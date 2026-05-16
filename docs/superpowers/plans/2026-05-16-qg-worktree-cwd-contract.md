# quality-gates worktree cwd contract — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** quality-gates pipeline 전체에 `project_dir` 단일 좌표 계약을 강제해서 worktree 안에서 `/qg` 실행 시 subagent (특히 codex-reviewer) 가 main repo 가 아닌 worktree 를 정확히 review 하도록 fix.

**Architecture:** `project_dir` = SKILL preflight 시점 `pwd` 절대경로. setup-qg.sh 가 state file frontmatter 에 write → stop-hook 가 `build_gate_prompt()` 의 3개 gate 분기에서 read & inject → SKILL 의 모든 Agent() dispatch prompt 에 포함 → 각 agent.md 가 input contract 로 받음 → codex-reviewer bash 가 `cd "$project_dir"` 실행 후 `codex exec -C "$project_dir"` 호출. 모든 hook 은 stdin payload 의 `cwd` 키로 state 경로 정규화.

**Tech Stack:** Bash (scripts/hooks), Python 3 (hooks/tests), Markdown (agents/SKILL/CHANGELOG/spec), git worktree.

**Spec:** `docs/superpowers/specs/2026-05-16-qg-worktree-cwd-contract-design.md` (approved by spec-reviewer R3, stagnation false).

**Pre-implementation must-read** (per spec-reviewer R3 advisory): `hooks/stop-hook.py:103-140` — the `gate3_resolution_iter` backward-compat pattern. `project_dir` field fallback MUST replicate this pattern (graceful + stderr warning), NOT the `required_numeric` block (which returns `None, None` on failure). Wrong pattern = gate2/3 continuation hard-fail on legacy state files.

**File structure** (18 files touched):

| Layer | Files |
|---|---|
| State write | `scripts/setup-qg.sh` |
| State read + continuation | `hooks/stop-hook.py` |
| Hooks cwd normalization | `hooks/post-tool-use-session-tracker.py`, `hooks/session-start-advisor.py` |
| Agent input contracts | `agents/{scout,codex-reviewer,adversarial,synthesizer,test-scope-validator,security-reviewer}.md` |
| Dispatch propagation | `skills/quality-pipeline/SKILL.md` |
| Tests | `tests/{test_worktree.sh, test_codex_dispatch_invariant.sh, test_stop_hook_unit.py, test_hook_cwd_contract.py}` (last is new) |
| Release artifacts | `.claude-plugin/plugin.json`, `CHANGELOG.md`, `README.md` |

---

## Task 1: Add `project_dir` to state file schema (Phase A.1)

**Why first:** state file is the single source of truth for gate boundary propagation. Without it, every other fix has no value to read.

**Files:**
- Modify: `plugins/quality-gates/scripts/setup-qg.sh` (around L260)
- Modify: `plugins/quality-gates/tests/test_setup_qg.sh`

- [ ] **Step 1.1: Read current setup-qg.sh frontmatter write block**

Run: `sed -n '250,270p' plugins/quality-gates/scripts/setup-qg.sh`

Expected: lines 252-266 emit `---` frontmatter with keys `status`, `current_gate`, ..., `session_id`, `started_at`.

- [ ] **Step 1.2: Add failing test to test_setup_qg.sh**

Append (or insert before the final summary block) in `plugins/quality-gates/tests/test_setup_qg.sh`:

```bash
# --- Test: project_dir in state frontmatter (v1.13.0 AC6) ---
SID="proj-dir-test-01"
TMP=$(mktemp -d)
(
  cd "$TMP"
  CLAUDE_CODE_SESSION_ID="$SID" bash "$PLUGIN_DIR/scripts/setup-qg.sh" >/dev/null 2>&1
)
STATE_FILE="$TMP/.claude/quality-gates/$SID/pipeline.md"
if grep -q '^project_dir:' "$STATE_FILE" 2>/dev/null; then
  pass "project_dir present in state frontmatter"
else
  fail "project_dir missing from state frontmatter at $STATE_FILE"
fi

# Verify value equals invocation cwd
if grep -q "^project_dir: \"$TMP\"" "$STATE_FILE" 2>/dev/null; then
  pass "project_dir value equals invocation cwd"
else
  fail "project_dir value mismatch: expected \"$TMP\", got $(grep '^project_dir:' "$STATE_FILE")"
fi
rm -rf "$TMP"
```

- [ ] **Step 1.3: Run test, verify FAIL**

Run: `bash plugins/quality-gates/tests/test_setup_qg.sh 2>&1 | tail -20`
Expected: at least one `✗ FAIL: project_dir missing from state frontmatter` line.

- [ ] **Step 1.4: Patch setup-qg.sh frontmatter write**

In `plugins/quality-gates/scripts/setup-qg.sh`, find the heredoc block (around L252) that writes `---` ... `session_id: ...` ... `started_at: ...` ... `---`. Add `project_dir: "$(pwd)"` line right before `session_id: "$SESSION_ID"`:

```bash
session_id: "$SESSION_ID"
```

becomes:

```bash
project_dir: "$(pwd)"
session_id: "$SESSION_ID"
```

- [ ] **Step 1.5: Run test, verify PASS**

Run: `bash plugins/quality-gates/tests/test_setup_qg.sh 2>&1 | tail -10`
Expected: both `project_dir present` and `project_dir value equals invocation cwd` PASS, and final `Results: N passed, 0 failed`.

- [ ] **Step 1.6: Commit**

```bash
git add plugins/quality-gates/scripts/setup-qg.sh plugins/quality-gates/tests/test_setup_qg.sh
git commit -m "$(cat <<'EOF'
feat(qg): persist project_dir in state frontmatter (B6 AC6)

setup-qg.sh writes project_dir=$(pwd) to state file so stop-hook can
inject it into gate continuation prompts, preventing main-repo drift
when /qg runs inside a git worktree.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Parse `project_dir` in stop-hook (Phase A.2)

**Why:** state file now has the field; parser must surface it to downstream consumers.

**Files:**
- Modify: `plugins/quality-gates/hooks/stop-hook.py` (around L139, after `last_gate3_needed_hash` block)
- Modify: `plugins/quality-gates/tests/test_stop_hook_unit.py`

- [ ] **Step 2.1: Read existing fallback pattern as reference**

Run: `sed -n '109,142p' plugins/quality-gates/hooks/stop-hook.py`

Expected: `gate3_resolution_iter` / `max_gate3_resolutions` / `last_gate3_needed_hash` fallback pattern — replicate this exactly (graceful + stderr warning).

- [ ] **Step 2.2: Add failing test to test_stop_hook_unit.py**

Append to `plugins/quality-gates/tests/test_stop_hook_unit.py` (or add new test function):

```python
def test_parse_state_file_reads_project_dir(tmp_path, capsys):
    """parse_state_file surfaces project_dir from frontmatter (AC6)."""
    state_file = tmp_path / "pipeline.md"
    state_file.write_text("""---
status: gate1_running
current_gate: 1
gate2_iteration: 0
max_gate2_iterations: 5
gate3_resolution_iter: 0
last_gate3_needed_hash: ""
max_gate3_resolutions: 3
skip_runtime: false
single_gate: null
plan_file: "auto"
pr_url: ""
available_plugins: ""
project_dir: "/Users/test/myproject/wt-feat"
session_id: "abc123def456"
started_at: "2026-05-16T10:00:00Z"
---

# state body
""")
    state, body = parse_state_file(str(state_file))
    assert state is not None
    assert state["project_dir"] == "/Users/test/myproject/wt-feat"


