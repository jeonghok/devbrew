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
import conductor_status as CST  # noqa: E402
import leader_seat as LS  # noqa: E402
import repo_defaults  # noqa: E402
import roadmap_status as RS  # noqa: E402
import team_layout as TL  # noqa: E402
import team_status as TS  # noqa: E402
from state_path import state_root  # noqa: E402

RULE_DOC = repo_defaults.BRANCH_RULE_FILE   # 레포 브랜치 규칙 문서
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

    def foreign_edit(self, label="other", files=None, fetch=True):
        """둘째 클론이 상태 브랜치에 남의 고침을 올리고 첫 클론이 받아 온다(`fetch=False` 면 원격에만 둔다).
        부를 때마다 다른 클론 이름 · 다른 글을 준다."""
        other = self.clone(label)
        self.g("fetch", "-q", "origin", SPEC, repo=other)
        self.g("update-ref", "refs/heads/conductor/" + ALPHA, "refs/remotes/origin/conductor/" + ALPHA, repo=other)
        self.claim(repo=other, session=OTHER)
        files = files or {self.team.rules: TEAM_RULE + "\n- [남] %s · 조건: 역할=worker · 출처: a · 확인: b\n" % label}
        commit = self.write(files, repo=other, session=OTHER).commit
        if fetch:
            self.g("fetch", "-q", "origin", SPEC)
        return commit

    def ls(self, *args, root=None):
        """명령줄로 conductor_branch.py 를 부른다 — (종료 코드, 표준 출력 + 표준 오류). `root` 를 주면 그 폴더를 `--root` 와 cwd 로 준다."""
        p = subprocess.run([sys.executable, str(SCRIPTS / "conductor_branch.py"), "--root", str(root or self.w), *args],
                           capture_output=True, encoding="utf-8", cwd=str(root) if root else None)
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

    def test_tip_rolled_back_behind_the_confirmed_end_is_unmeasured(self):   # 마지막 리뷰 I1 — 확인 끝의 조상으로 되돌아간 끝을 믿지 않는다
        fa = self.foreign_edit("a")   # 남이 줄을 더한다
        fb = self.foreign_edit("b", {self.team.rules: TEAM_RULE + "\n"})   # 남이 그 줄을 뺀다 — 끝 상태는 깨끗하다
        LS.confirm(str(self.w), rm(ALPHA), SID, fb)
        self.assertEqual(self.tip_of(), (fb, []))   # 양성 대조 — 확인한 끝은 읽는다
        self.g("push", "-q", "--force", "origin", "%s:refs/heads/conductor/%s" % (fa, ALPHA), repo=self.t / "a")
        self.g("fetch", "-q", "origin", "+" + SPEC)
        self.assertEqual(self.tip(), fa)   # 양성 대조 — 읽을 끝이 확인 끝의 조상으로 갔다(로컬 ref 는 더 뒤다)
        self.assertEqual(self.tip_of(), (None, [LS.FOREIGN_UNMEASURED + TS.READ_DEFAULT_RULES]))

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


    def test_command_line_reset_from_a_subfolder_drops_the_copy(self):   # 마지막 리뷰 I3 — --root 가 하위 폴더여도 경로는 레포 뿌리 기준
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        self.assertIsNotNone(self.copy())   # 양성 대조
        rc, out = self.ls("rules-reset", "--roadmap", rm(ALPHA), "--session", SID, root=self.w / "docs")
        self.assertEqual(rc, 0, out)
        self.assertNotIn(LS.NO_COPY, out)
        self.assertEqual((self.copy(), self.base_line()), (None, None))

    def test_crlf_default_rules_compare_without_the_cr(self):   # 기본 브랜치 규칙이 CRLF 여도 줄 대조는 같다 — 다른 줄은 바이트 그대로 둔다
        self.put({self.team.rules: TEAM_RULE + "\r\n"})
        with self.assertRaises(CB.BranchError) as cm:
            LS.rules_edit(str(self.w), rm(ALPHA), SID, add=TEAM_RULE)
        self.assertEqual(cm.exception.rc, 2)   # 이미 있는 줄
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        self.assertEqual(self.copy(), TEAM_RULE + "\r\n" + NEW + "\r\n")
        LS.rules_edit(str(self.w), rm(ALPHA), SID, drop=TEAM_RULE)
        self.assertEqual(self.copy(), NEW + "\r\n")

    def test_marker_comes_before_the_off_switch(self):   # F14 — 표지(5) → 쓸 수 있는지 → 팀 차례 · 붉어지는 변이: 꺼짐을 먼저 본다
        self.put({".devbrew.md": "---\nstate_branch: 끔\n---\n"})
        with self.assertRaises(CB.BranchError) as cm:
            LS.rules_edit(str(self.w), rm(ALPHA), OTHER, add=NEW)
        self.assertEqual(cm.exception.rc, 5)
        res = LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)   # 양성 대조 — 표지를 쥔 세션은 꺼짐을 알리고 넘어간다
        self.assertEqual((res.commit, res.notes), (None, (CB.OFF_NOTE,)))

    def test_reset_of_an_own_copy_does_not_confirm(self):   # 남의 규칙 고침이 없으면 확인한 끝을 옮기지 않는다
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        res = LS.rules_edit(str(self.w), rm(ALPHA), SID, reset=True)
        self.assertIsNotNone(res.commit)
        self.assertNotIn(LS.RESET_DONE, res.notes)
        self.assertNotIn(cs.TRUST_WHY[0], [r["까닭"] for r in self.rows()])

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

    def test_refused_remake_writes_nothing(self):   # 마지막 리뷰 I2 — 다시 만들 때의 2 도 아무것도 쓰지 않는다 · 다음 sync 가 사본을 두 배로 만들지 않는다
        copy = TEAM_RULE + "\n" + NEW + "\n"
        theirs = self.foreign_edit("race", {self.team.rules: copy}, fetch=False)   # 원격에만 있다 — 첫 쓰기는 보지 못한다
        before, rows = self.local(), self.rows()
        with self.assertRaises(CB.BranchError) as cm:
            LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        self.assertEqual(cm.exception.rc, 2)
        self.assertEqual(self.g("rev-parse", "refs/remotes/origin/conductor/" + ALPHA), theirs)   # 양성 대조 — 다시 만들기까지 갔다
        self.assertEqual((self.local(), self.rows()), (before, rows))
        CST.sync(str(self.w), rm(ALPHA), SID)
        self.assertEqual(self.copy(), copy)

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

    def test_diverged_reset_refuses_without_writing(self):   # 갈라진 상태 브랜치 — 사본이 원격에만 있어도 「없다」 고 넘어가지 않는다
        self.foreign_edit()   # 남의 사본을 받아 왔다
        local = self.local()
        mine = self.g("commit-tree", self.g("rev-parse", local + "^{tree}"), "-p", local, "-m", "올리지 못한 내 커밋")
        self.g("update-ref", "refs/heads/conductor/" + ALPHA, mine, local)
        seen, split = CB.seen_tip(str(self.w), ALPHA)
        self.assertEqual((seen, bool(split)), (None, True))   # 양성 대조 — 정말 갈라졌다
        remote = self.g("rev-parse", "refs/remotes/origin/conductor/" + ALPHA)
        with self.assertRaises(CB.BranchError) as cm:
            LS.rules_edit(str(self.w), rm(ALPHA), SID, reset=True)
        self.assertEqual((cm.exception.rc, str(cm.exception)), (1, "%s — %s" % (LS.FOREIGN_UNMEASURED, CB.visible(split))))
        self.assertEqual((self.local(), self.g("rev-parse", "refs/remotes/origin/conductor/" + ALPHA)), (mine, remote))
        self.assertIsNotNone(CB.read(str(self.w), remote, self.team.rules))
        self.assertEqual(self.g("ls-remote", str(self.o), "refs/heads/conductor/" + ALPHA).split()[0], remote)

    def test_reset_with_an_unmeasured_pending_side_says_unmeasured(self):   # I11 — 재지 못함은 「남아 있다」 가 아니다
        old = self.write({self.team.rules: "- 옛 줄\n"}).commit
        mine = self.write({self.team.status: "s\n"}).commit
        other = self.clone("merger")   # 남의 머지 커밋 — 남의 고침 판정이 두 쪽 모두 None 이 된다
        self.g("fetch", "-q", "origin", SPEC, repo=other)
        tree = self.g("rev-parse", old + "^{tree}", repo=other)
        b = self.g("commit-tree", tree, "-p", old, "-m", "B", repo=other)
        m = self.g("commit-tree", tree, "-p", mine, "-p", b, "-m", "M", repo=other)
        self.g("push", "-q", "origin", "%s:refs/heads/conductor/%s" % (m, ALPHA), repo=other)
        self.g("fetch", "-q", "origin", SPEC)
        self.assertIsNone(LS.foreign(str(self.w), rm(ALPHA), m, TS.pending_paths(self.team)))   # 양성 대조
        res = LS.rules_edit(str(self.w), rm(ALPHA), SID, reset=True)
        self.assertIsNotNone(res.commit)
        self.assertIsNone(self.copy())
        self.assertEqual(res.notes[-1], LS.RESET_PENDING_UNMEASURED)
        self.assertTrue(res.notes[-1].startswith(LS.FOREIGN_UNMEASURED))
        self.assertNotIn(LS.RESET_PENDING_LEFT, res.notes)
        self.assertNotIn(cs.TRUST_WHY[0], [r["까닭"] for r in self.rows()])

    def test_moving_onto_the_fetched_tip_tells_elsewhere(self):   # AC3 — 앞당긴 끝은 다른 곳이 쓴 것이다 · 붉어지는 변이: 알림을 뺀다
        self.foreign_edit("o1", {self.team.status: "x\n"})
        seen = self.tip()
        res = LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        self.assertEqual(res.notes, (CB.ELSEWHERE % (seen[:8], CB._commit_stamp(str(self.w), seen)),))
        self.assertEqual(res.made, (res.commit,))   # 앞당긴 끝은 「씀」 이 아니다(B3)
        self.assertNotIn(seen, [r["끝"] for r in self.rows()])
        res = LS.rules_edit(str(self.w), rm(ALPHA), SID, drop=NEW)   # 양성 대조 — 로컬이 이미 읽을 끝이면 알리지 않는다
        self.assertEqual(res.notes, ())

    def test_reset_onto_the_fetched_tip_tells_elsewhere(self):
        self.foreign_edit()
        seen = self.tip()
        res = LS.rules_edit(str(self.w), rm(ALPHA), SID, reset=True)
        self.assertEqual(res.notes[0], CB.ELSEWHERE % (seen[:8], CB._commit_stamp(str(self.w), seen)))
        self.assertEqual(res.notes[-1], LS.RESET_DONE)

    def test_glyphs_are_the_read_side_constants(self):   # F9 — 다시 치지 않는다
        self.assertEqual((LS.FOREIGN, LS.FOREIGN_UNMEASURED, LS.RULES_BASE_FILE), (TS.FOREIGN, TS.FOREIGN_UNMEASURED, TS.RULES_BASE_FILE))


