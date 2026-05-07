#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/src/target_program.c"
OUTDIR="$ROOT/results/raw/bin"

mkdir -p "$OUTDIR"

CC=${CC:-gcc}
CFLAGS="-O2 -march=native -fno-omit-frame-pointer -Wall -Wextra"

$CC $CFLAGS "$SRC" -o "$OUTDIR/target_O2"

echo "Built: $OUTDIR/target_O2"