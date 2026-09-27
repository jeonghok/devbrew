#!/usr/bin/env bash
# test_topic_head.sh — scripts/topic-head.sh · qg-worktree.sh create-head --topic
#   (설계 §6.2.2–§6.2.6 · §6.4.1, AC3–AC7 · AC14 · AC15 · AC16)
#
# 각 케이스는 mktemp 아래 일회용 git 리포를 세운다 — 실제 리포에서 fixture git 실행 금지.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TH="$PLUGIN_ROOT/scripts/topic-head.sh"
WT="$PLUGIN_ROOT/scripts/qg-worktree.sh"
SEALER="$PLUGIN_ROOT/scripts/seal-worktree.sh"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

KEY='docs/x-design.md#pr1'
SID='sesstopic1234'
REPO=""
cleanup() { cd / && rm -rf "$REPO"; }

new_repo() {   # main 두 커밋(둘째가 $KEY 의 경로를 만든다). CWD = 리포
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q .
  git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo r0 > f.txt; git add f.txt; git commit -qm r0
  mkdir -p docs; echo '# design' > docs/x-design.md
  git add docs/x-design.md; git commit -qm "add design doc"
}

decl_commit() {   # <파일> <내용> <메시지> [키] — 토픽 선언 트레일러를 단 커밋
  echo "$2" > "$1"; git add "$1"
  git commit -qm "$3

Spec: ${4:-$KEY}"
}

fixed_keys() { printf '%s\n' "$1" | grep -E '^[a-z_]+: ' | grep -vc '^commit: '; }
commit_lines() { printf '%s\n' "$1" | sed -n 's/^commit: //p'; }

case_usage() {
  new_repo
  local rc
  bash "$TH" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "인자 없음: exit 2"
  bash "$TH" "$SID" --topic >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "--topic 값 없음: exit 2"
  bash "$TH" "$SID" --bogus x >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "모르는 플래그: exit 2"
  cleanup
}

case_no_declaration() {
  new_repo
  git checkout -q -b plain; echo p > p.txt; git add p.txt; git commit -qm "plain (선언 없음)"
  local out rc; out=$(bash "$TH" "$SID"); rc=$?
  assert_eq "$rc" "0" "선언 없음: exit 0"
  assert_eq "$(field status "$out")" "no-declaration" "선언 없음: status: no-declaration"
  assert_eq "$(field seal "$out")" "-" "선언 없음: 봉인을 뜨지 않는다"
  assert_eq "$(fixed_keys "$out")" "13" "선언 없음: 고정 키 13줄"
  assert_eq "$(commit_lines "$out" | grep -c .)" "0" "선언 없음: commit: 줄 없음"
  assert_eq "$(field in_base "$out")" "-" "선언 없음: in_base: -(resolve 전에 끝남)"
  cleanup
}

case_single_branch_topic() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  local C1; C1=$(git rev-parse HEAD)
  echo dirty > wip.txt
  local out S; out=$(bash "$TH" "$SID"); S=$(field seal "$out")
  assert_eq "$(field status "$out")" "ok" "단일 구성원: status: ok"
  assert_eq "$(fixed_keys "$out")" "13" "단일 구성원: 고정 키 13줄"
  assert_eq "$(field boundary "$out")" "$R" "단일 구성원: 경계 = 분기점"
  assert_grep "$S" '^[0-9a-f]{40}$' "단일 구성원: 봉인 SHA"
  assert_eq "$(field tips "$out")" "$S" "단일 구성원: 끝점은 봉인 하나(현재 tip 은 봉인의 조상)"
  assert_eq "$(field head_commit "$out")" "$S" "단일 구성원: 합칠 것이 없으면 head_commit = 봉인"
  assert_eq "$(field tree "$out")" "$(git rev-parse "$S^{tree}")" "단일 구성원: tree = 봉인의 트리"
  assert_grep "$(git ls-tree -r --name-only "$(field tree "$out")")" '^wip\.txt$' "미커밋 파일이 합친 트리에 있다"
  assert_eq "$(field commits "$out")" "1" "본 커밋 1"
  assert_eq "$(commit_lines "$out")" "$C1" "본 커밋 SHA 가 commit: 줄로 실린다(AC15)"
  assert_eq "$(field in_base "$out")" "0" "단일 구성원: in_base 0"
  assert_eq "$(printf '%s\n' "$out" | sed -n '5p')" "in_base: 0" "다섯째 줄이 in_base(13키 순서 — branches 다음)"
  cleanup
}

