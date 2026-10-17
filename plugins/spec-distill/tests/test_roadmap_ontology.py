#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""references/roadmap-ontology.md — 계층 넷 · 객체 표 · 링크 칸 이름의 실재(R5 AC10).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_roadmap_ontology.py
"""
from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path

PLUGIN = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PLUGIN / "scripts"))
from roadmap_model import FIELDS, section_body  # noqa: E402

DOC = PLUGIN / "references" / "roadmap-ontology.md"
SOURCES = ("roadmap_model.py", "roadmap_status.py", "check_bundle_coverage.py", "repo_defaults.py",
           "conductor_state.py", "roadmap_render.py")
LAYERS = ("컨트롤 플레인", "계획", "실행", "기록")
OBJECTS = ("로드맵", "에픽", "에픽 묶음", "설계문서", "산출물", "계획", "레포 설정", "브랜치", "커밋", "PR",
           "worktree · agent", "결정 기록 줄", "재분해 이력 항목", "번호 대조 행", "미룸 · 넘김 줄",
           "넘김 확인 줄", "판정", "구현 대조", "지휘 기록", "기계 상태", "리뷰 원장")
HEAD = ["객체", "층", "식별자", "속성", "링크(칸 · 키)", "주인"]
BACKTICK = re.compile(r"`([^`]+)`")


def rows(section: str) -> list:
    body = section_body(DOC.read_text(encoding="utf-8"), section) or ""
    lines = [l.strip() for l in body.splitlines() if l.strip().startswith("|")]
    return [[c.strip() for c in l[1:-1].split("|")] for l in lines]


def link_ok(token: str, corpus: str) -> bool:
    return token.rstrip(":") in FIELDS or token in corpus


class Ontology(unittest.TestCase):
    def setUp(self):
        self.corpus = "\n".join((PLUGIN / "scripts" / n).read_text(encoding="utf-8") for n in SOURCES)

    def test_four_layers(self):
        self.assertEqual([r[0] for r in rows("## 계층")[2:]], list(LAYERS))

    def test_object_table_shape(self):
        table = rows("## 객체")
        self.assertEqual(table[0], HEAD)
        self.assertGreaterEqual(len(table) - 2, 15)
        self.assertEqual([r[0] for r in table[2:]], list(OBJECTS))
        for r in table[2:]:
            self.assertEqual(len(r), len(HEAD), r)
            self.assertIn(r[1], LAYERS, r)

    def test_link_names_exist_in_parsers(self):
        missing = []
        for r in rows("## 객체")[2:]:
            for token in BACKTICK.findall(r[4]):
                if not link_ok(token, self.corpus):
                    missing.append("%s: %s" % (r[0], token))
        self.assertEqual(missing, [])

    def test_owner_scripts_exist(self):   # 주인 칸이 이름 붙인 스크립트는 실재한다
        text = DOC.read_text(encoding="utf-8")
        named = set(re.findall(r"`([a-z_]+\.py)`", text))
        self.assertTrue({"roadmap_model.py", "conductor_state.py", "control_plane.py",
                         "repo_defaults.py", "roadmap_status.py"} <= named)
        self.assertEqual([n for n in sorted(named) if not (PLUGIN / "scripts" / n).is_file()], [])

    def test_lock_catches_a_made_up_link(self):   # 양성 대조 — 없는 칸 이름은 걸린다
        self.assertFalse(link_ok("없는칸:", self.corpus))
        self.assertTrue(link_ok("묶음:", self.corpus))


if __name__ == "__main__":
    unittest.main()
