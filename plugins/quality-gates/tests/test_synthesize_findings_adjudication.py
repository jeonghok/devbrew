"""synthesize_findings 가 «파일 부재»와 «경로 없음»을 구별하는지, 미판정을 세는지 본다.

원장만 재는 단언은 판정 기준이 아니다 — 원장이 옳아도 소비자가 그것을 안 읽으면
사용자가 보는 것은 여전히 clean 이다. 그래서 아래 `TestOutputSurface` 는 원장이 아니라
**stdout** 을 본다.
"""
import contextlib
import importlib.util
import io
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
        형제 synthesize_artifact_findings.py:199 에는 L.hold(...) 가 있다."""
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


def _run(argv):
    """`main()` 을 돌려 stdout 을 문자열로 돌려준다.

    `render()` 를 직접 부르지 않는 이유: 결함은 render 안이 아니라 main→render
    **이음매**에 있었다(원장은 degrade 를 올바로 세는데 main 이 `held` 만 꺼내
    갔다). 이음매를 건너뛰는 테스트는 그 결함을 볼 수 없다.
    """
    buf = io.StringIO()
    old = sys.argv
    sys.argv = ["synthesize_findings.py"] + list(argv)
    try:
        with contextlib.redirect_stdout(buf):
            mod.main()
    finally:
        sys.argv = old
    return buf.getvalue()


class TestOutputSurface(unittest.TestCase):
    """설계 §10.3 — 「깨끗함」과 바이트 동일한 출력이 나오면 RED."""

    def test_dead_primary_input_output_differs_from_clean(self):
        clean = _run([])
        degraded = _run(["--findings", "/nonexistent/findings.yaml"])
        self.assertNotEqual(
            degraded, clean,
            "주 입력이 죽었는데 출력이 clean 과 바이트 동일하다 — "
            "원장이 degrade 를 세도 소비자가 안 읽으면 사용자는 clean 을 본다")
        self.assertIn(mod.DEGRADE_MARKER, degraded,
                      "degrade 공시 마커가 stdout 에 없다")
        self.assertIn("입력 실패(주)", degraded, "무엇이 degrade 인지가 없다")

    def test_clean_run_has_no_degrade_notice(self):
        """양성 짝 — 아무 때나 켜지는 공시는 공시가 아니다."""
        clean = _run([])
        self.assertNotIn(mod.DEGRADE_MARKER, clean)
        self.assertIn("No high-confidence findings.", clean)

    def test_degrade_shows_on_the_table_branch_too(self):
        """두 갈래 모두 — 살아남은 발견이 있어도 공시는 나가야 한다."""
        with tempfile.NamedTemporaryFile(
                "w", suffix=".yaml", encoding="utf-8", delete=False) as fh:
            fh.write("findings:\n"
                     "  - {file: a.py, line: 3, severity: CRITICAL, "
                     "summary: boom, confidence: 9, agent: sec}\n")
            path = fh.name
        out = _run(["--findings", path])
        self.assertIn("| CRITICAL |", out, "표 갈래를 탔는지 먼저 확인한다")
        self.assertIn(mod.DEGRADE_MARKER, out,
                      "표가 있는 갈래에서 degrade 공시가 사라졌다")


if __name__ == "__main__":
    unittest.main()
