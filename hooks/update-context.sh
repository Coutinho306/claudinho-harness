#!/usr/bin/env bash
# NOTE: SessionStart hook — self-learning .claude/context.json updater.
# Detects active feature from current branch and infers test command from
# project layout, then writes them to context.json non-destructively.
# Idempotent: developer-set fields are never overwritten; only missing fields
# are filled. Re-runs each session so renamed branches stay in sync.
#
# WHY: jq is preferred but optional. Python3 fallback covers
# environments where jq may be absent. Both branches preserve existing keys
# via in-place merge.
set -euo pipefail

git rev-parse --show-toplevel &>/dev/null || exit 0
REPO_ROOT="$(git rev-parse --show-toplevel)"
CTX_DIR="$REPO_ROOT/.claude"
CTX="$CTX_DIR/context.json"

mkdir -p "$CTX_DIR"
[ -f "$CTX" ] || printf '%s\n' '{"plugin":"ashen-harness"}' > "$CTX"

# Detect test_command from project layout. First match wins.
detect_test_cmd() {
    if [ -f "$REPO_ROOT/package.json" ] && grep -q '"test"[[:space:]]*:' "$REPO_ROOT/package.json"; then
        if [ -f "$REPO_ROOT/pnpm-lock.yaml" ]; then echo "pnpm test"; return
        elif [ -f "$REPO_ROOT/yarn.lock" ]; then echo "yarn test"; return
        elif [ -f "$REPO_ROOT/bun.lockb" ] || [ -f "$REPO_ROOT/bun.lock" ]; then echo "bun test"; return
        else echo "npm test"; return
        fi
    fi
    [ -f "$REPO_ROOT/pyproject.toml" ] || [ -f "$REPO_ROOT/setup.py" ] || [ -f "$REPO_ROOT/pytest.ini" ] && { echo "pytest"; return; }
    [ -f "$REPO_ROOT/Cargo.toml" ] && { echo "cargo test"; return; }
    [ -f "$REPO_ROOT/go.mod" ] && { echo "go test ./..."; return; }
    [ -f "$REPO_ROOT/build.gradle" ] || [ -f "$REPO_ROOT/build.gradle.kts" ] && { echo "./gradlew test"; return; }
    [ -f "$REPO_ROOT/pom.xml" ] && { echo "mvn test"; return; }
    [ -f "$REPO_ROOT/mix.exs" ] && { echo "mix test"; return; }
    echo ""
}

# Detect active_feature from branch name. Recognized prefixes: feat, fix,
# refactor, hotfix, chore, design, specs.
detect_active_feature() {
    local branch
    branch="$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
    case "$branch" in
        feat/*|fix/*|refactor/*|hotfix/*|chore/*|design/*) echo "${branch#*/}" ;;
        specs/*) echo "${branch#*/}" ;;
        *) echo "" ;;
    esac
}

TEST_CMD="$(detect_test_cmd)"
ACTIVE_FEATURE="$(detect_active_feature)"
BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if command -v jq &>/dev/null; then
    TMP="$(mktemp)"
    jq \
        --arg tc "$TEST_CMD" \
        --arg af "$ACTIVE_FEATURE" \
        --arg br "$BRANCH" \
        --arg ts "$TS" \
        '.plugin = "ashen-harness"
         | (if $tc != "" and (.test_command // "") == "" then .test_command = $tc else . end)
         | (if $af != "" then .active_feature = $af else . end)
         | (if $br != "" then .current_branch = $br else . end)
         | .last_updated = $ts' \
        "$CTX" > "$TMP" && mv "$TMP" "$CTX"
elif command -v python3 &>/dev/null; then
    python3 - "$CTX" "$TEST_CMD" "$ACTIVE_FEATURE" "$BRANCH" "$TS" <<'PY'
import json, sys, pathlib
path = pathlib.Path(sys.argv[1])
test_cmd, active_feature, branch, ts = sys.argv[2:6]
try:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        data = {}
except (json.JSONDecodeError, OSError):
    data = {}
data["plugin"] = "ashen-harness"
if test_cmd and not data.get("test_command"):
    data["test_command"] = test_cmd
if active_feature:
    data["active_feature"] = active_feature
if branch:
    data["current_branch"] = branch
data["last_updated"] = ts
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
else
    echo "[ashen-harness] update-context skipped: neither jq nor python3 available" >&2
    exit 0
fi

echo "[ashen-harness] context.json updated (active_feature=${ACTIVE_FEATURE:-none}, test_command=${TEST_CMD:-none}, branch=${BRANCH:-none})" >&2
