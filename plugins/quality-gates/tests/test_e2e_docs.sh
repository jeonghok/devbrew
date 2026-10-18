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

case_I1_cli_direct_walk_is_gated_by_the_fingerprint_rc() {
  # CLI 직접 실행은 걷기 자체가 리뷰 대상 코드의 실행이다 — 지문 rc 가 그 앞의 코드 게이트다(X5).
  local s; s=$(section "$SKILL" "## e2e")
  assert_eq "$(printf '%s\n' "$s" | grep -cxF -- '"$QG/scripts/e2e-state.sh" fingerprint --out "$D/e2e-before.txt"; echo "before rc=$?"')" "1" \
    "I1: CLI 직접 실행 경로가 지문을 재고 그 rc 를 낸다"
  assert_eq "$(printf '%s\n' "$s" | grep -cxF -- '- `before rc=0` — E2 로 간다.')" "1" "I1: 걷기는 before rc=0 에서만 간다"
  assert_eq "$(printf '%s\n' "$s" | grep -cxF -- '- `before rc=3` — kill switch 다. CLI 명령을 하나도 실행하지 않고 e2e 칸을 `꺼짐(kill switch)` 로 두고 `## Final verdict` 로 간다.')" "1" \
    "I1: before rc=3 이면 CLI 명령을 실행하지 않고 꺼짐(kill switch)"
  assert_eq "$(printf '%s\n' "$s" | grep -cxF -- '- `before rc` 가 그 밖의 0 아닌 값 — 걷지 않는다. stderr 사유를 공시하고 판정안 `미확인(지문 실패)` 로 E3 를 건너뛰고 E4 로 간다.')" "1" \
    "I1: 그 밖의 rc 면 걷지 않고 미확인(지문 실패)"
  assert_not_contains "$s" '만 돌리고 E2 로 간다' "I1: rc 를 보지 않고 E2 로 가는 옛 문장이 없다"
}

