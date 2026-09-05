# Quality-Gates v1.5.0 — E2E Verification Scenarios

> **Historical (v2.2.x snapshot).** Model lines below predate the 2026-09-06 «no `model` key» convention; scenario H's "Task 1 model-override experiment" measured dispatch-time override of `inherit`, which gate agents no longer receive.

This document records the manual verification scenarios for the v1.5.0 redesign.
Live `/qg` runs require an interactive Claude Code session against a real PR;
this file specifies *what to test* and *what passing looks like* so a reviewer
or a future re-verification can reproduce the results.

A static-checks summary is at the bottom.

## Setup (once)

1. Confirm branch is `feature/qg-cost-reduction` merged or rebased on `main`.
2. Confirm `pr-review-toolkit`, `feature-dev`, and `superpowers` plugins are
   installed (`/plugin list`).
3. Confirm tests pass:
   ```bash
   python3 -m unittest discover plugins/quality-gates/tests -v
   ```
   Expected: 23 tests pass.

## Scenarios

### A — Trivia (whitespace)
**Setup**: pick any single source file; add one trailing-whitespace edit.
**Run**: `/qg`
**Expected**: instant PASS, 0 dispatches. State file shows `outcome: trivia-skipped`, `trivia_kind: whitespace`. Pipeline message says "Trivia change (whitespace); review skipped."

### A2 — Trivia (rename)
**Setup**: `git mv old.py new.py` with no other edits.
**Run**: `/qg`
**Expected**: instant PASS, 0 dispatches. `trivia_kind: rename`.

### A3 — NOT trivia (comment-only safety check)
**Setup**: edit one comment line (single file, ≤3 lines, but not whitespace/rename).
**Run**: `/qg`
**Expected**: trivia escape does NOT fire. Pipeline proceeds to Gate 1, then Quick depth in Gate 2. Confirms our intentional decision to leave comment-only outside the trivia path (language fragility).

### B — Quick (small single-file diff)
**Setup**: single Python file, ~30 LOC change, no new files.
**Run**: `/qg`
**Expected** dispatches in order:
- scout (Sonnet) → emits `depth: quick`, `phase1_agents: [code-reviewer]`, `phase2_agents: []`
- pr-review-toolkit:code-reviewer (upstream Opus) — Phase 1
- synthesizer (Sonnet) — Phase 1.6
Total: 3 dispatches. AskUserQuestion does NOT fire (Phase 1+2 = 1 < 4).

### C — Standard (multi-file, mid-size)
**Setup**: ~100 LOC across two files.
**Run**: `/qg`
**Expected** dispatches:
- scout → `depth: standard`, `phase1_agents: [code-reviewer, silent-failure-hunter]`, `phase2_agents` of 0–2 specialists
- code-reviewer (Opus, upstream) + silent-failure-hunter (Sonnet override) — Phase 1
- 0–2 Phase 2 agents per scout's plan (Sonnet)
- adversarial (Opus) — Phase 1.5
- synthesizer (Sonnet) — Phase 1.6
Total: 5–7 dispatches. AskUserQuestion fires only if Phase 1+2 ≥ 4.

### D — Deep (large diff, AskUserQuestion gate)
**Setup**: ≥200 LOC AND new file added AND a config file (`*.json` / `*.toml`) touched.
**Run**: `/qg`
**Expected**:
- scout → `depth: deep`, `phase1_agents: [code-reviewer, silent-failure-hunter, feature-dev:code-reviewer]`, `phase2_agents` likely 2 (e.g., `type-design-analyzer` + `feature-dev:code-architect`).
- Phase 1+2 = 5 ≥ 4 → **AskUserQuestion fires** with the three options.
- Choose `phase1-only` → Phase 2 skipped; only Phase 1 (3) + adversarial + synth = 5 dispatches.

### E — No cross-gate restart
**Setup**: PR with code that intentionally has a Gate 2 issue requiring file changes (e.g., bug that the reviewer will spot).
**Run**: `/qg`
**Expected**: Gate 2 emits `NEEDS_RESTART` after fix-loop exhaustion → user-choice prompt fires (`gate2_user_choice`). Pipeline does NOT auto-restart from Gate 1. User picks "Apply changes and re-run `/qg`" → pipeline ends with abort signal.

