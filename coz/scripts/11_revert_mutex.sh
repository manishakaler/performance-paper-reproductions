#!/usr/bin/env bash
#
# 11_revert_mutex_patch.sh
#
# Reverts the mutex fast-path patch by restoring sqlite3.c from the
# backup taken at first-apply time by 10_patch_mutex.sh.
#
# Usage:
#   scripts/11_revert_mutex_patch.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=third_party/sqlite-3.7.17/sqlite3.c
BAK=third_party/sqlite-3.7.17/sqlite3.c.before_mutex_patch

if [ ! -f "$BAK" ]; then
    echo "ERROR: backup $BAK not found."
    echo "Either the mutex patch was never applied via the script, or the"
    echo "backup was deleted. To return sqlite3.c to a guaranteed pristine"
    echo "state, re-fetch:"
    echo "  rm -rf third_party/sqlite-3.7.17"
    echo "  scripts/01_fetch_sqlite.sh"
    exit 1
fi

cp "$BAK" "$SRC"
echo "Restored $SRC from $BAK"
echo
echo "Rebuild to make the revert effective:"
echo "  scripts/02_build_sqlite.sh"
echo "  scripts/03_build_bench.sh"