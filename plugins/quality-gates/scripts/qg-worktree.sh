#!/usr/bin/env bash
# qg-worktree.sh — 차등 테스트 두 축(기준선 · HEAD)의 일회용 git worktree.
#
# Subcommands:
#   memo-init <project-dir>      -> 리포 밖 실행 안 메모 디렉토리의 절대 경로 (표지 .qg-memo). 리포 안이면 exit 2
#   memo-drop <memo-dir>         -> 표지가 있는 메모만 지운다. 없는 경로는 exit 0, 표지 없으면 exit 2
#   remove <abs-path>            -> 자기 사본(<top>/.claude/worktrees/qg-(base|head)-<sid8> · 옛 자리 포함)만
#                                   best-effort 로 지운다. 브랜치를 쥔 worktree · 링크 대상은 건드리지 않는다
#   own-paths <session-id>       -> 이 세션의 등록된 사본의 레포 기준 상대 경로 한 줄씩 (없으면 빈 출력)
#   create-baseline <merge-base-sha> <session-id>
#                                -> echoes absolute worktree path; detached at merge_base,
#                                   NO working-tree overlay (baseline must not inherit
#                                   HEAD's uncommitted changes)
#   create-head <sealed-sha> <session-id> [--topic <topic-key> | --range <range-scope-file>]
#                                -> echoes absolute worktree path; detached at the given
#                                   commit. Without a flag: re-seals the working tree
#                                   (seal-worktree.sh) and asserts the trees match. With
#                                   --topic: re-derives the combined topic tree
#                                   (topic-head.sh --topic) and asserts the trees match.
#                                   With --range: reads the file resolve-range.sh froze at
#                                   run start and requires status ok, start != end, and the
#                                   given commit == its end (no re-derivation from refs).
#                                   Every way the sha is not a declared free variable
#                                   (§6.4.1). No sandbox required.
#
# 샌드박스(create-sandbox · mutation-guard)는 plugins/plugin-audit/scripts/audit-sandbox.sh 로 옮겨 갔다.

set -u

die() { echo "qg-worktree: $*" >&2; exit 2; }

# 경로의 물리 경로 — 마지막 성분은 풀지 않는다(링크는 링크로 남는다). 부모가 없으면 받은 그대로.
phys_path() {   # <path>
  local d b
  d=$(dirname "$1"); b=$(basename "$1")
  if [[ -d "$d" ]]; then d=$(cd "$d" && pwd -P) && printf '%s/%s\n' "$d" "$b" && return 0; fi
  printf '%s\n' "$1"
}

# 등록 판정의 단일 읽기 — `git worktree list --porcelain` 의 블록에서 같은 worktree 를 찾는다.
# 글자가 아니라 신원(물리 경로 · 같은 inode)으로 견준다 — 대소문자를 구분하지 않는 파일시스템에서
# 이름이 대소문자만 다른 사용자 worktree 도 같은 것으로 잡는다.
# 등록돼 있으면 그 브랜치 이름(브랜치를 쥐지 않았으면 `-`)을 내고 rc 0, 등록돼 있지 않으면 rc 1.
wt_registered_branch() {   # <abs-path>
  local want line p="" br="-"
  want=$(phys_path "$1")
  while IFS= read -r line; do
    case "$line" in
      "worktree "*) p=$(phys_path "${line#worktree }"); br="-" ;;
      "branch "*) br="${line#branch }" ;;
      "") if [[ -n "$p" ]] && { [[ "$p" == "$want" ]] || [[ "$p" -ef "$1" ]]; }; then printf '%s\n' "$br"; return 0; fi; p="" ;;
    esac
  done < <(git worktree list --porcelain 2>/dev/null; echo)
  return 1
}

holds_branch() {   # <abs-path> — 등록된 worktree 가 브랜치를 쥐고 있으면 참
  local br
  br=$(wt_registered_branch "$1") || return 1
  [[ "$br" != "-" ]]
}

# 폴더 안에 그 이름이 글자 그대로 있나 — 대소문자를 구분하지 않는 파일시스템에서 `qg-base-x` 가
# `QG-Base-x` 를 열어 주는 것을 자기 것으로 착각하지 않기 위함.
has_exact_entry() {   # <dir> <name>
  [[ -n "$(find "$1" -mindepth 1 -maxdepth 1 -name "$2" -print 2>/dev/null)" ]]
}

# 세션 id 앞 8자를 검증해 낸다.
sid_short_of() {   # <session-id>
  local s="${1:0:8}"
  [[ -n "$s" ]] || die "empty session-id"
  case "$s" in
    *[!A-Za-z0-9_-]*) die "bad session-id (A-Z a-z 0-9 _ - 만 허용): $1" ;;
  esac
  printf '%s\n' "$s"
}

