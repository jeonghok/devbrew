"""raw_source.py locate — 원자료(framing 기록 파일)를 찾는 길과 판결 줄."""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

_SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(_SCRIPTS))
RAW = str(_SCRIPTS / "raw_source.py")

import raw_source as RS  # noqa: E402
import legacy_names  # noqa: E402
import team_write  # noqa: E402

SEED = "---\ntype: interview-seed\naudit_file: other.audit.md\n---\n\n문장 하나.\n"
AUDIT = "---\ntype: interview-seed-audit\n---\n\n## 1. 원문\n\n원문.\n"


def state_text(seed_value, body="그냥 요청"):
    return ("---\ntype: interview-state\nseed: %s\n---\n\n## 풀린 입력\n\n~~~~\n%s\n~~~~\n"
            % (seed_value, body))


def put(root, rel, text):
    p = Path(root) / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")
    return p


def run_in(cwd, *args):
    cp = subprocess.run([sys.executable, RAW, "locate"] + list(args), cwd=cwd,
                        capture_output=True, text=True, encoding="utf-8",
                        env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"))
    return cp


def last(cp):
    lines = cp.stdout.splitlines()
    return lines[-1] if lines else ""


class RepoCase(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        self.repo = os.path.realpath(self._td.name)
        subprocess.run(["git", "init", "-q", self.repo], check=True)

    def run_(self, *args, cwd=None):
        cp = run_in(cwd or self.repo, *args)
        return cp.returncode, last(cp)

    def seed_pair(self, name="s"):
        put(self.repo, "docs/%s.md" % name, SEED)
        put(self.repo, "docs/%s.audit.md" % name, AUDIT)


class SeedMode(RepoCase):
    def test_found(self):
        self.seed_pair()
        self.assertEqual(self.run_("--seed", "docs/s.md"), (0, "raw-source: FOUND docs/s.audit.md"))

    def test_seed_missing(self):
        self.assertEqual(self.run_("--seed", "docs/none.md"),
                         (3, "raw-source: LOST " + RS.R_SEED_MISSING.format(seed="docs/none.md")))

    def test_not_md(self):
        put(self.repo, "docs/s.txt", SEED)
        self.assertEqual(self.run_("--seed", "docs/s.txt"),
                         (3, "raw-source: LOST " + RS.R_SEED_NOT_MD.format(seed="docs/s.txt")))

    def test_audit_missing(self):
        put(self.repo, "docs/s.md", SEED)
        put(self.repo, "docs/other.audit.md", AUDIT)
        self.assertEqual(self.run_("--seed", "docs/s.md"),
                         (3, "raw-source: LOST " + RS.R_AUDIT_MISSING.format(audit="docs/s.audit.md")))

    def test_audit_type(self):
        put(self.repo, "docs/s.md", SEED)
        put(self.repo, "docs/s.audit.md", "---\ntype: interview-brief\n---\n\n본문\n")
        self.assertEqual(self.run_("--seed", "docs/s.md"),
                         (3, "raw-source: LOST " + RS.R_AUDIT_TYPE.format(audit="docs/s.audit.md", kind="interview-brief")))
        put(self.repo, "docs/s.audit.md", "머리 없음\n")
        self.assertEqual(self.run_("--seed", "docs/s.md"),
                         (3, "raw-source: LOST " + RS.R_AUDIT_TYPE.format(audit="docs/s.audit.md", kind="없음")))

    def test_audit_type_empty_value(self):
        put(self.repo, "docs/s.md", SEED)
        put(self.repo, "docs/s.audit.md", "---\ntype:\n---\n\n본문\n")
        self.assertEqual(self.run_("--seed", "docs/s.md"),
                         (3, "raw-source: LOST " + RS.R_AUDIT_TYPE.format(audit="docs/s.audit.md", kind="없음")))

    def test_audit_unreadable(self):
        put(self.repo, "docs/s.md", SEED)
        p = Path(self.repo) / "docs/s.audit.md"
        p.write_bytes(b"\xff\xfe\x00bad")
        self.assertEqual(self.run_("--seed", "docs/s.md"),
                         (3, "raw-source: LOST " + RS.R_AUDIT_TYPE.format(audit="docs/s.audit.md", kind="읽지 못함")))

    def test_link_seed(self):
        with tempfile.TemporaryDirectory() as outside:
            real = put(outside, "real.md", SEED)
            (Path(self.repo) / "docs").mkdir()
            os.symlink(str(real), str(Path(self.repo) / "docs/l.md"))
            put(self.repo, "docs/l.audit.md", AUDIT)
            self.assertEqual(self.run_("--seed", "docs/l.md"), (0, "raw-source: FOUND docs/l.audit.md"))

    def test_odd_name(self):
        self.seed_pair("notes")
        self.assertEqual(self.run_("--seed", "docs/notes.md"), (0, "raw-source: FOUND docs/notes.audit.md"))

    def test_outside_tree(self):
        with tempfile.TemporaryDirectory() as outside:
            s = put(outside, "x.md", SEED)
            put(outside, "x.audit.md", AUDIT)
            self.assertEqual(self.run_("--seed", str(s)),
                             (0, "raw-source: FOUND " + str(s)[:-3] + ".audit.md"))


class InterviewMode(RepoCase):
    def test_brief_and_state_agree(self):
        self.seed_pair()
        put(self.repo, "docs/b.state.md", state_text("docs/s.md"))
        put(self.repo, "docs/b.md", "---\ntype: interview-brief\n---\n")
        want = (0, "raw-source: FOUND docs/s.audit.md")
        self.assertEqual(self.run_("--interview", "docs/b.md"), want)
        self.assertEqual(self.run_("--interview", "docs/b.state.md"), want)

    def test_no_state(self):
        put(self.repo, "docs/b.md", "---\ntype: interview-brief\n---\n")
        self.assertEqual(self.run_("--interview", "docs/b.md"), (0, "raw-source: NO-FRAMING"))

    def test_seed_none_plain_input(self):
        put(self.repo, "docs/b.state.md", state_text("없음"))
        self.assertEqual(self.run_("--interview", "docs/b.state.md"), (0, "raw-source: NO-FRAMING"))

    def test_seed_none_seed_input(self):
        put(self.repo, "docs/b.state.md", state_text("없음", SEED.rstrip("\n")))
        self.assertEqual(self.run_("--interview", "docs/b.state.md"),
                         (3, "raw-source: LOST " + RS.R_SEED_UNRECORDED))

    def test_seed_empty_seed_input(self):
        put(self.repo, "docs/b.state.md", state_text("", SEED.rstrip("\n")))
        self.assertEqual(self.run_("--interview", "docs/b.state.md"),
                         (3, "raw-source: LOST " + RS.R_SEED_UNRECORDED))

    def _no_framing_for(self, text):
        put(self.repo, "docs/b.state.md", text)
        self.assertEqual(self.run_("--interview", "docs/b.state.md"), (0, "raw-source: NO-FRAMING"))
        v = RS.locate_from_interview(str(Path(self.repo) / "docs/b.state.md"))
        self.assertEqual(v.kind, "NO-FRAMING")

    def test_block_three_tilde_fence(self):
        self._no_framing_for("---\ntype: interview-state\nseed: 없음\n---\n\n## 풀린 입력\n\n~~~\n"
                             + SEED.rstrip("\n") + "\n~~~\n")

    def test_block_five_tilde_fence(self):
        put(self.repo, "docs/b.state.md", "---\ntype: interview-state\nseed: 없음\n---\n\n## 풀린 입력\n\n~~~~~\n"
            + SEED.rstrip("\n") + "\n~~~~~\n")
        self.assertEqual(self.run_("--interview", "docs/b.state.md"),
                         (3, "raw-source: LOST " + RS.R_SEED_UNRECORDED))

    def test_block_backtick_fence(self):
        self._no_framing_for("---\ntype: interview-state\nseed: 없음\n---\n\n## 풀린 입력\n\n````\n"
                             + SEED.rstrip("\n") + "\n````\n")

    def test_block_prose_before_fence(self):
        self._no_framing_for("---\ntype: interview-state\nseed: 없음\n---\n\n## 풀린 입력\n\n먼저 한 줄.\n\n~~~~\n"
                             + SEED.rstrip("\n") + "\n~~~~\n")

    def test_block_fenced_other_type(self):
        self._no_framing_for(state_text("없음", "---\ntype: interview-brief\n---\n\n문장 하나."))

    def test_block_heading_only_in_frontmatter(self):
        self._no_framing_for("---\ntype: interview-state\nseed: 없음\n## 풀린 입력\n~~~~\n---\n"
                             "type: interview-seed\n---\n~~~~\n")

    def test_no_block(self):
        put(self.repo, "docs/b.state.md", "---\ntype: interview-state\nseed: 없음\n---\n\n본문\n")
        self.assertEqual(self.run_("--interview", "docs/b.state.md"), (0, "raw-source: NO-FRAMING"))

    def test_recorded_seed_missing(self):
        put(self.repo, "docs/b.state.md", state_text("docs/gone.md"))
        self.assertEqual(self.run_("--interview", "docs/b.state.md"),
                         (3, "raw-source: LOST " + RS.R_SEED_MISSING.format(seed="docs/gone.md")))

    def test_recorded_audit_type(self):
        put(self.repo, "docs/s.md", SEED)
        put(self.repo, "docs/s.audit.md", "---\ntype: interview-brief\n---\n")
        put(self.repo, "docs/b.state.md", state_text("docs/s.md"))
        self.assertEqual(self.run_("--interview", "docs/b.state.md"),
                         (3, "raw-source: LOST " + RS.R_AUDIT_TYPE.format(audit="docs/s.audit.md", kind="interview-brief")))

    def test_quoted_seed(self):
        self.seed_pair()
        put(self.repo, "docs/b.state.md", state_text('"docs/s.md"'))
        self.assertEqual(self.run_("--interview", "docs/b.state.md"), (0, "raw-source: FOUND docs/s.audit.md"))

    def test_cwd_elsewhere(self):
        self.seed_pair()
        st = put(self.repo, "docs/b.state.md", state_text("docs/s.md"))
        with tempfile.TemporaryDirectory() as other:
            self.assertEqual(self.run_("--interview", str(st), cwd=other),
                             (0, "raw-source: FOUND docs/s.audit.md"))

    def test_usage_errors(self):
        for args in (("--interview", "docs/x.audit.md"), ("--interview", "docs/x.txt"),
                     ("--seed", "a.md", "--interview", "b.md"), ()):
            cp = run_in(self.repo, *args)
            self.assertEqual(cp.returncode, 2, args)
            self.assertNotIn("raw-source:", cp.stdout, args)

    def test_state_unreadable(self):
        p = Path(self.repo) / "docs"
        p.mkdir()
        (p / "b.state.md").write_bytes(b"\xff\xfe\x00bad")
        cp = run_in(self.repo, "--interview", "docs/b.state.md")
        self.assertEqual(cp.returncode, 2)
        self.assertIn("[raw_source]", cp.stderr)
        self.assertNotIn("raw-source:", cp.stdout)


class _W:
    class Refused(Exception):
        pass

    class Usage(Exception):
        pass

    @staticmethod
    def read(p):
        return Path(p).read_text(encoding="utf-8")

    @staticmethod
    def rel(top, p):
        return Path(os.path.realpath(p)).relative_to(top).as_posix()


def theirs(top, state_rel):
    """옆 생성기의 답을 판결 종류로 옮긴다."""
    found, lost = team_write._framing_from_state(Path(top), state_rel, _W)
    if found is not None:
        fm = RS.frontmatter_scalars(Path(top) / found) or {}
        return ("FOUND", found) if legacy_names.kind_matches(fm.get("type"), team_write.FRAMING_TYPE) else ("LOST", None)
    if lost is not None:
        return ("LOST", None)
    return ("NO-FRAMING", None)


class ParityWithTeamWrite(RepoCase):
    def mine(self):
        v = RS.locate_from_interview(str(Path(self.repo) / "docs/b.state.md"))
        return (v.kind, v.audit)

    def check(self):
        self.assertEqual(self.mine(), theirs(self.repo, "docs/b.state.md"))

    def test_same(self):
        # 1 framing 있음
        self.seed_pair()
        put(self.repo, "docs/b.state.md", state_text("docs/s.md"))
        self.check()
        self.assertEqual(self.mine()[0], "FOUND")
        # 2 framing 없음
        put(self.repo, "docs/b.state.md", state_text("없음"))
        self.check()
        self.assertEqual(self.mine()[0], "NO-FRAMING")
        # 3 상태 파일 없음
        (Path(self.repo) / "docs/b.state.md").unlink()
        self.check()
        self.assertEqual(self.mine()[0], "NO-FRAMING")
        # 4 기록 파일 없음
        put(self.repo, "docs/t.md", SEED)
        put(self.repo, "docs/b.state.md", state_text("docs/t.md"))
        self.check()
        self.assertEqual(self.mine()[0], "LOST")
        # 5 seed 파일 없음
        put(self.repo, "docs/b.state.md", state_text("docs/gone.md"))
        self.check()
        self.assertEqual(self.mine()[0], "LOST")
        # 6 type 다름
        put(self.repo, "docs/u.md", SEED)
        put(self.repo, "docs/u.audit.md", "---\ntype: interview-brief\n---\n")
        put(self.repo, "docs/b.state.md", state_text("docs/u.md"))
        self.check()
        self.assertEqual(self.mine()[0], "LOST")
        # 7 .md 아님
        put(self.repo, "docs/v.txt", SEED)
        put(self.repo, "docs/b.state.md", state_text("docs/v.txt"))
        self.check()
        self.assertEqual(self.mine()[0], "LOST")

    def test_documented_difference(self):
        put(self.repo, "docs/b.state.md", state_text("없음", SEED.rstrip("\n")))
        self.assertEqual(theirs(self.repo, "docs/b.state.md"), ("NO-FRAMING", None))
        self.assertEqual(self.mine(), ("LOST", None))
        self.assertEqual(RS.locate_from_interview(str(Path(self.repo) / "docs/b.state.md")).reason,
                         RS.R_SEED_UNRECORDED)


if __name__ == "__main__":
    unittest.main()
