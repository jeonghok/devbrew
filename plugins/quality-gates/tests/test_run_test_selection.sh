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

# v3.0.0 (/qg iter-1): unittest 어댑터는 **판정할 수 있는 파일만** claim 한다.
# 빈 파일이나 모듈-레벨 bare `def test_` 만 있는 파일은 `unittest discover` 가 0개를
# 수집하고 exit 0 을 내므로 claim 하면 "테스트 0개인데 pass" 가 된다. 아래 케이스들은
# **어댑터 소유권**을 재는 것이지 판정 가능성을 재는 것이 아니므로, 픽스처를 진짜
# TestCase 로 둬서 원래 의도(주장됨 vs 미주장 대비)를 유지한다.
mk_unittest_file() {   # mk_unittest_file <abs-path>
  printf 'import unittest\nclass T(unittest.TestCase):\n    def test_ok(self):\n        pass\n' > "$1"
}

# T43 + AC46: 어느 어댑터도 주장하지 않는 unit → unclaimed (조용한 누락 0)
case_assign_unclaimed() {
  mkw; mkdir -p "$W/tests"; mk_unittest_file "$W/tests/test_a.py"   # unittest만 감지됨
  local out; out=$(printf 'tests/test_a.py\nspec/foo_spec.rb\n' \
                   | bash "$RTS" assign "$W" | sort | tr '\n' ';')
  if [[ "$out" == "spec/foo_spec.rb${TAB}unclaimed${TAB}file;tests/test_a.py${TAB}unittest${TAB}file;" ]]; then
    pass "미주장 파일 → unclaimed 행"
  else fail "unclaimed (got: $out)"; fi
  rmw
}

# /qg iter-1 CRITICAL conf 9 (silent-failure-hunter 가 실행으로 재현).
# `unittest discover -p test_x.py` 는 모듈-레벨 bare `def test_…` 를 **0개 수집**하고
# exit 0 을 낸다(실측) — 아무것도 판정하지 않았는데 `pass` 행이 서고, 양측 동일하면
# STILL_GREEN → 테스트 0개로 PASS 다. 종료 코드로는 구분할 수 없으므로(0개 수집도 0)
# **선택 시점에** 거른다. 못 고른 파일은 unclaimed → verification degraded → PASS 불가.
#
# 양의 짝이 필수다: 판정 가능한 파일은 여전히 claim 돼야 한다. 없으면 "unittest 를 아예
# claim 하지 않는" mutation 이 GREEN 이 된다.
case_assign_unittest_skips_unjudgeable_file() {
  mkw; mkdir -p "$W/tests"
  printf 'def test_bare():\n    assert False\n' > "$W/tests/test_pytest_style.py"
  mk_unittest_file "$W/tests/test_unittest_style.py"
  local out; out=$(printf 'tests/test_pytest_style.py\ntests/test_unittest_style.py\n' \
                   | bash "$RTS" assign "$W" | sort | tr '\n' ';')
  if [[ "$out" == "tests/test_pytest_style.py${TAB}unclaimed${TAB}file;tests/test_unittest_style.py${TAB}unittest${TAB}file;" ]]; then
    pass "unittest: bare def test_ 는 unclaimed(→degraded) · TestCase 는 claim(양의 짝)"
  else fail "unittest 판정가능성 게이트 (got: $out)"; fi
  rmw
}

