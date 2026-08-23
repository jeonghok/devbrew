"""전환이 외부 출력을 바꾸지 않는지 고정한다.

기계적 전환이므로 회귀 방어가 이 태스크의 전부다 — 새 행동은 없다.
"""
import importlib.util
import sys
import unittest
from pathlib import Path

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


if __name__ == "__main__":
    unittest.main()
