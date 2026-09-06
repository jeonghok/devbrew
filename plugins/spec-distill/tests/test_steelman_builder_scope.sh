#!/usr/bin/env bash
# V4/AC6 — steelman-builder is read-only (Law 2 frontmatter scoping) + web-capable.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/steelman-builder.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

test -f "$AGENT" && ok "agent file exists" || { no "agent file missing"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }

# Frontmatter 창 = 첫 두 '---' 사이. (구버전 awk 'c==1' 은 '---' 줄 자체를 포함했다.)
fm="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$AGENT")"

# 모델 티어 락 — frontmatter 에 model 키를 두지 않는다. 리터럴 핀은 세션 선택을,
# `inherit` 는 사용자의 subagent 기본 티어 설정을 덮어쓴다(CLI 2.1.261 실측).
MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
grep -qE "$MODEL_KEY" <<<"$fm" \
  && no "frontmatter 에 model 키가 있다 — 하니스가 티어를 정한다" \
  || ok "frontmatter 에 model 키 없음 (tier-unpinned)"

# v0.21.0: allowedTools(죽은 필드) + disallowedTools → tools: allowlist.
# census 가 가설을 확증했다: 업무에 WebSearch×2 · WebFetch×2 실사용.
grep -qE '^tools: Read, Grep, Glob, WebSearch, WebFetch$' <<<"$fm" \
  && ok "tools: 가 census 도출 목록과 일치" \
  || no "tools: 가 census 도출 목록과 다름"

grep -qE '^(allowedTools|disallowedTools):' <<<"$fm" \
  && no "죽은 allowedTools / denylist 잔존" \
  || ok "allowedTools · disallowedTools 없음"

# AC6(구): 쓰기 도구가 물리적으로 부재 — 이제 denylist 열거가 아니라 allowlist 부재로.
for tool in Write Edit MultiEdit NotebookEdit Bash Agent Monitor; do
  grep -qE "^tools:.*(^|,)[[:space:]]*${tool}[[:space:]]*(,|$)" <<<"$fm" \
    && no "AC6: tools: 에 $tool 이 있다" \
    || ok "AC6: tools: 에 $tool 없음"
done

# web 연구 표면은 census 근거로 유지 — 조용한 열화 방지.
for tool in WebSearch WebFetch; do
  grep -qE "^tools:.*${tool}" <<<"$fm" \
    && ok "tools: 에 $tool 유지" \
    || no "tools: 에서 $tool 이 사라졌다 — steelman 근거 수집 불가"
done

# name + verbatim-output contract present
grep -q '^name: steelman-builder$' <<<"$fm" \
  && ok "name: steelman-builder" || no "name field broken"
grep -qiE 'verbatim|약화.*금지|편집.*금지' "$AGENT" \
  && ok "AC5: verbatim/no-weakening output contract present" \
  || no "AC5: verbatim output contract missing"

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

# v0.54.0 — 목표 적합 재설계 (설계 §6.1). 부재 락에는 양성 짝을 둔다.
grep -qE '^input_slots:' <<<"$fm" && ok "input_slots 선언" || no "input_slots 부재"
for tag in direction trigger goal premises constraints; do
  grep -qE "^  - tag: ${tag}$" <<<"$fm" && ok "슬롯 태그 $tag" || no "슬롯 태그 $tag 부재 (AC2)"
done
[[ "$(grep -c '^    kind: orchestrator_framing$' <<<"$fm")" -eq 1 ]] \
  && ok "orchestrator_framing 은 슬롯 하나(premises)에만" || no "orchestrator_framing 슬롯 수가 1 이 아니다 (AC2)"
# :3 의 set -o pipefail 아래서 `awk | grep -q` 는 grep 이 첫 매치에서 끝나 awk 에 SIGPIPE 를
# 보내면 141 로 죽어 `&&` 가지를 거짓 RED 시킬 수 있다 — 파이프 대신 명령 치환으로 우회.
grep -q 'orchestrator_framing' <<<"$(awk '/tag: premises/{f=1} f&&/kind:/{print; exit}' <<<"$fm")" \
  && ok "premises 의 kind 가 orchestrator_framing" || no "premises 의 kind 가 다르다"
