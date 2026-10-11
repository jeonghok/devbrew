#!/usr/bin/env bash
# test_runner_adapters.sh — run-test-selection.sh 의 어댑터 표(detect · granularity)와 실행 관문.
# 요구: R3 · R4 · R14 · R21(go) · R22 (docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md §요구 목록)
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RTS="$PLUGIN_ROOT/scripts/run-test-selection.sh"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

W=""
mkw() { W=$(mktemp -d) && [ -d "$W" ] || { echo "mktemp 실패" >&2; exit 1; }; }
rmw() { cd / && rm -rf "$W"; }
runners() { bash "$RTS" detect "$1" 2>/dev/null | awk '$1 == "runner:" { print $2 }'; }
gran_of() { bash "$RTS" detect "$1" 2>/dev/null | awk -v r="$2" '$1=="runner:"{c=$2} $1=="granularity:" && c==r {print $2}'; }

# 일회용 트리: <repo>/main 에 커밋하고 <repo>/wt 에 detached 로 연다. run 은 detached 일회용 트리만 받는다.
TREE=""; REPO=""
mktree() {   # mktree — 호출 전에 $REPO/main 에 파일을 둔다
  ( cd "$REPO/main" && git add -A && git commit -qm t ) || { no "픽스처 커밋 실패"; return 1; }
  git -C "$REPO/main" worktree add -q --detach "$REPO/wt" HEAD || { no "픽스처 worktree 실패"; return 1; }
  TREE="$REPO/wt"
}
mkrepo() {
  REPO=$(mktemp -d) && [ -d "$REPO" ] || { echo "mktemp 실패" >&2; exit 1; }
  git init -q -b main "$REPO/main" || exit 1
  git -C "$REPO/main" config user.email t@t; git -C "$REPO/main" config user.name t
  git -C "$REPO/main" config commit.gpgsign false
}
rmrepo() { cd / && rm -rf "$REPO"; }
row_of() { awk -F'\t' -v u="$2" '$1 == u { print $2 "\t" $3 }' "$1"; }

# ── detect: 어댑터 표 ────────────────────────────────────────────────────────────
case_detect_pytest()   { mkw; : > "$W/pytest.ini"; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"
  assert_eq "$(runners "$W")" "pytest" "pytest.ini → pytest"; rmw; }
case_detect_unittest() { mkw; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"
  assert_eq "$(runners "$W")" "unittest" "설정 없는 test_*.py → unittest"; rmw; }
case_detect_pytest_declared() { mkw; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"; : > "$W/conftest.py"
  assert_eq "$(runners "$W")" "pytest" "conftest.py + test_*.py → pytest"; rmw; }
case_detect_shell() { mkw; mkdir -p "$W/tests"; printf '#!/bin/bash\nexit 0\n' > "$W/tests/t.sh"; chmod +x "$W/tests/t.sh"
  assert_eq "$(runners "$W")" "shell" "실행 비트 tests/*.sh → shell"; rmw; }
case_detect_jest()   { mkw; printf '{"devDependencies":{"jest":"29"}}' > "$W/package.json"
  assert_eq "$(runners "$W")" "jest" "devDependencies.jest → jest"; rmw; }
case_detect_vitest() { mkw; printf '{"devDependencies":{"vitest":"1"}}' > "$W/package.json"
  assert_eq "$(runners "$W")" "vitest" "devDependencies.vitest → vitest"; rmw; }
case_detect_go()     { mkw; : > "$W/go.mod"; assert_eq "$(runners "$W")" "go" "go.mod → go"; rmw; }
case_detect_cargo()  { mkw; : > "$W/Cargo.toml"; assert_eq "$(runners "$W")" "cargo" "Cargo.toml → cargo"; rmw; }
case_detect_make()   { mkw; printf 'test:\n\ttrue\n' > "$W/Makefile"; assert_eq "$(runners "$W")" "make" "Makefile test: → make"; rmw; }
case_detect_npm_script() { mkw; printf '{"scripts":{"test":"node t.js"}}' > "$W/package.json"
  assert_eq "$(runners "$W")" "npm-script" "scripts.test → npm-script"; rmw; }
case_detect_zero() { mkw; local out rc; out=$(bash "$RTS" detect "$W"); rc=$?
  assert_eq "$rc:$out" "0:" "어댑터 0개는 빈 출력 + exit 0"; rmw; }
