"""재비판이 낮춘 지적을 이유와 함께 보이고 `--restore-lowered` 로 되올린다(AC26).

`main()` 을 직접 돌려 stdout 을 본다 — 표면은 원장이 아니라 사람이 보는 출력이다.
"""
import contextlib
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "synthesize_findings.py"
spec = importlib.util.spec_from_file_location("synthesize_findings_lowered", SCRIPT)
mod = importlib.util.module_from_spec(spec)
sys.path.insert(0, str(SCRIPT.parent))
spec.loader.exec_module(mod)

REASON = "의도 출처는 캐시 무효화만 요구한다"
IMP = {"agent": "security-reviewer", "file": "src/a.py", "line": 41, "severity": "IMPORTANT",
       "summary": "캐시 키를 검증하지 않는다", "proposed_fix": "키를 검증한다"}
IMP2 = {"agent": "security-reviewer", "file": "src/b.py", "line": 7, "severity": "CRITICAL",
        "summary": "로그에 토큰을 남긴다", "proposed_fix": "토큰을 가린다"}
LOWER_F1 = "verdicts:\n  - {f: f1, verdict: lower, evidence: \"%s\"}\n" % REASON
LOWER_BOTH = ("verdicts:\n  - {f: f1, verdict: lower, evidence: \"%s\"}\n"
              "  - {f: f2, verdict: lower, evidence: \"둘째 이유\"}\n" % REASON)


def run_synth(findings, recritic, extra=(), emit=False, use_recritic=True):
    """Returns `(rc, stdout, stderr)`."""
    with tempfile.TemporaryDirectory() as d:
        fp = Path(d) / "findings.yaml"
        fp.write_text(json.dumps(findings, ensure_ascii=False), encoding="utf-8")
        loaded, _dropped, _dead = mod.load_findings(str(fp))
        _items, mapping = mod.anonymize(loaded)
        mp = Path(d) / "map.json"
        mp.write_text(json.dumps(mapping, ensure_ascii=False), encoding="utf-8")
        rp = Path(d) / "reply.txt"
        rp.write_text("재비판을 마쳤습니다.\n\n```qg-recritic\n" + recritic + "```\n",
                      encoding="utf-8")
        argv = ["--findings", str(fp)]
        if use_recritic:
            argv += ["--recritic", str(rp), "--recritic-map", str(mp)]
        argv += list(extra)
        if emit:
            argv.append("--emit-verdict")
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
        return rc, out.getvalue(), err.getvalue()


def synth(*a, **kw):
    rc, out, err = run_synth(*a, **kw)
    if rc != 0:
        raise AssertionError("rc=%s stderr=%s" % (rc, err))
    return out


