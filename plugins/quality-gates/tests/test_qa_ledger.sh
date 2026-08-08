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

# T95 (iter-8 리뷰 #4): 종료 코드가 **인자 모양(2)** 과 **내용(4)** 을 구분한다.
#
# 이 리포의 형제 스크립트가 확립한 규약이다(AC60: "생략 시 exit 2, 빈 값은 exit 4").
# 앞 버전은 둘 다 2 였고, 그러면 "부르는 법을 틀렸다" 와 "읽었는데 믿을 수 없다" 가
# 같은 신호가 된다. 소비자는 어느 쪽이든 PASS 불가로 라우팅하므로 **동작이 아니라
# 진단**을 재는 락이며, 그래서 non-zero 가 아니라 **정확한 코드**를 단언해야 이빨이 있다.
rc_of() { "$@" >/dev/null 2>&1; echo $?; }
case_exit_code_shape_vs_content() {
  setup
  local ok=1
  write_ledger "$TMP/l.md"; write_aggregate "$TMP/a.yaml" closed; write_assign_rows "$TMP/as.tsv"
  # 인자 모양 → 2
  [[ "$(rc_of python3 "$LEDGER" --assign-rows "$TMP/as.tsv" "$TMP/l.md")" == 2 ]] \
    || { echo "    --aggregate 누락이 2 가 아님"; ok=0; }
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows)" == 2 ]] \
    || { echo "    --assign-rows 값 부재가 2 가 아님"; ok=0; }
  # 내용 → 4
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/nope.yaml" --assign-rows "$TMP/as.tsv" "$TMP/l.md")" == 4 ]] \
    || { echo "    집계 파일 부재가 4 가 아님"; ok=0; }
  printf 'adapters: [pytest]\n' > "$TMP/a0.yaml"
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/a0.yaml" --assign-rows "$TMP/as.tsv" "$TMP/l.md")" == 4 ]] \
    || { echo "    attribution_status 0개가 4 가 아님"; ok=0; }
  printf 'tests/test_a.py\tunittest\n' > "$TMP/asbad.tsv"
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/asbad.tsv" "$TMP/l.md")" == 4 ]] \
    || { echo "    배정 3필드 위반이 4 가 아님"; ok=0; }
  # 원장 자신의 read 경로도 같은 축 — 비-UTF-8 은 트레이스백이 아니라 4 다.
  printf '\xff\xfe not utf-8\n' > "$TMP/bad.md"
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/as.tsv" "$TMP/bad.md")" == 4 ]] \
    || { echo "    비-UTF-8 원장이 4 가 아님 (UnicodeDecodeError ⊄ OSError 회귀)"; ok=0; }
  # 양의 짝: 구조 위반은 여전히 1 이고, 정상은 0 이다 (전부 non-zero 로 접히지 않았다)
  write_ledger "$TMP/miss.md" gap
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/as.tsv" "$TMP/miss.md")" == 1 ]] \
    || { echo "    구조 위반이 1 이 아님"; ok=0; }
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/as.tsv" "$TMP/l.md")" == 0 ]] \
    || { echo "    정상 입력이 0 이 아님"; ok=0; }
  [[ $ok -eq 1 ]] && pass "종료 코드 4갈래 — 모양 2 · 내용 4 · 구조 1 · 통과 0" \
                  || fail "종료 코드가 축을 구분하지 못함"
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

