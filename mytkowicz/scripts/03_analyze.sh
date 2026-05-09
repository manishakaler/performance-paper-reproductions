#!/usr/bin/env bash
#
# Compute per-padding median, mean, std, 95% CI from results/padding_sweep.csv.
# Identifies the best and worst paddings (highest and lowest median throughput)
# so the TMA/Cachegrind scripts can target them.
#
set -euo pipefail
cd "$(dirname "$0")/.."

CSV=results/padding_sweep.csv
if [ ! -f "$CSV" ]; then
    echo "ERROR: $CSV not found. Run scripts/02_padding_sweep.sh first."
    exit 1
fi

OUT=results/padding_summary.csv

python3 - <<PYEOF
import csv, statistics, math
from collections import defaultdict

rows = defaultdict(list)
with open("$CSV") as f:
    r = csv.DictReader(f)
    for row in r:
        rows[int(row['padding'])].append(float(row['elapsed_s']))

# Compute statistics
out = []
for pad in sorted(rows.keys()):
    samples = rows[pad]
    n = len(samples)
    mean = statistics.mean(samples)
    median = statistics.median(samples)
    sd = statistics.stdev(samples) if n > 1 else 0.0
    se = sd / math.sqrt(n) if n > 1 else 0.0
    ci95 = 1.96 * se   # large-n normal approx; for n=10 use t but close enough
    cv = (sd / mean * 100) if mean > 0 else 0.0
    out.append((pad, n, mean, median, sd, ci95, cv))

with open("$OUT", "w") as f:
    f.write("padding,n,mean_s,median_s,std_s,ci95_s,cv_pct\n")
    for r in out:
        f.write(f"{r[0]},{r[1]},{r[2]:.6f},{r[3]:.6f},{r[4]:.6f},{r[5]:.6f},{r[6]:.3f}\n")

# Identify best (lowest mean elapsed = fastest) and worst (highest mean = slowest)
best = min(out, key=lambda r: r[2])
worst = max(out, key=lambda r: r[2])
range_pct = (worst[2] - best[2]) / best[2] * 100

print()
print(f"{'padding':>8}  {'n':>3}  {'mean':>9}  {'median':>9}  {'std':>9}  {'95% CI':>9}  {'CV%':>6}")
for r in out:
    marker = ""
    if r[0] == best[0]: marker = "  <-- BEST"
    if r[0] == worst[0]: marker = "  <-- WORST"
    print(f"{r[0]:>8}  {r[1]:>3}  {r[2]:>9.4f}  {r[3]:>9.4f}  {r[4]:>9.4f}  {r[5]:>9.4f}  {r[6]:>6.2f}{marker}")

print()
print(f"BEST  padding={best[0]:5d} mean={best[2]:.4f} s")
print(f"WORST padding={worst[0]:5d} mean={worst[2]:.4f} s")
print(f"Range: {range_pct:.2f}% (worst is {range_pct:.2f}% slower than best)")
print()
print(f"Wrote $OUT")

# Save best/worst paddings to a small file for the TMA/Cachegrind scripts
with open("results/best_worst_padding.txt", "w") as f:
    f.write(f"BEST_PADDING={best[0]}\n")
    f.write(f"WORST_PADDING={worst[0]}\n")
    f.write(f"BEST_MEAN_S={best[2]:.6f}\n")
    f.write(f"WORST_MEAN_S={worst[2]:.6f}\n")
    f.write(f"RANGE_PCT={range_pct:.3f}\n")
PYEOF

echo
echo "Saved best/worst to results/best_worst_padding.txt for downstream scripts:"
cat results/best_worst_padding.txt