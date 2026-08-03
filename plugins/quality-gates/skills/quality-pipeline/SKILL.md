---
name: quality-pipeline
description: >
  Runs the full quality-gates pipeline in a single assistant turn. Triggered by
  `/qg`, "run quality gates", "verify my implementation", "check code quality",
  or "is my PR ready to merge". Dispatches up to two gates (review, then
  optionally runtime verification) serially; progression and fix-loop decisions
  surface to the user via AskUserQuestion. A gate argument (`/qg both|review|runtime`)
  sets the scope. On non-aborted completion the command layer offers an opt-in
  PR-understanding publish continuation — a separate consent-gated step, not a gate.
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
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/resolve-baseline.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/run-test-selection.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/baseline-cache.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/diff-test-results.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check_qa_ledger.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/render-terminal.py:*)
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

# Quality Gates — In-Turn Orchestrator (v2.7.0)

You are running the **full quality-gates pipeline** in a single assistant
turn. You dispatch up to two gates serially in order (Runtime gate only when selected). At decision points
(review-iter boundary, runtime needs-resolve) you call
`AskUserQuestion` and branch on the user's response — the response arrives
as a tool result in the same turn, so no Stop hook and no continuation
sentinel are needed.

**Law 2 (Writer ≠ Reviewer):** you are the orchestrator (writer). `security-reviewer`, `adversarial`, and `test-scope-validator` are read-only reviewers (`tools: Read, Grep, Glob` — fail-closed allowlist). The `runtime-verifier` is a **sandbox executor**: it CAN Write/Edit, but only inside a disposable git-worktree sandbox, and you enforce Law 2 *structurally* — after it runs you compute `qg-worktree.sh mutation-guard <sandbox> <baseline> <snapshot_digest>` and, if `forced_downgrade: yes`, you cap the verdict at FAIL regardless of what the verifier claimed. The `<snapshot_digest>` is the orchestrator-held seal (captured at create-sandbox) that the guard verifies before trusting its snapshot — the verifier cannot reach it (§6.1). Nothing is committed; the sandbox is discarded. You may also apply user-approved Review-gate fixes ("Retry" path) via Edit/Write — those are user-consented.

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
   - [Reviewer composition (scope-driven)](#reviewer-composition-scope-driven) — 3-tier + rubric + palette
   - [Runtime gate](#runtime-gate) — 영향 판정 + 기준선 대비 차등 실행 + test-scope-validator/runtime-verifier
3. **Decision points (AskUserQuestion templates):**
   - [Review iter boundary decision](#review-iter-boundary-decision)
   - [Review max-iter decision](#review-max-iter-decision)
   - [Runtime NEEDS_RESOLUTION decision](#runtime-needs_resolution-decision)
4. **Output templates** (verbatim, field substitution):
   - Review / Runtime result templates
   - [Publish-eligible sentinel](#publish-eligible-sentinel) — fail-safe write contract shared by Final Summary + Runtime R8
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

`setup-qg.sh --ensure`는 또한 이번 run 시작 시 stale
`.claude/quality-gates/<sid>/publish-eligible.md`를 지운다(매 호출, `--ensure`
조기 exit 앞) — [Publish-eligible sentinel](#publish-eligible-sentinel)이 항상
이번 run의 완료만 반영하도록(SKILL은 `Write`만 있고 삭제 tool이 없어 이 정리는
스크립트가 담당).

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
runtime-scope inputs at the Runtime gate's [Step R5a⁰](#runtime-gate)
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

Reached when gate scope = both via the full-pipeline Dispatch Loop (interactive `Run both gates`, or the `gate=both` argument). **Single-gate `/qg runtime` bypasses the Dispatch Loop and runs the equivalent runtime-scope init at the Runtime gate's [Step R5a⁰](#runtime-gate) instead** — so every path that reaches the Runtime gate produces `manifest` / `approved_surfaces` / `block_policy` for R5a³. Decide runtime scope ONCE, but only when there is something risky to decide.

1. Run `${CLAUDE_PLUGIN_ROOT}/scripts/detect-runtime.sh` to get the manifest with `requires_decision` flags. This runs whenever gate scope = both — the manifest is also threaded to the Runtime gate's R5a³ dispatch.
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
5. Otherwise run [Runtime gate](#runtime-gate) (R-init–R9).
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

**Step 1b — Changes-exist signal (iteration N=1 only).** Before dispatching the
scout, run the read-only changes-exist signal **once** and cache it for the rest
of this turn (C3 — single call; the cached values are consumed by the
honest-verdict floor at Step 4.5):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/check-review-scope.sh"
```

The script takes **no arguments** — scope resolution (what to review) is yours, not
the script's. Parse the structured stdout and cache `$changes_exist`,
`$branch_ahead_count` (the changed-file count on `merge_base..HEAD`),
`$worktree_dirty`, `$base` (display name), and `$degraded`. There is **no routing**
here: this signal exists only to feed the Step 4.5 verdict floor.

- `$degraded == yes` → the changes-exist signal is unavailable (detached HEAD /
  no base branch / unrelated history / shallow). This run is NOT floor-protected;
  the Step 4.5 ELSE-IF branch prints one loud advisory at the verdict (CLAUDE.md
  loud-logging). Continue to the scout.

Run this signal check ONLY in iteration N=1; iterations 2–5 reuse the cached values
(single-call — do not re-invoke).

> **Review-scope ownership (honesty norm — G3).** You own review-scope resolution.
> If the scope you resolved at step 1 is empty (0 files) but the branch/worktree has
> changes (`$changes_exist == yes`), you MUST NOT certify clean — offer to review the
> full branch (`/qg branch`) or emit the honest "no scope reviewed" verdict. The Step
> 4.5 floor enforces this structurally: this norm is the routing half (model-owned),
> the floor is the integrity half (deterministic).

2. Dispatch the scout: `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/scout.py ...)` — compute its
   metrics from the review scope you resolved at step 1 (the session `files.md` set, the
   `branch` diff, or the `--paths` globs). Scope is model-owned; there is no cached scope
   variable to thread.
3. **Compose and dispatch the reviewer set (scope-driven).** You (orchestrator)
   select which reviewers to dispatch this iteration from three tiers. Selection is
   **model-owned routing** (P8 lightness — not a deterministic gate): the floor is
   fixed, codex is an availability-floor, and Tier C specialists are chosen by the
   diff scope per [Reviewer composition (scope-driven)](#reviewer-composition-scope-driven).
   Re-select every iteration. **No qg-own tool posture changes here (#104 lock kept).**

   **Tier A — Floor (스코프 무관, 항상 디스패치; 모델이 스코프 판단으로 뺄 수 없음).**
   `quality-gates:security-reviewer` (Phase 1) and `quality-gates:adversarial`
   (Phase 1.5) run **every non-trivia iteration regardless of scope** — their `tools:`
   posture (`Read, Grep, Glob`, #104 lock) is unchanged. Both MUST include
   `project_dir: "$project_dir"`:

```
Agent({
  subagent_type: "quality-gates:security-reviewer",
  description: "Security review (Review gate iter N)",
  prompt: "Run code-level security review on the current diff.
    project_dir: \"$project_dir\"
    diff_scope: <the review scope you resolved at step 1: session (files.md set) / branch (git diff vs base) / paths (--paths globs)>
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
    phase1_findings: <yaml from security-reviewer + Tier C specialists + codex>
    iteration: N"
})
```

   **Tier B — codex (availability-floor: 있으면 무조건, 스코프 무관).** If the codex
   reviewer is available (`detect_codex.sh` returns true), it is dispatched via
   `run_codex_reviewer.sh` this iteration **regardless of scope** — model-family
   diversity is load-bearing. It re-derives scope from the inlined diff blob (build
   that blob from the review scope you resolved at step 1) and additionally injects
   the project spec's Acceptance Criteria into its `<spec_context>` slot, resolved
   **script-internally** by `run_codex_reviewer.sh` (via `discover-spec.sh`) — so no
   `spec_path` dispatch field and no `allowed-tools` change are needed.
   `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1` empties the slot (the script reads the env
   var directly). If codex is unavailable, continue without it — scope does not change
   this.

   **Tier C — Dynamic specialists (모델이 diff 스코프로 선택; 외부 advisory agent).**
   Choose zero or more from the menu in [Reviewer composition (scope-driven)](#reviewer-composition-scope-driven)
   by matching the diff to the rubric + scope-signal palette there.
   `pr-review-toolkit:code-reviewer` is the **강한 default** (Tier C, NOT floor):
   include it on any non-trivial diff; drop it only on a quick-depth diff. Tier C
   agents are advisory — you own fixes; their output is findings YAML. Do NOT thread a
   `model:` override into their dispatch (upstream model pinning is respected).

   **Transparency (loud — 매 iteration user-visible stdout 한 줄).** Emit exactly one
   line documenting the composition, so drops/degrades are never silent:

   > `> [quality-gates] Review iter N — 선택: <디스패치한 리뷰어 목록>(근거: <스코프 신호>) / 제외: <이유 또는 "해당 신호 없음">`

   **Graceful degradation (loud).** If a Tier C candidate is unavailable
   (pr-review-toolkit / feature-dev not installed), continue with floor(A) + codex(B) +
   whatever is installed, and print:

   > `> [quality-gates] specialist <X> unavailable (<plugin> 미설치) — degraded coverage`

   Floor and codex are **not** affected by this degrade. There is **no fan-out consent
   gate** (lightness) — fan-out is bounded by the rubric's natural signal-binding, the
   transparency line above, the recomputed max fan-out declared in the README, and the
   authoring-time hard-review (CLAUDE.md fan-out ≥5 gate).
4. Dispatch `quality-gates:synthesizer` (or local synthesize_findings.py)
   to consolidate findings. **Capture the script's complete stdout** — the
   synthesized Markdown block (counts line + findings table + suggested-fixes
   list, or the empty-state line). You surface this verbatim in step 4.5; do
   NOT reformat or re-summarize it yourself (Law 1 determinism — the script,
   not the orchestrator, owns the rendering).

   **Step 4.5 — Surface findings.** Judge the boundary on the **kept
   (displayed) finding count**, read from the `**Findings:**` counts line in
   that stdout — NOT the raw reviewer count.

   **Resolved-scope file count (floor input — reuse, not a new measurement).**
   `$resolved_scope_file_count` = the file count of the scope you resolved at
   step 1: for `session` it is the same count the v2.5.0 transparency line already
   surfaced (the `files.md` items); for `branch` it is the cached
   `$branch_ahead_count`; for `paths` it is the number of `--paths` glob matches you
   resolved. If this count cannot be determined (e.g. the session `files.md` is
   unreadable), do NOT silently treat it as 0 — treat the run as `$degraded == yes`
   for the floor (the ELSE-IF branch below + loud advisory). This is an
   already-known value; do not re-measure (the orchestrator has no raw-git/grep tool).

   Three cases:
   - **kept > 0** (the counts line totals ≥ 1 across the three severities) →
     emit the captured stdout to the user as a deliberate assistant message,
     prepended with the single context line `## Review gate iter N — Findings`,
     **before** invoking the decision tool. Then go to step 5.
   - **kept = 0 AND suppressed > 0** (the synthesizer emitted the empty-state
     line `No high-confidence findings. N low-confidence findings suppressed.`
     with N > 0 — read N from that line) → no high-confidence finding to act
     on → treat as **clean**: do NOT call AskUserQuestion. Surface the single
     `No high-confidence findings…` line for transparency, then apply the
     **Honest-verdict floor** below. Then **exit the loop → [Dispatch
     Loop](#dispatch-loop) step 4** (which skips the Runtime gate
     when gate scope = Review gate only / `effective_skip_runtime`, else runs it) — do not iterate again.
   - **kept = 0 AND suppressed = 0** (the same empty-state line with N = 0) →
     apply the SAME **Honest-verdict floor** below, then exit the loop → [Dispatch
     Loop](#dispatch-loop) step 4 (which short-circuits the Runtime gate for the
     review-only path, else runs it).

   **Honest-verdict floor (deterministic — both clean sub-cases).** The floor keys
   on two deterministic inputs — `$resolved_scope_file_count` (the step-1 count above)
   and the cached `$changes_exist` (emitted by `check-review-scope.sh`, independent of
   any clean claim):
   - IF `$resolved_scope_file_count == 0 AND $changes_exist == yes`: do NOT print
     bare `clean`. Print
     `## Review gate iter N: no scope reviewed (0 files; branch <M> ahead of <base>, worktree <dirty|clean>) — NOT certified clean.`
     (`<M>` = `$branch_ahead_count`, `<base>` = `$base`, worktree token from
     `$worktree_dirty`: `yes`→`dirty`, `no`→`clean`). A zero-scope run with real changes must never read as
     "reviewed & clean".
   - ELSE IF `$degraded == yes AND $resolved_scope_file_count == 0`: print
     `## Review gate iter N: clean` AND the loud advisory
     `> [quality-gates] scope check degraded (detached HEAD / no base branch / unrelated history / shallow) — empty-scope detection skipped (fail-open; verdict not floor-protected this run).`
   - ELSE: print `## Review gate iter N: clean` exactly as before (scope > 0, or a
     genuine no-op with `$changes_exist == no` — unchanged happy path).

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

## Reviewer composition (scope-driven)

The Review gate reviewer set is composed by scope (spec §5). Selection is
**model-owned** (lightness) — there is no deterministic selector schema; scout is a
hint, not an authority. The 3-tier model:

- **Tier A — Floor** (`quality-gates:security-reviewer` + `quality-gates:adversarial`):
  스코프 무관 항상. `tools: Read, Grep, Glob` (#104 락, 무변경). 모델이 못 뺀다.
- **Tier B — codex** (availability-floor): `detect_codex.sh` 참이면 무조건, 스코프 무관.
- **Tier C — Dynamic specialists** (아래 rubric으로 diff 스코프에 맞춰 가감; 최대 6 후보):

**rubric (review-pr §4 흡수):**

| 스코프 신호 | 전문가 |
|---|---|
| 비-trivial diff 기본 | `pr-review-toolkit:code-reviewer` (강한 default; quick-depth만 drop) |
| 에러핸들링 변경 | `pr-review-toolkit:silent-failure-hunter` |
| 타입 추가/변경 | `pr-review-toolkit:type-design-analyzer` |
| 테스트 파일 변경 | `pr-review-toolkit:pr-test-analyzer` |
| docs/주석 추가 | `pr-review-toolkit:comment-analyzer` |
| 대형 구조/아키텍처 변경 | `feature-dev:code-architect` |

**depth→Tier C 크기 가이드라인 (scout 힌트, 재현성 게이트 아님):** `quick` →
code-reviewer만(또는 없음); `standard` → + 신호-매칭 전문가 1–2; `deep` → + 신호-매칭
전문가(구조 변경이면 code-architect). scout의 `phase1_agents`/`phase2_agents`는 힌트일 뿐
권위가 아니다(Retry마다 재선택).

**scope-signal 팔레트 (모델 판단 보강, 결정론 아님; `security-guidance` 카테고리 출처):**
역직렬화(pickle/yaml/torch) · 인젝션(eval/exec/os.system/subprocess-shell) ·
XSS(innerHTML/dangerouslySetInnerHTML) · crypto(createCipher/AES-ECB) · TLS-verify-disabled ·
XXE · GHA-workflow-injection · SRI · deps-manifest 변경 · migration/schema · public-API 변경 ·
삭제 파일. 이 신호가 보이면 해당 전문가(또는 code-reviewer 프롬프트 힌트)를 풍부하게 고른다.

**비-규범 예시 (illustrative only — 테스트 대상 아님; 모델이 최종 판단):**

| diff 예 | scout depth | 예상 Tier C 선택 |
|---|---|---|
| 1-파일 버그픽스 | quick | code-reviewer |
| 기능 추가(에러핸들링+테스트) | standard | code-reviewer, silent-failure-hunter, pr-test-analyzer |
| 신규 모듈(새 타입+구조) | deep | code-reviewer, type-design-analyzer, code-architect |
| 순수 docs 개편 | standard | comment-analyzer (+ code-reviewer) |

**git-history/이전-PR 렌즈**는 이미 Bash-무장된 `pr-review-toolkit:code-reviewer`가 프롬프트
힌트로 수행한다 — qg-own 에이전트는 Bash/Web을 갖지 않는다(무변경). Tier C 외부 에이전트는
write-capable(pr-review-toolkit inherit-all)이거나 read/web-only(feature-dev:code-architect)이며
모두 advisory다(오케스트레이터가 fix 소유).

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

이 게이트는 **이번 변경의 영향분**을 골라 merge_base 기준선 대비로 돌린다. 모델이
*무엇을 돌릴지* 한 번 고르고, 그 선택을 결정론이 기준선·HEAD 양쪽에서 두 번 실행해
짝짓는다 — 귀속(이 fail 은 내 탓인가)과 백스톱(결과가 조용히 비었나)이 같은
메커니즘에 얹힌다.

> **호출 주체 불변식 (load-bearing).** `run-test-selection.sh` 는 기준선 측(R4)과
> HEAD 측(R5b) **둘 다 오케스트레이터가 직접** 호출한다. `runtime-verifier` 가 자기
> 턴 안에서 테스트를 돌려 결과를 evidence-log 로 self-report 하는 경로는 **금지**다.
> verifier 의 evidence-log 에 적힌 테스트 결과는 advisory 이며, 이 스크립트의
> 오케스트레이터 호출 결과가 authoritative 다 — 둘이 다르면 후자를 쓴다. (R7 의
> mutation-guard 가 verifier 의 `writes:` self-report 를 대하는 방식과 같은 패턴.)

**Step R-init — baseline 확정.**

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/resolve-baseline.sh"
```

4키(`base` / `base_ref` / `merge_base` / `degraded`)를 캡처한다. `degraded: yes` 면
차등 실행이 불가능하므로 loud advisory 를 내고 **verdict 를 PASS 로 올리지 않는다**:

> `> [quality-gates] baseline 확정 불가 (<사유>) — 차등 귀속 없이 진행, verdict 는 PASS 불가`

**Step R1a — 러너 어댑터 감지 (HEAD 트리).**

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/run-test-selection.sh" detect "$project_dir"
```

감지된 어댑터를 **집합으로** 캡처한다(0개 이상 — 폴리글랏 레포는 복수). 각 어댑터는
`runner` / `granularity` / `setup_cmd` 3줄이다. 이 집합이 R2 산문·R4·R5b·R6 의
`--granularity` 로 스레드된다. **감지 표를 여기서 재구현하지 않는다** — 감지 지식은
그 스크립트가 단독 소유한다. 감지 0개(빈 stdout + exit 0)는 오류가 아니라 결과이며,
그 경우 floor 를 제공할 수 없다는 사실이 R8 에서 loud 하게 나온다.

**Step R1b — 영향 판정 (모델 소유) + unit 배정.**

스코프 결정은 **당신**이 한다. 아래 넷은 *입력이지 규칙이 아니다*:

| 스코프 보조 입력 | 무엇 | 신뢰 등급 |
|---|---|---|
| `compute-test-scope-candidates.sh` 후보 목록 | diff 의 src → 이름 매칭 test 파일 | **구조적** — 있으면 강한 신호, 없다고 없는 것은 아님 |
| git diff + commit message + PR description | 무엇이 바뀌었고 무엇을 **의도**했나 | **구조적** |
| 레포 CI 설정의 test-selection | CI 가 무엇을 고르는가 | **참고** — 대체 금지, 차이는 R2 산문에 한 줄 |
| `test-scope-validator` 분류 | `outdated-suspicion`/`cherry-pick-suspicion` | **부정 신호** — 그렇게 찍힌 테스트는 커버리지로 세지 않음 |

`test-scope-validator` 를 여기서 dispatch 한다 (read-only reviewer; `project_dir` 는
*preflight* 디렉토리 — 실제 diff 를 본다). Per [Reviewer dispatch contract](#reviewer-dispatch-contract):

```
Agent({
  subagent_type: "quality-gates:test-scope-validator",
  description: "Classify scope-relevant test files (Runtime gate)",
  prompt: "Validate test scope against current diff, spec acceptance criteria, and plan items.
    project_dir: \"$project_dir\"
    spec_path: <path or 'auto'; pass 'none' if DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1>
    plan_path: <path or 'auto'>
    candidate_test_files: <compute-test-scope-candidates.sh 출력>"
})
```

**빈 스코프 fail-safe**: 후보 목록이 비었다고 검증을 건너뛰지 않는다. 백엔드·설정·
인프라 변경도 앱 동작에 영향을 준다 — 영향분이 안 잡히면 그것 자체를 `gap` 차원에
기록하고, 러너 전체 실행 또는 smoke 로 폭을 넓힐지 R2 산문에 쓴다.

고른 **후보 파일 경로**를 배정 스크립트에 넘긴다. 당신이 고르는 것은 *파일*이고,
그것을 unit 으로 바꾸는 것은 스크립트다 — 파일→패키지 축약 같은 결정론 변환을
여기서 손으로 하지 않는다:

```bash
printf '%s\n' "${candidate_files[@]}" \
  | "${CLAUDE_PLUGIN_ROOT}/scripts/run-test-selection.sh" assign "$project_dir"
```

`<unit>\t<runner|unclaimed>\t<granularity>` 행을 캡처한다. stderr 의 `미실행 러너:`
줄도 함께 잡아 `gap` 차원에 열거한다. **`unclaimed` 행이 하나라도 있으면** 그 목록을
R8 의 `verification` 차원으로 가져간다 (`gap` 이 아니다 — 이유는 R8).

**Step R2 — 계획 산문 + 비용 신호.**

사람 말로 쓴다. 전문용어 나열은 산출물 실패다. 어투는 재량이지만 **여섯 필드는 필수**:

1. **무엇이 바뀌었나** — 파일 나열이 아니라 "무엇을 하는 코드가"
2. **어떤 행동에 닿나** — 행동/경로를 이름으로 지목
3. **무엇을 돌리나 + 선택 비율** — `영향 테스트 12개 선택 (전체 47개 중)` 형태.
   분모는 반드시 `compute-test-scope-candidates.sh --total` 의 출력이다 —
   당신이 센 값이 아니다. 분모가 모델 자기보고이면 과선택이 심해질수록 분모도 같이
   부풀려 비율이 정상으로 보인다.
4. **비용 신호** — `즉시`(캐시 전량 적중·설치 불필요) / `수 분`(기준선 실행 필요·
   설치 불필요) / `설치 포함`(deps 설치 필요) 셋 중 하나. **숫자 시간 추정을 쓰지
   않는다** — 추정기가 없으므로 지어낸 숫자가 된다.
5. **무엇을 안 돌리나** — 미선택분 · 자동화 불가 플로우 · blocked 표면 · `unclaimed`
   · `미실행 러너`
6. **CI 와 다르면 그 차이** — 한 줄. 대체하지 않고 설명만 한다.

`granularity: bulk` 어댑터가 하나라도 있으면 이 산문에 **항상** 다음을 넣는다:

> `커버리지 미보장(러너가 선택을 무시함)`

`assign` 이 낸 `BULK` 행 — 어느 파일 어댑터도 주장하지 않은 잔여를 bulk 러너가
흡수한 결과 — 도 같은 공시 대상이다. 흡수자는 정의상 bulk 어댑터이고, 그 실행은
파일 지목 없이 러너 전체를 돌린다. 잔여 흡수는 언어를 가리지 않으므로
(`.rb`·`.java` 같은 미지원 확장자도 흡수된다) 공시를 "원래 bulk 인 러너"에만
붙이면 흡수분이 조용히 공시 없이 돈다.

그리고 정확히 한 줄의 scope transparency 앵커를 emit 한다:

> `> Runtime scope: 영향 테스트 <N>개 선택 (전체 <M>개 중), 러너 <runners> — 이번 변경의 영향분만 기준선 대비로 돌린다.`

**Step R3 — 갭 게이트 (생략이 있을 때만).**

R2 의 5번이 곧 생략 목록이다. **생략 목록이 비어 있으면 `AskUserQuestion` 을 발화하지 않는다** — 계획 한 줄만 출력하고 zero-click 으로 R4 로 간다.

비어 있지 않으면 정확히 1회 `AskUserQuestion`: 생략 목록을 보여주고
`그대로 진행` / `범위 넓혀서 다시 계획` / `중단`. 질문 빈도가 생략의 양에
비례하므로, 질문이 뜰 때는 반드시 정보가 있다.

**Step R4 — 기준선 측 (오케스트레이터 단독 — verifier 미개입).**

`degraded: yes` 면 이 스텝 전체를 건너뛰고 R8 에서 `BASELINE_UNRUNNABLE` 로 처리한다.
건너뛸 때 기준선 행 파일은 **비우지 않고** 선택한 unit 마다 `<unit>\tunrun\t-` 로
채운다 — 빈 파일을 R6 에 넘기면 행 부재가 `SILENT_DROP` 으로 라벨된다. 둘 다 PASS 는
아니지만 보고되는 사유가 달라진다(기준선을 못 돌린 것 vs 고른 것이 사라진 것).

① 캐시 조회 — 어댑터마다:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/baseline-cache.sh" get \
  ".claude/quality-gates/baseline-cache" "$merge_base" "$runner" "${units[@]}"
```

적중분만 나온다. 입력 목록과 차집합해 **미적중분**을 얻는다. exit 4(손상)는 전량
미적중으로 취급하고 loud advisory 를 낸다.

② 미적중분이 있을 때만 기준선 워크트리를 만든다:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" create-baseline "$merge_base" "<session-id>"
```

그 트리에서 **`detect` 를 다시 실행한다 — HEAD 의 어댑터 집합을 재사용하지 않는다.**
diff 가 테스트 인프라 자체를 바꾸는 경우(unittest→pytest 마이그레이션, `package.json`
에 jest 신규 추가) 두 집합이 다를 수 있고, HEAD 감지를 기준선에 그대로 쓰면 spurious
`error` 가 나와 진짜 회귀를 `PRE_EXISTING` 으로 은폐한다. 두 집합이 다르면 한쪽에만
있는 어댑터의 unit 은 반대편에서 `unrun` 이 되어 귀속이 degrade 되고, 그 사실을 R2
산문과 `gap` 에 명시한다.

그다음 어댑터마다:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/run-test-selection.sh" run \
  "$baseline_wt" "$runner" bulk "${miss_units[@]}"
```

bulk 가 red 면 실패한 unit 에 대해서만 `per-unit` 으로 재실행한다 (2단 구조).

③ 결과를 캐시에 기록하고 기준선 워크트리를 폐기한다:

```bash
printf '%s\n' "${rows[@]}" | "${CLAUDE_PLUGIN_ROOT}/scripts/baseline-cache.sh" put \
  ".claude/quality-gates/baseline-cache" "$merge_base" "$runner"
"${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" remove "$baseline_wt"
```

`granularity ∈ {file, package}` 에서 bulk-green 이 나오면 **unit 별 `pass` 행으로
분해해** 기록한다 — 집합 전체가 통과했으므로 각 unit 이 통과했다. `BULK` 키는
`granularity: bulk` 어댑터에서만 생긴다.

**R4 가 R5 보다 먼저인 이유** — 기준선 실행이 HEAD 샌드박스와 **다른 트리에서,
verifier 개입 없이** 끝나야 한다. 같은 트리에서 코드를 되감았다 복원하면
mutation-guard 의 의미가 흐려지고, verifier 가 기준선을 조작해 진짜 회귀를
`PRE_EXISTING` 으로 위장할 수 있는 경로가 생긴다.

**Step R5a⁰ — Runtime-scope inputs (every path that reaches this gate).** The R5a³
dispatch requires `manifest`, `approved_surfaces`, and `block_policy`. The
full-pipeline `Run both gates` / `gate=both` path produced them in
[Decision 2](#decision-2--runtime-scope--block-policy-conditional). **Single-gate
`/qg runtime` bypassed the Dispatch Loop, so if `approved_surfaces` / `block_policy`
are still unset on entry here, produce them now**: run
`${CLAUDE_PLUGIN_ROOT}/scripts/detect-runtime.sh` to get the `manifest`, then apply
Decision 2's firing logic on the result — fire the runtime-scope `AskUserQuestion`
only if ≥1 `requires_decision` surface exists and no surface-selection arg
pre-answers it; otherwise zero-click with the automatic test runners as
`approved_surfaces` and a default `block_policy=skip`. (`gate=runtime` pre-answers
gate scope, NOT surface selection — same as main; spec §3 Non-goal preserves
single-gate behavior.) After this step `manifest` /
`approved_surfaces` / `block_policy` are guaranteed defined for R5a³. If Decision 2
already ran (gate scope = both), this step is a no-op.

> **매니페스트의 `test_runners` 필드는 이 게이트의 실행 경로에서 소비되지 않는다.**
> 매니페스트는 **부팅 표면**(`runnable_surfaces` / `approved_surfaces`)만 정하고,
> 실행할 테스트 러너 식별은 R1a 가 소유한다. 두 집합이 다른 것은 결함이 아니라 축이
> 다르기 때문이다.

**Step R5a¹ — Create the sandbox (or fall back).** Seal the code-under-review into
a disposable git-worktree:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" create-sandbox "<session-id>"
```

- Exit 0 → capture **line 1 = `sandbox_dir`**, **line 2 = `baseline_sha`**, **line 3
  = `snapshot_digest`**. Parse contract (fixed): read exactly three lines with three
  successive `IFS= read -r` and strip trailing whitespace/CR from `snapshot_digest`
  (`tr -d '[:space:]'` or equivalent) — a stray newline/space in the hex makes the
  guard fail-closed on every run. Hold all three as orchestrator variables
  (verifier-unreachable). Set `runtime_project_dir = sandbox_dir`.
- **Exit 3** (kill switch `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1`) → graceful fallback
  (no sandbox): set `runtime_project_dir = project_dir`. The verdict is **capped at
  SKIP_WITH_EVIDENCE — never PASS** (no sandbox = no structural Law-2 guarantee = no
  certification). BEFORE the R5a³ dispatch, capture `fallback_pre` = `git -C
  "$project_dir" status --porcelain --untracked-files=all` plus a tracked content
  tree-hash baseline. Print: `> [quality-gates] runtime sandbox disabled — read-only
  smoke mode on the real tree; verdict capped at SKIP_WITH_EVIDENCE
  (DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1).`
- Any other non-zero → surface stderr verbatim and mark the Runtime gate failed.

**Step R5a² — gather spec Acceptance Criteria.** Resolve the spec (reuse
`discover-spec.sh` semantics) and build `spec_acceptance_criteria` as a
`{ac_id, text}` list. If no spec, pass an empty list (the verifier falls back to
plan_features → smoke).

Also derive `evidence_dir = "$project_dir/.claude/quality-gates/$CLAUDE_CODE_SESSION_ID/"`
(the preflight main-repo `project_dir`, NOT the sandbox — so it survives the R9
sandbox discard).

**Step R5a³ — dispatch runtime-verifier (executor).** 이 dispatch 는 **판단이 필요한
것만** 맡는다: 앱 부팅용 setup fix · 상황별 부팅 · 브라우저/CLI 플로우. **테스트 실행도,
테스트 러너용 deps 설치도 여기 없다.**

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

**Step R5b — HEAD 측 테스트 실행 (verifier 턴 *종료 후*, 오케스트레이터가 직접).**

verifier 의 dispatch 가 **끝난 뒤**, 어댑터마다:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/run-test-selection.sh" run \
  "$runtime_project_dir" "$runner" bulk "${units[@]}"
```

**bulk 가 green 이면 per-unit 재실행을 하지 않는다** — 집합 전체가 통과했으므로 귀속할
것이 없다. red 일 때만 실패한 unit 에 대해 `per-unit` 으로 재실행한다. 흔한 경우 2회,
비싼 경우에만 정밀해진다.

이 호출은 R5a³ 의 `Agent({…})` 블록 **밖**에 있어야 한다 — 위 호출 주체 불변식.
verifier 가 디버깅 중 테스트를 돌리는 것 자체를 막지는 않지만(Bash 를 갖고 있고 setup
확인에 필요하다), **그 결과가 판정에 들어가는 경로**를 막는다. verifier 의 evidence-log
테스트 결과는 advisory 이고 이 호출 결과가 authoritative 다.

**Step R6 — 대조 (결정론).** 어댑터마다 한 번씩:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/diff-test-results.py" \
  --expected "$expected_units_file" \
  --baseline "$baseline_rows_file" --head "$head_rows_file" \
  --granularity "$granularity" --runner "$runner" > "$per_adapter_yaml"
```

`--expected` 는 R1b 가 고른 unit 목록이다 — **두 산출물의 상호 대조가 아니라 독립
입력**이라야 두 스크립트가 같은 정규화 버그로 같은 unit 을 대칭 누락할 때 잡힌다.

**flaky — 재실행은 정확히 1회다 — green 이 나올 때까지가 아니다.** `NEW_REGRESSION`
후보만 HEAD 에서 1회 재실행한다. 또 fail 이면 확증 `NEW_REGRESSION`, pass 면 `FLAKY`
로 기록하고 게이트를 FAIL 시키지 않되 **보고서에 올린다**. 기준선에서 이미 red 인 것은
재실행 대상이 아니다(이미 `PRE_EXISTING`). 재실행 후에는 갱신된 `--head` 로
`diff-test-results.py` 를 다시 호출하고, **그 마지막 호출의 결과가 authoritative** 다.
여기서 위험은 false green 이 아니라 false red 이고, **무한 재실행이 바로 false green
경로**이므로 1회로 잠근다.

그다음 어댑터 YAML 들을 집계한다:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/diff-test-results.py" --aggregate \
  --expected-adapters "$adapter_count" "${per_adapter_yamls[@]}"
```

`verdict_input`(`confirmed_product_defect` / `silent_drop` / `baseline_unrunnable`)과
`attribution_status` 를 캡처한다. 이 집계를 손으로 하지 않는다 — N 개 YAML 을 읽고
최악값을 고르면 불변식 ②가 결과값에서 없앤 "모델 요약이 판정을 결정"이 집계 레이어에서
재입장한다. 입력 개수가 안 맞으면 스크립트가 exit 4 로 fail-closed 한다.

**Step R7 — Mutation guard (authoritative verdict cap).** Unless in read-only
fallback, compute the product-mutation oracle:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" mutation-guard "<sandbox_dir>" "<baseline_sha>" "<snapshot_digest>"
```

Read the YAML. **If `forced_downgrade: yes`**, the verdict is capped at FAIL
regardless of the verifier's emitted verdict (Law 2 — the verifier cannot
self-approve a product change). Surface `tracked_diff` + `disallowed_new_files` as
evidence. The verifier's own `writes:` self-report is advisory only; this git result
is authoritative.

**R7 exit-code routing (an indeterminate guard is never a PASS).** Capture BOTH the
guard's stdout YAML AND its exit code:

| Guard result | R7 routing |
|---|---|
| exit 0 + `forced_downgrade: no` | no product mutation → proceed to R8 normally |
| exit 0 + `forced_downgrade: yes` | cap verdict at FAIL; surface `tracked_diff` / `disallowed_new_files` / `guard_flags` as evidence |
| **exit 4** (`guard_fail`), OR any other non-zero exit, OR a missing/invalid `forced_downgrade` key, OR a `guard_error:` line present | treat as `forced_downgrade: yes` → cap verdict at FAIL; surface the guard's `guard_error` + **stderr verbatim**; mark the Runtime gate failed. **Never read an errored or garbled guard as PASS** (indeterminate ≠ clean). |

A digest mismatch (the verifier forged the snapshot) surfaces here as **exit 4** with
`guard_error: snapshot integrity check failed` — the seal the guard checks is held by
the orchestrator, out of the verifier's reach.

**Fallback working-tree guard (read-only mode only).** When the sandbox was disabled
(Exit 3), do NOT run the sandbox `mutation-guard`. The verdict is already capped at
SKIP_WITH_EVIDENCE (R5a¹); this guard is a pure SAFETY SIGNAL, not a verdict input.
After the R5a³ dispatch, recompute `fallback_post`. If anything changed, emit a loud
warning to user-visible stdout AND record it in `evidence_dir`:
`> [quality-gates] WARNING: runtime fallback 에서 working tree 가 변경됨 — <changed files>. sandbox 미사용으로 구조적 보호 없음; 검토 요망 (git diff 후 revert 권장).`
git-ignored files do not appear in `--porcelain`, so a setup-only `.env` fix is
correctly NOT flagged. The warning does not change the verdict and does not block
the gate.

**Step R8 — 원장 + verdict + outcome routing.**

evidence-log — verifier 가 R5a³ 에서 쓴 `$evidence_dir/runtime-evidence.md`, 없으면
같은 경로로 새로 만든다 — 에 floor 5차원 원장을 이어 쓴다 (spec-distill 커버리지
원장과 같은 줄 모양):

```
- floor:changed      — closed   — <무엇이 바뀌었나; 러너 특정>
- floor:behavior     — closed   — <어떤 행동/경로에 닿나>
- floor:verification — closed   — <실행된 것 + 실행 방식(차등/bulk)>
- floor:attribution  — closed   — <모든 fail 의 귀속 라벨>
- floor:gap          — closed   — <못 확인한 것 전부 열거 (0개면 "없음"도 명시)>
- derived: 없음 — <왜 0개인지>
```

`degraded` 는 실패가 아니라 **1급 상태**다. 다음 라우팅으로 status 를 정한다:

| 못 확인한 것 | 원장 | PASS |
|---|---|---|
| **영향분**을 못 돌림 (러너 부재 exit 3 · baseline 불가 · 귀속 불가 · `unclaimed` 존재) | `verification` 또는 `attribution` 이 **`degraded`** | **불가** |
| **영향분과 무관한** 표면을 안 돌림 (다른 러너 부재 · 자동화 불가 플로우 · 미선택분 · `미실행 러너`) | `gap` 에 **열거하고 `closed`** | 가능 |

R6 이 낸 `attribution_status` 를 그대로 `floor:attribution` 의 status 로 옮긴다 —
집계값을 원장에 안 옮기면 그 캡처는 아무 데도 닿지 않는다. verdict 입력은
`verdict_input` 3플래그와 `attribution_status` 뿐이며, `per_adapter` 카운트는 사람이
읽을 진단이다 — verdict 를 그리로 라우팅하지 않는다.

`gap: closed` 와 `verification: degraded` 는 다른 뜻이다 — `gap` 은 *"못 확인한 것을
빠짐없이 열거했다"* 이므로 열거가 곧 닫힘이고, `degraded` 는 *"확인하기로 한 것을 못
확인했다"* 이므로 인증 불가다.

> **`unclaimed` 가 하나라도 있으면 `verification: degraded` 이고 verdict 를 PASS 로 올리지 않는다.**
>
> 목록은 `gap` 에도 열거하되, **열거가 인증을 대신하지 않는다.** `unclaimed` unit 은
> 정의상 R1b 가 **영향분으로 판정한** 것이고, 실행 수단이 없다는 것은 위 표의
> "영향분을 못 돌림"을 만족한다. 이 규칙이 없으면 8종 미지원 레포에서 **테스트가 한
> 개도 안 돈 채 PASS** 가 나온다.

구조 게이트를 돌린다:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/check_qa_ledger.py" "$evidence_dir/runtime-evidence.md"
```

non-zero 면 stderr 를 verbatim 으로 노출하고 **verdict 를 PASS 로 올리지 않는다**.

verdict 결정:

| verdict | 조건 |
|---|---|
| `PASS` | floor 5차원 전부 `closed` **and** `confirmed_product_defect: false` **and** `silent_drop: false` **and** `forced_downgrade: no` **and** 상황별 층 통과 |
| `FAIL` | `confirmed_product_defect: true` **or** `forced_downgrade: yes` **or** 상황별 층(부팅/플로우) 실패 |
| `SKIP_WITH_EVIDENCE` | 영향분 0개 → `SKIP_WITH_EVIDENCE` **or** `baseline_unrunnable: true` **or** `silent_drop: true` **or** 어느 floor 차원이 `degraded` |
| `NEEDS_RESOLUTION` | setup-fixable 잔존 — **기존 무변경** |

**동시 성립 시 총 순서** (표의 행은 배타가 아니다):

```
확증 제품결함(FAIL, terminal)  >  NEEDS_RESOLUTION  >  SKIP_WITH_EVIDENCE  >  PASS
```

- **확증 제품결함**(`confirmed_product_defect: true` · `forced_downgrade: yes`)은
  **terminal** 이며 어떤 degrade 사유로도 downgrade 되지 않는다. `silent_drop` 이나
  floor degraded 가 같이 성립해도 verdict 는 `FAIL` 이다.
  그리고 **degrade 사실은 원장과 보고서에 함께 기록된다** — 삼켜지지 않는다.
- 그 외의 FAIL 사유(부팅 실패 등)와 `NEEDS_RESOLUTION` 이 동시면 `NEEDS_RESOLUTION`
  이 이긴다 (기존 `runtime-verifier.md` 선례 승계).
- **어느 방향으로도 degrade 사유가 PASS 를 만들지 못하고, degrade 사유가 확증 결함을
  지우지도 못한다.**

`granularity: bulk` 어댑터가 실행됐으면 최종 보고서에도 **항상**
`커버리지 미보장(러너가 선택을 무시함)` 을 남긴다 — 그 실행의 주장은 "영향분을
확인했다"가 아니라 "러너 전체를 돌렸고 그 안에 영향분이 포함되기를 기대한다"이다.
양쪽 red 인 bulk 어댑터에는 다음을 그대로 쓴다:

> `기준선도 빨간 상태입니다. 이 러너(<runner>)는 파일 단위 지목이 안 되므로 그 안에 새 회귀가 숨었는지 구분하지 못했습니다.`

**Outcome routing** (verdict = min(위 verdict, guard cap, fallback cap)):

- **Fallback mode (sandbox disabled)** → a `PASS` becomes **SKIP_WITH_EVIDENCE**;
  `FAIL`/`NEEDS_RESOLUTION` pass through unchanged.
- **Clean (PASS) AND `forced_downgrade: no`** → print `## Runtime gate — clean` and
  continue to final summary.
- **`forced_downgrade: yes`** → print the Runtime gate FAIL block including the
  surfaced diff; emit final summary marked Runtime gate failure. Do NOT auto-restart,
  do NOT apply the diff.
- **FAIL** → print verdict block (귀속 표 + 원장 포함); final summary marked failure.
- **SKIP_WITH_EVIDENCE** → print evidence (원장 포함); continue.
- **NEEDS_RESOLUTION** → invoke [Runtime NEEDS_RESOLUTION decision](#runtime-needs_resolution-decision).

**Publish-eligible sentinel (single-gate `/qg runtime` — non-aborted terminal
only).** `/qg runtime` 은 Dispatch Loop 를 우회하므로 Final Summary 기록 지점에
도달하지 않을 수 있다. R8 이 **비중단 terminal**(clean / `forced_downgrade: yes` /
FAIL / SKIP_WITH_EVIDENCE)로 종결하면 여기서
`.claude/quality-gates/<sid>/publish-eligible.md` 에 [Publish-eligible
sentinel](#publish-eligible-sentinel)을 `Write` 한다(`<verdict>` = 그 R8 verdict
token). **NEEDS_RESOLUTION → Stop 및 사용자 Stop 경로에서는 쓰지 않는다.** Final
Summary 도 도달했다면 idempotent overwrite 라 무해.

**Step R9 — Discard the sandbox** (verdict-independent), unless in read-only fallback:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" remove "<sandbox_dir>"
```

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
- **Yes, retry** → increment resolution counter; if exceeds env limit, fall through to Skip with evidence. Otherwise re-create the sandbox (Step R5a¹) and re-capture the new output's `sandbox_dir` (line 1), `baseline_sha` (line 2), and `snapshot_digest` (line 3) with the same three successive `IFS= read -r` + digest-strip idiom as R5a¹ — refreshing **all three** orchestrator variables. create-sandbox emits a NEW commit `B` AND a NEW snapshot (hence a new digest) each call, so reusing the old `baseline_sha` makes the guard `guard_fail "bad baseline sha"` and reusing the old `snapshot_digest` makes it `guard_fail "snapshot integrity check failed"` — both false FAILs. The new snapshot is auto-recorded in the new gitdir; the stale sandbox + its old snapshot are force-removed by R5a¹'s idempotent cleanup. Then re-dispatch runtime-verifier with the refreshed `sandbox_dir`, and call R7 as 3-arg with the refreshed `snapshot_digest`. (Fix the parse order: capturing the digest as line 2 swaps `baseline_sha`/`snapshot_digest` and fails-closed every run.)
- **Skip with evidence** → record SKIP_WITH_EVIDENCE and continue.
- **Stop** → final summary aborted at the Runtime gate.

## Publish-eligible sentinel

비중단 완료 시, 커맨드 계층이 읽을 fail-safe sentinel을 `Write`한다. **두 종결
지점**(Final Summary, Runtime R8)이 이 포맷을 공유한다 — 재정의 말고 여기를 참조.

- **경로:** `.claude/quality-gates/<sid>/publish-eligible.md` (`<sid>` =
  `$CLAUDE_CODE_SESSION_ID`, state file과 동일). setup-qg.sh가 Preflight마다
  stale 사본을 지우므로(Preflight P2), 이 파일의 존재 = **이번 run**의 비중단 완료.
- **내용 (정확히 2줄):**
  ```
  <!-- qg-publish-eligible:v1 -->
  verdict: <terminal 게이트 verdict 토큰>
  ```
  1번째 줄은 고정 마커(커맨드의 유효성 검사). `<verdict>`는 방금 렌더한 terminal
  게이트 토큰(`clean` / `proceeded-with-findings iter N` / `failed` /
  `SKIP_WITH_EVIDENCE` / `no scope reviewed …`)을 그대로 — offer 문구에 삽입된다.
- **disposition 가드 (§5-A):** `## Final Summary`는 게이트별 셀을 독립 렌더한다
  (`Review gate\t<token>` / `Runtime gate\t<token>`). **disposition = `aborted`
  iff 어느 한 셀 token이 리터럴 `aborted`로 시작**(Review `aborted iter N` /
  Runtime `aborted`). disposition = aborted면 **sentinel을 쓰지 않는다.** 그 외
  (clean/proceeded-with-findings/failed/skipped/SKIP_WITH_EVIDENCE)는 non-aborted
  → 쓴다.
- **Write는 idempotent** — 같은 경로 overwrite. 한 실행이 Final Summary와 R8에
  모두 도달해도 동일 sentinel을 다시 쓸 뿐(무해).

## Final Summary

Build the status rows and render them (deterministic, scannable) — one
`key<TAB>value` line per gate, verdict vocabulary unchanged (`clean iter N`,
`no scope reviewed (branch <M> ahead)`, `proceeded-with-findings iter N`,
`aborted iter N`, `skipped`, `clean`, `failed`, `SKIP_WITH_EVIDENCE`):

```bash
printf 'Review gate\t<clean iter N | no scope reviewed (branch <M> ahead) | proceeded-with-findings iter N | aborted iter N | skipped>\nRuntime gate\t<clean | failed | SKIP_WITH_EVIDENCE | aborted | skipped>\n' \
  | ${CLAUDE_PLUGIN_ROOT}/scripts/render-terminal.py table --title "Quality Gates — Complete"
```

Then print the appended `## History` lines from the state file as an
indented tree beneath the table.

**Publish-eligible sentinel (non-aborted completion only).** 위 두 게이트 셀
token을 검사한다. **어느 셀이든 리터럴 `aborted`로 시작하면 disposition =
aborted → sentinel을 쓰지 않는다**(사용자 Stop). 그 외에는
`.claude/quality-gates/<sid>/publish-eligible.md`에 [Publish-eligible
sentinel](#publish-eligible-sentinel) 포맷으로 `Write`한다 — `<verdict>`는 이
요약의 terminal 게이트 token(Runtime을 돌렸으면 Runtime 셀, review-only면
Review 셀). 이 Write가 커맨드 계층 offer를 arm한다.

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
