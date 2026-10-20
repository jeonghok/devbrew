#!/usr/bin/env bash
# test_verdict_no_reread.sh — 최종 판정은 기계가 낸 결과 줄로만 정해진다(설계 §7 · AC17 · AC18 · R24).
#
# 판정 펜스(최종 · trivia · 걸러진 diff 빈 실행)는 세션 폴더를 다시 읽지 않는다. 판정 인자는 숫자를 만든 직후의
# 펜스가 낸 `qg-verdict-args:` 줄이고, 판정 펜스는 그 줄을 따옴표 heredoc 자리에 받아 검사한 뒤 넘긴다.
# 차등 테스트 · e2e 대역이 판정 전에 세션 폴더의 파일을 지우거나 고쳐도 판정 줄은 받은 줄의 값이어야 한다.
# 펜스는 SKILL.md 에서 표지로 뽑아 bash 와 zsh(있으면) 양쪽에서 돌린다 — Bash 도구의 셸은 zsh 다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd -- "$PLUGIN_ROOT/../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
. "$PLUGIN_ROOT/tests/lib/recritic_fixture.sh"
export PYTHONDONTWRITEBYTECODE=1
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
REF="$PLUGIN_ROOT/skills/quality-pipeline/references/differential-test.md"
README="$PLUGIN_ROOT/README.md"
V="$PLUGIN_ROOT/scripts/verdict.py"
FENCE_PY="$PLUGIN_ROOT/tests/lib/verdict_fence.py"
SHELLS="bash"; command -v zsh >/dev/null 2>&1 && SHELLS="bash zsh"

T="$(mktemp -d)"; [ -n "$T" ] && [ -d "$T" ] || { echo "mktemp 실패" >&2; exit 1; }
trap 'rm -rf "$T"' EXIT
SID="noreread01"
R="$T/r"
git init -q -b trunk "$R" && git -C "$R" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m init
RD="$R/.claude/quality-gates/$SID"; RV="$T/rv"; mkdir -p "$RD" "$RV"
HEADSHA="$(git -C "$R" rev-parse --short HEAD)"

# 펜스 뽑기 — stdin 의 글에서 본문에 needle 이 든 첫 ```bash 펜스(들여쓰기를 걷어 낸 본문).
IFS= read -r -d '' PY_FENCE <<'PY' || true
import sys, textwrap
lines = sys.stdin.read().splitlines()
needle = sys.argv[1]
i = 0
while i < len(lines):
    if lines[i].strip() == "```bash":
        j = i + 1
        body = []
        while j < len(lines) and lines[j].strip() != "```":
            body.append(lines[j]); j += 1
        text = textwrap.dedent("\n".join(body))
        if needle in text:
            print(text); break
        i = j + 1
    else:
        i += 1
PY
fence_with() { python3 -I -X utf8 -c "$PY_FENCE" "$1"; }
section() { awk -v h="$2" '$0 == h {on=1; print; next} on && /^## /{exit} on' "$1"; }

# run_verdict <셸> <표지> [이름=값 …] — 판정 펜스를 채워 R 에서 돌린다. OUT · ERR · RC · LINE 을 채운다.
run_verdict() {
  local sh="$1" marker="$2"; shift 2
  rm -f "$RD/verdict.out" "$T/fence.sh"
  [ "$marker" = final-verdict ] && set -- "QG_ARGS_RR=되올림 없음" "$@"
  if ! python3 -I "$FENCE_PY" "$SKILL" "$marker" "$T/fence.sh" "<session-id>=$SID" "$@" 2>"$T/fill.err"; then
    OUT=""; ERR="$(cat "$T/fill.err")"; RC=99; LINE=""; return
  fi
  OUT="$(cd "$R" && CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$sh" "$T/fence.sh" 2>"$T/fence.err")"; RC=$?
  ERR="$(cat "$T/fence.err")"
  LINE="$(tail -n 1 "$RD/verdict.out" 2>/dev/null)"
}

# ── 픽스처: 숫자를 만든 직후의 펜스가 낸 두 줄 ─────────────────────────────
# (1) 리뷰 결과 줄 — 막는 지적 하나를 재비판이 확인했다(합성기 --emit-verdict --verdict-args 의 마지막 줄)
printf '%s\n' '- {agent: r, file: a.py, line: 1, severity: IMPORTANT, summary: s, proposed_fix: f}' > "$RV/findings.yaml"
rf_prep "$RV"
rf_reply "$RV" 'verdicts:
  - {f: f1, verdict: confirm}'
rf_synth "$RV" --emit-verdict --verdict-args > "$RV/synth.out" 2>"$T/synth.err"
R_LINE="$(tail -n 1 "$RV/synth.out")"
assert_eq "$R_LINE" "qg-verdict-args: --blocking 1 --optional 0 --defect" "픽스처: 합성기가 리뷰 결과 줄을 냈다"
# (2) 차등 결과 줄 — D5 사본에서 verdict.py --emit-args 가 낸다
cat > "$RD/differential.yaml" <<'YAML'
adapters: [bash]
verdict_input:
  confirmed_product_defect: false
  silent_drop: false
  baseline_unrunnable: false
attribution_status: ok
degrade_causes: []
new_failures: 0
unclaimed: []
per_adapter: []
YAML
D_LINE="$(python3 "$V" --emit-args --differential "$RD/differential.yaml")"
assert_eq "$D_LINE" "qg-verdict-args: --new-failures 0" "픽스처: verdict.py --emit-args 가 차등 결과 줄을 냈다"
# (3) e2e 결과 줄 — 걷지 않은 실행도 E6 이 낸다
E_OK="qg-verdict-args: --e2e 안 함"

tamper_session() {   # 차등 테스트 · e2e 대역 — 판정 전에 세션 폴더의 판정 재료를 지우고 고친다
  rm -f "$RV/synth.out" "$RV/synth-review.out"
  printf 'adapters: [bash]\nverdict_input:\n  confirmed_product_defect: false\ndegrade_causes: []\nnew_failures: 99\n' > "$RD/differential.yaml"
  printf -- '- iter 1 · #%s · x.py · SUGGESTION\n' 1 2 3 4 5 > "$RD/excluded.md"
  printf 'status: ok\nstart: 0000000\nend: 1111111\n' > "$RD/range-scope.txt"
}

