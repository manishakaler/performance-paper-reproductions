#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TP="$ROOT/third_party"
SQLITE_DIR="$TP/sqlite"
COZ_DIR="$TP/coz"
SRC="$ROOT/src/sqlite_bench.c"
OUTDIR="$ROOT/results/raw/bin"

mkdir -p "$OUTDIR"

CC=${CC:-gcc}
CFLAGS="-O2 -g -gdwarf-3 -pthread -fno-omit-frame-pointer"
INC="-I$SQLITE_DIR/install/include -I$COZ_DIR/include"
LIBS="-L$COZ_DIR/build/libcoz -lcoz -lsqlite3 -lpthread -ldl"

$CC $CFLAGS $INC "$SRC" -o "$OUTDIR/sqlite_bench" $LIBS

echo "Built: $OUTDIR/sqlite_bench"