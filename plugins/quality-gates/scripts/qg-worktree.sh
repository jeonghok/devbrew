#!/usr/bin/env bash
# qg-worktree.sh — 차등 테스트 두 축(기준선 · HEAD)의 일회용 git worktree.
#
# Subcommands:
#   memo-init <project-dir>      -> 리포 밖 실행 안 메모 디렉토리의 절대 경로 (표지 .qg-memo). 리포 안이면 exit 2
#   memo-drop <memo-dir>         -> 표지가 있는 메모만 지운다. 없는 경로는 exit 0, 표지 없으면 exit 2
#   remove <abs-path>            -> best-effort `git worktree remove --force`
#   create-baseline <merge-base-sha> <session-id>
#                                -> echoes absolute worktree path; detached at merge_base,
#                                   NO working-tree overlay (baseline must not inherit
#                                   HEAD's uncommitted changes)
#   create-head <sealed-sha> <session-id> [--topic <topic-key>]
#                                -> echoes absolute worktree path; detached at the given
#                                   commit. Without --topic: re-seals the working tree
#                                   (seal-worktree.sh) and asserts the trees match. With
#                                   --topic: re-derives the combined topic tree
#                                   (topic-head.sh --topic) and asserts the trees match.
#                                   Either way the sha is not a declared free variable
#                                   (§6.4.1). No sandbox required.
#
# 샌드박스(create-sandbox · mutation-guard)는 plugins/plugin-audit/scripts/audit-sandbox.sh 로 옮겨 갔다.

set -u

die() { echo "qg-worktree: $*" >&2; exit 2; }

