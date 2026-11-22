#!/bin/bash
# Build the folder to upload to Zenodo, from what the pipeline produced.
#
# Run it from the project root (the folder that contains code/):
#     bash code/make_zenodo.sh
#
# Needs, per VM (vm1, vm2):
#     velib_<vm>_raw.tar, velib_<vm>_raw.tar.sha256, velib_<vm>_summary.txt   (from pack_vm.sh)
#     data/<vm>/ with station_status/ and clean/                              (run_all.py --vm <vm>)
# and once: data/vm_comparison.csv (compare_vms.py), README_zenodo.md, DATA_DICTIONARY.md.
#
# Result: zenodo/ with 17 files, SHA256SUMS.txt included. Nothing is uploaded.

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
Z=zenodo
fail() { echo "ERROR: $*" >&2; exit 1; }

# 1. inputs are there, and the raw tars are intact
for v in vm1 vm2; do
  for f in "velib_${v}_raw.tar" "velib_${v}_raw.tar.sha256" "velib_${v}_summary.txt"; do
    [ -f "$f" ] || fail "missing $f (step B1 of the guide)"
  done
  sha256sum -c "velib_${v}_raw.tar.sha256" > /dev/null || fail "checksum of velib_${v}_raw.tar does not match"
  [ -d "data/$v/station_status" ] || fail "data/$v/station_status missing: run python code/run_all.py --vm $v"
  [ -d "data/$v/clean/station_status_clean" ] || fail "data/$v/clean missing: run python code/run_all.py --vm $v"
done
[ -f data/vm_comparison.csv ] || fail "data/vm_comparison.csv missing: python code/compare_vms.py vm1/velib vm2/velib"
[ -f README_zenodo.md ] || fail "README_zenodo.md missing"
if [ -e "$Z" ] && [ -n "$(ls -A "$Z" 2>/dev/null)" ]; then
  fail "$Z/ already exists and is not empty: move it away first"
fi
mkdir -p "$Z"

# 2. copy what is already a file
cp velib_vm1_raw.tar velib_vm2_raw.tar velib_vm1_raw.tar.sha256 velib_vm2_raw.tar.sha256 \
   velib_vm1_summary.txt velib_vm2_summary.txt "$Z"/
cp data/vm_comparison.csv "$Z"/
cp README_zenodo.md "$Z/README.md"
if [ -f DATA_DICTIONARY.md ]; then cp DATA_DICTIONARY.md "$Z"/; else echo "WARNING: DATA_DICTIONARY.md not found, not included"; fi

# 3. derived data, one set of archives per VM (Parquet and NDJSON are already compressed)
for v in vm1 vm2; do
  tar -cf "$Z/${v}_parquet.tar" --exclude='*.csv' --exclude='*.log' \
      -C "data/$v" station_status clean
  if [ -d "data/$v/daily_json" ]; then
    tar -cf "$Z/${v}_ndjson.tar" --exclude='*.csv' -C "data/$v" daily_json
  else
    echo "WARNING: data/$v/daily_json missing, no ${v}_ndjson.tar"
  fi
  (cd "data/$v" && find . \( -name '*.csv' -o -name '*.log' \) | tar -czf "../../$Z/${v}_csv_logs.tar.gz" -T -)
done

# 4. code
if command -v zip > /dev/null; then
  zip -rq "$Z/code.zip" code -x '*/__pycache__/*' '*.pyc'
else
  python3 - <<'PY'
import pathlib, zipfile
with zipfile.ZipFile("zenodo/code.zip", "w", zipfile.ZIP_DEFLATED) as z:
    for p in sorted(pathlib.Path("code").rglob("*")):
        if p.is_file() and "__pycache__" not in p.parts and p.suffix != ".pyc":
            z.write(p)
PY
fi

# 5. checksums of everything
(cd "$Z" && sha256sum $(ls | grep -v '^SHA256SUMS.txt$') > SHA256SUMS.txt)

N=$(ls "$Z" | wc -l)
echo
ls -lh "$Z"
echo
echo "$N files, total $(du -sh "$Z" | cut -f1)   (Zenodo limits: 100 files, 50 GB per record)"
[ "$N" -le 100 ] || fail "more than 100 files"
if grep -q '\[[A-Z ]*\]' README_zenodo.md; then echo "WARNING: README_zenodo.md still contains [placeholders]"; fi
echo "Done. Upload the content of $Z/ (guide, part F)."
