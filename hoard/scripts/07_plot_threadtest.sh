#!/usr/bin/env bash
#
# Build a scalability plot from results/threadtest_*.csv using gnuplot
# Generates results/threadtest_scalability.png.
#
# If gnuplot isn't available, the script falls back to a Python
# matplotlib fallback.
#
set -euo pipefail
cd "$(dirname "$0")/.."

CSVS=$(ls results/threadtest_*.csv 2>/dev/null || true)
if [ -z "$CSVS" ]; then
    echo "ERROR: no results/threadtest_*.csv found. Run 04_run_threadtest.sh first."
    exit 1
fi

if command -v gnuplot >/dev/null 2>&1; then
    gnuplot <<'GNUEOF'
set terminal pngcairo size 900,600 enhanced font 'Sans,11'
set output 'results/threadtest_scalability.png'
set title 'threadtest: throughput vs threads (median of 3 runs)'
set xlabel 'Threads'
set ylabel 'Throughput (ops/s)'
set logscale y
set grid
set key bottom right
set datafile separator ','
plot \
    'results/threadtest_glibc.csv'    using 1:6 with linespoints lw 2 pt 7 title 'glibc (ptmalloc2)', \
    'results/threadtest_hoard.csv'    using 1:6 with linespoints lw 2 pt 5 title 'Hoard', \
    'results/threadtest_jemalloc.csv' using 1:6 with linespoints lw 2 pt 9 title 'jemalloc', \
    'results/threadtest_mimalloc.csv' using 1:6 with linespoints lw 2 pt 11 title 'mimalloc'
GNUEOF
    echo "Wrote results/threadtest_scalability.png (gnuplot)"
    exit 0
fi

# Fallback: matplotlib
python3 - <<'PYEOF'
import csv, glob, os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

fig, ax = plt.subplots(figsize=(9, 6))
for path in sorted(glob.glob('results/threadtest_*.csv')):
    name = os.path.basename(path).replace('threadtest_', '').replace('.csv', '')
    threads, tput = [], []
    with open(path) as f:
        r = csv.DictReader(f)
        for row in r:
            threads.append(int(row['threads']))
            tput.append(float(row['throughput_ops_s']))
    ax.plot(threads, tput, marker='o', linewidth=2, label=name)

ax.set_yscale('log')
ax.set_xlabel('Threads')
ax.set_ylabel('Throughput (ops/s)')
ax.set_title('threadtest: throughput vs threads (median of 3 runs)')
ax.grid(True, which='both', alpha=0.3)
ax.legend(loc='lower right')
plt.tight_layout()
plt.savefig('results/threadtest_scalability.png', dpi=120)
print("Wrote results/threadtest_scalability.png (matplotlib)")
PYEOF