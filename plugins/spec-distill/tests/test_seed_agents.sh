#!/usr/bin/env bash
# guards: plugins/spec-distill/agents/seed-*.md
#
# 두 seed 리뷰어의 **도구 표면**을 잰다. `tools: []` 는 Law 2 의 집행 지점이고, 여기서는
# 그보다 더 강하다 — 이 둘은 `Read` 도 없다.
#
# **왜 `Read` 조차 없나**: `seed-readback` 의 측정이 성립하려면 그것이 **seed 만** 알아야
# 한다. `Read` 가 있으면 원문 파일을 열어 「seed 만 읽고 알 수 있나」가 더 이상 재지지
# 않는다. `seed-critic` 은 원문이 필요하지만 **inline 으로** 받는다 — 도구가 아니라
# 프롬프트로 준다. 도구 표면이 격리의 유일한 물리적 근거다(프롬프트 지시는 근거가 아니다).
#
# `disallowedTools` 단독은 금지다 — 공간에 대해서도 시간에 대해서도 fail-open 이다
# (내일 추가될 도구는 오늘 열거할 수 없다).
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
AGENTS="$ROOT/plugins/spec-distill/agents"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/agents/seed-critic.md"
  echo "plugins/spec-distill/agents/seed-readback.md"
  exit 0
fi

n=0
for a in seed-critic seed-readback; do
  f="$AGENTS/$a.md"
  if [ ! -f "$f" ]; then no "$a: agent 정의 부재"; continue; fi
  n=$((n + 1))
  fm="$(awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f' "$f")"
  # `tools:` 가 있고 빈 리스트인가. 값이 있으면 RED.
  tl="$(printf '%s\n' "$fm" | sed -n 's/^tools:[[:space:]]*//p' | head -1)"
  case "$tl" in
    "[]"|"[ ]") ok "$a: tools: [] (도구 표면 0)" ;;
    "")         no "$a: frontmatter 에 tools: 선언이 없다 — default-everything 은 금지다" ;;
    *)          no "$a: tools: '$tl' — 빈 리스트가 아니다. 격리가 도구 표면에서 무너진다" ;;
  esac
  # denylist 단독 금지
  printf '%s\n' "$fm" | grep -q '^disallowedTools:' \
    && no "$a: disallowedTools 를 쓴다 — 공간·시간 양쪽에 fail-open 이다" \
    || ok "$a: denylist 미사용"
  # camelCase `allowedTools` 잔존 — 존재하지 않는 필드를 실재하는 것처럼 쓰면
  # 조용히 무시되면서도 다음 저자를 오독시킨다 (context §③).
  printf '%s\n' "$fm" | grep -qE '^allowedTools:' \
    && no "$a: allowedTools(camelCase) — 존재하지 않는 필드다. 조용히 무시된다" \
    || ok "$a: allowedTools(camelCase) 잔존 없음"
  # model: inherit — 형제 zero-tool 둘(brief-critic·brief-readback)의 정본과 같은 값.
  ml="$(printf '%s\n' "$fm" | sed -n 's/^model:[[:space:]]*//p' | head -1)"
  [ "$ml" = "inherit" ] \
    && ok "$a: model: inherit" \
    || no "$a: model: '$ml' — 형제 정본은 inherit 이다"
  # description 이 dispatch 트리거로 기능하려면 실제로 이 agent 이름을 참조하는
  # SKILL.md dispatch 자리가 있어야 한다 — **토큰 공존이 아니라 관계**: description
  # 필드의 실재가 아니라 그 필드가 가리키는 대상(SKILL.md 안 실제 dispatch)이 있는지를
  # 확인한다. 가짜 agent 정의(description 텍스트만 있고 아무 SKILL 도 부르지 않는 것)를
  # 걸러내는 것이 이 검사의 목적이다.
  if grep -qE "subagent_type: \"spec-distill:$a\"" "$ROOT/plugins/spec-distill/skills"/*/SKILL.md 2>/dev/null; then
    ok "$a: SKILL.md 가 이 agent 를 실제로 dispatch 한다 (description 이 장식이 아니다)"
  else
    no "$a: 어떤 SKILL.md 도 subagent_type: \"spec-distill:$a\" 를 dispatch 하지 않는다 — description 이 가리킬 대상이 없다"
  fi
done
[ "$n" -eq 2 ] && ok "agent 2개 전부 실재" || no "agent 도출 ${n}개 — 2 여야 한다"
finish
