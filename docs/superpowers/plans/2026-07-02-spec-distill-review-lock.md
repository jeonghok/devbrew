# spec-distill Review-in-Progress Lock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** subagent(async) dispatch 중 메인 `Stop`이 진행 중인 리뷰를 재강제(중복 A/절단 B)하는 오발을, **문서별(multi-key) `review_in_progress` 락**으로 봉쇄하되 리뷰 강제 계약(Law 1/2)은 100% 보존한다.

**Architecture:** 신규 `scripts/review_lock.py`가 문서별 엔트리 리스트를 state.local.md에 소유(`suppressed_paths`와 동형). `reviewing-spec`가 매 진입마다 그 문서 엔트리를 refresh(`set`)하고, `review-dispatch.py`(Stop)와 `pending-review-reminder.py`(UserPromptSubmit)가 pending 처리 전에 `is_review_active`로 조회해 "그 문서 + 신선"일 때만 no-op한다. approve/cancel은 `clear`, ④ 멈춤은 `pause`. 어떤 실패도 정상 dispatch로 fail(fail-safe = 강제).

**Tech Stack:** Python 3.9+ (hooks/scripts), bash (skill/finalizer 호출 + shell 테스트), unittest (python 테스트). state는 마크다운 `.claude/spec-distill/<sid>/state.local.md`.

## Global Constraints

이 절의 요구는 **모든 task에 암묵적으로 포함**된다 — spec에서 verbatim 복사:

- **버전 bump**: `plugins/spec-distill/.claude-plugin/plugin.json` `0.17.0` → `0.18.0` (minor — 새 state 블록 + 훅 동작 추가, breaking 아님). 이 PR이 spec-distill을 건드리므로 bump 필수(cache key).
- **CHANGELOG**: `plugins/spec-distill/CHANGELOG.md`에 `## [0.18.0] — 2026-07-02` (Added/Changed/Fixed/Removed). ISO 날짜, `XX` placeholder 금지.
- **단일 정규화 소스**: `canonical_key`는 `suppress_state`에서만 정의. `review_lock.py`는 이를 **import**하고 새 `docs/superpowers/specs/` PREFIX 리터럴을 만들지 않는다 (`test_cancel_review.py::test_no_prefix_slice_outside_suppress_state`가 sibling 스크립트에서 이 문자열을 grep로 금지 — 단, 이 테스트는 `cancel_review.py`/`approve_handoff.sh`만 스코프; `review_lock.py`는 `import`이므로 리터럴 불필요).
- **fail-safe = 강제 (Law 1)**: 락 조회의 어떤 예외(파싱·import 실패 포함)도 정상 dispatch로 귀결. over-review > under-review — 기존 suppress fail-open과 같은 방향.
- **AC7 — `hooks/spec-write-validator.py` 무변경**: pending은 항상 arm되는 안전 substrate. 이 파일을 수정하지 않는다.
- **AC9 — `last_dispatched_at` 30초 self-ref 가드 유지**: `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC`(default 30) 로직 제거·병합 금지 (별개 실패 모드 커버).
- **py3.9 호환**: 모든 python 파일 상단 `from __future__ import annotations` (`str | None` 시그니처가 3.9에서 동작).
- **Placeholder 금지**: `TBD`/`TODO`/`FIXME`/`<placeholder>` 토큰을 코드·docs에 넣지 않는다 (validator가 차단).
- **Korean-primary docs**: SKILL.md/README/CHANGELOG 산문은 한국어 primary, 영어는 식별자·고유명사·기술용어에 한정.
- **테스트 실행 규약**: python 테스트는 **repo root에서** `python3 -m unittest discover -s plugins/spec-distill/tests -p '<file>'` (직접 실행 금지 — vacuous). shell 테스트도 repo root에서 실행.
- **회귀 락 teeth (AC14)**: 문서/스킬 grep 락은 **body-unique** 문구를 섹션 윈도우에서 assert하고, mutation(그 라인 삭제)으로 red 됨을 증명 (헤더-satisfiable 함정 회피).

**TTL 기본값**: `is_review_active`·prune 임계 = **1800초(30분)**, env `DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC`로 override. refresh-on-reentry라 실제로 걸리는 건 *라운드-간 gap*이지 누적 리뷰시간이 아니다.

---

## File Structure

| 파일 | 책임 | Task |
|---|---|---|
| `scripts/review_lock.py` **(신규)** | 문서별 엔트리 리스트 소유. `set_lock`/`clear_lock`/`pause`/`is_review_active` + CLI. 원자적 write, stale prune, kill switch. | 1 |
| `tests/test_review_lock.py` **(신규)** | 위 모듈 단위 + CLI 테스트 (AC15/16/17/18 유닛 포함). | 1 |
| `hooks/review-dispatch.py` | suppress 뒤·TTL 가드 앞에 `is_review_active` 게이트. | 2 |
| `tests/test_review_dispatch.sh` | 락 게이트 케이스 추가 (신선→no-op / 다른문서→dispatch / stale→dispatch). | 2 |
| `hooks/pending-review-reminder.py` | 동일 document-keyed 락 게이트. | 3 |
| `tests/test_reminder_hook.sh` | 락 게이트 케이스 추가. | 3 |
| `skills/reviewing-spec/SKILL.md` | Step 1 `set`(refresh) + Phase 5 옵션↔락 매핑표(④=`pause`). | 4 |
| `tests/test_reviewing_spec_lock.sh` **(신규)** | SKILL body-unique 문구 teeth 락. | 4 |
| `scripts/approve_handoff.sh` | `review_lock.py clear` 호출 + dead `main_repo` 블록 제거. | 5 |
| `tests/test_approve_handoff.sh` | clear 호출(엔트리 제거) + dead 블록 부재 grep. | 5 |
| `scripts/cancel_review.py` | 취소 키 엔트리 `clear`(approve 대칭). | 6 |
| `tests/test_cancel_review.py` | 취소→clear / 다른 키 엔트리 불변(AC11). | 6 |
| `.claude-plugin/plugin.json` · `CHANGELOG.md` · `README.md` · `tests/test_readme_sync.sh` | 0.18.0 + 문서 동기화. | 7 |

**무변경 (명시)**: `hooks/spec-write-validator.py` (AC7), `scripts/suppress_state.py` (import만), `hooks/state_path.py`.

---

### Task 1: `review_lock.py` 모듈 + 단위 테스트

**Files:**
- Create: `plugins/spec-distill/scripts/review_lock.py`
- Test: `plugins/spec-distill/tests/test_review_lock.py`

**Interfaces:**
- Consumes: `suppress_state.canonical_key/pending_path/strip_pending/state_file_for`, `state_path.SESSION_PATTERN` (기존).
- Produces (다음 task들이 의존하는 정확한 시그니처):
  - `set_lock(state_file: Path, raw_path: str, now: datetime) -> None` — 그 키 엔트리 upsert(refresh), 나머지 보존.
  - `clear_lock(state_file: Path, raw_path: str) -> None` — 그 키 엔트리만 제거.
  - `pause(state_file: Path, raw_path: str) -> None` — `clear_lock` + 같은-키 pending strip(suppress 없음).
  - `is_review_active(body: str, pending_key: str | None, now: datetime, ttl: int) -> bool` — 그 키 엔트리 존재+신선이면 True.
  - `canonical_key(raw_path: str) -> str | None` — `suppress_state`에서 재수출.
  - CLI: `python3 review_lock.py {set|clear|pause} <sid> <raw_path>`.

**설계 노트 (round-4 advisory)**: `set_lock`/`clear_lock`/`pause`는 `state_file`을 받아 read-modify-write를 스스로 소유하는 CLI 진입점이고, `is_review_active`는 이미 state를 1회 읽은 훅이 재-read를 피하도록 `body`(문자열)를 받는 read-only 판정기다. 이 비대칭은 의도된 것이며 모듈 docstring에 한 줄로 명시한다.

- [ ] **Step 1: 실패 테스트 작성** — `plugins/spec-distill/tests/test_review_lock.py`

