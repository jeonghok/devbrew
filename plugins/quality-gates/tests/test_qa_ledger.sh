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

# 집계 YAML 을 쓴다 — `--aggregate` 가 필수가 된 뒤로 모든 호출에 하나가 필요하다.
write_aggregate() {   # write_aggregate <file> [attribution_status]
  printf 'adapters: [pytest]\nverdict_input:\n  confirmed_product_defect: false\n  silent_drop: false\n  baseline_unrunnable: false\nattribution_status: %s\n' \
    "${2:-closed}" > "$1"
}

# 배정 TSV 를 쓴다 — `--assign-rows` 가 필수가 된 뒤로 모든 호출에 하나가 필요하다.
# $2 는 unclaimed 행 수(기본 0). claim 된 행은 항상 하나 넣는다: 빈 파일은 "배정 0건"
# 이라는 **다른 축**(§11 ⑭)이라 기본 픽스처로 쓰면 케이스가 그 축에 얹힌다.
write_assign_rows() {   # write_assign_rows <file> [unclaimed-count]
  local f=$1 n=${2:-0} i
  printf 'tests/test_a.py\tunittest\tfile\n' > "$f"
  for ((i = 1; i <= n; i++)); do
    printf 'spec/foo_%d_spec.rb\tunclaimed\tfile\n' "$i" >> "$f"
  done
}

# 기본 러너. 기존 케이스들의 원장은 `floor:attribution` 을 `closed` 로 쓰므로 집계도
# `closed` 로 맞춘다 — 전사 대조를 *통과*시켜 두어야, 그 케이스들이 재려던 축(누락·
# 문법·모순)이 계속 그 축에서 판정된다. 안 맞추면 전부 exit 2 로 죽어 **음성 케이스가
# 엉뚱한 이유로 통과**하는 위양성이 된다. `--assign-rows` 도 같은 이유로 unclaimed
# 0건을 기본으로 쓴다 — 원장의 `verification` 이 `closed` 이므로 집행이 발화하면 안 된다.
run_ledger() {
  write_aggregate "$TMP/agg.yaml"
  write_assign_rows "$TMP/assign.tsv"
  python3 "$LEDGER" --aggregate "$TMP/agg.yaml" --assign-rows "$TMP/assign.tsv" "$1" \
    >/dev/null 2>&1
}

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
  # 집계 YAML 에도 한글을 넣는다 — 이 파일은 `--aggregate` 가 필수가 되면서 새로 생긴
  # **두 번째 read 경로**이고, 여기서 encoding 을 빠뜨리면 non-UTF-8 로케일에서만
  # 깨지는 같은 결함이 재입장한다. ASCII 전용 픽스처는 그 축을 지나가지 않는다.
  printf '# 어댑터 집계 (한글 주석 — 로케일 독립 read 검사용)\nadapters: [pytest]\nattribution_status: closed\n' \
    > "$TMP/agg_ko.yaml"
  # 배정 TSV 도 같은 이유로 한글을 담는다 — `--assign-rows` 는 **세 번째 read 경로**이고,
  # 여기서 encoding 을 빠뜨리면 non-UTF-8 로케일에서만 깨지는 같은 결함이 재입장한다.
  printf '테스트/한글_test.py\tunittest\tfile\n' > "$TMP/assign_ko.tsv"
  if PYTHONIOENCODING=ascii LC_ALL=C python3 "$LEDGER" \
       --aggregate "$TMP/agg_ko.yaml" --assign-rows "$TMP/assign_ko.tsv" \
       < "$TMP/l.md" >/dev/null 2>&1; then
    pass "stdin·집계·배정 세 read 경로: ascii 로케일에서도 exit 0 (UTF-8 명시)"
  else
    fail "read 경로가 로케일 의존 디코딩으로 깨짐 (I1)"
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

