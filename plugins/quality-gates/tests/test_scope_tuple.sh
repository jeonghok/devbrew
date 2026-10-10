#!/usr/bin/env bash
# test_scope_tuple.sh — scripts/scope_tuple.py · 합성기 `--scope`
#   (설계 §6.2.6 · §6.4.3, AC7 · AC15 · AC16)
#
# 스코프 파일은 topic-head.sh 산출물의 모양이다 — 여기서는 손으로 써서 합성기의 행동
# (판정 · 사유 · `scope:` 블록)만 잰다. topic-head.sh 자신은 test_topic_head.sh 가 잰다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"
. "$SCRIPT_DIR/lib/recritic_fixture.sh"
export PYTHONDONTWRITEBYTECODE=1

B=1111111111111111111111111111111111111111
C1=2222222222222222222222222222222222222222
C2=3333333333333333333333333333333333333333
S=4444444444444444444444444444444444444444
TR=5555555555555555555555555555555555555555
HC=6666666666666666666666666666666666666666
T=""

setup_clean_run() {   # 탐지 0 · 재비판 0 · 각도 전부 filled — 스코프만 판정을 움직인다
  T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"
  rf_prep "$T"
  rf_reply "$T" 'verdicts: []
added: []'
  printf 'security: filled\nadjudication: filled\ndifferent-premise: filled\n' > "$T/angles.txt"
}

write_scope() {   # <path> <status> <reason> <tree> <head_commit> <conflicts> <commits> [commit...]
  local p="$1" st="$2" rs="$3" tr="$4" hd="$5" cf="$6" n="$7"; shift 7
  {
    printf 'topic_key: docs/x-design.md#pr1\nstatus: %s\nreason: %s\n' "$st" "$rs"
    printf 'branches: topicA,topicB\nin_base: 1\nboundary: %s\ntips: %s,%s\nseal: %s\nseal_on_topic: yes\n' "$B" "$C1" "$S" "$S"
    printf 'tree: %s\nhead_commit: %s\nconflicts: %s\ncommits: %s\n' "$tr" "$hd" "$cf" "$n"
    local c; for c in "$@"; do printf 'commit: %s\n' "$c"; done
  } > "$p"
}

write_undeclared() {   # <path> <status>
  printf 'topic_key: -\nstatus: %s\nreason: -\nbranches: -\nin_base: -\nboundary: -\ntips: -\nseal: -\nseal_on_topic: -\ntree: -\nhead_commit: -\nconflicts: -\ncommits: -\n' "$2" > "$1"
}

line_of() { printf '%s\n' "$1" | grep -n -E "$2" | head -1 | cut -d: -f1; }

# 파이썬 본문은 `$( )` 안 heredoc 으로 두지 않는다(bash 3.2) — 최상위 heredoc 으로 담는다.
IFS= read -r -d '' PY_LS <<'PY' || true
import sys
sys.path.insert(0, sys.argv[1])
import scope_tuple
base = ("topic_key: docs/x-design.md#pr1\nstatus: no-declaration\nreason: {r}\nbranches: -\nin_base: -\n"
        "boundary: -\ntips: -\nseal: -\nseal_on_topic: -\ntree: -\nhead_commit: -\n"
        "conflicts: -\ncommits: -\n")
for label, r in (("TAIL", "x "), ("MID", "a b: c")):
    d = scope_tuple.parse(base.format(r=r))
    print("%s:%d" % (label, 1 if d["reason"] == r else 0))
PY

case_line_separator_in_value_is_kept() {
  # 줄 경계는 `\n` 하나다 — `splitlines()` 는 U+2028 등도 줄 끝으로 읽어 값의 꼬리를 조용히
  # 잘라 낸다(`x<U+2028>` → `x`). `open()` 의 universal newline 이 CRLF 는 이미 접는다.
  local got; got=$(python3 -c "$PY_LS" "$PLUGIN_ROOT/scripts" 2>&1)
  assert_grep "$got" '^TAIL:1$' "값 끝의 U+2028 이 조용히 잘리지 않는다"
  assert_grep "$got" '^MID:1$'  "값 중간의 U+2028 뒤가 새 줄(모르는 키)로 읽히지 않는다"
}

