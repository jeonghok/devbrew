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

finish
