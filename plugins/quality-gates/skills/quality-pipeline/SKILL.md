---
name: quality-pipeline
description: >
  Runs the full quality-gates pipeline in a single assistant turn. Triggered by
  `/qg`, "run quality gates", "verify my implementation", "check code quality",
  or "is my PR ready to merge". Dispatches up to two gates (review, then
  optionally runtime verification) serially; progression and fix-loop decisions
  surface to the user via AskUserQuestion. A gate argument (`/qg both|review|runtime`)
  sets the scope. On non-aborted completion the pipeline simply ends; publishing
  a PR-understanding comment is a separate explicit step (`/qg-publish`) — not a
  gate, and not an automatic continuation.
cost_class: variable
allowed-tools:
  # Group 1 — Preflight scripts (실행 순서: setup → trivia)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh:*)
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

# Quality Gates — In-Turn Orchestrator (v6.0.0)

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
   - [Preflight](#preflight) — kill switch / setup-qg
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
   - Final summary template
   - [kill switch](#kill-switch) — DEVBREW_QUALITY_GATES_DISABLE* 색인, 각 스위치가 실제로 검사되는 스텝으로 포인터만
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

**Step P0b — Resolve the plugin root.** `CLAUDE_PLUGIN_ROOT` is **not set in the
Bash tool environment**. Run every script path below with the installed
plugin-root substituted; when dogfooding inside the devbrew repo that is
`./plugins/quality-gates`. Self-contained fences derive it in-line:

```bash
QG="${CLAUDE_PLUGIN_ROOT:-./plugins/quality-gates}"
```

Shell state does not carry between Bash calls — every fence that needs `$QG`
assigns it in that same fence. Do not hoist the assignment.

**Step P1 — Global kill switch.** If `DEVBREW_QUALITY_GATES_DISABLE=1`,
emit `[quality-gates] disabled via DEVBREW_QUALITY_GATES_DISABLE=1` and
return immediately. Do NOT call setup-qg.sh or any agent.

**Step P2 — Setup state.** Run:

```bash
QG="${CLAUDE_PLUGIN_ROOT:-./plugins/quality-gates}"
"$QG/scripts/setup-qg.sh" --ensure $ARGUMENTS
```

`setup-qg.sh --ensure` creates the per-session state file
(`.claude/quality-gates/<sid>/pipeline.md`) with minimal v1.32.0 schema.
Exit non-zero → surface stderr verbatim and abort.

**Preflight 는 P2 에서 끝난다.** SID 존재·패턴 검증은 `setup-qg.sh` 가 P2 에서
정규식으로 수행하고 exit 1 한다 — Preflight 자신은 별도 SID 검증 스텝을 갖지
않는다.

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
  `DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE=1`, pass `spec_path: none` to the
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

1. Run `scripts/detect-runtime.sh` (plugin root per Step P0b) to get the manifest with `requires_decision` flags. This runs whenever gate scope = both — the manifest is also threaded to the Runtime gate's R5a³ dispatch.
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
        {label: "Run all + ask on block", description: "Opt into all; block_policy=ask (mid-run question, bounded by DEVBREW_QUALITY_GATES_RUNTIME_MAX_RESOLUTIONS)."},
        {label: "Boot nothing",            description: "Skip every requires_decision surface. The Runtime floor (R4/R5b differential test run) still runs — it is the orchestrator's, not the verifier's."},
        {label: "Stop on block",            description: "Opt into all; block_policy=stop (abort the gate at the first unrecoverable block)."}
      ],
      multiSelect: false
    }
  ]
})
```

**Upfront approval is authoritative.** A surface opted in here is NOT re-asked mid-run. A mid-run question fires only for a *newly discovered* block when `block_policy=ask`, and the total number of such mid-run questions is itself bounded by `DEVBREW_QUALITY_GATES_RUNTIME_MAX_RESOLUTIONS`.

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

Run `scripts/check-trivia.sh` (plugin root per Step P0b). Exit code:
- 0 = trivia detected → skip all gates. Print:
  > `Trivia diff — all gates skipped (one-sentence diff per CLAUDE.md trivia escape).`
- 1 = non-trivia → proceed to the Review gate.
- any other non-zero (script crash / environment failure) → print stderr
  verbatim and abort the pipeline. Do NOT silently treat as non-trivia.

## Review gate

Iterative fix-loop, `max_review_iterations = 5` (hard-coded constant).

For each iteration N (1..5):

1. **Resolve the review scope** — `paths` / `branch` / `session` (`session` = the default: no `branch` arg, no `--paths`). **There is no preflight scope**; nothing upstream hands you a file set, so you derive it here, from git, every turn:

   ```bash
   QG="${CLAUDE_PLUGIN_ROOT:-./plugins/quality-gates}"   # plugin root per Step P0b
   MERGE_BASE=$("$QG/scripts/resolve-baseline.sh" | awk '$1=="merge_base:"{print $2}')
   git diff --name-only "$MERGE_BASE"..HEAD    # (a) committed on this branch
   git diff HEAD --name-only                   # (b) tracked, not yet committed
   git ls-files --others --exclude-standard    # (c) untracked and not ignored
   ```

   `session` = **(a) ∪ (b) ∪ (c)** · `branch` = **(a)** · `paths` = what the `--paths` globs resolve to. Never re-derive a base yourself — `resolve-baseline.sh` owns it (two consumers on different baselines is the C2 failure), and its `degraded: yes` means the set is undeterminable: carry that to Step 4.5's degraded branch instead of silently calling it 0. The size of the set you end up with is `$resolved_scope_file_count` (Step 4.5) and it is what you feed to `scout.py`.

   **Deriving from git is what makes the scope tool-agnostic** — git reports a changed file the same way whichever tool produced it, so a file written by a Bash heredoc or `sed -i` is in the default scope exactly like one written by `Write` (A20). Never source the scope from a per-session record of "files this turn edited": such a record is produced by a hook keyed on the writing tool's name, so every write outside that name list vanishes from the scope silently — the pre-5.0.0 defect this release removed.

   **Scope transparency (P8 determinism-economy):** iteration N=1에서, 스코프가 *암묵 default(session)* 로 — 즉 `branch`/`--paths` arg 없이 — 풀렸다면 사용자-가시 한 줄을 출력한다: `> Review scope: session (<COUNT> changed files). 전체 PR/브랜치는 /qg branch.` (`<COUNT>` = `$resolved_scope_file_count` — 정의는 Step 4.5 "Resolved-scope file count" 참조, `check-review-scope.sh` 산출값이 아니다). 명시적 `/qg branch`·`--paths`는 사용자가 scope를 이미 골랐으므로 출력하지 않는다. 이는 결정론 가드가 **아니다** — git 비교·차단 로직 없이 "scope가 암묵 session인가?"만 본다. 자연어로 표현된 scope 의도(예: "전체 PR", "지금 브랜치")는 별도 토큰 parser 없이 모델이 자유롭게 해석해 branch scope로 라우팅한다 (non-load-bearing routing은 모델 신뢰; `/qg branch`는 결정론적 escape hatch로 유지).

**Step 1b — Changes-exist signal (iteration N=1 only).** Before dispatching the
scout, run the read-only changes-exist signal **once** and cache it for the rest
of this turn (C3 — single call; the cached values are consumed by the
honest-verdict floor at Step 4.5):

```bash
QG="${CLAUDE_PLUGIN_ROOT:-./plugins/quality-gates}"
"$QG/scripts/check-review-scope.sh"
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

