# AI Red-Team Lab

Adversarial testing of two RAG systems — [SecureRAG-Sentinel](https://github.com/mathewtom/SecureRAG-Sentinel)
(classical RAG) and [SecureRAG-Agent](https://github.com/mathewtom/SecureRAG-Agent)
(LangGraph ReAct agent with seven authorization-guarded tools). Configs,
scripts, and findings live under each tool's directory; per-tool READMEs
have full run instructions.

Both targets treat the LLM as untrusted. Every test runs from the E003
persona — Priya Patel, low-privilege Software Engineer — against the
production HTTP boundary. The API hardcodes E003 server-side, so
adversarial tools can't spoof identity by sending a different `user_id`
in the request body.

> The custom AutoDAN-HGA surrogate-transfer harness has been spun out
> into its own repo: [mathewtom/AutoDAN-HGA](https://github.com/mathewtom/AutoDAN-HGA).

---

## Tools

| Tool | Target | Status |
|---|---|---|
| [Garak](garak/) (NVIDIA) | Sentinel `/query` | V5 scan complete |
| [Promptfoo](promptfoo/) | Sentinel `/query` | V1 + V2 complete |
| [PyRIT](https://github.com/Azure/PyRIT) (Microsoft) | — | Planned |
| [DeepTeam](https://github.com/confident-ai/deepteam) | — | Planned |
| [FuzzyAI](https://github.com/cyberark/FuzzyAI) (CyberArk) | — | Planned |

---

### Garak

NVIDIA's broad probe set — DAN variants, encoding bypasses, latent-injection
patterns. Two-phase methodology: raw Llama 3.3 70B baseline first, then the
full pipeline. The ASR delta measures how much each defense layer
contributes.

V5 against Sentinel `/query` produced a 7.9% headline ASR. After triage —
removing detector-noise false positives and Llama Guard refusals that the
matchers were counting as "successes" — the real ASR was about 0.7%.
Latent injection was the strongest probe family at ~19% on
`LatentInjectionReport`; a corresponding fix landed in Sentinel's input
scanner. Reports and run instructions in [garak/](garak/).

---

### Promptfoo

Iterative LLM-driven attacker plus LLM-as-judge grader. Best fit for
access control and RAG-specific abuses where a static probe set runs
out of ideas. Two passes against Sentinel:

V1 (Haiku attacker + grader) found a real defect: AWS access keys from a
seeded vendor-assessment document were leaking through Presidio's PII
layer in 81 of 165 responses. Same-day fix — a 21-pattern
CredentialDetector. V1 also exposed Haiku-as-grader as a methodology
weakness; most other "failures" were grader noise, not real bypasses.

V2 (Sonnet attacker + grader, after the credential fix) produced a clean
measurement: 0% real ASR across 125 non-base64 tests. The 35 remaining
"failures" are all base64-strategy infrastructure artifacts where Llama
refuses to decode the input and Promptfoo's built-in detector counts the
refusal as "no output." No actual defense bypasses, no AKIA strings in
any reply, zero false positives from the Sonnet grader. Reports in
[promptfoo/](promptfoo/).

---

## Repository layout

```
garak/
├── SecureRAG-Sentinel/{configs,scripts,reports}/
└── SecureRAG-Agent/{configs,scripts,reports}/
promptfoo/
├── SecureRAG-Sentinel/{configs,reports}/
└── SecureRAG-Agent/{configs,reports}/
results/    # cross-tool ASR comparisons and HTML reports
```

Tooling lives at each tool root: `garak/.venv`, `promptfoo/node_modules`.
Run instructions are in each tool's local README.

---

## Prerequisites

- The relevant target repo cloned alongside this lab and running locally
  at `http://localhost:8000`.
- [Ollama](https://ollama.com) with `llama3.3:70b` and `llama-guard3:1b`
  pulled.
- Python 3.12+, Node.js 18+ (Promptfoo only).
- An [Anthropic API key](https://console.anthropic.com) for Promptfoo's
  Claude attacker/grader. Garak runs entirely locally.

Sentinel's `docker-compose.yml` defaults to `SECURERAG_RATE_MODE=test`
(rate limiter off for scans). Older Sentinel checkouts default to prod
mode at 10 req/60s and will 429 every scan after the 10th request; pull
the latest Sentinel `main` if you see rate-limit-blocked scans.

---

## Security mappings

Findings are mapped to [OWASP Top 10 for LLM Applications (2025)](https://genai.owasp.org)
and [MITRE ATLAS](https://atlas.mitre.org).

---

## License

MIT
