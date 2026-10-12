#!/usr/bin/env bash
# R1(2026-10-12) — 조사 · 판정 agent 의 도구 표면(Law 2) · 입력 칸 · 역할 · 출력 의무.
# 두 agent 를 한 루프로 잰다: 같은 규칙을 두 파일에 복제하면 한쪽만 고쳐지는 drift 가 생긴다.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$REPO_ROOT/shared/tests/assert.sh"
AG="$REPO_ROOT/plugins/spec-distill/agents"

fm_of()   { awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$1"; }
body_of() { awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{f=0;b=1;next} b' "$1"; }

# agent 이름 · 기대 슬롯(tag:var:kind) · 본문 출력 키
check_agent() {
  local name="$1" slots="$2" keys="$3" f="$AG/$1.md"
  [[ -f "$f" ]] || { no "$name: agent 파일 부재"; return; }
  local fm body; fm="$(fm_of "$f")"; body="$(body_of "$f")"
  grep -qxF "name: $name" <<<"$fm" && ok "$name: name" || no "$name: name 불일치"
  grep -qxF 'tools: Read, Grep, Glob' <<<"$fm" && ok "$name: tools 가 정확히 Read, Grep, Glob" || no "$name: tools 가 Read, Grep, Glob 이 아니다"
  for t in Write Edit MultiEdit NotebookEdit Bash Agent Monitor WebSearch WebFetch; do
    grep -qE "^tools:.*(^|,)[[:space:]]*${t}[[:space:]]*(,|$)" <<<"$fm" && no "$name: tools 에 $t (Law 2)" || ok "$name: tools 에 $t 없음"
  done
  grep -qE '^(allowedTools|disallowedTools):' <<<"$fm" && no "$name: allowedTools/denylist" || ok "$name: denylist 없음"
  grep -qE "^[\"']?model[\"']?[[:space:]]*:" <<<"$fm" && no "$name: model 키가 있다" || ok "$name: model 키 없음"
  grep -qxF 'cost_class: low' <<<"$fm" && ok "$name: cost_class: low" || no "$name: cost_class 가 low 가 아니다"
  local s tag var kind
  for s in $slots; do
    IFS=: read -r tag var kind <<<"$s"
    { grep -qxF "  - tag: $tag" <<<"$fm" && grep -qxF "    var: $var" <<<"$fm"; } \
      && ok "$name: 슬롯 $tag/$var" || no "$name: 슬롯 $tag/$var 부재"
    awk -v t="  - tag: $tag" -v k="    kind: $kind" '$0==t{f=1;next} f&&/^  - tag:/{exit} f&&$0==k{hit=1} END{exit !hit}' <<<"$fm" \
      && ok "$name: 슬롯 $tag 의 kind=$kind" || no "$name: 슬롯 $tag 의 kind 가 $kind 가 아니다"
  done
  grep -qE 'kind: (prior_verdict|score|orchestrator_framing)' <<<"$fm" && no "$name: 금지 종류 슬롯" || ok "$name: 금지 종류 슬롯 없음"
  grep -qF 'You are NOT' <<<"$body" && grep -qF 'You ARE' <<<"$body" \
    && ok "$name: 역할 절(You ARE / You are NOT)" || no "$name: 역할 절 부재"
  local k
  for k in $keys; do
    grep -qE "^[[:space:]]*-?[[:space:]]*${k}:" <<<"$body" && ok "$name: 출력 키 $k" || no "$name: 출력 키 $k 부재"
  done
}

check_agent repo-researcher \
  "question:RESEARCH_QUESTION:task claims_contract:CLAIMS_CONTRACT:repo_context open_decisions:OPEN_DECISIONS:task" \
  "repo_claims id path anchor claim touches decides"
RR_FLAT="$(tr '\n' ' ' < "$AG/repo-researcher.md" | tr -s ' ')"
grep -qF '인덱스·목차·description 필드만 읽고 판정하지 않는다' <<<"$RR_FLAT" \
  && ok "repo-researcher: 판정 전에 구현을 읽는다" || no "repo-researcher: 구현 읽기 의무 부재"
grep -qF '목록에 없는 id 를 지어내지 않는다' <<<"$RR_FLAT" \
  && ok "repo-researcher: decides 는 받은 목록 안에서만" || no "repo-researcher: decides 지어내기 금지 부재"
finish
