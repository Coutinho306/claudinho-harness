#!/usr/bin/env bash
# NOTE: PreCompact hook — persists pipeline state before context
# compaction so long-running pipelines (/spike, /plan, /task) survive
# compression and can be resumed. Reads CLAUDE_PIPELINE_* env vars exported
# by the active command; no-op when none are set (compaction outside a
# pipeline run).
set -euo pipefail

git rev-parse --show-toplevel &>/dev/null || exit 0
REPO_ROOT="$(git rev-parse --show-toplevel)"
SLUG="${CLAUDE_PIPELINE_SLUG:-}"

[[ -z "$SLUG" ]] && exit 0

# Artifacts root (CLAUDE.md § Artifact Storage Convention): env override,
# default `specs`. Absolute → used verbatim; relative → joined to repo root.
ARTIFACTS_ROOT="${HARNESS_ARTIFACTS_ROOT:-specs}"
case "$ARTIFACTS_ROOT" in
  /*) ARTIFACTS_BASE="$ARTIFACTS_ROOT" ;;
  *)  ARTIFACTS_BASE="$REPO_ROOT/$ARTIFACTS_ROOT" ;;
esac

SNAPSHOT_DIR="$ARTIFACTS_BASE/features/$SLUG"
mkdir -p "$SNAPSHOT_DIR"
SNAPSHOT="$SNAPSHOT_DIR/.pipeline-state.json"

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"

# Build JSON without depending on jq presence
cat > "$SNAPSHOT" <<JSON
{
  "slug": "$SLUG",
  "command": "${CLAUDE_PIPELINE_COMMAND:-}",
  "tier": "${CLAUDE_PIPELINE_TIER:-}",
  "commit_policy": "${CLAUDE_PIPELINE_COMMIT_POLICY:-}",
  "pr_policy": "${CLAUDE_PIPELINE_PR_POLICY:-}",
  "worktree_policy": "${CLAUDE_PIPELINE_WORKTREE_POLICY:-inplace}",
  "branch": "$BRANCH",
  "agents_completed": "${CLAUDE_PIPELINE_AGENTS_DONE:-}",
  "snapshot_at": "$TS"
}
JSON

echo "[ashen-harness] pipeline state snapshot: $SNAPSHOT" >&2