case_ok_scope_is_clean_and_carries_tuple() {
  setup_clean_run
  write_scope "$T/scope.txt" ok - "$TR" "$HC" - 2 "$C1" "$C2"
  local out; out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/scope.txt")
  assert_grep "$out" '^verdict: clean$'              "status: ok 는 판정을 막지 않는다"
  assert_grep "$out" '^scope:$'                      "scope: 블록이 꼬리에 있다(AC15)"
  assert_grep "$out" '^  mode: topic$'               "ok 면 mode: topic"
  assert_grep "$out" "^  boundary: $B\$"             "경계가 실린다"
  assert_grep "$out" "^  tips: $C1,$S\$"             "끝점이 실린다"
  assert_grep "$out" "^  tree: $TR\$"                "합친 트리 OID 가 실린다"
  assert_grep "$out" '^  commits: 2$'                "본 커밋 수가 실린다"
  assert_grep "$out" "^  commit: $C1\$"              "본 커밋 SHA 1"
  assert_grep "$out" "^  commit: $C2\$"              "본 커밋 SHA 2"
  local ls la lv; ls=$(line_of "$out" '^scope:$'); la=$(line_of "$out" '^angles:$'); lv=$(line_of "$out" '^verdict: ')
  assert_eq "$([ -n "$ls" ] && [ -n "$la" ] && [ -n "$lv" ] && [ "$ls" -lt "$la" ] && [ "$la" -lt "$lv" ] && echo ordered)" \
    "ordered" "꼬리 순서 = scope: → angles: → verdict:"
  rm -rf "$T"
}

case_conflict_is_not_certified_with_files() {
  setup_clean_run
  write_scope "$T/scope.txt" merge-conflict "merge-tree conflict at $C1" - - "f.txt,g.txt" 2 "$C1" "$C2"
  local out; out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/scope.txt")
  assert_grep "$out" '^verdict: not-certified$'      "합치기 충돌은 clean 이 아니다(AC7)"
  assert_grep "$out" '^reason: merge-conflict$'      "사유는 merge-conflict"
  assert_grep "$out" '^  conflicts: f\.txt,g\.txt$'  "충돌 파일이 나열된다"
  assert_grep "$out" '^  mode: session$'             "충돌이면 mode: session(판정 대상은 현재 브랜치)"
  rm -rf "$T"
}

case_declaration_statuses_map_to_reasons() {
  setup_clean_run
  local st want out
  for st in declaration-invalid unbounded merge-failed; do
    case "$st" in merge-failed) want=merge-conflict ;; *) want=declaration-invalid ;; esac
    write_scope "$T/scope.txt" "$st" "x" - - - -
    out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/scope.txt")
    assert_grep "$out" '^verdict: not-certified$' "$st → not-certified"
    assert_grep "$out" "^reason: $want\$"        "$st → reason: $want"
  done
  rm -rf "$T"
}

case_non_blocking_statuses_disclose_only() {
  setup_clean_run
  local st out
  for st in no-declaration base-unresolved seal-failed; do
    write_undeclared "$T/scope.txt" "$st"
    out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/scope.txt")
    assert_grep "$out" '^verdict: clean$'     "$st 는 스코프 사유를 내지 않는다(다른 경로가 막는다)"
    assert_grep "$out" "^  status: $st\$"     "$st 가 scope: 블록에 공시된다"
    assert_grep "$out" '^  mode: session$'    "$st → mode: session"
  done
  rm -rf "$T"
}

case_defect_beats_scope_reason() {
  T=$(mktemp -d)
  printf -- '- {agent: r, file: a.py, line: 1, severity: IMPORTANT, summary: s, proposed_fix: f}\n' > "$T/findings.yaml"
  rf_prep "$T"
  rf_reply "$T" 'verdicts: []
added: []'
  printf 'security: filled\nadjudication: filled\ndifferent-premise: filled\n' > "$T/angles.txt"
  write_scope "$T/scope.txt" merge-conflict x - - "f.txt" -
  local out; out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/scope.txt")
  assert_grep "$out" '^verdict: defect$' "확증 결함은 스코프 미판정보다 우선한다(§6.4.3)"
  rm -rf "$T"
}

