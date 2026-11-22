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
import conductor_state as cs  # noqa: E402
from state_path import state_root  # noqa: E402


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
        self.assertEqual(CB.bad_state_names(self.w), 0)                                       # 양성 대조 — 꼴 틀린 꼬리가 없으면 0
        for tail in ("-x", "Ev\u202eil", "a/b", BETA):
            self.g("update-ref", "refs/remotes/origin/conductor/" + tail, trunk)
        self.g("update-ref", "refs/heads/conductor/-y", trunk)
        self.g("update-ref", "refs/heads/conductor/-x", trunk)                                # 두 쪽에 같은 꼬리 — 한 번 센다
        self.g("update-ref", "refs/heads/conductor/" + ALPHA, trunk)
        self.assertEqual(CB.state_names(self.w), sorted([ALPHA, BETA]))
        self.assertEqual(CB.bad_state_names(self.w), 4)                                       # M25 ④ — state_names 가 버린 꼬리의 수


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

    def test_marker_owner_is_compared_whole_in_both_directions(self):
        # 붉어지는 뒤집기: `owner != session` 을 앞머리 견줌(`owner.startswith(session)` · `session.startswith(owner)`)으로 바꾸면 붉다.
        # 양성 대조: 각 로드맵에서 표지를 쥔 이름 그대로는 0 으로 만든다.
        self.claim(ALPHA, session=SID)
        self.claim(BETA, session=SID + "x")
        refs = self.refs()
        rc, out = cli(self.w, "ensure", "--roadmap", rm(ALPHA), "--session", SID + "x")   # 부르는 이름이 표지 주인 이름의 뒤로 더 길다
        self.assertEqual((rc, self.refs()), (5, refs), out)
        rc, out = cli(self.w, "ensure", "--roadmap", rm(BETA), "--session", SID)          # 표지 주인 이름이 부르는 이름의 뒤로 더 길다
        self.assertEqual((rc, self.refs()), (5, refs), out)
        for road, who in ((ALPHA, SID), (BETA, SID + "x")):
            rc, out = cli(self.w, "ensure", "--roadmap", rm(road), "--session", who)
            self.assertEqual(rc, 0, out)

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
        root = self.g("commit-tree", EMPTY_TREE, "-m", "관계없는 뿌리", repo=d)   # 과제 6 의 ensure 는 받아 온다 — 관계없는 뿌리는 손으로 둔다
        self.g("update-ref", CB.ref_of(ALPHA), root, repo=d)
        res = CB.write(d, rm(ALPHA), SID, lambda base: {self.team.status: "덮으려 한다\n"}, "STATUS")
        self.assertEqual((res.pushed, res.onto), (True, remote_before))                       # 거절된 뒤 원격 끝 위에 다시 만들었다
        self.assertEqual(self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o), res.commit)
        self.assertEqual(self.rc("merge-base", "--is-ancestor", remote_before, res.commit, repo=d), 0)   # 원격 끝이 덮이지 않았다
        self.assertEqual(self.rc("merge-base", "--is-ancestor", root, res.commit, repo=d), 1)          # 관계없는 뿌리는 이력에 들지 않는다


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
        self.assertEqual(CB.Result._fields, ("commit", "pushed", "onto", "notes", "made"))
        self.assertEqual(CB.Result(None, False, None, ()).made, ())   # 넷째 칸까지만 주는 옛 호출도 그대로 돈다
        self.assertEqual(CB.Base._fields, ("commit", "read", "names"))


