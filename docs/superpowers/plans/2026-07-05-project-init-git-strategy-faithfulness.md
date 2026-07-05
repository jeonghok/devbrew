# project-init git-strategy enforcement faithfulness — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** project-init의 enforcement hook(`post-tool-use.py`)이 프로젝트가 선택한 git 전략에 충실해지도록 — 폴백·교정 제안이 미선택 GitHub Flow를 단정하지 않게 — 수정하고, 전무하던 테스트 하니스로 회귀를 막는다.

**Architecture:** `post-tool-use.py`는 PostToolUse advisory hook(항상 `sys.exit(0)`, `systemMessage`로 non-blocking 경고). 순수 함수 3개(`get_branch_pattern`·`derive_prefixes`·`validate_branch`)를 조합하고 `main()`이 stdin JSON을 읽어 두 검증기를 실행한다. 이 계획은 (F1) 패턴-해석 계약을 `Optional[re.Pattern]`로 바꿔 loud-advisory fail-open을 도입, (F2) 교정 제안을 활성 패턴에서 파생, (F3) trunk 템플릿을 doc-only로 정직화, (main §5.5) 두 검증기를 무조건 실행하도록 하고, 신규 `test_post_tool_use.py`로 전부를 잠근다.

**Tech Stack:** Python 3 stdlib(`re`, `json`, `os`, `sys`, `unittest`, `importlib`, `tempfile`, `subprocess`). 테스트 실행은 `python3 -m unittest`. Markdown 템플릿/문서.

## Global Constraints

이 절의 값은 모든 task에 암묵 포함된다. spec §4에서 verbatim.

- **advisory hook 유지** — PostToolUse, 항상 `sys.exit(0)` + `systemMessage`. blocking(PreToolUse deny) 승격 금지.
- **kill switch 불변** — `DEVBREW_DISABLE_PROJECT_INIT=1` / `DEVBREW_SKIP_HOOKS=project-init:post-tool-use`. 어떤 변경도 kill switch 존중을 약화하지 않는다.
- **`validate_commit` 함수 내부 로직 불변** — 호출 빈도만 §5.5에서 개선(compound 명령에서 branch 경고와 무관하게 실행).
- **신규 워크트리에서 구현** — `feature/git-strategy-faithfulness` (이미 생성, base `00415d9`). 모든 파일 경로는 워크트리 절대경로 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/...`. main-repo 동명 파일(`/Users/jeonghokim/Downloads/devbrew/plugins/...`)에 절대 쓰지 말 것.
- **plugin.json bump 동반** — 같은 PR에서 `1.6.0 → 1.7.0`(minor). 다섯 commit 모두 단일 PR로 merge되어 bump가 함께 shipping됨.
- **문서 Korean-primary** — CHANGELOG/README 동기화. 영어는 식별자·regex·code·고유명사에 한정.
- **테스트 실행은 `python3 -m unittest`** — 직접 실행(`python3 test_x.py`)은 vacuous. 워크트리 root(`plugins/project-init`이 보이는 위치)에서 실행.
- **git merge over rebase; 서브에이전트 순차** — 병렬·투기적 dispatch 금지.

---

## File Structure

| 파일 (워크트리 절대경로 prefix 생략) | 책임 | Task |
|---|---|---|
| `plugins/project-init/hooks/post-tool-use.py` | enforcement hook. F1(`get_branch_pattern` Optional + `DEFAULT_BRANCH_PATTERN` 삭제 + `validate_branch` fail-open), F2(`derive_prefixes` 신규 + suggestion 재작성), main() 이중 검증 | 1, 2, 3 |
| `plugins/project-init/hooks/tests/test_post_tool_use.py` | **신규** 테스트 하니스. `importlib` 로드 + `unittest` | 1, 2, 3 |
| `plugins/project-init/templates/trunk-based/branch-strategy.md` | trunk 템플릿 Pattern B 노트 doc-only 재작성 | 4 |
| `plugins/project-init/.claude-plugin/plugin.json` | `version` 1.6.0 → 1.7.0 | 5 |
| `plugins/project-init/CHANGELOG.md` | `## [1.7.0]` 엔트리 | 5 |
| `plugins/project-init/README.md` | "## 설치된 Hook" `post-tool-use` 줄 + tree 주석 동기화 | 5 |

`test_post_tool_use.py`는 세 task에 걸쳐 **점진적으로 append**된다: Task 1이 파일을 생성(scaffold + F1 클래스), Task 2가 F2 클래스 append, Task 3이 main() 클래스 append. 각 task는 실행 전 파일을 Read해 현재 상태를 확인한다.

---

## Task 1: F1 — loud-advisory fail-open 폴백 + 테스트 하니스

**Files:**
- Create: `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/plugins/project-init/hooks/tests/test_post_tool_use.py`
- Modify: `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/plugins/project-init/hooks/post-tool-use.py` (line 19 `DEFAULT_BRANCH_PATTERN` 삭제; `get_branch_pattern` 59-77 재작성; `validate_branch` 97-99에 fail-open 분기 삽입)

**Interfaces:**
- Consumes: 없음(첫 task).
- Produces: 테스트 하니스가 다음을 export — 모듈 `_hook`(`importlib`로 로드한 `post-tool-use.py`), 헬퍼 `write_strategy(project_dir, regex_block)`, `run_hook(payload, env_override=None, cwd=None) -> (stdout, returncode)`. Task 2·3이 재사용. hook 측: `get_branch_pattern() -> Optional[re.Pattern]`(None = fail-open), `validate_branch(command) -> Optional[str]`(fail-open 시 "fail-open" 포함 advisory 문자열).

- [ ] **Step 1: 테스트 하니스 파일 생성 (scaffold + F1 클래스)**

`/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/plugins/project-init/hooks/tests/test_post_tool_use.py` 를 다음 내용으로 생성:

