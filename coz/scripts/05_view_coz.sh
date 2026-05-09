#!/usr/bin/env bash
#
# Open the Coz viewer on a profile.
#
set -euo pipefail
cd "$(dirname "$0")/.."

VARIANT="${1:-baseline}"
PROFILE="results/coz/profile_${VARIANT}.jsonl"

if [ ! -f "$PROFILE" ]; then
    echo "ERROR: $PROFILE not found."
    exit 1
fi

echo "==== text-mode summary for $PROFILE ===="
third_party/coz/coz plot --text -i "$PROFILE" || true

echo
echo "==== to launch the interactive viewer (opens a browser tab): ===="
echo "    third_party/coz/coz plot -i $PROFILE"
echo
echo "If running on elnux over SSH, forward the viewer's port, e.g.:"
echo "    ssh -L 8000:localhost:8000 elnux2.cs.umass.edu"
echo "then run the plot command on elnux."