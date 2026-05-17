# spec-distill Hook Context Injection Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill의 5개 hook (`review-dispatch.py`, `spec-write-validator.py` advisory 분기, `pending-review-reminder.py`, `interview-trigger.sh`, `session-anchor.sh`) stdout JSON을 dual-target 패턴(Claude-target field + `systemMessage` 짧은 흔적)으로 정정하여 Claude LLM context로 dispatch 메시지가 실제로 도달하게 만들고, 회귀 방지 통합 test를 신설하며, v0.5.0 minor bump.

**Architecture:** 각 hook은 기존 `{"systemMessage":"..."}` 단일 필드 출력을 (a) PostToolUse/UserPromptSubmit/SessionStart는 `{"hookSpecificOutput":{"hookEventName":"<event>","additionalContext":"..."},"systemMessage":"<짧은 흔적>"}` (b) Stop hook은 `{"decision":"block","reason":"...","systemMessage":"<짧은 흔적>"}` 형태로 변경. Stop hook은 추가로 (1) `rewrite_state()` 호출을 `print()` 이전으로 옮기고 fsync 추가, (2) `rewrite_state` OSError 시 `{}` exit 0 (block storm 회피). 회귀 방지는 `tests/test_hook_output_schema.py` (Python unittest, parametrized via subTest, env-redirect fixture로 contract 검증). reference 패턴: `plugins/quality-gates/hooks/stop-hook.py:845-849`.

**Tech Stack:** Python 3 stdlib (`unittest`, `subprocess`, `tempfile`, `json`, `ast`, `unittest.mock`, `shutil`), bash + jq + sed (graceful no-jq fallback), git CLI. 외부 의존성 추가 없음.

**Spec:** `docs/superpowers/specs/2026-05-17-spec-distill-hook-context-injection-design.md` v1.3.0 (3 rounds reviewed).

**Branch:** `fix/spec-distill-hook-context-injection` (이미 4 commit, working tree clean).

---

## File Structure

**Modified (hook code, 5 files):**
- `plugins/spec-distill/hooks/review-dispatch.py` — Stop hook: ordering + fsync + output schema
- `plugins/spec-distill/hooks/spec-write-validator.py` — PostToolUse: advisory branch output schema
- `plugins/spec-distill/hooks/pending-review-reminder.py` — UserPromptSubmit: output schema
- `plugins/spec-distill/hooks/interview-trigger.sh` — UserPromptSubmit: jq + no-jq output schema
- `plugins/spec-distill/hooks/session-anchor.sh` — SessionStart: jq + no-jq output schema

**Modified (bash tests, 5 files):**
- `plugins/spec-distill/tests/test_review_dispatch.sh`
- `plugins/spec-distill/tests/test_review_dispatch_design_mandate.sh`
- `plugins/spec-distill/tests/test_hooks.sh`
- `plugins/spec-distill/tests/test_reminder_hook.sh`
- `plugins/spec-distill/tests/test_spec_write_validator.sh`

**Created (test, 1 file):**
- `plugins/spec-distill/tests/test_hook_output_schema.py` — new Python unittest with parametrized fixture for all 5 hooks

**Modified (metadata, 3 files):**
- `plugins/spec-distill/.claude-plugin/plugin.json` — version bump
- `plugins/spec-distill/CHANGELOG.md` — [0.5.0] entry
- `plugins/spec-distill/README.md` — Hooks + Principles Instantiated update

**Unchanged (explicit):** `plugins/spec-distill/hooks/hooks.json`, `plugins/spec-distill/hooks/state_path.py`, `plugins/spec-distill/scripts/parse_spec_structure.py`, all skills/agents/commands.

---

## Task 1: Verify branch state and create test scaffolding directory

**Files:**
- Check: `git status`, current branch
- Create: nothing yet

- [ ] **Step 1: Verify on the right branch with clean tree**

Run:
```bash
git status
git log --oneline -5
```
Expected: on `fix/spec-distill-hook-context-injection`, working tree clean, recent commits show spec revisions (`b192efa`, `2a54894`, `445aec3`, `c0bc790`).

- [ ] **Step 2: Verify dependencies present**

Run:
```bash
which python3 jq bash git
python3 --version
jq --version
```
Expected: all present, Python 3.8+ recommended (for `ast.unparse`).

- [ ] **Step 3: No commit (this task is verification only)**

---

## Task 2: Create test_hook_output_schema.py scaffolding with base TestCase

**Files:**
- Create: `plugins/spec-distill/tests/test_hook_output_schema.py`

- [ ] **Step 1: Write the scaffolding (no test methods yet, just helpers + base class)**

Create `plugins/spec-distill/tests/test_hook_output_schema.py`:

```python
#!/usr/bin/env python3
"""AC12 — Hook output schema 통합 회귀 방지 test (v0.5.0).

Covers AC1–AC5 (5 hook output schemas), AC1a (encoding round-trip),
AC7.1/7.2/7.3 (Stop hook ordering + rewrite-fail behavior + ordering
verification 3-prong), AC10/AC11 (kill switches), NG9 (cross-resolver
advisory).

Run:
    python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py
"""
from __future__ import annotations

import ast
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parents[3]
HOOKS_DIR = REPO_ROOT / "plugins" / "spec-distill" / "hooks"


def _make_temp_repo() -> Path:
    """Create a temp dir initialised as a git repo (state_path needs git)."""
    tmp = Path(tempfile.mkdtemp(prefix="specdistill-schema-"))
    subprocess.run(["git", "init", "-q"], cwd=tmp, check=True)
    subprocess.run(["git", "config", "user.email", "t@t.t"], cwd=tmp, check=True)
    subprocess.run(["git", "config", "user.name", "t"], cwd=tmp, check=True)
    subprocess.run(
        ["git", "commit", "-q", "--allow-empty", "-m", "seed"],
        cwd=tmp, check=True,
    )
    return tmp


def _write_pending_review_state(
    repo: Path, session_id: str, *, spec_path: str = "/tmp/x-spec.md",
    mode: str = "spec", worktree_path: str | None = None,
    triggered_at: str = "2026-05-17T00:00:00Z",
    last_dispatched_at: str | None = None,
) -> Path:
    """Write a state.local.md with a pending_review block."""
    state_dir = repo / ".claude" / "spec-distill" / session_id
    state_dir.mkdir(parents=True, exist_ok=True)
    state_file = state_dir / "state.local.md"
    block = (
        f"pending_review:\n"
        f"  path: {spec_path}\n"
        f"  mode: {mode}\n"
    )
    if worktree_path:
        block += f"  worktree_path: {worktree_path}\n"
    block += f"  triggered_at: {triggered_at}\n"
    tail = ""
    if last_dispatched_at:
        tail = f"\nlast_dispatched_at: {last_dispatched_at}\n"
    state_file.write_text(
        f"---\nsession_id: {session_id}\n---\n\n{block}{tail}",
        encoding="utf-8",
    )
    return state_file


def _run_hook(
    hook_relpath: str, *,
    cwd: Path, env_extra: dict[str, str] | None = None,
    stdin_payload: dict | None = None,
    binary: str = "python3",
) -> subprocess.CompletedProcess:
    """Run a hook with isolated env. cwd=temp repo redirects state_root()."""
    env = {"HOME": os.environ.get("HOME", "/tmp"), "PATH": os.environ["PATH"]}
    if env_extra:
        env.update(env_extra)
    hook_path = HOOKS_DIR / hook_relpath
    stdin_str = json.dumps(stdin_payload or {})
    return subprocess.run(
        [binary, str(hook_path)],
        cwd=cwd, env=env, input=stdin_str, text=True,
        capture_output=True, timeout=15,
    )


class HookOutputSchemaTestBase(unittest.TestCase):
    """Base class with shared fixture lifecycle."""

    def setUp(self):
        self.repo = _make_temp_repo()

    def tearDown(self):
        shutil.rmtree(self.repo, ignore_errors=True)
```

- [ ] **Step 2: Run the new file to verify it imports cleanly (no test methods yet)**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py -v
```
Expected: `Ran 0 tests in 0.000s` — OK (file parses, no tests defined yet).

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/tests/test_hook_output_schema.py
git commit -m "test(spec-distill): scaffold test_hook_output_schema.py base (AC12)"
```

