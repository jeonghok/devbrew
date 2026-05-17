# project-init docs-lint Hook v1.4.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `plugins/project-init/`에 root context 파일 (`CLAUDE.md`/`AGENTS.md`/`.claude/CLAUDE.md`/`.claude/AGENTS.md`) 의 agent-readable convention 5개를 PostToolUse advisory로 검증하는 `docs-lint.py` hook을 신설하고, `/project-init` command가 AGENTS.md를 canonical로 작성하면서 CLAUDE.md를 `@AGENTS.md` thin pointer로 발행하도록 갱신 (v1.4.0).

**Architecture:** 기존 `post-tool-use.py`와 동일 advisory 패턴 — `decision: "block"` 안 씀, 위반 시 `systemMessage` 출력만. 두 hook은 같은 `hooks.json`에 공존, 다른 matcher (기존 = `Bash`, 신규 = `Write|Edit|MultiEdit`). 코드는 stdlib only, Python 3. 5개 rule (R1 size, R2 TOC, R5 fenced code lang, R6 internal links resolve, R-pointer CLAUDE/AGENTS drift) 을 각각 독립 함수로 구현해 unit test로 격리 검증.

**Tech Stack:** Python 3 (stdlib: `json`, `os`, `re`, `sys`, `pathlib`, `unittest`, `tempfile`). 셸: bash. 외부 의존성 없음.

**Spec:** [`docs/superpowers/specs/2026-05-17-project-init-docs-lint-hook-design.md`](../specs/2026-05-17-project-init-docs-lint-hook-design.md) — 4-round spec-reviewer approved, 34+ ACs, 9+ rejected alternatives.

**Pre-existing context:** 기존 `plugins/project-init/hooks/post-tool-use.py:149-154` 의 `kill_switch_active()` 함수가 새 hook의 패턴 미러링 대상. 기존 `hooks.json`은 `PostToolUse` + matcher `Bash` 단일 entry. 두 hook은 matcher가 서로 disjoint (Bash vs Write/Edit/MultiEdit) 이므로 stdout aggregation 충돌 없음 (devbrew P15 plugin coexistence).

---

## Task 0: V12 — matcher harness 지원 확인 (CRITICAL pre-flight)

**Why first:** spec V12 가 *AC3 구현 전 반드시* 라고 명시. Claude Code harness가 `hooks.json`의 `"matcher": "Write|Edit|MultiEdit"` regex alternation 표현을 실제 지원하는지 미검증. 미지원 시 fallback 전략 (3개 entry 분리 또는 matcher 없이 hook 내부 `tool_name` 분기) 으로 plan 갱신 필요.

**Files:**
- Probe only — no file creation in this task.

- [ ] **Step 1: 임시 probe hook 작성 (검증용, 본 구현엔 미포함)**

임시 디렉토리에 다음 두 파일 생성:

```bash
mkdir -p /tmp/devbrew-v12-probe/hooks
cat > /tmp/devbrew-v12-probe/hooks/probe.sh <<'EOF'
#!/bin/bash
# Simply log to stderr which tool fired the hook
echo "[v12-probe] tool_name=$(cat | python3 -c 'import json,sys; print(json.load(sys.stdin).get(\"tool_name\",\"\"))')" >&2
echo '{}'
EOF
chmod +x /tmp/devbrew-v12-probe/hooks/probe.sh

cat > /tmp/devbrew-v12-probe/hooks/hooks.json <<'EOF'
{
  "description": "v12 probe — verify Write|Edit|MultiEdit matcher",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [{"type": "command", "command": "bash /tmp/devbrew-v12-probe/hooks/probe.sh", "timeout": 5}]
      }
    ]
  }
}
EOF
```

- [ ] **Step 2: probe를 임시 plugin으로 enable + Claude Code 세션에서 Write/Edit/MultiEdit 도구 각 호출**

검증 절차 (사용자 또는 separate Claude Code 세션 필요 — agent가 직접 진행 불가):
1. probe를 `~/.claude/plugins/` 하위에 임시 plugin으로 wire (또는 settings.json `enabledPlugins`에 등록).
2. Write 한 번 — 임의 파일 생성 → stderr에 `[v12-probe] tool_name=Write` 보이면 OK.
3. Edit 한 번 → `[v12-probe] tool_name=Edit` 보이면 OK.
4. MultiEdit 한 번 → `[v12-probe] tool_name=MultiEdit` 보이면 OK.

- [ ] **Step 3: 결과 분기**

- **모든 3개 발화**: matcher regex alternation 지원 확인 → Task 8의 hooks.json entry를 spec AC3 그대로 작성. **Plan unchanged**.
- **일부만 발화**: regex alternation 미지원 → 다음 중 fallback 선택:
  - (a) `hooks.json`에 3개 entry 분리 (matcher: `Write`, matcher: `Edit`, matcher: `MultiEdit` 각각).
  - (b) `hooks.json` matcher 없이 모든 PostToolUse 받고, `docs-lint.py` 내부에서 `tool_name in ("Write", "Edit", "MultiEdit")` 분기 (기존 `post-tool-use.py:171-173` 패턴 미러).
  - **권고**: (b) — entry 1개로 단순, kill switch 처리 동일, 다른 hook과 coexistence 동일.
- **결과 기록**: 본 plan 파일 § *"V12 probe result"* 섹션 (아래 Step 4) 에 결과 기록.

- [ ] **Step 4: V12 결과 기록 + probe cleanup**

이 plan 파일 맨 아래 § "V12 Probe Result" 섹션에 결과 한 줄 추가 (구현자가 채움):

```
## V12 Probe Result

- Date: YYYY-MM-DD
- Harness: Claude Code <version>
- Verdict: [SUPPORTED | UNSUPPORTED — fallback (b) applied]
- Evidence: <stderr 출력 캡처 또는 fallback 코드 인용>
```

probe 디렉토리 정리: `rm -rf /tmp/devbrew-v12-probe`.

- [ ] **Step 5: Commit (probe 결과 plan 갱신)**

```bash
git add docs/superpowers/plans/2026-05-17-project-init-docs-lint-hook.md
git commit -m "chore(plan): record V12 matcher harness probe result"
```

---

## Task 1: Hook skeleton — kill switch, file filter, worktree skip

**Files:**
- Create: `plugins/project-init/hooks/docs-lint.py`
- Create: `plugins/project-init/hooks/tests/__init__.py` (empty)
- Create: `plugins/project-init/hooks/tests/test_docs_lint.py`

**Covers AC1, AC2, AC4, AC5, AC6.**

- [ ] **Step 1: 빈 test 파일에 skeleton tests 작성 (실패 예상)**

`plugins/project-init/hooks/tests/test_docs_lint.py`:

```python
"""Unit tests for plugins/project-init/hooks/docs-lint.py."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parent.parent / "docs-lint.py"


def run_hook(payload: dict, env_override: dict | None = None, cwd: str | None = None) -> tuple[str, int]:
    """Invoke the hook with given JSON payload; return (stdout, returncode)."""
    env = os.environ.copy()
    # Strip any inherited devbrew env vars first to make tests deterministic
    for k in list(env):
        if k.startswith("DEVBREW_"):
            del env[k]
    if env_override:
        env.update(env_override)
    if cwd:
        env["CLAUDE_PROJECT_DIR"] = cwd
    cp = subprocess.run(
        [sys.executable, str(HOOK)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        env=env,
        timeout=10,
    )
    return cp.stdout, cp.returncode


class TestSkeleton(unittest.TestCase):
    """AC1, AC2, AC4, AC5, AC6 — skeleton behavior."""

    def test_kill_switch_full_disable(self):
        """AC4: DEVBREW_DISABLE_PROJECT_INIT=1 → {} exit 0."""
        out, rc = run_hook(
            {"tool_name": "Write", "tool_input": {"file_path": "/anything/CLAUDE.md"}},
            env_override={"DEVBREW_DISABLE_PROJECT_INIT": "1"},
        )
        self.assertEqual(out.strip(), "{}")
        self.assertEqual(rc, 0)

    def test_kill_switch_hook_opt_out(self):
        """AC4: DEVBREW_SKIP_HOOKS containing project-init:docs-lint → {}."""
        out, rc = run_hook(
            {"tool_name": "Write", "tool_input": {"file_path": "/anything/CLAUDE.md"}},
            env_override={"DEVBREW_SKIP_HOOKS": "other:foo,project-init:docs-lint,bar:baz"},
        )
        self.assertEqual(out.strip(), "{}")
        self.assertEqual(rc, 0)

    def test_non_target_tool_no_op(self):
        """AC2: Bash tool input → {} (only Write/Edit/MultiEdit checked)."""
        with tempfile.TemporaryDirectory() as td:
            out, rc = run_hook(
                {"tool_name": "Bash", "tool_input": {"command": "ls"}},
                cwd=td,
            )
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)

    def test_non_target_file_no_op(self):
        """AC2: file_path that isn't one of the 4 names → {}."""
        with tempfile.TemporaryDirectory() as td:
            other = Path(td) / "README.md"
            other.write_text("# readme\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(other)}},
                cwd=td,
            )
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)

    def test_invalid_json_graceful(self):
        """AC6: invalid stdin JSON → {} exit 0 (graceful)."""
        # send raw garbage instead of structured payload
        env = {k: v for k, v in os.environ.items() if not k.startswith("DEVBREW_")}
        cp = subprocess.run(
            [sys.executable, str(HOOK)],
            input="this is not json",
            capture_output=True,
            text=True,
            env=env,
            timeout=10,
        )
        self.assertEqual(cp.stdout.strip(), "{}")
        self.assertEqual(cp.returncode, 0)

    def test_worktree_path_skip(self):
        """AC5: file_path inside .git/worktrees/** → skip ({})."""
        with tempfile.TemporaryDirectory() as td:
            wt_dir = Path(td) / ".git" / "worktrees" / "wt1"
            wt_dir.mkdir(parents=True)
            wt_file = wt_dir / "CLAUDE.md"
            wt_file.write_text("# stub\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(wt_file)}},
                cwd=td,
            )
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)

    def test_path_traversal_outside_project_dir(self):
        """C4: file_path escaping CLAUDE_PROJECT_DIR → skip."""
        with tempfile.TemporaryDirectory() as td_outer:
            with tempfile.TemporaryDirectory() as td_project:
                outside = Path(td_outer) / "CLAUDE.md"
                outside.write_text("# stub\n")
                out, rc = run_hook(
                    {"tool_name": "Write", "tool_input": {"file_path": str(outside)}},
                    cwd=td_project,
                )
                self.assertEqual(out.strip(), "{}")
                self.assertEqual(rc, 0)

    def test_target_file_passes_through_to_rules(self):
        """AC1: legitimate CLAUDE.md in project dir → reaches rule layer (no rules triggered for valid empty file → {})."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "CLAUDE.md"
            target.write_text("# Title\n\nShort content.\n")  # passes all 5 rules
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 테스트 실행해 모두 실패 확인**

Run: `cd plugins/project-init && python3 -m unittest hooks.tests.test_docs_lint -v`
Expected: FAIL — hook 파일 부재 (`docs-lint.py` not found 또는 import error).

- [ ] **Step 3: `docs-lint.py` skeleton 구현**

`plugins/project-init/hooks/docs-lint.py`:

```python
#!/usr/bin/env python3
"""PostToolUse hook for project-init plugin — agent-readable docs convention validator.

Validates root context files (CLAUDE.md, AGENTS.md, .claude/CLAUDE.md, .claude/AGENTS.md)
against 5 deterministic rules: R1 size, R2 TOC, R5 fenced code language,
R6 internal links resolve, R-pointer CLAUDE/AGENTS drift.

Non-blocking advisory pattern: outputs systemMessage on violation, {} on pass.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path
from typing import Optional


# --- Filter constants ---

TARGET_BASENAMES = {"CLAUDE.md", "AGENTS.md"}
TARGET_RELPATHS = {"CLAUDE.md", "AGENTS.md", ".claude/CLAUDE.md", ".claude/AGENTS.md"}
TARGET_TOOLS = {"Write", "Edit", "MultiEdit"}
WORKTREE_MARKER = os.sep + ".git" + os.sep + "worktrees" + os.sep


# --- Helpers ---


def kill_switch_active() -> bool:
    """Return True if devbrew kill switch env vars opt this hook out.

    Mirrors plugins/project-init/hooks/post-tool-use.py:149-154 pattern,
    differing only in the hook token string.
    """
    if os.environ.get("DEVBREW_DISABLE_PROJECT_INIT") == "1":
        return True
    skip_list = [s.strip() for s in os.environ.get("DEVBREW_SKIP_HOOKS", "").split(",")]
    return "project-init:docs-lint" in skip_list


def resolve_target_path(file_path: str, project_dir: str) -> Optional[Path]:
    """Return absolute Path if file_path is one of the 4 target root context files
    relative to project_dir, else None. Skips worktree internal metadata paths."""
    if not file_path:
        return None
    abs_path = Path(file_path).resolve()
    if WORKTREE_MARKER in str(abs_path):
        return None
    try:
        rel = abs_path.relative_to(Path(project_dir).resolve())
    except ValueError:
        # File is outside CLAUDE_PROJECT_DIR
        return None
    if rel.as_posix() not in TARGET_RELPATHS:
        return None
    return abs_path


def emit(systemMessage: Optional[str] = None) -> None:
    """Print hook JSON output and exit 0."""
    if systemMessage:
        print(json.dumps({"systemMessage": systemMessage}), flush=True)
    else:
        print(json.dumps({}), flush=True)


def main() -> int:
    if kill_switch_active():
        emit()
        return 0
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        print("[project-init:docs-lint] invalid JSON on stdin — skipping", file=sys.stderr)
        emit()
        return 0
    tool_name = payload.get("tool_name", "")
    if tool_name not in TARGET_TOOLS:
        emit()
        return 0
    file_path = payload.get("tool_input", {}).get("file_path", "")
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
    target = resolve_target_path(file_path, project_dir)
    if target is None:
        emit()
        return 0
    # Rules will be wired in subsequent tasks. For skeleton, no rules → pass.
    emit()
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: 테스트 재실행 — 모두 통과 확인**

Run: `cd plugins/project-init && python3 -m unittest hooks.tests.test_docs_lint -v`
Expected: PASS — 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add plugins/project-init/hooks/docs-lint.py plugins/project-init/hooks/tests/
git commit -m "feat(project-init): docs-lint hook skeleton (kill switch + file filter)"
```

---

## Task 2: Rule R1 — size warning

**Files:**
- Modify: `plugins/project-init/hooks/docs-lint.py` (add `check_r1_size`)
- Modify: `plugins/project-init/hooks/tests/test_docs_lint.py` (add test class)

**Covers AC7, AC8.**

- [ ] **Step 1: Failing tests for R1 추가**

`plugins/project-init/hooks/tests/test_docs_lint.py` 끝에 append:

```python
class TestR1Size(unittest.TestCase):
    """R1 — file size threshold (warn at >200, strong warn at >300)."""

    def _write_lines(self, td: str, basename: str, n: int) -> Path:
        p = Path(td) / basename
        p.write_text("\n".join(f"line {i}" for i in range(n)) + "\n")
        return p

    def test_exactly_200_lines_passes(self):
        """AC7: 200 lines exact → no R1 warning."""
        with tempfile.TemporaryDirectory() as td:
            target = self._write_lines(td, "CLAUDE.md", 200)
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("Anthropic recommends", out)
            self.assertEqual(rc, 0)

    def test_201_lines_warns(self):
        """AC7: 201 lines → R1 base warning (no STRONG suffix yet)."""
        with tempfile.TemporaryDirectory() as td:
            target = self._write_lines(td, "AGENTS.md", 201)
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("Anthropic recommends ≤200", out)
            self.assertIn("201 lines", out)
            self.assertNotIn("STRONG", out)
            self.assertEqual(rc, 0)

    def test_300_lines_passes_strong_threshold(self):
        """AC8: 300 lines exact → only base warning (not STRONG yet, threshold is >300)."""
        with tempfile.TemporaryDirectory() as td:
            target = self._write_lines(td, "AGENTS.md", 300)
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("Anthropic recommends ≤200", out)
            self.assertNotIn("STRONG", out)

    def test_301_lines_strong_warns(self):
        """AC8: 301 lines → R1 base + STRONG suffix in single message."""
        with tempfile.TemporaryDirectory() as td:
            target = self._write_lines(td, "AGENTS.md", 301)
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("Anthropic recommends ≤200", out)
            self.assertIn("STRONG", out)
            self.assertIn("301 lines", out)
            # AC8: single combined string, not duplicate emit
            self.assertEqual(out.count("Anthropic recommends ≤200"), 1)
```

- [ ] **Step 2: 테스트 실행 — 새 4개 fail 확인**

Run: `cd plugins/project-init && python3 -m unittest hooks.tests.test_docs_lint.TestR1Size -v`
Expected: 4 FAIL (skeleton doesn't emit R1 messages).

- [ ] **Step 3: `docs-lint.py`에 R1 구현**

`docs-lint.py`의 `main()` 위, `# --- Helpers ---` 아래에 추가:

```python
# --- Rules ---


def check_r1_size(target: Path, rel_display: str) -> Optional[str]:
    """AC7/AC8: size warning if >200 lines, STRONG suffix if >300."""
    try:
        content = target.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None
    lines = content.count("\n") + (0 if content.endswith("\n") or not content else 1)
    if lines <= 200:
        return None
    base = (
        f"project-init: {rel_display} is {lines} lines. "
        f"Anthropic recommends ≤200. Move detailed content to docs/** and link from here."
    )
    if lines > 300:
        return base + " (STRONG: >300 lines means agent will likely truncate)"
    return base
```

`main()`에서 `target is None` 분기 이후, `emit()` 직전을 다음으로 교체:

```python
    # Compute display path (relative to project_dir for readability)
    try:
        rel_display = target.relative_to(Path(project_dir).resolve()).as_posix()
    except ValueError:
        rel_display = str(target)
    messages: list[str] = []
    msg_r1 = check_r1_size(target, rel_display)
    if msg_r1:
        messages.append(msg_r1)
    # More rules will be added in subsequent tasks.
    if messages:
        emit("\n\n".join(messages))
    else:
        emit()
    return 0
```

- [ ] **Step 4: 테스트 재실행 — 통과 확인**

Run: `cd plugins/project-init && python3 -m unittest hooks.tests.test_docs_lint -v`
Expected: PASS — all 12 tests pass (8 skeleton + 4 R1).

- [ ] **Step 5: Commit**

```bash
git add plugins/project-init/hooks/docs-lint.py plugins/project-init/hooks/tests/test_docs_lint.py
git commit -m "feat(project-init): docs-lint R1 size warning (>200, STRONG >300)"
```

---

## Task 3: Rule R2 — TOC required if >300 lines

**Files:**
- Modify: `plugins/project-init/hooks/docs-lint.py` (add `check_r2_toc`)
- Modify: `plugins/project-init/hooks/tests/test_docs_lint.py`

**Covers AC9, AC10.**

- [ ] **Step 1: Failing tests for R2 추가**

`test_docs_lint.py` 끝에 append:

```python
class TestR2Toc(unittest.TestCase):
    """R2 — TOC required if >300 lines."""

    def test_350_lines_no_toc_warns(self):
        """AC9: 350 lines + no TOC → R2 warning (and R1 STRONG)."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text("# Title\n\n" + "\n".join(f"line {i}" for i in range(350)) + "\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("exceeds 300 lines without a TOC", out)
            # AC19: both R1 STRONG and R2 fire, joined with \n\n
            self.assertIn("STRONG", out)

    def test_350_lines_with_korean_toc_passes(self):
        """AC9: 350 lines + ## 목차 → R2 passes (R1 STRONG still fires)."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n## 목차\n\n- intro\n\n"
                + "\n".join(f"line {i}" for i in range(350)) + "\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("without a TOC", out)
            self.assertIn("STRONG", out)  # R1 still fires

    def test_350_lines_with_english_toc_passes(self):
        """AC9: 350 lines + ## Table of Contents → R2 passes."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n## Table of Contents\n\n- intro\n\n"
                + "\n".join(f"line {i}" for i in range(350)) + "\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("without a TOC", out)

    def test_300_lines_or_less_no_r2(self):
        """AC9: ≤300 lines → R2 never fires regardless of TOC presence."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text("\n".join(f"line {i}" for i in range(250)) + "\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("without a TOC", out)

    def test_toc_at_end_of_file_still_passes(self):
        """AC10: TOC location is free — bottom of file also OK."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n"
                + "\n".join(f"line {i}" for i in range(340)) + "\n"
                + "\n## 목차\n\n- intro\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("without a TOC", out)
