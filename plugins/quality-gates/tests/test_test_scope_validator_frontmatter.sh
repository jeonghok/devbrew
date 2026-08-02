#!/usr/bin/env bash
# Tests for agents/test-scope-validator.md frontmatter — verifies Plugin Shape
# compliance: allowedTools / disallowedTools / model / cost_class declarations.
# Mirrors style of test_runtime_verifier_frontmatter.sh.

set -u

AGENT="$(cd "$(dirname "$0")/.." && pwd)/agents/test-scope-validator.md"
PASS=0
FAIL=0

note() { echo "  → $1"; }

assert_grep() {
  local pattern="$1" msg="$2"
  if grep -qE "$pattern" "$AGENT"; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (pattern '$pattern' not found)"
  fi
}

assert_not_grep() {
  local pattern="$1" msg="$2"
  if ! grep -qE "$pattern" "$AGENT"; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (unexpected '$pattern')"
  fi
}

assert_body_grep() {
  local pattern="$1" msg="$2"
  if echo "$BODY" | grep -qE "$pattern"; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (pattern '$pattern' not found in body)"
  fi
}

if [ ! -f "$AGENT" ]; then
  echo "  ✗ FAIL: agent file missing: $AGENT"
  exit 1
fi

# Extract markdown body (everything after the SECOND '---' line).
BODY=$(awk '/^---$/{c++; next} c>=2' "$AGENT")

# Extract frontmatter block (between first two '---' lines).
FM=$(awk '/^---$/{c++; next} c==1' "$AGENT")

echo "== Frontmatter declarations =="
echo "$FM" | grep -qE '^name:[[:space:]]*test-scope-validator$' \
  && { PASS=$((PASS + 1)); note "PASS: name=test-scope-validator"; } \
  || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: name field"; }
echo "$FM" | grep -qE '^model:[[:space:]]*inherit$' \
  && { PASS=$((PASS + 1)); note "PASS: model=inherit"; } \
  || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: model field (inherit 아님)"; }
echo "$FM" | grep -qE '^model:[[:space:]]*(opus|sonnet|haiku)$' \
  && { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: 고정 티어 핀 잔존"; } \
  || { PASS=$((PASS + 1)); note "PASS: 고정 티어 핀 없음"; }
echo "$FM" | grep -qE '^cost_class:[[:space:]]*low$' \
  && { PASS=$((PASS + 1)); note "PASS: cost_class=low"; } \
  || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: cost_class field"; }

# v2.11.0: allowedTools(죽은 필드) / disallowedTools 블록 리스트 → tools: 한 줄 allowlist
echo "== tools: allowlist (fail-closed) =="
echo "$FM" | grep -qE '^tools: Read, Grep, Glob$' \
  && { PASS=$((PASS + 1)); note "PASS: tools: Read, Grep, Glob"; } \
  || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: tools: 가 'Read, Grep, Glob' 이 아님"; }

assert_not_grep '^allowedTools:' "죽은 allowedTools 제거됨"
assert_not_grep '^disallowedTools:' "disallowedTools 제거됨 (allowlist 가 컨트롤)"

echo "== 금지 도구가 tools: 에 없음 =="
# Bash 제거 근거: persona 는 후보 파일 읽기를 `Read` 로 지시하고(Inputs/Step 1) Bash 를 업무에
# 쓰지 않는다 → allowlist(`Read, Grep, Glob`)에서 제외. (줄번호는 drift 하므로 인용하지 않음.)
assert_not_grep '^tools:.*(Write|Edit|MultiEdit|NotebookEdit|Bash|Agent|Monitor|mcp__)' \
  "tools: 에 쓰기·실행·위임·MCP 도구 없음"

echo "== body claims (scoped to markdown body) =="
assert_body_grep 'aligned' "body mentions aligned classification"
assert_body_grep 'outdated-suspicion' "body mentions outdated-suspicion"
assert_body_grep 'cherry-pick-suspicion' "body mentions cherry-pick-suspicion"
assert_body_grep 'unclear' "body mentions unclear"
assert_body_grep 'test_scope_verdicts' "body mentions output key"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
