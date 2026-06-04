# spec-distill cancel-review + per-doc suppression Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill 리뷰 상태머신에 per-doc·session-scoped `suppressed_paths` 집합을 추가해, 리뷰 완료(approve) 후 또는 중단 요청 후에 같은 `-design.md`를 재편집해도 reviewing-spec가 다시 dispatch되지 않게 한다.

**Architecture:** 취소(`/spec-distill:cancel-review`, 사용자)와 완료(`approve_handoff.sh`)가 같은 `suppressed_paths` 집합에 기록하고, PostToolUse `spec-write-validator.py`가 arm(`write_state`) 직전 그 집합을 조회해 일치 시 arm을 skip한다. 정규화·pending strip·suppress 로직은 신규 `scripts/suppress_state.py` **단일 소스**에만 존재하며, bash 호출자·cancel_review·validator는 모두 raw 경로를 넘기고 정규화를 위임한다.

**Tech Stack:** Python 3 (stdlib only — `re`, `pathlib`, `subprocess`), Bash, `unittest` (python 테스트), shell 테스트 하니스. 외부 의존성 없음.

---

## ⚠ 실행 환경 규약 (모든 task에 적용)

- **워크트리에서 구현.** 구현은 `main`에서 분기한 워크트리 `feature/spec-distill-cancel-suppress`에서 진행한다 (사용자 명시 + 설계 C8). Task 1이 워크트리를 만든다.
- **경로 규율 (subagent drift 차단).** 워크트리 루트는 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/spec-distill-cancel-suppress` 다 (이하 `$WT`). 이 plan의 *모든 상대 경로는 `$WT` 기준*이다. 절대 경로로 Edit/Write/commit할 때는 **반드시 `$WT` 절대 경로**를 쓰고, main repo 절대 경로(`/Users/jeonghokim/Downloads/devbrew/...`)를 쓰지 말 것. 매 commit 후 `git -C "$WT" branch --show-current` 가 `feature/spec-distill-cancel-suppress` 인지 검증한다.
- **보안-민감 파일.** `suppress_state.py`(kill switch 보유)·`spec-write-validator.py`(게이트)는 보안 컨트롤이다 (CLAUDE.md "kill switch는 보안 컨트롤"). persona/게이트 약화 없이 추가만 한다.
- **테스트 실행.** python 테스트는 `python3 -m unittest discover`로만 (직접 실행은 vacuous — reference 메모). shell 테스트는 repo(=`$WT`) 루트에서 `bash <path>`.
- **버전 bump.** `plugins/spec-distill/` 를 건드리는 PR이므로 같은 PR에서 `plugin.json` 0.13.0 → 0.14.0 + CHANGELOG + README 동기화 (Task 7).

---

## File Structure

신규 (4):
- `plugins/spec-distill/scripts/suppress_state.py` — 정규화·strip·suppress 단일 소스. Python API + thin CLI.
- `plugins/spec-distill/scripts/cancel_review.py` — `/spec-distill:cancel-review` 진입점. 인자 해석 + 정책만, 로직은 suppress_state에 위임.
- `plugins/spec-distill/commands/cancel-review.md` — 짧은 명령형 커맨드 래퍼.
- `plugins/spec-distill/tests/test_cancel_review.py` — suppress_state 단위 + cancel_review 통합 테스트.

편집 (8):
- `plugins/spec-distill/hooks/spec-write-validator.py` — `write_state` 직전 `is_suppressed` 게이트 + inline strip → `suppress_state.strip_pending`.
- `plugins/spec-distill/scripts/approve_handoff.sh` — 세션 dir `rm -rf` → `suppress_state.py add`.
- `plugins/spec-distill/.claude-plugin/plugin.json` — 0.14.0.
- `plugins/spec-distill/CHANGELOG.md` — `[0.14.0]` 항목.
- `plugins/spec-distill/README.md` — Flow·Hooks·Principles·Kill switches.
- `plugins/spec-distill/tests/test_spec_write_validator.sh` — AC9/AC10/AC11/AC18 케이스.
- `plugins/spec-distill/tests/test_approve_handoff.sh` — AC12/AC13 (dir 보존 + suppress 기록).
- `plugins/spec-distill/tests/test_readme_sync.sh` — 0.14.0 + `cancel-review` 동기화.

무변경 (재확인만): `hooks/review-dispatch.py`(Stop — pending 안 생기므로 자연 no-op), `hooks/pending-review-reminder.py`(UserPromptSubmit — 동), `hooks/session-end-cleanup.py`(AC15 — 기존 dir 삭제가 세션 간 누출 차단).

---

## Task 1: 워크트리 생성 + baseline 캡처 + 설계문서·plan 커밋

**Files:**
- Create (worktree): `$WT` (= `.claude/worktrees/spec-distill-cancel-suppress`)
- Commit into worktree: `docs/superpowers/specs/2026-06-04-spec-distill-cancel-suppress-design.md`, `docs/superpowers/plans/2026-06-05-spec-distill-cancel-suppress.md`

- [ ] **Step 1: main 분기 워크트리 생성**

설계문서·plan은 현재 main 작업트리에 *untracked*로 존재한다 (커밋 안 됨). untracked 파일은 새 워크트리로 따라가지 않으므로 워크트리 생성 후 명시적으로 복사한다.

```bash
cd /Users/jeonghokim/Downloads/devbrew
git worktree add -b feature/spec-distill-cancel-suppress \
  .claude/worktrees/spec-distill-cancel-suppress main
```
Expected: `Preparing worktree (new branch 'feature/spec-distill-cancel-suppress')` + `HEAD is now at d09e79f ...`.

- [ ] **Step 2: 설계문서 + plan을 워크트리로 복사 후 커밋**

`cp`(Write 아님)로 가져오므로 PostToolUse hook이 fire하지 않는다 (재arm 없음).

```bash
WT=/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/spec-distill-cancel-suppress
mkdir -p "$WT/docs/superpowers/specs" "$WT/docs/superpowers/plans"
cp /Users/jeonghokim/Downloads/devbrew/docs/superpowers/specs/2026-06-04-spec-distill-cancel-suppress-design.md \
   "$WT/docs/superpowers/specs/"
cp /Users/jeonghokim/Downloads/devbrew/docs/superpowers/plans/2026-06-05-spec-distill-cancel-suppress.md \
   "$WT/docs/superpowers/plans/"
git -C "$WT" add docs/superpowers/specs/2026-06-04-spec-distill-cancel-suppress-design.md \
                 docs/superpowers/plans/2026-06-05-spec-distill-cancel-suppress.md
git -C "$WT" commit -m "docs(spec-distill): cancel-review + suppression design & plan (v0.14.0)"
git -C "$WT" branch --show-current   # MUST print: feature/spec-distill-cancel-suppress
```
Expected: 1 commit; branch 검증이 `feature/spec-distill-cancel-suppress` 출력.

- [ ] **Step 3: baseline 테스트 green 캡처**

작업 전 기존 스위트가 green인지 확인 (회귀 판정 기준선 — qg pre-existing reds 메모 참조).

```bash
cd "$WT"
python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_*.py' 2>&1 | tail -5
for t in test_spec_write_validator.sh test_approve_handoff.sh test_readme_sync.sh; do
  echo "=== $t ==="; bash "plugins/spec-distill/tests/$t" 2>&1 | tail -3