case_I1_each_walk_starts_without_the_previous_walks_files() {
  # 같은 실행의 두 번째 걷기(다시 걷기 · 리뷰·테스트부터 다시 · Retry)가 앞 걷기의 증거표로 판정안을 내지 않는다.
  # 지문을 재는 E1 펜스(부팅 · CLI 직접 실행) 각각에서 지우는 줄이 지문 줄보다 앞이다.
  local s res
  s=$(section "$SKILL" "## e2e")
  res=$(printf '%s\n' "$s" | awk '
    /^```bash$/ { inf = 1; rm = 0; fp = 0; n = 0; next }
    inf && /^```$/ { inf = 0; if (fp) { total++; if (rm && rm < fp) good++ } next }
    inf { n++
          if ($0 == "rm -f \"$D/e2e-evidence.tsv\" \"$D/e2e-after.txt\" \"$D/e2e-before.txt\"") rm = n
          if (index($0, "\"$QG/scripts/e2e-state.sh\" fingerprint --out \"$D/e2e-before.txt\"") == 1 && !fp) fp = n }
    END { printf "%d/%d\n", good, total }')
  assert_eq "$res" "2/2" "I1: E1 펜스 둘 다 지문 앞에서 앞 걷기의 증거표 · 지문 파일을 지운다"
  assert_not_grep "$s" '^rm -f .*e2e-(app\.pgid|record\.md|flip\.md)' "I1: 걷기 펜스가 pgid · 기록 · 뒤집기 파일은 지우지 않는다"
}

case_I2_cli_direct_approval_lists_the_command_lines() {
  assert_eq "$(grep -cxF -- '- CLI 직접 실행 시나리오의 `description` 은 부팅 명령 자리에 실행할 CLI 명령 줄을 전부 글자 그대로 담는다. 고르면 그 줄들만 실행을 승인한다.' "$REF")" "1" \
    "I2: CLI 직접 실행 시나리오의 질문이 실행할 명령 줄을 보이고, 고르면 그 줄들만 승인한다(줄 전체)"
  local s; s=$(section "$SKILL" "## e2e")
  assert_contains "$s" '승인된 CLI 명령 줄만 글자 그대로 실행한다. 그 밖에 리뷰 대상 코드를 실행하는 명령은 돌리지 않는다.' \
    "I2: SKILL 의 CLI 직접 실행 경로는 승인된 줄만 실행한다"
}

case_M3_M5_M8_e1_e4_wording() {
  local s; s=$(section "$SKILL" "## e2e")
  assert_contains "$s" '- 두 줄이 없고 `boot rc=5` — 부팅이 실패한 뒤 boot 자신의 정리(stop)도 실패했다.' "M3: boot rc=5 갈래가 있다"
  assert_contains "$s" '남은 앱은 사람이 직접 내려야 한다고 알린다(기록 `e2e-app.pgid` 는 남는다).' "M3: rc=5 는 남은 앱을 사람에게 알린다"
  assert_contains "$s" '호출의 timeout 은 부팅 상한보다 길게 준다: 기본이면 150000 ms, `DEVBREW_QUALITY_GATES_E2E_BOOT_TIMEOUT` 이 있으면' "M5: E1 의 Bash 호출 timeout 이 부팅 상한보다 길다"
  assert_contains "$s" '- **다시 걷기** — iteration 을 쓰지 않는다. 시나리오가 쓴 E1 펜스(부팅 펜스, CLI 직접 실행이면 E1 (CLI 직접 실행) 펜스)부터' \
    "M8: 다시 걷기가 CLI 직접 실행 펜스도 이름으로 가리킨다"
}

case_M9_preflight_stops_a_leftover_app_before_clearing() {
  local p st rm
  p=$(awk '/^\*\*P2 — setup\.\*\*/{w=1} /^\*\*P3 /{w=0} w' "$SKILL")
  st=$(printf '%s\n' "$p" | grep -nxF -- 'bash "$QG/scripts/e2e-state.sh" stop --dir "$RD"; echo "preflight-stop rc=$?"' | head -n 1 | cut -d: -f1)
  rm=$(nline_in "$p" 'rm -f "$RD/excluded.md"')
  if [ -n "$st" ] && [ -n "$rm" ] && [ "$st" -lt "$rm" ]; then ok "M9: P2 가 지우기 전에 남은 앱을 내린다(rc 는 막지 않는다)"; else no "M9: P2 의 stop 줄 위치 (stop=$st rm=$rm)"; fi
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
  assert_eq "$(printf '%s\n' "$s" | grep -cxF -- '- `DEVBREW_QUALITY_GATES_DISABLE_E2E=1` — e2e 만 끈다. `## e2e` E0 의 지문이 exit 3 으로 끝나 질문이 뜨지 않고, e2e 칸이 `꺼짐(kill switch)` 이다. 집행은 `e2e-state.sh` 다.')" "1" \
    "kill switch 색인의 DISABLE_E2E 항목이 줄 전체 그대로다(뒤에 덧붙인 말이 없다)"
  assert_grep "$s" 'DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1.*e2e' "kill switch 색인의 DISABLE_DIFFERENTIAL_TEST 줄이 e2e 를 말한다"
  assert_eq "$(printf '%s\n' "$s" | grep -c '^- `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1`')" "1" \
    "kill switch 색인에 DISABLE_DIFFERENTIAL_TEST 항목은 하나다(제자리 확장)"
}

case_reconstructed_skill_keeps_the_e2e_window_whole() {
  # 재구성 헬퍼(tests/lib/reconstruct-skill.sh)가 e2e.md 를 되접어도 `## e2e` 창은 다음 `## ` 앞까지 E0~E5 를 품는다.
  . "$PLUGIN_ROOT/tests/lib/reconstruct-skill.sh"
  local out w e
  if ! out="$(reconstruct_skill_md "$SKILL")"; then no "재구성 헬퍼가 실패했다"; return; fi
  w=$(awk '/^## e2e$/{f=1; print; next} f && /^## /{exit} f' "$out")
  assert_eq "$(grep -cx '# e2e — 걷기 절차' "$out")" "0" "재구성본에 e2e.md 의 # 제목이 없다"
  assert_eq "$(printf '%s\n' "$w" | grep -cx '### 1. 시나리오 만들기')" "1" "e2e.md 본문이 ## e2e 창 안에 ### 로 내려 들어갔다"
  for e in E0 E1 E2 E3 E4 E5; do
    printf '%s\n' "$w" | grep -q "^\*\*${e} " && ok "재구성본의 ## e2e 창에 ${e} 가 있다" || no "재구성본의 ## e2e 창에 ${e} 가 없다"
  done
  rm -f "$out"
}

case_X3_local_origin_rule() {
  assert_file_grep "$REF" '^- 승인된 명령이 띄운 `127\.0\.0\.1` · `localhost` origin 만 연다\.$' "X3: 로컬 origin 규칙(줄 끝까지)"
  assert_file_grep "$REF" '^- 파일 업로드 · 다운로드 저장 · 외부 계정 로그인 · 결제는 하지 않는다\.$' "X3: 업로드 금지 규칙"
}

PHIL="$ROOT/docs/philosophy/devbrew-harness-philosophy.md"
README="$PLUGIN_ROOT/README.md"

case_AC26_P4_sentence_replaced() {
  local s; s=$(section "$PHIL" "### P4 — Verification Is Infrastructure")
  assert_grep "$s" 'qg 는 runtime tier 를 사람이 승인하면 e2e 걷기로 확인한다 — 걷지 않은 실행은 판정 줄의 e2e 칸이 그 사실을 보인다\(오케스트레이터의 판정은 판정안이고 reviewer 는 감독하는 사람이다 — Law 2 해석\)\.$' \
    "AC26: P4 의 새 문장이 문단 끝에 통째로 있다"
  assert_not_contains "$s" 'e2e 걷기로 집행한다' "AC26: P4 의 「집행한다」 문장이 없다"
  assert_not_contains "$s" 'runtime tier 를 주장하지 않는다' "AC26: P4 의 옛 문장이 없다"
  assert_not_contains "$s" 'runtime tier 의 집행 코드가 없다' "AC26: P4 의 옛 문장 앞절도 없다"
  assert_grep "$s" '^코드\(mechanical · semantic · runtime\): .*`plugins/quality-gates/references/e2e\.md`$' \
    "AC26: P4 코드 앵커가 references/e2e.md 를 인용한다"
}

case_readme_documents_the_switches() {
  assert_file_grep "$README" '^\| `DEVBREW_QUALITY_GATES_DISABLE_E2E=1` \| .*\(지문 · 비교 · 부팅이 exit 3\)\. \|$' "README 표에 DISABLE_E2E 줄이 있다"
  assert_file_grep "$README" '^\| `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` \|.*e2e 부팅' \
    "README 의 DISABLE_DIFFERENTIAL_TEST 줄이 e2e 부팅도 막는다고 말한다"
  assert_file_grep "$README" '^- `DEVBREW_QUALITY_GATES_E2E_BOOT_TIMEOUT`: 90 \(' "README 에 부팅 상한 노브가 기본값 90 으로 있다"
}

case_readme_describes_the_e2e_stage() {
  local flow; flow=$(section "$README" "## 파이프라인 흐름 (single-turn)")
  assert_grep "$flow" '^ ├ e2e ' "README 흐름도에 e2e 줄이 있다"
  local a b
  a=$(nline_in "$flow" ' ├ e2e '); b=$(nline_in "$flow" ' ├ Final verdict')
  if [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]; then ok "README 흐름도: e2e 가 Final verdict 앞이다"; else no "README 흐름도: e2e 위치 (e2e=$a final=$b)"; fi
  assert_file_grep "$README" '^\| ④ e2e \|' "README 파이프라인 표에 e2e 행이 있다"
  assert_file_grep "$README" '^- \*\*e2e\*\*' "README 사전 요건에 e2e 줄이 있다"
}

case_readme_states_the_e2e_limits() {
  assert_file_grep "$README" '^- e2e `stop` 은 승인된 명령이 띄운 프로세스 그룹을 내린다\. .*고르지 않는다\.$' "README: 데몬 · 남은 앱 한계 줄(독립 bullet)"
  assert_file_grep "$README" '^- e2e 남은 앱: .*남을 수 있다\.$' "README: 남은 앱 고아 한계"
  assert_file_grep "$README" '^- e2e 남은 앱: .*다른 세션의 `/qg` 는 앞 세션의 폴더를 보지 않으므로' "M4: 다른 세션의 /qg 는 남은 앱을 내리지 않는다"
  assert_file_grep "$README" '^- e2e 남은 앱: .*내리지 못하면 사유를 출력한 뒤 pgid 기록이 든 폴더를 지우므로' "M4: setup 백스톱이 stop 실패 뒤 기록을 지운다"
  assert_file_absent "$README" '`--ensure` 경로로 들어오면' "M4: 옛 「--ensure 경로」 고아 문장이 없다(P2 가 내린다)"
  assert_file_grep "$README" '^- e2e 증거 판독: .*`—` · `none` 같은 글자는 증거로 읽혀 `충족` 이 그대로 남는다\.$' "M4: 닫힌 증거 없음 목록"
  assert_file_grep "$README" '^- e2e `stop` 과 다른 사용자의 프로세스: .*`stop-failed` 로 끝난다\.$' "M4: 다른 사용자 프로세스가 섞인 그룹"
  assert_file_grep "$README" '^- e2e 부팅 정리 실패: .*exit 5 로 끝나고 앱이 남을 수 있다 — 그 앱은 사람이 직접 내려야 한다\.$' "M4: boot exit 5"
  assert_file_grep "$README" '^- e2e `stop` 의 생존 판정: .*갈 수 있다\.$' "README: stop 의 ps 생존 판정 한계"
  assert_file_grep "$README" '^- e2e 포트 확인: .*`::1` 에만 묶이는 서버.*`--host 127\.0\.0\.1` 같은 인자를 쓴다\.$' "README: IPv6 한계(::1 전용 서버 포함)"
  assert_file_grep "$README" '^- e2e CLI 직접 걷기: .*아니다\.$' "README: CLI 직접 걷기 한계"
  assert_file_grep "$README" '^- e2e 지문: .*않는다\.$' "README: 지문 한계"
}

case_readme_security_paragraph_and_principle() {
  assert_file_grep "$README" '^명령을 호스트 권한으로 실행한다 — 시나리오를 고르는 것이 그 실행의 승인이고' "README 보안 문단: e2e 승인 문장"
  assert_file_grep "$README" '^코드가 아니라 오케스트레이터가 읽는 지문 rc 다\)\. 선언 경로의$' "I2: README 보안 문단이 CLI 직접 걷기의 게이트는 지문 rc 라고 말한다"
  assert_file_grep "$README" '^- \*\*P4 — runtime tier 는 사람이 승인하는 e2e 걷기.*tests/test_e2e_docs\.sh`\.$' "README 인스턴스화한 원칙에 P4 줄"
  assert_file_grep "$README" '^- \*\*P4 — .*runtime tier 는 사람이 승인하면 e2e 걷기로 확인한다 — 걷지 않은 실행은 판정 줄의 e2e 칸이 그 사실을 보인다\. 걷는 동안 .*tests/test_e2e_docs\.sh`\.$' "README P4 줄: 확인한다 문장이 줄 안에 통째로 있다"
  assert_file_absent "$README" 'e2e 걷기로 집행한다' "README: 옛 「집행한다」 문장이 없다"
  assert_file_absent "$README" '주장을 거둔다' "README: 옛 「주장을 거둔다」 문장이 없다"
  assert_file_absent "$README" '주장만 거뒀다' "README: 옛 「주장만 거뒀다」 문장이 없다"
  assert_file_grep "$README" '부팅되는 앱의 런타임 행위는 e2e 걷기가 본다\(아래 P4 줄\)\.$' "README: LD3 의 새 문장이 줄 끝에 있다"
  assert_file_grep "$README" '^- \*\*e2e\*\* — `curl`\(API 시나리오를 걸을 때' "README 사전 요건: curl 은 API 시나리오용"
}

case_readme_has_disable_e2e_line() {
  assert_file_grep "$README" '`DEVBREW_QUALITY_GATES_DISABLE_E2E=1` 은 e2e 를 끈다\(판정 줄의 e2e 칸이 `꺼짐\(kill switch\)`\)' "README 범위 절에 DISABLE_E2E 줄이 있다"
}

for c in $(declare -F | awk '{print $3}' | grep '^case_'); do
  note "── $c"
  "$c"
done
finish
