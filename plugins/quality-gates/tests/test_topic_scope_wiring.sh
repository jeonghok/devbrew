#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/quality-pipeline/references/differential-test.md plugins/quality-gates/scripts/scope_tuple.py
# test_topic_scope_wiring.sh — 토픽 스코프 배선 (설계 §6.2 · §6.4.1, AC3–AC7 · AC15 · AC16).
#
# 오케스트레이터 산문이 스크립트 산출물을 «실제로» 흘리는가를 잰다. 각 사실은 그것이 적힌
# 한 줄(또는 한 펜스)에서 잰다 — 다른 행이 대신 만족시키면 뒤집기를 못 잡는다. 열거가
# 필요한 단언은 코드의 열거(scope_tuple.STATUSES)에서 도출한다.
set -u
[ "${1:-}" = "--emit-scanned" ] && { printf '%s\n' \
  plugins/quality-gates/skills/quality-pipeline/SKILL.md \
  plugins/quality-gates/skills/quality-pipeline/references/differential-test.md \
  plugins/quality-gates/scripts/scope_tuple.py; exit 0; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
REF="$PLUGIN_ROOT/skills/quality-pipeline/references/differential-test.md"
export PYTHONDONTWRITEBYTECODE=1

# 파이썬 본문은 `$( )` 안 heredoc 으로 두지 않는다 — bash 3.2 는 그 본문의 짝 없는 괄호 ·
# 따옴표로 치환 경계를 잘못 잡는다. 최상위 heredoc 으로 변수에 담고 `python3 -c` 로 넘긴다.
IFS= read -r -d '' PY_TRIVIA <<'PY' || true
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'^## Trivia escape\n(.*?)(?=^## )', text, re.S | re.M)
lines = (m.group(1) if m else "").splitlines()
det = [i for i, l in enumerate(lines) if 'resolve-topic.sh" detect' in l]
trv = [i for i, l in enumerate(lines) if 'check-trivia.sh' in l]
print("DETECT:%d" % len(det))
print("DETECT_FIRST:%d" % (1 if det and trv and det[0] < trv[0] else 0))
skip_needle = 'trivia escape 를 **쓰지 않고** 곧장 iteration 1 로 간다'
skip = [l for l in lines if 'status: ok' in l and 'status: declaration-invalid' in l and skip_needle in l]
print("SKIP_LINE:%d" % len(skip))
nodecl_violation = [l for l in lines if 'no-declaration' in l and 'trivia escape' in l and '쓰지 않' in l]
print("NODECL_VIOLATION:%d" % len(nodecl_violation))
PY

IFS= read -r -d '' PY_STATUS <<'PY' || true
import re, sys
sys.path.insert(0, sys.argv[2])
import scope_tuple
text = open(sys.argv[1], encoding="utf-8").read()
missing, wrong = [], []
for st in scope_tuple.STATUSES:
    pat = re.compile(r'^\s*\| `' + re.escape(st) + r'` \|')
    rows = [l for l in text.splitlines() if pat.match(l)]
    if len(rows) != 1:
        missing.append(st)
        continue
    r = rows[0]
    if st == "ok":
        if "**topic**" not in r or "| session |" in r:
            wrong.append(st)
    elif "| session |" not in r or "**topic**" in r:
        wrong.append(st)
print("MISSING:" + ",".join(missing))
print("WRONG:" + ",".join(wrong))
PY

case_trivia_escape_is_gated_by_declaration() {
  # Review Focus 2 · R-AO — 선언이 있으면 trivia escape 를 쓰지 않는다.
  local got; got=$(python3 -c "$PY_TRIVIA" "$SKILL")
  assert_grep "$got" '^DETECT:1$'         "Trivia escape 절에 detect 호출 펜스가 하나"
  assert_grep "$got" '^DETECT_FIRST:1$'   "detect 가 check-trivia 보다 먼저 나온다"
  assert_grep "$got" '^SKIP_LINE:1$'      "ok · declaration-invalid 면 trivia escape 를 쓰지 않고 곧장 iteration 1 로 간다(같은 줄, 긍정 목적지 단언)"
  assert_grep "$got" '^NODECL_VIOLATION:0$' "Trivia 절 전체에서 no-declaration 과 trivia escape 를 쓰지 않음이 한 줄에 함께 나오지 않는다"
}

case_step1_writes_scope_file() {
  # R-AJ — ① 1a 가 매 iteration topic-head.sh 출력을 고정 경로에 쓴다. 산문으로 옮기면
  # 실행되지 않으므로 bash 펜스 «안»의 줄만 센다.
  local n
  n=$(awk '/^[[:space:]]*```bash/{f=1;next} /^[[:space:]]*```/{f=0} f' "$SKILL" \
      | grep -cF '"$QG/scripts/topic-head.sh" "<session-id>" > ".claude/quality-gates/<session-id>/topic-scope.txt" && cat ".claude/quality-gates/<session-id>/topic-scope.txt"')
  assert_eq "$n" "1" "① 1a 펜스가 topic-head.sh 출력을 .claude/quality-gates/<session-id>/topic-scope.txt 에 쓰고 && 로 그대로 cat 한다(한 줄, || true 로 삼키지 않는다)"
}

