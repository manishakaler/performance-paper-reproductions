#!/usr/bin/env bash
#
# Build the small SQLite benchmark for the layout-sensitivity sweep.
# Reuses the libsqlite3_custom.so built for Paper 1 (Coz reproduction).
#
set -euo pipefail
cd "$(dirname "$0")/.."

# Path to the Coz repo to reuse its built SQLite library.
COZ_REPO="../coz"
LIB="${COZ_REPO}/build-custom/libsqlite3_custom.so"
INC="${COZ_REPO}/third_party/sqlite-3.7.17"

if [ ! -f "$LIB" ]; then
    echo "ERROR: $LIB not found. Build the Coz reproduction first."
    echo "  cd ../coz && scripts/02_build_sqlite.sh"
    exit 1
fi

mkdir -p results/raw/bin

gcc -O2 -g -fno-omit-frame-pointer -pthread \
    -I "$INC" \
    src/sqlite_bench_small.c \
    -o results/raw/bin/sqlite_bench_small \
    -L "${COZ_REPO}/build-custom" -lsqlite3_custom \
    -ldl

echo "Built results/raw/bin/sqlite_bench_small"

# Sanity-check 
echo "ldd check (libsqlite3_custom.so should resolve to coz repo):"
LD_LIBRARY_PATH="${COZ_REPO}/build-custom" \
    ldd results/raw/bin/sqlite_bench_small | grep -i sqlite || true

# Quick one-run smoke test
echo
echo "Smoke test (one run, no padding, ASLR randomized as default):"
LD_LIBRARY_PATH="${COZ_REPO}/build-custom" \
    results/raw/bin/sqlite_bench_small 2>&1 | tail -2