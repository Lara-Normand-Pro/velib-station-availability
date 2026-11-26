# External data sources

Everything in `data/external/` that does not come from the Vélib' feed. One block per source. Raw downloads of large files are not committed; the small derived files and the script that builds them are.

Rule: another student must be able to redo the join from this file alone. Record the exact edition, the date you accessed it, and a checksum.

## Derived file

| File | Rows | Built by | Date built |
|---|---|---|---|
| `station_communes.csv` | one per station | `<script path>` | `<YYYY-MM-DD>` |

Columns: `station_id`, `insee_code`, `commune`, `is_paris`, `population`, `population_year`.

Checks done (tick when done):
- [ ] every panel station (1,515) has exactly one commune
- [ ] stations near the Paris boundary (Boulogne, Neuilly, Montreuil, ...) checked by hand
- [ ] number of Paris stations compared with a known figure
- [ ] any station outside Île-de-France flagged

## Source 1: commune boundaries or reverse lookup

| Item | Value |
|---|---|
| Name | `<API Géo "Découpage administratif" / IGN ADMIN EXPRESS / other>` |
| URL | |
| Product and edition (millésime) | |
| Date accessed | |
| Licence | `<Licence Ouverte 2.0 / other, check the exact wording>` |
| File name and sha256 of the download | |
| Notes | |

## Source 2: population

| Item | Value |
|---|---|
| Name | INSEE, Populations de référence 2023 (candidate; confirm) |
| URL | |
| Reference date | population at 1 January 2023, commune limits of 1 January 2025 (confirm on the page) |
| Date accessed | |
| Licence | |
| File name and sha256 of the download | |
| Notes | Paris: use the whole commune (INSEE code 75056) for "Paris vs rest". The vintage (2023) differs from the Vélib' data (autumn 2026): state it. |

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
