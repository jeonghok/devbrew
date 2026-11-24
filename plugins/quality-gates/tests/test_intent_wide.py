"""R2 넓게 보는 조언자 — 표시 · 넓이 · 준비 · 거름 · 렌더(scripts/intent_origin.py · intent_critic.py)."""
import argparse
import json
import os
import shutil
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import test_intent_critic as tic  # noqa: E402 — 헬퍼만 빌린다

io_ = tic.io_
ia = tic.ia
ic = tic._load("intent_critic")
ot = tic._load("other_teams")
MARKERS = list(io_.DEFAULT_MARKERS)
OTHER_MAX = "DEVBREW_QUALITY_GATES_OTHER_TEAMS_MAX_BYTES"
ENV_MARKERS = "DEVBREW_QUALITY_GATES_INTENT_DOC_MARKERS"
DIFF_SHAPE = "차등 결과의 꼴이 다르다 — 읽지 못한 부분은 근거로 세지 않았다"
REC = "docs/rm/one/reviews/2026-11-20-roadmap-end.md"
UNREAD_ONE = "의도 문서인지 확인 못 한 문서 1 — 추적되지 않는다"


def _ok(repo, *args):
    p = tic._git(repo, *args)
    if p.returncode != 0:
        raise AssertionError("git %s: %s" % (" ".join(args), p.stderr))
    return p.stdout.strip()


WIDE_FILES = {
    "docs/brief.md": "## 6. 사용자 원문\nbrief-quote-token\n",
    "docs/rm/one/roadmap.md": tic._fm(type="roadmap", source_brief="docs/brief.md")
    + "### R1 — 하나\n- 의도: one-intent-token\n",
    "docs/rm/one/R1.md": tic._fm(type="epic-bundle", roadmap="docs/rm/one/roadmap.md",
                                 source_brief="docs/brief.md")
    + "## 6. 사용자 원문\nbundle-quote-token\n",
    "docs/specs/x-design.md": tic._fm(source_interview="docs/rm/one/R1.md",
                                      roadmap="docs/rm/one/roadmap.md"),
    "docs/guide.md": "# 안내\n",
    "docs/seed.md": tic._fm(type="seed"),
    "src/a.py": "x = 1\n",
}


def _wide_repo(root):
    """넓게 보는 리뷰 시험용 리포 — 첫 커밋(init) 위에 문서 · 코드를 한 커밋으로(「wide fixture」)."""
    os.makedirs(root, exist_ok=True)
    tic._git_repo(root)
    for rel, text in WIDE_FILES.items():
        tic._write(text, root, rel)
    _ok(root, "add", "docs", "src")
    _ok(root, "commit", "-q", "-m", "wide fixture")
    return root


