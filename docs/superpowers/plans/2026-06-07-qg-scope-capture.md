# qg scope-capture — self-honest verdict + scope transparency (v2.6.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop qg's Review gate from labelling an unreviewed branch "clean" (false-clean) by adding a deterministic read-only scope signal that drives an honest-verdict floor (kill-unable) and a one-click redirect gate (kill-able), plus one additive Runtime transparency line — without changing the session default, genuine-no-op clean, or `/qg branch`.

**Architecture:** One read-only script (`check-review-scope.sh`) emits a single signal (`empty_scope_with_changes` | `normal` | `genuine_noop` | `degraded`). The SKILL calls it ONCE at Review iter-1 and caches `$scope_signal`/`$branch_ahead_count`/`$base`; two consumers read that cache — (A) a redirect `AskUserQuestion` gate (UX, P17, disabled by `DEVBREW_QG_DISABLE_SCOPE_REDIRECT=1`) and (B) a deterministic verdict-label floor at Step 4.5 (correctness, P8, not kill-able). Runtime gains one additive line after Step R2. Source design: `docs/superpowers/specs/2026-06-07-qg-scope-capture-design.md`.

**Tech Stack:** bash 3.2-compatible shell scripts (macOS), `git` plumbing (`merge-base`, `diff --name-only`, `rev-parse --verify`, `symbolic-ref`), bash test harnesses (fixture git repos under `mktemp`), markdown prompt-as-spec (`SKILL.md`), static grep/awk protocol-shape verifier.

---

## Implementation Notes (read before starting)

- **Strictly sequential, subagent-driven.** No parallel or speculative dispatch (user memory: *Evidence before "approved"*). Complete and verify each task before the next.
- **Law 2 invariant (C1):** NEVER edit `plugins/quality-gates/agents/*.md`. This feature touches no persona. Task 6 verifies the diff is persona-free.
- **bash 3.2 footguns (memory):** never expand `"${arr[@]}"` of an empty array under `set -u` (guard with `[[ ${#arr[@]} -gt 0 ]]`); avoid capturing `$(git … -z)` into a variable (NUL stripped) — use `--name-only | wc -l`. The new script uses `set -u` (NOT `-e`) for graceful degradation, matching `detect-runtime.sh`.
- **Run tests from the repo root** (`/Users/jeonghokim/Downloads/devbrew`). Per memory, `main` carries ~8 pre-existing stale reds (codex/consent/security/sandbox — environment-dependent, unrelated). Task 1 Step 0 captures that baseline; Task 6 confirms no NEW reds.
- **macOS awk caveat (existing harness, line ~319):** `awk -v p='\('` mangles escaped parens. All new grep anchors below are paren-free and `$`-free literals (`script-emitted base`, `regardless of Review scope`, `review scope is empty`, `no scope reviewed`, `NOT certified clean`).
- **All file paths below are absolute or repo-root-relative.** `${CLAUDE_PLUGIN_ROOT}` inside `SKILL.md` resolves to `plugins/quality-gates/` at runtime — keep that token verbatim in SKILL edits.
- **Commit after each task** with a Conventional Commit (`feat(quality-gates): …`). Work on the existing branch `feature/qg-scope-capture` (do not branch again; do not rebase — user memory).