2. Dispatch the scout: `Bash(scripts/scout.py ...)` (plugin root per Step P0b) — compute its
   metrics from the review scope you resolved at step 1 (the git-derived changed-file set, the
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

   **Kill switch — `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1`.** Tier A 를
   *모델이* 스코프 판단으로 뺄 수는 없지만, *사용자는* 끌 수 있다. 이 둘은 다른
   것이다: 앞은 라우팅 재량이고 뒤는 사용자 소유의 opt-out 이다(CLAUDE.md
   Plugin Shape — *"모든 reviewer는 opt-out 가능"*, 그리고 *"kill switch는 보안
   컨트롤"*). 매 iteration, 바로 아래 `security-reviewer` Agent 리터럴을 발행하기
   **직전에** 이 게이트를 통과시킨다 — 게이트는 여기, dispatch 지점에 선다:

   IF `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1`:
   1. 아래 `quality-gates:security-reviewer` Agent 리터럴을 **발행하지 않는다.**
      바로 다음의 `quality-gates:adversarial` 리터럴과 Tier B(codex)·Tier C 는
      **그대로 fire 한다** — 꺼지는 것은 이 하나뿐이다.
   2. `adversarial` 의 `phase1_findings` 슬롯에는 실제로 받은 것만 넣는다
      (Tier C + codex). 없는 리뷰어 몫을 있는 것처럼 채우거나 대신 지어내지 않는다.
   3. **loud advisory** — 이 줄을 사용자에게 그대로 보인다:
      > `> [quality-gates] security-reviewer disabled via DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1 — 이 iteration 에는 보안 리뷰가 없었다 (Tier A floor 결손).`
   4. 이 iteration 에 대해 `$security_review_absent = yes` 로 두고 **Step 4.5 의
      판정 표면까지 들고 간다**(아래 Security-review-absent advisory). 배너 한 줄로
      끝내면 verdict 만 읽는 사람에게는 결손이 보이지 않는다.

   ELSE: `$security_review_absent = no` — 아래 리터럴을 평소대로 발행한다.

   **왜 codex kill switch 와 달리 loud 인가.** 형제 스위치
   `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1` 은 [Codex skip 안내](#codex-skip-안내)의
   silent 표에 있다(*"사용자가 직접 껐다. 자기가 한 일을 다시 알릴 필요가 없다"*).
   여기서는 그 논리를 따르지 않는다 — codex 는 Tier B(가용성 floor, 다양성 층)이고
   `security-reviewer` 는 **Tier A floor 두 명 중 하나**다. floor 구성원이 빠지면
   그 iteration 의 `clean` 이 뜻하는 바 자체가 달라지므로, 사용자의 의도적 opt-out
   이더라도 **판정을 읽는 사람**에게 결손이 보여야 한다. 두 스위치를 "일관성" 명목
   으로 같은 취급으로 합치지 말 것.

```
Agent({
  subagent_type: "quality-gates:security-reviewer",
  // **처분** — consumer=plugins/quality-gates/scripts/synthesize_findings.py · fail-open
  description: "Security review (Review gate iter N)",
  prompt: "Run code-level security review on the current diff.
    project_dir: \"$project_dir\"
    diff_scope: <the review scope you resolved at step 1: session (git-derived changed files) / branch (git diff vs base) / paths (--paths globs)>
    plan_path: <path or 'auto'>
    iteration: N
    <…scout-supplied context…>"
})

Agent({
  subagent_type: "quality-gates:adversarial",
  // **처분** — consumer=plugins/quality-gates/scripts/synthesize_findings.py · fail-open
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
   `DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE=1` empties the slot (the script reads the env
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

kill switch는 `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1`이다. 이 게이트는 현재 **산문**이며 모델이
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
| `killswitch_config_missing` | 형제 설정 `codex-killswitch.conf`가 없다 — `plugins/quality-gates/scripts/codex-killswitch.conf` 확인 |
| `killswitch_config_incomplete` | 위 conf에 `CODEX_KILL_SWITCH_VAR` 값이 없다 — conf 파일 점검 |
| `killswitch_config_invalid` | 위 conf의 값이 유효한 식별자가 아니다(공백만·CRLF·탭·메타문자 등) — conf 파일 점검 |

배너 문구:

> `[quality-gates] codex 리뷰 미실행 (<사유>) — 이 리뷰에는 모델 다양성이 없었다 (degraded).`

**감지기 실행 자체가 실패한 경우는 위 표와 다른 사실이다.** 정상 실행된 `detect_codex.sh`는
`codex_available: false`여도 항상 skip_reason 중 하나를 함께 낸다(위 visible 표뿐 아니라 아래
silent 표의 두 사유도 포함 — "위 표의"로 한정하면 그 둘이 빠진다). `detect_codex.sh`를
돌렸는데 비-zero exit이거나 출력에 `codex_available:` 줄이 아예 없으면, 그것은 "codex가 없다"가
아니라 **감지기 자체가 안 돈 것**이다 — `plugins/quality-gates/scripts/detect_codex.sh`는
`shared/codex/detect_codex.sh`를 가리키는 상대 심볼릭 링크라 끊길 수 있다. 그 사유를
`not_installed` 등 위 표의 값이나 `unknown`으로 뭉개지 말고 **`detector_not_runnable`**로
별도 취급한다:

> `[quality-gates] codex 감지기 실행 실패 (detector_not_runnable) — 이 리뷰에는 모델 다양성이 없었다 (degraded).`

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
   `$resolved_scope_file_count` = the size of the file set you actually resolved
   and reviewed at step 1 — the same set whose `changed_lines`/`new_files` you
   fed into `scout.py`. It is **never** copied from `check-review-scope.sh`: for
   the default (`session`) that set is the git-derived changed-file set (branch
   diff against base, unioned with the worktree's own changed files); for
   `branch` it is the branch diff against base; for `paths` it is the number of
   `--paths` glob matches you resolved. This count and the cached
   `$changes_exist` below MUST stay independently computed — the floor compares
   them, and if the count were itself read off `check-review-scope.sh` the two
   could never disagree, silently disarming the floor for its default mode.
   If this count cannot be determined (e.g. the same git-sanity failure that
   makes `check-review-scope.sh` itself report `degraded: yes` — detached HEAD,
   no base branch, shallow clone), do NOT silently treat it as 0 — treat the run
   as `$degraded == yes` for the floor (the ELSE-IF branch below + loud
   advisory). This is an already-known value; do not re-measure (re-deriving it
   risks landing on an answer that no longer matches the set you actually
   reviewed).

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

   **Not-clean notice override (applies to BOTH clean sub-cases, before the floor).**
   The key is the marker every such notice carries, not any one notice's wording:
   if the captured stdout contains `**이 실행은 clean이 아니다**` on any line, you MUST
   surface **every** line carrying it verbatim, **in addition to** the empty-state
   line, and you MUST NOT print a bare `clean` verdict. Print instead:
   `## Review gate iter N: not clean — <사유>.`
   `<사유>` comes from the notice itself, and notices differ in what they carry:
   - The **Dropped-finding** notice carries a count — it reads
     `<D> finding(s) dropped as malformed`. Print
     `<D> finding(s) dropped as malformed (unjudged)`.
   - A notice with **no count** (e.g. the `판정 degrade` line, which names which
     input or judgment path failed rather than how many items) has no `<D>` to read.
     Do NOT invent one and do NOT skip the override — print that notice line
     **verbatim** as `<사유>`.

   Then continue to step 5's decision tool as if findings remained.

   Why this clause exists: the synthesizer emits that notice — whose own text reads
   `**이 실행은 clean이 아니다**` — precisely because a malformed finding may have
   carried a real CRITICAL that was never judged. Before this clause, step 4.5 keyed
   only on the counts line and the `No high-confidence findings…` line, so the notice
   was produced by the script and then discarded by its only consumer: the gate
   printed `clean` over dropped CRITICAL claims (2026-08-05 `/qg` 라운드 2 적발 —
   생산자만 고치고 소비자를 안 고친 반쪽 수정). A finding that was thrown away is not
   a finding that was cleared. This mirrors the Runtime gate's `indeterminate ≠ clean`
   rule at [Step R4](#runtime-gate).

   Why the key is the marker and not the notice text: keying on one notice's literal
   is an enumeration, and an enumeration is fail-open over time — a second notice
   (`판정 degrade`) was added later and was **not** matched by a `dropped as malformed`
   key, so the same half-fix reappeared with only the instance changed. Deriving the
   key from the marker the notices share covers every present and future notice that
   declares itself not-clean.

   **Security-review-absent advisory (applies to EVERY step-4.5 exit path — the
   `kept > 0` case and BOTH clean sub-cases).** If this iteration set
   `$security_review_absent == yes` (the Tier A kill switch fired at dispatch), you
   MUST print this line as part of the verdict surface, immediately after the
   `## Review gate iter N …` line, before the decision tool:
   `> [quality-gates] 이 라운드에는 보안 리뷰가 없었다 — security-reviewer 가 DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1 로 꺼져 있었다. 이 verdict 는 "보안 리뷰를 통과했다"를 뜻하지 않는다.`
   Repeat it every iteration in which the switch was on — it is a property of that
   iteration's verdict, not a one-time notice.

   Why this is a separate clause from the dispatch-time banner: the banner is
   emitted mid-iteration, far above the verdict, and a reader who scrolls to the
   verdict (or reads only the `## History` line) never sees it. Tier A floor is
   `security-reviewer + adversarial`; with one of the two removed, a bare `clean`
   over-claims. Same family as the [Not-clean notice override](#review-gate) above —
   *a finding that was never produced is not a finding that was cleared.*

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

**이 게이트의 절차 전문은 `references/runtime-gate.md` 에 있다.** Runtime 게이트를
실제로 돌 때 그 파일을 Read 로 읽어 그대로 따른다. `/qg review` 처럼 Runtime 을 돌지
않는 실행에서는 읽지 않는다 — 이 분리의 목적이 그것이다(조건부 로드).

읽어야 하는 조건: Arguments 가 `runtime` 또는 `both` 이거나, Review 게이트가 끝난 뒤
Runtime 으로 진행하기로 판정된 경우.

```
Read references/runtime-gate.md
```

경로는 이 SKILL.md 파일 기준 상대경로다 — 레포·설치본 두 레이아웃 모두 이
SKILL.md와 같은 위치에 `references/runtime-gate.md`가 있으므로 그대로 resolve
된다([state-file-format](references/state-file-format.md#history)와 같은 관례).

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
- `ask` → invoke [Runtime NEEDS_RESOLUTION decision](#runtime-needs_resolution-decision) (retry / skip-with-evidence / stop). Total `ask` mid-run questions are bounded by `DEVBREW_QUALITY_GATES_RUNTIME_MAX_RESOLUTIONS`; on exhaustion, fall through to skip-with-evidence.

---

The NEEDS_RESOLUTION branch is the only Runtime gate outcome that surfaces a user question when `block_policy=ask`. It is bounded by `DEVBREW_QUALITY_GATES_RUNTIME_MAX_RESOLUTIONS` so a mis-configured environment cannot loop indefinitely.

Per spec AC8 and the secret-policy rule (P21), the prompt body asks the user to place secrets on disk first and respond yes/no. Never request a secret value as a literal string.

## Runtime NEEDS_RESOLUTION decision

> **Spec anchor (AC8):** the literal phrase `Runtime verifier needs` MUST appear in the prompt — V2b grep checks this. **P21 reaffirmation MUST also appear in the prompt body** (literal token `P21`) — the prompt never asks for secret values, only paths or yes/no.

Loop up to `DEVBREW_QUALITY_GATES_RUNTIME_MAX_RESOLUTIONS` times (default 3, env override clamped 0..10):

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

## Final Summary

Build the status rows and render them (deterministic, scannable) — one
`key<TAB>value` line per gate, verdict vocabulary unchanged (`clean iter N`,
`no scope reviewed (branch <M> ahead)`, `proceeded-with-findings iter N`,
`aborted iter N`, `skipped`, `clean`, `failed`, `SKIP_WITH_EVIDENCE`):

```bash
QG="${CLAUDE_PLUGIN_ROOT:-./plugins/quality-gates}"
printf 'Review gate\t<clean iter N | no scope reviewed (branch <M> ahead) | proceeded-with-findings iter N | aborted iter N | skipped>\nRuntime gate\t<clean | failed | SKIP_WITH_EVIDENCE | aborted | skipped>\n' \
  | $QG/scripts/render-terminal.py table --title "Quality Gates — Complete"
```

Then print the appended `## History` lines from the state file as an
indented tree beneath the table.

State file cleanup is deferred to /cancel-qg or SessionEnd cleanup hook.

## kill switch

이 SKILL이 존중하는 kill switch 색인 — 각 스위치의 전체 동작은 아래 명시된 스텝/절
본문에 있다(여기서 재서술하지 않는다, drift 방지):

- `DEVBREW_QUALITY_GATES_DISABLE=1` — 전역, 파이프라인 전체를 즉시 종료한다. Preflight
  Step P1.
- `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1` — Review gate의 codex co-review만 skip한다
  (Claude 리뷰는 정상 진행). Review gate의 "Codex skip 안내".
- `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1` — Review gate Tier A floor의
  `security-reviewer`만 skip한다. Review gate의 "Tier A — Floor" 절(dispatch 직전
  게이트 + loud advisory)과 Step 4.5의 "Security-review-absent advisory".
- `DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE=1` — Runtime gate의
  test-scope-validator dispatch에 `spec_path: none`을 강제해 spec 기반 ac_coverage를
  끈다(plan 기반 scope만 남는다). Arguments 절.
- `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX=1` — Runtime gate 샌드박스를 끄고
  실제 트리 폴백으로 간다. verdict는 SKIP_WITH_EVIDENCE로 cap — 이 스위치가 켜진
  경로는 PASS를 낼 수 없다. Runtime gate Exit 3.

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
