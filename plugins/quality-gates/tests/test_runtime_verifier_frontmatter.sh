#!/usr/bin/env bash
# Validates runtime-verifier.md frontmatter + body for the v2.2.0 sandbox-
# executor contract. The agent is now an executor: model inherit, Write/Edit
# in allowedTools, browser-interaction tools, NotebookEdit still denied, and
# the body declares the sandbox / no-commit / product-fix-forbidden contract.

set -u

FILE="$(cd "$(dirname "$0")/.." && pwd)/agents/runtime-verifier.md"
PASS=0
FAIL=0

assert_grep() {
  local pattern="$1" msg="$2"
  if grep -qE "$pattern" "$FILE"; then
    PASS=$((PASS + 1)); echo "  PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (pattern '$pattern' not in file)"
  fi
}
assert_nogrep() {
  local pattern="$1" msg="$2"
  if grep -qE "$pattern" "$FILE"; then
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (pattern '$pattern' unexpectedly present)"
  else
    PASS=$((PASS + 1)); echo "  PASS: $msg"
  fi
}

# --- frontmatter (v2.11.0: allowedTools(죽은 필드) → tools: allowlist) ---
assert_grep "^model: inherit" "model is inherit"
assert_grep "^cost_class: variable" "cost_class stays variable"
assert_nogrep "^allowedTools:" "죽은 allowedTools 제거됨"
assert_nogrep "^disallowedTools:" "disallowedTools 제거됨 (allowlist가 컨트롤)"
assert_grep "^tools:" "tools: allowlist 선언"

# AC6: tools: 집합 = v2.10.3 의 죽은 allowedTools 22개 + iter-1 리뷰로 추가한 network-query MCP 1개
# (list_network_requests) = 23개. 근거: persona Hard Rule 5 가 web PASS 증거로 'network status'(URL+status)
# 를 요구하는데 chrome 15개엔 network 조회 도구가 없어 구조적으로 못 만들던 갭을 메운 것(구 denylist 는
# 모든 MCP 를 줘서 갭이 가려졌고 이 PR 이 allowlist 로 노출시켰다). get_network_request 는 요청/응답 상세
# (auth 헤더·쿠키·토큰·바디)를 노출해 evidence-log(main repo)로 secret 유출 벡터가 되므로 least-privilege
# 상 제외 — status 는 list_network_requests 로 충분(codex iter-1 적발). per-tool 이름이라 서버 grant 아님.
FM="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$FILE")"
TOOLS_VAL="$(grep -m1 -E '^tools:' <<<"$FM" | sed 's/^tools:[[:space:]]*//')"
CHROME="mcp__plugin_chrome-devtools-mcp_chrome-devtools"

# 셸 무관하게 한 항목씩 개행으로 낸다. `printf '%s\n' $LIST`(unquoted) 는 셸 의존적이다 —
# bash 는 word-split 하지만 zsh 은 하지 않아 22개가 한 줄로 뭉쳐 항상 FAIL 한다.
# 이 테스트는 반드시 `bash <file>` 로 실행한다 (ambient 셸이 zsh 일 수 있다).
want_tools() {
  printf '%s\n' Read Bash Grep Glob Write Edit MultiEdit
  local t
  for t in navigate_page take_screenshot take_snapshot list_console_messages \
           get_console_message close_page new_page wait_for click fill \
           fill_form type_text hover press_key evaluate_script \
           list_network_requests; do
    printf '%s\n' "${CHROME}__${t}"
  done
}
ACTUAL="$(printf '%s\n' "$TOOLS_VAL" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' | sort)"
WANT="$(want_tools | sort)"
if [ "$ACTUAL" = "$WANT" ]; then
  PASS=$((PASS + 1)); echo "  PASS: AC6 tools: 가 죽은 allowedTools 22개 + network-query 1개와 집합 동일 ($(printf '%s\n' "$ACTUAL" | wc -l | tr -d ' ')개)"
else
  FAIL=$((FAIL + 1)); echo "  ✗ FAIL: AC6 집합 불일치"
  echo "    누락: $(comm -13 <(printf '%s\n' "$ACTUAL") <(printf '%s\n' "$WANT") | tr '\n' ' ')"
  echo "    확대: $(comm -23 <(printf '%s\n' "$ACTUAL") <(printf '%s\n' "$WANT") | tr '\n' ' ')"
fi

# AC6: 서버 단위 grant 금지 — chrome 서버 이름이 per-tool 접미사 없이 단독으로 오면 안 된다.
if printf '%s' "$TOOLS_VAL" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
     | grep -qxE "${CHROME}|${CHROME}__\*|mcp__\*"; then
  FAIL=$((FAIL + 1)); echo "  ✗ FAIL: AC6 서버 단위 MCP grant 발견 (15→~29 표면 확대: upload_file 유출 벡터)"
else
  PASS=$((PASS + 1)); echo "  PASS: AC6 서버 단위 grant 없음 (per-tool 열거만)"
fi

# AC6: 금지 4종 각각에 자기 이름의 TOOL-EXCEPTION 마커 (frontmatter 창 안, 도구별 1:1)
for t in Write Edit MultiEdit Bash; do
  if grep -qE "^#[[:space:]]*TOOL-EXCEPTION:[[:space:]]*${t}[[:space:]]+.+$" <<<"$FM"; then
    PASS=$((PASS + 1)); echo "  PASS: $t 에 TOOL-EXCEPTION 마커"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $t 가 tools: 에 있는데 마커 없음"
  fi
done

# --- body contract ---
assert_grep "sandbox" "body references the sandbox"
assert_grep "functional_assertions" "evidence-log functional_assertions section"
assert_grep "ac_id" "functional assertions bind to ac_id"
assert_grep "mutation_guard" "body references orchestrator mutation_guard"
assert_grep "product" "body addresses product-source rule"
assert_grep "SKIP_WITH_EVIDENCE" "SKIP_WITH_EVIDENCE verdict documented"
assert_grep "NEEDS_RESOLUTION" "NEEDS_RESOLUTION verdict documented"

# AC31 — 테스트 실행 결과 self-report 가 판정에 쓰이지 않음을 페르소나가 명시한다.
# 이 문장이 없으면 verifier 는 자기 턴에서 돌린 테스트 결과를 evidence-log 에 실어
# 보내도 된다고 읽고, 오케스트레이터가 받는 것이 raw 출력이 아니라 모델의 요약이 된다.
assert_grep "테스트 실행 결과는 판정에 들어가지 않는다" "AC31: self-report 배제 문구"

# AC41 — 테스트 러너용 deps 설치는 verifier 의 책임이 아니다. 어댑터의 setup_cmd 가
# 양측에서 같은 명령으로 돌아야 차등 비교가 사과와 오렌지가 되지 않는다.
assert_grep "테스트 러너용 deps 설치는 하지 않는다" "AC41: deps 설치 배제 문구"

echo ""
echo "Tests passed: $PASS, failed: $FAIL"
[[ $FAIL -eq 0 ]] || exit 1
