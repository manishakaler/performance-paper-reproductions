# Reproducing Three Performance Papers

This project reproduces three papers on UMass elnux:

| # | Paper | Workload | Code |
|---|-------|----------|------|
| 1 | **Coz** (SOSP 2015) | Multi-threaded SQLite INSERTs (`:memory:` DB) | `src/sqlite_bench.c` instrumented with `COZ_PROGRESS` |
| 2 | **Hoard** (ASPLOS 2000) | `threadtest`, `cache_thrash`, `cache_scratch` against four allocators (glibc, Hoard, jemalloc, mimalloc) | `src/threadtest.c`, `src/cache_thrash.c`, `src/cache_scratch.c`; allocators loaded via `LD_PRELOAD` |
| 3 | **Mytkowicz** (ASPLOS 2009) | Padding sweep over the same SQLite benchmark | `src/sqlite_bench_small.c` run under varied `PADDING` env-var sizes with `setarch -R` |

## Project layout

```
project-manishakaler-1/
├── README.md          (this file)
├── coz/               (Paper 1 — see coz/coz-exp-README.md)
├── hoard/             (Paper 2 — see hoard/hoard-exp-README.md)
├── mytkowicz/         (Paper 3 — see mytkowicz/myk-exp-README.md)
└── report/             Project report pdf
```

## How to run

Each paper has its own README with the exact command sequence:

- **Paper 1 (Coz):** [`coz/README.md`](coz/README.md)
- **Paper 2 (Hoard):** [`hoard/README.md`](hoard/README.md)
- **Paper 3 (Mytkowicz):** [`mytkowicz/README.md`](mytkowicz/README.md)

Run them in order: Paper 3 reuses the SQLite library built in
Paper 1.

## Building the report

```bash
cd report
mkdir -p figures
cp ../hoard/results/threadtest_scalability.png  figures/
cp ../mytkowicz/results/padding_sensitivity.png figures/
cd plots && python3 make_figures.py && cd ..
pdflatex report.tex && pdflatex report.tex
```

Output: `report/report.pdf` (6 pages).

## Requirements

All steps run without `sudo`. Tools required:
`gcc`, `git`, `wget`, `unzip`, `make`, `cmake`, `autoconf`,
`perf`, `valgrind`, `setarch`, `python3`, `pdflatex`,
`gnuplot` *or* `matplotlib`.