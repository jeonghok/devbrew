#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""승인 줄 읽기 · 상태 계산의 「설계 중」 근거 · 머지된 에픽 PR 번호(R5 계획 3 Task 2 — 결정 C · J).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_roadmap_approval.py
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import control_plane as cp  # noqa: E402
import repo_defaults as rd  # noqa: E402
import roadmap_model as M  # noqa: E402
import roadmap_status as rs  # noqa: E402

DOC = "---\nsource_interview: b.md\n---\n\n# 설계\n\n## 지휘 기록\n\n%s\n"


class ApprovalDate(unittest.TestCase):
    def test_canonical_line(self):
        self.assertEqual(M.approval_date(DOC % "- spec 승인 · 2026-10-18 · 「① /compact 후 다음 세션 줄 (권장)」"), "2026-10-18")

    def test_latest_of_several(self):
        doc = DOC % "- spec 승인 · 2026-10-17 · 「①」\n- spec 승인 · 2026-10-19 · 「②」"
        self.assertEqual(M.approval_date(doc), "2026-10-19")

    def test_hand_written_line(self):
        self.assertEqual(M.approval_date(DOC % "- 2026-10-18 사용자가 spec 을 승인했다(① 고름)"), "2026-10-18")

    def test_negated_lines_are_not_approval(self):
        for line in ("- 2026-10-18 승인 대기", "- 2026-10-18 승인 전 리뷰 3라운드", "- 2026-10-18 승인 거절 — 고침",
                     "- 2026-10-18 아직 승인하지 않았다", "- 2026-10-18 승인 안 됨"):
            self.assertIsNone(M.approval_date(DOC % line), line)

    def test_probe_lines_are_not_approval(self):
        for tail in ("미승인", "승인 요청 보냄", "승인 보류", "승인 철회", "승인 게이트 띄움", "재승인 필요",
                     "승인을 기다린다", "승인이 아니다", "조사 흐름 고름 — 사용자 승인", "시작 승인 공시"):
            self.assertIsNone(M.approval_date(DOC % ("- 2026-10-18 " + tail)), tail)

    def test_round2_lines_are_not_approval(self):
        for tail in ("spec 승인받지 못함", "spec 승인 받을 예정", "spec 승인받기 전 리뷰", "spec 승인됨 아님",
                     "spec 승인했던 것 무효", "spec 리뷰 통과, 승인 받으러 감", "specs 승인됨 아닌 다른 문서"):
            self.assertIsNone(M.approval_date(DOC % ("- 2026-10-18 " + tail)), tail)

    def test_canonical_without_date_is_format_error(self):
        for rest in ("어제 · 「①」", "어제 · 「2026-10-18 계획」", "2026-10-180 · 「①」"):
            with self.assertRaises(M.FormatError, msg=rest):
                M.approval_date(DOC % ("- spec 승인 · " + rest))

    def test_no_section_or_no_line(self):
        self.assertIsNone(M.approval_date("# 설계\n"))
        self.assertIsNone(M.approval_date(DOC % "- 넘김 확인 · R2 · 0123abcd · 받음"))
        self.assertIsNone(M.approval_date(DOC % "승인 2026-10-18 (목록 줄 아님)"))

    def test_duplicate_heading_is_format_error(self):
        doc = DOC % "- spec 승인 · 2026-10-18 · 「①」" + "\n## 지휘 기록\n\n- x\n"
        with self.assertRaises(M.FormatError):
            M.approval_date(doc)

    def test_heading_in_fence_is_not_section(self):
        doc = "# 설계\n\n```\n## 지휘 기록\n- spec 승인 · 2026-10-18 · 「①」\n```\n"
        self.assertIsNone(M.approval_date(doc))


