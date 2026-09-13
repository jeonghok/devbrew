#!/usr/bin/env bash
# state-keying 불변식 락 — reviewing-spec 이 세션 상태를 harness sid 하나로 연다.
#
# 재는 것:
#   · `## 입력` 이 `state_path.py` 의 session-id · state-root 로 `STATE_DIR="$ROOT/$harness_sid"`
#     를 만든다(엔진 상태 `docreview-state.md` 가 여기 산다).
#   · codex 펜스가 산출물 경로를 같은 `$ROOT/$harness_sid` 에서 도출한다 — 엔진 상태와 codex
#     산출물이 한 디렉토리에 앉는다. 갈리면 재개·GC 가 서로 다른 것을 본다.
#   · `## 절차` 가 `--state-dir` 로 그 `$STATE_DIR` 을 넘긴다.
#   · 음의 짝: 옛 상태 파일 변수 `$STATE`(원장 파일)가 skill 어디에도 없다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$REPO_ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md"
. "$REPO_ROOT/shared/tests/assert.sh"

# 창의 끝 앵커가 실제로 범위를 닫았는지 본다 — sed 범위는 종료 주소가 없으면 EOF 까지 흐른다.
bounded_window() {  # $1=시작 정규식  $2=종료 정규식
  local out; out="$(sed -n "/$1/,/$2/p" "$SKILL")"
  [[ -n "$out" ]] || return 0
  grep -q "$2" <<<"$(tail -n1 <<<"$out")" || return 0
  printf '%s\n' "$out"
}

w_out="$(bounded_window '^## 입력$' '^## 프로필$')"
[[ -n "$w_out" ]] \
  && ok "W: 입력 윈도우가 비어 있지 않다 (앵커 생존)" \
  || no "W: 입력 윈도우가 비었다 — 구조 앵커 파손"

grep -qF 'state_path.py" session-id' <<<"$w_out" \
  && ok "S1: 입력 절이 state_path.py session-id 로 sid 를 해석한다" \
  || no "S1: 입력 절에 session-id 해석이 없다"
grep -qF 'state_path.py" state-root' <<<"$w_out" \
  && ok "S1b: 입력 절이 state_path.py state-root 로 루트를 해석한다" \
  || no "S1b: 입력 절에 state-root 해석이 없다"
grep -qE '^STATE_DIR="\$ROOT/\$harness_sid"$' <<<"$w_out" \
  && ok "S2: 입력 절이 STATE_DIR 을 \$ROOT/\$harness_sid 로 만든다" \
  || no "S2: 입력 절의 STATE_DIR 이 \$ROOT/\$harness_sid 가 아니다"

# S2a2: 엔진 상태 디렉터리는 arm 원장과 **같은 루트·세션** 아래에서 **문서별로** 도출된다.
# S2a 의 `^STATE="` 는 `STATE_DIR=` 을 매치하지 않으므로 따로 잰다. 세 성분이 전부 있어야 한다:
# 루트(`$ROOT`)와 세션(`$harness_sid`)이 arm 원장과 갈리면 같은 세션의 두 상태가 다른 자리에
# 앉아 재개·GC·훅 판독이 서로 다른 것을 보고, 문서(`$spec_path`)가 빠지면 한 세션에서 리뷰한
# 두 문서가 한 원장의 라운드·재리뷰 상한·finding 을 나눠 쓴다. 도출이 실제로 문서마다 다른
# 자리를 내는지는 실행으로 잰다(test_reviewing_spec_residue.sh 의 P 셀).
grep -qE '^STATE_DIR="\$\(python3 "[^"]*/scripts/docreview_state\.py" state-dir-for --root "\$ROOT" --session "\$harness_sid" --doc "\$\{spec_path:-\}"' "$SKILL" \
  && ok "S2a2: 엔진 state 디렉터리가 \$ROOT · \$harness_sid · \$spec_path 에서 state-dir-for 로 도출된다" \
  || no "S2a2: \$STATE_DIR 이 \$ROOT · \$harness_sid · \$spec_path 셋에서 state-dir-for 로 도출되지 않는다 — 엔진 상태가 arm 원장과 갈리거나 문서를 넘어 섞인다"
# S2a3 (∀ — S2a2 의 짝): SKILL 안의 `STATE_DIR=` 대입이 **전부** 같은 도출을 거친다. S2a2 는
# `## 입력` 한 줄의 존재만 잰다 — 펜스의 재도출이나 새 대입이 세션 디렉토리 자체를 쓰면
# 침묵한다. 하한 2(`## 입력` + codex 펜스)는 이 등식의 vacuity 바닥이다.
sd_tot=$(grep -cE '^[[:space:]]*STATE_DIR=' "$SKILL")
sd_der=$(grep -cE '^[[:space:]]*STATE_DIR=.*docreview_state\.py" state-dir-for --root "\$ROOT" --session "\$harness_sid" --doc "\$\{spec_path:-\}"' "$SKILL")
if [[ "$sd_tot" -lt 2 ]]; then
  no "S2a3: STATE_DIR 대입이 ${sd_tot}건뿐 — \`## 입력\` 과 codex 펜스 두 자리가 안 찼다. 아래 등식은 이 상태에서 공허하다"
elif [[ "$sd_tot" -eq "$sd_der" ]]; then
  ok "S2a3: STATE_DIR 대입 ${sd_tot}건이 전부 문서별 도출을 거친다"
else
  no "S2a3: STATE_DIR 대입 ${sd_tot}건 중 문서별 도출은 ${sd_der}건 — 나머지가 세션 디렉토리를 문서를 넘어 나눠 쓴다"
fi
grep -qF 'CODEX_YAML="$ROOT/$harness_sid/docreview-codex.yaml"' "$SKILL" \
  && ok "S3: codex 산출물이 같은 \$ROOT/\$harness_sid 아래 도출된다" \
  || no "S3: codex 산출물 경로가 엔진 상태와 다른 디렉토리로 갈린다"

proc="$(bounded_window '^## 절차$' '^## dispatch 블록 둘$')"
grep -qF '`--state-dir` 는 위 `$STATE_DIR`' <<<"$proc" \
  && ok "S4: 절차 절이 --state-dir 로 \$STATE_DIR 을 넘긴다" \
  || no "S4: 절차 절의 --state-dir 가 \$STATE_DIR 이 아니다 (창 ${#proc}자)"

# S5 (S2 의 음의 짝) — 옛 원장 파일 변수. `$STATE_DIR` 은 걸리지 않게 뒤를 막는다.
if grep -qE '\$STATE([^_A-Za-z0-9]|$)' "$SKILL"; then
  no "S5: skill 에 옛 원장 파일 변수 \$STATE 가 남았다: $(grep -nE '\$STATE([^_A-Za-z0-9]|$)' "$SKILL" | head -3)"
else
  ok "S5: skill 에 \$STATE 가 없다 (STATE_DIR 만 있다)"
fi
finish
