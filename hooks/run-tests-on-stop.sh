#!/usr/bin/env bash
# AIDEV-NOTE: SubagentStop hook — auto-detects stack and runs tests after
# implementation agents (ashen-ai-eng-builder, ashen-data-eng-builder,
# ashen-infra-ops-builder, ashen-generalist-builder) finish.
# Wire via hooks/hooks.json with matcher matching builder agent names.
# Opt-in via env HARNESS_AUTOTEST=1; no-op otherwise.
set -euo pipefail

[[ "${HARNESS_AUTOTEST:-0}" == "1" ]] || exit 0

# Skip if not in a git repo
git rev-parse --show-toplevel &>/dev/null || exit 0
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

run() {
  echo "[ashen-harness] running: $*" >&2
  "$@"
}

# Stack detection — first match wins. Profile override via .claude/context.json
# (key: test_command) takes precedence if present.
PROFILE_CMD=""
if [[ -f .claude/context.json ]] && command -v jq &>/dev/null; then
  PROFILE_CMD="$(jq -r '.test_command // empty' .claude/context.json 2>/dev/null || true)"
fi

if [[ -n "$PROFILE_CMD" ]]; then
  run bash -c "$PROFILE_CMD"
elif [[ -f bun.lockb || -f bun.lock ]]; then
  run bun test
elif [[ -f package.json ]]; then
  # AIDEV-NOTE: prefer jq to gate on scripts.test, but Node projects without
  # jq still get a best-effort npm test rather than a silent skip.
  if command -v jq &>/dev/null; then
    if jq -e '.scripts.test' package.json &>/dev/null; then
      run npm test --silent
    else
      echo "[ashen-harness] package.json has no scripts.test; skipping" >&2
    fi
  else
    echo "[ashen-harness] jq not found; running npm test best-effort" >&2
    run npm test --silent || echo "[ashen-harness] npm test failed or undefined" >&2
  fi
elif [[ -f pyproject.toml || -f pytest.ini || -f setup.cfg ]]; then
  run pytest -q
elif [[ -f go.mod ]]; then
  run go test ./...
elif [[ -f Cargo.toml ]]; then
  run cargo test --quiet
elif [[ -f Gemfile ]]; then
  run bundle exec rspec --format progress
else
  echo "[ashen-harness] no recognized stack; skipping autotest" >&2
fi
