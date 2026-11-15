"""돌려주는 꼴 2판 — 머리 칸 · 닫힌 어휘 · 결과 줄 · 리뷰 커밋 · 스위치(gate · prepare).

`test_intent_critic.py` 의 헬퍼(`_cli` · `_env` · `_write` · `_read` · `_git_repo` · `_filter_rd` ·
`_out` · `_q` · `_last` · `_return_block`)만 빌린다.
"""
import contextlib
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import test_intent_critic as tic  # noqa: E402

ic = tic._load("intent_critic")

GLOBAL = "DEVBREW_QUALITY_GATES_DISABLE"
STAGE = tic.KILL
KILL_RESULT = "intent-critic 꺼짐(kill switch)"
HEX40 = set("0123456789abcdef")


def _check_vocab(case, block):
    """어느 갈래든 닫힌 어휘 안이다."""
    case.assertEqual(block["contract"], 2)
    case.assertIn(block["status"], ic.RETURN_STATUSES)
    if block["status"] == "skipped":
        case.assertIn(block["reason"], ic.SKIP_REASONS)
    elif block["status"] == "failed":
        case.assertIn(block["reason"], ic.FAIL_REASONS)
    else:
        case.assertEqual(block["reason"], "-")
    if block["status"] == "ran":
        case.assertIn(block["outcome"], ic.RETURN_OUTCOMES)
    else:
        case.assertEqual(block["outcome"], "-")


