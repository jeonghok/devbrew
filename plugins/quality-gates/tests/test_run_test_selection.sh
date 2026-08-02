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

# 경로 밖 실행 스크립트는 shell 이 주장하지 않는다 — 주장하면 run 이 그것을 실행한다.
case_assign_shell_scope_excludes_non_test() {
  mkw; mkdir -p "$W/tests" "$W/scripts"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$W/tests/t.sh";       chmod +x "$W/tests/t.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$W/scripts/deploy.sh"; chmod +x "$W/scripts/deploy.sh"
  local out; out=$(printf 'tests/t.sh\nscripts/deploy.sh\n' | bash "$RTS" assign "$W" | sort | tr '\n' ';')
  if [[ "$out" == "scripts/deploy.sh${TAB}unclaimed${TAB}file;tests/t.sh${TAB}shell${TAB}file;" ]]; then
    pass "tests/ 밖 실행 스크립트 → unclaimed (shell 미주장)"
  else fail "shell 스코프 (got: $out)"; fi
  rmw
}

# 중첩된 tests/ 는 여전히 주장한다 — 스코프를 좁히다 정당한 대상을 놓치면 안 된다.
case_assign_shell_scope_includes_nested() {
  mkw; mkdir -p "$W/pkg/tests"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$W/pkg/tests/t.sh"; chmod +x "$W/pkg/tests/t.sh"
  local out; out=$(printf 'pkg/tests/t.sh\n' | bash "$RTS" assign "$W")
  [[ "$out" == "pkg/tests/t.sh${TAB}shell${TAB}file" ]] \
    && pass "중첩 tests/ 실행 스크립트 → shell" || fail "중첩 tests/ (got: $out)"
  rmw
}

# 중복 stdin 입력 (claimed file 축약) → 한 unit 행으로 수렴한다.
case_assign_dedup_claimed_file() {
  mkw; mkdir -p "$W/tests"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$W/tests/t.sh"; chmod +x "$W/tests/t.sh"
  local out; out=$(printf 'tests/t.sh\ntests/t.sh\n' | bash "$RTS" assign "$W")
  [[ "$out" == "tests/t.sh${TAB}shell${TAB}file" ]] \
    && pass "중복 stdin (claimed) → unit 행 1개" || fail "중복 claimed (got: $out)"
  rmw
}

# 중복 stdin 입력 (unclaimed) → 한 unit 행으로 수렴한다.
case_assign_dedup_unclaimed() {
  mkw; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"   # unittest만 감지 — .rb는 미주장
  local out; out=$(printf 'spec/foo_spec.rb\nspec/foo_spec.rb\n' | bash "$RTS" assign "$W")
  [[ "$out" == "spec/foo_spec.rb${TAB}unclaimed${TAB}file" ]] \
    && pass "중복 stdin (unclaimed) → unit 행 1개" || fail "중복 unclaimed (got: $out)"
  rmw
}

# 정규식 메타문자가 든 경로가 서로 다른 unit 으로 남는가 — dedup 이 grep 패턴으로
# 비교하면 `a.sh` 가 `axsh` 를 삼켜 후자가 조용히 사라진다. 조용한 누락은 이 스크립트가
# 막으라고 있는 바로 그 실패다.
case_assign_dedup_is_literal_not_regex() {
  mkw; mkdir -p "$W/tests"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$W/tests/a.sh";  chmod +x "$W/tests/a.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$W/tests/axsh";  chmod +x "$W/tests/axsh"
  : > "$W/tests/test_keep.py"
  # 순서가 핵심: 점 없는 경로("axsh")가 먼저 seen_files 에 들어가야, 점 있는 경로("a.sh")를
  # 나중에 PATTERN 으로 grep -qx 검사할 때 "."가 "x" 를 와일드카드 매치해 오탐이 난다.
  # 반대 순서(a.sh 먼저)는 이 결함을 통과시키지 못한다 — 이 순서로 mutation-확인했다.
  local out; out=$(printf 'tests/axsh\ntests/a.sh\n' | bash "$RTS" assign "$W" | sort | tr '\n' ';')
  if [[ "$out" == "tests/a.sh${TAB}shell${TAB}file;tests/axsh${TAB}unclaimed${TAB}file;" ]]; then
    pass "메타문자 경로가 서로를 삼키지 않는다 (literal dedup)"
  else fail "dedup literal (got: $out)"; fi
  rmw
}

