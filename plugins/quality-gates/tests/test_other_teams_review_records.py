"""다른 팀 읽기가 리뷰 기록 파일(머리 `type: roadmap-review`)을 의도 문서로 싣지 않는다."""
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import intent_origin as io_  # noqa: E402
import other_teams as ot  # noqa: E402

REVIEW_HEAD = "---\ntype: roadmap-review\nroadmap: docs/r/roadmap.md\n---\n"
DESIGN_HEAD = "---\nroadmap: docs/r/roadmap.md\n---\n"
LINE = "리뷰 기록 1개는 다른 팀 근거로 싣지 않았다"


def _git(repo, *args):
    subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t", *args], cwd=repo,
                   check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


class TestReviewRecordsSkipped(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.repo = os.path.join(self.tmp, "repo")
        os.makedirs(self.repo)
        _git(self.repo, "init", "-q", "-b", "main")
        self._write("README.md", "x\n")
        _git(self.repo, "add", "-A")
        _git(self.repo, "commit", "-q", "-m", "first")
        _git(self.repo, "update-ref", "refs/remotes/origin/main", "HEAD")
        _git(self.repo, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main")
        _git(self.repo, "checkout", "-q", "-b", "feature/x")

    def _write(self, rel, text):
        path = os.path.join(self.repo, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)

    def _commit(self):
        _git(self.repo, "add", "-A")
        _git(self.repo, "commit", "-q", "-m", "work")
        _git(self.repo, "checkout", "-q", "main")

    def _text(self):
        return ot.collect(self.repo, self.repo, "main", set(), [], list(io_.DEFAULT_MARKERS),
                          80000, list_prs=lambda r: ([], None))["text"]

    def test_review_record_not_loaded(self):
        self._write("docs/r/reviews/2026-11-22-R1-spec.md", REVIEW_HEAD + "MARK-REVIEW\n")
        self._write("docs/r/specs/x-design.md", DESIGN_HEAD + "MARK-DESIGN\n")
        self._commit()
        text = self._text()
        self.assertIn("MARK-DESIGN", text)
        self.assertNotIn("MARK-REVIEW", text)
        self.assertEqual(text.count(LINE), 1)

    def test_no_line_without_records(self):
        self._write("docs/r/specs/x-design.md", DESIGN_HEAD + "MARK-DESIGN\n")
        self._commit()
        text = self._text()
        self.assertIn("MARK-DESIGN", text)
        self.assertNotIn("다른 팀 근거로 싣지 않았다", text)

    def test_other_roadmaps_records_too(self):
        self._write("docs/q/reviews/2026-11-22-R2-spec.md",
                    "---\ntype: roadmap-review\nroadmap: docs/q/roadmap.md\n---\nMARK-REVIEW\n")
        self._write("docs/r/specs/x-design.md", DESIGN_HEAD + "MARK-DESIGN\n")
        self._commit()
        text = self._text()
        self.assertNotIn("MARK-REVIEW", text)
        self.assertEqual(text.count(LINE), 1)

    def test_branch_still_listed(self):
        self._write("docs/r/reviews/2026-11-22-R1-spec.md", REVIEW_HEAD + "MARK-REVIEW\n")
        self._commit()
        text = self._text()
        self.assertNotIn("MARK-REVIEW", text)
        self.assertIn("그 밖의 브랜치 1개 — 겹침 · 의도 문서 없음", text)
        self.assertEqual(text.count(LINE), 1)


if __name__ == "__main__":
    unittest.main()
