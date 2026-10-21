#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""references/roadmap-ontology.md — 계층 넷 · 객체 표 · 링크 이름 · 주인의 실재(R5 AC10).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_roadmap_ontology.py
"""
from __future__ import annotations

import ast
import re
import sys
import unittest
from pathlib import Path

PLUGIN = Path(__file__).resolve().parent.parent
SCRIPTS = PLUGIN / "scripts"
sys.path.insert(0, str(SCRIPTS))
from roadmap_model import FIELDS, FORBIDDEN, REQUIRED, section_body  # noqa: E402
from roadmap_render import BUNDLE_FORMAT  # noqa: E402
from conductor_state import COLUMNS  # noqa: E402
from repo_defaults import COUNT_KEYS, DIR_KEYS, TEXT_KEYS  # noqa: E402

DOC = PLUGIN / "references" / "roadmap-ontology.md"
SOURCES = ("roadmap_model.py", "roadmap_status.py", "check_bundle_coverage.py", "repo_defaults.py",
           "conductor_state.py", "roadmap_render.py")
LAYERS = ("컨트롤 플레인", "계획", "실행", "기록")
OBJECTS = ("로드맵", "에픽", "에픽 묶음", "설계문서", "산출물", "계획", "레포 설정", "브랜치", "커밋", "PR",
           "worktree · agent", "작업", "결정 기록 줄", "재분해 이력 항목", "번호 대조 행", "미룸 · 넘김 줄",
           "넘김 확인 줄", "판정", "구현 대조", "지휘 기록", "기계 상태", "리뷰 원장")
HEAD = ["객체", "층", "식별자", "속성", "링크(칸 · 키)", "주인"]
BACKTICK = re.compile(r"`([^`]+)`")
# 객체 → 주인 칸이 이름 붙여야 하는 (스크립트, 그 안에 정의된 기호). 기호는 코드에 실재해야 한다.
PINS = {
    "에픽": (("roadmap_model.py", "parse_roadmap"),),
    "에픽 묶음": (("roadmap_write.py", "cmd_create"), ("roadmap_render.py", "render_bundle")),
    "레포 설정": (("repo_defaults.py", "resolve"),),
    "브랜치": (("roadmap_status.py", "progress"),),
    "번호 대조 행": (("check_bundle_coverage.py", "table_rows"),),
    "미룸 · 넘김 줄": (("roadmap_model.py", "handoff_rows"),),
    "넘김 확인 줄": (("conductor_state.py", "confirm_line", "쓰기"), ("roadmap_model.py", "CONFIRM_RE", "읽기")),
    "기계 상태": (("conductor_state.py", "parse_machine"), ("control_plane.py", "overlay")),
}
ALLOW_LINK = ("#<n>", "- 넘김 확인", "받는 곳", "받듦", "Spec:", "**Spec:**")   # 코드 글에 그대로 있어야 한다
ALLOW_SOURCE = ("PR 의 head", "문서 경로")


def rows(section: str) -> list:
    body = section_body(DOC.read_text(encoding="utf-8"), section) or ""
    lines = [l.strip() for l in body.splitlines() if l.strip().startswith("|")]
    return [[c.strip() for c in l[1:-1].split("|")] for l in lines]


def frontmatter_keys() -> set:
    block = BUNDLE_FORMAT.split("---\n")[1]
    return {l.split(":")[0] for l in block.splitlines() if ":" in l}


KEYS = frontmatter_keys() | set(DIR_KEYS) | set(TEXT_KEYS) | set(COUNT_KEYS) | {"source_brief", "source_interview", "roadmap"}


def link_ok(token: str, corpus: str) -> bool:
    """링크 토큰을 종류별로 코드에서 뽑은 집합과 맞춘다 — 부분 문자열로 맞추지 않는다."""
    if token in ALLOW_LINK:
        return token in corpus
    if token.endswith(":"):
        return token[:-1] in FIELDS
    if token.startswith("## "):
        return token in corpus
    return token in COLUMNS or token in KEYS


def _target_names(target) -> list:
    if isinstance(target, ast.Name):
        return [target.id]
    if isinstance(target, (ast.Tuple, ast.List)):
        return [n for t in target.elts for n in _target_names(t)]
    return []


def defined(name: str, text: str) -> bool:
    """최상위 def · 대입(주석 달린 것 · 튜플 풀기 포함)이 이름을 정의한다. import 재수출은 정의가 아니다."""
    for node in ast.parse(text).body:
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)) and node.name == name:
            return True
        if isinstance(node, ast.Assign) and any(name in _target_names(t) for t in node.targets):
            return True
        if isinstance(node, ast.AnnAssign) and name in _target_names(node.target):
            return True
    return False


class Ontology(unittest.TestCase):
    def setUp(self):
        self.corpus = "\n".join((SCRIPTS / n).read_text(encoding="utf-8") for n in SOURCES)

    def test_four_layers(self):
        self.assertEqual([r[0] for r in rows("## 계층")[2:]], list(LAYERS))

    def test_object_table_shape(self):
        table = rows("## 객체")
        self.assertEqual(table[0], HEAD)
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

    def test_link_source_is_backticked(self):
        bad = []
        for r in rows("## 객체")[2:]:
            for seg in r[4].split(" · "):
                m = re.search(r"[→←]", seg)
                src = (seg[:m.start()] if m else seg).strip()
                if src in ALLOW_SOURCE:
                    continue
                if not (src.startswith("`") and src.endswith("`") and src.count("`") == 2):
                    bad.append("%s: %s" % (r[0], src))
        self.assertEqual(bad, [])

    def test_owner_symbols_are_defined_in_named_owner(self):
        table = {r[0]: r for r in rows("## 객체")[2:]}
        problems = []
        for obj, pairs in PINS.items():
            for script, sym, *role in pairs:
                if "`%s`" % script not in table[obj][5]:
                    problems.append("%s: 주인 칸에 %s 없음" % (obj, script))
                if role and "%s `%s`" % (role[0], script) not in table[obj][5]:
                    problems.append("%s: 주인 칸에 「%s `%s`」 없음" % (obj, role[0], script))
                text = (SCRIPTS / script).read_text(encoding="utf-8")
                if not defined(sym, text):
                    problems.append("%s: %s 에 %s 정의 없음" % (obj, script, sym))
        self.assertEqual(problems, [])

    def test_every_script_named_exists(self):
        named = set(re.findall(r"`([a-z_]+\.py)`", DOC.read_text(encoding="utf-8")))
        self.assertEqual([n for n in sorted(named) if not (SCRIPTS / n).is_file()], [])

    def test_epic_row_names_every_field_and_kind_rule(self):
        epic = next(r for r in rows("## 객체")[2:] if r[0] == "에픽")
        cell = epic[3]
        listed = cell.split("칸:")[1].split(".")[0].split(" · ")
        self.assertEqual(sorted(x.strip() for x in listed), sorted(FIELDS))
        self.assertTrue(REQUIRED and FORBIDDEN)
        for name in ("REQUIRED", "FORBIDDEN"):
            self.assertIn("`%s`" % name, cell)

    def test_state_folder_is_named_by_constant_not_literal(self):
        text = DOC.read_text(encoding="utf-8")
        self.assertIn("`repo_defaults.CONDUCTOR_DIR`", text)
        self.assertTrue(defined("CONDUCTOR_DIR", (SCRIPTS / "repo_defaults.py").read_text(encoding="utf-8")))
        self.assertNotIn("/conductor/", text)

    def test_lock_catches_made_up_and_substring_links(self):   # 양성 대조
        self.assertFalse(link_ok("없는칸:", self.corpus))
        self.assertTrue(link_ok("묶음:", self.corpus))
        self.assertFalse(link_ok("id", self.corpus))      # `ids` 의 부분 문자열은 키가 아니다
        self.assertTrue(link_ok("ids", self.corpus))
        self.assertFalse(link_ok("## 없는 절", self.corpus))


if __name__ == "__main__":
    unittest.main()
