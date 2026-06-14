# qg Scope Detector Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Strip the v2.6.0 false-clean detector's *routing reconstruction* (git modes/paths/union/`signal`/`$effective_diff_scope`/redirect gate) while keeping its *verdict-integrity floor* as a single deterministic signal, shipping quality-gates v2.7.0.

**Architecture:** The v2.6.0 detector tangled two jobs in 120 lines: deciding *what to review* (routing — the source of all 5 dogfood bugs) and blocking *"clean" over 0 reviewed files when changes exist* (verdict integrity — load-bearing). This plan separates them. `check-review-scope.sh` shrinks to ~40 lines that emit only `changes_exist`; routing is delegated to the model plus the existing `/qg branch` escape hatch and a one-line honesty norm; the Step 4.5 floor keys on the product of two deterministic signals — `resolved_scope_file_count == 0 AND changes_exist == yes`. The empty-scope redirect gate, `$effective_diff_scope` wiring, and `DEVBREW_QG_DISABLE_SCOPE_REDIRECT` kill switch are removed.

**Tech Stack:** Bash (POSIX-ish, macOS `/bin/bash` 3.2-compatible; `set -u` not `-e` for graceful degradation), markdown SKILL prompt, JSON plugin manifest. Tests are standalone bash scripts run from the repo root (no enumerating runner). No CI — baseline is captured manually.

**Spec:** `docs/superpowers/specs/2026-06-13-qg-scope-detector-simplification-design.md` (review-approved; decisions locked: **B** minimal floor / structural redirect **removed** / **tiny script**, no raw git in allowed-tools, script kept-not-renamed).

---

## Pre-flight context the engineer must know

These are non-obvious facts. Read them before Task 1.

1. **`SKILL.md` `allowed-tools` is script-only Bash.** The orchestrator may run only the listed scripts (`check-review-scope.sh`, `scout.py`, …) plus `Agent`/`AskUserQuestion`/`Read`/`Glob`/`Grep`/`Edit`/`Write`. It **cannot** run raw `git` or raw `grep` via Bash. Therefore the floor's `resolved_scope_file_count` is *reused from the step-1 scope already resolved* (the v2.5.0 transparency count for session, `$branch_ahead_count` for branch, the `--paths` glob match count for paths) — **not** a fresh measurement. Do **not** add a raw `git` grant (spec N3). This is why the floor lives in SKILL prose and the *script* only supplies the independent `changes_exist` signal.
2. **`check-review-scope.sh` is shrunk, NOT deleted or renamed.** Its `allowed-tools` entry and the `scripts/check-allowed-tools-order.sh:17` `EXPECTED_ORDER` entry stay **unchanged** (spec AC11, Handoff Context). The tool count stays 18.
3. **`CHANGELOG.md` is append-only.** Preserve `## [2.6.0]`; prepend `## [2.7.0]`. The removal-grep ACs (AC8/9/10) check the *active* docs (SKILL/qg.md/README), **never** the CHANGELOG (which legitimately retains the removed terms in history).
4. **Tests run from the repo root**, e.g. `bash plugins/quality-gates/tests/test_check_review_scope.sh`. The repo has ~8 pre-existing environment-dependent stale-red tests unrelated to this work (`project_qg_pre_existing_test_reds`); the goal is "exactly those 8, zero new reds" (AC15).
5. **Every test fixture is fail-closed.** A fixture must `mktemp -d || exit 1; cd "$REPO" || exit 1` **before any git command**, so git never runs in the caller's live repo. The v2.6.0 dogfood found a `set -u`-only fixture that risked `git branch -D main` on the live repo (`project_qg_scope_capture`). This is a hard requirement.
6. **The AC13 e2e goes in a dedicated file** `tests/test_qg_false_clean_floor.sh`, not jammed into `tests/harness/test_skill_orchestration_behavior.sh`. Rationale: the harness is a `set -euo pipefail` *static* protocol-shape grep verifier; injecting live-git fixtures into a `set -e` script is exactly the safety hazard fact #5 warns about. The harness is still modified (static prose anchors + negative guards), satisfying its Files-to-Modify row; the *executable* floor e2e gets a safe `set -u` home. This is a deliberate, spec-intent-preserving split (spec defers TDD-sequencing/fixture details to the plan; AC5 is explicitly a two-layer static-anchor + e2e design).
7. **TDD ordering.** The script change (Task 3) is driven red-first by the e2e written in the same task; the SKILL change (Task 4) is driven red-first by the harness anchor rewrite in the same task. No task leaves another task's test red.

## File map

| File | Responsibility after this change |
|---|---|
| `plugins/quality-gates/scripts/check-review-scope.sh` | ~40-line read-only signal: emits `changes_exist` / `branch_ahead_count` / `worktree_dirty` / `base` / `degraded`. No mode/paths/signal/resolved_count/merge_base. |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | Step 1b = call-once-cache (no routing); honesty norm; Step 4.5 floor on `resolved_scope_file_count == 0 AND changes_exist == yes`; redirect section + `$effective_diff_scope` deleted; v2.7.0 headers. |
| `plugins/quality-gates/tests/test_check_review_scope.sh` | New contract unit tests (changes_exist / F2 / NG4 / degraded). mode/paths/signal/merge_base cases removed. |
| `plugins/quality-gates/tests/test_qg_false_clean_floor.sh` | **NEW.** Fail-closed e2e: false-clean blocked + happy-path clean + genuine no-op clean + degraded fail-open. |
| `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` | Static anchors rewritten: floor-on-`changes_exist`, honesty norm present, negative guards for removed surface; version `v2.7.0`. |
| `plugins/quality-gates/commands/qg.md` | Remove `DEVBREW_QG_DISABLE_SCOPE_REDIRECT` row; rewrite false-clean scope prose. |
| `plugins/quality-gates/.claude-plugin/plugin.json` | `2.6.0` → `2.7.0`. |
| `plugins/quality-gates/CHANGELOG.md` | Prepend `## [2.7.0] — 2026-06-13` (Removed/Changed); `[2.6.0]` preserved. |
| `plugins/quality-gates/README.md` | Rewrite the P8 self-honest-floor bullet for v2.7.0. |
| `plugins/quality-gates/scripts/check-allowed-tools-order.sh` | **UNCHANGED** — verify it still passes (script kept). |

---

## Task 1: Baseline capture (no commit)

Establishes the AC15 reference and confirms the starting branch. Produces no code change.

**Files:** none (read-only).

- [ ] **Step 1: Confirm the working branch**

Run: `cd /Users/jeonghokim/Downloads/devbrew && git branch --show-current && git log --oneline -1`
Expected: branch `feature/qg-detector-simplification`; HEAD is the committed design doc (`6dc56e0` or later). If on a different branch, `git checkout feature/qg-detector-simplification` (the spec doc must be present).

- [ ] **Step 2: Confirm the design spec is present**

Run: `test -f docs/superpowers/specs/2026-06-13-qg-scope-detector-simplification-design.md && echo PRESENT`
Expected: `PRESENT`.

- [ ] **Step 3: Capture the affected-test + linter baseline (all currently green)**

