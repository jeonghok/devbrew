#!/usr/bin/env bash
# test_e2e_docs.sh — e2e 의 배선 문면(설계 v10 §4 · §8 · 색인 K-2 · K-8 · X3 · X5 · AC26).
#
# 문면 락은 「있다」만 재면 뒤에 부정을 붙여도 통과한다. 그래서 위치(절 순서) · 고정 문자열 전체 · 옛 문장의 부재를
# 함께 잰다. 부재 단언에는 같은 자리의 양성 짝을 둔다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd -- "$PLUGIN_ROOT/../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
REF="$PLUGIN_ROOT/references/e2e.md"
STATE_FMT="$PLUGIN_ROOT/skills/quality-pipeline/references/state-file-format.md"

line_of() { grep -n -x -F -- "$1" "$2" | head -n 1 | cut -d: -f1; }

section() {   # section <file> <정확한 제목 줄> — 그 제목부터 다음 같은 깊이 제목 앞까지
  awk -v h="$2" '
    $0 == h { on = 1; depth = index(h, " "); print; next }
    on && /^#+ / { d = index($0, " "); if (d <= depth) exit }
    on { print }' "$1"
}

nline_in() {  # nline_in <text> <고정 문자열> — 그 문자열이 처음 나오는 줄 번호(없으면 빈 값)
  printf '%s\n' "$1" | grep -n -F -- "$2" | head -n 1 | cut -d: -f1
}

case_K8_e2e_section_sits_between_fixloop_and_final() {
  local f e v
  f=$(line_of "## Fix-loop" "$SKILL"); e=$(line_of "## e2e" "$SKILL"); v=$(line_of "## Final verdict" "$SKILL")
  if [ -n "$f" ] && [ -n "$e" ] && [ -n "$v" ] && [ "$f" -lt "$e" ] && [ "$e" -lt "$v" ]; then
    ok "K-8: ## e2e 가 ## Fix-loop 와 ## Final verdict 사이에 있다"
  else
    no "K-8: 절 순서가 틀렸다 (Fix-loop=$f e2e=$e Final verdict=$v)"
  fi
}

case_reference_is_read_from_the_e2e_section() {
  local s; s=$(section "$SKILL" "## e2e")
  assert_eq "$(printf '%s\n' "$s" | grep -c -x -F 'Read ${CLAUDE_PLUGIN_ROOT}/references/e2e.md')" "1" \
    "## e2e 절이 references/e2e.md 를 정확히 한 번 Read 한다"
  [ -f "$REF" ] && ok "references/e2e.md 가 있다" || no "references/e2e.md 가 없다"
}

case_X5_boot_is_chained_after_fingerprint() {
  local s; s=$(section "$SKILL" "## e2e")
  assert_contains "$s" '"$QG/scripts/e2e-state.sh" fingerprint --out "$D/e2e-before.txt" && "$QG/scripts/e2e-state.sh" boot --dir "$D"' \
    "X5: 부팅은 지문 뒤에 && 로만 이어진다(kill switch 의 exit 3 이 부팅을 막는다)"
  assert_contains "$s" '"$QG/scripts/e2e-state.sh" fingerprint --out "$D/e2e-gate.txt"; echo "e2e-gate rc=$?"' \
    "AC20: 질문 전에 지문으로 kill switch 를 잰다"
}

case_X4_stop_runs_before_and_after_walk() {
  local s; s=$(section "$SKILL" "## e2e")
  assert_eq "$(printf '%s\n' "$s" | grep -c -F '"$QG/scripts/e2e-state.sh" stop --dir "$D"')" "2" \
    "X4: 걷기 앞(남은 앱) · 뒤(E3) 두 자리에서 stop 을 부른다"
}

case_e2e_fences_guard_the_repo_root() {
  # R-T5e — D 를 정하는 줄은 전부 바로 앞 줄이 rev-parse 실패에 exit 1 하는 TOP 가드다.
  local s nd unguarded
  s=$(section "$SKILL" "## e2e")
  nd=$(printf '%s\n' "$s" | grep -c '^D="\${TOP}/\.claude/quality-gates/<session-id>"$')
  [ "$nd" -ge 4 ] && ok "R-T5e: ## e2e 의 D 는 TOP 에서 정한다 (${nd}곳)" || no "R-T5e: TOP 에서 D 를 정하는 펜스가 모자라다 (${nd}곳)"
  assert_not_contains "$s" 'D="$(git rev-parse --show-toplevel)' "R-T5e: rev-parse 실패를 가드하지 않는 D 대입이 없다"
  unguarded=$(printf '%s\n' "$s" | awk '/^D=/{ if (prev !~ /^TOP="\$\(git rev-parse --show-toplevel\)" \|\| \{ echo .* >&2; exit 1; \}$/) print NR } {prev=$0}')
  assert_eq "$unguarded" "" "R-T5e: ## e2e 의 모든 D 대입 바로 앞 줄이 TOP 가드다"
}