# T95′ (iter-8 `/qg` 리뷰): 파서 축 4종 — 전부 실측 생존 mutant 를 닫는다.
case_parser_axes() {
  setup
  local ok=1
  write_ledger "$TMP/l.md"; write_aggregate "$TMP/a.yaml" closed; write_assign_rows "$TMP/as.tsv"
  # (SR3) 같은 플래그 반복 → dict 가 마지막 값을 조용히 취해 집행이 꺼진 채 exit 0 이었다.
  printf '' > "$TMP/empty.tsv"
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/a.yaml" \
        --assign-rows "$TMP/as.tsv" --assign-rows "$TMP/empty.tsv" "$TMP/l.md")" == 2 ]] \
    || { echo "    --assign-rows 중복이 2 가 아님 (마지막 값이 조용히 이긴다)"; ok=0; }
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/a.yaml" --aggregate "$TMP/a.yaml" \
        --assign-rows "$TMP/as.tsv" "$TMP/l.md")" == 2 ]] \
    || { echo "    --aggregate 중복이 2 가 아님"; ok=0; }
  # (G4) **4필드** 행 — unit 경로에 탭이 들면 unclaimed 가 fields[1] 밖으로 밀려난다.
  #      `!= 3` 을 `< 3` 으로 완화하면 그 행이 조용히 미집계되어 rc 4 → rc 0 (진짜 PASS 유출).
  # ★ fields[2] 가 **정상 granularity** 여야 이 축이 격리된다. `unclaimed` 을 3번째에 두면
  #   granularity 검사가 먼저 잡아 `< 3` mutant 가 생존한다(실측: 이 케이스가 엉뚱한 이유로
  #   통과했다) — 두 검사가 같은 입력을 덮으면 뒤엣것의 이빨을 앞엣것이 가린다.
  printf 'spec/a\tb\tfile\tunclaimed\n' > "$TMP/as4.tsv"
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/as4.tsv" "$TMP/l.md")" == 4 ]] \
    || { echo "    4필드 행(granularity 는 정상)이 4 가 아님 — 길이 축이 격리되지 않았다"; ok=0; }
  # 현실적 형태(unit 경로에 탭) 도 함께 — 이쪽은 granularity 검사가 잡는다(이중 방어).
  printf 'spec/a\tb\tunclaimed\tfile\n' > "$TMP/as4b.tsv"
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/as4b.tsv" "$TMP/l.md")" == 4 ]] \
    || { echo "    unit 경로 탭 형태가 4 가 아님"; ok=0; }
  # (CX4) granularity 는 닫힌 집합 — 러너 이름은 소유자 것이라 검사하지 않는다.
  printf 'tests/a.py\tunittest\tbogus\n' > "$TMP/asg.tsv"
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/asg.tsv" "$TMP/l.md")" == 4 ]] \
    || { echo "    granularity 어휘 밖이 4 가 아님"; ok=0; }
  # 양의 짝: 세 granularity 전부 정상 통과해야 한다 (과차단 방지)
  printf 'tests/a.py\tunittest\tfile\npkg\tgo\tpackage\nBULK\tcargo\tbulk\n' > "$TMP/asok.tsv"
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/asok.tsv" "$TMP/l.md")" == 0 ]] \
    || { echo "    정상 3종 granularity 가 red (과차단)"; ok=0; }
  [[ $ok -eq 1 ]] && pass "파서 축 — 중복 플래그 2 · 4필드 4 · granularity 어휘 4 · 정상 3종 0" \
                  || fail "파서 축 이빨 없음"
  cleanup
}

