#!/usr/bin/env bash
# AC6 — blind-spot-prober 도구 표면(read-only Law 2) + Output 스키마 존재.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/blind-spot-prober.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

test -f "$AGENT" || { no "agent 파일 부재: $AGENT"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }
FM="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$AGENT")"

# 모델 티어 락 — frontmatter 에 model 키를 두지 않는다. 리터럴 핀은 세션 선택을,
# `inherit` 는 사용자의 subagent 기본 티어 설정을 덮어쓴다(CLI 2.1.261 실측).
MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
grep -qE "$MODEL_KEY" <<<"$FM" \
  && no "frontmatter 에 model 키가 있다 — 하니스가 티어를 정한다" \
  || ok "frontmatter 에 model 키 없음 (tier-unpinned)"

grep -qE '^name: blind-spot-prober$' <<<"$FM" \
  && ok "name: blind-spot-prober" || no "name이 blind-spot-prober 아님"

# web 근거가 필요하므로 WebSearch/WebFetch 보유 (steelman-builder와 동형), 쓰기는 부재.
grep -qE '^tools: Read, Grep, Glob, WebSearch, WebFetch$' <<<"$FM" \
  && ok "tools: Read, Grep, Glob, WebSearch, WebFetch" \
  || no "tools: 가 read-only+web 목록과 다름"

grep -qE '^(allowedTools|disallowedTools):' <<<"$FM" \
  && no "죽은 allowedTools / denylist 잔존" || ok "denylist 없음"

# Law 2: 쓰기·실행·위임 물리 부재
for t in Write Edit MultiEdit NotebookEdit Bash Agent Monitor; do
  grep -qE "^tools:.*(^|,)[[:space:]]*${t}[[:space:]]*(,|$)" <<<"$FM" \
    && no "tools: 에 $t 가 있다 (Law 2 위반)" \
    || ok "tools: 에 $t 없음"
done

# AC6: Output 스키마 키
grep -q 'hidden_assumptions' "$AGENT" \
  && ok "Output: hidden_assumptions 키 존재" || no "hidden_assumptions 키 부재"
grep -q 'failure_modes' "$AGENT" \
  && ok "Output: failure_modes 키 존재" || no "failure_modes 키 부재"

# E10 — 단일 호출 상한 표현 + 탐색 폭 좁힘 문구 부재.
# 하니스가 프롬프트로 검색 횟수를 묶으면 조사가 본질인 역할의 능력을 직접 깎는다.
# 패턴은 test_brief_agents.sh:194의 E10 락을 확장한 것이다(숫자 범위·병렬 금지 추가).
if grep -qE '최대 [0-9]+회|[0-9]+회까지|[0-9]–[0-9]회|[0-9]-[0-9]회|max_[a-z_]+ *= *[0-9]' "$AGENT"; then
  no "E10: 단일 호출 상한 표현 잔존"
else
  ok "E10: 상한 표현 없음"
fi
if grep -qE '병렬.{0,8}금지|투기적.{0,8}금지' "$AGENT"; then
  no "E10: 병렬·투기적 호출 금지 문구 잔존 (탐색 폭 좁힘)"
else
  ok "E10: 병렬 금지 문구 없음"
fi

# 조사 주장 계약 배선 — 형제 둘과 글자째 같은 삼중쌍.
for tag in claims_contract open_decisions; do
  grep -qE "^  - tag: ${tag}$" <<<"$FM" && ok "슬롯 태그 $tag" || no "슬롯 태그 $tag 부재"
done
grep -q 'var: CLAIMS_CONTRACT' <<<"$FM" && ok "슬롯 var CLAIMS_CONTRACT" || no "슬롯 var CLAIMS_CONTRACT 부재"
grep -q 'var: OPEN_DECISIONS' <<<"$FM" && ok "슬롯 var OPEN_DECISIONS" || no "슬롯 var OPEN_DECISIONS 부재"
grep -q 'kind: repo_context' <<<"$FM" && ok "claims_contract 의 kind 가 repo_context" || no "kind: repo_context 부재"
BODY="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{f=0;b=1;next} b' "$AGENT")"
for tok in repo_claims decides; do
  grep -qE "^[[:space:]]*-?[[:space:]]*${tok}:" <<<"$BODY" \
    && ok "출력 의무: $tok 키가 본문 스키마에 있다" || no "출력 의무: $tok 키 부재"
done

# AC22 — 옛 하드 상한 문구가 agent 파일 «전체»(frontmatter description 포함)에 남지 않는다. description 은
# dispatch 판단에 모델이 읽는 필드라, 옛 상한이 남으면 재개방 뒤 정당한 재dispatch 를 거부하게 한다.
# 양의 짝이 자격+예산 서술의 실재를 문다 — 부재 락만이면 문단을 통째로 지워도 통과한다.
AGENT_FLAT="$(tr '\n' ' ' < "$AGENT" | tr -s ' ')"
grep -qiF -- 'once per' <<<"$AGENT_FLAT" && no "AC22: 옛 상한 문구 «once per» 잔존" || ok "AC22: «once per» 없음"
grep -qiF -- 'fan-out 1' <<<"$AGENT_FLAT" && no "AC22: 옛 상한 문구 «fan-out 1» 잔존" || ok "AC22: «fan-out 1» 없음"
grep -qiF -- '인터뷰당 1회' <<<"$AGENT_FLAT" && no "AC22: 옛 상한 문구 «인터뷰당 1회» 잔존" || ok "AC22: «인터뷰당 1회» 없음"
grep -qiF -- '재dispatch 금지' <<<"$AGENT_FLAT" && no "AC22: 옛 상한 문구 «재dispatch 금지» 잔존" || ok "AC22: «재dispatch 금지» 없음"
grep -qF -- 'eligibility is' <<<"$AGENT_FLAT" && ok "AC22(양의 짝): 자격+예산 서술 실재" || no "AC22: 자격+예산 서술 부재 — 부재 락이 공허해진다"
grep -qF -- 'whether an open decision still touches that dimension' <<<"$AGENT_FLAT" && ok "AC22(양의 짝): 자격+예산 서술 실재" || no "AC22: 자격+예산 서술 부재 — 부재 락이 공허해진다"
grep -qF -- '1 plus that dimension'\''s reopen count' <<<"$AGENT_FLAT" && ok "AC22(양의 짝): 자격+예산 서술 실재" || no "AC22: 자격+예산 서술 부재 — 부재 락이 공허해진다"
# 웹 근거도 계약 모양이다(스펙 §B — prober 의 출력 의무는 coverage-mapper 와 같다). URL 문자열 목록이면
# `decides` 가 없어 웹 premortem 이 결정 연결을 영영 못 댄다. 양의 짝: 계약 객체의 `url:` 키.
grep -qE '^[[:space:]]*-[[:space:]]*"https://' <<<"$BODY" \
  && no "웹 근거가 URL 문자열 목록이다 — 계약 객체(url·supports·claim·touches·decides)가 아니다" \
  || ok "웹 근거가 URL 문자열 목록이 아니다"
ev_n="$(grep -cE '^[[:space:]]*-[[:space:]]*url:[[:space:]]*"https://' <<<"$BODY")"
dec_n="$(grep -cE '^[[:space:]]*decides:' <<<"$BODY")"
{ [[ "$ev_n" -ge 2 ]] && [[ "$dec_n" -ge 3 ]]; } \
  && ok "웹 근거 계약 객체: hidden_assumptions·failure_modes 두 자리 모두 url + decides (repo_claims 포함 decides ≥3)" \
  || no "웹 근거 계약 객체 부재: url 항목 ${ev_n} · decides 키 ${dec_n}"
finish
