#!/usr/bin/env bash
# R6 — 지휘자가 지난 답을 qg 에 넘기고 판 3 만 읽는다(skills/epic-conductor/references/qg-review.md). 정적 락이다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_qg_review_readable.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
DOC="$ROOT/plugins/spec-distill/skills/epic-conductor/references/qg-review.md"
if [ ! -f "$DOC" ]; then no "qg-review.md 가 없다"; finish; exit $?; fi
WHOLE="$(cat "$DOC")"

# part <머리 줄> — 그 머리 아래 본문. 펜스 밖에서 깊이가 같거나 얕은 머리를 만나면 끝난다.
part() {
  awk -v h="$1" '
    BEGIN { depth = index(h, " ") - 1 }
    /^```/ { infence = !infence }
    !infence && $0 == h { on = 1; next }
    on && !infence && /^#+ / && index($0, " ") - 1 <= depth { exit }
    on { print }
  ' "$DOC"
}
# n_of <글> <글자> — 겹치지 않게 센 수
n_of() { printf '%s\n' "$1" | grep -oF -- "$2" | wc -l | tr -d ' '; }
one()  { assert_eq "$(n_of "$1" "$2")" "1" "$3"; }
zero() { assert_eq "$(n_of "$1" "$2")" "0" "$3"; }
# fenced <글> <표지> — 표지 글자가 든 첫 펜스의 본문(펜스 줄은 빼고)
fenced() {
  printf '%s\n' "$1" | awk -v m="$2" '
    /^```/ { if (inside) { if (index(body, m)) { printf "%s", body; exit } inside = 0 } else { inside = 1; body = "" } next }
    inside { body = body $0 "\n" }'
}
# lead <글> <머리> — 줄 첫머리가 머리인 첫 줄(앞의 빈칸은 떼고 본다)
lead() { printf '%s\n' "$1" | awk -v p="$2" '{ s = $0; sub(/^ +/, "", s) } index(s, p) == 1 { print s; exit }'; }
# in_order <줄> <이름> <글자>... — 글자들이 그 줄에 이 차례로 있다
in_order() {
  line="$1"; name="$2"; shift 2
  verdict="$(awk -v l="$line" 'BEGIN { for (i = 1; i < ARGC; i++) { p = index(l, ARGV[i]); if (p == 0) { print "없음:" ARGV[i]; exit } if (p <= last) { print "차례:" ARGV[i]; exit } last = p } print "ok"; exit }' "$@")"
  if [ "$verdict" = "ok" ]; then ok "$name"; else no "$name (${verdict})"; fi
}

CALL="$(part '## 호출 줄')"
BEAT="$(part '### 한 박자')"
SENT="$(part '### 이미 보낸 것')"
SEND="$(part '### 보내는 글')"
BACK="$(part '## 돌아왔을 때')"
RET="$(part '## 되돌리기')"
ANS="$(part '### 이미 답한 것')"
WRONG="$(part '## 「잘못 골랐다」 의 행선')"
for pair in "호출 줄:$CALL" "한 박자:$BEAT" "이미 보낸 것:$SENT" "보내는 글:$SEND" "돌아왔을 때:$BACK" "되돌리기:$RET" "이미 답한 것:$ANS" "행선:$WRONG"; do
  [ -n "${pair#*:}" ] && ok "절 본문을 읽었다: ${pair%%:*}" || no "절 본문이 비었다 — 아래 단언이 공허하다: ${pair%%:*}"
done
SF="$(fenced "$SEND" '너는 qg 리뷰 담당자다')"
REPORT="$(lead "$SF" '마지막 보고:')"
LIST="$(lead "$SF" '지적 목록:')"
[ -n "$SF" ] && ok "보내는 글 펜스를 읽었다" || no "보내는 글 펜스가 없다 — 아래 단언이 공허하다"
[ -n "$REPORT" ] && ok "마지막 보고 줄을 읽었다" || no "마지막 보고 줄이 없다 — 아래 단언이 공허하다"
[ -n "$LIST" ] && ok "지적 목록 줄을 읽었다" || no "지적 목록 줄이 없다 — 아래 단언이 공허하다"

