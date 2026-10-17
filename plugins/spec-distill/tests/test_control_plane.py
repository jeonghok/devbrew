#!/usr/bin/env python3
"""control_plane.py 의 표시 순수 함수 — 상태줄 · 지도 · 작업 목록 줄의 모양(R6 AC1 · AC2 · AC3).

Run (리포 루트에서):
    python3 -m unittest plugins/spec-distill/tests/test_control_plane.py
"""
from __future__ import annotations

import inspect
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import control_plane as cp  # noqa: E402
import conductor_state as cs  # noqa: E402
import roadmap_status  # noqa: E402

RM = "docs/superpowers/roadmaps/rm/roadmap.md"


def blk(bid, stage, task, deps=(), warnings=(), title=None, reason="이유", **extra):
    b = {"id": bid, "title": title or "에픽 " + bid, "kind": "bundle", "stage": stage, "reason": reason,
         "task_status": task, "deps": list(deps), "warnings": list(warnings), "notes": []}
    b.update(extra)
    return b


def report(blocks, exit_code=0, **kw):
    r = {"roadmap": RM, "source": "origin/main", "fetched_at": "2026-10-15 10:00", "notice": "알림",
         "blocks": blocks, "unassigned": [], "orphans": [], "unknown_ids": [], "overlaps": [],
         "format_errors": [], "unknown_reasons": [], "exit": exit_code}
    r.update(kw)
    return r


BASE = [blk("R1", "설계 중", "in_progress", warnings=["경고 하나"]), blk("R2", "계획", "in_progress"),
        blk("R3", "준비", "pending"), blk("R4", "대기", "pending"), blk("R0", "머지됨", "completed")]
NO_IV = {"supported": True, "items": [], "errors": []}
IV = {"supported": True, "errors": [],
      "items": [{"path": "docs/superpowers/interview/2026-10-15-t-interview.state.md", "n": 3, "limit": 20,
                 "last": "포화 판정 1: 아직 — 빈 곳 2개", "mtime": 2.0},
                {"path": "docs/superpowers/interview/2026-10-14-u-interview.state.md", "n": 9, "limit": 20,
                 "last": None, "mtime": 1.0}]}

STATE = """---
type: interview-state
seed: none
orchestration:
  focused_dimension: null
  research_dispatches: {coverage_mapper: 1, blind_spot_prober: 1, steelman_builder: 0, repo_researcher: 1}  # 조사
  research_limit: 20
  saturation_limit: 5
---

## R1

본문.

## audit §2 대기 줄

- 상한 도달 20/20 — 사용자 선택 S4: 연장
- 포화 판정 1: 아직 — 빈 곳 2개
"""


class Statusline(unittest.TestCase):
    def test_base_shape(self):
        self.assertEqual(cp.statusline_text([(RM, report(BASE, 1))], NO_IV, 5),
                         "rm · 설계 1 · 구현 1 · 준비 1 · 경고 1 · 받은 지 5분")

    def test_no_warnings(self):
        line = cp.statusline_text([(RM, report([blk("R3", "준비", "pending")]))], NO_IV, 0)
        self.assertEqual(line, "rm · 설계 0 · 구현 0 · 준비 1 · 경고 없음 · 받은 지 0분")

    def test_top_level_warnings_count(self):
        r = report(BASE, 1, orphans=["S3", "S9"], unassigned=["C4"], unknown_ids=["X1"])
        self.assertIn("· 경고 4 ·", cp.statusline_text([(RM, r)], NO_IV, 5))

    def test_unknown_exit(self):
        line = cp.statusline_text([(RM, report(BASE, 3))], NO_IV, 5)
        self.assertTrue(line.endswith(" · 받은 지 5분 · 검사 불가"), line)

    def test_interview_segment_latest_first(self):
        line = cp.statusline_text([(RM, report(BASE, 1))], IV, 5)
        self.assertTrue(line.endswith(" · 받은 지 5분 · 인터뷰 조사 3/20 외 1"), line)

    def test_no_roadmap_with_interview(self):
        self.assertEqual(cp.statusline_text([], IV, None), "인터뷰 조사 3/20 외 1")

    def test_no_roadmap_no_interview_is_empty(self):
        self.assertEqual(cp.statusline_text([], NO_IV, 3), "")

    def test_unsupported_interview_has_no_segment(self):
        line = cp.statusline_text([(RM, report(BASE, 1))], {"supported": False, "items": [], "errors": []}, 5)
        self.assertNotIn("인터뷰", line)

    def test_interview_error(self):
        iv = {"supported": True, "items": [], "errors": [{"path": "x", "reason": "깨짐"}]}
        self.assertTrue(cp.statusline_text([(RM, report(BASE, 1))], iv, 5).endswith(" · 인터뷰 셀 수 없음"))

    def test_minutes_unknown(self):
        self.assertIn("· 받은 시각 모름", cp.statusline_text([(RM, report(BASE, 1))], NO_IV, None))

    def test_many_roadmaps_are_summed(self):
        other = ("docs/superpowers/roadmaps/rn/roadmap.md", report(BASE, 3))
        line = cp.statusline_text([(RM, report(BASE, 1)), other], NO_IV, 5)
        self.assertEqual(line, "rm 외 1 · 설계 2 · 구현 2 · 준비 2 · 경고 2 · 받은 지 5분 · 검사 불가")

    def test_future_stage_names(self):
        r = report([blk("R5", "구현 중", None), blk("R8", "검토", None)])
        self.assertEqual(cp.statusline_text([(RM, r)], NO_IV, 1),
                         "rm · 설계 0 · 구현 1 · 준비 0 · 기타 1 · 경고 없음 · 받은 지 1분")

    def test_select_error(self):
        self.assertEqual(cp.statusline_text([], NO_IV, 2, "목록을 못 읽었다"), "검사 불가")

    def test_control_chars_statusline(self):
        r = report([blk("R1", "설계 중", "in_progress")])
        line = cp.statusline_text([("docs/superpowers/roadmaps/a\x1b[31mb\nc/roadmap.md", r)], NO_IV, 1)
        self.assertNotIn("\x1b", line)
        self.assertNotIn("\n", line)


