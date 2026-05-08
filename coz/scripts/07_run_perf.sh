#!/usr/bin/env bash
#
# Conventional-profiler comparison the assignment requires.
#
# Records a perf profile of the same benchmark and dumps the top symbols
# so you can compare what perf points at vs. what Coz points at.
#
# perf_event_paranoid is 0 on elnux per your environment, so this should
# work without sudo.
#
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p results/perf
PERFDATA=results/perf/perf.data
PERFTXT=results/perf/perf_report.txt

export LD_LIBRARY_PATH="$PWD/build-custom:${LD_LIBRARY_PATH:-}"

echo "Recording perf profile..."
perf record -g --call-graph=dwarf -o "$PERFDATA" -- \
    results/raw/bin/sqlite_bench

echo
echo "Top self-time symbols:"
perf report -i "$PERFDATA" --stdio --no-children --sort=dso,symbol \
    | head -60 | tee "$PERFTXT"

echo
echo "Full report saved to $PERFTXT"
echo
echo "For the report, contrast:"
echo "  - what perf says is hot (self time, e.g. pthread_mutex_lock, sqlite3_step)"
echo "  - what Coz says causes program-level speedup (the lines in profile.jsonl)"