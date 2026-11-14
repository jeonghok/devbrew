"""R2 다른 팀 읽기 — 다른 작업 찾기와 파일 겹침(scripts/other_teams.py)."""
import os
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import test_intent_critic as tic  # noqa: E402 — 헬퍼만 빌린다

ot = tic._load("other_teams")
DEFAULT_REF = "refs/remotes/origin/main"
DAY0 = 1767225600  # 2026-01-01T00:00:00Z — 커밋마다 하루씩 뒤로

ROADMAP_ONE = (tic._fm(type="roadmap")
               + "# 로드맵 하나\n## 에픽\n### R1 — 하나\n- 의도: one-intent-token\n"
               "- 브랜치: feature/mine\n- 경로 예약: a.txt\n## 결정 기록\n- one-decision-token\n")
ROADMAP_TWO = (tic._fm(type="roadmap")
               + "# 로드맵 둘\n## 에픽\n### R1 — 둘\n- 의도: two-intent-token\n"
               "- 브랜치: feature/other\n")


def _run(repo, *args, when=None):
    """픽스처의 git — rc 를 단언한다(조용히 실패한 준비는 테스트를 공허하게 만든다)."""
    env = dict(os.environ)
    if when is not None:
        stamp = "@%d +0000" % when
        env["GIT_COMMITTER_DATE"] = stamp
        env["GIT_AUTHOR_DATE"] = stamp
    proc = subprocess.run(["git", "-C", repo] + list(args), capture_output=True,
                          text=True, encoding="utf-8", env=env)
    if proc.returncode != 0:
        raise AssertionError("git %s → rc %d: %s" % (" ".join(args), proc.returncode, proc.stderr))
    return proc.stdout


class _Clock:
    def __init__(self):
        self.n = 0

    def tick(self):
        self.n += 1
        return DAY0 + self.n * 86400


def _commit(repo, clock, msg, files):
    """files: {경로: 글} — 쓰고 그 경로만 add 한 뒤 커밋한다. 커밋 sha 를 돌려준다."""
    for rel, text in files.items():
        tic._write(text, repo, rel)
    _run(repo, "add", "--", *sorted(files))
    _run(repo, "commit", "-q", "-m", msg, when=clock.tick())
    return _run(repo, "rev-parse", "HEAD").strip()


def _teams_repo(root):
    """다른 팀 픽스처 — 이름 → sha. 원격 없이 update-ref · symbolic-ref 로 ref 만 세운다.

    main(= refs/remotes/origin/main, origin/HEAD → origin/main):
      c0 ── m1(feature/merged 의 merge) ── m2(feature/squashed 를 한 커밋으로) ── m3(feature/rebased 를 새 커밋으로)
    feature/mine(c0 위: k1 · k2) · feature/mine-next(k2 위: n1) · feature/other(c0 위: o1)
    feature/far(c0 위: f1) · feature/merged(g1) · feature/squashed(s1 · s2) · feature/rebased(r1)
    refs/remotes/origin/feature/other = feature/other. 체크아웃은 feature/mine.
    """
    os.makedirs(root, exist_ok=True)
    clock = _Clock()
    _run(root, "init", "-q", "-b", "main")
    _run(root, "config", "user.name", "t")
    _run(root, "config", "user.email", "t@example.com")
    _run(root, "config", "commit.gpgsign", "false")
    shas = {}
    shas["c0"] = _commit(root, clock, "c0", {
        "a.txt": "a\n", "CHANGELOG.md": "# 변경\n",
        "docs/rm/one/roadmap.md": ROADMAP_ONE,
        "docs/rm/one/R2.md": tic._fm(type="epic-bundle", roadmap="docs/rm/one/roadmap.md") + "# 묶음\n",
        "docs/rm/two/roadmap.md": ROADMAP_TWO})

    def branch(name, start="c0"):
        _run(root, "checkout", "-q", "-b", name, shas[start])

    branch("feature/merged")
    shas["g1"] = _commit(root, clock, "g1", {"g.txt": "g\n"})
    branch("feature/squashed")
    shas["s1"] = _commit(root, clock, "s1", {"s.txt": "s1\n"})
    shas["s2"] = _commit(root, clock, "s2", {"s.txt": "s1\ns2\n"})
    branch("feature/rebased")
    shas["r1"] = _commit(root, clock, "r1", {"r.txt": "r\n"})
    branch("feature/other")
    shas["o1"] = _commit(root, clock, "o1", {
        "a.txt": "a\nother\n",
        "team/other-design.md": tic._fm(roadmap="docs/rm/two/roadmap.md") + "# 다른 팀 설계\n"})
    branch("feature/far")
    shas["f1"] = _commit(root, clock, "f1", {"z.txt": "z\n"})
    branch("feature/mine")
    shas["k1"] = _commit(root, clock, "k1", {
        "a.txt": "a\nmine\n",
        "docs/specs/mine-design.md": tic._fm(roadmap="docs/rm/one/roadmap.md") + "# 내 설계\n"})
    shas["k2"] = _commit(root, clock, "k2", {"CHANGELOG.md": "# 변경\n- 내 것\n"})
    branch("feature/mine-next", "k2")
    shas["n1"] = _commit(root, clock, "n1", {"b.txt": "b\n"})

    _run(root, "checkout", "-q", "main")
    _run(root, "merge", "-q", "--no-ff", "--no-edit", "-m", "m1", "feature/merged", when=clock.tick())
    shas["m1"] = _run(root, "rev-parse", "HEAD").strip()
    shas["m2"] = _commit(root, clock, "m2", {"s.txt": "s1\ns2\n"})
    shas["m3"] = _commit(root, clock, "m3", {"r.txt": "r\n"})
    _run(root, "update-ref", DEFAULT_REF, shas["m3"])
    _run(root, "symbolic-ref", "refs/remotes/origin/HEAD", DEFAULT_REF)
    _run(root, "update-ref", "refs/remotes/origin/feature/other", shas["o1"])
    _run(root, "checkout", "-q", "feature/mine")
    return shas


