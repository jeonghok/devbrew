# Gate 3 Test Scope Validator — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a light-weight pre-execution test scope check to Gate 3 of the `quality-gates` plugin, classifying candidate test files as `aligned` / `outdated-suspicion` / `cherry-pick-suspicion` / `unclear` before `runtime-verifier` runs them.

**Architecture:** Skill의 Gate 3 흐름에 Step 2.5 추가. Skill이 결정론적 bash script (`compute-test-scope-candidates.sh`)로 후보 test 파일 목록을 산출하고, 새 sub-agent (`test-scope-validator`)에게 plan + diff + 후보 리스트를 전달해 분류 결과만 받음. 검증은 informational/warning only — Gate 3의 verdict 모델 (PASS/FAIL/SKIP_WITH_EVIDENCE/NEEDS_RESOLUTION) 과 stop-hook continuation 분기는 손대지 않는다.

**Tech Stack:** Bash (POSIX-ish, macOS+Linux), git, Markdown agent definitions with YAML frontmatter, Python (existing test helpers), `quality-pipeline` SKILL (Claude Code skill).

**Spec reference:** [`docs/superpowers/specs/2026-05-12-gate3-test-scope-validator-design.md`](../specs/2026-05-12-gate3-test-scope-validator-design.md)

---

## File Structure Overview

**New files (6):**
- `plugins/quality-gates/scripts/compute-test-scope-candidates.sh` — deterministic candidate-test-file resolver (heuristic src→test + diff fallback)
- `plugins/quality-gates/agents/test-scope-validator.md` — agent definition (frontmatter + system prompt)
- `plugins/quality-gates/tests/test_compute_test_scope_candidates.sh` — unit test for the script
- `plugins/quality-gates/tests/test_test_scope_validator_frontmatter.sh` — Plugin Shape compliance test (frontmatter, scoping)
- `plugins/quality-gates/tests/fixtures/test-scope/aligned/`, `outdated/`, `cherry-pick/` — E2E reference fixtures for manual `/qg --gate3` runs (3 small repos as plain dirs with sample plan + diff + tests)

**Modified files (4):**
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — insert Step 2.5 between existing Step 2 and Step 3 of Gate 3 section
- `plugins/quality-gates/.claude-plugin/plugin.json` — version `1.8.1` → `1.9.0`
- `plugins/quality-gates/CHANGELOG.md` — `## [1.9.0] — 2026-05-12` entry
- `plugins/quality-gates/README.md` — Principles Instantiated (Law 2 3-way, §5.3), Agents 표 (test-scope-validator), Env vars 표 (`DEVBREW_DISABLE_GATE3_TEST_VALIDATION`)

**Untouched (architectural guarantee — AC14):**
- `plugins/quality-gates/hooks/stop-hook.py`
- `plugins/quality-gates/agents/runtime-verifier.md`
- `plugins/quality-gates/scripts/detect-runtime.sh`

---

## Task 1: Candidate computation script (TDD)

**Files:**
- Create: `plugins/quality-gates/tests/test_compute_test_scope_candidates.sh`
- Create: `plugins/quality-gates/scripts/compute-test-scope-candidates.sh`

- [ ] **Step 1.1: Write the failing test**

Create `plugins/quality-gates/tests/test_compute_test_scope_candidates.sh`:

```bash
#!/usr/bin/env bash
# Tests for scripts/compute-test-scope-candidates.sh
# Builds temp git repos at runtime; verifies heuristic src→test mapping
# + changed-test fallback + language-unsupported empty result.

set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/compute-test-scope-candidates.sh"
PASS=0
FAIL=0

note() { echo "  → $1"; }

assert_eq() {
  local actual="$1" expected="$2" msg="$3"
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg"
    echo "    got:      $actual"
    echo "    expected: $expected"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (missing '$needle')"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (unexpected '$needle')"
  fi
}

mktemp_repo() {
  local d
  d=$(mktemp -d -t qg-cand-XXXXXX)
  (
    cd "$d"
    git init -q
    git config user.email test@example.com
    git config user.name Test
    git config commit.gpgsign false
  )
  echo "$d"
}

run_script() {
  local repo="$1"
  ( cd "$repo" && bash "$SCRIPT" ) 2>/dev/null
}

# --- Test 1: Python src change → maps to existing tests/test_foo.py ---
echo "== Test 1: Python mapping =="
REPO=$(mktemp_repo)
(
  cd "$REPO"
  mkdir -p src tests
  echo "def foo(): return 1" > src/foo.py
  echo "from src.foo import foo
def test_foo(): assert foo() == 1" > tests/test_foo.py
  git add . && git commit -q -m "init"
  echo "def foo(): return 2" > src/foo.py
)
OUT=$(run_script "$REPO")
assert_contains "$OUT" "tests/test_foo.py" "T1: maps src/foo.py to tests/test_foo.py"
rm -rf "$REPO"

# --- Test 2: TypeScript src change → maps to .test.ts neighbor ---
echo "== Test 2: TypeScript mapping =="
REPO=$(mktemp_repo)
(
  cd "$REPO"
  mkdir -p src
  echo "export const bar = () => 1" > src/bar.ts
  echo "import { bar } from './bar'
test('bar', () => { expect(bar()).toBe(1) })" > src/bar.test.ts
  git add . && git commit -q -m "init"
  echo "export const bar = () => 2" > src/bar.ts
)
OUT=$(run_script "$REPO")
assert_contains "$OUT" "src/bar.test.ts" "T2: maps src/bar.ts to src/bar.test.ts"
rm -rf "$REPO"

# --- Test 3: changed test file is included verbatim ---
echo "== Test 3: changed-test fallback =="
REPO=$(mktemp_repo)
(
  cd "$REPO"
  mkdir -p tests
  echo "def test_x(): pass" > tests/test_x.py
  git add . && git commit -q -m "init"
  echo "def test_x(): assert True" > tests/test_x.py
)
OUT=$(run_script "$REPO")
assert_contains "$OUT" "tests/test_x.py" "T3: changed test file appears in candidates"
rm -rf "$REPO"

# --- Test 4: unsupported language (Go), no neighbor test → empty result ---
echo "== Test 4: unsupported language =="
REPO=$(mktemp_repo)
(
  cd "$REPO"
  echo "package main
func main() {}" > main.go
  git add . && git commit -q -m "init"
  echo "package main
func main() { println() }" > main.go
)
OUT=$(run_script "$REPO")
assert_eq "$OUT" "" "T4: Go src change without test produces empty output"
rm -rf "$REPO"

# --- Test 5: no diff (clean working tree, no commits ahead) → empty ---
echo "== Test 5: no diff =="
REPO=$(mktemp_repo)
(
  cd "$REPO"
  echo "x" > a.py
  git add . && git commit -q -m "init"
)
OUT=$(run_script "$REPO")
assert_eq "$OUT" "" "T5: clean tree produces empty output"
rm -rf "$REPO"

# --- Test 6: de-duplication (src change + same test also touched) ---
echo "== Test 6: de-dup =="
REPO=$(mktemp_repo)
(
  cd "$REPO"
  mkdir -p src tests
  echo "def f(): return 1" > src/f.py
  echo "from src.f import f
def test_f(): assert f() == 1" > tests/test_f.py
  git add . && git commit -q -m "init"
  echo "def f(): return 2" > src/f.py
  echo "from src.f import f
def test_f(): assert f() == 2" > tests/test_f.py
)
OUT=$(run_script "$REPO")
# tests/test_f.py should appear exactly once
COUNT=$(echo "$OUT" | grep -c '^tests/test_f.py$' || true)
assert_eq "$COUNT" "1" "T6: tests/test_f.py appears exactly once"
rm -rf "$REPO"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

Make executable:

```bash
chmod +x plugins/quality-gates/tests/test_compute_test_scope_candidates.sh
```

- [ ] **Step 1.2: Run test to verify it fails**

```bash
bash plugins/quality-gates/tests/test_compute_test_scope_candidates.sh
```

Expected: FAIL — `scripts/compute-test-scope-candidates.sh` doesn't exist; bash command errors with "No such file or directory" for every test case. Some assertions may still pass coincidentally (empty stdout matches empty expected), but the failures will be obvious.

- [ ] **Step 1.3: Implement the script**

Create `plugins/quality-gates/scripts/compute-test-scope-candidates.sh`:

```bash
#!/usr/bin/env bash
# compute-test-scope-candidates.sh — emit a newline-separated, de-duplicated,
# sorted list of test-file paths that are in-scope for the current diff.
#
# Inputs:
#   $PWD            — must be a git working tree
#   (no env vars)   — review range is computed identically to SKILL.md Gate 2 Step 0
#
# Output (stdout):
#   Zero or more lines, one path per line. Paths are repo-relative.
#   Empty stdout means "no candidates" (skill should silently skip Step 2.5).
#
# Exit: 0 on success (including empty result), non-zero only on hard errors
# (e.g., not a git repo). Skill must fail-open (treat non-zero as empty).
#
# Read-only. Never creates/modifies/deletes files.

set -u

# Confirm git context.
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "compute-test-scope-candidates: not a git repository" >&2
  exit 1
fi

# Review range — identical formula to Gate 2 Step 0 (SKILL.md §"Step 0").
REVIEW_RANGE=""
if [ -z "$(git diff --name-only 2>/dev/null)" ] \
   && git rev-parse --verify --quiet main >/dev/null \
   && [ -n "$(git log --oneline main..HEAD 2>/dev/null)" ]; then
  REVIEW_RANGE="main...HEAD"
fi

TESTRE='(test|spec)\.[jt]sx?$|_test\.py$|\.test\.|\.spec\.|(^|/)tests?/'

# shellcheck disable=SC2086  # REVIEW_RANGE intentionally word-splits
CHANGED_ALL=$(git diff $REVIEW_RANGE --name-only 2>/dev/null || true)

# Split changed files into src vs test.
CHANGED_SRC=$(echo "$CHANGED_ALL" | grep -vE "$TESTRE" || true)
CHANGED_TESTS=$(echo "$CHANGED_ALL" | grep -E "$TESTRE" || true)