```python
"""spec-distill review_lock.py contract — document-keyed(multi-key) review-in-progress lock.

TestReviewLockUnit: Python API 직접 import 단위 (AC15/16/17/18 유닛).
TestReviewLockCLI: CLI subprocess + kill switch.

실행 (repo root):
  python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_review_lock.py'
"""
from __future__ import annotations  # str | None 시그니처가 py3.9에서도 동작

import os
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone, timedelta
from pathlib import Path

SCRIPTS = (Path(__file__).resolve().parent.parent / "scripts").resolve()
HOOKS = (Path(__file__).resolve().parent.parent / "hooks").resolve()
LOCK_CLI = SCRIPTS / "review_lock.py"
sys.path.insert(0, str(SCRIPTS))
sys.path.insert(0, str(HOOKS))
import review_lock  # noqa: E402 # pyright: ignore[reportMissingImports]

PREFIX = "docs/superpowers/specs/"
DOC_A = PREFIX + "2026-07-01-doc-a-design.md"
DOC_B = PREFIX + "2026-07-01-doc-b-design.md"
T0 = datetime(2026, 7, 1, 13, 0, 0, tzinfo=timezone.utc)


def _iso(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


class TestReviewLockUnit(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.sf = self.tmp / "sid12345" / "state.local.md"

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_set_lock_creates_entry(self):
        review_lock.set_lock(self.sf, "/wt/" + DOC_A, T0)  # worktree-absolute 형태
        body = self.sf.read_text()
        self.assertTrue(review_lock.is_review_active(body, DOC_A, T0, 1800))

    def test_set_lock_upsert_refresh_preserves_other(self):  # AC18 유닛
        review_lock.set_lock(self.sf, DOC_A, T0)
        review_lock.set_lock(self.sf, DOC_B, T0)
        body = self.sf.read_text()
        self.assertTrue(review_lock.is_review_active(body, DOC_A, T0, 1800))
        self.assertTrue(review_lock.is_review_active(body, DOC_B, T0, 1800))
        # A refresh → B 엔트리 보존(clobber 없음)
        t1 = T0 + timedelta(seconds=100)
        review_lock.set_lock(self.sf, DOC_A, t1)
        body = self.sf.read_text()
        self.assertTrue(review_lock.is_review_active(body, DOC_B, t1, 1800))
        # 엔트리 중복 안 생김 (upsert)
        self.assertEqual(
            [p for p, _ in review_lock._parse_entries(body)].count(DOC_A), 1
        )

    def test_clear_lock_removes_only_that_key(self):
        review_lock.set_lock(self.sf, DOC_A, T0)
        review_lock.set_lock(self.sf, DOC_B, T0)
        review_lock.clear_lock(self.sf, "/wt/" + DOC_A)  # 다른 경로 형태도 같은 키
        body = self.sf.read_text()
        self.assertFalse(review_lock.is_review_active(body, DOC_A, T0, 1800))
        self.assertTrue(review_lock.is_review_active(body, DOC_B, T0, 1800))

    def test_clear_lock_idempotent_absent(self):
        review_lock.clear_lock(self.sf, DOC_A)  # 파일 없음 → no-op, no crash
        review_lock.set_lock(self.sf, DOC_A, T0)
        review_lock.clear_lock(self.sf, DOC_B)  # 없는 키 → no-op
        body = self.sf.read_text()
        self.assertTrue(review_lock.is_review_active(body, DOC_A, T0, 1800))

    def test_is_review_active_absent_key_false(self):  # AC16 core
        review_lock.set_lock(self.sf, DOC_A, T0)
        body = self.sf.read_text()
        self.assertFalse(review_lock.is_review_active(body, DOC_B, T0, 1800))

    def test_is_review_active_fresh_true_stale_false(self):  # AC4 경계
        review_lock.set_lock(self.sf, DOC_A, T0)
        body = self.sf.read_text()
        self.assertTrue(review_lock.is_review_active(body, DOC_A, T0 + timedelta(seconds=1799), 1800))
        self.assertFalse(review_lock.is_review_active(body, DOC_A, T0 + timedelta(seconds=1800), 1800))
        self.assertFalse(review_lock.is_review_active(body, DOC_A, T0 + timedelta(seconds=5000), 1800))

    def test_is_review_active_no_lock_false(self):
        self.assertFalse(review_lock.is_review_active("---\nsession_id: s\n---\n", DOC_A, T0, 1800))

    def test_is_review_active_unparseable_since_false(self):  # fail-safe = enforce
        body = ("review_in_progress:\n  - path: " + DOC_A + "\n    since: not-a-date\n")
        self.assertFalse(review_lock.is_review_active(body, DOC_A, T0, 1800))

    def test_is_review_active_none_key_false(self):
        self.assertFalse(review_lock.is_review_active("review_in_progress:\n", None, T0, 1800))

    def test_multi_round_refresh_never_stale(self):  # AC15
        t = T0
        for _ in range(5):
            review_lock.set_lock(self.sf, DOC_A, t)
            body = self.sf.read_text()
            self.assertTrue(review_lock.is_review_active(body, DOC_A, t + timedelta(seconds=1799), 1800))
            t = t + timedelta(seconds=1799)  # 라운드-간 gap < TTL

    def test_pause_removes_entry_and_same_key_pending(self):  # AC17 유닛
        self.sf.parent.mkdir(parents=True)
        self.sf.write_text(
            "---\nsession_id: sid12345\n---\n\n"
            "pending_review:\n  path: /wt/" + DOC_A + "\n  mode: design\n"
            "  worktree_path: /wt\n  triggered_at: t\n\n"
            "review_in_progress:\n  - path: " + DOC_A + "\n    since: " + _iso(T0) + "\n"
        )
        review_lock.pause(self.sf, "/wt/" + DOC_A)
        body = self.sf.read_text()
        self.assertNotIn("pending_review:", body)
        self.assertFalse(review_lock.is_review_active(body, DOC_A, T0, 1800))

    def test_pause_preserves_other_doc_entry_and_pending(self):
        self.sf.parent.mkdir(parents=True)
        self.sf.write_text(
            "---\nsession_id: sid12345\n---\n\n"
            "pending_review:\n  path: " + DOC_B + "\n  mode: design\n"
            "  triggered_at: t\n\n"
            "review_in_progress:\n"
            "  - path: " + DOC_A + "\n    since: " + _iso(T0) + "\n"
            "  - path: " + DOC_B + "\n    since: " + _iso(T0) + "\n"
        )
        review_lock.pause(self.sf, DOC_A)  # A만 멈춤
        body = self.sf.read_text()
        self.assertIn("pending_review:", body)  # B pending 보존(다른 키)
        self.assertFalse(review_lock.is_review_active(body, DOC_A, T0, 1800))
        self.assertTrue(review_lock.is_review_active(body, DOC_B, T0, 1800))

    def test_stale_prune_on_set(self):
        # A는 stale, B를 새로 set → A가 prune되어 리스트가 bounded
        review_lock.set_lock(self.sf, DOC_A, T0)
        review_lock.set_lock(self.sf, DOC_B, T0 + timedelta(seconds=5000))
        body = self.sf.read_text()
        keys = [p for p, _ in review_lock._parse_entries(body)]
        self.assertNotIn(DOC_A, keys)  # stale prune
        self.assertIn(DOC_B, keys)

    def test_out_of_scope_noop(self):
        review_lock.set_lock(self.sf, "/x/README.md", T0)  # canonical_key None
        self.assertFalse(self.sf.exists() and "review_in_progress" in self.sf.read_text())


def run_cli(args, env_extra=None, sid_env="clitest12", cwd=None):
    env = {**os.environ}
    for k in ("DEVBREW_DISABLE_SPEC_DISTILL", "CLAUDE_CODE_SESSION_ID",
              "DEVBREW_SPEC_DISTILL_SESSION_ID", "DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC"):
        env.pop(k, None)
    if sid_env is not None:
        env["DEVBREW_SPEC_DISTILL_SESSION_ID"] = sid_env
    if env_extra:
        env.update(env_extra)
    return subprocess.run(["python3", str(LOCK_CLI)] + args,
                          env=env, cwd=cwd, capture_output=True, text=True, timeout=10)


class TestReviewLockCLI(unittest.TestCase):
    SID = "clitest12"

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        subprocess.run(["git", "init", "-q"], cwd=self.tmp, check=True)
        self.sf = self.tmp / ".claude" / "spec-distill" / self.SID / "state.local.md"

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_cli_set_then_clear(self):
        doc = str(self.tmp / DOC_A)
        cp = run_cli(["set", self.SID, doc], cwd=self.tmp)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        self.assertIn("review_in_progress:", self.sf.read_text())
        self.assertIn(DOC_A, self.sf.read_text())
        cp2 = run_cli(["clear", self.SID, doc], cwd=self.tmp)
        self.assertEqual(cp2.returncode, 0, cp2.stderr)
        self.assertNotIn(DOC_A, self.sf.read_text())

    def test_cli_pause(self):
        doc = str(self.tmp / DOC_A)
        self.sf.parent.mkdir(parents=True)
        self.sf.write_text(
            f"---\nsession_id: {self.SID}\n---\n\n"
            f"pending_review:\n  path: {doc}\n  mode: design\n  triggered_at: t\n\n"
            f"review_in_progress:\n  - path: {DOC_A}\n    since: {_iso(T0)}\n"
        )
        cp = run_cli(["pause", self.SID, doc], cwd=self.tmp)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        body = self.sf.read_text()
        self.assertNotIn("pending_review:", body)
        self.assertNotIn(DOC_A, body.split("review_in_progress", 1)[-1] if "review_in_progress" in body else "")

    def test_cli_killswitch_noop(self):
        doc = str(self.tmp / DOC_A)
        cp = run_cli(["set", self.SID, doc], env_extra={"DEVBREW_DISABLE_SPEC_DISTILL": "1"}, cwd=self.tmp)
        self.assertEqual(cp.returncode, 0)
        self.assertIn("no-op", cp.stderr)
        self.assertFalse(self.sf.exists())

    def test_cli_bad_session_rejected(self):
        cp = run_cli(["set", "../bad", str(self.tmp / DOC_A)], sid_env=None, cwd=self.tmp)
        self.assertEqual(cp.returncode, 2)

    def test_cli_ttl_env_override(self):  # AC8 — env가 prune 임계에 반영
        doc = str(self.tmp / DOC_A)
        # since=T0(과거), TTL=1초로 override하면 set 시 자기 엔트리는 now라 살아남되
        # 별 엔트리는 prune. 여기선 clear로 재확인: 이미 set된 fresh는 유지.
        run_cli(["set", self.SID, doc], env_extra={"DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC": "1"}, cwd=self.tmp)
        self.assertIn(DOC_A, self.sf.read_text())


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_review_lock.py'`
Expected: FAIL — `ModuleNotFoundError: No module named 'review_lock'` (모듈 아직 없음).

