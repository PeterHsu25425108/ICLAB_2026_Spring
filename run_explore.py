import os
import re
import csv
import argparse
import subprocess
import time

FIELDNAMES = ["CLK", "RTL", "SYN", "GATE", "Area", "Slack", "Cost"]

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

def load_cache_from_csv(csv_path, kb):
    cache = {}
    if os.path.exists(csv_path):
        with open(csv_path, 'r') as file:
            reader = csv.DictReader(file)
            for row in reader:
                try:
                    clk = float(row["CLK"])
                    if row["Cost"] not in ["VIOLATION", "GATE_FAIL", "-", "PARSE_ERR"]:
                        row["Cost"] = float(row["Cost"])
                    else:
                        if "VIOLATED" in row["SYN"]:
                            kb["max_failed_clk"] = max(kb["max_failed_clk"], clk)
                    cache[clk] = row
                except ValueError:
                    pass
        print(f"Loaded {len(cache)} previous results from {csv_path}")
        if kb["max_failed_clk"] > 0:
            print(f"-> Knowledge Base: Max failed clock known is {kb['max_failed_clk']} ns.")
    return cache

def append_to_csv(csv_path, result_dict):
    file_exists = os.path.exists(csv_path)
    with open(csv_path, 'a', newline='') as file:
        writer = csv.DictWriter(file, fieldnames=FIELDNAMES)
        if not file_exists:
            writer.writeheader()
        writer.writerow(result_dict)

def sort_csv(csv_path):
    if os.path.exists(csv_path):
        with open(csv_path, 'r') as file:
            reader = csv.DictReader(file)
            rows = list(reader)
        rows.sort(key=lambda x: float(x["CLK"]))
        with open(csv_path, 'w', newline='') as file:
            writer = csv.DictWriter(file, fieldnames=FIELDNAMES)
            writer.writeheader()
            writer.writerows(rows)

def evaluate_clk(clk, rtl_dir, syn_dir, gate_dir, testbed_dir, base_dir, design_name, latency_cycles, cache, csv_path, kb):
    if clk in cache:
        print(f"\n[CACHE] Skipping CLK = {clk} ns (Already evaluated)")
        res = cache[clk]
        passed = str(res["Cost"]) not in ["VIOLATION", "GATE_FAIL", "-"]
        return res, passed

    if clk <= kb["max_failed_clk"]:
        print(f"\n[INFERRED] Skipping CLK = {clk} ns (Guaranteed timing violation since {kb['max_failed_clk']} ns failed)")
        res = {"CLK": clk, "RTL": "PASS(Inferred)", "SYN": "VIOLATED(Inferred)", "GATE": "-", "Area": "-", "Slack": "-", "Cost": "VIOLATION"}
        cache[clk] = res
        append_to_csv(csv_path, res)
        return res, False

    print(f"\nEvaluating CLK = {clk} ns")
    update_syn_tcl(syn_dir, clk)
    update_pattern_clk(testbed_dir, clk)
    
    print("  Running 01_RTL...")
    rtl_out = run_command("./01_run_vcs_rtl", rtl_dir)
    if not check_sim_pass(rtl_out):
        print("  RTL Simulation Failed. Skipping Synthesis and Gate.")
        res = {"CLK": clk, "RTL": "FAIL", "SYN": "-", "GATE": "-", "Area": "-", "Slack": "-", "Cost": "-"}
        cache[clk] = res
        append_to_csv(csv_path, res)
        run_command("./09_clean_up", base_dir)
        return res, False

    print("  Running 02_SYN...")
    run_command("./01_run_dc_shell", syn_dir)
    area, slack_status, slack_val = parse_reports(syn_dir, design_name)
    
    if slack_status != "MET":
        print(f"  Synthesis Timing Violated (Slack: {slack_val}). Skipping Gate sim.")
        kb["max_failed_clk"] = max(kb["max_failed_clk"], clk)
        res = {"CLK": clk, "RTL": "PASS", "SYN": "VIOLATED", "GATE": "-", "Area": area if area else "-", "Slack": slack_val if slack_val else "-", "Cost": "VIOLATION"}
        cache[clk] = res
        append_to_csv(csv_path, res)
        run_command("./09_clean_up", base_dir)
        return res, False

    print("  Running 03_GATE...")
    gate_out = run_command("./01_run_vcs_gate", gate_dir)
    if check_sim_pass(gate_out):
        latency_mult = latency_cycles if latency_cycles is not None else 1
        cost = round(area * clk * latency_mult, 2)
        print(f"  Success! Area: {area}, Slack: {slack_val}, Cost: {cost}")
        res = {"CLK": clk, "RTL": "PASS", "SYN": "MET", "GATE": "PASS", "Area": area, "Slack": slack_val, "Cost": cost}
        cache[clk] = res
        passed = True
    else:
        print("  Gate Simulation Failed.")
        res = {"CLK": clk, "RTL": "PASS", "SYN": "MET", "GATE": "FAIL", "Area": area, "Slack": slack_val, "Cost": "GATE_FAIL"}
        cache[clk] = res
        passed = False
        
    append_to_csv(csv_path, res)
    print("  Running 09_clean_up...")
    run_command("./09_clean_up", base_dir)
    
    return res, passed

