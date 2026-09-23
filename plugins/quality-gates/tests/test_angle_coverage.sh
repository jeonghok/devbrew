#!/usr/bin/env bash
# test_angle_coverage.sh — AC10 · AC10a · AC11 · AC12 (설계 §6.3.1 · §6.3.2).
#
# 이 락이 `test_review_floor_lock.sh` 를 **교체**한다(Task 4 가 그것을 지운다).
# 옛 락의 앵커는 SKILL.md 의 명단 리터럴이었고 그것은 **피검자가 쥔 앵커**였다 —
# 모델이 산문을 고치면 락이 따라 움직인다. 새 앵커는 합성기가 쓰는 모듈의
# ∀ 관계다: 각도 셋 전부가 상태를 갖지 않으면 exit 4 이고, 그 「셋」은 이 락이
# 열거하지 않고 `angles.py` 에서 **도출**한다.
#
# **이 락이 재지 «않는» 것(설계 §15-4)** — 「각도가 상태를 가졌는가」는 재지만
# 「그 상태가 참인가」는 못 잰다. 모델이 세 각도를 전부 `folded_into:` 로 주장하면
# 이 락은 GREEN 이다. 형식적 완전성의 락이지 진실성의 락이 아니다.
#
# **오늘 배선이 안 된 것** — `--angles` 는 기본 off 다(계획 R-E). 오케스트레이터가
# 그것을 «항상» 싣게 만드는 것은 PR4 의 빚이고, 이 락은 그 빚을 재지 못한다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd -- "$PLUGIN_ROOT/../.." && pwd)"
. "$REPO_ROOT/shared/tests/assert.sh"
A="$PLUGIN_ROOT/scripts/angles.py"
export PYTHONDONTWRITEBYTECODE=1

TMP="$(mktemp -d -t angles-XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT

# 열거를 **모듈에게 물어** 가져온다. 여기에 리터럴을 복사하면 두 자리가 어긋날 때
# 락이 자기 사본만 보고 GREEN 을 낸다.
ANGLES="$(python3 -c "
import sys; sys.path.insert(0,'$PLUGIN_ROOT/scripts'); import angles
print('\n'.join(angles.ANGLES))")"
BLOCKING="$(python3 -c "
import sys; sys.path.insert(0,'$PLUGIN_ROOT/scripts'); import angles
print('\n'.join(angles.BLOCKING_ANGLES))")"
REASONS="$(python3 -c "
import sys; sys.path.insert(0,'$PLUGIN_ROOT/scripts'); import angles
print('\n'.join(angles.ABSENT_REASONS))")"

# 도출이 실패하면(모듈 부재·문법 오류) 아래 전부가 «빈 코퍼스 위의 통과»가 된다.
# 침묵하지 않고 여기서 먼저 밝힌다 — vacuous 락은 통과가 곧 증거가 아니다.
if [ -z "$ANGLES" ] || [ -z "$BLOCKING" ] || [ -z "$REASONS" ]; then
  no "angles.py 에서 열거를 도출하지 못했다 — 아래 단언은 아무것도 재지 않는다"
  # `finish` 는 «종료하지 않는다» — 값을 반환할 뿐이다(`shared/tests/assert.sh:111-114`).
  # 뒤에 `exit` 가 없으면 스크립트가 그대로 계속 돌아 빈 코퍼스 위에서 단언을 쌓는다.
  # 인자 없는 `exit` 는 직전 명령(`finish`)의 상태로 나간다.
  finish; exit
fi

# write_angles <파일> <"각도: 상태"...>  — 생략된 각도는 안 쓴다(총 함수 검사용)
write_angles() {
  local f="$1"; shift
  : > "$f"
  local kv
  for kv in "$@"; do printf '%s\n' "$kv" >> "$f"; done
}

case_all_three_filled_is_ok() {
  local f="$TMP/ok.txt" out rc=0
  write_angles "$f" "security: filled" "adjudication: filled" "different-premise: filled"
  out="$(python3 "$A" --angles "$f")" || rc=$?
  assert_eq "$rc" "0" "세 각도가 전부 상태를 가지면 exit 0"
  assert_grep "$out" '^angles:$'                     "angles: 블록이 나온다"
  assert_grep "$out" '^  security: filled$'          "보안 각도 한 줄"
  assert_grep "$out" '^  adjudication: filled$'      "판정 각도 한 줄"
  assert_grep "$out" '^  different-premise: filled$' "다른 전제 각도 한 줄"
  assert_grep "$out" '^angle_absent: false$'         "막지 않는다"
}

