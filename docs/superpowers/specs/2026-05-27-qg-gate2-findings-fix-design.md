# quality-gates v1.32.1 — Gate 2 Findings Fix

> **Status:** Approved 2026-05-27 (auto-mode brainstorming, user confirmed scope = all 27+ in branch).
> **Source of findings:** [`docs/superpowers/plans/notes/2026-05-27-gate2-findings.md`](../plans/notes/2026-05-27-gate2-findings.md) — produced by `/qg` v1.31.0 cached SKILL running against this branch.
> **Predecessor spec:** [`2026-05-27-qg-askq-iteration-design.md`](2026-05-27-qg-askq-iteration-design.md) (v1.32.0).
> **Branch:** `worktree-feature-qg-askq-iteration` → PR #71.

## 0. Handoff Context

**TL;DR.** Fix 27+ Gate 2 findings on PR #71 (quality-gates v1.32.0). Bump to v1.32.1 at final commit. Inline execution, per-file-group commits.

**Implicit context an executor MUST hold.**

- **Worktree absolute path** (all Edits/Writes must use this): `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration`.
- **Branch**: `worktree-feature-qg-askq-iteration` (local) → `feature/qg-askq-iteration` (remote). PR #71 is open against `main`.
- **Plugin under fix**: `plugins/quality-gates/`. Cache path users may have stale: `~/.claude/plugins/cache/devbrew/quality-gates/1.32.0/` — cache will invalidate when version bumps to 1.32.1.
- **Source of truth for findings**: `docs/superpowers/plans/notes/2026-05-27-gate2-findings.md` (frozen reference).
- **`project_dir` name collision warning**: there are TWO `project_dir`s in this codebase — one is a per-dispatch runtime parameter (re-introduced by C1, see §5.1), the other was a state-file schema field (removed in v1.32.0, NOT re-introduced). Stale tests that assert the schema field MUST be removed (§5.6.1, §5.6.4).
- **Session-id binding**: state files live at `.claude/quality-gates/<session-id>/`. C2 fix relies on reading `session_id:` from `pipeline.md` frontmatter; ensure preflight scripts can locate this field.
- **String-concat-evasion idiom**: `session-start-advisor.py` line 43 uses `"current" + "_gate:"` (and after fix, also `"consecutive_no" + "_signal:"`) so the source does not contain the literal token. This is anti-grep-self-reference, not a bug. AC17 asserts this evasion stays applied to both keys.

**Deferred to plan (not in spec).**

