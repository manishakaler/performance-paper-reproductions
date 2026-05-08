#!/usr/bin/env bash
#
# Build SQLite 3.7.17 as a shared library with debug info and frame
# pointers so Coz can resolve source lines inside it.
#
# Critical flags:
#   -g                          debug info (Coz needs it for line resolution)
#   -fno-omit-frame-pointer     accurate stack walks
#   -O2                         realistic optimization level
#   -fPIC + -shared             produces libsqlite3_custom.so
#   -DSQLITE_THREADSAFE=1       serialized mode -- this is what makes the
#                               recursive connection mutex hot, which is
#                               what the paper exploits.
#
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=third_party/sqlite-3.7.17
OUT=build-custom

if [ ! -f "$SRC/sqlite3.c" ]; then
    echo "ERROR: $SRC/sqlite3.c not found. Run scripts/01_fetch_sqlite.sh first."
    exit 1
fi

mkdir -p "$OUT"

gcc -g -O2 -fno-omit-frame-pointer -fPIC -shared \
    -DSQLITE_THREADSAFE=1 \
    -DSQLITE_ENABLE_COLUMN_METADATA \
    -I"$SRC" \
    "$SRC/sqlite3.c" \
    -o "$OUT/libsqlite3_custom.so" \
    -lpthread -ldl

echo "Built $OUT/libsqlite3_custom.so"
ls -lh "$OUT/libsqlite3_custom.so"

# Sanity-check that debug info is present.
if command -v readelf >/dev/null 2>&1; then
    if readelf -S "$OUT/libsqlite3_custom.so" | grep -q '\.debug_info'; then
        echo "OK: .debug_info section present."
    else
        echo "WARN: no .debug_info section. Coz line resolution will fail."
    fi
fi