case_status_table_is_total_over_statuses() {
  # R-AK — 상태 표가 scope_tuple.STATUSES 전부를 받고, ok 만 topic 이다.
  local got; got=$(python3 -c "$PY_STATUS" "$SKILL" "$PLUGIN_ROOT/scripts")
  assert_grep "$got" '^MISSING:$' "상태 표가 STATUSES 여덟 전부를 정확히 한 행씩 받는다"
  assert_grep "$got" '^WRONG:$'   "ok 행만 **topic**, 나머지는 session"
}

case_topic_diff_uses_boundary_and_tree() {
  # ② · ③ 이 같은 트리를 본다 — 파일 집합 · diff 는 스코프 파일의 boundary · tree 에서.
  # `git ` 으로 시작하는 줄이면 A20 락이 session 합집합으로 끌어가 실행한다.
  local got
  got=$(grep -F "sed -n 's/^boundary: //p'" "$SKILL" | grep -F "sed -n 's/^tree: //p'" | grep -F 'git diff --name-only "$b" "$t"')
  assert_eq "$(printf '%s\n' "$got" | grep -c .)" "1" "파일 집합 질의가 boundary · tree 를 한 줄에서 읽는다"
  assert_not_grep "$got" '^[[:space:]]*git ' "그 줄은 git 으로 시작하지 않는다(A20 session 오라클 밖)"
  case "$got" in
    *'git diff --name-only "$b" "$t"') ok "그 줄이 git diff --name-only \"\$b\" \"\$t\" 로 끝난다(뒤에 다른 git 호출을 덧붙이지 않는다)" ;;
    *) no "그 줄이 git diff --name-only \"\$b\" \"\$t\" 로 끝난다(뒤에 다른 git 호출을 덧붙이지 않는다)"
       printf '      actual tail: %s\n' "$got" ;;
  esac
}

case_step4_row_carries_scope() {
  # R-AL — 두 사유와 scope: 블록은 합성기가 이 파일에서 낸다. SKILL 의 의무는 싣는 것 하나.
  local rows
  rows=$(grep -F -- '--scope ".claude/quality-gates/<session-id>/topic-scope.txt"' "$SKILL")
  assert_eq "$(printf '%s\n' "$rows" | grep -c '^[[:space:]]*|')" "1" "Step 4 판정 입력 표에 --scope 행이 하나"
  assert_grep "$rows" 'topic-head\.sh' "그 행이 조건(① 이 topic-head.sh 를 불렀다)을 같은 줄에 적는다"
  assert_grep "$rows" '불렀다' "그 행의 조건이 1a 호출을 긍정형(불렀다)으로 적는다"
  assert_not_grep "$rows" '부르지|않았' "그 행의 조건이 호출-부정형(부르지 · 않았)이 아니다"
  assert_not_grep "$rows" '싣지 (않|말)|없음|생략' "그 행이 부정형(싣지 않는다 · 싣지 말 것 · 없음 · 생략)이 아니다"
}

case_scope_block_surfaces() {
  # AC15 — scope: 블록이 판정 옆(Step 4.5)과 Final Summary 에 그대로 나간다.
  local s45 fs fs_needle
  s45=$(grep -F '`scope:` 블록' "$SKILL" | grep -F '**그대로** 보인다')
  assert_eq "$(printf '%s\n' "$s45" | grep -c .)" "1" "Step 4.5 가 scope: 블록을 그대로 보인다(한 줄, 긍정형 — '보이지 말고' 는 이 needle 을 못 만족한다)"
  fs_needle='the last synthesizer output'\''s `scope:` block and `angles:` block verbatim'
  fs=$(awk '/^## Final Summary$/{f=1;next} f&&/^## /{exit} f' "$SKILL" | grep -F -- "$fs_needle")
  assert_eq "$(printf '%s\n' "$fs" | grep -c .)" "1" "Final Summary 가 scope: · angles: 블록을 이 순서로 verbatim 싣는다(한 줄, 리터럴)"
}

case_filtered_diff_uses_boundary_and_tree() {
  # 리뷰 라운드 1 신규 — FILTERED_DIFF 도 topic 스코프에서는 경계 · 합친 트리에서 뽑는다.
  # session 베이스라인(MERGE_BASE·HEAD)으로 새면 리뷰어 diff 가 스코프 파일과 어긋난다.
  local got
  got=$(grep -F 'FILTERED_DIFF' "$SKILL" | grep -F 'git diff "$b" "$t"')
  assert_eq "$(printf '%s\n' "$got" | grep -c .)" "1" "FILTERED_DIFF 문장이 같은 줄에서 git diff \"\$b\" \"\$t\" 를 쓴다"
  assert_not_grep "$got" 'MERGE_BASE|HEAD' "그 줄에 MERGE_BASE · HEAD 가 없다(session 베이스라인으로 새지 않는다)"
}

for c in case_trivia_escape_is_gated_by_declaration case_step1_writes_scope_file \
         case_status_table_is_total_over_statuses case_topic_diff_uses_boundary_and_tree \
         case_step4_row_carries_scope case_scope_block_surfaces \
         case_filtered_diff_uses_boundary_and_tree; do
  echo "== $c"; $c
done
finish
