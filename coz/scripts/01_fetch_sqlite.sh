#!/usr/bin/env bash
#
# Fetch SQLite 3.7.17
#
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p third_party
cd third_party

if [ -d sqlite-3.7.17 ]; then
    echo "sqlite-3.7.17 already present, skipping fetch."
    exit 0
fi

URL="https://www.sqlite.org/2013/sqlite-amalgamation-3071700.zip"
echo "Fetching $URL"

if command -v wget >/dev/null 2>&1; then
    wget -q "$URL" -O sqlite-amalgamation-3071700.zip
else
    curl -sSL "$URL" -o sqlite-amalgamation-3071700.zip
fi

unzip -q sqlite-amalgamation-3071700.zip
mv sqlite-amalgamation-3071700 sqlite-3.7.17
rm sqlite-amalgamation-3071700.zip

echo "OK. Source: third_party/sqlite-3.7.17/sqlite3.c"