#!/usr/bin/env python3
"""Build data/external/station_communes.csv: one commune (and its population) per station.

Source: API Géo (geo.api.gouv.fr, Etalab / INSEE / IGN), endpoint /communes?lat=&lon=.
It returns the commune that contains the point, with INSEE code, name and population.
Run once from the repository root:  python code/build_station_communes.py
Needs: pandas, requests. Takes about 5 to 10 minutes (one polite request per station, cached).

Output columns (what notebook section 0.4 expects):
  station_id, insee_code, commune, is_paris, population, population_year
`population_year` is left as "to_check": API Géo does not state the census year in the reply.
Look it up on the API Géo documentation page on the access date and write it into the CSV and
into SOURCES.md (do not guess it).
Stations that fall in no commune (point in the Seine, or outside France) are listed in
station_communes_unmatched.csv for a hand check; they stay out of the main file until fixed.
"""
import json, sys, time
from pathlib import Path
import pandas as pd
import requests

ROOT = Path(__file__).resolve().parents[1]
NEIGH = next((ROOT / "data").rglob("station_neighbours.csv"))       # station_id, lat, lon, ...
OUT = ROOT / "data" / "external" / "station_communes.csv"
CACHE = ROOT / "data" / "external" / "api_geo_cache.json"
URL = "https://geo.api.gouv.fr/communes"

def lookup(session, lat, lon):
    r = session.get(URL, params={"lat": lat, "lon": lon, "fields": "code,nom,population", "format": "json"}, timeout=30)
    r.raise_for_status()
    data = r.json()
    return data[0] if data else None

def main():
    st = pd.read_csv(NEIGH, dtype={"station_id": str})[["station_id", "lat", "lon"]]
    cache = json.loads(CACHE.read_text()) if CACHE.exists() else {}
    s = requests.Session()
    s.headers["User-Agent"] = "velib-student-project (ESSEC, Group H)"
    for n, r in enumerate(st.itertuples(), 1):
        if r.station_id in cache:
            continue
        for attempt in range(3):
            try:
                cache[r.station_id] = lookup(s, r.lat, r.lon); break
            except requests.RequestException as e:
                print(f"  retry {attempt + 1} for {r.station_id}: {e}"); time.sleep(2 * (attempt + 1))
        else:
            sys.exit("API Géo unreachable: stop here, re-run later (the cache keeps what was done)")
        if n % 100 == 0:
            CACHE.write_text(json.dumps(cache)); print(f"  {n}/{len(st)}")
        time.sleep(0.05)
    CACHE.write_text(json.dumps(cache))
    rows, bad = [], []
    for r in st.itertuples():
        c = cache.get(r.station_id)
        if not c:
            bad.append({"station_id": r.station_id, "lat": r.lat, "lon": r.lon}); continue
        rows.append({"station_id": r.station_id, "insee_code": c["code"], "commune": c["nom"],
                     "is_paris": c["code"] == "75056", "population": c.get("population"),
                     "population_year": "to_check"})
    pd.DataFrame(rows).to_csv(OUT, index=False)
    print(f"{len(rows)} stations written to {OUT.relative_to(ROOT)}; {len(bad)} without a commune")
    if bad:
        pd.DataFrame(bad).to_csv(OUT.with_name("station_communes_unmatched.csv"), index=False)
        print("  see station_communes_unmatched.csv: fix by hand, then add the rows to the main file")
    print(pd.DataFrame(rows).groupby("is_paris").size().rename("stations").to_string())
    print("Next: fill in population_year, update data/external/SOURCES.md (URL, access date, licence).")

if __name__ == "__main__":
    main()