# call-line-answered (AC15) — 지휘자가 내는 호출 줄은 --answered 를 붙인 한 꼴
CALL_LINE='/quality-gates:quality-pipeline range <시작 커밋>..<끝 커밋> --origin <원문 파일의 레포 상대경로> --answered <「이미 답한 것」 파일의 절대경로>'
assert_eq "$(fenced "$CALL" 'quality-pipeline range')" "$CALL_LINE" "call-line-answered: 호출 줄 펜스가 --answered 를 붙인 그 한 줄뿐"
one "$CALL" "$CALL_LINE" "call-line-answered: 호출 줄 절에 그 줄이 한 번"
one "$WHOLE" 'quality-pipeline range' "call-line-answered: 파일 전체에서 quality-pipeline range 가 한 번(다른 꼴의 호출 줄이 없다)"

# old-qg-retry-once (AC8 · AC15 담당자 쪽) — 호출 줄 락과 따로 묶는다
RETRY='qg 가 `--answered` 를 모르는 인자라고 멈추면 그 인자와 값을 뺀 같은 줄로 한 번만 다시 부르고, 마지막 보고 첫머리에 「답 이어지기 없이 돌았다 — 깔린 quality-gates 가 `--answered` 를 모른다」 를 적는다.'
one "$SF" "$RETRY" "old-qg-retry-once: 보내는 글 펜스에 옛 qg 다시 부르기 문장이 한 번"
one "$WHOLE" "$RETRY" "old-qg-retry-once: 그 문장이 파일 전체에서 한 번(지휘자 쪽에 다른 꼴의 호출 지시가 없다)"
zero "$CALL" '인자와 값을 뺀' "old-qg-retry-once 음성: 호출 줄 절은 인자를 빼는 꼴을 싣지 않는다(양성 짝: 보내는 글의 다시 부르기 문장)"

# back-contract-3 (AC8)
one "$BACK" '`contract` 가 `3` 이 아니면' "back-contract-3: 돌아왔을 때가 판 3 만 읽는다"
zero "$WHOLE" '`contract` 가 `2` 가 아니면' "back-contract-3 음성: 판 2 만 읽던 옛 검사가 없다(양성 짝: 판 3 검사)"
one "$BACK" '결과 파일의 판(<값>)을 읽지 못한다' "back-contract-3: 판이 다르면 읽지 못한다는 줄을 보인다"

# answered-script-order (AC13 지휘 쪽) — 보관 폴더 → 「이미 답한 것」 파일 → 보내기
ORDER="$(lead "$BEAT" '보내는 차례는 ')"
in_order "$ORDER" "answered-script-order: 한 박자의 차례가 보관 폴더 → 「이미 답한 것」 파일 → 보내기" \
  '보관 폴더 만들기와 `## 자원` 에 적기' '「이미 답한 것」 파일 만들기' '→ 보내기 →'
one "$ORDER" '「이미 답한 것」 파일 만들기' "answered-script-order: 차례 문장에 「이미 답한 것」 파일 만들기 한 번"
assert_eq "$(grep -cxF '### 이미 답한 것' "$DOC")" "1" "answered-script-order: ### 이미 답한 것 머리가 한 번"
one "$ANS" 'qg_answered.py --roadmap <로드맵> --ref origin/HEAD' "answered-script-order: 스크립트를 기본 브랜치 ref 부터 부른다"
one "$ANS" '--out <보관 폴더>/qg-answered.yaml --notices <보관 폴더>/qg-answered-notices.txt' "answered-script-order: 출력과 알림 파일이 보관 폴더에"
PLACES="$(lead "$ANS" '- 읽는 자리')"
in_order "$PLACES" "answered-script-order: 읽는 자리 셋이 기본 브랜치 → 기록 브랜치 → 에픽 브랜치 차례" \
  '`origin/HEAD`(기본 브랜치)' '`origin/<기록 브랜치>`' '열린 에픽 브랜치마다 로컬 `<에픽 브랜치>`'
CMDLINE="$(lead "$ANS" '- 부르는 꼴:')"
in_order "$CMDLINE" "answered-script-order: 부르는 꼴의 --ref 도 같은 차례" \
  '--ref origin/HEAD' '--ref origin/<기록 브랜치>' '--ref <에픽 브랜치>'