# ── AC18 — 세션 폴더를 바꿔도 판정 줄은 받은 줄의 값이다 ─────────────────────
case_final_verdict_ignores_tampered_session() {
  local sh
  for sh in $SHELLS; do
    tamper_session
    [ ! -e "$RV/synth.out" ] && ok "[$sh] 전제: 대역이 synth.out 을 지웠다" || no "[$sh] 전제: synth.out 이 남았다"
    assert_contains "$(cat "$RD/differential.yaml")" 'new_failures: 99' "[$sh] 전제: 대역이 new_failures 를 99 로 고쳤다"
    assert_eq "$(grep -c '^- ' "$RD/excluded.md")" "5" "[$sh] 전제: 대역이 excluded.md 에 다섯 줄을 더했다"
    run_verdict "$sh" final-verdict "QG_ARGS_R=$R_LINE" "QG_ARGS_D=$D_LINE" "QG_ARGS_X=" "QG_ARGS_S=" "QG_ARGS_E=$E_OK" "<N>=1"
    assert_eq "$RC" "0" "[$sh] 최종 판정 펜스 rc 0 (stderr: ${ERR})"
    assert_contains "$OUT" 'verdict rc=0' "[$sh] verdict.py 가 rc 0 으로 끝났다"
    assert_eq "$LINE" "qg: defect · 막는 지적 1 · 선택 0 · 차등 새 실패 0 · e2e 안 함 · 제외 패치 0 · iter 1 · $HEADSHA" \
      "[$sh] 판정 줄은 받은 줄들과 기본값(제외 0 · 지금 HEAD)이다 — 변조 값(99 · 5 · 범위 파일의 끝)이 아니다"
    assert_not_contains "$LINE" ' · 차등 새 실패 99 · ' "[$sh] 판정 줄의 차등 새 실패 칸이 변조한 99 가 아니다"
    assert_not_contains "$LINE" ' · 제외 패치 5 · ' "[$sh] 판정 줄의 제외 패치 칸이 변조한 5 가 아니다"
    assert_grep "$(cat "$RD/verdict.out" 2>/dev/null)" '^verdict: defect$' "[$sh] 판정값은 defect"
  done
}

# 양성 대조 — 펜스는 받은 자리를 실제로 쓴다(위 단언이 공허하지 않다).
case_positive_control_slots_are_used() {
  local sh
  for sh in $SHELLS; do
    run_verdict "$sh" final-verdict "QG_ARGS_R=$R_LINE" "QG_ARGS_D=qg-verdict-args: --new-failures 99" \
      "QG_ARGS_X=qg-verdict-args: --excluded 5" "QG_ARGS_S=qg-verdict-args: --sha abc1234" \
      "QG_ARGS_E=qg-verdict-args: --e2e 꺼짐(kill switch) --e2e-overridden" "<N>=3"
    assert_eq "$RC" "0" "[$sh] 양성 대조 rc 0 (stderr: ${ERR})"
    assert_eq "$LINE" "qg: defect · 막는 지적 1 · 선택 0 · 차등 새 실패 99 · e2e 꺼짐(kill switch) (사람이 뒤집음) · 제외 패치 5 · iter 3 · abc1234" \
      "[$sh] 양성 대조: 다섯 자리의 값이 판정 줄에 그대로 실린다"
    run_verdict "$sh" final-verdict "QG_ARGS_R=qg-verdict-args: --blocking 0 --optional 2 --reason scope-empty" \
      "QG_ARGS_D=qg-verdict-args: --new-failures 1 --defect --reason silent-drop" "QG_ARGS_X=" "QG_ARGS_S=" \
      "QG_ARGS_E=qg-verdict-args: --e2e 미확인" "<N>=2"
    assert_eq "$RC" "0" "[$sh] 리뷰 사유 + 차등 결함 rc 0 (stderr: ${ERR})"
    assert_grep "$(cat "$RD/verdict.out" 2>/dev/null)" '^reasons: \[scope-empty, silent-drop, e2e-unconfirmed\]$' \
      "[$sh] 리뷰 · 차등 · e2e 사유가 한 판정에 모인다"
    assert_eq "$LINE" "qg: defect · 막는 지적 0 · 선택 2 · 차등 새 실패 1 · e2e 미확인 · 제외 패치 0 · iter 2 · $HEADSHA" \
      "[$sh] 차등 결함이 판정을 defect 로 만든다"
  done
}