done
```
Expected: python `OK`; 각 shell 테스트 `summary: N passed, 0 failed` / `PASSED` / `Fail: 0`. 만약 사전 red가 있으면 기록만 하고 (작업 무관 red는 무시) 진행.

---

## Task 2: `suppress_state.py` — 정규화·strip·suppress 단일 소스 (TDD)

**Files:**
- Create: `plugins/spec-distill/scripts/suppress_state.py`
- Test: `plugins/spec-distill/tests/test_cancel_review.py` (`TestSuppressState` 클래스 — 직접 import 단위)

- [ ] **Step 1: 실패 테스트 작성 (`TestSuppressState`)**

`$WT/plugins/spec-distill/tests/test_cancel_review.py` 를 새로 만들고 아래 단위 클래스를 넣는다 (Task 3에서 같은 파일에 `TestCancelReview`를 *추가*한다 — 이 Step에서는 헤더 + `TestSuppressState`만).

```python
"""spec-distill cancel-review + suppress_state contract (v0.14.0).

TestSuppressState: 단일 소스 헬퍼 직접 import 단위 (AC4/AC11/AC14/AC17).
TestCancelReview: cancel_review.py subprocess 통합 (AC1–AC8, AC19).

실행 (repo root):
  python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_cancel_review.py'
"""
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = (Path(__file__).resolve().parent.parent / "scripts").resolve()
HOOKS = (Path(__file__).resolve().parent.parent / "hooks").resolve()
CANCEL = SCRIPTS / "cancel_review.py"
sys.path.insert(0, str(SCRIPTS))
sys.path.insert(0, str(HOOKS))
import suppress_state  # noqa: E402

PREFIX = "docs/superpowers/specs/"
DOC_A = PREFIX + "2026-01-01-doc-a-design.md"
DOC_B = PREFIX + "2026-01-01-doc-b-design.md"


