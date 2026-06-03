# qg v2.2.0 mutation-guard round-2 (digest-seal) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close C-NEW-1 (verifier-writable snapshot = master key) by sealing the pre-verifier snapshot with an orchestrator-held digest, add a snapshot-independent `b-precise` detector, fix the empty-index false-positive (I-NEW-2), and harden the two reviewer personas + the vacuous test that let the bypass escape review.

**Architecture:** Three structural additions to the existing 4-layer fail-closed mutation-guard plus a Law-3 review hardening. (1) **digest-seal**: `create-sandbox` emits `git hash-object <snapshot>` as output **line 3**; the orchestrator (SKILL turn) captures it into a verifier-unreachable channel and threads it as the guard's **3rd argument**; the guard recomputes-and-compares before trusting the snapshot — forge → `guard_fail` exit 4. (2) **b-precise**: a second baseline-anchored `read-tree`+`add -A` pass that neutralizes only the *non-baseline* ignore sources (`info/exclude`, `core.excludesFile`) and flags, via pure git-diff set-difference, new files hidden only by them — snapshot-independent defense-in-depth that absorbs the symlink-only Layer-1b gap. (3) **read-tree seed**: Layer 1's temp index is seeded from `B^{tree}` instead of empty, so force-tracked ignored files no longer false-positive. (4) **Law-3**: explicit "is the guard's trusted artifact verifier-writable?" checks added to `security-reviewer.md` + `adversarial.md`, and the vacuous H-AC3(ii) test rewritten to isolate Layer 2.

**Tech Stack:** bash 3.2-compatible shell (macOS `/bin/bash` 3.2.57 — NUL-in-`$(...)` gotcha applies; read NUL-delimited output via files/process-sub, never variable capture), git plumbing (`hash-object`, `read-tree`, `write-tree`, `diff --name-status --diff-filter=A`, `comm`), POSIX tools. Tests are bash scripts run **from the repo root** via `/bin/bash`. The plugin has **no CI**; `main` carries 8 pre-existing stale reds + 3 pytest collection errors, so only the green of *new/modified* tests is the regression signal.

---

## Baseline, Conventions & Safety (read before Task 1)

- **Branch:** `feature/qg-sandbox-executor`, work **in place** (no worktree). HEAD currently at the round-1.5 hardening (`plugin.json` = 2.2.0).
- **Version:** `plugins/quality-gates/.claude-plugin/plugin.json` stays **2.2.0** — this is the unmerged base being *completed*, not a new release (round-1.5 precedent). Do **not** bump. Task 8 verifies it.
- **Test runner (always):** `/bin/bash <path-from-repo-root>`. Never run shell tests under the Bash tool's interactive shell alone — bash 4/5 preserves NUL in `$(...)` and can mask the 3.2.57 NUL bug. The two guard/SKILL tests have shebang `#!/usr/bin/env bash`; invoke them as `/bin/bash plugins/quality-gates/tests/...` to exercise the production gotcha.
- **Security-sensitive files (test-suite-level care):** `scripts/qg-worktree.sh` (the guard = a security control), `agents/security-reviewer.md`, `agents/adversarial.md`. Treat persona edits with the same gravity as editing the test suite (CLAUDE.md).
- **P21:** the guard hashes file *contents* but only ever emits/compares the *hash*. Never echo a secret value or file content to stdout/evidence. The `info/exclude` neutralize→restore must not print file contents.
- **Throwaway-repo rule:** every guard reproduction runs inside a fresh `mktemp -d` + `git init` repo (the existing `mk_sandbox` helper). **Never** run `create-sandbox`/`mutation-guard` against the real devbrew working tree — b-precise *temporarily renames the sandbox common-dir's `.git/info/exclude`*, which in production is the real repo's; in tests the common-dir is the throwaway repo's `.git`, so there is no risk. The real working tree MUST stay clean.
- **Commits:** commit per task (the steps below include the exact `git commit`). Do **not** push or open a PR unless the user asks.

**Pre-flight baseline capture (do this once, as the very first action of Task 1, before any edit):**

```bash
cd /Users/jeonghokim/Downloads/devbrew
/bin/bash plugins/quality-gates/tests/test_qg_mutation_guard.sh; echo "guard rc=$?"
/bin/bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh; echo "orch rc=$?"
git status --porcelain   # MUST be empty (clean tree)
```

Expected at baseline (round-1.5 state): both print their pass summary and `rc=0`; `git status` is empty. Record the two pass counts — they are the floor; no modified/new test may go red without a corresponding intended change.

---

## File Structure (decomposition map)

| File | Responsibility in this change | Tasks |
|---|---|---|
| `plugins/quality-gates/scripts/qg-worktree.sh` | create-sandbox line-3 digest emit; guard 3-arg + Layer-0 digest verify; Layer-1 read-tree seed; Layer-1b b-precise + neutralization trap | 1,2,3,4 |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | R0 line-3 capture + parse contract; R4 guard 3-arg; NEEDS_RESOLUTION retry 3-value recapture; Law-2 header line | 5 |
| `plugins/quality-gates/agents/security-reviewer.md` | persona check: guard-trusted artifact verifier-writability | 6 |
| `plugins/quality-gates/agents/adversarial.md` | same persona check | 6 |
| `plugins/quality-gates/tests/test_qg_mutation_guard.sh` | 3-arg migration + R2-AC1/AC2/AC3 + de-vacuum H-AC3(ii) (R2-AC4) | 1,2,3,4,7 |
| `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` | static asserts: line-3 capture, guard 3-arg, retry 3-value, persona grep (R2-AC5) | 5,6 |
| `plugins/quality-gates/CHANGELOG.md` | amend `[2.2.0]` with round-2 (digest-seal, b-precise, read-tree, persona) | 8 |
| `docs/superpowers/specs/2026-06-01-qg-mutation-guard-hardening-design.md` | round-2 supersede pointers on §5 row + §10 bullet | 8 |
| `plugins/quality-gates/.claude-plugin/plugin.json` | **no change** — verify it stays 2.2.0 | 8 |
| `plugins/quality-gates/agents/runtime-verifier.md` | **no change** — digest is orchestrator-side (explicit non-edit) | — |

---

## Task 1: create-sandbox emits the snapshot digest as output line 3

**Files:**
- Modify: `plugins/quality-gates/scripts/qg-worktree.sh` (header comment `:9-13`; emit `:189-190`)
- Test: `plugins/quality-gates/tests/test_qg_mutation_guard.sh` (first block)

Non-breaking: existing guard tests read only lines 1–2.

- [ ] **Step 1: Capture the baseline** (the pre-flight block above). Confirm both suites green + clean tree.

- [ ] **Step 2: Write the failing test** — add this block immediately after the existing `[create-sandbox: snapshot captured with all 7 keys]` block (after the `cleanup_sandbox "$SANDBOX"` on the current line ~58), so it shares the `mk_sandbox`/`field` helpers:

```bash
echo "[R2-AC1 setup: create-sandbox emits snapshot digest as line 3]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
SNAP="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
EXPECT=$(git -C "$SANDBOX" hash-object "$SNAP")
[ -n "$DIGEST" ] && [ "$DIGEST" = "$EXPECT" ] \
  && pass "create-sandbox line 3 == hash-object of snapshot" || fail "line-3 digest absent/mismatch (got '$DIGEST', want '$EXPECT')"
cleanup_sandbox "$SANDBOX"
```

- [ ] **Step 3: Run it; verify it fails**

