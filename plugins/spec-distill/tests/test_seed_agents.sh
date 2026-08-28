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
# ── 관계 축 2 (fix round 4 — 펜스별 결속) — 매 dispatch 펜스가 «단독으로» <태그>${변수}
#    쌍을 description 선언과 일치시킨다 ────────────────────────────────────────
# 도구 표면이 0 이어도 SKILL.md 의 dispatch 프롬프트가 description 이 약속하지 않은
# 것을 인라인하면 격리는 여전히 샌다. round 2 는 태그 **이름**의 집합만, round 3 는
# 태그+변수 **쌍**을 걸었지만, 그 agent 이름을 언급하는 펜스가 여럿이면 **합집합**으로
# 재비교했다 — 재리뷰가 실측으로 뚫었다: 죽은/예시 펜스가 옳은 쌍을 갖고 있으면, 진짜
# dispatch 펜스가 태그 없이 `${BLOB}` 를 맨몸으로 흘려도 합집합에는 결손이 안 보인다.
# 이제 그 agent 이름을 언급하는 **펜스마다 독립적으로** 자기 쌍 집합이 선언과 정확히
# 일치해야 한다 — 한 펜스라도 어긋나면 그 펜스가 RED 를 낸다. 합집합은 개별 펜스의
# 결손을 가릴 수 있지만 펜스별 결속은 가릴 수 없다.
#
# **"진짜 dispatch 냐 예시냐"를 가르는 별도 규칙을 두지 않았다.** 그 이름 뒤에
# `subagent_type: "spec-distill:<name>"` 리터럴을 쓰는 순간 이 리포의 기존 관례
# (`shared/tests/test_dispatch_disposition.sh` 의 NOTATION 정규식)가 이미 그 줄을
# dispatch 로 세고 앵커(`// **처분** —`)까지 요구한다. 이 락이 별도 구분 규칙을 새로
# 만들면 그 규칙 자체가 다음 우회 표적이 된다(예: "펜스 앞에 `// 예시` 주석이 있으면
# 면제"라고 하면 그 주석 한 줄이 새 우회다). 대신 기존 락이 이미 강제하는 정의를 그대로
# 물려받는다 — 그 리터럴을 쓰면 dispatch 로 취급되고, dispatch 로 취급되면 이 축도
# 검사한다. 새 구분자를 발명하지 않는 것이 우회 표면을 늘리지 않는 길이다.
#
# **도출, 하드코딩 아님.** description 의 백틱 리터럴이 쌍 전체를 담는다
# (`<draft>${BLOB}</draft>`, `<seed>${SEED}</seed>`) — 쌍을 도출했던 것과 같은 방법으로
# 펜스마다 뽑아 대조한다. 태그의 `>` 와 `${` 사이 공백은 **허용**한다(`<draft>
# ${BLOB}</draft>` 같은 의미보존 재서식이 거짓 RED 를 내던 round 3 의 과잉엄격을
# 없앴다) — 조여야 하는 것은 쌍의 «관계»지 서식의 «인접성»이 아니다.
#
# **이 축이 못 보는 것 (round 5 — 재검증 후 다시 씀. 이전 판은 검증 없이 썼다가
# 틀린 항목을 실재하는 갭 옆에 나란히 적어, 실제보다 넓게 덮는 것처럼 읽혔다).** 이것은
# **정적 텍스트 대조**다. 아래 두 항목은 **각각 실제로 돌려서 관측**했다 —
# `plugins/spec-distill/tests/test_seed_agents.sh` 와
# `shared/tests/test_dispatch_disposition.sh` 양쪽의 실행 결과를 근거로 삼는다.
#
#  1. **데이터 흐름.** `<seed>${SEED}</seed>` 에서 태그·변수 «이름」이 둘 다 옳아도,
#     `SEED` 가 이 dispatch 지점 «위» 어딘가에서 실제로 무엇에 할당됐는지는 안 본다.
#     실측(round 3, round 5 재확인): dispatch 바로 위에 `SEED = BLOB;` 를 심어도 이
#     락은 15/15 GREEN 이다 — 실행 시점 값을 추적하려면 데이터-흐름 분석이 필요하고
#     텍스트 대조는 그 종류의 사실을 볼 수 없다.
#
#  2. **이름을 계산으로 쪼개는 것.** `P1 = "spec-distill:"; P2 = "seed-readback";
#     subagent_type: P1 + P2` 처럼 이름을 문자열 연결로 쪼개면 이 락도 리포의 dispatch
#     회계 락(`shared/tests/test_dispatch_disposition.sh`)도 **완전히 침묵한다.**
#     실측(round 5): 진짜 dispatch 는 그대로 두고 이 형태의 죽은 펜스를 옆에 추가해
#     초안을 seed 채널로 흘려도 이 락 15/15 GREEN, 회계 락 19/19 GREEN — 어느 쪽도
#     그 펜스를 dispatch 로조차 세지 않는다. 이 락의 펜스 매칭(`index(buf, pat)`,
#     `pat` 는 `"spec-distill:<name>"` 리터럴 통짜)도, 회계 락의 이름-경계 정규식도
#     **소스 텍스트에 그 리터럴 문자열이 그대로 붙어 있는지**를 본다 — 두 리터럴을
#     런타임에만 이어 붙이면 정적 검사가 볼 수 있는 범위를 완전히 벗어난다. 흔한
#     실수로 보이지 않는다는 이유로 이 사실을 축소해 적지 않는다 — 이것이 실제 경계다.
#     **이 갭이 안전한 이유는 이 두 락이 아니라 별개의 사실이다**: 두 agent 의 실제
#     격리는 `tools: []` 런타임 강제이지 이 두 락이 아니다 — 이 락들은 SKILL.md 와
#     description 두 파일에 적힌 계약이 서로 맞는지를 재는 defence-in-depth 이고, 이
#     갭이 뚫려도 도구 표면은 여전히 0 이다.
#
#     **다음 항목은 위 두 갭과 같은 부류가 아니라서 뺐다 — 실측으로 둘 다 이미
#     잡는 것을 확인했다(round 5, 이전 판의 오기 정정):** ```javascript 가 아닌 다른
#     펜스 언어 태그, 그리고 코드펜스를 아예 없앤 산문 언급. 둘 다 이 락을
#     "SKILL.md 에서 dispatch 펜스(```javascript)를 못 찾았다" 로 RED 시킨다(다른
#     펜스는 있는데 원하는 언어의 펜스가 없다는 신호를 그대로 낸다) — 의도한
#     쌍-불일치 단언이 아니라 이 fallback 단언으로 잡히지만, 잡히는 것은 실측으로
#     같다.
#
# **주의 — 과잉엄격(막지는 않지만 알아둘 것, round 5 실측).** "DO NOT USE" 같은 반례를
# ```javascript 펜스 안에 `subagent_type: "spec-distill:<name>"` 리터럴로 적으면 이
# 락은 그것도 실제 dispatch 로 간주해 검사하고 의도적으로 어긋난 쌍이 있으면 RED 를
# 낸다. **거짓 GREEN 을 만들지는 않는다**(안전한 방향의 과잉엄격)지만, 다음 저자가 이
# 파일에 반례를 남기면 이유를 모른 채 막힌다.
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

