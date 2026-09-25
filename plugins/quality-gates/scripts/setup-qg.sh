#!/bin/bash

# Quality Gates Pipeline Setup Script
# Creates per-session state file for in-turn pipeline orchestration
# (AskUserQuestion-iteration model; no Stop hook continuation).
# All file I/O happens here (bash), not through Claude's Write tool,
# so no permission prompts are triggered.

set -euo pipefail

# --- Defense-in-depth kill switch ---
# SKILL preflight P1 also checks this and short-circuits before calling
# setup-qg.sh. Honoring it here too means direct callers (tests, scripts)
# can't accidentally bypass the kill switch via a fresh invocation.
if [[ "${DEVBREW_QUALITY_GATES_DISABLE:-}" == "1" ]]; then
  echo "[quality-gates] setup-qg disabled via DEVBREW_QUALITY_GATES_DISABLE=1" >&2
  exit 1
fi

# --- Argument Parsing ---

REMOVED_ARGS=""
PLAN_FILE="auto"
PR_URL=""
ENSURE_MODE="false"
SESSION_ID=""
BRANCH_MODE="false"
TARGET_BRANCH=""

while [[ $# -gt 0 ]]; do
  case $1 in
    review|runtime|both|--skip-runtime)
      # 제거된 인자 — 한 파이프라인이라 고를 게이트가 없다. 조용히 무시하지 않고
      # 아래 출력에서 한 줄씩 알린 뒤 정상 진행한다(설계 §6.5.2).
      REMOVED_ARGS="$REMOVED_ARGS $1"
      shift
      ;;
    --paths)
      # 스코프 override 는 SKILL 이 $ARGUMENTS 에서 직접 읽는다 — 여기서는 소비만 한다.
      # 다음 토큰이 없거나 `--` 로 시작하거나 제거/branch 키워드면 글롭 0개 —
      # 아래 while 루프가 한 번도 안 돌 조건과 정확히 같아야 한다(그래야 0글롭이
      # 조용히 통과하지 않는다).
      shift
      if [[ $# -eq 0 ]] || [[ "$1" =~ ^-- ]] || [[ "$1" =~ ^(review|runtime|both|branch)$ ]]; then
        echo "❌ Error: --paths requires at least one glob" >&2
        exit 1
      fi
      while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]] && [[ ! "$1" =~ ^(review|runtime|both|branch)$ ]]; do
        shift
      done
      ;;
    --gc)
      # qg.md 가 GC 를 이미 돌렸다 — setup 은 무시한다.
      shift
      ;;
    branch)
      shift
      # peek next token
      if [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]] && [[ ! "$1" =~ ^(review|runtime|both)$ ]]; then
        TARGET_BRANCH="$1"
        shift
      fi
      BRANCH_MODE="true"
      ;;
    --ensure)
      ENSURE_MODE="true"
      shift
      ;;
    --plan)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --plan requires a file path argument" >&2
        exit 1
      fi
      PLAN_FILE="$2"
      shift 2
      ;;
    --pr-url)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --pr-url requires a URL argument" >&2
        exit 1
      fi
      PR_URL="$2"
      shift 2
      ;;
    --session-id)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --session-id requires an argument" >&2
        exit 1
      fi
      SESSION_ID="$2"
      shift 2
      ;;
    -h|--help)
      cat << 'HELP_EOF'
Quality Gates Pipeline Setup

USAGE:
  /qg [branch [<name>]] [OPTIONS]

ARGUMENTS:
  branch [<name>]      Review the full branch diff (with <name>: in an isolated worktree)
  (none)               Review git-derived changes (branch + worktree)

OPTIONS:
  --paths <glob>...    Scope override — review only the matched paths
  --plan <path>        Specify plan file path (default: auto-detect)
  --pr-url <url>       Specify PR URL
  --session-id <id>    Override session ID (defaults to CLAUDE_CODE_SESSION_ID)
  --ensure             Idempotent mode: no-op if state from this session
                       already exists (used by skill preflight, not /qg).
  -h, --help           Show this help message

