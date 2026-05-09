#!/usr/bin/env bash
#
# Run cache_scratch (passive false sharing) and cache_thrash (active
# false sharing) under each allocator at a fixed thread count.
# Writes one CSV per (benchmark, allocator) pair.
#
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p results

NTHREADS=8        # paper-style 8-thread setup
NITER_SCRATCH=2000000
NITER_THRASH=200000
BSIZE=8           # tiny -> several per cache line in a naive allocator
WRITES_THRASH=200
RUNS=5

declare -A PRELOADS=(
    [glibc]=""
    [hoard]="$PWD/build/libhoard.so"
    [jemalloc]="$PWD/build/libjemalloc.so"
    [mimalloc]="$PWD/build/libmimalloc.so"
)

ALLOCATORS=()
for a in glibc hoard jemalloc mimalloc; do
    p="${PRELOADS[$a]}"
    if [ -z "$p" ] || [ -f "$p" ]; then ALLOCATORS+=("$a"); fi
done

median () {
    sort -n | awk '{a[NR]=$1} END {if(NR%2)printf "%.6f", a[(NR+1)/2]; else printf "%.6f", (a[NR/2]+a[NR/2+1])/2}'
}

run_bench () {
    local bench=$1; local args=$2
    local OUT="results/${bench}_summary.csv"
    echo "allocator,threads,elapsed_s,throughput" > "$OUT"
    echo
    echo "=== ${bench} ==="
    for alloc in "${ALLOCATORS[@]}"; do
        PRELOAD="${PRELOADS[$alloc]}"
        elapsed_list=""
        tput_list=""
        for run in $(seq 1 $RUNS); do
            if [ -n "$PRELOAD" ]; then
                line=$(LD_PRELOAD="$PRELOAD" ./bin/${bench} $args)
            else
                line=$(./bin/${bench} $args)
            fi
            # last two columns are elapsed and tput
            elap=$(echo "$line" | awk '{print $(NF-1)}')
            tput=$(echo "$line" | awk '{print $NF}')
            elapsed_list="${elapsed_list}${elap}\n"
            tput_list="${tput_list}${tput}\n"
        done
        med_elap=$(printf "$elapsed_list" | median)
        med_tput=$(printf "$tput_list" | median)
        printf "  %-9s elapsed=%-7s tput=%s\n" "$alloc" "$med_elap" "$med_tput"
        echo "$alloc,$NTHREADS,$med_elap,$med_tput" >> "$OUT"
    done
    echo "Wrote $OUT"
}

run_bench cache_scratch "$NTHREADS $NITER_SCRATCH $BSIZE"
run_bench cache_thrash  "$NTHREADS $NITER_THRASH $BSIZE $WRITES_THRASH"

echo
echo "Done. Next: scripts/06_run_perf_c2c.sh"