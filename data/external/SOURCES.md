# External data sources

Everything in `data/external/` that does not come from the Vélib' feed. One block per source. Raw downloads of large files are not committed; the small derived files and the script that builds them are.

Rule: another student must be able to redo the join from this file alone. Record the exact edition, the date you accessed it, and a checksum.

## Derived file

| File | Rows | Built by | Date built |
|---|---|---|---|
| `station_communes.csv` | one per station (1,525) | `code/build_station_communes.py` | 24.11.2026 (date of the saved file) |

Columns: `station_id`, `insee_code`, `commune`, `is_paris`, `population`, `population_year`. The notebook uses `is_paris` and `commune` (Paris against the rest, section 7) and `insee_code` (map outlines). It does not use `population` in any result.

## Source 1: commune of each station (the only external source we used for communes)

| Item | Value |
|---|---|
| Name | API Géo, "Découpage administratif" (geo.api.gouv.fr), reverse lookup by latitude and longitude |
| URL | https://geo.api.gouv.fr/communes?lat=...&lon=... (endpoint used by `code/build_station_communes.py`) |
| Product and edition (millésime) | Current API at the access date; the reply does not state an edition |
| Date accessed | November 2026 (file saved 24.11.2026) |
| Licence | Open licence (Licence Ouverte); check the exact version on the API Géo page |
| File name and sha256 of the download | None: the script calls the API about 1,500 times and caches the answers; the result is committed as `station_communes.csv` |
| Notes | We planned separate IGN ADMIN-EXPRESS boundaries and INSEE population files (proposal). We used API Géo instead: one small reproducible call, a committed result, no geo libraries and no large boundary download. The question only needs the commune of each station. |

## Source 2: population (not used)

| Item | Value |
|---|---|
| Name | `population` field returned by API Géo with each commune |
| Status | Stored in `station_communes.csv`, used in no result. No separate INSEE file was downloaded. |
| Reference year | Not stated in the API reply, so `population_year` is "not stated by API Géo" |
| Notes | Population counts residents, not Vélib' users, so we never read it as "people affected". It would also not match the data period (autumn 2026). |

## Source 3: events (demonstrations, closures, damage) between 20.09 and 16.11.2026

File: `events.csv`, one row per event. Columns: `event_id`, `date_start`, `date_end` (Paris dates, inclusive), `kind` (`mobilisation`, `violence`, `planned_closure`, `visit`), `label` (short, used in figures), `description`, `source_url`, `source_type` (primary or secondary), `access_date`, `status`, `exclude_from_baseline`.

Purpose, in this order:
1. **Validation**: events known from independent sources, dated before looking at the data, that the measure should detect (notebook section 6). Closures are the clearest signal (about 110 stations, 7% of the network); vandalism (6 stations damaged on 17.10) is only visible at station level.
2. **Robustness**: results with and without the days flagged `exclude_from_baseline`.
3. **Context** for the replay (section 10). Bike counts reported in the press (destroyed or stolen bikes) are context only: the feed cannot show them.

Rules: every row has a URL and an access date; `status` stays `to_verify` until someone has opened the source and checked the date, the figure and the wording (prefer the operator's posts, the prefecture and the Interior Ministry over press summaries); do not describe causes, only dates and sourced facts. The first draft of this file comes from a web search on 22.11.2026 read through search excerpts only.

Optional station-level check: for a closure, copy the operator's list of closed stations into `closed_stations_<event_id>.csv` with a `stationCode` column (list the access date in the row of `events.csv`).

## Source 4: the 300 m distance

| Item | Value |
|---|---|
| Claim | Vélib' Métropole states that there is a station every 300 m in Paris |
| URL | https://www.velib-metropole.fr/communes/paris |
| Date accessed | 11.10.2026 (noted by the group; page not reachable again on 23.11.2026, HTTP 403, so the wording was not re-read) |
| Scope | Paris only. The page does not say it holds for the suburbs, and our data show it does not (about 76% of the stations outside Paris have no other panel station within 300 m). |
| Use in the project | Starting value for the "viable alternative" rule; 200 m and 500 m tested in notebook section 7.4 |
| To do | Someone opens the page again, checks the exact wording and copies the sentence (under 15 words) here |

## Optional sources (only if the group decides to add them)

Weather (Open-Meteo), school holidays (zone C), Paris bike counters, BAN geocoding. Add a block like the ones above for each, or leave this section empty.

## Limits to state in the report

- A commune is an administrative unit, not a catchment area.
- Population counts residents, not Vélib' users.
- Population year and boundary year do not match the data period.