case_walk_records_are_staged_not_appended_to_result() {
  # R-T5c · K-2 — 걷기 중에는 result.md 에 덧붙이지 않는다. 기록은 세션 폴더의 두 파일에 쌓고 Final verdict 가 옮긴다.
  local s; s=$(section "$SKILL" "## e2e")
  assert_contains "$s" '>> "$D/e2e-record.md"' "R-T5c: 걷기 기록은 e2e-record.md 에 쌓는다"
  assert_contains "$s" '>> "$D/e2e-flip.md"' "R-T5c: 뒤집기 줄은 e2e-flip.md 에 쌓는다"
  assert_not_contains "$s" 'result.md"' "R-T5c: ## e2e 절의 펜스가 result.md 를 건드리지 않는다"
}

case_final_verdict_goes_through_verdict_py_with_e2e() {
  local s; s=$(section "$SKILL" "## Final verdict")
  assert_contains "$s" 'python3 "$QG/scripts/verdict.py" --prior "$SYN" --line ' "K-3 · K-7: 최종 판정은 ② 의 \$SYN 을 --prior 로 잇는다"
  assert_contains "$s" 'SYN="<마지막 iteration 의 RV>/synth.out"' "K-7: --prior 파일은 ② 의 \$RV/synth.out 이다"
  assert_contains "$s" "--e2e '<e2e 칸>'" "K-3: 최종 판정 호출이 e2e 칸을 싣는다"
  assert_contains "$s" "--e2e '안 함'" "trivia 판정 줄의 e2e 칸은 안 함"
  # R24 — 판정 줄 숫자는 셸이 기계 출력에서 뽑는다. 차등 새 실패의 `K=` 줄은 ⑤ 가 자기 규칙으로 바꾸는 자리라
  # 그 글자를 여기서 핀하지 않는다 — 셸 변수에서 온다는 것만 잰다.
  assert_contains "$s" 'N_BLOCK=$(sed -n '"'"'s/^blocking: //p'"'"' "$SYN"); N_OPT=$(sed -n '"'"'s/^optional: //p'"'"' "$SYN")' "R24: 막는 지적 · 선택은 \$SYN 에서 뽑는다"
  assert_grep "$s" '^K=' "R24: 차등 새 실패는 셸이 대입한다(K= 줄)"
  assert_contains "$s" '--blocking "$N_BLOCK" --optional "$N_OPT" --new-failures "$K" --excluded "$X"' "R24: 판정 줄 숫자 넷이 셸 변수에서 온다(결측을 0 으로 채우지 않는다)"
  assert_not_grep "$s" '--(blocking|optional|new-failures|excluded) <' "R24: 숫자를 모델이 채우는 자리표시가 없다"
  assert_not_contains "$s" 'ARGS+=(--defect)' "--prior 와 앞 판정 재주입(--defect · --reason)을 함께 두지 않는다"
  # ② 의 I3 — 합성 출력이 없거나 키가 겹치면 판정 줄을 만들지 않는다. --prior 가 verdict 줄만 다시 재므로 이 가드가 남아야 한다.
  assert_contains "$s" '[ -s "$SYN" ] || {' "I3: 합성 출력이 없거나 비면 멈추는 가드가 남았다"
  assert_contains "$s" 'for k in verdict blocking optional; do' "I3: verdict · blocking · optional 줄이 정확히 한 번인지 재는 고리가 남았다"
}

