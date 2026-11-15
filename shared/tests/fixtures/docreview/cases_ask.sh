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