# 막는 길 — 자리가 비었거나 모양 밖이면 판정 줄 없이 멈춘다(fail-closed).
case_bad_lines_fail_closed() {
  local sh label r d x s e want
  for sh in $SHELLS; do
    while IFS='|' read -r label r d x s e want; do
      [ -n "$label" ] || continue
      run_verdict "$sh" final-verdict "QG_ARGS_R=$r" "QG_ARGS_D=$d" "QG_ARGS_X=$x" "QG_ARGS_S=$s" "QG_ARGS_E=$e" "<N>=1"
      if [ "$RC" -ne 0 ] && [ "$RC" -ne 99 ]; then ok "[$sh] $label: 0 이 아닌 값으로 끝난다 (rc $RC)"; else no "[$sh] $label: rc $RC"; fi
      [ ! -e "$RD/verdict.out" ] && ok "[$sh] $label: verdict.out 을 쓰지 않는다" || no "[$sh] $label: verdict.out 이 생겼다"
      assert_contains "$ERR" "$want" "[$sh] $label: 멈춘 이유를 밝힌다"
    done <<EOF
리뷰 줄 없음||$D_LINE|||$E_OK|리뷰 결과 줄이나 차등 테스트 결과 줄이 비었다
차등 줄 없음|$R_LINE||||$E_OK|리뷰 결과 줄이나 차등 테스트 결과 줄이 비었다
e2e 줄 없음|$R_LINE|$D_LINE||||e2e 결과 줄이 비었다
리뷰 자리에 자리표시가 남음|<리뷰 줄>|$D_LINE|||$E_OK|리뷰 결과 줄이 정해진 모양
리뷰 줄이 합성기 본문 줄|blocking: 1|$D_LINE|||$E_OK|리뷰 결과 줄이 정해진 모양
리뷰 줄에 차등 축 인자|qg-verdict-args: --blocking 0 --optional 0 --new-failures 0|$D_LINE|||$E_OK|이 줄에 올 수 없는 값(--new-failures)
차등 줄에 리뷰 축 인자|$R_LINE|qg-verdict-args: --new-failures 0 --blocking 0|||$E_OK|이 줄에 올 수 없는 값(--blocking)
리뷰 줄에 같은 이름 두 번|qg-verdict-args: --blocking 1 --blocking 0 --optional 0|$D_LINE|||$E_OK|같은 값(--blocking)이 두 번
제외 줄에 범위 인자|$R_LINE|$D_LINE|qg-verdict-args: --sha abc1234||$E_OK|이 줄에 올 수 없는 값(--sha)
범위 줄 값이 대문자|$R_LINE|$D_LINE||qg-verdict-args: --sha ABC1234|$E_OK|범위 결과 줄이 정해진 모양
값이 - 로 시작(-h)|qg-verdict-args: --blocking 1 --optional 0 --reason -h|$D_LINE|||$E_OK|리뷰 결과 줄이 정해진 모양
값이 - 로 시작(-1)|qg-verdict-args: --blocking -1 --optional 0|$D_LINE|||$E_OK|리뷰 결과 줄이 정해진 모양
도움말 이름|qg-verdict-args: --blocking 1 --optional 0 --help|$D_LINE|||$E_OK|이 줄에 올 수 없는 값(--help)
값 없는 이름에 값|qg-verdict-args: --blocking 1 --optional 0 --defect 1|$D_LINE|||$E_OK|이름 없는 값(1)
값이 필요한 이름에 값 없음|qg-verdict-args: --blocking --optional 0|$D_LINE|||$E_OK|--blocking 에 값이 없다
끝 이름에 값 없음|$R_LINE|qg-verdict-args: --new-failures|||$E_OK|--new-failures 에 값이 없다
사유에 값 없음|qg-verdict-args: --blocking 0 --optional 0 --reason|$D_LINE|||$E_OK|--reason 에 값이 없다
e2e 칸이 열거 밖|$R_LINE|$D_LINE|||qg-verdict-args: --e2e 몰라|e2e 결과 줄의 칸이 정해진 값이 아니다
e2e 줄 머리가 없음|$R_LINE|$D_LINE|||--e2e pass|e2e 결과 줄이 정해진 모양
EOF
  done
  # 되올린 뒤 리뷰 자리는 비울 수 없다 — 빈 줄이면 리뷰 자리의 줄로 조용히 넘어가지 않고 멈춘다.
  local rrl rrv rrw
  for sh in $SHELLS; do
    while IFS='|' read -r rrl rrv rrw; do
      [ -n "$rrl" ] || continue
      run_verdict "$sh" final-verdict "QG_ARGS_R=$R_LINE" "QG_ARGS_RR=$rrv" "QG_ARGS_D=$D_LINE" "QG_ARGS_X=" "QG_ARGS_S=" "QG_ARGS_E=$E_OK" "<N>=1"
      assert_eq "$RC" "4" "[$sh] $rrl: 판정 펜스가 4 로 끝난다"
      [ ! -e "$RD/verdict.out" ] && ok "[$sh] $rrl: verdict.out 을 쓰지 않는다" || no "[$sh] $rrl: verdict.out 이 생겼다"
      assert_contains "$ERR" "$rrw" "[$sh] $rrl: 멈춘 이유를 밝힌다"
    done <<EOF
RR 빈 줄||되올리기 여부가 비었다 — 되올리지 않았으면 되올림 없음 을 적어라
RR 자리표시가 남음|<되올린 뒤 리뷰 결과 줄 — 되올리지 않았으면 되올림 없음>|되올린 뒤 리뷰 결과 줄이 정해진 모양(qg-verdict-args: --이름 값 …)이 아니다 — 되올리지 않았으면 되올림 없음 을 글자 그대로 적어라
RR 뒤에 글이 붙음|되올림 없음 (사용자가 고르지 않음)|되올린 뒤 리뷰 결과 줄이 정해진 모양(qg-verdict-args: --이름 값 …)이 아니다 — 되올리지 않았으면 되올림 없음 을 글자 그대로 적어라
EOF
    # 두 줄 — 첫 줄만 읽고 나머지를 버리지 않는다(되올림 없음 뒤에 줄이 더 있어도 리뷰 자리의 줄로 넘어가지 않는다)
    for rrv in "되올림 없음
qg-verdict-args: --blocking 2 --optional 0 --defect" "되올림 없음

x"; do
      run_verdict "$sh" final-verdict "QG_ARGS_R=$R_LINE" "QG_ARGS_RR=$rrv" "QG_ARGS_D=$D_LINE" "QG_ARGS_X=" "QG_ARGS_S=" "QG_ARGS_E=$E_OK" "<N>=1"
      assert_eq "$RC" "4" "[$sh] RR 두 줄 이상: 판정 펜스가 4 로 끝난다"
      [ ! -e "$RD/verdict.out" ] && ok "[$sh] RR 두 줄 이상: verdict.out 을 쓰지 않는다" || no "[$sh] RR 두 줄 이상: verdict.out 이 생겼다"
      assert_contains "$ERR" "되올린 뒤 리뷰 자리에 줄이 둘 이상이다" "[$sh] RR 두 줄 이상: 멈춘 이유를 밝힌다"
    done
    # 리뷰 자리의 모양 오류에는 되올리기 안내가 붙지 않는다
    run_verdict "$sh" final-verdict "QG_ARGS_R=blocking: 1" "QG_ARGS_D=$D_LINE" "QG_ARGS_X=" "QG_ARGS_S=" "QG_ARGS_E=$E_OK" "<N>=1"
    assert_not_contains "$ERR" "되올림 없음 을 글자 그대로" "[$sh] 리뷰 자리의 모양 오류에는 되올리기 안내가 없다"
    # 양성 짝 — 되올림 없음 이면 리뷰 자리의 줄로 판정한다
    run_verdict "$sh" final-verdict "QG_ARGS_R=$R_LINE" "QG_ARGS_RR=되올림 없음" "QG_ARGS_D=$D_LINE" "QG_ARGS_X=" "QG_ARGS_S=" "QG_ARGS_E=$E_OK" "<N>=1"
    assert_eq "$RC" "0" "[$sh] 되올림 없음 → R 사용: rc 0 (stderr: ${ERR})"
    assert_eq "$LINE" "qg: defect · 막는 지적 1 · 선택 0 · 차등 새 실패 0 · e2e 안 함 · 제외 패치 0 · iter 1 · $HEADSHA" \
      "[$sh] 되올림 없음 → R 사용: 판정 줄은 리뷰 자리의 줄의 값이다"
  done
  # verdict.py 는 -h · --help 로 도움말을 내고 0 으로 끝나지 않는다(판정 인자 자리의 낱말이 판정 없이 성공하지 못한다)
  local rc h
  for h in -h --help; do
    rc=0; python3 "$V" --line --blocking 0 --optional 0 --new-failures 0 --excluded 0 --iter 1 --sha abc1234 "$h" >/dev/null 2>&1 || rc=$?
    assert_eq "$rc" "2" "verdict.py $h 는 사용법 오류(rc 2)다"
  done
}

