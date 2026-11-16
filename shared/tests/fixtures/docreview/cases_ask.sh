# docreview 질문 재료 케이스 — 짧은 경고 줄과 상태 줄. 행동 락(test_docreview_ask.sh)이 쓴다.
# 계약: cases.sh 를 먼저 source 한다(헬퍼 route_r1 · r1 · gfirst · critic_dead_twice · $FX · $PROF_SD · $SCRIPTS).
#       각 case_* 는 자기 임시 디렉토리를 만들고 끝에 지운다. 관측은 assert_* 로만 낸다.

status_of() { PYTHONPATH="$SCRIPTS" python3 -c 'import sys, docreview_state as S
st = S.load_state(sys.argv[1]); print(S.status_line(S.gate_summary(st)))' "$1"; }

case_ask_short_warn_line_unit() {
  local got; got="$(PYTHONPATH="$SCRIPTS" python3 -c '
from docreview_ask import short_warn_line
print(short_warn_line([("codex 리뷰 없음", "a"), (None, "b"), ("보류한 지적", "c"), ("보류한 지적", "d"), (None, "e")]))
print(repr(short_warn_line([])))')"
  assert_eq "$got" "리뷰 경고 5개: codex 리뷰 없음 · 보류한 지적 ×2 · 그 밖 2개
''" "짧은 경고 줄: 처음 나온 순서 · 같은 이름은 ×k · 표에 없는 것은 그 밖 N개 · 없으면 빈 글"
}
case_ask_status_count_equals_first_line() {   # AC6 — 같은 목록에서 센다
  local d f s; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-nolayer2.txt" "$FX/codex-failed.yaml" --skip)" \
    || { no "상태 줄: route_r1 실패"; return; }
  f="$(gfirst "$d")"; s="$(status_of "$d")"
  assert_contains "$f" "경고 3개: " "상태 줄 전제: 게이트 첫 줄의 경고는 셋이다"
  assert_eq "${s%%:*}" "리뷰 경고 3개" "상태 줄: 개수가 게이트 첫 줄과 같고 머리에 채널 이름이 있다"
  for n in 'codex 리뷰 없음' '재비판 없음' '세부 검토 없음'; do assert_contains "$s" "$n" "상태 줄: 짧은 이름 「${n}」"; done
  assert_not_contains "$s" "다른 모델의 시각" "상태 줄: 긴 쉬운 문장은 싣지 않는다"
  rm -rf "$d"
}
case_ask_status_no_warns() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "상태 줄: route_r1 실패"; return; }
  assert_eq "$(status_of "$d")" "경고 없음" "상태 줄: 경고는 없고 남은 것이 있으면 「경고 없음」"
  rm -rf "$d"
}
case_ask_status_nothing_left() {   # case_plain_render_nothing_left 와 같은 준비
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-empty.txt" "$FX/codex-empty-ok.yaml" "$FX/recritic-empty.txt")" \
    || { no "case_ask_status_nothing_left: 준비 실패"; return; }
  assert_eq "$(status_of "$d")" "이상 없음" "상태 줄: 남은 것도 경고도 없으면 「이상 없음」"
  rm -rf "$d"
}
case_ask_status_unverified() {     # case_T46_critic_dead_twice_unverified 와 같은 준비
  local d s; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "case_ask_status_unverified: 준비 실패"; return; }
  critic_dead_twice "$d"
  s="$(status_of "$d")"
  assert_eq "$s" "「미검증」 리뷰어(doc-critic)가 결과를 내지 못해 이 라운드는 리뷰되지 않았다." "상태 줄: 미검증이면 그 공시의 첫 문장이고 두 문구는 쓰지 않는다"
  rm -rf "$d"
}
case_ask_unknown_warn_counted() {
  local got; got="$(PYTHONPATH="$SCRIPTS" python3 -c '
import docreview_state as S, docreview_ask as A
e = S._warn_entries(["표에 없는 경고 하나", "codex 없음 — 모델 다양성 0 (exit_nonzero)"])
print(e[0]); print(A.short_warn_line(e))')"
  assert_eq "$got" "(None, '표에 없는 경고 하나')
리뷰 경고 2개: codex 리뷰 없음 · 그 밖 1개" "짧은 경고 줄: 표에 없는 원문도 센다(버리지 않는다)"
}
case_ask_warn_gloss_short_names_total() {
  local got; got="$(PYTHONPATH="$SCRIPTS" python3 -c '
import docreview_state as S
print(all(len(r) == 4 and isinstance(r[3], str) and 0 < len(r[3]) <= 14 for r in S.WARN_GLOSS))')"
  assert_eq "$got" "True" "경고 표: 모든 행에 열네 글자 안의 짧은 이름이 있다(∀)"
}
case_ask_plain_warns_unchanged() {
  local got; got="$(PYTHONPATH="$SCRIPTS" python3 -c '
import docreview_state as S
w = ["codex 없음 — 모델 다양성 0 (exit_nonzero)", "셀 수 없음: layer2 — block missing", "표에 없는 경고", "보류: a", "보류: a"]
print(S._plain_warns(w) == [l for _, l in S._warn_entries(w)], len(S._plain_warns(w)))')"
  assert_eq "$got" "True 5" "경고 표: 쉬운 줄 목록은 그대로이고 같은 글자의 사건은 따로 센다"
}

