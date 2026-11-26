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
    if at is not None:
        lines.append("- 답한 때: %s" % at)
    lines.append("")
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


def rname(target, site="spec", day="2026-11-24"):
    """기록 이름 틀 `<날짜>-<대상>-<자리>.md` 안의 이름."""
    return "%s-%s-%s.md" % (day, target, site)


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

    def test_repo_subdirectory_still_finds_records(self):
        # --repo 가 리포 루트 아래 폴더여도 기록 폴더는 루트 기준으로 찾는다(빈 목록 · 알림 없음이 되지 않는다)
        e = Env(self)
        commit_files(e.repo, {rpath(NAME): self.two_record(), "docs/sub/x.txt": "x\n"})
        e.repo = os.path.join(e.repo, "docs", "sub")
        p = e.run(["main"])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual([x["key"] for x in e.entries()], [NAME + "#1", NAME + "#3"])
        self.assertEqual(e.notice_text(), "")

    def test_prior_cell_identity_with_separator(self):
        # 이름에 ` · ` 가 든 기록 파일은 이름 틀 밖 — 그 이름의 열쇠(`a · b.md#<n>`)는 qg 가 칸을 ` · ` 로
        # 나눠 읽어 맞출 수 없으니 넘기지 않고, 대상을 가릴 수 없어 어느 답도 넘기지 않는다(AC30 · AC13)
        e = Env(self)
        odd = "a · b.md"
        commit_files(e.repo, {rpath(odd): self.two_record()})
        ident_prior = "의도다 · 2026-11-22 21:25 · diff#a · b.md#갈라짐#방향 · 근거가 달라짐"
        key_prior = "의도다 · 2026-11-22 21:25 · %s#1 · 근거가 달라짐" % odd
        commit_files(e.repo, {rpath(NAME2): record(3, [section(1, prior=ident_prior),
                                                       section(2, prior=key_prior)])})
        p = e.run(["main"])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(e.entries(), [])
        self.assertEqual(e.notice_text().splitlines(),
                         ["읽지 못한 기록 1개: main:%s" % rpath(odd)])

    def test_answer_outside_template_is_noticed_not_dropped(self):
        # 틀의 다섯 값 밖인 `- 답:` 은 그 절만 넘기지 않고 알림 한 줄(기록 · 질문 번호 · 값)을 남긴다.
        # 틀 안의 넘기지 않는 값 셋은 알림 없이 건너뛰고, 같은 파일의 다른 답은 그대로 싣는다
        e = Env(self)
        typed = "의도다 — 이유를 직접 썼다"
        rec = record(3, [section(1, ans=typed), section(2, ans="의도다"),
                         section(3, ans="지금은 모르겠다"), section(4, ans="답하지 않음"),
                         section(5, ans="묻지 않음(상한 넘어 남김)"), section(6, ans="")])
        commit_files(e.repo, {rpath(NAME): rec})
        p = e.run(["main"])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual([x["key"] for x in e.entries()], [NAME + "#2"])
        lines = e.notice_text().splitlines()
        want = ("답이 틀의 값 밖이라 넘기지 않은 질문 2개: main:%s 질문 1 「%s」 · main:%s 질문 6 「」"
                % (rpath(NAME), typed, rpath(NAME)))
        self.assertEqual(lines, [want])
        self.assertEqual(p.stderr.splitlines(), [want])
        self.assertNotIn("읽지 못한 기록", e.notice_text())

    def test_prior_dash_or_empty_reads_as_none(self):
        # `- 전에 한 답:` 이 `-` 나 빈 값이어도 「없음」 과 같다 — 기록 파일 전체를 읽지 못한 기록으로 세지 않는다
        e = Env(self)
        commit_files(e.repo, {rpath(NAME): self.two_record(),
                              rpath(NAME2): record(3, [section(1, prior="-"),
                                                       section(2, prior="")])})
        p = e.run(["main"])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual([x["key"] for x in e.entries()],
                         [NAME + "#1", NAME + "#3", NAME2 + "#1", NAME2 + "#2"])
        self.assertEqual(e.notice_text(), "")

    def test_empty_answered_at_round_trip(self):
        # `- 답한 때:` 가 없는 답은 `-` 로 싣는다 — qg 가 그 답을 다시 물어 낸 asked_before 를 옮긴 새 기록이
        # 칸 수가 맞아 읽히고, 그 열쇠의 앞 항목을 뺀다(빈칸이 접혀 칸이 사라지지 않는다)
        sys.path.insert(0, os.path.abspath(QG_SCRIPTS))
        try:
            import intent_answers
            import intent_critic
        finally:
            sys.path.pop(0)
        e = Env(self)
        commit_files(e.repo, {rpath(NAME): record(3, [section(1, ans="의도다", at=None)])})
        p = e.run(["main"])
        self.assertEqual(p.returncode, 0, p.stderr)
        handed, why = intent_answers.read_handed(e.out)
        self.assertIsNone(why)
        self.assertEqual(handed[0]["answered_at"], "-")
        cell = intent_critic._text_cell(intent_critic._asked_before(
            handed[0]["answer"], handed[0]["answered_at"], handed[0]["key"], "근거가 달라짐"))
        prior = yaml.safe_load(cell)
        self.assertEqual(prior, "의도다 · - · %s#1 · 근거가 달라짐" % NAME)
        commit_files(e.repo, {rpath(NAME2): record(3, [section(1, prior=prior)])})
        p = e.run(["main"])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual([x["key"] for x in e.entries()], [NAME2 + "#1"])
        self.assertEqual(e.notice_text(), "")

    def test_unreadable_record_counted_not_dropped(self):
        e = Env(self)
        broken = "---\ntype: [roadmap-review\ncontract: 2\n---\n\n" + section(1)
        v4 = record(4, [section(1)])
        commit_files(e.repo, {rpath(NAME): self.two_record(),
                              rpath(rname("R7")): broken, rpath(rname("R8")): v4})
        p = e.run(["main", "nope"])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual([x["key"] for x in e.entries()], [NAME + "#1", NAME + "#3"])
        line = e.notice_text().splitlines()
        self.assertEqual(len(line), 1)
        self.assertTrue(line[0].startswith("읽지 못한 기록 3개: "), line[0])
        for part in ("main:%s" % rpath(rname("R7")), "main:%s" % rpath(rname("R8")),
                     "nope:%s/" % FOLDER):
            self.assertIn(part, line[0])
        self.assertIn(line[0], p.stderr)

    def test_unreadable_variants(self):
        # 이름은 틀 안 · 대상은 저마다 달라(R11–R17) 깨진 것은 내용뿐이다
        bad = {
            rname("R11"): record(2, [section(1)], rtype="other"),
            rname("R12"): record(3, [section(1, prior="의도다 · 한 칸")]),
            rname("R13"): record(3, [section(1, prior="의도다 · 2026-11-22 21:25 · 까닭 없는 열쇠")]),
            rname("R14"): record(2, [section(1).replace("## 질문 1", "## 질문 １")]),
            rname("R15"): record(2, [section(1, question="a\x07b")]),
            rname("R16"): record(3, [section(1, ans="잘못 골랐다", route="아무 곳")]),
            rname("R17"): record(2, [section(1, ans="잘못 골랐다")], site="nowhere"),
        }
        e = Env(self)
        files = {rpath(k): v for k, v in bad.items()}
        files[rpath(NAME)] = self.two_record()
        commit_files(e.repo, files)
        # UTF-8 아님
        with open(os.path.join(e.repo, rpath(rname("R18"))), "wb") as fh:
            fh.write(b"---\xff\n")
        run_git(e.repo, "add", "-A")
        run_git(e.repo, "commit", "-q", "-m", "bin")
        p = e.run(["main"])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual([x["key"] for x in e.entries()], [NAME + "#1", NAME + "#3"])
        self.assertIn("읽지 못한 기록 8개: ", e.notice_text())

    def test_control_chars_in_record_file_name(self):
        e = Env(self)
        files = {rpath(NAME): self.two_record(),
                 rpath("bad\nname.md"): self.two_record(),
                 rpath("bel\x07.md"): self.two_record()}
        commit_files(e.repo, files)
        p = e.run(["main"])
        self.assertEqual(p.returncode, 0, p.stderr)
        # 제어 글자가 든 이름은 틀 밖 — 어느 답도 넘어가지 않는다(AC13). 알림 줄은 한 줄로 남는다
        self.assertEqual(e.entries(), [])
        lines = e.notice_text().splitlines()
        self.assertEqual(len(lines), 1, lines)
        self.assertTrue(lines[0].startswith("읽지 못한 기록 2개: "), lines[0])
        self.assertIn("bad\\x0aname.md", lines[0])
        self.assertEqual(len(p.stderr.splitlines()), 1)
        sys.path.insert(0, os.path.abspath(QG_SCRIPTS))
        try:
            import intent_answers
        finally:
            sys.path.pop(0)
        self.assertIsNone(intent_answers.read_handed(e.out)[1])

    def test_duplicate_field_or_section_is_unreadable(self):
        dup_ans = section(1, ans="지금은 모르겠다").replace(
            "- 질문: 질문 글", "- 질문: 질문 글\n- 답: 의도다")
        e = Env(self)
        commit_files(e.repo, {rpath(rname("R7")): record(2, [dup_ans]),
                              rpath(rname("R8")): record(2, [section(1), section(1)])})
        p = e.run(["main"])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(e.entries(), [])
        self.assertTrue(e.notice_text().startswith("읽지 못한 기록 2개: "))

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