case_two_siblings_combined() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  local CA; CA=$(git rev-parse HEAD)
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  local CB; CB=$(git rev-parse HEAD)
  echo dirty > wip.txt
  local out T H; out=$(bash "$TH" "$SID"); T=$(field tree "$out"); H=$(field head_commit "$out")
  assert_eq "$(field status "$out")" "ok" "형제 둘: status: ok"
  local names; names=$(git ls-tree -r --name-only "$T")
  assert_grep "$names" '^a\.txt$' "합친 트리에 형제 topicA 의 변경(AC3)"
  assert_grep "$names" '^b\.txt$' "합친 트리에 현재 브랜치의 변경"
  assert_grep "$names" '^wip\.txt$' "합친 트리에 미커밋 변경(AC6 — 봉인을 먼저 넣었다)"
  assert_eq "$(git rev-parse "$H^{tree}")" "$T" "head_commit 의 트리 = tree"
  assert_not_grep "$H" "^$(field seal "$out")\$" "형제가 있으면 head_commit 은 봉인이 아니다"
  assert_eq "$(field commits "$out")" "2" "본 커밋 2"
  assert_eq "$(commit_lines "$out" | sort | paste -sd, -)" "$(printf '%s\n' "$CA" "$CB" | sort | paste -sd, -)" \
    "commit: 줄 = 두 선언 커밋(봉인은 토픽 커밋이 아니다)"
  cleanup
}

case_merged_member_is_baseline() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  local CA; CA=$(git rev-parse HEAD)
  git checkout -q main; git merge -q --no-ff topicA -m "merge topicA"
  git branch -q -D topicA
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  local out; out=$(bash "$TH" "$SID")
  assert_eq "$(field status "$out")" "ok" "머지된 앞 조각: status: ok"
  assert_eq "$(field in_base "$out")" "1" "머지된 앞 조각의 선언이 in_base 로 공시된다(AC4 재정의)"
  assert_eq "$(field branches "$out")" "topicB" "구성원은 topicB 뿐 — 머지된 topicA 는 기준선"
  assert_not_grep "$(commit_lines "$out")" "^$CA\$" "머지된 앞 조각의 커밋은 본 커밋이 아니다"
  assert_grep "$(commit_lines "$out")" '^[0-9a-f]{40}$' "본 커밋은 있다(양의 짝 — topicB 의 커밋)"
  assert_eq "$(field boundary "$out")" "$R" "경계 = topicB 의 분기점"
  assert_eq "$(fixed_keys "$out")" "13" "고정 키 13줄"
  cleanup
}

case_stack_after_front_merged() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  local TIPA; TIPA=$(git rev-parse HEAD)
  git checkout -q -b topicB; decl_commit b.txt b1 "b1 — A 위에 쌓음"
  git checkout -q main; git merge -q --no-ff topicA -m "merge topicA"
  git checkout -q topicB
  local out T B0; out=$(bash "$TH" "$SID"); T=$(field tree "$out"); B0=$(field boundary "$out")
  assert_eq "$(field status "$out")" "ok" "스택 앞 조각 머지 뒤: status: ok"
  assert_eq "$B0" "$TIPA" "경계 = topicA 의 끝(= topicB 와 main 의 merge-base)"
  assert_eq "$(git diff --name-only "$B0" "$T")" "b.txt" "리뷰 diff 는 b.txt 뿐 — 머지된 A 는 기준선"
  assert_grep "$(git ls-tree -r --name-only "$T")" '^a\.txt$' "합친 트리에는 A 의 파일이 있다(topicB 가 담고 있다)"
  assert_eq "$(field in_base "$out")" "1" "in_base 1"
  cleanup
}

