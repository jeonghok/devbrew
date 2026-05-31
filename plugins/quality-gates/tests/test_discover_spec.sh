#!/usr/bin/env bash
# Tests for scripts/discover-spec.sh — mirror of test_discover_plan.sh,
# re-aimed at the SPEC artifact (Acceptance-Criteria-section eligibility,
# project-local only — no legacy-global source).
# Uses bash assertions; no external test framework.

set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/discover-spec.sh"
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

# Run from a given dir; capture stdout + exit code.
run_in_env() {
  local proj="$1"; shift
  cd "$proj"
  bash "$SCRIPT" "$@" 2>"$proj/_stderr"
  return $?
}

# write_spec <path> <with_ac:1|0>
write_spec() {
  local path="$1" with_ac="$2"
  mkdir -p "$(dirname "$path")"
  {
    echo "# Some Spec Title"
    echo
    echo "## 1. Context"
    echo "prose"
    if [[ "$with_ac" == "1" ]]; then
      echo "## 5. Acceptance Criteria"
      echo "1. the thing works"
    fi
  } > "$path"
}

# --- Test 1: project-local empty → exit 1, source=none ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/docs/superpowers/specs"
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "1" "T1: exit 1 when no spec"
assert_contains "$OUT" '"source":"none"' "T1: source=none"
assert_contains "$OUT" "docs/superpowers/specs" "T1: reason mentions specs path"
cd / && rm -rf "$TMPDIR"

# --- Test 2: project-local has 1 spec WITH AC section → source=project-local ---
TMPDIR=$(mktemp -d)
write_spec "$TMPDIR/docs/superpowers/specs/foo-design.md" 1
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "0" "T2: exit 0 with eligible spec"
assert_contains "$OUT" '"source":"project-local"' "T2: source=project-local"
assert_contains "$OUT" "foo-design.md" "T2: spec_path mentions foo-design.md"
cd / && rm -rf "$TMPDIR"

# --- Test 3: project-local file WITHOUT AC section → ineligible → exit 1 ---
TMPDIR=$(mktemp -d)
write_spec "$TMPDIR/docs/superpowers/specs/notes.md" 0
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "1" "T3: exit 1 when only non-AC markdown exists"
assert_contains "$OUT" '"source":"none"' "T3: source=none for non-spec file"
cd / && rm -rf "$TMPDIR"

# --- Test 4: --spec <existing> → source=explicit ---
TMPDIR=$(mktemp -d)
write_spec "$TMPDIR/custom.md" 1
OUT=$(run_in_env "$TMPDIR" --spec "$TMPDIR/custom.md")
RC=$?
assert_eq "$RC" "0" "T4: exit 0 with --spec to existing file"
assert_contains "$OUT" '"source":"explicit"' "T4: source=explicit"
assert_contains "$OUT" "custom.md" "T4: spec_path is the explicit path"
cd / && rm -rf "$TMPDIR"

# --- Test 5: --spec <nonexistent> → exit 2 ---
TMPDIR=$(mktemp -d)
OUT=$(run_in_env "$TMPDIR" --spec "/tmp/definitely-no-spec-xyz123.md")
RC=$?
assert_eq "$RC" "2" "T5: exit 2 with --spec to nonexistent file"
assert_contains "$OUT" '"source":"none"' "T5: source=none"
assert_contains "$OUT" "does not exist" "T5: reason mentions 'does not exist'"
cd / && rm -rf "$TMPDIR"

# --- Test 6: two eligible specs → most recent mtime wins ---
TMPDIR=$(mktemp -d)
write_spec "$TMPDIR/docs/superpowers/specs/older.md" 1
write_spec "$TMPDIR/docs/superpowers/specs/newer.md" 1
touch -t 202601010000 "$TMPDIR/docs/superpowers/specs/older.md"
touch -t 202601010001 "$TMPDIR/docs/superpowers/specs/newer.md"
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "0" "T6: exit 0"
assert_contains "$OUT" "newer.md" "T6: picks most recently modified eligible spec"
cd / && rm -rf "$TMPDIR"

# --- Test 7: --spec with no following path → exit 2 (regression) ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
OUT=$(bash "$SCRIPT" --spec 2>/dev/null)
RC=$?
assert_eq "$RC" "2" "T7: exit 2 when --spec has no path"
assert_contains "$OUT" '"source":"none"' "T7: source=none"
assert_contains "$OUT" "requires a path argument" "T7: reason mentions path argument requirement"
cd / && rm -rf "$TMPDIR"

# --- Test 8: no-root-miss — eligible spec at proj root is missed from a subdir ---
TMPDIR=$(mktemp -d)
write_spec "$TMPDIR/docs/superpowers/specs/foo-design.md" 1
mkdir -p "$TMPDIR/sub/dir"
OUT=$(run_in_env "$TMPDIR/sub/dir")
RC=$?
assert_eq "$RC" "1" "T8: exit 1 when invoked from a subdir (project-local resolved against \$PWD)"
assert_contains "$OUT" '"source":"none"' "T8: source=none from wrong cwd"
cd / && rm -rf "$TMPDIR"

# --- Summary ---
echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
