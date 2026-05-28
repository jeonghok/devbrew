#!/usr/bin/env bash
# test_pre_pipeline_check.sh — direct coverage for scripts/pre-pipeline-check.sh.
#
# Covers C2 race fix (same-session pipeline.md preservation) and supporting
# behaviors. Each case isolates state under a per-test tmpdir so the live
# repo's .claude/quality-gates/ is untouched.

set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/pre-pipeline-check.sh"

PASS=0
FAIL=0

note() { echo "  → $1"; }

pass() { PASS=$((PASS + 1)); note "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }

write_pipeline() {
  local dir="$1" sid="$2"
  cat > "$dir/pipeline.md" <<EOF
---
session_id: "$sid"
started_at: "2026-05-27T00:00:00Z"
gate3_max_resolutions: 3
---
EOF
}

write_branch_marker() {
  local dir="$1" branch="$2"
  cat > "$dir/branch.md" <<EOF
---
branch: "$branch"
updated: "2026-01-01T00:00:00Z"
---
EOF
}

# --- case_fresh_start: no prior state → result: fresh_start ---
case_fresh_start() {
  local tmp; tmp=$(mktemp -d); cd "$tmp"
  export CLAUDE_CODE_SESSION_ID="test-pre-fresh-$$"
  if bash "$SCRIPT" 2>/dev/null | grep -q 'result: fresh_start\|result: no_session_data'; then
    pass "case_fresh_start"
  else
    fail "case_fresh_start (no fresh_start/no_session_data emitted)"
  fi
  cd / && rm -rf "$tmp"
  unset CLAUDE_CODE_SESSION_ID
}

# --- case_same_session_preserved: pipeline.md owned by current session must survive ---
case_same_session_preserved() {
  local tmp; tmp=$(mktemp -d); cd "$tmp"
  export CLAUDE_CODE_SESSION_ID="test-pre-same-$$"
  local dir=".claude/quality-gates/$CLAUDE_CODE_SESSION_ID"
  mkdir -p "$dir"
  write_pipeline "$dir" "$CLAUDE_CODE_SESSION_ID"
  write_branch_marker "$dir" "stale-branch"
  bash "$SCRIPT" >/dev/null 2>&1
  if [[ -f "$dir/pipeline.md" ]]; then
    pass "case_same_session_preserved"
  else
    fail "case_same_session_preserved (pipeline.md deleted)"
  fi
  cd / && rm -rf "$tmp"
  unset CLAUDE_CODE_SESSION_ID
}

# --- case_cross_session_deleted: pipeline.md owned by DIFFERENT session is wiped ---
case_cross_session_deleted() {
  local tmp; tmp=$(mktemp -d); cd "$tmp"
  export CLAUDE_CODE_SESSION_ID="test-pre-cross-$$"
  local dir=".claude/quality-gates/$CLAUDE_CODE_SESSION_ID"
  mkdir -p "$dir"
  write_pipeline "$dir" "a-completely-different-session-id"
  write_branch_marker "$dir" "stale-branch"
  bash "$SCRIPT" >/dev/null 2>&1
  if [[ ! -f "$dir/pipeline.md" ]]; then
    pass "case_cross_session_deleted"
  else
    fail "case_cross_session_deleted (pipeline.md survived)"
  fi
  cd / && rm -rf "$tmp"
  unset CLAUDE_CODE_SESSION_ID
}

# --- case_advisory_emitted: same-session preservation emits stderr advisory ---
case_advisory_emitted() {
  local tmp; tmp=$(mktemp -d); cd "$tmp"
  export CLAUDE_CODE_SESSION_ID="test-pre-advisory-$$"
  local dir=".claude/quality-gates/$CLAUDE_CODE_SESSION_ID"
  mkdir -p "$dir"
  write_pipeline "$dir" "$CLAUDE_CODE_SESSION_ID"
  write_branch_marker "$dir" "stale-branch"
  local err
  err=$(bash "$SCRIPT" 2>&1 >/dev/null)
  if echo "$err" | grep -q 'preserving session-owned state file'; then
    pass "case_advisory_emitted"
  else
    fail "case_advisory_emitted (stderr: $err)"
  fi
  cd / && rm -rf "$tmp"
  unset CLAUDE_CODE_SESSION_ID
}

case_fresh_start
case_same_session_preserved
case_cross_session_deleted
case_advisory_emitted

echo
echo "test_pre_pipeline_check: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