zero "$WHOLE" 'origin/<에픽 브랜치>' "answered-script-order 음성: push 되지 않은 에픽 브랜치 기록을 origin 으로 읽지 않는다(양성 짝: 로컬 <에픽 브랜치>)"
one "$ANS" '- rc 가 2 면 부른 꼴이 틀린 것이다 — 스크립트가 낸 stderr 줄을 보이고, 부른 꼴을 고쳐 다시 부른다.' "answered-script-order: rc 2 면 부른 꼴을 고쳐 다시 부른다"
one "$ANS" '- rc 가 3 이면 파일을 쓰지 못한 것이다 — 그 stderr 줄을 보이고 그대로 보낸다(qg 가 「넘겨받은 답을 읽지 못함 — 없음」 으로 알린다).' "answered-script-order: rc 3 이면 stderr 줄을 보이고 그대로 보낸다"
one "$SENT" '(아래 `### 이미 답한 것` 의 읽는 자리 셋)' "answered-script-order: 이미 보낸 것 1 이 이미 답한 것의 읽는 자리 셋을 가리킨다"

# self-filter-gone (AC15) — 거르는 곳은 qg 한 곳
SELF='지휘자는 스스로 거르지 않는다 — 거르는 곳은 qg 한 곳이다.'
one "$WHOLE" "$SELF" "self-filter-gone: 파일에 「지휘자는 스스로 거르지 않는다」 문장이 한 번"
one "$ANS" "$SELF" "self-filter-gone: 그 문장이 ### 이미 답한 것 에"
zero "$WHOLE" '같은 대상에 전에 물은 것이 있어도 질문은 띄운다' "self-filter-gone 음성: 「있어도 질문은 띄운다」 가 없다(양성 짝: 스스로 거르지 않는다 문장)"
zero "$WHOLE" '돌아온 질문은 거르지 않는다' "self-filter-gone 음성: 「돌아온 질문은 거르지 않는다」 가 없다(양성 짝: 스스로 거르지 않는다 문장)"
zero "$WHOLE" '### 같은 대상에 전에 물은 것' "self-filter-gone 음성: 손 절차 절 머리가 없다(양성 짝: ### 이미 답한 것 머리)"

# report-only-wrong-list (AC15)
one "$REPORT" '`이미 「잘못 골랐다」 답이 있어 거른 질문:`' "report-only-wrong-list: 마지막 보고에 「잘못 골랐다」 로 거른 목록"
zero "$SF" '`이미 답한 질문이라 거른 질문:`' "report-only-wrong-list 음성: 보내는 글이 「이미 답한 질문」 목록을 싣게 하지 않는다(양성 짝: 「잘못 골랐다」 목록)"
one "$WRONG" '- 담당자 보고에 `이미 「잘못 골랐다」 답이 있어 거른 질문:` 목록이 있으면 그 질문마다 「앞서 잘못 골랐다고 답한 것이 아직 그대로다」 로 보이고 같은 행선을 적용한다 — 새로 나온 「잘못 골랐다」 가 없어도 같다.' "report-only-wrong-list: 머지 앞 행선이 그 목록을 읽는다"

# pre-merge-file (AC21 · Q2 고치면 · Q3 세지 않는다)
COPY="$(lead "$SF" '끝내기 전에')"
assert_contains "$COPY" 'findings-pre-merge.yaml' "pre-merge-file: 합쳐지기 전 지적 목록 파일을 보관 폴더로 옮긴다"
assert_contains "$COPY" '<보관 폴더> 로 셸 복사한다' "pre-merge-file: 옮기는 길은 셸 복사"
for lit in '세션 폴더의 findings-pre-merge.yaml' '묶음(막는 지적 · 제안 · 낮춘 지적)' '쉬운 한 문장(`plain`, 없으면 `summary`)' \
           '막는 지적엔 고치는 법(`proposed_fix`)의 첫 문장' '낮춘 지적엔 원래 심각도(`lowered_from`)와 낮춘 이유(`lowered_reason`)의 첫 문장' \
           '새로 깨진 테스트는 result.md 의 `### 차등 회귀` 에서 「새로 깨진 테스트: <테스트 이름>」 으로' \
           '`lowered: true` 인 항목은 낮춘 지적 묶음에만 싣는다' \
           '세션 폴더에 그 파일이 없으면 qg 의 고칠 목록(result.md 의 `### 막는 지적` · `### 제안` · `## 낮춘 지적`)에서 싣고 마지막 보고 첫머리에 「합쳐지기 전 목록 없이 실었다 — 같은 줄의 지적이 하나로 합쳐졌을 수 있다」 를 적는다'; do
  one "$LIST" "$lit" "pre-merge-file: 지적 목록 줄에 ${lit}"