case_every_angle_is_required() {
  # AC10 — **총 함수**다. 각도 하나를 «빼면» 그것이 무엇이든 exit 4 여야 한다.
  # 열거를 도출해 돌므로 `ANGLES` 에 네 번째가 생기면 이 루프가 자동으로 그것도 잰다.
  local missing a f rc out
  while IFS= read -r missing; do
    [ -n "$missing" ] || continue
    f="$TMP/missing-$missing.txt"; : > "$f"
    while IFS= read -r a; do
      [ -n "$a" ] || continue
      [ "$a" = "$missing" ] && continue
      printf '%s: filled\n' "$a" >> "$f"
    done <<< "$ANGLES"
    rc=0; out="$(python3 "$A" --angles "$f" 2>&1)" || rc=$?
    assert_eq "$rc" "4" "'$missing' 의 상태가 없으면 exit 4 (총 함수)"
    assert_contains "$out" "$missing" "오류가 빠진 각도의 이름을 댄다"
  done <<< "$ANGLES"
}

case_state_grammar_is_closed() {
  local f="$TMP/grammar.txt" rc st
  # 문법 «안» — 셋 다 선다
  for st in "filled" "absent" "folded_into:security-reviewer"; do
    write_angles "$f" "security: $st" "adjudication: filled" "different-premise: filled"
    rc=0; python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
    assert_eq "$rc" "0" "'$st' 는 문법 안이다"
  done
  # 문법 «밖» — 넷 다 exit 4. `folded_into:` 뒤가 비거나 공백이 섞인 것도 포함한다.
  for st in "maybe" "folded_into:" "FILLED" "folded_into:two words"; do
    write_angles "$f" "security: $st" "adjudication: filled" "different-premise: filled"
    rc=0; python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
    assert_eq "$rc" "4" "'$st' 는 문법 밖이라 exit 4"
  done
}

case_absent_reason_grammar_is_closed() {
  # I1 (컨트롤러 ruling T2-a · 설계 §15) — `absent(<사유>)` 는 어느 각도에도 쓸 수
  # 있다. 사유는 `ANGLES`/`BLOCKING` 과 같은 방식으로 **모듈에게 물어** 가져온다.
  local f="$TMP/reason.txt" rc st
  # 문법 «안» — 두 사유 모두 선다
  while IFS= read -r st; do
    [ -n "$st" ] || continue
    write_angles "$f" "security: absent($st)" "adjudication: filled" "different-premise: filled"
    rc=0; python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
    assert_eq "$rc" "0" "'absent($st)' 는 문법 안이다"
  done <<< "$REASONS"
  # 문법 «밖» — 빈 괄호·모르는 사유·안 닫힌 괄호는 exit 4
  for st in "absent()" "absent(bogus)" "absent(not-installed"; do
    write_angles "$f" "security: $st" "adjudication: filled" "different-premise: filled"
    rc=0; python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
    assert_eq "$rc" "4" "'$st' 는 문법 밖이라 exit 4"
  done
}

case_unknown_angle_is_fail_closed() {
  local f="$TMP/unknown.txt" rc=0
  write_angles "$f" "security: filled" "adjudication: filled" \
                    "different-premise: filled" "made-up-angle: filled"
  python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "열거 밖 각도는 exit 4 — 각도 셋은 닫혀 있다"
}

case_duplicate_angle_is_fail_closed() {
  # 같은 각도가 두 줄이면 «어느 쪽이 참인지» 산출물만 보고는 복원할 수 없다.
  # 「마지막이 이긴다」로 두면 앞 줄을 조용히 덮는 경로가 열린다.
  local f="$TMP/dup.txt" rc=0
  write_angles "$f" "security: absent" "security: filled" \
                    "adjudication: filled" "different-premise: filled"
  python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "같은 각도가 두 번 나오면 exit 4"
}

case_malformed_extra_line_is_fail_closed() {
  # I2 — 세 각도가 전부 유효해도 서식이 아닌 «여분» 줄이 섞이면 exit 4 여야 한다.
  # `security:absent`(콜론 뒤 공백 없음)는 `_LINE` 패턴 밖이라 `parse()` 의
  # 「서식이 아니다」 절이 이 줄에서 발동해야 한다. 그 절이 조용히 `continue` 로
  # 바뀌어도(누락 각도 검사만으로는 못 잡는다 — 세 각도가 이미 다 채워져 있어서)
  # 이 케이스가 없으면 스위트가 그대로 GREEN 이다. 컨트롤러 지시대로 이 케이스의
  # 이빨은 mutation 으로 직접 확인했다(리포트 "Fix round 1" 절 참고).
  local f="$TMP/malformed-extra.txt" rc=0
  write_angles "$f" "security: filled" "adjudication: filled" \
                    "different-premise: filled" "security:absent"
  python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "형식이 아닌 여분 줄이 섞이면 exit 4"
}