- [ ] **Step 3: `review_lock.py` 구현** — `plugins/spec-distill/scripts/review_lock.py`

```python
#!/usr/bin/env python3
"""spec-distill review-in-progress 락 — document-keyed(multi-key) 단일 소스 (v0.18.0).

subagent(async) dispatch 중 메인 `Stop`이 진행 중인 리뷰를 재강제(중복 A/절단 B)하는
오발을, "그 문서의 리뷰가 진행 중"인 동안만 그 문서의 dispatch를 게이트해 봉쇄한다.

락은 세션-전역 스칼라도 단일 {path,since} 쌍도 아니라 **문서별 엔트리 리스트**
(suppressed_paths와 동형)다 — 인터리브 2-문서 리뷰에서 한 문서의 set이 다른 문서
엔트리를 clobber하지 않게 하기 위함(design R7/AC18).

state.local.md 스키마:
  review_in_progress:
    - path: docs/superpowers/specs/2026-07-01-A-design.md   # canonical_key
      since: 2026-07-01T13:23:53Z
    - path: docs/superpowers/specs/2026-07-01-B-design.md
      since: 2026-07-01T13:40:00Z

시그니처 비대칭(round-4 advisory): set_lock/clear_lock/pause는 state_file을 받아
read-modify-write를 스스로 소유하는 CLI 진입점이고, is_review_active는 이미 state를
1회 읽은 훅이 재-read를 피하도록 body(문자열)를 받는 read-only 판정기다.

Python API: canonical_key(재수출), set_lock, clear_lock, pause, is_review_active.
CLI (skill·bash 호출자): python3 review_lock.py {set|clear|pause} <sid> <raw_path>
Kill switch: DEVBREW_DISABLE_SPEC_DISTILL=1 → no-op.
Env: DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC=<int> (default 1800) — set/clear stale prune 임계.
"""
from __future__ import annotations

import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
HOOKS_DIR = SCRIPT_DIR.parent / "hooks"
sys.path.insert(0, str(SCRIPT_DIR))
sys.path.insert(0, str(HOOKS_DIR))
from state_path import SESSION_PATTERN  # noqa: E402 # pyright: ignore[reportMissingImports]
from suppress_state import (  # noqa: E402 # pyright: ignore[reportMissingImports]
    canonical_key,
    pending_path,
    state_file_for,
    strip_pending,
)

DEFAULT_TTL_SEC = 1800

# 헤더 + 두-줄 엔트리(  - path: … / 4-space since: …)의 0개 이상. suppressed_paths(단일-줄
# `  - <key>`)나 pending_review와 shape이 달라 상호 오매칭 없음.
LOCK_BLOCK_RE = re.compile(
    r"^review_in_progress:\n(?:  - path: [^\n]+\n    since: [^\n]+\n)*",
    re.MULTILINE,
)
ENTRY_RE = re.compile(r"  - path:\s*(?P<path>[^\n]+)\n\s+since:\s*(?P<since>[^\n]+)")


def _ttl_sec() -> int:
    try:
        return int(os.environ.get("DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC", str(DEFAULT_TTL_SEC)))
    except ValueError:
        return DEFAULT_TTL_SEC


def _iso(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_iso(s: str):
    try:
        return datetime.strptime(s.strip(), "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except (ValueError, AttributeError):
        return None


def _parse_entries(body: str) -> list[tuple[str, str]]:
    """review_in_progress 블록의 (canonical_key, since) 리스트. 없으면 []."""
    m = LOCK_BLOCK_RE.search(body)
    if not m:
        return []
    out: list[tuple[str, str]] = []
    for em in ENTRY_RE.finditer(m.group(0)):
        out.append((em.group("path").strip(), em.group("since").strip()))
    return out


def _strip_lock(body: str) -> str:
    return LOCK_BLOCK_RE.sub("", body)


def _render_lock(entries: list[tuple[str, str]]) -> str:
    lines = ["review_in_progress:"]
    for path, since in entries:
        lines.append(f"  - path: {path}")
        lines.append(f"    since: {since}")
    return "\n".join(lines) + "\n"


def _read_or_init(state_file: Path) -> str:
    if state_file.exists():
        try:
            return state_file.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            print(f"[spec-distill] review_lock: state unreadable, re-init: {exc}", file=sys.stderr)
    sid = state_file.parent.name
    return f"---\nsession_id: {sid}\n---\n\n"


def _atomic_write(state_file: Path, body: str) -> None:
    state_file.parent.mkdir(parents=True, exist_ok=True)
    with open(state_file, "w", encoding="utf-8") as f:
        f.write(body)
        f.flush()
        os.fsync(f.fileno())


def _is_stale(since: str, now: datetime, ttl: int) -> bool:
    dt = parse_iso(since)
    if dt is None:
        return True  # unparseable → prune (fail-safe)
    return (now - dt).total_seconds() >= ttl


def _commit(state_file: Path, body: str, entries: list[tuple[str, str]], now: datetime, ttl: int) -> None:
    fresh = [(p, s) for (p, s) in entries if not _is_stale(s, now, ttl)]
    body = _strip_lock(body).rstrip()
    if fresh:
        body = body + "\n\n" + _render_lock(fresh).rstrip()
    _atomic_write(state_file, body + "\n")


def set_lock(state_file: Path, raw_path: str, now: datetime) -> None:
    """그 문서 엔트리를 {path, since: now}로 upsert(refresh). 다른 엔트리 보존.

    매 reviewing-spec 진입(최초 + revise 재진입)에서 호출 — 라운드-간 gap만 TTL에
    걸리고 누적 리뷰시간은 걸리지 않게 하는 refresh-on-reentry(AC1/AC15).
    스코프 밖(canonical_key None) 경로는 no-op.
    """
    key = canonical_key(raw_path)
    if key is None:
        return
    body = _read_or_init(state_file)
    entries = [(p, s) for (p, s) in _parse_entries(body) if p != key]
    entries.append((key, _iso(now)))
    _commit(state_file, body, entries, now, _ttl_sec())


def clear_lock(state_file: Path, raw_path: str) -> None:
    """그 문서 엔트리만 제거. 다른 엔트리 보존. 멱등. approve/cancel이 호출."""
    key = canonical_key(raw_path)
    if key is None or not state_file.exists():
        return
    try:
        body = state_file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return
    entries = [(p, s) for (p, s) in _parse_entries(body) if p != key]
    _commit(state_file, body, entries, datetime.now(timezone.utc), _ttl_sec())


def pause(state_file: Path, raw_path: str) -> None:
    """④ 멈춤: 그 문서 엔트리 제거 + 같은-키 pending strip(suppress 없음 — resumable).

    엔트리만 제거하고 pending을 남기면 즉시 재발동([83dc5425]), 엔트리를 남기면
    bounded under-review 창([fa17d241]) — 둘을 함께 닫는다(AC17). 다른 문서 엔트리·
    pending은 불변.
    """
    key = canonical_key(raw_path)
    if key is None:
        return
    clear_lock(state_file, raw_path)
    if not state_file.exists():
        return
    try:
        body = state_file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return
    pend = pending_path(body)
    if pend is not None and canonical_key(pend) == key:
        _atomic_write(state_file, strip_pending(body).rstrip() + "\n")


def is_review_active(body: str, pending_key: str | None, now: datetime, ttl: int) -> bool:
    """그 pending 문서의 락 엔트리가 존재 + 신선일 때만 True. 그 외 전부 False.

    False(엔트리 부재 / stale / 파싱 불가) → 훅이 정상 dispatch(fail-safe = 강제, Law 1).
    다른 문서 엔트리가 신선해도 pending_key로 조회하므로 이 문서엔 영향 없음(AC16).
    """
    if not pending_key:
        return False
    for path, since in _parse_entries(body):
        if path == pending_key:
            dt = parse_iso(since)
            if dt is None:
                return False
            if (now - dt).total_seconds() >= ttl:
                return False
            return True
    return False


def main(argv: list[str]) -> int:
    if os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1":
        print("[spec-distill] review_lock: DEVBREW_DISABLE_SPEC_DISTILL=1 — no-op", file=sys.stderr)
        return 0
    if len(argv) < 4:
        print("usage: review_lock.py {set|clear|pause} <sid> <raw_path>", file=sys.stderr)
        return 2
    cmd, sid, raw_path = argv[1], argv[2], argv[3]
    if not SESSION_PATTERN.match(sid):
        trunc = sid[:32] + ("..." if len(sid) > 32 else "")
        print(f"[spec-distill] review_lock: session_id rejected: '{trunc}'", file=sys.stderr)
        return 2
    sf = state_file_for(sid)
    if cmd == "set":
        set_lock(sf, raw_path, datetime.now(timezone.utc))
        return 0
    if cmd == "clear":
        clear_lock(sf, raw_path)
        return 0
    if cmd == "pause":
        pause(sf, raw_path)
        return 0
    print(f"[spec-distill] review_lock: unknown subcommand '{cmd}'", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **Step 4: 실행 권한 부여 + 테스트 통과 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && chmod +x plugins/spec-distill/scripts/review_lock.py && python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_review_lock.py' -v`