done
assert_contains "$REPORT" '위 지적 목록' "pre-merge-file: 마지막 보고가 위 지적 목록을 싣는다"
one "$RET" '지적마다의 처리는 합쳐지기 전 지적 목록 파일(`findings-pre-merge.yaml`)의 항목 하나를 단위로 센다' "pre-merge-file: 되돌리기가 합쳐지기 전 목록의 항목 하나를 단위로 센다"
one "$RET" '그 파일 없이 qg 의 고칠 목록에서 실었으면' "pre-merge-file(Q2): 파일 없이 실은 때를 가른다"
one "$RET" '그 목록의 행 하나를 단위로 센다' "pre-merge-file(Q2): 그때는 그 목록의 행 하나를 단위로 센다"
zero "$WHOLE" '합성 표가 합치기 전의 목록' "pre-merge-file 음성: 출처 없는 「합성 표가 합치기 전의 목록」 이 없다(양성 짝: findings-pre-merge.yaml 줄)"
zero "$WHOLE" '합성 표가 한 행으로 합친 지적은' "pre-merge-file 음성: 담당자가 합친 행을 풀어 세던 옛 문장이 없다(양성 짝: 항목 하나를 단위로 센다)"

# degrade-lines-verbatim (AC16 담당자 쪽)
one "$REPORT" 'qg 가 무엇이 빠지거나 줄어든 채 돌았다고 알린 줄(넘겨받은 답을 읽지 못함 · 리뷰어나 codex 가 돌지 못함 · 재비판이 돌지 못함 같은 줄)을 글자 그대로' "degrade-lines-verbatim: 마지막 보고가 빠진 채 돈 알림 줄을 글자 그대로 싣는다"

# asked-then-recheck (AC22)
one "$RET" '구현이 끝난 머지 전 에픽을 이름으로 청해 본 리뷰(`asked`)가 막는 지적을 내 되돌린 뒤의 좁은 재리뷰는 `recheck-pr<번호>` 로 보내고 그 PR 의 「두 번까지」 에 센다. 그 뒤 자동 머지 앞 리뷰는 `premerge-pr<번호>` 로 평소대로 한 번 보낸다 — 이름으로 청한 리뷰는 그 횟수에 세지 않는다.' "asked-then-recheck: 이름으로 청한 리뷰 뒤의 좁은 재리뷰와 자동 머지 앞 리뷰의 자리 글자"

# recheck-intent-answered (§5 지휘 절차에서 바뀌는 것)
RI="$(lead "$RET" '- **좁은 재리뷰의 의도 점검.**')"
[ -n "$RI" ] && ok "좁은 재리뷰의 의도 점검 불릿을 읽었다" || no "좁은 재리뷰의 의도 점검 불릿이 없다 — 아래 단언이 공허하다"
one "$RI" '호출 줄은 첫 리뷰와 같은 꼴이라(`--answered` 포함)' "recheck-intent-answered: 좁은 재리뷰도 --answered 를 붙인 같은 꼴"
one "$RI" '근거가 같으면 다시 묻지 않는다' "recheck-intent-answered: 같은 의심 · 의도다 · 근거가 같으면 다시 묻지 않는다"
zero "$WHOLE" '호출 줄에 인자를 더하지 않으므로' "recheck-intent-answered 음성: 인자를 더하지 않는다던 옛 문장이 없다(양성 짝: --answered 포함)"

# 화면의 틀(Task 13) — 맥락 머리 · 질문 블록 · 결과 글 · 기록 틀 3판
RES="$(part '### 결과 글')"
ASK="$(part '## 묻기')"
REC="$(part '### 기록 파일')"
for pair in "결과 글:$RES" "묻기:$ASK" "기록 파일:$REC"; do
  [ -n "${pair#*:}" ] && ok "절 본문을 읽었다: ${pair%%:*}" || no "절 본문이 비었다 — 아래 단언이 공허하다: ${pair%%:*}"
done
# next_line <글> <머리> — 줄 첫머리가 머리인 첫 줄의 바로 다음 줄(빈칸을 떼지 않는다)
next_line() { printf '%s\n' "$1" | awk -v p="$2" 'hit { print; exit } index($0, p) == 1 { hit = 1 }'; }
# heads <글> <머리> — 줄 첫머리가 머리인 줄의 수
heads() { printf '%s\n' "$1" | awk -v p="$2" 'index($0, p) == 1 { c++ } END { print c + 0 }'; }

