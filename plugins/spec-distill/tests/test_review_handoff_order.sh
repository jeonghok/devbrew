#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/conducting-interview/references/finishing.md plugins/spec-distill/templates/interview-brief-template.md plugins/spec-distill/skills/reviewing-spec/SKILL.md
#
# AC8 · AC16 — 핸드오프 네 자리가 brainstorming → `spec-distill:reviewing-spec` → writing-plans
# 순서를 싣고, `reviewing-spec` 의 게이트 없는 두 종료 경로가 같은 복귀 지시로 끝나는가.
#
# **정적 락이다.** 문구의 존재와 순서만 증명한다 — 오케스트레이터가 그 문구대로 부르는지는
# 재지 못한다(AC14 수동 e2e 몫). 게이트 없는 종료의 «실행 출력»은
# `test_reviewing_spec_entry_fence.sh` 가 잰다 — 여기는 그 문장이 표면에 있는지만 본다.
#
# 자리마다 창을 따로 자른다 — 파일 어딘가에 순서가 있으면 통과하는 것이 아니라 그 자리에
# 있어야 한다. 순서는 창 안의 문자 오프셋으로 잰다(한 줄 안의 순서까지).
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FIN="$ROOT/plugins/spec-distill/skills/conducting-interview/references/finishing.md"
TPL="$ROOT/plugins/spec-distill/templates/interview-brief-template.md"
SKILL="$ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/skills/conducting-interview/references/finishing.md"
  echo "plugins/spec-distill/templates/interview-brief-template.md"
  echo "plugins/spec-distill/skills/reviewing-spec/SKILL.md"
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"

RETURN_TAIL='리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트).'

nonempty() {   # nonempty <라벨> <창> — 빈 창은 통과가 아니라 앵커 파손
  if [ -n "$2" ]; then ok "$1: 창 추출 ($(printf '%s\n' "$2" | wc -l | tr -d ' ')줄)"; return 0; fi
  no "$1: 창이 비었다 — 구조 앵커 파손 (통과 아님)"; return 1
}
order() {   # order <라벨> <창> <앞> <뒤>
  local r
  r="$(WIN="$2" A="$3" B="$4" python3 -c '
import os
w, a, b = os.environ["WIN"], os.environ["A"], os.environ["B"]
i, j = w.find(a), w.find(b)
print("앞 없음" if i < 0 else "뒤 없음" if j < 0 else "ok" if i < j else "역순")
')"
  if [ "$r" = "ok" ]; then ok "$1: '$3' → '$4'"; else no "$1: 순서 판정 $r ('$3' → '$4')"; fi
}

# ── ① /compact 템플릿 — 사용자가 그대로 붙여넣는 한 줄 ──────────────────────
ONE="$(grep -F '/compact interview brief at' "$FIN" || true)"
n1="$(printf '%s' "$ONE" | grep -c . || true)"
if [ "$n1" = "1" ]; then
  ok "① 템플릿 줄이 정확히 하나"
  order "① 템플릿" "$ONE" "Skill superpowers:brainstorming" "spec-distill:reviewing-spec"
  order "① 템플릿" "$ONE" "spec-distill:reviewing-spec" "writing-plans"
  # 치환되지 않은 placeholder 를 잡는 fail-closed 검사가 없다(finishing.md 가 스스로 적는다) —
  # 새 꺾쇠 자리를 들이지 않는다.
  ph="$(printf '%s' "$ONE" | grep -oE '<[^>]+>' | sort -u | tr '\n' ' ')"
  assert_eq "$ph" "<brief-path> " "① 템플릿의 꺾쇠 placeholder 는 <brief-path> 하나뿐"
else
  no "① 템플릿 줄이 ${n1}개 — 정확히 하나여야 한다"
fi

# ── ② 호출 프롬프트 ─────────────────────────────────────────────────────────
TWO="$(awk '/^- \*\*② 확정하고 바로 brainstorming\*\*/{f=1} /^- \*\*③/{f=0} f' "$FIN")"
if nonempty "②" "$TWO"; then
  order "② 호출 프롬프트" "$TWO" "Skill superpowers:brainstorming" "spec-distill:reviewing-spec"
  order "② 호출 프롬프트" "$TWO" "spec-distill:reviewing-spec" "writing-plans"
  assert_contains "$TWO" "보다 이 순서가 우선한다" "②: brainstorming 의 「다음은 writing-plans 뿐」보다 우선한다고 적는다"
  assert_contains "$TWO" "게이트 없이 끝나면 brainstorming 의 사용자 리뷰 게이트로 돌아간다" "②: 게이트 없는 종료의 복귀 분기를 싣는다 (AC16)"
fi

# ── brief 템플릿 §7 ─────────────────────────────────────────────────────────
SEV="$(awk '/^## 7\. Next Action/{f=1} f' "$TPL")"
if nonempty "§7" "$SEV"; then
  order "brief 템플릿 §7" "$SEV" "superpowers:brainstorming" "spec-distill:reviewing-spec"
  order "brief 템플릿 §7" "$SEV" "spec-distill:reviewing-spec" "writing-plans"
fi

# ── reviewing-spec description — 자기 자신을 가리키므로 이름 대신 «앞/뒤» 를 잰다 ─
DESC="$(awk 'NR==1 && /^---$/{f=1; next} f && /^---$/{exit} f' "$SKILL" \
  | awk '/^description:/{d=1; print; next} d && /^[a-z_]+:/{d=0} d')"
if nonempty "description" "$DESC"; then
  order "description" "$DESC" "superpowers:brainstorming" "superpowers:writing-plans"
  assert_contains "$DESC" "before superpowers:writing-plans" "description: writing-plans «앞» 에 쓴다고 적는다"
  assert_contains "$DESC" "user-review gate" "description: brainstorming 의 사용자 리뷰 게이트를 대신한다고 적는다"
  assert_contains "$DESC" "path as the argument" "description: 설계문서 경로를 인자로 받는다고 적는다"
fi

# ── AC16 — 게이트 없는 두 종료 경로 ──────────────────────────────────────────
STEPA="$(grep -E '^> `\[spec-distill\] current_spec ' "$SKILL" || true)"
na="$(printf '%s' "$STEPA" | grep -c . || true)"
if [ "$na" = "1" ]; then
  case "$STEPA" in
    *"$RETURN_TAIL\`") ok "대상 부재 advisory 가 복귀 지시로 끝난다" ;;
    *) no "대상 부재 advisory 의 마지막 문장이 복귀 지시가 아니다: $STEPA" ;;
  esac
else
  no "대상 부재 advisory 인용 줄이 ${na}개 — 정확히 하나여야 한다"
fi
FENCE="$(awk 'index($0,"<!-- review-entry:begin -->"){f=1;next} index($0,"<!-- review-entry:end -->"){f=0} f' "$SKILL")"
if nonempty "진입 펜스" "$FENCE"; then
  assert_contains "$FENCE" "$RETURN_TAIL" "진입 펜스가 복귀 지시 문장을 갖는다"
fi
finish
