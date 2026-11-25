#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_sync.py — 걸음 1 의 맞추기를 명령 하나로 돈다(설계 §2 · AC10 · AC11 · AC12).

픽스처: 버릴 레포 하나(origin 은 git@github.com:me/r.git — 가짜 ssh 가 로컬 bare 레포로 잇는다) · PATH 앞의 가짜 gh · hc.
명령은 실제 하위 프로세스로 부른다 — 이 레포의 스크립트는 가짜로 바꾸지 않는다.

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_conductor_sync.py
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PLUGIN = Path(__file__).resolve().parent.parent
SCRIPTS = PLUGIN / "scripts"
SYNC = SCRIPTS / "conductor_sync.py"
FX = PLUGIN / "tests" / "fixtures" / "conductor-e2e"   # 버릴 brief(C1 · S1 · OQ1)
sys.path.insert(0, str(SCRIPTS))
import conductor_state as cs  # noqa: E402

SID, OTHER = "session-sync0001", "session-sync0002"
RD = "docs/superpowers/roadmaps/"
RM = RD + "rm/roadmap.md"
TM = RD + "tm/roadmap.md"
ME = "t9a"
SEGMENTS = ("자리", "원격 받기", "작업 목록", "표지", "기본 브랜치", "PR 캐시", "상태 브랜치", "세션 담당자", "스위트 잠금",
            "실행 원장", "주인 모를 worktree", "판 차이")
FIRST_ONLY = ("주인 모를 worktree", "판 차이")
ROLE_DOC = "리더 역할 문서의 고유 글 7f3a"   # 리더 묶음 본문에만 있는 줄
TIME_LINE = re.compile(r"맞추기 — [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} 기준")

GH = """#!/bin/sh
[ -z "${FAKE_GH_LOG:-}" ] || printf '%s\\n' "$*" >> "$FAKE_GH_LOG"
case "$1 $2" in
  "pr list") case " $* " in
               *" --head feature/e1 "*) cat "${FAKE_GH_E1:-/dev/null}" 2>/dev/null | grep . || echo '[]' ;;
               *) echo '[]' ;;
             esac ;;
  *) echo "fake gh: $*" >&2; exit 1 ;;
esac
"""
HC = """#!/bin/sh
[ -z "${FAKE_HC_LOG:-}" ] || printf '%s\\n' "$*" >> "$FAKE_HC_LOG"
cat "$FAKE_HC_JSON"
"""
SSH = """#!/bin/sh
c=""
for a in "$@"; do c="$a"; done
cd "$FAKE_REMOTES" && eval "exec git ${c#git-}"
"""


def block(eid, title, deps="없음", branch=None):
    return ("### %s — %s\n- 의도: %s\n- 범위:\n  - 한다: x\n  - 안 한다: y\n- 의존: %s\n- 브랜치: %s\n- 묶음: %s.md\n"
            "- 경로 예약: 없음\n\n" % (eid, title, title, deps, branch or "feature/" + eid.lower(), eid))


def roadmap_text(blocks, team=False):
    head = "---\ntype: roadmap\n%ssource_brief: docs/b.md\n---\n\n# 버릴 로드맵\n\n## 에픽\n\n" % ("layout: team\n" if team else "")
    return head + blocks + "## 결정 기록\n\n## 재분해 이력\n\n- 없음\n\n## 위험 번호표\n\n- K1 — 위험 — 숨은 가정: 버릴 가정 — 근거 없음\n"


def bundle(eid, roadmap, ids):
    return ("---\ntype: epic-bundle\nepic: %s\nroadmap: %s\nsource_brief: docs/b.md\nids: [%s]\n---\n\n# %s\n"
            % (eid, roadmap, ids, eid))


