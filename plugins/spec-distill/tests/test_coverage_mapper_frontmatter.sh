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

# 조사 주장 계약 배선 — 슬롯 둘의 선언과 출력 의무. 슬롯의 var·kind 는 형제 둘과 글자째 같아야
# 한다(`tools/adjudication/check_slots.py` 의 var_mismatch 가 갈라짐을 잡지만, 그 락이 죽으면
# 이 자리가 마지막 방어선이다).
for tag in claims_contract open_decisions; do
  grep -qE "^  - tag: ${tag}$" <<<"$FM" && ok "슬롯 태그 $tag" || no "슬롯 태그 $tag 부재"
done
grep -q 'var: CLAIMS_CONTRACT' <<<"$FM" && ok "슬롯 var CLAIMS_CONTRACT" || no "슬롯 var CLAIMS_CONTRACT 부재"
grep -q 'var: OPEN_DECISIONS' <<<"$FM" && ok "슬롯 var OPEN_DECISIONS" || no "슬롯 var OPEN_DECISIONS 부재"
grep -q 'kind: repo_context' <<<"$FM" && ok "claims_contract 의 kind 가 repo_context" || no "kind: repo_context 부재"
# 출력 의무 — 스키마 키 둘이 본문에 실재한다(존재 검사라 frontmatter 를 뺀 본문에서 잰다:
# description 이 같은 낱말을 담아도 출력 스키마를 지우면 RED 다).
BODY="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{f=0;b=1;next} b' "$AGENT")"
for tok in repo_claims evidence decides; do
  grep -qE "^[[:space:]]*-?[[:space:]]*${tok}:" <<<"$BODY" \
    && ok "출력 의무: $tok 키가 본문 스키마에 있다" || no "출력 의무: $tok 키 부재"
done

# AC22 — 옛 하드 상한 문구가 agent 파일 «전체»(frontmatter description 포함)에 남지 않는다. description 은
# dispatch 판단에 모델이 읽는 필드라, 옛 상한이 남으면 재개방 뒤 정당한 재dispatch 를 거부하게 한다.
# 양의 짝이 자격+예산 서술의 실재를 문다 — 부재 락만이면 문단을 통째로 지워도 통과한다.
AGENT_FLAT="$(tr '\n' ' ' < "$AGENT" | tr -s ' ')"
grep -qF -- 'bounded to two' "$AGENT" && no "AC22: 옛 상한 문구 «bounded to two» 잔존" || ok "AC22: «bounded to two» 없음"
grep -qF -- 'once per' "$AGENT" && no "AC22: 옛 상한 문구 «once per» 잔존" || ok "AC22: «once per» 없음"
grep -qF -- '상한 2 dispatch' "$AGENT" && no "AC22: 옛 상한 문구 «상한 2 dispatch» 잔존" || ok "AC22: «상한 2 dispatch» 없음"
grep -qF -- '상한 2(conducting-interview' "$AGENT" && no "AC22: 옛 상한 문구 «상한 2(conducting-interview» 잔존" || ok "AC22: «상한 2(conducting-interview» 없음"
grep -qF -- 'dispatch eligibility is whether an open decision still' <<<"$AGENT_FLAT" && ok "AC22(양의 짝): 자격+예산 서술 실재" || no "AC22: 자격+예산 서술 부재 — 부재 락이 공허해진다"
grep -qF -- '1 plus the total reopen count' <<<"$AGENT_FLAT" && ok "AC22(양의 짝): 자격+예산 서술 실재" || no "AC22: 자격+예산 서술 부재 — 부재 락이 공허해진다"
finish
