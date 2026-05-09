# Paper 3 — Mytkowicz

Reproduces the layout-sensitivity result from Mytkowicz et al.,
*Producing Wrong Data Without Doing Anything Obviously Wrong!*
(ASPLOS 2009). SPEC INT 2006 (paper's workload) is licensed and
unavailable, so we substitute the SQLite benchmark from Paper 1.

## What's in here

- `src/sqlite_bench_small.c` — smaller SQLite INSERT driver
  (4 threads × 25,000 inserts, ~1–2 s per run).
- `scripts/01..06` — build, padding sweep, statistics, TMA,
  Cachegrind, plot.

## Prerequisite

**Paper 1 must be built first.** This reproduction reuses
`../coz/build-custom/libsqlite3_custom.so`. Verify:

```bash
ls ../coz/build-custom/libsqlite3_custom.so
```

## Run

```bash
chmod +x scripts/*.sh

scripts/01_build.sh                # compile sqlite_bench_small
scripts/02_padding_sweep.sh        # 31 paddings × 10 runs (~12 min)
scripts/03_analyze.sh              # stats + best/worst paddings
scripts/04_tma.sh                  # perf stat TMA on best/worst
scripts/05_cachegrind.sh           # cachegrind on best/worst (~3 min)
scripts/06_plot.sh                 # generate plot
```

## Outputs

- `results/padding_sweep.csv` — 310 raw measurements
- `results/padding_summary.csv` — per-padding stats with 95% CI
- `results/best_worst_padding.txt` — best/worst padding sizes
- `results/padding_sensitivity.png` — headline plot
- `results/tma/tma_{best,worst}.txt` — TMA breakdowns
- `results/cachegrind/cg_{best,worst}.log` — cachegrind summaries

## Pre-flight check

```bash
which setarch valgrind perf
setarch -R true && echo "setarch -R works"
ls ../coz/build-custom/libsqlite3_custom.so
```