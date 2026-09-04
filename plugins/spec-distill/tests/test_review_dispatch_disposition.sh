#!/usr/bin/env bash
# guards: plugins/spec-distill/hooks/review-dispatch.py
#
# 훅의 차단 결정 두 자리가 자기 처분을 원장 어휘로 밝히는지 검사한다.
#
# 채널은 `reason` 이다. `systemMessage` 는 모델 컨텍스트에 도달하지 않는다
# (카나리 14개 중 0개). `reason` 은 차단 결정에 딸릴 때 7/7 도달한다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../../shared/tests/assert.sh"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/review-dispatch.py"

BODY="$(cat "$HOOK")"

assert_grep "$BODY" 'from adjudication import Ledger' \
  "훅이 원장을 import 한다 (㉮ 에 들어온다 — L1 의 대상이 된다)"

# 차단 결정 자리마다 처분 호출이 있는지. 자리 «수»에서 출발한다 —
# 하나를 배선하고 다른 하나를 잊는 것이 이 검사가 막는 것이다.
nblock="$(printf '%s\n' "$BODY" | grep -c '"decision": "block"')"
ndisp="$(printf '%s\n' "$BODY" | grep -cE '\.(hold|reject|source_failed|uncountable)\(')"
note "차단 결정 $nblock 자리 · 처분 호출 $ndisp 건"
if [ "${nblock:-0}" -gt 0 ] 2>/dev/null; then
  ok "차단 결정 $nblock 자리 (0 이 아니다)"
else
  no "차단 결정이 0 이다 — grep 이 깨졌거나 분기가 사라졌다. 이 검사가 공허하다"
fi
if [ "${ndisp:-0}" -ge "${nblock:-0}" ] 2>/dev/null; then
  ok "처분 호출 $ndisp >= 차단 자리 $nblock"
else
  no "차단 자리 $nblock 중 $((nblock - ndisp)) 곳이 처분을 안 부른다"
fi

# `reason` 에 원장 사유가 실리는지 — 채널을 못 박는다.
assert_grep "$BODY" 'reasons\(\)' \
  "원장의 reasons() 를 읽는다 (원장 객체는 프로세스와 함께 사라진다)"
assert_not_grep "$BODY" 'systemMessage.*reasons\(\)' \
  "원장 사유를 systemMessage 로 보내지 않는다 (모델 도달 0/14)"

finish
