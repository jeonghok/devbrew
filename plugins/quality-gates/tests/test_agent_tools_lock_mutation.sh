#!/usr/bin/env bash
# AC9 — test_agent_frontmatter_keys.sh 의 이빨 증명. 12 mutation 전부에서 RED 여야 한다.
# RED 가 안 나는 락은 장식이다.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LOCK="$ROOT/plugins/quality-gates/tests/test_agent_frontmatter_keys.sh"
PASS=0; FAIL=0

# GC9: mktemp 가드 — 대입 실패 시 trap arm 전에 abort. 빈 변수가 cwd 로 laundering 되면
# trap 의 rm -rf 가 repo 를 지운다.
TMP="$(mktemp -d)" || { echo "FAIL: mktemp 실패"; exit 1; }
[ -n "$TMP" ] && [ -d "$TMP" ] || { echo "FAIL: TMP 가 유효한 디렉토리가 아님"; exit 1; }
trap 'rm -rf "$TMP"' EXIT

FIX="$TMP/plugins/probe/agents"
mkdir -p "$FIX" || exit 1

# 기준선: 이 픽스처는 GREEN 이어야 한다. 아니면 아래 mutation 의 RED 는 무의미하다.
write_agent() {
  printf -- '---\nname: probe\ndescription: fixture\nmodel: inherit\n%s\n---\n\nbody\n' "$1" > "$FIX/probe.md"
}

expect() {  # expect <RED|GREEN> <설명>
  local want="$1" msg="$2"
  if bash "$LOCK" "$TMP" >/dev/null 2>&1; then local got=GREEN; else local got=RED; fi
  if [ "$got" = "$want" ]; then PASS=$((PASS+1)); echo "  ✓ $msg ($got)"
  else FAIL=$((FAIL+1)); echo "  ✗ FAIL: $msg — want $want, got $got"; fi
}

echo "== 기준선 =="
write_agent 'tools: Read, Grep, Glob'
expect GREEN "정상 allowlist 는 통과"

echo "== ① allowedTools 재도입 =="
write_agent 'tools: Read, Grep, Glob
allowedTools:
  - Read'
expect RED "allowedTools 재도입"

echo "== ② kebab 재도입 =="
write_agent 'tools: Read, Grep, Glob
allowed-tools:
  - Read'
expect RED "kebab allowed-tools 재도입"

echo "== ③ tools: 제거 =="
write_agent 'disallowedTools:
  - Write'
expect RED "tools: 부재 (카브아웃 없음)"

echo "== ④ 금지 8종 각각을 마커 없이 추가 =="
for t in Write Edit MultiEdit NotebookEdit Agent Bash Monitor 'mcp__*'; do
  write_agent "tools: Read, Grep, Glob, $t"
  expect RED "마커 없는 금지 도구: $t"
done

echo "== ⑤ 다른 도구의 마커만 있는 채 금지 도구 추가 (1:1 매칭 이빨) =="
write_agent '# TOOL-EXCEPTION: Bash — 근거가 있는 척
tools: Read, Grep, Glob, Write'
expect RED "Bash 마커가 Write 를 정당화하지 못함"

# 🔴 위치 독립성 — 이 3건을 지우지 말 것.
# 실측: 토큰 루프의 후행-개행 버그는 **마지막 토큰만** 조용히 버렸다. ④·⑤ 가 전부
# 금지 도구를 맨 뒤에 두기 때문에, 이 3건이 없으면 그 버그가 12/12 GREEN 으로 통과한다.
echo "== 위치 독립성 (마지막-토큰 드롭 회귀 감지) =="
write_agent 'tools: Write, Read, Grep'
expect RED "금지 도구가 맨앞"
write_agent 'tools: Read, Bash, Grep'
expect RED "금지 도구가 중간"
write_agent 'tools: Read, Grep, Monitor'
expect RED "금지 도구가 맨끝"

echo "== 보강: 마커가 있으면 통과 (예외 경로가 실제로 열리는지) =="
write_agent '# TOOL-EXCEPTION: Bash — sandbox executor
tools: Read, Grep, Glob, Bash'
expect GREEN "자기 이름 마커가 있는 금지 도구는 통과"

echo "== 보강: per-tool MCP 정확 이름은 마커 없이 통과 (AC6 과의 정합) =="
write_agent 'tools: Read, mcp__plugin_chrome-devtools-mcp_chrome-devtools__click'
expect GREEN "per-tool MCP 정확 이름은 서버 grant 가 아님"

echo "== 보강: 서버 단위 grant 는 RED =="
write_agent 'tools: Read, mcp__plugin_chrome-devtools-mcp_chrome-devtools'
expect RED "mcp__<server> 서버 단위 grant"
write_agent 'tools: Read, mcp__plugin_chrome-devtools-mcp_chrome-devtools__*'
expect RED "mcp__<server>__* 서버 전체 grant"

echo; echo "mutation: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
