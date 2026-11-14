#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""team 형식의 사람이 읽는 형식 정본(references/team-files.md) · README · 판(R1 AC26 — 계획 1 몫).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_team_docs.py
"""
from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

PLUGIN = Path(__file__).resolve().parents[1]
SCRIPTS = PLUGIN / "scripts"
sys.path.insert(0, str(SCRIPTS))
import team_layout as L  # noqa: E402
import team_files as F  # noqa: E402
import roadmap_render as R  # noqa: E402

DOC = PLUGIN / "references" / "team-files.md"
README = PLUGIN / "README.md"


class TeamFilesDoc(unittest.TestCase):   # R1 AC26 — 계획 1 몫
    def test_sections_of_this_plan(self):
        heads = [l for l in DOC.read_text(encoding="utf-8").splitlines() if l.startswith("## ")]
        self.assertEqual(heads, ["## §1 팀 폴더", "## §2 과제 폴더와 INTENT.md", "## §3 원자료", "## §4 sources.md", "## §6 역할 문서"])

    def test_names_come_from_the_code(self):
        text = DOC.read_text(encoding="utf-8")
        for name in L.ROLES + (L.RULES_FILE, L.HANDBOOK_FILE, L.INTENT_FILE, L.SOURCES_FILE, L.ORIGINAL_FILE, L.REVIEW_FILE, L.STATUS_FILE,
                               "layout: team", "type: job", "type: job-sources", "kind: epic", "kind: task", R.TEAM_COLUMN) + F.SECTIONS:
            self.assertIn(name, text, name)
        self.assertIn("<!-- 출처: ", text)   # 구간 첫 줄의 머리

    def test_users_example_is_verbatim(self):   # 원문 대조 — INTENT.md 예시 「로그인 개선」
        text = DOC.read_text(encoding="utf-8")
        for line in ("예시) 로그인 개선", "목표 - 재설정 뒤 다시 로그인 하는 단계 없애기",
                     "지시 원문 - 재설정 뒤에 다시 로그인 하는 단계 없애고, 디자인 톤은 유지",
                     "하지 않을 것 - 로그인 화면 디자인 바꾸기 소셜 로그인 추가", "결정 기록 - 10/22 방향 1 승인 단계가 가장 적음"):
            self.assertIn("\n" + line + "\n", text)

    def test_notice_not_enforcement_lives_here_and_in_readme_only(self):   # D2.19
        sentence = "역할 문서는 알림이고 막는 것은 도구 권한이다"
        self.assertIn(sentence, DOC.read_text(encoding="utf-8"))
        self.assertIn(sentence, README.read_text(encoding="utf-8"))

    def test_one_plan_per_branch_and_exit_codes(self):
        text = DOC.read_text(encoding="utf-8")
        self.assertIn("브랜치 하나에 계획 하나", text)
        self.assertIn("종료 코드 4", text)


class Readme(unittest.TestCase):
    def test_team_layout_is_documented(self):
        text = README.read_text(encoding="utf-8")
        principles = text.split("## Principles Instantiated", 1)[1].split("\n## ", 1)[0]
        self.assertIn("team-files.md", principles)
        for name in ("--layout team", "team_layout.py check", "job new", "original --brief", "references/team-files.md"):
            self.assertIn(name, text, name)
        self.assertIn("`roadmap_write.py` 는 0 성공 · 1 쓰지 않음 · 2 사용법 오류 · 4 ", text)


class Version(unittest.TestCase):
    def test_bumped_with_changelog(self):
        version = json.loads((PLUGIN / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8"))["version"]
        self.assertGreaterEqual(tuple(int(x) for x in version.split(".")), (8, 14, 0))
        log = (PLUGIN / "CHANGELOG.md").read_text(encoding="utf-8")
        self.assertIn("## [%s] — " % version, log)
        entry = log.split("## [%s] — " % version, 1)[1].split("\n## [", 1)[0]
        for word in ("--layout team", "rules_budget", "handbook_budget", "job new", "종료 코드 4"):
            self.assertIn(word, entry, word)


if __name__ == "__main__":
    unittest.main()
