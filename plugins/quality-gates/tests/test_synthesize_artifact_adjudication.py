"""전환이 외부 출력을 바꾸지 않는지 고정한다.

기계적 전환이므로 회귀 방어가 이 태스크의 전부다 — 새 행동은 없다.
"""
import contextlib
import importlib.util
import io
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

SCRIPT = (Path(__file__).resolve().parents[1] / "scripts"
          / "synthesize_artifact_findings.py")
spec = importlib.util.spec_from_file_location("synthesize_artifact_findings", SCRIPT)
mod = importlib.util.module_from_spec(spec)
sys.path.insert(0, str(SCRIPT.parent))
spec.loader.exec_module(mod)


class TestOutputUnchanged(unittest.TestCase):

    def test_ledger_is_closed_direction(self):
        """다음 소비자가 기계다 — 미판정 항목은 제외된다."""
        L = mod.Ledger(items="closed")
        L.hold("f1", "판정 부재")
        self.assertEqual(L.surfaced(), [],
                         "items=closed 는 미판정 항목을 노출하지 않는다")
        self.assertTrue(L.blocks(),
                        "제외하되 «막는다» — converged 가 False 여야 한다")

    def test_unadjudicated_still_blocks_convergence(self):
        """:252 의 conjunct 가 살아 있는지."""
        L = mod.Ledger(items="closed")
        L.hold("f1", "판정 부재")
        r = L.report()
        self.assertEqual(r["counts"]["held"], 1)
        self.assertTrue(r["degraded"])

    def test_phase_synth_reports_one_unadjudicated(self):
        """실제 호출 지점(phase_synth)을 직접 구동한다.

        위 두 테스트는 Ledger 모듈 자체의 계약(Task 1 이 이미 잠근 것)만 본다 —
        이 파일이 그 계약을 실제로 어떻게 배선했는지는 보지 않는다. 이 테스트는
        phase_synth 를 직접 호출해 :193-209 의 전환 지점(L.hold + L.report()로
        derive 하는 unadjudicated)을 통과시킨다.

        subprocess 대신 in-process 호출을 골랐다 — phase_synth 는 stdout 에
        직접 yaml 을 쓰므로 redirect_stdout 으로 캡처하면 실제 CLI 호출과
        동일한 코드 경로(argparse 배선 제외)를 검증할 수 있고, 서브프로세스
        기동 비용도 없다. argparse → phase 분기 자체는 이미
        test_synthesize_artifact_findings.sh 가 CLI 경계까지 통째로 덮는다.
        """
        f1 = {"category": "logic", "target_anchor": "#a1", "summary": "gap A",
              "severity": "CRITICAL"}
        f2 = {"category": "logic", "target_anchor": "#a2", "summary": "gap B",
              "severity": "CRITICAL"}
        f1["dedup_key"] = mod.dedup_key(f1)
        f2["dedup_key"] = mod.dedup_key(f2)

        with tempfile.TemporaryDirectory() as td:
            findings_path = str(Path(td) / "merged.yaml")
            adv_path = str(Path(td) / "adv.yaml")
            with open(findings_path, "w", encoding="utf-8") as fh:
                yaml.safe_dump({"findings": [f1, f2], "sources_failed": 0}, fh)
            with open(adv_path, "w", encoding="utf-8") as fh:
                # f1 만 판정한다 — f2 는 미판정으로 남는다.
                yaml.safe_dump({"verdicts": [
                    {"finding_key": f1["dedup_key"], "verdict": "confirm",
                     "evidence": "real"},
                ]}, fh)

            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                mod.phase_synth(findings_path, adv_path)
            parsed = yaml.safe_load(buf.getvalue())

        self.assertEqual(parsed["unadjudicated"], 1,
                         "미판정 finding(f2) 1건이 emit 된 문서에 반영돼야 한다")
        self.assertIs(parsed["converged"], False,
                      "미판정이 남아 있으면 converged 는 False 여야 한다 (AC16)")


if __name__ == "__main__":
    unittest.main()
