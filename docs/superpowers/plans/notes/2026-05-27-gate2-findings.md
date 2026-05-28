# Gate 2 Findings — PR #71 (quality-gates v1.32.0)

> Generated 2026-05-27 by `/qg` quality-pipeline SKILL (v1.31.0 cached) running against feature/qg-askq-iteration branch. Reviewer fan-out: 7/8 LLM agents (codex script: prompt_build_failed, loud-skipped). Iteration 1 verdict: FAIL. Wall-clock exceeded (default 30 min); user chose Accept-Partial. Gate 3 not run.

## Critical (≥ 90 confidence) — 6 findings

- **C1 — `project_dir` contract break** (code-reviewer)  
  `plugins/quality-gates/skills/quality-pipeline/SKILL.md` no longer threads `project_dir` to subagent dispatches. Agents `adversarial.md`, `test-scope-validator.md`, `security-reviewer.md`, `runtime-verifier.md` still declare it required and forbid re-resolving via `pwd`/`git rev-parse`. Under `/qg branch <name>` worktree mode, agents will hit their "do not re-resolve" guard or silently fall back to wrong cwd — the exact coordinate-drift bug the agents were hardened against.  
  **Fix**: add an explicit Preflight step that derives `project_dir` (pwd or worktree_path from state) and threads `project_dir: "<value>"` into every reviewer prompt template.

- **C2 — P2 → P3 state-file race** (silent-failure-hunter)  
  SKILL preflight P2 (`setup-qg.sh --ensure`) creates `pipeline.md`, then P3 (`pre-pipeline-check.sh`) deletes it on branch mismatch via `rm -f "$SESSION_FILE" "$STATE_FILE"` at `pre-pipeline-check.sh:39`. No re-creation. Final Summary History silently empty for cross-branch QG runs.  
  **Fix**: reorder P2/P3, OR have pre-pipeline-check refuse to delete a state file owned by the current session, OR re-invoke setup-qg after a cleared_branch_mismatch.

- **C3 — `DEVBREW_GATE3_MAX_RESOLUTIONS` clamp removed; SKILL prose still claims it** (silent-failure-hunter)  
  setup-qg.sh validation block (old lines 190-198) deleted in Task 3. SKILL.md still says "default 3, env override, clamp 0..10" at lines 131, 333, 347. No code reads/clamps. Re-introduces P18 unbounded-autonomy regression.  
  **Fix**: restore validation in setup-qg.sh (or move to SKILL preflight bash); write parsed value to state and have SKILL read from there.

- **C4 — `test_setup_qg.sh` stale: 9/25 assertions fail** (pr-test-analyzer)  
  Asserts removed schema keys (`gate3_resolution_iter:`, `max_gate3_resolutions:`, `project_dir:`) and removed stderr warnings (`exceeds maximum 10`, `is not numeric`). Task 7 missed this file.  
  **Fix**: rewrite for v1.32.0 minimal schema, OR delete with CHANGELOG justification.

- **C5 — `test_session_start_advisor.py` (v1 file) still in tree** (pr-test-analyzer, code-reviewer)  
  v1 Python test never removed in Task 7 cleanup. 5/12 assertions fail vs v1.32.0 advisor (asserts removed stdout one-liner: `/qg`, `--reset`, `sibling`).  
  **Fix**: delete file (v2 shell wrapper `test_session_start_advisor_v2.sh` covers replacement).

- **C6 — SKILL.md orchestration has zero behavioral tests** (pr-test-analyzer, code-architect)  
  Static grep wrapper (`test_skill_orchestration.sh`) covers V2a/V2b/V7 only. V7 tautological: token `PASS` never appears in SKILL.md (`grep -c '\bPASS\b'` = 0), so V7's failure path is unreachable. The 4 AskUserQuestion decision branches + Gate 2 iter cap + Retry path + `DEVBREW_GATE3_MAX_RESOLUTIONS` enforcement: all untested.  
  **Fix**: protocol test in `tests/harness/` dispatching mocked subagents with canned verdicts; assert tool-call sequence + iter cap honored.

## Important (≥ 80 confidence) — 12 findings

