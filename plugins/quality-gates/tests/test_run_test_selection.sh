#!/usr/bin/env bash
# test_run_test_selection.sh — assign · run · unrun · pending 의 행 파일 계약.
# 요구: R5 · R7 · R11 · R15 · R16 · R17 · R20 · R21 (docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md §요구 목록)
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RTS="$(cd -- "$SCRIPT_DIR/.." && pwd)/scripts/run-test-selection.sh"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

REPO=""; TREE=""
mkrepo() {
  REPO=$(mktemp -d) && [ -d "$REPO" ] || { echo "mktemp 실패" >&2; exit 1; }
  git init -q -b main "$REPO/main" || exit 1
  git -C "$REPO/main" config user.email t@t; git -C "$REPO/main" config user.name t
  git -C "$REPO/main" config commit.gpgsign false
  mkdir -p "$REPO/main/tests"; printf 'x\n' > "$REPO/main/README"
}
shtest() {   # shtest <relpath> <exit> — 실행 비트가 있는 shell 테스트
  mkdir -p "$REPO/main/$(dirname "$1")"
  printf '#!/bin/bash\nexit %s\n' "$2" > "$REPO/main/$1"; chmod +x "$REPO/main/$1"
}
mktree() {
  ( cd "$REPO/main" && git add -A && git commit -qm t ) || { no "픽스처 커밋 실패"; return 1; }
  git -C "$REPO/main" worktree add -q --detach "$REPO/wt" HEAD || { no "픽스처 worktree 실패"; return 1; }
  TREE="$REPO/wt"
}
rmrepo() { cd / && rm -rf "$REPO"; }
row_of() { awk -F'\t' -v u="$2" '$1 == u { print $2 "\t" $3 "\t" $4 }' "$1"; }
trailer() { tail -n 1 "$1"; }
assign() { printf '%s\n' "$@" | bash "$RTS" assign "$TREE" "$REPO/assign.tsv" 2>/dev/null; }
arow() { awk -F'\t' -v u="$1" '$1 == u { print $2 "\t" $3 }' "$REPO/assign.tsv"; }

