#!/usr/bin/env bash
# Validates runtime-verifier.md frontmatter + body for the v2.2.0 sandbox-
# executor contract. The agent is now an executor: frontmatter 에 model 키 없음, Write/Edit
# in allowedTools, browser-interaction tools, NotebookEdit still denied, and
# the body declares the sandbox / no-commit / product-fix-forbidden contract.

set -u

FILE="$(cd "$(dirname "$0")/.." && pwd)/agents/runtime-verifier.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# --- frontmatter (v2.11.0: allowedTools(죽은 필드) → tools: allowlist) ---
MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
assert_file_absent "$FILE" "$MODEL_KEY" "frontmatter 에 model 키 없음 (tier-unpinned)"
assert_file_grep "$FILE" "^cost_class: variable" "cost_class stays variable"
assert_file_absent "$FILE" "^allowedTools:" "죽은 allowedTools 제거됨"
assert_file_absent "$FILE" "^disallowedTools:" "disallowedTools 제거됨 (allowlist가 컨트롤)"
assert_file_grep "$FILE" "^tools:" "tools: allowlist 선언"

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
  ok "AC6 tools: 가 죽은 allowedTools 22개 + network-query 1개와 집합 동일 ($(printf '%s\n' "$ACTUAL" | wc -l | tr -d ' ')개)"
else
  no "AC6 집합 불일치 (누락: $(comm -13 <(printf '%s\n' "$ACTUAL") <(printf '%s\n' "$WANT") | tr '\n' ' ') / 확대: $(comm -23 <(printf '%s\n' "$ACTUAL") <(printf '%s\n' "$WANT") | tr '\n' ' '))"
fi

# AC6: 서버 단위 grant 금지 — chrome 서버 이름이 per-tool 접미사 없이 단독으로 오면 안 된다.
if printf '%s' "$TOOLS_VAL" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
     | grep -qxE "${CHROME}|${CHROME}__\*|mcp__\*"; then
  no "AC6 서버 단위 MCP grant 발견 (15→~29 표면 확대: upload_file 유출 벡터)"
else
  ok "AC6 서버 단위 grant 없음 (per-tool 열거만)"
fi

# AC6: 금지 4종 각각에 자기 이름의 TOOL-EXCEPTION 마커 (frontmatter 창 안, 도구별 1:1)
for t in Write Edit MultiEdit Bash; do
  if grep -qE "^#[[:space:]]*TOOL-EXCEPTION:[[:space:]]*${t}[[:space:]]+.+$" <<<"$FM"; then
    ok "$t 에 TOOL-EXCEPTION 마커"
  else
    no "$t 가 tools: 에 있는데 마커 없음"
  fi
done

# --- body contract ---
#
# **본문 assert 는 본문만 읽는다 (/qg iter-5 C4).** 앞 버전은 `assert_grep` 으로 파일
# **전체**를 grep 했는데, 이 파일의 frontmatter `description:` 이 길어서 `sandbox`(10회)
# `product`(5회) `SKIP_WITH_EVIDENCE`(1회) `NEEDS_RESOLUTION`(1회) 를 스스로 만족시켰다.
# 즉 이름이 "body contract" 인 assert 들이 **본문을 하나도 읽지 않고** 통과할 수 있었고,
# 실제로 `Fabricate a green by patching product source` Hard Rule 을 지워도 21/21 GREEN
# 이었다. persona 파일은 보안-민감 코드이고(CLAUDE.md), 그 파일의 규칙을 지키는 락이
# 규칙 삭제를 못 잡으면 락이 아니다.
BODY="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{f=2;next} f==2' "$FILE")"
if [[ -z "$BODY" ]]; then
  no "본문이 비었다 — 아래 body assert 가 공허하게 통과할 뻔했다"
fi
assert_grep "$BODY" "sandbox" "body references the sandbox"
assert_grep "$BODY" "functional_assertions" "evidence-log functional_assertions section"
assert_grep "$BODY" "ac_id" "functional assertions bind to ac_id"
assert_grep "$BODY" "mutation_guard" "body references orchestrator mutation_guard"
assert_grep "$BODY" "SKIP_WITH_EVIDENCE" "SKIP_WITH_EVIDENCE verdict documented"
assert_grep "$BODY" "NEEDS_RESOLUTION" "NEEDS_RESOLUTION verdict documented"

# product-source 규칙은 **단어 `product` 의 등장**이 아니라 두 규칙의 존재다. 앞 버전의
# `assert_grep "product"` 는 frontmatter 의 산문으로도, 본문의 아무 문장으로도 만족됐다 —
# 규칙을 통째로 지워도 GREEN. 두 자리를 각각 잠근다:
#   (1) "You are NOT responsible for" 목록의 금지 항목 (PASS 를 위조하지 말라)
#   (2) Hard Rule 1 (tracked source 변경 → PASS 불가)
assert_grep "$BODY" "Fabricate a green by patching product source" \
  "body: 제품 소스 패치로 green 위조 금지 (금지 목록)"
assert_grep "$BODY" "Product source is sacred" \
  "body: Hard Rule 1 — 제품 소스 불가침"
# `immutable baseline` 에 대한 별도 assert 는 **의도적으로 두지 않는다.** 그 문구는 위
# 두 문장 안에만 존재하므로, 그것을 재는 락은 두 anchor 가 이미 죽은 뒤에야 죽는다 —
# 독립 축인 척하는 중복 락이다. mutation 으로 이빨을 보일 수 없는 락은 만들지 않는다.

# AC31 — 테스트 실행 결과 self-report 가 판정에 쓰이지 않음을 페르소나가 명시한다.
# 이 문장이 없으면 verifier 는 자기 턴에서 돌린 테스트 결과를 evidence-log 에 실어
# 보내도 된다고 읽고, 오케스트레이터가 받는 것이 raw 출력이 아니라 모델의 요약이 된다.
assert_file_grep "$FILE" "테스트 실행 결과는 판정에 들어가지 않는다" "AC31: self-report 배제 문구"

# AC41 — 테스트 러너용 deps 설치는 verifier 의 책임이 아니다. 어댑터의 setup_cmd 가
# 양측에서 같은 명령으로 돌아야 차등 비교가 사과와 오렌지가 되지 않는다.
assert_file_grep "$FILE" "테스트 러너용 deps 설치는 하지 않는다" "AC41: deps 설치 배제 문구"

# 최종 whole-branch 리뷰 (이월분 승격) — Hard Rule 1 의 `installing deps` 는 **무한정
# 허용**으로 읽혔고, 두 줄 아래 Hard Rule 3 의 한정(`not test-runner deps`)과 정면으로
# 모순됐다. 이 페르소나 산문은 §11⑬ 이 verifier-생성 환경 비대칭에 대해 가진 **유일한**
# 통제이고, CLAUDE.md 상 persona 파일은 보안-민감 코드다.
#
# 검사는 **규칙 1 그 줄 안에서** 한다. 파일 어디든 있으면 통과하는 검사는 규칙 3 문구
# 하나로 이미 만족되므로 이빨이 없다 (락이 헤더-satisfiable 이 되는 것과 같은 함정).
rule1_line=$(grep -n '^1\. \*\*Product source is sacred' "$FILE" | head -1 | cut -d: -f1)
if [[ -n "$rule1_line" ]] && sed -n "${rule1_line}p" "$FILE" | grep -q 'test-runner deps'; then
  ok "Hard Rule 1 의 deps 허용이 test-runner deps 를 한정한다"
else
  no "Hard Rule 1 의 'installing deps' 가 한정 없이 허용됨 (Rule 3 과 모순)"
fi

finish