case_blocking_angles_are_exactly_two() {
  # AC11 · AC12 의 비대칭 자체를 핀한다. 「다른 전제」가 `BLOCKING_ANGLES` 에
  # 들어가면 모델 다양성 손실이 게이트가 된다 — 헌장 위반이다. 반대로 보안·판정이
  # 빠지면 AC11 이 죽는다. 아래 두 행동 케이스는 «오늘의 값»만 재므로 집합 자체를
  # 핀하는 이 단언이 따로 필요하다.
  local got; got="$(printf '%s\n' "$BLOCKING" | sort | tr '\n' ' ')"
  assert_eq "$got" "adjudication security " \
    "막는 각도는 보안·판정 둘뿐이다 (다른 전제는 공시만 — AC12)"
}

case_absent_blocking_angle_sets_the_flag() {
  # AC11 의 «산출자» 쪽. 판정 «값» 은 Task 4 의 합성기 경로가 잰다.
  local f="$TMP/absent.txt" out a b
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    : > "$f"
    while IFS= read -r b; do
      [ -n "$b" ] || continue
      if [ "$b" = "$a" ]; then printf '%s: absent\n' "$b" >> "$f"
      else printf '%s: filled\n' "$b" >> "$f"; fi
    done <<< "$ANGLES"
    out="$(python3 "$A" --angles "$f")"
    assert_grep "$out" '^angle_absent: true$' "'$a' 가 absent 면 막는다"
  done <<< "$BLOCKING"
}

case_absent_non_blocking_angle_discloses_only() {
  # AC12 — 「다른 전제」의 부재는 **공시되되 막지 않는다**.
  local f="$TMP/dp-absent.txt" out
  write_angles "$f" "security: filled" "adjudication: filled" "different-premise: absent"
  out="$(python3 "$A" --angles "$f")"
  assert_grep "$out"     '^  different-premise: absent$' "부재가 산출물에 **드러난다**"
  assert_grep "$out"     '^angle_absent: false$'         "그래도 막지 않는다"
  assert_not_grep "$out" '^angle_absent: true$'          "막는다고 말하지 않는다"
}

case_absent_reason_blocks_when_angle_is_blocking() {
  # I1 — 사유가 있어도 **막는 각도**(BLOCKING_ANGLES)면 여전히 막는다. 사유는
  # 「무엇 때문에 부재했는가」를 공시할 뿐 막는지 여부는 여전히 각도가 가른다.
  local f="$TMP/reason-block.txt" out a b
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    : > "$f"
    while IFS= read -r b; do
      [ -n "$b" ] || continue
      if [ "$b" = "$a" ]; then printf '%s: absent(not-derived)\n' "$b" >> "$f"
      else printf '%s: filled\n' "$b" >> "$f"; fi
    done <<< "$ANGLES"
    out="$(python3 "$A" --angles "$f")"
    assert_grep "$out" '^angle_absent: true$' "'$a' 가 absent(not-derived) 면 여전히 막는다"
  done <<< "$BLOCKING"
}

case_absent_reason_on_non_blocking_angle_discloses_only() {
  # I1 — AC12 짝. 「다른 전제」의 부재는 사유가 붙어도 공시만 하고 막지 않는다.
  local f="$TMP/dp-reason.txt" out
  write_angles "$f" "security: filled" "adjudication: filled" "different-premise: absent(not-installed)"
  out="$(python3 "$A" --angles "$f")"
  assert_grep "$out"     '^  different-premise: absent\(not-installed\)$' "부재 사유가 산출물에 그대로 드러난다"
  assert_grep "$out"     '^angle_absent: false$'                          "그래도 막지 않는다"
  assert_not_grep "$out" '^angle_absent: true$'                           "막는다고 말하지 않는다"
}

case_self_adjudication_is_rejected() {
  # AC10a — 판정 각도가 **그 실행에서 finding 을 낸** 수행자에게 접히면 exit 4.
  local f="$TMP/self.txt" rc=0 out
  write_angles "$f" "security: filled" "adjudication: folded_into:security-reviewer" \
                    "different-premise: filled"
  out="$(python3 "$A" --angles "$f" --author security-reviewer 2>&1)" || rc=$?
  assert_eq "$rc" "4" "자기 finding 자기 판정은 exit 4"
  assert_contains "$out" "security-reviewer" "오류가 그 수행자의 이름을 댄다"
}

