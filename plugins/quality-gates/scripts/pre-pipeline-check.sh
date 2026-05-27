#!/usr/bin/env bash
# Pre-pipeline check (qg-cost-reduction plan §F-1).
# - Detects branch mismatch / staleness in session-scope state.
# - Mutates: may delete stale state files. NOT a hook (called from SKILL.md).
# - Stdout: structured `key: value` lines consumed by SKILL.md.
#
# Result keys emitted on stdout (always one of):
#   cleared_branch_mismatch - HEAD branch changed since last run; both state files deleted
#   cleared_stale      - session file older than $STALE_HOURS; deleted
#   fresh_start        - no prior branch marker; first run on this branch
#   preserved          - session file exists and is fresh; reuse
#   no_session_data    - no session file present (and no active state)
#
# Always also emits `branch: <current-branch>` and, on cleared_branch_mismatch,
# `previous_branch: <old-branch>`.

set -euo pipefail

SESSION_ID="${CLAUDE_CODE_SESSION_ID:-}"
if [[ -z "$SESSION_ID" ]]; then
  echo "result: no_session_id"
  exit 0
fi
STATE_DIR=".claude/quality-gates/$SESSION_ID"
STATE_FILE="$STATE_DIR/pipeline.md"
SESSION_FILE="$STATE_DIR/files.md"
BRANCH_FILE="$STATE_DIR/branch.md"
STALE_HOURS="${QG_STALE_HOURS:-24}"

current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"

last_branch=""
if [[ -f "$BRANCH_FILE" ]]; then
  last_branch="$(awk -F'"' '/^branch:/ {print $2; exit}' "$BRANCH_FILE" 2>/dev/null || echo "")"
fi

# 2. Branch mismatch? Wipe stale state, but NEVER delete a pipeline.md
# owned by the live (same-session) pipeline (C2 race fix). setup-qg.sh
# may have just created STATE_FILE; this script must not race-delete it.
if [[ -n "$last_branch" && "$last_branch" != "$current_branch" ]]; then
  pipeline_session=""
  if [[ -f "$STATE_FILE" ]]; then
    pipeline_session=$(awk -F'"' '/^session_id:/ { print $2; exit }' "$STATE_FILE" 2>/dev/null | tr -d '[:space:]')
  fi
  if [[ -n "$pipeline_session" && "$pipeline_session" == "$SESSION_ID" ]]; then
    echo "pre-pipeline-check: preserving session-owned state file ($STATE_FILE)" >&2
    rm -f "$SESSION_FILE"
  else
    rm -f "$SESSION_FILE" "$STATE_FILE"
  fi
  echo "result: cleared_branch_mismatch"
  echo "previous_branch: $last_branch"
  echo "branch: $current_branch"
elif [[ -z "$last_branch" ]]; then
  echo "result: fresh_start"
  echo "branch: $current_branch"
elif [[ -f "$SESSION_FILE" ]]; then
  # 3. Staleness check (mtime of session file).
  if find "$SESSION_FILE" -mmin "+$((STALE_HOURS * 60))" 2>/dev/null | grep -q .; then
    rm -f "$SESSION_FILE"
    echo "result: cleared_stale"
    echo "branch: $current_branch"
  else
    echo "result: preserved"
    echo "branch: $current_branch"
  fi
else
  echo "result: no_session_data"
  echo "branch: $current_branch"
fi

# 4. Update branch marker (atomic) — for every path that did NOT early-exit.
mkdir -p "$STATE_DIR"
tmp_branch="${BRANCH_FILE}.tmp.$$"
{
  printf '%s\n' '---'
  printf 'branch: "%s"\n' "$current_branch"
  printf 'updated: "%s"\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s\n' '---'
  printf '%s\n' '# Quality-Gates Branch Marker'
} > "$tmp_branch"
mv "$tmp_branch" "$BRANCH_FILE"
