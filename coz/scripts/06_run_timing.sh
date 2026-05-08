#!/usr/bin/env bash
#
# Wall-clock timing without Coz, 10 runs, prints per-run elapsed seconds
# and the median. Run this for both the baseline and the patched library
# (rebuild build-custom/libsqlite3_custom.so between the two and rerun).
#
# Usage: scripts/06_run_timing.sh [label]
#
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL="${1:-baseline}"
RUNS=10

mkdir -p results/timing
OUT="results/timing/timing_${LABEL}.csv"

export LD_LIBRARY_PATH="$PWD/build-custom:${LD_LIBRARY_PATH:-}"

echo "run,elapsed_s,throughput_ops_s" > "$OUT"

for i in $(seq 1 $RUNS); do
    # The benchmark prints its own elapsed line on stderr.
    LINE=$(results/raw/bin/sqlite_bench 2>&1 1>/dev/null | tail -1)
    ELAPSED=$(echo "$LINE" | sed -n 's/.*elapsed=\([0-9.]*\)s.*/\1/p')
    TPUT=$(echo "$LINE" | sed -n 's/.*throughput=\([0-9.]*\) ops.*/\1/p')
    echo "$i,$ELAPSED,$TPUT" | tee -a "$OUT"
done

echo
echo "Median elapsed:"
awk -F, 'NR>1{print $2}' "$OUT" | sort -n | awk '{
    a[NR]=$1
} END {
    if (NR%2) print a[(NR+1)/2]
    else print (a[NR/2] + a[NR/2+1])/2
}'
echo
echo "Wrote $OUT"