# 앞 실행이 남긴 같은 이름의 사본을 치운다. 부모 폴더가 아예 없으면 할 일이 없다. 부모를 끝까지 풀었을 때
# 기대한 자리가 아니면(링크로 리포 안 다른 곳 · 밖을 가리킨다) 지우지 않고 멈춘다.
# 링크는 링크만 지운다 · 브랜치를 쥔 등록된 worktree 는 지우지 않고 멈춘다 · 그 밖은 지운다.
clear_stale_copy() {   # <path> <expected-parent>
  local wt="$1" want_parent="$2" real_parent
  real_parent=$(cd "$(dirname "$wt")" 2>/dev/null && pwd -P) || return 0
  [[ "$real_parent" == "$want_parent" ]] \
    || die "일회용 트리 자리가 기대한 곳이 아니다(링크?) — 지우지 않는다: $(dirname "$wt") -> $real_parent"
  if [[ -L "$wt" || -e "$wt" ]]; then
    has_exact_entry "$real_parent" "$(basename "$wt")" \
      || die "이름이 대소문자만 다른 항목이다 — 지우지 않는다: $wt"
  fi
  git worktree prune >/dev/null 2>&1 || true
  if [[ -L "$wt" ]]; then
    rm -f -- "$wt" || die "앞 실행이 남긴 링크를 지우지 못했다: $wt"
  elif [[ -e "$wt" ]]; then
    holds_branch "$wt" && die "자기 이름의 사본이 브랜치를 쥐고 있다 — 지우지 않는다: $wt"
    git worktree remove --force --force "$wt" >/dev/null 2>&1 || rm -rf -- "$wt" \
      || die "앞 실행이 남긴 트리를 지우지 못했다: $wt"
  fi
  git worktree prune >/dev/null 2>&1 || true
}