# 주어진 커밋에 detached 된 일회용 워크트리를 플러그인 네임스페이스 안에 만든다.
# 두 소비자가 공유한다: `create-baseline`(기준선 축 = merge_base, 선언 경로는 경계) 과
# `create-head`(HEAD 축 = seal-worktree.sh 가 봉인한 커밋, 선언 경로(`--topic`)는
# topic-head.sh 가 합친 커밋).
#
# **working-tree 오버레이를 하지 않는다** — 두 축 모두 커밋
# 상태 그대로여야 차등의 의미가 산다. 기준선이 HEAD 의 미커밋 변경을 물면 차등이
# 사라진다.
make_detached_worktree() {   # <sha> <session-id> <prefix> → 워크트리 절대경로 emit
  local sha="$1" sid="$2" prefix="$3"
  local sid_short main_root parent wt p_anc
  git rev-parse --verify --quiet "$sha^{commit}" >/dev/null 2>&1 \
    || die "not a commit: $sha"
  sid_short="${sid:0:8}"
  [[ -n "$sid_short" ]] || die "empty session-id"
  case "$sid_short" in
    *[!A-Za-z0-9_-]*) die "bad session-id (A-Z a-z 0-9 _ - 만 허용): $sid" ;;
  esac
  main_root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not a git repo"
  main_root=$(cd "$main_root" && pwd -P) || die "cd failed: $main_root"
  parent="$main_root/.claude/quality-gates/worktrees"
  # 리뷰 대상 리포가 커밋한 `.claude` 심볼릭 링크가 리포 밖을 가리키면 아래 강제 삭제가 리포 밖에서 일어난다.
  # 만들기 전에 가장 깊은 기존 조상을, 만든 뒤에 parent 를 정규화해 main_root 아래인지 본다.
  p_anc="$parent"
  while [[ -n "$p_anc" && "$p_anc" != "/" && ! -d "$p_anc" ]]; do p_anc=$(dirname "$p_anc"); done
  p_anc=$(cd "$p_anc" && pwd -P) || die "cd failed: $p_anc"
  case "$p_anc/" in
    "$main_root"/*) ;;
    *) die "일회용 트리 자리가 리포 밖을 가리킨다 — 만들지 않는다: $parent -> $p_anc" ;;
  esac
  mkdir -p "$parent" || die "cannot create $parent"
  parent=$(cd "$parent" && pwd -P) || die "cd failed: $parent"
  [[ "$parent" == "$main_root/.claude/quality-gates/worktrees" ]] \
    || die "일회용 트리 이름공간이 기대한 자리가 아니다(링크?) — 만들지 않는다: $parent"
  wt="$parent/${prefix}-${sid_short}"

  # 이 이름공간의 base-·head- 트리는 일회용이다. 앞 실행이 남긴 것은 지우고 다시 만든다 —
  # 남겨 두면 그 세션은 다음 차등에서 트리를 못 만든다(R23).
  git worktree prune >/dev/null 2>&1 || true
  if [[ -L "$wt" ]]; then
    rm -f -- "$wt" || die "앞 실행이 남긴 링크를 지우지 못했다: $wt"
  elif [[ -e "$wt" ]]; then
    git worktree remove --force --force "$wt" >/dev/null 2>&1 || rm -rf -- "$wt" \
      || die "앞 실행이 남긴 트리를 지우지 못했다: $wt"
  fi
  git worktree prune >/dev/null 2>&1 || true
  git worktree add --detach "$wt" "$sha" >/dev/null 2>&1 \
    || die "git worktree add failed (${prefix}: $wt)"
  printf '%s\n' "$wt"
}

case "${1:-}" in
  create-baseline)
    # 기준선 축(merge_base). 같은 worktrees/ 네임스페이스에 만들어 remove 가드를
    # 그대로 받는다. 본문은 `make_detached_worktree` 가 `create-head` 와 공유한다.
    [[ $# -eq 3 ]] || die "usage: create-baseline <merge-base-sha> <session-id>"
    make_detached_worktree "$2" "$3" base
    ;;
  create-head)
    # HEAD 축(봉인 커밋). **봉인 확인 (assert-equality)** — 인자가 선언된 자유 변수가
    # 되면 형제 `create-baseline "$merge_base" <sid>` 와 인자 모양이 같아, `$merge_base`
    # 를 넘기는 실수 하나로 HEAD 축이 기준선의 바이트 복사본이 되고 전 unit 이 STILL_GREEN
    # 으로 접힌다. 그래서 지금 봉인을 **다시 떠서** 트리를 대조한다 — 기대 OID 를
    # 오케스트레이터가 따로 옮겨 적지 않으므로 대조 양쪽이 같은 전사에서 나오지 않는다.
    # 대조는 거부만 할 수 있고 선택은 못 한다: 값의 출처는 여전히 호출자다.
    # 선언 경로(--topic)의 HEAD 축은 봉인이 아니라 «봉인 + 구성원 끝점»을 합친 트리다.
    # 같은 규율 — 기대 트리를 지금 다시 도출해 대조한다(topic-head.sh 가 봉인부터 다시 뜬다).
    ch_topic=""
    if [[ $# -eq 5 && "$4" == "--topic" && -n "$5" ]]; then
      ch_topic="$5"
    elif [[ $# -ne 3 ]]; then
      die "usage: create-head <sealed-sha> <session-id> [--topic <topic-key>]"
    fi
    git rev-parse --verify --quiet "$2^{commit}" >/dev/null \
      || die "not a commit: $2"
    if [[ -z "$ch_topic" ]]; then
      ch_expected=$(bash "$(dirname "${BASH_SOURCE[0]}")/seal-worktree.sh" seal "$3") \
        || die "cannot re-seal the working tree to verify the HEAD axis"
      [[ "$(git rev-parse "$2^{tree}")" == "$(git rev-parse "$ch_expected^{tree}")" ]] \
        || die "sealed-sha mismatch: tree of '$2' is not the tree of the working tree sealed now — the HEAD axis must be built from the seal, not from merge_base or a stale seal"
    else
      ch_out=$(bash "$(dirname "${BASH_SOURCE[0]}")/topic-head.sh" "$3" --topic "$ch_topic") \
        || die "cannot re-derive the topic HEAD axis"
      ch_status=$(printf '%s\n' "$ch_out" | sed -n 's/^status: //p' | head -1)
      ch_reason=$(printf '%s\n' "$ch_out" | sed -n 's/^reason: //p' | head -1)
      [[ "$ch_status" == "ok" ]] \
        || die "topic HEAD axis is not derivable now (status: ${ch_status:-?} — ${ch_reason:--}) — no combined tree to verify against"
      ch_tree=$(printf '%s\n' "$ch_out" | sed -n 's/^tree: //p' | head -1)
      [[ "$(git rev-parse "$2^{tree}")" == "$ch_tree" ]] \
        || die "head-commit mismatch: tree of '$2' is not the combined topic tree derived now — the topic HEAD axis must be built from topic-head.sh's head_commit, not from the seal alone, the boundary, or a stale value"
    fi

    make_detached_worktree "$2" "$3" head
    ;;
  remove)
    # 같은 의미의 다른 사본: plugins/plugin-audit/scripts/audit-sandbox.sh 의 `remove` — 의미가 같다(가드 바꾸면 둘 다).
    [[ $# -eq 2 ]] || die "usage: remove <abs-path>"
    target="$2"
    # Safety: only allow paths under <repo>/.claude/quality-gates/worktrees/
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    # Canonicalize repo_root to resolve symlinks (macOS /var → /private/var)
    repo_root=$(cd "$repo_root" && pwd -P) || die "cd failed: $repo_root"
    parent="$repo_root/.claude/quality-gates/worktrees"
    # Canonicalize target by resolving its deepest existing ancestor.
    # Walk up until we find an existing dir, resolve it, then reattach the rest.
    t_path="$target" t_suffix=""
    while [[ -n "$t_path" && ! -d "$t_path" ]]; do
      t_suffix="/$(basename "$t_path")$t_suffix"
      t_path=$(dirname "$t_path")
    done
    if [[ -d "$t_path" ]]; then
      t_path=$(cd "$t_path" && pwd -P) || die "cd failed: $t_path"
    fi
    target_real="$t_path$t_suffix"
    case "$target_real" in
      "$parent"/*) ;;
      *) die "refuse to remove outside namespace: $target" ;;
    esac
    [[ -d "$target" ]] || exit 0  # idempotent
    git worktree remove --force "$target" 2>/dev/null \
      || rm -rf "$target" \
      || die "rm -rf fallback also failed: $target"  # fallback when git lost track
    ;;
  memo-init)
    # 실행 안 메모 — 한 번의 /qg 동안 기준선 행 · 배정 · 대조 산출을 담는다. 검사 대상 트리
    # 밖이어야 봉인(HEAD 축)에 섞이지 않는다(R6).
    [[ $# -eq 2 ]] || die "usage: memo-init <project-dir>"
    root=$(git -C "$2" rev-parse --show-toplevel 2>/dev/null) || die "git 리포가 아니다: $2"
    root=$(cd "$root" && pwd -P) || die "cd failed: $root"
    memo=$(mktemp -d "${TMPDIR:-/tmp}/qg-memo.XXXXXX") || die "메모 디렉토리를 만들지 못했다"
    memo_p=$(cd "$memo" && pwd -P) || { rmdir "$memo"; die "메모 디렉토리를 해소하지 못했다: $memo"; }
    case "$memo_p/" in
      "$root"/*) rmdir "$memo"; die "메모가 검사 대상 트리 안에 생긴다($memo_p) — TMPDIR 을 $root 밖으로 두고 다시 실행하라" ;;
    esac
    : > "$memo_p/.qg-memo" || { rmdir "$memo"; die "메모 표지를 쓰지 못했다: $memo_p"; }
    printf '%s\n' "$memo_p"
    ;;
  memo-drop)
    [[ $# -eq 2 ]] || die "usage: memo-drop <memo-dir>"
    [[ -e "$2" ]] || exit 0
    # 표지는 리뷰 대상 리포도 심을 수 있다. memo-init 이 만든 모양(자리·이름·일반 파일 표지)만 지운다.
    md="${2%/}"
    case "$md" in
      */qg-memo.??????) ;;
      *) die "qg 메모 이름이 아니다 — 지우지 않는다: $2" ;;
    esac
    [[ -d "$md" && ! -L "$md" ]] || die "qg 메모가 아니다 — 지우지 않는다: $2"
    [[ -f "$md/.qg-memo" && ! -L "$md/.qg-memo" ]] || die "qg 메모가 아니다(표지 없음 또는 링크) — 지우지 않는다: $2"
    md_parent=$(cd "$(dirname "$md")" && pwd -P) || die "cd failed: $md"
    md_tmp=$(cd "${TMPDIR:-/tmp}" && pwd -P) || die "TMPDIR 을 해소하지 못했다: ${TMPDIR:-/tmp}"
    [[ "$md_parent" == "$md_tmp" ]] || die "qg 메모가 만들어지는 자리가 아니다 — 지우지 않는다: $2"
    rm -rf -- "$2" || die "메모를 지우지 못했다: $2"
    ;;
  *)
    die "unknown subcommand: ${1:-}"
    ;;
esac
