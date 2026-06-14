#!/usr/bin/env bash
# test_check_review_scope.sh — coverage for scripts/check-review-scope.sh
# (design v2.7.0 §5.2, AC1–AC4). Each case isolates a throwaway git repo under
# mktemp so the live repo's working tree is untouched (fail-closed).

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
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1   # fail-closed: never run git in caller's repo
  git init -q
  git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo base > a.txt; git add a.txt; git commit -qm base
  git checkout -q -b feature
  echo work >> a.txt; git commit -qam work
}

# AC1: branch ahead → changes_exist yes, branch_ahead_count=1, base=main, degraded=no
case_changes_exist_branch_ahead() {
  mk_repo_feature_ahead
  local out; out=$(bash "$SCRIPT")
  if [[ "$(field changes_exist "$out")" == "yes" \
     && "$(field branch_ahead_count "$out")" == "1" \
     && "$(field base "$out")" == "main" \
     && "$(field degraded "$out")" == "no" ]]; then
    pass "branch ahead → changes_exist=yes (ahead=1, base=main, degraded=no)"
  else
    fail "branch ahead (got: $out)"
  fi
  cd / && rm -rf "$REPO"
}

# AC1: on base, clean tree → changes_exist no (genuine no-op)
case_changes_exist_none() {
  mk_repo_feature_ahead
  git checkout -q main
  local out; out=$(bash "$SCRIPT")
  if [[ "$(field changes_exist "$out")" == "no" \
     && "$(field branch_ahead_count "$out")" == "0" \
     && "$(field worktree_dirty "$out")" == "no" \
     && "$(field degraded "$out")" == "no" ]]; then
    pass "on base, clean tree → changes_exist=no (genuine no-op)"
  else
    fail "no changes (got: $out)"
  fi
  cd / && rm -rf "$REPO"
}

# AC3 (NG4): a .gitignore'd build artifact must NOT trip changes_exist.
case_ng4_ignored_not_counted() {
  mk_repo_feature_ahead
  git checkout -q main
  echo 'build/' > .gitignore; git add .gitignore; git commit -qm gitignore
  mkdir -p build; echo obj > build/x.o   # ignored, untracked
  local out; out=$(bash "$SCRIPT")
  if [[ "$(field changes_exist "$out")" == "no" \
     && "$(field worktree_dirty "$out")" == "no" \
     && "$(field branch_ahead_count "$out")" == "0" ]]; then
    pass "gitignored artifact → changes_exist=no (NG4 --exclude-standard)"
  else
    fail "ng4 ignored (got: $out)"
  fi
  cd / && rm -rf "$REPO"
}

# AC3 (NG4): a non-ignored untracked file → worktree_dirty + changes_exist yes.
case_ng4_untracked_counted() {
  mk_repo_feature_ahead
  git checkout -q main
  echo new > newfile.txt   # non-ignored, untracked
  local out; out=$(bash "$SCRIPT")
  if [[ "$(field worktree_dirty "$out")" == "yes" \
     && "$(field changes_exist "$out")" == "yes" ]]; then
    pass "non-ignored untracked → worktree_dirty=yes, changes_exist=yes (NG4)"
  else
    fail "ng4 untracked (got: $out)"
  fi
  cd / && rm -rf "$REPO"
}

# AC2 (F2 regression): origin/main exists but there is NO local main — the
# fresh-clone / CI-checkout / worktree topology. base must resolve to a git-usable
# ref (origin/main) so merge-base succeeds and the signal does NOT fail-open to
# degraded in a common setup. A correct branch_ahead_count (>0) + degraded=no
# proves the internal merge_base resolved (merge_base is no longer emitted in v2.7.0).
case_f2_origin_head_no_local_main() {
  local remote; remote=$(mktemp -d) || exit 1; git init -q --bare "$remote"
  mk_repo_feature_ahead
  git remote add origin "$remote"
  git push -q origin main
  git push -q origin feature
  git fetch -q origin main feature 2>/dev/null || true  # ensure refs/remotes/origin/* exist
  git remote set-head origin main
  git branch -D main >/dev/null 2>&1   # only origin/main remains (no local main)
  local out rc; out=$(bash "$SCRIPT"); rc=$?
  if [[ "$(field base "$out")" == "main" \
     && "$(field changes_exist "$out")" == "yes" \
     && "$(field branch_ahead_count "$out")" == "1" \
     && "$(field degraded "$out")" == "no" \
     && "$rc" -eq 0 ]]; then
    pass "origin/main but NO local main → changes_exist=yes (not degraded fail-open)"
  else
    fail "F2 no-local-main fail-open (rc=$rc got: $out)"
  fi
  cd / && rm -rf "$REPO" "$remote"
}

# AC4: detached HEAD → degraded + exit 0 (fail-open)
case_degraded_detached() {
  mk_repo_feature_ahead
  git checkout -q --detach
  local out rc; out=$(bash "$SCRIPT"); rc=$?
  if [[ "$(field degraded "$out")" == "yes" && "$(field changes_exist "$out")" == "no" && "$rc" -eq 0 ]]; then
    pass "detached HEAD → degraded + exit 0 (fail-open)"
  else
    fail "degraded detached (rc=$rc got: $out)"
  fi
  cd / && rm -rf "$REPO"
}

# AC4: no main/master base branch + no remote → degraded + exit 0
case_degraded_no_base() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1   # fail-closed
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b weirdname
  echo x > a.txt; git add a.txt; git commit -qm x
  local out rc; out=$(bash "$SCRIPT"); rc=$?
  if [[ "$(field degraded "$out")" == "yes" && "$rc" -eq 0 ]]; then
    pass "no main/master base → degraded + exit 0"
  else
    fail "degraded no-base (rc=$rc got: $out)"
  fi
  cd / && rm -rf "$REPO"
}

# read-only: working tree + git status unchanged before/after
case_read_only() {
  mk_repo_feature_ahead
  local before after
  before=$(git status --porcelain=v1; find . -type f | sort)
  bash "$SCRIPT" >/dev/null 2>&1
  after=$(git status --porcelain=v1; find . -type f | sort)
  if [[ "$before" == "$after" ]]; then
    pass "read-only: working tree + git status unchanged"
  else
    fail "read-only violated (before != after)"
  fi
  cd / && rm -rf "$REPO"
}

case_changes_exist_branch_ahead
case_changes_exist_none
case_ng4_ignored_not_counted
case_ng4_untracked_counted
case_f2_origin_head_no_local_main
case_degraded_detached
case_degraded_no_base
case_read_only

echo
echo "test_check_review_scope: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