class Publish(StateRepo):
    def setUp(self):
        super().setUp()
        self.claim()
        CB.ensure(self.w, rm(ALPHA), SID)
        self.team = CB.team_of(self.w, rm(ALPHA))
        self.received = self.team.path(CB.RECEIVED_FILE)
        self.m2 = self.clone("m2")                     # 같은 로드맵을 쓰는 다른 기계
        self.claim(repo=self.m2)

    @staticmethod
    def add_line(path, line):
        return lambda base: {path: (base.read(path) or "") + line + "\n"}

    def test_push_outcome_table(self):
        ref = "refs/heads/conductor/x:refs/heads/conductor/x"
        for rc, text, want in ((0, "To o\n*\t%s\t[new branch]\nDone\n" % ref, "ok"), (0, "To o\n \t%s\tabc..def\nDone\n" % ref, "ok"),
                               (1, "To o\n!\t%s\t[rejected] (fetch first)\nDone\n" % ref, "behind"),
                               (1, "To o\n!\t%s\t[rejected] (non-fast-forward)\nDone\n" % ref, "behind"),
                               (1, "To o\n!\t%s\t[remote rejected] (pre-receive hook declined)\nDone\n" % ref, "failed"),
                               (128, "", "failed"), (1, "!\t%s\t[rejected-ish]\n" % ref, "failed"), (1, "x [rejected] y\n", "failed")):
            self.assertEqual(CB.push_outcome(rc, text), want, text)

    def test_ensure_adopts_the_branch_another_machine_made(self):
        tip = CB.local_tip(self.w, ALPHA)
        r = CB.ensure(self.m2, rm(ALPHA), SID)
        self.assertEqual(CB.local_tip(self.m2, ALPHA), tip)       # 뿌리를 또 만들지 않는다
        self.assertIn("원격의 것을 받아 왔다", r.notes[0])
        self.assertEqual(self.g("rev-list", "--count", CB.ref_of(ALPHA), repo=self.o), "1")

    def test_rejected_push_is_remade_on_the_remote_tip_without_force(self):
        CB.ensure(self.m2, rm(ALPHA), SID)
        theirs = CB.write(self.m2, rm(ALPHA), SID, self.add_line(self.received, "- 저쪽 줄"), "받음")
        calls = []

        def status(base):
            calls.append(base.commit)
            return {self.team.status: "내 STATUS\n"}
        r = CB.write(self.w, rm(ALPHA), SID, status, "STATUS")
        self.assertEqual((r.onto, r.pushed, calls[-1]), (theirs.commit, True, theirs.commit))
        self.assertEqual(self.g("rev-parse", r.commit + "^"), theirs.commit)                  # 올라간 커밋 위에 얹었다 — 고치지 않았다
        self.assertTrue(any(n.startswith("다른 곳에서 이 브랜치에 썼다 — %s · " % theirs.commit[:8]) for n in r.notes), r.notes)
        self.assertEqual(self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o), r.commit)
        self.assertEqual(CB.read(self.w, r.commit, self.received), "- 저쪽 줄\n")
        self.assertEqual(CB.read(self.w, r.commit, self.team.status), "내 STATUS\n")

    def test_line_file_gets_the_same_edit_not_an_overwrite(self):
        CB.ensure(self.m2, rm(ALPHA), SID)
        CB.write(self.m2, rm(ALPHA), SID, self.add_line(self.received, "- 저쪽 줄"), "받음")
        r = CB.write(self.w, rm(ALPHA), SID, self.add_line(self.received, "- 이쪽 줄"), "받음")
        self.assertEqual(CB.read(self.w, r.commit, self.received), "- 저쪽 줄\n- 이쪽 줄\n")

    def test_no_origin_keeps_the_local_commit_and_the_next_write_carries_it(self):
        url = self.g("remote", "get-url", "origin")
        self.g("remote", "set-url", "origin", "file://" + str(self.t / "gone.git"))
        r1 = CB.write(self.w, rm(ALPHA), SID, self.add_line(self.received, "- 하나"), "받음")
        self.assertEqual((r1.pushed, CB.local_tip(self.w, ALPHA)), (False, r1.commit))
        self.assertTrue(any(n.startswith("아직 안 올라옴") for n in r1.notes), r1.notes)
        self.g("remote", "set-url", "origin", url)
        r2 = CB.write(self.w, rm(ALPHA), SID, self.add_line(self.received, "- 둘"), "받음")
        self.assertTrue(r2.pushed)
        self.assertEqual(self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o), r2.commit)
        self.assertEqual(self.rc("merge-base", "--is-ancestor", r1.commit, r2.commit), 0)
        self.assertFalse(any(str(self.t) in n or "file://" in n for n in r1.notes), r1.notes)   # 사유에 원격 주소 · 절대경로가 실리지 않는다(J55)

    def test_no_origin_at_all_exits_zero_from_the_command(self):   # AC3 — origin 이 없으면 로컬에만 쓰고 0
        self.g("remote", "remove", "origin")
        self.claim(BETA)
        rc, out = cli(self.w, "ensure", "--roadmap", rm(BETA), "--session", SID)
        self.assertEqual(rc, 0, out)
        self.assertIn("아직 안 올라옴", out)
        self.assertIsNotNone(CB.local_tip(self.w, BETA))

    def test_unpushed_earlier_commits_survive_a_later_rejection(self):   # J4
        CB.ensure(self.m2, rm(ALPHA), SID)
        letter = self.team.inbox + "/" + BETA + "/2026-11-19-01.md"
        url = self.g("remote", "get-url", "origin")
        self.g("remote", "set-url", "origin", "file://" + str(self.t / "gone.git"))
        CB.write(self.w, rm(ALPHA), SID, lambda base: {letter: "이쪽 글\n"}, "편지")
        CB.write(self.w, rm(ALPHA), SID, self.add_line(self.received, "- 이쪽 줄"), "받음")
        CB.write(self.m2, rm(ALPHA), SID, lambda base: {letter: "저쪽 글\n"}, "편지")
        theirs = CB.write(self.m2, rm(ALPHA), SID, self.add_line(self.received, "- 저쪽 줄"), "받음")
        self.g("remote", "set-url", "origin", url)
        r = CB.write(self.w, rm(ALPHA), SID, lambda base: {self.team.status: "내 STATUS\n"}, "STATUS")
        self.assertEqual((r.onto, r.pushed), (theirs.commit, True))
        self.assertEqual(self.rc("merge-base", "--is-ancestor", theirs.commit, r.commit), 0)
        self.assertEqual(CB.read(self.w, r.commit, letter), "저쪽 글\n")                                   # 올라간 글은 그대로
        self.assertEqual(CB.read(self.w, r.commit, letter.replace("-01.md", "-02.md")), "이쪽 글\n")       # 내 글은 다음 번호로
        self.assertEqual(CB.read(self.w, r.commit, self.received), "- 저쪽 줄\n- 이쪽 줄\n")
        self.assertEqual(self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o), r.commit)

    def offline(self):
        """origin 에 닿지 못하게 한다. 되돌릴 주소를 돌려준다."""
        url = self.g("remote", "get-url", "origin")
        self.g("remote", "set-url", "origin", "file://" + str(self.t / "gone.git"))
        return url

    def test_replayed_letter_names_stay_unique_across_the_whole_inbox(self):   # J4 · J23 — 경로가 아니라 이름을 inbox 전체에서 본다
        """뒤집으면 붉다 — 이름 겹침을 경로로만 보면 all/…-01 이 그대로 더해져 같은 이름의 글이 둘 생기고,
        같은 폴더에서만 다음 번호를 찾으면 …-03 이 둘 생긴다. 읽는 쪽은 그런 글을 둘 다 내지 않는다(J24)."""
        CB.ensure(self.m2, rm(ALPHA), SID)
        inbox = self.team.inbox + "/"
        url = self.offline()
        CB.write(self.w, rm(ALPHA), SID, lambda base: {inbox + "all/2026-11-19-01.md": "이쪽 모두에게\n"}, "편지")        # 폴더는 다르고 이름이 같다
        CB.write(self.w, rm(ALPHA), SID, lambda base: {inbox + BETA + "/2026-11-19-02.md": "이쪽 베타에게\n"}, "편지")   # 경로가 같고 글이 다르다
        CB.write(self.m2, rm(ALPHA), SID, lambda base: {inbox + BETA + "/2026-11-19-01.md": "저쪽 1\n"}, "편지")
        CB.write(self.m2, rm(ALPHA), SID, lambda base: {inbox + BETA + "/2026-11-19-02.md": "저쪽 2\n"}, "편지")
        CB.write(self.m2, rm(ALPHA), SID, lambda base: {inbox + "all/2026-11-19-03.md": "저쪽 3\n"}, "편지")            # 다음 번호가 다른 폴더에 이미 있다
        self.g("remote", "set-url", "origin", url)
        r = CB.write(self.w, rm(ALPHA), SID, lambda base: {self.team.status: "s\n"}, "STATUS")
        got = {p[len(inbox):]: CB.read(self.w, r.commit, p) for _m, p in CB.names(self.w, r.commit, inbox)}
        self.assertEqual(got, {BETA + "/2026-11-19-01.md": "저쪽 1\n", BETA + "/2026-11-19-02.md": "저쪽 2\n", "all/2026-11-19-03.md": "저쪽 3\n",
                               "all/2026-11-19-04.md": "이쪽 모두에게\n", BETA + "/2026-11-19-05.md": "이쪽 베타에게\n"})
        names = [p.rsplit("/", 1)[1] for p in got]
        self.assertEqual(len(names), len(set(names)))

    def test_same_letter_on_both_sides_is_not_doubled(self):
        CB.ensure(self.m2, rm(ALPHA), SID)
        path = self.team.inbox + "/all/2026-11-19-01.md"
        url = self.offline()
        CB.write(self.w, rm(ALPHA), SID, lambda base: {path: "같은 글\n"}, "편지")
        CB.write(self.m2, rm(ALPHA), SID, lambda base: {path: "같은 글\n"}, "편지")          # 같은 경로 · 같은 글
        self.g("remote", "set-url", "origin", url)
        r = CB.write(self.w, rm(ALPHA), SID, lambda base: {self.team.status: "s\n"}, "STATUS")
        self.assertEqual([p for _m, p in CB.names(self.w, r.commit, self.team.inbox + "/")], [path])

    def test_line_file_replay_counts_lines_as_a_multiset(self):   # J52
        CB.ensure(self.m2, rm(ALPHA), SID)
        url = self.offline()
        CB.write(self.w, rm(ALPHA), SID, lambda base: {self.received: "- 같은 줄\n- 같은 줄\n- 지울 줄\n"}, "받음")      # 같은 줄 둘을 더한다
        CB.write(self.w, rm(ALPHA), SID, lambda base: {self.received: "- 같은 줄\n- 같은 줄\n"}, "받음")                 # 한 줄을 뺀다
        CB.write(self.m2, rm(ALPHA), SID, lambda base: {self.received: "- 같은 줄\n- 지울 줄\n- 지울 줄\n"}, "받음")     # 저쪽에도 같은 글자의 줄이 있다
        self.g("remote", "set-url", "origin", url)
        r = CB.write(self.w, rm(ALPHA), SID, lambda base: {self.team.status: "s\n"}, "STATUS")
        # 저쪽 셋 + 더한 셋(이미 있어도 더한다) − 뺀 하나(앞에서부터 하나만)
        self.assertEqual(CB.read(self.w, r.commit, self.received), "- 같은 줄\n- 지울 줄\n- 같은 줄\n- 같은 줄\n- 지울 줄\n")

    def test_two_rejections_in_a_row_run_the_edit_once_per_attempt_and_leave_one_copy(self):   # J4 — 이번 쓰기는 다시 얹지 않는다
        """뒤집으면 붉다 — 둘째 거절에서 앞 시도의 「이번 쓰기」 커밋까지 다시 얹으면 번호를 다시 센 같은 글이 둘 실린다."""
        from unittest import mock
        CB.ensure(self.m2, rm(ALPHA), SID)
        CB.write(self.m2, rm(ALPHA), SID, self.add_line(self.received, "- 저쪽 줄 1"), "받음")       # 첫 거절의 까닭
        real_fetch, sneaked, bases = CB.fetch_state, [], []

        def fetch_then_the_other_machine_writes_again(root, name):
            tip = real_fetch(root, name)
            if not sneaked:                                                                         # 받아 온 직후 다른 기계가 한 번 더 쓴다 — 둘째 거절의 까닭
                sneaked.append(CB.write(self.m2, rm(ALPHA), SID, self.add_line(self.received, "- 저쪽 줄 2"), "받음").commit)
            return tip

        def numbered(base):                                                                         # send 처럼 새 끝에서 번호를 다시 센다
            bases.append(base.commit)
            taken = base.names(self.team.inbox + "/")
            return {self.team.inbox + "/all/2026-11-19-%02d.md" % (len(taken) + 1): "내 글\n"}
        with mock.patch.object(CB, "fetch_state", side_effect=fetch_then_the_other_machine_writes_again):
            r = CB.write(self.w, rm(ALPHA), SID, numbered, "편지")
        self.assertEqual((len(bases), len(set(bases))), (3, 3))                                     # 처음 한 번 + 거절마다 새 끝에서 한 번
        self.assertEqual((r.pushed, r.onto), (True, sneaked[0]))
        self.assertEqual([p for _m, p in CB.names(self.w, r.commit, self.team.inbox + "/")],
                         [self.team.inbox + "/all/2026-11-19-01.md"])                               # 같은 글이 두 번 실리지 않는다
        self.assertEqual(CB.read(self.w, r.commit, self.received), "- 저쪽 줄 1\n- 저쪽 줄 2\n")

    def test_remote_that_refuses_is_not_retried(self):
        hook = self.o / "hooks" / "pre-receive"
        hook.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
        hook.chmod(0o755)
        r = CB.write(self.w, rm(ALPHA), SID, self.add_line(self.received, "- 줄"), "받음")
        self.assertEqual((r.pushed, r.onto), (False, None))
        self.assertTrue(any(n.startswith("아직 안 올라옴") for n in r.notes), r.notes)

    def test_three_rejections_stop_with_the_local_commit_kept(self):   # 거절은 실제다 — 받아 올 때마다 다른 기계가 또 올린다
        from unittest import mock
        CB.ensure(self.m2, rm(ALPHA), SID)
        CB.write(self.m2, rm(ALPHA), SID, self.add_line(self.received, "- 저쪽 줄 0"), "받음")   # 처음 올리기의 거절 까닭
        real_fetch, fetched, judged, other = CB.fetch_state, [], [], []
        real_judge = CB.push_outcome

        def fetch_then_the_other_machine_writes(root, name):
            tip = real_fetch(root, name)
            fetched.append(tip)
            other.append(True)                                                             # 저쪽 기계의 올리기 판정은 세지 않는다
            CB.write(self.m2, rm(ALPHA), SID, self.add_line(self.received, "- 저쪽 줄 %d" % len(fetched)), "받음")
            other.pop()
            return tip

        def judge(rc, text):
            verdict = real_judge(rc, text)
            if not other:
                judged.append(verdict)
            return verdict
        with mock.patch.object(CB, "fetch_state", side_effect=fetch_then_the_other_machine_writes), \
                mock.patch.object(CB, "push_outcome", side_effect=judge):
            with self.assertRaises(CB.BranchError) as c:
                CB.write(self.w, rm(ALPHA), SID, self.add_line(self.received, "- 이쪽 줄"), "받음")
        self.assertEqual((c.exception.rc, judged), (1, ["behind"] * 4))                 # 처음 한 번 + 다시 만들기 세 번 — 모두 실제 거절
        self.assertIn("세 번 다시 만들어도 올리지 못했다", str(c.exception))
        local = CB.local_tip(self.w, ALPHA)
        self.assertEqual(self.g("rev-parse", local + "^"), fetched[-1])                   # 로컬 커밋은 마지막으로 받아 온 끝 위에 남았다
        self.assertNotEqual(self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o), local)   # 올라가지 않았다
        self.assertEqual(CB.read(self.w, local, self.received),
                         "- 저쪽 줄 0\n- 저쪽 줄 1\n- 저쪽 줄 2\n- 이쪽 줄\n")              # 이번 쓰기의 고침은 꼭 한 번

    def test_single_branch_shallow_clone_fetches_by_explicit_refspec(self):   # Review Focus 2
        d = self.clone("sh", "--depth", "1", "--no-local")
        self.assertEqual(self.g("config", "--get-all", "remote.origin.fetch", repo=d), "+refs/heads/trunk:refs/remotes/origin/trunk")
        self.claim(repo=d)
        CB.ensure(d, rm(ALPHA), SID)
        theirs = CB.write(self.w, rm(ALPHA), SID, self.add_line(self.received, "- 저쪽 줄"), "받음")
        r = CB.write(d, rm(ALPHA), SID, self.add_line(self.received, "- 얕은 쪽 줄"), "받음")
        self.assertEqual((r.onto, r.pushed), (theirs.commit, True))
        self.assertEqual(CB.read(d, r.commit, self.received), "- 저쪽 줄\n- 얕은 쪽 줄\n")

    def test_elsewhere_names_the_remote_tip_and_its_own_time(self):
        CB.ensure(self.m2, rm(ALPHA), SID)
        theirs = CB.write(self.m2, rm(ALPHA), SID, self.add_line(self.received, "- 저쪽 줄"), "받음")
        when = self.g("log", "-1", "--format=%cd", "--date=format:%Y-%m-%d %H:%M %z", theirs.commit, repo=self.m2)   # 그 커밋의 시간대 그대로
        r = CB.write(self.w, rm(ALPHA), SID, lambda base: {self.team.status: "s\n"}, "STATUS")
        self.assertEqual(r.notes, (CB.ELSEWHERE % (theirs.commit[:8], when),))
        self.assertRegex(when, r"^\d{4}-\d\d-\d\d \d\d:\d\d [+-]\d{4}$")

    def test_a_race_between_ls_remote_and_the_first_push_adopts_instead_of_claiming_creation(self):
        tip = CB.local_tip(self.w, ALPHA)
        with mock.patch.object(CB, "git", side_effect=lambda root, *a, **k: (2, "", "") if a[:1] == ("ls-remote",) else REAL_GIT(root, *a, **k)):
            r = CB.ensure(self.m2, rm(ALPHA), SID)                                         # 원격에 없다고 본 뒤 만든 뿌리는 거절된다
        self.assertEqual((r.pushed, r.onto, CB.local_tip(self.m2, ALPHA)), (True, tip, tip))
        self.assertTrue(r.notes[0].startswith("원격의 것을 받아 왔다 — "), r.notes)
        self.assertEqual(self.g("rev-list", "--count", CB.ref_of(ALPHA), repo=self.o), "1")

    def test_a_local_write_during_a_remake_is_replayed_not_overwritten(self):   # 옛 값 조건 — 다시 만들기의 update-ref
        """뒤집으면 붉다 — 다시 만든 끝을 그 시도가 읽은 로컬 끝이 아닌 값을 옛 값으로 두면 그 사이 로컬에 끼어든 커밋이 사라진다."""
        CB.ensure(self.m2, rm(ALPHA), SID)
        CB.write(self.m2, rm(ALPHA), SID, self.add_line(self.received, "- 저쪽 줄"), "받음")
        pending, calls = self.team.path(CB.PENDING_FILE), []

        def edit(base):
            calls.append(base.commit)
            if len(calls) == 2:   # 첫 다시 만들기 — 받아 온 뒤 · ref 를 옮기기 전에 로컬에 다른 쓰기가 끼어든다
                local = CB.local_tip(self.w, ALPHA)
                sneak = CB._build_commit(self.w, local, {pending: "- 끼어든 줄\n"}, "끼어든 쓰기", False)
                self.g("update-ref", CB.ref_of(ALPHA), sneak, local)
            return {self.team.status: "내 STATUS\n"}
        r = CB.write(self.w, rm(ALPHA), SID, edit, "STATUS")
        self.assertTrue(r.pushed)
        self.assertEqual(CB.read(self.w, r.commit, pending), "- 끼어든 줄\n")         # 끼어든 커밋은 다음 시도에서 다시 얹혔다
        self.assertEqual(CB.read(self.w, r.commit, self.received), "- 저쪽 줄\n")
        self.assertEqual(len(calls), 3)                                                  # 옮기기 실패도 한 번으로 센다

    def test_push_outcome_needs_the_bang_flag_and_the_third_cell(self):
        ref = "refs/heads/conductor/x:refs/heads/conductor/x"
        for text in (" \t%s\t[rejected] (fetch first)\n" % ref, "=\t%s\t[rejected] (non-fast-forward)\n" % ref,
                     "!\t[rejected]\t%s\n" % ref, "!\t%s\n" % ref):
            self.assertEqual(CB.push_outcome(1, text), "failed", text)
        self.assertEqual(CB.push_outcome(1, "To o\n!\t%s\t[rejected] (stale info)\n" % ref), "behind")   # 양성 대조

    def test_letters_renamed_within_one_replayed_commit_count_each_other(self):   # J23 — 이 다시 얹기에서 앞서 더한 이름도 센다
        """뒤집으면 붉다 — 한 커밋 안에서 앞서 더한 이름을 세지 않으면 둘이 같은 번호를 받아 하나가 덮이고,
        그대로 더한 이름을 세지 않으면 다른 폴더의 같은 이름이 또 그대로 더해진다."""
        CB.ensure(self.m2, rm(ALPHA), SID)
        inbox = self.team.inbox + "/"
        url = self.offline()
        CB.write(self.w, rm(ALPHA), SID, lambda base: {inbox + "all/2026-11-19-01.md": "이쪽 가\n", inbox + "all/2026-11-19-02.md": "이쪽 나\n",
                                                       inbox + "all/2026-11-19-05.md": "이쪽 다\n", inbox + BETA + "/2026-11-19-05.md": "이쪽 라\n"}, "편지")
        CB.write(self.m2, rm(ALPHA), SID, lambda base: {inbox + "all/2026-11-19-01.md": "저쪽 1\n", inbox + "all/2026-11-19-02.md": "저쪽 2\n"}, "편지")
        self.g("remote", "set-url", "origin", url)
        r = CB.write(self.w, rm(ALPHA), SID, lambda base: {self.team.status: "s\n"}, "STATUS")
        got = {p[len(inbox):]: CB.read(self.w, r.commit, p) for _m, p in CB.names(self.w, r.commit, inbox)}
        # 경로 차례(BETA 폴더가 먼저) — BETA/05 는 그대로, 겹치는 all/01 · all/02 · all/05 는 06 · 07 · 08
        self.assertEqual(got, {"all/2026-11-19-01.md": "저쪽 1\n", "all/2026-11-19-02.md": "저쪽 2\n", BETA + "/2026-11-19-05.md": "이쪽 라\n",
                               "all/2026-11-19-06.md": "이쪽 가\n", "all/2026-11-19-07.md": "이쪽 나\n", "all/2026-11-19-08.md": "이쪽 다\n"})

    def odd_commit(self, repo, committer_time):
        """그 클론의 상태 브랜치 끝 위에 committer 때가 이상한 커밋을 손으로 만들어 올린다(git 의 날짜 검사를 지나지 않게)."""
        tip = CB.local_tip(repo, ALPHA)
        body = ("tree %s\nparent %s\nauthor x <x@example.invalid> 1700000000 +0000\ncommitter x <x@example.invalid> %s\n\n이상한 때\n"
                % (self.g("rev-parse", tip + "^{tree}", repo=repo), tip, committer_time))
        p = subprocess.run(["git", "hash-object", "-t", "commit", "-w", "--literally", "--stdin"], cwd=str(repo), env=ENV,
                           input=body, capture_output=True, encoding="utf-8", check=True)
        odd = p.stdout.strip()
        self.g("update-ref", CB.ref_of(ALPHA), odd, tip, repo=repo)
        self.g("push", "-q", "origin", "%s:%s" % (CB.ref_of(ALPHA), CB.ref_of(ALPHA)), repo=repo)
        return odd

    def test_a_remote_tip_with_an_impossible_time_does_not_stop_the_rebuild(self):   # 남의 글 — 시간대 · 때가 범위 밖
        """뒤집으면 붉다 — 시간대 범위를 보지 않거나 바꾸기 오류를 잡지 않으면 ref 를 옮긴 뒤 올리기 전에 예외로 죽는다."""
        CB.ensure(self.m2, rm(ALPHA), SID)
        for n, when in enumerate(("1700000000 +9900", "99999999999999 +0000", "1700000000 +0099")):
            odd = self.odd_commit(self.m2, when)
            r = CB.write(self.w, rm(ALPHA), SID, self.add_line(self.received, "- 이쪽 줄 %d" % n), "받음")
            self.assertEqual((r.pushed, r.onto), (True, odd), when)
            self.assertEqual(r.notes, (CB.ELSEWHERE % (odd[:8], CB.STAMP_UNKNOWN),), when)
            self.g("fetch", "-q", "origin", "+%s:%s" % (CB.ref_of(ALPHA), CB.ref_of(ALPHA)), repo=self.m2)   # 다음 이상한 커밋을 새 끝 위에

    def test_letter_names_with_other_scripts_digits_are_not_numbers(self):   # 남의 글 — `\d` 는 ٩٩ 도 받는다
        self.assertEqual(CB.next_letter_name(["all/2026-11-19-\u0669\u0669.md", "all/2026-11-19-01.md"], "2026-11-19"), "2026-11-19-02.md")
        self.assertEqual(CB.next_letter_name(["\uff12\uff10\uff12\uff16-11-19-05.md"], "\uff12\uff10\uff12\uff16-11-19"),
                         "\uff12\uff10\uff12\uff16-11-19-01.md")   # 전각 숫자 날짜도 꼴 밖이다
        CB.ensure(self.m2, rm(ALPHA), SID)
        inbox = self.team.inbox + "/"
        url = self.offline()
        CB.write(self.w, rm(ALPHA), SID, lambda base: {inbox + "all/2026-11-19-01.md": "이쪽\n"}, "편지")
        CB.write(self.m2, rm(ALPHA), SID, lambda base: {inbox + "all/2026-11-19-\u0669\u0669.md": "저쪽 ٩٩\n",
                                                        inbox + BETA + "/2026-11-19-01.md": "저쪽\n"}, "편지")
        self.g("remote", "set-url", "origin", url)
        r = CB.write(self.w, rm(ALPHA), SID, lambda base: {self.team.status: "s\n"}, "STATUS")   # 다시 얹기가 막히지 않는다
        self.assertTrue(r.pushed)
        self.assertEqual(CB.read(self.w, r.commit, inbox + "all/2026-11-19-02.md"), "이쪽\n")

    def test_failed_push_reason_is_the_rejection_cell_not_the_error_banner(self):   # 과제 5 리뷰 M4
        hook = self.o / "hooks" / "pre-receive"
        hook.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
        hook.chmod(0o755)
        r = CB.write(self.w, rm(ALPHA), SID, self.add_line(self.received, "- 줄"), "받음")
        self.assertEqual(r.notes, (CB.NOT_PUSHED + " — [remote rejected] (pre-receive hook declined)",))
        self.assertEqual(CB.local_tip(self.w, ALPHA), r.commit)                       # 로컬 커밋은 남는다

    def test_a_renamed_letter_deleted_later_in_the_chain_does_not_delete_the_remote_letter(self):   # J4 — 이름을 바꾼 편지의 뒤 고침은 바꾼 이름에
        """뒤집으면 붉다 — 지움을 원래 경로에 그대로 적용하면 저쪽 기계가 쓴 같은 이름의 편지가 지워지고 바꾼 이름의 사본이 남는다."""
        CB.ensure(self.m2, rm(ALPHA), SID)
        letter = self.team.inbox + "/" + BETA + "/2026-11-19-01.md"
        url = self.offline()
        CB.write(self.w, rm(ALPHA), SID, lambda base: {letter: "이쪽 글\n"}, "편지")
        CB.write(self.w, rm(ALPHA), SID, lambda base: {letter: None}, "지움")
        CB.write(self.m2, rm(ALPHA), SID, lambda base: {letter: "저쪽 글\n"}, "편지")
        self.g("remote", "set-url", "origin", url)
        r = CB.write(self.w, rm(ALPHA), SID, lambda base: {self.team.status: "s\n"}, "STATUS")
        self.assertEqual([p for _m, p in CB.names(self.w, r.commit, self.team.inbox + "/")], [letter])
        self.assertEqual(CB.read(self.w, r.commit, letter), "저쪽 글\n")

    def test_replayed_commit_keeps_its_message_and_status_is_not_replayed(self):   # J4 — 계산물은 다시 얹지 않는다
        CB.ensure(self.m2, rm(ALPHA), SID)
        url = self.offline()
        early = CB.write(self.w, rm(ALPHA), SID, lambda base: {self.received: "- 이쪽 줄\n", self.team.status: "옛 STATUS\n"}, "받음과 STATUS")
        theirs = CB.write(self.m2, rm(ALPHA), SID, lambda base: {self.team.status: "저쪽 STATUS\n"}, "STATUS")
        self.g("remote", "set-url", "origin", url)
        r = CB.write(self.w, rm(ALPHA), SID, self.add_line(self.received, "- 둘"), "받음")
        replayed = self.g("rev-parse", r.commit + "^")
        self.assertEqual(self.g("rev-parse", replayed + "^"), theirs.commit)
        self.assertEqual(self.g("log", "-1", "--format=%B", replayed), self.g("log", "-1", "--format=%B", early.commit))
        self.assertEqual(CB.read(self.w, r.commit, self.team.status), "저쪽 STATUS\n")   # 옛 계산물로 덮지 않는다
        self.assertEqual(CB.read(self.w, r.commit, self.received), "- 이쪽 줄\n- 둘\n")


EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
REAL_GIT = CB.git


class EnsureRace(StateRepo):
    def test_a_tip_that_appears_mid_creation_is_reported_not_built_on(self):   # 과제 5 리뷰 M1 · AC1 — 있으면 아무것도 바꾸지 않는다
        self.claim()
        real, appeared = CB._build_commit, []

        def build_then_another_writer_creates(root, tip, changes, message, force):
            commit = real(root, tip, changes, message, force)
            if not appeared:
                appeared.append(self.g("commit-tree", EMPTY_TREE, "-m", "다른 쓰기"))
                self.g("update-ref", CB.ref_of(ALPHA), appeared[0])
            return commit
        with mock.patch.object(CB, "_build_commit", side_effect=build_then_another_writer_creates):
            r = CB.ensure(self.w, rm(ALPHA), SID)
        self.assertEqual(CB.local_tip(self.w, ALPHA), appeared[0])                     # 그 위에 빈 커밋을 얹지 않았다
        self.assertEqual((r.commit, r.notes), (None, ("있다 — %s(%s)" % (CB.branch_of(ALPHA), appeared[0][:8]),)))


class EnsureFetchFails(StateRepo):
    def test_remote_branch_that_cannot_be_fetched_is_not_recreated(self):   # J6 — 원격에 있으면 둘째 뿌리를 만들지 않는다
        """뒤집으면 붉다 — 받아 오지 못했을 때 뿌리를 만들면 「만들었다」 가 나오고 원격과 관계없는 브랜치가 생긴다."""
        self.claim()
        m2 = self.clone("m2")
        self.claim(repo=m2)
        CB.ensure(m2, rm(ALPHA), SID)                                                          # 원격에 있다
        secret = str(self.t / "secret" / "path.git")
        fake = lambda root, *a, **k: ((128, "", "fatal: '%s' does not appear to be a git repository\n" % secret)
                                      if a[:1] == ("fetch",) else REAL_GIT(root, *a, **k))
        refs = self.refs()
        with mock.patch.object(CB, "git", side_effect=fake):
            with self.assertRaises(CB.BranchError) as c:
                CB.ensure(self.w, rm(ALPHA), SID)
        self.assertEqual(c.exception.rc, 3)
        self.assertIn("받아 오지 못했다", str(c.exception))
        self.assertIn("<경로>", str(c.exception))
        self.assertNotIn(secret, str(c.exception))
        self.assertEqual((self.refs(), CB.local_tip(self.w, ALPHA)), (refs, None))               # 아무것도 만들지 않았다
        rc, out = cli(self.w, "ensure", "--roadmap", rm(ALPHA), "--session", SID)                # 양성 대조 — 받아 오면 받는다
        self.assertEqual(rc, 0, out)
        self.assertIn("원격의 것을 받아 왔다", out)


