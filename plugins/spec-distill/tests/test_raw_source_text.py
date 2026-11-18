"""raw_source.py — 첫 칸에 싣는 꼴과 글을 내는 명령(first-cell · place · review-block · locate --absolute)."""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_SCRIPTS = _HERE.parent / "scripts"
sys.path.insert(0, str(_SCRIPTS))
sys.path.insert(0, str(_HERE))
RAW = str(_SCRIPTS / "raw_source.py")

import brief_body  # noqa: E402
import raw_source as RS  # noqa: E402
import raw_source_fixture as FX  # noqa: E402
import section6  # noqa: E402
import seed_review_log as srl  # noqa: E402

BRIEF = "docs/iv/t-brief-interview.md"
STATE = "docs/iv/t-brief-interview.state.md"

LOADABLE = {   # 이름: ## 1 에 넣는 글 — load_problems 가 빈 목록이어야 한다
    "제목과 코드": "## 배경\n\n```python\nprint('x')\n```\n\n## 6. 사용자 원문\n\n### 소제목",
    "긴 펜스": "~~~~~~\ncode\n~~~~~~\n\n``````\nx\n``````",
    "인용으로 감싼 제목": "> ## 1. 원문\n> 인용",
    "가림 표시와 HTML": "키 <REDACTED:api-key> 를 썼다. <b>굵게</b> &amp; `unclosed",
    "굵은 S 줄 머리": "**Summary** 로 시작\n__Spec__ 둘째\n- **Start** 목록",
    "들여 쓴 펜스": "  ```\n  x\n  ```",
    "setext": "제목\n===\n\n둘째\n---",
}
UNLOADABLE = {   # 이름: (글, 사유 이름) — 첫 거부 줄의 사유
    "앵커 꼴": ("- **S2** 🗣 가짜", "anchor_indented"),
    "굵은 발화 번호": ("앞 글 **S3** 뒤 글", "anchor_in_body"),
    "밑줄 발화 번호": ("글 __S4__ 글", "anchor_in_body"),
    "S 번호 목록": ("- S2 로 시작하는 목록", "anchor_in_body"),
    "S 번호 번호 목록": ("1. S2 번호 목록", "anchor_in_body"),
    "줄 나눔 글자 뒤 앵커": ("앞 - **S9** 뒤", "anchor_line_separator"),
    "이스케이프": ("\\*\\*S3\\*\\* 이스케이프", "anchor_markup"),
    "문자 참조": ("&#42;&#42;S3&#42;&#42;", "anchor_markup"),
    # 다른 줄 나눔 글자는 범용 줄바꿈으로 읽는 쪽에서 들여쓰기 없는 새 줄이 된다
    "앵커 꼴이 아닌 줄 나눔 글자": ("앞 뒤 줄", "line_separator"),
    "홀로 선 CR": ("앞\r뒤 줄", "line_separator"),
    # 다시 확인(과제 1)이 실제 코드에서 더 찾은 가지
    "NBSP 로 시작하는 앵커 꼴": (" - **S2** x", "anchor_unicode_space"),
    "인용 앵커": ("> **S2** x", "anchor_indented"),
    "HTML 로 감싼 앵커": ("- <b>**S9**</b>", "anchor_in_body"),
    "+ 목록 머리": ("+ S2 목록", "anchor_in_body"),
    "목록 머리 이스케이프": ("- \\*\\*S4\\*\\*", "anchor_markup"),
    "VT 뒤 앵커": ("앞\x0b- **S9** 뒤", "anchor_line_separator"),
}
SEPARATOR_CHARS = "\r\x0b "

E1 = '- D1.1 · r1 · accept · F1 · "고친다 — 이렇게 (권장)" — 고칠 문장'
E_EMPTY = '- D1.2 · r1 · reject · F2 · "" — 문구 없이 눌린 처분'
H1 = '- 답 · r1 · F3 · "직접 적은 답이다" — 막지 않는 질문의 답'