# 위조 줄 — 자리에 셸 확장을 심어도 펼쳐지지 않고 멈춘다(따옴표 heredoc · eval 없음).
case_forged_line_is_not_expanded() {
  local sh m1 m2 m3 m4
  for sh in $SHELLS; do
    m1="$T/pwned-$sh-1"; m2="$T/pwned-$sh-2"; m3="$T/pwned-$sh-3"; m4="$T/pwned-$sh-4"
    rm -f "$m1" "$m2" "$m3" "$m4"
    run_verdict "$sh" final-verdict "QG_ARGS_R=qg-verdict-args: --blocking 0 --optional 0 \$(touch $m1)" \
      "QG_ARGS_D=$D_LINE" "QG_ARGS_X=" "QG_ARGS_S=" "QG_ARGS_E=$E_OK" "<N>=1"
    [ ! -e "$m1" ] && ok "[$sh] 위조 \$( ) 줄이 실행되지 않는다" || no "[$sh] 위조 \$( ) 줄이 실행됐다"
    [ "$RC" -ne 0 ] && [ "$RC" -ne 99 ] && [ ! -e "$RD/verdict.out" ] && ok "[$sh] 위조 \$( ) 줄은 판정 없이 멈춘다" || no "[$sh] 위조 \$( ) 줄로 판정이 나왔다 (rc $RC)"
    run_verdict "$sh" final-verdict "QG_ARGS_R=$R_LINE" "QG_ARGS_D=qg-verdict-args: --new-failures \`touch $m2\`" \
      "QG_ARGS_X=" "QG_ARGS_S=" "QG_ARGS_E=$E_OK" "<N>=1"
    [ ! -e "$m2" ] && ok "[$sh] 위조 역따옴표 줄이 실행되지 않는다" || no "[$sh] 위조 역따옴표 줄이 실행됐다"
    [ "$RC" -ne 0 ] && [ "$RC" -ne 99 ] && [ ! -e "$RD/verdict.out" ] && ok "[$sh] 위조 역따옴표 줄은 판정 없이 멈춘다" || no "[$sh] 위조 역따옴표 줄로 판정이 나왔다 (rc $RC)"
    run_verdict "$sh" final-verdict "QG_ARGS_R=$R_LINE" "QG_ARGS_D=$D_LINE" "QG_ARGS_X=" "QG_ARGS_S=" \
      "QG_ARGS_E=qg-verdict-args: --e2e pass\$(touch $m3)" "<N>=1"
    [ ! -e "$m3" ] && ok "[$sh] 위조 e2e 줄이 실행되지 않는다" || no "[$sh] 위조 e2e 줄이 실행됐다"
    [ "$RC" -ne 0 ] && [ "$RC" -ne 99 ] && [ ! -e "$RD/verdict.out" ] && ok "[$sh] 위조 e2e 줄은 판정 없이 멈춘다" || no "[$sh] 위조 e2e 줄로 판정이 나왔다 (rc $RC)"
    run_verdict "$sh" final-verdict "QG_ARGS_R=$R_LINE" "QG_ARGS_D=$D_LINE" "QG_ARGS_X=qg-verdict-args: --excluded *" \
      "QG_ARGS_S=" "QG_ARGS_E=$E_OK" "<N>=1"
    [ "$RC" -ne 0 ] && [ "$RC" -ne 99 ] && [ ! -e "$RD/verdict.out" ] && ok "[$sh] 글롭 글자가 든 줄은 판정 없이 멈춘다" || no "[$sh] 글롭 글자가 든 줄로 판정이 나왔다 (rc $RC)"
    run_verdict "$sh" trivia-verdict "QG_ARGS_R=" "QG_ARGS_D=" "QG_ARGS_X=" "QG_ARGS_S=qg-verdict-args: --sha \$(touch $m4)" "QG_ARGS_E="
    [ ! -e "$m4" ] && ok "[$sh] trivia 펜스도 위조 줄을 펼치지 않는다" || no "[$sh] trivia 펜스가 위조 줄을 실행했다"
    [ "$RC" -ne 0 ] && [ "$RC" -ne 99 ] && [ ! -e "$RD/verdict.out" ] && ok "[$sh] trivia 펜스도 위조 줄로 멈춘다" || no "[$sh] trivia 펜스가 위조 줄로 판정을 냈다 (rc $RC)"
  done
}