def _other_branch(repo):
    """origin ref 를 세우고(원격 URL 없음 — gh 가 불리지 않는다) src/a.py 를 고친 다른 브랜치를 둔다."""
    _ok(repo, "update-ref", "refs/remotes/origin/main", _ok(repo, "rev-parse", "HEAD"))
    _ok(repo, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main")
    _ok(repo, "checkout", "-q", "-b", "feature/other")
    tic._write("x = 2\n", repo, "src", "a.py")
    _ok(repo, "commit", "-q", "-am", "other")
    _ok(repo, "checkout", "-q", "main")
    if _ok(repo, "remote"):
        raise AssertionError("이 리포에 원격이 있으면 열린 PR 조회가 네트워크에 닿는다")


class TestMarkers(unittest.TestCase):
    def test_parse(self):
        self.assertEqual(io_.parse_markers("roadmap, type=seed"), ["roadmap", "type=seed"])
        self.assertEqual(io_.parse_markers(",".join(io_.DEFAULT_MARKERS)), MARKERS)
        self.assertEqual(io_.parse_markers("type=v1.2,a_b-c"), ["type=v1.2", "a_b-c"])
        for bad in ("", " , ", "type=", "=x", "a b", "a=b=c", "키", "roadmap\n", "a,=b",
                    "a.b", "a.b=c"):
            self.assertIsNone(io_.parse_markers(bad), bad)

    def test_is_intent_doc(self):
        self.assertTrue(io_.is_intent_doc(tic._fm(source_interview="x.md"), MARKERS))
        self.assertTrue(io_.is_intent_doc(tic._fm(source_brief="x.md"), MARKERS))
        self.assertTrue(io_.is_intent_doc(tic._fm(type="roadmap"), MARKERS))
        self.assertTrue(io_.is_intent_doc(tic._fm(type="epic-bundle"), MARKERS))
        self.assertFalse(io_.is_intent_doc(tic._fm(type="design"), MARKERS))
        self.assertFalse(io_.is_intent_doc("# 제목\nroadmap: x\n", MARKERS))
        self.assertTrue(io_.is_intent_doc(tic._fm(type="seed"), MARKERS + ["type=seed"]))

    def test_unreadable_or_odd_frontmatter(self):
        """YAML 이 예외를 내는 머리(없는 날짜 · 틀린 수 · 틀린 태그)는 「머리 없음」, 스칼라가 아닌 값은 None —
        별칭을 글로 펼치지 않는다."""
        for bad in ("created_at: 2026-02-30", "x: 0x_", "y: !!float x", "z: [", "w: !!python/name:os.system"):
            text = "---\n%s\nroadmap: docs/rm/x/roadmap.md\n---\n# 본문\n" % bad
            with self.subTest(bad=bad):
                self.assertIsNone(io_.frontmatter_value(text, "roadmap"))
                self.assertFalse(io_.is_intent_doc(text, MARKERS))
                self.assertTrue(io_.frontmatter_unreadable(text))
        bomb, prev = "a: &a [x, x]\n", "a"
        for key in "bcdefg":  # 층마다 9배 — 글로 펼치면 수 MB
            bomb += "%s: &%s [%s]\n" % (key, key, ", ".join(["*" + prev] * 9))
            prev = key
        for value in ("[a, b]", "{k: v}", "*g"):
            text = "---\n%sroadmap: %s\n---\n" % (bomb, value)
            with self.subTest(value=value):
                # assertIsNone 은 실패 때 값을 찍는다 — 펼친 글(수 MB)이 출력을 덮지 않게 참거짓으로 본다.
                self.assertTrue(io_.frontmatter_value(text, "roadmap") is None, value)
                self.assertFalse(io_.frontmatter_unreadable(text))
        good = "---\ncreated_at: 2026-02-01\nroadmap: docs/rm/x/roadmap.md\n---\n"
        self.assertEqual(io_.frontmatter_value(good, "created_at"), "2026-02-01")
        self.assertEqual(io_.frontmatter_value(good, "roadmap"), "docs/rm/x/roadmap.md")
        self.assertFalse(io_.frontmatter_unreadable(good))
        self.assertFalse(io_.frontmatter_unreadable("# 머리 없음\n"))


DOCS = {"docs/specs/a-design.md": tic._fm(source_interview="docs/R1.md"),
        "docs/guide.md": "# 안내\n", "CHANGELOG.md": "# 변경\n",
        "docs/rm/x/roadmap.md": tic._fm(type="roadmap")}


class TestBreadth(unittest.TestCase):
    def _b(self, mode, names):
        return io_.review_breadth(mode, names, DOCS.get, MARKERS)

    def test_table(self):
        design = "docs/specs/a-design.md"
        cases = [("pr", {"src/a.py", design}, "narrow"),
                 ("pr", {design, "CHANGELOG.md"}, "intent-docs"),
                 ("pr", {"docs/rm/x/roadmap.md"}, "intent-docs"),
                 ("pr", {"docs/guide.md", "CHANGELOG.md"}, "narrow"),
                 ("pr", {design, "skills/x/SKILL.md"}, "narrow"),
                 ("pr", {design, "docs/page.mdx"}, "narrow"),
                 ("pr", None, "narrow"),
                 ("range", {"src/a.py"}, "range"),
                 ("range", None, "narrow")]
        for mode, names, want in cases:
            with self.subTest(mode=mode, names=names):
                self.assertEqual(self._b(mode, names)[0], want)

    def test_range_lists_changed_intent_docs(self):
        design = "docs/specs/a-design.md"
        self.assertEqual(self._b("range", {"src/a.py", design}), ("range", [], 0))
        self.assertEqual(self._b("range", {design, "CHANGELOG.md"}), ("range", [design], 0))
        self.assertEqual(self._b("range", {"docs/guide.md", "src/a.py"}), ("range", [], 0))
        self.assertEqual(self._b("range", {"skills/x/SKILL.md"}), ("range", [], 0))   # 모델이 읽는 파일은 읽지 않는다
        self.assertEqual(self._b("range", None), ("narrow", [], 0))

    def test_untracked_doc_counted(self):
        design = "docs/specs/a-design.md"
        self.assertEqual(self._b("pr", {design, "docs/new-design.md"}),
                         ("intent-docs", [design], 1))
        self.assertEqual(self._b("pr", {"docs/new-design.md"}), ("narrow", [], 1))
        self.assertEqual(self._b("pr", {"src/a.py", "docs/new-design.md"}), ("narrow", [], 0))


class TestReadTree(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = os.path.join(self.tmp.name, "repo")
        os.makedirs(self.repo)
        tic._git_repo(self.repo)
        tic._write("c\n", self.repo, "sub", "c.txt")
        os.symlink("a.txt", os.path.join(self.repo, "l.txt"))
        os.symlink(".", os.path.join(self.repo, "ld"))
        self._ok("add", "sub/c.txt", "l.txt", "ld")
        self._ok("commit", "-q", "-m", "links")
        tic._write("s\n", self.repo, "staged.md")
        self._ok("add", "staged.md")
        tic._write("n\n", self.repo, "new.txt")

    def tearDown(self):
        self.tmp.cleanup()

    def _ok(self, *args, repo=None):
        p = tic._git(repo or self.repo, *args)
        self.assertEqual(p.returncode, 0, p.stderr)
        return p

    def _magic_repo(self):
        repo = os.path.join(self.tmp.name, "magic")
        os.makedirs(repo)
        tic._git_repo(repo)
        tic._write("star\n", repo, "docs", "*.md")
        tic._write("b\n", repo, "docs", "b.md")
        tic._write("m\n", repo, ":(top)x.md")
        self._ok("add", "--", ":(literal)docs/*.md", ":(literal)docs/b.md",
                 ":(literal):(top)x.md", repo=repo)
        self._ok("commit", "-q", "-m", "magic", repo=repo)
        return repo

    def test_reads_tracked_and_staged(self):
        self.assertEqual(io_.read_tree(self.repo, "a.txt"), ("x\n", None))
        self.assertEqual(io_.read_tree(self.repo, "staged.md"), ("s\n", None))
        self.assertEqual(io_.read_tree(self.repo, "sub/c.txt"), ("c\n", None))

    def test_reads_working_copy(self):
        tic._write("y\n", self.repo, "a.txt")
        self.assertEqual(io_.read_tree(self.repo, "a.txt"), ("y\n", None))

    def test_glob_and_magic_names_are_literal(self):
        repo = self._magic_repo()
        self.assertEqual(io_.read_tree(repo, "docs/*.md"), ("star\n", None))
        self.assertEqual(io_.read_tree(repo, ":(top)x.md"), ("m\n", None))
        self._ok("rm", "-q", "--", ":(literal)docs/*.md", repo=repo)
        self.assertIsNone(io_.read_tree(repo, "docs/*.md")[0])
        # 지운 것은 그 한 파일뿐이다 — 같은 폴더의 다른 문서는 그대로 읽힌다
        self.assertEqual(io_.read_tree(repo, "docs/b.md"), ("b\n", None))

    def test_read_tracked_magic_names_are_literal(self):
        repo = self._magic_repo()
        self.assertEqual(io_.read_tracked(repo, "HEAD", ":(top)x.md"), ("m\n", None))
        self.assertEqual(io_.read_tracked(repo, "HEAD", "docs/*.md"), ("star\n", None))
        self.assertEqual(io_.read_tracked(repo, "HEAD", ".GIT/config"), (None, ".git 아래"))

    def test_rejects(self):
        cases = (("new.txt", io_.REASON_UNTRACKED), ("l.txt", "심볼릭 링크"),
                 ("../a.txt", "상위 경로(..)"), ("/etc/hosts", "절대 경로"),
                 (".git/config", ".git 아래"), (".GIT/config", ".git 아래"),
                 ("sub/.Git/x", ".git 아래"), ("a\n.txt", io_.REASON_CONTROL),
                 ("sub", "보통 파일이 아님"), ("", io_.REASON_UNTRACKED))
        for rel, why in cases:
            with self.subTest(rel=rel):
                self.assertEqual(io_.read_tree(self.repo, rel), (None, why))
        self.assertIsNone(io_.read_tree(self.repo, "ld/a.txt")[0])

    def test_working_copy_links_rejected(self):
        """색인은 보통 파일인데 작업 사본의 마디가 링크로 바뀌었다 — 트리 밖을 읽지 않는다."""
        outside = os.path.join(self.tmp.name, "outside")
        tic._write("secret\n", outside, "c.txt")
        tic._write("secret\n", outside, "a.txt")
        os.remove(os.path.join(self.repo, "sub", "c.txt"))
        os.rmdir(os.path.join(self.repo, "sub"))
        os.symlink(outside, os.path.join(self.repo, "sub"))
        os.remove(os.path.join(self.repo, "a.txt"))
        os.symlink(os.path.join(outside, "a.txt"), os.path.join(self.repo, "a.txt"))
        self.assertEqual(io_.read_tree(self.repo, "sub/c.txt"), (None, "심볼릭 링크"))
        self.assertEqual(io_.read_tree(self.repo, "a.txt"), (None, "심볼릭 링크"))

    def test_folder_replaced_by_untracked_file(self):
        """색인에는 폴더(sub/c.txt)인데 작업 사본의 sub 가 추적 안 된 보통 파일이다 — 읽지 않는다."""
        os.remove(os.path.join(self.repo, "sub", "c.txt"))
        os.rmdir(os.path.join(self.repo, "sub"))
        tic._write("untracked\n", self.repo, "sub")
        self.assertEqual(io_.read_tree(self.repo, "sub"), (None, "보통 파일이 아님"))

    def test_deleted_or_not_git(self):
        os.remove(os.path.join(self.repo, "a.txt"))
        self.assertEqual(io_.read_tree(self.repo, "a.txt"), (None, io_.REASON_UNTRACKED))
        plain = os.path.join(self.tmp.name, "plain")
        tic._write("x\n", plain, "a.txt")
        self.assertIsNone(io_.read_tree(plain, "a.txt")[0])
        self.assertIsNone(io_.read_tree(os.path.join(self.tmp.name, "none"), "a.txt")[0])


class TestWideConfig(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = tic._git_repo(self.tmp.name)
        tic._git(self.repo, "config", "core.excludesFile", os.devnull)
        self.rd = tempfile.mkdtemp(dir=self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def _config(self, env=None):
        p = tic._cli("config", "--rd", self.rd, "--repo", self.repo, "--base", "HEAD",
                     "--project-dir", self.repo, env=env)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(tic._read(self.rd, "intent-config.txt").strip(), p.stdout.strip())
        out = {}
        for line in p.stdout.splitlines():
            key, _, value = line.partition(": ")
            out[key] = value
        return out

    def test_defaults(self):
        c = self._config()
        self.assertEqual(c["other_teams_max_bytes"], "80000")
        self.assertEqual(c["intent_doc_markers"],
                         "source_intent,source_interview,roadmap,source_brief,type=roadmap,type=epic-bundle")
        self.assertEqual(c["other_teams_max_bytes_source"], "default")
        self.assertEqual(c["intent_doc_markers_source"], "default")

    def test_env(self):
        c = self._config(tic._env(**{OTHER_MAX: "5000", ENV_MARKERS: "roadmap,type=seed"}))
        self.assertEqual((c["other_teams_max_bytes"], c["other_teams_max_bytes_source"]),
                         ("5000", "env"))
        self.assertEqual((c["intent_doc_markers"], c["intent_doc_markers_source"]),
                         ("roadmap,type=seed", "env"))

    def test_invalid(self):
        c = self._config(tic._env(**{OTHER_MAX: "0", ENV_MARKERS: "type="}))
        self.assertEqual((c["other_teams_max_bytes"], c["other_teams_max_bytes_source"]),
                         ("80000", "default-invalid"))
        self.assertEqual((c["intent_doc_markers"], c["intent_doc_markers_source"]),
                         (",".join(MARKERS), "default-invalid"))

    def test_settings_changed(self):
        env = tic._env(**{OTHER_MAX: "5000", ENV_MARKERS: "roadmap"})
        tic._write('{"env": {"%s": "roadmap"}}' % ENV_MARKERS, self.repo, ".claude",
                   "settings.json")
        c = self._config(env)
        self.assertEqual((c["intent_doc_markers"], c["intent_doc_markers_source"]),
                         (",".join(MARKERS), "default-settings-changed"))
        self.assertEqual((c["other_teams_max_bytes"], c["other_teams_max_bytes_source"]),
                         ("5000", "env"))

    def test_read_config_optional_and_strict(self):
        path = os.path.join(self.rd, "intent-config.txt")
        old = tic._config_text()
        tic._write(old, path)
        cfg = ic._read_config(self.rd)
        self.assertEqual((cfg["other_teams_max_bytes"], cfg["intent_doc_markers"]),
                         (80000, MARKERS))
        tic._write(old + "intent_doc_markers: roadmap,type=seed\n", path)
        cfg = ic._read_config(self.rd)
        self.assertEqual((cfg["other_teams_max_bytes"], cfg["intent_doc_markers"]),
                         (80000, ["roadmap", "type=seed"]))
        tic._write(old + "other_teams_max_bytes: 700\n", path)
        self.assertEqual(ic._read_config(self.rd)["other_teams_max_bytes"], 700)
        for bad in ("other_teams_max_bytes: x\n", "other_teams_max_bytes: 0\n",
                    "intent_doc_markers: type=\n",
                    "intent_doc_markers: roadmap\nintent_doc_markers: roadmap\n"):
            with self.subTest(bad=bad):
                tic._write(old + bad, path)
                self.assertIsNone(ic._read_config(self.rd))


class TestWidePrepare(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.R = _wide_repo(os.path.join(self.tmp.name, "repo"))
        self.rd = self._new_rd()

    def tearDown(self):
        self.tmp.cleanup()

    def _new_rd(self, config=None):
        rd = tempfile.mkdtemp(dir=self.tmp.name)
        tic._write(config or tic._config_text(), rd, "intent-config.txt")
        tic._write("## Goals\ngoal-body\n", rd, "intent.md")
        return rd

    def _prep(self, mode="pr", names=("src/a.py",), base=None, rd=None, origin=None):
        rd = rd or self.rd
        if names is not None:
            tic._write("".join(n + "\n" for n in names), rd, "review-i1.names")
        sp = os.path.join(rd, "intent-specs.json")
        tic._write(json.dumps({"intent_source": "spec-trailer", "specs": []}), sp)
        args = ["prepare", "--rd", rd, "--repo", self.R, "--tree-root", self.R, "--mode", mode,
                "--head", "HEAD", "--review-commit", "HEAD", "--specs-json", sp]
        if base is not None:
            args.append("--base=" + base)
        if origin is not None:
            args.append("--origin=" + origin)
        p = tic._cli(*args)
        self.assertEqual(p.returncode, 0, p.stderr)
        return p

    def _f(self, name, rd=None):
        return tic._read(rd or self.rd, name)

    def _plan(self, rd=None):
        return self._f("intent-plan.txt", rd).splitlines()

    def test_range_calls_without_run_evidence(self):
        p = self._prep(mode="range")
        self.assertEqual(tic._last(p), "intent-call: first-only")
        self.assertIn("breadth: range", self._plan())
        self.assertIn("넓게 본다 — 범위 모드", p.stdout.splitlines())

    def _commit_record(self, brief=True):
        # brief=True 픽스처는 AC21 의 일반 동작(바뀐 문서의 source_brief: 를 따라가기 · --origin 과 같은 파일이면
        # 한 번만 싣기)을 잰다. 지휘자의 실제 기록 틀은 source_brief: 없이 roadmap: 만 싣는다(계획 검토 P2) —
        # 그 꼴은 brief=False 와 test_range_roadmap_only_record_with_origin 이 잰다 — 로드맵 끝에서 머리만 커밋한
        # 틀 그대로(없음 표지 셋은 따옴표에 싼 "-" — 따옴표 없는 - 는 YAML 이 머리 전체를 읽지 못한다).
        if brief:
            fm = dict(type="roadmap-review", roadmap="docs/rm/one/roadmap.md", source_brief="docs/brief.md")
        else:
            fm = dict(type="roadmap-review", roadmap="docs/rm/one/roadmap.md", epic='"-"', site="end",
                      reviewed_base='"-"', reviewed_head='"-"', contract="2")
        tic._write(tic._fm(**fm) + "기록\n", self.R, *REC.split("/"))
        _ok(self.R, "add", REC)
        _ok(self.R, "commit", "-q", "-m", "record")

    def test_range_roadmap_only_record_with_origin(self):
        self._commit_record(brief=False)
        p = self._prep(mode="range", names=(REC,), origin="docs/brief.md")
        self.assertIn("breadth: range", self._plan())
        self.assertIn("one-intent-token", self._f("intent-roadmap.md"))
        origin = self._f("intent-origin.md")
        self.assertEqual(origin.count("brief-quote-token"), 1)
        out = p.stdout.splitlines()
        self.assertFalse([l for l in out if l.startswith("로드맵 없음") or l.startswith("원문 없음")])

    def test_range_record_follows_roadmap_and_brief(self):
        self._commit_record()
        p = self._prep(mode="range", names=(REC,))
        self.assertIn("breadth: range", self._plan())
        self.assertIn("one-intent-token", self._f("intent-roadmap.md"))
        self.assertIn("brief-quote-token", self._f("intent-origin.md"))
        out = p.stdout.splitlines()
        self.assertFalse([l for l in out if l.startswith("로드맵 없음") or l.startswith("원문 없음")])

    def test_range_origin_same_file_loaded_once(self):
        self._commit_record()
        self._prep(mode="range", names=(REC,), origin="docs/brief.md")
        origin = self._f("intent-origin.md")
        self.assertEqual(origin.count("brief-quote-token"), 1)
        self.assertEqual(origin.count("<!-- origin-source: docs/brief.md · file: docs/brief.md -->"), 1)

    def test_range_code_only_keeps_today(self):
        p = self._prep(mode="range", names=("src/a.py",))
        self.assertTrue(self._f("intent-roadmap.md").startswith("로드맵 없음 — "))
        self.assertIn("넓게 본다 — 범위 모드", p.stdout.splitlines())

    def test_range_without_names_falls_back(self):
        p = self._prep(mode="range", names=None)
        self.assertEqual(tic._last(p), "intent-call: none")
        self.assertIn("breadth: narrow", self._plan())
        self.assertIn("바뀐 파일 목록이 없어 넓게 보지 않는다", p.stdout.splitlines())

    def test_design_doc_only_calls(self):
        p = self._prep(names=("docs/specs/x-design.md",))
        self.assertEqual(tic._last(p), "intent-call: first-only")
        self.assertIn("breadth: intent-docs", self._plan())
        self.assertIn("넓게 본다 — 의도 문서가 바뀐 변경", p.stdout.splitlines())
        self.assertIn("bundle-quote-token", self._f("intent-origin.md"))
        self.assertIn("one-intent-token", self._f("intent-roadmap.md"))
        # build_origin 이 찾은 로드맵이 다른 팀 읽기에 넘어간다 — 이번 로드맵의 팀 지도가 기록에 실린다.
        self.assertIn("### 이번 로드맵 docs/rm/one/roadmap.md (리뷰 트리)\n", self._f(ot.FILE))

    def test_roadmap_only_change(self):
        self._prep(names=("docs/rm/one/roadmap.md",))
        self.assertIn("one-intent-token", self._f("intent-roadmap.md"))
        self.assertIn("brief-quote-token", self._f("intent-origin.md"))
        self.assertIn("breadth: intent-docs", self._plan())

    def test_bundle_only_change(self):
        self._prep(names=("docs/rm/one/R1.md",))
        self.assertIn("brief-quote-token", self._f("intent-origin.md"))
        self.assertIn("one-intent-token", self._f("intent-roadmap.md"))

    def test_plain_docs_only_is_r1(self):
        p = self._prep(names=("docs/guide.md",))
        self.assertEqual(tic._last(p), "intent-call: none")
        self.assertIn(tic.NONE_LINE, p.stdout.splitlines())
        self.assertIn("breadth: narrow", self._plan())

    def test_code_pr_is_r1(self):
        p = self._prep()
        # 부르지 않는 좁은 실행의 stdout 은 R1 과 글자까지 같다
        self.assertEqual(p.stdout, "%s\nintent-call: none\n" % tic.NONE_LINE)
        self.assertIn("breadth: narrow", self._plan())
        tic._write("관찰 하나\n", self.rd, "e2e-record.md")
        p = self._prep()
        self.assertEqual(tic._last(p), "intent-call: first-only")
        self.assertIn("breadth: narrow", self._plan())
        self.assertNotIn("넓게 본다 — 범위 모드", p.stdout)
        # 다른 브랜치가 있고 다른 팀 기록이 상한을 넘어도 부르지 않는 실행의 stdout 은 R1 그대로 —
        # 상한 줄은 기록의 `## 상한` 에만 있다. 리뷰어를 부르면 상한 줄을 공시한다.
        _other_branch(self.R)
        rd = self._new_rd(tic._config_text() + "other_teams_max_bytes: 10\n")
        p = self._prep(rd=rd)
        self.assertEqual(p.stdout, "%s\nintent-call: none\n" % tic.NONE_LINE)
        cap = [line for line in self._f(ot.FILE, rd).split("\n") if line.startswith("상한 10바이트 — ")]
        self.assertEqual(len(cap), 1, self._f(ot.FILE, rd))
        self.assertNotIn("상한 10바이트", self._f(ic.PREPARE_NOTICES, rd))
        self.assertEqual(ot.summary(self._f(ot.FILE, rd))[0], ["- feature/other — src/a.py"])
        tic._write("관찰 하나\n", rd, "e2e-record.md")
        p = self._prep(rd=rd)
        self.assertEqual(tic._last(p), "intent-call: first-only")
        self.assertIn(cap[0], p.stdout.splitlines())
        self.assertIn(cap[0], self._f(ic.PREPARE_NOTICES, rd).splitlines())

    def test_kill_switch_stops_prepare(self):
        """gate 를 거치지 않고 불려도 스위치가 켜져 있으면 prepare 는 넓이 판정 · 다른 팀 읽기를 하지 않고
        앞 실행의 두 파일을 지우며, gate 가 꺼짐에서 내는 것과 같은 출력 · 돌려주는 꼴을 낸다."""
        _other_branch(self.R)
        kill = tic._env(**{tic.KILL: "1"})
        tic._write("stale\n", self.rd, ot.FILE)
        tic._write("stale\n", self.rd, ic.SCOPE)
        tic._write("src/a.py\n", self.rd, "review-i1.names")
        sp = os.path.join(self.rd, "intent-specs.json")
        tic._write(json.dumps({"intent_source": "spec-trailer", "specs": []}), sp)
        p = tic._cli("prepare", "--rd", self.rd, "--repo", self.R, "--tree-root", self.R,
                     "--mode", "range", "--head", "HEAD", "--review-commit", "HEAD",
                     "--specs-json", sp, env=kill)
        self.assertEqual((p.returncode, p.stdout, p.stderr), (0, ic.KILL_LINE + "\n", ""))
        for name in (ot.FILE, ic.SCOPE, "intent-plan.txt", "intent-evidence.txt"):
            self.assertFalse(os.path.lexists(os.path.join(self.rd, name)), name)
        gate_rd = self._new_rd()
        g = tic._cli("gate", "--rd", gate_rd, "--path", "final", "--mode", "range", env=kill)
        self.assertEqual((g.returncode, g.stdout), (p.returncode, p.stdout))
        # 세션 폴더 경로만 다르다 — 그 밖의 칸은 한 글자도 같다.
        own, other = tic._return_block(self.rd), tic._return_block(gate_rd)
        self.assertEqual(own[0].replace(self.rd, "<rd>"), other[0].replace(gate_rd, "<rd>"))
        self.assertEqual(own[1]["session_dir"], os.path.abspath(self.rd))
        block = tic._return_block(self.rd)[1]
        self.assertEqual((block["status"], block["reason"]), ("skipped", "kill-switch"))

    def test_teams_failure_still_shown_when_not_called(self):
        """부르지 않는 좁은 실행에서도 다른 팀 읽기 실패는 공시한다(상한 줄만 뺀다)."""
        def boom(*_a, **_k):
            raise RuntimeError("x")

        notices = []
        args = argparse.Namespace(rd=self.rd, repo=self.R, tree_root=self.R, review_commit="HEAD",
                                  head="HEAD", origin=None, mode="pr", base="-",
                                  specs_json=os.path.join(self.rd, "intent-specs.json"))
        tic._write(json.dumps({"intent_source": "spec-trailer", "specs": []}), args.specs_json)
        tic._write("src/a.py\n", self.rd, "review-i1.names")
        real = ic._teams
        with mock.patch.object(ic, "_teams", lambda *a: real(*a, collect=boom)):
            call = ic._prepare(args, notices)
        self.assertEqual(call, "none")
        self.assertIn("다른 팀 읽기 실패 — RuntimeError", notices)

    def test_overlap_alone_does_not_call(self):
        _other_branch(self.R)
        p = self._prep()
        self.assertEqual(tic._last(p), "intent-call: none")
        overlap, _unverified = ot.summary(self._f(ot.FILE))
        self.assertEqual(overlap, ["- feature/other — src/a.py"])

    def test_other_teams_rows_in_evidence(self):
        _other_branch(self.R)
        tic._write("관찰 하나\n", self.rd, "e2e-record.md")
        p = self._prep()
        self.assertEqual(tic._last(p), "intent-call: first-only")
        rows = self._f("intent-evidence.txt").split("\n")
        self.assertEqual(rows[0], "   1\t[e2e] 관찰 하나")
        self.assertGreater(len(rows), 5)
        for n, row in enumerate(rows, 1):
            head, _, body = row.partition("\t")
            self.assertEqual(head.strip(), str(n))
            if n > 1:
                self.assertTrue(body.startswith("[다른 팀] "), row)
        self.assertIn("[다른 팀] - feature/other — src/a.py", rows[1] + rows[2])

    def test_other_teams_bytes_do_not_flip_split(self):
        _other_branch(self.R)
        walk = "관찰 하나\n"
        tic._write(walk, self.rd, "e2e-record.md")
        self._prep()
        run_input = io_.total_bytes(io_.build_evidence(walk, None)[0],
                                    *[self._f(n) for n in ("intent-origin.md", "intent-roadmap.md",
                                                           "intent-intent.md", "intent-doubts.md")])
        whole_input = run_input - io_.total_bytes(io_.build_evidence(walk, None)[0]) \
            + io_.total_bytes(self._f("intent-evidence.txt"))
        cap = run_input + 1
        self.assertGreater(whole_input, cap)  # 다른 팀 줄을 세면 넘는다 — 이 시험의 이빨
        tic._write(tic._config_text(max_bytes=cap), self.rd, "intent-config.txt")
        p = self._prep()
        self.assertNotEqual(tic._last(p), "intent-call: single")
        self.assertEqual(tic._last(p), "intent-call: first-only")
        teams = io_.teams_bytes(self._f("intent-evidence.txt"))
        self.assertIn("입력 %d바이트 · 다른 팀 기록 %d바이트(상한 80000 — 나눠 부르기 판정에 넣지 않는다)"
                      % (run_input, teams), p.stdout.splitlines())
        tic._write(tic._config_text(max_bytes=run_input - 1), self.rd, "intent-config.txt")
        self.assertEqual(tic._last(self._prep()), "intent-call: single")

    def _siblings_seen(self, scope_text):
        """topic-scope.txt 를 둔 세션 폴더로 `_prepare` 를 돌려 `collect` 가 받은 siblings 를 돌려준다."""
        seen = []

        def fake(*_a, **kwargs):
            seen.append(kwargs.get("siblings", "없음"))
            return {"text": "", "notices": []}

        if scope_text is not None:
            tic._write(scope_text, self.rd, "topic-scope.txt")
        tic._write("src/a.py\n", self.rd, "review-i1.names")
        sp = os.path.join(self.rd, "intent-specs.json")
        tic._write(json.dumps({"intent_source": "spec-trailer", "specs": []}), sp)
        args = argparse.Namespace(rd=self.rd, repo=self.R, tree_root=self.R, review_commit="HEAD",
                                  head="HEAD", origin=None, mode="pr", base="-", specs_json=sp)
        real = ic._teams
        with mock.patch.object(ic, "_teams", lambda *a: real(*a, collect=fake)):
            ic._prepare(args, [])
        self.assertEqual(len(seen), 1)
        return seen[0]

    def test_topic_scope_members_excluded(self):
        got = self._siblings_seen("topic_key: k\nstatus: ok\nreason: -\nbranches: feature/x,feature/y\n")
        self.assertEqual(got, {"feature/x", "feature/y"})
        for text in ("status: merge-failed\nbranches: feature/x,feature/y\n",
                     "status: declaration-invalid\nbranches: feature/x,feature/y\n"):
            with self.subTest(text=text):
                self.tearDown()
                self.setUp()
                self.assertIsNone(self._siblings_seen(text))

    def test_topic_scope_without_members_excludes_nothing(self):
        for text in ("status: ok\nbranches: -\n", "status: ok\nreason: -\n", None):
            with self.subTest(text=text):
                self.tearDown()
                self.setUp()
                self.assertIsNone(self._siblings_seen(text))

    def test_topic_scope_member_pieces(self):
        tic._write("status: ok\nbranches:  feature/x, ,feature/y ,\n", self.rd, "topic-scope.txt")
        self.assertEqual(ic._topic_siblings(self.rd), {"feature/x", "feature/y"})

    def test_teams_bytes_match_evidence(self):
        _other_branch(self.R)
        tic._write("관찰 하나\n", self.rd, "e2e-record.md")
        p = self._prep()
        rows = [r for r in self._f("intent-evidence.txt").split("\n")
                if r.partition("\t")[2].startswith("[다른 팀] ")]
        self.assertTrue(rows)
        want = len("\n".join(rows).encode("utf-8"))
        self.assertEqual(io_.teams_bytes(self._f("intent-evidence.txt")), want)
        shown = [line for line in p.stdout.splitlines() if "다른 팀 기록 " in line]
        self.assertEqual(len(shown), 1)
        self.assertIn("다른 팀 기록 %d바이트(" % want, shown[0])
        self.assertNotEqual(want, io_.total_bytes(self._f(ot.FILE)))

    def test_scope_file(self):
        first = _ok(self.R, "rev-parse", "HEAD~1")
        self._prep(mode="range", base=first)
        lines = self._f("intent-scope.md").split("\n")
        self.assertEqual(lines[:2], ["넓이: 넓게 본다 — 범위 모드", "읽은 인용: 받는다"])
        self.assertEqual(lines[lines.index("## 바뀐 파일") + 1], "- src/a.py")
        self.assertEqual(lines[lines.index("## 커밋 제목") + 1], "- wide fixture")
        narrow = self._new_rd()
        self._prep(rd=narrow)
        lines = self._f("intent-scope.md", narrow).split("\n")
        self.assertEqual(lines[:2], ["넓이: 좁게 본다 — 코드가 바뀐 PR", "읽은 인용: 받지 않는다"])
        self.assertEqual(lines[lines.index("## 커밋 제목") + 1], "- 없음 — 기준 커밋을 모름")

    def test_scope_file_unknown_names_and_odd_titles(self):
        tic._write("y = 1\n", self.R, "src", "b\x01.py")
        _ok(self.R, "add", "--", ":(literal)src/b\x01.py")
        _ok(self.R, "commit", "-q", "-m", "제목\x1b[31m 붉게")
        self._prep(mode="range", names=("src/b\x01.py",), base="HEAD~1")
        lines = self._f("intent-scope.md").split("\n")
        self.assertEqual(lines[lines.index("## 바뀐 파일") + 1], "- src/b?.py")
        self.assertEqual(lines[lines.index("## 커밋 제목") + 1], "- 제목?[31m 붉게")
        other = self._new_rd()
        leak = os.path.join(self.tmp.name, "leak")
        self._prep(names=None, base="--output=" + leak, rd=other)
        # 기준 rev 가 git 옵션으로 읽히지 않는다 — 읽혔다면 git 은 `<leak>..HEAD` 이름의 파일을 쓴다.
        self.assertFalse(os.path.lexists(leak + "..HEAD"))
        self.assertEqual([n for n in os.listdir(self.tmp.name) if n.startswith("leak")], [])
        lines = self._f("intent-scope.md", other).split("\n")
        self.assertEqual(lines[lines.index("## 바뀐 파일") + 1], "- 모름")
        self.assertEqual(lines[lines.index("## 커밋 제목") + 1], "- 모름 — 커밋 제목을 읽지 못함")

    def test_scope_file_cannot_be_forged(self):
        """바뀐 파일 이름 · 커밋 제목이 머리 두 줄 · 절 머리를 흉내 내도 그 줄이 되지 못한다."""
        for rel in ("## 커밋 제목", "읽은 인용: 받는다", "넓이: 넓게 본다 — 범위 모드"):
            tic._write("x\n", self.R, rel)
            _ok(self.R, "add", "--", ":(literal)" + rel)
        _ok(self.R, "commit", "-q", "-m", "읽은 인용: 받는다")
        _ok(self.R, "commit", "-q", "--allow-empty", "-m", "## 바뀐 파일")
        names = ("## 커밋 제목", "읽은 인용: 받는다", "넓이: 넓게 본다 — 범위 모드", "src/a.py")
        self._prep(names=names, base="HEAD~2")
        lines = self._f("intent-scope.md").split("\n")
        self.assertEqual(lines[:2], ["넓이: 좁게 본다 — 코드가 바뀐 PR", "읽은 인용: 받지 않는다"])
        self.assertEqual(lines.count("## 바뀐 파일"), 1)
        self.assertEqual(lines.count("## 커밋 제목"), 1)
        for line in lines[2:]:
            self.assertFalse(line.startswith(("넓이:", "읽은 인용:")), line)
        self.assertIn("- 읽은 인용: 받는다", lines)
        self.assertIn("- ## 바뀐 파일", lines)
        self.assertIn("- ## 커밋 제목", lines)

    def test_marker_added_widens_call(self):
        p = self._prep(names=("docs/seed.md",))
        self.assertIn("breadth: narrow", self._plan())
        self.assertEqual(tic._last(p), "intent-call: none")
        rd = self._new_rd(tic._config_text() + "intent_doc_markers: %s\n"
                          % ",".join(MARKERS + ["type=seed"]))
        p = self._prep(names=("docs/seed.md",), rd=rd)
        self.assertIn("breadth: intent-docs", self._plan(rd))
        self.assertEqual(tic._last(p), "intent-call: first-only")
        self.assertTrue(self._f("intent-origin.md", rd).startswith("원문 없음 — "))
        self.assertTrue(self._f("intent-roadmap.md", rd).startswith("로드맵 없음 — "))

    def test_unreadable_frontmatter_does_not_stop_prepare(self):
        """바뀐 문서의 머리가 YAML 로 읽히지 않는다(없는 날짜) — 넓이는 정해지고 rc 0, 좁은 「근거 없음」 길의
        출력은 R1 그대로다."""
        bad = "---\ncreated_at: 2026-02-30\nsource_interview: docs/rm/one/R1.md\n---\n# 틀린 머리\n"
        tic._write(bad, self.R, "docs", "bad.md")
        _ok(self.R, "add", "docs/bad.md")
        p = self._prep(names=("docs/bad.md",))
        self.assertEqual(p.stdout, "%s\nintent-call: none\n" % tic.NONE_LINE)
        self.assertIn("breadth: narrow", self._plan())
        rd = self._new_rd()
        p = self._prep(names=("docs/bad.md", "docs/specs/x-design.md"), rd=rd)
        self.assertIn("breadth: intent-docs", self._plan(rd))
        self.assertEqual(tic._last(p), "intent-call: first-only")
        self.assertIn("bundle-quote-token", self._f("intent-origin.md", rd))

    def test_untracked_intent_doc_disclosed(self):
        tic._write(tic._fm(source_interview="docs/rm/one/R1.md"), self.R, "docs", "new-design.md")
        p = self._prep(names=("docs/new-design.md",))
        self.assertIn("breadth: narrow", self._plan())
        self.assertIn(UNREAD_ONE, p.stdout.splitlines())

    def test_deleted_doc_is_not_unread(self):
        os.remove(os.path.join(self.R, "docs", "guide.md"))
        p = self._prep(names=("docs/guide.md", "docs/specs/x-design.md"))
        self.assertIn("breadth: intent-docs", self._plan())
        self.assertNotIn(UNREAD_ONE, p.stdout.splitlines())
        _ok(self.R, "rm", "-q", "--cached", "docs/guide.md")
        rd = self._new_rd()
        p = self._prep(names=("docs/guide.md",), rd=rd)
        self.assertIn("breadth: narrow", self._plan(rd))
        self.assertNotIn("확인 못 한 문서", p.stdout)

    def test_uncommitted_design_read_from_tree(self):
        tic._write(tic._fm(source_interview="docs/brief.md"), self.R, "docs", "specs",
                   "x-design.md")
        self._prep(names=("docs/specs/x-design.md",))
        origin = self._f("intent-origin.md")
        self.assertIn("brief-quote-token", origin)
        self.assertNotIn("bundle-quote-token", origin)

    def test_teams_failure_is_fail_open(self):
        def boom(*_a, **_k):
            raise RuntimeError("x")

        args = argparse.Namespace(repo=self.R, tree_root=self.R, review_commit="HEAD")
        cfg = {"intent_doc_markers": MARKERS, "other_teams_max_bytes": 80000}
        self.assertEqual(ic._teams(args, None, [], cfg, collect=boom),
                         ("", ["다른 팀 읽기 실패 — RuntimeError"]))
        seen = []

        def fake(*a, **k):
            seen.append((a, k))
            return {"text": "## 겹치는 곳\n- 겹침 없음\n", "notices": ["n1"]}

        self.assertEqual(ic._teams(args, {"src/a.py"}, ["docs/rm/one/roadmap.md"], cfg,
                                   collect=fake),
                         ("## 겹치는 곳\n- 겹침 없음\n", ["n1"]))
        self.assertEqual(seen, [((self.R, os.path.abspath(self.R), "HEAD", {"src/a.py"},
                                  ["docs/rm/one/roadmap.md"], MARKERS, 80000), {"siblings": None})])

    def test_differential_shape_disclosed(self):
        tic._write("per_adapter: x\n", self.rd, "differential.yaml")
        p = self._prep()
        self.assertEqual(tic._last(p), "intent-call: none")
        self.assertIn(DIFF_SHAPE, p.stdout.splitlines())
        tic._write("per_adapter: []\n", self.rd, "differential.yaml")
        p = self._prep()
        self.assertNotIn(DIFF_SHAPE, p.stdout.splitlines())


TIMEOUT_NOTE = "git 읽기가 시간 한도 30초를 넘김"


class TestOriginTimeout(unittest.TestCase):
    """시간 한도 — 원문 읽기와 넓이 판정(AC16)."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.R = _wide_repo(os.path.join(self.tmp.name, "repo"))
        self.timeouts = []
        real = io_.subprocess.run

        def fake(cmd, *a, **k):
            self.timeouts.append(k.get("timeout"))
            if "show" in cmd or "ls-files" in cmd:
                raise io_.subprocess.TimeoutExpired(cmd, k.get("timeout"))
            return real(cmd, *a, **k)

        self.patch = mock.patch.object(io_.subprocess, "run", fake)
        self.patch.start()

    def tearDown(self):
        self.patch.stop()
        self.tmp.cleanup()

    def test_origin_timeout_is_not_untracked(self):
        design = "docs/specs/x-design.md"
        built = io_.build_origin(self.R, "HEAD", "HEAD", None, [design])
        self.assertIn("%s 를 읽지 못함 — %s" % (design, TIMEOUT_NOTE), built["notices"])
        for line in built["notices"]:
            self.assertNotIn("추적 안 된", line)
            if "시간 한도" in line:
                self.assertNotIn("원문 링크 거부", line)
        self.assertIn(30, self.timeouts)
        self.assertEqual(set(self.timeouts), {30})

    def test_breadth_timeout_disclosed_apart_from_untracked(self):
        rd = tempfile.mkdtemp(dir=self.tmp.name)
        tic._write("docs/specs/x-design.md\n", rd, "review-i1.names")
        # 자식 프로세스는 대역을 받지 않는다 — 같은 프로세스에서 _breadth 를 부른다.
        a = argparse.Namespace(rd=rd, mode="pr")
        notices = []
        names, breadth, docs = ic._breadth(a, self.R, {"intent_doc_markers": MARKERS}, notices)
        self.assertEqual(breadth, "narrow")
        self.assertIn("의도 문서인지 확인 못 한 문서 1 — " + TIMEOUT_NOTE, notices)
        self.assertNotIn(UNREAD_ONE, notices)


class TestHeadValues(unittest.TestCase):
    def test_unstringable_frontmatter_is_unreadable(self):
        class Bad(int):
            def __str__(self):
                raise ValueError("Exceeds the limit for integer string conversion")

            __repr__ = __str__

        text = "---\nroadmap: x\n---\n# 본문\n"
        with mock.patch.object(io_.yaml, "safe_load", lambda _t: {"roadmap": Bad(3), "a": "b"}):
            self.assertTrue(io_.frontmatter_unreadable(text))
            self.assertIsNone(io_.frontmatter_value(text, "roadmap"))
            self.assertFalse(io_.is_intent_doc(text, MARKERS))
        if hasattr(sys, "set_int_max_str_digits"):
            big = "---\nroadmap: 0x%s\n---\n" % ("f" * 5000)
            self.assertTrue(io_.frontmatter_unreadable(big))
            self.assertIsNone(io_.frontmatter_value(big, "roadmap"))
            self.assertFalse(io_.is_intent_doc(big, MARKERS))

    def test_differential_odd_yaml_unreadable(self):
        self.assertEqual(io_.has_evidence(None, "a: 2026-02-30\n"),
                         (False, ["차등 결과를 읽지 못함 — 근거로 세지 않았다"]))


class TestHeadKeyPrecedence(unittest.TestCase):
    """바뀐 의도 문서의 머리 키 — 새 키에 값이 있으면 새 키만, 키가 없거나 값이 없으면 옛 키(세 길이 같은 문서를 고른다 — 따옴표만 빈 값은 값이다)."""

    def _origin(self, head):
        with tempfile.TemporaryDirectory() as d:
            tic._git_repo(d)
            tic._write(head, d, "docs", "changed.md")
            tic._write("## 6. 사용자 원문\nnew-token\n", d, "docs", "new.md")
            tic._write("## 6. 사용자 원문\nold-token\n", d, "docs", "old.md")
            _ok(d, "add", "docs")
            _ok(d, "commit", "-q", "-m", "heads")
            return io_.build_origin(d, "HEAD", "HEAD", None, [], changed_docs=["docs/changed.md"])["origin"]

    def test_both_keys_follow_only_new(self):
        o = self._origin(tic._fm(source_intent="docs/new.md", source_interview="docs/old.md"))
        self.assertIn("new-token", o)
        self.assertNotIn("old-token", o)

    def test_valueless_new_key_follows_old(self):
        o = self._origin(tic._fm(source_intent="", source_interview="docs/old.md"))
        self.assertIn("old-token", o)
        self.assertNotIn("new-token", o)

    def test_quoted_empty_new_key_does_not_fall_back(self):
        o = self._origin(tic._fm(source_intent='""', source_interview="docs/old.md"))
        self.assertNotIn("old-token", o)

    def test_only_old_key_follows_old(self):
        o = self._origin(tic._fm(source_interview="docs/old.md"))
        self.assertIn("old-token", o)


class TestAnswerOddValues(unittest.TestCase):
    def test_answer_file_odd_values_unreadable(self):
        with tempfile.TemporaryDirectory() as rd:
            root = tic._filter_rd(rd, answers=[(tic.ID1, "의도다", tic.OBS1)])
            good = sorted(os.listdir(root))
            self.assertEqual(len(good), 1)
            with open(os.path.join(root, good[0]), encoding="utf-8") as fh:
                text = fh.read()
            bad = text.replace("answered_at: ", "answered_at: 2026-02-30\nold_at: ", 1)
            self.assertNotEqual(bad, text)
            answered, unreadable = ia.read_answered(root)
            self.assertEqual((len(answered), unreadable), (1, 0))
            self.assertIsNone(ia.parse_answer_file(bad))
            with open(os.path.join(root, tic._wf(7)), "w", encoding="utf-8") as fh:
                fh.write(bad)
            answered, unreadable = ia.read_answered(root)
            self.assertEqual((len(answered), unreadable), (1, 1))
            tic._write(tic._out([tic._q("D1", lines=[1], same_as=tic.ID1)]), rd,
                       "intent-critic-1.txt")
            p = tic._cli("filter", "--rd", rd)
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertIn("읽지 못한 답 파일 1", p.stdout.splitlines())
            self.assertEqual(tic._by_state(rd, "answered-filtered")[0]["target_id"], "D1")

    def test_answer_file_odd_values_unreadable_in_prepare(self):
        """같은 이상한 값의 답 파일을 `prepare` 도 읽지 못한 것으로 세고, 보통 답은 그대로 읽는다."""
        with tempfile.TemporaryDirectory() as rd:
            root = tic._filter_rd(rd, answers=[(tic.ID1, "의도다", tic.OBS1)])
            name = os.listdir(root)[0]
            with open(os.path.join(root, name), encoding="utf-8") as fh:
                text = fh.read()
            bad = text.replace("answered_at: ", "answered_at: 2026-02-30\nold_at: ", 1)
            self.assertNotEqual(bad, text)
            with open(os.path.join(root, tic._wf(7)), "w", encoding="utf-8") as fh:
                fh.write(bad)
            tic._write("관찰\n", rd, "e2e-record.md")
            tic._write("## Goals\ngoal-body\n", rd, "intent.md")
            sp = os.path.join(rd, "intent-specs.json")
            tic._write(json.dumps({"intent_source": "spec-trailer", "specs": []}), sp)
            tree = os.path.join(rd, "tree")
            p = tic._cli("prepare", "--rd", rd, "--repo", tree, "--tree-root", tree, "--mode", "pr",
                         "--head", "HEAD", "--review-commit", "HEAD", "--specs-json", sp)
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertIn("읽지 못한 답 파일 1", p.stdout.splitlines())
            self.assertIn(tic.ID1, tic._read(rd, "intent-answered.md"))


class TestDifferentialShape(unittest.TestCase):
    def test_cases(self):
        bad = ("per_adapter: x\n", "runner: x\n", "per_adapter:\n  - 3\n",
               "per_adapter:\n  - runner: a\n", "per_adapter:\n  - attributions: x\n",
               "per_adapter:\n  - attributions:\n      - x\n", "# 주석만\n")
        for text in bad:
            with self.subTest(text=text):
                self.assertEqual(io_.has_evidence(None, text), (False, [DIFF_SHAPE]))
        for text in ("per_adapter: []\n", tic.DIFF_GREEN, "", None):
            with self.subTest(text=text):
                self.assertEqual(io_.has_evidence(None, text), (False, []))
        # 꼴이 다른 항목이 있어도 통과로 끝나지 않은 판정은 그대로 부르는 근거다
        mixed = tic.DIFF_RED + "  - 3\n"
        self.assertEqual(io_.has_evidence(None, mixed), (True, [DIFF_SHAPE]))
        self.assertEqual(io_.has_evidence(None, "- a\n"),
                         (False, ["차등 결과를 읽지 못함 — 근거로 세지 않았다"]))

    def test_build_evidence_with_other_teams(self):
        text, n = io_.build_evidence(None, None, "## 겹치는 곳\n\n- a — b\n")
        self.assertEqual((text, n), ("   1\t[다른 팀] ## 겹치는 곳\n   2\t[다른 팀] - a — b", 2))
        text, n = io_.build_evidence("관찰\n", tic.DIFF_GREEN, "x\ry\n")
        self.assertEqual(text.split("\n")[0], "   1\t[e2e] 관찰")
        self.assertEqual(text.split("\n")[-2:], ["%4d\t[다른 팀] x" % (n - 1),
                                                 "%4d\t[다른 팀] y" % n])
        self.assertEqual(io_.MARK_TEAMS, "[다른 팀] ")


def _sides_repo(root):
    """커밋 A(old) 뒤 HEAD(new) — 묶음 · 로드맵 · brief 의 본문이 바뀐다. → (리포, A)."""
    repo = _wide_repo(root)
    bodies = {"docs/rm/one/R1.md": ("bundle-quote-token", "%s-bundle"),
              "docs/rm/one/roadmap.md": ("one-intent-token", "%s-roadmap"),
              "docs/brief.md": ("brief-quote-token", "%s-brief")}
    for rel, (token, new) in bodies.items():
        tic._write(WIDE_FILES[rel].replace(token, new % "old"), repo, rel)
    _ok(repo, "commit", "-q", "-am", "old")
    a = _ok(repo, "rev-parse", "HEAD")
    for rel, (token, new) in bodies.items():
        tic._write(WIDE_FILES[rel].replace(token, new % "new"), repo, rel)
    _ok(repo, "commit", "-q", "-am", "new")
    return repo, a


class TestReadSides(unittest.TestCase):
    SPEC = "docs/specs/x-design.md"

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.repo, cls.A = _sides_repo(os.path.join(cls.tmp.name, "repo"))

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_review_side_reads_review_commit(self):
        o = io_.build_origin(self.repo, "HEAD", self.A, None, [self.SPEC])
        self.assertIn("old-bundle", o["origin"])
        self.assertNotIn("new-bundle", o["origin"])
        self.assertIn("old-roadmap", o["roadmap"])
        self.assertNotIn("new-roadmap", o["roadmap"])
        self.assertEqual(o["roadmaps"], ["docs/rm/one/roadmap.md"])

    def test_caller_origin_reads_head_commit(self):
        o = io_.build_origin(self.repo, "HEAD", self.A, "docs/brief.md", [])
        self.assertIn("new-brief", o["origin"])
        self.assertNotIn("old-brief", o["origin"])

    def test_tree_root_wins_for_review_side(self):
        tree = os.path.join(self.tmp.name, "tree-a")
        _ok(self.repo, "worktree", "add", "-q", "--detach", tree, self.A)
        try:
            o = io_.build_origin(self.repo, "HEAD", "HEAD", None, [self.SPEC], tree_root=tree)
            self.assertIn("old-bundle", o["origin"])
            self.assertNotIn("new-bundle", o["origin"])
            tic._write(WIDE_FILES["docs/rm/one/R1.md"].replace("bundle-quote-token", "hand-edit"),
                       tree, "docs", "rm", "one", "R1.md")
            o = io_.build_origin(self.repo, "HEAD", "HEAD", None, [self.SPEC], tree_root=tree)
            self.assertIn("hand-edit", o["origin"])
            self.assertIn("old-roadmap", o["roadmap"])
        finally:
            _ok(self.repo, "worktree", "remove", "--force", tree)

    def test_changed_docs_followed(self):
        o = io_.build_origin(self.repo, "HEAD", "HEAD", None, [],
                             changed_docs=["docs/rm/one/roadmap.md"])
        self.assertIn("new-brief", o["origin"])
        self.assertIn("new-roadmap", o["roadmap"])
        self.assertEqual(o["roadmaps"], ["docs/rm/one/roadmap.md"])
        both = io_.build_origin(self.repo, "HEAD", "HEAD", None, [self.SPEC],
                                changed_docs=["docs/rm/one/R1.md"])
        self.assertEqual(both["roadmaps"], ["docs/rm/one/roadmap.md"])
        self.assertIn("new-bundle", both["origin"])

    def test_read_tracked_rev_and_filename_alike(self):
        """작업 폴더에 `<rev>:<경로>` 이름의 파일이 있어도 rev 로만 읽힌다."""
        tic._write("decoy\n", self.repo, "HEAD:a.txt")
        tic._write("decoy\n", self.repo, "%s:a.txt" % self.A)
        try:
            self.assertEqual(io_.read_tracked(self.repo, "HEAD", "a.txt"), ("x\n", None))
            self.assertEqual(io_.read_tracked(self.repo, self.A, "a.txt"), ("x\n", None))
        finally:
            os.remove(os.path.join(self.repo, "HEAD:a.txt"))
            os.remove(os.path.join(self.repo, "%s:a.txt" % self.A))


RQ = {"path": "a.txt", "line": 1, "text": "x"}
# 넓은 넓이 둘 — 거르기 · 렌더의 넓은 갈래는 둘 다로 돈다(한쪽만 넓게 보는 퇴행을 잡게).
WIDE_BREADTHS = ("range", "intent-docs")
QUOTE_GONE = "인용이 그 파일에 없어 거름 1"
COUNT_KEYS = ("evidence", "quote", "read_only", "answered", "over_cap", "unidentified", "broken",
              "absorbed", "cites_dropped")


class _WideRun:
    """거르기 · 렌더 시험이 함께 쓰는 준비 — 리뷰 트리 · 세션 폴더 · filter 한 번."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.rd = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def _tree(self):
        return os.path.join(self.rd, "tree")

    def _prepare(self, wide, **kw):
        """리뷰 트리(a.txt 가 `x\\n` 인 git 리포)와 세션 폴더 — 넓으면 계획 파일 끝에 `breadth: <넓이>`.

        `wide` 는 거짓(좁게) · 참(`range`) · 넓이 글자(`range` · `intent-docs`)."""
        os.makedirs(self._tree(), exist_ok=True)
        tic._git_repo(self._tree())
        tic._filter_rd(self.rd, **kw)
        if wide:
            with open(os.path.join(self.rd, "intent-plan.txt"), "a", encoding="utf-8") as fh:
                fh.write("breadth: %s\n" % (wide if isinstance(wide, str) else "range"))

    def _filter(self, first):
        tic._write(first, self.rd, "intent-critic-1.txt")
        p = tic._cli("filter", "--rd", self.rd)
        self.assertEqual(p.returncode, 0, p.stderr)
        return p

    def _run(self, first, wide, **kw):
        self._prepare(wide, **kw)
        return self._filter(first)

    def _evidence(self, text):
        tic._write(text, self.rd, "intent-evidence.txt")

    def _git_ok(self, repo, *args):
        p = tic._git(repo, *args)
        self.assertEqual(p.returncode, 0, p.stderr)


class TestWideFilter(_WideRun, unittest.TestCase):
    """넓게 보는 리뷰의 거르기 — 읽은 인용 확인 · 근거의 갈래 · 새 종류 · 고르는 순서."""

    def test_read_quote_accepted_in_wide(self):
        for breadth in WIDE_BREADTHS:
            with self.subTest(breadth=breadth), tempfile.TemporaryDirectory() as rd:
                self.rd = rd
                p = self._run(tic._out([tic._q("D1", lines=[], read_quotes=[RQ])]), wide=breadth)
                self.assertEqual(tic._last(p), "intent-ask: 1")
                q = tic._by_state(self.rd, "ask")[0]
                self.assertEqual(q["evidence_kinds"], ["읽어서 봄"])
                self.assertEqual(q["observation"], ["[읽음] a.txt:1 x"])
                self.assertEqual(q["read_quotes"], [RQ])
                self.assertEqual(q["evidence_lines"], [])
                self.assertNotIn("근거로 받지 않은 인용", p.stdout)

    def test_narrow_read_only_filtered(self):
        p = self._run(tic._out([tic._q("D1", lines=[], read_quotes=[RQ])]), wide=False)
        self.assertIn("읽은 인용만 있어 거름 1", p.stdout.splitlines())
        self.assertEqual(tic._last(p), "intent-ask: 0")
        self.assertNotIn("근거 없어 거름", p.stdout)

    def test_new_kinds_have_identity(self):
        self.assertEqual(ia.make_id("diff", "a.txt", "갈라짐"), "diff#a.txt#갈라짐")
        self.assertEqual(ia.make_id("diff", "a.txt", "중복"), "diff#a.txt#중복")
        self.assertEqual(ia.KINDS[-1], "기타")
        self.assertEqual(ia.KINDS[ia.KINDS.index("마찰") + 1:], ("갈라짐", "중복", "기타"))

    def test_read_quote_variants_rejected(self):
        self._prepare(wide=True)
        tree = self._tree()
        os.symlink("a.txt", os.path.join(tree, "l.txt"))
        os.symlink(".", os.path.join(tree, "ld"))
        # 끝 줄바꿈 없는 파일 — 줄 0 · 음수가 파이썬 음의 색인(끝 줄)으로 맞지 않게.
        tic._write("x", tree, "nonl.txt")
        self._git_ok(tree, "add", "l.txt", "ld", "nonl.txt")
        self._git_ok(tree, "commit", "-q", "-m", "links")
        tic._write("x\n", tree, "new.txt")
        # 세션 폴더(rd) 의 파일 — 리뷰 트리 위(`..`) · 절대 경로로, 그리고 pr 모드처럼 트리 안의
        # 무시된 세션 폴더를 상대 경로로.
        tic._write("x\n", self.rd, "a.txt")
        tic._write("x\n", self.rd, "session.txt")
        tic._write(".claude/\n", tree, ".gitignore")
        tic._write("x\n", tree, ".claude", "qg", "s1", "intent-config.txt")
        # 다른 worktree — 트리 밖과 트리 안(`.claude/worktrees/`) 둘 다. 거기서는 a.txt 가 추적된다.
        outside_wt = os.path.join(self.rd, "wt")
        self._git_ok(tree, "worktree", "add", "-q", "-b", "wt-out", outside_wt)
        self._git_ok(tree, "worktree", "add", "-q", "-b", "wt-in",
                     os.path.join(tree, ".claude", "worktrees", "w"))
        self.assertTrue(os.path.isfile(os.path.join(outside_wt, "a.txt")))
        variants = (
            {"path": "a.txt", "line": 2, "text": "x"},
            {"path": "a.txt", "line": 1, "text": "y"},
            {"path": "nope.txt", "line": 1, "text": "x"},
            {"path": "../a.txt", "line": 1, "text": "x"},
            {"path": "/etc/hosts", "line": 1, "text": "x"},
            {"path": os.path.join(tree, "a.txt"), "line": 1, "text": "x"},
            {"path": "l.txt", "line": 1, "text": "x"},
            {"path": "ld/a.txt", "line": 1, "text": "x"},
            {"path": "new.txt", "line": 1, "text": "x"},
            {"path": os.path.join(self.rd, "session.txt"), "line": 1, "text": "x"},
            {"path": ".claude/qg/s1/intent-config.txt", "line": 1, "text": "x"},
            {"path": os.path.join(outside_wt, "a.txt"), "line": 1, "text": "x"},
            {"path": ".claude/worktrees/w/a.txt", "line": 1, "text": "x"},
            {"path": "a.txt", "line": 2, "text": ""},
            {"path": "a.txt", "line": 2, "text": "   "},
            {"path": "a.txt", "line": 0, "text": "x"},
            {"path": "nonl.txt", "line": 0, "text": "x"},
            {"path": "nonl.txt", "line": -1, "text": "x"},
            {"path": "nonl.txt", "line": 2, "text": "x"},
            {"path": "a.txt", "line": "1", "text": "x"},
            {"path": "a.txt", "line": True, "text": "x"},
            {"path": "a.txt", "line": 1.0, "text": "x"},
            {"path": "a.txt", "line": 1},
            {"path": ["a.txt"], "line": 1, "text": "x"},
            {"path": "a.txt", "line": 1, "text": 1},
            "a.txt:1 x",
        )
        for quote in variants:
            with self.subTest(quote=quote):
                p = self._filter(tic._out([tic._q("D1", lines=[], read_quotes=[quote])]))
                self.assertIn(QUOTE_GONE, p.stdout.splitlines())
                self.assertEqual(tic._last(p), "intent-ask: 0")
        # 양성 대조 — 같은 준비에서 맞는 인용은 물음이 된다.
        for good in (RQ, {"path": "nonl.txt", "line": 1, "text": "x"}):
            p = self._filter(tic._out([tic._q("D1", lines=[], read_quotes=[good])]))
            self.assertEqual(tic._last(p), "intent-ask: 1", good)

    def test_whitespace_only_difference_accepted(self):
        self._prepare(wide=True)
        tic._write("  x  \r\n", self._tree(), "w.txt")
        self._git_ok(self._tree(), "add", "w.txt")
        quote = {"path": "w.txt", "line": 1, "text": "x"}
        p = self._filter(tic._out([tic._q("D1", lines=[], read_quotes=[quote])]))
        self.assertEqual(tic._last(p), "intent-ask: 1")
        self.assertEqual(tic._by_state(self.rd, "ask")[0]["observation"], ["[읽음] w.txt:1 x"])

    def test_read_quote_line_stays_one_line(self):
        """확인된 인용 글 가운데의 줄 가름 · 제어 글자는 관찰 줄에서 `?` — 관찰 줄이 둘로 갈라져 답 파일의
        머리 줄을 흉내 내지 못한다. read_quotes 기록은 글자 그대로 남는다."""
        self._prepare(wide=True)
        odd = "a\x85b c\rd\x1be"
        tic._write("%s\n" % odd, self._tree(), "o.txt")
        self._git_ok(self._tree(), "add", "o.txt")
        quote = {"path": "o.txt", "line": 1, "text": odd}
        p = self._filter(tic._out([tic._q("D1", lines=[], read_quotes=[quote])]))
        self.assertEqual(tic._last(p), "intent-ask: 1")
        q = tic._by_state(self.rd, "ask")[0]
        self.assertEqual(q["observation"], ["[읽음] o.txt:1 a?b?c?d?e"])
        for line in q["observation"]:
            self.assertEqual(len(line.splitlines()), 1, line)
            for ch in ("\x85", " ", "\r", "\x1b"):
                self.assertNotIn(ch, line)
        self.assertEqual(q["read_quotes"], [quote])

    def test_narrow_other_team_line_asks(self):
        self._prepare(wide=False)
        self._evidence(io_.build_evidence("관찰\n", None, "## 겹치는 곳\n- b — a.txt\n")[0])
        p = self._filter(tic._out([tic._q("D1", kind="갈라짐", lines=[3])]))
        self.assertEqual(tic._last(p), "intent-ask: 1")
        q = tic._by_state(self.rd, "ask")[0]
        self.assertEqual(q["evidence_kinds"], ["다른 팀에서 봄"])
        self.assertEqual(q["id"], tic.SRC + "#D1#갈라짐")
        self.assertTrue(q["identified"])

    def test_bad_line_with_good_quote_survives(self):
        p = self._run(tic._out([tic._q("D1", lines=[99], read_quotes=[RQ])]), wide=True)
        self.assertEqual(tic._last(p), "intent-ask: 1")
        q = tic._by_state(self.rd, "ask")[0]
        self.assertEqual(q["evidence_kinds"], ["읽어서 봄"])
        self.assertEqual(q["evidence_lines"], [])
        self.assertIn("근거로 받지 않은 인용 1", p.stdout.splitlines())

    def test_partial_quotes_counted(self):
        bad = {"path": "a.txt", "line": 1, "text": "y"}
        p = self._run(tic._out([tic._q("D1", lines=[], read_quotes=[RQ, bad])]), wide=True)
        self.assertEqual(tic._last(p), "intent-ask: 1")
        self.assertIn("근거로 받지 않은 인용 1", p.stdout.splitlines())
        self.assertEqual(tic._by_state(self.rd, "ask")[0]["read_quotes"], [RQ])

    def test_narrow_ignored_quote_counted(self):
        p = self._run(tic._out([tic._q("D1", lines=[1], read_quotes=[RQ])]), wide=False)
        self.assertEqual(tic._last(p), "intent-ask: 1")
        q = tic._by_state(self.rd, "ask")[0]
        self.assertEqual(q["evidence_kinds"], ["돌려서 봄"])
        self.assertEqual(q["read_quotes"], [])
        self.assertEqual(q["observation"], [tic.OBS1])
        self.assertIn("근거로 받지 않은 인용 1", p.stdout.splitlines())

    def test_kinds_combined(self):
        p = self._run(tic._out([tic._q("D1", lines=[1], read_quotes=[RQ])]), wide=True)
        self.assertEqual(tic._last(p), "intent-ask: 1")
        q = tic._by_state(self.rd, "ask")[0]
        self.assertEqual(q["evidence_kinds"], ["돌려서 봄", "읽어서 봄"])
        self.assertEqual(q["observation"], [tic.OBS1, "[읽음] a.txt:1 x"])
        self.assertNotIn("근거로 받지 않은 인용", p.stdout)

    def test_run_evidence_goes_first_within_weight(self):
        cands = [tic._q("D1", lines=[], read_quotes=[RQ]), tic._q("D2", lines=[1]),
                 tic._q("D3", kind="빠진 기능", weight="기능", lines=[1]),
                 tic._q("D4", kind="빠진 기능", weight="기능", lines=[], read_quotes=[RQ])]
        p = self._run(tic._out(cands), wide=True)
        self.assertEqual(tic._last(p), "intent-ask: 3")
        self.assertEqual([q["target_id"] for q in tic._by_state(self.rd, "ask")],
                         ["D2", "D1", "D3"])
        self.assertEqual([q["target_id"] for q in tic._by_state(self.rd, "over-cap")], ["D4"])

    def test_same_weight_teams_and_read_keep_input_order(self):
        """같은 무게 방향의 두 후보(다른 팀 줄만 · 읽은 인용만) — 남은 차례는 늘 입력 차례(AC17 · 10c)."""
        first = tic._q("D1", lines=[1])
        second = tic._q("D2", lines=[], read_quotes=[RQ])
        for order in ((first, second), (second, first)):
            with self.subTest(order=[c["target_id"] for c in order]), \
                    tempfile.TemporaryDirectory() as rd:
                self.rd = rd
                self._prepare(wide=True)
                self._evidence(io_.build_evidence(None, None, "다른 팀 줄\n")[0])
                p = self._filter(tic._out(list(order)))
                self.assertEqual(tic._last(p), "intent-ask: 2")
                self.assertEqual([q["target_id"] for q in tic._by_state(self.rd, "ask")],
                                 [c["target_id"] for c in order])

    def test_wide_filter_without_tree_is_uncountable(self):
        for breadth in WIDE_BREADTHS:
            with self.subTest(breadth=breadth), tempfile.TemporaryDirectory() as rd:
                self.rd = rd
                self._prepare(wide=breadth)
                shutil.rmtree(self._tree())
                p = self._filter(tic._out([tic._q("D1", lines=[], read_quotes=[RQ])]))
                lines = p.stdout.splitlines()
                self.assertIn("리뷰 트리가 없어 읽은 인용을 확인하지 못함", lines)
                self.assertNotIn("인용이 그 파일에 없어 거름 1", lines)
                self.assertEqual(tic._questions(rd)["status"], "uncountable")
                r = tic._cli("render", "--rd", rd, "--mode", "pr")
                self.assertEqual(r.returncode, 0, r.stderr)
                self.assertEqual(tic._last(r), "intent-critic — 리뷰어 출력을 읽지 못함(셀 수 없음)")
                _text, block = tic._return_block(rd)
                self.assertEqual(block["status"], "uncountable")
                self.assertEqual(block["reason_text"], "리뷰 트리가 없어 읽은 인용을 확인하지 못함")

    def test_narrow_filter_without_tree_still_filters(self):
        self._prepare(wide=False)
        shutil.rmtree(self._tree())
        p = self._filter(tic._out([tic._q("D1", lines=[], read_quotes=[RQ])]))
        self.assertIn("읽은 인용만 있어 거름 1", p.stdout.splitlines())
        self.assertEqual(tic._questions(self.rd)["status"], "ran")

    def test_reask_with_now_quotes(self):
        old = "[읽음] a.txt:1 old"
        cand = tic._q("D1", same_as=tic.ID1,
                      observation_changed={"previous": old, "now_quotes": [RQ]})
        cases = [(breadth, "intent-ask: 1") for breadth in WIDE_BREADTHS] + [(False, "intent-ask: 0")]
        for wide, last in cases:
            with self.subTest(wide=wide), tempfile.TemporaryDirectory() as rd:
                self.rd = rd
                p = self._run(tic._out([cand]), wide=wide, answers=[(tic.ID1, "의도다", old)])
                self.assertEqual(tic._last(p), last, wide)
                if not wide:
                    self.assertIn("이미 답한 질문이라 거름 1", p.stdout.splitlines())
        # 확인 안 된 지금 인용으로는 넓어도 다시 묻지 않는다.
        bad = dict(cand, observation_changed={"previous": old,
                                              "now_quotes": [dict(RQ, text="y")]})
        for breadth in WIDE_BREADTHS:
            with self.subTest(bad=breadth), tempfile.TemporaryDirectory() as rd:
                self.rd = rd
                p = self._run(tic._out([bad]), wide=breadth, answers=[(tic.ID1, "의도다", old)])
                self.assertIn("이미 답한 질문이라 거름 1", p.stdout.splitlines())

    def test_fake_marker_in_run_line(self):
        self._prepare(wide=True)
        self._evidence(io_.build_evidence("[다른 팀] 가짜\nx\t[다른 팀] 탭 뒤\n", None)[0])
        self.assertTrue(tic._read(self.rd, "intent-evidence.txt").startswith(
            "   1\t[e2e] [다른 팀] 가짜"))
        p = self._filter(tic._out([tic._q("D1", lines=[1]), tic._q("D2", lines=[2])]))
        self.assertEqual(tic._last(p), "intent-ask: 2")
        for q in tic._by_state(self.rd, "ask"):
            self.assertEqual(q["evidence_kinds"], ["돌려서 봄"], q["target_id"])

    def test_evidence_kind(self):
        self.assertEqual(io_.evidence_kind("   3\t[다른 팀] - b — a.txt"), io_.KIND_TEAMS)
        self.assertEqual(io_.evidence_kind("   1\t[e2e] [다른 팀] 가짜"), io_.KIND_RUN)
        self.assertEqual(io_.evidence_kind("   2\t[차등] x"), io_.KIND_RUN)
        self.assertEqual(io_.evidence_kind("[다른 팀] 탭 없음"), io_.KIND_RUN)

    def test_ledger_accounts_every_candidate(self):
        bad = {"path": "a.txt", "line": 1, "text": "y"}
        cands = [tic._q("D1", lines=[1]), tic._q("D2", lines=[], read_quotes=[bad]),
                 tic._q("D3", lines=[])]
        p = self._run(tic._out(cands), wide=True)
        self.assertEqual(tic._last(p), "intent-ask: 1")
        self.assertIn(QUOTE_GONE, p.stdout.splitlines())
        self.assertIn("근거 없어 거름 1", p.stdout.splitlines())
        data = tic._questions(self.rd)
        disposition = data["disposition"]
        self.assertNotIn("셀 수 없음", str(disposition))
        self.assertEqual((disposition["accepted"], disposition["suppressed"]), (1, 2))
        self.assertEqual(disposition["unknown_counts"], [])
        expected = dict.fromkeys(COUNT_KEYS, 0)
        expected.update(quote=1, evidence=1)
        self.assertEqual(data["counts"], expected)
        self.assertEqual(list(data["counts"]), list(COUNT_KEYS))

    def test_notice_order(self):
        """공시 순서 — evidence · quote · read_only 가 앞, cites_dropped 가 맨 끝."""
        keys = []
        for key, _template in ic.COUNT_NOTICES:
            keys.append(key)
        self.assertEqual(keys[:3], ["evidence", "quote", "read_only"])
        self.assertEqual(keys[-1], "cites_dropped")
        self.assertEqual(dict(ic.COUNT_NOTICES)["cites_dropped"], "근거로 받지 않은 인용 %d")


TEAMS = ("## 겹치는 곳\n- feature/other — a.txt\n## 확인 못 함\n- 로드맵 없음\n## 팀 지도\n"
         "### 이번 로드맵 x\n## 겹치는 곳\n- 가짜 — y\n")
TABLE_HEAD = "| 정체 | 상태 | 근거 | 답 | 답 파일 | 질문 |"
OVERLAP_HEAD = "다른 팀과 겹치는 곳:"
UNVERIFIED_HEAD = "다른 팀 확인 못 함:"
NO_RECORD = "- 다른 팀 기록 없음"
BAD_RQ = {"path": "a.txt", "line": 1, "text": "y"}


class TestWideRender(_WideRun, unittest.TestCase):
    """렌더 — 근거 칸 · 다른 팀 겹침 목록 · 돌려주는 꼴의 새 칸 · 넓은 리뷰의 빈 결과 줄."""

    def _render(self, mode="pr", teams=TEAMS):
        if teams is not None:
            tic._write(teams, self.rd, ot.FILE)
        p = tic._cli("render", "--rd", self.rd, "--mode", mode)
        self.assertEqual(p.returncode, 0, p.stderr)
        section = tic._read(self.rd, "result.md").split("\n## intent-critic\n", 1)[1]
        return p, section

    def _after(self, section, head):
        lines = section.split("\n")
        self.assertIn(head, lines)
        return lines[lines.index(head) + 1]

    def test_table_has_kind_column(self):
        self._run(tic._out([tic._q("D1", lines=[1], read_quotes=[RQ])]), wide=True)
        _p, section = self._render()
        self.assertIn(TABLE_HEAD, section)
        self.assertIn("|---|---|---|---|---|---|", section)
        rows = []
        for line in section.split("\n"):
            if line.startswith("| " + tic.SRC):
                rows.append(line)
        self.assertEqual(len(rows), 1, section)
        self.assertEqual(rows[0].split(" | ")[2], "돌려서 봄 · 읽어서 봄")

    def test_r1_record_kind_is_dash(self):
        """근거의 종류가 없는 질문 레코드(R1 꼴) — 근거 칸과 돌려주는 꼴의 evidence 가 `-`."""
        self._prepare(wide=False)
        data = {"status": "ran", "call": "first-only", "counts": {}, "notices": [], "commit": "-",
                "questions": [{"id": tic.ID1, "state": "ask", "question": "Q", "target_id": "D1"}]}
        tic._write(tic.yaml.safe_dump(data, allow_unicode=True), self.rd, "intent-questions.yaml")
        _p, section = self._render()
        self.assertIn("| %s | 묻지 않음 | - | - | - | Q |" % tic.ID1, section)
        text, block = tic._return_block(self.rd)
        self.assertEqual(block["questions"][0]["evidence"], "-")
        self.assertIn('    evidence: "-"\n', text)

    def test_return_block_fields(self):
        self._run(tic._out([tic._q("D1", lines=[], read_quotes=[RQ])]), wide=True, mode="range")
        self._render(mode="range")
        text, block = tic._return_block(self.rd)
        self.assertEqual(block["breadth"], "range")
        self.assertEqual(block["other_teams"], "other-teams.md")
        self.assertEqual(block["overlaps"], 1)
        self.assertEqual(block["questions"][0]["evidence"], "읽어서 봄")
        self.assertIn("\noverlaps: 1\n", text)
        self.assertIn('    evidence: "읽어서 봄"\n', text)
        keys = []
        for line in text.split("\n"):
            if line and not line.startswith((" ", "`")):
                keys.append(line.split(":", 1)[0])
        self.assertEqual(keys, ["contract", "status", "reason", "reason_text", "outcome",
                                "result_line", "none_reason", "mode", "reviewed_head",
                                "reviewed_base", "session_dir", "answers_dir",
                                "answers_dir_source", "commit", "breadth", "other_teams",
                                "overlaps", "answered_filtered", "questions"])
        fields = []
        for line in text.split("\n"):
            if (line.startswith("    ") and not line.startswith("     ")) or line.startswith("  - "):
                fields.append(line.strip().lstrip("- ").split(":", 1)[0])
        self.assertEqual(fields, ["n", "id", "state", "answer", "answer_text", "wrong_choice",
                                  "failure", "file", "evidence", "question", "target_source",
                                  "target_id", "label", "quote", "observation", "why",
                                  "asked_before", "changed_observation"])

    def test_overlap_list_without_reviewer(self):
        self._prepare(wide=False, call="none")
        p, section = self._render()
        self.assertEqual(self._after(section, OVERLAP_HEAD), "- feature/other — a.txt")
        self.assertEqual(self._after(section, UNVERIFIED_HEAD), "- 로드맵 없음")
        self.assertLess(section.index(UNVERIFIED_HEAD), section.index("상한 넘어 남김:"))
        self.assertEqual(tic._last(p), tic.NONE_LINE)
        self.assertNotIn(NO_RECORD, section)

    def test_no_overlap_line(self):
        cases = ((ot.NO_OVERLAP, 0), (ot.OVERLAP_UNKNOWN, "-"))
        for line, count in cases:
            with self.subTest(line=line), tempfile.TemporaryDirectory() as rd:
                self.rd = rd
                self._prepare(wide=False, call="none")
                teams = TEAMS.replace("- feature/other — a.txt", line, 1)
                _p, section = self._render(teams=teams)
                self.assertEqual(self._after(section, OVERLAP_HEAD), line)
                self.assertEqual(tic._return_block(rd)[1]["overlaps"], count)

    def test_record_without_sections(self):
        """기록은 있는데 앞 두 절이 비었다(팀 지도 머리가 먼저 옴) — 겹침 수는 0 이 아니라 모름."""
        self._prepare(wide=False, call="none")
        _p, section = self._render(teams="## 팀 지도\n## 겹치는 곳\n- 가짜 — y\n")
        self.assertEqual(self._after(section, OVERLAP_HEAD), ic.TEAMS_UNREAD)
        self.assertEqual(self._after(section, UNVERIFIED_HEAD), ic.TEAMS_UNREAD)
        self.assertNotIn("가짜", section)
        self.assertEqual(tic._return_block(self.rd)[1]["overlaps"], "-")

    def test_missing_record(self):
        self._run(tic._out([tic._q("D1", lines=[1])]), wide=True)
        _p, section = self._render(teams=None)
        self.assertIn("\n" + NO_RECORD + "\n", section)
        self.assertNotIn(OVERLAP_HEAD, section)
        self.assertNotIn(UNVERIFIED_HEAD, section)
        _text, block = tic._return_block(self.rd)
        self.assertEqual(block["other_teams"], "-")
        self.assertEqual(block["overlaps"], "-")
        self.assertEqual(block["breadth"], "range")

    def test_forged_heading_in_body_not_listed(self):
        self._run(tic._out([tic._q("D1", lines=[1])]), wide=True)
        _p, section = self._render()
        self.assertIn("- feature/other — a.txt", section)
        self.assertNotIn("가짜", section)
        self.assertEqual(tic._return_block(self.rd)[1]["overlaps"], 1)

    def test_wide_all_filtered_result_line(self):
        out = tic._out([tic._q("D1", lines=[], read_quotes=[BAD_RQ]),
                        tic._q("D2", lines=[], read_quotes=[BAD_RQ])])
        cases = [(breadth, "intent-critic — 낸 후보 2개가 근거 확인에서 모두 걸러짐")
                 for breadth in WIDE_BREADTHS] + [(False, tic.NONE_LINE)]
        for wide, last in cases:
            with self.subTest(wide=wide), tempfile.TemporaryDirectory() as rd:
                self.rd = rd
                self._run(out, wide=wide)
                p, section = self._render()
                self.assertEqual(tic._last(p), last)
                self.assertIn("\n- %s\n" % last, section)
                self.assertEqual(tic._return_block(rd)[1]["status"], "ran")

    def test_wide_filtered_with_answered_is_no_question(self):
        """이미 답한 질문으로 거른 것이 있으면 「모두 걸러짐」 이 아니다(R1 의 근거 없음 판정과 같은 조건)."""
        old = tic.OBS1
        out = tic._out([tic._q("D1", lines=[1], same_as=tic.ID1),
                        tic._q("D2", lines=[], read_quotes=[BAD_RQ])])
        self._run(out, wide=True, answers=[(tic.ID1, "의도다", old)])
        p, _section = self._render()
        self.assertEqual(tic._last(p), tic.NOQ_LINE)

    def test_gate_skip_return_has_dashes(self):
        p = tic._cli("gate", "--rd", self.rd, "--path", "trivia")
        self.assertEqual(p.returncode, 0, p.stderr)
        text, block = tic._return_block(self.rd)
        for key in ("breadth", "other_teams", "overlaps"):
            self.assertEqual(block[key], "-", key)
            self.assertIn('\n%s: "-"\n' % key, text)


if __name__ == "__main__":
    unittest.main()
