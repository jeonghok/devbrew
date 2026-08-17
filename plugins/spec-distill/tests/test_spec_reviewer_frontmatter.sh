#!/usr/bin/env bash
# AC17 — spec-reviewer 도구 표면 회귀 락 (v0.21.0 신설).
#
# 왜 신설인가: 이 agent 는 devbrew 에서 가장 많이 dispatch 되는 리뷰어인데 도구 표면
# 락이 **없었다**. before-census 실측(실제 리뷰 3회): Bash×45 · Read×7 · WebFetch×2 ·
# Grep×0 · Glob×0. persona 는 Bash 를 한 번도 지시하지 않는데 45회 부르고, 선언에 없는
# WebFetch 로 공식 문서를 검증했다 — 선언과 실사용이 양방향으로 어긋나 있었다.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/spec-reviewer.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

test -f "$AGENT" || { no "agent 파일 부재: $AGENT"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }
FM="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$AGENT")"

# 모델 티어 양방향 락 — 하니스가 세션의 모델 선택을 덮어쓰지 않는다.
# 이 리뷰어는 devbrew에서 가장 많이 dispatch되는 리뷰어인데 `model: sonnet`으로
# 핀돼 있었다: 실측 6회 전부 opus-5 세션이 sonnet-5 리뷰어를 받았다 — 리뷰어가
# writer보다 약한 상태가 매 dispatch 재현됐다.
# positive+negative 둘 다 필요하다. negative만 두면 `model:` 줄을 통째로 지워도
# 통과하고, positive만 두면 두 줄을 넣는 mutation이 통과한다.
grep -qE '^model: inherit$' <<<"$FM" \
  && ok "model: inherit (세션 티어 상속)" \
  || no "model이 inherit이 아님 — 하니스가 티어를 덮어쓴다"
grep -qE '^model: (opus|sonnet|haiku)$' <<<"$FM" \
  && no "고정 티어 핀 잔존" \
  || ok "고정 티어 핀 없음"

grep -qE '^tools: Read, Grep, Glob, WebSearch, WebFetch$' <<<"$FM" \
  && ok "tools: Read, Grep, Glob, WebSearch, WebFetch (조사 도구 결핍 해소)" \
  || no "tools: 가 census 도출 목록과 다름"

grep -qE '^(allowedTools|disallowedTools):' <<<"$FM" \
  && no "죽은 allowedTools / denylist 잔존" \
  || ok "allowedTools · disallowedTools 없음"

# Law 2: 쓰기·실행·위임이 물리적으로 부재
for t in Write Edit MultiEdit NotebookEdit Bash Agent Monitor; do
  grep -qE "^tools:.*(^|,)[[:space:]]*${t}[[:space:]]*(,|$)" <<<"$FM" \
    && no "tools: 에 $t 가 있다 (Law 2 위반)" \
    || ok "tools: 에 $t 없음"
done
grep -qE '^tools:.*mcp__' <<<"$FM" \
  && no "tools: 에 MCP grant" || ok "tools: 에 MCP 없음"

# WebSearch/WebFetch 는 유지되어야 한다 — 조용한 열화 방지 (spec §12).
for tool in WebSearch WebFetch; do
  grep -qE "^tools:.*${tool}" <<<"$FM" \
    && ok "tools: 에 $tool 유지" \
    || no "tools: 에서 $tool 이 사라졌다 — 외부 근거 확인 불가"
done
finish
