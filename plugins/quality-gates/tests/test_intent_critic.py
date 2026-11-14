"""scripts/doc_paths.py 설정 키 넓힘 · scripts/intent_answers.py (쓴소리 답 파일) · scripts/intent_origin.py (근거 · 원문 · 로드맵 · 의심)."""
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
io_ = _load("intent_origin")

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


def _fm(**kv):
    body = "".join("%s: %s\n" % (k, v) for k, v in kv.items())
    return "---\n" + body + "---\n"


BUNDLE_BODY = (
    "# 묶음\n## 1. 머리말\nintro-token\n## 2. 제약\nconstraint-token\n"
    "## 3. 열린 질문\nopenq-token\n## 4. 계획\nplan-token\n"
    "## 5. 기각 · 위험\nrisk-token\n## 6. 사용자 원문\n> 원문 줄 quote-token\n"
    ">\n> 다시 검증할 것 — recheck-token\n> 이어지는 recheck-more\n>\n> 끝 줄 tail-token\n")

ROADMAP_BODY = (
    _fm(type="roadmap")
    + "# 로드맵\n## 에픽\n### R1 — 본체\n- 의도: epic-body-token\n"
    "## 위험 번호표\n- K1 — 위험 — 숨은 가정: risk-section-token\n"
    "## 열린 질문\n- oq-section-token\n"
    "## 지휘 절차\n- choice-body-token\n- K3 — 위험 — outside-k-token\n"
    "> 다시 검증할 것 — rm-recheck-token\n> 이어지는 rm-more\n>\n- after-recheck-token\n")


def _origin_repo(root):
    """원문 · 로드맵 링크 시험용 임시 git 리포(커밋 뒤 추적 안 된 docs/new.md 포함)."""
    _git_repo(root)
    files = {
        "docs/spec.md": _fm(source_interview="docs/R1.md", roadmap="docs/roadmap.md"),
        "docs/R1.md": _fm(type="epic-bundle", source_brief="docs/brief.md",
                          roadmap="docs/roadmap.md") + BUNDLE_BODY,
        "docs/spec2.md": _fm(source_interview="docs/R2.md"),
        "docs/R2.md": _fm(type="epic-bundle", source_brief="docs/brief2.md")
        + BUNDLE_BODY.replace("-token", "-two"),
        "docs/spec3.md": _fm(source_interview="docs/R3.md", roadmap="docs/roadmap.md"),
        "docs/R3.md": _fm(type="epic-bundle", source_brief="docs/brief3.md")
        + "## 6. 사용자 원문\nonly-quote-token\n",
        "docs/roadmap.md": ROADMAP_BODY,
        "docs/old.md": "# 옛 문서\nold-body-token\n> 다시 검증할 것 — old-recheck\n",
        "docs/spec_old.md": _fm(source_interview="docs/old.md"),
        "docs/spec_link.md": _fm(source_interview="docs/link.md"),
        "docs/spec_new.md": _fm(source_interview="docs/new.md"),
        "docs/spec_parent.md": _fm(source_interview="../x.md"),
        "docs/spec_abs.md": _fm(source_interview="/etc/hosts"),
        "docs/spec_dir.md": _fm(source_interview="docs"),
        "docs/spec_nolink.md": _fm(title="t"),
        "docs/spec_rlink.md": _fm(roadmap="docs/link.md"),
        "docs/spec_rnew.md": _fm(roadmap="docs/new.md"),
        "docs/spec_rparent.md": _fm(roadmap="../x.md"),
        "docs/spec_rnone.md": _fm(source_interview="docs/R2.md"),
    }
    for rel, text in files.items():
        Path(root, rel).parent.mkdir(parents=True, exist_ok=True)
        Path(root, rel).write_text(text, encoding="utf-8")
    os.symlink("old.md", os.path.join(root, "docs", "link.md"))
    _git(root, "add", "docs")
    _git(root, "commit", "-q", "-m", "fixture")
    Path(root, "docs", "new.md").write_text("untracked\n", encoding="utf-8")
    return root


DIFF_GREEN = ("per_adapter:\n  - runner: pytest\n    attributions:\n      - unit: t::a\n"
              "        verdict: STILL_GREEN\n        note: \"\"\n")
DIFF_RED = DIFF_GREEN.replace("STILL_GREEN", "NEW_REGRESSION")


def _diff(*verdicts):
    out = "per_adapter:\n  - runner: pytest\n    attributions:\n"
    for i, v in enumerate(verdicts):
        out += "      - unit: t::u%d\n        verdict: %s\n        note: \"\"\n" % (i, v)
    return out


