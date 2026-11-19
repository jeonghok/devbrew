#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_branch.py — 상태 브랜치의 이름 · 쓸 수 있는지 · 읽기 · 쓰기 · 올리기.

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_conductor_branch.py
"""
from __future__ import annotations

import datetime
import importlib.util
import json
import os
import re
import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
from conductor_branch_fixture import ALPHA, BETA, ENV, OTHER, SCRIPTS, SID, StateRepo, rm  # noqa: E402
import conductor_branch as CB  # noqa: E402


class Fixture(StateRepo):
    def test_two_roadmaps_are_found_and_staged(self):
        out = subprocess.run([sys.executable, str(SCRIPTS / "roadmap_status.py"), "--json", rm(ALPHA)], cwd=str(self.w),
                             env=ENV, capture_output=True, encoding="utf-8").stdout
        blocks = json.loads(out)["blocks"]
        self.assertEqual([(b["id"], b["title"], b["stage"]) for b in blocks], [("A1", "가 · 나", "준비"), ("A2", "다", "준비")])
        self.assertEqual(self.g("rev-parse", "--abbrev-ref", "origin/HEAD"), "origin/trunk")
        self.assertEqual(self.snap(), self.snap())

    def test_second_clone_shares_the_remote(self):
        other = self.clone("m2")
        self.assertEqual(self.g("rev-parse", "origin/trunk", repo=other), self.g("rev-parse", "origin/trunk"))

    def test_shallow_clone_is_really_shallow(self):   # 로컬 경로 클론은 --depth 를 무시한다 — file:// 로만 얕아진다
        d = self.clone("sh", "--depth", "1", "--no-local")
        self.assertEqual(self.g("rev-parse", "--is-shallow-repository", repo=d), "true")

    def test_state_folder_is_never_committed_and_git_runs_without_the_users_config(self):
        self.claim()
        self.put({"x.txt": "x\n"})                                   # git add -A 를 거친다
        self.epic_branch("feature/a1", {"src/a.py": "a\n"})
        for ref in ("trunk", "feature/a1"):
            self.assertEqual([p for p in self.g("ls-tree", "-r", "--name-only", ref).split("\n") if p.startswith(".claude")], [], ref)
        other = self.clone("m2")
        self.claim(repo=other)                                       # 다른 클론에서 새로 잡힌다 — 표지가 실려 오지 않았다
        self.assertEqual(os.environ["GIT_CONFIG_GLOBAL"], "/dev/null")
        self.assertEqual(self.rc("merge-base", "--is-ancestor", "trunk", "feature/a1"), 0)
        self.assertEqual(self.rc("merge-base", "--is-ancestor", "feature/a1", "trunk"), 1)   # 양성 대조 — rc 가 실제로 갈린다


RULE_OK = "# B\n\n```regex\n^(feature|fix)/[a-z0-9][a-z0-9.-]*$|^conductor/[a-z0-9][a-z0-9.-]*$\n```\n"
RULE_NO = "# B\n\n```regex\n^(feature|fix)/[a-z0-9][a-z0-9.-]*$\n```\n"
RULE_DOC = "docs/git-workflow/branch-strategy.md"


class Names(StateRepo):
    def test_name_branch_and_team_paths(self):
        self.assertEqual(CB.roadmap_name(rm(ALPHA)), ALPHA)
        self.assertEqual((CB.branch_of(ALPHA), CB.ref_of(ALPHA)), ("conductor/" + ALPHA, "refs/heads/conductor/" + ALPHA))
        team = CB.team_of(self.w, rm(ALPHA))
        self.assertEqual((team.status, team.inbox), ("docs/superpowers/roadmaps/%s/STATUS.md" % ALPHA, "docs/superpowers/roadmaps/%s/inbox" % ALPHA))
        for bad in ("roadmap.md", "docs/superpowers/roadmaps/a/b/roadmap.md", "elsewhere/x/roadmap.md"):
            with self.assertRaises(CB.BranchError, msg=bad) as c:
                CB.team_of(self.w, bad)
            self.assertEqual(c.exception.rc, 2)

    def test_stamp_carries_the_offset_and_compares_across_zones(self):
        kst = datetime.timezone(datetime.timedelta(hours=9))
        text = CB.stamp(datetime.datetime(2026, 11, 19, 2, 30, tzinfo=kst))
        self.assertEqual(text, "2026-11-19 02:30 +0900")
        self.assertLess(CB.parse_stamp(text), CB.parse_stamp("2026-11-18 18:00 +0000"))   # 02:30 +0900 은 17:30 UTC 다
        for bad in ("2026-11-19 02:30", "2026-11-19 02:30 +09:00", "2026-11-19 02:30 +0900\n", " 2026-11-19 02:30 +0900",
                    "2026-13-45 99:99 +9999", "2026-02-30 10:00 +0900", "2026-11-19 24:00 +0900", "2026-11-19 02:30 +2460",   # 꼴은 맞고 달력 · 시계에 없다
                    "٢٠٢٦-11-19 02:30 +0900", "", None):   # ٢ 는 다른 문자 체계의 숫자 2 다
            self.assertIsNone(CB.parse_stamp(bad), bad)
        self.assertIsNotNone(CB.parse_stamp(CB.stamp()))


class Availability(StateRepo):
    def test_default_is_usable(self):
        self.assertIsNone(CB.availability(self.w, rm(ALPHA)))   # 규칙 문서가 없는 레포 — 만든다

    def test_off_and_broken_setting(self):
        self.put({".devbrew.md": "---\nstate_branch: 끔\n---\n"})
        self.assertEqual(CB.availability(self.w, rm(ALPHA)), "상태 브랜치가 꺼져 있다")
        self.put({".devbrew.md": "---\nstate_branch: off\n---\n"})
        why = CB.availability(self.w, rm(ALPHA))
        self.assertTrue(why.startswith("레포 설정을 읽지 못해 상태 브랜치를 쓰지 않는다 — "), why)
        self.assertIn("state_branch", why)

    def test_a_setting_file_that_cannot_be_trusted_never_reads_as_on(self):
        """끔 옆의 오류 하나가 끔을 지우지 못한다. 뒤집으면 붉다 — state_branch 값만 보면 첫 경우가 None(쓸 수 있다)이 된다."""
        for text in ("---\nstate_branch: 끔\nstate_brunch: 끔\n---\n",          # 오타 난 키 하나 — 해결자가 레포 층을 통째로 버린다
                     "---\nstate_branch: 끔\ntest_command: \n---\n",            # 다른 키의 빈 값 — 해결자가 오류로 낸다
                     "---\nstate_branch: 끔\nstate_branch: 끔\n---\n",          # 같은 키 둘 — 해결자가 예외를 던진다
                     "\ufeff---\nstate_branch: 끔\n---\n",                       # 머리말 앞의 BOM — 예외
                     "---\nstate_branch: 끔\n"):                                 # 닫히지 않은 머리말 — 예외
            self.put({".devbrew.md": text}, message=repr(text))
            why = CB.availability(self.w, rm(ALPHA))
            self.assertIsNotNone(why, text)
            self.assertTrue(why.startswith("레포 설정을 읽지 못해 상태 브랜치를 쓰지 않는다 — "), (text, why))
        self.put({".devbrew.md": "---\nstate_branch: 켬\nstate_brunch: 끔\n---\n"})   # 켬이어도 읽지 못한 설정으로는 쓰지 않는다
        self.assertTrue(CB.availability(self.w, rm(ALPHA)).startswith("레포 설정을 읽지 못해"))
        self.put({".devbrew.md": "---\nstate_branch: 켬\nparallel_default: 2\n---\n"})   # 양성 대조 — 오류가 없으면 쓸 수 있다
        self.assertIsNone(CB.availability(self.w, rm(ALPHA)))

    def test_setting_is_read_from_the_default_branch_not_the_working_tree(self):
        (self.w / ".devbrew.md").write_text("---\nstate_branch: 끔\n---\n", encoding="utf-8")   # 커밋하지 않았다
        self.assertIsNone(CB.availability(self.w, rm(ALPHA)))

    def test_folder_name_outside_the_shape(self):
        from conductor_branch_fixture import roadmap_text
        self.put({"docs/superpowers/roadmaps/2026_Alpha/roadmap.md": roadmap_text("x", self.BETA_BLOCKS)})
        why = CB.availability(self.w, "docs/superpowers/roadmaps/2026_Alpha/roadmap.md")
        self.assertIn("2026_Alpha", why)
        self.assertIn("소문자", why)
        for name in ("a..b", "x.lock", "alpha.", "-alpha", ".alpha", "al pha", "alphа"):   # 마지막은 다른 문자 체계의 a 다 · git 이 ref 로 받지 않는 꼴 셋(J56)
            self.assertFalse(CB.name_ok(name), name)
            self.assertIn("쓸 수 없다", CB.availability(self.w, "docs/superpowers/roadmaps/%s/roadmap.md" % name), name)
        for name in (ALPHA, "a", "0", "a.b-c", "v1.2"):
            self.assertTrue(CB.name_ok(name), name)

    def test_branch_rule(self):
        self.put({RULE_DOC: RULE_OK})
        self.assertIsNone(CB.availability(self.w, rm(ALPHA)))
        self.put({RULE_DOC: RULE_NO})
        self.assertEqual(CB.availability(self.w, rm(ALPHA)),
                         "이 레포의 브랜치 규칙이 conductor/ 를 받지 않는다 — 규칙 문서에 갈래를 더하거나 state_branch 를 끈다")

    def test_rule_document_without_a_usable_rule_closes(self):   # J9 — 훅은 건너뛰지만 여기서는 만들지 않는다
        for text in ("# 규칙이 없는 문서\n", "```regex\n\n```\n", "```regex\n^(feature\n```\n"):
            self.put({RULE_DOC: text})
            why = CB.availability(self.w, rm(ALPHA))
            self.assertIn("브랜치 규칙을 읽지 못했다", why, text)
        (self.w / RULE_DOC).write_bytes(b"```regex\n^\xff$\n```\n")
        self.g("commit", "-qam", "binary")
        self.g("push", "-q", "origin", "trunk")
        self.assertIn("브랜치 규칙을 읽지 못했다", CB.availability(self.w, rm(ALPHA)))

    def test_unknown_default_branch(self):
        self.put({RULE_DOC: RULE_NO})
        self.g("remote", "set-head", "origin", "--delete")            # origin 은 있는데 기본 브랜치를 모른다 — 규칙을 읽을 곳이 없다
        why = CB.availability(self.w, rm(ALPHA))
        self.assertIn("브랜치 규칙을 읽지 못했다", why)
        self.assertIn("set-head", why)
        self.g("remote", "remove", "origin")                          # origin 이 아예 없다 — 올릴 곳이 없으니 로컬에 쓴다
        self.assertIsNone(CB.availability(self.w, rm(ALPHA)))

    def test_same_verdict_as_the_project_init_hook(self):   # 같은 읽기 · 같은 호출 — 훅이 경고하면 여기서도 받지 않는다
        hook_path = Path(__file__).resolve().parents[3] / "plugins" / "project-init" / "hooks" / "post-tool-use.py"
        if not hook_path.is_file():
            self.skipTest("project-init 훅이 이 트리에 없다")
        spec = importlib.util.spec_from_file_location("post_tool_use_hook", hook_path)
        hook = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(hook)
        name = CB.branch_of(ALPHA)
        seen = set()
        for rule in ("^(feature|fix)/[a-z0-9][a-z0-9.-]*$|^conductor/[a-z0-9][a-z0-9.-]*$", "^(feature|fix)/[a-z0-9][a-z0-9.-]*$",
                     "^conductor/", "^(feature|conductor)/[a-z]+$", "conductor/[a-z0-9.-]+", "^.*$"):
            self.put({RULE_DOC: "```regex\n%s\n```\n" % rule}, message=rule)
            kind, pattern = CB.branch_rule(self.w)
            self.assertEqual(kind, "규칙", rule)
            hook_ok = hook.check_branch_name(name, hook.read_branch_rule(str(self.w))[0]) is None
            self.assertEqual(CB.availability(self.w, rm(ALPHA)) is None, hook_ok, rule)
            seen.add(hook_ok)
        self.assertEqual(seen, {True, False})   # 표가 두 답을 다 지난다


class Reading(StateRepo):
    def test_read_names_and_tips(self):
        trunk = self.g("rev-parse", "trunk")
        self.assertIn("# 알파 — 로드맵", CB.read(self.w, trunk, rm(ALPHA)))
        self.assertIsNone(CB.read(self.w, trunk, "no/such.md"))
        self.assertIn(("100644", rm(BETA)), CB.names(self.w, trunk, "docs/superpowers/roadmaps/"))
        self.assertEqual(CB.names(self.w, trunk, "no/such/"), [])
        self.assertIsNone(CB.local_tip(self.w, ALPHA))
        self.assertEqual((CB.seen_tip(self.w, ALPHA), CB.state_names(self.w)), ((None, None), []))
        self.g("update-ref", CB.ref_of(BETA), trunk)   # 양성 대조 — 있는 브랜치는 보인다
        self.assertEqual((CB.local_tip(self.w, BETA), CB.seen_tip(self.w, BETA), CB.state_names(self.w)), (trunk, (trunk, None), [BETA]))

    def test_seen_tip_reads_the_side_that_is_ahead_and_refuses_only_a_split(self):   # J54
        old = self.g("rev-parse", "trunk")
        self.put({"x.txt": "x\n"})
        new = self.g("rev-parse", "trunk")                                     # old 가 new 의 조상이다
        tracking = "refs/remotes/origin/conductor/" + BETA
        for local_at, remote_at in ((old, new), (new, old), (new, new)):
            self.g("update-ref", CB.ref_of(BETA), local_at)
            self.g("update-ref", tracking, remote_at)
            self.assertEqual(CB.seen_tip(self.w, BETA), (new, None), (local_at, remote_at))   # 한 커밋 달라도 읽는다 — 사유가 없다
        side = self.g("commit-tree", old + "^{tree}", "-p", old, "-m", "갈라진 쪽")
        self.g("update-ref", CB.ref_of(BETA), side)
        tip, why = CB.seen_tip(self.w, BETA)                                   # 갈라졌을 때만 읽지 않는다
        self.assertIsNone(tip)
        self.assertTrue(why)
        self.g("update-ref", "-d", tracking)
        self.assertEqual(CB.seen_tip(self.w, BETA), (side, None))              # 로컬만 있으면 그것

    def test_roadmaps_and_which_are_unfinished(self):
        self.assertEqual(CB.roadmap_paths(self.w), {ALPHA: rm(ALPHA), BETA: rm(BETA)})
        self.assertEqual([(r.name, r.path, r.unfinished, r.why) for r in CB.roadmaps(self.w)],
                         [(ALPHA, rm(ALPHA), True, None), (BETA, rm(BETA), True, None)])
        self.epic_branch("feature/b1", {"src/b.py": "x\n"})
        self.merge_epic("feature/b1")                                   # BETA 의 하나뿐인 에픽이 머지됐다
        table = {r.name: r for r in CB.roadmaps(self.w)}
        self.assertEqual((table[ALPHA].unfinished, table[BETA].unfinished), (True, False))
        self.assertEqual([b["stage"] for b in table[BETA].report["blocks"]], ["머지됨"])
        self.put({"docs/superpowers/roadmaps/2026-01-03-broken/roadmap.md": "---\ntype: roadmap\nsource_brief: b.md\n---\n\n# 깨진 로드맵\n"})
        broken = {r.name: r for r in CB.roadmaps(self.w)}["2026-01-03-broken"]
        self.assertEqual((broken.report, broken.unfinished), (None, True))   # 셀 수 없는 로드맵은 끝난 것으로 치지 않는다
        self.assertTrue(broken.why)

    def test_git_runner_is_closed(self):
        with self.assertRaises(RuntimeError):
            CB.git(self.w, "checkout", "trunk")
        for write_form in (("config", "user.name", "x"), ("config", "--unset", "user.name"), ("config", "--add", "a.b", "c"), ("config",)):
            with self.assertRaises(RuntimeError, msg=write_form):
                CB.git(self.w, *write_form)
        self.assertEqual(CB.git(self.w, "config", "--get", "remote.origin.url")[0], 0)   # 양성 대조 — 읽는 꼴은 돈다
        for word in ("checkout", "switch", "worktree", "stash", "reset", "rebase", "commit", "merge"):
            self.assertNotIn(word, CB.GIT_ALLOWED, word)


class Showing(unittest.TestCase):
    def test_visible_turns_control_and_direction_characters_into_text(self):   # J51
        raw = "a\x1b[2Kb\u202ec\u2028d\x00e\tf\u200bg\x85h\rI\x0bj\x0ck\u2066l"
        out = CB.visible(raw)
        self.assertEqual(out, "a\\x1b[2Kb\\u202ec\\u2028d\\x00e\tf\\u200bg\\x85h\\x0dI\\x0bj\\x0ck\\u2066l")
        # 나머지 범주와 0xFFFF 위 글자 — Zp · Cs · Co · \\U 갈래
        wide = CB.visible("a\u2029b\ud800c\ue000d\U000e0001e\U000f0000f")
        self.assertEqual(wide, "a\\u2029b\\ud800c\\ue000d\\U000e0001e\\U000f0000f")
        plain = "가 · 나 — 「다」 ──── │ <경로> abc 123"
        self.assertEqual(CB.visible(plain), plain)                              # 보통 글자는 그대로

    def test_machine_name_matches_only_as_a_word(self):   # J18
        from unittest import mock
        import socket
        with mock.patch.object(socket, "gethostname", return_value="dev.local"):
            pat = CB.machine_pattern()
            self.assertEqual(pat.search("on dev.local/x").group(0), "dev.local")      # 온 이름이 짧은 이름보다 먼저다 — 짧은 이름이 가로채면 `.local` 이 남는다
            for text, hit in (("devbrew 의 문서", False), ("mydev 폴더", False), ("dev2", False), ("dev 에서", True), ("(DEV)", True),
                              ("dev.local/x", True), ("에서dev", True)):
                self.assertEqual(bool(pat.search(text)), hit, text)
        with mock.patch.object(socket, "gethostname", return_value="pc"):
            self.assertIsNone(CB.machine_pattern())                                # 두 글자 이름은 낱말로도 너무 흔하다

    def test_redact_hides_remote_addresses_and_absolute_paths(self):   # J55
        for raw, want in (("fatal: unable to access 'https://user:t0ken@example.invalid/a/b.git/': failed", "fatal: unable to access '<원격>': failed"),
                          ("ssh: connect to host git@example.invalid:me/repo.git port 22", "ssh: connect to host <원격> port 22"),
                          ("fatal: '/private/tmp/x/gone.git' does not appear to be a git repository", "fatal: '<경로>' does not appear to be a git repository"),
                          ("! [rejected] (fetch first)", "! [rejected] (fetch first)")):
            self.assertEqual(CB.redact(raw), want, raw)


class AvailabilityWithoutAnOrigin(StateRepo):
    """기본 브랜치를 몰라 설정 층을 건너뛴 레포 — 설정 파일이 있을 때만 닫는다(P1)."""

    def drop_origin(self):
        self.g("remote", "remove", "origin")

    def test_unread_settings_file_closes_when_the_default_branch_is_unknown(self):
        (self.w / ".devbrew.md").write_text("---\nstate_branch: 끔\n---\n", encoding="utf-8")   # 커밋하지 않은 작업 폴더의 파일
        self.drop_origin()
        why = CB.availability(self.w, rm(ALPHA))
        self.assertTrue(why.startswith("레포 설정을 읽지 못해 상태 브랜치를 쓰지 않는다 — "), why)
        self.assertNotEqual(why, "상태 브랜치가 꺼져 있다")

    def test_settings_file_in_head_alone_closes_too(self):
        self.put({".devbrew.md": "---\nstate_branch: 켬\n---\n"})
        self.drop_origin()
        self.assertTrue(CB.availability(self.w, rm(ALPHA)).startswith("레포 설정을 읽지 못해 상태 브랜치를 쓰지 않는다 — "))

    def test_no_settings_file_means_local_writes_stay_open(self):   # 양성 대조
        self.drop_origin()
        self.assertIsNone(CB.availability(self.w, rm(ALPHA)))


class OthersTextCannotBuildPaths(StateRepo):
    def test_team_of_refuses_dot_dot_role_and_bad_names(self):
        for bad in ("..", ".", "inbox", "leader", "jobs", "Alpha", "-x", "a b", "x.lock"):
            with self.assertRaises(CB.BranchError, msg=bad) as c:
                CB.team_of(self.w, "docs/superpowers/roadmaps/%s/roadmap.md" % bad)
            self.assertEqual(c.exception.rc, 2, bad)
        self.assertEqual(CB.team_of(self.w, rm(ALPHA)).name, ALPHA)   # 양성 대조

    def test_state_names_keeps_only_well_formed_tails_on_both_sides(self):
        trunk = self.g("rev-parse", "trunk")
        for tail in ("-x", "Ev\u202eil", "a/b", BETA):
            self.g("update-ref", "refs/remotes/origin/conductor/" + tail, trunk)
        self.g("update-ref", "refs/heads/conductor/-y", trunk)
        self.g("update-ref", "refs/heads/conductor/" + ALPHA, trunk)
        self.assertEqual(CB.state_names(self.w), sorted([ALPHA, BETA]))


def cli(repo, *args, env=None):
    p = subprocess.run([sys.executable, str(SCRIPTS / "conductor_branch.py"), "--root", str(repo), *args],
                       cwd=str(repo), env=env or ENV, capture_output=True, encoding="utf-8")
    return p.returncode, p.stdout + p.stderr


class Ensure(StateRepo):
    def test_creates_an_unrelated_branch_and_touches_no_checkout(self):
        self.claim()
        (self.w / "dirty.txt").write_text("x", encoding="utf-8")
        self.g("add", "dirty.txt")
        (self.w / rm(ALPHA)).write_text("고친 채 둔 파일\n", encoding="utf-8")
        before = self.snap()
        rc, out = cli(self.w, "ensure", "--roadmap", rm(ALPHA), "--session", SID)
        self.assertEqual(rc, 0, out)
        self.assertIn("만들었다 — conductor/" + ALPHA, out)
        tip = CB.local_tip(self.w, ALPHA)
        self.assertEqual(self.g("rev-list", "--count", tip), "1")
        self.assertEqual(self.g("ls-tree", "-r", tip), "")                                   # 코드가 없다
        self.assertEqual(self.g("merge-base", "trunk", tip, check=False), "")                # 이력을 나누지 않는다
        self.assertEqual(self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o), tip)             # origin 에 올라갔다
        self.assertEqual(self.snap(), before)                                                # HEAD · index · 추적 파일 그대로
        refs = self.refs()
        rc, out = cli(self.w, "ensure", "--roadmap", rm(ALPHA), "--session", SID)
        self.assertEqual((rc, self.refs()), (0, refs))                                       # 있으면 아무것도 바꾸지 않는다
        self.assertIn("있다 — conductor/" + ALPHA, out)

    def test_only_the_marker_holder_writes(self):
        refs = self.refs()
        rc, out = cli(self.w, "ensure", "--roadmap", rm(ALPHA), "--session", SID)   # 표지 없음
        self.assertEqual((rc, self.refs()), (5, refs), out)
        self.claim(session=OTHER)
        rc, out = cli(self.w, "ensure", "--roadmap", rm(ALPHA), "--session", SID)   # 다른 세션의 표지
        self.assertEqual((rc, self.refs()), (5, refs), out)
        rc, _ = cli(self.w, "ensure", "--roadmap", rm(ALPHA), "--session", OTHER)   # 양성 대조
        self.assertEqual(rc, 0)

    def test_rule_refusal_and_off_do_not_create(self):
        self.claim()
        self.put({RULE_DOC: RULE_NO})
        refs_w, refs_o = self.refs(), self.refs(self.o)
        rc, out = cli(self.w, "ensure", "--roadmap", rm(ALPHA), "--session", SID)
        self.assertEqual(rc, 0, out)
        self.assertIn("이 레포의 브랜치 규칙이 conductor/ 를 받지 않는다", out)
        self.assertEqual((self.refs(), self.refs(self.o)), (refs_w, refs_o))
        self.put({RULE_DOC: RULE_OK, ".devbrew.md": "---\nstate_branch: 끔\n---\n"})
        rc, out = cli(self.w, "ensure", "--roadmap", rm(ALPHA), "--session", SID)
        self.assertEqual(rc, 0, out)
        self.assertIn("상태 브랜치가 꺼져 있다", out)
        self.assertIsNone(CB.local_tip(self.w, ALPHA))
        self.put({".devbrew.md": "---\nstate_branch: 켬\n---\n"})                     # 양성 대조 — 규칙이 받고 켜져 있으면 만든다
        rc, _ = cli(self.w, "ensure", "--roadmap", rm(ALPHA), "--session", SID)
        self.assertIsNotNone(CB.local_tip(self.w, ALPHA))

    def test_roadmap_that_is_not_on_the_default_branch_gets_no_branch(self):
        ghost = "docs/superpowers/roadmaps/2026-09-09-ghost/roadmap.md"
        self.claim("2026-09-09-ghost")
        refs = self.refs()
        rc, out = cli(self.w, "ensure", "--roadmap", ghost, "--session", SID)
        self.assertEqual((rc, self.refs()), (1, refs), out)

    def test_a_branch_named_conductor_blocks_creation_loudly(self):   # Review Focus 5
        self.claim()
        self.g("branch", "conductor", "trunk")
        before = self.snap()
        rc, out = cli(self.w, "ensure", "--roadmap", rm(ALPHA), "--session", SID)
        self.assertEqual(rc, 3, out)
        self.assertIn("cannot lock ref 'refs/heads/conductor/" + ALPHA + "': 'refs/heads/conductor' exists", out)   # git 의 사유 줄이 실린다
        self.assertEqual(self.snap(), before)
        self.assertIsNone(CB.local_tip(self.w, ALPHA))

    def test_no_git_identity_stops_without_leftovers(self):   # Review Focus 3
        self.claim()
        for key in ("user.name", "user.email"):
            self.g("config", "--unset", key)
        self.g("config", "user.useConfigOnly", "true")
        refs = self.refs()
        scratch = self.t / "scratch-tmp"
        scratch.mkdir()
        rc, out = cli(self.w, "ensure", "--roadmap", rm(ALPHA), "--session", SID, env=dict(ENV, TMPDIR=str(scratch)))
        self.assertEqual((rc, self.refs()), (3, refs), out)
        self.assertIn("git config user.name", out)
        self.assertEqual(list(scratch.iterdir()), [])                       # 임시 index 폴더가 남지 않았다
        made = []
        real = CB.tempfile.mkdtemp

        def spy(*a, **k):
            made.append(real(*a, **k))
            return made[-1]
        with mock.patch.object(CB.tempfile, "mkdtemp", spy):
            with self.assertRaises(CB.BranchError) as c:
                CB.ensure(self.w, rm(ALPHA), SID)
        self.assertEqual(c.exception.rc, 3)
        self.assertEqual(len(made), 1)                                      # 양성 대조 — 임시 index 는 실제로 만들어졌고
        self.assertFalse(os.path.exists(made[0]))                           # 지워졌다


class Write(StateRepo):
    def setUp(self):
        super().setUp()
        self.claim()
        CB.ensure(self.w, rm(ALPHA), SID)
        self.team = CB.team_of(self.w, rm(ALPHA))

    def put_status(self, text, repo=None):
        return CB.write(repo or self.w, rm(ALPHA), SID, lambda base: {self.team.status: text}, "STATUS")

    def test_one_write_is_one_commit_and_no_checkout_moves(self):
        linked = self.t / "linked"
        self.g("worktree", "add", "-q", str(linked), "-b", "feature/x", "trunk")
        (linked / "wip.txt").write_text("x", encoding="utf-8")
        before = (self.snap(), self.snap(linked))
        first = CB.local_tip(self.w, ALPHA)
        r1 = self.put_status("하나\n")
        r2 = self.put_status("둘\n", repo=linked)                       # 다른 worktree 에서 불러도 같은 브랜치에 쓴다
        self.assertEqual((self.snap(), self.snap(linked)), before)
        self.assertEqual(self.g("rev-list", "--count", r2.commit), "3")
        self.assertEqual((self.g("rev-parse", r1.commit + "^"), self.g("rev-parse", r2.commit + "^")), (first, r1.commit))
        self.assertEqual(CB.read(self.w, r2.commit, self.team.status), "둘\n")
        self.assertTrue(r2.pushed)
        self.assertEqual(self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o), r2.commit)
        self.assertRegex(self.g("log", "-1", "--format=%s", r2.commit), r"^chore\(conductor\): STATUS · 세션 aaaa1111$")

    def test_nothing_changed_writes_nothing(self):
        r = self.put_status("같다\n")
        refs = self.refs()
        again = self.put_status("같다\n")
        self.assertEqual((again.commit, self.refs()), (None, refs))
        self.assertIsNone(CB.write(self.w, rm(ALPHA), SID, lambda base: None, "빈 고침").commit)
        self.assertIsNotNone(r.commit)

    def test_delete_and_nested_paths(self):
        letter = self.team.inbox + "/" + BETA + "/2026-11-19-01.md"
        CB.write(self.w, rm(ALPHA), SID, lambda base: {letter: "글\n", self.team.status: "s\n"}, "둘")
        r = CB.write(self.w, rm(ALPHA), SID, lambda base: {letter: None}, "지움")
        self.assertEqual([p for _m, p in CB.names(self.w, r.commit, self.team.dir + "/")], [self.team.status])
        self.assertEqual([m for m, _p in CB.names(self.w, r.commit, self.team.dir + "/")], ["100644"])   # 보통 파일 모드로 쓴다

    def test_paths_outside_the_roadmap_folder_are_refused(self):
        refs = self.refs()
        for path in ("src/code.py", self.team.dir + "/../x.md", "/abs.md", rm(BETA)):
            with self.assertRaises(CB.BranchError, msg=path) as c:
                CB.write(self.w, rm(ALPHA), SID, lambda base: {path: "x\n"}, "밖")
            self.assertEqual(c.exception.rc, 3)
        self.assertEqual(self.refs(), refs)

    def test_ref_moves_only_from_the_tip_that_was_read(self):
        """읽은 뒤 다른 쓰기가 끼어들면 그 커밋 위에서 다시 만든다. 뒤집으면 붉다 — update-ref 의 옛 값 인자를 빼면 ref 가
        그대로 덮여 edit 가 한 번만 불리고(calls[1] 이 없다) 끼어든 커밋이 내 커밋의 조상이 아니게 된다."""
        calls, intruder = [], []

        def edit(base):
            calls.append(base.commit)
            if len(calls) == 1:   # 첫 읽기와 ref 옮기기 사이에 다른 쓰기가 끼어든다
                tree = self.g("rev-parse", base.commit + "^{tree}")
                intruder.append(self.g("commit-tree", tree, "-p", base.commit, "-m", "끼어든 쓰기"))
                self.g("update-ref", CB.ref_of(ALPHA), intruder[0], base.commit)
            return {self.team.status: "내 쓰기\n"}
        r = CB.write(self.w, rm(ALPHA), SID, edit, "STATUS")
        self.assertEqual(calls[1], intruder[0])
        self.assertEqual(self.g("rev-parse", r.commit + "^"), intruder[0])
        self.assertEqual(self.rc("merge-base", "--is-ancestor", intruder[0], r.commit), 0)   # 종료 코드로 잰다 — 이 명령은 출력이 없다
        self.assertEqual(len(calls), 2)

    def test_write_before_ensure_and_without_the_marker(self):
        with self.assertRaises(CB.BranchError) as c:
            CB.write(self.w, rm(ALPHA), OTHER, lambda base: {self.team.status: "x\n"}, "STATUS")
        self.assertEqual(c.exception.rc, 5)
        self.claim(BETA)
        with self.assertRaises(CB.BranchError) as c:
            CB.write(self.w, rm(BETA), SID, lambda base: {CB.team_of(self.w, rm(BETA)).status: "x\n"}, "STATUS")
        self.assertEqual(c.exception.rc, 1)

    def test_shallow_clone_writes(self):
        d = self.clone("sh", "--depth", "1", "--no-local")
        self.assertEqual(self.g("rev-parse", "--is-shallow-repository", repo=d), "true")
        self.claim(repo=d)
        before = self.snap(d)
        CB.ensure(d, rm(ALPHA), SID)                                # 원격에 이미 있다 — 과제 6 이 받아 오게 한다. 이 과제에서는 만들기만 본다
        r = CB.write(d, rm(ALPHA), SID, lambda base: {self.team.status: "얕은 클론\n"}, "STATUS")
        self.assertIsNotNone(r.commit)
        self.assertEqual(self.snap(d), before)


class WriteFloorGuards(StateRepo):
    def setUp(self):
        super().setUp()
        self.claim()
        CB.ensure(self.w, rm(ALPHA), SID)
        self.team = CB.team_of(self.w, rm(ALPHA))

    def put_status(self, text):
        return CB.write(self.w, rm(ALPHA), SID, lambda base: {self.team.status: text}, "STATUS")

    def test_directory_and_file_conflicts_stop_and_write_nothing(self):   # I4 — 덮어써 지우지 않는다
        leaf = self.team.dir + "/x"
        CB.write(self.w, rm(ALPHA), SID, lambda base: {leaf: "파일\n"}, "파일")
        refs = self.refs()
        for conflict in (leaf + "/y", ):
            with self.assertRaises(CB.BranchError, msg=conflict) as c:
                CB.write(self.w, rm(ALPHA), SID, lambda base: {conflict: "아래\n"}, "충돌")
            self.assertEqual(c.exception.rc, 3)
        CB.write(self.w, rm(ALPHA), SID, lambda base: {self.team.dir + "/d/z": "z\n"}, "폴더")
        refs = self.refs()
        with self.assertRaises(CB.BranchError) as c:                          # 폴더가 있는 자리에 파일
            CB.write(self.w, rm(ALPHA), SID, lambda base: {self.team.dir + "/d": "파일\n"}, "충돌")
        self.assertEqual((c.exception.rc, self.refs()), (3, refs))
        self.assertEqual(CB.read(self.w, CB.local_tip(self.w, ALPHA), self.team.dir + "/d/z"), "z\n")

    def test_push_lands_exactly_on_the_local_commit(self):               # I1
        r = self.put_status("올라간다\n")
        self.assertEqual(self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o), r.commit)
        d = self.clone("sh2", "--depth", "1", "--no-local")
        self.claim(repo=d)
        remote_before = self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o)
        CB.ensure(d, rm(ALPHA), SID)                                       # 관계없는 뿌리를 만들고 — 올리기는 거절돼야 한다
        res = CB.write(d, rm(ALPHA), SID, lambda base: {self.team.status: "덮으려 한다\n"}, "STATUS")
        self.assertFalse(res.pushed)
        self.assertTrue(res.notes and res.notes[0].startswith(CB.NOT_PUSHED), res.notes)
        self.assertEqual(self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o), remote_before)   # 원격 끝이 덮이지 않았다


class MainCatchesEverything(StateRepo):
    def test_unexpected_exception_exits_3_with_one_line(self):            # I3
        import contextlib
        import io
        err = io.StringIO()
        with mock.patch.object(CB, "ensure", side_effect=RuntimeError("boom\n둘째 줄")), contextlib.redirect_stderr(err):
            rc = CB.main(["--root", str(self.w), "ensure", "--roadmap", rm(ALPHA), "--session", SID])
        self.assertEqual(rc, 3)
        self.assertEqual(len(err.getvalue().strip().splitlines()), 1)
        self.assertIn("RuntimeError", err.getvalue())


class GitGateGuards(StateRepo):
    def test_push_and_update_ref_refuse_overwriting_forms(self):         # I1
        ref = CB.ref_of(ALPHA)
        bad_push = (("--force", "origin", ref + ":" + ref), ("-f", "origin", ref + ":" + ref), ("--force-with-lease", "origin", ref),
                    ("--mirror", "origin"), ("--delete", "origin", ref), ("-d", "origin", ref), ("--porcelain", "origin", "+" + ref + ":" + ref),
                    ("--porcelain", "origin", ":" + ref))
        for form in bad_push:
            with self.assertRaises(RuntimeError, msg=form):
                CB.git(self.w, "push", *form)
        for form in (("-d", ref), (ref, "a" * 40), (ref, "a" * 40, "b" * 40, "c" * 40), ("--no-deref", ref, "a" * 40, "b" * 40)):
            with self.assertRaises(RuntimeError, msg=form):
                CB.git(self.w, "update-ref", *form)
        rc, _o, _e = CB.git(self.w, "push", "--porcelain", "origin", "HEAD:refs/heads/probe")   # 양성 대조 — 덮어쓰지 않는 꼴은 돈다
        self.assertEqual(rc, 0)


class WriteBoundary(unittest.TestCase):
    """경계 락 — 쓰기 바닥이 쓰는 git 명령 · 쓰면 안 되는 이름을 파일 본문으로 읽는다."""
    SRC = (SCRIPTS / "conductor_branch.py").read_text(encoding="utf-8")

    def test_write_floor_uses_only_plumbing_and_never_touches_the_checkout(self):
        for word in ("checkout", "switch", "worktree", "stash", "reset", "rebase", "commit", "merge"):
            self.assertNotIn(word, CB.GIT_ALLOWED, word)
        for word in ("hash-object", "read-tree", "update-index", "write-tree", "commit-tree", "update-ref", "push"):
            self.assertIn(word, CB.GIT_ALLOWED, word)
        calls = set(re.findall(r'git\(\s*root,\s*"([a-z-]+)"', self.SRC))
        self.assertTrue(calls <= CB.GIT_ALLOWED, calls - CB.GIT_ALLOWED)
        self.assertIn("GIT_INDEX_FILE", self.SRC)      # 임시 index — 작업 폴더의 index 를 쓰지 않는다
        self.assertNotIn('"add"', self.SRC)

    def test_update_ref_always_carries_the_old_value(self):
        self.assertRegex(self.SRC, r'"update-ref",\s*ref_of\(name\),\s*commit,\s*tip or ZERO_OID')
        self.assertEqual(CB.ZERO_OID, "0" * 40)

    def test_not_pushed_label_and_result_shape(self):
        self.assertEqual(CB.NOT_PUSHED, "아직 안 올라옴")
        self.assertEqual(CB.Result._fields, ("commit", "pushed", "onto", "notes"))
        self.assertEqual(CB.Base._fields, ("commit", "read", "names"))
