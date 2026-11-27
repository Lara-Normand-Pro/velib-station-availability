# Analysis notebook: how to run it

Group H, Vélib' station availability (ESSEC, Data, Data storage). This folder holds the analysis notebook. It is written to run on **macOS or Windows**, without anything from the original author's computer. Data are downloaded from Zenodo; nothing large is stored in this repository.

**Status:** final version of 27.11. It ran end to end on the real data (24,998,625 rows, 16,452 captures) and the figures of the report come from it. It contains the written readings, the 13 verified events, the closure lists E09 and E10, the commune table, the count check by day, the radius and event-day checks, the VM2 comparison, the environment record and the replay video with a map background. The file is saved **without outputs**: run it to get them. Two switches are off by default and must be set to `True` by hand in the first code cell: `RUN_BENCHMARK` (section 4) and `RUN_REPLAY` (section 10).

## 1. What you need

- Python 3.10 or newer
- About 3 GB of free disk space (750 MB of downloads, the rest unpacked; you can delete `data/zenodo/` afterwards). The optional storage benchmark (section 4) needs about 10 GB more on the full period
- 8 GB of RAM is enough **if you follow the rules in section 4** (do not load the full table into pandas)

## 2. Set up (once)

Open a terminal in the repository root.

**macOS / Linux**
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r notebooks/requirements.txt
```

**Windows (PowerShell)**
```powershell
py -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r notebooks/requirements.txt
```
If PowerShell refuses to run the activation script, run `Set-ExecutionPolicy -Scope Process Bypass` once in that window, then activate again.

`notebooks/requirements.txt` lists everything the notebook needs (`duckdb`, `pandas`, `pyarrow`, `numpy`, `matplotlib`, `requests`, `psutil`, `jupyterlab`). It is separate from the pipeline's `requirements.txt`.

Start Jupyter from the repository root (so relative paths work):
```
jupyter lab
```
and open `notebooks/analysis.ipynb`. Run it top to bottom (**Run > Run All Cells**). The first run downloads about 750 MB; the next runs reuse everything.

## 3. Get the data

The data are on Zenodo, version DOI **10.5281/zenodo.24444738** (all versions: 10.5281/zenodo.24444737), licence ODbL. Section 0.1 of the notebook downloads what it needs if `data/vm1/` does not hold the data yet and checks the checksums against `SHA256SUMS.txt`. To do it by hand:

| File on Zenodo | Size | What it gives you | Unpack to |
|---|---|---|---|
| `vm1_parquet.tar` | 311 MB | cleaned rows with flags (`clean/station_status_clean/`), `clean/episodes.parquet`, flat table | `data/vm1/` |
| `vm1_csv_logs.tar.gz` | 436 MB | summary tables: `stations_daily.csv`, `station_neighbours.csv`, `sampling_sensitivity.csv`, `cleaning_log.csv`, ... | `data/vm1/` (the notebook skips `daily_json/`, about 2 GB of daily CSV you do not need) |
| `SHA256SUMS.txt` | tiny | checksums of every file | anywhere |

The raw tars (`velib_vm1_raw.tar`, 638 MB) are **not needed** for the analysis; they are the primary archive and the starting point for rebuilding everything with `python code/run_all.py --vm vm1 --no-bench` (about 2 hours).

Rules for the data:
- **VM1 is the main series. VM2 is a reliability check. Never merge them.**
- All times are UTC.
- Column meanings are in `DATA_DICTIONARY.md` at the repository root.

Expected layout after unpacking (paths match `code/`):
```
data/
  vm1/
    clean/
      station_status_clean/date=<YYYY-MM-DD>/part-0.parquet   (large: 58 daily files)
      episodes.parquet                                        (1.4 MB)
      stations_daily.csv, cleaning_log.csv, sampling_sensitivity.csv, ...
    station_neighbours.csv, threshold_sensitivity.csv, ...
  external/                                                   (see section 5)
  derived/                                                    (small tables built by the notebook)