---

## Task 3: Add failing Stop hook (review-dispatch.py) schema test

**Files:**
- Modify: `plugins/spec-distill/tests/test_hook_output_schema.py` (append class)

- [ ] **Step 1: Append the test class with Stop hook happy-path schema check**

Append to `plugins/spec-distill/tests/test_hook_output_schema.py`:

```python
class TestReviewDispatchSchema(HookOutputSchemaTestBase):
    """AC1 — review-dispatch.py (Stop hook) output schema."""

    def test_pending_review_emits_decision_block_with_reason(self):
        session_id = "test-stop-happy"
        _write_pending_review_state(
            self.repo, session_id,
            spec_path="/tmp/some-spec.md", mode="spec",
            worktree_path="/Users/foo/wt",
        )
        result = _run_hook(
            "review-dispatch.py",
            cwd=self.repo,
            env_extra={"DEVBREW_SPEC_DISTILL_SESSION_ID": session_id},
        )
        self.assertEqual(result.returncode, 0, msg=f"stderr: {result.stderr}")
        self.assertTrue(result.stdout.strip(), msg="stdout empty")
        payload = json.loads(result.stdout)
        self.assertEqual(payload.get("decision"), "block")
        reason = payload.get("reason", "")
        self.assertIn("MANDATORY", reason)
        self.assertIn("spec path:", reason)
        self.assertIn("mode:", reason)
        self.assertIn("worktree_path:", reason)
        sysmsg = payload.get("systemMessage", "")
        self.assertTrue(sysmsg, msg="systemMessage missing")
        self.assertLessEqual(len(sysmsg), 120, msg=f"systemMessage too long: {len(sysmsg)}")
        self.assertTrue(sysmsg.startswith("[spec-distill]"))
```

- [ ] **Step 2: Run the test to verify it FAILS (current hook emits systemMessage only)**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py::TestReviewDispatchSchema -v
```
Expected: FAIL. `payload.get("decision")` is `None` (current code emits `{"systemMessage": msg}` without `decision`).

- [ ] **Step 3: No commit yet (failing test). Proceed to next task to make it pass.**

---

## Task 4: Fix review-dispatch.py — fsync in rewrite_state + ordering + output schema

**Files:**
- Modify: `plugins/spec-distill/hooks/review-dispatch.py:1-16` (docstring), `66-75` (rewrite_state body), `118-127` (main() ordering)

- [ ] **Step 1: Update docstring and add fsync to rewrite_state**

Edit `plugins/spec-distill/hooks/review-dispatch.py` — replace the docstring (lines 1-16) with:

```python
#!/usr/bin/env python3
"""spec-distill Stop hook — review dispatch enforcer (v0.5.0).

Reads state.local.md for the current session. If `pending_review:` block
is present AND last_dispatched_at is empty or older than the redispatch TTL,
emits stdout `{"decision":"block","reason":"...","systemMessage":"..."}` —
the `decision:"block"` forces Claude Code to continue immediately (no user
input wait), and `reason` is shown to Claude as a system message so the next
turn first action becomes the reviewing-spec skill call.

Ordering guarantee (AC7.1): `rewrite_state()` must complete (with fsync) BEFORE
the JSON is printed. Reverse ordering races with a second Stop fire and
produces a block storm. On rewrite OSError, the hook exits `{}` 0 (no block)
to preserve the race-free TTL guard (AC7.2) — the L4b UserPromptSubmit
reminder picks up the missed dispatch on the next user prompt.

Kill switches:
- DEVBREW_DISABLE_SPEC_DISTILL=1
- DEVBREW_SKIP_HOOKS=spec-distill:Stop  (or :review-dispatch)
- DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=<int>  (default 30; self-ref cycle guard)
"""
```

Edit `rewrite_state` function (lines 66-75) — replace:

```python
def rewrite_state(path: Path, body: str, now: datetime) -> None:
    body = re.sub(
        r"^pending_review:\n(?:  [^\n]*\n)*", "", body, flags=re.MULTILINE
    )
    new_ts = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    if LAST_DISPATCHED_RE.search(body):
        body = LAST_DISPATCHED_RE.sub(f"last_dispatched_at: {new_ts}", body)
    else:
        body = body.rstrip() + f"\nlast_dispatched_at: {new_ts}\n"
    path.write_text(body, encoding="utf-8")
```

with (open/flush/fsync for durability per AC7.1):

```python
def rewrite_state(path: Path, body: str, now: datetime) -> None:
    body = re.sub(
        r"^pending_review:\n(?:  [^\n]*\n)*", "", body, flags=re.MULTILINE
    )
    new_ts = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    if LAST_DISPATCHED_RE.search(body):
        body = LAST_DISPATCHED_RE.sub(f"last_dispatched_at: {new_ts}", body)
    else:
        body = body.rstrip() + f"\nlast_dispatched_at: {new_ts}\n"
    # AC7.1: explicit flush + fsync for OS-level durability before any emit.
    with open(path, "w", encoding="utf-8") as f:
        f.write(body)
        f.flush()
        os.fsync(f.fileno())
```

Verify `import os` is already present at line 19 (it is, per prior reading).

- [ ] **Step 2: Reorder main() — rewrite BEFORE print, OSError → return 0**

Edit `plugins/spec-distill/hooks/review-dispatch.py` main() block around lines 118-127. Replace:

```python
    msg = " ".join(msg_lines)
    print(json.dumps({"systemMessage": msg}), flush=True)
    try:
        rewrite_state(state_path, body, now)
    except OSError as e:
        print(f"[spec-distill] state rewrite failed (non-fatal): {e}", file=sys.stderr)
    return 0
```

with:

```python
    msg = " ".join(msg_lines)
    # AC7.1: rewrite BEFORE emit. AC7.2: rewrite-fail → no emit (block storm guard).
    try:
        rewrite_state(state_path, body, now)
    except OSError as e:
        print(
            f"[spec-distill] state rewrite failed (non-fatal, dispatch suppressed): {e}",
            file=sys.stderr,
        )
        return 0  # {} stdout, no decision:block — L4b reminder picks up on next prompt
    print(json.dumps({
        "decision": "block",
        "reason": msg,
        "systemMessage": "[spec-distill] reviewing-spec dispatch enforced for next turn",
    }), flush=True)
    return 0
```

- [ ] **Step 3: Run the Stop hook test from Task 3 to verify it PASSES**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py::TestReviewDispatchSchema -v
```
Expected: PASS.