case_conflict_lists_files() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit f.txt fromA "a1"
  git checkout -q -b topicB "$R"; decl_commit f.txt fromB "b1"
  local out; out=$(bash "$TH" "$SID")
  assert_eq "$(field status "$out")" "merge-conflict" "같은 파일을 달리 고친 형제: merge-conflict(AC7)"
  assert_grep "$(field conflicts "$out")" '(^|,)f\.txt(,|$)' "충돌 파일이 conflicts: 에 나열된다"
  assert_eq "$(field tree "$out")" "-" "충돌이면 tree: -"
  assert_eq "$(field head_commit "$out")" "-" "충돌이면 head_commit: -"
  assert_eq "$(field commits "$out")" "2" "충돌이어도 본 커밋은 싣는다"
  assert_eq "$(fixed_keys "$out")" "13" "충돌: 고정 키 13줄"
  cleanup
}

case_declared_path_absent() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1" 'docs/nope-design.md#pr1'
  local out; out=$(bash "$TH" "$SID")
  assert_eq "$(field status "$out")" "declaration-invalid" "경로 부재: declaration-invalid(AC16)"
  assert_grep "$(field reason "$out")" 'nope-design\.md' "reason 이 부재 경로를 이름 붙인다"
  assert_eq "$(field commits "$out")" "-" "깨진 선언: commits: -"
  cleanup
}

case_two_fragments_on_one_branch() {
  new_repo
  git checkout -q -b stacked; decl_commit a.txt a1 "a1" 'docs/x-design.md#pr1'
  decl_commit b.txt b1 "b1" 'docs/x-design.md#pr2'
  local out; out=$(bash "$TH" "$SID")
  assert_eq "$(field status "$out")" "declaration-invalid" "한 브랜치에 조각 둘: declaration-invalid(조용히 합치지 않는다)"
  assert_eq "$(field seal "$out")" "-" "감지 단계에서 멈춘다 — 봉인을 뜨지 않는다"
  assert_grep "$(field reason "$out")" '2 distinct' "reason 이 키 개수를 적는다"
  cleanup
}

case_explicit_topic_skips_detect() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q -b plain "$R"; echo p > p.txt; git add p.txt; git commit -qm "plain"
  assert_eq "$(field status "$(bash "$TH" "$SID")")" "no-declaration" "플래그 없이: 현재 브랜치에 선언 없음(양의 짝)"
  local out; out=$(bash "$TH" "$SID" --topic "$KEY")
  assert_eq "$(field status "$out")" "ok" "--topic: 감지를 건너뛰고 그 토픽을 푼다"
  assert_eq "$(field topic_key "$out")" "$KEY" "--topic: topic_key 가 그 값"
  assert_eq "$(field seal_on_topic "$out")" "no" "현재 브랜치가 토픽 밖이면 seal_on_topic: no(공시)"
  cleanup
}

case_unrelated_member_is_unbounded() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q --orphan island; git rm -rqf .; decl_commit i.txt i1 "i1"
  git checkout -q -b topicA "$R"; decl_commit a.txt a1 "a1"
  local out; out=$(bash "$TH" "$SID")
  assert_eq "$(field status "$out")" "unbounded" "히스토리가 끊긴 구성원: unbounded(경계를 못 센다)"
  cleanup
}

case_runs_from_subdirectory() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  mkdir -p sub/deep; cd sub/deep || return
  assert_eq "$(field status "$(bash "$TH" "$SID")")" "ok" "하위 디렉토리에서 불러도 status: ok"
  cleanup
}

