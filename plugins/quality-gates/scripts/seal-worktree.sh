#!/usr/bin/env bash
# seal-worktree.sh — 워킹트리(수정 · 삭제 · untracked 반영)를 **워크트리 생성 없이**
#   커밋 하나로 봉인한다. (설계 2026-09-21 §6.4.1, AC14)
#
#   seal <session-id>   -> 봉인 커밋 SHA 한 줄 (stdout)
#
# `create-sandbox` 를 대체한다. 그것은 워크트리를 만들고 파일을 한 벌 복사한 뒤
# 커밋했다 — 여기서는 **임시 인덱스**로 같은 트리를 만든다. 워크트리도, 복사도 없다.
#
# **요건은 「git 이 집지 않는 자리」다.** 임시 인덱스를 `.git` 안(`git rev-parse
# --git-path`)에 둔다 — `git add -A` 가 원리적으로 집지 않고, 사용자 리포의 무시 설정에
# 의존하지 않는다. 봉인 «후» 트리 검사가 권위 가드다: 위치가 아니라 결과를 잰다.
set -u

die() { echo "seal-worktree: $*" >&2; exit 2; }

[ "${1:-}" = "seal" ] || die "usage: seal-worktree.sh seal <session-id>"
sid="${2:-}"
sid_short="${sid:0:8}"
[ -n "$sid_short" ] || die "empty session-id"

main_root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not a git repo"
main_root=$(cd "$main_root" && pwd -P) || die "cd failed: $main_root"

SEAL_INDEX=$(git -C "$main_root" rev-parse --git-path "qg-seal-${sid_short}.index" 2>/dev/null) \
  || die "cannot resolve git dir for the seal index"
case "$SEAL_INDEX" in /*) ;; *) SEAL_INDEX="$main_root/$SEAL_INDEX" ;; esac

rm -f "$SEAL_INDEX" "$SEAL_INDEX.lock"
trap 'rm -f "$SEAL_INDEX" "$SEAL_INDEX.lock"' EXIT

# `export` 가 load-bearing 이다 — 그냥 대입하면 아래 git 들이 **실제 인덱스**를 쓴다.
# 서브셸로 감싸 이 스크립트의 나머지 환경에 새지 않게 한다.
B=$(
  export GIT_INDEX_FILE="$SEAL_INDEX"
  cd "$main_root" || exit 1
  git read-tree HEAD || exit 1
  # -c advice.addEmbeddedRepo=false — qg 자신의 중첩 워크트리(.claude/quality-gates/worktrees/*)가
  # gitlink 로 잡혀도 기대한 결과다(바로 아래 rm --cached 가 걷어낸다); 그 advisory 는 노이즈다.
  git -c advice.addEmbeddedRepo=false add -A || exit 1
  # 명시적 pathspec exclude(`:(exclude).claude/quality-gates`)는 그 자리가 사용자의
  # .gitignore 로도 덮여 있으면 git 이 "명시적으로 무시 자리를 집었다" 로 오인해
  # exit 1 로 죽는다(add.c 의 ignore-check 는 exclude magic 을 안 본다, 실측). add 뒤에
  # 인덱스에서 그 자리를 지우는 쪽이 무시 설정과 무관하게 서고, 중첩 워크트리가
  # gitlink 로 들어온 경우(embedded repository 경고)도 같이 걷어낸다.
  git rm -r --cached --ignore-unmatch -q -- .claude/quality-gates || exit 1
  TREE=$(git write-tree) || exit 1
  git -c user.email=qg-seal@devbrew.local \
      -c user.name='qg seal' \
      -c commit.gpgsign=false \
      commit-tree "$TREE" -p HEAD -m "qg: sealed" || exit 1
) || die "seal failed"
[ -n "$B" ] || die "seal produced no commit"

# 권위 있는 가드 — **결과**를 잰다. index 자체와 그 .lock 형제 둘 다 대상이다
# (git 이 add -A 자신의 락 파일을 그 add -A 로 줍는 관측이 이 작업에서 나왔다 —
# 설계 §7-I 는 인덱스 자체가 봉인 트리에 들어간다는 것만 기록하고 .lock 은 안 담는다).
if git -C "$main_root" ls-tree -r --name-only "$B" | grep -qE "qg-seal-${sid_short}\.index(\.lock)?$|seal-${sid_short}\.index(\.lock)?$"; then
  die "sealed tree contains the temp index or its lock ($SEAL_INDEX) — AC14 violation"
fi

printf '%s\n' "$B"
