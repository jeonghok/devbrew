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
        m = dict(META_OK); m["codex"] = {"ran": False}
        data = {"meta": m, "findings": [], "d_verdicts": [], "oq_answers": [],
                "new_open_questions": [], "axis_failures": [], "degraded": [{"what": "codex 미실행", "why": "x"}]}
        rc, md, _ = render(data)
        head = "\n".join(md.splitlines()[:20])
        self.assertIn("codex", head.lower())
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
        data = {"meta": META_OK, "findings": [
            f("A1-1", "HIGH", "S", deep_verified=True),
            f("A1-2", "HIGH", "S", deep_verified=False),
            f("A1-3", "MEDIUM", "S", deep_verified=None)],
            "d_verdicts": [], "oq_answers": [], "new_open_questions": [], "axis_failures": [], "degraded": []}
        rc, md, _ = render(data)
        # false = "상한 초과" 라벨, null = 무라벨
        self.assertIn("상한 초과", md)

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


if __name__ == "__main__":
    unittest.main()