```python
"""Unit tests for plugins/project-init/hooks/post-tool-use.py."""
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Optional, Tuple

HOOK = Path(__file__).resolve().parent.parent / "post-tool-use.py"

# The hook filename has a hyphen, so it is not importable by name. Load it via
# importlib (side-effect-free: post-tool-use.py guards execution behind
# `if __name__ == "__main__":`) so tests couple to the REAL functions/constants
# rather than parallel literal copies. Mirrors test_docs_lint.py.
_spec = importlib.util.spec_from_file_location("post_tool_use_hook", HOOK)
assert _spec is not None and _spec.loader is not None, f"could not load hook module from {HOOK}"
_hook = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_hook)


def write_strategy(project_dir: str, regex_block: Optional[str]) -> None:
    """Write docs/git-workflow/branch-strategy.md under project_dir.

    regex_block is None  -> file with NO ```regex fence (regex-less).
    regex_block == ""    -> file with an EMPTY ```regex fence (degenerate).
    otherwise            -> file with a ```regex fence containing regex_block.
    """
    dst = Path(project_dir) / "docs" / "git-workflow"
    dst.mkdir(parents=True, exist_ok=True)
    f = dst / "branch-strategy.md"
    if regex_block is None:
        f.write_text("# Branch Strategy\n\nNo regex fence here.\n")
    else:
        f.write_text(f"# Branch Strategy\n\n```regex\n{regex_block}\n```\n")


def run_hook(payload: dict, env_override: Optional[dict] = None,
             cwd: Optional[str] = None) -> Tuple[str, int]:
    """Invoke the hook script as a subprocess; return (stdout, returncode)."""
    env = os.environ.copy()
    # Strip inherited devbrew env vars so tests are deterministic.
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


class _ProjectDirTestCase(unittest.TestCase):
    """Base: isolates CLAUDE_PROJECT_DIR to a fresh tempdir per test."""

    def setUp(self) -> None:
        self._prev = os.environ.get("CLAUDE_PROJECT_DIR")
        self.tmp = tempfile.mkdtemp()
        os.environ["CLAUDE_PROJECT_DIR"] = self.tmp

    def tearDown(self) -> None:
        if self._prev is None:
            os.environ.pop("CLAUDE_PROJECT_DIR", None)
        else:
            os.environ["CLAUDE_PROJECT_DIR"] = self._prev
        shutil.rmtree(self.tmp, ignore_errors=True)


class F1FailOpenTest(_ProjectDirTestCase):
    """F1 / LD2 — no valid declared pattern => fail OPEN, loudly (AC1)."""

    def test_file_absent_fails_open(self):
        # No strategy file written under self.tmp.
        self.assertIsNone(_hook.get_branch_pattern())
        msg = _hook.validate_branch("git checkout -b release/x")
        self.assertIsNotNone(msg)
        self.assertIn("fail-open", msg)
        self.assertIn("skipping", msg)

    def test_regexless_file_fails_open(self):
        write_strategy(self.tmp, None)
        self.assertIsNone(_hook.get_branch_pattern())
        self.assertIn("fail-open", _hook.validate_branch("git checkout -b release/x"))

    def test_malformed_regex_fails_open(self):
        write_strategy(self.tmp, "^(feature|fix")  # unbalanced paren -> re.error
        self.assertIsNone(_hook.get_branch_pattern())
        self.assertIn("fail-open", _hook.validate_branch("git checkout -b whatever"))

    def test_empty_regex_fence_fails_open(self):
        write_strategy(self.tmp, "")  # ```regex\n\n``` -> search regex can't capture
        self.assertIsNone(_hook.get_branch_pattern())
        self.assertIn("fail-open", _hook.validate_branch("git checkout -b release/x"))

    def test_whitespace_only_regex_fence_fails_open(self):
        # ```regex\n   \n``` -> captures "   " -> .strip() empty -> guard -> None.
        # Must NOT become re.compile("") which would silently pass EVERY branch.
        write_strategy(self.tmp, "   ")
        self.assertIsNone(_hook.get_branch_pattern())
        msg = _hook.validate_branch("git checkout -b anything-goes")
        self.assertIsNotNone(msg)  # not silent pass-all
        self.assertIn("fail-open", msg)

    def test_declared_gitflow_pattern_respected(self):
        # AC3: a declared pattern is honored; release/* passes, no fail-open.
        write_strategy(self.tmp, r"^(feature|fix|release|hotfix)/[a-z0-9][a-z0-9.-]*$")
        pat = _hook.get_branch_pattern()
        self.assertIsNotNone(pat)
        self.assertIsNone(_hook.validate_branch("git checkout -b release/v1.2"))


class F1RegressionLockTest(unittest.TestCase):
    """AC2 — DEFAULT_BRANCH_PATTERN must stay deleted (no silent GitHub-Flow default)."""

    def test_default_branch_pattern_symbol_removed(self):
        self.assertFalse(
            hasattr(_hook, "DEFAULT_BRANCH_PATTERN"),
            "DEFAULT_BRANCH_PATTERN reintroduced — GitHub-Flow default fallback is back",
        )


class PreservedBehaviorTest(_ProjectDirTestCase):
    """AC7 — commit / kill-switch / non-Bash / malformed-JSON paths unchanged."""

    def test_protected_branch_skipped(self):
        self.assertIsNone(_hook.validate_branch("git checkout -b main"))

    def test_conventional_commit_passes(self):
        self.assertIsNone(_hook.validate_commit('git commit -m "feat: add thing"'))

    def test_non_conventional_commit_flagged(self):
        msg = _hook.validate_commit('git commit -m "add thing"')
        self.assertIsNotNone(msg)
        self.assertIn("Conventional Commits", msg)

    def test_kill_switch_disable(self):
        out, rc = run_hook(
            {"tool_name": "Bash", "tool_input": {"command": "git checkout -b Bad_Name"}},
            env_override={"DEVBREW_DISABLE_PROJECT_INIT": "1"},
        )
        self.assertEqual(out.strip(), "{}")
        self.assertEqual(rc, 0)

    def test_non_bash_tool_skipped(self):
        out, rc = run_hook({"tool_name": "Write", "tool_input": {"file_path": "x"}})
        self.assertEqual(out.strip(), "{}")
        self.assertEqual(rc, 0)

    def test_malformed_json_stdin(self):
        env = os.environ.copy()
        for k in list(env):
            if k.startswith("DEVBREW_"):
                del env[k]
        cp = subprocess.run(
            [sys.executable, str(HOOK)], input="not json",
            capture_output=True, text=True, env=env, timeout=10,
        )
        self.assertEqual(cp.stdout.strip(), "{}")
        self.assertEqual(cp.returncode, 0)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 테스트 실행 → RED 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/plugins/project-init && python3 -m unittest hooks.tests.test_post_tool_use -v`

Expected: FAIL. 구체적으로 —
- `F1RegressionLockTest.test_default_branch_pattern_symbol_removed` → FAIL(현재 `DEFAULT_BRANCH_PATTERN` 존재).
- `F1FailOpenTest.test_file_absent_fails_open` 외 fail-open 케이스 → FAIL(현재 `get_branch_pattern`이 `DEFAULT_BRANCH_PATTERN` 반환 → "fail-open" 문자열 없음, 또는 rejection).
- `PreservedBehaviorTest.*` → PASS(회귀 락, 처음부터 green).

(참고: `python3 -m unittest hooks.tests.test_post_tool_use`는 `plugins/project-init`에 `hooks/__init__.py`가 없어도 `hooks/tests/__init__.py`가 있으면 동작한다. 실패 시 대안: `python3 -m unittest discover -s hooks/tests -p 'test_post_tool_use.py' -v`.)

- [ ] **Step 3: F1 구현 — `DEFAULT_BRANCH_PATTERN` 삭제**

`post-tool-use.py` line 17-19 영역에서 상수 정의를 제거. 현재:

```python
# --- Constants ---

DEFAULT_BRANCH_PATTERN = re.compile(r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$")
CONVENTIONAL_COMMIT_PATTERN = re.compile(
```

로 바꿈:

```python
# --- Constants ---

CONVENTIONAL_COMMIT_PATTERN = re.compile(
```

(`DEFAULT_BRANCH_PATTERN` 한 줄만 삭제. `CONVENTIONAL_COMMIT_PATTERN` 이하는 불변.)

- [ ] **Step 4: F1 구현 — `get_branch_pattern` 재작성 (Optional + empty-block guard)**

현재 `get_branch_pattern` (line 59-77) 전체를 아래로 교체:

```python
def get_branch_pattern():
    """Return the declared branch pattern, or None when none is validly declared.

    None => fail-open: 전략 미선언 → 브랜치명 검증을 건너뛴다(loud advisory).
    아래 넷을 하나의 fail-open 경로로 통일한다: (1) 파일 부재, (2) ```regex 블록
    부재, (3) malformed regex(re.error), (4) 빈/공백-only 블록(.strip() 후 empty).
    """
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", ".")
    strategy_path = os.path.join(
        project_dir, "docs", "git-workflow", "branch-strategy.md"
    )
    try:
        with open(strategy_path, "r") as f:
            content = f.read()
        match = re.search(r"```regex\n(.+?)\n```", content)
        if match and match.group(1).strip():  # 빈/공백-only 캡처 → 무효(fail-open, reviewer cccfc098)
            return re.compile(match.group(1).strip())
    except (FileNotFoundError, IOError, re.error):
        pass
    return None
```

