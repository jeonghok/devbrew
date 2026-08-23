#!/usr/bin/env bash
# test_qg_false_clean_floor.sh — AC13 e2e: the verdict-integrity floor blocks
# false-clean (resolved scope 0 + changes exist) end-to-end (design v2.7.0 §5.3).
# Drives the REAL (shrunk) check-review-scope.sh in isolated throwaway repos and
# applies the SAME floor decision the SKILL Step 4.5 prose specifies. The static
# prose-anchor that the SKILL text matches this decision is asserted in
# tests/harness/test_skill_orchestration_behavior.sh (the `resolved_scope_file_count
# == 0` + `changes_exist == yes` anchors). Together = the two-layer verification of
# design-spec AC5 (prose-anchor + this executable e2e).
#
# FAIL-CLOSED: every fixture cds into a fresh mktemp repo BEFORE any git command;
# a failed mktemp/cd aborts immediately so git never runs in the caller's repo
# (v2.6.0 dogfood lesson: a set -u-only fixture risked `git branch -D main` on the
# live repo — project_qg_scope_capture).

set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/check-review-scope.sh"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
REPO=""

# field <key> <output-text> → prints the value after "<key>: "

# floor_verdict <resolved_count> <changes_exist> <degraded> → not_clean | clean | clean_degraded
# Mirror of SKILL Step 4.5 §5.3. The harness static anchor asserts the SKILL prose
# carries this exact condition (design-spec AC5, layer 1); this side is layer 2 (executable).
floor_verdict() {
  local resolved="$1" changes="$2" degraded="$3"
  if [[ "$resolved" -eq 0 && "$changes" == "yes" ]]; then
    echo "not_clean"
  elif [[ "$degraded" == "yes" && "$resolved" -eq 0 ]]; then
    echo "clean_degraded"
  else
    echo "clean"
  fi
}

# resolved_scope_file_count fixture (mirror of SKILL §5.3 session derivation).
# There is no on-disk representation of this value in production — SKILL.md's
# `$resolved_scope_file_count` is a value the MODEL asserts from its own turn's
# scope resolution and is by design never derived from check-review-scope.sh
# (the two signals must stay independently computed, or the floor below can
# never observe a disagreement between them). Each case sets `resolved` as a
# plain local variable standing in for that model-asserted count, instead of
# round-tripping it through a file.

# Build a repo with a 'main' base + a 'feature' branch 1 commit ahead.
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

# AC13 core: empty session scope (0 files) + branch ahead → floor returns not_clean.
case_false_clean_blocked() {
  mk_repo_feature_ahead
  export CLAUDE_CODE_SESSION_ID="fc-empty-$$"
  local out resolved verdict
  out=$(bash "$SCRIPT")
  resolved=0   # model-asserted resolved scope (fixture) — see comment above
  verdict=$(floor_verdict "$resolved" "$(field changes_exist "$out")" "$(field degraded "$out")")
  if [[ "$verdict" == "not_clean" \
     && "$(field changes_exist "$out")" == "yes" \
     && "$(field branch_ahead_count "$out")" == "1" ]]; then
    ok "false-clean (0 files + branch ahead) → NOT certified clean"
  else
    no "false-clean not blocked (resolved=$resolved verdict=$verdict out=$out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

# AC7 happy-path: resolved scope >0 → floor returns clean (no false-positive block).
case_scope_present_clean() {
  mk_repo_feature_ahead
  export CLAUDE_CODE_SESSION_ID="fc-files-$$"
  local out resolved verdict
  out=$(bash "$SCRIPT")
  resolved=1   # model-asserted resolved scope (fixture) — see comment above
  verdict=$(floor_verdict "$resolved" "$(field changes_exist "$out")" "$(field degraded "$out")")
  if [[ "$verdict" == "clean" && "$resolved" -eq 1 ]]; then
    ok "resolved scope >0 → clean (happy-path, no floor over-fire)"
  else
    no "scope-present clean (resolved=$resolved verdict=$verdict out=$out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

# C4 genuine no-op: on base, clean tree → changes_exist=no → floor clean.
case_genuine_noop_clean() {
  mk_repo_feature_ahead
  git checkout -q main
  export CLAUDE_CODE_SESSION_ID="fc-noop-$$"
  local out resolved verdict
  out=$(bash "$SCRIPT")
  resolved=0   # model-asserted resolved scope (fixture) — see comment above
  verdict=$(floor_verdict "$resolved" "$(field changes_exist "$out")" "$(field degraded "$out")")
  if [[ "$verdict" == "clean" && "$(field changes_exist "$out")" == "no" ]]; then
    ok "genuine no-op (no changes) → clean (floor not over-fired)"
  else
    no "genuine no-op clean (verdict=$verdict out=$out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

# AC6 degraded: no base branch → degraded → floor fail-open (clean_degraded).
case_degraded_fail_open() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1   # fail-closed
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b weirdname
  echo x > a.txt; git add a.txt; git commit -qm x
  export CLAUDE_CODE_SESSION_ID="fc-degraded-$$"
  local out resolved verdict
  out=$(bash "$SCRIPT")
  resolved=0   # model-asserted resolved scope (fixture) — see comment above
  verdict=$(floor_verdict "$resolved" "$(field changes_exist "$out")" "$(field degraded "$out")")
  if [[ "$verdict" == "clean_degraded" && "$(field degraded "$out")" == "yes" ]]; then
    ok "no base branch → degraded → floor fail-open (clean + advisory)"
  else
    no "degraded fail-open (verdict=$verdict out=$out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

case_false_clean_blocked
case_scope_present_clean
case_genuine_noop_clean
case_degraded_fail_open
finish
