# Quality-Gates Forward-Only Cleanup + Stop-Hook Trim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align quality-gates SKILL.md / state-file-format.md prose with the v1.5.0 forward-only state machine, remove deprecated `total_iterations` / `max_total_iterations` field handling (including the dead `extend`-transition write at `update_state_file:419-420`), and trim `build_special_prompt` 6-case duplication + `main()` transition-handler ladder in `stop-hook.py` — all in one PR with regression guards that lock the invariants going forward.

**Architecture:** Ordered D1 (deprecated field removal) → D2 (`build_special_prompt` template) → D3 (`main()` helper) → D4 (prose drift fix). Each step closes with `tests/` passing and a commit so bisect remains useful inside the PR (Rejected Alternative F in the spec). A new `tests/test_forward_only_prose.sh` (grep-based regression guard) and `tests/test_stop_hook_unit.py` (`build_special_prompt` invariant tests) lock the invariants. Final version bump `1.9.0 → 1.10.0` + CHANGELOG.

**Tech Stack:** Python 3 (stop-hook.py + Python tests), bash (regression test + measurement commands), markdown (SKILL.md / CHANGELOG.md / state-file-format.md / spec), JSON (plugin.json).

**Spec:** [`docs/superpowers/specs/2026-05-13-qg-forward-only-cleanup-and-stop-hook-trim-design.md`](../specs/2026-05-13-qg-forward-only-cleanup-and-stop-hook-trim-design.md)

**Worktree:** `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-forward-only-cleanup/` on branch `worktree-qg-forward-only-cleanup`.

---

## File Map

| Path | Type | Purpose |
|---|---|---|
| `plugins/quality-gates/hooks/stop-hook.py` | Edit | D1 (parse_state_file, update_state_file), D2 (build_special_prompt), D3 (main() helper) |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | Edit | D4 (5 prose sites) |
| `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md` | Edit | D1 (deprecated note), D4 (example history log) |
| `plugins/quality-gates/tests/test_stop_hook_state_machine.py` | Edit | D1 fixture cleanup (lines 25-26, 40-41, 56-57, 72-73, 87-88, 161-162) — line 15 test preserved |
| `plugins/quality-gates/tests/test_kill_switches.py` | Edit | D1 fixture cleanup (line 49) |
| `plugins/quality-gates/tests/test_session_start_advisor.py` | Edit | D1 fixture cleanup (line 26) |
| `plugins/quality-gates/.claude-plugin/plugin.json` | Edit | Version `1.9.0` → `1.10.0` |
| `plugins/quality-gates/CHANGELOG.md` | Edit | Prepend `## [1.10.0] — 2026-05-13` section |
| `plugins/quality-gates/tests/test_forward_only_prose.sh` | Create | Forbidden + required phrase + deprecated-field grep guard |
| `plugins/quality-gates/tests/test_stop_hook_unit.py` | Create | `build_special_prompt` invariant unit tests |

10 file touches (8 edit + 2 create).

---

## Task 1: Baseline and scaffold the prose regression guard (D-shared, TDD anchor)

**Why first:** The spec mandates a forbidden-phrase grep regression guard (AC12). Creating it now — before any prose / code edit — lets it act as the failing test that proves D1/D4 worked. Existing test suite is captured as the green baseline.

**Files:**
- Create: `plugins/quality-gates/tests/test_forward_only_prose.sh`

- [ ] **Step 1: Confirm worktree and baseline state**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-forward-only-cleanup
git status
git log --oneline -3
wc -l plugins/quality-gates/hooks/stop-hook.py
```
Expected: clean tree on `worktree-qg-forward-only-cleanup`, top 2 commits are the spec (`ded5c7f`, `7c68dcc`), `wc -l` reports `960`.

- [ ] **Step 2: Run the full existing test suite as baseline**

Run:
```bash
cd plugins/quality-gates
for t in tests/test_*.sh; do bash "$t" || { echo "BASELINE FAIL: $t"; exit 1; }; done
for t in tests/test_*.py; do python3 "$t" || { echo "BASELINE FAIL: $t"; exit 1; }; done
echo "BASELINE PASS"
```
Expected: `BASELINE PASS`. Any failure here aborts the plan (the worktree is not in a known-good state).

- [ ] **Step 3: Write the new regression guard `test_forward_only_prose.sh`**

Create `plugins/quality-gates/tests/test_forward_only_prose.sh` with the following content (mode 0755 — chmod after writing):

```bash
#!/usr/bin/env bash
# Regression guard for the v1.5.0 forward-only state machine prose contract.
# Failing this test means the SKILL.md / references prose has drifted back
# toward the pre-v1.5.0 "auto-restart from Gate 1" vocabulary, OR the
# deprecated total_iterations / max_total_iterations fields have re-entered
# the codebase.
#
# Locked by spec docs/superpowers/specs/2026-05-13-qg-forward-only-cleanup-and-stop-hook-trim-design.md AC1-3, AC4-6, AC8, NG7.
set -u

REPO_PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_PLUGIN_ROOT"

FAILED=0
fail()  { echo "FAIL: $*"; FAILED=1; }
ok()    { echo "ok:   $*"; }

# --- AC1-3: forbidden phrases in skill prose -----------------------------------

if grep -rn 'restart from Gate 1' skills references 2>/dev/null; then
    fail "AC1: 'restart from Gate 1' phrase still present"
else
    ok "AC1: no 'restart from Gate 1' in skill prose"
fi

if grep -rn 'loop-back' skills 2>/dev/null; then
    fail "AC2: 'loop-back' phrase still present in SKILL prose"
else
    ok "AC2: no 'loop-back' in skill prose"
fi

if grep -rn 'Restarting from Gate 1' skills references 2>/dev/null; then
    fail "AC3: example log line 'Restarting from Gate 1' still present"
else
    ok "AC3: no 'Restarting from Gate 1' in skill or references"
fi

# --- AC4-6: required phrases ---------------------------------------------------

if grep -q 'forward-only' skills/quality-pipeline/SKILL.md; then
    ok "AC4: SKILL.md mentions 'forward-only'"
else
    fail "AC4: SKILL.md missing 'forward-only' (verdict definition?)"
fi

count_fix_rerun=$(grep -c 'Fix and re-run /qg' skills/quality-pipeline/SKILL.md || true)
if [ "$count_fix_rerun" -ge 1 ]; then
    ok "AC5: SKILL.md contains 'Fix and re-run /qg' (count=$count_fix_rerun)"
else
    fail "AC5: SKILL.md missing 'Fix and re-run /qg'"
fi

count_no_auto=$(grep -cE 'does (not|NOT) auto-restart' skills/quality-pipeline/SKILL.md || true)
if [ "$count_no_auto" -ge 2 ]; then
    ok "AC6: SKILL.md contains 'does not auto-restart' >=2 (count=$count_no_auto)"
else
    fail "AC6: SKILL.md needs 'does not auto-restart' in >=2 sections (got $count_no_auto)"
fi

# --- AC8: deprecated state field residues --------------------------------------
# Allowed: CHANGELOG history; test_no_max_total_iterations_constant gate test.

LEAK=$(grep -rn 'total_iterations\|max_total_iterations' . 2>/dev/null \
  | grep -v 'CHANGELOG.md' \
  | grep -v 'test_stop_hook_state_machine.py.*test_no_max_total_iterations_constant' \
  || true)

if [ -z "$LEAK" ]; then
    ok "AC8: no deprecated-field residue (CHANGELOG + named gate test excluded)"
else
    fail "AC8: deprecated-field residue:"
    echo "$LEAK"
fi

# --- NG7: setup-qg.sh has no deprecated-field writing --------------------------

if grep -n 'total_iterations\|max_total_iterations' scripts/setup-qg.sh 2>/dev/null; then
    fail "NG7: setup-qg.sh contains deprecated field reference (regression)"