- [ ] **Step 5: F1 구현 — `validate_branch`에 fail-open 분기 삽입**

현재 `validate_branch` (line 86-111)의 pattern 사용부:

```python
    pattern = get_branch_pattern()
    if pattern.match(branch_name):
        return None

    # Suggest correction
    suggestion = branch_name
    if "/" in suggestion:
        suggestion = suggestion.split("/", 1)[1]
    suggestion = f"feature/{suggestion}"

    return (
        f'project-init: Branch "{branch_name}" does not follow naming convention.\n'
        f"Expected pattern: {pattern.pattern}\n"
        f"Suggested: git branch -m {suggestion}"
    )
```

를 아래로 교체 (fail-open 분기만 추가; suggestion 블록은 Task 2에서 재작성하므로 이번엔 그대로 유지):

```python
    pattern = get_branch_pattern()
    if pattern is None:  # 유효 패턴 없음(부재/regex-less/malformed/빈-블록) → fail OPEN, loudly
        return (
            "project-init: no valid branch-naming pattern found in "
            "docs/git-workflow/branch-strategy.md — skipping branch-name "
            "validation (fail-open)."
        )
    if pattern.match(branch_name):
        return None

    # Suggest correction
    suggestion = branch_name
    if "/" in suggestion:
        suggestion = suggestion.split("/", 1)[1]
    suggestion = f"feature/{suggestion}"

    return (
        f'project-init: Branch "{branch_name}" does not follow naming convention.\n'
        f"Expected pattern: {pattern.pattern}\n"
        f"Suggested: git branch -m {suggestion}"
    )
```

- [ ] **Step 6: 테스트 실행 → GREEN 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/plugins/project-init && python3 -m unittest hooks.tests.test_post_tool_use -v`

Expected: PASS (모든 `F1FailOpenTest`·`F1RegressionLockTest`·`PreservedBehaviorTest` green).

- [ ] **Step 7: docs-lint 회귀 없음 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/plugins/project-init && python3 -m unittest hooks.tests.test_docs_lint 2>&1 | tail -3`

