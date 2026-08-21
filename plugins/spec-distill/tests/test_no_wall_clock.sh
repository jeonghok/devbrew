#!/usr/bin/env bash
# spec-distill — 인터뷰 월클락 제거 회귀 락 (v0.17.0).
# Run: bash plugins/spec-distill/tests/test_no_wall_clock.sh
# 월클락 토큰이 라이브 surface(2 SKILL + README)로 되살아나지 않음을 보장.
# CHANGELOG는 history 보존이라 스캔 제외(과거 Removed 엔트리가 정당하게 "wall-clock" 언급).
# Exits 0 on pass, 1 on fail.

set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PLUGIN_ROOT="$REPO_ROOT/plugins/spec-distill"

# 라이브 surface — 월클락 토큰이 0이어야 하는 파일 (CHANGELOG 제외).
#
# Task 32(무게 감축): 이 락은 **순수 부재 락**이다 — 코퍼스가 줄어도 RED 가 되지 않고
# 조용히 약해진다. `conducting-interview` 의 `## 종료` 절차 전문이
# `skills/conducting-interview/references/finishing.md` 로 분리되면서, 이 열거형 배열이
# 보는 범위는 그 스킬에서 614줄 중 396줄로 줄었는데도 GREEN 이었다(실측). 하필 종료
# 절차가 "얼마나 오래 걸렸나"를 다시 재고 싶어지는 **가장 그럴듯한 자리**다.
# 그래서 references/*.md 를 **열거가 아니라 도출**한다 — 새 참조 파일이 생기면 자동으로
# 대상이 된다. 열거한 세 파일은 그대로 두고(명시적 계약), 도출분을 더한다.
SURFACES=(
  "$PLUGIN_ROOT/skills/conducting-interview/SKILL.md"
  "$PLUGIN_ROOT/skills/reviewing-spec/SKILL.md"
  "$PLUGIN_ROOT/README.md"
)
DERIVED=()
while IFS= read -r _f; do
  [[ -n "$_f" ]] && DERIVED+=("$_f")
done < <(ls "$PLUGIN_ROOT"/skills/*/references/*.md 2>/dev/null)
SURFACES+=("${DERIVED[@]+"${DERIVED[@]}"}")

# 금지 토큰 (재도입 방지).
TOKENS=(
  "wall_clock_started_at"
  "DEVBREW_SPEC_DISTILL_TIMEOUT_MIN"
  "wall-clock"
)

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

echo "=== interview wall-clock removal regression lock ==="

# vacuity: 도출이 0건이면 이 락은 분할 이전 범위로 조용히 되돌아가면서 GREEN 을 찍는다.
# '참조 파일 없음'과 '글롭이 깨졌음'은 여기서 구별되지 않으므로 둘 다 loud FAIL 한다.
if [[ "${#DERIVED[@]}" -ge 1 ]]; then
  ok "코퍼스: references/*.md ${#DERIVED[@]}건 도출 (vacuous 아님)"
else
  no "코퍼스: skills/*/references/*.md 를 0건 도출했다 — 스캔 범위가 조용히 좁아졌다"
fi

for surface in "${SURFACES[@]}"; do
  rel="${surface#"$REPO_ROOT"/}"
  if [[ ! -f "$surface" ]]; then
    no "surface missing: $rel"
    continue
  fi
  for tok in "${TOKENS[@]}"; do
    if grep -qiF -- "$tok" "$surface"; then
      no "$rel still contains token '$tok'"
    else
      ok "$rel free of '$tok'"
    fi
  done
done
finish
