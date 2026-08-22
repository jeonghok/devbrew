#!/usr/bin/env bash
# AC5 / AC11 — security-reviewer kill switch 가 **dispatch 지점을 지배하는지** 재는 구조 락.
#
# ── 이 락이 재는 것 ─────────────────────────────────────────────────────────
#  · SKILL.md 의 **모든** `subagent_type: "quality-gates:security-reviewer"` dispatch
#    리터럴에 대해(∀), 그 **바로 위 창** 안에 kill switch 게이트가 서 있다 —
#    env 토큰 · `IF <ENV>=1:` 조건 · loud advisory 배너 원문 · "발행하지 않는다" 지시.
#  · 창은 **파일 구조에서 매번 도출**한다. 리터럴 줄번호를 박지 않는다 — 이 리포에서
#    줄번호 인용이 리팩터로 썩은 전례가 있다(감사 §7-11, +24 어긋남 13건).
#
# ── 이 락이 **재지 않는 것** (경계를 안 적으면 다음 사람이 GREEN 을 오독한다) ──
#  · **LLM 이 그 지시를 따르는지는 재지 않는다.** SKILL.md 는 실행되는 코드가 아니라
#    모델이 읽는 **산문**이다. 이 GREEN 은 *"지시가 dispatch 지점에 서 있다"* 까지이고
#    *"스위치가 실제로 security-reviewer 를 끈다"* 가 아니다 — 후자는 integration
#    smoke(AC10b, opt-in)의 몫이다.
#  · **산문의 의미 반전**은 못 잡는다. IF/ELSE 본문을 통째로 맞바꾸거나 "발행하지
#    않는다" 를 다른 낱말로 바꿔 쓰면 토큰이 남아 이 grep 을 통과한다(실측 확인함).
#    잡는 것은 **토큰 수준** 훼손뿐이다 — 조건 반전(`!=1`), env 이름 오타, 게이트 삭제,
#    게이트를 dispatch 뒤로 이동.
#  · **SKILL.md 밖**의 dispatch 는 보지 않는다(현재 리포에 실재 dispatch 는 여기 하나).
#  · 게이트 **아래쪽** 문서(Step 4.5 verdict advisory · Environment 색인)의 정확성은
#    재지 않는다. 그 둘은 이 락의 **decoy** 이며 창 밖임을 아래에서 못 박는다.
set -eu
REPO_ROOT="$(git rev-parse --show-toplevel)"
SKILL="$REPO_ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"

if [ ! -f "$SKILL" ]; then
  echo "  FAIL: SKILL.md missing at $SKILL" >&2; exit 1
fi

set +e
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

ENV_NAME='DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER'
DISPATCH_LIT='subagent_type: "quality-gates:security-reviewer"'

# ── (1) 완전 소멸 락 — 파일 전체 ∃ 카운트 ────────────────────────────────────
# 이 셋만으로는 게이트 삭제를 **못 잡는다**(색인·verdict 배너가 decoy 로 만족시킨다).
# 그래도 지우지 않는다: 스위치가 문서에서 통째로 사라지는 경우는 이쪽이 잡는다.
assert_count_ge "grep -c '$ENV_NAME' '$SKILL'" 1 \
  "kill switch env var present"

assert_count_ge "grep -cE 'security-reviewer disabled|security-reviewer.*DEVBREW_QUALITY_GATES_DISABLE' '$SKILL'" 1 \
  "disable log message present"

assert_count_ge "grep -c 'security-reviewer' '$SKILL'" 3 \
  "security-reviewer dispatch reference count"

