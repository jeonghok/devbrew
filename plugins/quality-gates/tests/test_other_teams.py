"""R2 다른 팀 읽기 — 다른 작업 찾기와 파일 겹침(scripts/other_teams.py)."""
import copy
import inspect
import os
import shutil
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
    """files: {경로: 글} — 쓰고 그 경로만 add 한 뒤 커밋한다. 커밋 sha 를 돌려준다.

    경로는 `:(literal)` 로 넘긴다 — `team/*.md` · `:(top)x.md` 같은 이름도 그 파일 하나다.
    """
    for rel, text in files.items():
        tic._write(text, repo, rel)
    _run(repo, "add", "--", *[ot.lit(rel) for rel in sorted(files)])
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


def _assert_logs_hide_signatures(case, calls):
    """적힌 `log` 호출마다 `--no-show-signature` — 사용자 설정 log.showSignature 가 서명 글을 이름 목록에 섞지 않게."""
    logs = [args for sub, _rc, args in calls if sub == "log"]
    case.assertTrue(logs, "log 호출이 없다 — 이 단언이 공허하다")
    for args in logs:
        case.assertIn("--no-show-signature", args)


# 서명 · 검증을 흉내 내는 gpg — 서명된 커밋을 네트워크 · 키 없이 만들고, 검증 때 사람이 읽는 글을 stderr 로 낸다.
FAKE_GPG = ("#!/bin/sh\ncase \" $* \" in\n"
            "  *\" -bsau \"*) cat >/dev/null\n"
            "    printf -- '-----BEGIN PGP SIGNATURE-----\\n\\nZmFrZQ==\\n-----END PGP SIGNATURE-----\\n'\n"
            "    echo '[GNUPG:] SIG_CREATED D 1 8 00 0 X' >&2; exit 0 ;;\n"
            "  *\" --verify \"*) cat >/dev/null\n"
            "    echo 'Good \"fake\" signature' >&2\n"
            "    echo '[GNUPG:] GOODSIG 0 fake'; exit 0 ;;\n"
            "esac\nexit 1\n")


_TEMPLATE = {}


def _copy_teams_repo(dest):
    """픽스처 리포를 한 번 만들고 복사해 준다(커밋을 매번 다시 만들지 않는다) — 이름 → sha."""
    if not _TEMPLATE:
        tmp = tempfile.TemporaryDirectory()
        root = os.path.join(tmp.name, "repo")
        _TEMPLATE.update(tmp=tmp, root=root, shas=_teams_repo(root))
    shutil.copytree(_TEMPLATE["root"], dest, symlinks=True)
    return dict(_TEMPLATE["shas"])


def _frozen(value):
    """메모 키 — 집합 · 목록을 해시되는 꼴로."""
    if isinstance(value, (set, frozenset)):
        return frozenset(value)
    if isinstance(value, (list, tuple)):
        return tuple(_frozen(v) for v in value)
    return value


def tearDownModule():
    if _TEMPLATE:
        _TEMPLATE["tmp"].cleanup()


