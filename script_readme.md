# IC Lab Clock Exploration Automation (`run_explore.py`)

This script automates the search for the optimal `Area * Clock` cost (or `Area * Clock * Latency` cost) for IC Lab assignments. It automatically modifies clock constraints, runs the RTL/SYN/GATE EDA flow, and logs the results to a sorted CSV.

## Quick Start
Run the script from anywhere in your server terminal, specifying the lab folder:
```bash
python3 ~/run_explore.py lab1