- [ ] **Step 4: Run existing bash test to verify no immediate regression (will fail since assertions expect old format — that's fine, we update them later)**

Run:
```bash
bash plugins/spec-distill/tests/test_review_dispatch.sh
```
Expected: some FAIL (existing assertions check `systemMessage` substring). Note the failure count and proceed — the bash tests get updated in Task 18.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/hooks/review-dispatch.py plugins/spec-distill/tests/test_hook_output_schema.py
git commit -m "fix(spec-distill): review-dispatch Stop hook output + ordering + fsync (AC1/AC7.1/AC7.2)"
```

---

## Task 5: Add AC1a encoding round-trip test (special chars in spec path)

**Files:**
- Modify: `plugins/spec-distill/tests/test_hook_output_schema.py` (add test method)

- [ ] **Step 1: Append test method to TestReviewDispatchSchema**

Add inside `TestReviewDispatchSchema` class:

```python
    def test_reason_encoding_safe_with_special_chars(self):
        """AC1a — special chars in spec path must round-trip via json.loads."""
        session_id = "test-stop-encoding"
        special_path = "/tmp/spec dir/with $special `chars`.md"
        _write_pending_review_state(
            self.repo, session_id,
            spec_path=special_path, mode="design",
            worktree_path="/tmp/wt with space",
        )
        result = _run_hook(
            "review-dispatch.py",
            cwd=self.repo,
            env_extra={"DEVBREW_SPEC_DISTILL_SESSION_ID": session_id},
        )
        self.assertEqual(result.returncode, 0)
        payload = json.loads(result.stdout)  # ← round-trip via stdlib json
        self.assertIn(special_path, payload["reason"])
        self.assertIn("/tmp/wt with space", payload["reason"])
```

- [ ] **Step 2: Run the new test to verify it PASSES (Task 4's fix already handles this via json.dumps)**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py::TestReviewDispatchSchema::test_reason_encoding_safe_with_special_chars -v
```
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/tests/test_hook_output_schema.py
git commit -m "test(spec-distill): AC1a encoding round-trip with special chars"
```

---

## Task 6: Add AC7.2 fault injection test (rewrite OSError → {} exit)

**Files:**
- Modify: `plugins/spec-distill/tests/test_hook_output_schema.py` (add test method)

- [ ] **Step 1: Append test method**

Add inside `TestReviewDispatchSchema` class:

```python
    def test_rewrite_failure_suppresses_emit(self):
        """AC7.2 — if rewrite_state raises OSError, hook must NOT emit decision:block."""
        session_id = "test-stop-rewrite-fail"
        state_file = _write_pending_review_state(
            self.repo, session_id, spec_path="/tmp/x-spec.md", mode="spec",
        )
        # Make state file read-only to force rewrite_state OSError.
        # We make the *parent directory* read-only so write_text() fails on open.
        parent = state_file.parent
        original_mode = parent.stat().st_mode
        try:
            os.chmod(parent, 0o555)  # r-xr-xr-x
            result = _run_hook(
                "review-dispatch.py",
                cwd=self.repo,
                env_extra={"DEVBREW_SPEC_DISTILL_SESSION_ID": session_id},
            )
        finally:
            os.chmod(parent, original_mode)
        self.assertEqual(result.returncode, 0)
        # stdout must be empty or {} — NOT decision:block
        stripped = result.stdout.strip()
        if stripped:
            payload = json.loads(stripped)
            self.assertNotEqual(
                payload.get("decision"), "block",
                msg=f"AC7.2 violated: emitted decision:block despite rewrite failure: {stripped}",
            )
        # stderr should contain the loud log
        self.assertIn("state rewrite failed", result.stderr)
        self.assertIn("dispatch suppressed", result.stderr)
```

- [ ] **Step 2: Run the test to verify it PASSES (Task 4's `return 0` early return handles this)**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py::TestReviewDispatchSchema::test_rewrite_failure_suppresses_emit -v
```
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/tests/test_hook_output_schema.py
git commit -m "test(spec-distill): AC7.2 fault injection — rewrite OSError suppresses emit"
```

---

## Task 7: Add AC7.3 ordering verification — AST inspection + mock trace

**Files:**
- Modify: `plugins/spec-distill/tests/test_hook_output_schema.py` (add new test class)

- [ ] **Step 1: Append a new test class for ordering verification**

Add to `plugins/spec-distill/tests/test_hook_output_schema.py`:

```python
class TestReviewDispatchOrdering(unittest.TestCase):
    """AC7.3 — verify rewrite_state runs BEFORE print(json.dumps(...))."""

    def _walk_calls_in_order(self, body_nodes, target_names):
        """Yield (lineno, name) for Call nodes whose func.id is in target_names.

        Recurses into FunctionDef body if encountered (handles helper refactor
        per AC7.3.1 commentary)."""
        for node in body_nodes:
            if isinstance(node, ast.Expr) and isinstance(node.value, ast.Call):
                call = node.value
                name = None
                if isinstance(call.func, ast.Name):
                    name = call.func.id
                elif isinstance(call.func, ast.Attribute):
                    name = call.func.attr
                if name in target_names:
                    yield (node.lineno, name)
            if isinstance(node, ast.With):
                yield from self._walk_calls_in_order(node.body, target_names)
            if isinstance(node, ast.Try):
                yield from self._walk_calls_in_order(node.body, target_names)
                for handler in node.handlers:
                    yield from self._walk_calls_in_order(handler.body, target_names)
            if isinstance(node, ast.If):
                yield from self._walk_calls_in_order(node.body, target_names)
                yield from self._walk_calls_in_order(node.orelse, target_names)
            if isinstance(node, ast.FunctionDef):
                yield from self._walk_calls_in_order(node.body, target_names)

    def test_ast_rewrite_before_print(self):
        """AC7.3.1 — static AST scan: rewrite_state appears before print."""
        source = (HOOKS_DIR / "review-dispatch.py").read_text(encoding="utf-8")
        tree = ast.parse(source)
        main_fn = next(
            n for n in tree.body
            if isinstance(n, ast.FunctionDef) and n.name == "main"
        )
        calls = list(self._walk_calls_in_order(main_fn.body, {"rewrite_state", "print"}))
        # Filter to only the calls inside the dispatch flow (i.e. after the
        # final guard returns). Practically: find the last rewrite_state and
        # the last print and assert ordering.
        rewrite_lines = [ln for ln, n in calls if n == "rewrite_state"]
        # Note: `print` is also used for stderr loud logs. We assert the JSON
        # emit print (the last print in main) comes AFTER at least one
        # rewrite_state call.
        print_lines = [ln for ln, n in calls if n == "print"]
        self.assertTrue(rewrite_lines, "no rewrite_state call found in main()")
        self.assertTrue(print_lines, "no print call found in main()")
        # The final emit print must be after the rewrite_state call.
        self.assertLess(
            min(rewrite_lines), max(print_lines),
            msg=f"AC7.3.1 violated: rewrite={rewrite_lines}, print={print_lines}",
        )

    def test_mock_trace_rewrite_before_print(self):
        """AC7.3.3 — execute-time mock trace verifies rewrite runs first."""
        # We import the hook module and patch its rewrite_state + print.
        # Use importlib to load by file path.
        import importlib.util
        spec_module = importlib.util.spec_from_file_location(
            "review_dispatch_under_test", HOOKS_DIR / "review-dispatch.py",
        )
        mod = importlib.util.module_from_spec(spec_module)
        spec_module.loader.exec_module(mod)

        call_log: list[str] = []
        original_rewrite = mod.rewrite_state

        def traced_rewrite(*args, **kwargs):
            call_log.append("rewrite_state")
            return original_rewrite(*args, **kwargs)

        original_print = mod.print  # noqa: T201

        def traced_print(*args, **kwargs):
            # Only count stdout prints (json emit), not stderr loud logs.
            if kwargs.get("file") is None:
                call_log.append("print_stdout")
            return original_print(*args, **kwargs)

        # Build a temp repo + state file so the hook's main() actually runs
        # its dispatch path.
        repo = _make_temp_repo()
        try:
            session_id = "test-mock-trace"
            _write_pending_review_state(
                repo, session_id, spec_path="/tmp/x-spec.md", mode="spec",
            )
            with mock.patch.object(mod, "rewrite_state", traced_rewrite), \
                 mock.patch.object(mod, "print", traced_print), \
                 mock.patch.dict(os.environ, {
                     "DEVBREW_SPEC_DISTILL_SESSION_ID": session_id,
                 }), \
                 mock.patch("sys.stdin", new=__import__("io").StringIO("{}")):
                cwd_before = os.getcwd()
                try:
                    os.chdir(repo)
                    mod.main()
                finally:
                    os.chdir(cwd_before)
        finally:
            shutil.rmtree(repo, ignore_errors=True)
        # The trace must show rewrite_state BEFORE print_stdout.
        try:
            r_idx = call_log.index("rewrite_state")
        except ValueError:
            self.fail(f"rewrite_state not called; trace: {call_log}")
        try:
            p_idx = call_log.index("print_stdout")
        except ValueError:
            self.fail(f"print_stdout not called; trace: {call_log}")
        self.assertLess(
            r_idx, p_idx,
            msg=f"AC7.3.3 violated: rewrite at {r_idx}, print at {p_idx}; trace: {call_log}",
        )
```

- [ ] **Step 2: Run the ordering tests to verify they PASS**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py::TestReviewDispatchOrdering -v
```
Expected: both `test_ast_rewrite_before_print` and `test_mock_trace_rewrite_before_print` PASS.

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/tests/test_hook_output_schema.py
git commit -m "test(spec-distill): AC7.3 ordering verification (AST + mock trace prongs)"
```

---

## Task 8: Add failing PostToolUse (spec-write-validator) advisory schema test

**Files:**
- Modify: `plugins/spec-distill/tests/test_hook_output_schema.py` (add new class)

- [ ] **Step 1: Append the test class**

Add to `plugins/spec-distill/tests/test_hook_output_schema.py`:

```python
class TestSpecWriteValidatorSchema(HookOutputSchemaTestBase):
    """AC2 — spec-write-validator.py advisory branch output schema."""

    def test_design_mode_advisory_emits_additional_context(self):
        # Create a valid design.md fixture so the validator passes structural
        # checks and reaches the advisory branch.
        spec_rel = Path("docs") / "superpowers" / "specs" / "2026-05-17-test-design.md"
        spec_abs = self.repo / spec_rel
        spec_abs.parent.mkdir(parents=True, exist_ok=True)
        spec_abs.write_text(
            "# Test Design\n\nContext / Why\n\nGoals\n\nNon-goals\n\n"
            "Constraints\n\nAcceptance Criteria\n\nFiles\n\nVerification Plan\n\n"
            "Rejected Alternatives\n\nMetadata\n",
            encoding="utf-8",
        )
        stdin_payload = {
            "session_id": "test-pttu",
            "hook_event_name": "PostToolUse",
            "tool_name": "Write",
            "tool_input": {"file_path": str(spec_abs)},
            "tool_output": "ok",
            "cwd": str(self.repo),
        }
        result = _run_hook(
            "spec-write-validator.py",
            cwd=self.repo, stdin_payload=stdin_payload,
            env_extra={"DEVBREW_SPEC_DISTILL_SESSION_ID": "test-pttu"},
        )
        self.assertEqual(result.returncode, 0, msg=f"stderr: {result.stderr}")
        self.assertTrue(result.stdout.strip(), msg="advisory stdout empty")
        payload = json.loads(result.stdout)
        hso = payload.get("hookSpecificOutput", {})
        self.assertEqual(hso.get("hookEventName"), "PostToolUse")
        ac = hso.get("additionalContext", "")
        self.assertIn("structural OK", ac)
        self.assertIn("Reviewer will be dispatched", ac)
        sysmsg = payload.get("systemMessage", "")
        self.assertTrue(sysmsg)
        self.assertLessEqual(len(sysmsg), 120)
        self.assertTrue(sysmsg.startswith("[spec-distill]"))
```

- [ ] **Step 2: Run the test to verify it FAILS**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py::TestSpecWriteValidatorSchema -v
```
Expected: FAIL. `hookSpecificOutput` key missing in current output (current code emits `{"systemMessage":"..."}`).

- [ ] **Step 3: No commit yet — proceed to fix in next task.**

---

## Task 9: Fix spec-write-validator.py advisory branch output schema

**Files:**
- Modify: `plugins/spec-distill/hooks/spec-write-validator.py:167-175` (advisory branch)

- [ ] **Step 1: Replace the advisory print statement**

Edit `plugins/spec-distill/hooks/spec-write-validator.py`. Replace lines 167-175:

```python
    # Advisory systemMessage
    print(
        json.dumps({
            "systemMessage": (
                f"[spec-distill] {mode} structural OK. "
                "Reviewer will be dispatched at turn end."
            )
        }),
        flush=True,
    )
    return 0
```

with:

```python
    # Advisory output (v0.5.0 dual-target: additionalContext for Claude + systemMessage trace).
    print(
        json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": (
                    f"[spec-distill] {mode} structural OK. "
                    "Reviewer will be dispatched at turn end "
                    "(Stop hook will mandate reviewing-spec skill invocation)."
                ),
            },
            "systemMessage": f"[spec-distill] {mode} OK · reviewer dispatch pending",
        }),
        flush=True,
    )
    return 0
```

- [ ] **Step 2: Run the test to verify it PASSES**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py::TestSpecWriteValidatorSchema -v
```
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/hooks/spec-write-validator.py plugins/spec-distill/tests/test_hook_output_schema.py
git commit -m "fix(spec-distill): spec-write-validator advisory output schema (AC2)"
```

---

## Task 10: Add failing UserPromptSubmit (pending-review-reminder) schema test

**Files:**
- Modify: `plugins/spec-distill/tests/test_hook_output_schema.py`

- [ ] **Step 1: Append the test class**

```python
class TestPendingReviewReminderSchema(HookOutputSchemaTestBase):
    """AC3 — pending-review-reminder.py output schema."""

    def test_pending_review_past_ttl_emits_reminder_in_additional_context(self):
        session_id = "test-reminder"
        # last_dispatched_at older than 30s default TTL.
        old_ts = "2026-05-16T00:00:00Z"
        _write_pending_review_state(
            self.repo, session_id,
            spec_path="/tmp/x-design.md", mode="design",
            worktree_path="/tmp/wt",
            last_dispatched_at=old_ts,
        )
        stdin_payload = {"user_prompt": "hi", "session_id": session_id}
        result = _run_hook(
            "pending-review-reminder.py",
            cwd=self.repo, stdin_payload=stdin_payload,
            env_extra={"DEVBREW_SPEC_DISTILL_SESSION_ID": session_id},
        )
        self.assertEqual(result.returncode, 0, msg=f"stderr: {result.stderr}")
        self.assertTrue(result.stdout.strip())
        payload = json.loads(result.stdout)
        hso = payload.get("hookSpecificOutput", {})
        self.assertEqual(hso.get("hookEventName"), "UserPromptSubmit")
        ac = hso.get("additionalContext", "")
        self.assertIn("REMINDER", ac)
        self.assertIn("pending_review", ac)
        self.assertIn("reviewing-spec", ac)
        sysmsg = payload.get("systemMessage", "")
        self.assertTrue(sysmsg)
        self.assertLessEqual(len(sysmsg), 120)
```

- [ ] **Step 2: Run the test to verify it FAILS**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py::TestPendingReviewReminderSchema -v
```
Expected: FAIL — `hookSpecificOutput` missing.

- [ ] **Step 3: No commit yet — proceed to fix.**

---

## Task 11: Fix pending-review-reminder.py output schema

**Files:**
- Modify: `plugins/spec-distill/hooks/pending-review-reminder.py:105`

- [ ] **Step 1: Replace the print statement**

Edit `plugins/spec-distill/hooks/pending-review-reminder.py`. Replace line 105:

```python
    print(json.dumps({"systemMessage": " ".join(parts)}), flush=True)
```

with:

```python
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": " ".join(parts),
        },
        "systemMessage": "[spec-distill] pending review reminder re-dispatched",
    }), flush=True)