class Show(unittest.TestCase):
    def show(self, items, iv=NO_IV, notes=(), sel=None):
        return cp.show_text(items, iv, list(notes), cp.first_line, sel).split("\n")

    def test_first_line_is_status_first_line(self):
        r = report(BASE, 1)
        lines = self.show([(RM, r)])
        self.assertEqual(lines[0], roadmap_status.render(r).split("\n")[0])
        self.assertEqual(lines[1], "로드맵: " + RM)

    def test_waiting_marker_only_unfinished_deps(self):
        r = report([blk("R0", "머지됨", "completed"), blk("R2", "설계 중", "in_progress"),
                    blk("R7", "대기", "pending"), blk("R6", "설계 중", "in_progress", deps=["R0", "R2", "R7"]),
                    blk("R9", "준비", "pending", deps=["R0"])])
        lines = self.show([(RM, r)])
        self.assertIn("R6 에픽 R6 — 설계 중 · 이유 ← 기다림: R2 · R7", lines)
        self.assertIn("R9 에픽 R9 — 준비 · 이유", lines)

    def test_block_warnings_indented(self):
        self.assertIn("    경고: 경고 하나", self.show([(RM, report(BASE, 1))]))

    def test_top_level_warning_lines(self):
        r = report(BASE, 1, orphans=["S3", "S9"], unassigned=["C4"], unknown_ids=["X1"])
        lines = self.show([(RM, r)])
        self.assertIn("고아 발화: 2개 — S3 · S9", lines)
        self.assertIn("미배정 번호: 1개 — C4", lines)
        self.assertIn("brief 에 없는 번호: 1개 — X1", lines)

    def test_top_level_uncountable(self):
        lines = self.show([(RM, report(BASE, 3, orphans=None, unassigned=None))])
        self.assertIn("고아 발화: 셀 수 없음", lines)
        self.assertIn("미배정 번호: 셀 수 없음", lines)

    def test_empty_top_level_lines_absent(self):
        text = "\n".join(self.show([(RM, report(BASE, 0))]))
        self.assertNotIn("고아 발화", text)

    def test_unknown_reasons_lines(self):
        r = report(BASE, 3, format_errors=["형식 하나"], unknown_reasons=["로드맵을 못 읽었다: x (origin/main)"])
        lines = self.show([(RM, r)])
        self.assertIn("검사 불가: 형식 깨짐 — 형식 하나", lines)
        self.assertIn("검사 불가: 로드맵을 못 읽었다: x (origin/main)", lines)

    def test_rulings_absent_section_absent(self):
        self.assertNotIn("판정 줄:", self.show([(RM, report(BASE, 1))]))

    def test_rulings_present(self):
        r = report([blk("R5", "구현 중", None, rulings=["실행 판정 하나"]), blk("R6", "계획", "in_progress", rulings=[])])
        lines = self.show([(RM, r)])
        i = lines.index("판정 줄:")
        self.assertEqual(lines[i + 1], "    R5: 실행 판정 하나")

    def test_rulings_present_but_empty(self):
        lines = self.show([(RM, report([blk("R5", "계획", "in_progress", rulings=[])]))])
        i = lines.index("판정 줄:")
        self.assertEqual(lines[i + 1], "    없음")

    def test_no_roadmap(self):
        self.assertEqual(self.show([])[0], "로드맵 없음 — 기본 브랜치에 끝나지 않은 블록이 있는 로드맵이 없다")

    def test_select_error(self):
        self.assertEqual(self.show([], sel="목록을 못 읽었다")[0], "검사 불가: 목록을 못 읽었다")

    def test_interview_sections(self):
        self.assertIn("인터뷰: 셀 수 없음 — 이 플러그인 버전은 인터뷰 상태 파일을 아직 남기지 않는다",
                      self.show([], {"supported": False, "items": [], "errors": []}))
        self.assertIn("인터뷰: 진행 중 없음", self.show([], NO_IV))
        lines = self.show([], IV)
        self.assertIn("인터뷰: 진행 중 2개", lines)
        self.assertIn("    docs/superpowers/interview/2026-10-15-t-interview.state.md — 조사 3/20 · 마지막 사건: "
                      "포화 판정 1: 아직 — 빈 곳 2개", lines)
        err = {"supported": True, "items": [], "errors": [{"path": "p.state.md", "reason": "깨짐"}]}
        self.assertIn("    p.state.md — 셀 수 없음(깨짐)", self.show([], err))

    def test_cache_note(self):
        self.assertEqual(self.show([], NO_IV, ["캐시 파일이 깨져 있었다"])[-1], "캐시를 쓰지 못했다 — 캐시 파일이 깨져 있었다")

    def test_control_chars_show(self):
        r = report([blk("R1", "설계 중", "in_progress", title="a\x1b]0;x\x07b", warnings=["w\nx"])])
        text = "\n".join(self.show([(RM, r)]))
        self.assertNotIn("\x1b", text)
        self.assertNotIn("\x07", text)
        self.assertIn("    경고: w x", text.split("\n"))