else
    ok "NG7: setup-qg.sh free of deprecated field references"
fi

# -------------------------------------------------------------------------------

if [ "$FAILED" -ne 0 ]; then
    echo "test_forward_only_prose.sh: FAIL"
    exit 1
fi
echo "test_forward_only_prose.sh: PASS"
```

- [ ] **Step 4: Make it executable and run — expect mixed FAIL**

Run:
```bash
chmod +x plugins/quality-gates/tests/test_forward_only_prose.sh
bash plugins/quality-gates/tests/test_forward_only_prose.sh
```
Expected: `test_forward_only_prose.sh: FAIL` — AC1, AC2, AC3, AC4-6 (and AC8) will all currently fail because the prose has not been edited yet and the deprecated fields are still in the code. This is the **intended failing-test anchor** for the rest of the plan.

- [ ] **Step 5: Commit the regression guard**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-forward-only-cleanup
git add plugins/quality-gates/tests/test_forward_only_prose.sh
git commit -m "$(cat <<'EOF'
test(qg): add forward-only prose + deprecated-field regression guard

Failing test anchor for the v1.10.0 cleanup. Grep-based:
- AC1-3 forbid 'restart from Gate 1' / 'loop-back' / 'Restarting from Gate 1'
- AC4-6 require 'forward-only', 'Fix and re-run /qg', 'does not auto-restart' (>=2)
- AC8 disallows total_iterations / max_total_iterations residue (CHANGELOG +
  test_no_max_total_iterations_constant gate excluded)
- NG7 asserts setup-qg.sh has no deprecated field writing

Currently FAIL by design — D1 (Tasks 2-5) and D4 (Tasks 10-11) drive it green.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: D1.a — Remove deprecated fields from `parse_state_file`

**Files:**
- Modify: `plugins/quality-gates/hooks/stop-hook.py` (lines 89, 92, 101–107)

- [ ] **Step 1: Read the target block to confirm content**

Run:
```bash
sed -n '85,108p' plugins/quality-gates/hooks/stop-hook.py
```
Confirm lines 89–107 match the spec's quoted code.

- [ ] **Step 2: Edit `parse_state_file` — replace the deprecated tolerate block**

In `plugins/quality-gates/hooks/stop-hook.py`, replace:

```python
    # Convert numeric fields (forward-only: total_iterations / max_total_iterations
    # are no longer written by setup-qg.sh; tolerate their absence on read).
    required_numeric = ("current_gate", "gate2_iteration", "max_gate2_iterations")
    optional_numeric = ("total_iterations", "max_total_iterations",
                        "gate3_resolution_iter", "max_gate3_resolutions")
    for field in required_numeric:
        val = state.get(field, "0")
        if not val.isdigit():
            print(f"⚠️  Quality Gates: Invalid numeric field '{field}': {val}",
                  file=sys.stderr)
            return None, None
        state[field] = int(val)
    for field in optional_numeric:
        val = state.get(field)
        if val is None:
            continue
        if val.isdigit():
            state[field] = int(val)
        # else: leave as-is; nothing reads it after forward-only refactor
```

with:

```python
    # Convert numeric fields. total_iterations / max_total_iterations were
    # removed in v1.10.0 (already never-written since v1.5.0); legacy state
    # files carrying them are simply parsed without those keys — nothing
    # downstream reads them.
    required_numeric = ("current_gate", "gate2_iteration", "max_gate2_iterations")
    optional_numeric = ("gate3_resolution_iter", "max_gate3_resolutions")
    for field in required_numeric:
        val = state.get(field, "0")
        if not val.isdigit():
            print(f"⚠️  Quality Gates: Invalid numeric field '{field}': {val}",
                  file=sys.stderr)
            return None, None
        state[field] = int(val)
    for field in optional_numeric:
        val = state.get(field)
        if val is None:
            continue
        if val.isdigit():
            state[field] = int(val)
```

- [ ] **Step 3: Run the stop-hook unit tests to confirm parse still works**

Run:
```bash
cd plugins/quality-gates
python3 tests/test_stop_hook_state_machine.py
```
Expected: PASS. Fixtures still carry `"total_iterations": 1` keys in dicts, but `parse_state_file` is not invoked by those tests (they directly call `compute_transition`). The harmless presence of extra dict keys does not break anything. Cleanup of fixtures happens in Task 4.

- [ ] **Step 4: Run the full Python test suite**

Run:
```bash
for t in tests/test_*.py; do python3 "$t" || { echo "FAIL: $t"; exit 1; }; done
```
Expected: all pass.

- [ ] **Step 5: Commit**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-forward-only-cleanup
git add plugins/quality-gates/hooks/stop-hook.py
git commit -m "$(cat <<'EOF'
refactor(qg): drop total_iterations from parse_state_file

D1.a of v1.10.0 cleanup. parse_state_file no longer tolerates
total_iterations / max_total_iterations in the optional_numeric tuple
nor in the conversion loop. Legacy state files that still carry the
fields parse without populating those keys in the returned state dict;
downstream code never reads them after the v1.5.0 forward-only
refactor, so this is purely dead-weight removal.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: D1.b — Remove dead `extend`-transition write from `update_state_file`

**Why critical:** spec §G5 e2b6f5a — `new_max_total += transition.get("additional", 3)` (line 420) is **already a dead write** because `replacements` (lines 436–442) lacks `max_total_iterations`. Removing the variables and the dead `+=` cleans up the deception that the `extend` branch does something.

**Files:**
- Modify: `plugins/quality-gates/hooks/stop-hook.py` (lines 403, 405, 419–420, 433–435 comment)

- [ ] **Step 1: Verify the dead-write claim before editing**

Run:
```bash
sed -n '395,445p' plugins/quality-gates/hooks/stop-hook.py | grep -n 'total_iterations\|max_total_iterations\|extend\|replacements'
```
Expected: `new_total = state.get("total_iterations", 1)` (line 9 of slice = file line 403), `new_max_total = state.get("max_total_iterations", 5)` (line 405), `new_max_total += transition.get("additional", 3)` (~line 420), and the `replacements` dict that does NOT contain those keys.

- [ ] **Step 2: Confirm the `extend` transition is/isn't emitted elsewhere**

Run:
```bash
grep -n '"extend"' plugins/quality-gates/hooks/stop-hook.py
```
Expected: matches at the `update_state_file` branch (~line 419) and at the `main()` handler block. Confirm by visual inspection whether `compute_transition` ever returns `{"type": "extend", ...}`.

```bash
sed -n '270,395p' plugins/quality-gates/hooks/stop-hook.py | grep -n 'extend'
```
Expected: **no matches** in `compute_transition`. This confirms that the `extend` branch in `update_state_file` is unreachable today.

- [ ] **Step 3: Edit `update_state_file` — remove `new_total`, `new_max_total`, the `extend` branch, and the obsolete forward-only comment**

In `plugins/quality-gates/hooks/stop-hook.py`, replace:

```python
    new_status = state.get("status", "gate1_running")
    new_gate = state.get("current_gate", 1)
    new_total = state.get("total_iterations", 1)
    new_gate2_iter = state.get("gate2_iteration", 0)
    new_max_total = state.get("max_total_iterations", 5)
    new_gate3_resolution_iter = state.get("gate3_resolution_iter", 0)

    t_type = transition["type"]
    if t_type == "next_gate":
        new_gate = transition["next_gate"]
        new_status = f"gate{new_gate}_running"
        if new_gate == 2:
            new_gate2_iter = transition.get("gate2_iteration", 1)
    elif t_type == "retry_gate":
        retry_gate = transition.get("gate", new_gate)
        new_status = f"gate{retry_gate}_running"
        if retry_gate == 2:
            new_gate2_iter = transition.get("gate2_iteration", new_gate2_iter)
    elif t_type == "extend":
        new_max_total += transition.get("additional", 3)
    elif t_type in ("complete", "abort"):
        new_status = "completed" if t_type == "complete" else "aborted"
