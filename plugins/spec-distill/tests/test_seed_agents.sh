#!/usr/bin/env bash
# guards: plugins/spec-distill/agents/seed-*.md plugins/spec-distill/skills/framing-requests/SKILL.md
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
#
# ── 관계 축 2 (fix round 3 — 쌍 결속) — dispatch 창의 <태그>${변수} 쌍 ==
#    description 선언 ────────────────────────────────────────────────────
# 도구 표면이 0 이어도 SKILL.md 의 dispatch 프롬프트가 description 이 약속하지 않은
# 것을 인라인하면 격리는 여전히 샌다. round 2 는 **태그 이름의 집합**만 대조했는데
# 그것으로는 부족했다 — `<seed>${BLOB}</seed>` 처럼 태그 이름은 옳고 안에 바인딩된
# **변수만 바뀐** 편집이 그 축을 그대로 통과했다(실측, round 2 self-defeat). 그것은
# 다른 결함이 아니라 **같은 결함이 올바른 라벨을 쓴 것**이다 — `seed-readback` 이
# 초안을 받으면, 그것이 `<draft>` 태그로 왔든 이름만 `<seed>` 로 바꿔 왔든 냉독의
# 전제(seed 하나만으로 무엇을 이해했나)는 똑같이 무너진다. 그래서 이 축은 이제
# «태그 이름」이 아니라 «태그+그 안에 바로 이어지는 변수» **쌍**을 건다.
#
# **도출, 하드코딩 아님.** description 의 백틱 리터럴이 이제 쌍 전체를 담는다
# (`<draft>${BLOB}</draft>`, `<seed>${SEED}</seed>`) — 태그 이름을 도출했던 것과 같은
# 방법으로 쌍도 그대로 뽑는다. 백틱 밖 `<example>` 은 뒤에 `${...}` 인터폴레이션이
# 오지 않으므로 쌍 정규식 자체가 걸러낸다(백틱 경계는 여기서부터는 방어의 전부가
# 아니라 이중 방어일 뿐이다).
#
# **이 축이 못 보는 것 (여기 명시한다).** 이것은 **정적 텍스트 대조**다.
# `<seed>${SEED}</seed>` 에서 태그·변수 «이름» 이 둘 다 옳아도, `SEED` 라는 변수가
# 이 dispatch 지점 «위» 어딘가에서 실제로 무엇에 할당됐는지는 안 본다 — 예를 들어
# 위에 `const SEED = BLOB` 같은 대입이 있다면 이름은 전부 맞는데 값은 초안이다.
# 그것은 데이터 흐름이고, 텍스트 대조가 볼 수 있는 범위 밖이다. 이 락의 보장은
# 「선언된 채널과 실제로 인라인된 채널의 (이름, 변수-토큰) 쌍이 같다」까지이고, 그
# 변수-토큰이 실행 시점에 무엇을 담을지까지는 보장하지 않는다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
AGENTS="$ROOT/plugins/spec-distill/agents"
SKILL="$ROOT/plugins/spec-distill/skills/framing-requests/SKILL.md"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/agents/seed-critic.md"
  echo "plugins/spec-distill/agents/seed-readback.md"
  echo "plugins/spec-distill/skills/framing-requests/SKILL.md"
  exit 0
fi

# extract_dispatch_window <agent-name> → SKILL.md 안에서 그 agent 를 dispatch 하는
#   ```javascript 펜스 하나의 전체 텍스트. 오늘 실측으로 dispatch 서식은 항상
#   그 펜스 하나(펜스당 dispatch 1건) — 여러 dispatch 가 한 펜스에 있으면 이 함수는
#   구분하지 않고 펜스 전체를 반환한다(이 태스크 범위에서는 무해, 1:1 이므로).
extract_dispatch_window() {
  awk -v pat="\"spec-distill:$1\"" '
    /^```javascript[[:space:]]*$/ { buf=""; capturing=1; next }
    capturing && /^```[[:space:]]*$/ {
      if (index(buf, pat) > 0) printf "%s", buf
      capturing=0; next
    }
    capturing { buf = buf $0 "\n" }
  ' "$SKILL"
}

# set_diff <A(개행 목록)> <B(개행 목록)> → A 에 있고 B 에 없는 줄(A \ B). 빈 줄은 무시.
set_diff() {
  printf '%s\n' "$1" | grep -v '^$' | while IFS= read -r line; do
    printf '%s\n' "$2" | grep -qxF -- "$line" || printf '%s\n' "$line"
  done
}

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

  # ── 관계 축 2: dispatch 창의 (태그,변수) 쌍 == description 선언 쌍. 도출(하드코딩
  # 아님) — frontmatter 안 백틱 리터럴(`<draft>${BLOB}</draft>` 등)에서 뽑는다. 이
  # 축이 못 보는 것(변수 값의 데이터 흐름)은 파일 머리 "관계 축 2" 절에 명시했다.
  PAIR_RE='<[a-zA-Z_][a-zA-Z0-9_]*>\$\{[A-Za-z_][A-Za-z0-9_]*\}'
  PAIR_SED='s/^<([a-zA-Z_][a-zA-Z0-9_]*)>\$\{([A-Za-z_][A-Za-z0-9_]*)\}$/\1=\2/'
  expected="$(printf '%s\n' "$fm" | grep -oE "$PAIR_RE" | sed -E "$PAIR_SED" | sort -u)"
  n_expected="$(printf '%s\n' "$expected" | grep -c . || true)"
  if [ "$n_expected" -lt 1 ]; then
    no "$a: description 에서 <태그>\${변수} 쌍 선언을 하나도 도출 못 함 — 이 축이 vacuous 하다"
  else
    ok "$a: description 에서 쌍 선언 ${n_expected}개 도출 — {$(printf '%s' "$expected" | tr '\n' ' ')}"
    window="$(extract_dispatch_window "$a")"
    if [ -z "$window" ]; then
      no "$a: SKILL.md 에서 dispatch 창(\`\`\`javascript 펜스)을 못 찾았다"
    else
      actual="$(printf '%s' "$window" | grep -oE "$PAIR_RE" | sed -E "$PAIR_SED" | sort -u)"
      extra="$(set_diff "$actual" "$expected")"
      missing="$(set_diff "$expected" "$actual")"
      if [ -z "$extra" ] && [ -z "$missing" ]; then
        ok "$a: dispatch 창의 (태그,변수) 쌍이 description 선언과 정확히 일치 — {$(printf '%s' "$actual" | tr '\n' ' ')}"
      else
        [ -n "$extra" ] \
          && no "$a: 창에 선언 밖 쌍 — $(printf '%s' "$extra" | tr '\n' ' ')(격리가 샌다 — 이 채널이나 그 값이 description 약속과 다르다)"
        [ -n "$missing" ] \
          && no "$a: 선언된 쌍이 창에 없음 — $(printf '%s' "$missing" | tr '\n' ' ')(계약 불일치 — description 이 약속한 채널·값을 실제로는 그대로 안 준다)"
      fi
    fi
  fi
done
[ "$n" -eq 2 ] && ok "agent 2개 전부 실재" || no "agent 도출 ${n}개 — 2 여야 한다"
finish