class LetterNames(unittest.TestCase):
    def test_next_number_is_one_past_the_largest_of_that_day_across_the_whole_inbox(self):   # 판정 P3 · J23
        N = CB.next_letter_name
        self.assertEqual(N([], "2026-11-19"), "2026-11-19-01.md")
        self.assertEqual(N(["a/2026-11-19-01.md", "b/2026-11-19-03.md"], "2026-11-19"), "2026-11-19-04.md")   # 구멍(02)을 다시 쓰지 않는다
        self.assertEqual(N(["2026-11-18-07.md", "c/2026-11-19-02.md", "c/2026-11-19-05.md.bak", "note.md", "2026-11-19-5.md"],
                           "2026-11-19"), "2026-11-19-03.md")                                                # 다른 날 · 꼴 밖 이름은 세지 않는다
        self.assertEqual(N(["2026-11-19-98.md"], "2026-11-19"), "2026-11-19-99.md")                          # 경계 양성 대조
        with self.assertRaises(CB.BranchError) as c:
            N(["x/2026-11-19-99.md"], "2026-11-19")
        self.assertEqual(c.exception.rc, 2)


class PublishGateGuards(StateRepo):
    def test_fetch_and_ls_remote_take_only_the_safe_forms(self):
        for form in (("fetch", "origin", "+refs/heads/trunk:refs/heads/trunk"), ("fetch", "origin", "refs/heads/x"), ("fetch", "origin"),
                     ("fetch", "--upload-pack=touch x", "origin", "+refs/heads/a:refs/remotes/origin/a"),
                     ("fetch", "other", "+refs/heads/a:refs/remotes/origin/a"), ("ls-remote", "--upload-pack=touch x", "origin"),
                     ("remote", "add", "x", "y")):
            with self.assertRaises(RuntimeError, msg=form):
                CB.git(self.w, *form)
        self.assertIsNone(CB.fetch_state(self.w, ALPHA))                                       # 원격에 없다 — 실패는 None
        self.assertEqual(CB.git(self.w, "fetch", "origin", "+refs/heads/trunk:refs/remotes/origin/trunk")[0], 0)   # 양성 대조
        self.assertEqual(CB.git(self.w, "ls-remote", "--exit-code", "origin", "refs/heads/trunk")[0], 0)