```

with:

```python
    new_status = state.get("status", "gate1_running")
    new_gate = state.get("current_gate", 1)
    new_gate2_iter = state.get("gate2_iteration", 0)
    new_gate3_resolution_iter = state.get("gate3_resolution_iter", 0)

    t_type = transition["type"]
    if t_type == "next_gate":
        new_gate = transition["next_gate"]
        new_status = f"gate{new_gate}_running"
        if new_gate == 2:
            new_gate2_iter = transition.get("gate2_iteration", 1)
    elif t_type == "retry_gate":
        retry_gate = transition.get("gate", new_gate)
        new_status = f"gate{retry_gate}_running"
        if retry_gate == 2:
            new_gate2_iter = transition.get("gate2_iteration", new_gate2_iter)
    elif t_type in ("complete", "abort"):
        new_status = "completed" if t_type == "complete" else "aborted"
```

Also replace the obsolete comment:

```python
    # Apply frontmatter updates via string replacement.
    # Forward-only: total_iterations / max_total_iterations are no longer
    # persisted (setup-qg.sh stopped writing them in v1.5.0). Stale fields
    # in old state files are tolerated on read but not refreshed.
```

with:

```python
    # Apply frontmatter updates via string replacement. Only fields in the
    # replacements dict below are touched; legacy fields stay verbatim and
    # never re-enter the state machine.
```

- [ ] **Step 4: Run unit tests**

Run:
```bash
cd plugins/quality-gates
python3 tests/test_stop_hook_state_machine.py
```
Expected: PASS. Fixtures still carry `total_iterations` in dicts (cleaned in next task), but `update_state_file` is called via integration paths, not unit tests here.

- [ ] **Step 5: Spot-check that no other file references `new_max_total`**

Run:
```bash
grep -n 'new_max_total\|new_total' plugins/quality-gates/hooks/stop-hook.py
```
Expected: 0 hits.

- [ ] **Step 6: Commit**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-forward-only-cleanup
git add plugins/quality-gates/hooks/stop-hook.py
git commit -m "$(cat <<'EOF'
refactor(qg): drop dead extend-transition write in update_state_file

D1.b of v1.10.0 cleanup. The 'extend' branch incremented new_max_total
but never persisted it (replacements dict lacks max_total_iterations
since v1.5.0). compute_transition does not return type='extend' either,
so the branch was double-dead: unreachable, and would have been a no-op
if reached.

Removes new_total / new_max_total local variables and the extend
branch from update_state_file. Replaces the obsolete forward-only
comment with a current-state description.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: D1.c — Clean fixture files

**Files:**
- Modify: `plugins/quality-gates/tests/test_stop_hook_state_machine.py` (6 fixture pairs at lines 25-26, 40-41, 56-57, 72-73, 87-88, 161-162)
- Modify: `plugins/quality-gates/tests/test_kill_switches.py` (line 49)
- Modify: `plugins/quality-gates/tests/test_session_start_advisor.py` (line 26)

- [ ] **Step 1: Remove the 6 fixture-pair lines in `test_stop_hook_state_machine.py`**

For each of the 6 occurrences, delete the two consecutive lines `"total_iterations": 1,` and `"max_total_iterations": 5,`. Use `Edit` with `replace_all=true` on the exact pair string since both pairs occur identically multiple times:

Replace in `plugins/quality-gates/tests/test_stop_hook_state_machine.py`:
```python
            "total_iterations": 1,
            "max_total_iterations": 5,
```
with the empty string (deletion). Use `replace_all=true`.

This collapses 6 fixture states from 8 keys each to 6 keys.

Preserve `test_no_max_total_iterations_constant` (line 15) — it is a positive regression guard.

- [ ] **Step 2: Remove line 49 of `test_kill_switches.py`**

In `plugins/quality-gates/tests/test_kill_switches.py`, replace:

```python
PIPELINE_RUNNING = (
    "---\n"
    "status: gate1_running\n"
    "current_gate: 1\n"
    "total_iterations: 0\n"
    'started_at: "2026-05-10T00:00:00Z"\n'
    "---\n"
    "# Quality Gates Pipeline State\n"
)
```

with:

```python
PIPELINE_RUNNING = (
    "---\n"
    "status: gate1_running\n"
    "current_gate: 1\n"
    'started_at: "2026-05-10T00:00:00Z"\n'
    "---\n"
    "# Quality Gates Pipeline State\n"
)
```

- [ ] **Step 3: Remove line 26 of `test_session_start_advisor.py`**

In `plugins/quality-gates/tests/test_session_start_advisor.py`, replace:

```python
def make_state(status: str, gate: int = 2, started_at: str = "2026-04-29T08:14:00Z") -> str:
    return (
        "---\n"
        f"status: {status}\n"
        f"current_gate: {gate}\n"
        "total_iterations: 1\n"
        f'started_at: "{started_at}"\n'
        "---\n"
        "# Quality Gates Pipeline State\n"
    )
```

with:

```python
def make_state(status: str, gate: int = 2, started_at: str = "2026-04-29T08:14:00Z") -> str:
    return (
        "---\n"
        f"status: {status}\n"
        f"current_gate: {gate}\n"
        f'started_at: "{started_at}"\n'
        "---\n"
        "# Quality Gates Pipeline State\n"
    )
```

- [ ] **Step 4: Run all Python tests**

Run:
```bash
cd plugins/quality-gates
for t in tests/test_*.py; do python3 "$t" || { echo "FAIL: $t"; exit 1; }; done
```
Expected: all pass.

- [ ] **Step 5: Run the bash tests too**

Run:
```bash
for t in tests/test_*.sh; do bash "$t" || { echo "FAIL: $t"; exit 1; }; done
```
Expected: `test_forward_only_prose.sh` still fails on AC1-6 (prose drift not yet fixed) but on AC8 the deprecated-field grep should now be much closer to zero. Other `.sh` tests pass.

- [ ] **Step 6: Commit**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-forward-only-cleanup
git add plugins/quality-gates/tests/test_stop_hook_state_machine.py \
        plugins/quality-gates/tests/test_kill_switches.py \
        plugins/quality-gates/tests/test_session_start_advisor.py
git commit -m "$(cat <<'EOF'
test(qg): drop deprecated total_iterations from fixtures

D1.c of v1.10.0 cleanup. test_stop_hook_state_machine.py had 6
fixture state dicts each carrying total_iterations / max_total_iterations
unused by compute_transition. test_kill_switches.py and
test_session_start_advisor.py had the field baked into their
PIPELINE_RUNNING / make_state fixtures.

The named regression test test_no_max_total_iterations_constant
(line 15) is preserved — it remains the positive guard against the
field re-entering the module surface.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: D1.d — Remove the deprecated note from `state-file-format.md`

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md` (lines 37–38 deprecated note)

- [ ] **Step 1: Edit the schema doc**

In `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md`, delete the two-line block:

```
# total_iterations / max_total_iterations: deprecated in v1.5.0 (cross-gate
# restart removed). Tolerated on read for back-compat; never written.
```

The surrounding YAML block should compress cleanly (no blank line should be left in place of the deletion).

- [ ] **Step 2: Verify by grep**

Run:
```bash
grep -n 'total_iterations\|max_total_iterations' plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md
```
Expected: 0 hits.

- [ ] **Step 3: Re-run `test_forward_only_prose.sh`**

Run:
```bash
bash plugins/quality-gates/tests/test_forward_only_prose.sh
```
Expected: AC8 + NG7 now PASS. AC1-3 and AC4-6 still FAIL (prose drift is Task 10–11). Net result is still FAIL — that's correct.

