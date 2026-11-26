"""합치기 전 지적 목록 파일(`--pre-merge-out`) — AC21 의 합성 스크립트 · qg 본문 쪽."""
import contextlib
import importlib.util
import io
import json
import sys
import tempfile
import os
import unittest
from pathlib import Path
from unittest import mock

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


def run_synth(findings, recritic, pre_merge=None, extra=(), prep=None, patch_replace=False, seen=None):
    """`pre_merge` · `extra` 의 `{d}` 는 임시 폴더로 바뀐다. Returns `(rc, stdout, stderr, written)`.

    `prep(d)` 는 실행 앞에 임시 폴더를 꾸민다. `patch_replace` 면 `os.replace` 가 실패한다.
    `seen` 이 dict 면 실행 뒤 폴더의 이름 목록(`names`)과 `inspect(d)` 결과를 담는다."""
    with tempfile.TemporaryDirectory() as d:
        if prep is not None:
            prep(d)
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
        argv += [a.replace("{d}", d) for a in extra]
        out, err = io.StringIO(), io.StringIO()
        old = sys.argv
        sys.argv = ["synthesize_findings.py"] + argv
        rc = 0
        try:
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err), \
                    mock.patch("os.replace", side_effect=OSError("replace 실패")) if patch_replace \
                    else contextlib.nullcontext():
                mod.main()
        except SystemExit as exc:
            rc = exc.code if isinstance(exc.code, int) else 1
        finally:
            sys.argv = old
        written = None
        target = Path(d) / "pre.yaml"
        if seen is not None:
            seen["names"] = sorted(os.listdir(d))
            if "inspect" in seen:
                seen["result"] = seen["inspect"](d)
        if target.exists() and not target.is_symlink():
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

    def test_verdict_failure_leaves_no_pre_merge(self):
        # AC22 — 판정 계산이 멈추면(읽지 못하는 --scope → rc 4) 합치기 전 목록 파일이 생기지 않는다.
        seen = {}
        rc, out, _err, doc = run_synth([A1, A2, B], LOWER_B, "{d}/pre.yaml",
                                       extra=["--emit-verdict", "--scope", "{d}/없는-scope.txt"], seen=seen)
        self.assertEqual(rc, 4)
        self.assertEqual(out, "")
        self.assertIsNone(doc)
        self.assertNotIn("pre.yaml", seen["names"])
        # 양의 짝 — 읽지 못하는 --scope 만 뺀 같은 판정 호출은 판정이 나고 파일이 생긴다.
        rc2, out2, err2, doc2 = run_synth([A1, A2, B], LOWER_B, "{d}/pre.yaml", extra=["--emit-verdict"])
        self.assertIn("verdict:", out2)
        self.assertEqual(rc2, 0, err2)
        self.assertEqual(len(doc2["findings"]), 3)

    def test_write_failure_removes_old_file(self):
        # AC22 — 쓰기가 실패하면(임시 파일을 쓴 뒤 자리 바꾸기에서) 옛 파일도 임시 파일도 남지 않는다 · rc · stdout 그대로.
        def old(d):
            (Path(d) / "pre.yaml").write_text("findings: [옛 실행]\n", encoding="utf-8")
        rc1, out1, _e1, _d1 = run_synth([A1, A2, B], LOWER_B)
        seen = {}
        rc2, out2, err2, doc2 = run_synth([A1, A2, B], LOWER_B, "{d}/pre.yaml", prep=old,
                                          patch_replace=True, seen=seen)
        self.assertEqual(rc2, rc1)
        self.assertEqual(out2, out1)
        self.assertIn("[synthesize_findings] 합치기 전 목록을 쓰지 못했다 — ", err2)
        self.assertIsNone(doc2)
        self.assertNotIn("pre.yaml", seen["names"])
        self.assertEqual([n for n in seen["names"] if "pre.yaml" in n], [], seen["names"])

    def test_tmp_not_following_symlink(self):
        # 옛 임시 파일 이름(`<대상>.tmp`) 자리에 링크를 미리 두어도 링크 너머가 바뀌지 않고, 대상은 보통 파일이다.
        def plant(d):
            (Path(d) / "victim.txt").write_text("그대로\n", encoding="utf-8")
            os.symlink(str(Path(d) / "victim.txt"), str(Path(d) / "pre.yaml.tmp"))
        seen = {"inspect": lambda d: ((Path(d) / "victim.txt").read_text(encoding="utf-8"),
                                      (Path(d) / "pre.yaml").is_symlink())}
        rc, _out, err, doc = run_synth([A1, A2, B], LOWER_B, "{d}/pre.yaml", prep=plant, seen=seen)
        self.assertEqual(rc, 0, err)
        self.assertEqual(seen["result"], ("그대로\n", False))
        self.assertEqual(len(doc["findings"]), 3)

    def test_recritic_added_finding_in_pre_merge(self):
        # AC23 · 제안 21 — 재비판이 더한(added) 지적이 합치기 전 목록에 실린다.
        added = ("verdicts: []\nadded:\n  - {file: src/c.py, line: 9, severity: IMPORTANT, "
                 "summary: \"경로를 거르지 않는다\", proposed_fix: \"경로를 거른다\"}\n")
        rc, _out, err, doc = run_synth([A1, B], added, "{d}/pre.yaml")
        self.assertEqual(rc, 0, err)
        got = [f for f in doc["findings"] if f["file"] == "src/c.py"]
        self.assertEqual(len(got), 1, doc)
        self.assertEqual(got[0]["summary"], "경로를 거르지 않는다")
        self.assertIs(got[0]["promoted"], True)
        self.assertEqual(len(doc["findings"]), 3)

    def test_fix_line_file_with_newline_one_line(self):
        # AC10 — 「고칠 방법」 줄의 파일 칸에 줄바꿈이 들어도 한 줄이다.
        f = dict(A1, file="a\nb.py", line=3)
        rc, out, err, _doc = run_synth([f], "verdicts: []\n")
        self.assertEqual(rc, 0, err)
        tail = out[out.index("**고칠 방법:**"):].splitlines()
        self.assertEqual(tail[1:], ["- #1 `a b.py:3` — 키를 검증한다"])

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
