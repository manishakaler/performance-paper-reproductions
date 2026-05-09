#!/usr/bin/env bash
#
# Cachegrind on best and worst paddings. Cachegrind models L1/L2/LLC
# misses precisely.
#
# ouput: differences in D1mr (L1 read misses), DLmr (last-
# level read misses), Bcm (branch mispredicts), I1mr (L1 instruction
# misses) between best and worst paddings.
#
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f results/best_worst_padding.txt ]; then
    echo "ERROR: results/best_worst_padding.txt missing. Run scripts/03_analyze.sh first."
    exit 1
fi
source results/best_worst_padding.txt

COZ_REPO="../coz"
export LD_LIBRARY_PATH="${COZ_REPO}/build-custom:${LD_LIBRARY_PATH:-}"
BENCH=results/raw/bin/sqlite_bench_small

mkdir -p results/cachegrind

if ! command -v valgrind >/dev/null 2>&1; then
    echo "ERROR: valgrind not found. Cachegrind is bundled with valgrind."
    exit 1
fi

run_cachegrind() {
    local label=$1; local pad=$2
    local PAD_VAL=""
    if [ "$pad" -gt 0 ]; then
        PAD_VAL=$(printf 'A%.0s' $(seq 1 "$pad"))
    fi

    local LOG="results/cachegrind/cg_${label}.log"
    local OUTFILE="results/cachegrind/cg_${label}.out"

    echo "=== Cachegrind: ${label} (padding=${pad}) ==="

    
    env PADDING="$PAD_VAL" valgrind --tool=cachegrind \
        --cachegrind-out-file="$OUTFILE" \
        "$BENCH" \
        2>"$LOG"

    if [ ! -f "$OUTFILE" ]; then
        echo "ERROR: $OUTFILE was not created. Cachegrind may not have completed."
        return 1
    fi

    # Show the summary block (last 25 lines of the log)
    echo
    tail -25 "$LOG"
    echo
}

run_cachegrind best  "$BEST_PADDING"
run_cachegrind worst "$WORST_PADDING"

echo
echo "Done. Files written:"
ls -lh results/cachegrind/cg_*.out results/cachegrind/cg_*.log

echo
echo "Headline metrics to compare in cg_best.log vs cg_worst.log:"
echo "  D1  miss rate (L1 data cache miss rate)"
echo "  LLd miss rate (last-level data cache miss rate)"
echo "  I1  miss rate (L1 instruction cache miss rate)"
echo "  LLi miss rate (last-level instruction cache miss rate)"
echo
echo "For per-function breakdown, run:"
echo "  cg_annotate results/cachegrind/cg_best.out  | head -50"
echo "  cg_annotate results/cachegrind/cg_worst.out | head -50"