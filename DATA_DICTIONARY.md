# Data dictionary

Group H, Vélib' availability project (ESSEC, Data, Data storage). What every file of the
Zenodo record contains, and what every column means.

**Period** 20.09.2026 to 16.11.2026 23:59:59 UTC. **Collectors** two independent virtual
machines, VM1 and VM2, never merged in this record. **Source** Vélib' Métropole GBFS feed
(`station_status` every 5 minutes, `station_information` every hour), operated by
Smovengo. All timestamps are UTC (Paris is UTC+2 until 25.10.2026, UTC+1 after). All
distances are straight-line metres.

---

## 0. Where things are

| Zenodo file | Unpacks to | What it is |
|---|---|---|
| `velib_vm1_raw.tar`, `velib_vm2_raw.tar` | `velib/status/<date>/<YYYYMMDDTHHMMSSZ>.json.gz`, `velib/info/<date>/…`, `velib/http_log.csv`, `velib/quarantine/{status,info}/<date>/` | **The primary data**: untouched files as the collector wrote them (section 1) |
| `velib_vmN_raw.tar.sha256`, `velib_vmN_summary.txt` | | checksum of the tar, counts and period of what it holds |
| `vmN_parquet.tar` | `station_status/date=<date>/part-0.parquet`, `clean/station_status_clean/date=<date>/part-0.parquet`, `clean/episodes.parquet` | flat tables (sections 2, 3, 4) |
| `vmN_ndjson.tar` | `daily_json/status_<date>.ndjson.gz` | one file per day, one line per capture (section 5) |
| `vmN_csv_logs.tar.gz` | `daily_json/status_<date>.csv` and all summary tables | readable CSV copies and quality tables (sections 5 to 9) |
| `vm_comparison.csv` | | VM1 against VM2, per day (section 10) |
| `code.zip` | `code/` | the scripts that produce everything above from the raw tars |
| `SHA256SUMS.txt` | | checksum of every file of the record |

How much there is:

| | VM1 | VM2 |
|---|---|---|
| Status captures | 16,452 | 16,478 |
| Station lists (hourly) | 1,371 | 1,374 |
| First / last status day | 20.09 / 16.11 | 20.09 / 16.11 |
| Station observations (rows of the flat table) | 24,998,625 | 25,038,093 |
| First capture (UTC) | 20.09.2026 21:05 | 20.09.2026 18:57 |
| Failed requests, quarantined captures | 0, 0 | 0, 0 |

VM2 started about two hours before VM1: its 26 extra captures (and 39,468 extra rows, 26 × 1,518) are all on 20.09. A full day holds 288
status captures and 24 station lists. 20.09 is a partial day on both VMs.

## 1. Raw files (`velib_vmN_raw.tar`)

**`status/<date>/<YYYYMMDDTHHMMSSZ>.json.gz`**: one GBFS `station_status` response, gzip.
The file name is the moment **we sent the request** (UTC).

| Field | Meaning |
|---|---|
| `lastUpdatedOther` | the feed's own update marker |
| `ttl` | validity in seconds declared by the feed |
| `data.stations[]` | one object per station (below) |

| Station field | Meaning |
|---|---|
| `station_id` | identifies the station. Join key to the station list |
| `stationCode` | the short code printed on the station |
| `num_bikes_available`, `num_docks_available` | bikes to rent, free docks, at that moment |
| `num_bikes_available_types` | list splitting the bikes: `[{"mechanical": n}, {"ebike": n}]` |
| `is_installed`, `is_renting`, `is_returning` | 0 or 1: deployed, allows rentals, accepts returns |
| `last_reported` | unix seconds: when the **station** last reported its state |

**`info/<date>/<YYYYMMDDTHHMMSSZ>.json.gz`**: one `station_information` response per hour.
Per station: `station_id`, `stationCode`, `name`, `lat`, `lon` (WGS84), `capacity` (total
docks). `rental_methods` and `station_opening_hours` are incomplete and not used.

**`http_log.csv`**: one line per request, written by the collector whatever the outcome,
no header. Cut at the end of 16.11 UTC.

| Position | Example | Meaning |
|---|---|---|
| 1 | `20261116T235501Z` | when the request was sent |
| 2 | `status` or `info` | which feed |
| 3 | `200` | HTTP code returned |
| 4 | `466440` | size of the response in bytes (from collector v2) |
| 5 | `1525` | number of stations in the response (v2) |
| 6 | `ok` | content check made by the collector: `ok`, `partial` or `bad` (v2) |

Lines before 02.11.2026 (VM1) or 03.11.2026 (VM2) have only the first three fields: the
collector did not check content then. `validate.py` applies the same check to every archived file afterwards.

**`quarantine/{status,info}/<date>/`**: captures the collector refused to archive. Empty for both VMs.