### F — Within-Gate-2 fix loop
**Setup**: PR where Phase 1 finds CRITICAL issues that the skill can fix in-place.
**Run**: `/qg`
**Expected**: fix → re-run scout (delta diff: only changed files) → narrower dispatch → either PASS or another fix iteration. After ≤5 iterations, either PASS or `gate2_max_exceeded` user-choice fires.

### G — `/qg --paths` override
**Setup**: edit files outside `plugins/quality-gates/`.
**Run**: `/qg --paths "plugins/quality-gates/**"`
**Expected**: scout sees only the matched paths (the others are excluded from diff). Session-files content is ignored.

### H — Cross-plugin model respect
**Run**: any /qg invocation that dispatches `pr-review-toolkit:code-reviewer`.
**Inspect**: state file dispatch summary should show `model: opus` for that agent (upstream-hardcoded, not overridden), while devbrew agents (no `model` key) show `model: sonnet` (Task 1 model-override experiment confirmed this works).

### I — Repeat detection
**Setup**: contrive a PR where Phase 1 finds the same finding twice (e.g., the auto-fix doesn't actually fix the root cause).
**Run**: `/qg`
**Expected**: after iteration 2 with identical scout dispatch hash + synthesizer hash, the SKILL surfaces the Gate 2 iter-boundary decision via AskUserQuestion (Retry / Proceed to Gate 3 / Stop) with a repeat-detected note in the prompt, before reaching the hard cap `max_gate2_iterations=5`.

### J — Branch switch mid-session
**Run**: edit a file on `feature/qg-cost-reduction`, then `git checkout main`, then `/qg`.
**Expected**: scope is git-derived fresh at invocation time (branch diff against base, unioned with the worktree's own changed files), not cached from a prior turn or session file — `/qg` on `main` reviews `main`'s own diff against its base, not the leftover `feature/qg-cost-reduction` diff. No explicit reset step is needed; there is no session-scope file to go stale.

### K — `/qg --reset` kill switch
**Setup**: any active or stale state files in `.claude/`.
**Run**: `/qg --reset`
**Expected**: `quality-gates.local.md`, `quality-gates-session.local.md`, `quality-gates-branch.local.md`, plus `qg-diff-cache.txt` and `qg-code-paths.tmp` all removed. Message "Quality-gates state cleared."

### L — `DEVBREW_QUALITY_GATES_DISABLE=1`
**Run**: set env var, then start a new Claude Code session AND attempt `/qg`.
**Expected**: SessionStart advisor is silent. `/qg` should also detect the env var (this happens via the setup script and skill check; not yet covered by a test, but the existing kill-switch tests for individual hooks confirm the propagation).

## Static Wiring Checks (automated)

Run this from repo root any time:

```bash
python3 -c "
import yaml, json, os
print('Agents (model + cost_class):')
for a in ['scout','adversarial','synthesizer','plan-verifier','runtime-verifier']:
    fm = open(f'plugins/quality-gates/agents/{a}.md').read().split('---')[1]
    d = yaml.safe_load(fm)
    print(f'  {a}: model={d.get(\"model\")}, cost_class={d.get(\"cost_class\")}')
print()
print('SKILL cost_class:', yaml.safe_load(open('plugins/quality-gates/skills/quality-pipeline/SKILL.md').read().split('---')[1])['cost_class'])
print('plugin.json version:', json.load(open('plugins/quality-gates/.claude-plugin/plugin.json'))['version'])
print('Hooks registered:')
for ev, lst in json.load(open('plugins/quality-gates/hooks/hooks.json'))['hooks'].items():
    for entry in lst:
        for hook in entry['hooks']:
            print(f'  {ev}: {hook[\"command\"].split(chr(47))[-1]}')
"

python3 -m unittest discover plugins/quality-gates/tests -v 2>&1 | tail -3
```

Expected output (final state):

```
Agents (model + cost_class):
  scout: model=sonnet, cost_class=low
  adversarial: model=opus, cost_class=low
  synthesizer: model=sonnet, cost_class=low
  runtime-verifier: model=(none — user setting/session), cost_class=variable

SKILL cost_class: variable
plugin.json version: 2.2.x
Hooks registered:
  SessionStart: session-start-advisor.py
  (v1.32.0 removes the Stop hook — pipeline progression is now in-turn
  AskUserQuestion-driven, not turn-by-turn signal-driven.)

Ran 23 tests in 0.NNNs
OK
```

## v1.6.0 Scenarios (per-session state)

### V1 — Concurrent sessions do not share pipeline state

**Setup**: Two terminal sessions A and B in the same project (same worktree). Both have valid `CLAUDE_CODE_SESSION_ID` env vars (`$SID_A`, `$SID_B`).
1. In A: run `/qg`. Verify `.claude/quality-gates/$SID_A/pipeline.md` is created.
2. In B: run `/qg`. Verify `.claude/quality-gates/$SID_B/pipeline.md` is created, independent of A's.
3. Review scope itself is git-derived (branch diff against base, unioned with the worktree's own changed files) — since A and B share the same worktree, both sessions resolve the SAME scope from git; there is no per-session file tracker to isolate.

**Pass**: `$SID_A` and `$SID_B` each have their own `pipeline.md` with independent History/iteration state; neither session's pipeline-state file is touched by the other's run.

### V2 — Dormant session GC

**Setup**: Backdate a sibling session's files mtime by 25 hours.
```bash
old=$(($(date +%s) - 25 * 3600))
touch -t "$(date -r $old +%Y%m%d%H%M)" .claude/quality-gates/oldsess0001/pipeline.md
touch -t "$(date -r $old +%Y%m%d%H%M)" .claude/quality-gates/oldsess0001
```
1. Run `/qg` (any flavor). Verify `.claude/quality-gates/oldsess0001/` no longer exists.
2. Set `DEVBREW_QUALITY_GATES_GC_VERBOSE=1` and observe stdout: `[quality-gates] GC: removed 1 stale session folder(s)`.

### V3 — Graceful SessionEnd cleanup

1. Start `/qg` in a session.
2. Close Claude Code gracefully (not `kill -9`).
3. Verify `.claude/quality-gates/$SID/` is gone.

**Pass**: own folder removed; sibling folders untouched.

### V4 — Legacy migration on upgrade

**Setup**: Pre-existing v1.5.0 flat files (5 files) in `.claude/`.
```bash
touch .claude/quality-gates.local.md \
      .claude/quality-gates-session.local.md \
      .claude/quality-gates-branch.local.md \
      .claude/qg-diff-cache.txt \
      .claude/qg-code-paths.tmp
```
1. Open Claude Code. Observe `session-start-advisor` stdout: `[quality-gates] Legacy v1.5.0 state files detected.`
2. Run `/qg`. Observe `setup-qg.sh` stderr: `Removed 5 legacy flat state file(s) from v1.5.0.`
3. Verify the 5 files are gone, new `.claude/quality-gates/$SID/pipeline.md` exists.

### V5 — GC lock contention silent

1. Hold the lock from a shell:
```bash
exec 9>".claude/quality-gates/.gc.lock"
flock -n 9 || echo "fail"
# (keep shell open with lock held)
```
2. In another terminal, run `/qg --gc`. Should silently exit (GC skipped, no error).
3. Stale folders preserved.

### V6 — Kill switch globally disables

```bash
DEVBREW_QUALITY_GATES_DISABLE=1 /qg
```
1. Verify no `.claude/quality-gates/` folder created.
2. Verify SessionEnd hook noop.
3. Verify `qg-gc.py` exits 0 without action.

## Out-of-Scope for This Verification

- Live cost telemetry (recording actual $ per run for each depth tier) —
  needs a real billing endpoint; deferred to first-week-after-merge metrics.
- A/B comparison vs v1.4.0 baseline — needs the same PR run on both versions;
  recommended for the first 5 PRs after merge.
- Automated E2E test harness — would require a Claude Code subprocess invocation
  pattern that the current toolchain does not standardize. Manual verification
  via the scenarios above is the contract.

## Gate 3 Active Verification Scenarios (v1.8.0)

### Scenario G3-A: Web app, docker-compose, .env all present

**Setup:** project root has `docker-compose.yml`, `package.json` with `dev`
script, `.env`, and a plan referencing `/auth`. chrome-devtools MCP is
configured.

**Run:** `/qg --gate3`

**Expected:**
- Detector emits manifest with: docker-compose, npm:dev, npm:test,
  pytest (if applicable), `mcp_browser: chrome-devtools`,
  `plan_features: [/auth]`, `env_status: [{file: .env, exists: true}]`.
- Skill asks: "Bring up docker compose? (yes/skip-this-surface)" → user yes.
- Skill: `docker compose up -d` succeeds.
- Agent dispatched with manifest. Attempts each surface, captures screenshots
  + a11y snapshots, writes evidence-log.
- Verdict: PASS.
- SKILL prints `## Gate 3: Runtime Verification — clean` → pipeline complete.

### Scenario G3-B: Web app, .env missing but .env.example present

**Setup:** same as G3-A but `.env` does not exist; `.env.example` does.

**Run:** `/qg --gate3`

**Expected:**
- Detector flags `env_status: [{file: .env, exists: false, has_example: true}]`.
- Skill asks: "Copy .env.example → .env? (yes/manual-set/skip)" → user yes.
- Skill: `cp .env.example .env`.
- Agent proceeds; verdict depends on whether the example values are valid for
  startup. If app boots: PASS. If app fails on bad credentials: NEEDS_RESOLUTION
  with `needed: [{kind: missing-env-var, description: "DB_URL invalid; set
  real value in .env and retry"}]`.
- On NEEDS_RESOLUTION: skill asks retry/skip/abort. User edits .env, picks
  retry → agent re-dispatched (iter=1) → PASS.

### Scenario G3-C: Docker daemon down (mid-run escalation)

**Setup:** `docker-compose.yml` exists, but Docker is not running.

**Run:** `/qg --gate3`

**Expected:**
- Skill: `docker compose up -d` fails ("Cannot connect to Docker daemon").
- Skill jumps to Step 5 (NEEDS_RESOLUTION handling) WITHOUT agent dispatch.
- Skill asks: "Docker daemon down. Start it and retry? (retry/skip-surface/abort)"
- If retry: skill re-attempts `docker compose up -d`. If now succeeds → continue
  to Step 3 agent dispatch.
- If skip-surface: agent dispatched with manifest, but compose surface marked
  `pre-skipped` in applied_decisions. Agent attempts npm:dev only.
- After 3 retries with same `needed_hash`: `gate3_repeat_detected` →
  proceed/abort.

### Scenario G3-D: Markdown-only repo (fast-path SKIP)

**Setup:** repo has only `.md` files. No package.json, no docker-compose,
no test infra.

**Run:** `/qg --gate3`

**Expected:**
- Detector emits manifest with empty runnable_surfaces / test_runners /
  plan_features.
- Skill: fast-path SKIP_WITH_EVIDENCE. **Sub-agent NOT dispatched.**
- Evidence log written: "no runnable surfaces detected".
- SKILL prints `## Gate 3 — SKIP_WITH_EVIDENCE` with the evidence-log path.
- Token cost for Gate 3: detector + minimal skill overhead. No agent tokens.

### Verification

To run these scenarios manually:
1. `cd plugins/quality-gates/tests/fixtures/gate3/<scenario-dir>`
2. `CLAUDE_CODE_SESSION_ID=test_$(date +%s) /qg --gate3`
3. Observe expected behavior; check evidence-log under `.claude/quality-gates/<sid>/`.

The fixtures cover G3-A (web-compose), G3-B (web-example-only), and G3-D
(markdown-only) directly. G3-C requires Docker on the host machine and is
a manual test only.
