"""합치기 전 지적 목록 파일(`--pre-merge-out`) — AC21 의 합성 스크립트 · qg 본문 쪽."""
import contextlib
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "synthesize_findings.py"
SKILL = ROOT / "skills" / "quality-pipeline" / "SKILL.md"
spec = importlib.util.spec_from_file_location("synthesize_findings_premerge", SCRIPT)
mod = importlib.util.module_from_spec(spec)
sys.path.insert(0, str(SCRIPT.parent))
spec.loader.exec_module(mod)

FLAG = '--pre-merge-out "$RD/findings-pre-merge.yaml"'
A1 = {"agent": "security-reviewer", "file": "src/a.py", "line": 41, "severity": "IMPORTANT",
      "summary": "캐시 키를 검증하지 않는다", "proposed_fix": "키를 검증한다"}
A2 = {"agent": "security-reviewer", "file": "src/a.py", "line": 41, "severity": "IMPORTANT",
      "summary": "캐시 키 검증이 빠졌다", "proposed_fix": "검증을 더한다"}
B = {"agent": "security-reviewer", "file": "src/b.py", "line": 7, "severity": "CRITICAL",
     "summary": "로그에 토큰을 남긴다", "proposed_fix": "토큰을 가린다"}
LOWER_B = "verdicts:\n  - {f: f3, verdict: lower, evidence: \"의도 밖 처방\"}\n"


def run_synth(findings, recritic, pre_merge=None):
    """`pre_merge` 의 `{d}` 는 임시 폴더로 바뀐다. Returns `(rc, stdout, stderr, written)`."""
    with tempfile.TemporaryDirectory() as d:
        fp = Path(d) / "findings.yaml"
        fp.write_text(json.dumps(findings, ensure_ascii=False), encoding="utf-8")
        loaded, _dropped, _dead = mod.load_findings(str(fp))
        _items, mapping = mod.anonymize(loaded)
        mp = Path(d) / "map.json"
        mp.write_text(json.dumps(mapping, ensure_ascii=False), encoding="utf-8")
        rp = Path(d) / "reply.txt"
        rp.write_text("끝.\n\n```qg-recritic\n" + recritic + "```\n", encoding="utf-8")
        argv = ["--findings", str(fp), "--recritic", str(rp), "--recritic-map", str(mp)]
        if pre_merge is not None:
            argv += ["--pre-merge-out", pre_merge.replace("{d}", d)]
        out, err = io.StringIO(), io.StringIO()
        old = sys.argv
        sys.argv = ["synthesize_findings.py"] + argv
        rc = 0
        try:
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                mod.main()
        except SystemExit as exc:
            rc = exc.code if isinstance(exc.code, int) else 1
        finally:
            sys.argv = old
        written = None
        target = Path(d) / "pre.yaml"
        if target.exists():
            written = yaml.safe_load(target.read_text(encoding="utf-8"))
        return rc, out.getvalue(), err.getvalue(), written


class TestPreMergeOut(unittest.TestCase):

    def test_written_before_dedup(self):
        # 앞의 둘 = 같은 자리 · 같은 심각도(합쳐지는 쌍), 셋째 = 재비판이 낮춘 것
        rc, _out, _err, doc = run_synth([A1, A2, B], LOWER_B, "{d}/pre.yaml")
        self.assertEqual(rc, 0)
        self.assertEqual(len(doc["findings"]), 3)
        same_spot = [f for f in doc["findings"] if f["file"] == "src/a.py"]
        self.assertEqual(len(same_spot), 2)
        lowered = [f for f in doc["findings"] if f["file"] == "src/b.py"][0]
        self.assertEqual(lowered["severity"], "SUGGESTION")
        self.assertIs(lowered["lowered"], True)

    def test_does_not_change_verdict(self):
        rc1, out1, _e1, _d1 = run_synth([A1, A2, B], LOWER_B)
        rc2, out2, _e2, _d2 = run_synth([A1, A2, B], LOWER_B, "{d}/pre.yaml")
        self.assertEqual(rc1, rc2)
        self.assertEqual(out1.encode("utf-8"), out2.encode("utf-8"))

    def test_unwritable_keeps_rc(self):
        rc1, out1, _e1, _d1 = run_synth([A1, A2, B], LOWER_B)
        rc2, out2, err2, _d2 = run_synth([A1, A2, B], LOWER_B, "{d}/없는폴더/pre.yaml")
        self.assertEqual(rc2, rc1)
        self.assertEqual(out2, out1)
        self.assertIn("[synthesize_findings] 합치기 전 목록을 쓰지 못했다 — ", err2)

    def test_empty_is_usage(self):
        rc, _out, _err, _doc = run_synth([A1], LOWER_B, "")
        self.assertEqual(rc, 2)

    def test_skill_fences_pass_it(self):
        text = SKILL.read_text(encoding="utf-8")
        step4 = text.index("**rc 를 소비하라.**")
        restore = text.index("**되올려 다시 합성하기.**")
        fence_start = text.rindex('synthesize_findings.py" --findings', 0, step4)
        fence = text[fence_start:step4]
        self.assertEqual(fence.count(FLAG), 1)
        self.assertLess(fence.index('--emit-verdict --angles "$RV/angles.txt"'), fence.index(FLAG))
        para_end = text.index("\n\n", restore)
        self.assertEqual(text[restore:para_end].count(FLAG), 1)
        # 양의 짝: 파일 전체에 정확히 둘 — Step 3.9 의 synth-review 펜스에는 없다
        self.assertEqual(text.count(FLAG), 2)
        review_end = text.index('echo "synth-review rc=')
        review_fence = text[text.rindex('synthesize_findings.py"', 0, review_end):review_end]
        self.assertNotIn("--pre-merge-out", review_fence)
        self.assertIn("synth-review.out", review_fence)


if __name__ == "__main__":
    unittest.main()
