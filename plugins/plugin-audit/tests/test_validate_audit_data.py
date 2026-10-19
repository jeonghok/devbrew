import copy, json, shutil, subprocess, sys, tempfile, unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"   # plugins/plugin-audit/scripts
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
                                "evidence": [{"file": "x", "line": 1, "quote": "q"}], "severity": "SUGGESTION"}],
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

    def test_refutation_null_is_clean_red_not_crash(self):  # C (qg 2026-07-20 round-2 + codex re-verify)
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

    def test_axes_must_be_valid_subset(self):
        for bad in ([], [0], [7], [1, 1], ["1"], [True], "16", None):
            d_ = copy.deepcopy(VALID); d_["meta"]["axes"] = bad
            rc, err = run_validate(d_)
            self.assertEqual(rc, 1, f"meta.axes={bad!r} 가 통과했다")
            self.assertIn("meta.axes 가 잘못됐다", err)
        for good in ([1, 6], [1, 2, 3, 4, 5, 6], [3]):
            d_ = copy.deepcopy(VALID); d_["meta"]["axes"] = good
            rc, err = run_validate(d_)
            self.assertEqual(rc, 0, err)
        rc, err = run_validate(copy.deepcopy(VALID))   # 키 없음
        self.assertEqual(rc, 0, err)

    def test_missing_claude_source_verdict_is_red(self):  # SF2 (qg 2026-07-20 round-2)
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

def run_validate_artifacts(data, report_text="# report\n", extra=()):
    """빈 tempdir에 report 와 data 만 두고 --artifacts 로 실행 — README · CLAUDE.md 는 없다."""
    with tempfile.TemporaryDirectory() as t:
        root = Path(t)
        report_path = root / "report.md"
        report_path.write_text(report_text, encoding="utf-8")
        j = root / "audit-data.json"
        j.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
        cmd = [sys.executable, str(SCRIPT), "--artifacts", str(j), "--report", str(report_path), *extra]
        r = subprocess.run(cmd, capture_output=True, text=True, cwd=str(root))
        return r.returncode, r.stderr


class TestArtifacts(unittest.TestCase):
    def test_artifacts_valid_is_green_without_readme_or_claude_md(self):
        rc, err = run_validate_artifacts(copy.deepcopy(VALID))
        self.assertEqual(rc, 0, err)

    def test_repo_root_option_removed(self):
        rc, err = run_validate_artifacts(copy.deepcopy(VALID), extra=("--repo-root", "."))
        self.assertEqual(rc, 2)
        self.assertIn("unrecognized arguments: --repo-root", err)

    def test_artifacts_degraded_without_banner_is_red(self):
        bad = copy.deepcopy(VALID)
        bad["degraded"] = [{"axis": 3, "reason": "권한 부족"}]
        rc, err = run_validate_artifacts(
            bad, report_text="# report\n\nNo mention of the issue anywhere near the top.\n")
        self.assertEqual(rc, 1, "degraded 비었지 않은데 배너 없음이 통과했다 (AC-3)")

    def test_artifacts_degraded_with_banner_is_green(self):
        ok = copy.deepcopy(VALID)
        ok["degraded"] = [{"axis": 3, "reason": "권한 부족"}]
        rc, err = run_validate_artifacts(ok, report_text="# report\n\n⚠ degraded: axis 3 권한 부족\n")
        self.assertEqual(rc, 0, err)