Run: `/bin/bash plugins/quality-gates/tests/test_qg_mutation_guard.sh`
Expected: FAIL on `line-3 digest absent/mismatch` (current `create-sandbox` emits only 2 lines, so `DIGEST` is empty), and the overall script exits non-zero.

- [ ] **Step 4: Implement the line-3 emit.** In `qg-worktree.sh`, replace the create-sandbox output line. Old (`:189-190`):

```bash
    # Output contract: line 1 = sandbox abs path, line 2 = baseline SHA.
    printf '%s\n%s\n' "$sandbox" "$base"
```

New:

```bash
    # §6.1 round-2 digest-seal — hash the just-written 7-field snapshot so the
    # orchestrator can hold the digest out-of-band and the guard can verify the
    # snapshot's integrity (verifier-writable file → must be sealed). hash-object
    # is always available in a git context.
    snapshot_digest=$(git -C "$sandbox" hash-object "$snap") || die "cannot digest snapshot: $snap"
    # Output contract (round-1.5 2 lines → 3): line 1 = sandbox abs path,
    # line 2 = baseline SHA, line 3 = snapshot digest.
    printf '%s\n%s\n%s\n' "$sandbox" "$base" "$snapshot_digest"
```

- [ ] **Step 5: Update the header doc comment.** Old (`:9-13`):

```bash
#   create-sandbox <session-id> -> echoes 2 lines: sandbox abs path, baseline SHA
#                                  (disposable worktree mirroring the working tree,
#                                   git-ignored files excluded; sealed as commit B)
#   mutation-guard <sandbox> <B> -> echoes YAML: tracked_diff / disallowed_new_files /
#                                    forced_downgrade (pure git; §6.7)
```

New:

```bash
#   create-sandbox <session-id> -> echoes 3 lines: sandbox abs path, baseline SHA,
#                                  snapshot digest (disposable worktree mirroring the
#                                  working tree, git-ignored files excluded; sealed as
#                                  commit B; snapshot sealed by an orchestrator-held digest)
#   mutation-guard <sandbox> <B> <snapshot-digest>
#                                -> echoes YAML: tracked_diff / disallowed_new_files /
#                                   guard_flags / forced_downgrade (pure git; §6.1-6.3).
#                                   Verifies the snapshot digest before trusting it.
```

- [ ] **Step 6: Run it; verify it passes**

Run: `/bin/bash plugins/quality-gates/tests/test_qg_mutation_guard.sh`
Expected: the new `line-3 digest` assertion PASSes. All previously-green guard tests still pass (they read only lines 1–2; the new 3rd line is ignored by their `sed -n '1p'/'2p'`). Overall `rc=0`.

- [ ] **Step 7: Commit**

```bash
git add plugins/quality-gates/scripts/qg-worktree.sh plugins/quality-gates/tests/test_qg_mutation_guard.sh
git commit -m "feat(quality-gates): create-sandbox emits snapshot digest as output line 3 (digest-seal §6.1)"
```

---

## Task 2: mutation-guard 3-arg contract + Layer-0 digest verification (+ migrate existing tests)

**Files:**
- Modify: `plugins/quality-gates/scripts/qg-worktree.sh` (mutation-guard arg parse `:197-198`; Layer-0 `:206-231`)
- Test: `plugins/quality-gates/tests/test_qg_mutation_guard.sh` (helper + every guard call site + new R2-AC1 blocks)

**This is the breaking change.** A signature break cannot be half-migrated, so this task implements the 3-arg guard AND migrates every existing call site in the same commit.

> **Exit-code reconciliation (read before coding).** Spec §5 prose says "a guard without a digest is indeterminate → `guard_fail`" while §6.1's literal code uses `die` for a wrong *arg count*. Both are non-zero / never-PASS, so the security intent holds either way. Implement §6.1 literally: **wrong arg count (`$# != 4`) → `die` exit 2**; **present-but-empty digest (`$4` is `""`) → `guard_fail` exit 4**. R2-AC1(c) ("digest 누락/빈값 → exit 4") is satisfied by the *empty-digest* path (the indeterminate, well-formed call). The fully-omitted 2-arg path → exit 2 is also asserted (still never-PASS; SKILL R4 routes "any non-zero" to ≤FAIL).

- [ ] **Step 1: Write the failing digest tests** — append these blocks near the end of the test file, just before the final `echo`/`Result:` lines:

```bash
echo "[R2-AC1(a): master-key exploit — forged snapshot + original digest -> guard_fail exit 4]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
SNAP="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
COMMON="$(git -C "$SANDBOX" rev-parse --git-common-dir)"
printf 'BACKDOOR()\n' > "$SANDBOX/onlyhack.js"                 # new product file
echo 'onlyhack.js' >> "$COMMON/info/exclude"                   # evade Layer 1 (add -A honors common exclude)
NEWH=$(git -C "$SANDBOX" hash-object "$COMMON/info/exclude")
sed "s|^excl_common_sha=.*|excl_common_sha=$NEWH|" "$SNAP" > "$SNAP.t" && mv "$SNAP.t" "$SNAP"   # forge Layer 2 ref
# orchestrator still holds the ORIGINAL (pre-forge) digest captured at create time:
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null); RC=$?
[ "$RC" -eq 4 ] && pass "forged snapshot + orig digest -> exit 4 (R2-AC1a)" || fail "master-key exit was $RC (expected 4)"
printf '%s' "$G" | grep -qi "digest" \
  && pass "guard_error cites digest mismatch (R2-AC1a)" || fail "no digest-mismatch reason surfaced"
cleanup_sandbox "$SANDBOX"

echo "[R2-AC1(c): empty digest -> guard_fail exit 4; omitted (2-arg) -> die exit 2]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "" 2>/dev/null); RC=$?
[ "$RC" -eq 4 ] && pass "empty digest -> exit 4 (R2-AC1c)" || fail "empty-digest exit was $RC (expected 4)"
"$WT" mutation-guard "$SANDBOX" "$BASE" >/dev/null 2>&1; RC2=$?
[ "$RC2" -ne 0 ] && pass "2-arg call rejected (exit $RC2, never PASS) (R2-AC1c)" || fail "2-arg call was not rejected"
cleanup_sandbox "$SANDBOX"
```

- [ ] **Step 2: Run; verify failure**

Run: `/bin/bash plugins/quality-gates/tests/test_qg_mutation_guard.sh`
Expected: the new R2-AC1(a)/(c) blocks FAIL — the current 2-arg guard treats a 3rd arg as a usage error (`die` exit 2, not 4) and ignores digest. (Also: many existing 2-arg tests are still green here — they break only after Step 3 changes the signature; that is why Step 4 migrates them in the same task.)

- [ ] **Step 3: Implement the 3-arg contract + Layer-0 digest verify** in `qg-worktree.sh`.

(3a) Arg parse + usage comment. Old (`:192-198`):

```bash
  mutation-guard)
    # 4-layer fail-closed product-mutation oracle (spec §6.2). Inputs are ONLY
    # (sandbox, baseline B) + a snapshot create-sandbox wrote in the per-worktree
    # gitdir. No channel for a verifier self-claim → structural Law 2 defense.
    # Execution order locked: layer 0 → 1 → 2 → 3 → aggregate.
    [[ $# -eq 3 ]] || die "usage: mutation-guard <sandbox-abs> <baseline-sha>"
    sandbox="$2" base="$3"
```

New:

```bash
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
```

(3b) Digest-present check — insert immediately AFTER the `guard_fail() { ... }` definition (after its closing `}` at `:213`), before `[[ -d "$sandbox" ]]`:

```bash
    # ---- Layer 0 (round-2): snapshot digest seal ----
    # A missing/empty digest means the orchestrator did not seal this snapshot →
    # indeterminate → never PASS (§6.1; distinct from a 2-arg usage error = die 2).
    [[ -n "$expected_digest" ]] || guard_fail "missing snapshot digest (seal absent → indeterminate)"
```

(3c) Recompute + compare — insert immediately AFTER the 7-key assert `for k in ...; do ... done` loop (after `:231`), before the `snap_get()` definition (`:232`):

```bash
    # Seal check: recompute the digest of the (verifier-reachable) snapshot and
    # compare to the orchestrator-held value. A forged snapshot → mismatch →
    # guard_fail (closes C-NEW-1: the verifier cannot forge the trust reference
    # because it cannot reach the orchestrator-held expected_digest). Runs AFTER
    # the existence + 7-key asserts, so those fail-closed first if applicable.
    recomputed=$(git -C "$sandbox" hash-object "$snap" 2>&1) \
      || guard_fail "cannot recompute snapshot digest: $recomputed"
    [[ "$recomputed" == "$expected_digest" ]] \
      || guard_fail "snapshot integrity check failed (digest mismatch — possible verifier tamper)"
```

- [ ] **Step 4: Migrate every existing 2-arg call site to 3-arg.** The transformation is mechanical and uniform:

  1. In each test block that calls the guard, after the line that sets `SANDBOX`/`BASE` from `mk_sandbox` output, also capture the digest: `DIGEST=$(sed -n '3p' <<<"$OUT")`.
  2. Append `"$DIGEST"` as the 3rd argument to every `"$WT" mutation-guard "$SANDBOX" "$BASE"` invocation.

  Concrete example — the `[mutation-guard: clean sandbox -> no downgrade]` block becomes:

```bash
echo "[mutation-guard: clean sandbox -> no downgrade]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: no" ] \
  && pass "clean sandbox -> forced_downgrade: no" || fail "clean misreported: $(field "$G" forced_downgrade)"
cleanup_sandbox "$SANDBOX"
```

  **Two special blocks** need explicit handling:

  - `[C-B: bad baseline sha -> guard_fail exit 4]` (currently captures only `SANDBOX`): add `DIGEST=$(sed -n '3p' <<<"$OUT")` and call `"$WT" mutation-guard "$SANDBOX" "deadbeef…deadbeef" "$DIGEST"`. (The bad-baseline `rev-parse` fails inside Layer 0 before the digest is compared → still exit 4.)
  - `[C-A(iii-tilde): ~/-relative core.excludesFile smuggle]` (uses a custom `OUT=$(cd "$R" && HOME="$THOME" "$WT" create-sandbox …)`): capture `DIGEST=$(sed -n '3p' <<<"$OUT")` from that same `OUT` and pass it: `G=$(HOME="$THOME" "$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)`. The snapshot is unchanged by the attack (it appends to `$THOME/.gitignore_global`, not the snapshot), so the original digest still matches and Layer 2 fires `ignore_channel_tampered`.

  Note on `NEW-03(b)` (snapshot malformed — key removed): keep passing the original `DIGEST`. The 7-key assert fails *before* the digest recompute, so it still exits 4 (the digest is never compared). No special handling needed.

- [ ] **Step 5: Add the remaining R2-AC1 verification blocks** (b/d/e) near the other new blocks:

```bash
echo "[R2-AC1(b): no-forge variant — info/exclude changed, snapshot intact -> Layer 2 ignore_channel_tampered]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
COMMON="$(git -C "$SANDBOX" rev-parse --git-common-dir)"
printf 'export const fix=1\n' > "$SANDBOX/onlyhack.js"
echo 'onlyhack.js' >> "$COMMON/info/exclude"     # change ignore, DO NOT touch the snapshot
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null); RC=$?
[ "$RC" -ne 4 ] && pass "no-forge: digest valid, guard does not fail-closed (R2-AC1b)" || fail "no-forge wrongly exit 4"
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "no-forge -> forced_downgrade: yes (Layer 2) (R2-AC1b)" || fail "no-forge not caught"
printf '%s' "$G" | grep -q "ignore_channel_tampered" \
  && pass "ignore_channel_tampered flagged (R2-AC1b)" || fail "Layer 2 tamper flag missing"
cleanup_sandbox "$SANDBOX"

echo "[R2-AC1(d): clean sandbox + correct digest + no tamper -> forced_downgrade: no]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: no" ] \
  && pass "clean + correct digest -> no downgrade (R2-AC1d)" || fail "clean+digest misreported"
cleanup_sandbox "$SANDBOX"

echo "[R2-AC1(e): honest tracked mutation + correct digest -> forced_downgrade: yes (digest does NOT short-circuit Layer 1)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
printf 'orig\nHACKED TO PASS\n' > "$SANDBOX/tracked.txt"
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "honest mutation + correct digest -> forced (R2-AC1e)" || fail "Layer 1 short-circuited by digest pass"
printf '%s' "$G" | grep -q "tracked.txt" \
  && pass "tracked.txt surfaced (R2-AC1e)" || fail "tracked.txt not surfaced"
cleanup_sandbox "$SANDBOX"
```

- [ ] **Step 6: Run the full guard suite + completeness grep**

Run:
```bash
/bin/bash plugins/quality-gates/tests/test_qg_mutation_guard.sh; echo "rc=$?"
# Completeness gate: no guard call may remain 2-arg. This prints any line that
# calls mutation-guard without a visible 3rd token. Expected: NO output.
grep -nE '"\$WT" mutation-guard "\$SANDBOX" "\$[A-Za-z_]+" *2?>?' plugins/quality-gates/tests/test_qg_mutation_guard.sh \
  | grep -vE 'mutation-guard "\$SANDBOX" "\$[A-Za-z_]+" "\$' || echo "no stray 2-arg calls"
```
Expected: `rc=0`, all R2-AC1 + all migrated round-1.5 blocks green; the grep prints `no stray 2-arg calls` (the `"deadbeef…"` literal-baseline C-B call is the only one with a literal middle arg — confirm by eye that it has `"$DIGEST"` appended).

- [ ] **Step 7: Commit**

```bash
git add plugins/quality-gates/scripts/qg-worktree.sh plugins/quality-gates/tests/test_qg_mutation_guard.sh
git commit -m "feat(quality-gates): mutation-guard 3-arg digest-seal contract + Layer-0 verify (closes C-NEW-1)"
```

---

## Task 3: Layer-1 read-tree seed (I-NEW-2 empty-index false-positive fix)

**Files:**
- Modify: `plugins/quality-gates/scripts/qg-worktree.sh` (Layer 1 `:243-248`)
- Test: `plugins/quality-gates/tests/test_qg_mutation_guard.sh`

- [ ] **Step 1: Write the failing test** (force-tracked ignored file, clean sandbox):

```bash
echo "[R2-AC3(a): force-tracked ignored file, no mutation -> forced_downgrade: no (I-NEW-2)]"
R=$(mktemp -d)
(cd "$R" && git init -q -b main && git config user.email t@t && git config user.name t)
printf 'orig\n' > "$R/tracked.txt"
printf '*.log\n.env\n' > "$R/.gitignore"
printf 'debug\n' > "$R/debug.log"
(cd "$R" && git add -A && git add -f debug.log && git commit -q -m init)   # debug.log is tracked despite *.log ignore
OUT=$(cd "$R" && "$WT" create-sandbox "inew2guard0123456" 2>/dev/null)
SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: no" ] \
  && pass "force-tracked ignored, clean -> no downgrade (R2-AC3a)" || fail "I-NEW-2 false-positive: $(field "$G" tracked_diff)"
cleanup_sandbox "$SANDBOX"
```

