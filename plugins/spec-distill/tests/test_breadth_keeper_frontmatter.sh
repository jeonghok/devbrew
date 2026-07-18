#!/usr/bin/env bash
# AC17 — breadth-keeper 도구 표면 회귀 락 (v0.21.0 신설).
#
# ⚠️ 이 목록은 census 가 아니라 **문서화된 계약 + 보수적 최소**로 정해졌다: 프로브를
# persona 가 거절해 실사용을 측정하지 못했고, "거절이 capability 에서 오는지 persona 에서
# 오는지" 구별할 수 없었다. 도구가 부족하다는 증거가 나오면 census 후 이 락을 고칠 것.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/breadth-keeper.md"
pass=0; fail=0
note() { if [ "$1" = "PASS" ]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

test -f "$AGENT" || { note FAIL "agent 파일 부재: $AGENT"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }
FM="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$AGENT")"

grep -qE '^tools: Read, Grep, Glob$' <<<"$FM" \
  && note PASS "tools: Read, Grep, Glob (census 도출)" \
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

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[ "$fail" -eq 0 ]
