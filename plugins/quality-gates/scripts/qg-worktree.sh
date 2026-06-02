#!/usr/bin/env bash
# qg-worktree.sh — git worktree lifecycle helper for /qg branch <name>.
#
# Subcommands:
#   sanitize <name>              -> echoes sanitized name; exit 2 on reject
#   validate-branch <name>       -> exit 0 if git ref exists; exit 2 otherwise
#   create <name> <session-id>   -> echoes absolute worktree path; idempotent
#   remove <abs-path>            -> best-effort `git worktree remove --force`
#   create-sandbox <session-id> -> echoes 3 lines: sandbox abs path, baseline SHA,
#                                  snapshot digest (disposable worktree mirroring the
#                                  working tree, git-ignored files excluded; sealed as
#                                  commit B; snapshot sealed by an orchestrator-held digest)
#   mutation-guard <sandbox> <B> <snapshot-digest>
#                                -> echoes YAML: tracked_diff / disallowed_new_files /
#                                   guard_flags / forced_downgrade (pure git; §6.1-6.3).
#                                   Verifies the snapshot digest before trusting it.
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
    base_abs=$(cd "$parent" && pwd -P) || die "cd failed: $parent"
    abs="$base_abs/${sanitized}-${sid_short}"
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
    main_root=$(cd "$main_root" && pwd -P) || die "cd failed: $main_root"
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
        mkdir -p "$sandbox/$(dirname "$rel")" || die "mkdir failed: $rel"
        rm -rf "$sandbox/$rel" 2>/dev/null  # make type-change (file->symlink) faithful
        cp -a "$src" "$sandbox/$rel" || die "cp failed: $rel"    # -a preserves mode, symlink, binary
      fi
    done < "$tmp_list"
    rm -f "$tmp_list"

    # Honor deletions: a tracked file deleted in the working tree must not
    # survive in the sealed baseline.
    while IFS= read -r -d '' rel; do
      rm -f "$sandbox/$rel" || die "rm (deletion-honor) failed: $rel"
    done < <(git -C "$main_root" ls-files -d -z)

    # Seal the immutable baseline commit B. --no-verify skips any repo hooks;
    # -c identity makes the commit succeed even when git identity is unset.
    # §6.1/NEW-05 — guarantee reflog logging BEFORE the baseline commit so the
    # baseline and any later HEAD move are logged (default is true, but a host
    # may have pre-set false). Layer 2 later compares this value vs the snapshot.
    # NOTE(side-effect): in a linked worktree this writes to the common .git/config
    # (main repo). 'true' is git's default so no practical harm; documented in §6.1.
    git -C "$sandbox" config core.logAllRefUpdates true || die "cannot set logAllRefUpdates"
    git -C "$sandbox" add -A >/dev/null 2>&1 || die "git add -A failed in sandbox"
    git -C "$sandbox" \
      -c user.email=qg-sandbox@devbrew.local -c user.name='qg sandbox' \
      -c commit.gpgsign=false \
      commit -q --no-verify --allow-empty -m "qg runtime sandbox baseline" \
      >/dev/null 2>&1 || die "baseline commit failed"
    base=$(git -C "$sandbox" rev-parse HEAD) || die "cannot read baseline SHA"

    # §6.1 — capture the pre-verifier baseline snapshot the mutation-guard
    # compares against. Side-channel: lives in the per-worktree gitdir, so the
    # 2-line output contract is unchanged and `git worktree remove` auto-cleans it.
    snap_gitdir=$(git -C "$sandbox" rev-parse --absolute-git-dir) || die "cannot resolve gitdir"
    snap_common=$(git -C "$sandbox" rev-parse --git-common-dir)   || die "cannot resolve common-dir"
    case "$snap_common" in /*) ;; *) snap_common="$sandbox/$snap_common" ;; esac
    snap="$snap_gitdir/qg-mutation-snapshot"

    snap_hash_file() { if [[ -f "$1" ]]; then git -C "$sandbox" hash-object "$1" 2>/dev/null || printf 'absent'; else printf 'absent'; fi; }
    # reflog/stash MUST be hashed with the IDENTICAL idiom the guard uses
    # (var-capture + `printf '%s'`), else a clean sandbox false-positives.
    snap_rl=$(git -C "$sandbox" reflog show HEAD 2>/dev/null || true)
    if [[ -n "$snap_rl" ]]; then
      head_reflog_sha=$(printf '%s' "$snap_rl" | git -C "$sandbox" hash-object --stdin)
    else
      head_reflog_sha=empty
    fi
    snap_sl=$(git -C "$sandbox" stash list 2>/dev/null || true)
    stash_sha=$(printf '%s' "$snap_sl" | git -C "$sandbox" hash-object --stdin)
    excl_common_sha=$(snap_hash_file "$snap_common/info/exclude")
    excl_wt_sha=$(snap_hash_file "$snap_gitdir/info/exclude")
    excludesfile=$(git -C "$sandbox" config --get core.excludesFile 2>/dev/null || printf 'absent')
    if [[ "$excludesfile" != "absent" ]]; then
      ef_path="$excludesfile"; case "$ef_path" in "~/"*) ef_path="${HOME:-}/${ef_path#'~/'}" ;; esac
      excludesfile_sha=$(snap_hash_file "$ef_path")
    else
      excludesfile_sha=absent
    fi
    logallrefupdates=$(git -C "$sandbox" config --get core.logAllRefUpdates 2>/dev/null || printf 'unset')

    {
      printf 'head_reflog_sha=%s\n' "$head_reflog_sha"
      printf 'stash_sha=%s\n'        "$stash_sha"
      printf 'excl_common_sha=%s\n'  "$excl_common_sha"
      printf 'excl_wt_sha=%s\n'      "$excl_wt_sha"
      printf 'excludesfile=%s\n'     "$excludesfile"
      printf 'excludesfile_sha=%s\n' "$excludesfile_sha"
      printf 'logallrefupdates=%s\n' "$logallrefupdates"
    } > "$snap" || die "cannot write snapshot: $snap"

    # §6.1 round-2 digest-seal — hash the just-written 7-field snapshot so the
    # orchestrator can hold the digest out-of-band and the guard can verify the
    # snapshot's integrity (verifier-writable file → must be sealed). hash-object
    # is always available in a git context.
    snapshot_digest=$(git -C "$sandbox" hash-object "$snap") || die "cannot digest snapshot: $snap"
    # Output contract (round-1.5 2 lines → 3): line 1 = sandbox abs path,
    # line 2 = baseline SHA, line 3 = snapshot digest.
    printf '%s\n%s\n%s\n' "$sandbox" "$base" "$snapshot_digest"
    ;;
  mutation-guard)
    # 4-layer fail-closed product-mutation oracle (spec §6.1-6.3). Inputs are
    # (sandbox, baseline B, snapshot-digest) + a snapshot create-sandbox wrote in
    # the per-worktree gitdir. The snapshot is verifier-writable scratch SEALED by
    # the orchestrator-held digest ($4): layer 0 verifies it before layers 1-3
    # trust it → structural Law 2 defense (round-2 §6.1 closes C-NEW-1).
    # Execution order locked: layer 0 → 1 → 1b → 2 → 3 → aggregate.
    # $1=subcommand "mutation-guard" is counted, so the 3-arg contract is $#==4
    # (round-1.5's 2-arg contract was $#==3).
    [[ $# -eq 4 ]] || die "usage: mutation-guard <sandbox-abs> <baseline-sha> <snapshot-digest>"
    sandbox="$2" base="$3" expected_digest="$4"

    # YAML single-quoted scalar escaper (I-D): '' escapes an embedded quote.
    yq() { local s; s=$(printf '%s' "$1" | sed "s/'/''/g"); printf "'%s'" "$s"; }

    # ---- Layer 0: fail-closed foundation (C-B, NEW-03) ----
    # Any indeterminate result emits forced_downgrade: yes and exits 4 (locked;
    # distinct from die=2 and kill-switch=3). "indeterminate is never PASS."
    guard_fail() {
      echo "tracked_diff: []"
      echo "disallowed_new_files: []"
      echo "guard_flags: []"
      printf 'guard_error: %s\n' "$(yq "$1")"
      echo "forced_downgrade: yes"
      exit 4
    }

    # ---- Layer 0 (round-2): snapshot digest seal ----
    # A missing/empty digest means the orchestrator did not seal this snapshot →
    # indeterminate → never PASS (§6.1; distinct from a 2-arg usage error = die 2).
    [[ -n "$expected_digest" ]] || guard_fail "missing snapshot digest (seal absent → indeterminate)"

    [[ -d "$sandbox" ]] || guard_fail "sandbox not found: $sandbox"
    gitdir=$(git -C "$sandbox" rev-parse --absolute-git-dir 2>&1) \
      || guard_fail "cannot resolve gitdir: $gitdir"
    common=$(git -C "$sandbox" rev-parse --git-common-dir 2>&1) \
      || guard_fail "cannot resolve common-dir: $common"
    case "$common" in /*) ;; *) common="$sandbox/$common" ;; esac
    base_tree=$(git -C "$sandbox" rev-parse "${base}^{tree}" 2>&1) \
      || guard_fail "bad baseline sha: $base ($base_tree)"

    snap="$gitdir/qg-mutation-snapshot"
    [[ -f "$snap" ]] || guard_fail "snapshot missing: $snap"
    # Assert ALL §6.1 keys present — a missing key read as '' would yield a
    # false forced=no (NEW-03). §6.1 table is the key single-source-of-truth.
    for k in head_reflog_sha stash_sha excl_common_sha excl_wt_sha \
             excludesfile excludesfile_sha logallrefupdates; do
      grep -q "^$k=" "$snap" || guard_fail "snapshot missing key: $k"
    done

    # Seal check: recompute the digest of the (verifier-reachable) snapshot and
    # compare to the orchestrator-held value. A forged snapshot → mismatch →
    # guard_fail (closes C-NEW-1: the verifier cannot forge the trust reference
    # because it cannot reach the orchestrator-held expected_digest). Runs AFTER
    # the existence + 7-key asserts, so those fail-closed first if applicable.
    recomputed=$(git -C "$sandbox" hash-object "$snap" 2>&1) \
      || guard_fail "cannot recompute snapshot digest: $recomputed"
    [[ "$recomputed" == "$expected_digest" ]] \
      || guard_fail "snapshot integrity check failed (digest mismatch — possible verifier tamper)"

    snap_get() { sed -n "s/^$1=//p" "$snap" | head -1; }

    forced="no"
    guard_flags=()
    tracked_diff=()
    disallowed=()

    # ---- Layer 1: content tree-hash (C-E + honest mutation) ----
    # Fresh temp index → git re-stats every path, ignoring assume-unchanged /
    # skip-worktree index bits (verified). No -f → tracked .gitignore (part of B)
    # is honored, preserving the legit git-ignored .env setup-only PASS path.
    idx="$gitdir/qg-tmp-idx.$$"; rm -f "$idx"
    add_out=$(GIT_INDEX_FILE="$idx" git -C "$sandbox" add -A -- . 2>&1) \
      || { rm -f "$idx"; guard_fail "add -A failed: $add_out"; }
    cur_tree=$(GIT_INDEX_FILE="$idx" git -C "$sandbox" write-tree 2>&1) \
      || { rm -f "$idx"; guard_fail "write-tree failed: $cur_tree"; }
    rm -f "$idx"

    if [[ "$cur_tree" != "$base_tree" ]]; then
      forced="yes"
      ns=$(git -C "$sandbox" diff --name-status "$base_tree" "$cur_tree" 2>&1) \
        || guard_fail "diff name-status failed: $ns"
      while IFS=$'\t' read -r st p1 p2; do
        [[ -z "$st" ]] && continue
        case "$st" in
          A*)    disallowed+=("$p1") ;;          # new non-ignored file (staged by add -A)
          R*|C*) tracked_diff+=("$p1" "$p2") ;;  # rename/copy: both paths
          *)     tracked_diff+=("$p1") ;;         # M / D / T / U
        esac
      done <<< "$ns"
    fi

    # New symlinks are product-affecting regardless of ignore status (original
    # §6.7-2 rule). add -A skips ignored symlinks, so enumerate via ls-files -z.
    # Read NUL-delimited entries from a temp file — NOT a $(...) capture, because
    # bash drops NUL bytes, which silently disabled this union (integration-review I-1).
    others_file="$gitdir/qg-tmp-others.$$"; rm -f "$others_file"
    git -C "$sandbox" ls-files --others -z > "$others_file" 2>/dev/null \
      || { rm -f "$others_file"; guard_fail "ls-files --others failed"; }
    while IFS= read -r -d '' rel; do
      [[ -z "$rel" ]] && continue
      [[ -L "$sandbox/$rel" ]] || continue
      disallowed+=("$rel")
    done < "$others_file"
    rm -f "$others_file"
    [[ ${#disallowed[@]} -gt 0 ]] && forced="yes"

    # ---- Layer 2: ignore-channel + config tamper (C-A, NEW-05) ----
    ho() { if [[ -f "$1" ]]; then git -C "$sandbox" hash-object "$1" 2>/dev/null || printf 'absent'; else printf 'absent'; fi; }
    now_excl_c=$(ho "$common/info/exclude")
    now_excl_w=$(ho "$gitdir/info/exclude")
    now_ef=$(git -C "$sandbox" config --get core.excludesFile 2>/dev/null || printf 'absent')
    if [[ "$now_ef" != "absent" ]]; then
      ef_path="$now_ef"; case "$ef_path" in "~/"*) ef_path="${HOME:-}/${ef_path#'~/'}" ;; esac
      now_ef_sha=$(ho "$ef_path")
    else
      now_ef_sha="absent"
    fi
    now_lar=$(git -C "$sandbox" config --get core.logAllRefUpdates 2>/dev/null || printf 'unset')

    if [[ "$now_excl_c" != "$(snap_get excl_common_sha)" \
       || "$now_excl_w" != "$(snap_get excl_wt_sha)" \
       || "$now_ef"     != "$(snap_get excludesfile)" \
       || "$now_ef_sha" != "$(snap_get excludesfile_sha)" ]]; then
      forced="yes"; guard_flags+=("ignore_channel_tampered")
    fi
    if [[ "$now_lar" != "$(snap_get logallrefupdates)" ]]; then
      forced="yes"; guard_flags+=("reflog_logging_tampered")
    fi

    # ---- Layer 3: snapshot delta (C-D) ----
    # ⚠️ MUST hash with the IDENTICAL idiom create-sandbox used (var-capture +
    # `printf '%s'`), else a clean sandbox false-positives. absolute
    # rev-list --all --not is FORBIDDEN (sibling-branch false-positive, §10).
    g_rl=$(git -C "$sandbox" reflog show HEAD 2>/dev/null || true)
    if [[ -n "$g_rl" ]]; then
      now_reflog=$(printf '%s' "$g_rl" | git -C "$sandbox" hash-object --stdin)
    else
      now_reflog=empty
    fi
    g_sl=$(git -C "$sandbox" stash list 2>/dev/null || true)
    now_stash=$(printf '%s' "$g_sl" | git -C "$sandbox" hash-object --stdin)
    if [[ "$now_reflog" != "$(snap_get head_reflog_sha)" ]]; then
      forced="yes"; guard_flags+=("reflog_advanced")
    fi
    if [[ "$now_stash" != "$(snap_get stash_sha)" ]]; then
      forced="yes"; guard_flags+=("stash_added")
    fi

    # ---- Emit (two original fields preserved → 8 happy-path compat) ----
    if [[ ${#tracked_diff[@]} -gt 0 ]]; then
      echo "tracked_diff:"
      printf '%s\n' "${tracked_diff[@]}" | sort -u | while IFS= read -r f; do
        [[ -z "$f" ]] && continue; echo "  - $(yq "$f")"
      done
    else
      echo "tracked_diff: []"
    fi
    if [[ ${#disallowed[@]} -gt 0 ]]; then
      echo "disallowed_new_files:"
      printf '%s\n' "${disallowed[@]}" | sort -u | while IFS= read -r f; do
        [[ -z "$f" ]] && continue; echo "  - $(yq "$f")"
      done
    else
      echo "disallowed_new_files: []"
    fi
    if [[ ${#guard_flags[@]} -gt 0 ]]; then
      echo "guard_flags:"
      printf '%s\n' "${guard_flags[@]}" | sort -u | while IFS= read -r g; do
        echo "  - $g"
      done
    else
      echo "guard_flags: []"
    fi
    echo "forced_downgrade: $forced"
    ;;
  remove)
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