- [ ] **Step 2: Run; verify failure**

Run: `/bin/bash plugins/quality-gates/tests/test_qg_mutation_guard.sh`
Expected: FAIL — the empty-index `add -A` (no `-f`) re-excludes the tracked `debug.log`, so `cur_tree` drops it → `cur_tree != base_tree` → spurious `forced_downgrade: yes` with `tracked_diff` containing `debug.log`.

- [ ] **Step 3: Seed the Layer-1 temp index from the baseline tree.** Old (`:243-248`):

```bash
    idx="$gitdir/qg-tmp-idx.$$"; rm -f "$idx"
    add_out=$(GIT_INDEX_FILE="$idx" git -C "$sandbox" add -A -- . 2>&1) \
      || { rm -f "$idx"; guard_fail "add -A failed: $add_out"; }
    cur_tree=$(GIT_INDEX_FILE="$idx" git -C "$sandbox" write-tree 2>&1) \
      || { rm -f "$idx"; guard_fail "write-tree failed: $cur_tree"; }
    rm -f "$idx"
```

New:

```bash
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
```

- [ ] **Step 4: Run; verify the new test passes**

Run: `/bin/bash plugins/quality-gates/tests/test_qg_mutation_guard.sh`
Expected: R2-AC3(a) PASSes (`forced_downgrade: no`).

- [ ] **Step 5: Add C-E + .env preservation regressions** (these must stay green — the read-tree seed must not weaken them). The existing `C-E(a)`, `C-E(b)`, and `git-ignored .env` blocks already cover R2-AC3(b)/(c)/(d); add explicit AC-labelled aliases only if the existing ones don't already assert it. To avoid duplication, instead add a single confirmation comment-block that re-runs the `.env` PASS path with the digest (already migrated in Task 2) and re-runs C-E — verify by running the full suite. (No new code needed beyond Task 2's migration; this step is a verification, not an edit.)

Run: `/bin/bash plugins/quality-gates/tests/test_qg_mutation_guard.sh; echo "rc=$?"`
Expected: `rc=0` — C-E(a)/(b) still `forced_downgrade: yes` (read-tree drops index bits → add -A re-stats → caught); `.env` still `forced_downgrade: no`.

- [ ] **Step 6: Commit**

```bash
git add plugins/quality-gates/scripts/qg-worktree.sh plugins/quality-gates/tests/test_qg_mutation_guard.sh
git commit -m "fix(quality-gates): seed Layer-1 temp index from B^{tree} (I-NEW-2 false-positive)"
```

---

## Task 4: Layer-1b b-precise — baseline-anchored detection of non-baseline-hidden files

**Files:**
- Modify: `plugins/quality-gates/scripts/qg-worktree.sh` (Layer-0 pre-restore after `:220`; Layer-1b after `:277`)
- Test: `plugins/quality-gates/tests/test_qg_mutation_guard.sh`

This is the largest task: it adds the `.qgbak` neutralization (with idempotent pre-restore + crash-backstop trap), the second baseline-anchored `read-tree`+`add -A` pass, the pure git-diff set-difference, and the symlink union. Restore happens **inline before Layer 2** (Layer 2 hashes `info/exclude` against the snapshot; an un-restored empty file would false-fire).

- [ ] **Step 1: Write the failing de-vacuum isolation tests** (Layer 2 forged-off + matching digest, so only Layer 1b can produce `forced=yes`):

```bash
echo "[R2-AC2(i): common info/exclude-hidden new file, Layer 2 forged-off -> Layer 1b sole catch]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
SNAP="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
COMMON="$(git -C "$SANDBOX" rev-parse --git-common-dir)"
printf 'export const fix=1\n' > "$SANDBOX/onlyhack.js"
echo 'onlyhack.js' >> "$COMMON/info/exclude"
NEWH=$(git -C "$SANDBOX" hash-object "$COMMON/info/exclude")
sed "s|^excl_common_sha=.*|excl_common_sha=$NEWH|" "$SNAP" > "$SNAP.t" && mv "$SNAP.t" "$SNAP"
DIGEST=$(git -C "$SANDBOX" hash-object "$SNAP")     # digest of the patched snapshot -> Layer 0 passes
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "common-hidden file -> forced (Layer 1b sole, R2-AC2i)" || fail "b-precise common EVADED"
printf '%s' "$G" | grep -q "onlyhack.js" \
  && pass "onlyhack.js in disallowed_new_files (R2-AC2i)" || fail "onlyhack.js not surfaced"
printf '%s' "$G" | grep -q "ignore_channel_tampered" \
  && fail "Layer 2 fired — de-vacuum NOT isolated (R2-AC2i)" || pass "Layer 2 silent — de-vacuum isolation holds (R2-AC2i)"
cleanup_sandbox "$SANDBOX"

echo "[R2-AC2(iii): core.excludesFile-hidden new file, Layer 2 forged-off -> Layer 1b sole catch]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
SNAP="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
REPO="${SANDBOX%/.claude/quality-gates/worktrees/*}"
EXC="$REPO/.qg_excludes"; echo 'onlyhack.js' > "$EXC"          # throwaway-internal path (N-4: no host ~/.gitconfig)
git -C "$SANDBOX" config --local core.excludesFile "$EXC"
printf 'export const fix=1\n' > "$SANDBOX/onlyhack.js"
EFH=$(git -C "$SANDBOX" hash-object "$EXC")
sed "s|^excludesfile=.*|excludesfile=$EXC|; s|^excludesfile_sha=.*|excludesfile_sha=$EFH|" "$SNAP" > "$SNAP.t" && mv "$SNAP.t" "$SNAP"
DIGEST=$(git -C "$SANDBOX" hash-object "$SNAP")
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "excludesFile-hidden file -> forced (Layer 1b sole, R2-AC2iii)" || fail "b-precise excludesFile EVADED"
printf '%s' "$G" | grep -q "ignore_channel_tampered" \
  && fail "Layer 2 fired — de-vacuum NOT isolated (R2-AC2iii)" || pass "Layer 2 silent (R2-AC2iii)"
cleanup_sandbox "$SANDBOX"

echo "[R2-AC2(ii): per-worktree info/exclude-hidden new file, Layer 2 forged-off -> caught (Layer 1 structural)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
SNAP="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
WTDIR="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)"
printf 'export const fix=1\n' > "$SANDBOX/onlyhack.js"
mkdir -p "$WTDIR/info"; echo 'onlyhack.js' >> "$WTDIR/info/exclude"
NEWW=$(git -C "$SANDBOX" hash-object "$WTDIR/info/exclude")
sed "s|^excl_wt_sha=.*|excl_wt_sha=$NEWW|" "$SNAP" > "$SNAP.t" && mv "$SNAP.t" "$SNAP"
DIGEST=$(git -C "$SANDBOX" hash-object "$SNAP")
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
# add -A ignores per-worktree info/exclude in a linked worktree, so Layer 1 stages
# the file; b-precise neutralizes it too. Either way it is caught WITHOUT Layer 2.
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "per-worktree-hidden file -> forced w/o Layer 2 (R2-AC2ii)" || fail "per-worktree file EVADED"
printf '%s' "$G" | grep -q "onlyhack.js" \
  && pass "onlyhack.js surfaced (R2-AC2ii)" || fail "onlyhack.js not surfaced"
cleanup_sandbox "$SANDBOX"

echo "[R2-AC2(iv): baseline .gitignore-matched new file -> no downgrade (usability)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
mkdir -p "$SANDBOX/node_modules"; printf 'x\n' > "$SANDBOX/node_modules/x.js"   # baseline .gitignore has node_modules/
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: no" ] \
  && pass "baseline-ignored runtime artifact -> no downgrade (R2-AC2iv)" || fail "node_modules false-FAILed"
cleanup_sandbox "$SANDBOX"

echo "[R2-AC2(v): info/exclude-hidden new symlink -> forced (symlink coverage union)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
SNAP="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
COMMON="$(git -C "$SANDBOX" rev-parse --git-common-dir)"
( cd "$SANDBOX" && ln -s /etc/hosts hacklink )
echo 'hacklink' >> "$COMMON/info/exclude"
NEWH=$(git -C "$SANDBOX" hash-object "$COMMON/info/exclude")
sed "s|^excl_common_sha=.*|excl_common_sha=$NEWH|" "$SNAP" > "$SNAP.t" && mv "$SNAP.t" "$SNAP"
DIGEST=$(git -C "$SANDBOX" hash-object "$SNAP")
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "info/exclude-hidden symlink -> forced (R2-AC2v)" || fail "b-precise symlink EVADED"
cleanup_sandbox "$SANDBOX"
```