```

- [ ] **Step 2: 테스트 실행 — 새 5개 fail 확인 (positive cases도 R2 부재 때문에 통과는 하지만 R2 검사 미구현)**

Run: `cd plugins/project-init && python3 -m unittest hooks.tests.test_docs_lint.TestR2Toc -v`
Expected: `test_350_lines_no_toc_warns` FAIL (no R2 message). 나머지는 우연히 PASS — 진짜 구현 후 다시 확인.

- [ ] **Step 3: `docs-lint.py`에 R2 구현**

`check_r1_size` 아래에 추가:

```python
TOC_RE = re.compile(r"^##\s+(목차|Table of Contents|Contents)\s*$", re.MULTILINE)


def check_r2_toc(target: Path, rel_display: str) -> Optional[str]:
    """AC9: TOC required if >300 lines."""
    try:
        content = target.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None
    lines = content.count("\n") + (0 if content.endswith("\n") or not content else 1)
    if lines <= 300:
        return None
    if TOC_RE.search(content):
        return None
    return (
        f"project-init: {rel_display} exceeds 300 lines without a TOC section. "
        f'Add "## 목차" or "## Table of Contents" near the top.'
    )
```

`main()`의 messages 합성 구간에 R2 추가:

```python
    msg_r2 = check_r2_toc(target, rel_display)
    if msg_r2:
        messages.append(msg_r2)
```

- [ ] **Step 4: 테스트 재실행 — 모두 통과**

Run: `cd plugins/project-init && python3 -m unittest hooks.tests.test_docs_lint -v`
Expected: PASS — 17 tests pass (12 + 5 R2).

- [ ] **Step 5: Commit**

```bash
git add plugins/project-init/hooks/docs-lint.py plugins/project-init/hooks/tests/test_docs_lint.py
git commit -m "feat(project-init): docs-lint R2 TOC required if >300 lines"
```

---

## Task 4: Rule R5 — fenced code language

**Files:**
- Modify: `plugins/project-init/hooks/docs-lint.py` (add `check_r5_fences`)
- Modify: `plugins/project-init/hooks/tests/test_docs_lint.py`

**Covers AC11, AC12.**

- [ ] **Step 1: Failing tests for R5 추가**

```python
class TestR5Fences(unittest.TestCase):
    """R5 — fenced code blocks must declare a language (3-backtick only)."""

    def test_bare_fence_warns(self):
        """AC11: opening fence without language → warn with line number."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n"
                "```\n"
                "some code\n"
                "```\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("fenced code block", out)
            self.assertIn("line L3", out)

    def test_languaged_fence_passes(self):
        """AC11: opening fence with bash → pass."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n"
                "```bash\n"
                "ls\n"
                "```\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("fenced code block", out)

    def test_indented_code_block_ignored(self):
        """AC12: 4+ space indent → markdown indented code, R5 skips."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n"
                "    ```\n"  # 4 spaces — indented code, not fence
                "    code\n"
                "    ```\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("fenced code block", out)

    def test_close_fence_not_flagged(self):
        """AC11 stateful: bare closing fence after opening fence is OK."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n"
                "```python\n"  # open with lang
                "x = 1\n"
                "```\n"        # bare close — must NOT trigger
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("fenced code block", out)

    def test_multi_violation_count_and_list(self):
        """AC11 message format: count + list pattern."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            # 3 bare opens (with proper closes)
            content = ""
            for _ in range(3):
                content += "```\nstuff\n```\n\n"
            target.write_text("# Title\n\n" + content)
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("3 fenced code blocks", out)
            self.assertIn("at lines [", out)

    def test_4_backtick_fence_ignored(self):
        """AC11 scope-out: 4+ backtick fences not checked."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n"
                "````\n"  # 4 backticks, no language
                "code\n"
                "````\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("fenced code block", out)
```

- [ ] **Step 2: 테스트 실행 — 적어도 2개 fail 확인 (bare fence + multi-violation)**

Run: `cd plugins/project-init && python3 -m unittest hooks.tests.test_docs_lint.TestR5Fences -v`
Expected: 2 FAIL (no R5 message yet for bare fence + multi-violation count).

- [ ] **Step 3: `docs-lint.py`에 R5 구현**

`check_r2_toc` 아래에 추가:

```python
FENCE_RE = re.compile(r"^ {0,3}`{3}(\S*)\s*$")


def check_r5_fences(target: Path, rel_display: str) -> Optional[str]:
    """AC11/AC12: bare 3-backtick opening fence without language tag."""
    try:
        content = target.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None
    violations: list[int] = []
    in_fence = False
    for lineno, line in enumerate(content.splitlines(), start=1):
        m = FENCE_RE.match(line)
        if not m:
            continue
        if not in_fence:
            # Opening fence
            lang = m.group(1)
            if not lang:
                violations.append(lineno)
        # Toggle either way (closing fence is always bare and intentional)
        in_fence = not in_fence
    if not violations:
        return None
    if len(violations) == 1:
        return (
            f"project-init: {rel_display} has 1 fenced code block without a language tag "
            f"at line L{violations[0]}. Add the language (e.g. \"```bash\")."
        )
    shown = violations[:5]
    suffix = ""
    if len(violations) > 5:
        suffix = f" ... and {len(violations) - 5} more"
    line_list = ", ".join(f"L{n}" for n in shown) + suffix
    return (
        f"project-init: {rel_display} has {len(violations)} fenced code blocks "
        f"without language tags at lines [{line_list}]. "
        f"Add the language (e.g. \"```bash\")."
    )
```

`main()` messages 합성에 R5 추가:

```python
    msg_r5 = check_r5_fences(target, rel_display)
    if msg_r5:
        messages.append(msg_r5)
