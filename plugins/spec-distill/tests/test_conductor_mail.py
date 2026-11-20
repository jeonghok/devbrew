#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_mail.py — 편지의 꼴 · 보내기 · 온 글 · 읽기 · 받음 줄 · 세는 것.

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_conductor_mail.py
"""
from __future__ import annotations

import datetime
import socket
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from conductor_branch_fixture import ALPHA, BETA, ENV, OTHER, SCRIPTS, SID, StateRepo, block, rm, roadmap_text  # noqa: E402
import conductor_branch as CB  # noqa: E402
import conductor_mail as CM  # noqa: E402

KST = datetime.timezone(datetime.timedelta(hours=9))
NOW = datetime.datetime(2026, 11, 19, 2, 40, tzinfo=KST)
GOOD = ("---\ntype: conductor-letter\nfrom: 2026-01-01-alpha\nto: 2026-01-02-beta\nkind: 예고\nabout: src/shared.py\n"
        "sent_at: 2026-11-19 02:40 +0900\n---\n곧 src/shared.py 를 고친다\n")


def cli(repo, *args):
    p = subprocess.run([sys.executable, str(SCRIPTS / "conductor_mail.py"), "--root", str(repo), *args],
                       cwd=str(repo), env=ENV, capture_output=True, encoding="utf-8")
    return p.returncode, p.stdout + p.stderr


class Shape(unittest.TestCase):
    def test_render_and_parse_round_trip(self):
        text = CM.render_letter(ALPHA, BETA, "예고", "2026-11-19 02:40 +0900", "곧 src/shared.py 를 고친다", about="src/shared.py")
        self.assertEqual(text, GOOD)
        head, body = CM.parse_letter(text)
        self.assertEqual(head, {"type": "conductor-letter", "from": ALPHA, "to": BETA, "kind": "예고", "about": "src/shared.py",
                                "sent_at": "2026-11-19 02:40 +0900"})
        self.assertEqual(body, "곧 src/shared.py 를 고친다\n")
        self.assertNotIn("about:", CM.render_letter(ALPHA, BETA, "예고", "2026-11-19 02:40 +0900", "x"))

    def test_head_is_closed(self):
        for old, new in (("type: conductor-letter\n", ""), ("type: conductor-letter", "type: conductor-letters"),
                         ("from: 2026-01-01-alpha\n", "from: 2026-01-01-alpha\nfrom: 2026-01-01-alpha\n"),
                         ("kind: 예고\n", "kind: 예고\ncc: x\n"), ("kind: 예고", "kind: 예고함"), ("kind: 예고", "kind: 예"),
                         ("sent_at: 2026-11-19 02:40 +0900", "sent_at: 2026-11-19 02:40"), ("about: src/shared.py", "about: "),
                         ("to: 2026-01-02-beta\n", ""), ("---\n곧", "곧"), ("---\ntype", "\ufeff---\ntype"), ("---\ntype", "--- \ntype")):
            bad = GOOD.replace(old, new, 1)
            self.assertNotEqual(bad, GOOD, old)
            with self.assertRaises(CM.LetterError, msg=repr(new)):
                CM.parse_letter(bad)
        CM.parse_letter(GOOD.replace("kind: 예고\nabout: src/shared.py\n", "about: src/shared.py\nkind: 배운 것\n"))   # 양성 대조 — 칸의 차례는 가리지 않는다


class MailRepo(StateRepo):
    """한 기계가 로드맵 둘을 지휘한다 — 둘 다 표지를 잡고 상태 브랜치를 만들어 둔다."""
    def setUp(self):
        super().setUp()
        for name in (ALPHA, BETA):
            self.claim(name)
            CB.ensure(self.w, rm(name), SID)
        self.team = CB.team_of(self.w, rm(ALPHA))

    def send(self, to, kind, body="글", frm=ALPHA, **kw):
        return CM.send(self.w, rm(frm), SID, to, kind, body, now=NOW, **kw)


class Send(MailRepo):
    def test_letter_lands_in_the_senders_branch_under_the_receivers_name(self):
        before = self.snap()
        result, notice = self.send(BETA, "예고", "곧 src/shared.py 를 고친다", about="src/shared.py")
        path = self.team.inbox + "/" + BETA + "/2026-11-19-01.md"
        self.assertEqual(CB.read(self.w, result.commit, path), GOOD)
        self.assertEqual(notice, "%s 지휘자의 글 — conductor/%s:%s" % (ALPHA, ALPHA, path))
        self.assertEqual(self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o), result.commit)
        self.assertEqual(self.snap(), before)
        second, _ = self.send(CM.ALL, "배운 것")                         # 번호는 inbox 전체에서 센다(J23)
        self.assertEqual([p for _m, p in CB.names(self.w, second.commit, self.team.inbox + "/")],
                         [self.team.inbox + "/" + BETA + "/2026-11-19-01.md", self.team.inbox + "/all/2026-11-19-02.md"])
        self.assertIsNone(CB.local_tip(self.w, BETA) and CB.read(self.w, CB.local_tip(self.w, BETA), path))   # 받는 쪽 브랜치에는 쓰지 않는다

    def test_refused_values_write_nothing(self):
        from unittest import mock
        host = "Build-Host-77.local"
        cases = [dict(to=BETA, kind="잡담"), dict(to=BETA[:-1], kind="예고"), dict(to=BETA + " ", kind="예고"), dict(to="no-such-roadmap", kind="예고"),
                 dict(to=ALPHA, kind="예고"), dict(to=CM.ALL, kind="질문"), dict(to=CM.ALL, kind="답", re_=BETA + "/2026-11-19-01.md"),
                 dict(to=BETA, kind="질문", re_=BETA + "/2026-11-19-01.md"), dict(to=BETA, kind="답"),
                 dict(to=BETA, kind="답", re_=BETA + "/2026-11-19-09.md"), dict(to=BETA, kind="답", re_="2026-11-19-01.md"),
                 dict(to=BETA, kind="예고", about=str(self.w / "src/a.py")), dict(to=BETA, kind="예고", about="~/notes.md"),
                 dict(to=BETA, kind="예고", about="see %s" % host.upper()), dict(to=BETA, kind="예고", about="두\n줄"),
                 dict(to=BETA, kind="예고", about="가" * 201), dict(to=BETA, kind="예고", about="x\x1b[2Ky"),
                 dict(to=BETA, kind="예고", about="x\u202ey"), dict(to=BETA, kind="예고", about="x\u2028y")]
        refs = self.refs()
        with mock.patch.object(socket, "gethostname", return_value=host):   # 기계 이름은 쓸 때 묻는다
            for kw in cases:
                with self.assertRaises(CB.BranchError, msg=repr(kw)) as c:
                    self.send(**kw)
                self.assertEqual(c.exception.rc, 2, kw)
        self.assertEqual(self.refs(), refs)
        self.assertIsNotNone(self.send(BETA, "예고", about="src/a.py · PR #12")[0].commit)   # 양성 대조

    def test_answer_names_a_letter_that_really_came(self):
        self.send(ALPHA, "질문", "이 PR 을 먼저 머지해도 되나", frm=BETA)
        result, _ = self.send(BETA, "답", "된다", re_=BETA + "/2026-11-19-01.md")
        head, _body = CM.parse_letter(CB.read(self.w, result.commit, self.team.inbox + "/" + BETA + "/2026-11-19-01.md"))
        self.assertEqual((head["kind"], head["re"]), ("답", BETA + "/2026-11-19-01.md"))

    def test_finished_roadmap_is_not_a_receiver(self):
        self.epic_branch("feature/b1", {"src/b.py": "x\n"})
        self.merge_epic("feature/b1")
        with self.assertRaises(CB.BranchError) as c:
            self.send(BETA, "예고")
        self.assertEqual(c.exception.rc, 2)
        self.assertIn("끝", str(c.exception))

    def test_machine_name_is_matched_as_a_word(self):   # J18 — 짧은 기계 이름이 다른 낱말을 걸지 않는다
        from unittest import mock
        with mock.patch.object(socket, "gethostname", return_value="dev.local"):
            self.assertIsNotNone(self.send(BETA, "예고", about="devbrew 의 src/a.py · PR #12")[0].commit)
            for about in ("dev 에서 고친다", "host DEV.", "dev.local 의 폴더"):
                with self.assertRaises(CB.BranchError, msg=about) as c:
                    self.send(BETA, "예고", about=about)
                self.assertEqual(c.exception.rc, 2)

    def test_about_at_the_limit_is_taken(self):
        self.assertIsNotNone(self.send(BETA, "예고", about="가" * 200)[0].commit)

    def test_notice_names_the_path_that_was_really_written_after_a_remake(self):
        """뒤집으면 붉다 — 알림 줄을 처음 고른 경로로 만들면 …-01 을 가리킨다(그 이름은 다른 기계의 글이다)."""
        m2 = self.clone("m2")
        self.claim(repo=m2)
        CB.ensure(m2, rm(ALPHA), SID)
        CM.send(m2, rm(ALPHA), SID, CM.ALL, "예고", "다른 기계가 먼저 보낸 글", now=NOW)        # origin 에 …-01 이 먼저 올라간다
        result, notice = self.send(BETA, "예고", "내 글")                                          # 이 기계는 그것을 모른 채 …-01 로 짓고 거절된다
        path = self.team.inbox + "/" + BETA + "/2026-11-19-02.md"
        self.assertEqual(notice, "%s 지휘자의 글 — conductor/%s:%s" % (ALPHA, ALPHA, path))
        self.assertIn("내 글", CB.read(self.w, result.commit, path))
        self.assertIsNone(CB.read(self.w, result.commit, self.team.inbox + "/" + BETA + "/2026-11-19-01.md"))
        self.assertIsNotNone(result.onto)

    def test_long_body_is_written_and_told(self):
        short, _ = self.send(BETA, "예고", "가" * 2000)
        self.assertFalse(any(CM.LONG_NOTE in n for n in short.notes))
        long_, _ = self.send(BETA, "예고", "가" * 2001)
        self.assertIsNotNone(long_.commit)
        self.assertTrue(any("길다 — 자세한 것은 파일로 남기고 경로를 적는다" in n for n in long_.notes), long_.notes)

    def test_command_ends_with_the_notice_line_and_respects_marker_and_switch(self):
        rc, out = cli(self.w, "send", "--roadmap", rm(ALPHA), "--session", SID, "--to", BETA, "--kind", "예고", "--body", "글")
        self.assertEqual(rc, 0, out)
        self.assertRegex(out.strip().splitlines()[-1], r"^%s 지휘자의 글 — conductor/%s:.+/inbox/%s/\d{4}-\d{2}-\d{2}-01\.md$" % (ALPHA, ALPHA, BETA))
        rc, out = cli(self.w, "send", "--roadmap", rm(ALPHA), "--session", OTHER, "--to", BETA, "--kind", "예고", "--body", "글")
        self.assertEqual(rc, 5, out)
        rc, out = cli(self.w, "send", "--roadmap", rm(ALPHA), "--session", SID, "--to", BETA, "--kind", "잡담", "--body", "글")
        self.assertEqual(rc, 2, out)
        tip = CB.local_tip(self.w, ALPHA)
        self.put({".devbrew.md": "---\nstate_branch: 끔\n---\n"})
        rc, out = cli(self.w, "send", "--roadmap", rm(ALPHA), "--session", SID, "--to", BETA, "--kind", "예고", "--body", "글")
        self.assertEqual((rc, CB.local_tip(self.w, ALPHA)), (0, tip), out)
        self.assertIn("상태 브랜치가 꺼져 있다", out)
