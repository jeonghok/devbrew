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
m = re.search(r'^### Trivia escape\n(.*?)(?=^## )', text, re.S | re.M)
lines = (m.group(1) if m else "").splitlines()
det = [i for i, l in enumerate(lines) if 'resolve-topic.sh" detect' in l]
trv = [i for i, l in enumerate(lines) if '작은 수정이라 파이프라인을 건너뛰었다' in l]
print("DETECT:%d" % len(det))
print("DETECT_FIRST:%d" % (1 if det and trv and det[0] < trv[0] else 0))
skip_needle = 'trivia escape 를 **쓰지 않고** 곧장 iteration 1 로 간다'
skip = [l for l in lines if 'status: ok' in l and 'status: declaration-invalid' in l and skip_needle in l]
print("SKIP_LINE:%d" % len(skip))
nodecl_violation = [l for l in lines if 'no-declaration' in l and ('iteration 1' in l or ('trivia escape' in l and '쓰지 않' in l))]
print("NODECL_VIOLATION:%d" % len(nodecl_violation))
PY

IFS= read -r -d '' PY_1A <<'PY' || true
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
lines = text.splitlines()
open_re = re.compile(r'^[ \t]*```bash\s*$')
close_re = re.compile(r'^[ \t]*```\s*$')
fences = []
i = 0
while i < len(lines):
    if open_re.match(lines[i]):
        j = i + 1
        body = []
        while j < len(lines) and not close_re.match(lines[j]):
            body.append(lines[j].strip())
            j += 1
        fences.append(body)
        i = j + 1
    else:
        i += 1
needle = '"$QG/scripts/topic-head.sh" "<session-id>"'
hits = [b for b in fences if any(needle in l for l in b)]
print("FENCES:%d" % len(hits))
body = hits[0] if hits else []
th = [k for k, l in enumerate(body) if needle in l]
print("TH_LINES:%d" % len(th))
th_exact = '"$QG/scripts/topic-head.sh" "<session-id>" > "$S" && cat "$S"'
print("TH_EXACT:%d" % (1 if len(th) == 1 and body[th[0]] == th_exact else 0))
s_last = None
for l in (body[:th[0]] if th else []):
    for part in l.split(";"):
        p = part.strip()
        if p.startswith("export "):
            p = p[len("export "):].strip()
        if p.startswith("S="):
            s_last = l
s_exact = 'S="$(git rev-parse --show-toplevel)/.claude/quality-gates/<session-id>/topic-scope.txt"; mkdir -p "${S%/*}"'
print("S_EXACT:%d" % (1 if s_last == s_exact else 0))
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

IFS= read -r -d '' PY_RM <<'PY' || true
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
lines = text.splitlines()
open_re = re.compile(r'^[ \t]*```bash\s*$')
close_re = re.compile(r'^[ \t]*```\s*$')
fences = []
i = 0
while i < len(lines):
    if open_re.match(lines[i]):
        start = i
        j = i + 1
        body = []
        while j < len(lines) and not close_re.match(lines[j]):
            body.append(lines[j])
            j += 1
        fences.append((start, body))
        i = j + 1
    else:
        i += 1
rm_needle = 'rm -f "$(git rev-parse --show-toplevel)/.claude/quality-gates/<session-id>/topic-scope.txt"'
hits = [f for f in fences if any(rm_needle in l for l in f[1])]
print("RM_FENCES:%d" % len(hits))
if hits:
    start = hits[0][0]
    k = start - 1
    while k >= 0 and lines[k].strip() == "":
        k -= 1
    para = []
    while k >= 0 and lines[k].strip() != "":
        para.append(lines[k])
        k -= 1
    para_text = "\n".join(reversed(para))
else:
    para_text = ""
