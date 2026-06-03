# qg b-precise backup simplification (round-3) — guard-created mktemp, drop cross-run pre-restore

> Status: **APPROVED (spec-distill 3-round adversarial review, 2026-06-03; 14 issues
> resolved) but DEFERRED — NOT implemented.** The user chose to stop at the integrity-sound
> codex-1..6 fix state (committed `45a6a24` + `fde0602`); the shipped guard closes F1's six
> integrity siblings without this redesign. This document is the ready-to-implement starting
> point if/when the predictable-path class (codex-7/8/9 + the root cause) is revisited.
> Supersedes the F1 `.qgbak`-hardening approach in
> `2026-06-02-qg-mutation-guard-round2-digest-seal-design.md` §pre-restore (the sha-gated
> `$f.qgbak` pre-restore loop) — that approach would be replaced wholesale, not patched.

## Context / Why

The qg `mutation-guard` Layer 1b ("b-precise") detects product files hidden ONLY by
non-baseline ignore sources (`info/exclude`, `core.excludesFile`). To do this it must
temporarily **neutralize** `info/exclude`: back it up, empty the live file, run a
baseline-anchored detection pass, then restore it.

The round-2/round-3 implementation backed up to a **predictable path** `$f.qgbak` in the
**shared common gitdir** and additionally tried to **recover** a `$f.qgbak` left by a
prior crashed run (the "pre-restore" loop). Because `$f.qgbak` is verifier-writable and
its name is predictable, a model-diverse review (codex) found **six successive integrity
bypasses of this one helper** across five passes — all variants of "the verifier plants
something at the predictable backup/restore path":

- **codex-2**: plant `$f.qgbak` as a *directory* → backup `mv` moves live exclude INTO it (silent corruption).
- **codex-3**: plant the *live* `info/exclude` as a directory → restore `mv` moves backup INTO it.
- **codex-6**: plant `$f.qgbak` = original content + tamper live → pre-restore overwrites the tamper, *erasing* `ignore_channel_tampered` evidence.
- **codex-7**: `[[ -f ]]` follows symlinks → a symlink `.qgbak`/live bypasses the "regular file" checks.
- **codex-8 / codex-5**: restore `mv` / blind `restore_excludes` install a non-guard-created `.qgbak`.

None of these is a Law-2 *self-approval bypass* — the core guarantee (a verifier cannot make
a product mutation PASS) held throughout, verified by the security + adversarial reviewers.
All six are **integrity** corruption of the orchestrator's own `info/exclude`, or
fail-closed-contract gaps, in a *defense-in-depth helper*. The pattern shows the
predictable verifier-targetable backup path + cross-run recovery is a complexity/risk sink
that whack-a-mole is not converging. This redesign cuts the class at the root.

## Goals

1. Eliminate the **plant-attack class** (codex-2/3/6/7) structurally: the verifier must have
   no predictable, pre-creatable path that the guard's backup/restore machinery trusts.
2. Preserve the b-precise *detection* capability unchanged (files hidden by
   `info/exclude`/`core.excludesFile` still caught; baseline-ignored artifacts like
   `node_modules/` still NOT flagged).
3. Preserve the **fail-closed posture**: any anomaly in the backup/restore path → `guard_fail`
   (exit 4), never a false PASS.
4. Keep the Law-2 self-approval guarantee and the digest-seal / Layer 0–3 architecture
   intact and untouched.

## Non-goals

- Cross-run crash *content recovery* of `info/exclude` (see Constraints — explicitly dropped).
- OS-level egress / symlink-following sandbox hardening beyond the guard's own paths
   (out of scope, unchanged).
- Any change to Layers 0 (seal), 1 (read-tree-seeded index), 2 (ignore/config tamper),
   3 (immutable `B^{tree}`), or the snapshot/digest mechanism.