# extract_dispatch_windows <agent-name> → 그 agent 를 이름으로 언급하는 ```javascript
#   펜스 «전부」를, 펜스마다 하나씩, 사람이 읽을 수 있는 경계 마커 줄로 나눠 낸다.
#   round 3 까지는 매칭 펜스 전체를 하나의 버퍼로 합쳐 냈다 — 죽은 펜스가 진짜 펜스의
#   결손을 가렸다(round 4 재리뷰 실측). 이제 펜스를 독립 단위로 낸다. 경계는 raw
#   바이트(0x1E 등)가 아니라 평범한 텍스트 줄이다 — awk 구현마다 `\x` 이스케이프
#   지원이 갈리는 위험을 피하고, bash 쪽도 일반 `read` 로 그대로 나눌 수 있다.
extract_dispatch_windows() {
  awk -v pat="\"spec-distill:$1\"" '
    /^```javascript[[:space:]]*$/ { buf=""; capturing=1; next }
    capturing && /^```[[:space:]]*$/ {
      if (index(buf, pat) > 0) { printf "%s", buf; print "@@FENCE_BOUNDARY_4f9c2a@@" }
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

# 태그 바로 뒤(공백 허용) `${변수}` 인접 쌍 → "태그=변수" 로 정규화.
PAIR_RE='<[a-zA-Z_][a-zA-Z0-9_]*>[[:space:]]*\$\{[A-Za-z_][A-Za-z0-9_]*\}'
PAIR_SED='s/^<([a-zA-Z_][a-zA-Z0-9_]*)>[[:space:]]*\$\{([A-Za-z_][A-Za-z0-9_]*)\}$/\1=\2/'

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

  # ── 관계 축 2: agent 를 언급하는 펜스 «각각」이 자기 (태그,변수) 쌍을 description
  # 선언과 정확히 일치시켜야 한다(round 4 — 펜스별 결속, 합집합 아님).
  expected="$(printf '%s\n' "$fm" | grep -oE "$PAIR_RE" | sed -E "$PAIR_SED" | sort -u)"
  n_expected="$(printf '%s\n' "$expected" | grep -c . || true)"
  if [ "$n_expected" -lt 1 ]; then
    no "$a: description 에서 <태그>\${변수} 쌍 선언을 하나도 도출 못 함 — 이 축이 vacuous 하다"
  else
    ok "$a: description 에서 쌍 선언 ${n_expected}개 도출 — {$(printf '%s' "$expected" | tr '\n' ' ')}"
    windows_raw="$(extract_dispatch_windows "$a")"
    if [ -z "$windows_raw" ]; then
      no "$a: SKILL.md 에서 dispatch 펜스(\`\`\`javascript)를 못 찾았다"
    else
      fence_n=0
      buf=""
      while IFS= read -r line || [ -n "$line" ]; do
        if [ "$line" = "@@FENCE_BOUNDARY_4f9c2a@@" ]; then
          fence_n=$((fence_n + 1))
          actual="$(printf '%s' "$buf" | grep -oE "$PAIR_RE" | sed -E "$PAIR_SED" | sort -u)"
          extra="$(set_diff "$actual" "$expected")"
          missing="$(set_diff "$expected" "$actual")"
          if [ -z "$extra" ] && [ -z "$missing" ]; then
            ok "$a: 펜스 #${fence_n} 의 (태그,변수) 쌍이 description 선언과 정확히 일치 — {$(printf '%s' "$actual" | tr '\n' ' ')}"
          else
            [ -n "$extra" ] \
              && no "$a: 펜스 #${fence_n} 에 선언 밖 쌍 — $(printf '%s' "$extra" | tr '\n' ' ')(격리가 샌다 — 이 채널이나 그 값이 description 약속과 다르다)"
            [ -n "$missing" ] \
              && no "$a: 펜스 #${fence_n} 에 선언된 쌍 없음 — $(printf '%s' "$missing" | tr '\n' ' ')(계약 불일치 — 이 펜스 «단독으로» description 이 약속한 채널·값을 그대로 안 준다)"
          fi
          buf=""
        else
          buf="$buf$line"$'\n'
        fi
      done <<< "$windows_raw"
      [ "$fence_n" -ge 1 ] || no "$a: 펜스 분리 도출이 0건 — extract_dispatch_windows 가 깨졌다"
    fi
  fi
done
[ "$n" -eq 2 ] && ok "agent 2개 전부 실재" || no "agent 도출 ${n}개 — 2 여야 한다"
finish
