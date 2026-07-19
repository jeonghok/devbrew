import json, subprocess, sys, tempfile, unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "assemble-audit-data.py"


def run(**files):
    with tempfile.TemporaryDirectory() as d:
        d = Path(d)
        args = [sys.executable, str(SCRIPT)]
        for flag, obj in files.items():
            p = d / f"{flag}.json"
            p.write_text(json.dumps(obj), encoding="utf-8")
            args += [f"--{flag.replace('_','-')}", str(p)]
        out = d / "out.json"
        args += ["--repo-root", str(d), "--no-grounding", "--out", str(out)]
        r = subprocess.run(args, capture_output=True, text=True)
        data = json.loads(out.read_text(encoding="utf-8")) if out.exists() else None
        return r, data


BASE_META = {"date": "2026-01-01", "fanout_declared": 30,
             "consent": {"approved": True, "at": "2026-01-01T00:00Z", "fanout": 30},
             "codex": {"ran": True, "version": "1.0"}, "target": "myplugin", "seed_provided": False}


class TestAssemble(unittest.TestCase):
    def test_codex_side_merged_with_source(self):
        r, data = run(
            workflow_return={"findings": [], "d_verdicts": [{"id": "D1", "verdict": "confirmed", "reason": "x", "source": "claude"}],
                             "oq_answers": [], "new_open_questions": [], "axis_failures": [], "degraded_events": []},
            codex_side={"d_verdicts": [{"id": "D1", "verdict": "withdrawn", "reason": "y"}], "oq_answers": [], "new_open_questions": []},
            meta=BASE_META, assigned={"assigned_d": ["D1"], "assigned_oq": []})
        self.assertEqual(r.returncode, 0)
        srcs = sorted(v["source"] for v in data["d_verdicts"])
        self.assertEqual(srcs, ["claude", "codex"])  # codex-merge, source stamped

    def test_backfill_unverified_for_dead_axis(self):
        # assigned D2가 어떤 source에도 없음 → unverified 백필 (이 run은 미발화 → 합성 fixture)
        r, data = run(
            workflow_return={"findings": [], "d_verdicts": [{"id": "D1", "verdict": "confirmed", "reason": "x", "source": "claude"}],
                             "oq_answers": [], "new_open_questions": [], "axis_failures": [2], "degraded_events": []},
            codex_side={"d_verdicts": [], "oq_answers": [], "new_open_questions": []},
            meta=BASE_META, assigned={"assigned_d": ["D1", "D2"], "assigned_oq": []})
        d2 = [v for v in data["d_verdicts"] if v["id"] == "D2"]
        self.assertTrue(d2 and d2[0]["verdict"] == "unverified", "dead-axis D2 not backfilled")

    def test_cross_model_confirmed_on_file_line_overlap(self):
        f_claude = {"id": "A1-1", "axis": 1, "source": "claude", "status": "reported",
                    "evidence": [{"file": "a.py", "line": 5, "quote": "q"}], "severity": "HIGH"}
        f_codex = {"id": "CX-1", "axis": 1, "source": "codex", "status": "reported",
                   "evidence": [{"file": "a.py", "line": 5, "quote": "q"}], "severity": "HIGH"}
        # MUTATION-TEETH: non-overlapping finding must NOT be marked cross_model_confirmed.
        # Catches an `&` (intersection) -> `|` (union) mutation in ev_keys(f) & other[...].
        f_claude_solo = {"id": "A1-2", "axis": 1, "source": "claude", "status": "reported",
                         "evidence": [{"file": "b.py", "line": 9, "quote": "q2"}], "severity": "HIGH"}
        r, data = run(
            workflow_return={"findings": [f_claude, f_codex, f_claude_solo], "d_verdicts": [], "oq_answers": [],
                             "new_open_questions": [], "axis_failures": [], "degraded_events": []},
            codex_side={"d_verdicts": [], "oq_answers": [], "new_open_questions": []},
            meta=BASE_META, assigned={"assigned_d": [], "assigned_oq": []})
        by = {f["id"]: f for f in data["findings"]}
        self.assertTrue(by["A1-1"]["cross_model_confirmed"] and by["CX-1"]["cross_model_confirmed"])
        self.assertFalse(by["A1-2"]["cross_model_confirmed"], "non-overlapping finding wrongly cross-model-confirmed")

    def test_gate_e_refuted_becomes_noq(self):
        f = {"id": "A1-9", "axis": 1, "source": "claude", "status": "refuted",
             "refutation": {"stage": "axis", "gate": "E", "reason": "scope-out"},
             "evidence": [{"file": "x", "line": 1, "quote": "q"}], "severity": "LOW"}
        r, data = run(
            workflow_return={"findings": [f], "d_verdicts": [], "oq_answers": [],
                             "new_open_questions": [], "axis_failures": [], "degraded_events": []},
            codex_side={"d_verdicts": [], "oq_answers": [], "new_open_questions": []},
            meta=BASE_META, assigned={"assigned_d": [], "assigned_oq": []})
        self.assertTrue(any(n.get("why_not_gap") for n in data["new_open_questions"]), "gate-E refuted not routed to NOQ")

    def test_meta_and_degraded_attached(self):
        r, data = run(
            workflow_return={"findings": [], "d_verdicts": [], "oq_answers": [],
                             "new_open_questions": [], "axis_failures": [], "degraded_events": ["codex timeout"]},
            codex_side={"d_verdicts": [], "oq_answers": [], "new_open_questions": []},
            meta=BASE_META, assigned={"assigned_d": [], "assigned_oq": []})
        self.assertEqual(data["meta"]["target"], "myplugin")
        self.assertIn("codex timeout", data["degraded"])


if __name__ == "__main__":
    unittest.main()