class SyncRepo(unittest.TestCase):
    """버릴 레포 하나를 클래스마다 한 번 세운다. 케이스가 바꾼 표지 · 기계 상태는 그 케이스가 되돌린다."""

    @classmethod
    def setUpClass(cls):
        cls.t = Path(os.path.realpath(tempfile.mkdtemp(prefix="sync-")))
        t = cls.t
        cls.bin, cls.bin_nohc = t / "bin", t / "bin-nohc"   # 둘째는 hc 가 없는 PATH
        for d, names in ((cls.bin, ("gh", "hc", "fakessh")), (cls.bin_nohc, ("gh",))):
            d.mkdir()
            for name in names:
                p = d / name
                p.write_text({"gh": GH, "hc": HC, "fakessh": SSH}[name], encoding="utf-8")
                p.chmod(0o755)
        cls.hc_json = t / "hc.json"
        cls.hc_json.write_text(json.dumps({"terminals": []}), encoding="utf-8")
        remote = t / "remotes" / "me" / "r.git"
        remote.parent.mkdir(parents=True)
        cls.env = {k: v for k, v in os.environ.items()
                   if k not in ("CLAUDE_CODE_SESSION_ID", "HC_TERMINAL_ID", "GH_REPO", "GH_HOST", "DEVBREW_SKIP_HOOKS",
                                "DEVBREW_SPEC_DISTILL_DISABLE", "CLAUDE_PLUGIN_ROOT")}
        cls.env.update(PATH="%s:/usr/bin:/bin" % cls.bin, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1",
                       GIT_SSH_COMMAND=str(cls.bin / "fakessh"), GIT_SSH_VARIANT="simple", FAKE_REMOTES=str(t / "remotes"),
                       FAKE_HC_JSON=str(cls.hc_json), DEVBREW_SPEC_DISTILL_SESSION_ID=SID, PYTHONDONTWRITEBYTECODE="1",
                       GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@example.invalid", GIT_COMMITTER_NAME="t",
                       GIT_COMMITTER_EMAIL="t@example.invalid")
        cls.git(t, "init", "-q", "--bare", "-b", "trunk", str(remote))
        cls.w = t / "w"
        cls.git(t, "clone", "-q", "git@github.com:me/r.git", str(cls.w))
        cls.git(cls.w, "symbolic-ref", "HEAD", "refs/heads/trunk")
        files = {
            "docs/b.md": (FX / "b.md").read_text(encoding="utf-8"), "docs/b.audit.md": (FX / "b.audit.md").read_text(encoding="utf-8"),
            RM: roadmap_text(block("E1", "가") + block("E2", "나", deps="E1") + block("E3", "다")),
            RD + "rm/E1.md": bundle("E1", RM, "C1"), RD + "rm/E2.md": bundle("E2", RM, "S1"),
            RD + "rm/E3.md": bundle("E3", RM, "OQ1, K1, «e2e-k»"),
            TM: roadmap_text(block("T1", "팀 일").replace("- 묶음: T1.md", "- 묶음: jobs/T1/sources.md"), team=True),
            RD + "tm/jobs/T1/sources.md": ("---\ntype: job-sources\njob: T1\nsource_brief: docs/b.md\n"
                                          "ids: [C1, S1, OQ1, K1, «e2e-k»]\n---\n\n# T1\n"),
            RD + "leader/CLAUDE.md": "# 리더\n\n" + ROLE_DOC + "\n",
        }
        cls.put(files)
        cls.git(cls.w, "add", "-A")
        cls.git(cls.w, "commit", "-qm", "base")
        cls.git(cls.w, "push", "-q", "origin", "trunk")
        cls.git(cls.w, "remote", "set-head", "origin", "--auto")
        # E3 — 기능 브랜치를 기본 브랜치에 머지해 단계를 「머지됨」 으로
        cls.git(cls.w, "switch", "-q", "-c", "feature/e3")
        cls.put({"src/e3.txt": "e3\n"})
        cls.git(cls.w, "add", "-A")
        cls.git(cls.w, "commit", "-qm", "e3")
        cls.git(cls.w, "push", "-q", "origin", "feature/e3")
        cls.git(cls.w, "switch", "-q", "trunk")
        cls.git(cls.w, "merge", "-q", "--no-ff", "feature/e3", "-m", "Merge pull request #3 from me/feature/e3")
        cls.git(cls.w, "push", "-q", "origin", "trunk")
        cls.git(cls.w, "fetch", "-q", "origin")

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(str(cls.t), ignore_errors=True)

    @classmethod
    def git(cls, cwd, *args):
        return subprocess.run(["git", *args], cwd=str(cwd), env=cls.env, capture_output=True, encoding="utf-8",
                              check=True).stdout

    @classmethod
    def put(cls, files):
        for rel, text in files.items():
            p = cls.w / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(text, encoding="utf-8")

    def setUp(self):
        self.addCleanup(self.forget)

    def forget(self):
        """케이스가 잡은 표지를 푼다 — 다음 케이스가 「처음」 을 다시 본다."""
        for road in (RM, TM):
            for sid in (SID, OTHER):
                self.ledger("release", "--roadmap", road, "--session", sid)

    def run_py(self, script, *args, env=None):
        p = subprocess.run([sys.executable, str(script), *args], cwd=str(self.w), env=env or self.env,
                           capture_output=True, encoding="utf-8")
        return p.returncode, p.stdout, p.stderr

    def ledger(self, *args):
        rc, out, err = self.run_py(SCRIPTS / "conductor_ledger.py", *args)
        return rc, out + err

    def sync(self, *args, env=None, script=SYNC):
        rc, out, err = self.run_py(script, "--roadmap", RM, *args, env=env)
        return rc, out, err

    def machine(self, road=RM):
        return cs.load(cs.machine_path(self.w / ".claude" / "spec-distill", road), road)


