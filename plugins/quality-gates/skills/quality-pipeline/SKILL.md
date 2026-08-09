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
   - [Runtime gate](#runtime-gate) — test-scope-validator + runtime-verifier
3. **Decision points (AskUserQuestion templates):**
   - [Review iter boundary decision](#review-iter-boundary-decision)
   - [Review max-iter decision](#review-max-iter-decision)
   - [Runtime NEEDS_RESOLUTION decision](#runtime-needs_resolution-decision)
4. **Output templates** (verbatim, field substitution):
   - Review / Runtime result templates
   - [Publish-eligible sentinel](#publish-eligible-sentinel) — fail-safe write contract shared by Final Summary + Runtime R6
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

   **Capture the runner's exit code.** `run_codex_reviewer.sh` normally exits 0 and
   always writes YAML to the output path you gave it — with one exception: if it
   cannot write that path at all (unwritable directory/permissions/RO mount), it
   exits **3** instead, having already printed a loud diagnostic to stderr. On
   `rc == 3`, delete the output file before reading anything from it
   (`rm -f <output_path>`) — otherwise a prior iteration's YAML (which may carry a
   false-positive `codex_failed: false`) sits untouched and is read as this
   iteration's codex verdict. This mirrors `run_brief_codex_reviewer.sh`'s identical
   exit-3 contract, whose caller (`spec-distill`'s `reviewing-brief` SKILL) already
   implements the same `if rc == 3: rm -f` pattern.

#### Codex skip 안내

`detect_codex.sh`가 false를 내면 그 사유를 사용자에게 보인다. codex는 부가 기능이
아니라 **P11(cross-model adversarial)을 코드로 집행하는 구조 메커니즘**이다 — 철학이
집행 파일로 `run_codex_reviewer.sh`를 명시한다. 그러므로 배너는 "codex 없음"이 아니라
**"이 리뷰에는 모델 다양성이 없었다"**를 말해야 한다.

kill switch는 `DEVBREW_DISABLE_QG_CODEX=1`이다. 이 게이트는 현재 **산문**이며 모델이
detect를 돌린다 — 리터럴 bash 게이트로의 전환은 이 사이클 범위 밖이고,
`test_codex_gate_observation.sh`의 UNGATED 원장에 사유와 함께 등재돼 있다.

**visible (사용자가 조치할 수 있다 — 배너로 보인다):**

| skip_reason | 사용자에게 보이는 문구 |
|---|---|
| `not_installed` | Codex CLI not installed — `npm i -g @openai/codex` |
| `auth_missing` | codex auth missing — `codex login` 또는 `CODEX_API_KEY` |
| `timeout_binary_missing` | no `timeout`/`gtimeout` on PATH — `brew install coreutils` |
| `known_bad_version` | version known-bad (0.120.0/1/2 stdin deadlock) — 업그레이드 필요 |
| `version_below_floor` | version_below_floor — stdin prompt(`codex exec -`)는 0.118.0 이상이 필요하다 |
| `version_unreadable` | version_unreadable — `codex --version`에서 semver를 읽지 못했다 |

배너 문구:

> `[quality-gates] codex 리뷰 미실행 (<사유>) — 이 리뷰에는 모델 다양성이 없었다 (degraded).`

**silent (사용자 조치 대상이 아니다 — 배너를 내지 않는다):**

| skip_reason | 왜 조용한가 |
|---|---|
| `kill_switch` | 사용자가 직접 껐다. 자기가 한 일을 다시 알릴 필요가 없다 |
| `inside_codex_sandbox` | 이미 codex 안이다. 재귀 방지이지 결손이 아니다 |

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
   transparency line above, and the recomputed max fan-out declared in the README.
   (A repo-wide `fan-out ≥5` hard-review gate was **removed** from CLAUDE.md and the philosophy doc by the harness-capability-suppression sweep — it is no longer a backstop and must not be cited as one.)
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

   **Dropped-finding override (applies to BOTH clean sub-cases, before the floor).**
   If the captured stdout contains a line matching `dropped as malformed`, you MUST
   surface that line verbatim **in addition to** the empty-state line, and you MUST
   NOT print a bare `clean` verdict. Print instead:
   `## Review gate iter N: not clean — <D> finding(s) dropped as malformed (unjudged).`
   (`<D>` = the count from that line.) Then continue to step 5's decision tool as if
   findings remained.

   Why this clause exists: the synthesizer emits that notice — whose own text reads
   `**이 실행은 clean이 아니다**` — precisely because a malformed finding may have
   carried a real CRITICAL that was never judged. Before this clause, step 4.5 keyed
   only on the counts line and the `No high-confidence findings…` line, so the notice
   was produced by the script and then discarded by its only consumer: the gate
   printed `clean` over dropped CRITICAL claims (2026-08-05 `/qg` 라운드 2 적발 —
   생산자만 고치고 소비자를 안 고친 반쪽 수정). A finding that was thrown away is not
   a finding that was cleared. This mirrors the Runtime gate's `indeterminate ≠ clean`
   rule at [Step R4](#runtime-gate).

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

**Runtime scope transparency (additive — AC11).** Emit exactly one user-visible
line here (Step R2 complete → before the R3 dispatch), now that the
manifest, approved surfaces, and spec AC are all known:

> `> Runtime scope: full project (<project_type>) — boots <surface summary>, asserts <K> spec AC. Runtime runs the whole app regardless of Review scope.`

Substitute `<project_type>` and `<surface summary>` from the `detect-runtime.sh`
manifest (`project_type` + a short `runnable_surfaces` / `test_runners` digest);
`<K>` = the number of `spec_acceptance_criteria` gathered in Step R2 (`0 spec AC (smoke fallback)`
when none). The final clause is the OQ4 asymmetry marker (literal — do not
paraphrase; it is the unique `grep -cE` anchor for this emission point). This is the ONLY emission point — every path that reaches the Runtime
gate (both-gates and single `/qg runtime`) flows through R3, so one line covers
them all; the Review-gate-only path never reaches here (correct — there is no
Runtime to describe). This is purely additive: no new gate, no diff-scope forcing,
no behavior change (NG3 / AC12).

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

**Publish-eligible sentinel (single-gate `/qg runtime` — non-aborted terminal
only).** `/qg runtime`은 Dispatch Loop를 우회하므로(위 [Arguments](#arguments))
Final Summary 기록 지점에 도달하지 않을 수 있다. R6이 **비중단 terminal**
(clean / `forced_downgrade: yes` / FAIL / SKIP_WITH_EVIDENCE)로 종결하면 여기서
`.claude/quality-gates/<sid>/publish-eligible.md`에 [Publish-eligible
sentinel](#publish-eligible-sentinel)을 `Write`한다(`<verdict>`
= 그 R6 verdict token). **NEEDS_RESOLUTION → Stop 및 사용자 Stop 경로에서는 쓰지
않는다**(abort → offer 미발동). Final Summary도 도달했다면 idempotent overwrite라
무해.

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

## Publish-eligible sentinel

비중단 완료 시, 커맨드 계층이 읽을 fail-safe sentinel을 `Write`한다. **두 종결
지점**(Final Summary, Runtime R6)이 이 포맷을 공유한다 — 재정의 말고 여기를 참조.

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
- **Write는 idempotent** — 같은 경로 overwrite. 한 실행이 Final Summary와 R6에
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