# Heuristic src→test mapping (Python, JS, TS only).
MAPPED=""
while IFS= read -r src; do
  [ -z "$src" ] && continue
  case "$src" in
    *.py)
      base=$(basename "$src" .py)
      while IFS= read -r found; do
        [ -n "$found" ] && MAPPED="${MAPPED}${found}"$'\n'
      done < <(find . -type f \( -name "test_${base}.py" -o -name "${base}_test.py" \) 2>/dev/null | sed 's|^\./||')
      ;;
    *.ts|*.tsx|*.js|*.jsx)
      base=$(basename "$src")
      base="${base%.*}"
      while IFS= read -r found; do
        [ -n "$found" ] && MAPPED="${MAPPED}${found}"$'\n'
      done < <(find . -type f \( \
          -name "${base}.test.ts"   -o -name "${base}.test.tsx" \
       -o -name "${base}.test.js"   -o -name "${base}.test.jsx" \
       -o -name "${base}.spec.ts"   -o -name "${base}.spec.tsx" \
       -o -name "${base}.spec.js"   -o -name "${base}.spec.jsx" \
        \) 2>/dev/null | sed 's|^\./||')
      ;;
    # Other languages: no heuristic; only CHANGED_TESTS counts (handled below).
  esac
done <<< "$CHANGED_SRC"

# Union, strip leading ./, sort -u, drop empty lines.
{
  echo "$MAPPED"
  echo "$CHANGED_TESTS"
} | sed 's|^\./||' | sort -u | grep -v '^[[:space:]]*$' || true

exit 0
```

Make executable:

```bash
chmod +x plugins/quality-gates/scripts/compute-test-scope-candidates.sh
```

- [ ] **Step 1.4: Run test to verify it passes**

```bash
bash plugins/quality-gates/tests/test_compute_test_scope_candidates.sh
```

Expected: `Results: 12 passed, 0 failed` (every assert in tests 1–6 passes; exact PASS count depends on how many assertions each test makes — minimum 6).

- [ ] **Step 1.5: Commit**

```bash
git add plugins/quality-gates/scripts/compute-test-scope-candidates.sh \
        plugins/quality-gates/tests/test_compute_test_scope_candidates.sh
git commit -m "$(cat <<'EOF'
feat(qg): add compute-test-scope-candidates.sh script + tests

Deterministic candidate-test-file resolver for Gate 3 Step 2.5.
Heuristic src→test mapping for Python/JS/TS; changed-test fallback
for other languages; sort-unique output. Read-only.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: test-scope-validator agent definition (TDD via frontmatter check)

**Files:**
- Create: `plugins/quality-gates/tests/test_test_scope_validator_frontmatter.sh`
- Create: `plugins/quality-gates/agents/test-scope-validator.md`

- [ ] **Step 2.1: Write the failing frontmatter test**

Create `plugins/quality-gates/tests/test_test_scope_validator_frontmatter.sh`:

```bash
#!/usr/bin/env bash
# Tests for agents/test-scope-validator.md frontmatter — verifies Plugin Shape
# compliance: allowedTools / disallowedTools / model / cost_class declarations.
# Mirrors style of test_runtime_verifier_frontmatter.sh.

set -u

AGENT="$(cd "$(dirname "$0")/.." && pwd)/agents/test-scope-validator.md"
PASS=0
FAIL=0

note() { echo "  → $1"; }

assert_grep() {
  local pattern="$1" msg="$2"
  if grep -qE "$pattern" "$AGENT"; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (pattern '$pattern' not found)"
  fi
}

assert_not_grep() {
  local pattern="$1" msg="$2"
  if ! grep -qE "$pattern" "$AGENT"; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (unexpected '$pattern')"
  fi
}

if [ ! -f "$AGENT" ]; then
  echo "  ✗ FAIL: agent file missing: $AGENT"
  exit 1
fi

# Extract frontmatter block (between first two '---' lines).
FM=$(awk '/^---$/{c++; next} c==1' "$AGENT")

echo "== Frontmatter declarations =="
echo "$FM" | grep -qE '^name:[[:space:]]*test-scope-validator$' \
  && { PASS=$((PASS + 1)); note "PASS: name=test-scope-validator"; } \
  || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: name field"; }
echo "$FM" | grep -qE '^model:[[:space:]]*sonnet$' \
  && { PASS=$((PASS + 1)); note "PASS: model=sonnet"; } \
  || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: model field"; }
echo "$FM" | grep -qE '^cost_class:[[:space:]]*low$' \
  && { PASS=$((PASS + 1)); note "PASS: cost_class=low"; } \
  || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: cost_class field"; }

echo "== allowedTools (positive list) =="
for t in Read Grep Glob Bash; do
  echo "$FM" | grep -qE "^[[:space:]]*-[[:space:]]*${t}$" \
    && { PASS=$((PASS + 1)); note "PASS: allowedTools includes $t"; } \
    || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: allowedTools missing $t"; }
done

echo "== disallowedTools (Law 2 enforcement) =="
for t in Write Edit MultiEdit NotebookEdit; do
  echo "$FM" | grep -qE "^[[:space:]]*-[[:space:]]*${t}$" \
    && { PASS=$((PASS + 1)); note "PASS: disallowedTools includes $t"; } \
    || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: disallowedTools missing $t"; }
done

echo "== body claims =="
assert_grep 'aligned' "body mentions aligned classification"
assert_grep 'outdated-suspicion' "body mentions outdated-suspicion"
assert_grep 'cherry-pick-suspicion' "body mentions cherry-pick-suspicion"
assert_grep 'unclear' "body mentions unclear"
assert_grep 'test_scope_verdicts' "body mentions output key"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

Make executable:

```bash
chmod +x plugins/quality-gates/tests/test_test_scope_validator_frontmatter.sh
```

- [ ] **Step 2.2: Run test to verify it fails**

```bash
bash plugins/quality-gates/tests/test_test_scope_validator_frontmatter.sh
```

Expected: FAIL — `agents/test-scope-validator.md` missing; exits with "agent file missing" at line 1 of body checks.

- [ ] **Step 2.3: Create the agent file**

Create `plugins/quality-gates/agents/test-scope-validator.md`:

```markdown
---
name: test-scope-validator
model: sonnet
cost_class: low
color: yellow
allowedTools:
  - Read
  - Grep
  - Glob
  - Bash
