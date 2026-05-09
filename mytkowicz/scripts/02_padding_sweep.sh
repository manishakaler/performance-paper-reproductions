#!/usr/bin/env bash
#
# Padding sweep: vary the size of an environment-variable padding
# (PADDING=AAAAA...) across many values, and run the SQLite benchmark
# multiple times per padding size, with ASLR disabled via setarch -R.
#
# This reproduces the central experimental method to show that the same 
# binary, compiled with the same
# flags, produces measurably different runtimes depending on memory
# layout, even with all randomness sources controlled. Environment
# variable size affects the initial stack alignment of the process,
# which in turn shifts where the program's text/data lands relative
# to L1/L2/LLC cache sets and the branch predictor's BTB indexing.
#
# Output: results/padding_sweep.csv
#   columns: padding,run,elapsed_s,throughput_ops_s
#
#
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p results

COZ_REPO="../coz"
export LD_LIBRARY_PATH="${COZ_REPO}/build-custom:${LD_LIBRARY_PATH:-}"

BENCH=results/raw/bin/sqlite_bench_small
if [ ! -x "$BENCH" ]; then
    echo "ERROR: $BENCH missing. Run scripts/01_build.sh first."
    exit 1
fi

# Padding sizes to sweep. Step of 32 bytes covers a full set of stack
# alignments inside one cache line (64 B) several times over. Range
# 0..4096 covers ~64 different cache-line offsets.
PADDINGS=(0 32 64 96 128 160 192 224 256 320 384 448 512 640 768 896 \
          1024 1152 1280 1408 1536 1792 2048 2304 2560 2816 3072 3328 \
          3584 3840 4096)
RUNS=10

OUT=results/padding_sweep.csv
echo "padding,run,elapsed_s,throughput_ops_s" > "$OUT"

# Verify setarch is available 
if ! command -v setarch >/dev/null 2>&1; then
    echo "ERROR: setarch not found. Cannot disable ASLR per-process."
    exit 1
fi

# Verify setarch -R works 
if ! setarch -R true 2>/dev/null; then
    echo "WARNING: setarch -R failed; falling back to plain run (ASLR will be on)."
    SETARCH=""
else
    SETARCH="setarch -R"
    echo "ASLR-off via setarch -R confirmed working."
fi

echo
echo "Sweeping ${#PADDINGS[@]} padding sizes × $RUNS runs each..."
echo

for pad in "${PADDINGS[@]}"; do
    # Build padding string of exactly $pad bytes
    if [ "$pad" -gt 0 ]; then
        PAD_VAL=$(printf 'A%.0s' $(seq 1 "$pad"))
    else
        PAD_VAL=""
    fi

    for run in $(seq 1 $RUNS); do
        # Use env to set PADDING for the child process only.
        # The benchmark prints the canonical line on stdout as
        #   threads\tops_per_thread\ttotal\telapsed\tthroughput
        line=$(env PADDING="$PAD_VAL" $SETARCH "$BENCH" 2>/dev/null | tail -1)
        elapsed=$(echo "$line" | awk '{print $4}')
        tput=$(echo "$line"    | awk '{print $5}')
        echo "$pad,$run,$elapsed,$tput" >> "$OUT"
    done

    # Median of this padding's runs 
    med_e=$(awk -F, -v p="$pad" '$1==p{print $3}' "$OUT" | sort -n | awk '{a[NR]=$1} END {if(NR%2)printf "%.4f", a[(NR+1)/2]; else printf "%.4f", (a[NR/2]+a[NR/2+1])/2}')
    med_t=$(awk -F, -v p="$pad" '$1==p{print $4}' "$OUT" | sort -n | awk '{a[NR]=$1} END {if(NR%2)printf "%.0f", a[(NR+1)/2]; else printf "%.0f", (a[NR/2]+a[NR/2+1])/2}')
    printf "  pad=%-5d  med_elapsed=%s s  med_tput=%s ops/s\n" "$pad" "$med_e" "$med_t"
done

echo
echo "Wrote $OUT"
echo "Run scripts/03_analyze.sh to compute stats and find best/worst paddings."