def heads(out):
    """구간 줄의 이름(「<이름> — 」 앞) 차례 — 들여 쓴 원문 줄은 빼고."""
    names = []
    for line in out.splitlines():
        if line.startswith(" ") or " — " not in line:
            continue
        names.append(line.split(" — ", 1)[0])
    return names


def without_time(out):
    return "\n".join(l for l in out.splitlines() if not TIME_LINE.fullmatch(l))


class Segments(SyncRepo):
    def test_segments_in_order(self):
        rc, out, err = self.sync()
        self.assertEqual(rc, 0, out + err)
        got = [h for h in heads(out) if h in SEGMENTS]
        self.assertEqual(got, list(SEGMENTS), out)
        self.assertIn("\n규모 — ", out)
        self.assertIn("\n끝나지 않은 일:", out)
        last = out.rstrip("\n").split("\n")[-1]
        self.assertTrue(last.startswith("맞추기 — ") and last.endswith(" 기준"), last)
        self.assertTrue(TIME_LINE.fullmatch(last), last)


class Repeat(SyncRepo):
    def test_first_only_segments(self):
        self.sync()
        rc, out, err = self.sync()
        self.assertEqual(rc, 0, out + err)
        self.assertIn("\n표지 — 이 세션이 쥐고 있다\n", out)
        for name in FIRST_ONLY:
            self.assertNotIn(name, heads(out), out)
        self.assertEqual([h for h in heads(out) if h in SEGMENTS], [h for h in SEGMENTS if h not in FIRST_ONLY])

    def test_same_state_same_output(self):   # AC11
        self.sync()
        second, third = self.sync()[1], self.sync()[1]
        self.assertTrue(TIME_LINE.fullmatch(second.rstrip("\n").split("\n")[-1]), second)
        self.assertEqual(without_time(second), without_time(third))


class Stops(SyncRepo):
    def marker(self, road=RM):
        return cs.machine_dir(self.w / ".claude" / "spec-distill", road) / cs.MARKER

    def test_stop_other_session_holds(self):   # AC10
        self.assertEqual(self.ledger("claim", "--roadmap", RM, "--session", OTHER)[0], 0)
        rc, out, err = self.sync()
        self.assertEqual(rc, 5, out + err)
        self.assertIn("\n멈춤 — 표지: 다른 세션(%s)" % OTHER, out)
        self.assertNotIn("기본 브랜치", heads(out))   # 뒤 구간은 돌지 않는다
        self.assertFalse(TIME_LINE.search(out), out)
        rc, out, err = self.sync("--takeover")
        self.assertEqual(rc, 0, out + err)
        self.assertIn("\n표지 — 넘겨받았다(이전 주인 %s)\n" % OTHER, out)
        self.assertIn("기본 브랜치", heads(out))   # 양성 짝 — 멈추지 않으면 그 줄이 있다
        for name in FIRST_ONLY:
            self.assertIn(name, heads(out), out)

    def test_stop_no_session(self):   # AC12
        env = {k: v for k, v in self.env.items() if k not in ("DEVBREW_SPEC_DISTILL_SESSION_ID", "CLAUDE_CODE_SESSION_ID")}
        self.assertFalse(self.marker().exists())
        rc, out, err = self.sync(env=env)
        self.assertEqual(rc, 3, out + err)
        self.assertIn("작업 목록", heads(out))
        self.assertIn("\n멈춤 — 표지: 세션 번호를 얻지 못했다", out)
        self.assertNotIn("session_id", out + err)   # 해결자의 영어 줄은 이 명령의 꼴이 아니다
        self.assertFalse(self.marker().exists())   # 표지 파일이 생기지 않았다
        self.assertEqual(self.sync()[0], 0)
        self.assertTrue(self.marker().exists())   # 양성 짝 — 세션 번호가 있으면 표지가 생긴다

    def keep_machine(self):
        path = cs.machine_path(self.w / ".claude" / "spec-distill", RM)
        before = path.read_text(encoding="utf-8") if path.exists() else None
        self.addCleanup(lambda: path.write_text(before, encoding="utf-8") if before is not None else path.unlink())
        return path, before

    def test_stop_unreadable_state(self):
        self.sync()
        self.forget()
        path, _before = self.keep_machine()
        path.write_text("깨진 기계 상태\n", encoding="utf-8")
        rc, out, err = self.sync()
        self.assertEqual(rc, 3, out + err)
        self.assertIn("\n멈춤 — 표지: ", out)
        self.assertTrue(any(l.startswith("    [spec-distill] ") for l in out.splitlines()), out)   # 원문을 들여 낸다
        self.assertNotIn("기본 브랜치", heads(out))

    def test_stop_old_pr_rows_carries_reset(self):   # 옛 판의 PR 캐시 줄 — 원문에 --reset 명령이 실린다
        self.sync()
        self.forget()
        path, before = self.keep_machine()
        self.assertIn("\n## PR\n", before)
        path.write_text(before.replace("\n## PR\n", "\n## PR\n\n- feature/e1 · #1 · 열림 · 2026-10-18 10:00\n", 1), encoding="utf-8")
        rc, out, err = self.sync()
        self.assertEqual(rc, 3, out + err)
        self.assertIn("\n멈춤 — 표지: ", out)
        self.assertTrue(any(l.startswith("    ") and "--reset" in l for l in out.splitlines()), out)


