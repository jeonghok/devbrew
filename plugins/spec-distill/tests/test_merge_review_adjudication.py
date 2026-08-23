"""merge_review 가 버린 것을 «세는지» 본다.

「깨끗함」과 바이트 동일한 출력이 나오면 RED — 그것이 이 결함의 모양이었다.
"""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "merge_review.py"


def run(claude_text, codex_yaml=None):
    with tempfile.TemporaryDirectory() as d:
        cp = Path(d) / "claude.txt"
        cp.write_text(claude_text, encoding="utf-8")
        argv = [sys.executable, str(SCRIPT), "--claude-output", str(cp)]
        if codex_yaml is not None:
            yp = Path(d) / "codex.yaml"
            yp.write_text(codex_yaml, encoding="utf-8")
            argv += ["--codex-yaml", str(yp)]
        else:
            argv += ["--codex-yaml", "/nonexistent"]
        r = subprocess.run(argv, capture_output=True, text=True)
        return r.stdout


SENTINEL = '```spec-review-issues\n%s\n```\n'


class TestAdjudicationAccounting(unittest.TestCase):

    def test_non_dict_issue_is_held_not_dropped(self):
        """#1 — 비-dict 원소를 버리면서 「깨끗함」을 단언하던 자리."""
        body = ('{"issues": [{"category":"c","target_section":"s",'
                '"severity":"high","message":"m"}, "쓰레기", 42]}')
        out = run("**Status:** needs_revise\n" + SENTINEL % body)
        self.assertIn("adjudication_held: 2", out,
                      "비-dict 원소 2개가 보류로 계수돼야 한다")

    def test_missing_sentinel_is_uncountable_not_zero(self):
        """#1 — 원리적 미상. issues 리스트가 만들어지기 전이라 개수를 모른다."""
        out = run("**Status:** needs_revise\n(센티널 블록 없음)\n")
        self.assertIn("adjudication_unknown:", out)
        self.assertIn("claude_issues", out,
                      "무엇을 셀 수 없었는지 이름이 나와야 한다")
        self.assertNotIn("adjudication_held: 0\nadjudication_unknown: \n", out,
                         "0 으로 뭉개면 거짓 clean 이다")

    def test_malformed_codex_yaml_reports_count(self):
        """#2 — 셀 수 있는데 안 세던 자리."""
        yaml = ("findings:\n"
                "  - category: a\n"
                "    target_section: b\n"
                "meta:\n"
                "  codex_failed: false\n"
                "  codex_failed: false\n")   # 중복 마커 → malformed
        body = '{"issues": []}'
        out = run("**Status:** approved\n" + SENTINEL % body, codex_yaml=yaml)
        self.assertIn("codex_yaml_malformed", out)
        self.assertRegex(out, r"adjudication_held: [1-9]",
                         "버려진 codex finding 개수가 보고돼야 한다")

    def test_empty_key_codex_finding_is_held(self):
        """#5 — category·target_section 이 둘 다 빈 finding 이 원장에 안 들어가던 자리."""
        yaml = ("findings:\n"
                "  - category: ''\n"
                "    target_section: ''\n"
                "    severity: high\n"
                "meta:\n"
                "  codex_failed: false\n")
        body = '{"issues": []}'
        out = run("**Status:** approved\n" + SENTINEL % body, codex_yaml=yaml)
        self.assertRegex(out, r"adjudication_held: [1-9]",
                         "키 없는 codex finding 이 보류로 계수돼야 한다")

    def test_verdict_contract_unchanged(self):
        """회계 추가가 verdict 를 바꾸지 않는다 (AC10 회귀 방어)."""
        body = '{"issues": []}'
        out = run("**Status:** approved\n" + SENTINEL % body)
        self.assertIn("combined_verdict: approved", out)
        self.assertIn("codex_degraded: true", out)


if __name__ == "__main__":
    unittest.main()