---

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `plugins/quality-gates/scripts/check-review-scope.sh` | **NEW** read-only deterministic scope signal (single responsibility: "is resolved scope empty while changes exist?") | 1 |
| `plugins/quality-gates/tests/test_check_review_scope.sh` | **NEW** unit test — AC1–AC5 via fixture git repos | 1 |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | allowed-tools entry; iter-1 call+cache (Step 1b); `## Empty-scope redirect decision` section; Step 4.5 floor (both clean sub-cases); Runtime R2→R3 line; Final Summary variant; version bump | 2,3,4,5 |
| `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` | static protocol-shape assertions for the SKILL edits (redirect anchor uniqueness, honest anchors, AC13 base reuse, runtime line proximity, v2.6.0) | 2,3,4,5 |
| `plugins/quality-gates/commands/qg.md` | Quick Reference kill-switch row + Scope-section floor/redirect note | 5 |
| `plugins/quality-gates/.claude-plugin/plugin.json` | `2.5.0` → `2.6.0` | 5 |
| `plugins/quality-gates/CHANGELOG.md` | `## [2.6.0] — 2026-06-07` block | 5 |
| `plugins/quality-gates/README.md` | Principles Instantiated: P8 floor bullet | 5 |
| `docs/philosophy/devbrew-harness-philosophy.md` | P8 determinism-economy: absorb the self-honest floor (no new P#) | 5 |

---

## Task 1: `check-review-scope.sh` + unit test

**Files:**
- Create: `plugins/quality-gates/scripts/check-review-scope.sh`
- Create (Test): `plugins/quality-gates/tests/test_check_review_scope.sh`

Covers spec §5.1 and **AC1–AC5**.

- [ ] **Step 0: Capture the pre-existing test baseline**

Run (from repo root) and save the output — this is the stale-red baseline to compare against in Task 6:

```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in plugins/quality-gates/tests/*.sh plugins/quality-gates/tests/harness/*.sh; do
  printf '%s: ' "$t"; bash "$t" >/dev/null 2>&1 && echo OK || echo RED
done | tee "$CLAUDE_JOB_DIR/tmp/qg-baseline-before.txt"
```

Expected: ~8 `RED` lines (codex/consent/security/sandbox-related, environment-dependent). Note them; they are unrelated to this work.

- [ ] **Step 1: Write the failing unit test**

Create `plugins/quality-gates/tests/test_check_review_scope.sh` with this exact content:

```bash
#!/usr/bin/env bash
# test_check_review_scope.sh — coverage for scripts/check-review-scope.sh
# (design v2.6.0 §5.1, AC1–AC5). Each case isolates a throwaway git repo under
# mktemp so the live repo's working tree is untouched.

set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/check-review-scope.sh"

PASS=0; FAIL=0
REPO=""
pass() { PASS=$((PASS + 1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }

# field <key> <output-text> → prints the value after "<key>: "
field() { printf '%s\n' "$2" | awk -v k="$1:" '$1 == k { print $2 }'; }

# Build a repo with a 'main' base branch + a 'feature' branch 1 commit ahead.
# Sets global REPO and leaves CWD inside it (on feature, clean tree).
mk_repo_feature_ahead() {
  REPO=$(mktemp -d); cd "$REPO"
  git init -q
  git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo base > a.txt; git add a.txt; git commit -qm base
  git checkout -q -b feature
  echo work >> a.txt; git commit -qam work
}

# AC1 (session): empty session scope + branch ahead → empty_scope_with_changes
case_session_empty_branch_ahead() {
  mk_repo_feature_ahead
  export CLAUDE_CODE_SESSION_ID="test-scope-empty-$$"
  local out; out=$(bash "$SCRIPT" session)
  if [[ "$(field signal "$out")" == "empty_scope_with_changes" \
     && "$(field branch_ahead_count "$out")" == "1" \
     && "$(field base "$out")" == "main" ]]; then
    pass "session empty + branch ahead → empty_scope_with_changes (base=main, ahead=1)"
  else
    fail "session empty + branch ahead (got: $out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

# AC3 (session): files.md has >=1 entry → normal
case_session_files_present() {
  mk_repo_feature_ahead
  export CLAUDE_CODE_SESSION_ID="test-scope-files-$$"
  mkdir -p ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID"
  printf '# Quality-Gates Session Files\n\n- a.txt\n' \
    > ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID/files.md"
  local out; out=$(bash "$SCRIPT" session)
  if [[ "$(field signal "$out")" == "normal" \
     && "$(field resolved_count "$out")" == "1" ]]; then
    pass "session files.md present → normal (resolved_count=1)"
  else
    fail "session files.md present (got: $out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

# AC2: empty session + no changes (on base, clean) → genuine_noop
case_genuine_noop() {
  mk_repo_feature_ahead
  git checkout -q main
  export CLAUDE_CODE_SESSION_ID="test-scope-noop-$$"
  local out; out=$(bash "$SCRIPT" session)
  if [[ "$(field signal "$out")" == "genuine_noop" ]]; then
    pass "empty session + no changes → genuine_noop"
  else
    fail "genuine_noop (got: $out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

# AC3 (paths): glob matches a changed file → normal
case_paths_changed() {
  mk_repo_feature_ahead
  echo dirty >> a.txt
  export CLAUDE_CODE_SESSION_ID="test-scope-paths-$$"
  local out; out=$(bash "$SCRIPT" paths 'a.txt')
  if [[ "$(field signal "$out")" == "normal" \
     && "$(field resolved_count "$out")" == "1" ]]; then
    pass "paths glob matches changed file → normal"
  else
    fail "paths changed (got: $out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

# AC1 (paths): glob matches nothing in the diff but changes exist elsewhere
#              → empty_scope_with_changes
case_paths_no_match() {
  mk_repo_feature_ahead
  echo dirty >> a.txt
  export CLAUDE_CODE_SESSION_ID="test-scope-paths2-$$"
  local out; out=$(bash "$SCRIPT" paths 'b.txt')
  if [[ "$(field signal "$out")" == "empty_scope_with_changes" ]]; then
    pass "paths glob no match but changes exist → empty_scope_with_changes"
  else
    fail "paths no match (got: $out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

# AC4: detached HEAD → degraded + exit 0 (fail-open)
case_degraded_detached() {
  mk_repo_feature_ahead
  git checkout -q --detach
  export CLAUDE_CODE_SESSION_ID="test-scope-detach-$$"
  local out rc; out=$(bash "$SCRIPT" session); rc=$?
  if [[ "$(field signal "$out")" == "degraded" && "$rc" -eq 0 ]]; then
    pass "detached HEAD → degraded + exit 0 (fail-open)"
  else
    fail "degraded detached (rc=$rc got: $out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

# AC4: no main/master base branch + no remote → degraded + exit 0
case_degraded_no_base() {
  REPO=$(mktemp -d); cd "$REPO"
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b weirdname
  echo x > a.txt; git add a.txt; git commit -qm x
  export CLAUDE_CODE_SESSION_ID="test-scope-nobase-$$"
  local out rc; out=$(bash "$SCRIPT" session); rc=$?
  if [[ "$(field signal "$out")" == "degraded" && "$rc" -eq 0 ]]; then
    pass "no main/master base → degraded + exit 0"
  else
    fail "degraded no-base (rc=$rc got: $out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

# base resolution via refs/remotes/origin/HEAD symbolic-ref → base=main
case_base_origin_head() {
  local remote; remote=$(mktemp -d); git init -q --bare "$remote"
  mk_repo_feature_ahead
  git remote add origin "$remote"
  git push -q origin main
  git push -q origin feature
  git remote set-head origin main
  export CLAUDE_CODE_SESSION_ID="test-scope-originhead-$$"
  local out; out=$(bash "$SCRIPT" session)
  if [[ "$(field base "$out")" == "main" \
     && "$(field signal "$out")" == "empty_scope_with_changes" ]]; then
    pass "base via origin/HEAD symbolic-ref → base=main"
  else
    fail "base origin/HEAD (got: $out)"
  fi
  cd / && rm -rf "$REPO" "$remote"; unset CLAUDE_CODE_SESSION_ID
}

# AC5: read-only — working tree + git status unchanged before/after
case_read_only() {
  mk_repo_feature_ahead
  export CLAUDE_CODE_SESSION_ID="test-scope-ro-$$"
  local before after
  before=$(git status --porcelain=v1; find . -type f | sort)
  bash "$SCRIPT" session >/dev/null 2>&1
  after=$(git status --porcelain=v1; find . -type f | sort)
  if [[ "$before" == "$after" ]]; then
    pass "read-only: working tree + git status unchanged"
  else
    fail "read-only violated (before != after)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

case_session_empty_branch_ahead
case_session_files_present
case_genuine_noop
case_paths_changed
case_paths_no_match
case_degraded_detached
case_degraded_no_base
case_base_origin_head
case_read_only

echo
echo "test_check_review_scope: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
```

Make it executable:

```bash
chmod +x plugins/quality-gates/tests/test_check_review_scope.sh
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash plugins/quality-gates/tests/test_check_review_scope.sh`
Expected: FAIL — every case fails because `scripts/check-review-scope.sh` does not exist yet (bash reports "No such file or directory"; `field` returns empty, assertions miss). The summary line shows `9 failed`.

- [ ] **Step 3: Write the script**

Create `plugins/quality-gates/scripts/check-review-scope.sh` with this exact content:

```bash
#!/usr/bin/env bash
# check-review-scope.sh — read-only deterministic scope signal for the Review gate.
# (design v2.6.0 §5.1) Single responsibility: "Is the resolved review scope empty
# while there are changes that warrant review?" — the false-clean detector.
#
# Inputs:
#   $1                       — scope mode: session | branch | paths   (default: session)
#   $2..                     — glob list (paths mode only)
#   $CLAUDE_CODE_SESSION_ID  — locates .claude/quality-gates/<sid>/files.md (session mode)
#
# Output (structured stdout, consumed by SKILL.md):
#   resolved_count: <N>
#   branch_ahead_count: <M>
#   worktree_dirty: yes|no
#   base: <branch-name|->
#   signal: empty_scope_with_changes | normal | genuine_noop | degraded
#
# Exit code: always 0 (signal: degraded carries the fail-open state — C5).
# Read-only: never creates/modifies/deletes files (C4). Invoke from project root.

set -u   # NOT -e: graceful degradation, like detect-runtime.sh.

mode="${1:-session}"
shift || true
globs=("$@")

emit_degraded() {
  echo "resolved_count: 0"
  echo "branch_ahead_count: 0"
  echo "worktree_dirty: no"
  echo "base: -"
  echo "signal: degraded"
  exit 0
}

# --- git sanity (fail-open on anything uncertain — C5) ---
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || emit_degraded
git rev-parse --verify --quiet HEAD >/dev/null 2>&1 || emit_degraded
# detached HEAD → no branch context to compare → degraded.
git symbolic-ref --quiet HEAD >/dev/null 2>&1 || emit_degraded

# --- base resolution (single source of truth — C6). All existence checks use
#     `git rev-parse --verify --quiet` for consistent local/remote handling. ---
base=""
if ref=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); then
  base="${ref#origin/}"
elif git rev-parse --verify --quiet refs/remotes/origin/main >/dev/null 2>&1; then
  base="main"
elif git rev-parse --verify --quiet refs/remotes/origin/master >/dev/null 2>&1; then
  base="master"
elif git rev-parse --verify --quiet refs/heads/main >/dev/null 2>&1; then
  base="main"
elif git rev-parse --verify --quiet refs/heads/master >/dev/null 2>&1; then
  base="master"
else
  emit_degraded
fi

merge_base=$(git merge-base "$base" HEAD 2>/dev/null) || emit_degraded
[[ -n "$merge_base" ]] || emit_degraded

branch_ahead_count=$(git diff --name-only "$merge_base"..HEAD 2>/dev/null | wc -l | tr -d ' ')

# --- worktree_dirty: tracked changes OR non-ignored untracked.
#     --exclude-standard is intentional (NG4): .gitignore'd build artifacts must
#     NOT count as "changes" and false-trip empty_scope_with_changes. ---
worktree_dirty="no"
if [[ -n "$(git diff HEAD --name-only 2>/dev/null)" ]]; then
  worktree_dirty="yes"
elif [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
  worktree_dirty="yes"
fi

# --- resolved_count per mode ---
resolved_count=0
case "$mode" in
  session)
    sid="${CLAUDE_CODE_SESSION_ID:-}"
    files_md=".claude/quality-gates/$sid/files.md"
    if [[ -n "$sid" && -f "$files_md" ]]; then
      # files.md entries are markdown list items "- <path>" (session-tracker hook).
      resolved_count=$(grep -cE '^- ' "$files_md" 2>/dev/null)
      resolved_count=${resolved_count:-0}
    fi
    ;;
  branch)
    resolved_count="$branch_ahead_count"
    ;;
  paths)
    if [[ ${#globs[@]} -gt 0 ]]; then
      # glob matches that ALSO appear in `git diff HEAD` (changed-and-matched),
      # not bare glob membership.
      resolved_count=$(git diff HEAD --name-only -- "${globs[@]}" 2>/dev/null | wc -l | tr -d ' ')
    fi
    ;;
  *)
    emit_degraded
    ;;
esac

# --- changes_exist + signal decision ---
changes_exist="no"
if [[ "$branch_ahead_count" -gt 0 || "$worktree_dirty" == "yes" ]]; then
  changes_exist="yes"
fi

if [[ "$resolved_count" -gt 0 ]]; then
  signal="normal"
elif [[ "$changes_exist" == "yes" ]]; then
  signal="empty_scope_with_changes"
else
  signal="genuine_noop"
fi

echo "resolved_count: $resolved_count"
echo "branch_ahead_count: $branch_ahead_count"
echo "worktree_dirty: $worktree_dirty"
echo "base: $base"
echo "signal: $signal"
exit 0
```

Make it executable:

```bash
chmod +x plugins/quality-gates/scripts/check-review-scope.sh
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash plugins/quality-gates/tests/test_check_review_scope.sh`
Expected: PASS — `test_check_review_scope: 9 passed, 0 failed`, exit 0.

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/quality-gates/scripts/check-review-scope.sh plugins/quality-gates/tests/test_check_review_scope.sh
git commit -m "feat(quality-gates): add read-only check-review-scope.sh scope signal (v2.6.0 §5.1)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: SKILL redirect gate — call+cache + `## Empty-scope redirect decision`

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` (allowed-tools; Review gate Step 1b; new decision section)
- Modify (Test): `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`

Covers spec §5.2 and **AC6, AC7 (redirect branches), AC9 (kill switch), AC13 (base reuse)**. TDD: add the static assertions first (they fail), then make the SKILL edits to green them.

- [ ] **Step 1: Add the failing protocol-shape assertions**

In `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`, insert this block immediately BEFORE the final summary block (the line `if [[ "$fail" -eq 0 ]]; then`):

```bash
# --- v2.6.0 AC6/AC7/AC9/AC13: empty-scope redirect gate ---
# check-review-scope.sh invoked in the Review gate (call+cache).
assert_line "check-review-scope.sh invoked" "$(first_line 'check-review-scope.sh')"
# AC6: redirect question carries the unique anchor 'review scope is empty'.
redirect_q=$(first_line 'question:.*[Rr]eview scope is empty')
assert_line "empty-scope redirect question present (anchor 'review scope is empty')" "$redirect_q"
rse_count=$(grep -ciE 'question:.*review scope is empty' "$SKILL_MD" || true)
if [[ "$rse_count" -eq 1 ]]; then
  echo "PASS: 'review scope is empty' anchor unique (1 question: line)"
else
  echo "FAIL: 'review scope is empty' anchor not unique ($rse_count question: lines)"
  fail=$((fail + 1))
fi
assert_line "Empty-scope redirect decision section present" "$(first_line '## Empty-scope redirect decision')"
# AC7: honest-empty branch leaves a positive observable line (not a non-event).
assert_line "honest-empty skip anchor present" "$(first_line 'skipping reviewer dispatch')"
# AC13: redirect-branch reuses the script-emitted base (C6 single base).
assert_line "redirect-branch reuses script-emitted base (AC13)" "$(first_line 'script-emitted base')"
# AC9: scope-redirect kill switch documented in SKILL.
assert_line "scope-redirect kill switch present" "$(first_line 'DEVBREW_QG_DISABLE_SCOPE_REDIRECT')"
```

- [ ] **Step 2: Run the harness to verify the new assertions fail**

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: FAIL — the 6 new assertions fail (`check-review-scope.sh`, `review scope is empty`, the section header, `skipping reviewer dispatch`, `script-emitted base`, `DEVBREW_QG_DISABLE_SCOPE_REDIRECT` all absent from SKILL.md). All pre-existing assertions still PASS.

- [ ] **Step 3a: Add the script to SKILL allowed-tools**

In `SKILL.md`, find this line (in the `allowed-tools:` Group 1 block):

```
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-trivia.sh:*)
```

Insert immediately AFTER it:

```
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-review-scope.sh:*)
```

- [ ] **Step 3b: Add Review gate Step 1b (call+cache + routing)**

In `SKILL.md`, find the start of Review-gate step 2 (currently the only line beginning with `2. Dispatch the scout:`):

```
2. Dispatch the scout: `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/scout.py ...)`.
```

Insert this block immediately BEFORE that `2. Dispatch the scout:` line:

````
**Step 1b — Scope signal & empty-scope redirect (iteration N=1 only).** Before
dispatching the scout, run the read-only scope signal **once** and cache it for
the rest of this turn (C7 — single call; the cached values are consumed again by
the honest-verdict floor at Step 4.5, so the gate and the floor can never diverge):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/check-review-scope.sh" <mode> [globs…]
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
- `normal` / `genuine_noop` / `degraded` → no gate, no advisory; continue silently
  to the scout (happy-path zero-click; `degraded` is fail-open per C5).

Run this signal check ONLY in iteration N=1 — the empty-scope case is resolved
here (branch / honest-empty / stop), so iterations 2–5 always run on a non-empty
scope and never re-trigger it.

````

- [ ] **Step 3c: Add the `## Empty-scope redirect decision` section**

