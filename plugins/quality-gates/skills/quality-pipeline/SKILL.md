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
  # 비-플러그인 명령 중 **항목을 가진 유일한 것**. R-init 이 오케스트레이터 소유 중간 파일
  # 6종의 집을 만든다 (AC69). 레포 안에 두면 `create-sandbox` 가 커밋 `B` 로 봉인하므로
  # (`ls-files --others --exclude-standard` 로 미추적·비-ignore 파일을 샌드박스로 복사한다)
  # 반드시 트리 밖이어야 하고, 그러려면 이 한 명령이 필요하다.
  #
  # **"목록에 없는 셸 명령이 하나도 없다"는 뜻이 아니다 (정정).** 이 SKILL 의 fenced 블록은
  # 항목 없는 맨 셸 유틸리티를 여럿 실행한다 — `pwd`(Step P0, 모든 `/qg` 실행) · `printf` ·
  # `echo` · `exit` · `cd` · `set` · `mv` · `case` · `[[` · `git`(R-init 담김 가드). 그런데도
  # `pwd` 는 여러 릴리스에 걸쳐 permission stop 없이 돌아왔다 — 즉 **fenced 블록의 맨 셸
  # 유틸리티가 항목을 필요로 하는지 자체가 미측정**이다. 여기에 **개수를 적지 않는다**:
  # 앞 판본은 넷을 세어 적었고 같은 커밋의 R-init 편집이 그 census 를 바로 어긋나게 만들었다
  # (§11 ㉜ · F12). 항목을 늘리지 않는 이유: 실측되지 않은 위험을 대가로 `Bash(mv:*)` 같은
  # 넓은 grant 를 사는 것은 도구 표면 양보다. 판정은 예정된 Runtime 실측이 낸다 — 그 관측은
  # `pwd` 처럼 **대입 안의 명령 치환**인 모양과 `[[ … ]] && <script>` 처럼 **맨 빌트인이 선두**
  # 인 모양을 함께 봐야 한다(후자는 릴리스 증거가 아예 없다).
  - Bash(mktemp:*)
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

# Quality Gates — In-Turn Orchestrator (v3.0.0)

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
2. **Gate firing condition (mechanical):** fire an `AskUserQuestion` **only if** the manifest has ≥1 surface with `requires_decision: true` AND no argument already pre-answers the *surface selection*. `gate=both` answers **gate scope only** — it does NOT pre-answer runtime scope, so Decision 2 still fires for `/qg both` when a `requires_decision` surface exists (matching bare `/qg` runtime behavior). Otherwise (no boot surface at all / surface-arg-answered) print a one-line plan and proceed **zero-click** with `approved_surfaces` empty. **Every kind in `runnable_surfaces` now carries `requires_decision: true`** — since v3.0.0 the manifest holds boot surfaces only, and test runners are no longer surfaces at all (they are the orchestrator's, run in R4/R5b outside the verifier's turn). So "zero-click" here means *there was nothing to boot*, not *there were automatic surfaces*.
3. When firing, confirm in ONE question: **runtime scope** (which `requires_decision` surfaces to opt into) and **block policy** (`stop` / `skip` / `ask`). Record the opted-in surfaces as `approved_surfaces` and the chosen `block_policy`.

```
AskUserQuestion({
  questions: [
    {
      question: "Runtime scope: these surfaces can start processes or reach outside (requires_decision): <list>. Which should I run, and what should I do if one stays blocked after setup retries?",
      header: "Runtime scope",
      options: [
        {label: "Run all + skip blocked", description: "Opt into all listed surfaces; block_policy=skip (SKIP_WITH_EVIDENCE, continue)."},
        {label: "Run all + ask on block", description: "Opt into all; block_policy=ask (mid-run question, bounded by DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS)."},
        {label: "Boot nothing",            description: "Skip every requires_decision surface. The Runtime floor (R4/R5b differential test run) still runs — it is the orchestrator's, not the verifier's."},
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

**감지기 실행 자체가 실패한 경우는 위 표와 다른 사실이다.** 정상 실행된 `detect_codex.sh`는
`codex_available: false`여도 항상 위 표의 `skip_reason` 중 하나를 함께 낸다. `detect_codex.sh`를
돌렸는데 비-zero exit이거나 출력에 `codex_available:` 줄이 아예 없으면, 그것은 "codex가 없다"가
아니라 **감지기 자체가 안 돈 것**이다 — `plugins/quality-gates/scripts/detect_codex.sh`는
`shared/codex/detect_codex.sh`를 가리키는 상대 심볼릭 링크라 끊길 수 있다. 그 사유를
`not_installed` 등 위 표의 값이나 `unknown`으로 뭉개지 말고 **`detector_not_runnable`**로
별도 취급한다:

> `[quality-gates] codex 감지기 실행 실패 (detector_not_runnable) — 이 리뷰에는 모델 다양성이 없었다 (degraded).`

배너 문구:

> `[quality-gates] codex 리뷰 미실행 (<사유>) — 이 리뷰에는 모델 다양성이 없었다 (degraded).`

**silent (사용자 조치 대상이 아니다 — 배너를 내지 않는다):**

| skip_reason | 왜 조용한가 |
|---|---|
| `kill_switch` | 사용자가 직접 껐다. 자기가 한 일을 다시 알릴 필요가 없다 |
| `inside_codex_sandbox` | 이미 codex 안이다. 재귀 방지이지 결손이 아니다 |

#### codex 결과 판정 (러너가 돌고 난 뒤)

`run_codex_reviewer.sh` 가 exit 0 을 내는 것은 **계약이지 성공 신호가 아니다.**
산출물 YAML 을 읽어 아래 순서로 판정하고, 앞 단계에서 결론이 나면 뒤를 보지 않는다.

1. **산출물 파일이 없거나 0바이트** → codex 결과 없음. 배너를 낸다.
   0바이트는 소비자에게 *"codex 성공, 발견 없음"* 으로 읽힌다 — 리뷰어 하나가
   조용히 사라지는 상태다.
2. **`meta.codex_failed: true`** → 돌았으나 결과를 신뢰할 수 없다. `meta.reason` 을
   배너에 함께 싣는다 (`exit_nonzero` · `schema_mismatch` · `malformed_json` ·
   `missing_result` · `auth_error_in_stderr` · `extract_failed` 등).
3. **`meta.codex_failed: false` 가 있어야** 정상이다. 그 키가 **부재하거나 판독
   불가**면 degrade 다 — `findings: []` 만 보고 clean 으로 읽지 않는다
   (`indeterminate ≠ clean`).

배너 문구:

> `[quality-gates] codex 리뷰 결과 사용 불가 (<reason>) — 이 리뷰에는 모델 다양성이 없었다 (degraded).`

**스트림 이벤트는 판정 입력이 아니다.** `--json` 의 `error` 이벤트는 **재시도로 성공한
run 에서도 방출**되므로 실패 신호로 쓰지 않는다. 그 층은 로깅 대상이다.

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
>
> **두 호출은 각자의 트리에서 돈다 — 어느 쪽도 verifier 의 샌드박스가 아니다.**
> 기준선 측은 `create-baseline` 이 merge_base 에, HEAD 측은 `create-head` 가 봉인
> 커밋 `B` 에 detached 로 만든 일회용 트리다. *누가 부르는가* 만 나누고 *어디서
> 도는가* 를 나누지 않으면 self-report 신뢰가 결과값 축에서 실행 환경 축으로 옮겨갈
> 뿐이다 (§11 ⑬). 두 축 모두에서 실행되는 것은 어댑터의 `setup_cmd` 뿐이다.

**Step R-init — 중간 파일 위치 + baseline 확정.**

먼저 이 실행이 쓸 **오케스트레이터 소유 중간 파일**의 집이 될 디렉토리를 하나 만든다.
`mktemp -d` 는 **`TMPDIR` 을 존중**하므로 "트리 밖" 이 저절로 성립하지 않는다 — 담김을
직접 확인하고, 안이면 **멈춘다**:

```bash
[[ -n "$project_dir" ]] \
  || { echo "[quality-gates] \$project_dir 가 비어 있습니다 — 담김을 판정할 수 없습니다. verdict 는 PASS 불가." >&2; exit 1; }
qg_run_tmp=$(mktemp -d) \
  || { echo "[quality-gates] 중간 파일 디렉토리 생성 실패 — verdict 는 PASS 불가. 경로를 즉흥으로 정하지 말 것." >&2; exit 1; }
qg_run_tmp_p=$(cd "$qg_run_tmp" 2>/dev/null && pwd -P) \
  || { echo "[quality-gates] 중간 파일 디렉토리 해소 실패 ($qg_run_tmp) — verdict 는 PASS 불가." >&2; exit 1; }
sealed_root=$(git -C "$project_dir" rev-parse --show-toplevel 2>/dev/null) \
  || { echo "[quality-gates] \$project_dir 의 저장소 최상위를 구하지 못했습니다 — 봉인 범위를 알 수 없습니다. verdict 는 PASS 불가." >&2; exit 1; }
[[ -n "$sealed_root" ]] \
  || { echo "[quality-gates] 저장소 최상위가 빈 값입니다 — 봉인 범위를 알 수 없습니다. verdict 는 PASS 불가." >&2; exit 1; }
sealed_root_p=$(cd "$sealed_root" 2>/dev/null && pwd -P) \
  || { echo "[quality-gates] 저장소 최상위 해소 실패 ($sealed_root) — verdict 는 PASS 불가." >&2; exit 1; }
