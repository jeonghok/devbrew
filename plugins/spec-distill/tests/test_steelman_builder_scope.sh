#!/usr/bin/env bash
# V4/AC6 — steelman-builder is read-only (Law 2 frontmatter scoping) + web-capable.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/steelman-builder.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

test -f "$AGENT" && ok "agent file exists" || { no "agent file missing"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }

# Frontmatter 창 = 첫 두 '---' 사이. (구버전 awk 'c==1' 은 '---' 줄 자체를 포함했다.)
fm="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$AGENT")"

# 모델 티어 양방향 락 — 하니스가 세션 모델을 덮어쓰지 않는다(리터럴 핀 = 조용한 하향).
grep -qE '^model: inherit$' <<<"$fm" \
  && ok "model: inherit (세션 티어 상속)" || no "model이 inherit이 아님"
grep -qE '^model: (opus|sonnet|haiku)$' <<<"$fm" \
  && no "고정 티어 핀 잔존" || ok "고정 티어 핀 없음"

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
awk '/tag: premises/{f=1} f&&/kind:/{print; exit}' <<<"$fm" | grep -q 'orchestrator_framing' \
  && ok "premises 의 kind 가 orchestrator_framing" || no "premises 의 kind 가 다르다"
grep -q 'confidence' "$AGENT" \
  && no "AC1: confidence 필드/규칙 잔존 (폐지, 설계 O3)" || ok "AC1: confidence 부재"
# 키 앵커(줄 시작, 임의 들여쓰기 + 콜론) — 산문 규칙(번호로 시작)의 백틱 인용은
# 이 형태로 시작하지 않으므로 걸리지 않는다. 순수 리터럴 존재만 보면 산문 인용이
# 스키마 키 자체가 깨진 것을 가려 GREEN 을 낸다 (controller ruling, M5 관측).
for tok in recommendation premise_refutation premise_list_challenge touches repo_claims anchor refined_takes refined_drops case_for_alternative case_for_current; do
  grep -qE "^[[:space:]]*${tok}:" "$AGENT" && ok "AC1: 스키마 키 $tok 존재" || no "AC1: 스키마 키 $tok 가 없다"
done
grep -q '원안의 옹호자' "$AGENT" \
  && no "AC3: 「원안의 옹호자」 문구 잔존 — 한 편 배정 역할" || ok "AC3: 「원안의 옹호자」 부재"
grep -q '어느 한 편의 옹호자' "$AGENT" \
  && ok "AC3: 「어느 한 편의 옹호자」 존재 (양성 짝)" || no "AC3: 「어느 한 편의 옹호자」 부재"
grep -q 'coverage-mapper neglect\|neglect' "$AGENT" \
  && no "C18: neglect trigger 문구 잔존" || ok "C18: neglect 부재"
# recommendation: 스키마 줄에 앵커 — 서술부("recommending kept / refined / switched.")가
# 같은 세 단어를 다른 목적(역할 설명)으로 써서 스키마 enum 파손을 가릴 수 있었다 (controller
# ruling, M9 관측). 앵커는 그 줄 하나로 좁혀 enum 자체를 잰다.
grep -qE '^recommendation:.*kept.*refined.*switched' "$AGENT" \
  && ok "추천 어휘 kept/refined/switched (스키마 줄)" || no "추천 어휘 부재 (스키마 줄)"
grep -qE 'defended|방어' "$AGENT" && no "옛 어휘 defended/방어 잔존" || ok "옛 어휘 부재"
finish