Expected: PASS — 모든 유닛·CLI 테스트 OK.

- [ ] **Step 5: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/scripts/review_lock.py plugins/spec-distill/tests/test_review_lock.py
git commit -m "feat(spec-distill): add review_lock.py (document-keyed review-in-progress lock)"
```

---

### Task 2: `review-dispatch.py` (Stop 훅) 락 게이트

**Files:**
- Modify: `plugins/spec-distill/hooks/review-dispatch.py` (suppress 블록 뒤, TTL 가드 앞 — 현재 line 151 이후, 152 앞)
- Test: `plugins/spec-distill/tests/test_review_dispatch.sh` (케이스 추가)

**Interfaces:**
- Consumes: `review_lock.is_review_active(body, pending_key, now, ttl)`, `review_lock.canonical_key(raw)` (Task 1). `SCRIPTS_DIR`는 이미 sys.path에 있음(line 35-36).
- Produces: 없음 (훅은 terminal consumer).

- [ ] **Step 1: 실패 테스트 작성** — `test_review_dispatch.sh`의 `# Case 17 ...` 블록 다음, `echo ""` summary 앞에 아래 3케이스 추가

```bash
# Case 18 (AC3): 같은 문서 락 엔트리 신선 + pending → no-op + pending 보존.
NOW18=$(python3 -c 'from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')
setup_state "test-018" "---
session_id: test-018
---

pending_review:
  path: docs/superpowers/specs/2026-07-01-lk-design.md
  mode: design
  triggered_at: 2026-05-16T10:00:00Z

review_in_progress:
  - path: docs/superpowers/specs/2026-07-01-lk-design.md
    since: $NOW18
"
out=$(run_hook "test-018")
rc=$?
sf18="$WORK/.claude/spec-distill/test-018/state.local.md"
[[ $rc -eq 0 ]] && [[ -z "$out" ]] \
  && grep -q '^pending_review:' "$sf18" \
  && note PASS "AC3: fresh same-doc lock → no-op + pending 보존" \
  || note FAIL "AC3 failed (rc=$rc out='$out')"

# Case 19 (AC16): 다른 문서만 락 엔트리 신선, 이 문서 pending → 정상 dispatch(억제 안 됨).
NOW19=$(python3 -c 'from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')
setup_state "test-019" "---
session_id: test-019
---

pending_review:
  path: docs/superpowers/specs/2026-07-01-thisdoc-design.md
  mode: design
  triggered_at: 2026-05-16T10:00:00Z

review_in_progress:
  - path: docs/superpowers/specs/2026-07-01-otherdoc-design.md
    since: $NOW19
"
out=$(run_hook "test-019")
rc=$?
sf19="$WORK/.claude/spec-distill/test-019/state.local.md"
[[ $rc -eq 0 ]] \
  && echo "$out" | jq -e '.decision == "block"' >/dev/null \
  && ! grep -q '^pending_review:' "$sf19" \
  && note PASS "AC16: 다른 문서 락 신선 → 이 문서 정상 dispatch(비억제)" \
  || note FAIL "AC16 failed (rc=$rc out='$out')"

# Case 20 (AC4): 같은 문서 락 엔트리 stale(과거) + pending → dispatch + strip(fail-safe).
setup_state "test-020" "---
session_id: test-020
---

pending_review:
  path: docs/superpowers/specs/2026-07-01-stale-design.md
  mode: design
  triggered_at: 2026-05-16T10:00:00Z

review_in_progress:
  - path: docs/superpowers/specs/2026-07-01-stale-design.md
    since: 2020-01-01T00:00:00Z
"
out=$(run_hook "test-020")
rc=$?
sf20="$WORK/.claude/spec-distill/test-020/state.local.md"
[[ $rc -eq 0 ]] \
  && echo "$out" | jq -e '.decision == "block"' >/dev/null \
  && ! grep -q '^pending_review:' "$sf20" \
  && note PASS "AC4: stale 락 → dispatch + strip(fail-safe = 강제)" \
  || note FAIL "AC4 failed (rc=$rc out='$out')"
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/spec-distill/tests/test_review_dispatch.sh`
Expected: Case 18 FAIL (락 게이트 미구현이라 신선 엔트리에도 `decision:block` emit + pending strip). Case 19/20은 우연히 PASS일 수 있음(현재 락 무시 = 항상 dispatch).