# ── /qg iter-2 CRITICAL (리뷰어 4명이 독립적으로 같은 결론) ────────────────────
#
# 위 게이트의 술어가 `grep -qE '(unittest|TestCase)'` — **앵커 없는 파일 전체
# 부분문자열** 이었다. 그래서 pytest 스타일 파일의 지배적 첫 줄
# `from unittest.mock import patch` 가 게이트를 통과시켰고, 실측으로 claim →
# `discover` 0개 수집 → **exit 0 → `pass`** 가 재현됐다(같은 파일을 pytest 로
# 돌리면 `1 failed`). 게이트가 있는데 그 게이트가 막으려던 바로 그 파일이 통과했다.
#
# 세 축을 각각 잰다 — import · 주석 · 상속하지 않는 헬퍼 클래스. 하나만 재면
# 나머지 두 축이 열린 술어(예: import 만 제외하는 특례)가 GREEN 을 받는다.
case_assign_unittest_substring_escapes() {
  mkw; mkdir -p "$W/tests"
  printf 'from unittest.mock import patch\n\ndef test_bare():\n    assert False\n' \
    > "$W/tests/test_mockimport.py"
  printf '# run with pytest, not unittest\ndef test_bare():\n    assert False\n' \
    > "$W/tests/test_comment.py"
  printf 'class TestCaseHelpers:\n    pass\n\ndef test_bare():\n    assert False\n' \
    > "$W/tests/test_helper.py"
  local out; out=$(printf 'tests/test_mockimport.py\ntests/test_comment.py\ntests/test_helper.py\n' \
                   | bash "$RTS" assign "$W" | sort | tr '\n' ';')
  local want="tests/test_comment.py${TAB}unclaimed${TAB}file;"
  want+="tests/test_helper.py${TAB}unclaimed${TAB}file;"
  want+="tests/test_mockimport.py${TAB}unclaimed${TAB}file;"
  if [[ "$out" == "$want" ]]; then
    pass "unittest: mock-import·주석·비상속 헬퍼 3축 전부 unclaimed (부분문자열 탈출 봉쇄)"
  else fail "부분문자열 탈출 (got: $out)"; fi
  rmw
}

# 좁힌 술어가 **정상 unittest 파일을 죽이지 않았음**을 잠근다. 이 짝이 없으면
# "아무것도 claim 하지 않는" mutation 이 위 케이스만으로 GREEN 이 된다.
# 세 형태 전부 `discover` 가 정상 수집하는 것들이다.
case_assign_unittest_still_claims_real_files() {
  mkw; mkdir -p "$W/tests"
  # unittest 를 직접 import 하지 않는 상속 (django 스타일)
  printf 'from django.test import TestCase\n\nclass T(TestCase):\n    def test_ok(self):\n        pass\n' \
    > "$W/tests/test_django.py"
  # 다중 상속 + 정규화된 base
  printf 'import unittest\n\nclass T(Mixin, unittest.TestCase):\n    def test_ok(self):\n        pass\n' \
    > "$W/tests/test_multi.py"
  # 클래스 없이 스위트를 만드는 정식 프로토콜
  printf 'def load_tests(loader, tests, pattern):\n    return tests\n' \
    > "$W/tests/test_loadtests.py"
  local out; out=$(printf 'tests/test_django.py\ntests/test_multi.py\ntests/test_loadtests.py\n' \
                   | bash "$RTS" assign "$W" | sort | tr '\n' ';')
  local want="tests/test_django.py${TAB}unittest${TAB}file;"
  want+="tests/test_loadtests.py${TAB}unittest${TAB}file;"
  want+="tests/test_multi.py${TAB}unittest${TAB}file;"
  if [[ "$out" == "$want" ]]; then
    pass "unittest: django 상속·다중 상속·load_tests 는 여전히 claim (양의 짝)"
  else fail "정상 unittest 파일 claim (got: $out)"; fi
  rmw
}

# /qg iter-3 CRITICAL — 게이트는 ∃ 가 아니라 ∀ 여야 한다.
# 앞 술어는 "discover 가 수집할 것이 하나라도 있는가" 를 물었다. 실측된 두 탈출은
# 그 질문에 **yes** 라고 답하면서도 discover 가 파일의 나머지를 통째로 놓친다:
#   (a) mixed — 진짜 TestCase 하나 + 모듈-레벨 bare def test_ → claim → `pass 0`,
#       같은 파일에 pytest 는 2 failed.
#   (b) docstring 예제 안의 들여쓴 `class T(unittest.TestCase):` → 앵커 정규식이
#       매치한다. 그 파일의 실제 테스트는 bare def 다.
# (b) 는 앞 커밋의 주석이 "docstring 은 만족시킬 수 없다" 고 단언한 케이스다 — 거짓.
case_assign_unittest_forall_not_exists() {
  mkw; mkdir -p "$W/tests"
  printf 'import unittest\n\nclass T(unittest.TestCase):\n    def test_ok(self):\n        pass\n\ndef test_bare():\n    assert False\n' \
    > "$W/tests/test_mixed.py"
  printf '"""Example:\n\n    class TestWidget(unittest.TestCase):\n        def test_x(self): ...\n"""\n\ndef test_bare():\n    assert False\n' \
    > "$W/tests/test_doc.py"
  local out; out=$(printf 'tests/test_mixed.py\ntests/test_doc.py\n' \
                   | bash "$RTS" assign "$W" | sort | tr '\n' ';')
  local want="tests/test_doc.py${TAB}unclaimed${TAB}file;tests/test_mixed.py${TAB}unclaimed${TAB}file;"
  if [[ "$out" == "$want" ]]; then
    pass "unittest: mixed·docstring-예제 둘 다 unclaimed (∃ 가 아니라 ∀)"
  else fail "∀-조건 (got: $out)"; fi
  rmw
}

