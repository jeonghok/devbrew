---
name: quality-pipeline
description: >
  This skill should be used when the user wants to run quality gates, verify code
  quality, check PR readiness, or run the QG pipeline. Triggered by commands like
  "/qg", "run quality gates", "verify my implementation", "check code quality",
  or "is my PR ready to merge". Executes a single gate per turn; the Stop hook
  manages pipeline progression automatically.
cost_class: variable
---

# Quality Gates — Gate Executor

You are executing a **single gate** of the quality pipeline. The Stop hook
manages pipeline progression (gate-to-gate transitions and within-Gate-2
iteration counting). The pipeline is **forward-only**: code-change verdicts
(`NEEDS_RESTART`) terminate with a user-choice prompt rather than auto-restarting
from Gate 1. You do NOT manage state files or pipeline flow.

## Preflight

Before parsing arguments or dispatching agents, do this in order:

**1. Detect continuation vs. first invocation.** Look at the current turn's user
prompt. If it contains the literal string `# QG-STOP-HOOK-CONTINUATION` on its
own line, this is a Stop-hook-injected continuation → go to step 2a. Otherwise
it is a first invocation (via `/qg` or direct skill call) →
go to step 2b.

**2a. Continuation path.** The state file MUST exist. Verify (the session ID
is read from `$CLAUDE_CODE_SESSION_ID`; if empty, treat as an invariant
violation and stop with the same error as below):

```bash
test -f ".claude/quality-gates/${CLAUDE_CODE_SESSION_ID}/pipeline.md"
```

- Exit 0 → proceed to the Arguments section below.
- Non-zero → this is an invariant violation (Stop hook continued a pipeline
  whose state file vanished). Output the following to the user and stop the
  pipeline immediately — do NOT call `setup-qg.sh`, as fresh state would mask
  the real bug:

  > ❌ Pipeline state file disappeared mid-run
  > (`.claude/quality-gates/<session-id>/pipeline.md`).
  > This indicates state corruption or an accidental deletion.
  > Run `/cancel-qg` to clear residual state, then `/qg` to restart.

**2b. First-invocation path.** Bootstrap or validate state by running:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh" --ensure
```

`setup-qg.sh --ensure` handles all cases: creates state if missing, no-ops if
fresh state for this session already exists, overwrites stale state from a
prior (crashed) session, and errors if a concurrent pipeline is genuinely
active.

- Exit 0 → state is valid and session-matched. Proceed to the Arguments section.
- Exit non-zero → surface the script's stderr output to the user verbatim and
  abort. The error is already actionable (e.g. "already active — run
  `/cancel-qg`"); do not attempt recovery.

**Note on the continuation marker.** `# QG-STOP-HOOK-CONTINUATION` is a
deliberate machine-readable sentinel emitted only by
`stop-hook.py:build_gate_prompt()`. If a user types it literally, preflight
will incorrectly take the continuation path — this is an acceptable limitation
for the threat model.

## Arguments

Parse the following from the prompt parameters:

- `gate`: Which gate to execute (1, 2, or 3)
- `plan_path`: Plan file path (or "auto")
- `pr_url`: PR URL (optional)
- `available_plugins`: Comma-separated list of available plugins
- `iteration`: Current Gate 2 iteration number (Gate 2 only)
- `max_iterations`: Maximum Gate 2 iterations (Gate 2 only)
- `previous_findings`: Summary from last Gate 2 iteration (Gate 2 only)

If this is the first gate invocation (no parameters in the prompt), determine the gate
from any `/qg` arguments (gate1, gate2, gate3) or default to gate=1.

## Dependency Check

If `available_plugins` is provided in the prompt parameters, use it directly.

Otherwise (first invocation only), run the pre-flight dependency checks per
[references/dependency-check.md](references/dependency-check.md) to build the
`available_plugins` list.

## Gate Execution

### Pre-pipeline check (§F-1)

Before any agent dispatch in the first gate of a fresh pipeline (skip on
mid-pipeline continuations — Stop hook injection), run:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/pre-pipeline-check.sh"
```

Parse the output (one `key: value` line per output line):

- `result: active_resume` → continue with existing state file (mid-pipeline resume).
- `result: cleared_branch_mismatch` → tell user "branch changed; session scope reset."
- `result: cleared_stale` → tell user "stale session data cleared."
- `result: fresh_start` | `result: preserved` | `result: no_session_data` → silent.

After the check, if `result == cleared_*`, do NOT use any prior
`.claude/quality-gates/<session-id>/files.md` data — proceed as if `--branch`
mode is implied (full diff against `main`). The check itself operates within
the per-session folder; cross-session siblings are never inspected.

### Trivia escape (§E)

Run the trivia detector before Gate 1 dispatch:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/check-trivia.sh"
```

If exit code is `0`:
- Read the stdout line `trivia: <kind>` (kind ∈ `whitespace | rename`).
- Update `.claude/quality-gates/<session-id>/pipeline.md` with
  `status: completed`, `outcome: trivia-skipped`, `trivia_kind: <kind>`.
- Emit `<qg-signal verdict="trivia-skipped" reason="<kind>" />` and stop.
- Tell the user: "Trivia change (`<kind>`); review skipped."

If exit code is non-zero, proceed to Gate 1.

### Gate 1: Plan Verification

Dispatch the plan-verifier agent:

```
Agent(
  subagent_type="quality-gates:plan-verifier",
  prompt="Verify plan implementation completeness.
    plan_path: <plan_path or 'auto'>
    project_dir: <current working directory>
    available_plugins: <available_plugins list>"
)
```

Read the agent's report. Check the Verdict line.

**Implementation Trace (conditional — skill-orchestrated):**

The plan-verifier agent is a leaf agent and does NOT dispatch `feature-dev:code-explorer` itself. Instead, it emits a `### Possibly Implemented (needs trace)` section in its report listing items whose files exist in the git diff but whose checkboxes are unchecked. This skill performs the trace:

1. **Parse the trace section.** Scan the plan-verifier report for a `### Possibly Implemented (needs trace)` header. If the section is absent or empty → no trace is needed. Record "Implementation Trace: Skipped (no possibly-implemented items)" in the Gate 1 output and proceed.
2. **Check plugin availability.** If the section is present but `available_plugins` does NOT include `feature-dev` → skip silently and record "Implementation Trace: Skipped (feature-dev plugin not available)".
3. **Conditional code-explorer dispatch.** If the section is present AND `feature-dev` is available, parse the bulleted items. Each bullet follows the format `- <item text> | files: <comma-separated paths> | line: <N>`. Dispatch `feature-dev:code-explorer` once with the parsed list verbatim:

```
Agent(
  subagent_type="feature-dev:code-explorer",
  prompt="The implementation plan is at <plan_path>. Read it first to understand
    the full scope of planned features.
    Then trace the implementation of the following items that appear to have
    been partially implemented (files exist in git diff but checkboxes unchecked):
    <parsed bullet list verbatim>
    For each, verify it is properly wired up and functional.
    Report which features are fully connected and which have gaps."
)
```

