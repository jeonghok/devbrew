import copy, json, subprocess, sys, tempfile, unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1]   # plugins/plugin-audit/scripts
SCRIPT = SCRIPTS_DIR / "validate-audit-data.py"

# 최소 유효 audit-data.json (§9.1). Claude+codex가 D1–D5·OQ1–OQ6를 각각 판정.
# assigned_d/assigned_oq/consent.fanout은 이제 데이터가 declare한다 (상수 아님).
def d(id_, src): return {"id": id_, "source": src, "verdict": "unverified", "reason": "r", "why_unverifiable": "w"}
def oq(id_, src): return {"id": id_, "source": src, "reason": "r", "answer": "a"}

VALID = {
    "meta": {"date": "2026-07-13", "fanout_declared": 30,
             "assigned_d": [f"D{i}" for i in range(1, 6)],
             "assigned_oq": [f"OQ{i}" for i in range(1, 7)],
             "consent": {"approved": True, "at": "2026-07-13T00:00:00Z", "fanout": 30},
             "codex": {"ran": True, "version": "0.142.5"}},
    "findings": [],
    "d_verdicts": [d(f"D{i}", s) for i in range(1, 6) for s in ("claude", "codex")],
    "oq_answers": [oq(f"OQ{i}", s) for i in range(1, 7) for s in ("claude", "codex")],
    "new_open_questions": [],
    "axis_failures": [],
    "degraded": [],
}


def run_validate(data, mode="--data"):
    with tempfile.TemporaryDirectory() as t:
        j = Path(t) / "audit-data.json"
        j.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
        r = subprocess.run([sys.executable, str(SCRIPT), mode, str(j)],
                           capture_output=True, text=True, cwd=str(SCRIPTS_DIR))
        return r.returncode, r.stderr


