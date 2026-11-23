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

finish
