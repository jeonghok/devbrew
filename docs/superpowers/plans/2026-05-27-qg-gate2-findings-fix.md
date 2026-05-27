# quality-gates v1.32.1 — Gate 2 Findings Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` (spec §8 chose **Inline Execution**, not subagent-driven). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve 27+ Gate 2 findings on PR #71 (quality-gates v1.32.0) and bump to v1.32.1.

**Architecture:** Per-file-group commits (~10 commits). Each task = one file group = one commit. Final commit bumps plugin version 1.32.0 → 1.32.1. Inline execution in the same conversation that runs the plan.

**Tech Stack:** bash 4+, python3, jq, grep, awk. No new runtime dependencies. Plugin path: `plugins/quality-gates/`.

**Spec:** [`docs/superpowers/specs/2026-05-27-qg-gate2-findings-fix-design.md`](../specs/2026-05-27-qg-gate2-findings-fix-design.md) (approved after 4 reviewing-spec rounds; 15 prior issues all resolved revised).

**Findings source:** [`docs/superpowers/plans/notes/2026-05-27-gate2-findings.md`](notes/2026-05-27-gate2-findings.md).

---

## Worktree absolute path

**Use this path for every Edit/Write call in this plan:**

```
/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
```

Per `feedback_subagent_worktree_path_emphasis.md`: re-state this in every Edit/Write call to avoid main-repo path drift.

Branch: `worktree-feature-qg-askq-iteration` (local) / `feature/qg-askq-iteration` (remote). PR #71 already open. Do NOT create a new branch.

---

## Task 0: Preflight

**Files:** none modified.

**Purpose:** Verify branch state, plugin version baseline, and pre-conditions for §5.4 LEGACY_V1_KEYS edit before any code changes.

- [ ] **Step 0.1: Verify branch and clean tree**

Run:

```bash
git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration rev-parse --abbrev-ref HEAD
git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration status --short
```

Expected: `worktree-feature-qg-askq-iteration` and only `??` untracked entries OK (no modified tracked files). If modified tracked files exist, STOP and surface them — they may be unrelated WIP.

- [ ] **Step 0.2: Verify plugin baseline version**

Run:

```bash
jq -r .version /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration/plugins/quality-gates/.claude-plugin/plugin.json
```

Expected: `1.32.0`. If anything else, STOP — spec assumes 1.32.0 baseline.

- [ ] **Step 0.3: Verify LEGACY_V1_KEYS pre-condition (§5.4)**

Run:

```bash
grep -nE '"current" \+ "_gate:"' /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration/plugins/quality-gates/hooks/session-start-advisor.py
grep -cE 'consecutive_no_signal:' /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration/plugins/quality-gates/hooks/session-start-advisor.py
```

Expected: first grep returns 1 match on line 43; second grep returns ≥1 match (literal still present). Records the file state spec §5.4 pre-condition expects.

If pre-condition does NOT hold, note the deviation in Task 4 commit body but still apply the Final form (split both keys) per spec §5.4 recovery branch.

- [ ] **Step 0.4: Snapshot test baseline (record current pass/fail state)**

Run:

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
for f in plugins/quality-gates/tests/test_*.sh; do
  printf '%s: ' "$f"; bash "$f" >/dev/null 2>&1 && echo PASS || echo FAIL
done
for f in plugins/quality-gates/tests/test_*.py; do
  printf '%s: ' "$f"; python3 "$f" >/dev/null 2>&1 && echo PASS || echo FAIL
done
```

Expected: at least `test_setup_qg.sh`, `test_session_start_advisor.py`, `test_kill_switches.py`, `test_worktree.sh` show FAIL (these are the stale tests this plan repairs). Record the baseline — used in Task 11 as the before/after diff for the PR comment.

---

## Task 1: SKILL.md — C1 / C6 ref / I6 / I7 / I10 / I11

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`

**Finding IDs absorbed:** C1, C6 (test reference only — new test created in Task 8), I6, I7, I10, I11.

**Why grouped:** all touch one file. Spec §5.1 + §5.7. Per-finding commits would split a single file across 6 commits.

- [ ] **Step 1.1: Read SKILL.md to locate anchor sections**

Use the Read tool on `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration/plugins/quality-gates/skills/quality-pipeline/SKILL.md`. Note line numbers for:

- The first `subagent_type: "adversarial"` dispatch block.
- The first `subagent_type: "test-scope-validator"` dispatch block.
- The first `subagent_type: "security-reviewer"` dispatch block.
- The first `subagent_type: "runtime-verifier"` dispatch block.
- Any frontmatter `gate2_iteration:` field.
- The Retry-path section (search for `Retry` near Gate 2 fix-loop).
- The check-trivia exit-code branch (search for `exit code 2` near trivia section).
- The Gate 2 Retry file-write block (search for `file:` near reviewer-supplied path handling).

- [ ] **Step 1.2: C1 — Add Preflight project_dir derivation**

In the SKILL.md "Preflight" or "Arguments" section near the top (before any Agent dispatch), add a bash block that derives `project_dir` once:

```markdown
**Preflight step P0 (project_dir derivation).** Before any reviewer dispatch,
compute the project directory used as the dispatch coordinate:

```bash
project_dir=$(pwd)
```

This value is threaded into every reviewer dispatch in the `project_dir:` field
of the prompt. Worktree-aware: `pwd` resolves to the active worktree root.
```

Use the Edit tool to insert before the first Agent dispatch.

- [ ] **Step 1.3: C1 — Thread project_dir into each reviewer dispatch**

For each of the 4 reviewer dispatches found in Step 1.1, use Edit to add a `project_dir: "<value>"` line inside the Agent prompt template. Pattern (apply 4 times, once per agent):

```diff
 Agent(
   subagent_type="quality-gates:adversarial",
   prompt="...
+    project_dir: \"$project_dir\"
     ...other fields..."
 )
```

Use Edit with replace_all=false; each dispatch has a unique surrounding context so use enough surrounding lines to disambiguate.

- [ ] **Step 1.4: Verify AC1 (per-dispatch grep)**

Run:

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
for agent in adversarial test-scope-validator security-reviewer runtime-verifier; do
  grep -A10 "subagent_type[^\"]*\"$agent" plugins/quality-gates/skills/quality-pipeline/SKILL.md \
    | grep -q "project_dir:" || { echo "AC1 FAIL: $agent dispatch missing project_dir"; exit 1; }
done
echo "AC1 PASS"
grep -cE 'project_dir=\$\(pwd\)' plugins/quality-gates/skills/quality-pipeline/SKILL.md
```

Expected: `AC1 PASS` printed; second grep returns ≥1.

- [ ] **Step 1.5: I6 — Add Retry-path error-handling AskUserQuestion block**

Locate the Gate 2 Retry-path section in SKILL.md (from Step 1.1). Use Edit to insert after the Retry-loop description:

```markdown
**Retry error handling.** If `Edit` returns one of `old_string not unique`,
`EACCES`, `ENOSPC`, or any other failure during the Retry application,
surface it via AskUserQuestion:

```
AskUserQuestion(
  questions=[{
    question: "Retry failed at <file>: <reason>. Skip retry / abort?",
    header: "Retry",
    options: [
      { label: "Skip retry / abort", description: "Abort this Retry iteration; surface to Gate 2 verdict." },
      { label: "Continue with next file", description: "Skip this file's fix; continue Retry loop." }
    ],
    multiSelect: false
  }]
)
```

No silent retry-skip — every Edit failure surfaces a user choice.
```

- [ ] **Step 1.6: I7 — Remove check-trivia exit-2 branch**

Find the SKILL prose describing `check-trivia.sh` exit codes. If it has a branch like "if exit code 2 then ...", delete that branch entirely. The script never exits 2; real environment failures should propagate as script errors to the user, not be misclassified as "non-trivia, proceed".

Use Edit to remove the unreachable branch.

- [ ] **Step 1.7: I10 — Add file-write safety canonicalization**

In the Retry-path section (near Step 1.5's I6 block), insert a canonicalization clause:

```markdown
**File-write safety.** Before applying any reviewer-supplied `file:` field,
canonicalize both sides:

```python
import os
root = os.path.realpath(project_dir)
candidate = os.path.realpath(supplied_file)
if os.path.commonpath([root, candidate]) != root:
    raise SecurityError(f"Path escapes project_dir: {candidate}")
```

