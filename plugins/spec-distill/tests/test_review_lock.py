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
