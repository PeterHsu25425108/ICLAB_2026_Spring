import os
import re
import csv
import argparse
import subprocess

def get_design_name(syn_dir):
    tcl_path = os.path.join(syn_dir, "syn.tcl")
    if not os.path.exists(tcl_path):
        return None
    with open(tcl_path, 'r') as file:
        for line in file:
            match = re.search(r'set\s+DESIGN\s+"([^"]+)"', line)
            if match:
                return match.group(1)
    return None

def update_syn_tcl(syn_dir, clk_val):
    tcl_path = os.path.join(syn_dir, "syn.tcl")
    with open(tcl_path, 'r') as file:
        content = file.read()
    
    new_content = re.sub(r'set\s+CYCLE\s+[\d\.]+', f'set CYCLE {clk_val}', content)
    
    with open(tcl_path, 'w') as file:
        file.write(new_content)

def update_pattern_clk(testbed_dir, clk_val):
    pattern_path = os.path.join(testbed_dir, "PATTERN.v")
    if not os.path.exists(pattern_path):
        print(f"Warning: Could not find {pattern_path}")
        return
    
    with open(pattern_path, 'r') as file:
        content = file.read()
    
    new_content = re.sub(r'`define\s+CYCLE_TIME\s+[\d\.]+', f'`define CYCLE_TIME {clk_val}', content)
    
    with open(pattern_path, 'w') as file:
        file.write(new_content)

def run_command(command, working_dir):
    try:
        result = subprocess.run(
            command,
            cwd=working_dir,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
            check=False
        )
        return result.stdout + result.stderr
    except Exception as e:
        return str(e)

def parse_reports(syn_dir, design_name):
    area_report = os.path.join(syn_dir, "Report", f"{design_name}.area")
    timing_report = os.path.join(syn_dir, "Report", f"{design_name}.timing")
    
    area = None
    slack_status = None
    slack_val = None

    try:
        with open(area_report, 'r') as f:
            match = re.search(r'Total cell area:\s+([\d\.]+)', f.read())
            if match:
                area = float(match.group(1))
    except FileNotFoundError:
        pass

    try:
        with open(timing_report, 'r') as f:
            match = re.search(r'slack\s*\((MET|VIOLATED)\)\s*([-\d\.]+)', f.read())
            if match:
                slack_status = match.group(1)
                slack_val = float(match.group(2))
    except FileNotFoundError:
        pass

    return area, slack_status, slack_val

def check_sim_pass(output_text):
    return "Congratulations !!" in output_text

def evaluate_clk(clk, rtl_dir, syn_dir, gate_dir, testbed_dir, design_name, latency_cycles, cache):
    if clk in cache:
        print(f"\n[CACHE] Skipping CLK = {clk} ns (Already evaluated)")
        res = cache[clk]
        passed = str(res["Cost"]) not in ["VIOLATION", "GATE_FAIL", "-"]
        return res, passed

    print(f"\nEvaluating CLK = {clk} ns")
    update_syn_tcl(syn_dir, clk)
    update_pattern_clk(testbed_dir, clk)
    
    print("  Running 01_RTL...")
    rtl_out = run_command("./01_run_vcs_rtl", rtl_dir)
    if not check_sim_pass(rtl_out):
        print("  RTL Simulation Failed. Skipping Synthesis and Gate.")
        res = {"CLK": clk, "RTL": "FAIL", "SYN": "-", "GATE": "-", "Area": "-", "Slack": "-", "Cost": "-"}
        cache[clk] = res
        return res, False

    print("  Running 02_SYN...")
    run_command("./01_run_dc_shell", syn_dir)
    area, slack_status, slack_val = parse_reports(syn_dir, design_name)
    
    if slack_status != "MET":
        print(f"  Synthesis Timing Violated (Slack: {slack_val}). Skipping Gate sim.")
        res = {"CLK": clk, "RTL": "PASS", "SYN": "VIOLATED", "GATE": "-", "Area": area, "Slack": slack_val, "Cost": "VIOLATION"}
        cache[clk] = res
        return res, False

    print("  Running 03_GATE...")
    gate_out = run_command("./01_run_vcs_gate", gate_dir)
    if check_sim_pass(gate_out):
        latency_mult = latency_cycles if latency_cycles is not None else 1
        cost = round(area * clk * latency_mult, 2)
        print(f"  Success! Area: {area}, Slack: {slack_val}, Cost: {cost}")
        res = {"CLK": clk, "RTL": "PASS", "SYN": "MET", "GATE": "PASS", "Area": area, "Slack": slack_val, "Cost": cost}
        cache[clk] = res
        return res, True
    else:
        print("  Gate Simulation Failed.")
        res = {"CLK": clk, "RTL": "PASS", "SYN": "MET", "GATE": "FAIL", "Area": area, "Slack": slack_val, "Cost": "GATE_FAIL"}
        cache[clk] = res
        return res, False