# T95″ (iter-8 `/qg` 리뷰 G5·G6): 미커버였던 반환 지점 3개 + 세 read 경로의 **음의** 짝.
case_exit_code_remaining_paths() {
  setup
  local ok=1
  write_ledger "$TMP/l.md"; write_aggregate "$TMP/a.yaml" closed; write_assign_rows "$TMP/as.tsv"
  # positional 초과 → 인자 모양 2
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/as.tsv" "$TMP/l.md" "$TMP/l.md")" == 2 ]] \
    || { echo "    positional 초과가 2 가 아님"; ok=0; }
  # 원장 파일 부재(OSError) → 내용 4
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/as.tsv" "$TMP/nope.md")" == 4 ]] \
    || { echo "    원장 파일 부재가 4 가 아님"; ok=0; }
  # stdin 비-UTF-8 → 내용 4
  printf '\xff\xfe x\n' > "$TMP/badstdin"
  if python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/as.tsv" < "$TMP/badstdin" \
       >/dev/null 2>&1; then echo "    비-UTF-8 stdin 이 통과"; ok=0
  else [[ $? -eq 4 ]] || { echo "    비-UTF-8 stdin 이 4 가 아님"; ok=0; }; fi
  # 형제 두 read 경로의 음의 짝 — `UnicodeDecodeError ⊄ OSError` 핸들러를 지우면
  # 트레이스백이 exit 1 을 내고, 1 은 이 스크립트의 어휘에서 "구조 위반" 이다(오진).
  # ★ 나쁜 바이트를 **그 밖의 모든 것이 정상인 필드 안에** 넣는다. 앞 버전은 파일 전체를
  #   `\xff\xfe not utf-8` 로 채웠는데, 그러면 핸들러를 지우고 `errors="replace"` 로 바꿔도
  #   두 픽스처가 **다른 이유로** 4 를 냈다 — 대체문자 텍스트에는 `attribution_status` 줄이
  #   0개이고(→4) 필드가 3개가 아니다(→4). 즉 하류 검사가 시험 대상을 가려 **스위트가
  #   25/25 GREEN 을 유지한 채** 디코드 실패 자체를 삭제할 수 있었다(실측). 내가 4필드
  #   픽스처에서 방금 고친 masking 과 같은 모양이 옆줄에서 재발한 것이다.
  #   지금 형태는 관대한 디코딩에서 행이 **살아남아** 축을 격리한다: 핸들러 있으면 둘 다 4,
  #   핸들러 우회하면 배정=1(집행 발화)·집계=0 이라 이 assert 가 RED 가 된다.
  printf 'attribution_status: closed\n#\xff\n' > "$TMP/agg_bad.yaml"
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/agg_bad.yaml" --assign-rows "$TMP/as.tsv" "$TMP/l.md")" == 4 ]] \
    || { echo "    비-UTF-8 집계가 4 가 아님 (핸들러 회귀)"; ok=0; }
  printf 'spec/\xff\tunclaimed\tfile\n' > "$TMP/as_bad.tsv"
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/as_bad.tsv" "$TMP/l.md")" == 4 ]] \
    || { echo "    비-UTF-8 배정이 4 가 아님 (핸들러 회귀)"; ok=0; }
  [[ $ok -eq 1 ]] && pass "잔여 반환 지점 3개 + 세 read 경로 음의 짝 전부 정확한 코드" \
                  || fail "반환 지점 커버리지 갭"
  cleanup
}

