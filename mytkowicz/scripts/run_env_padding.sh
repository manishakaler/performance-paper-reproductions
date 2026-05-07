#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BINDIR="$ROOT/results/raw/bin"
OUTDIR="$ROOT/results/raw"
BIN="$BINDIR/target_O2"

mkdir -p "$OUTDIR"

if [[ ! -x "$BIN" ]]; then
  echo "Binary not found: $BIN"
  echo "Run build_targets.sh first."
  exit 1
fi

RUNS=${RUNS:-20}
MIN_PAD=${MIN_PAD:-0}
MAX_PAD=${MAX_PAD:-8192}
STEP=${STEP:-256}
PROBLEM_SIZE=${PROBLEM_SIZE:-1000000}

OUTCSV="$OUTDIR/env_padding_runs.csv"
echo "pad_bytes,run_id,elapsed_sec,checksum" > "$OUTCSV"

for ((pad=MIN_PAD; pad<=MAX_PAD; pad+=STEP)); do
  PADVAL=$(python3 - <<PY
n = $pad
print("X" * n)
PY
)
  for ((r=1; r<=RUNS; r++)); do
    OUTPUT=$(env MYTKO_PAD="$PADVAL" "$BIN" "$PROBLEM_SIZE")
    ELAPSED=$(echo "$OUTPUT" | awk -F= '/elapsed_sec/ {print $2}')
    CHECKSUM=$(echo "$OUTPUT" | awk -F= '/checksum/ {print $2}')
    echo "$pad,$r,$ELAPSED,$CHECKSUM" >> "$OUTCSV"
    echo "pad=$pad run=$r elapsed=$ELAPSED"
  done
done

echo "Wrote $OUTCSV"