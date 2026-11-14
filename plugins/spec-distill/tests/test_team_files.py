#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""team_files.py — 틀 일곱과 과제 파일(INTENT · sources)의 글(R1 AC4 · AC18).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_team_files.py
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "plugins" / "spec-distill" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import team_layout as L  # noqa: E402
import team_files as F  # noqa: E402
import roadmap_model as M  # noqa: E402


class Templates(unittest.TestCase):   # AC18 — 두 칸뿐, 문서의 성격을 설명하는 문장이 없다
    COMMON = ["- 받은 명령으로 시작 묶음을 첫 걸음에 돌리고, 첫 줄의 두 커밋을 결과 파일 머리에 옮긴다.",
              "- 받은 규칙은 쓰기 전에 지금도 맞는지 확인한다.",
              "- 시작 묶음의 `<커밋>:<경로>` 는 작업 폴더의 파일이 아니라 `git show <커밋>:<경로>` 로 읽는다."]

    def test_role_templates_have_two_sections_only(self):
        self.assertEqual(sorted(p.name for p in F.TEMPLATES.glob("role-*.md")), sorted("role-%s.md" % r for r in L.ROLES))
        for role in L.ROLES:
            lines = F.role_template(role).read_text(encoding="utf-8").splitlines()
            self.assertEqual([l for l in lines if l.startswith("#")], ["## 할 일", "## 하지 않을 일"], role)
            self.assertEqual(lines[0], "## 할 일", role)
            self.assertEqual([l for l in lines if l and not l.startswith("#") and not l.startswith("- ")], [], role)
            self.assertEqual(lines[2:5], self.COMMON, role)
            for word in ("알림", "도구 권한", "집행", "이 문서"):
                self.assertNotIn(word, "\n".join(lines), (role, word))

    def test_worker_lines_are_the_users_words(self):
        text = F.role_template("worker").read_text(encoding="utf-8")
        for line in ("- 과제마다 INTENT.md 부터", "- 설계안 승인 뒤에 코드", "- 실서비스 배포", "- 다른 폴더 파일 고치기", "- 승인 전 코딩"):
            self.assertIn(line + "\n", text)

    def test_no_file_named_like_auto_loaded_memory(self):
        self.assertEqual([p.name for p in F.TEMPLATES.rglob(L.ROLE_DOC)], [])

    def test_rules_empty_and_handbook_principle(self):
        self.assertEqual((F.TEMPLATES / L.RULES_FILE).read_text(encoding="utf-8"), "# RULES\n")
        self.assertIn("> 잘못 쌓인 맥락은 없는 것보다 나쁘다. 이 파일의 줄은 쓰기 전에 지금 확인하고, 틀렸으면 지운다.\n",
                      (F.TEMPLATES / L.HANDBOOK_FILE).read_text(encoding="utf-8"))


class Ranges(unittest.TestCase):
    def test_round_trip_and_hyphen_input(self):
        self.assertEqual(F.parse_ranges("23–57 · 75–87"), [(23, 57), (75, 87)])
        self.assertEqual(F.format_ranges(F.parse_ranges("23-57 · 9-9")), "23–57 · 9–9")

    def test_rejects(self):
        for bad in ("", "없음", "57–23", "0–3", "3", "a–b", "２–３", "1–2,4–5", "1–2 · ", "1–2–3", "-1–2"):
            self.assertRaises(ValueError, F.parse_ranges, bad)