- Backing up / restoring `core.excludesFile`. b-precise neutralizes `core.excludesFile` for
   its detection pass via the `-c core.excludesFile=/dev/null` override on the
   `read-tree`+`add` (a config flag, not a file move) — unchanged, needs no backup. Only
   `info/exclude` (which has no per-invocation override) uses the backup/empty/restore dance,
   so D1–D3 are correctly scoped to `info/exclude` (common + per-worktree) ONLY; this is a
   design decision, not an omission. `core.excludesFile` *tampering* is independently caught
   by Layer 2 (AC5 + the existing `C-A(iii)` test), and a `core.excludesFile`-hidden new file
   by the neutralized pass (the existing `R2-AC2(iii)` test, unchanged).

## Design

### D0 — Security foundation: the sequential-turn model (why mktemp is unplantable)

Every claim below rests on one structural fact, made explicit here because it is the
load-bearing security ground (the same turn-isolation the digest-seal relies on):
**the `mutation-guard` runs as a single shell invocation in the orchestrator turn,
strictly AFTER the runtime-verifier subagent's turn has fully ended.** The orchestrator
(SKILL) dispatches the verifier subagent, waits for it to complete, and only then calls the
guard — the verifier and the guard never execute concurrently, and no verifier code runs at
any point during the guard's backup → empty → detect → restore sequence. (This is the same
writer/reviewer turn separation that makes the whole Law-2 guard sound.)

Consequences relied on by D1/D2:

- The gitdir **is** verifier-writable — that is precisely why the predictable `$f.qgbak`
  path was attackable. But a path the guard **creates fresh during its own run**, after the
  verifier's turn ended, cannot have been pre-created or raced by the verifier: there is no
  concurrent writer to win a TOCTOU against.
- `mktemp "$gitdir/qg-excl-bak.XXXXXX"` uses an **explicit gitdir prefix**, so `mktemp` does
  NOT consult `$TMPDIR`; a verifier-controlled `TMPDIR` is irrelevant to where the backup
  lands. (The verifier cannot influence the guard's environment anyway — separate turn,
  separate process.)
- The restore window (D2) is inside the same uninterrupted guard execution, so the live
  target cannot be swapped (e.g. to a symlink/dir) between backup and restore — no verifier
  runs there to do it. This is why D2 needs no restore-time re-validation beyond an
  exit-checked `mv`.

### D1 — Backup to a guard-created `mktemp` path (not `$f.qgbak`)

For each of the common (`$qg_ce = $common/info/exclude`) and per-worktree
(`$qg_we = $gitdir/info/exclude`) excludes that exists at backup time:

Two explicit blocks (NOT a generic `$f` loop) so the `bak_ce` / `bak_we` mapping is
unambiguous — AC8's "absent ⇒ `bak_we` stays unset" depends on this exact structure:

```sh
bak_ce= ; bak_we=          # run-local; empty ⇒ "no backup taken for this path"

# --- common info/exclude ($qg_ce = $common/info/exclude) ---
# live must be a genuine regular file (not dir/symlink) — else verifier tamper → fail closed.
[[ ! -e "$qg_ce" || ( -f "$qg_ce" && ! -L "$qg_ce" ) ]] || guard_fail "non-regular info/exclude (tamper): $qg_ce"
if [[ -f "$qg_ce" && ! -L "$qg_ce" ]]; then
  bak_ce=$(mktemp "$gitdir/qg-excl-bak.XXXXXX") || guard_fail "b-precise: cannot create backup tempfile"
  mv "$qg_ce" "$bak_ce" || guard_fail "b-precise: common info/exclude backup mv failed"
  : > "$qg_ce"          || guard_fail "b-precise: cannot reset common info/exclude placeholder"
fi

# --- per-worktree info/exclude ($qg_we = $gitdir/info/exclude); identical shape, bak_we ---
[[ ! -e "$qg_we" || ( -f "$qg_we" && ! -L "$qg_we" ) ]] || guard_fail "non-regular info/exclude (tamper): $qg_we"
if [[ -f "$qg_we" && ! -L "$qg_we" ]]; then
  bak_we=$(mktemp "$gitdir/qg-excl-bak.XXXXXX") || guard_fail "b-precise: cannot create backup tempfile"
  mv "$qg_we" "$bak_we" || guard_fail "b-precise: per-worktree info/exclude backup mv failed"
  : > "$qg_we"          || guard_fail "b-precise: cannot reset per-worktree info/exclude placeholder"
fi
```