In `SKILL.md`, find this section header:

```
## Review iter boundary decision
```

Insert this entire block immediately BEFORE that `## Review iter boundary decision` header:

````
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

````

- [ ] **Step 4: Run the harness to verify it passes**

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: PASS — all assertions including the 6 new ones; the pre-existing `iter cap near Review gate AskUserQuestion` proximity check still PASSES (the new redirect `AskUserQuestion` lives BEFORE the adversarial dispatch in Step 1b, and its full literal sits AFTER Step 4.5, so the first-`AskUserQuestion`-after-adversarial anchor at the "do NOT call AskUserQuestion" line is unmoved). Final line: `all protocol-shape assertions PASS`.

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
git commit -m "feat(quality-gates): empty-scope redirect gate (call+cache + decision section, v2.6.0 §5.2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: SKILL honest-verdict floor (Step 4.5 both clean sub-cases + Final Summary)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` (Step 4.5; Final Summary)
- Modify (Test): `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`

Covers spec §5.3 and **AC8 (floor, both sub-cases), AC10 (no-regression)**. TDD: assertions first, then SKILL edits.

- [ ] **Step 1: Add the failing floor assertions**

In `test_skill_orchestration_behavior.sh`, insert this block immediately BEFORE the final summary block (`if [[ "$fail" -eq 0 ]]; then`):