def main():
    parser = argparse.ArgumentParser(description="Run design steps and explore CLK.")
    parser.add_argument("lab", help="Lab identifier (e.g., lab1)")
    parser.add_argument("--init_clk", type=float, default=10.0)
    parser.add_argument("--max_clk", type=float, default=15.0)
    parser.add_argument("--min_clk", type=float, default=5.0)
    parser.add_argument("--step", type=float, default=0.5)
    parser.add_argument("--latency_cycles", type=int, default=None)
    parser.add_argument("--tolerance", type=int, default=None)
    parser.add_argument("--use_bs", action="store_true", help="Use binary search to find min passing clock first")
    args = parser.parse_args()

    match = re.search(r'\d+', args.lab)
    if not match:
        print("Invalid lab argument. Please use a format like 'lab1'.")
        return
    
    lab_num = int(match.group())
    base_dir = os.path.join(os.path.expanduser("~"), f"SPRING2026_LAB{lab_num:02d}")
    
    if not os.path.exists(base_dir):
        print(f"Directory not found: {base_dir}")
        return

    testbed_dir = os.path.join(base_dir, "00_TESTBED")
    rtl_dir = os.path.join(base_dir, "01_RTL")
    syn_dir = os.path.join(base_dir, "02_SYN")
    gate_dir = os.path.join(base_dir, "03_GATE")
    output_csv = os.path.join(base_dir, f"{args.lab}_stat.csv")

    design_name = get_design_name(syn_dir)
    if not design_name:
        print(f"Could not find design name in {syn_dir}/syn.tcl")
        return

    # 1. Build a strict grid aligned with max_clk
    valid_clks = []
    c = args.max_clk
    while c >= args.min_clk:
        valid_clks.append(round(c, 2))
        c -= args.step
    valid_clks.reverse() # Sort ascending: [min_clk, ..., max_clk]

    if args.init_clk not in valid_clks:
        print(f"Error: init_clk ({args.init_clk}) is not aligned with the step grid starting from max_clk ({args.max_clk}).")
        return

    print(f"Starting exploration for {args.lab} in {base_dir}")
    print(f"Design Name: {design_name}")
    print("-" * 50)

    cache = {}
    actual_min_clk = args.min_clk

    # 2. Binary Search (Optional)
    if args.use_bs:
        print("\n--- Running Binary Search for Minimum Passing Clock ---")
        low = 0
        high = len(valid_clks) - 1
        best_idx = -1

        while low <= high:
            mid = (low + high) // 2
            test_clk = valid_clks[mid]
            
            _, passed = evaluate_clk(test_clk, rtl_dir, syn_dir, gate_dir, testbed_dir, design_name, args.latency_cycles, cache)
            
            if passed:
                best_idx = mid
                high = mid - 1 # Try a tighter clock
            else:
                low = mid + 1  # Relax the clock

        if best_idx != -1:
            actual_min_clk = valid_clks[best_idx]
            print(f"-> Binary search complete. Absolute minimum passing clock is {actual_min_clk} ns.")
        else:
            print("-> Binary search complete. No passing clock found in the entire range.")
            actual_min_clk = args.max_clk + args.step # Skips downward exploration entirely

    # 3. Downward Exploration
    print("\n--- Starting Downward Exploration ---")
    current_clk = args.init_clk
    last_cost = float('inf')
    consecutive_increases = 0

    while current_clk >= actual_min_clk:
        result_dict, passed = evaluate_clk(current_clk, rtl_dir, syn_dir, gate_dir, testbed_dir, design_name, args.latency_cycles, cache)
        
        if not passed:
            print(f"Stopping downward exploration. Hit failure at {current_clk} ns.")
            break
            
        current_cost = result_dict["Cost"]
        if args.tolerance is not None and current_cost > last_cost:
            consecutive_increases += 1
            print(f"  Cost increased. Consecutive increases: {consecutive_increases}/{args.tolerance}")
        else:
            consecutive_increases = 0
            
        if args.tolerance is not None and consecutive_increases >= args.tolerance:
            print(f"Stopping downward exploration. Cost increased for {args.tolerance} consecutive steps.")
            break
            
        last_cost = current_cost
        current_clk = round(current_clk - args.step, 2)

    # 4. Upward Exploration
    print("\n--- Starting Upward Exploration ---")
    current_clk = round(args.init_clk + args.step, 2)
    while current_clk <= args.max_clk:
        evaluate_clk(current_clk, rtl_dir, syn_dir, gate_dir, testbed_dir, design_name, args.latency_cycles, cache)
        current_clk = round(current_clk + args.step, 2)

    # 5. Output to CSV
    with open(output_csv, mode='w', newline='') as file:
        writer = csv.DictWriter(file, fieldnames=["CLK", "RTL", "SYN", "GATE", "Area", "Slack", "Cost"])
        writer.writeheader()
        
        results_list = list(cache.values())
        sorted_results = sorted(results_list, key=lambda x: x["CLK"])
        writer.writerows(sorted_results)

    print(f"\nExploration complete. Results saved to {output_csv}")

if __name__ == "__main__":
    main()