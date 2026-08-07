#!/usr/bin/env bash
# qg-worktree.sh — git worktree lifecycle helper for /qg branch <name>.
#
# Subcommands:
#   sanitize <name>              -> echoes sanitized name; exit 2 on reject
#   validate-branch <name>       -> exit 0 if git ref exists; exit 2 otherwise
#   create <name> <session-id>   -> echoes absolute worktree path; idempotent
#   remove <abs-path>            -> best-effort `git worktree remove --force`
#   create-baseline <merge-base-sha> <session-id>
#                                -> echoes absolute worktree path; detached at merge_base,
#                                   NO working-tree overlay (baseline must not inherit
#                                   HEAD's uncommitted changes)
#   create-head <sealed-sha> <session-id>
#                                -> echoes absolute worktree path; detached at commit B
#                                   (the seal create-sandbox emitted). Pristine HEAD tree
#                                   for the authoritative test axis — deliberately NOT the
#                                   verifier's sandbox, so the verifier's boot setup cannot
#                                   reach the axis (§11 ⑬) and the gate's own test output
#                                   cannot reach mutation-guard's tree (§6.7 S4).
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

# 주어진 커밋에 detached 된 일회용 워크트리를 플러그인 네임스페이스 안에 만든다.
# 두 소비자가 공유한다: `create-baseline`(기준선 축 = merge_base) 과
# `create-head`(HEAD 축 = create-sandbox 가 봉인한 커밋 B).
#
# `create-sandbox` 와 달리 **working-tree 오버레이를 하지 않는다** — 두 축 모두 커밋
# 상태 그대로여야 차등의 의미가 산다. 기준선이 HEAD 의 미커밋 변경을 물면 차등이
# 사라지고, HEAD 축이 verifier 가 부팅용으로 만든 상태를 물면 두 축이 같은 환경이라는
# 전제가 무너진다(§11 ⑬).
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
  # 경로 충돌 가드. `create` 는 `${sanitized}-${sid_short}` 를 쓰므로 같은 세션의
  # `/qg branch base`(또는 `head`)가 **바로 이 경로**를 만든다. 무조건 `--force` 로
  # 갈아엎으면 사용자의 미커밋 작업이 되돌릴 수 없이 사라진다.
  #
  # 판별자로 "HEAD 가 심볼릭 ref 인가"(=브랜치 워크트리)는 쓸 수 없다 — `create` 도
  # `git worktree add --detach` 라서 둘 다 detached 다 (실측). 대신 **non-force**
  # `git worktree remove` 를 먼저 시도한다: git 자신이 "수정된 파일이나 추적되지 않은
  # 파일이 있으면 거부" 를 정의하고 있고, 그 거부가 곧 "여기 잃을 것이 있다" 는
  # 신호다. git-ignored 파일만 있는 트리는 정상 제거된다(실측) — 우리가 만든 트리
  # (빌드 산출물은 전부 ignored, C1 참조)는 언제나 이 경로로 지워지므로 정상 동작에는
  # 영향이 없다. 거부되면 조용히 파괴하지 않고 죽는다.
  git worktree prune >/dev/null 2>&1 || true
  if [[ -e "$wt" ]]; then
    if ! git worktree remove "$wt" >/dev/null 2>&1; then
      [[ -e "$wt" ]] && die "refuse to clobber existing path: $wt — git declined a non-forced removal, so it holds uncommitted or untracked content (or the path is not a registered worktree). Likely causes: \`/qg branch ${prefix}\` in this same session owns this exact path, or a prior run left non-ignored test output behind. Inspect it, then remove it yourself (\`git worktree remove --force\`) or rerun in a new session."
    fi
    git worktree prune >/dev/null 2>&1 || true
  fi
  git worktree add --detach "$wt" "$sha" >/dev/null 2>&1 \
    || die "git worktree add failed (${prefix}: $wt)"
  printf '%s\n' "$wt"
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
    # compares against. Lives in the per-worktree gitdir (so `git worktree remove`
    # auto-cleans it); round-2 seals it with a digest emitted as output line 3,
    # which the guard verifies before trusting the snapshot (§6.1).
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
    # 5-layer fail-closed product-mutation oracle (spec §6.1-6.3). Inputs are
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

    qg_ce="$common/info/exclude"
    qg_we="$gitdir/info/exclude"
    # NOTE: b-precise crash-recovery pre-restore was MOVED to after the digest seal
    # (see the §6.2 step 1a block below) so it trusts only the sealed snapshot, never
    # the verifier-writable .qgbak path (F1: closes codex-2 dir-plant + the regular-
    # file pre-restore-trust gap).

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

    # ---- b-precise crash-recovery pre-restore (§6.2 step 1a; AFTER the seal) ----
    # A prior guard killed mid-neutralization may have left info/exclude empty with
    # the original parked in .qgbak; restore it BEFORE Layer 1/2 read info/exclude.
    # But .qgbak is a verifier-writable predictable path in the SHARED common gitdir,
    # so trust the SEALED snapshot — not the path: restore .qgbak ONLY when it hashes
    # to the snapshot's recorded original sha (an authentic crash orphan). A
    # non-regular .qgbak (planted directory) is verifier tampering → fail closed
    # (else the backup `mv` below moves the live file INTO it, silently corrupting
    # the orchestrator's info/exclude). A regular .qgbak whose content does NOT match
    # is an attacker plant → left untouched (the normal backup/restore cycle then
    # preserves the real live exclude, never overwriting it with planted content).
    # Closes F1 (codex-2 + the regular-file pre-restore-trust gap); seal = trust anchor.
    for pair in "$qg_ce:excl_common_sha" "$qg_we:excl_wt_sha"; do
      f="${pair%%:*}"; key="${pair#*:}"
      [[ -e "$f.qgbak" ]] || continue
      # The backup path must be a regular file (a planted directory/symlink = tamper).
      [[ -f "$f.qgbak" ]] || guard_fail "verifier-planted non-regular .qgbak (backup-path tamper): $f.qgbak"
      # The live target must be absent or a regular file: a verifier-planted directory
      # would make the restore `mv` move the backup INTO it, corrupting host state (codex-3).
      [[ ! -e "$f" || -f "$f" ]] || guard_fail "non-regular info/exclude target (backup-path tamper): $f"
      # Crash recovery ONLY: a guard killed mid-neutralization leaves the live file in the
      # placeholder state (absent or EMPTY via `: >`). If live is NON-EMPTY it is real or
      # verifier-tampered content — never overwrite it from .qgbak (that would ERASE a
      # verifier's ignore-channel tamper before Layer 2 can flag it). Skip → Layer 2 judges
      # the live content as-is. (codex-6)
      [[ -s "$f" ]] && continue
      # hash-object of a known-existing regular file must not fail silently → fail closed
      # (a swallowed 'absent' would hide verifier-controlled backup-path tampering) (codex-4).
      bak_sha=$(git -C "$sandbox" hash-object "$f.qgbak" 2>/dev/null) \
        || guard_fail "cannot hash .qgbak backup (fail-closed): $f.qgbak"
      [[ "$bak_sha" == "$(snap_get "$key")" ]] && mv -f "$f.qgbak" "$f"
    done

    forced="no"
    guard_flags=()
    tracked_diff=()
    disallowed=()

    # ---- Layer 1: content tree-hash (C-E + honest mutation) ----
    # Fresh temp index → git re-stats every path, ignoring assume-unchanged /
    # skip-worktree index bits (verified). No -f → tracked .gitignore (part of B)
    # is honored, preserving the legit git-ignored .env setup-only PASS path.
    idx="$gitdir/qg-tmp-idx.$$"; rm -f "$idx"
    # I-NEW-2: seed from B^{tree}, NOT an empty index. A force-tracked ignored
    # file (`git add -f debug.log`, committed dist/) is already in B, so it stays
    # in the index and is only re-stat'd — not re-excluded — so a clean sandbox
    # is not a false-positive. assume-unchanged/skip-worktree bits are index-only
    # (absent from a tree), so read-tree drops them → add -A still re-stats every
    # path → C-E catch preserved. No -f → tracked .gitignore (part of B) honored →
    # the legit git-ignored .env setup-only PASS path preserved.
    rt_out=$(GIT_INDEX_FILE="$idx" git -C "$sandbox" read-tree "$base_tree" 2>&1) \
      || { rm -f "$idx"; guard_fail "read-tree (Layer 1 seed) failed: $rt_out"; }
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

    # ---- Layer 1b (b-precise): baseline-anchored detection of new files hidden
    #      ONLY by non-baseline ignore sources (info/exclude, core.excludesFile).
    #      Trusted ignore source = baseline .gitignore ONLY (tracked, in B^{tree};
    #      its tamper is caught by Layer 1). info/exclude + core.excludesFile are
    #      untrusted (verifier-writable, absent from B). snapshot-INDEPENDENT, so a
    #      bug in the digest seal or Layer 2 still leaves this detector standing.
    #      Restore inline BEFORE Layer 2; the trap is a crash-only backstop. ----
    # Restore ONLY backups THIS run created (flag-tracked). A pre-existing .qgbak the
    # backup did NOT create — e.g. a verifier plant for an originally-ABSENT info/exclude
    # — must never be installed as the live exclude (codex-5). Authentic prior-crash
    # orphans are handled solely by the sha-gated pre-restore above; nothing else trusts
    # a .qgbak by mere existence.
    made_ce_bak=0; made_we_bak=0
    restore_excludes() {
      # reverse of backup order: per-worktree first, then common (common is shared).
      [[ "$made_we_bak" == 1 && -f "$qg_we.qgbak" ]] && mv -f "$qg_we.qgbak" "$qg_we"
      [[ "$made_ce_bak" == 1 && -f "$qg_ce.qgbak" ]] && mv -f "$qg_ce.qgbak" "$qg_ce"
      return 0
    }
    trap restore_excludes EXIT INT TERM
    # backup (common first, then per-worktree) via atomic rename + empty placeholder.
    if [[ -f "$qg_ce" ]]; then
      mv "$qg_ce" "$qg_ce.qgbak" && made_ce_bak=1 || guard_fail "b-precise: common info/exclude backup failed"
      : > "$qg_ce" || guard_fail "b-precise: cannot reset common info/exclude placeholder"
    fi
    if [[ -f "$qg_we" ]]; then
      mv "$qg_we" "$qg_we.qgbak" && made_we_bak=1 || guard_fail "b-precise: per-worktree info/exclude backup failed"
      : > "$qg_we" || guard_fail "b-precise: cannot reset per-worktree info/exclude placeholder"
    fi

    # Second baseline-anchored pass: read-tree B then add -A with excludesFile
    # neutralized. info/exclude is physically emptied above; baseline .gitignore
    # (in B, in the working tree) is still honored → runtime artifacts stay ignored.
    idx2="$gitdir/qg-tmp-idx2.$$"; rm -f "$idx2"
    bp_rt=$(GIT_INDEX_FILE="$idx2" git -C "$sandbox" -c core.excludesFile=/dev/null read-tree "$base_tree" 2>&1) \
      || { rm -f "$idx2"; guard_fail "b-precise read-tree failed: $bp_rt"; }
    bp_add=$(GIT_INDEX_FILE="$idx2" git -C "$sandbox" -c core.excludesFile=/dev/null add -A -- . 2>&1) \
      || { rm -f "$idx2"; guard_fail "b-precise add -A failed: $bp_add"; }
    cur_tree_neutralized=$(GIT_INDEX_FILE="$idx2" git -C "$sandbox" write-tree 2>&1) \
      || { rm -f "$idx2"; guard_fail "b-precise write-tree failed: $cur_tree_neutralized"; }
    rm -f "$idx2"

    # Restore info/exclude NOW (before Layer 2) + drop the crash-backstop trap.
    restore_excludes
    trap - EXIT INT TERM

    # Pure git-diff set-difference (does NOT read Layer 1's bash arrays, avoiding a
    # coupling bug): paths ADDED only when non-baseline sources are neutralized =
    # smuggled new files. git represents symlinks as mode-120000 tree entries, so a
    # symlink hidden by info/exclude shows up here too (additive with the ls-files
    # symlink loop above → union ⊇ prior coverage).
    bp_neut="$gitdir/qg-bp-neut.$$"; bp_l1="$gitdir/qg-bp-l1.$$"
    bp_nraw="$gitdir/qg-bp-nraw.$$"; bp_lraw="$gitdir/qg-bp-lraw.$$"
    rm -f "$bp_neut" "$bp_l1" "$bp_nraw" "$bp_lraw"
    # Capture each diff to a temp file and check ITS exit (the | cut | sort would
    # otherwise mask a git-diff failure → empty set → silent fail-open). codex-1.
    git -C "$sandbox" diff --name-status --diff-filter=A "$base_tree" "$cur_tree_neutralized" > "$bp_nraw" 2>/dev/null \
      || { rm -f "$bp_neut" "$bp_l1" "$bp_nraw" "$bp_lraw"; guard_fail "b-precise neutralized-diff failed (fail-closed)"; }
    git -C "$sandbox" diff --name-status --diff-filter=A "$base_tree" "$cur_tree" > "$bp_lraw" 2>/dev/null \
      || { rm -f "$bp_neut" "$bp_l1" "$bp_nraw" "$bp_lraw"; guard_fail "b-precise layer1-diff failed (fail-closed)"; }
    cut -f2- "$bp_nraw" | LC_ALL=C sort -u > "$bp_neut"
    cut -f2- "$bp_lraw" | LC_ALL=C sort -u > "$bp_l1"
    rm -f "$bp_nraw" "$bp_lraw"
    while IFS= read -r rel; do
      [[ -z "$rel" ]] && continue
      disallowed+=("$rel"); forced="yes"
    done < <(LC_ALL=C comm -23 "$bp_neut" "$bp_l1")
    rm -f "$bp_neut" "$bp_l1"

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
  create-baseline)
    # 기준선 축(merge_base). 같은 worktrees/ 네임스페이스에 만들어 remove 가드를
    # 그대로 받는다. 본문은 `make_detached_worktree` 가 `create-head` 와 공유한다.
    [[ $# -eq 3 ]] || die "usage: create-baseline <merge-base-sha> <session-id>"
    make_detached_worktree "$2" "$3" base
    ;;
  create-head)
    # HEAD 축(create-sandbox 가 봉인한 커밋 B). **verifier 샌드박스와 별개 트리**다 —
    # 권위 있는 HEAD 테스트가 verifier 의 부팅 setup 이 만든 상태 위에서 돌면 두 축이
    # 같은 환경이라는 이 설계의 전제가 무너지고(§11 ⑬), 테스트 산출물이
    # mutation-guard 의 검사 대상 트리에 떨어져 거짓 terminal FAIL 을 낸다(§6.7 S4).
    # 두 결함 모두 이 분리로 닫힌다.
    [[ $# -eq 3 ]] || die "usage: create-head <sealed-sha> <session-id>"

    # **봉인 확인 (assert-equality).** 앞선 판본은 `$sha` 를 무검증으로 받았다. 그러면
    # 이 자리가 `--baseline-detected` 형제인 *선언된 자유 변수*가 되는데, 그 잔여들과
    # 달리 **부재가 아니라 오값**이라 fail-closed 조차 아니었다: 바로 위 형제
    # `create-baseline "$merge_base" <sid>` 와 인자 모양이 같으므로 `$merge_base` 를
    # 넘기는 실수 하나로 HEAD 축이 기준선의 바이트 복사본이 되고, 전 unit 이
    # `(P,P) → STILL_GREEN → closed` 로 접혀 **degrade 신호 하나 없이 PASS** 가 난다.
    # R7 은 자기 `baseline_sha` 로 샌드박스만 보므로 HEAD 트리가 어느 커밋에서 왔는지
    # 알지 못한다 (/qg iter-7 리뷰, security-reviewer CRITICAL).
    #
    # 왜 "샌드박스 HEAD 에서 **도출**" 이 아니라 "**대조**" 인가 (adversarial 판정).
    # 도출은 신뢰 앵커를 피검자에게 넘긴다 — verifier 는 그 샌드박스 안에서 Write·Bash 를
    # 쥐고 있어 `B` 위에 커밋할 수 있고, 그러면 HEAD 축의 내용을 verifier 가 고르게 된다.
    # 대조는 **거부만 할 수 있고 선택은 못 한다**: 값의 출처는 여전히 오케스트레이터가
    # 들고 있는 `baseline_sha`(= R7 이 가드에 넘기는 바로 그 값)이고, 이 검사는 그것이
    # 이 세션의 봉인과 다를 때 죽을 뿐이다. verifier 가 샌드박스 HEAD 를 움직이면 그것도
    # 여기서 fail-closed 로 죽고 R7 의 reflog 플래그가 별도로 잡는다.
    # (digest 로 봉인된 스냅샷에서 읽는 안은 불가 — 그 7필드에 baseline SHA 가 없다.)
    ch_sid_short="${3:0:8}"
    [[ -n "$ch_sid_short" ]] || die "empty session-id"
    ch_root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not a git repo"
    ch_root=$(cd "$ch_root" && pwd -P) || die "cd failed: $ch_root"
    ch_sandbox="$ch_root/.claude/quality-gates/worktrees/rt-${ch_sid_short}"
    [[ -d "$ch_sandbox" ]] \
      || die "no sealed sandbox for this session: $ch_sandbox — create-head must follow create-sandbox in the same session (HEAD axis has no sealed commit to attach to)"
    ch_sealed=$(git -C "$ch_sandbox" rev-parse HEAD 2>/dev/null) \
      || die "cannot read sealed commit from sandbox: $ch_sandbox"
    [[ "$2" == "$ch_sealed" ]] \
      || die "sealed-sha mismatch: got '$2' but this session's sandbox is at '$ch_sealed' — the HEAD axis must be built from commit B, not from merge_base or a stale retry value"

    make_detached_worktree "$2" "$3" head
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