# 되올린 뒤 리뷰 결과 줄(차등 테스트 뒤 세션 폴더에서 만든 줄)은 차등 테스트 전 리뷰 결과 줄보다 느슨할 수 없다.
case_restore_line_cannot_loosen() {
  local sh label r0 rr want
  R0="qg-verdict-args: --blocking 2 --optional 0 --defect --review-blocked --reason scope-empty"
  for sh in $SHELLS; do
    while IFS='|' read -r label rr want; do
      [ -n "$label" ] || continue
      run_verdict "$sh" final-verdict "QG_ARGS_R=$R0" "QG_ARGS_RR=$rr" "QG_ARGS_D=$D_LINE" "QG_ARGS_X=" "QG_ARGS_S=" "QG_ARGS_E=$E_OK" "<N>=1"
      if [ "$RC" -ne 0 ] && [ "$RC" -ne 99 ]; then ok "[$sh] $label: 0 이 아닌 값으로 끝난다 (rc $RC)"; else no "[$sh] $label: rc $RC"; fi
      [ ! -e "$RD/verdict.out" ] && ok "[$sh] $label: verdict.out 을 쓰지 않는다" || no "[$sh] $label: verdict.out 이 생겼다"
      assert_contains "$ERR" "$want" "[$sh] $label: 멈춘 이유를 밝힌다"
    done <<EOF
막는 지적 수가 줄었다|qg-verdict-args: --blocking 1 --optional 1 --defect --review-blocked --reason scope-empty|막는 지적 수가 차등 테스트 전 리뷰 결과 줄보다 적거나
사유가 빠졌다|qg-verdict-args: --blocking 2 --optional 0 --defect --review-blocked|--reason scope-empty 가 없다
결함 표시가 빠졌다|qg-verdict-args: --blocking 2 --optional 0 --review-blocked --reason scope-empty|--defect 가 없다
항목 소실 표시가 빠졌다|qg-verdict-args: --blocking 3 --optional 0 --defect --reason scope-empty|--review-blocked 가 없다
막는 지적 수가 없다|qg-verdict-args: --optional 0 --defect --review-blocked --reason scope-empty|막는 지적 수가 차등 테스트 전 리뷰 결과 줄보다 적거나
되올린 줄이 모양 밖|blocking: 3|되올린 뒤 리뷰 결과 줄이 정해진 모양
EOF
    # 양성 짝 — 되올리기가 막는 지적을 늘리면 그 줄이 판정에 쓰인다
    run_verdict "$sh" final-verdict "QG_ARGS_R=qg-verdict-args: --blocking 0 --optional 1" \
      "QG_ARGS_RR=qg-verdict-args: --blocking 1 --optional 0 --defect" "QG_ARGS_D=$D_LINE" "QG_ARGS_X=" "QG_ARGS_S=" "QG_ARGS_E=$E_OK" "<N>=1"
    assert_eq "$RC" "0" "[$sh] 되올린 줄이 더 엄하면 rc 0 (stderr: ${ERR})"
    assert_eq "$LINE" "qg: defect · 막는 지적 1 · 선택 0 · 차등 새 실패 0 · e2e 안 함 · 제외 패치 0 · iter 1 · $HEADSHA" \
      "[$sh] 되올린 뒤 리뷰 결과 줄의 수가 판정 줄에 실린다"
    run_verdict "$sh" final-verdict "QG_ARGS_R=$R0" \
      "QG_ARGS_RR=qg-verdict-args: --blocking 2 --optional 0 --defect --review-blocked --reason merge-conflict --reason scope-empty" \
      "QG_ARGS_D=$D_LINE" "QG_ARGS_X=" "QG_ARGS_S=" "QG_ARGS_E=$E_OK" "<N>=1"
    assert_eq "$RC" "0" "[$sh] 같은 수 · 사유가 더 많은 되올린 줄은 받는다 (stderr: ${ERR})"
    assert_grep "$(cat "$RD/verdict.out" 2>/dev/null)" '^reasons: \[merge-conflict, scope-empty, findings-lost\]$' "[$sh] 되올린 줄의 사유가 판정에 실린다"
  done
}

# trivia · 걸러진 diff 빈 실행 — 같은 다섯 자리, 빈 자리는 0 기본값이고 세션 폴더를 읽지 않는다.
case_trivia_and_scope_empty_fences() {
  local sh
  for sh in $SHELLS; do
    tamper_session
    run_verdict "$sh" trivia-verdict "QG_ARGS_R=" "QG_ARGS_D=" "QG_ARGS_X=" "QG_ARGS_S=" "QG_ARGS_E="
    assert_eq "$RC" "0" "[$sh] trivia 펜스 rc 0 (stderr: ${ERR})"
    assert_eq "$LINE" "qg: not-certified (trivia) · 막는 지적 0 · 선택 0 · 차등 새 실패 0 · e2e 안 함 · 제외 패치 0 · iter 0 · $HEADSHA" \
      "[$sh] trivia 판정 줄 — 범위 파일 · excluded.md 를 읽지 않는다"
    run_verdict "$sh" trivia-verdict "QG_ARGS_R=" "QG_ARGS_D=" "QG_ARGS_X=" "QG_ARGS_S=qg-verdict-args: --sha abc1234" "QG_ARGS_E="
    assert_eq "$LINE" "qg: not-certified (trivia) · 막는 지적 0 · 선택 0 · 차등 새 실패 0 · e2e 안 함 · 제외 패치 0 · iter 0 · abc1234" \
      "[$sh] trivia 판정 줄 — 범위 줄의 커밋을 쓴다(양성 짝)"
    tamper_session
    run_verdict "$sh" scope-empty-verdict "QG_ARGS_R=" "QG_ARGS_D=" "QG_ARGS_X=qg-verdict-args: --excluded 2" "QG_ARGS_S=" "QG_ARGS_E=" "<N>=2"
    assert_eq "$RC" "0" "[$sh] 걸러진 diff 빈 실행 펜스 rc 0 (stderr: ${ERR})"
    assert_eq "$LINE" "qg: not-certified (scope-empty) · 막는 지적 0 · 선택 0 · 차등 새 실패 0 · e2e 안 함 · 제외 패치 2 · iter 2 · $HEADSHA" \
      "[$sh] 걸러진 diff 빈 실행 판정 줄 — 제외 줄의 2 이지 excluded.md 의 5 가 아니다"
  done
}