case_detect_polyglot() { mkw; : > "$W/go.mod"; : > "$W/Cargo.toml"; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"
  assert_eq "$(runners "$W" | tr '\n' ' ')" "unittest go cargo " "폴리글랏은 집합"; rmw; }
case_detect_js_ambiguous_is_loud() { mkw; printf '{"devDependencies":{"jest":"1","vitest":"1"},"scripts":{"test":"node x"}}' > "$W/package.json"
  local err; err=$(bash "$RTS" detect "$W" 2>&1 >/dev/null)
  assert_eq "$(runners "$W")" "npm-script" "jest+vitest 모호 → npm-script"
  assert_contains "$err" "jest 와 vitest" "모호함을 알린다"; rmw; }
case_detect_malformed_package_json_is_loud() { mkw; printf '{not json' > "$W/package.json"
  local err; err=$(bash "$RTS" detect "$W" 2>&1 >/dev/null)
  assert_contains "$err" "파싱에 실패" "package.json 파손을 알린다"; rmw; }
case_granularity_table() {
  local r out=""
  for r in pytest unittest shell jest vitest go cargo make npm-script; do out="$out$r=$(bash "$RTS" granularity "$r") "; done
  assert_eq "$out" "pytest=file unittest=file shell=file jest=file vitest=file go=package cargo=bulk make=bulk npm-script=bulk " "입도 표"
  bash "$RTS" granularity rspec >/dev/null 2>&1; assert_eq "$?" "2" "미지 러너는 exit 2"
}
case_R22_detect_imports_no_repo_module() { mkw; printf '{"scripts":{"test":"node t.js"}}' > "$W/package.json"
  printf 'open("%s/PWNED","w").write("x")\n' "$W" > "$W/json.py"
  local rc; ( cd "$W" && DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1 bash "$RTS" detect "$W" >/dev/null 2>&1 ); rc=$?
  assert_eq "$rc" "0" "detect 는 exit 0"
  [ ! -e "$W/PWNED" ] && ok "감지가 저장소의 json.py 를 import 하지 않는다" || no "저장소 모듈이 detect 중 실행됐다"; rmw; }
# 어댑터 개수를 적은 문서 주장은 닫힌 집합과 같아야 한다.
case_adapter_count_claims_match() {
  local n found=0 bad=0 hit claimed
  n=$(sed -n '/^granularity_of() {/,/^}/p' "$RTS" | grep -oE '^[[:space:]]+[a-z|-]+\)' | tr -d ' )' | tr '|' '\n' | grep -c .)
  while IFS= read -r hit; do
    found=$((found + 1))
    claimed=$(sed -E 's/.*러너 어댑터 ([0-9]+)종.*/\1/' <<<"$hit")
    [ "$claimed" = "$n" ] || { bad=1; echo "    불일치 ${claimed}≠${n}: ${hit:0:110}"; }
  done < <(grep -rnE "러너 어댑터 [0-9]+종" "$PLUGIN_ROOT" --include='*.md' --include='*.sh' --include='*.py' 2>/dev/null | grep -v '/CHANGELOG.md:')
  [ "$n" -eq 9 ] && ok "닫힌 집합 9종" || no "닫힌 집합 파싱 n=$n"
  [ "$found" -gt 0 ] && [ "$bad" -eq 0 ] && ok "어댑터 개수 주장 ${found}곳 일치" || no "어댑터 개수 주장 불일치 또는 0건(found=$found)"
}

