---
name: quality-pipeline
description: >
  This skill runs the full quality-gates pipeline in a single assistant
  turn. Triggered by `/qg`, "run quality gates", "verify my implementation",
  "check code quality", or "is my PR ready to merge". Dispatches up to
  two gates (review, then optionally runtime verification)
  serially in a single turn. Progression decisions and fix-loop
  iteration boundaries surface to the user via AskUserQuestion tool calls.
  With a gate argument (`/qg both|review|runtime`) the happy path requires zero
  user clicks; bare `/qg` asks one upfront gate-scope question (Review only /
  both), then runs click-free on the happy path.
cost_class: variable
allowed-tools:
  # Group 1 — Preflight scripts (실행 순서: setup → pre-check → trivia)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/pre-pipeline-check.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-trivia.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-review-scope.sh:*)
  # Group 2 — Review gate scripts
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/scout.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/run_codex_reviewer.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/synthesize_findings.py:*)
  # Group 3 — Runtime gate scripts
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/detect-runtime.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/detect_codex.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/compute-test-scope-candidates.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh:*)
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

# Quality Gates — In-Turn Orchestrator (v2.5.0)

You are running the **full quality-gates pipeline** in a single assistant
turn. You dispatch up to two gates serially in order (Runtime gate only when selected). At decision points
(review-iter boundary, runtime needs-resolve) you call
`AskUserQuestion` and branch on the user's response — the response arrives
as a tool result in the same turn, so no Stop hook and no continuation
sentinel are needed.

**Law 2 (Writer ≠ Reviewer):** you are the orchestrator (writer). `security-reviewer`, `adversarial`, and `test-scope-validator` are read-only reviewers (`disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]`). The `runtime-verifier` is a **sandbox executor**: it CAN Write/Edit, but only inside a disposable git-worktree sandbox, and you enforce Law 2 *structurally* — after it runs you compute `qg-worktree.sh mutation-guard <sandbox> <baseline> <snapshot_digest>` and, if `forced_downgrade: yes`, you cap the verdict at FAIL regardless of what the verifier claimed. The `<snapshot_digest>` is the orchestrator-held seal (captured at create-sandbox) that the guard verifies before trusting its snapshot — the verifier cannot reach it (§6.1). Nothing is committed; the sandbox is discarded. You may also apply user-approved Review-gate fixes ("Retry" path) via Edit/Write — those are user-consented.

**State file:** read `worktree_path` from `.claude/quality-gates/<sid>/pipeline.md`
only during preflight; never write. Setup script handles creation, /cancel-qg
handles deletion.

## Contents

이 SKILL은 단일 어시스턴트 턴 안에서 전체 파이프라인을 실행. 섹션 그룹:

