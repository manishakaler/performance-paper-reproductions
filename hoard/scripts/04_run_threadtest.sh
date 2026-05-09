#!/usr/bin/env bash
#
# Run threadtest across all 4 allocators and a sweep of thread counts.
# Writes one CSV per allocator at results/threadtest_<alloc>.csv.
#
# Total wall-clock: ~10-15 minutes depending on machine load.
#
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p results

# Workload: 50000 allocs/round * 50 rounds * 64 bytes per block
# Tune these if it runs too fast or slow.
NITER=50000
NREP=50
BSIZE=64
RUNS=3   # repeat each cell 3x and take the median

# Thread counts to sweep. 1, 2, 4, 8, 14 (1 socket physical), 28
# (both sockets physical), 56 (full HT). Add 16 to anchor against
# the Hoard paper's figure (which goes to 14-16).
THREADS=(1 2 4 8 14 16 28 56)

# Allocator definitions: name and LD_PRELOAD value
declare -A PRELOADS=(
    [glibc]=""
    [hoard]="$PWD/build/libhoard.so"
    [jemalloc]="$PWD/build/libjemalloc.so"
    [mimalloc]="$PWD/build/libmimalloc.so"
)

# Verify each .so exists (skip allocators that didn't build)
ALLOCATORS=()
for a in glibc hoard jemalloc mimalloc; do
    p="${PRELOADS[$a]}"
    if [ -z "$p" ] || [ -f "$p" ]; then
        ALLOCATORS+=("$a")
    else
        echo "SKIP $a: ${p} not found"
    fi
done
echo "Will run: ${ALLOCATORS[*]}"

# Helper: median of stdin numeric column
median () {
    sort -n | awk '{a[NR]=$1} END {if(NR%2)printf "%.6f", a[(NR+1)/2]; else printf "%.6f", (a[NR/2]+a[NR/2+1])/2}'
}

for alloc in "${ALLOCATORS[@]}"; do
    OUT="results/threadtest_${alloc}.csv"
    echo "threads,niter,nrep,bsize,elapsed_s,throughput_ops_s" > "$OUT"
    PRELOAD="${PRELOADS[$alloc]}"

    echo
    echo "=== ${alloc} ==="
    for nt in "${THREADS[@]}"; do
        # Run RUNS times, collect elapsed and tput per run
        elapsed_list=""
        tput_list=""
        for run in $(seq 1 $RUNS); do
            if [ -n "$PRELOAD" ]; then
                line=$(LD_PRELOAD="$PRELOAD" ./bin/threadtest "$nt" "$NITER" "$NREP" "$BSIZE")
            else
                line=$(./bin/threadtest "$nt" "$NITER" "$NREP" "$BSIZE")
            fi
            # Output is tab-sep: threads niter nrep bsize elapsed tput
            elap=$(echo "$line" | awk '{print $5}')
            tput=$(echo "$line" | awk '{print $6}')
            elapsed_list="${elapsed_list}${elap}\n"
            tput_list="${tput_list}${tput}\n"
        done
        med_elap=$(printf "$elapsed_list" | median)
        med_tput=$(printf "$tput_list" | median)
        printf "  threads=%-2d  med_elapsed=%-7s  med_tput=%s\n" "$nt" "$med_elap" "$med_tput"
        echo "$nt,$NITER,$NREP,$BSIZE,$med_elap,$med_tput" >> "$OUT"
    done
    echo "Wrote $OUT"
done

echo
echo "Done. Plot with: scripts/10_plot_threadtest.sh"