4. **Integrate trace results.** For each item reported as "fully connected", downgrade its status from blocking to "Likely implemented" (non-blocking) in the Gate 1 verdict computation. For each item reported with gaps, keep it as blocking. Append a "Implementation Trace" section to the Gate 1 output summarizing per-item results.
5. **Recompute Gate 1 verdict** using the updated blocking count: if zero blocking items remain → PASS; otherwise FAIL with the remaining count.

**Evidence-Based Verification (conditional):**

If `available_plugins` includes `superpowers` AND the plan-verifier report
contains items in "Likely implemented" or "Possibly implemented" status:

```
Skill("superpowers:verification-before-completion")
```

Follow the skill's gate function:
1. IDENTIFY: Determine which command proves the implementation works
2. RUN: Execute the full command
3. READ: Check full output and exit code
4. VERIFY: Does the output confirm the implementation?

Integrate evidence into Gate 1's verdict.
Note: This step executes commands but does NOT modify any code.

**Output Gate 1 result to user:**
```
## Gate 1: Plan Verification — [PASS/FAIL/SKIP]
[verdict explanation]
[key findings summary]
[evidence-based verification results, if executed]
```

**Handle verdict:**
- PASS → emit signal with verdict="PASS"
- SKIP → emit signal with verdict="SKIP"
- FAIL →
  Report blocking gaps to the user.
  Ask: "N blocking items remain. Should I implement them, or proceed anyway?"
  - If implement: implement the items, then emit signal with verdict="RETRY"
  - If proceed: emit signal with verdict="PASS_WITH_WARNINGS"

### Gate 1 → Gate 2 handoff format

On PASS (or PASS_WITH_WARNINGS), Gate 1 MUST emit, as the last block of its
assistant message, a YAML fenced block named `gate1_summary`:

```yaml
plan_path: <absolute or repo-relative path>
matched_items: [<plan checkbox text>]
unmatched_items: [<plan checkbox text>]
unexpected_files: [<path>]
verdict: PASS | FAIL | NEEDS_CLARIFICATION
```

If `verdict` is FAIL, the pipeline halts here (Gate 2 does not run — Law 1).
If `verdict` is NEEDS_CLARIFICATION, Stop hook injects a user choice
(clarify / proceed / abort).
On PASS, the harness passes this block verbatim to Scout (Phase 0) as part
of its prompt context.

### Gate 2: PR Review

Gate 2 is orchestrated inline by this skill — the skill dispatches review
agents directly because Claude Code does not allow agents to dispatch other
agents (only skills can use `Agent()` with `subagent_type`). There is no
intermediate orchestrator agent for Gate 2.

**Tunable constants** (edit this block to tune):

- `AUTO_PLAN_LINE_THRESHOLD = 30` — minimum changed-line count to dispatch `superpowers:code-reviewer` when plan was auto-detected
- `LARGE_DIFF_CHARS = 50000` — if `git diff` stdout exceeds this, fall back to per-agent `git diff` (no inline)
- `LARGE_DIFF_LINES = 800` — same, counted in `+`/`-` lines

**Optimization principles** (preserve QA quality while reducing token cost):

- Capture `git diff` ONCE per iteration and inline it into dispatch prompts so subagents do not re-fetch
- Use deterministic bash checks (not free-form interpretation) to decide Phase 2 dispatches — **fail-open** when checks are ambiguous
- Skip re-running an agent inside the fix-loop only when the fixed files do not intersect its domain
- Structure dispatch prompts as `[immutable head] → [diff] → [variable tail]` for prompt-cache friendliness
- Record every skip decision in the output report — **no silent skips**
- **Never truncate or summarize the diff** — the complete unified diff is passed verbatim

#### Step 0: Resolve plan_path_source and capture diff

First, derive `plan_path_source`:

- If `plan_path` is literally `"auto"` or empty → `plan_path_source = "auto"`
- Otherwise (user passed an explicit path via `/qg --plan=<path>`, or SKILL.md received a concrete resolved path) → `plan_path_source = "explicit"`

This flag decides whether to unconditionally dispatch `superpowers:code-reviewer` (explicit intent, Path A) or gate it on diff characteristics (auto, Path B).

Then run this **single consolidated bash block**. It captures the diff once, writes it to a cache file for later reuse, computes all Phase 2 trigger flags in the same shell where `$DIFF_CONTENT` is still alive, and emits a JSON line to stdout that this skill will parse:

```bash
# NOTE: `set -e` removed — every command below has explicit failure handling
# (`|| true` / `|| echo 0`). `set -e` interacts poorly with subshell
# command substitution and was causing silent aborts in fix-loop iterations
# (qg self-review §5.1). Each command's failure mode is now local and
# predictable.

# Per-session cache directory (must already exist — setup-qg.sh creates it).
QG_DIR=".claude/quality-gates/${CLAUDE_CODE_SESSION_ID}"
mkdir -p "$QG_DIR"

# Review range selection (qg self-review §5.1 fix):
#   - Working tree dirty → review unstaged changes (default `git diff` form)
#   - Working tree clean + commits ahead of main → review cumulative branch diff
#     so /qg works after a `git commit` without forcing the user to add `branch`
#   - Otherwise (clean tree, no commits ahead) → empty diff scope (no-op review)
# REVIEW_RANGE is empty for the dirty-tree path; "main...HEAD" for the
# committed-ahead-of-main path. Unquoted expansion below is intentional so
# that empty REVIEW_RANGE adds no extra arg to git diff.
REVIEW_RANGE=""
if [ -z "$(git diff --name-only 2>/dev/null)" ] \
   && git rev-parse --verify --quiet main >/dev/null \
   && [ -n "$(git log --oneline main..HEAD 2>/dev/null)" ]; then
  REVIEW_RANGE="main...HEAD"
fi

# Docs filter (§D): exclude *.md, *.txt, *.rst, docs/**, CHANGELOG*, README*
# from the scope passed to code-reviewer-style agents. Gate 1 plan-verifier
# already saw the unfiltered diff above; from here on, agents see code paths only.
# shellcheck disable=SC2086  # REVIEW_RANGE intentionally word-splits (empty | "main...HEAD")
git diff $REVIEW_RANGE --name-only \
  | "${CLAUDE_PLUGIN_ROOT}/scripts/filter-docs.sh" \
  > "$QG_DIR/code-paths.tmp"

if [ -s "$QG_DIR/code-paths.tmp" ]; then
  # shellcheck disable=SC2046,SC2086
  DIFF_CONTENT=$(git diff $REVIEW_RANGE -- $(cat "$QG_DIR/code-paths.tmp"))
else
  # Docs-only change (rare after trivia escape and Gate 1 PASS): empty diff for code reviewers
  DIFF_CONTENT=""
fi

printf '%s' "$DIFF_CONTENT" > "$QG_DIR/diff-cache.txt"

DIFF_CHARS=${#DIFF_CONTENT}
DIFF_LINES=$(printf '%s\n' "$DIFF_CONTENT" | grep -cE '^[+-][^+-]' || echo 0)

LARGE_DIFF_CHARS=50000
LARGE_DIFF_LINES=800
if [ "$DIFF_CHARS" -le "$LARGE_DIFF_CHARS" ] && [ "$DIFF_LINES" -le "$LARGE_DIFF_LINES" ]; then
  INLINE_DIFF_MODE=true
else
  INLINE_DIFF_MODE=false
fi

CHANGED_LINES=$(printf '%s\n' "$DIFF_CONTENT" | grep -E '^[+-][^+-]' || true)

if printf '%s\n' "$CHANGED_LINES" | grep -qE '\b(interface|class|type|struct|enum)\b'; then
  TYPE_DESIGN=1
else
  TYPE_DESIGN=0
fi

# Test detection — `(^|/)tests?/` matches both top-level `tests/` and nested
# `<sub>/tests/` (qg self-review §5.1 fix; previously only matched top-level
# which silently set test_change=0 for monorepo / plugin marketplace layouts).
# shellcheck disable=SC2086
if git diff $REVIEW_RANGE --name-only | grep -qE '(test|spec)\.[jt]sx?$|_test\.py$|\.test\.|\.spec\.|(^|/)tests?/'; then
  TEST_CHANGE=1
else
  TEST_CHANGE=0
fi

COMMENT_CHANGE=0
if printf '%s\n' "$CHANGED_LINES" | awk '
  /^\+[[:space:]]*(\/\/|#|\*|\/\*)/ { n++; if (n >= 3) { found=1; exit } }
  !/^\+[[:space:]]*(\/\/|#|\*|\/\*)/ { n=0 }
  END { exit !found }
'; then
  COMMENT_CHANGE=1
fi

# shellcheck disable=SC2086
NEW_FILES=$(git diff $REVIEW_RANGE --diff-filter=A --name-only | paste -sd, - 2>/dev/null || true)
# shellcheck disable=SC2086
CONFIG_TOUCHED=$(git diff $REVIEW_RANGE --name-only | grep -E '(^|/)(package\.json|tsconfig\.json|pyproject\.toml|Cargo\.toml|go\.mod)$|\.schema\.|/migrations/|\.proto$|openapi\.' | paste -sd, - 2>/dev/null || true)
if [ -n "$NEW_FILES" ] || [ -n "$CONFIG_TOUCHED" ]; then
  ARCH_CHANGE=1
else
  ARCH_CHANGE=0
fi

# shellcheck disable=SC2086
CHANGED_LINE_COUNT=$(git diff $REVIEW_RANGE --numstat | awk '{sum += $1 + $2} END {print sum+0}')

printf '{"diff_chars":%d,"diff_lines":%d,"inline_diff_mode":"%s","type_design":%d,"test_change":%d,"comment_change":%d,"new_files":"%s","config_touched":"%s","arch_change":%d,"changed_line_count":%d,"review_range":"%s"}\n' \
  "$DIFF_CHARS" "$DIFF_LINES" "$INLINE_DIFF_MODE" "$TYPE_DESIGN" "$TEST_CHANGE" "$COMMENT_CHANGE" "$NEW_FILES" "$CONFIG_TOUCHED" "$ARCH_CHANGE" "$CHANGED_LINE_COUNT" "$REVIEW_RANGE"
```

