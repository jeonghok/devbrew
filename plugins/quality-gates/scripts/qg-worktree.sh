#!/usr/bin/env bash
# qg-worktree.sh — git worktree lifecycle helper for /qg branch <name>.
#
# Subcommands:
#   sanitize <name>              -> echoes sanitized name; exit 2 on reject
#   validate-branch <name>       -> exit 0 if git ref exists; exit 2 otherwise
#   create <name> <session-id>   -> echoes absolute worktree path; idempotent
#   remove <abs-path>            -> best-effort `git worktree remove --force`
#   create-sandbox <session-id> -> echoes 2 lines: sandbox abs path, baseline SHA
#                                  (disposable worktree mirroring the working tree,
#                                   git-ignored files excluded; sealed as commit B)
#   mutation-guard <sandbox> <B> -> echoes YAML: tracked_diff / disallowed_new_files /
#                                    forced_downgrade (pure git; added in a later task)
#
# Sanitize rules: replace '/' with '-', then reject if remainder contains
# anything outside [A-Za-z0-9._-], or contains '..' substring, or has
# leading '.', or exceeds 64 chars.
#
# Kill switch: DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1 — `create` exits 2
# with a loud message.
# Kill switch: DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1 — `create-sandbox` exits 3
# (distinct from die's exit 2) so the orchestrator can fall back to read-only.

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
  create-sandbox)
    # Disposable git worktree reflecting the main working tree (code-under-
    # review), sealed into an immutable baseline commit B. §6.3 of the spec.
    [[ $# -eq 2 ]] || die "usage: create-sandbox <session-id>"
    if [[ "${DEVBREW_QG_DISABLE_RUNTIME_SANDBOX:-0}" == "1" ]]; then
      echo "qg-worktree: runtime sandbox disabled via DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1 — orchestrator must fall back to read-only smoke mode" >&2
      exit 3   # distinct from die's exit 2 → SKILL branches on this
    fi
    sid="$2"
    sid_short="${sid:0:8}"
    [[ -n "$sid_short" ]] || die "empty session-id"
    main_root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not a git repo"
    main_root=$(cd "$main_root" && pwd -P)
    parent="$main_root/.claude/quality-gates/worktrees"
    mkdir -p "$parent" || die "cannot create $parent"
    sandbox="$parent/rt-${sid_short}"

    # Idempotent: clear any stale sandbox so a fresh baseline can't inherit
    # prior-run state.
    git worktree prune >/dev/null 2>&1 || true
    if [[ -e "$sandbox" ]]; then
      git worktree remove --force "$sandbox" >/dev/null 2>&1 || rm -rf "$sandbox"
      git worktree prune >/dev/null 2>&1 || true
    fi
    git worktree add --detach "$sandbox" HEAD >/dev/null 2>&1 \
      || die "git worktree add failed (sandbox: $sandbox)"

    # Overlay the main working-tree state, byte-faithfully, EXCLUDING
    # git-ignored files (prod .env / deps / build — §6.3c operational safety).
    # Per-file `cp -a` loop is the portable choice: rsync --ignore-missing-args
    # and tar --null are unreliable across macOS bsdtar / old rsync.
    tmp_list=$(mktemp) || die "mktemp failed"
    {
      git -C "$main_root" ls-files -z                          # tracked (any state)
      git -C "$main_root" ls-files --others --exclude-standard -z  # untracked, not ignored
    } > "$tmp_list"
    while IFS= read -r -d '' rel; do
      [[ -z "$rel" ]] && continue
      case "$rel" in
        .claude/quality-gates/worktrees/*) continue ;;  # never copy a sandbox into itself
      esac
      src="$main_root/$rel"
      if [[ -e "$src" || -L "$src" ]]; then
        mkdir -p "$sandbox/$(dirname "$rel")"
        rm -rf "$sandbox/$rel"          # make type-change (file->symlink) faithful
        cp -a "$src" "$sandbox/$rel"    # -a preserves mode, symlink, binary
      fi
    done < "$tmp_list"
    rm -f "$tmp_list"

    # Honor deletions: a tracked file deleted in the working tree must not
    # survive in the sealed baseline.
    while IFS= read -r -d '' rel; do
      rm -f "$sandbox/$rel"
    done < <(git -C "$main_root" ls-files -d -z)

    # Seal the immutable baseline commit B. --no-verify skips any repo hooks;
    # -c identity makes the commit succeed even when git identity is unset.
    git -C "$sandbox" add -A >/dev/null 2>&1
    git -C "$sandbox" \
      -c user.email=qg-sandbox@devbrew.local -c user.name='qg sandbox' \
      -c commit.gpgsign=false \
      commit -q --no-verify --allow-empty -m "qg runtime sandbox baseline" \
      >/dev/null 2>&1 || die "baseline commit failed"
    base=$(git -C "$sandbox" rev-parse HEAD) || die "cannot read baseline SHA"

    # Output contract: line 1 = sandbox abs path, line 2 = baseline SHA.
    printf '%s\n%s\n' "$sandbox" "$base"
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
      || rm -rf "$target" \
      || die "rm -rf fallback also failed: $target"  # fallback when git lost track
    ;;
  *)
    die "unknown subcommand: ${1:-}"
    ;;
esac