# G2 — 판정가능성 게이트의 **`unittest` 한정**이 잠겨 있지 않았다. `run-test-
# selection.sh` 의 `[[ "$claimed" == "unittest" ]] &&` 를 지우면 전 스위트가 GREEN
# 이었는데, 그 결과는 **pytest 레포에서 bare `def test_` 파일이 전부 unclaimed** 가
# 되는 것이다 — pytest 는 그 형태를 정상 수집하는데도. AC53 에 따라 unclaimed 하나면
# `verification: degraded` → PASS 불가이므로 **평범한 pytest 레포가 구조적으로
# 인증 불가**가 된다. 픽스처 조합(pytest 감지 + bare-def 파일)이 없어서 뚫려 있었다.
case_assign_judge_gate_is_unittest_only() {
  mkw; mkdir -p "$W/tests"
  : > "$W/pytest.ini"                       # → pytest 어댑터로 감지
  printf 'def test_bare():\n    assert False\n' > "$W/tests/test_bare.py"
  local out; out=$(printf 'tests/test_bare.py\n' | bash "$RTS" assign "$W" | tr '\n' ';')
  if [[ "$out" == "tests/test_bare.py${TAB}pytest${TAB}file;" ]]; then
    pass "pytest 레포의 bare def test_ 는 claim 된다 (게이트는 unittest 한정)"
  else fail "판정가능성 게이트 스코프 (got: $out)"; fi
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
  mkw; mkdir -p "$W/tests"; mk_unittest_file "$W/tests/test_a.py"
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
  mkw; mkdir -p "$W/tests"; mk_unittest_file "$W/tests/test_a.py"   # unittest만 감지 — .rb는 미주장
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
  local out rc; out=$(bash "$RTS" run "$W" bogus-runner bulk X 2>/dev/null); rc=$?
  if [[ $rc -eq 2 && -z "$out" ]]; then
    pass "알 수 없는 runner → exit 2 (usage) + stdout 없음"
  else fail "unknown runner exit (rc=$rc out='$out')"; fi
  rmw
}

# 리뷰 Finding 1: bulk 모드의 absent 행은 present_count-eq-0 short-circuit 이나 per-unit
# absent 분기와 다른 코드 경로다(:387 부근). 이 케이스가 없으면 bulk 쪽 printf 를 지워도
# 스위트가 GREEN 이다 — 총 함수 계약이 소리 없이 깨진다.
case_run_bulk_partial_absent() {
  mk_shell_repo
  local out; out=$(bash "$RTS" run "$W" shell bulk tests/ok.sh tests/gone.sh 2>/dev/null)
  local n; n=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
  if [[ "$n" == "2" ]] \
     && printf '%s\n' "$out" | grep -q "^tests/ok\.sh${TAB}" \
     && printf '%s\n' "$out" | grep -q "^tests/gone\.sh${TAB}absent${TAB}-$"; then
    pass "bulk 부분 부재 → 2행 (존재분 + absent)"
  else fail "bulk partial absent (got: $out)"; fi
  rmw
}

