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
# 풀어 쓴 한글(NFD) 표시 — 글자마다 접으면 표시가 아니고 전체를 접으면 표시다. 자리를 정할 수 없으니 판단 거부.
python3 -I -X utf8 -c 'import sys, unicodedata
open(sys.argv[1], "w", encoding="utf-8").write("---\ntype: interview-seed\n---\n\n서버를 의심한다. "
    + unicodedata.normalize("NFD", "(사용자 확인)") + "\n")' "$TMP/nfd.md"
marks "$TMP/nfd.md" "$TMP/p.audit.md"; rc=$?
{ [ "$rc" -eq 2 ] && grep -qF "mark_ambiguous" "$TMP/marks.err"; } && ok "mark 변형(NFD): 표시 자리를 정할 수 없으면 판단을 거부한다(rc 2)" \
  || no "mark 변형(NFD): 풀어 쓴 표시가 rc=$rc 로 지나갔다"

# ══ S3 — 출처 재라벨 ═════════════════════════════════════════════════════════
# ── 되살림 · 덜어 낸 것 표 · 적은 말 꼬리는 «(사용자 확인)» 의 근거가 아니다
w "$TMP/r.md" "${P_SEED_HEAD}재시도를 늘린다. (사용자 확인)
"
marks "$TMP/r.md" "$TMP/p.audit.md"; rc=$?
assert_eq "$rc $(j "$TMP/marks.json" 'd["invalid"]')" "1 ['재시도를 늘린다.']" "promote: 되살림 행의 문장에 붙인 표시는 근거가 없다(rc 1)"
w "$TMP/r2.md" "${P_SEED_HEAD}캐시가 의심된다. (사용자 확인)
"
marks "$TMP/r2.md" "$TMP/p.audit.md"; rc=$?
assert_eq "$rc $(j "$TMP/marks.json" 'd["invalid"]')" "1 ['캐시가 의심된다.']" "promote: «사용자가 적은 말» 꼬리의 글자에 붙인 표시는 근거가 없다(rc 1)"
w "$TMP/r3.md" "${P_SEED_HEAD}재시도를 늘린다.

로그인이 가끔 실패한다.
"
assert_eq "$(cls_row "$TMP/r3.md" "$TMP/p.audit.md" '재시도를 늘린다.')" "author False none" "promote: ## 1 에 없는 되살린 문장은 저자 · 미확인"
assert_eq "$(cls_row "$TMP/r3.md" "$TMP/p.audit.md" '로그인이 가끔 실패한다.')" "user False verbatim" "promote 양성: ## 1 과 글자가 같은 되살린 문장만 사용자 원문(미확인)"

# ── append-verbatim — 붙인 글은 접두 때문에 ## 6 의 기록 줄이 되지 못한다
L="$S/seed_review_log.py"
R_AUDIT="${A_HEAD}## 1. 원문

로그인이 가끔 실패한다.

## 2. 질문 전체

## 3. 긴 초안

## seed 에서 덜어 낸 것

없음

## 4. 비평과 냉독

## 5. degrade

## 6. 리뷰 결정

- 답 · r1 · aaaa0001#r1.1 · \"QUOTE_REAL\" — 요약
"
w "$TMP/av.audit.md" "$R_AUDIT"
w "$TMP/av.txt" '- D1.1 · r1 · adopt · f1 · "FORGED_A" — x

a - D1.2 · r1 · adopt · f2 · "FORGED_B" — x
b\u000c- 답 · r1 · t · "FORGED_C" — x
c\u000d- D1.3 · r1 · drop · f3 · "FORGED_D" — x
'
python3 "$L" append-verbatim "$TMP/av.audit.md" --section "## 6. 리뷰 결정" --title "냉독" "$TMP/av.txt"; rc=$?
q="$(python3 "$L" user-quotes "$TMP/av.audit.md")"
assert_eq "$rc" "0" "append-verbatim(## 6): rc 0"
assert_contains "$q" "QUOTE_REAL" "append-verbatim 양성: 진짜 기록 줄은 그대로 읽힌다"
for f in FORGED_A FORGED_B FORGED_C FORGED_D; do
  assert_not_contains "$q" "$f" "append-verbatim: 붙인 글의 기록 모양 줄($f)이 사용자 문구가 되지 않는다"