- [ ] **Step 4: Commit**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-forward-only-cleanup
git add plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md
git commit -m "$(cat <<'EOF'
docs(qg): drop deprecated total_iterations schema note

D1.d of v1.10.0 cleanup. references/state-file-format.md still
documented the v1.5.0-deprecated fields as "tolerated on read".
With Tasks 2-4 those fields no longer exist anywhere in the
codebase except CHANGELOG history and the regression-guard test,
so the schema doc no longer needs to mention them.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: D2.a — Write `test_stop_hook_unit.py` (AC14 invariants)

**Why before the refactor:** Unit tests assert the *current* behavior of `build_special_prompt` so the Task 7 refactor cannot silently change semantics. These tests pass against the current 6-case implementation; they protect the refactor.

**Files:**
- Create: `plugins/quality-gates/tests/test_stop_hook_unit.py`

- [ ] **Step 1: Write the unit test file**

Create `plugins/quality-gates/tests/test_stop_hook_unit.py` with this content:

```python
"""Unit tests for stop-hook.py build_special_prompt invariants.

These tests protect the Task 7 refactor (6-case → template + per-case dict).
They assert what every special prompt MUST contain so the refactor cannot
silently drop semantic content.

Locked by spec docs/superpowers/specs/2026-05-13-qg-forward-only-cleanup-and-stop-hook-trim-design.md AC14.
"""
import importlib.util
import sys
import unittest
from pathlib import Path

HOOK_PATH = Path(__file__).resolve().parent.parent / "hooks" / "stop-hook.py"
_spec = importlib.util.spec_from_file_location("stop_hook", HOOK_PATH)
stop_hook = importlib.util.module_from_spec(_spec)
sys.modules["stop_hook"] = stop_hook
_spec.loader.exec_module(stop_hook)


# Canonical (transition_type, prompt_key, expected_header_prefix) tuples.
# Header prefix is the exact case-tag the prompt MUST start with.
SPECIAL_CASES = [
    ("max_gate2_exceeded",        None,                       "GATE2_MAX_EXCEEDED\n\n"),
    ("gate3_needs_resolution",    None,                       "GATE3_NEEDS_RESOLUTION\n\n"),
    ("gate3_repeat_detected",     None,                       "GATE3_REPEAT_DETECTED\n\n"),
    ("gate3_fail",                None,                       "GATE3_FAIL\n\n"),
    ("gate2_user_choice",         "gate2_needs_restart",      "GATE2_NEEDS_RESTART\n\n"),
    ("gate2_user_choice",         "gate2_repeat_detected",    "GATE2_REPEAT_DETECTED\n\n"),
    ("gate2_user_choice",         None,                       "GATE2_USER_CHOICE\n\n"),  # generic fallback
]


def _state_stub():
    return {
        "max_gate2_iterations": 5,
        "gate3_resolution_iter": 0,
        "max_gate3_resolutions": 3,
        "current_gate": 2,
        "gate2_iteration": 1,
    }


class TestBuildSpecialPrompt(unittest.TestCase):
    def test_each_case_has_correct_header_prefix(self):
        state = _state_stub()
        for t_type, prompt_key, header in SPECIAL_CASES:
            with self.subTest(t_type=t_type, prompt_key=prompt_key):
                out = stop_hook.build_special_prompt(
                    t_type, state, "## Gate Results\nbaseline\n",
                    prompt_key=prompt_key,
                )
                self.assertTrue(
                    out.startswith(header),
                    msg=f"{t_type}/{prompt_key}: missing header {header!r}, got {out[:80]!r}",
                )

    def test_each_case_is_substantial(self):
        # All special prompts must be substantial (>200 chars) — they carry
        # option descriptions, signal mapping, and pipeline context.
        state = _state_stub()
        for t_type, prompt_key, _ in SPECIAL_CASES:
            with self.subTest(t_type=t_type, prompt_key=prompt_key):
                out = stop_hook.build_special_prompt(
                    t_type, state, "## Gate Results\nbaseline\n",
                    prompt_key=prompt_key,
                )
                self.assertGreater(len(out), 200, msg=f"{t_type}/{prompt_key}: too short")

    def test_each_case_contains_qg_signal_mapping_twice(self):
        # Every special prompt MUST tell the model how to emit signals — at
        # least two distinct <qg-signal directives (proceed/skip/abort).
        state = _state_stub()
        for t_type, prompt_key, _ in SPECIAL_CASES:
            with self.subTest(t_type=t_type, prompt_key=prompt_key):
                out = stop_hook.build_special_prompt(
                    t_type, state, "## Gate Results\nbaseline\n",
                    prompt_key=prompt_key,
                )
                self.assertGreaterEqual(
                    out.count("<qg-signal"), 2,
                    msg=f"{t_type}/{prompt_key}: needs >=2 <qg-signal lines",
                )

    def test_each_case_contains_abort_option(self):
        state = _state_stub()
        for t_type, prompt_key, _ in SPECIAL_CASES:
            with self.subTest(t_type=t_type, prompt_key=prompt_key):
                out = stop_hook.build_special_prompt(
                    t_type, state, "## Gate Results\nbaseline\n",
                    prompt_key=prompt_key,
                )
                self.assertIn("abort", out.lower(),
                              msg=f"{t_type}/{prompt_key}: needs abort option")

    def test_unknown_transition_returns_pipeline_error(self):
        # AC14: exact prefix, not just "non-empty" (a future refactor that
        # returns "" would otherwise pass).
        state = _state_stub()
        out = stop_hook.build_special_prompt(
            "no_such_transition", state, "", prompt_key=None,
        )
        self.assertTrue(out.startswith("PIPELINE_ERROR\n\n"),
                        msg=f"unknown transition: got {out[:80]!r}")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it against the *current* (un-refactored) implementation**

Run:
```bash
cd plugins/quality-gates
python3 tests/test_stop_hook_unit.py
```
Expected: PASS — current `build_special_prompt` already satisfies every invariant (verify by reading lines 591–736 if any case fails). This green baseline locks the refactor.

- [ ] **Step 3: Commit**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-forward-only-cleanup
git add plugins/quality-gates/tests/test_stop_hook_unit.py
git commit -m "$(cat <<'EOF'
test(qg): unit tests for build_special_prompt invariants

D2.a of v1.10.0 cleanup. Tests assert what every special prompt
MUST contain: exact case-tag header prefix, length >200 chars,
>=2 <qg-signal directives, an 'abort' option, and a precise
'PIPELINE_ERROR\n\n' prefix on unknown transitions (per AC14
c5a1e3b: catches a future refactor that returns "" silently).

These pass green against the current 6-case implementation and
will continue to pass after the Task 7 template refactor.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: D2.b — Refactor `build_special_prompt` to template + per-case dict

**Files:**
- Modify: `plugins/quality-gates/hooks/stop-hook.py` (lines ~591–736, `build_special_prompt`)

- [ ] **Step 1: Capture current LoC**

Run:
```bash
awk '/^def build_special_prompt/{f=1; n=0} f{n++; if(/^def [a-z_]+\(/ && !/^def build_special_prompt/){print "BEFORE:", n-1; exit}}' \
  plugins/quality-gates/hooks/stop-hook.py
