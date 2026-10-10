"""쉬운 말 출력 PR 4 — plugin-audit 이 사람에게 내는 고정 문구.

SKILL 의 codex 건너뜀 줄 · 렌더 배너를 가리키는 인용 · 종료 보고 틀, check-integrity 의 오류 · 요약 줄,
assemble 의 빈칸 채움 사유가 쉬운 말인지 잰다. 부재 단언마다 같은 자리의 양성 짝이 있다.
산문 단언은 줄바꿈을 지운 본문(flat)에서 잰다 — 다시 쓰일 때 문장이 줄을 넘을 수 있다.
"""
import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PLUGIN = Path(__file__).resolve().parents[1]
REPO = PLUGIN.parents[1]
SKILL = PLUGIN / "skills" / "plugin-audit" / "SKILL.md"
RENDER = PLUGIN / "scripts" / "render-audit-report.py"
INTEGRITY = PLUGIN / "scripts" / "check-integrity.sh"
ASSEMBLE = PLUGIN / "scripts" / "assemble-audit-data.py"


def flat(text):
    return " ".join(text.split())


def gate_block(body):
    m = re.search(r"<!--\s*codex-gate:begin[^>]*-->(.*?)<!--\s*codex-gate:end\s*-->", body, re.S)
    if m is None:
        raise AssertionError("codex-gate 블록이 없다")
    return m.group(1)


class SkillTextTest(unittest.TestCase):
    def setUp(self):
        self.body = SKILL.read_text(encoding="utf-8")
        self.flat = flat(self.body)

    def test_codex_skip_line_is_plain_and_keeps_reason_token(self):
        block = gate_block(self.body)
        self.assertIn("[plugin-audit] codex 독립 감사를 건너뛰었다 (reason: ${skip_reason:-unknown})", block)
        self.assertIn("이 감사에는 다른 모델의 확인이 없다. 모델 다양성 없음(degraded).", block)
        self.assertNotIn("co-audit SKIPPED", block, "옛 영어 건너뜀 줄이 남았다")

    def test_pointer_quote_matches_the_render_banner(self):
        quote = "축 완주 수와 기록(journal)으로 확인하라"
        self.assertIn('"' + quote + '" 포인터의', self.flat, "SKILL 이 렌더 배너를 옛 글자로 인용한다")
        self.assertIn(quote, RENDER.read_text(encoding="utf-8"), "인용한 글자가 렌더 배너에 없다")
        self.assertNotIn("journal로 확인하라", self.flat)

    def test_final_report_template(self):
        a = self.flat.index("8. **종료 보고**")
        b = self.flat.index("## kill switch")
        step = self.flat[a:b]
        self.assertIn("첫 줄은 리포트 둘째 줄의 상태 문장을 그대로 쓴다", step)
        self.assertIn("리포트 (`$RUN_DIR/audit.md`)의 절대경로를 보인다 — 사용자가 열어 볼 것은 이것이다.", step)
        self.assertIn("원장(`$RUN_DIR/audit-journal.jsonl`) 경로는 사용자가 물을 때만 보인다.", step)
        self.assertIn("맨 끝에 사용자가 할 일 하나를 쓴다", step)
        self.assertNotIn("의 절대경로를 사용자에게 보인다", step, "세 경로를 모두 보이던 옛 틀이 남았다")


