"""넘겨받은 「이미 답한 것」 파일 읽기와 답 파일의 질문 글."""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import yaml  # noqa: E402

import intent_answers as ia  # noqa: E402
import intent_origin as io_  # noqa: E402
import test_intent_critic as tic  # noqa: E402

KEY1 = "2026-11-22-R4-spec.md#2"
KEY2 = "2026-11-22-R4-spec.md#3"


def _entry(key=KEY1, answer="의도다", route="-", **over):
    e = {"key": key, "id": "diff#docs/a.md#갈라짐", "answer": answer,
         "question": "그때의 질문", "observation": "관찰 하나\n관찰 둘",
         "answered_at": "2026-11-22 21:25", "route": route,
         "record": "road/reviews/2026-11-22-R4-spec.md"}
    e.update(over)
    return e


def _q(v):
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
    return str(v)


def _yaml_entry(e, drop=None):
    lines = []
    first = True
    for k, v in e.items():
        if k == drop:
            continue
        lines.append("%s %s: %s" % ("  -" if first else "   ", k, _q(v)))
        first = False
    return "\n".join(lines)


def _doc(entries_yaml, contract="contract: 1\n"):
    return contract + "entries:\n" + entries_yaml + "\n"


class TestReadHanded(unittest.TestCase):
    def _write(self, d, text, name="handed.yaml"):
        p = os.path.join(d, name)
        with open(p, "w", encoding="utf-8") as fh:
            fh.write(text)
        return p

    def _why(self, d, text):
        entries, why = ia.read_handed(self._write(d, text))
        self.assertIsNone(entries, text)
        return why

    def test_reads_entries_in_order(self):
        with tempfile.TemporaryDirectory() as d:
            second = _entry(KEY2, "잘못 골랐다", "새 일의 씨앗")
            p = self._write(d, _doc(_yaml_entry(_entry()) + "\n" + _yaml_entry(second)))
            entries, why = ia.read_handed(p)
            self.assertIsNone(why)
            self.assertEqual(entries, [_entry(), second])

    def test_unreadable_reasons(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(ia.read_handed(os.path.join(d, "none.yaml")), (None, ia.HANDED_MISSING))
            sub = os.path.join(d, "dir")
            os.mkdir(sub)
            self.assertEqual(ia.read_handed(sub), (None, ia.HANDED_NOT_FILE))
            good = self._write(d, _doc(_yaml_entry(_entry())))
            link = os.path.join(d, "link.yaml")
            os.symlink(good, link)
            self.assertEqual(ia.read_handed(link), (None, ia.HANDED_NOT_FILE))
            big = os.path.join(d, "big.yaml")
            with open(big, "wb") as fh:
                fh.write(b"a" * (ia.HANDED_MAX_BYTES + 1))
            self.assertEqual(ia.read_handed(big), (None, ia.HANDED_TOO_BIG))

            shape = ia.HANDED_BAD_SHAPE
            alias = ("contract: 1\nx: &a [1]\nentries:\n  - key: \"%s\"\n    id: *a\n" % KEY1)
            cases = [
                "contract: 1\nentries: [unclosed\n",
                "contract: 1\nentries: 5\n",
                "contract: 1\nentries: {a: 1}\n",
                _doc(_yaml_entry(_entry(), drop="record")),
                _doc(_yaml_entry(_entry(record=5))),
                _doc(_yaml_entry(_entry(question="x")).replace('"x"', "[1, 2]")),
                alias,
                _doc(_yaml_entry(_entry(answer="지금은 모르겠다"))),
                _doc(_yaml_entry(_entry(answer="없는 답"))),
                _doc(_yaml_entry(_entry(key="a.md#1\n"))),
                _doc(_yaml_entry(_entry(key="a#1"))),
                _doc(_yaml_entry(_entry(key="a.md#"))),
                _doc(_yaml_entry(_entry(key="a/b.md#1"))),
                _doc(_yaml_entry(_entry(key="a.md#1#2"))),
                _doc(_yaml_entry(_entry(key="a.md#\u0661"))),
                _doc(_yaml_entry(_entry()) + "\n"
                     + _yaml_entry(_entry(answer="잘못 골랐다", route="새 일의 씨앗"))),
                "- 1\n- 2\n",
            ]
            for text in cases:
                self.assertEqual(self._why(d, text), shape, text)
            for text in ("contract: 2\nentries: []\n", "entries: []\n",
                         "contract: true\nentries: []\n", 'contract: "1"\nentries: []\n'):
                self.assertEqual(self._why(d, text), ia.HANDED_BAD_VERSION, text)

    def test_route_values(self):
        with tempfile.TemporaryDirectory() as d:
            for route in ("이 에픽 안에서 고친다", "새 일의 씨앗", "재분해 신호"):
                p = self._write(d, _doc(_yaml_entry(_entry(answer="잘못 골랐다", route=route))))
                entries, why = ia.read_handed(p)
                self.assertIsNone(why)
                self.assertEqual(entries[0]["route"], route)
            for route in ("-", "엉뚱한 곳", ""):
                p = self._write(d, _doc(_yaml_entry(_entry(answer="잘못 골랐다", route=route))))
                self.assertEqual(ia.read_handed(p), (None, ia.HANDED_BAD_SHAPE))
            p = self._write(d, _doc(_yaml_entry(_entry(answer="의도다", route="새 일의 씨앗"))))
            self.assertEqual(ia.read_handed(p), (None, ia.HANDED_BAD_SHAPE))


class TestAnswerFileQuestion(unittest.TestCase):
    def test_answer_file_question_section(self):
        ident = "diff#docs/a.md#갈라짐"
        t = ia.render_answer_file(ident, "  이 방향이 맞나?\n둘째 줄  ", "구절", "라벨", ["관찰"],
                                  "의도다", "원문", "t", "2026-11-14T01:02:03Z")
        p = ia.parse_answer_file(t)
        self.assertEqual(p["question"], "이 방향이 맞나?\n둘째 줄")
        self.assertEqual(p["observation"], "관찰")
        no_q = t.replace("## 질문", "## 다른 절")
        self.assertEqual(ia.parse_answer_file(no_q)["question"], "")


class TestPrepareHanded(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.R = tic._origin_repo(os.path.join(cls.tmp.name))

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def setUp(self):
        self.rd = tempfile.mkdtemp(dir=self.tmp.name)
        tic._write(tic._config_text(), self.rd, "intent-config.txt")
        tic._write("## Goals\ngoal-body\n", self.rd, "intent.md")
        tic._write("관찰\n", self.rd, "e2e-record.md")

    def _prep(self, handed=None, tree_root=None):
        sp = os.path.join(self.rd, "intent-specs.json")
        tic._write('{"intent_source": "spec-trailer", "specs": []}', sp)
        args = ["prepare", "--rd", self.rd, "--repo", self.R,
                "--tree-root", tree_root or self.R, "--mode", "pr", "--head", "HEAD",
                "--review-commit", "HEAD", "--specs-json", sp]
        if handed:
            args += ["--answered", handed]
        p = tic._cli(*args)
        self.assertEqual(p.returncode, 0, p.stderr)
        return p

    def _handed_file(self, text):
        path = os.path.join(self.rd, "handed-in.yaml")
        tic._write(text, path)
        return path

    def test_handed_lines_one_per_entry_with_question(self):
        e1 = _entry(KEY1, question="첫째\n질문")
        e2 = _entry(KEY2, answer="잘못 골랐다", route="새 일의 씨앗", question="둘째 질문")
        h = self._handed_file(_doc(_yaml_entry(e1) + "\n" + _yaml_entry(e2)))
        with tempfile.TemporaryDirectory() as tree:
            tic._write(tic._answer_text(), tree, tic.ANS_DIR, tic._wf(1))
            p = self._prep(h, tree_root=tree)
        self.assertEqual(tic._last(p), "intent-call: first-only")
        lines = tic._read(self.rd, "intent-answered.md").splitlines()
        self.assertEqual(len(lines), 3, lines)
        self.assertTrue(lines[0].startswith("- %s · 의도다 · 질문: Q? · " % tic.IDENT), lines[0])
        self.assertTrue(lines[1].startswith("- %s · %s · 의도다 · " % (KEY1, e1["id"])), lines[1])
        self.assertIn("질문: 첫째 질문 · 관찰: 관찰 하나", lines[1])
        self.assertTrue(lines[2].startswith("- %s · %s · 잘못 골랐다 · " % (KEY2, e2["id"])), lines[2])
        self.assertIn("질문: 둘째 질문", lines[2])

    def test_handed_copy_written_and_removed(self):
        e1, e2 = _entry(KEY1), _entry(KEY2, answer="잘못 골랐다", route="재분해 신호")
        h = self._handed_file(_doc(_yaml_entry(e1) + "\n" + _yaml_entry(e2)))
        self._prep(h)
        copy = yaml.safe_load(tic._read(self.rd, "intent-handed.yaml"))
        self.assertEqual(copy["entries"], [e1, e2])
        self._prep()
        self.assertFalse(os.path.exists(os.path.join(self.rd, "intent-handed.yaml")))

    def test_unreadable_handed_file_runs_on_with_notice(self):
        base = self._handed_file(_doc(_yaml_entry(_entry())))
        link = os.path.join(self.rd, "link.yaml")
        os.symlink(base, link)
        big = os.path.join(self.rd, "big.yaml")
        with open(big, "wb") as fh:
            fh.write(b"a" * (ia.HANDED_MAX_BYTES + 1))
        bad_shape = os.path.join(self.rd, "shape.yaml")
        tic._write("contract: 1\nentries: 5\n", bad_shape)
        bad_ver = os.path.join(self.rd, "ver.yaml")
        tic._write("contract: 2\nentries: []\n", bad_ver)
        cases = [(os.path.join(self.rd, "none.yaml"), ia.HANDED_MISSING),
                 (self.rd, ia.HANDED_NOT_FILE), (link, ia.HANDED_NOT_FILE),
                 (big, ia.HANDED_TOO_BIG), (bad_shape, ia.HANDED_BAD_SHAPE),
                 (bad_ver, ia.HANDED_BAD_VERSION)]
        for path, why in cases:
            self._prep(base)  # 앞 실행이 남긴 복사본
            self.assertTrue(os.path.exists(os.path.join(self.rd, "intent-handed.yaml")))
            p = self._prep(path)
            self.assertTrue(tic._last(p).startswith("intent-call: "), p.stdout)
            self.assertEqual(p.stdout.splitlines().count("넘겨받은 답을 읽지 못함 — " + why), 1, why)
            self.assertFalse(os.path.exists(os.path.join(self.rd, "intent-handed.yaml")), why)
            self.assertEqual(tic._read(self.rd, "intent-answered.md"), "답한 질문 없음\n", why)

    def test_cells_fold_and_empty_cells_become_dash(self):
        e = _entry(KEY1, question="앞\r가짜 줄\t탭|파이프 끝", answer="의도다",
                   observation="")
        h = self._handed_file(_doc(_yaml_entry(e)))
        self._prep(h)
        lines = tic._read(self.rd, "intent-answered.md").splitlines()
        self.assertEqual(lines, ["- %s · %s · 의도다 · 질문: 앞 가짜 줄 탭|파이프 끝 · 관찰: -"
                                 % (KEY1, e["id"])])
        e2 = _entry(KEY2, question="")
        self._prep(self._handed_file(_doc(_yaml_entry(e2))))
        self.assertIn("질문: - · 관찰: 관찰 하나", tic._read(self.rd, "intent-answered.md"))

    def test_stale_copy_removed_without_evidence_and_on_kill_switch(self):
        h = self._handed_file(_doc(_yaml_entry(_entry())))
        copy = os.path.join(self.rd, "intent-handed.yaml")
        self._prep(h)
        self.assertTrue(os.path.exists(copy))
        os.remove(os.path.join(self.rd, "e2e-record.md"))
        p = self._prep(h)
        self.assertEqual(tic._last(p), "intent-call: none")
        self.assertFalse(os.path.exists(copy))
        tic._write("관찰\n", self.rd, "e2e-record.md")
        self._prep(h)
        self.assertTrue(os.path.exists(copy))
        sp = os.path.join(self.rd, "intent-specs.json")
        p = tic._cli("prepare", "--rd", self.rd, "--repo", self.R, "--tree-root", self.R,
                     "--mode", "pr", "--head", "HEAD", "--review-commit", "HEAD",
                     "--specs-json", sp, "--answered", h,
                     env=tic._env(**{tic.KILL: "1"}))
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertFalse(os.path.exists(copy))

    def test_no_answered_arg_unchanged(self):
        with tempfile.TemporaryDirectory() as tree:
            tic._write(tic._answer_text(), tree, tic.ANS_DIR, tic._wf(1))
            p = self._prep(tree_root=tree)
        self.assertEqual(tic._read(self.rd, "intent-answered.md"),
                         "- %s · 의도다 · 질문: Q? · 관찰: 3 근거\n" % tic.IDENT)
        self.assertNotIn("넘겨받은", p.stdout)
        self.assertFalse(os.path.exists(os.path.join(self.rd, "intent-handed.yaml")))


PREV = "[e2e] 관찰 1"
AT_H = "2026-11-22 21:25"
KA, KB, KC, KD = "r-a.md#1", "r-b.md#1", "r-c.md#1", "r-d.md#1"
KE, KF1, KF2, KG = "r-e.md#1", "r-f1.md#1", "r-f2.md#1", "r-g.md#1"
WHY_B = "답에 따라 이 기능을 둘지가 갈린다(D2)"
WHY_H = "답에 따라 범위가 달라진다"


def _ident(tid):
    return tic.SRC + "#%s#방향" % tid


def _changed(n):
    return {"previous": PREV, "now_lines": [n]}


def _hand(key, answer="의도다", route="-", tid="D1"):
    return _entry(key, answer, route, id=_ident(tid), observation=PREV + "\n둘째 관찰",
                  answered_at=AT_H, record="road/reviews/" + key.split("#")[0])


def _eight():
    """질문 여덟(a–h)과 넘겨받은 항목들 — TestFilterHanded 의 표 한 벌."""
    entries = [_hand(KA, tid="D1"), _hand(KB, tid="D2"),
               _hand(KC, "잘못 골랐다", "이 에픽 안에서 고친다", "D3"),
               _hand(KD, "잘못 골랐다", "새 일의 씨앗", "D4"),
               _hand(KE, "잘못 골랐다", "재분해 신호", "D5"),
               _hand(KF1, "잘못 골랐다", "이 에픽 안에서 고친다", "D6"),
               _hand(KF2, tid="D6"), _hand(KG, tid="D99")]
    cands = [tic._q("D1", same_as=KA),
             tic._q("D2", same_as=KB, observation_changed=_changed(3), why=WHY_B),
             tic._q("D3", same_as=KC),
             tic._q("D4", same_as=KD),
             tic._q("D5", same_as=KE, observation_changed=_changed(4), why="줄\n바꿈"),
             tic._q("D6", same_as=KF2),
             tic._q("D7", same_as=KG),
             tic._q("D8", same_as="r-none.md#1", why="   ")]
    return entries, cands


class TestFilterHanded(unittest.TestCase):
    """넘겨받은 열쇠로 거르기 — 가르는 표(AC10 · AC12)."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.rd = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def _run(self, entries, cands, answers=(), names=None, handed_text=None):
        tic._filter_rd(self.rd, answers=answers)
        for n, text in (names or {}).items():
            tic._write(text, self.rd, "review-i%d.names" % n)
        if handed_text is not None:
            tic._write(handed_text, self.rd, "intent-handed.yaml")
        elif entries is not None:
            tic._write(yaml.safe_dump({"entries": entries}, allow_unicode=True, sort_keys=False),
                       self.rd, "intent-handed.yaml")
        tic._write(tic._out(cands), self.rd, "intent-critic-1.txt")
        p = tic._cli("filter", "--rd", self.rd)
        self.assertEqual(p.returncode, 0, p.stderr)
        return p

    def _render(self):
        tic._write("## 판정\nv\n## 게시\np\n", self.rd, "result.md")
        r = tic._cli("render", "--rd", self.rd, "--mode", "pr")
        self.assertEqual(r.returncode, 0, r.stderr)
        return tic._read(self.rd, "result.md").split("## intent-critic", 1)[1]

    def _by_tid(self):
        out = {}
        for rec in tic._questions(self.rd)["questions"]:
            out[rec["target_id"]] = rec
        return out

    def test_one_run_covers_every_branch(self):
        entries, cands = _eight()
        p = self._run(entries, cands)
        lines = p.stdout.splitlines()
        self.assertIn("이미 답한 질문이라 거름 4", lines)
        self.assertNotIn(tic.NAMES_GONE, lines)  # 넘겨받은 항목엔 범위 표시가 없다
        self.assertEqual(tic._questions(self.rd)["counts"]["answered"], 4)
        recs = self._by_tid()
        states = {}
        for tid, rec in recs.items():
            states[tid] = rec["state"]
        self.assertEqual(states["D1"], "answered-filtered")
        self.assertEqual(states["D4"], "deferred-filtered")
        self.assertEqual(states["D6"], "answered-filtered")
        self.assertEqual(states["D7"], "answered-filtered")
        for tid in ("D2", "D3", "D5", "D8"):
            self.assertIn(states[tid], ("ask", "over-cap"), tid)
        self.assertEqual(recs["D2"]["asked_before"], "의도다 · %s · %s · 근거가 달라짐" % (AT_H, KB))
        self.assertEqual(recs["D5"]["asked_before"],
                         "잘못 골랐다 · %s · %s · 근거가 달라짐" % (AT_H, KE))
        self.assertEqual(recs["D3"]["asked_before"],
                         "잘못 골랐다 · %s · %s · 고친 뒤에도 보임" % (AT_H, KC))
        self.assertEqual(recs["D3"]["changed_observation"], "-")
        self.assertEqual(recs["D8"]["asked_before"], "-")
        self.assertEqual(recs["D8"]["changed_observation"], "-")
        self.assertEqual(recs["D2"]["changed_observation"],
                         ["[e2e] 관찰 3", "이전 관찰: " + PREV, "   3\t[e2e] 관찰 3"])
        self.assertEqual(recs["D5"]["changed_observation"][0], "[e2e] 관찰 4")
        # 걸러진 넘겨받은 항목의 칸.
        self.assertEqual(recs["D6"]["answer_file"], "road/reviews/r-f2.md")
        self.assertEqual(recs["D6"]["previous_answer"], "의도다")
        self.assertIs(recs["D6"]["handed"], True)
        self.assertIs(recs["D6"]["deferred"], False)
        self.assertNotIn("identity_then", recs["D6"])
        self.assertIs(recs["D4"]["deferred"], True)
        self.assertEqual(recs["D7"]["identity_then"], _ident("D99"))
        for tid in ("D1", "D4", "D6", "D7"):
            self.assertEqual(recs[tid]["asked_before"], "-", tid)
            self.assertNotIn("range_mark", recs[tid], tid)

    def test_unidentified_question_still_reads_handed_key(self):
        q = tic._q("D1", kind="모르는", same_as=KA, question="모르는 종류")
        p = self._run([_hand(KA, tid="D1")], [q])
        self.assertIn("이미 답한 질문이라 거름 1", p.stdout.splitlines())
        rec = tic._questions(self.rd)["questions"][0]
        self.assertEqual(rec["state"], "answered-filtered")
        self.assertEqual(rec["identity_then"], _ident("D1"))

    def test_handed_key_with_other_identity_filters_and_marks(self):
        entries, cands = _eight()
        self._run(entries, cands)
        section = self._render()
        head = "이미 답한 질문이라 거른 질문:"
        self.assertIn(head, section)
        listed = []
        for line in section.split(head, 1)[1].lstrip("\n").splitlines():
            if not line.startswith("- "):
                break
            listed.append(line)
        self.assertEqual(len(listed), 4, listed)
        g = "- %s · 의도다 · road/reviews/r-g.md · 넘겨받은 답 · 정체가 다름 — %s → %s — %s" % (
            _ident("D7"), _ident("D99"), _ident("D7"), cands[6]["question"])
        d = "- %s · 잘못 골랐다 · road/reviews/r-d.md · 넘겨받은 답 · 미뤄 둔 의심 — %s" % (
            _ident("D4"), cands[3]["question"])
        f = "- %s · 의도다 · road/reviews/r-f2.md · 넘겨받은 답 — %s" % (
            _ident("D6"), cands[5]["question"])
        self.assertIn(g, listed)
        self.assertIn(d, listed)
        self.assertIn(f, listed)
        for line in listed:
            self.assertNotIn("이 범위가 더한 답 파일", line)
            self.assertNotIn("범위 변경 여부를 확인하지 못함", line)
        self.assertNotIn("이미 「잘못 골랐다」 답이 있어 거른 질문:", section)

    def test_folder_answers_unchanged_and_asked_before(self):
        id2 = _ident("D2")
        names = {1: "%s/%s\n%s/%s\n" % (tic.ANS_DIR, tic._wf(0), tic.ANS_DIR, tic._wf(1))}
        answers = [(tic.ID1, "의도다", tic.OBS1), (id2, "잘못 골랐다", tic.OBS1)]
        cands = [tic._q("D1", same_as=tic.ID1), tic._q("D2", same_as=id2, question="폴더의 잘못"),
                 tic._q("D4", same_as=KD, question="미뤄 둔 그 질문")]
        p = self._run([_hand(KD, "잘못 골랐다", "새 일의 씨앗", "D4")], cands, answers=answers,
                      names=names)
        self.assertIn("이미 답한 질문이라 거름 3", p.stdout.splitlines())
        recs = self._by_tid()
        self.assertEqual(recs["D1"]["state"], "answered-filtered")
        self.assertEqual(recs["D2"]["state"], "wrong-choice-filtered")
        self.assertEqual(recs["D4"]["state"], "deferred-filtered")
        self.assertNotIn("handed", recs["D1"])
        section = self._render()
        listed = section.split("이미 답한 질문이라 거른 질문:", 1)[1]
        self.assertIn("- %s · 의도다 · %s/%s · 이 범위가 더한 답 파일 — " % (
            tic.ID1, tic.ANS_DIR, tic._wf(0)), listed)
        wrong = section.split("이미 「잘못 골랐다」 답이 있어 거른 질문:", 1)[1]
        self.assertIn("폴더의 잘못", wrong)
        self.assertNotIn("미뤄 둔 그 질문", wrong)
        # 관찰이 달라졌으면 묻고 asked_before 를 채운다.
        with tempfile.TemporaryDirectory() as rd:
            self.rd = rd
            self._run(None, [tic._q("D1", same_as=tic.ID1, observation_changed=_changed(2))],
                      answers=[(tic.ID1, "의도다", tic.OBS1)])
            rec = tic._questions(rd)["questions"][0]
            self.assertEqual(rec["state"], "ask")
            self.assertEqual(rec["asked_before"],
                             "의도다 · %s · %s · 근거가 달라짐" % (tic.AT1, tic.ID1))
            self.assertEqual(rec["changed_observation"][0], "[e2e] 관찰 2")

    def test_previous_copied_from_printed_cell(self):
        """`previous` 가 intent-answered.md 가 보인 관찰 칸 그대로(번호 포함)여도 — 답 폴더의 답이든
        넘겨받은 항목이든 — 근거가 달라졌으면 다시 묻고, 달라졌다는 근거가 없거나 다른 관찰이면 거른다."""
        id2 = _ident("D2")
        hand = _entry(KB, id=_ident("D9"), observation=tic.OBS1 + "\n둘째 관찰",
                      answered_at=AT_H, record="road/reviews/r-b.md")
        with tempfile.TemporaryDirectory() as rd:
            tic._filter_rd(rd, answers=[(id2, "의도다", tic.OBS1)])
            answered = ia.read_answered_under(os.path.join(rd, "tree"), tic.ANS_DIR)[0]
            printed = tic.ic._answered_lines(answered, [hand]).splitlines()
        self.assertEqual(len(printed), 2, printed)
        cells = []
        for line in printed:
            cells.append(line.rsplit(" · 관찰: ", 1)[1])
        self.assertEqual(cells, ["1 [e2e] 관찰 1", "1 [e2e] 관찰 1"])
        folder, handed = cells
        cases = [({"previous": folder, "now_lines": [3]}, {"previous": handed, "now_lines": [3]},
                  "ask"),
                 ({"previous": folder, "now_lines": []}, {"previous": handed, "now_lines": []},
                  "answered-filtered"),
                 ({"previous": "1 [e2e] 관찰 2", "now_lines": [3]},
                  {"previous": "1 [e2e] 관찰 2", "now_lines": [3]}, "answered-filtered")]
        for f_changed, h_changed, want in cases:
            with self.subTest(previous=f_changed["previous"], want=want), \
                    tempfile.TemporaryDirectory() as rd:
                self.rd = rd
                cands = [tic._q("D2", same_as=id2, observation_changed=f_changed),
                         tic._q("D9", same_as=KB, observation_changed=h_changed)]
                self._run([hand], cands, answers=[(id2, "의도다", tic.OBS1)])
                recs = self._by_tid()
                self.assertEqual(recs["D2"]["state"], want)
                self.assertEqual(recs["D9"]["state"], want)
                if want == "ask":
                    self.assertEqual(recs["D2"]["asked_before"],
                                     "의도다 · %s · %s · 근거가 달라짐" % (tic.AT1, id2))
                    self.assertEqual(recs["D9"]["asked_before"],
                                     "의도다 · %s · %s · 근거가 달라짐" % (AT_H, KB))
                    self.assertEqual(recs["D2"]["changed_observation"][1],
                                     "이전 관찰: 1 [e2e] 관찰 1")

    def test_snippet_cut_at_80(self):
        tic._filter_rd(self.rd)
        walk = "관찰 1\n관찰 2\n" + "가" * 94 + "\n"
        tic._write(io_.build_evidence(walk, None)[0], self.rd, "intent-evidence.txt")
        tic._write(yaml.safe_dump({"entries": [_hand(KB, tid="D2")]}, allow_unicode=True),
                   self.rd, "intent-handed.yaml")
        tic._write(tic._out([tic._q("D2", same_as=KB, observation_changed=_changed(3))]),
                   self.rd, "intent-critic-1.txt")
        p = tic._cli("filter", "--rd", self.rd)
        self.assertEqual(p.returncode, 0, p.stderr)
        line = tic._read(self.rd, "intent-evidence.txt").split("\n")[2]
        stripped = line.split("\t", 1)[1]
        self.assertEqual(len(stripped), 100)
        snippet = tic._questions(self.rd)["questions"][0]["changed_observation"][0]
        self.assertEqual(snippet, stripped[:80] + "…")
        self.assertEqual(len(snippet), 81)

    def test_snippet_from_quote_when_no_lines(self):
        old = "[읽음] a.txt:1 old"
        tree = os.path.join(self.rd, "tree")
        os.makedirs(tree)
        tic._git_repo(tree)
        tic._filter_rd(self.rd)
        with open(os.path.join(self.rd, "intent-plan.txt"), "a", encoding="utf-8") as fh:
            fh.write("breadth: range\n")
        entry = _entry(KB, observation=old, record="road/reviews/r-b.md")
        tic._write(yaml.safe_dump({"entries": [entry]}, allow_unicode=True), self.rd,
                   "intent-handed.yaml")
        rq = {"path": "a.txt", "line": 1, "text": "x"}
        q = tic._q("D2", same_as=KB, observation_changed={"previous": old, "now_quotes": [rq]})
        tic._write(tic._out([q]), self.rd, "intent-critic-1.txt")
        p = tic._cli("filter", "--rd", self.rd)
        self.assertEqual(p.returncode, 0, p.stderr)
        rec = tic._questions(self.rd)["questions"][0]
        self.assertEqual(rec["state"], "ask")
        quote = io_.quote_line(rq)
        self.assertEqual(rec["changed_observation"], [quote, "이전 관찰: " + old, quote])

    def test_unreadable_session_copy_is_disclosed_and_not_used(self):
        bad = _entry("a#1")
        texts = ("entries: 5\n", "- 1\n", "entries: [unclosed\n",
                 yaml.safe_dump({"entries": [bad]}, allow_unicode=True))
        for text in texts:
            with self.subTest(text=text), tempfile.TemporaryDirectory() as rd:
                self.rd = rd
                p = self._run(None, [tic._q("D1", same_as=KA)], handed_text=text)
                lines = p.stdout.splitlines()
                self.assertEqual(lines.count("넘겨받은 답을 읽지 못함 — 꼴이 맞지 않음"), 1, text)
                self.assertEqual(tic._last(p), "intent-ask: 1")
        with tempfile.TemporaryDirectory() as rd:
            self.rd = rd
            p = self._run(None, [tic._q("D1", same_as=KA)])
            self.assertNotIn("넘겨받은", p.stdout)
            self.assertEqual(tic._last(p), "intent-ask: 1")


class TestReturnThree(unittest.TestCase):
    """돌려주는 꼴 3판 — `answered_filtered` · `why` · `asked_before` · `changed_observation`(AC6 · AC7)."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.rd = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def _filter_render(self, entries, cands):
        tic._filter_rd(self.rd)
        tic._write(yaml.safe_dump({"entries": entries}, allow_unicode=True, sort_keys=False),
                   self.rd, "intent-handed.yaml")
        tic._write(tic._out(cands), self.rd, "intent-critic-1.txt")
        p = tic._cli("filter", "--rd", self.rd)
        self.assertEqual(p.returncode, 0, p.stderr)
        r = tic._cli("render", "--rd", self.rd, "--mode", "pr")
        self.assertEqual(r.returncode, 0, r.stderr)
        return tic._return_block(self.rd)

    def test_contract_three_and_new_cells(self):
        entries, cands = _eight()
        text, block = self._filter_render(entries, cands)
        self.assertIn("\ncontract: 3\n", text)
        self.assertEqual(block["contract"], 3)
        self.assertEqual(block["answered_filtered"], 4)
        self.assertIn("\nanswered_filtered: 4\nquestions:\n", text)
        keys = []
        for line in text.split("\n"):
            if line.startswith("  - "):
                keys = [line[4:].split(":", 1)[0]]
            elif line.startswith("    ") and not line.startswith("     "):
                keys.append(line.strip().split(":", 1)[0])
        self.assertEqual(keys[-3:], ["why", "asked_before", "changed_observation"])
        rows = {}
        for row in block["questions"]:
            rows[row["target_id"]] = row
        self.assertEqual(sorted(rows), ["D2", "D3", "D5", "D8"])
        self.assertEqual(rows["D2"]["why"], WHY_B)
        for tid in ("D3", "D5", "D8"):  # 없음 · 줄바꿈 · 빈칸뿐 — 질문은 남는다
            self.assertEqual(rows[tid]["why"], "-", tid)
        self.assertEqual(rows["D2"]["asked_before"], "의도다 · %s · %s · 근거가 달라짐" % (AT_H, KB))
        self.assertEqual(rows["D2"]["changed_observation"],
                         ["[e2e] 관찰 3", "이전 관찰: " + PREV, "3 [e2e] 관찰 3"])
        self.assertEqual(rows["D3"]["changed_observation"], "-")
        self.assertEqual(rows["D8"]["asked_before"], "-")
        recs = {}
        for rec in tic._questions(self.rd)["questions"]:
            recs[rec["target_id"]] = rec
        self.assertEqual(recs["D2"]["why"], WHY_B)
        self.assertEqual(recs["D5"]["why"], "-")

    def test_all_filtered_still_counts(self):
        entries, cands = _eight()
        _text, block = self._filter_render(entries, [cands[0], cands[3]])
        self.assertEqual(block["status"], "ran")
        self.assertEqual(block["outcome"], "none")
        self.assertEqual(block["answered_filtered"], 2)
        self.assertEqual(block["questions"], [])

    def test_answered_filtered_dash_when_skipped(self):
        p = tic._cli("gate", "--rd", self.rd, "--path", "trivia", "--mode", "pr")
        self.assertEqual(p.returncode, 0, p.stderr)
        _t, block = tic._return_block(self.rd)
        self.assertEqual(block["answered_filtered"], "-")
        with tempfile.TemporaryDirectory() as rd:
            tic._filter_rd(rd, call="none")
            r = tic._cli("render", "--rd", rd, "--mode", "pr")
            self.assertEqual(r.returncode, 0, r.stderr)
            _t, block = tic._return_block(rd)
            self.assertEqual(block["answered_filtered"], "-")


if __name__ == "__main__":
    unittest.main()
