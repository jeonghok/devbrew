#!/usr/bin/env bash
# test_resolve_baseline.sh — scripts/resolve-baseline.sh (design §5.2 R-init, AC4/AC5/AC6/AC37).
# 각 케이스는 mktemp 아래 일회용 git 레포를 만든다 (fail-closed: 실제 레포에서 git 실행 금지).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RESOLVE="$PLUGIN_ROOT/scripts/resolve-baseline.sh"
REVIEW_SCOPE="$PLUGIN_ROOT/scripts/check-review-scope.sh"
CANDIDATES="$PLUGIN_ROOT/scripts/compute-test-scope-candidates.sh"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
REPO=""

NO_DEFAULT_LINE="[resolve-baseline] 기본 브랜치를 찾지 못했다 — origin/HEAD 가 없거나 가리키는 브랜치가 없다. git remote set-head origin --auto 로 고친다"

mk_bare() {   # main + feature(1 commit ahead), CWD = repo, 원격 ref 없음
  REPO=$(mktemp -d) && [ -d "$REPO" ] || exit 1
  REPO=$(cd "$REPO" && pwd -P) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo base > a.txt; git add a.txt; git commit -qm base
  git checkout -q -b feature
  echo work >> a.txt; git commit -qam work
}
mk_repo() {   # mk_bare + origin/main · origin/HEAD → origin/main (main 의 tip)
  mk_bare
  git update-ref refs/remotes/origin/main main
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
}
cleanup() { cd / && rm -rf "$REPO"; }

# T2-a: 정상 — 키 + degraded:no + merge_base가 origin/HEAD 가 가리키는 tip
case_normal() {
  mk_repo
  local out err; out=$(bash "$RESOLVE" 2>"$REPO/.git/rb.err"); err=$(cat "$REPO/.git/rb.err")
  local expect; expect=$(git rev-parse main)
  if [[ "$(field base "$out")" == "main" \
     && "$(field base_ref "$out")" == "refs/remotes/origin/main" \
     && "$(field merge_base "$out")" == "$expect" \
     && "$(field degraded "$out")" == "no" \
     && "$(field degraded_reason "$out")" == "-" \
     && "$(printf '%s\n' "$out" | awk -F: '{print $1}' | tr '\n' ',')" == "base,base_ref,merge_base,degraded,degraded_reason,same_as_head,ahead," \
     && -z "$err" ]]; then
    ok "정상 레포 → base/base_ref/merge_base/degraded/degraded_reason · stderr 없음"
  else no "정상 (got: $out | err: $err)"; fi
  cleanup
}

# 기준은 origin/HEAD 하나 — origin/main · origin/master · 로컬 main · master 로 대신하지 않는다.
case_no_fallback() {
  local kind out err
  for kind in origin-main origin-master local-main local-master; do
    mk_bare
    case "$kind" in
      origin-main)   git update-ref refs/remotes/origin/main main ;;
      origin-master) git update-ref refs/remotes/origin/master main ;;
      local-main)    : ;;
      local-master)  git branch -q -m main master ;;
    esac
    out=$(bash "$RESOLVE" 2>"$REPO/.git/rb.err"); err=$(cat "$REPO/.git/rb.err")
    if [[ "$(field degraded "$out")" == "yes" \
       && "$(field degraded_reason "$out")" == "no-default-branch" \
       && "$(field base "$out")" == "-" \
       && "$err" == "$NO_DEFAULT_LINE" ]]; then
      ok "origin/HEAD 없음 + $kind 만 → degraded:yes · no-default-branch · 안내 한 줄"
    else no "$kind 로 대신했다 (got: $out | err: $err)"; fi
    cleanup
  done
}

# 개명 뒤 dangling origin/HEAD — 가리키는 ref 가 없으면 같은 사유(origin/main 이 있어도).
case_dangling_origin_head() {
  mk_bare
  git update-ref refs/remotes/origin/main main
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/master
  local out err; out=$(bash "$RESOLVE" 2>"$REPO/.git/rb.err"); err=$(cat "$REPO/.git/rb.err")
  if [[ "$(field degraded "$out")" == "yes" \
     && "$(field degraded_reason "$out")" == "no-default-branch" \
     && "$err" == "$NO_DEFAULT_LINE" ]]; then
    ok "dangling origin/HEAD → no-default-branch · 안내 한 줄"
  else no "dangling origin/HEAD (got: $out | err: $err)"; fi
  cleanup
}