Display the **full canonicalized file list** in the AskUserQuestion `description`
(not just the `<summary>` field) so the user sees every path being written.
Reject and warn on any path resolving outside `project_dir`.
```

- [ ] **Step 1.8: I11 — Remove gate2_iteration phantom field**

Search SKILL.md frontmatter template for `gate2_iteration:`:

```bash
grep -n '^gate2_iteration:' plugins/quality-gates/skills/quality-pipeline/SKILL.md
```

If present, use Edit to delete the entire line (the History section carries the real counter).

- [ ] **Step 1.9: C6 — Reference the new protocol-shape test**

In SKILL.md's testing/verification section (if present), add:

```markdown
**Protocol-shape regression**: the SKILL.md orchestration contract is
verified by `tests/harness/test_skill_orchestration_behavior.sh` (added
in v1.32.1). The previous static-grep V7 assertion in
`tests/test_skill_orchestration.sh` is deleted; the new test must be
present before V7 can be removed (atomic). See spec §5.6.9.
```

- [ ] **Step 1.10: Verify Task 1 ACs**

Run:

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
# AC11a (I6)
grep -A5 'Retry' plugins/quality-gates/skills/quality-pipeline/SKILL.md \
  | grep -iqE 'AskUserQuestion.*(Retry failed|skip retry|abort)' \
  && echo "AC11a PASS" || echo "AC11a FAIL"
# AC11b (I7)
test "$(grep -cE 'check-trivia.*exit.*2|exit.*code.*2.*check-trivia|trivia.*== *2' plugins/quality-gates/skills/quality-pipeline/SKILL.md)" -eq 0 \
  && echo "AC11b PASS" || echo "AC11b FAIL"
# AC11c (I10)
grep -q 'realpath' plugins/quality-gates/skills/quality-pipeline/SKILL.md \
  && grep -q 'commonpath' plugins/quality-gates/skills/quality-pipeline/SKILL.md \
  && grep -A3 'realpath' plugins/quality-gates/skills/quality-pipeline/SKILL.md | grep -q 'project_dir' \
  && echo "AC11c PASS" || echo "AC11c FAIL"
# AC14 (I11)
test "$(grep -cE '^gate2_iteration:' plugins/quality-gates/skills/quality-pipeline/SKILL.md)" -eq 0 \
  && echo "AC14 PASS" || echo "AC14 FAIL"
```

All four must print PASS.

- [ ] **Step 1.11: Commit Task 1**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md
git commit -m "$(cat <<'EOF'
fix(quality-gates): SKILL.md — restore project_dir contract + retry safety

Findings resolved:
- C1: thread project_dir into 4 reviewer dispatches (adversarial,
  test-scope-validator, security-reviewer, runtime-verifier) + preflight P0.
- C6 (reference): point SKILL testing section at new protocol-shape test
  in tests/harness/ (test added separately in Task 8).
- I6: Retry-path error-handling AskUserQuestion block (Edit failure surfaces
  user choice instead of silent skip).
- I7: remove unreachable check-trivia exit-2 branch.
- I10: realpath + commonpath canonicalization for reviewer-supplied file:
  fields (both sides normalised; full file list shown in
  AskUserQuestion description).
- I11: remove phantom gate2_iteration: 0 frontmatter field (real counter
  lives in History section).

ACs verified: AC1, AC11a, AC11b, AC11c, AC14.
Spec: docs/superpowers/specs/2026-05-27-qg-gate2-findings-fix-design.md §5.1, §5.7

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: setup-qg.sh — C3 / I3

**Files:**
- Modify: `plugins/quality-gates/scripts/setup-qg.sh`

**Findings absorbed:** C3, I3.

- [ ] **Step 2.1: Read setup-qg.sh to locate insertion points**

Read `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration/plugins/quality-gates/scripts/setup-qg.sh`. Note:

- Header comment near line 4 (mentions "Stop hook-based").
- `--help` output near lines 95-96 (mentions "Stop hook-based").
- State-file write block (where `pipeline.md` is created with frontmatter).

- [ ] **Step 2.2: I3 — Remove "Stop hook-based" wording**

Use Edit (replace_all=true if the phrase appears identically twice; otherwise two separate Edits):

```diff
-# Stop hook-based pipeline state setup
+# Pipeline state setup (AskUserQuestion-iteration-based)
```

Repeat for the `--help` output.

- [ ] **Step 2.3: C3 — Restore DEVBREW_GATE3_MAX_RESOLUTIONS validation**

Find the state-file write block. Insert before it (or near the env-var defaulting section):

```bash
# DEVBREW_GATE3_MAX_RESOLUTIONS validation (P18 unbounded-autonomy guard).
# Default: 3. Clamped to 0..10. Non-numeric → warning + default.
gate3_max="${DEVBREW_GATE3_MAX_RESOLUTIONS:-3}"
if ! [[ "$gate3_max" =~ ^[0-9]+$ ]]; then
  echo "setup-qg: DEVBREW_GATE3_MAX_RESOLUTIONS='$gate3_max' is not numeric; defaulting to 3" >&2
  gate3_max=3
elif (( gate3_max > 10 )); then
  echo "setup-qg: DEVBREW_GATE3_MAX_RESOLUTIONS='$gate3_max' exceeds maximum 10; clamping to 10" >&2
  gate3_max=10
fi
```

Then add `gate3_max_resolutions: $gate3_max` to the state-file heredoc/printf that writes `pipeline.md`.

- [ ] **Step 2.4: Verify AC3**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
export CLAUDE_CODE_SESSION_ID=test-ac3-clamp
DEVBREW_GATE3_MAX_RESOLUTIONS=99 bash plugins/quality-gates/scripts/setup-qg.sh --ensure 2>&1 | tee /tmp/ac3.log
grep -q 'exceeds maximum 10' /tmp/ac3.log && echo "AC3 clamp warning PASS" || echo "AC3 clamp warning FAIL"
grep -q 'gate3_max_resolutions: 10' ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID/pipeline.md" \
  && echo "AC3 clamp value PASS" || echo "AC3 clamp value FAIL"

# Reset for non-numeric case
rm -rf ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID"
DEVBREW_GATE3_MAX_RESOLUTIONS=abc bash plugins/quality-gates/scripts/setup-qg.sh --ensure 2>&1 | tee /tmp/ac3b.log
grep -q 'is not numeric' /tmp/ac3b.log && echo "AC3 non-numeric warning PASS" || echo "AC3 non-numeric warning FAIL"
grep -q 'gate3_max_resolutions: 3' ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID/pipeline.md" \
  && echo "AC3 default value PASS" || echo "AC3 default value FAIL"

# Cleanup
rm -rf ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID"
unset CLAUDE_CODE_SESSION_ID DEVBREW_GATE3_MAX_RESOLUTIONS
```

All four PASS lines must print.

- [ ] **Step 2.5: Commit Task 2**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
git add plugins/quality-gates/scripts/setup-qg.sh
git commit -m "$(cat <<'EOF'
fix(quality-gates): setup-qg.sh — restore GATE3 clamp + drop Stop-hook wording

Findings resolved:
- C3: restore DEVBREW_GATE3_MAX_RESOLUTIONS validation block. Parse integer,
  clamp 0..10, default 3, write gate3_max_resolutions: field to state.
  Re-installs the P18 unbounded-autonomy guard removed in v1.32.0 Task 3.
- I3: remove "Stop hook-based" wording from header comment (line ~4) and
  --help text (lines ~95-96).

AC verified: AC3 (with DEVBREW_GATE3_MAX_RESOLUTIONS=99 and =abc).
Spec: docs/superpowers/specs/2026-05-27-qg-gate2-findings-fix-design.md §5.2

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: pre-pipeline-check.sh — C2

**Files:**
- Modify: `plugins/quality-gates/scripts/pre-pipeline-check.sh`

**Finding absorbed:** C2 (P2 → P3 race fix via session-id guard).

- [ ] **Step 3.1: Read pre-pipeline-check.sh, locate deletion block**

Read the script. Find the `rm -f "$SESSION_FILE" "$STATE_FILE"` line (around line 39 per spec §5.3) and the surrounding `branch_mismatch` logic.

- [ ] **Step 3.2: Add session-id guard before deletion**

Use Edit to wrap the deletion in a session-id check. Replace:

```bash
rm -f "$SESSION_FILE" "$STATE_FILE"
```

with:

```bash
# C2 fix: only delete state owned by a DIFFERENT session. Same-session
# pipeline.md is owned by the live pipeline (preflight runs after setup-qg
# created the file) and must not be deleted.
pipeline_session=""
if [[ -f "$SESSION_FILE" ]]; then
  pipeline_session=$(awk -F': *' '/^session_id:/ { print $2; exit }' "$SESSION_FILE" 2>/dev/null | tr -d '[:space:]')
fi
if [[ -n "$pipeline_session" && "$pipeline_session" == "${CLAUDE_CODE_SESSION_ID:-}" ]]; then
  echo "pre-pipeline-check: preserving session-owned state file" >&2
else
  rm -f "$SESSION_FILE" "$STATE_FILE"
fi
```

Adapt the variable names (`$SESSION_FILE` / `$STATE_FILE`) to whatever the script actually uses if different.

- [ ] **Step 3.3: Smoke-test the guard manually**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
export CLAUDE_CODE_SESSION_ID=test-c2-same
mkdir -p ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID"
cat > ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID/pipeline.md" <<EOF
---
session_id: $CLAUDE_CODE_SESSION_ID
branch: some-other-branch
---
EOF
# Same-session: file should survive (advisory printed)
bash plugins/quality-gates/scripts/pre-pipeline-check.sh 2>&1 | tee /tmp/c2-same.log
test -f ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID/pipeline.md" \
  && echo "C2 same-session preserved PASS" || echo "C2 same-session preserved FAIL"
grep -q 'preserving session-owned' /tmp/c2-same.log \
  && echo "C2 advisory PASS" || echo "C2 advisory FAIL"

# Cross-session: file should be deleted
sed -i.bak 's/^session_id:.*/session_id: different-session/' ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID/pipeline.md"
rm -f ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID/pipeline.md.bak"
bash plugins/quality-gates/scripts/pre-pipeline-check.sh >/dev/null 2>&1
test ! -f ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID/pipeline.md" \
  && echo "C2 cross-session deleted PASS" || echo "C2 cross-session deleted FAIL"

# Cleanup
rm -rf ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID"
unset CLAUDE_CODE_SESSION_ID
```

All three PASS lines must print. (Formal test `tests/test_pre_pipeline_check.sh` added in Task 9.)

