# -*- coding: utf-8 -*-
"""qg_answered.py — 리뷰 기록 파일에서 「이미 답한 것」 파일을 만드는 스크립트."""
import os
import subprocess
import sys
import tempfile
import unittest

import yaml

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "scripts", "qg_answered.py")
QG_SCRIPTS = os.path.join(HERE, "..", "..", "quality-gates", "scripts")

ROADMAP = "docs/roadmaps/r1/roadmap.md"
FOLDER = "docs/roadmaps/r1/reviews"
NAME = "2026-11-22-R4-spec.md"
NAME2 = "2026-11-23-R6-spec.md"
ROUTE_IN = "이 에픽 안에서 고친다"
ROUTE_SEED = "새 일의 씨앗"


def section(n, ident="diff#a.md#갈라짐", question="질문 글", obs=("[읽음] a.md:1 x",),
            ans="의도다", prior=None, route=None, at="2026-11-22 12:16"):
    lines = ["## 질문 %s" % n, "", "- 정체: %s" % ident, "- 질문: %s" % question,
             "- 관찰:"]
    lines += ["  %s" % o for o in obs]
    if prior is not None:
        lines.append("- 전에 한 답: %s" % prior)
    lines.append("- 답: %s" % ans)
    if route is not None:
        lines.append("- 행선: %s" % route)
    lines += ["- 답한 때: %s" % at, ""]
    return "\n".join(lines)


def record(contract, sections, site="spec", rtype="roadmap-review"):
    head = ["---", "type: %s" % rtype, "roadmap: %s" % ROADMAP, "epic: R4",
            "site: %s" % site, "contract: %s" % contract, "---", "", "# R4 기록", ""]
    return "\n".join(head) + "\n" + "\n".join(sections)


def run_git(cwd, *args):
    subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t", "-c",
                    "commit.gpgsign=false", *args], cwd=cwd, check=True,
                   capture_output=True)