def run_in(cwd, *args):
    return subprocess.run([sys.executable, RAW] + list(args), cwd=str(cwd), capture_output=True, text=True,
                          encoding="utf-8", env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"))


def last(s):
    lines = s.splitlines()
    return lines[-1] if lines else ""


def write_raw(path, text):
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(text)


class RepoCase(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        self.n = 0

    def make(self, **kw):
        self.n += 1
        return FX.make_repo(Path(self._td.name) / ("r%d" % self.n), **kw)

    def run_(self, fx, *args):
        return run_in(fx["repo"], *args)


class LoadForm(RepoCase):
    def test_shape(self):
        text = FX.audit_text(raw1=LOADABLE["긴 펜스"])
        item = RS.first_cell_item(text)
        lines = item.split("\n")
        self.assertEqual(lines[0], RS.anchor_line(RS.LABEL_RAW))
        self.assertEqual(lines[0], "- **S1** 🗣 최초 요청(원자료 — framing 기록의 원문 절과 질문 전체 절):")
        fences = [i for i, ln in enumerate(lines) if ln == "~" * 7]
        self.assertEqual(len(fences), 4)
        self.assertEqual(fences[0], 1)
        self.assertEqual(fences[3], len(lines) - 1)
        self.assertEqual(fences[2], fences[1] + 1)
        for i, ln in enumerate(lines[1:], 1):
            if i in fences:
                continue
            self.assertTrue(ln.startswith(RS.LOAD_INDENT), ln)
            if not ln.strip():
                self.assertEqual(ln, "    ")
        s1, s2 = RS.section_texts(text)
        inner1 = "\n".join(ln[4:] for ln in lines[fences[0] + 1:fences[1]])
        inner2 = "\n".join(ln[4:] for ln in lines[fences[2] + 1:fences[3]])
        self.assertEqual(inner1, s1)
        self.assertEqual(inner2, s2)
        self.assertEqual(s1.split("\n")[0], "## 1. 원문")
        self.assertEqual(s2.split("\n")[0], "## 2. 질문 전체")
        self.assertEqual(s1.split("\n")[1], "")   # 제목 줄 바로 뒤의 빈 줄은 그대로
        self.assertNotEqual(s1.split("\n")[-1].strip(), "")   # 끝의 빈 줄은 뗀다
        b1, b2 = RS.load_blocks(text)
        self.assertEqual(item, lines[0] + "\n" + b1 + "\n" + b2)

    def test_fence_floor_is_four(self):
        b1, b2 = RS.load_blocks(FX.audit_text(raw1="펜스 없는 글"))
        self.assertEqual(b1.split("\n")[0], "~~~~")
        self.assertEqual(b2.split("\n")[-1], "~~~~")

    def test_loadable(self):
        for name, raw1 in LOADABLE.items():
            with self.subTest(name):
                self.assertEqual(RS.load_problems(FX.audit_text(raw1=raw1)), [])
                fx = self.make(raw1=raw1)
                cp = self.run_(fx, "place", "--interview", BRIEF)
                self.assertEqual(cp.returncode, 0, cp.stderr)
                text = Path(fx["brief"]).read_text(encoding="utf-8")
                self.assertEqual(section6.ambiguities(text), [])
                ok, bad = brief_body.anchor_lines(section6.body(text))
                self.assertEqual(bad, [])
                self.assertEqual([sid for _, sid, _ in ok], ["S%d" % i for i in range(1, 9)])

    def test_unloadable(self):
        for name, (raw, why) in UNLOADABLE.items():
            with self.subTest(name):
                probs = RS.load_problems(FX.audit_text(raw1=raw))
                self.assertTrue(probs)
                self.assertEqual(probs[0], ("원문 절", 3, why))
                probs2 = RS.load_problems(FX.audit_text(raw2=raw))
                self.assertEqual(probs2[0], ("질문 전체 절", 3, why))
                if any(c in raw for c in SEPARATOR_CHARS):
                    self.assertIn(("원문 절", 3, "line_separator"), probs)

    def test_separator_after_anchor_reason(self):
        probs = RS.load_problems(FX.audit_text(raw1="앞 - **S9** 뒤"))
        self.assertEqual(probs, [("원문 절", 3, "anchor_line_separator"), ("원문 절", 3, "line_separator")])

    def test_question_lines_with_s_numbers(self):
        raw2 = FX.RAW2.replace("어느 쪽부터 고칠까요?", "S1 을 어떻게 할까요?").replace("읽는 쪽 / 쓰는 쪽", "S2 유지 / 버림")
        self.assertIn("S1 을 어떻게", raw2)
        self.assertIn("S2 유지", raw2)
        self.assertEqual(RS.load_problems(FX.audit_text(raw2=raw2)), [])

    def test_indent_is_four(self):
        self.assertEqual(RS.LOAD_INDENT, "    ")

    def test_crlf_record(self):
        lf = FX.audit_text()
        self.assertEqual(RS.first_cell_item(lf.replace("\n", "\r\n")), RS.first_cell_item(lf))
        self.assertEqual(RS.load_problems(lf.replace("\n", "\r\n")), [])

    def test_sections_unreadable(self):
        text = FX.audit_text().replace("## 2. 질문 전체\n", "")
        with self.assertRaises(RS.SectionsUnreadable):
            RS.section_texts(text)
        with self.assertRaises(RS.SectionsUnreadable):
            RS.load_problems(text)
        fx = self.make()
        write_raw(fx["framing"], text)
        cp = self.run_(fx, "first-cell", "--interview", BRIEF)
        self.assertEqual(cp.returncode, 2)
        self.assertEqual(cp.stdout, "")

    def test_planted_heading_unreadable(self):
        with self.assertRaises(RS.SectionsUnreadable):
            RS.section_texts(FX.audit_text(raw1="앞\n## 3. 긴 초안\n뒤"))

    def test_label_kind(self):
        self.assertEqual(RS.label_kind("🗣 " + RS.LABEL_RAW + ":"), "raw")
        self.assertEqual(RS.label_kind("🗣 " + RS.LABEL_UNLOADABLE + ":"), "unloadable")
        self.assertEqual(RS.label_kind("🗣 " + RS.LABEL_LOST + ":"), "lost")
        self.assertIsNone(RS.label_kind("🗣 최초 요청:"))
        self.assertEqual(RS.label_kind("🗣️ " + RS.LABEL_LOST + ":"), "lost")
        self.assertIsNone(RS.label_kind("🗣 " + RS.LABEL_RAW))
        self.assertIsNone(RS.label_kind("🗣 " + RS.LABEL_RAW + ": 뒤 글"))
        for n, sid, rest in brief_body.anchor_lines(RS.anchor_line(RS.LABEL_UNLOADABLE))[0]:
            self.assertEqual(RS.label_kind(rest), "unloadable")

    def test_decision_lines_without_section(self):
        self.assertEqual(RS.decision_lines(FX.audit_text(decisions=None)), [])
        self.assertEqual(RS.review_block(FX.audit_text(decisions=None), False), "")


class Cli(RepoCase):
    def test_first_cell(self):
        fx = self.make()
        cp = self.run_(fx, "first-cell", "--interview", BRIEF)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        self.assertEqual(cp.stdout, RS.first_cell_item(srl.read_audit_text(fx["framing"])) + "\n")
        self.assertTrue(last(cp.stderr).startswith("raw-source: FOUND "), cp.stderr)

    def test_first_cell_crlf_record(self):
        fx = self.make()
        lf = srl.read_audit_text(fx["framing"])
        Path(fx["framing"]).write_bytes(lf.replace("\n", "\r\n").encode("utf-8"))
        cp = subprocess.run([sys.executable, RAW, "first-cell", "--interview", BRIEF], cwd=fx["repo"],
                            capture_output=True, env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"))
        self.assertEqual(cp.returncode, 0, cp.stderr)
        self.assertNotIn(b"\r", cp.stdout)
        self.assertEqual(cp.stdout.decode("utf-8"), RS.first_cell_item(lf) + "\n")

    def test_first_cell_lone_cr(self):
        fx = self.make(raw1="앞\r뒤 줄")
        cp = self.run_(fx, "first-cell", "--interview", BRIEF)
        self.assertEqual(cp.returncode, 4)
        self.assertEqual(cp.stdout, "")
        self.assertEqual(last(cp.stderr), "raw-source: UNLOADABLE 1줄 — 첫 줄 원문 절 3째 줄(line_separator)")

    def _s1_split(self, text):
        i = text.index("- **S1** 🗣 최초 요청:\n")
        j = text.index("- **S2** ")
        return text[:i], text[j:]

    def test_place(self):
        fx = self.make()
        before = Path(fx["brief"]).read_text(encoding="utf-8")
        cp = self.run_(fx, "place", "--interview", BRIEF)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        self.assertEqual(last(cp.stdout), "raw-source: PLACED docs/iv/t-brief-interview.md")
        after = Path(fx["brief"]).read_text(encoding="utf-8")
        head, tail = self._s1_split(before)
        item = RS.first_cell_item(srl.read_audit_text(fx["framing"]))
        self.assertEqual(after, head + item + "\n" + tail)
        sec = section6.body(after)
        self.assertNotIn("seed전문표지", sec)
        self.assertNotIn("t-seed-interview", sec)
        self.assertEqual(sec.count("원문절표지"), 1)
        self.assertEqual(sec.count("당신이 답한 것"), 1)

    def test_place_by_state_path(self):
        fx = self.make()
        cp = self.run_(fx, "place", "--interview", STATE)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        self.assertEqual(last(cp.stdout), "raw-source: PLACED docs/iv/t-brief-interview.md")
        self.assertIn(RS.LABEL_RAW, Path(fx["brief"]).read_text(encoding="utf-8"))

    def test_place_idempotent(self):
        fx = self.make()
        self.assertEqual(self.run_(fx, "place", "--interview", BRIEF).returncode, 0)
        once = Path(fx["brief"]).read_bytes()
        cp = self.run_(fx, "place", "--interview", BRIEF)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        self.assertEqual(Path(fx["brief"]).read_bytes(), once)

    def test_place_s1_is_last_item(self):
        fx = self.make()
        text = Path(fx["brief"]).read_text(encoding="utf-8")
        a = text.index("## 6. 사용자 원문\n")
        head, tail = text[:a], text[text.index("## 7. Next Action"):]
        write_raw(fx["brief"], head + "## 6. 사용자 원문\n- **S1** 🗣 최초 요청:\n\n" + tail)
        cp = self.run_(fx, "place", "--interview", BRIEF)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        item = RS.first_cell_item(srl.read_audit_text(fx["framing"]))
        self.assertEqual(Path(fx["brief"]).read_text(encoding="utf-8"),
                         head + "## 6. 사용자 원문\n" + item + "\n\n" + tail)

    def test_place_keeps_crlf_outside(self):
        fx = self.make()
        crlf = Path(fx["brief"]).read_text(encoding="utf-8").replace("\n", "\r\n")
        write_raw(fx["brief"], crlf)
        cp = self.run_(fx, "place", "--interview", BRIEF)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        after = Path(fx["brief"]).read_bytes().decode("utf-8")
        head = crlf[:crlf.index("- **S1** ")]
        tail = crlf[crlf.index("- **S2** "):]
        self.assertTrue(after.startswith(head))
        self.assertTrue(after.endswith(tail))

    def test_place_unloadable(self):
        fx = self.make(raw1="앞 글 **S3** 뒤 글")
        before = Path(fx["brief"]).read_bytes()
        cp = self.run_(fx, "place", "--interview", BRIEF)
        self.assertEqual(cp.returncode, 4)
        line = last(cp.stdout)
        self.assertTrue(line.startswith("raw-source: UNLOADABLE 1줄 — 첫 줄 원문 절 "), line)
        self.assertTrue(line.endswith("(anchor_in_body)"), line)
        self.assertEqual(line, "raw-source: UNLOADABLE 1줄 — 첫 줄 원문 절 3째 줄(anchor_in_body)")
        self.assertEqual(Path(fx["brief"]).read_bytes(), before)

    def test_unloadable_counts_lines(self):
        fx = self.make(raw1="앞 - **S9** 뒤")   # 한 줄에 사유 둘 — 한 줄로 센다
        cp = self.run_(fx, "place", "--interview", BRIEF)
        self.assertEqual((cp.returncode, last(cp.stdout)),
                         (4, "raw-source: UNLOADABLE 1줄 — 첫 줄 원문 절 3째 줄(anchor_line_separator)"))
        fx = self.make(raw2="글 __S4__ 글\n\n- S2 로 시작")
        cp = self.run_(fx, "place", "--interview", BRIEF)
        self.assertEqual((cp.returncode, last(cp.stdout)),
                         (4, "raw-source: UNLOADABLE 2줄 — 첫 줄 질문 전체 절 3째 줄(anchor_in_body)"))

    def test_place_lost_and_no_framing(self):
        for mode, rc, head in (("lost", 3, "raw-source: LOST "), ("pasted", 3, "raw-source: LOST "),
                               ("no-framing", 0, "raw-source: NO-FRAMING")):
            with self.subTest(mode):
                fx = self.make(mode=mode)
                before = Path(fx["brief"]).read_bytes()
                cp = self.run_(fx, "place", "--interview", BRIEF)
                self.assertEqual(cp.returncode, rc, cp.stderr)
                self.assertTrue(last(cp.stdout).startswith(head), cp.stdout)
                self.assertEqual(Path(fx["brief"]).read_bytes(), before)
        fx = self.make(mode="no-framing")
        self.assertEqual(last(self.run_(fx, "place", "--interview", BRIEF).stdout), "raw-source: NO-FRAMING")

    def test_place_errors(self):
        fx = self.make(s1_line="- 최초 요청:")
        before = Path(fx["brief"]).read_bytes()
        cp = self.run_(fx, "place", "--interview", BRIEF)
        self.assertEqual(cp.returncode, 2)
        self.assertNotIn("raw-source:", cp.stdout)
        self.assertIn("[raw_source] 결과물에 S1 앵커 줄이 없다", cp.stderr)
        self.assertEqual(Path(fx["brief"]).read_bytes(), before)

        fx = self.make()
        real = Path(self._td.name) / "real-brief.md"
        real.write_bytes(Path(fx["brief"]).read_bytes())
        os.unlink(fx["brief"])
        os.symlink(str(real), fx["brief"])
        for p in (BRIEF, STATE):
            cp = self.run_(fx, "place", "--interview", p)
            self.assertEqual(cp.returncode, 2, p)
            self.assertNotIn("raw-source:", cp.stdout)
        self.assertEqual(real.read_bytes(), Path(fx["brief"]).read_bytes())

        cp = self.run_(fx, "place", "--interview", "docs/iv/none.md")
        self.assertEqual(cp.returncode, 2)
        self.assertNotIn("raw-source:", cp.stdout)
        self.assertEqual(last(cp.stderr), "[raw_source] 파일이 없다 — docs/iv/none.md")

    def test_missing_path(self):
        fx = self.make()
        for cmd in ("first-cell", "place", "review-block"):
            cp = self.run_(fx, cmd, "--interview", "docs/iv/none.md")
            self.assertEqual(cp.returncode, 2, cmd)
            self.assertNotIn("raw-source:", cp.stdout + cp.stderr)
        cp = self.run_(fx, "locate", "--interview", "docs/iv/none.md")
        self.assertEqual((cp.returncode, last(cp.stdout)), (0, "raw-source: NO-FRAMING"))

    def test_absolute(self):
        fx = self.make()
        with tempfile.TemporaryDirectory() as other:
            cp = run_in(other, "locate", "--interview", fx["state"], "--absolute")
            self.assertEqual(cp.returncode, 0, cp.stderr)
            line = last(cp.stdout)
            self.assertTrue(line.startswith("raw-source: FOUND "), line)
            got = line[len("raw-source: FOUND "):]
            self.assertTrue(os.path.isabs(got), got)
            self.assertTrue(os.path.samefile(got, fx["framing"]))
            cp = run_in(other, "locate", "--interview", fx["state"])
            self.assertEqual((cp.returncode, last(cp.stdout)), (0, "raw-source: FOUND docs/iv/t-seed-interview.audit.md"))
        cp = self.run_(fx, "locate", "--seed", "docs/iv/t-seed-interview.md", "--absolute")
        self.assertEqual((cp.returncode, last(cp.stdout)),
                         (0, "raw-source: FOUND " + os.path.join(fx["repo"], "docs/iv/t-seed-interview.audit.md")))
        cp = self.run_(fx, "locate", "--seed", "docs/iv/t-seed-interview.md")
        self.assertEqual(last(cp.stdout), "raw-source: FOUND docs/iv/t-seed-interview.audit.md")
        fx = self.make(mode="no-framing")
        cp = self.run_(fx, "locate", "--interview", BRIEF, "--absolute")
        self.assertEqual((cp.returncode, cp.stdout), (0, "raw-source: NO-FRAMING\n"))

    def test_review_block(self):
        fx = self.make(decisions="\n".join([E1, E_EMPTY, H1]))
        cp = self.run_(fx, "review-block", "--interview", BRIEF)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        self.assertEqual(cp.stdout.splitlines(), [E1, H1])
        self.assertTrue(last(cp.stderr).startswith("raw-source: FOUND "), cp.stderr)
        cp = self.run_(fx, "review-block", "--interview", BRIEF, "--with-sections")
        self.assertEqual(cp.returncode, 0, cp.stderr)
        b1, b2 = RS.load_blocks(srl.read_audit_text(fx["framing"]))
        self.assertEqual(cp.stdout, b1 + "\n" + b2 + "\n\n" + E1 + "\n" + H1 + "\n")

    def test_review_block_empty(self):
        fx = self.make(decisions=E_EMPTY)
        cp = self.run_(fx, "review-block", "--interview", BRIEF)
        self.assertEqual((cp.returncode, cp.stdout), (0, ""))
        fx = self.make(mode="lost")
        cp = self.run_(fx, "review-block", "--interview", BRIEF, "--with-sections")
        self.assertEqual((cp.returncode, cp.stdout), (3, ""))
        self.assertTrue(last(cp.stderr).startswith("raw-source: LOST "))

    def test_review_block_tolerates_old_audit(self):
        fx = self.make()
        write_raw(fx["framing"], FX.audit_text(decisions=None))
        cp = self.run_(fx, "review-block", "--interview", BRIEF)
        self.assertEqual((cp.returncode, cp.stdout), (0, ""))
        cp = self.run_(fx, "review-block", "--interview", BRIEF, "--with-sections")
        b1, b2 = RS.load_blocks(srl.read_audit_text(fx["framing"]))
        self.assertEqual((cp.returncode, cp.stdout), (0, b1 + "\n" + b2 + "\n"))
        write_raw(fx["framing"], FX.audit_text(decisions="\n".join(
            ["아무 말이나 적은 줄", E1, '- 모양이 아닌 줄 · "따옴표" —', "(안내 괄호)", "없음"])))
        cp = self.run_(fx, "review-block", "--interview", BRIEF)
        self.assertEqual((cp.returncode, cp.stdout), (0, E1 + "\n"))


if __name__ == "__main__":
    unittest.main()