# context-head (AC1)
HEAD4='<대상 이름> — <자리의 쉬운 이름> 리뷰
이 에픽이 하기로 한 것: <로드맵 에픽 블록의 의도 줄 그대로>
결과: <막는 지적 n개 · 제안 n개 · 낮춘 지적 n개 | 막는 지적 없음 · …>
물을 것: <n개 | 없음>[ · 전에 답해 묻지 않은 것 <m>개]'
CH="$(fenced "$RES" '<자리의 쉬운 이름> 리뷰')"
assert_eq "$CH" "$HEAD4" "context-head: 결과 글의 맥락 머리 펜스가 네 줄 그대로"
for i in 2 3 4; do
  case $i in 2) want='이 에픽이 하기로 한 것:' ;; 3) want='결과:' ;; 4) want='물을 것:' ;; esac
  got="$(printf '%s\n' "$CH" | awk -v n="$i" 'NR == n')"
  case "$got" in "$want"*) ok "context-head: ${i}째 줄이 ${want} 로 시작" ;; *) no "context-head: ${i}째 줄이 ${want} 로 시작하지 않는다(${got:-없음})" ;; esac
done
one "$WHOLE" '<대상 이름> — <자리의 쉬운 이름> 리뷰' "context-head: 맥락 머리 펜스가 파일에 한 번"
one "$ASK" '`### 결과 글` 의 맥락 머리 아래에' "context-head: 묻기의 질문 블록이 결과 글의 맥락 머리를 가리킨다"
one "$WHOLE" '로드맵 에픽 블록의 `- 의도:` 줄을 글자 그대로 옮긴다' "context-head: 의도 줄을 글자 그대로 옮긴다"
EASY="$(lead "$RES" '- **자리의 쉬운 이름**')"
in_order "$EASY" "context-head: 자리의 쉬운 이름 다섯이 한 불릿에" \
  '`spec` 은 「설계 승인 앞」' '`premerge` 는 「머지 앞」' '`recheck` 는 「머지 앞 — 고친 부분만」' '`end` 는 「로드맵 끝」' '`asked` 는 「이름으로 청함」'
one "$RES" '로드맵 리뷰면 머리 낱말을 「이 로드맵이 하기로 한 것」 으로 바꾸고' "context-head: 로드맵 리뷰의 머리 낱말"
one "$RES" '판정 줄의 수는 같은 줄의 지적을 합친 뒤의 수라 쓰지 않는다' "context-head: 결과 개수는 판정 줄 수가 아니다"
one "$RES" '「막는 지적 n개(새로 깨진 테스트 k개 포함)」' "context-head: 새로 깨진 테스트를 막는 지적 수에 넣는 꼴"

# question-block (AC2)
QBLOCK='질문 <n> — <질문 문장>
  왜 묻나: <why>
  <「여기는 직접 확인해 보세요 — …」 줄 — 질문 글에 그 표지가 있을 때만>

자세히: <기록 파일 또는 보관 파일의 경로>
답은 qg 판정을 바꾸지 않는다. 이유를 남기려면 직접 입력 칸에 「의도다 — 이유」 처럼 쓴다.'
assert_eq "$(fenced "$ASK" '왜 묻나: <why>')" "$QBLOCK" "question-block: 묻기의 질문 블록 펜스가 그대로"
one "$WHOLE" '질문 <n> — <질문 문장>' "question-block: 질문 블록 펜스가 파일에 한 번"
for rule in '- 왜 묻나 — 그 항목의 `why` 를 그대로 쓴다. `why` 가 `-` 면 `왜 묻나: 리뷰어가 적지 않았다` 로 쓴다 — 줄을 빼지 않는다.' \
            '`asked_before` 의 넷째 칸이 `근거가 달라짐` 일 때 `전에 「<답>」 라고 답하셨는데(<날짜>) 이번에는 <새로 보인 것> 가 보였다. ` 를,' \
            '`고친 뒤에도 보임` 일 때 `전에 「잘못 골랐다」 라고 답하셨다(<날짜>) — 고친 뒤에도 같은 의심이 보인다. ` 를 붙인다.'; do
  one "$ASK" "$rule" "question-block: 왜 묻나 규칙 — ${rule}"