case_remote_only_sibling_is_combined() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git update-ref refs/remotes/origin/main "$R"
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git update-ref refs/remotes/origin/topicA HEAD
  git checkout -q main; git branch -q -D topicA
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  local out; out=$(bash "$TH" "$SID")
  assert_eq "$(field status "$out")" "ok" "원격-전용 형제: status: ok"
  assert_grep "$(git ls-tree -r --name-only "$(field tree "$out")")" '^a\.txt$' "원격-전용 형제의 변경이 합친 트리에 있다"
  assert_not_grep "$(field branches "$out")" '(^|,)(origin|origin/HEAD|origin/main|main)(,|$)' \
    "base 원격 ref · origin/HEAD(=origin) 는 구성원이 아니다"
  cleanup
}

case_no_side_effects() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  echo dirty > wip.txt; echo mod >> b.txt
  local st0 h0 idx0 wl0 refs0
  st0=$(git status --porcelain); h0=$(git rev-parse HEAD); idx0=$(git ls-files -s | git hash-object --stdin)
  wl0=$(git worktree list --porcelain); refs0=$(git for-each-ref)
  local out; out=$(bash "$TH" "$SID")
  assert_eq "$(field status "$out")" "ok" "부작용 없음 케이스도 실행이 합치기까지 가 status: ok 를 낸다"
  assert_grep "$(field seal "$out")" '^[0-9a-f]{40}$' "봉인 SHA 가 실제로 떴다"
  assert_not_grep "$(field head_commit "$out")" "^$(field seal "$out")\$" "형제가 있으니 head_commit 은 봉인이 아니다(합치기가 실제로 돌았다)"
  assert_eq "$(git status --porcelain)" "$st0" "워킹트리 상태 불변"
  assert_eq "$(git rev-parse HEAD)" "$h0" "HEAD 불변"
  assert_eq "$(git ls-files -s | git hash-object --stdin)" "$idx0" "실제 인덱스 불변"
  assert_eq "$(git worktree list --porcelain)" "$wl0" "워크트리 추가 없음"
  assert_eq "$(git for-each-ref)" "$refs0" "ref 추가 · 이동 없음"
  cleanup
}

case_repo_hooks_not_run() {
  new_repo
  local M; M=$(mktemp -d)
  mkdir -p hooks
  local h
  for h in post-index-change post-checkout reference-transaction pre-auto-gc; do
    printf '#!/bin/sh\necho %s >> %s/ran\n' "$h" "$M" > "hooks/$h"; chmod +x "hooks/$h"
  done
  git add hooks; git commit -qm "tracked hooks"
  git config core.hooksPath hooks
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  rm -f "$M/ran"
  echo dirty > wip.txt
  local out; out=$(DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1 bash "$TH" "$SID")
  assert_eq "$(field status "$out")" "ok" "추적 hooksPath: topic-head 가 봉인까지 돌아 status: ok"
  assert_eq "$([ -e "$M/ran" ] && cat "$M/ran" || echo none)" "none" \
    "추적 hooksPath: topic-head(봉인 · 해석 · 합치기)가 저장소 훅을 하나도 돌리지 않는다"
  git add wip.txt
  assert_grep "$([ -e "$M/ran" ] && cat "$M/ran" || echo none)" '^post-index-change$' \
    "추적 hooksPath: 같은 fixture 에서 git add 를 직접 하면 훅이 돈다(양의 짝 — fixture 가 실제로 훅을 가진다)"
  rm -rf "$M"
  cleanup
}

case_create_head_topic_accepts_derived_commit() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  echo dirty > wip.txt
  local out H h; out=$(bash "$TH" "$SID"); H=$(field head_commit "$out")
  if h=$(bash "$WT" create-head "$H" "$SID" --topic "$KEY" 2>/dev/null) \
     && [ -f "$h/a.txt" ] && [ -f "$h/b.txt" ] && [ -f "$h/wip.txt" ]; then
    ok "합친 커밋 → create-head --topic 수락 · 트리에 형제 · 현재 · 미커밋 변경(양의 짝)"
    bash "$WT" remove "$h" >/dev/null 2>&1
  else
    no "합친 커밋인데 create-head --topic 이 거부했거나 트리에 셋이 없다"
  fi
  cleanup
}