class _NotARepo:
    """git 이 아닌 폴더 — TMPDIR 이 다른 리포 안이어도 위로 찾아 올라가지 않게 천장을 둔다."""

    def __enter__(self):
        self.tmp = tempfile.TemporaryDirectory()
        path = os.path.realpath(os.path.join(self.tmp.name, "plain"))
        os.makedirs(path)
        self.env = mock.patch.dict(os.environ, {"GIT_CEILING_DIRECTORIES": os.path.dirname(path)})
        self.env.start()
        return path

    def __exit__(self, *exc):
        self.env.stop()
        self.tmp.cleanup()


def _names(entries):
    return [e["name"] for e in entries]


def _by_name(entries, name):
    for e in entries:
        if e["name"] == name:
            return e
    raise AssertionError("%s 없음: %s" % (name, _names(entries)))


def _subcommand(args):
    """`-c <k=v>` 앞머리를 건너뛴 git 하위 명령."""
    i = 0
    while i < len(args) and args[i] == "-c":
        i += 2
    return args[i] if i < len(args) else None


class _Fixture(unittest.TestCase):
    """읽기만 하는 테스트가 함께 쓰는 리포(바꾸는 테스트는 _fresh 로 자기 리포를 만든다)."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.repo = os.path.join(cls.tmp.name, "repo")
        cls.shas = _teams_repo(cls.repo)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def _fresh(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        repo = os.path.join(tmp.name, "repo")
        return repo, _teams_repo(repo)

    def _work(self, end="HEAD", repo=None):
        return ot.other_work(repo or self.repo, DEFAULT_REF, end)


class TestDefaultBranch(_Fixture):
    def test_default_branch(self):
        self.assertEqual(ot.default_branch(self.repo), ("main", DEFAULT_REF))

    def test_no_default_branch(self):
        repo, _ = self._fresh()
        _run(repo, "symbolic-ref", "--delete", "refs/remotes/origin/HEAD")
        self.assertIsNone(ot.default_branch(repo))
        _run(repo, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/nope")
        self.assertIsNone(ot.default_branch(repo))

    def test_not_a_repo(self):
        with _NotARepo() as plain:
            self.assertIsNone(ot.default_branch(plain))


class TestOtherWork(_Fixture):
    def test_unmerged_branches_listed(self):
        self.assertEqual(_names(self._work()[0]),
                         ["feature/far", "feature/mine-next", "feature/other"])

    def test_merged_squashed_rebased_excluded(self):
        names = _names(self._work()[0])
        for gone in ("feature/merged", "feature/squashed", "feature/rebased"):
            self.assertNotIn(gone, names)

    def test_review_branch_excluded(self):
        self.assertNotIn("feature/mine", _names(self._work()[0]))

    def test_same_tip_is_one_entry(self):
        names = _names(self._work()[0])
        self.assertNotIn("origin/feature/other", names)
        self.assertEqual(names.count("feature/other"), 1)

    def test_remote_only_branch_named_with_remote(self):
        repo, shas = self._fresh()
        _run(repo, "branch", "-D", "feature/far")
        _run(repo, "update-ref", "refs/remotes/origin/feature/far", shas["f1"])
        self.assertIn("origin/feature/far", _names(self._work(repo=repo)[0]))

    def test_entry_fields(self):
        other = _by_name(self._work()[0], "feature/other")
        self.assertEqual(other["sha"], self.shas["o1"])
        self.assertEqual(other["time"], DAY0 + 6 * 86400)
        self.assertEqual(set(other), {"name", "sha", "time", "paths", "base"})

    def test_paths_from_unreachable_commits(self):
        entries = self._work()[0]
        self.assertEqual(_by_name(entries, "feature/other")["paths"],
                         {"a.txt", "team/other-design.md"})
        self.assertEqual(_by_name(entries, "feature/mine-next")["paths"], {"b.txt"})

    def test_range_end_before_tip(self):
        entries = self._work(end=self.shas["k1"])[0]
        self.assertEqual(_by_name(entries, "feature/mine")["paths"], {"CHANGELOG.md"})

    def test_unreadable_count_is_zero_on_clean_repo(self):
        self.assertEqual(self._work()[1], 0)

    def test_checkout_elsewhere_same(self):
        repo, shas = self._fresh()
        before = ot.other_work(repo, DEFAULT_REF, shas["k2"])
        _run(repo, "checkout", "-q", "feature/far")
        self.assertEqual(ot.other_work(repo, DEFAULT_REF, shas["k2"]), before)
        self.assertEqual(_names(before[0]), ["feature/far", "feature/mine-next", "feature/other"])

    def test_base_is_later_merge_base(self):
        entries = self._work()[0]
        self.assertEqual(_by_name(entries, "feature/mine-next")["base"], self.shas["k2"])
        self.assertEqual(_by_name(entries, "feature/other")["base"], self.shas["c0"])

    def test_failed_branch_counted_not_listed(self):
        real = ot._git
        far = self.shas["f1"]

        def failing(repo, *args):
            if _subcommand(args) == "log" and far in args:
                return subprocess.CompletedProcess(args, 128, b"", b"fatal")
            return real(repo, *args)

        ot._git = failing
        try:
            entries, unreadable = self._work()
        finally:
            ot._git = real
        self.assertEqual(_names(entries), ["feature/mine-next", "feature/other"])
        self.assertEqual(unreadable, 1)

    def test_uncountable_when_refs_unreadable(self):
        with _NotARepo() as plain:
            self.assertEqual(ot.other_work(plain, DEFAULT_REF, "HEAD"), ([], None))

    def test_option_like_rev_refused(self):
        self.assertEqual(ot.other_work(self.repo, "--all", "HEAD"), ([], None))
        self.assertEqual(ot.other_work(self.repo, DEFAULT_REF, "-n1"), ([], None))


class TestOverlaps(_Fixture):
    def test_overlaps(self):
        entries = self._work()[0]
        ot.mark_overlaps(entries, {"a.txt", "CHANGELOG.md"})
        self.assertEqual(_by_name(entries, "feature/other")["overlap"], ["a.txt"])
        self.assertEqual(_by_name(entries, "feature/far")["overlap"], [])
        ot.mark_overlaps(entries, None)
        for e in entries:
            self.assertEqual(e["overlap"], [])

    def test_lit(self):
        self.assertEqual(ot.lit("team/*.md"), ":(literal)team/*.md")


class TestReadOnlyGit(_Fixture):
    def _snapshot(self, repo):
        return (_run(repo, "for-each-ref"), _run(repo, "status", "--porcelain"),
                _run(repo, "symbolic-ref", "HEAD"))

    def test_repo_untouched(self):
        repo, shas = self._fresh()
        before = self._snapshot(repo)
        short, ref = ot.default_branch(repo)
        entries, _ = ot.other_work(repo, ref, shas["k1"])
        ot.mark_overlaps(entries, {"a.txt"})
        self.assertEqual(self._snapshot(repo), before)

    def test_git_forms_run_clean(self):
        real = ot._git
        calls = []

        def recording(repo, *args):
            proc = real(repo, *args)
            calls.append((_subcommand(args), None if proc is None else proc.returncode, args))
            return proc

        ot._git = recording
        try:
            short, ref = ot.default_branch(self.repo)
            entries, unreadable = ot.other_work(self.repo, ref, "HEAD")
            ot.mark_overlaps(entries, {"a.txt"})
        finally:
            ot._git = real
        self.assertEqual(unreadable, 0)
        self.assertEqual({c[0] for c in calls},
                         {"symbolic-ref", "rev-parse", "for-each-ref", "rev-list", "log",
                          "diff", "merge-base"})
        for sub, rc, args in calls:
            self.assertIsNotNone(rc, args)
            if sub == "merge-base" and "--is-ancestor" in args:
                self.assertIn(rc, (0, 1), args)
            else:
                self.assertEqual(rc, 0, args)


if __name__ == "__main__":
    unittest.main()
