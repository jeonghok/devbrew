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

PRE = "ed0da79f"   # #221 까지 합친 첫 병합 커밋 — 이 앞의 로드맵이 옮기기 전 정본이다
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


HEAD = "---\ntype: roadmap\nsource_brief: b.md\n---\n\n# r\n\n## 에픽\n\n"
TAIL = "## 결정 기록\n\n## 재분해 이력\n\n- 없음\n\n## 위험 번호표\n"
OLD_SCOPE = "- 범위: 한다 x 「말」 / 안 한다 y\n"
NEW_SCOPE = "- 범위:\n  - 한다: x 「말」\n  - 안 한다: y\n"


def blk(intent="- 의도: 의도\n", scope=OLD_SCOPE, extra="", head="### A1 — 가\n"):
    return (head + intent + scope + "- 의존: 없음\n- 브랜치: feature/a\n- 묶음: A1.md\n- 경로 예약: 없음\n"
            + extra + "\n")


def road(*parts):
    return HEAD + "".join(parts) + TAIL


class MigrateKeepsEveryOtherByte(unittest.TestCase):
    """블록의 범위 한 줄만 바뀌고 나머지는 글자 그대로이거나, 옮기지 않고 거절한다."""

    def check(self, old):
        new = W.migrated_text(old, lambda n: None)
        self.assertEqual(new, old.replace(OLD_SCOPE, NEW_SCOPE))
        self.assertNotEqual(new, old)
        self.assertEqual(W.migrated_text(new, lambda n: None), new)

    def test_prose_line_under_epics_section(self):
        self.check(road("에픽 절 머리 설명 한 줄.\n\n", blk()))

    def test_prose_line_inside_block(self):
        self.check(road(blk(extra="블록 안의 설명 줄 「말」\n")))

    def test_sub_item_intent_stays(self):
        self.check(road(blk(intent="- 의도:\n  - 하나\n  - 둘\n")))

    def test_flow_none_stays(self):
        self.check(road(blk(extra="- 흐름: 없음\n")))

    def test_two_do_items_stay_separate(self):
        two = "- 범위:\n  - 한다: a\n  - 한다: b\n  - 안 한다: c\n"
        old = road(blk(scope=two, head="### A0 — 영\n"), blk())
        new = W.migrated_text(old, lambda n: None)
        self.assertEqual(new, old.replace(OLD_SCOPE, NEW_SCOPE))
        self.assertIn(two, new)

    def test_already_new_is_no_change(self):
        old = road(blk(scope=NEW_SCOPE))
        self.assertEqual(W.migrated_text(old, lambda n: None), old)

    def test_unconvertible_scope_is_refused(self):
        for scope in ("- 범위: n\n", "- 범위: 한다 a / 안 한다 b / 안 한다 c\n"):
            with self.assertRaises(W.Refused):
                W.migrated_text(road(blk(scope=scope)), lambda n: None)


class LiveRoadmap(unittest.TestCase):
    """이 로드맵은 옮겨졌다 — 옛 꼴 블록 · 옛 꼴 이력이 없고, 옮기기 전 인용을 하나도 잃지 않았다."""

    def setUp(self):
        self.text = (REPO / RM).read_text(encoding="utf-8")

    def test_no_quote_lost_since_before_migration(self):
        lost = set(quotes(git_show(PRE + ":" + RM))) - set(quotes(self.text))
        self.assertEqual(lost, set())

    def test_each_history_entry_keeps_its_original_quotes_in_order(self):
        """옛 한 줄마다 그 줄의 「…」 들이 순서대로 같은 새 항목 안(바뀜 · 원문)에 있다 — 합쳐 세는 집합 대조가 못 보는 손실."""
        old = git_show(PRE + ":" + RM)
        old_body = old.split("## 재분해 이력\n", 1)[1].split("\n## ", 1)[0]
        old_lines = [l for l in old_body.splitlines() if l.startswith("- 20")]
        new_body = self.text.split("## 재분해 이력\n", 1)[1].split("\n## ", 1)[0]
        entries = ["### " + e for e in new_body.split("\n### ")[1:]]
        self.assertEqual(len(entries), len(old_lines))
        for line, entry in zip(old_lines, entries):
            seq = quotes(entry)
            at = 0
            for q in quotes(line):
                try:
                    at = seq.index(q, at) + 1
                except ValueError:
                    self.fail("%s: 옛 인용이 순서대로 있지 않다: %s" % (entry.splitlines()[0], q))

    def test_user_words_column_holds_only_quotes_or_none(self):
        entries, errors = parse_history(self.text)
        self.assertEqual(errors, [])
        for e in entries:
            self.assertTrue(bool(e["quotes"]) != bool(e["no_words"]), e["date"])

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