class RulesBranch(TeamRepo):   # R3 AC17
    def test_one_commit_one_file_from_the_default_branch(self):
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        main = self.g("rev-parse", "origin/trunk")
        before = self.snap()
        commit = LS.rules_branch(str(self.w), rm(ALPHA), SID, "chore/alpha-rules")
        self.assertEqual(self.g("rev-parse", "refs/heads/chore/alpha-rules"), commit)
        self.assertEqual(self.g("rev-parse", commit + "^"), main)
        self.assertEqual(self.g("diff-tree", "--no-commit-id", "--name-only", "-r", commit), self.team.rules)
        self.assertEqual(self.g("show", "%s:%s" % (commit, self.team.rules)), TEAM_RULE + "\n" + NEW)
        self.assertEqual(self.snap(), before)   # 작업 폴더를 건드리지 않는다

    def test_diverged_default_refuses_with_the_difference(self):   # 1 · 브랜치를 만들지 않는다
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        self.put({self.team.rules: "- [다른] 다른 손 · 조건: 역할=worker · 출처: a · 확인: b\n"})
        self.assertEqual(LS.rules_state(str(self.w), rm(ALPHA), self.tip()).verdict, "갈라짐")
        rc, out = self.ls("rules-branch", "--roadmap", rm(ALPHA), "--session", SID, "--branch", "chore/alpha-rules")
        self.assertEqual(rc, 1, out)
        self.assertIn(LS.DIVERGED, out)
        self.assertIn("다른 손", out)
        self.assertEqual(self.rc("rev-parse", "--verify", "-q", "refs/heads/chore/alpha-rules"), 1)

    def test_nothing_to_raise(self):
        with self.assertRaises(CB.BranchError) as cm:
            LS.rules_branch(str(self.w), rm(ALPHA), SID, "chore/alpha-rules")
        self.assertEqual((cm.exception.rc, LS.NOTHING in str(cm.exception)), (1, True))

    def test_refuses_state_prefix_and_existing_branch(self):
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        with self.assertRaises(CB.BranchError) as cm:
            LS.rules_branch(str(self.w), rm(ALPHA), SID, "conductor/x")
        self.assertEqual(cm.exception.rc, 2)
        self.g("branch", "chore/taken", "trunk")
        with self.assertRaises(CB.BranchError) as cm:
            LS.rules_branch(str(self.w), rm(ALPHA), SID, "chore/taken")
        self.assertEqual(cm.exception.rc, 3)

    def test_diverged_difference_lines_are_marked_and_visible(self):   # 남의 글은 visible 을 거쳐 줄마다 「│ 」 아래에 실린다
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        self.put({self.team.rules: "- [다른] 제어\x1b글자 · 조건: 역할=worker · 출처: a · 확인: b\n"})
        with self.assertRaises(CB.BranchError) as cm:
            LS.rules_branch(str(self.w), rm(ALPHA), SID, "chore/alpha-rules")
        lines = str(cm.exception).split("\n")
        self.assertEqual((cm.exception.rc, lines[0]), (1, LS.DIVERGED))
        self.assertGreater(len(lines), 1)
        self.assertEqual([l for l in lines[1:] if not l.startswith("│ ")], [])
        self.assertIn("│ +" + NEW, lines)
        self.assertIn("│ -- [다른] 제어\\x1b글자 · 조건: 역할=worker · 출처: a · 확인: b", lines)
        self.assertNotIn("\x1b", str(cm.exception))

    def test_command_line_codes(self):   # B2 — 하위 명령의 종료 코드와 마지막 줄 · 올리지 않는다
        args = ("rules-branch", "--roadmap", rm(ALPHA), "--session", SID, "--branch", "chore/alpha-rules")
        rc, out = self.ls(*args)
        self.assertEqual((rc, out.strip().splitlines()[-1:]), (1, ["[spec-distill] " + LS.NOTHING]), out)
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        rc, out = self.ls("rules-branch", "--roadmap", rm(ALPHA), "--session", OTHER, "--branch", "chore/alpha-rules")
        self.assertEqual(rc, 5, out)
        rc, out = self.ls(*args)
        commit = self.g("rev-parse", "refs/heads/chore/alpha-rules")
        self.assertEqual((rc, out.strip().splitlines()[-1:]),
                         (0, ["[spec-distill] " + LS.BRANCH_MADE % ("chore/alpha-rules", commit)]), out)
        self.assertEqual(self.g("ls-remote", str(self.o), "refs/heads/chore/alpha-rules"), "")   # 올리지 않는다
        rc, out = self.ls(*args)
        self.assertEqual(rc, 3, out)   # 이미 있다
        self.assertEqual(self.g("rev-parse", "refs/heads/chore/alpha-rules"), commit)
        rc, out = self.ls("rules-branch", "--roadmap", rm(ALPHA), "--session", SID)
        self.assertEqual(rc, 2, out)   # --branch 가 없다

    def test_refuses_a_name_git_would_not_take(self):   # 2 — 받지 않는 값 · 붉어지는 변이: 꼴 검사를 뺀다(3 이 된다)
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        before = self.refs()
        for name in ("", "-x", "a..b", "a b", "a.lock", "a/", "a//b", ".a", "HEAD", "a@{b", "a\x1bb"):
            with self.assertRaises(CB.BranchError) as cm:
                LS.rules_branch(str(self.w), rm(ALPHA), SID, name)
            self.assertEqual(cm.exception.rc, 2, repr(name))
        self.assertEqual(self.refs(), before)

    def test_repo_branch_rule_is_read_with_match(self):   # F10 — availability · project-init 훅과 같은 `match` 읽기
        self.put({RULE_DOC: "```regex\n^(chore|conductor)/[a-z0-9]+\n```\n"})
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        with self.assertRaises(CB.BranchError) as cm:
            LS.rules_branch(str(self.w), rm(ALPHA), SID, "fix/alpha-rules")
        self.assertEqual(cm.exception.rc, 2)
        self.assertEqual(self.rc("rev-parse", "--verify", "-q", "refs/heads/fix/alpha-rules"), 1)
        commit = LS.rules_branch(str(self.w), rm(ALPHA), SID, "chore/alpha-rules")   # 앞이 맞으면 받는다(fullmatch 가 아니다)
        self.assertEqual(self.g("rev-parse", "refs/heads/chore/alpha-rules"), commit)

    def test_command_line_from_a_subfolder_reads_the_repo_branch_rule(self):   # 마지막 리뷰 I3 — --root 가 하위 폴더여도 규칙 문서는 레포 뿌리 기준
        self.put({RULE_DOC: "```regex\n^(chore|conductor)/[a-z0-9-]+\n```\n"})
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        sub = self.w / "docs"
        rc, out = self.ls("rules-branch", "--roadmap", rm(ALPHA), "--session", SID, "--branch", "fix/alpha-rules", root=sub)
        self.assertEqual(rc, 2, out)
        self.assertEqual(self.rc("rev-parse", "--verify", "-q", "refs/heads/fix/alpha-rules"), 1)
        rc, out = self.ls("rules-branch", "--roadmap", rm(ALPHA), "--session", SID, "--branch", "chore/alpha-rules", root=sub)
        self.assertEqual(rc, 0, out)   # 양성 대조 — 규칙이 받는 이름은 하위 폴더에서도 만든다
        self.assertEqual(self.rc("rev-parse", "--verify", "-q", "refs/heads/chore/alpha-rules"), 0)

    def test_foreign_rules_edit_refuses(self):   # 규칙 쪽 남의 고침 — 1 · 만들지 않는다
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        self.foreign_edit()
        with self.assertRaises(CB.BranchError) as cm:
            LS.rules_branch(str(self.w), rm(ALPHA), SID, "chore/alpha-rules")
        self.assertEqual((cm.exception.rc, str(cm.exception)), (1, LS.FOREIGN % 1 + LS.REFUSE_TAIL))
        self.assertEqual(self.rc("rev-parse", "--verify", "-q", "refs/heads/chore/alpha-rules"), 1)

    def test_command_line_unmeasured_foreign_refuses(self):   # None 도 1 — 남의 머지 커밋이 규칙 경로에 있다 · 붉어지는 변이: None 갈래를 뺀다
        old = self.write({self.team.rules: "- 옛 줄\n"}).commit
        mine = self.write({self.team.status: "s\n"}).commit
        other = self.clone("merger")
        self.g("fetch", "-q", "origin", SPEC, repo=other)
        tree = self.g("rev-parse", old + "^{tree}", repo=other)
        b = self.g("commit-tree", tree, "-p", old, "-m", "B", repo=other)
        m = self.g("commit-tree", tree, "-p", mine, "-p", b, "-m", "M", repo=other)
        self.g("push", "-q", "origin", "%s:refs/heads/conductor/%s" % (m, ALPHA), repo=other)
        self.g("fetch", "-q", "origin", SPEC)
        self.assertIsNone(LS.foreign(str(self.w), rm(ALPHA), m, TS.rules_paths(self.team)))   # 양성 대조
        rc, out = self.ls("rules-branch", "--roadmap", rm(ALPHA), "--session", SID, "--branch", "chore/alpha-rules")
        self.assertEqual((rc, out.strip().splitlines()[-1:]),
                         (1, ["[spec-distill] " + LS.FOREIGN_UNMEASURED + LS.REFUSE_TAIL]), out)
        self.assertEqual(self.rc("rev-parse", "--verify", "-q", "refs/heads/chore/alpha-rules"), 1)

    def test_command_line_diverged_state_branch_refuses(self):   # 갈라진 상태 브랜치 — _read_tip 이 1 · 붉어지는 변이: 로컬 끝을 읽는다
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        self.foreign_edit("o1", {self.team.status: "x\n"})
        local = self.g("rev-parse", "refs/heads/conductor/" + ALPHA)
        mine = self.g("commit-tree", self.g("rev-parse", local + "^{tree}"), "-p", local, "-m", "올리지 못한 내 커밋")
        self.g("update-ref", "refs/heads/conductor/" + ALPHA, mine, local)
        seen, split = CB.seen_tip(str(self.w), ALPHA)
        self.assertEqual((seen, bool(split)), (None, True))   # 양성 대조 — 정말 갈라졌다
        rc, out = self.ls("rules-branch", "--roadmap", rm(ALPHA), "--session", SID, "--branch", "chore/alpha-rules")
        self.assertEqual((rc, out.strip().splitlines()[-1:]),
                         (1, ["[spec-distill] %s — %s" % (LS.FOREIGN_UNMEASURED, CB.visible(split))]), out)
        self.assertEqual(self.rc("rev-parse", "--verify", "-q", "refs/heads/chore/alpha-rules"), 1)

    def test_off_switch_tells_and_makes_nothing(self):   # 0 — 쓸 수 없어 알리고 넘어간다
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        self.put({".devbrew.md": "---\nstate_branch: 끔\n---\n"})
        rc, out = self.ls("rules-branch", "--roadmap", rm(ALPHA), "--session", SID, "--branch", "chore/alpha-rules")
        self.assertEqual((rc, out.strip().splitlines()[-1:]), (0, ["[spec-distill] " + CB.OFF_NOTE]), out)
        self.assertEqual(self.rc("rev-parse", "--verify", "-q", "refs/heads/chore/alpha-rules"), 1)