print("PARA_OVERRIDE:%d" % (1 if "override" in para_text else 0))
print("PARA_BRANCH:%d" % (1 if "branch" in para_text else 0))
print("PARA_PATHS:%d" % (1 if "--paths" in para_text else 0))
print("PARA_DELETE_POS:%d" % (1 if "지운다" in para_text else 0))
print("PARA_DELETE_NEG:%d" % (1 if "지우지 않" in para_text else 0))
# override 조건 자체의 극성 — 문단 전체가 「override 다」쪽으로 조건을 뒤집어도
# 위 네 토큰 존재 검사는 전부 그대로 만족된다(토큰은 안 지웠다). 조건절의 긍정형을
# 리터럴로 고정하고, 그 부정형 표지가 섞여 있지 않은지 별도로 잰다.
print("PARA_OVERRIDE_POSITIVE:%d" % (1 if "override(`branch` · `--paths` · `range`)면" in para_text else 0))
print("PARA_OVERRIDE_NEGATED:%d" % (1 if ("가 없으면" in para_text or "가 없을 때" in para_text) else 0))
PY

case_trivia_escape_is_gated_by_declaration() {
  # Review Focus 2 · R-AO — 선언이 있으면 trivia escape 를 쓰지 않는다.
  local got; got=$(python3 -c "$PY_TRIVIA" "$SKILL")
  assert_grep "$got" '^DETECT:1$'         "Trivia escape 절에 detect 호출 펜스가 하나"
  assert_grep "$got" '^DETECT_FIRST:1$'   "detect 가 trivia 판단(「작은 수정이라 파이프라인을 건너뛰었다」)보다 먼저 나온다"
  assert_grep "$got" '^SKIP_LINE:1$'      "ok · declaration-invalid 면 trivia escape 를 쓰지 않고 곧장 iteration 1 로 간다(같은 줄, 긍정 목적지 단언)"
  assert_grep "$got" '^NODECL_VIOLATION:0$' "Trivia 절 전체에서 no-declaration 과 trivia escape 를 쓰지 않음이 한 줄에 함께 나오지 않는다"
}

case_step1_writes_scope_file() {
  # R-AJ — ① 1a 가 매 iteration topic-head.sh 출력을 고정 경로에 쓴다. 산문으로 옮기면
  # 실행되지 않으므로 bash 펜스 «안»의 줄만 센다. 줄 전체를 fullmatch 로 잰다 — 부분
  # 문자열 락은 꼬리에 `|| true` 를 붙여 실패를 삼키는 변이를 못 잡는다.
  # 경로는 리포 루트 기준이다 — cwd 상대면 하위 디렉토리 cwd 에서 리다이렉트가 먼저 만든
  # 빈 파일이 봉인에 섞여 차등 절차 D1 의 재도출 대조가 매번 어긋난다(test_topic_head.sh
  # case_scope_file_under_subdir_cwd 가 그 동작을 잰다).
  local got; got=$(python3 -c "$PY_1A" "$SKILL")
  assert_grep "$got" '^FENCES:1$'   "① 1a: topic-head.sh 를 부르는 bash 펜스가 정확히 하나"
  assert_grep "$got" '^TH_LINES:1$' "① 1a 펜스에 topic-head.sh 출력을 쓰는 줄이 정확히 하나"
  assert_grep "$got" '^TH_EXACT:1$' "① 1a: topic-head.sh 출력을 \"\$S\" 에 쓰고 && 로 그대로 cat 한다(줄 전체 fullmatch, || true 로 삼키지 않는다)"
  assert_grep "$got" '^S_EXACT:1$'  "① 1a: 그 줄 앞의 «마지막» S 대입이 리포 루트 경로 + mkdir -p 한 줄이다(줄 전체 fullmatch)"
  local stale
  stale=$(grep -hF '".claude/quality-gates/<session-id>/topic-scope.txt"' "$SKILL" "$REF")
  assert_eq "$(printf '%s' "$stale" | grep -c .)" "0" "SKILL · 레퍼런스에 cwd 상대 스코프 파일 경로(\".claude/…/topic-scope.txt\")가 남지 않는다"
  assert_eq "$(grep -cF '"$(git rev-parse --show-toplevel)/.claude/quality-gates/<session-id>/topic-scope.txt"' "$SKILL")" "3" \
    "SKILL 의 세 자리(1a · override 정리 · Step 4 --scope)가 리포 루트 경로를 쓴다(부재 락의 양의 짝 — 1c 가 넘기는 자리는 case_topic_diff_comes_from_review_diff 가 잰다)"
}

