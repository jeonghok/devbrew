#!/usr/bin/env bash
# 구조적 보증 — `plugins/*/agents/*.md` **전부**가 frontmatter 에 `model` 키를 두지 않는다.
#
# 왜 별도 스윕인가 (2026-08-04 /qg 라운드 1, pr-test-analyzer 적발):
# 모델 티어는 플러그인마다 손으로 열거한 per-agent 테스트로만 지켜지고 있었다.
# 열거는 공간에도 시간에도 fail-open이다: 내일 추가될 플러그인의 agent를 오늘
# 열거할 수 없다. 이 리포가 `tools:`를 denylist가 아니라 allowlist로 쓰는 것과 같은 논리다.
#
# 왜 «키 부재»인가 (CLI 2.1.261 실측, 2026-09-06): 리터럴 티어는 세션 모델 선택을
# 덮어쓰고, `inherit` 는 사용자의 subagent 기본 티어 설정(`CLAUDE_CODE_SUBAGENT_MODEL`)을
# 덮어쓴다. 키가 없어야 하니스가 「사용자 설정 → 세션 모델」 순으로 위임한다.
# 어느 값이든 하니스가 티어를 정하는 것이므로 키 자체를 두지 않는다.
#
# 범위 밖: 외부(비-devbrew) 플러그인의 하드코딩 핀은 존중한다 — 이 스윕은
# 이 리포가 소유한 `plugins/` 아래만 본다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

# 따옴표 키(`"model":`)·콜론 앞 공백(`model :`)·공백 없음(`model:inherit`)을 전부 잡는다 —
# YAML 이 유효하다고 보는 표기는 전부 하니스에도 유효하다.
MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"

shopt -s nullglob
agents=(plugins/*/agents/*.md)
shopt -u nullglob

# ── 스캔이 실제로 무언가를 봤는가 (vacuous-pass 방지) ────────────────────────
# glob이 아무것도 매치하지 않으면 아래 루프가 0회 돌고 전부 통과한다 — "키가 하나도
# 없다"와 "아무것도 스캔하지 않았다"가 구별되지 않는 fail-open이다.
if [ "${#agents[@]}" -ge 10 ]; then
  ok "0 — 스윕이 agent ${#agents[@]}개를 실제로 열었다 (vacuous pass 아님)"
else
  no "0 — 스윕이 본 agent가 ${#agents[@]}개뿐 — glob이 깨졌거나 리포 구조가 바뀌었다"
  finish; exit
fi

fm_of() { awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$1"; }

keyed=()
for f in "${agents[@]}"; do
  if fm_of "$f" | grep -qE "$MODEL_KEY"; then
    keyed+=("$f: $(fm_of "$f" | grep -m1 -E "$MODEL_KEY")")
  fi
done

[ "${#keyed[@]}" -eq 0 ] && ok "1 — frontmatter 에 model 키를 둔 agent 0개" || {
  no "1 — frontmatter 에 model 키를 둔 agent ${#keyed[@]}개 (리터럴이든 inherit 이든 하니스가 티어를 정한다)"
  printf '      %s\n' "${keyed[@]}"; }
finish
