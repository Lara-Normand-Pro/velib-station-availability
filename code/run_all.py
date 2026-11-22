"""
Run the whole workflow in order, from raw captures to cleaned table and checks.

    python code/run_all.py --vm vm1              # everything, for the folder vm1/velib
    python code/run_all.py --vm vm2 --no-bench   # skip the storage benchmark (needs duckdb)
    python code/run_all.py --vm vm1 --no-csv     # skip the large per-day CSV files
    python code/run_all.py                       # no --vm: the submitted package, as before

With --vm vmN the scripts read vmN/velib/ (the unpacked velib_vmN_raw.tar) and write into
data/vmN/. The two VMs are never mixed. Stops at the first script that fails.
Any working directory.
"""
import os, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
STEPS = [
    ("coverage.py",          "collection coverage, from the HTTP log"),
    ("validate.py",          "content check of every raw capture"),
    ("build_snapshot.py",    "raw captures -> one Parquet file per day"),
    ("daily_json.py",        "raw captures -> one NDJSON file per day"),
    ("ndjson_to_csv.py",     "NDJSON -> one CSV file per day (large)"),
    ("neighbours.py",        "station distances, 200 / 300 / 500 m"),
    ("clean.py",             "cleaning: flags, same-day station list, panel"),
    ("episodes.py",          "failure episodes, renting and returning sides"),
    ("sampling_test.py",     "last_reported check, 5 vs 15 / 30 / 60 min"),
    ("storage_benchmark.py", "SQLite vs Parquet + DuckDB"),
]
if "--no-bench" in sys.argv:
    STEPS = [s for s in STEPS if s[0] != "storage_benchmark.py"]
if "--no-csv" in sys.argv:
    STEPS = [s for s in STEPS if s[0] != "ndjson_to_csv.py"]

env = dict(os.environ)
if "--vm" in sys.argv:
    i = sys.argv.index("--vm")
    if i + 1 >= len(sys.argv) or sys.argv[i + 1].startswith("--"):
        sys.exit("usage: run_all.py --vm vm1 [--no-bench] [--no-csv]")
    env["VELIB_VM"] = sys.argv[i + 1]
    print(f"VM: {env['VELIB_VM']}")

for script, what in STEPS:
    print(f"\n{'=' * 78}\n{script}: {what}\n{'=' * 78}", flush=True)
    r = subprocess.run([sys.executable, str(HERE / script)], env=env)
    if r.returncode != 0:
        sys.exit(f"\nstopped: {script} failed")
print("\nall steps done")
