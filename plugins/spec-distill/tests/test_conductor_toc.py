#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_toc.py — 차례의 걸음 표 파서."""
from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS))
import conductor_toc as T  # noqa: E402

HEADER = "| 걸음 | 들어서는 때 | 지시서 | 함께 읽는 것 |\n|---|---|---|---|\n"
WHENS = ["부를 때마다", "단계: 인터뷰", "단계: 준비 · 설계 중 · 일부 머지", "단계: 계획 중", "단계: 구현 중", "단계: 머지됨 · 끝남", "에픽이 막혔을 때"]
NAMES = ["맞추기", "묻기", "다음 일 고르기와 보내기", "계획 맞이", "구현 맞이", "머지 뒤", "닫기"]


def toc_text(rows=None, extras=None, manual=None):
    rows = rows if rows is not None else range(1, 8)
    lines = ["# 차례", "", "### 걸음 표", "", HEADER.rstrip("\n")]
    for n in rows:
        if isinstance(n, tuple):
            n, guide = n
        else:
            guide = "`<SD>/references/conducting-step-%d.md`" % n
        lines.append("| %d %s | %s | %s | — |" % (n, NAMES[n - 1], WHENS[n - 1], guide))
    lines += ["", "### 걸음에 달리지 않은 지시서", ""]
    for e in (extras if extras is not None else ["- 이어 받을 때 — `<SD>/references/conducting-resume.md`"]):
        lines.append(e)
    lines += ["", "## 손으로 따르는 절차", ""]
    lines.append(manual if manual is not None else "손으로 할 때는 `<SD>/references/conducting-manual.md` 를 따른다.")
    return "\n".join(lines) + "\n"


class ParseTests(unittest.TestCase):
    def test_parse_reads_seven_steps(self):
        toc = T.parse(toc_text())
        self.assertEqual([s.number for s in toc.steps], [1, 2, 3, 4, 5, 6, 7])
        self.assertEqual(toc.steps[2].stages, ("준비", "설계 중", "일부 머지"))
        self.assertEqual(toc.steps[5].stages, ("머지됨", "끝남"))
        self.assertEqual(toc.steps[0].stages, ())
        self.assertEqual(toc.steps[2].guide, "<SD>/references/conducting-step-3.md")
        self.assertEqual(toc.extras[0].guide, "<SD>/references/conducting-resume.md")
        self.assertEqual(toc.manual, "<SD>/references/conducting-manual.md")

    def test_step_for_exact_and_suffixed(self):
        toc = T.parse(toc_text())
        self.assertEqual(T.step_for(toc, "설계 중").number, 3)
        self.assertEqual(T.step_for(toc, "일부 머지 1/2").number, 3)
        self.assertEqual(T.step_for(toc, "머지됨").number, 6)
        self.assertIsNone(T.step_for(toc, "일부 머지됨"))
        self.assertIsNone(T.step_for(toc, "대기"))

    def _rejects(self, text, *needles):
        with self.assertRaises(T.TocError) as cm:
            T.parse(text)
        for n in needles:
            self.assertIn(n, str(cm.exception))
        self.assertNotIn("\n", str(cm.exception))

    def test_parse_rejects_missing_row(self):
        self._rejects(toc_text(rows=[1, 2, 3, 4, 5, 6]), "7")

    def test_parse_rejects_duplicate_stage(self):
        text = toc_text().replace("단계: 계획 중", "단계: 계획 중 · 준비")
        self._rejects(text, "준비")

    def test_parse_rejects_bad_path(self):
        text = toc_text(rows=[1, 2, (3, "`references/x.md`"), 4, 5, 6, 7])
        self._rejects(text, "3", "references/x.md")

    def test_parse_rejects_two_manual_paths(self):
        manual = "`<SD>/references/conducting-manual.md` 와 `<SD>/references/conducting-other.md`"
        self._rejects(toc_text(manual=manual), "conducting-manual.md", "conducting-other.md")

    def test_parse_rejects_repeated_path(self):
        extras = ["- 겹침 — `<SD>/references/conducting-step-2.md`"]
        self._rejects(toc_text(extras=extras), "conducting-step-2.md")

    def test_named_files_order(self):
        toc = T.parse(toc_text())
        want = ["<SD>/references/conducting-step-%d.md" % n for n in range(1, 8)]
        want += ["<SD>/references/conducting-resume.md", "<SD>/references/conducting-manual.md"]
        self.assertEqual(T.named_files(toc), want)

    def test_resolve_accepts_only_sd_form(self):
        root = Path("/p")
        self.assertEqual(T.resolve(root, "<SD>/references/a-1.md"), root / "references" / "a-1.md")
        for bad in ("references/a.md", "<SD>/references/../a.md", "<SD>/references/A.md", "<SD>/x/a.md"):
            with self.assertRaises(T.TocError):
                T.resolve(root, bad)


class CliTests(unittest.TestCase):
    def _run(self, root, *args):
        p = subprocess.run([sys.executable, str(SCRIPTS / "conductor_toc.py"), *args, "--plugin-root", str(root)],
                           capture_output=True, text=True, encoding="utf-8")
        return p.returncode, p.stdout, p.stderr

    def test_cli_files_and_step(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td).resolve()
            refs = root / "references"
            refs.mkdir()
            (refs / "conducting.md").write_text(toc_text(), encoding="utf-8")
            toc = T.parse(toc_text())
            for sd in T.named_files(toc):
                (root / sd.replace("<SD>/", "")).write_text("x\n", encoding="utf-8")
            rc, out, _ = self._run(root, "files")
            self.assertEqual(rc, 0)
            lines = out.splitlines()
            self.assertEqual(lines[0], str(refs / "conducting.md"))
            self.assertEqual(len(lines), 10)
            rc, out, _ = self._run(root, "files", "--kind", "manual")
            self.assertEqual(out.splitlines(), [str(refs / "conducting-manual.md")])
            rc, out, _ = self._run(root, "files", "--kind", "step")
            self.assertEqual(len(out.splitlines()), 7)
            rc, out, _ = self._run(root, "step", "--stage", "준비")
            self.assertEqual(rc, 0)
            cols = out.rstrip("\n").split("\t")
            self.assertEqual(cols[0], "3")
            self.assertEqual(cols[2], str(refs / "conducting-step-3.md"))
            rc, out, err = self._run(root, "step", "--stage", "대기")
            self.assertEqual(rc, 1)
            self.assertIn("걸음 없음", out + err)
            (refs / "conducting-step-4.md").unlink()
            rc, out, err = self._run(root, "files")
            self.assertEqual(rc, 3)
            self.assertIn("지시서가 없다", out + err)
            self.assertIn("[spec-distill] 차례를 읽지 못했다", out + err)


    def test_load_non_utf8_is_toc_error(self):   # 읽지 못한 차례는 TocError — 명령줄 rc 3, 맞추기 명령은 죽지 않는다
        with tempfile.TemporaryDirectory() as td:
            root = Path(td).resolve()
            (root / "references").mkdir()
            (root / "references" / "conducting.md").write_bytes(toc_text().encode("utf-8") + b"\xff\xfe\n")
            with self.assertRaises(T.TocError) as cm:
                T.load(root)
            self.assertIn("UTF-8", str(cm.exception))
            rc, out, err = self._run(root, "files")
            self.assertEqual(rc, 3)
            self.assertIn("[spec-distill] 차례를 읽지 못했다", out + err)


if __name__ == "__main__":
    unittest.main()
