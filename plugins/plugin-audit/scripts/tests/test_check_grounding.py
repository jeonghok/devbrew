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

    def test_empty_evidence_is_not_verified(self):
        # 회귀 방지 (codex fix-review): evidence가 비었으면 검증할 인용이 없으므로
        # grounding_verified=True로 새면 안 되고, 폐기 시 degraded_event 흔적을 남겨야 한다
        # (AC-3 조용한 증발 금지 — codex final-review).
        with tempfile.TemporaryDirectory() as d:
            f = {"id": "F", "status": "reported", "evidence": [], "degraded_events": []}
            cg.ground_finding(f, Path(d))
            self.assertNotEqual(f.get("grounding_verified"), True, "빈 evidence가 grounded로 통과")
            self.assertEqual(f["status"], "discarded")
            self.assertTrue(f["degraded_events"], "폐기됐는데 degraded_event 흔적 없음 (AC-3 조용한 증발)")

    def test_path_traversal_is_not_grounded(self):
        # codex final-review: 인용 파일 경로가 repo_root 밖(절대경로/../ /symlink)이면
        # grounding해선 안 된다 (repo 밖 임의 파일 read-oracle 차단).
        with tempfile.TemporaryDirectory() as outside:
            secret = Path(outside) / "secret.txt"
            secret.write_text("TOPSECRET\n", encoding="utf-8")
            with tempfile.TemporaryDirectory() as d:  # repo_root
                f = {"id": "F", "status": "reported", "degraded_events": [],
                     "evidence": [{"file": str(secret), "line": 1, "quote": "TOPSECRET"}]}
                cg.ground_finding(f, Path(d))
                self.assertNotEqual(f.get("grounding_verified"), True,
                                    "repo_root 밖 절대경로 파일이 grounded로 통과 (path traversal)")

    def test_blank_quote_is_not_verified(self):
        # 회귀 방지 (codex fix-review): 모든 quote가 공백이면 실제로 검증된 인용이 0개 —
        # grounding_verified=True로 새면 안 된다.
        with tempfile.TemporaryDirectory() as d:
            self._fixture(d)
            f = {"id": "F", "status": "reported",
                 "evidence": [{"file": "src.py", "line": 3, "quote": "   "}], "degraded_events": []}
            cg.ground_finding(f, Path(d))
            self.assertNotEqual(f.get("grounding_verified"), True, "공백 quote가 grounded로 통과")

    def test_multiline_quote_is_grounded(self):
        # C5: 여러 줄에 걸친 인용은 단일-라인 매칭으론 거짓 폐기된다. 전체파일 정규화 검색으로 실재 인정.
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "src.py").write_text("def foo():\n    return 42\n", encoding="utf-8")
            f = {"id": "F", "status": "reported", "degraded_events": [],
                 "evidence": [{"file": "src.py", "line": 1, "quote": "def foo(): return 42"}]}
            cg.ground_finding(f, Path(d))
            self.assertTrue(f["grounding_verified"], "여러 줄 인용이 거짓 폐기됨 (단일-라인 매칭)")
            self.assertNotEqual(f["status"], "discarded")

    def test_null_quote_does_not_crash(self):  # B (/qg 2026-07-20 round-2)
        # security-reviewer: `ev.get("quote", "")`는 키 *부재*시만 "" — {"quote": null}(키 존재, 값 None)이면
        # None 반환 → `_norm(None)`=re.sub(None) TypeError. line 24는 try 밖이라 uncaught. codex findings는
        # schema 미검증으로 findings에 병합되므로(assemble step-7), 미신뢰 대상이 유도한 null-quote 인용
        # 하나가 post-1 조립 전체를 죽인다(full-audit DoS, AC-3 degrade-not-crash 무력화). 재현: 크래시하면
        # ground_finding 호출이 여기서 TypeError를 던져 이 테스트가 ERROR(RED)가 된다.
        with tempfile.TemporaryDirectory() as d:
            self._fixture(d)
            f = {"id": "F", "status": "reported", "degraded_events": [],
                 "evidence": [{"file": "src.py", "line": 1, "quote": None}]}
            cg.ground_finding(f, Path(d))
            self.assertNotEqual(f.get("grounding_verified"), True, "null quote가 grounded로 통과")

    def test_null_file_does_not_crash(self):  # B — file 필드 null
        # {"file": null}이면 `(root / ev.get("file",""))`가 root / None → PosixPath/NoneType TypeError,
        # except (ValueError, OSError)가 못 잡는다. 크래시 금지가 이빨.
        with tempfile.TemporaryDirectory() as d:
            self._fixture(d)
            f = {"id": "F", "status": "reported", "degraded_events": [],
                 "evidence": [{"file": None, "line": 1, "quote": "HELLO WORLD"}]}
            cg.ground_finding(f, Path(d))
            self.assertNotEqual(f.get("grounding_verified"), True, "null file이 grounded로 통과")


if __name__ == "__main__":
    unittest.main()