done
one "$ASK" '`<답>` 은 `asked_before` 의 첫째 칸, `<날짜>` 는 둘째 칸을 있는 그대로 쓴다.' "question-block: 날짜는 asked_before 둘째 칸 그대로"
one "$ASK" '`<새로 보인 것>` 은 `changed_observation` 의 첫 항목이다 — 스크립트가 옮긴 글이고 짓거나 줄이지 않는다.' "question-block: 새로 보인 것은 changed_observation 첫 항목"
HIDE="$(lead "$ASK" '- 화면에 싣지 않는 것')"
in_order "$HIDE" "question-block: 화면에 싣지 않는 것 다섯이 한 불릿에" '의심하는 인용' '근거 줄' '근거의 종류' '정체' '전에 물은 것의 질문 글'
zero "$WHOLE" 'intent-critic 은 의도대로 만들었는지가 아니라' "question-block 음성: 옛 고정 문장 첫째가 없다(양성 짝: 질문 블록 끝 줄)"
one "$WHOLE" '이유를 남기려면 직접 입력 칸에' "question-block: 이유 남기는 안내가 파일에 한 번"
assert_eq "$(heads "$WHOLE" '이유를 남기려면')" "0" "question-block 음성: 이유 남기는 안내가 홀로 선 줄로 없다(양성 짝: 끝 줄)"
assert_eq "$(heads "$WHOLE" '답은 qg 판정을 바꾸지 않는다. 이유를 남기려면 직접 입력 칸에 「의도다 — 이유」 처럼 쓴다.')" "1" "question-block: 그 안내는 끝 줄 안에만"
one "$ASK" '`자세히` 줄의 경로는 기록 파일에 그 리뷰의 `## 질문` 절이 이미 있으면' "question-block: 자세히 경로는 기록 파일에 그 리뷰의 질문 절이 있을 때만 기록 파일"
one "$ASK" '머리만 먼저 커밋된 기록 파일은 이미 있는 기록 파일로 치지 않는다' "question-block: 머리만 커밋된 기록 파일은 치지 않는다"
zero "$WHOLE" '- 근거로 본 것(' "question-block 음성: 옛 앞 글 틀의 근거 줄이 없다(양성 짝: 질문 블록 펜스)"

# result-text (AC3)
RTEXT='<맥락 머리 네 줄>
다음: <지금 일어나는 일 한 문장>

막는 지적
1. <그 지적의 쉬운 한 문장> (<파일>)
   고치는 법: <고치는 법의 첫 문장>
제안
3. <그 지적의 쉬운 한 문장> (<파일>)
낮춘 지적
6. <그 지적의 쉬운 한 문장> (<파일>) — 원래 <심각도>, 낮춘 이유: <한 구절>
자세히: <보관 폴더의 result.md 경로>'
assert_eq "$(fenced "$RES" '다음: <지금 일어나는 일 한 문장>')" "$RTEXT" "result-text: 결과 글 펜스가 그대로"
one "$WHOLE" '다음: <지금 일어나는 일 한 문장>' "result-text: 결과 글 펜스가 파일에 한 번"
for lit in '번호는 세 묶음을 이어서 매긴다' '`plain` 칸이고, 그 칸이 없는 지적은 `summary` 칸이다' '「새로 깨진 테스트: <테스트 이름>」' \
           '낮춘 이유 한 구절은 `lowered_reason` 의 첫 문장' \
           '「막는 지적을 구현 담당자에게 돌려보냈다 — 고친 부분만 다시 본다」, 「막는 지적이 없어 머지 전 확인으로 간다」, 「아래 질문 2개를 먼저 묻는다」' \
           '낮춘 지적은 낮춘 지적 묶음에만 한 번 싣고 제안 묶음과 제안 수에는 세지 않는다' \
           '고칠 목록의 `### 제안` 에 든 `(lowered)` 줄도 제안으로 세지 않는다' \
           '지적도 질문도 없으면 맥락 머리 네 줄 · 「다음」 줄과 끝의 `자세히: <보관 폴더의 result.md 경로>` 한 줄이다' \
           '지적이 없고 질문만 있는 리뷰는 맥락 머리 뒤에 바로 `## 묻기` 의 질문 블록이 온다' \
           '한 메시지에 결과 글을 먼저, 질문 블록을 뒤에 싣는다 — 맥락 머리는 한 번만 쓴다'; do
  one "$RES" "$lit" "result-text: ${lit}"