1. **Workflow (top-to-bottom on invocation):**
   - [Preflight](#preflight) — kill switch / setup-qg / pre-pipeline-check
   - [Arguments](#arguments) — `/qg` flags 파싱
   - [Dispatch Loop](#dispatch-loop) — two gates serialized in order with per-gate iteration
2. **Per-gate dispatch logic:**
   - [Trivia escape](#trivia-escape) — one-sentence diff → all gates skipped
   - [Review gate](#review-gate) — scout + Phase 1 + adversarial + synthesizer; iter loop with decision tool at every boundary
   - [Runtime gate](#runtime-gate) — test-scope-validator + runtime-verifier
3. **Decision points (AskUserQuestion templates):**
   - [Review iter boundary decision](#review-iter-boundary-decision)
   - [Review max-iter decision](#review-max-iter-decision)
   - [Runtime NEEDS_RESOLUTION decision](#runtime-needs_resolution-decision)
4. **Output templates** (verbatim, field substitution):
   - Review / Runtime result templates
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
Do NOT proceed to the Review gate with degraded state.

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
- `gate` (optional): `review`, `runtime`, `both`, or absent.
  - `review` → Review gate only. `runtime` → Runtime gate only (single-gate).
  - `both` → run **both** gates with no gate-scope question (the zero-click "both" escape; symmetric with `review`/`runtime`). `both` answers **gate scope only**, not runtime scope — so Decision 2 still fires for `/qg both` when a `requires_decision` surface exists (same as bare `/qg`).
  - absent → fire the Decision 1 gate-scope question (Review gate only / Run both gates).
  - **Precedence:** an explicit `gate=` value always wins over `--skip-runtime`; on conflict `gate=` wins and a one-line advisory is printed (see Decision 1). No silent conflict.
- `plan_path` (optional): defaults to "auto" (`scripts/discover-plan.sh`).
  Threaded as a secondary scope hint to the Runtime gate's test-scope-validator
  and the Review gate's security-reviewer / adversarial dispatches. The Gate-1
  plan-verifier was removed in v2.0.0 — plan is no longer verified, only hinted.
- `spec_path` (optional): defaults to "auto" (`scripts/discover-spec.sh`).
  The project spec is the Acceptance Criteria truth. Consumed by the Runtime
  gate's test-scope-validator (used to assess per-AC coverage — emitted as the advisory `ac_coverage` output) and by
  the Review gate codex path (spec AC injected into `<spec_context>`,
  script-internal in `run_codex_reviewer.sh`). If
  `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1`, pass `spec_path: none` to the
  test-scope-validator dispatch — this forces the no-spec fallback (ac_coverage
  omitted, plan-based scope only). All spec behavior is advisory; it never
  blocks a gate.
- `pr_url` (optional).
- `skip_runtime` (flag): if set, skip the Runtime gate — **subject to gate-scope precedence** (normalized below).
- `paths` (optional, repeatable): scope override for the Review gate diff.

**Effective skip-runtime (precedence normalization).** After parsing, compute `effective_skip_runtime`: it is `true` only when `skip_runtime` is set AND no explicit `gate ∈ {runtime, both}` was given. If `--skip-runtime` is combined with an explicit `gate=runtime` / `gate=both`, `gate=` wins → `effective_skip_runtime = false` and you print `> [quality-gates] --skip-runtime ignored: explicit gate=<value> wins (precedence).` (`gate=review` + `--skip-runtime` agree — no conflict; `effective_skip_runtime = true`.) **Every runtime-skip test below uses `effective_skip_runtime`, never the raw `skip_runtime` flag** — this is what wires the Decision-1 precedence rule into actual execution.

Single-gate mode (`review`/`runtime`) runs ONLY the named gate and
emits its verdict directly — no inter-gate progression. `/qg runtime`
bypasses the Dispatch Loop (and Decision 2), so it produces its
runtime-scope inputs at the Runtime gate's [Step R-init](#runtime-gate)
instead — `detect-runtime.sh` → `manifest` / `approved_surfaces` /
`block_policy` (and the runtime-scope question if a `requires_decision`
surface exists) — preserving main's single-gate behavior (spec §3
Non-goal: single-gate 동작 무변경).

## Upfront Execution Plan

Two upfront decisions are owned here, in order, before any gate runs — after [Preflight](#preflight) and [Arguments](#arguments), as [Dispatch Loop](#dispatch-loop) step 2 (after the trivia escape, before any gate dispatch). **Decision 1 (gate scope)** fires first and always (unless an argument pre-answers it); **Decision 2 (runtime scope)** is conditional and only reachable when gate scope = both.

### Decision 1 — Gate scope (always, unless an argument pre-answers it)

Fire this **first**, before any gate dispatch — it runs as part of [Dispatch Loop](#dispatch-loop) step 2, ahead of the Review gate.

- **Skip condition (an argument is the answer):** if `gate ∈ {review, runtime, both}` or `skip_runtime` is set, that argument IS the answer — do NOT fire the question. `--skip-runtime` is an alias for "Review gate only" (= `gate=review`).
- **Precedence (no silent conflict):** an explicit `gate=` value always wins over `--skip-runtime`. If `--skip-runtime` is combined with a conflicting `gate=runtime`/`gate=both`, `gate=` wins, `--skip-runtime` is ignored, and you print a one-line advisory: `> [quality-gates] --skip-runtime ignored: explicit gate=<value> wins (precedence).` The [Arguments](#arguments) mapping is normative on conflict.
- **Otherwise fire a binary AskUserQuestion.** The literal phrase `both gates` MUST appear in the `question:` field — it is this decision's protocol-shape anchor and is unique across all decision-tool calls in this SKILL:

```
AskUserQuestion({
  questions: [
    {
      question: "Run both gates (Review gate → Runtime gate), or only the Review gate?",
      header: "Gate scope",
      options: [
        {label: "Run both gates",   description: "Review gate then Runtime gate. Runtime scope is decided next only if a requires_decision surface exists."},
        {label: "Review gate only", description: "Run the Review gate and stop; skip the Runtime gate entirely."}
      ],
      multiSelect: false
    }
  ]
})
```

- **Branch on answer:**
  - `Review gate only` (also `gate=review` / `--skip-runtime`) → run the Review gate, then **short-circuit** the Runtime stage: skip Decision 2 and the entire Runtime gate, and emit the final summary.
  - `Run both gates` (also `gate=both`) → proceed to Decision 2.

### Decision 2 — Runtime scope + block policy (conditional)

Reached when gate scope = both via the full-pipeline Dispatch Loop (interactive `Run both gates`, or the `gate=both` argument). **Single-gate `/qg runtime` bypasses the Dispatch Loop and runs the equivalent runtime-scope init at the Runtime gate's [Step R-init](#runtime-gate) instead** — so every path that reaches the Runtime gate produces `manifest` / `approved_surfaces` / `block_policy` for R3. Decide runtime scope ONCE, but only when there is something risky to decide.

1. Run `${CLAUDE_PLUGIN_ROOT}/scripts/detect-runtime.sh` to get the manifest with `requires_decision` flags. This runs whenever gate scope = both — the manifest is also threaded to the Runtime gate's R3 dispatch.
2. **Gate firing condition (mechanical):** fire an `AskUserQuestion` **only if** the manifest has ≥1 surface with `requires_decision: true` AND no argument already pre-answers the *surface selection*. `gate=both` answers **gate scope only** — it does NOT pre-answer runtime scope, so Decision 2 still fires for `/qg both` when a `requires_decision` surface exists (matching bare `/qg` runtime behavior). Otherwise (pure-local test runners only / no risky surface / surface-arg-answered) print a one-line plan and proceed **zero-click**.
3. When firing, confirm in ONE question: **runtime scope** (which `requires_decision` surfaces to opt into — test runners are automatic) and **block policy** (`stop` / `skip` / `ask`). Record the opted-in surfaces as `approved_surfaces` and the chosen `block_policy`.

```
AskUserQuestion({
  questions: [
    {
      question: "Runtime scope: these surfaces can start processes or reach outside (requires_decision): <list>. Which should I run, and what should I do if one stays blocked after setup retries?",
      header: "Runtime scope",
      options: [
        {label: "Run all + skip blocked", description: "Opt into all listed surfaces; block_policy=skip (SKIP_WITH_EVIDENCE, continue)."},
        {label: "Run all + ask on block", description: "Opt into all; block_policy=ask (mid-run question, bounded by DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS)."},
        {label: "Test runners only",       description: "Skip every requires_decision surface; run only automatic test runners."},
        {label: "Stop on block",            description: "Opt into all; block_policy=stop (abort the gate at the first unrecoverable block)."}
      ],
      multiSelect: false
    }
  ]
})
```

**Upfront approval is authoritative.** A surface opted in here is NOT re-asked mid-run. A mid-run question fires only for a *newly discovered* block when `block_policy=ask`, and the total number of such mid-run questions is itself bounded by `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS`.

**Cost heads-up (AC13):** if the plan includes a web process-start surface (a heavy interactive flow on the inherited model), print one line before dispatching: `> Runtime gate will boot a web app and drive browser flows (heavier; inherited model).`

## Dispatch Loop

Full pipeline mode:

1. Run [Trivia escape](#trivia-escape). If trivia detected, print "Trivia diff — all gates skipped" and return.
2. Run [Upfront Execution Plan](#upfront-execution-plan). **Decision 1 (gate scope)** fires first (always, unless an arg pre-answers it): if the user chooses **Review gate only** (or `gate=review` / `--skip-runtime`), run the Review gate then **short-circuit** — skip Decision 2 and the Runtime gate, and go straight to the final summary (step 6). If **Run both gates** (or `gate=both`), continue. **Decision 2 (runtime scope + `block_policy`)** then fires only when a `requires_decision` surface exists and its surface selection is not arg-answered (zero-click otherwise); it records `approved_surfaces` and `block_policy`.
3. Run [Review gate](#review-gate) (unless gate scope excludes it). Iterate up to 5 times; at each iteration end: findings empty → continue; non-empty → [Review iter boundary decision](#review-iter-boundary-decision).
4. If `effective_skip_runtime` or gate scope excludes runtime, skip the Runtime gate and emit final summary.
5. Otherwise run [Runtime gate](#runtime-gate) (R0–R6).
6. Emit final summary.

## Trivia escape

Run `${CLAUDE_PLUGIN_ROOT}/scripts/check-trivia.sh`. Exit code:
- 0 = trivia detected → skip all gates. Print:
  > `Trivia diff — all gates skipped (one-sentence diff per CLAUDE.md trivia escape).`
- 1 = non-trivia → proceed to the Review gate.
- any other non-zero (script crash / environment failure) → print stderr
  verbatim and abort the pipeline. Do NOT silently treat as non-trivia.

## Review gate

Iterative fix-loop, `max_review_iterations = 5` (hard-coded constant).

For each iteration N (1..5):

1. Compute diff scope (paths / branch / session — from preflight result). **Scope transparency (P8 determinism-economy):** iteration N=1에서, 스코프가 *암묵 default(session)* 로 — 즉 `branch`/`--paths` arg 없이 — 풀렸다면 사용자-가시 한 줄을 출력한다: `> Review scope: session (<COUNT> files edited this session). 전체 PR/브랜치는 /qg branch.` (`<COUNT>` = preflight `files.md` 항목 수). 명시적 `/qg branch`·`--paths`는 사용자가 scope를 이미 골랐으므로 출력하지 않는다. 이는 결정론 가드가 **아니다** — git 비교·차단 로직 없이 "scope가 암묵 session인가?"만 본다. 자연어로 표현된 scope 의도(예: "전체 PR", "지금 브랜치")는 별도 토큰 parser 없이 모델이 자유롭게 해석해 branch scope로 라우팅한다 (non-load-bearing routing은 모델 신뢰; `/qg branch`는 결정론적 escape hatch로 유지).
**Step 1b — Scope signal & empty-scope redirect (iteration N=1 only).** Before
dispatching the scout, run the read-only scope signal **once** and cache it for
the rest of this turn (C7 — single call; the cached values are consumed again by
the honest-verdict floor at Step 4.5, so the gate and the floor can never diverge):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/check-review-scope.sh" <mode> [globs...]
```

`<mode>` is the scope resolved at step 1 (`session` / `branch` / `paths`); in
`paths` mode pass the `--paths` globs as trailing args. Parse the structured
stdout and cache `$scope_signal` (the `signal:` value), `$branch_ahead_count`,
and `$base`. Route on `$scope_signal`:

- `empty_scope_with_changes` AND `DEVBREW_QG_DISABLE_SCOPE_REDIRECT` unset → fire
  the [Empty-scope redirect decision](#empty-scope-redirect-decision) NOW (before
  the scout), and branch per that section before continuing.
- `empty_scope_with_changes` AND `DEVBREW_QG_DISABLE_SCOPE_REDIRECT=1` → do NOT
  fire the gate; print one advisory line and continue to the scout (the Step 4.5
  floor still relabels the verdict — AC9):
  `> [quality-gates] review scope empty but branch <M> ahead of <base> — redirect gate disabled; floor still applies.`
- `normal` / `genuine_noop` → no gate, no advisory; continue silently to the scout
  (happy-path zero-click).
- `degraded` → no gate, no floor (fail-open per C5), but print one loud advisory
  line so the fallback is visible (CLAUDE.md loud-logging; design §5.1):
  `> [quality-gates] scope check degraded (detached HEAD / no base / shallow) — empty-scope detection skipped (fail-open; verdict not floor-protected this run).`
  then continue to the scout.

Run this signal check ONLY in iteration N=1 — the empty-scope case is resolved
here (branch / honest-empty / stop), so iterations 2–5 always run on a non-empty
scope and never re-trigger it.

2. Dispatch the scout: `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/scout.py ...)`.
3. Dispatch reviewer subagents in parallel (per [Reviewer dispatch contract](#reviewer-dispatch-contract)).
   `quality-gates:security-reviewer` and `quality-gates:adversarial` are
   the in-house dispatches that MUST include `project_dir: "$project_dir"`:

```
Agent({
  subagent_type: "quality-gates:security-reviewer",
  description: "Security review (Review gate iter N)",
  prompt: "Run code-level security review on the current diff.
    project_dir: \"$project_dir\"
    diff_scope: <paths|branch|session as resolved at preflight>
    plan_path: <path or 'auto'>
    iteration: N
    <…scout-supplied context…>"
})

Agent({
  subagent_type: "quality-gates:adversarial",
  description: "Adversarial review of Phase-1 findings (Review gate iter N)",
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
   The codex reviewer additionally injects the project spec's Acceptance
   Criteria into its `<spec_context>` slot — resolved **script-internally** by
   `run_codex_reviewer.sh` (via `discover-spec.sh`), so no `spec_path` dispatch
   field and no `allowed-tools` change are needed here (invocation parity with
   the existing `discover-plan.sh` mechanism). `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1`
   empties the slot — `run_codex_reviewer.sh` reads the env variable directly, so the orchestrator passes no additional argument for the codex path.
4. Dispatch `quality-gates:synthesizer` (or local synthesize_findings.py)
   to consolidate findings. **Capture the script's complete stdout** — the
   synthesized Markdown block (counts line + findings table + suggested-fixes
   list, or the empty-state line). You surface this verbatim in step 4.5; do
   NOT reformat or re-summarize it yourself (Law 1 determinism — the script,
   not the orchestrator, owns the rendering).

   **Step 4.5 — Surface findings.** Judge the boundary on the **kept
   (displayed) finding count**, read from the `**Findings:**` counts line in
   that stdout — NOT the raw reviewer count. Three cases:
   - **kept > 0** (the counts line totals ≥ 1 across the three severities) →
     emit the captured stdout to the user as a deliberate assistant message,
     prepended with the single context line `## Review gate iter N — Findings`,
     **before** invoking the decision tool. Then go to step 5.
   - **kept = 0 AND suppressed > 0** (the synthesizer emitted the empty-state
     line `No high-confidence findings. N low-confidence findings suppressed.`
     with N > 0 — read N from that line) → no high-confidence finding to act
     on → treat as **clean**: do NOT call AskUserQuestion. Surface only that
     single `No high-confidence findings…` line for transparency, then **exit
     the loop → [Dispatch Loop](#dispatch-loop) step 4** (which skips the Runtime
     gate when gate scope = Review gate only / `effective_skip_runtime`, else runs
     it) — do not iterate again.
   - **kept = 0 AND suppressed = 0** (the same empty-state line with N = 0) →
     print `## Review gate iter N: clean` and exit the loop → [Dispatch
     Loop](#dispatch-loop) step 4 (which short-circuits the Runtime gate for the
     review-only path, else runs it).

5. **Decision tool (kept > 0 only).** Invoke [Review iter boundary
   decision](#review-iter-boundary-decision). Fill its `<summary>` slot by
   **verbatim-copying the `**Findings:**` counts line** from step 4's stdout
   (deterministic extraction — do NOT author a fresh sentence). Append one
   `## History` line of the form
   `Review gate iter N: <c> CRITICAL / <i> IMPORTANT / <s> SUGGESTION → user chose <choice>`
   (severity triplet copied from the same counts line; see
   [state-file-format](references/state-file-format.md#history)).

If iteration N=5 ends with kept > 0: run step 4.5's surface first (same as
above), then invoke [Review max-iter decision](#review-max-iter-decision)
instead of the normal iter-boundary decision. Fill that template's
`Last findings: <summary>` slot with the same verbatim counts line (the
template text itself is unchanged).

---

The two decision templates below are tool-call literals; they fire only
on the non-empty-findings branch (iter-boundary) and on the iteration-5
exhaustion branch (max-iter). Each emits a single decision-tool invocation
with a unique header so the user can disambiguate iterations in the
transcript.

The iter-boundary anchor phrase `findings remain` is specific to this
template and must not appear in any other decision-tool call in this
SKILL, per spec AC6.

## Empty-scope redirect decision

> **Spec anchor (AC6):** the literal phrase `review scope is empty` MUST appear
> in the `question:` field — the orchestration harness checks it exists and is
> UNIQUE across all decision-tool calls in this SKILL (grep -c == 1). Fired only
> from Review gate Step 1b when `$scope_signal == empty_scope_with_changes` and
> `DEVBREW_QG_DISABLE_SCOPE_REDIRECT` is unset.

```
AskUserQuestion({
  questions: [
    {
      question: "Review scope is empty (session: 0 files) but the branch is <M> files ahead of <base>. These changes were never reviewed this session. What should I review?",
      header: "Review scope",
      options: [
        {label: "Review branch diff (recommended)", description: "Review the merge_base..HEAD diff; re-interpret scope as branch, then proceed normally."},
        {label: "Proceed (honest-empty, not clean)", description: "Skip reviewer dispatch and emit an honest verdict — 'no scope reviewed, NOT clean'."},
        {label: "Stop", description: "Abort the pipeline with an honest summary. Re-run with /qg branch."}
      ],
      multiSelect: false
    }
  ]
})
```

Substitute `<M>` = cached `$branch_ahead_count`, `<base>` = cached `$base`.
Branch on the answer — each branch leaves a transcript-observable line (AC7):

- **Review branch diff** → re-interpret scope as `branch`: the review target is
  `git merge-base $base HEAD`..HEAD, reusing the **script-emitted base** `$base`
  (C6 single base — the displayed "<M> files" equals the reviewed diff). Print
  `> Review scope: branch (<M> files vs <base>).` then continue to step 2 (the
  scout) and proceed normally for the remaining iterations.
- **Proceed (honest-empty, not clean)** → skip the scout / reviewer / synthesizer
  dispatch entirely (no value in reviewing 0 files). Print the positive observable
  line `> Review gate: skipping reviewer dispatch — 0 files reviewed (honest-empty path).`
  then emit the honest verdict label (the Step 4.5 floor label
  `## Review gate iter N: no scope reviewed (0 files; branch <M> ahead of <base>) — NOT certified clean.`)
  and exit the loop → [Dispatch Loop](#dispatch-loop) step 4.
- **Stop** → emit the final summary marked
  `aborted at Review gate (empty scope, branch <M> ahead)`.

## Review iter boundary decision

> **Spec anchor (AC6):** the literal phrase `findings remain` MUST appear
> in the prompt — V2b grep checks this. This phrase is Review-iter-specific
> (not used in any other decision-tool call in this SKILL).

Call AskUserQuestion (replace `N` with the iteration number, `<summary>`
with the synthesizer's one-line summary):

```
AskUserQuestion({
  questions: [
    {
      question: "Review gate iter N: findings remain (<summary>). What next?",
      header: "Review iter N",
      options: [
        {label: "Retry",              description: "Apply the suggested fixes (I will Edit the files in this turn), then re-run Review gate reviewers."},
        {label: "Proceed to Runtime gate",  description: "Accept current findings as-is and continue to runtime verification."},
        {label: "Stop",               description: "Abort the pipeline at this iteration. Address findings and re-run /qg."}
      ],
      multiSelect: false
    }
  ]
})
```

**Gate-scope conditional (review-only):** when gate scope = `Review gate only` (the Decision 1 choice, or `gate=review` / `--skip-runtime`) there is no Runtime gate to proceed to — replace the `Proceed to Runtime gate` option above with `{label: "Proceed (accept findings, finalize)", description: "Accept current findings as-is and go straight to the final summary; the Runtime gate is short-circuited."}` and branch it to the final summary (NOT the Runtime gate). `Retry` and `Stop` are unchanged.

Branch on answer:
- **Retry** → apply user-consented fixes by calling Edit/Write directly
  with the synthesizer's suggested patches; increment iteration counter;
  loop back to step 1 of the Review gate section. See
  [Retry: file-write safety](#retry-file-write-safety) for the
  canonicalization requirement on reviewer-supplied paths, and
  [Retry: error handling](#retry-error-handling) for the AskUserQuestion
  surface that fires on Edit failures.
- **Proceed to Runtime gate** → exit the loop, continue to the Runtime gate with current
  findings recorded in History.
- **Proceed (accept findings, finalize)** (review-only variant) → exit the loop, skip the Runtime gate, and emit the final summary with findings recorded.
- **Stop** → emit final summary marked aborted at the Review gate.

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
        {label: "Abort retry",     description: "Abort this Retry iteration entirely; surface as failure to the Review gate verdict."},
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

## Review max-iter decision

After iteration 5 still has findings, do NOT silently halt. Call:

```
AskUserQuestion({
  questions: [
    {
      question: "Review gate reached max 5 iterations. Last findings: <summary>. Proceed to the Runtime gate or stop?",
      header: "Review max-iter",
      options: [
        {label: "Proceed to Runtime gate", description: "Accept residual findings and continue."},
        {label: "Stop",              description: "Abort the pipeline. Address findings and re-run /qg."}
      ],
      multiSelect: false
    }
  ]
})
```

**Gate-scope conditional (review-only):** when gate scope = `Review gate only`, replace the `Proceed to Runtime gate` option with `{label: "Proceed (accept findings, finalize)", description: "Accept residual findings and go straight to the final summary; the Runtime gate is short-circuited."}` branching to the final summary, not the Runtime gate.

Branch on answer accordingly. (P18 unbounded-autonomy is satisfied by
this user-consent termination.)

## Runtime gate

If `effective_skip_runtime` was set, skip this entire section.

**Step R-init — Runtime-scope inputs (every path that reaches this gate).** The R3 dispatch requires `manifest`, `approved_surfaces`, and `block_policy`. The full-pipeline `Run both gates` / `gate=both` path produced them in [Decision 2](#decision-2--runtime-scope--block-policy-conditional). **Single-gate `/qg runtime` bypassed the Dispatch Loop, so if `approved_surfaces` / `block_policy` are still unset on entry here, produce them now**: run `${CLAUDE_PLUGIN_ROOT}/scripts/detect-runtime.sh` to get the `manifest`, then apply Decision 2's firing logic on the result — fire the runtime-scope `AskUserQuestion` only if ≥1 `requires_decision` surface exists and no surface-selection arg pre-answers it; otherwise zero-click with the automatic test runners as `approved_surfaces` and a default `block_policy=skip`. (`gate=runtime` pre-answers gate scope, NOT surface selection — same as main; spec §3 Non-goal preserves single-gate behavior.) After this step `manifest` / `approved_surfaces` / `block_policy` are guaranteed defined for R3. If Decision 2 already ran (gate scope = both), this step is a no-op.

**Step R0 — Create the sandbox (or fall back).** Seal the code-under-review into a disposable git-worktree:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" create-sandbox "<session-id>"
```

- Exit 0 → capture **line 1 = `sandbox_dir`**, **line 2 = `baseline_sha`**, **line 3 = `snapshot_digest`**. Parse contract (fixed): read exactly three lines with three successive `IFS= read -r` (`sandbox_dir` → `baseline_sha` → `snapshot_digest`) and strip trailing whitespace/CR from `snapshot_digest` (`tr -d '[:space:]'` or equivalent) — a stray newline/space in the hex makes the guard fail-closed on every run. Hold all three as orchestrator variables (verifier-unreachable: they live in this SKILL turn's context, not in the sandbox). Set `runtime_project_dir = sandbox_dir` (the verifier's `project_dir` for this gate, frozen — overrides the preflight `project_dir` for the Runtime gate only).
- **Exit 3** (kill switch `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1`) → graceful fallback (no sandbox): set `runtime_project_dir = project_dir` (the preflight main-repo dir; `sandbox_dir`/`baseline_sha` stay UNSET). The verifier runs in read-only smoke mode against the real tree. Because the verifier still holds Write tools (frontmatter cannot be revoked per-dispatch), the fallback verdict is **capped at SKIP_WITH_EVIDENCE — never PASS** (no sandbox = no structural Law-2 guarantee = no certification; I-A). BEFORE the R3 dispatch, capture `fallback_pre` = `git -C "$project_dir" status --porcelain --untracked-files=all` plus a tracked content tree-hash baseline (`GIT_INDEX_FILE=<tmp> git -C "$project_dir" add -A -- . && git write-tree`). Print: `> [quality-gates] runtime sandbox disabled — read-only smoke mode on the real tree; verdict capped at SKIP_WITH_EVIDENCE (DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1).`
- Any other non-zero → surface stderr verbatim and mark the Runtime gate failed.

**Step R1 — test-scope-validator** (read-only reviewer; `project_dir` is the *preflight* dir, not the sandbox — it reviews the real diff). Per [Reviewer dispatch contract](#reviewer-dispatch-contract):

```
Agent({
  subagent_type: "quality-gates:test-scope-validator",
  description: "Classify scope-relevant test files (Runtime gate)",
  prompt: "Validate test scope against current diff, spec acceptance criteria, and plan items.
    project_dir: \"$project_dir\"
    spec_path: <path or 'auto'; pass 'none' if DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1>
    plan_path: <path or 'auto'>
    candidate_test_files: <list from scope-detection step>"
})
```

**Step R2 — gather spec Acceptance Criteria.** Resolve the spec (reuse `discover-spec.sh` semantics already used by test-scope-validator) and build `spec_acceptance_criteria` as a `{ac_id, text}` list. If no spec, pass an empty list (the verifier falls back to plan_features → smoke).

Also derive `evidence_dir = "$project_dir/.claude/quality-gates/$CLAUDE_CODE_SESSION_ID/"` (the preflight main-repo `project_dir`, NOT the sandbox — so it survives the R5 sandbox discard; `$CLAUDE_CODE_SESSION_ID` is the same value used for the pipeline state file). This absolute path is threaded to the verifier so its evidence-log + screenshots land in the main repo, not inside the disposable sandbox.
(detect-runtime.sh runs from this same main-repo `project_dir` during the Upfront Execution Plan, so its `attempted_log_path` resolves to the identical `evidence_dir`.)

**Step R3 — dispatch runtime-verifier (executor)** with `project_dir = runtime_project_dir`, the spec AC, the approved surfaces, and the block policy:

```
Agent({
  subagent_type: "quality-gates:runtime-verifier",
  description: "Runtime verification (Runtime gate, sandbox executor)",
  prompt: "Boot the declared surfaces in the sandbox, drive flows, assert against spec AC, write an evidence-log.
    project_dir: \"$runtime_project_dir\"
    evidence_dir: \"$evidence_dir\"
    spec_acceptance_criteria: <{ac_id,text} list or []>
    manifest: <output of detect-runtime.sh>
    approved_surfaces: <surfaces opted in at the Upfront Execution Plan>
    block_policy: <stop|skip|ask>
    resolution_iter: <N (1..DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS)>"
})
```

**Step R4 — Mutation guard (authoritative verdict cap).** Unless in read-only fallback, compute the product-mutation oracle:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" mutation-guard "<sandbox_dir>" "<baseline_sha>" "<snapshot_digest>"
```

Read the YAML. **If `forced_downgrade: yes`**, the verdict is capped at FAIL regardless of the verifier's emitted verdict (Law 2 — the verifier cannot self-approve a product change). Surface `tracked_diff` + `disallowed_new_files` as evidence ("the app only ran after this change — fix it in a normal writer→review cycle"). The verifier's own `writes:` self-report is advisory only; this git result is authoritative.

**R4 exit-code routing (C-C — mirror R0's discipline; an indeterminate guard is never a PASS).** Capture BOTH the guard's stdout YAML AND its exit code:

| Guard result | R4 routing |
|---|---|
| exit 0 + `forced_downgrade: no` (all §6.1 snapshot keys valid) | no product mutation → proceed to R5/R6 normally |
| exit 0 + `forced_downgrade: yes` | cap verdict at FAIL; surface `tracked_diff` / `disallowed_new_files` / `guard_flags` as evidence |
| **exit 4** (`guard_fail`), OR any other non-zero exit, OR a missing/invalid `forced_downgrade` key, OR a `guard_error:` line present | treat as `forced_downgrade: yes` → cap verdict at FAIL; surface the guard's `guard_error` + **stderr verbatim**; mark the Runtime gate failed. **Never read an errored or garbled guard as PASS** (indeterminate ≠ clean). |

An errored guard (corrupt index, lost gitdir, missing/truncated snapshot, bad baseline) must not present as "not a downgrade." This is the orchestration-layer half of the bypass closure — the guard script's layers 0–3 (§6.2) cover C-A/C-B/C-D/C-E; this table covers C-C.

A digest mismatch (the verifier forged the snapshot) surfaces here as **exit 4** with `guard_error: snapshot integrity check failed` — the same fail-closed path as any other indeterminate guard. This is the round-2 closure of C-NEW-1: the seal the guard checks is held by the orchestrator, out of the verifier's reach.

**Fallback working-tree guard (read-only mode only — I-A/I-B).** When the sandbox was disabled (Exit 3), do NOT run the sandbox `mutation-guard`. The verdict is already capped at SKIP_WITH_EVIDENCE (R0); this guard is a pure SAFETY SIGNAL, not a verdict input. After the R3 dispatch, recompute `fallback_post` (porcelain + tracked content tree-hash, same as `fallback_pre`). If anything changed (a porcelain entry in `fallback_post` not in `fallback_pre`, or a differing tree-hash), emit a loud warning **to user-visible stdout** AND record it in `evidence_dir` (§6.6): `> [quality-gates] WARNING: runtime fallback에서 working tree가 변경됨 — <changed files>. sandbox 미사용으로 구조적 보호 없음; 검토 요망 (git diff 후 revert 권장).` git-ignored files do not appear in `--porcelain`, so a setup-only `.env` fix is correctly NOT flagged. The warning does not change the verdict (already ≤SKIP cap) and does not block the gate (P18 — no extra loop).

**Step R5 — Discard the sandbox** (verdict-independent), unless in read-only fallback:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" remove "<sandbox_dir>"
```

**Step R6 — Outcome routing** (verdict = min(verifier verdict, guard cap, fallback cap)):

- **Fallback mode (sandbox disabled)** → the verifier's verdict is capped: a `PASS` becomes **SKIP_WITH_EVIDENCE** (no structural guarantee), `FAIL`/`NEEDS_RESOLUTION` pass through unchanged. The R4 fallback warning (if any) is printed but does not alter the verdict.
- **Clean (PASS) AND `forced_downgrade: no`** → print `## Runtime gate — clean` and continue to final summary.
- **`forced_downgrade: yes`** → print the Runtime gate FAIL block including the surfaced diff; emit final summary marked Runtime gate failure. Do NOT auto-restart, do NOT apply the diff (in-gate accept is out of scope).
- **FAIL** (product bug / unrecoverable) → print verdict block; final summary marked failure.
- **SKIP_WITH_EVIDENCE** → print evidence; continue.
- **NEEDS_RESOLUTION** → invoke [Runtime NEEDS_RESOLUTION decision](#runtime-needs_resolution-decision).

## Blocked-path routing

A surface is *blocked* when the executor cannot complete it. Routing (per-surface — one block never aborts the others):

| Block kind | Handling |
|---|---|
| setup-fixable (.env/deps) | executor auto-fixes in sandbox + retries (≤3/dispatch). Success → continue; exhausted → `NEEDS_RESOLUTION`. |
| operational-safety (prod config/network needed) | NOT run. Recorded `blocked-for-safety` → SKIP_WITH_EVIDENCE or NEEDS_RESOLUTION("provide test config"). |
| needs-decision (`requires_decision` not in `approved_surfaces`) | NOT run → SKIP_WITH_EVIDENCE. |
| product bug (AC unmet / won't boot from product defect) | FAIL + evidence. Not a retry. |
| hang/timeout | per-surface wall-clock kill; record blocked; continue with remaining surfaces. |

On executor `NEEDS_RESOLUTION` (setup retries exhausted), apply the upfront `block_policy`:
- `stop` → abort the gate at the block; terminal summary.
- `skip` → record SKIP_WITH_EVIDENCE for that surface; finalize with partial results.
- `ask` → invoke [Runtime NEEDS_RESOLUTION decision](#runtime-needs_resolution-decision) (retry / skip-with-evidence / stop). Total `ask` mid-run questions are bounded by `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS`; on exhaustion, fall through to skip-with-evidence.

---

The NEEDS_RESOLUTION branch is the only Runtime gate outcome that surfaces a user question when `block_policy=ask`. It is bounded by `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS` so a mis-configured environment cannot loop indefinitely.

Per spec AC8 and the secret-policy rule (P21), the prompt body asks the user to place secrets on disk first and respond yes/no. Never request a secret value as a literal string.

## Runtime NEEDS_RESOLUTION decision

> **Spec anchor (AC8):** the literal phrase `Runtime verifier needs` MUST appear in the prompt — V2b grep checks this. **P21 reaffirmation MUST also appear in the prompt body** (literal token `P21`) — the prompt never asks for secret values, only paths or yes/no.

Loop up to `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS` times (default 3, env override clamped 0..10):

```
AskUserQuestion({
  questions: [
    {
      question: "Runtime verifier needs: <missing resource description>. (P21: never paste secrets into this prompt — add them to .env / config on disk first, then choose Yes, retry.)",
      header: "Runtime resolve",
      options: [
        {label: "Yes, retry",         description: "I've added the missing resource on disk. Re-run the Runtime gate."},
        {label: "Skip with evidence", description: "Mark the Runtime gate SKIP_WITH_EVIDENCE with reason."},
        {label: "Stop",               description: "Abort the pipeline at the Runtime gate."}
      ],
      multiSelect: false
    }
  ]
})
```

Branch:
- **Yes, retry** → increment resolution counter; if exceeds env limit, fall through to Skip with evidence. Otherwise re-create the sandbox (Step R0) and re-capture the new output's `sandbox_dir` (line 1), `baseline_sha` (line 2), and `snapshot_digest` (line 3) with the same three successive `IFS= read -r` + digest-strip idiom as R0 — refreshing **all three** orchestrator variables. create-sandbox emits a NEW commit `B` AND a NEW snapshot (hence a new digest) each call, so reusing the old `baseline_sha` makes the guard `guard_fail "bad baseline sha"` and reusing the old `snapshot_digest` makes it `guard_fail "snapshot integrity check failed"` — both false FAILs. The new snapshot is auto-recorded in the new gitdir; the stale sandbox + its old snapshot are force-removed by R0's idempotent cleanup. Then re-dispatch runtime-verifier with the refreshed `sandbox_dir`, and call R4 as 3-arg with the refreshed `snapshot_digest`. (Fix the parse order: capturing the digest as line 2 swaps `baseline_sha`/`snapshot_digest` and fails-closed every run.)
- **Skip with evidence** → record SKIP_WITH_EVIDENCE and continue.
- **Stop** → final summary aborted at the Runtime gate.

## Final Summary

Print:

```markdown
## Quality Gates Pipeline — Complete (v2.5.0)

- **Review gate**: <clean iter N | proceeded-with-findings iter N | aborted iter N | skipped>
- **Runtime gate**: <clean | failed | SKIP_WITH_EVIDENCE | aborted | skipped>

**History:**
<copy the appended ## History lines from the state file>
```

State file cleanup is deferred to /cancel-qg or SessionEnd cleanup hook.

## Rules

**R1 (Law 2 — physical):** never call Edit/Write on agent persona files
(`plugins/quality-gates/agents/*.md`) in this turn. The orchestrator may
edit working-tree files for user-consented Review gate fixes only.

**R2 (state file write invariant):** never write `pipeline.md` frontmatter.
You MAY append a single line to the `## History` section per gate verdict;
do not modify any other content. Frontmatter is owned by setup-qg.sh.

**R3 (no fake user messages):** v1.32.0 has no Stop hook continuation, no
emission tag, and no continuation sentinel. Do NOT emit any such marker.

**R4 (P21 secret policy):** the decision-tool prompts never request a
secret value as a string. For Runtime gate missing-credential resolution, ask
the user to place secrets on disk (`.env`, config file) and respond yes/no.

**R5 (single dispatch per turn):** the entire pipeline runs in one turn.
Do not call setup-qg.sh more than once. Do not call check-trivia.sh more
than once. Do not re-dispatch the same Review gate reviewer for the same
iteration.
