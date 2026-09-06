#!/usr/bin/env bash
# AC7 — coverage-mapper 도구 표면 회귀 락 + Output 스키마 존재 (predecessor 에이전트 승계).
#
# ⚠️ tools 목록은 census 가 아니라 **문서화된 계약 + 보수적 최소**다(이전 tunneling-detector 에이전트 승계).
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/coverage-mapper.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

test -f "$AGENT" || { no "agent 파일 부재: $AGENT"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }
FM="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$AGENT")"

# 모델 티어 락 — frontmatter 에 model 키를 두지 않는다. 리터럴 핀은 세션 선택을,
# `inherit` 는 사용자의 subagent 기본 티어 설정을 덮어쓴다(CLI 2.1.261 실측).
MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
grep -qE "$MODEL_KEY" <<<"$FM" \
  && no "frontmatter 에 model 키가 있다 — 하니스가 티어를 정한다" \
  || ok "frontmatter 에 model 키 없음 (tier-unpinned)"

grep -qE '^name: coverage-mapper$' <<<"$FM" \
  && ok "name: coverage-mapper (재명명)" || no "name이 coverage-mapper 아님"

grep -qE '^tools: Read, Grep, Glob, WebSearch, WebFetch$' <<<"$FM" \
  && ok "tools: Read, Grep, Glob, WebSearch, WebFetch (조사 도구 결핍 해소)" \
  || no "tools: 가 조사 도구 결핍 해소 목록과 다름"

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

# AC7: 재목적화 Output 스키마 키 (advisory 제안자)
grep -q 'derived_dimensions' "$AGENT" \
  && ok "Output: derived_dimensions 키 존재" || no "derived_dimensions 키 부재"
grep -q 'neglect_flag' "$AGENT" \
  && ok "Output: neglect_flag 키 존재" || no "neglect_flag 키 부재"
finish
