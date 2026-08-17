import json, subprocess, sys, tempfile, unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "assemble-audit-data.py"


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


def run_live_grounding(repo_files, **files):
    """run() 변형 — Task 14 REVIEW FIX: --no-grounding을 생략하고 --repo-root를
    실제 소스 파일이 존재하는 tempdir로 지정해 LIVE grounding 경로(_load_grounding()
    → check-grounding.py resolve + ground_finding() 호출)를 실제로 태운다."""
    with tempfile.TemporaryDirectory() as d:
        d = Path(d)
        for name, content in repo_files.items():
            (d / name).write_text(content, encoding="utf-8")
        args = [sys.executable, str(SCRIPT)]
        for flag, obj in files.items():
            p = d / f"{flag}.json"
            p.write_text(json.dumps(obj), encoding="utf-8")
            args += [f"--{flag.replace('_','-')}", str(p)]
        out = d / "out.json"
        args += ["--repo-root", str(d), "--out", str(out)]  # 의도적으로 --no-grounding 생략
        r = subprocess.run(args, capture_output=True, text=True)
        data = json.loads(out.read_text(encoding="utf-8")) if out.exists() else None
        return r, data


BASE_META = {"date": "2026-01-01", "fanout_declared": 30,
             "consent": {"approved": True, "at": "2026-01-01T00:00Z", "fanout": 30},
             "codex": {"ran": True, "version": "1.0"}, "target": "myplugin", "seed_provided": False}