case_malformed_scope_is_atomic_fail4() {
  setup_clean_run
  local out rc f
  for f in missing-key bad-status count-mismatch ok-without-tree; do
    case "$f" in
      missing-key)     printf 'topic_key: -\nstatus: ok\n' > "$T/scope.txt" ;;
      bad-status)      write_undeclared "$T/scope.txt" "made-up" ;;
      count-mismatch)  write_scope "$T/scope.txt" ok - "$TR" "$HC" - 3 "$C1" ;;
      ok-without-tree) write_scope "$T/scope.txt" ok - - "$HC" - 1 "$C1" ;;
    esac
    out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/scope.txt" 2>/dev/null); rc=$?
    assert_eq "$rc" "4" "$f → exit 4"
    assert_eq "$out" "" "$f → stdout 비어 있음(원자적 실패)"
  done
  rm -rf "$T"
}

case_scope_flag_usage_errors() {
  setup_clean_run
  write_undeclared "$T/scope.txt" no-declaration
  local rc
  rf_synth "$T" --scope "$T/scope.txt" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "--scope 는 --emit-verdict 없이 exit 2"
  rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "--scope 빈 문자열 exit 2"
  rm -rf "$T"
}

case_in_base_disclosed_and_validated() {
  # AC4 재정의 — 판정에서 빠진 머지된 앞 조각의 수가 scope: 블록에 실린다.
  setup_clean_run
  write_scope "$T/scope.txt" ok - "$TR" "$HC" - 2 "$C1" "$C2"
  local out rc; out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/scope.txt")
  assert_grep "$out" '^  in_base: 1$' "scope: 블록에 in_base 가 실린다"
  local lb li; lb=$(line_of "$out" '^  branches: '); li=$(line_of "$out" '^  in_base: ')
  assert_eq "$([ -n "$lb" ] && [ -n "$li" ] && [ "$li" -eq $((lb + 1)) ] && echo next)" "next" "in_base 는 branches 바로 다음 줄"
  sed 's/^in_base: 1$/in_base: 1x/' "$T/scope.txt" > "$T/bad.txt"
  out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/bad.txt" 2>/dev/null); rc=$?
  assert_eq "$rc" "4" "in_base 가 수 · - 가 아니면 exit 4(1x — fullmatch)"
  assert_eq "$out" "" "그때 stdout 비어 있음"
  # status 가 ok 가 아니어도 형식 검사가 선다 — ok 블록 검사가 대신 잡지 못하는 자리
  write_undeclared "$T/u2.txt" no-declaration
  sed 's/^in_base: -$/in_base: 1x/' "$T/u2.txt" > "$T/bad3.txt"
  out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/bad3.txt" 2>/dev/null); rc=$?
  assert_eq "$rc" "4" "status 가 ok 가 아니어도 in_base 가 수 · - 가 아니면 exit 4"
  sed 's/^in_base: 1$/in_base: -/' "$T/scope.txt" > "$T/bad2.txt"
  out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/bad2.txt" 2>/dev/null); rc=$?
  assert_eq "$rc" "4" "status: ok 인데 in_base 가 - 면 exit 4"
  write_undeclared "$T/u.txt" no-declaration
  out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/u.txt"); rc=$?
  assert_eq "$rc" "0" "선언 없음의 in_base: - 는 받는다(양의 짝)"
  assert_grep "$out" '^  in_base: -$' "선언 없음: in_base: - 가 공시된다"
  rm -rf "$T"
}

for c in case_ok_scope_is_clean_and_carries_tuple case_conflict_is_not_certified_with_files \
         case_declaration_statuses_map_to_reasons case_non_blocking_statuses_disclose_only \
         case_defect_beats_scope_reason case_malformed_scope_is_atomic_fail4 \
         case_scope_flag_usage_errors case_line_separator_in_value_is_kept \
         case_in_base_disclosed_and_validated; do
  echo "== $c"; $c
done
finish
