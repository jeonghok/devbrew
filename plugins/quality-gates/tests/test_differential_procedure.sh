#!/usr/bin/env bash
# test_differential_procedure.sh — 차등 테스트 절차 문서와 파이프라인 SKILL 의 판정 입력 배선.
# 요구: R6 · R18 · R22 · R24 (docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md §요구 목록)
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REF="$PLUGIN_ROOT/skills/quality-pipeline/references/differential-test.md"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
VERDICT="$PLUGIN_ROOT/scripts/verdict.py"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

has_line() { grep -qxF -- "$2" "$1"; }
section() { awk -v h="$2" '$0 == h {on=1; next} on && /^## /{exit} on' "$1"; }

# R18 — 짝짓기가 실패하면 error-axis 다. 표의 행이 그 대응을 싣고, verdict.py 가 그 사유를 not-certified 로 낸다.
case_R18_failed_pairing_routes_to_error_axis() {
  has_line "$REF" '| `diff_rc` 가 0 이 아니다 · 파일이 없다 · D5 전에 절차가 끝났다(D0 메모 실패 · D2 exit 4 포함) | `--reason error-axis` (R18) |' \
    && ok "R18: 판정 입력 표에 error-axis 행" || no "R18: 판정 입력 표에 error-axis 행이 없다"
  local out; out=$(python3 "$VERDICT" --reason error-axis)
  assert_eq "$(printf '%s\n' "$out" | sed -n '1,2p' | tr '\n' ' ')" "verdict: not-certified reason: error-axis " \
    "R18: --reason error-axis → not-certified (error-axis)"
}
# R22 — 오케스트레이터 쪽 kill switch: 절차 전체를 건너뛰고 kill-switch 사유를 싣는다.
case_R22_orchestrator_honors_kill_switch() {
  has_line "$REF" '| D0 의 kill switch | `--reason kill-switch` |' \
    && ok "R22: 판정 입력 표에 kill-switch 행" || no "R22: kill-switch 행이 없다"
  grep -qF '`DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` 이면 이 절차 전체를 건너뛰고' "$REF" \
    && ok "R22: D0 이 스위치를 먼저 본다" || no "R22: D0 에 스위치 확인이 없다"
}
# R24 — 판정은 D5 산출 파일을 그대로 읽는다. 원장 전사 경로가 없다.
case_R24_verdict_reads_the_machine_output() {
  has_line "$REF" '| `diff_rc=0` 이고 `$RD/differential.yaml` 이 있다 | `--differential "$RD/differential.yaml"` |' \
    && ok "R24: 판정 입력은 D5 가 남긴 세션 폴더 사본이다" || no "R24: 판정 입력 행이 없다"
  assert_eq "$(grep -c '<memo>' "$SKILL")" "0" "R24 · K-3: SKILL 어디에도 메모 경로 자리표시가 없다(합성기도 사본을 읽는다)"
  local s4; s4=$(awk '/^### Step 4 /{f=1} /^### Step 4\.5/{f=0} f' "$SKILL")
  assert_contains "$s4" '| `--differential "$RD/differential.yaml"` |' "Step 4: 합성기의 차등 입력은 세션 폴더 사본이다"
  assert_contains "$s4" 'RD="${TOP}/.claude/quality-gates/<session-id>"' "Step 4: 합성 펜스가 RD 를 정한다"
  local f n=0
  for f in "$REF" "$SKILL"; do
    grep -qE 'runtime-evidence|check_qa_ledger|floor:verification' "$f" && { n=$((n + 1)); echo "    전사 원장 흔적: $f"; }
  done
  assert_eq "$n" "0" "R24: 절차와 SKILL 에 전사 원장이 없다"
  assert_not_grep "$(cat "$SKILL")" 'aggregate[._]yaml|\(new_regression\|new_test_red\)' \
    "R24: SKILL 은 옛 집계 파일을 읽거나 범주 카운트를 다시 세지 않는다(K 는 new_failures: 에서)"
  grep -qF 'diff-test-results.py' "$REF" && ok "R24 양성 짝: 절차가 diff-test-results.py 를 부른다" || no "R24: 절차가 짝짓기를 부르지 않는다"
}
# R24 · K-3 — 실행 끝의 판정 줄과 기록은 D5 가 세션 폴더에 남긴 사본을 읽는다. SKILL 펜스에 메모 경로 자리표시가 없다.
case_R24_final_verdict_reads_the_session_copy() {
  local d5; d5=$(section "$REF" '## D5 짝짓기 — 매 iteration')
  assert_contains "$d5" 'cp "<memo>/diff-i<N>.yaml" "$RD/differential.yaml"' "D5 가 이 iteration 의 출력을 세션 폴더 사본으로 덮어쓴다"
  assert_contains "$d5" $'else\n  rm -f "$RD/differential.yaml"\nfi' "D5: 출력이 없거나 실패면 사본을 지운다(앞 iteration 값이 남지 않는다)"
  assert_contains "$d5" '|| { diff_rc=4; rm -f "$RD/differential.yaml"; }' "D5: 사본 복사가 실패하면 error-axis 로 가고 반쪽 사본을 지운다"
  assert_contains "$d5" 'cp "<memo>/not-counted-i<N>.md" "$RD/differential-not-counted.md"' "D5 가 커버리지 제외 목록도 사본으로 둔다"
  assert_contains "$(section "$REF" '## D1 HEAD 축 트리 — 매 iteration')" \
    'rm -f "$RD/differential.yaml" "$RD/differential-not-counted.md"' "D1: iteration 시작에 앞 iteration 사본을 지운다"
  assert_contains "$(section "$REF" '## D2 후보와 배정 — 매 iteration')" '"<memo>/not-counted-i<N>.md"' \
    "D2: 커버리지로 세지 않는 목록을 메모 파일에 쓴다"
  local fv; fv=$(section "$SKILL" '## Final verdict')
  assert_contains "$fv" 'DY="$RD/differential.yaml"' "Final verdict: K 는 세션 폴더 사본에서 읽는다"
  assert_contains "$fv" "sed -n 's/^new_failures: //p' \"\$DY\"" "Final verdict: K 는 new_failures: 값이다"
  assert_contains "$fv" 'cat "$RD/differential.yaml"' "기록 펜스: ## 차등 테스트 에 사본을 그대로 붙인다"
  assert_contains "$fv" 'cat "$RD/differential-not-counted.md"' "기록 펜스: 커버리지 제외 목록을 덧붙인다"
  local memo_in_fence
  memo_in_fence=$(awk '/^[ \t]*```bash$/{f=1; next} f && /^[ \t]*```$/{f=0} f && /<memo>/{print NR}' "$SKILL")
  assert_eq "$memo_in_fence" "" "K-3: SKILL 의 bash 펜스에 <memo> 자리표시가 없다"
}
# R6 — 메모 지우기(D8)는 기록 펜스 뒤 · 게시 앞에 명시적으로 있다.
case_R6_memo_drop_after_record_before_publish() {
  local rec d8 pub
  rec=$(grep -n 'differential-not-counted.md"; fi$' "$SKILL" | tail -1 | cut -d: -f1)
  d8=$(grep -n '^Then run D8' "$SKILL" | head -1 | cut -d: -f1)
  pub=$(grep -n '^## Publish$' "$SKILL" | head -1 | cut -d: -f1)
  if [ -n "$rec" ] && [ -n "$d8" ] && [ -n "$pub" ] && [ "$rec" -lt "$d8" ] && [ "$d8" -lt "$pub" ]; then
    ok "R6: D8 이 기록 펜스($rec) 뒤 · Publish($pub) 앞($d8)에 있다"
  else
    no "R6: D8 위치 (기록=$rec D8=$d8 Publish=$pub)"
  fi
  assert_contains "$(section "$REF" '## D8 실행 끝 — 메모 지우기')" '"$QG/scripts/qg-worktree.sh" memo-drop "<memo>"' "D8 이 memo-drop 을 부른다"
}
# SKILL 의 차등 절은 reference 를 읽고, 실행이 끝날 때 메모를 지우라고 말한다.
case_skill_section_wires_the_reference() {
  local sec; sec=$(section "$SKILL" '## Differential test')
  assert_contains "$sec" 'Read ${CLAUDE_PLUGIN_ROOT}/skills/quality-pipeline/references/differential-test.md' "SKILL: reference 를 읽는다"
  assert_contains "$sec" 'D8' "SKILL: 실행 끝 메모 지우기(D8)를 가리킨다"
  assert_contains "$sec" 'new_failures:' "SKILL: 판정 줄의 차등 새 실패는 new_failures: 에서 온다"
  assert_contains "$sec" '`> [quality-gates] 차등 테스트가 DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1 로 꺼져 있다 — 이 실행은 not-certified (kill-switch) 다.`' \
    "SKILL: kill switch 공지 줄이 그대로 남았다(R22 오케스트레이터 쪽 공시)"
  assert_not_grep "$sec" 'probe|usable: no' "SKILL: 지운 probe 하위명령을 말하지 않는다"
}

