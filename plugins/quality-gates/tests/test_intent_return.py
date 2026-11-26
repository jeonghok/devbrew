"""돌려주는 꼴 3판 — 머리 칸 · 닫힌 어휘 · 결과 줄 · 리뷰 커밋 · 스위치(gate · prepare).

`test_intent_critic.py` 의 헬퍼(`_cli` · `_env` · `_write` · `_read` · `_git_repo` · `_filter_rd` ·
`_out` · `_q` · `_last` · `_return_block`)만 빌린다.
"""
import contextlib
import io
import json
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import test_intent_critic as tic  # noqa: E402

ic = tic._load("intent_critic")

GLOBAL = "DEVBREW_QUALITY_GATES_DISABLE"
STAGE = tic.KILL
HEX40 = set("0123456789abcdef")


def _check_vocab(case, block):
    """어느 갈래든 닫힌 어휘 안이다."""
    case.assertEqual(block["contract"], 3)
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
    for row in block["questions"]:
        case.assertIn(row["state"], ic.QUESTION_STATES)


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

    def test_retired_switches_do_not_skip_gate(self):
        # 은퇴한 의도 점검 끄기 · 통째 끄기는 더 듣지 않는다 — 켜도 gate 가 실행 줄을 낸다.
        # 짝: 건너뛰는 길(trivia)은 같은 환경에서도 건너뜀 블록을 쓴다.
        for env in ({STAGE: "1"}, {GLOBAL: "1"}, {GLOBAL: "1", STAGE: "1"}):
            with self.subTest(env=env):
                p = self._gate("final", **env)
                self.assertEqual(p.stdout, "intent-gate: run\n")
                self.assertFalse(os.path.exists(os.path.join(self.rd, "intent-return.md")))
        p = self._gate("trivia", **{GLOBAL: "1", STAGE: "1"})
        _t, block = self._head()
        self.assertEqual((block["status"], block["reason"]), ("skipped", "trivia"))
        self.assertEqual(block["result_line"], tic._last(p))

    def test_retired_switches_do_not_stop_prepare(self):
        # prepare 도 은퇴한 두 변수를 읽지 않는다 — 다른 팀 기록 · scope 칸을 평소대로 쓴다.
        tic._write(tic._config_text(), self.rd, "intent-config.txt")
        sp = os.path.join(self.rd, "specs.json")
        tic._write(json.dumps({"intent_source": "spec-trailer", "specs": []}), sp)
        env = tic._env(**{GLOBAL: "1", STAGE: "1"})
        p = tic._cli("prepare", "--rd", self.rd, "--repo", self.rd, "--tree-root", self.rd,
                     "--mode", "pr", "--head", "HEAD", "--review-commit", "HEAD",
                     "--specs-json", sp, env=env)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertTrue(tic._last(p).startswith("intent-call: "), p.stdout)
        self.assertNotIn("꺼짐", p.stdout)
        self.assertFalse(os.path.exists(os.path.join(self.rd, "intent-return.md")))

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
        self._gate("trivia")
        self._head()
        tic._filter_rd(self.rd, call="none")
        self._render()
        _t, b = self._head()
        self.assertEqual(b["contract"], 3)
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
        self.assertEqual(len(ic.RETURN_KEYS), 18)
        self.assertEqual(ic.RETURN_KEYS[-1], "answered_filtered")
        self.assertEqual(len(ic.QUESTION_KEYS), 18)

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
                  "observation", "why", "asked_before", "changed_observation"]


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

    def test_failure_and_answer_text_cells_are_folded(self):
        """답 기록 실패 행의 `answer` · `failure` · `answer_text`(목록 꼴) · 원문 칸도 한 줄로 접힌다."""
        bad = "줄\n바꿈 가름‮방향\x07종 \"따옴표\" a: b"
        self._seed([{"record_failed": True, "failed_answer": bad, "failure": bad,
                     "answer_text": ["첫 " + bad, "둘째 줄"], "target_source": bad,
                     "target_id": bad}])
        self._render()
        text, block = tic._return_block(self.rd)
        row = block["questions"][0]
        self.assertEqual(row["state"], "답 기록 실패")
        for key in ("answer", "failure", "target_source", "target_id"):
            self.assertEqual(row[key], ic._one_line(bad), key)
        self.assertEqual(row["answer_text"], [ic._one_line("첫 " + bad), "둘째 줄"])
        for ch in (" ", "‮", "\x07"):
            self.assertNotIn(ch, text)
        self.assertIn("    answer_text:\n      - %s\n      - \"둘째 줄\"\n"
                      % json.dumps(ic._one_line("첫 " + bad), ensure_ascii=False), text)
        self.assertIs(row["wrong_choice"], False)


