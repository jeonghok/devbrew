import json, subprocess, sys, tempfile, unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts" / "render-audit-report.py"


def render(data):
    with tempfile.TemporaryDirectory() as t:
        j = Path(t) / "d.json"; out = Path(t) / "r.md"; readme = Path(t) / "README.md"
        j.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
        r = subprocess.run([sys.executable, str(SCRIPT), str(j), "--out", str(out), "--readme", str(readme)],
                           capture_output=True, text=True, cwd=str(REPO))
        md = out.read_text(encoding="utf-8") if out.is_file() else ""
        return r.returncode, md, r.stderr


def f(id_, sev, cost, axis=1, **kw):
    base = {"id": id_, "source": "claude", "axis": axis, "title": id_, "severity": sev,
            "fix_cost": cost, "status": "reported", "user_harm": "h", "recommendation": "r",
            "counter_argument": "c", "reference_gap": "none", "deep_verified": None,
            "evidence": [{"file": "f", "line": 1, "quote": "q"}]}
    base.update(kw); return base


META_OK = {"date": "2026-07-13", "fanout_declared": 30,
           "consent": {"approved": True, "at": "t"}, "codex": {"ran": True}}


class TestRender(unittest.TestCase):
    def test_sort_severity_then_cost(self):
        # CRITICAL<HIGH는 알파벳순으로도 우연히 맞다(C<H) — 실제 뒤집힘 창은 MEDIUM/LOW다
        # (알파벳순: LOW < MEDIUM, 그러나 서수는 MEDIUM(2) < LOW(3)). A1-4/A1-5로 그 창을 태운다.
        data = {"meta": META_OK, "findings": [f("A1-2", "HIGH", "L"), f("A1-1", "HIGH", "S"),
                f("A1-3", "CRITICAL", "M"), f("A1-5", "LOW", "S"), f("A1-4", "MEDIUM", "S")],
                "d_verdicts": [], "oq_answers": [], "new_open_questions": [], "axis_failures": [], "degraded": []}
        rc, md, err = render(data)
        self.assertEqual(rc, 0, err)
        # CRITICAL 먼저, 그 다음 HIGH 중 S(cost) 먼저
        order = [md.index("A1-3"), md.index("A1-1"), md.index("A1-2")]
        self.assertEqual(order, sorted(order), f"정렬 뒤집힘:\n{md}")
        self.assertLess(md.index("A1-4"), md.index("A1-5"),
                         "MEDIUM이 LOW보다 먼저여야 — 알파벳순 문자열 비교는 여기서 뒤집는다(L<M)")

    def test_prose_fix_cost_does_not_break_sort(self):
        # fix_cost에 산문이 섞여도(비교자가 NaN 안 나게) 정렬이 결정론이어야 (§9.2)
        # 세 번째 항목(L, exact)이 필수: S vs prose-M만으로는 whole-string lookup 뮤테이션
        # (prose → naive=99) 하에서도 S(naive=0)가 여전히 먼저라 순서가 안 뒤집힌다
        # (header-satisfiable 함정 — 회귀 락 실측: 0<1(correct)과 0<99(naive) 모두 동일 순서).
        # prose-M(correct=1) vs L(correct=2, exact)이 진짜 이빨: naive lookup은 prose를 99로
        # 떨어뜨려 L(naive=2)이 먼저 오도록 뒤집는다.
        data = {"meta": META_OK, "findings": [f("A1-1", "HIGH", "M — 훅 20줄"), f("A1-2", "HIGH", "S"),
                f("A1-3", "HIGH", "L")],
                "d_verdicts": [], "oq_answers": [], "new_open_questions": [], "axis_failures": [], "degraded": []}
        rc, md, err = render(data)
        self.assertEqual(rc, 0, err)
        self.assertLess(md.index("A1-2"), md.index("A1-1"), "S가 M보다 먼저여야 (산문 섞여도)")
        self.assertLess(md.index("A1-1"), md.index("A1-3"),
                         "M(산문)이 L보다 먼저여야 — naive whole-string lookup은 이 쌍에서 뒤집는다")

    def test_codex_absent_banner(self):
        # degraded item의 "what"에 "codex" substring이 있으면 배너 분기와 무관하게
        # assertIn("codex", ...)가 통과해버려 toothless — "what"에서 codex를 빼고
        # 배너 고유 문구("codex 독립 감사 미실행")를 직접 단언한다.
        m = dict(META_OK); m["codex"] = {"ran": False}
        data = {"meta": m, "findings": [], "d_verdicts": [], "oq_answers": [],
                "new_open_questions": [], "axis_failures": [], "degraded": [{"what": "기타 결손", "why": "x"}]}
        rc, md, err = render(data)
        self.assertEqual(rc, 0, err)
        head = "\n".join(md.splitlines()[:20])
        self.assertIn("codex 독립 감사 미실행", head)
        self.assertIn("⚠", head)

    def test_all_axes_dead_no_report(self):  # AC-4(a)
        data = {"meta": META_OK, "findings": [], "d_verdicts": [], "oq_answers": [],
                "new_open_questions": [], "axis_failures": [{"axis": i, "why": "죽음"} for i in range(1, 7)],
                "degraded": []}
        rc, md, err = render(data)
        self.assertEqual(rc, 1, "6축 전멸인데 리포트를 만들었다 (AC-4a)")

    def test_partial_axes_banner(self):  # AC-4(b)
        data = {"meta": META_OK, "findings": [f("A1-1", "HIGH", "S")], "d_verdicts": [], "oq_answers": [],
                "new_open_questions": [], "axis_failures": [{"axis": 2, "why": "x"}], "degraded": [{"what": "x", "why": "y"}]}
        rc, md, _ = render(data)
        head = "\n".join(md.splitlines()[:20])
        self.assertIn("/6", head)  # "5/6 축 완주" 류

    def test_deep_verified_three_states(self):  # §9.2
        # toothless였던 원래 형태(assertIn("상한 초과", md) 전역 1건)는 3-state가 2-state로
        # collapse돼도 GREEN — finding별 라인을 추출해 세 상태를 개별 단언한다.
        data = {"meta": META_OK, "findings": [
            f("A1-1", "HIGH", "S", deep_verified=True),
            f("A1-2", "HIGH", "S", deep_verified=False),
            f("A1-3", "MEDIUM", "S", deep_verified=None)],
            "d_verdicts": [], "oq_answers": [], "new_open_questions": [], "axis_failures": [], "degraded": []}
        rc, md, err = render(data)
        self.assertEqual(rc, 0, err)
        lines = md.splitlines()

        def line_for(id_):
            for ln in lines:
                if f"({id_})" in ln:
                    return ln
            self.fail(f"{id_}에 대한 라인을 찾을 수 없음:\n{md}")

        l1, l2, l3 = line_for("A1-1"), line_for("A1-2"), line_for("A1-3")
        self.assertIn("통과", l1, "True → 심층검증 통과 라벨이 있어야")
        self.assertIn("상한 초과", l2, "False → 상한 초과 라벨이 있어야")
        self.assertNotIn("통과", l3, "None은 통과 라벨이 없어야")
        self.assertNotIn("상한 초과", l3, "None은 상한 초과 라벨도 없어야 (무라벨)")

    def test_noq_section_and_cross_model_badge(self):
        data = {"meta": META_OK,
                "findings": [f("A1-1", "HIGH", "S", cross_model_confirmed=True)],
                "d_verdicts": [], "oq_answers": [],
                "new_open_questions": [{"id": "NOQ-1", "source": "claude", "axis": 3,
                                        "observation": "obs", "why_not_gap": "LD5 밖", "evidence": []}],
                "axis_failures": [], "degraded": []}
        rc, md, _ = render(data)
        self.assertIn("NOQ-1", md)
        self.assertIn("obs", md)
        self.assertIn("⚑", md)  # cross-model 배지

    def test_sort_reference_gap_tiebreak(self):
        # stage 3: severity·cost 동률, reference_gap 유무만 다름 — 있는 쪽이 먼저.
        # id를 일부러 반대로 배정(A3-9=있음, A3-1=없음)해 stage-4(id) 낙폭으로
        # 우연히 통과하는 걸 배제한다: id만으로 정렬되면 A3-1이 먼저 와야 하는데
        # stage 3가 살아있으면 A3-9(레퍼런스 격차 있음)가 먼저 와야 한다.
        data = {"meta": META_OK, "findings": [
            f("A3-9", "HIGH", "S", reference_gap="OMC 있음"),
            f("A3-1", "HIGH", "S", reference_gap="none")],
            "d_verdicts": [], "oq_answers": [], "new_open_questions": [], "axis_failures": [], "degraded": []}
        rc, md, err = render(data)
        self.assertEqual(rc, 0, err)
        self.assertLess(md.index("A3-9"), md.index("A3-1"),
                         "reference_gap 있는 A3-9가 없는 A3-1보다 먼저여야 (stage 3, id 역순 배치로 우연통과 배제)")

    def test_sort_id_tiebreak(self):
        # stage 4: severity·cost·reference_gap 유무까지 전부 동률 — id 오름차순만 남는다.
        # 입력 순서를 내림차순(A4-9 먼저)으로 줘서, id 요소가 tuple에서 빠지면(stable sort로
        # 입력 순서 그대로 유지) 실패하도록 만든다.
        data = {"meta": META_OK, "findings": [
            f("A4-9", "HIGH", "S", reference_gap="none"),
            f("A4-1", "HIGH", "S", reference_gap="none")],
            "d_verdicts": [], "oq_answers": [], "new_open_questions": [], "axis_failures": [], "degraded": []}
        rc, md, err = render(data)
        self.assertEqual(rc, 0, err)
        self.assertLess(md.index("A4-1"), md.index("A4-9"),
                         "동률이면 id 오름차순(A4-1 먼저)이어야 (stage 4)")

    def test_oq_answers_and_backref(self):
        # Fix 1: oq_answers[]/oq_ref 렌더링. OQ1은 좌/우 대칭(빈 쪽=0건 명시),
        # OQ2..6은 answer+evidence+reason. finding.oq_ref는 해당 OQ 서브섹션에
        # 역참조로 나타나야 한다.
        data = {"meta": META_OK,
                "findings": [f("A2-1", "HIGH", "S", oq_ref="OQ2")],
                "d_verdicts": [],
                "oq_answers": [
                    {"id": "OQ1", "source": "claude", "reason": "r1",
                     "left_evidence": [{"claim": "좌주장", "file": "a.py", "line": 1, "quote": "q1"}],
                     "right_evidence": []},
                    {"id": "OQ2", "source": "claude", "answer": "답변입니다", "reason": "r2",
                     "evidence": [{"file": "b.py", "line": 2, "quote": "q2"}]},
                ],
                "new_open_questions": [], "axis_failures": [], "degraded": []}
        rc, md, err = render(data)
        self.assertEqual(rc, 0, err)
        self.assertIn("배정된 열린 질문", md, "OQ 섹션 헤더가 있어야")
        self.assertIn("좌주장", md, "OQ1 좌측 claim이 렌더돼야")
        self.assertIn("0건", md, "OQ1 우측이 비었으면 0건으로 명시돼야 (숨기면 안 됨, §9.5)")
        # OQ2 서브섹션만 슬라이스해 답변·역참조가 "그 서브섹션 안에" 있는지 확인
        idx_oq2 = md.index("### OQ2")
        rest = md[idx_oq2 + len("### OQ2"):]
        next_hash = rest.find("### ")
        oq2_section = rest if next_hash == -1 else rest[:next_hash]
        self.assertIn("답변입니다", oq2_section, "OQ2 answer가 OQ2 서브섹션에 렌더돼야")
        self.assertIn("A2-1", oq2_section, "oq_ref==OQ2인 finding이 OQ2 서브섹션에 역참조돼야")

    def test_oq_evidence_renders_for_non_oq1_id(self):
        # WB4: left/right evidence 렌더는 id가 아니라 *구조*로 분기해야 한다. OQ id는 seed-derived라
        # OQ2~4에도 left/right evidence가 붙는데(2026-07-15 baseline), `if oq_id=="OQ1"` 하드코딩은
        # 그것을 조용히 드롭했다. OQ2에 left/right evidence를 줘서 렌더되는지 확인 — `oq_id=="OQ1"`로
        # 되돌리면 이 단언이 RED (steelman_condition 포함).
        data = {"meta": META_OK, "findings": [],
                "d_verdicts": [], "oq_answers": [
                    {"id": "OQ2", "source": "claude", "reason": "r2",
                     "left_evidence": [{"claim": "좌증거OQ2", "file": "x.py", "line": 3, "quote": "qx"}],
                     "right_evidence": [{"claim": "우증거OQ2", "file": "y.py", "line": 4, "quote": "qy"}],
                     "steelman_condition": "b"}],
                "new_open_questions": [], "axis_failures": [], "degraded": []}
        rc, md, err = render(data)
        self.assertEqual(rc, 0, err)
        idx = md.index("### OQ2")
        rest = md[idx + len("### OQ2"):]
        nxt = rest.find("### ")
        section = rest if nxt == -1 else rest[:nxt]
        self.assertIn("좌증거OQ2", section, "OQ2 left_evidence가 렌더돼야 (구조-구동, id 무관)")
        self.assertIn("우증거OQ2", section, "OQ2 right_evidence가 렌더돼야")
        self.assertIn("스틸맨 조건", section, "OQ2 steelman_condition이 렌더돼야")

    def test_d_verdicts_render(self):
        # d_verdicts[]는 oq_answers와 동일한 "producer but no reader" 증발 위험이 있던 필드
        # (audit-workflow.js가 만들고 validate-audit-data.py가 검증하지만 렌더러가 드롭했던 버그).
        # D2에 claude/codex 두 source를 엇갈린 verdict로 줘서 §9.3("해소하지 않고 나란히
        # 드러낸다")이 실제로 지켜지는지 — 즉 둘 다 렌더되는지 — 확인한다. D4는 unverified +
        # why_unverifiable로 "불가사유"가 정직하게 보여지는지 확인한다.
        data = {"meta": META_OK, "findings": [], "oq_answers": [], "new_open_questions": [],
                "axis_failures": [], "degraded": [],
                "d_verdicts": [
                    {"id": "D2", "source": "claude", "verdict": "confirmed", "reason": "클로드근거"},
                    {"id": "D2", "source": "codex", "verdict": "withdrawn", "reason": "코덱스근거"},
                    {"id": "D4", "source": "claude", "verdict": "unverified", "reason": "불명확",
                     "why_unverifiable": "재현불가사유"},
                ]}
        rc, md, err = render(data)
        self.assertEqual(rc, 0, err)
        self.assertIn("후보 단서 판정", md, "D-verdicts 섹션 헤더가 있어야")
        # 두 source의 verdict가 모두 나타나야 — 하나로 collapse되면(첫 source만 렌더)
        # withdrawn이 사라진다 (divergence가 숨겨짐).
        self.assertIn("confirmed", md, "D2 claude 판정(confirmed)이 렌더돼야")
        self.assertIn("withdrawn", md, "D2 codex 판정(withdrawn)이 렌더돼야 — 엇갈림을 숨기면 안 됨(§9.3)")
        self.assertIn("클로드근거", md, "D2 claude 근거가 렌더돼야")
        self.assertIn("코덱스근거", md, "D2 codex 근거가 렌더돼야")
        self.assertIn("재현불가사유", md, "unverified의 why_unverifiable(불가사유)가 렌더돼야")

    def test_string_degraded_does_not_crash(self):
        # producer 계약: check-plugin-structure.sh(Gate E)는 degraded를 **평문 문자열**로
        # 방출한다 (add_degr가 str append). render가 x.get('what')을 무조건 호출하면 문자열에서
        # AttributeError로 리포트가 전멸한다 — "plugin-dev 미설치"는 문서화된 흔한 degrade다.
        # E의 실제 산출 shape를 먹여 크래시하지 않고 렌더되는지 락한다.
        data = {"meta": META_OK, "findings": [], "d_verdicts": [], "oq_answers": [],
                "new_open_questions": [], "axis_failures": [],
                "degraded": ["⚠ plugin-dev 미설치 — 심층 구조 검사 생략"]}
        rc, md, err = render(data)
        self.assertEqual(rc, 0, f"평문 문자열 degraded에서 render가 크래시:\n{err}")
        self.assertIn("plugin-dev 미설치", md, "문자열 degraded 내용이 렌더돼야")

    def test_title_uses_meta_target(self):
        # plugin-audit로 이관하며 유일한 project-init 리터럴이던 title을 meta.target에서
        # 유도하도록 일반화한다 (Task 5). 하드코딩된 "project-init"이 남아있으면 이 테스트가
        # quality-gates target에서 RED여야 한다 — 타이틀은 렌더된 md의 첫 줄이다.
        m = dict(META_OK); m["target"] = "quality-gates"
        data = {"meta": m, "findings": [], "d_verdicts": [], "oq_answers": [],
                "new_open_questions": [], "axis_failures": [], "degraded": []}
        rc, md, err = render(data)
        self.assertEqual(rc, 0, err)
        first_line = md.splitlines()[0]
        self.assertIn("quality-gates", first_line,
                      "meta.target이 리포트 첫 줄(title)에 반영돼야 — project-init 하드코딩 잔존 시 실패")


if __name__ == "__main__":
    unittest.main()
