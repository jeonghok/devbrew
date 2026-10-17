#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_write.py migrate — 옛 블록을 새 형식으로, 인용을 잃지 않고(R5 AC4).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_roadmap_migrate.py
"""
from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "plugins" / "spec-distill" / "scripts"))
import roadmap_render as R  # noqa: E402
import roadmap_write as W  # noqa: E402
from roadmap_model import parse_history, parse_roadmap, quotes  # noqa: E402

PRE = "93be1042"
RM = "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md"


def git_show(rev_path: str) -> str:
    proc = subprocess.run(["git", "-C", str(REPO), "show", rev_path], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise AssertionError("git show %s 실패: %s" % (rev_path, proc.stderr.decode("utf-8", "replace")))
    return proc.stdout.decode("utf-8")


class MigrateText(unittest.TestCase):
    def test_old_blocks_become_new_with_same_quotes(self):
        old = git_show(PRE + ":" + RM)
        new = W.migrated_text(old, lambda n: git_show("%s:%s/%s" % (PRE, Path(RM).parent.as_posix(), n)))
        self.assertNotEqual(new, old)
        self.assertEqual(set(quotes(old)), set(quotes(new)))
        self.assertEqual(parse_roadmap(new)[4], [])
        self.assertIn("- 범위:\n  - 한다: ", new)

    def test_migrated_text_is_a_fixed_point(self):
        old = git_show(PRE + ":" + RM)
        read = lambda n: git_show("%s:%s/%s" % (PRE, Path(RM).parent.as_posix(), n))  # noqa: E731
        once = W.migrated_text(old, read)
        self.assertEqual(W.migrated_text(once, read), once)


class LiveRoadmap(unittest.TestCase):
    """이 로드맵은 옮겨졌다 — 옛 꼴 블록 · 옛 꼴 이력이 없고, 옮기기 전 인용을 하나도 잃지 않았다."""

    def setUp(self):
        self.text = (REPO / RM).read_text(encoding="utf-8")

    def test_no_quote_lost_since_before_migration(self):
        lost = set(quotes(git_show(PRE + ":" + RM))) - set(quotes(self.text))
        self.assertEqual(lost, set())

    def test_history_is_new_form(self):
        entries, errors = parse_history(self.text)
        self.assertEqual(errors, [])
        self.assertEqual([e["date"] for e in entries if e["form"] == "old"], [])

    def test_scopes_are_sub_items(self):
        _m, blocks, _r, _k, errors = parse_roadmap(self.text)
        self.assertEqual(errors, [])
        one_line = [b["id"] for b in blocks if isinstance(b["fields"].get("범위"), str)
                    and R.SCOPE_RE.fullmatch(b["fields"]["범위"])]
        self.assertEqual(one_line, [])


if __name__ == "__main__":
    unittest.main()
