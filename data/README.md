# data/

This folder is empty on purpose: the data is too large for Git and is published on Zenodo.

Download the record (DOI: **10.5281/zenodo.24444738**), unpack the raw archives into `vm1/` and `vm2/`
at the root of this repository, then run:

    python code/run_all.py --vm vm1 --no-bench
    python code/run_all.py --vm vm2 --no-bench

The results are written here, in `data/vm1/` and `data/vm2/`. Alternatively, unpack
`vm1_parquet.tar` and `vm2_parquet.tar` from the record into `data/vm1/` and `data/vm2/`
to skip the two-hour rebuild. See `DATA_DICTIONARY.md` for every table and column.

`data/external/` is the exception: it holds the small hand-made tables that the notebook reads. `station_communes.csv`
gives the commune of each station and comes from API Géo (see `external/SOURCES.md`); its population column is not
used in any result. `events.csv` lists the events of the period with their sources.
