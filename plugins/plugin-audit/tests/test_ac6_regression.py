import json, subprocess, sys, tempfile, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]        # repo root (tests→plugin-audit→plugins→repo)
FIX = Path(__file__).resolve().parent / "fixtures"
ASM = Path(__file__).resolve().parents[1] / "scripts" / "assemble-audit-data.py"
BASELINE = ROOT / "docs/audits/2026-07-15-project-init-audit-data.json"

# §13 신규(비교 제외): baseline에 부재하는 필드만
EXCLUDE_META = {"target", "seed_provided", "assigned_d", "assigned_oq"}
EXCLUDE_FINDING = {"grounding_verified"}   # baseline엔 없음(annotate-only로 붙음) → 제외


def project(obj):
    obj = json.loads(json.dumps(obj))
    for k in EXCLUDE_META:
        obj["meta"].pop(k, None)
    for f in obj["findings"]:
        for k in EXCLUDE_FINDING:
            f.pop(k, None)
    return obj


class TestAC6(unittest.TestCase):
    def test_generalized_assembly_reproduces_baseline(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / "out.json"
            r = subprocess.run([sys.executable, str(ASM),
                                "--workflow-return", str(FIX / "ac6_workflow_return.json"),
                                "--codex-side", str(FIX / "ac6_codex_side.json"),
                                "--meta", str(FIX / "ac6_meta.json"),
                                "--assigned", str(FIX / "ac6_assigned.json"),
                                "--repo-root", str(ROOT), "--no-grounding",
                                "--out", str(out)], capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            got = json.loads(out.read_text(encoding="utf-8"))
            base = json.loads(BASELINE.read_text(encoding="utf-8"))
            gp, bp = project(got), project(base)
            # legacy 필드 등가: finding id·status·정렬 + cross_model_confirmed 재계산 일치
            self.assertEqual([f["id"] for f in gp["findings"]], [f["id"] for f in bp["findings"]])
            self.assertEqual([f["status"] for f in gp["findings"]], [f["status"] for f in bp["findings"]])
            self.assertEqual({f["id"]: f["cross_model_confirmed"] for f in gp["findings"]},
                             {f["id"]: f["cross_model_confirmed"] for f in bp["findings"]})
            # codex-merge 구조: d_verdicts source 분포 동일
            self.assertEqual(sorted(v["source"] for v in gp["d_verdicts"]),
                             sorted(v["source"] for v in bp["d_verdicts"]))

    def test_cx2_and_a61_reproduced(self):
        base = json.loads(BASELINE.read_text(encoding="utf-8"))
        ids = {f["id"] for f in base["findings"]}
        self.assertIn("CX-2", ids)
        self.assertIn("A6-1", ids)


if __name__ == "__main__":
    unittest.main()