case_create_head_topic_rejects_wrong_commits() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  echo dirty > wip.txt
  # 거부의 «이유»까지 잰다 — 옛 usage 오류가 되살아나도 exit 2 라 종료 코드만으로는 못 가른다.
  local out S H err; out=$(bash "$TH" "$SID"); S=$(field seal "$out"); H=$(field head_commit "$out")
  err=$(bash "$WT" create-head "$S" "$SID" --topic "$KEY" 2>&1 >/dev/null)
  assert_grep "$err" 'head-commit mismatch' "봉인 단독 → create-head --topic 거부 · 트리 대조로(형제가 빠진 트리)"
  err=$(bash "$WT" create-head "$R" "$SID" --topic "$KEY" 2>&1 >/dev/null)
  assert_grep "$err" 'head-commit mismatch' "경계 → create-head --topic 거부 · 트리 대조로"
  err=$(bash "$WT" create-head "$H" "$SID" 2>&1 >/dev/null)
  assert_grep "$err" 'sealed-sha mismatch' "--topic 없이 합친 커밋 → 봉인 대조가 거부(그대로)"
  echo later > later.txt
  err=$(bash "$WT" create-head "$H" "$SID" --topic "$KEY" 2>&1 >/dev/null)
  assert_grep "$err" 'head-commit mismatch' "① 뒤 워킹트리가 바뀌면 거부(stale) · 트리 대조로"
  assert_eq "$(git worktree list | grep -c 'head-')" "0" "거부된 호출은 HEAD 축 워크트리를 만들지 않는다"
  cleanup
}

case_scope_file_under_subdir_cwd() {
  # SKILL ① 1a 의 스코프 파일 경로 — 하위 디렉토리 cwd 의 상태 디렉토리(.gitignore 가 덮지
  # 않는 리포)에 쓰면 리다이렉트가 먼저 만든 빈 파일이 봉인에 섞이고, R-init 의
  # create-head --topic 재봉인은 채워진 파일을 담아 트리 대조가 어긋난다. 리포 루트의
  # .claude/quality-gates 는 봉인이 뺀다.
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  mkdir -p sub; cd sub || return
  mkdir -p ".claude/quality-gates/$SID"; echo "state" > ".claude/quality-gates/$SID/pipeline.md"
  local H err h S
  bash "$TH" "$SID" > ".claude/quality-gates/$SID/topic-scope.txt"
  H=$(field head_commit "$(cat ".claude/quality-gates/$SID/topic-scope.txt")")
  err=$(bash "$WT" create-head "$H" "$SID" --topic "$KEY" 2>&1 >/dev/null)
  assert_grep "$err" 'head-commit mismatch' "cwd 상대 스코프 파일(하위 디렉토리): 재도출 대조가 어긋난다(양의 짝 — fixture 가 결함을 재현한다)"
  rm -f ".claude/quality-gates/$SID/topic-scope.txt"
  S="$(git rev-parse --show-toplevel)/.claude/quality-gates/$SID/topic-scope.txt"; mkdir -p "${S%/*}"
  bash "$TH" "$SID" > "$S"
  H=$(field head_commit "$(cat "$S")")
  if h=$(bash "$WT" create-head "$H" "$SID" --topic "$KEY" 2>/dev/null) && [ -f "$h/a.txt" ]; then
    ok "리포 루트 스코프 파일(하위 디렉토리 cwd): create-head --topic 이 합친 커밋을 받는다"
    bash "$WT" remove "$h" >/dev/null 2>&1
  else
    no "리포 루트 스코프 파일(하위 디렉토리 cwd)인데 create-head --topic 이 거부했다"
  fi
  cleanup
}