- [ ] **Step 2: Run; verify failure**

Run: `/bin/bash plugins/quality-gates/tests/test_qg_mutation_guard.sh`
Expected: R2-AC2(i) and (iii) FAIL — with Layer 2 forged-off and a matching digest, the current Layer-1b (symlink-only) does not stage a hidden *regular* file, so `forced_downgrade: no`. (ii)/(iv)/(v) may already pass via Layer 1 / baseline-ignore / the existing ls-files symlink loop; (i)/(iii) are the red that drives the implementation.

- [ ] **Step 3: Add the idempotent pre-restore in Layer 0.** Insert immediately AFTER the common-dir resolution line `case "$common" in /*) ;; *) common="$sandbox/$common" ;; esac` (`:220`), before `base_tree=$(...)`:

```bash
    # ---- b-precise pre-restore (§6.2 step 1a; load-bearing for correctness) ----
    # A prior guard killed mid-neutralization may have left info/exclude as an
    # empty file with the original renamed to .qgbak. Restore BEFORE Layer 2 reads
    # info/exclude (else now-vs-snapshot would compare an empty file → false
    # ignore_channel_tampered). Per-file independent → safe on partial recovery.
    qg_ce="$common/info/exclude"
    qg_we="$gitdir/info/exclude"
    for f in "$qg_ce" "$qg_we"; do
      [[ -f "$f.qgbak" ]] && mv -f "$f.qgbak" "$f"
    done
```

- [ ] **Step 4: Add the b-precise block** immediately AFTER the existing Layer-1b ls-files loop and its `[[ ${#disallowed[@]} -gt 0 ]] && forced="yes"` line (`:277`), and BEFORE the `# ---- Layer 2:` comment (`:279`):

```bash
    # ---- Layer 1b (b-precise): baseline-anchored detection of new files hidden
    #      ONLY by non-baseline ignore sources (info/exclude, core.excludesFile).
    #      Trusted ignore source = baseline .gitignore ONLY (tracked, in B^{tree};
    #      its tamper is caught by Layer 1). info/exclude + core.excludesFile are
    #      untrusted (verifier-writable, absent from B). snapshot-INDEPENDENT, so a
    #      bug in the digest seal or Layer 2 still leaves this detector standing.
    #      Restore inline BEFORE Layer 2; the trap is a crash-only backstop. ----
    restore_excludes() {
      # reverse of backup order: per-worktree first, then common (common is shared).
      [[ -f "$qg_we.qgbak" ]] && mv -f "$qg_we.qgbak" "$qg_we"
      [[ -f "$qg_ce.qgbak" ]] && mv -f "$qg_ce.qgbak" "$qg_ce"
      return 0
    }
    trap restore_excludes EXIT INT TERM
    # backup (common first, then per-worktree) via atomic rename + empty placeholder.
    if [[ -f "$qg_ce" ]]; then
      mv "$qg_ce" "$qg_ce.qgbak" || guard_fail "b-precise: common info/exclude backup failed"
      : > "$qg_ce"
    fi
    if [[ -f "$qg_we" ]]; then
      mv "$qg_we" "$qg_we.qgbak" || guard_fail "b-precise: per-worktree info/exclude backup failed"
      : > "$qg_we"
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
    bp_neut="$gitdir/qg-bp-neut.$$"; bp_l1="$gitdir/qg-bp-l1.$$"; rm -f "$bp_neut" "$bp_l1"
    git -C "$sandbox" diff --name-status --diff-filter=A "$base_tree" "$cur_tree_neutralized" 2>/dev/null \
      | cut -f2- | LC_ALL=C sort -u > "$bp_neut"
    git -C "$sandbox" diff --name-status --diff-filter=A "$base_tree" "$cur_tree" 2>/dev/null \
      | cut -f2- | LC_ALL=C sort -u > "$bp_l1"
    while IFS= read -r rel; do
      [[ -z "$rel" ]] && continue
      disallowed+=("$rel"); forced="yes"
    done < <(LC_ALL=C comm -23 "$bp_neut" "$bp_l1")
    rm -f "$bp_neut" "$bp_l1"
```

- [ ] **Step 5: Run; verify the new tests pass**

Run: `/bin/bash plugins/quality-gates/tests/test_qg_mutation_guard.sh`
Expected: R2-AC2(i)/(ii)/(iii)/(iv)/(v) all PASS. In particular (i)/(iii) now `forced_downgrade: yes` with `onlyhack.js` surfaced and Layer 2 silent (de-vacuum isolation), and (iv) stays `forced_downgrade: no`.

- [ ] **Step 6: Run the full suite (regression)**

Run: `/bin/bash plugins/quality-gates/tests/test_qg_mutation_guard.sh; echo "rc=$?"`
Expected: `rc=0`. Confirm specifically that the existing `[C-A(i): common-dir info/exclude smuggle]` block still flags `ignore_channel_tampered` (Layer 2 unchanged because the snapshot is NOT forged there — b-precise is additive), the `.env` PASS block stays `no`, and clean stays `no`.

- [ ] **Step 7: Commit**

```bash
git add plugins/quality-gates/scripts/qg-worktree.sh plugins/quality-gates/tests/test_qg_mutation_guard.sh
git commit -m "feat(quality-gates): Layer-1b b-precise baseline-anchored detector (absorbs I-NEW-1; defense-in-depth)"
```

---

## Task 5: SKILL wiring — line-3 digest capture, guard 3-arg, retry 3-value recapture

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` (Law-2 header `:46`; R0 `:405`; R4 `:448`; retry `:527`)
- Test: `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`

- [ ] **Step 1: Write the failing static asserts.** Append, before the final `if [[ "$fail" -eq 0 ]]` block in `test_skill_orchestration_behavior.sh`:

```bash
# --- round-2 digest-seal wiring ---

# R0 must capture snapshot_digest as line 3.
assert_line "R0 captures snapshot_digest (line 3)" "$(first_line 'snapshot_digest')"

# Guard call must thread the 3rd arg: a line containing both `mutation-guard`
# and `snapshot_digest` (the R4 call line, or the Law-2 header mention).
if grep -qE 'mutation-guard.*snapshot_digest' "$SKILL_MD"; then
  echo "PASS: R4 guard call threads snapshot_digest (3-arg)"
