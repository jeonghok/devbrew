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
        v, notes = rs.merged_by_pr([row(cross="예")], BR, None, None, "main", always, started=True)
        self.assertIsNone(v)
        self.assertFalse(any("브랜치 끝 없이 판정" in n for n in notes), notes)

    def test_reused_name_old_pr_is_not_merged(self):             # 옛 MERGED 의 headRefOid ≠ 끝
        v, _ = rs.merged_by_pr([row(oid=OLD, merge=M_OLD)], BR, TIP, None, "main", always)
        self.assertIsNone(v)

    def test_non_default_base_is_not_merged(self):
        v, _ = rs.merged_by_pr([row(base="release")], BR, TIP, None, "main", always)
        self.assertIsNone(v)

    def test_non_default_base_when_branch_deleted(self):
        v, _ = rs.merged_by_pr([row(base="release")], BR, None, None, "main", always, started=True)
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

    def test_deleted_branch_single_row_notices(self):             # 시작한 에픽의 지운 브랜치(양의 짝)
        v, notes = rs.merged_by_pr([row(oid=OLD, merge=M_OLD)], BR, None, None, "main", always, started=True)
        self.assertEqual(v, "머지됨")
        self.assertIn("브랜치 끝 없이 판정 — 캐시의 headRefOid %s" % OLD[:8], notes)

    def test_never_created_branch_old_merged_pr_is_not_merged(self):  # AC15 — 만들기 전 브랜치 이름의 옛 MERGED PR
        v, notes = rs.merged_by_pr([row(oid=OLD, merge=M_OLD, num="#1")], BR, None, None, "main", always)
        self.assertIsNone(v)
        self.assertEqual(notes, ["브랜치가 없다 — 같은 이름의 옛 PR #1 은 이 에픽의 PR 로 세지 않았다(이 에픽의 승인된 "
                                 "설계문서나 계획이 기본 브랜치에 없어 아직 만들지 않은 브랜치로 본다) — 지운 브랜치면 "
                                 "`git branch feature/x %s` 로 되살리거나, 설계문서의 승인 줄 · 계획의 `**Spec:**` 를 "
                                 "확인한다" % OLD])

    def test_never_created_notice_quotes_unsafe_branch_name(self):
        br = "fix/it's ; rm"
        _v, notes = rs.merged_by_pr([row(branch=br, oid=OLD, merge=M_OLD)], br, None, None, "main", always)
        self.assertIn("`git branch 'fix/it'\\''s ; rm' %s`" % OLD, notes[0])

    def test_never_created_branch_two_old_prs_is_not_uncountable(self):
        rows = [row(oid=OLD, merge=M_OLD, num="#3"), row(oid=TIP, merge=M, num="#9")]
        v, notes = rs.merged_by_pr(rows, BR, None, None, "main", always)
        self.assertIsNone(v)
        self.assertTrue(notes and notes[0].startswith("브랜치가 없다 — 같은 이름의 옛 PR #3 · #9 은"), notes)
        self.assertIn("`git branch feature/x <headRefOid>`", notes[0])

    def test_never_started_but_tip_present_still_judged(self):    # 끝이 있으면 시작 흔적을 묻지 않는다
        v, _ = rs.merged_by_pr([row()], BR, TIP, None, "main", always, started=False)
        self.assertEqual(v, "머지됨")

    def test_deleted_branch_two_rows_is_uncountable(self):
        rows = [row(oid=OLD, merge=M_OLD, num="#3"), row(oid=TIP, merge=M, num="#9")]
        v, notes = rs.merged_by_pr(rows, BR, None, None, "main", always, started=True)
        self.assertEqual(v, "셀 수 없음")
        self.assertEqual(notes, ["셀 수 없음 — 같은 이름의 머지된 PR 이 여럿이고 브랜치 끝이 없다(#3 · #9) — 브랜치를 맞는 PR 의 "
                                 "headRefOid 로 되살린다(`git branch feature/x <headRefOid>`)"])

    def test_deleted_branch_two_rows_same_oid_is_one_tip(self):
        rows = [row(num="#3"), row(num="#9")]
        v, _ = rs.merged_by_pr(rows, BR, None, None, "main", always, started=True)
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
        v, notes = rs.merged_by_pr([row(), self.fork()], BR, None, None, "main", always, started=True)
        self.assertEqual(v, "머지됨")
        self.assertIn("브랜치 끝 없이 판정 — 캐시의 headRefOid %s" % TIP[:8], notes)

    def test_deleted_branch_other_base_row_last_is_not_a_second_candidate(self):
        rows = [row(), row(base="release", oid=OLD, merge=M_OLD, num="#5")]
        v, _ = rs.merged_by_pr(rows, BR, None, None, "main", always, started=True)
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


