# Vélib' project: raw data quality and cleaning

Group H. Kenza Gueddas, Adem Ben Njima, Lara Normand, Amine Ben Bachir Hassani, Adrien Labergère.
First version 03.11.2026, updated 22.11.2026 with the full collection (20.09 to 16.11.2026).

## Our question, made precise after peer review

**How often does a Vélib' station fail its users (no bike to rent, or no free dock to return)
while no other station within 300 m of it can serve them instead, and does this differ between
Paris and the surrounding communes?**

Three points are explicit, as Group I suggested. Distances are measured from station to
station, not from the user, because user positions are not in the data and the user is already at
a station when the problem happens. Renting and returning are studied separately: a station with
no bikes can still take returns. The comparison unit is the commune, summarised as Paris versus
the rest of the network. The 300 m is the spacing Vélib' Métropole gives for Paris
(velib-metropole.fr/communes/paris, accessed 11.10.2026); our sensitivity check at 200, 300 and
500 m is unchanged.

## What we checked, and on what

The figures below cover the whole collection: every `station_status` capture from 20.09.2026 to
16.11.2026 23:59:59 UTC (all times are UTC). Two collectors ran in parallel, VM1 and VM2, and
their data are never merged. The figures are those of VM1; VM2 gives the same picture
(for example 202,853 and 203,012 failure episodes). Everything can be reproduced from the
Zenodo record (DOI 10.5281/zenodo.24444738) with `python code/run_all.py --vm vm1 --no-bench`.

We assessed quality at five levels, from the collection down to the meaning of one field:

| Level | What can go wrong | How we check | Script |
|---|---|---|---|
| Collection | missing captures, failed requests | HTTP log vs 288 expected per day | `coverage.py` |
| File content | a 200 response with incomplete content | every station, every field, every file | `validate.py` |
| Rows | duplicates, impossible values | counts vs capacity, exact duplicates | `clean.py` |
| Stations | stations that come and go, freeze or go silent | same-day station list, run lengths | `clean.py` |
| Meaning | a field that does not mean what we assumed | `last_reported` vs the counts | `sampling_test.py` |

## Findings

| Problem | Evidence (VM1, full period) | Effect on our question | Decision |
|---|---|---|---|
| Collection gaps | 57 full days, all with 288 captures; 16,452 captures in total; 0 failed requests; the longest gap between two captures is 5 minutes | none | nothing to repair |
| Incomplete capture | 122 captures (0.74%; VM2: 123): `stationCode` and the mechanical / electric split missing for every station, file of about 24 KB instead of 34 KB. They occur at all 24 hours, the first on 21.09 at 22:50 UTC. 120 fall in the same 5-minute slot on both machines: the cause is the server, not our collectors (`docs/vm_comparison.md`) | none on availability: bike and dock counts are present | keep, flag `partial_capture` (185,378 rows); `collect.sh` v2 checks content |
| Truncated or unreadable capture | none in 16,452 files (1,517 to 1,525 stations each) | would distort a whole time step | rule kept: drop any capture with fewer than 1,400 stations; it removed 0 rows |
| Exact duplicates | none on one machine | would appear if the two VMs were merged | drop repeated `(station_id, fetched_at)`; removed 0 rows |
| Stations entering and leaving | 1,527 station ids in 58 days: 1,515 regular, 8 `temporary` (listed on under half of the days, for example Argenteuil), 4 event stations: Concorde (409 docks), Invalides (410), "Station Tour de France" (204), Vincennes racecourse (100) | a station that is not really part of the network would count as a failure or as an alternative | match each day with that day's station list; flag `temporary` (10,893 rows) and `event_station` (63,722 rows); exclude both from the panel |
| Missing capacity | 12 stations with capacity 0 or missing (45,498 rows, 0.18%) | `docks_unavailable` cannot be computed | capacity set to unknown, station kept |
| Counts above capacity | 195,000 rows (0.78%): bikes + docks exceed capacity | small; counts are what users see | flag `capacity_conflict`, keep the counts |
| Out of service | 2.6% of rows; a median of 23.5 stations out of service for a whole day, and 18 stations out of service for at least 99% of the period | a real failure for users | kept, counted on both sides |
| Silent stations | 271 stations have `last_reported` older than 3 h at some point (290,804 rows, 1.16%), mostly out of service | their counts may be stale | flag `silent`; decide per analysis |
| Frozen stations | 326 stations in service with identical counts for 12 h or more at some point (183,072 rows, 0.73%) | a stuck sensor would read as a long failure | flag `frozen`, exclude those rows from the panel |
| `last_reported` misread | see next section | our planned deduplication would have removed most episodes | dropped the deduplication; keep every capture |