class PublishBoundary(unittest.TestCase):
    """경계 락 — 올리기 · 다시 만들기가 쓰는 git 명령의 꼴을 파일 본문으로 읽는다."""
    SRC = (SCRIPTS / "conductor_branch.py").read_text(encoding="utf-8")

    def test_new_commands_are_allowed_and_remote_is_not(self):
        for word in ("fetch", "ls-remote", "rev-list", "diff-tree"):
            self.assertIn(word, CB.GIT_ALLOWED, word)
        self.assertNotIn("remote", CB.GIT_ALLOWED)                     # remote 는 쓰는 꼴(add · set-url · remove)을 가진다

    def test_every_update_ref_call_carries_ref_new_and_old(self):
        sites = re.findall(r'git\(root, "update-ref"[^\n]*', self.SRC)
        full = [s for s in sites if re.match(r'git\(root, "update-ref", [^,()]+(?:\([^()]*\))?, [^,]+, [^,)]+\)', s)]
        self.assertGreaterEqual(len(sites), 3, sites)                   # 처음 쓰기 · 다시 만들기 · 받아 온 끝 두기
        self.assertEqual(full, sites)

    def test_fetch_lands_in_the_remote_tracking_ref_only(self):
        sites = re.findall(r'git\(root, "fetch"[^\n]*', self.SRC)
        self.assertEqual(len(sites), 1, sites)
        self.assertIn('"refs/remotes/origin/"', self.SRC)
        self.assertEqual(CB.NET_TIMEOUT, 60)


class Delete(StateRepo):
    def setUp(self):
        super().setUp()
        import conductor_mail as CM
        for name in (ALPHA, BETA):
            self.claim(name)
            CB.ensure(self.w, rm(name), SID)
        CM.send(self.w, rm(ALPHA), SID, BETA, "예고", "아직 읽지 않았을 글")
        CM.send(self.w, rm(BETA), SID, ALPHA, "질문", "답을 기다리는 질문")
        team = CB.team_of(self.w, rm(ALPHA))
        CB.write(self.w, rm(ALPHA), SID, lambda base: {team.path(CB.PENDING_FILE): "- A1 · 결정 기록 · 줄 하나\n- A1 · 결정 기록 · 줄 둘\n"}, "대기 줄")

    def test_without_confirmation_it_counts_and_keeps_the_branch(self):  # R3 AC23
        tip = CB.local_tip(self.w, ALPHA)
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID)
        self.assertEqual((rc, CB.local_tip(self.w, ALPHA)), (1, tip), out)
        self.assertEqual(self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o), tip)
        self.assertIn("상대가 아직 받지 않은 보낸 글 1 · 내가 답하지 않은 온 질문 1 · 남은 대기 줄 2 · 안 올린 규칙 고침 0줄", out)
        self.assertIn("--confirmed", out)
        self.assertIn("수를 센 끝: " + tip, out)
        self.assertEqual(len([ln for ln in out.splitlines() if ln.startswith("[spec-distill] ") or ln.startswith("수를 센 끝")]), 2)

    def test_confirmed_deletes_local_and_remote_and_nothing_else(self):  # R3 AC23
        before, beta, tip = self.snap(), CB.local_tip(self.w, BETA), CB.local_tip(self.w, ALPHA)
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", tip)
        self.assertEqual(rc, 0, out)
        self.assertIsNone(CB.local_tip(self.w, ALPHA))
        self.assertEqual(self.g("rev-parse", "--verify", "-q", CB.ref_of(ALPHA), repo=self.o, check=False), "")
        self.assertEqual((self.snap(), CB.local_tip(self.w, BETA)), (before, beta))               # 다른 로드맵의 브랜치와 작업 폴더는 그대로
        self.assertEqual(self.g("rev-parse", CB.ref_of(BETA), repo=self.o), beta)
        self.assertEqual(self.g("for-each-ref", "refs/remotes/origin/conductor/" + ALPHA), "")     # 원격 추적 ref 도 남지 않는다
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", tip)
        self.assertEqual(rc, 1, out)                                                              # 이미 없다

    def test_delete_empties_the_trust_section(self):   # M35 — 다시 만든 브랜치에서 옛 확인 끝이 판정을 영영 None 으로 두지 않게
        path, beta = (cs.machine_path(state_root(str(self.w)), rm(name)) for name in (ALPHA, BETA))
        self.assertNotEqual(cs.load(path, rm(ALPHA))[cs.TRUST], [])   # 양성 대조 — 지우기 전에는 「씀」 줄이 있다
        kept = cs.load(beta, rm(BETA))[cs.TRUST]
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", CB.local_tip(self.w, ALPHA))
        self.assertEqual(rc, 0, out)
        self.assertEqual(cs.load(path, rm(ALPHA))[cs.TRUST], [])
        self.assertEqual(cs.load(beta, rm(BETA))[cs.TRUST], kept)   # 다른 로드맵의 절은 그대로

    def test_delete_that_does_not_delete_keeps_the_trust_section(self):   # 확인 없이 센 것뿐이면 비우지 않는다
        path = cs.machine_path(state_root(str(self.w)), rm(ALPHA))
        before = cs.load(path, rm(ALPHA))[cs.TRUST]
        self.assertEqual(cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID)[0], 1)
        self.assertEqual(cs.load(path, rm(ALPHA))[cs.TRUST], before)

    def test_only_the_marker_holder_deletes(self):  # R3 AC23
        tip = CB.local_tip(self.w, ALPHA)
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", OTHER, "--confirmed", CB.local_tip(self.w, ALPHA))
        self.assertEqual((rc, CB.local_tip(self.w, ALPHA)), (5, tip), out)

    def test_remote_that_moved_is_not_deleted_and_the_count_is_taken_again(self):   # J39 — 다른 기계가 올린 글을 세지 않고 지우지 않는다  # R3 AC23
        """뒤집으면 붉다 — 받아 와 견주지 않고 지우면 첫 --confirmed 가 0 으로 끝나고 다른 기계의 글이 원격에서 사라진다."""
        import conductor_mail as CM
        m2 = self.clone("m2")
        self.claim(repo=m2)
        CB.ensure(m2, rm(ALPHA), SID)
        theirs = CM.send(m2, rm(ALPHA), SID, BETA, "예고", "다른 기계가 올린 글")[0].commit
        mine = CB.local_tip(self.w, ALPHA)
        self.assertNotEqual(mine, theirs)
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", mine)
        self.assertEqual(rc, 1, out)
        self.assertEqual(self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o), theirs)                # 원격은 그대로다
        self.assertIn("상대가 아직 받지 않은 보낸 글 2 · ", out)                                      # 받아 온 끝에서 다시 셌다(이 기계의 것 1 + 다른 기계의 것 1)
        self.assertEqual(CB.local_tip(self.w, ALPHA), theirs)                                       # 로컬은 받아 온 끝으로 옮겨졌다 — 다음 확인은 같은 끝을 센다
        self.assertIn("수를 센 끝: " + theirs, out)                                                  # 다시 센 끝이 새 끝 줄로 나온다
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", theirs)
        self.assertEqual(rc, 0, out)
        self.assertEqual(self.g("rev-parse", "--verify", "-q", CB.ref_of(ALPHA), repo=self.o, check=False), "")

    def test_remote_that_cannot_be_reached_keeps_the_local_branch(self):
        self.g("remote", "set-url", "origin", "file://" + str(self.t / "gone.git"))
        tip = CB.local_tip(self.w, ALPHA)
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", CB.local_tip(self.w, ALPHA) or "0" * 40)
        self.assertEqual((rc, CB.local_tip(self.w, ALPHA)), (3, tip), out)                        # 원격을 먼저 지운다 — 못 지우면 로컬도 둔다

    def test_local_commit_not_pushed_is_kept_and_not_moved(self):
        """로컬만 앞선 채(올리지 못한 커밋)로는 원격이 같다고 볼 수 없다 — 지우지 않고 로컬 끝도 옮기지 않는다."""
        import conductor_mail as CM
        self.g("remote", "set-url", "--push", "origin", "file://" + str(self.t / "gone.git"))
        CM.send(self.w, rm(ALPHA), SID, BETA, "예고", "올리지 못한 글")
        mine, remote = CB.local_tip(self.w, ALPHA), self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o)
        self.assertNotEqual(mine, remote)
        self.g("remote", "set-url", "--push", "origin", str(self.o))
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", CB.local_tip(self.w, ALPHA) or "0" * 40)
        self.assertEqual((rc, CB.local_tip(self.w, ALPHA), self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o)), (1, mine, remote), out)
        self.assertIn("올리지 못한 커밋", out)

    def test_branch_missing_on_the_remote_deletes_the_local_one_only(self):
        self.g("push", "origin", ":" + CB.ref_of(ALPHA))
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", CB.local_tip(self.w, ALPHA) or "0" * 40)
        self.assertEqual(rc, 0, out)
        self.assertIsNone(CB.local_tip(self.w, ALPHA))
        self.assertIn("원격에는 없었다", out)

    def test_a_repo_with_the_branch_switched_off_can_still_delete_what_is_left(self):  # R3 AC23
        self.put({".devbrew.md": "---\nstate_branch: 끔\n---\n"})
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", CB.local_tip(self.w, ALPHA) or "0" * 40)
        self.assertEqual(rc, 0, out)
        self.assertIsNone(CB.local_tip(self.w, ALPHA))

    def test_local_ref_is_deleted_only_if_it_still_holds_the_tip_that_was_read(self):
        """뒤집으면 붉다 — 옛 값 조건이 없으면 읽은 뒤 다른 쓰기가 옮긴 끝을 그대로 지운다."""
        moved, tip0 = CB.local_tip(self.w, BETA), CB.local_tip(self.w, ALPHA)
        real = CB._git_delete

        def racing(root, *args, **kw):
            if args[0] == "update-ref" and args[2] == CB.ref_of(ALPHA):   # 로컬 ref 를 지우기 직전에 다른 쓰기가 끝을 옮긴다
                subprocess.run(["git", "update-ref", CB.ref_of(ALPHA), moved], cwd=str(root), env=ENV, check=True)
            return real(root, *args, **kw)
        with mock.patch.object(CB, "_git_delete", racing):
            with self.assertRaises(CB.BranchError) as c:
                CB.delete(self.w, rm(ALPHA), SID, tip0)
        self.assertEqual(c.exception.rc, 3)
        self.assertEqual(CB.local_tip(self.w, ALPHA), moved)

    def test_a_remote_that_refuses_the_delete_keeps_the_local_branch(self):
        """뒤집으면 붉다 — 원격 지우기의 rc 를 안 보면 원격에 남은 브랜치를 두고 로컬만 지우고 0 으로 끝난다."""
        self.g("config", "receive.denyDeletes", "true", repo=self.o)
        tip = CB.local_tip(self.w, ALPHA)
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", CB.local_tip(self.w, ALPHA) or "0" * 40)
        self.assertEqual((rc, CB.local_tip(self.w, ALPHA)), (3, tip), out)
        self.assertEqual(self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o), tip)
        self.assertNotIn("지웠다", out)

    def test_a_remote_moved_between_the_comparison_and_the_delete_is_not_deleted(self):   # M25 ④ — 센 끝에 건 지우기(lease)
        """뒤집으면 붉다 — lease 를 떼면 견준 뒤 다른 클론이 올린 커밋째 원격 브랜치가 지워진다."""
        tip = CB.local_tip(self.w, ALPHA)
        m2 = self.clone("m2")
        self.assertEqual(self.g("rev-parse", CB.TRACKING_PREFIX + CB.branch_of(ALPHA), repo=m2), tip)
        theirs = self.g("commit-tree", tip + "^{tree}", "-p", tip, "-m", "다른 클론의 쓰기", repo=m2)
        real, pushed = CB._git_delete, []

        def interleave(root, *args, **kw):
            if args[0] == "push" and not pushed:   # 받아 와 견준 뒤 · 원격을 지우기 직전에 다른 클론이 실제로 올린다
                self.g("push", "-q", "origin", "%s:%s" % (theirs, CB.ref_of(ALPHA)), repo=m2)
                pushed.append(theirs)
            return real(root, *args, **kw)
        with mock.patch.object(CB, "_git_delete", interleave):
            with self.assertRaises(CB.BranchError) as c:
                CB.delete(self.w, rm(ALPHA), SID, tip)
        self.assertEqual((c.exception.rc, pushed), (3, [theirs]))
        self.assertEqual(self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o), theirs)              # 원격 브랜치가 남았고 다른 클론의 커밋이 끝이다
        self.assertEqual(CB.local_tip(self.w, ALPHA), tip)                                         # 로컬도 두었다

    def test_an_origin_that_cannot_be_known_stops_the_delete(self):
        tip = tip0 = CB.local_tip(self.w, ALPHA)
        with mock.patch.object(CB, "_origin_exists", return_value=None):
            with self.assertRaises(CB.BranchError) as c:
                CB.delete(self.w, rm(ALPHA), SID, tip0)
        self.assertEqual(c.exception.rc, 3)
        self.assertEqual(CB.local_tip(self.w, ALPHA), tip)
        self.assertEqual(self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o), tip)

    def test_a_local_write_that_absorbed_a_remote_commit_does_not_make_the_old_count_valid(self):
        """뒤집으면 붉다 — 확인 때의 로컬 끝과만 견주면 이 기계의 보통 쓰기가 남의 커밋을 흡수한 뒤 세지 않은 글이 지워진다(리뷰 I1)."""
        import conductor_mail as CM
        counted = CB.local_tip(self.w, ALPHA)
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID)
        self.assertIn("수를 센 끝: " + counted, out)
        m2 = self.clone("m2")
        self.claim(repo=m2)
        CB.ensure(m2, rm(ALPHA), SID)
        theirs = CM.send(m2, rm(ALPHA), SID, BETA, "예고", "수를 센 뒤 다른 기계가 보낸 글")[0].commit
        CB.write(self.w, rm(ALPHA), SID, lambda base: {CB.team_of(self.w, rm(ALPHA)).path(CB.PENDING_FILE): "- A1 · 결정 기록 · 줄 셋\n"}, "끼어든 쓰기")
        mine = CB.local_tip(self.w, ALPHA)
        self.assertEqual(self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o), mine)                   # 로컬이 남의 커밋을 흡수해 원격 끝과 같다
        self.assertNotEqual(mine, counted)
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", counted)
        self.assertEqual(rc, 1, out)
        self.assertEqual((CB.local_tip(self.w, ALPHA), self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o)), (mine, mine))   # 아무것도 지우지 않았다
        self.assertIn("상대가 아직 받지 않은 보낸 글 2 · ", out)                                      # 다시 센 수에 그 글이 들어 있다
        self.assertIn("수를 센 끝: " + mine, out)
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", mine)   # 양성 대조 — 같은 끝이면 지운다
        self.assertEqual(rc, 0, out)
        self.assertIsNone(CB.local_tip(self.w, ALPHA))
        self.assertTrue(theirs)

    def test_a_local_only_move_after_the_count_is_not_deleted_either(self):
        counted = CB.local_tip(self.w, ALPHA)
        CB.write(self.w, rm(ALPHA), SID, lambda base: {CB.team_of(self.w, rm(ALPHA)).path(CB.PENDING_FILE): "- A1 · 결정 기록 · 줄 셋\n"}, "끼어든 쓰기")
        now = CB.local_tip(self.w, ALPHA)
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", counted)
        self.assertEqual((rc, CB.local_tip(self.w, ALPHA)), (1, now), out)
        self.assertIn("수를 센 끝: " + now, out)
        self.g("push", "origin", ":" + CB.ref_of(ALPHA))                                           # 원격이 없는 경우도 로컬 끝만 견준다
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", counted)
        self.assertEqual((rc, CB.local_tip(self.w, ALPHA)), (1, now), out)
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", now)
        self.assertEqual(rc, 0, out)

    def test_the_counted_tip_may_be_given_whole_or_as_its_first_eight_and_nothing_else(self):
        tip = CB.local_tip(self.w, ALPHA)
        for bad in (tip[:7], tip[:9], tip[:39], tip + "0", tip[:8].upper(), "g" * 8, "", tip[:8] + " ", "0" * 8, "0" * 40):
            rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", bad)
            self.assertEqual((rc, CB.local_tip(self.w, ALPHA)), (2 if bad != "0" * 8 and bad != "0" * 40 else 1, tip), (bad, out))
        flip = "0" if tip[7] != "0" else "1"
        for near in (tip[:7] + flip, tip[:4] + "0" * 4 if tip[4:8] != "0" * 4 else tip[:4] + "1" * 4, tip[:39] + ("0" if tip[39] != "0" else "1")):
            rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", near)   # 앞부분만 같은 끝은 같은 끝이 아니다
            self.assertEqual((rc, CB.local_tip(self.w, ALPHA)), (1, tip), (near, out))
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", tip[:8])
        self.assertEqual(rc, 0, out)
        self.assertIsNone(CB.local_tip(self.w, ALPHA))

    def test_the_whole_forty_char_tip_confirms_and_a_confirmed_flag_without_a_tip_is_a_usage_error(self):
        tip = CB.local_tip(self.w, ALPHA)
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed")
        self.assertEqual((rc, CB.local_tip(self.w, ALPHA)), (2, tip), out)
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", tip)
        self.assertEqual(rc, 0, out)
        self.assertIsNone(CB.local_tip(self.w, ALPHA))


    def test_unpushed_rules_edits_are_counted_exactly(self):
        import conductor_status as cstat
        team = CB.team_of(self.w, rm(ALPHA))
        self.put({team.rules: "- 규칙 하나\n- 규칙 둘\n"})
        self.g("push", "origin", "trunk")
        CB.write(self.w, rm(ALPHA), SID, lambda base: {team.rules: "- 규칙 하나\n- 규칙 셋\n- 규칙 넷\n"}, "규칙")
        self.assertEqual(cstat.leftovers(self.w, rm(ALPHA))["rules"], 3)                           # 뺀 줄 1 + 더한 줄 2
        rc, out = cli(self.w, "delete", "--roadmap", rm(ALPHA), "--session", SID)
        self.assertIn("안 올린 규칙 고침 3줄", out)

    def test_leftovers_count_four_things_at_a_given_or_local_tip(self):
        import conductor_status as cstat
        want = {"unreceived": 1, "unanswered": 1, "pending": 2, "rules": 0}
        self.assertEqual(cstat.leftovers(self.w, rm(ALPHA)), want)
        self.assertEqual(cstat.leftovers(self.w, rm(ALPHA), CB.local_tip(self.w, ALPHA)), want)
        self.assertEqual(cstat.leftovers(self.w, rm(BETA))["pending"], 0)                        # 파일이 없으면 0