class _Fixture(unittest.TestCase):
    """읽기만 하는 테스트가 함께 쓰는 리포(바꾸는 테스트는 _fresh 로 자기 리포를 받는다)."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.repo = os.path.join(cls.tmp.name, "repo")
        cls.shas = _copy_teams_repo(cls.repo)
        cls._memo = {}

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def _fresh(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        repo = os.path.join(tmp.name, "repo")
        return repo, _copy_teams_repo(repo)

    def _work(self, end="HEAD", repo=None):
        return ot.other_work(repo or self.repo, DEFAULT_REF, end)

    def _once(self, key, compute):
        """같은 키의 결과는 이 클래스에서 한 번만 계산하고 깊은 복사로 내준다(고친 시험이 다음에 새지 않게)."""
        memo = type(self)._memo
        if key not in memo:
            memo[key] = compute()
        return copy.deepcopy(memo[key])

    def _work_once(self, end="HEAD"):
        """공유 리포의 other_work — mock 안에서는 부르지 않는다(메모가 mock 밖 값을 낸다)."""
        args = (self.repo, DEFAULT_REF, end)
        return self._once(("other_work",) + args, lambda: ot.other_work(*args))

    def _collect_once(self, **kwargs):
        """공유 리포의 _collect — mock 안에서는 부르지 않는다(메모가 mock 밖 값을 낸다)."""
        bound = inspect.signature(_collect).bind(self.repo, **kwargs)
        bound.apply_defaults()
        key = ("collect",) + tuple(_frozen(v) for v in bound.arguments.values())
        return self._once(key, lambda: _collect(*bound.args, **bound.kwargs))


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
        self.assertEqual(_names(self._work_once()[0]),
                         ["feature/far", "feature/mine-next", "feature/other"])

    def test_merged_squashed_rebased_excluded(self):
        names = _names(self._work_once()[0])
        for gone in ("feature/merged", "feature/squashed", "feature/rebased"):
            self.assertNotIn(gone, names)

    def test_review_branch_excluded(self):
        self.assertNotIn("feature/mine", _names(self._work_once()[0]))

    def test_same_tip_is_one_entry(self):
        names = _names(self._work_once()[0])
        self.assertNotIn("origin/feature/other", names)
        self.assertEqual(names.count("feature/other"), 1)

    def test_remote_only_branch_named_with_remote(self):
        repo, shas = self._fresh()
        _run(repo, "branch", "-D", "feature/far")
        _run(repo, "update-ref", "refs/remotes/origin/feature/far", shas["f1"])
        self.assertIn("origin/feature/far", _names(self._work(repo=repo)[0]))

    def test_entry_fields(self):
        other = _by_name(self._work_once()[0], "feature/other")
        self.assertEqual(other["sha"], self.shas["o1"])
        self.assertEqual(other["time"], DAY0 + 6 * 86400)
        self.assertEqual(set(other), {"name", "sha", "time", "paths", "base"})

    def test_paths_from_unreachable_commits(self):
        entries = self._work_once()[0]
        self.assertEqual(_by_name(entries, "feature/other")["paths"],
                         {"a.txt", "team/other-design.md"})
        self.assertEqual(_by_name(entries, "feature/mine-next")["paths"], {"b.txt"})

    def test_range_end_before_tip(self):
        entries = self._work_once(end=self.shas["k1"])[0]
        self.assertEqual(_by_name(entries, "feature/mine")["paths"], {"CHANGELOG.md"})

    def test_unreadable_count_is_zero_on_clean_repo(self):
        self.assertEqual(self._work_once()[1], 0)

    def test_checkout_elsewhere_same(self):
        repo, shas = self._fresh()
        before = ot.other_work(repo, DEFAULT_REF, shas["k2"])
        _run(repo, "checkout", "-q", "feature/far")
        self.assertEqual(ot.other_work(repo, DEFAULT_REF, shas["k2"]), before)
        self.assertEqual(_names(before[0]), ["feature/far", "feature/mine-next", "feature/other"])

    def test_rev_named_files_in_checkout_change_nothing(self):
        """작업 트리의 파일 이름이 rev 와 같아도(`HEAD` · 기본 ref 경로) 결과가 같다."""
        cases = (("HEAD 이름 파일(추적 안 됨)", ("HEAD",), False, "HEAD"),
                 ("HEAD 이름 파일(커밋됨)", ("HEAD",), True, "HEAD"),
                 ("기본 ref 경로 파일(추적 안 됨)", (DEFAULT_REF,), False, "k2"),
                 ("기본 ref 경로 파일(커밋됨)", (DEFAULT_REF,), True, "k2"),
                 ("둘 다(추적 안 됨)", ("HEAD", DEFAULT_REF), False, "HEAD"))
        for label, files, commit, end in cases:
            with self.subTest(label):
                repo, shas = self._fresh()
                rev = shas.get(end, end)
                before = ot.other_work(repo, DEFAULT_REF, rev)
                for rel in files:
                    tic._write("x\n", repo, rel)
                if commit:
                    _run(repo, "add", "--", *files)
                    _run(repo, "commit", "-q", "-m", "rev-named")
                    if rev != "HEAD":  # 리뷰 끝이 새 커밋으로 옮겨 간다 — 남의 작업은 그대로여야 한다
                        rev = _run(repo, "rev-parse", "HEAD").strip()
                after = ot.other_work(repo, DEFAULT_REF, rev)
                self.assertEqual(after[1], 0)
                self.assertEqual(after, before)
                self.assertEqual(_names(after[0]),
                                 ["feature/far", "feature/mine-next", "feature/other"])

    def test_base_is_later_merge_base(self):
        entries = self._work_once()[0]
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

    def test_signed_commits_under_show_signature(self):
        """사용자 설정 log.showSignature=true — 서명된 커밋의 서명 글이 경로 목록 · 커밋 시각에 섞이지 않는다."""
        repo, shas = self._fresh()
        fake = os.path.join(os.path.dirname(repo), "fake-gpg.sh")
        tic._write(FAKE_GPG, fake)
        os.chmod(fake, 0o755)
        for key, value in (("gpg.format", "openpgp"), ("gpg.program", fake),
                           ("user.signingkey", "fake")):
            _run(repo, "config", key, value)
        when = DAY0 + 90 * 86400
        _run(repo, "checkout", "-q", "-b", "feature/signed", shas["c0"])
        tic._write("s\n", repo, "sig.txt")
        _run(repo, "add", "sig.txt")
        _run(repo, "commit", "-q", "-S", "-m", "signed", when=when)
        _run(repo, "checkout", "-q", "feature/mine")
        _run(repo, "config", "log.showSignature", "true")
        # 양성 대조 — 이 설정에서 git 은 서명 글을 이름 목록 앞에 실제로 낸다.
        self.assertIn('Good "fake" signature',
                      _run(repo, "log", "--format=", "--name-only", "-1", "feature/signed"))
        entries, unreadable = self._work(repo=repo)
        self.assertEqual(unreadable, 0)
        self.assertEqual(_by_name(entries, "feature/signed")["paths"], {"sig.txt"})
        self.assertEqual(ot._commit_time(repo, "feature/signed", "sig.txt"), when)

    def test_uncountable_when_refs_unreadable(self):
        with _NotARepo() as plain:
            self.assertEqual(ot.other_work(plain, DEFAULT_REF, "HEAD"), ([], None))

    def test_option_like_rev_refused(self):
        self.assertEqual(ot.other_work(self.repo, "--all", "HEAD"), ([], None))
        self.assertEqual(ot.other_work(self.repo, DEFAULT_REF, "-n1"), ([], None))

    def test_shared_result_is_not_mutated_across_tests(self):
        """같은 인자로 다시 받은 결과에 앞에서 고친 값이 없다."""
        first = self._collect_once(names={"a.txt"})
        first["notices"].append("planted-notice")
        self.assertNotIn("planted-notice", self._collect_once(names={"a.txt"})["notices"])
        entries = self._work_once()[0]
        entries.append({"name": "planted"})
        entries[0]["paths"].add("planted.txt")
        again = self._work_once()[0]
        self.assertNotIn("planted", _names(again))
        self.assertNotIn("planted.txt", again[0]["paths"])


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
        _assert_logs_hide_signatures(self, calls)
        for sub, rc, args in calls:
            self.assertIsNotNone(rc, args)
            if sub == "merge-base" and "--is-ancestor" in args:
                self.assertIn(rc, (0, 1), args)
            else:
                self.assertEqual(rc, 0, args)


# ---------------------------------------------------------------- Task 4 — 기록

ROADMAP_PATH = "docs/rm/one/roadmap.md"
MARKERS = list(ot.io_.DEFAULT_MARKERS)
CAP = 80000
ALWAYS = ("- 원격 브랜치를 새로 받지 않았다 — 오래됐을 수 있다",
          "- 다른 컴퓨터 · 올리지 않은 작업은 볼 수 없음")
INTERVIEW = "- 컨텍스트 쌓기 단계의 팀은 확인 못 함 — 그 문서의 표시가 설정에 없다"


class TestLineInterviewWords(unittest.TestCase):
    def test_line_interview_words(self):
        self.assertIn("컨텍스트 쌓기", ot.LINE_INTERVIEW)
        self.assertNotIn("인터뷰", ot.LINE_INTERVIEW)


def _no_prs(repo):
    return ([], None)


def _collect(repo, names=None, roadmaps=(ROADMAP_PATH,), markers=None, max_bytes=CAP,
             list_prs=_no_prs, review_commit="HEAD", siblings=None):
    return ot.collect(repo, repo, review_commit, names, list(roadmaps),
                      MARKERS if markers is None else markers, max_bytes, list_prs=list_prs,
                      siblings=siblings)


def _on_branch(repo, branch, files, day, msg="more"):
    """branch 에 커밋 하나를 더하고 feature/mine 으로 돌아온다.

    같은 이름의 origin 원격 ref(main 이면 origin/main)도 함께 옮긴다 — 옛 끝에 남은 원격 ref 가
    따로 된 항목이 되지 않게.
    """
    clock = _Clock()
    clock.n = day - 1
    _run(repo, "checkout", "-q", branch)
    sha = _commit(repo, clock, msg, files)
    remote = "refs/remotes/origin/" + branch
    if _run(repo, "for-each-ref", "--format=%(refname)", remote).strip() == remote:
        _run(repo, "update-ref", remote, sha)
    _run(repo, "checkout", "-q", "feature/mine")
    return sha


# 기록의 머리 — 본문(로드맵 · 문서)의 `#` 줄과 가르려고 기록이 쓰는 머리만 끊는 자리로 본다.
_TOP = (ot.HEAD_OVERLAP, ot.HEAD_UNVERIFIED, ot.HEAD_MAP, ot.HEAD_WORK, ot.HEAD_CAP)
_UNIT = ("### 이번 로드맵 ", "### 다른 로드맵 ", "### feature/", "### origin/", "그 밖의 브랜치 ")
_PART = ("#### 의도 문서 ", "#### 겹치는 파일 ")


def _block(text, head):
    """`head` 로 시작하는 줄부터 그 아래 기록 머리 앞까지."""
    if head.startswith("#### "):
        stops = _TOP + _UNIT + _PART
    elif head.startswith("### "):
        stops = _TOP + _UNIT
    else:
        stops = _TOP
    out = None
    for line in text.split("\n"):
        if out is None:
            if line.startswith(head):
                out = [line]
            continue
        if line.startswith(stops):
            break
        out.append(line)
    if out is None:
        raise AssertionError("%r 없음:\n%s" % (head, text))
    while out and out[-1] == "":
        out.pop()
    return "\n".join(out)


def _unit_bytes(text, head):
    return len((_block(text, head) + "\n").encode("utf-8"))


def _unverified(text):
    return ot.summary(text)[1]


def _cap_line(text):
    return _block(text, ot.HEAD_CAP).split("\n")[1]


def _map_bytes(text):
    """기록의 `## 팀 지도` 머리 뒤부터 `## 다른 작업` 앞까지의 바이트 — 실린 지도 항목의 합."""
    start = text.index(ot.HEAD_MAP + "\n") + len(ot.HEAD_MAP) + 1
    end = text.index(ot.HEAD_WORK + "\n")
    return len(text[start:end].encode("utf-8"))


class TestEpicLines(unittest.TestCase):
    def test_epic_lines(self):
        text = ("# 로드맵\n## 에픽\n### R1 — 하나\n- 의도: intent-a\n- 브랜치: feature/x\n"
                "- 묶음: docs/x.md\n- 범위:\n  - 한다: scope-do\n  - 안 한다: scope-dont\n"
                "- 의존: dep-a\n- 경로 예약: path-a\n남는 글 stray-token\n"
                "### 메모\n그냥 글 memo-token\n## 결정 기록\n- decision-a\n### 결정 하나\n"
                "decision-sub\n## 다른 절\nother-section\n")
        out = ot.epic_lines(text)
        for want in ("### R1 — 하나", "- 의도: intent-a", "- 범위:", "  - 한다: scope-do",
                     "  - 안 한다: scope-dont", "- 의존: dep-a", "- 경로 예약: path-a",
                     "## 결정 기록", "- decision-a", "### 결정 하나", "decision-sub"):
            self.assertIn(want + "\n", out)
        for gone in ("- 브랜치:", "- 묶음:", "stray-token", "### 메모", "memo-token",
                     "other-section"):
            self.assertNotIn(gone, out)
        self.assertLess(out.index("### R1 — 하나"), out.index("## 결정 기록"))

    def test_no_epic_blocks(self):
        self.assertEqual(ot.epic_lines("# 그냥 문서\n### 절\n글\n"), "")


class TestTeamMap(_Fixture):
    def test_this_roadmap_from_tree_others_from_default(self):
        repo, _ = self._fresh()
        _on_branch(repo, "feature/other", {"docs/rm/two/roadmap.md": ROADMAP_TWO.replace(
            "two-intent-token", "branch-only-token")}, 50)
        tic._write(ROADMAP_ONE.replace("one-intent-token", "tree-only-token"), repo, ROADMAP_PATH)
        text = _collect(repo)["text"]
        this = _block(text, "### 이번 로드맵 ")
        self.assertTrue(this.startswith("### 이번 로드맵 docs/rm/one/roadmap.md (리뷰 트리)\n"), this)
        self.assertIn("tree-only-token", this)
        self.assertIn("one-decision-token", this)
        other = _block(text, "### 다른 로드맵 ")
        self.assertTrue(other.startswith(
            "### 다른 로드맵 docs/rm/two/roadmap.md (기본 브랜치 main)\n"), other)
        self.assertIn("two-intent-token", other)
        self.assertNotIn("branch-only-token", other)

    def test_sibling_from_tree_when_default_lacks_folder(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        repo = os.path.join(tmp.name, "repo")
        os.makedirs(repo)
        clock = _Clock()
        _run(repo, "init", "-q", "-b", "main")
        _run(repo, "config", "user.name", "t")
        _run(repo, "config", "user.email", "t@example.com")
        _run(repo, "config", "commit.gpgsign", "false")
        base = _commit(repo, clock, "c0", {"x.txt": "x\n"})
        _run(repo, "update-ref", DEFAULT_REF, base)
        _run(repo, "symbolic-ref", "refs/remotes/origin/HEAD", DEFAULT_REF)
        _run(repo, "checkout", "-q", "-b", "feature/mine")
        _commit(repo, clock, "rm", {ROADMAP_PATH: ROADMAP_ONE, "docs/rm/two/roadmap.md": ROADMAP_TWO})
        text = _collect(repo)["text"]
        other = _block(text, "### 다른 로드맵 ")
        self.assertTrue(other.startswith("### 다른 로드맵 docs/rm/two/roadmap.md (리뷰 트리)\n"),
                        other)
        self.assertIn("two-intent-token", other)
        # 리뷰 트리의 링크 폴더도 다른 로드맵으로 읽지 않는다.
        outside = os.path.join(tmp.name, "outside")
        tic._write(ROADMAP_TWO.replace("two-intent-token", "outside-token"), outside, "roadmap.md")
        os.symlink(outside, os.path.join(repo, "docs/rm/link"))
        _run(repo, "add", "--", "docs/rm/link")
        text = _collect(repo)["text"]
        self.assertNotIn("outside-token", text)
        self.assertNotIn("docs/rm/link", text)

    def test_symlinked_roadmap_folder_skipped(self):
        repo, _ = self._fresh()
        outside = os.path.join(os.path.dirname(repo), "outside")
        tic._write(ROADMAP_TWO.replace("two-intent-token", "outside-token"), outside, "roadmap.md")
        _run(repo, "checkout", "-q", "main")
        os.symlink(outside, os.path.join(repo, "docs/rm/link"))
        _run(repo, "add", "--", "docs/rm/link")
        _run(repo, "commit", "-q", "-m", "link")
        _run(repo, "update-ref", DEFAULT_REF, _run(repo, "rev-parse", "HEAD").strip())
        _run(repo, "checkout", "-q", "feature/mine")
        text = _collect(repo)["text"]
        self.assertNotIn("outside-token", text)
        self.assertNotIn("docs/rm/link", text)
        self.assertIn("two-intent-token", text)

    def test_other_roadmaps_recent_first(self):
        """다른 로드맵은 기본 브랜치에서 마지막으로 바뀐 것이 먼저다(경로 순이 아니다)."""
        repo, _ = self._fresh()
        _on_branch(repo, "main", {"docs/rm/a-zero/roadmap.md": ROADMAP_TWO.replace(
            "two-intent-token", "zero-intent-token")}, 50)
        _on_branch(repo, "main", {"docs/rm/two/roadmap.md": ROADMAP_TWO + "- 범위: later\n"}, 51)
        text = _collect(repo)["text"]
        self.assertLess(text.index("### 다른 로드맵 docs/rm/two/roadmap.md"),
                        text.index("### 다른 로드맵 docs/rm/a-zero/roadmap.md"))

    def test_no_roadmap(self):
        result = _collect(self.repo, roadmaps=[])
        self.assertIn("- 로드맵 없음", _unverified(result["text"]))
        self.assertNotIn("### 이번 로드맵", result["text"])
        self.assertNotIn("### 다른 로드맵", result["text"])

    def test_rejected_roadmap_path_not_followed(self):
        """신뢰 경계에서 거부된 로드맵 경로로는 나란한 폴더를 찾지 않는다."""
        for rel, why in (("../rm/one/roadmap.md", "상위 경로(..)"),
                         ("docs/rm/three/roadmap.md", "추적 안 된 파일 또는 없음")):
            with self.subTest(rel):
                text = _collect(self.repo, roadmaps=[rel])["text"]
                self.assertIn("- 로드맵 %s 를 읽지 못함 — %s" % (rel, why), _unverified(text))
                self.assertNotIn("### 다른 로드맵", text)
                self.assertNotIn("다른 로드맵을 찾지 못함", text)

    def test_roadmap_given_is_not_listed_as_missing(self):
        self.assertNotIn("- 로드맵 없음", _unverified(_collect(self.repo)["text"]))


NO_EPIC_ONE = "- 로드맵 docs/rm/one/roadmap.md 를 읽었지만 에픽 블록을 찾지 못함 — 글자 꼴이 다를 수 있다"
NO_EPIC_TWO = "- 로드맵 docs/rm/two/roadmap.md 를 읽었지만 에픽 블록을 찾지 못함 — 글자 꼴이 다를 수 있다"


def _no_epic_lines(text):
    """「확인 못 함」 줄 가운데 에픽 블록을 못 찾았다는 줄."""
    out = []
    for line in _unverified(text):
        if "에픽 블록을 찾지 못함" in line:
            out.append(line)
    return out


class TestNoEpicRoadmap(_Fixture):
    """읽었는데 에픽 블록이 없는 로드맵 — 「에픽 없음」 과 「글자 꼴이 달라 못 읽음」 을 가리지 못하니 「확인 못 함」 에 남긴다."""

    def _with_this_roadmap(self, body):
        repo, _ = self._fresh()
        tic._write(tic._fm(type="roadmap") + body, repo, ROADMAP_PATH)
        return _collect(repo)["text"]

    def test_this_roadmap_without_epic_block(self):
        text = self._with_this_roadmap("# 로드맵\n## 에픽\n### R1 — 하나\n- 브랜치: feature/x\n")
        self.assertEqual(_no_epic_lines(text), [NO_EPIC_ONE])
        self.assertEqual(ot.LINE_NO_EPIC % ROADMAP_PATH, NO_EPIC_ONE[2:])
        self.assertIn("### 이번 로드맵 docs/rm/one/roadmap.md (리뷰 트리)\n", text)

    def test_marker_shape_differs(self):
        for mark in ("- 의도 : x-intent", "**의도**: x-intent", "* 의도: x-intent", "-의도: x-intent"):
            with self.subTest(mark):
                text = self._with_this_roadmap("# 로드맵\n## 에픽\n### R1 — 하나\n%s\n" % mark)
                self.assertEqual(_no_epic_lines(text), [NO_EPIC_ONE])

    def test_decisions_only(self):
        text = self._with_this_roadmap("# 로드맵\n## 결정 기록\n- only-decision-token\n")
        self.assertEqual(_no_epic_lines(text), [NO_EPIC_ONE])
        self.assertIn("only-decision-token", _block(text, "### 이번 로드맵 "))

    def test_roadmap_with_epics_has_no_line(self):
        text = _collect(self.repo)["text"]
        self.assertIn("one-intent-token", text)
        self.assertIn("two-intent-token", text)
        self.assertEqual(_no_epic_lines(text), [])
        self.assertNotIn("에픽 블록을 찾지 못함", text)

    def test_sibling_without_epic_names_sibling(self):
        repo, _ = self._fresh()
        _on_branch(repo, "main", {"docs/rm/two/roadmap.md": tic._fm(type="roadmap")
                                  + "# 로드맵 둘\n## 에픽\n### R1 — 둘\n- 의도 : two-shape-token\n"}, 50)
        text = _collect(repo)["text"]
        self.assertEqual(_no_epic_lines(text), [NO_EPIC_TWO])
        self.assertIn("### 다른 로드맵 docs/rm/two/roadmap.md (기본 브랜치 main)\n", text)

    def test_control_characters_in_name_stay_one_line(self):
        repo, _ = self._fresh()
        odd = "docs/rm/evil\n## 팀 지도\r- 가짜\x1b/roadmap.md"
        shown = "docs/rm/evil?## 팀 지도?- 가짜?/roadmap.md"
        real = ot.io_.read_tree

        def read_tree(tree_root, rel):
            if rel == odd:
                return ("# 로드맵\n## 에픽\n### R1\n- 브랜치: x\n", None)
            return real(tree_root, rel)

        with mock.patch.object(ot.io_, "read_tree", read_tree):
            text = _collect(repo, roadmaps=[odd])["text"]
        want = "- " + ot.LINE_NO_EPIC % shown
        self.assertEqual(_no_epic_lines(text), [want])
        self.assertEqual(text.count("\n" + ot.HEAD_MAP + "\n"), 1)
        for line in _unverified(text):
            self.assertTrue(line.startswith("- "), line)
            self.assertNotIn("가짜", line.replace(want, ""))


class TestOtherWorkRecord(_Fixture):
    def test_intent_doc_in_any_folder(self):
        text = self._collect_once()["text"]
        block = _block(text, "### feature/other ")
        self.assertIn("#### 의도 문서 team/other-design.md\n", block)
        self.assertIn("# 다른 팀 설계", block)

    def test_model_read_file_is_not_intent_doc(self):
        """「문서 파일」 은 넓이 판정과 같은 뜻 — 모델이 읽는 파일은 머리가 같아도 의도 문서가 아니다."""
        repo, _ = self._fresh()
        head = tic._fm(roadmap="docs/rm/two/roadmap.md")
        _on_branch(repo, "feature/far", {"skills/x/SKILL.md": head + "skill-token\n",
                                         "docs/plain-design.md": head + "plain-token\n"}, 50)
        block = _block(_collect(repo)["text"], "### feature/far ")
        self.assertIn("#### 의도 문서 docs/plain-design.md\n", block)
        self.assertIn("plain-token", block)
        self.assertNotIn("skills/x/SKILL.md", block)
        self.assertNotIn("skill-token", block)

    def test_branch_heading_shape(self):
        text = self._collect_once(names={"a.txt"})["text"]
        head = _block(text, "### feature/other ").split("\n")[0]
        self.assertEqual(head, "### feature/other · %s · 2026-01-07 · 열린 PR 없음"
                         % self.shas["o1"][:7])

    def test_marker_added_loads_doc(self):
        repo, _ = self._fresh()
        _on_branch(repo, "feature/far",
                   {"notes/seed.md": tic._fm(type="seed") + "# 씨앗 seed-token\n"}, 50)
        added = _collect(repo, markers=MARKERS + ["type=seed"])["text"]
        self.assertIn("#### 의도 문서 notes/seed.md\n", added)
        self.assertIn("seed-token", added)
        self.assertNotIn(INTERVIEW, _unverified(added))
        plain = _collect(repo)["text"]
        self.assertNotIn("seed-token", plain)
        self.assertIn(INTERVIEW, _unverified(plain))

    def test_overlap_listed_with_diff(self):
        text = self._collect_once(names={"a.txt"})["text"]
        self.assertEqual(ot.summary(text)[0], ["- feature/other — a.txt"])
        diff = _block(text, "#### 겹치는 파일 a.txt")
        self.assertIn("+other", diff)
        self.assertIn("diff --git", diff)

    def test_no_overlap(self):
        text = self._collect_once(names={"q.txt"})["text"]
        self.assertEqual(ot.summary(text)[0], ["- 겹침 없음"])
        self.assertEqual(ot.NO_OVERLAP, "- 겹침 없음")
        self.assertEqual(ot.OVERLAP_UNKNOWN, "- 겹침 확인 못 함")

    def test_names_unknown(self):
        text = self._collect_once(names=None)["text"]
        self.assertEqual(ot.summary(text)[0], ["- 겹침 확인 못 함"])
        self.assertIn("- 바뀐 파일 목록을 몰라 파일 겹침을 확인 못 함", _unverified(text))
        self.assertNotIn("- 바뀐 파일 목록을 몰라 파일 겹침을 확인 못 함",
                         _unverified(self._collect_once(names={"q.txt"})["text"]))

    def test_rest_counted(self):
        text = self._collect_once(names={"a.txt"})["text"]
        work = _block(text, ot.HEAD_WORK)
        self.assertIn("\n그 밖의 브랜치 2개 — 겹침 · 의도 문서 없음", work)
        self.assertNotIn("### feature/far", work)
        self.assertNotIn("### feature/mine-next", work)

    def test_pr_attached_and_foreign_pr(self):
        def prs(repo):
            return ([{"number": 7, "title": "다른 팀 설계", "branch": "feature/other"},
                     {"number": 9, "title": "포크", "branch": "fork/x"},
                     {"number": 3, "title": "내 것", "branch": "feature/mine"}], None)

        text = _collect(self.repo, names={"a.txt", "z.txt"}, list_prs=prs)["text"]
        self.assertIn("- feature/other · PR #7 다른 팀 설계 — a.txt", ot.summary(text)[0])
        unverified = _unverified(text)
        self.assertIn("- PR #9 내용 확인 못 함 — 그 브랜치가 이 리포에 없다", unverified)
        self.assertNotIn("- PR #3 내용 확인 못 함 — 그 브랜치가 이 리포에 없다", unverified)
        self.assertTrue(_block(text, "### feature/far ").split("\n")[0].endswith(" · 열린 PR 없음"))
        self.assertTrue(_block(text, "### feature/other ").split("\n")[0].endswith(
            " · PR #7 다른 팀 설계"))

    def test_pr_on_hidden_same_tip_name(self):
        """끝 커밋이 같은 둘째 이름(원격 이름 포함)의 PR 도 그 항목에 붙는다(T4-5)."""
        repo, shas = self._fresh()
        _run(repo, "branch", "feature/other-alias", shas["o1"])

        def prs(_repo):
            return ([{"number": 8, "title": "별칭", "branch": "feature/other-alias"}], None)

        text = _collect(repo, names={"a.txt"}, list_prs=prs)["text"]
        self.assertIn("- feature/other · PR #8 별칭 — a.txt", ot.summary(text)[0])
        self.assertNotIn("- PR #8 내용 확인 못 함 — 그 브랜치가 이 리포에 없다", _unverified(text))

    def test_pr_on_remote_only_branch(self):
        repo, shas = self._fresh()
        _run(repo, "branch", "-D", "feature/far")
        _run(repo, "update-ref", "refs/remotes/origin/feature/far", shas["f1"])

        def prs(_repo):
            return ([{"number": 5, "title": "먼 것", "branch": "feature/far"}], None)

        text = _collect(repo, names={"z.txt"}, list_prs=prs)["text"]
        self.assertIn("- origin/feature/far · PR #5 먼 것 — z.txt", ot.summary(text)[0])

    def test_fork_prs_never_attached(self):
        """포크 PR 은 머리 이름이 main · 다른 팀 브랜치 · 리뷰 브랜치와 같아도 붙지 않고 늘 한 줄씩 적힌다."""
        def prs(_repo):
            return ([{"number": 7, "title": "같은 리포", "branch": "feature/other", "fork": False},
                     {"number": 11, "title": "포크 main", "branch": "main", "fork": True},
                     {"number": 12, "title": "fork collides", "branch": "feature/other",
                      "fork": True},
                     {"number": 13, "title": "포크 리뷰", "branch": "feature/mine", "fork": True}],
                    None)

        text = _collect(self.repo, names={"a.txt"}, list_prs=prs)["text"]
        overlap, unverified = ot.summary(text)
        self.assertEqual(overlap, ["- feature/other · PR #7 같은 리포 — a.txt"])
        for number in (11, 12, 13):
            self.assertIn("- PR #%d 내용 확인 못 함 — 그 브랜치가 이 리포에 없다" % number, unverified)
        self.assertNotIn("- PR #7 내용 확인 못 함 — 그 브랜치가 이 리포에 없다", unverified)
        self.assertNotIn("fork collides", text)
        self.assertNotIn("포크 main", text)
        self.assertTrue(_block(text, "### feature/other ").split("\n")[0].endswith(
            " · PR #7 같은 리포"))

    def test_gh_unavailable(self):
        text = _collect(self.repo, names={"a.txt"},
                        list_prs=lambda repo: (None, "gh 없음"))["text"]
        self.assertIn("- 열린 PR 확인 못 함 — gh 없음", _unverified(text))
        self.assertTrue(_block(text, "### feature/other ").split("\n")[0].endswith(
            " · 열린 PR 확인 못 함"))

    def test_no_default_branch(self):
        repo, _ = self._fresh()
        _run(repo, "symbolic-ref", "--delete", "refs/remotes/origin/HEAD")
        called = []
        text = _collect(repo, names={"a.txt"},
                        list_prs=lambda r: called.append(r) or ([], None))["text"]
        self.assertIn("- 기본 브랜치를 찾지 못함 — 다른 브랜치와 다른 로드맵을 읽지 않았다",
                      _unverified(text))
        self.assertEqual(ot.summary(text)[0], ["- 겹침 확인 못 함"])
        self.assertEqual(_block(text, ot.HEAD_WORK), ot.HEAD_WORK)
        self.assertIn("one-intent-token", _block(text, "### 이번 로드맵 "))
        self.assertNotIn("### 다른 로드맵", text)
        self.assertEqual(called, [])

    def test_unreadable_branches_counted(self):
        real = ot._git
        far = self.shas["f1"]

        def failing(repo, *args):
            if _subcommand(args) == "log" and far in args:
                return subprocess.CompletedProcess(args, 128, b"", b"fatal")
            return real(repo, *args)

        with mock.patch.object(ot, "_git", failing):
            text = _collect(self.repo, names={"a.txt"})["text"]
        self.assertIn("- 읽지 못한 브랜치 1개", _unverified(text))
        # 일부만 못 읽었으면 읽은 브랜치의 겹침은 그대로 — 빈 곳은 위 줄이 공시한다.
        self.assertEqual(ot.summary(text)[0], ["- feature/other — a.txt"])
        with mock.patch.object(ot, "_git", failing):
            none_found = _collect(self.repo, names={"q.txt"})["text"]
        self.assertEqual(ot.summary(none_found)[0], ["- 겹침 없음"])
        self.assertNotIn("- 읽지 못한 브랜치", "\n".join(_unverified(self._collect_once()["text"])))

    def test_branch_list_unreadable(self):
        with mock.patch.object(ot, "other_work", lambda repo, ref, end, notes=None: ([], None)):
            text = _collect(self.repo, names={"a.txt"})["text"]
        self.assertIn("- 브랜치 목록을 읽지 못함 — 다른 브랜치를 읽지 않았다", _unverified(text))
        self.assertEqual(ot.summary(text)[0], ["- 겹침 확인 못 함"])

    def test_unreadable_frontmatter_named(self):
        """다른 브랜치 문서의 머리가 YAML 로 읽히지 않는다(없는 날짜) — 기록은 쓰이고 다른 브랜치도 그대로,
        그 브랜치 · 문서는 「확인 못 함」 에 이름으로 남는다."""
        repo, _ = self._fresh()
        bad = "---\ncreated_at: 2026-02-30\nroadmap: docs/rm/two/roadmap.md\n---\n# 틀린 머리\n"
        _on_branch(repo, "feature/far", {"docs/bad-design.md": bad}, 50)
        text = _collect(repo, names={"a.txt"})["text"]
        self.assertIn("- feature/far 의 docs/bad-design.md 머리를 읽지 못함 — 의도 문서인지 확인 못 함",
                      _unverified(text))
        self.assertEqual(ot.summary(text)[0], ["- feature/other — a.txt"])
        self.assertIn("#### 의도 문서 team/other-design.md\n", _block(text, "### feature/other "))
        self.assertNotIn("#### 의도 문서 docs/bad", text)
        self.assertIn(ot.HEAD_CAP, text)

    def test_one_failing_branch_is_contained(self):
        """브랜치 하나의 읽기가 예외로 끝나도 기록 전체를 잃지 않는다 — 그 브랜치 이름이 든 「확인 못 함」 한 줄."""
        real_docs, real_unit = ot._intent_docs, ot._branch_unit

        def docs(repo, entry, *rest):
            if entry["name"] == "feature/other":
                raise RuntimeError("x")
            return real_docs(repo, entry, *rest)

        with mock.patch.object(ot, "_intent_docs", docs):
            text = _collect(self.repo, names={"a.txt", "z.txt"})["text"]
        self.assertIn("- 브랜치 feature/other 를 읽지 못함 — RuntimeError", _unverified(text))
        # 겹침은 경로 목록에서 이미 안다 — 목록에 그대로 남는다.
        self.assertIn("- feature/other — a.txt", ot.summary(text)[0])
        self.assertIn("### feature/far ", text)
        self.assertNotIn("#### 의도 문서 team/other-design.md", text)

        def unit(repo, entry, *rest):
            if entry["name"] == "feature/far":
                raise OverflowError("x")
            return real_unit(repo, entry, *rest)

        with mock.patch.object(ot, "_branch_unit", unit):
            text = _collect(self.repo, names={"a.txt", "z.txt"})["text"]
        self.assertIn("- 브랜치 feature/far 를 읽지 못함 — OverflowError", _unverified(text))
        self.assertNotIn("### feature/far ", text)
        self.assertIn("#### 의도 문서 team/other-design.md\n", _block(text, "### feature/other "))
        self.assertIn("- feature/far — z.txt", ot.summary(text)[0])

    def test_worktree_count(self):
        repo, _ = self._fresh()
        line = "- 다른 worktree 1개의 커밋 안 된 작업은 읽지 않았다"
        self.assertNotIn(line, _unverified(_collect(repo)["text"]))
        _run(repo, "worktree", "add", "-q", os.path.join(os.path.dirname(repo), "wt"),
             "feature/far")
        self.assertIn(line, _unverified(_collect(repo)["text"]))

    def test_always_lines(self):
        for kwargs in ({}, {"roadmaps": []}, {"names": {"a.txt"}}):
            with self.subTest(kwargs):
                unverified = _unverified(self._collect_once(**kwargs)["text"])
                for line in ALWAYS:
                    self.assertIn(line, unverified)

    def test_not_a_repo_fails_as_values(self):
        with _NotARepo() as plain:
            result = ot.collect(plain, plain, "HEAD", {"a.txt"}, [ROADMAP_PATH], MARKERS, CAP,
                                list_prs=_no_prs)
        unverified = _unverified(result["text"])
        self.assertIn("- 기본 브랜치를 찾지 못함 — 다른 브랜치와 다른 로드맵을 읽지 않았다",
                      unverified)
        self.assertTrue(any(line.startswith("- 로드맵 docs/rm/one/roadmap.md 를 읽지 못함 — ")
                            for line in unverified), unverified)


class TestCap(_Fixture):
    def test_cap_order_and_disclosure(self):
        full = _collect(self.repo, names={"a.txt"})
        self.assertEqual(_cap_line(full["text"]), "상한 %d바이트 안에 3개를 모두 실었다" % CAP)
        self.assertEqual(full["notices"], [])
        cap = _map_bytes(full["text"])
        tight = _collect(self.repo, names={"a.txt"}, max_bytes=cap)
        text = tight["text"]
        self.assertIn("one-intent-token", text)
        self.assertIn("two-intent-token", text)
        self.assertNotIn("### feature/other", _block(text, ot.HEAD_WORK))
        line = "상한 %d바이트 — 3개 중 2개만 실었다(뺀 것: feature/other)" % cap
        self.assertEqual(_cap_line(text), line)
        self.assertEqual(tight["notices"], [line])
        # 앞 두 절은 상한과 무관하게 실린다.
        self.assertEqual(ot.summary(text)[0], ["- feature/other — a.txt"])

    def test_order_maps_then_overlap_then_rest(self):
        repo, _ = self._fresh()
        _on_branch(repo, "feature/far", {
            "docs/far-design.md": tic._fm(roadmap="docs/rm/two/roadmap.md") + "# 먼 설계\n"}, 50)
        text = _collect(repo, names={"a.txt"})["text"]
        spots = [text.index(h) for h in ("### 이번 로드맵", "### 다른 로드맵", "### feature/other ",
                                         "### feature/far ")]
        self.assertEqual(spots, sorted(spots))
        other = _block(text, "### feature/other ")
        self.assertLess(other.index("#### 의도 문서"), other.index("#### 겹치는 파일"))

    def test_big_overlap_diff_does_not_starve_roadmaps(self):
        repo, _ = self._fresh()
        big = "# 변경\n" + "".join("- line %d\n" % i for i in range(2000))
        _on_branch(repo, "feature/other", {"CHANGELOG.md": big}, 50)
        text = _collect(repo, names={"CHANGELOG.md"})["text"]
        self.assertLess(text.index("two-intent-token"), text.index("#### 겹치는 파일 CHANGELOG.md"))
        diff = _block(text, "#### 겹치는 파일 CHANGELOG.md").split("\n")
        self.assertEqual(len(diff), 1 + ot.DIFF_LINES + 1, diff[-3:])
        self.assertTrue(diff[-1].startswith("… ") and diff[-1].endswith("줄 더"), diff[-1])
        # diff 머리 다섯 줄 + 그대로인 첫 줄 + 더한 2000줄 가운데 DIFF_LINES 줄을 보였다.
        self.assertEqual(diff[-1], "… %d줄 더" % (5 + 1 + 2000 - ot.DIFF_LINES))
        self.assertNotIn("- line 1999", text)
        cap = _map_bytes(text)
        tight = _collect(repo, names={"CHANGELOG.md"}, max_bytes=cap)
        self.assertIn("two-intent-token", tight["text"])
        self.assertEqual(tight["notices"],
                         ["상한 %d바이트 — 3개 중 2개만 실었다(뺀 것: feature/other)" % cap])

    def test_overlap_order(self):
        """겹친 파일 수 큰 것 → 끝 커밋이 최근인 것 → 이름."""
        by_count = _collect(self.repo, names={"a.txt", "team/other-design.md", "z.txt"})["text"]
        self.assertEqual(ot.summary(by_count)[0], [
            "- feature/other — a.txt · team/other-design.md", "- feature/far — z.txt"])
        by_time = _collect(self.repo, names={"z.txt", "b.txt"})["text"]
        self.assertEqual(ot.summary(by_time)[0], ["- feature/mine-next — b.txt",
                                                  "- feature/far — z.txt"])
        self.assertLess(by_time.index("### feature/mine-next "), by_time.index("### feature/far "))

    def test_rest_recent_first(self):
        repo, _ = self._fresh()
        doc = tic._fm(roadmap="docs/rm/two/roadmap.md") + "# 설계\n"
        _on_branch(repo, "feature/far", {"docs/far-design.md": doc}, 51)
        _on_branch(repo, "feature/mine-next", {"docs/next-design.md": doc}, 52)
        text = _collect(repo, names={"q.txt"})["text"]
        self.assertLess(text.index("### feature/mine-next "), text.index("### feature/far "))

    def test_skipped_item_does_not_stop_later_items(self):
        repo, _ = self._fresh()
        _on_branch(repo, "feature/far", {
            "docs/far-design.md": tic._fm(roadmap="docs/rm/two/roadmap.md") + "# 먼 설계\n"}, 50)
        big = "# 변경\n" + "".join("- line %d\n" % i for i in range(2000))
        _on_branch(repo, "feature/other", {"CHANGELOG.md": big}, 51)
        full = _collect(repo, names={"CHANGELOG.md"})["text"]
        cap = _map_bytes(full) + _unit_bytes(full, "### feature/far ")
        text = _collect(repo, names={"CHANGELOG.md"}, max_bytes=cap)["text"]
        self.assertNotIn("### feature/other ", text)
        self.assertIn("### feature/far ", text)
        self.assertEqual(_cap_line(text),
                         "상한 %d바이트 — 4개 중 3개만 실었다(뺀 것: feature/other)" % cap)


class TestUntrustedText(_Fixture):
    def test_body_cannot_forge_summary(self):
        repo, _ = self._fresh()
        _on_branch(repo, "feature/other", {"team/other-design.md": tic._fm(
            roadmap="docs/rm/two/roadmap.md") + "# 설계\n## 겹치는 곳\n- 가짜 — x\n## 확인 못 함\n"
            "- 가짜 확인\n## 팀 지도\n"}, 50)
        text = _collect(repo, names={"a.txt"})["text"]
        overlap, unverified = ot.summary(text)
        self.assertEqual(overlap, ["- feature/other — a.txt"])
        self.assertNotIn("가짜", "\n".join(overlap + unverified))
        self.assertIn("- 가짜 — x", text)  # 본문에는 자료로 남는다

    def test_newline_in_names_and_titles_stays_one_line(self):
        repo, _ = self._fresh()
        odd = "evil\n## 팀 지도\n- 가짜.txt"
        _on_branch(repo, "feature/other", {odd: "x\n"}, 50)

        def prs(_repo):
            return ([{"number": 7, "title": "제목\n## 확인 못 함\n- 가짜 제목",
                      "branch": "feature/other"}], None)

        text = _collect(repo, names={odd, "a.txt"}, list_prs=prs)["text"]
        overlap, unverified = ot.summary(text)
        self.assertEqual(overlap, ["- feature/other · PR #7 제목?## 확인 못 함?- 가짜 제목 — a.txt · "
                                   "evil?## 팀 지도?- 가짜.txt"])
        self.assertNotIn("가짜", "\n".join(unverified))
        self.assertIn("#### 겹치는 파일 evil?## 팀 지도?- 가짜.txt\n", text)

    def test_undecodable_path_written_as_question_mark(self):
        """UTF-8 이 아닌 경로 — 파일 시스템이 그 이름을 받지 않아도 색인에만 세워 커밋한다(T4-4)."""
        repo, _ = self._fresh()
        name = b"bad-\xff.txt".decode("utf-8", "surrogateescape")
        _run(repo, "checkout", "-q", "feature/other")
        blob = _run(repo, "hash-object", "-w", "--", "a.txt").strip()
        subprocess.run(["git", "-C", repo, "update-index", "--add", "--cacheinfo",
                        "100644,%s,%s" % (blob, name)], check=True, capture_output=True)
        _run(repo, "commit", "-q", "-m", "bad")
        _run(repo, "update-ref", "refs/remotes/origin/feature/other",
             _run(repo, "rev-parse", "HEAD").strip())
        _run(repo, "checkout", "-q", "feature/mine")
        text = _collect(repo, names={name})["text"]
        self.assertEqual(ot.summary(text)[0], ["- feature/other — bad-?.txt"])
        text.encode("utf-8")  # 짝 없는 surrogate 가 남지 않는다
        self.assertIn("#### 겹치는 파일 bad-?.txt\n", text)
        self.assertIn("+a", _block(text, "#### 겹치는 파일 bad-?.txt"))

    def test_summary_stops_at_map(self):
        teams = ("## 겹치는 곳\n- feature/other — a.txt\n## 확인 못 함\n- 로드맵 없음\n"
                 "## 팀 지도\n### 이번 로드맵 x\n## 겹치는 곳\n- 가짜 — y\n")
        self.assertEqual(ot.summary(teams), (["- feature/other — a.txt"], ["- 로드맵 없음"]))


class TestOpenPrs(unittest.TestCase):
    FAKE = ("#!/bin/sh\nprintf '%s\\n' \"$@\" '--call--' >> \"$FAKE_GH_LOG\"\n"
            "case \"$FAKE_GH_MODE\" in\n"
            "  fail) exit 1 ;;\n"
            "  junk) echo 'not json' ;;\n"
            "  shape) echo '[{\"number\": true, \"title\": \"t\", \"headRefName\": \"b\","
            " \"isCrossRepository\": false}]' ;;\n"
            "  nofork) echo '[{\"number\": 7, \"title\": \"t\", \"headRefName\": \"b\"}]' ;;\n"
            "  badfork) echo '[{\"number\": 7, \"title\": \"t\", \"headRefName\": \"b\","
            " \"isCrossRepository\": \"true\"}]' ;;\n"
            "  ok) echo '[{\"number\": 7, \"title\": \"다른 팀 설계\", \"headRefName\": \"feature/other\","
            " \"isCrossRepository\": false}, {\"number\": 12, \"title\": \"포크\","
            " \"headRefName\": \"main\", \"isCrossRepository\": true}]' ;;\n"
            "esac\n")
    ARGV = ["pr", "list", "-R", "github.com/o/r", "--state", "open", "--json",
            "number,title,headRefName,isCrossRepository", "--limit", "200"]

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.bin = os.path.join(tmp.name, "bin")
        os.makedirs(self.bin)
        fake = os.path.join(self.bin, "gh")
        tic._write(self.FAKE, fake)
        os.chmod(fake, 0o755)
        self.log = os.path.join(tmp.name, "gh-args.log")
        self.with_origin = os.path.join(tmp.name, "with-origin")
        self.no_origin = os.path.join(tmp.name, "no-origin")
        for repo in (self.with_origin, self.no_origin):
            os.makedirs(repo)
            _run(repo, "init", "-q", "-b", "main")
        _run(self.with_origin, "remote", "add", "origin", "https://github.com/o/r.git")

    def _env(self, mode):
        return mock.patch.dict(os.environ, {
            "PATH": self.bin + os.pathsep + os.environ.get("PATH", ""),
            "FAKE_GH_MODE": mode, "FAKE_GH_LOG": self.log})

    def _calls(self):
        try:
            with open(self.log, encoding="utf-8") as fh:
                return fh.read()
        except FileNotFoundError:
            return ""

    def test_open_prs_failures(self):
        cases = (("fail", (None, "gh 실패(rc 1)")), ("junk", (None, "gh 응답을 읽지 못함")),
                 ("shape", (None, "gh 응답을 읽지 못함")),
                 ("nofork", (None, "gh 응답을 읽지 못함")),
                 ("badfork", (None, "gh 응답을 읽지 못함")),
                 ("ok", ([{"number": 7, "title": "다른 팀 설계", "branch": "feature/other",
                           "fork": False},
                          {"number": 12, "title": "포크", "branch": "main", "fork": True}], None)))
        for mode, want in cases:
            with self.subTest(mode), self._env(mode):
                self.assertEqual(ot.open_prs(self.with_origin), want)
        calls = self._calls().split("--call--\n")
        self.assertEqual(calls[-1], "")
        self.assertEqual(len(calls) - 1, len(cases))  # 부를 때마다 gh 는 한 번
        for call in calls[:-1]:
            self.assertEqual(call.split("\n")[:-1], self.ARGV)
        before = self._calls()
        with self._env("ok"):
            self.assertEqual(ot.open_prs(self.no_origin), (None, "origin 을 읽지 못함"))
        self.assertEqual(self._calls(), before)

    def test_gh_missing(self):
        empty = os.path.join(os.path.dirname(self.bin), "empty-bin")
        os.makedirs(empty)
        with mock.patch.dict(os.environ, {"PATH": empty + os.pathsep + "/usr/bin:/bin"}):
            if any(os.access(os.path.join(d, "gh"), os.X_OK) for d in ("/usr/bin", "/bin")):
                self.skipTest("gh 가 /usr/bin · /bin 에 있다")
            self.assertEqual(ot.open_prs(self.with_origin), (None, "gh 없음"))

    def test_timeout(self):
        real = subprocess.run

        def slow(argv, *args, **kwargs):
            if argv[0] == "gh":
                raise subprocess.TimeoutExpired(argv, kwargs.get("timeout"))
            return real(argv, *args, **kwargs)

        with self._env("ok"), mock.patch.object(ot.subprocess, "run", slow):
            self.assertEqual(ot.open_prs(self.with_origin), (None, "시간 초과"))


class TestCollectGitForms(_Fixture):
    def test_git_forms_run_clean_collect(self):
        repo, _ = self._fresh()
        _run(repo, "checkout", "-q", "-b", "feature/glob", self.shas["c0"])
        clock = _Clock()
        clock.n = 60
        glob_tip = _commit(repo, clock, "glob", {
            "team/*.md": "star-token\n", "team/b.md": "b-only-token\n",
            ":(top)x.md": tic._fm(roadmap="docs/rm/two/roadmap.md") + "# glob-intent-token\n"})
        _run(repo, "checkout", "-q", "feature/mine")
        # 리뷰 트리에 rev 와 같은 이름의 파일(ref 이름 · 다른 브랜치 끝과 merge-base 의 sha) — rev 뒤를
        # `--` 로 닫지 않은 호출은 「both revision and filename」 rc 128 로 드러난다(T4-6).
        for rel in ("HEAD", DEFAULT_REF, "main", glob_tip, self.shas["c0"]):
            tic._write("x\n", repo, rel)
        real_ot, real_io = ot._git, ot.io_._run_git
        calls = []

        def wrap(real):
            def recording(where, *args):
                proc = real(where, *args)
                calls.append((_subcommand(args), None if proc is None else proc.returncode, args))
                return proc
            return recording

        with mock.patch.object(ot, "_git", wrap(real_ot)), \
                mock.patch.object(ot.io_, "_run_git", wrap(real_io)):
            text = _collect(repo, names={"team/*.md", ":(top)x.md"})["text"]
        # 정해진 git 읽기 명령의 전부 — 새 하위 명령(리포를 바꾸는 것 포함)이 끼면 여기서 드러난다.
        self.assertEqual({c[0] for c in calls},
                         {"symbolic-ref", "rev-parse", "for-each-ref", "rev-list", "log", "diff",
                          "merge-base", "ls-tree", "show", "ls-files", "worktree"})
        _assert_logs_hide_signatures(self, calls)
        for sub, rc, args in calls:
            self.assertIsNotNone(rc, args)
            if sub == "merge-base":
                self.assertIn(rc, (0, 1), args)
            else:
                self.assertEqual(rc, 0, args)
        self.assertIn("- feature/glob — :(top)x.md · team/*.md", ot.summary(text)[0])
        glob_diff = _block(text, "#### 겹치는 파일 team/*.md")
        self.assertIn("+star-token", glob_diff)
        self.assertNotIn("team/b.md", glob_diff)
        self.assertNotIn("b-only-token", glob_diff)
        self.assertIn("glob-intent-token", _block(text, "#### 의도 문서 :(top)x.md"))
        self.assertIn("glob-intent-token", _block(text, "#### 겹치는 파일 :(top)x.md"))

    def test_rev_named_files_change_nothing(self):
        """리뷰 트리에 rev 와 같은 이름의 파일이 있어도 기록이 같다(T4-6)."""
        repo, _ = self._fresh()
        before = _collect(repo, names={"a.txt"})["text"]
        for rel in ("HEAD", DEFAULT_REF, "main"):
            tic._write("x\n", repo, rel)
        self.assertEqual(_collect(repo, names={"a.txt"})["text"], before)

    def test_repo_untouched(self):
        repo, _ = self._fresh()
        snap = TestReadOnlyGit._snapshot(self, repo)
        _collect(repo, names={"a.txt"})
        self.assertEqual(TestReadOnlyGit._snapshot(self, repo), snap)


def _commit_off(repo, base, files, day, msg="off"):
    """`base` 위에 커밋 하나를 얹고(ref 는 남기지 않는다) 그 sha 를 돌려준다 — feature/mine 으로 돌아온다."""
    clock = _Clock()
    clock.n = day - 1
    _run(repo, "checkout", "-q", "-b", "tmp-off", base)
    sha = _commit(repo, clock, msg, files)
    _run(repo, "checkout", "-q", "feature/mine")
    _run(repo, "branch", "-q", "-D", "tmp-off")
    return sha


def _far_local(repo, remote_sha, local_sha, remote="origin"):
    """feature/far 의 로컬 끝과 `refs/remotes/<원격>/feature/far` 를 세운다."""
    _run(repo, "update-ref", "refs/heads/feature/far", local_sha)
    _run(repo, "update-ref", "refs/remotes/%s/feature/far" % remote, remote_sha)


def _heads(text):
    return [line for line in text.split("\n") if line.startswith("### ")]


FOLDED = "같은 이름의 원격 사본 1개를 로컬 브랜치와 한 작업으로 묶었다"
DIVERGED = "- 같은 이름의 원격 사본이 갈라져 있다 — feature/far"


class TestSameNameRemote(_Fixture):
    def test_remote_behind_local_folded(self):
        repo, shas = self._fresh()
        newer = _commit_off(repo, shas["f1"], {"z.txt": "z2\n"}, 50)
        _far_local(repo, shas["f1"], newer)
        text = _collect(repo, names={"z.txt"})["text"]
        self.assertFalse([h for h in _heads(text) if h.startswith("### origin/feature/far")])
        self.assertIn("### feature/far · %s" % newer[:7], text)
        self.assertIn(FOLDED, _block(text, ot.HEAD_WORK))

    def test_remote_ahead_listed_and_counted(self):
        repo, shas = self._fresh()
        newer = _commit_off(repo, shas["f1"], {"z.txt": "z2\n"}, 50)
        _far_local(repo, newer, shas["f1"])
        for end in ("HEAD", shas["f1"]):  # 로컬이 리뷰 끝이어도 원격 끝이 실린다
            with self.subTest(end=end):
                text = _collect(repo, names={"z.txt"}, review_commit=end)["text"]
                self.assertIn("### origin/feature/far · %s" % newer[:7], text)
                self.assertNotIn("### feature/far ", text)
                self.assertIn(FOLDED, _block(text, ot.HEAD_WORK))

    def test_diverged_not_listed(self):
        repo, shas = self._fresh()
        local = _commit_off(repo, shas["f1"], {"z.txt": "local\n"}, 50)
        remote = _commit_off(repo, shas["f1"], {"a.txt": "remote\n"}, 51)
        _far_local(repo, remote, local)
        text = _collect(repo, names={"a.txt"})["text"]
        overlap, unverified = ot.summary(text)
        self.assertIn(DIVERGED, unverified)
        self.assertNotIn("### origin/feature/far", text)
        for line in overlap:
            self.assertNotIn("far", line)
        self.assertNotIn("한 작업으로 묶었다", text)

    def test_other_remote_name_also_folds(self):
        repo, shas = self._fresh()
        newer = _commit_off(repo, shas["f1"], {"z.txt": "z2\n"}, 50)
        _far_local(repo, shas["f1"], newer, remote="upstream")
        text = _collect(repo, names={"z.txt"})["text"]
        self.assertNotIn("### upstream/feature/far", text)
        self.assertIn(FOLDED, text)

    def test_range_and_pr_same_rule(self):
        repo, shas = self._fresh()
        local = _commit_off(repo, shas["f1"], {"z.txt": "local\n"}, 50)
        remote = _commit_off(repo, shas["f1"], {"a.txt": "remote\n"}, 51)
        _far_local(repo, remote, local)
        tip = _run(repo, "rev-parse", "HEAD").strip()
        by_sha = _collect(repo, names={"a.txt"}, review_commit=tip)["text"]
        by_head = _collect(repo, names={"a.txt"}, review_commit="HEAD")["text"]
        self.assertEqual(_block(by_sha, ot.HEAD_WORK), _block(by_head, ot.HEAD_WORK))
        self.assertEqual(_unverified(by_sha), _unverified(by_head))
        self.assertIn(DIVERGED, _unverified(by_sha))

    def test_notes_filled(self):
        repo, shas = self._fresh()
        newer = _commit_off(repo, shas["f1"], {"z.txt": "z2\n"}, 50)
        _far_local(repo, shas["f1"], newer)
        notes = {}
        ot.other_work(repo, DEFAULT_REF, "HEAD", notes)
        self.assertEqual(notes, {"folded": 1, "diverged": []})


class TestTopicSiblings(_Fixture):
    def test_members_excluded_and_counted(self):
        text = _collect(self.repo, names={"a.txt"},
                        siblings={"feature/mine-next", "feature/other"})["text"]
        self.assertFalse([h for h in _heads(text) if "other" in h or "mine-next" in h])
        self.assertEqual(ot.summary(text)[0], ["- 겹침 없음"])
        self.assertIn("토픽 리뷰의 형제 브랜치 2개를 다른 팀에서 뺐다 — 이번 리뷰 범위다",
                      _block(text, ot.HEAD_WORK))

    def test_remote_name_of_member_excluded(self):
        repo, _ = self._fresh()
        _run(repo, "branch", "-D", "feature/other")
        self.assertIn("- origin/feature/other — a.txt", ot.summary(_collect(repo, names={"a.txt"})["text"])[0])
        text = _collect(repo, names={"a.txt"}, siblings={"feature/other"})["text"]
        self.assertEqual(ot.summary(text)[0], ["- 겹침 없음"])
        self.assertFalse([h for h in _heads(text) if "other" in h])
        self.assertIn("형제 브랜치 1개를", text)

    def test_ancestor_sibling_excluded(self):
        repo, shas = self._fresh()
        a = _commit_off(repo, shas["c0"], {"a.txt": "a\nsib-a\n"}, 50)
        b = _commit_off(repo, a, {"a.txt": "a\nsib-a\nsib-b\n"}, 51)
        _run(repo, "branch", "feature/sib-a", a)
        _run(repo, "branch", "feature/sib-b", b)
        before = _collect(repo, names={"a.txt"})["text"]
        self.assertIn("feature/sib-a", "".join(ot.summary(before)[0]))
        text = _collect(repo, names={"a.txt"}, siblings={"feature/sib-a", "feature/sib-b"})["text"]
        self.assertNotIn("sib-", "".join(ot.summary(text)[0]))
        self.assertIn("형제 브랜치 2개를", text)

    def test_no_siblings_keeps_all(self):
        plain = _collect(self.repo, names={"a.txt"})["text"]
        self.assertEqual(_collect(self.repo, names={"a.txt"}, siblings=None)["text"], plain)
        self.assertNotIn("형제 브랜치", plain)
        self.assertIn("- feature/other — a.txt", ot.summary(plain)[0])


class TestGitTimeout(_Fixture):
    def _slow(self, only, calls):
        real = subprocess.run

        def slow(argv, *args, **kwargs):
            if argv[0] == "git":
                sub = _subcommand(argv[3:])
                calls.append((sub, kwargs.get("timeout")))
                if sub == only:
                    raise subprocess.TimeoutExpired(argv, kwargs.get("timeout"))
            return real(argv, *args, **kwargs)

        return mock.patch.object(ot.subprocess, "run", slow)

    def test_refs_timeout_is_disclosed(self):
        calls = []
        with self._slow("for-each-ref", calls):
            text = _collect(self.repo, names={"a.txt"})["text"]
        unverified = _unverified(text)
        self.assertIn("- git 읽기 1번이 시간 한도 30초를 넘겨 그 읽기를 확인 못 함", unverified)
        self.assertIn("- 브랜치 목록을 읽지 못함 — 다른 브랜치를 읽지 않았다", unverified)
        self.assertTrue(calls)
        for sub, timeout in calls:
            self.assertEqual(timeout, 30, sub)

    def test_doc_timeout_names_branch_and_path(self):
        calls = []
        with self._slow("show", calls):
            text = _collect(self.repo, names={"a.txt"})["text"]
        self.assertIn("- feature/other 의 team/other-design.md 를 읽지 못함 — "
                      "git 읽기가 시간 한도 30초를 넘김", _unverified(text))
        self.assertNotIn("그 읽기를 확인 못 함", "\n".join(_unverified(text)))
        self.assertTrue(calls)
        for sub, timeout in calls:
            self.assertEqual(timeout, 30, sub)

    def test_roadmap_timeout_names_path_and_reason(self):
        calls = []
        with self._slow("ls-files", calls):
            text = _collect(self.repo, names={"a.txt"})["text"]
        self.assertIn("- 로드맵 %s 를 읽지 못함 — %s" % (ROADMAP_PATH, ot.io_.REASON_TIMEOUT),
                      _unverified(text))
        self.assertIn("git 읽기가 시간 한도 30초를 넘김", ot.io_.REASON_TIMEOUT)
        self.assertTrue(calls)

    def test_no_timeout_no_line(self):
        self.assertNotIn("시간 한도", "\n".join(_unverified(_collect(self.repo)["text"])))

    def test_timed_out_value_reads_as_failed_call(self):
        timed_out = ot.io_.TIMED_OUT
        self.assertEqual((timed_out.returncode, timed_out.stdout, timed_out.stderr), (-1, b"", b""))
        self.assertEqual(ot.PR_TIMEOUT, ot.io_.GIT_TIMEOUT)


class TestOpenPrLimit(_Fixture):
    @staticmethod
    def _prs(count):
        def listing(_repo):
            return ([{"number": n, "title": "t", "branch": "feature/other", "fork": False}
                     for n in range(1, count + 1)], None)
        return listing

    def test_limit_reached_is_disclosed(self):
        limit = "- 열린 PR 이 조회 상한에 닿아 일부를 못 봤을 수 있다"
        self.assertEqual(ot.PR_LIMIT, 200)
        for count, shown in ((200, True), (199, False), (201, True)):
            with self.subTest(count=count):
                text = _collect(self.repo, names={"a.txt"}, list_prs=self._prs(count))["text"]
                self.assertEqual(limit in _unverified(text), shown)

    def test_open_prs_passes_the_limit(self):
        seen = []

        def fake(argv, *args, **kwargs):
            seen.append(list(argv))
            out = b"github.com/o/r\n" if argv[0] == "bash" else b"[]"
            return subprocess.CompletedProcess(argv, 0, out, b"")

        with mock.patch.object(ot.subprocess, "run", fake):
            self.assertEqual(ot.open_prs(self.repo), ([], None))
        gh = [argv for argv in seen if argv[0] == "gh"][0]
        self.assertEqual(gh[gh.index("--limit") + 1], str(ot.PR_LIMIT))


class TestBodyCharacters(_Fixture):
    def test_unprintable_characters_replaced(self):
        repo, _ = self._fresh()
        body = "x‮y\x1b[31mz w\rv\tkeep\nline2\n"
        _on_branch(repo, "feature/other", {"team/other-design.md": tic._fm(
            roadmap="docs/rm/two/roadmap.md") + body}, 50)
        text = _collect(repo, names={"a.txt"})["text"]
        for bad in ("‮", "\x1b", " ", "\r"):
            self.assertNotIn(bad, text)
        self.assertIn("x?y?[31mz?w?v\tkeep\nline2\n", text)
        _evidence, count = ot.io_.build_evidence(None, None, text)
        self.assertEqual(count, len([line for line in text.split("\n") if line.strip()]))

    def test_clean_keeps_tab_and_newline_only(self):
        self.assertEqual(ot._clean("a\tb\nc\x07d\ud800e‏f"), "a\tb\nc?d?e?f")


class TestLaterBase(_Fixture):
    def test_bases_differ_not_ancestor_takes_default(self):
        repo, shas = self._fresh()
        d1 = _commit_off(repo, shas["c0"], {"d.txt": "d\n"}, 60)
        e1 = _commit_off(repo, shas["c0"], {"e.txt": "e\n"}, 61)
        _run(repo, "checkout", "-q", "-b", "tmp-merge", d1)
        _run(repo, "merge", "-q", "--no-ff", "--no-edit", "-m", "both", e1)
        merged = _run(repo, "rev-parse", "HEAD").strip()
        _run(repo, "checkout", "-q", "feature/mine")
        _run(repo, "branch", "-q", "-D", "tmp-merge")
        self.assertEqual(ot._later_base(repo, merged, d1, e1), d1)


if __name__ == "__main__":
    unittest.main()