# T90 + AC66 (§11 ⑱ = 라운드 6·7 의 U3): 기계 집계값 ↔ 원장 전사값 대조.
#
# 닫는 fail-open: R8 은 R6 이 낸 `attribution_status` 를 **모델이 원장에 옮겨 적게**
# 하는데, `degraded` 를 `closed` 로 옮기면 floor 5차원이 전부 `closed` 가 되어 PASS 행을
# 그대로 만족시킨다. 이 게이트가 두 값을 대조하는 것이 유일한 집행자다.
#
# 이빨 설계 — **양방향 + 양의 짝**. 단방향(불일치→red)만 재면 "언제나 red" 로 만드는
# 변경이 통과하고, 양의 짝(일치→green) 없이는 대조를 통째로 지운 변경도 통과한다.
case_transcription_matches_machine() {
  setup
  local ok=1
  # 이 케이스가 재는 축은 **전사**뿐이다 — 배정은 unclaimed 0건으로 고정해 ㉓ 집행이
  # 발화하지 않게 둔다. 안 그러면 두 축이 섞여 어느 쪽이 red 를 냈는지 못 가른다.
  write_assign_rows "$TMP/as.tsv"
  # 양의 짝 ①: closed/closed → 통과 (대조가 코퍼스를 읽고 같다고 판정한다)
  write_ledger "$TMP/l.md"; write_aggregate "$TMP/a.yaml" closed
  python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/as.tsv" "$TMP/l.md" \
    >/dev/null 2>&1 || { echo "    일치(closed/closed)가 red"; ok=0; }
  # 양의 짝 ②: degraded/degraded → 통과. `degraded` 는 1급 상태이지 실패가 아니다.
  grep -vF 'floor:attribution' "$TMP/l.md" > "$TMP/ld.md"
  printf -- '- floor:attribution — degraded — 귀속 불가 1건\n' >> "$TMP/ld.md"
  write_aggregate "$TMP/ad.yaml" degraded
  python3 "$LEDGER" --aggregate "$TMP/ad.yaml" --assign-rows "$TMP/as.tsv" "$TMP/ld.md" \
    >/dev/null 2>&1 || { echo "    일치(degraded/degraded)가 red"; ok=0; }
  # 음 ①: 위험 방향 — 기계는 degraded 인데 원장은 closed (PASS 로 새는 방향)
  python3 "$LEDGER" --aggregate "$TMP/ad.yaml" --assign-rows "$TMP/as.tsv" "$TMP/l.md" \
    >/dev/null 2>&1 && { echo "    기계 degraded → 원장 closed 가 통과함 (PASS 유출)"; ok=0; }
  # 음 ②: 반대 방향도 잡는다 — 한 방향만 잡으면 '언제나 closed 를 기대' 로 퇴화한다
  python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/as.tsv" "$TMP/ld.md" \
    >/dev/null 2>&1 && { echo "    기계 closed → 원장 degraded 가 통과함"; ok=0; }
  [[ $ok -eq 1 ]] && pass "전사 대조 — 양방향 불일치 red · 양의 짝 2종 green" \
                  || fail "전사 대조 이빨 없음"
  cleanup
}

# 대조 입력이 없거나 못 믿을 때는 **통과가 아니다** (fail-closed).
case_aggregate_is_mandatory_and_fail_closed() {
  setup
  write_ledger "$TMP/l.md"
  write_assign_rows "$TMP/as.tsv"
  local ok=1
  python3 "$LEDGER" --assign-rows "$TMP/as.tsv" "$TMP/l.md" >/dev/null 2>&1 \
    && { echo "    --aggregate 없이 통과함 (조용한 면제)"; ok=0; }
  python3 "$LEDGER" --aggregate "$TMP/nope.yaml" --assign-rows "$TMP/as.tsv" "$TMP/l.md" \
    >/dev/null 2>&1 && { echo "    집계 파일 부재인데 통과함"; ok=0; }
  printf 'adapters: [pytest]\n' > "$TMP/a0.yaml"
  python3 "$LEDGER" --aggregate "$TMP/a0.yaml" --assign-rows "$TMP/as.tsv" "$TMP/l.md" \
    >/dev/null 2>&1 && { echo "    attribution_status 0개인데 통과함"; ok=0; }
  # 2개 이상도 거부한다 — 첫 매치만 보면 원하는 값을 앞에 덧붙여 대조를 우회할 수 있다.
  # 원장은 이 케이스가 만든 `$TMP/l.md` 를 쓴다. 다른 케이스의 파일을 참조하면
  # `cleanup` 뒤라 **파일 부재로 non-zero** 가 나서 이 assert 가 엉뚱한 이유로 통과한다.
  printf 'attribution_status: closed\nattribution_status: degraded\n' > "$TMP/a2.yaml"
  python3 "$LEDGER" --aggregate "$TMP/a2.yaml" --assign-rows "$TMP/as.tsv" "$TMP/l.md" \
    >/dev/null 2>&1 && { echo "    attribution_status 2개인데 통과함"; ok=0; }
  [[ $ok -eq 1 ]] && pass "대조 입력 부재·불량 4종 → 전부 non-zero (fail-closed)" \
                  || fail "대조 입력 fail-open"
  cleanup
}