class TestData(unittest.TestCase):
    def test_valid_is_green(self):
        rc, err = run_validate(VALID)
        self.assertEqual(rc, 0, err)

    def test_missing_assigned_d_is_red(self):  # row 16 이빨
        bad = copy.deepcopy(VALID)
        bad["d_verdicts"] = [x for x in bad["d_verdicts"] if x["id"] != "D2"]
        rc, err = run_validate(bad)
        self.assertEqual(rc, 1, "배정 D2 누락이 완결성 검사를 통과했다 (backfill 미강제)")

    def test_missing_assigned_d_is_red_isolated_from_b7(self):  # row 16 이빨, B7과 분리 증명
        # VALID는 codex.ran=True라서 D2(양쪽 source) 제거가 B7(코덱스 병합) 검사와도 우연히
        # 겹쳐 잡힌다. codex.ran=False로 B7을 끄면 완결성 루프 단독의 이빨을 분리 증명한다.
        bad = copy.deepcopy(VALID)
        bad["meta"]["codex"]["ran"] = False
        bad["d_verdicts"] = [x for x in bad["d_verdicts"] if x["id"] != "D2"]
        rc, err = run_validate(bad)
        self.assertEqual(rc, 1, "codex.ran=False에서도 배정 D2 누락이 완결성 검사 단독으로 안 잡혔다")

    def test_wrong_fanout_is_red(self):
        # fanout_declared는 이제 상수 30이 아니라 meta.consent.fanout과의 내부 정합으로 검사한다.
        bad = copy.deepcopy(VALID)
        bad["meta"]["fanout_declared"] = 25  # consent.fanout(30)과 불일치
        rc, _ = run_validate(bad); self.assertEqual(rc, 1)

    def test_fanout_declared_mismatch_is_red(self):
        # fanout_declared==30이지만 consent.fanout=25로 불일치시킨다. 구 리터럴(!= 30)
        # 아래서는 30==30이라 통과(GREEN)해버리므로, 이 케이스는 신구 형태를 판별한다.
        bad = copy.deepcopy(VALID)
        bad["meta"]["fanout_declared"] = 30
        bad["meta"]["consent"]["fanout"] = 25
        rc, err = run_validate(bad)
        self.assertEqual(rc, 1, f"fanout_declared(30) != consent.fanout(25) should RED:\n{err}")

    def test_fanout_match_nonzero_is_green(self):
        # 30이 아닌 값(42)으로 둘을 일치시킨다. 구 리터럴(!= 30) 아래서는 42 != 30이라
        # 거짓 RED가 나므로, 이 케이스는 "상수 30에 여전히 묶여있는" 회귀를 잡는다.
        ok = copy.deepcopy(VALID)
        ok["meta"]["fanout_declared"] = 42
        ok["meta"]["consent"]["fanout"] = 42
        rc, err = run_validate(ok)
        self.assertEqual(rc, 0, f"fanout_declared(42) == consent.fanout(42) should GREEN:\n{err}")

    def test_assigned_sets_are_data_driven(self):  # 하드코딩 D1–D5/OQ1–OQ6 제거 증명
        ok = copy.deepcopy(VALID)
        ok["meta"]["assigned_d"] = ["D1", "D2"]
        ok["meta"]["assigned_oq"] = ["OQ1", "OQ2"]
        # codex 병합(B7) 검사도 배정 세트만 봐야 하므로 D1/D2·OQ1/OQ2만 남기고 나머지 제거
        ok["d_verdicts"] = [x for x in ok["d_verdicts"] if x["id"] in ("D1", "D2")]
        ok["oq_answers"] = [x for x in ok["oq_answers"] if x["id"] in ("OQ1", "OQ2")]
        rc, err = run_validate(ok)
        self.assertEqual(rc, 0, f"assigned_d=[D1,D2]만 선언했는데 D3–D5 부재가 거짓 RED:\n{err}")

    def test_consent_mismatch_is_red(self):
        bad = copy.deepcopy(VALID); bad["meta"]["consent"]["approved"] = False
        rc, _ = run_validate(bad); self.assertEqual(rc, 1)

    def test_pending_steelman_is_red(self):
        bad = copy.deepcopy(VALID)
        bad["findings"] = [{"id": "A2-1", "source": "claude", "axis": 2, "status": "reported",
                            "steelman_condition": "pending", "evidence": [{"file": "f", "line": 1, "quote": "q"}]}]
        rc, err = run_validate(bad)
        self.assertEqual(rc, 1, "steelman_condition: pending 잔존이 통과했다")

    def test_codex_ran_but_no_codex_verdict_is_red(self):  # B7
        bad = copy.deepcopy(VALID)
        bad["d_verdicts"] = [x for x in bad["d_verdicts"] if x["source"] != "codex"]
        rc, err = run_validate(bad)
        self.assertEqual(rc, 1, "codex.ran=true인데 codex 판정 없음이 통과 (LD4 참칭)")

    def test_gate_e_refuted_without_noq_is_red(self):  # row 8 이빨
        bad = copy.deepcopy(VALID)
        bad["findings"] = [{"id": "A1-1", "source": "claude", "axis": 1, "status": "refuted",
                            "refutation": {"stage": "axis", "gate": "E", "reason": "범위 밖"},
                            "evidence": [{"file": "f", "line": 1, "quote": "q"}]}]
        # scope-out NOQ 없음 → RED
        rc, err = run_validate(bad)
        self.assertEqual(rc, 1, "gate-E refuted가 NOQ로 회수되지 않았는데 통과 (조용한 증발)")

    def test_gate_e_refuted_with_noq_is_green(self):
        # NOQ id는 producer(assemble)가 refuted finding의 **같은 id**로 만든다 — identity 기반
        # 검증에 맞게 NOQ.id == finding.id로 둔다. reason_code 구조화 마커로 인식.
        ok = copy.deepcopy(VALID)
        ok["findings"] = [{"id": "A1-1", "source": "claude", "axis": 1, "status": "refuted",
                           "refutation": {"stage": "axis", "gate": "E", "reason": "범위 밖"},
                           "evidence": [{"file": "f", "line": 1, "quote": "q"}]}]
        ok["new_open_questions"] = [{"id": "A1-1", "source": "claude", "axis": 1,
                                     "observation": "A1-1", "why_not_gap": "scope-out (gate E) — 범위 밖",
                                     "reason_code": "gate_e_scope_out", "evidence": []}]
        rc, err = run_validate(ok)
        self.assertEqual(rc, 0, err)

    def test_gate_e_duplicate_noq_masks_missing_is_red(self):
        # codex fix-review: count-기반 검증이면 무관/중복 scope-out NOQ가 특정 refuted finding의
        # 누락 NOQ를 가려 거짓 GREEN이 된다. gate-E finding 2개(A1-1,A1-2) 중 A1-1의 NOQ만
        # 2개(중복) 두면 count==2로 gate_e와 같지만 A1-2의 NOQ는 부재 — identity 기반이면 RED.
        bad = copy.deepcopy(VALID)
        bad["findings"] = [
            {"id": "A1-1", "source": "claude", "axis": 1, "status": "refuted",
             "refutation": {"stage": "axis", "gate": "E", "reason": "x"},
             "evidence": [{"file": "f", "line": 1, "quote": "q"}]},
            {"id": "A1-2", "source": "claude", "axis": 1, "status": "refuted",
             "refutation": {"stage": "axis", "gate": "E", "reason": "x"},
             "evidence": [{"file": "f", "line": 1, "quote": "q"}]},
        ]
        bad["new_open_questions"] = [
            {"id": "A1-1", "source": "claude", "axis": 1, "observation": "o",
             "why_not_gap": "scope-out (gate E)", "reason_code": "gate_e_scope_out", "evidence": []},
            {"id": "A1-1", "source": "claude", "axis": 1, "observation": "o2",
             "why_not_gap": "scope-out (gate E)", "reason_code": "gate_e_scope_out", "evidence": []},
        ]
        rc, err = run_validate(bad)
        self.assertEqual(rc, 1, f"중복 NOQ가 A1-2의 누락 NOQ를 가려 거짓 GREEN:\n{err}")

    def test_gate_e_real_assemble_output_is_green(self):
        # HAND-SHAPE 함정 봉쇄: 위 test_gate_e_refuted_with_noq_is_green은 why_not_gap을 손으로
        # "LD5 범위 밖"이라 써서 producer(assemble-audit-data.py)가 실제로 내는
        # "scope-out (gate E)"를 한 번도 안 태웠다. 여기선 gate-E refuted finding을 **실제
        # assemble에 태워** 그 산출 NOQ를 validate에 먹인다 — fix 전에는 assemble이 "범위 밖"
        # 없는 문자열을 내고 validate가 그것만 인정해 거짓 RED(조용한 증발 오탐).
        assemble = SCRIPTS_DIR / "assemble-audit-data.py"
        with tempfile.TemporaryDirectory() as t:
            t = Path(t)
            wf = {"findings": [{"id": "A1-9", "axis": 1, "source": "claude", "status": "refuted",
                                "refutation": {"stage": "axis", "gate": "E", "reason": "scope-out"},
                                "evidence": [{"file": "x", "line": 1, "quote": "q"}], "severity": "LOW"}],
                  "d_verdicts": [], "oq_answers": [], "new_open_questions": [],
                  "axis_failures": [], "degraded_events": []}
            codex = {"d_verdicts": [], "oq_answers": [], "new_open_questions": []}
            meta = {"date": "2026-01-01", "fanout_declared": 0,
                    "consent": {"approved": True, "at": "t", "fanout": 0},
                    "codex": {"ran": False}, "target": "myplugin", "seed_provided": False}
            assigned = {"assigned_d": [], "assigned_oq": []}
            paths = {}
            for name, obj in (("wf", wf), ("codex", codex), ("meta", meta), ("assigned", assigned)):
                p = t / f"{name}.json"; p.write_text(json.dumps(obj), encoding="utf-8"); paths[name] = p
            out = t / "data.json"
            subprocess.run([sys.executable, str(assemble),
                            "--workflow-return", str(paths["wf"]), "--codex-side", str(paths["codex"]),
                            "--meta", str(paths["meta"]), "--assigned", str(paths["assigned"]),
                            "--repo-root", str(t), "--no-grounding", "--out", str(out)],
                           check=True, capture_output=True, text=True)
            data = json.loads(out.read_text(encoding="utf-8"))
            rc, err = run_validate(data)
            self.assertEqual(rc, 0, f"실제 assemble gate-E 산출이 validate에서 거짓 RED:\n{err}")

    def test_noq_missing_why_not_gap_is_red(self):
        bad = copy.deepcopy(VALID)
        bad["new_open_questions"] = [{"id": "NOQ-1", "source": "claude", "axis": 1,
                                      "observation": "x", "evidence": []}]  # why_not_gap 없음
        rc, _ = run_validate(bad); self.assertEqual(rc, 1)

    def test_cross_source_dedup_is_red(self):  # cross-model 증발 (LD4)
        bad = copy.deepcopy(VALID)
        bad["findings"] = [
            {"id": "A1-1", "source": "claude", "axis": 1, "status": "refuted",
             "refutation": {"stage": "dedup", "target_id": "CX-1", "reason": "absorbed"},
             "evidence": [{"file": "f", "line": 1, "quote": "q"}]},
            {"id": "CX-1", "source": "codex", "axis": 1, "status": "reported",
             "evidence": [{"file": "f", "line": 1, "quote": "q"}]},
        ]
        rc, err = run_validate(bad)
        self.assertEqual(rc, 1, f"cross-source dedup should RED:\n{err}")

    def test_invalid_oq_ref_is_red(self):
        bad = copy.deepcopy(VALID)
        bad["findings"] = [{"id": "A1-1", "source": "claude", "axis": 1, "status": "reported",
                            "oq_ref": "OQ9", "evidence": [{"file": "f", "line": 1, "quote": "q"}]}]
        rc, err = run_validate(bad)
        self.assertEqual(rc, 1, f"oq_ref=OQ9 (not OQ1-6) should RED:\n{err}")

    def test_invalid_d_verdict_is_red(self):
        bad = copy.deepcopy(VALID)
        bad["d_verdicts"][0]["verdict"] = "bogus"
        rc, err = run_validate(bad)
        self.assertEqual(rc, 1, f"d_verdict verdict=bogus should RED:\n{err}")

    def test_noq_missing_source_is_red(self):
        bad = copy.deepcopy(VALID)
        bad["new_open_questions"] = [{"id": "NOQ-1", "axis": 1, "observation": "x",
                                      "why_not_gap": "y", "evidence": []}]
        rc, err = run_validate(bad)
        self.assertEqual(rc, 1, f"NOQ missing source should RED:\n{err}")

    def test_noq_bad_axis_is_red(self):
        bad = copy.deepcopy(VALID)
        bad["new_open_questions"] = [{"id": "NOQ-1", "source": "claude", "axis": 9,
                                      "observation": "x", "why_not_gap": "y", "evidence": []}]
        rc, err = run_validate(bad)
        self.assertEqual(rc, 1, f"NOQ axis=9 (not 1-6) should RED:\n{err}")

    def test_noq_bool_axis_is_red(self):
        # codex final-review: bool은 int의 subclass라 axis=True가 isinstance(int)+1<=True<=6을
        # 통과해 axis 1로 새어든다. type(ax) is int로 bool을 거부해야 한다.
        bad = copy.deepcopy(VALID)
        bad["new_open_questions"] = [{"id": "NOQ-1", "source": "claude", "axis": True,
                                      "observation": "x", "why_not_gap": "y", "evidence": []}]
        rc, err = run_validate(bad)
        self.assertEqual(rc, 1, f"axis=True(bool)가 axis 1로 통과 (bool is int subclass):\n{err}")

    def test_refutation_null_is_clean_red_not_crash(self):  # C (/qg 2026-07-20 round-2 + codex re-verify)
        # code-reviewer + silent-failure-hunter: `f.get("refutation", {}).get("gate")`는 키 *부재*시만 {}.
        # `"refutation": null`이면 None.get()가 AttributeError → traceback(깨끗한 RED가 아닌 크래시).
        # codex re-verify(R3): `or {}`조차 truthy non-dict(문자열·리스트)는 통과시켜 여전히 크래시.
        # 정상 refuted는 항상 {stage,gate,reason} dict이므로, 비-dict refutation은 malformed → validate가
        # 크래시가 아니라 **clean RED**로 잡아야 한다(§9.1 producer 회계). null·문자열·리스트 전부 검증.
        for bad_ref in (None, "gate E", ["E"], 5):
            data = copy.deepcopy(VALID)
            data["findings"] = [{"id": "A1-1", "source": "claude", "axis": 1, "status": "refuted",
                                 "refutation": bad_ref, "evidence": [{"file": "f", "line": 1, "quote": "q"}]}]
            rc, err = run_validate(data)
            self.assertNotIn("Traceback", err, f"refutation={bad_ref!r}이 크래시(traceback):\n{err}")
            self.assertNotIn("AttributeError", err, f"refutation={bad_ref!r}이 AttributeError:\n{err}")
            self.assertEqual(rc, 1, f"비-dict refutation({bad_ref!r})이 clean RED로 안 잡힘:\n{err}")
            self.assertIn("refutation", err, f"malformed refutation 사유가 stderr에 없음:\n{err}")

    def test_missing_claude_source_verdict_is_red(self):  # SF2 (/qg 2026-07-20 round-2)
        # silent-failure-hunter: 완결성(40-47)은 any-source 존재만, B7(53-59)은 codex-source 존재만
        # 강제한다. 대칭인 claude-source 존재 검사가 없어, backfill 회귀로 dead Claude 축이 codex 답변에
        # 가려져도 validate가 GREEN. D2의 claude 판정만 제거(codex는 유지) → fix 후 RED여야.
        bad = copy.deepcopy(VALID)
        bad["d_verdicts"] = [x for x in bad["d_verdicts"]
                             if not (x["id"] == "D2" and x["source"] == "claude")]
        rc, err = run_validate(bad)
        self.assertEqual(rc, 1, f"D2 claude-source 판정 부재(dead-axis masking, LD4)가 통과 (backstop 없음):\n{err}")

    def test_missing_claude_source_oq_is_red(self):  # SF2 대칭 (OQ)
        bad = copy.deepcopy(VALID)
        bad["oq_answers"] = [x for x in bad["oq_answers"]
                             if not (x["id"] == "OQ2" and x["source"] == "claude")]
        rc, err = run_validate(bad)
        self.assertEqual(rc, 1, f"OQ2 claude-source 답변 부재가 통과 (backstop 없음):\n{err}")


