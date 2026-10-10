#!/usr/bin/env bash
# 구조적 보증 — `plugins/*/agents/*.md` 의 frontmatter `model` 키.
#
# 기본은 «키 부재»다(CLI 2.1.261 실측, 2026-09-06): 리터럴 티어는 세션 모델 선택을 덮어쓰고,
# `inherit` 는 사용자의 subagent 기본 티어 설정(`CLAUDE_CODE_SUBAGENT_MODEL`)을 덮어쓴다. 키가
# 없어야 하니스가 「사용자 설정 → 세션 모델」 순으로 위임한다.
#
# 예외는 아래 PINNED 둘뿐이고 값은 정확히 `opus` 다 — qg 소유 리뷰 agent 는 opus 로 고정한다(qg v10
# 재결정 R3, 사용자 지시 「리뷰는 opus」). 예외 목록은 열거지만 «더 넓히는» 방향의 실수를 막는다:
# 목록 밖 agent 에 키가 생기면 RED, 목록 안 agent 의 값이 opus 가 아니거나 키가 둘이어도 RED 다.
#
# 범위 밖: 외부(비-devbrew) 플러그인의 하드코딩 핀은 존중한다 — 이 스윕은 이 리포의 `plugins/` 만 본다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
PINNED=(
  "plugins/quality-gates/agents/code-recritic.md"
  "plugins/quality-gates/agents/security-reviewer.md"
)

shopt -s nullglob
agents=(plugins/*/agents/*.md)
shopt -u nullglob

if [ "${#agents[@]}" -ge 10 ]; then
  ok "0 — 스윕이 agent ${#agents[@]}개를 실제로 열었다 (vacuous pass 아님)"
else
  no "0 — 스윕이 본 agent가 ${#agents[@]}개뿐 — glob이 깨졌거나 리포 구조가 바뀌었다"
  finish; exit
fi

fm_of() { awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$1"; }
is_pinned() { local p; for p in "${PINNED[@]}"; do [ "$p" = "$1" ] && return 0; done; return 1; }

keyed=(); bad_pin=()
for f in "${agents[@]}"; do
  lines="$(fm_of "$f" | grep -E "$MODEL_KEY")"
  if is_pinned "$f"; then
    [ "$lines" = "model: opus" ] || bad_pin+=("$f: «${lines:-키 없음}»")
  elif [ -n "$lines" ]; then
    keyed+=("$f: $(printf '%s\n' "$lines" | head -1)")
  fi
done

[ "${#keyed[@]}" -eq 0 ] && ok "1 — PINNED 밖에서 frontmatter 에 model 키를 둔 agent 0개" || {
  no "1 — PINNED 밖에서 model 키를 둔 agent ${#keyed[@]}개"
  printf '      %s\n' "${keyed[@]}"; }
[ "${#bad_pin[@]}" -eq 0 ] && ok "2 — PINNED ${#PINNED[@]}개가 정확히 한 줄 \`model: opus\` 를 갖는다" || {
  no "2 — PINNED 의 model 이 정확히 \`model: opus\` 한 줄이 아니다"
  printf '      %s\n' "${bad_pin[@]}"; }
for p in "${PINNED[@]}"; do
  [ -f "$p" ] && ok "3 — PINNED 파일이 실재한다: $p" || no "3 — PINNED 파일이 없다: $p (예외 목록이 낡았다)"
done
finish