class MergeCommitBeforePrCache(unittest.TestCase):
    """PR 캐시에 줄이 있어도 끝이 기본 브랜치 머지 커밋의 부모면 머지됨 — 로컬 끝, 또는 로컬이 기본 브랜치에 다 든 원격 끝."""
    MERGES = [(M, ["e" * 40, TIP], "Merge pull request #7 from o/feature/x")]

    def test_local_tip_is_merge_parent(self):                      # 로컬 끝이 PR head 보다 앞이어도
        why = rs.merged_by_tips(FakeGit(), [(M, ["e" * 40, NEW], "Merge branch 'feature/x'")], "main", NEW, TIP)
        self.assertEqual(why, "기본 브랜치의 머지 커밋 %s" % M[:8])

    def test_remote_tip_is_merge_parent_stale_local(self):         # 로컬이 원격의 조상(받기만 함) — 로컬은 기본 브랜치 안
        why = rs.merged_by_tips(FakeGit({(OLD, "main"), (OLD, TIP)}), self.MERGES, "main", OLD, TIP)
        self.assertEqual(why, "기본 브랜치의 머지 커밋 %s(원격 끝)" % M[:8])

    def test_remote_tip_is_merge_parent_local_fast_forwarded(self):  # 로컬을 기본 브랜치로 앞당김
        why = rs.merged_by_tips(FakeGit({(NEW, "main")}), self.MERGES, "main", NEW, TIP)
        self.assertEqual(why, "기본 브랜치의 머지 커밋 %s(원격 끝)" % M[:8])

    def test_remote_tip_is_merge_parent_no_local(self):
        self.assertIsNotNone(rs.merged_by_tips(FakeGit(), self.MERGES, "main", None, TIP))

    def test_local_commits_outside_main_is_not_merged(self):       # AC15 — 머지 뒤 기본 브랜치 밖 커밋
        self.assertIsNone(rs.merged_by_tips(FakeGit({(TIP, NEW)}), self.MERGES, "main", NEW, TIP))

    def test_reused_name_tip_not_a_merge_parent(self):             # AC15 — 새 브랜치 끝은 옛 머지 커밋의 부모가 아니다
        self.assertIsNone(rs.merged_by_tips(FakeGit(), self.MERGES, "main", NEW, None))

    def test_tip_already_in_first_parent_is_not_merged(self):      # 끝이 머지 전에 이미 기본 브랜치에 있었다
        self.assertIsNone(rs.merged_by_tips(FakeGit({(TIP, "e" * 40)}), self.MERGES, "main", TIP, None))


class StaleLocalTip(unittest.TestCase):
    """로컬 끝이 원격 끝의 조상이면 PR 의 headRefOid 를 원격 끝과 견준다(squash · rebase)."""

    def test_stale_local_uses_remote_tip(self):
        v, notes = rs.merged_by_pr([row(oid=TIP)], BR, OLD, TIP, "main", always, stale_local=True)
        self.assertEqual(v, "머지됨")
        self.assertIn("로컬 끝 %s 이 원격 끝 %s 보다 뒤라 원격 끝으로 판정" % (OLD[:8], TIP[:8]), notes)

    def test_not_stale_local_ahead_is_not_merged(self):            # 짝: 로컬이 앞(기본 브랜치 밖 커밋)이면 로컬 끝
        v, notes = rs.merged_by_pr([row(oid=TIP)], BR, NEW, TIP, "main", always, stale_local=False)
        self.assertIsNone(v)
        self.assertIn("로컬 끝 %s · 원격 끝 %s" % (NEW[:8], TIP[:8]), notes)

    def test_stale_local_remote_ahead_of_pr_head_is_not_merged(self):  # 머지 뒤 원격에 커밋이 더 붙음
        v, _ = rs.merged_by_pr([row(oid=OLD, merge=M_OLD)], BR, OLD, TIP, "main", always, stale_local=True)
        self.assertIsNone(v)


if __name__ == "__main__":
    unittest.main()