# ── assign ──────────────────────────────────────────────────────────────────────
# R17 — 배정 파일은 꼬리 줄(감지된 어댑터 · 행 수)로 끝난다. 생산자가 끝까지 썼다는 증거다.
case_R17_assign_writes_trailer() {
  mkrepo; shtest tests/a.sh 0; mktree || { rmrepo; return; }
  assign tests/a.sh; local rc=$?
  assert_eq "$rc" "0" "R17: assign exit 0"
  assert_eq "$(trailer "$REPO/assign.tsv")" "#qg-assign	adapters=shell	rows=1" "R17: 꼬리 줄"
  rmrepo
}
# R17 — 사용 오류로 죽은 assign 은 배정 파일을 남기지 않는다(빈 파일이 「배정할 것 없음」으로 읽히지 않게).
case_R17_failed_assign_leaves_no_file() {
  mkrepo; mktree || { rmrepo; return; }
  printf 'x\n' | bash "$RTS" assign "$REPO/no-such-tree" "$REPO/assign.tsv" 2>/dev/null; local rc=$?
  assert_eq "$rc" "2" "R17: 없는 트리 → exit 2"
  [ ! -e "$REPO/assign.tsv" ] && ok "R17: 배정 파일이 생기지 않았다" || no "R17: 실패한 assign 이 파일을 남겼다"
  rmrepo
}
# R20 — 트리 밖으로 나가는 후보(절대경로 · `..` · 밖을 가리키는 링크)는 claim 되지 않고 unclaimed 다.
case_R20_assign_refuses_units_outside_tree() {
  mkrepo; shtest tests/a.sh 0; mkdir -p "$REPO/outside/tests"; printf '#!/bin/bash\n' > "$REPO/outside/tests/x.sh"
  chmod +x "$REPO/outside/tests/x.sh"; mktree || { rmrepo; return; }
  ln -s "$REPO/outside/tests" "$TREE/tests/escape"
  assign "/etc/passwd" "../outside/tests/x.sh" "tests/escape/x.sh" tests/a.sh
  assert_eq "$(arow /etc/passwd)" "unclaimed	file" "R20: 절대경로 → unclaimed"
  assert_eq "$(arow ../outside/tests/x.sh)" "unclaimed	file" "R20: .. → unclaimed"
  assert_eq "$(arow tests/escape/x.sh)" "unclaimed	file" "R20: 밖을 가리키는 링크 → unclaimed"
  assert_eq "$(arow tests/a.sh)" "shell	file" "R20 양성 대조: 트리 안 shell 테스트는 claim"
  rmrepo
}
# R20 — shell 은 tests/*.sh 이면서 실행 비트가 있을 때만 claim 한다.
case_R20_shell_scope() {
  mkrepo; shtest tests/a.sh 0; shtest scripts/b.sh 0; printf '#!/bin/bash\n' > "$REPO/main/tests/c.sh"
  mktree || { rmrepo; return; }
  assign scripts/b.sh tests/c.sh tests/a.sh
  assert_eq "$(arow scripts/b.sh)" "unclaimed	file" "R20: tests/ 밖 .sh → unclaimed"
  assert_eq "$(arow tests/c.sh)" "unclaimed	file" "R20: 실행 비트 없음 → unclaimed"
  assert_eq "$(arow tests/a.sh)" "shell	file" "R20 양성 대조"
  rmrepo
}
# R21 — unittest 는 판정하지 못하는 파일을 claim 하지 않는다.
case_R21_unittest_refuses_unjudgeable_files() {
  mkrepo
  printf 'def test_bare():\n    assert False\n' > "$REPO/main/tests/test_bare.py"
  printf 'from unittest.mock import patch\nclass TestHelper:\n    def test_x(self):\n        pass\n' > "$REPO/main/tests/test_plain_class.py"
  printf 'import unittest\nclass T(unittest.TestCase):\n    def test_x(self):\n        pass\n' > "$REPO/main/tests/test_real.py"
  printf 'import unittest\nclass T(unittest.TestCase):\n    def test_x(self):\n        pass\ndef test_bare():\n    assert False\n' > "$REPO/main/tests/test_mixed.py"
  mktree || { rmrepo; return; }
  assign tests/test_bare.py tests/test_plain_class.py tests/test_real.py tests/test_mixed.py
  assert_eq "$(arow tests/test_bare.py)" "unclaimed	file" "R21: 모듈 레벨 bare def test → unclaimed"
  assert_eq "$(arow tests/test_plain_class.py)" "unclaimed	file" "R21: TestCase 아닌 class Test → unclaimed"
  assert_eq "$(arow tests/test_mixed.py)" "unclaimed	file" "R21: TestCase + 모듈 레벨 bare def test 섞임 → unclaimed"
  assert_eq "$(arow tests/test_real.py)" "unittest	file" "R21 양성 대조: TestCase 하위클래스 → unittest"
  rmrepo
}
# R21 — go 는 *_test.go 를 패키지 unit 으로 접는다.
case_R21_go_unit_is_package() {
  mkrepo; mkdir -p "$REPO/main/pkg"; printf 'module x\n' > "$REPO/main/go.mod"
  printf 'package pkg\n' > "$REPO/main/pkg/a_test.go"; printf 'package pkg\n' > "$REPO/main/pkg/b_test.go"
  mktree || { rmrepo; return; }
  assign pkg/a_test.go pkg/b_test.go pkg/a.go
  assert_eq "$(arow pkg)" "go	package" "R21: *_test.go → 패키지 unit"
  assert_eq "$(grep -c '^pkg	' "$REPO/assign.tsv")" "1" "R21: 같은 패키지는 한 행"
  assert_eq "$(arow pkg/a.go)" "unclaimed	file" "R21: *_test.go 아닌 go 파일은 claim 안 함"
  rmrepo
}
# R16 — 어느 어댑터도 못 돌리는 후보는 unclaimed 행으로 남는다(조용히 사라지지 않는다).
case_R16_unhandled_candidate_is_unclaimed() {
  mkrepo; printf 'x\n' > "$REPO/main/README"; mktree || { rmrepo; return; }
  assign spec/foo_spec.rb
  assert_eq "$(arow spec/foo_spec.rb)" "unclaimed	file" "R16: 지원하지 않는 후보 → unclaimed"
  assert_eq "$(trailer "$REPO/assign.tsv")" "#qg-assign	adapters=-	rows=1" "R16: 감지 0 은 adapters=-"
  rmrepo
}
case_bulk_absorbs_residual() {
  mkrepo; printf '[package]\nname="x"\n' > "$REPO/main/Cargo.toml"; printf 'test:\n\ttrue\n' > "$REPO/main/Makefile"
  mktree || { rmrepo; return; }
  local err; err=$(printf 'src/lib.rs\n' | bash "$RTS" assign "$TREE" "$REPO/assign.tsv" 2>&1 >/dev/null)
  assert_eq "$(arow BULK)" "cargo	bulk" "잔여는 첫 bulk 러너가 흡수"
  assert_contains "$err" "미실행 러너: make" "흡수하지 않은 bulk 러너를 알린다"
  rmrepo
}

for c in case_R17_assign_writes_trailer case_R17_failed_assign_leaves_no_file \
         case_R20_assign_refuses_units_outside_tree case_R20_shell_scope \
         case_R21_unittest_refuses_unjudgeable_files case_R21_go_unit_is_package \
         case_R16_unhandled_candidate_is_unclaimed case_bulk_absorbs_residual; do
  echo "== $c"; $c
done
finish