REMOVED (v9): review · runtime · both · --skip-runtime — one pipeline, no gate
  scope to choose. Passing one prints a one-line notice and the run proceeds.

PIPELINE:
  scope → differential test → reviewers → re-critique → verdict
  (clean · defect · not-certified (<reason>))

STOPPING:
  Use /cancel-qg to cancel an active pipeline
HELP_EOF
      exit 0
      ;;
    *)
      echo "❌ Error: Unknown argument: $1" >&2
      echo "   Use --help for usage information" >&2
      exit 1
      ;;
  esac
done

# --- Resolve session ID ---
# --session-id arg takes precedence, then env var.
if [[ -z "$SESSION_ID" ]]; then
  SESSION_ID="${CLAUDE_CODE_SESSION_ID:-}"
fi
if [[ -z "$SESSION_ID" ]]; then
  cat >&2 <<EOF
❌ Quality Gates: cannot create pipeline state — session ID is empty.
   Neither --session-id <id> argument nor CLAUDE_CODE_SESSION_ID env var was provided.
   This usually means /qg was invoked outside of Claude Code or in a sub-shell
   that did not inherit the env. Re-run /qg from Claude Code, or pass
   --session-id explicitly.
EOF
  exit 1
fi

# Validate pattern (defense in depth; matches qg-gc.py SESSION_PATTERN).
if [[ ! "$SESSION_ID" =~ ^[A-Za-z0-9_-]{8,}$ ]]; then
  echo "❌ Quality Gates: session ID '$SESSION_ID' fails pattern guard ([A-Za-z0-9_-]{8,})." >&2
  exit 1
fi

