# qg Upfront Gate-Scope Decision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a full `/qg` (no gate arg) ask one upfront "Review gate only / Run both gates" question — after the trivia escape, before any gate dispatch — and add a `/qg both` argument for the zero-click both-gates path.

**Architecture:** This is an orchestration-protocol + documentation change inside the `quality-gates` plugin. No new scripts, agents, or runtime code. The "code" is the prompt in `skills/quality-pipeline/SKILL.md` (the in-turn orchestrator) plus the command/README/CHANGELOG/version surfaces. The only **automated test** is the grep-based protocol-shape verifier `tests/harness/test_skill_orchestration_behavior.sh`; TDD here means adding new grep assertions first (they go red because `SKILL.md` has no gate-scope question yet), then editing `SKILL.md` until they go green.

**Tech Stack:** Markdown (SKILL/command/README/CHANGELOG), JSON (`plugin.json`), Bash (the protocol-shape test harness, `awk`/`grep`-based). All edits land in the worktree `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+qg-upfront-gate-scope` on branch `worktree-feature+qg-upfront-gate-scope`.

**Source spec:** `docs/superpowers/specs/2026-06-04-qg-upfront-gate-scope-design.md` (approved).

---

## Orientation (read before starting)

**Worktree absolute root (all paths below are relative to this):**
`/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+qg-upfront-gate-scope`

Run every git/test command from that worktree root. Do **not** `cd` into the original repo checkout — same-named files there would cause branch drift (a known failure mode in this repo).

**Files this plan touches (spec §6):**

| File | Responsibility | Test-covered? |
|---|---|---|
| `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` | Grep protocol-shape assertions (the "tests") | n/a — is the test |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | In-turn orchestrator prompt: Upfront Execution Plan, Dispatch Loop, Arguments, frontmatter desc, version strings | **yes** (the harness reads it) |
| `plugins/quality-gates/commands/qg.md` | `/qg` command: argument-hint, Quick Reference table | no |
| `plugins/quality-gates/README.md` | P18 "Principles Instantiated" bullet | no |
| `plugins/quality-gates/.claude-plugin/plugin.json` | SemVer `version` | no |
| `plugins/quality-gates/CHANGELOG.md` | `## [2.4.0]` entry | no |

**The anchor convention (load-bearing — spec §4, §5):** every `AskUserQuestion` decision in `SKILL.md` carries a *unique* phrase inside its `question:` field (NOT the option `label`), and the harness greps `question:.*<anchor>`. Existing anchors: `findings remain` (Review iter boundary), `Runtime verifier needs` (Runtime resolve). The **new** anchor is the literal `both gates` and it must appear in exactly one `question:` line.

**Version bump rule (memory `feedback_plugin_version_bump`):** any PR touching `plugins/<name>/` must bump that plugin's `version`. This plan bumps `2.3.0 → 2.4.0` and keeps all version strings (plugin.json, SKILL title, SKILL Final Summary, CHANGELOG, the harness version anchor) consistent in one atomic commit (Task 4).

**Why edits are safe against the existing proximity assertions:** Tasks 2–3 only *add* lines inside `## Arguments` and `## Upfront Execution Plan` (both above the Review/Runtime gate dispatch blocks). Everything below shifts down together, so the harness's relative-distance checks (`assert_proximity`, `assert_order` among already-present markers) are preserved. The version-string edits (Task 4) are single-token swaps with no line-count change.

---

## Task 1: Baseline — capture stale reds, confirm target test is green

**Files:** none modified (measurement only).

Per spec §7 + memory `project_qg_pre_existing_test_reds`: `main` carries ~8 pre-existing red tests (codex / consent / security / sandbox families) unrelated to this work. A "regression" is a **new** red not in this baseline. The one test we modify — `test_skill_orchestration_behavior.sh` — must end **green**.

- [ ] **Step 1: Record the pre-existing red set**

