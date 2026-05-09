# Paper 2 — Hoard

Reproduces the scalability and false-sharing benchmarks from
Berger et al., *Hoard: A Scalable Memory Allocator for
Multithreaded Applications* (ASPLOS 2000). Compares four
allocators: glibc `ptmalloc2`, Hoard, jemalloc 5.3.0, mimalloc
2.1.7.

## What's in here

- `src/threadtest.c` — multi-threaded malloc/free for scalability.
- `src/cache_scratch.c` — passive false sharing.
- `src/cache_thrash.c` — active false sharing.
- `scripts/01..07` — fetch + build allocators, build benchmarks,
  sweep, perf c2c, plot.

## Run

```bash
chmod +x scripts/*.sh

scripts/01_fetch_allocators.sh    # clone Hoard, jemalloc, mimalloc
scripts/02_build_allocators.sh    # build all four .so files
scripts/03_build_benchmarks.sh    # build the three benchmarks
scripts/04_run_threadtest.sh      # sweep 4 allocators × 8 thread counts (~12 min)
scripts/05_run_false_sharing.sh   # cache_scratch + cache_thrash (~5 min)
scripts/06_run_perf_c2c.sh all    # perf c2c on all four allocators
scripts/07_plot_threadtest.sh     # generate scalability PNG
```

## Hoard build patch

Upstream Hoard master is missing the `xxfree_sized` symbol on
modern glibc. `02_build_allocators.sh` automatically appends a
two-stub patch to `libhoard.cpp` before building. Idempotent —
safe to re-run.

## Outputs

- `results/threadtest_{glibc,hoard,jemalloc,mimalloc}.csv`
- `results/cache_scratch_summary.csv`
- `results/cache_thrash_summary.csv`
- `results/threadtest_scalability.png`
- `results/perf_c2c/c2c_*_report.txt`

## Manual sanity test

```bash
LD_PRELOAD=$PWD/build/libhoard.so    ./bin/threadtest 8 50000 50 64
LD_PRELOAD=$PWD/build/libjemalloc.so ./bin/threadtest 8 50000 50 64
LD_PRELOAD=$PWD/build/libmimalloc.so ./bin/threadtest 8 50000 50 64
                                     ./bin/threadtest 8 50000 50 64   # glibc
```