class FakeGit:
    """progress 가 부르는 git 읽기만 흉내 낸다 — 커밋 하나(tip)의 파일들.
    `failures` 는 진짜 Git 처럼 읽기 실패를 쌓는다 — progress 가 갈라진 곳을 못 읽은 것과 못 찾은 것을 이것으로 가른다."""
    def __init__(self, files, plans=(), base_failure=None):
        self.files, self.plans = files, list(plans)
        self.failures = []
        self.base_failure = base_failure

    def grep_files(self, tree, needle, folder):
        return [p for p in self.files if p.startswith(folder)]

    def blob(self, tree, path):
        return self.files.get(path)

    def merge_base(self, a, b):
        if self.base_failure:
            self.failures.append(self.base_failure)
            return None
        return "base"

    def changed(self, base, tip, folder):
        return [p for p in self.plans if p.startswith(folder)]

    def first_touch(self, base, tip, path):
        return "c1"

    def trailer_after(self, c, tip, base, trailers):
        return False


SETTINGS = {"specs_dir": "docs/superpowers/specs/", "plans_dir": "docs/superpowers/plans/"}
SPEC = "docs/superpowers/specs/x-design.md"


def spec_text(record):
    return "---\nsource_interview: rm/A1.md\n---\n\n# x\n\n## 지휘 기록\n\n%s\n" % record


class Progress(unittest.TestCase):
    def block(self):
        return {"id": "A1", "kind": "bundle", "fields": {}}

    def test_spec_only(self):
        b = self.block()
        got = rs.progress(FakeGit({SPEC: "---\nsource_interview: rm/A1.md\n---\n# x\n"}), "main", "tip", b, "rm/A1.md", SETTINGS)
        self.assertEqual(got[:2], ("설계 중", "spec 있음"))
        self.assertIsNone(b["approved"])

    def test_approved_no_plan(self):
        b = self.block()
        got = rs.progress(FakeGit({SPEC: spec_text("- spec 승인 · 2026-10-18 · 「①」")}), "main", "tip", b, "rm/A1.md", SETTINGS)
        self.assertEqual(got[:2], ("설계 중", "spec 승인됨(2026-10-18) · 계획 없음"))
        self.assertEqual(b["approved"], "2026-10-18")

    def test_broken_record_is_not_silent(self):
        b = self.block()
        doc = spec_text("- spec 승인 · 2026-10-18 · 「①」") + "\n## 지휘 기록\n\n- y\n"
        got = rs.progress(FakeGit({SPEC: doc}), "main", "tip", b, "rm/A1.md", SETTINGS)
        self.assertEqual(got[0], "설계 중")
        self.assertTrue(got[1].startswith("spec 있음 · 지휘 기록 읽기 불가 — "), got[1])
        self.assertIsNone(b["approved"])

    def test_plan_wins_over_approval(self):
        b = self.block()
        plan = "docs/superpowers/plans/x.md"
        files = {SPEC: spec_text("- spec 승인 · 2026-10-18 · 「①」"), plan: "**Spec:** `%s`\n" % SPEC}
        got = rs.progress(FakeGit(files, [plan]), "main", "tip", b, "rm/A1.md", SETTINGS)
        self.assertEqual(got[0], "계획")

    def test_unread_merge_base_is_unknown_not_designing(self):
        b = self.block()
        why = "git merge-base 실패(rc 128): fatal: bad object"
        got = rs.progress(FakeGit({SPEC: spec_text("- spec 승인 · 2026-10-18 · 「①」")}, base_failure=why),
                          "main", "tip", b, "rm/A1.md", SETTINGS)
        self.assertEqual(got[0], "알 수 없음")
        self.assertIn(why, got[1])