- [ ] **Step 3: 락 게이트 구현** — `review-dispatch.py`의 suppress try/except 블록(현재 line 147-151) 바로 다음, `# TTL guard against self-ref cycle`(현재 line 152) 앞에 삽입

```python
    # Document-keyed review lock (v0.18.0): 이 문서의 리뷰가 in-flight(신선 엔트리)면
    # 재-arm된 pending은 subagent 경계 Stop 오발 — no-op하고 pending을 보존한다.
    # fail-safe = 강제: 엔트리 부재/stale/파싱·import 예외 중 하나라도면 정상 dispatch로
    # 진행(Law 1, over-review > under-review). 다른 문서의 신선 엔트리는 pending_key로
    # 조회하므로 이 문서를 억제하지 않는다(AC16).
    try:
        import review_lock  # scripts/ deferred import, fails-open (AC4)  # pyright: ignore[reportMissingImports]
        try:
            lock_ttl = int(os.environ.get("DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC", "1800"))
        except ValueError:
            lock_ttl = 1800
        pending_key = review_lock.canonical_key(m.group("path").strip())
        if pending_key is not None and review_lock.is_review_active(
            body, pending_key, datetime.now(timezone.utc), lock_ttl
        ):
            return 0  # review in progress for this doc → no dispatch, pending preserved
    except Exception as exc:  # noqa: BLE001 — fail-open to dispatch (Law 1)
        print(
            f"[spec-distill] review-lock check failed (non-fatal, dispatching): {exc}",
            file=sys.stderr,
        )
```

- [ ] **Step 4: 전체 훅 테스트 통과 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/spec-distill/tests/test_review_dispatch.sh`
Expected: `summary: N passed, 0 failed` — 기존 케이스(11–17) 회귀 없이 신규 18/19/20 PASS.

- [ ] **Step 5: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/hooks/review-dispatch.py plugins/spec-distill/tests/test_review_dispatch.sh
git commit -m "feat(spec-distill): Stop hook honors document-keyed review lock"
```

---

### Task 3: `pending-review-reminder.py` (UserPromptSubmit 훅) 락 게이트

**Files:**
- Modify: `plugins/spec-distill/hooks/pending-review-reminder.py` (sys.path에 SCRIPTS_DIR 추가 + `if not m: return 0` 다음·TTL 체크 앞에 게이트)
- Test: `plugins/spec-distill/tests/test_reminder_hook.sh` (케이스 추가)

**Interfaces:**
- Consumes: `review_lock.is_review_active`, `review_lock.canonical_key` (Task 1). reminder 훅은 현재 SCRIPTS_DIR을 path에 넣지 않으므로 추가 필요.
- Produces: 없음.

- [ ] **Step 1: 실패 테스트 작성** — `test_reminder_hook.sh`의 `write_state()` 아래에 락-포함 헬퍼 + AC5 케이스 2개 추가 (AC8 kill switch 케이스 앞에 삽입)

```bash
# --- review lock 게이트 (AC5) 헬퍼: pending + review_in_progress 엔트리 동시 기록 ---
write_state_with_lock() {
  local last_dispatched="$1"; local lock_since="$2"
  cat > "$SDIR/state.local.md" <<EOF
---
session_id: $SID
---

pending_review:
  path: /docs/superpowers/specs/x-design.md
  mode: design
  worktree_path: /Users/foo/.claude/worktrees/wt
  triggered_at: 2026-05-17T00:00:00Z

last_dispatched_at: $last_dispatched

review_in_progress:
  - path: docs/superpowers/specs/x-design.md
    since: $lock_since
EOF
}

# AC5a: 같은 문서 락 신선 → TTL 만료여도 재-emit 안 함(mid-review 재-nag 방지).
OLD5=$(python3 -c 'from datetime import datetime,timezone,timedelta; print((datetime.now(timezone.utc)-timedelta(seconds=60)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
NOW5=$(python3 -c 'from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')
write_state_with_lock "$OLD5" "$NOW5"
out=$(run_hook)
[[ -z "$out" ]] \
  && note PASS "AC5a: fresh same-doc lock → reminder 재-emit 안 함(TTL 만료여도)" \
  || note FAIL "AC5a unexpected output: '$out'"

# AC5b: 락 엔트리 stale → 정상 재-emit(fail-safe = 강제).
write_state_with_lock "$OLD5" "2020-01-01T00:00:00Z"
out=$(run_hook)
echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("reviewing-spec")' >/dev/null \
  && note PASS "AC5b: stale lock → reminder 재-emit(fail-safe)" \
  || note FAIL "AC5b failed. out='$out'"
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/spec-distill/tests/test_reminder_hook.sh`
Expected: AC5a FAIL (락 미구현 → 신선 엔트리에도 재-emit).

- [ ] **Step 3a: sys.path에 SCRIPTS_DIR 추가** — `pending-review-reminder.py` 현재 line 23-25

기존:
```python
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from state_path import state_root as _state_root, resolve_session_id  # noqa: E402
```
변경 후:
```python
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
SCRIPTS_DIR = SCRIPT_DIR.parent / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))
from state_path import state_root as _state_root, resolve_session_id  # noqa: E402
```

- [ ] **Step 3b: 락 게이트 구현** — 현재 line 96-97 `m = PENDING_RE.search(body)` / `if not m: return 0` 다음, TTL 계산(현재 line 98 `try: ttl = ...`) 앞에 삽입

```python
    # Document-keyed review lock (v0.18.0) — Stop 훅과 동일 게이트(AC5): 이 문서의
    # 리뷰가 in-flight(신선 엔트리)면 재-nag하지 않는다. fail-safe = 강제(어떤 예외도
    # 정상 재-emit으로 fall-through).
    try:
        import review_lock  # pyright: ignore[reportMissingImports]
        try:
            lock_ttl = int(os.environ.get("DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC", "1800"))
        except ValueError:
            lock_ttl = 1800
        pending_key = review_lock.canonical_key(m.group("path").strip())
        if pending_key is not None and review_lock.is_review_active(
            body, pending_key, datetime.now(timezone.utc), lock_ttl
        ):
            return 0
    except Exception as exc:  # noqa: BLE001 — fail-open to re-emit (Law 1)
        print(
            f"[spec-distill] review-lock check failed (non-fatal, reminding): {exc}",
            file=sys.stderr,
        )
```

- [ ] **Step 4: 전체 reminder 테스트 통과 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/spec-distill/tests/test_reminder_hook.sh`
Expected: `Fail: 0` — 기존 AC3/AC4/AC4b/AC8 회귀 없이 AC5a/AC5b PASS.

- [ ] **Step 5: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/hooks/pending-review-reminder.py plugins/spec-distill/tests/test_reminder_hook.sh
git commit -m "feat(spec-distill): reminder hook honors document-keyed review lock"
```

---

### Task 4: `reviewing-spec` SKILL.md — set(refresh) + Phase 5 매핑표

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md` (Step 1 + Phase 5 Step C)
- Test: `plugins/spec-distill/tests/test_reviewing_spec_lock.sh` (신규, teeth 락)

**Interfaces:**
- Consumes: `review_lock.py {set|pause}` CLI (Task 1). LLM이 실행하는 bash 명령으로 문서화.
- Produces: 없음.

- [ ] **Step 1: teeth 락 테스트 작성** — `plugins/spec-distill/tests/test_reviewing_spec_lock.sh`

```bash
#!/usr/bin/env bash
# AC14 — reviewing-spec SKILL이 review_lock set(refresh) + Phase 5 ④=pause 매핑을
# body-unique 문구로 문서화했는지 회귀 락. mutation(그 라인 삭제)으로 red 증명.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$REPO_ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md"
pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# body-unique 문구 1: Step 1 refresh 명령 (헤더에 없는 CLI 리터럴).
grep -q 'review_lock.py" set' "$SKILL" \
  && note PASS "AC1: Step 1 review_lock set(refresh) 명령 존재" \
  || note FAIL "AC1: review_lock set 명령 없음"

