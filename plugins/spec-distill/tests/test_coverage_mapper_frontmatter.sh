#!/usr/bin/env bash
# AC7 — coverage-mapper 도구 표면 회귀 락 + Output 스키마 존재 (predecessor 에이전트 승계).
#
# ⚠️ tools 목록은 census 가 아니라 **문서화된 계약 + 보수적 최소**다(이전 tunneling-detector 에이전트 승계).
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/coverage-mapper.md"
pass=0; fail=0
note() { if [ "$1" = "PASS" ]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

test -f "$AGENT" || { note FAIL "agent 파일 부재: $AGENT"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }
FM="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$AGENT")"

grep -qE '^name: coverage-mapper$' <<<"$FM" \
  && note PASS "name: coverage-mapper (재명명)" || note FAIL "name이 coverage-mapper 아님"

grep -qE '^tools: Read, Grep, Glob$' <<<"$FM" \
  && note PASS "tools: Read, Grep, Glob (predecessor 에이전트 승계)" \
  || note FAIL "tools: 가 승계 목록과 다름"

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

# AC7: 재목적화 Output 스키마 키 (advisory 제안자)
grep -q 'derived_dimensions' "$AGENT" \
  && note PASS "Output: derived_dimensions 키 존재" || note FAIL "derived_dimensions 키 부재"
grep -q 'neglect_flag' "$AGENT" \
  && note PASS "Output: neglect_flag 키 존재" || note FAIL "neglect_flag 키 부재"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[ "$fail" -eq 0 ]