class OneDefaultRef(unittest.TestCase):
    def test_constants_live_in_model_only(self):
        self.assertIs(rs.DEFAULT_REF, M.DEFAULT_REF)
        self.assertIs(cp.DEFAULT_REF, M.DEFAULT_REF)
        self.assertIs(rs.NO_DEFAULT, M.NO_DEFAULT)
        self.assertIs(cp.NO_DEFAULT, M.NO_DEFAULT)
        self.assertIs(rd._rm.DEFAULT_REF, M.DEFAULT_REF)
        self.assertIs(rd._rm.NO_ORIGIN, M.NO_ORIGIN)
        for name in ("roadmap_status.py", "control_plane.py", "repo_defaults.py"):
            text = (Path(rs.__file__).parent / name).read_text(encoding="utf-8")
            self.assertNotIn('DEFAULT_REF = "', text, name)
            self.assertNotIn("NO_DEFAULT = (", text, name)
            self.assertNotIn("NO_ORIGIN = ", text, name)


class MergedPrs(unittest.TestCase):
    def b(self):
        return {"id": "R1", "stage": "머지됨", "branch_states": [
            {"branch": "feature/a", "tip": None, "merged": "x"}, {"branch": "feature/b", "tip": None, "merged": "y"}]}

    @staticmethod
    def row(br, num, state, cross="아니오", base="main"):
        return {"브랜치": br, "번호": num, "상태": state, "확인한 때": "t", "headRefOid": "a" * 40, "교차 레포": cross,
                "baseRefName": base, "mergeCommit": "-", "쓴 세션": "session-aaaa1111"}

    def test_cache_only_and_own_pr_wins_over_a_later_fork_row(self):
        rows = [self.row("feature/a", "#7", "머지됨"), self.row("feature/a", "#8", "열림", cross="예"),
                self.row("feature/a", "#9", "열림", base="dev")]
        got = cp.merged_prs(self.b(), rows, "main")
        self.assertEqual(got[0], ("feature/a", {"number": "#7", "state": "머지됨", "source": "PR 캐시"}))
        self.assertEqual(got[1][0], "feature/b")
        self.assertEqual(got[1][1]["state"], "알 수 없음")

    def test_merged_row_wins_over_a_newer_open_row(self):
        rows = [self.row("feature/a", "#9", "열림"), self.row("feature/a", "#7", "머지됨"), self.row("feature/a", "#5", "닫힘")]
        got = cp.merged_prs(self.b(), rows, "main")
        self.assertEqual(got[0], ("feature/a", {"number": "#7", "state": "머지됨", "source": "PR 캐시"}))

    def test_finished_epic_without_rows_names_the_refill_command(self):
        got = cp.merged_prs(self.b(), [], "main")
        self.assertEqual([p["state"] for _b, p in got], ["알 수 없음", "알 수 없음"])
        why = got[0][1]["source"]
        self.assertIn("PR 캐시에 없다 — 끝난 에픽의 줄은 지휘자가 다시 채우지 않는다", why)
        self.assertIn("ledger pr-refresh --roadmap <로드맵> --session <세션> --epic R1 로 채운다", why)
        self.assertNotIn("gh", why.replace("pr-refresh", ""))

    def test_overlay_only_for_focus(self):
        report = {"blocks": [self.b(), dict(self.b(), id="R2")]}
        cp.overlay([("rm/roadmap.md", report)], lambda rel: ({"PR": [], "실행 원장": []}, None), True,
                   read=lambda p, n: "", focus="R1", default_short="main")
        self.assertIn("merged_prs", report["blocks"][0])
        self.assertNotIn("merged_prs", report["blocks"][1])

    def test_epic_view_shows_merged_prs(self):
        b = dict(self.b(), title="가", reason="머지", deps=[], parallel=[], specs=[], plans=[],
                 merged_prs=[("feature/a", {"number": "#7", "state": "머지됨", "source": "PR 캐시"})])
        lines, rc = cp.epic_view("rm/roadmap.md", {"blocks": [b], "handoffs": [], "machine": None}, "R1")
        self.assertEqual(rc, 0)
        self.assertIn("  PR: feature/a #7 머지됨(PR 캐시)", lines)


if __name__ == "__main__":
    unittest.main()
