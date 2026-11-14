"""scripts/doc_paths.py 설정 키 넓힘 · scripts/intent_answers.py (쓴소리 답 파일)."""
import importlib.util
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"


def _load(name):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / (name + ".py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


doc_paths = _load("doc_paths")
ia = _load("intent_answers")

AT1 = "2026-11-14T01:02:03Z"
AT2 = "2026-11-14T02:00:00Z"
IDENT = "a.md#D1#방향"


def _git(repo, *args):
    return subprocess.run(["git", "-C", repo] + list(args), capture_output=True,
                          text=True, encoding="utf-8")


def _git_repo(root):
    """임시 git 리포(첫 커밋 포함, user 설정, a.txt · b.txt 추적)를 root 에 만든다."""
    _git(root, "init", "-q", "-b", "main")
    _git(root, "config", "user.name", "t")
    _git(root, "config", "user.email", "t@example.com")
    _git(root, "config", "commit.gpgsign", "false")
    for n in ("a.txt", "b.txt"):
        Path(root, n).write_text("x\n", encoding="utf-8")
    _git(root, "add", "a.txt", "b.txt")
    _git(root, "commit", "-q", "-m", "init")
    return root


def _answer_text(ident=IDENT, answer="의도다", at=AT1):
    return ia.render_answer_file(ident, "Q?", "구절", "고른 라벨", ["  3\t근거"],
                                 answer, answer, "tree abc · dirty no", at)


class TestSettingsKey(unittest.TestCase):
    def test_key_param_detects_change_of_other_key(self):
        k = "DEVBREW_QUALITY_GATES_INTENT_ANSWERS_DIR"
        base = '{"env": {"%s": "a"}}' % k
        head = '{"env": {"%s": "b"}}' % k
        self.assertTrue(doc_paths.settings_key_changed(base, head, key=k))
        self.assertFalse(doc_paths.settings_key_changed(base, head))

    def test_bad_json_counts_as_changed(self):
        self.assertTrue(doc_paths.settings_key_changed("{", "{}", key="X"))


class TestIdentity(unittest.TestCase):
    def test_roundtrip(self):
        i = ia.make_id("docs/a-brief.md", "D13", "방향")
        self.assertEqual(i, "docs/a-brief.md#D13#방향")
        self.assertEqual(ia.split_id(i), ("docs/a-brief.md", "D13", "방향"))

    def test_rejects_bad_parts(self):
        for args in (("/abs.md", "D1", "방향"), ("a/../b.md", "D1", "방향"),
                     ("a.md", "D 1", "방향"), ("a.md", "D1", "모르는종류"),
                     ("a#b.md", "D1", "방향"), ("a.md", "", "방향"), ("a b.md", "D1", "방향")):
            self.assertIsNone(ia.make_id(*args))

    def test_diff_source(self):
        self.assertEqual(ia.make_id("diff", "plugins/x/y.py", "기본값"),
                         "diff#plugins/x/y.py#기본값")

    def test_split_rejects_bad(self):
        for bad in ("a#b", "a#b#c#d", "/x#D1#방향", "a.md#D1#없는종류"):
            self.assertIsNone(ia.split_id(bad))


class TestAnswerFile(unittest.TestCase):
    def test_render_then_parse(self):
        t = ia.render_answer_file(IDENT, "Q?", "구절", "고른 라벨", ["  3\t[e2e] 버튼이 없다"],
                                  "의도다", "의도다 — 일부러", "tree abc · dirty no", AT1)
        p = ia.parse_answer_file(t)
        self.assertEqual((p["id"], p["answer"]), (IDENT, "의도다"))
        self.assertIn("버튼이 없다", p["observation"])
        self.assertEqual(p["answered_at"], AT1)
        self.assertEqual(ia.answer_filename(IDENT, AT1)[:17], "20261114T010203Z-")

    def test_parse_rejects(self):
        good = _answer_text()
        self.assertIsNone(ia.parse_answer_file(good.replace("qg-intent-answer", "other")))
        self.assertIsNone(ia.parse_answer_file(good.replace("answer: 의도다", "answer: 모름")))
        self.assertIsNone(ia.parse_answer_file(good.replace(IDENT, "bad id")))

    def test_parse_accepts_unidentified(self):
        t = _answer_text(ident="unidentified:0123456789ab")
        p = ia.parse_answer_file(t)
        self.assertEqual(p["id"], "unidentified:0123456789ab")

    def test_fake_heading_in_text_does_not_hijack_observation(self):
        t = ia.render_answer_file(IDENT, "Q\n## 근거로 본 관찰\n가짜", "구절", "확정", ["진짜"],
                                  "의도다", "원문", "t", AT1)
        self.assertEqual(ia.parse_answer_file(t)["observation"], "진짜")


class TestReadAnswered(unittest.TestCase):
    def test_read_answered_latest_wins(self):
        with tempfile.TemporaryDirectory() as d:
            Path(d, "1.md").write_text(_answer_text(answer="지금은 모르겠다", at=AT2),
                                       encoding="utf-8")
            Path(d, "2.md").write_text(_answer_text(answer="의도다", at=AT1), encoding="utf-8")
            answered, bad = ia.read_answered(d)
            self.assertEqual(bad, 0)
            self.assertEqual(answered[IDENT]["answer"], "지금은 모르겠다")
            self.assertTrue(answered[IDENT]["path"].endswith("1.md"))

    def test_read_answered_tie_uses_filename(self):
        with tempfile.TemporaryDirectory() as d:
            Path(d, "a.md").write_text(_answer_text(answer="의도다"), encoding="utf-8")
            Path(d, "b.md").write_text(_answer_text(answer="잘못 골랐다"), encoding="utf-8")
            answered, _ = ia.read_answered(d)
            self.assertEqual(answered[IDENT]["answer"], "잘못 골랐다")

    def test_read_answered_skips_broken(self):
        with tempfile.TemporaryDirectory() as d:
            Path(d, "1.md").write_text("no frontmatter\n", encoding="utf-8")
            Path(d, "2.md").write_text("---\nid: [\n---\n", encoding="utf-8")
            Path(d, "3.md").write_text(_answer_text().replace("answer: 의도다", "answer: 모름"),
                                       encoding="utf-8")
            real = Path(d, "real.txt")
            real.write_text(_answer_text(), encoding="utf-8")
            os.symlink(str(real), os.path.join(d, "4.md"))
            answered, bad = ia.read_answered(d)
            self.assertEqual(answered, {})
            self.assertEqual(bad, 4)

    def test_unidentified_left_out_and_not_unreadable(self):
        with tempfile.TemporaryDirectory() as d:
            Path(d, "u.md").write_text(_answer_text(ident="unidentified:0123456789ab"),
                                       encoding="utf-8")
            self.assertEqual(ia.read_answered(d), ({}, 0))

    def test_missing_dir_is_empty(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(ia.read_answered(os.path.join(d, "none")), ({}, 0))


class TestCommitAnswers(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = _git_repo(self.tmp.name)
        self.rel = "docs/qg-intent-answers"
        self.files = [(ia.answer_filename(IDENT, AT1), _answer_text()),
                      (ia.answer_filename("a.md#D2#기본값", AT1),
                       _answer_text(ident="a.md#D2#기본값"))]

    def tearDown(self):
        self.tmp.cleanup()

    def _staged(self):
        return _git(self.root, "diff", "--cached", "--name-only").stdout.split()

    def test_commit_only_answer_files(self):
        Path(self.root, "a.txt").write_text("changed\n", encoding="utf-8")
        _git(self.root, "add", "a.txt")
        Path(self.root, "b.txt").write_text("changed\n", encoding="utf-8")
        Path(self.root, "c.txt").write_text("new\n", encoding="utf-8")
        paths, err = ia.write_answer_files(self.root, self.rel, self.files)
        self.assertIsNone(err)
        self.assertEqual(paths, [self.rel + "/" + n for n, _ in self.files])
        sha, err = ia.commit_answer_files(self.root, paths, "docs(qg): 답")
        self.assertIsNone(err)
        self.assertTrue(sha)
        shown = _git(self.root, "show", "--name-only", "--format=", "HEAD").stdout.split()
        self.assertEqual(sorted(shown), sorted(paths))
        self.assertEqual(self._staged(), ["a.txt"])
        self.assertIn(" M b.txt", _git(self.root, "status", "--porcelain").stdout)
        self.assertIn("?? c.txt", _git(self.root, "status", "--porcelain").stdout)
        self.assertEqual(len(_git(self.root, "log", "--oneline").stdout.splitlines()), 2)

    def test_commit_failure_detached(self):
        paths, _ = ia.write_answer_files(self.root, self.rel, self.files)
        _git(self.root, "checkout", "-q", "--detach")
        sha, err = ia.commit_answer_files(self.root, paths, "m")
        self.assertIsNone(sha)
        self.assertEqual(err, "브랜치가 아니다(detached HEAD)")
        self.assertTrue(os.path.isfile(os.path.join(self.root, paths[0])))
        self.assertEqual(self._staged(), [])

    def test_commit_failure_ignored_dir(self):
        Path(self.root, ".gitignore").write_text("docs/qg-intent-answers/\n", encoding="utf-8")
        paths, _ = ia.write_answer_files(self.root, self.rel, self.files)
        sha, err = ia.commit_answer_files(self.root, paths, "m")
        self.assertIsNone(sha)
        self.assertEqual(err, "답 자리를 git 이 무시한다")
        self.assertTrue(os.path.isfile(os.path.join(self.root, paths[0])))
        self.assertEqual(self._staged(), [])

    def test_commit_failure_ignored_dir_keeps_user_stage(self):
        Path(self.root, "a.txt").write_text("changed\n", encoding="utf-8")
        _git(self.root, "add", "a.txt")
        Path(self.root, ".gitignore").write_text("docs/qg-intent-answers/\n", encoding="utf-8")
        paths, _ = ia.write_answer_files(self.root, self.rel, self.files)
        sha, err = ia.commit_answer_files(self.root, paths, "m")
        self.assertEqual((sha, err), (None, "답 자리를 git 이 무시한다"))
        self.assertEqual(self._staged(), ["a.txt"])

    def test_commit_failure_one_file_ignored(self):
        Path(self.root, "a.txt").write_text("changed\n", encoding="utf-8")
        _git(self.root, "add", "a.txt")
        Path(self.root, ".gitignore").write_text("*%s\n" % self.files[1][0][-20:],
                                                 encoding="utf-8")
        paths, _ = ia.write_answer_files(self.root, self.rel, self.files)
        sha, err = ia.commit_answer_files(self.root, paths, "m")
        self.assertIsNone(sha)
        self.assertEqual(err, "답 자리를 git 이 무시한다")
        self.assertEqual(self._staged(), ["a.txt"])

    def test_commit_failure_unborn_branch_keeps_user_stage(self):
        with tempfile.TemporaryDirectory() as d:
            _git(d, "init", "-q", "-b", "main")
            Path(d, "a.txt").write_text("x\n", encoding="utf-8")
            _git(d, "add", "a.txt")
            Path(d, ".gitignore").write_text("*%s\n" % self.files[1][0][-20:],
                                             encoding="utf-8")
            paths, err = ia.write_answer_files(d, self.rel, self.files)
            self.assertIsNone(err)
            sha, err = ia.commit_answer_files(d, paths, "m")
            self.assertEqual((sha, err), (None, "답 자리를 git 이 무시한다"))
            self.assertEqual(_git(d, "diff", "--cached", "--name-only").stdout.split(),
                             ["a.txt"])

    def test_commit_failure_hook(self):
        Path(self.root, "a.txt").write_text("changed\n", encoding="utf-8")
        _git(self.root, "add", "a.txt")
        hook = Path(self.root, ".git", "hooks", "pre-commit")
        hook.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
        hook.chmod(0o755)
        paths, _ = ia.write_answer_files(self.root, self.rel, self.files)
        sha, err = ia.commit_answer_files(self.root, paths, "m")
        self.assertIsNone(sha)
        self.assertTrue(err.startswith("git commit 실패 — "), err)
        self.assertEqual(self._staged(), ["a.txt"])
        self.assertTrue(os.path.isfile(os.path.join(self.root, paths[0])))

    def test_write_rejects_symlink_and_outside(self):
        with tempfile.TemporaryDirectory() as other:
            os.makedirs(os.path.join(self.root, "docs"))
            os.symlink(other, os.path.join(self.root, "docs", "qg-intent-answers"))
            paths, err = ia.write_answer_files(self.root, self.rel, self.files)
            self.assertEqual((paths, err), ([], "답 자리가 심볼릭 링크다"))
            self.assertEqual(os.listdir(other), [])
            paths, err = ia.write_answer_files(self.root, other, self.files)
            self.assertEqual((paths, err), ([], "답 자리가 리포 밖이다"))
            self.assertEqual(os.listdir(other), [])
            paths, err = ia.write_answer_files(self.root, "../elsewhere", self.files)
            self.assertEqual((paths, err), ([], "답 자리가 리포 밖이다"))

    def test_write_exclusive(self):
        name, text = self.files[0]
        paths, err = ia.write_answer_files(self.root, self.rel, [(name, "old\n")])
        self.assertIsNone(err)
        paths, err = ia.write_answer_files(self.root, self.rel, [(name, text)])
        self.assertEqual((paths, err), ([], "같은 이름의 답 파일이 이미 있다"))
        with open(os.path.join(self.root, self.rel, name), encoding="utf-8") as fh:
            self.assertEqual(fh.read(), "old\n")

    def test_write_partial_returns_written_and_error(self):
        n0, t0 = self.files[0]
        n1, t1 = self.files[1]
        ia.write_answer_files(self.root, self.rel, [(n1, "old\n")])
        paths, err = ia.write_answer_files(self.root, self.rel, [(n0, t0), (n1, t1)])
        self.assertEqual(paths, [self.rel + "/" + n0])
        self.assertEqual(err, "같은 이름의 답 파일이 이미 있다")


if __name__ == "__main__":
    unittest.main()
