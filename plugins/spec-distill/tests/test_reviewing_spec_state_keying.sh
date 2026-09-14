#!/usr/bin/env bash
# state-keying 불변식 락 — reviewing-spec 이 엔진 상태를 세션(harness sid) 아래 문서별 디렉토리로 연다.
#
# 재는 것:
#   · `## 입력` 이 `state_path.py` 의 session-id · state-root 와 엔진의 `state-dir-for` 로 `STATE_DIR` 을
#     만든다 — `<state root>/<sid>/docreview/<문서별>`(엔진 상태 `docreview-state.md` 가 여기 산다). 세션
#     디렉토리 자체가 아니다 — 한 세션의 두 문서가 원장을 나눠 쓰지 않는다(spec-distill 3.1.0 · R78).
#   · SKILL 의 모든 `STATE_DIR=` 대입이 같은 도출을 거친다(실패 분기의 `STATE_DIR=""` 리셋만 뺀다).
#   · codex 펜스가 산출물 경로를 그 `$STATE_DIR` 안에서 도출한다 — 엔진 상태와 codex
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
# S2 — 옛 단언은 `^STATE_DIR="$ROOT/$harness_sid"$`(세션 디렉토리)였다. 엔진 상태는 이제 그 아래 문서별
# 디렉토리다(R78). 같은 창 · 같은 두 성분(`$ROOT` · `$harness_sid`)에 문서(`$spec_path`)를 더한 도출 줄을 잰다.
# 줄 끝까지 고정한다(main 의 `$` 앵커 — 리뷰 m5): `|| true)"` 뒤에는 주석만 올 수 있다. 값 뒤에 경로를 덧붙이는
# 변이(`|| true)/.."`)가 여기서 RED 다.
grep -qE '^STATE_DIR="\$\(python3 "\$SD/scripts/docreview_state\.py" state-dir-for --root "\$ROOT" --session "\$harness_sid" --doc "\$\{spec_path:-\}" \|\| true\)"([[:space:]]+#.*)?$' <<<"$w_out" \
  && ok "S2: 입력 절이 STATE_DIR 을 \$ROOT · \$harness_sid · \$spec_path 에서 state-dir-for 로 만든다" \
  || no "S2: 입력 절의 STATE_DIR 이 \$ROOT · \$harness_sid · \$spec_path 의 state-dir-for 도출이 아니다"

# S2a2: 엔진 상태 디렉터리는 **세션**(`$ROOT/$harness_sid`) 아래에서 **문서별로** 도출된다(파일 어디든 —
# S2 는 `## 입력` 창 안의 `$SD` 형만 잰다). 세 성분이 전부 있어야 한다:
# 루트(`$ROOT`)와 세션(`$harness_sid`)이 빠지면 같은 세션의 상태가 다른 자리에
# 앉아 재개·GC 가 서로 다른 것을 보고, 문서(`$spec_path`)가 빠지면 한 세션에서 리뷰한
# 두 문서가 한 원장의 라운드·재리뷰 상한·finding 을 나눠 쓴다. 도출이 실제로 문서마다 다른
# 자리를 내는지는 실행으로 잰다(test_reviewing_spec_residue.sh 의 P 셀).
grep -qE '^STATE_DIR="\$\(python3 "[^"]*/scripts/docreview_state\.py" state-dir-for --root "\$ROOT" --session "\$harness_sid" --doc "\$\{spec_path:-\}"' "$SKILL" \
  && ok "S2a2: 엔진 state 디렉터리가 \$ROOT · \$harness_sid · \$spec_path 에서 state-dir-for 로 도출된다" \
  || no "S2a2: \$STATE_DIR 이 \$ROOT · \$harness_sid · \$spec_path 셋에서 state-dir-for 로 도출되지 않는다 — 엔진 상태가 세션과 갈리거나 문서를 넘어 섞인다"
# S2a3 (∀ — S2a2 의 짝): SKILL 안의 `STATE_DIR=` 대입이 **전부** 같은 도출을 거친다. S2a2 는
# `## 입력` 한 줄의 존재만 잰다 — 펜스의 재도출이나 새 대입이 세션 디렉토리 자체를 쓰면
# 침묵한다. 하한 2(`## 입력` + codex 펜스)는 이 등식의 vacuity 바닥이다.
# 모집단에서 빼는 것은 **실패 분기의 리셋 줄 한 모양** — 들여쓴 정확히 `STATE_DIR=""` — 뿐이다(spec-distill
# 3.0.0 의 `## 입력` 골격이 상태 리졸버 부재 · sid 미해석 분기에서 비운다, R78 조건 4). 비우는 대입은 어느
# 디렉토리도 나눠 쓰지 않고 선결 `init` 을 `state_dir_missing` 으로 멈춘다. 들여쓰지 않은 빈 대입 · 주석이나
# 공백이 붙은 빈 대입 · 비지 않은 값은 전부 모집단에 남는다.
sd_all=$(grep -cE '^[[:space:]]*STATE_DIR=' "$SKILL")
sd_reset=$(grep -cE '^[[:space:]]+STATE_DIR=""$' "$SKILL")
sd_tot=$((sd_all - sd_reset))
sd_der=$(grep -cE '^[[:space:]]*STATE_DIR=.*docreview_state\.py" state-dir-for --root "\$ROOT" --session "\$harness_sid" --doc "\$\{spec_path:-\}"' "$SKILL")
if [[ "$sd_tot" -lt 2 ]]; then
  no "S2a3: STATE_DIR 대입이 ${sd_tot}건뿐 — \`## 입력\` 과 codex 펜스 두 자리가 안 찼다. 아래 등식은 이 상태에서 공허하다"
elif [[ "$sd_tot" -eq "$sd_der" ]]; then
  ok "S2a3: STATE_DIR 대입 ${sd_tot}건이 전부 문서별 도출을 거친다 (실패 분기의 빈 리셋 ${sd_reset}건은 모집단 밖)"
else
  no "S2a3: STATE_DIR 대입 ${sd_tot}건 중 문서별 도출은 ${sd_der}건 — 나머지가 세션 디렉토리를 문서를 넘어 나눠 쓴다"
fi
# S3 — 옛 단언은 `CODEX_YAML="$ROOT/$harness_sid/docreview-codex.yaml"`(세션 디렉토리)의 존재였다. codex
# 산출물은 이제 그 문서의 `$STATE_DIR` 안이다(R78). S2a3 이 `$STATE_DIR` 의 모든 대입을 `$ROOT/$harness_sid`
# 아래 문서별 도출로 묶으므로 둘을 합치면 옛 S3 보다 좁다. 존재가 아니라 ∀ 다 — 줄머리 `CODEX_YAML=` 대입이
# 전부 이 모양이어야 한다(하한 1).
cy_tot=$(grep -cE '^[[:space:]]*CODEX_YAML=' "$SKILL")
cy_ok=$(grep -cE '^[[:space:]]*CODEX_YAML="\$STATE_DIR/docreview-codex\.yaml"$' "$SKILL")
if [[ "$cy_tot" -ge 1 && "$cy_tot" -eq "$cy_ok" ]]; then
  ok "S3: codex 산출물 대입 ${cy_tot}건이 전부 그 문서의 \$STATE_DIR 안이다"
else
  no "S3: codex 산출물 대입 ${cy_tot}건 중 \$STATE_DIR/docreview-codex.yaml 은 ${cy_ok}건 — 엔진 상태와 다른 디렉토리로 갈린다"
fi

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