# ── (2) 창 도출 — 구조에서, 줄번호 없이 ──────────────────────────────────────
# 창 = (직전 구조 경계, dispatch 를 감싼 코드펜스의 시작) 사이의 산문 구간.
#   · 구조 경계 = 펜스 밖 마크다운 heading **또는** 직전 코드펜스의 닫힘 — 더 가까운 쪽.
#   · 창은 dispatch **위**에서 끝난다 → dispatch 아래의 decoy 는 구조적으로 창 밖이다.
# 출력 한 줄 = "<창시작> <창끝> <dispatch 줄>".
WINDOWS="$(awk -v lit="$DISPATCH_LIT" '
  { t = $0; gsub(/^[ \t]+|[ \t]+$/, "", t) }
  t ~ /^```/ { if (fence == 0) { fence = 1; fopen = NR } else { fence = 0; bound = NR } ; next }
  !fence && /^#+[ ]/ { bound = NR }
  index($0, lit) > 0 { print (bound + 1) " " ((fence ? fopen : NR) - 1) " " NR }
' "$SKILL")"

# 양성 대조 — dispatch 가 0 이면 아래의 ∀ 는 공허하게 통과한다. 먼저 실재를 못 박는다.
assert_count_ge "grep -cF '$DISPATCH_LIT' '$SKILL'" 1 \
  "dispatch 리터럴이 최소 하나 실재 (∀ 가 공허하지 않다는 양성 대조)"

# 계측기 자기점검 — 창 도출기가 grep 이 보는 dispatch 를 하나도 놓치지 않았는가.
grep_n="$(grep -cF "$DISPATCH_LIT" "$SKILL")"
awk_n="$(printf '%s\n' "$WINDOWS" | grep -c '[0-9]')"
assert_eq "$awk_n" "$grep_n" "창 도출기가 dispatch 를 하나도 놓치지 않았다 (계측기 자기점검)"

# ── (3) ∀ dispatch: 창이 게이트를 담고 있는가 ────────────────────────────────
miss_env=0; miss_cond=0; miss_banner=0; miss_skip=0
decoy_verdict_in=0; decoy_index_in=0

decoy_verdict_lines="$(grep -nF '보안 리뷰를 통과했다' "$SKILL" | cut -d: -f1)"
decoy_index_lines="$(grep -nF 'Review gate Tier A floor의' "$SKILL" | cut -d: -f1)"

while read -r s e d; do
  [ -n "${d:-}" ] || continue
  wtext="$(awk -v s="$s" -v e="$e" 'NR >= s && NR <= e' "$SKILL")"

  if ! printf '%s\n' "$wtext" | grep -qF "$ENV_NAME"; then
    miss_env=$((miss_env + 1))
    printf '      [창 이탈] dispatch:%s 창[%s,%s] — env 토큰 %s 없음\n' "$d" "$s" "$e" "$ENV_NAME"
  fi
  if ! printf '%s\n' "$wtext" | grep -qE "^[[:space:]]*IF .*${ENV_NAME}=1"; then
    miss_cond=$((miss_cond + 1))
    printf '      [창 이탈] dispatch:%s 창[%s,%s] — IF %s=1 조건 없음/훼손\n' "$d" "$s" "$e" "$ENV_NAME"
  fi
  if ! printf '%s\n' "$wtext" | grep -qF "security-reviewer disabled via ${ENV_NAME}=1"; then
    miss_banner=$((miss_banner + 1))
    printf '      [창 이탈] dispatch:%s 창[%s,%s] — loud advisory 배너 원문 없음\n' "$d" "$s" "$e"
  fi
  if ! printf '%s\n' "$wtext" | grep -qF '발행하지 않는다'; then
    miss_skip=$((miss_skip + 1))
    printf '      [창 이탈] dispatch:%s 창[%s,%s] — "발행하지 않는다" 지시 없음\n' "$d" "$s" "$e"
  fi

  for ln in $decoy_verdict_lines; do
    if [ "$ln" -ge "$s" ] && [ "$ln" -le "$e" ]; then
      decoy_verdict_in=$((decoy_verdict_in + 1))
      printf '      [창 과대] dispatch:%s 창[%s,%s] 이 verdict advisory(:%s)를 삼켰다\n' "$d" "$s" "$e" "$ln"
    fi
  done
  for ln in $decoy_index_lines; do
    if [ "$ln" -ge "$s" ] && [ "$ln" -le "$e" ]; then
      decoy_index_in=$((decoy_index_in + 1))
      printf '      [창 과대] dispatch:%s 창[%s,%s] 이 Environment 색인(:%s)을 삼켰다\n' "$d" "$s" "$e" "$ln"
    fi
  done
done <<WINEOF
$WINDOWS
WINEOF

assert_eq "$miss_env" 0     "∀ dispatch — 창 안에 kill switch env 토큰이 있다"
assert_eq "$miss_cond" 0    "∀ dispatch — 창 안에 'IF <ENV>=1' 조건이 훼손 없이 있다"
assert_eq "$miss_banner" 0  "∀ dispatch — 창 안에 loud advisory 배너 원문이 있다"
assert_eq "$miss_skip" 0    "∀ dispatch — 창 안에 '발행하지 않는다' 지시가 있다"

# ── (4) decoy 배제 — 창이 아래쪽 ∃-만족자를 삼키지 않는가 ────────────────────
# 음의 락에는 양의 짝이 필요하다: decoy 가 파일에서 사라지면 "창 밖" 은 공허해진다.
assert_count_ge "grep -cF '보안 리뷰를 통과했다' '$SKILL'" 1 \
  "decoy① Step 4.5 verdict advisory 가 파일에 실재 (창-밖 검사의 양성 짝)"
assert_count_ge "grep -cF 'Review gate Tier A floor의' '$SKILL'" 1 \
  "decoy② Environment 색인이 파일에 실재 (창-밖 검사의 양성 짝)"

assert_eq "$decoy_verdict_in" 0 "decoy① verdict advisory 는 모든 창 밖이다"
assert_eq "$decoy_index_in" 0   "decoy② Environment 색인은 모든 창 밖이다"

finish