```

- [ ] **Step 2: Run the test to verify it PASSES**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py::TestPendingReviewReminderSchema -v
```
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/hooks/pending-review-reminder.py plugins/spec-distill/tests/test_hook_output_schema.py
git commit -m "fix(spec-distill): pending-review-reminder output schema (AC3)"
```

---

## Task 12: Add failing UserPromptSubmit (interview-trigger.sh) schema test

**Files:**
- Modify: `plugins/spec-distill/tests/test_hook_output_schema.py`

- [ ] **Step 1: Append the test class**

```python
class TestInterviewTriggerSchema(HookOutputSchemaTestBase):
    """AC4 — interview-trigger.sh output schema (bash, jq + no-jq paths)."""

    def _run(self, env_extra=None):
        stdin_payload = {"user_prompt": "make a chat app"}
        return _run_hook(
            "interview-trigger.sh",
            cwd=self.repo, stdin_payload=stdin_payload,
            env_extra=env_extra, binary="bash",
        )

    @unittest.skipUnless(shutil.which("jq"), "jq required for AC4-a")
    def test_jq_path_emits_additional_context(self):
        result = self._run()
        self.assertEqual(result.returncode, 0, msg=f"stderr: {result.stderr}")
        self.assertTrue(result.stdout.strip())
        payload = json.loads(result.stdout)
        hso = payload.get("hookSpecificOutput", {})
        self.assertEqual(hso.get("hookEventName"), "UserPromptSubmit")
        ac = hso.get("additionalContext", "")
        self.assertIn("interview", ac)
        self.assertIn("advisory", ac)
        sysmsg = payload.get("systemMessage", "")
        self.assertTrue(sysmsg)
        self.assertLessEqual(len(sysmsg), 120)

    def test_no_jq_fallback_emits_additional_context(self):
        # Force no-jq by stripping PATH to a dir without jq.
        no_jq_bin = self.repo / "no-jq-bin"
        no_jq_bin.mkdir()
        # Symlink only bash + python3 + sed + tr + grep + printf + cat + wc.
        for tool in ("bash", "python3", "sed", "tr", "grep", "printf", "cat", "wc"):
            src = shutil.which(tool)
            if src:
                (no_jq_bin / tool).symlink_to(src)
        result = self._run(env_extra={"PATH": str(no_jq_bin)})
        self.assertEqual(result.returncode, 0, msg=f"stderr: {result.stderr}")
        self.assertTrue(result.stdout.strip())
        payload = json.loads(result.stdout)
        hso = payload.get("hookSpecificOutput", {})
        self.assertEqual(hso.get("hookEventName"), "UserPromptSubmit")
        self.assertIn("interview", hso.get("additionalContext", ""))