- [ ] **Step 3.4: Commit Task 3**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
git add plugins/quality-gates/scripts/pre-pipeline-check.sh
git commit -m "$(cat <<'EOF'
fix(quality-gates): pre-pipeline-check — session-id guard against P2→P3 race

Finding resolved:
- C2: P2 (setup-qg --ensure) creates pipeline.md; P3 (pre-pipeline-check)
  was deleting it on branch-mismatch. Same-session pipeline files are
  owned by the live pipeline. Now: read session_id: from pipeline.md
  frontmatter; only delete if it does NOT match $CLAUDE_CODE_SESSION_ID.
  New stderr advisory: "pre-pipeline-check: preserving session-owned
  state file".

Smoke-tested manually (same-session preserved + cross-session deleted +
advisory emitted). Formal test_pre_pipeline_check.sh added in Task 9.
Spec: docs/superpowers/specs/2026-05-27-qg-gate2-findings-fix-design.md §5.3

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: session-start-advisor.py — I4 / I5 / LEGACY_V1_KEYS

**Files:**
- Modify: `plugins/quality-gates/hooks/session-start-advisor.py`

**Findings absorbed:** I4 (OSError swallow), I5 (JSONDecodeError swallow), LEGACY_V1_KEYS Medium (split consecutive_no_signal), invariant comment Medium.

- [ ] **Step 4.1: Read session-start-advisor.py around lines 40-140**

Read the file. Confirm Step 0.3 pre-condition (LEGACY_V1_KEYS line 43 has `"current" + "_gate:"` already split; literal `consecutive_no_signal:` still present).

- [ ] **Step 4.2: LEGACY_V1_KEYS split + invariant comment**

Use Edit on the LEGACY_V1_KEYS line. Replace:

```python
LEGACY_V1_KEYS = ("status:", "current" + "_gate:", "consecutive_no_signal:")
```

with:

```python
# Invariant: keys MUST use string concatenation to evade static grep
# against self-referential tokens. AC17 asserts both `"current" + "_gate:"`
# and `"consecutive_no" + "_signal:"` are present and the literal forms
# (`current_gate:`, `consecutive_no_signal:`) are absent.
LEGACY_V1_KEYS = ("status:", "current" + "_gate:", "consecutive_no" + "_signal:")
```

If pre-condition from Step 0.3 was violated (line was unrolled), apply the same Final form anyway. Note the deviation in Task 4 commit body.

- [ ] **Step 4.3: I5 — Replace JSONDecodeError swallow**

Find `_load_payload` function (around lines 100-110). Replace:

```python
    except json.JSONDecodeError:
        pass
```

with:

```python
    except json.JSONDecodeError as e:
        print(f"[qg-advisor] payload parse failed: {e}", file=sys.stderr)
```

Keep the surrounding `return {}` (empty-dict fallback) — read-only advisor must not crash SessionStart, but the diagnostic is now visible.

Confirm `import sys` is present at the top of the file. If not, add it.

- [ ] **Step 4.4: I4 — Replace OSError swallow in _emit_legacy_v1_advisory**

Find `_emit_legacy_v1_advisory` function (around lines 120-140). Replace:

```python
    except OSError:
        pass
```

with:

```python
    except OSError as e:
        print(f"[qg-advisor] legacy-v1 scan skipped: {e}", file=sys.stderr)
```

- [ ] **Step 4.5: Verify Task 4 ACs**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
FILE=plugins/quality-gates/hooks/session-start-advisor.py
# AC9 (I4)
grep -qE "print.*qg-advisor.*legacy-v1" "$FILE" && echo "AC9 PASS" || echo "AC9 FAIL"
# AC10 (I5)
grep -qE "payload parse failed" "$FILE" && echo "AC10 PASS" || echo "AC10 FAIL"
# AC17 (LEGACY_V1_KEYS evasion + presence)
test "$(grep -cE 'consecutive_no_signal:|current_gate:' "$FILE")" -eq 0 \
  && echo "AC17 literal-absent PASS" || echo "AC17 literal-absent FAIL"
grep -qF '"current" + "_gate:"' "$FILE" \
  && grep -qF '"consecutive_no" + "_signal:"' "$FILE" \
  && echo "AC17 both-splits-present PASS" || echo "AC17 both-splits-present FAIL"
# Syntax check (advisor must still import cleanly)
python3 -c "import ast; ast.parse(open('$FILE').read())" && echo "AC4-syntax PASS" || echo "AC4-syntax FAIL"
```

All five must PASS.

- [ ] **Step 4.6: Commit Task 4**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
git add plugins/quality-gates/hooks/session-start-advisor.py
git commit -m "$(cat <<'EOF'
fix(quality-gates): session-start-advisor — diagnostic errors + LEGACY_V1_KEYS

Findings resolved:
- I4: replace bare `except OSError: pass` in _emit_legacy_v1_advisory with
  diagnostic stderr line. Silent failure → diagnosable failure.
- I5: replace bare `except json.JSONDecodeError: pass` in _load_payload
  with diagnostic stderr line. Empty-dict fallback retained (advisor must
  not crash SessionStart) but failure mode is now visible.
- LEGACY_V1_KEYS half-applied fix: split `consecutive_no_signal:` into
  string-concat form. v1.32.0 only split `current_gate:`; this completes
  the static-grep evasion.
- LEGACY_V1_KEYS invariant comment: one-line `# Invariant:` documenting
  why string-concat is used (AC17 regression target).

ACs verified: AC9, AC10, AC17 (literal-absent + both-splits-present).
Spec: docs/superpowers/specs/2026-05-27-qg-gate2-findings-fix-design.md §5.4

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: README.md — I8

**Files:**
- Modify: `plugins/quality-gates/README.md`

**Finding absorbed:** I8 (remove v1.5.0 Stop-hook ASCII diagram).

- [ ] **Step 5.1: Read README.md around lines 140-180**

Read the file. Find the v1.5.0 Stop-hook diagram block (around lines 149-155 per spec §5.5) and the v1.32.0 AskUserQuestion diagram (around line 157+).

- [ ] **Step 5.2: Delete the Stop-hook diagram and any cross-references**

Use Edit to delete the entire v1.5.0 ASCII block including any heading and surrounding prose that explicitly references it. Also scan the surrounding prose (Read 10 lines before and after) for "Stop hook" cross-references and rephrase or delete them.

- [ ] **Step 5.3: Verify AC12**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
test "$(grep -cE 'Stop hook' plugins/quality-gates/README.md)" -eq 0 \
  && echo "AC12 PASS" || echo "AC12 FAIL: $(grep -nE 'Stop hook' plugins/quality-gates/README.md)"
```

If FAIL, the grep output lists remaining occurrences. Edit each one until count is 0.

- [ ] **Step 5.4: Commit Task 5**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
git add plugins/quality-gates/README.md
git commit -m "$(cat <<'EOF'
fix(quality-gates): README — remove v1.5.0 Stop-hook diagram

Finding resolved:
- I8: README had v1.5.0 Stop-hook ASCII diagram coexisting with the
  v1.32.0 AskUserQuestion diagram. v1.5.0 diagram removed entirely;
  v1.32.0 diagram is now the only state diagram in the doc. Surrounding
  prose cross-references to "Stop hook" also removed.

AC verified: AC12 (grep -c 'Stop hook' returns 0).
Spec: docs/superpowers/specs/2026-05-27-qg-gate2-findings-fix-design.md §5.5

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: tests/ surgical edits — I1 / I2 / I9 / V8 split / test_branch_worktree comments

**Files:**
- Modify: `plugins/quality-gates/tests/test_kill_switches.py`
- Modify: `plugins/quality-gates/tests/test_worktree.sh`
- Modify: `plugins/quality-gates/tests/e2e-scenarios.md`
- Modify: `plugins/quality-gates/tests/test_session_start_advisor_v2.sh` (V8 split)
- Modify: `plugins/quality-gates/tests/test_branch_worktree.sh` (comment-only)

**Findings absorbed:** I1, I2, I9, V8 split (Medium), test_branch_worktree drift (Medium).

This task is surgical edits across multiple test files. Each is small. Group into one commit because they're all "test-drift fixes".

- [ ] **Step 6.1: I1 — test_kill_switches.py stderr fix**

Read `plugins/quality-gates/tests/test_kill_switches.py` around lines 270-285. Find the advisor sanity assertion using `result.stdout`. Use Edit to change `result.stdout` → `result.stderr` (advisor writes to stderr in v1.32.0).

If the test uses `subprocess.run(..., capture_output=True)`, both `stdout` and `stderr` are captured — only the assertion target changes.

- [ ] **Step 6.2: I2 — test_worktree.sh remove project_dir assertions**

Read `tests/test_worktree.sh` around lines 170-235. Find T5 and T9 cases that assert removed `project_dir:` state-file field. Use Edit to delete those specific assertion lines (the surrounding test cases stay; only the lines asserting the removed schema field are removed).

- [ ] **Step 6.3: I9 — e2e-scenarios.md update v1.5.0 references**

Read `tests/e2e-scenarios.md` around lines 85-300. Lines noted in spec: 88, 141, 242, 290. For each:

- Replace `stop-hook.py` references with prose describing AskUserQuestion-driven iteration.
- Replace `<qg-signal>` references with prose describing direct skill output.
- Replace `gate2_repeat_detected` with prose describing Gate 2 iter cap.

Use Edit per line; the actual replacement prose depends on local context — keep the surrounding scenario intent intact.

- [ ] **Step 6.4: V8 split in test_session_start_advisor_v2.sh**

Read `tests/test_session_start_advisor_v2.sh`. Find the V8 test case. Use Edit to split into V8a and V8b:

- V8a: per-session fixture only (`.claude/quality-gates/<session-id>/pipeline.md` shape).
- V8b: flat-legacy fixture only (`.claude/quality-gates/pipeline.md` at the root, no session subdir).

Each runs independently so a branch failure is identifiable. Reuse the original V8 body; split into two parametric helper invocations.

- [ ] **Step 6.5: test_branch_worktree.sh comment drift**

Read `tests/test_branch_worktree.sh` lines 110-130. Lines 116 and 122 reference "stop-hook simulation" in comments. Use Edit to rewrite as "AskUserQuestion simulation" or delete the obsolete reference.

- [ ] **Step 6.6: Verify Task 6 ACs**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
# AC7 (I1)
python3 plugins/quality-gates/tests/test_kill_switches.py && echo "AC7 PASS" || echo "AC7 FAIL"
# AC8 (I2)
bash plugins/quality-gates/tests/test_worktree.sh && echo "AC8 PASS" || echo "AC8 FAIL"
# AC13 (I9)
test "$(grep -cE 'stop-hook\.py|<qg-signal|gate2_repeat_detected' plugins/quality-gates/tests/e2e-scenarios.md)" -eq 0 \
  && echo "AC13 PASS" || echo "AC13 FAIL"
# V8 split present
grep -qE '^V8a|test_V8a|case_V8a' plugins/quality-gates/tests/test_session_start_advisor_v2.sh \
  && grep -qE '^V8b|test_V8b|case_V8b' plugins/quality-gates/tests/test_session_start_advisor_v2.sh \
  && echo "V8 split PASS" || echo "V8 split FAIL"
```