case_folding_into_a_silent_reviewer_is_ok() {
  # 같은 모양인데 그 수행자가 finding 을 «안 냈으면» 정상이다 — C13 이 허용한
  # 접어 넣기다. 이 케이스가 없으면 위 케이스는 「folded_into 를 전부 막는다」와
  # 구별되지 않는다(양의 짝).
  local f="$TMP/fold-ok.txt" rc=0
  write_angles "$f" "security: filled" "adjudication: folded_into:scout" \
                    "different-premise: filled"
  python3 "$A" --angles "$f" --author security-reviewer >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "0" "finding 을 안 낸 리뷰어에게 접는 것은 정상이다"
}

case_security_angle_may_fold_into_its_own_author() {
  # AC10a 의 **범위 한정**. 보안 각도는 «무엇을 찾는가» 의 문제라 그 리뷰어가
  # finding 을 내는 것이 정상이다. 여기에 같은 금지를 걸면 C13 의 접어 넣기가
  # 사실상 죽는다 — 설계가 명시적으로 뺀 자리다.
  local f="$TMP/sec-fold.txt" rc=0
  write_angles "$f" "security: folded_into:security-reviewer" "adjudication: filled" \
                    "different-premise: filled"
  python3 "$A" --angles "$f" --author security-reviewer >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "0" "보안 각도에는 AC10a 를 적용하지 않는다"
}

case_forbidden_set_is_adjudication_only() {
  # 위 두 케이스는 «오늘의 두 각도»만 잰다. 금지 집합 자체를 핀해야 세 번째
  # 각도가 조용히 편입되거나 판정 각도가 조용히 빠지는 것을 잡는다.
  local got; got="$(python3 -c "
import sys; sys.path.insert(0,'$PLUGIN_ROOT/scripts'); import angles
print(' '.join(sorted(angles.SELF_ADJUDICATION_FORBIDDEN)))")"
  assert_eq "$got" "adjudication" "AC10a 의 대상은 판정 각도 하나다"
}

case_missing_file_is_fail_closed() {
  local rc=0; python3 "$A" --angles "$TMP/nope.txt" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "각도 파일이 없으면 exit 4 (조용히 clean 으로 새지 않는다)"
}

case_empty_flag_is_usage_error() {
  # exit 2 와 exit 4 를 가른다 — 빈 인자는 «잘못된 호출»이지 «실패한 판정»이 아니다.
  local rc=0; python3 "$A" --angles "" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "빈 경로는 usage 오류(exit 2)"
  rc=0; python3 "$A" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "경로를 아예 안 주면 usage 오류(exit 2)"
}

case_non_utf8_is_fail_closed() {
  # 형제 `verdict.read_or_none()` 이 네 번째 재발로 얻은 절이다 —
  # `UnicodeDecodeError` 는 `ValueError` 의 하위이지 `OSError` 가 아니라서,
  # `except OSError` 만 두면 raw traceback + exit 1 로 0/2/4 계약을 탈출한다.
  # 픽스처는 **유효한 본문 뒤에** 나쁜 바이트를 붙인다 — 파일 전체가 쓰레기면
  # 서식 오류로도 exit 4 가 나서 green-for-the-wrong-reason 이 된다.
  local f="$TMP/bad.bin" rc=0
  printf 'security: filled\nadjudication: filled\ndifferent-premise: filled\n' > "$f"
  printf '# \xff\xfe\n' >> "$f"
  python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "비-UTF-8 각도 파일은 exit 4 (traceback 이 아니다)"
}

case_all_three_filled_is_ok
case_every_angle_is_required
case_state_grammar_is_closed
case_absent_reason_grammar_is_closed
case_unknown_angle_is_fail_closed
case_duplicate_angle_is_fail_closed
case_malformed_extra_line_is_fail_closed
case_blocking_angles_are_exactly_two
case_absent_blocking_angle_sets_the_flag
case_absent_non_blocking_angle_discloses_only
case_absent_reason_blocks_when_angle_is_blocking
case_absent_reason_on_non_blocking_angle_discloses_only
case_self_adjudication_is_rejected
case_folding_into_a_silent_reviewer_is_ok
case_security_angle_may_fold_into_its_own_author
case_forbidden_set_is_adjudication_only
case_missing_file_is_fail_closed
case_empty_flag_is_usage_error
case_non_utf8_is_fail_closed
finish
