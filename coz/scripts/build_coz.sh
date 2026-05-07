#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TP="$ROOT/third_party"
COZ_DIR="$TP/coz"

mkdir -p "$TP"

if [[ ! -d "$COZ_DIR/.git" ]]; then
  git clone https://github.com/plasma-umass/coz.git "$COZ_DIR"
fi

cd "$COZ_DIR"
mkdir -p build
cd build
cmake ..
make -j"$(nproc)"

echo "Built Coz in: $COZ_DIR/build"