class TestB7NarrowedToRanAndNotFailed(unittest.TestCase):
    """B7은 `codex.ran is True`이면 codex-source D/OQ 판정을 강제했다. '실행-실패'
    상태는 ran=true인데 판정이 없으므로 **거짓 RED**가 났다. 조건을
    `ran == true AND failed == false`로 좁힌다.

    `failed` 키 부재는 fail-closed로 둔다 — 기존 데이터는 실행-성공을 뜻하므로
    B7이 그대로 걸려야 한다.
    """

    def _errs(self, codex_meta, d_verdicts):
        import importlib.util
        from pathlib import Path
        p = Path(__file__).resolve().parents[1] / "scripts" / "validate-audit-data.py"
        spec = importlib.util.spec_from_file_location("val", p)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        data = {"meta": {"codex": codex_meta, "assigned_d": ["D1"], "assigned_oq": []},
                "findings": [], "d_verdicts": d_verdicts, "oq_answers": [],
                "new_open_questions": [], "degraded": [], "axis_failures": []}
        return [e for e in mod.validate_data(data) if "B7" in e]

    def test_run_failed_does_not_raise_false_b7(self):
        errs = self._errs({"ran": True, "failed": True},
                          [{"id": "D1", "verdict": "confirmed", "source": "claude"}])
        self.assertEqual(errs, [], "실행-실패 상태에 B7 거짓 RED가 나면 안 된다")

    def test_run_success_without_codex_verdict_still_raises_b7(self):
        errs = self._errs({"ran": True, "failed": False},
                          [{"id": "D1", "verdict": "confirmed", "source": "claude"}])
        self.assertTrue(errs, "실행-성공인데 codex 판정이 없으면 B7이 잡아야 한다")

    def test_failed_key_absent_is_fail_closed(self):
        errs = self._errs({"ran": True},
                          [{"id": "D1", "verdict": "confirmed", "source": "claude"}])
        self.assertTrue(errs, "failed 부재는 실행-성공으로 읽어 B7을 유지한다")

    def test_not_run_does_not_raise_b7(self):
        errs = self._errs({"ran": False, "failed": False},
                          [{"id": "D1", "verdict": "confirmed", "source": "claude"}])
        self.assertEqual(errs, [])



def _drop_codex(data, id_):
    data["d_verdicts"] = [x for x in data["d_verdicts"] if not (x["id"] == id_ and x["source"] == "codex")]
    return data


def _mark_backfilled(data, id_):
    # 고르지 않은 축의 id 는 claude 판정이 assemble 의 빈칸 채움뿐이다.
    for x in data["d_verdicts"]:
        if x["id"] == id_ and x["source"] == "claude":
            x.update(verdict="unverified", backfilled=True,
                     reason="이번 감사에서 고르지 않은 축이라 빈칸을 채웠다(backfilled — 검증 안 됨)")
    return data


