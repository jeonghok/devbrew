#!/usr/bin/env bash
# state_path.py state-root-for — 문서가 속한 레포의 상태 루트 (R13 §5 · AC9).
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HELPER="$REPO_ROOT/plugins/spec-distill/scripts/state_path.py"
. "$REPO_ROOT/shared/tests/assert.sh"

T=$(mktemp -d -t specdistill-ledgerroot-XXXXXX) || exit 1
T=$(cd "$T" && pwd -P) || exit 1
trap 'rm -rf "$T"' EXIT
export PYTHONDONTWRITEBYTECODE=1

mkrepo() {
  git init -q "$1" && git -C "$1" config user.email t@t.t && git -C "$1" config user.name t
  mkdir -p "$1/docs" && echo x > "$1/docs/x.md" && git -C "$1" add docs/x.md && git -C "$1" commit -qm init
}
A="$T/A"; B="$T/B"
mkrepo "$A"; mkrepo "$B"
git -C "$A" worktree add -q "$T/A-wt" 2>/dev/null || git -C "$A" worktree add -q "$T/A-wt" HEAD
mkdir -p "$T/nogit"; echo x > "$T/nogit/x.md"
NOTICE_PREFIX="[spec-distill] 문서가 git 작업 트리 밖이다 — 지금 작업 폴더의 레포 원장을 쓴다: "

run() {  # run <cwd> <args...> → SRF_OUT SRF_ERR SRF_RC
  local d="$1"; shift
  SRF_OUT=$(cd "$d" && python3 "$HELPER" "$@" 2>"$T/err"); SRF_RC=$?
  SRF_ERR=$(cat "$T/err")
}

note "== srf_inside_other_repo"
run "$B" state-root-for "$A/docs/x.md"
assert_eq "$SRF_OUT" "$A/.claude/spec-distill" "다른 레포 안 문서 → 그 레포의 상태 루트"
assert_eq "$SRF_ERR|$SRF_RC" "|0" "다른 레포 안: stderr 비움 · rc 0"

note "== srf_linked_worktree"
run "$B" state-root-for "$T/A-wt/docs/x.md"
assert_eq "$SRF_OUT" "$A/.claude/spec-distill" "연결된 worktree 안 문서 → 본 레포 상태 루트"

note "== srf_outside_git"
run "$B" state-root-for "$T/nogit/x.md"
assert_eq "$SRF_OUT" "$B/.claude/spec-distill" "git 밖 문서 → 지금 cwd 레포의 상태 루트"
assert_eq "$SRF_ERR" "${NOTICE_PREFIX}$T/nogit/x.md" "git 밖: stderr 가 정확히 한 줄 공시"
assert_eq "$SRF_RC" "0" "git 밖: rc 0"

note "== srf_empty_is_state_root"
run "$B" state-root
want="$SRF_OUT"
run "$B" state-root-for ""
assert_eq "$SRF_OUT" "$want" "빈 인자 → state-root 와 같다"
assert_eq "$SRF_ERR|$SRF_RC" "|0" "빈 인자: 공시 없음 · rc 0"

note "== srf_relative"
run "$A" state-root-for docs/x.md
assert_eq "$SRF_OUT" "$A/.claude/spec-distill" "상대 경로 → 문서가 속한 레포의 상태 루트"
assert_eq "$SRF_ERR" "" "상대 경로: stderr 비움"

note "== srf_missing_folder"
run "$A" payload-root "$A/nodir/x.md"; pr_out="$SRF_OUT"; pr_err="$SRF_ERR"; pr_rc="$SRF_RC"
run "$B" state-root-for "$A/nodir/x.md"
assert_eq "$SRF_RC|$SRF_OUT|$SRF_ERR" "$pr_rc|$pr_out|$pr_err" "없는 폴더 → payload-root 와 같은 rc · 출력 · 사유"

note "== srf_link_folder_refused"
mkdir -p "$T/outside"; ln -s "$T/outside" "$A/linkdir"
run "$A" payload-root "$A/linkdir/x.md"; pr_err="$SRF_ERR"; pr_rc="$SRF_RC"
run "$B" state-root-for "$A/linkdir/x.md"
assert_eq "$SRF_RC|$SRF_OUT" "2|" "링크 폴더 → rc 2 · stdout 비움"
assert_eq "$SRF_ERR" "$pr_err" "링크 폴더: payload-root 와 같은 사유 줄"
assert_eq "$pr_rc" "2" "양성 대조: payload-root 도 rc 2"

note "== existing_unchanged"
OLD="$T/old"; mkdir -p "$OLD"
git -C "$REPO_ROOT" show d433cd3b:plugins/spec-distill/scripts/state_path.py > "$OLD/state_path.py"
cmp_old() {  # cmp_old <cwd> <args...>
  local d="$1"; shift
  local o n
  o=$(cd "$d" && python3 "$OLD/state_path.py" "$@" 2>&1; echo "rc=$?")
  n=$(cd "$d" && python3 "$HELPER" "$@" 2>&1; echo "rc=$?")
  assert_eq "$n" "$o" "고치기 전과 같다: ${d##*/} $*"
}
cmp_old "$A" state-root
cmp_old "$T/A-wt" state-root
cmp_old "$T/nogit" state-root
cmp_old "$B" state-root "$A"
cmp_old "$B" state-root "$T/nogit"
cmp_old "$B" payload-root "$A/docs/x.md"
cmp_old "$B" payload-root "$T/nogit/x.md"
cmp_old "$B" payload-root "$A/nodir/x.md"
cmp_old "$B" payload-root "$A/linkdir/x.md"
cmp_old "$B" payload-root ""
cmp_old "$B" payload-root

finish