class TestLoweredSection(unittest.TestCase):

    def test_lowered_section_lists_original_severity_and_reason(self):
        out = synth([IMP], LOWER_F1)
        self.assertIn("lowered: 1\n", out)
        self.assertIn("blocking: 0\n", out)
        self.assertIn("## 낮춘 지적", out)
        self.assertRegex(out, r"\| L1 \| src/a\.py:41 \| IMPORTANT \| .+ \| 의도 출처는 캐시 무효화만 요구한다 \|")

    def test_section_header_and_place(self):
        """표 머리가 정해진 꼴이고, 절은 지적 표 뒤 · 「고칠 방법」 앞이다."""
        out = synth([IMP], LOWER_F1)
        self.assertIn("## 낮춘 지적\n\n| 번호 | 위치 | 원래 심각도 | 내용 | 낮춘 이유 |\n|---|---|---|---|---|\n", out)
        self.assertLess(out.index("| 심각도 | 위치 |"), out.index("## 낮춘 지적"))
        self.assertLess(out.index("## 낮춘 지적"), out.index("**고칠 방법:**"))

    def test_content_cell_is_the_summary(self):
        out = synth([IMP], LOWER_F1)
        self.assertIn("| L1 | src/a.py:41 | IMPORTANT | 캐시 키를 검증하지 않는다 | %s |" % REASON, out)

    def test_content_cell_uses_plain_first(self):
        f = dict(IMP, plain="캐시 키를 확인하지 않아 남의 값을 읽을 수 있다")
        out = synth([f], LOWER_F1)
        self.assertIn("| L1 | src/a.py:41 | IMPORTANT | 캐시 키를 확인하지 않아 남의 값을 읽을 수 있다 "
                      "(캐시 키를 검증하지 않는다) |", out)

    def test_lowered_line_right_after_optional(self):
        out = synth([IMP], LOWER_F1)
        lines = out.splitlines()
        i = lines.index("optional: 1")
        self.assertEqual(lines[i + 1], "lowered: 1")
        self.assertEqual(out.count("\nlowered: "), 1)

    def test_numbering_follows_input_order_not_table_order(self):
        """번호는 입력 순서다 — 지적 표는 심각도 · 파일로 정렬하지만 L 번호는 그 정렬을 따르지 않는다."""
        z = dict(IMP, file="src/z.py", line=1)
        a = dict(IMP, file="src/a.py", line=2, summary="둘째")
        out = synth([z, a], LOWER_BOTH)
        self.assertIn("lowered: 2\n", out)
        self.assertLess(out.index("| L1 | src/z.py:1 |"), out.index("| L2 | src/a.py:2 |"))
        self.assertLess(out.index("| SUGGESTION (lowered) | src/a.py:2 |"),
                        out.index("| SUGGESTION (lowered) | src/z.py:1 |"),
                        "전제: 지적 표는 파일 순으로 정렬된다")

    def test_reason_cell_escapes_pipe(self):
        rc = "verdicts:\n  - {f: f1, verdict: lower, evidence: \"a|b\"}\n"
        out = synth([IMP], rc)
        self.assertIn("| a\\|b |", out)

    def test_no_lowered_no_section(self):
        out = synth([IMP], "verdicts:\n  - {f: f1, verdict: confirm}\n")
        self.assertIn("lowered: 0\n", out)
        self.assertNotIn("## 낮춘 지적", out)
        self.assertNotIn("restored:", out)

    def test_lower_without_evidence_is_not_lowered(self):
        """근거 없는 lower 는 confirm 으로 강제된다 — 낮춘 지적이 아니다."""
        out = synth([IMP], "verdicts:\n  - {f: f1, verdict: lower}\n")
        self.assertIn("lowered: 0\n", out)
        self.assertIn("blocking: 1\n", out)

    def test_lowered_line_on_empty_run(self):
        out = synth([], "verdicts: []\n")
        self.assertIn("optional: 0\nlowered: 0\n", out)


