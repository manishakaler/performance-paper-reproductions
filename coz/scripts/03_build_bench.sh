#!/usr/bin/env bash
#
# Build the benchmark, linking against the libsqlite3_custom.so.
# Output: results/raw/bin/sqlite_bench
#
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p results/raw/bin

if [ ! -f build-custom/libsqlite3_custom.so ]; then
    echo "ERROR: build-custom/libsqlite3_custom.so missing. Run 02_build_sqlite.sh."
    exit 1
fi

# coz.h location: the Coz repo ships it under include/. Adjust if your
# layout differs.
COZ_INCLUDE="third_party/coz/include"
if [ ! -f "$COZ_INCLUDE/coz.h" ]; then
    # fallback locations
    for c in third_party/coz/coz/include third_party/coz; do
        if [ -f "$c/coz.h" ]; then COZ_INCLUDE="$c"; break; fi
    done
fi
if [ ! -f "$COZ_INCLUDE/coz.h" ]; then
    echo "ERROR: cannot find coz.h. Set COZ_INCLUDE manually."
    exit 1
fi
echo "Using coz.h from $COZ_INCLUDE"

gcc -g -O2 -fno-omit-frame-pointer \
    -I"third_party/sqlite-3.7.17" \
    -I"$COZ_INCLUDE" \
    src/sqlite_bench.c \
    -o results/raw/bin/sqlite_bench \
    -Lbuild-custom -lsqlite3_custom \
    -lpthread -ldl

echo "Built results/raw/bin/sqlite_bench"

echo
echo "ldd check (libsqlite3_custom.so should resolve to build-custom/):"
LD_LIBRARY_PATH="$PWD/build-custom:${LD_LIBRARY_PATH:-}" \
    ldd results/raw/bin/sqlite_bench | grep -i sqlite || true