# ── AC17 — 숫자를 만드는 펜스가 결과 줄을 낸다 ───────────────────────────────
case_review_axis_synthesis_precedes_the_differential_test() {
  local s35 s39 s4 dt s39w fence
  s35=$(grep -nxF '### Step 3.5 — re-critique (판정 각도)' "$SKILL" | cut -d: -f1)
  s39=$(grep -nxF '### Step 3.9 — 리뷰 축 합성 (차등 테스트 전)' "$SKILL" | cut -d: -f1)
  s4=$(grep -nxF '### Step 4 — synthesis (after the differential test)' "$SKILL" | cut -d: -f1)
  dt=$(grep -nxF '## Differential test' "$SKILL" | cut -d: -f1)
  if [ -n "$s35" ] && [ -n "$s39" ] && [ -n "$s4" ] && [ -n "$dt" ] && [ "$s35" -lt "$s39" ] && [ "$s39" -lt "$s4" ] && [ "$s4" -lt "$dt" ]; then
    ok "Step 3.9 가 Step 3.5 와 Step 4 사이에 있다"
  else no "Step 3.9 위치 (3.5=$s35 3.9=$s39 4=$s4 차등=$dt)"; fi
  s39w=$(awk '$0 == "### Step 3.9 — 리뷰 축 합성 (차등 테스트 전)" {on=1; next} on && /^### /{exit} on' "$SKILL")
  fence=$(printf '%s\n' "$s39w" | fence_with 'synthesize_findings.py')
  assert_contains "$fence" '--emit-verdict --angles "$RV/angles.txt" --verdict-args' "Step 3.9: 합성기가 리뷰 결과 줄을 낸다"
  assert_contains "$fence" '> "$RV/synth-review.out"' "Step 3.9: 출력은 Step 4 와 따로 synth-review.out 이다"
  assert_eq "$(printf '%s\n' "$fence" | tail -n 1)" 'tail -n 1 "$RV/synth-review.out"' "Step 3.9: 펜스의 마지막 명령이 리뷰 결과 줄을 보인다"
  assert_not_contains "$fence" '--differential' "Step 3.9: 차등 입력을 싣지 않는다"
  assert_not_contains "$fence" 'kill-switch' "Step 3.9: 차등 기원 사유(kill-switch)를 싣지 않는다"
  assert_contains "$s39w" '② 에서 온 세 행' "Step 3.9: 판정 입력은 Step 4 표에서 ② 의 행을 뺀 것이다"
  # R4 — Step 4 본 합성은 리뷰 결과 줄을 내지 않는다. 되올려 다시 합성하기만 새 줄을 낸다.
  local s4w s4f
  s4w=$(awk '$0 == "### Step 4 — synthesis (after the differential test)" {on=1; next} on && /^### /{exit} on' "$SKILL")
  s4f=$(printf '%s\n' "$s4w" | fence_with 'synthesize_findings.py')
  assert_contains "$s4f" '> "$RV/synth.out"' "Step 4: 본 합성 펜스(양성 짝)"
  assert_not_contains "$s4f" '--verdict-args' "Step 4: 본 합성은 리뷰 결과 줄을 내지 않는다"
  assert_not_contains "$s4w" '--verdict-args' "Step 4: 되올려 다시 합성하기도 Step 4 합성으로는 리뷰 결과 줄을 내지 않는다(차등 기원 사유가 섞인다)"
  assert_contains "$s4w" 'Step 3.9 의 펜스를 같은 판정 입력에 같은 `--restore-lowered <번호들>` 을 더해 다시 돌린다' "되올린 뒤 리뷰 결과 줄은 Step 3.9 를 다시 돌려 낸다"
  assert_contains "$s4w" 'Step 3.9 가 처음 낸 줄도 버리지 않는다 — 판정 펜스가' "되올리기 전 리뷰 결과 줄을 판정 펜스가 함께 받는다"
  local fvs; fvs=$(section "$SKILL" '## Final verdict')
  assert_contains "$fvs" '| `QG_ARGS_RR` 되올린 뒤 리뷰(최종 판정 펜스만) |' "Final verdict: 되올린 뒤 리뷰 자리"
  assert_contains "$fvs" '자리(따옴표 here-doc 의 몸)마다 정확히 한 줄 — 그 줄을 낸 펜스가 출력한 `qg-verdict-args: …` 기계 줄 하나 — 만 글자 그대로 넣는다.' \
    "Final verdict: 자리마다 기계 줄 정확히 한 줄"
  local flow a b c
  flow=$(section "$SKILL" '## Flow')
  a=$(printf '%s\n' "$flow" | grep -n '│   ① 리뷰 ' | head -1 | cut -d: -f1)
  b=$(printf '%s\n' "$flow" | grep -n "│   ①' 리뷰 축 합성" | head -1 | cut -d: -f1)
  c=$(printf '%s\n' "$flow" | grep -n '│   ② 차등 테스트' | head -1 | cut -d: -f1)
  if [ -n "$a" ] && [ -n "$b" ] && [ -n "$c" ] && [ "$a" -lt "$b" ] && [ "$b" -lt "$c" ]; then ok "Flow: ①' 리뷰 축 합성이 ① 과 ② 사이다"
  else no "Flow: ①' 위치 (①=$a ①'=$b ②=$c)"; fi
}

