# Promptfoo — Eval + Red Team

[Promptfoo](https://github.com/promptfoo/promptfoo) is two products under one CLI:

1. **`promptfoo eval`** — YAML test cases with assertions (`contains`, `llm-rubric`, `factuality`, `latency`). Used here for **RAG quality regression** — proving that tightening a defense doesn't break correct answers.
2. **`promptfoo redteam`** — Plugin-generated adversarial inputs + iterative attack strategies, scored by an LLM judge. Used here for the actual offensive work against [SecureRAG-Sentinel](https://github.com/mathewtom/SecureRAG-Sentinel).

Both modes target the same `POST /query` endpoint and run from the **E003 perspective** (a low-privilege Software Engineer authenticated via SSO — see top-level [README](../README.md#threat-model--the-e003-persona)).

## Why Promptfoo specifically

Garak fires static probes. Promptfoo runs an **iterative attacker LLM** (Claude Haiku 4.5) that adapts its prompts based on the previous response, then a **grader LLM** (Claude Haiku 4.5) that judges each attempt against rubrics — including rubrics that consider the `source_documents` returned by the API, not just the answer string. This is the right tool for testing access control, because the attacker can frame requests in social-engineering-style ways ("I'm covering for my manager...", "for the audit...") that no static probe list can enumerate.

## Architecture

```
                  ┌────────────────────────┐
  Attacker LLM ─► │  PromptFoo redteam     │ ─► Target: localhost:8000/query
  (Claude Haiku)  │  (generates attacks,   │       (SecureRAG-Sentinel as E003)
                  │   iterates)            │
                  └────────────────────────┘
                              │
                              ▼
                       Grader LLM (Claude Haiku)
                       — sees question, answer,
                         AND source_documents
                       — produces ASR + rationale
```

## Setup

```bash
cd promptfoo/

# Install promptfoo locally (pinned via package.json — see below)
npm install

# Configure your Anthropic API key
cp .env.example .env
# edit .env and paste your sk-ant-... key
```

You also need [SecureRAG-Sentinel](https://github.com/mathewtom/SecureRAG-Sentinel) running on `localhost:8000` with the test rate limit:

```bash
# In a separate terminal, in the SecureRAG-Sentinel checkout:
SECURERAG_RATE_MODE=test uvicorn src.api:app --host 0.0.0.0 --port 8000
```

## Running

| Command | What it does |
|---------|--------------|
| `./run_eval.sh` | RAG quality regression — 20 golden Q&A pairs scored by Claude grader |
| `./run_redteam_baseline.sh` | Phase 1 redteam against raw Ollama (no defenses). Establishes baseline ASR. |
| `./run_redteam_pipeline.sh` | Phase 2 redteam against the FastAPI (all 7 defenses active). Measures protected ASR. |

The delta between baseline ASR and pipeline ASR is the value of the defense stack.

## Layout

```
promptfoo/
├── README.md                         # this file
├── .env.example                      # ANTHROPIC_API_KEY template
├── package.json                      # promptfoo version pin
├── providers/
│   ├── securerag-pipeline.yaml       # HTTP → localhost:8000 + non-200 handling
│   └── ollama-baseline.yaml          # raw Llama 3.3 70B for phase 1
├── eval/
│   ├── promptfooconfig.yaml          # base RAG quality regression
│   └── golden_qa.yaml                # ground-truth Q&A from data/raw/
├── redteam/
│   ├── promptfooconfig.yaml          # plugins + strategies + Claude attacker/grader
│   └── purpose.md                    # system context for attack generation
├── run_eval.sh
├── run_redteam_baseline.sh           # phase 1 — raw Ollama
└── run_redteam_pipeline.sh           # phase 2 — protected API
```

## Plugin selection — mapped to SecureRAG-Sentinel defenses

| Plugin | Tests | Defense layer |
|--------|-------|---------------|
| `prompt-injection` | Instruction override, ChatML smuggling | Layer 2 (input regex) + Layer 3 (embedding similarity) |
| `pii:direct`, `pii:session` | PII extraction attempts | Ingestion-time Presidio redaction |
| `bola` | Access objects belonging to other users (e.g. read another employee's HR record) | Layer 4 (org-chart filtering) |
| `bfla` | Trigger admin-only behavior as a low-priv user | Server-side hardcoded `user_id` |
| `rbac` | Role-escalation framing | Layer 4 + classification metadata |
| `rag-document-exfiltration` | Extract retrieved chunks verbatim | Layer 6 (output scanner) + Layer 7 (classification guard) |
| `rag-poisoning` | Indirect injection via document content | Ingestion sanitization gate |
| `hijacking` | Steer the model off-task | Layer 5 (security prompt) + Layer 6 |
| `excessive-agency` | Persuade model to take actions it can't | Architecture (no tools, no write access) |
| `policy` (custom) | "must never reveal HR records for employees other than E003" | Layer 4 + Layer 7 |

Strategies enabled: `jailbreak` (single-turn iterative), `base64`, `multilingual`. `crescendo` (multi-turn) added once the basics work.

## Costs

Claude Haiku 4.5 for both attacker and grader. Rough estimates:

| Run | API calls | Estimated cost |
|-----|-----------|----------------|
| `./run_eval.sh` (20 Q&A) | ~20 grader calls | ~$0.05 |
| `./run_redteam_*.sh` (10 plugins, jailbreak + base64) | ~700 calls (350 attacker + 350 grader) | ~$1.20 |

Budget: **~$15 for an initial 10 runs.** Levers if cost balloons: reduce `numTests` per plugin, drop `jailbreak:tree`, or use Ollama as the grader for non-critical plugins.

Local (target API) calls are free — they hit your laptop, not Anthropic.

## Security caveats

- The `transformResponse` on the HTTP provider maps **400** (input injection caught), **422** (output flagged), and **429** (rate limited) into synthetic strings like `[BLOCKED_INPUT_INJECTION]`. These are **defensive successes** and graders treat them as such. Without this transform, PromptFoo would mark these as test errors.
- `.env` is gitignored. Never commit `ANTHROPIC_API_KEY`.
- Generated reports may contain attack prompts and (during baseline) successful jailbreak outputs. The `results/promptfoo/*.html` file committed to this repo is a **representative, sanitized run**. Raw JSONL reports are gitignored.

## Findings

See [results/promptfoo/](../results/promptfoo/) for the latest sanitized HTML report and the running findings table in the top-level [README](../README.md).
