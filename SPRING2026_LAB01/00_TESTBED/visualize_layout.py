# %%
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import matplotlib.patches as patches

def parse_shape(shape_hex):
    # Convert hex string to integer
    if( not shape_hex or shape_hex.startswith("//") or shape_hex.startswith("endl")):
        return 0, 0, 0, 0, 0

    parts = [int(p) for p in shape_hex.split()]
    
    # Extract fields based on your specification
    layer_id = parts[0]
    x1 = parts[1]
    y1 = parts[2]
    x2 = parts[3]
    y2 = parts[4]

    return layer_id, x1, y1, x2, y2


# %%
def split_into_layouts(lines):
    """Split file lines into groups of shapes, separated by blank lines."""
    groups = []
    current = []
    for line in lines:
        if line.strip():
            current.append(line)
        else:
            if current:
                groups.append(current)
                current = []
    if current:
        groups.append(current)
    return groups


def plot_layout(shape_lines, output_path):
    fig, ax = plt.subplots(figsize=(8, 8))
    
    # Layer styling and Priority (zorder)
    # Priority Mapping (Higher zorder = stays on top)
    # NW:1, NP/PP:2, OD:3, PO:4, M1:5 (with hatch), CONT:6
    styles = {
        1: {'fc': 'lightgreen', 'ec': 'none',   'alpha': 1.0, 'z': 6, 'label': 'CO'},
        2: {'fc': 'red',        'ec': 'none',   'alpha': 0.8, 'z': 3, 'label': 'OD'},
        3: {'fc': 'blue',       'ec': 'none',   'alpha': 0.8, 'z': 4, 'label': 'PO'},
        4: {'fc': 'none',       'ec': 'skyblue','alpha': 1.0, 'z': 5, 'hatch': '...', 'label': 'M1'},
        5: {'fc': 'none',       'ec': 'yellow', 'alpha': 1.0, 'z': 2, 'lw': 2, 'label': 'NP'},
        6: {'fc': 'none',       'ec': 'purple', 'alpha': 1.0, 'z': 2, 'lw': 2, 'label': 'PP'},
        7: {'fc': 'none',       'ec': 'white',  'alpha': 1.0, 'z': 1, 'lw': 3, 'label': 'NW'}
    }

    try:
        for line in shape_lines[:16]: # Process up to 16 shapes
            input_string = line.strip()
            if( not input_string or input_string.startswith("//") or input_string.startswith("endl")):
                continue
            
            layer_id, x1, y1, x2, y2 = parse_shape(input_string)

            if layer_id == 0 or layer_id not in styles:
                continue
            
            s = styles[layer_id]
            # Create rectangle with zorder for layer priority
            rect = patches.Rectangle(
                (x1, y1), x2-x1, y2-y1, 
                facecolor=s.get('fc'), 
                edgecolor=s.get('ec'),
                hatch=s.get('hatch'),
                linewidth=s.get('lw', 1),
                alpha=s.get('alpha'),
                zorder=s['z'], # Higher numbers are drawn on top
                label=s.get('label') # Add label for legend
            )
            ax.add_patch(rect)

    except Exception as e:
        print(f"Error processing layout: {e}")
        return

    # Grid and Axis Setup
    ax.set_xlim(-1, 16)
    ax.set_ylim(-1, 16)

    # keep tick marks every 1 but only show labels for multiples of 5
    ax.set_xticks(range(16))
    ax.set_yticks(range(16))
    ax.set_xticklabels([str(t) if t % 5 == 0 else "" for t in range(16)])
    ax.set_yticklabels([str(t) if t % 5 == 0 else "" for t in range(16)])

    ax.grid(which='major', color='gray', linestyle='-', linewidth=0.5, alpha=0.3)
    ax.set_aspect('equal')
    ax.set_facecolor('#4e4e4e') # Dark background for better visibility
    plt.title("DRC Exercise: 32x32 Layout Visualization")
    
    # Create legend (avoiding duplicates)
    handles, labels = plt.gca().get_legend_handles_labels()
    by_label = dict(zip(labels, handles))
    plt.legend(by_label.values(), by_label.keys(), loc='upper right', bbox_to_anchor=(1.2, 1), facecolor='#8e8e8e', edgecolor='white', framealpha=0.9)

    plt.savefig(output_path, bbox_inches='tight')
    plt.close()
    print(f"Saved: {output_path}")

# %%
# Usage
# Mode 1: python visualize_layout.py <layout_file.txt>
#   - Treats file as groups of shapes separated by blank lines.
#   - Each group produces one output PNG: [filename]_[index].png
#
# Mode 2: python visualize_layout.py <LAB1_case.txt> <pattern_index>
#   - Parses the PATTERN.v/LAB1_case format:
#     Line 1: PATNUM
#     Per pattern: golden_out, drc_sel, then 16 lines of "typ llx lly urx ury"
#   - Plots the specified pattern index (0-based).
import os, sys
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python visualize_layout.py <layout_file.txt>")
        print("  python visualize_layout.py <LAB1_case.txt> <pattern_index>")
    elif len(sys.argv) == 3:
        # Mode 2: LAB1_case format with pattern index
        filename = sys.argv[1]
        pat_idx = int(sys.argv[2])
        base = os.path.splitext(filename)[0]
        try:
            with open(filename, 'r') as f:
                lines = [l.strip() for l in f.readlines() if l.strip()]
        except FileNotFoundError:
            print(f"Error: {filename} not found.")
            sys.exit(1)

        patnum = int(lines[0])
        if pat_idx < 0 or pat_idx >= patnum:
            print(f"Error: pattern index {pat_idx} out of range [0, {patnum-1}]")
            sys.exit(1)

        # Each pattern: 1 line golden + 1 line drc_sel + 16 shape lines = 18 lines
        offset = 1 + pat_idx * 18
        golden = int(lines[offset])
        drc_sel = int(lines[offset + 1])
        shape_lines = lines[offset + 2 : offset + 18]

        rule_type = drc_sel & 1
        rule_layer = (drc_sel >> 1) & 0x7
        layer_names = {0: 'CONTACT', 1: 'DIFF', 2: 'POLY', 3: 'M1', 4: 'NP', 5: 'PP', 6: 'NW'}
        print(f"Pattern {pat_idx}: golden={golden}, drc_sel={drc_sel} "
              f"(rule_type={'spacing' if rule_type else 'width'}, "
              f"rule_layer={layer_names.get(rule_layer, '?')})")

        output_path = f"{base}_pat{pat_idx}.png"
        plot_layout(shape_lines, output_path)
    else:
        # Mode 1: original blank-line-separated groups
        filename = sys.argv[1]
        base = os.path.splitext(filename)[0]
        try:
            with open(filename, 'r') as f:
                lines = f.readlines()
        except FileNotFoundError:
            print(f"Error: {filename} not found.")
            sys.exit(1)

        groups = split_into_layouts(lines)
        print(f"Found {len(groups)} layout(s) in {filename}")
        for i, group in enumerate(groups):
            output_path = f"{base}_{i}.png"
            plot_layout(group, output_path)

# %%