class TestSuppressState(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.sf = self.tmp / "sid12345" / "state.local.md"

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_canonical_key_strips_prefix(self):
        self.assertEqual(suppress_state.canonical_key("/abs/wt/" + DOC_A), DOC_A)
        self.assertEqual(suppress_state.canonical_key(DOC_A), DOC_A)

    def test_canonical_key_out_of_scope_none(self):
        self.assertIsNone(suppress_state.canonical_key("/x/README.md"))
        self.assertIsNone(suppress_state.canonical_key(""))

    def test_add_idempotent_single_entry(self):  # AC4
        suppress_state.add(self.sf, "/wt/" + DOC_A)
        suppress_state.add(self.sf, DOC_A)
        self.assertEqual(
            suppress_state.suppressed_keys(self.sf.read_text()), [DOC_A]
        )

    def test_remove(self):
        suppress_state.add(self.sf, DOC_A)
        suppress_state.remove(self.sf, DOC_A)
        self.assertEqual(suppress_state.suppressed_keys(self.sf.read_text()), [])

    def test_is_suppressed(self):
        self.assertFalse(suppress_state.is_suppressed(self.sf, DOC_A))
        suppress_state.add(self.sf, DOC_A)
        self.assertTrue(suppress_state.is_suppressed(self.sf, "/wt/" + DOC_A))

    def test_strip_pending_preserves_suppressed(self):  # AC14 / C3
        body = (
            "---\nsession_id: s\n---\n\n"
            "pending_review:\n  path: " + DOC_A + "\n  mode: design\n"
            "  worktree_path: /x\n  triggered_at: t\n\n"
            "suppressed_paths:\n  - " + DOC_B + "\n"
        )
        self.assertEqual(suppress_state.pending_path(body), DOC_A)
        self.assertIn(DOC_B, suppress_state.suppressed_keys(body))
        stripped = suppress_state.strip_pending(body)
        self.assertNotIn("pending_review:", stripped)
        self.assertIn("suppressed_paths:", stripped)
        self.assertIn(DOC_B, stripped)

    def test_suppress_path_same_key_strips_pending(self):  # AC1 core
        self.sf.parent.mkdir(parents=True)
        self.sf.write_text(
            "---\nsession_id: sid12345\n---\n\n"
            "pending_review:\n  path: /wt/" + DOC_A + "\n  mode: design\n"
            "  worktree_path: /wt\n  triggered_at: t\n"
        )
        suppress_state.suppress_path(self.sf, "/wt/" + DOC_A)
        body = self.sf.read_text()
        self.assertNotIn("pending_review:", body)
        self.assertEqual(suppress_state.suppressed_keys(body), [DOC_A])

    def test_suppress_path_different_key_preserves_pending(self):  # AC19 unit
        self.sf.parent.mkdir(parents=True)
        self.sf.write_text(
            "---\nsession_id: sid12345\n---\n\n"
            "pending_review:\n  path: /wt/" + DOC_A + "\n  mode: design\n"
            "  worktree_path: /wt\n  triggered_at: t\n"
        )
        suppress_state.suppress_path(self.sf, "/wt/" + DOC_B)
        body = self.sf.read_text()
        self.assertIn("pending_review:", body)
        self.assertEqual(suppress_state.pending_path(body), "/wt/" + DOC_A)
        self.assertEqual(suppress_state.suppressed_keys(body), [DOC_B])

    def test_no_prefix_slice_outside_suppress_state(self):  # AC17
        root = Path(__file__).resolve().parent.parent
        for rel in ("scripts/cancel_review.py", "scripts/approve_handoff.sh"):
            txt = (root / rel).read_text()
            self.assertNotIn(
                "docs/superpowers/specs/", txt,
                f"{rel} must delegate normalization to suppress_state (AC17)",
            )
```

- [ ] **Step 2: 실패 확인**

Run: `cd "$WT" && python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_cancel_review.py' -v`
Expected: `ModuleNotFoundError: No module named 'suppress_state'` (아직 미생성) — collection/import 단계 실패.

- [ ] **Step 3: `suppress_state.py` 구현**

`$WT/plugins/spec-distill/scripts/suppress_state.py`:

```python
#!/usr/bin/env python3
"""spec-distill suppression state — per-doc auto-review muting의 단일 소스 (v0.14.0).

두 리뷰 gap을 하나의 session-scoped `suppressed_paths` 집합으로 닫는다:
  (A) approve 후 같은 design 문서 재편집 → 재arm
  (B) 사용자 중단 요청 후에도 재arm
취소(cancel_review.py) + 완료(approve_handoff.sh)가 같은 집합에 기록하고,
PostToolUse validator가 arm 직전 조회한다.

정규화·pending strip·suppress가 이 파일에만 존재한다(C4/AC17) — bash 호출자와
cancel_review·validator는 raw 경로를 넘기고 정규화를 위임한다.

Python API: canonical_key, pending_path, suppressed_keys, strip_pending,
            state_file_for, is_suppressed, add, remove, suppress_path
CLI (bash 호출자): python3 suppress_state.py {add|remove|is-suppressed} <sid> <raw_path>
  - add: suppress_path (키 add + 같은-키 pending strip). 멱등.
  - remove: 억제 해제. 멱등.
  - is-suppressed: exit 0(suppressed) / 1(아님).

Kill switch (CLI defense-in-depth — API 호출자는 상위에서 이미 검사):
  DEVBREW_DISABLE_SPEC_DISTILL=1 → no-op.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
HOOKS_DIR = SCRIPT_DIR.parent / "hooks"
sys.path.insert(0, str(HOOKS_DIR))
from state_path import state_root, SESSION_PATTERN  # noqa: E402

PREFIX = "docs/superpowers/specs/"

PENDING_RE = re.compile(r"^pending_review:\n(?:  [^\n]*\n)*", re.MULTILINE)
SUPPRESSED_RE = re.compile(r"^suppressed_paths:\n((?:  - [^\n]+\n)*)", re.MULTILINE)


def canonical_key(raw_path: str) -> str | None:
    """경로에서 PREFIX 이후 substring. 스코프 밖이면 None.

    worktree·절대·상대 경로 무관하게 같은 문서가 같은 키로 매핑(C4).
    정규화는 이 함수에만 존재 — 다른 파일은 raw 경로 위임(AC17).
    """
    if not raw_path:
        return None
    idx = raw_path.find(PREFIX)
    if idx < 0:
        return None
    return raw_path[idx:]


def pending_path(body: str) -> str | None:
    """state body의 pending_review.path 값(저장된 그대로). 없으면 None."""
    m = PENDING_RE.search(body)
    if not m:
        return None
    for line in m.group(0).splitlines():
        ls = line.strip()
        if ls.startswith("path:"):
            return ls[len("path:"):].strip()
    return None


def suppressed_keys(body: str) -> list[str]:
    """state body의 suppressed_paths 항목(정규화 키들)."""
    m = SUPPRESSED_RE.search(body)
    if not m:
        return []
    keys: list[str] = []
    for line in m.group(1).splitlines():
        ls = line.strip()
        if ls.startswith("- "):
            keys.append(ls[2:].strip())
    return keys


def strip_pending(body: str) -> str:
    """pending_review 블록 제거. suppressed_paths(0-indent 헤더)는 보존(C3).

    validator의 write_state가 import해 inline re.sub 중복을 제거한다.
    """
    return PENDING_RE.sub("", body)


def _strip_suppressed(body: str) -> str:
    return SUPPRESSED_RE.sub("", body)


def _render_suppressed(keys: list[str]) -> str:
    return "suppressed_paths:\n" + "".join(f"  - {k}\n" for k in keys)


def state_file_for(sid: str) -> Path:
    """sid → state.local.md 경로 단일 해석(호출자 중복 제거).

    state_path.state_root()를 래핑 — 저장소 위치 변경(NG5 redesign) 시
    이 한 곳만 갱신하면 되는 single update point.
    """
    return state_root() / sid / "state.local.md"


def _read_or_init(state_file: Path) -> str:
    if state_file.exists():
        try:
            return state_file.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            print(
                f"[spec-distill] suppress_state: state unreadable, re-init: {exc}",
                file=sys.stderr,
            )
    sid = state_file.parent.name
    return f"---\nsession_id: {sid}\n---\n\n"


def _commit(state_file: Path, body: str, keys: list[str]) -> None:
    body = _strip_suppressed(body).rstrip()
    if keys:
        body = body + "\n\n" + _render_suppressed(keys).rstrip()
    state_file.parent.mkdir(parents=True, exist_ok=True)
    state_file.write_text(body + "\n", encoding="utf-8")


def is_suppressed(state_file: Path, raw_path: str) -> bool:
    key = canonical_key(raw_path)
    if key is None or not state_file.exists():
        return False
    try:
        body = state_file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return False
    return key in suppressed_keys(body)


def add(state_file: Path, raw_path: str) -> None:
    """정규화 키를 suppressed_paths에 멱등 추가. 파일 부재 시 생성.

    pending_review는 건드리지 않는다(strip은 suppress_path/호출자가 결정).
    """
    key = canonical_key(raw_path)
    if key is None:
        return
    body = _read_or_init(state_file)
    keys = suppressed_keys(body)
    if key not in keys:
        keys.append(key)
    _commit(state_file, body, keys)


def remove(state_file: Path, raw_path: str) -> None:
    """정규화 키를 suppressed_paths에서 멱등 제거(재리뷰 재개)."""
    key = canonical_key(raw_path)
    if key is None or not state_file.exists():
        return
    try:
        body = state_file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return
    keys = suppressed_keys(body)
    if key not in keys:
        return
    keys.remove(key)
    _commit(state_file, body, keys)


def suppress_path(state_file: Path, raw_path: str) -> bool:
    """키 add + pending이 *같은 키*일 때만 strip(다른 문서 pending 보존 — AC19).

    CLI `add`(approve_handoff) + cancel_review의 explicit-path/현재-pending이 공유.
    스코프 밖 경로면 False(호출자가 advisory).
    """
    key = canonical_key(raw_path)
    if key is None:
        return False
    add(state_file, raw_path)
    try:
        body = state_file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return True
    pend = pending_path(body)
    if pend is not None and canonical_key(pend) == key:
        state_file.write_text(strip_pending(body).rstrip() + "\n", encoding="utf-8")
    return True


def main(argv: list[str]) -> int:
    if os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1":
        print(
            "[spec-distill] suppress_state: DEVBREW_DISABLE_SPEC_DISTILL=1 — no-op",
            file=sys.stderr,
        )
        return 0
    if len(argv) < 4:
        print(
            "usage: suppress_state.py {add|remove|is-suppressed} <sid> <raw_path>",
            file=sys.stderr,
        )
        return 2
    cmd, sid, raw_path = argv[1], argv[2], argv[3]
    if not SESSION_PATTERN.match(sid):
        trunc = sid[:32] + ("..." if len(sid) > 32 else "")
        print(
            f"[spec-distill] suppress_state: session_id rejected: '{trunc}'",
            file=sys.stderr,
        )
        return 2
    sf = state_file_for(sid)
    if cmd == "add":
        if not suppress_path(sf, raw_path):
            print(
                f"[spec-distill] suppress_state: '{raw_path}' out of scope "
                f"(no {PREFIX}) — no-op",
                file=sys.stderr,
            )
            return 1
        return 0
    if cmd == "remove":
        if canonical_key(raw_path) is None:
            print(
                f"[spec-distill] suppress_state: '{raw_path}' out of scope — no-op",
                file=sys.stderr,
            )
            return 1
        remove(sf, raw_path)
        return 0
    if cmd == "is-suppressed":
        return 0 if is_suppressed(sf, raw_path) else 1
    print(f"[spec-distill] suppress_state: unknown subcommand '{cmd}'", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **Step 4: 통과 확인 + 실행권한**

```bash
cd "$WT" && chmod +x plugins/spec-distill/scripts/suppress_state.py
python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_cancel_review.py' -v
```
Expected: `TestSuppressState` 10 tests `OK` (`TestCancelReview`는 Task 3에서 추가).

- [ ] **Step 5: 커밋**

```bash
cd "$WT"
git add plugins/spec-distill/scripts/suppress_state.py plugins/spec-distill/tests/test_cancel_review.py
git commit -m "feat(spec-distill): suppress_state single-source for per-doc review suppression"
git branch --show-current   # MUST: feature/spec-distill-cancel-suppress
```

---

## Task 3: `cancel_review.py` — `/spec-distill:cancel-review` 진입점 (TDD)

**Files:**
- Create: `plugins/spec-distill/scripts/cancel_review.py`
- Test: `plugins/spec-distill/tests/test_cancel_review.py` (`TestCancelReview` 클래스 추가)

- [ ] **Step 1: 실패 테스트 추가 (`TestCancelReview`)**

`test_cancel_review.py` *끝에* 아래를 추가한다 (`TestSuppressState` 다음).

```python
def run_cancel(args, env_extra=None, cwd=None, sid="tsid1234"):
    env = {**os.environ}
    for k in ("DEVBREW_DISABLE_SPEC_DISTILL", "CLAUDE_CODE_SESSION_ID",
              "DEVBREW_SPEC_DISTILL_SESSION_ID"):
        env.pop(k, None)
    if sid is not None:
        env["DEVBREW_SPEC_DISTILL_SESSION_ID"] = sid
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        ["python3", str(CANCEL)] + args,
        env=env, cwd=cwd, capture_output=True, text=True, timeout=10,
    )


