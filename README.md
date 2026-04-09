# AI Red Team Lab

Adversarial testing of [SecureRAG-Sentinel](https://github.com/mathewtom/SecureRAG-Sentinel) — a security-hardened RAG pipeline — using open-source red teaming tools.

The target system treats the LLM as an untrusted component: documents are sanitized before they hit the vector store, access-controlled before they reach the model, and rate-limited at the API boundary. This repo exists to find out where those defenses break.

## Target System

SecureRAG-Sentinel is a RAG pipeline built with LangChain, ChromaDB, Presidio, and Ollama (Llama 3.3 70B). It treats the LLM as an untrusted component and runs a seven-layer defense stack on every query:

| # | Layer | Status |
|---|-------|--------|
| 1 | Rate limiter (per-user sliding window) | ✅ Deployed |
| 2 | Input injection scan (scored regex patterns) | ✅ Deployed |
| 3 | Embedding similarity scan (cosine match against 100-prompt corpus) | ✅ Deployed |
| 4 | Access-controlled retrieval (org-chart + dept + classification) | ✅ Deployed |
| 5 | LLM inference with security prompt template | ✅ Deployed |
| 6 | Output scanner (regex fast path + Llama Guard 3 1B) | ✅ Deployed |
| 7 | Classification guard (output-side leak prevention) | ✅ Deployed |

Ingestion-side defenses (NFKC normalization, injection quarantine, PII redaction via Presidio) run before anything reaches the vector store.

Full architecture, OWASP/ATLAS mappings, and threat model are in the [main repo](https://github.com/mathewtom/SecureRAG-Sentinel).

## Threat Model — The E003 Persona

The API hardcodes the requesting user to **E003 (Priya Patel — Software Engineer, low privilege)** server-side. Adversarial tools cannot spoof identity by sending a different `user_id` in the request body. This models the real threat: *an authenticated low-privilege engineer trying to escape their bounds.*

Every test in this lab is run from the E003 perspective. Successful attacks are ones where E003 manages to:

- Read HR records for employees other than themselves
- Access classified documents from departments E003 isn't a member of (Legal, Finance, Executive)
- Override the system prompt or extract sanitized content
- Trigger PII disclosure or classification leaks through the output

## Tools

Each tool gets its own directory with configs, scripts, and a local README explaining how to run it.

| Tool | Purpose | Directory | Status |
|------|---------|-----------|--------|
| [Garak](https://github.com/NVIDIA/garak) (NVIDIA) | Broad vulnerability scanning — prompt injection, DAN, encoding bypasses | [garak/](garak/) | ✅ Active |
| [Promptfoo](https://github.com/promptfoo/promptfoo) | Eval + red team. Iterative LLM-driven attacks with Claude as attacker/grader. Best fit for access control & RAG-specific abuses. | [promptfoo/](promptfoo/) | ✅ Active |
| [PyRIT](https://github.com/Azure/PyRIT) (Microsoft) | Multi-turn adaptive attacks, Crescendo, converter chains | [pyrit/](pyrit/) | 🔲 Planned |
| [DeepTeam](https://github.com/confident-ai/deepteam) (Confident AI) | Unit-test-style red teaming, LLM-as-judge evaluation | [deepteam/](deepteam/) | 🔲 Planned |
| [FuzzyAI](https://github.com/cyberark/FuzzyAI) (CyberArk) | Genetic mutation fuzzing, Unicode smuggling, ASCII art attacks | [fuzzyai/](fuzzyai/) | 🔲 Planned |

## Methodology

Every tool runs a two-phase scan:

1. **Phase 1 — Baseline**: Scan the raw Ollama model directly (no security layers)
2. **Phase 2 — Protected**: Scan the full pipeline through the FastAPI endpoint (all defenses active)

The delta in Attack Success Rate (ASR) between phases measures the value of each defense layer. Results are logged in `results/` with timestamps.

## Prerequisites

- [SecureRAG-Sentinel](https://github.com/mathewtom/SecureRAG-Sentinel) cloned and running locally on `http://localhost:8000`
- [Ollama](https://ollama.com) with `llama3.3:70b` and `llama-guard3:1b` pulled
- Python 3.12+
- Node.js 18+ (for Promptfoo only)
- An [Anthropic API key](https://console.anthropic.com) (for Promptfoo's Claude attacker/grader). Garak runs entirely locally and does not need this.

> **Important — rate limiting.** SecureRAG-Sentinel defaults to 10 requests/60s per user. Adversarial scans need hundreds of requests; export `SECURERAG_RATE_MODE=test` (100k/10min) before starting the API or every scan will be 429'd to death.

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