class PrCache(SyncRepo):
    def test_cache_change_is_shown(self):   # 고침 알림 — 캐시가 바뀐 줄을 낸다, 다음 번은 달라진 것 없음
        e1 = self.t / "gh-e1.json"
        e1.write_text(json.dumps([{"number": 5, "state": "OPEN", "headRefName": "feature/e1", "headRefOid": "a" * 40,
                                   "isCrossRepository": False, "baseRefName": "trunk", "mergeCommit": None}]), encoding="utf-8")
        self.addCleanup(e1.unlink)
        env = dict(self.env, FAKE_GH_E1=str(e1))
        rc, out, err = self.sync(env=env)
        self.assertEqual(rc, 0, out + err)
        self.assertIn("\nPR 캐시 — 이상: 고쳤다 — feature/e1 #5 없음 → 열림\n", out)
        self.assertIn("\n    PR 캐시: 브랜치 ", out)   # pr-refresh 원문을 들여 낸다
        rc, out, err = self.sync(env=env)
        self.assertIn("\nPR 캐시 — 달라진 것 없음\n", out)
        rc, out, err = self.sync()   # 그 PR 이 목록에서 사라지면 다시 고침
        self.assertIn("\nPR 캐시 — 이상: 고쳤다 — feature/e1 #5 열림 → 없음\n", out)


class StatusView(SyncRepo):
    def test_status_line_outside_benign_is_shown(self):   # Review Focus 2
        self.sync()
        rc, _o, err = self.run_py(SCRIPTS / "conductor_status.py", "waiting", "add", "--roadmap", RM, "--session", SID,
                                  "--epic", "E1", "--kind", "spec 승인", "--via", cs.ASK_VIA[1])
        self.assertEqual(rc, 0, err)
        self.addCleanup(self.run_py, SCRIPTS / "conductor_status.py", "waiting", "clear", "--roadmap", RM, "--session", SID,
                        "--epic", "E1")
        rc, out, err = self.sync()
        self.assertEqual(rc, 0, out + err)
        self.assertIn("\n상태 브랜치 — 이상: 기다리는 질문 1 · 온 글 0\n", out)
        shown = [l for l in out.splitlines() if l.startswith("    - 이 로드맵 · E1 · spec 승인 · ")]   # 현황 화면의 그 질문 줄 그대로
        self.assertEqual(len(shown), 1, out)
        self.assertTrue(shown[0].endswith("부터"), shown[0])

    def test_unknown_view_lines_are_kept(self):   # 목록에 없는 줄을 버리는 갈래가 없다 — 어느 자리의 모르는 줄도 이상
        import conductor_status as CS
        import conductor_sync as SY
        sections = dict((name, [CS.NONE_LINE]) for name in CS.STATUS_SECTIONS)
        sections[CS.STATUS_SECTIONS[-1]] = ["0줄"]
        head = CS.render_status(CS.Status("r", RM, "2026-11-25 09:00 +0900", "0123abcd", "session-", sections)).split("\n")
        tail = ["다른 로드맵과 닿는 것 (계산 09:00)", "- 닿는 것 없음", "사용자를 기다리는 질문 (오래된 순)", "- 없음",
                "온 글 0 · 아직 받지 않은 보낸 글 0 · 답 기다리는 글 0"]
        self.assertEqual(SY.read_view(head + tail), (0, 0, 0, []))   # 양성 짝 — 아는 꼴만이면 이상이 없다
        for at in range(len(tail) + 1):
            lines = head + tail[:at] + ["처음 보는 줄 %d" % at] + tail[at:]
            self.assertIn("처음 보는 줄 %d" % at, SY.read_view(lines)[3], at)
        got = SY.read_view(head + tail[:2] + ["- 예약 겹침: a — b"] + tail[2:])
        self.assertEqual((got[2], got[3]), (1, []))   # 정보 줄은 개수로 센다
        rules = head[:-2] + ["- 3줄", ""]
        self.assertEqual(SY.read_view(rules + tail)[3], ["## 안 올린 규칙 고침: 3줄"])   # STATUS 안의 0 이 아닌 고침


