---
name: quality-pipeline
description: >
  Runs the quality-gates pipeline in a single assistant turn. Triggered by
  `/qg`, "run quality gates", "verify my implementation", "check code quality",
  or "is my PR ready to merge". One pipeline, one verdict — scope, a differential
  test against the baseline (always), reviewers per angle, a framing-blind
  re-critique, and synthesis. Fix-loop decisions surface via AskUserQuestion.
  Publishing a PR-understanding comment is a separate explicit step
  (`/qg-publish`) — not part of the pipeline, and not an automatic continuation.
cost_class: variable
allowed-tools:
  # Group 1 — Preflight scripts (실행 순서: setup → trivia → 스코프 신호)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-trivia.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-review-scope.sh:*)
  # Group 2 — Differential test scripts (references/differential-test.md)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/resolve-baseline.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/compute-test-scope-candidates.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/run-test-selection.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/baseline-cache.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/seal-worktree.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/diff-test-results.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check_qa_ledger.py:*)
  # 비-플러그인 명령 중 **항목을 가진 유일한 것**. R-init 이 오케스트레이터 소유 중간 파일의
  # 집을 만든다(AC69). 레포 안에 두면 봉인(`seal-worktree.sh` 의 `git add -A`)이 그 파일들을
  # HEAD 축에 넣으므로 반드시 트리 밖이어야 하고, 그러려면 이 한 명령이 필요하다. fenced
  # 블록의 맨 셸 유틸리티(`pwd` · `printf` · `git` …)가 항목을 필요로 하는지는 미측정이다 —
  # 넓은 grant 를 사지 않는다.
  - Bash(mktemp:*)
  # Group 3 — Review scripts (각도 · 재비판 · 합성)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/scout.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/detect_codex.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/run_codex_reviewer.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/recritic_bridge.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/synthesize_findings.py:*)
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

# Quality Gates — In-Turn Orchestrator (v8.0.0)

You are running the **quality-gates pipeline** in a single assistant turn. There is
**one pipeline and one verdict** — no gate scope to choose. At the fix-loop boundary
you call `AskUserQuestion` and branch on the user's response — the response arrives
as a tool result in the same turn, so no Stop hook and no continuation sentinel are
needed.