Run each from the repo root and record pass/fail:
```bash
bash plugins/quality-gates/tests/test_check_review_scope.sh            | tail -1
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh | tail -1
bash plugins/quality-gates/scripts/check-allowed-tools-order.sh        | tail -1
bash plugins/quality-gates/tests/test_check_allowed_tools_order.sh     | tail -1
```
Expected:
- `test_check_review_scope: 11 passed, 0 failed`
- `test_skill_orchestration_behavior: all protocol-shape assertions PASS`
- `check-allowed-tools-order: OK (18 tools in canonical order)`
- `All tests pass.`

- [ ] **Step 4: Record the repo-wide stale-red baseline (AC15 reference)**

This is the set of pre-existing environment-dependent failures unrelated to this work. Run the bash test suite for the plugin and note the failing files (codex/consent/security/sandbox class, ~8). You do **not** fix these. Save the list for the Task 8 comparison.
```bash
for t in plugins/quality-gates/tests/test_*.sh; do
  out=$(bash "$t" 2>&1 | tail -1)
  case "$out" in *FAIL*|*failed*) [[ "$out" == *"0 failed"* ]] || echo "RED: $t — $out";; esac
done
```
Expected: a stable list of ~8 reds (record it). None of them are `test_check_review_scope.sh`, `test_check_allowed_tools_order.sh`, or the harness.

---

## Task 2: Write the false-clean e2e test (RED — drives the script shrink)

The e2e is the headline behavioral contract: *the floor blocks false-clean end-to-end*. It runs the **real** `check-review-scope.sh` in fail-closed throwaway repos and applies the same floor decision the SKILL Step 4.5 prose specifies. It is RED now because the current script emits `signal:`/`resolved_count:`, not `changes_exist:`.

**Files:**
- Create: `plugins/quality-gates/tests/test_qg_false_clean_floor.sh`

- [ ] **Step 1: Create the e2e test file**

Write `plugins/quality-gates/tests/test_qg_false_clean_floor.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# test_qg_false_clean_floor.sh — AC13 e2e: the verdict-integrity floor blocks
# false-clean (resolved scope 0 + changes exist) end-to-end (design v2.7.0 §5.3).
# Drives the REAL (shrunk) check-review-scope.sh in isolated throwaway repos and
# applies the SAME floor decision the SKILL Step 4.5 prose specifies. The static
# prose-anchor guaranteeing the SKILL text matches this decision lives in
# tests/harness/test_skill_orchestration_behavior.sh (two-layer AC5).
#
# FAIL-CLOSED: every fixture cds into a fresh mktemp repo BEFORE any git command;
# a failed mktemp/cd aborts immediately so git never runs in the caller's repo
# (v2.6.0 dogfood lesson: a set -u-only fixture risked `git branch -D main` on the
# live repo — project_qg_scope_capture).

set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/check-review-scope.sh"

PASS=0; FAIL=0; REPO=""
pass() { PASS=$((PASS + 1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }

# field <key> <output-text> → prints the value after "<key>: "
field() { printf '%s\n' "$2" | awk -v k="$1:" '$1 == k { print $2 }'; }

# floor_verdict <resolved_count> <changes_exist> <degraded> → not_clean | clean | clean_degraded
# Mirror of SKILL Step 4.5 §5.3. The static anchor in the harness asserts the SKILL
# prose matches this exact condition+label (two-layer AC5; this side is executable).
floor_verdict() {
  local resolved="$1" changes="$2" degraded="$3"
  if [[ "$resolved" -eq 0 && "$changes" == "yes" ]]; then
    echo "not_clean"
  elif [[ "$degraded" == "yes" && "$resolved" -eq 0 ]]; then
    echo "clean_degraded"
  else
    echo "clean"
  fi
}

# resolved_scope_file_count for SESSION mode (mirror of SKILL §5.3 session derivation:
# files.md "- <path>" items). The script no longer reads files.md — scope is model-owned —
# so this derivation lives with the consumer (here, the test).
session_resolved_count() {
  local md=".claude/quality-gates/$1/files.md" c=0
  [[ -f "$md" ]] && c=$(grep -c '^- ' "$md" 2>/dev/null || true)
  echo "${c:-0}"
}

# Build a repo with a 'main' base + a 'feature' branch 1 commit ahead.
# Sets global REPO and leaves CWD inside it (on feature, clean tree).
mk_repo_feature_ahead() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1   # fail-closed: never run git in caller's repo
  git init -q
  git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo base > a.txt; git add a.txt; git commit -qm base
  git checkout -q -b feature
  echo work >> a.txt; git commit -qam work
}

# AC13 core: empty session scope (0 files) + branch ahead → floor returns not_clean.
case_false_clean_blocked() {
  mk_repo_feature_ahead
  export CLAUDE_CODE_SESSION_ID="fc-empty-$$"
  local out resolved verdict
  out=$(bash "$SCRIPT")
  resolved=$(session_resolved_count "$CLAUDE_CODE_SESSION_ID")   # no files.md → 0
  verdict=$(floor_verdict "$resolved" "$(field changes_exist "$out")" "$(field degraded "$out")")
  if [[ "$verdict" == "not_clean" \
     && "$(field changes_exist "$out")" == "yes" \
     && "$(field branch_ahead_count "$out")" == "1" ]]; then
    pass "false-clean (0 files + branch ahead) → NOT certified clean"
  else
    fail "false-clean not blocked (resolved=$resolved verdict=$verdict out=$out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

# AC7 happy-path: resolved scope >0 → floor returns clean (no false-positive block).
case_scope_present_clean() {
  mk_repo_feature_ahead
  export CLAUDE_CODE_SESSION_ID="fc-files-$$"
  mkdir -p ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID"
  printf '# files\n\n- a.txt\n' > ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID/files.md"
  local out resolved verdict
  out=$(bash "$SCRIPT")
  resolved=$(session_resolved_count "$CLAUDE_CODE_SESSION_ID")   # 1
  verdict=$(floor_verdict "$resolved" "$(field changes_exist "$out")" "$(field degraded "$out")")
  if [[ "$verdict" == "clean" && "$resolved" -eq 1 ]]; then
    pass "resolved scope >0 → clean (happy-path, no floor over-fire)"
  else
    fail "scope-present clean (resolved=$resolved verdict=$verdict out=$out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

# C4 genuine no-op: on base, clean tree → changes_exist=no → floor clean.
case_genuine_noop_clean() {
  mk_repo_feature_ahead
  git checkout -q main
  export CLAUDE_CODE_SESSION_ID="fc-noop-$$"
  local out resolved verdict
  out=$(bash "$SCRIPT")
  resolved=$(session_resolved_count "$CLAUDE_CODE_SESSION_ID")   # 0
  verdict=$(floor_verdict "$resolved" "$(field changes_exist "$out")" "$(field degraded "$out")")
  if [[ "$verdict" == "clean" && "$(field changes_exist "$out")" == "no" ]]; then
    pass "genuine no-op (no changes) → clean (floor not over-fired)"
  else
    fail "genuine no-op clean (verdict=$verdict out=$out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

# AC6 degraded: no base branch → degraded → floor fail-open (clean_degraded).
case_degraded_fail_open() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1   # fail-closed
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b weirdname
  echo x > a.txt; git add a.txt; git commit -qm x
  export CLAUDE_CODE_SESSION_ID="fc-degraded-$$"
  local out resolved verdict
  out=$(bash "$SCRIPT")
  resolved=$(session_resolved_count "$CLAUDE_CODE_SESSION_ID")   # 0
  verdict=$(floor_verdict "$resolved" "$(field changes_exist "$out")" "$(field degraded "$out")")
  if [[ "$verdict" == "clean_degraded" && "$(field degraded "$out")" == "yes" ]]; then
    pass "no base branch → degraded → floor fail-open (clean + advisory)"
  else
    fail "degraded fail-open (verdict=$verdict out=$out)"
  fi
  cd / && rm -rf "$REPO"; unset CLAUDE_CODE_SESSION_ID
}

case_false_clean_blocked
case_scope_present_clean
case_genuine_noop_clean
case_degraded_fail_open

echo
echo "test_qg_false_clean_floor: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x plugins/quality-gates/tests/test_qg_false_clean_floor.sh`

