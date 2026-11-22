# Vélib' project: raw data quality and cleaning (one page)

Group H. Kenza Gueddas, Adem Ben Njima, Lara Normand, Amine Ben Bachir Hassani, Adrien Labergère.
First version 03.11.2026, updated 22.11.2026 (full collection).

Detail and evidence: `data_quality_and_cleaning.pdf`. Data: DOI 10.5281/zenodo.24444738.

**Data.** The GBFS `station_status` feed, captured every 5 minutes by two collectors (VM1 and VM2) from 20.09 to 16.11.2026 23:59:59 UTC (58 days, UTC throughout). VM1: 16,452 captures, 24,998,625 station rows, 1,527 station ids. VM2: 16,478 captures, 25,038,093 rows. The two series are never merged; the figures below are VM1's, and VM2 gives the same picture.

## Quality of the raw data

| Level | What we found |
|--------|----------------------------------------|
| Collection | 288 of 288 captures on each of the 57 full days, on both VMs; no failed request, no capture quarantined, longest gap between two captures 5 minutes. Each VM holds every 5-minute slot, so merging them would add none. |
| File content | 0.74% of captures are partial (122 on VM1, 123 on VM2): bike and dock counts present, `stationCode` and mechanical / electric split missing. 120 fall in the same slot on both VMs, so the cause is the server, not us. No truncated capture in 16,452 files. |
| Reliability of our own capture | On 305 slots caught by both VMs, the median share of stations with identical counts is 100% (minimum 92.0%): a capture is close to instantaneous. No exact duplicate on one machine. |
| Meaning | `last_reported` is not the time of the counts: it renews about once an hour, and 89.4% of count changes happen while it is unchanged. |
| Stations | 1,515 regular stations, 8 temporary ones and 4 event stations (Concorde, Invalides, Tour de France, Vincennes racecourse; 100+ docks); 12 stations with capacity 0 or missing; 0.78% of rows with bikes + docks above capacity; 271 silent and 326 frozen stations at some point. 2.6% of rows are out of service, 18 stations for the whole period: a real failure for users, so kept. |

## Main cleaning choices, and why

We **flag, we do not alter**: the feed is our only source, so nothing can correct a count. Rows are dropped only when they carry no information, and on the full period that rule removed no row; every other problem is a boolean column, and `in_panel` combines them so each exclusion stays visible and reversible.

1. **Drop** captures with fewer than 1,400 stations (network: about 1,519) and repeated `(station_id, fetched_at)` rows. **Keep** partial captures, since availability only needs the counts.
2. **Match each day with that day's station list**, because the network changes during the period.
3. **Exclude temporary and event stations** (100+ docks) from the panel: they would count as failures or as false alternatives.
4. **Keep every capture, no deduplication on `last_reported`.** At one capture per hour, or with our old plan, only about half of the 5-minute episodes remain visible (50.3% and 51.1%) and the share of time without a bike drops from 6.94% to 6.12% with the old plan.
5. **Flag** silent (`last_reported` older than 180 min) and frozen stations (identical counts for 12 h or more); capacity 0 becomes unknown, capacity conflicts are flagged, not corrected.

Result: the panel keeps 24,740,954 of 24,998,625 rows (98.97%) and 1,515 stations.

## What the cleaned data already shows (VM1, full period)

| Measure | Value |
|-----------------|--------------------------|
| Share of time a station cannot rent / cannot take a return | 6.94% / 5.21% |
| Failure episodes (at least 2 consecutive captures) | 124,950 no-bike and 77,903 no-dock, at 1,500 stations; 1,134 last 24 h or more |
| Median observed duration | 25 min (no bike), 20 min (no dock); 55% of no-bike episodes last under 30 min |

Durations are what we saw: a real episode can be up to 5 minutes longer at each end.

## Storage

On one cleaned day (21.09), Parquet partitioned by date and read with DuckDB takes 1.8 MB for 29 columns, against 46.8 MB for 8 columns in SQLite, and scans faster (10 ms vs 63 ms for the share of time without a bike). SQLite is faster for one-station lookups (0.4 ms vs 7 ms). Our queries are mostly scans, so we keep Parquet, and will measure again on the whole period.

## Limits and what is still open

- Eight weeks of autumn: no winter, no summer. Demonstrations in Paris after the 29.09 snapshot closed or damaged some stations; in the analysis we mark those days and report the results with and without them.
- The counts are renewed at least every 5 minutes, but the feed does not say how long after an event they change, so a short delay may remain.
- The VMs sit in the same cloud region: a regional outage would hit both. None showed up in the logs.
- Not yet done: the commune boundaries (IGN) and population (INSEE), joined in the analysis step as context only.
