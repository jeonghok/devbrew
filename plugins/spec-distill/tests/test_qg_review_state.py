#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""qg_review_state.py — 기준 커밋 · 범위 · 세는 수와 상한 · 「열기」 · 「보냄」 · 「돌아옴」
(AC2 · AC3 · AC4 · AC5 · AC8 · AC9 · AC19 · AC32 · AC33).

Run: cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_qg_review_state -v
"""
from __future__ import annotations

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


if __name__ == "__main__":
    unittest.main()
