#!/usr/bin/env bash
# AC9 — test_agent_frontmatter_keys.sh 의 이빨 증명. 34개 케이스(mutation 은 RED,
# 보강/기준선 케이스는 GREEN) 가 각 want 대로 정확히 나와야 한다.
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

# 🔴 adversarial review (Task 8 재현) — YAML-구문 우회 4종. 8/8 실 agent 는 plain
# 단일 라인 unquoted 라서 오늘은 안전하지만, 락이 이 형태를 못 잡으면 quote/block
# scalar/중복 키로 금지 도구를 숨긴 agent 가 조용히 GREEN 을 받는다.
echo "== ⑥ YAML-구문 우회: 이중 인용 =="
write_agent 'tools: "Read, Grep, Write"'
expect RED "이중 인용 scalar 는 plain 이 아니라 거절(fail-closed)"

echo "== ⑦ YAML-구문 우회: 단일 인용 =="
write_agent "tools: 'Read, Grep, Write'"
expect RED "단일 인용 scalar 는 plain 이 아니라 거절(fail-closed)"

echo "== ⑧ YAML-구문 우회: block scalar (>) =="
write_agent 'tools: >
  Read, Grep, Write'
expect RED "block scalar 뒤에 숨은 진짜 목록은 단일 라인 검증 불가 -> FAIL"

echo "== ⑨ YAML-구문 우회: 중복 tools: 키 (첫 값=무해한 decoy) =="
write_agent 'tools: Read, Grep
tools: Read, Write'
expect RED "중복 tools: 키는 grep -m1 이 decoy 만 보게 만듦 -> FAIL"

echo "== ⑩ YAML-구문 우회: flow-sequence 대괄호 ([...]) =="
write_agent 'tools: [Read, Bash]'
expect RED "flow-sequence 는 토큰이 '[Read'/'Bash]' 로 쪼개져 정확매칭을 피해감 -> FAIL"

# 🔴 adversarial review (iter-1 재현) — YAML-구문 우회 2종 추가. codex 가 ⑪ 을,
# adversarial 이 ⑫ 를 실 픽스처로 재현했다. ⑪ 은 inline 주석, ⑫ 는 anchor 접두.
echo "== ⑪ YAML-구문 우회: 인라인 주석 (tools: Read, Write # 주석) =="
write_agent 'tools: Read, Grep, Glob, Write # 무해해 보이는 주석'
expect RED "인라인 주석 뒤 Write 는 YAML 이 주석을 벗겨 부여 -> 토큰화 前 주석 제거로 잡아야 FAIL"

echo "== ⑫ YAML-구문 우회: anchor 접두 (tools: &a [Read, Write]) =="
write_agent 'tools: &a [Read, Write]'
expect RED "anchor 접두는 flow-seq 가드(\`[\`*)를 피하므로 거절 -> FAIL"

# 🔴 codex iter-1 재검증 적발 — 내 첫 comment-strip 이 YAML-비인식이라 인용 안 `#` 에서
# 잘려 새 우회를 열었다. quote-aware 처리(인용 먼저 벗기고 토큰화)로 봉쇄.
echo "== ⑬ YAML-구문 우회: 인용 안의 # (tools: \"Read, Grep # x, Write\") =="
write_agent 'tools: "Read, Grep # x, Write"'
expect RED "인용 scalar 거절이 인용 안 # 우회를 원천 차단(harness 는 Write 부여)"

echo "== ⑭ YAML-구문 우회: tag (tools: !!seq [Read, Write]) =="
write_agent 'tools: !!seq [Read, Write]'
expect RED "tag(!!seq) 접두는 plain scalar 가 아니므로 거절 -> FAIL"

# 🔴 codex iter-1 재검증(2차) 적발 — 인용 scalar 가 다음 줄로 이어지면 grep -m1 이 첫 줄만
# 봐서 Write 를 놓친다(block-scalar 와 같은 클래스). 인용 전면 거절로 봉쇄.
echo "== ⑮ YAML-구문 우회: multiline 인용 scalar (값이 다음 줄로) =="
write_agent 'tools: "Read,
  Write"'
expect RED "multiline 인용은 첫 줄만 봐서는 Write 를 놓친다 -> 인용 거절로 봉쇄"

echo "== ⑯ YAML-구문 우회: multiline plain scalar (tools: Read,⏎  Write) =="
write_agent 'tools: Read,
  Write'
expect RED "plain 값이 다음 줄로 접히면 continuation 탐지로 거절 (첫 줄만 보면 Write 놓침)"

# 🔴 codex 3차 재검증 적발 — continuation 이 빈 줄을 낀 경우(YAML 은 여전히 한 scalar).
echo "== ⑰ YAML-구문 우회: 빈 줄 낀 multiline plain (tools: Read,⏎<빈줄>⏎  Write) =="
write_agent 'tools: Read,

  Write'
expect RED "빈 줄을 건너뛰고 첫 비어있지 않은 indented 줄을 검사 -> Write continuation 거절"

echo "== 보강: plain 안전 목록의 인라인 주석은 GREEN (주석 제거가 over-reject 아님) =="
write_agent 'tools: Read, Grep, Glob # 정상 주석'
expect GREEN "plain scalar 는 주석 제거 후 통과"

echo "== 보강: 안전해 보여도 인용은 거절(fail-closed; 8 실 agent 는 unquoted plain) =="
write_agent 'tools: "Read, Grep, Glob"'
expect RED "인용 scalar 는 plain 이 아니라 거절 — plain 'Read, Grep, Glob' 로 쓸 것"

echo; echo "mutation: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