When a live exclude is **absent**, the `! -e` branch of the guard passes and the `if` is
skipped, so its `bak_*` stays empty (→ AC8: restore is a no-op for it).

The backup path is **created by the guard during the orchestrator turn**. The verifier ran
earlier (its turn is over) and is not concurrent, so it **cannot pre-create or target** a
fresh random `mktemp` name. There is no predictable path to plant at. This removes the
entire premise of codex-2/3/6/7.

### D2 — Restore only the guard's own backups (run-local var, trap-safe)

The trap handler is a **best-effort crash backstop** — it must NOT call `guard_fail` (that
exits, which would re-enter the EXIT context and risk double-emitting the verdict YAML):

```sh
# Trap = best-effort only: put originals back if the guard is killed mid-pass. Restores
# exclusively THIS run's backups (bak_* set ⇒ D1 succeeded), so a leftover at the old
# $f.qgbak path is never consulted (codex-5 dissolved). No guard_fail here → no recursion.
restore_excludes() {
  [[ -n "${bak_we:-}" && -f "$bak_we" ]] && mv -f "$bak_we" "$qg_we"
  [[ -n "${bak_ce:-}" && -f "$bak_ce" ]] && mv -f "$bak_ce" "$qg_ce"
  return 0
}
trap restore_excludes EXIT INT TERM
```

The **fail-closed** restore is the INLINE one on the normal path, run after the detection
pass and BEFORE dropping the trap:

```sh
[[ -n "${bak_we:-}" && -f "$bak_we" ]] && { mv -f "$bak_we" "$qg_we" || guard_fail "b-precise: per-worktree exclude restore failed"; }
[[ -n "${bak_ce:-}" && -f "$bak_ce" ]] && { mv -f "$bak_ce" "$qg_ce" || guard_fail "b-precise: common exclude restore failed"; }
trap - EXIT INT TERM
```

> **No trap recursion (NEW-1):** if an inline restore `mv` fails it calls `guard_fail` →
> `exit 4`; the still-armed EXIT trap then runs `restore_excludes` **once** (bash does not
> re-enter an EXIT trap that itself exits) and, because that handler contains no
> `guard_fail`, it cannot recurse or re-emit. Net effect: a single fail-closed `exit 4`. The
> trap is dropped immediately after the successful inline restore so it does not fire on a
> clean exit.

> **Restore-time re-validation (deliberate decision, not an omission):** the restore `mv -f`
> is NOT preceded by a re-check that `$qg_*` is still a regular non-symlink. Per D0 the
> verifier cannot swap the live path during the guard's run (no concurrent execution), so
> the backup-time non-regular/symlink check (D1) is sufficient — there is no TOCTOU window a
> verifier could use between backup and restore. The inline restore `mv -f` is still
> exit-checked so an unexpected failure (disk, permissions) fails closed (codex-8).

### D3 — Drop the cross-run pre-restore loop entirely

The sha-gated/filetype/live-state `$f.qgbak` pre-restore loop (round-3 codex-2..6 hardening)
is **removed**. There is no cross-run recovery of a `$f.qgbak` orphaned by a prior crash.

### D4 — Exit-check the b-precise transformation pipeline (codex-9)

**Decision: temp-file capture (NOT `set -o pipefail`).** Each `git diff` is captured to a
temp file with its exit checked (already done for codex-1); the `cut`/`sort` then read from
that file as a separate exit-checked step, and the `comm` set-difference likewise — no
pipeline whose middle stage can mask a failure. **Rationale:** macOS `/bin/bash` 3.2's
`set -o pipefail` interacts poorly with the NUL / process-substitution patterns already in
this code (see the NUL caveat in Constraints), and per-step capture gives precise
fail-closed diagnostics. Every step's non-zero exit routes to `guard_fail`.

