#!/usr/bin/env bash
#
# Run Coz on the benchmark.
#
# KEY DETAIL: by default Coz only profiles lines in the MAIN executable.
# We need it to also profile lines inside libsqlite3_custom.so (where the
# pthread mutex code lives). That's what --binary-scope and --source-scope
# do below.
#
# A profile.jsonl is written to results/coz/. Re-run from the repo root
# so the viewer can resolve src/sqlite_bench.c and sqlite3.c paths.
#
set -euo pipefail
cd "$(dirname "$0")/.."

VARIANT="${1:-baseline}"   # "baseline" or "patched"

mkdir -p results/coz
PROFILE="results/coz/profile_${VARIANT}.jsonl"

if [ ! -x results/raw/bin/sqlite_bench ]; then
    echo "ERROR: results/raw/bin/sqlite_bench missing. Run 03_build_bench.sh."
    exit 1
fi

export LD_LIBRARY_PATH="$PWD/build-custom:${LD_LIBRARY_PATH:-}"

# Use glob patterns rather than absolute paths -- Coz matches the binary
# scope against the path the dynamic loader records, which may differ
# from the filesystem path we know (esp. on NFS-mounted homes).
echo "Running Coz on variant=$VARIANT"
echo "  profile  -> $PROFILE"
echo "  binary scope: %libsqlite3_custom.so"
echo "  source scope: %sqlite3.c, %sqlite_bench.c"
echo

third_party/coz/coz run \
    --binary-scope '%libsqlite3_custom.so' \
    --source-scope '%sqlite3.c' \
    --source-scope '%sqlite_bench.c' \
    -o "$PROFILE" \
    --- results/raw/bin/sqlite_bench

echo
echo "Done. Open the viewer with:"
echo "    scripts/05_view_coz.sh $VARIANT"