## The main correction: what `last_reported` is

On 29.09 we read `last_reported` as the moment the counts were measured. From that we concluded
that stations report every half hour, that most of our rows repeated an earlier report, and that
we should keep one row per distinct `last_reported`. Group I showed this reading was wrong, and our
own check (`sampling_test.py`) confirms it on the whole period:

| Measure (full period) | Value |
|---|---|
| Consecutive captures with unchanged `last_reported` where the counts changed | 28.5% |
| Count changes that happen while `last_reported` is unchanged | 89.4% |
| `last_reported` renewals per station per hour, night (00-05 UTC) / day (06-19 UTC) | 1.12 / 1.24 |
| Count changes per station per hour, night / day | 1.03 / 4.52 |
| Median age of `last_reported` when we read it | 32.9 min |

`last_reported` renews about once an hour, day and night alike, while the counts follow the
activity of the city. It behaves like an hourly signal from the station, not a measurement time.
The 33 minutes we first read as a delay is simply the typical age of an hourly timestamp, and the
91.4% of rows that repeat an earlier `(station, last_reported)` pair is 11 captures out of 12. We
renamed the column `lr_age_min` (it was `lag_min`) so nobody reads it as a delay of the counts.

We then tested what our plan would have cost, by recounting episodes with the same rule (at
least two consecutive kept captures) on coarser data:

| Kept data (cannot rent) | Episodes | Share of the 5-min episodes | 5-min episodes still seen | Share of rows failing |
|---|---|---|---|---|
| Every capture (5 min) | 124,950 | 100% | 100% | 6.94% |
| One capture every 15 min | 67,149 | 53.7% | 93.1% | 6.94% |
| One capture every 30 min | 38,374 | 30.7% | 73.2% | 6.92% |
| One capture every 60 min | 20,470 | 16.4% | 50.3% | 6.92% |
| One row per `last_reported` (our old plan) | 21,041 | 16.8% | 51.1% | 6.12% |

Coarser sampling barely changes the share of time without a bike, but it erases episodes: at
60 minutes or with our old deduplication, only about one episode in six is still counted and half
are not seen at all. The deduplication also biases the share of time downwards (6.12% instead of
6.94%), because it keeps the first row of each hour. Since 55% of no-bike episodes last less than
30 minutes, this is exactly the part of the answer we would have lost. The returning side gives
the same picture (`data/vm1/clean/sampling_sensitivity.csv`): 77,903 episodes at 5 minutes,
17.2% kept at 60 minutes. This also answers Prof. Pascual's question on the 5-minute interval: it
is the rate at which the counts actually move.

What we still cannot know: the counts are renewed at least every 5 minutes, but the feed does not
tell us how long after an event they change, so a short delay may remain.

## Cleaning procedure and why

**Principle: we flag, we do not alter.** The feed is our only source, so we have nothing to
correct a count against. Rows are removed only when they carry no usable information (a truncated
capture, an exact duplicate). Every other problem becomes a boolean column, and the analysis uses
one column, `in_panel`, so each exclusion is visible and can be reversed. On the full period the
two removal rules did not remove a single row; all the cleaning is done by flags.

1. **Captures.** Drop captures with fewer than 1,400 stations (the network has about 1,519).
   Keep partial captures: availability only needs the counts.