# T93 + AC68 (§11 ㉓): `unclaimed` → `verification: degraded` 를 기계가 집행한다.
#
# 닫는 fail-open: `assign` 의 구조적 거부 3곳이 낳는 `unclaimed` unit 은 어느 어댑터의
# 목록에도 없어 `--expected` 에 안 들어가므로 `SILENT_DROP` 백스톱조차 닿지 않는다.
# 그 상태로 5차원 `closed` 를 적으면 **한 번도 안 돈 unit 을 두고 PASS** 가 된다.
#
# 이빨 설계 — 위험 방향(음) + 양의 짝 2종 + fail-closed 1종. 양의 짝이 없으면
# "언제나 red" 로 만드는 변경이, 0건 짝이 없으면 "언제나 degraded 요구" 가 통과한다.
case_unclaimed_forces_degraded() {
  setup
  local ok=1
  write_ledger "$TMP/l.md"                       # verification = closed
  grep -vF 'floor:verification' "$TMP/l.md" > "$TMP/ldeg.md"
  printf -- '- floor:verification — degraded — unclaimed 2건, 실행 수단 없음\n' >> "$TMP/ldeg.md"
  write_aggregate "$TMP/a.yaml" closed
  write_assign_rows "$TMP/as0.tsv" 0
  write_assign_rows "$TMP/as2.tsv" 2

  # 음: unclaimed 2건 + verification closed → non-zero (이것이 닫는 유출 경로)
  python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/as2.tsv" "$TMP/l.md" \
    >/dev/null 2>&1 && { echo "    unclaimed 2건인데 verification closed 가 통과함"; ok=0; }
  # 양 ①: unclaimed 2건 + verification degraded → 통과 (규칙을 지킨 원장은 green)
  python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/as2.tsv" "$TMP/ldeg.md" \
    >/dev/null 2>&1 || { echo "    unclaimed 2건 + degraded 가 red"; ok=0; }
  # 양 ②: unclaimed 0건 + verification closed → 통과 (과차단 방지 — 이게 정상 실행이다)
  python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/as0.tsv" "$TMP/l.md" \
    >/dev/null 2>&1 || { echo "    unclaimed 0건인데 closed 가 red (과차단)"; ok=0; }
  # fail-closed: 셀 수 없는 입력을 "0건" 으로 접지 않는다 (3필드 위반 → 사용 오류)
  printf 'tests/test_a.py\tunittest\n' > "$TMP/asbad.tsv"
  python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/asbad.tsv" "$TMP/l.md" \
    >/dev/null 2>&1 && { echo "    문법 위반 배정 행이 통과함 (셀 수 없는데 0건 취급)"; ok=0; }
  [[ $ok -eq 1 ]] && pass "unclaimed 집행 — 유출 방향 red · 양의 짝 2종 green · 불량 입력 fail-closed" \
                  || fail "unclaimed 집행 이빨 없음"
  cleanup
}

# `--assign-rows` 자체가 조용히 면제되면 위 집행은 존재하지 않는 것과 같다.
case_assign_rows_is_mandatory_and_fail_closed() {
  setup
  write_ledger "$TMP/l.md"; write_aggregate "$TMP/a.yaml" closed
  local ok=1
  python3 "$LEDGER" --aggregate "$TMP/a.yaml" "$TMP/l.md" >/dev/null 2>&1 \
    && { echo "    --assign-rows 없이 통과함 (조용한 면제)"; ok=0; }
  python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/nope.tsv" "$TMP/l.md" \
    >/dev/null 2>&1 && { echo "    배정 파일 부재인데 통과함"; ok=0; }
  python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows >/dev/null 2>&1 \
    && { echo "    --assign-rows 값 없이 통과함"; ok=0; }
  [[ $ok -eq 1 ]] && pass "--assign-rows 부재·파일부재·값부재 → 전부 non-zero (fail-closed)" \
                  || fail "--assign-rows fail-open"
  cleanup
}

for c in case_complete case_each_missing_dimension case_degraded_is_valid \
         case_unknown_status case_empty_evidence case_derived_reason_required \
         case_derived_named case_heading_does_not_satisfy \
         case_c1_no_false_contradiction case_stdin_utf8_locale_independent \
         case_duplicate_floor_dimension case_derived_named_bad_status \
         case_transcription_matches_machine \
         case_aggregate_is_mandatory_and_fail_closed \
         case_unclaimed_forces_degraded \
         case_assign_rows_is_mandatory_and_fail_closed; do
  echo "== $c"; $c
done
echo "── qa ledger: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