disallowedTools:
  - Write
  - Edit
  - MultiEdit
  - NotebookEdit
description: >
  Light-weight pre-execution check (Gate 3 Step 2.5 of the quality-gates
  pipeline) that classifies each scope-relevant test file as
  aligned / outdated-suspicion / cherry-pick-suspicion / unclear.
  Read-only — never modifies code or tests. Emits a single YAML block
  with per-file classification + one-line evidence. No numeric scoring.

  <example>Context: Gate 3 Step 2.5 — skill provides plan_path,
  Gate 1 matched_items, filtered diff, and candidate_test_files.
  user: "Validate that the candidate test files match the planned scope
  of the diff."
  assistant: "I'll read each candidate test file, compare its assertions
  to the plan items and changed behavior in the diff, and emit a
  test_scope_verdicts YAML block."</example>
---

# Test Scope Validator Agent (Gate 3 Step 2.5)

You are the **Test Scope Validator** — a light-weight pre-execution check that runs *before* `runtime-verifier` executes test suites. Your job is to flag tests that look out of sync with the planned scope, so the user can decide whether to trust the upcoming `npm test` / `pytest` exit code. **You are advisory** — your output never blocks Gate 3.

## Hard Rules

1. **You CANNOT write or edit project files.** `Write` / `Edit` / `MultiEdit` / `NotebookEdit` are disallowed.
2. **You produce one structured YAML block at the end of your message — nothing else after it.** No prose recommendations, no remediation guidance, no follow-up questions.
3. **No numeric scoring.** Do not include percentages, confidences, or X/Y ratings in the `evidence` field. Path components that naturally contain digits (`test_v2.py`) are fine; explicit scoring like `7/10` or `85%` is forbidden.
4. **Do not fetch context outside the candidate files + plan + diff already in your prompt.** No `curl`, no `WebFetch`, no MCP. `Bash` is for reading files (`cat`, `head`, `wc`) only.

## Input (from skill)

Your dispatch prompt contains:

- `plan_path`: path to the spec/plan markdown
- `gate1_summary`: verbatim YAML from Gate 1 with `matched_items`
- `## Current Diff` section: filtered unified diff (≤50KB)
- `candidate_test_files`: newline-separated list of test file paths to evaluate

## Step 1: Build Mental Model

For each item in `candidate_test_files`:
1. Read the file (`Read` tool).
2. Identify the *behaviors* the file asserts (function names called, expected return values, raised exceptions, route paths, etc.).
3. Cross-reference with:
   - `matched_items` from `gate1_summary` — what features were planned
   - the `## Current Diff` — what symbols/behaviors were added/changed/removed

## Step 2: Classify Each Test File

Pick exactly one classification per file:

| Classification | Trigger |
|---|---|
| `aligned` | Assertions clearly match plan items or post-diff behavior |
| `outdated-suspicion` | Assertions reference symbols / behaviors that were renamed, removed, or semantically changed in the diff, yet the test file itself was not updated |
| `cherry-pick-suspicion` | Assertions are tautological (`assert True`, `assert obj is not None` as the only assertion in a test function) OR coverage exists but the behavior tested is orthogonal to plan scope |
| `unclear` | Heavy mocking, indirect coupling, or insufficient context to classify confidently |

Default to `unclear` when in doubt — that is a legitimate signal, not a fallback to hide behind.

## Step 3: Emit Output

End your message with **exactly one** YAML fenced block:

```yaml
test_scope_verdicts:
  - file: <repo-relative path>
    classification: aligned | outdated-suspicion | cherry-pick-suspicion | unclear
    evidence: "<one short clause, ≤120 chars, no numeric scores>"
  - file: ...
    classification: ...
    evidence: "..."
summary: "<N aligned, M outdated-suspicion, K cherry-pick-suspicion, L unclear>"
```

Rules for the block:
- One `- file:` entry per candidate. Do not silently drop a candidate; if you cannot read it, emit `classification: unclear, evidence: "could not read file"`.
- `evidence` is a single short clause — no nested paragraphs, no recommendations, no questions.
- `summary` is the counters joined by `, ` exactly as shown above.

## Notes

