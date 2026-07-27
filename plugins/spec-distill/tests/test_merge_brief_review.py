#!/usr/bin/env python3
"""Spec B T5 — merge_brief_review.py.

AC7(fail-closed 합집합 · codex binding) · AC8(`codex_isolated: false` 항상) ·
AC9(codex 부재 시 critic verdict 보존 + `codex_degraded: true`)

Run: cd plugins/spec-distill/tests && python3 -m unittest test_merge_brief_review -v
"""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "plugins" / "spec-distill" / "scripts" / "merge_brief_review.py"

CRITIC_APPROVED = """# Brief Fidelity Review

**Status:** Approved

```brief-critic-issues
{"issues": []}
```
"""

CRITIC_ISSUES = """# Brief Fidelity Review

**Status:** Issues Found

```brief-critic-issues
{"issues": [
  {"category": "distortion", "target_section": "#2-제약", "severity": "high",
   "message": "C1 statement가 S1 원문의 뜻을 바꿨다"}
]}
```
"""

CRITIC_HEADING_STATUS = CRITIC_ISSUES.replace("**Status:** Issues Found",
                                              "## Status: Issues Found")
CRITIC_NO_STATUS = CRITIC_ISSUES.replace("**Status:** Issues Found", "판정 없음")

CODEX_CLEAN = "findings: []\nmeta:\n  codex_failed: false\n"
CODEX_ISSUE = """findings:
  - agent: codex-reviewer
    category: omission
    target_section: "#2-제약"
    severity: high
    confidence: 8
    summary: S3 원문의 핵심이 §2에서 빠졌다
    proposed_fix: 제약 항목 추가
meta:
  codex_failed: false
"""
CODEX_FAILED = "findings: []\nmeta:\n  codex_failed: true\n  reason: missing_result\n"


def merge(critic_text, codex_text=None, omit_codex=False):
    with tempfile.TemporaryDirectory() as d:
        cpath = Path(d) / "critic.md"
        cpath.write_text(critic_text, encoding="utf-8")
        args = [sys.executable, str(SCRIPT), "--critic-output", str(cpath)]
        if not omit_codex:
            ypath = Path(d) / "codex.yaml"
            ypath.write_text(codex_text if codex_text is not None else CODEX_CLEAN,
                             encoding="utf-8")
            args += ["--codex-yaml", str(ypath)]
        proc = subprocess.run(args, capture_output=True, text=True)
        return proc.returncode, proc.stdout, proc.stderr


def kv(out):
    d = {}
    for line in out.splitlines():
        if ":" in line and not line.startswith((" ", "-")):
            k, _, v = line.partition(":")
            d[k.strip()] = v.strip()
    return d


class TestExists(unittest.TestCase):
    def test_script_exists(self):
        self.assertTrue(SCRIPT.is_file(), f"스크립트 부재: {SCRIPT}")


class TestVerdictUnion(unittest.TestCase):
    def test_both_clean_approved(self):
        rc, out, _ = merge(CRITIC_APPROVED, CODEX_CLEAN)
        self.assertEqual(rc, 0)
        self.assertEqual(kv(out)["fidelity_verdict"], "approved")

    def test_critic_only_issues_makes_verdict(self):
        _, out, _ = merge(CRITIC_ISSUES, CODEX_CLEAN)
        self.assertEqual(kv(out)["fidelity_verdict"], "needs_revise")

    def test_codex_only_issues_makes_verdict(self):
        """codex는 binding — 단독으로 verdict를 만든다 (advisory 아님)."""
        _, out, _ = merge(CRITIC_APPROVED, CODEX_ISSUE)
        d = kv(out)
        self.assertEqual(d["fidelity_verdict"], "needs_revise")
        self.assertEqual(d["critic_verdict"], "approved")
        self.assertEqual(d["codex_verdict"], "needs_revise")

    def test_findings_carry_source_labels(self):
        _, out, _ = merge(CRITIC_ISSUES, CODEX_ISSUE)
        self.assertIn("source: critic", out)
        self.assertIn("source: codex", out)


class TestCodexIsolationLabel(unittest.TestCase):
    def test_codex_isolated_always_false_present(self):
        for critic, codex in ((CRITIC_APPROVED, CODEX_CLEAN),
                              (CRITIC_ISSUES, CODEX_ISSUE),
                              (CRITIC_APPROVED, CODEX_FAILED)):
            _, out, _ = merge(critic, codex)
            self.assertEqual(kv(out)["codex_isolated"], "false",
                             "codex_isolated: false 가 항상 출력되지 않는다")

    def test_codex_isolated_present_when_codex_omitted(self):
        _, out, _ = merge(CRITIC_APPROVED, omit_codex=True)
        self.assertEqual(kv(out)["codex_isolated"], "false")


class TestCodexDegrade(unittest.TestCase):
    def test_codex_missing_preserves_critic_verdict(self):
        _, out, _ = merge(CRITIC_ISSUES, omit_codex=True)
        d = kv(out)
        self.assertEqual(d["codex_degraded"], "true")
        self.assertEqual(d["critic_verdict"], "needs_revise")
        self.assertEqual(d["fidelity_verdict"], "needs_revise")

    def test_codex_missing_with_clean_critic_is_approved_but_loud(self):
        _, out, _ = merge(CRITIC_APPROVED, omit_codex=True)
        d = kv(out)
        self.assertEqual(d["fidelity_verdict"], "approved")
        self.assertEqual(d["codex_degraded"], "true")
        self.assertIn("codex", out.lower())
        self.assertIn("advisory", out)

    def test_codex_failed_marker_is_degrade_not_clean(self):
        _, out, _ = merge(CRITIC_APPROVED, CODEX_FAILED)
        self.assertEqual(kv(out)["codex_degraded"], "true")


class TestCriticVerdictParsing(unittest.TestCase):
    def test_heading_status_line_is_recovered(self):
        """round-4 실측: `## Status:` 형식이 verdict 소실을 일으켰다."""
        _, out, _ = merge(CRITIC_HEADING_STATUS, CODEX_CLEAN)
        d = kv(out)
        self.assertEqual(d["critic_verdict_unrecoverable"], "false")
        self.assertEqual(d["critic_verdict"], "needs_revise")

    def test_missing_status_is_unrecoverable_and_findings_still_parse(self):
        _, out, _ = merge(CRITIC_NO_STATUS, CODEX_CLEAN)
        d = kv(out)
        self.assertEqual(d["critic_verdict_unrecoverable"], "true")
        self.assertEqual(d["fidelity_verdict"], "needs_revise",
                         "findings가 있는데 approved로 갔다")
        self.assertIn("source: critic", out)

    def test_both_indeterminate_never_approves(self):
        """critic verdict 파싱 실패 + codex degraded → 사람에게. approved 금지."""
        no_findings = CRITIC_NO_STATUS.replace(
            '{"issues": [\n  {"category": "distortion", "target_section": "#2-제약", '
            '"severity": "high",\n   "message": "C1 statement가 S1 원문의 뜻을 바꿨다"}\n]}',
            '{"issues": []}')
        _, out, _ = merge(no_findings, omit_codex=True)
        d = kv(out)
        self.assertNotEqual(d["fidelity_verdict"], "approved",
                            "양쪽 판정 불가가 approved로 해소됐다 (fail-open)")
        self.assertIn("advisory", out)


if __name__ == "__main__":
    unittest.main()
