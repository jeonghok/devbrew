#!/bin/bash

# Quality Gates Pipeline Setup Script
# Creates state file for Stop hook-based pipeline progression.
# All file I/O happens here (bash), not through Claude's Write tool,
# so no permission prompts are triggered.

set -euo pipefail

# --- Argument Parsing ---

SINGLE_GATE=""
SKIP_RUNTIME="false"
PLAN_FILE="auto"
PR_URL=""
ENSURE_MODE="false"
SESSION_ID=""

while [[ $# -gt 0 ]]; do
  case $1 in
    gate1|gate2|gate3)
      SINGLE_GATE="$1"
      shift
      ;;
    --skip-runtime)
      SKIP_RUNTIME="true"
      shift
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
  /qg [gate1|gate2|gate3] [OPTIONS]

ARGUMENTS:
  gate1          Run Plan Verification only
  gate2          Run PR Review only
  gate3          Run Runtime Verification only
  (none)         Run full pipeline (Gate 1 → 2 → 3)

OPTIONS:
  --skip-runtime       Skip Gate 3 (runtime verification)
  --plan <path>        Specify plan file path (default: auto-detect)
  --pr-url <url>       Specify PR URL
  --session-id <id>    Override session ID (defaults to CLAUDE_CODE_SESSION_ID)
  --ensure             Idempotent mode: no-op if state from this session
                       already exists (used by skill preflight, not /qg).
  -h, --help           Show this help message

PIPELINE:
  Gate 1: Plan Verification — checks all planned items are implemented
  Gate 2: PR Review — iterative code review (review → fix → re-review)
  Gate 3: Runtime Verification — launches app and verifies behavior

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
python3 "$SCRIPT_DIR/qg-gc.py" --session-id "$SESSION_ID" 2>/dev/null || true

# DEVBREW_GATE3_MAX_RESOLUTIONS env override (default 3, integer 0..10 clamp)
RAW_MAX="${DEVBREW_GATE3_MAX_RESOLUTIONS:-3}"
if [[ ! "$RAW_MAX" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Quality Gates: DEVBREW_GATE3_MAX_RESOLUTIONS='$RAW_MAX' is not numeric; using default 3" >&2
  MAX_GATE3_RESOLUTIONS=3
elif [[ "$RAW_MAX" -gt 10 ]]; then
  MAX_GATE3_RESOLUTIONS=10
else
  MAX_GATE3_RESOLUTIONS="$RAW_MAX"
fi

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

# Check pr-review-toolkit (required for Gate 2)
PR_REVIEW_FOUND=false
if plugin_installed "pr-review-toolkit"; then
  PR_REVIEW_FOUND=true
  AVAILABLE_PLUGINS="pr-review-toolkit"
fi

if [[ "$PR_REVIEW_FOUND" == "false" ]]; then
  echo "⚠️  Warning: pr-review-toolkit plugin not found" >&2
  echo "   Gate 2 (PR Review) requires this plugin for code review agents" >&2
  echo "   Pipeline will continue but Gate 2 may have limited functionality" >&2
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

# --- Determine Initial State ---

CURRENT_GATE=1
STATUS="gate1_running"

if [[ -n "$SINGLE_GATE" ]]; then
  case $SINGLE_GATE in
    gate1) CURRENT_GATE=1; STATUS="gate1_running" ;;
    gate2) CURRENT_GATE=2; STATUS="gate2_running" ;;
    gate3) CURRENT_GATE=3; STATUS="gate3_running" ;;
  esac
fi

# --- Create State File ---

TEMP_FILE="${STATE_FILE}.tmp.$$"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

cat > "$TEMP_FILE" << EOF
---
status: $STATUS
current_gate: $CURRENT_GATE
gate2_iteration: 0
max_gate2_iterations: 5
gate3_resolution_iter: 0
max_gate3_resolutions: $MAX_GATE3_RESOLUTIONS
skip_runtime: $SKIP_RUNTIME
single_gate: ${SINGLE_GATE:-null}
plan_file: "$PLAN_FILE"
pr_url: "$PR_URL"
available_plugins: "$AVAILABLE_PLUGINS"
session_id: "$SESSION_ID"
started_at: "$TIMESTAMP"
---

# Quality Gates Pipeline State

## Gate Results

## Pipeline History
- [$TIMESTAMP] Pipeline started (iteration 1)
EOF

mv "$TEMP_FILE" "$STATE_FILE"

# --- Output Setup Message ---

GATE_NAMES=("" "Plan Verification" "PR Review" "Runtime Verification")

if [[ -n "$SINGLE_GATE" ]]; then
  GATE_NUM=${SINGLE_GATE//gate/}
  echo "🔄 Quality Gates Pipeline — Single Gate Mode"
  echo ""
  echo "Gate: ${GATE_NUM} (${GATE_NAMES[$GATE_NUM]})"
else
  echo "🔄 Quality Gates Pipeline — Full Pipeline"
  echo ""
  echo "Gates: 1 (Plan Verification) → 2 (PR Review) → 3 (Runtime Verification)"
  if [[ "$SKIP_RUNTIME" == "true" ]]; then
    echo "       Gate 3 skipped (--skip-runtime)"
  fi
fi

echo ""
echo "Available plugins: ${AVAILABLE_PLUGINS:-none}"
if [[ -n "$PR_URL" ]]; then
  echo "PR URL: $PR_URL"
fi
if [[ "$PLAN_FILE" != "auto" ]]; then
  echo "Plan file: $PLAN_FILE"
fi
echo ""
echo "Stop hook is active. Pipeline progression is automatic."
echo "To cancel: /cancel-qg"
