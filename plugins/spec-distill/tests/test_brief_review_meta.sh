#!/usr/bin/env bash
# Spec B T15·T18·T29·T31(문서) — 메타데이터 · 훅 무증가 · 결정론 체크 열거표 · 정규화 계약.
# AC19(메타데이터) · AC22a(훅 0 추가) · AC22c(이빨 없는 체크 0 + 전수 열거) · AC11(N1–N5 순서·NFC)
# Run: bash plugins/spec-distill/tests/test_brief_review_meta.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
PJ="$SD/.claude-plugin/plugin.json"
CL="$SD/CHANGELOG.md"
RM="$SD/README.md"
HOOKS="$SD/hooks"
SPEC="$REPO_ROOT/docs/superpowers/specs/2026-07-27-spec-distill-brief-review-pipeline-design.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }
section() { awk -v pat="$1" '$0 ~ pat {inw=1; next} inw && /^## / {exit} inw' "$2"; }

# --- T15 / AC19 : 메타데이터 (minor만 pin, patch unpin) ---------------------
grep -qE '"version": "0\.24\.[0-9]+"' "$PJ" \
  && note PASS "T15: plugin.json 0.24.x" || note FAIL "T15: plugin.json이 0.24.x가 아님"
grep -qE '^## \[0\.24\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CL" \
  && note PASS "T15: CHANGELOG [0.24.0] + ISO 날짜" || note FAIL "T15: CHANGELOG [0.24.0] 누락/비-ISO"
# append-only 누산 — 과거 엔트리 pin은 절대 빼지 않는다
for v in '0\.20\.0' '0\.22\.0' '0\.23\.0'; do
  grep -qE "^## \[$v\]" "$CL" && note PASS "T15: CHANGELOG 과거 엔트리 [$v] 보존" \
                              || note FAIL "T15: 과거 엔트리 [$v]가 사라졌다 (append-only 위반)"
done
PRIN="$(section '^## Principles Instantiated' "$RM")"
for kw in 'brief-critic' 'brief-direction-reviewer' 'brief-readback' 'reviewing-brief'; do
  grep -qF "$kw" <<<"$PRIN$(section '^## Flow' "$RM")" \
    && note PASS "T15: README에 신규 컴포넌트 '$kw'" || note FAIL "T15: README에 '$kw' 부재"
done
KS="$(section '^## Kill switches' "$RM")"
grep -qF 'DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW' <<<"$KS" \
  && note PASS "T15: README Kill switches에 신규 스위치" || note FAIL "T15: 신규 kill switch 미문서화"
grep -qF 'Law 2' <<<"$PRIN" && note PASS "T15: Principles Instantiated에 Law 2" || note FAIL "T15: Law 2 항목 부재"

# --- T18 / AC22a : 훅 집합 고정 열거 + 'brief' 문자열 0건 --------------------
EXPECTED="hooks.json pending-review-reminder.py review-dispatch.py session-end-cleanup.py spec-write-validator.py state_path.py"
ACTUAL="$(cd "$HOOKS" && ls -1 | sort | tr '\n' ' ' | sed 's/ $//')"
EXPECTED_SORTED="$(tr ' ' '\n' <<<"$EXPECTED" | sort | tr '\n' ' ' | sed 's/ $//')"
[[ "$ACTUAL" == "$EXPECTED_SORTED" ]] \
  && note PASS "T18: hooks/ 집합이 고정 열거와 정확히 일치 (6개)" \
  || note FAIL "T18: hooks/ 집합 불일치 — 기대[$EXPECTED_SORTED] 실제[$ACTUAL]"
n_brief="$(grep -cF 'brief' "$HOOKS/hooks.json" || true)"
[[ "$n_brief" == "0" ]] && note PASS "T18: hooks.json에 'brief' 문자열 0건" \
                        || note FAIL "T18: hooks.json에 'brief' ${n_brief}건 (훅 표면 확장)"

# --- T29 / AC22c : 결정론 체크 전수 열거표 ----------------------------------
test -f "$SPEC" || note FAIL "spec 문서 부재: $SPEC"
T63="$(awk '/^### 6\.3/{inw=1; next} inw && /^## /{exit} inw' "$SPEC")"
[[ -n "$T63" ]] && note PASS "T29: spec §6.3 열거표 실재" || note FAIL "T29: §6.3 표 부재"
for chk in 'check_verbatim_coverage' 'zero-tool probe' 'merge_brief_review' 'T-lock'; do
  grep -qF "$chk" <<<"$T63" && note PASS "T29: 열거표에 '$chk'" || note FAIL "T29: 열거표에 '$chk' 누락"
