#!/usr/bin/env python3
import csv
import math
import sys
from collections import defaultdict

if len(sys.argv) != 3:
    print("usage: collect_stats.py input.csv output.csv")
    sys.exit(1)

inp, outp = sys.argv[1], sys.argv[2]

data = defaultdict(list)

with open(inp, newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        pad = int(row["pad_bytes"])
        t = float(row["elapsed_sec"])
        data[pad].append(t)

with open(outp, "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow([
        "pad_bytes", "n", "mean_sec", "stddev_sec",
        "ci95_low_sec", "ci95_high_sec"
    ])

    for pad in sorted(data):
        xs = data[pad]
        n = len(xs)
        mean = sum(xs) / n
        if n > 1:
            var = sum((x - mean) ** 2 for x in xs) / (n - 1)
            stddev = math.sqrt(var)
            sem = stddev / math.sqrt(n)
            ci = 1.96 * sem
        else:
            stddev = 0.0
            ci = 0.0

        writer.writerow([
            pad, n, mean, stddev,
            mean - ci, mean + ci
        ])