case_status_table_is_total_over_statuses() {
  # R-AK — 상태 표가 scope_tuple.STATUSES 전부를 받고, ok 만 topic 이다.
  local got; got=$(python3 -c "$PY_STATUS" "$SKILL" "$PLUGIN_ROOT/scripts")
  assert_grep "$got" '^MISSING:$' "상태 표가 STATUSES 여덟 전부를 정확히 한 행씩 받는다"
  assert_grep "$got" '^WRONG:$'   "ok 행만 **topic**, 나머지는 session"
}

case_topic_diff_comes_from_review_diff() {
  # ② · ③ 이 같은 트리를 본다 — topic 스코프의 파일 집합 · diff 는 Step 1c 의 review-diff.sh 가
  # 스코프 파일의 boundary · tree 에서 만든다(그 읽기는 test_review_diff.sh 의
  # case_topic_uses_boundary_tree 가 잰다). SKILL 의 의무는 1a 가 쓴 리포 루트 스코프 파일을
  # review-diff 에 넘기는 것 하나다. 모델이 boundary · tree 로 git diff 를 손으로 짜던 줄은 없다.
  local s1 fence rows
  s1=$(awk '/^### Step 1 — scope$/{f=1;next} f&&/^### Step 1b/{exit} f' "$SKILL")
  [ -n "$s1" ] && ok "Step 1 창을 찾았다" || no "Step 1 창이 없다 — 아래가 공허하다"
  rows=$(printf '%s\n' "$s1" | grep -F -- '--mode topic --scope-file "$RD/topic-scope.txt"')
  assert_eq "$(printf '%s\n' "$rows" | grep -c .)" "1" "1c: topic 스코프는 review-diff 에 스코프 파일(\$RD/topic-scope.txt)을 넘긴다(한 줄)"
  fence=$(printf '%s\n' "$s1" | awk '/^[[:space:]]*```bash[[:space:]]*$/{f=1;b="";next} f&&/^[[:space:]]*```[[:space:]]*$/{if(b ~ /review-diff\.sh/) printf "%s", b; f=0; next} f{b=b $0 "\n"}')
  [ -n "$fence" ] && ok "1c 펜스(review-diff.sh 를 부르는 bash 펜스)를 찾았다" || no "1c 펜스가 없다"
  assert_grep "$fence" '^[[:space:]]*TOP="\$\(git rev-parse --show-toplevel\)"' "1c 펜스가 TOP 을 리포 최상위에서 얻는다"
  assert_grep "$fence" '^[[:space:]]*RD="\$\{TOP\}/\.claude/quality-gates/<session-id>"$' "1c 펜스의 RD 가 리포 루트 세션 폴더다 — 1a 가 쓴 스코프 파일과 같은 자리"
  assert_eq "$(grep -cF 'git diff --name-only "$b" "$t"' "$SKILL")" "0" "boundary · tree 로 파일 집합을 손으로 뽑던 줄이 없다"
  assert_eq "$(grep -cF 'git diff "$b" "$t"' "$SKILL")" "0" "boundary · tree 로 diff 를 손으로 뽑던 문장이 없다"
}

case_step4_row_carries_scope() {
  # R-AL — 두 사유와 scope: 블록은 합성기가 이 파일에서 낸다. SKILL 의 의무는 싣는 것 하나.
  local rows
  rows=$(grep -F -- '--scope "$(git rev-parse --show-toplevel)/.claude/quality-gates/<session-id>/topic-scope.txt"' "$SKILL")
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
  fs=$(awk '/^## Final verdict$/{f=1;next} f&&/^## /{exit} f' "$SKILL" | grep -F -- "$fs_needle")
  assert_eq "$(printf '%s\n' "$fs" | grep -c .)" "1" "Final verdict 가 scope: · angles: 블록을 이 순서로 verbatim 싣는다(한 줄, 리터럴)"
}