# body-unique 문구 2: Phase 5 ④=pause 매핑 (CLI 리터럴).
grep -q 'review_lock.py" pause' "$SKILL" \
  && note PASS "AC2: Phase 5 ④=pause 명령 존재" \
  || note FAIL "AC2: review_lock pause 명령 없음"

# teeth 증명: pause 라인을 삭제한 mutation은 grep FAIL 이어야 함(락에 이빨 있음).
MUT=$(mktemp)
grep -v 'review_lock.py" pause' "$SKILL" > "$MUT"
if grep -q 'review_lock.py" pause' "$MUT"; then
  note FAIL "AC14 teeth: mutation 후에도 매칭 — 락 무의미"
else
  note PASS "AC14 teeth: pause 라인 삭제 시 grep red(이빨 증명)"
fi
rm -f "$MUT"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/spec-distill/tests/test_reviewing_spec_lock.sh`
Expected: AC1/AC2 FAIL (SKILL에 아직 명령 없음).

- [ ] **Step 3a: Step 1에 refresh 명령 추가** — SKILL.md의 `## Steps` 항목 1(현재 line 18, "…만 spec-reviewer에게 요청." 로 끝나는 문단) 다음, 항목 2 앞에 새 문단 삽입

```markdown

**리뷰 락 refresh (v0.18.0)** — state 로드 직후, `spec-reviewer` dispatch *전에* 이 문서의 review-in-progress 락을 갱신한다 (매 진입 — 최초 + revise 재진입):

```bash
python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/review_lock.py" set "$session_id" "$spec_path"
```

이 락은 subagent(async) 경계에서 발생하는 메인 `Stop`이 진행 중인 리뷰를 재강제(중복/절단)하지 않도록 `review-dispatch.py`(Stop)와 `pending-review-reminder.py`(UserPromptSubmit)가 참조한다. 락은 **문서별**이라 다른 문서의 최초 강제는 억제하지 않으며, stale(TTL 1800s 초과) 시 강제가 재개된다(fail-safe = 강제).
```

- [ ] **Step 3b: Phase 5 Step C ④ 라인 갱신 + 매핑표 추가** — SKILL.md Step C(현재 line 96) `- **④ 멈춤**: state 보존, 종료.`

기존:
```markdown
- **④ 멈춤**: state 보존, 종료.
```
변경 후:
```markdown
- **④ 멈춤**: `review_lock.py pause`(그 문서 엔트리 제거 + 같은-문서 pending strip, suppress 없이 — resumable) 실행 후 state 보존, 종료. 아래 매핑표 참조.
```

그리고 Step C 전체(현재 line 96 `- **④ 멈춤**` 다음, `### polite stop 금지` 앞)에 매핑표 삽입:

```markdown

### Phase 5 옵션 ↔ 리뷰 락 매핑 (v0.18.0)

| 옵션 | 리뷰 락 동작 |
|---|---|
| ① / ② (approve) | `approve_handoff.sh`가 suppress + `review_lock.py clear`로 **그 문서 엔트리만** 제거. |
| ③ (수정 필요/revise) | clear 안 함 — 다음 `reviewing-spec` 진입 Step 1이 그 문서 엔트리를 refresh. |
| ④ (멈춤/나중에) | `review_lock.py pause`로 **그 문서 엔트리 제거 + 같은-문서 pending strip**(suppress 없이 — resumable). pending strip은 `review_lock.py pause`가 수행. |

④ 멈춤 선택 시 실행:

```bash
python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/review_lock.py" pause "$session_id" "$spec_path"
```

④에서 엔트리만 제거하고 pending을 남기면 즉시 재발동([83dc5425]), 엔트리를 남기면 bounded under-review 창([fa17d241]) — `pause`가 둘을 함께 닫는다. 모든 동작은 **그 문서 엔트리에만** 작용하고 다른 문서 엔트리는 불변(multi-key, [ad4e6c3f]).
```

- [ ] **Step 4: teeth 락 테스트 통과 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/spec-distill/tests/test_reviewing_spec_lock.sh`
Expected: `Fail: 0`.

- [ ] **Step 5: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/spec-distill/tests/test_reviewing_spec_lock.sh
git commit -m "docs(spec-distill): reviewing-spec sets/refreshes review lock + Phase 5 mapping"
```

---

### Task 5: `approve_handoff.sh` — clear 호출 + dead `main_repo` 블록 제거

**Files:**
- Modify: `plugins/spec-distill/scripts/approve_handoff.sh` (현재 line 62-70 dead 블록 제거 + suppress 블록 뒤 clear 호출 추가)
- Test: `plugins/spec-distill/tests/test_approve_handoff.sh` (케이스 추가)

**Interfaces:**
- Consumes: `review_lock.py clear` CLI (Task 1).
- Produces: 없음.

**주의**: `test_cancel_review.py::test_no_prefix_slice_outside_suppress_state`가 `approve_handoff.sh`에서 `docs/superpowers/specs/` 리터럴을 금지한다 — `review_lock.py clear` 호출은 `$spec_path`(raw)를 넘기고 정규화를 위임하므로 리터럴 불필요, 이 계약을 유지한다.

- [ ] **Step 1: 실패 테스트 작성** — `test_approve_handoff.sh`의 Case 4(AC12) 다음, Case 5 앞에 아래 2케이스 추가

```bash
# ── Case 4b (AC6): approve → review_in_progress 그 문서 엔트리 clear ──
WORK=$(mktemp -d); setup_repo "$WORK"
sess="$WORK/.claude/spec-distill/test-sid12"
spec="$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
key="docs/superpowers/specs/2026-01-01-test-spec.md"
otherkey="docs/superpowers/specs/2026-01-01-other-design.md"
NOWLK=$(python3 -c 'from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')
cat > "$sess/state.local.md" <<EOF
---
session_id: test-sid12
---

pending_review:
  path: $spec
  mode: design
  triggered_at: 2026-01-01T00:00:00Z

review_in_progress:
  - path: $key
    since: $NOWLK
  - path: $otherkey
    since: $NOWLK
EOF
bash "$SCRIPT" "test-sid12" "$spec" >/dev/null 2>&1; rc=$?
if [[ $rc -eq 0 ]] \
   && ! grep -q "  - path: $key\$" "$sess/state.local.md" \
   && grep -q "  - path: $otherkey\$" "$sess/state.local.md"; then
    note PASS "case 4b (AC6): approve clears THIS doc lock entry, preserves other"
else
    note FAIL "case 4b (AC6): rc=$rc"
fi
rm -rf "$WORK"

# ── Case 4c (AC12): dead main_repo 블록 부재 (스크립트 소스 grep) ──
if ! grep -qE 'main_repo=|git_common_dir=' "$SCRIPT"; then
    note PASS "case 4c (AC12): dead main_repo/git_common_dir 블록 제거됨"
else
    note FAIL "case 4c (AC12): dead 블록 잔존"
fi
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/spec-distill/tests/test_approve_handoff.sh`
Expected: case 4b FAIL (clear 미구현 → 엔트리 잔존), case 4c FAIL (dead 블록 아직 존재).

- [ ] **Step 3a: dead `main_repo` 블록 제거** — `approve_handoff.sh` 현재 line 63-70

기존 (삭제):
```bash
# ─── Resolve main repo (uses git-common-dir like state_path.py) ───
# NOTE(v0.15.0): v0.14.0에서 `rm -rf "$main_repo/..."`가 제거된 뒤 main_repo는 현재
# 미사용(dead) — 최소 diff로 보존. 제거는 안전한 future trivia.
git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null || echo ".git")
if [[ ! "$git_common_dir" = /* ]]; then
    git_common_dir="$(pwd)/$git_common_dir"
fi
main_repo="$(dirname "$git_common_dir")"
```
→ 이 블록(주석 4줄 + 코드 5줄)을 통째로 제거.