class IntegrityTextTest(unittest.TestCase):
    def run_ci(self, *args):
        with tempfile.TemporaryDirectory() as t:
            out = str(Path(t) / "m.txt")
            argv = [args[0], out] + list(args[1:]) if args else []
            r = subprocess.run(["bash", str(INTEGRITY)] + argv, cwd=str(REPO),
                               capture_output=True, text=True, encoding="utf-8")
            return r.returncode, r.stderr

    def test_missing_target_value(self):
        rc, err = self.run_ci("ld5", "--target")
        self.assertEqual(rc, 2, err)
        self.assertIn("[check-integrity] FATAL: --target 에 값이 없다(--target requires a value)", err)

    def test_missing_extra_path_value(self):
        rc, err = self.run_ci("ld5", "--extra-path")
        self.assertEqual(rc, 2, err)
        self.assertIn("[check-integrity] FATAL: --extra-path 에 값이 없다(--extra-path requires a value)", err)

    def test_unknown_argument(self):
        rc, err = self.run_ci("ld5", "--bogus")
        self.assertEqual(rc, 2, err)
        self.assertIn("[check-integrity] FATAL: 알 수 없는 인자다 — --bogus (unknown argument)", err)

    def test_ld5_needs_target(self):
        rc, err = self.run_ci("ld5")
        self.assertEqual(rc, 2, err)
        self.assertIn("[check-integrity] FATAL: ld5 모드에는 --target <name> 이 필요하다(mode=ld5 requires --target)", err)

    def test_empty_manifest(self):
        rc, err = self.run_ci("ld5", "--target", "zz-no-such-plugin")
        self.assertEqual(rc, 1, err)
        self.assertIn("[check-integrity] FATAL: 해시 목록이 비었다(mode=ld5, manifest is empty) — 열거한 파일이 하나도 없다.", err)

    def test_summary_line(self):
        rc, err = self.run_ci("harness")
        self.assertEqual(rc, 0, err)
        self.assertRegex(err, r"\[check-integrity\] 파일 [1-9][0-9]*개의 해시를 적었다\(mode=harness\) -> ")
        self.assertNotIn("files=", err, "옛 영어 요약 줄이 남았다")


