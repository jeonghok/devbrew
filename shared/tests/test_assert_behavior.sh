#!/usr/bin/env bash
# guards: shared/tests/** plugins/**
#
# assert.sh 헬퍼의 **종료 행동**을 고정한다.
#
# 왜 호출 수로 부족한가(설계 §9.2): "통합 전후 assertion 호출 수 대조"는
# `exit`→계속 전환에 **완전히 불변**이다. 헬퍼를 하나로 합치면서 실패 시
# 즉시 종료하던 것을 계속 진행하게 바꿔도 수 축은 그대로 통과한다 —
# 그러면 뒤 assertion들이 오염된 상태에서 돌고, 스위트는 여전히 "N개 실행"을 보고한다.
#
# 그래서 여기서는 **의도적으로 실패시키는 fixture**로 각 헬퍼가 실패 후
# 이어지는 줄을 실행하는지 아닌지를 직접 관측한다.
set -u
# 위 `# guards:` 선언의 짝 — 이 파일은 아무 경로도 스캔하지 않으므로 빈 출력이 정답이다.
# 답하지 않으면 test_guards_coverage_bidirectional.sh 가 이 스위트를 통째로 실행해 자기
# assertion 출력을 "scanned paths"로 오인한다 〔실측: 이관 중 발견 — 기존 두 guards: 선언
# 파일(test_guards_coverage_bidirectional.sh:13, test_guards_declaration_mapping.sh:13)의
# 확립된 관례를 그대로 따른다〕.
[ "${1:-}" = "--emit-scanned" ] && exit 0
HERE="$(cd "$(dirname "$0")" && pwd)"
pass=0; fail=0
t_ok() { pass=$((pass+1)); echo "  ✓ $1"; }
t_no() { fail=$((fail+1)); echo "  ✗ $1"; }
TMP="$(mktemp -d -t assert-behav-XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT
# 파일 대상 헬퍼의 픽스처. `absent-file` 은 **만들지 않는다** — 부재 시 fail-closed 인지가
# 아래 probe 목록의 마지막 항목이고, 그 이빨은 이관 전 test_adversarial_model_consistency.sh:39
# 의 주석이 실측으로 기록한 것이다("없는 파일에 grep 하면 부재 검사가 vacuous 하게 통과한다").
printf 'NEEDLE here\n' > "$TMP/present.txt"

# 실패를 유발한 뒤 SENTINEL 을 찍는다. SENTINEL 이 보이면 "계속 진행", 안 보이면 "즉시 종료".
probe() {   # $1 = 헬퍼 호출 한 줄
  cat > "$TMP/probe.sh" <<PROBE
#!/usr/bin/env bash
set -u
. "$HERE/assert.sh"
$1
echo "SENTINEL_REACHED"
finish
PROBE
  bash "$TMP/probe.sh" 2>&1
}

# 계약: 판정 헬퍼는 **실패를 세고 계속 진행**한다. 종료는 finish 가 한다.
# (즉시 종료형으로 바꾸고 싶다면 그것은 계약 변경이고, 이 락이 RED 로 알린다.)
for call in 'assert_eq "a" "b" "의도적 실패"' \
            'assert_contains "haystack" "없는것" "의도적 실패"' \
            'assert_grep "text" "없는패턴" "의도적 실패"' \
            'assert_not_grep "text" "te.t" "의도적 실패"' \
            'assert_count_ge "echo 1" 5 "의도적 실패"' \
            'assert_file_absent "'"$TMP"'/present.txt" "NEEDLE" "의도적 실패"' \
            'assert_file_grep "'"$TMP"'/absent-file" "x" "의도적 실패"' \
            'no "의도적 실패"'; do
  out="$(probe "$call")"
  case "$out" in
    *SENTINEL_REACHED*) t_ok "행동: ${call%% *} 실패 후 계속 진행 (계약대로)" ;;
    *) t_no "행동: ${call%% *} 가 실패 시 즉시 종료한다 — 계약이 바뀌었다 (통합이 이빨을 뺐을 수 있다)" ;;
  esac
  case "$out" in
    *"의도적 실패"*) t_ok "행동: ${call%% *} 가 실패 메시지를 낸다" ;;
    *) t_no "행동: ${call%% *} 가 실패를 조용히 삼킨다" ;;
  esac
done

# finish 는 실패가 있으면 non-zero 로 끝나야 한다. 여기가 무너지면 스위트 전체가
# "전부 GREEN"으로 보고된다 — 가장 조용한 실패 모드.
out="$(probe 'assert_eq "a" "b" "의도적 실패"')"; rc=$?
[ "$rc" -ne 0 ] \
  && t_ok "행동: 실패가 있으면 finish 가 non-zero" \
  || t_no "행동: 실패가 있는데 finish 가 0 — 스위트 전체가 거짓 GREEN"

# 양의 짝 — 성공 경로에서는 0 이어야 한다. 없으면 "무엇이든 non-zero"와 구별 안 된다.
out="$(probe 'assert_eq "a" "a" "성공"')"; rc=$?
[ "$rc" -eq 0 ] \
  && t_ok "행동: 실패가 없으면 finish 가 0" \
  || t_no "행동: 성공 경로가 non-zero — 항상-실패 헬퍼"

# 실패 줄의 **접두**를 못박는다. 위 루프의 `*"의도적 실패"*` 검사는 메시지가 나오는지만
# 보므로 **접두 변경에 완전히 불변**이다. 그런데 이 계획의 여러 자리가 `^  ✗ ` 로 실패 줄을
# 골라낸다 — Task 16 의 변이 B `report()` · 카나리아 mutation E · Step 3 무변이 진단,
# Task 35 의 변이 6b, 그리고 Task 35 콜아웃의 샘플 출력 줄(문서가 약속하는 기대 출력).
# 접두가 바뀌면 그 다섯 자리가 **조용히 0건**이 된다. 실제로 그런 판본이 있었다: 넷이
# 이 리포 어디에도 없는 `NO:` 를 찾고 있었고, 실행자는 아무 줄도 못 받았다(2026-08-17
# fix round 5 실측). 그래서 접두 자체가 락 대상이다.
out="$(probe 'no "접두 프로브"')"
printf '%s\n' "$out" | grep -q '^  ✗ 접두 프로브$' \
  && t_ok "출력: 실패 줄 접두가 '  ✗ ' 다 (진단 grep 다섯 자리의 계약)" \
  || t_no "출력: 실패 줄 접두가 '  ✗ ' 가 아니다 — 그 다섯 자리가 조용히 0건이 된다"
# 음의 짝 — 성공 줄도 함께 잰다. 실패 줄만 보면 "모든 줄이 ✗ 로 시작"하는 판본도 통과한다.
out="$(probe 'ok "접두 프로브"')"
printf '%s\n' "$out" | grep -q '^  ✓ 접두 프로브$' \
  && t_ok "출력: 성공 줄 접두가 '  ✓ ' 다" \
  || t_no "출력: 성공 줄 접두가 '  ✓ ' 가 아니다"

# field 의 **인자 순서**를 못박는다. 통합이 순서를 뒤집으면 호출부가 빈 문자열끼리
# 비교하며 조용히 통과하므로, 순서 자체가 락 대상이다.
. "$HERE/assert.sh"
got="$(field 'codex_available' 'codex_available: true
skip_reason: none')"
[ "$got" = "true" ] \
  && t_ok "field: 인자 순서 <key> <text>, 값만 반환" \
  || t_no "field: 인자 순서/반환이 계약과 다르다 (got='$got')"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[ "$fail" -eq 0 ]