class Tasks(unittest.TestCase):
    def test_lines(self):
        r = report([blk("R1", "설계 중", "in_progress"), blk("R5", "구현 중", None, reason="R5 단계")], 1)
        out, err, rc = cp.tasks_output([(RM, r)])
        self.assertEqual((out, err, rc), (["R1 에픽 R1 — 설계 중\tin_progress",
                                           "R5 에픽 R5 — 구현 중 · 알 수 없음(R5 단계)\tkeep"], "", 0))

    def test_every_line_has_exactly_two_fields(self):
        r = report([blk("R1", "설계 중", "in_progress", title="탭\t제목")], 0)
        out, _err, _rc = cp.tasks_output([(RM, r)])
        self.assertEqual([len(x.split("\t")) for x in out], [2])

    def test_not_on_default_prints_nothing(self):
        r = report([blk("R1", "설계 중", "in_progress")], 4)
        out, err, rc = cp.tasks_output([(RM, r)])
        self.assertEqual((out, rc), ([], 4))
        self.assertIn("--roadmap-file", err)

    def test_unknown_exit_prints_nothing(self):
        r = report(BASE, 3, unknown_reasons=["로드맵을 못 읽었다: x (origin/main)"])
        out, err, rc = cp.tasks_output([(RM, r)])
        self.assertEqual((out, rc), ([], 3))
        self.assertEqual(err, "검사 불가 — 로드맵을 못 읽었다: x (origin/main)")

    def test_many_roadmaps(self):
        out, err, rc = cp.tasks_output([(RM, report(BASE)), ("docs/superpowers/roadmaps/rn/roadmap.md", report(BASE))])
        self.assertEqual((out, rc), ([], 2))
        self.assertTrue(err.startswith("로드맵이 여럿이다 — 경로를 하나 주라: "), err)

    def test_none(self):
        self.assertEqual(cp.tasks_output([]), ([], "로드맵 없음 — 작업 목록을 바꾸지 않는다", 3))

    def test_select_error(self):
        self.assertEqual(cp.tasks_output([], "목록을 못 읽었다"), ([], "검사 불가 — 목록을 못 읽었다", 3))


