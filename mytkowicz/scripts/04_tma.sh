#!/usr/bin/env bash
#
# Top-down Microarchitecture Analysis (TMA) on the best- and worst-
# performing padding sizes. perf stat with the Intel TMA L1 metrics
# (Frontend_Bound, Backend_Bound, Bad_Speculation, Retiring) shows
# which microarchitectural bucket the layout difference shifts time
# into.
#
# The Mytkowicz et al. paper attributes layout sensitivity to
# (a) cache conflict misses driven by code/data placement and
# (b) BTB indexing collisions in the branch predictor. TMA reveals
# both: cache effects appear as Backend_Bound (and specifically
# memory_bound), branch-predictor effects appear as Bad_Speculation.
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

mkdir -p results/tma

# Try L1 TMA metrics; fall back to a compatible event set if metric
# names differ on this kernel/perf version.
TMA_EVENTS="-M Frontend_Bound,Backend_Bound,Bad_Speculation,Retiring"

run_tma() {
    local label=$1; local pad=$2
    local PAD_VAL=""
    if [ "$pad" -gt 0 ]; then
        PAD_VAL=$(printf 'A%.0s' $(seq 1 "$pad"))
    fi

    local OUT="results/tma/tma_${label}.txt"
    echo "=== TMA: ${label} (padding=${pad}) ==="
    {
        echo "# Layout: padding=${pad} bytes"
        echo "# Command: perf stat ${TMA_EVENTS} -- ${BENCH}"
        echo
        # Repeat 5 times so perf can average
        env PADDING="$PAD_VAL" \
            perf stat $TMA_EVENTS -r 5 -- setarch -R "$BENCH" 2>&1
    } | tee "$OUT"
    echo
    echo "  -> $OUT"
}

# If the -M flag fails (older perf), we fall back to raw events.
if ! perf stat -M Frontend_Bound -- true >/dev/null 2>&1; then
    echo "WARNING: perf -M metric form not supported. Falling back to raw events."
    TMA_EVENTS="-e cycles,instructions,branches,branch-misses,cache-references,cache-misses,L1-dcache-load-misses,LLC-load-misses"
fi

run_tma best  "$BEST_PADDING"
run_tma worst "$WORST_PADDING"

echo
echo "Done. Compare results/tma/tma_best.txt vs results/tma/tma_worst.txt."
echo "Look for differences in:"
echo "  - Backend_Bound (cache effects)"
echo "  - Bad_Speculation (branch-predictor effects)"
echo "  - Frontend_Bound (icache / BTB)"
echo "  - Retiring (the only 'good' bucket; lower = layout is hurting throughput)"