# 절차는 D0~D8 아홉 단계이고, 지운 단계(옛 R-init~R8 · 갭 게이트)가 남지 않았다.
case_reference_steps_are_d0_to_d8() {
  local got; got=$(grep -oE '^## D[0-9]+ ' "$REF" | tr -d '# ' | tr '\n' ' ')
  assert_eq "$got" "D0 D1 D2 D3 D4 D5 D6 D7 D8 " "절차 단계 D0~D8 이 순서대로 하나씩"
  assert_eq "$(grep -c '§' "$REF")" "0" "모델이 매 iteration 읽는 절차는 설계 문서의 절(§)을 가리키지 않는다 — 지킬 규칙은 절차 안에 있다"
  assert_not_grep "$(cat "$REF")" '^\*\*Step R|갭 게이트|baseline-cache|test-scope-validator' "옛 단계 · 지운 장치가 절차에 없다"
  assert_contains "$(cat "$REF")" '이 호출 결과가 authoritative 다' "호출 주체 불변식: 스크립트 호출 결과가 판정 입력의 유일한 출처다"
}
# 토픽 스코프 경로: 기준선은 경계, HEAD 축은 합친 커밋, 후보와 분모는 그 트리에서 센다.
# 토픽 값(head_commit · tree)은 매 iteration 의 topic-scope.txt 에서 읽는다 — Retry 뒤 Step 1a 가 새로 쓴 값이다.
case_topic_path_wiring() {
  local d0 d1
  d0=$(section "$REF" '## D0 실행 시작 — 첫 iteration 에서 한 번'); d1=$(section "$REF" '## D1 HEAD 축 트리 — 매 iteration')
  assert_contains "$d1" 'S="$RD/topic-scope.txt"' "토픽: D1 이 이 iteration 의 스코프 파일을 읽는다"
  assert_contains "$d1" "hc=\$(sed -n 's/^head_commit: //p' \"\$S\")" "토픽: HEAD 축 커밋은 이 iteration 파일의 head_commit: 이다"
  assert_contains "$d1" 'create-head "$hc" "<session-id>" --topic "$key"' "토픽: HEAD 축 트리는 --topic 으로 다시 도출해 대조한다"
  assert_not_grep "$d0" 'create-head|head_commit' "토픽: D0(한 번)은 HEAD 축 값을 정하지 않는다"
  assert_contains "$d0" '기준선 커밋은 실행마다 하나로 고정된다' "기준선 고정과 그 공시가 D0 에 있다"
  assert_contains "$(cat "$REF")" '토픽 · 범위 스코프면 `--topic <boundary> <tree>` 를 붙인다' "토픽: 후보는 경계..트리"
  assert_contains "$(cat "$REF")" '(토픽 · 범위 스코프면 `--total --tree <tree>`' "토픽: 분모도 그 트리에서"
}