class TestAssemble(unittest.TestCase):
    def test_malformed_codex_finding_does_not_crash_assembly(self):  # V2-1/V2-2 (codex re-verify round-2 근본 봉쇄)
        # codex findings는 schema 미검증으로 findings에 병합돼(audit-workflow.js) evidence/refutation이
        # 비정상형일 수 있다. ev_keys(line22)는 비-dict evidence 원소의 .get()에서 크래시 + list file/line로
        # unhashable set-key 크래시, gate-E(line72)는 truthy non-dict refutation의 .get()에서 크래시 → post-1
        # 조립 전체 DoS(grounding·validate 하드닝이 우회된다). ingestion 정규화(_sanitize_finding)로 근본 봉쇄.
        r, data = run(
            workflow_return={"findings": [
                {"id": "CX-1", "source": "codex", "status": "refuted", "refutation": "gate E",
                 "evidence": [{"file": ["a.py"], "line": [1], "quote": 5}, "not-a-dict"]}],
                "d_verdicts": [], "oq_answers": [], "new_open_questions": [],
                "axis_failures": [], "degraded_events": []},
            codex_side={"d_verdicts": [], "oq_answers": [], "new_open_questions": []},
            meta=BASE_META, assigned={"assigned_d": [], "assigned_oq": []})
        self.assertEqual(r.returncode, 0, f"malformed codex finding이 조립을 크래시시킴:\n{r.stderr}")
        self.assertIsNotNone(data, "출력 미생성 (크래시)")

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
        # degraded 항목은 {what,why}로 정규화된다 (pre-0/pre-1 게이트가 방출하는 평문 문자열이
        # render의 x.get('what')을 크래시시키지 않도록). 내용 존재는 직렬화본으로 확인한다.
        self.assertIn("codex timeout", json.dumps(data["degraded"], ensure_ascii=False))
        self.assertTrue(all(isinstance(x, dict) for x in data["degraded"]),
                        "degraded 항목이 {what,why} dict로 정규화되지 않음 (render 크래시 위험)")

    def test_assemble_runs_grounding_live(self):
        # REVIEW FIX (Task 14): 5개 기존 테스트는 전부 --no-grounding으로 grounding을
        # 우회한다. 이 테스트는 --no-grounding 없이 assemble()을 돌려 _load_grounding()이
        # check-grounding.py를 실제로 resolve하고 ground_finding()이 findings를 mutate하는
        # LIVE 경로를 잠근다.
        f_match = {"id": "G-1", "axis": 1, "source": "claude", "status": "reported",
                   "evidence": [{"file": "src.py", "line": 3, "quote": "HELLO WORLD"}], "severity": "HIGH"}
        f_nomatch = {"id": "G-2", "axis": 1, "source": "claude", "status": "reported",
                     "evidence": [{"file": "src.py", "line": 1, "quote": "NOT PRESENT ANYWHERE"}], "severity": "LOW"}
        r, data = run_live_grounding(
            {"src.py": "line1\nline2\nHELLO WORLD\nline4\n"},
            workflow_return={"findings": [f_match, f_nomatch], "d_verdicts": [], "oq_answers": [],
                             "new_open_questions": [], "axis_failures": [], "degraded_events": []},
            codex_side={"d_verdicts": [], "oq_answers": [], "new_open_questions": []},
            meta=BASE_META, assigned={"assigned_d": [], "assigned_oq": []})
        self.assertEqual(r.returncode, 0, r.stderr)
        by = {f["id"]: f for f in data["findings"]}
        self.assertTrue(by["G-1"]["grounding_verified"], "live grounding did not verify a real matching quote")
        self.assertFalse(by["G-2"]["grounding_verified"], "live grounding wrongly verified a non-matching quote")
        self.assertEqual(by["G-2"]["status"], "discarded", "non-matching quote finding not discarded by live grounding")

    def test_grounding_degraded_promoted_to_toplevel(self):
        # WB-minor: grounding이 폐기한 finding의 degraded_event가 최상위 degraded[]로 승격돼
        # 정직성 배너에 흔적을 남겨야 한다 (AC-3, 조용한 증발 금지). LIVE grounding 경로로
        # (--no-grounding 없이) 인용이 부재한 finding을 태운다 — 승격 루프를 제거하면 RED.
        f_absent = {"id": "G-9", "axis": 1, "source": "claude", "status": "reported",
                    "evidence": [{"file": "src.py", "line": 1, "quote": "NOT PRESENT ANYWHERE"}], "severity": "HIGH"}
        r, data = run_live_grounding(
            {"src.py": "line1\nline2\n"},
            workflow_return={"findings": [f_absent], "d_verdicts": [], "oq_answers": [],
                             "new_open_questions": [], "axis_failures": [], "degraded_events": []},
            codex_side={"d_verdicts": [], "oq_answers": [], "new_open_questions": []},
            meta=BASE_META, assigned={"assigned_d": [], "assigned_oq": []})
        self.assertEqual(r.returncode, 0, r.stderr)
        by = {f["id"]: f for f in data["findings"]}
        self.assertEqual(by["G-9"]["status"], "discarded", "absent-citation finding not discarded by live grounding")
        blob = json.dumps(data["degraded"], ensure_ascii=False)
        self.assertIn("G-9", blob,
                      "discarded finding left no note in top-level degraded[] (silent evaporation)")

    def test_backfill_claude_unverified_even_when_codex_supplied(self):
        # C2: dead Claude 축이라도 codex가 답하면 'axis incomplete' backfill이 떠야 한다.
        # have_d를 codex 병합 *후* 전체(any-source)로 보면 codex D2가 Claude 죽음을 조용히
        # 가린다 — claude-source만 봐야 정직(LD4). codex만 D2를 답하고 Claude는 부재.
        r, data = run(
            workflow_return={"findings": [], "d_verdicts": [], "oq_answers": [],
                             "new_open_questions": [], "axis_failures": [], "degraded_events": []},
            codex_side={"d_verdicts": [{"id": "D2", "verdict": "confirmed", "reason": "codex만"}],
                        "oq_answers": [], "new_open_questions": []},
            meta=BASE_META, assigned={"assigned_d": ["D2"], "assigned_oq": []})
        self.assertEqual(r.returncode, 0, r.stderr)
        d2 = [v for v in data["d_verdicts"] if v["id"] == "D2"]
        srcs = sorted(v["source"] for v in d2)
        self.assertIn("codex", srcs, "codex D2 판정이 있어야")
        self.assertIn("claude", srcs,
                      "codex만 답한 죽은 Claude 축에도 claude unverified backfill이 떠야 (C2)")
        claude_d2 = [v for v in d2 if v["source"] == "claude"]
        self.assertEqual(claude_d2[0]["verdict"], "unverified", "backfill은 unverified여야")

    def test_gate_e_noq_has_structured_marker_and_int_axis(self):
        # 계약 락: gate-E NOQ는 구조화 마커 reason_code + 정수 axis를 가져야 validate가 인정한다.
        # 문자열 axis "3"과 지역화-only why_not_gap이 두 개의 거짓 RED 경로였다.
        f = {"id": "A3-9", "axis": "3", "source": "claude", "status": "refuted",
             "refutation": {"stage": "axis", "gate": "E", "reason": "scope-out"},
             "evidence": [{"file": "x", "line": 1, "quote": "q"}], "severity": "LOW"}
        r, data = run(
            workflow_return={"findings": [f], "d_verdicts": [], "oq_answers": [],
                             "new_open_questions": [], "axis_failures": [], "degraded_events": []},
            codex_side={"d_verdicts": [], "oq_answers": [], "new_open_questions": []},
            meta=BASE_META, assigned={"assigned_d": [], "assigned_oq": []})
        n = [q for q in data["new_open_questions"] if q["id"] == "A3-9"]
        self.assertTrue(n, "gate-E NOQ 미생성")
        self.assertEqual(n[0].get("reason_code"), "gate_e_scope_out", "구조화 마커(reason_code) 부재")
        self.assertIsInstance(n[0].get("axis"), int, "axis가 정수로 강제돼야 (validate isinstance int 요건)")


