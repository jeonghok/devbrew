#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""team_rules.py — 규칙 줄의 읽는 법 · 형식 · 예산 · 같은 규칙 글 · 승격 후보(R1 AC19 · AC20 · AC26).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_team_rules.py
"""
from __future__ import annotations

import ast
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "plugins" / "spec-distill" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import team_rules as TR  # noqa: E402

GOOD = ("- [테스트] 고친 곳엔 테스트 먼저 · 조건: 역할=worker, 단계=implement"
        " · 출처: R3 결정 기록 2026-11-20 · 확인: 테스트 명령을 돌려 본다")   # 설계 §7 의 예시 줄 그대로


class Parse(unittest.TestCase):
    def one(self, line, handbook=False):
        rules = TR.parse_rules(line + "\n", handbook=handbook)
        self.assertEqual(len(rules), 1, line)
        return rules[0]

    def test_the_design_example(self):
        r = TR.parse_rules("# RULES\n\n" + GOOD + "\n")[0]
        self.assertEqual((r.line_no, r.tag, r.text), (3, "테스트", "고친 곳엔 테스트 먼저"))
        self.assertEqual(r.conds, {"역할": ("worker",), "단계": ("implement",)})
        self.assertEqual((r.sources, r.confirm, r.counter, r.problems),
                         (("R3 결정 기록 2026-11-20",), "테스트 명령을 돌려 본다", None, ()))
        self.assertEqual(TR.head_of(r), "[테스트] 고친 곳엔 테스트 먼저")

    def test_only_dash_bracket_lines_are_rules(self):
        text = "# RULES\n\n> 머리말\n- 산문 불릿\n-[붙은] 것\n  - [들여쓴] 것 · 출처: a · 확인: b\n" + GOOD + "\n"
        self.assertEqual([r.line_no for r in TR.parse_rules(text)], [7])

    def test_separator_and_marker_words_inside_the_text(self):   # Review Focus 1
        r = self.one("- [문서] 목차 · 앵커를 함께 고친다 · 출처: R1 결정 기록 | R2 결정 기록 · 확인: 목차 · 앵커를 눈으로 본다")
        self.assertEqual((r.text, r.sources, r.confirm, r.problems),
                         ("목차 · 앵커를 함께 고친다", ("R1 결정 기록", "R2 결정 기록"), "목차 · 앵커를 눈으로 본다", ()))
        r = self.one("- [보고] 글 가운데 출처: 라는 낱말 · 출처: a · 확인: b")
        self.assertEqual((r.text, r.problems), ("글 가운데 출처: 라는 낱말", ()))

    def test_conditions(self):
        r = self.one("- [폴더] 남의 폴더 고치지 않기 · 조건: 역할=worker|writer, 경로=plugins/**/*.py · 출처: a · 확인: b")
        self.assertEqual((r.conds, r.problems), ({"역할": ("worker", "writer"), "경로": ("plugins/**/*.py",)}, ()))

    def test_problems(self):
        for line, handbook, want in (
                ("- [] 글 · 출처: a · 확인: b", False, TR.BAD_TAG),
                ("- [태그 글 · 출처: a · 확인: b", False, TR.BAD_TAG),
                ("- [태그] · 출처: a · 확인: b", False, TR.NO_TEXT),
                ("- [태그] 글 · 확인: b", False, TR.MISSING % "출처:"),
                ("- [태그] 글 · 출처: a", False, TR.MISSING % "확인:"),
                ("- [태그] 글 · 출처:  · 확인: b", False, TR.MISSING % "출처:"),
                ("- [태그] 글 · 출처: a · 확인: b", True, TR.MISSING % "반례 확인:"),
                ("- [태그] 글 · 출처: a · 출처: c · 확인: b", False, TR.TWICE % "출처:"),
                ("- [태그] 글 · 조건: 팀=x · 출처: a · 확인: b", False, TR.BAD_KEY % "팀"),
                ("- [태그] 글 · 조건: 역할 · 출처: a · 확인: b", False, TR.BAD_COND % "역할"),
                ("- [태그] 글 · 조건: 경로= · 출처: a · 확인: b", False, TR.BAD_COND % "경로="),
                ("- [태그] 글 · 조건: 역할=reviewer · 출처: a · 확인: b", False, TR.BAD_VALUE % ("역할", "reviewer")),
                ("- [태그] 글 · 조건: 단계=deploy · 출처: a · 확인: b", False, TR.BAD_VALUE % ("단계", "deploy")),
                ("- [태그] 글 · 조건: 역할=worker|boss · 출처: a · 확인: b", False, TR.BAD_VALUE % ("역할", "boss")),
        ):
            self.assertEqual(self.one(line, handbook).problems[:1], (want,), line)
        ok = self.one("- [태그] 글 · 출처: a · 확인: b · 반례 확인: 2026-11-20 없었다", True)
        self.assertEqual((ok.problems, ok.counter), ((), "2026-11-20 없었다"))
        self.assertEqual(self.one("- [태그] 글 · 출처: a · 확인: b · 반례 확인: c").problems, ())   # 팀 규칙 줄에도 있어도 된다

    def test_repeated_key_and_empty_condition_are_not_errors(self):
        r = self.one("- [태그] 글 · 조건: 역할=worker, 역할=writer · 출처: a · 확인: b")
        self.assertEqual((r.problems, r.conds), ((), {"역할": ("worker", "writer")}))
        r = self.one("- [태그] 글 · 조건:  · 출처: a · 확인: b")
        self.assertEqual((r.problems, r.conds), ((), {}))
        r = self.one("- [태그] 글 · 조건: 역할=boss, 역할=worker · 출처: a · 확인: b")
        self.assertEqual(r.problems, (TR.BAD_VALUE % ("역할", "boss"),))

    def test_crlf(self):   # Review Focus 2
        self.assertEqual(TR.parse_rules(GOOD + "\r\n")[0].confirm, "테스트 명령을 돌려 본다")


class Files(unittest.TestCase):
    def check(self, rules, handbook, rb=8192, hb=16384):
        return TR.check_files("t/R", rules, "H", handbook, rb, hb)

    def test_passes(self):
        self.assertEqual(self.check(("# RULES\n" + GOOD + "\n").encode("utf-8"), b"# HANDBOOK\n"), [])

    def test_budget_edge(self):   # 설계 Verification Plan — 한 바이트 넘기기
        body = ("# RULES\n" + GOOD + "\n").encode("utf-8")
        self.assertEqual(self.check(body, b"", rb=len(body)), [])
        got = self.check(body, b"", rb=len(body) - 1)
        self.assertEqual(len(got), 1)
        for part in ("t/R: 예산 초과", "%d바이트" % len(body), "rules_budget", "먼저 지우거나 승격하라"):
            self.assertIn(part, got[0])

    def test_same_text_across_files_and_within_one(self):
        other = "- [다른 태그] 고친 곳엔 테스트 먼저 · 출처: x · 확인: y · 반례 확인: z\n".encode("utf-8")
        got = self.check((GOOD + "\n").encode("utf-8"), other)
        self.assertEqual(len(got), 1)
        self.assertIn("t/R:1", got[0])
        self.assertIn("H:1", got[0])
        twice = (GOOD + "\n" + GOOD.replace("[테스트]", "[또]") + "\n").encode("utf-8")
        self.assertEqual(len(self.check(twice, b"")), 1)   # U12 가 나 면 이 기대값은 0 이다

    def test_missing_files(self):
        self.assertEqual(len(self.check(None, b"")), 1)    # 팀 규칙 파일이 없다 — 어긋남
        self.assertEqual(self.check(b"# RULES\n", None), [])   # 공통 규칙 파일이 없다 — 알림은 명령이 낸다

    def test_bad_bytes_and_bom_do_not_crash(self):   # Review Focus 2
        self.assertTrue(self.check(b"- [\xff] x \xc2\xb7 \n", b""))
        self.assertEqual(self.check(b"\xef\xbb\xbf# RULES\n", b""), [])   # BOM 뒤의 제목 줄은 규칙 줄이 아니다
        # BOM 바로 뒤의 첫 줄도 규칙 줄로 읽는다 — 출처 · 확인이 빠진 줄이면 어긋남이 나고, 맞는 줄이면 규칙 하나다
        self.assertTrue(self.check("\ufeff- [태그] 글\n".encode("utf-8"), b""))
        self.assertEqual([(r.line_no, r.tag, r.problems) for r in TR.parse_rules("\ufeff" + GOOD + "\n")], [(1, "테스트", ())])


_FS_ATTRS = frozenset(("write_text", "write_bytes", "mkdir", "makedirs", "touch", "unlink", "rmdir", "rename", "rmtree",
                       "symlink_to", "hardlink_to", "chmod", "truncate"))
_OS_ONLY = frozenset(("replace", "remove", "symlink", "link", "system", "popen"))
_NO_IMPORT = frozenset(("subprocess", "shutil", "tempfile"))


def side_effects(source: str) -> list:
    """소스에서 파일을 쓰거나 지우는 부름 · 프로세스를 띄우는 모듈 import 를 찾는다(표준 출력 · 표준 오류 쓰기는 뺀다)."""
    found = []
    for node in ast.walk(ast.parse(source)):
        if isinstance(node, ast.Import):
            found += ["import " + a.name for a in node.names if a.name.split(".")[0] in _NO_IMPORT]
        elif isinstance(node, ast.ImportFrom) and (node.module or "").split(".")[0] in _NO_IMPORT:
            found.append("from " + node.module)
        elif isinstance(node, ast.Call):
            f = node.func
            name = f.id if isinstance(f, ast.Name) else f.attr if isinstance(f, ast.Attribute) else ""
            if name == "open":
                modes = [a.value for a in node.args + [k.value for k in node.keywords if k.arg == "mode"]
                         if isinstance(a, ast.Constant) and isinstance(a.value, str) and set(a.value) <= set("rwxabt+")]
                if any(set(m) & set("wxa+") for m in modes):
                    found.append("open(%s)" % modes)
            elif isinstance(f, ast.Attribute) and (name in _FS_ATTRS or (name in _OS_ONLY and isinstance(f.value, ast.Name)
                                                                      and f.value.id == "os")):
                found.append(name)
            elif isinstance(f, ast.Attribute) and name in ("write", "writelines"):
                target = f.value
                to_std = (isinstance(target, ast.Attribute) and target.attr in ("stdout", "stderr")
                          and isinstance(target.value, ast.Name) and target.value.id == "sys")
                if not to_std:
                    found.append(name)
    return found


class ReadOnly(unittest.TestCase):   # 새 스크립트 둘은 파일을 쓰지 않고 git 은 roadmap_status.Git 으로만 부른다
    def test_new_scripts_have_no_side_effects(self):
        for name in ("team_rules.py", "start_bundle.py"):
            source = (SCRIPTS / name).read_text(encoding="utf-8")
            self.assertIn("roadmap_status", source, name)   # 읽은 것이 그 스크립트다(빈 글이 아니다)
            self.assertEqual(side_effects(source), [], name)

    def test_detector_has_teeth(self):   # 양성 대조 — 찾아야 할 꼴마다 하나, 찾지 말아야 할 꼴도
        for bad in ("import subprocess", "import subprocess as sp", "from subprocess import run", "import shutil",
                    "open(p, 'w')", "open(p, mode='a')", "open(p, 'r+b')", "Path(p).write_text(x)", "p.write_bytes(b)",
                    "os.replace(a, b)", "os.remove(p)", "os.makedirs(d)", "fh.write(x)", "os.system('x')"):
            self.assertTrue(side_effects(bad), bad)
        for fine in ("open(p, 'rb')", "open(p)", "sys.stdout.write(t)", "sys.stderr.write(t)", "s.replace('a', 'b')",
                     "names.remove(x)", "import os"):
            self.assertEqual(side_effects(fine), [], fine)


class Candidates(unittest.TestCase):   # AC20
    def test_two_or_more_sources(self):
        text = GOOD + "\n- [문서] 바꾼 건 CHANGELOG에 · 출처: R1 결정 기록 | R4 결정 기록 · 확인: CHANGELOG 를 본다\n"
        self.assertEqual([r.tag for r in TR.candidates(TR.parse_rules(text))], ["문서"])


if __name__ == "__main__":
    unittest.main()