## 2. `station_status/date=<date>/part-0.parquet`

One row per station per capture. One file per day. Nothing is dropped or corrected: this
step only flattens the raw JSON.

| Column | Type | Meaning |
|---|---|---|
| `station_id` | integer | station identifier |
| `stationCode` | text | short code. **Null** when the capture lacks it (partial captures) |
| `num_bikes_available` | integer | bikes available to rent |
| `mechanical`, `ebike` | integer | the split of the above. **Null** on partial captures |
| `num_docks_available` | integer | free docks |
| `is_installed`, `is_renting`, `is_returning` | 0 or 1 | as published |
| `last_reported` | timestamp UTC | when the **station** last reported |
| `fetched_at` | timestamp UTC | when **we** sent the request (from the file name) |
| `lr_age_min` | float | `fetched_at` minus `last_reported`, in minutes (before 03.11 this was called `lag_min`) |
| `feed_last_updated` | integer | the feed's `lastUpdatedOther` |
| `source_file` | text | the raw file the row came from |
| `vm` | text | `vm1` or `vm2` |

Three things to know before using it:

- `fetched_at` is when we **asked**, not when the answer arrived (within a second or two).
- **`last_reported` is an hourly station signal, not the measurement time.** It renews about
  once an hour per station, while the counts change several times an hour. So `lr_age_min`
  (median about 33 minutes) is the age of that signal when we read it. It does not say how
  long after a real event the report appeared. About 91% of rows repeat an earlier
  `(station_id, last_reported)` pair, and about 89% of count changes happen under an
  unchanged `last_reported`. This is why all rows are kept and **no deduplication on
  `last_reported` is done**.
- The number of stations per capture varies over the period (1,517 to 1,525 on VM1) because
  the station list changes.

## 3. `clean/station_status_clean/date=<date>/part-0.parquet`

The same rows after `clean.py`, plus flags and derived columns. Principle: **we flag, we do
not alter.** Counts are never corrected or imputed. Rows are removed only when they carry
no usable information, and on this dataset none were: a capture with fewer than 1,400
stations would be dropped (0 captures), an exact duplicate `(station_id, fetched_at)` would
be dropped (0 rows). Everything else becomes a flag, and the analysis decides through the
single column `in_panel`.

| Column | Meaning |
|---|---|
| `fetched_at`, `station_id`, `stationCode`, `last_reported`, `lr_age_min`, `vm` | as in section 2 |
| `name`, `lat`, `lon` | from the **same day's** station list (the last hourly list of that day) |
| `capacity` | total docks, from that list. **NA** when the list gives 0 or nothing |
| `num_bikes_available`, `mechanical`, `ebike`, `num_docks_available` | as published |
| `docks_unavailable` | `capacity - bikes - docks`: docks neither holding a bike nor free. Negative means a conflict |
| `is_installed`, `is_renting`, `is_returning` | as published |
| `state` | `out_of_service`, else `empty` (0 bikes), else `full` (0 free docks), else `ok` |
| `out_of_service` | not installed, **or** neither renting nor returning |
| `can_rent` | installed, renting, at least 1 bike |
| `can_return` | installed, returning, at least 1 free dock |

Flags (true or false), with the rule:

| Flag | Rule | VM1 rows flagged | VM2 rows flagged |
|---|---|---|---|
| `partial_capture` | `stationCode` missing: counts present, descriptive fields missing | 185,378 | 186,896 |
| `in_station_list` | the station is in that day's station list (flag is true when it is) | 0 not in list | 0 not in list |
| `temporary` | listed on fewer than half of the days | 10,893 | 10,919 |
| `event_station` | `capacity` 100 or more (regular stations have at most 78) | 63,722 | 63,774 |
| `capacity_conflict` | bikes + docks > capacity | 195,000 | 195,242 |
| `silent` | `lr_age_min` above 180 (three missed hourly reports) | 290,804 | 291,224 |
| `frozen` | in service and counts identical for 12 hours or more | 183,072 | 183,441 |
| `in_panel` | **selected for analysis**: `in_station_list` and not `temporary` and not `event_station` and not `frozen` | 24,740,954 selected | 24,779,975 selected |

`silent`, `capacity_conflict` and `partial_capture` do **not** remove a row from the panel.
Their rows stay in `in_panel` so the analysis can choose. Rows by `state`, VM1: ok
22,451,401, empty 1,175,158, full 721,585, out_of_service 650,481. VM2: ok 22,488,206, empty
1,175,938, full 722,441, out_of_service 651,508. The panel holds 1,515 stations on both VMs.

## 4. `clean/episodes.parquet`

Failure episodes, built on every capture of `in_panel` rows, on two sides kept apart: a
user who wants to rent and a user who wants to return need different things.