Expected: OK (기존 테스트 무회귀 — post-tool-use 변경은 docs-lint와 독립).

- [ ] **Step 8: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness
git add plugins/project-init/hooks/post-tool-use.py plugins/project-init/hooks/tests/test_post_tool_use.py
git commit -m "feat(project-init): fail-open branch validation when strategy undeclared (F1)

DEFAULT_BRANCH_PATTERN 삭제; get_branch_pattern -> Optional[re.Pattern]
(부재/regex-less/malformed/빈-블록 통일 fail-open); validate_branch가
loud advisory 반환. 신규 test_post_tool_use.py 하니스로 AC1/AC2/AC7 잠금.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 9: 워크트리 브랜치 확인 (drift 방지)**

Run: `git branch --show-current`
Expected: `feature/git-strategy-faithfulness` (detached HEAD 아님).

---

## Task 2: F2 — 활성 패턴 파생 교정 제안

**Files:**
- Modify: `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/plugins/project-init/hooks/post-tool-use.py` (`derive_prefixes` 신규 헬퍼 추가; `validate_branch`의 suggestion 블록 재작성)
- Modify: `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/plugins/project-init/hooks/tests/test_post_tool_use.py` (F2 테스트 클래스 append)

**Interfaces:**
- Consumes: Task 1이 만든 `_hook`, `write_strategy`, `_ProjectDirTestCase`. `_hook.validate_branch(command) -> Optional[str]`.
- Produces: `derive_prefixes(pattern: re.Pattern) -> list[str]` (선두 identifier-alternation 그룹에서 prefix 추출, exotic이면 `[]`). `validate_branch`의 declared-pattern 위반 메시지가 파생 prefix를 나열하고 `feature/<name>` 하드코딩을 하지 않음.

- [ ] **Step 1: F2 실패 테스트 append**

`test_post_tool_use.py` 의 `if __name__ == "__main__":` 줄 *앞에* 다음 두 클래스를 추가:

```python
class DerivePrefixesTest(unittest.TestCase):
    """F2 / AC4 / AC5 — extract prefixes from leading identifier-alternation only."""

    def test_github_flow(self):
        pat = re.compile(r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$")
        self.assertEqual(_hook.derive_prefixes(pat), ["feature", "fix"])

    def test_git_flow(self):
        pat = re.compile(r"^(feature|fix|release|hotfix)/[a-z0-9][a-z0-9.-]*$")
        self.assertEqual(_hook.derive_prefixes(pat), ["feature", "fix", "release", "hotfix"])

    def test_non_capturing_group(self):
        pat = re.compile(r"^(?:feature|fix)/[a-z0-9].*$")
        self.assertEqual(_hook.derive_prefixes(pat), ["feature", "fix"])

    def test_inline_flag_group_not_misparsed(self):
        # (?i) inline flag must NOT yield ["i"] — reviewer a909f052
        pat = re.compile(r"(?i)^(feature|fix)/[a-z0-9].*$")
        self.assertEqual(_hook.derive_prefixes(pat), [])

    def test_nested_group(self):
        pat = re.compile(r"^((?:a|b))/[a-z0-9].*$")
        self.assertEqual(_hook.derive_prefixes(pat), [])

    def test_literal_prefix(self):
        pat = re.compile(r"^feature-.*$")
        self.assertEqual(_hook.derive_prefixes(pat), [])


class F2SuggestionTest(_ProjectDirTestCase):
    """F2 / AC4 / AC5 — correction suggestion derived from active pattern."""

    def test_gitflow_violation_lists_derived_prefixes_no_feature_hardcode(self):
        write_strategy(self.tmp, r"^(feature|fix|release|hotfix)/[a-z0-9][a-z0-9.-]*$")
        msg = _hook.validate_branch("git checkout -b hotfix-login")
        self.assertIsNotNone(msg)
        self.assertIn("release", msg)
        self.assertIn("hotfix", msg)
        self.assertNotIn("feature/hotfix-login", msg)   # no hardcoded feature/ suggestion
        self.assertIn("<prefix>/hotfix-login", msg)      # placeholder, not a single prefix

    def test_exotic_pattern_degrades_to_doc(self):
        write_strategy(self.tmp, r"^feature-.*$")  # literal prefix -> exotic -> []
        msg = _hook.validate_branch("git checkout -b bad")
        self.assertIsNotNone(msg)
        self.assertNotIn("git branch -m", msg)  # cmd is None for exotic
        self.assertIn("docs/git-workflow/branch-strategy.md", msg)
```

- [ ] **Step 2: 테스트 실행 → RED 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/plugins/project-init && python3 -m unittest hooks.tests.test_post_tool_use -v`

Expected: FAIL —
- `DerivePrefixesTest.*` → FAIL/ERROR(`_hook`에 `derive_prefixes` 없음, `AttributeError`).
- `F2SuggestionTest.test_gitflow_violation_...` → FAIL(현재 `Suggested: git branch -m feature/hotfix-login` → `feature/hotfix-login` 포함, `release`/`<prefix>` 부재).
- Task 1 클래스들 → 여전히 PASS.

- [ ] **Step 3: F2 구현 — `derive_prefixes` 헬퍼 추가**

`post-tool-use.py` 의 `guess_commit_type` 함수 *바로 앞* (현재 `def guess_commit_type` 정의 위)에 신규 함수 추가:

```python
def derive_prefixes(pattern):
    """Extract allowed branch prefixes from a compiled pattern's leading alternation group.

    ^(feature|fix|release|hotfix)/…  ->  ["feature","fix","release","hotfix"]
    ^(?:feature|fix)/…               ->  ["feature","fix"]   (non-capturing OK)
    선두가 identifier-alternation이 아니면(inline flags (?i), nested group, 리터럴 등) → []
    (교정 제안에서 prefix 하드코딩 금지). 그룹 내용을 [a-z][a-z0-9-]* 토큰의 |-결합으로
    못박아 `(?i)` 같은 flag 그룹이 "i" 프리픽스로 오파싱되지 않게 한다(reviewer a909f052).
    """
    m = re.match(
        r"\^?\((?:\?:)?([a-z][a-z0-9-]*(?:\|[a-z][a-z0-9-]*)*)\)", pattern.pattern
    )
    return m.group(1).split("|") if m else []