All four PASS.

- [ ] **Step 6.7: Commit Task 6**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
git add plugins/quality-gates/tests/test_kill_switches.py \
        plugins/quality-gates/tests/test_worktree.sh \
        plugins/quality-gates/tests/e2e-scenarios.md \
        plugins/quality-gates/tests/test_session_start_advisor_v2.sh \
        plugins/quality-gates/tests/test_branch_worktree.sh
git commit -m "$(cat <<'EOF'
fix(quality-gates): tests — surgical drift fixes (I1/I2/I9 + V8 split)

Findings resolved:
- I1: test_kill_switches.py advisor sanity assertion now checks stderr
  (v1.32.0 advisor writes to stderr, not stdout).
- I2: test_worktree.sh T5 + T9 assertions on removed project_dir: schema
  field removed; worktree-mode session-folder layout assertions retained.
- I9: tests/e2e-scenarios.md lines 88/141/242/290 — replace stop-hook.py,
  <qg-signal>, gate2_repeat_detected references with v1.32.0 equivalents.
- V8 split (Medium): test_session_start_advisor_v2.sh V8 split into V8a
  (per-session fixture) and V8b (flat-legacy) so branch failures are
  independently identifiable.
- test_branch_worktree.sh comment drift (Medium): lines 116/122 "stop-hook
  simulation" → "AskUserQuestion simulation".

ACs verified: AC7, AC8, AC13, V8 split.
Spec: docs/superpowers/specs/2026-05-27-qg-gate2-findings-fix-design.md §5.6.3, §5.6.4, §5.6.6, §5.6.8

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: tests/ rewrites and deletes — C4 / C5 / I12

**Files:**
- Modify: `plugins/quality-gates/tests/test_setup_qg.sh` (REWRITE)
- Delete: `plugins/quality-gates/tests/test_session_start_advisor.py`
- Modify: `plugins/quality-gates/tests/test_readme_state_diagram_complete.sh` (run + fix)

**Findings absorbed:** C4, C5, I12.

- [ ] **Step 7.1: C4 — Rewrite test_setup_qg.sh for v1.32.1 schema**

Read the current `tests/test_setup_qg.sh`. Identify the 9 assertions that target removed keys (`gate3_resolution_iter:`, `max_gate3_resolutions:`, `project_dir:`) and removed stderr warnings.

Use Write to replace the file with a v1.32.1-targeted version. Template:

```bash
#!/usr/bin/env bash
# test_setup_qg.sh — verify setup-qg.sh --ensure behavior against v1.32.1 state schema.
# Replaces v1.32.0-era version that asserted removed schema keys.

set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd -- "$PLUGIN_ROOT/../.." && pwd)"

fail=0
trap 'echo "FAIL: $fail assertion(s) failed"; exit 1' ERR

assert() {
  local label="$1" cmd="$2"
  if eval "$cmd"; then echo "PASS: $label"; else echo "FAIL: $label"; fail=$((fail+1)); fi
}

cd "$REPO_ROOT"

# Case 1: fresh state creation
export CLAUDE_CODE_SESSION_ID="test-setup-1-$$"
rm -rf ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID"
bash "$PLUGIN_ROOT/scripts/setup-qg.sh" --ensure >/dev/null 2>&1
assert "fresh state file created" "test -f .claude/quality-gates/$CLAUDE_CODE_SESSION_ID/pipeline.md"
assert "state contains session_id" "grep -q 'session_id:' .claude/quality-gates/$CLAUDE_CODE_SESSION_ID/pipeline.md"
assert "state contains gate3_max_resolutions (default 3)" "grep -q 'gate3_max_resolutions: 3' .claude/quality-gates/$CLAUDE_CODE_SESSION_ID/pipeline.md"

# Case 2: --ensure idempotency (second call is no-op)
mtime1=$(stat -f %m ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID/pipeline.md" 2>/dev/null || stat -c %Y ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID/pipeline.md")
sleep 1
bash "$PLUGIN_ROOT/scripts/setup-qg.sh" --ensure >/dev/null 2>&1
mtime2=$(stat -f %m ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID/pipeline.md" 2>/dev/null || stat -c %Y ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID/pipeline.md")
assert "--ensure idempotent (no rewrite)" "[ \"$mtime1\" = \"$mtime2\" ]"

# Case 3: clamp value
rm -rf ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID"
DEVBREW_GATE3_MAX_RESOLUTIONS=99 bash "$PLUGIN_ROOT/scripts/setup-qg.sh" --ensure >/dev/null 2>&1
assert "DEVBREW_GATE3_MAX_RESOLUTIONS=99 clamped to 10" "grep -q 'gate3_max_resolutions: 10' .claude/quality-gates/$CLAUDE_CODE_SESSION_ID/pipeline.md"

# Case 4: per-session folder layout
rm -rf ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID"
export CLAUDE_CODE_SESSION_ID="test-setup-isolation-$$"
bash "$PLUGIN_ROOT/scripts/setup-qg.sh" --ensure >/dev/null 2>&1
assert "session-isolated folder" "test -d .claude/quality-gates/$CLAUDE_CODE_SESSION_ID"

# Cleanup
rm -rf ".claude/quality-gates/test-setup-1-$$" ".claude/quality-gates/test-setup-isolation-$$"

trap - ERR
echo "test_setup_qg: all assertions passed"
exit 0
```

Adjust the script paths if the actual `setup-qg.sh` writes state to a different path. The four asserted cases cover §5.6.1's required new assertions (--ensure idempotency, clamp value, per-session layout, session-id binding).

- [ ] **Step 7.2: C5 — Delete v1 test_session_start_advisor.py**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
git rm plugins/quality-gates/tests/test_session_start_advisor.py
```

- [ ] **Step 7.3: I12 — Run test_readme_state_diagram_complete.sh; fix if drift**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
bash plugins/quality-gates/tests/test_readme_state_diagram_complete.sh && echo "I12 already passing" || echo "I12 needs fix"
```

If failing, Read the test and update its assertion list to match the v1.32.1 README (post-Task 5 I8 fix). The test typically lists expected diagram nodes; ensure that list matches the only remaining diagram in README.md.

- [ ] **Step 7.4: Verify Task 7 ACs**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
# AC4 (C4)
bash plugins/quality-gates/tests/test_setup_qg.sh && echo "AC4 PASS" || echo "AC4 FAIL"
# AC5 (C5)
test ! -f plugins/quality-gates/tests/test_session_start_advisor.py \
  && echo "AC5 PASS" || echo "AC5 FAIL"
# AC15 (I12)
bash plugins/quality-gates/tests/test_readme_state_diagram_complete.sh \
  && echo "AC15 PASS" || echo "AC15 FAIL"
```

All three PASS.

- [ ] **Step 7.5: Commit Task 7**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
git add plugins/quality-gates/tests/test_setup_qg.sh \
        plugins/quality-gates/tests/test_readme_state_diagram_complete.sh
git add -u plugins/quality-gates/tests/test_session_start_advisor.py
git commit -m "$(cat <<'EOF'
fix(quality-gates): tests — rewrite test_setup_qg + delete v1 advisor test

Findings resolved:
- C4: test_setup_qg.sh rewritten for v1.32.1 minimal schema. Removed 9
  stale assertions (gate3_resolution_iter:, max_gate3_resolutions:,
  project_dir:, removed stderr warnings). New assertions: --ensure
  idempotency, gate3_max_resolutions clamp value, per-session folder
  layout, session-id binding.
- C5: v1 test_session_start_advisor.py deleted. v2 shell wrapper
  test_session_start_advisor_v2.sh is the active test (5/12 v1
  assertions were broken against v1.32.0 advisor).
- I12: test_readme_state_diagram_complete.sh updated (or no-op if
  already passing) to match v1.32.1 README post-I8 diagram removal.

ACs verified: AC4, AC5, AC15.
Spec: docs/superpowers/specs/2026-05-27-qg-gate2-findings-fix-design.md §5.6.1, §5.6.2, §5.6.7

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: tests/harness/ NEW protocol-shape test + V7 atomic delete — C6

**Files:**
- Create: `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
- Modify: `plugins/quality-gates/tests/test_skill_orchestration.sh` (remove V7 case)