class DeleteGateGuards(StateRepo):
    def test_delete_forms_are_refused_unless_the_delete_mark_is_given_for_that_exact_form(self):
        ref, oid = CB.ref_of(ALPHA), "a" * 40
        lease = "--force-with-lease=%s:%s" % (ref, oid)
        for form in (("push", "--porcelain", lease, "origin", ":" + ref), ("update-ref", "-d", ref, oid)):
            with self.assertRaises(RuntimeError, msg=form):
                CB.git(self.w, *form)                                                              # 표지 없이는 지우는 꼴이 문에서 막힌다
        for form in (("push", "--porcelain", "origin", ":" + ref),                                                     # lease 없는 옛 꼴(I8)
                     ("push", "--porcelain", "--force-with-lease=%s:%s" % (CB.ref_of(BETA), oid), "origin", ":" + ref),   # lease 의 ref 와 지우는 ref 가 다르다
                     ("push", "--porcelain", "--force-with-lease=refs/heads/trunk:%s" % oid, "origin", ":refs/heads/trunk"),
                     ("push", "--porcelain", "--force-with-lease=%s:%s" % (ref, oid[:8]), "origin", ":" + ref),    # 끝은 40자 전체만
                     ("push", "--porcelain", "--force-with-lease=%s:%s" % (ref, oid + "\n"), "origin", ":" + ref),
                     ("push", "--porcelain", "--force-with-lease=%s" % ref, "origin", ":" + ref), ("push", "--porcelain", "--force-with-lease", "origin", ":" + ref),
                     ("push", "--porcelain", "origin", lease, ":" + ref), ("push", lease, "--porcelain", "origin", ":" + ref),
                     ("push", "--porcelain", lease, "--force", "origin", ":" + ref), ("push", "--porcelain", lease, "origin", ":" + ref, ":" + CB.ref_of(BETA)),
                     ("push", "--porcelain", lease, "origin", "+" + ref + ":" + ref), ("push", "--porcelain", lease, "origin", ref + ":" + ref),
                     ("push", "--porcelain", "origin", ":refs/heads/trunk"), ("push", "--porcelain", "origin", ":refs/heads/feature/a1"),
                     ("push", "--force", "origin", ":" + ref), ("push", "--delete", "origin", ref), ("push", "--porcelain", "origin", "+" + ref + ":" + ref),
                     ("push", "--porcelain", "origin", ":" + ref, ":" + CB.ref_of(BETA)), ("push", "--porcelain", "origin", ref + ":" + ref),
                     ("update-ref", "-d", "refs/heads/trunk", oid), ("update-ref", "-d", ref), ("update-ref", "-d", ref, "main"),
                     ("update-ref", "--no-deref", "-d", ref, oid), ("fetch", "--quiet", "origin", "+%s:refs/remotes/origin/x" % ref),
                     ("ls-remote", "origin", ref), ("rev-parse", "HEAD"),
                     ("push", "--porcelain", "origin", ":" + ref + "*"), ("push", "--porcelain", "origin", ":" + ref + "/x"), ("push", "--porcelain", "origin", ":" + ref + "\n"),
                     ("push", "--porcelain", "origin", ":refs/heads/conductor/*"), ("push", "--porcelain", "origin", ":refs/heads/conductor/../trunk"),
                     ("update-ref", "-d", ref + "/x", oid), ("update-ref", "-d", "refs/heads/conductor/*", oid), ("update-ref", "-d", ref, oid + "0"),
                     ("update-ref", "-d", ref, oid + "\n")):
            with self.assertRaises(RuntimeError, msg=form):
                CB.git(self.w, *form, delete=True)                                                 # 표지가 있어도 그 두 꼴 밖은 막힌다
        self.assertEqual(CB.git(self.w, "update-ref", "-d", "refs/remotes/origin/conductor/" + ALPHA, oid, delete=True)[0] in (0, 1), True)   # 양성 대조 — 문을 지난다(없는 ref 라 git 이 거절해도 RuntimeError 는 아니다)
        self.assertIn(CB.git(self.w, "push", "--porcelain", lease, "origin", ":" + ref, delete=True)[0], (0, 1))   # 양성 대조 — lease 꼴은 문을 지난다(원격에 없는 ref 라 git 이 거절한다)