# ── 질문 재료(`ask-material`) — 질문으로 뜨는 행마다 묶음 하나(설계 §3-1 · AC4) ─────────────────
unset DEVBREW_DOCREVIEW_ASK_WIDTH   # 개발자 환경의 기준 길이가 케이스에 새지 않게 한다
mat() { py docreview_state.py ask-material --state-dir "$1" "${@:2}"; }   # mat <state-dir> [플래그…]
ask_prep_fields() {   # 정할 것 하나 + 고칠 곳 하나(critic-fields) · codex 실패 · 재비판 건너뜀 → state dir
  route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-fields.txt" "$FX/codex-failed.yaml" --skip
}

case_ask_material_decide_bundle() {
  local d m fid; d="$(ask_prep_fields)" || { no "질문 재료: route_r1 실패"; return; }
  fid="$(jget "$d/fin.json" '[x["id"] for x in d["findings"] if x["disposition"]=="decide" and "다른 것을 겨눈다" in x["summary"]][0]')"
  local before rb; before="$(cksum < "$d/docreview-state.md")"; rb="$(py docreview_state.py gate --state-dir "$d" --render | cksum)"
  m="$(mat "$d" --gate-file-result '{"ok": true, "shown": "~/x/gate-r1.md"}')"
  assert_grep "$m" "^질문 [0-9]+/[0-9]+ \(${fid}\)$" "질문 재료: 머리 줄에 차례와 지적 id"
  assert_contains "$m" "본문: Goals 가 브리프의 goal 과 다른 것을 겨눈다" "질문 재료: 본문은 리뷰어의 요약 칸 그대로"
  assert_grep "$m" '^상태: 리뷰 경고 [0-9]+개: ' "질문 재료: 상태 줄은 짧은 경고 줄"
  assert_contains "$m" "전문: ~/x/gate-r1.md" "질문 재료: 전문 줄은 받은 경로 그대로"
  assert_contains "$m" "선택지: 고친다(채택) / 그대로 둔다(기각) / 나중에 정한다(보류)" "질문 재료: 선택지는 엔진 라벨"
  assert_contains "$m" "고치면 (30자 · 그대로): §2 를 브리프 §1 의 goal 한 문장으로 되돌린다" "질문 재료: 고치면 칸 전문과 길이 표시"
  assert_contains "$m" "그대로 두면 (26자 · 그대로): 설계 전체가 다른 문제를 잘 푸는 쪽으로 굳는다" "질문 재료: 그대로 두면 칸 전문과 길이 표시"
  assert_contains "$m" "고정 얻음: 그대로 둔다(기각) = 지금 글이 그대로 남는다" "질문 재료: 그대로 둔다의 얻음은 엔진 문구"
  assert_contains "$m" "고정 설명: 나중에 정한다(보류) = 지금 정하지 않는다 — 이 지적은 승인을 더 막지 않고 리뷰가 다시 묻지 않는다 | 얻음: 지금 정하지 않고 넘어간다 · 내줌: 이 지적은 승인을 더 막지 않고 리뷰가 다시 묻지 않는다" \
    "질문 재료: 보류의 고정 설명이 두 꼴이고 엔진이 실제로 하는 일을 적는다"
  assert_eq "$(cksum < "$d/docreview-state.md")" "$before" "질문 재료: 원장을 쓰지 않는다(읽기 전용)"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" --render | cksum)" "$rb" "질문 재료: 부른 뒤에도 게이트 글이 같다"
  assert_not_contains "$m" "질문으로 뜨는 행 없음" "질문 재료: 묶음이 있으면 묶음 0 의 머리 줄은 없다(양의 짝)"
  rm -rf "$d"
}
case_ask_material_no_bundles() {               # case_ask_status_nothing_left 와 같은 준비 — 질문으로 뜨는 행이 없다
  local d m; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-empty.txt" "$FX/codex-empty-ok.yaml" "$FX/recritic-empty.txt")" \
    || { no "case_ask_material_no_bundles: 준비 실패"; return; }
  m="$(mat "$d" --gate-file-result '{"ok": true, "shown": "~/x/gate-r1.md"}')"
  assert_eq "$m" "질문으로 뜨는 행 없음 — 아래 두 줄은 다음 단계 질문의 본문에 싣는다
상태: 이상 없음
전문: ~/x/gate-r1.md" "질문 재료: 묶음이 0 이면 머리 줄과 다음 단계 질문이 싣는 「상태」 · 「전문」 두 줄만 낸다"
  assert_contains "$(mat "$d")" "전문: 전문 파일을 쓰지 못했다 — 쓰는 명령을 부르지 않았다" "질문 재료: 묶음이 0 이어도 전문 줄은 쓰기 결과를 따른다"
  rm -rf "$d"
}
case_ask_material_length_mark_uses_width() {   # case_ask_material_decide_bundle 과 같은 준비, 환경 값 20
  local d m rc; d="$(ask_prep_fields)" || { no "case_ask_material_length_mark_uses_width: 준비 실패"; return; }
  m="$(DEVBREW_DOCREVIEW_ASK_WIDTH=20 mat "$d")"
  assert_contains "$m" "고치면 (30자 · 줄인다): " "질문 재료: 기준 길이를 넘으면 「줄인다」"
  DEVBREW_DOCREVIEW_ASK_WIDTH=5 mat "$d" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "질문 재료: 기준 길이가 허용 범위 밖이면 rc 2"
  rm -rf "$d"
}
case_ask_material_absent_fields() {            # case_decision_view_absence_is_literal 과 같은 준비(두 칸이 없는 지적)
  local d m r; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "case_ask_material_absent_fields: 준비 실패"; return; }
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample-r2.md" > "$d/fin.json"
  m="$(mat "$d")"; r="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_contains "$m" "고치면 (부재): (대체안 미작성)" "질문 재료: 대체안이 없으면 부재 표기"
  assert_contains "$m" "그대로 두면 (부재): (리뷰어가 안 적음)" "질문 재료: 그대로 두면이 없으면 부재 표기"
  assert_contains "$r" "고치면: (대체안 미작성)" "질문 재료 짝: 게이트 글의 부재 표기와 글자가 같다"
  assert_contains "$r" "그대로 두면: (리뷰어가 안 적음)" "질문 재료 짝: 게이트 글의 부재 표기와 글자가 같다"
  rm -rf "$d"
}
case_ask_material_post_decision() {            # case_T35_frozen_change_auto_decide 와 같은 준비(허가 없이 바뀐 절)
  local d m; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "case_ask_material_post_decision: 준비 실패"; return; }
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample-r2.md" > "$d/fin.json"
  # 이 준비에는 라운드 1 의 사전 결정도 열려 있다(그 묶음엔 「고정 얻음」이 있다) — 사후 결정 하나의 묶음만 본다.
  local fid; fid="$(jget "$d/fin.json" '[x["id"] for x in d["findings"] if x["category"]=="frozen_change"][0]')"
  m="$(mat "$d" | awk -v id="($fid)" 'BEGIN { RS = "" } index($0, id)')"
  assert_grep "$m" "^질문 [0-9]+/[0-9]+ \(${fid}\)$" "질문 재료 전제: 사후 결정의 묶음 하나를 골라냈다"
  assert_contains "$m" "선택지: 현재 변경 유지(채택) / 이전 상태로 원복(기각) / 나중에 정한다(보류)" "질문 재료: 사후 결정의 선택지"
  assert_contains "$m" "덧줄: 「채택」은 원복 의무를 관측 없이 종결한다" "질문 재료: 사후 채택이 뜻하는 것이 덧줄에 있다"
  assert_contains "$m" "고정 설명: 현재 변경 유지(채택) = 바뀐 글을 받아들인다 — 되돌릴 의무가 끝나고 리뷰가 다시 확인하지 않는다 | 얻음: 바뀐 글이 그대로 남는다 · 내줌: 허가 없이 바뀐 글을 받아들여 되돌릴 의무가 끝난다" "질문 재료: 현재 변경 유지의 고정 설명"
  assert_contains "$m" "고정 설명: 이전 상태로 원복(기각) = 바뀐 글을 이전 글로 되돌려야 한다 — 다음 라운드가 확인할 때까지 승인이 막힌다 | " "질문 재료: 원복의 고정 설명"
  assert_not_contains "$m" "고정 얻음: " "질문 재료: 사후 결정에는 「고정 얻음」 줄이 없다"
  rm -rf "$d"
}
case_ask_material_adopt_unavailable() {        # case_AC38_r3_f5_gate_adopt_unavailable 와 같은 준비
  local d m; d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "case_ask_material_adopt_unavailable: 준비 실패"; return; }
  br "$d" "$FX/brief-append-r1.md"; seed_findings "$d" "[${F_BRIEF_NOIMM/EDIT_SCOPE/#6-사용자-원문}]"
  m="$(mat "$d")"
  assert_contains "$m" "선택지: 그대로 둔다(기각) / 나중에 정한다(보류)" "질문 재료: 고를 수 없는 「고친다」는 선택지에 없다"
  assert_contains "$m" "덧줄: 고친다(채택)는 고를 수 없다 — " "질문 재료: 그 이유가 덧줄에 있다"
  rm -rf "$d"
}
case_ask_material_fix_rows_flag() {            # case_plain_render_fix_and_decide 와 같은 준비(고칠 곳 하나 + 정할 것 하나)
  local d a b; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-fields.txt" "$FX/codex-empty-ok.yaml" "$FX/recritic-empty.txt")" \
    || { no "case_ask_material_fix_rows_flag: 준비 실패"; return; }
  a="$(mat "$d")"; b="$(mat "$d" --fix-rows)"
  assert_not_contains "$a" "선택지: 적용 / 적용하지 않음" "질문 재료: 플래그가 없으면 수정 행은 묶음이 없다"
  assert_contains "$b" "선택지: 적용 / 적용하지 않음" "질문 재료: --fix-rows 면 수정 행도 전체 묶음"
  assert_contains "$b" "고정 얻음: 적용하지 않음 = 지금 글이 그대로 남는다" "질문 재료: 적용하지 않음의 얻음은 엔진 문구"
  assert_contains "$b" "고치면 (" "질문 재료: 수정 행에도 두 칸이 있다"
  rm -rf "$d"
}
case_ask_material_blocking_ask_short() {       # case_T31_T34_blocked_fix_held_gate_opens 와 같은 준비
  local d m; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "case_ask_material_blocking_ask_short: 준비 실패"; return; }
  seed_findings "$d" "[$F_FIX,$F_ASK]"
  m="$(mat "$d")"
  assert_contains "$m" "렌더: " "질문 재료: 수정의 전제가 되는 질문은 짧은 묶음"
  assert_contains "$m" "이 답을 기다리는 수정 " "질문 재료: 짧은 묶음의 렌더 줄은 게이트 글의 그 줄"
  rm -rf "$d"
}
case_ask_material_ask_rows_flag() {            # 막지 않는 질문 하나(blocks 없음) — --ask-rows 일 때만 짧은 묶음
  local d a b; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "case_ask_material_ask_rows_flag: 준비 실패"; return; }
  seed_findings "$d" "[${F_ASK/\"blocks\":\[\"bbbb0001#r1.1\"\]/\"blocks\":[]}]"
  a="$(mat "$d")"; b="$(mat "$d" --ask-rows)"
  assert_not_contains "$a" "(cccc0001#r1.1)" "질문 재료: 플래그가 없으면 답을 기다리는 질문 행은 묶음이 없다"
  assert_contains "$b" "렌더: b.py 를 유지하나? (cccc0001#r1.1)" "질문 재료: --ask-rows 면 그 행이 짧은 묶음"
  rm -rf "$d"
}
case_ask_material_extra_round() {              # case_cap_zero_open_two_stage 와 같은 준비(상한 도달 · 열린 것 0)
  local d m; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "case_ask_material_extra_round: 준비 실패"; return; }
  next_round "$d" "$FX/design-sample.md" >/dev/null; next_round "$d" "$FX/design-sample.md" >/dev/null
  m="$(mat "$d")"
  assert_contains "$m" "(추가 라운드)" "질문 재료: 상한에 닿으면 추가 라운드 묶음"
  assert_contains "$m" "선택지: 추가 라운드 1회 열기 / 진행 옵션으로" "질문 재료: 열린 것이 0 이면 두 선택지"
  assert_contains "$m" "고정 설명: 추가 라운드 1회 열기 = 상한 밖 리뷰를 한 번 더 돈다 | 얻음: 고친 글을 리뷰가 한 번 더 본다 · 내줌: 상한 밖 라운드를 한 번 더 돌아 다음 단계가 그만큼 늦어진다" "질문 재료: 추가 라운드 1회 열기의 고정 설명"
  assert_contains "$m" "고정 설명: 진행 옵션으로 = 추가 라운드 없이 다음 단계 질문으로 간다 | 얻음: 리뷰를 닫고 다음 단계 질문으로 간다 · 내줌: 마지막으로 고친 글은 리뷰가 다시 보지 않는다" "질문 재료: 진행 옵션으로의 고정 설명"
  rm -rf "$d"
}
case_ask_material_approve_with_open_tail() {   # case_AC13_open_count_and_label 과 같은 준비(상한 · 열린 지적 있음)
  local d m n; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "case_ask_material_approve_with_open_tail: 준비 실패"; return; }
  seed_findings "$d" "[$F_DEC,$F_FIX]"
  local s="$d/s.json"; snap "$FX/design-sample.md" "$s"
  put_snap "$d" "$s" && py docreview_state.py begin-round --state-dir "$d" >/dev/null; put_snap "$d" "$s" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  m="$(mat "$d")"; n="$(py docreview_state.py gate --state-dir "$d" | jgets 'd["open_total"]')"
  assert_contains "$m" "선택지: 열기 / 열지 않음" "질문 재료: 열린 것이 있으면 추가 라운드는 열기 · 열지 않음"
  assert_contains "$m" "고정 설명: 열지 않음 = 추가 라운드를 열지 않는다 — 남은 항목은 이 게이트에서 정한다 | 얻음: 리뷰를 이 라운드에서 닫는다 · 내줌: 마지막으로 고친 글은 리뷰가 다시 보지 않는다" "질문 재료: 열지 않음의 고정 설명"
  assert_contains "$m" "승인 선택지 고정 설명: 열린 지적 ${n}개를 두고 진행 = 열린 지적 ${n}개를 둔 채 다음 단계 질문으로 간다 | 얻음: 리뷰를 닫고 다음 단계로 간다 · 내줌: 열린 지적 ${n}개가 풀리지 않은 채 넘어간다" "질문 재료: 승인 선택지의 고정 설명이 꼬리에 있다"
  rm -rf "$d"
}
case_ask_material_gate_file_failed() {         # case_ask_material_decide_bundle 과 같은 준비
  local d m; d="$(ask_prep_fields)" || { no "case_ask_material_gate_file_failed: 준비 실패"; return; }
  m="$(mat "$d" --gate-file-result '{"ok": false, "reason": "gate_file_write_failed", "detail": "Permission denied"}')"
  assert_contains "$m" "전문: 전문 파일을 쓰지 못했다 — gate_file_write_failed · Permission denied" "질문 재료: 전문을 못 썼으면 그 사유가 전문 줄에 나온다"
  assert_contains "$(mat "$d")" "전문: 전문 파일을 쓰지 못했다 — 쓰는 명령을 부르지 않았다" "질문 재료: 결과를 받지 못했으면 그렇게 알린다"
  assert_contains "$(mat "$d" --gate-file-result '깨진 글')" "전문: 전문 파일을 쓰지 못했다 — 결과를 읽지 못했다" "질문 재료: 결과가 JSON 이 아니면 그렇게 알린다"
  rm -rf "$d"
}
case_ask_material_module_missing() {           # 원장 스크립트만 복사한 트리 — ask-material 만 사유를 내고 멈춘다
  local d t rc; d="$(ask_prep_fields)" || { no "case_ask_material_module_missing: 준비 실패"; return; }
  t="$(mktemp -d -t asklone-XXXXXX)"; cp -L "$SCRIPTS/docreview_state.py" "$SCRIPTS/docreview_config.py" "$t/"
  python3 "$t/docreview_state.py" ask-material --state-dir "$d" >"$t/out" 2>"$t/err"; rc=$?
  assert_eq "$rc $(grep -c ask_module_missing "$t/err") $(wc -c < "$t/out" | tr -d ' ')" "1 1 0" \
    "형제 부재: ask-material 은 ask_module_missing rc 1 로 멈추고 재료를 내지 않는다"
  rm -rf "$d" "$t"
}

