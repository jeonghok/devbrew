#!/usr/bin/env bash
# test_resolve_baseline.sh — scripts/resolve-baseline.sh (design §5.2 R-init, AC4/AC5/AC6/AC37).
# 각 케이스는 mktemp 아래 일회용 git 레포를 만든다 (fail-closed: 실제 레포에서 git 실행 금지).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RESOLVE="$PLUGIN_ROOT/scripts/resolve-baseline.sh"
REVIEW_SCOPE="$PLUGIN_ROOT/scripts/check-review-scope.sh"
CANDIDATES="$PLUGIN_ROOT/scripts/compute-test-scope-candidates.sh"

PASS=0; FAIL=0; REPO=""
pass() { PASS=$((PASS + 1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }
field() { printf '%s\n' "$2" | awk -v k="$1:" '$1 == k { print $2 }'; }

mk_repo() {   # main + feature(1 commit ahead), CWD = repo
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo base > a.txt; git add a.txt; git commit -qm base
  git checkout -q -b feature
  echo work >> a.txt; git commit -qam work
}
cleanup() { cd / && rm -rf "$REPO"; }

# T2-a: 정상 — 4키 + degraded:no + merge_base가 main의 tip
case_normal() {
  mk_repo
  local out; out=$(bash "$RESOLVE")
  local expect; expect=$(git rev-parse main)
  if [[ "$(field base "$out")" == "main" \
     && "$(field base_ref "$out")" == "main" \
     && "$(field merge_base "$out")" == "$expect" \
     && "$(field degraded "$out")" == "no" ]]; then
    pass "정상 레포 → base/base_ref/merge_base/degraded 4키"
  else fail "정상 (got: $out)"; fi
  cleanup
}

# T2-b: detached HEAD → degraded
case_detached() {
  mk_repo
  git checkout -q --detach HEAD
  local out; out=$(bash "$RESOLVE")
  if [[ "$(field degraded "$out")" == "yes" && "$(field merge_base "$out")" == "-" ]]; then
    pass "detached HEAD → degraded:yes, merge_base:-"
  else fail "detached (got: $out)"; fi
  cleanup
}

# T2-c: shallow clone → degraded  (M9: shallow 감지를 지우면 여기가 RED)
case_shallow() {
  mk_repo
  local src="$REPO" dst; dst=$(mktemp -d)
  git clone -q --depth 1 "file://$src" "$dst/s" 2>/dev/null
  cd "$dst/s" || { fail "shallow clone 실패"; rm -rf "$dst"; cleanup; return; }
  local out; out=$(bash "$RESOLVE")
  if [[ "$(field degraded "$out")" == "yes" ]]; then
    pass "shallow clone → degraded:yes"
  else fail "shallow (got: $out)"; fi
  cd / && rm -rf "$dst"; cleanup
}

# T2-d: base 미해결 (main/master 없음) → degraded
case_no_base() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b topic
  echo x > a.txt; git add a.txt; git commit -qm x
  local out; out=$(bash "$RESOLVE")
  if [[ "$(field degraded "$out")" == "yes" && "$(field base "$out")" == "-" ]]; then
    pass "base 미해결 → degraded:yes"
  else fail "no-base (got: $out)"; fi
  cleanup
}

# T3: 두 소비자에 `main` 하드코딩 0회 + 실제 호출 존재
case_no_hardcoded_main() {
  local bad=0
  # `main`을 baseline으로 쓰는 리터럴 패턴만 검사 (주석/산문의 'main' 단어는 무관)
  grep -nE '(verify --quiet main|main\.\.\.HEAD|main\.\.HEAD|log --oneline main)' \
       "$REVIEW_SCOPE" "$CANDIDATES" && bad=1
  if [[ $bad -eq 0 ]]; then pass "두 소비자에 main 하드코딩 baseline 0회"
  else fail "main 하드코딩 잔존"; fi
  if grep -q 'resolve-baseline.sh' "$REVIEW_SCOPE" && grep -q 'resolve-baseline.sh' "$CANDIDATES"; then
    pass "두 소비자가 resolve-baseline.sh를 실제 호출"
  else fail "resolve-baseline.sh 호출 부재"; fi
}

# T4: check-review-scope.sh 출력 계약 불변 (5키 + exit 0)
case_review_scope_contract() {
  mk_repo
  local out rc; out=$(bash "$REVIEW_SCOPE"); rc=$?
  local keys; keys=$(printf '%s\n' "$out" | awk -F: '{print $1}' | tr '\n' ',')
  if [[ $rc -eq 0 && "$keys" == "changes_exist,branch_ahead_count,worktree_dirty,base,degraded," ]]; then
    pass "check-review-scope 5키 순서 + exit 0 불변"
  else fail "check-review-scope 계약 (rc=$rc keys=$keys)"; fi
  cleanup
}

# T29: --total이 리포 전체 테스트 파일 수를 emit
case_total() {
  mk_repo
  mkdir -p tests src
  : > tests/test_a.py; : > tests/test_b.py; : > src/plain.py
  git add -A; git commit -qm tests
  local out; out=$(bash "$CANDIDATES" --total)
  if [[ "$out" == "2" ]]; then pass "--total → 2 (테스트 2, 비테스트 1)"
  else fail "--total (got: '$out', expected 2)"; fi
  cleanup
}

for c in case_normal case_detached case_shallow case_no_base \
         case_no_hardcoded_main case_review_scope_contract case_total; do
  echo "== $c"; $c
done
echo "── resolve-baseline: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