```

- [ ] **Step 4: 테스트 재실행 — 모두 통과**

Run: `cd plugins/project-init && python3 -m unittest hooks.tests.test_docs_lint -v`
Expected: PASS — 23 tests pass (17 + 6 R5).

- [ ] **Step 5: Commit**

```bash
git add plugins/project-init/hooks/docs-lint.py plugins/project-init/hooks/tests/test_docs_lint.py
git commit -m "feat(project-init): docs-lint R5 fenced code language (stateful walk, 3-backtick)"
```

---

## Task 5: Rule R6 — internal links resolve

**Files:**
- Modify: `plugins/project-init/hooks/docs-lint.py` (add `check_r6_links`)
- Modify: `plugins/project-init/hooks/tests/test_docs_lint.py`

**Covers AC13, AC14, AC15.**

- [ ] **Step 1: Failing tests for R6 추가**

```python
class TestR6Links(unittest.TestCase):
    """R6 — internal markdown links must resolve."""

    def test_resolved_link_passes(self):
        """AC13: link to existing sibling file → pass."""
        with tempfile.TemporaryDirectory() as td:
            sibling = Path(td) / "docs.md"
            sibling.write_text("ok")
            target = Path(td) / "AGENTS.md"
            target.write_text("# Title\n\nSee [docs](docs.md).\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("unresolved internal link", out)

    def test_unresolved_link_warns(self):
        """AC13/AC14: link to non-existent file → warn with path listed."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text("# Title\n\nSee [missing](nope.md).\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("1 unresolved internal link", out)
            self.assertIn("nope.md", out)

    def test_url_scheme_skipped(self):
        """AC13: URL schemes (http, https, mailto, custom) → skip."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n"
                "- [external](https://example.com)\n"
                "- [contact](mailto:x@y.z)\n"
                "- [phone](tel:1234)\n"
                "- [custom](weird+scheme:foo)\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("unresolved internal link", out)

    def test_anchor_only_link_skipped(self):
        """AC13: #anchor-only link → skip (same-file anchor not checked)."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text("# Title\n\n[jump](#section)\n## section\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("unresolved internal link", out)

    def test_fragment_stripped_before_check(self):
        """AC13: link with #fragment — path checked, fragment stripped."""
        with tempfile.TemporaryDirectory() as td:
            sibling = Path(td) / "docs.md"
            sibling.write_text("ok")
            target = Path(td) / "AGENTS.md"
            target.write_text("[see](docs.md#header)\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("unresolved internal link", out)

    def test_escape_outside_project_dir_skipped(self):
        """AC15: link target escaping project_dir → treated as external, skipped."""
        with tempfile.TemporaryDirectory() as td_outer:
            with tempfile.TemporaryDirectory() as td_project:
                outside = Path(td_outer) / "other.md"
                outside.write_text("ok")
                target = Path(td_project) / "AGENTS.md"
                # relative path going up and out
                rel = os.path.relpath(outside, td_project)
                target.write_text(f"[outside]({rel})\n")
                out, rc = run_hook(
                    {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                    cwd=td_project,
                )
                self.assertNotIn("unresolved internal link", out)

    def test_multi_unresolved_truncates_at_5(self):
        """AC14: max 5 listed, '... and M more' suffix beyond."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text("\n".join(f"[bad{i}](no{i}.md)" for i in range(8)) + "\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("8 unresolved internal link", out)
            self.assertIn("and 3 more", out)
```

- [ ] **Step 2: 테스트 실행 — 최소 3개 fail 확인**

Run: `cd plugins/project-init && python3 -m unittest hooks.tests.test_docs_lint.TestR6Links -v`
Expected: ≥3 FAIL (unresolved/multi/truncation).

- [ ] **Step 3: `docs-lint.py`에 R6 구현**

`check_r5_fences` 아래 추가:

```python
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
URL_SCHEME_RE = re.compile(r"^[a-z][a-z0-9+.-]*:")


def check_r6_links(target: Path, rel_display: str, project_dir: Path) -> Optional[str]:
    """AC13/AC14/AC15: internal markdown links must resolve."""
    try:
        content = target.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None
    unresolved: list[str] = []
    base_dir = target.parent
    for m in LINK_RE.finditer(content):
        raw_target = m.group(2).strip()
        if not raw_target:
            continue
        if URL_SCHEME_RE.match(raw_target):
            continue
        if raw_target.startswith("#"):
            continue
        # Strip fragment
        path_part = raw_target.split("#", 1)[0]
        if not path_part:
            continue
        resolved = (base_dir / path_part).resolve()
        # AC15: escape outside project_dir → treat as external
        try:
            resolved.relative_to(project_dir)
        except ValueError:
            continue
        if not resolved.exists():
            unresolved.append(raw_target)
    if not unresolved:
        return None
    shown = unresolved[:5]
    suffix = ""
    if len(unresolved) > 5:
        suffix = f" ... and {len(unresolved) - 5} more"
    list_str = ", ".join(shown) + suffix
    return (
        f"project-init: {rel_display} has {len(unresolved)} unresolved internal link(s): "
        f"[{list_str}]"
    )
```

`main()`에서 `project_dir` 사용 부분 갱신 + R6 추가:

```python
    project_dir_path = Path(project_dir).resolve()
    # ... rel_display 계산 ...
    msg_r6 = check_r6_links(target, rel_display, project_dir_path)
    if msg_r6:
        messages.append(msg_r6)
```

- [ ] **Step 4: 테스트 재실행 — 통과 확인**

Run: `cd plugins/project-init && python3 -m unittest hooks.tests.test_docs_lint -v`
Expected: PASS — 30 tests pass (23 + 7 R6).

- [ ] **Step 5: Commit**

```bash
git add plugins/project-init/hooks/docs-lint.py plugins/project-init/hooks/tests/test_docs_lint.py
git commit -m "feat(project-init): docs-lint R6 internal links resolve"
```

---

## Task 6: Rule R-pointer — CLAUDE/AGENTS drift

**Files:**
- Modify: `plugins/project-init/hooks/docs-lint.py` (add `check_r_pointer` + normalization helper)
- Modify: `plugins/project-init/hooks/tests/test_docs_lint.py`

**Covers AC16, AC17, AC18, AC18.5.**

- [ ] **Step 1: Failing tests for R-pointer 추가**

```python
class TestRPointer(unittest.TestCase):
    """R-pointer — CLAUDE.md ↔ AGENTS.md drift detection (bidirectional trigger)."""

    def _write_pair(self, td: str, agents_content: str, claude_content: str, sub: str = "") -> tuple[Path, Path]:
        base = Path(td) / sub if sub else Path(td)
        base.mkdir(parents=True, exist_ok=True)
        a = base / "AGENTS.md"
        c = base / "CLAUDE.md"
        a.write_text(agents_content)
        c.write_text(claude_content)
        return a, c

    def test_only_one_file_no_check(self):
        """AC16: drift requires BOTH files; only AGENTS.md present → no R-pointer."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text("# title\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("drift risk", out)

    def test_thin_pointer_passes(self):
        """AC16 cond 2: CLAUDE.md is '@AGENTS.md' → pass."""
        with tempfile.TemporaryDirectory() as td:
            a, c = self._write_pair(td, "# canonical\n", "@AGENTS.md\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(c)}},
                cwd=td,
            )
            self.assertNotIn("drift risk", out)

    def test_thin_pointer_with_frontmatter_passes(self):
        """AC16 normalization: frontmatter stripped before @AGENTS.md check."""
        with tempfile.TemporaryDirectory() as td:
            a, c = self._write_pair(
                td,
                "# canonical\n",
                "---\ntitle: foo\n---\n@AGENTS.md\n",
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(c)}},
                cwd=td,
            )
            self.assertNotIn("drift risk", out)

    def test_frontmatter_no_trailing_newline_passes(self):
        """AC16 trailing newline regex: closing --- without \\n still strips."""
        with tempfile.TemporaryDirectory() as td:
            base = Path(td)
            (base / "AGENTS.md").write_text("# canonical\n")
            (base / "CLAUDE.md").write_text("---\nfoo: bar\n---\n@AGENTS.md")  # no trailing \n
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(base / "CLAUDE.md")}},
                cwd=td,
            )
            self.assertNotIn("drift risk", out)

    def test_html_comments_stripped(self):
        """AC16: HTML comments removed before comparison."""
        with tempfile.TemporaryDirectory() as td:
            a, c = self._write_pair(
                td,
                "# canonical\n",
                "<!-- maintainer note -->\n@AGENTS.md\n",
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(c)}},
                cwd=td,
            )
            self.assertNotIn("drift risk", out)

    def test_divergent_content_warns(self):
        """AC17: both exist + CLAUDE.md has divergent content → drift warning."""
        with tempfile.TemporaryDirectory() as td:
            a, c = self._write_pair(
                td,
                "# canonical AGENTS\n",
                "# completely different CLAUDE\n\nLots of content here.\n",
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(c)}},
                cwd=td,
            )
            self.assertIn("drift risk", out)
            self.assertIn("ln -sf AGENTS.md CLAUDE.md", out)

    def test_symlink_passes(self):
        """AC16 cond 1: CLAUDE.md is symlink to AGENTS.md → pass."""
        with tempfile.TemporaryDirectory() as td:
            a = Path(td) / "AGENTS.md"
            a.write_text("# canonical\n")
            c = Path(td) / "CLAUDE.md"
            os.symlink("AGENTS.md", c)
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(c)}},
                cwd=td,
            )
            self.assertNotIn("drift risk", out)

    def test_bidirectional_trigger_from_agents_edit(self):
        """AC18.5: editing AGENTS.md also triggers R-pointer if pair CLAUDE.md is divergent."""
        with tempfile.TemporaryDirectory() as td:
            a, c = self._write_pair(
                td,
                "# canonical AGENTS\n",
                "# divergent CLAUDE\n\nstuff\n",
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(a)}},  # AGENTS edited
                cwd=td,
            )
            self.assertIn("drift risk", out)

    def test_dot_claude_dir_independent(self):
        """AC18: .claude/CLAUDE.md ↔ .claude/AGENTS.md checked independently."""
        with tempfile.TemporaryDirectory() as td:
            dot = Path(td) / ".claude"
            a, c = self._write_pair(td, "# root agents\n", "@AGENTS.md\n")  # root pair OK
            dot.mkdir()
            (dot / "AGENTS.md").write_text("# inner\n")
            (dot / "CLAUDE.md").write_text("# divergent inner\n\ndifferent content\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(dot / "CLAUDE.md")}},
                cwd=td,
            )
            self.assertIn("drift risk", out)
            # Root pair is fine, not flagged
            self.assertNotIn("Make CLAUDE.md contain", out.split("drift risk")[0])
```

- [ ] **Step 2: 테스트 실행 — 최소 4개 fail**

Run: `cd plugins/project-init && python3 -m unittest hooks.tests.test_docs_lint.TestRPointer -v`
Expected: ≥4 FAIL (no R-pointer implementation yet).

- [ ] **Step 3: `docs-lint.py`에 R-pointer 구현**

`check_r6_links` 아래 추가:

```python
FRONTMATTER_RE = re.compile(r"^---\n.*?\n---(?:\n|$)", re.DOTALL)
HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)


