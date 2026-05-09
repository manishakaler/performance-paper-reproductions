#!/usr/bin/env bash
#
# 10_patch_mutex.sh
#
# Applies the Coz paper's recursive-mutex fast-path patch to
# pthreadMutexEnter in SQLite 3.7.17. Inserts a short fast-path block
# right after the function's opening assert; if the calling thread
# already owns the recursive mutex, increment nRef and return without
# calling pthread_mutex_lock.
#
# Reference: Curtsinger & Berger, "Coz: Finding Code that Counts with
# Causal Profiling," SOSP 2015, section 5.1.
#
# Note: A backup of the unpatched file at
# sqlite3.c. is saved before_mutex_patch on first apply. Revert with
# scripts/11_revert_mutex_patch.sh.
#
#
# Usage:
#   scripts/10_patch_mutex.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=third_party/sqlite-3.7.17/sqlite3.c
BAK=third_party/sqlite-3.7.17/sqlite3.c.before_mutex_patch

if [ ! -f "$SRC" ]; then
    echo "ERROR: $SRC not found. Run scripts/01_fetch_sqlite.sh first."
    exit 1
fi


SIGNATURE='Coz fast path: skip pthread_mutex_lock'
if grep -qF "$SIGNATURE" "$SRC"; then
    echo "Mutex patch already applied (signature found in $SRC)."
    exit 0
fi

# Save backup
if [ ! -f "$BAK" ]; then
    cp "$SRC" "$BAK"
    echo "Saved backup: $BAK"
fi

python3 - "$SRC" <<'PYEOF'
import sys, os, tempfile

src_path = sys.argv[1]
with open(src_path, 'r') as f:
    data = f.read()

# Pristine 3.7.17 pthreadMutexEnter starts like this. We insert the
# fast-path block right after the opening assert.
target = (
    'static void pthreadMutexEnter(sqlite3_mutex *p){\n'
    '  assert( p->id==SQLITE_MUTEX_RECURSIVE || pthreadMutexNotheld(p) );\n'
)

count = data.count(target)
if count == 0:
    sys.stderr.write(
        "ERROR: could not locate pthreadMutexEnter in expected pristine form.\n"
        "Has sqlite3.c been modified some other way? Re-fetch with:\n"
        "  rm -rf third_party/sqlite-3.7.17 && scripts/01_fetch_sqlite.sh\n"
    )
    sys.exit(1)
if count > 1:
    sys.stderr.write(f"ERROR: target string appears {count} times -- expected exactly once.\n")
    sys.exit(1)

fast_path = (
    '\n'
    '  /* Coz fast path: skip pthread_mutex_lock when this thread already owns\n'
    '  ** the recursive mutex. Per Curtsinger & Berger, Coz: Finding Code that\n'
    '  ** Counts with Causal Profiling, SOSP 2015, section 5.1. */\n'
    '  if( p->id==SQLITE_MUTEX_RECURSIVE ){\n'
    '    pthread_t self = pthread_self();\n'
    '    if( p->nRef>0 && pthread_equal(p->owner, self) ){\n'
    '      p->nRef++;\n'
    '      return;\n'
    '    }\n'
    '  }\n'
)

new_data = data.replace(target, target + fast_path, 1)

# Atomic write.
dirname = os.path.dirname(src_path) or '.'
fd, tmp_path = tempfile.mkstemp(dir=dirname, prefix='sqlite3.c.', suffix='.tmp')
try:
    with os.fdopen(fd, 'w') as f:
        f.write(new_data)
    os.replace(tmp_path, src_path)
except Exception:
    if os.path.exists(tmp_path):
        os.unlink(tmp_path)
    raise

print("OK: inserted fast-path block into pthreadMutexEnter")
PYEOF

# Verify.
if ! grep -qF "$SIGNATURE" "$SRC"; then
    echo "ERROR: patch signature not found after edit. Restoring backup."
    cp "$BAK" "$SRC"
    exit 1
fi

echo "Applied mutex fast-path patch to $SRC."
echo "Affected function: pthreadMutexEnter"
echo
echo "Next steps:"
echo "  scripts/02_build_sqlite.sh        # rebuild libsqlite3_custom.so"
echo "  scripts/03_build_bench.sh         # relink benchmark"
echo "  scripts/06_run_timing.sh mutex    # measure mutex-only patch effect"