# 주어진 커밋에 detached 된 일회용 워크트리를 `<top>/.claude/worktrees/qg-<prefix>-<sid8>` 에 만든다.
# 그 폴더는 사용자 · 지휘자의 worktree 와 함께 쓰므로 자기 이름 꼴만 다룬다.
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
  sid_short=$(sid_short_of "$sid") || exit 2
  main_root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not a git repo"
  main_root=$(cd "$main_root" && pwd -P) || die "cd failed: $main_root"
  parent="$main_root/.claude/worktrees"
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
  [[ "$parent" == "$main_root/.claude/worktrees" ]] \
    || die "일회용 트리 자리가 기대한 곳이 아니다(링크?) — 만들지 않는다: $parent"
  wt="$parent/qg-${prefix}-${sid_short}"

  # 옛 자리(`.claude/quality-gates/worktrees/`)의 같은 세션 이름만 치운다 — 다른 세션의 옛 사본은 건드리지 않는다.
  clear_stale_copy "$main_root/.claude/quality-gates/worktrees/${prefix}-${sid_short}" \
    "$main_root/.claude/quality-gates/worktrees"
  # 새 자리의 같은 이름은 일회용이다. 앞 실행이 남긴 것은 지우고 다시 만든다 —
  # 남겨 두면 그 세션은 다음 차등에서 트리를 못 만든다(R23).
  clear_stale_copy "$wt" "$parent"
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
    # 범위 경로(--range)의 HEAD 축은 resolve-range.sh 가 실행 시작에 얼린 끝 커밋이다.
    # 지금 작업 트리 · ref 를 다시 뜨지 않는다 — 실행 중 fetch 로 ref 가 움직여도 얼린 값만 받는다.
    ch_topic="" ch_range="" ch_sha="$2"
    if [[ $# -eq 5 && "$4" == "--topic" && -n "$5" ]]; then
      ch_topic="$5"
    elif [[ $# -eq 5 && "$4" == "--range" && -n "$5" ]]; then
      ch_range="$5"
    elif [[ $# -ne 3 ]]; then
      die "usage: create-head <sealed-sha> <session-id> [--topic <topic-key> | --range <range-scope-file>]"
    fi
    git rev-parse --verify --quiet "$2^{commit}" >/dev/null \
      || die "not a commit: $2"
    if [[ -n "$ch_range" ]]; then
      [[ -f "$ch_range" ]] \
        || die "range scope not ok: 범위 파일이 없다 — $ch_range"
      ch_r_mode=$(sed -n 's/^mode: //p' "$ch_range" | head -1)
      ch_r_status=$(sed -n 's/^status: //p' "$ch_range" | head -1)
      ch_r_start=$(sed -n 's/^start: //p' "$ch_range" | head -1)
      ch_r_end=$(sed -n 's/^end: //p' "$ch_range" | head -1)
      [[ "$ch_r_mode" == "range" && "$ch_r_status" == "ok" ]] \
        || die "range scope not ok (mode: ${ch_r_mode:-?}, status: ${ch_r_status:-?}) — 풀린 범위가 없어 HEAD 축을 만들지 않는다"
      [[ -n "$ch_r_start" && "$ch_r_start" != "-" && -n "$ch_r_end" && "$ch_r_end" != "-" \
         && "$ch_r_start" != "$ch_r_end" ]] \
        || die "range scope not ok (start: ${ch_r_start:-?}, end: ${ch_r_end:-?}) — 시작 · 끝이 둘 다 있고 달라야 한다"
      [[ "$(git rev-parse --verify --quiet "$2^{commit}")" == "$ch_r_end" ]] \
        || die "range end mismatch: '$2' is not the frozen end commit ($ch_r_end) — the HEAD axis must be built from the range file's end, not from the start, a moved ref, or a stale value"
      # 확인한 값으로 만든다 — 인자가 ref 이름이면 확인과 만들기 사이에 움직일 수 있다.
      ch_sha="$ch_r_end"
    elif [[ -z "$ch_topic" ]]; then
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

    make_detached_worktree "$ch_sha" "$3" head
    ;;
  remove)
    # 같은 의미의 다른 사본: plugins/plugin-audit/scripts/audit-sandbox.sh 의 `remove` — 의미가 같다(가드 바꾸면 둘 다).
    [[ $# -eq 2 ]] || die "usage: remove <abs-path>"
    target="$2"
    # 받는 것: <repo>/.claude/worktrees/qg-(base|head)-<1~8자> 와 옛 <repo>/.claude/quality-gates/worktrees/(base|head)-<1~8자> 뿐.
    # 앞의 폴더는 사용자 worktree 와 함께 쓴다 — 이름이 자기 꼴이 아니면 거부한다.
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    # Canonicalize repo_root to resolve symlinks (macOS /var → /private/var)
    repo_root=$(cd "$repo_root" && pwd -P) || die "cd failed: $repo_root"
    # 마지막 성분은 풀지 않는다(링크는 링크로 본다). 부모는 가장 깊은 실재 조상을 풀어 붙인다.
    t_name=$(basename "$target")
    t_path=$(dirname "$target") t_suffix=""
    while [[ -n "$t_path" && ! -d "$t_path" && "$t_path" != "/" && "$t_path" != "." ]]; do
      t_suffix="/$(basename "$t_path")$t_suffix"
      t_path=$(dirname "$t_path")
    done
    if [[ -d "$t_path" ]]; then
      t_path=$(cd "$t_path" && pwd -P) || die "cd failed: $t_path"
    fi
    t_parent="$t_path$t_suffix"
    target_real="$t_parent/$t_name"
    scope_ok=0
    case "$t_parent" in
      "$repo_root/.claude/worktrees")
        [[ "$t_name" =~ ^qg-(base|head)-[A-Za-z0-9_-]{1,8}$ ]] && scope_ok=1 ;;
      "$repo_root/.claude/quality-gates/worktrees")
        [[ "$t_name" =~ ^(base|head)-[A-Za-z0-9_-]{1,8}$ ]] && scope_ok=1 ;;
    esac
    [[ "$scope_ok" -eq 1 ]] || die "refuse to remove outside namespace: $target"
    if [[ -L "$target_real" || -e "$target_real" ]]; then
      has_exact_entry "$t_parent" "$t_name" \
        || die "이름이 대소문자만 다른 항목이다 — 지우지 않는다: $target"
    fi
    if [[ -L "$target_real" ]]; then
      rm -f -- "$target_real" || die "링크를 지우지 못했다: $target"   # 링크만 지운다 — 가리키는 곳은 건드리지 않는다
      exit 0
    fi
    [[ -d "$target_real" ]] || exit 0  # idempotent
    holds_branch "$target_real" && die "브랜치를 쥔 worktree 라 지우지 않는다: $target"
    git worktree remove --force --force "$target_real" 2>/dev/null \
      || rm -rf -- "$target_real" \
      || die "rm -rf fallback also failed: $target"  # fallback when git lost track
    ;;
  own-paths)
    # 이 세션의 등록된 사본의 레포 기준 상대 경로를 한 줄씩 낸다(없으면 빈 출력). 봉인 · 리뷰 범위 · 지문이 쓴다.
    [[ $# -eq 2 ]] || die "usage: own-paths <session-id>"
    op_sid=$(sid_short_of "$2") || exit 2
    op_top=$(git rev-parse --show-toplevel 2>/dev/null) || die "not a git repo"
    op_top=$(cd "$op_top" && pwd -P) || die "cd failed: $op_top"
    for op_prefix in base head; do
      op_rel=".claude/worktrees/qg-${op_prefix}-${op_sid}"
      [[ -d "$op_top/$op_rel" && ! -L "$op_top/$op_rel" ]] || continue
      has_exact_entry "$op_top/.claude/worktrees" "qg-${op_prefix}-${op_sid}" || continue   # 대소문자만 다른 사용자 worktree 는 자기 것이 아니다
      op_br=$(wt_registered_branch "$op_top/$op_rel") || continue
      [[ "$op_br" == "-" ]] && printf '%s\n' "$op_rel"
    done
    exit 0
    ;;
  memo-init)
    # 실행 안 메모 — 한 번의 /quality-gates:quality-pipeline 동안 기준선 행 · 배정 · 대조 산출을 담는다. 검사 대상 트리
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