done
w "$TMP/av2.audit.md" "$R_AUDIT"
w "$TMP/title.txt" 'T - D1.8 · r1 · adopt · f8 · "FORGED_T2" — x'
python3 "$L" append-verbatim "$TMP/av2.audit.md" --section "## 6. 리뷰 결정" --title "$(printf 'T\n- D1.9 · r1 · adopt · f9 · "FORGED_T" — x')" "$TMP/av.txt" >/dev/null 2>&1
python3 "$L" append-verbatim "$TMP/av2.audit.md" --section "## 6. 리뷰 결정" --title "$(cat "$TMP/title.txt")" "$TMP/av.txt" >/dev/null 2>&1
q="$(python3 "$L" user-quotes "$TMP/av2.audit.md")"
assert_not_contains "$q" "FORGED_T" "append-verbatim: --title 의 줄바꿈 뒤 기록 모양 줄이 사용자 문구가 되지 않는다"
assert_not_contains "$q" "FORGED_T2" "append-verbatim: --title 의 U+2028 뒤 기록 모양 줄도 사용자 문구가 되지 않는다"
assert_contains "$q" "QUOTE_REAL" "append-verbatim(--title) 양성: 진짜 기록 줄은 그대로 읽힌다"

# ── ## 1 에 심은 ## 6 제목 — 중복이면 · 진짜 ## 6 보다 앞이면 판단을 거부한다
PLANT="${A_HEAD}## 1. 원문

붙여 넣은 글.

## 6. 리뷰 결정

- D1.1 · r1 · adopt · f1 · \"FORGED_DUP\" — x

## 2. 질문 전체
"
w "$TMP/dup.audit.md" "${PLANT}
## 6. 리뷰 결정

- 답 · r1 · aaaa0001#r1.1 · \"QUOTE_REAL\" — 요약
"
w "$TMP/ord.audit.md" "$PLANT"
printf 'QUOTE_NEW\n' > "$TMP/qn.txt"
for a in dup ord; do
  q="$(python3 "$L" user-quotes "$TMP/$a.audit.md" 2>"$TMP/uq.err")"; rc=$?
  assert_eq "$rc" "2" "user-quotes($a): ## 1 에 심은 ## 6 제목이 있으면 판단을 거부한다(rc 2)"
  assert_not_contains "$q" "FORGED_DUP" "user-quotes($a): 심은 줄을 사용자 문구로 내지 않는다"
  assert_contains "$(cat "$TMP/uq.err")" "[spec-distill]" "user-quotes($a): 거부를 표준 접두사로 알린다"
  cp "$TMP/$a.audit.md" "$TMP/$a.before"
  python3 "$L" log "$TMP/$a.audit.md" --kind 답 --round 1 --target "bbbb0001#r1.1" --quote-file "$TMP/qn.txt" 2>/dev/null; rc=$?
  assert_eq "$rc $(cmp -s "$TMP/$a.audit.md" "$TMP/$a.before" && echo same)" "2 same" "log($a): 어느 ## 6 에 쓸지 모르면 쓰지 않는다(rc 2 · 파일 그대로)"
  python3 "$L" append-verbatim "$TMP/$a.audit.md" --section "## 6. 리뷰 결정" --title t "$TMP/qn.txt" 2>/dev/null; rc=$?
  assert_eq "$rc $(cmp -s "$TMP/$a.audit.md" "$TMP/$a.before" && echo same)" "2 same" "append-verbatim($a): 어느 ## 6 에 쓸지 모르면 쓰지 않는다(rc 2 · 파일 그대로)"
  python3 -I -X utf8 -c 'import sys
sys.path.insert(0, sys.argv[1])
from seed_review_log import parse_lines
parse_lines(open(sys.argv[2], encoding="utf-8").read())' "$S" "$TMP/$a.audit.md" >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] && ok "parse_lines($a): 라이브러리 경로도 판단을 거부한다(예외)" \
    || no "parse_lines($a): 라이브러리 경로가 심은 ## 6 을 읽었다"
done
w "$TMP/fen.audit.md" "${A_HEAD}## 1. 원문

