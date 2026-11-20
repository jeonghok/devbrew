#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""리더 자리 — 상태 브랜치의 규칙 사본 · 남의 고침 판정 · 규칙을 읽을 끝.

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_leader_seat.py
"""
from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock  # noqa: F401

sys.path.insert(0, str(Path(__file__).resolve().parent))
from conductor_branch_fixture import ALPHA, OTHER, ROADMAPS, SCRIPTS, SID, StateRepo, rm, roadmap_text  # noqa: E402
import conductor_branch as CB  # noqa: E402
import conductor_state as cs  # noqa: E402
import roadmap_status as RS  # noqa: E402
import team_layout as TL  # noqa: E402
import team_status as TS  # noqa: E402
from state_path import state_root  # noqa: E402

TEAM_RULE = "- [하나] 고친 곳엔 테스트 먼저 · 조건: 역할=worker · 출처: a · 확인: b"
SPEC = "refs/heads/conductor/%s:refs/remotes/origin/conductor/%s" % (ALPHA, ALPHA)


class TeamRepo(StateRepo):
    """ALPHA 를 team 형식(머리말 layout: team)으로 다시 쓰고 기본 브랜치에 규칙 파일 한 줄을 둔다.
    상태 계산을 거치지 않는 함수(leader_seat · team_status 의 남의 고침 판정)만 이 픽스처로 잰다."""
    def setUp(self):
        super().setUp()
        self.team = TL.Team(ROADMAPS, ALPHA)
        head = roadmap_text("알파 — 로드맵", self.ALPHA_BLOCKS).replace("type: roadmap\n", "type: roadmap\nlayout: team\n", 1)
        self.put({rm(ALPHA): head, self.team.rules: TEAM_RULE + "\n"})
        self.claim()
        CB.ensure(str(self.w), rm(ALPHA), SID)

    def rows(self, repo=None):
        return cs.load(cs.machine_path(state_root(str(repo or self.w)), rm(ALPHA)), rm(ALPHA))[cs.TRUST]

    def write(self, files, repo=None, session=SID):
        return CB.write(str(repo or self.w), rm(ALPHA), session, lambda b: files, "시험")

    def tip(self, repo=None):
        return CB.seen_tip(str(repo or self.w), ALPHA)[0]

    def foreign_edit(self, label="other", files=None):
        """둘째 클론이 상태 브랜치에 남의 고침을 올리고 첫 클론이 받아 온다. 부를 때마다 다른 클론 이름 · 다른 글을 준다."""
        other = self.clone(label)
        self.g("fetch", "-q", "origin", SPEC, repo=other)
        self.g("update-ref", "refs/heads/conductor/" + ALPHA, "refs/remotes/origin/conductor/" + ALPHA, repo=other)
        self.claim(repo=other, session=OTHER)
        files = files or {self.team.rules: TEAM_RULE + "\n- [남] %s · 조건: 역할=worker · 출처: a · 확인: b\n" % label}
        commit = self.write(files, repo=other, session=OTHER).commit
        self.g("fetch", "-q", "origin", SPEC)
        return commit

    def ls(self, *args):
        """명령줄로 conductor_branch.py 를 부른다 — (종료 코드, 표준 출력 + 표준 오류)."""
        p = subprocess.run([sys.executable, str(SCRIPTS / "conductor_branch.py"), "--root", str(self.w), *args],
                           capture_output=True, encoding="utf-8")
        return p.returncode, p.stdout + p.stderr


class RulesTip(TeamRepo):   # R3 AC15 · AC21 · AC14
    def tip_of(self, on=True, rows="load"):
        return TS.rules_tip(RS.Git(str(self.w)), self.team, on, self.rows() if rows == "load" else rows)

    def test_no_copy_means_default(self):
        self.assertEqual(self.tip_of(), (None, []))

    def test_own_copy_is_read(self):
        res = self.write({self.team.rules: TEAM_RULE + "\n- [둘] 새 줄 · 조건: 역할=worker · 출처: a · 확인: b\n"})
        self.assertEqual(self.tip_of(), (res.commit, []))
        self.assertEqual(TL.leader_ref("refs/remotes/origin/HEAD", res.commit), res.commit)

    def test_off_means_default_even_with_a_copy(self):   # AC14
        self.write({self.team.rules: "- 사본\n"})
        self.assertEqual(self.tip_of(on=False), (None, []))

    def test_foreign_copy_is_not_read_until_confirmed(self):   # AC21 — 남의 고침
        self.foreign_edit()
        tip, notes = self.tip_of()
        self.assertIsNone(tip)
        self.assertEqual(notes, ["확인되지 않은 남의 고침 1 — 규칙은 기본 브랜치의 글을 읽는다"])

    def test_unreadable_machine_state_closes(self):   # I11 — 한 뜻: 재지 못함
        self.write({self.team.rules: "- 사본\n"})
        tip, notes = self.tip_of(rows=None)
        self.assertIsNone(tip)
        self.assertEqual(notes, ["남의 고침을 재지 못했다 — 규칙은 기본 브랜치의 글을 읽는다"])


class Foreign(TeamRepo):
    def trust(self):
        return TS.trust_of(self.rows())

    def test_only_the_named_paths_count(self):   # 남이 STATUS 만 바꾼 커밋은 세지 않는다
        git = RS.Git(str(self.w))
        fake = self.foreign_edit("o1", {self.team.status: "x\n"})
        self.assertEqual(TS.foreign_commits(git, self.tip(), self.trust(), TS.rules_paths(self.team)), [])
        moved = self.foreign_edit("o2")
        got = TS.foreign_commits(git, self.tip(), self.trust(), TS.rules_paths(self.team))
        self.assertEqual(got, [(moved, (self.team.rules,))])
        self.assertNotIn(fake, [c for c, _p in got])

    def test_own_commits_are_not_foreign(self):
        mine = self.write({self.team.rules: "- 내 줄\n"}).commit
        self.assertEqual(TS.foreign_commits(RS.Git(str(self.w)), mine, self.trust(), TS.rules_paths(self.team)), [])

    def test_git_failure_or_missing_base_is_none_not_empty(self):
        git = RS.Git(str(self.w))
        self.assertIsNone(TS.foreign_commits(git, "f" * 40, self.trust(), TS.rules_paths(self.team)))
        self.assertIsNone(TS.foreign_commits(git, self.tip(), ("e" * 40, frozenset()), TS.rules_paths(self.team)))

    def test_foreign_merge_back_to_an_old_copy_is_not_hidden(self):   # I2 — 경로 한정 log 의 이력 단순화가 숨기는 머지
        old = self.write({self.team.rules: "- 옛 줄\n"}).commit
        self.write({self.team.rules: "- 새 줄\n"})
        mine = self.write({self.team.status: "s\n"}).commit
        other = self.clone("merger")   # 남의 기계 흉내: old 위에 규칙을 건드리지 않는 커밋 B, 그리고 머지 M(mine, B) 의 규칙 = 옛 줄
        self.g("fetch", "-q", "origin", SPEC, repo=other)
        b_tree = self.g("rev-parse", old + "^{tree}", repo=other)
        b = self.g("commit-tree", b_tree, "-p", old, "-m", "B", repo=other)
        m_tree = self.g("rev-parse", old + "^{tree}", repo=other)   # 규칙 = 옛 줄 · STATUS 는 없어도 된다 — 숨김은 규칙 경로에서 일어난다
        m = self.g("commit-tree", m_tree, "-p", mine, "-p", b, "-m", "M", repo=other)
        self.g("push", "-q", "origin", "%s:refs/heads/conductor/%s" % (m, ALPHA), repo=other)
        self.g("fetch", "-q", "origin", SPEC)
        git = RS.Git(str(self.w))
        hidden = git.run("log", "--format=%H", "%s..%s" % (mine, m), "--", self.team.rules)[1].split()
        self.assertEqual(hidden, [])   # 양성 대조 — 기본 이력 단순화는 정말 숨긴다(고치기 전의 꼴은 0 으로 읽힌다)
        self.assertIsNone(TS.foreign_commits(git, m, self.trust(), TS.rules_paths(self.team)))   # 닫는 쪽
        self.assertIsNone(TS.rules_tip(git, self.team, True, self.rows())[0])

    def test_columns_match_the_machine_state(self):   # M30 — 붉어지는 변이: 한쪽 글자를 바꾼다
        self.assertEqual((TS.TRUST_WHY, TS.TRUST_COLUMNS), (cs.TRUST_WHY, cs.COLUMNS[cs.TRUST]))
        self.assertEqual(TS.pending_paths(self.team), [self.team.path(CB.PENDING_FILE)])


if __name__ == "__main__":
    unittest.main()