```
Expected: `BEFORE: 146` (or close to that — line counting follows the spec).

- [ ] **Step 2: Replace the function with a template + data table**

In `plugins/quality-gates/hooks/stop-hook.py`, replace the entire `def build_special_prompt(...)` (currently spans roughly lines 591–736) with:

```python
# Per-case data for build_special_prompt. Each entry is keyed by either the
# transition_type (for single-prompt-key cases) or the tuple
# (transition_type, prompt_key). The 'header' is the exact case-tag prefix the
# unit tests assert. 'body' is rendered with .format(**fmt) where fmt is a
# state-derived mapping built inline below.
_SPECIAL_PROMPTS = {
    "max_gate2_exceeded": {
        "header": "GATE2_MAX_EXCEEDED",
        "body": (
            "Gate 2 (PR Review) exceeded maximum iterations "
            "({max_gate2_iterations}).\n\n"
            "Report remaining issues to the user and present options:\n"
            "1. Proceed to Gate 3 anyway\n"
            "2. Abort pipeline\n\n"
            "Based on user choice:\n"
            '- Proceed: emit <qg-signal gate="2" verdict="PASS_WITH_WARNINGS" '
            'summary="Proceeding with remaining issues" files_changed="" />\n'
            '- Abort: emit <qg-signal action="abort" reason="User chose to abort" />\n'
        ),
    },
    "gate3_needs_resolution": {
        "header": "GATE3_NEEDS_RESOLUTION",
        "body": (
            "Gate 3 (Runtime Verification) found resolvable missing resources "
            "(resolution iteration {gate3_resolution_iter}/{max_gate3_resolutions}).\n\n"
            "The skill (mother) must present the agent's `needed` items to the user "
            "as **decision-only** options (retry / skip this surface / abort). "
            "DO NOT ask the user for secret values (API keys, DB URLs, tokens, "
            "passwords). If a secret is required, the only valid options are: "
            "user sets the secret in .env on disk and chooses retry, OR skip the "
            "affected surface, OR abort.\n\n"
            "Present options to the user via AskUserQuestion:\n"
            "1. Retry — user has resolved the missing resource (e.g., started "
            "Docker daemon, added env var to .env). Re-dispatch runtime-verifier.\n"
            "2. Skip this surface — record the surface as unresolved in evidence-log "
            "and continue with remaining surfaces.\n"
            "3. Abort — stop the pipeline.\n\n"
            "Based on user choice:\n"
            "- Retry: re-dispatch runtime-verifier with updated manifest "
            '(skill increments gate3_resolution_iter). Then emit '
            '<qg-signal gate="3" verdict="..." iteration="N" /> with the new verdict.\n'
            '- Skip surface: emit <qg-signal gate="3" verdict="SKIP_WITH_EVIDENCE" '
            'summary="user opted to skip <surface>" files_changed="" />\n'
            '- Abort: emit <qg-signal action="abort" reason="User chose to abort '
            'during gate3_needs_resolution" />\n'
        ),
    },
    "gate3_repeat_detected": {
        "header": "GATE3_REPEAT_DETECTED",
        "body": (
            "Gate 3 (Runtime Verification) is not converging — "
            "the same `needed` resources appeared 2 iterations in a row.\n\n"
            "Present options to the user via AskUserQuestion:\n"
            "1. Proceed — accept the current state with warnings and continue\n"
            "2. Abort — stop the pipeline\n\n"
            "Based on user choice:\n"
            '- Proceed: emit <qg-signal gate="3" verdict="PASS_WITH_WARNINGS" '
            'summary="Repeat detected; user accepted" files_changed="" />\n'
            '- Abort: emit <qg-signal action="abort" reason="User chose to abort" />\n'
        ),
    },
    "gate3_fail": {
        "header": "GATE3_FAIL",
        "body": (
            "Gate 3 (Runtime Verification) failed.\n\n"
            "Present options to the user:\n"
            "1. Fix the issues and re-run `/qg` (pipeline does not auto-restart)\n"
            "2. Skip runtime verification and accept\n"
            "3. Abort pipeline\n\n"
            "Based on user choice:\n"
            '- Fix: inform the user to apply fixes and re-run /qg. '
            'Then emit <qg-signal action="abort" reason="User will re-run /qg after fixes" />\n'
            '- Skip: emit <qg-signal gate="3" verdict="SKIP" '
            'summary="User chose to skip runtime verification" files_changed="" />\n'
            '- Abort: emit <qg-signal action="abort" reason="User chose to abort" />\n'
        ),
    },
    ("gate2_user_choice", "gate2_needs_restart"): {
        "header": "GATE2_NEEDS_RESTART",
        "body": (
            "Gate 2 (PR Review) found that code-level changes are needed.\n\n"
            "The pipeline is forward-only and cannot automatically re-enter Gate 1.\n\n"
            "Present options to the user:\n"
            "1. Proceed — accept the Gate 2 findings as-is and continue\n"
            "2. Apply changes and re-run — apply the suggested changes, "
            "then re-run `/qg` manually\n"
            "3. Abort — stop the pipeline\n\n"
            "Based on user choice:\n"
            '- Proceed: emit <qg-signal gate="2" verdict="PASS_WITH_WARNINGS" '
            'summary="Accepted Gate 2 findings as-is" files_changed="" />\n'
            '- Apply + re-run: emit <qg-signal action="abort" '
            'reason="User will apply changes and re-run /qg" />\n'
            '- Abort: emit <qg-signal action="abort" reason="User chose to abort" />\n'
        ),
    },
    ("gate2_user_choice", "gate2_repeat_detected"): {
        "header": "GATE2_REPEAT_DETECTED",
        "body": (
            "Gate 2 (PR Review) is not converging — "
            "the same findings appeared 2 iterations in a row.\n\n"
            "Present options to the user:\n"
            "1. Proceed — accept the current Gate 2 findings and continue\n"
            "2. Abort — stop the pipeline\n\n"
            "Based on user choice:\n"
            '- Proceed: emit <qg-signal gate="2" verdict="PASS_WITH_WARNINGS" '
            'summary="Proceeding despite repeated findings" files_changed="" />\n'
            '- Abort: emit <qg-signal action="abort" reason="User chose to abort" />\n'
        ),
    },
    ("gate2_user_choice", None): {
        "header": "GATE2_USER_CHOICE",
        "body": (
            "Gate 2 (PR Review) requires user input.\n\n"
            "Present options to the user:\n"
            "1. Proceed — accept findings as-is\n"
            "2. Abort — stop the pipeline\n\n"
            "Based on user choice:\n"
            '- Proceed: emit <qg-signal gate="2" verdict="PASS_WITH_WARNINGS" '
            'summary="User accepted findings" files_changed="" />\n'
            '- Abort: emit <qg-signal action="abort" reason="User chose to abort" />\n'
        ),
    },
}


def build_special_prompt(transition_type, state, gate_results, prompt_key=None):
    """Build prompts for special situations (user choices, gate failures).

    transition_type: the transition["type"] value.
    prompt_key: optional sub-key (currently used to disambiguate
                gate2_user_choice into gate2_needs_restart /
                gate2_repeat_detected; absent → generic gate2_user_choice).
    """
    if transition_type == "gate2_user_choice":
        key = ("gate2_user_choice", prompt_key)
        entry = _SPECIAL_PROMPTS.get(key) or _SPECIAL_PROMPTS[("gate2_user_choice", None)]
    else:
        entry = _SPECIAL_PROMPTS.get(transition_type)

    if entry is None:
        # SF-3: unknown transition_type. Should be unreachable — every type
        # in the dispatch set must have a branch above. Fail loudly rather
        # than producing a blank prompt that would confuse the user.
        print(
            f"⚠️  Quality Gates: build_special_prompt: unhandled transition_type "
            f"'{transition_type}' (prompt_key={prompt_key!r})",
            file=sys.stderr,
        )
        return (
            f"PIPELINE_ERROR\n\nQuality Gates reached an unhandled transition state: "
            f"'{transition_type}'. This is a programming error.\n\n"
            "Please run `/cancel-qg` and re-run `/qg` from scratch.\n\n"
            '- Recovery: emit <qg-signal action="abort" reason="unhandled transition: '
            f"{transition_type}\" />"
        )

    fmt = {
        "max_gate2_iterations": state.get("max_gate2_iterations", 5),
        "gate3_resolution_iter": state.get("gate3_resolution_iter", 0),
        "max_gate3_resolutions": state.get("max_gate3_resolutions", 3),
    }
    return (
        f"{entry['header']}\n\n"
        f"{entry['body'].format(**fmt)}"
        f"\nPipeline context:\n{gate_results}"
    )
