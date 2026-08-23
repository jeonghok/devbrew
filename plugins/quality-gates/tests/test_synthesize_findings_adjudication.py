"""synthesize_findings 가 «파일 부재»와 «경로 없음»을 구별하는지, 미판정을 세는지 본다."""
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "synthesize_findings.py"
spec = importlib.util.spec_from_file_location("synthesize_findings", SCRIPT)
mod = importlib.util.module_from_spec(spec)
sys.path.insert(0, str(SCRIPT.parent))
spec.loader.exec_module(mod)


class TestSourceFailure(unittest.TestCase):

    def test_missing_file_is_source_failure_not_empty(self):
        """#7 — 파일 부재를 「경로 없음」과 같이 다루면 dropped=0 이 되어
        render() 의 공지가 영원히 안 켜진다."""
        L = mod.Ledger(items="open")
        items, dropped = mod.load_yaml("/nonexistent/findings.yaml", ledger=L)
        self.assertEqual(items, [])
        r = L.report()
        self.assertEqual(r["counts"]["sources_failed"], 1,
                         "부재한 «경로가 주어진» 파일은 입력 실패다")

    def test_no_path_is_not_source_failure(self):
        """양성 대조 — 경로가 아예 없는 것은 실패가 아니다."""
        L = mod.Ledger(items="open")
        items, dropped = mod.load_yaml(None, ledger=L)
        self.assertEqual(items, [])
        self.assertEqual(L.report()["counts"]["sources_failed"], 0,
                         "경로 미지정은 입력 실패가 아니다")


class TestUnadjudicated(unittest.TestCase):

    def test_finding_without_verdict_is_counted(self):
        """#8 — 판정이 없는 finding 을 카운터 없이 keep 하던 자리.
        형제 synthesize_artifact_findings.py:197 에는 unadjudicated += 1 이 있다."""
        L = mod.Ledger(items="open")
        findings = [{"file": "a.py", "line": 1, "title": "t", "severity": "high"}]
        kept, dropped = mod.apply_verdicts(findings, [], ledger=L)
        self.assertEqual(len(kept), 1, "미판정 finding 은 유지된다 (fail-open)")
        self.assertEqual(dropped, 0, "malformed 가 아니므로 dropped 는 0")
        self.assertEqual(L.report()["counts"]["held"], 1,
                         "유지하되 «세어야» 한다")

    def test_malformed_finding_still_counted_by_dropped(self):
        """양성 대조 — 기존 `dropped` 채널이 살아 있다.
        `apply_verdicts` 는 이미 non-mapping finding 을 세고 stderr 를 낸다
        (:271-277). 이 전환이 그 채널을 없애면 안 된다."""
        L = mod.Ledger(items="open")
        kept, dropped = mod.apply_verdicts(["문자열 finding"], [], ledger=L)
        self.assertEqual(kept, [])
        self.assertEqual(dropped, 1, "기존 dropped 카운터가 그대로 산다")


if __name__ == "__main__":
    unittest.main()
