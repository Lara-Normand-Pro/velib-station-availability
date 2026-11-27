# Vélib' station availability in Paris, 20 September - 16 November 2026

Group H, ESSEC, course "Data, Data storage". We collected the real-time Vélib' Métropole feed
every 5 minutes for 8 weeks with two independent collectors, and we study how often a station
cannot give or take a bike, and whether another working station lies within 300 m (about a
4-minute walk) at that moment.

- **Data (Zenodo):** [10.5281/zenodo.24444738](https://doi.org/10.5281/zenodo.24444738). Raw captures, derived tables, checksums, frozen code.
- **This repository:** the code, the setup to collect again, the analysis and the report.

## What is where

| | Zenodo record | This repository |
|---|---|---|
| Raw captures of both collectors (VM1, VM2) | yes | no (too large) |
| Derived data (Parquet, NDJSON, CSV, cleaned panel, episodes) | yes | no |
| Pipeline code (`code/`) | yes, frozen copy (`code.zip`) | yes, living version |
| Data dictionary | yes | yes (`DATA_DICTIONARY.md`) |
| VM setup and collection scripts | `collect.sh`, `crontab.txt` in `code.zip` | yes (`code/`, `vm_setup/`) |
| Analysis notebook, report | no | yes (`notebooks/`, `report/`) |

```
code/          the pipeline (run_all.py runs everything), collect.sh, crontab.txt, pack_vm.sh
vm_setup/      how the collector VMs were set up
notebooks/     the analysis
report/        final report
data/          data/external/: small hand-made tables (events, communes); the rest is empty here, see data/README.md
DATA_DICTIONARY.md   every file, table and column
```

## Reproduce the results from the data (use 1)

You need Python (tested with 3.12). The full rebuild was run on a laptop with 64 GB of RAM and on one with
16 GB (one collector is about 25 million rows); we recommend at least 16 GB. Allow about 2 hours per collector.

1. Download all files of the Zenodo record into one folder and check them:
   `sha256sum -c SHA256SUMS.txt` (Linux, macOS) or `Get-FileHash <file> -Algorithm SHA256` (Windows).
2. Clone this repository and unpack the raw archives at its root:
   ```
   mkdir vm1 vm2
   tar -xf velib_vm1_raw.tar -C vm1
   tar -xf velib_vm2_raw.tar -C vm2
   ```
3. Install and run:
   ```
   pip install -r code/requirements.txt
   python code/run_all.py --vm vm1 --no-bench
   python code/run_all.py --vm vm2 --no-bench
   python code/compare_vms.py vm1/velib vm2/velib
   ```
   Results go to `data/vm1/`, `data/vm2/` and `data/vm_comparison.csv`. VM1 and VM2 are never mixed.
4. Shortcut: unpack `vm1_parquet.tar` and `vm2_parquet.tar` from the record into `data/vm1/` and
   `data/vm2/` to skip step 3. The notebook reads the Parquet tables.

## Run the analysis notebook

`notebooks/analysis.ipynb` is the full analysis, one section per section of the report. It downloads the
data it needs from Zenodo (about 750 MB, with checksums) and queries the Parquet tables with DuckDB.

1. `pip install -r notebooks/requirements.txt`, then open `notebooks/analysis.ipynb` and Run All.
2. `VM = "vm1"` (first code cell) is the main series. Set `VM = "vm2"`, run again, then set `VM = "vm1"` to
   get the VM1 / VM2 comparison.
3. `RUN_REPLAY` (video, 4 to 25 minutes) and `RUN_BENCHMARK` (storage benchmark, slow, needs disk) are `False`
   by default: set them to `True` by hand.

See `notebooks/README.md` for the set-up on Windows and macOS. The small tables made by hand (13 events with
their sources, commune of each station) are in `data/external/`.

## From the report to the code

Where each figure and each key number of `report.pdf` (in the submitted archive; `report/report.pdf` in this repository) comes from. "Notebook §x" is
a section of `notebooks/analysis.ipynb`; the pipeline scripts are in `code/`.

| In the report | Produced by |
|---|---|
| 24,998,625 rows, 16,452 captures, 1,515 panel stations (§2, §6) | notebook §0.2 Self-check |
| 288 captures a day, no failed request, longest gap 5 min (§1 table, §2) | `code/coverage.py`; notebook §2 (`fig_coverage.png`) |
| 122 partial captures (§1 table, §2) | `code/validate.py` (`capture_quality.csv`) |
| Figure 1; `last_reported` (89.4 %), coarser sampling (93 % / 54 %, 50 % / 16 %), 6.12 % with deduplication (§2) | `code/sampling_test.py` (`sampling_sensitivity.csv`); notebook §5 (`fig_sampling.png`) |
| Cleaning flags table; `in_panel` 24,740,954 rows, 98.97 % (§2) | `code/clean.py` (`cleaning_log.csv`); notebook §3 (`fig_cleaning.png`) |
| 770 absent station-captures (§2) | notebook §3, second code cell |
| Storage tables: eight formats, designs A and B (§3) | `code/storage_benchmark.py`; notebook §4 (`RUN_BENCHMARK = True`) |
| How often: 6.94 % / 5.21 %, no alternative 2.17 % / 1.96 %, out of service 2.35 points (§4) | notebook §7.1 (tables built in §0.6 and §0.7) |
| Figure 2, weekday and hour (§4) | notebook §7.2 (`fig_hour_weekday.png`) |
| Figure 3, map; median and 90th percentile, 91 stations above 20 %, Notre-Dame rings (§4) | notebook §7.3 (`fig_station_map.png`) |
| Table Paris against the rest; isolated stations 8.9 % / 76.1 %, 487 isolated, reweighting 0.9 % / 1.0 % (§4, §6) | notebook §7.4; pair table from §0.5, communes from `data/external/station_communes.csv` (`code/build_station_communes.py`) |
| Radius test 200 / 300 / 500 m (§4) | notebook §7.4, radius test |
| Without the 14 event days, without the eight stations always out of service, first and second half (§4) | notebook §7.5 |
| VM2 gives the same rates as VM1 (§6) | notebook §7.5, VM2 comparison (run once with `VM = "vm2"`) |
| Figure 4, events timeline (§5) | notebook §6 (`fig_events_timeline.png`); `data/external/events.csv` |
| Closed stations out of service 72 % / 49 % against 3.7 % (§5) | notebook §6, station-level check; `data/external/closed_stations_E09.csv`, `closed_stations_E10.csv` |
| Hourly peaks 11.1 % / 9.7 % against a 1.26 % median over 29 days (§5) | notebook §6, peak table |
| Stations out of service for half a day: 128-162, 145, median 19 over 36 days (§5) | notebook §6, count check |
| Replay video (§5) | notebook §10 (`RUN_REPLAY = True`) |

## Collect the data again (use 2)

The collector is one shell script run by cron on a Linux machine with `curl` and `python3`
(we used an Azure VM). See `vm_setup/` for the full setup.

1. Copy `code/collect.sh` to `$HOME` and make it executable (`chmod +x collect.sh`).
2. Install the two cron lines of `code/crontab.txt`: status every 5 minutes, station list every hour.
3. Files appear in `~/velib/status/<date>/` and `~/velib/info/<date>/`, one line per request in
   `~/velib/http_log.csv`. A capture that fails the content check goes to `~/velib/quarantine/`.
4. `code/pack_vm.sh` packs the data up to a chosen UTC day without stopping the collector.

The feed: `https://velib-metropole-opendata.smovengo.cloud/opendata/Velib_Metropole`
(`station_status.json`, `station_information.json`). The past state of the feed cannot be
downloaded afterwards: the raw archive on Zenodo is the only record of it.

## The pipeline

`code/run_all.py --vm vmN` runs, in order:

| Script | Does |
|---|---|
| `coverage.py` | collection coverage per day, from the HTTP log |
| `validate.py` | content check of every raw capture |
| `build_snapshot.py` | raw captures to one Parquet file per day |
| `daily_json.py` | raw captures to one NDJSON file per day |
| `ndjson_to_csv.py` | NDJSON to one CSV file per day |
| `neighbours.py` | distances between stations, thresholds 200 / 300 / 500 m |
| `clean.py` | flags and the analysis panel (`in_panel`); counts are never altered |
| `episodes.py` | failure episodes, renting and returning sides |
| `sampling_test.py` | what coarser sampling (15 / 30 / 60 min) would lose |
| `storage_benchmark.py` | SQLite against Parquet + DuckDB (skipped with `--no-bench`) |

`compare_vms.py` compares the two collectors. `make_zenodo.sh` builds the folder uploaded to Zenodo.

## The data in numbers

| | VM1 | VM2 |
|---|---|---|
| Status captures | 16,452 | 16,478 |
| Station lists (hourly) | 1,371 | 1,374 |
| Station observations | 24,998,625 | 25,038,093 |
| Failed requests | 0 | 0 |
| Captures flagged `partial` (station code and bike types missing) | 122 | 123 |
| Rows dropped by cleaning | 0 | 0 |
| Failure episodes (at least 2 consecutive captures) | 202,853 | 203,012 |

Period: 20.09.2026 to 16.11.2026 23:59:59 UTC. 20.09 is a partial day (collection began in the
evening). VM2 started about two hours before VM1.

## Read this before using the data

- **`last_reported` is an hourly station signal, not the measurement time.** It renews about once
  an hour while the counts change several times an hour. We keep all rows and do not deduplicate on it.
- **5-minute sampling.** States shorter than about 10 minutes are not seen.
- **VM1 and VM2 are not merged.** They read the same feed, so stacking them counts each station twice per slot.
  On every day except 20.09 both captured exactly the same 5-minute slots, and the counts agreed
  for 100.0% of stations in the median sampled slot (92.0% in the worst): use one as the main
  series and the other as a check.
- **We flag, we do not alter.** Cleaning adds flag columns and one selection column, `in_panel`.
- All times are UTC.

Everything is defined in `DATA_DICTIONARY.md`.

## Licence and citation

Data: Vélib' Métropole / Smovengo, Open Database License (ODbL 1.0). Code: MIT (see LICENSE).

Cite the data as: Gueddas, K., Ben Njima, A., Normand, L., Ben Bachir, A., Labergère, A. (2026).
*Vélib' Métropole station status, 20.09.2026 - 16.11.2026 (two collectors)* [Data set]. Zenodo.
https://doi.org/10.5281/zenodo.24444738

## Authors

Kenza Gueddas, Adem Ben Njima, Lara Normand, Amine Ben Bachir, Adrien Labergère (ESSEC).