```

- [ ] **Step 4: F2 구현 — `validate_branch` suggestion 블록 재작성**

Task 1 Step 5에서 남겨둔 suggestion 블록 (`# Suggest correction` 부터 함수 끝까지):

```python
    # Suggest correction
    suggestion = branch_name
    if "/" in suggestion:
        suggestion = suggestion.split("/", 1)[1]
    suggestion = f"feature/{suggestion}"

    return (
        f'project-init: Branch "{branch_name}" does not follow naming convention.\n'
        f"Expected pattern: {pattern.pattern}\n"
        f"Suggested: git branch -m {suggestion}"
    )
```

를 아래로 교체:

```python
    # Suggest correction — prefixes derived from the active pattern (no feature/ hardcode)
    name_part = branch_name.split("/", 1)[1] if "/" in branch_name else branch_name
    prefixes = derive_prefixes(pattern)
    if prefixes:
        hint = f"Allowed prefixes: {', '.join(prefixes)}"
        cmd = f"Rename with: git branch -m <prefix>/{name_part}   (choose a prefix above)"
    else:  # exotic regex → NO feature/ hardcode
        hint = "See docs/git-workflow/branch-strategy.md for allowed prefixes."
        cmd = None

    lines = [
        f'project-init: Branch "{branch_name}" does not follow naming convention.',
        f"Expected pattern: {pattern.pattern}",
        hint,
    ]
    if cmd:
        lines.append(cmd)
    return "\n".join(lines)
```