class TestCodexSideIngestionGate(unittest.TestCase):
    """관문이 `findings`에만 걸려 있었다. d_verdicts·oq_answers·new_open_questions는
    정규화 없이 통과해 malformed 입력에 AttributeError/TypeError/KeyError로 죽었다.

    degrade의 의미를 못 박는다: **항목별 삭제 + 손실 보고**. 전체 거부가 아니다 —
    한 컬렉션의 오류가 나머지 감사 결과를 통째로 버리게 하면 손실이 더 크다.
    """

    def _assemble(self, codex_side):
        import importlib.util
        from pathlib import Path
        p = Path(__file__).resolve().parents[1] / "scripts" / "assemble-audit-data.py"
        spec = importlib.util.spec_from_file_location("asm", p)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        wf = {"findings": [], "d_verdicts": [], "oq_answers": [],
              "new_open_questions": [], "axis_failures": []}
        meta = {"date": "2026-08-09", "target": "t",
                "codex": {"ran": True, "failed": False}}
        assigned = {"assigned_d": [], "assigned_oq": []}
        return mod.assemble(wf, codex_side, meta, assigned, Path("."), False)

    def test_non_dict_element_dropped_valid_sibling_kept(self):
        out = self._assemble({"d_verdicts": [{"id": "D1", "verdict": "confirmed"},
                                             "쓰레기", 42]})
        ids = [v["id"] for v in out["d_verdicts"]]
        self.assertEqual(ids, ["D1"], "유효한 형제는 보존해야 한다")
        self.assertEqual(out["meta"]["codex"]["dropped"][0]["collection"], "d_verdicts")
        self.assertEqual(out["meta"]["codex"]["dropped"][0]["count"], 2)

    def test_element_without_id_is_dropped(self):
        out = self._assemble({"oq_answers": [{"answer": "a"}, {"id": "", "answer": "b"},
                                             {"id": "OQ1", "answer": "c"}]})
        self.assertEqual([v["id"] for v in out["oq_answers"]], ["OQ1"])
        self.assertTrue(out["meta"]["codex"]["dropped"])

    def test_non_list_collection_degrades_to_empty_not_total_reject(self):
        out = self._assemble({"new_open_questions": {"id": "NOQ1"},
                              "d_verdicts": [{"id": "D1", "verdict": "confirmed"}]})
        self.assertEqual(out["new_open_questions"], [])
        self.assertEqual([v["id"] for v in out["d_verdicts"]], ["D1"],
                         "한 컬렉션의 오류가 나머지를 버리게 하면 안 된다")
        reasons = [d["reason"] for d in out["meta"]["codex"]["dropped"]]
        self.assertIn("not_a_list", reasons)

    def test_malformed_input_never_raises(self):
        for bad in ({"d_verdicts": "문자열"}, {"oq_answers": [None]},
                    {"new_open_questions": [[]]}, {"d_verdicts": [{"id": 3}]}):
            try:
                self._assemble(bad)
            except Exception as e:                       # noqa: BLE001
                self.fail(f"{bad} 에서 예외: {type(e).__name__}: {e}")

    def test_clean_input_leaves_no_dropped_key(self):
        out = self._assemble({"d_verdicts": [{"id": "D1", "verdict": "confirmed"}]})
        self.assertNotIn("dropped", out["meta"]["codex"],
                         "정상 입력에 손실 보고가 붙으면 배너가 상시 켜진다")


if __name__ == "__main__":
    unittest.main()