# D1 펜스를 실제로 돌린다 — 플러그인 루트는 호출을 기록하는 대역이다.
d1_fence() { awk '$0 == "## D1 HEAD 축 트리 — 매 iteration" {on=1; next} on && /^## /{exit} on && /^```bash$/{f=1; next} f && /^```$/{exit} f' "$REF"; }
case_topic_axis_is_read_every_iteration() {
  local T; T=$(mktemp -d) && [ -d "$T" ] || { no "mktemp 실패"; return; }
  git init -q "$T/r" && git -C "$T/r" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  local SID=sidd1run01 RDX="$T/r/.claude/quality-gates/sidd1run01"; mkdir -p "$RDX" "$T/stub/scripts"
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "$STUB_LOG"\n[ -n "${STUB_FAIL:-}" ] && exit 2\necho /stub/head-tree\n' > "$T/stub/scripts/qg-worktree.sh"
  printf '#!/bin/sh\necho SEALED\n' > "$T/stub/scripts/seal-worktree.sh"
  chmod +x "$T/stub/scripts/qg-worktree.sh" "$T/stub/scripts/seal-worktree.sh"
  local F; F=$(d1_fence)
  [ -n "$F" ] && ok "D1 펜스를 뽑았다" || { no "D1 펜스가 없다"; rm -rf "$T"; return; }
  run_d1() {   # run_d1 <scope0> <base0> [STUB_FAIL]
    printf '%s\n' "$F" | sed "s/<session-id>/$SID/g; s/<D0 의 스코프: topic | session | range>/$1/g; s/<D0 의 기준선 커밋>/$2/g" > "$T/d1.sh"
    ( cd "$T/r" && CLAUDE_PLUGIN_ROOT="$T/stub" STUB_LOG="$T/log" STUB_FAIL="${3:-}" bash "$T/d1.sh" 2>/dev/null )
  }
  ts() { printf 'topic_key: k1\nstatus: ok\nboundary: %s\ntree: %s\nhead_commit: %s\n' "$1" "$3" "$2" > "$RDX/topic-scope.txt"; }
  local out n
  : > "$T/log"
  ts B1 H1 T1; out=$(run_d1 topic B1)
  assert_grep "$out" '^head_commit=H1$' "iteration 1: HEAD 축은 그 iteration 파일의 head_commit"
  assert_eq "$(tail -1 "$T/log")" "create-head H1 $SID --topic k1" "iteration 1: create-head --topic 에 그 값"
  ts B1 H2 T2; out=$(run_d1 topic B1)
  assert_grep "$out" '^head_commit=H2$' "R11: Retry 뒤 iteration 2 는 새로 쓴 head_commit 을 쓴다(첫 iteration 값이 아니다)"
  assert_grep "$out" '^tree=T2$' "Retry 뒤 iteration 2 의 후보 · 분모 트리도 새 값이다"
  assert_eq "$(tail -1 "$T/log")" "create-head H2 $SID --topic k1" "iteration 2: create-head 가 새 head_commit 을 받는다"
  out=$(run_d1 topic B1 1)
  assert_grep "$out" '^head_commit=-$' "트리를 못 만들면 HEAD 커밋은 - 다(찍어 둔 sha 를 넘기지 않는다)"
  assert_grep "$out" '^head_tree=$' "트리를 못 만들면 head_tree 는 비었다"
  n=$(wc -l < "$T/log")
  ts B2 H3 T3; out=$(run_d1 topic B1)
  assert_grep "$out" '^axis=mismatch$' "경계가 실행 시작과 다르면 이 iteration 은 축 불일치(error-axis)"
  rm -f "$RDX/topic-scope.txt"; out=$(run_d1 topic B1)
  assert_grep "$out" '^axis=mismatch$' "topic → session 으로 바뀌면 축 불일치"
  assert_eq "$(wc -l < "$T/log")" "$n" "축 불일치면 트리를 만들지 않는다"
  out=$(run_d1 session M1)
  assert_grep "$out" '^head_commit=SEALED$' "session: 봉인한 커밋이 HEAD 축이다"
  assert_eq "$(tail -1 "$T/log")" "create-head SEALED $SID" "session: create-head 는 --topic 없이 봉인 커밋을 받는다"
  ts M1 H4 T4; out=$(run_d1 session M1)
  assert_grep "$out" '^axis=mismatch$' "session → topic 으로 바뀌면 축 불일치"
  echo stale > "$RDX/differential.yaml"; echo stale > "$RDX/differential-not-counted.md"; run_d1 session M1 >/dev/null
  [ ! -e "$RDX/differential.yaml" ] && [ ! -e "$RDX/differential-not-counted.md" ] \
    && ok "D1 은 축 불일치여도 앞 iteration 사본을 먼저 지운다" || no "D1 이 앞 iteration 사본을 남겼다"
  rm -rf "$T"
}

for c in case_R18_failed_pairing_routes_to_error_axis case_R22_orchestrator_honors_kill_switch \
         case_R24_verdict_reads_the_machine_output case_R24_final_verdict_reads_the_session_copy \
         case_R6_memo_drop_after_record_before_publish case_skill_section_wires_the_reference \
         case_reference_steps_are_d0_to_d8 case_topic_path_wiring case_topic_axis_is_read_every_iteration; do
  echo "== $c"; $c
done
finish