- **I1 — test_kill_switches.py advisor sanity** asserts stdout but v1.32.0 advisor writes to stderr (line 277-280).  
- **I2 — test_worktree.sh T5+T9** assert removed `project_dir` schema (lines 175-198, 224-229).  
- **I3 — setup-qg.sh header comment + help** still say "Stop hook-based" (line 4, 95-96).  
- **I4 — `_emit_legacy_v1_advisory` OSError swallow** (session-start-advisor.py:124-136): on EACCES/EIO/TOCTOU race, silently no-op — exact silent failure the function is named to prevent.  
- **I5 — `_load_payload` JSONDecodeError swallow** (session-start-advisor.py:104-108): malformed stdin → empty dict → wrong cwd advisory with no diagnostic.  
- **I6 — SKILL.md Retry path lacks error handling** (SKILL.md:297-303): no spec for Edit failures (old_string-not-unique, EACCES, ENOSPC, partial fix application).  
- **I7 — check-trivia.sh never exits 2** but SKILL.md branches on exit 2 (unreachable). Real environment failures mis-classified as "non-trivia, proceed".  
- **I8 — README v1.5.0 Stop hook diagram NOT removed** (README.md:149-155). Old + new diagrams coexist. CHANGELOG claims "diagram replaced" but actually added.  
- **I9 — tests/e2e-scenarios.md v1.5.0 references** lines 88, 141, 242, 290 (`stop-hook.py`, `<qg-signal>`, `gate2_repeat_detected`). V1 grep refinement (code-only) missed this `.md` file.  
- **I10 — Gate 2 Retry arbitrary file write surface** (security-reviewer): reviewer-supplied `file:` could be `~/.ssh/authorized_keys`; AskUserQuestion only shows `<summary>`. Need canonicalization + file-list display.  
- **I11 — `gate2_iteration: 0` phantom field** (type-design-analyzer): pinned at 0 forever in frontmatter, real counter lives in History. Remove from frontmatter or remove the pinning.  
- **I12 — test_readme_state_diagram_complete.sh likely drifted** vs v1.32.0 README (code-architect — needs run to confirm).

## Medium / quality issues — 9 more

- `consecutive_no_signal:` literal in `LEGACY_V1_KEYS` (advisor.py:43): only `current_gate` was split-concatenated; `consecutive_no_signal` left as literal. Half-applied fix.
- V2b grep tests presence, not uniqueness (`findings remain` could be duplicated to other AskUserQuestion sections, violating AC6 anchor uniqueness).
- `test_cancel_qg.sh` stages decoupled: inline shell, not command's actual bash block (TQ-2).
- `pre-pipeline-check.sh` zero direct tests.
- `setup-qg.sh --ensure` idempotency untested.
- SKILL kill switch (`DEVBREW_DISABLE_QUALITY_GATES=1` at P1) untested.
- V8 in `test_session_start_advisor_v2.sh` combines per-session + flat fixture — can't distinguish branches.
- `test_branch_worktree.sh` comments lines 116/122 reference "stop-hook simulation" (drift).
- Type-design: `LEGACY_V1_KEYS` invariants undocumented/unenforced (no regression test that literal `current_gate:` doesn't reappear in source).

## Architectural concerns — 3 (not findings, observations)

- **AskUserQuestion overload** (consent-gate + progression-gate): different failure modes (Stop on consent = save cost; Stop on progression = abort pipeline). Disambiguation via `header` field only. README's "P22 generalization" makes this explicit.
- **Orchestrator-as-writer**: physical Law 2 maintained (reviewers have `disallowedTools`), but Writer+Reviewer share single-turn context — semantic boundary weakened vs old Stop-hook turn-boundary.
- **Test pyramid regression**: behavioral Python tests deleted (3 files); replaced by static grep wrappers. Net loss of runtime verification coverage on critical orchestration logic.

## Suggested fix sequence

1. **Top priority** (block PR merge): C1 (project_dir), C4 + C5 (test cleanup that should have been in Task 7), C3 (clamp restore).
2. **Important** (apply before claiming "v1.32.0 ready"): I1 + I2 + I8 + I9 (test/doc drift), I10 (security retry path), C2 (P2→P3 race), C6 (at least one behavioral SKILL test).
3. **Quality / follow-up** (separate PR or v1.33.0): I3, I4, I5, I6, I7, I11, all medium issues.

## Reviewer skip notes

- `pr-review-toolkit:codex-reviewer` SKIPPED: `run_codex_reviewer.sh` failed with `CLAUDE_PLUGIN_ROOT: unbound variable`. After setting env var, retried: failed with `{"codex_failed": true, "reason": "prompt_build_failed"}`. v1.31.0 cached infrastructure issue — model-family diversity coverage degraded for this review.
- `superpowers:code-reviewer`: not in scout's `phase2_agents` for primary path (would have been gated by Path B rules in fallback only).

## Pipeline state at termination

- Wall-clock exceeded at 30 min boundary. User chose Accept-Partial.
- Gate 1: PASS (79/79).
- Gate 2: FAIL (iter 1, no fix applied).
- Gate 3: NOT RUN (wall-clock exceeded before reaching).
- State file: `.claude/quality-gates/d915fa62-6f59-447b-aa2a-f0b6d7bcf5d7/pipeline.md` — Stop hook will mark `outcome: wall-clock-partial` on receipt of `action="complete"` signal.

## Recommendation for PR #71

Convert each Critical + Important finding into a PR review comment (or batch as one consolidated review). Iterate the branch with C1/C3/C4/C5/I8/I9 + I10 absorbed before requesting merge. Defer Medium / Architectural items to v1.33.0 follow-up.