```

- [ ] **Step 3: Run the new unit tests**

Run:
```bash
cd plugins/quality-gates
python3 tests/test_stop_hook_unit.py
```
Expected: PASS — all invariants preserved.

- [ ] **Step 4: Run the full Python test suite**

Run:
```bash
for t in tests/test_*.py; do python3 "$t" || { echo "FAIL: $t"; exit 1; }; done
```
Expected: all pass.

- [ ] **Step 5: Measure LoC for AC9**

Run:
```bash
awk '/^def build_special_prompt/{f=1; n=0} f{n++; if(/^def [a-z_]+\(/ && !/^def build_special_prompt/){print "AFTER:", n-1; exit}}' \
  plugins/quality-gates/hooks/stop-hook.py
```
Expected: `AFTER: <= 80`. (The function body itself is small now; the data lives in the module-level `_SPECIAL_PROMPTS` dict above it.)

- [ ] **Step 6: Commit**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-forward-only-cleanup
git add plugins/quality-gates/hooks/stop-hook.py
git commit -m "$(cat <<'EOF'
refactor(qg): template build_special_prompt around a per-case dict

D2.b of v1.10.0 cleanup. The 6-case ladder (~146 LoC) becomes:
- module-level _SPECIAL_PROMPTS dict (header + body per case, with
  format-string placeholders for state-derived numbers)
- 30-line build_special_prompt that looks up the entry, formats it,
  and appends the pipeline-context tail

Semantics preserved (test_stop_hook_unit.py invariants all pass):
each case has its exact case-tag header, >=2 <qg-signal directives,
an abort option, >200 chars, and unknown transitions still return
the precise 'PIPELINE_ERROR\n\n' prefix.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: D3 — Extract `emit_continuation` helper from `main()`

**Files:**
- Modify: `plugins/quality-gates/hooks/stop-hook.py` (lines ~870–942, the 5 transition-handler branches in `main()`)

- [ ] **Step 1: Capture baseline transition-handler LoC**

Run:
```bash
awk '/# 9\. Handle completion\/abort/{f=1; n=0} f{n++} /# 13\. Build next gate prompt/{if(f){print "BEFORE main handler:", n; exit}}' \
  plugins/quality-gates/hooks/stop-hook.py
```
Expected: `BEFORE main handler: ~73`.

- [ ] **Step 2: Add the `emit_continuation` helper before `main()`**

In `plugins/quality-gates/hooks/stop-hook.py`, insert this helper directly above `def main():`:

```python
def emit_continuation(prompt, sys_msg):
    """Emit a Stop-hook 'block' decision and exit(0).

    Centralizes the print(json.dumps({...})) + sys.exit(0) boilerplate
    that the main() transition handlers all share.
    """
    print(json.dumps({
        "decision": "block",
        "reason": prompt,
        "systemMessage": sys_msg,
    }))
    sys.exit(0)
```

- [ ] **Step 3: Rewrite the transition-handler block of `main()`**

Replace the current section that begins with `# 9. Handle completion/abort` and ends after `# 13. Build next gate prompt` with this single, helper-driven block:

```python
    # 9. Handle completion/abort — remove session folder entirely and allow exit.
    if transition["type"] in ("complete", "abort"):
        folder = os.path.dirname(state_file)
        shutil.rmtree(folder, ignore_errors=True)
        sys.exit(0)

    # 10. Resolve prompt + sys_msg for every remaining transition shape, then
    #     hand off to emit_continuation. Cases share the same trailer
    #     (block decision + system message), differing only in how the next
    #     prompt is constructed.
    USER_CHOICE_TYPES = {
        "gate2_user_choice", "max_gate2_exceeded", "gate3_fail",
        "gate3_needs_resolution", "gate3_repeat_detected",
    }

    if transition["type"] in USER_CHOICE_TYPES:
        prompt = build_special_prompt(
            transition["type"], state, gate_results,
            prompt_key=transition.get("prompt_key"),
        )
    elif transition["type"] == "next_gate":
        next_state, next_body = parse_state_file(state_file)
        if next_state:
            prompt = build_gate_prompt(transition["next_gate"], next_state,
                                       extract_gate_results(next_body))
        else:
            prompt = build_gate_prompt(transition["next_gate"], state, gate_results)
    elif transition["type"] == "retry_gate":
        retry_gate = transition.get("gate", state["current_gate"])
        next_state, next_body = parse_state_file(state_file)
        if next_state:
            prompt = build_gate_prompt(retry_gate, next_state,
                                       extract_gate_results(next_body))
        else:
            prompt = build_gate_prompt(retry_gate, state, gate_results)
    elif transition["type"] in ("continue", "extend"):
        # Scout fallback or capacity extension — re-inject the current gate
        # prompt. (extend is kept reachable for forward-compat even though
        # compute_transition does not currently emit it.)
        next_state, next_body = (parse_state_file(state_file)
                                 if transition["type"] == "extend"
                                 else (None, None))
        the_state = next_state or state
        the_results = (extract_gate_results(next_body) if next_body
                       else gate_results)
        prompt = build_gate_prompt(the_state["current_gate"], the_state, the_results)
    else:
        # Defensive fallback: unknown transition — re-inject current gate.
        prompt = build_gate_prompt(state["current_gate"], state, gate_results)

    sys_msg = build_system_message(state, transition)
    emit_continuation(prompt, sys_msg)
```

- [ ] **Step 4: Run the full test suite**

Run:
```bash
cd plugins/quality-gates
for t in tests/test_*.py; do python3 "$t" || { echo "FAIL: $t"; exit 1; }; done
for t in tests/test_*.sh; do bash "$t" || true; done   # prose still failing
echo "Python tests done."
```
Expected: All Python tests PASS. `test_forward_only_prose.sh` still FAILs on AC1-6 (prose drift comes in Task 10).

- [ ] **Step 5: Measure post-refactor LoC**

Run:
```bash
awk '/# 9\. Handle completion\/abort/{f=1; n=0} f{n++} /sys_msg = build_system_message\(state, transition\)/{if(f){print "AFTER main handler:", n; exit}}' \
  plugins/quality-gates/hooks/stop-hook.py
wc -l plugins/quality-gates/hooks/stop-hook.py
```
Expected: `AFTER main handler: <= 35` and `wc -l <= 800`.

- [ ] **Step 6: Commit**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-forward-only-cleanup
git add plugins/quality-gates/hooks/stop-hook.py
git commit -m "$(cat <<'EOF'
refactor(qg): extract emit_continuation helper from main()

D3 of v1.10.0 cleanup. main()'s transition-handler ladder (~73 LoC,
five near-identical `print(json.dumps({...})); sys.exit(0)` blocks)
collapses into a single dispatch block followed by one
emit_continuation() call.

