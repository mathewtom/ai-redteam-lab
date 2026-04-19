#!/usr/bin/env bash
# Phase 2: Scan the full SecureRAG-Sentinel pipeline via REST.
# Requires: FastAPI running on port 8000 (uvicorn src.api:app --port 8000).
# NOTE: Temporarily raise the rate limit in src/api.py before running.

set -euo pipefail

PROBES="promptinject,dan,encoding,knownbadsignatures"
CONFIG="../configs/target_pipeline_ic.json"
RESULTS_DIR="../reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== Garak Phase 2: Pipeline scan (IC user E003) ==="
echo "Target: http://localhost:8000/query"
echo "Probes: $PROBES"
echo ""

# Sanity check: is the API reachable?
if ! curl -s http://localhost:8000/health > /dev/null 2>&1; then
  echo "ERROR: SecureRAG-Sentinel API not reachable on port 8000."
  echo "Start it with: cd /path/to/SecureRAG-Sentinel && uvicorn src.api:app --port 8000"
  exit 1
fi

echo "API health check passed."
echo ""

mkdir -p "$RESULTS_DIR"

garak \
  --model_type rest \
  -G "$CONFIG" \
  --probes "$PROBES"

# Copy reports to results
LATEST_REPORT=$(ls -t ~/.local/share/garak/garak_runs/*.report.html 2>/dev/null | head -1)
if [ -n "$LATEST_REPORT" ]; then
  cp "$LATEST_REPORT" "$RESULTS_DIR/pipeline_ic_${TIMESTAMP}.html"
  echo ""
  echo "Report copied to: $RESULTS_DIR/pipeline_ic_${TIMESTAMP}.html"
fi

LATEST_JSONL=$(ls -t ~/.local/share/garak/garak_runs/*.report.jsonl 2>/dev/null | head -1)
if [ -n "$LATEST_JSONL" ]; then
  cp "$LATEST_JSONL" "$RESULTS_DIR/pipeline_ic_${TIMESTAMP}.jsonl"
fi

echo ""
echo "=== Phase 2 complete. Compare with baseline report. ==="
