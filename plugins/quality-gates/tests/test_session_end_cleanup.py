"""Tests for the SessionEnd cleanup hook."""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parent.parent / "hooks" / "session-end-cleanup.py"
SID = "endsession12"


def make_session_dir(cwd, sid):
    folder = Path(cwd) / ".claude" / "quality-gates" / sid
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "pipeline.md").write_text("---\nstatus: gate2_running\n---\n")
    (folder / "files.md").write_text("- /abs/x.py\n")
    return folder


def run_hook(cwd, payload, env_extra=None):
    env = os.environ.copy()
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        [sys.executable, str(HOOK)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        cwd=cwd,
        env=env,
    )


class TestSessionEndCleanup(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

    def test_removes_self_folder(self):
        folder = make_session_dir(self.tmp, SID)
        proc = run_hook(self.tmp, {"session_id": SID})
        self.assertEqual(proc.returncode, 0, msg=proc.stderr)
        self.assertFalse(folder.exists())

    def test_idempotent_when_folder_missing(self):
        proc = run_hook(self.tmp, {"session_id": SID})
        self.assertEqual(proc.returncode, 0)

    def test_does_not_touch_other_sessions(self):
        own = make_session_dir(self.tmp, SID)
        other = make_session_dir(self.tmp, "siblingses99")
        run_hook(self.tmp, {"session_id": SID})
        self.assertFalse(own.exists())
        self.assertTrue(other.exists())

    def test_kill_switch(self):
        folder = make_session_dir(self.tmp, SID)
        proc = run_hook(
            self.tmp,
            {"session_id": SID},
            env_extra={"DEVBREW_QUALITY_GATES_DISABLE": "1"},
        )
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(folder.exists())

    def test_empty_session_id_silent_exit(self):
        proc = run_hook(self.tmp, {"session_id": ""})
        self.assertEqual(proc.returncode, 0)

    def test_traversal_session_id_cannot_delete_outside_state_root(self):
        """`session_id` 는 payload 에서 오는 미검증 입력이다.

        이 훅은 spec-distill 쪽과 달리 charset 패턴으로 거르지 않는다. Task 21 이전에는
        `Path(root) / "../../victim"` 이 그대로 `shutil.rmtree` 로 흘러가 state root
        **밖**이 지워졌다(수정 전 판본으로 실측: victim 디렉토리가 삭제됨).
        `gc_common.safe_rmtree` 의 root 검증이 그 자리를 막는다.
        """
        victim = Path(self.tmp) / "victim"
        victim.mkdir()
        (victim / "keep.txt").write_text("살아있어야 한다", encoding="utf-8")
        (Path(self.tmp) / ".claude" / "quality-gates").mkdir(parents=True)

        proc = run_hook(self.tmp, {"session_id": "../../victim", "cwd": self.tmp})

        self.assertEqual(proc.returncode, 0, msg=proc.stderr)
        self.assertTrue(
            victim.exists(),
            msg=f"state root 밖 경로가 삭제됐다 (경로 탈출); stderr={proc.stderr}",
        )
        # 양의 짝: 거부는 **조용하면 안 된다.** stderr 가 비면 삭제 실패가 성공으로 읽힌다.
        self.assertIn("삭제 거부", proc.stderr, msg=f"거부가 조용했다: {proc.stderr!r}")

    def test_removes_dangling_worktree(self):
        """Dangling worktree (no terminal Stop hook fired) is cleaned at SessionEnd."""
        # Set up a git repo with a worktree and state pointing to it
        repo = Path(self.tmp) / "repo"
        repo.mkdir()
        subprocess.run(["git", "init", "-q", "-b", "main"], cwd=repo, check=True)
        subprocess.run(["git", "config", "user.email", "t@t"], cwd=repo, check=True)
        subprocess.run(["git", "config", "user.name", "t"], cwd=repo, check=True)
        subprocess.run(["git", "commit", "-q", "--allow-empty", "-m", "i"],
                       cwd=repo, check=True)
        subprocess.run(["git", "branch", "feat-x"], cwd=repo, check=True)
        wt = repo / ".claude" / "quality-gates" / "worktrees" / "feat-x-abc12345"
        subprocess.run(
            ["git", "worktree", "add", "--detach", str(wt), "feat-x"],
            cwd=repo, check=True, capture_output=True,
        )

        sid = "endsess123456789"
        sdir = repo / ".claude" / "quality-gates" / sid
        sdir.mkdir(parents=True)
        (sdir / "pipeline.md").write_text(
            f'---\nstatus: gate2_running\nworktree_path: "{wt}"\n'
            f'target_branch: "feat-x"\nproject_dir: "{wt}"\n'
            f'session_id: "{sid}"\n---\n'
        )

        proc = run_hook(str(repo), {"session_id": sid})
        self.assertEqual(proc.returncode, 0, msg=proc.stderr)
        self.assertFalse(wt.exists(),
                         msg=f"worktree should be cleaned, stderr={proc.stderr}")
        self.assertFalse(sdir.exists(),
                         msg="session state folder should be cleaned")

    def test_keep_env_preserves_worktree(self):
        """DEVBREW_QUALITY_GATES_KEEP_WORKTREE=1 preserves the worktree at session end."""
        repo = Path(self.tmp) / "repo2"
        repo.mkdir()
        subprocess.run(["git", "init", "-q", "-b", "main"], cwd=repo, check=True)
        subprocess.run(["git", "config", "user.email", "t@t"], cwd=repo, check=True)
        subprocess.run(["git", "config", "user.name", "t"], cwd=repo, check=True)
        subprocess.run(["git", "commit", "-q", "--allow-empty", "-m", "i"],
                       cwd=repo, check=True)
        subprocess.run(["git", "branch", "feat-y"], cwd=repo, check=True)
        wt = repo / ".claude" / "quality-gates" / "worktrees" / "feat-y-def67890"
        subprocess.run(
            ["git", "worktree", "add", "--detach", str(wt), "feat-y"],
            cwd=repo, check=True, capture_output=True,
        )

        sid = "keependsess1234"
        sdir = repo / ".claude" / "quality-gates" / sid
        sdir.mkdir(parents=True)
        (sdir / "pipeline.md").write_text(
            f'---\nstatus: gate2_running\nworktree_path: "{wt}"\n'
            f'target_branch: "feat-y"\nproject_dir: "{wt}"\n'
            f'session_id: "{sid}"\n---\n'
        )

        proc = run_hook(str(repo), {"session_id": sid},
                        env_extra={"DEVBREW_QUALITY_GATES_KEEP_WORKTREE": "1"})
        self.assertEqual(proc.returncode, 0, msg=proc.stderr)
        self.assertTrue(wt.exists(),
                        msg="worktree should be preserved with KEEP=1")
        # State folder is still cleaned (only the worktree is preserved)
        self.assertFalse(sdir.exists(),
                         msg="session state folder should be cleaned")


if __name__ == "__main__":
    unittest.main()