| Column | Meaning |
|---|---|
| `station_id` | station |
| `side` | `no_rent` (cannot rent: `can_rent` false) or `no_return` (cannot return: `can_return` false) |
| `cause` | state at the first capture: `out_of_service`, or `empty` (no_rent) / `full` (no_return) |
| `start`, `end` | first and last capture seen failing |
| `n_captures` | captures in the run |
| `duration_min` | `n_captures` × 5. The time the station was **seen** failing; the true episode can be up to one interval longer at each end |

An episode is a run of **at least 2 consecutive captures** (so at least 10 minutes). Two
captures are consecutive when less than 7.5 minutes apart, so a missing capture ends the
run instead of being bridged. VM1: 202,853 episodes. VM2: 203,012.

## 5. `daily_json/status_<date>.ndjson.gz` and `status_<date>.csv`

**NDJSON**: one complete day kept in its original shape. One **line per capture** (288 on a
full day), each holding the full payload of that capture.

| Field | Meaning |
|---|---|
| `fetched_at` | when we sent the request, ISO 8601 UTC |
| `lastUpdatedOther` | the feed's update marker |
| `ttl` | validity in seconds declared by the feed |
| `n_stations` | stations in that capture |
| `stations` | the station list, untouched, as published |

Careful with the shape: 288 lines, but about 288 × 1,520 station observations inside them.
Read it one line at a time:

```python
import gzip, json
with gzip.open("daily_json/status_2026-09-21.ndjson.gz", "rt", encoding="utf-8") as f:
    for line in f:
        capture = json.loads(line)
```

**CSV**: the same day as a flat table, one row per station per capture, for reading in
Excel. Same information as section 2, in a much larger file (about 38 MB per day).
Columns: `fetched_at`, `station_id`, `stationCode`, `num_bikes_available`, `mechanical`,
`ebike`, `num_docks_available`, `is_installed`, `is_renting`, `is_returning`,
`last_reported` (unix seconds), `last_reported_utc` (ISO 8601), `lr_age_min`.

## 6. Collection quality: `coverage_status.csv`, `coverage_info.csv`, `capture_quality.csv`

**`coverage_status.csv`** and **`coverage_info.csv`** (from `http_log.csv`), one row per day:

| Column | Meaning |
|---|---|
| `date` | the UTC day |
| `captured` | requests that returned 200 |
| `attempted` | requests made |
| `expected` | 288 (status) or 24 (info) |
| `coverage_%` | `captured` / `expected` |
| `check_ok`, `check_partial`, `check_bad` | the collector's own content check, per day. Zero until the check was introduced (02.11.2026 on VM1, 03.11.2026 on VM2) |

`captured` equals `attempted` on every line: no request failed (so there is no
`failed_attempts.csv`). Coverage is 100% on every full day. 20.09 is below 100% because
collection started in the evening. One day has 289 captures: 02.11 on VM1 and 03.11 on VM2, the day the content check first appears in each log.

**`capture_quality.csv`**: one row per archived status file, from `validate.py`, which
reads every file.

| Column | Meaning |
|---|---|
| `file`, `bytes`, `fetched_at`, `n_stations` | the file, its size, its moment, its station count |
| `missing_<field>` | stations lacking that field, for the 7 core fields plus `stationCode` and `num_bikes_available_types` |
| `check` | `ok`: all fields present. `partial`: counts, flags and `last_reported` complete, but `stationCode` / bike types missing. `bad`: unreadable, fewer than 1,400 stations, or a core field missing |
| `problem` | what is missing |

VM1: 16,330 `ok`, 122 `partial` (0.74% of captures), 0 `bad`. VM2: 16,355 `ok`, 123 `partial` (0.75%), 0 `bad`. Partial captures come in
blocks of 3 to 5 consecutive hours. They are kept and flagged (`partial_capture`).

## 7. Stations: `station_neighbours.csv`, `threshold_sensitivity.csv`

From `neighbours.py`, on the last hourly station list of the period.

**`station_neighbours.csv`**

| Column | Meaning |
|---|---|
| `station_id`, `stationCode`, `name`, `lat`, `lon`, `capacity` | copied from the station list |
| `nearest_m` | distance to the closest other station |
| `nearest_station_id` | which station that is |
| `n_within_200m`, `n_within_300m`, `n_within_500m` | other stations within each radius |

A station with `n_within_300m` equal to 0 is **isolated**. Distances are straight line, so
a real walk is longer and these counts are on the optimistic side.

**`threshold_sensitivity.csv`**, one row per radius (200, 300, 500): `threshold_m`,
`with_neighbour`, `isolated`, `share_with_neighbour_%`, `share_isolated_%`,
`mean_neighbours`. It shows that the 300 m choice is not arbitrary. On VM1: 39.3% of
stations have a neighbour within 200 m, 68.1% within 300 m, 88.5% within 500 m; the median
distance to the nearest station is 230 m.

