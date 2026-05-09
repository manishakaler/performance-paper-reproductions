# Paper 1 — Coz

Reproduces the SQLite case study from Curtsinger & Berger,
*Coz: Finding Code that Counts with Causal Profiling* (SOSP 2015).

## What's in here

- `src/sqlite_bench.c` — multi-threaded SQLite INSERT driver,
  one `COZ_PROGRESS` per row.
- `scripts/01..11` — fetch SQLite 3.7.17, build, run Coz, time,
  apply patches, run perf.
- `third_party/coz/` — the Coz tool (must be cloned in
  separately from `https://github.com/plasma-umass/coz`).

## Run

```bash
chmod +x scripts/*.sh

scripts/01_fetch_sqlite.sh                # fetch SQLite 3.7.17
scripts/02_build_sqlite.sh                # build libsqlite3_custom.so
scripts/03_build_bench.sh                 # build benchmark
scripts/04_run_coz.sh baseline            # run Coz   (~4 min)
scripts/05_view_coz.sh baseline           # view profile
scripts/06_run_timing.sh baseline_clean   # 10 runs   (~12 min)

# Apply paper's mutex patch, rebuild, re-time
scripts/10_patch_mutex.sh
scripts/02_build_sqlite.sh && scripts/03_build_bench.sh
scripts/06_run_timing.sh mutex_clean

# Apply chunk-size patch (cumulative), rebuild, re-time
scripts/08_patch_chunk_size.sh
scripts/02_build_sqlite.sh && scripts/03_build_bench.sh
scripts/06_run_timing.sh chunk_clean

# perf record for flat-profiler comparison
scripts/07_run_perf.sh
```

## Outputs

- `results/coz/profile_baseline.jsonl` — Coz profile
- `results/timing/timing_*.csv` — wall-clock measurements
- `results/perf/perf_report.txt` — perf top symbols

## Revert patches

```bash
scripts/09_revert_chunk_patch.sh
scripts/11_revert_mutex_patch.sh
```