def test_parse_state_file_missing_project_dir_falls_back_to_cwd(tmp_path, capsys, monkeypatch):
    """v1.12.x state file lacks project_dir — fallback to os.getcwd() + stderr warning."""
    monkeypatch.chdir(tmp_path)
    state_file = tmp_path / "pipeline.md"
    state_file.write_text("""---
status: gate1_running
current_gate: 1
gate2_iteration: 0
max_gate2_iterations: 5
gate3_resolution_iter: 0
last_gate3_needed_hash: ""
max_gate3_resolutions: 3
skip_runtime: false
single_gate: null
plan_file: "auto"
pr_url: ""
available_plugins: ""
session_id: "abc123def456"
started_at: "2026-05-16T10:00:00Z"
---

# state body
""")
    state, body = parse_state_file(str(state_file))
    assert state is not None
    assert state["project_dir"] == str(tmp_path)
    captured = capsys.readouterr()
    assert "state file lacks project_dir" in captured.err
```

- [ ] **Step 2.3: Run test, verify FAIL**

Run: `python3 -m pytest plugins/quality-gates/tests/test_stop_hook_unit.py -k project_dir -v 2>&1 | tail -15`

Expected: 2 tests FAIL with `KeyError: 'project_dir'` or `assert ... in state` style errors.

- [ ] **Step 2.4: Patch parse_state_file**

In `plugins/quality-gates/hooks/stop-hook.py`, find the block ending with the `last_gate3_needed_hash` fallback (around L139-140):

```python
    if "last_gate3_needed_hash" not in state:
        state["last_gate3_needed_hash"] = ""
```

Add immediately after it (before the `# Convert boolean fields` comment):

```python
    # Backward compatibility for v1.12.x → v1.13.0:
    # - project_dir added in v1.13.0 to freeze pipeline coordinate at preflight.
    # If absent (legacy state file), default to current process cwd so the
    # pipeline continues rather than silently corrupting state. This mirrors
    # the gate3_resolution_iter pattern above (per spec-reviewer R3 advisory).
    if "project_dir" not in state or not state.get("project_dir"):
        state["project_dir"] = os.getcwd()
        print("⚠️  Quality Gates: state file lacks project_dir (v1.12.x schema?); "
              "defaulting to current process cwd",
              file=sys.stderr)
```

- [ ] **Step 2.5: Run test, verify PASS**

Run: `python3 -m pytest plugins/quality-gates/tests/test_stop_hook_unit.py -k project_dir -v 2>&1 | tail -10`

Expected: 2 tests PASS.

- [ ] **Step 2.6: Commit**

```bash
git add plugins/quality-gates/hooks/stop-hook.py plugins/quality-gates/tests/test_stop_hook_unit.py
git commit -m "$(cat <<'EOF'
feat(qg): parse project_dir from state with v1.12.x fallback (B6 AC6)

parse_state_file now surfaces project_dir to gate-continuation consumers;
missing field (legacy state) falls back to os.getcwd() + stderr warning,
mirroring the gate3_resolution_iter backward-compat pattern.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Inject `project_dir` into `build_gate_prompt` (Phase A.3)

**Why:** the load-bearing fix for B6 — without this, gate2/3 continuations re-evaluate cwd in SKILL and lose worktree context.

**Files:**
- Modify: `plugins/quality-gates/hooks/stop-hook.py` (build_gate_prompt at L525-587)
- Modify: `plugins/quality-gates/tests/test_stop_hook_unit.py`

- [ ] **Step 3.1: Add failing test**

Append to `plugins/quality-gates/tests/test_stop_hook_unit.py`:

```python
def test_build_gate_prompt_injects_project_dir_gate1():
    state = {
        "plan_file": "auto",
        "pr_url": "",
        "available_plugins": "pr-review-toolkit",
        "gate2_iteration": 1,
        "max_gate2_iterations": 5,
        "project_dir": "/Users/test/wt-feat",
        "skip_runtime": False,
        "max_gate3_resolutions": 3,
    }
    prompt = build_gate_prompt(1, state, "")
    assert "project_dir: /Users/test/wt-feat" in prompt


def test_build_gate_prompt_injects_project_dir_gate2():
    state = {
        "plan_file": "auto",
        "pr_url": "https://example.com/pr/1",
        "available_plugins": "pr-review-toolkit",
        "gate2_iteration": 2,
        "max_gate2_iterations": 5,
        "project_dir": "/Users/test/wt-feat",
        "skip_runtime": False,
        "max_gate3_resolutions": 3,
    }
    prompt = build_gate_prompt(2, state, "")
    assert "project_dir: /Users/test/wt-feat" in prompt


def test_build_gate_prompt_injects_project_dir_gate3():
    state = {
        "plan_file": "auto",
        "pr_url": "",
        "available_plugins": "pr-review-toolkit",
        "gate2_iteration": 1,
        "max_gate2_iterations": 5,
        "project_dir": "/Users/test/wt-feat",
        "skip_runtime": False,
        "max_gate3_resolutions": 3,
        "gate3_resolution_iter": 0,
    }
    prompt = build_gate_prompt(3, state, "")
    assert "project_dir: /Users/test/wt-feat" in prompt
```

- [ ] **Step 3.2: Run test, verify FAIL**

Run: `python3 -m pytest plugins/quality-gates/tests/test_stop_hook_unit.py -k build_gate_prompt_injects_project_dir -v 2>&1 | tail -15`

Expected: 3 tests FAIL with `assert 'project_dir: /Users/test/wt-feat' in <prompt without that line>`.

- [ ] **Step 3.3: Patch build_gate_prompt — gate 1 branch**

In `plugins/quality-gates/hooks/stop-hook.py`, find the gate 1 prompt construction (around L535-542). Locate the line:

```python
        prompt_parts.append(
            "Execute Quality Gates - Gate 1 (Plan Verification).\n\n"
            "Parameters:\n"
            f"  gate: 1\n"
            f"  plan_path: {plan_file}\n"
            f"  available_plugins: {available_plugins}\n"
        )
```

Replace with:

```python
        prompt_parts.append(
            "Execute Quality Gates - Gate 1 (Plan Verification).\n\n"
            "Parameters:\n"
            f"  gate: 1\n"
            f"  plan_path: {plan_file}\n"
            f"  project_dir: {state.get('project_dir', os.getcwd())}\n"
            f"  available_plugins: {available_plugins}\n"
        )
```

- [ ] **Step 3.4: Patch build_gate_prompt — gate 2 branch**

Find the gate 2 prompt construction (around L553-564). Locate:

```python
        prompt_parts.append(
            f"Execute Quality Gates - Gate 2 (PR Review), "
            f"iteration {gate2_iteration}/{max_gate2}.\n\n"
            "Parameters:\n"
            f"  gate: 2\n"
            f"  pr_url: {pr_url}\n"
            f"  iteration: {gate2_iteration}\n"
            f"  max_iterations: {max_gate2}\n"
            f"  previous_findings: {prev_findings}\n"
            f"  available_plugins: {available_plugins}\n"
            f"  plan_path: {plan_file}\n"
        )
```

Add `project_dir` line after `plan_path`:

```python
        prompt_parts.append(
            f"Execute Quality Gates - Gate 2 (PR Review), "
            f"iteration {gate2_iteration}/{max_gate2}.\n\n"
            "Parameters:\n"
            f"  gate: 2\n"
            f"  pr_url: {pr_url}\n"
            f"  iteration: {gate2_iteration}\n"
            f"  max_iterations: {max_gate2}\n"
            f"  previous_findings: {prev_findings}\n"
            f"  available_plugins: {available_plugins}\n"
            f"  plan_path: {plan_file}\n"
            f"  project_dir: {state.get('project_dir', os.getcwd())}\n"
        )
```

- [ ] **Step 3.5: Patch build_gate_prompt — gate 3 branch**

Find the gate 3 `elif gate_num == 3:` block (search `gate_num == 3` in stop-hook.py). Add the same `project_dir` line inside the parameter list, before the closing `)`.

If the current gate 3 block looks like:

```python
    elif gate_num == 3:
        prompt_parts.append(
            "Execute Quality Gates - Gate 3 (Runtime Verification).\n\n"
            "Parameters:\n"
            f"  gate: 3\n"
            f"  plan_path: {plan_file}\n"
            f"  available_plugins: {available_plugins}\n"
        )