```bash
# --- v2.6.0 AC8: honest-verdict floor at Step 4.5 (both clean sub-cases) ---
assert_line "honest floor label present" "$(first_line 'NOT certified clean')"
assert_line "honest floor gated on the cached scope signal" "$(first_line 'scope_signal == empty_scope_with_changes')"
# 'no scope reviewed' must appear in both clean sub-cases + the final-summary
# variant → at least 3 occurrences.
floor_count=$(grep -cE 'no scope reviewed' "$SKILL_MD" || true)
if [[ "$floor_count" -ge 3 ]]; then
  echo "PASS: honest floor label in both clean sub-cases + final summary ($floor_count)"
else
  echo "FAIL: honest floor under-applied (found $floor_count, need >=3)"
  fail=$((fail + 1))
fi
```

- [ ] **Step 2: Run the harness to verify the new assertions fail**

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: FAIL — the 3 new assertions fail (`NOT certified clean`, `scope_signal == empty_scope_with_changes` in a floor context, and `no scope reviewed` count < 3). Pre-existing + Task 2 assertions still PASS.

> Note: `scope_signal == empty_scope_with_changes` already appears once in Step 1b (Task 2), so `assert_line "honest floor gated on the cached scope signal"` may already pass — that is fine; the floor-label and count assertions are the ones that drive this task.

- [ ] **Step 3a: Edit the `kept = 0 AND suppressed = 0` clean branch**