# 짧은 이름 origin/main 을 가로채는 로컬 브랜치 · 태그 — 기준선은 원격 추적 커밋 그대로다.
case_planted_short_name() {
  local kind out remote rb_ref
  for kind in branch tag; do
    mk_repo
    remote=$(git rev-parse refs/remotes/origin/main)
    case "$kind" in
      branch) git branch -q origin/main HEAD ;;
      tag)    git tag origin/main HEAD ;;
    esac
    # 양성 대조: 옛 짧은 줄(origin/main)은 심은 ref(토픽 끝)로 풀린다 — 위험이 실재한다.
    if [[ "$(git rev-parse --verify --quiet origin/main 2>/dev/null)" == "$(git rev-parse HEAD)" \
       && "$(git rev-parse HEAD)" != "$remote" ]]; then
      ok "양성 대조($kind): 짧은 이름 origin/main 은 심은 ref 로 풀린다"
    else no "양성 대조($kind): 짧은 이름이 심은 ref 로 풀리지 않았다 — 픽스처가 위험을 만들지 못했다"; fi
    out=$(bash "$RESOLVE" 2>/dev/null)
    rb_ref=$(field base_ref "$out")
    if [[ "$(field degraded "$out")" == "no" \
       && "$(git rev-parse --verify --quiet "$rb_ref" 2>/dev/null)" == "$remote" \
       && "$(field merge_base "$out")" == "$remote" \
       && "$(field same_as_head "$out")" == "no" && "$(field ahead "$out")" == "1" \
       && "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" == "7" ]]; then
      ok "$kind origin/main 이 있어도 base_ref · merge_base 는 원격 추적 커밋(7줄)"
    else no "$kind origin/main 에 가로채였다 (got: $out)"; fi
    cleanup
  done
}

# origin/HEAD 가 refs/remotes/origin/ 밖(로컬 브랜치)을 가리키면 기본 브랜치로 받지 않는다.
case_origin_head_outside_remote() {
  mk_bare
  git symbolic-ref refs/remotes/origin/HEAD refs/heads/main
  local out err; out=$(bash "$RESOLVE" 2>"$REPO/.git/rb.err"); err=$(cat "$REPO/.git/rb.err")
  if [[ "$(field degraded "$out")" == "yes" \
     && "$(field degraded_reason "$out")" == "no-default-branch" \
     && "$err" == "$NO_DEFAULT_LINE" ]]; then
    ok "origin/HEAD → refs/heads/main → no-default-branch · 안내 한 줄"
  else no "origin/HEAD 가 로컬 브랜치를 가리킴 (got: $out | err: $err)"; fi
  cleanup
}

# 기본 브랜치 trunk(진짜 원격 · set-head --auto) → base: trunk · base_ref: refs/remotes/origin/trunk.
case_trunk_default() {
  local d; d=$(mktemp -d) && [ -d "$d" ] || exit 1
  d=$(cd "$d" && pwd -P) || exit 1
  git init -q --bare -b trunk "$d/remote.git"
  git init -q -b trunk "$d/w"; cd "$d/w" || exit 1
  git config user.email t@t.test; git config user.name tester
  echo base > a.txt; git add a.txt; git commit -qm base
  git remote add origin "$d/remote.git"; git push -q origin trunk
  git remote set-head origin --auto >/dev/null
  git checkout -q -b feature; echo w >> a.txt; git commit -qam w
  local out; out=$(bash "$RESOLVE" 2>/dev/null)
  if [[ "$(field base "$out")" == "trunk" \
     && "$(field base_ref "$out")" == "refs/remotes/origin/trunk" \
     && "$(field degraded "$out")" == "no" \
     && "$(field ahead "$out")" == "1" ]]; then
    ok "trunk 기본 → base: trunk · base_ref: refs/remotes/origin/trunk"
  else no "trunk (got: $out)"; fi
  cd / && rm -rf "$d"
}