```

Replace with:

```python
    elif gate_num == 3:
        prompt_parts.append(
            "Execute Quality Gates - Gate 3 (Runtime Verification).\n\n"
            "Parameters:\n"
            f"  gate: 3\n"
            f"  plan_path: {plan_file}\n"
            f"  project_dir: {state.get('project_dir', os.getcwd())}\n"
            f"  available_plugins: {available_plugins}\n"
        )
```

(If the actual block differs, preserve all existing parameters and add only the `project_dir` line.)

- [ ] **Step 3.6: Run test, verify PASS**

Run: `python3 -m pytest plugins/quality-gates/tests/test_stop_hook_unit.py -k build_gate_prompt_injects_project_dir -v 2>&1 | tail -10`

Expected: 3 tests PASS.

- [ ] **Step 3.7: Run full stop-hook test suite for regression**

Run: `python3 -m pytest plugins/quality-gates/tests/test_stop_hook_unit.py -v 2>&1 | tail -20`

Expected: all tests PASS (no regression in existing transition logic tests).

- [ ] **Step 3.8: Commit**

```bash
git add plugins/quality-gates/hooks/stop-hook.py plugins/quality-gates/tests/test_stop_hook_unit.py
git commit -m "$(cat <<'EOF'
feat(qg): inject project_dir into gate continuation prompts (B6 AC6)

build_gate_prompt() now emits project_dir in all three gate branches
(1/2/3), reading the value from state["project_dir"] with os.getcwd()
fallback. This closes the gate-boundary cwd-loss gap that allowed
worktree-launched pipelines to re-evaluate cwd in main repo at gate
transitions.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Normalize stop-hook state path via payload cwd (Phase B.1)

**Why:** B1 fix. stop-hook currently uses `ROOT = ".claude/quality-gates"` (relative), which resolves against process cwd — when hook fires from main repo cwd while pipeline state lives in worktree, hook can't find state file.

**Files:**
- Modify: `plugins/quality-gates/hooks/stop-hook.py` (L32, L35-36, L826 call site)
- Modify: `plugins/quality-gates/tests/test_stop_hook_unit.py`

- [ ] **Step 4.1: Add failing test**

Append to `plugins/quality-gates/tests/test_stop_hook_unit.py`:

```python
import io

def test_state_root_uses_payload_cwd(tmp_path):
    """_state_root reads payload cwd, ignoring process cwd."""
    hook_input = {"cwd": str(tmp_path)}
    root = _state_root(hook_input)
    assert root == tmp_path / ".claude" / "quality-gates"


def test_state_root_falls_back_to_getcwd_with_warning(capsys, monkeypatch, tmp_path):
    """Missing cwd in payload triggers stderr warning + os.getcwd() fallback."""
    monkeypatch.chdir(tmp_path)
    hook_input = {}  # missing cwd
    root = _state_root(hook_input)
    assert root == tmp_path / ".claude" / "quality-gates"
    captured = capsys.readouterr()
    assert "stop-hook payload missing 'cwd'" in captured.err
```

- [ ] **Step 4.2: Run test, verify FAIL**

Run: `python3 -m pytest plugins/quality-gates/tests/test_stop_hook_unit.py -k state_root -v 2>&1 | tail -10`

Expected: 2 tests FAIL with `NameError: name '_state_root' is not defined`.

- [ ] **Step 4.3: Add `_state_root` helper and update `state_file_for` signature**

In `plugins/quality-gates/hooks/stop-hook.py`, locate the existing module-level constants (around L30-36):

```python
ROOT = ".claude/quality-gates"


def state_file_for(session_id: str) -> str:
    return f"{ROOT}/{session_id}/pipeline.md"
```

Replace with:

```python
from pathlib import Path


def _state_root(hook_input: dict) -> Path:
    """Resolve state root from hook stdin payload cwd; fall back loudly."""
    cwd = hook_input.get("cwd") if hook_input else None
    if not cwd:
        print("[quality-gates] stop-hook payload missing 'cwd'; "
              "falling back to process cwd",
              file=sys.stderr)
        cwd = os.getcwd()
    return Path(cwd) / ".claude" / "quality-gates"


def state_file_for(session_id: str, hook_input: dict) -> str:
    return str(_state_root(hook_input) / session_id / "pipeline.md")
```

(Add `from pathlib import Path` at the top of the imports if not already present. Check `import` block near L21.)

- [ ] **Step 4.4: Update `state_file_for` call site in `main()`**

Find the line in `main()` (around L826):

```python
    state_file = state_file_for(session_id)
```

Replace with:

```python
    state_file = state_file_for(session_id, hook_input)
```

- [ ] **Step 4.5: Verify no other call sites of `state_file_for` exist**

Run: `grep -n "state_file_for" plugins/quality-gates/hooks/stop-hook.py`

Expected: only the definition (around L35) and the `main()` call (around L826). If there are more, update each to pass `hook_input`.

- [ ] **Step 4.6: Run new test, verify PASS**

Run: `python3 -m pytest plugins/quality-gates/tests/test_stop_hook_unit.py -k state_root -v 2>&1 | tail -10`

Expected: 2 tests PASS.

- [ ] **Step 4.7: Run full stop-hook suite for regression**

Run: `python3 -m pytest plugins/quality-gates/tests/test_stop_hook_unit.py -v 2>&1 | tail -15`

Expected: all tests PASS.

- [ ] **Step 4.8: Commit**

```bash
git add plugins/quality-gates/hooks/stop-hook.py plugins/quality-gates/tests/test_stop_hook_unit.py
git commit -m "$(cat <<'EOF'
fix(qg): derive stop-hook state path from payload cwd (B1)

Replace module-level ROOT=".claude/quality-gates" relative path with
_state_root(hook_input) helper that reads cwd from Claude Code's hook
stdin payload. Falls back to os.getcwd() + stderr warning when payload
lacks cwd. Eliminates the silent state-file-miss when hook fires from
main repo cwd but pipeline state lives in worktree.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Normalize post-tool-use-session-tracker via payload cwd (Phase B.2)

**Why:** B2 fix. The hook tracks file mutations into per-session state; relative `Path()` write loses worktree path. Plus `abs_path = str(Path(file_path).resolve())` resolves relative file_paths against process cwd, not worktree.

**Files:**
- Modify: `plugins/quality-gates/hooks/post-tool-use-session-tracker.py` (around L60-68)

- [ ] **Step 5.1: Read current implementation**

Run: `sed -n '40,75p' plugins/quality-gates/hooks/post-tool-use-session-tracker.py`

Expected: see `payload = json.load(sys.stdin)`, `file_path = payload.get("tool_input", {}).get("file_path")`, `abs_path = str(Path(file_path).resolve())`, `state_file = Path(".claude/quality-gates") / session_id / "files.md"`.

- [ ] **Step 5.2: Add failing test (will defer detailed assertion to Task 7 unit-test file)**

For now, write a quick smoke test inline to verify behavior with a tmpdir:

Create `plugins/quality-gates/tests/test_hook_cwd_contract.py`:

```python
#!/usr/bin/env python3
"""Smoke test for post-tool-use-session-tracker payload cwd handling."""
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

PLUGIN_DIR = Path(__file__).resolve().parent.parent
HOOK = PLUGIN_DIR / "hooks" / "post-tool-use-session-tracker.py"