**Finding absorbed:** C6 (with V7 deletion atomic per spec §5.1).

- [ ] **Step 8.1: Create harness directory if missing**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
mkdir -p plugins/quality-gates/tests/harness
```

- [ ] **Step 8.2: Write test_skill_orchestration_behavior.sh**

Use Write to create `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration/plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` with:

```bash
#!/usr/bin/env bash
# test_skill_orchestration_behavior.sh — protocol-shape test for SKILL.md.
# Asserts the prompt-defined orchestration protocol exists in SKILL.md with
# expected ordering and structural relationships. Does NOT execute SKILL.md
# at runtime. Replaces the V7 tautological grep test removed atomically.
# See spec §5.6.9 for the "protocol-shape" definition.

set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILL_MD="$(cd -- "$SCRIPT_DIR/../.." && pwd)/skills/quality-pipeline/SKILL.md"

test -f "$SKILL_MD" || { echo "FAIL: SKILL.md not found at $SKILL_MD"; exit 1; }

fail=0
assert_line() {
  local label="$1" pattern="$2"
  local line
  line=$(awk -v p="$pattern" '$0 ~ p { print NR; exit }' "$SKILL_MD")
  if [[ -n "$line" ]]; then echo "PASS: $label (line $line)"; echo "$line"
  else echo "FAIL: $label (pattern not found: $pattern)"; fail=$((fail+1)); echo "0"; fi
}

assert_order() {
  local label="$1" earlier="$2" later="$3"
  if [[ "$earlier" -gt 0 && "$later" -gt 0 && "$earlier" -lt "$later" ]]; then
    echo "PASS: $label (line $earlier < line $later)"
  else
    echo "FAIL: $label (earlier=$earlier later=$later)"
    fail=$((fail+1))
  fi
}

assert_proximity() {
  local label="$1" a="$2" b="$3" within="$4"
  if [[ "$a" -gt 0 && "$b" -gt 0 ]]; then
    local diff=$((a > b ? a - b : b - a))
    if [[ "$diff" -le "$within" ]]; then
      echo "PASS: $label (lines $a, $b within $within)"
    else
      echo "FAIL: $label (lines $a, $b distance $diff > $within)"
      fail=$((fail+1))
    fi
  else
    echo "FAIL: $label (a=$a b=$b — missing markers)"
    fail=$((fail+1))
  fi
}

# Gate dispatch lines (capture line numbers)
gate1_line=$(assert_line "Gate 1 plan-verifier dispatch" 'subagent_type.*plan-verifier' | tail -n1)
gate2_line=$(assert_line "Gate 2 adversarial dispatch" 'subagent_type.*adversarial' | tail -n1)
gate3_line=$(assert_line "Gate 3 runtime-verifier dispatch" 'subagent_type.*runtime-verifier' | tail -n1)

# Ordering: Gate 1 < Gate 2 < Gate 3
assert_order "Gate 1 precedes Gate 2" "$gate1_line" "$gate2_line"
assert_order "Gate 2 precedes Gate 3" "$gate2_line" "$gate3_line"

# Four reviewer agents in Gate 2 fan-out (consistency with C1 / AC1)
for agent in adversarial test-scope-validator security-reviewer runtime-verifier; do
  grep -qE "subagent_type[^\"]*\"$agent" "$SKILL_MD" \
    && echo "PASS: $agent dispatch present" \
    || { echo "FAIL: $agent dispatch missing"; fail=$((fail+1)); }
done

# Gate 2 iter cap proximity to AskUserQuestion section
askuser_line=$(assert_line "AskUserQuestion decision block" 'AskUserQuestion' | tail -n1)
itercap_line=$(assert_line "Gate 2 iter cap reference" 'iter.*cap|iteration.*cap|max.*iteration' | tail -n1)
assert_proximity "iter cap near AskUserQuestion" "$askuser_line" "$itercap_line" 50

# DEVBREW_GATE3_MAX_RESOLUTIONS in Gate 3 dispatch section
gate3_max_line=$(assert_line "DEVBREW_GATE3_MAX_RESOLUTIONS reference" 'DEVBREW_GATE3_MAX_RESOLUTIONS' | tail -n1)
assert_proximity "GATE3_MAX_RESOLUTIONS near Gate 3 dispatch" "$gate3_line" "$gate3_max_line" 100

# Retry path (I6) error-handling AskUserQuestion between Gate 2 and Gate 3
retry_line=$(assert_line "Retry error-handling AskUserQuestion" 'Retry.*AskUserQuestion|AskUserQuestion.*Retry' | tail -n1)
if [[ "$retry_line" -gt 0 && "$retry_line" -gt "$gate2_line" && "$retry_line" -lt "$gate3_line" ]]; then
  echo "PASS: Retry block between Gate 2 and Gate 3"
else
  echo "FAIL: Retry block not between Gate 2 ($gate2_line) and Gate 3 ($gate3_line); found at $retry_line"
  fail=$((fail+1))
fi

if [[ "$fail" -eq 0 ]]; then
  echo "test_skill_orchestration_behavior: all protocol-shape assertions PASS"
  exit 0
else
  echo "test_skill_orchestration_behavior: $fail assertion(s) FAILED"
  exit 1
fi
```

```bash
chmod +x /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration/plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
```

- [ ] **Step 8.3: Run the new test (expect PASS after Task 1's SKILL.md edits)**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
```

Expected: exit 0. If FAIL, the assertion message says which marker is missing. Either:
- Fix SKILL.md (Task 1 left something out — go back to Task 1 and Edit), OR
- Adjust the assertion's grep pattern if SKILL.md uses different wording for the same concept.

**Atomic dependency**: V7 deletion in Step 8.4 cannot proceed until this test PASSes.

- [ ] **Step 8.4: Delete V7 case from test_skill_orchestration.sh (atomic with Step 8.3)**

Read `tests/test_skill_orchestration.sh`. Find the V7 test case (matches the anchored grep from AC6: line-start, optional `function`/`test_` prefix, `V7`, then `[ { (` or whitespace).

Use Edit to delete the entire V7 function/case block. If V7 has a wrapper invocation elsewhere in the file (e.g. a `run_test V7` call), delete that too.

- [ ] **Step 8.5: Verify AC6**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
# AC6 new test passes
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh \
  && echo "AC6 new test PASS" || echo "AC6 new test FAIL"
# AC6 V7 anchored deletion
test "$(grep -cE '^[[:space:]]*(function[[:space:]]+)?(test_)?V7[[:space:]({]' plugins/quality-gates/tests/test_skill_orchestration.sh)" -eq 0 \
  && echo "AC6 V7 deleted PASS" || echo "AC6 V7 deleted FAIL"
```

Both PASS.

- [ ] **Step 8.6: Commit Task 8**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
git add plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh \
        plugins/quality-gates/tests/test_skill_orchestration.sh
git commit -m "$(cat <<'EOF'
fix(quality-gates): tests — protocol-shape harness + V7 atomic delete (C6)

Finding resolved:
- C6: new tests/harness/test_skill_orchestration_behavior.sh asserts
  SKILL.md orchestration protocol-shape (ordering + proximity + section
  membership). Replaces V7's tautological substring grep (which was
  `grep -c 'PASS'` returning 0 — always passed).
  Coverage: Gate 1 → 2 → 3 ordering, 4 reviewer agents present in Gate 2
  fan-out, iter cap near AskUserQuestion section, GATE3_MAX_RESOLUTIONS
  in Gate 3 dispatch, Retry block between Gate 2 and Gate 3.
- V7 atomic delete: V7 case removed from tests/test_skill_orchestration.sh
  in the same commit as the new test (spec §5.1 C6 atomicity note).
  Anchored grep AC6 verifies V7 definitions absent.

ACs verified: AC6 (new test + V7 deletion).
Spec: docs/superpowers/specs/2026-05-27-qg-gate2-findings-fix-design.md §5.6.9, §5.1

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Medium cluster — cancel-qg helper + new pre_pipeline_check test + kill switch test + V2b uniqueness + LEGACY regression

**Files:**
- Create: `plugins/quality-gates/scripts/cancel-qg-core.sh`
- Modify: `plugins/quality-gates/commands/cancel-qg.md`
- Modify: `plugins/quality-gates/tests/test_cancel_qg.sh`
- Create: `plugins/quality-gates/tests/test_pre_pipeline_check.sh`
- Modify: `plugins/quality-gates/tests/test_kill_switches.py` (add SKILL kill switch case)
- Modify: `plugins/quality-gates/tests/test_skill_orchestration.sh` (V2b uniqueness)
- Modify: `plugins/quality-gates/tests/test_session_start_advisor_v2.sh` (LEGACY regression assertion)

**Findings absorbed:** TQ-2 (cancel-qg helper extract), C2 test (new file), kill switch (Medium), V2b uniqueness (Medium), LEGACY_V1_KEYS regression test (Medium 5.6.5).

This task is the largest. Steps 9.1-9.5 are independent; each ends with a verification.

- [ ] **Step 9.1: TQ-2 — Extract cancel-qg-core.sh helper**

Read `plugins/quality-gates/commands/cancel-qg.md`. Identify the inline bash block that performs cleanup.

Create `plugins/quality-gates/scripts/cancel-qg-core.sh`:

```bash
#!/usr/bin/env bash
# cancel-qg-core.sh — pipeline state cleanup helper.
# Used by commands/cancel-qg.md and tests/test_cancel_qg.sh so both
# exercise identical code. See spec §5.8 TQ-2.