```

- [ ] **Step 2: Run the test to verify it FAILS (both jq and no-jq)**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py::TestInterviewTriggerSchema -v
```
Expected: FAIL on both — current bash emits `{systemMessage: ...}` without hookSpecificOutput.

- [ ] **Step 3: No commit yet — proceed to fix.**

---

## Task 13: Fix interview-trigger.sh (jq + no-jq fallback)

**Files:**
- Modify: `plugins/spec-distill/hooks/interview-trigger.sh:60-67`

- [ ] **Step 1: Replace the emit block**

Edit `plugins/spec-distill/hooks/interview-trigger.sh`. Replace lines 60-67:

```bash
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg m "$msg" '{systemMessage: $m}'
  else
    # Manual JSON-escape fallback for environments without jq
    escaped=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
    printf '{"systemMessage":"%s"}\n' "$escaped"
  fi
fi
```

with:

```bash
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg m "$msg" '{
        hookSpecificOutput: {
            hookEventName: "UserPromptSubmit",
            additionalContext: $m
        },
        systemMessage: "[spec-distill] interview suggestion (see context)"
    }'
  else
    # Manual JSON-escape fallback (sync with session-anchor.sh — same escape strategy)
    escaped=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ' | tr -d '\r')
    printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"},"systemMessage":"[spec-distill] interview suggestion (see context)"}\n' "$escaped"
  fi
fi
```

- [ ] **Step 2: Run the test to verify it PASSES**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py::TestInterviewTriggerSchema -v
```
Expected: PASS for both jq and no-jq tests.

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/hooks/interview-trigger.sh plugins/spec-distill/tests/test_hook_output_schema.py
git commit -m "fix(spec-distill): interview-trigger.sh output schema + CR-safe fallback (AC4)"
```

---

## Task 14: Add failing SessionStart (session-anchor.sh) schema test

**Files:**
- Modify: `plugins/spec-distill/tests/test_hook_output_schema.py`

- [ ] **Step 1: Append the test class**

```python
class TestSessionAnchorSchema(HookOutputSchemaTestBase):
    """AC5 — session-anchor.sh output schema (bash, jq + no-jq paths)."""

    def setUp(self):
        super().setUp()
        # Pre-populate a state dir so session-anchor finds "previous sessions".
        prev = self.repo / ".claude" / "spec-distill" / "previous-session"
        prev.mkdir(parents=True)
        (prev / "state.local.md").write_text(
            "---\nsession_id: previous-session\n---\n", encoding="utf-8",
        )

    def _run(self, env_extra=None):
        env = {"CLAUDE_PROJECT_DIR": str(self.repo)}
        if env_extra:
            env.update(env_extra)
        return _run_hook(
            "session-anchor.sh",
            cwd=self.repo, env_extra=env, binary="bash",
        )

    @unittest.skipUnless(shutil.which("jq"), "jq required for AC5-a")
    def test_jq_path_emits_additional_context(self):
        result = self._run()
        self.assertEqual(result.returncode, 0, msg=f"stderr: {result.stderr}")
        self.assertTrue(result.stdout.strip(), msg=f"empty stdout; stderr: {result.stderr}")
        payload = json.loads(result.stdout)
        hso = payload.get("hookSpecificOutput", {})
        self.assertEqual(hso.get("hookEventName"), "SessionStart")
        ac = hso.get("additionalContext", "")
        self.assertIn("이전 인터뷰 세션", ac)
        self.assertIn("/interview", ac)
        sysmsg = payload.get("systemMessage", "")
        self.assertTrue(sysmsg)
        self.assertLessEqual(len(sysmsg), 120)

    def test_no_jq_fallback_emits_additional_context(self):
        no_jq_bin = self.repo / "no-jq-bin-2"
        no_jq_bin.mkdir()
        for tool in ("bash", "python3", "sed", "tr", "grep", "printf", "cat",
                     "wc", "find", "head"):
            src = shutil.which(tool)
            if src:
                (no_jq_bin / tool).symlink_to(src)
        result = self._run(env_extra={"PATH": str(no_jq_bin)})
        self.assertEqual(result.returncode, 0, msg=f"stderr: {result.stderr}")
        self.assertTrue(result.stdout.strip())
        payload = json.loads(result.stdout)
        hso = payload.get("hookSpecificOutput", {})
        self.assertEqual(hso.get("hookEventName"), "SessionStart")
        self.assertIn("이전 인터뷰 세션", hso.get("additionalContext", ""))
```

- [ ] **Step 2: Run the test to verify it FAILS**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py::TestSessionAnchorSchema -v
```
Expected: FAIL on both jq and no-jq.

- [ ] **Step 3: No commit yet — proceed to fix.**

---

## Task 15: Fix session-anchor.sh (jq + no-jq fallback)

**Files:**
- Modify: `plugins/spec-distill/hooks/session-anchor.sh:44-51`

- [ ] **Step 1: Replace the emit block**

Edit `plugins/spec-distill/hooks/session-anchor.sh`. Replace lines 44-51 onwards (the jq/no-jq emit):

```bash
if command -v jq >/dev/null 2>&1; then
  jq -n --arg m "$msg" '{systemMessage: $m}'
else
  escaped=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
  printf '{"systemMessage":"%s"}\n' "$escaped"
fi

exit 0
```

with:

```bash
if command -v jq >/dev/null 2>&1; then
  jq -n --arg m "$msg" '{
      hookSpecificOutput: {
          hookEventName: "SessionStart",
          additionalContext: $m
      },
      systemMessage: "[spec-distill] previous interview session(s) detected"
  }'
else
  # Manual JSON-escape fallback (sed-based: backslash + double-quote + LF + CR only;
  # null byte / other control chars / non-BMP unicode out of scope — jq path handles those).
  escaped=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ' | tr -d '\r')
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"},"systemMessage":"[spec-distill] previous interview session(s) detected"}\n' "$escaped"
fi