2. **Duplicates.** Drop repeated `(station_id, fetched_at)`. Needed only if the two VMs are merged.
3. **Same-day station list.** Join each day's status with the station list of that same day
   (union of its 24 hourly lists for membership, the last one for coordinates and capacity), as
   Group I suggested. A station absent from that day's list is flagged.
4. **Temporary and event stations.** `temporary`: listed on fewer than half the days of the
   period. `event_station`: capacity of 100 docks or more. Regular stations stop at 78 docks;
   above that we only find Concorde, Invalides, "Station Tour de France" and the Vincennes
   racecourse. Presence alone would miss the first two, which stay listed for weeks while open
   one day. Both are excluded from the panel, as failing stations and as alternatives.
5. **Capacity.** Capacity 0 becomes unknown. `docks_unavailable = capacity - bikes - free docks`;
   negative values are flagged as conflicts, not corrected.
6. **Service and the two sides.** `can_rent`: installed, renting and at least one bike.
   `can_return`: installed, returning and at least one free dock. `state` keeps the descriptive
   categories (out of service, empty, full, ok). We still never write "broken": the feed cannot
   tell a broken station from one that stopped reporting.
7. **Silent.** `last_reported` older than 180 minutes, three missed hourly signals.
8. **Frozen.** Counts identical for 12 hours or more while in service. On 21.09 the longest
   unchanged run is under 6 h for 95% of stations, so 12 h leaves a wide margin before we call a
   quiet station stuck.
9. **Panel.** `in_panel` = in the same-day list, not temporary, not an event station, not frozen.

On the full period the panel keeps 24,740,954 of 24,998,625 rows (98.97%) and 1,515 stations. In
it, a station cannot rent 6.94% of the time and cannot take a return 5.21% of the time.

**Episodes** (`episodes.py`) are built on every capture: a run of at least two consecutive
captures where the station cannot rent (or cannot take a return). On the full period: 124,950
no-bike and 77,903 no-dock episodes, at 1,500 stations. The median no-bike episode is observed for
25 minutes, the median no-dock one for 20; 90% last 95 minutes or less, and only 1,134 episodes
(under 1%) last 24 hours or more. Durations are what we saw: the true episode can be up to
5 minutes longer at each end.

## Storage: first comparison

`storage_benchmark.py` loads the cleaned day 21.09 into SQLite (primary key on station and time,
index on time) and compares it with our date-partitioned Parquet read by DuckDB, on the three
queries the analysis needs. This comparison was made on that one day (437,184 rows); we did not
rerun it on the whole period (`--no-bench`).

| 21.09, 437,184 rows | SQLite | Parquet + DuckDB |
|---|---|---|
| Size on disk | 46.8 MB (8 columns) | 1.8 MB (all 29 columns) |
| Q1: share of time each station cannot rent (full scan) | 63 ms | 10 ms |
| Q2: one station's timeline (one station) | 0.4 ms | 7 ms |
| Q3: the whole network at one capture (one moment) | 4.6 ms | 36 ms |

Parquet is about 25 times smaller with more columns, and faster on scans, which is most of our
analysis. SQLite wins the selective lookups thanks to its indexes. Q3 is what the "viable
alternative" rule repeats for every capture, so we will run it once as a grouped query rather than
as many lookups, and measure again on the whole period before choosing.

## Still open

- The two machines are not merged: VM1 is the main series, and VM2 is a reliability check.
  Both machines hold every 5-minute slot of the 57 full days (`docs/vm_comparison.md`), so a merge
  would add no capture.
- The commune of each station, from API Géo (IGN contours), joined in the analysis step. Its
  population figure is not used in any result; population counts residents, never affected users.
- Demonstrations and riots in Paris after the 29.09 snapshot appear in the data collected later
  (stations closed or damaged). In the analysis we will mark those days and report the results
  with and without them.
- Eight weeks of autumn: no winter and no summer, so the results describe this season only.