set -euo pipefail

session_id=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-id) session_id="$2"; shift 2 ;;
    -h|--help) echo "Usage: cancel-qg-core.sh [--session-id <id>]"; exit 0 ;;
    *) echo "cancel-qg-core: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$session_id" ]]; then
  session_id="${CLAUDE_CODE_SESSION_ID:-}"
fi
if [[ -z "$session_id" ]]; then
  echo "cancel-qg-core: no --session-id and CLAUDE_CODE_SESSION_ID unset" >&2
  exit 1
fi

target_dir=".claude/quality-gates/$session_id"
if [[ -d "$target_dir" ]]; then
  rm -rf "$target_dir"
  echo "cancel-qg-core: removed $target_dir"
else
  echo "cancel-qg-core: no state at $target_dir (no-op)"
fi
```

```bash
chmod +x /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration/plugins/quality-gates/scripts/cancel-qg-core.sh
```

Use Edit on `plugins/quality-gates/commands/cancel-qg.md` to replace the inline bash block with:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/cancel-qg-core.sh"
```

(The original inline logic is now in the helper.)

Use Edit on `plugins/quality-gates/tests/test_cancel_qg.sh` to invoke the same helper instead of duplicating the inline logic.

- [ ] **Step 9.2: Create test_pre_pipeline_check.sh (C2 formal test)**

Use Write to create `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration/plugins/quality-gates/tests/test_pre_pipeline_check.sh`:

```bash
#!/usr/bin/env bash
# test_pre_pipeline_check.sh — C2 race-fix coverage + advisory message.

set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd -- "$PLUGIN_ROOT/../.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/pre-pipeline-check.sh"

fail=0

case_fresh_start() {
  export CLAUDE_CODE_SESSION_ID="test-pre-fresh-$$"
  rm -rf "$REPO_ROOT/.claude/quality-gates/$CLAUDE_CODE_SESSION_ID"
  cd "$REPO_ROOT"
  bash "$SCRIPT" >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then echo "PASS: case_fresh_start"; else echo "FAIL: case_fresh_start"; fail=$((fail+1)); fi
  unset CLAUDE_CODE_SESSION_ID
}

case_same_session_preserved() {
  export CLAUDE_CODE_SESSION_ID="test-pre-same-$$"
  local dir="$REPO_ROOT/.claude/quality-gates/$CLAUDE_CODE_SESSION_ID"
  mkdir -p "$dir"
  cat > "$dir/pipeline.md" <<EOF
---
session_id: $CLAUDE_CODE_SESSION_ID
branch: stale-branch
---
EOF
  cd "$REPO_ROOT"
  bash "$SCRIPT" >/dev/null 2>&1
  if [[ -f "$dir/pipeline.md" ]]; then echo "PASS: case_same_session_preserved"
  else echo "FAIL: case_same_session_preserved (file was deleted)"; fail=$((fail+1)); fi
  rm -rf "$dir"
  unset CLAUDE_CODE_SESSION_ID
}

case_cross_session_deleted() {
  export CLAUDE_CODE_SESSION_ID="test-pre-cross-$$"
  local dir="$REPO_ROOT/.claude/quality-gates/$CLAUDE_CODE_SESSION_ID"
  mkdir -p "$dir"
  cat > "$dir/pipeline.md" <<EOF
---
session_id: a-different-session
branch: stale-branch
---
EOF
  cd "$REPO_ROOT"
  bash "$SCRIPT" >/dev/null 2>&1
  if [[ ! -f "$dir/pipeline.md" ]]; then echo "PASS: case_cross_session_deleted"
  else echo "FAIL: case_cross_session_deleted (file survived)"; fail=$((fail+1)); fi
  rm -rf "$dir"
  unset CLAUDE_CODE_SESSION_ID
}

case_advisory_emitted() {
  export CLAUDE_CODE_SESSION_ID="test-pre-advisory-$$"
  local dir="$REPO_ROOT/.claude/quality-gates/$CLAUDE_CODE_SESSION_ID"
  mkdir -p "$dir"
  cat > "$dir/pipeline.md" <<EOF
---
session_id: $CLAUDE_CODE_SESSION_ID
branch: stale-branch
---
EOF
  cd "$REPO_ROOT"
  local err
  err=$(bash "$SCRIPT" 2>&1 >/dev/null)
  if echo "$err" | grep -q 'preserving session-owned state file'; then
    echo "PASS: case_advisory_emitted"
  else
    echo "FAIL: case_advisory_emitted (stderr: $err)"; fail=$((fail+1))
  fi
  rm -rf "$dir"
  unset CLAUDE_CODE_SESSION_ID
}

case_fresh_start
case_same_session_preserved
case_cross_session_deleted
case_advisory_emitted

if [[ "$fail" -eq 0 ]]; then
  echo "test_pre_pipeline_check: all cases PASS"
  exit 0
else
  echo "test_pre_pipeline_check: $fail case(s) FAILED"
  exit 1
fi
```

```bash
chmod +x /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration/plugins/quality-gates/tests/test_pre_pipeline_check.sh
bash /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration/plugins/quality-gates/tests/test_pre_pipeline_check.sh
```

Expected: all 4 cases PASS.

- [ ] **Step 9.3: SKILL kill switch test (Medium)**

Read `plugins/quality-gates/tests/test_kill_switches.py`. Add a new test method that asserts `DEVBREW_DISABLE_QUALITY_GATES=1` causes the SKILL preflight P1 to exit with the documented message.

Append a method like (adapt to the file's existing test class structure):

```python
def test_skill_disable_kill_switch(self):
    """DEVBREW_DISABLE_QUALITY_GATES=1 must short-circuit SKILL preflight."""
    env = {**os.environ, "DEVBREW_DISABLE_QUALITY_GATES": "1"}
    # SKILL is markdown — we test the documented behavior via the
    # preflight script that the SKILL invokes (setup-qg.sh respects the
    # disable flag).
    result = subprocess.run(
        ["bash", "plugins/quality-gates/scripts/setup-qg.sh", "--ensure"],
        env=env, capture_output=True, text=True, timeout=10
    )
    self.assertNotEqual(result.returncode, 0,
        "DEVBREW_DISABLE_QUALITY_GATES=1 should cause non-zero exit")
    combined = result.stdout + result.stderr
    self.assertRegex(combined, r"DEVBREW_DISABLE_QUALITY_GATES|disabled",
        "kill switch message should mention DEVBREW_DISABLE_QUALITY_GATES or 'disabled'")
```

(If the test file uses pytest style, write it as a function with `def test_skill_disable_kill_switch():` instead.)

If `setup-qg.sh` doesn't currently honor `DEVBREW_DISABLE_QUALITY_GATES`, this exposes a gap. In that case, also add to `setup-qg.sh` (Task 2 edit, but defer to a follow-up note — don't expand Task 2 retroactively):

```bash
if [[ "${DEVBREW_DISABLE_QUALITY_GATES:-}" == "1" ]]; then
  echo "setup-qg: DEVBREW_DISABLE_QUALITY_GATES=1; skipping pipeline state setup" >&2
  exit 1
fi
```

Add this at the very top of the script's main flow.

- [ ] **Step 9.4: V2b uniqueness (Medium)**

Read `plugins/quality-gates/tests/test_skill_orchestration.sh`. Find V2b. If it currently uses `grep -q 'findings remain' SKILL.md`, change to:

```bash
test "$(grep -c 'findings remain' "$SKILL_MD")" -eq 1 \
  && echo "PASS: V2b uniqueness" \
  || { echo "FAIL: V2b uniqueness"; fail=$((fail+1)); }
```

This asserts the marker is present **exactly once** (AC6 anchor uniqueness from spec §5.8).

- [ ] **Step 9.5: LEGACY_V1_KEYS regression assertion (Medium 5.6.5)**

Read `plugins/quality-gates/tests/test_session_start_advisor_v2.sh`. Add a new case that verifies all three legacy tokens (`status:`, `current_gate:`, `consecutive_no_signal:`) trigger the legacy-v1 advisory. Use file fixtures (write a fake state file containing each token in turn, invoke the advisor, assert the advisory line appears in stderr):

```bash
case_legacy_v1_keys_regression() {
  local tmp="$(mktemp -d)"
  trap "rm -rf '$tmp'" RETURN
  local cases=("status:" "current_gate:" "consecutive_no_signal:")
  for key in "${cases[@]}"; do
    echo "$key value" > "$tmp/fake-state.md"
    # Invoke advisor against this fixture. Adapt the invocation pattern
    # to whatever the existing V8a/V8b cases do.
    local err
    err=$(QG_STATE_FIXTURE="$tmp/fake-state.md" \
          python3 "$PLUGIN_ROOT/hooks/session-start-advisor.py" </dev/null 2>&1 >/dev/null) || true
    if echo "$err" | grep -q 'legacy-v1\|v1 state'; then
      echo "PASS: LEGACY_V1_KEYS triggers for '$key'"
    else
      echo "FAIL: LEGACY_V1_KEYS missed '$key' (stderr: $err)"
      fail=$((fail+1))
    fi
  done
}
case_legacy_v1_keys_regression
```