case_differential_line_producers() {
  local d5 fake out
  d5=$(section "$REF" '## D5 짝짓기 — 매 iteration' | fence_with 'diff-test-results.py')
  assert_contains "$d5" 'python3 "$QG/scripts/verdict.py" --emit-args --differential "$RD/differential.yaml"' "D5: 사본이 있으면 그 사본으로 차등 결과 줄"
  assert_contains "$d5" 'python3 "$QG/scripts/verdict.py" --emit-args --reason error-axis' "D5: 사본이 없으면 error-axis 차등 결과 줄"
  # D5 펜스를 실제로 돌린다 — 짝짓기 스크립트는 정해진 출력과 rc 를 내는 대역, verdict.py 는 진짜다.
  fake="$T/fakeplug"; mkdir -p "$fake/scripts" "$T/memo"; cp "$V" "$fake/scripts/verdict.py"
  printf '#!/bin/sh\nif [ "${STUB_RC:-0}" != 0 ]; then exit "$STUB_RC"; fi\nprintf "adapters: [bash]\\nverdict_input:\\n  confirmed_product_defect: true\\ndegrade_causes: [silent-drop]\\nnew_failures: 2\\n"\n' > "$fake/scripts/diff-test-results.py"
  chmod +x "$fake/scripts/diff-test-results.py"
  printf '%s\n' "$d5" | sed -e "s|<memo>|$T/memo|g" -e 's/<N>/1/g' -e "s/<session-id>/$SID/g" \
    -e 's/<기준선 커밋>/b0/g' -e 's/<HEAD 커밋>/h0/g' > "$T/d5.sh"
  out=$(cd "$R" && CLAUDE_PLUGIN_ROOT="$fake" bash "$T/d5.sh" 2>/dev/null)
  assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "qg-verdict-args: --new-failures 2 --defect --reason silent-drop" "D5 실행: 마지막 줄이 사본에서 낸 차등 결과 줄"
  out=$(cd "$R" && CLAUDE_PLUGIN_ROOT="$fake" STUB_RC=4 bash "$T/d5.sh" 2>/dev/null)
  assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "qg-verdict-args: --new-failures 0 --reason error-axis" "D5 실행: 짝짓기가 실패하면 error-axis 차등 결과 줄"
  # D7 — D5 에 닿지 못한 반복의 줄, SKILL 의 kill switch 펜스의 줄
  local d7 ks
  d7=$(section "$REF" '## D7 판정 입력' | fence_with '--emit-args')
  out=$(cd "$R" && CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash -c "$d7" 2>/dev/null)
  assert_eq "$out" "qg-verdict-args: --new-failures 0 --reason error-axis" "D7 펜스: D5 전에 끝난 반복의 차등 결과 줄"
  ks=$(section "$SKILL" '## Differential test' | fence_with '--emit-args')
  out=$(cd "$R" && CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash -c "$ks" 2>/dev/null)
  assert_eq "$out" "qg-verdict-args: --new-failures 0 --reason kill-switch" "kill switch 펜스: 차등 결과 줄"
  # 새 R24 문장은 절차에 한 번, 옛 두 문장은 없다
  assert_eq "$(grep -cxF -- '- R24 판정 인자는 숫자를 만든 직후의 펜스가 낸 줄(`qg-verdict-args:`)의 글자 그대로다 — 모델은 숫자를 고르거나 옮겨 적지 않고 그 줄을 판정 펜스에 붙인다.' "$REF")" "1" \
    "R24: 새 문장이 지킬 것 목록에 줄 전체로 한 번 있다"
  # 옛 두 문장은 따옴표를 끊어 둔다 — 금지 문장 grep 이 이 락 자신을 세지 않는다(런타임 값은 이어진 문장이다).
  assert_eq "$(grep -c '판정은 기계 출력을 직접'' 읽고' "$REF" "$SKILL" | awk -F: '{s+=$NF} END{print s+0}')" "0" "R24: 옛 R24 문장(판정이 기계 출력을 읽는다는 뜻)이 절차 · SKILL 에 없다"
  assert_eq "$(grep -c '사본을 직접'' 읽어 정한다' "$REF" "$SKILL" | awk -F: '{s+=$NF} END{print s+0}')" "0" "R24: 옛 D7 문장(verdict.py 가 사본을 읽어 판정한다는 뜻)이 절차 · SKILL 에 없다"
}