# §11 ⑭ 경계 핀 (iter-8 `/qg` 리뷰 Q5): **행 0개는 오류가 아니다.**
# 이 케이스가 없으면 "0행 거부" 수정이 스위트를 통과하며 ⑭ 를 조용히 닫는다 —
# 정당한 빈 스코프에서 PASS 가 구조적으로 불가능해진다. 양의 방향으로 못 박는다.
#
# ★ **바이트 모양이 아니라 생산자 출력으로 못 박는다.** 앞 버전은 `: > file`(빈 파일)과
#   공백만 있는 파일이라는 *바이트 모양* 두 개를 고정했다. 그러면 §11 ㉛ 이 문서화한 종결
#   모양(생산자가 행수 포함 완료 선언을 마지막 줄로 낸다)을 **랜딩할 수 없다** — 빈 파일에는
#   terminator 를 붙일 수 없으므로 이 케이스가 구조적으로 RED 가 되고, 그때 가장 싸 보이는
#   수리는 케이스 삭제이며 그것이 ⑭ 를 다시 연다. 실물 생산자에 결합하면 assert 가 생산자
#   변경에 반응하고 기대값(`0`)은 독립 리터럴로 남는다.
#
# ★ **㉛ 랜딩 근거는 거짓이었다 (/qg iter-8 iteration 3, F23 — 실측).** 앞 버전은 "실물
#   생산자에서 뽑으면 ㉛ 이후에도 같은 mutant 가 그대로 죽는다" 고 적었는데, 생산자가
#   `# assign-complete rows=0` 같은 완료 선언을 마지막 줄로 내게 하면 팔 A 의 파일은
#   비지 않게 되고 그 한 줄은 3필드가 아니므로 `check_qa_ledger.py` 가 `exit 4` 를 낸다 —
#   **바이트 픽스처와 똑같이 RED 다.** 랜딩 가능성은 *소비자*가 terminator 를 배우는가에
#   달렸지 픽스처 바이트의 출처에 달려 있지 않다. 재작성이 산 것은 생산자 결합(T97 이
#   실증한다)이고, 광고한 것은 그것이 아니었다.
#
# ★ **전제 가드는 팔 A 와 *같은 입력*을 시험해야 한다 (/qg iter-8 iteration 3, F20).**
#   앞 버전은 **비지 않은** stdin 으로 전제를 확인하고 팔 A 는 **빈** stdin 을 넘겼다.
#   그러면 "빈 입력에서만 죽는 생산자" 는 전제 가드를 통과하고 팔 A 는 0바이트를 얻어
#   `0` 을 만족한다 — 시체를 시험하지 않겠다는 가드가 정확히 그 시체를 통과시킨다.
#   이제 팔 A 자신의 종료코드를 잡아 `0` 을 요구한다(실측: 빈 stdin 에서 `assign` 은
#   rc 0 · 0바이트라 위양성 없음). 비지 않은 입력 확인은 *다른 축*(생산자가 애초에 행을
#   낼 줄 아는가)이므로 남겨 둔다.
case_zero_rows_is_not_an_error() {
  setup
  local ok=1 sel="$PLUGIN_ROOT/scripts/run-test-selection.sh" a0rc=0
  mkdir -p "$TMP/wt/tests" "$TMP/other/tests"
  write_ledger "$TMP/l.md"; write_aggregate "$TMP/a.yaml" closed
  # 전제 가드 ① — 같은 호출 모양이 비지 않은 입력에서는 행을 낸다.
  printf '../other/tests/evil.sh\n' | bash "$sel" assign "$TMP/wt" > "$TMP/one.tsv" 2>/dev/null
  [[ -s "$TMP/one.tsv" ]] \
    || { echo "    같은 호출 모양이 비지 않은 입력에도 행 0개 (픽스처 전제 붕괴)"; ok=0; }
  # 팔 A — 빈 후보 목록을 실물 생산자에 통과시킨 출력
  : | bash "$sel" assign "$TMP/wt" > "$TMP/as0.tsv" 2>/dev/null || a0rc=$?
  # 전제 가드 ② — 그 호출이 **완주**했다. 0바이트가 "빈 결과" 인지 "죽은 생산자" 인지
  #               가르는 것은 이 종료코드뿐이다.
  [[ "$a0rc" == 0 ]] \
    || { echo "    빈 입력에서 생산자가 rc=$a0rc 로 죽음 — 팔 A 가 시체를 시험하고 있다"; ok=0; }
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/as0.tsv" "$TMP/l.md")" == 0 ]] \
    || { echo "    0행 배정이 red — §11 ⑭(빈 스코프)를 이 인자가 닫아 버렸다"; ok=0; }
  # 팔 B — 같은 출력 + 앞뒤 빈 줄. `check_qa_ledger.py` 의 빈 줄 skip 을 잰다.
  #        (T97 은 *후행* 개행만 덮는다 — `"a\tb\tc\n".split("\n")` 의 마지막 `""`.)
  { printf '\n'; cat "$TMP/as0.tsv"; printf '\n   \n'; } > "$TMP/asblank.tsv"
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/asblank.tsv" "$TMP/l.md")" == 0 ]] \
    || { echo "    빈 줄이 섞인 배정이 red (빈 줄 skip 회귀)"; ok=0; }
  [[ $ok -eq 1 ]] && pass "실물 생산자의 0행 출력·빈 줄 혼입 → exit 0 (§11 ⑭ 는 이 인자의 축이 아니다)" \
                  || fail "빈 스코프 축이 침범됨"
  cleanup
}