# --- Branch worktree mode ---
WORKTREE_PATH=""
if [[ "$BRANCH_MODE" == "true" ]] && [[ -n "$TARGET_BRANCH" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  _wt_stderr_tmp=$(mktemp)
  if ! WORKTREE_PATH="$("$SCRIPT_DIR/qg-worktree.sh" create "$TARGET_BRANCH" "$SESSION_ID" 2>"$_wt_stderr_tmp")"; then
    echo "❌ Quality Gates: worktree creation failed" >&2
    cat "$_wt_stderr_tmp" >&2
    rm -f "$_wt_stderr_tmp"
    exit 1
  fi
  # Forward any advisory stderr (e.g. "reusing existing worktree") to our own stderr.
  [[ -s "$_wt_stderr_tmp" ]] && cat "$_wt_stderr_tmp" >&2
  rm -f "$_wt_stderr_tmp"
  # stdout is the absolute worktree path (single line).
  WORKTREE_PATH="$(printf '%s\n' "$WORKTREE_PATH" | tail -n1)"
fi

# --- Per-session paths ---
STATE_DIR=".claude/quality-gates/$SESSION_ID"
STATE_FILE="$STATE_DIR/pipeline.md"

# --- Active pipeline check (self-session only) ---
if [[ -f "$STATE_FILE" ]]; then
  if [[ "$ENSURE_MODE" == "true" ]]; then
    exit 0
  fi
  echo "❌ Error: A quality gates pipeline is already active in this session" >&2
  echo "   State file: $STATE_FILE" >&2
  echo "" >&2
  echo "   To cancel: /cancel-qg" >&2
  exit 1
fi

# --- Legacy v1.5.0 cleanup (one-time, advisory) ---
LEGACY_FILES=(
  ".claude/quality-gates.local.md"
  ".claude/quality-gates-session.local.md"
  ".claude/quality-gates-branch.local.md"
  ".claude/qg-diff-cache.txt"
  ".claude/qg-code-paths.tmp"
)
LEGACY_REMOVED=0
for f in "${LEGACY_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    rm -f "$f"
    LEGACY_REMOVED=$((LEGACY_REMOVED + 1))
  fi
done
if [[ "$LEGACY_REMOVED" -gt 0 ]]; then
  cat >&2 <<EOF
[quality-gates] Removed $LEGACY_REMOVED legacy flat state file(s) from v1.5.0.
v1.6.0 uses per-session storage at .claude/quality-gates/<session>/.
EOF
fi

# --- TTL GC (best-effort; never aborts setup) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/qg-gc.py" --session-id "$SESSION_ID" || true

mkdir -p "$STATE_DIR"

# --- Dependency Check ---

AVAILABLE_PLUGINS=""

# Helper: check if a plugin is installed
# Searches: installed_plugins.json, plugin cache dirs, and project marketplace.json
plugin_installed() {
  local name="$1"
  # Check installed_plugins.json (primary source of truth)
  if [ -f ~/.claude/plugins/installed_plugins.json ] && \
     grep -q "\"$name@" ~/.claude/plugins/installed_plugins.json 2>/dev/null; then
    return 0
  fi
  # Check plugin cache directories (fallback)
  if ls ~/.claude/plugins/cache/*/  2>/dev/null | grep -q "$name"; then
    return 0
  fi
  # Check project marketplace.json
  if [ -f ".claude-plugin/marketplace.json" ] && \
     grep -q "\"$name\"" ".claude-plugin/marketplace.json" 2>/dev/null; then
    return 0
  fi
  return 1
}

# Check pr-review-toolkit (required for the Review gate)
PR_REVIEW_FOUND=false
if plugin_installed "pr-review-toolkit"; then
  PR_REVIEW_FOUND=true
  AVAILABLE_PLUGINS="pr-review-toolkit"
fi

if [[ "$PR_REVIEW_FOUND" == "false" ]]; then
  echo "⚠️  Warning: pr-review-toolkit plugin not found" >&2
  echo "   The Review gate (PR Review) requires this plugin for code review agents" >&2
  echo "   Pipeline will continue but the Review gate may have limited functionality" >&2
  echo "" >&2
fi

# Check feature-dev (optional)
if plugin_installed "feature-dev"; then
  if [[ -n "$AVAILABLE_PLUGINS" ]]; then
    AVAILABLE_PLUGINS="$AVAILABLE_PLUGINS,feature-dev"
  else
    AVAILABLE_PLUGINS="feature-dev"
  fi
fi

# Check superpowers (optional)
if plugin_installed "superpowers"; then
  if [[ -n "$AVAILABLE_PLUGINS" ]]; then
    AVAILABLE_PLUGINS="$AVAILABLE_PLUGINS,superpowers"
  else
    AVAILABLE_PLUGINS="superpowers"
  fi
fi

# --- Create State File ---

TEMP_FILE="${STATE_FILE}.tmp.$$"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

cat > "$TEMP_FILE" << EOF
---
session_id: "$SESSION_ID"
started_at: "$TIMESTAMP"
EOF

# worktree_path is optional — only set when /qg branch <name> created one.
if [[ -n "$WORKTREE_PATH" ]]; then
  cat >> "$TEMP_FILE" << EOF
worktree_path: "$WORKTREE_PATH"
target_branch: "$TARGET_BRANCH"
EOF
fi

cat >> "$TEMP_FILE" << EOF
---

# Quality Gates Pipeline State (v1.32.1)

## History
- [$TIMESTAMP] Pipeline started
EOF

mv "$TEMP_FILE" "$STATE_FILE"

# --- Output Setup Message ---

echo "🔄 Quality Gates Pipeline"
echo ""
echo "Pipeline: scope → differential test → reviewers → re-critique → verdict"
for a in $REMOVED_ARGS; do
  echo "> [quality-gates] \`${a}\` 인자는 제거됐다 — 이제 한 파이프라인이라 게이트 범위를 고르지 않는다. 그대로 진행한다."
done

echo ""
echo "Available plugins: ${AVAILABLE_PLUGINS:-none}"
if [[ -n "$PR_URL" ]]; then
  echo "PR URL: $PR_URL"
fi
if [[ "$PLAN_FILE" != "auto" ]]; then
  echo "Plan file: $PLAN_FILE"
fi
echo ""
echo "Pipeline runs in this turn. To cancel before run: /cancel-qg"