- [ ] **Step 5: 테스트 실행 → GREEN 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/plugins/project-init && python3 -m unittest hooks.tests.test_post_tool_use -v`

Expected: PASS (전 클래스 green — `DerivePrefixesTest` 6, `F2SuggestionTest` 2 포함).

- [ ] **Step 6: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness
git add plugins/project-init/hooks/post-tool-use.py plugins/project-init/hooks/tests/test_post_tool_use.py
git commit -m "feat(project-init): derive branch-prefix suggestions from active pattern (F2)

derive_prefixes()가 선두 identifier-alternation 그룹에서 허용 prefix 추출.
validate_branch 교정 제안이 feature/ 하드코딩 대신 파생 prefix 목록 +
<prefix>/<name> 플레이스홀더 제시; exotic regex((?i)/nested/리터럴)는 [] →
docs 참조로 강등. AC4/AC5 잠금.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 7: 워크트리 브랜치 확인**

Run: `git branch --show-current`
Expected: `feature/git-strategy-faithfulness`.

---

## Task 3: main() 이중 검증 (compound 명령 commit 회귀 봉쇄)

**Files:**
- Modify: `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/plugins/project-init/hooks/post-tool-use.py` (`main()` line 177-183의 `or` short-circuit 제거)
- Modify: `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/plugins/project-init/hooks/tests/test_post_tool_use.py` (main() 이중 검증 클래스 append)

**Interfaces:**
- Consumes: Task 1의 `run_hook`, `write_strategy`. hook `main()`이 stdin JSON → `{"systemMessage": ...}` 또는 `{}`.
- Produces: `main()`이 두 검증기를 무조건 실행하고 경고를 `"\n\n"`로 concatenate. compound 명령에서 branch advisory가 commit 검증을 short-circuit하지 않음.

- [ ] **Step 1: main() 이중 검증 실패 테스트 append**

`test_post_tool_use.py` 의 `if __name__ == "__main__":` 줄 *앞에* 추가:

```python
class MainDoubleValidationTest(unittest.TestCase):
    """AC10 / §5.5 — main() runs BOTH validators (no `or` short-circuit)."""

    def test_compound_failopen_runs_both_validators(self):
        tmp = tempfile.mkdtemp()  # no strategy file -> branch fails open
        try:
            payload = {
                "tool_name": "Bash",
                "tool_input": {
                    "command": 'git checkout -b feat && git commit -m "add thing"'
                },
            }
            out, rc = run_hook(payload, cwd=tmp)
            self.assertEqual(rc, 0)
            data = json.loads(out)
            msg = data.get("systemMessage", "")
            self.assertIn("fail-open", msg)             # branch validator ran
            self.assertIn("Conventional Commits", msg)  # commit validator ALSO ran (not short-circuited)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_valid_branch_bad_commit_still_flags_commit(self):
        tmp = tempfile.mkdtemp()
        write_strategy(tmp, r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$")
        try:
            payload = {
                "tool_name": "Bash",
                "tool_input": {
                    "command": 'git checkout -b feature/ok && git commit -m "add thing"'
                },
            }
            out, rc = run_hook(payload, cwd=tmp)
            data = json.loads(out)
            msg = data.get("systemMessage", "")
            self.assertNotIn("naming convention", msg)  # branch OK -> no branch warning
            self.assertIn("Conventional Commits", msg)   # commit flagged independently
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_both_clean_emits_empty(self):
        tmp = tempfile.mkdtemp()
        write_strategy(tmp, r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$")
        try:
            payload = {
                "tool_name": "Bash",
                "tool_input": {
                    "command": 'git checkout -b feature/ok && git commit -m "feat: ok"'
                },
            }
            out, rc = run_hook(payload, cwd=tmp)
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
```

- [ ] **Step 2: 테스트 실행 → RED 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/plugins/project-init && python3 -m unittest hooks.tests.test_post_tool_use.MainDoubleValidationTest -v`

Expected: `test_compound_failopen_runs_both_validators` → FAIL(현재 `warning = validate_branch(...) or validate_commit(...)` — branch fail-open advisory가 truthy → commit 검증 short-circuit → `Conventional Commits` 부재). 나머지 둘 → PASS(회귀 락).

- [ ] **Step 3: `main()` 이중 검증 구현**

현재 `main()` 내부 (line 176-183):

```python
    command = tool_input.get("command", "")

    # Try branch validation first, then commit validation
    warning = validate_branch(command) or validate_commit(command)

    if warning:
        print(json.dumps({"systemMessage": warning}))
    else:
        print(json.dumps({}))
```

를 아래로 교체:

```python
    command = tool_input.get("command", "")

    # Run BOTH validators (no short-circuit): a branch warning must not
    # suppress commit validation on compound commands (§5.5).
    warnings = [w for w in (validate_branch(command), validate_commit(command)) if w]

    if warnings:
        print(json.dumps({"systemMessage": "\n\n".join(warnings)}))
    else:
        print(json.dumps({}))
```

- [ ] **Step 4: 전체 테스트 실행 → GREEN 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/plugins/project-init && python3 -m unittest hooks.tests.test_post_tool_use -v`

Expected: PASS (전 클래스). 이 시점에서 §7 매트릭스 전부 커버 — AC1, AC2, AC3, AC4, AC5, AC7, AC10 잠금(AC8은 이 하니스가 green인 것 자체).

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness
git add plugins/project-init/hooks/post-tool-use.py plugins/project-init/hooks/tests/test_post_tool_use.py
git commit -m "fix(project-init): run branch + commit validators for compound commands

main()의 or short-circuit 제거 → 두 검증기 무조건 실행+concatenate.
F1 fail-open이 compound 명령에서 commit 검증을 항상 건너뛰던 빈도-증가 회귀
봉쇄(reviewer e65cae85). advisory·non-blocking 성격 불변. AC10 잠금.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 6: 워크트리 브랜치 확인**

Run: `git branch --show-current`
Expected: `feature/git-strategy-faithfulness`.

---

## Task 4: F3 — trunk 템플릿 Pattern B doc-only 정직화

**Files:**
- Modify: `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/plugins/project-init/templates/trunk-based/branch-strategy.md` (Pattern B 노트 line 88 + 코드 블록 line 90-95)

**Interfaces:**
- Consumes: 없음(코드 무관, doc-only).
- Produces: `release/*` backport 안내가 kill-switch 우회 없이, hook의 non-blocking·다중-줄 advisory 성격을 정직히 설명.

- [ ] **Step 1: Pattern B Note 블록 교체 (kill-switch 우회 제거)**

`templates/trunk-based/branch-strategy.md` 의 현재 line 88 (Note blockquote):

```markdown
> **Note:** `release/*` 브랜치는 본 strategy의 regex (`^(feature|fix)/...`) 스코프 밖이라 project-init hook이 거부한다. 예외적 1회 작업이므로 kill switch로 우회: `DEVBREW_DISABLE_PROJECT_INIT=1 git checkout -b release/v1.x`.
```

를 아래로 교체:

```markdown
> **Note:** `release/*` 브랜치는 본 strategy의 regex(`^(feature|fix)/…`) 스코프 밖이라 project-init hook이 **advisory 경고**(허용 prefix `feature`/`fix`를 제시하는 다중 줄 메시지 — 이 전략엔 관용 없는 예외)를 냅니다. 단, project-init hook은 **non-blocking**(PostToolUse advisory)이라 브랜치 생성을 **차단하지 않습니다** — 의도된 backport 예외이므로 경고를 무시하고 진행하세요. hook 전체를 끄지 마세요(commit 검증까지 함께 꺼집니다).
```

- [ ] **Step 2: 코드 블록 교체 (kill-switch env prefix 제거)**

현재 코드 블록 line 90-95 영역:

```bash
# 1. trunk에서 release 브랜치 cut (1회만, kill switch 사용)
git checkout main
git pull origin main
DEVBREW_DISABLE_PROJECT_INIT=1 git checkout -b release/v1.x
git push -u origin release/v1.x
```

를 아래로 교체 (주석 문구 + `git checkout -b` 줄에서 env prefix 제거):

```bash
# 1. trunk에서 release 브랜치 cut (1회만; hook advisory 경고는 무시하고 진행)
git checkout main
git pull origin main
git checkout -b release/v1.x
git push -u origin release/v1.x
```

(line 97 이하 `# 2.`/`# 3.` 블록과 cherry-pick 흐름은 불변.)

- [ ] **Step 3: doc-only 검증 (grep — kill-switch 우회 부재 + non-blocking 명시)**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness
grep -n "DEVBREW_DISABLE_PROJECT_INIT" plugins/project-init/templates/trunk-based/branch-strategy.md; echo "exit=$?"
grep -n "non-blocking" plugins/project-init/templates/trunk-based/branch-strategy.md
```
Expected: 첫 grep은 매치 0줄 + `exit=1`(kill-switch 우회 안내 완전 제거). 둘째 grep은 새 Note의 `non-blocking` 매치 ≥1줄.

- [ ] **Step 4: docs-lint 회귀 없음 확인 (템플릿은 lint 대상 아님이지만 안전 확인)**

Run: `cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/plugins/project-init && python3 -m unittest hooks.tests.test_docs_lint 2>&1 | tail -3`
Expected: OK.

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness
git add plugins/project-init/templates/trunk-based/branch-strategy.md
git commit -m "docs(project-init): honest non-blocking note in trunk Pattern B (F3)

release/* backport 안내에서 DEVBREW_DISABLE_PROJECT_INIT=1 kill-switch
우회를 제거하고, hook이 non-blocking advisory(다중 줄)임을 정직히 설명.
hook 전체를 끄면 commit 검증까지 꺼진다는 경고 추가. AC6 잠금.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 6: 워크트리 브랜치 확인**

Run: `git branch --show-current`
Expected: `feature/git-strategy-faithfulness`.

---

## Task 5: 버전 bump + CHANGELOG + README 동기화

**Files:**
- Modify: `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/plugins/project-init/.claude-plugin/plugin.json` (version)
- Modify: `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/plugins/project-init/CHANGELOG.md` ([1.7.0] 엔트리)
- Modify: `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/plugins/project-init/README.md` ("## 설치된 Hook" post-tool-use 줄 + tree 주석)

**Interfaces:**
- Consumes: Task 1-4의 동작 변경(CHANGELOG/README가 서술하는 대상).
- Produces: plugin cache key invalidation (1.7.0) + 사용자-facing 문서 동기화.

- [ ] **Step 1: plugin.json version bump**

`.claude-plugin/plugin.json` 의 `"version": "1.6.0",` 를 `"version": "1.7.0",` 로 변경. (다른 필드 불변.)

- [ ] **Step 2: CHANGELOG [1.7.0] 엔트리 추가**

`CHANGELOG.md` 의 line 8 `## [1.6.0] — 2026-05-31` *바로 앞*에 아래 블록을 삽입:

```markdown
## [1.7.0] — 2026-07-05

### Changed

- **`hooks/post-tool-use.py` enforcement가 선택된 git 전략에 충실해짐** — 브랜치 검증 폴백이 전략 미선언 시 GitHub-Flow 패턴(`^(feature|fix)/…`)을 단정하던 것을 **loud-advisory fail-open**으로 교체. `get_branch_pattern()`의 반환 계약이 `re.Pattern` → `Optional[re.Pattern]`로 바뀌어, 전략 파일 부재·`` ```regex `` 블록 부재·malformed regex·빈/공백-only regex 블록의 넷을 모두 `None`(검증 생략 + discoverable advisory)으로 통일. Git Flow의 `release/*`·`hotfix/*`가 더는 silent 거부되지 않는다.
- 위반 브랜치 교정 제안이 **활성 패턴에서 파생**(`derive_prefixes()`) — 항상 `feature/<name>`을 제안하던 하드코딩 제거. Git Flow에서 `hotfix-login` 오타에 허용 prefix(`feature, fix, release, hotfix`) 목록과 `git branch -m <prefix>/…` 플레이스홀더를 제시. exotic regex(inline flags `(?i)`·nested group·리터럴 접두)는 `docs/git-workflow/branch-strategy.md` 참조로 강등.
- `main()`이 branch·commit 검증기를 **둘 다 실행**하고 경고를 concatenate — 기존 `or` short-circuit이 compound 명령(`git checkout -b … && git commit -m …`)에서 commit 검증을 건너뛰던 회귀를 봉쇄. advisory·non-blocking 성격 불변.
- `templates/trunk-based/branch-strategy.md` Pattern B 노트에서 `DEVBREW_DISABLE_PROJECT_INIT=1` kill-switch 우회 안내 제거 — hook이 non-blocking advisory임을 정직히 설명(`release/*` backport는 경고를 무시하고 진행; hook 전체를 끄면 commit 검증까지 함께 꺼짐).

### Removed

- `DEFAULT_BRANCH_PATTERN` 상수 완전 제거 — fail-open이 `None`을 반환하므로 GitHub-Flow 디폴트 폴백이 dead code.

### Added

- `hooks/tests/test_post_tool_use.py` — `post-tool-use.py`의 첫 테스트 하니스(`unittest`, `importlib` 로드). F1 fail-open(부재/regex-less/malformed/빈-블록)·F1 회귀 락(`DEFAULT_BRANCH_PATTERN` 부재)·F2 파생(`(?i)` 오파싱 방지 포함)·`main()` 이중 검증·보존 동작(kill switch·non-Bash·malformed JSON·Conventional Commits) 커버.

### Rationale

- 감사 결과 3전략 지원 설계 자체는 건전하나 enforcement 계층이 세 지점에서 미선택 GitHub Flow를 단정하는 전략-불충실 버그였다(brief §1 root cause). "조용히 GitHub Flow로 검증"보다 "시끄럽게 검증 생략"이 fail-open 원칙에 충실. merge/base-branch 런타임 강제(F4/F5)는 "harness lightness — trust the model"로 명시 defer.
```

- [ ] **Step 3: README "## 설치된 Hook" post-tool-use 줄 동기화**

`README.md` 의 현재 line 81:

```markdown
- **`PostToolUse` (Bash matcher) — `post-tool-use.py`**: 브랜치 명·커밋 메시지 검증. **왜 hook인가?**: 검증은 모델 attention 여부와 무관하게 모든 Bash invocation에 발화해야 한다. skill은 모델이 invoke하는 단위라 action 레이어에서의 결정적 실행을 보장하지 못함.
```

를 아래로 교체:

```markdown
- **`PostToolUse` (Bash matcher) — `post-tool-use.py`**: 브랜치 명·커밋 메시지 검증 (advisory, non-blocking). 브랜치 검증은 `docs/git-workflow/branch-strategy.md`의 선언된 전략 패턴을 런타임에 읽어 수행하며, 전략 미선언(파일/`` ```regex `` 블록 부재·malformed·빈 블록)이면 GitHub Flow를 단정하지 않고 **loud advisory로 검증을 건너뛴다**(fail-open, v1.7.0). 교정 제안은 활성 패턴에서 파생된 prefix를 제시한다. **왜 hook인가?**: 검증은 모델 attention 여부와 무관하게 모든 Bash invocation에 발화해야 한다. skill은 모델이 invoke하는 단위라 action 레이어에서의 결정적 실행을 보장하지 못함.
```

- [ ] **Step 4: README architecture tree 주석 동기화**

`README.md` 의 현재 line 16:

```markdown
│   ├── post-tool-use.py             # 브랜치 명명 + 커밋 메시지 검증기 (Bash matcher)
```

를 아래로 교체 (tree 정렬 유지):

```markdown
│   ├── post-tool-use.py             # 브랜치(fail-open advisory) + 커밋 검증기 (Bash matcher)
```

그리고 line 19 근처 tree의 tests 항목에 신규 파일이 반영되도록, 현재:

```markdown
│       ├── test_docs_lint.py        # 60+ Python stdlib unittest (charter rule 포함)
```

바로 아래에 한 줄 추가:

```markdown
│       ├── test_post_tool_use.py    # v1.7.0 — post-tool-use fail-open/F2/main 검증
```

(tree의 다른 줄 정렬·주석 불변. 실제 파일 정렬 열이 위 예시와 다르면 인접 줄의 `#` 열에 맞춰 공백 조정.)

- [ ] **Step 5: JSON 유효성 + 문서 확인**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness
python3 -c "import json; print(json.load(open('plugins/project-init/.claude-plugin/plugin.json'))['version'])"
grep -n "## \[1.7.0\]" plugins/project-init/CHANGELOG.md
grep -n "fail-open" plugins/project-init/README.md
```
Expected: `1.7.0` 출력; CHANGELOG에 `## [1.7.0]` 매치 1줄; README에 `fail-open` 매치 ≥1줄.

- [ ] **Step 6: 전체 테스트 최종 실행 (회귀 없음 최종 확인)**

Run: `cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness/plugins/project-init && python3 -m unittest hooks.tests.test_post_tool_use hooks.tests.test_docs_lint 2>&1 | tail -5`
Expected: OK (두 하니스 전부 green).

- [ ] **Step 7: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+git-strategy-faithfulness
git add plugins/project-init/.claude-plugin/plugin.json plugins/project-init/CHANGELOG.md plugins/project-init/README.md
git commit -m "chore(project-init): bump to 1.7.0 + CHANGELOG + README sync

git-strategy faithfulness (F1 fail-open + F2 파생 제안 + F3 doc-only +
main 이중 검증). enforcement surface 변경 → minor. AC9 잠금.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 8: 워크트리 브랜치 확인 + PR 준비**

Run: `git branch --show-current && git log --oneline -6`
Expected: `feature/git-strategy-faithfulness`; 5 신규 commit(F1 → F2 → main → F3 → bump) + design commit들.

이후 `/qg` (Review + Runtime 게이트) 통과 → PR 생성(merge, **rebase 금지**) → merge.

---

## Global Verification (모든 task 완료 후)

- [ ] `cd .../plugins/project-init && python3 -m unittest hooks.tests.test_post_tool_use -v` → 전 케이스 green.
- [ ] `python3 -m unittest hooks.tests.test_docs_lint` → OK (무회귀).
- [ ] `plugins/project-init/hooks/tests/smoke.sh` 실행 → 무회귀(docs-lint smoke, post-tool-use 변경과 독립).
- [ ] `/qg` — Review 게이트(security-reviewer + codex 모델 다양성) + Runtime 게이트.
- [ ] 병합 전: 워크트리 clean tree(`git status`), branch = `feature/git-strategy-faithfulness`, plugin.json = 1.7.0.

---

## Self-Review (spec 대조 — 계획 작성자가 직접 수행)

**Spec coverage (§8 AC1–AC10):**

| AC | 커버 task | 근거 |
|---|---|---|
| AC1 (fail-open incl 빈-블록) | Task 1 | `F1FailOpenTest` a–e |
| AC2 (`DEFAULT_BRANCH_PATTERN` 제거) | Task 1 | `F1RegressionLockTest` |
| AC3 (선언 regex 존중, release/* 통과) | Task 1 | `test_declared_gitflow_pattern_respected` |
| AC4 (파생 prefix, feature/ 하드코딩 없음) | Task 2 | `test_gitflow_violation_...` |
| AC5 (exotic → [] incl `(?i)`) | Task 2 | `DerivePrefixesTest.test_inline_flag_group_not_misparsed` 외 |
| AC6 (trunk doc + non-blocking 다중-줄) | Task 4 | Note 재작성 + grep 검증 |
| AC7 (commit/kill-switch/non-Bash/malformed-JSON 무회귀) | Task 1 | `PreservedBehaviorTest` |
| AC8 (신규 테스트 green) | Task 1–3 | 하니스 누적 green |
| AC9 (plugin.json 1.7.0 + CHANGELOG + README) | Task 5 | 세 파일 sync |
| AC10 (compound 두 검증기) | Task 3 | `MainDoubleValidationTest` |

모든 AC에 task 매핑 존재 — 갭 없음.

**Placeholder scan:** "TBD"/"적절히 처리"/"위와 유사"/코드 없는 test 스텝 없음 — 전 코드 스텝이 완전한 code block. 통과.

**Type consistency:** `get_branch_pattern() -> Optional[re.Pattern]`(Task 1) → `validate_branch`가 `if pattern is None`으로 소비(Task 1) → 아니면 `derive_prefixes(pattern)`(Task 2)에 전달. `derive_prefixes(pattern) -> list[str]`을 `if prefixes:`로 소비. `run_hook`/`write_strategy` 시그니처가 Task 1 정의와 Task 2·3 호출에서 일치. `main()`이 `validate_branch`/`validate_commit` 반환(둘 다 `Optional[str]`)을 list comprehension으로 필터 — 일관. 통과.