- [ ] **Step 3: Run it — verify it FAILS (RED)**

Run: `bash plugins/quality-gates/tests/test_qg_false_clean_floor.sh; echo "exit=$?"`
Expected: `test_qg_false_clean_floor: ... failed` with at least `case_false_clean_blocked` and `case_genuine_noop_clean` failing (the current script emits `signal:`/`resolved_count:`, so `field changes_exist` is empty → assertions fail), `exit=1`. **This RED is the point** — the new `changes_exist` contract does not exist yet.

(No commit — RED test is committed together with the script in Task 3.)

---

## Task 3: Shrink `check-review-scope.sh` to the changes-exist signal (GREEN)

Make the minimal script that satisfies the e2e, then re-write its unit test to the new contract. Both end green; the linter stays green (script kept, count 18).

**Files:**
- Modify (rewrite): `plugins/quality-gates/scripts/check-review-scope.sh`
- Modify (rewrite): `plugins/quality-gates/tests/test_check_review_scope.sh`
- Test: `plugins/quality-gates/tests/test_qg_false_clean_floor.sh` (from Task 2)

- [ ] **Step 1: Replace `check-review-scope.sh` with the shrunk signal**

Overwrite the entire file with exactly this content (~40 lines of logic; F2/NG4/degraded preserved, routing removed):

```bash
#!/usr/bin/env bash
# check-review-scope.sh — read-only deterministic CHANGES-EXIST signal for the
# Review gate's verdict-integrity floor (design v2.7.0 §5.2). Narrowed from v2.6.0:
# the single responsibility shrank from "is the resolved review scope empty while
# changes exist?" to "does this branch/worktree have changes?". Scope resolution
# (WHAT to review) is the MODEL's responsibility now; this script supplies only the
# load-bearing signal the SKILL Step 4.5 honest-verdict floor keys on, independent
# of any "clean" claim.
#
# Output (structured stdout, consumed by SKILL.md Step 1b → 4.5):
#   changes_exist: yes|no      # branch_ahead_count > 0 OR worktree_dirty == yes
#   branch_ahead_count: <M>    # CHANGED-FILE count on merge_base..HEAD (NOT commit count)
#   worktree_dirty: yes|no     # tracked diff OR non-ignored untracked
#   base: <name|->             # display name for the honest verdict message
#   degraded: yes|no           # fail-open marker (C2): cannot determine → floor not protected
#
# Exit code: always 0 (degraded: yes carries the fail-open state). Read-only:
# never creates/modifies/deletes files. Takes NO arguments. Invoke from project root.

set -u   # NOT -e: graceful degradation, like detect-runtime.sh.

emit_degraded() {
  echo "changes_exist: no"
  echo "branch_ahead_count: 0"
  echo "worktree_dirty: no"
  echo "base: -"
  echo "degraded: yes"
  exit 0
}

# --- git sanity (fail-open on anything uncertain — C2) ---
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || emit_degraded
git rev-parse --verify --quiet HEAD >/dev/null 2>&1 || emit_degraded
# detached HEAD → no branch context to compare → degraded.
git symbolic-ref --quiet HEAD >/dev/null 2>&1 || emit_degraded

# --- base resolution. `base` is the human-readable DISPLAY short-name; `base_ref`
#     is the git-usable ref KNOWN to exist (may be a remote-tracking ref). Kept
#     separate so a remote-only default branch (origin/main with no local main —
#     fresh clone / CI checkout / worktree) does NOT make `git merge-base` fail and
#     fall open to degraded (F2 fix, preserved from v2.6.0). ---
base=""
base_ref=""
if ref=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); then
  base="${ref#origin/}"; base_ref="$ref"
elif git rev-parse --verify --quiet refs/remotes/origin/main >/dev/null 2>&1; then
  base="main"; base_ref="origin/main"
elif git rev-parse --verify --quiet refs/remotes/origin/master >/dev/null 2>&1; then
  base="master"; base_ref="origin/master"
elif git rev-parse --verify --quiet refs/heads/main >/dev/null 2>&1; then
  base="main"; base_ref="main"
elif git rev-parse --verify --quiet refs/heads/master >/dev/null 2>&1; then
  base="master"; base_ref="master"
else
  emit_degraded
fi

merge_base=$(git merge-base "$base_ref" HEAD 2>/dev/null) || emit_degraded
[[ -n "$merge_base" ]] || emit_degraded

# branch_ahead_count is a CHANGED-FILE count (NOT a commit count): the number of
# files differing between merge_base and HEAD. The SKILL's branch-mode
# resolved_scope_file_count reuses this value.
branch_ahead_count=$(git diff --name-only "$merge_base"..HEAD 2>/dev/null | wc -l | tr -d ' ')

# --- worktree_dirty: tracked changes OR non-ignored untracked.
#     --exclude-standard is intentional (NG4): .gitignore'd build artifacts must
#     NOT count as "changes" and false-trip changes_exist. ---
worktree_dirty="no"
if [[ -n "$(git diff HEAD --name-only 2>/dev/null)" ]]; then
  worktree_dirty="yes"
elif [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
  worktree_dirty="yes"
fi

changes_exist="no"
if [[ "$branch_ahead_count" -gt 0 || "$worktree_dirty" == "yes" ]]; then
  changes_exist="yes"
fi

echo "changes_exist: $changes_exist"
echo "branch_ahead_count: $branch_ahead_count"
echo "worktree_dirty: $worktree_dirty"
echo "base: $base"
echo "degraded: no"
exit 0
```

- [ ] **Step 2: Run the e2e — verify it now PASSES (GREEN)**

Run: `bash plugins/quality-gates/tests/test_qg_false_clean_floor.sh; echo "exit=$?"`
Expected: `test_qg_false_clean_floor: 4 passed, 0 failed`, `exit=0`.

- [ ] **Step 3: Run the OLD unit test — verify it now FAILS (expected; superseded contract)**

Run: `bash plugins/quality-gates/tests/test_check_review_scope.sh; echo "exit=$?"`
Expected: failures (the old cases assert `signal:`/`resolved_count:`/`merge_base:` and pass `session`/`paths` args that the shrunk script no longer emits). `exit=1`. Step 4 replaces this file.

- [ ] **Step 4: Rewrite `test_check_review_scope.sh` to the new contract**

Overwrite the entire file with exactly this content (cases: changes_exist yes/no, F2 remote-only base, NG4 ignored-vs-untracked, degraded detached/no-base, read-only). The fail-closed `mktemp`/`cd` idiom is retained:

```bash
#!/usr/bin/env bash
# test_check_review_scope.sh — coverage for scripts/check-review-scope.sh
# (design v2.7.0 §5.2, AC1–AC4). Each case isolates a throwaway git repo under
# mktemp so the live repo's working tree is untouched (fail-closed).

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
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1   # fail-closed: never run git in caller's repo
  git init -q
  git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo base > a.txt; git add a.txt; git commit -qm base
  git checkout -q -b feature
  echo work >> a.txt; git commit -qam work
}

# AC1: branch ahead → changes_exist yes, branch_ahead_count=1, base=main, degraded=no
case_changes_exist_branch_ahead() {
  mk_repo_feature_ahead
  local out; out=$(bash "$SCRIPT")
  if [[ "$(field changes_exist "$out")" == "yes" \
     && "$(field branch_ahead_count "$out")" == "1" \
     && "$(field base "$out")" == "main" \
     && "$(field degraded "$out")" == "no" ]]; then
    pass "branch ahead → changes_exist=yes (ahead=1, base=main, degraded=no)"
  else
    fail "branch ahead (got: $out)"
  fi
  cd / && rm -rf "$REPO"
}

# AC1: on base, clean tree → changes_exist no (genuine no-op)
case_changes_exist_none() {
  mk_repo_feature_ahead
  git checkout -q main
  local out; out=$(bash "$SCRIPT")
  if [[ "$(field changes_exist "$out")" == "no" \
     && "$(field branch_ahead_count "$out")" == "0" \
     && "$(field worktree_dirty "$out")" == "no" \
     && "$(field degraded "$out")" == "no" ]]; then
    pass "on base, clean tree → changes_exist=no (genuine no-op)"
  else
    fail "no changes (got: $out)"
  fi
  cd / && rm -rf "$REPO"
}

# AC3 (NG4): a .gitignore'd build artifact must NOT trip changes_exist.
case_ng4_ignored_not_counted() {
  mk_repo_feature_ahead
  git checkout -q main
  echo 'build/' > .gitignore; git add .gitignore; git commit -qm gitignore
  mkdir -p build; echo obj > build/x.o   # ignored, untracked
  local out; out=$(bash "$SCRIPT")
  if [[ "$(field changes_exist "$out")" == "no" \
     && "$(field worktree_dirty "$out")" == "no" ]]; then
    pass "gitignored artifact → changes_exist=no (NG4 --exclude-standard)"
  else
    fail "ng4 ignored (got: $out)"
  fi
  cd / && rm -rf "$REPO"
}

# AC3 (NG4): a non-ignored untracked file → worktree_dirty + changes_exist yes.
case_ng4_untracked_counted() {
  mk_repo_feature_ahead
  git checkout -q main
  echo new > newfile.txt   # non-ignored, untracked
  local out; out=$(bash "$SCRIPT")
  if [[ "$(field worktree_dirty "$out")" == "yes" \
     && "$(field changes_exist "$out")" == "yes" ]]; then
    pass "non-ignored untracked → worktree_dirty=yes, changes_exist=yes (NG4)"
  else
    fail "ng4 untracked (got: $out)"
  fi
  cd / && rm -rf "$REPO"
}

# AC2 (F2 regression): origin/main exists but there is NO local main — the
# fresh-clone / CI-checkout / worktree topology. base must resolve to a git-usable
# ref (origin/main) so merge-base succeeds and the signal does NOT fail-open to
# degraded in a common setup. A correct branch_ahead_count (>0) + degraded=no
# proves the internal merge_base resolved (merge_base is no longer emitted in v2.7.0).
case_f2_origin_head_no_local_main() {
  local remote; remote=$(mktemp -d) || exit 1; git init -q --bare "$remote"
  mk_repo_feature_ahead
  git remote add origin "$remote"
  git push -q origin main
  git push -q origin feature
  git fetch -q origin main feature 2>/dev/null || true  # ensure refs/remotes/origin/* exist
  git remote set-head origin main
  git branch -D main >/dev/null 2>&1   # only origin/main remains (no local main)
  local out rc; out=$(bash "$SCRIPT"); rc=$?
  if [[ "$(field base "$out")" == "main" \
     && "$(field changes_exist "$out")" == "yes" \
     && "$(field branch_ahead_count "$out")" == "1" \
     && "$(field degraded "$out")" == "no" \
     && "$rc" -eq 0 ]]; then
    pass "origin/main but NO local main → changes_exist=yes (not degraded fail-open)"
  else
    fail "F2 no-local-main fail-open (rc=$rc got: $out)"
  fi
  cd / && rm -rf "$REPO" "$remote"
}

# AC4: detached HEAD → degraded + exit 0 (fail-open)
case_degraded_detached() {
  mk_repo_feature_ahead
  git checkout -q --detach
  local out rc; out=$(bash "$SCRIPT"); rc=$?
  if [[ "$(field degraded "$out")" == "yes" && "$(field changes_exist "$out")" == "no" && "$rc" -eq 0 ]]; then
    pass "detached HEAD → degraded + exit 0 (fail-open)"
  else
    fail "degraded detached (rc=$rc got: $out)"
  fi
  cd / && rm -rf "$REPO"
}

# AC4: no main/master base branch + no remote → degraded + exit 0
case_degraded_no_base() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1   # fail-closed
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b weirdname
  echo x > a.txt; git add a.txt; git commit -qm x
  local out rc; out=$(bash "$SCRIPT"); rc=$?
  if [[ "$(field degraded "$out")" == "yes" && "$rc" -eq 0 ]]; then
    pass "no main/master base → degraded + exit 0"
  else
    fail "degraded no-base (rc=$rc got: $out)"
  fi
  cd / && rm -rf "$REPO"
}

# read-only: working tree + git status unchanged before/after
case_read_only() {
  mk_repo_feature_ahead
  local before after
  before=$(git status --porcelain=v1; find . -type f | sort)
  bash "$SCRIPT" >/dev/null 2>&1
  after=$(git status --porcelain=v1; find . -type f | sort)
  if [[ "$before" == "$after" ]]; then
    pass "read-only: working tree + git status unchanged"
  else
    fail "read-only violated (before != after)"
  fi
  cd / && rm -rf "$REPO"
}

case_changes_exist_branch_ahead
case_changes_exist_none
case_ng4_ignored_not_counted
case_ng4_untracked_counted
case_f2_origin_head_no_local_main
case_degraded_detached
case_degraded_no_base
case_read_only

echo
echo "test_check_review_scope: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 5: Run both script tests + the linter — all GREEN**

Run:
```bash
bash plugins/quality-gates/tests/test_check_review_scope.sh        | tail -1
bash plugins/quality-gates/tests/test_qg_false_clean_floor.sh      | tail -1
bash plugins/quality-gates/scripts/check-allowed-tools-order.sh    | tail -1
```
Expected:
- `test_check_review_scope: 8 passed, 0 failed`
- `test_qg_false_clean_floor: 4 passed, 0 failed`
- `check-allowed-tools-order: OK (18 tools in canonical order)` (script kept → unchanged)

- [ ] **Step 6: Commit**

```bash
git add plugins/quality-gates/scripts/check-review-scope.sh \
        plugins/quality-gates/tests/test_check_review_scope.sh \
        plugins/quality-gates/tests/test_qg_false_clean_floor.sh
git commit -m "feat(quality-gates): shrink check-review-scope.sh to changes-exist signal

