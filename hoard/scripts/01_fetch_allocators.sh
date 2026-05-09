#!/usr/bin/env bash
#
# Clone Hoard, jemalloc, and mimalloc from their official upstream
# repositories. Pinned to specific commits / tags for reproducibility.
#
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p third_party
cd third_party

# Hoard - Berger's allocator. The canonical repo.
if [ ! -d Hoard ]; then
    git clone --depth 1 --branch master https://github.com/emeryberger/Hoard.git
    echo "Cloned Hoard."
else
    echo "Hoard already present, skipping."
fi

# jemalloc - Facebook/FreeBSD allocator. v5.3.0 is the latest stable.
if [ ! -d jemalloc ]; then
    git clone --depth 1 --branch 5.3.0 https://github.com/jemalloc/jemalloc.git
    echo "Cloned jemalloc."
else
    echo "jemalloc already present, skipping."
fi

# mimalloc - Microsoft's allocator. v2.1.7 is recent stable.
if [ ! -d mimalloc ]; then
    git clone --depth 1 --branch v2.1.7 https://github.com/microsoft/mimalloc.git
    echo "Cloned mimalloc."
else
    echo "mimalloc already present, skipping."
fi

echo
echo "All three allocators cloned to third_party/. Next: scripts/02_build_allocators.sh"