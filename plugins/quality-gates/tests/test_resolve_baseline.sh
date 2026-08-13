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

# ── /qg iter-2 CRITICAL — merge_base ref 변조 ─────────────────────────────────
#
# base 후보 ref 는 전부 **공유 common gitdir** 에 있고, `run` 이 실행하는 저장소
# 코드가 호스트 권한으로 `git update-ref` 를 할 수 있다. base 를 HEAD 로 옮기면
# 기준선 트리가 리뷰 대상 코드 자체가 되어 모든 진짜 회귀가 (fail,fail)=PRE_EXISTING
# 으로 접힌다. 이 스크립트는 **판정하지 않고 사실만** 낸다 — 정상(main 위 미커밋
# 작업)과 변조를 구분할 방법이 없기 때문이다. 소비자가 자기 축에서 결정한다.
case_same_as_head() {
  mk_repo
  # (1) feature 브랜치 정상 — base 가 뒤에 있다.
  local out; out=$(bash "$RESOLVE")
  if [[ "$(field same_as_head "$out")" == "no" && "$(field ahead "$out")" == "1" ]]; then
    pass "feature 1커밋 앞섬 → same_as_head:no, ahead:1"
  else fail "feature 정상 (got: $out)"; fi

  # (2) **변조** — refs/heads/main 을 HEAD 로 옮긴다. update-ref 한 번이면 된다.
  git update-ref refs/heads/main "$(git rev-parse HEAD)"
  out=$(bash "$RESOLVE")
  if [[ "$(field same_as_head "$out")" == "yes" && "$(field ahead "$out")" == "0" \
     && "$(field degraded "$out")" == "no" ]]; then
    pass "base ref 변조로 merge_base==HEAD → same_as_head:yes (degraded 와 별개 키)"
  else fail "변조 감지 (got: $out)"; fi
  cleanup
}

# 위 키가 **Review 게이트의 changes-exist floor 를 끄지 않는다.** merge_base==HEAD
# 는 `main` 위에서 커밋 없이 워킹트리만 고친 정상 상태로도 생긴다 — 거기서 degrade
# 하면 floor 가 통째로 꺼져 false-clean 이 돌아온다(v2.6.0 이 닫은 그 결함).
# 그래서 check-review-scope.sh 는 이 키를 읽지 않는다.
case_same_as_head_does_not_kill_review_floor() {
  mk_repo
  git checkout -q main
  echo dirty >> a.txt          # 커밋 없이 워킹트리만 변경 = merge_base == HEAD
  local rb; rb=$(bash "$RESOLVE")
  local out rc; out=$(bash "$REVIEW_SCOPE"); rc=$?
  if [[ "$(field same_as_head "$rb")" == "yes" \
     && $rc -eq 0 \
     && "$(field changes_exist "$out")" == "yes" \
     && "$(field degraded "$out")" == "no" ]]; then
    pass "main 위 미커밋 변경 → same_as_head:yes 인데 floor 는 changes_exist:yes/degraded:no"
  else fail "review floor 보존 (rb: $rb | scope: $out rc=$rc)"; fi
  cleanup
}

# degrade 경로도 6키를 전부 낸다 — 키를 빠뜨리면 소비자의 `field` 조회가 빈 문자열을
# 받고, 빈 문자열은 `!= yes` 라 **fail-open** 으로 읽힌다.
case_degraded_emits_all_keys() {
  mk_repo
  git checkout -q --detach HEAD
  local out; out=$(bash "$RESOLVE")
  local keys; keys=$(printf '%s\n' "$out" | awk -F: '{print $1}' | tr '\n' ',')
  if [[ "$keys" == "base,base_ref,merge_base,degraded,same_as_head,ahead," \
     && "$(field same_as_head "$out")" == "-" && "$(field ahead "$out")" == "-" ]]; then
    pass "degraded 경로도 6키 전부 (same_as_head:- ahead:-)"
  else fail "degraded 키 (got keys=$keys out=$out)"; fi
  cleanup
}

# T60(b) — AC62 정정(c)의 **판별자가 실제로 판별하는가** (라운드 7 spec review).
#
# AC62 초안은 `same_as_head: yes` **단독**으로 R4 를 스킵했고, 그것이 `main` 위
# 미커밋 작업에서 진짜 `NEW_REGRESSION`/FAIL 을 `BASELINE_UNRUNNABLE`/SKIP 으로
# 떨어뜨리는 것이 실측됐다. 정정된 판별자는 `same_as_head` × `worktree_dirty` 다.
#
# 이 케이스가 재는 것은 **판별자의 두 입력이 같은 상태(`same_as_head: yes`)에서
# 서로 다른 값을 실제로 낸다**는 것 — 즉 규칙이 결정 가능하다는 것. `worktree_dirty`
# 를 상수로 만드는 회귀(항상 yes / 항상 no)는 두 절 중 하나에서 RED 가 된다.
#
# **한계를 정직하게 적는다:** 이 규칙을 읽는 스크립트는 아직 없다(§6.7 AC62 정정
# (a)). 그래서 이것은 *규칙의 집행* 락이 아니라 *규칙이 필요로 하는 입력이 존재하고
# 구별력을 갖는다*는 락이다. 집행자가 생기기 전까지 그 이상은 잴 수 없다.
case_same_as_head_x_worktree_dirty() {
  mk_repo
  git checkout -q main

  # (1) 더러운 워킹트리 — 차등이 **가능한** 상태 (진행해야 함)
  echo dirty >> a.txt
  local rb_d sc_d; rb_d=$(bash "$RESOLVE"); sc_d=$(bash "$REVIEW_SCOPE")

  # (2) 같은 커밋, 깨끗한 워킹트리 — 차등이 **불가능한** 상태 (PASS 불가)
  git checkout -q -- a.txt
  local rb_c sc_c; rb_c=$(bash "$RESOLVE"); sc_c=$(bash "$REVIEW_SCOPE")

  if [[ "$(field same_as_head "$rb_d")" == "yes" \
     && "$(field same_as_head "$rb_c")" == "yes" \
     && "$(field worktree_dirty "$sc_d")" == "yes" \
     && "$(field worktree_dirty "$sc_c")" == "no" ]]; then
    pass "same_as_head:yes 고정, worktree_dirty 가 dirty/clean 을 구별 → 판별자 결정 가능"
  else fail "판별자 구별력 (dirty: rb=$rb_d sc=$sc_d | clean: rb=$rb_c sc=$sc_c)"; fi
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
         case_same_as_head case_same_as_head_does_not_kill_review_floor \
         case_same_as_head_x_worktree_dirty \
         case_degraded_emits_all_keys \
         case_no_hardcoded_main case_review_scope_contract case_total; do
  echo "== $c"; $c
done
echo "── resolve-baseline: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
