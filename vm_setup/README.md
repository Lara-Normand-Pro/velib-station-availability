# VM setup: how the data was collected

This folder explains how to rebuild the collection setup, if you want to log the Vélib' feed yourself.
The past state of the feed cannot be re-fetched (it publishes no history), which is why the raw captures
are archived on Zenodo. To collect a new series, follow the steps below.

The collectors are plain Linux machines with `cron`. Two identical VMs (VM1 and VM2) ran in parallel from
20 September 2026 and were never merged: the second one is a reliability check.

## What you need

- A small always-on Linux machine (we used Ubuntu 24.04 on a small cloud VM, region France Central).
  Any machine that stays on 24/7 works.
- `bash`, `curl`, `cron` and `python3` (only used for the content check inside `collect.sh`).
- Little disk space: two months of compressed captures were about 0.7 GB per VM, so any default disk is enough.
- Outbound HTTPS access. The feed is open: no account and no API key.

## 1. Create the machine

1. Create an Ubuntu 24.04 VM (smallest size is enough) with **SSH key authentication**.
2. Keep the private key on your laptop only. Never put it in a repository.
3. Connect with `ssh -i <your-key> <user>@<vm-address>`.
4. Check that the clock is in UTC and synchronised:

```bash
timedatectl
```

You want `System clock synchronized: yes`. All file names and logs use UTC.

## 2. Install the collector

Copy `collect.sh` (from `code/` in this repository) to the home directory of the VM and make it executable:

```bash
scp -i <your-key> code/collect.sh <user>@<vm-address>:~/
ssh -i <your-key> <user>@<vm-address> 'chmod +x ~/collect.sh'
```

What `collect.sh status` / `collect.sh info` does on each run:

1. Downloads `station_status.json` (or `station_information.json`) from the public Vélib' Métropole GBFS feed.
2. Opens the file and checks it (valid JSON, at least 1,400 stations, required fields present).
3. Archives it as `~/velib/<feed>/<YYYY-MM-DD>/<YYYYMMDDTHHMMSSZ>.json.gz` (UTC capture time in the name).
   A capture that fails the check is not deleted: it goes to `~/velib/quarantine/` instead.
4. Appends one line to `~/velib/http_log.csv`:
   `timestamp,feed,http_code,bytes,n_stations,check` where `check` is `ok`, `partial`, `bad` or `error`.

The script never modifies or deletes anything it already saved.

## 3. Schedule it

Open the crontab with `crontab -e` and add the two lines from `code/crontab.txt`:

```
*/5 * * * * $HOME/collect.sh status
0 * * * * $HOME/collect.sh info
```

That is one `station_status` capture every 5 minutes (288 per day) and one `station_information`
capture every hour (24 per day).

## 4. Check that it works

After 24 hours:

```bash
ls ~/velib/status/$(date -u +%F) | wc -l      # should approach 288 for a full day
tail -3 ~/velib/http_log.csv                  # codes should be 200, check should be ok
```

A weekly look at these two lines is enough to catch an outage early.

## 5. Second machine (optional)

We ran a second identical VM in parallel. In our data, where both collected the same slot, the content is
nearly identical, so the second VM acts as a reliability check rather than as an independent sample. If you
do the same, keep each VM's data separate and do not merge the two series.

## 6. Pack the raw data

At the end of the collection, run `pack_vm.sh` on each VM. It does not stop the collector and does not change
anything in `~/velib`.

```bash
scp -i <your-key> code/pack_vm.sh <user>@<vm-address>:~/
ssh -i <your-key> <user>@<vm-address> 'bash pack_vm.sh vm1 2026-11-16'
```

Replace `vm1` by `vm2` on the second machine. The cut date is in UTC, and only complete days up to and
including that date are packed. The output is, in the home directory of the VM:

```
velib_<vm>_raw.tar
velib_<vm>_raw.tar.sha256
velib_<vm>_summary.txt
```

Download them with `scp` and check the hash after the copy:

```bash
sha256sum -c velib_vm1_raw.tar.sha256
```

## 7. From the raw tar to the tables

The processing pipeline (Parquet, NDJSON, CSV, cleaning, episodes, VM comparison) is described in the main
`README.md` and in `DATA_DICTIONARY.md`. Typical use: unpack the tar into `vm1/`, install
`code/requirements.txt`, then run `python code/run_all.py --vm vm1 --no-bench`.

## Things to keep in mind

- **Security:** do not commit your private key, the VM address or any credential. The `.gitignore` of this
  repository already blocks `*.pem`, `*.key` and `.env`.
- **Cost:** a small VM running two months costs little, but set a budget alert in your cloud account and
  delete the VM when the collection is finished.
- **Before deleting a VM:** make sure the packed files are downloaded, the hashes match, and you have two
  copies (ours are in the Zenodo record).
- **Limits of the feed:** sampling every 5 minutes cannot see shorter changes, and the feed's
  `last_reported` field is an hourly station signal, not the measurement time.