# --- --artifacts 모드: 실제 파일을 본다 (골든 픽스처는 실물을 안 본다) ---

def run_validate_artifacts(data, readme_text=None, claude_md_text=None, report_text="# report\n"):
    """repo_root 레이아웃(README/CLAUDE.md/report)을 tempdir에 짓고 --artifacts로 실행."""
    with tempfile.TemporaryDirectory() as t:
        root = Path(t)
        if readme_text is not None:
            audits = root / "docs" / "audits"; audits.mkdir(parents=True)
            (audits / "README.md").write_text(readme_text, encoding="utf-8")
        if claude_md_text is not None:
            (root / "CLAUDE.md").write_text(claude_md_text, encoding="utf-8")
        report_path = root / "report.md"
        report_path.write_text(report_text, encoding="utf-8")
        j = root / "audit-data.json"
        j.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
        cmd = [sys.executable, str(SCRIPT), "--artifacts", str(j),
               "--repo-root", str(root), "--report", str(report_path)]
        r = subprocess.run(cmd, capture_output=True, text=True, cwd=str(SCRIPTS_DIR))
        return r.returncode, r.stderr


class TestArtifacts(unittest.TestCase):
    def test_artifacts_valid_is_green(self):
        rc, err = run_validate_artifacts(
            copy.deepcopy(VALID),
            readme_text="See [report](report.md) for the audit.\n",
            claude_md_text="Audits live under docs/audits/.\n",
        )
        self.assertEqual(rc, 0, err)

    def test_artifacts_readme_missing_link_is_red(self):
        rc, err = run_validate_artifacts(
            copy.deepcopy(VALID),
            readme_text="Nothing to see here.\n",
            claude_md_text="Audits live under docs/audits/.\n",
        )
        self.assertEqual(rc, 1, "README가 리포트를 링크하지 않는데 통과했다")

    def test_artifacts_missing_readme_is_red(self):
        rc, err = run_validate_artifacts(
            copy.deepcopy(VALID),
            readme_text=None,  # docs/audits/README.md 자체가 없음
            claude_md_text="Audits live under docs/audits/.\n",
        )
        self.assertEqual(rc, 1, "docs/audits/README.md 부재가 통과했다")

    def test_artifacts_claude_md_missing_pointer_is_red(self):
        rc, err = run_validate_artifacts(
            copy.deepcopy(VALID),
            readme_text="See [report](report.md) for the audit.\n",
            claude_md_text="No pointer here.\n",
        )
        self.assertEqual(rc, 1, "CLAUDE.md에 docs/audits/ 포인터가 없는데 통과했다")

    def test_artifacts_degraded_without_banner_is_red(self):
        bad = copy.deepcopy(VALID)
        bad["degraded"] = [{"axis": 3, "reason": "권한 부족"}]
        rc, err = run_validate_artifacts(
            bad,
            readme_text="See [report](report.md) for the audit.\n",
            claude_md_text="Audits live under docs/audits/.\n",
            report_text="# report\n\nNo mention of the issue anywhere near the top.\n",
        )
        self.assertEqual(rc, 1, "degraded 비었지 않은데 배너 없음이 통과했다 (AC-3)")

    def test_artifacts_degraded_with_banner_is_green(self):
        ok = copy.deepcopy(VALID)
        ok["degraded"] = [{"axis": 3, "reason": "권한 부족"}]
        rc, err = run_validate_artifacts(
            ok,
            readme_text="See [report](report.md) for the audit.\n",
            claude_md_text="Audits live under docs/audits/.\n",
            report_text="# report\n\n⚠ degraded: axis 3 권한 부족\n",
        )
        self.assertEqual(rc, 0, err)


if __name__ == "__main__":
    unittest.main()
