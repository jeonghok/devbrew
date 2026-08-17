#!/usr/bin/env bash
# AC6 — blind-spot-prober 도구 표면(read-only Law 2) + Output 스키마 존재.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/blind-spot-prober.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

test -f "$AGENT" || { no "agent 파일 부재: $AGENT"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }
FM="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$AGENT")"

# 모델 티어 양방향 락 — 하니스가 세션 모델을 덮어쓰지 않는다(리터럴 핀 = 조용한 하향).
grep -qE '^model: inherit$' <<<"$FM" \
  && ok "model: inherit (세션 티어 상속)" || no "model이 inherit이 아님"
grep -qE '^model: (opus|sonnet|haiku)$' <<<"$FM" \
  && no "고정 티어 핀 잔존" || ok "고정 티어 핀 없음"

grep -qE '^name: blind-spot-prober$' <<<"$FM" \
  && ok "name: blind-spot-prober" || no "name이 blind-spot-prober 아님"

# web 근거가 필요하므로 WebSearch/WebFetch 보유 (steelman-builder와 동형), 쓰기는 부재.
grep -qE '^tools: Read, Grep, Glob, WebSearch, WebFetch$' <<<"$FM" \
  && ok "tools: Read, Grep, Glob, WebSearch, WebFetch" \
  || no "tools: 가 read-only+web 목록과 다름"

grep -qE '^(allowedTools|disallowedTools):' <<<"$FM" \
  && no "죽은 allowedTools / denylist 잔존" || ok "denylist 없음"

# Law 2: 쓰기·실행·위임 물리 부재
for t in Write Edit MultiEdit NotebookEdit Bash Agent Monitor; do
  grep -qE "^tools:.*(^|,)[[:space:]]*${t}[[:space:]]*(,|$)" <<<"$FM" \
    && no "tools: 에 $t 가 있다 (Law 2 위반)" \
    || ok "tools: 에 $t 없음"
done

# AC6: Output 스키마 키
grep -q 'hidden_assumptions' "$AGENT" \
  && ok "Output: hidden_assumptions 키 존재" || no "hidden_assumptions 키 부재"
grep -q 'failure_modes' "$AGENT" \
  && ok "Output: failure_modes 키 존재" || no "failure_modes 키 부재"

# E10 — 단일 호출 상한 표현 + 탐색 폭 좁힘 문구 부재.
# 하니스가 프롬프트로 검색 횟수를 묶으면 조사가 본질인 역할의 능력을 직접 깎는다.
# 패턴은 test_brief_agents.sh:194의 E10 락을 확장한 것이다(숫자 범위·병렬 금지 추가).
if grep -qE '최대 [0-9]+회|[0-9]+회까지|[0-9]–[0-9]회|[0-9]-[0-9]회|max_[a-z_]+ *= *[0-9]' "$AGENT"; then
  no "E10: 단일 호출 상한 표현 잔존"
else
  ok "E10: 상한 표현 없음"
fi
if grep -qE '병렬.{0,8}금지|투기적.{0,8}금지' "$AGENT"; then
  no "E10: 병렬·투기적 호출 금지 문구 잔존 (탐색 폭 좁힘)"
else
  ok "E10: 병렬 금지 문구 없음"
fi
finish