Parse the JSON from the bash stdout and hold the flags in your context. **Fail-open**: if the bash block errors or emits unparseable output, set all Phase 2 flags to `1` so no agent is silently skipped.

If `inline_diff_mode` is `true`, use the `Read` tool on `.claude/quality-gates/<session-id>/diff-cache.txt` (substitute `<session-id>` with `$CLAUDE_CODE_SESSION_ID`) to load the diff content into context for reuse in Agent prompts. If `inline_diff_mode` is `false`, skip the Read — subagents will run their own `git diff`.

#### Dispatch Prompt Template

Assemble every Agent prompt in this fixed order so the prefix is cache-friendly:

```
[Section 1 — IMMUTABLE HEAD]
<role-and-rules text; identical across iterations>
<instruction NOT to re-run git diff if INLINE_DIFF_MODE is true>

[Section 2 — DIFF BLOCK]
(only if inline_diff_mode == true)
## Current Diff
```diff
<cached diff content verbatim, unabridged>
```

[Section 3 — VARIABLE TAIL]
iteration: <N>
previous_findings: <previous_findings or 'none'>
changed_files_since_last_dispatch: <list or 'none'>
```

**Never truncate or summarize the diff content when inlining.** The complete unified diff is passed verbatim.

#### Phase 0: Scout (always run, single dispatch)

**Purpose**: Replace rule-based diff-feature gating with model judgment. Scout reads the filtered diff + Gate 1 summary and returns a structured dispatch plan that overrides the rule-based flags computed in Step 0.

Dispatch:

```
Agent(
  subagent_type="quality-gates:scout",
  model="sonnet",
  prompt="<filtered diff (≤50KB) or '<diff too large; use git diff>'>

  gate1_summary:
  <verbatim YAML from Gate 1>

  session_scope: <branch | session | paths> + <applied path list>
  iteration: <N>"
)
```

Parse Scout's YAML output. Validate:
- `depth ∈ {quick, standard, deep}`
- `phase1_agents ⊆ {code-reviewer, silent-failure-hunter, feature-dev:code-reviewer}`
- If `depth == quick` then `phase2_agents` MUST be `[]`
- All listed agent names are recognized

If validation fails OR scout times out (>60s) OR scout sets `fallback: true`:
- Emit `<qg-signal verdict="scout-fallback" reason="<json-error|timeout|self-fallback>" />`
- Tell user: `[quality-gates] scout fallback engaged: <reason>. Using rule-based gating.`
- Fall through to **Fallback gating** (existing rule-based path below); skip Phase 1 / Phase 2 *depth-aware dispatch* and use the rule-based flags from Step 0 instead.

#### AskUserQuestion hard gate

Compute `len(scout.phase1_agents) + len(scout.phase2_agents)`. If **≥ 4**:

Before dispatching anything, invoke AskUserQuestion:

> Phase 1 (M) + Phase 2 (K) = N reviewer agents.
> Adversarial + Synthesizer always run on top.
> Approximate cost: <pull from §Cost classes>.
>
> Options:
> - `proceed` — dispatch as planned.
> - `phase1-only` — dispatch only Phase 1 agents; skip Phase 2.
> - `abort` — emit `<qg-signal action="abort" reason="user declined fan-out" />` and stop.

scout/adversarial/synthesizer are infrastructure and excluded from the count.

#### Phase 1: Critical Analysis (depth-aware, parallel)

Dispatch the agents in `scout.phase1_agents` **in parallel** (single tool-call
block). Model assignment per dispatch:

| agent | quick | standard | deep | model override on Task call |
|---|---|---|---|---|
| `pr-review-toolkit:code-reviewer` | (upstream Opus) | (upstream Opus) | (upstream Opus) | none — respect upstream `model: opus` |
| `pr-review-toolkit:silent-failure-hunter` | — | included | included | `model: "sonnet"` |
| `feature-dev:code-reviewer` | — | — | included | none — upstream is `model: sonnet` |

For agents whose frontmatter is `inherit`, pass `model: "sonnet"` via Task tool.
For hardcoded-frontmatter agents, do NOT pass `model` (respect upstream choice — Task 1 design decision).

**Fallback** (when scout-fallback engages): use the legacy "always 3 parallel"
behavior below.

#### Phase 1 (legacy/fallback): Critical Analysis

Dispatch these agents **in parallel** (single tool-call block with multiple `Agent()` calls).

**Agent A — pr-review-toolkit:code-reviewer**

