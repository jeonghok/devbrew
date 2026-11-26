#!/usr/bin/env bash
# audit-sandbox.sh — plugin-audit 자체 테스트 격리용 일회용 샌드박스.
#
# Subcommands:
#   create-sandbox <session-id> -> echoes 3 lines: sandbox abs path, baseline SHA,
#                                  snapshot digest (disposable worktree at
#                                  <repo>/.claude/worktrees/audit-rt-<sid8>, mirroring the
#                                  working tree, git-ignored files excluded; sealed as
#                                  commit B; snapshot sealed by an orchestrator-held digest)
#   mutation-guard <sandbox> <B> <snapshot-digest>
#                                -> echoes YAML: tracked_diff / disallowed_new_files /
#                                   guard_flags / forced_downgrade (pure git).
#                                   Verifies the snapshot digest before trusting it.
#   remove <abs-path>            -> best-effort removal of own copies only:
#                                   <repo>/.claude/worktrees/audit-rt-<1-8 chars>.
#                                   A link is removed as a link; a worktree holding a branch is kept.
#
# Kill switch: DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX=1 — `create-sandbox` exits 3
# (distinct from die's exit 2). The caller (scripts/run-own-tests.sh) then skips the run.
# The legacy name DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX=1 is honored as an alias:
# same exit 3, and the one stderr line names it and its rename.
#
# 이 샌드박스는 저장소 상태만 격리한다 — 프로세스 · 네트워크 · uid 격리는 없다
# (scripts/run-own-tests.sh 머리말의 알려진 한계).

set -u

die() { echo "audit-sandbox: $*" >&2; exit 2; }

# 이 스크립트가 지우는 것은 자기 이름 꼴의 사본뿐이다 — 새 자리 `<top>/.claude/worktrees/audit-rt-<sid8>`
# 는 사용자 · 지휘자의 worktree 와 같은 폴더라서, 자리 · 이름 · 브랜치 여부를 모두 맞춘 것만 지운다.
# 판정은 글자가 아니라 신원(물리 경로 · -ef)으로 한다 — 대소문자를 구분하지 않는 파일시스템에서
# 이름이 대소문자만 다른 사용자 폴더가 자기 것으로 읽히지 않게.

# 마지막 성분은 풀지 않고(링크는 링크로 남긴다) 부모만 물리 경로로 푼다. 부모가 없으면 받은 그대로.
resolve_leaf() {   # <path>
  local dir leaf
  dir=$(dirname "$1"); leaf=$(basename "$1")
  if [[ -d "$dir" ]]; then
    dir=$(cd "$dir" && pwd -P) || return 1
    printf '%s/%s\n' "$dir" "$leaf"
  else
    printf '%s\n' "$1"
  fi
}

# 등록된 worktree 가 브랜치를 쥐고 있나 — porcelain 블록마다 경로를 신원으로 견준다.
# 그 경로가 등록돼 있고 브랜치를 쥐면 참, 등록이 없거나 detached 면 거짓. 목록을 읽지 못하면 지우지 않고 멈춘다.
holds_branch() {   # <abs-path>
  local want cur="" branch="" line list
  want=$(resolve_leaf "$1")
  list=$(git worktree list --porcelain 2>/dev/null) \
    || die "등록된 worktree 목록을 읽지 못했다(git worktree list) — 브랜치를 쥐었는지 몰라 지우지 않는다: $1"
  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      if [[ -n "$cur" ]] && { [[ "$cur" == "$want" ]] || [[ "$cur" -ef "$1" ]]; }; then
        [[ -n "$branch" ]]; return
      fi
      cur=""; branch=""
    elif [[ "$line" == "worktree "* ]]; then
      cur=$(resolve_leaf "${line#worktree }")
    elif [[ "$line" == "branch "* ]]; then
      branch="${line#branch }"
    fi
  done < <(printf '%s\n' "$list"; echo)
  return 1
}

# 폴더 안에 그 이름이 글자 그대로 있나 (find -name 은 대소문자를 구분한다).
spelled_exactly() {   # <dir> <name>
  [[ -n "$(find "$1" -mindepth 1 -maxdepth 1 -name "$2" -print 2>/dev/null)" ]]
}

# 자기 이름 꼴의 사본 하나를 치운다. 부모가 아예 없으면 할 일이 없다. 부모를 끝까지 풀어 기대한 자리가
# 아니면(링크 · 리포 밖) 지우지 않고 멈춘다. 링크는 링크만 지운다 · 이름이 대소문자만 다르면 멈춘다 ·
# 브랜치를 쥔 worktree 는 멈춘다 · 그 밖은 지운다.
drop_own_copy() {   # <path> <expected-physical-parent>
  local path="$1" want_parent="$2" real_parent
  real_parent=$(cd "$(dirname "$path")" 2>/dev/null && pwd -P) || return 0
  [[ "$real_parent" == "$want_parent" ]] \
    || die "사본 자리가 기대한 곳이 아니다(링크?) — 지우지 않는다: $(dirname "$path") -> $real_parent"
  if [[ -L "$path" || -e "$path" ]]; then
    spelled_exactly "$real_parent" "$(basename "$path")" \
      || die "이름이 대소문자만 다른 항목이다 — 지우지 않는다: $path"
  fi
  git worktree prune >/dev/null 2>&1 || true
  if [[ -L "$path" ]]; then
    rm -f -- "$path" || die "링크를 지우지 못했다: $path"
  elif [[ -e "$path" ]]; then
    if holds_branch "$path"; then die "브랜치를 쥔 worktree 라 지우지 않는다: $path"; fi
    git worktree remove --force --force "$path" >/dev/null 2>&1 || rm -rf -- "$path" \
      || die "사본을 지우지 못했다: $path"
  fi
  git worktree prune >/dev/null 2>&1 || true
}