def run_hook(payload: dict, process_cwd: str) -> int:
    proc = subprocess.run(
        ["python3", str(HOOK)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        cwd=process_cwd,
        timeout=10,
    )
    return proc.returncode


def test_state_file_under_payload_cwd():
    """State write goes under payload cwd, not process cwd."""
    with tempfile.TemporaryDirectory() as wt_dir, tempfile.TemporaryDirectory() as proc_dir:
        sid = "tracker-test-01"
        payload = {
            "cwd": wt_dir,
            "session_id": sid,
            "tool_name": "Edit",
            "tool_input": {"file_path": "/some/absolute/foo.py"},
        }
        rc = run_hook(payload, proc_dir)
        assert rc == 0
        state_file = Path(wt_dir) / ".claude" / "quality-gates" / sid / "files.md"
        assert state_file.exists(), f"State not written under payload cwd: {state_file}"
        proc_state = Path(proc_dir) / ".claude" / "quality-gates" / sid / "files.md"
        assert not proc_state.exists(), f"Process-cwd leakage: {proc_state}"


def test_relative_file_path_resolves_against_payload_cwd():
    """Relative file_path resolves against payload cwd, not process cwd."""
    with tempfile.TemporaryDirectory() as wt_dir, tempfile.TemporaryDirectory() as proc_dir:
        sid = "tracker-test-02"
        # Write a file inside wt_dir so resolve doesn't go to /
        (Path(wt_dir) / "subdir").mkdir()
        (Path(wt_dir) / "subdir" / "rel.py").write_text("x = 1")
        payload = {
            "cwd": wt_dir,
            "session_id": sid,
            "tool_name": "Edit",
            "tool_input": {"file_path": "subdir/rel.py"},
        }
        rc = run_hook(payload, proc_dir)
        assert rc == 0
        state_file = Path(wt_dir) / ".claude" / "quality-gates" / sid / "files.md"
        content = state_file.read_text()
        expected_abs = str(Path(wt_dir) / "subdir" / "rel.py")
        # On macOS, /var ↔ /private/var symlink may differ; use resolve to compare
        assert str(Path(expected_abs).resolve()) in content, \
            f"Expected resolved {expected_abs} in state; got:\n{content}"


if __name__ == "__main__":
    test_state_file_under_payload_cwd()
    test_relative_file_path_resolves_against_payload_cwd()
    print("PASS: 2 tests")
```

- [ ] **Step 5.3: Run test, verify FAIL**

Run: `python3 plugins/quality-gates/tests/test_hook_cwd_contract.py 2>&1 | tail -10`

Expected: AssertionError on first test (state goes to process cwd, not payload cwd).

- [ ] **Step 5.4: Patch post-tool-use-session-tracker.py**

In `plugins/quality-gates/hooks/post-tool-use-session-tracker.py`, locate the existing logic (around L60-68):

```python
    file_path = payload.get("tool_input", {}).get("file_path")
    if not file_path:
        return 0
    abs_path = str(Path(file_path).resolve())
    state_file = Path(".claude/quality-gates") / session_id / "files.md"
```

Replace with:

```python
    file_path = payload.get("tool_input", {}).get("file_path")
    if not file_path:
        return 0
    # AC4: derive worktree-relative base from payload cwd (B2 fix).
    # Falls back to process cwd silently — session-tracker is not the warning surface.
    cwd_base = Path(payload.get("cwd") or os.getcwd())
    # If file_path is absolute, resolve() ignores cwd_base; if relative,
    # join against payload cwd so worktree paths resolve correctly.
    file_path_obj = Path(file_path)
    if file_path_obj.is_absolute():
        abs_path = str(file_path_obj.resolve())
    else:
        abs_path = str((cwd_base / file_path_obj).resolve())
    state_file = cwd_base / ".claude" / "quality-gates" / session_id / "files.md"
```

Ensure `import os` exists at the top of the file (if not, add it).

- [ ] **Step 5.5: Run test, verify PASS**

Run: `python3 plugins/quality-gates/tests/test_hook_cwd_contract.py 2>&1 | tail -5`

Expected: `PASS: 2 tests`.

- [ ] **Step 5.6: Run existing session-tracker test suite for regression**

Run: `python3 -m pytest plugins/quality-gates/tests/test_session_tracker.py -v 2>&1 | tail -15`

Expected: all PASS.

- [ ] **Step 5.7: Commit**

```bash
git add plugins/quality-gates/hooks/post-tool-use-session-tracker.py \
        plugins/quality-gates/tests/test_hook_cwd_contract.py
git commit -m "$(cat <<'EOF'
fix(qg): derive session-tracker state path from payload cwd (B2)

post-tool-use-session-tracker now reads payload["cwd"] for both the
state-file path and the relative-file_path resolve base. Absolute
file_paths still resolve() against themselves (CC tool spec convention).
Eliminates state-file leakage into process cwd and false abs_path
resolution when hook process cwd differs from worktree.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Normalize session-start-advisor via payload cwd (Phase B.3)

**Why:** B3 fix. `repo_root = Path.cwd()` (L74) assumes "workspace root" — doesn't know about worktrees.

**Files:**
- Modify: `plugins/quality-gates/hooks/session-start-advisor.py` (around L74)

- [ ] **Step 6.1: Add failing test**

Append to `plugins/quality-gates/tests/test_hook_cwd_contract.py` (reusing the file for hook cwd contract tests):

```python
ADVISOR_HOOK = PLUGIN_DIR / "hooks" / "session-start-advisor.py"


def test_session_start_advisor_uses_payload_cwd(tmp_path):
    """advisor scans plugins/*/agents/*.md relative to payload cwd."""
    # Create a fake plugin layout under tmp_path with a bad-key agent file
    agent_path = tmp_path / "plugins" / "fake-plugin" / "agents" / "test.md"
    agent_path.parent.mkdir(parents=True)
    agent_path.write_text(
        "---\nname: test\nallowed-tools: [Read]\n---\nbody\n"
    )

    proc = subprocess.run(
        ["python3", str(ADVISOR_HOOK)],
        input=json.dumps({"cwd": str(tmp_path), "session_id": "advisor-test-01"}),
        capture_output=True,
        text=True,
        cwd="/tmp",  # different from payload cwd to prove payload wins
        timeout=10,
    )
    # The kebab-case warning should mention the agent under payload cwd
    assert "fake-plugin/agents/test.md" in proc.stderr, \
        f"Advisor didn't scan payload cwd; stderr: {proc.stderr}"
```

- [ ] **Step 6.2: Run test, verify FAIL**

Run: `python3 -m pytest plugins/quality-gates/tests/test_hook_cwd_contract.py::test_session_start_advisor_uses_payload_cwd -v 2>&1 | tail -10`

Expected: FAIL — advisor scans `/tmp` (process cwd) and finds no `fake-plugin/agents/test.md`.

- [ ] **Step 6.3: Patch session-start-advisor.py**

In `plugins/quality-gates/hooks/session-start-advisor.py`, locate the function `_scan_agent_frontmatter_keys` (around L70-92). The current line is:

```python
def _scan_agent_frontmatter_keys() -> None:
    """plugins/*/agents/*.md 스캔, kebab-case allowed-tools/disallowed-tools 발견 시 advice."""
    if _subfeature_disabled("frontmatter-scan"):
        return
    repo_root = Path.cwd()
```

Change the function signature to accept `payload` and use payload cwd:

```python
def _scan_agent_frontmatter_keys(payload: dict) -> None:
    """plugins/*/agents/*.md 스캔, kebab-case allowed-tools/disallowed-tools 발견 시 advice."""
    if _subfeature_disabled("frontmatter-scan"):
        return
    repo_root = Path(payload.get("cwd") or os.getcwd())
```

Then find the call site of `_scan_agent_frontmatter_keys()` (likely in `main()` around the bottom of the file) and update it to pass payload.

If `main()` currently looks like:

```python
def main():
    ...
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        payload = {}
    ...
    _scan_agent_frontmatter_keys()
```

Update the call:

```python
    _scan_agent_frontmatter_keys(payload)
```

- [ ] **Step 6.4: Run test, verify PASS**

Run: `python3 -m pytest plugins/quality-gates/tests/test_hook_cwd_contract.py::test_session_start_advisor_uses_payload_cwd -v 2>&1 | tail -5`

Expected: PASS.

- [ ] **Step 6.5: Run existing advisor test suite for regression**

Run: `python3 -m pytest plugins/quality-gates/tests/test_session_start_advisor.py -v 2>&1 | tail -10`

Expected: all PASS.

- [ ] **Step 6.6: Commit**

```bash
git add plugins/quality-gates/hooks/session-start-advisor.py \
        plugins/quality-gates/tests/test_hook_cwd_contract.py
git commit -m "$(cat <<'EOF'
fix(qg): session-start-advisor scans worktree via payload cwd (B3)

_scan_agent_frontmatter_keys now derives repo_root from
payload["cwd"] instead of Path.cwd(), allowing kebab-case agent
frontmatter detection to work when Claude Code session is launched
inside a worktree.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Add `project_dir` Input contract to 5 LLM-only agents (Phase C.1)

**Why:** AC2 + agent-side half of B4. Each agent must declare it receives `project_dir` and forbid re-resolution.

**Files:**
- Modify: `plugins/quality-gates/agents/scout.md`
- Modify: `plugins/quality-gates/agents/adversarial.md`
- Modify: `plugins/quality-gates/agents/synthesizer.md`
- Modify: `plugins/quality-gates/agents/test-scope-validator.md`
- Modify: `plugins/quality-gates/agents/security-reviewer.md`

- [ ] **Step 7.1: Add failing test to test_worktree.sh**

In `plugins/quality-gates/tests/test_worktree.sh`, add before the final summary:

```bash
# --- Test 8: agent.md Inputs contract drift guard (AC2, T8) ---
for agent in scout adversarial synthesizer test-scope-validator security-reviewer codex-reviewer; do
  if grep -q 'project_dir' "$PLUGIN_DIR/agents/$agent.md"; then
    pass "T8: agents/$agent.md declares project_dir input"
  else
    fail "T8: agents/$agent.md missing project_dir input contract"
  fi
done
```

- [ ] **Step 7.2: Run test, verify FAIL**

Run: `bash plugins/quality-gates/tests/test_worktree.sh 2>&1 | tail -20`

Expected: 6 FAIL lines (T8 for each agent without project_dir).

- [ ] **Step 7.3: Patch agents/scout.md**

In `plugins/quality-gates/agents/scout.md`, find the `## Inputs` section (L15). Add as the **first** bullet under "You will receive:":

```markdown
- `project_dir`: project working directory (absolute path) — pipeline 의 단일 좌표. SKILL preflight 에서 frozen. 절대 재계산 금지 (`git rev-parse`, `Path.cwd()`, `pwd` 모두 금지).
```

Then in `## Forbidden` section (L87), add a new bullet:

```markdown
- Do not re-resolve cwd via `git rev-parse`, `Path.cwd()`, `os.getcwd()`, or any shell `pwd` invocation — use `project_dir` from your input verbatim. Re-resolution at agent runtime defeats the pipeline-wide coordinate contract.
```

- [ ] **Step 7.4: Patch agents/adversarial.md**

Same edits in `agents/adversarial.md`: add `project_dir` bullet under `## Inputs` (L18), add the "Do not re-resolve cwd" bullet under `## Forbidden` (L56).

- [ ] **Step 7.5: Patch agents/synthesizer.md**

Same edits in `agents/synthesizer.md`: `## Inputs` (L15), `## Forbidden` (L66).

- [ ] **Step 7.6: Patch agents/test-scope-validator.md**

test-scope-validator.md has no `## Inputs` section (uses `## Hard Rules` at L36). Add a new `## Inputs` section right after the frontmatter intro (before `## Hard Rules`), and add `## Forbidden` section if absent (else append the bullet).

Read first: `sed -n '1,40p' plugins/quality-gates/agents/test-scope-validator.md` to find the exact insertion point.

Insert (after the agent intro paragraph, before `## Hard Rules`):

```markdown
## Inputs

You will receive:

- `project_dir`: project working directory (absolute path) — pipeline 의 단일 좌표. SKILL preflight 에서 frozen. 절대 재계산 금지 (`git rev-parse`, `Path.cwd()`, `pwd` 모두 금지).
- (existing inputs as already documented elsewhere in this file)

## Forbidden

- Do not re-resolve cwd via `git rev-parse`, `Path.cwd()`, `os.getcwd()`, or any shell `pwd` invocation — use `project_dir` from your input verbatim. Re-resolution at agent runtime defeats the pipeline-wide coordinate contract.
```

(If a `## Forbidden` section already exists later, just append the bullet there; don't duplicate the header.)

- [ ] **Step 7.7: Patch agents/security-reviewer.md**

In `agents/security-reviewer.md`: add `project_dir` bullet under `## Inputs` (L19), and under `## Forbidden` (L78) add the "Do not re-resolve cwd" bullet.

- [ ] **Step 7.8: Run test, verify PASS for 5 LLM-only agents (codex-reviewer still fails — handled in Task 8)**

Run: `bash plugins/quality-gates/tests/test_worktree.sh 2>&1 | grep -E "T8.*(PASS|FAIL)"`

Expected: 5 lines `PASS: T8: agents/<name>.md declares project_dir input` for scout, adversarial, synthesizer, test-scope-validator, security-reviewer. 1 line `FAIL: T8: agents/codex-reviewer.md` (to be fixed in Task 8).

- [ ] **Step 7.9: Commit**

```bash
git add plugins/quality-gates/agents/scout.md \
        plugins/quality-gates/agents/adversarial.md \
        plugins/quality-gates/agents/synthesizer.md \
        plugins/quality-gates/agents/test-scope-validator.md \
        plugins/quality-gates/agents/security-reviewer.md \
        plugins/quality-gates/tests/test_worktree.sh
git commit -m "$(cat <<'EOF'
feat(qg): add project_dir input contract to 5 LLM-only agents (B4 AC2)

scout/adversarial/synthesizer/test-scope-validator/security-reviewer
agent.md files now declare project_dir as a required input and forbid
cwd re-resolution. test_worktree.sh T8 enforces the contract via grep
drift-guard for all 6 Gate-2 agents (codex-reviewer in next commit).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Fix codex-reviewer.md (bash 5-step + Inputs + Forbidden) (Phase C.2)

**Why:** B5 fix + Phase C.2. codex-reviewer is the highest-stakes agent (external subprocess); also fixes the `$REPO_ROOT/plugins/quality-gates/scripts/...` path that breaks outside devbrew's own repo.

**Files:**
- Modify: `plugins/quality-gates/agents/codex-reviewer.md`
- Modify: `plugins/quality-gates/tests/test_worktree.sh` (T7 negative grep)

- [ ] **Step 8.1: Add failing test (T7 negative grep)**

In `plugins/quality-gates/tests/test_worktree.sh`, add before the final summary:

```bash
# --- Test 7: codex-reviewer.md must not reference $REPO_ROOT/plugins/quality-gates (AC3) ---
if grep -q '\$REPO_ROOT/plugins/quality-gates' "$PLUGIN_DIR/agents/codex-reviewer.md"; then
  fail "T7: codex-reviewer.md still references \$REPO_ROOT/plugins/quality-gates (breaks outside devbrew)"
else
  pass "T7: codex-reviewer.md uses \${CLAUDE_PLUGIN_ROOT} (devbrew-portable)"
fi
```

- [ ] **Step 8.2: Run test, verify FAIL**

Run: `bash plugins/quality-gates/tests/test_worktree.sh 2>&1 | grep "T7"`

Expected: `FAIL: T7: codex-reviewer.md still references $REPO_ROOT/plugins/quality-gates`.

- [ ] **Step 8.3: Read current codex-reviewer.md bash block**

Run: `sed -n '38,110p' plugins/quality-gates/agents/codex-reviewer.md`

Expected: the bash block with `SCRATCH=$(mktemp -d ...)`, `REPO_ROOT=$(git rev-parse ...)`, `python3 "$REPO_ROOT/plugins/quality-gates/scripts/..."`, etc.

- [ ] **Step 8.4: Patch the bash block — add empty-project_dir guard + cd + simplify REPO_ROOT**

In `plugins/quality-gates/agents/codex-reviewer.md`, find the bash block opening:

```bash
SCRATCH="$(mktemp -d -t qg-codex-rev-XXXXXX)"
DIFF_FILE="$SCRATCH/diff.patch"
```

Insert these guard lines BEFORE `SCRATCH=`:

```bash
# AC3 guard — fail loud if pipeline coordinate is missing.
if [ -z "${project_dir:-}" ]; then
  echo '{"codex_failed": true, "reason": "missing_project_dir"}'
  exit 0
fi
cd "$project_dir" || { echo '{"codex_failed": true, "reason": "project_dir_unreachable"}'; exit 0; }

```

- [ ] **Step 8.5: Replace `REPO_ROOT=$(git rev-parse ...)` block**

Find:

```bash
# AC10: REPO_ROOT must be non-empty (defense against non-git invocation).
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  echo '{"codex_failed": true, "reason": "not_in_git_repo"}'
  exit 0
fi
```

Replace with:

```bash
# AC3: REPO_ROOT is now an alias for project_dir (single coordinate contract).
# The empty-string guard above (AC3 guard) already catches missing project_dir.
REPO_ROOT="$project_dir"
```

- [ ] **Step 8.6: Replace both `$REPO_ROOT/plugins/quality-gates/scripts/...` references with `${CLAUDE_PLUGIN_ROOT}`**

Find and replace (two occurrences):

```bash
python3 "$REPO_ROOT/plugins/quality-gates/scripts/build_codex_prompt.py" \
```

with:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/build_codex_prompt.py" \
```

And:

```bash
python3 "$REPO_ROOT/plugins/quality-gates/scripts/codex_findings_to_yaml.py" \
```

with:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/codex_findings_to_yaml.py" \
```

- [ ] **Step 8.7: Add `project_dir` to Inputs section**

In `agents/codex-reviewer.md`, find `## Inputs` (L27). Add as the first bullet:

```markdown
- `project_dir`: project working directory (absolute path) — pipeline 의 단일 좌표. SKILL preflight 에서 frozen. 절대 재계산 금지.
```

- [ ] **Step 8.8: Update `## Forbidden` section**

In `## Forbidden` (L117), the first bullet currently says:

```markdown
- Do not modify the invocation flags. `-s read-only`, `-C "$REPO_ROOT"`, `--json`, `< /dev/null`, and `2>"$STDERR_FILE"` are load-bearing.
```

Update it to reflect that `$REPO_ROOT` is now an alias:

```markdown
- Do not modify the invocation flags. `-s read-only`, `-C "$REPO_ROOT"` (where `$REPO_ROOT` is the alias for `$project_dir` set above), `--json`, `< /dev/null`, and `2>"$STDERR_FILE"` are load-bearing.
```

Add a new bullet at the end of `## Forbidden`:

```markdown
- Do not re-resolve cwd via `git rev-parse`, `Path.cwd()`, `os.getcwd()`, or any shell `pwd` invocation — use `project_dir` from your input verbatim. Re-resolution at agent runtime defeats the pipeline-wide coordinate contract (and re-introduces the worktree drift bug fixed in v1.13.0).
```

- [ ] **Step 8.9: Run T7 + T8 tests**

Run: `bash plugins/quality-gates/tests/test_worktree.sh 2>&1 | grep -E "T(7|8)"`

Expected: all PASS — T7 (no `$REPO_ROOT/plugins/quality-gates`) and T8 (all 6 agents declare project_dir).

- [ ] **Step 8.10: Run existing codex-reviewer frontmatter test for regression**

Run: `bash plugins/quality-gates/tests/test_codex_reviewer_frontmatter.sh 2>&1 | tail -5`

Expected: PASS.

- [ ] **Step 8.11: Commit**

```bash
git add plugins/quality-gates/agents/codex-reviewer.md \
        plugins/quality-gates/tests/test_worktree.sh
git commit -m "$(cat <<'EOF'
fix(qg): codex-reviewer uses project_dir + CLAUDE_PLUGIN_ROOT (B5 AC3)

codex-reviewer.md bash block now:
- Guards against empty project_dir (loud JSON failure)
- cd "$project_dir" before any operation
- REPO_ROOT="$project_dir" (alias, no git rev-parse)
- Calls plugin scripts via ${CLAUDE_PLUGIN_ROOT}/scripts/ instead of
  $REPO_ROOT/plugins/quality-gates/scripts/ (which only existed in
  devbrew's self-test; broke in every user repo)
Inputs/Forbidden sections updated to declare and enforce the contract.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Add `project_dir` to SKILL.md dispatch (Phase D)

**Why:** Final B4 fix. SKILL is the orchestrator — its dispatch prompts must carry the contract to each subagent.

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`
- Modify: `plugins/quality-gates/tests/test_codex_dispatch_invariant.sh` (Scenario 4)

- [ ] **Step 9.1: Add failing test (Scenario 4)**

In `plugins/quality-gates/tests/test_codex_dispatch_invariant.sh`, before the final `echo "PASS"` line, add:

```bash
# Scenario 4: project_dir contract in 5 SKILL.md dispatch blocks (AC1)
# Pattern P — 4 agents with explicit Agent() block (window=15)
for name in scout adversarial synthesizer test-scope-validator; do
  if ! awk -v name="quality-gates:$name" '
    $0 ~ name { found=NR }
    found && NR <= found+15 && /project_dir:/ { ok=1; exit }
    END { exit !ok }
  ' "$SKILL"; then
    fail "Scenario 4: Pattern-P dispatch block for $name lacks project_dir"
  fi
done

# Pattern L — security-reviewer prose header (window=30)
if ! awk '
  /\*\*Agent D — security-reviewer\*\*/ { found=NR }
  found && NR <= found+30 && /project_dir/ { ok=1; exit }
  END { exit !ok }
' "$SKILL"; then
  fail "Scenario 4: Pattern-L Agent D (security-reviewer) section lacks project_dir reference"
fi

# Reference-only — codex-reviewer.md is the source of truth
if ! grep -q 'project_dir' "$REPO_ROOT/plugins/quality-gates/agents/codex-reviewer.md"; then
  fail "Scenario 4: codex-reviewer.md lacks project_dir input contract"
fi

ok "Scenario 4: all 6 agents have project_dir contract (P×4 + L×1 + ref×1)"
```

- [ ] **Step 9.2: Run test, verify FAIL**

Run: `bash plugins/quality-gates/tests/test_codex_dispatch_invariant.sh 2>&1 | tail -10`

Expected: at least one FAIL for `Pattern-P dispatch block for <name> lacks project_dir`.

- [ ] **Step 9.3: Patch SKILL.md scout dispatch (Pattern P)**

In `plugins/quality-gates/skills/quality-pipeline/SKILL.md`, find the scout dispatch (around L445-456):

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

Add `project_dir:` line after `session_scope`:

```
Agent(
  subagent_type="quality-gates:scout",
  model="sonnet",
  prompt="<filtered diff (≤50KB) or '<diff too large; use git diff>'>

  gate1_summary:
  <verbatim YAML from Gate 1>

  session_scope: <branch | session | paths> + <applied path list>
  project_dir: <current working directory>
  iteration: <N>"
)
```

- [ ] **Step 9.4: Patch SKILL.md adversarial dispatch (Pattern P)**

Find the adversarial dispatch (around L669-675):

```
Agent(
  subagent_type="quality-gates:adversarial",
  model="opus",
  prompt="<all Phase 1 + Phase 2 findings as structured YAML>
  filtered_diff: <verbatim from cache>"
)
```

Add `project_dir:`:

```
Agent(
  subagent_type="quality-gates:adversarial",
  model="opus",
  prompt="<all Phase 1 + Phase 2 findings as structured YAML>
  filtered_diff: <verbatim from cache>
  project_dir: <current working directory>"
)
```

- [ ] **Step 9.5: Patch SKILL.md synthesizer dispatch (Pattern P)**

Find synthesizer dispatch (around L692-697):

```
Agent(
  subagent_type="quality-gates:synthesizer",
  model="sonnet",
  prompt="<all Phase 1 findings + Phase 2 findings + Adversarial verdicts>"
)
```

Update prompt:

```
Agent(
  subagent_type="quality-gates:synthesizer",
  model="sonnet",
  prompt="<all Phase 1 findings + Phase 2 findings + Adversarial verdicts>
  project_dir: <current working directory>"
)
```

- [ ] **Step 9.6: Patch SKILL.md test-scope-validator dispatch (Pattern P)**

Find test-scope-validator dispatch (around L994-1040). Add `project_dir: <current working directory>` to its prompt block similarly. Read the exact block first:

Run: `sed -n '990,1045p' plugins/quality-gates/skills/quality-pipeline/SKILL.md`

Then locate the prompt closing quote and add `project_dir:` line above it.

- [ ] **Step 9.7: Patch SKILL.md security-reviewer prose (Pattern L)**

Find the `**Agent D — security-reviewer**` section (around L577-591). Locate the "Immutable head:" block that ends with:

```markdown
> If the prompt contains a `## Current Diff` section, operate on that diff verbatim. **Do NOT run `git diff` yourself** — the full unified diff is already provided.
```

Add a new paragraph immediately after the Immutable head block:

```markdown
> Your input prompt will also include a `project_dir: <absolute path>` line representing the pipeline's single coordinate. Use this verbatim for any Read tool call — do not re-resolve via `pwd` or `Path.cwd()`.
```

- [ ] **Step 9.8: Run test, verify PASS**

Run: `bash plugins/quality-gates/tests/test_codex_dispatch_invariant.sh 2>&1 | tail -10`

Expected: `PASS: test_codex_dispatch_invariant.sh (4 scenarios)`.

- [ ] **Step 9.9: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md \
        plugins/quality-gates/tests/test_codex_dispatch_invariant.sh
git commit -m "$(cat <<'EOF'
feat(qg): propagate project_dir through SKILL dispatch prompts (B4 AC1)

SKILL.md now passes project_dir to 4 Pattern-P dispatch blocks (scout,
adversarial, synthesizer, test-scope-validator) and one Pattern-L block
(Agent D security-reviewer). codex-reviewer is reference-only — its
agent.md (already patched in Task 8) is the contract source of truth.
test_codex_dispatch_invariant.sh Scenario 4 enforces drift via
anchor-then-window awk for both patterns.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Add T5/T6/T9 worktree integration tests

**Why:** AC5 — final regression coverage for skill dispatch (T5), hook AST drift (T6), state file schema (T9).

**Files:**
- Modify: `plugins/quality-gates/tests/test_worktree.sh`

- [ ] **Step 10.1: Add T5/T6/T9 to test_worktree.sh**

In `plugins/quality-gates/tests/test_worktree.sh`, before the final summary, append:

```bash
# --- Test 5: SKILL.md prose contains project_dir in 5 dispatch blocks ---
SKILL_MD="$PLUGIN_DIR/skills/quality-pipeline/SKILL.md"
T5_FAIL=0
for name in scout adversarial synthesizer test-scope-validator; do
  if ! awk -v name="quality-gates:$name" '
    $0 ~ name { found=NR }
    found && NR <= found+15 && /project_dir:/ { ok=1; exit }
    END { exit !ok }
  ' "$SKILL_MD"; then
    T5_FAIL=1
    fail "T5: SKILL.md dispatch for $name lacks project_dir"
  fi
done
if ! awk '/\*\*Agent D — security-reviewer\*\*/ { found=NR }
        found && NR <= found+30 && /project_dir/ { ok=1; exit }
        END { exit !ok }' "$SKILL_MD"; then
  T5_FAIL=1
  fail "T5: SKILL.md Agent D section lacks project_dir"
fi
[[ "$T5_FAIL" -eq 0 ]] && pass "T5: SKILL.md propagates project_dir to all 5 dispatch points"

# --- Test 6: hooks read payload cwd (AST-based, not grep) ---
T6_FAIL=0
for hook in stop-hook.py post-tool-use-session-tracker.py session-start-advisor.py; do
  if ! python3 -c "
import ast, sys
tree = ast.parse(open('$PLUGIN_DIR/hooks/$hook').read())
found = False
for node in ast.walk(tree):
    if isinstance(node, ast.Call):
        # Look for *.get('cwd') or *.get('cwd', ...)
        if isinstance(node.func, ast.Attribute) and node.func.attr == 'get':
            args = node.args
            if args and isinstance(args[0], ast.Constant) and args[0].value == 'cwd':
                found = True
                break
sys.exit(0 if found else 1)
"; then
    T6_FAIL=1
    fail "T6: hooks/$hook does not call .get('cwd') anywhere"
  fi
done
[[ "$T6_FAIL" -eq 0 ]] && pass "T6: all 3 hooks read payload cwd (AST verified)"

# --- Test 9: setup-qg.sh writes project_dir to state frontmatter ---
if grep -q '^project_dir:' "$PLUGIN_DIR/scripts/setup-qg.sh"; then
  pass "T9: setup-qg.sh emits project_dir in state frontmatter"
else
  fail "T9: setup-qg.sh missing project_dir frontmatter write"
fi
```

- [ ] **Step 10.2: Run test_worktree.sh — all 9 tests should PASS now (T1-T9)**

Run: `bash plugins/quality-gates/tests/test_worktree.sh 2>&1 | tail -25`

Expected: `Results: N passed, 0 failed` where N covers T1-T9 (each T may have multiple sub-assertions; count varies but failures must be 0).

- [ ] **Step 10.3: Commit**

```bash
git add plugins/quality-gates/tests/test_worktree.sh
git commit -m "$(cat <<'EOF'
test(qg): add T5/T6/T9 worktree integration regression guards (AC5)

T5: SKILL.md dispatch blocks all carry project_dir (Pattern P + L).
T6: 3 hooks call .get('cwd') (AST-verified to avoid grep false matches).
T9: setup-qg.sh emits project_dir in state frontmatter.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Release artifacts (plugin.json bump + CHANGELOG + README) (Phase E)

**Why:** CLAUDE.md plugin-shape规约 — every PR touching plugin must bump version + emit CHANGELOG entry.

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`
- Modify: `plugins/quality-gates/CHANGELOG.md`
- Modify: `plugins/quality-gates/README.md`

- [ ] **Step 11.1: Bump plugin.json version**

In `plugins/quality-gates/.claude-plugin/plugin.json`, change:

```json
  "version": "1.12.0",
```

to:

```json
  "version": "1.13.0",
```

(Keep all other fields identical.)

- [ ] **Step 11.2: Add CHANGELOG entry**

In `plugins/quality-gates/CHANGELOG.md`, after the top `# Changelog` header (and any intro), insert before the existing `## [1.12.0]` entry:

```markdown
## [1.13.0] — 2026-05-16

### Added
- State file schema field `project_dir` (frontmatter) — single pipeline coordinate frozen at preflight (AC6, B6 fix).
- `project_dir` input contract on 6 Gate-2 agents: scout, codex-reviewer, adversarial, synthesizer, test-scope-validator, security-reviewer (AC2).
- `tests/test_hook_cwd_contract.py` — payload cwd contract for post-tool-use-session-tracker and session-start-advisor.
- `tests/test_worktree.sh` T5/T6/T7/T8/T9 — regression guards for SKILL dispatch, hook AST, codex-reviewer plugin paths, agent.md drift, state schema.
- `tests/test_codex_dispatch_invariant.sh` Scenario 4 — anchor-then-window awk for Pattern-P and Pattern-L dispatch blocks.

### Changed
- `hooks/stop-hook.py`: removed module-level `ROOT` constant; introduced `_state_root(hook_input)` helper deriving state path from payload cwd. `state_file_for(session_id, hook_input)` signature updated.
- `hooks/stop-hook.py:build_gate_prompt()`: all 3 gate branches now inject `project_dir: {state["project_dir"]}` into continuation prompts, ensuring gate-boundary cwd persistence.
- `hooks/stop-hook.py:parse_state_file()`: surfaces `project_dir` with v1.12.x backward-compat fallback (`os.getcwd()` + stderr warning, mirroring `gate3_resolution_iter` pattern at L114-120).
- `hooks/post-tool-use-session-tracker.py`: state path and `abs_path` resolution base both derived from payload cwd.
- `hooks/session-start-advisor.py`: `_scan_agent_frontmatter_keys` now takes payload arg and derives `repo_root` from payload cwd instead of `Path.cwd()`.
- `agents/codex-reviewer.md`: bash block guards empty `project_dir`, `cd "$project_dir"`, `REPO_ROOT="$project_dir"` (no more `git rev-parse`); plugin scripts called via `${CLAUDE_PLUGIN_ROOT}/scripts/` instead of `$REPO_ROOT/plugins/quality-gates/scripts/` (which only existed in devbrew's self-test).
- `skills/quality-pipeline/SKILL.md`: 4 Pattern-P dispatch blocks (scout/adversarial/synthesizer/test-scope-validator) and 1 Pattern-L block (Agent D security-reviewer) now declare `project_dir: <current working directory>` in their prompts.

### Fixed
- **B1**: stop-hook.py `ROOT` constant relative-path bug — state file path now derived from payload cwd (worktree-safe).
- **B2**: post-tool-use-session-tracker.py `Path(".claude/quality-gates")` relative bug + `abs_path` resolution against wrong base.
- **B3**: session-start-advisor.py `Path.cwd()` worktree blindness.
- **B4**: SKILL.md missing `project_dir` in dispatches to scout/codex-reviewer/adversarial/synthesizer/test-scope-validator/security-reviewer.
- **B5**: codex-reviewer.md (a) `$REPO_ROOT/plugins/quality-gates/scripts/...` path broken outside devbrew, (b) missing `cd "$project_dir"` causing subprocess cwd nondeterminism.
- **B6**: state file schema lacked `project_dir`; stop-hook `build_gate_prompt()` never propagated it across gate boundaries — caused gate2/3 continuations to re-evaluate cwd in main repo when pipeline was launched from worktree.

### Upgrade notes
- In-flight v1.12.x pipelines: state file lacks `project_dir`; `parse_state_file()` falls back to `os.getcwd()` + stderr warning. If your continuation is running from a worktree, expect one warning per gate transition. For clean state, run `/cancel-qg && /qg` after upgrade.
- No state-file format break: v1.12.x state files remain readable; v1.13.0 state files have one additional `project_dir:` line that older code would simply ignore.
```

- [ ] **Step 11.3: Add "Principles Instantiated" line to README**

In `plugins/quality-gates/README.md`, find the "Principles Instantiated" section. Add a new bullet (preserve existing bullets):

```markdown
- **Law 1 — Clarity Before Code (좌표 계약 측면)**: pipeline 의 단일 좌표 `project_dir` 가 SKILL preflight 에서 frozen 되어 모든 subagent / hook / 외부 codex 프로세스에 명시적으로 propagate. cwd 재계산은 frontmatter Forbidden + grep-anchored drift guard 로 mechanically 차단. (v1.13.0)
```

- [ ] **Step 11.4: Commit**

```bash
git add plugins/quality-gates/.claude-plugin/plugin.json \
        plugins/quality-gates/CHANGELOG.md \
        plugins/quality-gates/README.md
git commit -m "$(cat <<'EOF'
chore(qg): bump to v1.13.0 + CHANGELOG worktree cwd contract entry

Released worktree cwd contract fix (B1~B6). All 18 touched files
shipped together; SemVer minor bump because state file schema gains
project_dir field (backward-compat'd via fallback in stop-hook).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Final full-suite regression check

**Why:** Catch any test that broke during the cascade of changes.

- [ ] **Step 12.1: Run all quality-gates tests**

Run:

```bash
cd plugins/quality-gates
for t in tests/test_*.sh tests/test_*.py; do
  echo "=== $t ==="
  case "$t" in
    *.sh) bash "$t" 2>&1 | tail -3 ;;
    *.py) python3 "$t" 2>&1 | tail -3 ;;
  esac
