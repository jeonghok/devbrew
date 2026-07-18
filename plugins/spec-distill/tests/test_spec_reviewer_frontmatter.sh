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
pass=0; fail=0
note() { if [ "$1" = "PASS" ]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

test -f "$AGENT" || { note FAIL "agent 파일 부재: $AGENT"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }
FM="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$AGENT")"

grep -qE '^tools: Read, Grep, Glob, WebFetch$' <<<"$FM" \
  && note PASS "tools: Read, Grep, Glob, WebFetch (census 도출)" \
  || note FAIL "tools: 가 census 도출 목록과 다름"

grep -qE '^(allowedTools|disallowedTools):' <<<"$FM" \
  && note FAIL "죽은 allowedTools / denylist 잔존" \
  || note PASS "allowedTools · disallowedTools 없음"

# Law 2: 쓰기·실행·위임이 물리적으로 부재
for t in Write Edit MultiEdit NotebookEdit Bash Agent Monitor; do
  grep -qE "^tools:.*(^|,)[[:space:]]*${t}[[:space:]]*(,|$)" <<<"$FM" \
    && note FAIL "tools: 에 $t 가 있다 (Law 2 위반)" \
    || note PASS "tools: 에 $t 없음"
done
grep -qE '^tools:.*mcp__' <<<"$FM" \
  && note FAIL "tools: 에 MCP grant" || note PASS "tools: 에 MCP 없음"

# WebFetch 는 census 근거로 유지되어야 한다 — 조용한 열화 방지 (spec §12).
grep -qE '^tools:.*WebFetch' <<<"$FM" \
  && note PASS "WebFetch 유지 (공식 문서 검증에 실사용 — census 2회)" \
  || note FAIL "WebFetch 가 제거됐다 — 리뷰 품질 조용한 열화"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[ "$fail" -eq 0 ]
