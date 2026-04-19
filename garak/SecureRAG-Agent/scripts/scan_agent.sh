#!/usr/bin/env bash
# Garak scan against SecureRAG-Agent (/agent/query, runtime-bound E003).
#
# Usage:
#   ./scan_agent.sh smoke    # single probe, ~5 min — wiring validation
#   ./scan_agent.sh core     # promptinject,dan,leakreplay,lmrc — portfolio run
#   ./scan_agent.sh broad    # core + latentinjection,malwaregen,encoding
#
# Paths (target-partitioned layout):
#   configs : garak/SecureRAG-Agent/configs/target_agent.json
#   reports : garak/SecureRAG-Agent/reports/   (lab, public)
#             ../SecureRAG-Agent/reports/      (target repo, public)
#
# Prereqs:
#   - SecureRAG-Agent running at http://localhost:8000
#   - garak installed in garak/.venv (pip install -U git+https://github.com/NVIDIA/garak.git@main)

set -euo pipefail

TIER="${1:-smoke}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"           # garak/SecureRAG-Agent
GARAK_DIR="$(cd "$TARGET_DIR/.." && pwd)"            # garak/
LAB_ROOT="$(cd "$GARAK_DIR/.." && pwd)"              # ai-redteam-lab/
TARGET_REPO="$LAB_ROOT/../SecureRAG-Agent"

case "$TIER" in
  smoke) PROBES="promptinject.HijackHateHumans" ;;
  core)  PROBES="promptinject,dan,leakreplay,lmrc" ;;
  broad) PROBES="promptinject,dan,leakreplay,lmrc,latentinjection,malwaregen,encoding" ;;
  *) echo "Unknown tier: $TIER (use smoke|core|broad)"; exit 2 ;;
esac

CONFIG="$TARGET_DIR/configs/target_agent.json"
LAB_REPORTS="$TARGET_DIR/reports"
TARGET_REPO_REPORTS="$TARGET_REPO/reports"
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

mkdir -p "$LAB_REPORTS"
[ -d "$TARGET_REPO" ] && mkdir -p "$TARGET_REPO_REPORTS"

GARAK_BIN="$GARAK_DIR/.venv/bin/garak"
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
  cp "$LATEST_HTML"   "$LAB_REPORTS/${RUN_NAME}.report.html"
  cp "$LATEST_JSONL"  "$LAB_REPORTS/${RUN_NAME}.report.jsonl"
  [ -n "$LATEST_HITLOG" ] && cp "$LATEST_HITLOG" "$LAB_REPORTS/${RUN_NAME}.hitlog.jsonl"
  echo ""
  echo "Lab report:    $LAB_REPORTS/${RUN_NAME}.report.html"

  if [ -d "$TARGET_REPO_REPORTS" ]; then
    cp "$LATEST_HTML" "$TARGET_REPO_REPORTS/${RUN_NAME}.report.html"
    echo "Target report: $TARGET_REPO_REPORTS/${RUN_NAME}.report.html"
  fi
else
  echo "WARN: no report found under ~/.local/share/garak/garak_runs/"
fi

echo ""
echo "=== Done ==="