exit 0
```

- [ ] **Step 2: Run the test to verify it PASSES**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py::TestSessionAnchorSchema -v
```
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/hooks/session-anchor.sh plugins/spec-distill/tests/test_hook_output_schema.py
git commit -m "fix(spec-distill): session-anchor.sh output schema + CR-safe fallback (AC5)"
```

---

## Task 16: Add kill switch tests (AC10/AC11) for all 5 hooks

**Files:**
- Modify: `plugins/spec-distill/tests/test_hook_output_schema.py` (add class)

- [ ] **Step 1: Append the kill switch test class**

```python
class TestKillSwitches(HookOutputSchemaTestBase):
    """AC10/AC11 — DEVBREW_DISABLE_SPEC_DISTILL=1 and DEVBREW_SKIP_HOOKS=spec-distill:<event>."""

    def _empty_or_braces(self, stdout: str) -> bool:
        s = stdout.strip()
        return s == "" or s == "{}"

    def test_global_disable_silences_review_dispatch(self):
        session_id = "ks-review"
        _write_pending_review_state(self.repo, session_id, spec_path="/x", mode="spec")
        result = _run_hook(
            "review-dispatch.py", cwd=self.repo,
            env_extra={
                "DEVBREW_DISABLE_SPEC_DISTILL": "1",
                "DEVBREW_SPEC_DISTILL_SESSION_ID": session_id,
            },
        )
        self.assertEqual(result.returncode, 0)
        self.assertTrue(self._empty_or_braces(result.stdout),
                        msg=f"unexpected output: {result.stdout!r}")

    def test_hook_specific_disable_silences_review_dispatch(self):
        session_id = "ks-review-2"
        _write_pending_review_state(self.repo, session_id, spec_path="/x", mode="spec")
        result = _run_hook(
            "review-dispatch.py", cwd=self.repo,
            env_extra={
                "DEVBREW_SKIP_HOOKS": "spec-distill:Stop",
                "DEVBREW_SPEC_DISTILL_SESSION_ID": session_id,
            },
        )
        self.assertEqual(result.returncode, 0)
        self.assertTrue(self._empty_or_braces(result.stdout))

    def test_global_disable_silences_spec_write_validator(self):
        spec_abs = self.repo / "docs" / "superpowers" / "specs" / "x-design.md"
        spec_abs.parent.mkdir(parents=True, exist_ok=True)
        spec_abs.write_text("# x\n", encoding="utf-8")
        stdin_payload = {
            "tool_name": "Write",
            "tool_input": {"file_path": str(spec_abs)},
            "hook_event_name": "PostToolUse",
        }
        result = _run_hook(
            "spec-write-validator.py", cwd=self.repo, stdin_payload=stdin_payload,
            env_extra={"DEVBREW_DISABLE_SPEC_DISTILL": "1"},
        )
        self.assertEqual(result.returncode, 0)
        self.assertTrue(self._empty_or_braces(result.stdout))

    def test_global_disable_silences_pending_review_reminder(self):
        session_id = "ks-reminder"
        _write_pending_review_state(
            self.repo, session_id, spec_path="/x", mode="spec",
            last_dispatched_at="2026-05-16T00:00:00Z",  # past TTL
        )
        result = _run_hook(
            "pending-review-reminder.py", cwd=self.repo,
            stdin_payload={"user_prompt": "hi"},
            env_extra={
                "DEVBREW_DISABLE_SPEC_DISTILL": "1",
                "DEVBREW_SPEC_DISTILL_SESSION_ID": session_id,
            },
        )
        self.assertEqual(result.returncode, 0)
        self.assertTrue(self._empty_or_braces(result.stdout))

    def test_global_disable_silences_interview_trigger(self):
        result = _run_hook(
            "interview-trigger.sh", cwd=self.repo,
            stdin_payload={"user_prompt": "make a chat app"},
            env_extra={"DEVBREW_DISABLE_SPEC_DISTILL": "1"},
            binary="bash",
        )
        self.assertEqual(result.returncode, 0)
        self.assertTrue(self._empty_or_braces(result.stdout))

    def test_global_disable_silences_session_anchor(self):
        prev = self.repo / ".claude" / "spec-distill" / "x"
        prev.mkdir(parents=True)
        (prev / "state.local.md").write_text("---\n---\n", encoding="utf-8")
        result = _run_hook(
            "session-anchor.sh", cwd=self.repo,
            env_extra={
                "DEVBREW_DISABLE_SPEC_DISTILL": "1",
                "CLAUDE_PROJECT_DIR": str(self.repo),
            },
            binary="bash",
        )
        self.assertEqual(result.returncode, 0)
        self.assertTrue(self._empty_or_braces(result.stdout))
```

- [ ] **Step 2: Run the kill switch tests**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py::TestKillSwitches -v
```
Expected: all 6 PASS (kill switches already implemented in existing code).

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/tests/test_hook_output_schema.py
git commit -m "test(spec-distill): kill switch coverage for all 5 hooks (AC10/AC11)"
```

---

## Task 17: Add NG9 cross-resolver advisory test (skipUnless worktree)

**Files:**
- Modify: `plugins/spec-distill/tests/test_hook_output_schema.py`

- [ ] **Step 1: Append the advisory test class**

```python
def _in_worktree() -> bool:
    """Detect git worktree (vs main repo) via .git file (not dir)."""
    try:
        cp = subprocess.run(
            ["git", "rev-parse", "--is-inside-work-tree"],
            cwd=REPO_ROOT, capture_output=True, text=True, timeout=3, check=False,
        )
        if cp.returncode != 0 or cp.stdout.strip() != "true":
            return False
        # main repo has .git/ dir; worktree has .git file pointing to gitdir.
        dot_git = REPO_ROOT / ".git"
        return dot_git.is_file()
    except (OSError, subprocess.TimeoutExpired):
        return False


class TestCrossResolverAdvisory(unittest.TestCase):
    """NG9 — Python state_path vs bash CLAUDE_PROJECT_DIR resolver consistency.

    Skips if not running inside a worktree (the cross-resolver mismatch only
    manifests there). PASS = both resolvers point to the same dir; FAIL = the
    follow-up unification PR is needed.
    """

    @unittest.skipUnless(_in_worktree(), "cross-resolver test runs only inside a git worktree")
    def test_python_and_bash_resolvers_agree(self):
        # Python resolver: state_path.state_root()
        sys.path.insert(0, str(HOOKS_DIR))
        try:
            import state_path  # type: ignore
            py_root = state_path.state_root()
        finally:
            sys.path.pop(0)
        # Bash resolver: ${CLAUDE_PROJECT_DIR:-$PWD}/.claude/spec-distill
        bash_root = Path(os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())) \
            / ".claude" / "spec-distill"
        self.assertEqual(
            py_root.resolve(), bash_root.resolve(),
            msg=(
                "Python state_path and bash CLAUDE_PROJECT_DIR resolvers disagree. "
                "Follow-up PR per spec NG9 needed."
            ),
        )
```

- [ ] **Step 2: Run the test (will skip if not in worktree, pass if in worktree with aligned resolvers)**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py::TestCrossResolverAdvisory -v
```
Expected: either `skipped` (not in worktree) or PASS (in worktree, resolvers agree).

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/tests/test_hook_output_schema.py
git commit -m "test(spec-distill): NG9 cross-resolver advisory (skipUnless worktree)"
```

---

## Task 18: Update test_review_dispatch.sh assertions to new schema

**Files:**
- Modify: `plugins/spec-distill/tests/test_review_dispatch.sh`

- [ ] **Step 1: Read the current test file to find all assertion lines using systemMessage**

Run:
```bash
grep -n 'systemMessage\|jq' plugins/spec-distill/tests/test_review_dispatch.sh
```
Note the line numbers (typical: case 11, 13, 14 — wherever `systemMessage` is grep'd).

- [ ] **Step 2: Edit assertions — replace systemMessage substring grep with jq decision+reason check**

In `plugins/spec-distill/tests/test_review_dispatch.sh`, for each test case that asserts an emit happened, change patterns like:

```bash
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"systemMessage"' \
  && echo "$out" | grep -q 'MANDATORY' \
  && echo "$out" | grep -q '/tmp/some-spec.md' \
  && echo "$out" | grep -q 'reviewing-spec' \
  && echo "$out" | grep -q 'terminal handoff' \
  && note PASS "..." \
  || note FAIL "..."
```

to:

```bash
[[ $rc -eq 0 ]] \
  && echo "$out" | jq -e '.decision == "block"' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("MANDATORY")' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("/tmp/some-spec.md")' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("reviewing-spec")' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("terminal handoff")' >/dev/null \
  && echo "$out" | jq -e '.systemMessage | startswith("[spec-distill]")' >/dev/null \
  && note PASS "..." \
  || note FAIL "..."
```

Cases that assert silent skip (`[[ -z "$out" || "$out" == "" ]]`) remain unchanged.

- [ ] **Step 3: Run the bash test to verify it PASSES**

Run:
```bash
bash plugins/spec-distill/tests/test_review_dispatch.sh
```
Expected: all cases PASS (or same PASS count as v0.4.0 baseline).

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/tests/test_review_dispatch.sh
git commit -m "test(spec-distill): test_review_dispatch.sh assertions → jq JSON path (AC13)"
```

