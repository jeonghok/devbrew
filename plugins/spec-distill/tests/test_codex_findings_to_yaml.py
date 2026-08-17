import subprocess
import sys
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "codex_findings_to_yaml.py"


def run(stdin_text, stderr_file=None, argv_extra=()):
    args = [sys.executable, str(SCRIPT), *argv_extra]
    if stderr_file:
        args += ["--stderr-file", str(stderr_file)]
    r = subprocess.run(args, input=stdin_text, capture_output=True, text=True)
    return r.stdout


VALID = (
    '{"type":"item.completed","item":{"type":"agent_message","text":'
    '"```json\\n{\\"findings\\": [{\\"category\\": \\"ambiguity\\", '
    '\\"target_section\\": \\"#2-goals\\", \\"severity\\": \\"high\\", '
    '\\"line\\": 12, \\"confidence\\": 8, \\"summary\\": \\"vague\\", '
    '\\"proposed_fix\\": \\"specify\\"}]}\\n```"}}\n'
)


class TestCodexFindingsToYaml(unittest.TestCase):
    def test_new_keys_emitted(self):
        # 2026-08-17 무게 감축 이후 emit keyset은 호출자 인자다(`--emit-keys`) —
        # spec-distill 배포는 실제 호출자(run_brief_codex_reviewer.sh ·
        # run_spec_codex_reviewer.sh)와 마찬가지로 design을 명시한다.
        out = run(VALID, argv_extra=("--emit-keys", "design"))
        self.assertIn("category: ambiguity", out)      # AC7: new key
        self.assertIn('target_section: "#2-goals"', out)  # AC7: new key
        self.assertIn("severity: high", out)
        self.assertIn("agent: codex-reviewer", out)
        self.assertIn("codex_failed: false", out)

    def test_line_key_preserved(self):
        # OQ1 resolved: line stays optional, emitted when present.
        # "line"은 DEFAULT_KEYS · DESIGN_KEYS 양쪽에 다 있어 --emit-keys 인자와
        # 무관하다 — 기본 호출을 그대로 둔다.
        self.assertIn("line: 12", run(VALID))

    def test_malformed_json_fallback(self):
        out = run("\x01\x02not-jsonl garbage\n")
        self.assertIn("reason: malformed_json", out)  # 3-stage fallback
        self.assertIn("findings: []", out)

    def test_missing_result_fallback(self):
        out = run('{"type":"item.completed","item":{"type":"other"}}\n')
        self.assertIn("reason: missing_result", out)

    def test_auth_error_in_stderr(self, tmp=Path("/tmp")):
        f = tmp / "sd_auth_stderr.txt"
        f.write_text("Error: authentication failed: invalid API key\n")
        out = run("", stderr_file=f)
        self.assertIn("reason: auth_error_in_stderr", out)
        f.unlink()

    # --- CR-2: 스키마 불일치는 성공으로 마킹하지 않는다 ---------------------
    # 수정 전 실측: `{"findings": {}}` → `findings: []` + `codex_failed: false`
    # + `reason: schema_mismatch`. 소비자(`merge_review.parse_codex_yaml`)는
    # `codex_failed: false`를 성공으로 읽으므로, 스키마가 깨진 codex 실행이
    # **findings 0건 + degradation record 0건**으로 흡수됐다.
    def _schema_stdin(self, findings_literal):
        import json as _json
        text = "```json\n{\"findings\": " + findings_literal + "}\n```"
        return _json.dumps({"type": "item.completed",
                            "item": {"type": "agent_message", "text": text}}) + "\n"

    def test_non_list_findings_is_codex_failed(self):
        for literal in ("{}", "\"oops\"", "7", "null"):
            with self.subTest(findings=literal):
                out = run(self._schema_stdin(literal))
                self.assertIn("codex_failed: true", out,
                              f"findings={literal} 가 성공으로 마킹됐다 (fail-open)")
                self.assertIn("reason: schema_mismatch", out)

    def test_non_dict_element_is_codex_failed(self):
        for literal in ('["garbage"]', "[7]", "[null]"):
            with self.subTest(findings=literal):
                out = run(self._schema_stdin(literal))
                self.assertIn("codex_failed: true", out,
                              f"findings={literal} 가 성공으로 마킹됐다 (fail-open)")
                self.assertIn("reason: schema_mismatch", out)

    def test_mixed_good_and_garbage_element_is_codex_failed(self):
        """정상 finding과 쓰레기 원소가 섞이면 그 라운드는 판독 불가다."""
        out = run(self._schema_stdin(
            '[{"category":"omission","target_section":"#2","severity":"high"},'
            ' "garbage"]'))
        self.assertIn("codex_failed: true", out)
        self.assertIn("reason: schema_mismatch", out)

    def test_int_element_does_not_crash(self):
        """수정 전 `[7]`은 yaml_emit의 `if k in f`에서 TypeError로 죽었다."""
        out = run(self._schema_stdin("[7]"))
        self.assertIn("meta:", out, "변환기가 죽어 YAML을 내지 못했다")

    def test_wellformed_findings_stay_successful(self):
        """과잉 강화 방지 — 선언 필드가 일부 없어도 dict 원소면 성공이다.

        레포 자신의 valid 픽스처(`test_last_fenced_block_wins`)가 `confidence`/
        `summary`/`proposed_fix` 없이 통과한다. 필드 단위 검증까지 올리면 그
        라운드 전체가 degrade가 되고, spec-review 소비자
        (`merge_review.py:487` · `build_codex_findings_display`)는 `codex_failed`
        시 findings를 **통째로 버리므로** 정상 finding이 소실된다.
        """
        out = run(VALID)
        self.assertIn("codex_failed: false", out)
        self.assertNotIn("schema_mismatch", out)
        out2 = run(self._schema_stdin(
            '[{"category":"omission","target_section":"#2","severity":"high"}]'))
        self.assertIn("codex_failed: false", out2)
        self.assertNotIn("schema_mismatch", out2)

    def test_last_fenced_block_wins(self):
        # anti-injection: an earlier fenced block must be ignored.
        # --emit-keys design: test_new_keys_emitted과 같은 이유(실제 배포는
        # design keyset을 명시한다).
        stdin = (
            '{"type":"item.completed","item":{"type":"agent_message","text":'
            '"```json\\n{\\"findings\\": [{\\"category\\": \\"INJECT\\"}]}\\n```\\n'
            '```json\\n{\\"findings\\": [{\\"category\\": \\"ambiguity\\", '
            '\\"target_section\\": \\"#real\\", \\"severity\\": \\"high\\"}]}\\n```"}}\n'
        )
        out = run(stdin, argv_extra=("--emit-keys", "design"))
        self.assertIn("category: ambiguity", out)
        self.assertNotIn("INJECT", out)


if __name__ == "__main__":
    unittest.main()