class TestCancelReview(unittest.TestCase):
    SID = "tsid1234"

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        subprocess.run(["git", "init", "-q"], cwd=self.tmp, check=True)
        self.sf = self.tmp / ".claude" / "spec-distill" / self.SID / "state.local.md"

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _seed_pending(self, doc_raw):
        self.sf.parent.mkdir(parents=True, exist_ok=True)
        self.sf.write_text(
            f"---\nsession_id: {self.SID}\n---\n\n"
            f"pending_review:\n  path: {doc_raw}\n  mode: design\n"
            f"  worktree_path: {self.tmp}\n  triggered_at: t\n"
        )

    def test_ac1_cancel_current_pending(self):
        doc = str(self.tmp / DOC_A)
        self._seed_pending(doc)
        cp = run_cancel([], cwd=self.tmp)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        body = self.sf.read_text()
        self.assertNotIn("pending_review:", body)
        self.assertEqual(suppress_state.suppressed_keys(body), [DOC_A])

    def test_ac2_explicit_path_no_pending_creates(self):
        self.assertFalse(self.sf.exists())
        cp = run_cancel([str(self.tmp / DOC_A)], cwd=self.tmp)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        body = self.sf.read_text()
        self.assertEqual(suppress_state.suppressed_keys(body), [DOC_A])
        self.assertNotIn("pending_review:", body)

    def test_ac3_no_pending_no_args_advisory(self):
        cp = run_cancel([], cwd=self.tmp)
        self.assertEqual(cp.returncode, 0)
        self.assertIn("nothing to do", cp.stderr)
        self.assertFalse(self.sf.exists())

    def test_ac4_idempotent(self):
        doc = str(self.tmp / DOC_A)
        run_cancel([doc], cwd=self.tmp)
        run_cancel([doc], cwd=self.tmp)
        self.assertEqual(
            suppress_state.suppressed_keys(self.sf.read_text()), [DOC_A]
        )

    def test_ac5_reset_removes(self):
        doc = str(self.tmp / DOC_A)
        run_cancel([doc], cwd=self.tmp)
        cp = run_cancel(["--reset", doc], cwd=self.tmp)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        self.assertEqual(suppress_state.suppressed_keys(self.sf.read_text()), [])
        cp2 = run_cancel(["--reset", str(self.tmp / DOC_B)], cwd=self.tmp)
        self.assertEqual(cp2.returncode, 0)  # absent-key reset → no-op

    def test_ac6_killswitch(self):
        doc = str(self.tmp / DOC_A)
        self._seed_pending(doc)
        cp = run_cancel(
            [], env_extra={"DEVBREW_DISABLE_SPEC_DISTILL": "1"}, cwd=self.tmp
        )
        self.assertEqual(cp.returncode, 0)
        self.assertIn("no-op", cp.stderr)
        self.assertIn("pending_review:", self.sf.read_text())

    def test_ac7_sid_unresolved(self):
        cp = run_cancel([], cwd=self.tmp, sid=None)
        self.assertEqual(cp.returncode, 1)
        self.assertIn("session_id", cp.stderr)
        self.assertFalse(self.sf.exists())

    def test_ac8_out_of_scope(self):
        cp = run_cancel([str(self.tmp / "README.md")], cwd=self.tmp)
        self.assertEqual(cp.returncode, 1)
        self.assertIn("스코프 밖", cp.stderr)
        self.assertFalse(self.sf.exists())

    def test_ac19_different_doc_pending_preserved(self):
        doc_a = str(self.tmp / DOC_A)
        doc_b = str(self.tmp / DOC_B)
        self._seed_pending(doc_a)
        cp = run_cancel([doc_b], cwd=self.tmp)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        body = self.sf.read_text()
        self.assertIn("pending_review:", body)
        self.assertEqual(suppress_state.pending_path(body), doc_a)
        self.assertEqual(suppress_state.suppressed_keys(body), [DOC_B])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패 확인**

Run: `cd "$WT" && python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_cancel_review.py' -v`
Expected: `TestCancelReview` 케이스들이 `can't open file ... cancel_review.py` / 비-0 returncode로 실패 (`TestSuppressState`는 여전히 통과).

- [ ] **Step 3: `cancel_review.py` 구현**

`$WT/plugins/spec-distill/scripts/cancel_review.py`:

```python
#!/usr/bin/env python3
"""spec-distill /spec-distill:cancel-review — 사용자 주권(P17) 취소·억제 경로 (v0.14.0).

현재(또는 지정) design 문서의 pending_review를 취소하고 그 문서를 세션 동안
재arm에서 억제한다. --reset으로 재활성화. 정규화·strip·suppress는 모두
suppress_state(단일 소스)에 위임 — 이 파일은 인자 해석 + 정책만.

Usage (commands/cancel-review.md가 호출):
  python3 cancel_review.py                # 현재 pending 취소 + 억제
  python3 cancel_review.py <path>         # <path> 억제 (pending이 같은 문서면 함께 취소)
  python3 cancel_review.py --reset <path> # 억제 해제

Kill switch: DEVBREW_DISABLE_SPEC_DISTILL=1 → no-op (AC6).
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
HOOKS_DIR = SCRIPT_DIR.parent / "hooks"
sys.path.insert(0, str(SCRIPT_DIR))
sys.path.insert(0, str(HOOKS_DIR))
import suppress_state  # noqa: E402
from state_path import resolve_session_id  # noqa: E402


def _advise(msg: str) -> None:
    print(f"[spec-distill] cancel-review: {msg}", file=sys.stderr)


def main(argv: list[str]) -> int:
    if os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1":
        _advise("DEVBREW_DISABLE_SPEC_DISTILL=1 — no-op (state 보존)")
        return 0

    args = [a for a in argv[1:] if a and a.strip()]
    reset = False
    target: str | None = None
    if args and args[0] == "--reset":
        reset = True
        if len(args) < 2:
            _advise("--reset 는 <path> 인자가 필요합니다.")
            return 2
        target = args[1]
    elif args:
        target = args[0]

    sid = resolve_session_id()
    if sid is None:
        # resolve_session_id가 이미 loud stderr. 상태 변경 없음(AC7).
        return 1
    sf = suppress_state.state_file_for(sid)

    if reset:
        key = suppress_state.canonical_key(target)
        if key is None:
            _advise(f"'{target}' 스코프 밖({suppress_state.PREFIX} 없음) — no-op (AC8)")
            return 1
        suppress_state.remove(sf, target)
        _advise(f"re-enabled: {key} (suppressed_paths에서 제거, 재리뷰 재개).")
        return 0

    if target is not None:
        key = suppress_state.canonical_key(target)
        if key is None:
            _advise(f"'{target}' 스코프 밖({suppress_state.PREFIX} 없음) — no-op (AC8)")
            return 1
        suppress_state.suppress_path(sf, target)  # 같은-키 pending만 strip(AC19)
        _advise(f"suppressed {key} this session. 재리뷰: --reset {key}")
        return 0

    # 인자 없음 → 현재 pending 취소
    body = ""
    if sf.exists():
        try:
            body = sf.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            _advise(f"state 읽기 실패 — 보존: {exc}")
            return 1
    pend = suppress_state.pending_path(body)
    if pend is None:
        _advise(
            "취소할 pending_review 없음 + <path> 미지정 — nothing to do. "
            "특정 문서 사전 억제는 /spec-distill:cancel-review <path> (AC3)."
        )
        return 0
    suppress_state.suppress_path(sf, pend)
    key = suppress_state.canonical_key(pend) or pend
    _advise(f"cancelled pending review + suppressed {key} this session. 재리뷰: --reset {key}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **Step 4: 통과 확인 + 실행권한**

```bash
cd "$WT" && chmod +x plugins/spec-distill/scripts/cancel_review.py
python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_cancel_review.py' -v
```
Expected: `TestSuppressState` + `TestCancelReview` 전부 `OK`.

- [ ] **Step 5: 커밋**

```bash
cd "$WT"
git add plugins/spec-distill/scripts/cancel_review.py plugins/spec-distill/tests/test_cancel_review.py
git commit -m "feat(spec-distill): /spec-distill:cancel-review command script (cancel + suppress + --reset)"
git branch --show-current
```

---

## Task 4: `commands/cancel-review.md` — 커맨드 래퍼

**Files:**
- Create: `plugins/spec-distill/commands/cancel-review.md`

- [ ] **Step 1: 커맨드 파일 작성**

`$WT/plugins/spec-distill/commands/cancel-review.md` (`interview.md` 포맷 따름):

````markdown
---
description: 진행 중이거나 완료된 design 문서의 spec-distill auto-review를 취소·억제 (또는 --reset으로 재활성화). per-doc·session-scoped. devbrew P17 instantiation.
argument-hint: "[path] | --reset <path>"
---

# /spec-distill:cancel-review

현재(또는 지정한) design 문서의 `pending_review`를 취소하고, 그 문서가 이번 세션
동안 다시 auto-review로 arm되지 않도록 억제합니다. 리뷰 *완료* 후 또는 *중단* 요청
후에도 같은 `-design.md`를 재편집하면 reviewing-spec가 재dispatch되던 문제를 끄는
사용자 주권(P17) 경로입니다. cost_class: low.

## Step 1: kill switch 존중

`DEVBREW_DISABLE_SPEC_DISTILL=1` 이 set이면 즉시 종료 (no-op). 스크립트도 동일하게
존중하므로 그대로 실행해도 안전합니다.

## Step 2: 실행

다음을 그대로 실행하고 stderr advisory를 사용자에게 보여주십시오:

```bash
python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/cancel_review.py" $ARGUMENTS
```

## 사용법

- **인자 없음** — 현재 `pending_review` 문서를 취소 + 세션 억제. 이번 턴 Stop dispatch와
  다음 턴 reminder, 이후 같은 문서 edit이 모두 no-op이 됩니다.
- **`<path>`** — 그 문서를 억제. 현재 pending이 *같은* 문서면 함께 취소하고, *다른*
  문서의 pending은 보존합니다 (특정 문서 targeting / 사전 억제).
- **`--reset <path>`** — 억제 해제 → 그 문서 재편집 시 auto-review 재개.

## 동작 경계

- 억제는 **session-scoped**입니다. 새 세션은 SessionEnd cleanup 후 fresh 상태로
  시작하므로 stale 억제가 누출되지 않습니다.
- **Layer 1 구조 검증은 직교**합니다 — 억제는 arm/dispatch(Layer 2)만 끄며, 문서의
  ambiguity/placeholder 구조 검사는 그대로 동작합니다.
- 스코프(`docs/superpowers/specs/`) 밖 경로, session_id 미해석, kill switch는 상태를
  바꾸지 않고 loud advisory만 출력합니다.
````

- [ ] **Step 2: 커맨드 표면 sanity 확인**

Run (스크립트가 커맨드가 부르는 형태로 동작하는지 직접 호출 — git repo 안에서):
```bash
cd "$WT" && DEVBREW_SPEC_DISTILL_SESSION_ID=clitest1 \
  python3 plugins/spec-distill/scripts/cancel_review.py 2>&1