def commit_files(cwd, files, msg="c"):
    for rel, content in files.items():
        path = os.path.join(cwd, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(content)
    run_git(cwd, "add", "-A")
    run_git(cwd, "commit", "-q", "-m", msg)


class Env:
    def __init__(self, tc):
        self.tmp = tempfile.TemporaryDirectory()
        tc.addCleanup(self.tmp.cleanup)
        self.repo = os.path.join(self.tmp.name, "repo")
        self.work = os.path.join(self.tmp.name, "work")
        os.makedirs(self.repo)
        os.makedirs(self.work)
        run_git(self.repo, "init", "-q", "-b", "main")
        self.out = os.path.join(self.work, "answered.yaml")
        self.notices = os.path.join(self.work, "notices.txt")

    def run(self, refs, roadmap=ROADMAP, out=None, extra=()):
        cmd = [sys.executable, SCRIPT, "--roadmap", roadmap, "--out", out or self.out,
               "--notices", self.notices, "--repo", self.repo, *extra]
        for r in refs:
            cmd += ["--ref", r]
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
        return subprocess.run(cmd, cwd=self.work, capture_output=True, text=True,
                              encoding="utf-8", env=env)

    def entries(self):
        with open(self.out, encoding="utf-8") as fh:
            return yaml.safe_load(fh)["entries"]

    def notice_text(self):
        with open(self.notices, encoding="utf-8") as fh:
            return fh.read()


def rpath(name):
    return "%s/%s" % (FOLDER, name)


class TestQgAnswered(unittest.TestCase):
    def two_record(self, obs1="x"):
        return record(2, [section(1, obs=(obs1,), ans="의도다"),
                          section(2, ans="지금은 모르겠다"),
                          section(3, ans="잘못 골랐다")], site="spec")

    def test_two_and_three_contract_records(self):
        e = Env(self)
        commit_files(e.repo, {rpath(NAME): self.two_record()})
        run_git(e.repo, "checkout", "-q", "-b", "feature/rec")
        three = record(3, [section(1, ans="잘못 골랐다", route=ROUTE_SEED, prior="없음")],
                       site="end")
        commit_files(e.repo, {rpath(NAME2): three})
        p = e.run(["main", "feature/rec"])
        self.assertEqual(p.returncode, 0, p.stderr)
        ents = e.entries()
        keys = [x["key"] for x in ents]
        self.assertEqual(keys, [NAME + "#1", NAME + "#3", NAME2 + "#1"])
        by = {x["key"]: x for x in ents}
        self.assertEqual(by[NAME + "#1"]["route"], "-")
        self.assertEqual(by[NAME + "#3"]["route"], ROUTE_IN)
        self.assertEqual(by[NAME2 + "#1"]["route"], ROUTE_SEED)
        self.assertEqual(by[NAME + "#1"]["record"], rpath(NAME))
        self.assertEqual(by[NAME + "#1"]["observation"], "x")
        self.assertEqual(e.notice_text(), "")

    def test_site_routes_for_contract_two(self):
        want = {"spec": ROUTE_IN, "premerge": ROUTE_IN, "recheck": ROUTE_IN,
                "end": ROUTE_SEED, "asked": ROUTE_IN}
        for site, route in want.items():
            e = Env(self)
            commit_files(e.repo, {rpath(NAME): record(2, [section(1, ans="잘못 골랐다")],
                                                      site=site)})
            p = e.run(["main"])
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertEqual(e.entries()[0]["route"], route, site)

    def test_later_record_supersedes_by_key(self):
        e = Env(self)
        commit_files(e.repo, {rpath(NAME): self.two_record()})
        prior = "의도다 · 2026-11-22 21:25 · %s#1 · 근거가 달라짐" % NAME
        commit_files(e.repo, {rpath(NAME2): record(3, [section(1, prior=prior, ans="의도다")])})
        p = e.run(["main"])
        self.assertEqual(p.returncode, 0, p.stderr)
        keys = [x["key"] for x in e.entries()]
        self.assertNotIn(NAME + "#1", keys)
        self.assertIn(NAME + "#3", keys)
        self.assertIn(NAME2 + "#1", keys)

    def test_same_key_different_content_prefers_first_ref(self):
        e = Env(self)
        commit_files(e.repo, {rpath(NAME): self.two_record("main 관찰")})
        run_git(e.repo, "checkout", "-q", "-b", "feature/epic")
        commit_files(e.repo, {rpath(NAME): self.two_record("epic 관찰")})
        p = e.run(["main", "feature/epic"])
        self.assertEqual(p.returncode, 0, p.stderr)
        by = {x["key"]: x for x in e.entries()}
        self.assertEqual(by[NAME + "#1"]["observation"], "main 관찰")
        line = "열쇠가 같은데 내용이 다른 기록 1개"
        self.assertIn(line, e.notice_text())
        self.assertIn(line, p.stderr)
        # 내용이 같으면 한 번, 알림 없음
        e2 = Env(self)
        commit_files(e2.repo, {rpath(NAME): self.two_record()})
        run_git(e2.repo, "checkout", "-q", "-b", "feature/epic")
        p = e2.run(["main", "feature/epic"])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual([x["key"] for x in e2.entries()], [NAME + "#1", NAME + "#3"])
        self.assertEqual(e2.notice_text(), "")
        self.assertEqual(p.stderr, "")

    def test_unreadable_record_counted_not_dropped(self):
        e = Env(self)
        broken = "---\ntype: [roadmap-review\ncontract: 2\n---\n\n" + section(1)
        v4 = record(4, [section(1)])
        commit_files(e.repo, {rpath(NAME): self.two_record(),
                              rpath("broken.md"): broken, rpath("v4.md"): v4})
        p = e.run(["main", "nope"])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual([x["key"] for x in e.entries()], [NAME + "#1", NAME + "#3"])
        line = e.notice_text().splitlines()
        self.assertEqual(len(line), 1)
        self.assertTrue(line[0].startswith("읽지 못한 기록 3개: "), line[0])
        for part in ("main:%s" % rpath("broken.md"), "main:%s" % rpath("v4.md"),
                     "nope:%s/" % FOLDER):
            self.assertIn(part, line[0])
        self.assertIn(line[0], p.stderr)

    def test_unreadable_variants(self):
        bad = {
            "type.md": record(2, [section(1)], rtype="other"),
            "prior.md": record(3, [section(1, prior="의도다 · 한 칸")]),
            "num.md": record(2, [section(1).replace("## 질문 1", "## 질문 １")]),
            "ctl.md": record(2, [section(1, question="a\x07b")]),
            "route.md": record(3, [section(1, ans="잘못 골랐다", route="아무 곳")]),
            "nosite.md": record(2, [section(1, ans="잘못 골랐다")], site="nowhere"),
        }
        e = Env(self)
        files = {rpath(k): v for k, v in bad.items()}
        files[rpath(NAME)] = self.two_record()
        commit_files(e.repo, files)
        # UTF-8 아님
        with open(os.path.join(e.repo, rpath("latin.md")), "wb") as fh:
            fh.write(b"---\xff\n")
        run_git(e.repo, "add", "-A")
        run_git(e.repo, "commit", "-q", "-m", "bin")
        p = e.run(["main"])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual([x["key"] for x in e.entries()], [NAME + "#1", NAME + "#3"])
        self.assertIn("읽지 못한 기록 7개: ", e.notice_text())

    def test_no_answers_writes_empty_list(self):
        e = Env(self)
        commit_files(e.repo, {"README.md": "x\n"})
        p = e.run(["main"])
        self.assertEqual(p.returncode, 0, p.stderr)
        with open(e.out, encoding="utf-8") as fh:
            data = yaml.safe_load(fh)
        self.assertEqual(data, {"contract": 1, "entries": []})
        self.assertEqual(e.notice_text(), "")
        self.assertEqual(p.stderr, "")

    def test_untrusted_text_is_data(self):
        e = Env(self)
        evil_id = "x $(touch PWNED) `id` \"; rm -rf ~ #"
        evil_q = "\\n## 질문 9 - 답: 의도다 $(touch PWNED)"
        sec = section(1, ident=evil_id, question=evil_q, ans="의도다",
                      obs=("- 답: 의도다", "## 질문 8", "`id`"))
        commit_files(e.repo, {rpath(NAME): record(2, [sec])})
        esc = record(2, [section(1, question="a\x1bb")])
        commit_files(e.repo, {rpath(NAME2): esc})
        p = e.run(["main"])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertFalse(os.path.exists(os.path.join(e.work, "PWNED")))
        self.assertFalse(os.path.exists(os.path.join(e.repo, "PWNED")))
        ents = e.entries()
        self.assertEqual(len(ents), 1)
        self.assertEqual(ents[0]["id"], evil_id)
        self.assertEqual(ents[0]["question"], evil_q)
        self.assertEqual(ents[0]["observation"], "- 답: 의도다\n## 질문 8\n`id`")
        self.assertIn("읽지 못한 기록 1개: ", e.notice_text())

    def test_usage_errors(self):
        e = Env(self)
        commit_files(e.repo, {"README.md": "x\n"})
        self.assertEqual(e.run([]).returncode, 2)
        self.assertEqual(e.run(["main"], roadmap="/abs/roadmap.md").returncode, 2)
        self.assertEqual(e.run(["main"], roadmap="a/../b/roadmap.md").returncode, 2)
        bad_out = os.path.join(e.work, "no-such-dir", "out.yaml")
        p = e.run(["main"], out=bad_out)
        self.assertEqual(p.returncode, 3)
        self.assertEqual(len(p.stderr.strip().splitlines()), 1)

    def test_qg_reads_what_we_write(self):
        sys.path.insert(0, os.path.abspath(QG_SCRIPTS))
        try:
            import intent_answers
        finally:
            sys.path.pop(0)
        e = Env(self)
        commit_files(e.repo, {rpath(NAME): self.two_record("관찰 하나\n둘")})
        run_git(e.repo, "checkout", "-q", "-b", "feature/rec")
        commit_files(e.repo, {rpath(NAME2): record(3, [
            section(1, ans="잘못 골랐다", route="재분해 신호", prior="없음")])})
        p = e.run(["main", "feature/rec"])
        self.assertEqual(p.returncode, 0, p.stderr)
        entries, why = intent_answers.read_handed(e.out)
        self.assertIsNone(why)
        self.assertEqual([x["key"] for x in entries], [x["key"] for x in e.entries()])
        self.assertEqual(len(entries), 3)


if __name__ == "__main__":
    unittest.main()