## Constraints

- **Accepted degradation (replaces the dropped recovery):** if the guard is hard-killed
  (SIGKILL / power loss) *between* D1's `: > "$f"` and D2's restore — a millisecond window,
  and only when the EXIT/INT/TERM trap *also* fails to run — the live `info/exclude` is left
  emptied and the backup remains as an orphaned `qg-excl-bak.XXXXXX` in the gitdir. The
  **next** run's `create-sandbox` captures the (now-empty) `info/exclude` as its baseline, so
  there is **no false-positive** on subsequent runs; the only cost is that the user's local
  `info/exclude` *content* (e.g. `.omx/`) is lost (recoverable from the orphan, or by
  re-adding patterns). This is a rare, fail-safe trade for eliminating the bypass class. The
  trap already covers normal termination; this window is the residual.
- **Orphan inertness (why no false-positive on later runs):** a leftover
  `qg-excl-bak.XXXXXX` from a hard crash lives inside the gitdir (`$gitdir/`), i.e. the git
  directory — git never scans `.git/` for tracked or untracked files (`git status` / `add -A`
  / `git diff` operate on the work tree). `snap_get` reads only the fixed
  `qg-mutation-snapshot` path; Layer 2 reads only the specific `info/exclude` /
  `core.excludesFile` paths. So an orphan backup is invisible to Layers 0–3 on every
  subsequent run — it can cause neither a false-positive nor a false-negative, only consume
  trivial disk until the gitdir/sandbox is removed. And because the next run's
  `create-sandbox` re-captures the (now-empty) `info/exclude` as its baseline, the emptied
  live file is itself not flagged on later runs.
- Tests run from repo root via `/bin/bash` (macOS 3.2.57 NUL caveat). qg has no CI; only
  new/changed tests gate regression (8 pre-existing reds on main are out of scope).