done
```

Expected: every test ends with a PASS / `0 failed` / `OK` line. If any FAIL:
1. Read the failure message
2. Decide if it's a regression (real bug introduced) or a stale test that now needs updating
3. Fix the underlying issue (do NOT modify a test to mask a real regression)
4. Re-commit with `fix(qg): <description>` message

- [ ] **Step 12.2: Verify no `$REPO_ROOT/plugins/quality-gates` references remain anywhere**

Run: `grep -rn '\$REPO_ROOT/plugins/quality-gates' plugins/quality-gates/agents/ plugins/quality-gates/skills/ plugins/quality-gates/hooks/`

Expected: empty output. (Test files may reference it for negative grep — that's OK.)

- [ ] **Step 12.3: Verify all 6 agents declare project_dir**

Run:

```bash
for a in scout adversarial synthesizer test-scope-validator security-reviewer codex-reviewer; do
  if grep -q project_dir "plugins/quality-gates/agents/$a.md"; then
    echo "OK: $a"
  else
    echo "MISSING: $a"
  fi
done
```

Expected: 6 lines, all `OK`.

- [ ] **Step 12.4: Final commit (only if Step 12.1-12.3 caught issues)**

If steps caught nothing, skip this step. Otherwise commit each fix incrementally with appropriate `fix(qg): ...` messages.

---

## Task 13: Manual e2e verification (per spec AC8)

**Why:** Confirm the fix actually works against a real Claude Code session — automated tests can't simulate the full subagent dispatch chain.

This task is **manual** — the engineer runs it locally, not as a TDD step. Skip if no codex CLI available; in that case, gate1+gate2 fallback path is still exercised.

- [ ] **Step 13.1: Run e2e shell block from spec AC8**

```bash
# Setup
mkdir -p /tmp/qg-wt-test && cd /tmp/qg-wt-test
git init -q && echo "x" > README.md && git add . && git commit -q -m init
git worktree add ../wt-feat -b feature-x 2>&1 | tail -2
cd ../wt-feat
echo "y = 1" > foo.py && git add . && git commit -q -m "add foo"