case "$qg_run_tmp_p/" in
  "$sealed_root_p"/*)
    echo "[quality-gates] TMPDIR 이 검사 대상 트리 안입니다 ($qg_run_tmp) — 중간 파일이 커밋 B 로 봉인되거나 피검자에게 노출됩니다. TMPDIR 을 트리 밖으로 두고 다시 실행하십시오. verdict 는 PASS 불가." >&2
    exit 1 ;;
esac
echo "> [quality-gates] 중간 파일: $qg_run_tmp (실패 시 보존, 자동 삭제하지 않음)"
assign_rows_file="$qg_run_tmp/assign-rows.tsv"   # 실행당 1개 (R1b)
aggregate_yaml="$qg_run_tmp/aggregate.yaml"      # 실행당 1개 (R6 집계)
```

**이 가드가 AC69 의 유일한 실질 집행자다.** 텍스트 락은 대입 줄만 볼 수 있어, 뿌리를 다른
변수로 한 단계 우회하거나 `TMPDIR` 을 환경에서 넘기는 축을 원리적으로 못 본다. `pwd -P` 를
양쪽에 쓰는 것은 symlink 로 담김을 우회하는 것을 막기 위해서다 (`run-test-selection.sh` 의
`unit_within_worktree` 와 같은 idiom).

**기준은 `$project_dir` 이 아니라 저장소 최상위다 (/qg iter-8 iteration 3, F10).** 앞
버전은 `$project_dir` 과 비교했는데, 그 값은 Step P0 의 `pwd` 이고(`--show-toplevel` 이
아니다) **봉인하는 쪽은 그것을 쓰지 않는다** — `create-sandbox` 는
`main_root=$(git rev-parse --show-toplevel)` 를 독립적으로 구해
(`qg-worktree.sh:148-150`) 거기서 `ls-files --others --exclude-standard` 로 열거해
샌드박스로 복사한다(`:170-171`). 즉 가드가 재는 집합은 `$project_dir` 이고 실제로 커밋
`B` 로 봉인되는 집합은 `$main_root ⊇ $project_dir` 이었다. 서브디렉토리에서 `/qg` 를
부르고 `TMPDIR` 이 레포 루트 쪽에 있으면 `mktemp -d` 는 `$project_dir` **밖** ·
`$main_root` **안**에 떨어져 `case` arm 이 매치하지 않고, 가드는 통과하며, 파일은
봉인된다 — 이 가드의 산문이 막는다고 선언한 바로 그 결말이다. `$project_dir` 은 여전히
**어느 저장소인지**를 정하는 입력이고(`git -C "$project_dir"`), 담김 판정의 기준은
봉인하는 쪽과 같은 트리다.

**이 블록에 `git` 이 새로 들어왔다.** `allowed-tools` 에 항목이 없는 맨 셸 명령이 하나
늘었고(`pwd`·`printf`·`echo`·`cd`·`mv` 와 같은 부류), 그 부류가 항목을 필요로 하는지는
여전히 **미측정**이다(§11 ㉜). 항목을 늘리지 않는 판단은 그대로다 — 예정된 Runtime 실측이
이제 이 명령까지 함께 관측한다.

**빈 `$sealed_root` 검사가 따로 있는 이유는 `$project_dir` 의 것과 같다.** `rev-parse` 가
0 을 내면서 빈 문자열을 낼 경로가 있으면 이어지는 `cd ""` 가 0 을 반환해 패턴이 조용히
`$PWD/*` 가 된다 — 아래 문단이 `$project_dir` 에 대해 적은 실패 모드와 같은 것이다.

**빈 `$project_dir` 검사가 맨 앞에 있는 것이 이 가드의 이빨이다.** 이 블록은 **새 셸에
붙여넣는 템플릿**이고(`Bash` 도구는 호출마다 새 셸이라 변수가 살아남지 않는다), `$project_dir`
은 살아 있는 셸 변수가 아니라 오케스트레이터가 **리터럴로 치환해야 하는 자리**다. 즉 빈 값·
미치환은 예외가 아니라 **기본 실패 모드**다. 그리고 bash 의 `cd ""` 는 **0 을 반환하고 cwd 를
바꾸지 않으므로**, 검사 없이 `$(cd "$project_dir" && pwd -P)` 를 쓰면 패턴이 조용히 `$PWD/*`
가 되어 가드가 *다른 질문*("cwd 아래인가")에 답한다 — cwd 가 우연히 트리 안이면 맞고 아니면
공허하게 통과한다. 그래서 `-n` 검사가 **먼저**여야 하고(`|| ` 분기는 `cd ""` 성공 때문에
발화하지 않는다), 두 해소는 각각 fail-closed 여야 한다. 앞 버전은 인용한 idiom 에서 바로 그
실패 분기(`|| return 1`)를 빠뜨린 복사본이었다.

**`$evidence_dir` 은 별도 금지가 아니다** — `"$project_dir/.claude/quality-gates/<sid>/"`
이므로 `$project_dir` 담김의 부분집합이다. 앞 버전은 이것을 독립된 두 금지로 적었다.
**그 포함 관계가 이 가드의 전제다** — `$evidence_dir` 이 R5a³ 에서 피검자에게 넘어가는 것이
두 번째 금지의 원래 사유였고(설계 §11 ㉕ 이 소유), 그것이 트리 밖으로 옮겨지면 여기에
두 번째 담김 검사를 복구해야 한다.

나머지 넷은 **어댑터마다 하나씩**이고, **변수에 바인딩하지 않는다 — 쓰는 자리에서 경로를
그대로 적는다.** 이름 규칙 하나로 끝난다:

> `$qg_run_tmp/<역할>-$runner.<확장자>` — 역할은 `expected`(.txt) · `baseline`(.tsv) ·
> `head`(.tsv) · `per-adapter`(.yaml). `$runner` 는 **그 호출이 도는 어댑터**이며,
> 네 파일은 전부 R4·R5b·R6 의 **어댑터 루프 안에서만** 쓰이므로 그 자리에서 값이 정해진다.

**앞의 두 판본이 모두 틀렸고, 둘째는 첫째보다 나을 것이 없었다.** 처음에는 이 자리에서
`$runner` 를 전개했는데 R-init 시점에 `$runner` 가 바인딩되어 있지 않아 네 경로가
`expected-.txt` 하나로 붕괴했다. 그것을 셸 함수(`qg_paths_for`)로 바꿨지만 **함수는 여기서
원리적으로 작동할 수 없다**: `Bash` 도구는 호출마다 새 셸이라 함수 정의가 다음 호출까지
살아남지 않고, R-init 과 소비자(R4·R5b·R6) 사이에는 Agent dispatch(R5a³)와
`AskUserQuestion`(R3)까지 끼어 있다. 게다가 그 판본은 **어디서도 호출되지 않았다** — 정의
1건, 호출 0건. 스텝 사이로 바인딩을 들고 갈 수 있는 것은 셸 상태가 아니라 **오케스트레이터
컨텍스트**뿐이고(바로 아래 문단), 함수는 그렇게 들고 갈 수 없는 **유일한** 형태다.
그래서 정의 지점 자체를 없앤다 — **정의가 없으면 "정의를 부르는 것을 잊는" 실패 클래스도
없다.** 이 세 판본은 같은 실수의 세 얼굴이다: 매번 *정의*를 고치고 *배선*을 안 고쳤다.

러너 이름으로 가르는 이유: 한 이름을 재사용하면 폴리글랏 레포에서 **어댑터 A 의 행이
어댑터 B 의 대조에 들어간다.** R4 는 마지막 어댑터의 행만 남기고, R6 의
`--expected-adapters N` 은 서로 다른 YAML N 개 대신 **같은 파일 N 개**를 받는다.

`$qg_run_tmp` 와 실행-스코프 두 이름(`$assign_rows_file` · `$aggregate_yaml`)은
**오케스트레이터 변수로 붙잡아 스텝 사이로 들고 간다** (R5a¹ 의
`sandbox_dir`/`baseline_sha`/`snapshot_digest` 와 같은 규율). 스텝마다 `mktemp -d` 를 다시
부르지 않는다 — 새 디렉토리는 빈 디렉토리이고, 빈 배정 파일은 이 문서가 방금 닫은
fail-open 의 입력이다.

**닫히지 않은 이웃 (과장하지 않는다).** 위치를 정하고 담김을 집행할 뿐 **custody 를
증명하지 않는다.** 이 파일들은 `runtime-verifier` 의 쓰기 범위 안에 있다 — 그 agent 는
무제한 `Bash` 를 같은 OS 사용자로 갖고, 파일명은 이 문서에 리터럴로 적혀 있으며,
`mktemp -d` 의 0700 은 **같은 UID 에 대해 경계가 아니다**. 앞 버전이 여기 적었던
*"여섯 이름 전부 당신이 소유하고 당신만 쓴다"* 는 **존재하지 않는 경계의 서술**이었다.

**시계를 바로잡는다 — 창의 단위는 "verifier 턴"이 아니다.** 앞 버전은 노출 창을 R5a³
verifier 턴 앞/뒤로 쟀는데, 피검자가 통제하는 코드는 그 턴 말고도 **호스트 권한으로 세 번
더** 실행된다: R4 의 `setup_cmd`/`run`, R5b 의 `setup_cmd`/`run`, 그리고 R6 의 flaky
재실행. 올바른 단위는 **"저장소가 통제하는 코드가 호스트 사용자로 실행되는 임의의 지점"**
이다. 그 시계로 여섯을 전부 분류하면:

| | 파일 | 기록 → 소비 사이에 피검자 코드가 도는가 |
|---|---|---|
| **창 있음** | `$qg_run_tmp/assign-rows.tsv` | R1b 기록 → R8 소비. 창은 **R4 에서 열린다**(verifier 턴 뒤가 아니라 앞). 재시도는 R1b 를 다시 돌리지 않으므로 **두 번의 verifier 턴을 건넌다** |
| | `$qg_run_tmp/expected-$runner.txt` | R5b 어댑터 루프 기록 → R6 소비. **`SILENT_DROP` 백스톱의 원본** |
| | `$qg_run_tmp/baseline-$runner.tsv` | R4 기록 → R6 소비. **가장 나쁘다.** 재시도는 R4 를 다시 돌리지 않으므로 이것도 **두 번의 verifier 턴을 건넌다** |
| | `$qg_run_tmp/head-$runner.tsv` | R5b 기록 → R6 소비. 그 사이 R6 의 flaky 재실행이 `$head_tree_dir` 에서 저장소 코드를 돌리고 **같은 파일에 행을 다시 쓴다** |
| | `$qg_run_tmp/per-adapter-$runner.yaml` | R6 어댑터별 기록 → R6 말미 `--aggregate` 소비. 사이에 같은 flaky 재실행 |
| **창 없음 (조건부)** | `$qg_run_tmp/aggregate.yaml` | R6 말미 기록 → **R8 소비** (R7 은 이것을 읽지 않는다 — `mutation-guard` 자신의 YAML 만 읽는다). 사이에 도는 것은 R7 의 git 뿐이다 |

기준선 행 파일이 가장 나쁜 이유: 행을 `pass`→`fail` 로 뒤집으면 모든
`NEW_REGRESSION` 이 `PRE_EXISTING` → `closed` → **degrade 신호 없는 PASS** 가 된다.
§5.4/AC59 의 방어는 *캐시*를 지키지 조립된 행 파일을 지키지 않는다.

**그리고 배정 행 파일의 집행은 *부재*에 실려 있다.** 바로 아래 R1b 의 원자적 쓰기는
"생산자가 죽으면 최종 경로에 파일이 없다 → R8 이 exit 4" 로 신호를 만드는데, **부재는
피검자가 지울 수 있는 성질이 아니라 채울 수 있는 성질이다** — 빈 파일을 그 경로에 심으면
`--assign-rows` 는 잘 형성된 0행 TSV 를 읽고 `unclaimed=0`, exit 0 이 된다.

**필요한 것은 한 동작뿐이다 — 앞 버전이 "세 조건이 겹쳐야" 라고 적은 것은 안심시키는
방향으로 거짓이었다 (/qg iter-8 iteration 3, F9).** 그 문장은 `assign_rc` 가
오케스트레이터 턴 값이라는 사실에 기대는데, 이 시나리오에서 `assign_rc=0` 은 **정상값**
이고 파일도 **정상적으로 존재**한다. 즉 1차 라우팅은 arm 1("정상 진행")으로 제대로
발화하며 아무것도 제약하지 않는다. `assign` 이 실패할 필요도, 우연이 겹칠 필요도 없다 —
이미 있는 파일을 0바이트로 자르는 것 하나로 §11 ㉓ 집행이 발화하지 않고
`floor:verification` 이 `closed` 로 남는다.

**`$qg_run_tmp/aggregate.yaml` 의 "창 없음" 은 조건부다 (/qg iter-8 iteration 3, F15).** *"R7 은 순수
git 이다"* 는 *"피검자가 통제하는 코드가 안 돈다"* 와 **같은 술어가 아니다.** git 은
저장소 config 가 이름 지은 프로그램을 실행하고, 샌드박스는 linked worktree 이므로
`git -C <sandbox> config core.fsmonitor …` 는 **공유 `.git/config`** 에 쓴다
(`qg-worktree.sh:198-199` 가 자기 자신에 대해 그 부작용을 문서화한다). 그리고
`mutation-guard` 의 스냅샷은 7필드(`:240-248`), Layer 2 비교는 5필드(`:498-506`)뿐이라
`core.fsmonitor`·`core.hooksPath`·`alias.*`·`diff.external`·`core.pager` 는 **스냅샷도
비교도 안 된다.** R7 자신의 `git add -A`(`:381`·`:452`)가 인덱스를 갱신하며 그 fsmonitor
프로그램을 호출한다. 즉 이 창은 "한 YAML 의 custody" 보다 크다 — **가드 자신의 측정
안에서 피검자 코드가 돈다.** 이 갭은 이 브랜치가 건드리지 않는 파일에 있으므로 여기서
고치지 않고 §11 에 등재한다. 이 표에서 고친 것은 소비자 목록과 근거뿐이다.

이 축은 §6.7 S1(잔여 결함)이며 **열려 있다** — 닫는 모양은 `snapshot_digest` 선례
(오케스트레이터가 봉인을 쥔다)이거나 §11 ㉛ 의 생산자-발행 terminator 이고, **여섯 전부에
걸거나 하나도 안 걸어야 한다**(하나만 봉인하면 나머지에 대한 공시가 안심시키는 방향으로
거짓이 된다). **행 수를 모델이 전사해 두 번째 인자로 넘기는 모양은 안 된다** — 오케스트레이터가
행 수를 배울 곳이 그 파일뿐이라 대조 양쪽이 같은 의심 산출물에서 나오고, 이 라운드가 일부러
닫은 전사 seam 을 다시 연다.

디렉토리는 지우지 않는다: 실패한 실행의 중간 파일이 디버깅에 쓰이고(`CLAUDE.md` 의
"실패 시 보존"), 위 `echo` 가 그 경로를 사용자에게 알린다. 정리는 `TMPDIR` 수명에 위임.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/resolve-baseline.sh"
```

6키(`base` / `base_ref` / `merge_base` / `degraded` / `same_as_head` / `ahead`)를
캡처한다. 차등 실행이 불가능한 조건은 **정확히 둘**이다 — `degraded: yes`, 또는
`same_as_head: yes` **이면서 워킹 트리가 clean** 일 때(아래 표가 정본). 둘 중
하나에 해당하면 loud advisory 를 내고 **verdict 를 PASS 로 올리지 않는다**:

> `> [quality-gates] baseline 확정 불가 (<사유>) — 차등 귀속 없이 진행, verdict 는 PASS 불가`

`same_as_head: yes` 는 merge_base 가 HEAD 커밋과 같다는 뜻이다. 이 상태는 정상(`main`
위 미커밋 작업)으로도 변조(base 후보 ref 는 공유 common gitdir 에 있고 `run` 이 돌리는
저장소 코드가 `git update-ref` 를 할 수 있다)로도 생기고, **이 스크립트는 둘을 구분하지
못한다**. 구분하는 것은 워킹 트리다:

| `same_as_head` | 워킹 트리 | 차등 증거 | 조치 |
|---|---|---|---|
| yes | dirty | **성립** (기준선=커밋, HEAD=워킹 트리) | 정상 진행 |
| yes | clean | **불가** (두 트리가 같은 바이트) | R4 스킵 + PASS 불가 |
| no | — | 성립 | 정상 진행 |

깨끗한 트리에서 `same_as_head: yes` 면 모든 진짜 회귀가 `(fail,fail)=PRE_EXISTING` 으로
접히므로 PASS 로 올리지 않는다. **더러운 트리는 반대다 — 정상 진행이며 PASS 가능하다.**
`same_as_head: yes` **단독**으로 막던 앞 버전은 실측으로 해로웠다: `main` 위 미커밋
작업에서 측정된 `NEW_REGRESSION`/FAIL 이 `BASELINE_UNRUNNABLE`/SKIP 으로 내려갔다.
위 도입 문장이 그 포괄 형태로 남아 있어 이 표와 **정면으로 모순**됐고(codex `/qg`
iter-4, IMPORTANT), 도입부만 읽는 구현자는 제거된 동작을 되살리게 된다 — 좁힌 규칙의
원래 형태가 인용 가능한 채로 남으면 좁히지 않은 것과 같다. 도입 문장을 표에 맞췄다.
**알려진 미해소:** 이 규칙을 읽는 스크립트는 없다 —
오케스트레이터 산문이다. 부분 변조(base 를 브랜치 중간 커밋으로 이동)는 이 표의 어느
행에도 걸리지 않는다. Review 게이트의 changes-exist floor 는 이 키를 읽지
않는다 — 거기서는 `worktree_dirty` 가 변경을 잡으므로 정상 케이스가 죽지 않는다.

`degraded: no` 일 때는 baseline 한 줄을 그대로 출력한다 — `ahead` 는 **부분 변조
disclosure** 다 (base 를 HEAD 가 아니라 브랜치 중간 커밋으로 옮기면 `same_as_head` 는
no 이고 기준선 트리도 만들어진다; 그 창을 닫는 결정론 수단은 없다):

> `> [quality-gates] baseline: <base> @ <merge_base 앞 12자> (<ahead>커밋 앞섬)`

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

> **`compute-test-scope-candidates.sh` 의 종료 코드 라우팅 (/qg iter-7 iteration 2).**
> `0` = 성공(빈 출력은 *진짜로 후보가 없다*) · `1` = git 레포 아님 · **`4` = 리뷰 범위를
> diff 하지 못했다.** `4` 를 빈 출력과 같이 다루면 안 된다 — 그 경우 stderr 를 verbatim
> 노출하고 **`gap` 차원에 사유를 기록**하며, 그 사실이 `verification` 판정에 들어간다.
> "범위를 확정하지 못했다" 를 "이 diff 는 테스트를 건드리지 않는다" 로 읽는 것이 §6.7 F6
> 이 이름 붙인 결함이고, 스크립트 헤더가 예전에 *fail-open* 을 지시하고 있어 코드 수정만
> 으로는 닫히지 않았다(같은 라운드에 헤더도 함께 고쳤다).
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
set -o pipefail
printf '%s\n' "${candidate_files[@]}" \
  | "${CLAUDE_PLUGIN_ROOT}/scripts/run-test-selection.sh" assign "$project_dir" \
    > "$assign_rows_file.part" \
  && mv -f "$assign_rows_file.part" "$assign_rows_file"
assign_rc=$?
```

**`.part` → `mv` 는 장식이 아니라 이 스텝의 fail-closed 축이다.** 앞 버전은 최종 경로로
직접 리다이렉트했는데, 셸은 **명령이 돌기 전에** 대상을 만들고 절단한다. 그래서 인자
검증에서 즉사한 `assign`(`die` → 0바이트) 도, 루프 중간에 죽은 `assign`(문법적으로
완전한 **접두 행**) 도 R8 에게는 *"`unclaimed` 0건"* 과 **바이트 단위로 구분되지
않았다.** 형제 `--aggregate` 는 같은 입력에 `exit 4` 를 내는데 이쪽만 `exit 0` 이었다.
이제 실패한 실행은 최종 경로에 **파일을 남기지 않고**, R8 의 `--assign-rows` 가 부재로
`exit 4`(내용 축) 를 낸다.

`pipefail` 이 하는 일은 **왼쪽(`printf`)의 실패까지 파이프라인 상태로 올리는 것**이다.
오른쪽(`assign`)의 실패는 pipefail 없이도 잡힌다 — 파이프라인의 상태는 원래 **마지막
명령**의 상태이고 `assign` 이 마지막이라, 죽은 생산자는 `&&` 를 단락시켜 `mv` 를 아예
실행하지 않는다. 두 축을 한 규칙으로 덮어야 `&&` 앞의 **어느 단계**가 죽어도 최종 경로에
파일이 남지 않는다. (앞 버전은 여기 *"`pipefail` 이 없으면 `$?` 는 `mv` 만 본다"* 고 적었는데
그것은 사실이 아니다 — 코드는 맞고 근거만 틀렸다. 근거가 틀린 채로 load-bearing 한 줄에
붙어 있으면 다음 편집자가 그 줄을 지운다.)

**형제 두 리다이렉트가 `.part`→`mv` 를 안 쓰는 것은 누락이 아니다.** R6 의
`> "$qg_run_tmp/per-adapter-$runner.yaml"` 과 `> "$aggregate_yaml"` 은 최종 경로로 바로
쓴다. 안전한 이유는 **소비자가 요구하는 것이 양성 토큰**이기 때문이고, 소비자는 둘이
다르다 (/qg iter-8 iteration 3, F18): per-adapter 파일은 `diff-test-results.py` 의
`parse_adapter_yaml` 이 읽고, `$aggregate_yaml` 은 `check_qa_ledger.py` 가 읽는다. 앞
버전은 둘 다 후자가 읽는다고 적었다.

절단에 대한 주장도 정확히 적는다: **verdict 입력을 잃는 절단은 `exit 4` 가 된다.**
`_aggregate()` 는 `attribution_status:` 를 세 `verdict_input` 키 **뒤에**, `per_adapter:`
블록 **앞에** 낸다. 그래서 판정에 쓰이는 키를 잃는 절단은 `attribution_status:` 도 함께
잃고 `check_qa_ledger.py` 의 "정확히 1개" 검사가 `exit 4` 를 낸다. 조용히 사라질 수 있는
것은 **진단용 `per_adapter` 꼬리뿐**이며 그 값들은 아래에서 판정 입력이 아니라고 명시된다.
앞 버전의 *"잘린 파일은 exit 4 가 된다"* 는 보편 주장이라 이 꼬리에 대해 거짓이었다.

반면 `--assign-rows` 의 소비자에게는 **비어 있음이 적법한 답**이라 절단과 구분되지 않는다.
그 비대칭이 이 원칙을 어디에 적용할지를 가른다 — 형제 둘을 "고치"거나, 반대로 이 원칙이
채택되지 않았다고 결론짓지 말 것.

**`assign` 실패 라우팅 (R6·R7 표와 같은 규율 — 관측 없음은 음성 결과가 아니다).**
이 스텝은 이 SKILL 에서 **유일하게 라우팅이 없던** 결정론 호출이었다. 바로 위
`compute-test-scope-candidates.sh` 문단이 이름 붙인 결함 — *"범위를 확정하지 못했다"* 를
*"이 diff 는 테스트를 건드리지 않는다"* 로 읽는 것 — 이 30줄 아래에서 *"배정하지 못했다"*
를 *"`unclaimed` 0건"* 으로 읽는 형태로 재현됐다.

| `assign_rc` / 파일 상태 | 조치 |
|---|---|
| `0` + `$assign_rows_file` 존재 | 정상 진행 (행 0개도 정상 — 아래) |
| non-zero, **또는 최종 경로에 파일 부재** | stderr 를 verbatim 으로 노출하고 `verification` 을 **`degraded`** 로 두며 **verdict 를 PASS 로 올리지 않는다.** 빈 결과를 *"배정할 것이 없었다"* 로 읽지 않는다 |

**행 0개는 실패가 아니다.** `assign` 이 정상 종료하고 행이 0개인 것은 *후보가 비었다* 는
뜻이고, 그것은 이 인자가 판정하는 축이 **아니다**(§11 ⑭, 열려 있음). 위 표가 가르는 것은
*"생산자가 완주했는가"* 이지 *"결과가 비었는가"* 가 아니다 — 둘을 같은 신호로 접는 것이
앞 버전의 결함이었고, 반대로 0행을 오류로 만드는 수정은 ⑭ 를 **부수효과로 닫아** 정당한
빈 스코프에서 PASS 를 구조적으로 불가능하게 만든다.

**남는 틈 (과장하지 않는다).** `assign` 이 `exit 0` 을 내면서 stdout 이 잘린 경우(예:
ENOSPC — 그 스크립트는 `printf` 실패를 종료코드로 올리지 않는다)는 이 배선이 잡지
못한다. 닫는 모양은 생산자가 **행수 포함 완료 선언**을 마지막 줄로 내고 소비자가 그것을
요구하는 것이며, 이 라운드의 범위 밖이다(§11 에 등재).

그다음 **그 파일을 읽어** unit 목록을 얻는다 — 리다이렉트가 화면 출력을 없앴으므로
R2 의 5번 필드와 R8 의 `verification` 차원이 쓸 목록은 파일에서 온다.
`<unit>\t<runner|unclaimed>\t<granularity>` 3필드다. stderr 의 `미실행 러너:` 줄도 함께
잡아 `gap` 차원에 열거한다. **`unclaimed` 행이 하나라도 있으면** 그 목록을 R8 의
`verification` 차원으로 가져간다 (`gap` 이 아니다 — 이유는 R8).

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

R-init 이 `degraded: yes` 를 냈으면 이 스텝 전체를 건너뛰고 R8 에서
`BASELINE_UNRUNNABLE` 로 처리한다. **이때도 `$qg_run_tmp/baseline-$runner.tsv` 는 선택한 unit 마다
`<unit>\tunrun\t-` 로 채우고 `baseline_detected` 는 `NONE` 이다** — 형제 skip 경로 둘과
같은 규칙이다. 빈 파일을 넘기면 행 부재가 `SILENT_DROP` 으로 라벨돼 "기준선을 못
돌렸다"가 "고른 것이 사라졌다"로 잘못 보고된다(/qg iter-6 D2 실측: 빈 파일 →
`SILENT_DROP`, `unrun` 으로 채움 → `BASELINE_UNRUNNABLE`). 즉 바로 윗 문장이 약속한
`BASELINE_UNRUNNABLE` 은 채워야만 실제로 나온다 — 이 지시가 빠져 있었다.

**폴백(샌드박스 비활성)에서도 이 스텝 전체를 건너뛴다 (/qg iter-5 SR4).**
`DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1` 이면 R5a¹ 이 폴백으로 가고 **R5b 가 아예 돌지
않는다** — HEAD 축이 전량 `unrun` 이라는 뜻이다. 그러면 R4 가 만든 기준선 행은 어떤
값이든 `(P,U)`/`(F,U)`/`(A,U) → SILENT_DROP` 또는 `(U,*) → BASELINE_UNRUNNABLE` 로만
짝지어진다. 어느 쪽도 새 정보가 아니고 verdict 는 이미 SKIP_WITH_EVIDENCE 로 cap 돼
있다 — 즉 **기준선 워크트리 생성과 전체 기준선 스위트 실행을 대가로 아무것도 얻지
못한다.** 판별자는 R5b 가 쓰는 것과 같은 사실(샌드박스 비활성)이며, R4 는 R5a¹ 보다
먼저라 `sandbox_dir` 을 아직 못 보므로 **그 원인인 kill switch 를 직접 읽는다.**
건너뛸 때 `$qg_run_tmp/baseline-$runner.tsv` 는 선택한 unit 마다 `<unit>\tunrun\t-` 로 채우고
`baseline_detected` 는 `NONE` 이다 — 빈 파일을 넘기면 행 부재가 `SILENT_DROP` 으로
라벨돼 "기준선을 못 돌렸다"가 "고른 것이 사라졌다"로 잘못 보고된다.

**`same_as_head: yes` 만으로는 건너뛰지 않는다 (/qg iter-3 정정).** 앞 버전은 그렇게
지시했고 그것이 **측정 가능한 회귀를 비차단으로 내렸다**: `main` 위 미커밋 작업에서
기준선 트리는 merge_base **커밋**이고 HEAD 측은 **워킹 트리를 봉인한 커밋 `B`** 라
차등이 정확히 성립하는데, 스킵하면 `NEW_REGRESSION`/defect=true/FAIL 이
`BASELINE_UNRUNNABLE`/defect=false/SKIP 으로 바뀐다(실측). 차등 증거가 실제로 불가능한
것은 **`same_as_head: yes` 이고 워킹 트리가 깨끗할 때**뿐이다 — 그때만 두 트리가 같은
바이트다. 판별자는 `check-review-scope.sh` 의 `worktree_dirty` 다.

**판별자를 여기서 직접 구한다 (/qg iter-5 정정).** 앞 버전은 Review 게이트 Step 1b 가
캐시해 둔 값을 가정했는데, **Step 1b 는 Review 게이트 iteration N=1 에서만 돈다.**
`/qg runtime` 은 Dispatch Loop 를 우회하므로 그 경로에서 이 판별자는 **미정의**였고,
빈 문자열은 `!= yes` 라 "clean" 으로 읽혀 위 회귀가 다른 문으로 돌아온다. 값이 아직
없으면 여기서 직접 부른다 (이미 allowed-tools 에 있다):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/check-review-scope.sh"
```

`worktree_dirty` 와 **`degraded` 를 함께** 읽는다. `degraded: yes` 면 그 스크립트는
`worktree_dirty: no` 를 단정값으로 내지만 **그것은 관측이 아니라 자리표시자**다 —
`degraded: yes` 는 **"모름"** 이므로 **dirty 로 취급해 R4 를 실행한다**(fail-closed:
차등을 못 하는 쪽이 아니라 하는 쪽으로 기운다. 스킵의 피해는 진짜 FAIL 의 SKIP 강등이고,
불필요한 실행의 피해는 시간뿐이다).

| `same_as_head` | `check-review-scope` | 조치 |
|---|---|---|
| yes | `degraded: no` · `worktree_dirty: yes` | R4 실행 |
| yes | `degraded: no` · `worktree_dirty: no` | R4 스킵 + PASS 불가 |
| yes | `degraded: yes` | **모름 → dirty 취급 → R4 실행** |
| no | — | R4 실행 |

그때 R6 에 넘길
`baseline_detected` 는 `NONE` 이다 (기준선 트리를 만들지 않았으므로 관측이 없다).
건너뛸 때 `$qg_run_tmp/baseline-$runner.tsv` 는 **비우지 않고** 선택한 unit 마다 `<unit>\tunrun\t-` 로
채운다 — 빈 파일을 R6 에 넘기면 행 부재가 `SILENT_DROP` 으로 라벨된다. 둘 다 PASS 는
아니지만 보고되는 사유가 달라진다(기준선을 못 돌린 것 vs 고른 것이 사라진 것).

① 캐시 조회 — 어댑터마다:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/baseline-cache.sh" get \
  ".claude/quality-gates/baseline-cache" "$merge_base" "$runner" "${units[@]}"
```

적중분만 나온다. 입력 목록과 차집합해 **미적중분**을 얻는다. exit 4(손상)는 전량
미적중으로 취급하고 loud advisory 를 낸다.

**`fail` 은 적중으로 나오지 않는다 — 항상 재검증한다.** 캐시는 `.claude/quality-gates/`
아래에 있고 runtime-verifier 는 무제한 Bash 로 그 형제 디렉토리에 쓰라고 지시받는다.
게다가 `run` 은 저장소가 통제하는 코드를 호스트 권한으로 돌리므로 **적대적 subagent
없이도** 리뷰 대상 저장소의 평범한 테스트가 캐시 경로를 계산해 쓸 수 있다. 심어지거나
낡은 `fail` 은 `(F,F)=PRE_EXISTING` 으로 진짜 회귀를 숨기고, 전량 적중이면 ②의 기준선
워크트리 자체가 만들어지지 않아 **기준선 테스트가 하나도 돌지 않는다**.

봉인(digest)을 쓰지 않는 이유: 캐시는 실행 사이에 살아남는 것이 존재 이유라 세션
컨텍스트의 비밀로 봉인할 수 없고, 파일에 둔 비밀은 verifier 의 Bash 가 읽는다. 대신
**방향 비대칭**을 쓴다 — `pass`/`absent` 가 틀리면 `NEW_REGRESSION`/`NEW_TEST_RED` 로
결함이 되지만(fail-closed) `fail` 이 틀리면 결함이 숨는다. 그래서 `fail` 만 재검증하면
충분하고 비밀이 필요 없다. 같은 규칙이 flaky 기준선 red 의 영구 동결도 닫는다.
기준선에서 빨갰던 unit 은 매번 미적중분에 들어가 ②에서 다시 돈다 — 상각은 `pass`·
`absent` 에 대해 그대로 유지된다(대부분).

② **기준선 워크트리는 캐시 적중 여부와 무관하게 항상 만든다** (전량 적중이어도):

```bash
baseline_wt=$("${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" create-baseline \
  "$merge_base" "<session-id>") || baseline_wt=""
```

**Step R4 ② 실패 라우팅 (형제 R5b 표와 같은 규율 — 관측 없음은 음성 결과가 아니다,
/qg iter-8 iteration 3, F7).** `make_detached_worktree` 의 `die` 는 전부 `printf` **앞**
에서 나므로 실패하면 `$baseline_wt` 는 **빈 문자열**이다. 실패 집합은 "not a commit" ·
"not a git repo" · "cannot create \<parent\>" · "git worktree add failed" · 그리고
`qg-worktree.sh:88-91` 의 **"refuse to clobber existing path"**(앞선 실행이 남긴
`base-<sid8>` 이 있을 때) 다섯이다.

| `create-baseline` 결과 | 조치 |
|---|---|
| exit 0 + `$baseline_wt` 가 존재하는 디렉토리 | ②-a 로 진행 |
| non-zero **또는 `$baseline_wt` 가 빈 값/디렉토리 아님** | stderr 를 verbatim 으로 노출 · 선택한 unit 마다 `<unit>\tunrun\t-` 를 `$qg_run_tmp/baseline-$runner.tsv` 에 채움 · `baseline_detected=NONE` · `verification` 을 **`degraded`** · **verdict 를 PASS 로 올리지 않는다.** `probe`·`run`·캐시 기록은 건너뛴다 |

**행 파일을 채우는 것이 이 표의 요점이다.** 방향은 이 표가 없어도 fail-closed 지만
(`probe ""` 는 `usable: yes` 를 못 내고 `run ""` 은 행을 0개 낸다), **보고되는 사유가
틀린다** — 행 부재는 R6 에서 `SILENT_DROP`("고른 것이 사라졌다")으로 라벨되지
`BASELINE_UNRUNNABLE`("기준선을 못 돌렸다")이 아니다. 위의 세 스킵 경로가 전부 같은
채우기를 지시하는 이유가 그것이고, 이 경로에만 지시가 없었다. 그리고 지시가 없는 자리에서
모델이 `--baseline-detected` 에 `"$runner"` 를 즉흥으로 넘기면 그 값은 **근거 있는 관측**
으로 읽힌다(아래 문단이 이미 기록한 fail-open).

**stdout 을 잡아야 한다 — 이 스텝의 나머지가 `$baseline_wt` 를 쓴다.** `create-baseline` 은
형제 `create-head` 와 본문(`make_detached_worktree`)을 공유하고 만든 트리 경로를 stdout 으로
낸다. 앞 버전은 그 출력을 **버리면서** 아래 `probe`·`run`·`remove` 에 `$baseline_wt` 를
넘겼다 — 즉 어디서도 바인딩되지 않는 이름이었다(HEAD 축은 같은 자리에서 제대로 잡는다).
이것은 R-init 이 방금 없앤 것과 **같은 클래스의 네 번째 사례**다: 정의 없이 사용하는 경로.

**"미적중분이 있을 때만" 이었던 조건을 제거한 것이 이 스텝의 핵심이다.** 캐시는
`.claude/quality-gates/` 아래 있고 세션보다 오래 살며 verifier 의 Bash 와 `run` 이
실행하는 저장소 코드가 닿는다. 선택된 전 unit 에 `pass` 를 심으면 ①이 전량 적중이
되고, 조건부 ②는 **기준선 트리를 아예 만들지 않는다** — merge_base 에 그 어댑터가
없어서 원래 전량 `unrun` → `BASELINE_UNRUNNABLE` → PASS 불가였던 실행이
`STILL_GREEN` → `closed` → **PASS** 가 된다. §5.4 의 비대칭 논증은 실제값이
`unrun` 인 이 줄을 세지 않았다 — 결함 축이 아니라 **인증 축**이라 `fail` 전용
재검증이 닿지 않는다.

이 규칙의 집행자는 **부분적이다 — 과장하지 않는다.** `diff-test-results.py
--baseline-detected` 는 필수 인자라 "값을 못 구한 호출자"가 조용히 통과하는 경로는
없앤다. 하지만 그 인자는 **문자열이 도착했다는 것만** 강제한다 — 값이 실제 기준선
트리의 관측에서 왔는지는 검사하지 않으며, `"$runner"` 를 그대로 넘기면 항상
grounded 가 된다(/qg iter-3 실측, mutation GREEN). 즉 캐시가 ②를 억제하던 경로는
닫히지만, **정직한 값을 넘기는 것 자체는 여전히 오케스트레이터의 의무**다.

그 트리에서 **`detect` 를 다시 실행한다 — HEAD 의 어댑터 집합을 재사용하지 않는다.**
diff 가 테스트 인프라 자체를 바꾸는 경우(unittest→pytest 마이그레이션, `package.json`
에 jest 신규 추가) 두 집합이 다를 수 있고, HEAD 감지를 기준선에 그대로 쓰면 spurious
`error` 가 나와 진짜 회귀를 `PRE_EXISTING` 으로 은폐한다. 두 집합이 다르면 한쪽에만
있는 어댑터의 unit 은 반대편에서 `unrun` 이 되어 귀속이 degrade 되고, 그 사실을 R2
산문과 `gap` 에 명시한다.

②-a **감지된 러너마다 `probe` 를 돌린다 — 캐시 적중 여부와 무관하게 항상**
(/qg iter-5 CRITICAL SR1):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/run-test-selection.sh" probe "$baseline_wt" "$runner"
```

`baseline_detected` 는 `detect` 의 집합이 아니라 **이 `probe` 가 `usable: yes` 를 낸
러너의 집합**이다 (0개면 리터럴 `NONE`). `detect` 는 *이 트리가 무엇을 선언했는가*
를 답하고 `probe` 는 *지금 이 트리에서 실제로 돌 수 있는가* 를 답한다 — 위 문단의
규칙을 집행하려면 필요한 것은 두 번째다.

**왜 `detect` 로는 부족한가.** `run` 안에는 네 단계 관문이 있다(detect 멤버십 →
환경 디렉토리 gitignore → `setup_cmd` → 러너 바이너리 가용성). 그런데 캐시가 전량
적중이면 아래 ③의 `run` 이 **호출되지 않아** 그 관문이 한 번도 돌지 않는다. 그러면
`baseline_detected` 의 유일한 근거가 `detect` 뿐인데, `detect` 가 보는 것은 그 트리의
**선언**이다 (어떤 파일이 무엇을 선언하는지는 `run-test-selection.sh` 가 단독 소유하며
여기서 되풀이하지 않는다 — AC38/AC52). 선언은 되어 있고 도구가 설치되지 않은 머신에서
정직한 결과는 전량 `unrun` → `BASELINE_UNRUNNABLE` →
`degraded` → **PASS 불가**인데, 심어지거나 낡은 `pass` 한 파일이 그 실행을
`STILL_GREEN` → `closed` → **PASS** 로 바꾼다. `probe` 는 테스트를 하나도 돌리지
않고 그 관문만 통과시켜 근거를 실행 기반으로 되돌린다.

**캐시의 존재 이유는 그대로다.** 상각되는 것은 **테스트 실행**이고 `probe` 가
되살리는 것은 **관측**이다. 전량 적중을 이유로 기준선 스위트를 다시 돌리는 것은
이 결함의 해법이 **아니다** — 그것은 캐시를 없애는 것이다.

**조건을 붙이지 않는다.** "미적중분이 없을 때만 probe" 로 최적화하고 싶겠지만, 이
파일의 기록상 `~일 때만` 조건은 매번 구멍이 됐다(②의 "미적중분이 있을 때만" 이 바로
SR1 의 조상이다). `run` 이 관문을 다시 도는 중복은 `setup_cmd` 재실행 비용뿐이다.

**그 비용은 idempotent 가 아니다 — 정직하게 적는다 (/qg iter-6 A5).** 앞선 판본은
`uv sync --frozen`·`npm ci`·`poetry install` 이 "전부 idempotent" 라고 적었는데
사실이 아니다: `npm ci` 는 `node_modules` 를 통째로 지우고 다시 만들며, npm/pnpm/yarn
설치는 레포가 작성한 `preinstall`/`postinstall`/`prepare` 라이프사이클 스크립트를
**호스트 전권으로 실행**한다. 즉 이 스텝은 "테스트를 안 돌리는 값싼 가용성 확인" 이
아니라 리뷰 대상 브랜치의 코드를 실행하는 지점이다.

그럼에도 `probe` 를 무조건 도는 판단은 유지한다 — 게이트는 어차피 같은 트리에서
`npm test`/`make test`/`bash tests/*.sh` 를 레포 권한으로 돌리므로 설치 라이프사이클이
**새 능력을 추가하지 않는다**. 바뀌는 것은 근거뿐이다: "싸고 무해해서" 가 아니라
"이미 같은 신뢰 경계 안이고, 관문을 건너뛰면 SR1 이 되돌아오기 때문에" 돈다.
(`--ignore-scripts` 로 좁히는 선택지는 `probe` 와 `run` 의 관문을 발산시켜 T72 의
관문-동일성 계약을 깨므로 택하지 않는다.)

**읽는 방법은 stdout 의 양성 확인이다.** `usable: yes` 를 **본** 러너만
`baseline_detected` 에 넣는다. `usable: no`·비정상 종료·빈 출력·스크립트 부재는
전부 "yes 아님" 으로 떨어진다 — 부재를 통과로 읽는 경로가 없다(fail-closed).

그다음 어댑터마다 (미적중분이 있을 때만 — 트리는 이미 만들어져 있고 ②-a 의
`probe` 도 이미 돌았다):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/run-test-selection.sh" run \
  "$baseline_wt" "$runner" bulk "${miss_units[@]}"
```

bulk 가 red 면 실패한 unit 에 대해서만 `per-unit` 으로 재실행한다 (2단 구조).

> **이 축의 mode 토큰은 보수적으로 접는다 (/qg iter-7, security-reviewer).** 이 2단계 구조 때문에 한 축이 `bulk` 와 `per-unit` 을 **둘 다** 실행할 수 있는데 `--baseline-mode`/`--head-mode` 는 값이 하나다. 규칙: **이 축의 호출 중 하나라도 `bulk` 였으면 `bulk` 로 적는다.** `per-unit` 은 그 축의 모든 행이 per-unit 호출에서 나왔을 때만이다. 판단이 아니라 기계적 규칙인 이유는 반대 선택이 곧 fail-open 이기 때문이다 — `per-unit` 이라 적으면 도말 degrade 조건(`둘 중 하나라도 bulk`)이 꺼지고, 부분 승격이 남긴 `(F,F)` 행들이 `PRE_EXISTING` 으로 접혀 진짜 회귀를 가린다. 특히 기준선 축은 언제나 `bulk` 로 시작하므로 이 축의 답은 사실상 항상 `bulk` 다.
미적중분이 비어 있으면 이 호출은 생략한다 — **트리 생성과 `detect` 는 생략하지
않는다.** 상각되는 것은 테스트 *실행*이지 기준선 *관측*이 아니다.

③ 결과를 **R6 이 읽을 파일에 쓰고**, 캐시에 기록하고, 기준선 워크트리를 폐기한다:

```bash
printf '%s\n' "${rows[@]}" > "$qg_run_tmp/baseline-$runner.tsv"
printf '%s\n' "${rows[@]}" | "${CLAUDE_PLUGIN_ROOT}/scripts/baseline-cache.sh" put \
  ".claude/quality-gates/baseline-cache" "$merge_base" "$runner"
if [[ -n "${baseline_wt:-}" && -d "$baseline_wt" ]]; then
  "${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" remove "$baseline_wt"
fi
```

**`${rows[@]}` 가 무엇인지 여기서 못 박는다 (/qg iter-8 iteration 3, F1).** 이 어댑터에
대해 **선택한 unit 마다 정확히 한 행**이고, 출처는 ①의 캐시 적중분 ∪ ②의 `run` 출력이다.
2단 구조에서 **per-unit 재실행 행이 그 unit 의 bulk 행을 대체한다** — 둘 다 남기면 안
된다. `diff-test-results.py:88-90` 이 중복 unit 행에 `exit 4` 를 내며 조용한 last-wins 를
명시적으로 거부하므로, 두 단계를 이어붙이는 것은 조용한 오류가 아니라 **확정적인
`exit 4`** 다.

**앞 버전에는 이 첫 줄이 없었다 — 그리고 그것이 이 브랜치의 다섯 리비전 전부에서
그랬다.** R6 은 `--baseline "$qg_run_tmp/baseline-$runner.tsv"` 를 읽는데 그 경로에 쓰는
스텝이 **하나도 없었다**(HEAD 축·`expected` 도 같았다). 세 라운드에 걸친 앞선 "수정"은
전부 이 파일들의 *이름을 어떻게 짓는가*를 고쳤고(R-init 전개 → 셸 함수 → 인라인),
*누가 쓰는가*는 한 번도 건드리지 않았다. 정직한 실행은 `read_text_or_fail4` → `exit 4`
로 떨어져 귀속이 degrade 되고, 모델이 대신 화면 출력을 손으로 옮겨 적으면 아래
`--expected` 가 주장하는 독립성이 사라진다.

폐기가 조건부인 이유는 HEAD 축과 같다 — `create-baseline` 이 죽으면 `$baseline_wt` 는 빈
문자열이고, `remove ""` 는 담김 가드에 걸려 die 한다(파괴적이지는 않지만 스텝을 죽인다).
`&&` 가 아니라 `if` 인 이유: `[[ … ]] && cmd` 는 조건이 거짓일 때 **AND-리스트 전체가
1 을 반환**하고 이 복합문이 블록의 마지막 명령이라, 지울 트리가 없는 정상 경로에서
성공한 스텝이 실패로 읽힌다 (/qg iter-8 iteration 3, F8c).

**폐기는 R4 의 모든 종료 경로에서 실행한다** — ③ 은 happy path 에서만 도달하므로 `probe`
비정상 종료·`run` 비정상 종료·캐시 `exit 4` 로 빠지는 경로에도 같은 조건부 폐기를 둔다.
남기면 다음 `create-baseline` 이 `qg-worktree.sh:88-91` 의 "refuse to clobber existing
path" 에 걸려 **그 세션은 영영 PASS 에 도달하지 못한다** — R6 이 `head-<sid8>` 에 대해
이미 이름 붙이고 닫은 실패이고(`:1495-1502`), 기준선 축에는 그 규칙이 없었다.

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
pre-answers it; otherwise zero-click with **empty** `approved_surfaces` and a default
`block_policy=skip` (there is no automatic surface to opt into — see Decision 2). (`gate=runtime` pre-answers
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
  successive `IFS= read -r` (`sandbox_dir` → `baseline_sha` → `snapshot_digest`) and
  strip trailing whitespace/CR from `snapshot_digest`
  (`tr -d '[:space:]'` or equivalent) — a stray newline/space in the hex makes the
  guard fail-closed on every run. Hold all three as orchestrator variables
  (verifier-unreachable). Set `runtime_project_dir = sandbox_dir` (frozen — it
  overrides the preflight `project_dir` for the Runtime gate only).
- **Exit 3** (kill switch `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1`) → graceful fallback
  (no sandbox): set `runtime_project_dir = project_dir` (the preflight main-repo dir;
  `sandbox_dir`/`baseline_sha` stay UNSET). The verdict is **capped at
  SKIP_WITH_EVIDENCE — never PASS** (no sandbox = no structural Law-2 guarantee = no
  certification). BEFORE the R5a³ dispatch, capture `fallback_pre` = `git -C
  "$project_dir" status --porcelain --untracked-files=all` plus a tracked content
  tree-hash baseline (`GIT_INDEX_FILE=<tmp> git -C "$project_dir" add -A -- . && git
  write-tree`). **R5b 는 폴백에서 실행하지 않는다** (거기 근거 참조) — 오케스트레이터는
  실제 트리에서 `setup_cmd` 도 테스트 명령도 돌리지 않는다. verifier 는 여전히 Write 를
  들고 실제 트리에 붙으므로 "read-only" 라고 단정하지 않는다; 그것이 R7 폴백 신호와
  verdict cap 이 존재하는 이유다. Print: `> [quality-gates] runtime sandbox disabled —
  smoke mode on the real tree (qg runs no installer and no test command there; R5b
  skipped, HEAD units recorded unrun). Verifier still holds write access — see the R7
  working-tree warning. Verdict capped at SKIP_WITH_EVIDENCE
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

**폴백(샌드박스 비활성)에서는 이 스텝을 실행하지 않는다.** `sandbox_dir` 가 UNSET 이면
`run-test-selection.sh run` 을 **호출하지 말고** 선택한 unit 마다 `<unit>\tunrun\t-` 로
`$qg_run_tmp/head-$runner.tsv` 를 채운 뒤 R6 으로 간다. 이유 둘:

1. 폴백의 `runtime_project_dir` 는 **사용자의 실제 워킹 트리**다 (R5a¹ Exit 3). 이 호출은
   어댑터의 `setup_cmd` 를 그 트리에서 실행한다 — `npm ci` 는 `node_modules` 를 통째로
   지우고 다시 깔고, `uv sync --frozen` 은 lock 에 없는 패키지를 prune 하고,
   `python3 -m venv .venv` 는 기존 `.venv` 를 덮어쓴다 — 이어서 테스트 명령 자체
   (`npm test`·`make test`·`bash tests/*.sh`)도 같은 트리에서 돈다. **R7 의 폴백 안전
   신호는 이것을 구조적으로 보고할 수 없다**: `--porcelain` 은 git-ignored 를 보지 않고,
   `setup_env_dir_of` 가 보장하는 변경 대상이 정확히 `.venv`/`node_modules` 다. 즉
   "설치는 안 한다" 고 출력한 직후 동의 없이 트리를 바꾸는 경로이며, 가드가 눈감는 것이
   아니라 **설계상 볼 수 없는** 종류다.
2. 잃는 것이 없다. 폴백 verdict 는 R5a¹ 에서 이미 SKIP_WITH_EVIDENCE 로 cap 되어 PASS 가
   불가능하고, 귀속은 `(U,U) → BASELINE_UNRUNNABLE` 로 라우팅돼
   `baseline_unrunnable: true` 를 세운다 — 귀속이 조용히 틀리는 게 아니라 degrade 로
   드러난다. (/qg iter-6 D3 정정: 앞선 판본은 기준선 축이 관측값을 갖는다고 전제한
   비대칭 쌍으로 라우팅을 서술했는데, SR4 이후 **R4 도 폴백에서 건너뛰어 기준선 축까지
   전량 `unrun`** 이므로 그런 쌍은 이 모드에서 도달 불가다. 회귀 락도 함께 옮겼다 —
   락이 그 도달 불가능한 주장을 방어하고 있어서 산문만 고치면 스위트가 red 가 됐다.
   옛 주장의 재도입은 락이 별도로 막는다.)

verifier 의 dispatch 가 **끝난 뒤**, 먼저 **HEAD 축 전용 트리**를 만든다 (한 번, 어댑터
공통). 인자는 R5a¹ 이 잡아 둔 `baseline_sha` — `create-sandbox` 가 리뷰 대상 코드를
봉인한 커밋 `B` 다:

```bash
head_tree_dir=$("${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" create-head \
  "$baseline_sha" "<session-id>")
```

**이 트리는 verifier 의 샌드박스가 아니다 — `$runtime_project_dir` 을 여기 넘기지
않는다.** 두 결함이 이 분리 하나로 닫힌다:

1. **두 축이 같은 환경이라는 전제 (§11 ⑬).** 이 설계가 파는 것은 *"같은 선택을 두 번
   돌려 짝짓는다"* 인데, HEAD 축이 verifier 가 부팅용으로 설치·수정한 상태 위에서 돌면
   기준선 축(merge_base 의 **깨끗한 커밋 트리**)과 환경이 다르다. 그 비대칭은
   `NEW_REGRESSION` 과 **구별 불가능한 모양**으로 나타나고, 어느 쪽이 원인인지는
   verifier 자기보고로만 갈렸다 — 불변식 ②가 *결과값*에서 없앤 self-report 신뢰가
   *실행 환경* 축에 남아 있었다. 이제 양축 모두 오케스트레이터가 만든 커밋 detached
   트리이고, 각 트리에서 도는 것은 어댑터의 `setup_cmd` 뿐이다. **대칭이 구조적이다.**
2. **게이트 자신의 부작용이 만드는 거짓 terminal FAIL (§6.7 S4 · §11 ⑨).** R7 의
   mutation-guard 는 `sandbox_dir` 를 검사한다. 예전에는 HEAD 측 테스트가 바로 그
   트리에서 돌아 `.pytest_cache` 같은 산출물이 거기 떨어졌고, 대상 레포의 `.gitignore`
   가 그것을 덮지 않으면 `disallowed_new_files` 로 잡혀 **게이트가 자기 부작용에 FAIL 을
   냈다.** `make`·`npm-script` 는 내부 명령을 우리가 모르므로 억제할 수단도 없었다.
   이제 그 산출물은 `head_tree_dir` 에 떨어지고 가드는 그 트리를 보지 않는다 — R7 은
   **verifier 의 변경만** 본다. 가드를 느슨하게 하는 방향이 아니라 검사 대상에서
   게이트 자신을 뺀 것이므로 Law 2 표면은 그대로다.

그다음 어댑터마다 (샌드박스가 있을 때만):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/run-test-selection.sh" run \
  "$head_tree_dir" "$runner" bulk "${units[@]}"
```

**bulk 가 green 이면 per-unit 재실행을 하지 않는다** — 집합 전체가 통과했으므로 귀속할
것이 없다. red 일 때만 실패한 unit 에 대해 `per-unit` 으로 재실행한다. 흔한 경우 2회,
비싼 경우에만 정밀해진다.

어댑터의 실행이 끝나면 **R6 이 읽을 두 파일을 쓴다** (/qg iter-8 iteration 3, F1):

```bash
printf '%s\n' "${units[@]}" > "$qg_run_tmp/expected-$runner.txt"
printf '%s\n' "${head_rows[@]}" > "$qg_run_tmp/head-$runner.tsv"
```

`${head_rows[@]}` 는 기준선 축의 `${rows[@]}` 와 같은 규율이다 — 이 어댑터에 대해
**선택한 unit 마다 정확히 한 행**, per-unit 재실행 행이 그 unit 의 bulk 행을 대체하며,
두 단계를 이어붙이면 `diff-test-results.py:88-90` 이 중복 unit 으로 `exit 4` 를 낸다.
`${units[@]}` 는 이 어댑터에 배정된 unit 목록 그대로이고, `$qg_run_tmp/expected-$runner.txt` 는 그것을
**R6 에 독립 입력으로** 넘기기 위한 파일이다 — 아래 `--expected` 문단이 기대는 독립성이
바로 이 파일에서 온다.

**폴백(샌드박스 비활성)에서도 이 두 파일은 쓴다.** 위에서 `run` 을 호출하지 않는
대신 선택한 unit 마다 `<unit>\tunrun\t-` 를 `$qg_run_tmp/head-$runner.tsv` 에 채우고
`$qg_run_tmp/expected-$runner.txt` 는 그대로 쓴다. 파일 자체가 없으면 R6 은 `exit 4` 로 떨어져
`BASELINE_UNRUNNABLE` 대신 대조 실패를 보고한다 — 사유가 바뀐다.

> **이 축의 mode 토큰은 보수적으로 접는다 (/qg iter-7, security-reviewer).** 이 2단계 구조 때문에 한 축이 `bulk` 와 `per-unit` 을 **둘 다** 실행할 수 있는데 `--baseline-mode`/`--head-mode` 는 값이 하나다. 규칙: **이 축의 호출 중 하나라도 `bulk` 였으면 `bulk` 로 적는다.** `per-unit` 은 그 축의 모든 행이 per-unit 호출에서 나왔을 때만이다. 판단이 아니라 기계적 규칙인 이유는 반대 선택이 곧 fail-open 이기 때문이다 — `per-unit` 이라 적으면 도말 degrade 조건(`둘 중 하나라도 bulk`)이 꺼지고, 부분 승격이 남긴 `(F,F)` 행들이 `PRE_EXISTING` 으로 접혀 진짜 회귀를 가린다. 특히 기준선 축은 언제나 `bulk` 로 시작하므로 이 축의 답은 사실상 항상 `bulk` 다.

이 호출은 R5a³ 의 `Agent({…})` 블록 **밖**에 있어야 한다 — 위 호출 주체 불변식.
verifier 가 디버깅 중 테스트를 돌리는 것 자체를 막지는 않지만(Bash 를 갖고 있고 setup
확인에 필요하다), **그 결과가 판정에 들어가는 경로**를 막는다. verifier 의 evidence-log
테스트 결과는 advisory 이고 이 호출 결과가 authoritative 다.

**HEAD 축 트리는 여기서 폐기하지 않는다 — R6 끝까지 살려 둔다.** R6 의 flaky 규칙이
`NEW_REGRESSION` 후보를 **`$head_tree_dir` 에서 1회 재실행**하고 그 결과를
authoritative 로 선언하기 때문이다. (/qg iter-7 리뷰 — 리뷰어 4명 독립 수렴한
CRITICAL. 앞선 판본은 여기서 트리를 지우면서 *"R6 은 이 트리를 필요로 하지 않는다"* 고
적었는데 **다음 스텝이 그 문장을 반증한다.** 그때 도달 가능한 결말 넷 중 둘이
fail-open 이었다: 살아 있는 유일한 HEAD 측 트리인 verifier 샌드박스에서 재실행하면 이
브랜치가 닫았다고 선언한 §11 ⑬ 이 그 자리에서 되열리고 — 게다가 그 재실행이
authoritative 라 verifier 가 만든 상태에서 난 green 이 회귀를 강등한다 — 산출물이 R7 의
검사 대상 트리에 떨어져 §6.7 S4 의 거짓 terminal FAIL 까지 함께 살아난다.)

**Step R5b 실패 라우팅 (R6·R7 표와 같은 규율 — 관측 없음은 음성 결과가 아니다).**

| R5b 결과 | 라우팅 |
|---|---|
| `create-head` 가 non-zero | **HEAD 축을 관측하지 못했다.** stderr 를 verbatim 노출하고, 선택한 unit 마다 `<unit>\tunrun\t-` 로 HEAD 행을 채운 뒤 `verification` 을 **`degraded`** 로 두고 R6 으로 간다. `$runtime_project_dir` 로도 `$project_dir` 로도 **폴백하지 않는다** — 전자는 §11 ⑬ 을, 후자는 이 스텝의 폴백 규칙을 위반한다. |
| `run` 이 non-zero (러너 부재 exit 3 제외 — 그것은 정상 신호다) | 같은 처리. 그 어댑터의 unit 을 `unrun` 으로 채우고 `verification: degraded`. |
| 위 둘 다 아님 | 정상 — R6 으로 간다. |

이 표가 없던 판본에서는 `create-head` 가 죽으면 `head_tree_dir` 이 빈 문자열이 되고
`run ""` 가 exit 2 + 빈 stdout 을 내, 행 부재가 **"고른 것이 사라졌다" 쪽 카테고리로**
라벨됐다 — 방향은 fail-closed 지만 **사용자에게 가는 사유가 틀렸다** ("HEAD 워크트리를
만들지 못했다" 가 진실이다). 그 카테고리 이름을 여기 리터럴로 적지 않는 이유는 이
창에 그 토큰이 0회여야 한다는 별도의 회귀 락이 있기 때문이다 — 정정 노트가 옛 값을
인용하면 그 인용 자체가 락 위반이 된다. 또 verifier 는
`evidence_dir` 로 메인 레포 경로와 세션 id 를 받고 Bash 를 쥐므로 자기 턴에
`head-<sid8>` 경로를 미리 심어 이 실패를 **결정론적으로 유발**할 수 있다. 그 경우에도
위 표가 있으면 결과는 "검증 못 함" 으로 정직하게 보고되고 PASS 는 불가하다.

**Step R6 — 대조 (결정론).** 어댑터마다 한 번씩:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/diff-test-results.py" \
  --expected "$qg_run_tmp/expected-$runner.txt" \
  --baseline "$qg_run_tmp/baseline-$runner.tsv" \
  --head "$qg_run_tmp/head-$runner.tsv" \
  --granularity "$granularity" --runner "$runner" \
  --baseline-mode "$baseline_run_mode" --head-mode "$head_run_mode" \
  --baseline-detected "$baseline_detected" > "$qg_run_tmp/per-adapter-$runner.yaml"
```

**네 경로를 변수가 아니라 리터럴로 적는 이유는 R-init 에 있다** — 어댑터별 파일은 정의
지점을 갖지 않고 쓰는 자리에서 `$qg_run_tmp/<역할>-$runner.<확장자>` 로 전개한다. 여기
`$runner` 는 이 루프가 도는 어댑터이므로 값이 이 자리에서 정해진다.

`--expected` 는 R1b 가 고른 unit 목록이다 — **두 산출물의 상호 대조가 아니라 독립
입력**이라야 두 스크립트가 같은 정규화 버그로 같은 unit 을 대칭 누락할 때 잡힌다.

`--granularity` 는 손으로 고르지 않는다 — **`--runner` 가 결정하며 스크립트가 어댑터
표 소유자에게 물어 대조한다** (/qg iter-5 C5). 어긋난 쌍(예: `--runner cargo
--granularity file`)은 아래 도말 degrade 의 `granularity == "bulk"` 절을 발화시키지
않아 양측 red 인 bulk 실행을 `PRE_EXISTING` → `closed` → **PASS 적격**으로 만들었다.
확인이 필요하면 소유자에게 직접 물으면 된다 (순수 함수, 트리 불필요):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/run-test-selection.sh" granularity "$runner"
```

불일치·미지 러너·소유자 부재는 전부 **exit 4** 다 — "확인할 수 없었다"를 "확인됐다"로
읽는 경로가 없다.

`--baseline-mode` / `--head-mode` 는 R4 와 R5b 가 **각각** `run` 에 넘긴 실행 mode 다
(`bulk` 또는 `per-unit`). 어댑터의 `--granularity` 와 **다른 축**이며 둘을 같은 것으로
쓰면 안 된다. 배치로 돌면 `run` 이 **한 종료 코드를 전 unit 에 찍으므로**(도말), 입도가
그보다 잔 어댑터에서는 양측 red 가 전부 `PRE_EXISTING` 으로 접혀 `closed` → PASS 가
된다 — 실제로는 그중 어느 것이 회귀인지 **판정되지 않은** 상태다. 스크립트는
`granularity != bulk` + `pre_existing > 0` + **둘 중 하나라도 `bulk`** 를 `degraded` 로
내린다. **둘 다 필수 인자다** — 하나라도 생략하면 exit 2.

**축을 접지 않는다 (/qg iter-6 iteration 2 — 리뷰어 3명 독립 수렴).** 앞선 판본은 이
자리에 인자가 하나(`--mode`)뿐이었고, 양측 mode 가 다를 때 *"배치였던 쪽을 기준으로
`bulk` 를 넘긴다"* 는 규칙으로 **두 독립 호출을 한 토큰에 접었다.** 그 접기의 유일한
집행자가 그 토큰 자신이었으므로, `per-unit` 이라 적는 것만으로 `degraded` 가 `closed` 로
뒤집혔다 — R8 PASS 행의 결정론 조건이 전부 충족된다(실측). 특히 위험한 조합이
**기준선 bulk × HEAD per-unit** 인데, R4 는 기준선을 언제나 `run … bulk` 로 돌리므로
그게 예외가 아니라 **기본 경로**다. 축을 쪼개면 각 호출이 자기 mode 를 자기 자리에
적으므로 접기가 사라진다.

**한 번 시도했다가 철회한 것:** 데이터에서 도말을 추론하는 것(present unit ≥2 인데
`(status, exit)` 쌍이 1종). (a) 그 서명이 **head 축만** 봐서 위험한 축을 못 봤고,
(b) 정직한 per-unit 실행이 "고른 unit 전부 양측 red" 일 때를 degrade 시켜, 이 설계가
*"stale red 가 첫 실행부터 게이트를 막으면 쓸 수 없다"* 를 이유로 통과시키기로 한
결정을 되돌렸다. 순감이라 철회했다.

**남은 것(정직한 잔여 — §11 ⑰):** 이 값들의 **provenance 는 여전히 검증되지 않는다.**
형제 `--baseline-detected` 와 같은 등급이다. 닫으려면 `run` 이 자기 실행을 증거 파일로
남기고 이 스크립트가 그것을 읽어야 하는데, **기준선이 캐시 적중으로 올 때는 그 실행이
아예 없어** 계약이 성립하지 않는다. 그러니 여기서 mode 를 "고르지" 말고 **각 호출이
실제로 무엇이었는지 그대로 적어라** — 틀리게 적으면 원장이 조용히 틀린다.

`--baseline-detected` 는 R4②-a 의 `probe` 가 기준선 트리에서 **`usable: yes`** 를 낸
러너 집합이다 — `detect` 가 낸 집합이 **아니다** (/qg iter-5 SR1: `detect` 는 선언만
보고, 캐시 전량 적중이면 실행 관문이 한 번도 돌지 않는다. R4②-a 를 볼 것).
`usable: yes` 가 0개면 `NONE`; R-init 이 `degraded: yes` 이거나 `same_as_head: yes`
**이면서 워킹 트리가 clean** 이어서 R4 를 건너뛴 경우도 `NONE` — `same_as_head`
**단독**은 스킵 사유가 아니다, R4 의 정정을 볼 것.
**필수 인자다** — 생략하면 exit 2 로 죽는다. 선택 인자로 두고 부재를 "전부 감지됨"
으로 읽으면, 값을 못 구한 호출자(= 기준선 트리를 안 만든 호출자)가 정확히 이 검사가
막으려던 경로로 통과한다. `--runner` 가 이 집합에 없으면 그 어댑터의 모든 unit 은
기준선 축이 `unrun` 으로 내려가 `BASELINE_UNRUNNABLE` → `degraded` → PASS 불가가
된다. 캐시가 무엇을 내줬든 상관없다.

**flaky — 재실행은 정확히 1회다 — green 이 나올 때까지가 아니다.** `NEW_REGRESSION`
후보만 **`$head_tree_dir` 에서** 1회 재실행한다:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/run-test-selection.sh" run \
  "$head_tree_dir" "$runner" per-unit "${flaky_candidates[@]}"
```

**재실행 결과를 `$qg_run_tmp/head-$runner.tsv` 에 반영하는 것까지가 이 규칙이다 (/qg iter-7 iteration 2,
codex).** 그러지 않으면 *"마지막 호출의 결과가 authoritative"* 라는 바로 아래 문장이
닿을 데가 없다 — 대조는 여전히 **원래의 실패 행**을 읽는다. 순서:

1. 재실행 stdout 을 **임시 TSV** 로 받는다 (기존 행 파일을 직접 덮어쓰지 않는다).
2. `run` 이 non-zero 면(러너 부재 exit 3 제외) 그 재실행은 **관측 실패**다 — 위 R5b
   라우팅과 같이 `verification: degraded` 로 두고 **원래 행을 유지**한다. 재실행이
   죽은 것을 "재실행 결과 없음 = green" 으로 읽지 않는다.
3. 성공하면 재실행한 unit 의 행만 **교체**한다(추가가 아니다 — 같은 unit 이 두 행이면
   `diff-test-results.py` 가 중복 unit 으로 exit 4 를 낸다).
4. 교체된 파일을 원자적으로 배치한 뒤에야 `diff-test-results.py` 를 다시 부른다.

**어느 트리인지가 이 문장의 load-bearing 부분이다.** "HEAD 에서" 라고만 적었던 앞
판본은 R5b 가 그 트리를 이미 지운 뒤였고, 살아 있던 유일한 HEAD 측 트리가 verifier
샌드박스였다 — 거기서 재실행하면 §11 ⑬ 이 되열리는데 그 결과가 **authoritative** 로
선언돼 있어 verifier 가 만든 상태의 green 이 진짜 회귀를 강등한다. `$runtime_project_dir`
도 `$project_dir` 도 이 자리에 오면 안 된다. 또 fail 이면 확증 `NEW_REGRESSION`, pass 면
**귀속 카테고리가 아니라 원장 note 로** 기록한다 — `attribution` 차원에
`derived: flaky <unit> (기준선 pass · HEAD 1회 fail → 재실행 pass)` 한 줄을 남기고
보고서에 올리되 게이트를 FAIL 시키지 않는다. `FLAKY` 를 **토큰처럼** 적었던 앞 문장은
어디에서도 산출되지 않는 유령이었다 (/qg iter-5 SF2): `CATEGORIES` 8종에 없고
`diff-test-results.py` 가 그 문자열을 내지 않으므로, 그것을 찾는 소비자는 영원히
못 찾는다. 8종 카테고리 계약(AC11)은 닫힌 집합이라 여기에 9번째를 더할 수 없다 —
그래서 카테고리가 아니라 note 다. 기준선에서 이미 red 인 것은
재실행 대상이 아니다(이미 `PRE_EXISTING`). 재실행 후에는 갱신된 `--head` 로
`diff-test-results.py` 를 다시 호출하고, **그 마지막 호출의 결과가 authoritative** 다.
여기서 위험은 false green 이 아니라 false red 이고, **무한 재실행이 바로 false green
경로**이므로 1회로 잠근다.

그다음 어댑터 YAML 들을 집계한다:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/diff-test-results.py" --aggregate \
  --expected-adapters "$adapter_count" "$qg_run_tmp"/per-adapter-*.yaml > "$aggregate_yaml"
```

**glob 이지 모델이 만든 배열이 아니다 (/qg iter-8 iteration 3, F11).** 앞 버전은
`"${per_adapter_yamls[@]}"` 를 넘겼는데 그 이름은 **이 문서 어디에서도 대입되지 않는다** —
feature 커밋 이래 사용 1건·대입 0건이었다. 배열을 되살리면 `--expected-adapters` 의 개수
대조가 *"생산된 YAML 개수 vs 기대 개수"* 가 아니라 *"모델이 적은 목록의 길이 vs 기대
개수"* 가 되어 대조 양쪽이 같은 출처에서 나온다. `$qg_run_tmp` 는 실행마다 새로 만들어져
stale 파일을 주울 수 없으므로, glob 은 **실제 생산물**을 세게 만들어 그 개수 대조에
비로소 이빨을 준다.

집계까지 끝나면 **이제** HEAD 축 트리를 폐기한다 (R4③ 이 기준선 트리를 폐기하는 것과
대칭 — 두 트리 다 일회용이지만 HEAD 축의 수명은 **자기 축의 실행 + flaky 재실행 + 대조**
까지다):

```bash
if [[ -n "${head_tree_dir:-}" && -d "$head_tree_dir" ]]; then
  "${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" remove "$head_tree_dir"
fi
```

**조건부인 이유 (/qg iter-7 iteration 2, codex).** R5b 라우팅은 `create-head` 실패 후에도
`unrun` + `degraded` 로 **계속 진행**하도록 지시한다. 그 경로에서 `head_tree_dir` 은 빈
문자열이므로 무조건 `remove` 를 부르면 그 호출이 죽고, **이미 확정된 degrade 결과가
R7·R8 에 도달하기 전에 파이프라인이 끊긴다** — 정리 실패가 판정을 삼키는 형태다.
정리는 판정 경로가 아니므로 여기서 조용히 건너뛰는 것이 옳다(트리가 없으면 지울 것도
없다). 트리는 있는데 `remove` 가 실패하는 경우는 §11 ⑳ 의 누수이고, 그 사실은 stderr 로
드러나되 verdict 를 바꾸지 않는다.

**이 폐기는 R6 의 *모든* 종료 경로에서 실행한다 — 정상 종료만이 아니다
(/qg iter-7 iteration 2, security-reviewer).** 아래 R6 exit-code 라우팅이
`diff-test-results.py` 의 exit 4·키 판독 실패를 *"stderr 노출 + attribution degraded →
R8"* 로 보내는데, 그 경로가 폐기를 건너뛰면 `head-<sid8>` 이 남는다. 그리고 그 트리의
내용물은 테스트 산출물이라 다음 `create-head` 의 **non-force** 제거가 거부돼 die 하고,
같은 세션의 재시도와 이후 실행이 전부 `verification: degraded` 로 떨어진다 — **PASS 에
영영 도달할 수 없는 세션**이 된다. 방향은 fail-closed 라 우회는 아니지만 가용성 결함이다.
degrade 로 빠지는 경로에서도 폐기를 먼저 수행한 뒤 R8 로 간다.

R7 은 `sandbox_dir` 만 검사하므로 이 트리가 R6 까지 살아 있어도 가드에 닿지 않는다 —
§6.7 S4 의 봉쇄는 *수명*이 아니라 *다른 트리*라는 사실이 만든다. 다만 수명이 R6 까지
늘어난 만큼 §11 ⑳ 의 누수 창도 그만큼 넓어진다(같은 라운드에 ⑳ 에 반영했다).

**stdout 을 `$aggregate_yaml` 파일로 남긴다** — 값을 눈으로만 읽고 버리면 R8 의 전사
대조(`check_qa_ledger.py --aggregate`)가 대조할 원본이 없다. 이 파일이 R8 까지 살아야
한다.

`verdict_input`(`confirmed_product_defect` / `silent_drop` / `baseline_unrunnable`)과
`attribution_status` 를 캡처한다. 이 집계를 손으로 하지 않는다 — N 개 YAML 을 읽고
최악값을 고르면 불변식 ②가 결과값에서 없앤 "모델 요약이 판정을 결정"이 집계 레이어에서
재입장한다. 입력 개수가 안 맞으면 스크립트가 exit 4 로 fail-closed 한다.

**R6 exit-code routing (실패한 대조는 결코 PASS 가 아니다).** 위 두 호출 —
어댑터별 호출과 `--aggregate` 호출 **양쪽** — 에서 stdout 과 **exit code 를 함께**
잡는다. R7 표와 같은 이유의 오케스트레이션 층 규칙이다: 판정 입력을 *만드는* 단계가
죽었는데 그 죽음이 조용하면, 캡처되지 않은 `verdict_input` 이 "결함 보고 없음"으로
읽혀 R8 의 PASS 행(`verdict_input` 3플래그 전부 false)을
그대로 만족시킨다. 값의 부재는 음성 결과가 아니다.

| 대조 결과 | R6 라우팅 |
|---|---|
| exit 0 + `verdict_input` 3키와 `attribution_status` 를 모두 읽음 | 정상 — 그 값으로 R8 로 간다 |
| **exit 4**(어댑터 개수 불일치 · 입력 파일 부재/파싱 실패 · 중복 unit 행 · 미지 상태값), **그 외 non-zero**, 또는 **3키·`attribution_status` 중 하나라도 못 읽음** | stderr 를 그대로 노출하고 원장의 `attribution` 을 **`degraded`** 로 적은 뒤 **verdict 를 PASS 로 올리지 않는다**(≤`SKIP_WITH_EVIDENCE`). 캡처 실패를 "결함 없음"으로 읽지 않는다 |

어댑터별 호출 하나가 이 경로로 떨어지면 그 어댑터 YAML 은 신뢰할 수 없다. **그렇다고
`--expected-adapters` 를 줄여 개수를 맞추지 않는다** — 개수 대조가 바로 그 누락을 잡는
장치이므로, 분모를 낮추면 백스톱을 스스로 끄는 것이다. 그 어댑터를 `verification`
차원의 degrade 사유로 열거하고 집계는 원래 개수로 돌린다.

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
| exit 0 + `forced_downgrade: no` (all §6.1 snapshot keys valid) | no product mutation → proceed to R8 normally |
| exit 0 + `forced_downgrade: yes` | cap verdict at FAIL; surface `tracked_diff` / `disallowed_new_files` / `guard_flags` as evidence |
| **exit 4** (`guard_fail`), OR any other non-zero exit, OR a missing/invalid `forced_downgrade` key, OR a `guard_error:` line present | treat as `forced_downgrade: yes` → cap verdict at FAIL; surface the guard's `guard_error` + **stderr verbatim**; mark the Runtime gate failed. **Never read an errored or garbled guard as PASS** (indeterminate ≠ clean). |

A digest mismatch (the verifier forged the snapshot) surfaces here as **exit 4** with
`guard_error: snapshot integrity check failed` — the seal the guard checks is held by
the orchestrator, out of the verifier's reach.

**Fallback working-tree guard (read-only mode only).** When the sandbox was disabled
(Exit 3), do NOT run the sandbox `mutation-guard`. The verdict is already capped at
SKIP_WITH_EVIDENCE (R5a¹); this guard is a pure SAFETY SIGNAL, not a verdict input.
After the R5a³ dispatch, recompute `fallback_post` (porcelain + tracked content
tree-hash, **same recipe as `fallback_pre`**). If anything changed — a porcelain entry
in `fallback_post` that is not in `fallback_pre`, **or** a differing tree-hash — emit a
loud warning to user-visible stdout AND record it in `evidence_dir`:
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
> "영향분을 못 돌림"을 만족한다. 이 규칙이 없으면 러너 어댑터 9종 미지원 레포에서 **테스트가 한
> 개도 안 돈 채 PASS** 가 나온다.

구조 게이트를 돌린다:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/check_qa_ledger.py" \
  --aggregate "$aggregate_yaml" \
  --assign-rows "$assign_rows_file" \
  "$evidence_dir/runtime-evidence.md"
```

non-zero 면 stderr 를 verbatim 으로 노출하고 **verdict 를 PASS 로 올리지 않는다**.

**`--aggregate` 는 필수이고, 이 게이트가 여기서 하는 일은 위 전사의 대조다 (§11 ⑱).**
바로 앞 문단이 *"R6 이 낸 `attribution_status` 를 그대로 옮긴다"* 고 지시하는데, 옮겨
적은 값이 기계값과 같은지는 지금까지 아무도 보지 않았다 — `degraded` 를 `closed` 로
옮기면 floor 5차원 전부 `closed` 가 되어 **PASS 행을 그대로 만족시킨다.** 이제 게이트가
두 값을 대조하고 다르면 non-zero 를 낸다. 인자를 선택으로 두지 않는 이유는 형제
`--baseline-detected` 와 같다: 선택이면 넘기지 않은 호출자가 조용히 면제받고, 그
면제가 이 인자가 닫으려는 fail-open 의 모양 그 자체다.

**`--assign-rows` 도 필수이고, 바로 위 인용 블록의 `unclaimed` 규칙을 집행한다 (§11 ㉓).**
그 규칙은 지금까지 **읽는 기계가 없는 산문 한 문장**이었다 — `assign` 의 구조적 거부
3곳(워크트리 밖 unit · `unittest_can_judge` 실패 · 실행 수단 없음)이 전부 이 문장에
종착했고, `unclaimed` unit 은 어느 어댑터의 unit 목록에도 없어 `--expected` 에도 안
들어가므로 `SILENT_DROP` 백스톱마저 닿지 않았다. 즉 **한 번도 안 돈 unit 을 두고 3플래그
false + 5차원 `closed` → PASS** 가 성립했다. 이제 게이트가 `$assign_rows_file` 에서
직접 세고, 1건 이상인데 `floor:verification` 이 `degraded` 가 아니면 non-zero 를 낸다.

**개수가 아니라 경로를 넘기는 이유.** 처방의 원래 형태는 `--unclaimed-count <N>` 이었다.
그대로 두면 N 은 *당신이 옮겨 적는 숫자*가 되고, 그것은 바로 위 `--aggregate` 가 방금
닫은 전사 구멍을 같은 이음매에 다시 뚫는 것이다 — `0` 하나로 검사가 사라진다. 그래서
`--aggregate` 와 같은 모양(경로를 받아 스크립트가 판정)을 쓴다.

**닫히지 않은 이웃 (과장하지 않는다).** 이 두 대조는 *전사* 축만 닫는다. `$aggregate_yaml`
과 `$assign_rows_file` 이 정말 그 실행의 스크립트 출력인지(custody)는 여전히 검사하지
않는다 — §6.7 S1 과 같은 축이며 열려 있다. 또 `verdict_input` 3플래그는 원장에 실리지
않으므로 이 경로로는 대조할 대상이 없다. 그리고 **배정 행이 0개인 경우(빈 스코프)는
이 인자가 판정하지 않는다** — `unclaimed` 0건과 구분이 안 되므로 여기서 닫히는 것처럼
쓰면 거짓이다. 그 축은 §11 ⑭ 이며 열려 있다.

verdict 결정:

| verdict | 조건 |
|---|---|
| `PASS` | floor 5차원 전부 `closed` **and** `confirmed_product_defect: false` **and** `silent_drop: false` **and** `baseline_unrunnable: false` **and** `forced_downgrade: no` **and** 상황별 층 통과 |
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
- **Yes, retry** → increment resolution counter; if exceeds env limit, fall through to Skip with evidence. Otherwise re-create the sandbox (Step R5a¹) and re-capture the new output's `sandbox_dir` (line 1), `baseline_sha` (line 2), and `snapshot_digest` (line 3) with the same three successive `IFS= read -r` + digest-strip idiom as R5a¹ — refreshing **all three** orchestrator variables. create-sandbox emits a NEW commit `B` AND a NEW snapshot (hence a new digest) each call, so reusing the old `baseline_sha` makes the guard `guard_fail "bad baseline sha"` and reusing the old `snapshot_digest` makes it `guard_fail "snapshot integrity check failed"` — both false FAILs. The new snapshot is auto-recorded in the new gitdir; the stale sandbox + its old snapshot are force-removed by R5a¹'s idempotent cleanup. Then re-dispatch runtime-verifier with the refreshed `sandbox_dir` and re-run the remaining steps in the order given in the next paragraph — R7 is called as 3-arg with the refreshed `snapshot_digest`, NOT directly after the dispatch. (Fix the parse order: capturing the digest as line 2 swaps `baseline_sha`/`snapshot_digest` and fails-closed every run.)

  **재시도는 R5b·R6 도 다시 돈다 — verifier 재-dispatch 만으로 끝나지 않는다.** 재시도가 만드는 것은 **새 트리**이고, 이전 `$qg_run_tmp/head-$runner.tsv` 는 이미 폐기된 트리에서 나온 행이다. 그것을 그대로 R6 에 넘기면 `.env` 하나 고쳐 초록이 된 트리에서 옛 red 로 `confirmed_product_defect: true` 가 서서 **고쳐진 코드에 FAIL** 이 나고, 반대 방향은 더 나쁘다 — 옛 green 행이 재시도가 새로 만든 회귀를 가린다. 재-dispatch 뒤 순서는 **R5b(HEAD 축 재실행) → R6(대조 + 집계 재호출) → R7 → R8** 이고, 이전 HEAD 행은 **버린다**(덮어쓰지 말고 새로 만든다 — 부분 덮어쓰기는 두 트리의 행을 한 파일에 섞는다). 기준선 측 R4 는 다시 돌리지 않는다: `merge_base` 가 그대로라 캐시 키가 같고, 기준선은 재시도로 바뀌지 않는다.

  **재시도의 R5b 는 `create-head` 를 refresh 된 `baseline_sha` 로 다시 호출한다.** create-sandbox 는 호출마다 **새 커밋 `B`** 를 낸다 — 위에서 `baseline_sha` 를 재포착하는 이유가 그것이다. 그 재포착된 값을 `create-head` 에 넘기지 않고 옛 `baseline_sha` 를 재사용하면, HEAD 축 트리가 **재시도가 고치기 전 코드**에 붙는다. 그러면 R7 의 mutation-guard 는 새 트리를 보고 통과시키는데 R6 이 대조하는 행은 옛 코드에서 나온 것이라, 실패가 verdict 층이 아니라 **귀속 층에서 조용히** 일어난다 — 트리가 존재하고 행이 나오므로 어떤 degrade 신호도 서지 않는다. `create-head` 는 refresh 된 `baseline_sha` 로 다시 부른다 — 그리고 **틀린 값을 넘기면 이제 죽는다**: `create-head` 는 넘어온 sha 가 이 세션 샌드박스의 봉인 커밋과 같은지 대조하고 다르면 die 한다(옛 `B` 도 `merge_base` 도 거부). **다만 '이전 트리는 그 호출이 정리한다'는 보장이 아니다.** `make_detached_worktree` 는 **non-force** `git worktree remove` 만 시도하고, 거부되면 조용히 파괴하는 대신 die 한다 — 그런데 누수된 HEAD 축 트리의 내용물은 정의상 테스트 산출물이고, §11 ⑨ 가 적었듯 `make`·`npm-script` 계열은 그것을 억제할 수단이 없어 **비-ignored 로 남을 수 있다.** 그 경우가 정확히 non-force 가 거부하는 경우이므로 재사용이 아니라 loud die 가 나고, 그 세션에서는 HEAD 축을 다시 만들 수 없다(경로가 `<prefix>-<sid8>` 로 고정이므로). die 메시지가 안내하는 수동 제거 또는 새 세션이 유일한 복구다 — §11 ⑳ 에 등급과 함께 등재했다.
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