else
  echo "FAIL: R4 guard call does not thread snapshot_digest"
  fail=$((fail + 1))
fi

# I-G retry must re-capture snapshot_digest (line 3) in addition to the two existing.
if grep -E 're-capture' "$SKILL_MD" | grep -q 'snapshot_digest'; then
  echo "PASS: retry re-captures snapshot_digest"
else
  echo "FAIL: retry does not re-capture snapshot_digest"
  fail=$((fail + 1))
fi
```

- [ ] **Step 2: Run; verify failure**

Run: `/bin/bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: FAIL on the three new assertions (SKILL.md has no `snapshot_digest` yet).

- [ ] **Step 3a: Edit the Law-2 header line.** Old (`:46`, the inline guard mention):

```
after it runs you compute `qg-worktree.sh mutation-guard <sandbox> <baseline>` and, if `forced_downgrade: yes`, you cap the verdict at FAIL regardless of what the verifier claimed.
```

New:

```
after it runs you compute `qg-worktree.sh mutation-guard <sandbox> <baseline> <snapshot_digest>` and, if `forced_downgrade: yes`, you cap the verdict at FAIL regardless of what the verifier claimed. The `<snapshot_digest>` is the orchestrator-held seal (captured at create-sandbox) that the guard verifies before trusting its snapshot — the verifier cannot reach it (§6.1).
```

- [ ] **Step 3b: Edit R0 capture + parse contract.** Old (`:405`):

```
- Exit 0 → capture **line 1 = `sandbox_dir`**, **line 2 = `baseline_sha`**. Set `runtime_project_dir = sandbox_dir` (the verifier's `project_dir` for this gate, frozen — overrides the preflight `project_dir` for the Runtime gate only).
```

New:

```
- Exit 0 → capture **line 1 = `sandbox_dir`**, **line 2 = `baseline_sha`**, **line 3 = `snapshot_digest`**. Parse contract (fixed): read exactly three lines with three successive `IFS= read -r` (`sandbox_dir` → `baseline_sha` → `snapshot_digest`) and strip trailing whitespace/CR from `snapshot_digest` (`tr -d '[:space:]'` or equivalent) — a stray newline/space in the hex makes the guard fail-closed on every run. Hold all three as orchestrator variables (verifier-unreachable: they live in this SKILL turn's context, not in the sandbox). Set `runtime_project_dir = sandbox_dir` (the verifier's `project_dir` for this gate, frozen — overrides the preflight `project_dir` for the Runtime gate only).
```

- [ ] **Step 3c: Edit R4 guard call.** Old (`:448`):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" mutation-guard "<sandbox_dir>" "<baseline_sha>"
```

New:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" mutation-guard "<sandbox_dir>" "<baseline_sha>" "<snapshot_digest>"
```