class TestReturnHead(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.rd = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def _head(self, rd=None):
        text, block = tic._return_block(rd or self.rd)
        _check_vocab(self, block)
        self.assertEqual(block["session_dir"], os.path.abspath(rd or self.rd))
        return text, block

    def _gate(self, path, mode="pr", **env):
        p = tic._cli("gate", "--rd", self.rd, "--path", path, "--mode", mode,
                     env=tic._env(**env))
        self.assertEqual(p.returncode, 0, p.stderr)
        return p

    def _render(self, mode="pr"):
        p = tic._cli("render", "--rd", self.rd, "--mode", mode)
        self.assertEqual(p.returncode, 0, p.stderr)
        return p

    def _filter(self, first):
        tic._write(first, self.rd, "intent-critic-1.txt")
        p = tic._cli("filter", "--rd", self.rd)
        self.assertEqual(p.returncode, 0, p.stderr)

    # ---- gate · prepare 의 건너뜀과 실패

    def test_skip_and_fail_codes(self):
        cases = (("aborted", "skipped", "halted", "멈춘 실행"),
                 ("trivia", "skipped", "trivia", "작은 수정 — trivia"),
                 ("scope-empty", "skipped", "empty-diff", "리뷰할 diff 없음"),
                 ("tree-failed", "failed", "tree-failed", "리뷰 트리를 만들지 못함"))
        for path, status, reason, text in cases:
            with self.subTest(path=path):
                p = self._gate(path, mode="range")
                _t, block = self._head()
                self.assertEqual((block["status"], block["reason"], block["outcome"]),
                                 (status, reason, "-"))
                self.assertEqual(block["reason_text"], text)
                self.assertEqual(block["result_line"], tic._last(p))
                self.assertEqual(block["mode"], "range")

    def test_stage_and_global_switch(self):
        for path, env in (("final", {STAGE: "1"}), ("trivia", {GLOBAL: "1"})):
            with self.subTest(path=path):
                self._gate(path, **env)
                _t, block = self._head()
                self.assertEqual((block["status"], block["reason"], block["outcome"],
                                  block["result_line"]),
                                 ("skipped", "kill-switch", "-", KILL_RESULT))
                var = next(iter(env))
                self.assertEqual(block["reason_text"], "intent-critic 꺼짐(kill switch — %s=1)" % var)

    def test_both_switches_named(self):
        self._gate("final", **{GLOBAL: "1", STAGE: "1"})
        _t, block = self._head()
        self.assertEqual(block["reason_text"],
                         "intent-critic 꺼짐(kill switch — DEVBREW_QUALITY_GATES_DISABLE=1 · "
                         "DEVBREW_QUALITY_GATES_DISABLE_INTENT_CRITIC=1)")

    def test_switch_value_must_be_one(self):
        self._gate("final", **{GLOBAL: "0", STAGE: "yes"})
        self.assertFalse(os.path.exists(os.path.join(self.rd, "intent-return.md")))

    def test_prepare_global_switch_reads_nothing(self):
        tic._write(tic._config_text(), self.rd, "intent-config.txt")
        sp = os.path.join(self.rd, "specs.json")
        tic._write(json.dumps({"intent_source": "spec-trailer", "specs": []}), sp)
        env = tic._env(**{GLOBAL: "1"})
        p = tic._cli("prepare", "--rd", self.rd, "--repo", self.rd, "--tree-root", self.rd,
                     "--mode", "pr", "--head", "HEAD", "--review-commit", "HEAD",
                     "--specs-json", sp, env=env)
        self.assertEqual((p.returncode, tic._last(p)), (0, KILL_RESULT))
        for name in (ic.OTHER_TEAMS, ic.SCOPE):
            self.assertFalse(os.path.lexists(os.path.join(self.rd, name)), name)
        _t, block = self._head()
        self.assertEqual((block["status"], block["reason"], block["result_line"]),
                         ("skipped", "kill-switch", KILL_RESULT))
        self.assertEqual(block["reason_text"],
                         "intent-critic 꺼짐(kill switch — %s=1)" % GLOBAL)

        def boom(*_a, **_k):
            raise AssertionError("다른 팀 읽기가 불렸다")

        saved = ic._teams
        ic._teams = boom
        try:
            ns = ic._parser().parse_args(
                ["prepare", "--rd", self.rd, "--repo", self.rd, "--tree-root", self.rd,
                 "--mode", "pr", "--head", "HEAD", "--review-commit", "HEAD",
                 "--specs-json", sp])
            old = dict(os.environ)
            os.environ[GLOBAL] = "1"
            try:
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(ic.cmd_prepare(ns), 0)
            finally:
                os.environ.clear()
                os.environ.update(old)
        finally:
            ic._teams = saved

    # ---- render 의 갈래

    def test_outcomes(self):
        # 근거 없음 — 리뷰어를 부르지 않았다
        tic._filter_rd(self.rd, call="none")
        self._render()
        _t, b = self._head()
        self.assertEqual((b["status"], b["reason"], b["outcome"], b["reason_text"]),
                         ("skipped", "no-evidence", "-", "근거 없음"))
        self.assertEqual(b["result_line"], "intent-critic — 근거 없음")

        # 셀 수 없음 — 계획 파일이 없다
        with tempfile.TemporaryDirectory() as rd:
            self.rd = rd
            tic._filter_rd(rd)
            os.remove(os.path.join(rd, "intent-plan.txt"))
            p = self._render()
            _t, b = self._head()
            self.assertEqual((b["status"], b["reason"], b["outcome"]), ("uncountable", "-", "-"))
            self.assertEqual(b["reason_text"], "준비 파일(intent-plan.txt)을 읽지 못함")
            self.assertEqual(b["result_line"], tic._last(p))

        # 물은 질문 1
        with tempfile.TemporaryDirectory() as rd:
            self.rd = rd
            tic._filter_rd(rd)
            self._filter(tic._out([tic._q("D1")]))
            p = self._render()
            _t, b = self._head()
            self.assertEqual((b["status"], b["reason"], b["outcome"], b["reason_text"]),
                             ("ran", "-", "questions", "-"))
            self.assertEqual(b["result_line"], tic._last(p))
            self.assertEqual(b["none_reason"], "-")

        # 리뷰어가 낸 질문이 없다
        with tempfile.TemporaryDirectory() as rd:
            self.rd = rd
            tic._filter_rd(rd)
            self._filter(tic._out([], none_reason="물을 것이 없다"))
            p = self._render()
            _t, b = self._head()
            self.assertEqual((b["status"], b["outcome"]), ("ran", "none"))
            self.assertEqual(b["none_reason"], "물을 것이 없다")
            self.assertEqual(b["result_line"], tic._last(p))

        # 낸 질문이 모두 이미 답한 질문
        with tempfile.TemporaryDirectory() as rd:
            self.rd = rd
            tic._filter_rd(rd, answers=[(tic.ID1, "의도다", tic.OBS1)])
            self._filter(tic._out([tic._q("D1", same_as=tic.ID1)]))
            p = self._render()
            _t, b = self._head()
            self.assertEqual((b["status"], b["outcome"]), ("ran", "none"))
            self.assertEqual(b["result_line"], tic._last(p))

        # 좁은 리뷰에서 근거 없는 후보만
        with tempfile.TemporaryDirectory() as rd:
            self.rd = rd
            tic._filter_rd(rd)
            self._filter(tic._out([tic._q("D1", lines=[])]))
            p = self._render()
            _t, b = self._head()
            self.assertEqual((b["status"], b["reason"], b["outcome"]), ("ran", "-", "no-evidence"))
            self.assertEqual(b["result_line"], tic._last(p))

        # 넓은 리뷰에서 근거 없는 후보만
        with tempfile.TemporaryDirectory() as rd:
            self.rd = rd
            tic._filter_rd(rd)
            with open(os.path.join(rd, "intent-plan.txt"), "a", encoding="utf-8") as fh:
                fh.write("breadth: range\n")
            self._filter(tic._out([tic._q("D1", lines=[])]))
            p = self._render()
            _t, b = self._head()
            self.assertEqual((b["status"], b["outcome"]), ("ran", "all-filtered"))
            self.assertEqual(b["result_line"], tic._last(p))
            self.assertIn("모두 걸러짐", b["result_line"])

    def test_none_reason_two_calls_joined(self):
        tic._filter_rd(self.rd, call="split")
        tic._write(tic._out([], none_reason="첫째 이유"), self.rd, "intent-critic-1.txt")
        tic._write(tic._out([], none_reason="둘째 이유"), self.rd, "intent-critic-2.txt")
        p = tic._cli("filter", "--rd", self.rd)
        self.assertEqual(p.returncode, 0, p.stderr)
        self._render()
        _t, b = self._head()
        self.assertEqual(b["none_reason"], "첫째 이유 / 둘째 이유")

    def test_none_reason_is_folded_to_one_line(self):
        tic._filter_rd(self.rd)
        self._filter(tic._out([], none_reason="줄1\n줄2: \"따옴표\" 끝"))
        self._render()
        text, b = self._head()
        self.assertEqual(b["none_reason"], "줄1 줄2: \"따옴표\" 끝")
        self.assertNotIn(" ", text)

    def test_contract_and_session_dir(self):
        for path in ("aborted", "tree-failed"):
            self._gate(path)
            self._head()
        self._gate("final", **{GLOBAL: "1"})
        self._head()
        tic._filter_rd(self.rd, call="none")
        self._render()
        _t, b = self._head()
        self.assertEqual(b["contract"], 2)
        self.assertTrue(os.path.isabs(b["session_dir"]))

    def test_header_key_order(self):
        tic._filter_rd(self.rd)
        self._filter(tic._out([tic._q("D1")]))
        self._render()
        text, _b = self._head()
        keys = []
        for line in text.split("\n"):
            if line and not line.startswith((" ", "`")):
                keys.append(line.split(":", 1)[0])
        self.assertEqual(keys, list(ic.RETURN_KEYS) + ["questions"])
        self.assertEqual(len(ic.RETURN_KEYS), 17)
        self.assertEqual(len(ic.QUESTION_KEYS), 15)

    # ---- 리뷰 커밋

    def test_reviewed_commits_survive_answer_commit(self):
        with tempfile.TemporaryDirectory() as root:
            repo = tic._git_repo(root)
            first = tic._git(repo, "rev-parse", "HEAD").stdout.strip()
            tic._write("y\n", repo, "c.txt")
            tic._git(repo, "add", "c.txt")
            tic._git(repo, "commit", "-q", "-m", "second")
            review = tic._git(repo, "rev-parse", "HEAD").stdout.strip()
            rd = os.path.join(root, "session")
            os.makedirs(rd)
            tic._write(tic._config_text(), rd, "intent-config.txt")
            tic._write("## Goals\nx\n", rd, "intent.md")
            sp = os.path.join(rd, "specs.json")
            tic._write(json.dumps({"intent_source": "spec-trailer", "specs": []}), sp)
            p = tic._cli("prepare", "--rd", rd, "--repo", repo, "--tree-root", repo, "--mode", "pr",
                         "--head", "HEAD", "--review-commit", "HEAD", "--base", first,
                         "--specs-json", sp)
            self.assertEqual(p.returncode, 0, p.stderr)
            tic._write("z\n", repo, "d.txt")
            tic._git(repo, "add", "d.txt")
            tic._git(repo, "commit", "-q", "-m", "answer commit")
            moved = tic._git(repo, "rev-parse", "HEAD").stdout.strip()
            self.assertNotEqual(moved, review)
            r = tic._cli("render", "--rd", rd, "--mode", "pr")
            self.assertEqual(r.returncode, 0, r.stderr)
            _t, b = tic._return_block(rd)
            _check_vocab(self, b)
            self.assertEqual(b["reviewed_head"], review)
            self.assertEqual(b["reviewed_base"], first)
            self.assertEqual(len(b["reviewed_head"]), 40)
            self.assertTrue(set(b["reviewed_head"]) <= HEX40)
            self.assertTrue(os.path.exists(os.path.join(b["session_dir"], b["other_teams"])))

    def test_resolve_commit(self):
        with tempfile.TemporaryDirectory() as root:
            repo = tic._git_repo(root)
            head = tic._git(repo, "rev-parse", "HEAD").stdout.strip()
            self.assertEqual(ic._resolve_commit(repo, "HEAD"), head)
            self.assertEqual(ic._resolve_commit(repo, "-"), "-")
            self.assertEqual(ic._resolve_commit(repo, "--all"), "-")
            self.assertEqual(ic._resolve_commit(repo, "no-such-rev"), "-")
            self.assertEqual(ic._resolve_commit(root + "/nope", "HEAD"), "-")


SIX = (
    # (이름, 기대 상태, mode, record_ran, 레코드 덧칸)
    ("answered", "답함", "pr", True, {"state": "answered", "answer": "잘못 골랐다",
                                      "file": "docs/a.md"}),
    ("failed", "답 기록 실패", "pr", True,
     {"state": "ask", "record_failed": True, "failed_answer": "잘못 골랐다",
      "failure": "답 자리가 심볼릭 링크다"}),
    ("silent", "답하지 않음", "pr", True, {"state": "ask"}),
    ("range", "묻지 않음", "range", False, {"state": "ask"}),
    ("early", "묻지 않음", "pr", False, {"state": "ask"}),
    ("over", "상한 넘어 남김", "pr", True, {"state": "over-cap"}),
)
QUESTION_ORDER = ["n", "id", "state", "answer", "answer_text", "wrong_choice", "failure", "file",
                  "evidence", "question", "target_source", "target_id", "label", "quote",
                  "observation"]


class TestQuestionRows(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.rd = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def _record(self, i, extra):
        rec = {"id": "src#D%d#방향" % i, "identified": True, "state": "ask", "n": i,
               "target_source": "src", "target_id": "D%d" % i, "kind": "방향", "weight": "방향",
               "quote": "구절", "label": "라벨", "question": "질문 %d?" % i,
               "evidence_lines": [1], "observation": ["   1\t[e2e] 관찰 1"],
               "read_quotes": [], "evidence_kinds": ["e2e"]}
        rec.update(extra)
        return rec

    def _seed(self, extras, mode="pr", record_ran=True):
        tic._filter_rd(self.rd, mode=mode)
        data = {"status": "ran", "call": "first-only", "counts": {}, "notices": [],
                "commit": "-", "commit_line": "", "none_reason": "-",
                "questions": [self._record(i + 1, e) for i, e in enumerate(extras)]}
        if record_ran:
            data["record_ran"] = True
        tic._write(ic.yaml.safe_dump(data, allow_unicode=True, sort_keys=False),
                   self.rd, "intent-questions.yaml")

    def _render(self, mode="pr"):
        p = tic._cli("render", "--rd", self.rd, "--mode", mode)
        self.assertEqual(p.returncode, 0, p.stderr)
        return p

    def test_six_paths_give_five_states(self):
        for name, state, mode, ran, extra in SIX:
            with self.subTest(name=name):
                with tempfile.TemporaryDirectory() as rd:
                    self.rd = rd
                    self._seed([extra], mode=mode, record_ran=ran)
                    self._render(mode)
                    _t, block = tic._return_block(rd)
                    row = block["questions"][0]
                    self.assertEqual(row["state"], state)
                    result = tic._read(rd, "result.md")
                    self.assertIn("| %s | %s |" % (row["id"], state), result)
                    if name == "failed":
                        self.assertEqual(row["answer"], "잘못 골랐다")
                        self.assertIs(row["wrong_choice"], True)
                        self.assertEqual(row["failure"], "답 자리가 심볼릭 링크다")
        self.assertEqual(len(set(s for _n, s, _m, _r, _e in SIX)), 5)

    def test_result_line_counts_match_states(self):
        self._seed([SIX[0][4], SIX[1][4], SIX[2][4], SIX[2][4]])
        p = self._render()
        line = "intent-critic — 질문 4개를 물었다 · 답 1개(잘못 골랐다 1개) · 답하지 않음 2개"
        self.assertEqual(tic._last(p), line)
        _t, block = tic._return_block(self.rd)
        self.assertEqual(block["result_line"], line)
        self.assertEqual([r["state"] for r in block["questions"]].count("답하지 않음"), 2)

    def test_not_asked_lines(self):
        cases = (("range", False, "intent-critic — 질문 2개 묻지 않음(범위 모드)"),
                 ("pr", False, "intent-critic — 질문 2개 묻지 않음(묻기 전에 끝남)"))
        for mode, ran, line in cases:
            with self.subTest(mode=mode):
                with tempfile.TemporaryDirectory() as rd:
                    self.rd = rd
                    self._seed([{"state": "ask"}, {"state": "ask"}], mode=mode, record_ran=ran)
                    p = self._render(mode)
                    _t, block = tic._return_block(rd)
                    self.assertEqual(tic._last(p), line)
                    self.assertEqual(block["result_line"], line)
                    self.assertNotIn("물었다", block["result_line"])
                    self.assertNotIn("물었다", tic._last(p))

    def test_wrong_choice_is_bool_text(self):
        self._seed([SIX[0][4], SIX[2][4]])
        self._render()
        text, _b = tic._return_block(self.rd)
        self.assertIn("    wrong_choice: true\n", text)
        self.assertIn("    wrong_choice: false\n", text)
        self.assertNotIn("wrong_choice: yes", text)
        self.assertNotIn("wrong_choice: no\n", text)

    def test_question_fields_carried(self):
        tic._filter_rd(self.rd)
        tic._write(tic._out([tic._q("D1", lines=[1, 2])]), self.rd, "intent-critic-1.txt")
        p = tic._cli("filter", "--rd", self.rd)
        self.assertEqual(p.returncode, 0, p.stderr)
        self._render()
        rec = tic._questions(self.rd)["questions"][0]
        _t, block = tic._return_block(self.rd)
        row = block["questions"][0]
        for key in ("question", "target_source", "target_id", "label", "quote"):
            self.assertEqual(row[key], rec[key], key)
        self.assertEqual(row["observation"], [ic._one_line(x) for x in rec["observation"]])
        self.assertEqual(len(row["observation"]), 2)
        self.assertEqual(row["n"], 1)

    def test_numbers_unique_per_run(self):
        tic._filter_rd(self.rd, answers=[(tic.ID1, "의도다", tic.OBS1)])
        items = [tic._q("D2"), tic._q("D2"), tic._q("D3"), tic._q("D4"), tic._q("D5"),
                 tic._q("D1", same_as=tic.ID1)]
        tic._write(tic._out(items), self.rd, "intent-critic-1.txt")
        p = tic._cli("filter", "--rd", self.rd)
        self.assertEqual(p.returncode, 0, p.stderr)
        records = tic._questions(self.rd)["questions"]
        numbered = [r for r in records if r["state"] in ("ask", "over-cap")]
        self.assertEqual(sorted(r["n"] for r in numbered), [1, 2, 3, 4, 5])
        self.assertTrue([r for r in numbered if r["state"] == "over-cap"])
        for rec in records:
            if rec["state"] not in ("ask", "over-cap"):
                self.assertNotIn("n", rec)
        self._render()
        _t, block = tic._return_block(self.rd)
        self.assertEqual(sorted(r["n"] for r in block["questions"]), [1, 2, 3, 4, 5])

    def test_text_fields_are_folded_and_parse(self):
        bad = "줄\n바꿈\u2028가름\u202e방향 \"따옴표\" a: b"
        self._seed([{"question": bad, "label": bad, "quote": bad,
                     "observation": ["관찰\x07 하나\n둘", "   2\t[e2e] 관찰 2"]}])
        self._render()
        text, block = tic._return_block(self.rd)
        row = block["questions"][0]
        for key in ("question", "label", "quote"):
            for ch in ("\n", "\u2028", "\u202e", "\x07"):
                self.assertNotIn(ch, row[key], key)
        for line in row["observation"]:
            for ch in ("\n", "\u2028", "\u202e", "\x07"):
                self.assertNotIn(ch, line)
        for ch in ("\u2028", "\u202e", "\x07"):
            self.assertNotIn(ch, text)
        self.assertEqual(text.count("    question: "), 1)
        self.assertIn("\"따옴표\" a: b", row["question"])

    def test_question_keys_in_order(self):
        self._seed([SIX[0][4]])
        self._render()
        text, _b = tic._return_block(self.rd)
        keys = []
        for line in text.split("\n"):
            if line.startswith("  - "):
                keys.append(line[4:].split(":", 1)[0])
            elif line.startswith("    ") and not line.startswith("     "):
                keys.append(line.strip().split(":", 1)[0])
        self.assertEqual(keys, QUESTION_ORDER)


if __name__ == "__main__":
    unittest.main()
