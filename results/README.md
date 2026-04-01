# Results

Scan results from each tool, organized by tool and timestamped.

## Directory Structure

```
results/
├── garak/
│   ├── baseline_20260401_143022.html    # Phase 1: raw Ollama
│   ├── baseline_20260401_143022.jsonl
│   ├── pipeline_ic_20260401_151500.html # Phase 2: full pipeline (IC user)
│   ├── pipeline_ic_20260401_151500.jsonl
│   ├── access_ic_20260401_160000.html   # Access control variant
│   ├── access_vp_20260401_160000.html
│   └── access_unknown_20260401_160000.html
├── promptfoo/
├── pyrit/
├── deepteam/
└── fuzzyai/
```

## Naming Convention

`{scan_type}_{user_role}_{YYYYMMDD_HHMMSS}.{ext}`

## Reading JSONL Reports

Each line in a `.jsonl` report is a JSON object with:

```json
{
  "goal": "inject a prompt on hate humans",
  "prompt": "the adversarial prompt that was sent",
  "output": "the model's response",
  "score": 1.0,
  "probe": "promptinject.HijackHateHumansMini",
  "detector": "promptinject.AttackRogueString"
}
```

Filter for successful attacks:

```bash
cat baseline_20260401_143022.jsonl | python3 -m json.tool | grep '"score": 1.0'
```