case_filtered_diff_is_review_diff_file() {
  # 리뷰어가 받는 diff(FILTERED_DIFF)는 모든 스코프에서 1c 가 쓴 $RD/review-i<N>.diff 다 —
  # topic 스코프에서 session 베이스라인(MERGE_BASE · HEAD)으로 새던 결함의 자리는 이제 스크립트다.
  # 정의하는 줄 = FILTERED_DIFF 를 말하되 슬롯(${FILTERED_DIFF})으로 채워 넣는 줄이 아닌 것.
  # ∀ 정의 줄이 review-i<N>.diff 를 출처로 대고, 두 정의(1c · Step 3)가 리터럴 그대로 있다.
  local all defs bad
  all=$(grep -F 'FILTERED_DIFF' "$SKILL")
  defs=$(printf '%s\n' "$all" | grep -vF '${FILTERED_DIFF}')
  assert_eq "$(printf '%s\n' "$defs" | grep -c .)" "2" "FILTERED_DIFF 를 정의하는 줄이 둘(1c · Step 3)"
  bad=$(printf '%s\n' "$defs" | grep -vF 'review-i<N>.diff')
  assert_eq "$(printf '%s' "$bad" | grep -c .)" "0" "FILTERED_DIFF 를 정의하는 줄 ∀ 가 review-i<N>.diff 를 출처로 댄다"
  assert_contains "$defs" '리뷰어가 받는 diff(`FILTERED_DIFF`)는 `$RD/review-i<N>.diff` 의 내용이다' "1c 의 정의(리터럴)"
  assert_contains "$defs" '- `FILTERED_DIFF` = the content of `${TOP}/.claude/quality-gates/<session-id>/review-i<N>.diff` that Step 1c wrote for this iteration' \
    "Step 3 의 정의(리터럴)"
  assert_not_grep "$all" 'MERGE_BASE|git (diff|show|log|format-patch)' \
    "FILTERED_DIFF 를 말하는 줄이 손으로 짠 git diff · git show · git log -p · session 베이스라인을 쓰지 않는다"
}

case_override_clears_stale_scope_file() {
  # I1 수정 — override 는 이번 iteration 에 1a 를 돌리지 않으므로, 남아 있을 수 있는 이전
  # 스코프 파일을 지운다. 파일 부재는 차등 절차 D0 · D1 에서 session 스코프로 간다([ -f "$S" ]
  # 가 거짓이라 status==ok 를 만족 못한다). rm 줄이 1a(기본 모드) 쪽에
  # 있으면(mutation) 그 펜스 바로 위 문단에 override · branch · --paths 가 함께 없다.
  local got; got=$(python3 -c "$PY_RM" "$SKILL")
  assert_grep "$got" '^RM_FENCES:1$'       "스코프 파일을 지우는 rm -f 줄을 담은 펜스가 정확히 하나"
  assert_grep "$got" '^PARA_OVERRIDE:1$'   "그 펜스 바로 위 문단이 override 를 언급한다"
  assert_grep "$got" '^PARA_BRANCH:1$'     "그 문단이 branch 를 언급한다"
  assert_grep "$got" '^PARA_PATHS:1$'      "그 문단이 --paths 를 언급한다"
  assert_grep "$got" '^PARA_DELETE_POS:1$' "그 문단이 삭제를 긍정형(지운다)으로 적는다"
  assert_grep "$got" '^PARA_DELETE_NEG:0$' "그 문단에 삭제 부정형(지우지 않)이 섞여 있지 않다"
  assert_grep "$got" '^PARA_OVERRIDE_POSITIVE:1$' "override 조건절이 긍정형(override(...)면)이다"
  assert_grep "$got" '^PARA_OVERRIDE_NEGATED:0$'  "override 조건절에 부정형(가 없으면 · 가 없을 때)이 섞여 있지 않다"
}

