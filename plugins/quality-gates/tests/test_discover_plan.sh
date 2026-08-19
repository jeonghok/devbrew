#!/usr/bin/env bash
# Tests for scripts/discover-plan.sh
# Uses bash assertions; no external test framework.
# Mirrors style of test_setup_qg.sh.

set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/discover-plan.sh"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"




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
write_plan "$TMPDIR/docs/superpowers/plans/newer.md" 1 0
touch -t 202601010000 "$TMPDIR/docs/superpowers/plans/older.md"
touch -t 202601010001 "$TMPDIR/docs/superpowers/plans/newer.md"
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

# --- Test 11: sibling discover_common.sh missing (broken install) ---
# `.` 는 POSIX special builtin 이라 파일이 없으면 셸이 즉시 죽는다 — stdout 은 비고
# 계약(JSON)이 사라진다. 가드가 그것을 계약대로의 JSON + exit 2 로 바꾼다.
# 짝(positive): 공유 파일이 없어도 explicit `--plan <path>` 는 여전히 성립해야 한다.
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/scripts" "$TMPDIR/docs/superpowers/plans"
cp "$SCRIPT" "$TMPDIR/scripts/discover-plan.sh"
printf -- '- [ ] item\n' > "$TMPDIR/docs/superpowers/plans/p.md"
cd "$TMPDIR"
OUT=$(HOME="$TMPDIR/home" bash "$TMPDIR/scripts/discover-plan.sh" 2>/dev/null)
RC=$?
assert_eq "$RC" "2" "T11: exit 2 when discover_common.sh is absent"
assert_contains "$OUT" '"plan_path":""' "T11: contract JSON still emitted (stdout not empty)"
assert_contains "$OUT" "discover_common.sh" "T11: reason names the missing sibling"
OUT=$(HOME="$TMPDIR/home" bash "$TMPDIR/scripts/discover-plan.sh" --plan "$TMPDIR/docs/superpowers/plans/p.md" 2>/dev/null)
RC=$?
assert_eq "$RC" "0" "T11-pair: explicit --plan still resolves without the shared file"
assert_contains "$OUT" '"source":"explicit"' "T11-pair: source=explicit"
cd / && rm -rf "$TMPDIR"

# --- Test 12: tier order — unchecked beats mtime, and mtime breaks ties inside a tier ---
# 헤더가 약속하는 두 축을 갈라서 잰다. tier 순서를 뒤집어도, tier 안의 mtime 비교를
# 뒤집어도 각각 하나씩 RED 가 되도록 두 케이스를 둔다(한 케이스로는 둘을 구분 못 한다).
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/docs/superpowers/plans" "$TMPDIR/home/.claude/plans"
printf -- '- [ ] todo\n' > "$TMPDIR/docs/superpowers/plans/older-unchecked.md"
sleep 1
printf -- '- [x] done\n' > "$TMPDIR/docs/superpowers/plans/newer-checked.md"
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "0" "T12: exit 0"
assert_contains "$OUT" "older-unchecked.md" "T12: unchecked plan wins over a NEWER all-checked plan (tier before mtime)"
cd / && rm -rf "$TMPDIR"

TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/docs/superpowers/plans" "$TMPDIR/home/.claude/plans"
printf -- '- [x] done\n' > "$TMPDIR/docs/superpowers/plans/older-checked.md"
sleep 1
printf -- '- [X] done\n' > "$TMPDIR/docs/superpowers/plans/newer-checked.md"
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "0" "T12b: exit 0"
assert_contains "$OUT" "newer-checked.md" "T12b: inside the all-checked fallback tier, newest mtime wins"
cd / && rm -rf "$TMPDIR"

# --- Summary ---
finish