# Run qg gate1 (gate2 requires PR; gate1 SKIP is enough to verify state placement)
# In a Claude Code session: /qg gate1
echo "→ now switch to Claude Code in this dir and run: /qg gate1"
```

- [ ] **Step 13.2: After Claude Code returns from /qg gate1, verify state placement**

```bash
# State should be inside worktree, NOT main repo
ls -la /tmp/qg-wt-test/wt-feat/.claude/quality-gates/ 2>/dev/null && echo "OK: state in worktree"
[ ! -d /tmp/qg-wt-test/.claude/quality-gates ] && echo "OK: main repo untouched" || echo "FAIL: leakage into main repo"
```

- [ ] **Step 13.3: Verify project_dir in state frontmatter**

```bash
SID=$(ls /tmp/qg-wt-test/wt-feat/.claude/quality-gates/ | head -1)
grep "project_dir" "/tmp/qg-wt-test/wt-feat/.claude/quality-gates/$SID/pipeline.md"
```

Expected: `project_dir: "/tmp/qg-wt-test/wt-feat"` (or `/private/tmp/...` on macOS due to symlink — both OK).

- [ ] **Step 13.4: Cleanup**

```bash
cd /tmp
rm -rf qg-wt-test
git worktree prune
```

---

## Self-review checklist (do this BEFORE handing off)

After the plan is written, verify:

- [ ] Every spec AC (AC1-AC8) maps to at least one Task. (AC1 → Task 9; AC2 → Task 7+8; AC3 → Task 8; AC4 → Task 4+5+6; AC5 → Task 10; AC6 → Task 1+2+3; AC7 → Task 11; AC8 → Task 13.)
- [ ] No "TBD", "TODO", "fill in later" anywhere in the plan.
- [ ] Every step that writes code has the exact code (no "implement appropriately").
- [ ] Every test command includes expected output.
- [ ] Function signatures stay consistent across tasks: `_state_root(hook_input)`, `state_file_for(session_id, hook_input)`, `_scan_agent_frontmatter_keys(payload)`, `parse_state_file(path) → state, body`, `build_gate_prompt(gate_num, state, gate_results) → str`.
- [ ] Phase order matches spec §11: A (1-3) → B (4-6) → C (7-8) → D (9-10) → E (11) → F (13). Task 12 is a regression sweep before E.

If any item fails, fix inline.
