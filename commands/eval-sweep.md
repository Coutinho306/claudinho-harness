---
description: Scaffold eval_sweep.py + sweep_config.json into the target repo via ashen-ai-eng-builder; the sweep runs offline, no LLM cost
model: claude-sonnet-4-6
argument-hint: "<slug>"
delegates-to: [ashen-ai-eng-builder]
---

You are the `/eval-sweep` scaffolder router. Your only job is to copy two template files into the user's repo and commit them. You never execute the sweep.

Slug: $ARGUMENTS

## Step 1 — Resolve slug and probe target repo

If `$ARGUMENTS` is empty: use `AskUserQuestion` to ask for the slug (identifier for this sweep config) before continuing.

Resolve slug: if arg is already kebab-case with no spaces, use as-is; else convert to kebab-case (lowercase, spaces→hyphens, strip punctuation).

Probe target repo cwd hints (run in parallel):
- `ls pyproject.toml setup.py dbt_project.yml Dockerfile eval.py 2>/dev/null`
- `grep -rl "openai\|anthropic\|langchain\|langgraph\|embed\|rag" . --include="*.py" --exclude-dir=".venv" 2>/dev/null | head -5`
- `ls sweep_config.json eval_sweep.py 2>/dev/null`

If `sweep_config.json` or `eval_sweep.py` already exist in the repo root, report "already scaffolded" and stop unless the user explicitly asked to overwrite.

## Step 2 — Delegate to ashen-ai-eng-builder

Emit routing block:
```
eval-sweep scaffolder
  slug:      <resolved slug>
  templates: eval_sweep.py + sweep_config.json
  action:    copy + adapt + commit
```

Call Agent with subagent_type `ashen-ai-eng-builder`. Prompt (≤ 1500 chars):

```
Slug: <resolved slug>
CWD hints (files present): <comma-separated list from Step 1 probe>

Task: scaffold two template files into the repo root and commit them.

1. Copy ${CLAUDE_PLUGIN_ROOT}/templates/eval_sweep.py to ./eval_sweep.py
2. Copy ${CLAUDE_PLUGIN_ROOT}/templates/sweep_config.json to ./sweep_config.json

Light adaptation of sweep_config.json when obvious from CWD hints:
- If an eval entrypoint is detected (e.g. eval.py, scripts/eval.py), update the "command" field to reference it.
- If embedding or chunk_size constants appear in source, update axes values to match.
- Otherwise copy verbatim — the user will edit before running.

After copying (and adapting if appropriate), commit both files together with message:
  feat(eval): scaffold eval_sweep.py and sweep_config.json

Return: list of files written and commit hash.
```

## Step 3 — Report to user

Print final report:
```
eval-sweep scaffolded
  slug:    <resolved slug>
  files:   eval_sweep.py, sweep_config.json

Next steps:
  1. Edit sweep_config.json — update axes and command to match your eval setup.
  2. Run:  uv run eval_sweep.py --config sweep_config.json --dry-run
  3. When the dry-run looks right, run without --dry-run to execute the sweep.
  4. Use --resume to continue an interrupted run.

The sweep runs entirely offline — no LLM cost, no LLM latency.
```

## Rules
- No code changes. No commits from this router — the builder commits.
- Never execute the sweep. Never run eval_sweep.py.
- Only scaffold; the user owns running and interpreting results.
