#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_status.merged_by_pr · merged_by_git — 머지됨 판정의 여섯 조건 · 받기 전 · 셀 수 없음 · 머지 메시지 owner(R8 AC14 · AC15).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_merged_by_pr.py
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import roadmap_status as rs  # noqa: E402

BR = "feature/x"
TIP = "1" * 40
OLD = "2" * 40
NEW = "3" * 40
FORK = "4" * 40
M = "a" * 40
M_OLD = "b" * 40
M_FORK = "c" * 40


def row(**over):
    r = {"브랜치": BR, "번호": "#7", "상태": "머지됨", "확인한 때": "2026-10-20 10:00", "headRefOid": TIP,
         "교차 레포": "아니오", "baseRefName": "main", "mergeCommit": M, "쓴 세션": "session-aaaa1111"}
    for k, v in over.items():
        r[{"oid": "headRefOid", "merge": "mergeCommit", "cross": "교차 레포", "base": "baseRefName",
           "state": "상태", "branch": "브랜치", "num": "번호"}.get(k, k)] = v
    return r


def always(_c):
    return True


def never(_c):
    return False


class SixConditions(unittest.TestCase):
    def test_squash_merged_without_manual_line(self):           # AC14
        v, _ = rs.merged_by_pr([row(oid=TIP, merge=M)], BR, TIP, None, "main", always)
        self.assertEqual(v, "머지됨")

    def test_remote_tip_only(self):
        v, notes = rs.merged_by_pr([row()], BR, None, TIP, "main", always)
        self.assertEqual(v, "머지됨")
        self.assertEqual(notes, [])

    def test_cross_repo_is_not_merged(self):                     # AC15 — 다른 다섯이 다 맞아도
        v, _ = rs.merged_by_pr([row(cross="예")], BR, TIP, TIP, "main", always)
        self.assertIsNone(v)

    def test_cross_repo_even_when_branch_deleted(self):          # 끝 없음 + 교차 레포 예
        v, notes = rs.merged_by_pr([row(cross="예")], BR, None, None, "main", always)
        self.assertIsNone(v)
        self.assertFalse(any("브랜치 끝 없이 판정" in n for n in notes), notes)

    def test_reused_name_old_pr_is_not_merged(self):             # 옛 MERGED 의 headRefOid ≠ 끝
        v, _ = rs.merged_by_pr([row(oid=OLD, merge=M_OLD)], BR, TIP, None, "main", always)
        self.assertIsNone(v)

    def test_non_default_base_is_not_merged(self):
        v, _ = rs.merged_by_pr([row(base="release")], BR, TIP, None, "main", always)
        self.assertIsNone(v)

    def test_non_default_base_when_branch_deleted(self):
        v, _ = rs.merged_by_pr([row(base="release")], BR, None, None, "main", always)
        self.assertIsNone(v)

    def test_open_or_closed_is_not_merged(self):
        for state in ("열림", "닫힘"):
            v, _ = rs.merged_by_pr([row(state=state)], BR, TIP, None, "main", always)
            self.assertIsNone(v, state)

    def test_other_head_name_is_not_merged(self):
        v, _ = rs.merged_by_pr([row(branch="feature/x2")], BR, TIP, None, "main", always)
        self.assertIsNone(v)

    def test_commits_after_merge_is_not_merged(self):            # 끝이 더 나아감(로컬만)
        v, notes = rs.merged_by_pr([row(oid=TIP)], BR, NEW, TIP, "main", always)
        self.assertIsNone(v)
        self.assertIn("로컬 끝 %s · 원격 끝 %s" % (NEW[:8], TIP[:8]), notes)

    def test_deleted_branch_single_row_notices(self):
        v, notes = rs.merged_by_pr([row(oid=OLD, merge=M_OLD)], BR, None, None, "main", always)
        self.assertEqual(v, "머지됨")
        self.assertIn("브랜치 끝 없이 판정 — 캐시의 headRefOid %s" % OLD[:8], notes)

    def test_deleted_branch_two_rows_is_uncountable(self):
        rows = [row(oid=OLD, merge=M_OLD, num="#3"), row(oid=TIP, merge=M, num="#9")]
        v, notes = rs.merged_by_pr(rows, BR, None, None, "main", always)
        self.assertEqual(v, "셀 수 없음")
        self.assertEqual(notes, ["셀 수 없음 — 같은 이름의 머지된 PR 이 여럿이고 브랜치 끝이 없다(#3 · #9) — 브랜치를 맞는 PR 의 "
                                 "headRefOid 로 되살린다(`git branch feature/x <headRefOid>`)"])

    def test_deleted_branch_two_rows_same_oid_is_one_tip(self):
        rows = [row(num="#3"), row(num="#9")]
        v, _ = rs.merged_by_pr(rows, BR, None, None, "main", always)
        self.assertEqual(v, "머지됨")

    def test_not_fetched_is_not_merged(self):
        v, notes = rs.merged_by_pr([row()], BR, TIP, None, "main", never)
        self.assertEqual(v, "머지됨(받기 전)")
        self.assertTrue(any("git fetch 뒤 다시 계산한다" in n for n in notes), notes)

    def test_missing_merge_commit_is_not_merged(self):
        v, notes = rs.merged_by_pr([row(merge="-")], BR, TIP, None, "main", always)
        self.assertIsNone(v)
        self.assertTrue(any("mergeCommit" in n for n in notes), notes)

    def test_local_and_remote_tips_differ_both_shown(self):
        v, notes = rs.merged_by_pr([row(oid=NEW)], BR, NEW, TIP, "main", always)
        self.assertEqual(v, "머지됨")
        self.assertIn("로컬 끝 %s · 원격 끝 %s" % (NEW[:8], TIP[:8]), notes)

    def test_same_tips_no_notice(self):
        _v, notes = rs.merged_by_pr([row()], BR, TIP, TIP, "main", always)
        self.assertEqual(notes, [])

    def test_no_rows_is_none(self):
        self.assertEqual(rs.merged_by_pr([], BR, TIP, None, "main", always), (None, []))