class Steps(SyncRepo):
    def test_unmapped_stage_line(self):   # Review Focus 4
        rc, out, err = self.sync()
        self.assertEqual(rc, 0, out + err)
        lines = out.splitlines()
        e2 = [l for l in lines if l.startswith("- E2 ")]
        self.assertEqual(len(e2), 1, out)
        self.assertIn(" — 대기", e2[0])
        self.assertTrue(e2[0].endswith("→ 걸음 없음 — 차례 표에 이 단계가 없다"), e2[0])
        e1 = [l for l in lines if l.startswith("- E1 ")]
        self.assertEqual(len(e1), 1, out)
        self.assertIn(" — 준비 → 걸음 3 다음 일 고르기와 보내기 · ", e1[0])
        self.assertTrue(e1[0].endswith(str(PLUGIN / "references" / "conducting-step-3.md")), e1[0])

    def test_merged_epic_rows_bring_step6(self):   # Review Focus 4 — 머지된 에픽의 줄이 남은 동안 걸음 6
        self.assertEqual(self.ledger("claim", "--roadmap", RM, "--session", SID)[0], 0)
        self.assertEqual(self.ledger("add", "--roadmap", RM, "--session", SID, "--section", "자원",
                                     "--cells", "worktree · /x/e3 · E3 · 설계 · t")[0], 0)
        self.addCleanup(self.ledger, "drop", "--roadmap", RM, "--session", SID, "--section", "자원", "--where", "경로=/x/e3")
        rc, out, err = self.sync()
        self.assertEqual(rc, 0, out + err)
        lines = out.splitlines()
        self.assertIn("머지 뒤 일이 남은 에픽:", lines)
        left, after = lines.index("끝나지 않은 일:"), lines.index("머지 뒤 일이 남은 에픽:")
        self.assertFalse([l for l in lines[left:after] if l.startswith("- E3 ")], out)   # 끝나지 않은 일 밑에 없다
        e3 = [l for l in lines[after:] if l.startswith("- E3 ")]
        self.assertEqual(len(e3), 1, out)
        self.assertIn(" → 걸음 6 머지 뒤 · ", e3[0])
        self.assertIn(str(PLUGIN / "references" / "conducting-step-6.md"), e3[0])
        self.assertTrue(e3[0].endswith(" · 남은 줄: 작업 0 · 자원 1 · 살아 있는 agent 0"), e3[0])
        self.assertEqual(without_time(out), without_time(self.sync()[1]))   # AC11 — 줄이 남은 같은 상태
        self.assertEqual(self.ledger("drop", "--roadmap", RM, "--session", SID, "--section", "자원",
                                     "--where", "경로=/x/e3")[0], 0)
        rc, out, err = self.sync()
        self.assertEqual(rc, 0, out + err)
        self.assertNotIn("머지 뒤 일이 남은 에픽", out)
        self.assertFalse([l for l in out.splitlines() if l.startswith("- E3 ")], out)

    def test_toc_broken_does_not_stop(self):   # Review Focus 1
        copy = self.t / "plugin-copy"
        shutil.copytree(str(PLUGIN), str(copy), symlinks=False, ignore=shutil.ignore_patterns("tests", "__pycache__"))
        self.addCleanup(shutil.rmtree, str(copy), True)
        toc = copy / "references" / "conducting.md"
        text = toc.read_text(encoding="utf-8")
        row = next(l for l in text.split("\n") if l.startswith("| 4 "))
        toc.write_text(text.replace(row + "\n", "", 1), encoding="utf-8")
        rc, out, err = self.sync(script=copy / "scripts" / "conductor_sync.py")
        self.assertEqual(rc, 0, out + err)
        self.assertIn("\n차례 — 이상: 표를 읽지 못했다 — 걸음 4 행의 첫 칸이 ", out)   # 차례 파서의 사유 그대로
        self.assertEqual([h for h in heads(out) if h in SEGMENTS], list(SEGMENTS), out)
        self.assertTrue(TIME_LINE.fullmatch(out.rstrip("\n").split("\n")[-1]), out)
        work = [l for l in out.splitlines() if l.startswith("- E")]
        self.assertTrue(work and not [l for l in work if "→ 걸음" in l], out)   # 일마다의 걸음 칸 없이
        rc, out, err = self.sync()
        self.assertNotIn("차례 —", out)   # 양성 짝 — 표가 맞으면 차례 줄이 없다