---

## Task 19: Update test_review_dispatch_design_mandate.sh assertions

**Files:**
- Modify: `plugins/spec-distill/tests/test_review_dispatch_design_mandate.sh`

- [ ] **Step 1: Inspect current assertions**

Run:
```bash
grep -n 'systemMessage' plugins/spec-distill/tests/test_review_dispatch_design_mandate.sh
```

- [ ] **Step 2: Apply the same `systemMessage → decision+reason jq` migration as Task 18**

For each assertion that previously grep'd for `systemMessage` substring, replace with the equivalent `jq -e '.decision == "block"' >/dev/null && jq -e '.reason | contains("...")' >/dev/null` chain. Preserve the design-mode-specific substring assertions (e.g., `mode: design`).

- [ ] **Step 3: Run to verify**

Run:
```bash
bash plugins/spec-distill/tests/test_review_dispatch_design_mandate.sh
```
Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/tests/test_review_dispatch_design_mandate.sh
git commit -m "test(spec-distill): test_review_dispatch_design_mandate.sh assertions → jq (AC13)"
```

---

## Task 20: Update test_hooks.sh (if it has spec-write-validator advisory cases)

**Files:**
- Modify: `plugins/spec-distill/tests/test_hooks.sh`

- [ ] **Step 1: Inspect**

Run:
```bash
grep -n 'systemMessage\|spec-write-validator' plugins/spec-distill/tests/test_hooks.sh
```
If no assertions reference `systemMessage` for the advisory branch, skip steps 2-3 (only commit step 4 with note).

- [ ] **Step 2: For each advisory assertion, migrate to hookSpecificOutput.additionalContext**

Replace patterns like:

```bash
echo "$out" | grep -q 'structural OK'
```

(if they exist as `grep '"systemMessage"'` checks) with:

```bash
echo "$out" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null \
  && echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("structural OK")' >/dev/null
```

- [ ] **Step 3: Run to verify**

Run:
```bash
bash plugins/spec-distill/tests/test_hooks.sh
```
Expected: all PASS.

- [ ] **Step 4: Commit (even if no changes — record audit)**

```bash
git add plugins/spec-distill/tests/test_hooks.sh
git commit -m "test(spec-distill): test_hooks.sh assertions audit/update (AC14)" --allow-empty
```

---

## Task 21: Update test_reminder_hook.sh assertions

**Files:**
- Modify: `plugins/spec-distill/tests/test_reminder_hook.sh`

- [ ] **Step 1: Inspect**

Run:
```bash
grep -n 'systemMessage\|reviewing-spec\|REMINDER' plugins/spec-distill/tests/test_reminder_hook.sh
```

- [ ] **Step 2: Replace systemMessage substring grep with hookSpecificOutput.additionalContext jq check**

For each PASS assertion that previously did `echo "$out" | grep -q "reviewing-spec"`, change to:

```bash
echo "$out" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' >/dev/null \
  && echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("REMINDER")' >/dev/null \
  && echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("reviewing-spec")' >/dev/null
```

- [ ] **Step 3: Run to verify**

Run:
```bash
bash plugins/spec-distill/tests/test_reminder_hook.sh
```
Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/tests/test_reminder_hook.sh
git commit -m "test(spec-distill): test_reminder_hook.sh assertions → jq (AC14)"
```

---

## Task 22: Update test_spec_write_validator.sh advisory case assertions

**Files:**
- Modify: `plugins/spec-distill/tests/test_spec_write_validator.sh`

- [ ] **Step 1: Inspect**

Run:
```bash
grep -n 'systemMessage\|structural OK\|advisory' plugins/spec-distill/tests/test_spec_write_validator.sh
```

- [ ] **Step 2: Update advisory-branch assertions (do NOT touch block-branch — already uses decision+reason)**

For PASS cases that previously did `echo "$out" | grep -q 'structural OK'` or `grep -q '"systemMessage"'`, change to:

```bash
echo "$out" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null \
  && echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("structural OK")' >/dev/null
```

Block-branch cases that already check `jq -e '.decision == "block"' >/dev/null` remain unchanged.

- [ ] **Step 3: Run to verify**

Run:
```bash
bash plugins/spec-distill/tests/test_spec_write_validator.sh
```
Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/tests/test_spec_write_validator.sh
git commit -m "test(spec-distill): test_spec_write_validator.sh advisory assertions → jq (AC14)"
```

---

## Task 23: Bump plugin.json version 0.4.0 → 0.5.0

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`

- [ ] **Step 1: Edit version field**

Edit `plugins/spec-distill/.claude-plugin/plugin.json`. Change:

```json
  "version": "0.4.0",
```

to:

```json
  "version": "0.5.0",
```

Leave `name`, `description`, `author` untouched.

- [ ] **Step 2: Verify the diff is single-line**

Run:
```bash
git diff plugins/spec-distill/.claude-plugin/plugin.json
```
Expected: only the `version` line changed.

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json
git commit -m "chore(spec-distill): bump plugin.json 0.4.0 → 0.5.0 (AC16)"
```

---

## Task 24: Add CHANGELOG [0.5.0] entry

**Files:**
- Modify: `plugins/spec-distill/CHANGELOG.md`

- [ ] **Step 1: Insert new entry at the top (above `## [0.4.0]`)**

Edit `plugins/spec-distill/CHANGELOG.md`. After the file's `# Changelog` heading (line 1) and blank line, insert:

```markdown
## [0.5.0] — 2026-05-17

### Fixed
- 5개 hook (`review-dispatch.py`, `spec-write-validator.py` advisory 분기, `pending-review-reminder.py`, `interview-trigger.sh`, `session-anchor.sh`) 의 stdout JSON이 Claude LLM context로 도달하지 않던 silent failure. `systemMessage` 필드는 Claude Code 사양상 user transcript 표시 전용이며 LLM context inject 메커니즘이 아니다. 올바른 필드는 `hookSpecificOutput.additionalContext` (PostToolUse/UserPromptSubmit/SessionStart) 또는 Stop hook의 `decision:"block" + reason` 페어. dual-target 출력 (Claude-target field + `systemMessage` 짧은 흔적, ≤120자, "[spec-distill]" prefix) 으로 정정 — Claude는 context로 받고 user는 transcript에서 발화 흔적 확인 가능.
- `review-dispatch.py` `rewrite_state()` 호출 순서 정정 (write-before-emit, AC7.1). `rewrite_state()` 본문에 `f.flush()` + `os.fsync(f.fileno())` 추가하여 OS-level durability 보장. 이전 ordering (print → rewrite) 은 동일 turn 안에서 두 번째 Stop fire가 stale state를 읽고 두 번째 block 출력하는 block storm을 일으킬 수 있었음.
- `review-dispatch.py` rewrite OSError 시 `{}` exit 0 (block emit 안 함, AC7.2). 이번 dispatch 1회는 누락되나 L4b UserPromptSubmit reminder가 다음 user prompt에서 dispatch를 살림 — block storm 회피가 우선.
- `interview-trigger.sh` no-jq fallback에 `tr -d '\r'` 추가하여 session-anchor.sh와 CR 처리 대칭.

### Changed
- Stop hook (`review-dispatch.py`) 의 `decision:"block"` 이 Stop을 막고 Claude를 즉시 continue 시키므로 "다음 turn 첫 액션은 reviewing-spec" 강제가 user 입력 대기 없이 작동. 기존 30초 TTL guard (`DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC`) 가 무한 block 루프 방지를 그대로 담당.

### Added
- `tests/test_hook_output_schema.py` — Python `unittest` 기반 통합 회귀 방지 test. 5개 hook 모두에 대해 happy-path schema assertion + AC1a 인코딩 round-trip + AC7.2 fault injection + AC7.3 ordering 3-prong (AST inspection + mock-based trace) + AC10/AC11 kill switch + NG9 cross-resolver advisory (skipUnless worktree). bash fallback (jq-없는 환경) 케이스는 `unittest.skipUnless`로 환경 감지.

### Security
- kill switch 5개 (`DEVBREW_DISABLE_SPEC_DISTILL=1` 전역 + `DEVBREW_SKIP_HOOKS=spec-distill:<event>` hook 단위) 모두 무변경. 신규 env var 없음.
- bash hook no-jq fallback escape scope: backslash + double-quote + LF + CR만 처리. null byte / 기타 control char / non-BMP unicode는 처리 범위 밖 — jq path에서 full JSON escape 처리.

```