class TestChosenAxes(unittest.TestCase):
    """고른 축만 돈 감사 — codex 도 고른 축만 감사한다(SKILL pre-1)."""

    def test_b7_skips_ids_on_unchosen_axes(self):
        d_ = _mark_backfilled(_drop_codex(copy.deepcopy(VALID), "D4"), "D4")
        d_["meta"].update(axes=[1], assigned_axis={"D1": 1, "D4": 4})
        rc, err = run_validate(d_)
        self.assertEqual(rc, 0, err)

    def test_b7_still_reds_chosen_or_unknown_axis(self):
        # 양성 짝 — 고른 축의 id, 축을 모르는 id, 고른 축 정보가 없는 데이터는 여전히 RED.
        cases = (
            ("D1", dict(axes=[1], assigned_axis={"D1": 1, "D4": 4})),
            ("D4", dict(axes=[1], assigned_axis={"D1": 1})),
            ("D4", dict(assigned_axis={"D4": 4})),
            ("D4", dict(axes=[1], assigned_axis={"D4": True})),
        )
        for id_, extra in cases:
            d_ = _mark_backfilled(_drop_codex(copy.deepcopy(VALID), id_), "D4")
            d_["meta"].update(extra)
            rc, err = run_validate(d_)
            self.assertEqual(rc, 1, f"{id_} {extra}")
            self.assertIn(f"{id_}의 codex 판정 없음", err)

    def test_audited_id_needs_codex_even_if_map_says_unchosen(self):
        # 손으로 옮긴 축 지도가 틀려도(D1 은 고른 축 1 인데 4 로 적힘) D1 에는 실제 claude 판정이 있다 —
        # 돈 축이 감사했다는 뜻이므로 codex 판정 요구를 끄지 않는다 (B7 fail-open 봉쇄).
        d_ = _drop_codex(copy.deepcopy(VALID), "D1")
        d_["meta"].update(axes=[1], assigned_axis={"D1": 4})
        rc, err = run_validate(d_)
        self.assertEqual(rc, 1)
        self.assertIn("D1의 codex 판정 없음", err)
        # 양성 짝 — 같은 지도에서 claude 판정이 빈칸 채움뿐이면 통과한다.
        d_ = _mark_backfilled(_drop_codex(copy.deepcopy(VALID), "D1"), "D1")
        d_["meta"].update(axes=[1], assigned_axis={"D1": 4})
        rc, err = run_validate(d_)
        self.assertEqual(rc, 0, err)

    def test_b7_message_points_at_the_fix(self):
        d_ = _drop_codex(copy.deepcopy(VALID), "D1")
        rc, err = run_validate(d_)
        self.assertEqual(rc, 1)
        line = [l for l in err.splitlines() if "D1의 codex 판정 없음" in l][0]
        self.assertIn("assigned_axis", line)
        self.assertIn("axis_of", line)
        self.assertIn("assemble 을 다시 돌려라", line)
        self.assertIn("$RUN_DIR", line)

    def test_axes_and_axes_run_must_match(self):
        d_ = copy.deepcopy(VALID); d_["meta"].update(axes=[1, 6], axes_run=[1, 2])
        rc, err = run_validate(d_)
        self.assertEqual(rc, 1)
        self.assertIn("axes_run", err)
        for good in (dict(axes=[6, 1], axes_run=[1, 6]), dict(axes_run=[1, 6]), dict(axes=[1, 6])):
            d_ = copy.deepcopy(VALID); d_["meta"].update(good)
            rc, err = run_validate(d_)
            self.assertEqual(rc, 0, f"{good}: {err}")
        d_ = copy.deepcopy(VALID); d_["meta"].update(axes_run=[0])
        rc, err = run_validate(d_)
        self.assertEqual(rc, 1)
        self.assertIn("meta.axes_run 가 잘못됐다", err)

    def test_axes_and_consent_axes_must_match(self):
        d_ = copy.deepcopy(VALID); d_["meta"]["axes"] = [1, 6]
        d_["meta"]["consent"] = dict(d_["meta"]["consent"], axes=[1, 2])
        rc, err = run_validate(d_)
        self.assertEqual(rc, 1)
        self.assertIn("동의에서 고른 축", err)
        # positive pair — same set in any order, or only one of the two present
        for meta_axes, consent_axes in (([6, 1], [1, 6]), ([1, 6], None), (None, [1, 6])):
            d_ = copy.deepcopy(VALID)
            if meta_axes is not None:
                d_["meta"]["axes"] = meta_axes
            if consent_axes is not None:
                d_["meta"]["consent"] = dict(d_["meta"]["consent"], axes=consent_axes)
            rc, err = run_validate(d_)
            self.assertEqual(rc, 0, f"{meta_axes} {consent_axes}: {err}")

    def _assemble_then_validate(self, codex_d, axis_of=None, wf_axis=None, wf_d=None):
        assemble = SCRIPTS_DIR / "assemble-audit-data.py"
        with tempfile.TemporaryDirectory() as t:
            t = Path(t)
            wf = {"findings": [], "d_verdicts": [d("D1", "claude")], "oq_answers": [],
                  "new_open_questions": [], "axis_failures": [], "degraded_events": [], "axes_run": [1]}
            if wf_axis is not None:
                wf["assigned_axis"] = wf_axis
            if wf_d is not None:
                wf["d_verdicts"] = wf_d
            codex = {"d_verdicts": codex_d, "oq_answers": [], "new_open_questions": []}
            meta = {"date": "2026-01-01", "fanout_declared": "규모 문장",
                    "consent": {"approved": True, "at": "t", "fanout": "규모 문장", "axes": [1]},
                    "codex": {"ran": True, "version": "1.0"}, "target": "myplugin", "seed_provided": True,
                    "axes": [1]}
            assigned = {"assigned_d": ["D1", "D4"], "assigned_oq": [],
                        "axis_of": axis_of if axis_of is not None else {"D1": 1, "D4": 4}}
            paths = {}
            for name, obj in (("wf", wf), ("codex", codex), ("meta", meta), ("assigned", assigned)):
                p = t / f"{name}.json"
                p.write_text(json.dumps(obj, ensure_ascii=False), encoding="utf-8")
                paths[name] = p
            out = t / "data.json"
            subprocess.run([sys.executable, str(assemble),
                            "--workflow-return", str(paths["wf"]), "--codex-side", str(paths["codex"]),
                            "--meta", str(paths["meta"]), "--assigned", str(paths["assigned"]),
                            "--repo-root", str(t), "--no-grounding", "--out", str(out)],
                           check=True, capture_output=True, text=True)
            data = json.loads(out.read_text(encoding="utf-8"))
        return data, run_validate(data)

    def test_end_to_end_subset_axes_with_codex_is_green(self):
        data, (rc, err) = self._assemble_then_validate([{"id": "D1", "verdict": "confirmed", "reason": "r"}])
        self.assertEqual(rc, 0, err)
        d4 = [x for x in data["d_verdicts"] if x["id"] == "D4"]
        self.assertEqual([x["source"] for x in d4], ["claude"])
        self.assertEqual(d4[0]["verdict"], "unverified")

    def test_end_to_end_mislabelled_axis_of_still_reds(self):
        # 변이 — Workflow 지도가 없고 axis_of 가 D1(고른 축 1)을 4 로 잘못 적었다. D1 은 실제 claude 판정이 있다.
        data, (rc, err) = self._assemble_then_validate([], axis_of={"D1": 4, "D4": 4})
        self.assertEqual(data["meta"]["assigned_axis_source"], "assigned.json")
        self.assertEqual(rc, 1)
        self.assertIn("D1의 codex 판정 없음", err)

    def test_end_to_end_incoming_backfilled_marker_is_ignored(self):
        # 표식은 assemble 만 단다 — Workflow 가 보낸 backfilled 는 지우고 판단한다.
        d1 = dict(d("D1", "claude"), backfilled=True)
        data, (rc, err) = self._assemble_then_validate([], wf_axis={"D1": 4, "D4": 4}, wf_d=[d1])
        self.assertNotIn("backfilled", [x for x in data["d_verdicts"] if x["id"] == "D1"][0])
        self.assertEqual(rc, 1)
        self.assertIn("D1의 codex 판정 없음", err)

    def test_end_to_end_workflow_map_wins(self):
        data, (rc, err) = self._assemble_then_validate(
            [{"id": "D1", "verdict": "confirmed", "reason": "r"}],
            axis_of={"D1": 4, "D4": 1}, wf_axis={"D1": 1, "D4": 4})
        self.assertEqual(data["meta"]["assigned_axis"], {"D1": 1, "D4": 4})
        self.assertEqual(data["meta"]["assigned_axis_source"], "workflow")
        self.assertEqual(rc, 0, err)

    @unittest.skipUnless(shutil.which("node"), "node 없음 — Workflow 를 돌릴 수 없다")
    def test_end_to_end_real_workflow_drops_cross_axis_verdict(self):
        # 실제 Workflow 스크립트를 돌린다 — 자기 id 가 없는 축 3 이 고르지 않은 축 4 의 D4 를 판정해도
        # Workflow 가 그 판정을 빼고 공시하므로, 고른 축 [1,3] + codex 실행에서 B7 이 GREEN 이다.
        harness = (Path(__file__).resolve().parent / "_wf_harness.mjs").as_uri()
        driver = (
            "import { runWorkflow, DEFAULT_PACK } from " + json.dumps(harness) + "\n"
            "const pack = { ...DEFAULT_PACK, candidate_clues: [\n"
            "  { id: 'D1', axis: 1, claim: 'c', file: 'a', line: 1 },\n"
            "  { id: 'D4', axis: 4, claim: 'c', file: 'a', line: 4 }] }\n"
            "const v = (id) => ({ id, verdict: 'confirmed', reason: 'r' })\n"
            "const stub = async (p, o) => {\n"
            "  if (o.phase !== '감사') return { verdicts: [] }\n"
            "  const dv = o.label.startsWith('축1 ') ? [v('D1')] : o.label.startsWith('축3 ') ? [v('D4')] : []\n"
            "  return { findings: [], d_verdicts: dv, oq_answers: [], new_open_questions: [] }\n"
            "}\n"
            "const { result } = await runWorkflow('plugins/plugin-audit/scripts/audit-workflow.js', {\n"
            "  args: { target: 'sample', evidencePack: pack, codexFindings: [], axes: [1, 3] }, stubAgent: stub })\n"
            "process.stdout.write(JSON.stringify(result))\n"
        )
        r = subprocess.run(["node", "--input-type=module", "-e", driver],
                           capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(r.returncode, 0, r.stderr)
        wf = json.loads(r.stdout)
        self.assertEqual([x["id"] for x in wf["d_verdicts"]], ["D1"])
        self.assertTrue(any("D4" in e["what"] for e in wf["degraded_events"]), wf["degraded_events"])
        assemble = SCRIPTS_DIR / "assemble-audit-data.py"
        with tempfile.TemporaryDirectory() as t:
            t = Path(t)
            codex = {"d_verdicts": [{"id": "D1", "verdict": "confirmed", "reason": "r"}],
                     "oq_answers": [], "new_open_questions": []}
            meta = {"date": "2026-01-01", "fanout_declared": "규모 문장",
                    "consent": {"approved": True, "at": "t", "fanout": "규모 문장", "axes": [1, 3]},
                    "codex": {"ran": True, "version": "1.0"}, "target": "myplugin", "seed_provided": True,
                    "axes": [1, 3]}
            assigned = {"assigned_d": ["D1", "D4"], "assigned_oq": []}
            paths = {}
            for name, obj in (("wf", wf), ("codex", codex), ("meta", meta), ("assigned", assigned)):
                p = t / f"{name}.json"
                p.write_text(json.dumps(obj, ensure_ascii=False), encoding="utf-8")
                paths[name] = p
            out = t / "data.json"
            subprocess.run([sys.executable, str(assemble),
                            "--workflow-return", str(paths["wf"]), "--codex-side", str(paths["codex"]),
                            "--meta", str(paths["meta"]), "--assigned", str(paths["assigned"]),
                            "--repo-root", str(t), "--no-grounding", "--out", str(out)],
                           check=True, capture_output=True, text=True)
            data = json.loads(out.read_text(encoding="utf-8"))
        self.assertEqual(data["meta"]["assigned_axis_source"], "workflow")
        d4 = [x for x in data["d_verdicts"] if x["id"] == "D4"]
        self.assertEqual([(x["source"], x["verdict"], x.get("backfilled")) for x in d4],
                         [("claude", "unverified", True)])
        self.assertIn("D4", json.dumps(data["degraded"], ensure_ascii=False))
        rc, err = run_validate(data)
        self.assertEqual(rc, 0, err)

    def test_end_to_end_chosen_axis_missing_codex_still_reds(self):
        data, (rc, err) = self._assemble_then_validate([])
        self.assertEqual(rc, 1)
        self.assertIn("D1의 codex 판정 없음", err)
        self.assertNotIn("D4의 codex 판정 없음", err)


if __name__ == "__main__":
    unittest.main()