class Workers(SyncRepo):
    def test_session_workers(self):
        self.assertEqual(self.ledger("claim", "--roadmap", RM, "--session", SID)[0], 0)
        for cells in ("plan-e1 · E1 · 계획 · /wt/e1 · t", "sub-x · E1 · 구현 · /wt/x · t"):
            self.assertEqual(self.ledger("add", "--roadmap", RM, "--session", SID, "--section", "살아 있는 agent",
                                         "--cells", cells)[0], 0)
            self.addCleanup(self.ledger, "drop", "--roadmap", RM, "--session", SID, "--section", "살아 있는 agent",
                            "--where", "이름=" + cells.split(" · ")[0])
        terms = [{"address": "t9b", "name": "plan-e1", "parent": ME, "state": "live", "status": "working"},
                 {"address": "t9c", "name": "stray", "parent": ME, "state": "live", "status": "idle"},
                 {"address": "t8z", "name": "sub-x", "parent": "t1a", "state": "live", "status": "working"},
                 {"address": ME, "name": "leader", "state": "live", "status": "working"}]
        self.hc_json.write_text(json.dumps({"hidden_finished": 0, "terminals": terms}), encoding="utf-8")
        self.addCleanup(self.hc_json.write_text, json.dumps({"terminals": []}), encoding="utf-8")
        log = self.t / "hc.log"
        env = dict(self.env, HC_TERMINAL_ID=ME, FAKE_HC_LOG=str(log))
        rc, out, err = self.sync(env=env)
        self.assertEqual(rc, 0, out + err)
        self.assertIn("\n세션 담당자 — 이상: 표 2 · 내 자식 2 · 어긋남 2\n", out)
        self.assertIn("\n    견줄 줄: sub-x · E1 · 구현\n", out)
        self.assertIn("\n    표에 없는 내 자식: t9c stray idle\n", out)
        self.assertNotIn("plan-e1", out)
        self.assertEqual(log.read_text(encoding="utf-8").split("\n")[0], "ls --json --all")
        self.assertEqual(sorted(r["이름"] for r in self.machine()["살아 있는 agent"]), ["plan-e1", "sub-x"])   # 표의 줄은 그대로
        nohc = dict(env, PATH="%s:/usr/bin:/bin" % self.bin_nohc)
        rc, out, err = self.sync(env=nohc)
        self.assertEqual(rc, 0, out + err)
        self.assertIn("\n세션 담당자 — hc 없음 — 표의 줄 2 은 하니스 agent 목록과 견줄 줄\n", out)


class Team(SyncRepo):
    def test_team_bundle_line(self):
        rc, out, err = self.sync("--roadmap", TM)   # 뒤의 --roadmap 이 앞의 것을 덮는다
        self.assertEqual(rc, 0, out + err)
        lines = [l for l in out.splitlines() if l.startswith("리더 묶음 — ")]
        self.assertEqual(len(lines), 1, out)
        self.assertIn("start_bundle.py", lines[0])
        self.assertTrue(lines[0].endswith("--roadmap %s --role leader" % TM), lines[0])
        rc, bundle_out, err = self.run_py(SCRIPTS / "start_bundle.py", "--roadmap", TM, "--role", "leader")
        self.assertEqual(rc, 0, err)
        self.assertIn(ROLE_DOC, bundle_out)   # 양성 짝 — 묶음 본문에는 그 글이 있다
        self.assertNotIn(ROLE_DOC, out)
        self.assertNotIn("리더 묶음", self.sync()[1])   # team 형식이 아니면 그 줄이 없다


if __name__ == "__main__":
    unittest.main()
