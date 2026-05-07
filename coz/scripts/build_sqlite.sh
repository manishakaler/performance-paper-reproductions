#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TP="$ROOT/third_party"
SQLITE_DIR="$TP/sqlite"

mkdir -p "$TP"
cd "$TP"

if [[ ! -d "$SQLITE_DIR" ]]; then
  curl -L https://www.sqlite.org/2024/sqlite-autoconf-3450000.tar.gz \
    -o sqlite.tar.gz
  mkdir -p sqlite-src
  tar xf sqlite.tar.gz -C sqlite-src --strip-components=1
  mv sqlite-src "$SQLITE_DIR"
fi

cd "$SQLITE_DIR"
./configure --prefix="$SQLITE_DIR/install" CFLAGS="-O2 -g -fno-omit-frame-pointer"
make -j"$(nproc)"
make install

echo "SQLite built and installed under: $SQLITE_DIR/install"