class TestEvidence(unittest.TestCase):
    def test_all_green_is_not_evidence(self):
        self.assertFalse(io_.has_evidence(None, DIFF_GREEN)[0])
        self.assertEqual(io_.build_evidence(None, DIFF_GREEN), ("", 0))

    def test_non_green_or_walk_is_evidence(self):
        self.assertTrue(io_.has_evidence(None, DIFF_RED)[0])
        self.assertTrue(io_.has_evidence("관찰 a\n", DIFF_GREEN)[0])

    def test_pass_set_is_not_evidence(self):
        self.assertFalse(io_.has_evidence(None, _diff("STILL_GREEN", "FIXED", "NEW_TEST_GREEN"))[0])

    def test_one_non_pass_among_passes_is_evidence(self):
        for v in ("PRE_EXISTING", "SILENT_DROP", "NEW_TEST_RED", "BASELINE_UNRUNNABLE"):
            self.assertTrue(io_.has_evidence(None, _diff("STILL_GREEN", v, "FIXED"))[0], v)

    def test_unknown_attribution_is_evidence(self):
        self.assertTrue(io_.has_evidence(None, _diff("STILL_GREEN", "SOME_FUTURE_NAME"))[0])

    def test_numbers_and_order(self):
        t, n = io_.build_evidence("a\n\nb\n", DIFF_RED)
        self.assertIn("   1\t[e2e] a", t)
        self.assertIn("   2\t[e2e] b", t)
        self.assertIn("   3\t[차등] per_adapter:", t)
        self.assertEqual(io_.evidence_line_numbers(t), set(range(1, n + 1)))
        self.assertLess(t.index("[e2e] b"), t.index("[차등]"))

    def test_unreadable_differential(self):
        ok, notes = io_.has_evidence(None, "per_adapter: [")
        self.assertFalse(ok)
        self.assertIn("차등 결과를 읽지 못함 — 근거로 세지 않았다", notes)

    def test_unreadable_differential_with_walk(self):
        ok, notes = io_.has_evidence("관찰\n", "per_adapter: [")
        self.assertTrue(ok)
        self.assertIn("차등 결과를 읽지 못함 — 근거로 세지 않았다", notes)
        text, n = io_.build_evidence("관찰\n", "per_adapter: [")
        self.assertEqual((n, "[차등]" in text), (1, False))

    def test_empty_inputs(self):
        self.assertEqual(io_.build_evidence(None, "\n\n"), ("", 0))
        self.assertEqual(io_.build_evidence("\n \n", None), ("", 0))
        self.assertFalse(io_.has_evidence("", "")[0])

    def test_no_evidence_has_no_notice(self):
        self.assertEqual(io_.has_evidence(None, DIFF_GREEN), (False, []))


