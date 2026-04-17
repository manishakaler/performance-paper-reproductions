# Project: Reproducing Classic Results

## Overview

Reproduction studies are undervalued but extremely educational. In this project, you will attempt to reproduce the core empirical results from three major papers from the course: Coz, Hoard, the Mytkowicz et al. paper. For each paper, your goal is to replicate what the authors did, measuring the same quantities on the EdLab hardware, and explaining any discrepancies between their findings and your observations. You will then turn in a project report with your findings by May 8th, 11:59pm.

## Paper 1 — Coz

Reproduce the SQLite case study from the Coz paper. Your goal is to identify the same bottleneck that Coz identifies and verify whether Coz's predicted speedup matches the actual speedup you observe after applying the described fix.

**Guidance:**
- Run Coz on the benchmark and locate the progress point and the critical line identified in the paper.
- Implement the fix described in the paper and measure the before/after speedup.
- Compare Coz's predicted speedup to the actual speedup you measure. Do they agree? If not, why?
- As a point of comparison, run `perf record` on the same benchmark. Does a conventional profiler point you toward the same bottleneck Coz identifies?

## Paper 2 — Hoard

Reproduce the false-sharing and scalability benchmarks from the Hoard paper. Your goal is to verify whether Hoard's performance advantage over a standard allocator still holds on modern hardware.

**Guidance:**
- Run the paper's benchmarks (or close equivalents) comparing Hoard against glibc's `ptmalloc2`.
- Hoard was published before `jemalloc` and `mimalloc` existed. Include those allocators in your comparison as well. Do not try to `sudo install` them as packages! Build them from source instead. This will provide you with necessary context for interpreting your results on modern systems.
- Use `perf c2c` to visualize false sharing and verify that Hoard eliminates it as claimed or explain why it doesn't.
- Scalability results are especially hardware-dependent. Carefully document the EdLab hardware specs and compare against what the paper reports.

## Paper 3 — Mytkowicz et al.

Reproduce the layout-sensitivity result. Your goal is to show that the same program, compiled with the same flags but linked with different amounts of padding, produces measurably different runtimes.

**Guidance:**
- Set up a harness that varies the padding (environment variable size or binary padding) as described in the paper and collects runtimes with proper statistical treatment (confidence intervals, multiple runs).
- Disable ASLR and control for other confounds the paper identifies, so that the layout effect is isolated.
- Use TMA and Cachegrind to explain the mechanism — specifically, how layout changes affect cache conflict misses and branch predictor state.
- Document the gap between your measured effect sizes and the paper's findings, and give a hardware-based explanation for any difference.

## Notes
- You do not have `sudo` access on the EdLab machines! Many of the packages you will need for this project, including `coz`, `hoard`, `jemalloc`, and `mimalloc` will need to be built from source instead.

## Deliverables

For each of the three papers, you will produce:

- **Reproduction scripts and data**: All scripts needed to re-run your experiments, raw data files, and the code to generate your plots. Everything should be runnable by someone else with access to the same machine.
- **Clear comparisons**: A clearly-outlined report of the numbers and data you gather and how they compare to the numbers and data reported by each paper. Be precise about which figures and tables in the paper you are replicating or comparing against.
- **Hardware characterization**: A brief section documenting details of your hardware (CPU model, core count, cache sizes, memory bandwidth from `lmbench` or equivalent) and explaining how it differs from the hardware used in the paper in the dimensions that matter for the result. Do not just list the differences. Be specific about how they affect the paper's and your results.
- **Discrepancy analysis**: If your numbers differ meaningfully from the paper's, give a specific, mechanistic explanation. "Modern hardware is faster" is not a full or sufficient explanation. A better example would be something like "The L3 cache is 4× larger, which eliminates the conflict misses that drove the original effect".

Wrap all three reproductions into a single **reproduction report, about 6 pages long**. This should not be considered a hard limit. Your report should be complete, and if that means it is slightly shorter or longer than 6 pages, then that is fine. The report should read as a unified document, not three separate mini-reports stapled together. It should include a cohesive introduction to the papers, discuss common methodological lessons across all three, and conclude with what the exercise taught you about the durability of performance engineering results.

This report and all of the associated code and will be due on May 8th, 11:59pm.
