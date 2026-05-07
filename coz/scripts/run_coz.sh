#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COZ_ROOT="$ROOT/third_party/coz"
LIBDIR="$COZ_ROOT/build/libcoz"

LD_LIBRARY_PATH="$LIBDIR:${LD_LIBRARY_PATH:-}" \
  "$COZ_ROOT/coz" run --- \
  "$ROOT/results/raw/bin/sqlite_bench" coz_sqlite_coz.db