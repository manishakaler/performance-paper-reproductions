#!/usr/bin/env bash
#
# 09_revert_chunk_patch.sh
#
# Reverts the chunk-size optimization applied by 08_patch_chunk_size.sh,
# restoring sqlite3.c from the backup taken at first-apply time.
#
# This is symmetric with 08_*; running 08 then 09 should leave sqlite3.c
# byte-identical to its pre-08 state.
#
# Usage:
#   scripts/09_revert_chunk_patch.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=third_party/sqlite-3.7.17/sqlite3.c
BAK=third_party/sqlite-3.7.17/sqlite3.c.before_chunk_patch

if [ ! -f "$BAK" ]; then
    echo "ERROR: backup $BAK not found."
    echo "Either the chunk patch was never applied, or the backup was deleted."
    exit 1
fi

cp "$BAK" "$SRC"
echo "Restored $SRC from $BAK"
echo
echo "Current JOURNAL_CHUNKSIZE definition:"
grep -n "JOURNAL_CHUNKSIZE ((int)" "$SRC" | head -3
echo
echo "Rebuild to make the revert effective:"
echo "  scripts/02_build_sqlite.sh"
echo "  scripts/03_build_bench.sh"