# 리뷰 Finding 2: 거부된 unit 이 같은 bulk 호출의 형제 unit 상태를 오염시키지 않는다.
# per-unit 단일-거부 케이스만으로는 refused_units 북키핑이 bulk_status 계산과 잘못된
# 순서로 얽히는 경로를 못 잡는다.
case_run_bulk_refused_does_not_corrupt_sibling() {
  mkw; mkdir -p "$W/tests" "$W/scripts"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$W/tests/ok.sh"; chmod +x "$W/tests/ok.sh"
  printf '#!/usr/bin/env bash\ntouch PWNED\nexit 0\n' > "$W/scripts/deploy.sh"
  chmod +x "$W/scripts/deploy.sh"
  local out; out=$(bash "$RTS" run "$W" shell bulk tests/ok.sh scripts/deploy.sh 2>/dev/null)
  if printf '%s\n' "$out" | grep -q "^tests/ok\.sh${TAB}pass${TAB}0$" \
     && printf '%s\n' "$out" | grep -q "^scripts/deploy\.sh${TAB}unrun${TAB}-$" \
     && [[ ! -e "$W/PWNED" ]]; then
    pass "bulk 거부 unit 이 형제 상태를 오염시키지 않음 (부작용 없음)"
  else fail "bulk 혼합 거부 (out='$out', PWNED=$([[ -e "$W/PWNED" ]] && echo yes || echo no))"; fi
  rmw
}

# 리뷰 Finding 4: bulk 모드에서 공백이 든 unit 경로가 공백-연결(unquoted word-splitting)로
# 두 위치 인자로 쪼개지지 않는다. git 경로는 공백을 금지하지 않는다.
#
# shell 러너로는 이 결함을 잡을 수 없다: run_units 가 shell을 이미 unit별로 순회하고,
# shell_unit_in_scope 가드가 쪼개진 두 조각(둘 다 tests/*.sh 패턴을 만족 못함) 을 각각
# 거부하면서 rc 를 건드리지 않아 우연히 초기값 0(pass)이 살아남는다 — 실행 거부 가드가
# 쪼개짐 결함을 가려버린다. pytest 는 "$@" 를 한 번에 통째로 넘기므로 쪼개지면 pytest
# 자신이 "file or directory not found" 로 exit 4(error) 를 낸다 — 실측: 단일 인자는
# exit 0, 두 조각으로 쪼개면 exit 4.
case_run_bulk_unit_path_with_space() {
  mkw; mkdir -p "$W/tests"; : > "$W/pytest.ini"
  printf 'def test_ok():\n    assert True\n' > "$W/tests/test my.py"
  local out; out=$(bash "$RTS" run "$W" pytest bulk "tests/test my.py" 2>/dev/null)
  [[ "$out" == "tests/test my.py${TAB}pass${TAB}0" ]] \
    && pass "공백 포함 unit 경로가 bulk 모드에서 쪼개지지 않음" \
    || fail "공백 경로 bulk (got: $out)"
  rmw
}

