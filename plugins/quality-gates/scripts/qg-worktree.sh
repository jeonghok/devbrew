#!/usr/bin/env bash
# qg-worktree.sh — 차등 테스트 두 축(기준선 · HEAD)의 일회용 git worktree.
#
# Subcommands:
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
  local sid_short main_root parent wt
  git rev-parse --verify --quiet "$sha^{commit}" >/dev/null 2>&1 \
    || die "not a commit: $sha"
  sid_short="${sid:0:8}"
  [[ -n "$sid_short" ]] || die "empty session-id"
  main_root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not a git repo"
  main_root=$(cd "$main_root" && pwd -P) || die "cd failed: $main_root"
  parent="$main_root/.claude/quality-gates/worktrees"
  mkdir -p "$parent" || die "cannot create $parent"
  wt="$parent/${prefix}-${sid_short}"

  # Idempotent: 이전 실행의 트리가 남아 있으면 갈아엎는다.
  #
  # 경로 충돌 가드. 이 경로에 이미 다른 워크트리가 있을 수 있다(옛 qg 의 브랜치 워크트리
  # 모드가 같은 이름 규칙을 썼고, 사용자가 직접 만들 수도 있다). 무조건 `--force` 로
  # 갈아엎으면 그 안의 미커밋 작업이 되돌릴 수 없이 사라진다.
  #
  # 판별자로 "HEAD 가 심볼릭 ref 인가"(=브랜치 워크트리)는 쓸 수 없다 — detached 워크트리도
  # 흔하다. 대신 **non-force**
  # `git worktree remove` 를 먼저 시도한다: git 자신이 "수정된 파일이나 추적되지 않은
  # 파일이 있으면 거부" 를 정의하고 있고, 그 거부가 곧 "여기 잃을 것이 있다" 는
  # 신호다. git-ignored 파일만 있는 트리는 정상 제거된다(실측) — 우리가 만든 트리
  # (빌드 산출물은 전부 ignored, C1 참조)는 언제나 이 경로로 지워지므로 정상 동작에는
  # 영향이 없다. 거부되면 조용히 파괴하지 않고 죽는다.
  git worktree prune >/dev/null 2>&1 || true
  if [[ -e "$wt" ]]; then
    if ! git worktree remove "$wt" >/dev/null 2>&1; then
      [[ -e "$wt" ]] && die "refuse to clobber existing path: $wt — git declined a non-forced removal, so it holds uncommitted or untracked content (or the path is not a registered worktree). Likely causes: another worktree is registered at this exact path, or a prior run left non-ignored test output behind. Inspect it, then remove it yourself (\`git worktree remove --force\`) or rerun in a new session."
    fi
    git worktree prune >/dev/null 2>&1 || true
  fi
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
  *)
    die "unknown subcommand: ${1:-}"
    ;;
esac