class RulesState(TeamRepo):   # M8 — 같아짐 · 갈라짐
    def state(self):
        return LS.rules_state(str(self.w), rm(ALPHA), self.tip())

    def test_verdicts(self):
        self.assertEqual(self.state(), LS.RulesState(None, None, TEAM_RULE + "\n", "없음"))
        main = self.g("rev-parse", "origin/trunk")
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        copy = TEAM_RULE + "\n" + NEW + "\n"
        self.assertEqual(self.state(), LS.RulesState(copy, main, TEAM_RULE + "\n", "올릴 것"))
        self.put({self.team.rules: copy})   # 머지 흉내
        self.assertEqual(self.state(), LS.RulesState(copy, main, copy, "같음"))

    def test_unreadable_base_line_is_diverged(self):   # 닫는 쪽 — rules-base.md 가 없거나 꼴 밖이거나 커밋이 이 레포에 없다
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        main = self.g("rev-parse", "origin/trunk")
        base = self.team.path(LS.RULES_BASE_FILE)
        for text in (None, LS.BASE_HEAD + main[:8] + "\n", LS.BASE_HEAD + main + "\n" + LS.BASE_HEAD + main + "\n",
                     LS.BASE_HEAD + main.upper() + "\n", LS.BASE_HEAD + "f" * 40 + "\n", " " + LS.BASE_HEAD + main + "\n"):
            self.write({base: text})
            got = self.state()
            self.assertEqual((got.base, got.verdict), (None, "갈라짐"), repr(text))
        self.write({base: LS.BASE_HEAD + main + "\n"})   # 양성 대조 — 바른 줄이면 올릴 것
        self.assertEqual(self.state().verdict, "올릴 것")