```
Expected: `[spec-distill] cancel-review: 취소할 pending_review 없음 ... nothing to do ...` (exit 0). 상태 파일 미생성.

- [ ] **Step 3: 커밋**

```bash
cd "$WT"
git add plugins/spec-distill/commands/cancel-review.md
git commit -m "feat(spec-distill): /spec-distill:cancel-review command wrapper"
git branch --show-current
```

---

## Task 5: validator suppression 게이트 (TDD)

**Files:**
- Modify: `plugins/spec-distill/hooks/spec-write-validator.py`
- Test: `plugins/spec-distill/tests/test_spec_write_validator.sh` (Case 12–14 추가)

- [ ] **Step 1: 실패 테스트 추가**

`$WT/plugins/spec-distill/tests/test_spec_write_validator.sh` 의 `# Case 11 ...` 블록 다음, `echo ""` summary 직전에 아래 3 케이스를 삽입한다.

```bash
# Case 12: AC9/AC18 — suppressed doc → arm skip + suppress advisory가 normal advisory 교체
mkdir -p "$WORK/docs/superpowers/specs" "$WORK/.claude/spec-distill/test-supp"
cp "$FIX/spec-valid.md" "$WORK/docs/superpowers/specs/2026-05-16-supp-spec.md"
cat > "$WORK/.claude/spec-distill/test-supp/state.local.md" <<EOF
---
session_id: test-supp
---

suppressed_paths:
  - docs/superpowers/specs/2026-05-16-supp-spec.md
EOF
out=$(run_hook_stdout "$WORK/docs/superpowers/specs/2026-05-16-supp-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-supp")
rc=$?
sf="$WORK/.claude/spec-distill/test-supp/state.local.md"
if [[ $rc -eq 0 ]] \
  && ! grep -qE '^pending_review:' "$sf" \
  && echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("suppressed")' >/dev/null \
  && ! echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("Reviewer will be dispatched")' >/dev/null; then
  note PASS "AC9/AC18: suppressed doc → arm skip + suppress advisory (no normal advisory)"
else
  note FAIL "AC9/AC18 failed (rc=$rc out=$out)"
fi

# Case 13: AC10 — suppressed doc도 Layer 1 실행 (구조 실패 → exit 2)
cp "$FIX/spec-missing-goals.md" "$WORK/docs/superpowers/specs/2026-05-16-supp2-spec.md"
mkdir -p "$WORK/.claude/spec-distill/test-supp2"
cat > "$WORK/.claude/spec-distill/test-supp2/state.local.md" <<EOF
---
session_id: test-supp2
---

suppressed_paths:
  - docs/superpowers/specs/2026-05-16-supp2-spec.md
EOF
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-supp2-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-supp2")
rc=$?
[[ $rc -eq 2 ]] && echo "$out" | grep -qE "missing sections:" \
  && note PASS "AC10: suppressed doc still subject to Layer 1 (exit 2)" \
  || note FAIL "AC10 failed (rc=$rc out=$out)"

# Case 14: AC11 — 다른 비-suppressed 문서 write_state가 suppressed_paths 보존
mkdir -p "$WORK/.claude/spec-distill/test-pres"
cat > "$WORK/.claude/spec-distill/test-pres/state.local.md" <<EOF
---
session_id: test-pres
---

suppressed_paths:
  - docs/superpowers/specs/2026-05-16-docA-design.md
EOF
cp "$FIX/spec-valid.md" "$WORK/docs/superpowers/specs/2026-05-16-docB-spec.md"
run_hook "$WORK/docs/superpowers/specs/2026-05-16-docB-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-pres" >/dev/null
sf="$WORK/.claude/spec-distill/test-pres/state.local.md"
if grep -q "  - docs/superpowers/specs/2026-05-16-docA-design.md" "$sf" \
   && grep -qE '^pending_review:' "$sf"; then
  note PASS "AC11: suppressed_paths preserved across other-doc write_state"
else
  note FAIL "AC11 failed ($(cat "$sf"))"
fi
```

- [ ] **Step 2: 실패 확인**

Run: `cd "$WT" && bash plugins/spec-distill/tests/test_spec_write_validator.sh`
Expected: Case 12(AC9/AC18) FAIL (suppress 미구현 → pending 생성됨 + normal advisory), Case 14(AC11)도 FAIL 가능. Case 13(AC10)은 우연히 PASS 가능(Layer 1은 이미 동작). 기존 Case 1–11은 PASS 유지.

- [ ] **Step 3: validator 편집 — top-of-file sys.path + suppress advisory 함수**

`hooks/spec-write-validator.py` 상단의 sys.path 블록 (현재 33–37행 부근):
```python
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from state_path import state_root as _state_root  # noqa: E402
```
을 다음으로 교체:
```python
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
SCRIPTS_DIR = SCRIPT_DIR.parent / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))
from state_path import state_root as _state_root  # noqa: E402
```

