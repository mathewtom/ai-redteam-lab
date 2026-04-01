# AI Red Team Lab

Adversarial testing of [SecureRAG-Sentinel](https://github.com/mathewtom/SecureRAG-Sentinel) — a security-hardened RAG pipeline — using open-source red teaming tools.

The target system treats the LLM as an untrusted component: documents are sanitized before they hit the vector store, access-controlled before they reach the model, and rate-limited at the API boundary. This repo exists to find out where those defenses break.

## Target System

SecureRAG-Sentinel is a RAG pipeline built with LangChain, ChromaDB, Presidio, and Ollama (LLaMA 3.1 8B). It has four defensive layers:

| Layer | Defense | Status |
|-------|---------|--------|
| 1 | Regex + NER pattern matching (injection scanner, PII detector) | ✅ Deployed |
| 2 | Embedding similarity to known injection patterns | 🔲 Planned |
| 3 | Instruction classifier | 🔲 Planned |
| 4 | Output monitoring | 🔲 Planned |

Full architecture, OWASP/ATLAS mappings, and threat model are in the [main repo](https://github.com/mathewtom/SecureRAG-Sentinel).

## Tools

Each tool gets its own directory with configs, scripts, and a local README explaining how to run it.

| Tool | Purpose | Directory |
|------|---------|-----------|
| [Garak](https://github.com/NVIDIA/garak) (NVIDIA) | Broad vulnerability scanning — prompt injection, DAN, encoding bypasses | `garak/` |
| [Promptfoo](https://github.com/promptfoo/promptfoo) | Repeatable YAML-based red team tests, CI/CD integration | `promptfoo/` |
| [PyRIT](https://github.com/Azure/PyRIT) (Microsoft) | Multi-turn adaptive attacks, Crescendo, converter chains | `pyrit/` |
| [DeepTeam](https://github.com/confident-ai/deepteam) (Confident AI) | Unit-test-style red teaming, LLM-as-judge evaluation | `deepteam/` |
| [FuzzyAI](https://github.com/cyberark/FuzzyAI) (CyberArk) | Genetic mutation fuzzing, Unicode smuggling, ASCII art attacks | `fuzzyai/` |

## Methodology

Every tool runs a two-phase scan:

1. **Phase 1 — Baseline**: Scan the raw Ollama model directly (no security layers)
2. **Phase 2 — Protected**: Scan the full pipeline through the FastAPI endpoint (all defenses active)

The delta in Attack Success Rate (ASR) between phases measures the value of each defense layer. Results are logged in `results/` with timestamps.

## Prerequisites

- [SecureRAG-Sentinel](https://github.com/mathewtom/SecureRAG-Sentinel) cloned and running locally
- [Ollama](https://ollama.com) with `llama3.1:8b` pulled
- Python 3.12+
- Node.js 18+ (for Promptfoo only)

## Quick Start

```bash
# 1. Clone this repo alongside your SecureRAG-Sentinel checkout
git clone https://github.com/mathewtom/ai-redteam-lab.git
cd ai-redteam-lab

# 2. In a separate terminal, start the target system
cd /path/to/SecureRAG-Sentinel
source .venv/bin/activate
python -m src.pipeline          # populate ChromaDB
uvicorn src.api:app --port 8000 # start API

# 3. Start with Garak (see garak/README.md for details)
cd garak
python3 -m venv .venv
source .venv/bin/activate
pip install -U git+https://github.com/NVIDIA/garak.git@main
./scan_baseline.sh
./scan_pipeline.sh
```

## Results

Scan results, HTML reports, and ASR comparisons are tracked in `results/`. See `results/README.md` for the format.

## Security Mappings

All findings are mapped to:
- [OWASP Top 10 for LLM Applications (2025)](https://genai.owasp.org)
- [MITRE ATLAS](https://atlas.mitre.org)

## License

MIT
