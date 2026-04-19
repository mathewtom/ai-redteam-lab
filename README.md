# AI Red Team Lab

Adversarial testing of two security-hardened RAG targets:

- **[SecureRAG-Sentinel](https://github.com/mathewtom/SecureRAG-Sentinel)** — classical RAG with a seven-layer defense stack
- **[SecureRAG-Agent](https://github.com/mathewtom/SecureRAG-Agent)** — the agentic fork with 7 authorization-guarded tools (LangGraph ReAct)

Configs and reports are partitioned by target under each tool directory:

```
garak/
├── SecureRAG-Sentinel/{configs,scripts,reports}/
└── SecureRAG-Agent/{configs,scripts,reports}/
promptfoo/
├── SecureRAG-Sentinel/{configs,reports}/
└── SecureRAG-Agent/{configs,reports}/
```

Shared tooling (`garak/.venv`, `promptfoo/node_modules`) lives at the tool
root. See the per-target READMEs inside each directory for run instructions.

---

## Original context — SecureRAG-Sentinel

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
| [Garak](https://github.com/NVIDIA/garak) (NVIDIA) | Broad vulnerability scanning — prompt injection, DAN, encoding bypasses | [garak/](garak/) | ✅ Active (V5 scan complete) |
| [Promptfoo](https://github.com/promptfoo/promptfoo) | Eval + red team. Iterative LLM-driven attacks with Claude as attacker/grader. Best fit for access control & RAG-specific abuses. | [promptfoo/](promptfoo/) | ✅ Active (V1 baseline + pipeline complete) |
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

> **Rate limiting.** SecureRAG-Sentinel's `docker-compose.yml` now sets `SECURERAG_RATE_MODE=test` by default, which fully disables the per-user rate limiter for dev / security scanning. (Older Sentinel checkouts defaulted to prod mode at 10 req/60s, which would 429 every scan after the 10th request — pull the latest Sentinel `main` if you see rate-limit-blocked scans.)

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

Scan results, HTML reports, and ASR comparisons are tracked in [`results/`](results/). See `results/README.md` for the format.

### Findings to date

| Tool / scan | Date | Target | Headline ASR | Real ASR (after triage) | Top finding |
|---|---|---|---:|---:|---|
| Garak V5 | 2026-04-02 | Sentinel `/query` | 7.9% | ~0.7% | Latent injection (~19% on `LatentInjectionReport`); see [Sentinel `reports/`](https://github.com/mathewtom/SecureRAG-Sentinel/tree/main/reports) |
| [Promptfoo Baseline V1](results/promptfoo/promptfoo_baseline_v1.md) | 2026-04-09 | Raw Llama 3.3 70B (no defenses) | 28.28% | n/a (raw model upper bound) | `rag-document-exfiltration` 66.7%, `hijacking` 58.3%; iterative attacker is 3× the static strategy |
| [Promptfoo Pipeline V1](results/promptfoo/promptfoo_pipeline_v1.md) | 2026-04-10 | Sentinel `/query` (full stack, Haiku grader) | 55.15% | **~1.2%** | **AWS access keys leaked from `vendor_security_assessment.txt` in 81/165 responses.** Fixed same day with 21-pattern CredentialDetector. The other 89 "failures" were Haiku grader noise. |
| [Promptfoo Pipeline V2](results/promptfoo/promptfoo_pipeline_v2.md) | 2026-04-10 | Sentinel `/query` (full stack + credential fix, Sonnet attacker + grader) | 21.21% | **0.0%** | **Zero real defense bypasses.** All 35 failures are base64 strategy "No output" infrastructure artifacts (Llama can't decode base64 → refuses → promptfoo's built-in detector fires). Every non-base64 strategy: **0% ASR** (basic 0/45, jailbreak-templates 0/40, jailbreak:meta 0/40). Credential fix verified — zero AKIA strings in any response. Sonnet grader with explicit authorization table: zero false positives across 125 non-base64 tests. |

The V1→V2 pipeline progression tells a complete red-team story: V1 found a real credential leak (AWS keys bypassing Presidio) and exposed Haiku-as-grader as a methodology weakness. Both were fixed same day. V2 confirmed the fix and produced a clean measurement with a Sonnet-class adaptive attacker — 0% real ASR across 125 meaningful tests.

## Security Mappings

All findings are mapped to:
- [OWASP Top 10 for LLM Applications (2025)](https://genai.owasp.org)
- [MITRE ATLAS](https://atlas.mitre.org)

## License

MIT