In `SKILL.md`, find this exact block (Step 4.5, third bullet):

```
   - **kept = 0 AND suppressed = 0** (the same empty-state line with N = 0) →
     print `## Review gate iter N: clean` and exit the loop → [Dispatch
     Loop](#dispatch-loop) step 4 (which short-circuits the Runtime gate for the
     review-only path, else runs it).
```

Replace it with:

```
   - **kept = 0 AND suppressed = 0** (the same empty-state line with N = 0) →
     **Honest-verdict floor (AC8):** if the cached `$scope_signal ==
     empty_scope_with_changes`, do NOT print `clean`; print
     `## Review gate iter N: no scope reviewed (0 files; branch <M> ahead of <base>) — NOT certified clean.`
     (substitute `<M>` = `$branch_ahead_count`, `<base>` = `$base`). Otherwise
     (`normal` / `genuine_noop` / `degraded`) print `## Review gate iter N: clean`
     exactly as before (NG4 — genuine no-op and degraded fail-open are unchanged).
     Then exit the loop → [Dispatch Loop](#dispatch-loop) step 4 (which
     short-circuits the Runtime gate for the review-only path, else runs it).
```

- [ ] **Step 3b: Edit the `kept = 0 AND suppressed > 0` clean branch**

In `SKILL.md`, find this exact block (Step 4.5, second bullet):

```
   - **kept = 0 AND suppressed > 0** (the synthesizer emitted the empty-state
     line `No high-confidence findings. N low-confidence findings suppressed.`
     with N > 0 — read N from that line) → no high-confidence finding to act
     on → treat as **clean**: do NOT call AskUserQuestion. Surface only that
     single `No high-confidence findings…` line for transparency, then **exit
     the loop → [Dispatch Loop](#dispatch-loop) step 4** (which skips the Runtime
     gate when gate scope = Review gate only / `effective_skip_runtime`, else runs
     it) — do not iterate again.
```

Replace it with:

```
   - **kept = 0 AND suppressed > 0** (the synthesizer emitted the empty-state
     line `No high-confidence findings. N low-confidence findings suppressed.`
     with N > 0 — read N from that line) → no high-confidence finding to act
     on → treat as **clean**: do NOT call AskUserQuestion. Surface the single
     `No high-confidence findings…` line for transparency. **Honest-verdict floor
     (AC8):** if the cached `$scope_signal == empty_scope_with_changes`, ALSO
     print `## Review gate iter N: no scope reviewed (0 files; branch <M> ahead of <base>) — NOT certified clean.`
     beneath it (the suppressed-count line stays; a zero-scope run must not read
     as "reviewed & clean"). Then **exit the loop → [Dispatch
     Loop](#dispatch-loop) step 4** (which skips the Runtime gate when gate scope
     = Review gate only / `effective_skip_runtime`, else runs it) — do not iterate
     again.
```

> The literal `do NOT call AskUserQuestion` is preserved in place — it is the
> proximity anchor for the existing `iter cap near Review gate AskUserQuestion`
> assertion. Do not remove or relocate it.

- [ ] **Step 3c: Add the honest-empty variant to the Final Summary**

In `SKILL.md`, find this line (in the Final Summary template):

```
- **Review gate**: <clean iter N | proceeded-with-findings iter N | aborted iter N | skipped>
```

Replace it with:

```
- **Review gate**: <clean iter N | no scope reviewed (branch <M> ahead) | proceeded-with-findings iter N | aborted iter N | skipped>
```

- [ ] **Step 4: Run the harness to verify it passes**

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: PASS — all assertions including the 3 new floor assertions (`NOT certified clean` present; `no scope reviewed` count == 3; gated on `scope_signal == empty_scope_with_changes`). Final line: `all protocol-shape assertions PASS`.

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
git commit -m "feat(quality-gates): honest-verdict floor at Step 4.5 (both clean sub-cases, v2.6.0 §5.3)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: SKILL Runtime transparency line (R2 → R3)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` (between Step R2 and Step R3)
- Modify (Test): `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`

Covers spec §5.4 and **AC11 (single + position), AC12 (Runtime unchanged)**. TDD: assertions first, then SKILL edit.

- [ ] **Step 1: Add the failing runtime-line assertions**

In `test_skill_orchestration_behavior.sh`, insert this block immediately BEFORE the final summary block (`if [[ "$fail" -eq 0 ]]; then`):

```bash
# --- v2.6.0 AC11: Runtime scope transparency line, single + between R2 and R3 ---
r2_marker=$(first_line 'Step R2')
r3_marker=$(first_line 'Step R3')
rtscope_line=$(first_line 'regardless of Review scope')
assert_line "Runtime scope asymmetry marker present" "$rtscope_line"
assert_line "Runtime scope observable anchor present" "$(first_line 'Runtime scope: full project')"
if [[ "$rtscope_line" -gt "$r2_marker" && "$rtscope_line" -lt "$r3_marker" ]]; then
  echo "PASS: Runtime scope line between Step R2 ($r2_marker) and Step R3 ($r3_marker) at $rtscope_line"
else
  echo "FAIL: Runtime scope line not between R2/R3 (r2=$r2_marker line=$rtscope_line r3=$r3_marker)"
  fail=$((fail + 1))
fi
rtscope_count=$(grep -cE 'regardless of Review scope' "$SKILL_MD" || true)
if [[ "$rtscope_count" -eq 1 ]]; then
  echo "PASS: Runtime scope asymmetry marker unique (1)"
else
  echo "FAIL: Runtime scope asymmetry marker not unique ($rtscope_count)"
  fail=$((fail + 1))
fi
```

- [ ] **Step 2: Run the harness to verify the new assertions fail**

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: FAIL — `regardless of Review scope` and `Runtime scope: full project` absent; the proximity and uniqueness checks fail. Pre-existing + Task 2/3 assertions still PASS.

- [ ] **Step 3: Add the Runtime transparency line between R2 and R3**

In `SKILL.md`, find the start of Step R3 (currently the only line beginning with `**Step R3 — dispatch runtime-verifier`):