(Leave v0.4.0 entry below untouched.)

- [ ] **Step 2: Verify the diff**

Run:
```bash
head -30 plugins/spec-distill/CHANGELOG.md
```
Expected: new `## [0.5.0]` block at top, v0.4.0 still below.

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/CHANGELOG.md
git commit -m "docs(spec-distill): CHANGELOG [0.5.0] — 2026-05-17 entry (AC17)"
```

---

## Task 25: Update README.md — Hooks section + Principles Instantiated

**Files:**
- Modify: `plugins/spec-distill/README.md`

- [ ] **Step 1: Read the current README to find target sections**

Run:
```bash
grep -n '^##\|^###' plugins/spec-distill/README.md
```
Identify the line numbers of `## Hooks` (or "Hooks Installed") and `## Principles Instantiated` (if present; if not, add it).

- [ ] **Step 2: Update the Hooks section — append dual-target output paragraph**

In the Hooks section, after the existing per-hook descriptions, add one paragraph:

```markdown
**Output schema (v0.5.0+):** 모든 hook이 *dual-target output* 패턴 — Claude-target field (`hookSpecificOutput.additionalContext` for PostToolUse/UserPromptSubmit/SessionStart, `decision:"block" + reason` for Stop) + `systemMessage` (짧은 흔적, ≤120자, `[spec-distill]` prefix). Claude는 context로 dispatch 메시지를 받고, user는 transcript에서 hook 발화 흔적을 확인 가능. 이전 (`v0.4.0` 이하) 의 `systemMessage`-only 출력은 user transcript에는 보였으나 Claude LLM context로 inject되지 않는 silent failure였음 — `v0.5.0`에서 fix. Reference 패턴: `plugins/quality-gates/hooks/stop-hook.py:845-849`.
```

- [ ] **Step 3: Update / add Principles Instantiated section**

Find or create a `## Principles Instantiated` section. Add (or extend) with:

```markdown
- **Law 2 (Writer/Reviewer Never Share a Pass) — infrastructure operability**: spec-reviewer agent의 writer/reviewer 물리 분리가 의미를 가지려면 reviewer dispatch가 Claude context에 *실제로* 도달해야 한다. v0.5.0의 dual-target output fix가 이 baseline을 보장. dispatch가 silent하게 lost되면 reviewer persona 분리 자체가 무의미.
- **Law 3 (Every Cycle Must Leave the System Smarter)**: v0.5.0 PR이 hook 코드 fix + `tests/test_hook_output_schema.py` 회귀 방지 test + CHANGELOG 명시 + design.md (`docs/superpowers/specs/2026-05-17-spec-distill-hook-context-injection-design.md`) — 4-layer compounding 흔적. 같은 클래스의 silent-output mistake가 미래에 들어오면 CI에서 즉시 잡힘.
```

- [ ] **Step 4: Verify the diff**

Run:
```bash
git diff plugins/spec-distill/README.md
```
Expected: two text additions (one in Hooks section, one in Principles).

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/README.md
git commit -m "docs(spec-distill): README Hooks + Principles Instantiated (AC18/AC19)"
```

---

## Task 26: Final integration run — all tests must pass

**Files:**
- No file changes. Verification only.

- [ ] **Step 1: Run the new Python test suite**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py -v
```
Expected: all tests PASS (cross-resolver may skip if not in worktree).

- [ ] **Step 2: Run all updated bash tests**

Run:
```bash
for t in test_review_dispatch.sh test_review_dispatch_design_mandate.sh test_hooks.sh test_reminder_hook.sh test_spec_write_validator.sh; do
  echo "=== $t ==="
  bash plugins/spec-distill/tests/$t
done
```
Expected: each test prints PASS lines, no FAIL.

- [ ] **Step 3: Verify no kill switch regression**

Run:
```bash
DEVBREW_DISABLE_SPEC_DISTILL=1 python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py::TestKillSwitches -v
```
Expected: PASS (kill switch tests internally set the env per-case).

- [ ] **Step 4: Verify plugin.json + CHANGELOG + README diffs**

Run:
```bash
git diff origin/main -- plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/README.md
```
Expected: version bump line, new CHANGELOG entry, README additions.

- [ ] **Step 5: Verify no unintended files changed**

Run:
```bash
git diff origin/main --stat -- plugins/spec-distill/
```
Expected file list:
- `plugins/spec-distill/.claude-plugin/plugin.json`
- `plugins/spec-distill/CHANGELOG.md`
- `plugins/spec-distill/README.md`
- `plugins/spec-distill/hooks/review-dispatch.py`
- `plugins/spec-distill/hooks/spec-write-validator.py`
- `plugins/spec-distill/hooks/pending-review-reminder.py`
- `plugins/spec-distill/hooks/interview-trigger.sh`
- `plugins/spec-distill/hooks/session-anchor.sh`
- `plugins/spec-distill/tests/test_hook_output_schema.py` (new)
- `plugins/spec-distill/tests/test_review_dispatch.sh`
- `plugins/spec-distill/tests/test_review_dispatch_design_mandate.sh`
- `plugins/spec-distill/tests/test_hooks.sh` (possibly empty if no advisory cases)
- `plugins/spec-distill/tests/test_reminder_hook.sh`
- `plugins/spec-distill/tests/test_spec_write_validator.sh`

NOT in the list (should be unchanged):
- `plugins/spec-distill/hooks/hooks.json`
- `plugins/spec-distill/hooks/state_path.py`
- `plugins/spec-distill/scripts/parse_spec_structure.py`
- any file under `plugins/spec-distill/skills/`, `agents/`, `commands/`

- [ ] **Step 6: V5b manual Claude Code E2E (inherent, no automation)**

Per spec V5b: in a fresh Claude Code session (or current one), write a new design.md under `docs/superpowers/specs/` and observe:
1. Claude tool result for the Write should be followed by a system reminder containing `[spec-distill] design structural OK. Reviewer will be dispatched at turn end (...)`.
2. At end of turn, when Claude tries to Stop, the Stop hook should fire `decision:"block"` and Claude should immediately continue, invoking the `reviewing-spec` skill against the new file.

If either step is silent (no system reminder visible to Claude), the PR's core hypothesis (Claude Code spec verbatim quotes in spec §C4) is invalidated and the PR must be blocked.

- [ ] **Step 7: Commit (verification log only, no file changes — skip if nothing to commit)**

Run:
```bash
git status
```
If clean: no commit needed. Plan complete.

---

## Self-Review Checklist (Plan Author)

- [x] Every AC mapped to at least one task: AC1→Task 3-4, AC1a→Task 5, AC2→Task 8-9, AC3→Task 10-11, AC4→Task 12-13, AC5→Task 14-15, AC6 (state schema unchanged)→implicit, AC7.1/7.2/7.3→Task 4 + 6 + 7, AC8 (TTL guard)→existing tests in Task 18-19, AC9 (cleanup)→state_path.py unchanged, AC10/AC11→Task 16, AC12→Tasks 2-17 (cumulative), AC13/14→Tasks 18-22, AC15→Task 26 verification, AC16→Task 23, AC17→Task 24, AC18/19→Task 25.
- [x] No placeholders: each step has exact file paths, line numbers, code blocks, and commands.
- [x] Type consistency: `_run_hook()`, `_write_pending_review_state()`, `_make_temp_repo()` helpers defined once in Task 2, reused identically across Tasks 3-17.
- [x] V5a (automated) covered by Tasks 3-17. V5b (manual) explicit in Task 26 step 6.
- [x] devbrew Plugin Shape: version bump (Task 23), CHANGELOG (Task 24), README (Task 25) all present.

---

**End of plan.**