class Intent(unittest.TestCase):
    T = (F.TEMPLATES / L.INTENT_FILE).read_text(encoding="utf-8")

    def epic(self):
        return F.render_intent(self.T, "R3", F.KIND_EPIC, "d/t/roadmap.md", F.goal_text("의도 글", "한다 가 · 나 / 안 한다 다"),
                               F.original_pointer([(23, 57), (75, 87)], "d/t/roadmap.md"), F.not_text("한다 가 · 나 / 안 한다 다"))

    def test_epic_header_and_sections(self):
        text = self.epic()
        self.assertTrue(text.startswith("---\ntype: job\njob: R3\nkind: epic\nroadmap: d/t/roadmap.md\nbranch:\npaths: []\n---\n\n## 목표\n\n"))
        s = F.intent_sections(text)
        self.assertEqual(list(s), list(F.SECTIONS))
        self.assertEqual(s["목표"], "의도 글\n\n- 범위: 가 · 나")
        self.assertEqual(s["하지 않을 것"], "- 다")
        self.assertEqual(s["결정 기록"], "")
        self.assertIn("- 범위: intent/original.md 23–57행 · 75–87행", s["지시 원문"])
        self.assertTrue(s["지시 원문"].startswith("전체 그림에서 이 과제의 자리 — "))
        self.assertEqual(F.intent_ranges(text), [(23, 57), (75, 87)])
        self.assertTrue(text.endswith("## 결정 기록\n"))

    def test_scope_without_the_two_halves(self):
        self.assertEqual((F.goal_text("의도", "자유 범위"), F.not_text("자유 범위")), ("의도\n\n- 범위: 자유 범위", "- 없음"))

    def test_task_original_is_byte_exact_even_with_heading_lines(self):   # AC7 · Review Focus 1 · 3
        for said in ("한 줄", "줄 하나\n## 하지 않을 것\n## 결정 기록\n- 결정 · 2026-01-01 · 「가짜」\n", "{{JOB}} 과 {{NOT}}\n---\n",
                     "CRLF 줄\r\n둘째\r\n", "끝 빈 줄 둘\n\n\n", "## 목표\n## 지시 원문\n"):
            text = F.render_intent(self.T, "fix-x", F.KIND_TASK, "d/t/roadmap.md", "목표 한 줄", said, "- 없음",
                                   branch="fix/x", paths=("a/b.py", "c.md"))
            s = F.intent_sections(text)
            self.assertEqual(s["지시 원문"], said, repr(said))
            self.assertEqual((s["목표"], s["하지 않을 것"], s["결정 기록"]), ("목표 한 줄", "- 없음", ""), repr(said))
            self.assertIn("\nbranch: fix/x\npaths: [a/b.py, c.md]\n---\n", text)
            self.assertEqual(F.intent_ranges(text), [])

    def test_decision_lines_survive(self):
        text = self.epic() + "\n- spec 승인 · 2026-11-20 · 「이대로」\n"
        self.assertEqual(F.intent_sections(text)["결정 기록"], "- spec 승인 · 2026-11-20 · 「이대로」")

    def test_broken_shapes(self):
        text = self.epic()
        for broken in (text.replace("## 하지 않을 것\n", "", 1), text.replace("## 목표\n", "## 목 표\n", 1),
                       text.replace("## 지시 원문\n\n", "## 지시 원문\n", 1)):
            self.assertRaises(F.FormatError, F.intent_sections, broken)

    def test_drift(self):
        text = self.epic()
        self.assertEqual(F.intent_drift(text, "의도 글", "한다 가 · 나 / 안 한다 다"), [])
        self.assertEqual(len(F.intent_drift(text, "다른 의도", "한다 가 · 나 / 안 한다 라")), 2)


class Sources(unittest.TestCase):
    def test_render_and_read_back(self):
        text = F.render_sources("R3", "셋째 에픽", ["C1", "OQ2", "S4"], {"제약": ["- 🗣 confirmed **C1** — 가"], "열린 질문": ["- OQ2 [열림] — 나"],
                                                                      "웹 근거": [], "기각 · 위험": []}, "없음", "R4 에 x")
        self.assertTrue(text.startswith("---\ntype: job-sources\njob: R3\nids: [C1, OQ2, S4]\n---\n\n# R3 — 셋째 에픽 · 번호 항목\n\n## 제약\n\n"))
        self.assertEqual(M.bundle_ids(text), ["C1", "OQ2", "S4"])
        self.assertEqual(F.sources_interface(text), ("없음", "R4 에 x"))
        self.assertIn("## 웹 근거\n\n- 없음\n", text)
        self.assertNotIn("사용자 원문", text)


if __name__ == "__main__":
    unittest.main()