Immutable head:
> Review the unstaged changes for bugs, logic errors, security vulnerabilities, and code quality issues. Focus on high-confidence issues only.
>
> If the prompt contains a `## Current Diff` section, operate on that diff verbatim. **Do NOT run `git diff` yourself** — the full unified diff is already provided. You may still use `Read` on specific files for extra context outside the diff's scope.

**Agent B — pr-review-toolkit:silent-failure-hunter**

Immutable head:
> Review the unstaged changes to identify silent failures, inadequate error handling, and inappropriate fallback behavior. Focus on high-confidence issues only.
>
> If the prompt contains a `## Current Diff` section, operate on that diff verbatim. **Do NOT run `git diff` yourself** — the full unified diff is already provided.

**Agent C — feature-dev:code-reviewer** (only if `available_plugins` includes `feature-dev`)

Immutable head:
> Review the unstaged changes for project convention and guideline compliance. Focus on CLAUDE.md adherence, import patterns, naming conventions, and framework-specific patterns. Do NOT focus on bugs or security — another reviewer handles those. Report only issues with confidence >= 80.
>
> If the prompt contains a `## Current Diff` section, operate on that diff verbatim. **Do NOT run `git diff` yourself** — the full unified diff is already provided.

If `feature-dev` is NOT in `available_plugins`, skip Agent C silently and record this in the report's "Phase 2 Skipped Agents" section with reason "feature-dev plugin not available".

Wait for all three agents to complete. Collect their findings.

**Individual dispatch failures**: if any single `Agent()` call fails (plugin missing, agent errors, etc.), record `"<agent-name>: dispatch failed: <error>"` in the output report's "Dispatch Failures" section and continue with the remaining agents. Do not abort Gate 2 on a single failure.

#### Phase 2: Scout-recommended dispatch (primary path)

Dispatch ONLY the agents listed in `scout.phase2_agents` (subset of:
`type-design-analyzer`, `pr-test-analyzer`, `comment-analyzer`,
`superpowers:code-reviewer`, `feature-dev:code-architect`).

Model overrides per dispatch:

| agent | model override |
|---|---|
| `pr-review-toolkit:type-design-analyzer` (inherit) | `model: "sonnet"` |
| `pr-review-toolkit:pr-test-analyzer` (inherit) | `model: "sonnet"` |
| `pr-review-toolkit:comment-analyzer` (inherit) | `model: "sonnet"` |
| `superpowers:code-reviewer` (inherit) | `model: "sonnet"` |
| `feature-dev:code-architect` (hardcoded sonnet) | none — respect upstream |

If the AskUserQuestion gate above selected `phase1-only`, skip this section
entirely (and record "Phase 2 skipped: user requested phase1-only").

If scout-fallback engaged, use the rule-based fallback below.

#### Phase 2 (legacy/fallback): Conditional Analysis

Use the flag values parsed from the Step 0 JSON. Every skip must be recorded in the output report — **no silent skips**.

All Phase 2 dispatches are assembled via the template above. Append the following sentence to the end of each Phase 2 agent's immutable head:

> If the prompt contains a `## Current Diff` section, operate on that diff verbatim. **Do NOT run `git diff` yourself** — the full unified diff is already provided.

**If `type_design == 1`** → dispatch `pr-review-toolkit:type-design-analyzer`:
> Analyze all type/interface/class/struct/enum changes in the current diff for encapsulation, invariant expression, and design quality.

**If `test_change == 1`** → dispatch `pr-review-toolkit:pr-test-analyzer`:
> Review the test coverage in the current changes. Identify critical gaps in test coverage for new functionality.

**If `comment_change == 1`** → dispatch `pr-review-toolkit:comment-analyzer`:
> Analyze code comments in the current changes for accuracy, completeness, and long-term maintainability.

**If `arch_change == 1` AND `available_plugins` includes `feature-dev`** → dispatch `feature-dev:code-architect`:
> Analyze the architectural impact of the current diff. Validate that new files follow existing codebase patterns, module boundaries are respected, and architecture remains consistent. Focus on pattern validation, not bugs or style.

##### superpowers:code-reviewer dispatch (Path A / Path B)

**Prerequisites (both must hold):**

- `plan_path` is not empty
- `available_plugins` includes `superpowers`

If prerequisites fail → skip (record reason).

**Path A — Explicit user intent**: if `plan_path_source == "explicit"` → **dispatch unconditionally**.

**Path B — Auto-detected plan**: if `plan_path_source == "auto"` (or absent — treat missing as auto), dispatch only if **any one** of:

1. `new_files` (from Step 0 JSON) is non-empty
2. `changed_line_count >= 30` (`AUTO_PLAN_LINE_THRESHOLD`)
3. `config_touched` (from Step 0 JSON) is non-empty

Otherwise skip and record the reason (e.g., `"skipped: auto mode, 8 changed lines, no new files, no config touch"`).

Dispatch prompt (immutable head):
> Review the unstaged changes against the implementation plan at `{plan_path}`. Check for plan alignment, architectural deviations from planned approach, SOLID principles, and separation of concerns. Categorize issues as Critical, Important, or Suggestions.
>
> If the prompt contains a `## Current Diff` section, operate on that diff verbatim. **Do NOT run `git diff` yourself** — the full unified diff is already provided.

#### Phase 1.5: Adversarial (Standard/Deep only)

If `scout.depth ∈ {standard, deep}` AND Phase 1 produced any findings:

Dispatch:

```
Agent(
  subagent_type="quality-gates:adversarial",
  model="opus",
  prompt="<all Phase 1 + Phase 2 findings as structured YAML>
  filtered_diff: <verbatim from cache>"
)
```

Apply Adversarial verdicts (`confirm` / `downgrade` / `reject`) to the
finding set BEFORE passing to Synthesizer.

**Conditional re-run on iteration**: when Gate 2 enters a new iteration of
the within-loop fix-loop, compute the hash of the current Phase 1 finding
set as `(file, line, severity, summary)` tuples. Compare to previous
iteration's hash:
- Same hash → SKIP adversarial (already verified).
- Different hash → run adversarial.

#### Phase 1.6: Synthesizer (always when Phase 1 ran)

Dispatch:

```
Agent(
  subagent_type="quality-gates:synthesizer",
  model="sonnet",
  prompt="<all Phase 1 findings + Phase 2 findings + Adversarial verdicts>"
)
```

The synthesizer's Markdown output is what the user sees as "Gate 2 Findings"
(it replaces the raw aggregator dump in the legacy Output Report section).

#### Within-Gate-2 loop — efficient form

The fix-loop (max 5 iterations, preserved) runs scout once per iteration on
**delta diff** rather than the full diff:

1. Identify changed file set since last iteration: `git diff <last-iter-sha> HEAD --name-only`.
2. Re-run Scout with only those files in scope.
3. Dispatch only what scout newly recommends; reuse prior findings for
   unchanged files.
4. Apply Phase 1.5 conditional adversarial re-run rule above.
5. Always run synthesizer.

#### Repeat-detection (no-progress check)

After each iteration, compute:
- `dispatch_hash = sha256(json(scout_output_minimal))` (depth + phase1_agents + phase2_agents only)
- `synth_hash = sha256(synthesizer_markdown)`

