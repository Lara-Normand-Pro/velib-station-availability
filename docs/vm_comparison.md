# VM1 vs VM2: reliability of our own collection

Run with `code/compare_vms.py` on the two raw archives, cut at 16.11.2026 23:59:59 UTC
(first version 03.11.2026, updated 22.11.2026). Per-day table: `data/vm_comparison.csv`.

| | VM1 | VM2 |
|---|---|---|
| Start of collection | 20.09.2026 21:05 UTC | 20.09.2026 18:57 UTC |
| Status captures archived | 16,452 | 16,478 |
| Distinct 5-minute slots | 16,451 | 16,477 |
| Station lists (hourly) | 1,371 | 1,374 |
| Failed requests, quarantined captures | 0, 0 | 0, 0 |

One slot on each machine holds two captures (VM1 on 02.11, VM2 on 03.11), which is why captures
exceed slots by one.

## Results

**1. Both machines caught every capture on every full day.**
From 21.09 to 16.11 (57 days), each VM has 288 captures a day, with no gap longer than 5 minutes.
Over the whole period the union of the two machines (16,477 slots) is the same as VM2 alone, so
merging the two archives recovers nothing that one machine alone did not already have.

**2. The only slots caught by one machine are explained by the calendar, not by failures.**

| Day | Only VM1 | Only VM2 | Reason |
|---|---|---|---|
| 20.09 | 0 | 26 | VM2 started at 18:57 UTC, VM1 at 21:05 UTC |
| 21.09 to 16.11 | 0 | 0 | none |

**3. Two requests a few seconds apart read nearly the same feed.**
On 305 slots compared (a sample of the slots caught by both VMs), the share of
stations with identical bike and dock counts is 100% at the median and 92.0% at the minimum. The
feed does change between two requests made seconds apart, but only for a small part of the
stations, so a capture is close to instantaneous.

**4. The partial captures come from the server, not from our machines.**
Version 1 of the collector archived whatever the server returned. In the archives, 122 captures
on VM1 and 123 on VM2 (0.74% and 0.75%) are partial: station counts are present, but
`stationCode` and the bike types are empty, and the file is about 24 KB instead of about 34 KB.
120 of them fall in the same 5-minute slot on both machines. They are spread over all 24 hours of
the day. The same degraded answer reaches both machines at the same moment, so the cause is on the
Vélib' side. The first one is on 21.09 at 22:50 UTC, the one reported after the first peer review,
and the last on 16.11 at 13:15 UTC. Version 2 of the collector flags them as `partial` in the log;
it still archives them, and only files that fail the core check go to `quarantine/` (none did).

## What it changes for the project

- The counts (`num_bikes_available`, `num_docks_available`), which the failure episodes use,
  are present in the partial captures, so they are kept for the analysis. Only the bike-type
  split is unavailable for about 0.7% of the captures.
- One machine would have been enough over this period. The second one is a safeguard, and its
  archive is a check of the first. We use VM1 as the main series and do not merge the two.
- The two VMs sit in different regions (Denmark East and Sweden Central), so a regional outage would not have hit both. We saw no gap in either log.