```
**Step R3 — dispatch runtime-verifier (executor)** with `project_dir = runtime_project_dir`, the spec AC, the approved surfaces, and the block policy:
```

Insert this block immediately BEFORE that `**Step R3 …` line:

````
**Runtime scope transparency (additive — AC11).** Emit exactly one user-visible
line here (Step R2 complete → before the Step R3 dispatch), now that the
manifest, approved surfaces, and spec AC are all known:

> `> Runtime scope: full project (<project_type>) — boots <surface summary>, asserts <K> spec AC. Runtime runs the whole app regardless of Review scope.`

Substitute `<project_type>` and `<surface summary>` from the `detect-runtime.sh`
manifest (`project_type` + a short `runnable_surfaces` / `test_runners` digest);
`<K>` = the number of `spec_acceptance_criteria` gathered in Step R2 (`0 spec AC (smoke fallback)`
when none). The clause `regardless of Review scope` is the OQ4 asymmetry marker
(literal). This is the ONLY emission point — every path that reaches the Runtime
gate (both-gates and single `/qg runtime`) flows through R3, so one line covers
them all; the Review-gate-only path never reaches here (correct — there is no
Runtime to describe). This is purely additive: no new gate, no diff-scope forcing,
no behavior change (NG3 / AC12).

````

- [ ] **Step 4: Run the harness to verify it passes**

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: PASS — the runtime-line assertions pass (`regardless of Review scope` unique and positioned between `Step R2` and `Step R3`; `Runtime scope: full project` present). Pre-existing `R-init precedes runtime-verifier dispatch` still PASSES (the inserted lines shift the R3 dispatch down but preserve ordering). Final line: `all protocol-shape assertions PASS`.

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
git commit -m "feat(quality-gates): additive Runtime scope transparency line (R2->R3, v2.6.0 §5.4)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Version bump + docs (plugin.json, CHANGELOG, README, qg.md, philosophy, harness assertion)

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` (title + Final Summary version strings)
- Modify (Test): `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` (version assertion)
- Modify: `plugins/quality-gates/CHANGELOG.md`
- Modify: `plugins/quality-gates/README.md`
- Modify: `plugins/quality-gates/commands/qg.md`
- Modify: `docs/philosophy/devbrew-harness-philosophy.md`

Covers **AC14** (version/changelog/readme/qg.md + P8 absorption) and locks in the harness version assertion.

- [ ] **Step 1: Bump the SKILL version strings + harness assertion (test-first ordering)**

First update the harness assertion in `test_skill_orchestration_behavior.sh`. Find:

```bash
# Version bumped to 2.5.0 (title + final summary).
assert_line "v2.5.0 in SKILL" "$(first_line 'v2.5.0|2\.5\.0')"
```

Replace with:

```bash
# Version bumped to 2.6.0 (title + final summary).
assert_line "v2.6.0 in SKILL" "$(first_line 'v2.6.0|2\.6\.0')"
```

- [ ] **Step 2: Run the harness — expect the version assertion to fail**

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: FAIL — `v2.6.0 in SKILL` fails (SKILL still says v2.5.0). Everything else PASS.

- [ ] **Step 3: Bump SKILL title + Final Summary**

In `SKILL.md`, find:

```
# Quality Gates — In-Turn Orchestrator (v2.5.0)
```

Replace with:

```
# Quality Gates — In-Turn Orchestrator (v2.6.0)
```

Then find:

```
## Quality Gates Pipeline — Complete (v2.5.0)
```

Replace with:

```
## Quality Gates Pipeline — Complete (v2.6.0)
```

- [ ] **Step 4: Re-run the harness — expect all PASS**

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: PASS — `v2.6.0 in SKILL` now passes. Final line: `all protocol-shape assertions PASS`.

- [ ] **Step 5: Bump plugin.json**

In `plugins/quality-gates/.claude-plugin/plugin.json`, find:

```
  "version": "2.5.0",
```

Replace with:

```
  "version": "2.6.0",
```

- [ ] **Step 6: Add the CHANGELOG entry**

In `plugins/quality-gates/CHANGELOG.md`, find the line `## [2.5.0] — 2026-06-07` and insert this block immediately BEFORE it (so [2.6.0] is the new top entry):

```markdown
## [2.6.0] — 2026-06-07

Review gate가 *검토받았다고 믿는 scope*와 *실제 resolve한 scope*가 silent하게 발산할 때
("커밋 후 빈 세션 → resolved scope 0 → clean"의 false-clean)를 봉쇄. 새 read-only 신호
`check-review-scope.sh`가 단일 `signal`을 emit하면 SKILL이 Review iter-1에서 1회 호출·캐시해
(A) redirect 게이트(P17, kill 가능)와 (B) 정직-verdict floor(P8, kill 불가)로 소비. Runtime은
R2 직후 비대칭 명시 한 줄만 additive. session 기본값·genuine no-op clean·`/qg branch`는 무변경.
devbrew P8 determinism-economy instantiation(결정론은 정확성 floor 한 점에만; redirect/routing은
모델 신뢰).

### Added
- **`scripts/check-review-scope.sh` (신규, read-only)**: scope mode(session/branch/paths)별
  `resolved_count` / `branch_ahead_count` / `worktree_dirty` / `base` / `signal`을 emit.
  signal ∈ {`empty_scope_with_changes`, `normal`, `genuine_noop`, `degraded`}. 단일 base
  진실원(origin/HEAD → origin/main → origin/master → local main → master); 불확실 환경은
  `degraded` + exit 0 fail-open. `tests/test_check_review_scope.sh` (AC1–AC5).
- **Empty-scope redirect 게이트 (SKILL Step 1b + `## Empty-scope redirect decision`)**:
  `signal == empty_scope_with_changes` AND kill switch 미설정일 때만 1회 발화(앵커
  `review scope is empty`, 고유). 3옵션(branch diff / honest-empty / stop) 각각 관측 가능한
  출력 라인. kill switch `DEVBREW_QG_DISABLE_SCOPE_REDIRECT=1`.
