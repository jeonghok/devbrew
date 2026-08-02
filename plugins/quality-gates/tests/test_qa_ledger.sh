#!/usr/bin/env bash
# test_qa_ledger.sh — scripts/check_qa_ledger.py (design §5.6). AC17 AC18 · T14 T15 · M8
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
LEDGER="$PLUGIN_ROOT/scripts/check_qa_ledger.py"

PASS=0; FAIL=0; TMP=""
pass() { PASS=$((PASS + 1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }
setup()   { TMP=$(mktemp -d) || exit 1; }
cleanup() { rm -rf "$TMP"; }

# 완전한 원장을 쓴다. $1이 주어지면 그 floor 차원 줄을 **뺀다**.
write_ledger() {   # write_ledger <file> [omit-dim] [derived-line]
  local f=$1 omit=${2:-} derived=${3:-'- derived: 없음 — 순수 로직 변경으로 이 diff 특유의 확인 축 없음'}
  : > "$f"
  local d
  for d in changed behavior verification attribution gap; do
    [[ "$d" == "$omit" ]] && continue
    printf -- '- floor:%-13s — closed   — evidence for %s\n' "$d" "$d" >> "$f"
  done
  printf '%s\n' "$derived" >> "$f"
}

run_ledger() { python3 "$LEDGER" "$1" >/dev/null 2>&1; }

# T14: 완전한 원장 → 0
case_complete() {
  setup; write_ledger "$TMP/l.md"
  run_ledger "$TMP/l.md" && pass "완전한 원장 → exit 0" || fail "완전 원장이 red"
  cleanup
}

# T14: 5키 각각을 하나씩 뺀 5 픽스처 전부 non-zero
case_each_missing_dimension() {
  setup
  local d ok=1
  for d in changed behavior verification attribution gap; do
    write_ledger "$TMP/l.md" "$d"
    if run_ledger "$TMP/l.md"; then echo "    '$d' 누락인데 통과함"; ok=0; fi
  done
  [[ $ok -eq 1 ]] && pass "5차원 각각 누락 → 전부 non-zero" || fail "누락 감지 실패"
  cleanup
}

# degraded는 1급 상태 — 통과해야 한다 (실패가 아니다)
# 원본 verification 줄을 **치환**한다(추가가 아니라). 추가하면 같은 차원이 두 번
# 선언돼 중복 검사에 걸리고, 이 테스트는 degraded와 무관한 이유로 red가 된다.
case_degraded_is_valid() {
  setup; write_ledger "$TMP/l.md"
  grep -vF 'floor:verification' "$TMP/l.md" > "$TMP/l2.md"
  printf -- '- floor:verification — degraded — unclaimed 2건, 실행 수단 없음\n' >> "$TMP/l2.md"
  run_ledger "$TMP/l2.md" && pass "status=degraded → exit 0 (1급 상태)" || fail "degraded가 red"
  cleanup
}

# 알 수 없는 status는 통과하지 않는다
case_unknown_status() {
  setup; write_ledger "$TMP/l.md"
  grep -v 'floor:gap' "$TMP/l.md" > "$TMP/l2.md"
  printf -- '- floor:gap — unknown — whatever\n' >> "$TMP/l2.md"
  run_ledger "$TMP/l2.md" && fail "status=unknown이 통과함" || pass "알 수 없는 status → non-zero"
  cleanup
}

# evidence 절이 비면 통과하지 않는다 (구조는 있는데 내용이 없는 형식주의 차단)
case_empty_evidence() {
  setup; write_ledger "$TMP/l.md"
  grep -v 'floor:gap' "$TMP/l.md" > "$TMP/l2.md"
  printf -- '- floor:gap — closed —   \n' >> "$TMP/l2.md"
  run_ledger "$TMP/l2.md" && fail "빈 evidence가 통과함" || pass "빈 evidence → non-zero"
  cleanup
}

# T15 + AC18: derived: 없음 + 이유 → 0 / 이유 없음 → non-zero
case_derived_reason_required() {
  setup
  write_ledger "$TMP/ok.md"   "" '- derived: 없음 — 순수 로직 변경이라 확인 축 추가 없음'
  write_ledger "$TMP/bad.md"  "" '- derived: 없음'
  write_ledger "$TMP/none.md" "" '# derived 줄 자체가 없음'
  run_ledger "$TMP/ok.md"   && pass "derived 없음 + 이유 → exit 0"   || fail "derived 이유 있음이 red"
  run_ledger "$TMP/bad.md"  && fail "이유 없는 'derived: 없음'이 통과" || pass "derived 없음 + 이유 부재 → non-zero"
  run_ledger "$TMP/none.md" && fail "derived 줄 부재가 통과"          || pass "derived 줄 부재 → non-zero"
  cleanup
}

# 명명된 derived 차원도 floor와 같은 문법으로 검사된다
case_derived_named() {
  setup
  write_ledger "$TMP/ok.md"  "" '- derived:migration — closed — 스키마 up/down 양방향 확인'
  write_ledger "$TMP/bad.md" "" '- derived:migration'
  run_ledger "$TMP/ok.md"  && pass "명명 derived + status + evidence → exit 0" || fail "명명 derived가 red"
  run_ledger "$TMP/bad.md" && fail "status/evidence 없는 명명 derived가 통과"   || pass "불완전 명명 derived → non-zero"
  cleanup
}

# M8: 헤딩 매칭으로 완화하면 잡혀야 한다 — 차원 이름이 **헤딩에만** 있고
# 본문 행이 없는 원장은 반드시 non-zero.
case_heading_does_not_satisfy() {
  setup
  write_ledger "$TMP/l.md" gap
  printf '## floor:gap\n\n- floor:gap 이라는 문구가 산문에 등장한다\n' >> "$TMP/l.md"
  run_ledger "$TMP/l.md" && fail "헤딩/산문 언급만으로 gap이 닫힘" \
                         || pass "헤딩·산문 언급은 차원을 닫지 못함 (M8)"
  cleanup
}

# C1 회귀, 양방향: evidence 산문 속 "없음"(흔한 단어)은 모순으로 오판되면 안 되고,
# 진짜 모순(없음 선언 + 명명 derived 공존)은 여전히 잡혀야 한다. 둘째 방향이 없으면
# 모순 검사를 통째로 지우는 fix도 이 테스트를 통과해 버린다.
case_c1_no_false_contradiction() {
  setup
  # 방향 A: 명명 derived의 evidence 안에 "없음"이 등장해도 통과해야 한다.
  write_ledger "$TMP/ok.md" "" '- derived:migration — closed — 스키마 변경 회귀 없음, 양방향 확인 완료'
  run_ledger "$TMP/ok.md" && pass "evidence 속 '없음'은 명명 derived를 모순으로 만들지 않음" \
                          || fail "evidence 속 '없음' 때문에 정상 명명 derived가 red (C1)"

  # 방향 B: 진짜 모순 — `derived: 없음` 선언과 명명 derived가 함께 있으면 non-zero.
  write_ledger "$TMP/bad.md" "" '- derived: 없음 — 이 diff엔 추가 확인 축 없음'
  printf -- '- derived:migration — closed — 스키마 up/down 양방향 확인\n' >> "$TMP/bad.md"
  run_ledger "$TMP/bad.md" && fail "'없음' 선언 + 명명 derived 공존이 통과함 (모순 검사 소실)" \
                           || pass "'없음' 선언 + 명명 derived 공존 → non-zero (진짜 모순은 여전히 잡힘)"
  cleanup
}

# I1: stdin 경로도 UTF-8을 명시해야 한다 — 로케일이 ascii여도 안 깨져야 한다.
# run_ledger()는 항상 파일 인자를 쓰므로 이 테스트는 python3를 직접, stdin으로 호출한다.
case_stdin_utf8_locale_independent() {
  setup; write_ledger "$TMP/l.md"
  if PYTHONIOENCODING=ascii LC_ALL=C python3 "$LEDGER" < "$TMP/l.md" >/dev/null 2>&1; then
    pass "stdin 경로: ascii 로케일에서도 exit 0 (UTF-8 명시)"
  else
    fail "stdin 경로가 로케일 의존 디코딩으로 깨짐 (I1)"
  fi
  cleanup
}

# 같은 floor 차원이 두 번 선언되면 non-zero — 어느 것을 믿을지 불명해지기 때문.
case_duplicate_floor_dimension() {
  setup; write_ledger "$TMP/l.md"
  printf -- '- floor:changed      — degraded — 중복 선언\n' >> "$TMP/l.md"
  run_ledger "$TMP/l.md" && fail "중복 floor 차원 선언이 통과함" \
                         || pass "중복 floor 차원 선언 → non-zero"
  cleanup
}

# 명명 derived의 status가 {closed,degraded} 밖이면 non-zero. 픽스처는 문법을
# 완전히 만족해서 DERIVED_NAMED_RE에 실제로 매치해야 한다 — status/evidence가
# 아예 없는 픽스처는 문법위반 분기로 새서 이 검사 자체에 닿지 못한다.
case_derived_named_bad_status() {
  setup
  write_ledger "$TMP/l.md" "" '- derived:migration — bogus — evidence for migration'
  run_ledger "$TMP/l.md" && fail "out-of-set status인 명명 derived가 통과함" \
                         || pass "명명 derived의 status가 {closed,degraded} 밖 → non-zero"
  cleanup
}

for c in case_complete case_each_missing_dimension case_degraded_is_valid \
         case_unknown_status case_empty_evidence case_derived_reason_required \
         case_derived_named case_heading_does_not_satisfy \
         case_c1_no_false_contradiction case_stdin_utf8_locale_independent \
         case_duplicate_floor_dimension case_derived_named_bad_status; do
  echo "== $c"; $c
done
echo "── qa ledger: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