# ── 전문 파일(`gate-file`) — 라운드마다 파일 하나, 구역 둘(설계 §3-2 · AC5) ─────────────────
gfile() { py docreview_state.py gate-file --state-dir "$1"; }
gfile_prep() {   # case_ask_material_decide_bundle 과 같은 준비 → 부른 쪽의 local d · fid 에 담는다
  d="$(ask_prep_fields)" || return 1
  fid="$(jget "$d/fin.json" '[x["id"] for x in d["findings"] if x["disposition"]=="decide" and "다른 것을 겨눈다" in x["summary"]][0]')"
}

case_gate_file_two_zones_match_render() {
  local d fid out p; gfile_prep || { no "case_gate_file_two_zones_match_render: 준비 실패"; return; }
  out="$(gfile "$d")"; p="$(printf '%s' "$out" | jgets 'd["path"]')"
  assert_eq "$(printf '%s' "$out" | jgets 'd["ok"], d["round"]')" "(True, 1)" "전문 파일: 성공 JSON"
  assert_eq "${p##*/}" "gate-r1.md" "전문 파일: 라운드마다 파일 하나(gate-r<라운드>.md)"
  local zone1; zone1="$(awk '/^## 지금 게이트 글$/{f=1;next} /^## 이 라운드의 지적 원문$/{f=0} f' "$p" | sed -e '$ d')"
  assert_eq "$zone1" "$(py docreview_state.py gate --state-dir "$d" --render)" "전문 파일: 「지금 게이트 글」 구역이 그때의 게이트 글과 같다"
  assert_file_grep "$p" '^  고치면: §2 를 브리프 §1 의 goal 한 문장으로 되돌린다$' "전문 파일: 원문 구역에 대체안 전문"
  assert_file_grep "$p" '^  그대로 두면: plan 이 그 자리를 스스로 지어낸다$' "전문 파일: 결정이 아닌 지적(고칠 곳)의 원문도 있다"
  local zone2; zone2="$(sed -n '/^## 이 라운드의 지적 원문$/,$p' "$p")"   # 게이트 글도 같은 꼴의 「고치면:」 줄을 싣는다
  assert_grep "$zone2" '^  고치면: §2 를 브리프 §1 의 goal 한 문장으로 되돌린다$' "전문 파일: 대체안 전문은 원문 구역 안에 있다"
  assert_grep "$zone2" "^  자리: #12-files-to-modify$" "전문 파일: 원문 구역의 자리 칸은 지적의 앵커다"
  assert_grep "$zone2" "^  근거: —$" "전문 파일: 근거가 없으면 「—」"
  rm -rf "$d"
}
case_gate_file_originals_preserved() {         # 같은 준비 → gate-file → 한 결정을 adopt → gate-file
  local d fid p a b; gfile_prep || { no "case_gate_file_originals_preserved: 준비 실패"; return; }
  p="$(gfile "$d" | jgets 'd["path"]')"
  a="$(sed -n '/^## 이 라운드의 지적 원문$/,$p' "$p")"
  py docreview_state.py decide --state-dir "$d" --id "$fid" --choice adopt --quote="고친다" >/dev/null
  gfile "$d" >/dev/null; b="$(sed -n '/^## 이 라운드의 지적 원문$/,$p' "$p")"
  assert_eq "$b" "$a" "전문 파일: 결정을 반영한 뒤 다시 써도 원문 구역의 글이 같다"
  assert_file_grep "$p" '다음 라운드에서 반영이 확인돼야 닫힌다' "전문 파일 짝: 「지금 게이트 글」 구역은 새 게이트 글로 바뀌었다"
  # 새로 지어도 같은 글이 나오는 준비라 위 단언만으로는 「잇는다」와 「새로 짓는다」를 못 가른다 — 옛 구역에만 있는 줄로 가른다.
  printf -- '- 옛 라운드 글에만 있는 줄 (zzzz0001#r1.9)\n' | py nofollow_write.py append --out "$p"
  gfile "$d" >/dev/null
  assert_file_grep "$p" '^- 옛 라운드 글에만 있는 줄 \(zzzz0001#r1\.9\)$' "전문 파일: 원문 구역은 옛 파일의 글을 그대로 잇는다(새로 짓지 않는다)"
  rm -rf "$d"
}
case_gate_file_channel_zone_not_duplicated() { # gate-file → 펜스가 하듯 채널 구역을 덧붙임 → gate-file
  local d fid p; gfile_prep || { no "case_gate_file_channel_zone_not_duplicated: 준비 실패"; return; }
  p="$(gfile "$d" | jgets 'd["path"]')"
  printf '\n## 다른 채널의 경고\n번호 대조 경고 2개\n' | py nofollow_write.py append --out "$p"
  assert_eq "$(grep -c '^## 다른 채널의 경고$' "$p")" "1" "전문 파일 전제: 펜스가 채널 구역을 덧붙였다"
  gfile "$d" >/dev/null
  assert_eq "$(grep -c '^## 다른 채널의 경고$' "$p")" "0" "전문 파일: 다시 쓰면 옛 채널 구역이 사라진다(펜스가 다시 덧붙인다)"
  assert_eq "$(grep -c '^## 이 라운드의 지적 원문$' "$p")" "1" "전문 파일: 원문 구역은 하나다"
  assert_file_absent "$p" "번호 대조 경고 2개" "전문 파일: 옛 채널 줄이 원문 구역에 섞여 남지 않는다"
  rm -rf "$d"
}
case_gate_file_advice_included() {             # case_AC1_brief_overdesign_only 와 같은 준비(참고 항목이 생기는 프로필)
  local d p adv_id
  d="$(route_r1 "$PROF_MC/brief.md" "$FX/brief-sample.md" "$FX/critic-brief-overdesign.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")" \
    || { no "case_gate_file_advice_included: 준비 실패"; return; }
  adv_id="$(st_yaml "$d" '[v["id"] for v in (st.get("advice") or {}).values()][0]')"
  assert_grep "$adv_id" '#r1\.[0-9]+$' "전문 파일 전제: 참고 원장에 라운드 1 항목이 있다"
  p="$(gfile "$d" | jgets 'd["path"]')"
  assert_file_grep "$p" "^- .* \(${adv_id}\)$" "전문 파일: 참고로 간 항목도 원문 구역에 있다"
  rm -rf "$d"
}
case_gate_file_round_and_rejected() {          # 기본 route_r1(재비판이 하나를 기각) → 라운드 2(case_ask_material_absent_fields 와 같은 준비)
  local d p1 p2 r1sum; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "case_gate_file_round_and_rejected: 준비 실패"; return; }
  local rej; rej="$(jget "$d/fin.json" 'd["rejected"][0]["id"]')"
  p1="$(gfile "$d" | jgets 'd["path"]')"
  assert_not_contains "$(cat "$p1")" "($rej)" "전문 파일: 재비판이 기각한 지적은 원문 구역에 없다"
  assert_file_grep "$p1" "^- .* \(${rej%.*}\.2\)$" "전문 파일 짝: 같은 버킷의 기각되지 않은 지적은 있다"
  r1sum="$(cksum < "$p1")"
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample-r2.md" > "$d/fin.json"
  p2="$(gfile "$d" | jgets 'd["path"]')"
  assert_eq "${p2##*/}" "gate-r2.md" "전문 파일: 라운드 2 는 새 파일이다"
  assert_eq "$(cksum < "$p1")" "$r1sum" "전문 파일: 앞 라운드 파일은 그대로 남는다"
  assert_eq "$(sed -n '/^## 이 라운드의 지적 원문$/,$p' "$p2" | grep -c '#r1\.')" "0" "전문 파일: 원문 구역에는 이번 라운드 지적만 있다"
  assert_file_grep "$p2" '^- .* \([0-9a-f]+#r2\.[0-9]+\)$' "전문 파일 짝: 이번 라운드 지적은 있다"
  rm -rf "$d"
}
case_gate_file_symlink_refused() {
  local d fid out rc; gfile_prep || { no "case_gate_file_symlink_refused: 준비 실패"; return; }
  ln -s "$d/elsewhere.md" "$d/gate-r1.md"
  out="$(gfile "$d" 2>&1)"; rc=$?
  assert_eq "$rc" "1" "전문 파일: 마지막 성분이 링크면 쓰지 않는다(rc 1)"
  assert_contains "$out" "gate_file_write_failed" "전문 파일: 사유를 낸다"
  assert_contains "$out" "링크다 — 따라가지 않는다" "전문 파일: 링크라서 멈췄다고 적는다"
  [ ! -e "$d/elsewhere.md" ] && ok "전문 파일: 링크가 가리키는 곳에 쓰지 않았다" || no "전문 파일: 링크를 따라가 썼다"
  [ -L "$d/gate-r1.md" ] && ok "전문 파일: 링크를 일반 파일로 바꾸지 않았다" || no "전문 파일: 링크 자리를 새 파일로 바꿨다"
  assert_contains "$(mat "$d" --gate-file-result "$out")" "전문: 전문 파일을 쓰지 못했다 — gate_file_write_failed · 링크다 — 따라가지 않는다" \
    "전문 파일: 실패 결과를 질문 재료에 넘기면 그 사유가 전문 줄에 나온다"
  rm -rf "$d"
}
case_gate_file_ledger_untouched() {
  local d fid before; gfile_prep || { no "case_gate_file_ledger_untouched: 준비 실패"; return; }
  before="$(cksum < "$d/docreview-state.md")"; gfile "$d" >/dev/null
  assert_eq "$(cksum < "$d/docreview-state.md")" "$before" "전문 파일: 원장은 바뀌지 않는다"
  rm -rf "$d"
}
case_gate_file_success_feeds_material() {
  local d fid out; gfile_prep || { no "case_gate_file_success_feeds_material: 준비 실패"; return; }
  out="$(cd "$d" && gfile "$d")"
  assert_eq "$(printf '%s' "$out" | jgets 'd["shown"]')" "gate-r1.md" "전문 파일: 작업 폴더 아래면 보이는 경로가 상대 경로다"
  assert_contains "$(mat "$d" --gate-file-result "$out")" "전문: gate-r1.md" "전문 파일: 성공 결과를 넘기면 보이는 경로가 전문 줄이 된다"
  rm -rf "$d"
}
case_gate_file_module_missing() {              # 원장 스크립트와 질문 모듈만 복사한 트리 — gate-file 만 사유를 내고 멈춘다
  local d fid t rc; gfile_prep || { no "case_gate_file_module_missing: 준비 실패"; return; }
  t="$(mktemp -d -t gfclone-XXXXXX)"
  cp -L "$SCRIPTS/docreview_state.py" "$SCRIPTS/docreview_config.py" "$SCRIPTS/docreview_ask.py" "$t/"
  python3 "$t/docreview_state.py" gate-file --state-dir "$d" >"$t/out" 2>"$t/err"; rc=$?
  assert_eq "$rc $(grep -c writer_module_missing "$t/err") $(wc -c < "$t/out" | tr -d ' ') $(ls "$d" | grep -c '^gate-r')" "1 1 0 0" \
    "형제 부재: gate-file 은 writer_module_missing rc 1 로 멈추고 파일을 쓰지 않는다"
  rm -rf "$d" "$t"
}
case_gate_file_is_write_command() {
  local got; got="$(PYTHONPATH="$SCRIPTS" python3 -c '
import argparse, docreview_state as S
sub = next(a for a in S.build_parser()._actions if isinstance(a, argparse._SubParsersAction))
print("gate-file" in sub.choices, "ask-material" in sub.choices)')"
  assert_eq "$got" "True True" "하위 명령: gate-file 과 ask-material 이 있다"
  assert_not_contains "$(grep -n '^AC8_READ_ONLY=' "$REPO_ROOT/plugins/spec-distill/tests/test_ledger_wiring.sh")" "gate-file" "하위 명령: gate-file 은 읽기 전용 목록에 없다"
}
case_ask_display_path() {
  local got; got="$(PYTHONPATH="$SCRIPTS" python3 -c '
from docreview_ask import display_path as p
print(p("/w/repo/.claude/x.md", "/w/repo", "/h")); print(p("/h/a/x.md", "/w/repo", "/h")); print(p("/o/x.md", "/w/repo", "/h"))
print(p("/w/repository/x.md", "/w/repo", "/h"))')"
  assert_eq "$got" ".claude/x.md
~/a/x.md
/o/x.md
/w/repository/x.md" "보이는 경로: 작업 폴더 아래면 상대, 홈 아래면 ~, 아니면 그대로(이름의 앞만 같은 폴더는 아래가 아니다)"
}
case_ask_originals_block_unit() {
  local got; got="$(PYTHONPATH="$SCRIPTS" python3 -c '
import docreview_ask as A
print(A.originals_block([{"id": "a#r1.1", "summary": "요약 하나", "if_unfixed": None, "replacement": "줄 하나\n줄 둘",
                          "evidence": None, "anchor": "#2-goals"}]))
print(A.originals_block([]))
t = A.gate_file_text(2, "게이트", "원문")
print(repr(t))
print(repr(A.keep_originals(t)), repr(A.keep_originals(t + "\n## 다른 채널의 경고\nx\n")), repr(A.keep_originals("# 다른 글\n")))')"
  assert_eq "$got" "- 요약 하나 (a#r1.1)
  그대로 두면: (리뷰어가 안 적음)
  고치면: 줄 하나
    줄 둘
  근거: —
  자리: #2-goals
없음 — 이 라운드에 판정을 지난 지적이 없다
'# 리뷰 2라운드 — 게이트 전문\n\n## 지금 게이트 글\n게이트\n\n## 이 라운드의 지적 원문\n원문\n'
'원문' '원문' None" "원문 구역: 칸마다 한 줄 · 없는 칸은 부재 표기 · 여러 줄은 들여 잇는다 · 파일 꼴 · 옛 구역을 그대로 읽어 낸다"
}