class Confirm(TeamRepo):   # R3 AC21 · Review Focus 1 · I4 · I10 · M36
    def test_report_then_confirm_with_the_shown_tip(self):
        self.foreign_edit()
        rc, out = self.ls("confirm", "--roadmap", rm(ALPHA), "--session", SID)   # 명령줄 — 보고가 잘리지 않는다(B2)
        self.assertEqual(rc, 1, out)
        self.assertIn("[남] other", out)
        tip = out.strip().splitlines()[-1].rsplit(LS.CONFIRM_TIP % "", 1)[1].strip()
        self.assertEqual(tip, self.tip())
        self.assertEqual(self.ls("confirm", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", tip[:8])[0], 2)   # I4
        rc, out = self.ls("confirm", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", tip)
        self.assertEqual(rc, 0, out)
        self.assertEqual([(r["끝"], r["까닭"]) for r in self.rows()], [(tip, "확인")])
        self.assertEqual(TS.rules_tip(RS.Git(str(self.w)), self.team, True, self.rows())[0], tip)   # 확인한 뒤에는 그 내용

    def test_a_tip_that_moved_after_the_report_is_not_confirmed(self):
        self.foreign_edit("o1")
        stale = self.tip()
        self.foreign_edit("o2")   # 보인 뒤에 또 들어온 남의 고침
        with self.assertRaises(CB.BranchError) as cm:
            LS.confirm(str(self.w), rm(ALPHA), SID, stale)
        self.assertEqual(cm.exception.rc, 1)
        self.assertEqual(str(cm.exception).split("\n")[-1], LS.CONFIRM_TIP % self.tip())   # 다시 센 보고 — 새 끝
        self.assertNotIn("확인", [r["까닭"] for r in self.rows()])

    def test_rules_edit_is_refused_by_a_real_foreign_commit(self):   # I10 — 판정 함수를 흉내 내지 않는다
        self.foreign_edit()
        before = self.tip()
        rc, out = self.ls("rules-add", "--roadmap", rm(ALPHA), "--session", SID, "--line", NEW)
        self.assertEqual(rc, 1, out)
        self.assertIn("확인되지 않은 남의 고침 1", out)
        self.assertEqual(self.tip(), before)

    def test_reset_withdraws_a_foreign_rule_edit(self):   # M36 — H2 (가)
        self.foreign_edit()
        LS.rules_edit(str(self.w), rm(ALPHA), SID, reset=True)
        self.assertIsNone(CB.read(str(self.w), self.tip(), self.team.rules))
        self.assertEqual([r["까닭"] for r in self.rows()], ["확인"])
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)   # 다시 열린다

    def test_reset_keeps_the_trust_base_when_pending_has_foreign_lines(self):   # F3 — 양성 단언: 사본은 지웠고 대기 줄 쪽 알림이 났다
        self.foreign_edit("o1", {self.team.rules: "- [남] r\n", self.team.path(CB.PENDING_FILE): "- A1 · 지휘 기록 · 남\n"})
        res = LS.rules_edit(str(self.w), rm(ALPHA), SID, reset=True)
        self.assertIsNotNone(res.commit)
        self.assertIsNone(CB.read(str(self.w), self.tip(), self.team.rules))
        self.assertEqual(res.notes[-1], LS.RESET_PENDING_LEFT)
        self.assertNotIn("확인", [r["까닭"] for r in self.rows()])

    def test_remade_write_does_not_launder_a_foreign_edit(self):   # Review Focus 1 · Deferred df3f1a6d
        self.foreign_edit()
        self.write({self.team.status: "y\n"})   # 남의 끝 위에 다시 만든 내 STATUS
        self.assertEqual(LS.settle(str(self.w), rm(ALPHA), SID, self.tip()), 1)
        self.assertIsNone(TS.rules_tip(RS.Git(str(self.w)), self.team, True, self.rows())[0])

    def test_rewritten_remote_does_not_launder_a_held_foreign_commit(self):   # 마지막 리뷰 C1 — 로컬에 든 남의 커밋이 원격에서 사라진 뒤의 다시 얹기
        evil = self.foreign_edit("evil")
        self.write({self.team.status: "s1\n", self.team.path("note.md"): "n1\n"})   # 남의 끝 위에 다시 만든다 — 로컬이 남의 커밋을 품는다
        # (note.md — STATUS 는 다시 얹지 않으므로 다시 얹은 내 커밋이 생기게 한다)
        local = "refs/heads/conductor/" + ALPHA
        self.assertEqual(self.rc("merge-base", "--is-ancestor", evil, local), 0)   # 양성 대조
        other = self.t / "evil"
        parent = self.g("rev-parse", evil + "^", repo=other)
        harmless = self.g("commit-tree", self.g("rev-parse", parent + "^{tree}", repo=other), "-p", parent, "-m", "무해", repo=other)
        self.g("push", "-q", "--force", "origin", "%s:%s" % (harmless, local), repo=other)   # 남의 커밋을 원격에서 뺀다
        res = self.write({self.team.status: "s2\n"})   # 거절 → 받아 와 올리지 못한 커밋들을 다시 얹는다
        tip = self.tip()
        remade = self.g("log", "--format=%H", "%s..%s" % (harmless, tip), "--", self.team.rules).split()
        self.assertEqual(len(remade), 1)   # 양성 대조 — 남의 고침이 다시 얹혔다
        self.assertIn("[남] evil", CB.read(str(self.w), tip, self.team.rules))
        ends = [r["끝"] for r in self.rows()]
        self.assertNotIn(remade[0], ends)
        self.assertNotIn(remade[0], res.made)
        mine = [c for c in self.g("log", "--format=%H", "%s..%s" % (harmless, tip)).split() if c != remade[0]]
        self.assertEqual((len(mine), [c for c in mine if c not in ends]), (2, []))   # 양성 대조 — 다시 얹은 내 커밋 · 이번 쓰기는 적는다
        self.assertEqual(TS.rules_tip(RS.Git(str(self.w)), self.team, True, self.rows()),
                         (None, [LS.FOREIGN % 1 + TS.READ_DEFAULT_RULES]))
        self.assertEqual(LS.settle(str(self.w), rm(ALPHA), SID, tip), 1)

    def test_settle_compacts_when_clean(self):
        self.write({self.team.status: "y\n"})
        self.assertEqual(LS.settle(str(self.w), rm(ALPHA), SID, self.tip()), 0)
        self.assertEqual([r["까닭"] for r in self.rows()], ["확인"])

    def test_unreadable_machine_state_is_three(self):   # I11 — confirm 이 기계 상태를 읽지 못하면
        path = cs.machine_path(state_root(str(self.w)), rm(ALPHA))
        path.write_text(path.read_text(encoding="utf-8") + "\n## 확인한 끝\n\n| 끝 | 까닭 | 때 | 세션 |\n|---|---|---|---|\n| x | 씀 | - | - |\n", encoding="utf-8")
        self.assertEqual(self.ls("confirm", "--roadmap", rm(ALPHA), "--session", SID)[0], 3)

    # ── 계획 밖으로 더한 것 — 경합 · 남의 머지 · 보이는 글 · 명령줄 종료 코드 · settle 의 줄이기 ──

    def test_foreign_edit_landing_during_rules_add_stays_unconfirmed(self):   # 과제 6 리뷰 — 검사와 올리기 사이에 원격에 든 남의 고침
        theirs = self.foreign_edit("race", fetch=False)   # 원격에만 있다 — rules-add 의 검사는 보지 못한다
        self.assertNotEqual(self.tip(), theirs)   # 양성 대조 — 첫 클론은 아직 받아 오지 않았다
        res = LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)   # 올리기 거절 → 받아 온 남의 끝 위에 다시 만든다
        self.assertEqual(res.onto, theirs)
        self.assertEqual(self.g("rev-parse", res.commit + "^"), theirs)
        self.assertNotIn(theirs, [r["끝"] for r in self.rows()])   # 남의 커밋은 「씀」 이 아니다(B3)
        self.assertEqual(LS.settle(str(self.w), rm(ALPHA), SID, self.tip()), 1)
        self.assertEqual(TS.rules_tip(RS.Git(str(self.w)), self.team, True, self.rows()),
                         (None, [LS.FOREIGN % 1 + TS.READ_DEFAULT_RULES]))
        rc, out = self.ls("confirm", "--roadmap", rm(ALPHA), "--session", SID)
        self.assertEqual(rc, 1, out)
        self.assertIn("[남] race", out)
        self.assertIn(theirs[:8] + " · ", out)
        rc, out = self.ls("confirm", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", self.tip())
        self.assertEqual(rc, 0, out)
        self.assertEqual(TS.rules_tip(RS.Git(str(self.w)), self.team, True, self.rows()), (self.tip(), []))

    def test_foreign_merge_shows_every_commit_not_written_here(self):   # I2 — 판정이 None 이면 범위의 남의 커밋 전부 · 머지 표시
        old = self.write({self.team.rules: "- 옛 줄\n"}).commit
        self.write({self.team.rules: "- 새 줄\n"})
        mine = self.write({self.team.status: "s\n"}).commit
        other = self.clone("merger")
        self.g("fetch", "-q", "origin", SPEC, repo=other)
        tree = self.g("rev-parse", old + "^{tree}", repo=other)
        b = self.g("commit-tree", tree, "-p", old, "-m", "B", repo=other)
        m = self.g("commit-tree", tree, "-p", mine, "-p", b, "-m", "M", repo=other)
        self.g("push", "-q", "origin", "%s:refs/heads/conductor/%s" % (m, ALPHA), repo=other)
        self.g("fetch", "-q", "origin", SPEC)
        self.assertIsNone(LS.foreign(str(self.w), rm(ALPHA), m, TS.rules_paths(self.team)))   # 양성 대조 — 판정은 재지 못함
        with self.assertRaises(CB.BranchError) as cm:
            LS.confirm(str(self.w), rm(ALPHA), SID)
        text = str(cm.exception)
        self.assertEqual(cm.exception.rc, 1)
        self.assertTrue(text.startswith(LS.FOREIGN_UNMEASURED), text)
        self.assertIn(m[:8] + " · ", text)
        self.assertIn(b[:8] + " · ", text)
        self.assertIn(LS.MERGE_MARK % 2, text)
        self.assertIn("│ +- 옛 줄", text)   # 머지가 첫째 부모(새 줄)에 견줘 규칙을 옛 글로 되돌렸다
        self.assertEqual(text.split("\n")[-1], LS.CONFIRM_TIP % m)
        tip, notes = LS.confirm(str(self.w), rm(ALPHA), SID, m)
        self.assertEqual((tip, [(r["끝"], r["까닭"]) for r in self.rows()]), (m, [(m, "확인")]))
        self.assertEqual(TS.rules_tip(RS.Git(str(self.w)), self.team, True, self.rows()), (m, []))

    def test_report_of_foreign_text_is_visible_and_names_both_sides(self):   # 남의 글은 visible 을 거쳐 「│ 」 아래에 · 대기 줄 쪽도 보인다
        self.foreign_edit("o1", {self.team.rules: "- [남] 제어\x1b글자\n", self.team.path(CB.PENDING_FILE): "- A1 · 지휘 기록 · 남\n"})
        with self.assertRaises(CB.BranchError) as cm:
            LS.confirm(str(self.w), rm(ALPHA), SID)
        lines = str(cm.exception).split("\n")
        self.assertEqual(lines[0], LS.FOREIGN % 1 + LS.CONFIRM_HOW)
        self.assertIn(self.team.rules, lines[1])
        self.assertIn(self.team.path(CB.PENDING_FILE), lines[1])
        self.assertIn("│ +- [남] 제어\\x1b글자", lines)
        self.assertIn("│ +- A1 · 지휘 기록 · 남", lines)
        self.assertEqual([l for l in lines[2:-1] if not l.startswith("│ ")], [])
        self.assertNotIn("\x1b", str(cm.exception))

    def test_command_line_codes(self):   # B2 — 종료 코드와 마지막 줄
        rc, out = self.ls("confirm", "--roadmap", rm(ALPHA), "--session", SID)
        self.assertEqual((rc, out.strip().splitlines()[-1:]), (0, ["[spec-distill] " + LS.NOTHING_TO_CONFIRM]), out)
        self.foreign_edit()
        rc, out = self.ls("confirm", "--roadmap", rm(ALPHA), "--session", OTHER)
        self.assertEqual(rc, 5, out)
        for bad in ("zz", self.tip().upper(), self.tip() + "0", ""):
            rc, out = self.ls("confirm", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", bad)
            self.assertEqual(rc, 2, (bad, out))
        rc, out = self.ls("confirm", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", self.tip())
        self.assertEqual((rc, out.strip().splitlines()[-1:]), (0, ["[spec-distill] " + LS.CONFIRMED % self.tip()]), out)
        self.assertEqual([(r["끝"], r["까닭"]) for r in self.rows()], [(self.tip(), "확인")])   # 절이 확인 한 줄뿐이다

    def test_diverged_state_branch_is_three(self):   # 갈라진 끝은 재지 못함 — 확인하지 않는다
        self.foreign_edit()
        local = self.g("rev-parse", "refs/heads/conductor/" + ALPHA)
        mine = self.g("commit-tree", self.g("rev-parse", local + "^{tree}"), "-p", local, "-m", "올리지 못한 내 커밋")
        self.g("update-ref", "refs/heads/conductor/" + ALPHA, mine, local)
        self.assertIsNone(CB.seen_tip(str(self.w), ALPHA)[0])   # 양성 대조 — 정말 갈라졌다
        rc, out = self.ls("confirm", "--roadmap", rm(ALPHA), "--session", SID)
        self.assertEqual(rc, 3, out)
        self.assertIn(LS.FOREIGN_UNMEASURED, out)

    def test_settle_trims_only_abandoned_own_rows_while_foreign_edits_remain(self):   # M5 — 범위 밖 「씀」 만 지운다
        self.foreign_edit()
        res = self.write({self.team.status: "y\n"})   # 거절 → 다시 만든다 — 처음 만든 커밋은 버려진다
        self.assertIsNotNone(res.onto)
        own = [r["끝"] for r in self.rows() if r["까닭"] == "씀"]
        self.assertEqual(len(res.made), 2)   # 양성 대조 — 버려진 커밋과 다시 만든 커밋
        self.assertTrue(set(res.made) <= set(own))
        self.assertEqual(LS.settle(str(self.w), rm(ALPHA), SID, self.tip()), 1)
        kept = [r["끝"] for r in self.rows() if r["까닭"] == "씀"]
        self.assertNotIn(res.made[0], kept)   # 버려진 커밋 줄은 지웠다
        self.assertIn(res.commit, kept)
        self.assertEqual(LS.settle(str(self.w), rm(ALPHA), SID, self.tip()), 1)   # 남의 고침은 그대로 센다

    def test_settle_tells_when_own_rows_pile_up(self):   # S13 — 남의 고침이 남아 「씀」 줄이 500 을 넘으면 알린다
        mine = self.write({self.team.status: "y\n"}).commit
        self.foreign_edit()
        path = cs.machine_path(state_root(str(self.w)), rm(ALPHA))

        def pad(total):   # 「씀」 줄을 total 개로 — 범위 안의 내 커밋 줄을 되풀이한다
            data = cs.load(path, rm(ALPHA))
            have = len([r for r in data[cs.TRUST] if r["까닭"] == "씀"])
            data[cs.TRUST] += [{"끝": mine, "까닭": "씀", "때": CB.stamp(), "세션": SID}] * (total - have)
            cs.save(path, rm(ALPHA), data, SID)
        pad(LS.OWN_ROWS_MAX)
        notes = []
        self.assertEqual(LS.settle(str(self.w), rm(ALPHA), SID, self.tip(), notes), 1)
        self.assertEqual(notes, [])   # 양성 대조 — 500 이면 알리지 않는다
        pad(LS.OWN_ROWS_MAX + 1)
        self.assertEqual(LS.settle(str(self.w), rm(ALPHA), SID, self.tip(), notes), 1)
        self.assertEqual(notes, [LS.LONG_FOREIGN])


if __name__ == "__main__":
    unittest.main()