If both `dispatch_hash` and `synth_hash` are equal to the previous iteration's:
- Emit `<qg-signal verdict="repeat-detected" />`.
- Stop hook injects user choice (`gate2_repeat_detected` prompt): proceed (accept findings) / abort.

This guards philosophy AP15 ("loop without repeat detection") even though
`max_gate2_iterations=5` provides the hard upper bound.

#### Classifying Findings

From each agent's output, classify findings:

- **CRITICAL** (confidence ≥ 90%): Bugs, security vulnerabilities, data loss risks
- **IMPORTANT** (confidence ≥ 80%): Logic errors, poor error handling, missing validation
- **SUGGESTION** (confidence < 80%): Style, naming, simplification opportunities

#### Fix-and-Review Loop

If CRITICAL or IMPORTANT issues are found:

1. **Fix the issues** using `Edit`/`Write` tools (the skill has these directly — no delegation needed).
2. Capture the set of changed files:
   ```bash
   git diff --name-only
   ```
3. **Re-run the Step 0 consolidated bash block** so the cache file and flags reflect the post-fix state. Re-read `.claude/quality-gates/<session-id>/diff-cache.txt` into context.
4. If `iteration < max_iterations`: selectively re-dispatch per the dedup rule below.
5. If `iteration >= max_iterations`: stop and report remaining issues.

##### Agent Domain Mapping (for dedup)

When deciding whether to re-dispatch an agent, compute the intersection of `fix_files` with the agent's domain paths:

| Agent | Domain paths (glob) |
|---|---|
| `pr-review-toolkit:code-reviewer` | `**/*.{ts,tsx,js,jsx,py,go,rs,java,rb,kt,swift,cs,cpp,c,h}` |
| `pr-review-toolkit:silent-failure-hunter` | same as above |
| `feature-dev:code-reviewer` | same as above |
| `pr-review-toolkit:type-design-analyzer` | files containing type/interface/class/struct/enum definitions |
| `pr-review-toolkit:pr-test-analyzer` | test files only (see `test_change` regex) |
| `pr-review-toolkit:comment-analyzer` | files where comment lines were added/changed |
| `superpowers:code-reviewer` | same as code-reviewer (broad) |
| `feature-dev:code-architect` | source files + config/schema files |
| `pr-review-toolkit:code-simplifier` | never re-run (Phase 3 one-shot) |

##### Dedup Decision

For each agent `A` whose last run returned findings:

```
domain_paths_A = expand(A.domain paths)
if fix_files ∩ domain_paths_A == ∅:
  → SKIP re-dispatch. Record "dedup: A's domain untouched by fix"
else:
  → Re-dispatch A with the updated diff content
```

**Fail-open**: if the intersection check is ambiguous (e.g., domain paths hard to enumerate), **re-dispatch anyway**. Broad-domain agents (code-reviewer, silent-failure-hunter, feature-dev:code-reviewer) almost always re-dispatch because their domain covers all source files.

##### Targeted re-dispatch on specific fix types

These rules layer on top of the dedup rule (they can **expand** the re-dispatch set, never shrink it):

- If the fix changes function signatures or module structure → also re-dispatch `feature-dev:code-architect` (if run before)
- If the fix changes error handling → also re-dispatch `silent-failure-hunter`
- If the fix changes types/interfaces → also re-dispatch `type-design-analyzer` (if `type_design` still 1)
- If the fix deviates from plan → also re-dispatch `superpowers:code-reviewer` (if run before)

#### Phase 3: Polish — one-shot rule

Run `pr-review-toolkit:code-simplifier` **only when ALL THREE** conditions hold in the current iteration:

1. Phase 1 produced **zero** CRITICAL or IMPORTANT findings
2. Phase 2 produced **zero** CRITICAL or IMPORTANT findings
3. The fix-loop made **zero** file changes in this iteration

These conditions naturally limit Phase 3 to at most one execution per pipeline run: it runs only in the final clean iteration, after which the pipeline concludes with PASS.

Dispatch prompt (immutable head):
> Review recently modified code for opportunities to simplify for clarity, consistency, and maintainability while preserving all functionality.
>
> If the prompt contains a `## Current Diff` section, operate on that diff verbatim. **Do NOT run `git diff` yourself** — the full unified diff is already provided.

Code-simplifier findings are **always non-blocking** (suggestions only).

#### Detecting Code Changes

After the final fix (or after each iteration), run:

```bash
git diff --name-only
```

Record the list of changed files. This determines the signal verdict (`PASS` if no fixes, `NEEDS_RESTART` if files were modified).

#### Cache Cleanup

Before emitting the Gate 2 signal (on **any** verdict — PASS, FAIL, NEEDS_RESTART, or error), delete the per-session cache file:

```bash
rm -f ".claude/quality-gates/${CLAUDE_CODE_SESSION_ID}/diff-cache.txt"
```

This must run on every exit path. If the skill turn crashes before cleanup, the next Gate 2 invocation's Step 0 will overwrite the cache — stale content cannot bleed in, but an orphaned cache file is a signal that an earlier run failed abnormally. The folder itself stays; it is removed by `stop-hook.py` on terminal verdict, `/cancel-qg`, or the SessionEnd hook.

#### Output Report

Output a structured report in this exact format. **All skipped agents must be listed with a reason — no silent skips.**

```
## PR Review Report (Gate 2)

**Iteration:** [N]/[max]
**Inline Diff Mode:** [true/false] (diff_chars=[N], diff_lines=[N])
**Agents Dispatched:** [list]
**Files Changed During Fixes:** [list or "none"]

### Phase 2 Skipped Agents
- type-design-analyzer: [reason, e.g. "no type/interface/class/struct/enum in changed lines"]
- pr-test-analyzer: [reason, e.g. "no test files touched"]
- comment-analyzer: [reason, e.g. "no new comment block >= 3 lines added"]
- feature-dev:code-architect: [reason, e.g. "no new files, no config files touched"]
- superpowers:code-reviewer: [reason, e.g. "auto mode, 8 changed lines, no new files, no config touch"]
(omit entries that were dispatched)

### Dedup Skipped (fix-loop re-dispatch)
- [agent-name]: dedup — [agent]'s domain untouched by fix
(or "none")

### Dispatch Failures
- [agent-name]: dispatch failed: [error]
(omit section if none)

### Critical Issues
[list or "none"]

### Important Issues
[list or "none"]

### Suggestions (non-blocking)
[list or "none"]

### Code Changes Made
[list of fixes applied, or "none"]

### Verdict: [PASS / FAIL / NEEDS_RESTART]
[If PASS: "All critical and important issues resolved."]
[If FAIL: "N issues remain after max iterations."]
[If NEEDS_RESTART: "Code was changed during fixes. The pipeline is forward-only — it halts with a user-choice prompt rather than auto-restarting from Gate 1. The user applies the fixes and re-runs /qg."]
```

**Output Gate 2 result to user:**
```
## Gate 2: PR Review (iter [iteration]) — [PASS/FAIL/NEEDS_RESTART]
[verdict explanation]
[agents run and key findings]
```

**Handle verdict:**
- PASS → emit signal with verdict="PASS"
- NEEDS_RESTART → emit signal with verdict="NEEDS_RESTART"
- FAIL → emit signal with verdict="FAIL"

