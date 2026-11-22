#!/bin/bash
# Pack the raw captures of ONE VM into a tar file, cut at an end date (UTC).
#
# Run it ON THE VM (copy it there first: scp code/pack_vm.sh user@vm:):
#     bash pack_vm.sh vm1                 # cut at 2026-11-16 (UTC), the default
#     bash pack_vm.sh vm1 2026-11-16      # same, explicit
#
# The collector KEEPS RUNNING and nothing in ~/velib is changed or deleted. Only complete
# days up to and including END (UTC) are packed, and the HTTP log copy is cut at the end of
# that day, so the last possible capture is END 23:59:59 UTC.
#
# Output, in $OUT (default $HOME):
#     velib_<vm>_raw.tar   velib_<vm>_raw.tar.sha256   velib_<vm>_summary.txt
# Optional environment: VELIB_DIR (default $HOME/velib), OUT (default $HOME), FORCE=1.
#
# Inside the tar: velib/status/<date>/, velib/info/<date>/, velib/quarantine/{status,info}/<date>/
# (only days <= END) and velib/http_log.csv (lines up to END only).

set -euo pipefail

VM=${1:?usage: bash pack_vm.sh vm1|vm2 [END_DATE YYYY-MM-DD]}
END=${2:-2026-11-16}
SRC=${VELIB_DIR:-$HOME/velib}
OUT=${OUT:-$HOME}

[[ "$END" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "END must look like 2026-11-16"; exit 1; }
[ -d "$SRC/status" ] || { echo "no $SRC/status: wrong VELIB_DIR?"; exit 1; }
TODAY=$(date -u +%Y-%m-%d)
if [[ ! "$END" < "$TODAY" ]] && [ "${FORCE:-0}" != 1 ]; then
  echo "END ($END) is not before today UTC ($TODAY): that day is still being written."
  exit 1
fi

PARENT=$(dirname "$SRC")
BASE=$(basename "$SRC")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
LIST="$TMP/filelist.txt"
: > "$LIST"

days() {   # folder names YYYY-MM-DD <= END inside the directory $1
  if [ -d "$1" ]; then
    ls "$1" | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' | awk -v e="$END" '$1 <= e' || true
  fi
}

for feed in status info; do
  for d in $(days "$SRC/$feed"); do echo "$BASE/$feed/$d" >> "$LIST"; done
  for d in $(days "$SRC/quarantine/$feed"); do echo "$BASE/quarantine/$feed/$d" >> "$LIST"; done
done
[ -s "$LIST" ] || { echo "no day folder <= $END found"; exit 1; }

LASTDAY=$(days "$SRC/status" | tail -1)
FIRSTDAY=$(days "$SRC/status" | head -1)
[ "$LASTDAY" = "$END" ] || echo "WARNING: last status day found is $LASTDAY, not $END"

# HTTP log: keep the lines whose timestamp (YYYYMMDDTHHMMSSZ) is on a day <= END
mkdir -p "$TMP/$BASE"
EXTRA=()
if [ -f "$SRC/http_log.csv" ]; then
  awk -F, -v e="${END//-/}" 'substr($1,1,8) <= e ""' "$SRC/http_log.csv" > "$TMP/$BASE/http_log.csv"
  EXTRA=(-C "$TMP" "$BASE/http_log.csv")
else
  echo "WARNING: no http_log.csv found"
fi

T="$OUT/velib_${VM}_raw.tar"
tar -cf "$T" -C "$PARENT" -T "$LIST" "${EXTRA[@]}"
(cd "$OUT" && sha256sum "velib_${VM}_raw.tar" > "velib_${VM}_raw.tar.sha256")

# --- checks on what is really in the tar ------------------------------------------------
tar -tf "$T" > "$TMP/content.txt"
MAXDATE=$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$TMP/content.txt" | sort -u | tail -1)
if [[ "$MAXDATE" > "$END" ]]; then echo "ERROR: the tar contains a day after $END: $MAXDATE"; exit 1; fi
N_STATUS=$(grep -cE "^$BASE/status/.*\.json\.gz$" "$TMP/content.txt" || true)
N_INFO=$(grep -cE "^$BASE/info/.*\.json\.gz$" "$TMP/content.txt" || true)
N_QUAR=$(grep -cE "^$BASE/quarantine/.*\.json\.gz$" "$TMP/content.txt" || true)
PERDAY=$(grep -E "^$BASE/status/.*\.json\.gz$" "$TMP/content.txt" | awk -F/ '{c[$3]++} END {for (d in c) print c[d]}' | sort -n)
MINPD=$(echo "$PERDAY" | head -1); MAXPD=$(echo "$PERDAY" | tail -1)
LASTFILE=$(ls "$SRC/status/$LASTDAY" | tail -1)
if crontab -l 2>/dev/null | grep -q collect.sh; then CRON=yes; else CRON=no; fi
LOGFIRST=$(head -1 "$TMP/$BASE/http_log.csv" 2>/dev/null || true)
LOGLAST=$(tail -1 "$TMP/$BASE/http_log.csv" 2>/dev/null || true)
LOGN=$(wc -l < "$TMP/$BASE/http_log.csv" 2>/dev/null || echo 0)

SUM="$OUT/velib_${VM}_summary.txt"
{
  echo "collector:              $VM  (host $(hostname))"
  echo "packed at (UTC):        $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "cut rule:               UTC day <= $END, i.e. captures up to $END 23:59:59 UTC"
  echo "collector still running at packing time (cron): $CRON  (later captures are NOT in the tar)"
  echo "first status day:       $FIRSTDAY"
  echo "last status day:        $LASTDAY  (last capture file: $LASTFILE)"
  echo "status captures:        $N_STATUS  (per day: min $MINPD, max $MAXPD; 288 expected on a full day)"
  echo "station lists (info):   $N_INFO  (24 expected per full day)"
  echo "quarantined captures:   $N_QUAR"
  echo "http_log.csv lines:     $LOGN (cut at the end of $END)"
  echo "http_log first line:    $LOGFIRST"
  echo "http_log last line:     $LOGLAST"
  echo "tar size:               $(du -h "$T" | cut -f1)"
  echo "sha256:                 $(cut -d' ' -f1 "$OUT/velib_${VM}_raw.tar.sha256")"
} > "$SUM"

echo
cat "$SUM"
echo
echo "Next: copy these three files to your laptop:"
echo "  $T"
echo "  $T.sha256"
echo "  $SUM"
