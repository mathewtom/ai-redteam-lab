#!/usr/bin/env bash
# Phase 1: Scan the raw Ollama model (no security layers).
# Requires: ollama serve running with llama3.1:8b pulled.

set -euo pipefail

PROBES="promptinject,dan,encoding,knownbadsignatures"
MODEL="llama3.1:8b"
RESULTS_DIR="../results/garak"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== Garak Phase 1: Baseline scan of raw Ollama model ==="
echo "Model:  $MODEL"
echo "Probes: $PROBES"
echo ""

mkdir -p "$RESULTS_DIR"

garak \
  --model_type ollama \
  --model_name "$MODEL" \
  --probes "$PROBES"

# Copy the latest HTML report to results
LATEST_REPORT=$(ls -t ~/.local/share/garak/garak_runs/*.report.html 2>/dev/null | head -1)
if [ -n "$LATEST_REPORT" ]; then
  cp "$LATEST_REPORT" "$RESULTS_DIR/baseline_${TIMESTAMP}.html"
  echo ""
  echo "Report copied to: $RESULTS_DIR/baseline_${TIMESTAMP}.html"
fi

LATEST_JSONL=$(ls -t ~/.local/share/garak/garak_runs/*.report.jsonl 2>/dev/null | head -1)
if [ -n "$LATEST_JSONL" ]; then
  cp "$LATEST_JSONL" "$RESULTS_DIR/baseline_${TIMESTAMP}.jsonl"
fi

echo ""
echo "=== Phase 1 complete. Run scan_pipeline.sh for Phase 2. ==="