class AssembleTextTest(unittest.TestCase):
    def test_backfill_reasons_are_plain(self):
        meta = {"date": "2026-01-01", "fanout_declared": 30,
                "consent": {"approved": True, "at": "2026-01-01T00:00Z", "fanout": 30},
                "codex": {"ran": True, "version": "1.0"}, "target": "myplugin", "seed_provided": False}
        files = {
            "workflow-return": {"findings": [], "d_verdicts": [], "oq_answers": [], "new_open_questions": [],
                                "axis_failures": [2], "degraded_events": []},
            "codex-side": {"d_verdicts": [], "oq_answers": [], "new_open_questions": []},
            "meta": meta,
            "assigned": {"assigned_d": ["D2"], "assigned_oq": ["OQ1"]},
        }
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            argv = [sys.executable, str(ASSEMBLE)]
            for flag, obj in files.items():
                p = d / (flag + ".json")
                p.write_text(json.dumps(obj), encoding="utf-8")
                argv += ["--" + flag, str(p)]
            out = d / "out.json"
            argv += ["--repo-root", str(d), "--no-grounding", "--out", str(out)]
            r = subprocess.run(argv, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            data = json.loads(out.read_text(encoding="utf-8"))
        d2 = [v for v in data["d_verdicts"] if v["id"] == "D2"]
        oq1 = [v for v in data["oq_answers"] if v["id"] == "OQ1"]
        self.assertEqual(d2[0]["reason"], "축 감사가 끝나지 않아 빈칸을 채웠다(backfilled)")
        self.assertEqual(oq1[0]["reason"], "축 감사가 끝나지 않아 빈칸을 채웠다(backfilled — 검증 안 됨)")
        self.assertNotIn("axis incomplete", json.dumps(data, ensure_ascii=False))


PREAMBLE = PLUGIN / "scripts" / "codex-prompt-preamble.md"
CONVERTER = PLUGIN / "scripts" / "codex_audit_to_json.py"


class PlainFieldTest(unittest.TestCase):
    """`plain:` 칸 — 형식(codex 프롬프트) · 넘기기(변환기 · 조립) · 그리기(렌더)를 끝에서 끝까지."""

    def test_preamble_offers_plain_as_optional(self):
        text = PREAMBLE.read_text(encoding="utf-8")
        self.assertIn("Optional `plain` (string): the same finding in one plain sentence a first-time reader "
                      "understands, no internal IDs.", flat(text))
        self.assertIn('"plain": "one plain sentence for a first-time reader"', text)

    def test_codex_plain_reaches_the_report_heading_first(self):
        payload = {"findings": [
            {"id": "CX-1", "axis": 3, "title": "t1", "severity": "IMPORTANT",
             "evidence": [{"file": "a.py", "line": 1, "quote": "q"}], "plain": "쉬운 한 문장"},
            {"id": "CX-2", "axis": 3, "title": "t2", "severity": "SUGGESTION",
             "evidence": [{"file": "b.py", "line": 2, "quote": "q"}]}],
            "d_verdicts": [], "oq_answers": [], "new_open_questions": []}
        ev = json.dumps({"type": "item.completed", "item": {"type": "agent_message",
                         "text": "```json\n" + json.dumps(payload) + "\n```"}}) + "\n"
        conv = subprocess.run([sys.executable, str(CONVERTER)], input=ev, capture_output=True, text=True)
        self.assertEqual(conv.returncode, 0, conv.stderr)
        found = json.loads(conv.stdout)["findings"]
        wf_findings = []
        for f in found:
            g = dict(f)
            g.update({"source": "codex", "status": "reported"})
            wf_findings.append(g)
        meta = {"date": "2026-01-01", "fanout_declared": 30,
                "consent": {"approved": True, "at": "2026-01-01T00:00Z", "fanout": 30},
                "codex": {"ran": True, "version": "1.0"}, "target": "myplugin", "seed_provided": False}
        files = {
            "workflow-return": {"findings": wf_findings, "d_verdicts": [], "oq_answers": [],
                                "new_open_questions": [], "axis_failures": [], "degraded_events": []},
            "codex-side": {"d_verdicts": [], "oq_answers": [], "new_open_questions": []},
            "meta": meta, "assigned": {"assigned_d": [], "assigned_oq": []},
        }
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            argv = [sys.executable, str(ASSEMBLE)]
            for flag, obj in files.items():
                p = d / (flag + ".json")
                p.write_text(json.dumps(obj, ensure_ascii=False), encoding="utf-8")
                argv += ["--" + flag, str(p)]
            data_p, md_p = d / "audit-data.json", d / "audit.md"
            argv += ["--repo-root", str(d), "--no-grounding", "--out", str(data_p)]
            r = subprocess.run(argv, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            r = subprocess.run([sys.executable, str(RENDER), str(data_p), "--out", str(md_p)],
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            md = md_p.read_text(encoding="utf-8")
        self.assertIn("### [IMPORTANT] 쉬운 한 문장 (t1 · CX-1)\n", md)
        self.assertIn("### [SUGGESTION] t2 (CX-2)\n", md, "plain 없는 codex 지적도 버려지지 않고 나온다")
        self.assertNotIn("None", md, "codex 의 최소 필드 지적에도 None 이 찍히지 않는다")


README = PLUGIN / "README.md"


class ReadmeTextTest(unittest.TestCase):
    def setUp(self):
        self.text = README.read_text(encoding="utf-8")
        self.lead = flat(self.text.split("\n## ", 1)[0].split("\n", 1)[1])

    def test_lead_says_what_it_does(self):
        self.assertTrue(self.lead.startswith("devbrew 플러그인 하나를 고치지 않고 읽기만 해서 감사한다."), self.lead[:80])
        self.assertIn("결과는 증거가 붙은 빈틈 목록이고, 심각한 것부터 정렬된다.", self.lead)

    def test_done_report_line_matches_the_skill(self):
        body = flat(self.text)
        self.assertIn("감사가 끝나면 상태 한 줄과 리포트(`audit.md`) 경로를 보고한다 — 데이터 · 원장 경로는 물으면 보인다.", body)
        self.assertNotIn("세 파일의 절대경로", body)


if __name__ == "__main__":
    unittest.main()
