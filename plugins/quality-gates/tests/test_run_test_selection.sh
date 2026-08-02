#!/usr/bin/env bash
# test_run_test_selection.sh — assign/run 서브커맨드 (design §5.4).
# AC9 AC39 AC40 AC46 AC52 AC54 AC56(run) · T7 T35 T36a T43 T50 T52 T54(run) · M10 M16 M26
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RTS="$PLUGIN_ROOT/scripts/run-test-selection.sh"
TAB=$'\t'

PASS=0; FAIL=0; W=""
pass() { PASS=$((PASS + 1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }
mkw()  { W=$(mktemp -d) || exit 1; }
rmw()  { cd / && rm -rf "$W"; }

# ── assign ──────────────────────────────────────────────────────────────────

# T50 + M26: go 픽스처 — 파일 경로가 패키지 디렉토리로 축약되고 중복이 제거된다.
# 동종(file-granularity) 레포에서는 배정을 모델이 해도 결과가 같아 이 결함을 못 잡는다.
case_assign_go_package() {
  mkw; printf 'module x\n' > "$W/go.mod"
  mkdir -p "$W/pkg/a" "$W/pkg/b"
  : > "$W/pkg/a/one_test.go"; : > "$W/pkg/a/two_test.go"; : > "$W/pkg/b/three_test.go"
  local out; out=$(printf 'pkg/a/one_test.go\npkg/a/two_test.go\npkg/b/three_test.go\n' \
                   | bash "$RTS" assign "$W" | sort | tr '\n' ';')
  if [[ "$out" == "pkg/a${TAB}go${TAB}package;pkg/b${TAB}go${TAB}package;" ]]; then
    pass "go: 3파일 → 2패키지 unit (중복 제거)"
  else fail "go assign (got: $out)"; fi
  rmw
}

# T43 + AC46: 어느 어댑터도 주장하지 않는 unit → unclaimed (조용한 누락 0)
case_assign_unclaimed() {
  mkw; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"     # unittest만 감지됨
  local out; out=$(printf 'tests/test_a.py\nspec/foo_spec.rb\n' \
                   | bash "$RTS" assign "$W" | sort | tr '\n' ';')
  if [[ "$out" == "spec/foo_spec.rb${TAB}unclaimed${TAB}file;tests/test_a.py${TAB}unittest${TAB}file;" ]]; then
    pass "미주장 파일 → unclaimed 행"
  else fail "unclaimed (got: $out)"; fi
  rmw
}

# T52 + AC54: bulk 어댑터 복수 감지 → 첫 하나만 흡수, 나머지는 stderr `미실행 러너`
case_assign_bulk_conflict() {
  mkw
  printf '[package]\nname="x"\n' > "$W/Cargo.toml"
  printf 'test:\n\t@true\n' > "$W/Makefile"
  local out err
  out=$(printf 'src/lib.rs\nsrc/other.rs\n' | bash "$RTS" assign "$W" 2>"$W/err.txt")
  err=$(cat "$W/err.txt")
  if [[ "$out" == "BULK${TAB}cargo${TAB}bulk" ]] && printf '%s' "$err" | grep -q '미실행 러너: make'; then
    pass "cargo+make → cargo 1행 흡수 + make는 미실행 러너로 loud"
  else fail "bulk 충돌 (out='$out' err='$err')"; fi
  rmw
}

# 잔여 흡수자가 없으면(bulk 어댑터 미감지) 잔여는 unclaimed다 — 조용히 버리지 않는다.
case_assign_residual_no_absorber() {
  mkw; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"
  local out; out=$(printf 'src/main.rs\n' | bash "$RTS" assign "$W")
  [[ "$out" == "src/main.rs${TAB}unclaimed${TAB}file" ]] \
    && pass "흡수자 없음 → 잔여는 unclaimed" || fail "잔여 (got: $out)"
  rmw
}

# ── run ─────────────────────────────────────────────────────────────────────

mk_shell_repo() {   # 통과 1 + 실패 1 셸 테스트
  mkw; mkdir -p "$W/tests"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$W/tests/ok.sh";  chmod +x "$W/tests/ok.sh"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$W/tests/bad.sh"; chmod +x "$W/tests/bad.sh"
}

# T7 + M10 + AC9: 테스트 실패(exit 0 + `fail`)와 러너 부재(exit 3)가 **분리**된다
case_run_test_failure_vs_absent_runner() {
  mk_shell_repo
  local out rc
  out=$(bash "$RTS" run "$W" shell per-unit tests/ok.sh tests/bad.sh 2>/dev/null); rc=$?
  if [[ $rc -eq 0 ]] \
     && printf '%s\n' "$out" | grep -q "^tests/ok\.sh${TAB}pass${TAB}0$" \
     && printf '%s\n' "$out" | grep -q "^tests/bad\.sh${TAB}fail${TAB}1$"; then
    pass "테스트 실패 → exit 0 + status=fail"
  else fail "테스트 실패 분리 (rc=$rc out='$out')"; fi

  # 같은 트리에서 감지되지 않는 러너 → exit 3 + 전 unit unrun (T54 run 절반, AC56)
  out=$(bash "$RTS" run "$W" cargo bulk BULK 2>/dev/null); rc=$?
  if [[ $rc -eq 3 && "$out" == "BULK${TAB}unrun${TAB}-" ]]; then
    pass "어댑터 사용 불가 → exit 3 + 전 unit unrun"
  else fail "exit 3 (rc=$rc out='$out')"; fi
  rmw
}

# T35 + M16: **총 함수** — 입력 unit 수 == 출력 행 수 (정상 / exit 3 / 일부 absent)
case_run_total_function() {
  mk_shell_repo
  local n
  n=$(bash "$RTS" run "$W" shell per-unit tests/ok.sh tests/bad.sh tests/gone.sh 2>/dev/null \
      | wc -l | tr -d ' ')
  [[ "$n" == "3" ]] && pass "정상+absent 혼합: 3 입력 → 3 행" || fail "총 함수 정상 ($n)"
  n=$(bash "$RTS" run "$W" cargo bulk A B C 2>/dev/null | wc -l | tr -d ' ')
  [[ "$n" == "3" ]] && pass "exit 3: 3 입력 → 3 unrun 행" || fail "총 함수 exit3 ($n)"
  rmw
}

# T36a + AC40: 상태 5종 중 absent — 워크트리에 없는 unit
case_run_absent() {
  mk_shell_repo
  local out; out=$(bash "$RTS" run "$W" shell per-unit tests/gone.sh 2>/dev/null)
  [[ "$out" == "tests/gone.sh${TAB}absent${TAB}-" ]] \
    && pass "부재 unit → absent" || fail "absent (got: $out)"
  rmw
}

# AC10 지원: bulk green → 전 unit이 pass 행 (호출자가 per-unit 재실행을 건너뛸 근거)
case_run_bulk_green() {
  mk_shell_repo
  rm "$W/tests/bad.sh"
  cp "$W/tests/ok.sh" "$W/tests/ok2.sh"
  local out passes
  out=$(bash "$RTS" run "$W" shell bulk tests/ok.sh tests/ok2.sh 2>/dev/null)
  passes=$(printf '%s\n' "$out" | grep -c "${TAB}pass${TAB}0$")
  [[ "$passes" == "2" ]] && pass "bulk green → 전 unit pass 행" || fail "bulk green ($out)"
  rmw
}

for c in case_assign_go_package case_assign_unclaimed case_assign_bulk_conflict \
         case_assign_residual_no_absorber case_run_test_failure_vs_absent_runner \
         case_run_total_function case_run_absent case_run_bulk_green; do
  echo "== $c"; $c
done
echo "── run-test-selection: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
