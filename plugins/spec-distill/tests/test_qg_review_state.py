#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""qg_review_state.py — 기준 커밋 · 범위 · 세는 수와 상한 · 「열기」(AC4 · AC5 · AC9 · AC19 · AC33).

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


if __name__ == "__main__":
    unittest.main()