# ── 실행 관문 ───────────────────────────────────────────────────────────────────
# R14 — 기준선 트리는 어댑터를 스스로 다시 탐지한다: 그 트리에 없는 어댑터는 unrun 이다.
case_R14_tree_without_adapter_is_unrun() {
  mkrepo; mkdir -p "$REPO/main/tests"; printf 'x\n' > "$REPO/main/README"
  mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell bulk "$REPO/rows.tsv" tests/a.sh 2>/dev/null; local rc=$?
  assert_eq "$rc" "3" "R14: 트리에 shell 어댑터가 없으면 exit 3"
  assert_eq "$(row_of "$REPO/rows.tsv" tests/a.sh)" "unrun	-" "R14: 그 unit 은 unrun"
  rmrepo
}
# R3 — 러너가 이 머신에 없으면 unrun 이다(PRE_EXISTING 위장 방지).
case_R3_missing_toolchain_is_unrun() {
  mkrepo; mkdir -p "$REPO/main/pkg"; printf 'module x\n' > "$REPO/main/go.mod"; printf 'package pkg\n' > "$REPO/main/pkg/a_test.go"
  mktree || { rmrepo; return; }
  PATH=/usr/bin:/bin bash "$RTS" run "$TREE" go per-unit "$REPO/rows.tsv" pkg 2>/dev/null; local rc=$?
  assert_eq "$rc" "3" "R3: go 가 PATH 에 없으면 exit 3"
  assert_eq "$(row_of "$REPO/rows.tsv" pkg)" "unrun	-" "R3: unrun 행"
  rmrepo
}
# R3 — setup 실패도 unrun 이다. 러너(venv 의 python)는 있는데 의존성 설치만 실패하는 픽스처라
# setup 관문만이 이 unit 을 막는다(네트워크 없이 pip 가 바로 거부하는 요구 줄).
case_R3_setup_failure_is_unrun() {
  mkrepo; mkdir -p "$REPO/main/tests"
  printf '!!!not-a-requirement\n' > "$REPO/main/requirements.txt"; printf '.venv/\n' > "$REPO/main/.gitignore"
  printf 'import unittest\nclass T(unittest.TestCase):\n    def test_a(self):\n        pass\n' > "$REPO/main/tests/test_a.py"
  mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" unittest per-unit "$REPO/rows.tsv" tests/test_a.py 2>/dev/null; local rc=$?
  assert_eq "$rc" "3" "R3: setup(pip install) 실패면 exit 3"
  assert_eq "$(row_of "$REPO/rows.tsv" tests/test_a.py)" "unrun	-" "R3: unrun 행"
  rmrepo
}
# R3 — 실행 도중의 exit 127 도 unrun 이다.
case_R3_exit_127_is_unrun() {
  mkrepo; mkdir -p "$REPO/main/tests"
  printf '#!/bin/bash\nqg-no-such-command-xyz\n' > "$REPO/main/tests/a.sh"; chmod +x "$REPO/main/tests/a.sh"
  mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/a.sh 2>/dev/null
  assert_eq "$(row_of "$REPO/rows.tsv" tests/a.sh)" "unrun	127" "R3: exit 127 → unrun"
  rmrepo
}
# R4 — 0/1/127 밖의 종료 코드는 unrun 으로 접지 않는다(error).
case_R4_other_exit_is_error_not_unrun() {
  mkrepo; mkdir -p "$REPO/main/tests"
  printf '#!/bin/bash\nexit 2\n' > "$REPO/main/tests/a.sh"; chmod +x "$REPO/main/tests/a.sh"
  mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/a.sh 2>/dev/null
  assert_eq "$(row_of "$REPO/rows.tsv" tests/a.sh)" "error	2" "R4: exit 2 → error"
  rmrepo
}
# R21 — go unit 은 *_test.go 가 있는 패키지여야 존재한다. 없으면 absent(아무것도 판정하지 않은 pass 방지).
case_R21_go_package_without_tests_is_absent() {
  mkrepo; mkdir -p "$REPO/main/pkg"; printf 'module x\n' > "$REPO/main/go.mod"; printf 'package pkg\n' > "$REPO/main/pkg/a.go"
  mktree || { rmrepo; return; }
  local bin; bin=$(mktemp -d); printf '#!/bin/bash\nexit 0\n' > "$bin/go"; chmod +x "$bin/go"
  PATH="$bin:/usr/bin:/bin" bash "$RTS" run "$TREE" go per-unit "$REPO/rows.tsv" pkg 2>/dev/null
  assert_eq "$(row_of "$REPO/rows.tsv" pkg)" "absent	-" "R21: *_test.go 없는 패키지 → absent"
  rm -rf "$bin"; rmrepo
}
# R22 — kill switch 가 켜져 있으면 run 은 저장소 코드를 하나도 실행하지 않는다.
case_R22_kill_switch_runs_no_repo_code() {
  mkrepo; mkdir -p "$REPO/main/tests"; local mark="$REPO/RAN"
  printf '#!/bin/bash\ntouch %q\n' "$mark" > "$REPO/main/tests/a.sh"; chmod +x "$REPO/main/tests/a.sh"
  mktree || { rmrepo; return; }
  DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1 bash "$RTS" run "$TREE" shell bulk "$REPO/rows.tsv" tests/a.sh 2>/dev/null; local rc=$?
  assert_eq "$rc" "3" "R22: kill switch → exit 3"
  [ ! -e "$mark" ] && ok "R22: 저장소 코드가 돌지 않았다" || no "R22: kill switch 아래에서 저장소 코드가 돌았다"
  # 양성 대조 — 스위치 없이는 같은 픽스처가 실제로 돈다.
  bash "$RTS" run "$TREE" shell bulk "$REPO/rows2.tsv" tests/a.sh 2>/dev/null
  [ -e "$mark" ] && ok "R22 양성 대조: 스위치 없이 돈다" || no "R22 양성 대조 실패 — 픽스처가 원래 안 돈다"
  rmrepo
}
# R22 — setup 단계도 저장소 코드의 경로다: 추적되는 venv/__main__.py 를 `python3 -m venv` 가 실행한다.
case_R22_kill_switch_blocks_setup_step() {
  mkrepo; mkdir -p "$REPO/main/tests" "$REPO/main/venv"; local mark="$REPO/SETUP_RAN"
  printf 'x\n' > "$REPO/main/requirements.txt"; printf '.venv/\n' > "$REPO/main/.gitignore"
  printf 'import unittest\nclass T(unittest.TestCase):\n    def test_a(self):\n        pass\n' > "$REPO/main/tests/test_a.py"
  : > "$REPO/main/venv/__init__.py"; printf 'open(%s, "w").close()\n' "\"$mark\"" > "$REPO/main/venv/__main__.py"
  mktree || { rmrepo; return; }
  DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1 bash "$RTS" run "$TREE" unittest per-unit "$REPO/rows.tsv" tests/test_a.py 2>/dev/null; local rc=$?
  assert_eq "$rc" "3" "R22: setup 이 있는 어댑터도 kill switch → exit 3"
  [ ! -e "$mark" ] && ok "R22: kill switch 아래에서 setup 이 저장소 코드를 실행하지 않았다" || no "R22: setup 단계에서 저장소 코드가 돌았다"
  bash "$RTS" run "$TREE" unittest per-unit "$REPO/rows2.tsv" tests/test_a.py >/dev/null 2>&1
  [ -e "$mark" ] && ok "R22 양성 대조: 스위치 없이는 setup 이 이 픽스처의 코드를 실행한다" || no "R22 양성 대조 실패 — 픽스처가 setup 에 닿지 않는다"
  rmrepo
}
# 카고 빌드 산출물은 트리마다 따로 둔다(R11 의 두 축 분리).
case_cargo_target_dir_is_per_tree() {
  mkrepo; printf '[package]\nname="x"\n' > "$REPO/main/Cargo.toml"
  mktree || { rmrepo; return; }
  local bin obs; bin=$(mktemp -d); obs="$bin/obs"
  printf '#!/bin/bash\nprintf "%%s\\n" "$CARGO_TARGET_DIR" > %q\nexit 0\n' "$obs" > "$bin/cargo"; chmod +x "$bin/cargo"
  PATH="$bin:/usr/bin:/bin" bash "$RTS" run "$TREE" cargo bulk "$REPO/rows.tsv" BULK 2>/dev/null
  assert_eq "$(cat "$obs" 2>/dev/null)" "$TREE/target" "cargo 는 그 트리의 target 에 빌드한다"
  rm -rf "$bin"; rmrepo
}
for c in case_detect_pytest case_detect_unittest case_detect_pytest_declared case_detect_shell \
         case_detect_jest case_detect_vitest case_detect_go case_detect_cargo case_detect_make \
         case_detect_npm_script case_detect_zero case_detect_polyglot case_detect_js_ambiguous_is_loud \
         case_detect_malformed_package_json_is_loud case_R22_detect_imports_no_repo_module case_granularity_table case_adapter_count_claims_match \
         case_R14_tree_without_adapter_is_unrun case_R3_missing_toolchain_is_unrun \
         case_R3_setup_failure_is_unrun case_R3_exit_127_is_unrun case_R4_other_exit_is_error_not_unrun \
         case_R21_go_package_without_tests_is_absent case_R22_kill_switch_runs_no_repo_code \
         case_cargo_target_dir_is_per_tree case_R22_kill_switch_blocks_setup_step; do
  echo "== $c"; $c
done
finish
