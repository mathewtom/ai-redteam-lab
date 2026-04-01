# Garak — Vulnerability Scanning

[Garak](https://github.com/NVIDIA/garak) (NVIDIA) is a broad-spectrum LLM vulnerability scanner. Think of it as `nmap` for LLMs — it fires pre-built probes at a target and reports which ones got through.

## Setup

Garak has heavy dependencies that conflict with the main project. Use a dedicated venv:

```bash
cd garak/
python3 -m venv .venv
source .venv/bin/activate
pip install -U git+https://github.com/NVIDIA/garak.git@main
```

Requires Python 3.10–3.12.

## Running Scans

### Phase 1 — Baseline (raw Ollama)

Scans LLaMA 3.1 8B directly through Ollama, bypassing all security layers:

```bash
# Make sure Ollama is running: ollama serve
./scan_baseline.sh
```

### Phase 2 — Full Pipeline (via FastAPI)

Scans through the SecureRAG-Sentinel API with all defenses active:

```bash
# Make sure the target API is running on port 8000
./scan_pipeline.sh
```

### Access Control Variant

Runs the same probes as different users to test access control boundaries:

```bash
./scan_access_control.sh
```

## Config Files

| File | Target | User |
|------|--------|------|
| `target_pipeline_ic.json` | FastAPI pipeline | E003 (IC — sees self only) |
| `target_pipeline_vp.json` | FastAPI pipeline | E001 (VP — sees everything) |
| `target_pipeline_unknown.json` | FastAPI pipeline | X999 (unknown — sees nothing) |

## Probe Selection

These probes are selected to map to SecureRAG-Sentinel's specific defenses:

| Probe | Targets | Defense Layer |
|-------|---------|---------------|
| `promptinject` | Instruction override, role hijacking | Layer 1 (InjectionScanner) |
| `dan` | Persona jailbreaks | Prompt template |
| `encoding` | Base64/ROT13/hex encoded payloads | Layer 2 (not built yet) |
| `knownbadsignatures` | Curated known-bad attack strings | Layer 1 + prompt template |
| `leakreplay` | Training data / document content leakage | PII redaction |
| `xss` | Cross-site scripting in output | Layer 4 (not built yet) |

## Output

Reports land in `~/.local/share/garak/garak_runs/`. The scan scripts copy the HTML report into `../results/garak/` after each run.
