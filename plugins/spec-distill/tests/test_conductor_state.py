#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_state.py — 기계 상태 형식 · 원자 쓰기 · 표지 · 넘김 상태 계산(R5 AC43 · AC17).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_conductor_state.py
"""
from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import conductor_state as cs  # noqa: E402
import state_path  # noqa: E402

RM = "docs/superpowers/roadmaps/rm/roadmap.md"
SID, OTHER = "session-aaaa1111", "session-bbbb2222"


def sample():
    data = cs.empty()
    data["PR"].append({"브랜치": "feature/a", "번호": "#12", "상태": "열림", "확인한 때": "2026-10-17 10:00"})
    data["실행 원장"].append({"에픽": "R5", "계획": "docs/p.md", "원장": "/w/.superpowers/sdd/p/progress.md",
                           "읽은 줄": "3"})
    data["자원"].append({"종류": "worktree", "경로": "/w", "에픽": "R5", "용도": "구현", "만든 때": "2026-10-17"})
    data["기다리는 질문"].append({"에픽": "R5", "기대는 일": "구현", "질문": "범위 · 인터페이스를 어떻게 할까"})
    return data


class Format(unittest.TestCase):
    def test_round_trip(self):
        text = cs.render_machine(RM, sample())
        self.assertEqual(cs.parse_machine(text, RM), sample())

    def test_last_column_may_hold_separator_others_may_not(self):
        data = sample()
        data["자원"][0]["용도"] = "가 · 나"
        with self.assertRaises(cs.MachineError):
            cs.render_machine(RM, data)

    def test_broken_inputs_raise(self):
        good = cs.render_machine(RM, sample())
        broken = {
            "frontmatter 없음": good.split("---\n", 2)[2],
            "다른 로드맵": good.replace("roadmap: " + RM, "roadmap: other/roadmap.md"),
            "모르는 절": good + "\n## 모르는 절\n",
            "칸 수": good.replace("- feature/a · #12 · 열림 · 2026-10-17 10:00", "- feature/a · #12"),
            "PR 상태": good.replace("· 열림 ·", "· 열렸음 ·"),
            "PR 번호": good.replace("#12", "12"),
            "읽은 줄": good.replace("progress.md · 3", "progress.md · 셋"),
        }
        for name, text in broken.items():
            with self.assertRaises(cs.MachineError, msg=name):
                cs.parse_machine(text, RM)

    def test_machine_dir_uses_roadmap_folder(self):
        self.assertEqual(cs.machine_dir("/s", RM), Path("/s/conductor/rm"))
        for bad in ("roadmap.md", "a/../roadmap.md"):
            with self.assertRaises(cs.MachineError):
                cs.machine_dir("/s", bad)


class Storage(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.path = cs.machine_path(self.tmp, RM)

    def tearDown(self):
        shutil.rmtree(str(self.tmp))

    def test_missing_file_is_empty(self):
        self.assertEqual(cs.load(self.path, RM), cs.empty())

    def test_broken_file_is_not_read_as_empty(self):
        self.path.parent.mkdir(parents=True)
        self.path.write_text("깨진 글\n", encoding="utf-8")
        with self.assertRaises(cs.MachineError):
            cs.load(self.path, RM)

    def test_save_needs_the_marker_and_is_atomic(self):
        d = self.path.parent
        self.assertEqual(cs.acquire(d, SID), "acquired")
        self.assertEqual(cs.acquire(d, SID), "held")
        self.assertEqual(cs.acquire(d, OTHER), SID)
        cs.save(self.path, RM, sample(), SID)
        self.assertEqual(cs.load(self.path, RM), sample())
        before = self.path.read_bytes()
        with self.assertRaises(cs.MachineError):
            cs.save(self.path, RM, cs.empty(), OTHER)
        self.assertEqual(self.path.read_bytes(), before)
        self.assertEqual([p.name for p in d.iterdir() if p.name.startswith(".machine.")], [])

    def test_release_and_takeover(self):
        d = self.path.parent
        cs.acquire(d, SID)
        self.assertFalse(cs.release(d, OTHER))
        self.assertEqual(cs.holder(d), SID)
        self.assertEqual(cs.takeover(d, OTHER), SID)
        self.assertEqual(cs.holder(d), OTHER)
        self.assertTrue(cs.release(d, OTHER))
        self.assertIsNone(cs.holder(d))

    def test_save_without_marker_or_with_bad_session_is_refused(self):
        d = self.path.parent
        d.mkdir(parents=True)
        for sess in (SID, None, "bad id\nx"):
            with self.assertRaises(cs.MachineError, msg=repr(sess)):
                cs.save(self.path, RM, cs.empty(), sess)
            self.assertFalse(self.path.exists())
        with self.assertRaises(cs.MachineError):
            cs.takeover(d, "bad id\nx")
        with self.assertRaises(cs.MachineError):
            cs.release(d, None)
        self.assertFalse(cs.release(d, SID))

    def test_cell_edge_dot_is_refused(self):
        data = sample()
        data["자원"][0]["종류"] = "worktree ·"
        with self.assertRaises(cs.MachineError):
            cs.render_machine(RM, data)
        data = sample()
        data["실행 원장"][0]["읽은 줄"] = "³"
        with self.assertRaises(cs.MachineError):
            cs.render_machine(RM, data)

    def test_state_root_for_common(self):
        self.assertEqual(state_path.state_root_for_common(Path("/r/.git")), Path("/r/.claude/spec-distill"))


class Handoffs(unittest.TestCase):
    def test_five_states(self):
        rows = [("항목 가 · 나", "이유", "R2"), ("항목 둘", "이유", "R3"), ("항목 셋", "이유", "R4"),
                ("항목 넷", "이유", "#7"), ("항목 다섯", "이유", "없음")]
        records = {"R3": cs.confirm_line("R1", "항목 둘", "AC 보고 AC4")}
        stages = {"R1": "구현 끝", "R2": "설계 중", "R3": "머지됨", "R4": "머지됨"}
        got = {r["item"]: r["state"] for r in cs.handoff_rows([("R1", "s.md", rows)], stages, records)}
        self.assertEqual(got, {"항목 가 · 나": "열림", "항목 둘": "확인됨", "항목 셋": "처리됨",
                               "항목 넷": "이슈", "항목 다섯": "받는 곳 없음"})

    def test_confirm_key_ignores_other_giver(self):
        line = cs.confirm_line("R9", "항목", "근거")
        self.assertIn(("R9", cs.handoff_key("R9", "항목")), cs.confirmed_keys(line))
        self.assertNotIn(("R1", cs.handoff_key("R1", "항목")), cs.confirmed_keys(line))


class DocSections(unittest.TestCase):
    DOC = ("# d\n\n## 판정\n\n- Task 1: Ruling: 가 — 왜 — 비용\n\n```\n## 구현 대조 — p2.md\n```\n\n"
           "## 구현 대조 — docs/p1.md\n\n- 요약\n")

    def test_impl_done_is_per_plan(self):
        self.assertTrue(cs.impl_done(self.DOC, "docs/p1.md"))
        self.assertFalse(cs.impl_done(self.DOC, "docs/p2.md"))
        self.assertFalse(cs.impl_done(self.DOC, "p2.md"))   # 펜스 안 머리는 절이 아니다

    def test_rulings_archived(self):
        self.assertEqual(cs.rulings_archived(self.DOC), ["- Task 1: Ruling: 가 — 왜 — 비용"])
        self.assertIsNone(cs.rulings_archived("# 판정 절 없음\n"))

    def test_duplicate_heading_raises_and_prefix_is_not_a_match(self):
        with self.assertRaises(cs.FormatError):
            cs.rulings_archived("## 판정\n\n- a\n\n## 판정\n\n- b\n")
        self.assertIsNone(cs.rulings_archived("## 판정 근거\n\n- a\n"))

    def test_ledger_rulings(self):
        text = "# SDD ledger — plan: p\nTask 1: complete\nTask 2: Ruling: x — y — z\nFinal: Ruling: w\n"
        self.assertEqual(cs.ledger_rulings(text), ["Task 2: Ruling: x — y — z", "Final: Ruling: w"])


if __name__ == "__main__":
    unittest.main()