# 최종 whole-branch 리뷰 I5 — `run` 의 셸-스코프 검사가 담김(containment)이 아니라
# 부분문자열 검사였다. `../<other>/tests/evil.sh` 는 `*/tests/*.sh` 글롭과 `-x "$w/$f"`
# 를 **둘 다** 만족하고, `cd "$w" && bash "$u"` 가 그것을 워크트리 밖에서 실행했다
# (리뷰어 실측: EXECUTED-OUTSIDE-WORKTREE 마커). 양측이 같은 unit 목록을 돌므로
# **두 번** 실행된다. 이 컴포넌트의 명시된 안전 계약은 설계 §5.9 의
# "임의 명령을 추측해 실행하지 않는다" 이다.
#
# 두 호출 지점을 **모두** 잰다 — run 만 막으면 assign 이 여전히 그것을 unit 으로
# 주장해 다른 소비자에게 흘린다.
case_unit_outside_worktree_is_refused() {
  local root w evil out n
  root=$(mktemp -d); w="$root/victim"
  mkdir -p "$w/tests" "$root/other/tests"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$w/tests/ok.sh"; chmod +x "$w/tests/ok.sh"
  evil="$root/other/tests/evil.sh"
  printf '#!/usr/bin/env bash\ntouch %s/ESCAPED\nexit 0\n' "$root" > "$evil"; chmod +x "$evil"

  out=$(printf '../other/tests/evil.sh\n' | bash "$RTS" assign "$w")
  [[ "$out" == "../other/tests/evil.sh${TAB}unclaimed${TAB}file" ]] \
    && pass "assign: 워크트리 밖 unit 미주장 (unclaimed → verification degraded)" \
    || fail "assign 담김 (got: $out)"

  out=$(bash "$RTS" run "$w" shell per-unit ../other/tests/evil.sh 2>/dev/null)
  if [[ ! -e "$root/ESCAPED" ]]; then
    pass "run: 워크트리 밖 unit 미실행 (부작용 없음)"
  else
    fail "run 이 워크트리 밖 스크립트를 실행함 (out='$out')"
    rm -f "$root/ESCAPED"
  fi
  n=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
  [[ "$n" == "1" ]] && pass "거부해도 입력당 정확히 1행 (총 함수 유지)" \
                    || fail "총 함수 깨짐 ($n 행: '$out')"

  # 절대경로도 같은 클래스다 — `..` 만 막으면 절반만 막은 것이다.
  out=$(bash "$RTS" run "$w" shell per-unit "$evil" 2>/dev/null)
  [[ ! -e "$root/ESCAPED" ]] && pass "절대경로 unit 도 미실행" \
                             || fail "절대경로 unit 이 실행됨 (out='$out')"

  # 심볼릭 링크에는 **두 축**이 있고 서로 다른 코드가 막는다. 디렉토리 축만 재면
  # 잎(leaf) 축이 열린 채로 통과한다 — 라운드 2 NEW-2 가 그 상태를 실측으로 뚫었다.
  #
  # 축 A — 디렉토리 심볼릭 링크: `dirname` 의 `pwd -P` 해소가 막는다.
  ln -s "$root/other/tests" "$w/tests/link"
  out=$(bash "$RTS" run "$w" shell per-unit tests/link/evil.sh 2>/dev/null)
  [[ ! -e "$root/ESCAPED" ]] && pass "축 A: 디렉토리 심볼릭 링크 경유 unit 미실행" \
                             || fail "디렉토리 링크로 탈출 (out='$out')"

  # 축 B — **잎** 심볼릭 링크: `dirname` 은 트리 안이고 `-x`/`-e` 는 링크를 따라간다.
  # 잎을 해소하지 않으면 assign 이 주장하고 run 이 트리 밖 스크립트를 실행한다(실측).
  ln -s ../../other/tests/evil.sh "$w/tests/evil.sh"
  out=$(printf 'tests/evil.sh\n' | bash "$RTS" assign "$w")
  [[ "$out" == "tests/evil.sh${TAB}unclaimed${TAB}file" ]] \
    && pass "축 B: assign 이 잎 심볼릭 링크 unit 을 미주장" \
    || fail "assign 잎 링크 (got: $out)"
  out=$(bash "$RTS" run "$w" shell per-unit tests/evil.sh 2>/dev/null)
  if [[ ! -e "$root/ESCAPED" ]]; then
    pass "축 B: run 이 잎 심볼릭 링크 unit 을 미실행"
  else
    fail "잎 심볼릭 링크로 탈출 (out='$out')"; rm -f "$root/ESCAPED"
  fi

  # 축 D — 대상이 **워크트리 루트 자신**(`-> ..`). 담김은 정당하게 통과한다(진짜로 트리
  # 안이다). 그래서 이 축은 담김이 아니라 `granularity: file` 의 `-f` 검사가 막는다:
  # 디렉토리를 file unit 으로 받으면 러너가 트리 **전체**를 돌고 그 결과가 unit 하나의
  # `pass` 로 보고된다 — 탈출은 아니지만 귀속이 파괴되고 행은 초록이다.
  ln -s .. "$w/tests/rootlink.sh"
  out=$(bash "$RTS" run "$w" shell per-unit tests/rootlink.sh 2>/dev/null)
  [[ "$out" == "tests/rootlink.sh${TAB}absent${TAB}-" ]] \
    && pass "축 D: 루트를 가리키는 잎 링크는 file unit 이 아님 → absent (전-트리 실행 없음)" \
    || fail "루트 링크가 file unit 으로 통과 (out='$out')"

  # 정당한 트리-안 unit 은 여전히 돈다 — 담김 검사가 대상을 통째로 죽이지 않았는가
  out=$(bash "$RTS" run "$w" shell per-unit tests/ok.sh 2>/dev/null)
  [[ "$out" == "tests/ok.sh${TAB}pass${TAB}0" ]] \
    && pass "트리 안 정당한 unit 은 그대로 실행" || fail "정당 unit 회귀 (got: $out)"
  # 트리 **안**을 가리키는 잎 심볼릭 링크는 막지 않는다 (과잉 차단 방지)
  ln -s ok.sh "$w/tests/alias.sh"
  out=$(bash "$RTS" run "$w" shell per-unit tests/alias.sh 2>/dev/null)
  [[ "$out" == "tests/alias.sh${TAB}pass${TAB}0" ]] \
    && pass "트리 안을 가리키는 잎 링크는 그대로 실행 (과잉 차단 없음)" \
    || fail "트리 안 링크 과잉 차단 (got: $out)"
  rm -rf "$root"
}