그리고 `emit_block` 함수 정의 *바로 다음에* suppress advisory 함수를 추가:
```python
def emit_suppress_advisory(mode: str, key: str) -> None:
    """v0.14.0 — suppressed 문서 arm skip advisory. 기존 'Reviewer will be
    dispatched' 출력을 *교체*(이중 방출 금지, AC18)."""
    print(
        json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": (
                    f"[spec-distill] {key} review suppressed this session "
                    "(cancel-review/approved) — arm skipped. "
                    f"Re-enable: /spec-distill:cancel-review --reset {key}"
                ),
            },
            "systemMessage": f"[spec-distill] {mode} arm suppressed for {key}",
        }),
        flush=True,
    )
    print(
        f"[spec-distill] {key} review suppressed this session — arm skipped. "
        f"Re-enable: /spec-distill:cancel-review --reset {key}",
        file=sys.stderr,
    )
```

- [ ] **Step 4: validator 편집 — `write_state` inline strip → import, + suppress 게이트**

(a) `write_state` 내부의 inline pending strip (현재 183–186행 부근):
```python
    body = re.sub(
        r"^pending_review:\n(?:  [^\n]*\n)*", "", body, flags=re.MULTILINE
    )
    state_file.write_text(body.rstrip() + "\n\n" + block, encoding="utf-8")
```
을 다음으로 교체 (중복 정규식 제거 — single source):
```python
    import suppress_state
    body = suppress_state.strip_pending(body)
    state_file.write_text(body.rstrip() + "\n\n" + block, encoding="utf-8")
```

(b) `main()` 의 Layer 2 블록 (현재 244–252행 부근):
```python
    # Pass → write state (unless Layer 2 disabled)
    if os.environ.get("DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW") != "1":
        from state_path import resolve_session_id
        session_id = resolve_session_id(payload)
        if session_id is not None:
            try:
                write_state(session_id, file_path, mode, os.getcwd())
            except (PermissionError, OSError) as exc:
                print(f"[spec-distill] state write failed (non-fatal): {exc}", file=sys.stderr)
```
을 다음으로 교체:
```python
    # Pass → write state (unless Layer 2 disabled)
    if os.environ.get("DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW") != "1":
        from state_path import resolve_session_id
        session_id = resolve_session_id(payload)
        if session_id is not None:
            # v0.14.0 suppression 게이트 — per-doc, session-scoped (Layer 2).
            # Layer 1 구조 검증은 위에서 이미 실행됨(NG1·AC10): suppressed 문서도
            # 구조 실패면 exit 2로 차단. 여기 도달 = Layer 1 통과.
            try:
                import suppress_state
                sfile = suppress_state.state_file_for(session_id)
                if suppress_state.is_suppressed(sfile, file_path):
                    key = suppress_state.canonical_key(file_path) or file_path
                    emit_suppress_advisory(mode, key)
                    return 0  # arm skip — 기존 advisory 미방출(AC18)
            except Exception as exc:  # noqa: BLE001 — graceful degradation
                print(
                    f"[spec-distill] suppress check failed "
                    f"(non-fatal, arming normally): {exc}",
                    file=sys.stderr,
                )
            try:
                write_state(session_id, file_path, mode, os.getcwd())
            except (PermissionError, OSError) as exc:
                print(f"[spec-distill] state write failed (non-fatal): {exc}", file=sys.stderr)
```

- [ ] **Step 5: 통과 확인 (신규 + 회귀)**

```bash
cd "$WT"
bash plugins/spec-distill/tests/test_spec_write_validator.sh
python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_hook_output_schema.py' 2>&1 | tail -3
```
Expected: validator 테스트 `summary: 14 passed, 0 failed` (기존 11 + 신규 3). hook_output_schema 회귀 `OK`.

- [ ] **Step 6: 커밋**

```bash
cd "$WT"
git add plugins/spec-distill/hooks/spec-write-validator.py plugins/spec-distill/tests/test_spec_write_validator.sh
git commit -m "feat(spec-distill): validator suppression gate before arm (Layer 1 unchanged)"
git branch --show-current
```

---

## Task 6: `approve_handoff.sh` — dir rm → suppress (TDD)

**Files:**
- Modify: `plugins/spec-distill/scripts/approve_handoff.sh`
- Test: `plugins/spec-distill/tests/test_approve_handoff.sh` (Case 3·4 재작성)

- [ ] **Step 1: 실패 테스트로 재작성**

`test_approve_handoff.sh` 의 **Case 3** (53–66행)과 **Case 4** (68–78행)를 아래로 교체. 나머지 케이스(1,2,5,6,7)는 유지.

```bash
# ── Case 3 (AC12 idempotency): clean re-call → exit 0, suppressed_paths 1 entry ──
WORK=$(mktemp -d); setup_repo "$WORK"
spec="$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
bash "$SCRIPT" "test-sid12" "$spec" >/dev/null 2>&1
bash "$SCRIPT" "test-sid12" "$spec" >"$OUT" 2>&1; rc=$?
sf="$WORK/.claude/spec-distill/test-sid12/state.local.md"
cnt=$(grep -c "  - docs/superpowers/specs/2026-01-01-test-spec.md" "$sf" 2>/dev/null || echo 0)
if [[ $rc -eq 0 && "$cnt" == "1" ]]; then
    note PASS "case 3 (AC12): idempotent re-call → exactly 1 suppressed entry"
else
    note FAIL "case 3: rc=$rc cnt=$cnt"
fi
rm -rf "$WORK"

# ── Case 4 (AC12): approve → suppressed_paths 기록 + pending strip + dir 보존 ──
WORK=$(mktemp -d); setup_repo "$WORK"
sess="$WORK/.claude/spec-distill/test-sid12"
spec="$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
cat > "$sess/state.local.md" <<EOF
---
session_id: test-sid12
---

pending_review:
  path: $spec
  mode: spec
  worktree_path: $WORK
  triggered_at: 2026-01-01T00:00:00Z
EOF
bash "$SCRIPT" "test-sid12" "$spec" >/dev/null 2>&1; rc=$?
key="docs/superpowers/specs/2026-01-01-test-spec.md"
if [[ $rc -eq 0 && -d "$sess" ]] \
   && grep -q "^suppressed_paths:" "$sess/state.local.md" \
   && grep -q "  - $key" "$sess/state.local.md" \
   && ! grep -qE '^pending_review:' "$sess/state.local.md"; then
    note PASS "case 4 (AC12): suppress recorded + pending stripped + dir preserved"
else
    note FAIL "case 4 (AC12): rc=$rc dir=$([[ -d $sess ]] && echo y || echo n)"
fi
rm -rf "$WORK"
```

또한 파일 상단 주석(1–4행)의 `AC6 (cleanup happened)` 언급을 `AC12 (suppress recorded + dir preserved)`로 갱신.

- [ ] **Step 2: 실패 확인**

Run: `cd "$WT" && bash plugins/spec-distill/tests/test_approve_handoff.sh`
Expected: Case 4 FAIL (현재 스크립트는 dir를 rm하고 suppressed_paths를 안 씀). Case 3도 FAIL (suppressed entry 0). Case 1,2,5,6,7 PASS.

- [ ] **Step 3: `approve_handoff.sh` 편집**

(a) 헤더 주석 (7–9행) 교체:
```bash
#   (3) cleans up the per-session state directory (AC6).
# Idempotent by statelessness: re-running on a clean tree / already-removed
# session dir is a no-op.
```
→
```bash
#   (3) records the approved spec into suppressed_paths + strips its pending
#       (v0.14.0 — replaces dir rm; dir cleanup deferred to SessionEnd/TTL-GC).
# Idempotent by set-membership (AC4/AC12): re-running adds the key at most once.
```

(b) exit code 주석 (14행) `0 — spec exists ...; session dir cleaned` → `0 — spec exists ...; approved spec suppressed (dir preserved)`.

