#!/usr/bin/env bash
#
# 08_patch_chunk_size.sh
#
# Applies the second source-level optimization to SQLite 3.7.17:
# bump the in-memory journal chunk size from 1 KB to 8 KB.
#
# Context:
#   Coz's profile of the unpatched baseline (results/coz/profile_baseline.jsonl)
#   identified line 73610 of sqlite3.c -- a sqlite3_malloc(sizeof(FileChunk))
#   call inside memjrnlWrite -- as the strongest candidate causal bottleneck:
#       slope +0.117, R^2 0.18, max speedup +16.2%, 17 sample points.
#
#   FileChunk is a fixed-size struct holding journal data; SQLite allocates a
#   new chunk every time the in-memory journal grows past JOURNAL_CHUNKSIZE
#   bytes. The default is 1024 - sizeof(FileChunk*) = 1016 bytes per chunk,
#   which means one sqlite3_malloc call per ~1 KB of journal data. Bumping
#   the constant 8x reduces the allocation frequency at line 73610 by 8x
#   without changing the allocator's bin selection (8 KB stays within
#   glibc's small-bin path, well below the mmap threshold).
#
# Note: re-running this script after it has already been applied is a
# no-op. A backup of the unmodified file is kept at sqlite3.c.before_chunk_patch
# so the change can be reverted with scripts/09_revert_chunk_patch.sh.
#
#
# Usage:
#   scripts/08_patch_chunk_size.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=third_party/sqlite-3.7.17/sqlite3.c
BAK=third_party/sqlite-3.7.17/sqlite3.c.before_chunk_patch

OLD_DEFINE='#define JOURNAL_CHUNKSIZE ((int)(1024-sizeof(FileChunk*)))'
NEW_DEFINE='#define JOURNAL_CHUNKSIZE ((int)(8192-sizeof(FileChunk*)))'

if [ ! -f "$SRC" ]; then
    echo "ERROR: $SRC not found. Run scripts/01_fetch_sqlite.sh first."
    exit 1
fi

# Idempotency check.
if grep -qF "$NEW_DEFINE" "$SRC"; then
    echo "Patch already applied: JOURNAL_CHUNKSIZE is already 8192."
    grep -n "JOURNAL_CHUNKSIZE ((int)" "$SRC" | head -3
    exit 0
fi

if ! grep -qF "$OLD_DEFINE" "$SRC"; then
    echo "ERROR: original definition not found in $SRC."
    echo "Expected line:  $OLD_DEFINE"
    echo "Has the file been modified some other way?"
    grep -n "JOURNAL_CHUNKSIZE ((int)" "$SRC" | head -3
    exit 1
fi

# Save backup (only on first apply -- don't clobber an existing one).
if [ ! -f "$BAK" ]; then
    cp "$SRC" "$BAK"
    echo "Saved backup: $BAK"
fi

# Replace via python3 for literal string matching (no regex escaping issues).
# Exits non-zero (and writes nothing) if the old string isn't found or
# appears more than once -- both indicate something is wrong with the file.
python3 - "$SRC" "$OLD_DEFINE" "$NEW_DEFINE" <<'PYEOF'
import sys, os, tempfile

src_path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]

with open(src_path, 'r') as f:
    data = f.read()

count = data.count(old)
if count == 0:
    sys.stderr.write("ERROR: old definition not found in source\n")
    sys.exit(1)
if count > 1:
    sys.stderr.write(f"ERROR: old definition appears {count} times -- expected exactly once\n")
    sys.exit(1)

new_data = data.replace(old, new, 1)

# Atomic write: temp file in same dir, then rename.
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

print("OK: replaced 1 occurrence")
PYEOF

# Verify it landed.
if ! grep -qF "$NEW_DEFINE" "$SRC"; then
    echo "ERROR: patch did not apply. Restoring backup."
    cp "$BAK" "$SRC"
    exit 1
fi

echo "Applied chunk-size patch to $SRC:"
grep -n "JOURNAL_CHUNKSIZE ((int)" "$SRC" | head -3

echo
echo "Next steps:"
echo "  scripts/02_build_sqlite.sh        # rebuild libsqlite3_custom.so with new constant"
echo "  scripts/03_build_bench.sh         # relink benchmark against new lib"
echo "  scripts/06_run_timing.sh patched  # measure chunk-size patch effect"