import importlib.util, tempfile, unittest
from pathlib import Path

P = Path(__file__).resolve().parents[1] / "check-grounding.py"
spec = importlib.util.spec_from_file_location("cg", P)
cg = importlib.util.module_from_spec(spec)


def _load():
    spec.loader.exec_module(cg)


class TestGrounding(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        _load()

    def _fixture(self, d, name="src.py", body="line1\nline2\nHELLO WORLD\nline4\n"):
        (Path(d) / name).write_text(body, encoding="utf-8")

    def test_missing_file_is_null_degrade(self):
        with tempfile.TemporaryDirectory() as d:
            f = {"id": "F", "status": "reported", "evidence": [{"file": "nope.py", "line": 1, "quote": "x"}], "degraded_events": []}
            cg.ground_finding(f, Path(d))
            self.assertIsNone(f["grounding_verified"])

    def test_absent_quote_is_discarded(self):
        with tempfile.TemporaryDirectory() as d:
            self._fixture(d)
            f = {"id": "F", "status": "reported", "evidence": [{"file": "src.py", "line": 3, "quote": "NONEXISTENT"}], "degraded_events": []}
            cg.ground_finding(f, Path(d))
            self.assertFalse(f["grounding_verified"])
            self.assertEqual(f["status"], "discarded")

    def test_drifted_quote_is_line_corrected(self):
        with tempfile.TemporaryDirectory() as d:
            self._fixture(d)
            f = {"id": "F", "status": "reported", "evidence": [{"file": "src.py", "line": 99, "quote": "HELLO WORLD"}], "degraded_events": []}
            cg.ground_finding(f, Path(d))
            self.assertTrue(f["grounding_verified"])
            self.assertEqual(f["evidence"][0]["line"], 3)  # 교정

    def test_exact_quote_passes(self):
        with tempfile.TemporaryDirectory() as d:
            self._fixture(d)
            f = {"id": "F", "status": "reported", "evidence": [{"file": "src.py", "line": 3, "quote": "HELLO WORLD"}], "degraded_events": []}
            cg.ground_finding(f, Path(d))
            self.assertTrue(f["grounding_verified"])
            self.assertEqual(f["evidence"][0]["line"], 3)

    def test_all_evidence_checked_not_just_first(self):
        # C5: evidence[0]만 grounding하면 evidence[1]의 위조 인용이 통과한다. 첫 인용은 실재,
        # 둘째 인용은 부재 → 폐기돼야 한다.
        with tempfile.TemporaryDirectory() as d:
            self._fixture(d)  # src.py: line1\nline2\nHELLO WORLD\nline4
            f = {"id": "F", "status": "reported", "degraded_events": [],
                 "evidence": [{"file": "src.py", "line": 3, "quote": "HELLO WORLD"},
                              {"file": "src.py", "line": 1, "quote": "NONEXISTENT QUOTE"}]}
            cg.ground_finding(f, Path(d))
            self.assertFalse(f["grounding_verified"], "둘째 인용이 부재인데 grounding 통과 (evidence[0]만 봄)")
            self.assertEqual(f["status"], "discarded", "부재 인용 포함 finding이 폐기되지 않음")

    def test_multiline_quote_is_grounded(self):
        # C5: 여러 줄에 걸친 인용은 단일-라인 매칭으론 거짓 폐기된다. 전체파일 정규화 검색으로 실재 인정.
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "src.py").write_text("def foo():\n    return 42\n", encoding="utf-8")
            f = {"id": "F", "status": "reported", "degraded_events": [],
                 "evidence": [{"file": "src.py", "line": 1, "quote": "def foo(): return 42"}]}
            cg.ground_finding(f, Path(d))
            self.assertTrue(f["grounding_verified"], "여러 줄 인용이 거짓 폐기됨 (단일-라인 매칭)")
            self.assertNotEqual(f["status"], "discarded")


if __name__ == "__main__":
    unittest.main()