class DeleteBoundary(unittest.TestCase):
    SRC = (SCRIPTS / "conductor_branch.py").read_text(encoding="utf-8")

    def test_only_the_delete_function_passes_the_delete_mark(self):
        body = self.SRC.split("def delete(", 1)[1].split("# ── 명령줄", 1)[0]
        outside = self.SRC.replace(body, "")
        self.assertEqual(re.findall(r"delete=True\)", outside), ["delete=True)"], "표지를 넘기는 호출은 _git_delete 하나뿐이다")
        self.assertEqual(len(re.findall(r"_git_delete\(root", body)), 3)
        self.assertNotIn("delete=True", body)
        self.assertRegex(body, r'"update-ref", "-d", ref, tip')                                   # 로컬 ref 는 읽었던 끝을 옛 값으로 걸어 지운다

    def test_remote_is_deleted_before_local_and_confirmation_gates_everything(self):
        body = self.SRC.split("def delete(", 1)[1].split("# ── 명령줄", 1)[0]
        self.assertLess(body.index("confirmed is None"), body.index('"ls-remote"'))                      # 확인 없이 원격을 보지도 않는다
        self.assertLess(body.index('"push", "--porcelain", "--force-with-lease=%s:%s" % (ref, tip), "origin", ":" + ref'), body.index('"update-ref", "-d", ref, tip'))
        self.assertNotIn("availability(", body)
        self.assertIn("import conductor_status", body)
        self.assertNotRegex(self.SRC.split("def delete(", 1)[0], r"(?m)^import conductor_status|^from conductor_status")


class OwnCommits(StateRepo):   # R3 AC21 · Review Focus 1 · B3
    def own(self):
        return [r["끝"] for r in cs.load(cs.machine_path(state_root(str(self.w)), rm(ALPHA)), rm(ALPHA))[cs.TRUST]
                if r["까닭"] == "씀"]

    def other_writes(self, files):
        """둘째 클론이 같은 상태 브랜치에 써 올린다 — 그 커밋을 돌려준다."""
        other = self.clone("other%d" % len(list(self.t.iterdir())))
        self.claim(repo=other, session=OTHER)
        team = CB.team_of(str(other), rm(ALPHA))
        CB._fetch(str(other), team.name)
        self.g("update-ref", CB.ref_of(team.name), "refs/remotes/origin/" + CB.branch_of(team.name), repo=other)
        return CB.write(str(other), rm(ALPHA), OTHER, lambda b: files, "남").commit

    def test_every_made_commit_is_recorded(self):
        self.claim()
        made = CB.ensure(str(self.w), rm(ALPHA), SID)
        team = CB.team_of(str(self.w), rm(ALPHA))
        res = CB.write(str(self.w), rm(ALPHA), SID, lambda b: {team.status: "x\n"}, "STATUS")
        self.assertEqual(self.own(), [made.commit, res.commit])
        self.assertEqual(res.made, (res.commit,))

    def test_remade_on_foreign_tip_records_only_mine(self):   # 남의 커밋은 「씀」 이 아니다
        self.claim()
        CB.ensure(str(self.w), rm(ALPHA), SID)
        team = CB.team_of(str(self.w), rm(ALPHA))
        theirs = self.other_writes({team.rules: "- [남] 남의 줄\n"})
        mine = CB.write(str(self.w), rm(ALPHA), SID, lambda b: {team.status: "y\n"}, "STATUS")   # 거절 → 받아 와 다시 만든다
        self.assertEqual(mine.onto, theirs)
        self.assertNotIn(theirs, self.own())
        self.assertIn(mine.commit, self.own())

    def test_unchanged_remake_moves_ref_to_foreign_tip_without_recording_it(self):   # B3 — made 가 None 인 갈래
        self.claim()
        CB.ensure(str(self.w), rm(ALPHA), SID)
        team = CB.team_of(str(self.w), rm(ALPHA))
        theirs = self.other_writes({team.status: "같은 글\n"})
        res = CB.write(str(self.w), rm(ALPHA), SID, lambda b: {team.status: "같은 글\n"}, "STATUS")   # 원격 끝에서는 바뀐 것이 없다
        self.assertEqual(CB.local_tip(str(self.w), team.name), theirs)   # ref 는 남의 끝으로 옮겨 갔다
        self.assertNotIn(theirs, self.own())                             # 그래도 「씀」 이 아니다
        self.assertNotIn(theirs, res.made)

    def test_creating_race_does_not_record_the_adopted_root(self):   # B3 — ensure 가 만드는 사이 남이 먼저 올렸다
        other = self.clone("first")
        self.claim(repo=other, session=OTHER)
        their_root = CB.ensure(str(other), rm(ALPHA), OTHER).commit
        self.claim()
        real = CB.git   # 바꿔 끼우기 전에 잡는다 — 안에서 잡으면 자기 자신을 부른다

        def fake(root, *a, **k):   # ls-remote 가 「없다」(2)고 답한 것처럼 — 만드는 쪽으로 보낸다
            return (2, "", "") if a[:1] == ("ls-remote",) else real(root, *a, **k)
        with mock.patch.object(CB, "git", side_effect=fake):
            CB.ensure(str(self.w), rm(ALPHA), SID)
        self.assertNotIn(their_root, self.own())


class OldRepoSettingsNotDroppedSilently(StateRepo):   # 과제 2 리뷰 — 「씀」 기록이 옛 `## 레포 설정` 절을 지우면 원장 쓰기와 같은 알림을 낸다
    def plant(self):
        path = cs.machine_path(state_root(str(self.w)), rm(ALPHA))
        text = cs.render_machine(rm(ALPHA), cs.load(path, rm(ALPHA))) + "\n## 레포 설정\n\n- test_command · make test\n"
        path.write_text(text, encoding="utf-8")
        self.assertTrue(cs.has_old_repo_settings(path))
        return path

    def test_recording_own_commits_surfaces_the_dropped_notice(self):
        self.claim()
        path = self.plant()
        made = CB.ensure(str(self.w), rm(ALPHA), SID)                            # 만들기 길
        self.assertIn(cs.OLD_REPO_SETTINGS_DROPPED, made.notes)
        self.assertFalse(cs.has_old_repo_settings(path))                         # 실제로 지워졌다 — 알림은 그 사실이다
        team = CB.team_of(str(self.w), rm(ALPHA))
        self.assertNotIn(cs.OLD_REPO_SETTINGS_DROPPED,
                         CB.write(str(self.w), rm(ALPHA), SID, lambda b: {team.status: "x\n"}, "STATUS").notes)   # 양성 대조 — 옛 절이 없으면 알리지 않는다
        self.plant()
        res = CB.write(str(self.w), rm(ALPHA), SID, lambda b: {team.status: "y\n"}, "STATUS")   # 쓰기 길
        self.assertIn(cs.OLD_REPO_SETTINGS_DROPPED, res.notes)
        own = [r["끝"] for r in cs.load(path, rm(ALPHA))[cs.TRUST] if r["까닭"] == "씀"]
        self.assertIn(made.commit, own)                                          # 기록은 건너뛰지 않는다
        self.assertIn(res.commit, own)