(c) Session directory cleanup 블록 (80–82행):
```bash
# ─── Session directory cleanup (AC6) ───
rm -rf -- "$main_repo/.claude/spec-distill/$session_id/" 2>/dev/null || \
    echo "[spec-distill] cleanup rm failed (non-fatal) — SessionEnd hook will retry" >&2
```
을 다음으로 교체:
```bash
# ─── Suppress approved doc + strip its pending (v0.14.0, AC12) — replaces rm -rf ───
# approved 문서를 suppressed_paths에 기록 → 같은 문서 재편집 시 재arm 차단(증상 A).
# 정규화 + same-key pending strip + add는 suppress_state.py가 단일 소스로 수행(C4).
# 세션 dir는 더 이상 여기서 삭제하지 않는다 — "승인됨" 기억을 세션 동안 보존해야
# 재발을 막는다. dir cleanup은 SessionEnd hook / TTL-GC가 담당(AC15).
suppress_cli="$(dirname "$0")/suppress_state.py"
if [[ -f "$suppress_cli" ]]; then
    if ! python3 "$suppress_cli" add "$session_id" "$spec_path"; then
        echo "[spec-distill] approve_handoff: suppress 기록 실패 (non-fatal) — 같은 문서 재편집 시 재arm 가능. /spec-distill:cancel-review로 수동 억제 가능." >&2
    fi
else
    echo "[spec-distill] approve_handoff: suppress_state.py 없음 (non-fatal) — 세션 dir는 SessionEnd/GC가 정리." >&2
fi
```

(d) 마지막 echo (84행)의 `다음 단계는 reviewing-spec proceed 게이트 선택대로 진행.` 앞을 `v0.11.0` → `v0.14.0`로, 메시지를 현실에 맞게:
```bash
echo "spec-distill v0.14.0 handoff finalized (session: $session_id). approved spec suppressed for this session. 다음 단계는 reviewing-spec proceed 게이트 선택대로 진행."
```

- [ ] **Step 4: 통과 확인**

Run: `cd "$WT" && bash plugins/spec-distill/tests/test_approve_handoff.sh`
Expected: `PASSED: 7 cases`.

- [ ] **Step 5: 커밋**

```bash
cd "$WT"
git add plugins/spec-distill/scripts/approve_handoff.sh plugins/spec-distill/tests/test_approve_handoff.sh
git commit -m "feat(spec-distill): approve_handoff suppresses approved doc instead of rm (dir → SessionEnd/GC)"
git branch --show-current
```

---

## Task 7: 메타데이터 동기화 (plugin.json + CHANGELOG + README + readme_sync)

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`
- Modify: `plugins/spec-distill/CHANGELOG.md`
- Modify: `plugins/spec-distill/README.md`
- Test: `plugins/spec-distill/tests/test_readme_sync.sh`

- [ ] **Step 1: `test_readme_sync.sh` 를 0.14.0 + cancel-review 기대로 갱신 (실패 테스트)**

13–22행을 다음으로 교체:
```bash
grep -q '"version": "0.14.0"' "$PLUGIN_JSON" \
  && note PASS "AC16: plugin.json version 0.14.0" || note FAIL "AC16: plugin.json not 0.14.0"
grep -qE '^## \[0\.14\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && note PASS "AC16: CHANGELOG [0.14.0] entry with ISO date" || note FAIL "AC16: CHANGELOG [0.14.0] missing/!ISO"
grep -qE '^## \[0\.14\.0\].*XX' "$CHANGELOG" \
  && note FAIL "AC16: CHANGELOG date has XX placeholder" || note PASS "AC16: no XX placeholder in date"

for kw in 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' 'interview-brief' 'steelman-builder' 'cancel-review'; do
  grep -q "$kw" "$README" \
    && note PASS "AC16: README mentions $kw" || note FAIL "AC16: README missing $kw"
done
```
Run: `cd "$WT" && bash plugins/spec-distill/tests/test_readme_sync.sh` → Expected: FAIL (0.14.0 미반영, cancel-review 미언급).

- [ ] **Step 2: `plugin.json` bump**

`"version": "0.13.0"` → `"version": "0.14.0"`.

- [ ] **Step 3: CHANGELOG `[0.14.0]` 항목 추가**

`# Changelog` 다음, `## [0.13.0]` 앞에 삽입:
```markdown
## [0.14.0] — 2026-06-05

### Added
- `scripts/suppress_state.py` — per-doc·session-scoped `suppressed_paths` 집합의 **단일 소스**(정규화·pending strip·suppress). Python API(`canonical_key`/`pending_path`/`suppressed_keys`/`strip_pending`/`state_file_for`/`is_suppressed`/`add`/`remove`/`suppress_path`) + thin CLI(`{add|remove|is-suppressed} <sid> <raw_path>`). 정규화는 이 파일에만 존재 — 호출자는 raw 경로 위임(C4/AC17).
- `scripts/cancel_review.py` + `commands/cancel-review.md` — `/spec-distill:cancel-review [path] | --reset <path>`. 현재/지정 design 문서의 auto-review를 취소·억제(또는 재활성화). 리뷰 완료/중단 후 같은 문서 재편집 시 reviewing-spec가 재dispatch되던 두 gap(증상 A/B)을 끄는 사용자 주권(P17) 경로.
- Tests: `tests/test_cancel_review.py`(suppress_state 단위 + cancel_review 통합, AC1–AC8/AC11/AC14/AC17/AC19) + `test_spec_write_validator.sh`/`test_approve_handoff.sh` 확장.

### Changed
- `hooks/spec-write-validator.py` — Layer 1 통과 후 `write_state` 직전 `suppress_state.is_suppressed` 게이트: suppressed 문서는 arm skip + 전용 suppress advisory(기존 "Reviewer will be dispatched" 출력 *교체*) + return 0(AC9/AC18). Layer 1 구조 검증 불변(NG1/AC10). inline pending-strip re.sub → `suppress_state.strip_pending`(중복 제거).
- `scripts/approve_handoff.sh` — 세션 dir `rm -rf` → `suppress_state.py add`(approved 키 기록 + same-key pending strip). dir cleanup은 SessionEnd/TTL-GC로 이관 — 삭제 시 "승인됨" 기억 소실로 증상 A 재발(AC12). "idempotent by statelessness" → "idempotent by set-membership".
- `tests/test_readme_sync.sh` — 버전 기대값 0.13.0 → 0.14.0 + `cancel-review` README 동기화 체크.
- `README.md` — Flow(v0.14.0) + Hooks Installed(PostToolUse suppression 게이트) + Principles(P17 cancel/reset) + Kill switches(per-doc suppression 안내).

### Notes
- suppression은 **session-scoped**: SessionEnd cleanup이 dir를 삭제해 다음 세션은 fresh(NG4/AC15). 재리뷰는 `--reset <path>`, 다른 경로의 새 문서, 또는 reviewing-spec 직접 호출.
- `review-dispatch.py`(Stop)·`pending-review-reminder.py`(UserPromptSubmit)는 무변경 — pending_review가 안 생기므로 자연 no-op.
```

- [ ] **Step 4: README 동기화 (5곳)**

(i) 23행: `## Flow (v0.13.0)` → `## Flow (v0.14.0)`.

(ii) 43행 (`**v0.13.0**: ...` 줄) 다음에 추가:
```markdown
**v0.14.0**: per-doc·session-scoped `suppressed_paths` + `/spec-distill:cancel-review` — 리뷰 완료/중단 후 같은 design 문서 재편집 시 재arm 차단.
```

(iii) Principles → P17 줄(66행)을 다음으로 교체:
```markdown
- **P17 (User sovereignty)** — `needs_interview` user confirm gate, [5] Human Review, all kill switches, **`/spec-distill:cancel-review [path] | --reset <path>` per-doc 취소·재활성화 게이트 (v0.14.0)**.
```

(iv) Hooks Installed → PostToolUse row(105행)의 책임 셀 끝(`... 기록 (v0.3.0)`)을 다음으로 교체:
```markdown
mechanical Layer 1 검증 + `pending_review:` ledger 기록 (v0.3.0). **v0.14.0: arm 직전 `suppressed_paths` 조회 — 취소/승인된 문서는 arm skip(Layer 1은 불변).**
```

