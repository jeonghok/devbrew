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
OID_A, OID_B = "a" * 40, "0123456789abcdef0123456789abcdef01234567"


def pr_row(**over):
    row = {"브랜치": "feature/a", "번호": "#12", "상태": "열림", "확인한 때": "2026-10-17 10:00", "headRefOid": OID_A,
           "교차 레포": "아니오", "baseRefName": "trunk", "mergeCommit": "-", "쓴 세션": SID}
    row.update(over)
    return row


def sample():
    data = cs.empty()
    data["PR"].append(pr_row())
    data["PR"].append(pr_row(번호="#13", 상태="머지됨", mergeCommit=OID_B, **{"교차 레포": "예"}))
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
            "칸 수": good.replace("- feature/a · #12 · 열림 · 2026-10-17 10:00 · " + OID_A, "- feature/a · #12"),
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


class PrCache(unittest.TestCase):
    """PR 캐시 아홉 칸(R8 계획 2 Task 2) — 옛 판 4칸 줄은 고치는 명령과 함께 멈추고, --reset 만 PR 절을 건너뛴다."""
    OLD = "- feature/a · #12 · 열림 · 2026-10-17 10:00"

    def test_nine_columns_round_trip(self):
        self.assertEqual(cs.COLUMNS["PR"], ("브랜치", "번호", "상태", "확인한 때", "headRefOid", "교차 레포",
                                           "baseRefName", "mergeCommit", "쓴 세션"))
        text = cs.render_machine(RM, sample())
        self.assertIn("- feature/a · #13 · 머지됨 · 2026-10-17 10:00 · %s · 예 · trunk · %s · %s" % (OID_A, OID_B, SID),
                      text)
        self.assertEqual(cs.parse_machine(text, RM)["PR"], sample()["PR"])

    def old_text(self):
        good = cs.render_machine(RM, sample())
        head, _sep, rest = good.partition("## PR\n\n")
        return head + "## PR\n\n" + self.OLD + "\n" + rest.split("\n\n", 1)[1]

    def test_four_column_row_names_the_reset_command(self):
        with self.assertRaises(cs.MachineError) as cm:
            cs.parse_machine(self.old_text(), RM)
        msg = str(cm.exception)
        self.assertIn("옛 판이 쓴 PR 캐시 줄이다(칸 4개)", msg)
        self.assertIn("ledger pr-refresh --roadmap <로드맵> --session <세션> --reset 으로 다시 채운다", msg)
        self.assertRegex(msg, r"^\d+줄: ")

    def test_skip_reads_past_four_column_rows(self):
        data = cs.parse_machine(self.old_text(), RM, skip=("PR",))
        self.assertEqual(data["PR"], [])
        self.assertEqual(data["자원"], sample()["자원"])
        tmp = Path(tempfile.mkdtemp())
        try:
            path = cs.machine_path(tmp, RM)
            path.parent.mkdir(parents=True)
            path.write_text(self.old_text(), encoding="utf-8")
            self.assertEqual(cs.load(path, RM, skip=("PR",))["PR"], [])
            with self.assertRaises(cs.MachineError):
                cs.load(path, RM)
        finally:
            shutil.rmtree(str(tmp))

    def test_cell_checks(self):
        bad = {
            "교차 레포 몰라": {"교차 레포": "몰라"},
            "headRefOid 짧음": {"headRefOid": "abc"},
            "headRefOid 대문자": {"headRefOid": "A" * 40},
            "mergeCommit 짧음": {"mergeCommit": "def"},
            "상태": {"상태": "OPEN"},
        }
        for name, over in bad.items():
            data = cs.empty()
            data["PR"].append(pr_row(**over))
            with self.assertRaises(cs.MachineError, msg=name):
                cs.render_machine(RM, data)
            text = cs.render_machine(RM, cs.empty()).replace("## PR\n\n", "## PR\n\n- " + " · ".join(
                pr_row(**over)[c] for c in cs.COLUMNS["PR"]) + "\n")
            with self.assertRaises(cs.MachineError, msg=name + " (읽기)"):
                cs.parse_machine(text, RM)
        data = cs.empty()
        data["PR"].append(pr_row(mergeCommit=OID_B, 상태="머지됨", **{"교차 레포": "예"}))
        self.assertEqual(cs.parse_machine(cs.render_machine(RM, data), RM)["PR"], data["PR"])

    def test_no_pr_row_round_trip_and_shape(self):
        data = cs.empty()
        data["PR"].append(cs.no_pr_row("feature/z", "2026-10-22 09:00", SID))
        text = cs.render_machine(RM, data)
        self.assertIn("- feature/z · - · PR 0개 · 2026-10-22 09:00 · - · - · - · - · %s" % SID, text)
        self.assertEqual(cs.parse_machine(text, RM)["PR"], data["PR"])
        for over in ({"상태": "열림"}, {"headRefOid": OID_A}, {"교차 레포": "아니오"}, {"baseRefName": "trunk"},
                     {"mergeCommit": OID_B}):
            bad = cs.empty()
            bad["PR"].append(dict(cs.no_pr_row("feature/z", "2026-10-22 09:00", SID), **over))
            with self.assertRaises(cs.MachineError, msg=over):
                cs.render_machine(RM, bad)
        bad = cs.empty()
        bad["PR"].append(pr_row(상태="PR 0개"))
        with self.assertRaises(cs.MachineError):
            cs.render_machine(RM, bad)


