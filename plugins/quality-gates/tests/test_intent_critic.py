"""scripts/doc_paths.py 설정 키 넓힘 · scripts/intent_answers.py (쓴소리 답 파일) · scripts/intent_origin.py (근거 · 원문 · 로드맵 · 의심) · scripts/intent_critic.py (쓴소리 CLI)."""
import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

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


def _wf(n):
    """qg 가 쓰는 꼴의 답 파일 이름(answer_filename 과 같은 모양) — n 이 작을수록 먼저 정렬된다."""
    return "20261114T010203Z-%012x.md" % n


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
            # 늦은 answered_at 이 먼저 정렬되는 파일에 있다 — 파일 이름 순서가 아니라 answered_at 이 이긴다
            Path(d, _wf(1)).write_text(_answer_text(answer="지금은 모르겠다", at=AT2),
                                       encoding="utf-8")
            Path(d, _wf(2)).write_text(_answer_text(answer="의도다", at=AT1), encoding="utf-8")
            answered, bad = ia.read_answered(d)
            self.assertEqual(bad, 0)
            self.assertEqual(answered[IDENT]["answer"], "지금은 모르겠다")
            self.assertTrue(answered[IDENT]["path"].endswith(_wf(1)))

    def test_read_answered_tie_uses_filename(self):
        with tempfile.TemporaryDirectory() as d:
            Path(d, _wf(1)).write_text(_answer_text(answer="의도다"), encoding="utf-8")
            Path(d, _wf(2)).write_text(_answer_text(answer="잘못 골랐다"), encoding="utf-8")
            answered, _ = ia.read_answered(d)
            self.assertEqual(answered[IDENT]["answer"], "잘못 골랐다")

    def test_read_answered_skips_broken(self):
        with tempfile.TemporaryDirectory() as d:
            Path(d, _wf(1)).write_text("no frontmatter\n", encoding="utf-8")
            Path(d, _wf(2)).write_text("---\nid: [\n---\n", encoding="utf-8")
            Path(d, _wf(3)).write_text(_answer_text().replace("answer: 의도다", "answer: 모름"),
                                       encoding="utf-8")
            real = Path(d, "real.txt")
            real.write_text(_answer_text(), encoding="utf-8")
            os.symlink(str(real), os.path.join(d, _wf(4)))
            answered, bad = ia.read_answered(d)
            self.assertEqual(answered, {})
            self.assertEqual(bad, 4)

    def test_read_answered_rejects_names_qg_does_not_write(self):
        good = ia.answer_filename(IDENT, AT1)
        self.assertTrue(ia.is_answer_filename(good))
        for bad in ("x.md", "a\nb.md", good[:-3] + "\n.md", good.upper(), "1" + good,
                    good.replace("Z-", "Z_"), good + "\n"):
            self.assertFalse(ia.is_answer_filename(bad), repr(bad))
        with tempfile.TemporaryDirectory() as d:
            for name in ("x.md", "20261114T010203Z\n-000000000001.md", "1.md"):
                Path(d, name).write_text(_answer_text(answer="의도다"), encoding="utf-8")
            self.assertEqual(ia.read_answered(d), ({}, 3))
            Path(d, good).write_text(_answer_text(answer="잘못 골랐다"), encoding="utf-8")
            answered, bad = ia.read_answered(d)
            self.assertEqual((answered[IDENT]["answer"], bad), ("잘못 골랐다", 3))

    def test_answer_filename_refuses_odd_stamp(self):
        with self.assertRaises(ValueError):
            ia.answer_filename(IDENT, "2026-11-14 01:02")

    def test_unidentified_left_out_and_not_unreadable(self):
        with tempfile.TemporaryDirectory() as d:
            Path(d, _wf(1)).write_text(_answer_text(ident="unidentified:0123456789ab"),
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


REAL_SHAPE_BODY = (
    "## 6. 사용자 원문\n- **S1** 🗣 최초 요청:\n  > s1-token 첫 줄\n  >\n"
    "  > 다시 검증할 것 — shape-recheck\n  > 이어지는 shape-more\n"
    "- **S2** ☑ R1 답:\n  > s2-token\n- **S3** 🗣 R1 답:\n  > s3-token\n"
    "## 7. 뒤\nlater-token\n")

ROADMAP_HEADING_AFTER_RECHECK = (
    _fm(type="roadmap") + "# 로드맵\n## 에픽\n- epic2-token\n"
    "> 다시 검증할 것 — rm2-recheck\n> 이어지는 rm2-more\n"
    "## 지휘 절차\n- choice2-token\n")


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
        "docs/R4.md": _fm(type="epic-bundle", source_brief="docs/brief4.md") + REAL_SHAPE_BODY,
        "docs/roadmap2.md": ROADMAP_HEADING_AFTER_RECHECK,
        "docs/spec_shape.md": _fm(source_interview="docs/R4.md", roadmap="docs/roadmap2.md"),
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

    def test_differential_of_wrong_shape_is_unreadable(self):
        for text in ("just a string\n", "- a\n- b\n"):
            ok, notes = io_.has_evidence(None, text)
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

    def test_real_shape_recheck_quote_keeps_following_items(self):
        o = io_.build_origin(self.R, "HEAD", "HEAD", None, ["docs/spec_shape.md"])
        for kept in ("s1-token", "s2-token", "s3-token", "**S2**", "**S3**"):
            self.assertIn(kept, o["origin"])
        for moved in ("shape-recheck", "shape-more"):
            self.assertNotIn(moved, o["origin"])
            self.assertIn(moved, o["doubts"])
        for stay in ("s2-token", "s3-token", "**S2**"):
            self.assertNotIn(stay, o["doubts"])
        self.assertFalse(o["mixed"])


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

    def test_roadmap_heading_after_recheck_stays(self):
        o = io_.build_origin(self.R, "HEAD", "HEAD", None, ["docs/spec_shape.md"])
        self.assertIn("## 지휘 절차", o["roadmap"])
        self.assertIn("choice2-token", o["roadmap"])
        self.assertIn("epic2-token", o["roadmap"])
        self.assertNotIn("rm2-recheck", o["roadmap"])
        self.assertIn("rm2-recheck", o["doubts"])
        self.assertIn("rm2-more", o["doubts"])
        self.assertNotIn("choice2-token", o["doubts"])

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

    def test_recheck_paragraph_ends_at_heading(self):
        kept, moved = io_.strip_intent_doubts(
            "## Goals\n다시 검증할 것 — v1\n## Constraints\nconstraint-body\n")
        self.assertIn("## Constraints", kept)
        self.assertIn("constraint-body", kept)
        self.assertIn("v1", moved)
        self.assertNotIn("constraint-body", moved)
        kept, moved = io_.move_recheck_paragraphs("> 다시 검증할 것 — v1\n> ### 소제목\n> after\n")
        self.assertIn("### 소제목", kept)
        self.assertNotIn("소제목", moved)

    def test_recheck_quote_ends_at_next_list_item(self):
        text = ("- **S1** 🗣 x:\n  > a\n  >\n  > 다시 검증할 것 — X\n  > X2\n"
                "- **S2** ☑ keep-two\n- **S3** 🗣 keep-three\n")
        kept, moved = io_.move_recheck_paragraphs(text)
        for k in ("keep-two", "keep-three", "- **S2**", "- **S3**", "  > a"):
            self.assertIn(k, kept)
        self.assertIn("다시 검증할 것 — X", moved)
        self.assertIn("X2", moved)
        self.assertNotIn("keep-two", moved)

    def test_recheck_quote_multiline_and_quote_prefix_change(self):
        text = "> 다시 검증할 것 — a1\n> a2\n> a3\nplain-after\n> quote-after\n"
        kept, moved = io_.move_recheck_paragraphs(text)
        for m_ in ("a1", "a2", "a3"):
            self.assertIn(m_, moved)
            self.assertNotIn(m_, kept)
        self.assertIn("plain-after", kept)
        self.assertIn("quote-after", kept)
        text = "다시 검증할 것 — b1\n> quote-after\n"
        kept, moved = io_.move_recheck_paragraphs(text)
        self.assertIn("quote-after", kept)
        self.assertNotIn("quote-after", moved)

    def test_recheck_bullet_ends_at_same_or_shallower_bullet(self):
        text = ("- 다시 검증할 것 — b1\n  이어짐 b2\n  - 자식 b3\n- sibling-token\n"
                "  - nested 다시 검증할 것 — c1\n  - sib2-token\n- parent-token\n")
        kept, moved = io_.move_recheck_paragraphs(text)
        for k in ("sibling-token", "sib2-token", "parent-token"):
            self.assertIn(k, kept)
        for m_ in ("b1", "b2", "b3"):
            self.assertIn(m_, moved)
        text = ("- 항목\n  - 다시 검증할 것 — c1\n  - sib2-token\n- parent-token\n")
        kept, moved = io_.move_recheck_paragraphs(text)
        self.assertIn("sib2-token", kept)
        self.assertIn("parent-token", kept)
        self.assertIn("c1", moved)
        self.assertNotIn("sib2-token", moved)

    def test_total_bytes_korean(self):
        self.assertEqual(io_.total_bytes("가", "a"), 4)
        self.assertEqual(io_.total_bytes(), 0)


# ================================================================ intent_critic.py CLI

SCRIPT = SCRIPTS / "intent_critic.py"
KILL = "DEVBREW_QUALITY_GATES_DISABLE_INTENT_CRITIC"
ENV_DIR = "DEVBREW_QUALITY_GATES_INTENT_ANSWERS_DIR"
ENV_MAX = "DEVBREW_QUALITY_GATES_INTENT_CRITIC_MAX_BYTES"
ANS_DIR = "docs/qg-intent-answers"
SRC = "docs/brief.md"
NONE_LINE = "쓴소리 — 근거 없음"
NOQ_LINE = "쓴소리 — 질문 없음"
UNREAD_LINE = "쓴소리 — 리뷰어 출력을 읽지 못함(셀 수 없음)"


def _env(**extra):
    env = dict(os.environ)
    for k in (KILL, ENV_DIR, ENV_MAX):
        env.pop(k, None)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env.update(extra)
    return env


def _cli(*args, env=None):
    return subprocess.run([sys.executable, str(SCRIPT)] + [str(a) for a in args],
                          capture_output=True, text=True, encoding="utf-8",
                          env=env if env is not None else _env())


def _last(proc):
    lines = proc.stdout.strip().splitlines()
    return lines[-1] if lines else ""


def _read(*parts):
    return Path(*parts).read_text(encoding="utf-8")


def _write(text, *parts):
    Path(*parts).parent.mkdir(parents=True, exist_ok=True)
    Path(*parts).write_text(text, encoding="utf-8")


def _out(questions, none_reason=None):
    """리뷰어 출력 fixture — 산문 사이의 qg-intent-critic 펜스 하나."""
    data = {"questions": questions}
    if none_reason:
        data["none_reason"] = none_reason
    return ("살펴본 결과다.\n```qg-intent-critic\n"
            + yaml.safe_dump(data, allow_unicode=True, sort_keys=False) + "```\n끝.\n")


def _q(tid="D1", kind="방향", weight="방향", lines=(1,), src=SRC, question=None, **extra):
    item = {"target_source": src, "target_id": tid, "kind": kind, "weight": weight,
            "quote": "고른 구절", "label": "고른 라벨",
            "question": question or ("%s 를 정말 이렇게 고른 것인가?" % tid),
            "evidence_lines": list(lines)}
    item.update(extra)
    return item


def _config_text(max_bytes=120000, answers_dir=ANS_DIR):
    return ("answers_dir: %s\nanswers_dir_source: default\nmax_bytes: %d\n"
            "max_bytes_source: default\n" % (answers_dir, max_bytes))


def _filter_rd(rd, call="first-only", mode="pr", sources=(SRC,), aliases=None, answers=(),
               n_evidence=5):
    """filter · record · render 시험용 세션 폴더(config · plan · evidence · 리뷰 트리의 답 파일)."""
    root = os.path.join(rd, "tree", ANS_DIR)
    os.makedirs(root, exist_ok=True)
    for i, (ident, answer, obs) in enumerate(answers):
        _write(ia.render_answer_file(ident, "Q?", "구절", "고른 라벨", [obs], answer, answer,
                                     "t", AT1), root, _wf(i))
    walk = "".join("관찰 %d\n" % i for i in range(1, n_evidence + 1))
    _write(io_.build_evidence(walk, None)[0], rd, "intent-evidence.txt")
    _write(_config_text(), rd, "intent-config.txt")
    plan = ["call: " + call, "mode: " + mode, "answers_root: " + root]
    plan += ["source: " + s for s in sources]
    plan += ["alias: %s -> %s" % kv for kv in (aliases or {}).items()]
    _write("\n".join(plan) + "\n", rd, "intent-plan.txt")
    return root


def _questions(rd):
    return yaml.safe_load(_read(rd, "intent-questions.yaml"))


def _by_state(rd, state):
    return [q for q in _questions(rd)["questions"] if q["state"] == state]


def _return_block(rd):
    text = _read(rd, "intent-return.md")
    body = text.split("```qg-intent-return\n", 1)[1].split("\n```", 1)[0]
    return text, yaml.safe_load(body)


OBS1 = "   1\t[e2e] 관찰 1"
ID1 = SRC + "#D1#방향"


class TestGate(unittest.TestCase):
    def test_kill_switch_first(self):
        for path in ("trivia", "final"):
            with tempfile.TemporaryDirectory() as rd:
                p = _cli("gate", "--rd", rd, "--path", path, env=_env(**{KILL: "1"}))
                self.assertEqual(p.returncode, 0, p.stderr)
                self.assertEqual(_last(p), "쓴소리 꺼짐(kill switch)")
                text, block = _return_block(rd)
                self.assertIn("status: skipped — ", text)
                self.assertEqual(block["questions"], [])
                self.assertFalse(os.path.exists(os.path.join(rd, "result.md")))

    def test_paths(self):
        cases = {"aborted": "쓴소리 — 건너뜀(멈춘 실행)",
                 "trivia": "쓴소리 — 건너뜀(작은 수정 — trivia)",
                 "scope-empty": "쓴소리 — 건너뜀(리뷰할 diff 없음)"}
        for path, line in cases.items():
            with tempfile.TemporaryDirectory() as rd:
                p = _cli("gate", "--rd", rd, "--path", path)
                self.assertEqual((p.returncode, _last(p)), (0, line), path)
                text, block = _return_block(rd)
                self.assertTrue(str(block["status"]).startswith("skipped — "), path)
        with tempfile.TemporaryDirectory() as rd:
            p = _cli("gate", "--rd", rd, "--path", "final")
            self.assertEqual((p.returncode, _last(p)), (0, "intent-gate: run"))
            self.assertFalse(os.path.exists(os.path.join(rd, "intent-return.md")))

    def test_tree_failed_writes_return_block(self):
        with tempfile.TemporaryDirectory() as rd:
            p = _cli("gate", "--rd", rd, "--path", "tree-failed", "--mode", "range")
            self.assertEqual((p.returncode, _last(p)), (0, "쓴소리 — 리뷰 트리를 만들지 못함"))
            text, block = _return_block(rd)
            self.assertIn("status: skipped — 리뷰 트리를 만들지 못함", text)
            self.assertEqual(block["mode"], "range")

    def test_bad_call_is_rc2(self):
        with tempfile.TemporaryDirectory() as rd:
            self.assertEqual(_cli("gate", "--rd", rd, "--path", "bogus").returncode, 2)
            self.assertEqual(_cli("gate", "--path", "final").returncode, 2)
            self.assertEqual(_cli("nope").returncode, 2)


class TestConfig(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = _git_repo(os.path.join(self.tmp.name))
        # 사용자 전역 excludes 가 settings.local.json 을 무시해도 이 리포에서는 .gitignore 만 본다
        _git(self.repo, "config", "core.excludesFile", os.devnull)
        self.rd = tempfile.mkdtemp(dir=self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def _config(self, env=None, base="HEAD"):
        p = _cli("config", "--rd", self.rd, "--repo", self.repo, "--base", base,
                 "--project-dir", self.repo, env=env)
        self.assertEqual(p.returncode, 0, p.stderr)
        out = {}
        for line in p.stdout.strip().splitlines():
            k, _, v = line.partition(": ")
            out[k] = v
        self.assertEqual(_read(self.rd, "intent-config.txt").strip(), p.stdout.strip())
        return out

    def test_default_env_and_settings_changed(self):
        c = self._config()
        self.assertEqual(c, {"answers_dir": ANS_DIR, "answers_dir_source": "default",
                             "max_bytes": "120000", "max_bytes_source": "default"})
        env = _env(**{ENV_DIR: "notes/answers", ENV_MAX: "5000"})
        c = self._config(env)
        self.assertEqual((c["answers_dir"], c["answers_dir_source"]), ("notes/answers", "env"))
        self.assertEqual((c["max_bytes"], c["max_bytes_source"]), ("5000", "env"))
        # 리뷰 트리의 .claude/settings.json 이 base 와 그 키가 다르다 → 그 키만 기본값
        _write(json.dumps({"env": {ENV_DIR: "notes/answers"}}), self.repo, ".claude",
               "settings.json")
        c = self._config(env)
        self.assertEqual((c["answers_dir"], c["answers_dir_source"]),
                         (ANS_DIR, "default-settings-changed"))
        self.assertEqual((c["max_bytes"], c["max_bytes_source"]), ("5000", "env"))
        # base 에 같은 값이 커밋돼 있으면 바뀐 것이 아니다
        _git(self.repo, "add", ".claude/settings.json")
        _git(self.repo, "commit", "-q", "-m", "settings")
        c = self._config(env)
        self.assertEqual(c["answers_dir_source"], "env")

    def test_local_settings_file_also_guarded(self):
        env = _env(**{ENV_MAX: "5000"})
        _write(json.dumps({"env": {ENV_MAX: "5000"}}), self.repo, ".claude",
               "settings.local.json")
        c = self._config(env)
        self.assertEqual((c["max_bytes"], c["max_bytes_source"]),
                         ("120000", "default-settings-changed"))
        # git 이 무시하는 개인 설정 파일은 이 변경의 일부가 아니다
        _write(".claude/settings.local.json\n", self.repo, ".gitignore")
        c = self._config(env)
        self.assertEqual((c["max_bytes"], c["max_bytes_source"]), ("5000", "env"))

    def test_unknown_base(self):
        env = _env(**{ENV_DIR: "notes/answers"})
        c = self._config(env, base="-")
        self.assertEqual(c["answers_dir_source"], "env")
        _write(json.dumps({"env": {ENV_DIR: "notes/answers"}}), self.repo, ".claude",
               "settings.json")
        _git(self.repo, "add", ".claude/settings.json")
        _git(self.repo, "commit", "-q", "-m", "settings")
        c = self._config(env, base="-")
        self.assertEqual((c["answers_dir"], c["answers_dir_source"]),
                         (ANS_DIR, "default-settings-changed"))

    def test_invalid_values(self):
        for bad in ("../x", "/abs", ".claude/x", "a/../../b", ".git/x", " ", "."):
            c = self._config(_env(**{ENV_DIR: bad}))
            self.assertEqual((c["answers_dir"], c["answers_dir_source"]),
                             (ANS_DIR, "default-invalid"), bad)
        for bad in ("0", "abc", "-5", "1.5", ""):
            c = self._config(_env(**{ENV_MAX: bad}))
            self.assertEqual((c["max_bytes"], c["max_bytes_source"]),
                             ("120000", "default-invalid"), bad)
        c = self._config(_env(**{ENV_DIR: "docs/answers/"}))
        self.assertEqual((c["answers_dir"], c["answers_dir_source"]), ("docs/answers", "env"))


class TestPrepare(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.R = _origin_repo(os.path.join(cls.tmp.name))

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def setUp(self):
        self.rd = tempfile.mkdtemp(dir=self.tmp.name)
        _write(_config_text(), self.rd, "intent-config.txt")
        _write("## Goals\ngoal-body\n", self.rd, "intent.md")

    def _prep(self, specs=(), specs_text=None, repo=None, tree_root=None, origin=None):
        sp = os.path.join(self.rd, "intent-specs.json")
        if specs_text is None:
            specs_text = json.dumps({"intent_source": "spec-trailer", "specs": list(specs)})
        _write(specs_text, sp)
        args = ["prepare", "--rd", self.rd, "--repo", repo or self.R,
                "--tree-root", tree_root or repo or self.R, "--mode", "pr", "--head", "HEAD",
                "--review-commit", "HEAD", "--specs-json", sp]
        if origin:
            args += ["--origin", origin]
        p = _cli(*args)
        self.assertEqual(p.returncode, 0, p.stderr)
        return p

    def _f(self, name):
        return _read(self.rd, name)

    def test_none_when_no_evidence(self):
        p = self._prep()
        self.assertEqual(_last(p), "intent-call: none")
        self.assertIn(NONE_LINE, p.stdout.splitlines())
        self.assertIn("call: none", self._f("intent-plan.txt").splitlines())

    def test_none_when_all_green(self):
        _write(_diff("STILL_GREEN", "FIXED", "NEW_TEST_GREEN"), self.rd, "differential.yaml")
        p = self._prep(["docs/spec.md"])
        self.assertEqual(_last(p), "intent-call: none")
        self.assertIn(NONE_LINE, p.stdout.splitlines())

    def test_first_only_without_doubts(self):
        _write("관찰 하나\n", self.rd, "e2e-record.md")
        p = self._prep([])
        self.assertEqual(_last(p), "intent-call: first-only")
        self.assertTrue(self._f("intent-origin.md").startswith("원문 없음 — "))
        self.assertTrue(self._f("intent-roadmap.md").startswith("로드맵 없음 — "))
        self.assertEqual(self._f("intent-doubts.md"), "")
        self.assertIn("   1\t[e2e] 관찰 하나", self._f("intent-evidence.txt"))
        self.assertIn("goal-body", self._f("intent-intent.md"))
        plan = self._f("intent-plan.txt").splitlines()
        self.assertIn("call: first-only", plan)
        self.assertIn("mode: pr", plan)
        self.assertIn("answers_root: " + os.path.abspath(os.path.join(self.R, ANS_DIR)), plan)
        self.assertIn("원문 없음 — 의도 출처에 설계문서 없음", p.stdout.splitlines())

    def test_split_with_bundle(self):
        _write(DIFF_RED, self.rd, "differential.yaml")
        p = self._prep(["docs/spec.md"])
        self.assertEqual(_last(p), "intent-call: split")
        rm, doubts = self._f("intent-roadmap.md"), self._f("intent-doubts.md")
        self.assertIn("epic-body-token", rm)
        for moved in ("risk-section-token", "oq-section-token", "rm-recheck-token"):
            self.assertNotIn(moved, rm)
            self.assertIn(moved, doubts)
        self.assertIn("risk-token", doubts)
        self.assertIn("quote-token", self._f("intent-origin.md"))
        self.assertNotIn("recheck-token", self._f("intent-origin.md"))
        plan = self._f("intent-plan.txt").splitlines()
        self.assertIn("source: docs/brief.md", plan)
        self.assertIn("alias: docs/R1.md -> docs/brief.md", plan)
        self.assertIn("   1\t[차등] per_adapter:", self._f("intent-evidence.txt"))

    def test_split_roadmap_doubts_without_bundle(self):
        with tempfile.TemporaryDirectory() as d:
            repo = _git_repo(d)
            _write(_fm(roadmap="docs/roadmap.md"), repo, "docs", "spec_r.md")
            _write(ROADMAP_BODY, repo, "docs", "roadmap.md")
            _git(repo, "add", "docs")
            _git(repo, "commit", "-q", "-m", "r")
            _write("관찰\n", self.rd, "e2e-record.md")
            p = self._prep(["docs/spec_r.md"], repo=repo)
            self.assertEqual(_last(p), "intent-call: split")
            self.assertTrue(self._f("intent-origin.md").startswith("원문 없음 — "))
            self.assertIn("risk-section-token", self._f("intent-doubts.md"))
            self.assertNotIn("## 5.", self._f("intent-doubts.md"))

    def test_intent_doubts_moved(self):
        _write("관찰\n", self.rd, "e2e-record.md")
        _write("## Goals\ngoal-body\n- 다시 검증할 것 — rv-token\n\n## Risks\nrisk-body\n",
               self.rd, "intent.md")
        p = self._prep([])
        self.assertEqual(_last(p), "intent-call: split")
        kept, doubts = self._f("intent-intent.md"), self._f("intent-doubts.md")
        self.assertIn("goal-body", kept)
        for moved in ("risk-body", "rv-token"):
            self.assertNotIn(moved, kept)
            self.assertIn(moved, doubts.split("<!-- intent-doubts -->", 1)[1])

    def test_single_over_cap_counts_roadmap(self):
        _write(DIFF_RED, self.rd, "differential.yaml")
        self._prep(["docs/spec.md"])
        parts = ("intent-evidence.txt", "intent-origin.md", "intent-roadmap.md",
                 "intent-intent.md", "intent-doubts.md")
        total = io_.total_bytes(*[self._f(n) for n in parts])
        without_roadmap = total - io_.total_bytes(self._f("intent-roadmap.md"))
        cap = total - 1
        self.assertGreaterEqual(cap, without_roadmap)
        _write(_config_text(max_bytes=cap), self.rd, "intent-config.txt")
        p = self._prep(["docs/spec.md"])
        self.assertEqual(_last(p), "intent-call: single")
        self.assertIn("한 번에 넣음 — 입력 %d바이트가 상한 %d바이트를 넘었다" % (total, cap),
                      p.stdout.splitlines())
        self.assertIn("risk-section-token", self._f("intent-doubts.md"))
        self.assertIn("risk-token", self._f("intent-doubts.md"))
        self.assertIn("call: single", self._f("intent-plan.txt").splitlines())
        _write(_config_text(max_bytes=total), self.rd, "intent-config.txt")
        self.assertEqual(_last(self._prep(["docs/spec.md"])), "intent-call: split")

    def test_bad_specs_json(self):
        _write("관찰\n", self.rd, "e2e-record.md")
        for text in ("not json", json.dumps({"specs": "docs/spec.md"}), "[1, 2]"):
            p = self._prep(specs_text=text)
            self.assertIn("의도 출처 JSON 을 읽지 못함", p.stdout.splitlines(), text)
            self.assertEqual(_last(p), "intent-call: first-only", text)

    def test_mixed_old_document_is_disclosed(self):
        _write("관찰\n", self.rd, "e2e-record.md")
        p = self._prep(["docs/spec_old.md"])
        self.assertIn("첫 호출에 의심이 섞였다", p.stdout.splitlines())
        self.assertIn("직접 쓴 말 · 고른 라벨을 가르지 못함", p.stdout.splitlines())

    def test_answered_listing_and_unreadable(self):
        _write("관찰\n", self.rd, "e2e-record.md")
        with tempfile.TemporaryDirectory() as tree:
            _write(_answer_text(), tree, ANS_DIR, _wf(1))
            _write("broken\n", tree, ANS_DIR, "2.md")
            p = self._prep([], tree_root=tree)
            self.assertIn("읽지 못한 답 파일 1", p.stdout.splitlines())
            self.assertIn("- %s · 의도다 · 관찰: 3\t근거" % IDENT,
                          self._f("intent-answered.md").splitlines())

    def test_missing_config_is_rc4(self):
        os.remove(os.path.join(self.rd, "intent-config.txt"))
        sp = os.path.join(self.rd, "intent-specs.json")
        _write("{}", sp)
        p = _cli("prepare", "--rd", self.rd, "--repo", self.R, "--tree-root", self.R,
                 "--mode", "pr", "--head", "HEAD", "--review-commit", "HEAD", "--specs-json", sp)
        self.assertEqual(p.returncode, 4)
        p = _cli("prepare", "--rd", self.rd, "--repo", self.R, "--tree-root", self.R,
                 "--mode", "pr", "--head", "HEAD", "--review-commit", "HEAD",
                 "--specs-json", os.path.join(self.rd, "none.json"))
        self.assertEqual(p.returncode, 4)


class TestCheckOutput(unittest.TestCase):
    def _check(self, text):
        with tempfile.TemporaryDirectory() as d:
            _write(text, d, "out.txt")
            return _cli("check-output", os.path.join(d, "out.txt"))

    def test_check_output_variants(self):
        p = self._check(_out([_q()]))
        self.assertEqual((p.returncode, _last(p)), (0, "readable"))
        p = self._check(_out([], none_reason="물을 것이 없다"))
        self.assertEqual((p.returncode, _last(p)), (0, "readable"))
        fence = "```qg-intent-critic\nquestions: []\n```\n"
        bad = {"two fences": fence + fence,
               "other fence name": "```yaml\nquestions: []\n```\n",
               "prose only": "물을 것이 없다고 본다.\n",
               "broken yaml": "```qg-intent-critic\nquestions: [\n```\n",
               "no questions key": "```qg-intent-critic\nnone_reason: x\n```\n",
               "questions not a list": "```qg-intent-critic\nquestions: 3\n```\n",
               "unclosed": "```qg-intent-critic\nquestions: []\n",
               "empty": ""}
        for name, text in bad.items():
            p = self._check(text)
            self.assertEqual(p.returncode, 3, name)
            self.assertTrue(_last(p).startswith("unreadable: "), name)

    def test_missing_file_is_unreadable(self):
        p = _cli("check-output", "/no/such/file.txt")
        self.assertEqual(p.returncode, 3)
        self.assertTrue(_last(p).startswith("unreadable: "))


class TestDoubtsAppend(unittest.TestCase):
    def test_appends_first_candidates_once(self):
        with tempfile.TemporaryDirectory() as rd:
            _write("의심 본문\n", rd, "intent-doubts.md")
            _write(_out([_q("D1"), _q("D2")]), rd, "intent-critic-1.txt")
            p = _cli("doubts-append", "--rd", rd)
            self.assertEqual(_last(p), "doubts-append: 2")
            text = _read(rd, "intent-doubts.md")
            self.assertTrue(text.startswith("의심 본문\n"))
            self.assertIn("## 첫째 호출의 후보", text)
            self.assertIn("D2 를 정말 이렇게 고른 것인가?", text)
            p = _cli("doubts-append", "--rd", rd)
            self.assertEqual(_read(rd, "intent-doubts.md").count("## 첫째 호출의 후보"), 1)

    def test_heading_inside_doubts_does_not_suppress_append(self):
        with tempfile.TemporaryDirectory() as rd:
            _write("묶음 위험\n## 첫째 호출의 후보\n가짜 후보\n", rd, "intent-doubts.md")
            _write(_out([_q("D1")]), rd, "intent-critic-1.txt")
            self.assertEqual(_last(_cli("doubts-append", "--rd", rd)), "doubts-append: 1")
            text = _read(rd, "intent-doubts.md")
            self.assertEqual(text.count("## 첫째 호출의 후보"), 2)
            self.assertIn("D1 를 정말 이렇게 고른 것인가?", text)

    def test_unreadable_first_appends_nothing(self):
        with tempfile.TemporaryDirectory() as rd:
            _write("의심 본문\n", rd, "intent-doubts.md")
            _write("산문만\n", rd, "intent-critic-1.txt")
            p = _cli("doubts-append", "--rd", rd)
            self.assertEqual(_last(p), "doubts-append: 0")
            self.assertEqual(_read(rd, "intent-doubts.md"), "의심 본문\n")


class TestFilter(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.rd = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def _run(self, first=None, second=None, **kw):
        _filter_rd(self.rd, **kw)
        if first is not None:
            _write(first, self.rd, "intent-critic-1.txt")
        if second is not None:
            _write(second, self.rd, "intent-critic-2.txt")
        p = _cli("filter", "--rd", self.rd)
        self.assertEqual(p.returncode, 0, p.stderr)
        return p

    def _render(self, mode="pr"):
        p = _cli("render", "--rd", self.rd, "--mode", mode)
        self.assertEqual(p.returncode, 0, p.stderr)
        return p

    def test_citation_filter(self):
        p = self._run(_out([_q("D1", lines=[]), _q("D2", lines=[99]),
                            _q("D3", lines=["1"])]))
        self.assertIn("근거 없어 거름 3", p.stdout.splitlines())
        self.assertEqual(_last(p), "intent-ask: 0")
        self.assertEqual(_last(self._render()), NONE_LINE)

    def test_roadmap_question_needs_evidence(self):
        roadmap_q = _q("D7", kind="방향", weight="방향", lines=[], quote="로드맵의 방향 구절")
        no_key = _q("D8")
        del no_key["evidence_lines"]
        p = self._run(_out([roadmap_q, no_key]))
        self.assertIn("근거 없어 거름 2", p.stdout.splitlines())
        self.assertEqual(_last(p), "intent-ask: 0")

    def test_cap_and_weight(self):
        cands = [_q("D1", kind="기본값", weight="동작"), _q("D2", kind="마찰", weight="동작"),
                 _q("D3", kind="방향", weight="방향"), _q("D4", kind="빠진 기능", weight="기능"),
                 _q("D5", kind="범위 축소", weight="기능")]
        p = self._run(_out(cands))
        self.assertEqual(_last(p), "intent-ask: 3")
        self.assertIn("상한 넘어 남김 2", p.stdout.splitlines())
        self.assertEqual([q["target_id"] for q in _by_state(self.rd, "ask")], ["D3", "D4", "D5"])
        self.assertEqual([q["target_id"] for q in _by_state(self.rd, "over-cap")], ["D1", "D2"])

    def test_unknown_weight_goes_last(self):
        p = self._run(_out([_q("D9", weight="이상함"), _q("D1", kind="기본값", weight="동작")]))
        self.assertEqual(_last(p), "intent-ask: 2")
        self.assertEqual([q["target_id"] for q in _by_state(self.rd, "ask")], ["D1", "D9"])

    def test_same_as_filters_intended(self):
        p = self._run(_out([_q("D1", same_as=ID1)]), answers=[(ID1, "의도다", OBS1)])
        self.assertIn("이미 답한 질문이라 거름 1", p.stdout.splitlines())
        self.assertEqual(_last(p), "intent-ask: 0")
        self.assertEqual(_by_state(self.rd, "answered-filtered")[0]["id"], ID1)
        self.assertEqual(_last(self._render()), NOQ_LINE)

    def test_same_as_missing_or_mismatch_asks(self):
        id2 = SRC + "#D2#방향"
        cases = (([_q("D1")], [(ID1, "의도다", OBS1)]),
                 ([_q("D1", same_as=id2)], [(ID1, "의도다", OBS1), (id2, "의도다", OBS1)]),
                 ([_q("D1", same_as=ID1)], []))
        for cands, answers in cases:
            with tempfile.TemporaryDirectory() as rd:
                self.rd = rd
                p = self._run(_out(cands), answers=answers)
                self.assertEqual(_last(p), "intent-ask: 1", (cands, answers))
                self.assertNotIn("이미 답한 질문이라 거름", p.stdout)

    def test_unknown_answer_not_filtered(self):
        p = self._run(_out([_q("D1", same_as=ID1)]), answers=[(ID1, "지금은 모르겠다", OBS1)])
        self.assertEqual(_last(p), "intent-ask: 1")

    def test_wrong_choice_filtered_and_listed(self):
        p = self._run(_out([_q("D1", same_as=ID1, question="잘못 고른 그 질문")]),
                      answers=[(ID1, "잘못 골랐다", OBS1)])
        self.assertIn("이미 답한 질문이라 거름 1", p.stdout.splitlines())
        self.assertEqual(_by_state(self.rd, "wrong-choice-filtered")[0]["id"], ID1)
        _write("## 판정\nv\n## 게시\np\n", self.rd, "result.md")
        self.assertEqual(_last(self._render()), NOQ_LINE)
        section = _read(self.rd, "result.md").split("## 쓴소리", 1)[1]
        self.assertIn("이미 「잘못 골랐다」 답이 있어 거른 질문:", section)
        self.assertIn("잘못 고른 그 질문", section.split("이미 「잘못 골랐다」", 1)[1])

    def test_observation_changed_reasks(self):
        changed = {"previous": "[e2e] 관찰 1", "now_lines": [2]}
        p = self._run(_out([_q("D1", same_as=ID1, observation_changed=changed)]),
                      answers=[(ID1, "의도다", OBS1)])
        self.assertEqual(_last(p), "intent-ask: 1")
        for bad in ({"previous": "없는 관찰 글", "now_lines": [2]},
                    {"previous": "[e2e] 관찰 1", "now_lines": [99]},
                    {"previous": "[e2e] 관찰 1"}, "바뀌었다"):
            with tempfile.TemporaryDirectory() as rd:
                self.rd = rd
                p = self._run(_out([_q("D1", same_as=ID1, observation_changed=bad)]),
                              answers=[(ID1, "의도다", OBS1)])
                self.assertEqual(_last(p), "intent-ask: 0", bad)
                self.assertIn("이미 답한 질문이라 거름 1", p.stdout.splitlines())

    def test_bundle_alias_matches(self):
        p = self._run(_out([_q("D1", src="docs/R1.md", same_as=ID1)]),
                      aliases={"docs/R1.md": SRC}, answers=[(ID1, "의도다", OBS1)])
        self.assertIn("이미 답한 질문이라 거름 1", p.stdout.splitlines())
        self.assertEqual(_last(p), "intent-ask: 0")

    def test_unidentified_asks(self):
        text = "모르는 종류의 질문"
        p = self._run(_out([_q("D1", kind="모르는", question=text)]))
        self.assertEqual(_last(p), "intent-ask: 1")
        self.assertIn("정체를 가르지 못함 1", p.stdout.splitlines())
        ident = "unidentified:" + hashlib.sha1(text.encode("utf-8")).hexdigest()[:12]
        self.assertEqual(_by_state(self.rd, "ask")[0]["id"], ident)
        with tempfile.TemporaryDirectory() as rd:
            self.rd = rd
            p = self._run(_out([_q("D1", src="docs/other.md")]))
            self.assertEqual(_last(p), "intent-ask: 1")
            self.assertIn("정체를 가르지 못함 1", p.stdout.splitlines())

    def test_broken_items_held(self):
        p = self._run(_out(["문자열 항목", _q("D1", question=" "), _q("D2")]))
        self.assertIn("항목 파손 2", p.stdout.splitlines())
        self.assertIn("쓴소리 처분 — 보류: ", p.stdout)
        self.assertEqual(_last(p), "intent-ask: 1")
        disposition = _questions(self.rd)["disposition"]
        self.assertEqual((disposition["held"], disposition["accepted"]), (2, 1))
        self.assertEqual(disposition["held_by_class"]["항목 파손"], 2)

    def test_filter_unreadable_both(self):
        p = self._run("산문만\n", "```qg-intent-critic\nquestions: [\n```\n", call="split")
        self.assertEqual(_last(p), "intent-ask: 0")
        self.assertIn("쓴소리 처분 — 셀 수 없음: ", p.stdout)
        self.assertEqual(_questions(self.rd)["status"], "uncountable")
        disposition = _questions(self.rd)["disposition"]
        self.assertEqual(disposition["unknown_counts"], ["쓴소리 후보"])
        self.assertEqual(disposition["sources_failed"], 1)
        self.assertEqual(_last(self._render()), UNREAD_LINE)
        _, block = _return_block(self.rd)
        self.assertEqual((block["status"], block["questions"]), ("uncountable", []))

    def test_split_first_unreadable_is_uncountable_even_if_second_reads(self):
        p = self._run("산문만\n", _out([_q("D1")]), call="split")
        self.assertEqual(_last(p), "intent-ask: 0")
        self.assertEqual(_last(self._render()), UNREAD_LINE)

    def test_filter_second_unreadable_falls_back(self):
        p = self._run(_out([_q("D1")]), "산문만\n", call="split")
        self.assertIn("둘째 호출 출력을 읽지 못함 — 첫째 호출의 후보만 쓴다", p.stdout.splitlines())
        self.assertIn("쓴소리 처분 — 입력 실패(보조): ", p.stdout)
        self.assertEqual(_last(p), "intent-ask: 1")

    def test_first_only_ignores_second(self):
        p = self._run(_out([_q("D1")]), "산문만\n", call="first-only")
        self.assertNotIn("둘째 호출", p.stdout)
        self.assertNotIn("쓴소리 처분", p.stdout)
        self.assertEqual(_last(p), "intent-ask: 1")

    def test_single_uses_second_only(self):
        p = self._run(None, _out([_q("D1"), _q("D2")]), call="single")
        self.assertEqual(_last(p), "intent-ask: 2")
        with tempfile.TemporaryDirectory() as rd:
            self.rd = rd
            p = self._run(_out([_q("D1")]), "산문만\n", call="single")
            self.assertEqual(_last(p), "intent-ask: 0")
            self.assertEqual(_questions(rd)["status"], "uncountable")

    def test_split_union_absorbs_duplicate(self):
        first = _out([_q("D1"), _q("D4", kind="기본값", weight="동작")])
        second = _out([_q("D1", question="다시 쓴 D1"), _q("D2", kind="빠진 기능", weight="기능")])
        p = self._run(first, second, call="split")
        self.assertEqual(_last(p), "intent-ask: 3")
        self.assertIn("두 호출에서 겹친 후보를 합침 1", p.stdout.splitlines())
        asked = _by_state(self.rd, "ask")
        self.assertEqual([q["target_id"] for q in asked], ["D1", "D2", "D4"])
        self.assertEqual(asked[0]["question"], "D1 를 정말 이렇게 고른 것인가?")
        disposition = _questions(self.rd)["disposition"]
        self.assertEqual((disposition["absorbed"], disposition["accepted"]), (1, 3))
        self.assertIs(disposition["degraded"], False)

    def test_same_call_same_identity_is_not_merged(self):
        p = self._run(_out([_q("D1", question="첫 질문"), _q("D1", question="다른 질문")]))
        self.assertEqual(_last(p), "intent-ask: 2")
        self.assertNotIn("합침", p.stdout)

    def test_no_candidates_is_question_none(self):
        p = self._run(_out([], none_reason="물을 것이 없다"))
        self.assertEqual(_last(p), "intent-ask: 0")
        self.assertEqual(_last(self._render()), NOQ_LINE)

    def test_no_verdict_args_line(self):
        os.makedirs(os.path.join(self.rd, "repo"))
        repo = _git_repo(os.path.join(self.rd, "repo"))
        rd = os.path.join(self.rd, "rd")
        os.makedirs(rd)
        outs = [_cli("gate", "--rd", rd, "--path", "final"),
                _cli("config", "--rd", rd, "--repo", repo, "--base", "HEAD",
                     "--project-dir", repo)]
        _write("관찰 하나\n", rd, "e2e-record.md")
        _write("## Goals\ng\n", rd, "intent.md")
        _write("{}", rd, "intent-specs.json")
        outs.append(_cli("prepare", "--rd", rd, "--repo", repo, "--tree-root", repo,
                         "--mode", "pr", "--head", "HEAD", "--review-commit", "HEAD",
                         "--specs-json", os.path.join(rd, "intent-specs.json")))
        _write(_out([_q("a.txt", src="diff", kind="기본값")]), rd, "intent-critic-1.txt")
        _write(_out([]), rd, "intent-critic-2.txt")
        outs.append(_cli("check-output", os.path.join(rd, "intent-critic-1.txt")))
        outs.append(_cli("doubts-append", "--rd", rd))
        outs.append(_cli("filter", "--rd", rd))
        _write("=== id: diff#a.txt#기본값 · pick: 의도다\n", rd, "answers.txt")
        outs.append(_cli("record", "--rd", rd, "--repo", repo, "--answers",
                         os.path.join(rd, "answers.txt")))
        outs.append(_cli("render", "--rd", rd, "--mode", "pr"))
        self.assertEqual(_last(outs[-3]), "intent-ask: 1")
        self.assertEqual(_last(outs[-2]), "record: 1")
        for p in outs:
            self.assertEqual(p.returncode, 0, p.args)
            for line in p.stdout.splitlines():
                self.assertFalse(line.startswith("qg-verdict-args:"), line)


class TestRecord(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        os.makedirs(os.path.join(self.tmp.name, "repo"))
        self.repo = _git_repo(os.path.join(self.tmp.name, "repo"))
        self.rd = os.path.join(self.tmp.name, "rd")
        os.makedirs(self.rd)

    def tearDown(self):
        self.tmp.cleanup()

    def _asked(self, cands, mode="pr"):
        _filter_rd(self.rd, mode=mode, sources=(SRC,))
        _write(_out(cands), self.rd, "intent-critic-1.txt")
        p = _cli("filter", "--rd", self.rd)
        self.assertEqual(_last(p), "intent-ask: %d" % len(cands))
        return [q["id"] for q in _by_state(self.rd, "ask")]

    def _record(self, text):
        _write(text, self.tmp.name, "answers.txt")
        p = _cli("record", "--rd", self.rd, "--repo", self.repo, "--answers",
                 os.path.join(self.tmp.name, "answers.txt"))
        self.assertEqual(p.returncode, 0, p.stderr)
        return p

    def _files(self):
        d = os.path.join(self.repo, ANS_DIR)
        return sorted(os.listdir(d)) if os.path.isdir(d) else []

    def _parsed(self, name):
        return ia.parse_answer_file(_read(self.repo, ANS_DIR, name))

    def test_record_labels_writes_and_commits(self):
        Path(self.repo, "a.txt").write_text("user change\n", encoding="utf-8")
        _git(self.repo, "add", "a.txt")
        _write("관찰 하나\n", self.rd, "e2e-record.md")
        _write("## Goals\ng\n", self.rd, "intent.md")
        _write("{}", self.rd, "intent-specs.json")
        _cli("config", "--rd", self.rd, "--repo", self.repo, "--base", "HEAD",
             "--project-dir", self.repo)
        p = _cli("prepare", "--rd", self.rd, "--repo", self.repo, "--tree-root", self.repo,
                 "--mode", "pr", "--head", "HEAD", "--review-commit", "HEAD",
                 "--specs-json", os.path.join(self.rd, "intent-specs.json"))
        self.assertEqual(_last(p), "intent-call: first-only")
        _write(_out([_q("a.txt", src="diff", kind="기본값")]), self.rd, "intent-critic-1.txt")
        self.assertEqual(_last(_cli("filter", "--rd", self.rd)), "intent-ask: 1")
        ident = _by_state(self.rd, "ask")[0]["id"]
        self.assertEqual(ident, "diff#a.txt#기본값")
        p = self._record("=== id: %s · pick: 의도다\n" % ident)
        self.assertEqual(_last(p), "record: 1")
        self.assertIn("답 파일 1개를 커밋했다(", p.stdout)
        files = self._files()
        self.assertEqual(len(files), 1)
        parsed = self._parsed(files[0])
        self.assertEqual((parsed["id"], parsed["answer"]), (ident, "의도다"))
        self.assertIn("[e2e] 관찰 하나", parsed["observation"])
        self.assertTrue(parsed["target"].startswith("tree "))
        self.assertIn(" · dirty yes", parsed["target"])
        shown = _git(self.repo, "show", "--name-only", "--format=", "HEAD").stdout.split()
        self.assertEqual(shown, [ANS_DIR + "/" + files[0]])
        self.assertEqual(_git(self.repo, "diff", "--cached", "--name-only").stdout.split(),
                         ["a.txt"])
        self.assertIn("docs(qg-intent): 쓴소리 답 1개 기록",
                      _git(self.repo, "log", "-1", "--format=%s").stdout)
        q = _by_state(self.rd, "answered")[0]
        self.assertEqual((q["answer"], q["file"]), ("의도다", ANS_DIR + "/" + files[0]))

    def test_record_typed_multiline_and_fake_header(self):
        ids = self._asked([_q("D1"), _q("D2", kind="기본값", weight="동작")])
        typed = ("잘못 골랐다 — 이유\n=== id: 모르는#정체#방향\n둘째 줄\t탭 뒤\n"
                 "=== id: %s · pick: 아마\n=== id: %s · pick: 의도다\n" % (ids[1], ids[0]))
        p = self._record("=== id: %s · pick: typed\n%s" % (ids[0], typed))
        self.assertEqual(_last(p), "record: 1")
        files = self._files()
        self.assertEqual(len(files), 1)
        parsed = self._parsed(files[0])
        self.assertEqual((parsed["id"], parsed["answer"]), (ids[0], "잘못 골랐다"))
        body = _read(self.repo, ANS_DIR, files[0]).split("## 답 원문\n", 1)[1]
        for part in ("잘못 골랐다 — 이유", "=== id: 모르는#정체#방향", "둘째 줄\t탭 뒤",
                     "pick: 아마", "=== id: %s · pick: 의도다" % ids[0]):
            self.assertIn(part, body)
        self.assertEqual(len(_by_state(self.rd, "answered")), 1)
        self.assertEqual(_by_state(self.rd, "ask")[0]["id"], ids[1])

    def test_record_two_answers(self):
        ids = self._asked([_q("D1"), _q("D2", kind="기본값", weight="동작")])
        p = self._record("=== id: %s · pick: 잘못 골랐다\n=== id: %s · pick: 지금은 모르겠다\n"
                         % (ids[0], ids[1]))
        self.assertEqual(_last(p), "record: 2")
        answers = sorted(self._parsed(n)["answer"] for n in self._files())
        self.assertEqual(answers, ["잘못 골랐다", "지금은 모르겠다"])

    def test_record_typed_unknown_prefix(self):
        ids = self._asked([_q("D1")])
        self._record("=== id: %s · pick: typed\n글쎄\n" % ids[0])
        files = self._files()
        parsed = self._parsed(files[0])
        self.assertEqual(parsed["answer"], "지금은 모르겠다")
        self.assertIn("글쎄", _read(self.repo, ANS_DIR, files[0]).split("## 답 원문\n", 1)[1])

    def test_record_unidentified_answer_file(self):
        ids = self._asked([_q("D1", kind="모르는", question="모르는 질문")])
        self.assertTrue(ids[0].startswith("unidentified:"))
        self._record("=== id: %s · pick: 의도다\n" % ids[0])
        self.assertEqual(self._parsed(self._files()[0])["id"], ids[0])
        self.assertEqual(ia.read_answered(os.path.join(self.repo, ANS_DIR)), ({}, 0))

    def test_record_commit_failure_keeps_file(self):
        ids = self._asked([_q("D1")])
        _git(self.repo, "checkout", "-q", "--detach")
        p = self._record("=== id: %s · pick: 의도다\n" % ids[0])
        self.assertIn("답 파일을 커밋하지 못했다 — 브랜치가 아니다(detached HEAD)(파일은 남겼다)",
                      p.stdout.splitlines())
        self.assertEqual(_last(p), "record: 1")
        self.assertEqual(len(self._files()), 1)
        self.assertEqual(_questions(self.rd)["commit"], "failed — 브랜치가 아니다(detached HEAD)")
        _cli("render", "--rd", self.rd, "--mode", "pr")
        text, block = _return_block(self.rd)
        self.assertIn("commit: failed — 브랜치가 아니다(detached HEAD)", text)
        self.assertEqual(block["questions"][0]["file"], ANS_DIR + "/" + self._files()[0])

    def test_record_write_failure_is_disclosed(self):
        ids = self._asked([_q("D1")])
        Path(self.repo, "a.txt").write_text("user change\n", encoding="utf-8")
        _git(self.repo, "add", "a.txt")
        with tempfile.TemporaryDirectory() as other:
            os.makedirs(os.path.join(self.repo, "docs"))
            os.symlink(other, os.path.join(self.repo, ANS_DIR))
            head = _git(self.repo, "rev-parse", "HEAD").stdout
            p = self._record("=== id: %s · pick: 의도다  \n" % ids[0])
            self.assertIn("답 파일을 쓰지 못했다 — 답 자리가 심볼릭 링크다", p.stdout.splitlines())
            self.assertEqual(_last(p), "record: 0")
            self.assertEqual(os.listdir(other), [])
            self.assertEqual(_git(self.repo, "rev-parse", "HEAD").stdout, head)
            self.assertEqual(_git(self.repo, "diff", "--cached", "--name-only").stdout.split(),
                             ["a.txt"])
            _cli("render", "--rd", self.rd, "--mode", "pr")
            text, block = _return_block(self.rd)
            self.assertEqual(block["commit"], "failed — 답 자리가 심볼릭 링크다")
            self.assertIn("답 파일을 쓰지 못했다 — 답 자리가 심볼릭 링크다",
                          _read(self.rd, "result.md"))

    def test_record_does_not_write_session_drafts(self):
        ids = self._asked([_q("D1")])
        before = sorted(os.listdir(self.rd))
        self._record("=== id: %s · pick: 의도다\n" % ids[0])
        self.assertFalse(os.path.exists(os.path.join(self.rd, "intent-answers")))
        self.assertEqual(sorted(os.listdir(self.rd)), before)

    def test_record_range_mode_writes_nothing(self):
        ids = self._asked([_q("D1")], mode="range")
        head = _git(self.repo, "rev-parse", "HEAD").stdout
        p = self._record("=== id: %s · pick: 의도다\n" % ids[0])
        self.assertEqual(_last(p), "record: 0")
        self.assertEqual(self._files(), [])
        self.assertEqual(_git(self.repo, "rev-parse", "HEAD").stdout, head)


class TestRender(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.rd = self.tmp.name
        _filter_rd(self.rd)

    def tearDown(self):
        self.tmp.cleanup()

    def _qy(self, questions, commit="-", status="ran"):
        data = {"status": status, "call": "first-only", "counts": {}, "notices": [],
                "commit": commit, "questions": questions}
        _write(yaml.safe_dump(data, allow_unicode=True), self.rd, "intent-questions.yaml")

    def _item(self, tid, state, answer=None, file=None):
        q = {"id": SRC + "#%s#방향" % tid, "state": state, "question": "%s 질문 | 줄" % tid,
             "target_id": tid}
        if answer:
            q["answer"] = answer
        if file:
            q["file"] = file
        return q

    def test_render_pr_and_return_block(self):
        self._qy([self._item("D1", "answered", "의도다", ANS_DIR + "/a.md"),
                  self._item("D2", "answered", "지금은 모르겠다", ANS_DIR + "/b.md"),
                  self._item("D3", "over-cap")], commit="abc1234")
        p = _cli("render", "--rd", self.rd, "--mode", "pr")
        self.assertEqual(_last(p), "쓴소리 — 질문 2개를 물었다 · 답 2개(잘못 골랐다 0개)")
        text, block = _return_block(self.rd)
        self.assertEqual((block["status"], block["mode"], block["commit"]),
                         ("ran", "pr", "abc1234"))
        self.assertEqual((block["answers_dir"], block["answers_dir_source"]), (ANS_DIR, "default"))
        rows = block["questions"]
        self.assertEqual([r["state"] for r in rows], ["답함", "답함", "상한 넘어 남김"])
        self.assertEqual([r["file"] for r in rows], [ANS_DIR + "/a.md", ANS_DIR + "/b.md", "-"])
        self.assertEqual([r["answer"] for r in rows], ["의도다", "지금은 모르겠다", "-"])
        self.assertEqual(text.count("    wrong_choice: no\n"), 3)
        self.assertEqual([r["wrong_choice"] for r in rows], [False, False, False])
        section = _read(self.rd, "result.md").split("## 쓴소리", 1)[1]
        self.assertIn("| 정체 | 상태 | 답 | 답 파일 | 질문 |", section)
        self.assertIn("상한 넘어 남김:", section)
        self.assertIn("D3 질문", section.split("상한 넘어 남김:", 1)[1])
        self.assertNotIn("이미 「잘못 골랐다」", section)

    def test_render_wrong_choice_counted(self):
        self._qy([self._item("D1", "answered", "잘못 골랐다", ANS_DIR + "/a.md")], commit="abc")
        p = _cli("render", "--rd", self.rd, "--mode", "pr")
        self.assertEqual(_last(p), "쓴소리 — 질문 1개를 물었다 · 답 1개(잘못 골랐다 1개)")
        text, block = _return_block(self.rd)
        self.assertIn("    wrong_choice: yes\n", text)
        self.assertIs(block["questions"][0]["wrong_choice"], True)

    def test_render_range_not_asked(self):
        self._qy([self._item("D1", "ask"), self._item("D2", "ask")])
        p = _cli("render", "--rd", self.rd, "--mode", "range")
        self.assertEqual(_last(p), "쓴소리 — 질문 2개 아직 묻지 않음(범위 모드)")
        text, block = _return_block(self.rd)
        self.assertEqual(block["commit"], "-")
        self.assertEqual([r["state"] for r in block["questions"]], ["아직 묻지 않음"] * 2)
        self.assertEqual([r["file"] for r in block["questions"]], ["-", "-"])
        self.assertEqual(block["mode"], "range")

    def test_render_appends_after_publish_once(self):
        before = "# 결과\n## 판정\nverdict-line\n## 게시\n게시함\n"
        _write(before, self.rd, "result.md")
        self._qy([])
        p = _cli("render", "--rd", self.rd, "--mode", "pr")
        self.assertEqual(_last(p), NOQ_LINE)
        after = _read(self.rd, "result.md")
        self.assertTrue(after.startswith(before))
        self.assertGreater(after.index("## 쓴소리"), after.index("## 게시"))
        p = _cli("render", "--rd", self.rd, "--mode", "pr")
        self.assertEqual((p.returncode, _last(p)),
                         (0, "쓴소리 — 이 실행은 이미 쓴소리 단계를 돌았다"))
        self.assertEqual(_read(self.rd, "result.md"), after)

    def test_heading_before_publish_does_not_block_render(self):
        before = "## 판정\nv\n## e2e\n## 쓴소리 흉내 줄\n## 게시\n게시함\n"
        _write(before, self.rd, "result.md")
        self._qy([])
        p = _cli("render", "--rd", self.rd, "--mode", "pr")
        self.assertEqual(_last(p), NOQ_LINE)
        after = _read(self.rd, "result.md")
        self.assertGreater(after.rindex("## 쓴소리"), after.index("## 게시"))
        with tempfile.TemporaryDirectory() as rd:
            _filter_rd(rd)
            _write(yaml.safe_dump({"status": "ran", "questions": []}), rd,
                   "intent-questions.yaml")
            _write("## 판정\nv\n## e2e\n## 쓴소리 흉내 줄\n", rd, "result.md")
            p = _cli("render", "--rd", rd, "--mode", "range")
            self.assertEqual(_last(p), NOQ_LINE)
            self.assertIn("\n## 쓴소리\n", _read(rd, "result.md"))

    def test_render_missing_plan_is_uncountable(self):
        os.remove(os.path.join(self.rd, "intent-plan.txt"))
        p = _cli("render", "--rd", self.rd, "--mode", "pr")
        self.assertEqual(_last(p), UNREAD_LINE)
        self.assertEqual(_return_block(self.rd)[1]["status"], "uncountable")

    def test_render_no_evidence(self):
        _write("call: none\nmode: pr\nanswers_root: /x\n", self.rd, "intent-plan.txt")
        p = _cli("render", "--rd", self.rd, "--mode", "pr")
        self.assertEqual(_last(p), NONE_LINE)
        self.assertEqual(_return_block(self.rd)[1]["status"], "skipped — 근거 없음")


ic = _load("intent_critic")


class TestRecordSilentDrops(unittest.TestCase):
    """사용자가 친 답이 공시 없이 버려지지 않는다(리뷰 Important 1)."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        os.makedirs(os.path.join(self.tmp.name, "repo"))
        self.repo = _git_repo(os.path.join(self.tmp.name, "repo"))
        self.rd = os.path.join(self.tmp.name, "rd")
        os.makedirs(self.rd)
        _filter_rd(self.rd)
        _write(_out([_q("D1")]), self.rd, "intent-critic-1.txt")
        self.assertEqual(_last(_cli("filter", "--rd", self.rd)), "intent-ask: 1")
        self.ident = _by_state(self.rd, "ask")[0]["id"]

    def tearDown(self):
        self.tmp.cleanup()

    def _record(self, text):
        _write(text, self.tmp.name, "answers.txt")
        p = _cli("record", "--rd", self.rd, "--repo", self.repo, "--answers",
                 os.path.join(self.tmp.name, "answers.txt"))
        self.assertEqual(p.returncode, 0, p.stderr)
        return p

    def _rendered(self):
        _cli("render", "--rd", self.rd, "--mode", "pr")
        return _read(self.rd, "result.md").split("## 쓴소리", 1)[1]

    def test_wrong_id_header_is_disclosed(self):
        p = self._record("=== id: docs/brief.md#D9#방향 · pick: 의도다\n이유 글\n")
        line = "답 입력에서 묻는 질문의 머리를 찾지 못함 — 묻는 질문 1개"
        self.assertIn(line, p.stdout.splitlines())
        self.assertIn("머리 앞의 답 글을 읽지 못함 2줄", p.stdout.splitlines())
        self.assertEqual(_last(p), "record: 0")
        self.assertIn(line, _questions(self.rd)["record_notices"])
        self.assertIn(line, self._rendered())

    def test_text_before_first_header_is_disclosed(self):
        p = self._record("앞에 쓴 말\n\n=== id: %s · pick: 의도다\n" % self.ident)
        self.assertIn("머리 앞의 답 글을 읽지 못함 1줄", p.stdout.splitlines())
        self.assertEqual(_last(p), "record: 1")
        self.assertIn("머리 앞의 답 글을 읽지 못함 1줄", _questions(self.rd)["record_notices"])
        self.assertIn("머리 앞의 답 글을 읽지 못함 1줄", self._rendered())

    def test_missing_plan_in_pr_is_disclosed(self):
        os.remove(os.path.join(self.rd, "intent-plan.txt"))
        p = self._record("=== id: %s · pick: 의도다\n" % self.ident)
        line = "답을 기록하지 못했다 — 준비 파일(intent-plan.txt)을 읽지 못함"
        self.assertIn(line, p.stdout.splitlines())
        self.assertEqual(_last(p), "record: 0")
        self.assertIn(line, _questions(self.rd)["record_notices"])
        self.assertIn(line, self._rendered())

    def test_blank_input_has_no_drop_notice(self):
        p = self._record("\n\n")
        self.assertEqual(p.stdout.strip(), "record: 0")


class TestPlanInjection(unittest.TestCase):
    """리뷰 트리에서 읽은 값이 줄 단위 세션 파일에 줄을 덧쓰지 못한다(SEC-1)."""

    INJECT = '"docs/b.md\\nanswers_root: /elsewhere\\ncall: single"'

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = _git_repo(self.tmp.name)
        files = {
            "docs/spec_inj.md": _fm(source_interview="docs/RB.md"),
            "docs/RB.md": _fm(type="epic-bundle", source_brief=self.INJECT)
            + "## 6. 사용자 원문\nrb-quote\n## 5. 기각 · 위험\nrb-risk\n",
            "docs/spec_arrow.md": _fm(source_interview="docs/RA.md"),
            "docs/RA.md": _fm(type="epic-bundle", source_brief='"docs/x -> y.md"')
            + "## 6. 사용자 원문\nra-quote\n",
            "docs/spec_rm.md": _fm(roadmap='"docs/rm.md\\nanswers_root: /elsewhere"'),
            "docs/spec_si.md": _fm(source_interview='"docs/RB.md\\ncall: single"'),
        }
        for rel, text in files.items():
            _write(text, self.repo, rel)
        _git(self.repo, "add", "docs")
        _git(self.repo, "commit", "-q", "-m", "inj")
        self.rd = tempfile.mkdtemp(dir=self.tmp.name)
        _write(_config_text(), self.rd, "intent-config.txt")
        _write("관찰\n", self.rd, "e2e-record.md")

    def tearDown(self):
        self.tmp.cleanup()

    def _prep(self, spec, tree_root=None):
        sp = os.path.join(self.rd, "intent-specs.json")
        _write(json.dumps({"specs": [spec]}), sp)
        return _cli("prepare", "--rd", self.rd, "--repo", self.repo,
                    "--tree-root", tree_root or self.repo, "--mode", "pr", "--head", "HEAD",
                    "--review-commit", "HEAD", "--specs-json", sp)

    def _plan_lines(self):
        return _read(self.rd, "intent-plan.txt").splitlines()

    def test_source_brief_newline_cannot_rewrite_plan(self):
        p = self._prep("docs/spec_inj.md")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("묶음 source_brief 거부 — 여러 줄 또는 제어 문자", p.stdout.splitlines())
        plan = self._plan_lines()
        roots = [x for x in plan if x.startswith("answers_root:")]
        self.assertEqual(roots, ["answers_root: " + os.path.abspath(os.path.join(self.repo,
                                                                                 ANS_DIR))])
        self.assertEqual([x for x in plan if x.startswith("call:")], ["call: split"])
        self.assertNotIn("/elsewhere", "\n".join(plan))
        self.assertIn("source: docs/RB.md", plan)
        built = io_.build_origin(self.repo, "HEAD", "HEAD", None, ["docs/spec_inj.md"])
        self.assertEqual((built["aliases"], built["sources"]), ({}, ["docs/RB.md"]))

    def test_link_values_with_newline_are_refused(self):
        self.assertEqual(io_.read_tracked(self.repo, "HEAD", "docs/a\nb.md"),
                         (None, "여러 줄 또는 제어 문자"))
        self.assertEqual(io_.read_tracked(self.repo, "HEAD", "docs/a\tb.md"),
                         (None, "여러 줄 또는 제어 문자"))
        built = io_.build_origin(self.repo, "HEAD", "HEAD", None, ["docs/spec_rm.md"])
        self.assertIn("로드맵 링크 거부 — 여러 줄 또는 제어 문자", built["notices"])
        built = io_.build_origin(self.repo, "HEAD", "HEAD", None, ["docs/spec_si.md"])
        self.assertIn("원문 링크 거부 — 여러 줄 또는 제어 문자", built["notices"])
        self.assertEqual(built["sources"], [])

    def test_alias_arrow_is_not_written(self):
        p = self._prep("docs/spec_arrow.md")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("묶음 별칭 거부 — ' -> ' 또는 제어 문자", p.stdout.splitlines())
        self.assertEqual([x for x in self._plan_lines() if x.startswith("alias:")], [])

    def test_write_plan_guards_values(self):
        notices = []
        ic._write_plan(self.rd, "split", "pr", "/root/answers",
                       ["ok.md", "bad.md\nanswers_root: /elsewhere"],
                       {"b.md": "c.md", "d.md": "e.md\ncall: single", "f.md": "g -> h.md"},
                       notices)
        plan = ic._read_plan(self.rd)
        self.assertEqual((plan["call"], plan["answers_root"]), ("split", "/root/answers"))
        self.assertEqual(plan["sources"], ["ok.md"])
        self.assertEqual(plan["aliases"], {"b.md": "c.md"})
        self.assertIn("의도 출처 경로 거부 — 여러 줄 또는 제어 문자", notices)
        self.assertEqual(notices.count("묶음 별칭 거부 — ' -> ' 또는 제어 문자"), 2)

    def test_tree_root_with_newline_is_rc4(self):
        p = self._prep("docs/spec_inj.md", tree_root=self.repo + "\nanswers_root: /x")
        self.assertEqual(p.returncode, 4)

    def test_duplicated_singleton_plan_key_is_unreadable(self):
        for dup in ("answers_root: /elsewhere\n", "call: single\n", "mode: range\n"):
            with tempfile.TemporaryDirectory() as rd:
                _filter_rd(rd)
                _write(_read(rd, "intent-plan.txt") + dup, rd, "intent-plan.txt")
                _write(_out([_q("D1")]), rd, "intent-critic-1.txt")
                p = _cli("filter", "--rd", rd)
                self.assertEqual(_last(p), "intent-ask: 0", dup)
                self.assertEqual(_questions(rd)["status"], "uncountable", dup)
                self.assertIsNone(ic._read_plan(rd), dup)

    def test_duplicated_config_key_is_unreadable(self):
        _write(_config_text() + "answers_dir: ../elsewhere\n", self.rd, "intent-config.txt")
        self.assertIsNone(ic._read_config(self.rd))
        self.assertEqual(self._prep("docs/spec_inj.md").returncode, 4)


class TestFilteredListed(unittest.TestCase):
    """거른 질문마다 정체 · 답 · 답 파일 경로를 보인다(SEC-2)."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.rd = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def _run(self, answers, cands, names=None):
        _filter_rd(self.rd, answers=answers)
        for n, text in (names or {}).items():
            _write(text, self.rd, "review-i%d.names" % n)
        _write(_out(cands), self.rd, "intent-critic-1.txt")
        f = _cli("filter", "--rd", self.rd)
        _write("## 판정\nv\n## 게시\np\n", self.rd, "result.md")
        r = _cli("render", "--rd", self.rd, "--mode", "pr")
        section = _read(self.rd, "result.md").split("## 쓴소리", 1)[1]
        return f, r, section

    def _listed(self, section):
        head = "이미 답한 질문이라 거른 질문:"
        self.assertIn(head, section)
        out = []
        for line in section.split(head, 1)[1].lstrip("\n").splitlines():
            if not line.startswith("- "):
                break
            out.append(line)
        return out

    def test_filtered_intended_question_listed_with_file(self):
        f, r, section = self._run([(ID1, "의도다", OBS1)], [_q("D1", same_as=ID1)])
        self.assertIn("이미 답한 질문이라 거름 1", section)
        rows = self._listed(section)
        self.assertEqual(len(rows), 1)
        self.assertIn(ID1, rows[0])
        self.assertIn("의도다", rows[0])
        self.assertIn(ANS_DIR + "/" + _wf(0), rows[0])
        self.assertNotIn("이 범위가 더한 답 파일", rows[0])

    def test_count_and_list_agree(self):
        id2 = SRC + "#D2#방향"
        f, r, section = self._run([(ID1, "의도다", OBS1), (id2, "잘못 골랐다", OBS1)],
                                  [_q("D1", same_as=ID1), _q("D2", same_as=id2), _q("D3")])
        self.assertIn("이미 답한 질문이라 거름 2", section)
        rows = self._listed(section)
        self.assertEqual(len(rows), 2)
        self.assertIn("잘못 골랐다", rows[1])
        self.assertIn(ANS_DIR + "/" + _wf(1), rows[1])
        self.assertIn("이미 「잘못 골랐다」 답이 있어 거른 질문:", section)

    def test_range_added_answer_file_is_marked(self):
        names = {1: "a.txt\n", 2: "a.txt\n%s/%s\n" % (ANS_DIR, _wf(0))}
        f, r, section = self._run([(ID1, "의도다", OBS1)], [_q("D1", same_as=ID1)], names)
        self.assertIn("이 범위가 더한 답 파일", self._listed(section)[0])
        with tempfile.TemporaryDirectory() as rd:
            self.rd = rd
            names = {1: "%s/%s\n" % (ANS_DIR, _wf(0)), 2: "a.txt\n"}
            f, r, section = self._run([(ID1, "의도다", OBS1)], [_q("D1", same_as=ID1)], names)
            self.assertNotIn("이 범위가 더한 답 파일", self._listed(section)[0])

    def test_odd_answer_file_names_do_not_filter(self):
        root = _filter_rd(self.rd)
        for name in ("x.md", "20261114T010203Z\n-000000000001.md"):
            _write(ia.render_answer_file(ID1, "Q?", "구절", "고른 라벨", [OBS1], "의도다",
                                         "의도다", "t", AT1), root, name)
        _write(_out([_q("D1", same_as=ID1)]), self.rd, "intent-critic-1.txt")
        p = _cli("filter", "--rd", self.rd)
        self.assertEqual(_last(p), "intent-ask: 1")
        self.assertNotIn("이미 답한 질문이라 거름", p.stdout)
        self.assertEqual(ia.read_answered(root), ({}, 2))

    def test_no_names_list_is_disclosed(self):
        f, r, section = self._run([(ID1, "의도다", OBS1)], [_q("D1", same_as=ID1)])
        self.assertIn("바뀐 파일 목록(review-i<N>.names)이 없어 이 범위가 더한 답 파일을 가리지 못함",
                      section)


if __name__ == "__main__":
    unittest.main()