grep -q 'confidence' "$AGENT" \
  && no "AC1: confidence 필드/규칙 잔존 (폐지, 설계 O3)" || ok "AC1: confidence 부재"
# O1(옛 토큰 별칭 없음) — confidence 하나만 잡으면 옛 스키마의 나머지 세 토큰이 별칭으로
# 되살아나도 조용하다. skills/conducting-interview/SKILL.md 가 아직 alternative_statement 를
# 이름으로 부르고 있어 Task 4 복사-붙여넣기 한 번으로 돌아올 수 있는 실재 회귀 경로다.
for tok in alternative_statement strongest_case weakness_of_current; do
  grep -q "$tok" "$AGENT" \
    && no "O1: 옛 토큰 별칭 $tok 잔존" || ok "O1: 옛 토큰 별칭 $tok 부재"
done
# 키 앵커(줄 시작, 임의 들여쓰기 + 콜론) — 산문 규칙(번호로 시작)의 백틱 인용은
# 이 형태로 시작하지 않으므로 걸리지 않는다. 순수 리터럴 존재만 보면 산문 인용이
# 스키마 키 자체가 깨진 것을 가려 GREEN 을 낸다.
for tok in recommendation premise_refutation premise_list_challenge touches repo_claims anchor refined_takes refined_drops case_for_alternative case_for_current; do
  grep -qE "^[[:space:]]*${tok}:" "$AGENT" && ok "AC1: 스키마 키 $tok 존재" || no "AC1: 스키마 키 $tok 가 없다"
done
grep -q '원안의 옹호자' "$AGENT" \
  && no "AC3: 「원안의 옹호자」 문구 잔존 — 한 편 배정 역할" || ok "AC3: 「원안의 옹호자」 부재"
grep -q '어느 한 편의 옹호자' "$AGENT" \
  && ok "AC3: 「어느 한 편의 옹호자」 존재 (양성 짝)" || no "AC3: 「어느 한 편의 옹호자」 부재"
# `\|`(GNU BRE 확장) 제거 — 이식성 없는 grep 에서는 리터럴 `a\|b` 가 되어 아무것도
# 매치하지 않는 no-op 이 된다. 첫 가지는 둘째의 부분 문자열이라 애초에 무의미했다.
grep -q 'neglect' "$AGENT" \
  && no "C18: neglect trigger 문구 잔존" || ok "C18: neglect 부재"
# recommendation: 스키마 줄에 앵커 — 서술부("recommending kept / refined / switched.")가
# 같은 세 단어를 다른 목적(역할 설명)으로 써서 스키마 enum 파손을 가릴 수 있었다.
# 앵커는 그 줄 하나로 좁혀 enum 자체를 잰다.
grep -qE '^recommendation:.*kept.*refined.*switched' "$AGENT" \
  && ok "추천 어휘 kept/refined/switched (스키마 줄)" || no "추천 어휘 부재 (스키마 줄)"
# builder 추천에 deferred 는 없다 — 위 kept/refined/switched 존재 락이 이미 그 코퍼스가
# 비어있지 않음을 보장하므로 별도 양성 짝은 두지 않는다.
grep -q 'deferred' "$AGENT" \
  && no "builder 추천에 deferred 잔존 (verdict 는 kept/refined/switched 뿐)" \
  || ok "builder 추천에 deferred 없음"
grep -qE 'defended|방어' "$AGENT" && no "옛 어휘 defended/방어 잔존" || ok "옛 어휘 부재"