# 사유 키 — degrade 갈래마다 자기 사유.
case_reasons() {
  local d out
  d=$(mktemp -d) && [ -d "$d" ] || exit 1
  d=$(cd "$d" && pwd -P) || exit 1
  mkdir "$d/plain"
  out=$(cd "$d/plain" && GIT_CEILING_DIRECTORIES="$d" bash "$RESOLVE" 2>/dev/null)
  assert_eq "$(field degraded_reason "$out")" not-a-repo "레포 밖 → not-a-repo"
  git init -q "$d/empty"
  out=$(cd "$d/empty" && bash "$RESOLVE" 2>/dev/null)
  assert_eq "$(field degraded_reason "$out")" no-head "커밋 없음 → no-head"
  rm -rf "$d"
  mk_repo; git checkout -q --detach HEAD
  out=$(bash "$RESOLVE" 2>/dev/null)
  assert_eq "$(field degraded_reason "$out")" detached "detached HEAD → detached"
  cleanup
  mk_repo
  git update-ref refs/remotes/origin/main "$(git commit-tree "$(git write-tree)" -m orphan </dev/null)"
  out=$(bash "$RESOLVE" 2>/dev/null)
  assert_eq "$(field degraded_reason "$out")" merge-base "공통 조상 없음 → merge-base"
  cleanup
}

# T2-b: detached HEAD → degraded
case_detached() {
  mk_repo
  git checkout -q --detach HEAD
  local out; out=$(bash "$RESOLVE")
  if [[ "$(field degraded "$out")" == "yes" && "$(field merge_base "$out")" == "-" ]]; then
    ok "detached HEAD → degraded:yes, merge_base:-"
  else no "detached (got: $out)"; fi
  cleanup
}

# T2-c: shallow clone → degraded  (M9: shallow 감지를 지우면 여기가 RED)
case_shallow() {
  mk_repo
  local src="$REPO" dst; dst=$(mktemp -d)
  git clone -q --depth 1 "file://$src" "$dst/s" 2>/dev/null
  cd "$dst/s" || { no "shallow clone 실패"; rm -rf "$dst"; cleanup; return; }
  local out; out=$(bash "$RESOLVE")
  if [[ "$(field degraded "$out")" == "yes" && "$(field degraded_reason "$out")" == "shallow" ]]; then
    ok "shallow clone → degraded:yes · degraded_reason: shallow"
  else no "shallow (got: $out)"; fi
  cd / && rm -rf "$dst"; cleanup
}

# T2-d: base 미해결 (main/master 없음) → degraded
case_no_base() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b topic
  echo x > a.txt; git add a.txt; git commit -qm x
  local out; out=$(bash "$RESOLVE")
  if [[ "$(field degraded "$out")" == "yes" && "$(field base "$out")" == "-" \
     && "$(field degraded_reason "$out")" == "no-default-branch" ]]; then
    ok "base 미해결 → degraded:yes · no-default-branch"
  else no "no-base (got: $out)"; fi
  cleanup
}

# T3: 두 소비자에 `main` 하드코딩 0회 + 실제 호출 존재
case_no_hardcoded_main() {
  local bad=0
  # `main`을 baseline으로 쓰는 리터럴 패턴만 검사 (주석/산문의 'main' 단어는 무관)
  grep -nE '(verify --quiet main|main\.\.\.HEAD|main\.\.HEAD|log --oneline main)' \
       "$REVIEW_SCOPE" "$CANDIDATES" && bad=1
  if [[ $bad -eq 0 ]]; then ok "두 소비자에 main 하드코딩 baseline 0회"
  else no "main 하드코딩 잔존"; fi
  if grep -q 'resolve-baseline.sh' "$REVIEW_SCOPE" && grep -q 'resolve-baseline.sh' "$CANDIDATES"; then
    ok "두 소비자가 resolve-baseline.sh를 실제 호출"
  else no "resolve-baseline.sh 호출 부재"; fi
}

