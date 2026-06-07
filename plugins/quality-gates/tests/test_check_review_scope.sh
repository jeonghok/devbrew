#!/usr/bin/env bash
# test_check_review_scope.sh — coverage for scripts/check-review-scope.sh
# (design v2.6.0 §5.1, AC1–AC5). Each case isolates a throwaway git repo under
# mktemp so the live repo's working tree is untouched.

set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/check-review-scope.sh"

PASS=0; FAIL=0
REPO=""
pass() { PASS=$((PASS + 1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }

# field <key> <output-text> → prints the value after "<key>: "
field() { printf '%s\n' "$2" | awk -v k="$1:" '$1 == k { print $2 }'; }

# Build a repo with a 'main' base branch + a 'feature' branch 1 commit ahead.
# Sets global REPO and leaves CWD inside it (on feature, clean tree).
mk_repo_feature_ahead() {
  REPO=$(mktemp -d); cd "$REPO"
  git init -q
  git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo base > a.txt; git add a.txt; git commit -qm base
  git checkout -q -b feature
  echo work >> a.txt; git commit -qam work
}

# AC1 (session): empty session scope + branch ahead → empty_scope_with_changes
case_session_empty_branch_ahead() {
  mk_repo_feature_ahead
  export CLAUDE_CODE_SESSION_ID="test-scope-empty-$$"
  local out; out=$(bash "$SCRIPT" session)
  if [[ "$(field signal "$out")" == "empty_scope_with_changes" \
     && "$(field branch_ahead_count "$out")" == "1" \
     && "$(field base "$out")" == "main" ]]; then
    pass "session empty + branch ahead → empty_scope_with_changes (base=main, ahead=1)"
  else
    fail "session empty + branch ahead (got: $out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

# AC3 (session): files.md has >=1 entry → normal
case_session_files_present() {
  mk_repo_feature_ahead
  export CLAUDE_CODE_SESSION_ID="test-scope-files-$$"
  mkdir -p ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID"
  printf '# Quality-Gates Session Files\n\n- a.txt\n' \
    > ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID/files.md"
  local out; out=$(bash "$SCRIPT" session)
  if [[ "$(field signal "$out")" == "normal" \
     && "$(field resolved_count "$out")" == "1" ]]; then
    pass "session files.md present → normal (resolved_count=1)"
  else
    fail "session files.md present (got: $out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

# AC2: empty session + no changes (on base, clean) → genuine_noop
case_genuine_noop() {
  mk_repo_feature_ahead
  git checkout -q main
  export CLAUDE_CODE_SESSION_ID="test-scope-noop-$$"
  local out; out=$(bash "$SCRIPT" session)
  if [[ "$(field signal "$out")" == "genuine_noop" ]]; then
    pass "empty session + no changes → genuine_noop"
  else
    fail "genuine_noop (got: $out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

# AC3 (paths): glob matches a changed file → normal
case_paths_changed() {
  mk_repo_feature_ahead
  echo dirty >> a.txt
  export CLAUDE_CODE_SESSION_ID="test-scope-paths-$$"
  local out; out=$(bash "$SCRIPT" paths 'a.txt')
  if [[ "$(field signal "$out")" == "normal" \
     && "$(field resolved_count "$out")" == "1" ]]; then
    pass "paths glob matches changed file → normal"
  else
    fail "paths changed (got: $out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

# AC1 (paths): glob matches nothing in the diff but changes exist elsewhere
#              → empty_scope_with_changes
case_paths_no_match() {
  mk_repo_feature_ahead
  echo dirty >> a.txt
  export CLAUDE_CODE_SESSION_ID="test-scope-paths2-$$"
  local out; out=$(bash "$SCRIPT" paths 'b.txt')
  if [[ "$(field signal "$out")" == "empty_scope_with_changes" ]]; then
    pass "paths glob no match but changes exist → empty_scope_with_changes"
  else
    fail "paths no match (got: $out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

# AC4: detached HEAD → degraded + exit 0 (fail-open)
case_degraded_detached() {
  mk_repo_feature_ahead
  git checkout -q --detach
  export CLAUDE_CODE_SESSION_ID="test-scope-detach-$$"
  local out rc; out=$(bash "$SCRIPT" session); rc=$?
  if [[ "$(field signal "$out")" == "degraded" && "$rc" -eq 0 ]]; then
    pass "detached HEAD → degraded + exit 0 (fail-open)"
  else
    fail "degraded detached (rc=$rc got: $out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

# AC4: no main/master base branch + no remote → degraded + exit 0
case_degraded_no_base() {
  REPO=$(mktemp -d); cd "$REPO"
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b weirdname
  echo x > a.txt; git add a.txt; git commit -qm x
  export CLAUDE_CODE_SESSION_ID="test-scope-nobase-$$"
  local out rc; out=$(bash "$SCRIPT" session); rc=$?
  if [[ "$(field signal "$out")" == "degraded" && "$rc" -eq 0 ]]; then
    pass "no main/master base → degraded + exit 0"
  else
    fail "degraded no-base (rc=$rc got: $out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

# base resolution via refs/remotes/origin/HEAD symbolic-ref → base=main
case_base_origin_head() {
  local remote; remote=$(mktemp -d); git init -q --bare "$remote"
  mk_repo_feature_ahead
  git remote add origin "$remote"
  git push -q origin main
  git push -q origin feature
  git remote set-head origin main
  export CLAUDE_CODE_SESSION_ID="test-scope-originhead-$$"
  local out; out=$(bash "$SCRIPT" session)
  if [[ "$(field base "$out")" == "main" \
     && "$(field signal "$out")" == "empty_scope_with_changes" ]]; then
    pass "base via origin/HEAD symbolic-ref → base=main"
  else
    fail "base origin/HEAD (got: $out)"
  fi
  cd / && rm -rf "$REPO" "$remote"; unset CLAUDE_CODE_SESSION_ID
}

# AC5: read-only — working tree + git status unchanged before/after
case_read_only() {
  mk_repo_feature_ahead
  export CLAUDE_CODE_SESSION_ID="test-scope-ro-$$"
  local before after
  before=$(git status --porcelain=v1; find . -type f | sort)
  bash "$SCRIPT" session >/dev/null 2>&1
  after=$(git status --porcelain=v1; find . -type f | sort)
  if [[ "$before" == "$after" ]]; then
    pass "read-only: working tree + git status unchanged"
  else
    fail "read-only violated (before != after)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

case_session_empty_branch_ahead
case_session_files_present
case_genuine_noop
case_paths_changed
case_paths_no_match
case_degraded_detached
case_degraded_no_base
case_base_origin_head
case_read_only

echo
echo "test_check_review_scope: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