The next-prompt builder is selected by transition type but the
'block' decision + systemMessage trailer is unified. Existing tests
preserve current dispatch behavior; LoC budgets per AC10/AC11 met.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: D4.a — SKILL.md prose drift fix (5 sites)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` (lines 15, 749–752+757, 778, 1131–1141, 1200–1206)

This task contains five small edits to the same file. Each step is one edit + a focused verification.

- [ ] **Step 1: Site #1 — header line 15 ("loop-back" → forward-only language)**

In `plugins/quality-gates/skills/quality-pipeline/SKILL.md`, replace:

```
You are executing a **single gate** of the quality pipeline. The Stop hook manages
pipeline progression (gate-to-gate transitions, iteration counting, loop-back on
code changes). You do NOT manage state files or pipeline flow.
```

with:

```
You are executing a **single gate** of the quality pipeline. The Stop hook
manages pipeline progression (gate-to-gate transitions and within-Gate-2
iteration counting). The pipeline is **forward-only**: code-change verdicts
(`NEEDS_RESTART`) terminate with a user-choice prompt rather than auto-restarting
from Gate 1. You do NOT manage state files or pipeline flow.
```

- [ ] **Step 2: Site #2 — Gate 2 output block at lines 749–752+757**

Replace:

```
### Verdict: [PASS / FAIL / NEEDS_RESTART]
[If PASS: "All critical and important issues resolved."]
[If FAIL: "N issues remain after max iterations."]
[If NEEDS_RESTART: "Code was changed during fixes. Pipeline should restart from Gate 1."]
```

with:

```
### Verdict: [PASS / FAIL / NEEDS_RESTART]
[If PASS: "All critical and important issues resolved."]
[If FAIL: "N issues remain after max iterations."]
[If NEEDS_RESTART: "Code was changed during fixes. The pipeline is forward-only — it halts with a user-choice prompt rather than auto-restarting from Gate 1. The user applies the fixes and re-runs /qg."]
```

Also replace the header line a few lines below:

```
## Gate 2: PR Review (iter [iteration]) — [PASS/FAIL/NEEDS_RESTART]
```

(no change needed to this header — it already lists `NEEDS_RESTART` accurately as a verdict tag).

- [ ] **Step 3: Site #3 — Gate 2 Rules line 778**

Replace:

```
- If you changed code, your verdict MUST be `NEEDS_RESTART` (not `PASS`), so Gate 1 can re-verify
```

with:

```
- If you changed code, your verdict MUST be `NEEDS_RESTART` (not `PASS`) — the Stop hook halts the pipeline with a user-choice prompt so the user can re-run `/qg` after applying fixes. The pipeline does NOT auto-restart from Gate 1
```

- [ ] **Step 4: Site #4 — GATE3_FAIL prompt at lines 1131–1141**

Replace:

```
### GATE3_FAIL

Gate 3 failed. Present:
1. **Fix issues** (will restart from Gate 1)
2. **Skip** runtime verification
3. **Abort** pipeline

Based on choice:
- Fix: fix the issues, then `<qg-signal gate="3" verdict="NEEDS_RESTART" summary="Fixed runtime issues" files_changed="list,of,changed,files" />`
- Skip: `<qg-signal gate="3" verdict="SKIP" summary="User chose to skip" files_changed="" />`
- Abort: `<qg-signal action="abort" reason="User chose to abort" />`
```

with:

```
### GATE3_FAIL

Gate 3 failed. The pipeline is forward-only and does not auto-restart from Gate 1; the user applies fixes and re-runs `/qg`. Present:
1. **Fix and re-run /qg** — apply fixes; pipeline terminates so the user can re-run /qg manually
2. **Skip** runtime verification
3. **Abort** pipeline

Based on choice:
- Fix: inform the user to apply fixes and re-run /qg, then `<qg-signal action="abort" reason="User will re-run /qg after fixes" />`
- Skip: `<qg-signal gate="3" verdict="SKIP" summary="User chose to skip" files_changed="" />`
- Abort: `<qg-signal action="abort" reason="User chose to abort" />`
```

- [ ] **Step 5: Site #5 — Verdict definitions at lines 1200–1206**

Replace:

```
Verdict values:
- `PASS` — Gate succeeded, no issues
- `FAIL` — Gate failed, issues remain
- `SKIP` — Gate skipped (no plan file, non-web project, etc.)
- `NEEDS_RESTART` — Code was changed, pipeline should restart from Gate 1
- `PASS_WITH_WARNINGS` — Gate passed with non-blocking warnings
- `RETRY` — Gate needs to re-run (Gate 1 implemented missing items)
```

with:

```
Verdict values:
- `PASS` — Gate succeeded, no issues
- `FAIL` — Gate failed, issues remain
- `SKIP` — Gate skipped (no plan file, non-web project, etc.)
- `NEEDS_RESTART` — Code was changed during fixes. Pipeline halts with a Stop-hook user-choice prompt; the user applies fixes and re-runs `/qg`. The pipeline does **not** auto-restart from Gate 1 (forward-only state machine, v1.5.0+).
- `PASS_WITH_WARNINGS` — Gate passed with non-blocking warnings
- `RETRY` — Gate needs to re-run (Gate 1 implemented missing items)
```

- [ ] **Step 6: Verify prose regression test partially passes**

Run:
```bash
bash plugins/quality-gates/tests/test_forward_only_prose.sh
```
Expected: AC1–AC2 PASS (forbidden phrases gone), AC3 still FAILs only if `references/state-file-format.md` still has the `Restarting from Gate 1` example log line. AC4–AC6 PASS. AC8 + NG7 PASS from earlier tasks.

- [ ] **Step 7: Commit**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-forward-only-cleanup
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md
git commit -m "$(cat <<'EOF'
docs(qg): align SKILL.md prose with v1.5.0 forward-only state machine

D4.a of v1.10.0 cleanup. Five SKILL.md prose sites carried the
pre-v1.5.0 cross-gate-restart vocabulary even though the stop-hook
runtime had been forward-only for a year:

- Header (L15): 'loop-back on code changes' → forward-only language
- Gate 2 output (L749-752): NEEDS_RESTART description now matches
  Stop-hook user-choice prompt behavior
- Gate 2 rules (L778): clarifies the Stop hook handoff, not auto-restart
- GATE3_FAIL prompt (L1131-1141): option 1 relabeled
  'Fix and re-run /qg' (matches stop-hook.py:663 build_special_prompt)
- Verdict definition (L1200-1206): NEEDS_RESTART is now defined as
  forward-only with explicit 'does not auto-restart from Gate 1'

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: D4.b — `state-file-format.md` example history log

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md` (lines 60–64 example history block)

- [ ] **Step 1: Edit the example log block**

Replace:

```
## Pipeline History
- [2026-04-12T10:00:00Z] Pipeline started (iteration 1)
- [2026-04-12T10:02:00Z] Gate 1: PASS
- [2026-04-12T10:05:00Z] Gate 2 iter 1: FAIL
- [2026-04-12T10:08:00Z] Gate 2 iter 2: NEEDS_RESTART
- [2026-04-12T10:08:00Z] Restarting from Gate 1 (iteration 2)
```

with:

```
## Pipeline History
- [2026-04-12T10:00:00Z] Pipeline started
- [2026-04-12T10:02:00Z] Gate 1: PASS
- [2026-04-12T10:05:00Z] Gate 2 iter 1: FAIL
- [2026-04-12T10:08:00Z] Gate 2 iter 2: NEEDS_RESTART → user-choice (terminate; user re-runs /qg)
```

- [ ] **Step 2: Run the full prose regression test — expect ALL PASS now**

Run:
```bash
bash plugins/quality-gates/tests/test_forward_only_prose.sh
```
Expected: `test_forward_only_prose.sh: PASS` — all AC1–AC8 and NG7 green.

- [ ] **Step 3: Run every test once**

Run:
```bash
cd plugins/quality-gates
for t in tests/test_*.sh; do bash "$t" || { echo "FAIL: $t"; exit 1; }; done
for t in tests/test_*.py; do python3 "$t" || { echo "FAIL: $t"; exit 1; }; done
echo "ALL GREEN"
```
Expected: `ALL GREEN`.

- [ ] **Step 4: Commit**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-forward-only-cleanup
git add plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md
git commit -m "$(cat <<'EOF'
docs(qg): forward-only example log in state-file-format.md

D4.b of v1.10.0 cleanup. The example Pipeline History log still
showed 'Restarting from Gate 1 (iteration 2)' as if a NEEDS_RESTART
verdict would auto-loop back to Gate 1. Under the v1.5.0 forward-only
machine the actual log line ends at 'user-choice (terminate; user
re-runs /qg)'.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Version bump + CHANGELOG entry

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`
- Modify: `plugins/quality-gates/CHANGELOG.md`

- [ ] **Step 1: Bump `plugin.json`**

In `plugins/quality-gates/.claude-plugin/plugin.json`, replace:

```json
  "version": "1.9.0",
