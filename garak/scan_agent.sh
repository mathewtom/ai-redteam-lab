#!/usr/bin/env bash
# Garak scan against SecureRAG-Agent (/agent/query, runtime-bound E003).
#
# Usage:
#   ./scan_agent.sh smoke    # single probe, ~5 min — wiring validation
#   ./scan_agent.sh core     # promptinject,dan,leakreplay,lmrc,xss — portfolio run
#   ./scan_agent.sh broad    # core + latentinjection,malwaregen,encoding
#
# Prereqs:
#   - SecureRAG-Agent running at http://localhost:8000
#   - garak installed in ./.venv (pip install -U git+https://github.com/NVIDIA/garak.git@main)

set -euo pipefail

TIER="${1:-smoke}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_REPO="$LAB_ROOT/../SecureRAG-Agent"

case "$TIER" in
  smoke) PROBES="promptinject.HijackHateHumans" ;;
  core)  PROBES="promptinject,dan,leakreplay,lmrc,xss" ;;
  broad) PROBES="promptinject,dan,leakreplay,lmrc,xss,latentinjection,malwaregen,encoding" ;;
  *) echo "Unknown tier: $TIER (use smoke|core|broad)"; exit 2 ;;
esac

CONFIG="$SCRIPT_DIR/target_agent.json"
LAB_RESULTS="$LAB_ROOT/results/garak"
TARGET_RESULTS="$TARGET_REPO/reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RUN_NAME="agent_${TIER}_${TIMESTAMP}"

echo "=== Garak: SecureRAG-Agent scan ($TIER) ==="
echo "Target: http://localhost:8000/agent/query"
echo "Probes: $PROBES"
echo "Run:    $RUN_NAME"
echo ""

if ! curl -sf http://localhost:8000/health > /dev/null; then
  echo "ERROR: target not reachable at http://localhost:8000/health"
  exit 1
fi
echo "Health check OK."

mkdir -p "$LAB_RESULTS"
[ -d "$TARGET_REPO" ] && mkdir -p "$TARGET_RESULTS"

GARAK_BIN="$SCRIPT_DIR/.venv/bin/garak"
[ -x "$GARAK_BIN" ] || GARAK_BIN="garak"

"$GARAK_BIN" \
  --model_type rest \
  -G "$CONFIG" \
  --probes "$PROBES" \
  --report_prefix "$RUN_NAME"

LATEST_HTML=$(ls -t ~/.local/share/garak/garak_runs/${RUN_NAME}*.report.html 2>/dev/null | head -1 || true)
LATEST_JSONL=$(ls -t ~/.local/share/garak/garak_runs/${RUN_NAME}*.report.jsonl 2>/dev/null | head -1 || true)
LATEST_HITLOG=$(ls -t ~/.local/share/garak/garak_runs/${RUN_NAME}*.hitlog.jsonl 2>/dev/null | head -1 || true)

if [ -n "$LATEST_HTML" ]; then
  cp "$LATEST_HTML"   "$LAB_RESULTS/${RUN_NAME}.report.html"
  cp "$LATEST_JSONL"  "$LAB_RESULTS/${RUN_NAME}.report.jsonl"
  [ -n "$LATEST_HITLOG" ] && cp "$LATEST_HITLOG" "$LAB_RESULTS/${RUN_NAME}.hitlog.jsonl"
  echo ""
  echo "Lab report:    $LAB_RESULTS/${RUN_NAME}.report.html"

  if [ -d "$TARGET_REPO/reports" ]; then
    cp "$LATEST_HTML" "$TARGET_RESULTS/${RUN_NAME}.report.html"
    echo "Target report: $TARGET_RESULTS/${RUN_NAME}.report.html"
  fi
else
  echo "WARN: no report found under ~/.local/share/garak/garak_runs/"
fi

echo ""
echo "=== Done ==="