# T97 (iter-8 `/qg` 리뷰 H7): **생산자-소비자 계약**을 처음으로 잠근다.
# 지금까지 픽스처는 포맷을 손으로 다시 써서 *픽스처 작성자의 이해*를 검증했다. `unclaimed`
# 토큰이나 필드 순서가 한쪽에서만 바뀌면 개수는 조용히 0 이 되고 모든 락이 GREEN 을 유지한다
# (드리프트 방향이 fail-open). 실물 `assign` stdout 을 그대로 소비자에 먹인다.
case_producer_consumer_contract() {
  setup
  local ok=1 sel="$PLUGIN_ROOT/scripts/run-test-selection.sh"
  mkdir -p "$TMP/wt/tests" "$TMP/other/tests"
  # 워크트리 **밖** 경로는 어떤 어댑터의 소유도 아니다 → 결정론적으로 unclaimed 행이 나온다.
  #
  # ★ **흡수자가 있는 트리로 잰다 (/qg iter-8 iteration 3, F24).** README 는 담김 거부가
  #   bulk 흡수자 분기보다 **앞선다**고 주장하고, "흡수자가 있는 레포에서 이 검사가 죽은
  #   무게라고 결론짓지 말 것 — 가장 위험한 클래스가 바로 그 축" 이라고 적는다. 그런데
  #   스위트의 담김 픽스처는 전부 흡수자가 없는 셸 어댑터 트리였다. 그러면 거부를 흡수
  #   분기 **뒤로** 옮기는 편집이 스위트를 통째로 초록으로 통과하고 그 README 주장만
  #   조용히 거짓이 된다(안심시키는 방향). `Cargo.toml` + `Makefile` 로 bulk 흡수자를
  #   세워 그 주장이 실제로 측정되게 한다.
  : > "$TMP/wt/Cargo.toml"
  : > "$TMP/wt/Makefile"
  printf '../other/tests/evil.sh\n' | bash "$sel" assign "$TMP/wt" > "$TMP/real.tsv" 2>/dev/null
  grep -q 'unclaimed' "$TMP/real.tsv" \
    || { echo "    실물 assign 이 unclaimed 행을 내지 않음 (픽스처 전제 붕괴)"; ok=0; }
  write_ledger "$TMP/l.md"; write_aggregate "$TMP/a.yaml" closed
  # 원장은 verification=closed → 집행이 발화해야 한다 (exit 1)
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/real.tsv" "$TMP/l.md")" == 1 ]] \
    || { echo "    실물 assign 출력에 집행이 발화하지 않음 (생산자-소비자 계약 드리프트)"; ok=0; }
  # exit 1 은 "구조 위반" 전반의 코드라 *어떤* 오류인지는 못 가른다. stderr 로 축을 고정한다.
  python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/real.tsv" "$TMP/l.md" 2>&1 \
    | grep -q 'unclaimed' \
    || { echo "    exit 1 이 unclaimed 집행이 아닌 다른 구조 위반에서 왔다"; ok=0; }
  # 양의 짝: 같은 실물 출력 + degraded 원장 → 통과
  grep -vF 'floor:verification' "$TMP/l.md" > "$TMP/ld.md"
  printf -- '- floor:verification — degraded — unclaimed 1건, 실행 수단 없음\n' >> "$TMP/ld.md"
  [[ "$(rc_of python3 "$LEDGER" --aggregate "$TMP/a.yaml" --assign-rows "$TMP/real.tsv" "$TMP/ld.md")" == 0 ]] \
    || { echo "    실물 출력 + degraded 가 red"; ok=0; }
  [[ $ok -eq 1 ]] && pass "실물 assign stdout → 소비자: 집행 발화(1) · degraded 원장 통과(0)" \
                  || fail "생산자-소비자 계약 미잠금"
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
         case_assign_rows_is_mandatory_and_fail_closed \
         case_exit_code_shape_vs_content case_parser_axes \
         case_exit_code_remaining_paths case_zero_rows_is_not_an_error \
         case_producer_consumer_contract; do
  echo "== $c"; $c
done
echo "── qa ledger: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
