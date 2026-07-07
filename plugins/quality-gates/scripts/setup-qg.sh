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
if [[ "${DEVBREW_DISABLE_QUALITY_GATES:-}" == "1" ]]; then
  # Structural backstop (v2.10.0): even when globally disabled, clear any stale
  # publish-eligible sentinel for this session BEFORE exiting. The global-kill
  # exit is upstream of the arg-parsed cleanup in the "Stale publish-eligible
  # sentinel cleanup" block below, so without this a prior same-session run's
  # sentinel would survive a globally-disabled invocation — leaving the qg.md
  # offer's global-kill guard as the ONLY thing stopping a spurious publish
  # offer. Clearing it here makes the offer's inability to fire structural (no
  # sentinel to read); qg.md step-1 stays as belt-and-suspenders. Keyed off
  # CLAUDE_CODE_SESSION_ID (the same var the SKILL writes and the qg.md offer
  # read); empty + pattern guard mirror the session-id pattern validation below
  # so the rm path is traversal-safe. (The offer-read itself does not re-validate
  # the pattern — it relies on this write-side guard, since a sentinel can only
  # be created under an already-validated session.) --session-id args are
  # unparsed this early, so only the env-var session (the real, sole offer
  # coupling) is cleaned.
  _kill_sid="${CLAUDE_CODE_SESSION_ID:-}"
  if [[ -n "$_kill_sid" && "$_kill_sid" =~ ^[A-Za-z0-9_-]{8,}$ ]]; then
    # Loud-log a cleanup failure (e.g. non-writable session dir) rather than let
    # set -e abort here and MASK the kill-switch advisory + exit below — the `||`
    # list also exempts rm from set -e so the exit path stays reachable
    # (CLAUDE.md: loud logging을 동반한 graceful degradation).
    rm -f ".claude/quality-gates/$_kill_sid/publish-eligible.md" \
      || echo "[quality-gates] WARN: could not clear stale publish-eligible sentinel at .claude/quality-gates/$_kill_sid/ — publish offer falls back to the qg.md kill-switch guard." >&2
  fi
  echo "[quality-gates] setup-qg disabled via DEVBREW_DISABLE_QUALITY_GATES=1" >&2
  exit 1
fi

# --- Argument Parsing ---

SINGLE_GATE=""
SKIP_RUNTIME="false"
GATE_BOTH="false"
PLAN_FILE="auto"
PR_URL=""
ENSURE_MODE="false"
SESSION_ID=""
BRANCH_MODE="false"
TARGET_BRANCH=""

while [[ $# -gt 0 ]]; do
  case $1 in
    review|runtime)
      SINGLE_GATE="$1"
      shift
      ;;
    both)
      # full pipeline, both gates, no gate-scope question (NOT single-gate)
      GATE_BOTH="true"
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
  /qg [review|runtime|both] [OPTIONS]

ARGUMENTS:
  review         Run the Review gate only
  runtime        Run the Runtime gate only
  both           Run both gates with no gate-scope question
  (none)         Run full pipeline; ask gate scope (Review only / both) first

OPTIONS:
  --skip-runtime       Skip the Runtime gate (runtime verification)
  --plan <path>        Specify plan file path (default: auto-detect)
  --pr-url <url>       Specify PR URL
  --session-id <id>    Override session ID (defaults to CLAUDE_CODE_SESSION_ID)
  --ensure             Idempotent mode: no-op if state from this session
                       already exists (used by skill preflight, not /qg).
  -h, --help           Show this help message

PIPELINE:
  Review gate — iterative code review (review → fix → re-review)
  Runtime gate — launches app and verifies behavior

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

# --- Stale publish-eligible sentinel cleanup (v2.10.0) ---
# The Task-2 pipeline SKILL writes .claude/quality-gates/<sid>/publish-eligible.md
# only on non-aborted completion; the qg.md command offers publish iff that file
# is present. State files persist across runs in a session, so setup-qg.sh (called
# at SKILL Preflight P2) must clear a prior run's sentinel on EVERY invocation —
# BEFORE the --ensure early-exit in the "Active pipeline check" below, else a
# second /qg in the same session inherits a stale offer (false-offer). (The
# global-kill branch near the top has its own copy of this cleanup, since it
# exits upstream of here.) SKILL.md itself cannot rm (Write-only
# allowed-tools), so this deletion lives here (its Preflight mechanism).
rm -f ".claude/quality-gates/$SESSION_ID/publish-eligible.md"

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
python3 "$SCRIPT_DIR/qg-gc.py" --session-id "$SESSION_ID" 2>/dev/null || true

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

# --- Validate DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS (P18 unbounded-autonomy guard) ---
# Default 3. Clamped to 0..10. Non-numeric → warning + default.

runtime_max="${DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS:-3}"
if ! [[ "$runtime_max" =~ ^[0-9]+$ ]]; then
  echo "setup-qg: DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS='$runtime_max' is not numeric; defaulting to 3" >&2
  runtime_max=3
elif (( runtime_max > 10 )); then
  echo "setup-qg: DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS='$runtime_max' exceeds maximum 10; clamping to 10" >&2
  runtime_max=10
fi

# --- Create State File ---

TEMP_FILE="${STATE_FILE}.tmp.$$"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

cat > "$TEMP_FILE" << EOF
---
session_id: "$SESSION_ID"
started_at: "$TIMESTAMP"
runtime_max_resolutions: $runtime_max
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

if [[ -n "$SINGLE_GATE" ]]; then
  case "$SINGLE_GATE" in
    review)  GATE_LABEL="Review gate" ;;
    runtime) GATE_LABEL="Runtime gate" ;;
  esac
  echo "🔄 Quality Gates Pipeline — Single Gate Mode"
  echo ""
  echo "Gate: ${GATE_LABEL}"
  if [[ "$SINGLE_GATE" == "runtime" && "$SKIP_RUNTIME" == "true" ]]; then
    # precedence: explicit gate=runtime wins over --skip-runtime (matches SKILL effective_skip_runtime)
    echo "      --skip-runtime ignored: gate=runtime wins (precedence)"
  fi
else
  echo "🔄 Quality Gates Pipeline — Full Pipeline"
  echo ""
  echo "Gates: Review gate → Runtime gate"
  if [[ "$GATE_BOTH" == "true" ]]; then
    echo "       (both gates — no gate-scope question)"
  fi
  if [[ "$SKIP_RUNTIME" == "true" ]]; then
    if [[ "$GATE_BOTH" == "true" ]]; then
      # precedence: explicit gate=both wins over --skip-runtime; Runtime gate WILL run
      echo "       --skip-runtime ignored: gate=both wins (precedence); Runtime gate runs"
    else
      echo "       Runtime gate skipped (--skip-runtime)"
    fi
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
echo "Pipeline runs in this turn. To cancel before run: /cancel-qg"
