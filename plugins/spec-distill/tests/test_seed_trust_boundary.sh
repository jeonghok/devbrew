#!/usr/bin/env bash
# seed 신뢰 경계 — 사용자 · 리포 · 모델이 심을 수 있는 입력(seed 본문 · audit 본문 · «사용자가 적은 말» ·
# 붙여 넣은 마크다운)이 게이트(check_seed.py)나 출처 판정(seed_provenance.py · seed_review_log.py)을
# 속이지 못한다. 축마다 우회 픽스처 → 막힘, 양성 대조 → 통과. 막힘은 «그 검사의 이름»으로 잰다 —
# 다른 검사가 우연히 rc 1 을 내서 통과하는 일을 막는다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
S="$ROOT/plugins/spec-distill/scripts"
TMP="$(mktemp -d -t sd-trust-XXXXXX)" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
trap 'rm -rf "$TMP"' EXIT

# 픽스처 쓰기 — 둘째 인자를 그대로 쓰되 `\uXXXX` 만 그 글자로 바꾼다(한글은 글자 그대로 적는다).
w() {
  python3 -I -X utf8 -c 'import re, sys
s = re.sub(r"\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1), 16)), sys.argv[2])
open(sys.argv[1], "w", encoding="utf-8").write(s)' "$1" "$2"
}
# j <json> <식> — 식은 이 파일이 쓴 고정 문자열뿐이다(입력 데이터가 식이 되지 않는다).
j() { python3 -I -X utf8 -c 'import json, sys; d = json.load(open(sys.argv[1], encoding="utf-8")); print(eval(sys.argv[2]))' "$1" "$2" 2>/dev/null; }

# ══ S2 — check_seed.py: seed 본문 부재 검사 셋 ════════════════════════════════
GOOD_AUDIT='---
type: interview-seed-audit
---

## 1. 원문

로그인이 가끔 실패한다.

## 2. 질문 전체

## 3. 긴 초안

긴 초안.

## seed 에서 덜어 낸 것

없음

## 4. 비평과 냉독

## 5. degrade

## 6. 리뷰 결정
'
w "$TMP/good.audit.md" "$GOOD_AUDIT"
SEED_HEAD='---
type: interview-seed
---

로그인이 가끔 실패한다.

'
gate() { python3 "$S/check_seed.py" gate "$1" "$2" >/dev/null 2>"$TMP/gate.err"; }
# blocked <검사 이름> <라벨> <seed 꼬리>
blocked() {
  w "$TMP/case.md" "${SEED_HEAD}$3"
  gate "$TMP/case.md" "$TMP/good.audit.md"; local rc=$?
  if [ "$rc" -eq 1 ] && grep -qF "[check_seed] $1:" "$TMP/gate.err"; then ok "$2 — 막힌다($1)"
  else no "$2 — 통과했다(rc=$rc, stderr: $(tr '\n' ' ' < "$TMP/gate.err" | head -c 200))"; fi
}
passes() {
  w "$TMP/case.md" "${SEED_HEAD}$2"
  gate "$TMP/case.md" "$TMP/good.audit.md"; local rc=$?
  if [ "$rc" -eq 0 ]; then ok "$1 — 통과한다(양성 대조)"
  else no "$1 — 막혔다(rc=$rc, stderr: $(tr '\n' ' ' < "$TMP/gate.err" | head -c 200))"; fi
}

passes "깨끗한 seed" ''

# ── 답-슬롯 헤딩
blocked "답-슬롯 헤딩" "heading: # 하나" '# 미해결 질문

- 어디서 재현되나?'
blocked "답-슬롯 헤딩" "heading: 들여쓰기 3칸" '   ## Open Questions'
blocked "답-슬롯 헤딩" "heading: 전각 ＃" '＃＃ 대안'
blocked "답-슬롯 헤딩" "heading: setext ---" 'Open Questions
---'
blocked "답-슬롯 헤딩" "heading: setext ===" '대안
==='
blocked "답-슬롯 헤딩" "heading: 전각 라틴" '## Ａｌｔｅｒｎａｔｉｖｅｓ'
blocked "답-슬롯 헤딩" "heading: 제로폭(U+200B)이 낀 낱말" '## 대​안'
blocked "답-슬롯 헤딩" "heading: 제로폭(U+200D)이 낀 라틴" '## Rej‍ected'
blocked "답-슬롯 헤딩" "heading: 번호 붙은 제목" '## 3. 대안'
blocked "답-슬롯 헤딩" "heading: 소문자" '## open questions'
blocked "답-슬롯 헤딩" "heading: 펜스 안도 금지(seed 는 코드 예시가 아니다)" '```
## 대안
```'
blocked "답-슬롯 헤딩" "heading: # 뒤 공백 없음" '##대안'
blocked "답-슬롯 헤딩" "heading: U+2028 뒤의 줄" '앞 글 ## 대안'
passes "heading 양성: 문장 안의 낱말" '대안을 찾는 것이 목표다.'
passes "heading 양성: 금지 낱말이 아닌 제목" '## 배경'
passes "heading 양성: 빈 줄 뒤의 --- 는 setext 가 아니다" '대안은 아직 없다.

---

끝.'

# ── 태그
blocked "태그" "tag: 대문자" '[OPEN: 정하지 않음]'
blocked "태그" "tag: 콜론 앞 공백" '[Open : 정하지 않음]'
blocked "태그" "tag: 전각 괄호" '［open: 정하지 않음］'
blocked "태그" "tag: 전각 콜론" '[open： 정하지 않음]'
blocked "태그" "tag: 제로폭이 낀 낱말" '[op​en: 정하지 않음]'
blocked "태그" "tag: 괄호 뒤 공백" '[ 추론 : 정하지 않음]'
passes "tag 양성: 콜론 없는 꺾쇠 낱말" '[참고] 이것은 문장이다.'

# ── URL
blocked "URL" "url: 대문자 스킴" 'HTTPS://example.com'
blocked "URL" "url: 전각 스킴" 'ｈｔｔｐｓ://example.com'
blocked "URL" "url: 제로폭이 낀 스킴" 'ht​tps://example.com'
blocked "URL" "url: 다른 스킴" 'ftp://example.com/x'
blocked "URL" "url: 스킴 없는 www." 'www.example.com 에 있다.'
blocked "URL" "url: 마크다운 인라인 링크" '[자료](example.com) 를 본다.'
blocked "URL" "url: 마크다운 참조 정의" '[자료]: example.com'
passes "url 양성: 점이 든 낱말" '버전은 v1.2.3 이고 파일은 check_seed.py 다.'

# ══ S2 — check_seed.py: audit 절 찾기 ═══════════════════════════════════════
w "$TMP/seed.md" "${SEED_HEAD}"
# audit_case <라벨> <기대 rc> <stderr 에 있어야 할 글자(rc 1 일 때)> <audit 본문>
audit_case() {
  w "$TMP/case.audit.md" "$4"
  gate "$TMP/seed.md" "$TMP/case.audit.md"; local rc=$?
  if [ "$2" = "0" ]; then
    [ "$rc" -eq 0 ] && ok "$1 — 통과한다(양성 대조)" \
      || no "$1 — 막혔다(rc=$rc, stderr: $(tr '\n' ' ' < "$TMP/gate.err" | head -c 200))"
  else
    { [ "$rc" -eq 1 ] && grep -qF "$3" "$TMP/gate.err"; } && ok "$1 — 막힌다" \
      || no "$1 — 통과했다(rc=$rc, stderr: $(tr '\n' ' ' < "$TMP/gate.err" | head -c 200))"
  fi
}
A_HEAD='---
type: interview-seed-audit
---

'
A_TAIL='
## 4. 비평과 냉독

## 5. degrade

## 6. 리뷰 결정
'
audit_case "audit 양성: 템플릿 모양" 0 "" "$GOOD_AUDIT"
audit_case "audit 양성: ## 1 안의 템플릿 밖 제목(붙여 넣은 마크다운)" 0 "" "${A_HEAD}## 1. 원문

## 배경

로그인이 가끔 실패한다.

## 2. 질문 전체

## 3. 긴 초안

## seed 에서 덜어 낸 것

없음
${A_TAIL}"
audit_case "audit: 펜스 안에 심은 덜어 낸 것 절" 1 "덜어 낸 것" "${A_HEAD}## 1. 원문

로그인이 가끔 실패한다.

## 2. 질문 전체

## 3. 긴 초안

\`\`\`
## seed 에서 덜어 낸 것

없음
\`\`\`
${A_TAIL}"
audit_case "audit: 4칸 들여 쓴(코드 블록) 덜어 낸 것 절" 1 "덜어 낸 것" "${A_HEAD}## 1. 원문

로그인이 가끔 실패한다.

## 2. 질문 전체

## 3. 긴 초안

    ## seed 에서 덜어 낸 것

    없음
${A_TAIL}"
audit_case "audit: U+2028 로 이은 덜어 낸 것 절" 1 "덜어 낸 것" "${A_HEAD}## 1. 원문

로그인이 가끔 실패한다.

## 2. 질문 전체

## 3. 긴 초안

본문 ## seed 에서 덜어 낸 것 없음
${A_TAIL}"
audit_case "audit: ## 1 에 심은 덜어 낸 것 절(제목 중복)" 1 "겹친다" "${A_HEAD}## 1. 원문

로그인이 가끔 실패한다.

## seed 에서 덜어 낸 것

없음

## 2. 질문 전체

## 3. 긴 초안

## seed 에서 덜어 낸 것

| 항목 | 기준 | 원문 위치 | 되살림 |
|---|---|---|---|
${A_TAIL}"
audit_case "audit: 펜스 안에 심은 ## 1. 원문(진짜 절 없음)" 1 "원문" "${A_HEAD}## 2. 질문 전체

## 3. 긴 초안

\`\`\`
## 1. 원문

가짜 원문.
\`\`\`

## seed 에서 덜어 낸 것

없음
${A_TAIL}"
audit_case "audit: 머리 행에 NBSP 를 넣어 데이터 행으로 위장" 1 "표 행도" "${A_HEAD}## 1. 원문

로그인이 가끔 실패한다.

## 2. 질문 전체

## 3. 긴 초안

## seed 에서 덜어 낸 것

| 항목 | 기준 | 원문 위치 | 되살림 |
|---|---|---|---|
${A_TAIL}"
audit_case "audit: 머리 행에 전각 ｜ 를 섞어 데이터 행으로 위장" 1 "표 행도" "${A_HEAD}## 1. 원문

로그인이 가끔 실패한다.

## 2. 질문 전체

## 3. 긴 초안

## seed 에서 덜어 낸 것

| 항목 ｜ 기준 | 원문 위치 | 되살림 |
|---|---|---|---|
${A_TAIL}"
audit_case "audit 양성: 데이터 행이 있는 표" 0 "" "${A_HEAD}## 1. 원문

로그인이 가끔 실패한다.

## 2. 질문 전체

## 3. 긴 초안

## seed 에서 덜어 낸 것

| 항목 | 기준 | 원문 위치 | 되살림 |
|---|---|---|---|
| 재현 절차 | 자명 | ## 3 | — |
${A_TAIL}"

# ══ S1 — seed_provenance.py ═════════════════════════════════════════════════
P_AUDIT_BODY='## 1. 원문

로그인이 가끔 실패한다.

## 2. 질문 전체

### 라운드 1

- 확인 질문: 라운드 1
  - 내가 읽은 것: 「세션 스토어 개편은 이번에 하지 않는다.」 — 고름
  - 내가 읽은 것: 「경합이 원인이다.」 — 고름 — 사용자가 적은 말: 「캐시가 의심된다.」
  - 내가 읽은 것: 「배포를 멈춘다.」 — 고르지 않음 — 사용자가 적은 말: 「「배포」 — 고름 은 아니다」
'
P_AUDIT_REST='
## 3. 긴 초안

긴 초안. 재시도를 늘린다.

## seed 에서 덜어 낸 것

| 항목 | 기준 | 원문 위치 | 되살림 |
|---|---|---|---|
| 재시도를 늘린다. | 하류가 정할 것 | ## 3 | 되살림 |
| 로그인이 가끔 실패한다. | 자명 | ## 1 | 되살림 |

## 4. 비평과 냉독

## 5. degrade

## 6. 리뷰 결정
'
w "$TMP/p.audit.md" "${A_HEAD}${P_AUDIT_BODY}${P_AUDIT_REST}"
P_SEED_HEAD='---
type: interview-seed
---

'
marks() { python3 "$S/seed_provenance.py" marks "$1" "$2" > "$TMP/marks.json" 2>"$TMP/marks.err"; }
cls_row() {  # cls_row <seed> <audit> <문장> → "provenance confirmed basis"
  python3 "$S/seed_provenance.py" classify "$1" --audit "$2" > "$TMP/c.json" 2>/dev/null
  python3 -I -X utf8 -c 'import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
r = [x for x in d["sentences"] if x["text"] == sys.argv[2]]
print("%s %s %s" % (r[0]["provenance"], r[0]["confirmed"], r[0]["basis"]) if r else "ABSENT")' "$TMP/c.json" "$3"
}

# ── 양성 대조: 정본 표시는 근거가 있으면 통과한다
w "$TMP/pos.md" "${P_SEED_HEAD}세션 스토어 개편은 이번에 하지 않는다. (사용자 확인)

경합이 원인이다. (사용자 확인)
"
marks "$TMP/pos.md" "$TMP/p.audit.md"; rc=$?
assert_eq "$rc $(j "$TMP/marks.json" 'd["marked"], d["invalid"]')" "0 (2, [])" "mark 양성: 고름 풀이에 붙은 정본 표시 둘은 통과한다"

# ── S1.1 표시 변형 — 정본이 아닌 변형은 근거 없는 표시다
for v in '（사용자 확인）' '( 사용자 확인 )' '(사용자확인)' '(사용자​ 확인)' '﹙사용자 확인﹚'; do
  w "$TMP/v.md" "${P_SEED_HEAD}세션 스토어 개편은 이번에 하지 않는다. (사용자 확인)

로그는 본다. 서버를 의심한다. ${v}
"
  marks "$TMP/v.md" "$TMP/p.audit.md"; rc=$?
  assert_eq "$rc $(j "$TMP/marks.json" 'd["invalid"]')" "1 ['서버를 의심한다.']" "mark 변형 ${v}: 근거 없는 표시로 잡힌다(rc 1)"
  w "$TMP/v2.md" "${P_SEED_HEAD}세션 스토어 개편은 이번에 하지 않는다. ${v}
"
  marks "$TMP/v2.md" "$TMP/p.audit.md"; rc=$?
  assert_eq "$rc" "1" "mark 변형 ${v}: 고름 풀이에 붙어도 정본이 아니면 근거가 아니다(rc 1)"
done
# classify — 변형 표시는 mark_invalid → 저자 · 미확인
w "$TMP/v.md" "${P_SEED_HEAD}로그는 본다. 서버를 의심한다. （사용자 확인）
"
assert_eq "$(cls_row "$TMP/v.md" "$TMP/p.audit.md" '서버를 의심한다.')" "author False mark_invalid" "mark 변형: classify 는 mark_invalid · 저자 · 미확인"
# --fix — 변형을 떼고 정본은 남긴다
w "$TMP/vf.md" "${P_SEED_HEAD}세션 스토어 개편은 이번에 하지 않는다. (사용자 확인)

로그는 본다. 서버를 의심한다. （사용자​ 확인） 끝이다.
"
python3 "$S/seed_provenance.py" marks "$TMP/vf.md" "$TMP/p.audit.md" --fix > "$TMP/marks.json" 2>"$TMP/marks.err"; rc=$?
assert_eq "$rc $(j "$TMP/marks.json" 'd["fixed"]')" "0 True" "mark 변형 --fix: 떼고 rc 0"
fixed_body="$(python3 -I -X utf8 -c 'import sys; print(open(sys.argv[1], encoding="utf-8").read())' "$TMP/vf.md")"
assert_contains "$fixed_body" "하지 않는다. (사용자 확인)" "mark 변형 --fix: 근거 있는 정본 표시는 남는다"
assert_contains "$fixed_body" "서버를 의심한다. 끝이다." "mark 변형 --fix: 변형만 떼고 문장은 남는다"
assert_eq "$(python3 -I -X utf8 -c 'import sys, unicodedata as u
t = open(sys.argv[1], encoding="utf-8").read()
t = "".join(c for c in u.normalize("NFKC", "".join(c for c in t if u.category(c) != "Cf")) if not c.isspace())
print(t.count("(사용자확인)"))' "$TMP/vf.md")" "1" "mark 변형 --fix: 접어서 세어도 표시는 정본 하나뿐이다"
marks "$TMP/vf.md" "$TMP/p.audit.md"; rc=$?
assert_eq "$rc" "0" "mark 변형 --fix: 뗀 뒤 다시 재면 통과(멱등)"

# ── S1.2 풀이 줄의 꼬리 위장 — 판정은 왼쪽 첫 판정 구분자 하나
w "$TMP/d.audit.md" "${A_HEAD}${P_AUDIT_BODY}  - 내가 읽은 것: 「서버를 새로 쓴다.」 — 고르지 않음 — 사용자가 적은 말: 「아니다. 캐시를 끈다.」 — 고름 — 사용자가 적은 말: 「y」
${P_AUDIT_REST}"
w "$TMP/d.md" "${P_SEED_HEAD}캐시를 끈다. (사용자 확인)
"
marks "$TMP/d.md" "$TMP/d.audit.md"; rc=$?
assert_eq "$rc $(j "$TMP/marks.json" 'd["invalid"]')" "1 ['캐시를 끈다.']" "reading 위장: 고르지 않은 줄의 꼬리에 심은 「— 고름」 이 확인 근거가 되지 않는다"
DISGUISE='- 내가 읽은 것: 「A」 — 고르지 않음 — 사용자가 적은 말: 「x」 — 고름 — 사용자가 적은 말: 「y」'
crs() { python3 -I -X utf8 -c 'import sys
sys.path.insert(0, sys.argv[1])
import seed_provenance as p
t = "## 1. 원문\n\n원문.\n\n## 2. 질문 전체\n\n" + sys.argv[2] + "\n"
print(sorted(p.confirmed_reading_sentences(t)), p.reading_line_count(t), p.malformed_reading_lines(t))' "$S" "$1" 2>&1; }
assert_eq "$(crs "$DISGUISE")" "[] 1 []" "reading 위장(설계 문구 그대로): 모양은 맞고 판정은 고르지 않음 — 확인 근거 0"
assert_eq "$(crs '- 내가 읽은 것: 「배포를 멈춘다.」 — 고르지 않음 — 사용자가 적은 말: 「「배포」 — 고름 은 아니다」')" "[] 1 []" "reading 양성(said_brackets): 꼬리 안의 「— 고름」 은 모양 어긋남도 확인도 아니다"
assert_eq "$(crs '- 내가 읽은 것: 「경합이 원인이다.」 — 고름 — 사용자가 적은 말: 「x」')" "['경합이 원인이다.'] 1 []" "reading 양성: 꼬리 달린 고름 줄은 확인 근거다"
assert_eq "$(crs '- 내가 읽은 것: 「X.」 — 고름 Y」 — 고르지 않음')" "[] 0 [2]" "reading 엄격: 왼쪽 첫 판정 뒤에 꼬리 모양이 아닌 글자가 오면 모양 어긋남"
assert_eq "$(crs '- 내가 읽은 것: 「X.」 — 고름 — 덧붙임')" "[] 0 [2]" "reading 엄격: 판정 뒤 나머지는 비거나 정확히 꼬리 모양이어야 한다"
pr() { python3 -I -X utf8 -c 'import sys
sys.path.insert(0, sys.argv[1])
import seed_provenance as p
print(p.parse_reading_line(sys.argv[2]))' "$S" "$1" 2>&1; }
assert_eq "$(pr "$DISGUISE")" "('A', '고르지 않음', 'x」 — 고름 — 사용자가 적은 말: 「y')" "parse_reading_line: 위장 줄을 왼쪽 첫 판정으로 읽고 나머지는 적은 말이다"
assert_eq "$(pr '  - 내가 읽은 것: 「B.」 — 고름')" "('B.', '고름', None)" "parse_reading_line 양성: 꼬리 없는 줄"

finish