#### Gate 2 Rules

- NEVER reimplement review logic — always delegate to specialized agents (pr-review-toolkit, feature-dev, superpowers)
- If a plugin is not in `available_plugins`, skip its agents and note the skip in the report
- NEVER truncate, summarize, or filter the cached diff content when inlining — pass the full unified diff verbatim
- NEVER silently skip an agent — every skip must appear in the "Phase 2 Skipped Agents" or "Dedup Skipped" section with a reason
- Fail-open: when any bash check, JSON parse, or intersection test is ambiguous, **dispatch** the agent
- When fixing issues, make minimal changes — don't refactor or improve beyond what's needed
- If an agent returns no findings, that domain is clean — don't re-run it
- `code-simplifier` suggestions NEVER block the pipeline
- Always track which files you modify — the orchestrator needs this for the signal's `files_changed` attribute
- If you changed code, your verdict MUST be `NEEDS_RESTART` (not `PASS`) — the Stop hook halts the pipeline with a user-choice prompt so the user can re-run `/qg` after applying fixes. The pipeline does NOT auto-restart; Gate 1 does not re-run automatically
- Path A (`plan_path_source == "explicit"`) preserves the original `superpowers:code-reviewer` dispatch behavior — do not gate it on diff size
- Delete `.claude/quality-gates/<session-id>/diff-cache.txt` on every Gate 2 exit path (including errors)

### Gate 3: Runtime Verification

Gate 3 enforces an **evidence-required** verification model: the agent must
attempt every runnable surface declared in the pre-flight manifest, and any
SKIP must be backed by attempted-but-failed log entries. The skill mediates a
**3-way ping-pong** between itself (mother), the human, and the runtime-verifier
(reviewer): the skill detects infrastructure, asks the user up-front for
required *decisions* (never secret values), dispatches the agent with a
deterministic manifest, validates the resulting evidence-log, and re-dispatches
the agent up to `max_gate3_resolutions` times if the agent emits
`NEEDS_RESOLUTION`.

#### Step 0: Pre-flight detection

Run the deterministic detector once per Gate 3 invocation:

```bash
PLAN_PATH="<plan_file>" "${CLAUDE_PLUGIN_ROOT}/scripts/detect-runtime.sh"
```

Parse the YAML output into a `manifest` dict in your context. **Fail-open**:
if the detector errors or output is unparseable, proceed with an empty
manifest (`runnable_surfaces: []`, `plan_features: []`) — the agent will
then return `SKIP_WITH_EVIDENCE` defensively, which is correct for the
"no detectable runtime infrastructure" case.

#### Step 1: Fast-path SKIP (no agent dispatch)

If ALL of the following hold:

- `manifest.runnable_surfaces == []`
- `manifest.test_runners == []`
- `manifest.plan_features == []`

then there is genuinely nothing to verify. Emit immediately, without
dispatching the runtime-verifier agent (token-cost = 0):

1. Use Bash to write `<attempted_log_path>` with content:
   ```markdown
   # Gate 3 Evidence Log — fast-path skip
   No runnable surfaces, test runners, or plan features detected.
   Detector output saved at <session_dir>/manifest.yaml.
   ```
2. Output to user:
   ```
   ## Gate 3: Runtime Verification — SKIP_WITH_EVIDENCE
   No runnable surfaces detected (markdown-only / library without tests / etc.).
   Evidence log: <path>
   ```
3. Emit signal:
   ```xml
   <qg-signal gate="3" verdict="SKIP_WITH_EVIDENCE" summary="no runnable surfaces detected" files_changed="" />
   ```

Do NOT proceed to Step 2 in this case.

#### Step 2: Upfront resolution (AskUserQuestion, decisions only)

Build a list of `requires_decision` items from the manifest:

- Every `runnable_surface` with `requires_decision: true` (currently only
  `docker-compose`).
- Every `env_status` entry with `exists: false, has_example: true` — propose
  to copy `.env.example` to `.env`.