done
one "$LIST" '그때 `### 제안` 의 `(lowered)` 줄은 제안 묶음에 싣지 않는다' "result-text(Q3): 고칠 목록에서 실을 때도 낮춘 줄을 제안 묶음에 싣지 않는다"
zero "$WHOLE" '낮춘 대로 뒀다 — 되올릴 것이 있으면 말한다' "result-text 음성: 옛 「낮춘 대로 뒀다」 문장이 없다(양성 짝: 번호는 세 묶음을 이어서 매긴다)"
zero "$WHOLE" '「낮춘 지적」 표를 빠짐없이' "result-text 음성: 옛 낮춘 지적 표가 없다(양성 짝: 결과 글 펜스)"
one "$RET" '- **낮춘 지적은 결과 글의 낮춘 지적 묶음에 보이고**(위 `### 결과 글`)' "result-text: 되돌리기가 결과 글의 낮춘 지적 묶음을 가리킨다"
one "$(part '### 보내기')" '화면의 꼴은 아래 `### 결과 글` 이다.' "result-text: 돌아오면 보이는 문단이 결과 글을 가리킨다"

# result-line-cases (AC4 · Q1)
one "$RES" '결과 줄 끝에 「 · 인증 못 함(<그 사유 글자 그대로>)」 를 붙인다' "result-line-cases: not-certified 면 인증 못 함"
one "$RES" '결과 줄 끝에 「 · 의도 점검은 셀 수 없음(<사유>)」 를 붙인다' "result-line-cases(Q1): 의도 점검만 읽지 못하면 개수 뒤에 붙인다"
one "$RES" '결과 파일을 옮기지 못함 · 판을 읽지 못함 · 보낸 범위의 것이 아님' "result-line-cases(Q1): 의도 점검만 읽지 못한 세 경우"
one "$RES" '결과 줄 전체를 「셀 수 없음 — <그 자리에서 지휘자가 보이는 사유 문장 그대로>」 로 쓰는 것은 담당자가 돌아오지 않은 리뷰' "result-line-cases(Q1): 결과 줄 전체 셀 수 없음은 담당자가 돌아오지 않은 리뷰뿐"
one "$RES" '두 경우 모두 「물을 것」 줄은 싣지 않는다' "result-line-cases: 두 경우 모두 물을 것 줄이 없다"

# filtered-count-and-notices (AC16)
one "$RES" '돌려주는 꼴의 `answered_filtered` 에서 오고 0 이면 붙지 않는다' "filtered-count-and-notices: 전에 답해 묻지 않은 것은 answered_filtered 에서"
one "$RES" '`qg-answered-notices.txt` 의 줄을 맥락 머리 바로 아래에 글자 그대로' "filtered-count-and-notices: 알림 파일의 줄을 맥락 머리 아래에"
one "$RES" '빠지거나 줄어든 채 돌았다고 알리는 줄도 같은 자리에' "filtered-count-and-notices: 빠진 채 돈 알림 줄도 같은 자리에"

# record-template-3 (AC17 · Q5)
TPL="$(fenced "$REC" 'type: roadmap-review')"
[ -n "$TPL" ] && ok "record-template-3: 기록 틀 펜스를 읽었다" || no "record-template-3: 기록 틀 펜스가 없다 — 아래 단언이 공허하다"
for k in 'contract: 3' '- 왜 묻나: <why>' '- 전에 한 답: <asked_before 그대로 | 없음>' '- 행선: <이 에픽 안에서 고친다 | 새 일의 씨앗 | 재분해 신호' \
         '- 달라진 관찰:' '- 질문: <question>' '- 답: <의도다 |' '- 답 원문: <직접 쓴 글 그대로 | ->'; do
  assert_eq "$(heads "$TPL" "$k")" "1" "record-template-3: 줄 첫머리 ${k} 가 한 번"