# 중첩 키 좁힘 — 설계 §6.1 구속 목록은 점 표기(case_for_alternative.statement 등)다.
# 부모 키만 재면 같은 이름이 다른 블록에도 있을 때(예: strongest 가 case_for_alternative 와
# case_for_current 둘 다에 있음) 한쪽이 지워져도 다른 쪽이 대신 매치해 GREEN 이 남는다 —
# 이 태스크가 지키려는 대칭 불변식 그 자체가 락 밖에 있었다. 블록을 먼저 잘라(다음 최상위
# 키 직전까지) 그 블록 안에서만 키를 잰다.
cfa_block="$(awk '/^case_for_alternative:/{f=1;next} /^case_for_current:/{f=0} f' "$AGENT")"
cfc_block="$(awk '/^case_for_current:/{f=1;next} /^premise_refutation:/{f=0} f' "$AGENT")"
pr_block="$(awk '/^premise_refutation:/{f=1;next} /^premise_list_challenge:/{f=0} f' "$AGENT")"
ev_block="$(awk '/^evidence:/{f=1;next} /^repo_claims:/{f=0} f' "$AGENT")"
rc_block="$(awk '/^repo_claims:/{f=1;next} /^```$/{f=0} f' "$AGENT")"

grep -qE '^[[:space:]]*statement:' <<<"$cfa_block" \
  && ok "중첩 키 case_for_alternative.statement" || no "중첩 키 case_for_alternative.statement 부재"
grep -qE '^[[:space:]]*strongest:' <<<"$cfa_block" \
  && ok "중첩 키 case_for_alternative.strongest" || no "중첩 키 case_for_alternative.strongest 부재"
grep -qE '^[[:space:]]*strongest:' <<<"$cfc_block" \
  && ok "중첩 키 case_for_current.strongest" || no "중첩 키 case_for_current.strongest 부재"
grep -qE '^[[:space:]]*hits:' <<<"$pr_block" \
  && ok "중첩 키 premise_refutation.hits" || no "중첩 키 premise_refutation.hits 부재"
grep -qE '^[[:space:]]*why:' <<<"$pr_block" \
  && ok "중첩 키 premise_refutation.why" || no "중첩 키 premise_refutation.why 부재"
# url 은 리스트 첫 키라 `- ` 접두가 붙는다(`  - url: ...`) — 순수 공백 앵커로는
# dash 를 못 넘는다.
grep -qE '^[[:space:]]*-?[[:space:]]*url:' <<<"$ev_block" \
  && ok "중첩 키 evidence[].url" || no "중첩 키 evidence[].url 부재"
grep -qE '^[[:space:]]*supports:' <<<"$ev_block" \
  && ok "중첩 키 evidence[].supports" || no "중첩 키 evidence[].supports 부재"
grep -qE '^[[:space:]]*claim:' <<<"$ev_block" \
  && ok "중첩 키 evidence[].claim" || no "중첩 키 evidence[].claim 부재"
# path 도 리스트 첫 키라 같은 dash 접두 문제.
grep -qE '^[[:space:]]*-?[[:space:]]*path:' <<<"$rc_block" \
  && ok "중첩 키 repo_claims[].path" || no "중첩 키 repo_claims[].path 부재"
grep -qE '^[[:space:]]*claim:' <<<"$rc_block" \
  && ok "중첩 키 repo_claims[].claim" || no "중첩 키 repo_claims[].claim 부재"

# 재론(再論) 방지 핵심 규칙 — premise_refutation.hits 가 비면 switched 를 낼 수 없다(동작
# 규칙 10). 고정 문자열(-F)로 그 절 자체를 잰다: 규칙이 다시 사라지거나 문구가 바뀌면
# 소리가 난다.
grep -qF 'hits` 가 비어 있으면 `recommendation: switched` 를 내지 않습니다' "$AGENT" \
  && ok "동작 규칙: hits 비면 switched 금지 (재론 방지 핵심)" \
  || no "동작 규칙: hits 비면 switched 금지 규칙 부재 — 재론 방지 장치 없음"
finish