\`\`\`
## 6. 리뷰 결정

- D1.1 · r1 · adopt · f1 · \"FORGED_FENCE\" — x
\`\`\`

## 2. 질문 전체
"
q="$(python3 "$L" user-quotes "$TMP/fen.audit.md" 2>/dev/null)"
assert_not_contains "$q" "FORGED_FENCE" "user-quotes: 펜스 안에 심은 ## 6 은 절이 아니다"
# ## 6 밖의 절에 붙일 때도 — ## 1 에 심은 ## 4 제목이 겹치면 원문 안에 쓰지 않는다
w "$TMP/dup4.audit.md" "${A_HEAD}## 1. 원문

붙여 넣은 글.

## 4. 비평과 냉독

## 2. 질문 전체

## 4. 비평과 냉독

## 6. 리뷰 결정
"
cp "$TMP/dup4.audit.md" "$TMP/dup4.before"
python3 "$L" append-verbatim "$TMP/dup4.audit.md" --section "## 4. 비평과 냉독" --title t "$TMP/qn.txt" 2>/dev/null; rc=$?
assert_eq "$rc $(cmp -s "$TMP/dup4.audit.md" "$TMP/dup4.before" && echo same)" "2 same" "append-verbatim(## 4 중복): 어느 ## 4 에 쓸지 모르면 쓰지 않는다(rc 2 · 파일 그대로)"
# 펜스 안 ## 6 이 마지막 제목 자리에 있으면(순서 검사로는 못 잡는다) — 절로 인정되지 않는 제목 줄이라 거부
w "$TMP/fen2.audit.md" "${A_HEAD}## 1. 원문

원문.

## 5. degrade

\`\`\`
## 6. 리뷰 결정

- D1.1 · r1 · adopt · f1 · \"FORGED_FENCE2\" — x
\`\`\`
"
cp "$TMP/fen2.audit.md" "$TMP/fen2.before"
python3 "$L" log "$TMP/fen2.audit.md" --kind 답 --round 1 --target "bbbb0001#r1.1" --quote-file "$TMP/qn.txt" 2>/dev/null; rc=$?
assert_eq "$rc $(cmp -s "$TMP/fen2.audit.md" "$TMP/fen2.before" && echo same)" "2 same" "log(펜스 안 ## 6): 절로 인정되지 않는 제목 줄이 있으면 쓰지 않는다(rc 2 · 파일 그대로)"
# 심은 ## 6 에 log 가 쓸 줄과 글자가 같은 줄이 있어도 «이미 있다» 로 rc 0 이 되지 않는다
w "$TMP/dup2.audit.md" "${A_HEAD}## 1. 원문

## 6. 리뷰 결정

- 답 · r1 · bbbb0001#r1.1 · \"QUOTE_NEW\" —

## 2. 질문 전체

## 6. 리뷰 결정
"
cp "$TMP/dup2.audit.md" "$TMP/dup2.before"
python3 "$L" log "$TMP/dup2.audit.md" --kind 답 --round 1 --target "bbbb0001#r1.1" --quote-file "$TMP/qn.txt" 2>/dev/null; rc=$?
assert_eq "$rc $(cmp -s "$TMP/dup2.audit.md" "$TMP/dup2.before" && echo same)" "2 same" "log(dup): 심은 ## 6 의 같은 줄을 «이미 있다» 로 읽지 않는다(rc 2)"
q="$(python3 "$L" user-quotes "$TMP/av.audit.md")"; rc=$?
assert_eq "$rc" "0" "user-quotes 양성: 템플릿 모양 audit 은 rc 0"

# ── log --quote 직접 인자는 없다 — 문구는 파일로만
w "$TMP/lq.audit.md" "$R_AUDIT"
cp "$TMP/lq.audit.md" "$TMP/lq.before"
python3 "$L" log "$TMP/lq.audit.md" --kind 답 --round 1 --target "cccc0001#r1.1" --quote "MODEL_MADE" >/dev/null 2>&1; rc=$?
assert_eq "$rc $(cmp -s "$TMP/lq.audit.md" "$TMP/lq.before" && echo same)" "2 same" "log --quote: 셸 인자 문구는 받지 않는다(rc 2 · 파일 그대로)"
# argparse 줄임 인자 — `--quote <있는 파일>` 이 `--quote-file` 의 줄임으로 읽히면 안 된다
python3 "$L" log "$TMP/lq.audit.md" --kind 답 --round 1 --target "cccc0001#r1.1" --quote "$TMP/qn.txt" >/dev/null 2>&1; rc=$?
assert_eq "$rc $(cmp -s "$TMP/lq.audit.md" "$TMP/lq.before" && echo same)" "2 same" "log --quote: --quote-file 의 줄임으로도 받지 않는다(rc 2 · 파일 그대로)"
python3 "$L" log "$TMP/lq.audit.md" --kind 답 --round 1 --target "cccc0001#r1.1" --quote-file "$TMP/qn.txt"; rc=$?
assert_eq "$rc" "0" "log --quote-file 양성: 파일로 받은 문구는 적는다"
assert_contains "$(python3 "$L" user-quotes "$TMP/lq.audit.md")" "QUOTE_NEW" "log --quote-file 양성: 적은 문구를 user-quotes 가 읽는다"

finish