case_K2_result_records_e2e_after_differential() {
  # K-2 — result.md 절 순서: … ## 차등 테스트 · ## e2e · ## 뒤집기 · ## 게시. 기록 펜스가 그 순서로 옮긴다.
  local s p d e f
  s=$(section "$SKILL" "## Final verdict")
  assert_contains "$s" 'cat "$RD/e2e-record.md"' "K-2: 기록 펜스가 걷기 기록을 result.md 로 옮긴다"
  assert_contains "$s" 'cat "$RD/e2e-flip.md"' "K-2: 기록 펜스가 뒤집기 줄을 result.md 로 옮긴다"
  p=$(nline_in "$s" "printf '\\n## 판정\\n\\n'")
  d=$(nline_in "$s" "printf '\\n## 차등 테스트\\n\\n'")
  e=$(nline_in "$s" "printf '\\n## e2e\\n\\n'")
  f=$(nline_in "$s" "printf '\\n## 뒤집기\\n\\n'")
  if [ -n "$p" ] && [ -n "$d" ] && [ -n "$e" ] && [ -n "$f" ] && [ "$p" -lt "$d" ] && [ "$d" -lt "$e" ] && [ "$e" -lt "$f" ]; then
    ok "K-2: 기록 펜스가 ## 판정 · ## 차등 테스트 · ## e2e · ## 뒤집기 순서로 쓴다"
  else
    no "K-2: 기록 펜스의 절 순서가 틀렸다 (판정=$p 차등=$d e2e=$e 뒤집기=$f)"
  fi
  local fmt_d fmt_e fmt_f fmt_g
  fmt_d=$(line_of "## 차등 테스트" "$STATE_FMT"); fmt_e=$(line_of "## e2e" "$STATE_FMT")
  fmt_f=$(line_of "## 뒤집기" "$STATE_FMT"); fmt_g=$(line_of "## 게시" "$STATE_FMT")
  if [ -n "$fmt_d" ] && [ -n "$fmt_e" ] && [ -n "$fmt_f" ] && [ -n "$fmt_g" ] \
     && [ "$fmt_d" -lt "$fmt_e" ] && [ "$fmt_e" -lt "$fmt_f" ] && [ "$fmt_f" -lt "$fmt_g" ]; then
    ok "K-2: state-file-format 의 형식이 ## 차등 테스트 · ## e2e · ## 뒤집기 · ## 게시 순서다"
  else
    no "K-2: state-file-format 의 절 순서가 틀렸다 (차등=$fmt_d e2e=$fmt_e 뒤집기=$fmt_f 게시=$fmt_g)"
  fi
}

case_preflight_clears_walk_files_but_keeps_the_pgid() {
  # 실행 단위 e2e 파일은 P2 가 지운다. 앞 실행이 남긴 앱의 pgid 파일은 지우지 않는다 — E0 의 stop 이 그것으로 앱을 내린다(X4).
  local rm_line f
  rm_line=$(awk '/^\*\*P2 — setup\.\*\*/{w=1} /^\*\*P3 /{w=0} w && /^rm -f /' "$SKILL")
  for f in e2e-record.md e2e-flip.md e2e-evidence.tsv e2e-cmd.txt e2e-gate.txt e2e-before.txt e2e-after.txt; do
    assert_contains "$rm_line" "\"\$RD/$f\"" "P2 가 실행 단위 파일 $f 를 지운다"
  done
  assert_not_contains "$rm_line" 'e2e-app.pgid' "X4: P2 가 남은 앱의 pgid 파일을 지우지 않는다"
}

case_kill_switch_index_names_both() {
  local s; s=$(section "$SKILL" "## kill switch")
  assert_contains "$s" 'DEVBREW_QUALITY_GATES_DISABLE_E2E=1' "kill switch 색인에 DISABLE_E2E 가 있다"
  assert_grep "$s" 'DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1.*e2e' "kill switch 색인의 DISABLE_DIFFERENTIAL_TEST 줄이 e2e 를 말한다"
  assert_eq "$(printf '%s\n' "$s" | grep -c '^- `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1`')" "1" \
    "kill switch 색인에 DISABLE_DIFFERENTIAL_TEST 항목은 하나다(제자리 확장)"
}

case_X3_local_origin_rule() {
  assert_file_grep "$REF" '^- 승인된 명령이 띄운 `127\.0\.0\.1` · `localhost` origin 만 연다\.' "X3: 로컬 origin 규칙"
  assert_file_grep "$REF" '^- 파일 업로드 · 다운로드 저장 · 외부 계정 로그인 · 결제는 하지 않는다\.$' "X3: 업로드 금지 규칙"
}

for c in $(declare -F | awk '{print $3}' | grep '^case_'); do
  note "── $c"
  "$c"
done
finish