class ForkRowWrittenLast(unittest.TestCase):
    """같은 head 이름의 fork PR 이 캐시의 마지막 줄이어도 판정을 정하지 않는다."""

    def fork(self, **over):
        base = dict(cross="예", oid=FORK, merge=M_FORK, num="#99")
        base.update(over)
        return row(**base)

    def test_my_merged_row_then_fork_row(self):
        v, _ = rs.merged_by_pr([row(), self.fork()], BR, TIP, None, "main", always)
        self.assertEqual(v, "머지됨")

    def test_fork_reachable_does_not_rescue_my_unfetched_row(self):
        v, _ = rs.merged_by_pr([row(), self.fork()], BR, TIP, None, "main", lambda c: c == M_FORK)
        self.assertEqual(v, "머지됨(받기 전)")

    def test_my_open_row_then_fork_merged_row(self):
        v, _ = rs.merged_by_pr([row(state="열림", merge="-"), self.fork()], BR, TIP, None, "main", always)
        self.assertIsNone(v)

    def test_fork_head_equals_my_tip_still_rejected(self):
        v, _ = rs.merged_by_pr([row(state="열림", merge="-"), self.fork(oid=TIP)], BR, TIP, None, "main", always)
        self.assertIsNone(v)

    def test_deleted_branch_fork_row_last_is_not_a_second_candidate(self):
        v, notes = rs.merged_by_pr([row(), self.fork()], BR, None, None, "main", always)
        self.assertEqual(v, "머지됨")
        self.assertIn("브랜치 끝 없이 판정 — 캐시의 headRefOid %s" % TIP[:8], notes)

    def test_deleted_branch_other_base_row_last_is_not_a_second_candidate(self):
        rows = [row(), row(base="release", oid=OLD, merge=M_OLD, num="#5")]
        v, _ = rs.merged_by_pr(rows, BR, None, None, "main", always)
        self.assertEqual(v, "머지됨")


class FakeGit:
    def __init__(self, ancestors=()):
        self.ancestors = set(ancestors)

    def is_ancestor(self, a, b):
        return (a, b) in self.ancestors


class MergedByGit(unittest.TestCase):
    MSG = [("d" * 40, ["e" * 40, "f" * 40], "Merge pull request #3 from o/feature/x")]

    def test_own_owner_message_counts(self):
        why = rs.merged_by_git(FakeGit(), self.MSG, "main", BR, None, "o")
        self.assertIn("머지 메시지", why or "")

    def test_owner_case_insensitive(self):
        self.assertIsNotNone(rs.merged_by_git(FakeGit(), self.MSG, "main", BR, None, "O"))

    def test_other_owner_message_is_not_counted(self):
        merges = [("d" * 40, ["e" * 40, "f" * 40], "Merge pull request #3 from other/feature/x")]
        self.assertIsNone(rs.merged_by_git(FakeGit(), merges, "main", BR, None, "o"))

    def test_unknown_owner_skips_message_path(self):
        self.assertIsNone(rs.merged_by_git(FakeGit(), self.MSG, "main", BR, None, None))

    def test_merge_commit_path_needs_no_owner(self):
        merges = [("d" * 40, ["e" * 40, TIP], "Merge branch 'feature/x'")]
        why = rs.merged_by_git(FakeGit(), merges, "main", BR, TIP, None)
        self.assertIn("머지 커밋", why or "")


if __name__ == "__main__":
    unittest.main()