class WriterStamp(unittest.TestCase):
    """쓴 판(R8 계획 2 Task 3 · AC21) — 머리말에 쓴 판을 찍고, 더 새 판이 쓴 파일은 읽지 않고 멈춘다."""
    def setUp(self):
        self.orig = cs.own_version

    def tearDown(self):
        cs.own_version = self.orig

    def with_writer(self, writer, own):
        cs.own_version = lambda: own
        text = cs.render_machine(RM, sample())
        cs.own_version = self.orig
        old = "writer: spec-distill " + own + "\n"
        self.assertEqual(text.count(old), 1)
        return text.replace(old, "" if writer is None else "writer: " + writer + "\n")

    def test_writer_stamp_roundtrip(self):
        plugin_json = Path(cs.__file__).resolve().parent.parent / ".claude-plugin" / "plugin.json"
        import json
        want = json.loads(plugin_json.read_text(encoding="utf-8"))["version"]
        self.assertEqual(cs.own_version(), want)
        text = cs.render_machine(RM, sample())
        head = text.split("\n---\n", 1)[0].split("\n")
        self.assertIn("writer: spec-distill " + want, head)
        self.assertEqual(cs.parse_machine(text, RM), sample())

    def test_newer_writer_stops_older_reader(self):
        text = self.with_writer("spec-distill 9.1.0", "7.0.0")
        cs.own_version = lambda: "7.0.0"
        with self.assertRaises(cs.MachineError) as cm:
            cs.parse_machine(text, RM)
        msg = str(cm.exception)
        self.assertIn("더 새 판(spec-distill 9.1.0)이 썼다", msg)
        self.assertIn("업데이트", msg)
        self.assertIn("지금 판 7.0.0", msg)
        text = self.with_writer("spec-distill 7.10.0", "7.9.0")
        cs.own_version = lambda: "7.9.0"  # 자릿수가 다른 판 — 글자가 아니라 정수로 비교한다
        with self.assertRaises(cs.MachineError):
            cs.parse_machine(text, RM)

    def test_missing_writer_is_read(self):
        text = self.with_writer(None, "7.0.0")
        self.assertNotIn("writer:", text)
        cs.own_version = lambda: "7.0.0"
        self.assertEqual(cs.parse_machine(text, RM), sample())

    def test_same_or_older_writer_is_read(self):
        for writer, own in [("spec-distill 7.0.0", "7.0.0"), ("spec-distill 6.9.9", "7.0.0"),
                            ("spec-distill 7.0.0-rc1", "7.0.0"), ("spec-distill 7.9.0", "7.10.0"),
                            ("spec-distill 6.12.3", "7.0.0")]:
            text = self.with_writer(writer, own)
            cs.own_version = lambda: own
            self.assertEqual(cs.parse_machine(text, RM), sample(), (writer, own))

    def test_uncomparable_versions_stop(self):
        text = self.with_writer("spec-distill dev", "7.0.0")
        cs.own_version = lambda: "7.0.0"
        with self.assertRaises(cs.MachineError) as cm:
            cs.parse_machine(text, RM)
        self.assertIn("판을 비교하지 못했다", str(cm.exception))
        text = self.with_writer("spec-distill 7.0.0", "7.0.0")
        cs.own_version = lambda: "7.0"
        with self.assertRaises(cs.MachineError) as cm:
            cs.parse_machine(text, RM)
        self.assertIn("판을 비교하지 못했다", str(cm.exception))
        with self.assertRaises(cs.MachineError):
            cs.render_machine(RM, sample())

    def test_own_version_read_failure_stops_with_reinstall(self):
        orig_file = cs.__file__
        tmp = Path(tempfile.mkdtemp())
        try:
            (tmp / "scripts").mkdir()
            cs.__file__ = str(tmp / "scripts" / "conductor_state.py")
            for content in (None, "{not json", '{"version": ""}', '{"version": "dev"}'):
                meta = tmp / ".claude-plugin"
                if content is not None:
                    meta.mkdir(exist_ok=True)
                    (meta / "plugin.json").write_text(content, encoding="utf-8")
                with self.assertRaises(cs.MachineError) as cm:
                    cs.render_machine(RM, sample())
                self.assertTrue(str(cm.exception).endswith("— 플러그인을 다시 설치한다"), (content, str(cm.exception)))
        finally:
            cs.__file__ = orig_file
            shutil.rmtree(tmp, ignore_errors=True)

    def test_writer_name_must_be_spec_distill(self):
        for writer in ("other-plugin 7.0.0", "spec-distillx 7.0.0", "7.0.0"):
            text = self.with_writer(writer, "7.0.0")
            cs.own_version = lambda: "7.0.0"
            with self.assertRaises(cs.MachineError) as cm:
                cs.parse_machine(text, RM)
            self.assertTrue(str(cm.exception).endswith("머리말의 writer 줄을 확인한다"), (writer, str(cm.exception)))
        text = self.with_writer("spec-distill dev", "7.0.0")
        with self.assertRaises(cs.MachineError) as cm:
            cs.parse_machine(text, RM)
        self.assertTrue(str(cm.exception).endswith("머리말의 writer 줄을 확인한다"), str(cm.exception))

    def test_version_triple(self):
        self.assertEqual(cs.version_triple("8.7.0"), (8, 7, 0))
        self.assertEqual(cs.version_triple("v7.3.1-rc1"), (7, 3, 1))
        self.assertEqual(cs.version_triple("spec-distill 12.0.10"), (12, 0, 10))
        for bad in ("7.3", "dev", ""):
            self.assertIsNone(cs.version_triple(bad), bad)


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

    def test_repo_settings_rows(self):   # R8 AC5 — 해결자의 기계 상태 층
        self.assertEqual(cs.repo_settings_rows(self.path, RM), {})
        self.path.parent.mkdir(parents=True)
        head = "---\ntype: %s\nroadmap: %s\n---\n\n## 레포 설정\n\n" % (cs.TYPE, RM)
        self.path.write_text(head + "- test_command · make test\n- test_failure_pattern · \"^F: (.+)$\"\n", encoding="utf-8")
        self.assertEqual(cs.repo_settings_rows(self.path, RM),
                         {"test_command": "make test", "test_failure_pattern": "\"^F: (.+)$\""})
        self.path.write_text(head + "- test_command · make a\n- test_command · make b\n", encoding="utf-8")
        with self.assertRaises(cs.MachineError) as c:
            cs.repo_settings_rows(self.path, RM)
        self.assertIn("같은 키가 둘이다(test_command)", str(c.exception))


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


class OptionalWorks(unittest.TestCase):
    """지휘자 수리 2 — 빈 「작업」 절은 머리를 쓰지 않아 옛 판(그 절을 모르는)도 파일을 읽는다."""
    def test_empty_works_section_is_not_rendered(self):
        import conductor_state as C
        text = C.render_machine("a/rm/roadmap.md", C.empty())
        self.assertNotIn("## 작업", text)
        self.assertEqual(C.parse_machine(text, "a/rm/roadmap.md"), C.empty())
        data = C.empty()
        data["작업"].append(dict(zip(C.COLUMNS["작업"], ["수리 PR", "fix/x", "로드맵 밖", "구현", "a", "/d"])))
        text = C.render_machine("a/rm/roadmap.md", data)
        self.assertIn("## 작업", text)
        self.assertEqual(C.parse_machine(text, "a/rm/roadmap.md")["작업"], data["작업"])


if __name__ == "__main__":
    unittest.main()
