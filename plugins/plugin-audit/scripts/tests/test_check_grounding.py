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


if __name__ == "__main__":
    unittest.main()