class SettingsErrorIsZero(StateRepo):   # M25 ② · F14 — 설정 오류면 쓰는 명령이 3 이 아니라 알리고 0 · 표지가 먼저다
    def run_cli(self, script, *args):
        p = subprocess.run([sys.executable, str(SCRIPTS / script), "--root", str(self.w), *args],
                           cwd=str(self.w), env=ENV, capture_output=True, encoding="utf-8")
        return p.returncode, p.stdout + p.stderr

    def commands(self, session):
        common = ("--roadmap", rm(ALPHA), "--session", session)
        return (("conductor_branch.py", ("ensure",) + common), ("conductor_status.py", ("sync",) + common),
                ("conductor_mail.py", ("send",) + common + ("--to", BETA, "--kind", "예고", "--body", "글")),
                ("conductor_mail.py", ("ack",) + common + ("--letter", BETA + "/2026-11-19-01.md")),
                ("conductor_branch.py", ("rules-add",) + common + ("--line", "- 규칙 하나")),
                ("conductor_branch.py", ("confirm",) + common))

    def test_writing_commands_tell_and_end_with_zero_on_a_broken_setting(self):
        """뒤집으면 붉다 — team_of 를 availability 앞으로 되돌리면 로드맵 폴더를 정하다 설정 오류로 3 이 된다."""
        self.claim()
        CB.ensure(self.w, rm(ALPHA), SID)
        machine = cs.machine_path(state_root(str(self.w)), rm(ALPHA))
        self.assertTrue(machine.is_file())
        self.put({".devbrew.md": "---\nno_such_key: 1\n---\n"})
        for script, args in self.commands(SID):
            refs, state = self.refs(), machine.read_bytes()
            rc, out = self.run_cli(script, *args)
            self.assertEqual((rc, self.refs(), machine.read_bytes() == state), (0, refs, True), (args[0], out))
            self.assertIn(CB.SETTINGS_UNREADABLE, out, args[0])
            self.assertTrue(out.strip().splitlines()[-1].startswith("[spec-distill] " + CB.SETTINGS_UNREADABLE), (args[0], out))   # 마지막 줄이 알림이다
        refs = self.refs()
        rc, out = self.run_cli("conductor_status.py", "waiting", "add", "--roadmap", rm(ALPHA), "--session", SID,
                               "--epic", "A1", "--kind", "머지", "--via", "턴 끝")
        self.assertEqual((rc, self.refs()), (0, refs), out)
        self.assertIn(CB.SETTINGS_UNREADABLE, out)
        self.assertEqual([(r["에픽"], r["종류"]) for r in cs.load(machine, rm(ALPHA))[cs.ASKING]], [("A1", "머지")])   # 줄은 기계 상태에 쌓인다(AC6)

    def test_the_write_floor_itself_tells_before_reading_the_roadmap_folder(self):   # 바닥을 바로 부르는 쓰기도 같은 차례다
        """뒤집으면 붉다 — 바닥에서 team_of 를 availability 앞으로 되돌리면 BranchError(3) 이 난다(부르는 쪽 검사에 기대지 않는다)."""
        self.claim()
        CB.ensure(self.w, rm(ALPHA), SID)
        self.put({".devbrew.md": "---\nno_such_key: 1\n---\n"})
        refs, team = self.refs(), CB.team_layout.Team("docs/superpowers/roadmaps", ALPHA)
        res = CB.write(self.w, rm(ALPHA), SID, lambda base: {team.status: "x\n"}, "쓰기")
        self.assertEqual((res.commit, self.refs()), (None, refs))
        self.assertTrue(res.notes[0].startswith(CB.SETTINGS_UNREADABLE), res.notes)
        with self.assertRaises(CB.BranchError) as c:
            CB.write(self.w, rm(ALPHA), OTHER, lambda base: {team.status: "x\n"}, "쓰기")
        self.assertEqual((c.exception.rc, self.refs()), (5, refs))

    def test_a_session_without_the_marker_still_gets_five_on_a_broken_setting(self):
        """뒤집으면 붉다 — 표지보다 설정을 먼저 보면 표지 없는 세션이 0(알림)이나 3 으로 끝난다."""
        self.claim()
        CB.ensure(self.w, rm(ALPHA), SID)
        self.put({".devbrew.md": "---\nno_such_key: 1\n---\n"})
        refs = self.refs()
        for script, args in self.commands(OTHER) + (("conductor_status.py", ("waiting", "add", "--roadmap", rm(ALPHA), "--session", OTHER,
                                                                             "--epic", "A1", "--kind", "머지", "--via", "턴 끝")),):
            rc, out = self.run_cli(script, *args)
            self.assertEqual((rc, self.refs()), (5, refs), (args[0], out))


class HandMadeMerge(StateRepo):   # M25 ④ — 다시 얹을 커밋에 부모 둘 이상인 것이 있으면 다시 얹지 않는다
    def test_a_rejected_write_over_a_hand_made_merge_commit_stops_with_three(self):
        """뒤집으면 붉다 — 검사를 지우면 머지 커밋을 첫 부모에 견줘 다시 얹고 올려 끝난다(원격이 바뀐다)."""
        self.claim()
        CB.ensure(self.w, rm(ALPHA), SID)
        team = CB.team_of(self.w, rm(ALPHA))
        tip = CB.local_tip(self.w, ALPHA)
        side = self.g("commit-tree", tip + "^{tree}", "-p", tip, "-m", "곁")
        merge = self.g("commit-tree", tip + "^{tree}", "-p", tip, "-p", side, "-m", "손으로 만든 머지")
        self.g("update-ref", CB.ref_of(ALPHA), merge, tip)
        m2 = self.clone("m2")
        theirs = self.g("commit-tree", tip + "^{tree}", "-p", tip, "-m", "다른 클론의 쓰기", repo=m2)
        self.g("push", "-q", "origin", "%s:%s" % (theirs, CB.ref_of(ALPHA)), repo=m2)            # 이 기계의 올리기가 거절된다
        with self.assertRaises(CB.BranchError) as c:
            CB.write(self.w, rm(ALPHA), SID, lambda base: {team.status: "x\n"}, "쓰기")
        self.assertEqual(c.exception.rc, 3)
        self.assertIn("손으로 만든 머지 커밋이 있다 — 상태 브랜치는 스크립트만 쓴다: " + merge[:8], str(c.exception))
        self.assertEqual(self.g("rev-parse", CB.ref_of(ALPHA), repo=self.o), theirs)              # 원격 그대로

    def test_a_single_parent_chain_is_still_replayed(self):   # 양성 대조 — 같은 거절이 부모 하나인 커밋 위에서는 다시 얹혀 올라간다
        self.claim()
        CB.ensure(self.w, rm(ALPHA), SID)
        team = CB.team_of(self.w, rm(ALPHA))
        tip = CB.local_tip(self.w, ALPHA)
        side = self.g("commit-tree", tip + "^{tree}", "-p", tip, "-m", "곁")
        self.g("update-ref", CB.ref_of(ALPHA), side, tip)
        m2 = self.clone("m2")
        theirs = self.g("commit-tree", tip + "^{tree}", "-p", tip, "-m", "다른 클론의 쓰기", repo=m2)
        self.g("push", "-q", "origin", "%s:%s" % (theirs, CB.ref_of(ALPHA)), repo=m2)
        res = CB.write(self.w, rm(ALPHA), SID, lambda base: {team.status: "x\n"}, "쓰기")
        self.assertEqual((res.pushed, res.onto), (True, theirs))


class PathShape(unittest.TestCase):   # M26 · S4 — 경계 바로 뒤의 `/` · `~/` 로 시작하는 낱말만 절대경로다
    def test_boundaries_and_components(self):
        for tok in ("/a/b", "(/a/b)", "[/a/b]", "{/a/b}", "\u300c/a/b\u300d", "'/a/b'", '"/a/b"', "`/a/b`", "x:/a/b", "k=/a/b", "a,/a/b",
                    "x /a/b", "x\t/a/b", "~/k", "(~/k/l)", "key=~/k", "/나의/폴더", "~/나의", "/Users/x/y"):
            self.assertTrue(CB.looks_absolute(tok), tok)
        for tok in ("/a", "/a/", "~/", "~k/l", "a/b/c", "리더/담당자/일꾼", "설계/계획/구현", "./a/b", "x/a/b", "x~/k", "1/2/3", "", "//a", "-/a/b", "./~/k"):
            self.assertFalse(CB.looks_absolute(tok), tok)

    def test_redact_cuts_from_where_the_path_starts(self):
        self.assertEqual(CB.redact("fatal: key=/p/q 리더/담당자/일꾼 (/나의/폴더)"), "fatal: key=<경로> 리더/담당자/일꾼 (<경로>")


class DoneStages(unittest.TestCase):   # M27 — 글자로 복제한 목록이 상태 계산의 것과 같다
    def test_done_stages_are_the_status_computations_done(self):
        import roadmap_status as RS
        self.assertEqual(CB.DONE_STAGES, RS.DONE)


class CommandLineIdentity(StateRepo):   # B2 — 함수 안에서 가져온 모듈이 던진 BranchError 도 그 종료 코드로 끝난다
    def test_branch_error_raised_from_a_late_import_keeps_its_code(self):
        p = subprocess.run([sys.executable, str(SCRIPTS / "conductor_branch.py"), "--root", str(self.w),
                            "ensure", "--roadmap", rm(ALPHA), "--session", SID], capture_output=True, encoding="utf-8")
        self.assertEqual(p.returncode, 5)   # 표지 없음 — 지금도 5(양성 대조: 같은 모듈 안의 오류)
        src = (SCRIPTS / "conductor_branch.py").read_text(encoding="utf-8")
        self.assertIn('if __name__ == "__main__":\n    import conductor_branch as _self\n    sys.exit(_self.main())', src)