class TestRestore(unittest.TestCase):

    def test_restore_lowered_puts_it_back(self):
        out = synth([IMP], LOWER_F1, extra=["--restore-lowered", "L1"])
        self.assertIn("blocking: 1\n", out)
        self.assertIn("restored: L1\n", out)
        self.assertIn("(사용자가 되올림)", out)

    def test_restored_row_keeps_original_severity_and_prefix(self):
        out = synth([IMP], LOWER_F1, extra=["--restore-lowered", "L1"])
        self.assertIn("lowered: 1\nrestored: L1\n", out)
        self.assertIn("| L1 | src/a.py:41 | IMPORTANT | 캐시 키를 검증하지 않는다 | (사용자가 되올림) %s |"
                      % REASON, out)
        self.assertIn("| IMPORTANT | src/a.py:41 |", out)
        self.assertNotIn("(lowered)", out)

    def test_restore_all(self):
        out = synth([IMP, IMP2], LOWER_BOTH, extra=["--restore-lowered", "all"])
        self.assertIn("blocking: 2\n", out)
        self.assertIn("restored: L1,L2\n", out)

    def test_restore_some(self):
        out = synth([IMP, IMP2], LOWER_BOTH, extra=["--restore-lowered", "L2"])
        self.assertIn("blocking: 1\n", out)
        self.assertIn("restored: L2\n", out)
        self.assertIn("| L1 | src/a.py:41 | IMPORTANT | 캐시 키를 검증하지 않는다 | %s |" % REASON, out)
        self.assertIn("| L2 | src/b.py:7 | CRITICAL | 로그에 토큰을 남긴다 | (사용자가 되올림) 둘째 이유 |", out)
        self.assertIn("| CRITICAL | src/b.py:7 |", out)

    def test_restore_list_with_spaces(self):
        out = synth([IMP, IMP2], LOWER_BOTH, extra=["--restore-lowered", "L1, L2"])
        self.assertIn("blocking: 2\n", out)

    def test_restore_changes_verdict(self):
        base = synth([IMP], LOWER_F1, emit=True)
        back = synth([IMP], LOWER_F1, extra=["--restore-lowered", "L1"], emit=True)
        self.assertIn("verdict: clean\n", base, "전제: 낮춘 대로면 clean")
        self.assertIn("verdict: defect\n", back)

    def test_restore_is_not_coercion(self):
        """사람의 결정은 강제가 아니다 — 되올림이 degrade 공시를 켜지 않는다."""
        out = synth([IMP], LOWER_F1, extra=["--restore-lowered", "L1"])
        self.assertNotIn(mod.DEGRADE_MARKER, out)
        self.assertNotIn("강제", out)

    def test_restore_unknown_number_exit2(self):
        rc, out, err = run_synth([IMP], LOWER_F1, extra=["--restore-lowered", "L9"])
        self.assertEqual(rc, 2)
        self.assertEqual(out, "", "rc 2 면 본 보고서를 쓰지 않는다")
        self.assertIn("synthesize_findings.py: 모르는 낮춘 지적 번호: L9", err)

    def test_restore_known_and_unknown_exit2(self):
        rc, out, err = run_synth([IMP], LOWER_F1, extra=["--restore-lowered", "L1,L9"])
        self.assertEqual(rc, 2)
        self.assertIn("모르는 낮춘 지적 번호: L9", err)
        self.assertNotIn("L1", err.split("모르는 낮춘 지적 번호:")[1])

    def test_restore_malformed_token_exit2(self):
        rc, _out, err = run_synth([IMP], LOWER_F1, extra=["--restore-lowered", "1"])
        self.assertEqual(rc, 2)
        self.assertIn("모르는 낮춘 지적 번호: 1", err)

    def test_restore_when_nothing_lowered_exit2(self):
        rc, _out, err = run_synth([IMP], "verdicts:\n  - {f: f1, verdict: confirm}\n",
                                  extra=["--restore-lowered", "L1"])
        self.assertEqual(rc, 2)
        self.assertIn("모르는 낮춘 지적 번호: L1", err)

    def test_restore_empty_value_exit2(self):
        rc, _out, err = run_synth([IMP], LOWER_F1, extra=["--restore-lowered", ""])
        self.assertEqual(rc, 2)
        self.assertIn("--restore-lowered 는 빈 문자열을 받지 않는다", err)

    def test_restore_all_mixed_with_number_exit2(self):
        rc, _out, err = run_synth([IMP], LOWER_F1, extra=["--restore-lowered", "all,L1"])
        self.assertEqual(rc, 2)
        self.assertIn("all 하나를 받는다", err)

    def test_restore_without_recritic_exit2(self):
        rc, _out, err = run_synth([IMP], LOWER_F1, extra=["--restore-lowered", "L1"],
                                  use_recritic=False)
        self.assertEqual(rc, 2)
        self.assertIn("--restore-lowered 는 --recritic 없이 의미가 없다", err)


class TestInvariants(unittest.TestCase):

    def test_prefix_invariant_holds(self):
        no = synth([IMP, IMP2], LOWER_BOTH)
        yes = synth([IMP, IMP2], LOWER_BOTH, emit=True)
        self.assertTrue(yes.startswith(no), "판정 없는 출력이 판정 있는 출력의 접두가 아니다")
        self.assertIn("verdict: ", yes[len(no):])

    def test_prefix_invariant_holds_with_restore(self):
        extra = ["--restore-lowered", "L1"]
        no = synth([IMP, IMP2], LOWER_BOTH, extra=extra)
        yes = synth([IMP, IMP2], LOWER_BOTH, extra=extra, emit=True)
        self.assertTrue(yes.startswith(no))

    def test_counted_lines_exactly_once(self):
        out = synth([IMP, IMP2], LOWER_BOTH, extra=["--restore-lowered", "L2"], emit=True)
        for k in ("verdict", "blocking", "optional", "lowered", "restored"):
            n = 0
            for line in out.splitlines():
                if line.startswith(k + ": "):
                    n += 1
            self.assertEqual(n, 1, k)

    def test_apply_verdicts_records_original_severity(self):
        f = dict(IMP)
        v = {"finding_id": mod.finding_id(f), "verdict": "lower",
             "adjusted_severity": "SUGGESTION", "reason": REASON}
        out, _ = mod.apply_verdicts([f], [v], ledger=mod.Ledger(items="open"))
        self.assertEqual(out[0]["severity"], "SUGGESTION")
        self.assertEqual(out[0]["lowered_from"], "IMPORTANT")
        self.assertEqual(out[0]["lowered_reason"], REASON)


if __name__ == "__main__":
    unittest.main()