# 라운드 2 NEW-2 (두 번째 소비 지점) — 잎 심볼릭 링크 구멍은 `exists_unit` 를 통해
# pytest/jest unit 에도 그대로 닿았다. shell 픽스처 하나로는 그 축을 못 잰다:
# shell 은 `shell_unit_in_scope` 라는 두 번째 층이 있지만 pytest 는 `exists_unit` 뿐이다.
case_leaf_symlink_escape_via_pytest() {
  local root w out
  root=$(mktemp -d); w="$root/victim"
  mkdir -p "$w/tests" "$root/other/tests"
  : > "$w/pytest.ini"
  printf 'def test_x():\n    open("%s/ESCAPED", "w").write("x")\n' "$root" \
    > "$root/other/tests/test_evil.py"
  ln -s ../../other/tests/test_evil.py "$w/tests/test_evil.py"

  out=$(printf 'tests/test_evil.py\n' | bash "$RTS" assign "$w")
  [[ "$out" == "tests/test_evil.py${TAB}unclaimed${TAB}file" ]] \
    && pass "pytest: assign 이 잎 링크 unit 을 미주장" || fail "pytest assign 잎 링크 (got: $out)"

  out=$(bash "$RTS" run "$w" pytest per-unit tests/test_evil.py 2>/dev/null)
  if [[ ! -e "$root/ESCAPED" ]]; then
    pass "pytest: run 이 잎 링크 unit 을 미실행 (exists_unit 축)"
  else
    fail "pytest 잎 링크로 탈출 (out='$out')"
  fi
  rm -rf "$root"
}

# 라운드 3 F1 — 대상이 **`..` 로 끝나는** 잎 링크. 잎 해소가 `dirname(최종 대상)` 만
# 정규화하면 이 모양이 새어나간다: `-> ../..` 의 dirname 은 트리 **안**으로 정규화되는데
# 대상 자신은 트리 밖이다. 실측으로 pytest 가 워크트리 **밖에서** 32개 테스트를 돌렸고
# 행은 `pass 0` 이었다.
#
# **이 축은 `package` 입도로만 잴 수 있다.** `..` 로 끝나는 대상은 언제나 디렉토리이고,
# `file` 입도에서는 `exists_unit` 의 `-f` 가 그것을 먼저 `absent` 로 만들어 담김 검사가
# 무엇을 하든 결과가 같아진다 — 실제로 file 입도로 짠 첫 arm 은 담김 수정을 되돌려도
# GREEN 이었다(계측기가 고장 나 있던 경우). go 는 `-d` 를 쓰므로 디렉토리 unit 이
# 정당하고, 따라서 담김 검사가 유일한 방어선이다.
#
# `go` 스텁으로 관측한다 — 실물 toolchain 없이도(그리고 있어도) 같은 결과가 나와야 한다.
case_package_unit_updot_symlink_escape() {
  local root w bindir out rc
  root=$(mktemp -d); w="$root/wt"
  mkdir -p "$w/sub" "$root/sibling"
  printf 'module x\n' > "$w/go.mod"
  # **링크 깊이가 계측의 일부다.** 대상은 `dirname(대상)` 이 정확히 `$w` 로 정규화되도록
  # 놓아야 옛(dirname-only) 코드가 그것을 "안"으로 판정한다 — 즉 링크는 `$w` 의 한 단계
  # 아래에 있어야 한다. `$w/escape -> ../..` 처럼 얕게 놓으면 dirname 도 트리 밖이라
  # **옛 코드조차 거부**하고, 그러면 이 arm 은 수정을 되돌려도 GREEN 이다(실측으로
  # 그렇게 만들었다가 잡았다 — 계측기가 고장 난 케이스).
  ln -s ../.. "$w/sub/escape"    # → $root (트리 밖). dirname(대상) = $w (트리 안).
  bindir=$(mktemp -d)
  printf '#!/usr/bin/env bash\nexit 0\n' > "$bindir/go"; chmod +x "$bindir/go"

  out=$(PATH="$bindir:$PATH" bash "$RTS" run "$w" go per-unit sub/escape 2>/dev/null); rc=$?
  if [[ "$out" == "sub/escape${TAB}absent${TAB}-" ]]; then
    pass "package unit: '..' 종단 잎 링크가 러너에 전달되지 않음 (대상 자신을 정규화)"
  else
    fail "'..' 종단 링크가 package unit 으로 러너에 전달됨 (rc=$rc out='$out')"
  fi

  # 정당한 트리-안 패키지는 그대로 돈다 — 과잉 차단 방지
  mkdir -p "$w/pkg"; : > "$w/pkg/a_test.go"
  out=$(PATH="$bindir:$PATH" bash "$RTS" run "$w" go per-unit pkg 2>/dev/null)
  [[ "$out" == "pkg${TAB}pass${TAB}0" ]] \
    && pass "트리 안 정당한 package unit 은 그대로 실행" || fail "package 과잉 차단 (out='$out')"
  rm -rf "$root" "$bindir"
}