And, in the R4 routing table row for `exit 4`, the existing "OR a missing/invalid `forced_downgrade` key" clause already covers digest mismatch (it surfaces as `guard_fail` exit 4). Add one sentence after the table (after `:461`'s paragraph) so the digest case is explicit:

```
A digest mismatch (the verifier forged the snapshot) surfaces here as **exit 4** with `guard_error: snapshot integrity check failed` — the same fail-closed path as any other indeterminate guard. This is the round-2 closure of C-NEW-1: the seal the guard checks is held by the orchestrator, out of the verifier's reach.
```

- [ ] **Step 3d: Edit the NEEDS_RESOLUTION retry to re-capture all three values.** Old (`:527`, the "Yes, retry" bullet):

```
- **Yes, retry** → increment resolution counter; if exceeds env limit, fall through to Skip with evidence. Otherwise re-create the sandbox (Step R0) and **re-capture BOTH `sandbox_dir` (line 1) AND `baseline_sha` (line 2)** from the new output, refreshing the orchestrator variables — create-sandbox emits a NEW commit `B` each call, so reusing the old `baseline_sha` makes the guard `guard_fail "bad baseline sha"` (a false FAIL). The new snapshot is auto-recorded in the new gitdir; the stale sandbox + its old snapshot are force-removed by R0's idempotent cleanup. Then re-dispatch runtime-verifier with the refreshed `sandbox_dir`.
```

New:

```
- **Yes, retry** → increment resolution counter; if exceeds env limit, fall through to Skip with evidence. Otherwise re-create the sandbox (Step R0) and re-capture the new output's `sandbox_dir` (line 1), `baseline_sha` (line 2), and `snapshot_digest` (line 3) with the same three successive `IFS= read -r` + digest-strip idiom as R0 — refreshing **all three** orchestrator variables. create-sandbox emits a NEW commit `B` AND a NEW snapshot (hence a new digest) each call, so reusing the old `baseline_sha` makes the guard `guard_fail "bad baseline sha"` and reusing the old `snapshot_digest` makes it `guard_fail "snapshot integrity check failed"` — both false FAILs. The new snapshot is auto-recorded in the new gitdir; the stale sandbox + its old snapshot are force-removed by R0's idempotent cleanup. Then re-dispatch runtime-verifier with the refreshed `sandbox_dir`, and call R4 as 3-arg with the refreshed `snapshot_digest`. (Fix the parse order: capturing the digest as line 2 swaps `baseline_sha`/`snapshot_digest` and fails-closed every run.)
```

- [ ] **Step 4: Run; verify it passes**

Run: `/bin/bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: all three new assertions PASS plus the pre-existing v2.2.0 assertions (the `re-capture` block now also matches `snapshot_digest`). `all protocol-shape assertions PASS`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
git commit -m "feat(quality-gates): SKILL threads snapshot_digest (R0 capture, R4 3-arg, retry recapture) (§6.4)"
```

---

## Task 6: Law-3 persona hardening (security-reviewer + adversarial) + R2-AC5 static grep

**Files:**
- Modify: `plugins/quality-gates/agents/security-reviewer.md`, `plugins/quality-gates/agents/adversarial.md` (security-sensitive — test-suite-level care)
- Test: `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`

- [ ] **Step 1: Write the failing static grep** — append to `test_skill_orchestration_behavior.sh` before the final block:

```bash
# --- R2-AC5: Law-3 persona hardening (the bypass escaped because reviewers
#     trusted a verifier-writable artifact; the persona now forces that check).
#     Anchor on the stable literal `verifier-writable`, which BOTH persona edits
#     in Task 6 Step 3 include verbatim. ---
AGENTS_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)/agents"
for p in security-reviewer adversarial; do
  if grep -qi 'verifier-writable' "$AGENTS_DIR/$p.md"; then
    echo "PASS: $p persona has the verifier-writable-artifact check"
  else
    echo "FAIL: $p persona missing the verifier-writable-artifact check"
    fail=$((fail + 1))
  fi
done
```

- [ ] **Step 2: Run; verify failure**

Run: `/bin/bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: FAIL on both persona checks.

- [ ] **Step 3a: Add the check to `security-reviewer.md`.** Insert a new bullet at the end of the `## Hunt categories` list (after the `Dependency manifest changes` bullet, `:38`):

```markdown
- **Trusted-artifact custody (Law 2 self-approval surface)** — when reviewing a security control that compares "now" against a stored reference (snapshot, baseline, config, temp file, lockfile), ask: can the *subject being verified* — a subagent holding `Write`, or arbitrary `Bash` inside a sandbox — write that reference or compute its path? If yes, the comparison is meaningless (the subject controls both sides). The trust anchor MUST live out of the subject's reach (orchestrator turn context, or an immutable commit). Flag any verifier-writable comparison ground-truth as CRITICAL.
```

- [ ] **Step 3b: Add the check to `adversarial.md`.** Insert a new gate after **Gate C** (after `:47`, before `A finding must clear all three gates…` at `:49`). Renumber the closing sentence reference accordingly:

```markdown
**Gate D — For security-control findings: is the trust anchor out of the subject's reach?**
When the diff adds or modifies a control that verifies a subject by comparing against a stored reference (snapshot, baseline, config, temp file), check whether the subject being verified (a `Write`-holding subagent or arbitrary sandbox `Bash`) can write that reference or compute its path. If it can, the reference is **verifier-writable** and the control is vacuous — the subject controls both sides of the comparison — so a "this control is sound" finding must be `reject`ed, while an *absence* of this check is itself a real issue to record in `meta_note:`. The trust anchor must live in the orchestrator's turn context or an immutable commit, never in a verifier-writable location.
```

And change the line `A finding must clear all three gates to be \`confirm\`.` (`:49`) to:

```markdown
A finding must clear Gates A–C to be `confirm` (Gate D is a control-soundness lens, not a per-finding pass/fail).
```

- [ ] **Step 4: Run; verify it passes**

Run: `/bin/bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: both persona checks PASS; whole suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/agents/security-reviewer.md plugins/quality-gates/agents/adversarial.md plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
git commit -m "fix(quality-gates): persona check for verifier-writable trust anchors (Law-3 compounding §6.5)"
```

---

## Task 7: De-vacuum the H-AC3(ii) test (R2-AC4) + Layer-2 mutation-test

**Files:**
- Test: `plugins/quality-gates/tests/test_qg_mutation_guard.sh`

The round-1.5 `[C-A(ii): per-worktree gitdir info/exclude smuggle]` passed via Layer 1 (it added a *new file*, which add-A stages), so it never exercised Layer 2's `excl_wt_sha` path — a vacuous assertion. Rewrite it as a **rule-only change (no new file)** so only Layer 2 can fire, and add a mutation-test that disables Layer 2's `excl_wt_sha` comparison and confirms the rewritten case then EVADEs.

- [ ] **Step 1: Rewrite the C-A(ii) block** (replace the existing `[C-A(ii): per-worktree gitdir info/exclude smuggle …]` block):

```bash
echo "[R2-AC4: per-worktree info/exclude RULE-ONLY change (no new file) -> Layer 2 ignore_channel_tampered]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
WTDIR="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)"
mkdir -p "$WTDIR/info"; echo 'phantom-rule-no-such-file' >> "$WTDIR/info/exclude"   # rule only; NO file planted
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "per-worktree info/exclude rule-only -> forced (R2-AC4)" || fail "Layer 2 excl_wt_sha path EVADED"
printf '%s' "$G" | grep -q "ignore_channel_tampered" \
  && pass "ignore_channel_tampered from Layer 2 (R2-AC4)" || fail "Layer 2 tamper flag missing"
# Layer 1/1b must NOT be the catcher (no new/changed tracked file): disallowed must be empty.
printf '%s' "$G" | grep -q "disallowed_new_files: \[\]" \
  && pass "no file flagged — isolation to Layer 2 confirmed (R2-AC4)" || fail "a file was flagged — not isolated to Layer 2"
cleanup_sandbox "$SANDBOX"
```

- [ ] **Step 2: Add the Layer-2 mutation-test** (proves the green above actually traverses Layer 2):

```bash
echo "[R2-AC4 mutation-test: disabling Layer 2 excl_wt_sha comparison -> rule-only change EVADEs]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
WTDIR="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)"
mkdir -p "$WTDIR/info"; echo 'phantom-rule-no-such-file' >> "$WTDIR/info/exclude"
# Build a mutant copy of the guard with the per-worktree exclude comparison neutralized
# (force the excl_wt_sha branch to always compare equal). sed targets the now_excl_w line.
MUT=$(mktemp)
sed 's|"\$now_excl_w" != "\$(snap_get excl_wt_sha)"|"x" != "x"|' "$WT" > "$MUT"
chmod +x "$MUT"
GM=$(/bin/bash "$MUT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$GM" forced_downgrade)" = "forced_downgrade: no" ] \
  && pass "mutant (Layer 2 excl_wt disabled) -> EVADE: forced_downgrade: no (R2-AC4 mutation)" \
  || fail "mutant did NOT evade — the green is not actually traversing Layer 2"
rm -f "$MUT"
cleanup_sandbox "$SANDBOX"
```

> Implementation note for the implementer: the `sed` pattern in the mutation-test must match the exact `[[ "$now_excl_w" != "$(snap_get excl_wt_sha)" || … ]]` condition fragment in `qg-worktree.sh` (Layer 2, currently `:293`). If a prior task reformatted that line, update the `sed` LHS string to match the current source verbatim, then re-run. The test self-verifies the mutant evades, so a mis-targeted `sed` (no substitution → identical to original → still `forced: yes`) will fail loudly with "mutant did NOT evade".

- [ ] **Step 3: Run; verify green**

Run: `/bin/bash plugins/quality-gates/tests/test_qg_mutation_guard.sh; echo "rc=$?"`
Expected: R2-AC4 (rule-only) PASSes with `forced: yes` + `ignore_channel_tampered` + `disallowed_new_files: []`; the mutation-test PASSes (mutant → `forced: no`). `rc=0`.

- [ ] **Step 4: Commit**

```bash
git add plugins/quality-gates/tests/test_qg_mutation_guard.sh
git commit -m "test(quality-gates): de-vacuum H-AC3(ii) — isolate Layer-2 excl_wt path + mutation-test (R2-AC4)"
```

---

## Task 8: CHANGELOG amend + round-1.5 supersede pointers + plugin.json verify

**Files:**
- Modify: `plugins/quality-gates/CHANGELOG.md` (`[2.2.0]` entry)
- Modify: `docs/superpowers/specs/2026-06-01-qg-mutation-guard-hardening-design.md` (§5 row `:159`; §10 bullet `:495-496`)
- Verify (no change): `plugins/quality-gates/.claude-plugin/plugin.json`

- [ ] **Step 1: Amend the CHANGELOG `[2.2.0]` `### Fixed` section.** Insert these bullets immediately after the existing `mutation-guard 5개 우회 봉쇄` bullet group (after the `C-E …` bullet ends, before the `C-C SKILL R4` bullet, around `:62`):

```markdown
- **mutation-guard round-2: 6번째 우회(C-NEW-1) + 오탐(I-NEW-2) 봉쇄 (보안).** round-1.5 hardening의
  snapshot이 verifier-writable gitdir에 살아 피검증자가 신뢰 기준을 위조 가능했던 master-key 결함을
  **orchestrator-held digest seal**로 닫음: `create-sandbox`가 snapshot digest를 출력 line 3로 emit →
  orchestrator(SKILL)가 verifier-unreachable 채널로 보유 → `mutation-guard`가 3번째 인자로 받아 신뢰 전
  recompute·비교(위조 시 `guard_fail` exit 4). 추가로 snapshot-독립 **b-precise** 계층 1b를 도입 —
  baseline `.gitignore`만 신뢰 ignore 소스로 인정하고 `info/exclude`·`core.excludesFile`로만 숨겨진 신규
  파일(일반 파일 + symlink)을 2차 baseline-anchored read-tree pass의 git-diff 집합차로 포착(I-NEW-1
  symlink-only 갭 흡수, `node_modules` 등 baseline-ignored 산출물은 미플래그하여 usability 보존).
  I-NEW-2(empty-index false-positive)는 계층 1 임시 index를 `read-tree B^{tree}`로 시드해 제거
  (force-tracked ignored 파일 무변경 시 `forced=no`; C-E catch·`.env` PASS 보존).
- **Law-3 review-mechanism 강화.** 이 우회를 놓친 `security-reviewer`/`adversarial` persona에 "가드가
  신뢰하는 artifact(snapshot/baseline/config)를 피검증자(Write 보유 subagent·샌드박스 Bash)가 쓰거나
  경로 계산할 수 있는가" 체크 추가 + vacuous H-AC3(ii) 테스트를 rule-only 격리 케이스 + Layer-2 비활성
  mutation-test로 재작성. 출력 계약 2줄 → 3줄(snapshot digest)로 정직하게 변경.
```

- [ ] **Step 2: Update the round-1.5 spec §5 row.** Old (`:159` of `2026-06-01-…-design.md`):

```
| snapshot 저장 | **per-worktree gitdir** (`rev-parse --absolute-git-dir`)/qg-mutation-snapshot | 출력 계약 무변경, worktree remove 시 auto-clean |
```

New:

```
| snapshot 저장 | ~~**per-worktree gitdir**, 출력 계약 무변경~~ → **SUPERSEDED by round-2** (`2026-06-02-qg-mutation-guard-round2-digest-seal-design.md` §6.1): snapshot은 여전히 gitdir에 살되 verifier-writable이므로 **orchestrator-held digest로 봉인**(출력 line 3 + guard 3-arg). 무봉인 gitdir 저장이 C-NEW-1 master-key의 근본 원인이었다. | (round-2 정정) |
```

- [ ] **Step 3: Update the round-1.5 spec §10 bullet.** Old (`:495-496`):

```
- **snapshot을 create-sandbox 출력 3번째 줄로** — 출력 계약 변경 → 기존 2-arg 호출/테스트
  깨짐. → per-worktree gitdir 사이드채널(계약 무변경 + auto-clean).
```

New:

```
- **snapshot을 create-sandbox 출력 3번째 줄로** — (당시 기각: 출력 계약 변경 → 2-arg 호출/테스트
  깨짐.) **REVERSED by round-2** (`2026-06-02-qg-mutation-guard-round2-digest-seal-design.md` §6.1):
  snapshot *내용*은 gitdir에 두되 그 *digest*를 출력 line 3로 emit해 orchestrator가 보유 →
  3-arg guard로 봉인. "계약 무변경"의 편의가 정확히 master-key(C-NEW-1)를 만들었으므로 계약 변경
  비용을 수용한다.
```

- [ ] **Step 4: Verify plugin.json is unchanged at 2.2.0** (no edit — explicit verification):

Run: `grep '"version"' plugins/quality-gates/.claude-plugin/plugin.json`
Expected: `"version": "2.2.0",` (unchanged — this is the unmerged base being completed, not a new release).

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/CHANGELOG.md docs/superpowers/specs/2026-06-01-qg-mutation-guard-hardening-design.md
git commit -m "docs(quality-gates): CHANGELOG round-2 + round-1.5 §5/§10 supersede pointers (digest-seal)"
```

---

## Task 9: Full regression + integration verification (R2-AC6)

**Files:** none (verification only; no commit unless a fix is needed).

- [ ] **Step 1: Run the two modified suites + YAML validity**

```bash
cd /Users/jeonghokim/Downloads/devbrew
/bin/bash plugins/quality-gates/tests/test_qg_mutation_guard.sh; echo "guard rc=$?"
/bin/bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh; echo "orch rc=$?"
```
Expected: both `rc=0`. The guard suite covers round-1.5 H-AC1–10 (now 3-arg) + the 8 happy-path blocks + R2-AC1/AC2/AC3/AC4. The orchestration test covers the v2.2.0 protocol-shape + the round-2 digest/persona asserts.

- [ ] **Step 2: Confirm YAML validity of guard output is still asserted** — the existing `[id].tsx` and single-quote (`I-D`) blocks run `python3 -c "import yaml; yaml.safe_load(...)"`. Confirm those PASS in the Step-1 run (or that they print the `pyyaml unavailable` skip). If pyyaml is unavailable locally, note it; do not treat the skip as a failure.

- [ ] **Step 3: Run the broader guard-adjacent suite to catch unintended breakage** (these touch the same script/SKILL):

```bash
/bin/bash plugins/quality-gates/tests/test_qg_runtime_sandbox.sh; echo "sandbox rc=$?"
/bin/bash plugins/quality-gates/tests/test_qg_worktree_helper.sh; echo "helper rc=$?"
/bin/bash plugins/quality-gates/tests/test_skill_orchestration.sh; echo "orch2 rc=$?"
```
Expected: any failures here must be reconciled against the recorded baseline (Task 1). If a test was green at baseline and is now red, fix it before finishing. If it was already among the pre-existing reds, note it as out-of-scope (do NOT "fix" pre-existing reds in this change). The `test_qg_runtime_sandbox.sh` exercises the create-sandbox path most directly — pay attention to whether the new line-3 output broke any 2-line parsing assumption in it; if so, that is in-scope and must be fixed (extend the parse to read 3 lines).

- [ ] **Step 4: Final clean-tree + summary.** Confirm `git status --porcelain` shows only the intended committed changes (working tree clean after commits). Print a short summary of: AC coverage (R2-AC1 a–e, R2-AC2 i–v, R2-AC3 a–d, R2-AC4, R2-AC5, R2-AC6), files changed, and the note that the implementation PR should re-run qg self-review (this time expecting green) per spec §13.

- [ ] **Step 5 (only if Step 3 surfaced an in-scope break):** fix + re-run + commit with `fix(quality-gates): …`. Otherwise no commit.

---

## Self-Review (run after completing all tasks)

1. **Spec coverage:** R2-AC1 (Task 2 a/c/b/d/e), R2-AC2 i–v (Task 4), R2-AC3 a–d (Tasks 3 + Task 2 migration of `.env`/C-E), R2-AC4 (Task 7), R2-AC5 (Task 6), R2-AC6 (Task 9). §6.1 digest-seal (Tasks 1+2+5), §6.2 b-precise (Task 4), §6.3 read-tree (Task 3), §6.4 SKILL (Task 5), §6.5 Law-3 (Tasks 6+7). §8 Files to Modify all covered; `runtime-verifier.md` intentionally untouched; `plugin.json` stays 2.2.0 (Task 8 Step 4).
2. **Architecture-invariant (§6.1, NOT a code task):** the digest seal relies on the verifier running as a *separate Agent subagent turn* so it cannot read the orchestrator's tool-call args. This plan does not change that architecture. If a future change runs the verifier inline in the orchestrator turn, the seal must be redesigned — flag it then.
3. **bash 3.2 NUL:** the b-precise set-difference reads from temp files (`$bp_neut`/`$bp_l1`) and `comm`, and the `comm` results are read via process-substitution `< <(...)` — no `$(git … -z)` variable capture is introduced, so the macOS `/bin/bash` 3.2.57 NUL-strip gotcha does not bite. All tests are run via `/bin/bash`.
4. **Type/name consistency:** guard variable names used across tasks — `expected_digest`, `qg_ce`/`qg_we`, `restore_excludes`, `cur_tree`/`cur_tree_neutralized`, `idx`/`idx2`, `bp_neut`/`bp_l1`; SKILL variables `sandbox_dir`/`baseline_sha`/`snapshot_digest`; create-sandbox emit var `snapshot_digest`. These match between the implementation tasks and the tests.