Run from the worktree root:

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+qg-upfront-gate-scope
mkdir -p "$CLAUDE_JOB_DIR/tmp" 2>/dev/null || true
BASE="${CLAUDE_JOB_DIR:-/tmp}/tmp/qg-baseline.txt"
: > "$BASE"
for t in plugins/quality-gates/tests/harness/*.sh; do
  if bash "$t" >/dev/null 2>&1; then
    echo "PASS $t" >> "$BASE"
  else
    echo "FAIL $t" >> "$BASE"
  fi
done
cat "$BASE"
```

Expected: a mix of PASS/FAIL; note every `FAIL <path>` — that is the baseline red set. (The exact count may differ from "~8"; what matters is the *set*, captured verbatim.)

- [ ] **Step 2: Confirm the target test is currently green**

Run:

```bash
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh; echo "exit=$?"
```

Expected: ends with `test_skill_orchestration_behavior: all protocol-shape assertions PASS` and `exit=0`. If it is already red, STOP and investigate — the plan assumes this file is green at the start (it is the file we add assertions to).

- [ ] **Step 3: Confirm only two version strings carry `2.3.0` in SKILL.md**

Run:

```bash
grep -nE 'v?2\.3\.0' plugins/quality-gates/skills/quality-pipeline/SKILL.md
```

Expected: exactly two hits — the title line (`# Quality Gates — In-Turn Orchestrator (v2.3.0)`) and the Final Summary template line (`## Quality Gates Pipeline — Complete (v2.3.0)`). This confirms the Task 4 bump targets. (No commit — measurement only.)

---

## Task 2: Add failing gate-scope protocol-shape assertions (RED)

**Files:**
- Modify: `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`

Add the new gate-scope assertions and bump the version anchor. After this task several assertions will FAIL (gate-scope question absent; SKILL still says v2.3.0) — that is the expected RED state.

- [ ] **Step 1: Bump the version anchor (in place)**

Read the file first to confirm the exact text, then Edit lines ~150–151:

Replace:

```bash
# Version bumped to 2.3.0 (title + final summary).
assert_line "v2.3.0 in SKILL" "$(first_line 'v2.3.0|2\.3\.0')"
```

with:

```bash
# Version bumped to 2.4.0 (title + final summary).
assert_line "v2.4.0 in SKILL" "$(first_line 'v2.4.0|2\.4\.0')"
```

- [ ] **Step 2: Append the v2.4.0 gate-scope assertion block**

Insert this block **immediately before** the final `if [[ "$fail" -eq 0 ]]; then` line (the last block, after the existing v2.3.0 "Surface findings" assertions). `$review_line` is already computed near the top of the file (`first_line 'subagent_type.*quality-gates:adversarial'`) and is in scope here.

```bash
# --- v2.4.0: Upfront gate-scope decision (Decision 1) ---

# Decision 1 gate-scope question exists: literal `both gates` anchor in a
# question: field, with header `Gate scope`.
gatescope_q=$(first_line 'question:.*both gates')
assert_line "gate-scope question present (anchor 'both gates')" "$gatescope_q"
assert_line "Gate scope header present" "$(first_line 'header:.*Gate scope')"

# Ordering: gate-scope question BEFORE the Review gate dispatch.
assert_order "gate-scope question precedes Review gate dispatch" "$gatescope_q" "$review_line"

# Ordering: gate-scope (Decision 1) question BEFORE the runtime-scope (Decision 2) question.
runtimescope_q=$(first_line 'question:.*Runtime scope')
assert_order "gate-scope question precedes runtime-scope question" "$gatescope_q" "$runtimescope_q"

# Uniqueness: `both gates` appears in exactly one question: line (anchor convention).
bg_count=$(grep -cE 'question:.*both gates' "$SKILL_MD" || true)
if [[ "$bg_count" -eq 1 ]]; then
  echo "PASS: 'both gates' anchor unique (1 question: line)"
else
  echo "FAIL: 'both gates' anchor not unique ($bg_count question: lines)"
  fail=$((fail + 1))
fi

# `gate` domain documents `both`.
assert_line "gate domain documents both" "$(first_line 'gate.*review.*runtime.*both')"

# Precedence advisory: explicit gate= wins over --skip-runtime (no silent conflict).
assert_line "gate= precedence advisory documented" "$(first_line 'gate=.*wins')"

# Dispatch Loop <-> Upfront Execution Plan consistency (round-2 advisory b82e4d19):
# Dispatch Loop step 2 must reference Decision 1 and the short-circuit so the two
# sections cannot drift.
dl_line=$(first_line '## Dispatch Loop')
assert_line "Dispatch Loop section present" "$dl_line"
assert_line "Dispatch Loop references Decision 1" "$(first_line_after 'Decision 1' "$dl_line")"
assert_line "Dispatch Loop references short-circuit" "$(first_line_after 'short-circuit' "$dl_line")"
```

- [ ] **Step 3: Run the test — expect RED**

Run:

```bash
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh; echo "exit=$?"
```

Expected: `exit=1` with FAILs for — `gate-scope question present`, `Gate scope header present`, `gate-scope question precedes Review gate dispatch`, `gate-scope question precedes runtime-scope question`, `'both gates' anchor unique` (reports `$bg_count` = 0, which `-eq 1` rejects → FAIL), `gate domain documents both`, `gate= precedence advisory documented`, `Dispatch Loop references Decision 1`, `Dispatch Loop references short-circuit`, and `v2.4.0 in SKILL`.

- [ ] **Step 4: Commit (the failing test)**

```bash
git add plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
git commit -m "test(quality-gates): add upfront gate-scope protocol-shape assertions (RED)"
```

---

## Task 3: Restructure SKILL.md `## Upfront Execution Plan` into Decision 1 + Decision 2

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — the `## Upfront Execution Plan` section (locate by the `## Upfront Execution Plan` header; currently lines ~154–182, ending at the blank line before `## Dispatch Loop`).

This makes the existence / ordering / uniqueness / `Gate scope` header assertions go green. The runtime-scope `AskUserQuestion` template is preserved **verbatim** inside Decision 2; only the surrounding structure changes, and the words "gate scope (review / runtime / both)" are removed from the old step-3 prose (gate scope now lives in Decision 1).

- [ ] **Step 1: Write the failing test** — already added in Task 2 (this is a prompt change; the Task 2 assertions are its tests). No new test here.

- [ ] **Step 2: Replace the whole `## Upfront Execution Plan` section body**

Read the section first to confirm exact current text, then replace from the `## Upfront Execution Plan` header through the line immediately before `## Dispatch Loop` with:

````markdown
## Upfront Execution Plan

Two upfront decisions are owned here, in order, before any gate runs — after [Preflight](#preflight) and [Arguments](#arguments), and before the [Dispatch Loop](#dispatch-loop). **Decision 1 (gate scope)** fires first and always (unless an argument pre-answers it); **Decision 2 (runtime scope)** is conditional and only reachable when gate scope = both.

### Decision 1 — Gate scope (always, unless an argument pre-answers it)

Fire this **first**, before any gate dispatch — it is the first decision in the [Dispatch Loop](#dispatch-loop).

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

Reached **only when gate scope = both** (interactive `Run both gates`, or the `gate=both` argument). Decide runtime scope ONCE, but only when there is something risky to decide.

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
````

- [ ] **Step 3: Run the test — partial green**

Run:

```bash
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh; echo "exit=$?"
```

Expected: still `exit=1`, but now PASS for `gate-scope question present`, `Gate scope header present`, `gate-scope question precedes Review gate dispatch`, `gate-scope question precedes runtime-scope question`, and `'both gates' anchor unique`. Still FAIL: `gate domain documents both`, `gate= precedence advisory documented`, `Dispatch Loop references Decision 1`, `Dispatch Loop references short-circuit`, `v2.4.0 in SKILL` (those land in Tasks 3-Step-4 / 4). Confirm no previously-passing assertion regressed (e.g. `requires_decision referenced in plan gate`, `block policy stop/skip/ask present`, `Upfront Execution Plan section present` must still PASS).

- [ ] **Step 4: Update `## Dispatch Loop` step 2**

Read the `## Dispatch Loop` section (currently line ~184) and replace its step 2 line:

Replace:

```markdown
2. Run [Upfront Execution Plan](#upfront-execution-plan) to fix gate scope, runtime scope (`approved_surfaces`), and `block_policy`. Zero-click unless a `requires_decision` surface exists and is not arg-answered.
```

with:

```markdown
2. Run [Upfront Execution Plan](#upfront-execution-plan). **Decision 1 (gate scope)** fires first (always, unless an arg pre-answers it): if the user chooses **Review gate only** (or `gate=review` / `--skip-runtime`), run the Review gate then **short-circuit** — skip Decision 2 and the Runtime gate, and go straight to the final summary (step 6). If **Run both gates** (or `gate=both`), continue. **Decision 2 (runtime scope + `block_policy`)** then fires only when a `requires_decision` surface exists and its surface selection is not arg-answered (zero-click otherwise); it records `approved_surfaces` and `block_policy`.
```

- [ ] **Step 5: Run the test — Dispatch-Loop assertions green**

Run:

```bash
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh; echo "exit=$?"
```

Expected: `Dispatch Loop references Decision 1` and `Dispatch Loop references short-circuit` now PASS. Remaining FAILs: `gate domain documents both`, `gate= precedence advisory documented`, `v2.4.0 in SKILL` (Tasks 3-Step-6 / 4).

- [ ] **Step 6: Update `## Arguments` — add `both` + precedence rule**

Read the `## Arguments` section (currently line ~129) and replace the `gate` bullet:

Replace:

```markdown
- `gate` (optional): `review`, `runtime`, or absent (full pipeline).
```

with:

```markdown
- `gate` (optional): `review`, `runtime`, `both`, or absent.
  - `review` → Review gate only. `runtime` → Runtime gate only (single-gate).
  - `both` → run **both** gates with no gate-scope question (the zero-click "both" escape; symmetric with `review`/`runtime`). `both` answers **gate scope only**, not runtime scope — so Decision 2 still fires for `/qg both` when a `requires_decision` surface exists (same as bare `/qg`).
  - absent → fire the Decision 1 gate-scope question (Review gate only / Run both gates).
  - **Precedence:** an explicit `gate=` value always wins over `--skip-runtime`; on conflict `gate=` wins and a one-line advisory is printed (see Decision 1). No silent conflict.
```

- [ ] **Step 7: Run the test — gate-domain + precedence green**

Run:

```bash
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh; echo "exit=$?"
```

Expected: `gate domain documents both` and `gate= precedence advisory documented` now PASS. The only remaining FAIL is `v2.4.0 in SKILL` (fixed in Task 4).

- [ ] **Step 8: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md
git commit -m "feat(quality-gates): upfront gate-scope decision (Decision 1) + /qg both arg"
```

---

## Task 4: Bump version 2.3.0 → 2.4.0 (atomic) — turn the suite green

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` (title line ~37, Final Summary template line ~567)
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` (line 4)
- Modify: `plugins/quality-gates/CHANGELOG.md` (new top entry)

All version strings move together in one commit (memory `feedback_plugin_version_bump`). The harness version anchor was already changed in Task 2; this task supplies the matching SKILL string.

- [ ] **Step 1: Bump the SKILL title**

In `SKILL.md`, replace:

```markdown
# Quality Gates — In-Turn Orchestrator (v2.3.0)
```

with:

```markdown
# Quality Gates — In-Turn Orchestrator (v2.4.0)
```

- [ ] **Step 2: Bump the Final Summary template**

In `SKILL.md`, replace:

```markdown
## Quality Gates Pipeline — Complete (v2.3.0)
```

with:

```markdown
## Quality Gates Pipeline — Complete (v2.4.0)
```

- [ ] **Step 3: Bump `plugin.json`**

In `.claude-plugin/plugin.json`, replace:

```json
  "version": "2.3.0",
```

with:

```json
  "version": "2.4.0",
```

- [ ] **Step 4: Add the CHANGELOG entry**

In `CHANGELOG.md`, insert this block immediately above the `## [2.3.0] — 2026-06-04` line:

```markdown
## [2.4.0] — 2026-06-04

full `/qg`(gate arg 없음)가 trivia escape 후 어떤 게이트도 돌기 전에 **gate-scope 질문**
(Review gate only / Run both gates)을 1회 발화한다. devbrew Law 1(Clarity Before Code)
instantiation — 실행 범위를 의식적 결정으로 승격. 무클릭 둘 다는 새 `/qg both` arg로.

### Added
- **Upfront gate-scope 결정 (SKILL `## Upfront Execution Plan` Decision 1)**: trivia escape 후
  Review gate dispatch 전, binary AskUserQuestion(앵커 `both gates`, header `Gate scope`).
  "Review gate only" → Runtime 단계 short-circuit; "Run both gates" → Decision 2(runtime scope)로.
- **`/qg both` arg**: `gate` 도메인에 `both` 추가 — gate-scope 질문 없이 두 게이트 실행
  (`review`/`runtime`과 대칭). gate scope만 pre-answer하므로 `requires_decision` surface가 있으면
  Decision 2는 그대로 발화(오늘날 무인자 `/qg`와 동일).
- **신규 protocol-shape assertion** (`test_skill_orchestration_behavior.sh`): gate-scope 질문 존재
  (`question:.*both gates` + header `Gate scope`) · 순서(Review gate dispatch 앞 + runtime-scope 질문 앞) ·
  앵커 고유성 · `gate both` 문서화 · `gate=` precedence advisory · Dispatch Loop↔Upfront 정합.

### Changed
- **기본 동작**: full `/qg`(gate arg 없음)가 더 이상 무클릭으로 둘 다 돌지 않고 gate scope를
  1회 묻는다. 무클릭 둘 다는 `/qg both`. "zero-click happy path"는 *재정의* — gate-scope는 1회
  upfront 클릭(또는 `/qg both|review|runtime`이면 0), 이후 happy path는 무클릭.
- **버전 2.3.0 → 2.4.0** (minor, 새 surface): `plugin.json`, SKILL 제목 + Final Summary,
  `test_skill_orchestration_behavior.sh` 버전 assertion(`v2.3.0`→`v2.4.0`) 동기화.
- **SKILL frontmatter description / `commands/qg.md` / README P18**: gate-scope always-asks 정합.
```

- [ ] **Step 5: Run the target test — fully GREEN**

Run:

```bash
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh; echo "exit=$?"
```

Expected: `test_skill_orchestration_behavior: all protocol-shape assertions PASS` and `exit=0`.

- [ ] **Step 6: Confirm no stray `2.3.0` remains in the bumped surfaces**

```bash
grep -rnE 'v?2\.3\.0' plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
```

Expected: **no output** (CHANGELOG legitimately still contains the historical `## [2.3.0]` heading — that file is excluded from this grep on purpose).

- [ ] **Step 7: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md \
        plugins/quality-gates/.claude-plugin/plugin.json \
        plugins/quality-gates/CHANGELOG.md
git commit -m "chore(quality-gates): bump v2.3.0 → v2.4.0 (gate-scope decision)"
```

---

## Task 5: Reconcile doc surfaces (frontmatter desc, command, README)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` (frontmatter `description`, line ~10)
- Modify: `plugins/quality-gates/commands/qg.md` (argument-hint line 3, Quick Reference table)
- Modify: `plugins/quality-gates/README.md` (P18 bullet, line ~22)

These are not covered by the harness (no automated test asserts them); verify by reading after each edit. Per spec §6 they keep the "zero-click" narrative consistent with the new always-ask behavior, document `/qg both`, and absorb the gate-scope ask into the existing **P18** bullet (no new P# — memory `feedback_devbrew_design_lightness`).

- [ ] **Step 1: Reconcile the SKILL frontmatter `description`**

In `SKILL.md` frontmatter, replace:

```yaml
  Happy path (all gates pass) requires zero user clicks.
```

with:

```yaml
  With a gate argument (`/qg both|review|runtime`) the happy path requires zero
  user clicks; bare `/qg` asks one upfront gate-scope question (Review only /
  both), then runs click-free on the happy path.
```

- [ ] **Step 2: Update the command `argument-hint`**

In `commands/qg.md` line 3, replace:

```yaml
argument-hint: "[review|runtime] [branch [<name>]|--paths <glob>...|--reset] [--skip-runtime] [--plan <path>] [--pr-url <url>]"
```

with:

```yaml
argument-hint: "[review|runtime|both] [branch [<name>]|--paths <glob>...|--reset] [--skip-runtime] [--plan <path>] [--pr-url <url>]"
```

- [ ] **Step 3: Update the Quick Reference table (`/qg` row + new `/qg both` row)**

In `commands/qg.md`, replace the `/qg` row:

```markdown
| `/qg` | Full pipeline (Review gate → Runtime gate), session-scoped diff |
```

with these two rows (the new `/qg both` row directly after the reworded `/qg` row):

```markdown
| `/qg` | Ask gate scope (Review only / both), then run; session-scoped diff |
| `/qg both` | Full pipeline (both gates), no gate-scope question; session-scoped diff |
```

- [ ] **Step 4: Check for any other zero-click claim in the command file**

```bash
grep -niE 'zero.?click|no further commands|no user' plugins/quality-gates/commands/qg.md
```

Review each hit. Line ~49–53 ("No further commands are needed unless the pipeline is aborted at a decision point.") is still accurate (the gate-scope question *is* a decision point) — leave it. If any hit asserts bare `/qg` runs with no interaction, reword it to "after the gate-scope question". Expected: no edit beyond the table/hint unless such a claim is found.

- [ ] **Step 5: Extend the README P18 bullet**

In `README.md`, replace the P18 bullet (line ~22):

```markdown
- **P18 — Upfront 1-회 결정 + 폐기** (v2.2.0) — runtime 범위·block 정책을 `requires_decision` surface가 있을 때만 1회 확정(없으면 zero-click). executor-내부 setup retry ≤3/dispatch, SKILL re-dispatch ≤`runtime_max_resolutions`; 곱이 hard ceiling. kill switch `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1`. fallback(샌드박스 비활성)에서도 working-tree `git status` mutation 체크로 Law 2 구조적 보장 유지(verifier가 실제 트리를 바꾸면 ≤FAIL + loud warn).
```

with:

```markdown
- **P18 — Upfront 1-회 결정 + 폐기** (v2.2.0; gate-scope 확장 v2.4.0) — **gate scope**(Review gate only / Run both gates)는 full `/qg`(gate arg 없음)마다 trivia escape 후 1회 발화하고(`/qg both|review|runtime`이면 0클릭), runtime 범위·block 정책은 `requires_decision` surface가 있을 때만 1회 확정(없으면 zero-click). executor-내부 setup retry ≤3/dispatch, SKILL re-dispatch ≤`runtime_max_resolutions`; 곱이 hard ceiling. kill switch `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1`. fallback(샌드박스 비활성)에서도 working-tree `git status` mutation 체크로 Law 2 구조적 보장 유지(verifier가 실제 트리를 바꾸면 ≤FAIL + loud warn).
```

- [ ] **Step 6: Verify the doc edits read correctly**

```bash
sed -n '1,12p' plugins/quality-gates/skills/quality-pipeline/SKILL.md
sed -n '1,5p' plugins/quality-gates/commands/qg.md
grep -nE 'both gates|/qg both|gate scope|Gate scope' plugins/quality-gates/commands/qg.md plugins/quality-gates/README.md
```

Expected: frontmatter shows the reworded description; argument-hint shows `both`; the Quick Reference shows both rows; README P18 shows the gate-scope clause. (No automated assertion — visual confirmation.)

- [ ] **Step 7: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md \
        plugins/quality-gates/commands/qg.md \
        plugins/quality-gates/README.md
git commit -m "docs(quality-gates): reconcile zero-click narrative + /qg both for gate-scope"
```

---

## Task 6: Full verification — regression check, manual trace, dogfood

**Files:** none modified (verification only).

- [ ] **Step 1: Regression vs baseline**

Re-run the full harness suite and diff against the Task 1 baseline:

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+qg-upfront-gate-scope
BASE="${CLAUDE_JOB_DIR:-/tmp}/tmp/qg-baseline.txt"
NOW="${CLAUDE_JOB_DIR:-/tmp}/tmp/qg-now.txt"
: > "$NOW"
for t in plugins/quality-gates/tests/harness/*.sh; do
  if bash "$t" >/dev/null 2>&1; then echo "PASS $t" >> "$NOW"; else echo "FAIL $t" >> "$NOW"; fi
done
echo "=== baseline vs now (lines only in NOW are new state) ==="
diff "$BASE" "$NOW" || true
```

PASS criteria: the only line that changed for `test_skill_orchestration_behavior.sh` is `FAIL → PASS` (it is green now) **or** it was already PASS in baseline and stays PASS. **No test that was PASS in baseline may become FAIL** (zero new reds). Pre-existing baseline FAILs (codex/consent/security/sandbox) may remain FAIL — they are out of scope.

- [ ] **Step 2: Manual trace per spec §5 state machine (observable criteria)**

Read the restructured `## Upfront Execution Plan` + `## Dispatch Loop` and confirm each row by inspection (these are prompt-flow assertions, not runnable):

  - `/qg` (no arg, non-trivia) → Decision 1 `AskUserQuestion` fires with `both gates` in the `question:` field and header `Gate scope`, **before** the Review gate dispatch.
  - `/qg review` or `/qg --skip-runtime` → Decision 1 does NOT fire; Review gate runs; Runtime stage short-circuited.
  - `/qg both` + a `requires_decision` surface present → Decision 1 does NOT fire; Decision 2 (runtime scope) DOES fire.
  - `/qg both` + no risky surface → neither question fires; both gates run zero-click.
  - `/qg runtime` → single-gate Runtime only (unchanged).
  - `--skip-runtime` combined with `gate=runtime`/`gate=both` → advisory `--skip-runtime ignored: explicit gate=<value> wins` is documented and `gate=` wins (round-2 advisory 9f3c1a72).
  - trivia diff → no question; `Trivia diff — all gates skipped` printed.

- [ ] **Step 3: Cross-file version consistency**

```bash
grep -hE 'v?2\.4\.0' plugins/quality-gates/.claude-plugin/plugin.json \
  plugins/quality-gates/skills/quality-pipeline/SKILL.md \
  plugins/quality-gates/CHANGELOG.md | sort -u
git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+qg-upfront-gate-scope status --porcelain
git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+qg-upfront-gate-scope branch --show-current
```

Expected: `2.4.0` present in plugin.json, SKILL (title + Final Summary), and CHANGELOG; clean tree; branch = `worktree-feature+qg-upfront-gate-scope` (post-commit branch verification — memory `feedback_subagent_worktree_path_emphasis`).

- [ ] **Step 4: Dogfood note (manual, run by the user/operator)**

Because bare `/qg` now asks itself the gate-scope question (meta-circular for dogfooding), dogfood with the explicit args:
  - `/qg both` → observable: neither gate-scope nor (absent risky surface) runtime-scope question fires; **both gates run** end-to-end.
  - `/qg review` → observable: Review gate only; Runtime stage skipped.

This step is a manual smoke check, not a blocking automated gate; record the observation when run.

---

## Self-Review (run before handing off)

**1. Spec coverage** — every spec §6 file is touched: SKILL.md (Tasks 3,4,5), commands/qg.md (Task 5), README.md (Task 5), plugin.json (Task 4), CHANGELOG.md (Task 4), test harness (Task 2). Spec §2 goals: always-ask gate-scope (Task 3 Decision 1), `/qg both` (Task 3 Arguments), sequential+conditional (Task 3 Decision 1→2 + Dispatch Loop step 2). Spec §9 deferred items: exact question/option wording (Task 3), Dispatch Loop step 2 rewrite (Task 3 Step 4), `--skip-runtime`×`gate=` advisory wording (Task 3 Step 2 / Step 6) + its PASS criterion (Task 6 Step 2, round-2 9f3c1a72), Dispatch↔Upfront consistency grep (Task 2 block, round-2 b82e4d19), Dogfood observable line (Task 6 Step 4, round-2 low), v2.3.0→v2.4.0 anchor + 3+ new assertions (Task 2), stale-red baseline (Task 1 / Task 6 Step 1).

**2. Placeholder scan** — no `TBD`/`TODO`/"handle edge cases"; every edit shows the literal old→new text and every command shows expected output.

**3. Type/identifier consistency** — anchor `both gates` (Task 2 grep ↔ Task 3 question text) match; header `Gate scope` (Task 2 grep ↔ Task 3 template) match; `gate.*review.*runtime.*both` (Task 2 grep ↔ Task 3 Step 6 Arguments line) match; `gate=.*wins` (Task 2 grep ↔ Task 3 Step 2 advisory + Step 6 precedence) match; `Decision 1` / `short-circuit` (Task 2 grep ↔ Task 3 Step 4 Dispatch Loop) match; `question:.*Runtime scope` (Task 2 grep ↔ preserved runtime-scope template) match; version `2.4.0` consistent across Tasks 2 and 4.