def main():
    parser = argparse.ArgumentParser(description="Run design steps and explore CLK.")
    parser.add_argument("lab", help="Lab identifier (e.g., lab1)")
    parser.add_argument("--init_clk", type=float, default=10.0)
    parser.add_argument("--max_clk", type=float, default=15.0)
    parser.add_argument("--min_clk", type=float, default=5.0)
    parser.add_argument("--step", type=float, default=0.5)
    parser.add_argument("--latency_cycles", type=int, default=None)
    parser.add_argument("--tolerance", type=int, default=5)
    parser.add_argument("--use_bs", type=bool, default=False, help="Use binary search to find min passing clock first (only for downward search)")
    parser.add_argument("--search_order", choices=["downward", "upward"], default="downward", help="Order of linear search: 'downward' first or 'upward' first")
    parser.add_argument("--timeout", type=int, default=None, help="Stop exploring if total execution time exceeds this many seconds")
    args = parser.parse_args()

    start_time = time.time()

    def check_timeout():
        if args.timeout is not None and (time.time() - start_time) > args.timeout:
            print(f"\n[TIMEOUT] Exploration stopped. Time limit of {args.timeout} seconds reached.")
            return True
        return False

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

    valid_clks = []
    c = args.max_clk
    while c >= args.min_clk:
        valid_clks.append(round(c, 2))
        c -= args.step
    valid_clks.reverse()

    if args.init_clk not in valid_clks:
        print(f"Error: init_clk ({args.init_clk}) is not aligned with the step grid starting from max_clk ({args.max_clk}).")
        return

    print(f"Starting exploration for {args.lab} in {base_dir}")
    print(f"Design Name: {design_name}")
    print("-" * 50)

    kb = {"max_failed_clk": -1.0}
    cache = load_cache_from_csv(output_csv, kb)
    actual_min_clk = args.min_clk

    # 1. Check if we already have the minimum passing clock boundary cached
    passing_cached = [clk for clk, res in cache.items() if str(res.get("Cost", "")) not in ["VIOLATION", "GATE_FAIL", "-", "PARSE_ERR"]]
    boundary_known = False
    if passing_cached:
        min_pass_cached = min(passing_cached)
        clk_below = round(min_pass_cached - args.step, 2)
        # If the clock immediately below the lowest passing clock is known to fail, or if we hit the absolute floor, the boundary is known.
        if (clk_below in cache) or (clk_below <= kb["max_failed_clk"]) or (min_pass_cached <= args.min_clk):
            boundary_known = True
            actual_min_clk = min_pass_cached
            print(f"\n[INFO] Cached minimum passing clock boundary found at {actual_min_clk} ns. Skipping Binary Search.")

    # 2. Binary Search for downward search (only if boundary is unknown)
    if args.use_bs and args.search_order == "downward" and not boundary_known:
        print("\n--- Running Binary Search for Minimum Passing Clock ---")
        low = 0
        high = len(valid_clks) - 1
        best_idx = -1

        while low <= high:
            if check_timeout(): break
            mid = (low + high) // 2
            test_clk = valid_clks[mid]
            
            _, passed = evaluate_clk(test_clk, rtl_dir, syn_dir, gate_dir, testbed_dir, base_dir, design_name, args.latency_cycles, cache, output_csv, kb)
            
            if passed:
                best_idx = mid
                high = mid - 1 
            else:
                low = mid + 1  

        if best_idx != -1:
            actual_min_clk = valid_clks[best_idx]
            print(f"-> Binary search complete. Absolute minimum passing clock is {actual_min_clk} ns.")
        else:
            print("-> Binary search complete. No passing clock found in the entire range.")
            actual_min_clk = args.max_clk + args.step

    # 3. Establish Baseline at Init Clock
    if not check_timeout():
        evaluate_clk(args.init_clk, rtl_dir, syn_dir, gate_dir, testbed_dir, base_dir, design_name, args.latency_cycles, cache, output_csv, kb)

    def run_downward():
        print("\n--- Starting Downward Exploration ---")
        current_clk = round(args.init_clk - args.step, 2)
        last_cost = float('inf')
        consecutive_increases = 0
        
        if args.init_clk in cache:
            res_cost = cache[args.init_clk]["Cost"]
            if type(res_cost) in [float, int]:
                last_cost = res_cost
            elif str(res_cost) in ["VIOLATION", "GATE_FAIL", "-"]:
                print(f"Stopping downward exploration. Initial clock {args.init_clk} ns failed.")
                return

        while current_clk >= actual_min_clk:
            if check_timeout(): break
            result_dict, passed = evaluate_clk(current_clk, rtl_dir, syn_dir, gate_dir, testbed_dir, base_dir, design_name, args.latency_cycles, cache, output_csv, kb)
            
            if not passed:
                print(f"Stopping downward exploration. Hit failure at {current_clk} ns.")
                break
                
            current_cost = result_dict["Cost"]
            if args.tolerance is not None and type(current_cost) in [float, int] and current_cost > last_cost:
                consecutive_increases += 1
                print(f"  Cost increased. Consecutive increases: {consecutive_increases}/{args.tolerance}")
            else:
                consecutive_increases = 0
                
            if args.tolerance is not None and consecutive_increases >= args.tolerance:
                print(f"Stopping downward exploration. Cost increased for {args.tolerance} consecutive steps.")
                break
                
            if type(current_cost) in [float, int]:
                last_cost = current_cost
            current_clk = round(current_clk - args.step, 2)

    def run_upward():
        print("\n--- Starting Upward Exploration ---")
        current_clk = round(args.init_clk + args.step, 2)
        last_cost = float('inf')
        consecutive_increases = 0
        
        if args.init_clk in cache:
            res_cost = cache[args.init_clk]["Cost"]
            if type(res_cost) in [float, int]:
                last_cost = res_cost

        while current_clk <= args.max_clk:
            if check_timeout(): break
            result_dict, passed = evaluate_clk(current_clk, rtl_dir, syn_dir, gate_dir, testbed_dir, base_dir, design_name, args.latency_cycles, cache, output_csv, kb)
            
            current_cost = result_dict["Cost"]
            if args.tolerance is not None and type(current_cost) in [float, int] and current_cost > last_cost:
                consecutive_increases += 1
                print(f"  Cost increased. Consecutive increases: {consecutive_increases}/{args.tolerance}")
            else:
                consecutive_increases = 0
                
            if args.tolerance is not None and consecutive_increases >= args.tolerance:
                print(f"Stopping upward exploration. Cost increased for {args.tolerance} consecutive steps.")
                break
                
            if type(current_cost) in [float, int]:
                last_cost = current_cost
                
            current_clk = round(current_clk + args.step, 2)

    # 4. Execute Linear Sweeps in requested order
    if args.search_order == "downward":
        if not check_timeout(): run_downward()
        if not check_timeout(): run_upward()
    else:
        if not check_timeout(): run_upward()
        if not check_timeout(): run_downward()

    sort_csv(output_csv)
    print(f"\nExploration complete. Results saved and sorted in {output_csv}")

if __name__ == "__main__":
    main()