case_excluded_scope_e2e_producers() {
  local xf out sh rc
  xf=$(section "$SKILL" '## Fix-loop' | fence_with "qg-verdict-args: --excluded")
  [ -n "$xf" ] && ok "Fix-loop: 제외 결과 줄 펜스가 있다" || no "Fix-loop: 제외 결과 줄 펜스가 없다"
  assert_not_contains "$xf" 'grep -c' "제외 결과 줄: excluded.md 를 다시 세지 않는다"
  x_run() {   # x_run <셸> <앞 줄> <더할 줄들> — out · rc 를 채운다
    python3 -I "$FENCE_PY" "$SKILL" excluded-line "$T/x.sh" "<session-id>=$SID" "QG_ARGS_XPREV=$2" "QG_EXCLUDED_ADD=$3" 2>"$T/x.fill" \
      || { out="$(cat "$T/x.fill")"; rc=99; return; }
    out=$(cd "$R" && "$1" "$T/x.sh" 2>&1); rc=$?
  }
  for sh in $SHELLS; do
    rm -rf "$RD/excluded.md"
    x_run "$sh" "" ""
    assert_eq "$out" "qg-verdict-args: --excluded 0" "[$sh] 제외 결과 줄: 앞 줄도 더할 줄도 없으면 0"
    x_run "$sh" "" $'- iter 1 · #2 · b.py · SUGGESTION\n- iter 1 · #3 · c.py · 사용자 제외'
    assert_eq "$out" "qg-verdict-args: --excluded 2" "[$sh] 제외 결과 줄: 이번에 더한 줄 수"
    assert_eq "$(grep -c '^- ' "$RD/excluded.md")" "2" "[$sh] 제외 결과 줄 펜스가 그 줄들을 excluded.md 에 더했다"
    : > "$RD/excluded.md"   # 차등 테스트가 돌린 레포 코드가 기록을 비웠다
    x_run "$sh" "qg-verdict-args: --excluded 2" '- iter 2 · #1 · d.py · SUGGESTION'
    assert_eq "$out" "qg-verdict-args: --excluded 3" "[$sh] 제외 결과 줄: 기록을 비워도 누계는 앞 줄 2 + 이번 1"
    printf -- '- a\n- b\n- c\n- d\n- e\n' >> "$RD/excluded.md"   # 거꾸로 부풀린 경우
    x_run "$sh" "qg-verdict-args: --excluded 3" ""
    assert_eq "$out" "qg-verdict-args: --excluded 3" "[$sh] 제외 결과 줄: 기록을 부풀려도 누계는 그대로"
    for bad in "qg-verdict-args: --excluded 07" "qg-verdict-args: --excluded 3 --sha abc1234" "qg-verdict-args: --excluded" "excluded: 3" "qg-verdict-args: --excluded 1234567890"; do
      x_run "$sh" "$bad" ""
      if [ "$rc" -ne 0 ] && [ "$rc" -ne 99 ]; then ok "[$sh] 앞 줄 '$bad' 는 멈춘다"; else no "[$sh] 앞 줄 '$bad' 가 멈추지 않았다 (rc $rc: $out)"; fi
      assert_not_grep "$out" '^qg-verdict-args:' "[$sh] 앞 줄 '$bad' 면 결과 줄을 내지 않는다"
    done
    x_run "$sh" "" 'iter 3 · #1 · e.py · SUGGESTION'
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 99 ]; then ok "[$sh] 「- 」 로 시작하지 않는 더할 줄은 멈춘다"; else no "[$sh] 「- 」 없는 줄이 멈추지 않았다 (rc $rc)"; fi
    rm -f "$RD/excluded.md"; mkdir "$RD/excluded.md"
    x_run "$sh" "" '- iter 1 · #1 · a.py · SUGGESTION'
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 99 ]; then ok "[$sh] excluded.md 가 폴더면 멈춘다"; else no "[$sh] excluded.md 가 폴더인데 멈추지 않았다 (rc $rc)"; fi
    rmdir "$RD/excluded.md"; : > "$T/elsewhere.md"; ln -s "$T/elsewhere.md" "$RD/excluded.md"
    x_run "$sh" "" '- iter 1 · #1 · a.py · SUGGESTION'
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 99 ]; then ok "[$sh] excluded.md 가 링크면 멈춘다"; else no "[$sh] excluded.md 가 링크인데 멈추지 않았다 (rc $rc)"; fi
    [ ! -s "$T/elsewhere.md" ] && ok "[$sh] 링크 너머에 쓰지 않았다" || no "[$sh] 링크 너머에 썼다"
    rm -f "$RD/excluded.md"
  done
  local tree
  tree=$(awk '/^\*\*P2b — /{f=1} /^\*\*P3 — /{f=0} f' "$SKILL" | fence_with 'review_tree:')
  assert_eq "$(printf '%s\n' "$tree" | tail -n 1)" "printf 'qg-verdict-args: --sha %s\\n' \"\$(git rev-parse --short \"\$(sed -n 's/^end: //p' \"\$RS\")\")\"" \
    "범위 결과 줄: 리뷰 트리 펜스의 마지막 줄이 끝 커밋의 짧은 이름을 낸다"
  local e6
  e6=$(section "$SKILL" '## e2e' | fence_with 'qg-verdict-args: --e2e')
  assert_eq "$e6" "printf 'qg-verdict-args: --e2e %s%s\\n' '<e2e 칸>' '<뒤집음>'" "e2e 결과 줄 펜스(E6)"
  assert_not_contains "$(section "$SKILL" '## e2e')" '%q' "e2e 결과 줄은 printf %q 를 쓰지 않는다"
  out=$(printf '%s\n' "$e6" | sed -e "s/<e2e 칸>/꺼짐(kill switch)/" -e "s/<뒤집음>/ --e2e-overridden/" | bash 2>&1)
  assert_eq "$out" "qg-verdict-args: --e2e 꺼짐(kill switch) --e2e-overridden" "E6 실행: 칸과 뒤집음 표시"
  run_verdict bash final-verdict "QG_ARGS_R=$R_LINE" "QG_ARGS_D=$D_LINE" "QG_ARGS_X=" "QG_ARGS_S=" "QG_ARGS_E=$out" "<N>=1"
  assert_contains "$LINE" ' · e2e 꺼짐(kill switch) (사람이 뒤집음) · ' "E6 이 낸 줄을 최종 판정 펜스가 받는다"
  local e2e
  e2e=$(section "$SKILL" '## e2e')
  assert_eq "$(printf '%s\n' "$e2e" | grep -c '건너뛰고 e2e 칸을 `안 함` 으로 둔 채 E6 만 돈다')" "2" "e2e: 멈추기 · 범위 모드도 걷기 없이 E6 을 돈다"
  assert_contains "$e2e" '걷기를 건너뛰었든(Fix-loop · Max-iter 의 「멈추기」 · 범위 모드 — 칸은 `안 함`)' "E6: 어느 길로 판정에 가든 돈다"
  assert_contains "$e2e" '시나리오가 여럿이면 `${CLAUDE_PLUGIN_ROOT}/references/e2e.md` §6 이 e2e 칸을 정한 걷기를 정하고,' "E6: 여러 시나리오의 「사람이 뒤집음」은 e2e.md §6 이 정한다"
}

case_readme_limits() {
  local lim
  lim=$(section "$README" '## 한계')
  [ -n "$lim" ] && ok "README 에 한계 절이 있다" || no "README 에 한계 절이 없다"
  assert_contains "$lim" 'qg 는 최종 판정 수치를 레포 코드가 돌기 전 또는 만든 직후에 읽어 지킨다. 반복 중간 단계와 레포 코드가 남긴 프로세스의 영향은 막지 않는다. 판정 뒤 게시 단계(게시 여부를 `range-scope.txt` 유무와 result.md 의 `## 게시` 줄로 정한다)도 같다' \
    "README 한계: 설계 §7 의 문장 그대로"
}

for c in case_final_verdict_ignores_tampered_session case_positive_control_slots_are_used case_bad_lines_fail_closed \
         case_forged_line_is_not_expanded case_restore_line_cannot_loosen case_trivia_and_scope_empty_fences \
         case_review_axis_synthesis_precedes_the_differential_test case_differential_line_producers \
         case_excluded_scope_e2e_producers case_readme_limits; do
  echo "== $c"; "$c"
done
finish
