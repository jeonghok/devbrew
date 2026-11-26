#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""qg_review_state.py — 기준 커밋 · 범위 · 세는 수와 상한 · 「열기」 · 「보냄」 · 「돌아옴」 · 「답 적기」 와 닫는 조건 ·
「관문」 · 「다음」(AC2 · AC3 · AC4 · AC5 · AC6 · AC7 · AC8 · AC9 · AC19 · AC24 · AC25 · AC26 · AC27 · AC32 · AC33).

Run: cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_qg_review_state -v
"""
from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import qg_review_file as F  # noqa: E402
import qg_review_state as Q  # noqa: E402
from qg_review_state_fixture import BASE, EPIC, HEAD, ROADMAP, SESSION, Rig  # noqa: E402

TARGET = "pr12"
SPEC = "docs/superpowers/specs/a1-design.md"
JOB = "docs/superpowers/jobs/j1"
JOB_TARGET = "j1-plan1"
AT = "2026-11-26 10:00"
LATER = "2026-11-26 11:00"
RECORD = "docs/qg-intent-answers/A1-q1.md"
NO_VERDICT = "qg 가 끝까지 돌지 못했다 — 보관한 결과에 판정이 없다"
NOTICE = "알림 · 옛 흔적이 있다 — PR 전체를 처음부터 리뷰한다"
PR_BODY_TODO = "할 일 · 사용자 차례 · 옛 PR 본문의 막는 지적과 사용자 답을 한 번 보인다"
OTHER_RANGE = "결과가 보낸 범위의 것이 아니다"
UNCOUNTABLE = "의도 점검은 셀 수 없음"
ASK_KIND_TWO = "두 번까지"
NO_YAML = "알림 · PyYAML 이 없다 — 합치기 전 지적 목록 대신 결과 파일의 고칠 목록에서 옮겼다"
OUT_OF_RANGE = "알림 · 적어 낸 고친 커밋 %s 가 범위에 없다"
UNFIXED = "고치지 않은 막는 지적"
FAILED = "지적 목록을 얻지 못함"
INTENT = "의도 점검"
STOP = "이 에픽을 멈춘다"
NO_BRANCH = "기록 브랜치 없음 — 기록 브랜치를 push 하지 못했다"
GATE_NO_QG = "관문 · 열림 — qg 리뷰 없음(quality-gates 가 설치돼 있지 않다)"
NO_QG_NOTICE = "알림 · qg 없음 인자를 쓰지 않았다 — 이 PR 에 상태 파일이 있다"


def review(site, order, start, end, target=TARGET, **kw) -> F.Review:
    return F.Review(site=site, site_tag="%s-%s" % (site, target), target=target, order=order,
                    range_start=start, range_end=end, **kw)


def obtained(start, end, kind="얻음") -> F.Result:
    return F.Result(kind=kind, seen_range="%s..%s" % (start, end))


def failed() -> F.Result:
    return F.Result(kind="얻지 못함", reason=NO_VERDICT)


def finding(text, handling=F.NO_HANDLING) -> F.Finding:
    return F.Finding(kind="막는 지적", text=text, handling=handling)


def answer(ident, kind, value, record="") -> F.Answer:
    return F.Answer(id=ident, kind=kind, answer=value, at=AT, record=record)


def ask(kind, ident, text="질문") -> F.Ask:
    return F.Ask(kind=kind, id=ident, text=text)


def item_answer(question, ask_kind, value, original=""):
    return {"kind": "answer", "question": question, "ask_kind": ask_kind, "value": value,
            "original": original}


class TestQgReviewState(unittest.TestCase):
    def setUp(self):
        self.rig = Rig(self)
        self.base_sha = self.rig.sha()
        self.n = 1
        self.c1 = self.rig.commit({SPEC: "# A1 설계\n", "src/a.py": "a = 1\nb = 1\n"}, "impl 1")

    # ------------------------------------------------------------ 도우미

    def code(self, msg="fix") -> str:
        self.n += 1
        return self.rig.commit({"src/a.py": "a = %d\n" % self.n}, "%s %d" % (msg, self.n))

    def spec_only(self) -> str:
        self.n += 1
        return self.rig.commit({SPEC: "# A1 설계\n\n지휘 기록 %d\n" % self.n}, "spec %d" % self.n)

    def put(self, rv: F.Review) -> Path:
        folder = self.rig.archive("qg-%s-%s-built-%d" % (EPIC, rv.site_tag, rv.order))
        F.write_review(folder / F.STATE_NAME, rv)
        return folder

    def reviews(self, target=TARGET):
        return F.reviews_for(self.rig.report_root, target)

    def count(self) -> int:
        return len(list(self.rig.report_root.glob("*/" + F.STATE_NAME)))

    def open(self, site, *extra, target=TARGET, exclude=("--spec", SPEC)):
        return self.rig.run("open", "--roadmap", ROADMAP, "--target", target, "--repo", str(self.rig.repo),
                            "--at", AT, *exclude, "--site", site, "--base", BASE, "--head", HEAD,
                            "--epic", EPIC, "--session", SESSION, *extra)

    def ok(self, proc):
        self.assertEqual(proc.returncode, 0, "rc=%d\nstdout:\n%s\nstderr:\n%s"
                         % (proc.returncode, proc.stdout, proc.stderr[-1500:]))
        return proc.stdout.splitlines()

    def refused(self, proc, rc=4):
        self.assertEqual(proc.returncode, rc, "rc=%d\nstdout:\n%s\nstderr:\n%s"
                         % (proc.returncode, proc.stdout, proc.stderr[-1500:]))
        lines = proc.stdout.splitlines()
        self.assertTrue(lines and lines[0].startswith("까닭 · "), proc.stdout)
        return lines

    def folder_of(self, lines) -> Path:
        self.assertTrue(lines[0].startswith("보관 폴더 · "), lines)
        return Path(lines[0][len("보관 폴더 · "):])

    def closed_rereview(self, handling) -> F.Review:
        return review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="재리뷰로 이어짐",
                      worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1),
                      blocking=[finding("지적 1 — src/a.py 의 값", handling)])

    # ------------------------------------------------------------ 기준 커밋

    def test_base_commits_old_format(self):
        start = self.c1
        only_spec = self.spec_only()
        only_code = self.code()
        both = self.rig.commit({SPEC: "# A1 설계\n\n고침\n", "src/b.py": "b = 1\n"}, "both")
        got = Q.base_commits(self.rig.repo, start, self.rig.sha(), Q.exclusions(spec=SPEC))
        self.assertEqual(set(got), {only_code, both})
        self.assertNotIn(only_spec, got)
        self.assertEqual(Q.base_commits(self.rig.repo, start, only_spec, Q.exclusions(spec=SPEC)), [])

    def test_base_commits_team_format(self):
        start = self.rig.sha()
        review_file = self.rig.commit({JOB + "/results/review-1.md": "# 검수\n"}, "review")
        intent = self.rig.commit({JOB + "/INTENT.md": "# 의도\n\n## 결정 기록\n"}, "intent")
        impl = self.rig.commit({JOB + "/results/impl-2.md": "## 지적마다의 처리\n\n- 1 · 반박\n"}, "impl")
        design = self.rig.commit({JOB + "/design.md": "# 과제 설계\n"}, "design")
        got = Q.base_commits(self.rig.repo, start, self.rig.sha(), Q.exclusions(job_dir=JOB))
        self.assertEqual(set(got), {impl, design})
        self.assertFalse({review_file, intent} & set(got))

    def test_recheck_start_is_last_obtained_end(self):
        c2, c3 = self.code(), self.code()
        first = review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="재리뷰로 이어짐",
                       result=obtained(self.base_sha, self.c1))
        lost = review("recheck", 2, self.c1, c2, stage="닫힘", close_reason="다시 보냄", result=failed())
        opened = review("recheck", 3, self.c1, c3)
        self.assertEqual(Q.recheck_start([first, lost, opened]), self.c1)
        nothing = review("recheck", 2, self.c1, c2, stage="닫힘", close_reason="막는 지적 없음",
                         result=obtained(self.c1, c2, kind="리뷰할 것 없음"))
        self.assertEqual(Q.recheck_start([first, nothing, opened]), c2)
        self.assertIsNone(Q.recheck_start([opened]))

    def test_merge_commit_widens_to_whole_pr(self):
        c2 = self.code()
        self.put(self.closed_rereview("고친 커밋 " + c2))
        tip = self.rig.merge_commit()
        self.assertTrue(Q.has_merge(self.rig.repo, self.c1, tip))
        self.assertFalse(Q.has_merge(self.rig.repo, self.base_sha, self.c1))
        lines = self.ok(self.open("recheck"))
        new = self.reviews()[-1]
        merge_base = self.rig.git("merge-base", BASE, HEAD)
        self.assertEqual((new.site, new.order, new.range_start, new.range_end),
                         ("recheck", 2, merge_base, tip))
        self.assertIn("범위 · %s..%s" % (merge_base, tip), lines)
        new.stage, new.close_reason = "닫힘", "막는 지적 없음"
        new.result = obtained(merge_base, tip)
        F.write_review(self.folder_of(lines) / F.STATE_NAME, new)
        self.assertEqual(Q.counted_rechecks(self.reviews()), 1)

    def test_recheck_refused_without_base_commit(self):
        self.put(self.closed_rereview("반박 — 설계가 그렇게 정했다"))
        self.spec_only()
        before = self.count()
        self.refused(self.open("recheck"))
        self.assertEqual(self.count(), before)
        tip = self.code()
        lines = self.ok(self.open("recheck"))
        self.assertIn("범위 · %s..%s" % (self.c1, tip), lines)
        self.assertEqual(self.count(), before + 1)

    # ------------------------------------------------------------ 세는 수와 상한

    def test_cap_counts_only_obtained_rechecks(self):
        c2 = self.code()
        first = review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="재리뷰로 이어짐",
                       result=obtained(self.base_sha, self.c1))
        lost = review("recheck", 2, self.c1, c2, stage="닫힘", close_reason="다시 보냄", result=failed())
        got = review("recheck", 3, self.c1, c2, stage="닫힘", close_reason="재리뷰로 이어짐",
                     result=obtained(self.c1, c2))
        asked = review("asked", 1, self.base_sha, self.c1, stage="닫힘", close_reason="재리뷰로 이어짐",
                       result=obtained(self.base_sha, self.c1))
        self.assertEqual(Q.counted_rechecks([first, lost, got]), 1)
        self.assertEqual(Q.cap([first, lost, got]), 2)
        self.assertEqual(Q.counted_rechecks([asked, got]), 1)
        self.assertEqual(Q.counted_rechecks([first, asked]), 0)

        more = [answer("q-cap", "두 번까지", "한 번 더 돌려보낸다")]
        second = review("recheck", 4, self.c1, c2, stage="닫힘", close_reason="재리뷰로 이어짐",
                        result=obtained(self.c1, c2), answers=more)
        third = review("recheck", 5, self.c1, c2, stage="닫힘", close_reason="재리뷰로 이어짐",
                       result=obtained(self.c1, c2))
        self.assertEqual(Q.counted_rechecks([first, got, second]), 2)
        self.assertEqual(Q.cap([first, got, second]), 3)
        self.assertEqual(Q.cap([first, got, second, third]), 3)
        third.answers = list(more)
        self.assertEqual(Q.cap([first, got, second, third]), 4)
        left = review("recheck", 5, self.c1, c2, stage="닫힘", close_reason="사용자가 남김",
                      result=obtained(self.c1, c2),
                      answers=[answer("q-cap", "두 번까지", "남은 지적을 적고 머지 준비로 간다")])
        self.assertEqual(Q.cap([first, got, left]), 2)

        marked = review("premerge", 6, self.base_sha, c2, stage="닫힘", close_reason=F.REASON_DESIGN,
                        close_mark="%s %s" % (F.MARK_REIMPLEMENTED, LATER), result=obtained(self.base_sha, c2),
                        answers=[answer("q1", "의도 점검", "잘못 골랐다", RECORD)])
        again = review("premerge", 7, self.base_sha, c2, stage="닫힘", close_reason="재리뷰로 이어짐",
                       result=obtained(self.base_sha, c2))
        after = review("recheck", 8, c2, c2, stage="닫힘", close_reason="재리뷰로 이어짐",
                       result=obtained(c2, c2))
        chain = [first, got, second, third, marked, again, after]
        self.assertEqual(Q.counting_from(chain), [again, after])
        self.assertEqual(Q.counted_rechecks(chain), 1)
        self.assertEqual(Q.cap(chain), 2)

    def test_named_review_does_not_replace_first(self):
        self.put(review("asked", 1, self.base_sha, self.c1, stage="닫힘", close_reason="막는 지적 없음",
                        worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1)))
        self.assertEqual(self.gate_reasons(), [8])  # 이름으로 청한 리뷰만 닫혀 있으면 관문은 첫 리뷰 없음으로 닫힌다
        tip = self.code()
        lines = self.ok(self.open("premerge"))
        new = self.reviews()[-1]
        self.assertEqual((new.site, new.order, new.range_start, new.range_end),
                         ("premerge", 2, self.base_sha, tip))
        self.assertIn("자리 글자 · premerge-%s" % TARGET, lines)

    def test_open_refused_while_last_not_closed(self):
        folder = self.put(review("premerge", 1, self.base_sha, self.c1, stage="돌아옴",
                                 worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1),
                                 blocking=[finding("지적 1")]))
        before = self.count()
        for site in ("asked", "premerge", "recheck"):
            self.refused(self.open(site))
            self.assertEqual(self.count(), before, site)
        F.write_review(folder / F.STATE_NAME,
                       review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="막는 지적 없음",
                              worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1)))
        lines = self.ok(self.open("asked"))
        self.assertIn("자리 글자 · asked", lines)
        self.assertEqual(self.count(), before + 1)

    # ------------------------------------------------------------ 옛 흔적

    def test_legacy_traces_open_whole_pr(self):
        tip = self.code()
        whole = "범위 · %s..%s" % (self.base_sha, tip)

        with self.subTest(trace="없음"):
            self.rig.archive("qg-%s-premerge-%s3-2026-11-20" % (EPIC, TARGET))  # 다른 PR(pr123)
            self.rig.archive("qg-%s-premerge-pr1-2026-11-20" % EPIC)            # 다른 PR(pr1)
            lines = self.ok(self.open("premerge"))
            self.assertEqual(lines[1:], [whole, "자리 글자 · premerge-" + TARGET])

        for trace in ("folder", "pr-body", "ledger"):
            with self.subTest(trace=trace):
                self.setUp()
                tip = self.code()
                whole = "범위 · %s..%s" % (self.base_sha, tip)
                extra = ()
                if trace == "folder":
                    old = self.rig.archive("qg-%s-premerge-%s-2026-11-20" % (EPIC, TARGET))
                    (old / "result.md").write_text("# qg result\n", encoding="utf-8")
                else:
                    extra = ("--legacy-trace", trace)
                lines = self.ok(self.open("premerge", *extra))
                want = [whole, "자리 글자 · premerge-" + TARGET, NOTICE]
                if trace == "pr-body":
                    want.append(PR_BODY_TODO)
                self.assertEqual(lines[1:], want)
                new = self.reviews()[-1]
                self.assertEqual((new.order, new.range_start, new.range_end), (1, self.base_sha, tip))

    # ------------------------------------------------------------ 보관 폴더

    def test_open_same_day_gets_suffix(self):
        first = self.folder_of(self.ok(self.open("premerge")))
        self.assertEqual(first.name, "qg-%s-premerge-%s-2026-11-26" % (EPIC, TARGET))
        (first / "result.md").write_text("# 앞 리뷰\n", encoding="utf-8")
        rv = F.read_review(first / F.STATE_NAME)
        rv.stage, rv.close_reason, rv.worker, rv.result = "닫힘", "다시 보냄", "qg-w1 · " + AT, failed()
        rv.answers = [answer("q-failed", "지적 목록을 얻지 못함", "다시 보낸다")]
        F.write_review(first / F.STATE_NAME, rv)
        self.code()  # 끝이 움직여도 다시 보냄은 같은 범위다
        lines = self.ok(self.open("premerge"))
        second = self.folder_of(lines)
        self.assertEqual(second.name, first.name + "-2")
        self.assertEqual((first / "result.md").read_text(encoding="utf-8"), "# 앞 리뷰\n")
        self.assertEqual(F.read_review(first / F.STATE_NAME), rv)
        new = self.reviews()[-1]
        self.assertEqual((new.order, new.range_start, new.range_end), (2, rv.range_start, rv.range_end))

    def test_open_writes_resource_line(self):
        folder = self.folder_of(self.ok(self.open("premerge")))
        rc, out = self.rig.ledger("resources", "--roadmap", ROADMAP)
        self.assertEqual(rc, 0, out)
        rows = [line.split(" · ") for line in out.splitlines()]
        mine = [r for r in rows if len(r) == 5 and r[1] == str(folder)]
        self.assertEqual(len(mine), 1, out)
        self.assertEqual((mine[0][0], mine[0][2], mine[0][4]), ("qg 보관", EPIC, AT))

    def test_reopen_after_design_mark(self):
        folder = self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘",
                                 close_reason=F.REASON_DESIGN, worker="qg-w1 · " + AT,
                                 result=obtained(self.base_sha, self.c1),
                                 answers=[answer("q1", "의도 점검", "잘못 골랐다", RECORD)]))
        self.spec_only()  # 고친 설계문서 커밋 — 표시 전에는 열지 않는다
        before = self.count()
        for site in ("premerge", "recheck"):
            self.refused(self.open(site))
        self.assertEqual(self.count(), before)
        rv = F.read_review(folder / F.STATE_NAME)
        rv.close_mark = "%s %s" % (F.MARK_REIMPLEMENTED, LATER)
        F.write_review(folder / F.STATE_NAME, rv)
        tip = self.code("reimpl")
        self.refused(self.open("recheck"))
        self.ok(self.open("premerge"))
        new = self.reviews()[-1]
        self.assertEqual((new.site, new.order, new.range_start, new.range_end),
                         ("premerge", 2, self.base_sha, tip))

    # ------------------------------------------------------------ 명령줄

    def test_team_target_uses_job_dir(self):
        lines = self.ok(self.open("premerge", target=JOB_TARGET, exclude=("--job-dir", JOB)))
        self.assertIn("자리 글자 · premerge-" + JOB_TARGET, lines)
        self.assertEqual(self.reviews(JOB_TARGET)[-1].target, JOB_TARGET)
        self.assertEqual(self.open("premerge", target=JOB_TARGET).returncode, 2)
        self.assertEqual(self.open("premerge", exclude=("--job-dir", JOB)).returncode, 2)

    def test_usage_and_unreadable(self):
        self.assertEqual(self.open("premerge", exclude=()).returncode, 2)
        self.assertEqual(self.open("premerge", "--spec", "/abs/a.md", exclude=()).returncode, 2)
        self.assertEqual(self.open("premerge", target="pr0").returncode, 2)
        folder = self.rig.archive("qg-%s-premerge-%s-built-1" % (EPIC, TARGET))
        text = F.render(review("premerge", 1, self.base_sha, self.c1))
        (folder / F.STATE_NAME).write_text(text.replace("- 단계: 열림", "- 단계: 도는 중"), encoding="utf-8")
        before = self.count()
        for site in ("premerge", "recheck", "asked"):
            self.refused(self.open(site), rc=3)
        self.assertEqual(self.count(), before)

    def test_inconsistent_state_refused(self):
        self.code()
        cases = {
            "재리뷰로 이어짐인데 처리 없음": self.closed_rereview(F.NO_HANDLING),
            "의도 점검 답의 기록 경로 빔": review(
                "asked", 1, self.base_sha, self.c1, stage="닫힘", close_reason="막는 지적 없음",
                result=obtained(self.base_sha, self.c1), answers=[answer("q1", "의도 점검", "의도다")]),
            "앞 리뷰가 닫히지 않음": None,
        }
        for label, rv in cases.items():
            with self.subTest(case=label):
                self.setUp()
                self.code()
                if rv is None:
                    self.put(review("asked", 1, self.base_sha, self.c1, stage="보냄", worker="qg-w1 · " + AT))
                    self.put(review("asked", 2, self.base_sha, self.c1, stage="닫힘", close_reason="막는 지적 없음",
                                    result=obtained(self.base_sha, self.c1)))
                else:
                    self.put(rv)
                before = self.count()
                for site in ("premerge", "recheck", "asked"):
                    lines = self.refused(self.open(site))
                    self.assertIn("칸끼리 맞지 않는다", lines[0])
                self.assertEqual(self.count(), before)

    # ------------------------------------------------------------ 보냄 · 돌아옴

    def sent(self, site="premerge", order=1, start=None, end=None, stage="보냄", **kw) -> Path:
        """보낸 리뷰 하나를 짓고 그 보관 폴더를 낸다 — 기본은 첫 리뷰(PR 전체 base..c1)."""
        start = self.base_sha if start is None else start
        end = self.c1 if end is None else end
        worker = "qg-w%d · %s" % (order, AT) if stage == "보냄" else ""
        return self.put(review(site, order, start, end, stage=stage, worker=worker, **kw))

    def back(self, env=None):
        return self.rig.run("back", "--roadmap", ROADMAP, "--target", TARGET, "--repo", str(self.rig.repo),
                            "--at", LATER, env=env)

    def send(self, phase, worker=None):
        extra = () if worker is None else ("--worker", worker)
        return self.rig.run("send", "--roadmap", ROADMAP, "--target", TARGET, "--repo", str(self.rig.repo),
                            "--at", AT, "--phase", phase, *extra)

    def came_back(self, env=None):
        lines = self.ok(self.back(env))
        self.assertTrue(lines and lines[0].startswith("할 일 · "), lines)
        return self.reviews()[-1], lines

    def test_back_obtained(self):
        folder = self.sent()
        fix = "IMPORTANT src/a.py:1 — 값이 틀렸다 · 고칠 방법: 1 로 되돌린다"
        broken = "tests/test_a.py::test_x · NEW_REGRESSION — 고칠 방법: 값을 맞춘다"
        self.rig.write_result(folder, "defect", self.base_sha, self.c1, blocking=[fix], regress=[broken])
        self.rig.write_pre_merge(folder, [
            {"file": "src/a.py", "line": 1, "severity": "IMPORTANT", "summary": "값이 틀렸다",
             "proposed_fix": "1 로 되돌린다"},
            {"file": "src/a.py", "line": 2, "severity": "SUGGESTION", "summary": "이름을 바꾼다",
             "proposed_fix": "b 를 c 로"}])
        self.rig.write_intent_return(folder, [])
        rv, _lines = self.came_back()
        self.assertEqual((rv.stage, rv.close_reason, rv.worker), ("돌아옴", "", "qg-w1 · " + AT))
        self.assertEqual((rv.result.kind, rv.result.reason), ("얻음", ""))
        self.assertEqual(rv.result.seen_range, "%s..%s" % (self.base_sha, self.c1))
        self.assertTrue(rv.result.verdict_line.startswith("qg: defect · 막는 지적 1 "), rv.result.verdict_line)
        self.assertEqual(rv.result.intent_line, "intent-critic — 질문 0개")
        self.assertEqual([(f.kind, f.text, f.handling) for f in rv.blocking],
                         [("막는 지적", fix, F.NO_HANDLING), ("새로 깨진 테스트", broken, F.NO_HANDLING)])
        self.assertEqual((rv.asks, rv.filtered_wrong, rv.filtered_other), ([], [], []))

    def test_back_no_result_md(self):
        for stage in ("보냄", "보내는 중"):
            with self.subTest(stage=stage):
                self.setUp()
                folder = self.sent(stage=stage)
                (folder / "handler-report.md").write_text("# 담당자 보고\n", encoding="utf-8")
                rv, _lines = self.came_back()
                self.assertEqual((rv.stage, rv.result.kind, rv.result.reason), ("돌아옴", "얻지 못함", NO_VERDICT))
                self.assertEqual(rv.asks, [F.Ask(kind="지적 목록을 얻지 못함", id="q-failed", text=NO_VERDICT)])
                self.assertEqual(rv.blocking, [])

    def test_back_no_verdict(self):
        folder = self.sent()
        self.rig.write_result(folder, None, self.base_sha, self.c1, blocking=["IMPORTANT src/a.py:1 — 값"])
        self.rig.write_pre_merge(folder, [{"file": "src/a.py", "line": 1, "severity": "IMPORTANT",
                                           "summary": "값"}])
        self.rig.write_intent_return(folder, [{"id": "q1", "state": "묻지 않음", "question": "이것이 맞나"}])
        rv, _lines = self.came_back()
        self.assertEqual((rv.stage, rv.result.kind, rv.result.reason), ("돌아옴", "얻지 못함", NO_VERDICT))
        self.assertEqual((rv.blocking, [a.kind for a in rv.asks]), ([], ["지적 목록을 얻지 못함"]))

    def test_back_range_mismatch(self):
        for label in ("끝이 다르다", "시작이 다르다", "범위 절이 없다", "범위가 비었다"):
            with self.subTest(case=label):
                self.setUp()
                tip = self.code()
                folder = self.sent(end=tip)  # 보낸 범위 base..tip
                start, end = {"끝이 다르다": (self.base_sha, self.c1), "시작이 다르다": (self.c1, tip),
                              "범위 절이 없다": (None, None), "범위가 비었다": ("-", "-")}[label]
                self.rig.write_result(folder, "defect", start, end, blocking=["IMPORTANT src/a.py:1 — 값"],
                                      filtered=[("q9", "방향")], wrong=[("q9", "방향")])
                self.rig.write_intent_return(folder, [{"id": "q1", "state": "묻지 않음", "question": "맞나"}])
                rv, _lines = self.came_back()
                self.assertEqual((rv.stage, rv.result.kind, rv.result.reason),
                                 ("돌아옴", "얻지 못함", OTHER_RANGE))
                self.assertEqual((rv.blocking, rv.filtered_wrong, rv.filtered_other), ([], [], []))
                self.assertEqual([a.kind for a in rv.asks], ["지적 목록을 얻지 못함"])
                self.assertEqual(rv.asks[0].text, OTHER_RANGE)

    def test_back_trivia_closes_zero(self):
        for verdict in ("not-certified (trivia)", "not-certified (scope-empty)"):
            with self.subTest(verdict=verdict):
                self.setUp()
                folder = self.sent()
                self.rig.write_result(folder, verdict, self.base_sha, self.c1)
                self.rig.write_intent_return(folder, [], status="skipped", reason="trivia", outcome="-")
                rv, _lines = self.came_back()
                self.assertEqual((rv.stage, rv.close_reason, rv.result.kind),
                                 ("닫힘", "막는 지적 없음", "리뷰할 것 없음"))
                self.assertEqual((rv.blocking, rv.asks), ([], []))
                self.assertTrue(rv.result.verdict_line.startswith("qg: " + verdict), rv.result.verdict_line)
        with self.subTest(verdict="not-certified (kill-switch) 는 리뷰할 것 없음이 아니다"):
            self.setUp()
            folder = self.sent()
            self.rig.write_result(folder, "not-certified (kill-switch)", self.base_sha, self.c1)
            self.rig.write_intent_return(folder, [])
            rv, _lines = self.came_back()
            self.assertEqual((rv.result.kind, rv.stage, rv.close_reason), ("얻음", "닫힘", "막는 지적 없음"))

    def test_back_range_from_result_scope_when_intent_blank(self):
        heads = {"비었다": ("-", "-"), "다른 커밋을 말한다": (self.base_sha, self.base_sha)}
        for label, (head, base) in heads.items():
            with self.subTest(intent=label):
                self.setUp()
                folder = self.sent()
                self.rig.write_result(folder, "defect", self.base_sha, self.c1,
                                      blocking=["IMPORTANT src/a.py:1 — 값"])
                self.rig.write_intent_return(folder, [], reviewed_head=head, reviewed_base=base)
                rv, _lines = self.came_back()
                self.assertEqual((rv.result.kind, rv.stage), ("얻음", "돌아옴"))
                self.assertEqual([f.text for f in rv.blocking], ["IMPORTANT src/a.py:1 — 값"])

    def test_back_moves_originals_without_pr_body(self):
        rows = [("src/a.py", 3, "CRITICAL", "## 머리 줄처럼 보이는 요약 · 가운뎃점", "``` 펜스를 닫는다"),
                ("src/b.py", 7, "IMPORTANT", "- 맨 앞 줄표로 시작하는 요약", None)]
        fixes = ["%s %s:%d — %s · 고칠 방법: %s" % (sev, path, line, summary, fix or "(없음)")
                 for path, line, sev, summary, fix in rows]
        broken = ["tests/test_b.py::test_y · NEW_TEST_RED — 고칠 방법: 기대값"]
        findings = [dict({"agent": "security-reviewer", "file": path, "line": line, "severity": sev,
                          "summary": summary}, **({"proposed_fix": fix} if fix else {}))
                    for path, line, sev, summary, fix in rows]
        findings.append({"file": "src/c.py", "line": 1, "severity": "SUGGESTION", "summary": "제안"})
        got = {}
        for source in ("합치기 전 지적 목록", "고칠 목록"):
            with self.subTest(source=source):
                self.setUp()
                folder = self.sent()
                self.rig.write_result(folder, "defect", self.base_sha, self.c1, blocking=fixes, regress=broken)
                self.rig.write_intent_return(folder, [])
                if source == "합치기 전 지적 목록":
                    self.rig.write_pre_merge(folder, findings)
                rv, lines = self.came_back()
                self.assertNotIn(NO_YAML, lines)
                got[source] = [(f.kind, f.text) for f in rv.blocking]
                self.assertEqual(got[source], [("막는 지적", t) for t in fixes] + [("새로 깨진 테스트", broken[0])])
        with self.subTest(source="합치기 전 목록의 겹친 지적은 합치지 않는다"):
            self.setUp()
            folder = self.sent()
            self.rig.write_result(folder, "defect", self.base_sha, self.c1, blocking=fixes[:1])
            self.rig.write_pre_merge(folder, findings[:1] * 2)
            self.rig.write_intent_return(folder, [])
            rv, _lines = self.came_back()
            self.assertEqual([f.text for f in rv.blocking], fixes[:1] * 2)
        with self.subTest(source="합치기 전 목록의 꼴이 틀렸다"):
            self.setUp()
            folder = self.sent()
            self.rig.write_result(folder, "defect", self.base_sha, self.c1, blocking=fixes[1:])
            (folder / "findings-pre-merge.yaml").write_text("findings: {not: [a list\n", encoding="utf-8")
            self.rig.write_intent_return(folder, [])
            rv, _lines = self.came_back()
            self.assertEqual([f.text for f in rv.blocking], fixes[1:])

    def test_back_filtered_lists_split(self):
        folder = self.sent()
        self.rig.write_result(folder, "clean", self.base_sha, self.c1,
                              filtered=[("q1", "가가"), ("q2", "나나"), ("q3", "다다")], wrong=[("q2", "나나")])
        self.rig.write_intent_return(folder, [], answered_filtered=3)
        rv, _lines = self.came_back()
        self.assertEqual([(x.id, x.text, x.dest) for x in rv.filtered_wrong], [("q2", "나나", "")])
        self.assertEqual([(x.id, x.text) for x in rv.filtered_other],
                         [("q1", "의도다 · docs/qg-intent-answers/q1.md — 가가"),
                          ("q3", "의도다 · docs/qg-intent-answers/q3.md — 다다")])

    def test_back_intent_only_unasked(self):
        folder = self.sent()
        self.rig.write_result(folder, "clean", self.base_sha, self.c1, over=[("q2", "상한 넘은 질문")])
        self.rig.write_intent_return(folder, [
            {"id": "q1", "state": "묻지 않음", "question": "이 기능이 정말 필요한가"},
            {"id": "q2", "state": "상한 넘어 남김", "question": "상한 넘은 질문"},
            {"id": "q3", "state": "답함", "question": "답한 질문", "answer": "의도다"},
            {"id": "q4", "state": "묻지 않음", "question": "이름이 맞나"}])
        rv, _lines = self.came_back()
        self.assertEqual(rv.asks, [F.Ask(kind="의도 점검", id="q1", text="이 기능이 정말 필요한가"),
                                   F.Ask(kind="의도 점검", id="q4", text="이름이 맞나")])
        self.assertEqual((rv.stage, rv.result.intent_line), ("돌아옴", "intent-critic — 질문 4개"))

    def test_back_intent_unreadable_does_not_block(self):
        cases = ("없다", "판이 2", "펜스가 없다", "YAML 이 깨졌다")
        for label in cases:
            for blocking in ((), ("IMPORTANT src/a.py:1 — 값",)):
                with self.subTest(case=label, blocking=bool(blocking)):
                    self.setUp()
                    folder = self.sent()
                    self.rig.write_result(folder, "defect" if blocking else "clean", self.base_sha, self.c1,
                                          blocking=blocking)
                    path = folder / "intent-return.md"
                    if label == "판이 2":
                        self.rig.write_intent_return(folder, [{"id": "q1", "state": "묻지 않음", "question": "가"}],
                                                     contract=2)
                    elif label == "펜스가 없다":
                        path.write_text("contract: 3\nquestions: []\n", encoding="utf-8")
                    elif label == "YAML 이 깨졌다":
                        path.write_text("```qg-intent-return\ncontract: 3\nquestions: [\n```\n", encoding="utf-8")
                    rv, lines = self.came_back()
                    self.assertEqual((rv.result.kind, rv.result.intent_line), ("얻음", UNCOUNTABLE))
                    self.assertTrue(any(UNCOUNTABLE in x for x in lines), lines)
                    self.assertEqual(rv.asks, [])
                    want = ("돌아옴", "") if blocking else ("닫힘", "막는 지적 없음")
                    self.assertEqual((rv.stage, rv.close_reason), want)
                    self.assertEqual([f.text for f in rv.blocking], list(blocking))

    def test_back_closes_when_nothing(self):
        folder = self.sent()
        self.rig.write_result(folder, "clean", self.base_sha, self.c1,
                              filtered=[("q9", "방향이 맞나")], wrong=[("q9", "방향이 맞나")])
        self.rig.write_intent_return(folder, [], answered_filtered=1)
        rv, _lines = self.came_back()
        self.assertEqual((rv.stage, rv.close_reason, rv.result.kind), ("닫힘", "막는 지적 없음", "얻음"))
        self.assertEqual([x.id for x in rv.filtered_wrong], ["q9"])
        self.assertEqual(rv.filtered_other, [])
        with self.subTest(case="담당자가 옮긴 질문이 남았다 — 지우지 않고 닫지 않는다"):
            self.setUp()
            moved = F.Ask(kind="담당자가 옮긴 질문", id="w1", text="담당자가 멈춘 질문 — 이 파일을 지워도 되나")
            folder = self.sent(asks=[moved])
            self.rig.write_result(folder, "clean", self.base_sha, self.c1)
            self.rig.write_intent_return(folder, [])
            rv, _lines = self.came_back()
            self.assertEqual((rv.stage, rv.close_reason, rv.asks), ("돌아옴", "", [moved]))

    def at_cap_rechecks(self):
        """차례 1(첫 리뷰) · 2(좁은 재리뷰 하나) — 재리뷰로 이어짐으로 닫힘. (c2, c3) 를 낸다."""
        c2 = self.code()
        self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="재리뷰로 이어짐",
                        worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1),
                        blocking=[finding("지적 1", "고친 커밋 " + c2)]))
        c3 = self.code()
        self.put(review("recheck", 2, self.c1, c2, stage="닫힘", close_reason="재리뷰로 이어짐",
                        worker="qg-w2 · " + AT, result=obtained(self.c1, c2),
                        blocking=[finding("지적 2", "고친 커밋 " + c3)]))
        return c2, c3

    def test_back_at_cap_adds_two_max(self):
        cases = {"상한에 닿음": ("defect", (), True), "거른 「잘못 골랐다」 목록": ("defect", ("q9",), False),
                 "막는 지적 없음": ("clean", (), False)}
        for label, (verdict, wrong, asked) in cases.items():
            with self.subTest(case=label):
                self.setUp()
                c2, c3 = self.at_cap_rechecks()
                folder = self.sent("recheck", 3, c2, c3)
                blocking = ["IMPORTANT src/a.py:1 — 값"] if verdict == "defect" else []
                self.rig.write_result(folder, verdict, c2, c3, blocking=blocking,
                                      filtered=[(x, "방향") for x in wrong], wrong=[(x, "방향") for x in wrong])
                self.rig.write_intent_return(folder, [])
                rv, _lines = self.came_back()
                self.assertEqual(Q.counted_rechecks(self.reviews()), 2)
                self.assertEqual(ASK_KIND_TWO in [a.kind for a in rv.asks], asked, rv.asks)
                if asked:
                    self.assertEqual(rv.stage, "돌아옴")
                    self.assertEqual([a.id for a in rv.asks if a.kind == ASK_KIND_TWO], ["q-cap"])
        with self.subTest(case="상한 안 — 좁은 재리뷰 첫째"):
            self.setUp()
            c2 = self.code()
            self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="재리뷰로 이어짐",
                            worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1),
                            blocking=[finding("지적 1", "고친 커밋 " + c2)]))
            folder = self.sent("recheck", 2, self.c1, c2)
            self.rig.write_result(folder, "defect", self.c1, c2, blocking=["IMPORTANT src/a.py:1 — 값"])
            self.rig.write_intent_return(folder, [])
            rv, _lines = self.came_back()
            self.assertNotIn(ASK_KIND_TWO, [a.kind for a in rv.asks])

    def test_send_phases(self):
        self.refused(self.send("start"))  # 상태 파일이 없다
        self.put(review("premerge", 1, self.base_sha, self.c1))
        self.refused(self.send("done", "qg-w1"))
        self.refused(self.back())
        self.assertEqual(self.reviews()[-1].stage, "열림")
        self.ok(self.send("start"))
        self.assertEqual((self.reviews()[-1].stage, self.reviews()[-1].worker), ("보내는 중", ""))
        self.refused(self.send("start"))
        self.assertEqual(self.send("done").returncode, 2)
        self.assertEqual(self.send("done", "qg · w1").returncode, 2)
        self.ok(self.send("done", "qg-w1"))
        rv = self.reviews()[-1]
        self.assertEqual((rv.stage, rv.worker), ("보냄", "qg-w1 · " + AT))
        self.refused(self.send("start"))
        self.refused(self.send("done", "qg-w2"))
        self.assertEqual(self.send("start", "qg-w2").returncode, 2)
        self.assertEqual(self.reviews()[-1], rv)

    def test_back_without_pyyaml(self):
        blocker = self.rig.t / "no-yaml"
        blocker.mkdir()
        (blocker / "yaml.py").write_text('raise ImportError("PyYAML 을 막았다")\n', encoding="utf-8")
        folder = self.sent()
        fix = "IMPORTANT src/a.py:1 — 결과 파일의 글 · 고칠 방법: 되돌린다"
        self.rig.write_result(folder, "defect", self.base_sha, self.c1, blocking=[fix])
        self.rig.write_pre_merge(folder, [{"file": "src/a.py", "line": 9, "severity": "IMPORTANT",
                                           "summary": "합치기 전 목록의 글"}])
        self.rig.write_intent_return(folder, [{"id": "q1", "state": "묻지 않음", "question": "가"}])
        rv, lines = self.came_back(env={"PYTHONPATH": str(blocker)})
        self.assertIn(NO_YAML, lines)
        self.assertTrue(any(UNCOUNTABLE in x for x in lines), lines)
        self.assertEqual([f.text for f in rv.blocking], [fix])
        self.assertEqual((rv.result.kind, rv.result.intent_line, rv.asks), ("얻음", UNCOUNTABLE, []))


    # ------------------------------------------------------------ 답 적기 · 닫는 조건

    def record(self, items=None):
        args = ["record", "--roadmap", ROADMAP, "--target", TARGET, "--repo", str(self.rig.repo), "--at", LATER,
                "--spec", SPEC]
        if items is not None:
            self.inputs = getattr(self, "inputs", 0) + 1
            path = self.rig.t / ("input-%d.json" % self.inputs)
            path.write_text(json.dumps({"items": items}, ensure_ascii=False), encoding="utf-8")
            args += ["--input", str(path)]
        return self.rig.run(*args)

    def recorded(self, items=None):
        lines = self.ok(self.record(items))
        self.assertTrue(lines and lines[0].startswith("할 일 · "), lines)
        return self.reviews()[-1], lines

    def returned(self, order=1, start=None, end=None, site="premerge", **kw) -> Path:
        start = self.base_sha if start is None else start
        end = self.c1 if end is None else end
        kw.setdefault("result", obtained(start, end))
        return self.put(review(site, order, start, end, stage="돌아옴", worker="qg-w%d · %s" % (order, AT), **kw))

    def state_bytes(self, folder: Path) -> bytes:
        return (folder / F.STATE_NAME).read_bytes()

    def handling_file(self, n=1) -> str:
        return str(self.rig.resource_dir("report", EPIC) / ("handling-%d.md" % n))

    def ret(self, n=1, moved="아직", worker="impl-w1") -> F.ReturnLine:
        return F.ReturnLine(worker=worker, at=AT, path=self.handling_file(n), moved=moved)

    def test_close_no_blocking_after_answers(self):
        self.returned(asks=[ask(INTENT, "q1", "이 기능이 정말 필요한가")])
        rv, _lines = self.recorded([item_answer("q1", INTENT, "의도다"),
                                    {"kind": "record_path", "question": "q1", "path": RECORD}])
        self.assertEqual((rv.stage, rv.close_reason, rv.asks), ("닫힘", "막는 지적 없음", []))
        self.assertEqual([(a.id, a.kind, a.answer, a.record, a.at) for a in rv.answers],
                         [("q1", INTENT, "의도다", RECORD, LATER)])

    def two_max_returned(self):
        return self.returned(blocking=[finding("지적 1"), finding("지적 2", "반박 — 설계가 그렇게 정했다")],
                             asks=[ask(ASK_KIND_TWO, "q-cap")])

    def test_close_rereview_needs_base_commit(self):
        self.two_max_returned()
        self.code()  # 그 사이 올라온 기준 커밋
        rv, _lines = self.recorded([item_answer("q-cap", ASK_KIND_TWO, "남은 지적을 적고 머지 준비로 간다")])
        self.assertEqual([f.handling for f in rv.blocking], [F.USER_LEFT, F.USER_LEFT])
        self.assertEqual((rv.stage, rv.close_reason), ("닫힘", "재리뷰로 이어짐"))

    def test_close_rereview_waits_for_pending_return(self):
        fix = self.code()
        self.returned(blocking=[finding("지적 1", "고친 커밋 " + fix)], returns=[self.ret(1)],
                      asks=[ask(INTENT, "q1")])
        rv, _lines = self.recorded([item_answer("q1", INTENT, "의도다"),
                                    {"kind": "record_path", "question": "q1", "path": RECORD}])
        self.assertEqual((rv.stage, rv.close_reason), ("돌아옴", ""))  # 처리를 아직 옮기지 않은 「돌려보냄」 이 있다

    def test_close_user_left_without_base_commit(self):
        self.two_max_returned()
        self.spec_only()  # 리더 기록 파일만 바꾼 커밋은 기준 커밋이 아니다
        rv, _lines = self.recorded([item_answer("q-cap", ASK_KIND_TWO, "남은 지적을 적고 머지 준비로 간다")])
        self.assertEqual((rv.stage, rv.close_reason), ("닫힘", "사용자가 남김"))

    def test_close_without_review(self):
        self.returned(result=failed(), asks=[ask(FAILED, "q-failed", NO_VERDICT)])
        rv, _lines = self.recorded([item_answer("q-failed", FAILED, "리뷰 없이 머지 준비로 간다")])
        self.assertEqual((rv.stage, rv.close_reason, rv.asks), ("닫힘", "리뷰 없이 감", []))

    def test_close_resend(self):
        self.returned(result=failed(), asks=[ask(FAILED, "q-failed", NO_VERDICT)])
        rv, _lines = self.recorded([item_answer("q-failed", FAILED, "다시 보낸다")])
        self.assertEqual((rv.stage, rv.close_reason), ("닫힘", "다시 보냄"))
        with self.subTest(case="선택지 밖 답 · 「(권장)」 꼬리"):
            self.setUp()
            folder = self.returned(result=failed(), asks=[ask(FAILED, "q-failed", NO_VERDICT)])
            before = self.state_bytes(folder)
            for value in ("다시 보낸다 (권장)", "그냥 간다"):
                self.assertEqual(self.record([item_answer("q-failed", FAILED, value)]).returncode, 2, value)
            self.assertEqual(self.state_bytes(folder), before)
            self.setUp()
            folder = self.returned(asks=[ask(INTENT, "q1")])
            before = self.state_bytes(folder)
            proc = self.record([item_answer("q1", INTENT, "의도다 (권장)")])  # 선택지를 묶지 않는 질문에서도
            self.assertEqual(proc.returncode, 2, proc.stdout + proc.stderr)
            self.assertIn("(권장)", proc.stderr)
            self.assertEqual(self.state_bytes(folder), before)

    def test_close_wrong_choice_routes(self):
        with self.subTest(case="의도 점검 답의 행선"):
            folder = self.returned(blocking=[finding("지적 1")], asks=[ask(INTENT, "q1")])
            rv, _lines = self.recorded([item_answer("q1", INTENT, "잘못 골랐다")])
            self.assertEqual(rv.stage, "돌아옴")
            before = self.state_bytes(folder)
            lines = self.refused(self.record([{"kind": "route", "question": "q1", "value": "설계 대화로"}]))
            self.assertIn("기록 파일 경로", lines[0])  # 기록 파일 경로를 먼저 적는다(§4 표의 차례)
            self.assertEqual(self.state_bytes(folder), before)
            self.recorded([{"kind": "record_path", "question": "q1", "path": RECORD}])
            rv, _lines = self.recorded([{"kind": "route", "question": "q1", "value": "설계 대화로"}])
            self.assertEqual((rv.stage, rv.close_reason, rv.close_mark), ("닫힘", F.REASON_DESIGN, ""))
            self.assertEqual(rv.blocking[0].handling, F.NO_HANDLING)  # 막는 지적이 있어도 설계 대화가 먼저다
        with self.subTest(case="거른 「잘못 골랐다」 목록의 행선"):
            self.setUp()
            self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="막는 지적 없음",
                            worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1),
                            filtered_wrong=[F.Filtered(id="q7", text="가"), F.Filtered(id="q8", text="나")]))
            rv, _lines = self.recorded([{"kind": "route", "question": "q7", "value": "설계 대화로"}])
            self.assertEqual((rv.stage, rv.close_reason), ("닫힘", "막는 지적 없음"))  # q8 의 행선이 아직이다
            self.assertEqual([x.dest for x in rv.filtered_wrong], ["설계 대화로", ""])
            rv, _lines = self.recorded([{"kind": "route", "question": "q8", "value": "재분해 신호"}])
            self.assertEqual((rv.stage, rv.close_reason), ("닫힘", F.REASON_RESPLIT))
        with self.subTest(case="의도 점검 답과 거른 목록이 함께면 행선을 함께 적는다"):
            self.setUp()
            folder = self.returned(blocking=[finding("지적 1")], filtered_wrong=[F.Filtered(id="q7", text="가")],
                                   answers=[answer("q1", INTENT, "잘못 골랐다", RECORD)])
            before = self.state_bytes(folder)
            self.refused(self.record([{"kind": "route", "question": "q1", "value": "설계 대화로"}]))
            self.assertEqual(self.state_bytes(folder), before)
            rv, _lines = self.recorded([{"kind": "route", "question": "q1", "value": "설계 대화로"},
                                        {"kind": "route", "question": "q7", "value": "설계 대화로"}])
            self.assertEqual((rv.stage, rv.close_reason), ("닫힘", F.REASON_DESIGN))
            before = self.state_bytes(folder)
            self.recorded()  # git 이 사유를 바꾸지 못하는 닫힘은 다시 가려도 그대로다
            self.assertEqual(self.state_bytes(folder), before)
            self.setUp()
            folder = self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason=F.REASON_DESIGN,
                                     worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1),
                                     blocking=[finding("지적 1", "고친 커밋 deadbeef")], returns=[self.ret(1, "옮김")],
                                     answers=[answer("q1", INTENT, "잘못 골랐다", RECORD)]))
            before = self.state_bytes(folder)
            self.recorded()  # 범위 밖 고친 커밋이 있어도 그 닫힘은 되돌리지 않는다
            self.assertEqual(self.state_bytes(folder), before)
        with self.subTest(case="없는 질문의 행선"):
            self.setUp()
            folder = self.returned(blocking=[finding("지적 1")])
            before = self.state_bytes(folder)
            self.refused(self.record([{"kind": "route", "question": "q9", "value": "설계 대화로"}]))
            self.assertEqual(self.state_bytes(folder), before)

    def test_close_epic_stop_even_with_asks(self):
        self.returned(blocking=[finding("지적 1", "반박 — 설계가 그렇게 정했다")], returns=[self.ret(1, "옮김")],
                      asks=[ask(INTENT, "q1"), ask(UNFIXED, "q-unfixed-1")])
        rv, _lines = self.recorded([item_answer("q-unfixed-1", UNFIXED, STOP)])
        self.assertEqual((rv.stage, rv.close_reason), ("닫힘", "에픽을 멈춤"))
        self.assertEqual([a.id for a in rv.asks], ["q1"])

    def test_epic_stop_reanswer_reopens(self):
        self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="에픽을 멈춤",
                        worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1),
                        blocking=[finding("지적 1", "반박 — 설계가 그렇게 정했다")], returns=[self.ret(1, "옮김")],
                        answers=[answer("q-unfixed-1", UNFIXED, STOP)]))
        rv, _lines = self.recorded([item_answer("q-unfixed-1", UNFIXED, STOP)])  # 같은 답 — 그대로
        self.assertEqual((rv.stage, rv.close_reason, len(rv.answers)), ("닫힘", "에픽을 멈춤", 1))
        rv, _lines = self.recorded([item_answer("q-unfixed-1", UNFIXED, "다시 돌려보낸다")])
        self.assertEqual((rv.stage, rv.close_reason, rv.close_mark), ("돌아옴", "", ""))
        self.assertEqual([a.answer for a in rv.answers], [STOP, "다시 돌려보낸다"])
        self.assertEqual(rv.blocking[0].handling, F.RETURNED_AGAIN)
        with self.subTest(case="지적 목록을 얻지 못한 질문"):
            self.setUp()
            self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="에픽을 멈춤",
                            worker="qg-w1 · " + AT, result=failed(), answers=[answer("q-failed", FAILED, STOP)]))
            rv, _lines = self.recorded([item_answer("q-failed", FAILED, "다시 보낸다")])
            self.assertEqual((rv.stage, rv.close_reason), ("닫힘", "다시 보냄"))
            self.assertEqual([a.answer for a in rv.answers], [STOP, "다시 보낸다"])

    def test_intent_answer_needs_record_path(self):
        for label, path in (("기록 파일", RECORD), ("기록 브랜치 없음", NO_BRANCH)):
            with self.subTest(case=label):
                self.setUp()
                self.returned(asks=[ask(INTENT, "q1")])
                rv, lines = self.recorded([item_answer("q1", INTENT, "의도다", "직접 쓴 답\n둘째 줄")])
                self.assertEqual((rv.stage, rv.asks, rv.answers[0].record), ("돌아옴", [], ""))
                self.assertEqual(rv.answers[0].answer_text, "직접 쓴 답\n둘째 줄")
                self.assertIn("기록 파일", lines[0])
                rv, _lines = self.recorded([{"kind": "record_path", "question": "q1", "path": path}])
                self.assertEqual((rv.stage, rv.close_reason, rv.answers[0].record), ("닫힘", "막는 지적 없음", path))
        with self.subTest(case="꼴이 틀린 경로"):
            self.setUp()
            folder = self.returned(answers=[answer("q1", INTENT, "의도다")])
            before = self.state_bytes(folder)
            for bad in ("기록 브랜치 없음", "/abs/path.md", "../up.md", "a\nb.md", ""):
                self.assertEqual(self.record([{"kind": "record_path", "question": "q1", "path": bad}]).returncode,
                                 2, bad)
            self.assertEqual(self.state_bytes(folder), before)

    def test_unanswered_intent_leaves_asks(self):
        self.returned(blocking=[finding("지적 1", "반박 — 설계가 그렇게 정했다")], returns=[self.ret(1, "옮김")],
                      asks=[ask(INTENT, "q1"), ask(UNFIXED, "q-unfixed-1")])
        rv, _lines = self.recorded([item_answer("q1", INTENT, "답하지 않음")])
        self.assertEqual([a.id for a in rv.asks], ["q-unfixed-1"])
        self.recorded([{"kind": "record_path", "question": "q1", "path": RECORD}])
        rv, _lines = self.recorded()  # 다시 가려도 다시 띄우지 않고, 다른 종류의 질문은 남는다
        self.assertEqual(([a.id for a in rv.asks], rv.stage), (["q-unfixed-1"], "돌아옴"))

    def test_fixed_hash_outside_range_reverts(self):
        self.returned(blocking=[finding("지적 1")], returns=[self.ret(1)])
        rv, lines = self.recorded([{"kind": "return_moved", "value": "옮김"},
                                   {"kind": "handling", "finding": 1, "value": "고친 커밋 deadbeef"}])
        self.assertEqual(rv.blocking[0].handling, F.NO_HANDLING)
        self.assertEqual(rv.returns[0].moved, "옮겼으나 범위 밖 커밋")
        self.assertIn(OUT_OF_RANGE % "deadbeef", lines)
        self.assertEqual((rv.stage, rv.asks), ("돌아옴", []))  # 쓸 처리 없이 끝난 첫 번째 — 다시 돌려보낼 차례
        with self.subTest(case="범위 안의 고친 커밋은 남는다"):
            self.setUp()
            self.returned(blocking=[finding("지적 1")], returns=[self.ret(1)])
            fix = self.code()
            rv, lines = self.recorded([{"kind": "return_moved", "value": "옮김"},
                                       {"kind": "handling", "finding": 1, "value": "고친 커밋 " + fix[:10]}])
            self.assertEqual((rv.blocking[0].handling, rv.returns[0].moved), ("고친 커밋 " + fix[:10], "옮김"))
            self.assertEqual((rv.stage, rv.close_reason), ("닫힘", "재리뷰로 이어짐"))
            self.assertFalse([x for x in lines if x.startswith("알림 · 적어 낸")], lines)
        with self.subTest(case="여러 줄 처리 값"):
            self.setUp()
            folder = self.returned(blocking=[finding("지적 1")], returns=[self.ret(1)])
            before = self.state_bytes(folder)
            proc = self.record([{"kind": "return_moved", "value": "옮김"},
                                {"kind": "handling", "finding": 1, "value": "반박 — 첫 줄\n둘째 줄"}])
            self.assertEqual(proc.returncode, 2, proc.stdout + proc.stderr)
            self.assertIn("한 줄", proc.stderr)
            for bad in ("고쳤다", F.USER_LEFT):
                self.assertEqual(self.record([{"kind": "return_moved", "value": "옮김"},
                                              {"kind": "handling", "finding": 1, "value": bad}]).returncode, 2, bad)
            self.assertEqual(self.state_bytes(folder), before)

    def test_open_never_moves_previous(self):
        c2 = self.code()
        folder = self.put(self.closed_rereview("고친 커밋 " + c2))
        before = self.state_bytes(folder)
        self.ok(self.open("recheck"))
        self.assertEqual(self.state_bytes(folder), before)
        self.assertEqual([(r.order, r.stage) for r in self.reviews()], [(1, "닫힘"), (2, "열림")])

    def picked_reviews(self, close_reason="막는 지적 없음", **kw):
        """차례 1(첫 리뷰 — 재리뷰로 이어짐) · 차례 2(좁은 재리뷰 — 닫힘). (차례 1 의 보관 폴더, c2) 를 낸다."""
        c2 = self.code()
        first = self.put(self.closed_rereview("고친 커밋 " + c2))
        self.put(review("recheck", 2, self.c1, c2, stage="닫힘", close_reason=close_reason, worker="qg-w2 · " + AT,
                        result=obtained(self.c1, c2), **kw))
        return first, c2

    def test_pick_goes_to_last_review_and_reopens(self):
        first, c2 = self.picked_reviews()
        before = self.state_bytes(first)
        rv, _lines = self.recorded([{"kind": "pick", "text": "SUGGESTION src/a.py:2 — 이름을 바꾼다",
                                     "from_order": 1, "pick_kind": "고른 제안"},
                                    {"kind": "pick", "text": "되올린 지적 원문", "from_order": 2,
                                     "pick_kind": "되올린 지적"}])
        self.assertEqual(self.state_bytes(first), before)
        self.assertEqual((rv.order, rv.stage, rv.close_reason), (2, "돌아옴", ""))
        self.assertEqual([(f.kind, f.text, f.handling, f.from_review) for f in rv.blocking],
                         [("고른 제안", "SUGGESTION src/a.py:2 — 이름을 바꾼다", F.NO_HANDLING, "1"),
                          ("되올린 지적", "되올린 지적 원문", F.NO_HANDLING, "")])
        rv, _lines = self.recorded()  # 차례 2 의 범위로는 그 지적이 닫히지 않는다
        self.assertEqual(rv.stage, "돌아옴")
        self.recorded([{"kind": "return", "worker": "impl-w1", "handling_file": self.handling_file(1)}])
        c3 = self.code()
        rv, _lines = self.recorded([{"kind": "return_moved", "value": "옮김"},
                                    {"kind": "handling", "finding": 1, "value": "고친 커밋 " + c3},
                                    {"kind": "handling", "finding": 2, "value": "고친 커밋 " + c3}])
        self.assertEqual((rv.stage, rv.close_reason), ("닫힘", "재리뷰로 이어짐"))  # 뒤에 여는 리뷰가 본다
        with self.subTest(case="없는 차례 · 도는 리뷰"):
            self.setUp()
            self.picked_reviews()
            item = {"kind": "pick", "text": "가", "from_order": 3, "pick_kind": "고른 제안"}
            self.refused(self.record([item]))
            self.setUp()
            folder = self.sent()
            before = self.state_bytes(folder)
            self.refused(self.record([dict(item, from_order=1)]))
            self.assertEqual(self.state_bytes(folder), before)

    def at_cap_last(self, **kw) -> Path:
        """차례 1 · 2 재리뷰로 이어짐, 차례 3(좁은 재리뷰 둘째) — 세는 재리뷰가 상한(2)에 닿았다."""
        c2, c3 = self.at_cap_rechecks()
        kw.setdefault("stage", "닫힘")
        if kw["stage"] == "닫힘":
            kw.setdefault("close_reason", "막는 지적 없음")
        return self.put(review("recheck", 3, c2, c3, worker="qg-w3 · " + AT, result=obtained(c2, c3), **kw))

    def test_pick_at_cap_asks_two_max(self):
        self.at_cap_last()
        self.assertEqual((Q.counted_rechecks(self.reviews()), Q.cap(self.reviews())), (2, 2))
        pick = {"kind": "pick", "text": "제안 — 이름을 바꾼다", "from_order": 3, "pick_kind": "고른 제안"}
        rv, _lines = self.recorded([pick])
        self.assertEqual((rv.stage, [(a.kind, a.id) for a in rv.asks]), ("돌아옴", [(ASK_KIND_TWO, "q-cap")]))
        rv, _lines = self.recorded([dict(pick, text="둘째 제안")])
        self.assertEqual([a.kind for a in rv.asks], [ASK_KIND_TWO])  # 두 번 적지 않는다
        lines = self.refused(self.record([{"kind": "return", "worker": "impl-w1",
                                           "handling_file": self.handling_file(1)}]))
        self.assertIn("물을 것", lines[0])  # 「두 번까지」 의 답 전에는 돌려보내지 않는다
        rv, _lines = self.recorded([item_answer("q-cap", ASK_KIND_TWO, "한 번 더 돌려보낸다")])
        self.assertEqual((rv.stage, rv.asks, Q.cap(self.reviews())), ("돌아옴", [], 3))
        with self.subTest(case="상한 안이면 묻지 않는다"):
            self.setUp()
            self.picked_reviews()
            rv, _lines = self.recorded([dict(pick, from_order=2)])
            self.assertEqual(rv.asks, [])

    def test_wrong_choice_withdraws_two_max(self):
        self.at_cap_last(stage="돌아옴", asks=[ask(INTENT, "q1")])
        rv, _lines = self.recorded([{"kind": "pick", "text": "제안", "from_order": 3, "pick_kind": "고른 제안"}])
        self.assertEqual([a.kind for a in rv.asks], [INTENT, ASK_KIND_TWO])
        rv, _lines = self.recorded([item_answer("q1", INTENT, "잘못 골랐다")])
        self.assertEqual(rv.asks, [])
        self.assertEqual([a.kind for a in rv.answers], [INTENT])  # 거둔 것이지 답으로 적지 않는다

    def test_pick_with_wrong_list_no_two_max(self):
        self.at_cap_last(filtered_wrong=[F.Filtered(id="q7", text="앞서 잘못 골랐다고 답한 방향")])
        rv, _lines = self.recorded([{"kind": "pick", "text": "제안", "from_order": 3, "pick_kind": "고른 제안"}])
        self.assertNotIn(ASK_KIND_TWO, [a.kind for a in rv.asks])
        self.assertEqual(rv.stage, "돌아옴")
        self.assertEqual(self.row(self.next()), "R6a")

    def test_return_line_and_empty_return_count(self):
        self.returned(blocking=[finding("지적 1")])

        def send_back(worker, n):
            rv, _lines = self.recorded([{"kind": "return", "worker": worker, "handling_file": self.handling_file(n)}])
            self.assertEqual((rv.returns[-1].worker, rv.returns[-1].moved, rv.returns[-1].at),
                             (worker, "아직", LATER))
            self.assertEqual(rv.returns[-1].path, self.handling_file(n))
            return rv

        send_back("impl-w1", 1)
        self.refused(self.record([{"kind": "return", "worker": "impl-w9", "handling_file": self.handling_file(9)}]))
        rv, _lines = self.recorded([{"kind": "return_moved", "value": "처리 파일 없이 끝남"}])
        self.assertEqual((rv.returns[0].moved, rv.blocking[0].handling, rv.asks),
                         ("처리 파일 없이 끝남", F.NO_HANDLING, []))  # 첫 번째 — 다시 돌려보낼 차례
        send_back("impl-w2", 2)
        rv, lines = self.recorded([{"kind": "return_moved", "value": "옮김"},
                                   {"kind": "handling", "finding": 1, "value": "고친 커밋 deadbeef"}])
        self.assertIn(OUT_OF_RANGE % "deadbeef", lines)  # 「옮겼으나 범위 밖 커밋」 도 함께 센다 — 두 번째
        self.assertEqual(rv.returns[1].moved, "옮겼으나 범위 밖 커밋")
        self.assertEqual(rv.blocking[0].handling, F.UNTOUCHED_OUT_OF_RANGE)
        self.assertEqual([a.kind for a in rv.asks], [UNFIXED])
        rv, _lines = self.recorded([item_answer(rv.asks[0].id, UNFIXED, "다시 돌려보낸다")])
        self.assertEqual((rv.blocking[0].handling, rv.asks), (F.RETURNED_AGAIN, []))
        send_back("impl-w3", 3)
        rv, _lines = self.recorded([{"kind": "return_moved", "value": "처리 파일 없이 끝남"}])
        self.assertEqual((rv.blocking[0].handling, rv.asks), (F.RETURNED_AGAIN, []))  # 세기가 처음부터
        send_back("impl-w4", 4)
        rv, _lines = self.recorded([{"kind": "return_moved", "value": "처리 파일 없이 끝남"}])
        self.assertEqual(rv.blocking[0].handling, F.UNTOUCHED_NO_FILE)
        self.assertEqual([a.kind for a in rv.asks], [UNFIXED])
        rv, _lines = self.recorded([item_answer(rv.asks[0].id, UNFIXED, "반박을 받아들이고 남긴 지적으로 적는다")])
        self.assertEqual((rv.blocking[0].handling, rv.stage, rv.close_reason), (F.USER_LEFT, "닫힘", "사용자가 남김"))
        with self.subTest(case="반박이 있으면 고치지 않은 막는 지적의 질문"):
            self.setUp()
            self.returned(blocking=[finding("지적 1"), finding("지적 2")], returns=[self.ret(1)])
            rv, _lines = self.recorded([{"kind": "return_moved", "value": "옮김"},
                                        {"kind": "handling", "finding": 1, "value": "반박 — 설계가 그렇게 정했다"},
                                        {"kind": "handling", "finding": 2, "value": "손대지 않음"}])
            self.assertEqual([a.kind for a in rv.asks], [UNFIXED])
            self.assertEqual(rv.returns[0].moved, "옮김")
            rv, _lines = self.recorded([item_answer(rv.asks[0].id, UNFIXED, "다시 돌려보낸다")])
            self.assertEqual([f.handling for f in rv.blocking], [F.RETURNED_AGAIN, F.RETURNED_AGAIN])
        with self.subTest(case="아직 줄 없이 옮김 · 처리 없이 옮김"):
            self.setUp()
            folder = self.returned(blocking=[finding("지적 1")])
            before = self.state_bytes(folder)
            self.refused(self.record([{"kind": "return_moved", "value": "처리 파일 없이 끝남"}]))
            self.assertEqual(self.record([{"kind": "handling", "finding": 1, "value": "반박"}]).returncode, 2)
            self.assertEqual(self.state_bytes(folder), before)

    def test_no_review_closes_prior_fixed(self):
        c2 = self.code()
        first = review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="재리뷰로 이어짐",
                       worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1),
                       blocking=[finding("지적 1", "고친 커밋 " + c2), finding("지적 2", F.USER_LEFT)])
        self.put(first)
        self.returned(2, self.c1, c2, site="recheck", result=failed(), asks=[ask(FAILED, "q-failed", NO_VERDICT)])
        rv, _lines = self.recorded([item_answer("q-failed", FAILED, "리뷰 없이 머지 준비로 간다")])
        self.assertEqual((rv.stage, rv.close_reason), ("닫힘", "리뷰 없이 감"))
        prior = self.reviews()[0]
        self.assertEqual([f.handling for f in prior.blocking], [F.NO_REVIEW, F.USER_LEFT])
        self.assertEqual((prior.stage, prior.close_reason), ("닫힘", "재리뷰로 이어짐"))
        with self.subTest(case="뒤 리뷰가 이미 본 고친 커밋은 그대로"):
            self.setUp()
            c2, c3 = self.at_cap_rechecks()
            self.returned(3, c2, c3, site="recheck", result=failed(), asks=[ask(FAILED, "q-failed", NO_VERDICT)])
            self.recorded([item_answer("q-failed", FAILED, "리뷰 없이 머지 준비로 간다")])
            got = self.reviews()
            self.assertEqual(got[0].blocking[0].handling, "고친 커밋 " + c2)
            self.assertEqual(got[1].blocking[0].handling, F.NO_REVIEW)

    def test_mark_rejected_on_wrong_reason(self):
        cases = (("막는 지적 없음", "", F.MARK_REIMPLEMENTED), (F.REASON_RESPLIT, "", F.MARK_REIMPLEMENTED),
                 (F.REASON_DESIGN, "", F.MARK_RESPLIT_CONTINUE),
                 (F.REASON_DESIGN, "%s %s" % (F.MARK_REIMPLEMENTED, AT), F.MARK_REIMPLEMENTED),
                 (None, "", F.MARK_REIMPLEMENTED))
        for reason, mark, value in cases:
            with self.subTest(reason=reason, mark=mark, value=value):
                self.setUp()
                if reason is None:
                    folder = self.returned(answers=[answer("q1", INTENT, "잘못 골랐다", RECORD)])
                else:
                    folder = self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘",
                                             close_reason=reason, close_mark=mark, worker="qg-w1 · " + AT,
                                             result=obtained(self.base_sha, self.c1),
                                             answers=[answer("q1", INTENT, "잘못 골랐다", RECORD)]))
                before = self.state_bytes(folder)
                self.refused(self.record([{"kind": "mark", "value": value}]))
                self.assertEqual(self.state_bytes(folder), before)
        for reason, value in ((F.REASON_DESIGN, F.MARK_REIMPLEMENTED), (F.REASON_RESPLIT, F.MARK_RESPLIT_CONTINUE)):
            with self.subTest(reason=reason, value=value, case="받는다"):
                self.setUp()
                self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason=reason,
                                worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1),
                                answers=[answer("q1", INTENT, "잘못 골랐다", RECORD)]))
                rv, _lines = self.recorded([{"kind": "mark", "value": value}])
                self.assertEqual((rv.stage, rv.close_reason, rv.close_mark), ("닫힘", reason, "%s %s" % (value, LATER)))

    def test_reevaluate_after_rewrite(self):
        c2 = self.code()
        folder = self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="재리뷰로 이어짐",
                                 worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1),
                                 blocking=[finding("지적 1", "고친 커밋 " + c2)], returns=[self.ret(1, "옮김")]))
        before = self.state_bytes(folder)
        self.recorded()  # 기준 커밋이 그대로면 바뀌지 않는다
        self.assertEqual(self.state_bytes(folder), before)
        self.rig.git("reset", "-q", "--hard", self.c1)  # 닫은 뒤 브랜치가 다시 쓰였다
        self.spec_only()
        rv, lines = self.recorded()
        self.assertEqual((rv.stage, rv.close_reason), ("돌아옴", ""))
        self.assertEqual(rv.blocking[0].handling, F.NO_HANDLING)
        self.assertEqual(rv.returns[0].moved, "옮겼으나 범위 밖 커밋")
        self.assertIn(OUT_OF_RANGE % c2, lines)

    def test_record_input_and_stage_refusals(self):
        folder = self.returned(blocking=[finding("지적 1")], asks=[ask(INTENT, "q1")])
        before = self.state_bytes(folder)
        bad_inputs = ([{"kind": "모름"}], [{"kind": ["answer"]}], [{"kind": "answer", "question": "q1"}], ["글"],
                      [dict(item_answer("q1", INTENT, "의도다"), extra=1)],
                      [{"kind": "handling", "finding": True, "value": "반박"}],
                      [{"kind": "pick", "text": "가", "from_order": 1, "pick_kind": "제안"}])
        for items in bad_inputs:
            self.assertEqual(self.record(items).returncode, 2, items)
        path = self.rig.t / "broken.json"
        path.write_text("{not json", encoding="utf-8")
        args = ["record", "--roadmap", ROADMAP, "--target", TARGET, "--repo", str(self.rig.repo), "--spec", SPEC]
        self.assertEqual(self.rig.run(*args, "--input", str(path)).returncode, 2)
        self.assertEqual(self.rig.run(*args[:-2]).returncode, 2)  # --spec | --job-dir 가 없다
        self.refused(self.record([item_answer("q9", INTENT, "의도다")]))  # 없는 질문
        self.refused(self.record([item_answer("q1", FAILED, "다시 보낸다")]))  # 종류가 다르다
        self.assertEqual(self.state_bytes(folder), before)
        with self.subTest(case="도는 리뷰 · 담당자가 옮긴 질문"):
            self.setUp()
            self.sent()
            self.refused(self.record())
            self.refused(self.record([item_answer("q1", INTENT, "의도다")]))
            self.ok(self.record([{"kind": "worker_ask", "question": "w1", "text": "이 파일을 지워도 되나\n둘째 줄"}]))
            rv = self.reviews()[-1]
            self.assertEqual((rv.stage, [(a.kind, a.id, a.text) for a in rv.asks]),
                             ("보냄", [("담당자가 옮긴 질문", "w1", "이 파일을 지워도 되나\n둘째 줄")]))
            self.ok(self.record([item_answer("w1", "담당자가 옮긴 질문", "지우지 않는다")]))
            rv = self.reviews()[-1]
            self.assertEqual((rv.stage, rv.asks, [a.answer for a in rv.answers]), ("보냄", [], ["지우지 않는다"]))
        with self.subTest(case="멈출 조건"):
            self.setUp()
            self.put(review("recheck", 1, self.base_sha, self.c1))
            self.ok(self.record([{"kind": "stop_rule", "text": "두 번 뒤 남는 지적은 통합 리뷰 인계에 적는다"}]))
            self.assertEqual(self.reviews()[-1].stop_rule, "두 번 뒤 남는 지적은 통합 리뷰 인계에 적는다")

    # ------------------------------------------------------------ 관문 · 다음

    def common(self, target=TARGET, exclude=("--spec", SPEC)):
        return ["--roadmap", ROADMAP, "--target", target, "--repo", str(self.rig.repo), "--at", AT, *exclude]

    def gate(self, *extra, **kw):
        return self.rig.run("gate", *self.common(**kw), *extra)

    def gate_reasons(self, *extra, **kw):
        """관문의 걸린 까닭 번호들 — 열렸으면 빈 목록. 닫혔으면 줄마다 「까닭 · <번호> <이름>」 을 본다."""
        proc = self.gate(*extra, **kw)
        lines = proc.stdout.splitlines()
        if proc.returncode == 0:
            self.assertEqual(lines[:1], ["관문 · 열림"], proc.stdout)
            return []
        self.assertEqual((proc.returncode, lines[:1]), (1, ["관문 · 닫힘"]), proc.stdout + proc.stderr)
        got = []
        for line in lines[1:]:
            if line.startswith("까닭 · "):
                number, name = line[len("까닭 · "):].split(" ", 1)
                self.assertEqual(name, Q.REASON_NAMES[int(number)], line)
                got.append(int(number))
        return got

    def next(self, *alive, no_qg=False, **kw):
        args = ["next", *self.common(**kw)]
        for name in alive:
            args += ["--alive", name]
        if no_qg:
            args.append("--no-qg")
        lines = self.ok(self.rig.run(*args))
        self.assertTrue(len(lines) >= 3 and lines[0].startswith("할 일 · ") and lines[1].startswith("줄 · ")
                        and lines[2].startswith("까닭 · "), lines)
        return lines

    @staticmethod
    def row(lines) -> str:
        return lines[1][len("줄 · "):]

    @staticmethod
    def kind(lines) -> str:
        return lines[0].split(" · ")[1]

    @staticmethod
    def asked(lines):
        return [x for x in lines if x.startswith("물을 것 · ")]

    def test_gate_each_reason(self):
        cases = {
            1: [review("premerge", 1, self.base_sha, self.c1)],
            2: [review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="에픽을 멈춤",
                       worker="qg-w1 · " + AT, result=failed(), answers=[answer("q-failed", FAILED, STOP)])],
            3: [review("premerge", 1, self.base_sha, self.c1, stage="돌아옴", worker="qg-w1 · " + AT,
                       result=failed(), asks=[ask(FAILED, "q-failed", NO_VERDICT)])],
            4: [review("premerge", 1, self.base_sha, self.c1, stage="돌아옴", worker="qg-w1 · " + AT,
                       result=obtained(self.base_sha, self.c1), asks=[ask(INTENT, "q1")])],
            5: [review("premerge", 1, self.base_sha, self.c1, stage="돌아옴", worker="qg-w1 · " + AT,
                       result=obtained(self.base_sha, self.c1), answers=[answer("q1", INTENT, "의도다")])],
            6: [review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="막는 지적 없음",
                       worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1),
                       filtered_wrong=[F.Filtered(id="q7", text="가")])],
            7: [review("premerge", 1, self.base_sha, self.c1, stage="돌아옴", worker="qg-w1 · " + AT,
                       result=obtained(self.base_sha, self.c1), blocking=[finding("지적 1")])],
            8: [review("asked", 1, self.base_sha, self.c1, stage="닫힘", close_reason="막는 지적 없음",
                       worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1))],
        }
        for number, reviews in cases.items():
            with self.subTest(reason=number):
                self.setUp()
                for rv in reviews:
                    self.put(rv)
                self.assertEqual(self.gate_reasons(), [number])
        with self.subTest(reason="3 — 다시 보냄으로 닫히고 새 리뷰 없음"):
            self.setUp()
            self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="다시 보냄",
                            worker="qg-w1 · " + AT, result=failed(), answers=[answer("q-failed", FAILED, "다시 보낸다")]))
            self.assertEqual(self.gate_reasons(), [3])
        with self.subTest(reason="4 와 7 이 함께"):
            self.setUp()
            self.put(review("premerge", 1, self.base_sha, self.c1, stage="돌아옴", worker="qg-w1 · " + AT,
                            result=obtained(self.base_sha, self.c1), blocking=[finding("지적 1")],
                            asks=[ask(INTENT, "q1")]))
            self.assertEqual(self.gate_reasons(), [4, 7])
        with self.subTest(reason="7 — 「사용자가 남김」 뿐인데 기준 커밋으로 재리뷰로 이어짐(올라온 커밋이 재리뷰 전)"):
            self.setUp()
            self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="재리뷰로 이어짐",
                            worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1),
                            blocking=[finding("지적 1", F.USER_LEFT)]))
            self.code()
            self.assertEqual(self.gate_reasons(), [7])
        with self.subTest(reason="없음 — 양의 짝"):
            self.setUp()
            self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="막는 지적 없음",
                            worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1)))
            self.assertEqual(self.gate_reasons(), [])

    def test_gate_fixed_finding_closes_by_later_review(self):
        def first(c2):
            self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="재리뷰로 이어짐",
                            worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1),
                            blocking=[finding("지적 1", "고친 커밋 " + c2)], returns=[self.ret(1, "옮김")]))

        c2 = self.code()
        first(c2)
        self.assertEqual(self.gate_reasons(), [7])  # 그 고침을 본 리뷰가 아직 없다
        self.put(review("recheck", 2, self.c1, c2, stage="닫힘", close_reason="막는 지적 없음",
                        worker="qg-w2 · " + AT, result=obtained(self.c1, c2)))
        self.assertEqual(self.gate_reasons(), [])
        with self.subTest(case="뒤 리뷰가 지적 목록을 얻지 못함"):
            self.setUp()
            c2 = self.code()
            first(c2)
            self.returned(2, self.c1, c2, site="recheck", result=failed(), asks=[ask(FAILED, "q-failed", NO_VERDICT)])
            self.assertEqual(self.gate_reasons(), [3, 7])
            self.recorded([item_answer("q-failed", FAILED, "리뷰 없이 머지 준비로 간다")])
            self.assertEqual(self.gate_reasons(), [])  # 「리뷰 없이 가기로 함」 으로 닫혔다
            self.assertEqual(self.reviews()[0].blocking[0].handling, F.NO_REVIEW)

    def test_gate_no_qg(self):
        proc = self.gate("--no-qg")
        self.assertEqual((proc.returncode, proc.stdout.splitlines()), (0, [GATE_NO_QG]), proc.stdout)
        self.assertEqual(self.count(), 0)
        self.assertEqual(self.row(self.next(no_qg=True)), "R0")
        self.assertEqual(self.count(), 0)
        self.assertEqual(self.gate_reasons(), [8])  # 인자 없이 상태 파일이 없으면 첫 리뷰 없음
        self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="막는 지적 없음",
                        worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1)))
        proc = self.gate("--no-qg")
        self.assertEqual((proc.returncode, proc.stdout.splitlines()), (0, ["관문 · 열림", NO_QG_NOTICE]))
        lines = self.next(no_qg=True)
        self.assertEqual(self.row(lines), "R9")
        self.assertIn(NO_QG_NOTICE, lines)
        with self.subTest(case="상태 파일대로 닫힘"):
            self.setUp()
            self.put(review("premerge", 1, self.base_sha, self.c1))
            proc = self.gate("--no-qg")
            self.assertEqual(proc.returncode, 1)
            self.assertEqual(proc.stdout.splitlines(), ["관문 · 닫힘", "까닭 · 1 리뷰가 도는 중", NO_QG_NOTICE])
            lines = self.next(no_qg=True)
            self.assertEqual(self.row(lines), "R1a")
            self.assertIn(NO_QG_NOTICE, lines)
        with self.subTest(case="읽지 못한 상태 파일도 상태 파일이다"):
            self.setUp()
            self.broken_state()
            proc = self.gate("--no-qg")
            self.assertEqual(proc.returncode, 1, proc.stdout)
            self.assertIn(NO_QG_NOTICE, proc.stdout.splitlines())
            lines = self.next(no_qg=True)
            self.assertEqual(self.row(lines), "RX")
            self.assertIn(NO_QG_NOTICE, lines)
            self.assertNotIn(NO_QG_NOTICE, self.next())   # 인자가 없으면 알리지 않는다

    def test_next_failed_review_asks(self):
        folder = self.sent()
        self.rig.write_result(folder, None, self.base_sha, self.c1)
        self.ok(self.back())
        lines = self.next()
        self.assertEqual((self.row(lines), self.kind(lines)), ("R3a", "사용자 차례"))
        self.assertEqual(self.asked(lines), ["물을 것 · %s · q-failed" % FAILED])
        self.assertEqual(self.gate_reasons(), [3])
        with self.subTest(case="의도 점검만 셀 수 없음"):
            self.setUp()
            folder = self.sent()
            self.rig.write_result(folder, "defect", self.base_sha, self.c1, blocking=["IMPORTANT src/a.py:1 — 값"])
            (folder / "intent-return.md").write_text("contract: 3\nquestions: []\n", encoding="utf-8")
            self.ok(self.back())
            lines = self.next()
            self.assertEqual(self.row(lines), "R7d")
            self.assertFalse([x for x in lines if FAILED in x], lines)

    def sending(self) -> Path:
        folder = self.sent(stage="보내는 중")
        (folder / "qg-answered.yaml").write_text("answers: []\n", encoding="utf-8")
        (folder / "qg-answered-notices.txt").write_text("", encoding="utf-8")
        return folder

    def test_sending_only_pre_files_sends(self):
        folder = self.sending()
        (folder / ".DS_Store").write_bytes(b"\0")      # 숨은 파일 · 폴더는 담당자가 옮긴 파일이 아니다
        (folder / "sub").mkdir()
        lines = self.next()
        self.assertEqual((self.row(lines), self.kind(lines)), ("R1b", "보냄"))
        self.assertIn("send --phase done --worker", lines[0])
        self.assertNotIn("send --phase start", lines[0])  # 보내는 중에서는 start 가 거절된다
        chooser = [x for x in lines if x.startswith("지휘자가 가린다 · ")]
        self.assertEqual(len(chooser), 1, lines)
        self.assertIn("qg premerge-%s 1" % TARGET, chooser[0])

    def test_sending_with_moved_file_is_returned(self):
        folder = self.sending()
        (folder / "handler-report.md").write_text("# 담당자 보고\n", encoding="utf-8")
        lines = self.next()
        self.assertEqual((self.row(lines), self.kind(lines)), ("R1b", "돌아옴"))
        self.assertIn("handler-report.md", lines[0])
        self.ok(self.back())
        lines = self.next()
        self.assertEqual((self.row(lines), self.kind(lines)), ("R3a", "사용자 차례"))  # 다시 보내지 않는다
        self.assertEqual(self.asked(lines), ["물을 것 · %s · q-failed" % FAILED])
        with self.subTest(case="결과 파일이 있다"):
            self.setUp()
            folder = self.sending()
            self.rig.write_result(folder, "clean", self.base_sha, self.c1)
            lines = self.next()
            self.assertEqual((self.row(lines), self.kind(lines)), ("R1b", "돌아옴"))

    def broken_state(self) -> Path:
        folder = self.rig.archive("qg-%s-premerge-%s-built-1" % (EPIC, TARGET))
        text = F.render(review("premerge", 1, self.base_sha, self.c1))
        (folder / F.STATE_NAME).write_text(text.replace("- 단계: 열림", "- 단계: 도는 중"), encoding="utf-8")
        return folder

    def test_gate_unreadable_is_closed(self):
        folder = self.broken_state()
        before = self.state_bytes(folder)
        proc = self.gate()
        lines = proc.stdout.splitlines()
        self.assertEqual(proc.returncode, 1, proc.stdout + proc.stderr)
        self.assertEqual(lines[0], "관문 · 닫힘")
        self.assertTrue(lines[1].startswith("까닭 · 읽지 못함 — "), lines)
        self.assertEqual(self.state_bytes(folder), before)
        F.write_review(folder / F.STATE_NAME, review("premerge", 1, self.base_sha, self.c1))  # 양의 짝
        self.assertEqual(self.gate_reasons(), [1])
        with self.subTest(case="칸끼리 맞지 않음"):
            self.setUp()
            self.code()
            self.put(self.closed_rereview(F.NO_HANDLING))
            proc = self.gate()
            self.assertEqual(proc.returncode, 1)
            self.assertTrue(proc.stdout.splitlines()[1].startswith("까닭 · 칸끼리 맞지 않음 — "), proc.stdout)

    def test_gate_other_filtered_only_opens(self):
        other = [F.Filtered(id="q1", text="의도다 · docs/qg-intent-answers/q1.md — 가가")]
        self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="막는 지적 없음",
                        worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1), filtered_other=other))
        self.assertEqual(self.gate_reasons(), [])
        self.assertEqual(self.row(self.next()), "R9")
        with self.subTest(case="「잘못 골랐다」 목록이 하나라도 있다"):
            self.setUp()
            self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="막는 지적 없음",
                            worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1), filtered_other=other,
                            filtered_wrong=[F.Filtered(id="q2", text="나나")]))
            self.assertEqual(self.gate_reasons(), [6])

    def test_team_handling_header(self):
        team = ("--job-dir", JOB)
        result = self.rig.repo / JOB / "results" / "impl-2.md"  # 다음 시도의 구현 결과 파일
        line = F.ReturnLine(worker="impl-w1", at=AT, path=str(result))
        self.put(review("premerge", 1, self.base_sha, self.c1, target=JOB_TARGET, stage="돌아옴",
                        worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1),
                        blocking=[finding("지적 1")], returns=[line]))
        for header, want in ((True, "R7b"), (False, "R7c")):
            with self.subTest(header=header):
                self.rig.write_handling(result, ["1 · 반박 — 설계가 그렇게 정했다"], header=header)
                lines = self.next(target=JOB_TARGET, exclude=team)
                self.assertEqual((self.row(lines), self.kind(lines)), (want, "답 적기"))
                self.assertEqual(any(x.startswith("지휘자가 가린다 · ") for x in lines), not header, lines)

    def test_worker_question_not_failed(self):
        moved = ask("담당자가 옮긴 질문", "w1", "담당자가 멈춘 질문 — 이 파일을 지워도 되나")
        self.sent(asks=[moved])
        lines = self.next()
        self.assertEqual((self.row(lines), self.kind(lines)), ("R1c", "사용자 차례"))
        self.assertEqual(self.asked(lines), ["물을 것 · 담당자가 옮긴 질문 · w1"])
        self.assertFalse([x for x in lines if FAILED in x], lines)
        self.ok(self.record([item_answer("w1", "담당자가 옮긴 질문", "지우지 않는다")]))
        self.assertEqual(self.kind(self.next("qg-w1")), "기다린다")
        self.assertEqual(self.row(self.next()), "R1e")
        self.ok(self.back())  # 이어 부를 수 없다 — 결과 파일이 없다
        lines = self.next()
        self.assertEqual(self.row(lines), "R3a")
        self.assertEqual(self.asked(lines), ["물을 것 · %s · q-failed" % FAILED])
        with self.subTest(case="질문 차례 — 지적 목록을 얻지 못함 다음이 담당자가 옮긴 질문"):
            self.setUp()
            self.returned(result=failed(), asks=[moved, ask(FAILED, "q-failed", NO_VERDICT)])
            self.assertEqual(self.asked(self.next()), ["물을 것 · %s · q-failed" % FAILED])
            self.setUp()
            self.returned(asks=[ask(UNFIXED, "q-unfixed-1"), ask(INTENT, "q1"), moved])
            self.assertEqual(self.asked(self.next()), ["물을 것 · 담당자가 옮긴 질문 · w1"])
            self.setUp()
            self.returned(asks=[ask(UNFIXED, "q-unfixed-1"), ask(ASK_KIND_TWO, "q-cap"), ask(INTENT, "q1")])
            self.assertEqual(self.asked(self.next()), ["물을 것 · %s · q1" % INTENT])
            self.setUp()
            self.returned(asks=[ask(UNFIXED, "q-unfixed-1"), ask(ASK_KIND_TWO, "q-cap")])
            self.assertEqual(self.asked(self.next()), ["물을 것 · %s · q-cap" % ASK_KIND_TWO])

    def test_answer_then_cut_before_record(self):
        self.returned(asks=[ask(INTENT, "q1", "이 기능이 정말 필요한가")])
        self.recorded([item_answer("q1", INTENT, "의도다")])
        for _again in range(2):  # 끊겼다 다시 불러도 같은 할 일 — 다시 묻지 않는다
            lines = self.next()
            self.assertEqual((self.row(lines), self.kind(lines)), ("R5", "기록 파일 쓰기"))
            self.assertEqual(self.asked(lines), [])
        self.assertEqual(self.gate_reasons(), [5])

    def test_halted_and_resplit_wait(self):
        cases = (("에픽을 멈춤", "", "R2", "사용자 차례"), (F.REASON_RESPLIT, "", "R6d", "사용자 차례"),
                 (F.REASON_DESIGN, "", "R6b", "기다린다"))
        for reason, mark, want, kind in cases:
            with self.subTest(reason=reason):
                self.setUp()
                answers = ([answer("q-unfixed-1", UNFIXED, STOP)] if reason == "에픽을 멈춤"
                           else [answer("q1", INTENT, "잘못 골랐다", RECORD)])
                self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason=reason,
                                close_mark=mark, worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1),
                                blocking=[finding("지적 1", "반박 — 설계가 그렇게 정했다")] if answers[0].kind == UNFIXED
                                else [], returns=[self.ret(1, "옮김")] if answers[0].kind == UNFIXED else [],
                                answers=answers))
                self.spec_only()
                lines = self.next()
                self.assertEqual((self.row(lines), self.kind(lines)), (want, kind))
                self.assertEqual(self.asked(lines), [])

    def test_closed_but_gate_closed_rows(self):
        self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="막는 지적 없음",
                        worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1),
                        filtered_wrong=[F.Filtered(id="q7", text="앞서 잘못 골랐다고 답한 방향")]))
        lines = self.next()
        self.assertEqual((self.row(lines), self.kind(lines)), ("R6a", "답 적기"))
        self.assertIn("q7", lines[0])
        self.recorded([{"kind": "route", "question": "q7", "value": "설계 대화로"}])
        self.assertEqual(self.row(self.next()), "R6b")
        self.code("reimpl")
        self.recorded([{"kind": "mark", "value": F.MARK_REIMPLEMENTED}])
        lines = self.next()
        self.assertEqual((self.row(lines), self.kind(lines)), ("R6c", "열기"))
        with self.subTest(case="다시 보냄 뒤 새 리뷰 없음"):
            self.setUp()
            self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="다시 보냄",
                            worker="qg-w1 · " + AT, result=failed(), answers=[answer("q-failed", FAILED, "다시 보낸다")]))
            lines = self.next()
            self.assertEqual((self.row(lines), self.kind(lines)), ("R3b", "열기"))
            self.assertIn("--site premerge", lines[0])

    def test_next_unreadable_state_shows_values(self):
        folder = self.broken_state()
        before = self.state_bytes(folder)
        lines = self.next()
        self.assertEqual((self.row(lines), self.kind(lines)), ("RX", "상태 보이기"))
        self.assertTrue(lines[2].startswith("까닭 · 읽지 못함 — "), lines)
        self.assertIn("값 · %s · - 단계: 도는 중" % (folder / F.STATE_NAME), lines)
        self.assertEqual(self.state_bytes(folder), before)
        with self.subTest(case="칸끼리 맞지 않음"):
            self.setUp()
            self.code()
            folder = self.put(self.closed_rereview(F.NO_HANDLING))
            before = self.state_bytes(folder)
            lines = self.next()
            self.assertEqual((self.row(lines), self.kind(lines)), ("RX", "상태 보이기"))
            self.assertTrue(lines[2].startswith("까닭 · 칸끼리 맞지 않음 — "), lines)
            values = [x for x in lines if x.startswith("값 · 차례 1")]
            self.assertTrue(any("재리뷰로 이어짐" in x for x in values), lines)
            self.assertIn("값 · 차례 1 · 막는 지적 1 · %s" % F.NO_HANDLING, lines)
            self.assertEqual(self.state_bytes(folder), before)

    def test_return_wait_then_move(self):
        folder = self.returned(blocking=[finding("지적 1")], returns=[self.ret(1)])
        self.rig.write_handling(self.handling_file(1), ["1 · 반박 — 설계가 그렇게 정했다"])
        lines = self.next("impl-w1")
        self.assertEqual((self.row(lines), self.kind(lines)), ("R7a", "기다린다"))
        before = self.state_bytes(folder)
        self.refused(self.record([{"kind": "return", "worker": "impl-w2", "handling_file": self.handling_file(2)}]))
        self.assertEqual(self.state_bytes(folder), before)  # 다시 돌려보내지 않는다
        lines = self.next()
        self.assertEqual((self.row(lines), self.kind(lines)), ("R7b", "답 적기"))
        self.assertIn(self.handling_file(1), lines[0])
        for label, header in (("머리 없는 처리 파일", False), ("처리 파일 없음", None)):
            with self.subTest(case=label):
                path = Path(self.handling_file(1))
                if header is None:
                    path.unlink()
                else:
                    self.rig.write_handling(path, ["1 · 반박"], header=False)
                lines = self.next()
                self.assertEqual((self.row(lines), self.kind(lines)), ("R7c", "답 적기"))
                self.assertTrue(any(x.startswith("지휘자가 가린다 · ") for x in lines), lines)
                self.assertIn("처리 파일 없이 끝남", lines[0])

    def test_reverted_commit_notice(self):
        self.returned(blocking=[finding("지적 1")], returns=[self.ret(1)])
        self.recorded([{"kind": "return_moved", "value": "옮김"},
                       {"kind": "handling", "finding": 1, "value": "고친 커밋 deadbeef"}])
        self.assertEqual(self.reviews()[-1].blocking[0].reverted, "deadbeef")
        lines = self.next()
        self.assertEqual((self.row(lines), self.kind(lines)), ("R7d", "돌려보낸다"))
        self.assertIn(OUT_OF_RANGE % "deadbeef", lines)
        self.recorded([{"kind": "return", "worker": "impl-w2", "handling_file": self.handling_file(2)}])
        fix = self.code()
        rv, _lines = self.recorded([{"kind": "return_moved", "value": "옮김"},
                                    {"kind": "handling", "finding": 1, "value": "고친 커밋 " + fix}])
        self.assertEqual((rv.blocking[0].handling, rv.blocking[0].reverted), ("고친 커밋 " + fix, ""))
        with self.subTest(case="다른 길로 새 처리가 적혀도 비운다 — 알림이 한 바퀴 늦게 나오지 않는다"):
            self.setUp()
            self.returned(blocking=[finding("지적 1")], returns=[self.ret(1)])
            self.recorded([{"kind": "return_moved", "value": "옮김"},
                           {"kind": "handling", "finding": 1, "value": "고친 커밋 deadbeef"}])
            self.recorded([{"kind": "return", "worker": "impl-w2", "handling_file": self.handling_file(2)}])
            rv, _lines = self.recorded([{"kind": "return_moved", "value": "처리 파일 없이 끝남"}])
            self.assertEqual((rv.blocking[0].handling, rv.blocking[0].reverted), (F.UNTOUCHED_NO_FILE, ""))
            rv, _lines = self.recorded([item_answer(rv.asks[0].id, UNFIXED, "다시 돌려보낸다")])
            self.assertEqual((rv.blocking[0].handling, rv.blocking[0].reverted), (F.RETURNED_AGAIN, ""))
            lines = self.next()
            self.assertEqual(self.row(lines), "R7d")
            self.assertFalse([x for x in lines if x.startswith("알림 · 적어 낸")], lines)

    def test_at_cap_no_return_without_two_max_answer(self):
        # 상한에 닿은 PR 에서 「두 번까지」 의 답 없이 돌려보낼 것이 있으면 돌려보내기를 내지 않는다(AC32) —
        # 「돌아옴」 · 「답 적기」 가 그 질문을 적으므로 이 꼴은 칸끼리 맞지 않는 것이고 끝 줄이다(§4 「표가 덮는 것」).
        c2, c3 = self.at_cap_rechecks()
        folder = self.returned(3, c2, c3, site="recheck", blocking=[finding("지적 3")])
        lines = self.next()
        self.assertEqual(self.row(lines), "RX", lines)
        self.assertNotEqual(self.kind(lines), "돌려보낸다")
        rv = self.reviews()[-1]
        rv.answers = [answer("q-cap", ASK_KIND_TWO, "한 번 더 돌려보낸다")]  # 양의 짝 — 「한 번 더」 뒤에는 상한 안
        F.write_review(folder / F.STATE_NAME, rv)
        self.assertEqual(self.row(self.next()), "R7d")

    def test_asked_refused_until_mark(self):
        wrong = [answer("q1", INTENT, "잘못 골랐다", RECORD)]
        cases = {
            "에픽을 멈춤": dict(close_reason="에픽을 멈춤", result=failed(),
                           answers=[answer("q-failed", FAILED, STOP)]),
            "설계 대화로 · 표시 없음": dict(close_reason=F.REASON_DESIGN, answers=wrong),
            "재분해 신호 · 표시 없음": dict(close_reason=F.REASON_RESPLIT, answers=wrong),
            "거른 「잘못 골랐다」 목록": dict(close_reason="막는 지적 없음",
                                    filtered_wrong=[F.Filtered(id="q7", text="가")]),
        }
        for label, kw in cases.items():
            with self.subTest(case=label):
                self.setUp()
                kw.setdefault("result", obtained(self.base_sha, self.c1))
                self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", worker="qg-w1 · " + AT, **kw))
                before = self.count()
                lines = self.refused(self.open("asked"))
                self.assertEqual(self.count(), before)
                self.assertIn("이름으로 청한 리뷰도 받지 않는다", lines[0])
                self.assertEqual(lines[1:], self.next())  # 그 상태의 「다음」 줄과 같은 할 일
        for label, (reason, mark) in {"다시 구현됨": (F.REASON_DESIGN, F.MARK_REIMPLEMENTED),
                                      "재분해 뒤 이어 감": (F.REASON_RESPLIT, F.MARK_RESPLIT_CONTINUE)}.items():
            with self.subTest(case="표시 뒤 받음 — " + label):
                self.setUp()
                self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason=reason,
                                close_mark="%s %s" % (mark, LATER), worker="qg-w1 · " + AT,
                                result=obtained(self.base_sha, self.c1), answers=wrong))
                self.ok(self.open("asked"))
                self.assertEqual(self.count(), 2)
        with self.subTest(case="그 밖의 닫힘은 받는다 — 사용자가 남김"):
            self.setUp()
            self.put(review("premerge", 1, self.base_sha, self.c1, stage="닫힘", close_reason="사용자가 남김",
                            worker="qg-w1 · " + AT, result=obtained(self.base_sha, self.c1),
                            blocking=[finding("지적 1", F.USER_LEFT)]))
            self.ok(self.open("asked"))


if __name__ == "__main__":
    unittest.main()