```

with:

```json
  "version": "1.10.0",
```

- [ ] **Step 2: Prepend the new CHANGELOG section**

Insert this block in `plugins/quality-gates/CHANGELOG.md` directly above the `## [1.9.0]` heading:

```markdown
## [1.10.0] — 2026-05-13

### Changed
- **SKILL.md prose** aligned with the v1.5.0 forward-only state machine.
  Five sites in `skills/quality-pipeline/SKILL.md` had carried the pre-1.5.0
  "auto-restart from Gate 1" vocabulary; they now describe the actual
  Stop-hook behavior (user-choice prompt; user re-runs `/qg`).
- **`GATE3_FAIL` prompt option 1 label** is now
  `"Fix and re-run /qg"` (was `"Fix issues (will restart from Gate 1)"`).
  User-visible string change; semantics already matched the new label since
  v1.5.0.
- **Example history log** in `references/state-file-format.md` no longer
  shows `Restarting from Gate 1 (iteration 2)` — replaced with the
  forward-only termination line.

### Removed
- **`total_iterations` / `max_total_iterations`** state-file fields. Deprecated
  in v1.5.0, never written since, and (as discovered while preparing this
  release) the `extend` branch in `update_state_file` that incremented
  `new_max_total` was already a dead write because `max_total_iterations`
  had been absent from the `replacements` dict for a year. Removed from
  `parse_state_file`, `update_state_file`, schema doc, and three fixture
  files. The `test_no_max_total_iterations_constant` gate test is preserved.

### Fixed
- **Doc-vs-code drift**: SKILL.md verdict definitions, GATE3_FAIL prompt,
  and Gate 2 output format no longer mis-instruct reviewers that the
  pipeline auto-restarts from Gate 1. Locked by the new
  `tests/test_forward_only_prose.sh` grep guard (AC1–AC8 + NG7).

### Internal
- **`build_special_prompt`** refactored from a 6-case if/elif ladder
  (~146 LoC) to a `_SPECIAL_PROMPTS` per-case dict + a 30-line dispatcher.
  Semantics preserved; locked by `tests/test_stop_hook_unit.py`.
- **`main()` transition-handler** collapses ~73 LoC of duplicated
  `print(json.dumps({...})); sys.exit(0)` blocks into a single
  `emit_continuation` helper called after a small prompt-selector block.
- **`hooks/stop-hook.py` LoC**: before ≈ 960, after ≤ 800.

### Notes
- Stop-hook itself remains. The spec's "Stop-hook review" section enumerates
  6 responsibilities (turn-boundary auto-progression, multi-turn Gate 2
  fix-loop, user-choice prompt injection, state-file management, repeat
  detection invariant, mid-session cleanup); none can be moved into the
  skill without losing automatic continuation or the code-enforced
  AP15 *"loop without repeat detection"* guard.

```

(Leave the existing `## [1.9.0]` and earlier entries unchanged.)

- [ ] **Step 3: Run the full test suite once more**

Run:
```bash
cd plugins/quality-gates
for t in tests/test_*.sh; do bash "$t" || { echo "FAIL: $t"; exit 1; }; done
for t in tests/test_*.py; do python3 "$t" || { echo "FAIL: $t"; exit 1; }; done
echo "ALL GREEN"
```
Expected: `ALL GREEN`.

- [ ] **Step 4: Commit**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-forward-only-cleanup
git add plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md
git commit -m "$(cat <<'EOF'
chore(qg): bump version 1.9.0 → 1.10.0 + CHANGELOG entry

Bundles D1 (deprecated total_iterations / max_total_iterations
removal incl. dead extend write), D2 (build_special_prompt template),
D3 (emit_continuation helper), D4 (SKILL.md + state-file-format.md
prose drift fix) into a single minor release.

CHANGELOG documents prose-vs-code drift discovery, the dead extend
write, and the stop-hook 6-responsibility re-evaluation.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Final verification

**Files:** (read-only)

- [ ] **Step 1: Final LoC check (AC11)**

Run:
```bash
wc -l plugins/quality-gates/hooks/stop-hook.py
```
Expected: `<= 800` (was 960 before D1+D2+D3).

- [ ] **Step 2: Final grep guard run**

Run:
```bash
bash plugins/quality-gates/tests/test_forward_only_prose.sh
```
Expected: `test_forward_only_prose.sh: PASS`.

- [ ] **Step 3: Full test sweep**

Run:
```bash
cd plugins/quality-gates
for t in tests/test_*.sh; do bash "$t" || { echo "FAIL: $t"; exit 1; }; done
for t in tests/test_*.py; do python3 "$t" || { echo "FAIL: $t"; exit 1; }; done
echo "ALL GREEN"
```
Expected: `ALL GREEN`.

- [ ] **Step 4: Manual sanity grep for required phrases (AC4–AC6 spot-check)**

Run:
```bash
cd plugins/quality-gates
grep -n 'forward-only' skills/quality-pipeline/SKILL.md
grep -c 'Fix and re-run /qg' skills/quality-pipeline/SKILL.md
grep -cE 'does (not|NOT) auto-restart' skills/quality-pipeline/SKILL.md
```
Expected: at least 1, exactly 1, at least 2 (respectively).

- [ ] **Step 5: PR-readiness summary**

Print a short summary the human can paste into a PR description (Task 13 covers actual PR creation, which is out of this plan's scope):

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-forward-only-cleanup
git log --oneline origin/main..HEAD
echo "---"
echo "stop-hook.py LoC: $(wc -l < plugins/quality-gates/hooks/stop-hook.py)"
echo "test_forward_only_prose.sh:"
bash plugins/quality-gates/tests/test_forward_only_prose.sh | tail -1
```
Expected: 11 commits ahead of `origin/main` (the spec round-1 and round-2 commits + 9 implementation commits), LoC ≤ 800, prose guard PASS.

- [ ] **Step 6: Hand off to the human**

The work is done. The human reviews the commits, opens the PR (`fix/qg-forward-only-cleanup` → `main`), and merges according to the project's GitHub Flow. Do not push or open the PR autonomously — that's a deliberate human-in-the-loop gate.

---

## Self-Review Notes (2026-05-13)

- **Spec coverage:** Each G1–G9 acceptance criterion maps to at least one task.
  - G1–G4 (prose) → Task 9 + Task 10.
  - G5 (deprecated field removal incl. dead `extend` write) → Tasks 2, 3, 4, 5.
  - G6 (`build_special_prompt` template) → Tasks 6, 7.
  - G7 (`main()` helper) → Task 8.
  - G8 (regression guard) → Task 1.
  - G9 (LoC measurement) → Task 12.
- **No placeholders:** every step has either an exact code block or an exact command with expected output.
- **Type / name consistency:** `emit_continuation`, `_SPECIAL_PROMPTS`, `build_special_prompt`, `build_gate_prompt`, `build_system_message`, `parse_state_file`, `update_state_file`, `extract_gate_results` — these names appear identically in the relevant tasks.
- **Reviewer's `extend` concern:** Task 3 confirms the `extend` branch is unreachable today (`compute_transition` never emits it) AND silently no-op (the `+= additional` never landed in `replacements`). Task 8 keeps `extend` reachable in `main()` for forward-compat without restoring the dead write. If a future patch wants to re-introduce capacity extension, it adds back the persistence step deliberately — not through a years-old undead code path.
- **Bisect-ability:** 9 implementation commits (Tasks 1–11), each independently runnable through the test suite. Task ordering D1 → D2 → D3 → D4 (per Rejected Alt F in the spec) is preserved in the commit graph.
