#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""qg_review_state.py 걸어 보기 — 한 PR 의 머지 앞 리뷰(첫 리뷰 → 막는 지적 → 되돌리기 → 좁은 재리뷰 → 관문)를
스크립트 명령만으로 끝까지 돌리고, 중간 세 곳에서 끊었다 `next` 로 잇는다. 지휘 절차 문서의 펜스를 뽑아 돌리고,
접은 여러 줄 지적 줄을 기록 명령이 받는지 본다(설계 Verification Plan 「걸어 보기」 · AC8 · AC18 · AC31).

펜스를 돌린 종료 코드는 이 걸음에서 나와야 하는 값과만 견준다 — 문서의 종료 코드 문장(명령마다 흩어져 있다)과의
대조는 손으로 한다.

끊는 곳마다 리포를 새로 세운다 — 구현 담당자의 커밋이 브랜치 끝을 옮겨, 한 리포에서는 걸음끼리 범위가 섞인다.

Run: cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_qg_review_state_walk -v
"""
from __future__ import annotations

import io
import os
import json
import re
import shlex
import subprocess
import sys
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

TESTS = Path(__file__).resolve().parent
PLUGIN = TESTS.parent
sys.path.insert(0, str(PLUGIN / "scripts"))
sys.path.insert(0, str(TESTS))
import qg_review_file as F  # noqa: E402
import qg_review_state as Q  # noqa: E402
from qg_review_state_fixture import BASE, EPIC, GIT_ENV, HANDLING_HEAD, HEAD, ROADMAP, SESSION, Rig  # noqa: E402

QG_DOC = PLUGIN / "skills" / "epic-conductor" / "references" / "qg-review.md"
TARGET = "pr12"
SPEC = "docs/superpowers/specs/a1-design.md"
SPEC_TEXT = "# A1 설계\n\n## 지휘 기록\n\n- 결정 · 2026-11-25 · 이대로 간다\n"
DAY = "2026-11-26"
FINDING_1 = "IMPORTANT src/a.py:1 — 값이 틀렸다 · 고칠 방법: 1 로 되돌린다"
FINDING_2 = "IMPORTANT src/a.py:2 — 이름이 틀렸다 · 고칠 방법: b 를 c 로"
PRE_MERGE_1 = [
    {"file": "src/a.py", "line": 1, "severity": "IMPORTANT", "summary": "값이 틀렸다", "proposed_fix": "1 로 되돌린다"},
    {"file": "src/a.py", "line": 2, "severity": "IMPORTANT", "summary": "이름이 틀렸다", "proposed_fix": "b 를 c 로"}]
HANDLING_ROW = re.compile("- 막는 지적 ([1-9][0-9]*) · (.+)")
MAX_STEPS = 20
BACK_NEXT = "할 일 · next 를 부른다 · 돌아온 결과를 상태 파일에 옮겼다 — 다음 할 일은 next 가 정한다"


class Walk:
    """한 PR 의 흐름 하나 — 지휘자가 부르는 명령, 그리고 바깥에서 일어나는 일(qg 담당자 · 구현 담당자가 끝나며 남기는 것).
    `alive` 는 하니스 목록에 살아 있는 담당자 이름이고, `jobs` 는 그 담당자가 끝날 때 하는 일이다."""

    def __init__(self, tc):
        self.tc = tc
        self.rig = Rig(tc)
        self.base_sha = self.rig.sha()
        self.c1 = self.rig.commit({SPEC: SPEC_TEXT, "src/a.py": "a = 2\nb = 1\n"}, "impl 1")
        self.labels = {self.base_sha: "base", self.c1: "c1"}
        self.alive, self.jobs, self.folders = [], {}, {}
        self.minute = 0
        self.inputs = 0
        self.returns = 0
        self.seen = set()

    # ------------------------------------------------------------ 명령

    def at(self) -> str:
        self.minute += 1
        return "%s 10:%02d" % (DAY, self.minute)

    def call(self, cmd, *args, exclude=True):
        """`qg_review_state.py <cmd> --roadmap … --target … --repo … --at … <args>` — (rc, 줄들)."""
        argv = [cmd, "--roadmap", ROADMAP, "--target", TARGET, "--repo", str(self.rig.repo), "--at", self.at()]
        if exclude:
            argv += ["--spec", SPEC]
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            try:
                rc = Q.main(argv + list(args))
            except SystemExit as exc:
                rc = exc.code
        self.last_err = err.getvalue()
        return rc, out.getvalue().splitlines()

    def ok(self, cmd, *args, exclude=True):
        rc, lines = self.call(cmd, *args, exclude=exclude)
        self.tc.assertEqual(rc, 0, "%s → %d\n%s\n%s" % (cmd, rc, "\n".join(lines), self.last_err))
        return lines

    def next(self, row=None, kind=None):
        args = []
        for name in self.alive:
            args += ["--alive", name]
        lines = self.ok("next", *args)
        self.tc.assertTrue(len(lines) >= 3 and lines[1].startswith("줄 · "), lines)
        if row is not None:
            self.tc.assertEqual((lines[1], lines[0].split(" · ")[1]), ("줄 · " + row, kind), lines)
        return lines

    def open(self, site) -> list:
        lines = self.ok("open", "--site", site, "--base", BASE, "--head", HEAD, "--epic", EPIC, "--session", SESSION)
        self.tc.assertTrue(lines[0].startswith("보관 폴더 · "), lines)
        order = len(self.reviews())
        self.folders[order] = Path(lines[0][len("보관 폴더 · "):])
        return lines

    def record(self, items):
        """`record --input` — 입력 파일은 보관 폴더 밖(리포 밖 임시 폴더)에 쓴다."""
        self.inputs += 1
        path = self.rig.t / ("input-%d.json" % self.inputs)
        path.write_text(json.dumps({"items": items}, ensure_ascii=False), encoding="utf-8")
        return self.ok("record", "--input", str(path))

    def suite_lock_free(self):
        """`### 스위트 잠금` — 보내기 전에 `ledger suite-lock` 의 둘째 줄을 본다."""
        rc, out = self.rig.ledger("suite-lock", "--roadmap", ROADMAP)
        self.tc.assertEqual((rc, out.splitlines()[1:2]), (0, ["스위트 잠금: 비어 있음"]), out)

    def reviews(self):
        return F.reviews_for(self.rig.report_root, TARGET)

    def gate(self):
        return self.call("gate")

    # ------------------------------------------------------------ 바깥에서 일어나는 일

    def spawn_qg(self) -> str:
        order = len(self.reviews())
        name = "qg-w%d" % order
        self.alive.append(name)
        self.jobs[name] = lambda: self.qg_finishes(order)
        return name

    def qg_finishes(self, order):
        """qg 담당자가 끝나며 보관 폴더에 남기는 파일 — 첫 리뷰는 막는 지적 둘, 그 뒤 리뷰는 없음."""
        rv = self.reviews()[order - 1]
        folder = self.folders[order]
        if order == 1:
            self.rig.write_result(folder, "defect", rv.range_start, rv.range_end, blocking=[FINDING_1, FINDING_2])
            self.rig.write_pre_merge(folder, PRE_MERGE_1)
        else:
            self.rig.write_result(folder, "clean", rv.range_start, rv.range_end)
            self.rig.write_pre_merge(folder, [])
        self.rig.write_intent_return(folder, [])

    def spawn_impl(self, return_list: list) -> str:
        name = "impl-w%d" % self.returns
        self.alive.append(name)
        self.jobs[name] = lambda: self.impl_finishes(return_list)
        return name

    def impl_finishes(self, return_list):
        """구현 담당자가 받은 목록의 막는 지적마다 고치고 처리 파일에 `고친 커밋 <해시>` 를 쓴다."""
        numbers = [m.group(1) for m in (re.match(r"- 막는 지적 ([1-9][0-9]*) · ", x) for x in return_list) if m]
        self.tc.assertEqual(numbers, ["1", "2"], return_list)
        path = Path([x for x in return_list if x.startswith("처리 파일: ")][0][len("처리 파일: "):])
        fix = self.rig.commit({"src/a.py": "a = 1\nc = 1\n"}, "fix %d" % self.returns)
        self.labels[fix] = "fix%d" % self.returns
        self.rig.write_handling(path, ["막는 지적 %s · 고친 커밋 %s" % (n, fix) for n in numbers])

    def finish(self, name):
        self.alive.remove(name)
        self.jobs.pop(name)()

    # ------------------------------------------------------------ 할 일대로

    def send(self, start: bool):
        if start:
            self.suite_lock_free()
            self.tc.assertEqual(self.ok("send", "--phase", "start", exclude=False), ["단계 · 보내는 중"])
        name = self.spawn_qg()
        lines = self.ok("send", "--phase", "done", "--worker", name, exclude=False)
        self.tc.assertEqual(lines[0], "단계 · 보냄", lines)

    def send_back(self, handling: Path):
        rc, return_list = self.call("render", "--kind", "return-list", "--handling-file", str(handling),
                                    exclude=False)
        self.tc.assertEqual(rc, 0, return_list)
        name = self.spawn_impl(return_list)
        return self.record([{"kind": "return", "worker": name, "handling_file": str(handling)}])

    def handling_path(self) -> Path:
        """`## 되돌리기` — 하위 agent 길의 처리 파일은 그 에픽 보고 폴더의 `handling-<자리 글자>-<n>.md`."""
        self.returns += 1
        tag = self.reviews()[-1].site_tag
        return self.rig.resource_dir("report", EPIC) / ("handling-%s-%d.md" % (tag, self.returns))

    def move_handling(self, path: Path):
        """처리 파일의 `## 지적마다의 처리` 머리 아래를 `return_moved` 와 지적마다 `handling` 으로 옮긴다."""
        lines = path.read_text(encoding="utf-8").split("\n")
        rows = [HANDLING_ROW.fullmatch(x) for x in lines[lines.index(HANDLING_HEAD) + 1:]]
        items = [{"kind": "return_moved", "value": "옮김"}]
        items += [{"kind": "handling", "finding": int(m.group(1)), "value": m.group(2)} for m in rows if m]
        return self.record(items)

    def follow(self, lines):
        """`next` 가 낸 할 일 하나를 문서(`## 머지 앞 리뷰 상태` 의 꼴 표)대로 한다. 머지 준비면 참."""
        kind, text = lines[0].split(" · ")[1], lines[0].split(" · ", 2)[2]
        if kind == "열기":
            self.open(re.search(r"open --site ([a-z]+)", text).group(1))
        elif kind == "보냄":
            self.send(start="send --phase start" in text)
        elif kind == "기다린다":
            names = [n for n in self.alive if n in text]
            self.tc.assertEqual(len(names), 1, (lines, self.alive))
            self.finish(names[0])
        elif kind == "돌아옴":
            self.ok("back", exclude=False)
        elif kind == "돌려보낸다":
            self.send_back(self.handling_path())
        elif kind == "답 적기" and lines[1] == "줄 · R7b":
            self.move_handling(Path(re.search(r"처리 파일 (\S+) 을 읽어", text).group(1)))
        elif kind == "머지 준비":
            return True
        else:
            self.tc.fail("걸어 보기에서 나올 할 일이 아니다: %s" % lines)
        return False

    def state(self) -> tuple:
        folders = sorted(self.rig.report_root.glob("*/" + F.STATE_NAME))
        return tuple(p.read_bytes() for p in folders), tuple(self.alive), self.rig.sha()

    def drive(self):
        """`next` 를 부르고 그 할 일대로 하기를 머지 준비까지 — 같은 할 일이 같은 상태로 다시 나오면 실패(AC31)."""
        for _ in range(MAX_STEPS):
            lines = self.next()
            key = (lines[0], self.state())
            self.tc.assertNotIn(key, self.seen, "같은 할 일이 같은 상태로 다시 나왔다: %s" % lines)
            self.seen.add(key)
            if self.follow(lines):
                return
        self.tc.fail("%d 걸음 안에 머지 준비에 닿지 못했다" % MAX_STEPS)

    def end(self):
        """닿은 끝 — 관문과 리뷰마다의 칸(해시는 이름표로)."""
        rc, lines = self.gate()

        def label(text):
            return re.sub("[0-9a-f]{40}", lambda m: self.labels.get(m.group(0), "?"), text)

        reviews = [(rv.order, rv.site, rv.stage, rv.close_reason, label(rv.range_start), label(rv.range_end),
                    rv.result.kind, tuple((f.kind, f.text, label(f.handling)) for f in rv.blocking),
                    tuple((x.worker, x.moved) for x in rv.returns)) for rv in self.reviews()]
        return rc, lines, reviews


class TestQgReviewStateWalk(unittest.TestCase):

    def walk(self, cut=None) -> Walk:
        """한 PR 을 명령으로 걷는다. `cut` 이 주어지면 그 자리에서 끊고 `next` 로 잇는다."""
        w = Walk(self)
        w.next("R8a", "열기")
        lines = w.open("premerge")
        self.assertEqual(lines[1:], ["범위 · %s..%s" % (w.base_sha, w.c1), "자리 글자 · premerge-" + TARGET])
        w.next("R1a", "보냄")
        w.suite_lock_free()
        self.assertEqual(w.ok("send", "--phase", "start", exclude=False), ["단계 · 보내는 중"])
        if cut == "sending":
            return self.resume(w, "R1b", "보냄")
        w.send(start=False)
        w.next("R1d", "기다린다")
        w.finish("qg-w1")
        w.next("R1e", "돌아옴")
        lines = w.ok("back", exclude=False)
        self.assertEqual(lines[0], BACK_NEXT, lines)  # back 은 할 일을 짓지 않는다 — next 가 정한다
        rv = w.reviews()[-1]
        self.assertEqual((rv.stage, [f.text for f in rv.blocking]), ("돌아옴", [FINDING_1, FINDING_2]))
        w.next("R7d", "돌려보낸다")
        handling = w.handling_path()
        lines = w.send_back(handling)
        self.assertTrue(lines[0].startswith("할 일 · 기다린다 · 구현 담당자 impl-w1 가 살아 있다"), lines)
        if cut == "returned":
            return self.resume(w, "R7a", "기다린다")
        w.next("R7a", "기다린다")
        w.finish("impl-w1")
        w.next("R7b", "답 적기")
        lines = w.move_handling(handling)
        self.assertTrue(lines[0].startswith("할 일 · 열기 · 좁은 재리뷰(open --site recheck)"), lines)
        self.assertEqual((w.reviews()[-1].stage, w.reviews()[-1].close_reason), ("닫힘", "재리뷰로 이어짐"))
        w.next("R7e", "열기")
        rc, lines = w.gate()
        self.assertEqual((rc, lines[:1]), (1, ["관문 · 닫힘"]), lines)
        fix = w.rig.sha()
        lines = w.open("recheck")
        self.assertEqual(lines[1:], ["범위 · %s..%s" % (w.c1, fix), "자리 글자 · recheck-" + TARGET])
        if cut == "rechecked":
            return self.resume(w, "R1a", "보냄")
        w.send(start=True)
        w.finish("qg-w2")
        w.next("R1e", "돌아옴")
        lines = w.ok("back", exclude=False)
        self.assertEqual(lines, [BACK_NEXT])
        w.next("R9", "머지 준비")
        return w

    def resume(self, w: Walk, row: str, kind: str) -> Walk:
        """끊긴 자리 — 그때까지의 상태(상태 파일 · git · 하니스 목록)만 두고 `next` 를 불러 그 할 일로 잇는다."""
        self.cut_rows.append(w.next(row, kind)[:2])
        w.drive()
        return w

    def test_walk_one_pr_with_three_cuts(self):
        self.cut_rows = []
        straight = self.walk()
        rc, lines, reviews = straight.end()
        self.assertEqual((rc, lines), (0, ["관문 · 열림"]))
        self.assertEqual(reviews, [
            (1, "premerge", "닫힘", "재리뷰로 이어짐", "base", "c1", "얻음",
             (("막는 지적", FINDING_1, "고친 커밋 fix1"), ("막는 지적", FINDING_2, "고친 커밋 fix1")),
             (("impl-w1", "옮김"),)),
            (2, "recheck", "닫힘", "막는 지적 없음", "c1", "fix1", "얻음", (), ())])
        for cut in ("sending", "returned", "rechecked"):
            with self.subTest(cut=cut):
                self.assertEqual(self.walk(cut).end(), (rc, lines, reviews))
        self.assertEqual([x[0].split(" · ")[1] for x in self.cut_rows], ["보냄", "기다린다", "보냄"])

    # ------------------------------------------------------------ 문서의 펜스

    def doc_fences(self):
        """`qg-review.md` 의 펜스 안에서 `qg_review_state.py` 를 부르는 줄 — 문서 차례로."""
        out, inside = [], False
        for line in QG_DOC.read_text(encoding="utf-8").split("\n"):
            if line.startswith("```"):
                inside = not inside
            elif inside and "qg_review_state.py" in line:
                out.append(line)
        return out

    def test_walk_doc_fences_run(self):
        w = Walk(self)
        handling = w.rig.resource_dir("report", EPIC) / "handling-premerge-pr12-1.md"
        input_file = w.rig.t / "input-doc.json"
        input_file.write_text(json.dumps({"items": [{"kind": "return", "worker": "impl-w1",
                                                     "handling_file": str(handling)}]}, ensure_ascii=False),
                              encoding="utf-8")
        values = {"<SD>": str(PLUGIN), "<로드맵>": ROADMAP, "<대상>": TARGET, "<에픽 worktree>": str(w.rig.repo),
                  "<설계문서>": SPEC, "<살아 있는 담당자 이름>": "qg-w9", "<자리>": "premerge", "<바탕>": BASE,
                  "<리뷰받는 브랜치>": HEAD, "<에픽>": EPIC, "<세션>": SESSION, "<이름>": "qg-w1",
                  "<입력 파일>": str(input_file)}
        # 이 걸음에서 명령마다 나와야 하는 종료 코드 — 문서가 적은 종료 코드 문장과의 대조는 손으로 한다
        walk_rc = {"next": 0, "open": 0, "send": 0, "back": 0, "record": 0, "gate": 1, "render": 0}

        def before(cmd, argv):
            """펜스 사이에 바깥에서 일어나는 일 — 보내기 전 잠금 확인 · qg 담당자의 파일."""
            if cmd == "send" and "start" in argv:
                w.suite_lock_free()
            if cmd == "back":
                w.folders[1] = [p.parent for p in w.rig.report_root.glob("*/" + F.STATE_NAME)][0]
                w.qg_finishes(1)

        ran = []
        for line in self.doc_fences():
            argv = shlex.split(self.fill(line, values))
            self.assertTrue(argv[0].startswith("python"), line)
            argv = [sys.executable] + argv[1:]
            self.assertFalse([x for x in argv if "<" in x or ">" in x], argv)
            cmd = argv[2]
            before(cmd, argv)
            proc = subprocess.run(argv, cwd=str(w.rig.repo), env=dict(os.environ, **GIT_ENV),
                                  capture_output=True, encoding="utf-8")
            ran.append((cmd, proc.returncode))
            self.assertEqual(proc.returncode, walk_rc[cmd], (line, proc.stdout, proc.stderr))
        self.assertEqual([c for c, _rc in ran],
                         ["next", "open", "send", "send", "back", "record", "gate", "render"])
        self.assertEqual(set(c for c, _rc in ran), set(Q.COMMANDS))
        rv = w.reviews()[-1]
        self.assertEqual((rv.stage, [(x.worker, x.moved) for x in rv.returns]), ("돌아옴", [("impl-w1", "아직")]))

    @staticmethod
    def fill(line, values):
        """자리 표시를 값으로 — 따옴표로 싼 `"<SD>"` 는 따옴표째, 나머지는 셸 따옴표를 씌워 바꾼다."""
        line = line.replace('"<SD>"', shlex.quote(values["<SD>"]))
        for key, value in values.items():
            line = line.replace(key, shlex.quote(value))
        return line

    # ------------------------------------------------------------ 여러 줄 지적의 접은 줄

    def test_folded_finding_line_accepted(self):
        w = Walk(self)
        text = QG_DOC.read_text(encoding="utf-8")
        para = [x for x in text.split("\n") if x.startswith("**여러 줄 지적을 지휘 기록에.**")]
        self.assertEqual(len(para), 1)
        tail = re.search("끝에 「(…\\(전문: <보관 폴더 이름>의 지적 목록\\))」", para[0])
        self.assertIsNotNone(tail, para[0])
        finding = "IMPORTANT src/a.py:2 — 이름이 틀렸다\n  고칠 방법: b 를 c 로\n  둘째 줄"
        folded = finding.split("\n")[0] + tail.group(1).replace("<보관 폴더 이름>", "qg-E1-premerge-pr12-2026-11-26")
        self.assertEqual(folded, "IMPORTANT src/a.py:2 — 이름이 틀렸다…(전문: qg-E1-premerge-pr12-2026-11-26의 지적 목록)")
        spec = w.rig.repo / SPEC
        before = spec.read_bytes()
        rc, out = w.rig.ledger("record", "--spec", str(spec), "--line", finding)
        self.assertEqual(rc, 2, out)
        self.assertEqual(spec.read_bytes(), before)
        rc, out = w.rig.ledger("record", "--spec", str(spec), "--line", folded)
        self.assertEqual(rc, 0, out)
        lines = spec.read_text(encoding="utf-8").split("\n")
        record = lines[lines.index("## 지휘 기록") + 1:]
        self.assertEqual([x for x in record if x.startswith("- ")],
                         ["- 결정 · 2026-11-25 · 이대로 간다", "- " + folded])


if __name__ == "__main__":
    unittest.main()