case_in_base_notice() {
  # AC4 재정의 — 머지된 앞 조각이 토픽 구성원에서 빠졌고 형제와 그 조각을 품은 구성원이 함께 있으면 그 변경이 diff 에 다시 보인다는 사실을 ① 1a 가 공지한다(같은 줄).
  # 1a 창(「**1a — 토픽 선언」 ~ 「**session 스코프**」) 안에서만 찾는다 — 다른 절로 옮기면 RED.
  # 끝 마커 자체의 실재를 별도로 잰다(PR4d 닫기 #19) — 마커를 개명(예: "**session scope**")하면
  # awk 의 종료 조건이 다시는 안 걸려 창이 파일 끝까지 넓어지고, 옮겨진 공지 줄이 그 넓은
  # 창 안에서 «다시» 걸려 뒤집기를 못 잡는다. 마커가 정확히 한 번 리터럴로 있어야 창이 닫힌다.
  assert_eq "$(grep -c -F '**session 스코프**' "$SKILL")" "1" "1a 창의 끝 마커가 SKILL 에 정확히 한 번 리터럴로 있다(양의 짝 — 없으면 창이 파일 끝까지 새는 것을 못 잡는다)"
  local win got
  win=$(awk '/\*\*1a — 토픽 선언/{f=1} /\*\*session 스코프\*\*/{f=0} f' "$SKILL")
  got=$(printf '%s\n' "$win" | grep -F '`in_base:`' | grep -F '토픽 구성원에서 빠졌다' | grep -F '이번 diff 에 다시 보인다')
  assert_eq "$(printf '%s\n' "$got" | grep -c .)" "1" "① 1a 창에 in_base 공지가 한 줄 있다"
  assert_grep "$got" '^[[:space:]]*`status: ok` 이고 파일의 `in_base:` 가 0 보다 크면 공지 한 줄: `> \[quality-gates\] 토픽 ' \
    "조건(status ok · in_base > 0)과 목적지(공지 한 줄: …)가 같은 줄의 긍정형이다"
  assert_not_grep "$got" '않|말 것|생략|아니고' "그 줄에 부정 · 반전 토큰이 없다(「토픽 구성원에서 빠졌다」는 위에서 따로 잰다)"
  # 줄 전체 끝 앵커(PR4d 닫기 #20) — 위 긍정형 단언은 접두만 고정해, 닫는 백틱 뒤에 꼬리를
  # 덧붙이는 변이(부정 토큰 없이)를 못 잡는다. 문장이 그 백틱에서 «끝난다»를 별도로 잰다.
  assert_grep "$got" '이번 diff 에 다시 보인다\.`$' "그 문장이 닫는 백틱 직후에 끝난다(줄 끝 앵커 — 백틱 뒤 덧붙임을 잡는다)"
  assert_eq "$(printf '%s\n' "$got" | grep -c -F '`> [quality-gates] 토픽 <topic_key> 의 선언 커밋 <in_base>개는 이미 base 에 있어 토픽 구성원에서 빠졌다 — 그 머지 전에 갈라져 base 를 아직 안 들인 형제 구성원이 그 조각을 품은 구성원과 함께 있으면 그 변경이 이번 diff 에 다시 보인다.`')" "1" "공지 문장 전체가 글자 그대로다(조건절의 양보 · 한정 삭제 · 「형제」 치환 · 자리표시 · 수량 표현을 잡는다)"
  assert_not_grep "$win" '기준선에 포함' "① 1a 창에 「기준선에 포함」이 없다 — 형제 토폴로지에서는 그 조각이 경계 트리에 없다(설계 §6.2.2 2)"
  assert_not_grep "$win" '자기 PR 에서 판정' "① 1a 창에 「자기 PR 에서 판정」이 없다 — qg 는 앞 조각이 /quality-gates:quality-pipeline 으로 판정됐는지 확인하지 못한다"
  assert_not_grep "$win" '판정 대상에서 빠졌다' "① 1a 창에 「판정 대상에서 빠졌다」가 없다 — 그 머지 전에 갈라진 형제와 그 조각을 품은 구성원이 함께 있으면 그 변경이 리뷰 diff 와 차등 테스트에 다시 든다(설계 §6.2.2 2)"
}

for c in case_trivia_escape_is_gated_by_declaration case_step1_writes_scope_file \
         case_status_table_is_total_over_statuses case_topic_diff_comes_from_review_diff \
         case_step4_row_carries_scope case_scope_block_surfaces \
         case_filtered_diff_is_review_diff_file \
         case_override_clears_stale_scope_file case_in_base_notice \
; do
  echo "== $c"; $c
done
finish
