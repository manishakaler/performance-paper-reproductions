#!/usr/bin/env bash
#
# Build all three allocators from source as shared libraries that
# can be LD_PRELOADed.
#
# Outputs (all in build/):
#   build/libhoard.so
#   build/libjemalloc.so
#   build/libmimalloc.so
#
# Builds run in parallel via background subshells.
# Modern repos: Hoard uses CMake; jemalloc uses autoconf+make;
# mimalloc uses CMake. All three are shared-library builds.
#
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build
ROOT="$PWD"

# -------- Hoard (CMake) --------
build_hoard() {
    cd "$ROOT/third_party/Hoard"

    # PATCH: weak-symbol stubs for xxfree_sized / xxfree_aligned_sized.
    # Heap-Layers' wrapper.cpp calls these but the upstream Linux build
    # doesn't define them, producing "undefined symbol: xxfree_sized" at
    # LD_PRELOAD time on modern glibc / C23 callers (e.g. threadtest).
    # Idempotent: signature grep ensures we only append once even on
    # re-runs.
    local PATCH_SIGNATURE="Coz/Hoard repro: weak xxfree_sized stub"
    if ! grep -qF "$PATCH_SIGNATURE" src/source/libhoard.cpp; then
        cat >> src/source/libhoard.cpp << 'EOF'

// Coz/Hoard repro: weak xxfree_sized stub
// Heap-Layers' wrapper.cpp at wrappers/wrapper.cpp:173 calls
// xxfree_sized(ptr, sz) (and xxfree_aligned_sized) but those symbols
// are not defined for the Linux build path. Provide weak fallbacks
// that delegate to the existing xxfree, mirroring the macwrapper.cpp
// pattern.
extern "C" {
  __attribute__((weak)) void xxfree_sized(void *ptr, size_t) { xxfree(ptr); }
  __attribute__((weak)) void xxfree_aligned_sized(void *ptr, size_t, size_t) { xxfree(ptr); }
}
EOF
        echo "  hoard: applied xxfree_sized weak-stub patch"
    else
        echo "  hoard: xxfree_sized patch already present, skipping"
    fi

    mkdir -p build_cmake && cd build_cmake
    cmake .. > /tmp/hoard_cmake.log 2>&1
    make -j$(nproc) > /tmp/hoard_make.log 2>&1
    # CMake puts libhoard.so at build_cmake/libhoard.so
    if [ -f libhoard.so ]; then
        cp libhoard.so "$ROOT/build/libhoard.so"
        echo "  hoard built -> build/libhoard.so"
    else
        echo "  hoard build FAILED (no libhoard.so produced) -- check /tmp/hoard_*.log"
        return 1
    fi
}

# -------- jemalloc (autoconf+make) --------
build_jemalloc() {
    cd "$ROOT/third_party/jemalloc"
    if [ ! -f Makefile ]; then
        # ./autogen.sh runs autoconf and produces ./configure; we then run configure.
        # Note: --disable-shared=no is INVALID syntax. Shared libs are the default;
        # don't pass any --disable/--enable for shared.
        ./autogen.sh > /tmp/jemalloc_autogen.log 2>&1 || \
            ./configure > /tmp/jemalloc_configure.log 2>&1
        if [ ! -f Makefile ]; then
            ./configure --prefix="$ROOT/build/jemalloc-install" \
                > /tmp/jemalloc_configure.log 2>&1
        fi
    fi
    make -j$(nproc) > /tmp/jemalloc_make.log 2>&1
    # jemalloc produces lib/libjemalloc.so.X
    if ls lib/libjemalloc.so* >/dev/null 2>&1; then
        cp lib/libjemalloc.so* "$ROOT/build/"
        cd "$ROOT/build"
        if [ ! -f libjemalloc.so ]; then
            ln -sf "$(ls libjemalloc.so.* 2>/dev/null | head -1)" libjemalloc.so
        fi
        echo "  jemalloc built -> build/libjemalloc.so"
    else
        echo "  jemalloc build FAILED (no libjemalloc.so produced)"
        return 1
    fi
}

# -------- mimalloc (CMake) --------
build_mimalloc() {
    cd "$ROOT/third_party/mimalloc"
    mkdir -p out/release && cd out/release
    cmake -DCMAKE_BUILD_TYPE=Release ../.. > /tmp/mimalloc_cmake.log 2>&1
    make -j$(nproc) > /tmp/mimalloc_make.log 2>&1
    if ls libmimalloc.so* >/dev/null 2>&1; then
        cp libmimalloc.so* "$ROOT/build/"
        cd "$ROOT/build"
        if [ ! -f libmimalloc.so ]; then
            ln -sf "$(ls libmimalloc.so.* 2>/dev/null | head -1)" libmimalloc.so
        fi
        echo "  mimalloc built -> build/libmimalloc.so"
    else
        echo "  mimalloc build FAILED (no libmimalloc.so produced)"
        return 1
    fi
}

echo "Building three allocators in parallel..."
echo

(build_hoard)    & HOARD_PID=$!
(build_jemalloc) & JEM_PID=$!
(build_mimalloc) & MIM_PID=$!

FAIL=0
wait $HOARD_PID || { echo "Hoard build FAILED -- check /tmp/hoard_*.log"; FAIL=1; }
wait $JEM_PID   || { echo "jemalloc build FAILED -- check /tmp/jemalloc_*.log"; FAIL=1; }
wait $MIM_PID   || { echo "mimalloc build FAILED -- check /tmp/mimalloc_*.log"; FAIL=1; }

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi

echo
echo "Built libraries:"
for lib in libhoard.so libjemalloc.so libmimalloc.so; do
    if [ -f "build/$lib" ]; then
        printf "  %-20s OK (%s)\n" "$lib" "$(ls -lh build/$lib | awk '{print $5}')"
    else
        printf "  %-20s MISSING\n" "$lib"
    fi
done

echo
echo "Next: scripts/03_build_benchmarks.sh"