- [ ] **Step 3b: suppress 블록 뒤에 `review_lock.py clear` 호출 추가** — suppress if/else 블록(현재 line 51-61) 다음, dead 블록이 있던 자리(제거 후)에 삽입

```bash
# ─── Clear this doc's review-in-progress lock entry (v0.18.0, AC6) ───
# approve는 리뷰 완료 신호 → 그 문서 락 엔트리 제거(approve/cancel 대칭). raw
# $spec_path를 넘기고 canonical_key 정규화는 review_lock에 위임(specs prefix 리터럴
# 미포함 — test_no_prefix_slice 계약 유지). 다른 문서 엔트리는 불변(multi-key).
lock_cli="$(dirname "$0")/review_lock.py"
if [[ -f "$lock_cli" ]]; then
    python3 "$lock_cli" clear "$session_id" "$spec_path" \
      || echo "[spec-distill] approve_handoff: review-lock clear 실패 (non-fatal)" >&2
fi
```

- [ ] **Step 4: 전체 approve 테스트 통과 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/spec-distill/tests/test_approve_handoff.sh`
Expected: `PASSED` — 기존 7 케이스 + 4b/4c 회귀 없이 통과. `test_no_prefix_slice_outside_suppress_state`도 유지 확인:
Run: `python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_cancel_review.py' -k test_no_prefix_slice`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/scripts/approve_handoff.sh plugins/spec-distill/tests/test_approve_handoff.sh
git commit -m "feat(spec-distill): approve_handoff clears review lock; remove dead main_repo block"
```

---

### Task 6: `cancel_review.py` — clear 대칭

**Files:**
- Modify: `plugins/spec-distill/scripts/cancel_review.py` (suppress 경로들에 `review_lock.clear_lock` 추가)
- Test: `plugins/spec-distill/tests/test_cancel_review.py` (AC11 케이스 추가)

**Interfaces:**
- Consumes: `review_lock.clear_lock(state_file, raw_path)` (Task 1). cancel_review는 이미 SCRIPT_DIR(scripts)을 sys.path에 넣음 → `import review_lock` 가능.
- Produces: 없음.

- [ ] **Step 1: 실패 테스트 작성** — `test_cancel_review.py`의 `TestCancelReview` 클래스에 아래 메서드 추가 (`test_ac19_...` 다음)

```python
    def _seed_lock(self, key_a, key_b):
        from datetime import datetime, timezone
        now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        self.sf.parent.mkdir(parents=True, exist_ok=True)
        self.sf.write_text(
            f"---\nsession_id: {self.SID}\n---\n\n"
            f"review_in_progress:\n"
            f"  - path: {key_a}\n    since: {now}\n"
            f"  - path: {key_b}\n    since: {now}\n"
        )

    def test_ac11_cancel_clears_lock_entry_preserves_other(self):
        self._seed_lock(DOC_A, DOC_B)
        cp = run_cancel([str(self.tmp / DOC_A)], cwd=self.tmp)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        sys.path.insert(0, str(SCRIPTS))
        import review_lock  # noqa
        body = self.sf.read_text()
        entries = dict(review_lock._parse_entries(body))
        self.assertNotIn(DOC_A, entries)   # 취소 문서 락 제거
        self.assertIn(DOC_B, entries)      # 다른 문서 락 불변(AC11)
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_cancel_review.py' -k test_ac11`
Expected: FAIL (`DOC_A`가 여전히 entries에 존재 — clear 미구현).

- [ ] **Step 3a: `import review_lock` 추가** — `cancel_review.py` 현재 line 25-26

기존:
```python
import suppress_state  # noqa: E402 # pyright: ignore[reportMissingImports]
from state_path import resolve_session_id  # noqa: E402 # pyright: ignore[reportMissingImports]
```
변경 후:
```python
import suppress_state  # noqa: E402 # pyright: ignore[reportMissingImports]
import review_lock  # noqa: E402 # pyright: ignore[reportMissingImports]
from state_path import resolve_session_id  # noqa: E402 # pyright: ignore[reportMissingImports]
```

- [ ] **Step 3b: 두 suppress 경로에 clear 추가** — explicit-path 분기(현재 line 65-72)와 현재-pending 분기(현재 line 89-92)

explicit-path 분기 — 현재:
```python
    if target:
        key = suppress_state.canonical_key(target)
        if key is None:
            _advise(f"'{target}' 스코프 밖({suppress_state.PREFIX} 없음) — no-op (AC8)")
            return 1
        suppress_state.suppress_path(sf, target)  # 같은-키 pending만 strip(AC19)
        _advise(f"suppressed {key} this session. 재리뷰: --reset {key}")
        return 0
```
변경 후 (`suppress_path` 다음에 clear 한 줄):
```python
    if target:
        key = suppress_state.canonical_key(target)
        if key is None:
            _advise(f"'{target}' 스코프 밖({suppress_state.PREFIX} 없음) — no-op (AC8)")
            return 1
        suppress_state.suppress_path(sf, target)  # 같은-키 pending만 strip(AC19)
        review_lock.clear_lock(sf, target)        # approve 대칭 — 그 문서 락 제거(AC11)
        _advise(f"suppressed {key} this session. 재리뷰: --reset {key}")
        return 0
```

현재-pending 분기 — 현재:
```python
    suppress_state.suppress_path(sf, pend)
    key = suppress_state.canonical_key(pend) or pend
    _advise(f"cancelled pending review + suppressed {key} this session. 재리뷰: --reset {key}")
    return 0
```
변경 후:
```python
    suppress_state.suppress_path(sf, pend)
    review_lock.clear_lock(sf, pend)              # approve 대칭 — 그 문서 락 제거(AC11)
    key = suppress_state.canonical_key(pend) or pend
    _advise(f"cancelled pending review + suppressed {key} this session. 재리뷰: --reset {key}")
    return 0
```

(참고: `--reset` 분기는 재리뷰 재개 목적이므로 락을 건드리지 않는다 — AC11 "취소 문서만 clear".)

- [ ] **Step 4: 전체 cancel 테스트 통과 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_cancel_review.py' -v`
Expected: 기존 전체 + `test_ac11_...` PASS. `test_no_prefix_slice_outside_suppress_state`도 여전히 PASS (cancel_review에 prefix 리터럴 미추가).

- [ ] **Step 5: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/scripts/cancel_review.py plugins/spec-distill/tests/test_cancel_review.py
git commit -m "feat(spec-distill): cancel-review clears review lock (approve symmetry)"
```

---

### Task 7: 버전 bump + CHANGELOG + README 동기화

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` (0.17.0 → 0.18.0)
- Modify: `plugins/spec-distill/CHANGELOG.md` (`[0.18.0]` 항목)
- Modify: `plugins/spec-distill/README.md` (Hooks Installed / Kill switches / state schema / Principles / Flow 동기화)
- Modify: `plugins/spec-distill/tests/test_readme_sync.sh` (0.17.0 → 0.18.0 + 새 env keyword)

**Interfaces:**
- Consumes: 없음.
- Produces: 없음 (문서/메타).

- [ ] **Step 1: `test_readme_sync.sh` 기대값 갱신(실패 유도)** — 현재 line 1, 13, 15, 20

변경:
- line 1 주석: `# AC16 — README/plugin.json/CHANGELOG synced with v0.18.0 (review-in-progress lock).`
- line 13: `'"version": "0.17.0"'` → `'"version": "0.18.0"'`, note 문구 0.17.0 → 0.18.0.
- line 14: note FAIL 문구 `not 0.17.0` → `not 0.18.0`.
- line 15: `'^## \[0\.17\.0\] — 2026-[0-9]{2}-[0-9]{2}$'` → `'^## \[0\.18\.0\] — 2026-[0-9]{2}-[0-9]{2}$'` + note 문구.
- line 16: note FAIL `[0.17.0]` → `[0.18.0]`.
- line 17: `'^## \[0\.17\.0\].*XX'` → `'^## \[0\.18\.0\].*XX'`.
- line 20 keyword 루프에 새 env 추가:
```bash
for kw in 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' 'DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC' 'review_in_progress' 'interview-brief' 'steelman-builder' 'cancel-review'; do
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/spec-distill/tests/test_readme_sync.sh`
Expected: FAIL — plugin.json/CHANGELOG/README가 아직 0.17.0 및 새 keyword 부재.

