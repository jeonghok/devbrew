#!/usr/bin/env bash
# V7 — stale-term 회귀 락. rename 완결을 **production artifacts**에서 확인한다.
# (a) breadth-keeper → coverage-mapper 재명명이 production에 완결(잔존 0).
# (b) interview_round는 활성 코드서 제거, SKILL은 migration 섹션에만.
# 스코프: production artifacts만 — SKILL.md/README.md/agents/templates/scripts/plugin.json.
# 제외: (1) CHANGELOG.md(released 기록 + 이 rename을 서술하는 [0.22.0] 엔트리 — Keep-a-Changelog 불변),
#       (2) tests/(락·stage test가 토큰을 *집행/assert*하는 층 — stale ref면 그 테스트가 자체 fail),
#       (3) mocks/. 테스트의 토큰 참조는 제거를 강제하는 enforcement 층이지 stale 참조가 아니다.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
SKILL="$SD/skills/conducting-interview/SKILL.md"
pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# production artifact 파일 집합(tests/·CHANGELOG.md 제외)
prod_files=()
while IFS= read -r f; do prod_files+=("$f"); done < <(
  find "$SD" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.py' -o -name '*.json' \) \
    -not -path '*/tests/*' -not -name 'CHANGELOG.md'
)

# V7a: breadth-keeper production 잔존 0
bk="$(grep -nE 'breadth-keeper|breadth_keeper|Breadth-Keeper' "${prod_files[@]}" 2>/dev/null || true)"
[[ -z "$bk" ]] && note PASS "V7a: no breadth-keeper in production artifacts" \
  || { note FAIL "V7a: stale breadth-keeper in production:"; printf '%s\n' "$bk"; }

# V7b-1: SKILL.md interview_round는 migration 섹션에만
mig="$(awk '/^## In-flight state migration/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
all_ir=$(grep -c interview_round "$SKILL" 2>/dev/null || true)
mig_ir=$(printf '%s\n' "$mig" | grep -c interview_round 2>/dev/null || true)
{ [[ "$all_ir" -ge 1 ]] && [[ "$all_ir" -eq "$mig_ir" ]]; } \
  && note PASS "V7b: interview_round in SKILL confined to migration ($all_ir)" \
  || note FAIL "V7b: interview_round leaks outside SKILL migration (total=$all_ir mig=$mig_ir)"

# V7b-2: interview_round production(SKILL 제외) 잔존 0
ir=""
for f in "${prod_files[@]}"; do
  [[ "$f" == "$SKILL" ]] && continue
  m="$(grep -nH interview_round "$f" 2>/dev/null || true)"
  [[ -n "$m" ]] && ir+="$m"$'\n'
done
[[ -z "$ir" ]] && note PASS "V7b: no interview_round in production outside SKILL migration" \
  || { note FAIL "V7b: interview_round in unexpected production files:"; printf '%s\n' "$ir"; }

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
