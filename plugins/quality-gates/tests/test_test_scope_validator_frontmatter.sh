#!/usr/bin/env bash
# Tests for agents/test-scope-validator.md frontmatter — verifies Plugin Shape
# compliance: allowedTools / disallowedTools / model / cost_class declarations.
# Mirrors style of test_runtime_verifier_frontmatter.sh.

set -u

AGENT="$(cd "$(dirname "$0")/.." && pwd)/agents/test-scope-validator.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

if [ ! -f "$AGENT" ]; then
  echo "  ✗ FAIL: agent file missing: $AGENT"
  exit 1
fi

# Extract markdown body (everything after the SECOND '---' line).
BODY=$(awk '/^---$/{c++; next} c>=2' "$AGENT")

# Extract frontmatter block (between first two '---' lines).
FM=$(awk '/^---$/{c++; next} c==1' "$AGENT")

echo "== Frontmatter declarations =="
assert_grep "$FM" '^name:[[:space:]]*test-scope-validator$' "name=test-scope-validator"
assert_grep "$FM" '^model:[[:space:]]*inherit$' "model=inherit"
assert_not_grep "$FM" '^model:[[:space:]]*(opus|sonnet|haiku)$' "고정 티어 핀 없음"
assert_grep "$FM" '^cost_class:[[:space:]]*low$' "cost_class=low"

# v2.11.0: allowedTools(죽은 필드) / disallowedTools 블록 리스트 → tools: 한 줄 allowlist
echo "== tools: allowlist (fail-closed) =="
assert_grep "$FM" '^tools: Read, Grep, Glob$' "tools: Read, Grep, Glob"

assert_file_absent "$AGENT" '^allowedTools:' "죽은 allowedTools 제거됨"
assert_file_absent "$AGENT" '^disallowedTools:' "disallowedTools 제거됨 (allowlist 가 컨트롤)"

echo "== 금지 도구가 tools: 에 없음 =="
# Bash 제거 근거: persona 는 후보 파일 읽기를 `Read` 로 지시하고(Inputs/Step 1) Bash 를 업무에
# 쓰지 않는다 → allowlist(`Read, Grep, Glob`)에서 제외. (줄번호는 drift 하므로 인용하지 않음.)
assert_file_absent "$AGENT" '^tools:.*(Write|Edit|MultiEdit|NotebookEdit|Bash|Agent|Monitor|mcp__)' \
  "tools: 에 쓰기·실행·위임·MCP 도구 없음"

echo "== body claims (scoped to markdown body) =="
assert_grep "$BODY" 'aligned' "body mentions aligned classification"
assert_grep "$BODY" 'outdated-suspicion' "body mentions outdated-suspicion"
assert_grep "$BODY" 'cherry-pick-suspicion' "body mentions cherry-pick-suspicion"
assert_grep "$BODY" 'unclear' "body mentions unclear"
assert_grep "$BODY" 'test_scope_verdicts' "body mentions output key"

echo "== 자기모순 방지 (Hard Rule 4 vs Inputs PRIMARY axis) =="
# Hard Rule의 허용 컨텍스트 열거가 Inputs의 PRIMARY axis(spec_path)를 포함해야 한다.
# 라인번호가 아니라 문자열로 앵커한다(앞선 편집에 취약하지 않게).
rule4="$(grep -F 'Do not fetch context outside' "$AGENT")"
assert_grep "$rule4" 'spec' "Hard Rule 허용 컨텍스트에 spec 포함"
# assert 2는 `## Inputs` 섹션 윈도우로 스코프한다 — Hard Rule 4 자체도 이 fix로
# "PRIMARY reference axis" 문구를(agent에게 왜 spec을 읽어도 되는지 설명하려고) 포함하게
# 되었으므로, 전체 파일 grep은 header-satisfiable(Inputs 절의 선언을 지워도 Hard Rule 4의
# 사본이 살아남아 GREEN으로 남는 함정)이다. 특정 다음 heading 이름이 아니라 다음 `## `
# 아무 heading에서나 종료해 섹션 윈도우가 향후 편집에도 생존하게 한다.
inputs_block="$(awk '/^## Inputs/{f=1;print;next} /^## /{f=0} f' "$AGENT")"
assert_grep "$inputs_block" 'PRIMARY reference axis' "spec이 PRIMARY axis로 선언됨 (Inputs 절)"

finish