Narrow the v2.6.0 detector's responsibility from scope-routing (modes/paths/
union/signal — the source of all 5 dogfood bugs) to the load-bearing
changes-exist signal the Step 4.5 floor keys on. Preserve F2 (remote-only base
base/base_ref split), NG4 (--exclude-standard untracked), and degraded fail-open.
Add the AC13 false-clean e2e (fail-closed fixtures) + rewrite the unit test to the
new contract.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Simplify the SKILL + rewrite the harness anchors + bump version (GREEN)

Rewrite the static protocol-shape anchors first (RED), then edit the SKILL so they pass (GREEN), and bump the version artifacts in the same commit (version headers are asserted by the harness).

**Files:**
- Modify: `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`
- Modify: `plugins/quality-gates/CHANGELOG.md`

- [ ] **Step 1: Update the harness version anchor (line ~154)**

Edit `tests/harness/test_skill_orchestration_behavior.sh`. Replace:
```bash
# Version bumped to 2.6.0 (title + final summary).
assert_line "v2.6.0 in SKILL" "$(first_line 'v2.6.0|2\.6\.0')"
```
with:
```bash
# Version bumped to 2.7.0 (title + final summary).
assert_line "v2.7.0 in SKILL" "$(first_line 'v2.7.0|2\.7\.0')"
```

- [ ] **Step 2: Replace the v2.6.0 empty-scope-redirect anchor region with v2.7.0 floor anchors**

In `tests/harness/test_skill_orchestration_behavior.sh`, replace the **entire** block that begins with the comment `# --- v2.6.0 AC6/AC7/AC9/AC13: empty-scope redirect gate ---` and ends with the `floor_count` `fi` block (the block that currently spans the `check-review-scope.sh invoked` assert through the `honest floor under-applied` failure branch) with exactly:

```bash
# --- v2.7.0 §5.2-5.4: changes-exist floor (routing removed, integrity kept) ---
# check-review-scope.sh still invoked in the Review gate (call+cache for the floor).
assert_line "check-review-scope.sh invoked" "$(first_line 'check-review-scope.sh')"

# AC12: the model-owned routing honesty norm is present.
assert_line "review-scope ownership honesty norm present" "$(first_line 'You own review-scope resolution')"

# AC5: the Step 4.5 floor keys on the two deterministic inputs — the resolved scope
# file count AND the script-emitted changes_exist (NOT the removed scope_signal).
assert_line "floor keyed on resolved_scope_file_count == 0" "$(first_line 'resolved_scope_file_count == 0')"
assert_line "floor keyed on changes_exist == yes"           "$(first_line 'changes_exist == yes')"
assert_line "honest floor label present"                    "$(first_line 'NOT certified clean')"

# AC6: degraded signal still emits a loud fail-open advisory.
assert_line "degraded scope advisory present" "$(first_line 'scope check degraded')"

# 'no scope reviewed' appears in the honesty norm + the floor sub-case + the final
# summary variant → at least 3 occurrences.
floor_count=$(grep -cE 'no scope reviewed' "$SKILL_MD" || true)
if [[ "$floor_count" -ge 3 ]]; then
  echo "PASS: honest floor label in honesty norm + floor + final summary ($floor_count)"
else
  echo "FAIL: honest floor under-applied (found $floor_count, need >=3)"
  fail=$((fail + 1))
fi

# --- v2.7.0 negative guards: the removed routing surface must be GONE ---
# (AC8) empty-scope redirect gate + its question anchor + section + signal value.
for pat in 'review scope is empty' 'Empty-scope redirect' 'empty_scope_with_changes'; do
  n=$(grep -cF "$pat" "$SKILL_MD" || true)
  if [[ "$n" -eq 0 ]]; then
    echo "PASS: removed routing surface absent — '$pat' (0)"
  else
    echo "FAIL: removed routing surface still present — '$pat' ($n)"
    fail=$((fail + 1))
  fi
done
# (AC9) $effective_diff_scope wiring gone; (AC10) scope-redirect kill switch gone;
# (hygiene) the old scope_signal variable gone.
for pat in 'effective_diff_scope' 'DEVBREW_QG_DISABLE_SCOPE_REDIRECT' 'scope_signal'; do
  n=$(grep -cF "$pat" "$SKILL_MD" || true)
  if [[ "$n" -eq 0 ]]; then
    echo "PASS: removed variable/switch absent — '$pat' (0)"
  else
    echo "FAIL: removed variable/switch still present — '$pat' ($n)"
    fail=$((fail + 1))
  fi
done
```

This deletes the now-invalid positive anchors (`review scope is empty`, `Empty-scope redirect decision section present`, `skipping reviewer dispatch`, `script-emitted commit SHA`, `DEVBREW_QG_DISABLE_SCOPE_REDIRECT` present, `effective_diff_scope` present, `effective_diff_scope = branch`, `as resolved at preflight` guard, `UNION of every change that triggered`, `CANONICAL for ALL remaining`, `scope_signal == empty_scope_with_changes`) and adds the v2.7.0 floor anchors + negative guards.

- [ ] **Step 3: Run the harness — verify it FAILS (RED)**

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh; echo "exit=$?"`
Expected: FAILs — the SKILL still contains the redirect section, `$effective_diff_scope`, `scope_signal`, and the kill switch, and lacks the honesty norm + `resolved_scope_file_count == 0`. `exit=1`.

- [ ] **Step 4: SKILL — delete the `$effective_diff_scope` paragraph (Step 1, after the transparency line)**

Edit `skills/quality-pipeline/SKILL.md`. Delete this entire block (it sits between the step-1 scope-transparency paragraph and `**Step 1b`):
```
   **Effective scope variable (single source — closes the stale-after-redirect class).**
   Set the orchestrator variable `$effective_diff_scope` = the scope resolved here
   (`session` / `branch` / `paths`), with its review target (`branch` →
   `$merge_base..HEAD` once Step 1b resolves the base; `paths` → the `--paths`
   globs; `session` → the session `files.md` set). EVERY downstream scope consumer
   — the scout (step 2), every reviewer dispatch (step 3, the `diff_scope:` field),
   and the code-reviewer/codex inlined diff blob — reads `$effective_diff_scope`,
   NEVER the raw preflight value. The Step-1b "Review branch diff" redirect updates
   `$effective_diff_scope` in ONE place (next to `$scope_signal = normal`), so the
   new scope propagates to every consumer at once — the dispatch scope and the
   floor's `$scope_signal` always move together (the same defect class as F1).

```
(Remove the block and its surrounding blank line so the transparency paragraph is directly followed by `**Step 1b`.)

- [ ] **Step 5: SKILL — rewrite Step 1b (call-once-cache + honesty norm)**

Replace the entire Step 1b block (from `**Step 1b — Scope signal & empty-scope redirect (iteration N=1 only).** Before` through the paragraph ending `...so they always run on the redirect-selected non-empty scope and never re-trigger the signal.`) with exactly:

```
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
```

- [ ] **Step 6: SKILL — fix the scout (step 2) scope reference**

Replace:
```
2. Dispatch the scout: `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/scout.py ...)` — compute its
   metrics from **`$effective_diff_scope`'s target** (e.g. `git diff $merge_base` + untracked
   for the branch-union redirect), never the raw preflight scope, so a Step-1b redirect is
   honored here (C1).
