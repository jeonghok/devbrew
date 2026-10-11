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

for c in case_detect_pytest case_detect_unittest case_detect_pytest_declared case_detect_shell \
         case_detect_jest case_detect_vitest case_detect_go case_detect_cargo case_detect_make \
         case_detect_npm_script case_detect_zero case_detect_polyglot case_detect_js_ambiguous_is_loud \
         case_detect_malformed_package_json_is_loud case_granularity_table case_adapter_count_claims_match; do
  echo "== $c"; $c
done
finish