```

## 4. Working with the large table (read this before writing queries)

The cleaned table has about **25 million rows and 29 columns**. Loading it whole in pandas can use several GB and crash a laptop.

1. **Start from the small tables** when they are enough: `episodes.parquet` (202,853 rows), `stations_daily.csv` (about 88,000 rows), `station_neighbours.csv` (one row per station).
2. **For row-level data, query the Parquet files in place with DuckDB** and select only the columns you need. Never `SELECT *`, never `pd.read_parquet` on the whole folder.
3. **Aggregate once, save the small result** to `data/derived/<name>.parquet`, and reload it next time. The notebook has two helpers for this: `load_status(columns)` (a DuckDB view over the Parquet files with only the columns you ask for, `in_panel` rows only by default) and `cached(name, sql_or_function)`. Use them instead of writing `read_parquet` by hand.
4. **Develop on a few days, finish on everything.** Set `SAMPLE_DAYS` at the top of the notebook to a short list of dates while you work, and to `None` for the final numbers. Derived files built on sample days get a `__sample` suffix, so they never mix with the full-period ones.
5. Do not loop over rows in Python; use set-based SQL joins (the 300 m alternative-station rule in 0.7 is built this way, one day at a time).
6. If the notebook is slow or runs out of memory, lower `MEMORY_LIMIT` and `THREADS` at the top; DuckDB then spills to `data/tmp/`.

## 5. External data (already in the repository)

The question compares Paris with the surrounding communes, so each station needs a commune. This is **not in the Zenodo record**, so it is added in `data/external/`:

- `station_communes.csv`: the commune (INSEE code, name) of every station, built with `code/build_station_communes.py` from API Géo (reverse lookup by latitude and longitude, 5 to 10 minutes, answers cached). The notebook only reads it (section 0.4); set `BUILD_COMMUNES = True` to rebuild it. Its `population` column is not used in any result, and the API does not state its year.
- `events.csv`: the 13 events of the period, each with its source and access date; `closed_stations_E09.csv` and `closed_stations_E10.csv` list the closed stations.

Every source is documented in `data/external/SOURCES.md`. The rest of the notebook needs neither the network nor geo libraries.

## 6. What the notebook does, in order

The notebook follows the story of the report. Part 0 is the workflow, run once; sections 1 to 10 are the story.

| Part | Content | Output |
|---|---|---|
| 0.1 to 0.7 | Data (download, checksum, unpack), **self-check** (stops if numbers differ), panel stations, commune table, 300 m pairs, one pass over the 25 M rows (counts per station x UTC hour), alternative rule | `data/derived/` |
| 0.8 | Events table loaded from `data/external/events.csv` (13 verified events) | `EVENT_DAYS` |
| 1 | Question, defined terms, what changed after each feedback round | text |
| 2 | Data and collection | `fig_coverage.png` |
| 3 | Quality and cleaning: flag, do not alter | `fig_cleaning.png` |
| 4 | Storage: format benchmark + **design benchmark** (Parquet + DuckDB vs SQLite with reference tables), off by default; decision | `storage_benchmark.csv`, `storage_design_benchmark.csv` |
| 5 | Sampling and `last_reported` | `fig_sampling.png` |
| 6 | **Validation with events**: timeline with events, spike against baseline, closed-station check (closure lists E09 and E10) | `fig_events_timeline.png` (report fig. 1) |
| 7 | Analysis: how often, when (`fig_hour_weekday.png`), where (`fig_station_map.png`), 300 m question, robustness without event days. Each subsection prints **Observation** sentences and has a checklist for the interpretation | report figs. 2 to 4 |
| 8 | Reproducibility: three layers | text |
| 9 | Conclusion (three-sentence answer template), limits, lessons (draft to edit) | text |
| 10 | **The replay**: all 57 days on a map, with the events (`RUN_REPLAY = True`) | `replay_velib.mp4`, `fig_snapshot_*.png` |

Each prep step skips outputs that already exist; set `FORCE = True` to rebuild. Switches at the top: `SAMPLE_DAYS`, `STOP_ON_MISMATCH` (keep it `True`), `MEMORY_LIMIT`, `THREADS`, `RUN_BENCHMARK`, `RUN_REPLAY`. Every analysis table sums the counts in `station_hour` / `station_hour_alt` (`shares`, `shares_alt`), so shares are exact weighted shares. The video needs `pip install imageio-ffmpeg` (a smaller GIF is written without it); it is a presentation asset, the report does not depend on it. The small CSVs of sections 2, 3 and 5 are read defensively: if a file or column is missing, that figure is skipped with a message.

### Self-check numbers (VM1)
If your numbers differ, stop and find out why before analysing.

| Quantity | Value |
|---|---|
| Rows (flat table) | 24,998,625 |
| Status captures | 16,452 |
| Rows in the analysis panel (`in_panel`) | 24,740,954 (1,515 stations) |
| Share of time a station cannot rent / cannot take a return | 6.94% / 5.21% |
| Episodes cannot rent / cannot return | 124,950 / 77,903 (202,853 in total) |
| Share of stations with another station within 300 m | 68.1% |

## 7. Conventions to keep

- **Flag, do not alter.** No count is corrected; exclusions are flags, and `in_panel` is the single selector.
- Say "cannot rent" and "cannot take a return", never "broken": the feed cannot tell a broken station from one that stopped reporting.
- Episode durations are "time seen failing" (up to 5 minutes longer at each end).
- `last_reported` is an hourly station signal, **not** the time the counts were measured. Use the capture time (`fetched_at`) as the time axis.
- Population is context only.
- Distances are straight-line, station to station, computed with the same equirectangular formula as `code/neighbours.py` so that the pair table reproduces `n_within_300m` exactly.
- Hour of day and weekday in Part 1 are in Paris time, derived exactly from the UTC hour; the data stay in UTC.
- A neighbour missing from a capture counts as "cannot serve" in the alternative rule; the alternative must itself be a panel station.

## 8. What is done / what is open

Done: collection, cleaning pipeline, Zenodo archive, documentation, and the analysis in sections 1 to 10.

**Outputs.** The notebook writes its results to `outputs/` at the repository root. The repository ships the four figures of the report (`fig_sampling.png`, `fig_hour_weekday.png`, `fig_station_map.png`, `fig_events_timeline.png`) and the replay video (`replay_velib.mp4`, 57 s), exactly as the notebook produced them.

**Tested by someone else:** a group member who had not worked on the notebook cloned the repository and ran it from a clean clone (download from Zenodo, self-check on the real 25 M rows). If the self-check stops, look at the printed table first. Column names of `sampling_sensitivity.csv`, `cleaning_log.csv` and `coverage_status.csv` are matched loosely; fix them in sections 2, 3 and 5 if a figure is skipped.

Nothing open.