(v) Kill switches 목록 끝(128행 다음)에 추가:
```markdown
- `/spec-distill:cancel-review [path]` (v0.14.0) — env가 아닌 **per-doc 사용자 주권 경로**. 현재/지정 design 문서 auto-review 취소 + 세션 억제. `--reset <path>`로 재활성화. (kill switch는 아니지만 "원치 않는 리뷰를 끄는" 사용자 컨트롤로 여기 명시.)
```

- [ ] **Step 5: 통과 확인**

Run: `cd "$WT" && bash plugins/spec-distill/tests/test_readme_sync.sh`
Expected: `Total: N | Pass: N | Fail: 0` (cancel-review 포함 모든 kw + 0.14.0).

- [ ] **Step 6: 커밋**

```bash
cd "$WT"
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md \
        plugins/spec-distill/README.md plugins/spec-distill/tests/test_readme_sync.sh
git commit -m "docs(spec-distill): v0.14.0 bump + CHANGELOG + README/readme_sync (cancel-review + suppression)"
git branch --show-current
```

---

## Task 8: 전체 스위트 green + AC15/AC17 검증 + 정리

**Files:** (검증만 — 코드 변경 없음, AC 미충족 시 해당 Task로 회귀)

- [ ] **Step 1: 전체 python + shell 스위트**

```bash
cd "$WT"
python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_*.py' 2>&1 | tail -8
for t in plugins/spec-distill/tests/*.sh; do
  echo "=== $(basename "$t") ==="; bash "$t" 2>&1 | tail -2
done
```
Expected: python `OK` (또는 baseline에서 기록한 무관 red만 — Task 1 Step 3과 동일 집합). 모든 shell 테스트 0 fail. **baseline 대비 신규 red 0**.

- [ ] **Step 2: AC15 — SessionEnd cleanup이 dir 삭제(세션 간 누출 차단) 재확인**

본 PR은 `session-end-cleanup.py`를 바꾸지 않는다 (approve_handoff가 dir를 더는 안 지우므로 SessionEnd가 유일 dir cleanup 경로 중 하나임을 확인만).
```bash
cd "$WT"
python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_session_end_cleanup.py' -v 2>&1 | tail -5
grep -n "rmtree\|rm -rf\|shutil" plugins/spec-distill/hooks/session-end-cleanup.py | head
```
Expected: session_end_cleanup 테스트 `OK` + dir 삭제 로직 존재 확인. (없거나 red면 AC15 위험 — 사용자에게 보고.)

- [ ] **Step 3: AC17 — 정규화 단일 소스 grep 검증**

```bash
cd "$WT"
echo "--- canonical_key 정의는 suppress_state.py 한 곳만 ---"
grep -rn "def canonical_key" plugins/spec-distill/
echo "--- cancel_review.py / approve_handoff.sh 에 PREFIX 리터럴 슬라이스 없음 ---"
grep -n "docs/superpowers/specs/" plugins/spec-distill/scripts/cancel_review.py plugins/spec-distill/scripts/approve_handoff.sh || echo "OK: no literal prefix in delegators"
```
Expected: `canonical_key` 정의 1건(suppress_state.py); 두 delegator에 리터럴 prefix 0건 → `OK: no literal prefix in delegators`. (test_cancel_review.py의 `test_no_prefix_slice_outside_suppress_state`가 이미 기계 보장 — 이중 확인.)

- [ ] **Step 4: 최종 self-review 게이트 (Law 1 구조 + diff 확인)**

```bash
cd "$WT"
git log --oneline main..HEAD
git diff --stat main..HEAD
git status   # MUST be clean (no untracked/uncommitted)
```
Expected: 7 commits(design&plan / suppress_state / cancel_review / command / validator / approve_handoff / metadata); clean tree; branch = `feature/spec-distill-cancel-suppress`.

- [ ] **Step 5: 수동 e2e 안내 (사용자 실행)**

자동 테스트로 커버 못 하는 라이브 hook 흐름. 사용자에게 다음 시나리오를 안내(코드 변경 없음):
1. `-design.md` write → PostToolUse arm 확인 → `/spec-distill:cancel-review` → 턴 종료 시 Stop dispatch 없음.
2. approve 흐름 → 같은 문서 재편집 → 재arm 없음.
3. `/spec-distill:cancel-review --reset <path>` → 재편집 → 재arm 복귀.

---

## Self-Review (AC 커버리지)

| AC | 검증 위치 |
|---|---|
| AC1 cancel+pending → strip+add | Task3 test_ac1 / Task2 test_suppress_path_same_key |
| AC2 cancel `<path>` no-pending → add(create) | Task3 test_ac2 |
| AC3 no-pending no-args → advisory exit 0 | Task3 test_ac3 |
| AC4 멱등 1 entry | Task2 test_add_idempotent / Task3 test_ac4 / Task6 case3 |
| AC5 `--reset` 제거 + absent no-op | Task3 test_ac5 / Task2 test_remove |
| AC6 kill switch no-op | Task3 test_ac6 |
| AC7 sid 미해석 loud, no change | Task3 test_ac7 |
| AC8 out-of-scope reject | Task3 test_ac8 / Task2 test_canonical_key_out_of_scope |
| AC9 validator suppressed → skip+advisory | Task5 case12 |
| AC10 suppressed도 Layer 1(exit 2) | Task5 case13 |
| AC11 suppressed_paths 보존 (other-doc write) | Task5 case14 |
| AC12 approve → suppress+strip+dir 보존+멱등 | Task6 case3,case4 |
| AC13 approve spec-missing exit 1 불변 | Task6 case(기존 미변경 — 회귀로 보장; test_handoff_spec_path_validation.sh) |
| AC14 두 블록 round-trip | Task2 test_strip_pending_preserves_suppressed |
| AC15 SessionEnd dir 삭제 | Task8 step2 (기존 동작 확인) |
| AC16 plugin.json/CHANGELOG/README 동기화 | Task7 test_readme_sync |
| AC17 정규화 단일 소스 | Task2 test_no_prefix_slice / Task8 step3 |
| AC18 suppress advisory가 normal 교체(이중 없음) | Task5 case12 |
| AC19 다른-문서 pending 보존 | Task3 test_ac19 / Task2 test_suppress_path_different_key |

**Placeholder scan:** 모든 코드 step은 완전한 본문 포함. "TBD/TODO/implement later" 없음. (AC13은 *기존 미변경 동작*이라 신규 테스트 대신 회귀로 보장 — `test_handoff_spec_path_validation.sh` 가 spec-missing exit 1을 이미 커버, approve_handoff의 `[[ -f ]]` 가드는 본 PR에서 손대지 않음. Task8 Step1 전체 스위트로 회귀 확인.)

**Type/signature consistency:** suppress_state 공개 함수명(`canonical_key`/`pending_path`/`suppressed_keys`/`strip_pending`/`state_file_for`/`is_suppressed`/`add`/`remove`/`suppress_path`)이 cancel_review·validator·테스트에서 동일하게 사용됨. CLI 인자 순서 `<sid> <raw_path>` 가 approve_handoff 호출(`add "$session_id" "$spec_path"`)과 일치.

**위험 메모 (실행 중 확인):**
- `python3 -m unittest discover` 가 하이픈 디렉토리(`spec-distill`)에서도 동작 — start dir를 sys.path에 추가하므로 dotted-module 경로 불필요. 기존 `test_gc.py`가 같은 방식.
- validator의 `import suppress_state` 는 `env -i HOME PATH` 테스트 하니스에서도 동작(sys.path.insert로 PYTHONPATH 불요). Task5 Step5에서 실증.
- 워크트리 내 hook 실행 시 `state_root()` 는 git-common-dir로 **main repo** `.claude/spec-distill/` 를 가리킨다(§4.8) — 테스트는 자체 tmp git repo를 쓰므로 무관.
```

