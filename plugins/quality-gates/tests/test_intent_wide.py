"""R2 넓게 보는 조언자 — 표시 · 넓이 · 준비 · 거름 · 렌더(scripts/intent_origin.py · intent_critic.py)."""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import test_intent_critic as tic  # noqa: E402 — 헬퍼만 빌린다

io_ = tic.io_
ia = tic.ia
ic = tic._load("intent_critic")
MARKERS = list(io_.DEFAULT_MARKERS)
OTHER_MAX = "DEVBREW_QUALITY_GATES_OTHER_TEAMS_MAX_BYTES"
ENV_MARKERS = "DEVBREW_QUALITY_GATES_INTENT_DOC_MARKERS"


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
                         "source_interview,roadmap,source_brief,type=roadmap,type=epic-bundle")
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


if __name__ == "__main__":
    unittest.main()
