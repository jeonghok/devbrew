---
name: quality-pipeline
description: >
  This skill runs the full quality-gates pipeline in a single assistant
  turn. Triggered by `/qg`, "run quality gates", "verify my implementation",
  "check code quality", or "is my PR ready to merge". Dispatches the
  three gates (plan verification, PR review, runtime verification)
  serially in a single turn. Progression decisions and fix-loop
  iteration boundaries surface to the user via AskUserQuestion tool calls.
  Happy path (all gates pass) requires zero user clicks.
cost_class: variable
allowed-tools:
  # Group 1 — Preflight scripts (실행 순서: setup → pre-check → trivia)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/pre-pipeline-check.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-trivia.sh:*)
  # Group 2 — Gate 2 PR review scripts
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/scout.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/run_codex_reviewer.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/synthesize_findings.py:*)
  # Group 3 — Gate 3 runtime verification scripts
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/detect-runtime.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/detect_codex.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/compute-test-scope-candidates.sh:*)
  # Group 4 — Meta (orchestration primitives)
  - Agent
  - AskUserQuestion
  # Group 5 — File operations
  - Read
  - Glob
  - Grep
  - Edit
  - Write
---

# Quality Gates — In-Turn Orchestrator (v1.32.0)

You are running the **full quality-gates pipeline** in a single assistant
turn. You dispatch the three gates serially in order. At decision points
(plan-verification failure, review-iter boundary, runtime needs-resolve) you call
`AskUserQuestion` and branch on the user's response — the response arrives
as a tool result in the same turn, so no Stop hook and no continuation
sentinel are needed.

**Law 2 (Writer ≠ Reviewer):** you are the orchestrator (writer). All
verdict-producing agents are dispatched as separate subagents with
`disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` so they cannot
mutate the working tree. You ARE allowed to apply user-approved fixes
("Retry" path on the review gate) using Edit/Write — those changes are
user-consented, not self-approval.

**State file:** read `worktree_path` from `.claude/quality-gates/<sid>/pipeline.md`
only during preflight; never write. Setup script handles creation, /cancel-qg
handles deletion.

## Contents

이 SKILL은 단일 어시스턴트 턴 안에서 전체 파이프라인을 실행. 섹션 그룹:

1. **Workflow (top-to-bottom on invocation):**
   - [Preflight](#preflight) — kill switch / setup-qg / pre-pipeline-check
   - [Arguments](#arguments) — `/qg` flags 파싱
   - [Dispatch Loop](#dispatch-loop) — three gates serialized in order with per-gate iteration
2. **Per-gate dispatch logic:**
   - [Trivia escape](#trivia-escape) — one-sentence diff → all gates skipped
   - [Gate 1: Plan Verification](#gate-1-plan-verification) — dispatch `plan-verifier`
   - [Gate 2: PR Review](#gate-2-pr-review) — scout + Phase 1 + adversarial + synthesizer; iter loop with decision tool at every boundary
   - [Gate 3: Runtime Verification](#gate-3-runtime-verification) — test-scope-validator + runtime-verifier
3. **Decision points (AskUserQuestion templates):**
   - [Gate 1 FAIL decision](#gate-1-fail-decision)
   - [Gate 2 iter boundary decision](#gate-2-iter-boundary-decision)
   - [Gate 2 max-iter decision](#gate-2-max-iter-decision)
   - [Gate 3 NEEDS_RESOLUTION decision](#gate-3-needs_resolution-decision)
4. **Output templates** (verbatim, field substitution):
   - Gate 1/2/3 result templates
   - Final summary template
   - [Rules](#rules) — Law 2 invariants, state file invariants

## Preflight

이 섹션은 첫 번째 (그리고 유일한) SKILL 호출에서 한 번만 실행된다.

**Step P0 — Derive project_dir (dispatch coordinate).** Compute the project
directory ONCE at preflight; freeze the value for the rest of the turn:

```bash
project_dir=$(pwd)
```

This value is threaded into every reviewer dispatch via the `project_dir:`
field (see [Reviewer dispatch contract](#reviewer-dispatch-contract)).
Worktree-aware: `pwd` resolves to the active worktree root. Do NOT re-derive
in any per-dispatch block — the reviewer agents declare `project_dir` as a
required dispatch parameter and forbid `pwd`/`git rev-parse` recomputation
in their personas.

**Step P1 — Global kill switch.** If `DEVBREW_DISABLE_QUALITY_GATES=1`,
emit `[quality-gates] disabled via DEVBREW_DISABLE_QUALITY_GATES=1` and
return immediately. Do NOT call setup-qg.sh or any agent.

**Step P2 — Setup state.** Run:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh" --ensure $ARGUMENTS
```

`setup-qg.sh --ensure` creates the per-session state file
(`.claude/quality-gates/<sid>/pipeline.md`) with minimal v1.32.0 schema.
Exit non-zero → surface stderr verbatim and abort.

**Step P3 — Pre-pipeline check (scope detection).** Run:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/pre-pipeline-check.sh"
```

The script exits non-zero on hard precondition violations (`no_session_id`,
`invalid_session_id`) and zero on normal codes. **Non-zero exit must abort
the pipeline immediately** — surface the script's stderr verbatim and stop.
Do NOT proceed to Gate 1 with degraded state.

On zero exit, parse the `result:` line. Handle every emitted code; unknown
values are a contract violation, not "treat as fresh":

| `result:` | Meaning | Downstream action |
|---|---|---|
| `fresh_start` | First run on this branch | normal — silent |
| `preserved` | Session file fresh; reuse | normal — silent |
| `no_session_data` | No prior state | normal — silent |
| `cleared_branch_mismatch` | HEAD branch changed; state wiped | tell user "branch changed; session scope reset"; do not use prior files.md |
| `cleared_stale` | Session file aged out; deleted | tell user "stale session data cleared"; do not use prior files.md |
| `active_resume` | Mid-pipeline resume on same session | continue with existing state |
| (other) | Unknown — contract violation | abort with stderr verbatim |

## Arguments

Parse from `/qg` invocation:
- `gate` (optional): `gate1`, `gate2`, `gate3`, or absent (full pipeline).
- `plan_path` (optional): defaults to "auto" (`scripts/discover-plan.sh`).
- `pr_url` (optional).
- `skip_runtime` (flag): if set, skip Gate 3.
- `paths` (optional, repeatable): scope override for Gate 2 diff.

Single-gate mode (`gate1`/`gate2`/`gate3`) runs ONLY the named gate and
emits its verdict directly — no decision-tool call, no inter-gate
transition.

## Dispatch Loop

Full pipeline mode:

1. Run [Trivia escape](#trivia-escape). If trivia detected, print "Trivia
   diff — all gates skipped" and return.
2. Run [Gate 1: Plan Verification](#gate-1-plan-verification).
   - On clean verdict → continue to Gate 2 (silently; print one-line "Gate 1: clean").
   - On failure → invoke [Gate 1 FAIL decision](#gate-1-fail-decision); branch
     per user choice (Continue anyway / Stop / View detail).
3. Run [Gate 2: PR Review](#gate-2-pr-review). Iterate (review → fix?) up
   to 5 times. At the end of EACH iteration:
   - findings empty → print "Gate 2 iter N: clean" and continue to Gate 3.
   - findings non-empty → invoke [Gate 2 iter boundary decision](#gate-2-iter-boundary-decision).
4. If `skip_runtime`, skip Gate 3 and emit final summary.
5. Otherwise run [Gate 3: Runtime Verification](#gate-3-runtime-verification).
   - On clean verdict → continue to final summary.
   - On failure → final summary with Gate 3 failure marker; do not auto-restart.
   - On needs-resolution → invoke [Gate 3 NEEDS_RESOLUTION decision](#gate-3-needs_resolution-decision)
     up to `DEVBREW_GATE3_MAX_RESOLUTIONS` times (default 3, env override,
     clamp 0..10).
6. Emit final summary.

## Trivia escape

Run `${CLAUDE_PLUGIN_ROOT}/scripts/check-trivia.sh`. Exit code:
- 0 = trivia detected → skip all gates. Print:
  > `Trivia diff — all gates skipped (one-sentence diff per CLAUDE.md trivia escape).`
- 1 = non-trivia → proceed to Gate 1.
- any other non-zero (script crash / environment failure) → print stderr
  verbatim and abort the pipeline. Do NOT silently treat as non-trivia.

## Gate 1: Plan Verification

Dispatch the `quality-gates:plan-verifier` subagent:

```
Agent({
  subagent_type: "quality-gates:plan-verifier",
  description: "Plan verification (Gate 1)",
  prompt: "Verify that all checkbox items in the plan are implemented. ..."
})
```

(Construct the actual prompt from `plan_path`, the discovered plan via
`scripts/discover-plan.sh`, and the current diff.)

Subagent returns a verdict YAML block with one of the three outcomes:

- **Clean verdict**: print `## Gate 1: Plan Verification — clean\n**Verdict:** clean\n**Summary:** <one line>` and continue to Gate 2.
- **SKIP**: print `## Gate 1 — SKIP\n**Reason:** <reason>` and continue to Gate 2.
- **Failure verdict**: print the full Gate 1 result block (including
  unimplemented item list) and proceed to
  [Gate 1 FAIL decision](#gate-1-fail-decision).

---

The Gate 1 verdict block is rendered before invoking the FAIL decision so
that the user has the full context in scrollback when they answer the
question below. The orchestrator does not auto-continue past Gate 1 on
failure; user consent is required regardless of how many planned items
remain unimplemented.

The following section is the decision-tool template fired only on the
failure branch. Single-gate mode (`/qg gate1`) emits the verdict block and
exits without calling the decision tool at all — the FAIL decision is a
full-pipeline-only mechanism for inter-gate progression consent.

Verdict output blocks above are addressed to the user (rendered to the
conversation transcript). The decision template below is addressed to the
assistant runtime: it is a literal tool call the orchestrator emits, and
the user response arrives as a tool result in the same turn.

## Gate 1 FAIL decision

> **Spec anchor (AC7):** the literal phrase `Plan verification failed`
> MUST appear in the prompt — V2b grep checks this.

Call AskUserQuestion:

```
AskUserQuestion({
  questions: [
    {
      question: "Plan verification failed: <N> planned items not yet implemented (<summary>). How do you want to proceed?",
      header: "Gate 1 FAIL",
      options: [
        {label: "Continue anyway", description: "Proceed to Gate 2 review despite incomplete plan. Use when items are intentionally deferred."},
        {label: "Stop",            description: "Abort the pipeline. Address the gaps and re-run /qg."},
        {label: "View detail",     description: "Print full per-item verdict from plan-verifier, then ask again."}
      ],
      multiSelect: false
    }
  ]
})
```

Branch on the user's answer:
- **Continue anyway** → proceed to Gate 2 (record "Gate 1 failure — user continued" in History).
- **Stop** → emit final summary marked aborted at Gate 1.
- **View detail** → print the verbose Gate 1 verdict, then re-invoke this
  same decision tool (without `View detail` this time, to avoid loops).

## Gate 2: PR Review

Iterative fix-loop, `max_gate2_iterations = 5` (hard-coded constant).

For each iteration N (1..5):

1. Compute diff scope (paths / branch / session — from preflight result).
2. Dispatch the scout: `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/scout.py ...)`.
3. Dispatch reviewer subagents in parallel (per [Reviewer dispatch contract](#reviewer-dispatch-contract)).
   `quality-gates:security-reviewer` and `quality-gates:adversarial` are
   the in-house dispatches that MUST include `project_dir: "$project_dir"`:

```
Agent({
  subagent_type: "quality-gates:security-reviewer",
  description: "Security review (Gate 2 iter N)",
  prompt: "Run code-level security review on the current diff.
    project_dir: \"$project_dir\"
    diff_scope: <paths|branch|session as resolved at preflight>
    plan_path: <path or 'auto'>
    iteration: N
    <…scout-supplied context…>"
})

Agent({
  subagent_type: "quality-gates:adversarial",
  description: "Adversarial review of Phase-1 findings (Gate 2 iter N)",
  prompt: "Re-review findings from Phase-1 reviewers for false positives
    and missed exploit paths.
    project_dir: \"$project_dir\"
    phase1_findings: <yaml from security-reviewer + code-reviewer + codex>
    iteration: N"
})
```

   `pr-review-toolkit:code-reviewer` (if pr-review-toolkit available) and
   the codex reviewer (if `detect_codex.sh` returns true) are dispatched
   with their own contracts; they do not require `project_dir` because
   they re-derive scope from the inlined diff blob.
4. Dispatch `quality-gates:synthesizer` (or local synthesize_findings.py)
   to consolidate findings.
5. Compute boundary outcome:
   - findings empty → print `## Gate 2 iter N: clean` and exit the loop (continue to Gate 3).
   - findings non-empty → invoke [Gate 2 iter boundary decision](#gate-2-iter-boundary-decision).

If iteration N=5 ends with findings still non-empty: invoke
[Gate 2 max-iter decision](#gate-2-max-iter-decision) instead of the
normal iter-boundary decision.

---

The two decision templates below are tool-call literals; they fire only
on the non-empty-findings branch (iter-boundary) and on the iteration-5
exhaustion branch (max-iter). Each emits a single decision-tool invocation
with a unique header so the user can disambiguate iterations in the
transcript.

The iter-boundary anchor phrase `findings remain` is specific to this
template and must not appear in any other decision-tool call in this
SKILL, per spec AC6.

## Gate 2 iter boundary decision

> **Spec anchor (AC6):** the literal phrase `findings remain` MUST appear
> in the prompt — V2b grep checks this. This phrase is Gate 2-iter-specific
> (not used in any other decision-tool call in this SKILL).

Call AskUserQuestion (replace `N` with the iteration number, `<summary>`
with the synthesizer's one-line summary):

```
AskUserQuestion({
  questions: [
    {
      question: "Gate 2 iter N: findings remain (<summary>). What next?",
      header: "Gate 2 iter N",
      options: [
        {label: "Retry",              description: "Apply the suggested fixes (I will Edit the files in this turn), then re-run Gate 2 reviewers."},
        {label: "Proceed to Gate 3",  description: "Accept current findings as-is and continue to runtime verification."},
        {label: "Stop",               description: "Abort the pipeline at this iteration. Address findings and re-run /qg."}
      ],
      multiSelect: false
    }
  ]
})
```

Branch on answer:
- **Retry** → apply user-consented fixes by calling Edit/Write directly
  with the synthesizer's suggested patches; increment iteration counter;
  loop back to step 1 of the Gate 2 section. See
  [Retry: file-write safety](#retry-file-write-safety) for the
  canonicalization requirement on reviewer-supplied paths, and
  [Retry: error handling](#retry-error-handling) for the AskUserQuestion
  surface that fires on Edit failures.
- **Proceed to Gate 3** → exit the loop, continue to Gate 3 with current
  findings recorded in History.
- **Stop** → emit final summary marked aborted at Gate 2.

### Retry: file-write safety

Before applying any reviewer-supplied `file:` field, canonicalize BOTH the
project root and the candidate path (symlink-traversal mitigation, I10):

```python
import os
root = os.path.realpath(project_dir)
candidate = os.path.realpath(supplied_file)
if os.path.commonpath([root, candidate]) != root:
    raise SecurityError(f"Path escapes project_dir: {candidate}")
```

Display the **full canonicalized file list** in the AskUserQuestion
`description` field (not just a `<summary>` field) so the user sees every
path that will be written. Reject and warn on any path resolving outside
`project_dir`.

### Retry: error handling

If `Edit` returns one of `old_string not unique`, `EACCES`, `ENOSPC`, or
any other failure during Retry application, do NOT silently skip.
Surface "Retry failed" via AskUserQuestion (abort retry or skip this file, never silent):

```
AskUserQuestion({
  questions: [
    {
      question: "Retry failed at <file>: <reason>. Abort the retry iteration, or skip this file and continue with the remaining patches?",
      header: "Retry",
      options: [
        {label: "Abort retry",     description: "Abort this Retry iteration entirely; surface as failure to the Gate 2 verdict."},
        {label: "Skip this file",  description: "Skip THIS file's fix only; continue applying remaining Retry patches in this iteration."}
      ],
      multiSelect: false
    }
  ]
})
```

No silent retry-skip — every Edit failure surfaces a user choice. Labels
are explicit: "Abort retry" terminates the iteration; "Skip this file"
continues with remaining patches.

## Reviewer dispatch contract

The following four reviewer subagents declare `project_dir` as a REQUIRED
dispatch parameter and forbid `pwd`/`git rev-parse` recomputation inside
the persona. Any dispatch of these agents MUST thread the preflight-frozen
`$project_dir` value via the `project_dir:` field of the prompt:

- `quality-gates:adversarial`
- `quality-gates:test-scope-validator`
- `quality-gates:security-reviewer`
- `quality-gates:runtime-verifier`

The contract is verified by:
- runtime: agent personas reject prompts missing `project_dir:` (see
  `plugins/quality-gates/agents/*.md` frontmatter)
- static: `tests/harness/test_skill_orchestration_behavior.sh` asserts
  every `subagent_type: "<agent>"` block in this SKILL has a
  `project_dir:` line within 10 lines (AC1, AC6 protocol-shape)

## Gate 2 max-iter decision

After iteration 5 still has findings, do NOT silently halt. Call:

```
AskUserQuestion({
  questions: [
    {
      question: "Gate 2 reached max 5 iterations. Last findings: <summary>. Proceed to Gate 3 or stop?",
      header: "Gate 2 max-iter",
      options: [
        {label: "Proceed to Gate 3", description: "Accept residual findings and continue."},
        {label: "Stop",              description: "Abort the pipeline. Address findings and re-run /qg."}
      ],
      multiSelect: false
    }
  ]
})
```

Branch on answer accordingly. (P18 unbounded-autonomy is satisfied by
this user-consent termination.)

## Gate 3: Runtime Verification

If `skip_runtime` was set in arguments, skip this entire section.

1. Dispatch `quality-gates:test-scope-validator` to classify scope-relevant
   test files (aligned / outdated-suspicion / cherry-pick-suspicion / unclear).
   Per [Reviewer dispatch contract](#reviewer-dispatch-contract), `project_dir`
   is required:

```
Agent({
  subagent_type: "quality-gates:test-scope-validator",
  description: "Classify scope-relevant test files (Gate 3)",
  prompt: "Validate test scope against current diff and plan items.
    project_dir: \"$project_dir\"
    plan_path: <path or 'auto'>
    candidate_test_files: <list from scope-detection step>"
})
```

2. Run `${CLAUDE_PLUGIN_ROOT}/scripts/detect-runtime.sh` to discover
   runnable surfaces (docker-compose, npm:dev, MCP servers, etc.).
3. Dispatch `quality-gates:runtime-verifier` with the runtime manifest.
   `project_dir` is required:

```
Agent({
  subagent_type: "quality-gates:runtime-verifier",
  description: "Runtime verification (Gate 3)",
  prompt: "Attempt each declared runnable surface and write an evidence-log.
    project_dir: \"$project_dir\"
    manifest: <output of detect-runtime.sh>
    resolution_iter: <N (1..DEVBREW_GATE3_MAX_RESOLUTIONS)>"
})
```

4. Subagent verdict: clean, failure, `SKIP_WITH_EVIDENCE`, or
   `NEEDS_RESOLUTION`.

Outcome routing:

- **Clean verdict** → print `## Gate 3: Runtime Verification — clean` and continue
  to final summary.
- **Failure verdict** → print full Gate 3 verdict block, then emit final
  summary marked Gate 3 failure. Do NOT auto-restart.
- **SKIP_WITH_EVIDENCE** → print verdict block with evidence; continue to
  final summary.
- **NEEDS_RESOLUTION** → invoke
  [Gate 3 NEEDS_RESOLUTION decision](#gate-3-needs_resolution-decision).

---

The NEEDS_RESOLUTION branch is the only Gate 3 outcome that surfaces a
user question. Clean and failure outcomes route directly to the final
summary; SKIP_WITH_EVIDENCE prints evidence and continues. The decision
template below is bounded by `DEVBREW_GATE3_MAX_RESOLUTIONS` so a
mis-configured environment cannot loop indefinitely.

Per spec AC8 and the secret-policy rule (P21 reaffirmation), the prompt
body asks the user to place secrets on disk first and then respond yes/no.
Never request a secret value as a literal string in the prompt.

## Gate 3 NEEDS_RESOLUTION decision

> **Spec anchor (AC8):** the literal phrase `Runtime verifier needs` MUST
> appear in the prompt — V2b grep checks this. **P21 reaffirmation MUST
> also appear in the prompt body** (literal token `P21`) — the prompt
> never asks for secret values, only paths or yes/no.

Loop up to `DEVBREW_GATE3_MAX_RESOLUTIONS` times (default 3, env override
clamped 0..10):

```
AskUserQuestion({
  questions: [
    {
      question: "Runtime verifier needs: <missing resource description>. (P21: never paste secrets into this prompt — add them to .env / config on disk first, then choose Yes, retry.)",
      header: "Gate 3 resolve",
      options: [
        {label: "Yes, retry",         description: "I've added the missing resource on disk. Re-run Gate 3."},
        {label: "Skip with evidence", description: "Mark Gate 3 SKIP_WITH_EVIDENCE with reason."},
        {label: "Stop",               description: "Abort the pipeline at Gate 3."}
      ],
      multiSelect: false
    }
  ]
})
```

Branch:
- **Yes, retry** → increment resolution counter; if exceeds env limit,
  fall through to Skip with evidence. Otherwise re-dispatch runtime-verifier.
- **Skip with evidence** → record SKIP_WITH_EVIDENCE and continue to summary.
- **Stop** → final summary aborted at Gate 3.

## Final Summary

Print:

```markdown
## Quality Gates Pipeline — Complete (v1.32.0)

- **Gate 1**: <clean|failed-continued|SKIP>
- **Gate 2**: <clean iter N | proceeded-with-findings iter N | aborted iter N | skipped>
- **Gate 3**: <clean | failed | SKIP_WITH_EVIDENCE | aborted | skipped>

**History:**
<copy the appended ## History lines from the state file>
```

State file cleanup is deferred to /cancel-qg or SessionEnd cleanup hook.

## Rules

**R1 (Law 2 — physical):** never call Edit/Write on agent persona files
(`plugins/quality-gates/agents/*.md`) in this turn. The orchestrator may
edit working-tree files for user-consented Gate 2 fixes only.

**R2 (state file write invariant):** never write `pipeline.md` frontmatter.
You MAY append a single line to the `## History` section per gate verdict;
do not modify any other content. Frontmatter is owned by setup-qg.sh.

**R3 (no fake user messages):** v1.32.0 has no Stop hook continuation, no
emission tag, and no continuation sentinel. Do NOT emit any such marker.

**R4 (P21 secret policy):** the decision-tool prompts never request a
secret value as a string. For Gate 3 missing-credential resolution, ask
the user to place secrets on disk (`.env`, config file) and respond yes/no.

**R5 (single dispatch per turn):** the entire pipeline runs in one turn.
Do not call setup-qg.sh more than once. Do not call check-trivia.sh more
than once. Do not re-dispatch the same Gate 2 reviewer for the same
iteration.