def _normalize_pointer_content(content: str) -> str:
    """AC16 normalization: (1) strip frontmatter (2) strip HTML comments (3) str.strip().
    Order matters — see spec AC16 rationale; do not reorder."""
    # 1. Strip frontmatter
    no_fm = FRONTMATTER_RE.sub("", content, count=1)
    # 2. Strip HTML comments
    no_comments = HTML_COMMENT_RE.sub("", no_fm)
    # 3. Whitespace
    return no_comments.strip()


def _is_proper_pointer(claude_path: Path, agents_basename: str = "AGENTS.md") -> bool:
    """Return True if claude_path satisfies AC16 pass conditions."""
    # Cond 1: symlink to AGENTS.md
    if claude_path.is_symlink():
        link = os.readlink(claude_path)
        return link in (agents_basename, f"./{agents_basename}")
    # Cond 2: normalized content == "@AGENTS.md"
    try:
        content = claude_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return False
    return _normalize_pointer_content(content) == f"@{agents_basename}"


def check_r_pointer(target: Path, project_dir: Path) -> Optional[str]:
    """AC16-AC18.5: bidirectional CLAUDE/AGENTS drift detection.
    Triggered when editing any of the 4 target files; checks the directory's pair."""
    # Determine pair directory and check both pairs (root + .claude/) independently
    target_dir = target.parent
    claude_path = target_dir / "CLAUDE.md"
    agents_path = target_dir / "AGENTS.md"
    # Skip pair if either path escapes worktree or is in .git/worktrees/**
    for p in (claude_path, agents_path):
        if WORKTREE_MARKER in str(p.resolve()):
            return None
        try:
            p.resolve().relative_to(project_dir)
        except ValueError:
            return None
    if not (claude_path.exists() and agents_path.exists()):
        return None  # drift only meaningful when both exist
    if _is_proper_pointer(claude_path):
        return None
    rel = claude_path.relative_to(project_dir).as_posix()
    return (
        f"project-init: Both {rel} and "
        f"{agents_path.relative_to(project_dir).as_posix()} exist with divergent content "
        f"(drift risk). Make CLAUDE.md contain just \"@AGENTS.md\" or symlink it: "
        f"`ln -sf AGENTS.md CLAUDE.md`"
    )
```

`main()` messages 합성에 추가:

```python
    msg_rp = check_r_pointer(target, project_dir_path)
    if msg_rp:
        messages.append(msg_rp)
```

- [ ] **Step 4: 테스트 재실행 — 모두 통과**

Run: `cd plugins/project-init && python3 -m unittest hooks.tests.test_docs_lint -v`
Expected: PASS — 39 tests (30 + 9 R-pointer).

- [ ] **Step 5: Commit**

```bash
git add plugins/project-init/hooks/docs-lint.py plugins/project-init/hooks/tests/test_docs_lint.py
git commit -m "feat(project-init): docs-lint R-pointer (bidirectional CLAUDE/AGENTS drift)"
```

---

## Task 7: Fixture 디렉토리 layout + V2 smoke test

**Files:**
- Create: 10개 fixture 디렉토리 + 그 안의 파일들 (spec §7 fixture layout 그대로)
- Create: `plugins/project-init/hooks/tests/smoke.sh` (V2 자동화 스크립트)

**Covers fixture spec (AC30) + V2.**

- [ ] **Step 1: 10개 fixture 디렉토리 작성**

```bash
FIX=plugins/project-init/hooks/tests/fixtures
mkdir -p $FIX/{valid,oversized,strong_oversized,missing_toc,bare_fence,broken_link,drifted,proper_pointer,dangling_pointer}

# valid: happy path
cat > $FIX/valid/AGENTS.md <<'EOF'
# Valid Test Fixture

Short happy path — passes all 5 rules.

## Section

Some content with a `bash` fence below:

```bash
echo hello
```

Done.
EOF
cat > $FIX/valid/CLAUDE.md <<'EOF'
@AGENTS.md
EOF

# oversized: 201 lines
python3 -c "
with open('$FIX/oversized/AGENTS.md', 'w') as f:
    f.write('# Oversized fixture\n')
    for i in range(200):
        f.write(f'line {i}\n')
"

# strong_oversized: 301 lines
python3 -c "
with open('$FIX/strong_oversized/AGENTS.md', 'w') as f:
    f.write('# Strong oversized fixture\n')
    for i in range(300):
        f.write(f'line {i}\n')
"

# missing_toc: 350 lines, no TOC
python3 -c "
with open('$FIX/missing_toc/AGENTS.md', 'w') as f:
    f.write('# Missing TOC fixture\n')
    for i in range(349):
        f.write(f'line {i}\n')
"

# bare_fence
cat > $FIX/bare_fence/AGENTS.md <<'EOF'
# Bare fence fixture

```
this fence has no language
```
EOF

# broken_link
cat > $FIX/broken_link/AGENTS.md <<'EOF'
# Broken link fixture

See [missing](does-not-exist.md).
EOF

# drifted (both files, CLAUDE.md not thin pointer)
cat > $FIX/drifted/AGENTS.md <<'EOF'
# Canonical AGENTS.md
EOF
cat > $FIX/drifted/CLAUDE.md <<'EOF'
# Divergent CLAUDE.md

Lots of different content here that doesn't match.
EOF

# proper_pointer (both files, CLAUDE.md is thin pointer)
cat > $FIX/proper_pointer/AGENTS.md <<'EOF'
# Canonical AGENTS.md
EOF
cat > $FIX/proper_pointer/CLAUDE.md <<'EOF'
@AGENTS.md
EOF

# dangling_pointer (CLAUDE.md only, no AGENTS.md — S2b sub-case fixture)
# NOTE for maintainers: AGENTS.md is intentionally absent. Do not add one
# or you destroy the S2b sub-case intent.
cat > $FIX/dangling_pointer/CLAUDE.md <<'EOF'
@AGENTS.md
EOF
```

- [ ] **Step 2: V2 smoke script 작성**

`plugins/project-init/hooks/tests/smoke.sh`:

```bash
#!/usr/bin/env bash
# V2 — Hook smoke test (deterministic, no human eyeballing).
# Runs the docs-lint hook against every fixture and asserts expected stdout pattern.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
FIX="$ROOT/plugins/project-init/hooks/tests/fixtures"
HOOK="$ROOT/plugins/project-init/hooks/docs-lint.py"

declare -A EXPECT=(
  [valid]="{}"
  [oversized]="systemMessage"
  [strong_oversized]="systemMessage"
  [missing_toc]="systemMessage"
  [bare_fence]="systemMessage"
  [broken_link]="systemMessage"
  [drifted]="systemMessage"
  [proper_pointer]="{}"
  [dangling_pointer]="{}"
)

fails=0
for d in "${!EXPECT[@]}"; do
  target="$FIX/$d/AGENTS.md"
  [ -f "$target" ] || target="$FIX/$d/CLAUDE.md"
  payload="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$target\"}}"
  out=$(CLAUDE_PROJECT_DIR="$FIX/$d" python3 "$HOOK" <<< "$payload")
  expected="${EXPECT[$d]}"
  if [ "$expected" = "{}" ]; then
    if [ "$out" != "{}" ]; then
      echo "FAIL: $d expected {} got: $out"
      fails=$((fails+1))
    fi
  else
    if ! echo "$out" | grep -q "$expected"; then
      echo "FAIL: $d expected '$expected' got: $out"
      fails=$((fails+1))
    fi
  fi
done

if [ $fails -gt 0 ]; then
  echo "V2 FAIL: $fails fixture(s) mismatched"
  exit 1