- **정직-verdict floor (SKILL Step 4.5, 결정론)**: `signal == empty_scope_with_changes`이면
  clean으로 귀결되는 두 sub-case(`suppressed=0`·`suppressed>0`) 모두에서 verdict 라벨을
  `no scope reviewed … NOT certified clean`으로 교체. redirect 게이트와 같은 캐시 신호를 소비해
  발산 불가; 게이트 우회·kill switch에도 불변(load-bearing).
- **Runtime scope transparency 라인 (SKILL Step R2→R3, additive)**: `> Runtime scope: full project …
  regardless of Review scope`. 새 게이트·diff-scope 강제·동작 변경 없음.

### Changed
- **버전 2.5.0 → 2.6.0** (minor, 새 surface): `plugin.json`, SKILL 제목 + Final Summary,
  `test_skill_orchestration_behavior.sh` 버전 assertion(`v2.5.0`→`v2.6.0`) 동기화.
- **Empty-scope verdict 라벨**: resolved scope=0 + 변경 존재 시 더 이상 단독 `clean`이 아님.
  genuine no-op(변경 없음)·`normal`·`degraded` 경로의 `clean`/transparency 문구는 무변경.
- **README `인스턴스화한 원칙`**: P8 self-honest verdict floor bullet 추가.
- **`docs/philosophy/devbrew-harness-philosophy.md`**: P8 determinism-economy에 self-honest
  verdict floor 흡수(새 P# 없음).
```

- [ ] **Step 7: Add the README Principles bullet**

In `plugins/quality-gates/README.md`, find the v2.5.0 P8 bullet (the line beginning `- **P8 determinism-economy (harness lightness — trust the model)** (v2.5.0)`). Insert this new bullet immediately AFTER that bullet's line:

```markdown
- **P8 determinism-economy — self-honest verdict floor** (v2.6.0) — Review gate가 *검토받았다고 믿는 scope*와 *resolve한 scope*가 발산할 때(빈 세션 → resolved scope 0 → "clean"의 false-clean)를 봉쇄. read-only `scripts/check-review-scope.sh`가 단일 신호를 emit하면 SKILL이 iter-1에서 1회 호출·캐시해 **정직-verdict floor**(결정론·load-bearing, kill 불가 — `signal==empty_scope_with_changes`면 "no scope reviewed … NOT certified clean")와 **redirect 게이트**(P17, `DEVBREW_QG_DISABLE_SCOPE_REDIRECT=1`로 kill 가능)로 소비. 결정론은 정확성 floor 한 점에만; redirect/자연어 routing은 모델 신뢰. genuine no-op·session 기본값·`/qg branch`는 무변경. Runtime은 비대칭 명시 한 줄만 additive. regression: `tests/test_check_review_scope.sh`.
```

- [ ] **Step 8: Update commands/qg.md**

In `plugins/quality-gates/commands/qg.md`, find this row in the env-var section of the Quick Reference table:

```
| `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1` | Disable the Runtime gate sandbox executor (read-only smoke fallback; verdict capped at SKIP_WITH_EVIDENCE) |
```

Insert immediately AFTER it:

```
| `DEVBREW_QG_DISABLE_SCOPE_REDIRECT=1` | Disable the empty-scope redirect question (advisory only); the honest-verdict floor still applies |
```

Then, in the `### Scope (default: session)` section, find this line:

```
Override with `/qg branch` (full branch) or `/qg --paths <glob>...` (manual).
```

Insert this paragraph immediately AFTER it:

```
빈 세션에서 커밋된 변경이 있어 resolved scope가 0인데 브랜치는 base보다 앞서 있으면 (false-clean),
qg는 "clean"이라 하지 않는다 — `check-review-scope.sh`가 `empty_scope_with_changes`를 결정론으로
탐지해 **정직-verdict floor**(verdict를 `no scope reviewed … NOT certified clean`으로 교체;
kill 불가)와 1클릭 **redirect 게이트**(branch diff 리뷰 제안; `DEVBREW_QG_DISABLE_SCOPE_REDIRECT=1`로
끌 수 있음)를 띄운다. 진짜 변경 없음(genuine no-op)은 그대로 `clean`.
```

- [ ] **Step 9: Absorb the floor into philosophy P8 (no new P#)**

In `docs/philosophy/devbrew-harness-philosophy.md`, find the end of the determinism-economy paragraph (the sentence ending `…전부 폐기하고 모델 라우팅 신뢰로 결정.)`). Append this sentence to the SAME paragraph (right after that closing `)`):

```
 같은 economy의 대칭 적용: 결정론을 *덜어내는* 것뿐 아니라 *load-bearing인 한 점에 정확히 거는* 것도 P8이다 — qg v2.6.0의 self-honest verdict floor는 "검토 안 한 scope를 clean이라 부르지 않기"라는 정확성 보장 한 점에만 결정론을 걸고(kill 불가), 그 위의 redirect 제안·scope routing은 모델 신뢰(kill 가능)로 둔다.
```

Then find the absorption-log line (`**P8 determinism-economy refinement added 2026-06-07** …`) and append this clause to the end of that line:

```
 v2.6.0에서 self-honest verdict floor(정확성 한 점 결정론 + redirect/ routing 모델 신뢰)가 같은 단락의 대칭 사례로 흡수됨 — 새 P# 없음.
```

- [ ] **Step 10: Run the full quality-gates test suite (scoped to this work)**

Run the new + changed-touching tests and confirm green:

```bash
cd /Users/jeonghokim/Downloads/devbrew
bash plugins/quality-gates/tests/test_check_review_scope.sh
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
```

Expected: both exit 0 (`9 passed, 0 failed` and `all protocol-shape assertions PASS`).

- [ ] **Step 11: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/quality-gates/.claude-plugin/plugin.json \
        plugins/quality-gates/skills/quality-pipeline/SKILL.md \
        plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh \
        plugins/quality-gates/CHANGELOG.md \
        plugins/quality-gates/README.md \
        plugins/quality-gates/commands/qg.md \
        docs/philosophy/devbrew-harness-philosophy.md
git commit -m "chore(quality-gates): v2.6.0 bump + CHANGELOG/README/qg.md/philosophy (P8 floor absorb)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Full verification sweep (no new code)

**Files:** none modified — verification + evidence only.

- [ ] **Step 1: Confirm no NEW test regressions vs baseline**

Run the same sweep as Task 1 Step 0 and diff against the saved baseline:

```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in plugins/quality-gates/tests/*.sh plugins/quality-gates/tests/harness/*.sh; do
  printf '%s: ' "$t"; bash "$t" >/dev/null 2>&1 && echo OK || echo RED
done | tee "$CLAUDE_JOB_DIR/tmp/qg-baseline-after.txt"
diff "$CLAUDE_JOB_DIR/tmp/qg-baseline-before.txt" "$CLAUDE_JOB_DIR/tmp/qg-baseline-after.txt" || true
```

Expected: the only difference is `test_check_review_scope.sh` flipping from absent → `OK`. The pre-existing ~8 stale reds are unchanged; no previously-`OK` test became `RED`.

- [ ] **Step 2: Confirm Law 2 — no persona files touched (C1)**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git diff --name-only cb7dcbb..HEAD -- 'plugins/quality-gates/agents/*.md'
```

Expected: empty output (no `agents/*.md` in the diff). If anything prints, a Law-2 violation slipped in — revert it.

- [ ] **Step 3: Confirm the full set of changed files matches §7**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git diff --name-only cb7dcbb..HEAD
```

Expected exactly these 9 paths (plus this plan doc + the design/interview docs already committed earlier on the branch):
- `plugins/quality-gates/scripts/check-review-scope.sh`
- `plugins/quality-gates/tests/test_check_review_scope.sh`
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md`
- `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
- `plugins/quality-gates/commands/qg.md`
- `plugins/quality-gates/.claude-plugin/plugin.json`
- `plugins/quality-gates/CHANGELOG.md`
- `plugins/quality-gates/README.md`
- `docs/philosophy/devbrew-harness-philosophy.md`

- [ ] **Step 4: Manual e2e checklist (record results; not auto-scripted — memory V10 pattern)**

These exercise the live `/qg` flow with the observable anchors. Run in a scratch clone/branch or note them for the reviewer:

1. Edit → commit → **new session** → `/qg`: redirect gate fires with `review scope is empty` (AC6). Each of the 3 options:
   - "Review branch diff" → `> Review scope: branch (<M> files vs <base>)` then a normal review (AC7).
   - "Proceed honest-empty" → `> Review gate: skipping reviewer dispatch — 0 files reviewed (honest-empty path).` + verdict `… NOT certified clean.` (AC7/AC8).
   - "Stop" → final summary `aborted at Review gate (empty scope, branch <M> ahead)` (AC7).
2. `DEVBREW_QG_DISABLE_SCOPE_REDIRECT=1` `/qg`: no gate, advisory line, verdict still `NOT certified clean` (AC9).
3. Genuine no-op (clean tree, branch == base) `/qg`: silent, verdict `clean` unchanged (AC10).
4. A web project reaching the Runtime gate: `> Runtime scope: full project … regardless of Review scope` printed once just before the verifier dispatch, with the spec AC count (AC11).

- [ ] **Step 5: Report completion**

Summarize: all unit + orchestration tests green, no new regressions vs baseline, no persona edits, 9 files changed per §7, manual e2e results. The branch `feature/qg-scope-capture` is ready for `/qg` self-review and PR.

---

## Self-Review (plan author)

**1. Spec coverage (AC1–AC14):**
- AC1 (empty_scope_with_changes, all modes) → Task 1 cases `case_session_empty_branch_ahead`, `case_paths_no_match`; branch mode covered by script logic (`resolved_count=branch_ahead_count`) and exercised indirectly.
- AC2 (genuine_noop) → `case_genuine_noop`.
- AC3 (normal, incl. paths glob∩diff) → `case_session_files_present`, `case_paths_changed`.
- AC4 (degraded + exit 0) → `case_degraded_detached`, `case_degraded_no_base`.
- AC5 (read-only) → `case_read_only`.
- AC6 (redirect anchor unique) → Task 2 harness `rse_count == 1`.
- AC7 (3-option positive anchors) → Task 2 `## Empty-scope redirect decision` branches + `skipping reviewer dispatch` assertion; Task 6 manual e2e.
- AC8 (floor both sub-cases) → Task 3 Step 3a/3b + `NOT certified clean` / `no scope reviewed >= 3`.
- AC9 (kill switch) → Task 2 Step 3b kill-switch branch + `DEVBREW_QG_DISABLE_SCOPE_REDIRECT` assertion.
- AC10 (no-regression) → Task 3 "Otherwise … clean as before"; Task 6 baseline diff + manual case 3.
- AC11 (runtime line single + position) → Task 4 proximity + uniqueness assertions.
- AC12 (Runtime unchanged) → Task 4 "purely additive" wording; no behavior edit.
- AC13 (base reuse, C6) → Task 2 `script-emitted base` assertion + redirect-branch text.
- AC14 (version/changelog/readme/qg.md/P8) → Task 5 Steps 1–9.

**2. Placeholder scan:** No "TBD"/"handle errors"/"similar to". Every script, test, SKILL edit, and doc edit shows the literal content. Runtime line `<project_type>`/`<surface summary>`/`<K>`/`<M>`/`<base>` are intentional runtime substitution slots (prompt-as-spec), not plan placeholders — each has an explicit substitution rule.

**3. Type/identifier consistency:** signal values (`empty_scope_with_changes` / `normal` / `genuine_noop` / `degraded`), output keys (`resolved_count` / `branch_ahead_count` / `worktree_dirty` / `base` / `signal`), cached SKILL vars (`$scope_signal` / `$branch_ahead_count` / `$base`), and anchors (`review scope is empty`, `skipping reviewer dispatch`, `script-emitted base`, `no scope reviewed`, `NOT certified clean`, `regardless of Review scope`, `Runtime scope: full project`) are used identically across the script, the SKILL edits, and the harness assertions. The kill switch is spelled `DEVBREW_QG_DISABLE_SCOPE_REDIRECT` everywhere. Version `2.6.0` is bumped in plugin.json, SKILL title, SKILL Final Summary, and the harness assertion together (Task 5).
