#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""리더 자리 — 상태 브랜치의 규칙 사본 · 남의 고침 판정 · 규칙을 읽을 끝.

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_leader_seat.py
"""
from __future__ import annotations

import os
import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
from conductor_branch_fixture import ALPHA, OTHER, ROADMAPS, SCRIPTS, SID, StateRepo, rm, roadmap_text  # noqa: E402
import conductor_branch as CB  # noqa: E402
import conductor_state as cs  # noqa: E402
import leader_seat as LS  # noqa: E402
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

    def test_foreign_copy_is_counted_from_a_subfolder(self):   # 경로 인자는 레포 뿌리 기준이다 — cwd 가 하위 폴더여도 같다
        self.foreign_edit()
        got = TS.rules_tip(RS.Git(str(self.w / ROADMAPS)), self.team, True, self.rows())
        self.assertEqual(got, (None, ["확인되지 않은 남의 고침 1 — 규칙은 기본 브랜치의 글을 읽는다"]))

    def test_literal_pathspec_env_does_not_hide_the_foreign_copy(self):   # GIT_LITERAL_PATHSPECS 가 `:(top,literal)` 을 글자로 읽게 하지 않는다
        self.foreign_edit()
        with mock.patch.dict(os.environ, {"GIT_LITERAL_PATHSPECS": "1"}):
            got = TS.rules_tip(RS.Git(str(self.w / ROADMAPS)), self.team, True, self.rows())
        self.assertEqual(got, (None, ["확인되지 않은 남의 고침 1 — 규칙은 기본 브랜치의 글을 읽는다"]))

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


NEW = "- [둘] 새 줄 · 조건: 역할=worker · 출처: a · 확인: b"


class RulesEdit(TeamRepo):   # R3 AC17 · AC21
    def copy(self):
        return CB.read(str(self.w), self.tip(), self.team.rules)

    def base_line(self):
        return CB.read(str(self.w), self.tip(), self.team.path(LS.RULES_BASE_FILE))

    def test_first_edit_makes_the_copy_from_the_default_branch_and_records_the_base(self):
        main = self.g("rev-parse", "origin/trunk")
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        self.assertEqual(self.copy(), TEAM_RULE + "\n" + NEW + "\n")
        self.assertEqual(self.base_line(), LS.BASE_HEAD + main + "\n")

    def test_drop_then_reset(self):
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        LS.rules_edit(str(self.w), rm(ALPHA), SID, drop=TEAM_RULE)
        self.assertEqual(self.copy(), NEW + "\n")
        LS.rules_edit(str(self.w), rm(ALPHA), SID, reset=True)
        self.assertIsNone(self.copy())
        self.assertIsNone(self.base_line())

    def test_refuses_bad_or_pointless_lines(self):   # 2 — 아무것도 쓰지 않는다
        before = self.tip()
        for kw in ({"add": "- 태그 없는 줄"}, {"add": TEAM_RULE}, {"drop": NEW}):
            with self.assertRaises(CB.BranchError) as cm:
                LS.rules_edit(str(self.w), rm(ALPHA), SID, **kw)
            self.assertEqual(cm.exception.rc, 2, kw)
        self.assertEqual(self.tip(), before)

    def test_command_line_keeps_the_codes(self):   # B2 — 명령줄의 종료 코드와 마지막 줄
        rc, out = self.ls("rules-add", "--roadmap", rm(ALPHA), "--session", SID, "--line", "- 태그 없는 줄")
        self.assertEqual(rc, 2, out)
        rc, out = self.ls("rules-add", "--roadmap", rm(ALPHA), "--session", OTHER, "--line", NEW)
        self.assertEqual(rc, 5, out)
        rc, out = self.ls("rules-add", "--roadmap", rm(ALPHA), "--session", SID, "--line", NEW)
        self.assertEqual(rc, 0, out)

    def test_refuses_a_line_that_would_split(self):   # 2 — 줄 하나는 한 줄이다(줄바꿈 · 제어 글자를 받지 않는다)
        before = self.tip()
        for line in (NEW + "\n" + TEAM_RULE, NEW + "\r", NEW + " x"):
            with self.assertRaises(CB.BranchError) as cm:
                LS.rules_edit(str(self.w), rm(ALPHA), SID, add=line)
            self.assertEqual(cm.exception.rc, 2, repr(line))
        self.assertEqual(self.tip(), before)

    def test_reset_without_a_copy_writes_nothing(self):
        before = self.tip()
        res = LS.rules_edit(str(self.w), rm(ALPHA), SID, reset=True)
        self.assertEqual((res.commit, res.notes[-1:]), (None, (LS.NO_COPY,)))
        self.assertEqual(self.tip(), before)

    def test_command_line_drop_and_reset(self):   # B2 — 하위 명령마다 종료 코드와 마지막 줄
        rc, out = self.ls("rules-drop", "--roadmap", rm(ALPHA), "--session", SID, "--line", NEW)
        self.assertEqual(rc, 2, out)
        rc, out = self.ls("rules-reset", "--roadmap", rm(ALPHA), "--session", SID)
        self.assertEqual((rc, out.strip().splitlines()[-1:]), (0, ["[spec-distill] " + LS.NO_COPY]), out)
        rc, out = self.ls("rules-add", "--roadmap", rm(ALPHA), "--session", SID, "--line", NEW)
        self.assertEqual(rc, 0, out)
        rc, out = self.ls("rules-drop", "--roadmap", rm(ALPHA), "--session", SID, "--line", NEW)
        self.assertEqual((rc, self.copy()), (0, TEAM_RULE + "\n"), out)
        rc, out = self.ls("rules-reset", "--roadmap", rm(ALPHA), "--session", OTHER)
        self.assertEqual(rc, 5, out)
        rc, out = self.ls("rules-reset", "--roadmap", rm(ALPHA), "--session", SID)
        self.assertEqual((rc, self.copy()), (0, None), out)


class RulesEditForeign(TeamRepo):   # R3 AC21 · M36 — 남의 고침은 읽을 끝에서 재고, 쓰기는 받아 온 끝 위에서 한다
    def copy(self):
        return CB.read(str(self.w), self.tip(), self.team.rules)

    def local(self):
        return self.g("rev-parse", "refs/heads/conductor/" + ALPHA)

    def test_foreign_rules_edit_refuses_add_and_drop(self):   # 붉어지는 변이: 검사가 로컬 끝을 읽는다
        self.foreign_edit()
        before, text = self.tip(), self.copy()
        self.assertNotEqual(self.local(), before)   # 양성 대조 — 남의 끝은 받아 오기만 했다(로컬 ref 는 뒤다)
        for kw in ({"add": NEW}, {"drop": TEAM_RULE}):
            with self.assertRaises(CB.BranchError) as cm:
                LS.rules_edit(str(self.w), rm(ALPHA), SID, **kw)
            self.assertEqual((cm.exception.rc, str(cm.exception)), (1, LS.FOREIGN % 1 + LS.REFUSE_TAIL), kw)
        self.assertEqual((self.tip(), self.copy()), (before, text))
        rc, out = self.ls("rules-add", "--roadmap", rm(ALPHA), "--session", SID, "--line", NEW)
        self.assertEqual((rc, out.strip().splitlines()[-1:]), (1, ["[spec-distill] " + LS.FOREIGN % 1 + LS.REFUSE_TAIL]), out)

    def test_unmeasured_refuses_add(self):   # I11 — 기계 상태를 읽지 못하면 재지 못했다로 닫는다
        path = cs.machine_path(state_root(str(self.w)), rm(ALPHA))
        keep = path.with_name("kept.md")
        os.replace(str(path), str(keep))
        os.symlink(str(keep), str(path))   # 링크인 기계 상태는 읽지 않는다
        before = self.tip()
        with self.assertRaises(CB.BranchError) as cm:
            LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        self.assertEqual((cm.exception.rc, str(cm.exception)), (1, LS.FOREIGN_UNMEASURED + LS.REFUSE_TAIL))
        self.assertEqual(self.tip(), before)

    def test_add_builds_on_the_fetched_tip(self):   # F3 — 받아 온 끝(남이 STATUS 만 고침) 위에서 쓴다 · 붉어지는 변이: 앞당기기를 뺀다
        self.foreign_edit("o1", {self.team.status: "x\n"})
        seen = self.tip()
        self.assertNotEqual(self.local(), seen)   # 양성 대조 — 로컬 ref 는 뒤다
        res = LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        self.assertEqual((res.pushed, res.onto), (True, None))   # 다시 만들지 않았다
        self.assertEqual(self.g("rev-parse", res.commit + "^"), seen)
        self.assertEqual(res.made, (res.commit,))

    def test_reset_after_fetch_drops_the_foreign_copy_and_confirms(self):   # M36 (가) · F3 — 붉어지는 변이: 앞당기기를 뺀다
        self.foreign_edit()   # 남이 사본을 만들었다 — 받아 오기만 했다
        self.assertIsNotNone(self.copy())
        self.assertIsNone(CB.read(str(self.w), self.local(), self.team.rules))   # 양성 대조 — 로컬 끝에는 사본이 없다
        res = LS.rules_edit(str(self.w), rm(ALPHA), SID, reset=True)
        self.assertIsNotNone(res.commit)
        self.assertEqual((self.tip(), self.copy()), (res.commit, None))
        self.assertEqual(res.notes[-1], LS.RESET_DONE)
        self.assertEqual(TS.trust_of(self.rows()), (res.commit, frozenset()))
        self.assertEqual([r["까닭"] for r in self.rows()], [cs.TRUST_WHY[0]])   # 한 줄로 둔다
        self.assertEqual(TS.rules_tip(RS.Git(str(self.w)), self.team, True, self.rows()), (None, []))

    def test_reset_keeps_the_confirmed_end_while_pending_has_foreign_edits(self):   # 붉어지는 변이: 대기 줄 쪽을 보지 않는다
        self.foreign_edit("o1")
        self.foreign_edit("o2", {self.team.path(CB.PENDING_FILE): "- 남의 대기 줄\n"})
        res = LS.rules_edit(str(self.w), rm(ALPHA), SID, reset=True)
        self.assertIsNotNone(res.commit)
        self.assertIsNone(self.copy())
        self.assertEqual(res.notes[-1], LS.RESET_PENDING_LEFT)
        self.assertIsNone(TS.trust_of(self.rows())[0])
        self.assertNotIn(cs.TRUST_WHY[0], [r["까닭"] for r in self.rows()])

    def test_glyphs_are_the_read_side_constants(self):   # F9 — 다시 치지 않는다
        self.assertEqual((LS.FOREIGN, LS.FOREIGN_UNMEASURED, LS.RULES_BASE_FILE), (TS.FOREIGN, TS.FOREIGN_UNMEASURED, TS.RULES_BASE_FILE))


if __name__ == "__main__":
    unittest.main()