```
with:
```
2. Dispatch the scout: `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/scout.py ...)` — compute its
   metrics from the review scope you resolved at step 1 (the session `files.md` set, the
   `branch` diff, or the `--paths` globs). Scope is model-owned; there is no cached scope
   variable to thread.
```

- [ ] **Step 7: SKILL — fix the security-reviewer `diff_scope:` dispatch field**

Replace:
```
    diff_scope: <$effective_diff_scope — the CURRENT scope after Step 1b, NOT the raw preflight value; a 'Review branch diff' redirect makes this 'branch' with target = the redirect union (git diff $merge_base + untracked)>
```
with:
```
    diff_scope: <the review scope you resolved at step 1: session (files.md set) / branch (git diff vs base) / paths (--paths globs)>
```

- [ ] **Step 8: SKILL — fix the codex/code-reviewer inlined-blob paragraph**

Replace:
```
   `pr-review-toolkit:code-reviewer` (if pr-review-toolkit available) and
   the codex reviewer (if `detect_codex.sh` returns true) are dispatched
   with their own contracts; they do not require `project_dir` because
   they re-derive scope from the inlined diff blob — **build that blob from
   `$effective_diff_scope`'s target** (the empty-scope redirect's branch-union
   `git diff $merge_base` + untracked, or the explicit branch/paths/session target),
   NOT the raw preflight scope (C4 — same single-source rule as the scout and the
   `diff_scope:` field).
```
with:
```
   `pr-review-toolkit:code-reviewer` (if pr-review-toolkit available) and
   the codex reviewer (if `detect_codex.sh` returns true) are dispatched
   with their own contracts; they do not require `project_dir` because
   they re-derive scope from the inlined diff blob — **build that blob from the
   review scope you resolved at step 1** (the explicit branch / paths / session
   target). Scope is model-owned (the honesty norm above); the floor independently
   guards the empty-scope-with-changes case.
```

- [ ] **Step 9: SKILL — rewrite Step 4.5 (floor on `resolved_scope_file_count` × `changes_exist`)**

Replace the entire Step 4.5 block — from `   **Step 4.5 — Surface findings.** Judge the boundary on the **kept` through the end of the `kept = 0 AND suppressed = 0` case (ending `...short-circuits the Runtime gate for the review-only path, else runs it).`) — with exactly:

```
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
     Loop](#dispatch-loop) step 4** (which skips the Runtime gate when gate scope =
     Review gate only / `effective_skip_runtime`, else runs it) — do not iterate again.
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
     `$worktree_dirty`). A zero-scope run with real changes must never read as
     "reviewed & clean".
   - ELSE IF `$degraded == yes AND $resolved_scope_file_count == 0`: print
     `## Review gate iter N: clean` AND the loud advisory
     `> [quality-gates] scope check degraded (detached HEAD / no base branch / unrelated history / shallow) — empty-scope detection skipped (fail-open; verdict not floor-protected this run).`
   - ELSE: print `## Review gate iter N: clean` exactly as before (scope > 0, or a
     genuine no-op with `$changes_exist == no` — unchanged happy path).
```

- [ ] **Step 10: SKILL — delete the entire `## Empty-scope redirect decision` section**

Delete everything from the line `## Empty-scope redirect decision` up to (but not including) `## Review iter boundary decision`. This removes the section header, the `> **Spec anchor (AC6):** ... review scope is empty ...` note, the `AskUserQuestion({ ... })` redirect template, the `Substitute <M> = ...` paragraph, and all three branch descriptions (Review branch diff / Proceed honest-empty / Stop). After this edit, the `---` that precedes `## Empty-scope redirect decision` should be immediately followed by `## Review iter boundary decision`. (Verify the preceding `---` separator and the two decision-template intro paragraphs above it are left intact.)

- [ ] **Step 11: SKILL — bump the two version headers**

Replace `# Quality Gates — In-Turn Orchestrator (v2.6.0)` with `# Quality Gates — In-Turn Orchestrator (v2.7.0)`.
Replace `## Quality Gates Pipeline — Complete (v2.6.0)` with `## Quality Gates Pipeline — Complete (v2.7.0)`.

- [ ] **Step 12: Bump `plugin.json` to 2.7.0**

Edit `.claude-plugin/plugin.json`: replace `"version": "2.6.0",` with `"version": "2.7.0",`.

- [ ] **Step 13: Prepend the `## [2.7.0]` CHANGELOG entry**

Edit `CHANGELOG.md`. Insert the following block **between** line 5 (the blank line after the format/SemVer header) and the existing `## [2.6.0] — 2026-06-07` line — i.e. immediately above `## [2.6.0]`, preserving everything below:

```
## [2.7.0] — 2026-06-13

v2.6.0 false-clean detector에서 *routing 재구성*(무엇이 바뀌었나를 git으로 재구성)을 제거하고
*verdict 무결성 floor*(0파일인데 clean 금지)만 결정론으로 유지. dogfood 5개 버그가 전부 routing에서
나왔고 floor의 load-bearing 입력(`changes_exist`)은 한 번도 틀린 적 없다는 관찰에 따라 버그원천과
가치원천을 분리. `check-review-scope.sh`는 `changes_exist`만 emit하는 ~40줄로 축소되고, redirect
게이트·`$effective_diff_scope`·`DEVBREW_QG_DISABLE_SCOPE_REDIRECT`는 제거. routing은 모델 +
`/qg branch` escape hatch + 정직 norm 한 줄에 위임. 정상 경로(scope>0 / genuine no-op)는 무변경.
devbrew P8 determinism-economy + harness lightness instantiation(결정론은 load-bearing 무결성
floor 한 점에만; routing은 모델 신뢰).

### Removed
- **Empty-scope redirect 게이트** (SKILL Step 1b + `## Empty-scope redirect decision` 섹션 전체):
  빈 scope 시 3옵션 AskUserQuestion(branch diff / honest-empty / stop) + union 재계산. routing은
  모델 영역이므로 구조적 게이트 불필요(lightness; 사용자 "구조적 redirect 제거" 결정).
- **`$effective_diff_scope` single-source 변수 배선** (SKILL Step 1 + scout/dispatch/inlined-blob):
  redirect 전파용 캐시 변수. redirect 제거로 소비자 소멸 — scout/reviewer dispatch/codex blob은
  이제 모델-소유 scope를 직접 참조.
- **kill switch `DEVBREW_QG_DISABLE_SCOPE_REDIRECT`** (SKILL / qg.md / README): redirect 게이트와
  함께 제거. floor는 kill switch 없는 load-bearing 컨트롤로 유지.
- **`check-review-scope.sh`의 routing 출력**: `signal`(4-way) / `resolved_count` / `merge_base` emit,
  `mode`(session/branch/paths) 인자, `paths` glob union. 단위 테스트의 mode/paths/signal 케이스 제거.

### Changed
- **`scripts/check-review-scope.sh` 120줄 → ~40줄**: 단일 책임을 *"resolved scope가 비었는데 변경이
  있나?"*에서 *"브랜치/워킹트리에 변경이 존재하나?"*로 좁힘. emit = `changes_exist` / `branch_ahead_count`
  (변경 파일 수) / `worktree_dirty` / `base` / `degraded`. load-bearing fix 보존(F2 remote-only base
  `base`/`base_ref` 분리, NG4 `--exclude-standard` untracked, degraded fail-open + loud advisory).