- This step is informational. The skill prints your verdicts to the user and carries them into the evidence-log. Whether the user fixes the flagged tests is their decision in the next turn, after Gate 3 completes.
- Bias toward classifying as `unclear` when the evidence is thin — false `outdated-suspicion` / `cherry-pick-suspicion` calls have a higher signal-cost than `unclear`.
- Do not write a remediation plan. The user will read your evidence and decide.
```

- [ ] **Step 2.4: Run test to verify it passes**

```bash
bash plugins/quality-gates/tests/test_test_scope_validator_frontmatter.sh
```

Expected: all PASS (frontmatter fields + body keywords present).

- [ ] **Step 2.5: Commit**

```bash
git add plugins/quality-gates/agents/test-scope-validator.md \
        plugins/quality-gates/tests/test_test_scope_validator_frontmatter.sh
git commit -m "$(cat <<'EOF'
feat(qg): add test-scope-validator agent for Gate 3 Step 2.5

Light-weight pre-execution check that classifies candidate test files
as aligned / outdated-suspicion / cherry-pick-suspicion / unclear.
Frontmatter enforces Law 2 (Write/Edit disallowed) and §5.3 (no
numeric scoring). Informational only.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Wire Step 2.5 into Gate 3 of SKILL.md

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — Gate 3 section

- [ ] **Step 3.1: Locate insertion point**

Read SKILL.md and find the boundary between **Gate 3 Step 2** (Upfront resolution) and **Gate 3 Step 3** (Dispatch the runtime-verifier agent). The exact heading is `#### Step 3: Dispatch the runtime-verifier agent`.

```bash
grep -n "^#### Step [23]: " plugins/quality-gates/skills/quality-pipeline/SKILL.md
```

