---
slug: ecc-vs-claudinho-harness
kind: feature
domain: generalist
tier: light
status: done
date: 2026-06-30
related: []
---

# Post-build verify gate for /task

## Problem
`/task` currently goes Build → Review → Finalize. Review is advisory and never blocks, so a SPEC can be marked `status: done` even if its own declared validation commands (tests, lint, etc.) fail. There's no mechanism for a SPEC to declare "run these commands after build" and have `/task` gate on the result.

## Goal
1. `templates/SPEC.md` has a `## Validation` section (between `## Design` and `## Tasks`) documenting the fenced-command convention.
2. `commands/task.md` has a new Step 3 — Verify, inserted between Build and Review, that parses `## Validation`, runs each fenced command via Bash in repo root, in declared order, and emits a `verify: {status, commands, total}` result.
3. Downstream steps renumbered: 1 Pre-fetch+route, 2 Build, 3 Verify, 4 Review, 5 Finalize.
4. Finalize only advances SPEC `status: done` when `verify.status` is `pass` or `skipped`. On `fail`, SPEC `status` stays unchanged, `overall_status: blocked` is set in STATUS.md, failure detail is appended to STATUS notes, and the failure surfaces in the final `/task` report.
5. Verify is a separate gate from Review — Review stays advisory/unchanged.
6. `templates/STATUS.md` reflects the new 5-step sequence.
7. `README.md` documents the verify gate and `## Validation` convention in one line.

## Non-goals
- No multi-IDE scaffolds.
- No language packs.
- No orchestration framework.
- No cost tracking.
- No new dependencies.
- No standalone verifier subagent unless inline Bash in task.md proves unworkable.

## Design
Mechanism: SPEC.md declares validation as a `## Validation` section containing fenced shell code blocks, one command per line, run in order. Absent or empty section → `skipped`. Implementation is inline within `commands/task.md` Step 3 (no new subagent) — keeps the pipeline simple and avoids an extra Agent round-trip for what's a deterministic Bash loop. Terminal fail state: `overall_status: blocked` in STATUS.md, SPEC frontmatter `status` left unchanged (not advanced to `done`), failure (status / failing cmd / tail) surfaced in STATUS notes and the final `/task` report block.

Files touched: `templates/SPEC.md`, `commands/task.md`, `templates/STATUS.md`, `README.md`. Conditionally `agents/claudinho-verifier.md` (default: not added).

## Tasks
- [x] T1.1 Add `## Validation` section to templates/SPEC.md after `## Design`, before `## Tasks`
- [x] T1.2 Document one-fenced-shell-command-per-line convention with concrete example (`uv run pytest -q`)
- [x] T1.3 State empty/absent section → skipped, and the parsing contract (declared order, each via Bash, repo root)
- [x] T2.1 Insert new "Step 3 — Verify" in commands/task.md between Build and Review
- [x] T2.2 Verify step parses SPEC `## Validation`, extracts fenced commands in order
- [x] T2.3 Runs each via Bash, captures exit code; on non-zero captures last ~15 lines of output (omit tail on pass)
- [x] T2.4 Emits result contract `verify: {status: pass|fail|skipped, commands: [{cmd, exit, tail}], total: N}`
- [x] T2.5 Renumber downstream steps: Build=2, Verify=3 (new), Review=4, Finalize=5; update all in-text references and headings
- [x] T2.6 Update Step 1's STATUS.md bootstrap step list to 5 steps; confirm resume-from-first-`[ ]` logic still works
- [x] T2.7 Update templates/STATUS.md example step list to 5 steps matching task.md
- [x] T2.8 Gate Finalize (Step 5): advance SPEC `status: done` only when verify.status is pass or skipped; on fail leave SPEC status unchanged, set overall_status: blocked, append failure detail to STATUS notes, surface failure in final report
- [x] T2.9 Confirm Verify is a separate gate from Review (Review stays advisory/unchanged; verify fail doesn't require reviewer to flag it)
- [x] T3.1 Add one line to README.md documenting the post-build verify gate and `## Validation` convention
- [x] T3.2 Dry-run /task logic against 3 sample SPECs (scratchpad, not committed): passing commands → pass + status:done
- [x] T3.3 Dry-run: failing command → fail + overall_status:blocked + SPEC status unchanged + failure in report/STATUS
- [x] T3.4 Dry-run: no Validation commands → skipped + status:done
- [x] T3.5 Confirm scope guardrails: files touched limited to commands/task.md, templates/SPEC.md, templates/STATUS.md, README.md (and conditionally agents/claudinho-verifier.md)
- [x] T3.6 (conditional) Add agents/claudinho-verifier.md only if inline Bash in task.md proves unworkably noisy — default is NOT to add it (skipped: inline Bash proved clean, no agent added)

## Open questions
None — all resolved:
- Mechanism for declaring validation commands: `## Validation` section in SPEC.md with fenced shell blocks.
- Where verify logic lives: inline in commands/task.md Step 3, no new subagent (inline Bash was not noisy).
- Terminal fail state semantics: `overall_status: blocked` in STATUS.md, SPEC `status` left unchanged, failure surfaced in STATUS notes + final report.