class TestReadTracked(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.R = _origin_repo(cls.tmp.name)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_reads_committed_content(self):
        content, why = io_.read_tracked(self.R, "HEAD", "docs/old.md")
        self.assertIsNone(why)
        self.assertIn("old-body-token", content)

    def test_rejections_are_literal(self):
        cases = (("/etc/hosts", "절대 경로"), ("../x.md", "상위 경로(..)"),
                 ("docs/../../x.md", "상위 경로(..)"), (".git/config", ".git 아래"),
                 ("docs/.git/x", ".git 아래"), ("docs/new.md", "추적 안 된 파일 또는 없음"),
                 ("docs/none.md", "추적 안 된 파일 또는 없음"), ("", "추적 안 된 파일 또는 없음"),
                 ("docs/link.md", "심볼릭 링크"), ("docs", "보통 파일이 아님"))
        for rel, why in cases:
            content, got = io_.read_tracked(self.R, "HEAD", rel)
            self.assertEqual((content, got), (None, why), rel)

    def test_bad_commit_is_untracked(self):
        self.assertEqual(io_.read_tracked(self.R, "no-such-ref", "docs/old.md"),
                         (None, "추적 안 된 파일 또는 없음"))

    def test_frontmatter_value(self):
        t = _fm(source_interview="docs/R1.md", n="3")
        self.assertEqual(io_.frontmatter_value(t, "source_interview"), "docs/R1.md")
        self.assertEqual(io_.frontmatter_value(t, "n"), "3")
        self.assertIsNone(io_.frontmatter_value(t, "nope"))
        self.assertIsNone(io_.frontmatter_value("no front\n", "n"))
        self.assertIsNone(io_.frontmatter_value("---\nn: [\n---\n", "n"))


class TestOriginLink(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.R = _origin_repo(cls.tmp.name)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def _o(self, specs, caller=None):
        return io_.build_origin(self.R, "HEAD", "HEAD", caller, specs)

    def test_follows_source_interview_and_maps_bundle_to_brief(self):
        o = self._o(["docs/spec.md"])
        self.assertIn("docs/brief.md", o["sources"])
        self.assertEqual(o["aliases"]["docs/R1.md"], "docs/brief.md")
        self.assertIn("## 6. 사용자 원문", o["origin"])
        self.assertIn("## 2. 제약", o["origin"])
        self.assertIn("## 5. 기각 · 위험", o["doubts"])
        self.assertIn("## 3. 열린 질문", o["doubts"])
        self.assertNotIn("## 5.", o["origin"])
        self.assertNotIn("## 3.", o["origin"])
        self.assertNotIn("intro-token", o["origin"])
        self.assertNotIn("plan-token", o["origin"] + o["doubts"])
        self.assertIn("다시 검증할 것", o["doubts"])
        self.assertIn("recheck-more", o["doubts"])
        self.assertNotIn("다시 검증할 것", o["origin"])
        self.assertNotIn("recheck-more", o["origin"])
        self.assertIn("quote-token", o["origin"])
        self.assertIn("tail-token", o["origin"])
        self.assertIn("<!-- origin-source: docs/brief.md · file: docs/R1.md -->", o["origin"])
        self.assertFalse(o["mixed"])
        self.assertEqual(o["notices"], [])

    def test_origin_link_rejected_symlink(self):
        o = self._o(["docs/spec_link.md"])
        self.assertIn("원문 링크 거부 — 심볼릭 링크", o["notices"])
        self.assertEqual(o["origin"], "원문 없음 — 원문 링크 거부")
        self.assertIn("원문 없음 — 원문 링크 거부", o["notices"])
        self.assertNotIn("old-body-token", o["origin"] + o["doubts"])
        self.assertEqual(o["sources"], [])

    def test_origin_link_rejected_untracked_and_dir(self):
        o = self._o(["docs/spec_new.md"])
        self.assertIn("원문 링크 거부 — 추적 안 된 파일 또는 없음", o["notices"])
        self.assertNotIn("untracked", o["origin"])
        o = self._o(["docs/spec_dir.md"])
        self.assertIn("원문 링크 거부 — 보통 파일이 아님", o["notices"])

    def test_origin_link_rejected_parent_and_abs(self):
        o = self._o(["docs/spec_parent.md"])
        self.assertIn("원문 링크 거부 — 상위 경로(..)", o["notices"])
        self.assertEqual(o["origin"], "원문 없음 — 원문 링크 거부")
        o = self._o(["docs/spec_abs.md"])
        self.assertIn("원문 링크 거부 — 절대 경로", o["notices"])
        self.assertEqual(o["origin"], "원문 없음 — 원문 링크 거부")

    def test_spec_itself_rejected(self):
        o = self._o(["docs/missing-spec.md"])
        self.assertIn("원문 링크 거부 — 추적 안 된 파일 또는 없음", o["notices"])
        self.assertEqual(o["origin"], "원문 없음 — 원문 링크 거부")

    def test_caller_origin_first(self):
        o = self._o(["docs/spec2.md"], caller="docs/R1.md")
        self.assertIn("quote-token", o["origin"])
        self.assertNotIn("quote-two", o["origin"])
        self.assertEqual(o["sources"], ["docs/brief.md"])

    def test_caller_origin_rejected_goes_to_no_origin(self):
        o = self._o(["docs/spec2.md"], caller="docs/link.md")
        self.assertIn("원문 링크 거부 — 심볼릭 링크", o["notices"])
        self.assertEqual(o["origin"], "원문 없음 — 원문 링크 거부")

    def test_caller_origin_read_at_head_commit(self):
        o = io_.build_origin(self.R, "HEAD", "no-such-ref", "docs/R1.md", ["docs/spec2.md"])
        self.assertIn("quote-token", o["origin"])
        self.assertEqual(o["notices"], [])

    def test_old_doc_whole_file_mixed(self):
        o = self._o(["docs/spec_old.md"])
        self.assertTrue(o["mixed"])
        self.assertIn("old-body-token", o["origin"])
        self.assertIn("직접 쓴 말 · 고른 라벨을 가르지 못함", o["notices"])
        self.assertIn("첫 호출에 의심이 섞였다", o["notices"])
        self.assertEqual(o["sources"], ["docs/old.md"])
        self.assertEqual(o["aliases"], {})

    def test_two_specs_each_followed(self):
        o = self._o(["docs/spec.md", "docs/spec2.md"])
        self.assertIn("docs/brief.md", o["sources"])
        self.assertIn("docs/brief2.md", o["sources"])
        self.assertEqual(o["origin"].count("<!-- origin-source:"), 2)
        self.assertIn("quote-token", o["origin"])
        self.assertIn("quote-two", o["origin"])
        self.assertEqual(o["aliases"], {"docs/R1.md": "docs/brief.md",
                                        "docs/R2.md": "docs/brief2.md"})

    def test_same_bundle_twice_read_once(self):
        o = self._o(["docs/spec.md", "docs/spec.md"])
        self.assertEqual(o["origin"].count("<!-- origin-source:"), 1)

    def test_one_rejected_one_followed(self):
        o = self._o(["docs/spec_link.md", "docs/spec.md"])
        self.assertIn("quote-token", o["origin"])
        self.assertIn("원문 링크 거부 — 심볼릭 링크", o["notices"])
        self.assertFalse(o["origin"].startswith("원문 없음"))

    def test_no_specs_no_caller(self):
        o = self._o([])
        self.assertEqual(o["origin"], "원문 없음 — 의도 출처에 설계문서 없음")
        self.assertIn(o["origin"], o["notices"])
        self.assertTrue(o["roadmap"].startswith("로드맵 없음 — "))

    def test_spec_without_source_interview(self):
        o = self._o(["docs/spec_nolink.md"])
        self.assertEqual(o["origin"], "원문 없음 — 부른 쪽 원문도 설계문서 링크도 없음")
        self.assertIn(o["origin"], o["notices"])

    def test_keys(self):
        o = self._o([])
        self.assertEqual(sorted(o), ["aliases", "doubts", "mixed", "notices", "origin",
                                     "roadmap", "sources"])
        self.assertEqual(o["doubts"], "")
        self.assertIs(o["mixed"], False)


class TestRoadmap(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.R = _origin_repo(cls.tmp.name)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def _o(self, specs):
        return io_.build_origin(self.R, "HEAD", "HEAD", None, specs)

    def test_roadmap_followed_once(self):
        o = self._o(["docs/spec.md"])
        rm = o["roadmap"]
        self.assertEqual(rm.count("<!-- roadmap: docs/roadmap.md"), 1)
        self.assertIn("<!-- roadmap: docs/roadmap.md · from: docs/spec.md -->", rm)
        for kept in ("epic-body-token", "choice-body-token", "after-recheck-token"):
            self.assertIn(kept, rm)
        for moved in ("risk-section-token", "oq-section-token", "outside-k-token",
                      "rm-recheck-token", "rm-more", "## 위험 번호표", "## 열린 질문"):
            self.assertNotIn(moved, rm)
        self.assertIn("<!-- roadmap-doubts: docs/roadmap.md -->", o["doubts"])
        after = o["doubts"].split("<!-- roadmap-doubts: docs/roadmap.md -->", 1)[1]
        for moved in ("risk-section-token", "oq-section-token", "outside-k-token",
                      "rm-recheck-token", "rm-more"):
            self.assertIn(moved, after)
        for kept in ("epic-body-token", "choice-body-token", "after-recheck-token"):
            self.assertNotIn(kept, o["doubts"])

    def test_roadmap_only_doubts(self):
        o = self._o(["docs/spec3.md"])
        self.assertIn("only-quote-token", o["origin"])
        self.assertNotIn("## 5.", o["doubts"])
        self.assertIn("risk-section-token", o["doubts"])
        self.assertTrue(o["doubts"].strip())
        self.assertIn("epic-body-token", o["roadmap"])

    def test_roadmap_none_in_opened_docs(self):
        o = self._o(["docs/spec_rnone.md"])
        self.assertEqual(o["roadmap"], "로드맵 없음 — 연 문서에 roadmap: 없음")
        self.assertIn(o["roadmap"], o["notices"])
        self.assertNotIn("roadmap-doubts", o["doubts"])

    def test_roadmap_link_rejected_symlink_and_untracked(self):
        for spec, why in (("docs/spec_rlink.md", "심볼릭 링크"),
                          ("docs/spec_rnew.md", "추적 안 된 파일 또는 없음")):
            o = self._o([spec])
            self.assertIn("로드맵 링크 거부 — " + why, o["notices"])
            self.assertEqual(o["roadmap"], "로드맵 없음 — 로드맵 링크 거부")
            self.assertNotIn("untracked", o["roadmap"] + o["doubts"])
            self.assertNotIn("old-body-token", o["roadmap"] + o["doubts"])

    def test_roadmap_link_rejected_parent(self):
        o = self._o(["docs/spec_rparent.md"])
        self.assertIn("로드맵 링크 거부 — 상위 경로(..)", o["notices"])
        self.assertEqual(o["roadmap"], "로드맵 없음 — 로드맵 링크 거부")

    def test_roadmap_from_caller_origin_bundle(self):
        o = io_.build_origin(self.R, "HEAD", "HEAD", "docs/R1.md", [])
        self.assertIn("<!-- roadmap: docs/roadmap.md · from: docs/R1.md -->", o["roadmap"])


class TestSections(unittest.TestCase):
    def test_strip_intent_doubts(self):
        text = ("# T\n## Goals\ngoal-body\n## Rejected Alternatives\nrejected-body\n"
                "## 위험\nrisk-body\n## Constraints\nconstraint-body\n")
        kept, moved = io_.strip_intent_doubts(text)
        self.assertIn("## Goals", kept)
        self.assertIn("goal-body", kept)
        self.assertIn("constraint-body", kept)
        for gone in ("Rejected", "rejected-body", "risk-body", "## 위험"):
            self.assertNotIn(gone, kept)
        self.assertIn("rejected-body", moved)
        self.assertIn("risk-body", moved)
        self.assertNotIn("goal-body", moved)
        self.assertNotIn("constraint-body", moved)

    def test_strip_intent_doubts_names_and_case(self):
        for head in ("기각", "열린 질문", "Risk", "open question", "REJECTED"):
            kept, moved = io_.strip_intent_doubts("## Goals\ng-body\n## %s\nd-body\n" % head)
            self.assertNotIn("d-body", kept, head)
            self.assertIn("d-body", moved, head)
        kept, moved = io_.strip_intent_doubts("## Goals\ng-body\n")
        self.assertEqual(moved, "")
        self.assertIn("g-body", kept)

    def test_strip_intent_doubts_subsection_and_children(self):
        text = ("## 설계\nd-body\n### Open Questions\nq-body\n### 세부\nsub-body\n"
                "## 위험\nr-body\n### 하위\nchild-body\n## 끝\nend-body\n")
        kept, moved = io_.strip_intent_doubts(text)
        for x in ("d-body", "sub-body", "end-body"):
            self.assertIn(x, kept)
        for x in ("q-body", "r-body", "child-body"):
            self.assertNotIn(x, kept)
            self.assertIn(x, moved)

    def test_strip_intent_doubts_moves_recheck_paragraph(self):
        text = "## Goals\ngoal-body\n- 다시 검증할 것 — v1\n  이어짐 v2\n\nafter-body\n"
        kept, moved = io_.strip_intent_doubts(text)
        self.assertIn("goal-body", kept)
        self.assertIn("after-body", kept)
        self.assertNotIn("v1", kept)
        self.assertNotIn("v2", kept)
        self.assertIn("v1", moved)
        self.assertIn("v2", moved)

    def test_move_recheck_paragraphs(self):
        text = ("a-line\n> 다시 검증할 것 — x1\n> x2\n>\nb-line\n* 다시 검증할 것: y1\n\nc-line\n"
                "다시 검증할 것을 말하면 z1\n")
        kept, moved = io_.move_recheck_paragraphs(text)
        for x in ("a-line", "b-line", "c-line"):
            self.assertIn(x, kept)
        for x in ("x1", "x2", "y1", "z1"):
            self.assertIn(x, moved)
            self.assertNotIn(x, kept)
        self.assertNotIn("a-line", moved)
        self.assertEqual(io_.move_recheck_paragraphs("none here\n"), ("none here\n", ""))

    def test_split_sections(self):
        text = "pre\n## A\na1\n### A1\nn1\n## B\nb1\n### C\nc1\n"
        secs = io_.split_sections(text)
        self.assertEqual([h for h, _ in secs], [None, "## A", "## B"])
        self.assertIn("### A1", secs[1][1])
        self.assertIn("n1", secs[1][1])
        self.assertNotIn("b1", secs[1][1])
        self.assertIn("b1", secs[2][1])
        self.assertIn("c1", secs[2][1])
        secs = io_.split_sections("### X\nx\n### Y\ny\n## Z\nz\n")
        self.assertEqual([h for h, _ in secs], ["### X", "### Y", "## Z"])
        self.assertEqual(io_.split_sections(""), [])
        self.assertEqual(io_.split_sections("plain\n"), [(None, "plain\n")])

    def test_split_sections_heading_needs_space(self):
        secs = io_.split_sections("##notheading\n#### deep\n## H\nx\n")
        self.assertEqual([h for h, _ in secs], [None, "## H"])

    def test_total_bytes_korean(self):
        self.assertEqual(io_.total_bytes("가", "a"), 4)
        self.assertEqual(io_.total_bytes(), 0)


if __name__ == "__main__":
    unittest.main()