## 8. Cleaning tables: `clean/cleaning_log.csv`, `clean/stations_daily.csv`

**`cleaning_log.csv`**: what each cleaning step did, in numbers.

| Column | Meaning |
|---|---|
| `step` | `truncated_captures`, `exact_duplicates`, `partial_captures`, `not_in_station_list`, `temporary_stations`, `event_stations`, `capacity_missing`, `capacity_conflict`, `silent`, `frozen`, `in_panel` |
| `rule` | the rule applied |
| `rows_before`, `rows_after` | rows in and out. Equal for every step here: nothing is dropped |
| `rows_flagged` | rows flagged. For `in_panel` it is the rows **selected** |

**`stations_daily.csv`**, one row per station per day: `date`, `station_id`, `name`,
`capacity`, `captures`, `in_station_list`, `temporary`, `event_station`, then the share of
that day's captures that were `out_of_service`, `empty`, `full`, `silent`, `frozen`,
`capacity_conflict` (columns `share_<name>`, between 0 and 1).

## 9. Why 5 minutes: `clean/last_reported_check.csv`, `clean/sampling_sensitivity.csv`

From `sampling_test.py`.

**`last_reported_check.csv`** (`measure`, `value`): how `last_reported` behaves (renewals
and count changes per station per hour, night and day; share of count changes under an
unchanged `last_reported`; median age).

**`sampling_sensitivity.csv`**: what the analysis would lose by sampling less often, with
the same episode rule. Columns: `side`, `sampling` (every 5 / 15 / 30 / 60 min, or one row
per `(station, last_reported)`), `rows_kept`, `episodes`, `episodes_vs_5min_%`,
`5min_episodes_seen_at_all_%`, `share_of_rows_failing_%`. On VM1, sampling every 15 minutes
keeps about 51 to 54% of the episodes found at 5 minutes, and sees about 92 to 93% of them
at all; every 60 minutes keeps about 16 to 17% and sees about 49 to 50%.

## 10. VM1 against VM2: `vm_comparison.csv`

One row per day, counted in 5-minute slots (captures of the two VMs are matched by the
slot they fall in): `date`, `vm1` (slots captured by
VM1), `vm2`, `union` (slots captured by at least one), `only_vm1`, `only_vm2`.

What the comparison shows on this dataset:

- On every day except 20.09, the two VMs captured exactly the same 5-minute slots
  (`only_vm1` and `only_vm2` are 0), and neither missed a slot. On 20.09, VM2 has 26 slots
  that VM1 does not: it started earlier (35 against 61 slots that day). So merging the two
  recovers nothing beyond those 26 slots.
- In 305 sampled slots where both VMs have a capture, the share of stations with identical
  counts was 100.0% in the median and 92.0% in the worst slot. When counts differ, the feed
  changed between the two requests, which are seconds apart.
- So the second collector is a check on reliability, not a second independent sample.

**VM1 and VM2 are not merged in this record.** They read the same feed independently, so
stacking their tables would count each station twice per slot. Process them separately, or
merge by 5-minute slot as a documented step of the analysis.

## 11. How we define a failure

The rules the analysis applies, written down so that every group member computes the same
number.

| Concept | Rule |
|---|---|
| Empty | 0 bikes available. Working, but you cannot rent |
| Full | 0 free docks. Working, but you cannot return |
| Out of service | not installed, or neither renting nor returning |
| Failure episode | the same side failing in at least 2 consecutive captures (section 4) |
| Viable alternative | another station within 300 m, not failing at the same moment |
| Isolated station | no other station within 300 m |

We never merge these into one "failure" count: an empty station can be working perfectly,
and the feed cannot tell a broken station from one that stopped reporting.

## 12. Known limits

- **Resolution.** Captures are 5 minutes apart and `last_reported` is hourly. Events
  shorter than about 10 minutes are not seen. Collecting faster would multiply storage
  by about 5 at 1 minute, and the stations report hourly anyway.
- **Not instantaneous.** A capture is the feed's state when we asked, not the true state.
- **Cut.** Data stops at 16.11.2026 23:59:59 UTC. The collectors kept running after, but
  later captures are not in this record.
- **Partial days.** 20.09 is incomplete on both VMs (collection began in the evening, VM2
  at 18:57 UTC and VM1 at 21:05 UTC).
- **Station list changes.** Stations appear and disappear (temporary and event stations are
  flagged, section 3).
- **Source and licence.** Data from Vélib' Métropole / Smovengo, redistributed under the
  Open Data Commons Open Database License (ODbL), with attribution.

## 13. Not in this record

External sources the project may add later, both static and downloadable at any time:
IGN ADMIN-EXPRESS commune boundaries and INSEE population by commune.