done
grep -qF '누가' <<<"$T63" && note PASS "T29: '누가 쓰는가' 열 존재" || note FAIL "T29: '누가 쓰는가' 열 부재"
# 삭제된 어휘-검출 체크를 요구하지 않는다 (round-4가 잡은 dangling)
grep -qE '어휘 검출|오염 검출|contamination' <<<"$T63" \
  && note FAIL "T29: 삭제된 검출 메커니즘을 열거표가 요구" || note PASS "T29: 삭제된 검출 요구 부재"
# 신규 결정론 체크가 표에 빠지지 않았는가 — 구현된 스크립트 목록과 대조
for s in check_verbatim_coverage merge_brief_review; do
  test -f "$SD/scripts/$s.py" || note FAIL "T29: ${s}.py 부재 (Task 순서 이상)"
done

# --- T31(문서) / AC11 : 정규화 순서·NFC 계약이 spec에 명시 -------------------
S55="$(awk '/^### 5\.5/{inw=1; next} inw && /^### /{exit} inw' "$SPEC")"
grep -qF 'N1 → N2 → N3 → N4 → N5' <<<"$S55" \
  && note PASS "T31: 고정 순서 N1 → N5 명시" || note FAIL "T31: 고정 순서 명시 부재"
grep -qE 'N3보다 N1이 (반드시 )?먼저' <<<"$S55" \
  && note PASS "T31: 'N3보다 N1이 먼저' 근거 명시" || note FAIL "T31: 순서 근거 부재"
grep -qE 'NFC' <<<"$S55" && note PASS "T31: N5가 NFC" || note FAIL "T31: NFC 명시 부재"
grep -qE '전각/반각(은|을)? \*\*접지 않는다\*\*|접지 않는다' <<<"$S55" \
  && note PASS "T31: 폭-접기를 주장하지 않음" || note FAIL "T31: 폭-접기 주장 잔존"
grep -qF 'NFKC' <<<"$S55" && note PASS "T31: NFKC 미채택 근거 존재" || note FAIL "T31: NFKC 미채택 근거 부재"
# 구현이 문서와 일치하는가 (문서만 고치고 코드를 안 고치는 비대칭 방지)
grep -qF 'unicodedata.normalize("NFC"' "$SD/scripts/check_verbatim_coverage.py" \
  && note PASS "T31: 구현이 NFC를 쓴다" || note FAIL "T31: 구현이 NFC가 아니다 (문서-코드 drift)"

# --- E10 : 신규 결정론 체크가 이빨 없는 의례를 도입하지 않았는가 -------------
# skills/reviewing-brief/SKILL.md:359는 이 패턴을 이름으로 지목해 "넣지 않는다"고
# 기각하는 서술이다 — 원래 assertion(단일 grep)은 그 문장 자체와 매치해 항상 FAIL하는
# 오탐이었다(문서가 안티패턴을 *기술*하는 것과 실제로 *도입*하는 것을 구분 못 함).
# 같은 줄에 부정 문맥(넣지 않/도입하지 않/않습니다)이 있으면 서술로 보고 제외한다 —
# 검사 대상 자신이 부정 문맥까지 함께 조작하지 않는 한 통과 조건을 못 바꾼다는 뜻은
# 아니다(§6.3의 T-lock 계열과 같은 한계). 분류 정확성은 V8(사람) 몫 — 기계는 열거만 본다.
E10_HITS="$(grep -rnE '리뷰 라운드 기록이 (있는가|존재)' "$SD/scripts" "$SD/skills" 2>/dev/null \
  | grep -vE '넣지 않|도입하지 않|않습니다')"
[[ -z "$E10_HITS" ]] \
  && note PASS "AC22c: 이빨 없는 기록 검사 부재(서술 언급 제외)" \
  || note FAIL "AC22c: 이빨 없는 '리뷰 라운드 기록' 검사가 도입됐다: ${E10_HITS}"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ "$fail" -eq 0 ]]