(Adapt invocation to how the advisor reads fixtures — if it doesn't take an env var, place fixture file at the path the advisor scans.)

- [ ] **Step 9.6: Verify Task 9 ACs**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
# AC16 — V2b uniqueness, pre_pipeline_check, V8a/V8b + LEGACY regression
bash plugins/quality-gates/tests/test_skill_orchestration.sh && echo "AC16 V2b PASS" || echo "AC16 V2b FAIL"
bash plugins/quality-gates/tests/test_pre_pipeline_check.sh && echo "AC16 pre_pipeline_check PASS" || echo "AC16 pre_pipeline_check FAIL"
bash plugins/quality-gates/tests/test_session_start_advisor_v2.sh && echo "AC16 advisor_v2 PASS" || echo "AC16 advisor_v2 FAIL"
# AC18 — cancel-qg-core helper
test -x plugins/quality-gates/scripts/cancel-qg-core.sh && echo "AC18 helper exists+exec PASS" || echo "AC18 helper exists+exec FAIL"
grep -q cancel-qg-core.sh plugins/quality-gates/commands/cancel-qg.md \
  && grep -q cancel-qg-core.sh plugins/quality-gates/tests/test_cancel_qg.sh \
  && echo "AC18 references PASS" || echo "AC18 references FAIL"
bash plugins/quality-gates/tests/test_cancel_qg.sh && echo "AC18 test PASS" || echo "AC18 test FAIL"
# Kill switch
python3 plugins/quality-gates/tests/test_kill_switches.py && echo "kill switch tests PASS" || echo "kill switch tests FAIL"
```

All must PASS.

- [ ] **Step 9.7: Commit Task 9**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
git add plugins/quality-gates/scripts/cancel-qg-core.sh \
        plugins/quality-gates/commands/cancel-qg.md \
        plugins/quality-gates/tests/test_cancel_qg.sh \
        plugins/quality-gates/tests/test_pre_pipeline_check.sh \
        plugins/quality-gates/tests/test_kill_switches.py \
        plugins/quality-gates/tests/test_skill_orchestration.sh \
        plugins/quality-gates/tests/test_session_start_advisor_v2.sh \
        plugins/quality-gates/scripts/setup-qg.sh
git commit -m "$(cat <<'EOF'
fix(quality-gates): Medium cluster — helper extract + 3 new test cases

Findings resolved (Medium tier):
- TQ-2: cancel-qg-core.sh extracted from inline shell in commands/cancel-qg.md.
  Both the command and tests/test_cancel_qg.sh source the helper, eliminating
  divergence. Interface: cancel-qg-core.sh [--session-id <id>].
- Medium (pre_pipeline_check direct tests): new tests/test_pre_pipeline_check.sh
  covering case_fresh_start + case_same_session_preserved (C2) +
  case_cross_session_deleted + case_advisory_emitted (stderr).
- Medium (SKILL kill switch): test_kill_switches.py asserts
  DEVBREW_DISABLE_QUALITY_GATES=1 short-circuits preflight. setup-qg.sh
  also gains the kill-switch honor (if not already present).
- Medium (V2b uniqueness): test_skill_orchestration.sh V2b changed from
  `grep -q` to `grep -c == 1` (anchors AC6 marker uniqueness).
- Medium 5.6.5 (LEGACY_V1_KEYS regression): test_session_start_advisor_v2.sh
  asserts all three legacy tokens trigger the advisory (fixture-based,
  not source-grep — source uses string-concat evasion).

ACs verified: AC16, AC18.
Spec: docs/superpowers/specs/2026-05-27-qg-gate2-findings-fix-design.md §5.8, §5.6.5

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Final commit — plugin.json 1.32.1 + CHANGELOG

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`
- Modify: `plugins/quality-gates/CHANGELOG.md`

**Finding absorbed:** AC19 (version + CHANGELOG).

- [ ] **Step 10.1: Bump plugin.json**

Use Edit on `plugins/quality-gates/.claude-plugin/plugin.json` to change `"version": "1.32.0"` → `"version": "1.32.1"`.

- [ ] **Step 10.2: Prepend CHANGELOG entry**

Read `plugins/quality-gates/CHANGELOG.md` to see the format. Use Edit to prepend (before the existing `## [1.32.0]` entry):

```markdown
## [1.32.1] — 2026-05-27

### Fixed (Gate 2 review-driven, PR #71)

- **C1**: SKILL.md restores `project_dir:` threading into all 4 reviewer
  dispatches (`adversarial`, `test-scope-validator`, `security-reviewer`,
  `runtime-verifier`). 신규 preflight P0 step에서 `project_dir=$(pwd)`로
  도출 후 매 dispatch에 전달.
- **C2**: `pre-pipeline-check.sh` 세션 ID 가드 추가. 같은 세션이
  소유한 `pipeline.md`는 절대 삭제 안 함 (P2→P3 race 차단).
- **C3**: `DEVBREW_GATE3_MAX_RESOLUTIONS` 검증 블록 `setup-qg.sh`에
  복구. P18 unbounded-autonomy guard 회귀 해소.
- **C4**: `tests/test_setup_qg.sh` v1.32.1 schema 기준으로 재작성.
- **C5**: v1 `tests/test_session_start_advisor.py` 삭제 (v2 shell
  wrapper가 대체).
- **C6**: 새로운 `tests/harness/test_skill_orchestration_behavior.sh` —
  SKILL.md orchestration의 protocol-shape 검증 (순서/근접성/섹션
  멤버십). V7 tautological substring grep은 같은 commit에서 삭제.
- **I1/I2/I8/I9/I11/I12**: test/doc drift 정리.
- **I3**: `setup-qg.sh` 헤더/`--help`에서 "Stop hook-based" 표현 제거.
- **I4/I5**: `session-start-advisor.py` silent-failure (OSError/JSONDecodeError)
  diagnostic stderr로 전환.
- **I6**: SKILL.md Retry path error handling — Edit 실패 시 AskUserQuestion
  으로 사용자에게 surface (silent skip 금지).
- **I7**: `check-trivia.sh` exit-code 2 분기 제거 (unreachable).
- **I10**: Retry path file-write safety — reviewer 공급 `file:` 필드
  canonicalize (`realpath` + `commonpath`, project_dir 양쪽 normalisation).

### Fixed (Medium tier)

- LEGACY_V1_KEYS 두 번째 split (`consecutive_no_signal:` → string-concat).
- LEGACY_V1_KEYS invariant comment 추가.
- `cancel-qg-core.sh` 추출 (commands/cancel-qg.md와 tests/test_cancel_qg.sh
  공유 코드 경로).
- 새 `tests/test_pre_pipeline_check.sh` (C2 회귀 방지).
- `test_kill_switches.py`에 `DEVBREW_DISABLE_QUALITY_GATES=1` 케이스 추가.
- `test_skill_orchestration.sh` V2b uniqueness 강화 (`grep -c == 1`).
- `test_session_start_advisor_v2.sh` V8 → V8a/V8b 분리 + LEGACY_V1_KEYS
  fixture 기반 회귀 테스트.

### Security

- I10: reviewer 공급 path가 `project_dir` 외부로 escape하는 것을 차단
  (canonicalization + commonpath assertion). symlink-traversal 회피.

```

- [ ] **Step 10.3: Verify AC19**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
test "$(jq -r .version plugins/quality-gates/.claude-plugin/plugin.json)" = "1.32.1" \
  && echo "AC19 version PASS" || echo "AC19 version FAIL"
head -20 plugins/quality-gates/CHANGELOG.md | grep -q '## \[1.32.1\] — 2026-05-27' \
  && echo "AC19 CHANGELOG PASS" || echo "AC19 CHANGELOG FAIL"
```

Both PASS.

- [ ] **Step 10.4: Commit Task 10 (final commit)**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
git add plugins/quality-gates/.claude-plugin/plugin.json \
        plugins/quality-gates/CHANGELOG.md
git commit -m "$(cat <<'EOF'
chore(quality-gates): v1.32.0 → v1.32.1 (Gate 2 review-driven fixes)

Final commit of the Gate 2 findings fix series (PR #71). Bumps plugin
version 1.32.0 → 1.32.1 and prepends CHANGELOG entry summarizing all
27+ findings resolved across this branch.

Per feedback_plugin_version_bump.md: bumping cleanly marks "v1.32.0 had
review-caught issues fixed pre-merge" so users with cached v1.32.0
invalidate their cache after merge.

AC verified: AC19.
Spec: docs/superpowers/specs/2026-05-27-qg-gate2-findings-fix-design.md §5.9

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Full test sweep + PR comment

**Files:** none modified.

**Purpose:** spec §7 Verification Plan steps 2 + 4. Produce evidence for PR comment.

- [ ] **Step 11.1: Run full test sweep**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
echo "=== Shell tests ==="
for f in plugins/quality-gates/tests/test_*.sh; do
  printf '%-70s ' "$f"
  if bash "$f" >/dev/null 2>&1; then echo PASS; else echo FAIL; fi
done
echo "=== Harness tests ==="
for f in plugins/quality-gates/tests/harness/test_*.sh; do
  printf '%-70s ' "$f"
  if bash "$f" >/dev/null 2>&1; then echo PASS; else echo FAIL; fi
done
echo "=== Python tests ==="
for f in plugins/quality-gates/tests/test_*.py; do
  printf '%-70s ' "$f"
  if python3 "$f" >/dev/null 2>&1; then echo PASS; else echo FAIL; fi
done
```

Expected: every line PASS. If any FAIL, identify the cause and fix in a small follow-up commit before proceeding to Step 11.2.

- [ ] **Step 11.2: Run all ACs sweep (one-shot verification)**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
SKILL_MD=plugins/quality-gates/skills/quality-pipeline/SKILL.md
ADVISOR=plugins/quality-gates/hooks/session-start-advisor.py
README=plugins/quality-gates/README.md
E2E=plugins/quality-gates/tests/e2e-scenarios.md
ORCH=plugins/quality-gates/tests/test_skill_orchestration.sh
HARNESS=plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh

ac_pass=0; ac_fail=0
ac() { if eval "$2"; then echo "$1 PASS"; ac_pass=$((ac_pass+1)); else echo "$1 FAIL"; ac_fail=$((ac_fail+1)); fi; }

# AC1
ac AC1 'for a in adversarial test-scope-validator security-reviewer runtime-verifier; do grep -A10 "subagent_type[^\"]*\"$a" '"$SKILL_MD"' | grep -q "project_dir:" || exit 1; done'
# AC2
ac AC2 'bash plugins/quality-gates/tests/test_pre_pipeline_check.sh'
# AC3 — already verified in Step 2.4; re-run condensed
ac AC3 'CLAUDE_CODE_SESSION_ID=ac3-$$ DEVBREW_GATE3_MAX_RESOLUTIONS=99 bash plugins/quality-gates/scripts/setup-qg.sh --ensure 2>&1 | grep -q "exceeds maximum 10" && rm -rf .claude/quality-gates/ac3-$$'
# AC4
ac AC4 'bash plugins/quality-gates/tests/test_setup_qg.sh'
# AC5
ac AC5 'test ! -f plugins/quality-gates/tests/test_session_start_advisor.py'
# AC6
ac AC6 'bash '"$HARNESS"' && test "$(grep -cE '"'"'^[[:space:]]*(function[[:space:]]+)?(test_)?V7[[:space:]({]'"'"' '"$ORCH"')" -eq 0'
# AC7
ac AC7 'python3 plugins/quality-gates/tests/test_kill_switches.py'
# AC8
ac AC8 'bash plugins/quality-gates/tests/test_worktree.sh'
# AC9, AC10
ac AC9 'grep -qE "print.*qg-advisor.*legacy-v1" '"$ADVISOR"
ac AC10 'grep -qE "payload parse failed" '"$ADVISOR"
# AC11a/b/c
ac AC11a 'grep -A5 "Retry" '"$SKILL_MD"' | grep -iqE "AskUserQuestion.*(Retry failed|skip retry|abort)"'
ac AC11b 'test "$(grep -cE '"'"'check-trivia.*exit.*2|exit.*code.*2.*check-trivia|trivia.*== *2'"'"' '"$SKILL_MD"')" -eq 0'
ac AC11c 'grep -q "realpath" '"$SKILL_MD"' && grep -q "commonpath" '"$SKILL_MD"' && grep -A3 "realpath" '"$SKILL_MD"' | grep -q "project_dir"'
# AC12
ac AC12 'test "$(grep -cE '"'"'Stop hook'"'"' '"$README"')" -eq 0'
# AC13
ac AC13 'test "$(grep -cE '"'"'stop-hook\.py|<qg-signal|gate2_repeat_detected'"'"' '"$E2E"')" -eq 0'
# AC14
ac AC14 'test "$(grep -cE '"'"'^gate2_iteration:'"'"' '"$SKILL_MD"')" -eq 0'
# AC15
ac AC15 'bash plugins/quality-gates/tests/test_readme_state_diagram_complete.sh'
# AC16
ac AC16 'bash plugins/quality-gates/tests/test_skill_orchestration.sh && bash plugins/quality-gates/tests/test_pre_pipeline_check.sh && bash plugins/quality-gates/tests/test_session_start_advisor_v2.sh'
# AC17
ac AC17 'test "$(grep -cE '"'"'consecutive_no_signal:|current_gate:'"'"' '"$ADVISOR"')" -eq 0 && grep -qF '"'"'"current" + "_gate:"'"'"' '"$ADVISOR"' && grep -qF '"'"'"consecutive_no" + "_signal:"'"'"' '"$ADVISOR"
# AC18
ac AC18 'test -x plugins/quality-gates/scripts/cancel-qg-core.sh && grep -q cancel-qg-core.sh plugins/quality-gates/commands/cancel-qg.md && grep -q cancel-qg-core.sh plugins/quality-gates/tests/test_cancel_qg.sh && bash plugins/quality-gates/tests/test_cancel_qg.sh'
# AC19
ac AC19 'test "$(jq -r .version plugins/quality-gates/.claude-plugin/plugin.json)" = "1.32.1" && head -20 plugins/quality-gates/CHANGELOG.md | grep -q "## \[1.32.1\] — 2026-05-27"'

echo
echo "AC summary: $ac_pass PASS / $ac_fail FAIL"
[[ "$ac_fail" -eq 0 ]] || exit 1
```

Expected: `AC summary: 21 PASS / 0 FAIL` (AC1, AC2, AC3, AC4, AC5, AC6, AC7, AC8, AC9, AC10, AC11a, AC11b, AC11c, AC12, AC13, AC14, AC15, AC16, AC17, AC18, AC19).

- [ ] **Step 11.3: Generate PR comment**

Capture commit SHAs and AC verdicts. Run:

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
git log --oneline main..HEAD | head -20
```

Build a PR comment summary mapping each finding ID → resolving commit SHA + AC verdict. Format (copy-paste into PR #71 comment):

```markdown
## v1.32.1 — Gate 2 Findings Fix Summary

All 27+ Gate 2 findings from [findings doc](../blob/feature/qg-askq-iteration/docs/superpowers/plans/notes/2026-05-27-gate2-findings.md) resolved.

### Critical
| Finding | Commit | AC |
|---|---|---|
| C1 — project_dir contract | <Task 1 SHA> | AC1 |
| C2 — P2→P3 race | <Task 3 SHA> | AC2 |
| C3 — GATE3_MAX clamp | <Task 2 SHA> | AC3 |
| C4 — test_setup_qg rewrite | <Task 7 SHA> | AC4 |
| C5 — v1 advisor test delete | <Task 7 SHA> | AC5 |
| C6 — protocol-shape test | <Task 8 SHA> | AC6 |

### Important
| Finding | Commit | AC |
|---|---|---|
| I1 — stderr assertion | <Task 6 SHA> | AC7 |
| I2 — worktree project_dir | <Task 6 SHA> | AC8 |
| I3 — Stop-hook wording | <Task 2 SHA> | (manual grep) |
| I4 — OSError swallow | <Task 4 SHA> | AC9 |
| I5 — JSONDecodeError swallow | <Task 4 SHA> | AC10 |
| I6 — Retry error handling | <Task 1 SHA> | AC11a |
| I7 — no exit-2 branch | <Task 1 SHA> | AC11b |
| I8 — Stop-hook diagram | <Task 5 SHA> | AC12 |
| I9 — e2e-scenarios drift | <Task 6 SHA> | AC13 |
| I10 — file-write safety | <Task 1 SHA> | AC11c |
| I11 — gate2_iteration phantom | <Task 1 SHA> | AC14 |
| I12 — diagram-completeness | <Task 7 SHA> | AC15 |

### Medium
All 9 Medium-tier findings resolved across Tasks 6 and 9. See AC16, AC17, AC18.

### Version
1.32.0 → 1.32.1 (commit: <Task 10 SHA>). AC19.

### Test sweep
All shell + python tests PASS post-fix (baseline had 4 FAILs in
test_setup_qg.sh / test_session_start_advisor.py / test_worktree.sh /
test_kill_switches.py — all resolved).
```

Fill in `<Task N SHA>` placeholders from `git log` output. Post as a comment on PR #71 via `gh pr comment 71 --body-file <path>`.

- [ ] **Step 11.4: Push to remote**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
git push origin worktree-feature-qg-askq-iteration:feature/qg-askq-iteration
```

PR #71 automatically updates with the new commits.

---

## Self-Review Notes

After Task 11, the executor should look back at the spec ACs (spec §6) and confirm every one has a corresponding `echo "ACx PASS"` in the plan. The plan covers all 19 ACs (with AC11 split into a/b/c → 21 total ac() calls in Step 11.2).

**Spec coverage verified inline above** — each Task lists the finding IDs and ACs it resolves.

**Placeholder scan**: this plan deliberately uses `<Task N SHA>` placeholders in Step 11.3 (filled at execution time from `git log`). No other placeholders. All code blocks contain complete code; no "implement later" or "similar to Task N" patterns.

**Type consistency**: `project_dir` is consistently the runtime dispatch parameter (not the v1.32.0-removed state schema field — see spec §0 disambiguation note). `CLAUDE_CODE_SESSION_ID` is consistently used (never aliased). `gate3_max_resolutions:` is the consistent state-file key name across setup-qg.sh and tests.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-27-qg-gate2-findings-fix.md`.

Per spec §8: **Inline Execution** chosen. Use `superpowers:executing-plans` to run task-by-task. Each Task ends with a commit step; no batching across tasks.

Estimated duration: 60-90 minutes for an experienced executor with the worktree open.