- `plugin.json` stays `2.2.0` (unmerged base; round-3 folds into the same unreleased version).
- Persona files (`security-reviewer.md`, `adversarial.md`) are security-sensitive; the
  Law-3 broadenings from round-3 stay (still correct — "any verifier-writable path the guard
  reads/writes"). No persona weakening.
- **Sequential-turn invariant is load-bearing (§D0) and must be preserved.** The SKILL's
  Runtime gate dispatches the runtime-verifier subagent and only calls `mutation-guard`
  *after* that subagent's turn completes — never concurrently. This redesign's safety rests
  on it, so it is an invariant: any future refactor that parallelizes verifier and guard
  execution (or runs the guard mid-verifier-turn) **requires re-review of this design**.
  `SKILL.md` is intentionally NOT in Files to Modify — this change does not alter the
  dispatch order, only the guard's internal backup mechanism; the invariant is documented
  here so a later editor does not break it silently.

## Acceptance Criteria

- **AC1 (clean round-trip):** clean sandbox → `forced_downgrade: no`. The test snapshots
  the original `info/exclude` to a sibling path (e.g. `cp "$COMMON/info/exclude"
  "$COMMON/info/exclude.orig"`) BEFORE invoking the guard, then asserts `cmp -s` equality
  against the live file AFTER the guard returns (byte-identical round-trip — needed because
  D1 *moves* the original to the mktemp backup), and asserts no `qg-excl-bak.*` remains in
  the gitdir on the happy path (`find "$gitdir" -name 'qg-excl-bak.*'` is empty).
- **AC2 (detection preserved):** file hidden via common `info/exclude` with Layer 2
  forged-silent → still caught by b-precise (`disallowed_new_files` includes it); baseline
  `.gitignore`-matched artifact (`node_modules/x.js`) → NOT flagged.
- **AC3 (live non-regular → fail closed):** live `info/exclude` planted as a *directory* OR
  a *symlink* → `guard_fail` exit 4, and the orchestrator's live path is NOT corrupted
  (backup `mv` never moves it into a dir / follows a link).
- **AC4 (old `.qgbak` path inert):** planting anything (dir, regular file, symlink) at the
  legacy `$common/info/exclude.qgbak` path has **no effect** on the verdict and is never
  installed as the live exclude (the guard does not read it).
- **AC5 (tamper still caught):** appending a rule to live `info/exclude` (rule-only, no file)
  → `forced_downgrade: yes` with `ignore_channel_tampered` (Layer 2 — unaffected by the
  backup change; no pre-restore can erase it because there is none).
- **AC6 (fail-closed pipeline, codex-9):** a forced failure of the b-precise diff OR its
  `cut`/`sort`/`comm` transformation → `guard_fail` exit 4 (mutation test).
- **AC7 (no regression):** the new/changed tests are green AND previously-green tests stay
  green — the 8 pre-existing `main` reds are explicitly out of scope (a test already red on
  `main` before this change does not gate). Concrete invocation, from repo root via
  `/bin/bash` (macOS 3.2.57 NUL caveat): `/bin/bash plugins/quality-gates/tests/test_qg_mutation_guard.sh`
  (prints `… 0 failed`), `… test_qg_runtime_sandbox.sh`, `… test_qg_worktree_helper.sh`
  (each `0 failed`), and `… tests/harness/test_skill_orchestration_behavior.sh`
  (`all … PASS`).
- **AC8 (absent live skipped cleanly):** when the per-worktree `info/exclude` is ABSENT at
  backup time, D1's `! -e "$f"` branch skips the backup (no `bak_we` set), `restore_excludes`
  is a no-op for that path, and a clean sandbox still yields `forced_downgrade: no` (no
  spurious backup/restore of a non-existent file, no orphan created).

## Files to Modify

- `plugins/quality-gates/scripts/qg-worktree.sh` — `mutation-guard`: delete the pre-restore
  loop (D3); rewrite the b-precise backup (D1) + `restore_excludes` (D2); add D4 exit-checks.
  Remove now-unused helpers (`snap_get`-based pre-restore gating is gone; `snap_get` itself
  stays — used by Layer 2).
- `plugins/quality-gates/tests/test_qg_mutation_guard.sh` — replace the round-3 `.qgbak`
  tests (R3-AC1a/b/d/e + R3-AC2b: all test the removed `.qgbak` machinery) with the
  **AC1–AC6 AND AC8** tests above (AC7 is the suite-wide no-regression *criterion*, not a
  single test case); keep/adapt R3-AC1c (live dir → fail-closed) and R3-AC2a (codex-1 diff
  exit-check); rewrite the old "b-precise crash-recovery" test to the new no-recovery
  behavior (emptied `info/exclude` post-snapshot → `forced_downgrade: yes`). The implementer
  owns writing all of AC1–AC6 + AC8 as concrete test cases — none is deferred.
- `plugins/quality-gates/CHANGELOG.md` — replace/extend the round-3 `[2.2.0] ### Fixed`
  bullet to describe the simplified mechanism (mktemp backup, no cross-run recovery,
  bypass-class eliminated at root).

## Verification Plan

1. TDD: write AC1–AC6 tests, confirm the relevant ones RED against current code, implement
   D1–D4, confirm GREEN + full-suite no-regression.
2. Independent review via **codex** (`-s read-only` — leak-proof; the reviewer that found
   the class). **Go/no-go (not just a target):**
   - any **new CRITICAL or HIGH** finding → STOP, escalate to the user; do NOT keep patching
     (this redesign exists *because* whack-a-mole did not converge — a high finding means the
     root-cause approach itself needs re-examination);
   - **MEDIUM-only** findings → at most ONE hardening pass + one codex re-run; if a medium
     persists or a new one appears, escalate;
   - **LOW-only / advisory** → record as follow-up, proceed.
   Convergence = a codex pass with zero CRITICAL/HIGH/MEDIUM findings. Optionally one
   adversarial Claude pass with a hardened cwd-isolation preamble (read-only intent; verify
   the tree after per step 3).
3. Leak check after every test/review step (`info/exclude` present, `core.excludesfile`
   unset, no `qg-excl-bak.*`/symlink residue, tree clean) — the cwd-footgun corrupted the
   repo twice already.

## Rejected Alternatives

- **Keep patching `.qgbak` (option ②):** apply codex-7/8/9 and continue. Rejected: 5 rounds,
  9 findings, no clear convergence; the predictable path remains the root cause.
- **Ship with codex-7 fixed + 8/9 deferred (option ③):** Law-2 holds, but leaves a known
  integrity helper with documented gaps and a predictable-path attack surface.
- **Read `info/exclude` into a shell var instead of moving it:** rejected — arbitrary
  (possibly binary/huge) content in a shell var is fragile (NUL/encoding); `mktemp` move is
  faithful and simple.
- **Keep cross-run recovery but anchor it on a marker/sha:** rejected — any cross-run
  recovery needs a discoverable (predictable or marker) path, which reintroduces a
  verifier-targetable surface (the exact root cause).

## Handoff Context

**TL;DR:** Replace the b-precise (Layer 1b) `info/exclude` backup from a predictable,
verifier-targetable `$f.qgbak` path to a guard-created `mktemp` path; drop the cross-run
`.qgbak` pre-restore entirely; restore only this-run backups; fail-closed on a
non-regular/symlink live `info/exclude`; exit-check the b-precise pipeline (temp-file
capture). This deletes the root cause (predictable verifier-writable path) of codex-2/3/6/7
instead of patching each edge.

**Implicit context the implementer needs:**
- Target: `plugins/quality-gates/scripts/qg-worktree.sh`, subcommand `mutation-guard`,
  Layer-1b block. Current shape to transform: a pre-restore loop (DELETE), `restore_excludes`
  + `trap`, the backup (`mv $f $f.qgbak; : > $f`), the neutralized `read-tree`/`add`/
  `write-tree` pass, inline restore + trap drop, and the two `git diff` set-difference steps.
- The load-bearing security ground is the **sequential-turn model** (§D0): the verifier
  subagent fully ends, THEN the orchestrator-turn guard runs; never concurrent. This is what
  makes mktemp unplantable and obviates restore-time re-validation — keep that invariant in
  mind when editing.
- `codex` (`scripts/run_codex_reviewer.sh`, `-s read-only`) is the model-diverse reviewer
  that found all six siblings; it is **leak-proof** (read-only OS sandbox). Re-run it after
  implementation for convergence. The in-house Claude reviewers run Bash repros and have
  twice corrupted this repo via the cwd-footgun.
- **cwd-footgun** ([[feedback_subagent_security_repro_isolation]]): after every test/review
  step, verify the tree — `info/exclude` present, `core.excludesfile` unset, no
  `qg-excl-bak.*`/symlink residue, HEAD unchanged.
- Current working tree = the codex-1..6-fixed implementation (80/80 guard tests). This
  redesign **replaces** it: the `.qgbak` machinery is removed, so the round-3 `.qgbak` tests
  (R3-AC1a/b/d/e, R3-AC2b) are deleted, R3-AC1c (live dir→fail-closed) and R3-AC2a (codex-1
  diff exit-check) are kept/adapted, and the old "crash-recovery" test is rewritten to the
  no-recovery behavior.

**Deferred to plan:** exact line ranges (they shift during editing); the precise test
fixtures for AC1–AC8; whether to keep or rename the existing "crash-recovery" test.

## Metadata

- Author: orchestrator (round-3 continuation), 2026-06-03.
- Branch: `feature/qg-sandbox-executor`; plugin.json 2.2.0 (unmerged).
- Trust model unchanged: sealed snapshot (digest) is the trust anchor; Law-2 self-approval
  guarantee holds end-to-end (this change only simplifies a defense-in-depth helper).
- Discovery: model-diverse codex review across 5 passes (codex-2..7); see History in
  `.claude/quality-gates/<sid>/pipeline.md`.
