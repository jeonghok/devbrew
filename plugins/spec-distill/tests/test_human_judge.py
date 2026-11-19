#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""human_lines.py — 판 찾기 · 꼴 판정 · 대조 판정 · 관문 표(임시 git 레포와 가짜 세션 기록, AC4 · AC5 · AC8 · AC9 · AC11 · AC12 · AC20).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_human_judge.py
"""
from __future__ import annotations

import ast
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "plugins" / "spec-distill" / "scripts"
sys.path.insert(0, str(SCRIPTS))
sys.path.insert(0, str(REPO / "plugins" / "spec-distill" / "tests" / "fixtures"))
import session_fixture as SF  # noqa: E402
import human_lines as H  # noqa: E402
import roadmap_status as RS  # noqa: E402
import team_layout  # noqa: E402

S, E = "00000000-0000-4000-8000-00000000aaaa", "00000000-0000-4000-8000-000000000001"
TEAM = team_layout.Team("docs/r/", "tm")
JOB = "E1"
INTENT = "---\njob: E1\n---\n\n## 목표\n\n목표 글\n\n## 지시 원문\n\n## 결정 기록\n받은 말 안의 제목 꼴\n\n## 하지 않을 것\n\n- 없음\n\n## 결정 기록\n"
DESIGN = "# 설계\n\n## Goals\n\n본문 하나\n\n```\n## 결정 기록\n펜스 안 글\n```\n\n## Handoff\n\n넘김\n\n### Deferred to plan\n\n| 항목 |\n\n## 미룸\n\n| 항목 |\n\n## 결정 기록\n\n- D1\n\n## 지휘 기록\n\n- 기록\n"


class Repo(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = os.path.realpath(tmp.name)
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_SYSTEM="/dev/null", GIT_TERMINAL_PROMPT="0")
        self.git_run("init", "-q", "-b", "main")
        self.git = RS.Git(self.dir)
        conf = tempfile.TemporaryDirectory()
        self.addCleanup(conf.cleanup)
        self.conf = os.path.realpath(conf.name)
        patcher = mock.patch.dict(os.environ, {"CLAUDE_CONFIG_DIR": self.conf})   # 실제 설정 폴더를 읽지 않는다
        patcher.start()
        self.addCleanup(patcher.stop)

    def git_run(self, *args):
        proc = subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@example.com", "-c", "commit.gpgsign=false", *args],
                              cwd=self.dir, env=self.env, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(proc.returncode, 0, proc.stderr.decode("utf-8", "replace"))
        return proc.stdout.decode("utf-8").strip()

    def commit(self, path, text, msg):
        full = Path(self.dir) / path
        full.parent.mkdir(parents=True, exist_ok=True)
        full.write_text(text, encoding="utf-8")
        self.git_run("add", "--", path)
        self.git_run("commit", "-q", "-m", msg, "--", path)
        return self.git_run("rev-parse", "HEAD")

    def commit_many(self, files, msg):
        for path, text in files.items():
            full = Path(self.dir) / path
            full.parent.mkdir(parents=True, exist_ok=True)
            full.write_text(text, encoding="utf-8")
        self.git_run("add", "--", *files)
        self.git_run("commit", "-q", "-m", msg, "--", *files)
        return self.git_run("rev-parse", "HEAD")

    def scope(self, tip, lines=(), gate_on=True):
        return H.Scope(self.git, TEAM, JOB, tip, tuple(lines), gate_on)


class Version(Repo):
    def test_version_is_the_last_commit_that_changed_the_body(self):
        path = TEAM.design(JOB)
        c1 = self.commit(path, DESIGN, "설계")
        self.assertEqual(H.version(self.git, c1, path), c1[:8])
        c2 = self.commit(path, DESIGN.replace("- 기록", "- 기록\n- 둘째"), "기록 절만")
        self.assertEqual(H.version(self.git, c2, path), c1[:8])
        c3 = self.commit(path, DESIGN.replace("본문 하나", "본문 둘"), "본문")
        c4 = self.commit("other.txt", "x", "다른 파일")
        self.assertEqual(H.version(self.git, c4, path), c3[:8])
        c5 = self.commit(path, DESIGN, "본문을 처음 글로 되돌림")
        self.assertEqual(H.version(self.git, c5, path), c5[:8])            # c1 과 본문이 같아도 이어진 구간이 아니다
        self.assertEqual(H.version(self.git, c1, path), c1[:8])            # 끝마다 따로 센다
        self.assertIsNone(H.version(self.git, c5, TEAM.plan(JOB, 1)))


class ShapeVerdict(Repo):
    def line(self, rev, file="design.md", kind="spec 승인", label="승인 — 계획 담당자에게"):
        return H.render(kind, "2026-11-18", label, file, rev, S, E + "#1")

    def test_verdicts(self):
        path = TEAM.design(JOB)
        c1 = self.commit(path, DESIGN, "설계")
        c2 = self.commit(path, DESIGN.replace("| 항목 |", "| 항목 |\n| 새 미룸 |").replace("- 기록", "- 기록\n- 승인 직전 기록"), "미룸 · 기록 절만")
        c3 = self.commit(path, DESIGN.replace("본문 하나", "본문 둘"), "본문")
        with mock.patch.dict(os.environ, {"CLAUDE_CONFIG_DIR": "/nonexistent/claude"}):   # 꼴 판정은 세션 기록을 읽지 않는다
            self.assertEqual(H.shape(self.scope(c1), self.line(c1[:8])).verdict, H.PASS)
            self.assertEqual(H.shape(self.scope(c2), self.line(c1[:8])).verdict, H.PASS)      # AC8 — 기록 절 · 미룸 절
            stale = H.shape(self.scope(c3), self.line(c1[:8]))
            self.assertEqual((stale.verdict, "다시 승인받는다" in stale.why, stale.line.rev), (H.STALE, True, c1[:8]))
            self.assertEqual(H.shape(self.scope(c3), self.line(c3[:8])).verdict, H.PASS)
            self.assertEqual(H.shape(self.scope(c3), self.line("deadbeef")).verdict, H.UNCHECKED)
            self.assertEqual(H.shape(self.scope(c3), self.line(c3[:8], "plan-1.md", "계획 검토", "계획대로 구현한다")).verdict, H.UNCHECKED)
            none = H.shape(self.scope(c3), "- spec 승인 · 2026-11-18 · 「승인 — 계획 담당자에게」")
            self.assertEqual((none.verdict, none.line), (H.NO_EVIDENCE, None))


class SeededRepo(Repo):
    """c1 설계 · c2 plan-1.md · c3 plan-2.md · c4 INTENT.md — 파일마다 다른 커밋이다. tip = c4."""

    def setUp(self):
        super().setUp()
        self.c1 = self.commit(TEAM.design(JOB), DESIGN, "설계")
        self.c2 = self.commit(TEAM.plan(JOB, 1), "# 계획 1\n", "계획 1")
        self.c3 = self.commit(TEAM.plan(JOB, 2), "# 계획 2\n", "계획 2")
        self.c4 = self.commit(TEAM.intent(JOB), INTENT, "INTENT")
        self.tip = self.c4

    def approve(self, tip, kind=H.KIND_SPEC, plan=None, gate=None, picked=None, question=None, rev=None, session=S, when="2026-11-18T12:00:00.000Z", **kw):
        """그 끝의 묶인 파일로 머리를 만들고, 그 머리로 시작하는 질문 창 답을 기록에 지어 넣고, 그 답을 가리키는 줄을 돌려준다."""
        name = H.bound_name(kind, plan)
        rev = rev or H.version(self.git, tip, TEAM.job(JOB, name))
        label = H.RETRY_LABEL if (gate or "").startswith("다시 시도") else H.PASS_LABELS[kind][0]
        text = question or "%s — %s자리표시 질문" % (H.head(JOB, rev, plan if kind == H.KIND_PLAN else None), (gate + " ") if gate else "")
        uid = SF.add_answer(self.conf, session, [(text, picked or label + " (권장)")], when=when, **kw)   # who · drop · sidechain · subagent 는 kw 로
        return H.render(kind, when[:10], label, name, rev, session, uid + "#1", gate=gate)


class Match(SeededRepo):
    def v(self, raw, lines=None, tip=None):
        return H.match(self.scope(tip or self.tip, tuple(lines if lines is not None else [raw])), raw).verdict

    def test_real_line_passes(self):                                     # 양성 대조
        self.assertEqual(self.v(self.approve(self.tip)), H.PASS)
        self.assertEqual(self.v(self.approve(self.tip, H.KIND_PLAN, 1)), H.PASS)
        self.assertEqual(self.v(self.approve(self.tip, H.KIND_SKIP, gate="계획 검토 plan 2")), H.PASS)
        self.assertEqual(self.v(self.approve(self.tip, picked="승인 — 계획 담당자에게")), H.PASS)

    def test_forged_lines_do_not_pass(self):
        real = self.approve(self.tip)
        l = H.parse(real)
        cases = {
            "손으로 쓴 줄": ("- spec 승인 · 2026-11-18 · 「승인 — 계획 담당자에게」", H.NO_EVIDENCE),
            "없는 항목": (real.replace(l.entry, "00000000-0000-4000-8000-00000000dead"), H.MISMATCH),
            "없는 순번": (real.replace("#1", "#2"), H.MISMATCH),
            "다른 과제의 답": (self.approve(self.tip, question="E2 @%s — 질문" % l.rev), H.MISMATCH),
            "라벨만 바꾼 줄": (self.approve(self.tip, picked="수정 필요"), H.MISMATCH),
            "머리 앞에 공백": (self.approve(self.tip, question=" " + H.head(JOB, l.rev) + " 질문"), H.MISMATCH),
            "머리 뒤에 16진 글자(더 긴 판)": (self.approve(self.tip, question=H.head(JOB, l.rev) + "0 질문"), H.MISMATCH),
            "사람 아님(수락이 아니다)": (self.approve(self.tip, who="denied"), H.MISMATCH),
            "모르는 출처": (self.approve(self.tip, who="other"), H.UNCHECKED),
            "훅이 채운 답": (self.approve(self.tip, who="hook"), H.MISMATCH),
            "프로그램이 대신 답한 세션": (self.approve(self.tip, entrypoint="sdk-cli"), H.MISMATCH),
            "모르는 entrypoint": (self.approve(self.tip, entrypoint="fixture_other"), H.UNCHECKED),
            "entrypoint 칸 없음": (self.approve(self.tip, drop=("entrypoint",)), H.UNCHECKED),
            "빈 답": (self.approve(self.tip, empty=True), H.MISMATCH),
            "곁가지 항목": (self.approve(self.tip, sidechain=True), H.MISMATCH),
            "하위 agent 기록": (self.approve(self.tip, subagent=True), H.MISMATCH),
            "아는 칸 없음": (self.approve(self.tip, who="unknown"), H.UNCHECKED),
            "기록 파일 없음": (real.replace(S + ":", "00000000-0000-4000-8000-00000000ffff:"), H.UNCHECKED),
            "다른 계획 파일의 답": (self.approve(self.tip, H.KIND_PLAN, 1).replace("plan-1.md@%s" % self.c2[:8], "plan-2.md@%s" % self.c3[:8]), H.MISMATCH),
            "건너뜀 — 질문에 관문 이름 없음": (self.approve(self.tip, H.KIND_SKIP, gate="계획 검토 plan 2", question=H.head(JOB, self.c4[:8]) + " 건너뛸까요"), H.MISMATCH),
            "건너뜀 — 다른 관문의 답": (self.approve(self.tip, H.KIND_SKIP, gate="계획 검토 plan 1").replace("계획 검토 plan 1", "계획 검토 plan 2"), H.MISMATCH),
        }
        for name, (raw, want) in cases.items():
            self.assertEqual(self.v(raw), want, name)
        self.assertIn("다시 승인받는다", H.match(self.scope(self.tip, (cases["기록 파일 없음"][0],)), cases["기록 파일 없음"][0]).why)

    def test_other_question_of_the_same_call(self):
        rev = self.c1[:8]
        uid = SF.add_answer(self.conf, S, [(H.head(JOB, rev) + " 승인할까요", "수정 필요"), ("다음 에픽도 함께 할까요", "승인 — 계획 담당자에게")],
                            when="2026-11-18T12:00:00.000Z")
        for n in (1, 2):
            raw = H.render(H.KIND_SPEC, "2026-11-18", "승인 — 계획 담당자에게", "design.md", rev, S, "%s#%d" % (uid, n))
            self.assertEqual(self.v(raw), H.MISMATCH, n)

    def test_old_answer_with_a_rewritten_version(self):
        real = self.approve(self.tip)                                    # c1 의 본문을 보고 한 답
        c5 = self.commit(TEAM.design(JOB), DESIGN.replace("본문 하나", "본문 둘"), "승인 뒤 본문 고침")
        self.assertEqual(self.v(real, tip=c5), H.STALE)
        rewritten = real.replace("design.md@" + self.c1[:8], "design.md@" + c5[:8])
        self.assertEqual(H.shape(self.scope(c5, (rewritten,)), rewritten).verdict, H.PASS)   # 꼴만 보면 지난다
        self.assertEqual(self.v(rewritten, tip=c5), H.MISMATCH)                               # 사람이 본 질문에는 옛 판이 있다

    def test_one_answer_two_lines(self):
        real = self.approve(self.tip)
        twin = real.replace("2026-11-18", "2026-11-19")
        self.assertEqual(self.v(real, [real, twin]), H.MISMATCH)
        self.assertEqual(self.v(twin, [real, twin]), H.MISMATCH)
        self.assertEqual(self.v(real, [real, "- 결정 · 2026-11-18 · 「글」"]), H.PASS)   # 여러 끝에서 모은 같은 줄은 한 줄이다(겹침 없이 넘긴다)
        other = "00000000-0000-4000-8000-00000000bbbb"                                    # 이어받은 세션이 같은 uuid 를 복사했다
        SF.add_answer(self.conf, other, [(H.head(JOB, self.c1[:8]) + " 질문", "승인 — 계획 담당자에게")], entry=H.parse(real).entry,
                      when="2026-11-18T12:00:00.000Z")
        self.assertEqual(self.v(copy_alone := real.replace(S + ":", other + ":"), [copy_alone]), H.PASS)   # 이어받은 세션의 답만 있으면 지난다(J3)
        copy = real.replace(S + ":", other + ":").replace("2026-11-18", "2026-11-19")
        self.assertEqual(self.v(copy, [real, copy]), H.MISMATCH)

    def test_plan_head_carries_the_plan_number(self):   # 설계 §2 — 계획 파일 둘을 한 커밋이 마지막으로 고쳤다
        both = self.commit_many({TEAM.plan(JOB, 1): "# 계획 1 고침\n", TEAM.plan(JOB, 2): "# 계획 2 고침\n"}, "두 계획을 한 커밋에서")
        self.assertEqual(H.version(self.git, both, TEAM.plan(JOB, 1)), H.version(self.git, both, TEAM.plan(JOB, 2)))   # 판이 같다
        one = self.approve(both, H.KIND_PLAN, 1)
        self.assertIn("근거", one)
        self.assertEqual(self.v(one, tip=both), H.PASS)
        as_two = re.sub(r"plan-1\.md@", "plan-2.md@", one)
        self.assertEqual(H.shape(self.scope(both, (as_two,)), as_two).verdict, H.PASS)      # 꼴만 보면 지난다
        self.assertEqual(self.v(as_two, tip=both), H.MISMATCH)                               # 머리의 계획 번호로 갈린다
        two = self.approve(both, H.KIND_PLAN, 2)
        self.assertEqual(self.v(two, [one, two], tip=both), H.PASS)

    def test_date_is_not_compared(self):   # J28 — 줄을 답에 묶는 것은 근거 칸이다. 날짜는 보이는 값일 뿐이다
        real = self.approve(self.tip, when="2026-11-18T23:30:00.000Z")
        self.assertIn(" · 2026-11-18 · ", real)
        self.assertEqual(self.v(real), H.PASS)
        self.assertEqual(self.v(re.sub("2026-11-18", "2026-12-25", real)), H.PASS)

    def test_gate_names_are_not_matched_as_substrings(self):
        q = H.head(JOB, self.c4[:8]) + " — 계획 검토 plan 12 를 건너뛸까요"
        twelve = self.approve(self.tip, H.KIND_SKIP, gate="계획 검토 plan 12", question=q)
        self.assertEqual(self.v(twelve), H.PASS)
        one = re.sub("계획 검토 plan 12 · ", "계획 검토 plan 1 · ", twelve)
        self.assertEqual(H.parse(one).gate, "계획 검토 plan 1")
        self.assertEqual(self.v(one), H.MISMATCH)

    def test_changed_record_shapes_are_unchecked(self):   # J33 — 조용히 「어긋남」 이 되지 않는다
        for drop in (("isSidechain",), ("sourceToolAssistantUUID",), ("answers",), ("toolUseResult",), ("timestamp",)):
            raw = self.approve(self.tip, drop=drop)
            got = H.match(self.scope(self.tip, (raw,)), raw)
            self.assertEqual(got.verdict, H.UNCHECKED, drop)
            self.assertIn("human_gate: 끔", got.why, drop)

    def break_last_call(self, session=S):
        """마지막 질문 창 호출의 질문 칸을 읽지 못하는 꼴로 바꾼다 — 그 결과는 답이 아니라 「읽지 못한 호출」 로 잡힌다."""
        path = SF.record_path(self.conf, session)
        rows = [json.loads(x) for x in path.read_text(encoding="utf-8").splitlines() if x]
        rows[-2]["message"]["content"][0]["input"] = {"questions": "자리표시"}
        path.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8")

    def test_unreadable_call_at_the_cited_entry_is_unchecked(self):   # 과제 2 — 읽지 못한 호출은 답이 아니다. 그 자리를 가리킨 줄은 「어긋남」 이 아니다
        raw = self.approve(self.tip)
        self.assertEqual(self.v(raw), H.PASS)                               # 양성 대조 — 같은 준비에서 깨기 전에는 지난다
        self.break_last_call()
        got = H.match(self.scope(self.tip, (raw,)), raw)
        self.assertEqual(got.verdict, H.UNCHECKED)
        self.assertIn("다시 승인받는다", got.why)
        elsewhere = re.sub(H.parse(raw).entry, "00000000-0000-4000-8000-00000000dead", raw)
        self.assertEqual(self.v(elsewhere), H.MISMATCH)                    # 읽지 못한 호출이 다른 자리에 있으면 「없다」 그대로
        empty = self.approve(self.tip, empty=True)                         # 고른 답이 빈 결과는 답이 아니다(J33)
        self.assertEqual(self.v(empty), H.MISMATCH)
        self.break_last_call()                                             # 질문까지 읽지 못하면 빈 답인지 가를 수 없다 — 닫힌 쪽(확인 못 함)
        self.assertEqual(self.v(empty), H.UNCHECKED)


class Gates(SeededRepo):
    def miss(self, lines, stage, plan=None, plain=False, deep=True, gate_on=True):
        return H.missing(self.scope(self.tip, tuple(lines), gate_on), stage, plan, plain, deep)

    def test_gate_table_is_fixed(self):
        self.assertEqual(H.GATES, {"design": (), "plan": ("spec 승인",), "implement": ("spec 승인", "계획 검토"), "review": ("spec 승인", "계획 검토")})
        self.assertEqual((H.PLAIN_GATES, H.RETRY_STOP, H.GATE_OFF), (("흐름 승인",), 2, "사람 줄 대조가 꺼져 있다"))
        self.assertEqual([H.needed("design", None, False), H.needed("plan", 1, False), H.needed("implement", 2, False), H.needed("review", 2, False)],
                         [[], [("spec 승인", None)], [("spec 승인", None), ("계획 검토", 2)], [("spec 승인", None), ("계획 검토", 2)]])
        for stage in ("design", "plan", "implement", "review"):
            self.assertEqual(H.needed(stage, None, True), [("흐름 승인", None)])
        source = (SCRIPTS / "human_lines.py").read_text(encoding="utf-8")
        for word in ("repo_defaults", "walk_table", "os.environ"):       # AC9 — 관문 표는 설정 · 걸음표 · 환경에서 읽지 않는다
            self.assertNotIn(word, source, word)

    @staticmethod
    def reads_outside(source):
        """모듈 글의 구문 나무에서 — env: 환경 읽기(environ · getenv · 동적 import), settings: 설정 · 걸음표 · 지휘 상태 모듈 import 나 설정 파일 이름."""
        tree = ast.parse(source)
        names, mods = set(), set()
        for n in ast.walk(tree):
            if isinstance(n, ast.Attribute):
                names.add(n.attr)
            elif isinstance(n, ast.Name):
                names.add(n.id)
            elif isinstance(n, ast.Import):
                mods |= {a.name.split(".")[0] for a in n.names}
                names |= {(a.asname or a.name).split(".")[0] for a in n.names}
            elif isinstance(n, ast.ImportFrom):
                mods.add((n.module or "").split(".")[0])
                names |= {a.name for a in n.names}
        texts = [n.value for n in ast.walk(tree) if isinstance(n, ast.Constant) and isinstance(n.value, str)]
        env = bool(names & {"environ", "environb", "getenv", "getenvb", "__import__", "import_module"} or mods & {"os", "importlib"})
        settings = bool(mods & {"repo_defaults", "walk_table", "conductor_state"} or any(".devbrew" in x for x in texts))
        return {"env": env, "settings": settings}

    def test_gate_table_reads_no_settings_or_environment(self):   # AC9 · F8 — 글자 부재가 아니라 구문 나무로 본다
        self.assertEqual(self.reads_outside((SCRIPTS / "human_lines.py").read_text(encoding="utf-8")), {"env": False, "settings": False})
        planted = {                                                       # 양성 대조 — 글자 부재 락이 놓치는 꼴을 탐침이 본다
            "from os import getenv\nGATES = getenv('X')\n": "env",
            "from os import environ as e\n": "env",
            "import os as o\nGATES = o.environ.get('X')\n": "env",
            "import importlib\nm = importlib.import_module('o' + 's')\n": "env",
            "m = __import__('o' + 's')\n": "env",
            "from repo_defaults import gate_on\n": "settings",
            "import walk_table as w\n": "settings",
            "import conductor_state\n": "settings",
            "P = '.devbrew.md'\n": "settings",
        }
        for src, axis in planted.items():
            self.assertTrue(self.reads_outside(src)[axis], src)
        self.assertTrue(self.reads_outside((SCRIPTS / "state_path.py").read_text(encoding="utf-8"))["env"])             # 실제 모듈로도
        self.assertTrue(self.reads_outside((SCRIPTS / "conductor_ledger.py").read_text(encoding="utf-8"))["settings"])

    def test_missing(self):
        spec, plan1 = self.approve(self.tip), self.approve(self.tip, H.KIND_PLAN, 1)
        self.assertEqual(self.miss([], "design"), [])
        none = self.miss([], "implement", 1)
        self.assertEqual(len(none), 2)
        self.assertTrue(none[0].startswith("`spec 승인` 줄이 없다") and 'record --human "spec 승인"' in none[0], none[0])
        self.assertTrue(none[1].startswith("`계획 검토` 줄이 없다(계획 1)"), none[1])
        self.assertEqual(self.miss([spec], "plan", 1), [])
        self.assertEqual(len(self.miss([spec], "implement", 1)), 1)
        self.assertEqual(self.miss([spec, plan1], "implement", 1), [])
        self.assertEqual(self.miss([spec, plan1], "review", 1), [])
        two = self.miss([spec, plan1], "implement", 2)                   # 계획 1 의 줄은 계획 2 를 열지 않는다
        self.assertEqual((len(two), "계획 2" in two[0]), (1, True))
        hand = "- spec 승인 · 2026-11-18 · 「승인 — 계획 담당자에게」"
        self.assertIn("근거 없음", self.miss([hand], "plan", 1)[0])
        self.assertIn("record --human", self.miss([hand], "plan", 1)[0])

    def test_skip_line_opens_only_its_gate(self):
        spec, plan1 = self.approve(self.tip), self.approve(self.tip, H.KIND_PLAN, 1)
        skip2 = self.approve(self.tip, H.KIND_SKIP, gate="계획 검토 plan 2")
        self.assertEqual(self.miss([spec, skip2], "implement", 2), [])
        self.assertEqual(len(self.miss([spec, skip2], "implement", 1)), 1)       # 다른 관문은 그대로
        self.assertEqual(len(self.miss([skip2], "implement", 2)), 1)             # spec 승인은 그대로
        skip_spec = self.approve(self.tip, H.KIND_SKIP, gate="spec 승인")
        self.assertEqual(self.miss([skip_spec], "plan", 1), [])
        got, why = H.passed(self.scope(self.tip, (skip_spec,)), H.KIND_SPEC, None, True)
        self.assertEqual((got, why), (H.Passed("2026-11-18", True), None))
        self.assertEqual(H.passed(self.scope(self.tip, (spec,)), H.KIND_SPEC, None, True)[0], H.Passed("2026-11-18", False))
        self.assertEqual(H.passed(self.scope(self.tip, ()), H.KIND_SPEC, None, True), (None, H.NO_LINE))

    def test_collect_reads_every_tip_once(self):
        one = "- 결정 · 2026-11-18 · 「하나」"
        a = self.commit(TEAM.intent(JOB), INTENT + "\n" + one + "\n", "줄 하나")
        b = self.commit(TEAM.intent(JOB), INTENT + "\n" + one + "\n- 결정 · 2026-11-19 · 「둘」\n", "줄 둘")
        self.assertEqual(H.collect(self.git, TEAM, JOB, [a, b, a, self.c1]), ((one, "- 결정 · 2026-11-19 · 「둘」"), []))   # c1 에는 INTENT.md 가 없다
        broken = self.commit(TEAM.intent(JOB), "머리 없는 글\n", "깨진 INTENT")
        lines, notes = H.collect(self.git, TEAM, JOB, [broken, b, broken])
        self.assertEqual((len(lines), len(notes), broken[:8] in notes[0]), (2, 1, True))   # 같은 끝은 한 번만 읽고 한 번만 알린다

    def test_expected_lines_from_traces(self):   # J24 — human-check 가 「있어야 하는데 없는 줄」 을 찾는 표
        self.assertEqual(H.expected(False, [], [], []), [])
        self.assertEqual(H.expected(False, [], ["design-1.md"], []), [])
        self.assertEqual(H.expected(False, ["plan-1.md"], [], []), [("spec 승인", None, "plan-1.md 가 있다")])
        self.assertEqual(H.expected(False, ["plan-1.md", "plan-2.md"], ["plan-plan-1-1.md", "implement-plan-2-1.md", "review-plan-2-1.md"], []),
                         [("spec 승인", None, "plan-1.md 가 있다"), ("계획 검토", 2, "implement-plan-2-1.md 가 있다")])
        self.assertEqual(H.expected(False, [], [], ["implement-plan-1-2.md"]),
                         [("spec 승인", None, "implement-plan-1-2.md 의 받음 줄이 있다"), ("계획 검토", 1, "implement-plan-1-2.md 의 받음 줄이 있다")])
        self.assertEqual(H.expected(False, [], ["plan-plan-3-1.md"], []), [("spec 승인", None, "plan-plan-3-1.md 가 있다")])
        self.assertEqual(H.expected(True, [], [], []), [])
        self.assertEqual(H.expected(True, [], ["implement-1.md"], []), [("흐름 승인", None, "implement-1.md 가 있다")])
        self.assertEqual(H.expected(True, [], [], ["implement-1.md"]), [("흐름 승인", None, "implement-1.md 의 받음 줄이 있다")])

    def test_received_lines_follow_the_gate_table_by_stage(self):   # J24 · AC23 — 받음 줄도 결과 파일처럼 단계로 가른다
        self.assertEqual(H.expected(False, [], [], ["plan-plan-3-1.md"]), [("spec 승인", None, "plan-plan-3-1.md 의 받음 줄이 있다")])
        self.assertEqual(H.expected(False, [], [], ["design-1.md"]), [])
        self.assertEqual(H.expected(False, [], [], ["review-plan-2-1.md"]),
                         [("spec 승인", None, "review-plan-2-1.md 의 받음 줄이 있다"), ("계획 검토", 2, "review-plan-2-1.md 의 받음 줄이 있다")])
        self.assertEqual(H.expected(False, [], [], ["결과 아님.md"]), [])
        self.assertEqual(H.expected(False, [], ["plan-plan-3-1.md"], ["plan-plan-3-1.md", "implement-plan-3-1.md"]),
                         [("spec 승인", None, "plan-plan-3-1.md 가 있다"), ("계획 검토", 3, "implement-plan-3-1.md 의 받음 줄이 있다")])

    def test_gate_off_guidance_writes_by_text(self):   # §8 — 꺼져 있으면 질문 창 답이 아니라 글로 적는다
        off = self.miss([], "implement", 1, gate_on=False)
        self.assertEqual(off, ["`spec 승인` 줄이 없다 — 사람 줄 대조가 꺼져 있다 — 글로 적는다: `conductor_ledger.py record --approval --choice \"<고른 글>\"`",
                               "`계획 검토` 줄이 없다(계획 1) — 사람 줄 대조가 꺼져 있다 — 글로 적는다: "
                               "`conductor_ledger.py record --line \"계획 검토 · <YYYY-MM-DD> · 「<고른 글>」\"`"])
        flow = self.miss([], "implement", None, plain=True, gate_on=False)[0]
        self.assertIn('record --line "흐름 승인 · ', flow)
        on = self.miss([], "implement", 1)                                               # 양성 대조 — 켜져 있으면 질문 창 답에서만
        self.assertTrue(all("record --human" in x and "--line" not in x and "--approval" not in x for x in on), on)
        self.assertTrue(all("record --human" not in x for x in off + [flow]), off)

    def test_gate_off_malformed_spec_line_and_dateless_skip(self):
        bad = "- spec 승인 · 2026-11-1 · 「승인」"                                        # 정해진 꼴의 날짜가 어긋났다(approval_in 의 옛 규칙)
        got, why = H.passed(self.scope(self.tip, (bad,), False), H.KIND_SPEC, None, True)
        self.assertEqual(got, None)
        self.assertTrue(why.startswith("어긋남 — "), why)
        text = self.miss([bad], "plan", 1, gate_on=False)[0]
        self.assertTrue(text.startswith("`spec 승인` 줄이 지나지 못했다: 어긋남 — ") and "record --approval --choice" in text, text)
        skip_spec = "- 걸음 건너뜀 · 2026-11-18 · 「건너뛴다」 · spec 승인"
        self.assertEqual(H.passed(self.scope(self.tip, (bad, skip_spec), False), H.KIND_SPEC, None, True), (H.Passed("2026-11-18", True), None))
        dateless = "- 걸음 건너뜀 · 「건너뛴다」 · 계획 검토 plan 1"
        self.assertEqual(H.passed(self.scope(self.tip, (dateless,), False), H.KIND_PLAN, 1, True), (H.Passed("", True), None))
        self.assertEqual(H.passed(self.scope(self.tip, (dateless,), False), H.KIND_PLAN, 2, True), (None, H.NO_LINE))

    def test_collect_notes_a_tip_git_cannot_read(self):   # 없는 것과 읽지 못한 것은 다르다
        b = self.commit(TEAM.intent(JOB), INTENT + "\n- 결정 · 2026-11-19 · 「둘」\n", "줄")
        lines, notes = H.collect(self.git, TEAM, JOB, ["deadbeef", b, self.c1])      # git 이 「객체 이름이 아니다」 로 실패한다(경로 없음이 아니다)
        self.assertEqual((lines, len(notes)), (("- 결정 · 2026-11-19 · 「둘」",), 1))
        self.assertIn("deadbeef 의 결정 기록을 읽지 못했다", notes[0])

    def test_rerecord_tail_only_for_no_evidence_and_mismatch(self):
        real = self.approve(self.tip)
        c5 = self.commit(TEAM.design(JOB), DESIGN.replace("본문 하나", "본문 둘"), "승인 뒤 본문 고침")
        stale = H.missing(self.scope(c5, (real,)), "plan", 1, False, True)[0]
        self.assertTrue(stale.startswith("`spec 승인` 줄이 지나지 못했다: 낡음 — ") and "record --human" not in stale, stale)
        with mock.patch.dict(os.environ, {"CLAUDE_CONFIG_DIR": "/nonexistent/claude"}):
            unchecked = self.miss([real], "plan", 1)[0]
        self.assertTrue(unchecked.startswith("`spec 승인` 줄이 지나지 못했다: 확인 못 함 — ") and "record --human" not in unchecked, unchecked)
        hand = self.miss(["- spec 승인 · 2026-11-18 · 「승인 — 계획 담당자에게」"], "plan", 1)[0]          # 양성 대조
        self.assertTrue(hand.endswith('— 질문 창으로 승인받고 `conductor_ledger.py record --human "spec 승인"` 로 다시 적는다'), hand)

    def test_failing_skip_line_is_not_hidden_as_no_line(self):
        forged = self.approve(self.tip, H.KIND_SKIP, gate="계획 검토 plan 1")
        forged = re.sub("계획 검토 plan 1 · ", "spec 승인 · ", forged)               # 질문에 spec 승인 이 없다
        self.assertEqual(H.parse(forged).gate, "spec 승인")
        got, why = H.passed(self.scope(self.tip, (forged,)), H.KIND_SPEC, None, True)
        self.assertEqual((got, why), (None, "어긋남 — 그 질문에 관문 이름 spec 승인 이 없다"))
        self.assertTrue(self.miss([forged], "plan", 1)[0].startswith("`spec 승인` 줄이 지나지 못했다: 어긋남 — "))
        self.assertEqual(H.passed(self.scope(self.tip, ()), H.KIND_SPEC, None, True), (None, H.NO_LINE))   # 줄이 정말 없을 때만 「줄이 없다」

    def test_shallow_and_deep(self):
        spec = self.approve(self.tip)
        with mock.patch.dict(os.environ, {"CLAUDE_CONFIG_DIR": "/nonexistent/claude"}):
            self.assertEqual(self.miss([spec], "plan", 1, deep=False), [])
            self.assertIn("확인 못 함", self.miss([spec], "plan", 1, deep=True)[0])

    def test_plain_flow(self):
        flow = self.approve(self.tip, H.KIND_FLOW)
        self.assertEqual(self.miss([flow], "implement", None, plain=True), [])
        self.assertEqual(len(self.miss([self.approve(self.tip)], "implement", None, plain=True)), 1)
        self.assertIn("흐름 승인", self.miss([], "implement", None, plain=True)[0])

    def test_retry(self):
        retry = self.approve(self.tip, H.KIND_SKIP, gate="다시 시도 plan 1 시도 3")
        sc = self.scope(self.tip, (retry,))
        self.assertEqual([H.retry_open(sc, 1, 3, True), H.retry_open(sc, 1, 4, True), H.retry_open(sc, 2, 3, True), H.retry_open(sc, None, 3, True)],
                         [True, False, False, False])
        plain = self.approve(self.tip, H.KIND_SKIP, gate="다시 시도 구현 시도 3")
        self.assertTrue(H.retry_open(self.scope(self.tip, (plain,)), None, 3, True))
        self.assertTrue(self.miss([retry], "plan", 1)[0].startswith("`spec 승인` 줄이 없다"))   # 다시 시도 줄은 다른 관문을 열지 않는다

    def test_gate_off_looks_only_for_lines(self):
        with mock.patch.dict(os.environ, {"CLAUDE_CONFIG_DIR": "/nonexistent/claude"}):
            self.assertEqual(len(self.miss([], "implement", 1, gate_on=False)), 2)
            lines = ["- spec 승인 · 2026-11-18 · 「승인」", "- 계획 검토 · 2026-11-18 · 「좋다」"]
            self.assertEqual(self.miss(lines, "implement", 7, gate_on=False), [])
            self.assertEqual(self.miss(lines[:1], "plan", 1, gate_on=False), [])
            self.assertEqual(len(self.miss(lines[:1], "implement", 1, gate_on=False)), 1)
            skip = "- 걸음 건너뜀 · 2026-11-18 · 「건너뛴다」 · 계획 검토 plan 1"
            self.assertEqual(self.miss([lines[0], skip], "implement", 1, gate_on=False), [])
            self.assertEqual(len(self.miss([lines[0], skip], "implement", 2, gate_on=False)), 1)
            self.assertEqual(self.miss(["- 흐름 승인 · 2026-11-18 · 「설계 없이 진행」"], "implement", None, plain=True, gate_on=False), [])
            self.assertTrue(H.retry_open(self.scope(self.tip, ("- 걸음 건너뜀 · 2026-11-18 · 「다시 시도한다」 · 다시 시도 plan 1 시도 3",), False), 1, 3, True))
            self.assertEqual(len(self.miss(lines, "implement", 1, gate_on=True)), 2)   # 양성 대조 — 켜면 같은 줄이 지나지 못한다


if __name__ == "__main__":
    unittest.main()