# 설계 §5.4 표는 jest/vitest 소유를 `*.test.[jt]sx?` / `*.spec.*` 로 쓴다 — .spec. 뒤는
# 확장자 무관. 순수 ESM Vitest 레포의 foo.spec.mjs 가 unclaimed 로 떨어지면 verification 이
# 이유 없이 degraded 가 되어 PASS 를 막는다.
case_assign_spec_any_extension() {
  mkw; printf '{"devDependencies":{"vitest":"1"}}' > "$W/package.json"
  local out; out=$(printf 'src/foo.spec.mjs\n' | bash "$RTS" assign "$W")
  [[ "$out" == "src/foo.spec.mjs${TAB}vitest${TAB}file" ]] \
    && pass ".spec.mjs → vitest (설계 표의 *.spec.*)" || fail "spec 확장자 (got: $out)"
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

# 실행 지점의 방어: assign 을 우회해 임의 경로를 넘겨도 shell 어댑터는 그것을 실행하지
# 않는다. 설계 §5.9 "임의 명령을 추측해 실행하지 않는다".
case_run_shell_refuses_out_of_scope_unit() {
  mkw; mkdir -p "$W/tests" "$W/scripts"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$W/tests/ok.sh"; chmod +x "$W/tests/ok.sh"
  printf '#!/usr/bin/env bash\ntouch PWNED\nexit 0\n' > "$W/scripts/deploy.sh"
  chmod +x "$W/scripts/deploy.sh"
  local out; out=$(bash "$RTS" run "$W" shell per-unit scripts/deploy.sh 2>/dev/null)
  if [[ "$out" == "scripts/deploy.sh${TAB}unrun${TAB}-" && ! -e "$W/PWNED" ]]; then
    pass "스코프 밖 unit → 실행 거부 + unrun (부작용 없음)"
  else fail "실행 거부 (out='$out', PWNED=$([[ -e "$W/PWNED" ]] && echo yes || echo no))"; fi
  rmw
}

# die() 가 $(...) 안에서 삼켜지는 문제 (Task 2 리뷰) — <runner> 는 여기서 CLI 인자라
# 도달 가능하다. 캡처-후-체크가 없으면 잘못된 runner 이름이 exit 2 대신 빈 gran으로
# 조용히 흘러 이후 case 문에서 아무 분기도 안 타는 malformed 출력이 된다.
case_run_unknown_runner_usage_error() {
  mkw
  local rc; bash "$RTS" run "$W" bogus-runner bulk X >/dev/null 2>&1; rc=$?
  [[ $rc -eq 2 ]] && pass "알 수 없는 runner → exit 2 (usage)" || fail "unknown runner exit (rc=$rc)"
  rmw
}

for c in case_assign_go_package case_assign_unclaimed case_assign_bulk_conflict \
         case_assign_residual_no_absorber case_assign_shell_scope_excludes_non_test \
         case_assign_shell_scope_includes_nested case_assign_dedup_claimed_file \
         case_assign_dedup_unclaimed case_assign_dedup_is_literal_not_regex \
         case_assign_spec_any_extension case_run_test_failure_vs_absent_runner \
         case_run_total_function case_run_absent case_run_bulk_green \
         case_run_shell_refuses_out_of_scope_unit case_run_unknown_runner_usage_error; do
  echo "== $c"; $c
done
echo "── run-test-selection: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