case_create_head_topic_rejects_conflicted_topic() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit f.txt fromA "a1"
  git checkout -q -b topicB "$R"; decl_commit f.txt fromB "b1"
  local S; S=$(bash "$SEALER" seal "$SID")
  local err rc; err=$(bash "$WT" create-head "$S" "$SID" --topic "$KEY" 2>&1 >/dev/null); rc=$?
  assert_eq "$rc" "2" "충돌 토픽: create-head --topic exit 2"
  assert_grep "$err" 'merge-conflict' "충돌 토픽: stderr 가 status 를 이름 붙인다"
  cleanup
}

case_create_head_usage() {
  new_repo
  local S rc; S=$(bash "$SEALER" seal "$SID")
  bash "$WT" create-head "$S" "$SID" --topic >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "--topic 값 없음: exit 2"
  bash "$WT" create-head "$S" "$SID" --topic "" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "--topic 빈 값: exit 2"
  bash "$WT" create-head "$S" "$SID" --bogus "$KEY" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "모르는 플래그: exit 2"
  cleanup
}

case_explicit_topic_fully_merged() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q main; git merge -q --no-ff topicA -m "merge topicA"
  git checkout -q -b later; echo l > l.txt; git add l.txt; git commit -qm "later (선언 없음)"
  local out rc; out=$(bash "$TH" "$SID" --topic "$KEY"); rc=$?
  assert_eq "$rc" "0" "전부 머지된 키를 --topic 으로: exit 0(사용 오류가 아니다)"
  assert_eq "$(field status "$out")" "declaration-invalid" "전부 머지된 키를 --topic 으로: declaration-invalid"
  assert_grep "$(field reason "$out")" 'already in base_ref' "reason 이 resolve 의 사유를 그대로 싣는다"
  assert_eq "$(field in_base "$out")" "1" "in_base 1"
  assert_eq "$(fixed_keys "$out")" "13" "고정 키 13줄"
  cleanup
}

case_create_head_topic_names_resolve_reason() {
  # R-init 의 create-head --topic 재도출이 ok 가 아니면 죽는다 — 그때 사용자에게 status 만이 아니라
  # resolve 의 사유를 보인다(전부 머지된 키 · base 가 1a 와 R-init 사이에 움직인 경우).
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q main; git merge -q --no-ff topicA -m "merge topicA"
  git checkout -q -b later; echo l > l.txt; git add l.txt; git commit -qm "later (선언 없음)"
  local S; S=$(bash "$SEALER" seal "$SID")
  local err rc; err=$(bash "$WT" create-head "$S" "$SID" --topic "$KEY" 2>&1 >/dev/null); rc=$?
  assert_eq "$rc" "2" "전부 머지된 키를 create-head --topic: exit 2"
  assert_grep "$err" '\(status: declaration-invalid — ' "stderr 가 status 를 이름 붙인다"
  assert_grep "$err" 'all declared commits are already in base_ref' "stderr 가 resolve 의 사유를 싣는다"
  cleanup
}

for c in case_usage case_no_declaration case_single_branch_topic case_two_siblings_combined \
         case_merged_member_is_baseline case_stack_after_front_merged case_conflict_lists_files case_declared_path_absent \
         case_two_fragments_on_one_branch case_explicit_topic_skips_detect \
         case_unrelated_member_is_unbounded case_runs_from_subdirectory \
         case_remote_only_sibling_is_combined case_no_side_effects case_repo_hooks_not_run \
         case_create_head_topic_accepts_derived_commit case_create_head_topic_rejects_wrong_commits \
         case_scope_file_under_subdir_cwd \
         case_create_head_topic_rejects_conflicted_topic case_create_head_usage \
         case_explicit_topic_fully_merged case_create_head_topic_names_resolve_reason; do
  echo "== $c"; $c
done
finish