done
case "$(next_line "$TPL" '- 질문:')" in '- 왜 묻나:'*) ok "record-template-3: 왜 묻나 줄이 질문 줄 바로 다음" ;; *) no "record-template-3: 질문 줄 다음이 왜 묻나 줄이 아니다" ;; esac
case "$(next_line "$TPL" '- 전에 한 답:')" in '- 달라진 관찰:'*) ok "record-template-3(Q5): 달라진 관찰 줄이 전에 한 답 줄 바로 다음" ;; *) no "record-template-3(Q5): 전에 한 답 줄 다음이 달라진 관찰 줄이 아니다" ;; esac
case "$(next_line "$TPL" '- 달라진 관찰:')" in '  <changed_observation'*) ok "record-template-3(Q5): 달라진 관찰 아래 두 칸 들여 쓴 changed_observation 줄" ;; *) no "record-template-3(Q5): 달라진 관찰 아래에 두 칸 들여 쓴 changed_observation 줄이 없다" ;; esac
case "$(next_line "$TPL" '- 답:')" in '- 행선:'*) ok "record-template-3: 행선 줄이 답 줄 바로 다음" ;; *) no "record-template-3: 답 줄 다음이 행선 줄이 아니다" ;; esac
zero "$WHOLE" '- 같은 대상에 전에 물은 것:' "record-template-3 음성: 옛 「같은 대상에 전에 물은 것」 줄이 없다(양성 짝: 전에 한 답 줄)"
one "$REC" '`- 달라진 관찰:` 줄과 그 아래 두 칸 들여 쓴 줄은 근거가 달라져 다시 물은 질문' "record-template-3(Q5): 달라진 관찰은 근거가 달라져 다시 물은 질문에만"
one "$REC" '`- 질문:` · `- 답:` · `- 답 원문:` 줄의 이름과 자리 글자는 바꾸지 않는다' "record-template-3: 걸음 5 가 읽는 줄 이름은 그대로"
one "$REC" '2판 기록 파일(이 줄들이 없는 지난 기록)은 고치지 않는다 — `qg_answered.py` 가 그대로 읽는다' "record-template-3: 지난 2판 기록은 고치지 않고 qg_answered.py 가 읽는다"

# skill-show-line — SKILL.md ## 보이기 의 qg 문장
SKD="$ROOT/plugins/spec-distill/skills/epic-conductor/SKILL.md"
SHOW="$(awk '$0 == "## 보이기" { on = 1; next } on && /^## / { exit } on' "$SKD")"
[ -n "$SHOW" ] && ok "skill-show-line: SKILL.md 보이기 절을 읽었다" || no "skill-show-line: SKILL.md 보이기 절이 없다 — 아래 단언이 공허하다"
one "$SHOW" 'qg 담당자가 돌려준 리뷰 결과와 의도 점검 질문은 `references/qg-review.md` 의 `### 결과 글` · `## 묻기` 틀대로 맥락 머리로 시작하는 글로 보인 뒤 묻고, 질문 문장 앞머리에 에픽 이름(로드맵 리뷰면 「로드맵」)을 쓴다.' "skill-show-line: 보이기의 qg 문장이 맥락 머리로 시작하는 틀을 가리킨다"
zero "$SHOW" '따로 된 앞 글 뒤에 묻고' "skill-show-line 음성: 옛 앞 글 문장이 없다(양성 짝: 맥락 머리 문장)"

# deps-min-qg (AC8) — 의존 표의 quality-gates 최소 판이 quality-gates plugin.json 의 판이다(파일에서 읽어 견준다)
QGV="$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$ROOT/plugins/quality-gates/.claude-plugin/plugin.json" | head -1)"
QGROW="$(grep -F '| quality-gates | ' "$ROOT/plugins/spec-distill/dependencies.md" | head -1)"
QGMIN="$(printf '%s\n' "$QGROW" | awk -F'|' '{ gsub(/^ +| +$/, "", $3); print $3 }')"
[ -n "$QGV" ] && [ -n "$QGROW" ] && ok "deps-min-qg: 두 값을 읽었다" || no "deps-min-qg: 판 또는 표 행을 읽지 못했다 — 아래 단언이 공허하다"
assert_eq "$QGMIN" "$QGV" "deps-min-qg: dependencies.md 의 quality-gates 행 둘째 칸이 quality-gates plugin.json 의 판"

# readme-new-words (AC20) — spec-distill README 가 새 동작의 이름을 쓴다
RD="$(cat "$ROOT/plugins/spec-distill/README.md")"
assert_contains "$RD" 'qg_answered.py' "readme-new-words: qg_answered.py"
assert_contains "$RD" '맥락 머리' "readme-new-words: 맥락 머리"
assert_contains "$RD" 'quality-pipeline range <시작>..<끝> --origin <원문> --answered <절대경로>' "readme-new-words: README 의 qg 호출 줄이 --answered 를 붙인 꼴"

finish
