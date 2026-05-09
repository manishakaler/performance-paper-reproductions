#!/usr/bin/env bash
#
# Plot throughput vs. padding with 95% CI error bars.
# Generates results/padding_sensitivity.png.
#
set -euo pipefail
cd "$(dirname "$0")/.."

CSV=results/padding_summary.csv
[ -f "$CSV" ] || { echo "ERROR: $CSV not found. Run 03_analyze.sh first."; exit 1; }

if command -v gnuplot >/dev/null 2>&1; then
    gnuplot <<'GNUEOF'
set terminal pngcairo size 1000,500 enhanced font 'Sans,11'
set output 'results/padding_sensitivity.png'
set title 'Layout sensitivity: median elapsed vs. environment-variable padding'
set xlabel 'PADDING env-var size (bytes)'
set ylabel 'Elapsed time (seconds)'
set grid
set key off
set datafile separator ','
plot 'results/padding_summary.csv' using 1:3:6 with yerrorbars lw 2 pt 7 lc rgb 'steelblue' notitle, \
     'results/padding_summary.csv' using 1:3 with lines lw 1 lc rgb 'steelblue' dt 2 notitle
GNUEOF
    echo "Wrote results/padding_sensitivity.png (gnuplot)"
    exit 0
fi

# matplotlib fallback
python3 - <<'PYEOF'
import csv
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

xs, means, ci = [], [], []
with open('results/padding_summary.csv') as f:
    r = csv.DictReader(f)
    for row in r:
        xs.append(int(row['padding']))
        means.append(float(row['mean_s']))
        ci.append(float(row['ci95_s']))

fig, ax = plt.subplots(figsize=(10, 5))
ax.errorbar(xs, means, yerr=ci, marker='o', linewidth=1, linestyle='--',
            capsize=3, color='steelblue', ecolor='steelblue')
ax.set_xlabel('PADDING env-var size (bytes)')
ax.set_ylabel('Elapsed time (s, mean of 10 runs ± 95% CI)')
ax.set_title('Layout sensitivity: elapsed time vs. environment-variable padding')
ax.grid(alpha=0.3)
plt.tight_layout()
plt.savefig('results/padding_sensitivity.png', dpi=120)
print("Wrote results/padding_sensitivity.png (matplotlib)")
PYEOF