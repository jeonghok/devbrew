#!/usr/bin/env bash
# AC7b·AC7c — web kill switch가 두 소비자 각각에 인라인으로 살아 있다.
#
# 왜 소비자별로 나누는가: v0.24.12가 web_budget.py를 지우면서 kill switch 구현을
# 두 소비자로 이전했다. 한 파일에 대한 assert가 다른 파일을 덮으면, 한쪽에서
# 스위치가 사라져도 GREEN이 난다 — 스위치가 거짓말을 하는 상태다.
#
# 계약(설계 §6 S3d): 정확히 문자열 "1"만 참. 미설정 = 웹 활성. 평가는 각 웹 작업 직전.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
pass=0; fail=0
note() { if [[ "$1" == PASS ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

for consumer in conducting-interview reviewing-brief; do
  SKILL="$SD/skills/$consumer/SKILL.md"
  if [[ ! -f "$SKILL" ]]; then note FAIL "$consumer: SKILL.md 부재"; continue; fi
  # 줄-시작 앵커 + 정확한 비교식 — 산문 언급만으로는 통과하지 못한다.
  grep -qE '^[[:space:]]*if \[\[ "\$\{DEVBREW_SPEC_DISTILL_DISABLE_WEB:-0\}" == "1" \]\]' "$SKILL" \
    && note PASS "$consumer: kill switch 인라인 체크 실재" \
    || note FAIL "$consumer: kill switch 인라인 체크 부재"
  # 계약: 정확히 "1" — 느슨한 참 판정(true/yes/비어있지 않음)은 계약 위반이다.
  grep -qE 'DEVBREW_SPEC_DISTILL_DISABLE_WEB.*(true|yes|-n |!= *"")' "$SKILL" \
    && note FAIL "$consumer: 느슨한 참 판정 — 계약은 정확히 \"1\"이다" \
    || note PASS "$consumer: 참 판정이 \"1\" 한정"
  # 상한 게이트가 되돌아오지 않았다.
  grep -qE 'web_budget|SWEEP_CAP|SESSION_CAP' "$SKILL" \
    && note FAIL "$consumer: 상한 게이트 재도입" \
    || note PASS "$consumer: 상한 게이트 없음"
done

# production 전역 — 스크립트와 카운터가 실제로 사라졌다(AC7a).
# tests/·CHANGELOG는 제외: 전자는 부재를 assert하는 층이고 후자는 이력이다(C2).
leftover="$(grep -rln 'web_budget\|web_sweep_count\|web_search_count' "$SD" \
  --exclude-dir=tests --exclude=CHANGELOG.md 2>/dev/null || true)"
if [[ -z "$leftover" ]]; then
  note PASS "AC7a: production에 web_budget/카운터 잔존 0"
else
  note FAIL "AC7a: production 잔존:"; printf '    %s\n' $leftover
fi

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
