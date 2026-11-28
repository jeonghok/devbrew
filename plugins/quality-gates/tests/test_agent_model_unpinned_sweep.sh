#!/usr/bin/env bash
# 구조적 보증 — `plugins/*/agents/*.md` 의 frontmatter `model` 키.
#
# 기본은 «키 부재»다(CLI 2.1.261 실측, 2026-09-06): 리터럴 티어는 세션 모델 선택을 덮어쓰고,
# `inherit` 는 사용자의 subagent 기본 티어 설정(`CLAUDE_CODE_SUBAGENT_MODEL`)을 덮어쓴다. 키가
# 없어야 하니스가 「사용자 설정 → 세션 모델」 순으로 위임한다.
#
# 예외는 없다 — qg 리뷰 agent 도 키가 없다(R2a 사용자 결정 「세션 모델을 따른다」). 옛 qg v10
# 재결정 R3(「리뷰는 opus」, 사용자 지시)이 두 agent 를 `model: opus` 로 고정했던 것을 뒤집었다.
# 어느 agent 든 model 키가 생기면 RED 다.
#
# 범위 밖: 외부(비-devbrew) 플러그인의 하드코딩 핀은 존중한다 — 이 스윕은 이 리포의 `plugins/` 만 본다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"

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

keyed=()
for f in "${agents[@]}"; do
  lines="$(fm_of "$f" | grep -E "$MODEL_KEY")"
  if [ -n "$lines" ]; then
    keyed+=("$f: $(printf '%s\n' "$lines" | head -1)")
  fi
done

[ "${#keyed[@]}" -eq 0 ] && ok "1 — frontmatter 에 model 키를 둔 agent 0개" || {
  no "1 — model 키를 둔 agent ${#keyed[@]}개"
  printf '      %s\n' "${keyed[@]}"; }
finish
