#!/usr/bin/env bash
# AC6 — blind-spot-prober 도구 표면(read-only Law 2) + Output 스키마 존재.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/blind-spot-prober.md"
pass=0; fail=0
note() { if [ "$1" = "PASS" ]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

test -f "$AGENT" || { note FAIL "agent 파일 부재: $AGENT"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }
FM="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$AGENT")"

grep -qE '^name: blind-spot-prober$' <<<"$FM" \
  && note PASS "name: blind-spot-prober" || note FAIL "name이 blind-spot-prober 아님"

# web 근거가 필요하므로 WebSearch/WebFetch 보유 (steelman-builder와 동형), 쓰기는 부재.
grep -qE '^tools: Read, Grep, Glob, WebSearch, WebFetch$' <<<"$FM" \
  && note PASS "tools: Read, Grep, Glob, WebSearch, WebFetch" \
  || note FAIL "tools: 가 read-only+web 목록과 다름"

grep -qE '^(allowedTools|disallowedTools):' <<<"$FM" \
  && note FAIL "죽은 allowedTools / denylist 잔존" || note PASS "denylist 없음"

# Law 2: 쓰기·실행·위임 물리 부재
for t in Write Edit MultiEdit NotebookEdit Bash Agent Monitor; do
  grep -qE "^tools:.*(^|,)[[:space:]]*${t}[[:space:]]*(,|$)" <<<"$FM" \
    && note FAIL "tools: 에 $t 가 있다 (Law 2 위반)" \
    || note PASS "tools: 에 $t 없음"
done

# AC6: Output 스키마 키
grep -q 'hidden_assumptions' "$AGENT" \
  && note PASS "Output: hidden_assumptions 키 존재" || note FAIL "hidden_assumptions 키 부재"
grep -q 'failure_modes' "$AGENT" \
  && note PASS "Output: failure_modes 키 존재" || note FAIL "failure_modes 키 부재"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[ "$fail" -eq 0 ]