- [ ] **Step 3a: `plugin.json` bump** — `plugins/spec-distill/.claude-plugin/plugin.json` line 4

`"version": "0.17.0",` → `"version": "0.18.0",`

- [ ] **Step 3b: CHANGELOG 항목 추가** — `CHANGELOG.md` line 2(`# Changelog`) 다음, `## [0.17.0]` 앞에 삽입

```markdown

## [0.18.0] — 2026-07-02

### Added
- `scripts/review_lock.py` — **document-keyed(multi-key) `review_in_progress` 락**의 단일 소스. `set_lock`(그 키 엔트리 upsert/refresh, 나머지 보존)·`clear_lock`(그 키만 제거)·`pause`(clear + 같은-키 pending strip, suppress 없음 — resumable)·`is_review_active(body, pending_key, now, ttl)` + `{set|clear|pause}` CLI. 원자적 write(flush+fsync), stale prune, kill switch. `canonical_key`는 `suppress_state`에서 import(단일 정규화 소스).
- state.local.md `review_in_progress:` 엔트리 리스트(`suppressed_paths`와 동형) + `DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC` env(default 1800).
- `tests/test_review_lock.py`(유닛+CLI), `tests/test_reviewing_spec_lock.sh`(SKILL teeth 락).

### Changed
- `hooks/review-dispatch.py`(Stop) + `hooks/pending-review-reminder.py`(UserPromptSubmit) — suppress 체크 뒤·TTL 가드 앞에 `is_review_active` 게이트. 이 문서 락이 신선하면 no-op(pending 보존), 엔트리 부재/stale/파싱·import 예외면 정상 dispatch(fail-safe = 강제, Law 1). 다른 문서의 신선 엔트리는 pending_key 조회라 이 문서를 억제하지 않음(AC16).
- `skills/reviewing-spec/SKILL.md` — Step 1(매 진입)에서 `review_lock.py set`으로 그 문서 엔트리 refresh + Phase 5 옵션↔락 매핑표(①②=`approve_handoff.sh` clear, ③=재진입 refresh, ④=`review_lock.py pause`).
- `scripts/approve_handoff.sh` — suppress와 함께 `review_lock.py clear` 호출(그 문서 엔트리만). `scripts/cancel_review.py` — 취소 문서 키 엔트리 `clear`(approve 대칭, AC11).

### Fixed
- **subagent 경계 Stop 재발동**: `reviewing-spec`가 `spec-reviewer`를 async dispatch하고 await하려 턴을 멈출 때 발생하는 메인 `Stop`이, revise로 재-arm된 pending을 집어 리뷰를 (A) 중복 강제 / (B) 흐름 절단하던 오발. 문서별 락으로 "그 문서 리뷰 진행 중"을 표현해 봉쇄하되 리뷰 강제 계약(Law 1/2)은 100% 보존. 인터리브 2-문서 리뷰에서도 각 문서 보호 유지(multi-key, 한 문서 set이 다른 문서 락을 clobber 안 함).

### Removed
- `scripts/approve_handoff.sh`의 dead `git_common_dir`/`main_repo` 블록(v0.14.0에서 `rm -rf` 제거된 뒤 미사용).
```

- [ ] **Step 3c: README 동기화** — `plugins/spec-distill/README.md`

다음 편집을 적용 (grep으로 위치 확인한 현재 라인 기준):

1. **Hooks Installed 표** (현재 line 109 Stop 행, 110 UserPromptSubmit 행) 각각에 v0.18.0 락 문구 추가:
   - Stop 행 트리거 셀 끝에: ` **v0.18.0: `is_review_active` document-keyed 락 조회 — 이 문서 리뷰 in-flight(신선)면 no-op(pending 보존), 부재/stale/예외면 강제(fail-safe).**`
   - UserPromptSubmit 행 트리거 셀 끝에: ` **v0.18.0: 같은 document-keyed 락 존중 — mid-review 재-nag 방지.**`

2. **Kill switches 절**(현재 line 122 `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC` 항목) 다음 라인에 추가:
```markdown
- `DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC=<int>` (v0.18.0) — review-in-progress 락 신선도 임계 (default 1800초=30분). refresh-on-reentry라 실제로 걸리는 건 라운드-간 gap. stale 시 강제 재개(fail-safe). set/clear 시 stale 엔트리 prune 임계로도 사용.
```

3. **Flow 절**(현재 line 45-47의 vNN 노트 라인 뒤)에 한 줄 추가:
```markdown
**v0.18.0**: document-keyed(multi-key) `review_in_progress` 락 — subagent(async) 경계 메인 `Stop`이 진행 중 리뷰를 재강제(중복/절단)하던 오발 봉쇄. `review_lock.py`(set/clear/pause) + Stop·reminder 훅이 `is_review_active`로 게이트. fail-safe = 강제(리뷰 우회 구멍 없음).
```

4. **Principles Instantiated → Three Laws** 절(현재 line 62 AP2 구분 항목 뒤)에 한 줄 추가:
```markdown
- **Law 1 fail-safe + Law 2 (v0.18.0)** — `review_in_progress` 문서별 락이 subagent 경계 Stop 오발만 제거하고 리뷰 강제는 보존. 락 조회의 어떤 실패(부재/stale/파싱·import 예외)도 정상 dispatch로 fail(over-review > under-review). 락 set/clear/pause는 skill·스크립트가, 판정은 훅이 — writer가 자기 리뷰를 억제할 물리적 경로 없음(이 설계 자체가 물리 분리 리뷰어에게 4라운드에 걸쳐 실버그 다수를 잡혔다).
```

(정확한 삽입 지점은 구현 시 README를 열어 위 grep 앵커로 확인. Korean-primary·기존 표 포맷 준수.)

- [ ] **Step 4: 동기화 테스트 통과 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/spec-distill/tests/test_readme_sync.sh`
Expected: `Fail: 0` — 버전 0.18.0 + `review_in_progress` + `DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC` 등 모든 keyword 존재.

- [ ] **Step 5: 전체 회귀 + 커밋**

Run (전체 관련 테스트 회귀 확인):
```bash
cd /Users/jeonghokim/Downloads/devbrew
python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_review_lock.py'
python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_cancel_review.py'
bash plugins/spec-distill/tests/test_review_dispatch.sh
bash plugins/spec-distill/tests/test_reminder_hook.sh
bash plugins/spec-distill/tests/test_approve_handoff.sh
bash plugins/spec-distill/tests/test_reviewing_spec_lock.sh
bash plugins/spec-distill/tests/test_readme_sync.sh
```
Expected: 모두 pass / `Fail: 0`.

Commit:
```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/README.md plugins/spec-distill/tests/test_readme_sync.sh
git commit -m "chore(spec-distill): bump to 0.18.0 (review-in-progress lock) + doc sync"
```

---

## 실행 후 검증 (전 task 완료 후)

- **`/qg` 풀 파이프라인**(security-reviewer + codex 포함) clean — spec Verification Plan 요건. persona 파일(`suppress_state`/락) 무변경, fail-safe 방향 = 강제 유지 확인.
- **AC7 재확인**: `git diff main -- plugins/spec-distill/hooks/spec-write-validator.py`가 비어 있음(무변경).
- **AC9 재확인**: `review-dispatch.py`·`pending-review-reminder.py`의 `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC` 30초 가드 로직 잔존(제거·병합 안 됨).
- PR body: subagent 경계 Stop 오발 재현(라이브 4회) + 4라운드 리뷰 수렴 요약 첨부.
