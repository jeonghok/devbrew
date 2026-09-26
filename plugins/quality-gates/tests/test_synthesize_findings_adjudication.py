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


class TestRaiseGuard(unittest.TestCase):
    """`_apply_raise` 는 브리지를 거치지 않는 값에도 서야 한다 — 재비판 경로는 브리지가 먼저
    접으므로 CLI 로는 이 가드에 닿지 않는다(모의 실행: 접기를 지워도 CLI 케이스는 GREEN)."""

    def _one(self, sev):
        return {"agent": "security-reviewer", "file": "a.py", "line": 1,
                "severity": sev, "summary": "s", "confidence": 8}

    def test_lowercase_raise_folds_before_the_guard(self):
        f = self._one("IMPORTANT")
        v = {"finding_id": mod.finding_id(f), "verdict": "raise", "adjusted_severity": "critical"}
        out, _ = mod.apply_verdicts([f], [v], ledger=mod.Ledger(items="open"))
        self.assertEqual(out[0]["severity"], "CRITICAL", "소문자 critical 이 SUGGESTION 랭크로 떨어지면 raise 가 저지된다")

    def test_mixed_case_current_severity_is_not_lowered(self):
        f = self._one("Critical")
        v = {"finding_id": mod.finding_id(mod._normalize_identity(dict(f))), "verdict": "raise",
             "adjusted_severity": "IMPORTANT"}
        L = mod.Ledger(items="open")
        out, _ = mod.apply_verdicts([f], [v], ledger=L)
        self.assertEqual(mod._norm_sev(out[0]), "CRITICAL", "낡은 매핑의 raise 가 CRITICAL 을 내리면 안 된다")
        self.assertTrue(any("강제(게이트 변경)" in r for r in L.report()["reasons"]),
                        "내렸을 raise 는 판정을 바꾼 강제로 공시된다")

    def test_equal_raise_is_not_a_gate_coercion(self):
        f = self._one("IMPORTANT")
        v = {"finding_id": mod.finding_id(f), "verdict": "raise", "adjusted_severity": "important"}
        L = mod.Ledger(items="open")
        out, _ = mod.apply_verdicts([f], [v], ledger=L)
        self.assertEqual(out[0]["severity"], "IMPORTANT")
        self.assertFalse(any("강제(게이트 변경)" in r for r in L.report()["reasons"]),
                         "같은 등급 raise 는 표기 강제(gate=False)다")


class TestPromoteAuthorIsRequired(unittest.TestCase):

    def test_promote_new_findings_requires_author(self):
        """기본값이 있으면 판정자 자리가 사라진 뒤 유령 저자가 된다(PR3·PR4a 부채)."""
        with self.assertRaises(TypeError):
            mod.promote_new_findings([], [])
        promoted, dropped = mod.promote_new_findings(
            [{"file": "a.py", "line": 1, "severity": "IMPORTANT", "summary": "s"}], [],
            author="doc-recritic")
        self.assertEqual(dropped, 0)
        self.assertEqual(promoted[0]["agent"], "doc-recritic")

    def test_fold_sev_is_the_one_fold(self):
        """raise 가드와 _norm_sev 가 같은 접기를 쓴다 — 둘이 갈리면 소문자 raise 가 저지된다."""
        self.assertEqual(mod._fold_sev(" critical "), "CRITICAL")
        self.assertEqual(mod._fold_sev(["CRITICAL"]), ["CRITICAL"])
        self.assertEqual(mod._norm_sev({"severity": "Critical"}), "CRITICAL")
        self.assertEqual(mod._norm_sev({"severity": ["CRITICAL"]}), "SUGGESTION")

    def test_promote_new_findings_drops_item_missing_file(self):
        """Controller fix round 1, Minor 3 — R-AD 로 CLI 전환된 케이스(구 test_
        synthesize_promoted_findings.sh 10)는 file 결측을 더는 재지 않는다
        (recritic_bridge 가 file 을 «미지»로 채워 넘겨서 CLI 로는 안 닿는다).
        `promote_new_findings` 의 `NEW_FINDING_REQUIRED` 자체는 여전히 file 을
        요구한다 — 그 규칙을 직접 호출로 핀한다."""
        promoted, dropped = mod.promote_new_findings(
            [{"severity": "IMPORTANT", "summary": "s"}], [], author="doc-recritic")
        self.assertEqual(promoted, [])
        self.assertEqual(dropped, 1, "file 없는 항목은 여전히 malformed 로 드롭된다")

    def test_promote_new_findings_drops_item_missing_severity(self):
        """같은 이유로 severity 결측 드롭 경로도 CLI 밖에서 핀한다 — bridge 는
        severity·disposition 이 둘 다 없어야 «미지» 로 채운다(둘 중 하나만 없으면
        나머지가 대신 잡는다). `promote_new_findings` 자체가 호출자와 무관하게
        severity 를 요구하는지는 이 직접 호출로만 검사된다."""
        promoted, dropped = mod.promote_new_findings(
            [{"file": "a.py", "summary": "s"}], [], author="doc-recritic")
        self.assertEqual(promoted, [])
        self.assertEqual(dropped, 1, "severity 없는 항목은 여전히 malformed 로 드롭된다")


class TestMalformedContainerAtDocLevel(unittest.TestCase):
    """R-AD — `verdicts:`/`new_findings:` 가 컨테이너 수준에서 매핑·스칼라인 옛
    --adversarial 문서 모양은 CLI 로 다시 나타날 수 없다: `recritic_bridge.
    to_adjudication_doc` 는 이 두 키가 list 가 아니면 그 자리에서 판정자 사망으로
    돌려버린다(옛 test_synthesize_promoted_findings.sh 케이스 10c·13·15).

    **그 살아 있는 방어 자체**(`to_adjudication_doc` 의 `if not isinstance(...):
    return _dead(...)`)는 CLI 로 여전히 도달 가능하다 — 진짜 재비판자 응답의
    `added: 5`/매핑 등으로. 그 자리는 여기가 아니라
    test_recritic_bridge.sh::case_malformed_top_level_container_kills_adjudicator_not_the_run
    가 잰다(Controller fix round 1 — 그 방어를 `if False:` 로 바꿔도 이 파일의
    단위 테스트 셋은 GREEN 이었다: `extract_new_findings`/`extract_verdicts`
    를 직접 불러 그 방어를 건너뛰기 때문이다). 이 클래스는 그 아래 계층
    (`_as_list` — 항목 수만큼 dropped 로 세고 크래시하지 않는다)만 잰다."""

    def test_new_findings_scalar_is_not_a_crash(self):
        L = mod.Ledger(items="open")
        items, dropped = mod.extract_new_findings({"new_findings": 5}, ledger=L)
        self.assertEqual(items, [])
        self.assertEqual(dropped, 1, "스칼라 컨테이너는 주장 하나로 센다")

    def test_new_findings_mapping_is_counted_dropped(self):
        L = mod.Ledger(items="open")
        items, dropped = mod.extract_new_findings(
            {"new_findings": {"first": {"file": "x.py"}, "second": {"file": "y.py"}}},
            ledger=L)
        self.assertEqual(items, [])
        self.assertEqual(dropped, 2, "매핑 컨테이너는 항목 수만큼 센다")

    def test_verdicts_mapping_is_counted_dropped(self):
        L = mod.Ledger(items="open")
        items, dropped = mod.extract_verdicts(
            {"verdicts": {"a": {"finding_id": "x", "verdict": "reject"}}}, ledger=L)
        self.assertEqual(items, [])
        self.assertEqual(dropped, 1)


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