- **정직-verdict floor (SKILL Step 4.5)**: 캐시된 `$scope_signal == empty_scope_with_changes` 대신
  `$resolved_scope_file_count == 0 AND $changes_exist == yes`(두 결정론 신호의 곱)로 발동. 차단력
  무손실 — `changes_exist`는 모델 clean 주장과 무관한 객관 신호. degraded면 fail-open + loud advisory.
- **honesty norm 한 줄 추가 (SKILL Step 1b)**: 모델이 review-scope를 소유하고, 빈 scope + 변경 시
  `/qg branch` 제안 또는 honest verdict를 내도록 명시. routing(모델)/integrity(floor) 분리.
- **버전 2.6.0 → 2.7.0** (minor — surface 제거 + 동작 단순화, false-clean 차단 contract 보존):
  `plugin.json`, SKILL 제목 + Final Summary, harness 버전 assertion(`v2.6.0`→`v2.7.0`) 동기화.
- **README `인스턴스화한 원칙` self-honest-floor bullet + `commands/qg.md` Scope/kill-switch 문서** 갱신.
- **신규 테스트 `tests/test_qg_false_clean_floor.sh`** (fail-closed e2e): false-clean 차단 + happy-path
  clean + genuine no-op clean + degraded fail-open.

```

- [ ] **Step 14: Run the harness — verify GREEN; then the linter + grep ACs**

Run:
```bash
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh; echo "harness exit=$?"
bash plugins/quality-gates/scripts/check-allowed-tools-order.sh | tail -1
```
Expected: `test_skill_orchestration_behavior: all protocol-shape assertions PASS`, `harness exit=0`; `check-allowed-tools-order: OK (18 tools in canonical order)`.

If the harness `iter cap near Review gate AskUserQuestion` proximity assertion fails (distance > 120), that is a real signal — re-read the Step 1b/4.5 region; do NOT auto-widen the bound. The region shrank, so it is expected to pass at the existing 120.

Then verify the removal-grep ACs against the **active** SKILL (AC8/9/10):
```bash
SK=plugins/quality-gates/skills/quality-pipeline/SKILL.md
for p in 'review scope is empty' 'Empty-scope redirect' 'empty_scope_with_changes' 'effective_diff_scope' 'DEVBREW_QG_DISABLE_SCOPE_REDIRECT' 'scope_signal'; do
  printf '%s: ' "$p"; grep -cF "$p" "$SK"
done
```
Expected: every line prints `0`.

- [ ] **Step 15: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md \
        plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh \
        plugins/quality-gates/.claude-plugin/plugin.json \
        plugins/quality-gates/CHANGELOG.md
git commit -m "feat(quality-gates): floor on changes_exist; remove routing redirect (v2.7.0)

Step 1b becomes a single call-once-cache of the changes-exist signal; the Step 4.5
floor keys on resolved_scope_file_count == 0 AND changes_exist == yes (two
deterministic signals). Delete the empty-scope redirect gate, the
\$effective_diff_scope wiring, the scope_signal variable, and the
DEVBREW_QG_DISABLE_SCOPE_REDIRECT kill switch; add a one-line model-owned routing
honesty norm. Bump to v2.7.0 (plugin.json + SKILL headers + harness assertion) and
prepend the CHANGELOG entry.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Sync the user-facing docs (qg.md + README)

**Files:**
- Modify: `plugins/quality-gates/commands/qg.md`
- Modify: `plugins/quality-gates/README.md`

- [ ] **Step 1: qg.md — remove the kill-switch table row**

Edit `commands/qg.md`. Delete this entire table row:
```
| `DEVBREW_QG_DISABLE_SCOPE_REDIRECT=1` | Disable the empty-scope redirect question (advisory only); the honest-verdict floor still applies |
```

- [ ] **Step 2: qg.md — rewrite the false-clean scope prose**

Replace:
```
빈 세션에서 커밋된 변경이 있어 resolved scope가 0인데 브랜치는 base보다 앞서 있으면 (false-clean),
qg는 "clean"이라 하지 않는다 — `check-review-scope.sh`가 `empty_scope_with_changes`를 결정론으로
탐지해 **정직-verdict floor**(verdict를 `no scope reviewed … NOT certified clean`으로 교체;
kill 불가)와 1클릭 **redirect 게이트**(branch diff 리뷰 제안; `DEVBREW_QG_DISABLE_SCOPE_REDIRECT=1`로
끌 수 있음)를 띄운다. 진짜 변경 없음(genuine no-op)은 그대로 `clean`.
```
with:
```
빈 세션에서 커밋된 변경이 있어 resolved scope가 0인데 브랜치는 base보다 앞서 있으면 (false-clean),
qg는 "clean"이라 하지 않는다 — read-only `check-review-scope.sh`가 `changes_exist`를 결정론으로
emit하고, Review gate의 **정직-verdict floor**가 `resolved scope 0 AND changes_exist == yes`이면
verdict를 `no scope reviewed … NOT certified clean`으로 교체한다(load-bearing, kill 불가). 무엇을
리뷰할지(routing)는 모델이 소유 — 빈 scope면 모델이 `/qg branch`(전체 브랜치 리뷰)를 제안한다.
진짜 변경 없음(genuine no-op)은 그대로 `clean`; 신호가 degraded면 fail-open + loud advisory.
```

- [ ] **Step 3: README — rewrite the P8 self-honest-floor bullet (line ~24)**

Edit `README.md`. Replace the bullet that begins `- **P8 determinism-economy — self-honest verdict floor** (v2.6.0)` (a single long line) with exactly:
```
- **P8 determinism-economy — self-honest verdict floor** (v2.6.0; routing 제거·단순화 v2.7.0) — Review gate가 *검토받았다고 믿는 scope*와 *resolve한 scope*가 발산할 때(빈 세션 → resolved scope 0 → "clean"의 false-clean)를 봉쇄. read-only `scripts/check-review-scope.sh`가 `changes_exist`를 결정론으로 emit하고, SKILL이 iter-1에서 1회 호출·캐시해 **정직-verdict floor**(load-bearing, kill 불가)가 `resolved scope 0 AND changes_exist == yes`이면 verdict를 `no scope reviewed … NOT certified clean`으로 교체. **무엇을 리뷰할지(routing)는 모델이 소유** — v2.7.0에서 v2.6.0의 redirect 게이트·`$effective_diff_scope` 배선·`DEVBREW_QG_DISABLE_SCOPE_REDIRECT` kill switch를 제거하고 `/qg branch` escape hatch + honesty norm 한 줄로 대체(dogfood 5버그가 전부 routing 재구성에서 나왔고 floor의 load-bearing 입력 `changes_exist`는 틀린 적 없음). 결정론은 무결성 floor 한 점에만; routing/자연어는 모델 신뢰. genuine no-op·session 기본값·`/qg branch`는 무변경. regression: `tests/test_check_review_scope.sh`, `tests/test_qg_false_clean_floor.sh`.
```

- [ ] **Step 4: Verify the removal-grep ACs against the active docs (qg.md + README)**

Run:
```bash
for f in plugins/quality-gates/commands/qg.md plugins/quality-gates/README.md; do
  printf '%s: ' "$f"; grep -cF 'DEVBREW_QG_DISABLE_SCOPE_REDIRECT' "$f"