class InterviewState(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(cp.parse_interview_state(STATE), {"n": 3, "limit": 20, "last": "포화 판정 1: 아직 — 빈 곳 2개"})

    def test_empty_dispatches(self):
        text = STATE.replace("{coverage_mapper: 1, blind_spot_prober: 1, steelman_builder: 0, repo_researcher: 1}", "{}")
        self.assertEqual(cp.parse_interview_state(text)["n"], 0)

    def test_no_queue(self):
        self.assertIsNone(cp.parse_interview_state(STATE.split("## audit")[0])["last"])

    def test_bad_inputs(self):
        cases = {
            "no frontmatter": "본문만",
            "unclosed": "---\ntype: interview-state\n",
            "wrong type": STATE.replace("type: interview-state", "type: interview-brief"),
            "bad count": STATE.replace("coverage_mapper: 1", "coverage_mapper: x"),
            "no limit": STATE.replace("  research_limit: 20\n", ""),
            "no dispatches": STATE.replace("research_dispatches", "research_other"),
        }
        for name, text in cases.items():
            with self.subTest(name):
                with self.assertRaises(ValueError):
                    cp.parse_interview_state(text)


class Failed(unittest.TestCase):
    def test_failed_report_renders(self):
        r = cp.failed_report(RM, "사유")
        self.assertEqual(r["exit"], 3)
        self.assertTrue(cp.first_line(r).startswith("로드맵 상태 — 블록 0개"))


class CodeStamp(unittest.TestCase):
    def test_stamp_covers_roadmap_logic_files(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            for name in cp.CODE_STAMP_FILES:
                Path(d, name).write_text("x", encoding="utf-8")
            old = cp.SCRIPTS
            cp.SCRIPTS = Path(d)
            try:
                for edited in ("roadmap_model.py", "section6.py", "check_bundle_coverage.py", "repo_defaults.py"):
                    self.assertIn(edited, cp.CODE_STAMP_FILES)
                    before = cp.code_stamp()
                    Path(d, edited).write_text("changed-longer", encoding="utf-8")
                    self.assertNotEqual(before, cp.code_stamp(), edited)
            finally:
                cp.SCRIPTS = old


class Parallel(unittest.TestCase):
    def test_parallel_with_skips_dependents_and_done(self):
        blocks = [{"id": "A", "stage": "설계 중", "deps": []}, {"id": "B", "stage": "준비", "deps": ["A"]},
                  {"id": "C", "stage": "준비", "deps": []}, {"id": "D", "stage": "머지됨", "deps": []}]
        got = roadmap_status.parallel_with(blocks, [{"blocks": ["A", "C"], "paths": ["src/x"]}])
        self.assertEqual(got["A"], [{"id": "C", "overlap": ["src/x"]}])
        self.assertEqual([p["id"] for p in got["B"]], ["C"])
        self.assertEqual(got["D"], [])


def impl_done_block(bid="R5", branch="feature/a", **extra):
    return blk(bid, "구현 끝", "in_progress", branch_states=[{"branch": branch, "tip": "abcdef12", "merged": None}],
               **extra)


class Overlay(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.ledger = self.tmp / "progress.md"
        self.ledger.write_text("# SDD ledger — plan: p\nTask 1: Ruling: 가 — 왜 — 비용\n", encoding="utf-8")

    def tearDown(self):
        shutil.rmtree(str(self.tmp))

    def machine(self, pr=None, ledger_for=None):
        data = cs.empty()
        if pr:
            data["PR"].append({"브랜치": "feature/a", "번호": "#12", "상태": pr, "확인한 때": "2026-10-17 10:00"})
        if ledger_for:
            data["실행 원장"].append({"에픽": ledger_for, "계획": "p.md", "원장": str(self.ledger), "읽은 줄": "0"})
        return lambda rel: (data, None)

    def test_open_pr_in_machine_turns_impl_done_into_pr(self):
        r = report([impl_done_block()])
        cp.overlay([(RM, r)], self.machine(pr="열림"), None, True)
        self.assertEqual(r["blocks"][0]["stage"], "PR")
        self.assertEqual(r["blocks"][0]["task_status"], "in_progress")

    def test_unknown_pr_keeps_stage_and_says_so(self):
        r = report([impl_done_block()])
        cp.overlay([(RM, r)], self.machine(), None, True)
        self.assertEqual(r["blocks"][0]["stage"], "구현 끝")
        self.assertIn("    PR: 알 수 없음 — 기계 상태에 없고 gh 가 없다", self.show_lines(r))

    def test_statusline_mode_never_calls_gh(self):
        r = report([impl_done_block()])
        cp.overlay([(RM, r)], self.machine(), lambda br: self.fail("gh 를 불렀다"), False)
        self.assertEqual(r["blocks"][0]["pr"]["state"], "알 수 없음")
        self.assertIn("use_gh=False", inspect.getsource(cp.cmd_statusline))

    def test_rulings_ledger_then_archive_then_uncountable(self):
        r = report([impl_done_block("R5"), impl_done_block("R6", rulings_archived=["- 보관 판정"]),
                    impl_done_block("R7"), blk("R0", "머지됨", "completed")])
        cp.overlay([(RM, r)], self.machine(ledger_for="R5"), None, False)
        got = dict((b["id"], b.get("rulings", "없음 키")) for b in r["blocks"])
        self.assertEqual(got, {"R5": ["Task 1: Ruling: 가 — 왜 — 비용"], "R6": ["- 보관 판정"], "R7": None,
                               "R0": "없음 키"})
        self.assertIn("    R7: 셀 수 없음 — 실행 원장도 설계문서 `## 판정` 도 없다", self.show_lines(r))

    def test_broken_machine_is_shown_not_emptied(self):
        r = report([impl_done_block()])
        cp.overlay([(RM, r)], lambda rel: (None, "3줄: 모르는 절 'x'"), None, False)
        self.assertIsNone(r["machine"])
        self.assertIn("기계 상태를 읽지 못했다 — 3줄: 모르는 절 'x'", self.show_lines(r))

    def test_overlap_lines_show_content(self):
        r = report(BASE, overlaps=[{"blocks": ["R1", "R2"], "paths": ["src/x.py", "docs/y/"]}])
        lines = self.show_lines(r)
        self.assertIn("경로 예약 겹침(정보): 1개", lines)
        self.assertIn("    R1 ↔ R2: src/x.py · docs/y/", lines)

    def test_partial_merge_counts_as_implementation(self):
        counts, other = cp.bucket_counts([(RM, report([blk("R5", "일부 머지 1/3", "in_progress")]))])
        self.assertEqual((counts["구현"], other), (1, 0))

    def test_code_stamp_covers_state_computation_modules(self):
        # 기계 상태는 캐시 밖이라 state_path · ledger_marker 는 열쇠가 아니다(인터뷰 지원 토글이 캐시를 밀지 않는다)
        for name in ("conductor_state.py", "repo_defaults.py"):
            self.assertIn(name, cp.CODE_STAMP_FILES)
        self.assertNotIn("state_path.py", cp.CODE_STAMP_FILES)

    def test_machine_for_catches_format_error(self):
        class FakeRepo:
            cwd = "/nonexistent"

            def line(self, *args):
                return ".git"
        orig = cs.load

        def boom(path, rel):
            raise cp.FormatError("깨짐")
        cs.load = boom
        try:
            data, why = cp.machine_for(FakeRepo(), RM)
        finally:
            cs.load = orig
        self.assertIsNone(data)
        self.assertIn("깨짐", why)

    def test_gh_lookup_with_fake_gh(self):
        bindir = self.tmp / "bin"
        bindir.mkdir()
        gh = bindir / "gh"
        old_path = os.environ.get("PATH", "")
        os.environ["PATH"] = str(bindir) + os.pathsep + old_path
        try:
            for body, want in (("echo '[{\"number\": 7, \"state\": \"OPEN\"}]'", {"number": "#7", "state": "열림"}),
                               ("echo '[]'", {"number": None, "state": "없음"}),
                               ("exit 1", {"number": None, "state": "알 수 없음"})):
                gh.write_text("#!/bin/sh\n" + body + "\n", encoding="utf-8")
                gh.chmod(0o755)
                lookup = cp.gh_lookup_for(cp.Repo(str(self.tmp), cp.Deadline(5)), cp.Deadline(5))
                got = lookup("feature/a")
                self.assertEqual({"number": got["number"], "state": got["state"]}, want, body)
        finally:
            os.environ["PATH"] = old_path

    def show_lines(self, r):
        return cp.show_text([(RM, r)], NO_IV, [], lambda rep: "첫 줄", None).split("\n")


if __name__ == "__main__":
    unittest.main()
