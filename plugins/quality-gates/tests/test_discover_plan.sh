#!/usr/bin/env bash
# Tests for scripts/discover-plan.sh
# Uses bash assertions; no external test framework.
# Mirrors style of test_setup_qg.sh.

set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/discover-plan.sh"
PASS=0
FAIL=0

note() { echo "  → $1"; }

assert_eq() {
  local actual="$1" expected="$2" msg="$3"
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (got '$actual', expected '$expected')"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (string '$needle' not in '$haystack')"
  fi
}

# Helper: build a tmp HOME + project root, run script, capture stdout + exit code
run_in_env() {
  # Args: project_dir, [extra script args...]
  local proj="$1"; shift
  cd "$proj"
  HOME="$proj/home" bash "$SCRIPT" "$@" 2>"$proj/_stderr"
  return $?
}

write_plan() {
  # write_plan <path> <unchecked_count> <checked_count>
  local path="$1" unchecked="$2" checked="$3"
  mkdir -p "$(dirname "$path")"
  : > "$path"
  for ((i=0; i<unchecked; i++)); do echo "- [ ] item $i" >> "$path"; done
  for ((i=0; i<checked; i++)); do echo "- [x] item $i" >> "$path"; done
}

# --- Test 1: both sources empty → exit 1, source=none ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/docs/superpowers/plans" "$TMPDIR/home/.claude/plans"
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "1" "T1: exit 1 when both empty"
assert_contains "$OUT" '"source":"none"' "T1: source=none"
assert_contains "$OUT" "docs/superpowers/plans" "T1: reason mentions project-local path"
assert_contains "$OUT" ".claude/plans" "T1: reason mentions legacy path"
cd / && rm -rf "$TMPDIR"

# --- Test 2: project-local has 1 unchecked plan → source=project-local ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/home/.claude/plans"
write_plan "$TMPDIR/docs/superpowers/plans/foo.md" 3 0
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "0" "T2: exit 0 with project-local plan"
assert_contains "$OUT" '"source":"project-local"' "T2: source=project-local"
assert_contains "$OUT" "foo.md" "T2: plan_path mentions foo.md"
cd / && rm -rf "$TMPDIR"

# --- Test 3: project-local all-checked + legacy unchecked → project-local wins ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/home/.claude/plans"
write_plan "$TMPDIR/docs/superpowers/plans/done.md" 0 5
write_plan "$TMPDIR/home/.claude/plans/old.md" 3 0
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "0" "T3: exit 0"
assert_contains "$OUT" '"source":"project-local"' "T3: priority over checkbox status"
assert_contains "$OUT" "done.md" "T3: picks all-checked project-local plan"
cd / && rm -rf "$TMPDIR"

# --- Test 4: project-local empty + legacy has 1 → source=legacy-global ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/docs/superpowers/plans"
write_plan "$TMPDIR/home/.claude/plans/legacy.md" 2 0
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "0" "T4: exit 0 with legacy plan"
assert_contains "$OUT" '"source":"legacy-global"' "T4: legacy fallback fires"
assert_contains "$OUT" "legacy.md" "T4: legacy plan picked"
cd / && rm -rf "$TMPDIR"

# --- Test 5: project-local has README only (0 checkboxes) → source=none ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/home/.claude/plans"
mkdir -p "$TMPDIR/docs/superpowers/plans"
echo "# README" > "$TMPDIR/docs/superpowers/plans/README.md"
echo "Some prose without checkboxes." >> "$TMPDIR/docs/superpowers/plans/README.md"
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "1" "T5: exit 1 when only non-plan files exist"
assert_contains "$OUT" '"source":"none"' "T5: source=none for non-plan file"
cd / && rm -rf "$TMPDIR"

# --- Test 6: --plan <existing> → source=explicit ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/home/.claude/plans"
write_plan "$TMPDIR/custom.md" 1 0
OUT=$(run_in_env "$TMPDIR" --plan "$TMPDIR/custom.md")
RC=$?
assert_eq "$RC" "0" "T6: exit 0 with --plan to existing file"
assert_contains "$OUT" '"source":"explicit"' "T6: source=explicit"
assert_contains "$OUT" "custom.md" "T6: plan_path is the explicit path"
cd / && rm -rf "$TMPDIR"

# --- Test 7: --plan <nonexistent> → exit 2 ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/home/.claude/plans"
OUT=$(run_in_env "$TMPDIR" --plan "/tmp/definitely-does-not-exist-xyz123.md")
RC=$?
assert_eq "$RC" "2" "T7: exit 2 with --plan to nonexistent file"
assert_contains "$OUT" '"source":"none"' "T7: source=none"
assert_contains "$OUT" "does not exist" "T7: reason mentions 'does not exist'"
cd / && rm -rf "$TMPDIR"

# --- Test 8: project-local has 2 unchecked plans → most recent mtime wins ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/home/.claude/plans"
write_plan "$TMPDIR/docs/superpowers/plans/older.md" 1 0
sleep 1.1
write_plan "$TMPDIR/docs/superpowers/plans/newer.md" 1 0
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "0" "T8: exit 0"
assert_contains "$OUT" "newer.md" "T8: picks most recently modified"
cd / && rm -rf "$TMPDIR"

# --- Test 9: project-local has 2 zero-checkbox files → falls through to legacy ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/home/.claude/plans" "$TMPDIR/docs/superpowers/plans"
echo "no checkboxes" > "$TMPDIR/docs/superpowers/plans/a.md"
echo "also none" > "$TMPDIR/docs/superpowers/plans/b.md"
write_plan "$TMPDIR/home/.claude/plans/legacy.md" 2 0
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "0" "T9: exit 0 (fell through to legacy)"
assert_contains "$OUT" '"source":"legacy-global"' "T9: source=legacy-global after fall-through"
assert_contains "$OUT" "legacy.md" "T9: legacy plan picked"
cd / && rm -rf "$TMPDIR"

# --- Test 10: --plan with no following path → exit 2 (regression) ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/home/.claude/plans"
cd "$TMPDIR"
OUT=$(HOME="$TMPDIR/home" bash "$SCRIPT" --plan 2>/dev/null)
RC=$?
assert_eq "$RC" "2" "T10: exit 2 when --plan has no path"
assert_contains "$OUT" '"source":"none"' "T10: source=none"
assert_contains "$OUT" "requires a path argument" "T10: reason mentions path argument requirement"
cd / && rm -rf "$TMPDIR"

# --- Summary ---
echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
