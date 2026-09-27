"""synthesize_findings 가 «파일 부재»와 «경로 없음»을 구별하는지, 미판정을 세는지 본다.

원장만 재는 단언은 판정 기준이 아니다 — 원장이 옳아도 소비자가 그것을 안 읽으면
사용자가 보는 것은 여전히 clean 이다. 그래서 아래 `TestOutputSurface` 는 원장이 아니라
**stdout** 을 본다.
"""
import contextlib
import importlib.util
import io
import json
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


class TestMissingConfidenceNotSuppressedAsZero(unittest.TestCase):
    """누락된 confidence 가 억제 바닥(conf<=4) 아래로 조용히 떨어지지 않는다.

    `suppress()`는 non-CRITICAL·conf<=4 를 억제하고 판정(`_verdict.decide(
    defect=bool(kept), …)`)은 severity 를 안 묻는다 — confidence 가 없는
    finding 이 억제되면 그만큼 `kept`가 줄고, 차등 테스트가 깨끗하면 거짓
    `clean`이 날 수 있다. 누락도 malformed(`"high"`·null 등)와 같은 값(5)으로
    맞춘다.

    confidence 강제가 **게이트(억제 여부)를 실제로 바꾸는지**는 항목의 운명과
    최종 severity에 달려 있다 — `reject`된 항목은 판정에 안 들어가므로 못
    바꾸고, CRITICAL은 confidence와 무관하게 늘 kept라 못 바꾼다. 그래서
    `ledger.coerced()`의 `gate`는 조건부다(값 고정 자체는 항상 하되, 게이트를
    실제로 바꾸는 갈래에서만 `gate=True`로 센다). 승격 경로의 confidence
    누락은 판정자 자신의 주장에 대한 설계된 인코딩이라 세지 않지만, 승격
    경로의 non-numeric(malformed) 값은 판정자가 잘못 준 값이라 여전히 세진다.
    """

    def test_a_missing_confidence_defaults_to_five_not_suppressed(self):
        f = {"agent": "sec", "file": "a.py", "line": 1, "severity": "IMPORTANT",
             "summary": "s"}
        v = {"finding_id": mod.finding_id(f), "verdict": "confirm"}
        L = mod.Ledger(items="open")
        out, dropped = mod.apply_verdicts([f], [v], ledger=L)
        self.assertEqual(dropped, 0)
        self.assertEqual(out[0]["confidence"], 5,
                         "누락된 confidence 는 malformed 와 같은 값(5)으로 강제된다")
        kept, suppressed = mod.suppress(out, ledger=L)
        self.assertEqual(len(kept), 1,
                         "0 으로 접히면 non-CRITICAL·conf<=4 바닥에 유일하게 걸려 억제된다")
        self.assertEqual(len(suppressed), 0)
        r = L.report()
        self.assertEqual(r["counts"]["coerced"], 1, "누락도 강제로 정확히 1건 세어진다")
        self.assertIn("강제(게이트 변경): confidence None→5", r["reasons"],
                      "그 값이 억제 여부를 정하므로 게이트를 바꾼 강제(gate=True)로 공시된다")

    def test_b_non_numeric_confidence_same_treatment_and_now_counted(self):
        f = {"agent": "sec", "file": "a.py", "line": 1, "severity": "IMPORTANT",
             "summary": "s", "confidence": "high"}
        v = {"finding_id": mod.finding_id(f), "verdict": "confirm"}
        L = mod.Ledger(items="open")
        out, _dropped = mod.apply_verdicts([f], [v], ledger=L)
        self.assertEqual(out[0]["confidence"], 5)
        kept, suppressed = mod.suppress(out, ledger=L)
        self.assertEqual(len(kept), 1)
        r = L.report()
        self.assertEqual(r["counts"]["coerced"], 1)
        self.assertIn("강제(게이트 변경): confidence 'high'→5", r["reasons"],
                      "원값(malformed 표기)이 사유 줄에 그대로 남는다")

    def test_b2_bool_confidence_is_non_numeric_and_counted(self):
        """`bool`은 `int`의 하위형이라 맨 `int()`를 그냥 통과한다 — 숫자가 아닌
        것으로 명시적으로 막지 않으면 `True`가 confidence 1이 된다."""
        f = {"agent": "sec", "file": "a.py", "line": 1, "severity": "IMPORTANT",
             "summary": "s", "confidence": True}
        v = {"finding_id": mod.finding_id(f), "verdict": "confirm"}
        L = mod.Ledger(items="open")
        out, _dropped = mod.apply_verdicts([f], [v], ledger=L)
        self.assertEqual(out[0]["confidence"], 5, "bool 은 숫자가 아닌 것으로 본다")
        r = L.report()
        self.assertEqual(r["counts"]["coerced"], 1)
        self.assertIn("강제(게이트 변경): confidence True→5", r["reasons"])

    def test_c_numeric_confidence_is_fixed_not_coerced(self):
        """양의 짝 — 표기만 다를 뿐 값이 같은 confidence 는 강제로 세지 않는다."""
        f8 = {"agent": "sec", "file": "a.py", "line": 1, "severity": "IMPORTANT",
              "summary": "s", "confidence": 8}
        v8 = {"finding_id": mod.finding_id(f8), "verdict": "confirm"}
        L8 = mod.Ledger(items="open")
        out8, _ = mod.apply_verdicts([f8], [v8], ledger=L8)
        self.assertEqual(out8[0]["confidence"], 8)
        self.assertEqual(L8.report()["counts"]["coerced"], 0)

        f7 = {"agent": "sec", "file": "b.py", "line": 2, "severity": "IMPORTANT",
              "summary": "s", "confidence": "7"}
        v7 = {"finding_id": mod.finding_id(f7), "verdict": "confirm"}
        L7 = mod.Ledger(items="open")
        out7, _ = mod.apply_verdicts([f7], [v7], ledger=L7)
        self.assertEqual(out7[0]["confidence"], 7, "문자열 숫자도 int 로 확정된다")
        self.assertEqual(L7.report()["counts"]["coerced"], 0,
                         "표기만 다를 뿐 값이 같으므로 강제로 세지 않는다")

    def test_d_critical_missing_confidence_still_kept_and_coerced_without_gate(self):
        """CRITICAL 은 전과 같이 kept 다. confidence 강제는 여전히 값 수준에서
        일어나(coerced 1건) 세어지지만, CRITICAL은 confidence 와 무관하게 늘
        kept 이므로 그 강제는 억제 여부(게이트)를 바꾸지 않는다 — `gate=False`
        (/qg 리뷰 라운드 1 I-1: 무조건 `gate=True`는 아무것도 안 바꾼 강제를
        거짓으로 「게이트 변경」이라 공시했다)."""
        f = {"agent": "sec", "file": "a.py", "line": 1, "severity": "CRITICAL",
             "summary": "s"}
        v = {"finding_id": mod.finding_id(f), "verdict": "confirm"}
        L = mod.Ledger(items="open")
        out, _ = mod.apply_verdicts([f], [v], ledger=L)
        kept, suppressed = mod.suppress(out, ledger=L)
        self.assertEqual(len(kept), 1, "CRITICAL 은 confidence 와 무관하게 kept (전과 같음)")
        self.assertEqual(len(suppressed), 0)
        r = L.report()
        self.assertEqual(r["counts"]["coerced"], 1, "값 강제 자체는 여전히 세어진다")
        self.assertFalse(
            any("강제(게이트 변경)" in reason for reason in r["reasons"]),
            "CRITICAL 은 confidence 로 kept 여부가 안 바뀌므로 게이트를 안 바꾼 "
            "강제(gate=False)다 — 「게이트 변경」줄이 없어야 한다")

    def test_g_rejected_item_with_missing_confidence_has_no_coercion_entry(self):
        """기각된 항목은 판정(kept/suppressed)에 아예 안 들어가므로 confidence
        강제가 게이트를 못 바꾼다 — 강제 자체를 세지 않는다(/qg 리뷰 라운드 1 I-1:
        기각된 IMPORTANT가 「강제(게이트 변경)」+「차단: 예」를 `verdict: clean`
        옆에 거짓으로 띄웠다)."""
        f = {"agent": "sec", "file": "a.py", "line": 1, "severity": "IMPORTANT",
             "summary": "s"}
        v = {"finding_id": mod.finding_id(f), "verdict": "reject", "evidence": "e"}
        L = mod.Ledger(items="open")
        out, _dropped = mod.apply_verdicts([f], [v], ledger=L)
        self.assertEqual(out, [], "기각된 항목은 out 에 없다")
        r = L.report()
        self.assertEqual(r["counts"]["coerced"], 0,
                         "기각된 항목의 confidence 강제는 세지 않는다")
        self.assertFalse(r["degraded"],
                         "기각만 있고 다른 degrade 사유가 없으면 degrade 가 아니다")

    def test_e_promoted_missing_confidence_defaults_to_five_but_not_coerced(self):
        """승격 경로 — 기본값 5 는 판정자 자신의 주장에 대한 설계된 인코딩이지
        강제가 아니다. 세면 승격이 있는 모든 실행이 degrade 가 된다. 키 없음은
        stderr 도 안 낸다(M-1) — 이상이 아니라 정상 경로이기 때문이다."""
        L = mod.Ledger(items="open")
        buf = io.StringIO()
        with contextlib.redirect_stderr(buf):
            promoted, dropped = mod.promote_new_findings(
                [{"file": "a.py", "line": 1, "severity": "IMPORTANT", "summary": "s"}],
                [], author="doc-recritic", ledger=L)
        self.assertEqual(dropped, 0)
        self.assertEqual(promoted[0]["confidence"], 5)
        kept, suppressed = mod.suppress(promoted, ledger=L)
        self.assertEqual(len(kept), 1)
        self.assertEqual(L.report()["counts"]["coerced"], 0,
                         "승격 경로의 기본 confidence 는 강제로 세지 않는다")
        self.assertNotIn("missing confidence", buf.getvalue(),
                         "승격 경로의 키 없음은 이상이 아니므로 stderr 도 안 낸다")

    def test_h_promoted_non_numeric_confidence_is_counted(self):
        """승격 경로에서도 non-numeric(malformed) confidence 는 키 없음과 달리
        강제로 센다 — 판정자가 «잘못 준» 값이라 여전히 malformed 다(/qg 리뷰
        라운드 1 I-3: 예전에는 `count=False` 가 이 갈래까지 조용히 죽였다 —
        `confidence: low`→5 가 SUGGESTION 을 kept 로 바꾸고 `defect`를 내는데도
        아무것도 공시되지 않았다)."""
        L = mod.Ledger(items="open")
        buf = io.StringIO()
        with contextlib.redirect_stderr(buf):
            promoted, dropped = mod.promote_new_findings(
                [{"file": "b.py", "line": 2, "severity": "SUGGESTION", "summary": "s",
                  "confidence": "low"}],
                [], author="doc-recritic", ledger=L)
        self.assertEqual(dropped, 0)
        self.assertEqual(promoted[0]["confidence"], 5)
        self.assertIn("non-numeric confidence", buf.getvalue(),
                      "non-numeric 은 두 경로 모두에서 stderr 를 낸다")
        kept, suppressed = mod.suppress(promoted, ledger=L)
        self.assertEqual(len(kept), 1, "5는 억제 바닥(<=4) 위이므로 kept — 이 강제가 defect 를 만든다")
        r = L.report()
        self.assertEqual(r["counts"]["coerced"], 1,
                         "non-numeric 은 승격 경로에서도 강제로 센다")
        self.assertIn("강제(게이트 변경): confidence 'low'→5", r["reasons"])

    def test_i_overflow_confidence_defaults_to_five_without_crash(self):
        """`confidence: .inf`(YAML 이 `float('inf')`로 읽는다)는 `int()`에서
        `OverflowError`를 던진다 — `TypeError`/`ValueError`만 잡던 자리는
        여기서 그대로 죽었다(/qg 리뷰 라운드 1 M-2)."""
        f = {"agent": "sec", "file": "a.py", "line": 1, "severity": "IMPORTANT",
             "summary": "s", "confidence": float("inf")}
        v = {"finding_id": mod.finding_id(f), "verdict": "confirm"}
        L = mod.Ledger(items="open")
        out, dropped = mod.apply_verdicts([f], [v], ledger=L)
        self.assertEqual(dropped, 0)
        self.assertEqual(out[0]["confidence"], 5)
        self.assertEqual(L.report()["counts"]["coerced"], 1)

    def test_j_conf_safety_net_handles_overflow_and_bool(self):
        """`_conf` 총함수 안전망도 `_normalize_confidence`와 같은 가드를 갖는다
        (M-2 · M-3) — 이 초크포인트를 우회한 호출에도 억제 바닥 함정·크래시가
        되살아나지 않는다."""
        self.assertEqual(mod._conf({"confidence": float("inf")}), 5)
        self.assertEqual(mod._conf({"confidence": True}), 5)

    def test_f_cli_seam_missing_confidence_survives_end_to_end(self):
        """이음매(CLI) — findings YAML 에 confidence 없는 IMPORTANT 하나 + 그 항목을
        confirm 하는 재비판 판정. 판정자 부재 hold 가 끼지 않도록 실제로 confirm 한다.

        네 단언(표 행·suppressed 부재·DEGRADE_MARKER·verdict: defect)만으로는
        held(판정자 부재) 변형과 구별이 안 된다 — /qg 리뷰 라운드 1 I-2: 존재
        하지 않는 f 를 가리키도록 바꿔도(=hold 로 떨어져도) 네 단언이 전부
        그대로 통과했다(hold 경로도 confidence 를 강제하고 표에 싣고 defect
        를 내므로). confirm 이 실제로 적용됐다는 목적지-양의 단언(수용 1 ·
        미판정 0 · findings-lost 부재 · clean이 아니다 부재)을 더해 hold
        변형과 실제로 갈라지게 한다."""
        with tempfile.TemporaryDirectory() as d:
            findings_path = Path(d) / "findings.yaml"
            findings_path.write_text(
                "findings:\n"
                "  - {agent: sec, file: a.py, line: 1, severity: IMPORTANT, "
                "summary: '누락 confidence'}\n",
                encoding="utf-8")
            findings, _dropped, _dead = mod.load_findings(str(findings_path))
            items, mapping = mod._bridge.anonymize(findings)
            self.assertTrue(items, "픽스처 전제: 항목이 anonymize 를 통과해야 한다")
            map_path = Path(d) / "map.json"
            map_path.write_text(json.dumps(mapping, ensure_ascii=False), encoding="utf-8")
            reply_path = Path(d) / "reply.txt"
            reply_path.write_text(
                "재비판을 마쳤습니다.\n\n```docreview-recritic\n"
                "verdicts:\n  - {f: f1, verdict: confirm}\n"
                "```\n", encoding="utf-8")
            out = _run(["--findings", str(findings_path),
                       "--recritic", str(reply_path),
                       "--recritic-map", str(map_path),
                       "--emit-verdict"])
        self.assertIn("| IMPORTANT |", out, "confirm 된 IMPORTANT 가 표에 실린다")
        self.assertNotIn("suppressed (conf <= 4)", out,
                         "「suppressed」 집계에 0 이 아닌 수로 세지지 않는다")
        self.assertIn("억제 0", out, "양의 짝 — 처분 줄의 억제 칸도 0 이다")
        self.assertIn(mod.DEGRADE_MARKER, out, "confidence 강제가 degrade 로 공시된다")
        self.assertIn("verdict: defect", out,
                      "kept 가 1건이므로 판정 꼬리는 defect 다 (defect=bool(kept))")
        # 목적지-양의 단언 — held(판정자 부재) 변형에서는 이 다섯이 전부 다르게 나온다
        # (수용 0 · 미판정 1 · 「공시」 대신 「이 실행은 clean이 아니다」 · reasons:
        # [findings-lost]).
        self.assertIn("강제(게이트 변경): confidence None→5", out)
        self.assertIn("공시(판정을 막지 않음)", out)
        self.assertIn("미판정 0", out)
        self.assertNotIn("findings-lost", out)
        self.assertNotIn("clean이 아니다", out)


if __name__ == "__main__":
    unittest.main()
