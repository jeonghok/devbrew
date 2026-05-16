#!/usr/bin/env bash
# qg-worktree.sh — git worktree lifecycle helper for /qg branch <name>.
#
# Subcommands:
#   sanitize <name>              -> echoes sanitized name; exit 2 on reject
#   validate-branch <name>       -> exit 0 if git ref exists; exit 2 otherwise
#   create <name> <session-id>   -> echoes absolute worktree path; idempotent
#   remove <abs-path>            -> best-effort `git worktree remove --force`
#
# Sanitize rules: replace '/' with '-', then reject if remainder contains
# anything outside [A-Za-z0-9._-], or contains '..' substring, or has
# leading '.', or exceeds 64 chars.
#
# Kill switch: DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1 — `create` exits 1
# with a loud message.

set -u

die() { echo "qg-worktree: $*" >&2; exit 2; }

cmd_sanitize() {
  local name="$1"
  local sanitized="${name//\//-}"
  [[ -z "$sanitized" ]] && die "empty after sanitize"
  [[ "$sanitized" == .* ]] && die "leading dot: $name"
  [[ "$sanitized" == *..* ]] && die "dotdot token: $name"
  [[ "$sanitized" =~ ^[A-Za-z0-9._-]+$ ]] || die "invalid chars: $name"
  (( ${#sanitized} <= 64 )) || die "exceeds 64 chars: $name"
  printf '%s' "$sanitized"
}

case "${1:-}" in
  sanitize)
    [[ $# -eq 2 ]] || die "usage: sanitize <name>"
    cmd_sanitize "$2"; echo  # trailing newline for shell convenience
    ;;
  validate-branch)
    [[ $# -eq 2 ]] || die "usage: validate-branch <name>"
    git rev-parse --verify --quiet "refs/heads/$2" >/dev/null \
      || die "branch not found: $2 (try \`git branch --all\`)"
    ;;
  create)
    [[ $# -eq 3 ]] || die "usage: create <branch> <session-id>"
    if [[ "${DEVBREW_QG_DISABLE_BRANCH_WORKTREE:-0}" == "1" ]]; then
      die "Branch worktree mode disabled via DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1"
    fi
    branch="$2" sid="$3"
    sanitized=$(cmd_sanitize "$branch") || exit 2
    git rev-parse --verify --quiet "refs/heads/$branch" >/dev/null \
      || die "branch not found: $branch (try \`git branch --all\`)"
    sid_short="${sid:0:8}"
    [[ -n "$sid_short" ]] || die "empty session-id"
    parent=".claude/quality-gates/worktrees"
    mkdir -p "$parent" || die "cannot create $parent"
    abs="$(cd "$parent" && pwd -P)/${sanitized}-${sid_short}"
    if [[ -d "$abs" ]]; then
      # Idempotent: verify it's a registered worktree and reuse
      if git worktree list --porcelain | grep -qxF "worktree $abs"; then
        echo "qg-worktree: reusing existing worktree at $abs" >&2
        printf '%s' "$abs"; echo
        exit 0
      fi
      die "path exists but not a git worktree: $abs"
    fi
    git worktree add --detach "$abs" "$branch" >/dev/null \
      || die "git worktree add failed for $branch"
    printf '%s' "$abs"; echo
    ;;
  remove)
    [[ $# -eq 2 ]] || die "usage: remove <abs-path>"
    target="$2"
    # Safety: only allow paths under <repo>/.claude/quality-gates/worktrees/
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    # Canonicalize repo_root to resolve symlinks (macOS /var → /private/var)
    repo_root=$(cd "$repo_root" && pwd -P)
    parent="$repo_root/.claude/quality-gates/worktrees"
    # Canonicalize target by resolving its deepest existing ancestor.
    # Walk up until we find an existing dir, resolve it, then reattach the rest.
    t_path="$target" t_suffix=""
    while [[ -n "$t_path" && ! -d "$t_path" ]]; do
      t_suffix="/$(basename "$t_path")$t_suffix"
      t_path=$(dirname "$t_path")
    done
    if [[ -d "$t_path" ]]; then
      t_path=$(cd "$t_path" && pwd -P)
    fi
    target_real="$t_path$t_suffix"
    case "$target_real" in
      "$parent"/*) ;;
      *) die "refuse to remove outside namespace: $target" ;;
    esac
    [[ -d "$target" ]] || exit 0  # idempotent
    git worktree remove --force "$target" 2>/dev/null \
      || rm -rf "$target"  # fallback when git lost track
    ;;
  *)
    die "unknown subcommand: ${1:-}"
    ;;
esac