done
grep -cF 'empty_scope_with_changes' plugins/quality-gates/commands/qg.md
grep -cF 'empty_scope_with_changes' plugins/quality-gates/README.md
```
Expected: every count is `0`. (The terms survive only in `CHANGELOG.md` history — correct.)

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/commands/qg.md plugins/quality-gates/README.md
git commit -m "docs(quality-gates): sync qg.md + README to v2.7.0 changes-exist floor

Remove the DEVBREW_QG_DISABLE_SCOPE_REDIRECT kill-switch row and rewrite the
false-clean scope prose (qg.md); update the P8 self-honest-floor Principle bullet
to reflect routing removal + the changes_exist floor (README).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Full verification + required codex `/qg` dogfood

The floor is a security/integrity control. Per spec §8 step 7, a codex-diversity dogfood is **part of** verification (not optional): v2.6.0's `/qg` self-dogfood is exactly what caught the fail-open (F2) that two prior subagent review stages missed, and codex's independent (read-only, leak-proof) review is what surfaced it (`project_qg_scope_capture`).

**Files:** none (verification only; any fix loops back into the relevant task + a reviewer-persona edit per Law 3).

- [ ] **Step 1: Re-run every directly-affected test + linter (all GREEN)**

```bash
bash plugins/quality-gates/tests/test_check_review_scope.sh                   | tail -1
bash plugins/quality-gates/tests/test_qg_false_clean_floor.sh                 | tail -1
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh | tail -1
bash plugins/quality-gates/scripts/check-allowed-tools-order.sh               | tail -1
bash plugins/quality-gates/tests/test_check_allowed_tools_order.sh            | tail -1
```
Expected: `8 passed, 0 failed` / `4 passed, 0 failed` / `all protocol-shape assertions PASS` / `OK (18 tools in canonical order)` / `All tests pass.`

- [ ] **Step 2: AC15 baseline comparison — no new reds**

Re-run the Task 1 Step 4 sweep. Expected: the **same** ~8 pre-existing environment-dependent reds recorded in Task 1, and **zero** new failures. If a previously-green test is now red, it is in scope — fix it before proceeding.

- [ ] **Step 3: grep-AC final confirmation (AC8/9/10) across active docs**

```bash
for f in plugins/quality-gates/skills/quality-pipeline/SKILL.md \
         plugins/quality-gates/commands/qg.md \
         plugins/quality-gates/README.md; do
  for p in 'DEVBREW_QG_DISABLE_SCOPE_REDIRECT' 'effective_diff_scope' 'review scope is empty' 'empty_scope_with_changes'; do
    n=$(grep -cF "$p" "$f"); [[ "$n" -eq 0 ]] || echo "LEAK: $f :: $p ($n)"
  done
done
echo "grep-AC done"
```
Expected: only `grep-AC done` (no `LEAK:` lines).

- [ ] **Step 4: Required codex `/qg` dogfood on the feature branch**

Run the Review gate against the full feature branch so codex model-diversity independently examines the simplified floor and the shrunk script:
```
/qg branch review
```
Confirm in the run: (a) `check-review-scope.sh` is invoked once and the floor verdict honors the changes-exist signal; (b) codex (if `detect_codex.sh` is true) reviews the diff and does **not** surface a floor fail-open or a false-clean path. **If codex (or any reviewer) flags a real defect in the floor/script:** stop, fix the code, AND — if a reviewer *should* have caught it but didn't — edit the relevant reviewer persona (`plugins/quality-gates/agents/*.md`) in the same fix (Law 3 compounding), then re-run from the affected task. Do not record "clean" before the verdict is in (`feedback_evidence_before_approved`).

- [ ] **Step 5: Final branch sanity**

```bash
git log --oneline feature/qg-detector-simplification ^main | cat
git status --porcelain
```
Expected: 3 implementation commits (Task 3, 4, 5) on top of the design-doc commit; a clean working tree (no stray fixtures — every test `rm -rf`s its `mktemp` repo).

---

## Self-Review (run after writing the plan; performed inline)

**1. Spec coverage** — every AC maps to a task:
- AC1 (script emits changes_exist/branch_ahead/worktree/base/degraded, no signal/mode/paths) → Task 3 Step 1 + unit cases.
- AC2 (F2 remote-only base) → Task 3 `case_f2_origin_head_no_local_main`.
- AC3 (NG4 ignored-vs-untracked) → Task 3 `case_ng4_*`.
- AC4 (degraded detached/no-base, exit 0) → Task 3 `case_degraded_*`.
- AC5 (floor relabels false-clean; two-layer verify) → Task 4 Step 2 anchors + Task 2/3 e2e `case_false_clean_blocked`.
- AC6 (degraded fail-open + advisory) → Task 4 Step 9 ELSE-IF + harness anchor + Task 2 `case_degraded_fail_open`.
- AC7 (happy-path no regression) → Task 2 `case_scope_present_clean` + Task 4 ELSE branch.
- AC8 (`review scope is empty` gone; redirect section gone) → Task 4 Steps 10 + 14 negative guards.
- AC9 (`$effective_diff_scope` gone) → Task 4 Steps 4/6/7/8 + negative guard.
- AC10 (kill switch gone from SKILL/qg.md/README) → Task 4 Step 5, Task 5 Steps 1/3, grep checks.
- AC11 (allowed-tools/linter unchanged) → Task 3 Step 5 + Task 6 Step 1 (`OK (18 tools)`); script kept-not-renamed.
- AC12 (honesty norm present) → Task 4 Step 5 norm + Step 2 anchor.
- AC13 (false-clean e2e, fail-closed) → Task 2 (new dedicated file) + Task 3 GREEN.
- AC14 (plugin.json 2.7.0 + CHANGELOG + README) → Task 4 Steps 12/13, Task 5 Step 3.
- AC15 (baseline no new reds) → Task 1 Step 4 + Task 6 Step 2.

**2. Placeholder scan** — no TBD/TODO; every code step shows full content or an exact old→new string pair; every run step states the expected output.

**3. Type/name consistency** — field names (`changes_exist`, `branch_ahead_count`, `worktree_dirty`, `base`, `degraded`) are identical across the script (Task 3), the e2e (Task 2), the unit test (Task 3), the SKILL floor (Task 4), and the harness anchors (Task 4). `resolved_scope_file_count` and the verdict labels (`no scope reviewed … NOT certified clean`, `scope check degraded …`) match between the e2e mirror, the SKILL prose, and the harness `first_line` patterns. `floor_verdict` returns the same three tokens the SKILL three-way IF produces. The version string `v2.7.0` is consistent across plugin.json, both SKILL headers, the harness assertion, and the CHANGELOG heading.

**Deliberate deviations from the spec's Files-to-Modify (documented, spec-intent-preserving):**
- The AC13 e2e lives in a **new** `tests/test_qg_false_clean_floor.sh` rather than inside `test_skill_orchestration_behavior.sh` (Pre-flight fact #6: `set -e` live-git safety; the harness is still modified for the static AC5/6/12 anchors + AC8/9/10 negatives). The spec's Handoff Context explicitly defers fixture details to the plan and mandates fail-closed fixtures — this split is the safe realization. A reviewer comparing plan↔spec should treat this as covered, not a gap.
