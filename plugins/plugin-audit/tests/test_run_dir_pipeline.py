"""결정론 끝-끝 — 실행 디렉토리에서 post-1 을 끝까지 돌고 사용자 리포를 더럽히지 않는다
(설계 2026-09-28-audit-folder-removal AC5).

임시 git 리포에는 `.gitignore` 가 없다 — `.claude/` 를 ignore 하지 않는 사용자 리포를 흉내 낸다.
"""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PLUGIN = Path(__file__).resolve().parents[1]
S = PLUGIN / "scripts"
FIX = PLUGIN / "tests" / "fixtures"


def sh(*args, cwd):
    return subprocess.run(list(args), cwd=str(cwd), capture_output=True, text=True)


class TestRunDirPipeline(unittest.TestCase):
    def test_post1_runs_in_run_dir_and_leaves_repo_clean(self):
        with tempfile.TemporaryDirectory() as t:
            repo = Path(t).resolve()
            for cmd in (["git", "init", "-q"],
                        ["git", "-c", "user.name=t", "-c", "user.email=t@t", "commit",
                         "-q", "--allow-empty", "-m", "init"]):
                r = sh(*cmd, cwd=repo)
                self.assertEqual(r.returncode, 0, r.stderr)

            r = sh(sys.executable, str(S / "prepare-run-dir.py"), "project-init",
                   "--repo-root", str(repo), "--date", "2026-09-28", cwd=repo)
            self.assertEqual(r.returncode, 0, r.stderr)
            run_dir = Path(r.stdout.splitlines()[0])
            data, report = run_dir / "audit-data.json", run_dir / "audit.md"

            steps = [
                [sys.executable, str(S / "assemble-audit-data.py"),
                 "--workflow-return", str(FIX / "ac6_workflow_return.json"),
                 "--codex-side", str(FIX / "ac6_codex_side.json"),
                 "--meta", str(FIX / "ac6_meta.json"),
                 "--assigned", str(FIX / "ac6_assigned.json"),
                 "--repo-root", str(repo), "--no-grounding", "--out", str(data)],
                [sys.executable, str(S / "validate-audit-data.py"), "--data", str(data)],
                [sys.executable, str(S / "render-audit-report.py"), str(data), "--out", str(report)],
                [sys.executable, str(S / "validate-audit-data.py"),
                 "--artifacts", str(data), "--report", str(report)],
            ]
            for cmd in steps:
                with self.subTest(step=Path(cmd[1]).name + " " + cmd[2]):
                    r = sh(*cmd, cwd=repo)
                    self.assertEqual(r.returncode, 0, r.stderr)
            self.assertTrue(report.is_file())
            self.assertEqual(sorted(p.name for p in (repo / ".claude" / "plugin-audit").iterdir()),
                             [run_dir.name])

            status = sh("git", "status", "--porcelain", "--untracked-files=all", cwd=repo)
            self.assertEqual(status.returncode, 0, status.stderr)
            self.assertEqual(status.stdout, "", "실행 디렉토리가 사용자 리포의 git status 에 샌다")

            # 양성 대조 — 위 status 검사가 무언가를 볼 수 있다는 증거. 자기-ignore 를 떼면 보여야 한다.
            (run_dir / ".gitignore").unlink()
            status = sh("git", "status", "--porcelain", "--untracked-files=all", cwd=repo)
            self.assertIn("audit.md", status.stdout,
                          "양성 대조 실패 — .gitignore 를 떼도 status 가 비었다 (검사가 공허하다)")


if __name__ == "__main__":
    unittest.main()