case "${1:-}" in
  create-sandbox)
    # Disposable git worktree reflecting the main working tree (code-under-
    # review), sealed into an immutable baseline commit B. §6.3 of the spec.
    [[ $# -eq 2 ]] || die "usage: create-sandbox <session-id>"
    if [[ "${DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX:-0}" == "1" ]]; then
      echo "audit-sandbox: runtime sandbox disabled via DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX=1 — orchestrator must fall back to read-only smoke mode" >&2
      exit 3   # distinct from die's exit 2 → SKILL branches on this
    fi
    if [[ "${DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX:-0}" == "1" ]]; then
      echo "audit-sandbox: runtime sandbox disabled via DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX=1 (legacy name, renamed to DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX — set that instead) — orchestrator must fall back to read-only smoke mode" >&2
      exit 3
    fi
    sid="$2"
    sid_short="${sid:0:8}"
    [[ -n "$sid_short" ]] || die "empty session-id"
    case "$sid_short" in
      *[!A-Za-z0-9_-]*) die "bad session-id (A-Z a-z 0-9 _ - 만 허용): $sid" ;;
    esac
    main_root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not a git repo"
    main_root=$(cd "$main_root" && pwd -P) || die "cd failed: $main_root"
    [[ -n "$main_root" ]] || die "empty repo root"
    parent="$main_root/.claude/worktrees"
    # 리뷰 대상 리포가 커밋한 `.claude` · `.claude/worktrees` 링크가 리포 밖을 가리키면 아래 지우기가
    # 리포 밖에서 일어난다. 만들기 전에 가장 깊은 실재 조상을, 만든 뒤에 parent 를 물리 경로로 풀어 견준다.
    anc="$parent"
    while [[ -n "$anc" && "$anc" != "/" && ! -d "$anc" ]]; do anc=$(dirname "$anc"); done
    anc=$(cd "$anc" && pwd -P) || die "cd failed: $anc"
    case "$anc/" in
      "$main_root"/*) ;;
      *) die "사본 자리가 리포 밖을 가리킨다 — 만들지 않는다: $parent -> $anc" ;;
    esac
    mkdir -p "$parent" || die "cannot create $parent"
    parent=$(cd "$parent" && pwd -P) || die "cd failed: $parent"
    [[ "$parent" == "$main_root/.claude/worktrees" ]] \
      || die "사본 자리가 기대한 곳이 아니다(리포 안의 다른 곳을 가리키는 링크?) — 만들지 않는다: $parent"
    sandbox="$parent/audit-rt-${sid_short}"

    # Idempotent: 앞 실행이 남긴 같은 이름의 사본은 일회용이라 치우고 다시 만든다 — 새 기준선이
    # 앞 실행의 상태를 물려받지 않게.
    drop_own_copy "$sandbox" "$parent"
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
        # 어떤 세션의 사본이든 사본 안으로 복사하지 않는다 — audit-rt-* 전부.
        # 같은 폴더의 다른 worktree(.claude/worktrees/feat-x 등)는 지금처럼 복사된다.
        .claude/worktrees/audit-rt-*) continue ;;
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
  remove)
    # 같은 의미의 다른 사본: plugins/quality-gates/scripts/qg-worktree.sh 의 `remove` — 의미가 같다(가드 바꾸면 둘 다).
    [[ $# -eq 2 ]] || die "usage: remove <abs-path>"
    target="$2"
    # 받는 것: <repo>/.claude/worktrees/audit-rt-<1~8자> 뿐.
    # 그 폴더는 사용자 worktree 와 함께 쓴다 — 이름이 자기 꼴이 아니면 거부한다.
    top=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    top=$(cd "$top" && pwd -P) || die "cd failed: $top"
    [[ -n "$top" ]] || die "empty repo root"
    # 마지막 성분은 풀지 않는다(링크는 링크로 본다). 부모는 가장 깊은 실재 조상을 실경로로 풀어 붙인다(macOS /var → /private/var).
    leaf=$(basename "$target")
    anc=$(dirname "$target"); rest=""
    while [[ -n "$anc" && ! -d "$anc" && "$anc" != "/" && "$anc" != "." ]]; do
      rest="/$(basename "$anc")$rest"; anc=$(dirname "$anc")
    done
    if [[ -d "$anc" ]]; then anc=$(cd "$anc" && pwd -P) || die "cd failed: $anc"; fi
    tparent="$anc$rest"
    in_scope=0
    case "$tparent" in
      "$top/.claude/worktrees")
        [[ "$leaf" =~ ^audit-rt-[A-Za-z0-9_-]{1,8}$ ]] && in_scope=1 ;;
    esac
    [[ "$in_scope" -eq 1 ]] || die "refuse to remove outside namespace: $target"
    victim="$tparent/$leaf"
    if [[ -L "$victim" || -e "$victim" ]]; then
      spelled_exactly "$tparent" "$leaf" \
        || die "이름이 대소문자만 다른 항목이다 — 지우지 않는다: $target"
    fi
    if [[ -L "$victim" ]]; then
      rm -f -- "$victim" || die "링크를 지우지 못했다: $target"   # 링크만 지운다 — 가리키는 곳은 건드리지 않는다
      exit 0
    fi
    [[ -d "$victim" ]] || exit 0
    if holds_branch "$victim"; then die "브랜치를 쥔 worktree 라 지우지 않는다: $target"; fi
    git worktree remove --force --force "$victim" 2>/dev/null || rm -rf -- "$victim" \
      || die "worktree remove and rm -rf both failed: $target"
    ;;
  *)
    die "unknown subcommand: ${1:-}"
    ;;
esac
