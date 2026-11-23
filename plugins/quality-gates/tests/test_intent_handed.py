"""넘겨받은 「이미 답한 것」 파일 읽기와 답 파일의 질문 글."""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import intent_answers as ia  # noqa: E402

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


if __name__ == "__main__":
    unittest.main()