**Law 2 (Writer ≠ Reviewer):** you are the orchestrator (writer). `security-reviewer`, 재비판(`doc-recritic`), and `test-scope-validator` are read-only reviewers (`tools: Read, Grep, Glob` — fail-closed allowlist) — no qg-own agent has write access. External extra reviewers (e.g. `pr-review-toolkit`, chosen per [Angles and reviewers](#angles-and-reviewers-scope-driven)) may be write-capable upstream, but they are advisory — you own fixes; their output is findings YAML, never a commit. You run the tests yourself — both axes of the differential test, on trees you create — and you may apply user-approved fixes ("Retry" path) via Edit/Write; those are user-consented.

**State file:** read `worktree_path` from `.claude/quality-gates/<sid>/pipeline.md`
only during preflight; never write. Setup script handles creation, /cancel-qg
handles deletion.

## Contents

이 SKILL은 단일 어시스턴트 턴 안에서 전체 파이프라인을 실행. 섹션 그룹:

1. **Workflow (top-to-bottom on invocation):**
   - [Preflight](#preflight) — kill switch / setup-qg
   - [Arguments](#arguments) — `/qg` flags 파싱
   - [Pipeline](#pipeline) — ① 스코프 → ② 차등 테스트 → ③ 각도 + 리뷰어 → ④ 재비판 → ⑤ 합성 · 판정, iteration 마다
2. **Steps:**
   - [Trivia escape](#trivia-escape) — one-sentence diff → pipeline skipped
   - [Review](#review) — Step 1 스코프 · 1b 신호 · 1c 차등 테스트 · 2 scout · 3 디스패치 · Phase 1.5 재비판 · 4 합성 · 4.5 판정 표면 · 5 결정
   - [Angles and reviewers (scope-driven)](#angles-and-reviewers-scope-driven) — 각도 셋 + 추가 리뷰어 rubric
   - [Differential test](#differential-test) — 기준선 대비 차등 실행(절차 전문은 레퍼런스)
3. **Decision points (AskUserQuestion templates):**
   - [Fix-loop decision](#fix-loop-decision)
   - [Max-iter decision](#max-iter-decision)
4. **Output templates** — [Final Summary](#final-summary) · [kill switch](#kill-switch) · [Rules](#rules)

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

**Step P0b — Resolve the plugin root.** Every script named below lives under
`${CLAUDE_PLUGIN_ROOT}/scripts/`. If that path does not read as absolute, do not guess one
(the cwd included) — stop and report. Self-contained fences take the root from the token
and stop when it is empty:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
```

Shell state does not carry between Bash calls — every fence that needs `$QG`
assigns it in that same fence. Do not hoist the assignment.

**Step P1 — Global kill switch.** If `DEVBREW_QUALITY_GATES_DISABLE=1`,
emit `[quality-gates] disabled via DEVBREW_QUALITY_GATES_DISABLE=1` and
return immediately. Do NOT call setup-qg.sh or any agent.

**Step P2 — Setup state.** Run:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
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
- `plan_path` (optional): defaults to "auto" (`scripts/discover-plan.sh`).
  A secondary scope hint for `test-scope-validator` (differential test R1b) and
  for the `security-reviewer` / 재비판(doc-recritic) dispatches — not verified,
  only hinted.
- `spec_path` (optional): defaults to "auto" (`scripts/discover-spec.sh`).
  The project spec is the Acceptance Criteria truth — `test-scope-validator`
  classifies test files against it, and the codex path injects its AC into
  `<spec_context>` (script-internal in `run_codex_reviewer.sh`). If
  `DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE=1`, pass `spec_path: none` to
  the `test-scope-validator` dispatch. All spec behavior is advisory; it never
  blocks the pipeline.
- `pr_url` (optional).
- `branch [<name>]` (optional): scope override — the full branch diff (with
  `<name>`, in an isolated worktree created by `setup-qg.sh`).
- `paths` (optional, repeatable): scope override — `--paths <glob>...`.

**제거된 인자** — `both` · `review` · `runtime` · `--skip-runtime`. 한 파이프라인이라
고를 게이트 범위가 없다. `setup-qg.sh` 가 인자마다 한 줄
(``> [quality-gates] `<인자>` 인자는 제거됐다 — …``)을 내고 실행은 그대로 진행한다.
그 인자 때문에 질문을 띄우거나 어느 단계를 건너뛰지 않는다.

## Pipeline

한 파이프라인, 한 판정(설계 §6.1):

1. [Trivia escape](#trivia-escape). trivia 면 나머지 전부를 건너뛴다.
2. iteration N = 1..5 — 각 iteration 은 다섯 단계를 이 순서로 돈다:
   - ① **스코프** — [Review](#review) Step 1 · 1b
   - ② **차등 테스트** — Step 1c → [Differential test](#differential-test). **매 iteration 돈다** — iteration 2 이상은 Retry 가 코드를 고친 뒤라, 앞 iteration 의 결과는 다른 트리의 것이다.
   - ③ **각도 + 리뷰어** — Step 2 · 3
   - ④ **재비판** — Phase 1.5
   - ⑤ **합성 · 판정** — Step 4 · 4.5 · 5
3. [Final Summary](#final-summary).

**② 가 ③ 보다 앞인 것이 load-bearing 이다** — 테스트 결과는 실행이 내고, 그 결과가 ③ 에서
누구를 부를지의 입력이 된다(diff 는 피검자가 쓰지만 테스트 결과는 실행이 낸다).

## Trivia escape

Run `scripts/check-trivia.sh` (plugin root per Step P0b). Exit code:
- 0 = trivia detected → skip the whole pipeline. Print:
  > `Trivia diff — pipeline skipped (one-sentence diff per CLAUDE.md trivia escape).`
- 1 = non-trivia → proceed to iteration 1.
- any other non-zero (script crash / environment failure) → print stderr
  verbatim and abort the pipeline. Do NOT silently treat as non-trivia.

## Review

Iterative fix-loop, `max_review_iterations = 5` (hard-coded constant).

For each iteration N (1..5):

1. **Resolve the review scope** — `paths` / `branch` / `session` (`session` = the default: no `branch` arg, no `--paths`). **There is no preflight scope**; nothing upstream hands you a file set, so you derive it here, from git, every turn:

   ```bash
   QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }   # plugin root per Step P0b
   MERGE_BASE=$("$QG/scripts/resolve-baseline.sh" | sed -n 's/^merge_base: //p')
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
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/check-review-scope.sh"
```

The script takes **no arguments** — scope resolution (what to review) is yours, not
the script's. Parse the structured stdout and cache `$changes_exist`,
`$branch_ahead_count` (the changed-file count on `merge_base..HEAD`),
`$worktree_dirty`, `$base` (display name), and `$degraded`. There is **no routing**
here: this signal feeds the Step 4.5 verdict floor and R4's baseline-vs-HEAD
selection (reference R4).

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

**Step 1c — 차등 테스트 (②).** [Differential test](#differential-test) 절을 따른다 —
매 iteration 돈다. 결과(`$aggregate_yaml` 경로와 R6 두 호출의 exit code ·
`check_qa_ledger.py` 의 exit code)를 Step 4 로 들고 간다. 그 결과를 Step 3 의 추가
리뷰어 선택에 입력으로 쓴다 — 예: `NEW_REGRESSION` 이 난 unit 의 파일을 건드린 diff 에는
`pr-review-toolkit:silent-failure-hunter` 를 더 무겁게 본다.

2. Dispatch the scout: `Bash(scripts/scout.py ...)` (plugin root per Step P0b) — compute its
   metrics from the review scope you resolved at step 1 (the git-derived changed-file set, the
   `branch` diff, or the `--paths` globs). Scope is model-owned; there is no cached scope
   variable to thread.
3. **Compose and dispatch the reviewers — per angle (scope-driven).** 세 각도(보안 ·
   판정 · 다른 전제 — [Angles and reviewers](#angles-and-reviewers-scope-driven))마다
   수행자가 정해져 있고, 그 밖의 추가 리뷰어를 스코프로 고른다. 선택은 **model-owned
   routing** 이다(P8 lightness). Re-select every iteration. **No qg-own tool posture
   changes here (#104 lock kept).**

   **보안 각도 — `quality-gates:security-reviewer`, 매 iteration.** 스코프 판단으로 빼지
   않는다. 판정 각도(재비판, 아래 Phase 1.5)도 매 iteration 돈다. `tools:` posture
   (`Read, Grep, Glob`, #104 lock) is unchanged. `security-reviewer` MUST include
   `project_dir: "$project_dir"`:

   **Kill switch — `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1`.** 보안 각도를
   *모델이* 스코프 판단으로 뺄 수는 없지만, *사용자는* 끌 수 있다. 이 둘은 다른
   것이다: 앞은 라우팅 재량이고 뒤는 사용자 소유의 opt-out 이다(CLAUDE.md
   Plugin Shape — *"모든 reviewer는 opt-out 가능"*, 그리고 *"kill switch는 보안
   컨트롤"*). 매 iteration, 바로 아래 `security-reviewer` Agent 리터럴을 발행하기
   **직전에** 이 게이트를 통과시킨다 — 게이트는 여기, dispatch 지점에 선다:

   IF `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1`:
   1. 아래 `quality-gates:security-reviewer` Agent 리터럴을 **발행하지 않는다.**
      재비판 · codex · 추가 리뷰어는 **그대로 fire 한다** — 꺼지는 것은 이
      하나뿐이다.
   2. 재비판의 `findings` 슬롯에는 실제로 받은 것만 넣는다
      (codex + 추가 리뷰어). 없는 리뷰어 몫을 있는 것처럼 채우거나 대신 지어내지 않는다.
   3. **loud advisory** — 이 줄을 사용자에게 그대로 보인다:
      > `> [quality-gates] security-reviewer disabled via DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1 — 이 iteration 에는 보안 리뷰가 없었다 (보안 각도 부재).`
   4. 이 iteration 에 대해 `$security_review_absent = yes` 로 두고 **Step 4.5 의
      판정 표면까지 들고 간다**(아래 Security-review-absent advisory). 배너 한 줄로
      끝내면 verdict 만 읽는 사람에게는 결손이 보이지 않는다.

   ELSE: `$security_review_absent = no` — 아래 리터럴을 평소대로 발행한다.

   **왜 codex kill switch 와 달리 loud 인가.** 형제 스위치
   `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1` 은 [Codex skip 안내](#codex-skip-안내)의
   silent 표에 있다(*"사용자가 직접 껐다. 자기가 한 일을 다시 알릴 필요가 없다"*).
   codex 는 다른 전제 각도라 부재를 공시만 하고 막지 않는다. `security-reviewer` 는
   보안 각도라 부재가 판정을 막는다 — 사용자의 의도적 opt-out 이더라도 **판정을 읽는
   사람**에게 결손이 보여야 한다. 두 스위치를 "일관성" 명목으로 같은 취급으로 합치지
   말 것.

```
Agent({
  subagent_type: "quality-gates:security-reviewer",
  // **처분** — consumer=plugins/quality-gates/scripts/synthesize_findings.py · fail-open
  description: "Security review (qg iter N)",
  prompt: "Run code-level security review on the current diff.
    project_dir: <project_dir>${PROJECT_DIR}</project_dir>
    diff_scope: <diff_scope>${DIFF_SCOPE}</diff_scope> (session (git-derived changed files) / branch (git diff vs base) / paths (--paths globs) — the review scope you resolved at step 1)
    plan_path: <plan_path>${PLAN_PATH}</plan_path> (path or 'auto')
    iteration: <iteration>${ITERATION}</iteration>
    filtered_diff: <filtered_diff>${FILTERED_DIFF}</filtered_diff> (unified diff computed from the resolved review scope, documentation paths excluded)"
})
```

   **다른 전제 각도 — codex (사용 가능하면 부른다).** If the codex
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
   iteration's codex verdict. This mirrors the identical exit-3 contract of
   `run_docreview_codex_reviewer.sh` (spec-distill's document-review runner), whose
   callers (`spec-distill`'s `reviewing-spec` and `reviewing-brief` SKILLs) implement
   the same `if rc == 3: rm -f` pattern.

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

   **추가 리뷰어 — 스코프 도출(외부 advisory agent).**
   Choose zero or more from the menu in [Angles and reviewers](#angles-and-reviewers-scope-driven)
   by matching the diff to the rubric + scope-signal palette there.
   `pr-review-toolkit:code-reviewer` is the **강한 default** (각도 수행자가 아니다):
   include it on any non-trivial diff; drop it only on a quick-depth diff. 추가 리뷰어는
   advisory 다 — you own fixes; their output is findings YAML. Do NOT thread a
   `model:` override into their dispatch (upstream model pinning is respected).

   **Transparency (loud — 매 iteration user-visible stdout 한 줄).** Emit exactly one
   line documenting the composition, so drops/degrades are never silent:

   > `> [quality-gates] iter N — 선택: <디스패치한 리뷰어 목록>(근거: <스코프 신호>) / 제외: <이유 또는 "해당 신호 없음">`

   **Graceful degradation (loud).** If a 추가 리뷰어 candidate is unavailable
   (pr-review-toolkit / feature-dev not installed), continue with the angle performers +
   whatever is installed, and print:

   > `> [quality-gates] specialist <X> unavailable (<plugin> 미설치) — degraded coverage`

   The angle performers are **not** affected by this degrade. There is **no fan-out consent
   gate** (lightness) — fan-out is bounded by the rubric's natural signal-binding, the
   transparency line above, and the recomputed max fan-out declared in the README.
   (A repo-wide `fan-out ≥5` hard-review gate was **removed** from CLAUDE.md and the philosophy doc by the harness-capability-suppression sweep — it is no longer a backstop and must not be cited as one.)

   **Phase 1.5 — 재비판 (판정 각도).** 탐지(`security-reviewer` · codex ·
   추가 리뷰어)가 끝난 뒤 **한 번** 디스패치한다. **탐지 결과가 0건이어도 디스패치한다**(AC17 —
   빈 슬롯도 재비판한다. 놓친 결함은 재비판자가 `added` 로 낸다). 재비판자는 **프레이밍을
   못 본다** — 이 리뷰가 왜 열렸는지, 어느 리뷰어가 무엇을 냈는지를 싣지 않는다.

   1. **이 iteration 의 중간 파일 디렉토리** `RV` 를 `mktemp -d` 로 만들고 그 경로를 이후
      펜스에 리터럴로 싣는다(Bash 호출마다 셸이 새로 뜬다). 탐지 결과를 `$RV/findings.yaml`
      에 YAML 목록으로 쓴다. **각 항목의 `agent:` 는 디스패치한 agent 의 frontmatter
      `name:` 이다 — 플러그인 접두 없이**(`security-reviewer` · `code-reviewer` …; codex 는
      `codex`). 리뷰어가 적어 보낸 `agent:` 를 그대로 믿지 않는다 — 찍는 쪽이 너다.
   2. 익명화와 diff:

      ```bash
      QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
      RV="<1 에서 만든 절대 경로>"
      python3 "$QG/scripts/recritic_bridge.py" prepare --findings "$RV/findings.yaml" \
        --out-findings "$RV/recritic-findings.yaml" --out-map "$RV/recritic-map.json"
      cat "${CLAUDE_PLUGIN_ROOT}/references/recritic-code-profile.md"
      ```

      `prepare` 가 0 이 아닌 코드로 끝나면 재비판을 디스패치하지 않는다 — 이 뒤에 도는
      `synthesize_findings.py`(아래 「4. Run synthesize_findings.py」, 이 안쪽 번호 목록의
      4 가 아니다)가 응답 파일의 부재를 판정 각도의 주 입력 실패로 센다(침묵하지 않는다).
      `$RV/recritic.diff` 에는 `security-reviewer` 에게 준 것과 같은 **raw unified diff**
      (hunk 만)를 쓴다. `git show` · `git format-patch` · `git log -p` 의 출력은 쓰지 않는다 —
      그것들은 **커밋 메시지**를 싣고, 커밋 메시지는 작성자의 프레이밍이다.
   3. 디스패치 — 슬롯 넷을 **그대로** 채운다: `<document>` = `project_dir` 절대 경로와 이
      iteration 의 리뷰 스코프 경로 목록(재비판자는 그 경로의 코드를 `Read` 한다) ·
      `<findings>` = `$RV/recritic-findings.yaml` 의 내용 · `<profile>` = 위 `cat` 이 낸
      내용(경로가 아니라 **내용** — 재비판자는 플러그인 캐시 경로를 읽지 못한다) ·
      `<diff>` = `$RV/recritic.diff` 의 내용.

```
Agent({
  subagent_type: "quality-gates:doc-recritic",
  // **처분** — consumer=plugins/quality-gates/scripts/synthesize_findings.py · fail-closed
  description: "Framing-blind re-critique of the finding list (qg iter N)",
  prompt: "<document>${DOCUMENT}</document>
    <findings>${FINDINGS}</findings>
    <profile>${PROFILE}</profile>
    <diff>${DIFF}</diff>"
})
```

   4. 응답 전문을 요약·전사 없이 `$RV/recritic.txt` 에 **verbatim** 저장한다. 디스패치가
      실패했거나 응답이 없으면 파일을 만들지 않는다 — 합성기가 그 부재를 판정 각도의 주 입력
      실패로 세고, 본 보고서의 `**이 실행은 clean이 아니다**` 마커가 Step 4.5 의 Not-clean
      override 를 켠다.

4. Run `synthesize_findings.py` to consolidate findings:

   ```bash
   QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
   RV="<Phase 1.5 의 절대 경로>"
   python3 "$QG/scripts/synthesize_findings.py" --findings "$RV/findings.yaml" \
     --recritic "$RV/recritic.txt" --recritic-map "$RV/recritic-map.json" \
     --recritic-diff "$RV/recritic.diff"
   ```

   **rc 를 소비하라.** 이 스크립트가 0 이 아닌 rc 로 끝나거나 stdout 이 비어
   있으면(usage 오류·판정축 실패·미처리 traceback 전부 이 모양이다) 이 iteration
   은 **clean 이 아니다** — rc 와 stderr 를 그대로 보고하고 멈춘다. 빈 보고서를
   clean 으로 읽지 않는다.

   **Capture the script's complete stdout** — the
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
     prepended with the single context line `## qg iter N — Findings`,
     **before** invoking the decision tool. Then go to step 5.
   - **kept = 0 AND suppressed > 0** (the synthesizer emitted the empty-state
     line `No high-confidence findings. N low-confidence findings suppressed.`
     with N > 0 — read N from that line) → no high-confidence finding to act
     on → treat as **clean**: do NOT call AskUserQuestion. Surface the single
     `No high-confidence findings…` line for transparency, then apply the
     **Honest-verdict floor** below. Then **exit the loop → [Final
     Summary](#final-summary)** — do not iterate again.
   - **kept = 0 AND suppressed = 0** (the same empty-state line with N = 0) →
     apply the SAME **Honest-verdict floor** below, then exit the loop →
     [Final Summary](#final-summary).

   **Not-clean notice override (applies to BOTH clean sub-cases, before the floor).**
   The key is the marker every such notice carries, not any one notice's wording:
   if the captured stdout contains `**이 실행은 clean이 아니다**` on any line, you MUST
   surface **every** line carrying it verbatim, **in addition to** the empty-state
   line, and you MUST NOT print a bare `clean` verdict. Print instead:
   `## qg iter N: not clean — <사유>.`
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
   a finding that was cleared. This mirrors the differential test's `indeterminate ≠ clean`
   rule (reference R6).

   Why the key is the marker and not the notice text: keying on one notice's literal
   is an enumeration, and an enumeration is fail-open over time — a second notice
   (`판정 degrade`) was added later and was **not** matched by a `dropped as malformed`
   key, so the same half-fix reappeared with only the instance changed. Deriving the
   key from the marker the notices share covers every present and future notice that
   declares itself not-clean.

   **Security-review-absent advisory (applies to EVERY step-4.5 exit path — the
   `kept > 0` case and BOTH clean sub-cases).** If this iteration set
   `$security_review_absent == yes` (the 보안 각도 kill switch fired at dispatch), you
   MUST print this line as part of the verdict surface, immediately after the
   `## qg iter N …` line, before the decision tool:
   `> [quality-gates] 이 라운드에는 보안 리뷰가 없었다 — security-reviewer 가 DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1 로 꺼져 있었다. 이 verdict 는 "보안 리뷰를 통과했다"를 뜻하지 않는다.`
   Repeat it every iteration in which the switch was on — it is a property of that
   iteration's verdict, not a one-time notice.

   Why this is a separate clause from the dispatch-time banner: the banner is
   emitted mid-iteration, far above the verdict, and a reader who scrolls to the
   verdict (or reads only the `## History` line) never sees it. 보안 각도와 판정 각도는
   부재가 판정을 막는 두 각도다; with one of them missing, a bare `clean`
   over-claims. Same family as the [Not-clean notice override](#review) above —
   *a finding that was never produced is not a finding that was cleared.*

   **Honest-verdict floor (deterministic — both clean sub-cases).** The floor keys
   on two deterministic inputs — `$resolved_scope_file_count` (the step-1 count above)
   and the cached `$changes_exist` (emitted by `check-review-scope.sh`, independent of
   any clean claim):
   - IF `$resolved_scope_file_count == 0 AND $changes_exist == yes`: do NOT print
     bare `clean`. Print
     `## qg iter N: no scope reviewed (0 files; branch <M> ahead of <base>, worktree <dirty|clean>) — NOT certified clean.`
     (`<M>` = `$branch_ahead_count`, `<base>` = `$base`, worktree token from
     `$worktree_dirty`: `yes`→`dirty`, `no`→`clean`). A zero-scope run with real changes must never read as
     "reviewed & clean".
   - ELSE IF `$degraded == yes AND $resolved_scope_file_count == 0`: print
     `## qg iter N: clean` AND the loud advisory
     `> [quality-gates] scope check degraded (detached HEAD / no base branch / unrelated history / shallow) — empty-scope detection skipped (fail-open; verdict not floor-protected this run).`
   - ELSE: print `## qg iter N: clean` exactly as before (scope > 0, or a
     genuine no-op with `$changes_exist == no` — unchanged happy path).

5. **Decision tool (kept > 0 only).** Invoke [Fix-loop
   decision](#fix-loop-decision). Fill its `<summary>` slot by
   **verbatim-copying the `**Findings:**` counts line** from step 4's stdout
   (deterministic extraction — do NOT author a fresh sentence). Append one
   `## History` line of the form
   `qg iter N: <c> CRITICAL / <i> IMPORTANT / <s> SUGGESTION → user chose <choice>`
   (severity triplet copied from the same counts line; see
   [state-file-format](references/state-file-format.md#history)).

If iteration N=5 ends with kept > 0: run step 4.5's surface first (same as
above), then invoke [Max-iter decision](#max-iter-decision)
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

## Fix-loop decision

> **Spec anchor (AC6):** the literal phrase `findings remain` MUST appear
> in the prompt — V2b grep checks this. This phrase is Review-iter-specific
> (not used in any other decision-tool call in this SKILL).

Call AskUserQuestion (replace `N` with the iteration number, `<summary>`
with the synthesizer's one-line summary):

```
AskUserQuestion({
  questions: [
    {
      question: "qg iter N: findings remain (<summary>). What next?",
      header: "qg iter N",
      options: [
        {label: "Retry",             description: "Apply the suggested fixes (I will Edit the files in this turn), then re-run the pipeline for the next iteration — differential test included."},
        {label: "Accept and finish", description: "Accept current findings as-is and go to the final summary with the current verdict."},
        {label: "Stop",              description: "Abort the pipeline at this iteration. Address findings and re-run /qg."}
      ],
      multiSelect: false
    }
  ]
})
```

Branch on answer:
- **Retry** → apply user-consented fixes by calling Edit/Write directly
  with the synthesizer's suggested patches; increment iteration counter;
  loop back to [Pipeline](#pipeline) step 2 (① 부터 — ② 차등 테스트 포함). See
  [Retry: file-write safety](#retry-file-write-safety) for the
  canonicalization requirement on reviewer-supplied paths, and
  [Retry: error handling](#retry-error-handling) for the AskUserQuestion
  surface that fires on Edit failures.
- **Accept and finish** → exit the loop and emit the final summary with the
  findings recorded.
- **Stop** → emit final summary marked aborted at this iteration.

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
        {label: "Abort retry",     description: "Abort this Retry iteration entirely; surface as failure to the qg verdict."},
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

## Angles and reviewers (scope-driven)

The reviewer set is composed per angle (설계 §6.3.1). Selection is **model-owned**
(lightness) — there is no deterministic selector schema; scout is a hint, not an
authority. 각도의 의무는 결정론이 지키고(⑤ 의 각도 상태), 누가 채우는지는 여기서 정한다:

- **보안 각도** — `quality-gates:security-reviewer`: 매 iteration. `tools: Read, Grep, Glob` (#104 락, 무변경). 모델이 못 뺀다.
- **판정 각도** — 재비판 `quality-gates:doc-recritic`: 매 iteration(탐지 0 이어도 — AC17).
- **다른 전제 각도** — codex: `detect_codex.sh` 가 참이면 부른다. 모델 다양성 손실은 공시하고 막지 않는다.
- **추가 리뷰어** (아래 rubric으로 diff 스코프에 맞춰 가감; 최대 6 후보):

**rubric (review-pr §4 흡수):**

| 스코프 신호 | 전문가 |
|---|---|
| 비-trivial diff 기본 | `pr-review-toolkit:code-reviewer` (강한 default; quick-depth만 drop) |
| 에러핸들링 변경 | `pr-review-toolkit:silent-failure-hunter` |
| 타입 추가/변경 | `pr-review-toolkit:type-design-analyzer` |
| 테스트 파일 변경 | `pr-review-toolkit:pr-test-analyzer` |
| docs/주석 추가 | `pr-review-toolkit:comment-analyzer` |
| 대형 구조/아키텍처 변경 | `feature-dev:code-architect` |

**depth→추가 리뷰어 크기 가이드라인 (scout 힌트, 재현성 게이트 아님):** `quick` →
code-reviewer만(또는 없음); `standard` → + 신호-매칭 전문가 1–2; `deep` → + 신호-매칭
전문가(구조 변경이면 code-architect). scout의 `phase1_agents`/`phase2_agents`는 힌트일 뿐
권위가 아니다(Retry마다 재선택).

**scope-signal 팔레트 (모델 판단 보강, 결정론 아님; `security-guidance` 카테고리 출처):**
역직렬화(pickle/yaml/torch) · 인젝션(eval/exec/os.system/subprocess-shell) ·
XSS(innerHTML/dangerouslySetInnerHTML) · crypto(createCipher/AES-ECB) · TLS-verify-disabled ·
XXE · GHA-workflow-injection · SRI · deps-manifest 변경 · migration/schema · public-API 변경 ·
삭제 파일. 이 신호가 보이면 해당 전문가(또는 code-reviewer 프롬프트 힌트)를 풍부하게 고른다.

**비-규범 예시 (illustrative only — 테스트 대상 아님; 모델이 최종 판단):**

| diff 예 | scout depth | 예상 추가 리뷰어 선택 |
|---|---|---|
| 1-파일 버그픽스 | quick | code-reviewer |
| 기능 추가(에러핸들링+테스트) | standard | code-reviewer, silent-failure-hunter, pr-test-analyzer |
| 신규 모듈(새 타입+구조) | deep | code-reviewer, type-design-analyzer, code-architect |
| 순수 docs 개편 | standard | comment-analyzer (+ code-reviewer) |

**git-history/이전-PR 렌즈**는 이미 Bash-무장된 `pr-review-toolkit:code-reviewer`가 프롬프트
힌트로 수행한다 — qg-own 에이전트는 Bash/Web을 갖지 않는다(무변경). 추가 리뷰어 외부 에이전트는
write-capable(pr-review-toolkit inherit-all)이거나 read/web-only(feature-dev:code-architect)이며
모두 advisory다(오케스트레이터가 fix 소유).

## Reviewer dispatch contract

The following two reviewer subagents declare `project_dir` as a REQUIRED
dispatch parameter and forbid `pwd`/`git rev-parse` recomputation inside
the persona. Any dispatch of these agents MUST thread the preflight-frozen
`$project_dir` value via the `project_dir:` field of the prompt:

- `quality-gates:test-scope-validator`
- `quality-gates:security-reviewer`

`quality-gates:doc-recritic`(Phase 1.5)은 이 목록에 없다 — 그 입력 슬롯은 공유 정본이
정한 넷(`document` · `findings` · `profile` · `diff`)뿐이고, `project_dir` 은 별도 슬롯이
아니라 `<document>` 안에 싣는다. 슬롯 계약은 `shared/tests/test_agent_input_slots.sh` 와
`shared/tests/test_docreview_agents.sh` 가 잰다.

The contract is verified by:
- runtime: agent personas reject prompts missing `project_dir:` (see
  `plugins/quality-gates/agents/*.md` frontmatter)
- static: `shared/tests/test_agent_input_slots.sh` — it parses each agent's
  frontmatter `input_slots:` and the dispatch fences in this SKILL, and
  reports `PROBLEM undelivered` when a declared non-optional slot (such as
  `project_dir`) has no dispatch delivering it. Being a parse-and-compare,
  it is insensitive to spelling (space width, variable name) — which a
  proximity grep is not.

  *(An earlier revision of this paragraph named
  `tests/harness/test_skill_orchestration_behavior.sh` as the enforcer of a
  "`project_dir:` within 10 lines" rule. That was false — deleting the line
  left that lock's failure count unchanged. The measured enforcer is the one
  above.)*

## Max-iter decision

After iteration 5 still has findings, do NOT silently halt. Call:

```
AskUserQuestion({
  questions: [
    {
      question: "qg reached max 5 iterations. Last findings: <summary>. Finish with the current verdict or stop?",
      header: "qg max-iter",
      options: [
        {label: "Accept and finish", description: "Accept residual findings and go to the final summary."},
        {label: "Stop",              description: "Abort the pipeline. Address findings and re-run /qg."}
      ],
      multiSelect: false
    }
  ]
})
```

Branch on answer accordingly. (P18 unbounded-autonomy is satisfied by
this user-consent termination.)

## Differential test

**절차 전문은 `references/differential-test.md` 에 있다.** 매 iteration 의 ②(Review
Step 1c)에서 그 파일을 Read 로 읽어 그대로 따른다. trivia escape 로 파이프라인이
통째로 생략된 실행만 읽지 않는다.

```
Read ${CLAUDE_PLUGIN_ROOT}/skills/quality-pipeline/references/differential-test.md
```

그 파일의 플러그인 루트 변수(`CLAUDE_PLUGIN_ROOT`)는 치환되지 않은 채로 온다 — 읽거나 실행할 때 `${CLAUDE_PLUGIN_ROOT}` 로 바꿔 넣는다. 위 `Read` 줄의 경로가 절대 경로로 보이지 않으면 reference 를 cwd 에서 찾지 말고 멈춰 보고한다.

## Final Summary

Build the status rows and render them (deterministic, scannable) — one
`key<TAB>value` line per row:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
printf 'Review\t<clean iter N | no scope reviewed (branch <M> ahead) | accepted-with-findings iter N | aborted iter N>\nDifferential test\t<attribution_status · 원장 게이트 rc>\n' \
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
- `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1` — 다른 전제 각도(codex)만 skip한다
  (Claude 리뷰는 정상 진행). Review Step 3 의 "Codex skip 안내".
- `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1` — 보안 각도의
  `security-reviewer`만 skip한다. Review Step 3 의 "보안 각도" 절(dispatch 직전
  게이트 + loud advisory)과 Step 4.5의 "Security-review-absent advisory".
- `DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE=1` — 차등 테스트 R1b 의
  test-scope-validator dispatch 에 `spec_path: none` 을 강제하고 codex `<spec_context>`
  를 비운다(plan 기반 분류만 남는다). Arguments 절.

## Rules

**R1 (Law 2 — physical):** never call Edit/Write on agent persona files
(`plugins/quality-gates/agents/*.md`) in this turn. The orchestrator may
edit working-tree files for user-consented fixes only.

**R2 (state file write invariant):** never write `pipeline.md` frontmatter.
You MAY append a single line to the `## History` section per iteration verdict;
do not modify any other content. Frontmatter is owned by setup-qg.sh.

**R3 (no fake user messages):** v1.32.0 has no Stop hook continuation, no
emission tag, and no continuation sentinel. Do NOT emit any such marker.

**R4 (P21 secret policy):** the decision-tool prompts never request a
secret value as a string.

**R5 (single dispatch per turn):** the entire pipeline runs in one turn.
Do not call setup-qg.sh more than once. Do not call check-trivia.sh more
than once. Do not re-dispatch the same reviewer for the same
iteration.
