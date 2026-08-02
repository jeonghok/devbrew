#!/usr/bin/env bash
# test_runner_adapters.sh — run-test-selection.sh detect의 어댑터 8종 (design §5.9).
# AC34 AC38 AC45 AC56(detect) · T25 T34 T42 · M14 M20
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RTS="$PLUGIN_ROOT/scripts/run-test-selection.sh"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"

PASS=0; FAIL=0; W=""
pass() { PASS=$((PASS + 1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }
mkw()  { W=$(mktemp -d) || exit 1; }
rmw()  { cd / && rm -rf "$W"; }
# runners <worktree> → 감지된 runner 이름을 개행으로
runners() { bash "$RTS" detect "$1" | awk '$1 == "runner:" { print $2 }'; }
gran_of() { bash "$RTS" detect "$1" | awk -v r="$2" '
  $1=="runner:"{cur=$2} $1=="granularity:" && cur==r {print $2}'; }

# T34/T25: 8 어댑터 각각 감지
case_pytest()   { mkw; : > "$W/pytest.ini"; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"
  [[ "$(runners "$W")" == "pytest" ]] && pass "pytest.ini → pytest" || fail "pytest ($(runners "$W"))"; rmw; }
case_unittest() { mkw; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"
  [[ "$(runners "$W")" == "unittest" ]] && pass "설정 없는 test_*.py → unittest" || fail "unittest ($(runners "$W"))"; rmw; }
# 설정 섹션이 없어도 레포가 pytest 를 선언하면 pytest — 이 케이스가 없으면
# tier 2 가 죽은 코드인지 산 코드인지 스위트가 구분하지 못한다.
case_pytest_declared_without_config() {
  mkw; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"; : > "$W/conftest.py"
  [[ "$(runners "$W")" == "pytest" ]] \
    && pass "conftest.py + test_*.py (설정 섹션 없음) → pytest" \
    || fail "tier2 conftest ($(runners "$W"))"
  rmw
}
case_shell()    { mkw; mkdir -p "$W/tests"; printf '#!/usr/bin/env bash\nexit 0\n' > "$W/tests/t.sh"; chmod +x "$W/tests/t.sh"
  [[ "$(runners "$W")" == "shell" ]] && pass "실행비트 tests/*.sh → shell" || fail "shell ($(runners "$W"))"; rmw; }
case_jest()     { mkw; printf '{"devDependencies":{"jest":"29"}}' > "$W/package.json"
  [[ "$(runners "$W")" == "jest" ]] && pass "devDeps.jest → jest" || fail "jest ($(runners "$W"))"; rmw; }
case_vitest()   { mkw; printf '{"devDependencies":{"vitest":"1"}}' > "$W/package.json"
  [[ "$(runners "$W")" == "vitest" ]] && pass "devDeps.vitest → vitest" || fail "vitest ($(runners "$W"))"; rmw; }
case_go()       { mkw; printf 'module x\n' > "$W/go.mod"
  [[ "$(runners "$W")" == "go" && "$(gran_of "$W" go)" == "package" ]] \
    && pass "go.mod → go(package)" || fail "go ($(runners "$W"))"; rmw; }
case_cargo()    { mkw; printf '[package]\nname="x"\n' > "$W/Cargo.toml"
  [[ "$(runners "$W")" == "cargo" && "$(gran_of "$W" cargo)" == "bulk" ]] \
    && pass "Cargo.toml → cargo(bulk)" || fail "cargo ($(runners "$W"))"; rmw; }
case_make()     { mkw; printf 'test:\n\t@true\n' > "$W/Makefile"
  [[ "$(runners "$W")" == "make" ]] && pass "Makefile test: → make" || fail "make ($(runners "$W"))"; rmw; }
case_npmscript(){ mkw; printf '{"scripts":{"test":"node t.js"}}' > "$W/package.json"
  [[ "$(runners "$W")" == "npm-script" ]] && pass "scripts.test(비-jest/vitest) → npm-script" || fail "npm-script ($(runners "$W"))"; rmw; }

# T54(detect 절반) + AC56: 감지 0개 → 빈 stdout + exit 0
case_zero_adapters() {
  mkw; : > "$W/README.md"
  local out rc; out=$(bash "$RTS" detect "$W"); rc=$?
  if [[ $rc -eq 0 && -z "$out" ]]; then pass "감지 0개 → 빈 stdout + exit 0"
  else fail "0-어댑터 (rc=$rc out='$out')"; fi
  rmw
}

# T42 + M20: 폴리글랏 — 두 어댑터가 **함께** 반환된다 (단일-어댑터 픽스처로는 못 잡는다)
case_polyglot() {
  mkw; mkdir -p "$W/tests"
  : > "$W/tests/test_a.py"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$W/tests/t.sh"; chmod +x "$W/tests/t.sh"
  local got; got=$(runners "$W" | sort | tr '\n' ',')
  if [[ "$got" == "shell,unittest," ]]; then pass "폴리글랏 → 어댑터 2개 모두 반환"
  else fail "폴리글랏 (got: $got, expected shell,unittest,)"; fi
  rmw
}

# AC54: pytest/unittest 상호배타 · jest/vitest 판별불가 → npm-script 폴백
case_conflict_python() {
  mkw; : > "$W/pytest.ini"; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"
  local got; got=$(runners "$W" | tr '\n' ',')
  [[ "$got" == "pytest," ]] && pass "pytest 설정 존재 → unittest 미주장" || fail "py 충돌 ($got)"
  rmw
}
case_conflict_js_ambiguous() {
  mkw; printf '{"devDependencies":{"jest":"29","vitest":"1"},"scripts":{"test":"run-tests"}}' > "$W/package.json"
  local got; got=$(runners "$W" | tr '\n' ',')
  [[ "$got" == "npm-script," ]] && pass "jest+vitest 판별불가 → npm-script 폴백" || fail "js 모호 ($got)"
  rmw
}
case_conflict_js_resolved() {
  mkw; printf '{"devDependencies":{"jest":"29","vitest":"1"},"scripts":{"test":"vitest run"}}' > "$W/package.json"
  local got; got=$(runners "$W" | tr '\n' ',')
  [[ "$got" == "vitest," ]] && pass "scripts.test가 vitest 호출 → vitest" || fail "js 해소 ($got)"
  rmw
}

# T34 후반 + AC38: SKILL.md에 어댑터 감지 조건 재구현이 없다
# (body-unique한 감지 조건 문자열들이 SKILL.md에 등장하면 표를 복제한 것)
case_no_reimpl_in_skill() {
  local bad=0 s
  for s in 'devDependencies' 'pytest.ini' 'Cargo.toml' 'go.mod'; do
    if grep -qF "$s" "$SKILL"; then echo "    SKILL.md가 감지 조건 '$s'를 담고 있음"; bad=1; fi
  done
  [[ $bad -eq 0 ]] && pass "SKILL.md에 어댑터 감지 표 재구현 0회" || fail "SKILL.md 감지 표 재구현"
}

# 컨트롤러 룰링 회귀 락: pytest 감지는 **레포 선언**만 본다. 앰비언트 인터프리터 프로브가
# 다시 들어오면 같은 레포가 머신마다 다르게 감지되고, 설정 없는 pytest 레포가 unittest 로
# 새어 bare 함수 테스트가 조용히 0개 실행된다.
case_no_ambient_pytest_probe() {
  if grep -q 'import pytest' "$RTS"; then
    fail "앰비언트 pytest 프로브 재도입됨 (레포 선언 기반이어야 함)"
  else
    pass "앰비언트 pytest 프로브 0회 — 감지는 레포 선언만 본다"
  fi
}

for c in case_pytest case_unittest case_pytest_declared_without_config case_shell case_jest case_vitest case_go case_cargo \
         case_make case_npmscript case_zero_adapters case_polyglot \
         case_conflict_python case_conflict_js_ambiguous case_conflict_js_resolved \
         case_no_reimpl_in_skill case_no_ambient_pytest_probe; do
  echo "== $c"; $c
done
echo "── runner adapters: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