# 최종 whole-branch 리뷰 C2 백스톱 — 실행 **도중** 도구가 없어 나온 127 을 `error` 로
# 두면 §5.5 가 fail 축으로 접어 양측 fail → PRE_EXISTING → attribution closed →
# 테스트 0개 PASS 로 간다. 127 은 미실행 축(`unrun`)이다. 가용성 프로브는 실행
# **직전**만 보므로 이 매핑이 그 뒤를 받는다.
case_run_exit_127_is_unrun() {
  mkw; mkdir -p "$W/tests"
  printf '#!/usr/bin/env bash\nexit 127\n' > "$W/tests/gone.sh"; chmod +x "$W/tests/gone.sh"
  printf '#!/usr/bin/env bash\nexit 2\n'   > "$W/tests/err.sh";  chmod +x "$W/tests/err.sh"
  local out
  out=$(bash "$RTS" run "$W" shell per-unit tests/gone.sh 2>/dev/null)
  [[ "$out" == "tests/gone.sh${TAB}unrun${TAB}127" ]] \
    && pass "exit 127 → unrun (미실행 축)" || fail "127 매핑 (got: $out)"
  # 127 이 아닌 그 외 코드는 여전히 error 다 — 매핑을 통째로 바꾼 게 아님을 고정한다
  out=$(bash "$RTS" run "$W" shell per-unit tests/err.sh 2>/dev/null)
  [[ "$out" == "tests/err.sh${TAB}error${TAB}2" ]] \
    && pass "exit 2 → error (기존 매핑 무변경)" || fail "error 매핑 회귀 (got: $out)"
  rmw
}

for c in case_assign_go_package case_assign_unclaimed case_assign_unittest_skips_unjudgeable_file \
         case_assign_unittest_substring_escapes case_assign_unittest_still_claims_real_files \
         case_assign_judge_gate_is_unittest_only case_assign_unittest_forall_not_exists \
         case_assign_bulk_conflict \
         case_assign_residual_no_absorber case_assign_shell_scope_excludes_non_test \
         case_assign_shell_scope_includes_nested case_assign_dedup_claimed_file \
         case_assign_dedup_unclaimed case_assign_dedup_is_literal_not_regex \
         case_assign_spec_any_extension case_run_test_failure_vs_absent_runner \
         case_run_total_function case_run_absent case_run_bulk_green \
         case_run_shell_refuses_out_of_scope_unit case_run_unknown_runner_usage_error \
         case_run_bulk_partial_absent case_run_bulk_refused_does_not_corrupt_sibling \
         case_run_bulk_unit_path_with_space \
         case_unit_outside_worktree_is_refused case_leaf_symlink_escape_via_pytest \
         case_package_unit_updot_symlink_escape \
         case_run_exit_127_is_unrun; do
  echo "== $c"; $c
done
echo "── run-test-selection: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
