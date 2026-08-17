#!/usr/bin/env bash
# T11/AC1 — qg.md routes `critique` to critiquing-artifacts (deterministic-row prose lock).
set -u
Q="plugins/quality-gates/commands/qg.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

assert_contains "$(cat "$Q")" 'critiquing-artifacts' "qg.md references critiquing-artifacts skill"
# body-unique (not header/table-satisfiable): "산출물...비평...모드" only occurs in the
# routing-mode prose sentence ("...산출물 비평-수정 루프** 모드다."), not in the section
# heading ("...산출물 비평 루프)") or the Quick Reference table row (no "모드" there).
assert_file_grep "$Q" '산출물.*비평.*모드' "critique routing described"
# critique branch must precede/short-circuit the setup-qg.sh + quality-pipeline path
crit_ln="$(grep -nF 'critiquing-artifacts' "$Q" | head -1 | cut -d: -f1)"
pipe_ln="$(grep -nF 'quality-gates:quality-pipeline' "$Q" | head -1 | cut -d: -f1)"
if [ -n "$crit_ln" ] && [ -n "$pipe_ln" ] && [ "$crit_ln" -lt "$pipe_ln" ]; then
  ok "critique branch appears before code-pipeline dispatch"
else
  no "critique branch must precede quality-pipeline (crit=$crit_ln pipe=$pipe_ln)"
fi
# Quick Reference row for critique — literal "<path>" placeholder is table-row-unique
# (body prose uses a concrete example "docs/design.md", not the "<path>" placeholder).
assert_contains "$(cat "$Q")" '/qg critique <path>' "Quick Reference documents /qg critique"
# NL-routing is model-owned (no deterministic token parser claim). Body-unique phrase:
# a pre-existing unrelated branch-scope NL note elsewhere in qg.md also contains
# "자연어"/"모델이", so a bare alternation is satisfied even with the critique section
# fully absent — pin the exact critique-section wording instead.
assert_contains "$(cat "$Q")" '자연어 의도는 모델이' "NL critique intent noted as model-owned"

finish
