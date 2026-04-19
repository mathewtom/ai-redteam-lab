#!/usr/bin/env bash
# Phase 2b: Scan as different user roles to test access control boundaries.
# Runs the same probes as IC (E003), VP (E001), and unknown (X999).
# Compare results: if the IC or unknown scan returns HR data for other
# employees, the access control has a bypass.

set -euo pipefail

PROBES="promptinject,dan"
RESULTS_DIR="../reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Sanity check
if ! curl -s http://localhost:8000/health > /dev/null 2>&1; then
  echo "ERROR: SecureRAG-Sentinel API not reachable on port 8000."
  exit 1
fi

mkdir -p "$RESULTS_DIR"

for ROLE in ic vp unknown; do
  CONFIG="../configs/target_pipeline_${ROLE}.json"
  echo ""
  echo "=== Scanning as $ROLE (config: $CONFIG) ==="
  echo ""

  garak \
    --model_type rest \
    -G "$CONFIG" \
    --probes "$PROBES"

  LATEST_REPORT=$(ls -t ~/.local/share/garak/garak_runs/*.report.html 2>/dev/null | head -1)
  if [ -n "$LATEST_REPORT" ]; then
    cp "$LATEST_REPORT" "$RESULTS_DIR/access_${ROLE}_${TIMESTAMP}.html"
  fi

  LATEST_JSONL=$(ls -t ~/.local/share/garak/garak_runs/*.report.jsonl 2>/dev/null | head -1)
  if [ -n "$LATEST_JSONL" ]; then
    cp "$LATEST_JSONL" "$RESULTS_DIR/access_${ROLE}_${TIMESTAMP}.jsonl"
  fi
done

echo ""
echo "=== Access control scan complete. Compare reports across roles. ==="
