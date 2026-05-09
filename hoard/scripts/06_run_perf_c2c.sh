#!/usr/bin/env bash
#
# Run perf c2c on cache_thrash for two allocators (glibc and hoard,
# by default) and dump the cache-line contention reports. perf c2c
# attributes "Hits Tot" -- HITM (modified-line cache hits) -- to
# specific cache lines.
#
# Usage:
#   scripts/06_run_perf_c2c.sh           # default: glibc + hoard
#   scripts/06_run_perf_c2c.sh all       # glibc + hoard + jemalloc + mimalloc
#
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p results/perf_c2c

NTHREADS=8
NITER=200000
BSIZE=8
WRITES=200

if [ "${1:-}" = "all" ]; then
    ALLOCATORS=(glibc hoard jemalloc mimalloc)
else
    ALLOCATORS=(glibc hoard)
fi

declare -A PRELOADS=(
    [glibc]=""
    [hoard]="$PWD/build/libhoard.so"
    [jemalloc]="$PWD/build/libjemalloc.so"
    [mimalloc]="$PWD/build/libmimalloc.so"
)

# perf c2c needs the cycles + memory access events, which require
# perf_event_paranoid <= 2. elnux has it at 0.
if [ "$(cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null)" -gt 2 ]; then
    echo "WARNING: perf_event_paranoid > 2; perf c2c may not work."
fi

for alloc in "${ALLOCATORS[@]}"; do
    PRELOAD="${PRELOADS[$alloc]}"
    DATA="results/perf_c2c/c2c_${alloc}.data"
    REPORT="results/perf_c2c/c2c_${alloc}_report.txt"

    echo
    echo "=== perf c2c: $alloc ==="
    if [ -n "$PRELOAD" ]; then
        env LD_PRELOAD="$PRELOAD" perf c2c record -F 999 -o "$DATA" \
            -- ./bin/cache_thrash "$NTHREADS" "$NITER" "$BSIZE" "$WRITES"
    else
        perf c2c record -F 999 -o "$DATA" \
            -- ./bin/cache_thrash "$NTHREADS" "$NITER" "$BSIZE" "$WRITES"
    fi

    echo "  -> $DATA"
    perf c2c report -i "$DATA" --stdio --full-symbols 2>&1 | head -120 \
        | tee "$REPORT"
    echo "  -> $REPORT"
done

echo
echo "Done. Compare cache-line HITM counts across allocators."
echo "A good allocator (Hoard, jemalloc, mimalloc) should show"
echo "dramatically fewer HITM events than glibc on cache_thrash."