fi
echo "V2 PASS"
```

`chmod +x plugins/project-init/hooks/tests/smoke.sh`

- [ ] **Step 3: smoke 실행 — 모두 통과 확인**

Run: `bash plugins/project-init/hooks/tests/smoke.sh`
Expected: `V2 PASS`.

- [ ] **Step 4: Commit**

```bash
git add plugins/project-init/hooks/tests/fixtures/ plugins/project-init/hooks/tests/smoke.sh
git commit -m "test(project-init): docs-lint fixture suite + V2 smoke script"
```

---

## Task 8: `hooks.json` 두 번째 entry 등록

**Files:**
- Modify: `plugins/project-init/hooks/hooks.json`

**Covers AC3.**

**Pre-req:** Task 0 V12 결과에 따라 matcher 표현 결정.

- [ ] **Step 1: 현재 `hooks.json` 읽고 새 entry 추가**

`plugins/project-init/hooks/hooks.json`:

```json
{
  "description": "project-init - validates branch naming, commit messages, and agent-readable docs conventions",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/post-tool-use.py",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/docs-lint.py",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

**If V12 fallback (b) applied** (matcher regex 미지원): matcher 줄을 삭제하고 hook 내부에서 `tool_name in ("Write", "Edit", "MultiEdit")` 분기 — Task 1의 `docs-lint.py:main()`에 이미 그 분기가 있으므로 추가 코드 불필요. 단 `description` 갱신: `"... agent-readable docs conventions (all PostToolUse, filtered internally)"`.

- [ ] **Step 2: 통합 smoke — V2 재실행 + V3 kill switch + V4 회귀**

```bash
# V2
bash plugins/project-init/hooks/tests/smoke.sh

# V3 — full kill switch
out1=$(DEVBREW_DISABLE_PROJECT_INIT=1 python3 plugins/project-init/hooks/docs-lint.py \
  <<< '{"tool_name":"Write","tool_input":{"file_path":"plugins/project-init/hooks/tests/fixtures/oversized/AGENTS.md"}}')
[ "$out1" = "{}" ] && echo "V3a PASS" || { echo "V3a FAIL: $out1"; exit 1; }

# V3 — hook opt-out
out2=$(DEVBREW_SKIP_HOOKS=project-init:docs-lint python3 plugins/project-init/hooks/docs-lint.py \
  <<< '{"tool_name":"Write","tool_input":{"file_path":"plugins/project-init/hooks/tests/fixtures/oversized/AGENTS.md"}}')
[ "$out2" = "{}" ] && echo "V3b PASS" || { echo "V3b FAIL: $out2"; exit 1; }

# V4 — existing hook regression (branch validator)
out3=$(echo '{"tool_name":"Bash","tool_input":{"command":"git checkout -b feature/Foo_Bar"}}' \
  | CLAUDE_PROJECT_DIR=$(pwd) python3 plugins/project-init/hooks/post-tool-use.py)
echo "$out3" | grep -q "naming convention" && echo "V4 PASS" || { echo "V4 FAIL: $out3"; exit 1; }
```

Expected: All 4 PASS.

- [ ] **Step 3: Commit**

```bash
git add plugins/project-init/hooks/hooks.json
git commit -m "feat(project-init): register docs-lint hook in hooks.json (Write|Edit|MultiEdit matcher)"
```

---

## Task 9: Template rename + thin pointer template 신설

**Files:**
- Rename: `templates/{github-flow,git-flow,trunk-based}/claude-md-section.md` → `agents-md-section.md` (3건, git mv)
- Create: `plugins/project-init/templates/shared/claude-md-pointer.md`

**Covers AC24, AC25.**

- [ ] **Step 1: git mv 3건**

```bash
git mv plugins/project-init/templates/github-flow/claude-md-section.md \
       plugins/project-init/templates/github-flow/agents-md-section.md
git mv plugins/project-init/templates/git-flow/claude-md-section.md \
       plugins/project-init/templates/git-flow/agents-md-section.md
git mv plugins/project-init/templates/trunk-based/claude-md-section.md \
       plugins/project-init/templates/trunk-based/agents-md-section.md
```

- [ ] **Step 2: 신규 thin pointer template 작성**

`plugins/project-init/templates/shared/claude-md-pointer.md`:

```
@AGENTS.md
```

(파일 끝에 trailing newline 한 개)

- [ ] **Step 3: 변경 사항 확인**

Run: `git status && ls plugins/project-init/templates/shared/`
Expected: 3 renames staged + new pointer file.

- [ ] **Step 4: Commit**

```bash
git add plugins/project-init/templates/
git commit -m "refactor(project-init): rename claude-md-section.md → agents-md-section.md + add CLAUDE.md thin pointer template"
```

---

## Task 10: `/project-init` command — Step 4 전반 갱신 (AGENTS.md primary + thin pointer + 4-state matrix)

**Files:**
- Modify: `plugins/project-init/commands/project-init.md`

**Covers AC20, AC21, AC22, AC23.**

- [ ] **Step 1: Step 4 전체 교체 (Step 4a/4b/4c/4d)**

기존 Step 4 섹션을 다음으로 교체. 정확한 텍스트는 spec AC20-AC23을 implementation literal로 옮긴 것.

```markdown
### Step 4: 파일 생성

선택된 strategy와 답변을 바탕으로 다음 파일들을 생성한다.

**중요:** template 파일들은 `${CLAUDE_PLUGIN_ROOT}/templates/`에 있다. 읽고, placeholder를 치환하고, 프로젝트에 쓴다. **AGENTS.md를 canonical content source로**, **CLAUDE.md를 `@AGENTS.md` thin pointer로** 발행한다 (Codex/Cursor 등 16+ 벤더 호환 + 단일 source of truth).

#### 4a: Templates 읽기

플러그인에서 다음 파일을 읽는다:
- `${CLAUDE_PLUGIN_ROOT}/templates/shared/llm-guidelines.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/<strategy>/agents-md-section.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/<strategy>/branch-strategy.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/shared/commit-conventions.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/shared/pr-process.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/shared/claude-md-pointer.md`

여기서 `<strategy>`는 `github-flow`, `git-flow`, `trunk-based` 중 하나.

#### 4b: Placeholder 치환

template 컨텐츠에서 다음 placeholder들을 치환:

| Placeholder | 치환 값 |
|-------------|---------|
| `{{SCOPE_CONVENTION}}` | Step 3 질문 1의 scope 룰 |
| `{{MERGE_STRATEGY}}` | Step 3 질문 2의 merge 전략 |

#### 4c: 4-state matrix — AGENTS.md × CLAUDE.md

프로젝트 root의 `AGENTS.md`와 `CLAUDE.md` 상태에 따라 다음 matrix 적용 (AC22):

| State | AGENTS.md | CLAUDE.md | Action |
|---|---|---|---|
| **S1 (clean slate)** | 없음 | 없음 | AGENTS.md 신규 작성 (`agents-md-section.md` + `llm-guidelines.md` merge); CLAUDE.md 신규 작성 (`claude-md-pointer.md` content — `@AGENTS.md` 한 줄). |
| **S2 (CLAUDE-only legacy)** | 없음 | 존재 | Step 1의 migration 프롬프트 (AC21) — 거절 시 전체 `/project-init` abort. 승인 시 CLAUDE.md 내용 분기 (AC16 정규화 절차 (frontmatter strip → HTML comment strip → str.strip()) 준용해 분류): **S2a** 정규화 결과가 `@AGENTS.md` 아니면 full content — (a) `## LLM Coding Guidelines`/`## Git Workflow` 섹션 추출, (b) AGENTS.md로 이전·새 template과 merge, (c) CLAUDE.md를 `@AGENTS.md` 한 줄로 교체. **S2b** 정규화 결과 == `@AGENTS.md`인 dangling pointer (AGENTS.md 부재) — 새 template만으로 AGENTS.md 신규 작성, CLAUDE.md unchanged. |
| **S3 (AGENTS canonical, CLAUDE pointer)** | 존재 | 존재 + `@AGENTS.md` (R-pointer 통과) | AGENTS.md의 `## LLM Coding Guidelines`/`## Git Workflow` 섹션만 in-place 갱신. CLAUDE.md는 unchanged. |
| **S4 (AGENTS exists, CLAUDE divergent or absent)** | 존재 | 없음 또는 divergent content | 사용자에게 advisory + 두 옵션 — (i) CLAUDE.md를 `@AGENTS.md` 한 줄로 *재작성* (AGENTS.md unchanged), (ii) abort. 승인 시 (i) 수행 + S3 action. |

비-관리 컨텐츠 (다른 헤딩, 단락, 코드 블록)는 모든 state에서 보존.

#### 4d: docs/git-workflow/ 파일 쓰기

`docs/git-workflow/` 디렉토리가 없으면 생성. 다음 3개 파일 작성:

1. `docs/git-workflow/branch-strategy.md` — `templates/<strategy>/branch-strategy.md`에서
2. `docs/git-workflow/commit-conventions.md` — `templates/shared/commit-conventions.md`에서 (placeholder 치환 후)
3. `docs/git-workflow/pr-process.md` — `templates/shared/pr-process.md`에서 (placeholder 치환 후)
```

- [ ] **Step 2: Step 5 confirmation 메시지 갱신**

기존 Step 5 보고 메시지를 다음으로 교체 (AC23):

```markdown
### Step 5: 확인

생성 결과 보고:

> **{strategy 이름}** 전략으로 git workflow + LLM coding guidelines 초기화 완료.
>
> 생성/업데이트된 파일:
> - `AGENTS.md` — `## LLM Coding Guidelines`와 `## Git Workflow` 섹션 추가 (canonical content source)
> - `CLAUDE.md` — `@AGENTS.md` 한 줄 thin pointer (Claude Code가 AGENTS.md content를 자동 import)
> - `docs/git-workflow/branch-strategy.md` — 브랜치 룰
> - `docs/git-workflow/commit-conventions.md` — Commit 컨벤션
> - `docs/git-workflow/pr-process.md` — PR 프로세스
>
> `project-init` 플러그인 hook이 브랜치·commit 메시지 + agent-readable docs convention (size, TOC, fenced lang, links, drift)을 자동 검증합니다.
> AGENTS.md primary 패턴으로 OpenAI Codex, Cursor, Aider 등 16+ 벤더가 동일 파일을 인식합니다.
> 4-bullet LLM Coding Guidelines baseline은 Andrej Karpathy의 LLM 코딩 관찰에서 파생.
> 간결한 git 작업을 위해 `/commit` 또는 `/commit-push-pr` (commit-commands 플러그인) 사용.
```

- [ ] **Step 3: Step 1 migration 프롬프트 추가 확인**

기존 Step 1은 `## Git Workflow` 섹션 발견 시 migration 프롬프트만 묻는다. AC21에 따라 *기존 CLAUDE.md가 존재하면 AGENTS.md migration 프롬프트도 묻기*가 추가됨. Step 1 끝에 다음 추가:

```markdown
또한 root에 `CLAUDE.md`가 존재하고 `AGENTS.md`가 없다면 사용자에게 묻는다:

> "기존 CLAUDE.md 발견. AGENTS.md로 migrate할까요? (CLAUDE.md는 `@AGENTS.md` thin pointer로 교체됩니다)"

사용자 거절 시: 전체 `/project-init` 실행 abort — Step 2 이후의 docs/git-workflow/ 생성도 skip.
```

- [ ] **Step 4: Commit**

```bash
git add plugins/project-init/commands/project-init.md
git commit -m "feat(project-init): /project-init writes AGENTS.md primary + CLAUDE.md thin pointer (4-state matrix)"
```

---

## Task 11: Metadata + CHANGELOG + README 갱신

**Files:**
- Modify: `plugins/project-init/.claude-plugin/plugin.json`
- Modify: `plugins/project-init/CHANGELOG.md`
- Modify: `plugins/project-init/README.md`

**Covers AC26, AC27, AC28.**

- [ ] **Step 1: plugin.json version bump**

`plugins/project-init/.claude-plugin/plugin.json`:

```json
{
  "name": "project-init",
  "description": "Initialize git workflow rules + LLM coding baseline for any project. Select a branching strategy (GitHub Flow, Git Flow, Trunk-based), generate AGENTS.md (canonical) + CLAUDE.md (@AGENTS.md thin pointer) and docs/ with branch naming, Conventional Commits, PR process, and Karpathy-derived LLM coding guidelines. Auto-validates branch/commit + agent-readable docs conventions via hooks.",
  "version": "1.4.0",
  "author": {
    "name": "jeonghokim"
  }
}
```

- [ ] **Step 2: CHANGELOG.md `[1.4.0]` entry prepend**

`plugins/project-init/CHANGELOG.md`의 `## [1.3.0] — 2026-05-10` 위에 추가:

```markdown
## [1.4.0] — 2026-05-17

### Added
- `hooks/docs-lint.py` — root context 파일 (`CLAUDE.md`/`AGENTS.md`/`.claude/CLAUDE.md`/`.claude/AGENTS.md`) 의 5 agent-readable convention rule을 PostToolUse advisory로 검증. R1 size (>200 warn, >300 STRONG), R2 TOC (>300 lines required), R5 fenced code language tag, R6 internal links resolve, R-pointer CLAUDE/AGENTS drift (bidirectional trigger). Non-blocking, kill switch `DEVBREW_SKIP_HOOKS=project-init:docs-lint`. 디자인 근거: Anthropic 공식 ([code.claude.com/docs/en/memory.md] *"target under 200 lines"*) + AGENTS.md 오픈 스펙 ([agents.md] 16+ 벤더 채택) + Chroma 2025 *Context Rot* (input length에 monotonic degradation) + Lost-in-the-Middle (Liu 2023) 3-source 합의.
- `templates/shared/claude-md-pointer.md` — `@AGENTS.md\n` 한 줄, `/project-init`이 CLAUDE.md로 발행하는 thin pointer template.
- `hooks/tests/` — Python stdlib `unittest` 기반 39+ test case (모든 룰 happy/violation + kill switch + symlink + worktree + bidirectional trigger). fixture 10개 서브디렉토리 layout (`fixtures/<case>/AGENTS.md` 또는 `CLAUDE.md`).
- `hooks/tests/smoke.sh` — V2 자동화 smoke script (CI-runnable, no human eyeballing).

### Changed
- `commands/project-init.md` Step 4 전반 — **AGENTS.md를 canonical**, **CLAUDE.md를 `@AGENTS.md` thin pointer**로 발행. 기존 단일-CLAUDE.md 5-state matrix를 *AGENTS.md × CLAUDE.md 2축 4-state matrix* (S1 clean / S2a CLAUDE-only full / S2b dangling pointer / S3 AGENTS canonical / S4 divergent) 로 재작성. 4-state matrix는 mutually exclusive AND exhaustive — raw 6 조합 중 S2가 (2→1), S4가 (2→1) 압축.
- `commands/project-init.md` Step 1 — 기존 CLAUDE.md가 있고 AGENTS.md가 없으면 migration 프롬프트 추가. 거절 시 전체 abort.
- `commands/project-init.md` Step 5 confirmation — AGENTS.md (canonical) + CLAUDE.md (`@AGENTS.md` thin pointer) 생성 명시.
- `templates/<strategy>/claude-md-section.md` → `agents-md-section.md` 3건 rename (`git mv`로 history 보존).
- `hooks/hooks.json` — PostToolUse에 두 번째 entry 추가 (matcher `Write|Edit|MultiEdit`).

### Migration notes
- 기존 v1.3.0 사용자가 `/project-init` 재실행 시 S2 path로 진입 → migration 프롬프트 → AGENTS.md 생성 + CLAUDE.md thin pointer 교체.
- 두 hook은 kill switch 토큰이 다름 (`project-init:post-tool-use` vs `project-init:docs-lint`). 둘 모두 끄려면 `DEVBREW_SKIP_HOOKS=project-init:post-tool-use,project-init:docs-lint`.
```

- [ ] **Step 3: README.md 갱신 — Architecture tree**

`plugins/project-init/README.md` Architecture tree (line 7-30 부근) 를 다음으로 교체:

```markdown
## 아키텍처

\`\`\`
plugins/project-init/
├── .claude-plugin/plugin.json       # 플러그인 메타데이터
├── README.md                        # 본 파일
├── commands/
│   └── project-init.md              # /project-init — 인터랙티브 셋업
├── hooks/
│   ├── hooks.json                   # PostToolUse hook 설정 (2개 entry)
│   ├── post-tool-use.py             # 브랜치 명명 + 커밋 메시지 검증기 (Bash matcher)
│   ├── docs-lint.py                 # ★ v1.4.0 — agent-readable docs convention 검증 (Write/Edit/MultiEdit matcher)
│   └── tests/
│       ├── test_docs_lint.py        # 39+ Python stdlib unittest
│       ├── smoke.sh                 # V2 자동화 smoke script
│       └── fixtures/                # 10개 서브디렉토리 (valid, oversized, drifted, ...)
└── templates/
    ├── shared/
    │   ├── commit-conventions.md
    │   ├── llm-guidelines.md
    │   ├── pr-process.md
    │   └── claude-md-pointer.md     # ★ v1.4.0 — @AGENTS.md 한 줄 thin pointer
    ├── github-flow/
    │   ├── agents-md-section.md     # v1.4.0 rename (was claude-md-section.md)
    │   └── branch-strategy.md
    ├── git-flow/
    │   ├── agents-md-section.md
    │   └── branch-strategy.md
    └── trunk-based/
        ├── agents-md-section.md
        └── branch-strategy.md
\`\`\`
```

(이중 backtick → backslash로 escape — 실제 작성 시 정상 fence 사용)

- [ ] **Step 4: README.md — "Hooks Installed" 섹션 갱신**

기존 "Hooks Installed" 섹션을 다음으로 교체:

```markdown
## 설치된 Hook

- **`PostToolUse` (Bash matcher) — `post-tool-use.py`**: 브랜치 명·커밋 메시지 검증. **왜 hook인가?**: 검증은 모델 attention 여부와 무관하게 모든 Bash invocation에 발화해야 한다. skill은 모델이 invoke하는 단위라 action 레이어에서의 결정적 실행을 보장하지 못함.
  - Kill switch: `DEVBREW_DISABLE_PROJECT_INIT=1` 또는 `DEVBREW_SKIP_HOOKS=project-init:post-tool-use`

- **`PostToolUse` (Write|Edit|MultiEdit matcher) — `docs-lint.py` (v1.4.0)**: root context 파일 (CLAUDE.md, AGENTS.md, .claude/CLAUDE.md, .claude/AGENTS.md)의 agent-readable convention 5개 (size ≤200, TOC if >300, fenced code language, internal links resolve, CLAUDE/AGENTS drift) 검증. **왜 hook인가?**: 위와 동일 — Write/Edit이 일어날 때마다 deterministic하게 발화해야 함, advisory only (non-blocking).
  - Kill switch: `DEVBREW_DISABLE_PROJECT_INIT=1` (전체) 또는 `DEVBREW_SKIP_HOOKS=project-init:docs-lint` (이 hook만)
  - 두 hook 모두 끄려면: `DEVBREW_SKIP_HOOKS=project-init:post-tool-use,project-init:docs-lint`
```

- [ ] **Step 5: README.md — "Principles Instantiated" 섹션에 Law 1 라인 추가**

기존 "인스턴스화한 원칙" 섹션 안에 한 줄 추가:

```markdown
- **Law 1 (Clarity Before Code) — v1.4.0** — agent-readable docs convention enforcement (size ≤200, TOC ≥300줄, fenced code language tag, internal links resolve, CLAUDE/AGENTS drift). Anthropic 공식 가이드 + AGENTS.md 오픈 스펙 + Chroma 2025 *Context Rot* / Lost-in-the-Middle / MDEval / MAST 3-source 합의로 도출된 deterministic baseline.
```

- [ ] **Step 6: README.md — "동작 방식" 섹션 step 4 갱신**

기존 step 4 ("플러그인이 다음을 생성: ...") 의 CLAUDE.md 줄을 다음으로 교체:

```markdown
4. 플러그인이 다음을 생성:
   - `AGENTS.md` — `## LLM Coding Guidelines` + `## Git Workflow` (canonical content source, OpenAI Codex/Cursor/Aider 등 16+ 벤더 자동 인식)
   - `CLAUDE.md` — `@AGENTS.md` 한 줄 thin pointer (Claude Code가 AGENTS.md content를 자동 import)
   - `docs/git-workflow/branch-strategy.md` — 팀의 브랜치 룰
   - `docs/git-workflow/commit-conventions.md` — Conventional Commits 룰
   - `docs/git-workflow/pr-process.md` — PR 템플릿과 리뷰 체크리스트
```

- [ ] **Step 7: Commit**

```bash
git add plugins/project-init/.claude-plugin/plugin.json \
        plugins/project-init/CHANGELOG.md \
        plugins/project-init/README.md
git commit -m "chore(project-init): v1.4.0 metadata + CHANGELOG + README"
```

---

## Task 12: 최종 검증 + PR 준비

**Files:** 없음 (검증만)

**Covers V1, V2, V3, V4, V5, V7-V11.**

- [ ] **Step 1: V1 — unit tests pass**

Run: `cd plugins/project-init && python3 -m unittest discover hooks/tests -v`
Expected: 39+ tests pass (skeleton 8 + R1 4 + R2 5 + R5 6 + R6 7 + R-pointer 9).

- [ ] **Step 2: V2 — smoke script pass**

Run: `bash plugins/project-init/hooks/tests/smoke.sh`
Expected: `V2 PASS`.

- [ ] **Step 3: V3 — kill switch smoke**

```bash
out1=$(DEVBREW_DISABLE_PROJECT_INIT=1 python3 plugins/project-init/hooks/docs-lint.py \
  <<< '{"tool_name":"Write","tool_input":{"file_path":"plugins/project-init/hooks/tests/fixtures/oversized/AGENTS.md"}}')
[ "$out1" = "{}" ] && echo "V3a PASS" || exit 1

out2=$(DEVBREW_SKIP_HOOKS=project-init:docs-lint python3 plugins/project-init/hooks/docs-lint.py \
  <<< '{"tool_name":"Write","tool_input":{"file_path":"plugins/project-init/hooks/tests/fixtures/oversized/AGENTS.md"}}')
[ "$out2" = "{}" ] && echo "V3b PASS" || exit 1
```

Expected: V3a PASS + V3b PASS.

- [ ] **Step 4: V4 — existing post-tool-use.py 회귀 없음**

```bash
out=$(echo '{"tool_name":"Bash","tool_input":{"command":"git checkout -b feature/Foo_Bar"}}' \
  | CLAUDE_PROJECT_DIR=$(pwd) python3 plugins/project-init/hooks/post-tool-use.py)
echo "$out" | grep -q "naming convention" && echo "V4 PASS" || exit 1
```

Expected: V4 PASS.

- [ ] **Step 5: V5 — plugin-validator agent**

```
Dispatch plugin-dev:plugin-validator agent on plugins/project-init/ with focus:
- version 1.4.0 bump
- CHANGELOG [1.4.0] entry present
- README Architecture/Hooks/Principles sections updated
- new files referenced in hooks.json exist
```

Expected: agent reports no critical issues.

- [ ] **Step 6: V7 — 통합 시나리오 (수동) — `/project-init` 신규 프로젝트**

빈 tempdir 에서 `/project-init` 실행 → AGENTS.md (full content) + CLAUDE.md (`@AGENTS.md`) 둘 다 생성 확인.

- [ ] **Step 7: V8 — `/project-init` migration**

기존 CLAUDE.md만 있는 tempdir 에서 `/project-init` 실행 → migration prompt → 승인 → AGENTS.md로 content 이전 + CLAUDE.md thin pointer 교체 확인.

- [ ] **Step 8: V9 — hook 발화 통합**

AGENTS.md를 Edit으로 줄 추가해 201줄로 만들기 → R1 systemMessage 나타나는지 확인.

- [ ] **Step 9: V10 — worktree 시나리오**

```bash
git worktree add /tmp/devbrew-wt-test feature/docs-lint-hook
cd /tmp/devbrew-wt-test
# Edit AGENTS.md to be oversized → R1 fires
# Cleanup: git worktree remove /tmp/devbrew-wt-test
```

Expected: hook fires correctly, CLAUDE_PROJECT_DIR is worktree root.

- [ ] **Step 10: V11 — `.git/worktrees/**` skip**

`.git/worktrees/wt1/CLAUDE.md` 같은 경로 임의 생성 → hook target에서 제외되어 `{}` 반환 확인.

- [ ] **Step 11: PR 생성**

```bash
git push -u origin feature/docs-lint-hook
gh pr create --title "feat(project-init): docs-lint hook v1.4.0 (5 rules + AGENTS.md primary)" --body "$(cat <<'EOF'
## Summary

- root context 파일 (`CLAUDE.md`/`AGENTS.md`/`.claude/CLAUDE.md`/`.claude/AGENTS.md`) 에 5개 deterministic rule을 PostToolUse advisory로 검증하는 `docs-lint.py` hook 신설
- `/project-init` command가 **AGENTS.md를 canonical** + **CLAUDE.md를 `@AGENTS.md` thin pointer**로 발행하도록 갱신 (Codex/Cursor 등 16+ 벤더 호환)
- 두 변경은 chicken-and-egg coupling으로 단일 PR (spec §1 Goal coupling 근거 참조)

## Rules (R1-R5 + R-pointer)

- **R1 (size)**: >200줄 warn, >300줄 STRONG warn
- **R2 (TOC)**: >300줄이면 `## 목차` / `## Table of Contents` 필수
- **R5 (fenced lang)**: 3-backtick opening fence는 언어 태그 필수 (4+ backtick / tilde / space-separated info string scope 밖)
- **R6 (links)**: internal markdown link `os.path.exists` 검증, URL scheme/anchor skip
- **R-pointer**: CLAUDE.md ↔ AGENTS.md drift 검출 (bidirectional trigger, symlink/thin pointer 통과)

## Design source

- 디자인 스펙: `docs/superpowers/specs/2026-05-17-project-init-docs-lint-hook-design.md` (4-round spec-reviewer approved)
- 구현 계획: `docs/superpowers/plans/2026-05-17-project-init-docs-lint-hook.md`
- 3-agent 리서치 (Anthropic 공식 / AGENTS.md 오픈 스펙 + Codex/Cursor/Aider / Chroma context-rot + Lost-in-the-Middle + MDEval + MAST) 합의 기반

## Test plan

- [ ] V1: `python3 -m unittest discover plugins/project-init/hooks/tests -v` — 39+ tests pass
- [ ] V2: `bash plugins/project-init/hooks/tests/smoke.sh` — V2 PASS
- [ ] V3: kill switch 양쪽 (`DEVBREW_DISABLE_PROJECT_INIT=1`, `DEVBREW_SKIP_HOOKS=project-init:docs-lint`) 정상
- [ ] V4: 기존 `post-tool-use.py` branch validator 회귀 없음
- [ ] V5: plugin-validator agent pass
- [ ] V7-V8: `/project-init` 신규/migration 시나리오 manual smoke
- [ ] V10-V11: worktree 시나리오

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 12: PR URL 보고**

PR 생성 후 URL을 사용자에게 출력.

---

## V12 Probe Result

- Date: 2026-05-17
- Harness: Claude Code (`claude-opus-4-7[1m]`)
- Verdict: **SUPPORTED** — `matcher: "Write|Edit|MultiEdit"` regex alternation 지원 확인. 별도 probe 우회됨.
- Evidence: `plugins/spec-distill/hooks/hooks.json:33`이 이미 동일 패턴 (`"matcher": "Write|Edit|MultiEdit"`) 선언. 본 세션에서 `docs/superpowers/specs/2026-05-17-project-init-docs-lint-hook-design.md` Write 시 spec-distill의 `spec-write-validator.py`가 정상 발화 → `.claude/spec-distill/default/state.local.md`에 `pending_review:` 블록 기록. 같은 세션의 실측으로 harness가 regex alternation을 그대로 처리함을 확인. → Task 8의 `hooks.json` entry를 spec AC3 그대로 작성. Plan unchanged.

---

## Self-Review checklist

(plan 작성자가 작성 후 자체 검증)

**1. Spec coverage**: spec의 34 ACs를 task로 매핑:
- AC1, AC2, AC4-AC6 → Task 1 (skeleton)
- AC3 → Task 8 (hooks.json)
- AC7, AC8 → Task 2 (R1)
- AC9, AC10 → Task 3 (R2)
- AC11, AC12 → Task 4 (R5)
- AC13-AC15 → Task 5 (R6)
- AC16-AC18.5 → Task 6 (R-pointer)
- AC19 → Task 2-6 (message composition, 각 rule이 append; final \n\n join in main())
- AC20-AC23 → Task 10 (`/project-init`)
- AC24, AC25 → Task 9 (template rename)
- AC26-AC28 → Task 11 (metadata)
- AC29-AC34 → Task 1-6 (per-rule tests), Task 7 (fixtures + smoke)
- V12 → Task 0 (pre-flight)
- V1-V11 → Task 12 (verification)

✓ 모든 AC 매핑.

**2. Placeholder scan**: 모든 step에 actual code/command. TBD 없음. "TODO" 없음. "Add error handling" 없음.

**3. Type consistency**: 함수명 `check_r1_size`/`check_r2_toc`/`check_r5_fences`/`check_r6_links`/`check_r_pointer` 일관. `resolve_target_path`/`emit`/`kill_switch_active` 명명 일관. fixture 디렉토리 이름 (valid, oversized, strong_oversized, missing_toc, bare_fence, broken_link, drifted, proper_pointer, dangling_pointer) Task 7 fixture + Task 7 smoke + Task 8 V2 모두 동일.

**4. 발견된 inconsistency**: 없음.