ANS_DIR = tic.ANS_DIR
BLOCKED = "거르기 결과 · 설정 · 답 입력 중 읽지 못한 것이 있다"
MISMATCH = "정체가 맞지 않는 답 머리"


class TestAnswerInput(unittest.TestCase):
    """답 입력 — 질문 번호 머리 · 정체가 맞지 않는 머리(4a) · 답이 있던 질문에만 실패 표지(4b) · record 의 스위치."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = os.path.join(self.tmp.name, "repo")
        os.makedirs(self.repo)
        tic._git_repo(self.repo)
        self.rd = os.path.join(self.tmp.name, "rd")
        os.makedirs(self.rd)

    def tearDown(self):
        self.tmp.cleanup()

    def _asked(self, cands):
        tic._filter_rd(self.rd)
        tic._write(tic._out(cands), self.rd, "intent-critic-1.txt")
        p = tic._cli("filter", "--rd", self.rd)
        self.assertEqual(tic._last(p), "intent-ask: %d" % len(cands))
        return [(q["n"], q["id"]) for q in tic._by_state(self.rd, "ask")]

    def _two(self):
        return self._asked([tic._q("D1"), tic._q("D2", kind="기본값", weight="동작")])

    def _head(self, q, pick):
        return "=== n: %d · id: %s · pick: %s\n" % (q[0], q[1], pick)

    def _record(self, text, env=None, answers=None):
        path = answers or os.path.join(self.tmp.name, "answers.txt")
        if text is not None:
            tic._write(text, path)
        p = tic._cli("record", "--rd", self.rd, "--repo", self.repo, "--answers", path, env=env)
        self.assertEqual(p.returncode, 0, p.stderr)
        return p

    def _render(self):
        r = tic._cli("render", "--rd", self.rd, "--mode", "pr")
        self.assertEqual(r.returncode, 0, r.stderr)
        text, block = tic._return_block(self.rd)
        _check_vocab(self, block)
        rows = {}
        for row in block["questions"]:
            rows[row["n"]] = row
        return tic._last(r), rows, text

    def _files(self):
        d = os.path.join(self.repo, ANS_DIR)
        return sorted(os.listdir(d)) if os.path.isdir(d) else []

    def _body(self, name):
        return tic._read(self.repo, ANS_DIR, name)

    def test_second_of_same_identity(self):
        qs = self._asked([tic._q("D1", question="첫째 글"), tic._q("D1", question="둘째 글")])
        self.assertEqual(qs[0][1], qs[1][1])
        p = self._record(tic._header(self.rd, qs[0][1], "의도다", nth=2) + "\n")
        self.assertEqual(tic._last(p), "record: 1")
        files = self._files()
        self.assertEqual(len(files), 1)
        body = self._body(files[0])
        self.assertIn("## 질문\n\n둘째 글", body)
        self.assertNotIn("첫째 글", body)
        _line, rows, _t = self._render()
        self.assertEqual(rows[qs[1][0]]["state"], "답함")
        self.assertTrue(rows[qs[1][0]]["question"].startswith("둘째 글"))
        self.assertEqual(rows[qs[0][0]]["state"], "답하지 않음")
        self.assertTrue(rows[qs[0][0]]["question"].startswith("첫째 글"))

    def test_empty_input_marks_unanswered(self):
        self._two()
        p = self._record("")
        self.assertEqual(p.stdout.splitlines(), ["record: 0"])
        line, rows, _t = self._render()
        self.assertEqual([r["state"] for r in rows.values()], ["답하지 않음", "답하지 않음"])
        self.assertEqual(line, "intent-critic — 질문 2개를 물었다 · 답 0개(잘못 골랐다 0개) · 답하지 않음 2개")

    def test_wrong_header_after_typed_answer(self):
        qs = self._two()
        text = (self._head(qs[0], "typed") + "이유 글\n"
                + "=== n: %d · id: 틀린#정체#방향 · pick: 잘못 골랐다\n딸린 글\n" % qs[1][0])
        p = self._record(text)
        lines = p.stdout.splitlines()
        self.assertIn(MISMATCH + " 1개", lines)
        self.assertEqual(tic._last(p), "record: 1")
        files = self._files()
        self.assertEqual(len(files), 1)
        raw = self._body(files[0]).split("## 답 원문\n", 1)[1]
        self.assertEqual(raw.strip(), "이유 글")
        for part in ("딸린 글", "=== n:", "틀린#정체"):
            self.assertNotIn(part, raw)
        _line, rows, _t = self._render()
        first, second = rows[qs[0][0]], rows[qs[1][0]]
        self.assertEqual((first["state"], first["answer_text"]), ("답함", ["이유 글"]))
        self.assertEqual((second["state"], second["answer"], second["wrong_choice"], second["failure"]),
                         ("답 기록 실패", "잘못 골랐다", True, MISMATCH))
        self.assertEqual(second["answer_text"], "-")

    def test_unknown_number_only_disclosed(self):
        qs = self._two()
        p = self._record("=== n: 9 · id: x · pick: 의도다\n=== id: %s · pick: 의도다\n" % qs[0][1])
        self.assertIn(MISMATCH + " 2개", p.stdout.splitlines())
        self.assertNotIn("답 기록 실패", p.stdout)
        self.assertEqual(tic._last(p), "record: 0")
        self.assertEqual(self._files(), [])
        self.assertIn(MISMATCH + " 2개", tic._questions(self.rd)["record_notices"])
        _line, rows, _t = self._render()
        self.assertEqual([r["state"] for r in rows.values()], ["답하지 않음", "답하지 않음"])

    def test_duplicate_number_first_wins(self):
        qs = self._two()
        p = self._record(self._head(qs[0], "의도다") + self._head(qs[0], "잘못 골랐다"))
        line = "같은 질문 번호의 답 머리를 한 번만 받았다 — 더 나온 머리 1개"
        self.assertIn(line, p.stdout.splitlines())
        self.assertIn(line, tic._questions(self.rd)["record_notices"])
        self.assertEqual(tic._last(p), "record: 1")
        files = self._files()
        self.assertEqual(len(files), 1)
        self.assertEqual(ic.ia.parse_answer_file(self._body(files[0]))["answer"], "의도다")
        _line, rows, _t = self._render()
        self.assertEqual((rows[qs[0][0]]["state"], rows[qs[0][0]]["answer"]), ("답함", "의도다"))
        self.assertEqual(rows[qs[1][0]]["state"], "답하지 않음")

    def test_received_answer_beats_identity_wrong_header(self):
        """같은 번호에 정체가 틀린 머리가 먼저 오고 받은 머리가 뒤따르면 받은 답이 이긴다 — 그 질문은 답함이다."""
        qs = self._two()
        text = ("=== n: %d · id: 틀린#정체#방향 · pick: 잘못 골랐다\n" % qs[0][0]
                + self._head(qs[0], "의도다"))
        p = self._record(text)
        self.assertIn(MISMATCH + " 1개", p.stdout.splitlines())
        self.assertNotIn("답 기록 실패", p.stdout)
        self.assertEqual(tic._last(p), "record: 1")
        _line, rows, _t = self._render()
        self.assertEqual((rows[qs[0][0]]["state"], rows[qs[0][0]]["answer"]), ("답함", "의도다"))
        self.assertEqual(rows[qs[1][0]]["state"], "답하지 않음")

    def test_huge_number_header_counts_as_mismatched(self):
        """5000자리 번호의 머리는 숫자로 읽지 않고(파이썬 3.11 이상의 자릿수 한도) 맞지 않는 머리로 센다."""
        qs = self._two()
        huge = "=== n: " + "9" * 5000 + " · id: x · pick: 의도다\n"
        self.assertEqual(ic._header_parts(huge.rstrip("\n"))[0], None)
        p = self._record(huge + self._head(qs[0], "의도다"))
        lines = p.stdout.splitlines()
        self.assertIn(MISMATCH + " 1개", lines)
        self.assertEqual(tic._last(p), "record: 1")
        _line, rows, _t = self._render()
        self.assertEqual(rows[qs[0][0]]["state"], "답함")
        self.assertEqual(rows[qs[1][0]]["state"], "답하지 않음")

    def test_unreadable_pick_fails_that_question(self):
        """번호 · 정체는 맞는데 고른 것이 라벨 · typed 가 아니다 — 그 질문은 답 기록 실패(답 모름)이고 아래 글은
        어디에도 싣지 않는다."""
        qs = self._two()
        p = self._record(self._head(qs[0], "아마") + "딸린 글\n" + self._head(qs[1], "typed") + "의도다\n")
        lines = p.stdout.splitlines()
        self.assertIn("답 기록 실패 1개 — 답을 읽지 못함", lines)
        self.assertNotIn(MISMATCH, p.stdout)
        self.assertFalse([l for l in lines if l.startswith("머리 앞의")], lines)
        self.assertEqual(tic._last(p), "record: 1")
        raw = self._body(self._files()[0]).split("## 답 원문\n", 1)[1]
        self.assertEqual(raw.strip(), "의도다")
        _line, rows, _t = self._render()
        first, second = rows[qs[0][0]], rows[qs[1][0]]
        self.assertEqual((first["state"], first["answer"], first["failure"], first["answer_text"]),
                         ("답 기록 실패", "-", "답을 읽지 못함", "-"))
        self.assertEqual((second["state"], second["answer_text"]), ("답함", ["의도다"]))

    def test_typed_line_starting_with_equals_stays_text(self):
        qs = self._two()
        p = self._record(self._head(qs[0], "typed") + "의도다 — 이유\n=== 메모 ===\n===\n")
        self.assertNotIn(MISMATCH, p.stdout)
        self.assertEqual(tic._last(p), "record: 1")
        raw = self._body(self._files()[0]).split("## 답 원문\n", 1)[1]
        self.assertEqual(raw.strip(), "의도다 — 이유\n=== 메모 ===\n===")
        _line, rows, _t = self._render()
        self.assertEqual(rows[qs[0][0]]["answer_text"], ["의도다 — 이유", "=== 메모 ===", "==="])

    def test_failed_answer_carried(self):
        qs = self._asked([tic._q("D1")])
        with tempfile.TemporaryDirectory() as other:
            os.makedirs(os.path.join(self.repo, "docs"))
            os.symlink(other, os.path.join(self.repo, ANS_DIR))
            p = self._record(self._head(qs[0], "typed") + "잘못 골랐다 — 이유\n둘째 줄\n")
            self.assertEqual(os.listdir(other), [])
        self.assertEqual(tic._last(p), "record: 0")
        line, rows, _t = self._render()
        row = rows[qs[0][0]]
        self.assertEqual((row["state"], row["answer"], row["wrong_choice"], row["failure"]),
                         ("답 기록 실패", "잘못 골랐다", True, "답 자리가 심볼릭 링크다"))
        self.assertEqual(row["answer_text"], ["잘못 골랐다 — 이유", "둘째 줄"])
        # 답 기록이 돌았다 — 「묻기 전에 끝남」 이 아니다.
        self.assertEqual(line, "intent-critic — 질문 1개를 물었다 · 답 0개(잘못 골랐다 0개)")

    def test_typed_answer_text_folded_in_return(self):
        qs = self._asked([tic._q("D1")])
        self._record(self._head(qs[0], "typed") + "의도다 — 숨은 줄\x07종‮방향\n")
        _line, rows, text = self._render()
        self.assertEqual(rows[qs[0][0]]["answer_text"], [ic._one_line("의도다 — 숨은 줄\x07종‮방향")])
        for ch in (" ", "\x07", "‮"):
            self.assertNotIn(ch, text)

    def test_typed_answer_text_on_success(self):
        qs = self._two()
        p = self._record(self._head(qs[0], "typed") + "의도다 — 첫 줄\n둘째 줄\n"
                         + self._head(qs[1], "잘못 골랐다"))
        self.assertEqual(tic._last(p), "record: 2")
        _line, rows, text = self._render()
        first, second = rows[qs[0][0]], rows[qs[1][0]]
        self.assertEqual((first["state"], first["answer"], first["answer_text"]),
                         ("답함", "의도다", ["의도다 — 첫 줄", "둘째 줄"]))
        self.assertEqual((second["state"], second["answer"], second["answer_text"]),
                         ("답함", "잘못 골랐다", "-"))
        self.assertIn("    answer_text:\n      - \"의도다 — 첫 줄\"\n      - \"둘째 줄\"\n", text)

    def test_unreadable_config_fails_only_answered(self):
        qs = self._two()
        os.remove(os.path.join(self.rd, "intent-config.txt"))
        p = self._record(self._head(qs[0], "잘못 골랐다"))
        lines = p.stdout.splitlines()
        self.assertEqual(lines[0], "답을 기록하지 못했다 — " + BLOCKED)
        self.assertIn("답 기록 실패 1개 — " + BLOCKED, lines)
        self.assertEqual(tic._last(p), "record: 0")
        line, rows, _t = self._render()
        first, second = rows[qs[0][0]], rows[qs[1][0]]
        self.assertEqual((first["state"], first["answer"], first["wrong_choice"], first["failure"]),
                         ("답 기록 실패", "잘못 골랐다", True, BLOCKED))
        self.assertEqual(second["state"], "답하지 않음")
        self.assertEqual(line, "intent-critic — 질문 2개를 물었다 · 답 0개(잘못 골랐다 0개) · 답하지 않음 1개")

    def test_stray_text_does_not_fail_others(self):
        qs = self._two()
        p = self._record("잘못 골랐다\n" + self._head(qs[0], "의도다"))
        self.assertIn("머리 앞의 답 글을 읽지 못함 1줄", p.stdout.splitlines())
        self.assertNotIn("답 기록 실패", p.stdout)
        self.assertEqual(tic._last(p), "record: 1")
        _line, rows, _t = self._render()
        self.assertEqual(rows[qs[0][0]]["state"], "답함")
        self.assertEqual(rows[qs[1][0]]["state"], "답하지 않음")

    def test_unreadable_input_file_keeps_failure(self):
        qs = self._two()
        p = self._record(None, answers=os.path.join(self.tmp.name, "none.txt"))
        self.assertIn("답 기록 실패 2개 — " + BLOCKED, p.stdout.splitlines())
        self.assertEqual(tic._last(p), "record: 0")
        line, rows, _t = self._render()
        for q in qs:
            self.assertEqual((rows[q[0]]["state"], rows[q[0]]["answer"]), ("답 기록 실패", "-"))
        self.assertEqual(line, "intent-critic — 질문 2개를 물었다 · 답 0개(잘못 골랐다 0개)")

    def test_retired_switches_do_not_stop_record(self):
        # 은퇴한 두 변수는 record 를 막지 않는다 — 켜도 답 파일을 쓰고 커밋한다.
        # 짝: 같은 입력이 끄기 변수 없이도 같은 파일 수를 쓴다(test_second_of_same_identity 의 꼴).
        for var in (STAGE, GLOBAL):
            with self.subTest(var=var):
                qs = self._two()
                env = tic._env(**{var: "1"})
                p = self._record(self._head(qs[0], "의도다"), env=env)
                self.assertEqual(tic._last(p), "record: 1")
                self.assertNotIn("꺼짐", p.stdout)
                self.assertEqual(len(self._files()), 1)
                self.assertEqual(tic._git(self.repo, "status", "--porcelain").stdout, "")
                shutil.rmtree(os.path.join(self.repo, "docs"))
                tic._git(self.repo, "reset", "--hard", "-q", "HEAD~1")


STATE_DOC = tic.REFERENCE.parent / "state-file-format.md"
# 상태 문서에서 칸 목록을 싣는 일곱 줄의 머리(글자 그대로 — 뒤는 백틱 토큰만).
DOC_HEADS = (
    "- 머리 칸(차례대로):",
    "- 질문 칸(차례대로):",
    "- 칸 `status` 의 값:",
    "- 칸 `reason` 의 값(skipped):",
    "- 칸 `reason` 의 값(failed):",
    "- 칸 `outcome` 의 값(ran):",
    "- 질문 칸 `state` 의 값:",
)


def _doc_tokens(text, head):
    """`head` 로 시작하는 줄이 정확히 하나면 그 뒤의 백틱 토큰들, 아니면 None."""
    lines = []
    for line in text.split("\n"):
        if line.startswith(head):
            lines.append(line)
    if len(lines) != 1:
        return None
    return lines[0][len(head):].split("`")[1::2]


def _code_lists(keys=None, questions=None, statuses=None, skips=None, fails=None,
                outcomes=None, states=None):
    """상수에서 낸 일곱 목록 — 인자로 상수 튜플을 바꿔 끼울 수 있다(변이용)."""
    return [list(keys if keys is not None else ic.RETURN_KEYS) + ["questions"],
            list(questions if questions is not None else ic.QUESTION_KEYS),
            list(statuses if statuses is not None else ic.RETURN_STATUSES),
            list(skips if skips is not None else ic.SKIP_REASONS),
            list(fails if fails is not None else ic.FAIL_REASONS),
            list(outcomes if outcomes is not None else ic.RETURN_OUTCOMES),
            list(states if states is not None else ic.QUESTION_STATES)]


def _doc_mismatches(text, expected):
    """문서의 일곱 줄 가운데 기대 목록과 다른 줄의 머리 — 같은 비교를 락과 이빨 시험이 함께 쓴다."""
    bad = []
    for head, want in zip(DOC_HEADS, expected):
        if _doc_tokens(text, head) != want:
            bad.append(head)
    return bad


def _edit_line(text, head, edit):
    """`head` 로 시작하는 줄을 edit(줄) 로 바꾼 글(줄이 없으면 그대로)."""
    out = []
    for line in text.split("\n"):
        if line.startswith(head):
            line = edit(line)
        out.append(line)
    return "\n".join(out)


class TestReturnDoc(unittest.TestCase):
    """상태 문서의 칸 목록 · 수명 문장 · 절차 I2 · I7 의 글이 코드와 같다(AC9 · AC17)."""

    @classmethod
    def setUpClass(cls):
        cls.state = STATE_DOC.read_text(encoding="utf-8")
        cls.proc = tic.REFERENCE.read_text(encoding="utf-8")

    def _section(self, head):
        self.assertEqual(self.proc.count("\n## %s\n" % head), 1, head)
        return self.proc.split("\n## %s\n" % head, 1)[1].split("\n## ", 1)[0]

    def test_doc_lists_match_code(self):
        self.assertEqual(_doc_mismatches(self.state, _code_lists()), [])
        for head, want in zip(DOC_HEADS, _code_lists()):
            self.assertEqual(_doc_tokens(self.state, head), want, head)

    def test_written_keys_match_code(self):
        """실제 render 가 쓴 꼴의 칸 차례가 상수와 같다 — 문서 · 상수 · 쓰인 파일 셋이 이어진다."""
        with tempfile.TemporaryDirectory() as rd:
            tic._filter_rd(rd, mode="pr")
            rec = {"id": "src#D1#방향", "identified": True, "state": "ask", "n": 1,
                   "target_source": "src", "target_id": "D1", "kind": "방향", "weight": "방향",
                   "quote": "구절", "label": "라벨", "question": "질문?",
                   "evidence_lines": [1], "observation": ["   1\t[e2e] 관찰 1"],
                   "read_quotes": [], "evidence_kinds": ["e2e"]}
            data = {"status": "ran", "call": "first-only", "counts": {}, "notices": [],
                    "commit": "-", "commit_line": "", "none_reason": "-", "record_ran": True,
                    "questions": [rec]}
            tic._write(ic.yaml.safe_dump(data, allow_unicode=True, sort_keys=False),
                       rd, "intent-questions.yaml")
            p = tic._cli("render", "--rd", rd, "--mode", "pr")
            self.assertEqual(p.returncode, 0, p.stderr)
            text, _block = tic._return_block(rd)
        head_keys = []
        question_keys = []
        for line in text.split("\n"):
            if line.startswith("  - "):
                question_keys.append(line[4:].split(":", 1)[0])
            elif line.startswith("    ") and not line.startswith("     "):
                question_keys.append(line.strip().split(":", 1)[0])
            elif line[:1].isalpha():
                head_keys.append(line.split(":", 1)[0])
        want = _code_lists()
        self.assertEqual(head_keys, want[0])
        self.assertEqual(question_keys, want[1])
        self.assertEqual(_doc_tokens(self.state, DOC_HEADS[0]), head_keys)
        self.assertEqual(_doc_tokens(self.state, DOC_HEADS[1]), question_keys)

    def test_doc_lock_has_teeth(self):
        """같은 비교를 변이한 글 · 상수에 돌려 불일치를 본다 — 지우기 · 값 바꾸기 · 더하기 · 순서 · 줄 없음."""
        good = _code_lists()
        self.assertEqual(_doc_mismatches(self.state, good), [])  # 양성 대조
        for head, want in zip(DOC_HEADS, good):
            first = "`%s`" % want[0]
            second = "`%s`" % want[1] if len(want) > 1 else None
            variants = {
                "delete": lambda l: l.replace(first, "", 1),
                "change": lambda l: l.replace(first, "`%sx`" % want[0], 1),
                "add": lambda l: l.replace(first, first + " · `extra`", 1),
                "drop-line": lambda l: "- 지워진 줄",
            }
            if second is not None:
                variants["swap"] = lambda l: l.replace(first, "@@", 1).replace(second, first, 1).replace("@@", second, 1)
            for name, edit in variants.items():
                mutated = _edit_line(self.state, head, edit)
                self.assertNotEqual(mutated, self.state, (head, name))
                self.assertEqual(_doc_mismatches(mutated, good), [head], (head, name))
        # 칸 값 바꾸기 — 글자 그대로 skipped -> skip
        skip = _edit_line(self.state, DOC_HEADS[2], lambda l: l.replace("`skipped`", "`skip`", 1))
        self.assertEqual(_doc_mismatches(skip, good), [DOC_HEADS[2]])
        # contract 뒤에 extra 더하기
        extra = _edit_line(self.state, DOC_HEADS[0], lambda l: l.replace("`contract`", "`contract` · `extra`", 1))
        self.assertEqual(_doc_mismatches(extra, good), [DOC_HEADS[0]])
        # 같은 머리의 줄이 둘이면 읽지 않는다
        twice = self.state + "\n" + DOC_HEADS[3] + " `halted`\n"
        self.assertIn(DOC_HEADS[3], _doc_mismatches(twice, good))
        # 상수 쪽 변이 — 튜플에서 하나 지움 · 하나 더함
        for kw, src in (("keys", ic.RETURN_KEYS), ("questions", ic.QUESTION_KEYS),
                        ("statuses", ic.RETURN_STATUSES), ("skips", ic.SKIP_REASONS),
                        ("fails", ic.FAIL_REASONS), ("outcomes", ic.RETURN_OUTCOMES),
                        ("states", ic.QUESTION_STATES)):
            for mutated in (tuple(src[1:]), tuple(src) + ("extra",)):
                bad = _doc_mismatches(self.state, _code_lists(**{kw: mutated}))
                self.assertEqual(len(bad), 1, (kw, mutated))

    def test_contract_three_in_both_docs(self):
        """상태 문서의 판 줄 · 제목 · 새 칸의 뜻 줄과 I7 의 3판 문장이 코드의 판과 같다(AC7 문서 쪽)."""
        self.assertEqual(ic.CONTRACT, 3)
        self.assertEqual(self.state.count("- `contract` — 꼴의 판(`3`)."), 1)
        self.assertEqual(self.state.count("## 돌려주는 꼴 — `intent-return.md` (3판)"), 1)
        for meaning in ("- `answered_filtered` — 이미 답해 거른 질문의 수(정수).",
                        "- `why` — 리뷰어가 쓴 「왜 묻나」 한 줄 그대로",
                        "- `asked_before` — ",
                        "- `changed_observation` — "):
            self.assertEqual(self.state.count(meaning), 1, meaning)
        self.assertIn("`<전 답> · <답한 때> · <열쇠 또는 정체> · <근거가 달라짐 | 고친 뒤에도 보임>`", self.state)
        self.assertIn("넘겨받은 답[ · 미뤄 둔 의심][ · 정체가 다름 — <그때> → <지금>]", self.state)
        i7 = self._section("I7 돌려주기")
        self.assertEqual(i7.count("`$RD/intent-return.md`(3판) 를 Read 로 읽어"), 1)
        self.assertNotIn("(2판)", i7)
        for cell in ("`answered_filtered`", "`why`", "`asked_before`", "`changed_observation`"):
            self.assertIn(cell, i7)
        self.assertIn("넘겨받은 답 · 미뤄 둔 의심 · 정체가 다름 표시 포함", i7)

    def test_lifetime_sentence_in_both_docs(self):
        first = "세션 폴더는 같은 세션의 다음 qg 시작에 지워진다"
        second = ("그 세션이 qg 를 다시 부르지 않으면, 폴더가 정리 기한(기본 24시간)보다 오래된 뒤 "
                  "어느 세션이든 qg 를 시작할 때 지워진다")
        i7 = self._section("I7 돌려주기")
        for text in (self.state, i7):
            self.assertEqual(text.count(first), 1)
            self.assertEqual(text.count(second), 1)
            self.assertEqual(text.count(first + ". " + second + "."), 1 if text is i7 else 0)
        # 상태 문서는 첫 문장 뒤에 지우는 스크립트를 밝힌다.
        self.assertEqual(self.state.count(first + "(`scripts/setup-qg.sh`). " + second + "(`scripts/qg-gc.py`)."), 1)
        carry = ("나중에 쓸 부르는 쪽은 qg 를 다시 부르기 전에 `intent-return.md`(완결)와, 다른 팀 기록이 필요하면 "
                 "`session_dir` 아래 `other_teams` 값의 파일을 가져간다.")
        self.assertEqual(i7.count(carry), 1)

    def test_i7_decides_from_fields(self):
        """I7 의 할 일은 꼴의 칸에서 정한다 — 옛 칸 값 · 공시 줄 판독이 없다(AC9)."""
        i7 = self._section("I7 돌려주기")
        for field in ("`wrong_choice: true`", "`state: 답 기록 실패`", "`state: 답하지 않음`",
                      "`state: 묻지 않음`"):
            lines = [l for l in i7.split("\n") if l.startswith("  - " + field + " 인 질문")]
            self.assertEqual(len(lines), 1, field)
        for gone in ("wrong_choice: yes", "`아직 묻지 않음` 으로 남고 고른 답은 실리지 않는다",
                     "아직 묻지 않음"):
            self.assertNotIn(gone, i7)
            self.assertNotIn(gone, self.state)
        self.assertIn("질문 <k>개를 묻지 않았다 — 부르는 쪽이 사람에게 옮긴다", i7)
        self.assertIn("질문 <k>개를 묻기 전에 끝났다 — 다시 돌려 묻는다", i7)


if __name__ == "__main__":
    unittest.main()
