#!/usr/bin/env bash
# AC7 — design 자리의 층 2 체크리스트에 `handoff_incomplete` 가 일곱 번째로 실려 있다.
#
# ── 앵커 재조준 (문서 리뷰 엔진 전환, T7) ────────────────────────────────────
# 옛 대상은 삭제된 design-doc 리뷰어 agent 의 「Design Mode Branch」 블록이었다.
# 그 agent 는 엔진 전환으로 사라졌고, 이 자리의 체크리스트를 오늘 소유하는 것은
# `references/docreview-profiles/design-doc.md` 의 `layer_rubric.layer2` 다 — 탐지
# 리뷰어(`doc-critic`)가 층 2 에서 그 목록을 그대로 검토 항목으로 쓴다.
#
# 재는 것은 그대로다: **일곱 카테고리가 한 목록 안에 함께 있는가.** 대상만 바뀐다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PROFILE="$REPO_ROOT/plugins/spec-distill/references/docreview-profiles/design-doc.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# 양의 짝 — 부재 대상 위에서 아래 판정이 조용히 통과하는 것을 막는다. 대상 파일이
# 없으면 `layer2` 추출이 빈 문자열이 되고, 빈 문자열에 대한 grep 은 전부 실패해
# "일곱 개가 없다"라는 **원인을 잘못 짚는** 진단으로 넘어간다.
if [[ -f "$PROFILE" ]]; then
  ok "AC7: 프로필 실재 — ${PROFILE#"$REPO_ROOT/"}"
else
  no "AC7: 프로필 부재 — ${PROFILE#"$REPO_ROOT/"} (아래 판정은 잴 대상이 없다)"
  finish; exit
fi

# `layer_rubric.layer2` 한 줄을 frontmatter 에서 뽑는다. 이 키는 파일 안에 한 번만
# 나오므로 창을 따로 자르지 않는다.
LAYER2="$(sed -n 's/^[[:space:]]*layer2:[[:space:]]*//p' "$PROFILE" | head -1)"
if [[ -n "$LAYER2" ]]; then
  ok "AC7: layer_rubric.layer2 추출 성공 ($LAYER2)"
else
  no "AC7: layer_rubric.layer2 를 추출하지 못했다 — 프로필 문법이 바뀌었거나 키가 사라졌다"
  finish; exit
fi

for cat in "placeholder" "ambiguity" "scope_creep" "approaches_comparison" "isolation" "testing" "handoff_incomplete"; do
  printf '%s' "$LAYER2" | grep -qF "$cat" \
    && ok "AC7: 층 2 카테고리 '$cat' 실재" \
    || no "AC7: 층 2 카테고리 '$cat' 부재"
done

# approaches_comparison 항목이 「있는 것 검토」 절도 읽는다 — 낼 때 여섯 · 처분 · 한계(항목 창 안에서만 잰다)
AC_ITEM="$(awk '/^- `approaches_comparison`/{f=1} /^- `isolation`/{f=0} f' "$PROFILE")"
for lit in '`## 있는 것 검토` 절도 이 항목이 읽는다 — 있는 것이라는 대안을 견주는 자리다. 아래 여섯 가운데 하나면 낸다.' \
           '1. 「있는 것 검토」 절이 없고 「해당 없음 — 이유」도 없다.' \
           '2. 찾아본 후보가 이름으로 없거나, 「없음」이 어디를 찾았는지 없이 적혔거나, 찾지 않은 곳의 이유가 그 일에 대한 구체가 아니라 일반 문구다.' \
           '3. 후보마다 이 문서의 요구 문장(목표 · 수용 기준)에 비춘 맞음 판정이 없다.' \
           '4. 바깥 후보의 정보 여섯 칸(만든 쪽이 공식으로 내는가 · 널리 쓰이는가와 재는 단위 · 지금도 유지되는가 · 안정 단계 · 무엇을 실행하고 무엇에 닿는가와 알려진 보안 문제 · 라이선스와 그것이 지우는 의무)에 출처와 확인 날짜가 없고 「확인 못 함」 표시도 없다.' \
           '5. 직접 만들기 결론의 이유가 그 후보에 대한 구체가 아니라 상시 규칙이나 앞 결정의 인용뿐이다.' \
           '6. 고른 것마다 수용 기준이 없다.' \
           '빠진 사실을 채우는 것이면 `fix`, 저자에게 그 사실이 없으면 그 `fix` 를 막는 `ask`, 쓰기와 만들기의 결론을 바꾸자는 것이면 `decide` 다.' \
           '이 리뷰는 웹을 보지 않는다 — 절을 읽을 뿐 바깥을 새로 찾지 않으며, 빠진 후보는 문서나 레포에 근거가 있을 때만 지적한다.'; do
  assert_contains "$AC_ITEM" "$lit" "있는 것 먼저: approaches_comparison 항목에 «${lit}»"
done

# 기준 글의 우리 절 — 여섯 칸의 대상이 위 4번과 같고(바깥 후보), 「승인 전」을 받는 문장이 있다
REF_DOC="$REPO_ROOT/plugins/spec-distill/references/existing-first.md"
REF_OURS="$(awk '/^---$/{exit} {print}' "$REF_DOC")"
for lit in '4. **바깥 후보마다 보이는 정보 여섯.** 그 레포가 의존으로 적어 둔 남의 것도 바깥 후보다. 레포 안 것은 해당하는 칸만 적는다.' \
           '대화에서 승인받지 못한 것은 「승인 전」으로 적는다 — 문서를 승인하는 자리는 이 승인을 대신하지 않는다. 「승인 전」이 남으면 계획으로 넘기기 전에 사용자에게 묻는다.'; do
  assert_contains "$REF_OURS" "$lit" "있는 것 먼저: 기준 글의 우리 절에 «${lit}»"
done
MC="$(sed -n 's/^must_catch:[[:space:]]*//p' "$PROFILE" | head -1)"
assert_eq "$MC" '[goal_fit, problem_definition, scope, architecture, required_sections]' "있는 것 먼저: 꼭 잡을 항목 목록은 그대로다(approaches_comparison 을 올리지 않는다)"
finish
