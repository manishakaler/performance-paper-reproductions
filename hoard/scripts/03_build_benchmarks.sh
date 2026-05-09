#!/usr/bin/env bash
#
# Compile the three benchmarks into bin/.
# All built with -O2, frame pointers preserved for perf c2c later.
#
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p bin

CFLAGS="-O2 -g -fno-omit-frame-pointer -pthread -Wall"

for bench in threadtest cache_scratch cache_thrash; do
    gcc $CFLAGS -o "bin/${bench}" "src/${bench}.c"
    echo "  built bin/${bench}"
done

echo
echo "Smoke test (each 1-thread, glibc allocator):"
for bench in threadtest cache_scratch cache_thrash; do
    out=$(./bin/${bench} 1 2>&1 1>/dev/null | head -1)
    echo "  $bench OK: $out"
done

echo
echo "Next: scripts/04_run_threadtest.sh"