def good_record(n_sections=1):
    return record(3, [section(i + 1) for i in range(n_sections)])


def prior_to(key, ans="의도다", at="2026-11-22 21:25", why="근거가 달라짐"):
    return "%s · %s · %s · %s" % (ans, at, key, why)


NOTICE_FAIL = "[qg_answered] 알림 파일을 쓰지 못했다 — 알림은 위 줄뿐이다"
OUT_FAIL = "[qg_answered] 출력 파일을 쓰지 못했다 — "
NO_YAML = "[qg_answered] PyYAML 이 없다 — 답 없이 보낸다"


class TestQgAnsweredEdges(unittest.TestCase):
    def keys(self, env):
        return [x["key"] for x in env.entries()]

    def test_unreadable_record_drops_same_target(self):
        # 같은 에픽(R4)의 기록 하나가 깨졌으면 R4 의 답은 하나도 넘기지 않는다 — 깨진 파일 안의 「전에 한 답」
        # 이 NAME#1 을 뒤집었을 수 있다. 다른 에픽(R6)의 답은 넘어간다
        later = rname("R4", "premerge-pr12")
        broken = record(3, [section(1, prior=prior_to(NAME + "#1")),
                            section(2, ans="잘못 골랐다")])  # 3판 「잘못 골랐다」 에 행선이 없다
        e = Env(self)
        commit_files(e.repo, {rpath(NAME): good_record(2), rpath(NAME2): good_record(),
                              rpath(later): broken})
        p = e.run(["main"])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.keys(e), [NAME2 + "#1"])
        self.assertEqual(e.notice_text().splitlines(),
                         ["읽지 못한 기록 1개: main:%s" % rpath(later)])
        # 양의 짝 — 깨진 파일이 없으면 R4 의 답도 넘어간다
        e2 = Env(self)
        commit_files(e2.repo, {rpath(NAME): good_record(2), rpath(NAME2): good_record()})
        p = e2.run(["main"])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.keys(e2), [NAME + "#1", NAME + "#2", NAME2 + "#1"])
        # 로드맵 대상 — 깨진 로드맵 기록은 로드맵의 답만 막는다
        end = rname("roadmap", "end")
        e3 = Env(self)
        commit_files(e3.repo, {rpath(NAME): good_record(), rpath(end): good_record(),
                               rpath(rname("roadmap", "asked")): record(3, [section(1, ans="잘못 골랐다")])})
        p = e3.run(["main"])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.keys(e3), [NAME + "#1"])
        # 다른 ref 에 있는 같은 대상의 답도 막는다
        e4 = Env(self)
        commit_files(e4.repo, {rpath(NAME): good_record(), rpath(NAME2): good_record()})
        run_git(e4.repo, "checkout", "-q", "-b", "docs/records")
        commit_files(e4.repo, {rpath(later): broken})
        p = e4.run(["main", "docs/records"])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.keys(e4), [NAME2 + "#1"])

    def test_out_of_template_name_drops_all(self):
        # 이름이 틀(`<YYYY-MM-DD>-<대상>-<자리>[-<n>].md`) 밖인 기록이 하나라도 있으면 대상을 가릴 수 없어
        # 어느 답도 넘기지 않는다(AC13) — 내용이 멀쩡해도 같다
        for odd in ("notes.md", "2026-11-24-R4-review.md", "2026-11-24-r4-spec.md",
                    "2026-11-24-R4-spec-x.md", "2026-11-24-R4-premerge.md", "26-11-24-R4-spec.md",
                    "2026-11-24-R4-spec.md.md", "2026-11-24-R-spec.md"):
            e = Env(self)
            commit_files(e.repo, {rpath(NAME): good_record(), rpath(NAME2): good_record(),
                                  rpath(odd): good_record()})
            p = e.run(["main"])
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertEqual(e.entries(), [], odd)
            self.assertEqual(e.notice_text().splitlines(),
                             ["읽지 못한 기록 1개: main:%s" % rpath(odd)], odd)
        # 양의 짝 — 틀 안의 이름(번호 붙은 이름 · 로드맵 · 자리 다섯)은 모두 읽힌다
        names = [rname("R4", "spec-2"), rname("roadmap", "end"), rname("E12a", "recheck-pr7"),
                 rname("R4", "premerge-pr338"), rname("roadmap", "asked-3"), rname("R10", "asked")]
        e = Env(self)
        commit_files(e.repo, {rpath(n): good_record() for n in names})
        p = e.run(["main"])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(sorted(self.keys(e)), sorted(n + "#1" for n in names))
        self.assertEqual(e.notice_text(), "")

    def test_whole_ref_unreadable_drops_that_ref(self):
        # 없는 ref · `-` 로 시작하는 ref 는 그 ref 의 답이 없고 알림 한 줄, 다른 ref 의 답은 넘어간다
        e = Env(self)
        commit_files(e.repo, {rpath(NAME): good_record()})
        p = e.run(["main", "nope"], extra=("--ref=-main",))
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.keys(e), [NAME + "#1"])
        lines = e.notice_text().splitlines()
        self.assertEqual(len(lines), 1, lines)
        self.assertTrue(lines[0].startswith("읽지 못한 기록 2개: "), lines[0])
        for part in ("nope:%s/" % FOLDER, "-main:%s/" % FOLDER):
            self.assertIn(part, lines[0])
        # `-` 로 시작하는 ref 는 git 에 닿지 않는다 · 파일 목록을 읽지 못한 자리도 통째로 읽지 못한 자리다
        sys.path.insert(0, os.path.abspath(os.path.dirname(SCRIPT)))
        try:
            import qg_answered
        finally:
            sys.path.pop(0)
        calls = []

        def fake_git(repo, *args):
            calls.append(args)
            if args[0] == "rev-parse":
                return 0, b"0123456789abcdef0123456789abcdef01234567\n"
            return 1, b""
        real = qg_answered._git
        qg_answered._git = fake_git
        try:
            self.assertEqual(qg_answered.read_ref(".", "-main", FOLDER), ([], "-main:%s/" % FOLDER))
            self.assertEqual(calls, [])
            self.assertEqual(qg_answered.read_ref(".", "main", FOLDER), ([], "main:%s/" % FOLDER))
            self.assertEqual([c[0] for c in calls], ["rev-parse", "ls-tree"])
        finally:
            qg_answered._git = real

    def test_quiet_answer_keeps_prior(self):
        # 뒤 기록의 새 답이 넘기지 않는 값 셋이면 「전에 한 답」 이 가리킨 앞 답이 그대로 넘어가고,
        # 넘기는 값 둘이면 빠진다(AC14)
        later = rname("R4", "recheck-pr12")
        cases = (("지금은 모르겠다", True), ("답하지 않음", True),
                 ("묻지 않음(상한 넘어 남김)", True), ("의도다", False), ("잘못 골랐다", False))
        for ans, kept in cases:
            e = Env(self)
            route = ROUTE_IN if ans == "잘못 골랐다" else None
            commit_files(e.repo, {rpath(NAME): good_record(2), rpath(later): record(3, [
                section(1, prior=prior_to(NAME + "#1"), ans=ans, route=route)])})
            p = e.run(["main"])
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertEqual(NAME + "#1" in self.keys(e), kept, ans)
            self.assertIn(NAME + "#2", self.keys(e), ans)
            self.assertEqual(e.notice_text(), "", ans)

    def test_multiline_answer_with_heading(self):
        # 답 원문 둘째 줄부터 두 칸 들여 쓴 줄은 그 칸의 이어지는 글 — 그 가운데 `## ` 줄 · `- 답:` 꼴의 줄이
        # 있어도 절이 끊기지 않고(뒤 `- 답한 때:` 를 읽는다) 칸이 겹치지 않는다(AC15)
        raw = "- 답 원문: 첫 줄\n  ## 다른 것\n  - 답: 잘못 골랐다\n  # 제목 꼴\n  끝 줄"
        sec = section(1, at="2026-11-24 10:05").replace("- 답한 때:", raw + "\n- 답한 때:")
        e = Env(self)
        commit_files(e.repo, {rpath(NAME): record(3, [sec, section(2, ans="잘못 골랐다",
                                                                  route=ROUTE_SEED)])})
        p = e.run(["main"])
        self.assertEqual(p.returncode, 0, p.stderr)
        by = {x["key"]: x for x in e.entries()}
        self.assertEqual(sorted(by), [NAME + "#1", NAME + "#2"])
        self.assertEqual(by[NAME + "#1"]["answer"], "의도다")
        self.assertEqual(by[NAME + "#1"]["answered_at"], "2026-11-24 10:05")
        self.assertEqual(by[NAME + "#2"]["route"], ROUTE_SEED)
        self.assertEqual(e.notice_text(), "")

    def test_prior_time_with_separator_unreadable(self):
        # 「전에 한 답」 의 둘째 칸(답한 때)이 꼴 밖이면 열쇠를 짐작하지 않고 그 기록을 읽지 못한 기록으로
        # 센다 — 같은 대상(R4)의 답이 넘어가지 않고 알림이 남는다. 기록의 `- 답한 때:` 가 꼴 밖이어도 같다(AC30)
        later = rname("R4", "recheck-pr12")
        variants = {
            "prior-time-sep": section(1, prior=prior_to(NAME + "#1", at="2026-11-22 · 21:25")),
            "prior-time-iso": section(1, prior=prior_to(NAME + "#1", at="2026-11-22T21:25:00Z")),
            "prior-time-empty": section(1, prior=prior_to(NAME + "#1", at="")),
            "prior-first-cell": section(1, prior=prior_to(NAME + "#1", ans="지금은 모르겠다")),
            "prior-no-key": section(1, prior="의도다 · 2026-11-22 21:25 ·  · 근거가 달라짐"),
            "at-sep": section(1, at="2026-11-22 · 12:16"),
            "at-word": section(1, at="어제"),
            "at-seconds": section(1, at="2026-11-22 12:16:00"),
        }
        for label, sec in variants.items():
            e = Env(self)
            commit_files(e.repo, {rpath(NAME): good_record(2), rpath(NAME2): good_record(),
                                  rpath(later): record(3, [sec])})
            p = e.run(["main"])
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertEqual(self.keys(e), [NAME2 + "#1"], label)
            self.assertEqual(e.notice_text().splitlines(),
                             ["읽지 못한 기록 1개: main:%s" % rpath(later)], label)
        # 양의 짝 — `-` 인 답한 때 · 꼴 안의 답한 때는 읽혀 그 열쇠를 뺀다
        for at in ("-", "2026-11-22 21:25"):
            e = Env(self)
            commit_files(e.repo, {rpath(NAME): good_record(2), rpath(later): record(3, [
                section(1, prior=prior_to(NAME + "#1", at=at), at=at)])})
            p = e.run(["main"])
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertEqual(self.keys(e), [NAME + "#2", later + "#1"], at)
            self.assertEqual(e.notice_text(), "", at)

    def test_prior_identity_with_separator_reads(self):
        # 셋째 칸(정체)에 ` · ` 가 든 「전에 한 답」 은 읽힌다 — 같은 기록의 열쇠 칸이 가리킨 앞 답을 뺀다(AC30)
        later = rname("R4", "recheck-pr12")
        ident_prior = prior_to("diff#a · b.md#갈라짐#방향")
        e = Env(self)
        commit_files(e.repo, {rpath(NAME): good_record(2), rpath(later): record(3, [
            section(1, prior=ident_prior), section(2, prior=prior_to(NAME + "#1"))])})
        p = e.run(["main"])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.keys(e), [NAME + "#2", later + "#1", later + "#2"])
        self.assertEqual(e.notice_text(), "")

    def test_notice_file_fail_keeps_stderr(self):
        # 알림 파일을 쓰지 못하면 rc 4 — 표준 오류에 알림 줄과 끝 줄, 답 파일은 있다(AC16)
        broken = rname("R7")
        e = Env(self)
        commit_files(e.repo, {rpath(NAME): good_record(),
                              rpath(broken): record(3, [section(1, ans="잘못 골랐다")])})
        notice = "읽지 못한 기록 1개: main:%s" % rpath(broken)
        e.notices = os.path.join(e.work, "no-such-dir", "notices.txt")
        p = e.run(["main"])
        self.assertEqual(p.returncode, 4, p.stderr)
        self.assertEqual(p.stderr.splitlines(), [notice, NOTICE_FAIL])
        self.assertEqual(self.keys(e), [NAME + "#1"])
        # 답 파일을 쓰지 못하면 rc 3 — 알림 줄은 그 전에 이미 표준 오류에 있다
        e2 = Env(self)
        commit_files(e2.repo, {rpath(NAME): good_record(),
                               rpath(broken): record(3, [section(1, ans="잘못 골랐다")])})
        p = e2.run(["main"], out=os.path.join(e2.work, "no-such-dir", "out.yaml"))
        self.assertEqual(p.returncode, 3, p.stderr)
        lines = p.stderr.splitlines()
        self.assertEqual(len(lines), 2, lines)
        self.assertEqual(lines[0], notice)
        self.assertTrue(lines[1].startswith(OUT_FAIL), lines[1])
        self.assertNotIn(NOTICE_FAIL, p.stderr)
        # 알림이 없으면 rc 0 · 표준 오류는 비어 있다(양의 짝)
        e3 = Env(self)
        commit_files(e3.repo, {rpath(NAME): good_record()})
        p = e3.run(["main"])
        self.assertEqual((p.returncode, p.stderr), (0, ""))

    def test_no_partial_files_on_fail(self):
        # 바꿔 놓기가 실패하는 두 경우(쓸 자리가 폴더) 모두 임시 파일 · 반쯤 쓴 파일이 남지 않는다(AC29)
        e = Env(self)
        commit_files(e.repo, {rpath(NAME): good_record(),
                              rpath(rname("R7")): record(3, [section(1, ans="잘못 골랐다")])})
        e.notices = os.path.join(e.work, "notices-dir")
        os.makedirs(e.notices)
        p = e.run(["main"])
        self.assertEqual(p.returncode, 4, p.stderr)
        self.assertEqual(sorted(os.listdir(e.work)), ["answered.yaml", "notices-dir"])
        self.assertEqual(os.listdir(e.notices), [])
        self.assertEqual(self.keys(e), [NAME + "#1"])
        e2 = Env(self)
        commit_files(e2.repo, {rpath(NAME): good_record()})
        out_dir = os.path.join(e2.work, "out-dir")
        os.makedirs(out_dir)
        p = e2.run(["main"], out=out_dir)
        self.assertEqual(p.returncode, 3, p.stderr)
        self.assertEqual(sorted(os.listdir(e2.work)), ["out-dir"])
        self.assertEqual(os.listdir(out_dir), [])

    def test_route_missing_contract3_unreadable(self):
        # 3판 기록의 「잘못 골랐다」 에 행선이 없으면 읽지 못한 기록 — 2판은 자리에서 행선을 짓는다
        e = Env(self)
        commit_files(e.repo, {rpath(NAME): good_record(),
                              rpath(rname("R7")): record(3, [section(1, ans="잘못 골랐다")]),
                              rpath(rname("R8")): record(2, [section(1, ans="잘못 골랐다")])})
        p = e.run(["main"])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.keys(e), [NAME + "#1", rname("R8") + "#1"])
        self.assertEqual(e.notice_text().splitlines(),
                         ["읽지 못한 기록 1개: main:%s" % rpath(rname("R7"))])

    def test_record_branch_answer_carries_epic_only_does_not(self):
        # 첫 머지 앞 리뷰의 기록은 기록 브랜치에만, 같은 대상의 다른 기록은 에픽 브랜치에만 있다 — 지휘 절차의
        # 호출 꼴(`--ref <기본 브랜치> --ref <기록 브랜치>`)로 부르면 기록 브랜치의 답만 넘어간다(AC11)
        first = rname("R4", "premerge-pr12")
        epic_only = rname("R4", "recheck-pr12")
        e = Env(self)
        commit_files(e.repo, {"README.md": "x\n"})
        run_git(e.repo, "checkout", "-q", "-b", "docs/conductor-records")
        commit_files(e.repo, {rpath(first): good_record()})
        run_git(e.repo, "checkout", "-q", "main")
        run_git(e.repo, "checkout", "-q", "-b", "feature/r4-epic")
        commit_files(e.repo, {rpath(epic_only): good_record()})
        run_git(e.repo, "checkout", "-q", "main")
        p = e.run(["main", "docs/conductor-records"])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.keys(e), [first + "#1"])
        self.assertEqual(e.notice_text(), "")

    def test_no_yaml_guard(self):
        # PyYAML 을 들일 수 없으면 rc 5 와 한 줄 — 답 파일 · 알림 파일은 쓰지 않는다
        e = Env(self)
        commit_files(e.repo, {rpath(NAME): good_record()})
        argv = [SCRIPT, "--roadmap", ROADMAP, "--ref", "main", "--out", e.out,
                "--notices", e.notices, "--repo", e.repo]
        code = ("import runpy, sys\n"
                "sys.modules['yaml'] = None\n"
                "sys.argv = %r\n"
                "runpy.run_path(%r, run_name='__main__')\n") % (argv, SCRIPT)
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
        p = subprocess.run([sys.executable, "-c", code], cwd=e.work, capture_output=True,
                           text=True, encoding="utf-8", env=env)
        self.assertEqual(p.returncode, 5, p.stderr)
        self.assertEqual(p.stderr.splitlines(), [NO_YAML])
        self.assertEqual(os.listdir(e.work), [])
        # 양의 짝 — 같은 꼴로 막지 않고 부르면 rc 0
        code_ok = code.replace("sys.modules['yaml'] = None\n", "")
        p = subprocess.run([sys.executable, "-c", code_ok], cwd=e.work, capture_output=True,
                           text=True, encoding="utf-8", env=env)
        self.assertEqual(p.returncode, 0, p.stderr)


if __name__ == "__main__":
    unittest.main()