- Per-commit message templates (commit message is the plan-writer's concern).
- Exact diff regions (line numbers may have shifted between spec write and execution).
- Per-finding rollback strategy (covered by the standard "revert this commit" pattern).
- Order of file-group commits (plan-writer chooses based on file coupling).

## 1. Context / Why

PR #71 (quality-gates v1.32.0 — Stop hook removal + AskUserQuestion iteration) shipped with 27+ Gate 2 findings: 6 Critical, 12 Important, 9 Medium. Several findings are real bugs that escaped Task-15 regression check:

- **Contract breaks** between SKILL.md and reviewer agents (`project_dir` no longer threaded; C1).
- **Regression of P18 unbounded-autonomy guard** (`DEVBREW_GATE3_MAX_RESOLUTIONS` clamp deleted but SKILL prose still claims it; C3).
- **Stale tests from Task 7 miss** (`test_setup_qg.sh` 9/25 fail; v1 `test_session_start_advisor.py` not removed; C4/C5).
- **Race in preflight** (P3 deletes a state file P2 just created; C2).
- **Zero behavioral coverage** of SKILL orchestration (static greps only; C6).
- **Security retry path** allows reviewer-supplied arbitrary `file:` paths (I10).
- **Doc drift** (README v1.5.0 Stop-hook diagram coexists with v1.32.0 diagram; e2e-scenarios still references removed `stop-hook.py`).

User decision: fix all in this branch under v1.32.1 patch bump, single PR (#71), inline execution.

## 2. Goals

- All 6 Critical findings resolved.
- All 12 Important findings resolved.
- All 9 Medium findings resolved.
- v1.32.0 → v1.32.1 patch bump committed atomically with the last fix.
- PR #71 ready for merge after this work (no Gate 2 blockers remaining).
- Each fix's commit body lists the finding IDs it resolves (traceability back to the findings doc).

## 3. Non-goals

- Re-running Gate 2 / `/qg` against the branch (out of scope — runs after merge readiness).
- Resolving the 3 architectural observations (AskUserQuestion consent/progression overload; Orchestrator-as-writer Law-2 softening; test-pyramid regression). These are not bugs; defer to a v1.33.0 design discussion.
- Fixing the Codex script `prompt_build_failed` infra issue. Separate concern.
- Adding new functionality beyond what findings require.

## 4. Constraints

- **devbrew CLAUDE.md Three Laws** apply. Law 2 (writer/reviewer separation) is reinforced by C1 (re-establishing reviewer's `project_dir` contract).
- **Korean-primary docs.** Spec + plan + CHANGELOG entry written in Korean; identifiers/error messages stay English.
- **No commits skip hooks.** All fixes pass project-init hooks (commit format + branch naming).
- **Each plugin-touching commit** complies with `feedback_plugin_version_bump.md`: the *final* commit of this fix series bumps `plugins/quality-gates/.claude-plugin/plugin.json` from `1.32.0` → `1.32.1`. Intermediate commits leave the version at `1.32.0` to avoid churn.
- **Worktree absolute paths** are used in every Edit/Write throughout execution (per `feedback_subagent_worktree_path_emphasis.md`). Branch: `worktree-feature-qg-askq-iteration`.
- **No new P# additions** to devbrew philosophy (per `feedback_devbrew_design_lightness.md`).

## 5. Files to Modify

Grouped by file-cluster, with finding IDs each cluster absorbs.

### 5.1. `plugins/quality-gates/skills/quality-pipeline/SKILL.md`

- **C1** — Add a preflight step that derives `project_dir` and threads `project_dir: "<value>"` into every reviewer agent dispatch (`adversarial`, `test-scope-validator`, `security-reviewer`, `runtime-verifier`). On first invocation: `project_dir=$(pwd)`. On continuation (no such concept in v1.32.0+, but defensive): read from state if present.
  > **Disambiguation**: `project_dir` here is a *runtime dispatch parameter* threaded into reviewer prompts. It is NOT the same as the v1.32.0-removed state-file schema field `project_dir:` (which is intentionally still gone — see §5.6.1 / §5.6.4 stale-assertion removals). The two share a name but have different lifetimes (per-dispatch vs. persisted state).
- **C6** — Reference the new protocol-shape test (`tests/harness/test_skill_orchestration_behavior.sh`) in the testing section. V7's tautological assertion is **deleted and replaced** by the new test as a single atomic change — neither half is permitted to ship without the other. (See §5.6.9 for the "protocol-shape" definition: this test asserts the prompt-defined dispatch protocol exists in SKILL.md with the expected ordering and structural relationships; it does NOT execute the protocol at runtime. "Behavioral" in the original v1.32.0 finding was overclaim; "protocol-shape" is the honest grain.)
- **I6** — Specify Retry-path error handling: if Edit returns `old_string not unique` or `EACCES` or `ENOSPC`, surface the failure to the user via AskUserQuestion ("Retry failed at <file>: <reason>. Skip retry / abort?"). No silent retry-skip.
- **I7** — Remove the SKILL branch on `check-trivia.sh` exit code 2. The script never exits 2; the branch is unreachable. Real environment failures previously misclassified as "non-trivia, proceed" should now propagate as a script error to the user.
- **I10** — Retry-path file-write safety: when iterating reviewer-supplied `file:` fields, canonicalize via `os.path.realpath` and assert the result is within `project_dir`. **Both sides MUST be `realpath`-normalised before the comparison**: compute `root = os.path.realpath(project_dir)` and `candidate = os.path.realpath(supplied_file)`, then assert `os.path.commonpath([root, candidate]) == root`. Without this, a symlink in `project_dir` can produce divergence even for in-tree files. Display the full canonicalized file list in the AskUserQuestion `description` (not just `<summary>`). Reject and warn on any path escaping `project_dir`.

### 5.2. `plugins/quality-gates/scripts/setup-qg.sh`

- **C3** — Restore the `DEVBREW_GATE3_MAX_RESOLUTIONS` validation block: parse integer, clamp `0..10`, write final value into state file `gate3_max_resolutions:` field. Stderr warning if env var is non-numeric or out of range, defaulting to 3.
- **I3** — Remove "Stop hook-based" wording from header comment (line 4) and `--help` text (lines 95-96). Replace with "AskUserQuestion-iteration-based" or simply "pipeline state setup".

### 5.3. `plugins/quality-gates/scripts/pre-pipeline-check.sh`

- **C2** — Before deleting `pipeline.md` (line 39), read its `session_id:` field; only proceed with deletion if it does NOT match `$CLAUDE_CODE_SESSION_ID`. Same-session pipeline files are owned by the live pipeline and must never be deleted by preflight.
- New stderr advisory when same-session file is preserved: `pre-pipeline-check: preserving session-owned state file`.

### 5.4. `plugins/quality-gates/hooks/session-start-advisor.py`

- **I4** — `_emit_legacy_v1_advisory`: replace bare `except OSError: pass` (lines 124-136) with `except OSError as e: print(f"[qg-advisor] legacy-v1 scan skipped: {e}", file=sys.stderr)`. Silent failure → diagnosable failure.
- **I5** — `_load_payload`: replace bare `except json.JSONDecodeError: pass` (lines 104-108) with `except json.JSONDecodeError as e: print(f"[qg-advisor] payload parse failed: {e}", file=sys.stderr)` and return empty dict. The empty-dict fallback stays (read-only advisor must not crash SessionStart), but the diagnostic is now visible.
- **Medium (LEGACY_V1_KEYS half-applied fix)** — line 43.
  - **Pre-condition** (verify before editing): the current source already has `"current" + "_gate:"` split-form applied (this was done in v1.32.0's Part C). The literal `current_gate:` should NOT appear in the file. Only `consecutive_no_signal:` remains as a literal.
  - **Edit**: split the remaining literal `consecutive_no_signal:` into `"consecutive_no" + "_signal:"`.
  - **Final form** (idempotent target — running the edit twice produces the same result): `LEGACY_V1_KEYS = ("status:", "current" + "_gate:", "consecutive_no" + "_signal:")`.
  - **If the pre-condition does NOT hold** (e.g. someone unrolled the `current_gate` split): re-apply both splits to reach the Final form, then file a separate issue noting the regression.
  - Add a regression test (see 5.6.5).

### 5.5. `plugins/quality-gates/README.md`

- **I8** — Remove the v1.5.0 Stop-hook ASCII diagram (lines 149-155). Verify the v1.32.0 AskUserQuestion diagram (line 157+) is the only one remaining. Update the surrounding prose if it still cross-references the removed block.

### 5.6. `plugins/quality-gates/tests/` — rewrites + deletes + new harness

#### 5.6.1. `tests/test_setup_qg.sh` — REWRITE (C4)

Remove 9 assertions that test deleted schema keys (`gate3_resolution_iter:`, `max_gate3_resolutions:`, `project_dir:`) and deleted stderr warnings. Add new assertions for:

- `--ensure` idempotency (call twice, second is no-op).
- `gate3_max_resolutions:` field is written with clamped value (C3 acceptance).
- Per-session folder layout (`.claude/quality-gates/<session-id>/pipeline.md`).
- Session-id binding (state file frontmatter contains current session ID).

#### 5.6.2. `tests/test_session_start_advisor.py` — DELETE (C5)

v1 Python test. v2 shell wrapper `test_session_start_advisor_v2.sh` covers replacement. Add a note in the deletion commit body explaining the v1→v2 transition.

#### 5.6.3. `tests/test_kill_switches.py` — surgical edit (I1)

Advisor sanity assertion (line 277-280) currently checks stdout; v1.32.0 advisor writes to stderr. Change `result.stdout` → `result.stderr`. Verify the assertion still semantically holds (advisor emits exactly one kill-switch advisory line).

#### 5.6.4. `tests/test_worktree.sh` — surgical edit (I2)

T5 (lines 175-198) and T9 (lines 224-229) assert removed `project_dir:` schema field. Remove those assertions; T5/T9 should now only verify worktree-mode session-folder layout.

#### 5.6.5. `tests/test_session_start_advisor_v2.sh` — add regression (Medium: LEGACY_V1_KEYS)

Add an assertion that all three legacy tokens (`status:`, `current_gate:`, `consecutive_no_signal:`) trigger the legacy-v1 advisory. Use file fixtures, not source-grep (the source uses string-concat to evade static grep).

#### 5.6.6. `tests/e2e-scenarios.md` — surgical edit (I9)

Lines 88, 141, 242, 290: replace `stop-hook.py` / `<qg-signal>` / `gate2_repeat_detected` references with v1.32.0 equivalents (AskUserQuestion / direct skill output / Gate 2 iter cap via SKILL).

#### 5.6.7. `tests/test_readme_state_diagram_complete.sh` — run + fix (I12)

Run first to confirm drift. If failing, update the diagram-completeness assertion to match the v1.32.0 README state diagram (post-I8 fix). If passing, no action.

#### 5.6.8. `tests/test_branch_worktree.sh` — comment-only edit (Medium drift)

Lines 116 and 122 reference "stop-hook simulation" in comments. Rewrite as "AskUserQuestion simulation" or remove the obsolete reference.

#### 5.6.9. `tests/harness/test_skill_orchestration_behavior.sh` — NEW (C6)

**Definition of "protocol-shape" (replaces the original "behavioral" overclaim).** This test does NOT execute SKILL.md at runtime. It asserts that the prompt-defined protocol exists in SKILL.md with the expected **ordering** and **structural relationships** between sections. This is stronger than pure presence-grep (V7 was "is token PASS present somewhere" — tautological) but weaker than runtime behavioral testing. The honest grain: "if a reader of SKILL.md cannot find the expected dispatch sequence in the expected order, the test fails."

The test:

- Loads `SKILL.md` content as text.
- For each gate, asserts the dispatch block appears in the right order relative to other gates: Gate 1 dispatch precedes Gate 2 fan-out which precedes Gate 3 verifier. Uses `awk '/marker/ {print NR}'` to compare line numbers, not just presence.
- Asserts Gate 2 iter cap is referenced in proximity to the AskUserQuestion decision section (within N lines of each other — N is implementation detail, default 50).
- Asserts `DEVBREW_GATE3_MAX_RESOLUTIONS` reference present AND appears within the Gate 3 dispatch section (not floating in prose).
- Asserts the four reviewer agents from AC1 are all dispatched in the Gate 2 fan-out section (consistency with C1 fix).
- Asserts the Retry path (I6) error-handling AskUserQuestion exists between the Gate 2 fan-out and Gate 3 dispatch sections.

Implementation: bash script + `grep -A`/`grep -B`/`awk` line-number patterns. **Why this is not the same tautology as V7**: V7 asserted token presence in isolation. This test asserts structural relationships (ordering, proximity, section membership) that cannot be satisfied by accidental token reuse elsewhere. If a future SKILL.md author moves the Gate 2 iter cap reference outside the AskUserQuestion section, the proximity check fails — V7-style grep would not catch that.

### 5.7. `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — additional finding (I11)

`gate2_iteration: 0` phantom field — pinned at 0 in frontmatter, real counter lives in History section. Remove from frontmatter template entirely; the History entries are the authoritative counter.

### 5.8. Medium / quality cluster (one commit each, or batched)

- **V2b grep uniqueness** (Medium): `tests/test_skill_orchestration.sh` V2b currently `grep -q 'findings remain'`; change to assert exactly one occurrence (`test "$(grep -c 'findings remain' SKILL.md)" -eq 1`). Anchors AC6 uniqueness.
- **`test_cancel_qg.sh` stage decoupling** (TQ-2):
  - **Helper script** (NEW): `plugins/quality-gates/scripts/cancel-qg-core.sh`. Contains the cleanup logic currently inlined in `commands/cancel-qg.md`'s bash block.
  - **Interface**: `cancel-qg-core.sh [--session-id <id>]`. No-arg form uses `$CLAUDE_CODE_SESSION_ID`. Exit 0 on success, non-zero with stderr message on failure. (No `--dry-run` flag — not required by any finding; YAGNI.)
  - **`commands/cancel-qg.md`**: bash block calls `bash "$CLAUDE_PLUGIN_ROOT/scripts/cancel-qg-core.sh"` instead of inline shell.
  - **`tests/test_cancel_qg.sh`**: sources/invokes the same helper, so command and test exercise identical code.
  - AC covering this fix: see §6 AC16-extension below.
- **`pre-pipeline-check.sh` direct tests** (Medium): Add `tests/test_pre_pipeline_check.sh` covering: fresh-start path, same-session preservation (new C2 behavior), cross-session deletion.
- **`setup-qg.sh --ensure` idempotency** (Medium): Already covered by 5.6.1 rewrite (assertion added there).
- **SKILL kill switch test** (Medium): Add `DEVBREW_DISABLE_QUALITY_GATES=1` assertion to `test_kill_switches.py`; verify SKILL preflight P1 exits with the documented message.
- **V8 fixture split** (Medium): `test_session_start_advisor_v2.sh` V8 currently combines per-session + flat. Split into V8a (per-session) and V8b (flat-legacy) so branches are independently verifiable.
- **`LEGACY_V1_KEYS` invariants doc** (Medium): Add a one-line `# Invariant: ...` comment above `LEGACY_V1_KEYS` in session-start-advisor.py explaining why string-concat is used (static-grep evasion for self-referential keys).

### 5.9. `plugins/quality-gates/.claude-plugin/plugin.json` + `CHANGELOG.md`

- **Final commit**: bump `version: "1.32.0"` → `"1.32.1"`.
- **CHANGELOG.md**: prepend `## [1.32.1] — 2026-05-27` section with Korean-primary body. Cite "Gate 2 review-driven fixes" + list resolved finding IDs grouped (Critical/Important/Medium).

## 6. Acceptance Criteria

Each AC maps to one or more finding IDs.

- **AC1 (C1)** — per-dispatch assertion (not a count). For each of the 4 reviewer agents (`adversarial`, `test-scope-validator`, `security-reviewer`, `runtime-verifier`), the SKILL.md dispatch block within 10 lines after the agent name MUST contain `project_dir:`. Concretely:
  ```bash
  for agent in adversarial test-scope-validator security-reviewer runtime-verifier; do
    grep -A10 "subagent_type[^\"]*\"$agent" plugins/quality-gates/skills/quality-pipeline/SKILL.md \
      | grep -q "project_dir:" || { echo "AC1 FAIL: $agent dispatch missing project_dir"; exit 1; }
  done
  ```
  Additionally, exactly one preflight derivation line MUST exist (`project_dir=$(pwd)` or equivalent). The §5.1 disambiguation prose does NOT count against the per-dispatch assertion (the regex targets `subagent_type` blocks).
- **AC2 (C2)** — automated, no manual test. `bash tests/test_pre_pipeline_check.sh` (new test file in §5.8) exits 0 and includes three named cases: `case_same_session_preserved`, `case_cross_session_deleted`, `case_advisory_emitted`. The third case asserts the `pre-pipeline-check: preserving session-owned state file` stderr message is captured when same-session preservation occurs (covers §5.3's new advisory message — closes the AC-gap finding).
- **AC3 (C3)**: `bash setup-qg.sh --ensure` with `DEVBREW_GATE3_MAX_RESOLUTIONS=99` produces stderr warning + state file contains `gate3_max_resolutions: 10` (clamped). With `DEVBREW_GATE3_MAX_RESOLUTIONS=abc`: warning + default 3.
- **AC4 (C4)**: `bash tests/test_setup_qg.sh` exits 0; 0 failed assertions.
- **AC5 (C5)**: `test -f plugins/quality-gates/tests/test_session_start_advisor.py` returns false (file deleted).
- **AC6 (C6)**: `bash tests/harness/test_skill_orchestration_behavior.sh` exits 0; covers Gate 1 handoff, Gate 2 iter cap, Gate 3 dispatch. V7 deletion verified by an **anchored structural grep** (not a substring scan): `grep -cE '^[[:space:]]*(function[[:space:]]+)?(test_)?V7[[:space:]({]' plugins/quality-gates/tests/test_skill_orchestration.sh` returns 0. This pattern matches only V7 function/test-case **definitions** (line-start, optional `function`/`test_` prefix, terminator `[ { (` or whitespace), not substring occurrences in comments (e.g. `# removed V7`) or unrelated identifiers (e.g. `V7a`, `V70`). V7 must be deleted atomically with the new test's addition — see §5.1 C6 atomicity note.
- **AC7 (I1)**: `python3 tests/test_kill_switches.py` (or `pytest tests/test_kill_switches.py`) exits 0; advisor stderr-not-stdout assertion present. (Pre-fix wording `bash tests/test_kill_switches.py` was a typo — the file is `.py`.)
- **AC8 (I2)**: `bash tests/test_worktree.sh` exits 0; no `project_dir:` assertion remains.
- **AC9 (I4)**: `grep -nE "print.*qg-advisor.*legacy-v1" plugins/quality-gates/hooks/session-start-advisor.py` returns ≥1 match.
- **AC10 (I5)**: same for `payload parse failed`.
- **AC11a (I6 — Retry error handling)**: `grep -A5 'Retry' plugins/quality-gates/skills/quality-pipeline/SKILL.md | grep -iqE 'AskUserQuestion.*(Retry failed|skip retry|abort)'` succeeds. The `-i` flag is mandatory: §5.1 I6 prescribes the AskUserQuestion text as `Skip retry / abort?` with capital S, but earlier draft text used lowercase. Case-insensitive matching accepts both. The AskUserQuestion error-handling block exists within 5 lines of the Retry section header.
- **AC11b (I7 — no exit-2 branch on check-trivia)**: `grep -cE 'check-trivia.*exit.*2|exit.*code.*2.*check-trivia|trivia.*== *2' plugins/quality-gates/skills/quality-pipeline/SKILL.md` returns 0. No exit-2 conditional branches remain in SKILL.md prose.
- **AC11c (I10 — realpath + commonpath canonicalization)**: `grep -q 'realpath' plugins/quality-gates/skills/quality-pipeline/SKILL.md && grep -q 'commonpath' plugins/quality-gates/skills/quality-pipeline/SKILL.md && grep -A3 'realpath' plugins/quality-gates/skills/quality-pipeline/SKILL.md | grep -q 'project_dir'` all succeed. Both canonicalization functions referenced, and `realpath` appears within 3 lines of `project_dir` context.
- **AC12 (I8)**: `grep -cE 'Stop hook' plugins/quality-gates/README.md` returns 0 (no remaining Stop-hook diagram or prose).
- **AC13 (I9)**: `grep -cE 'stop-hook\.py|<qg-signal|gate2_repeat_detected' plugins/quality-gates/tests/e2e-scenarios.md` returns 0.
- **AC14 (I11)**: `grep -nE '^gate2_iteration:' plugins/quality-gates/skills/quality-pipeline/SKILL.md` returns 0 matches in the frontmatter template.
- **AC15 (I12)**: `bash tests/test_readme_state_diagram_complete.sh` exits 0.
- **AC16 (Medium cluster)**: `bash tests/test_skill_orchestration.sh` (V2b uniqueness), `bash tests/test_pre_pipeline_check.sh` (new), `bash tests/test_session_start_advisor_v2.sh` (V8a/V8b split + LEGACY_V1_KEYS regression) all exit 0.
- **AC17 (LEGACY_V1_KEYS literal evasion)**: `grep -E 'consecutive_no_signal:|current_gate:' plugins/quality-gates/hooks/session-start-advisor.py` returns 0 matches against the literal strings. **Idempotent**: AC passes whether `current_gate:` was already split (current state) or both keys were re-split together. Additionally, the file MUST contain both concat patterns: `grep -F '"current" + "_gate:"' file && grep -F '"consecutive_no" + "_signal:"' file` both succeed (closes the "skipped because already-split" loophole — the spec asserts both splits are present, not just absence of literals).
- **AC18 (TQ-2 cancel-qg helper)**: `test -x plugins/quality-gates/scripts/cancel-qg-core.sh` returns true. `grep -q cancel-qg-core.sh plugins/quality-gates/commands/cancel-qg.md && grep -q cancel-qg-core.sh plugins/quality-gates/tests/test_cancel_qg.sh` both succeed (command and test both reference the helper). `bash tests/test_cancel_qg.sh` exits 0.
- **AC19 (version + CHANGELOG)**: `jq -r .version plugins/quality-gates/.claude-plugin/plugin.json` returns `"1.32.1"`. `head -20 plugins/quality-gates/CHANGELOG.md` contains `## [1.32.1] — 2026-05-27`.

## 7. Verification Plan

1. **Per-fix verification**: after each Edit, run the corresponding AC's grep/test. No fix is "done" until its AC passes.
2. **Test suite sweep**: after all fixes, run every `tests/test_*.sh` and `tests/test_*.py` in the plugin. All must exit 0.
3. **Manual SKILL walkthrough** (Subjective): read SKILL.md end-to-end and verify the orchestration narrative flows without dangling references to removed Stop-hook concepts.
4. **PR comment generation**: produce a single PR comment summary mapping each finding ID → resolving commit SHA + AC verdict.

## 8. Rejected Alternatives

- **Subagent-Driven execution**: per-finding subagent + 2-stage review overhead is excessive. Each fix IS the response to a review (the Gate 2 findings doc). Inline execution chosen.
- **Per-finding commits (~27 commits)**: PR history bloat. Per-file-group commits (~10 commits) chosen.
- **C2 fix via reordering P2/P3**: rejected. Preflight (P3) conceptually runs before setup (P2), but in v1.32.0 setup creates the file preflight examines. Inverting requires substantial SKILL refactor; the session-id guard is the minimal, correct fix.
- **C2 fix via re-invoking setup-qg after `cleared_branch_mismatch`**: rejected. Introduces a double-write race (setup re-runs while old state partially exists) and a stale-data window between the preflight deletion and the re-setup call. Strictly more complex than the session-id guard, with no benefit — the session-id guard prevents the deletion from happening in the first place, eliminating the need for re-creation.
- **C3 fix via moving clamp to SKILL preflight bash**: rejected. setup-qg.sh is the single source of state-creation truth. Moving clamp to SKILL would duplicate validation logic.
- **C6 fix via live LLM execution test**: rejected — flaky, expensive, and the question is "does SKILL.md prescribe the right protocol?" not "does the protocol execute correctly?". Static fixture-driven assertions are the right grain.
- **Defer Medium tier to v1.33.0**: rejected by user (scope answer = "all in branch").
- **Bump to v1.33.0**: rejected. These are bug fixes against v1.32.0's intended surface. Patch bump is correct SemVer.
- **No version bump (treat as in-progress v1.32.0)**: rejected per `feedback_plugin_version_bump.md`. The previous PR commits already labeled the work v1.32.0; bumping to 1.32.1 cleanly marks "v1.32.0 had review-caught issues fixed pre-merge".

## 9. Metadata

| Field | Value |
|---|---|
| Spec ID | qg-gate2-findings-fix-v1.32.1 |
| Created | 2026-05-27 |
| Author | Claude Opus 4.7 + jeonghok |
| Spec status | Approved (user "approve, write the spec") |
| Plugin affected | `plugins/quality-gates` |
| Version transition | 1.32.0 → 1.32.1 |
| PR | #71 (jeonghok/devbrew) |
| Branch | `worktree-feature-qg-askq-iteration` (local) / `feature/qg-askq-iteration` (remote) |
| Source findings doc | `docs/superpowers/plans/notes/2026-05-27-gate2-findings.md` |
| Predecessor spec | `2026-05-27-qg-askq-iteration-design.md` |
| Trivia-escape eligible? | No (substantial multi-file change, security-sensitive I10) |
| Three Laws | Law 1 (this spec satisfies structural gate), Law 2 (C1 reinforces reviewer contract), Law 3 (CHANGELOG entry + finding-ID traceability in commits) |