# T4: check-review-scope.sh 출력 계약 (6키 + exit 0)
case_review_scope_contract() {
  mk_repo
  local out rc; out=$(bash "$REVIEW_SCOPE"); rc=$?
  local keys; keys=$(printf '%s\n' "$out" | awk -F: '{print $1}' | tr '\n' ',')
  if [[ $rc -eq 0 && "$keys" == "changes_exist,branch_ahead_count,worktree_dirty,base,degraded,degraded_reason," \
     && "$(field degraded_reason "$out")" == "-" ]]; then
    ok "check-review-scope 6키 순서 + exit 0 · degraded_reason: -"
  else no "check-review-scope 계약 (rc=$rc keys=$keys)"; fi
  cleanup
  # 기준선 사유를 자기 출력에 싣는다.
  mk_bare
  out=$(bash "$REVIEW_SCOPE" 2>/dev/null); rc=$?
  if [[ $rc -eq 0 && "$(field degraded "$out")" == "yes" \
     && "$(field degraded_reason "$out")" == "no-default-branch" ]]; then
    ok "check-review-scope 가 기준선 사유 no-default-branch 를 싣는다"
  else no "check-review-scope 사유 (rc=$rc out=$out)"; fi
  cleanup
}

# ── qg iter-2 CRITICAL — merge_base ref 변조 ─────────────────────────────────
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
    ok "feature 1커밋 앞섬 → same_as_head:no, ahead:1"
  else no "feature 정상 (got: $out)"; fi

  # (2) **변조** — origin/HEAD 가 가리키는 ref 를 HEAD 로 옮긴다. update-ref 한 번이면 된다.
  git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"
  out=$(bash "$RESOLVE")
  if [[ "$(field same_as_head "$out")" == "yes" && "$(field ahead "$out")" == "0" \
     && "$(field degraded "$out")" == "no" ]]; then
    ok "base ref 변조로 merge_base==HEAD → same_as_head:yes (degraded 와 별개 키)"
  else no "변조 감지 (got: $out)"; fi
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
    ok "main 위 미커밋 변경 → same_as_head:yes 인데 floor 는 changes_exist:yes/degraded:no"
  else no "review floor 보존 (rb: $rb | scope: $out rc=$rc)"; fi
  cleanup
}

# degrade 경로도 7키를 전부 낸다 — 키를 빠뜨리면 소비자의 `field` 조회가 빈 문자열을
# 받고, 빈 문자열은 `!= yes` 라 **fail-open** 으로 읽힌다.
case_degraded_emits_all_keys() {
  mk_repo
  git checkout -q --detach HEAD
  local out; out=$(bash "$RESOLVE")
  local keys; keys=$(printf '%s\n' "$out" | awk -F: '{print $1}' | tr '\n' ',')
  if [[ "$keys" == "base,base_ref,merge_base,degraded,degraded_reason,same_as_head,ahead," \
     && "$(field same_as_head "$out")" == "-" && "$(field ahead "$out")" == "-" ]]; then
    ok "degraded 경로도 7키 전부 (same_as_head:- ahead:-)"
  else no "degraded 키 (got keys=$keys out=$out)"; fi
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
    ok "same_as_head:yes 고정, worktree_dirty 가 dirty/clean 을 구별 → 판별자 결정 가능"
  else no "판별자 구별력 (dirty: rb=$rb_d sc=$sc_d | clean: rb=$rb_c sc=$sc_c)"; fi
  cleanup
}

# T29: --total이 리포 전체 테스트 파일 수를 emit
case_total() {
  mk_repo
  mkdir -p tests src
  : > tests/test_a.py; : > tests/test_b.py; : > src/plain.py
  git add -A; git commit -qm tests
  local out; out=$(bash "$CANDIDATES" --total)
  if [[ "$out" == "2" ]]; then ok "--total → 2 (테스트 2, 비테스트 1)"
  else no "--total (got: '$out', expected 2)"; fi
  cleanup
}

for c in case_normal case_no_fallback case_dangling_origin_head case_origin_head_outside_remote \
         case_planted_short_name \
         case_trunk_default case_reasons \
         case_detached case_shallow case_no_base \
         case_same_as_head case_same_as_head_does_not_kill_review_floor \
         case_same_as_head_x_worktree_dirty \
         case_degraded_emits_all_keys \
         case_no_hardcoded_main case_review_scope_contract case_total; do
  echo "== $c"; $c
done
finish