If the list is non-empty, invoke `AskUserQuestion` ONCE with up to 4 questions
(per the tool's hard cap). For each:

| Manifest item | Question label | Options |
|---|---|---|
| `docker-compose: requires_decision` | "Bring up `docker compose`?" | `yes` / `skip-this-surface` |
| `env_status: has_example, !exists` | "Copy `.env.example` → `.env`?" | `yes` / `manual-set-then-retry` / `skip` |

**Hard rules:**
- The option labels MUST be decisions (yes/no, retry/skip/abort) or paths.
  NEVER ask for a secret value (API_KEY, DB_URL, password) as free text.
- If more than 4 decisions exist, batch the most blocking 3 and let the agent's
  NEEDS_RESOLUTION loop handle the rest mid-run.

Apply the user's answers via the skill's Bash tool (the agent has
`Write/Edit` disallowed):

- "Copy `.env.example` → `.env`: yes" → `cp .env.example .env`
- "Bring up docker compose: yes" → `docker compose up -d` (capture exit code)

Update the manifest in your context with `applied_decisions` so the agent
knows what was already done. If `docker compose up -d` itself fails (daemon
down), record this as a pre-emptive resolvable failure: build a synthetic
`needed` block, jump to Step 5 (NEEDS_RESOLUTION handling) without
dispatching the agent yet.

When the skill emits a synthetic `<qg-signal verdict="NEEDS_RESOLUTION" needed_hash="..." />` for a skill-pre-emptive failure (rather than from the agent), it MUST compute `needed_hash` using the same algorithm as the agent — `printf '%s\n' "${kinds[@]}" | sort | { command -v sha256sum >/dev/null && sha256sum || shasum -a 256; } | cut -d' ' -f1`. An empty `needed_hash` would silently bypass repeat detection at `stop-hook.py:289` (`current_hash and current_hash == prior_hash` is false when current is empty), allowing infinite identical pre-emptive failures up to `max_gate3_resolutions`.

#### Step 2.5: Test scope validation (informational, non-blocking)

This step is informational. It never blocks Gate 3. The kill switch
`DEVBREW_DISABLE_GATE3_TEST_VALIDATION=1` (or
`DEVBREW_SKIP_HOOKS=quality-gates:gate3-test-scope`) skips the step
entirely.

**2.5a — Kill-switch check:**

```bash
if [ "${DEVBREW_DISABLE_GATE3_TEST_VALIDATION:-0}" = "1" ] \
   || [[ ",${DEVBREW_SKIP_HOOKS:-}," == *,quality-gates:gate3-test-scope,* ]]; then
  echo "validation skipped: kill switch"
  KILL_SWITCH=1
else
  KILL_SWITCH=0
fi
```

If `KILL_SWITCH=1`: append `## Test Scope Verdicts\n\nvalidation skipped: kill switch\n\n` to the evidence-log preamble and proceed to Step 3.

**2.5b — Compute candidate test files:**

```bash
CANDIDATES=$("${CLAUDE_PLUGIN_ROOT}/scripts/compute-test-scope-candidates.sh" 2>/dev/null || true)
```

If `$CANDIDATES` is empty (whitespace-only or true empty): append `## Test Scope Verdicts\n\nvalidation skipped: no candidate tests\n\n` to the evidence-log preamble and proceed to Step 3.

**2.5c — Dispatch test-scope-validator agent:**

```
Agent(
  subagent_type="quality-gates:test-scope-validator",
  model="sonnet",
  prompt="""Validate the scope alignment of candidate test files for Gate 3.

  plan_path: <plan_path>

  gate1_summary:
  <verbatim YAML from Gate 1, including matched_items>

  ## Current Diff
  ```diff
  <filtered diff verbatim, ≤50KB>
  ```

  candidate_test_files:
  <newline-separated paths from $CANDIDATES>
  """
)
```

**2.5d — Parse + validate output:**

Read the last YAML fenced block from the agent's reply. Validate:
- Has `test_scope_verdicts:` key with a list
- Has `summary:` key with a string
- Each verdict's `classification` is one of: `aligned`, `outdated-suspicion`, `cherry-pick-suspicion`, `unclear`
- No evidence/summary value contains `%`, `/<digit>+/<digit>+`, or standalone scoring tokens (use regex `[0-9]+%|[0-9]+/[0-9]+` — reject)

**Fail-open**: if parsing fails, schema violates, or agent dispatches errors (timeout, plugin missing, etc.): append `## Test Scope Verdicts\n\nvalidation skipped: <reason>\n\n` to the evidence-log preamble. Proceed to Step 3 without aborting Gate 3.

**2.5e — Render + carry forward:**

Print to user:

```
## Gate 3 — Test Scope Check
- <file>: <classification>[ — <evidence>]   (one line per verdict)

Summary: <agent.summary>. Proceeding to runtime execution; review flagged tests after Gate 3.
```

Use ⚠️ prefix for `outdated-suspicion` and ⚠️⚠️ for `cherry-pick-suspicion`. No prefix for `aligned` (omit evidence to keep output tight). `unclear` uses ⚠️.

Prepend to the evidence-log file at `manifest.attempted_log_path` via Bash heredoc (before runtime-verifier writes its part):

```bash
TMP_LOG=$(mktemp)
cat > "$TMP_LOG" <<EOF
## Test Scope Verdicts

<rendered verdict lines, same as user-facing output minus the ⚠️ marks>

Summary: <agent.summary>

EOF
# If the evidence-log already has content (re-entry), prepend; otherwise just write.
if [ -s "$ATTEMPTED_LOG_PATH" ]; then
  cat "$ATTEMPTED_LOG_PATH" >> "$TMP_LOG"
fi
mv "$TMP_LOG" "$ATTEMPTED_LOG_PATH"
```

Then proceed to Step 3 (dispatch runtime-verifier) regardless of verdicts.

**Gate 3 verdict impact:** none. The runtime-verifier's verdict (PASS/FAIL/SKIP_WITH_EVIDENCE/NEEDS_RESOLUTION) is the sole driver of Gate 3 outcome. Step 2.5 only enriches the evidence-log and surfaces information to the user.

#### Step 3: Dispatch the runtime-verifier agent

Build the dispatch prompt:

```
Agent(
  subagent_type="quality-gates:runtime-verifier",
  prompt="""Verify application runtime behavior using the manifest below.

  project_dir: <cwd>
  plan_path: <plan_path>
  iteration: <gate3_resolution_iter>
  previous_evidence_log_path: <path or 'none'>

  ## Manifest (verbatim from detect-runtime.sh)
  <YAML manifest>

  ## Applied decisions (from upfront AskUserQuestion)
  <YAML list of {decision, action, outcome}>
  """
)
```

Wait for the agent's structured response. Parse:

- `Verdict:` line (`PASS` / `FAIL` / `SKIP_WITH_EVIDENCE` / `NEEDS_RESOLUTION`)
- `Evidence Log:` path
- For `NEEDS_RESOLUTION`: the `needed:` YAML block + `needed_hash:` line

#### Step 4: Validate evidence-log (PASS / FAIL / SKIP_WITH_EVIDENCE)

For PASS or SKIP_WITH_EVIDENCE verdicts, validate the evidence-log:

1. Read the file at `manifest.attempted_log_path`.
2. Build the expected set. For each `runnable_surface` in the manifest, compute its **identifier** by kind:

   | kind | identifier (used for matching evidence-log entries) |
   |---|---|
   | `docker-compose` | `kind: docker-compose` (single entry per manifest) |
   | `npm-script` | `kind: npm-script | name: <name>` (one identifier per script: dev/start/serve/test) |
   | `pytest` | `kind: pytest` |
   | `cargo-test` / `cargo-run` | `kind: cargo-test` / `kind: cargo-run` |
   | `go-test` / `go-run` | `kind: go-test` / `kind: go-run` |
   | `makefile` | `kind: makefile | target: <target>` |

   Add one identifier per `plan_feature` (`kind: plan-feature | feature: <route_or_label>`).

   If `manifest.mcp_browser != none`, add a synthetic identifier `kind: chrome-devtools-mcp` (or `kind: playwright-mcp`).
3. For each expected item, grep for a matching `- kind: ...` block in the
   evidence-log.
4. If any expected item is missing, **reject the verdict**:
   - Output to user: "Evidence-log incomplete: M out of N items unattempted: [list]"
   - Emit `<qg-signal gate="3" verdict="FAIL" summary="incomplete evidence: <count> unattempted" files_changed="" />`
5. If all items present, accept the verdict and emit accordingly:
   - PASS → `<qg-signal gate="3" verdict="PASS" summary="all surfaces verified" files_changed="" />`
   - SKIP_WITH_EVIDENCE → `<qg-signal gate="3" verdict="SKIP_WITH_EVIDENCE" summary="<short>" files_changed="" />`

#### Step 5: NEEDS_RESOLUTION handling (mid-run escalation)

If verdict is `NEEDS_RESOLUTION`:

1. Parse the `needed:` block.
2. Use the agent's emitted `needed_hash` verbatim. If the agent failed to
   emit one, treat that as a contract violation and emit
   `<qg-signal gate="3" verdict="FAIL" summary="agent contract violation: no needed_hash in NEEDS_RESOLUTION report" files_changed="" />`
   instead — do not synthesize a hash, since algorithm divergence between
   skill and agent would silently break convergence detection.
3. Emit signal:
   ```xml
   <qg-signal gate="3" verdict="NEEDS_RESOLUTION" needed_hash="<hash>"
              summary="<one-line>" files_changed="" />
   ```
4. The Stop hook converts this into a `gate3_needs_resolution` continuation
   prompt — that prompt directs you (next turn) to invoke `AskUserQuestion`
   with the agent's `needed` items rendered as **retry / skip-surface / abort**
   options (NEVER as free-text inputs).
5. On retry continuation: re-dispatch the agent using the now-incremented
   `gate3_resolution_iter` value from state (the Stop hook auto-increments
   before the skill is re-invoked) and the previous evidence-log path so
   the agent can resume from where it left off.

#### Step 6: FAIL handling

If verdict is `FAIL` (or `NEEDS_RESTART`), emit:

```xml
<qg-signal gate="3" verdict="FAIL" summary="<one-line>" files_changed="<list or empty>" />
```

The Stop hook routes to `gate3_fail` (existing behavior).

#### Output to user (always)

After every Gate 3 turn, output to the user:

```
## Gate 3: Runtime Verification — [VERDICT]
**Manifest:** [N runnable surfaces, M plan features, mcp=<browser>]
**Evidence:** [path]
**Verdict explanation:** [from agent's report or fast-path text]
```

#### Gate 3 rules

- The detector is read-only — never invoke it with arguments that could
  cause file creation. The detector script already enforces this.
- The agent has `Write`/`Edit` disallowed. If the verdict report from the
  agent claims to have edited a file, treat that as a contract violation
  and emit FAIL with a note.
- Skill-side file ops (`cp`, `docker compose up`) MUST happen via Bash with
  the user's prior consent recorded as an applied_decision.
- NEVER ask the user for a secret value. The only valid resolutions for a
  missing secret are: (a) user sets it on disk and retries, (b) skip the
  affected surface, (c) abort.
- If `DEVBREW_GATE3_MAX_RESOLUTIONS=0`, the Stop hook will escalate the
  first NEEDS_RESOLUTION directly to `gate3_fail` — proceed with FAIL
  handling (Step 6) when the continuation prompt arrives.
- `iteration` parameter increments only on explicit gate3_needs_resolution
  continuations; the Stop hook manages this via update_state_file. Do not
  manually maintain the counter.

## Special Prompts from Stop Hook

The Stop hook may inject special prompts that start with keywords.
Handle them as follows:

### GATE2_NEEDS_RESTART (forward-only, replaces former MAX_TOTAL_ITERATIONS path)

Gate 2 emitted `NEEDS_RESTART` (code-level changes required). Present:
1. **Proceed** — accept current findings as-is and continue to Gate 3
2. **Abort** — stop pipeline; user will apply changes and re-run `/qg`

Based on choice:
- Proceed: `<qg-signal gate="2" verdict="PASS_WITH_WARNINGS" summary="User accepted findings" files_changed="" />`
- Abort: `<qg-signal action="abort" reason="User chose to abort" />`

### GATE2_REPEAT_DETECTED

Gate 2 within-loop is not converging (same dispatch plan + synthesizer
output for two iterations in a row). Present:
1. **Proceed** — accept findings as-is
2. **Abort** — stop pipeline

Based on choice:
- Proceed: `<qg-signal gate="2" verdict="PASS_WITH_WARNINGS" summary="Repeat detected; user accepted" files_changed="" />`
- Abort: `<qg-signal action="abort" reason="User chose to abort" />`

### GATE2_MAX_EXCEEDED

Gate 2 exceeded maximum review iterations. Report remaining issues and present:
1. **Proceed to Gate 3** anyway
2. **Abort** pipeline

Based on choice:
- Proceed: `<qg-signal gate="2" verdict="PASS_WITH_WARNINGS" summary="Proceeding with remaining issues" files_changed="" />`
- Abort: `<qg-signal action="abort" reason="User chose to abort" />`

### GATE3_FAIL

Gate 3 failed. The pipeline is forward-only and does not auto-restart; Gate 1 does not re-run automatically. The user applies fixes and re-runs `/qg`. Present:
1. **Fix and re-run /qg** — apply fixes; pipeline terminates so the user can re-run /qg manually
2. **Skip** runtime verification
3. **Abort** pipeline

Based on choice:
- Fix: inform the user to apply fixes and re-run /qg, then `<qg-signal action="abort" reason="User will re-run /qg after fixes" />`
- Skip: `<qg-signal gate="3" verdict="SKIP" summary="User chose to skip" files_changed="" />`
- Abort: `<qg-signal action="abort" reason="User chose to abort" />`

### GATE3_NEEDS_RESOLUTION

Gate 3 reviewer reported a resolvable missing resource. Read the previous
turn's `needed:` YAML block and present user options via AskUserQuestion.

For each `needed[i]`:
- Question: `needed[i].description`
- Options: `retry` / `skip-this-surface` / `abort` — decisions only; never ask for secret values from the user.

Based on user choice:
- All retries → re-dispatch runtime-verifier per Step 5 above. Then emit a
  fresh `<qg-signal gate="3" verdict="..." />` based on the new agent verdict.
- Any skip-this-surface → record in evidence-log, mark surface as
  user-skipped, emit
  `<qg-signal gate="3" verdict="SKIP_WITH_EVIDENCE" summary="user opted to skip <surface>" files_changed="" />`
- Any abort →
  `<qg-signal action="abort" reason="User aborted during gate3_needs_resolution" />`

### GATE3_REPEAT_DETECTED

Same `needed_hash` appeared twice — the resolution loop is not converging.
Present the user with proceed-with-warnings vs abort:

- Proceed → `<qg-signal gate="3" verdict="PASS_WITH_WARNINGS" summary="repeat detected; user accepted" files_changed="" />`
- Abort → `<qg-signal action="abort" reason="User aborted on repeat detection" />`

## Final Summary

When the Stop hook signals this is the last gate (no more gates after this),
output the final pipeline summary:

```
## Quality Gates Pipeline — Complete

### Gate Results
| Gate | Status | Details |
|------|--------|---------|
| 1. Plan Verification | [status] | [details] |
| 2. PR Review | [status] | [details] |
| 3. Runtime Verification | [status] | [details] |

### Summary of Changes Made
- [file]: [what was changed] (Gate N)

PR is ready for merge.
```

## Signal Tag Rules

After each gate completes, you **MUST** output a signal tag. This is how the Stop
hook knows what happened and what to do next.

**Gate completion signals:**
```xml
<qg-signal gate="N" verdict="VERDICT" summary="one-line summary" files_changed="comma,separated,list" />
```

Verdict values:
- `PASS` — Gate succeeded, no issues
- `FAIL` — Gate failed, issues remain
- `SKIP` — Gate skipped (no plan file, non-web project, etc.)
- `NEEDS_RESTART` — Code was changed during fixes. Pipeline halts with a Stop-hook user-choice prompt; the user applies fixes and re-runs `/qg`. The pipeline does **not** auto-restart (forward-only state machine, v1.5.0+; Gate 1 does not re-run automatically).
- `PASS_WITH_WARNINGS` — Gate passed with non-blocking warnings
- `RETRY` — Gate needs to re-run (Gate 1 implemented missing items)

For Gate 2, include the `iteration` attribute:
```xml
<qg-signal gate="2" verdict="PASS" iteration="3" summary="All issues resolved" files_changed="" />
```

**Pipeline control signals:**
```xml
<qg-signal action="complete" />
<qg-signal action="abort" reason="description" />
<qg-signal action="extend" additional="3" />
```

## Rules

- NEVER directly read or write the contents of `.claude/quality-gates/<session-id>/pipeline.md`. All state creation, validation, and stale-state cleanup is delegated to `setup-qg.sh`; mutation is the Stop hook's job. The skill may probe existence with `test -f` (Preflight only) and invoke `setup-qg.sh --ensure` via Bash. No other interaction is permitted. Sibling session folders under `.claude/quality-gates/` belong to other Claude Code sessions and must not be inspected or modified.
- ALWAYS emit exactly one `<qg-signal>` tag at the end of your response
- Output each gate's result to the user immediately
- If an agent dispatch fails (error), report the error and emit signal with verdict="FAIL"
- The `files_changed` attribute must list every file modified during this gate (comma-separated), or empty string if none
- The `summary` attribute should be a concise one-line description of the gate result
