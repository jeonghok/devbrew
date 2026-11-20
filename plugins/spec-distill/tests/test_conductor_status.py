#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_status.py — STATUS 의 꼴 · 계산 · sync · waiting.

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_conductor_status.py
"""
from __future__ import annotations

import datetime
import os
import socket
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from conductor_branch_fixture import ALPHA, BETA, ENV, OTHER, SCRIPTS, SID, StateRepo, rm  # noqa: E402
import conductor_branch as CB  # noqa: E402
import conductor_ledger as L  # noqa: E402
import conductor_mail as CM  # noqa: E402
import conductor_state as cs  # noqa: E402
import conductor_status as CS  # noqa: E402

KST = datetime.timezone(datetime.timedelta(hours=9))
T0 = datetime.datetime(2026, 11, 19, 2, 30, tzinfo=KST)


def at(minutes):
    return T0 + datetime.timedelta(minutes=minutes)


def cli(repo, *args):
    p = subprocess.run([sys.executable, str(SCRIPTS / "conductor_status.py"), "--root", str(repo), *args],
                       cwd=str(repo), env=ENV, capture_output=True, encoding="utf-8")
    return p.returncode, p.stdout + p.stderr


class StatusRepo(StateRepo):
    def setUp(self):
        super().setUp()
        self.mdir = self.claim()
        CB.ensure(self.w, rm(ALPHA), SID)
        self.team = CB.team_of(self.w, rm(ALPHA))

    def machine(self, change):
        return L.update(self.w, rm(ALPHA), SID, change)

    def status_text(self):
        return CB.read(self.w, CB.local_tip(self.w, ALPHA), self.team.status)


class Shape(StatusRepo):
    def test_sections_order_and_empty_lines(self):
        CS.sync(self.w, rm(ALPHA), SID, now=T0)
        base = self.g("rev-parse", "origin/trunk")[:8]
        self.assertEqual(self.status_text(), (
            "# STATUS — 알파 — 로드맵\n\n- 로드맵: %s\n- 계산: 2026-11-19 02:30 +0900 · 기준 커밋 %s · 지휘 세션 aaaa1111\n\n"
            "## 에픽\n- A1 가 · 나 · 준비 · 의존 완료 · 브랜치 없음\n- A2 다 · 준비 · 의존 완료 · 브랜치 없음\n\n"
            "## 열린 PR\n- 없음\n\n## 기다리는 질문\n- 없음\n\n## 작업\n- 없음\n\n"
            "## 편지\n- 보낸 글 0 · 아직 받지 않은 보낸 글 0 · 답 기다리는 글 0 · 받은 글 0\n\n"
            "## 안 올린 규칙 고침\n- 0줄\n") % (rm(ALPHA), base))

    def test_read_back_is_byte_equal_even_with_a_separator_in_the_title(self):   # Review Focus 1
        CS.sync(self.w, rm(ALPHA), SID, now=T0)
        text = self.status_text()
        parsed = CS.parse_status(text)
        self.assertEqual(CS.render_status(parsed), text)
        self.assertEqual((parsed.roadmap, parsed.computed, parsed.session, len(parsed.base)), (rm(ALPHA), "2026-11-19 02:30 +0900", "aaaa1111", 8))
        self.assertEqual(len(parsed.sections["에픽"]), 2)                       # 제목의 ` · ` 가 줄을 가르지 않는다
        self.assertEqual(list(parsed.sections), list(CS.STATUS_SECTIONS))

    def test_other_shapes_are_refused(self):
        CS.sync(self.w, rm(ALPHA), SID, now=T0)
        good = self.status_text()
        for old, new in (("# STATUS — ", "# 현황 — "), ("- 계산: 2026-11-19 02:30 +0900", "- 계산: 2026-11-19 02:30"), ("## 열린 PR\n- 없음\n\n", ""),
                         ("- 계산: 2026-11-19 02:30 +0900", "- 계산: 2026-13-45 99:99 +9999"),          # 꼴은 맞고 달력에 없다
                         ("- 계산: 2026-11-19 02:30 +0900", "- 계산: ٢٠٢٦-11-19 02:30 +0900"),
                         ("## 작업\n- 없음", "## 작업\n없음"), ("## 편지", "## 편지함"), ("기준 커밋 ", "기준 "), ("- 0줄\n", "- 0줄\n\n## 덤\n- x\n")):
            bad = good.replace(old, new, 1)
            self.assertNotEqual(bad, good, old)
            with self.assertRaises(CS.StatusError, msg=old):
                CS.parse_status(bad)

    def test_material_fills_every_section(self):
        self.epic_branch("feature/a1", {"src/a.py": "x\n"})

        def change(d):
            d["PR"].append({"브랜치": "feature/a1", "번호": "#12", "상태": "열림", "확인한 때": "2026-11-19 02:00", "headRefOid": "a" * 40,
                            "교차 레포": "아니오", "baseRefName": "trunk", "mergeCommit": "-", "쓴 세션": SID})
            d["PR"].append({"브랜치": "chore/fix", "번호": "#13", "상태": "열림", "확인한 때": "2026-11-19 02:00", "headRefOid": "b" * 40,
                            "교차 레포": "아니오", "baseRefName": "trunk", "mergeCommit": "-", "쓴 세션": SID})
            d["PR"].append({"브랜치": "feature/old", "번호": "#9", "상태": "머지됨", "확인한 때": "2026-11-19 02:00", "headRefOid": "c" * 40,
                            "교차 레포": "아니오", "baseRefName": "trunk", "mergeCommit": "d" * 40, "쓴 세션": SID})
            d["살아 있는 agent"].append({"이름": "a1-plan", "에픽": "A1", "일": "계획", "worktree": "/w/a1", "보낸 때": "2026-11-19 01:54"})
            d["작업"].append({"종류": "계획", "이름": "A1 계획 1", "에픽": "A1", "단계": "쓰는 중", "담당": "a1-plan", "근거": "docs/p.md"})
            d["작업"].append({"종류": "수리", "이름": "정리", "에픽": "로드맵 밖", "단계": "대기", "담당": "없음", "근거": "x"})
            d["작업"].append({"종류": "구현", "이름": "끝난 일", "에픽": "A2", "단계": "끝", "담당": "없음", "근거": "y"})
        self.machine(change)
        CS.sync(self.w, rm(ALPHA), SID, now=T0)
        s = CS.parse_status(self.status_text()).sections
        self.assertEqual(s["열린 PR"], ["A1 · #12 · feature/a1", "로드맵 밖 · #13 · chore/fix"])
        self.assertEqual(s["작업"], ["계획 · A1 계획 1 · 담당자 1 · 2026-11-19 01:54 +0900", "수리 · 정리 · 담당자 0 · -"])
        self.assertTrue(s["에픽"][0].startswith("A1 가 · 나 · 설계 중"), s["에픽"])

    def test_what_must_not_ride_does_not(self):   # AC5 — 재료에 있어도 나오지 않는다
        from unittest import mock
        host = "Build-Host-77.local"

        def change(d):
            d["기다리는 질문"].append({"에픽": "A1", "기대는 일": "구현", "질문": "비밀 질문 본문 — 선택지 가 · 나"})
            d["작업"].append({"종류": "구현", "이름": "%s 에서 %s 고치기" % (host.upper(), self.w / "src/a.py"), "에픽": "A1", "단계": "구현 중",
                              "담당": "없음", "근거": str(self.w / "docs/p.md")})
        self.machine(change)
        with mock.patch.object(socket, "gethostname", return_value=host):   # 기계 이름은 쓸 때 묻는다 — import 때 굳히지 않는다
            CS.sync(self.w, rm(ALPHA), SID, now=T0)
        text = self.status_text()
        for leak in ("비밀 질문 본문", "선택지", str(self.w), "Build-Host-77", "BUILD-HOST-77", "build-host-77", str(Path.home()), SID):
            self.assertNotIn(leak, text, leak)
        self.assertIn("- 구현 · <기계> 에서 <경로> 고치기 · 담당자 0 · -\n", text)
        self.assertEqual(CS.scrub("see /opt/tools/bin/x and a/b and 1/2", self.w), "see <경로> and a/b and 1/2")
        with mock.patch.object(socket, "gethostname", return_value="dev.local"):   # 짧은 이름이 다른 낱말을 깨지 않는다(J18)
            self.assertEqual(CS.scrub("devbrew 의 dev 에서 DEV.local 로", self.w), "devbrew 의 <기계> 에서 <기계> 로")

    def test_rules_gap_counts_lines_on_one_side_only(self):   # J19 — 사본이 없으면 0
        self.assertEqual(CS.rules_gap(self.w, rm(ALPHA), CB.local_tip(self.w, ALPHA)), 0)
        self.put({self.team.rules: "- 규칙 하나\n- 규칙 둘\n"})
        CB.write(self.w, rm(ALPHA), SID, lambda base: {self.team.rules: "- 규칙 하나\n- 규칙 셋\n- 규칙 넷\n"}, "규칙")
        self.assertEqual(CS.rules_gap(self.w, rm(ALPHA), CB.local_tip(self.w, ALPHA)), 3)   # 뺀 줄 1 + 더한 줄 2
        CS.sync(self.w, rm(ALPHA), SID, now=T0)
        self.assertIn("## 안 올린 규칙 고침\n- 3줄\n", self.status_text())


class Sync(StatusRepo):
    def test_same_material_differs_only_in_the_stamp_line(self):
        a = CS.render_status(CS.build_status(self.w, rm(ALPHA), SID, CB.local_tip(self.w, ALPHA), now=T0))
        b = CS.render_status(CS.build_status(self.w, rm(ALPHA), SID, CB.local_tip(self.w, ALPHA), now=at(5)))
        la, lb = a.splitlines(), b.splitlines()
        self.assertEqual([i for i, (x, y) in enumerate(zip(la, lb)) if x != y], [3])
        self.assertTrue(la[3].startswith("- 계산: "))

    def test_no_commit_when_nothing_but_the_stamp_changed_until_an_hour_passes(self):
        first = CS.sync(self.w, rm(ALPHA), SID, now=T0)
        tip = CB.local_tip(self.w, ALPHA)
        again = CS.sync(self.w, rm(ALPHA), SID, now=at(59))
        self.assertEqual((first.wrote, again.wrote, CB.local_tip(self.w, ALPHA)), (True, False, tip))
        self.assertIn("달라진 것이 없다 — 쓰지 않았다", again.notes)
        self.assertFalse(CS.sync(self.w, rm(ALPHA), SID, now=at(60)).wrote)         # 꼭 한 시간은 아직 낡지 않았다
        late = CS.sync(self.w, rm(ALPHA), SID, now=at(61))
        self.assertTrue(late.wrote)
        self.assertIn("- 계산: 2026-11-19 03:31 +0900", self.status_text())
        self.machine(lambda d: d["작업"].append({"종류": "수리", "이름": "새 일", "에픽": "로드맵 밖", "단계": "대기", "담당": "없음", "근거": "x"}))
        self.assertTrue(CS.sync(self.w, rm(ALPHA), SID, now=at(62)).wrote)          # 양성 대조 — 재료가 달라지면 바로 쓴다

    def test_command_writes_pushes_and_leaves_the_checkout_alone(self):
        before = self.snap()
        rc, out = cli(self.w, "sync", "--roadmap", rm(ALPHA), "--session", SID)
        self.assertEqual(rc, 0, out)
        self.assertEqual(self.snap(), before)
        self.assertEqual(self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o), CB.local_tip(self.w, ALPHA))
        self.assertRegex(self.status_text(), r"- 계산: \d{4}-\d{2}-\d{2} \d{2}:\d{2} [+-]\d{4} · 기준 커밋 [0-9a-f]{8} · 지휘 세션 aaaa1111\n")
        rc, out = cli(self.w, "sync", "--roadmap", rm(ALPHA), "--session", OTHER)
        self.assertEqual(rc, 5, out)

    def test_off_and_missing_branch(self):
        self.claim(BETA)
        rc, out = cli(self.w, "sync", "--roadmap", rm(BETA), "--session", SID)      # ensure 를 돌리지 않았다
        self.assertEqual(rc, 1, out)
        self.assertIn("ensure", out)
        tip = CB.local_tip(self.w, ALPHA)
        self.put({".devbrew.md": "---\nstate_branch: 끔\n---\n"})
        rc, out = cli(self.w, "sync", "--roadmap", rm(ALPHA), "--session", SID)
        self.assertEqual((rc, CB.local_tip(self.w, ALPHA)), (0, tip), out)
        self.assertIn("상태 브랜치가 꺼져 있다", out)

    def test_another_session_writing_after_my_claim_is_told(self):   # 설계 §1 — Deferred 0b618227 의 두 경우
        marker = self.mdir / cs.MARKER
        cs.takeover(self.mdir, OTHER)
        CS.sync(self.w, rm(ALPHA), OTHER, now=at(0))                                 # 다른 세션이 쓴 현황
        cs.takeover(self.mdir, SID)
        os.utime(str(marker), (at(10).timestamp(), at(10).timestamp()))             # 내가 표지를 잡은 때 = +10분 — 그 현황은 그 앞이다
        quiet = CS.sync(self.w, rm(ALPHA), SID, now=at(90))
        self.assertFalse(any("다른 세션이 이 로드맵의 현황을 쓰고 있다" in n for n in quiet.notes), quiet.notes)
        cs.takeover(self.mdir, OTHER)
        CS.sync(self.w, rm(ALPHA), OTHER, now=at(200))                               # 다른 세션이 +200분에 또 썼다
        cs.takeover(self.mdir, SID)
        os.utime(str(marker), (at(10).timestamp(), at(10).timestamp()))             # 내 표지는 여전히 +10분 — 그 현황은 그 뒤다
        loud = CS.sync(self.w, rm(ALPHA), SID, now=at(300))
        self.assertTrue(any(n.startswith("다른 세션이 이 로드맵의 현황을 쓰고 있다") for n in loud.notes), loud.notes)
        self.assertTrue(loud.wrote)                                                  # 알리기만 한다 — 쓰기는 한다

    def other_machine_syncs(self, minutes):
        """둘째 클론(다른 기계)의 다른 세션이 같은 로드맵의 현황을 올린다. 이 기계는 그 뒤 받아 온다."""
        m2 = self.clone("m2")
        self.claim(repo=m2, session=OTHER)
        CB.ensure(m2, rm(ALPHA), OTHER)
        self.assertTrue(CS.sync(m2, rm(ALPHA), OTHER, now=at(minutes)).wrote)
        self.g("fetch", "-q", "origin")                                              # 지휘 순환의 걸음 1 이 받아 온다 — 로컬 끝은 그대로다
        self.assertNotEqual(CB.local_tip(self.w, ALPHA), self.g("rev-parse", "refs/remotes/origin/conductor/" + ALPHA))

    def test_status_another_machine_pushed_after_my_claim_is_told(self):   # J21 — 두 기계 사이: 그 현황은 origin 추적 ref 에만 있다
        """뒤집으면 붉다 — 지금 STATUS 를 로컬 끝에서 읽으면 다른 기계가 올린 현황이 보이지 않아 알림이 나지 않는다."""
        marker = self.mdir / cs.MARKER
        os.utime(str(marker), (at(10).timestamp(), at(10).timestamp()))             # 내 표지는 +10분에 잡았다
        self.other_machine_syncs(200)                                                # 그 뒤 +200분에 다른 기계가 썼다
        loud = CS.sync(self.w, rm(ALPHA), SID, now=at(300))
        self.assertTrue(any(n.startswith("다른 세션이 이 로드맵의 현황을 쓰고 있다 — 세션 bbbb2222 · ") for n in loud.notes), loud.notes)
        self.assertTrue(loud.wrote)                                                  # 알리기만 한다
        self.assertEqual(self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o), CB.local_tip(self.w, ALPHA))

    def test_status_another_machine_pushed_before_my_claim_is_not_told(self):
        marker = self.mdir / cs.MARKER
        self.other_machine_syncs(200)
        os.utime(str(marker), (at(250).timestamp(), at(250).timestamp()))           # 내 표지는 그 현황보다 뒤에 잡았다(넘겨받은 경우)
        quiet = CS.sync(self.w, rm(ALPHA), SID, now=at(300))
        self.assertFalse(any("다른 세션이 이 로드맵의 현황을 쓰고 있다" in n for n in quiet.notes), quiet.notes)
        self.assertTrue(quiet.wrote)

    def test_a_planted_letter_on_another_branch_cannot_stop_sync(self):   # 남이 심은 시각 하나로 sync 가 죽지 않는다
        self.claim(BETA)
        CB.ensure(self.w, rm(BETA), SID)
        beta = CB.team_of(self.w, rm(BETA))
        letter = CM.render_letter(BETA, ALPHA, "질문", "2026-11-19 02:40 +0900", "글").replace("2026-11-19 02:40 +0900", "2026-13-45 99:99 +9999")
        CB.write(self.w, rm(BETA), SID, lambda base: {beta.inbox + "/" + ALPHA + "/2026-11-19-01.md": letter,
                                                     beta.path(CB.RECEIVED_FILE): "- 꼴이 다른 받음 줄\n", beta.status: "깨진 현황\n"}, "심기")
        out = CS.sync(self.w, rm(ALPHA), SID, now=T0)
        self.assertTrue(out.wrote)
        self.assertIn("## 편지\n- 보낸 글 0 · 아직 받지 않은 보낸 글 0 · 답 기다리는 글 0 · 받은 글 0\n", self.status_text())

    def test_status_of_another_roadmap_file_in_the_same_folder_is_not_overwritten(self):   # J22
        other = "docs/superpowers/roadmaps/%s/second.md" % ALPHA
        forged = CS.render_status(CS.build_status(self.w, rm(ALPHA), SID, CB.local_tip(self.w, ALPHA), now=T0)._replace(roadmap=other))
        CB.write(self.w, rm(ALPHA), SID, lambda base: {self.team.status: forged}, "심기")
        tip = CB.local_tip(self.w, ALPHA)
        rc, out = cli(self.w, "sync", "--roadmap", rm(ALPHA), "--session", SID)
        self.assertEqual((rc, CB.local_tip(self.w, ALPHA)), (3, tip), out)

    def test_letter_counts_ride(self):
        self.claim(BETA)
        CB.ensure(self.w, rm(BETA), SID)
        CM.send(self.w, rm(ALPHA), SID, BETA, "질문", "먼저 머지해도 되나", now=T0)
        CS.sync(self.w, rm(ALPHA), SID, now=T0)
        self.assertIn("## 편지\n- 보낸 글 1 · 아직 받지 않은 보낸 글 1 · 답 기다리는 글 1 · 받은 글 0\n", self.status_text())


class WindowAndFloor(StatusRepo):
    def ask(self, via, session=SID):
        def change(d):
            d[cs.ASKING].append({"에픽": "A1", "종류": "계획 확인", "건 길": via, "언제부터": "2026-11-19 02:05 +0900", "세션": session})
        self.machine(change)

    def asking(self):
        return [(r["건 길"], r["세션"]) for r in L.load(self.w, rm(ALPHA))[cs.ASKING]]

    def test_window_rows_of_this_session_are_lowered_even_when_the_branch_is_off(self):   # J57
        self.ask(cs.ASK_VIA[0])
        self.ask(cs.ASK_VIA[1])
        self.ask(cs.ASK_VIA[0], OTHER)
        self.put({".devbrew.md": "---\nstate_branch: 끔\n---\n"})
        out = CS.sync(self.w, rm(ALPHA), SID, now=T0)
        self.assertIn("상태 브랜치가 꺼져 있다", out.notes[0])
        self.assertEqual(self.asking(), [(cs.ASK_VIA[1], SID), (cs.ASK_VIA[0], OTHER)])

    def test_lower_window_false_keeps_the_rows_and_a_non_holder_lowers_nothing(self):
        self.ask(cs.ASK_VIA[0])
        CS.sync(self.w, rm(ALPHA), SID, now=T0, lower_window=False)
        self.assertEqual(self.asking(), [(cs.ASK_VIA[0], SID)])
        with self.assertRaises(L.Fail) as ctx:
            CS.sync(self.w, rm(ALPHA), OTHER, now=T0)
        self.assertEqual(ctx.exception.rc, 5)
        self.assertEqual(self.asking(), [(cs.ASK_VIA[0], SID)])

    def test_waiting_lines_come_oldest_first_without_the_question(self):
        self.ask(cs.ASK_VIA[1])
        self.machine(lambda d: d[cs.ASKING].append({"에픽": "로드맵 밖", "종류": "머지", "건 길": cs.ASK_VIA[1],
                                                    "언제부터": "2026-11-19 01:00 +0900", "세션": SID}))
        CS.sync(self.w, rm(ALPHA), SID, now=T0, lower_window=False)
        self.assertEqual(CS.parse_status(self.status_text()).sections["기다리는 질문"],
                         ["로드맵 밖 · 머지 · 2026-11-19 01:00 +0900", "A1 · 계획 확인 · 2026-11-19 02:05 +0900"])

    def test_unreadable_previous_status_is_replaced_with_a_note(self):
        CB.write(self.w, rm(ALPHA), SID, lambda base: {self.team.status: "손으로 고친 글\n"}, "심기")
        out = CS.sync(self.w, rm(ALPHA), SID, now=T0)
        self.assertTrue(out.wrote)
        self.assertIn("앞의 STATUS 를 읽지 못해 새로 쓴다", out.notes)
        CS.parse_status(self.status_text())