Expected: two lines like `838:#### Step 2: Upfront resolution...` and `876:#### Step 3: Dispatch the runtime-verifier agent` (exact line numbers may differ; insert the new block immediately before Step 3's heading).

- [ ] **Step 3.2: Insert the new section**

In `plugins/quality-gates/skills/quality-pipeline/SKILL.md`, insert the following block **immediately before** the line `#### Step 3: Dispatch the runtime-verifier agent`:

````markdown
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

````

- [ ] **Step 3.3: Verify SKILL.md still parses**

```bash
# Sanity check: the file still has matched ``` fences and intact heading
# structure. Count ``` occurrences (must remain even).
COUNT=$(grep -c '^```' plugins/quality-gates/skills/quality-pipeline/SKILL.md)
echo "Fence count: $COUNT (must be even)"
[ $((COUNT % 2)) -eq 0 ] && echo "OK" || echo "BROKEN"
```

Expected: `OK` (even fence count).

Also confirm Step 2.5 appears between Step 2 and Step 3:

```bash
grep -nE '^#### Step (2|2\.5|3): ' plugins/quality-gates/skills/quality-pipeline/SKILL.md
```

Expected: 3 lines in order — `Step 2: Upfront resolution`, `Step 2.5: Test scope validation`, `Step 3: Dispatch the runtime-verifier`.

- [ ] **Step 3.4: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md
git commit -m "$(cat <<'EOF'
feat(qg): wire Step 2.5 (test scope validation) into Gate 3

Adds an informational, non-blocking pre-execution check between Step 2
(upfront resolution) and Step 3 (runtime-verifier dispatch). Honors
DEVBREW_DISABLE_GATE3_TEST_VALIDATION kill switch and DEVBREW_SKIP_HOOKS.
Fail-open — any parse/dispatch error skips the step and records the
reason in the evidence-log without aborting Gate 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: E2E reference fixtures (manual verification only)

These fixtures are *reference scenarios* for human verification during a real `/qg --gate3` run. They are not automatically executed — they let a reviewer eyeball what each classification looks like with concrete files.

**Files:**
- Create: `plugins/quality-gates/tests/fixtures/test-scope/aligned/{plan.md, src/auth.py, tests/test_auth.py, DIFF.md}`
- Create: `plugins/quality-gates/tests/fixtures/test-scope/outdated/{plan.md, src/legacy.py, tests/test_legacy.py, DIFF.md}`
- Create: `plugins/quality-gates/tests/fixtures/test-scope/cherry-pick/{plan.md, src/new_feature.py, tests/test_new_feature.py, DIFF.md}`

- [ ] **Step 4.1: Create `aligned` fixture (expected classification = aligned)**

Create `plugins/quality-gates/tests/fixtures/test-scope/aligned/plan.md`:

```markdown
# Plan: Add /login endpoint

## Acceptance Criteria
- [x] POST /login returns 200 with valid creds
- [x] POST /login returns 401 with invalid creds
```

Create `plugins/quality-gates/tests/fixtures/test-scope/aligned/src/auth.py`:

```python
def login(username: str, password: str) -> int:
    if username == "admin" and password == "secret":
        return 200
    return 401
```

Create `plugins/quality-gates/tests/fixtures/test-scope/aligned/tests/test_auth.py`:

```python
from src.auth import login

def test_login_valid():
    assert login("admin", "secret") == 200

def test_login_invalid():
    assert login("admin", "wrong") == 401
```

Create `plugins/quality-gates/tests/fixtures/test-scope/aligned/DIFF.md`:

```markdown
# Fixture: aligned

Expected classification: `aligned` for tests/test_auth.py.
Both assertions match the plan's AC and the actual src/auth.py behavior.
```

- [ ] **Step 4.2: Create `outdated` fixture (expected classification = outdated-suspicion)**

Create `plugins/quality-gates/tests/fixtures/test-scope/outdated/plan.md`:

```markdown
# Plan: Replace parse_v1() with parse_v2()

## Acceptance Criteria
- [x] parse_v2() handles the new schema
- [x] parse_v1() is removed
```

Create `plugins/quality-gates/tests/fixtures/test-scope/outdated/src/legacy.py`:

```python
def parse_v2(payload: dict) -> dict:
    return {"version": 2, "data": payload.get("data", {})}
```

Create `plugins/quality-gates/tests/fixtures/test-scope/outdated/tests/test_legacy.py`:

```python
from src.legacy import parse_v1  # <- references removed symbol

def test_parse_v1_basic():
    assert parse_v1({"data": "x"}) == {"version": 1, "data": "x"}
```

Create `plugins/quality-gates/tests/fixtures/test-scope/outdated/DIFF.md`:

```markdown
# Fixture: outdated

Expected classification: `outdated-suspicion` for tests/test_legacy.py.
Test imports and asserts parse_v1() which the plan + diff removed.
The test file was not updated in this PR scope.
```

- [ ] **Step 4.3: Create `cherry-pick` fixture (expected classification = cherry-pick-suspicion)**

Create `plugins/quality-gates/tests/fixtures/test-scope/cherry-pick/plan.md`:

```markdown
# Plan: Add rate-limiting middleware

## Acceptance Criteria
- [x] Rate-limit returns 429 after 10 requests/min
- [x] Authenticated requests have higher limits
```

Create `plugins/quality-gates/tests/fixtures/test-scope/cherry-pick/src/new_feature.py`:

```python
class RateLimiter:
    def __init__(self, limit: int = 10):
        self.limit = limit
        self.count = 0

    def check(self) -> int:
        self.count += 1
        if self.count > self.limit:
            return 429
        return 200
```

Create `plugins/quality-gates/tests/fixtures/test-scope/cherry-pick/tests/test_new_feature.py`:

```python
from src.new_feature import RateLimiter

def test_ratelimiter_constructs():
    rl = RateLimiter()
    assert rl is not None  # tautological

def test_ratelimiter_has_limit_attr():
    rl = RateLimiter()
    assert hasattr(rl, "limit")  # property existence, not behavior
```

Create `plugins/quality-gates/tests/fixtures/test-scope/cherry-pick/DIFF.md`:

```markdown
# Fixture: cherry-pick

Expected classification: `cherry-pick-suspicion` for tests/test_new_feature.py.
Both tests are tautological — they exist for coverage but never assert
the 429 behavior or the authenticated-higher-limit AC from the plan.
```

- [ ] **Step 4.4: Commit**

```bash
git add plugins/quality-gates/tests/fixtures/test-scope/
git commit -m "$(cat <<'EOF'
test(qg): add reference fixtures for Gate 3 test-scope-validator

Three reference scenarios for manual verification of the validator's
classification accuracy: aligned, outdated, cherry-pick. Each fixture
contains a minimal plan + src + tests + DIFF.md describing the
expected classification.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Version bump + CHANGELOG entry

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` — `version` field
- Modify: `plugins/quality-gates/CHANGELOG.md` — prepend `## [1.9.0] — 2026-05-12` entry

- [ ] **Step 5.1: Read current plugin.json**

```bash
cat plugins/quality-gates/.claude-plugin/plugin.json
```

Expected: JSON containing `"version": "1.8.1"`.

- [ ] **Step 5.2: Bump version to 1.9.0**

Edit `plugins/quality-gates/.claude-plugin/plugin.json` — change the `version` field value from `"1.8.1"` to `"1.9.0"`. Leave all other fields unchanged.

Verify:

```bash
grep '"version"' plugins/quality-gates/.claude-plugin/plugin.json
```

Expected: `"version": "1.9.0",` (trailing comma may vary).

- [ ] **Step 5.3: Add CHANGELOG entry**

Read `plugins/quality-gates/CHANGELOG.md` and insert the following block **immediately after the `# Changelog` heading and any introductory paragraph**, before the existing `## [1.8.1]` heading:

```markdown
## [1.9.0] — 2026-05-12

### Added
- **Gate 3 Step 2.5 — Test scope validator** (informational, non-blocking).
  New `test-scope-validator` agent classifies scope-relevant test files as
  `aligned` / `outdated-suspicion` / `cherry-pick-suspicion` / `unclear`
  before `runtime-verifier` executes them. Surfaces silent failure modes
  (outdated tests against post-refactor behavior; tautological assertions
  added for coverage padding) without blocking Gate 3.
- `scripts/compute-test-scope-candidates.sh` — deterministic candidate
  resolver (Python/JS/TS heuristic src→test mapping + changed-test fallback).
- `agents/test-scope-validator.md` — read-only agent with `Write`/`Edit`
  disallowed (Law 2 3-way separation: writer / test-scope-validator /
  runtime-verifier).
- `tests/test_compute_test_scope_candidates.sh`, `tests/test_test_scope_validator_frontmatter.sh`
- `tests/fixtures/test-scope/{aligned,outdated,cherry-pick}/` — reference
  fixtures for manual verification.

### Changed
- `skills/quality-pipeline/SKILL.md` — Gate 3 gained Step 2.5 between
  Step 2 (Upfront resolution) and Step 3 (Dispatch runtime-verifier).
  Existing verdict model and stop-hook continuation prompts unchanged.

### Environment
- New: `DEVBREW_DISABLE_GATE3_TEST_VALIDATION=1` — skip Step 2.5 entirely.
- New: `DEVBREW_SKIP_HOOKS=quality-gates:gate3-test-scope` — alternate kill
  switch (consistent with existing skip-hook pattern).

```

Verify:

```bash
head -30 plugins/quality-gates/CHANGELOG.md
```

Expected: shows the new `## [1.9.0]` section immediately above `## [1.8.1]`.

- [ ] **Step 5.4: Commit**

```bash
git add plugins/quality-gates/.claude-plugin/plugin.json \
        plugins/quality-gates/CHANGELOG.md
git commit -m "$(cat <<'EOF'
chore(qg): bump version 1.8.1 → 1.9.0 + CHANGELOG entry

Records the Gate 3 Step 2.5 (test scope validator) addition.
Minor bump: new agent surface, no breaking changes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: README updates

**Files:**
- Modify: `plugins/quality-gates/README.md` — Principles Instantiated, Agents 표, Env vars 표

- [ ] **Step 6.1: Inspect README current structure**

```bash
grep -nE '^## |^### ' plugins/quality-gates/README.md | head -40
```

Identify three insertion points:
1. **Principles Instantiated** section — add bullets for Law 2 (3-way separation) and §5.3 (categorical signal)
2. **Agents** section (or equivalent table listing agents) — add row for `test-scope-validator`
3. **Environment variables** section (or equivalent table) — add row for `DEVBREW_DISABLE_GATE3_TEST_VALIDATION`

- [ ] **Step 6.2: Add Principles Instantiated entries**

In the "Principles Instantiated" section, append two new bullets:

```markdown
- **Law 2 — Writer/Reviewer separation (3-way variant).** Gate 3 enforces a 3-way agent split: writer (originating turn) ≠ `test-scope-validator` (pre-execution reviewer) ≠ `runtime-verifier` (executor). Both reviewer agents have `Write` / `Edit` / `MultiEdit` / `NotebookEdit` in `disallowedTools` — separation is physical, not prompt-based.
- **§5.3 — Categorical signal, not numeric scoring.** `test-scope-validator` emits exactly four classification values (`aligned` / `outdated-suspicion` / `cherry-pick-suspicion` / `unclear`). No percentages, confidences, or X/Y ratings. Counter integers in the summary (`1 aligned, 0 outdated…`) are allowed.
```

- [ ] **Step 6.3: Add test-scope-validator to Agents table**

Find the Agents table (or list). Add a row/entry for `test-scope-validator`:

```markdown
| `test-scope-validator` | Gate 3 Step 2.5 pre-execution check. Classifies candidate test files as `aligned` / `outdated-suspicion` / `cherry-pick-suspicion` / `unclear`. Read-only; non-blocking. | sonnet | low |
```

(If the existing table doesn't have these exact columns, match the column layout used by `runtime-verifier` and `plan-verifier` rows.)

- [ ] **Step 6.4: Add env var to Environment table**

Find the Environment table (or list of `DEVBREW_*` vars). Add:

```markdown
| `DEVBREW_DISABLE_GATE3_TEST_VALIDATION` | `1` to skip Gate 3 Step 2.5 (test scope validation) entirely. Default: unset (validation enabled). Honored alongside `DEVBREW_SKIP_HOOKS=quality-gates:gate3-test-scope`. |
```

(Match the existing column layout for other `DEVBREW_*` vars.)

- [ ] **Step 6.5: Verify README is coherent**

```bash
grep -c "test-scope-validator" plugins/quality-gates/README.md
grep -c "DEVBREW_DISABLE_GATE3_TEST_VALIDATION" plugins/quality-gates/README.md
```

Expected: both grep counts >= 1.

- [ ] **Step 6.6: Commit**

```bash
git add plugins/quality-gates/README.md
git commit -m "$(cat <<'EOF'
docs(qg): README updates for test-scope-validator (v1.9.0)

Principles Instantiated: add Law 2 3-way variant + §5.3 categorical
signal entries. Agents table: add test-scope-validator row.
Environment table: add DEVBREW_DISABLE_GATE3_TEST_VALIDATION.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Final verification + smoke check

**Files:** (verification only — no new code)

- [ ] **Step 7.1: Run the full qg test suite**

```bash
cd plugins/quality-gates
bash tests/test_compute_test_scope_candidates.sh && \
bash tests/test_test_scope_validator_frontmatter.sh && \
bash tests/test_detect_runtime.sh && \
bash tests/test_runtime_verifier_frontmatter.sh && \
bash tests/test_setup_qg.sh && \
bash tests/test_discover_plan.sh && \
bash tests/test_isolation.sh && \
bash tests/test_worktree.sh && \
echo "ALL SHELL TESTS PASSED"
```

Expected: every test prints `Results: N passed, 0 failed`; final line `ALL SHELL TESTS PASSED`.

- [ ] **Step 7.2: Run Python tests**

```bash
cd plugins/quality-gates
python3 -m pytest tests/ -v 2>&1 | tail -20
```

Expected: all existing Python tests still pass (we did not modify any Python).

- [ ] **Step 7.3: Verify stop-hook.py is untouched (AC14)**

```bash
git log --oneline main..HEAD -- plugins/quality-gates/hooks/stop-hook.py
```

Expected: empty output (no commits on this branch modified the file).

- [ ] **Step 7.4: Verify runtime-verifier.md is untouched**

```bash
git log --oneline main..HEAD -- plugins/quality-gates/agents/runtime-verifier.md
```

Expected: empty output.

- [ ] **Step 7.5: Verify version bump landed in a single commit alongside its changes**

```bash
git log --oneline main..HEAD
```

Expected: 6 commits (Tasks 1, 2, 3, 4, 5, 6) on the feature branch.

- [ ] **Step 7.6: Manual smoke instructions (for the human reviewer)**

Print the following block as the final task output so the reviewer knows what to test by hand:

```text
Manual smoke verification (run after merge to a branch where /qg is invocable):

1. cd to plugins/quality-gates/tests/fixtures/test-scope/aligned
   - Initialize a temp git repo, commit, make a trivial src change, then
     run /qg --gate3 in a Claude Code session that has quality-gates loaded.
   - Expect: "Test Scope Check" section in the user output with
     `tests/test_auth.py: aligned`. Gate 3 proceeds to runtime-verifier
     normally.

2. cd to ./outdated
   - Same steps. Expect: ⚠️ outdated-suspicion verdict for
     tests/test_legacy.py with evidence mentioning parse_v1.

3. cd to ./cherry-pick
   - Same steps. Expect: ⚠️⚠️ cherry-pick-suspicion verdict for
     tests/test_new_feature.py with evidence mentioning tautological
     or coverage-only assertions.

4. Kill switch:
   - DEVBREW_DISABLE_GATE3_TEST_VALIDATION=1 /qg --gate3 in any fixture.
   - Expect: evidence-log shows "validation skipped: kill switch".
     User-facing output does not include the "Test Scope Check" section.
```

---

## Self-Review

After writing this plan, the author re-read the spec sections in order:

**1. Spec coverage check (each AC → task):**

| AC | Covered in task |
|---|---|
| AC1 — Aligned silent pass | Task 4 (fixture) + Task 3 (Step 2.5e render logic) + Task 7 (smoke step 1) |
| AC2 — Outdated warning | Task 4 (fixture) + Task 3 (Step 2.5e render logic) + Task 7 (smoke step 2) |
| AC3 — Cherry-pick warning | Task 4 (fixture) + Task 3 (Step 2.5e render logic) + Task 7 (smoke step 3) |
| AC4 — Mixed verdicts | Task 3 (Step 2.5e renders one line per verdict, all categories) |
| AC5 — Empty candidates fast-skip | Task 1 (Test 4, Test 5) + Task 3 (Step 2.5b empty check) |
| AC6 — Kill switch | Task 3 (Step 2.5a) + Task 7 (smoke step 4) |
| AC7 — Plugin Shape | Task 2 (frontmatter test enforces it) |
| AC8 — Fail-open | Task 3 (Step 2.5d explicit fail-open clause) |
| AC9 — Output schema | Task 2 (agent system prompt) + Task 3 (Step 2.5d validation) |
| AC10 — No numeric scoring | Task 2 (agent rule 3) + Task 3 (regex reject in 2.5d) |
| AC11 — Heuristic mapping unit test | Task 1 (Tests 1–6) |
| AC12 — Trivia compatibility | Implicit (trivia escape runs before Gate 1, never reaches Gate 3) — documented in spec §5 AC12, no task needed |
| AC13 — Backward compat | Task 7 (step 3 verifies stop-hook untouched; kill switch test in smoke) |
| AC14 — stop-hook untouched | Task 7 (step 7.3 git log check) |
| AC15 — Law 2 verification | Task 2 (frontmatter test enforces `disallowedTools`) + agent definition itself |

All 15 ACs covered. No gaps.

**2. Placeholder scan:** No `TBD`, `TODO`, `implement later`, or "similar to Task N" references. Every code block contains actual content. The "manual smoke" task is intentionally manual — it is the final step that requires a live `/qg` invocation, which cannot be automated in a plan execution context.

**3. Type/identifier consistency:**
- Script name: `compute-test-scope-candidates.sh` (consistent across Tasks 1, 3, 5)
- Agent name: `test-scope-validator` (consistent across Tasks 2, 3, 5, 6)
- Env var: `DEVBREW_DISABLE_GATE3_TEST_VALIDATION` (consistent across Tasks 3, 5, 6, 7)
- Classification values: `aligned` / `outdated-suspicion` / `cherry-pick-suspicion` / `unclear` (consistent across Tasks 2, 3, 5, 6)
- Version: `1.9.0` (consistent across Tasks 5, 6)

No drift detected.
