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

    def test_trailing_blank_agent_message_does_not_clobber_real_one(self):
        """F2 (2026-08-17 fix round 1): 진짜 답 뒤에 빈 agent_message가 흐르면
        진짜 것이 살아남아야 한다 — plugin-audit에만 있던 공백 가드
        (`codex_jsonl.py:extract_last_agent_message`)를 정본이 흡수한 이후의
        보장. 가드가 없으면 빈 후보가 last_text를 덮어써 파싱이 실패하고
        `codex_failed: true`(`reason: malformed_json`)로 findings가 소실된다
        (실측, fix round 1 리뷰) — fail-open 방향의 판정 변경이라 별도로
        고정한다.
        """
        import json as _json
        real = _json.dumps({
            "type": "item.completed",
            "item": {"type": "agent_message",
                      "text": "```json\n{\"findings\": [{\"file\": \"a\", "
                              "\"severity\": \"HIGH\", \"summary\": \"x\"}]}\n```"},
        })
        blank = _json.dumps({
            "type": "item.completed",
            "item": {"type": "agent_message", "text": "   "},
        })
        out = run(real + "\n" + blank + "\n")
        self.assertIn("codex_failed: false", out,
                       "진짜 finding이 있는데도 뒤따른 빈 메시지가 판정을 덮어썼다")
        self.assertIn("file: a", out, "뒤따른 빈 메시지가 진짜 finding을 지웠다")
        self.assertNotIn("malformed_json", out)


class TestSummaryScalarRoundTrip(unittest.TestCase):
    """`summary` 는 codex 가 쓴 임의의 모델 텍스트다 — 그 모양이 문서를 죽이면 안 된다.

    2026-08-19 실측(수정 전, 이 스크립트 종단): `summary` 가 `[` 로 시작하면
    (`"[CRITICAL] …"` — 리뷰어가 흔히 쓰는 모양) 인용 없이 나가 **문서 전체가**
    ParserError 로 죽었다. 소비자(`merge_review.parse_codex_yaml`)는 그 파일을
    읽지 못하고 그 라운드의 findings 가 통째로 소실된다.

    각 케이스는 두 겹으로 잰다:
      ① 텍스트 — 산출된 `summary:` 줄이 실제로 인용됐는가 (PyYAML 없이도 이빨이 있다)
      ② 왕복 — PyYAML 로 파싱해 **원문과 정확히 같은 문자열**이 돌아오는가
    ②는 "보기에 그럴듯한 YAML" 과 "실제로 되돌아오는 YAML" 을 가른다.
    """

    #: 축 ① 첫 글자 지시자 ② 문자열 내부 지시자 ③ 빈 문자열 ④ 인용 불필요(음의 짝)
    SHAPES = [
        ("leading_bracket", "[CRITICAL] 대괄호로 시작하는 요약", True),
        ("leading_bracket_advisory", "[spec-distill] advisory", True),
        ("leading_brace", "{brace}", True),
        ("leading_dash", "- dash", True),
        ("leading_backtick", "`handler()` 가 null 을 반환한다", True),
        ("empty_string", "", True),
        # 자기 선정: 첫 글자가 아닌 `[` — 형제 술어(`[]{}` 멤버십)가 함의하지만
        # 파싱은 원래도 성공하던 모양이다. 정본이 형제와 **같은** 술어를 쓰는지를
        # 여기서 잰다(파싱 실패 케이스만으로는 멤버십 축이 확인되지 않는다).
        ("mid_string_bracket", "array[0] 범위 초과", True),
        ("plain", "plain summary", False),
        ("plain_hyphen_inside", "codex-reviewer 가 지적함", False),
    ]

    def _stdin(self, summary):
        import json as _json
        inner = _json.dumps({"findings": [{"file": "a.py", "severity": "HIGH",
                                            "summary": summary}]})
        return _json.dumps({
            "type": "item.completed",
            "item": {"type": "agent_message",
                      "text": "```json\n" + inner + "\n```"},
        }) + "\n"

    def _summary_line(self, out):
        for line in out.splitlines():
            if line.strip().startswith("summary:"):
                return line.strip()
        self.fail("산출물에 summary 줄이 없다:\n" + out)

    def test_summary_line_is_quoted_when_needed(self):
        """텍스트 겹 — PyYAML 이 없어도 실행되는 이빨."""
        for name, raw, want_quoted in self.SHAPES:
            with self.subTest(shape=name):
                line = self._summary_line(run(self._stdin(raw)))
                value = line[len("summary:"):].strip()
                if want_quoted:
                    self.assertTrue(value.startswith('"') and value.endswith('"'),
                                    f"{name}: 인용되지 않았다 → {line!r}")
                else:
                    self.assertFalse(value.startswith('"'),
                                      f"{name}: 필요 없는데 인용됐다 → {line!r}")

    def test_summary_round_trips_exactly(self):
        """왕복 겹 — 파싱해서 **원문 그대로** 돌아오는가."""
        try:
            import yaml  # noqa: PLC0415
        except ImportError:  # pragma: no cover - 환경 의존
            self.skipTest("PyYAML 없음 — 왕복 검증이 실행되지 않았다 "
                          "(텍스트 겹은 test_summary_line_is_quoted_when_needed 가 잰다)")
        for name, raw, _ in self.SHAPES:
            with self.subTest(shape=name):
                out = run(self._stdin(raw))
                try:
                    doc = yaml.safe_load(out)
                except yaml.YAMLError as e:
                    self.fail(f"{name}: 산출물이 파싱되지 않는다 "
                              f"({type(e).__name__}) — 이 라운드의 findings 는 소실된다:\n{out}")
                self.assertIsInstance(doc, dict, f"{name}: 최상위가 매핑이 아니다:\n{out}")
                got = doc["findings"][0].get("summary")
                self.assertEqual(got, raw,
                                 f"{name}: 왕복이 값을 바꿨다 {raw!r} → {got!r}")

    def test_the_other_keys_still_round_trip(self):
        """축퇴 가드 — summary 만 보다가 이웃 키가 깨지는 것을 놓치지 않는다."""
        try:
            import yaml  # noqa: PLC0415
        except ImportError:  # pragma: no cover - 환경 의존
            self.skipTest("PyYAML 없음")
        doc = yaml.safe_load(run(self._stdin("[CRITICAL] 요약")))
        f = doc["findings"][0]
        self.assertEqual(f["file"], "a.py")
        self.assertEqual(f["severity"], "HIGH")
        self.assertEqual(f["agent"], "codex-reviewer")
        self.assertIs(doc["meta"]["codex_failed"], False)


def _wrap(findings_literal):
    """평문 `{"findings": [...]}` 을 codex JSONL 이벤트(agent_message, 펜스드 json)로
    감싼다. `run()` 은 `extract_last_agent_message` 를 거치므로 이 봉투 없이 평문을
    바로 stdin 에 흘리면 `item.get("type") != "agent_message"` 라 findings 가 아니라
    `reason: missing_result` 로 떨어진다(실측 — brief 초안의 raw-payload 케이스가
    이 이유로 전부 RED 였다: 의도한 단언과 무관한 실패였다)."""
    import json as _json
    text = "```json\n{\"findings\": " + findings_literal + "}\n```"
    return _json.dumps({"type": "item.completed",
                        "item": {"type": "agent_message", "text": text}}) + "\n"


class DocreviewKeys(unittest.TestCase):
    def test_docreview_keyset_emits_disposition_layer_editscope(self):
        payload = _wrap('[{"ref":"x1","layer":2,"category":"placeholder",'
                        '"anchor":"#a","disposition":"decide","summary":"s",'
                        '"edit_scope":"#a","blocks":["x2"],"evidence":"e"}]')
        out = run(payload, argv_extra=("--emit-keys", "docreview"))
        for tok in ("layer: 2", "disposition: decide", 'edit_scope: "#a"', 'anchor: "#a"'):
            self.assertIn(tok, out)

    def test_docreview_blocks_list_renders_flow_and_round_trips(self):
        """AC18의 리스트 렌더 분기(`blocks`)가 실제로 파싱 가능한 YAML을 내는지 —
        키 존재만 보면 `[x2, x3]`가 인용 없이 나가 파서를 깨뜨려도 못 잡는다."""
        payload = _wrap('[{"ref":"x1","layer":1,"category":"c","anchor":"#a",'
                        '"disposition":"ask","summary":"s","blocks":["x2","x3"],'
                        '"evidence":"e"}]')
        out = run(payload, argv_extra=("--emit-keys", "docreview"))
        try:
            import yaml  # noqa: PLC0415
        except ImportError:  # pragma: no cover - 환경 의존
            self.assertIn("blocks: [x2, x3]", out)
            return
        doc = yaml.safe_load(out)
        self.assertEqual(doc["findings"][0]["blocks"], ["x2", "x3"])

    def test_default_and_design_bytes_unchanged(self):
        # AC18: docreview keyset 추가가 기존 두 keyset 의 출력을 바꾸지 않는다.
        payload = _wrap('[{"file":"a.py","line":3,"severity":"high","summary":"s","proposed_fix":"f"}]')
        self.assertEqual(run(payload), run(payload, argv_extra=("--emit-keys", "default")))
        d = _wrap('[{"category":"x","target_section":"#a","severity":"high","summary":"s","proposed_fix":"f"}]')
        self.assertIn("category: x", run(d, argv_extra=("--emit-keys", "design")))

    def test_default_and_design_bytes_match_committed_fixture(self):
        """AC18 회귀 가드의 진짜 이빨 — `run(payload) == run(payload, "--emit-keys","default")`
        만 재면 양쪽이 같은 코드에서 나오는 항진명제다(둘 다 같은 버그를 함께 낸다면 여전히
        같아서 통과한다). 그래서 기대값은 커밋된 고정 바이트(이 테스트 자체에 리터럴로
        박은 산출물)와 대조한다 — `default`·`design` 코드 경로 자체가 바뀌면 이 리터럴과
        어긋나 RED 다."""
        payload = _wrap('[{"file":"a.py","line":3,"severity":"high","summary":"s","proposed_fix":"f"}]')
        self.assertEqual(
            run(payload),
            "findings:\n  - agent: codex-reviewer\n    file: a.py\n    line: 3\n"
            "    severity: high\n    summary: s\n    proposed_fix: f\n"
            "meta:\n  codex_failed: false\n",
        )
        d = _wrap('[{"category":"x","target_section":"#a","severity":"high","summary":"s","proposed_fix":"f"}]')
        self.assertEqual(
            run(d, argv_extra=("--emit-keys", "design")),
            "findings:\n  - agent: codex-reviewer\n    category: x\n"
            '    target_section: "#a"\n    severity: high\n    summary: s\n'
            "    proposed_fix: f\nmeta:\n  codex_failed: false\n",
        )

    def test_default_and_design_ignore_list_valued_scalar_field(self):
        """리뷰 라운드 1 CRIT-1 회귀 가드 — `yaml_emit` 의 flow-list 분기는
        `isinstance(v, list)` 만으로 열리면 안 된다. codex 출력은 신뢰 안 되는 외부
        LLM 생성 입력이라, `default`/`design` 이 선언한 스칼라 계약 필드(`file` ·
        `category`)에 기형으로 list 값이 실려도(`{"file": ["a.py","b.py"], ...}`)
        그 keyset 의 출력 바이트는 바뀌면 안 된다 — `blocks`(DOCREVIEW_KEYS 전용) 가
        아닌 키는 항상 옛 `_yaml_scalar(...)` 의 인용된 `str()` 폴백을 타야 한다.
        기대값은 `git show 81b0c9b:shared/codex/codex_findings_to_yaml.py`(이 필드
        분기가 생기기 전 버전)를 **독립 실행**해 얻은 실측 바이트다 — 지금 코드에서
        다시 계산한 값이 아니다(항진명제 방지, 위 test_..._match_committed_fixture
        와 같은 원칙)."""
        payload = _wrap('[{"file":["a.py","b.py"],"line":3,"severity":"high",'
                        '"summary":"s","proposed_fix":"f"}]')
        self.assertEqual(
            run(payload),
            "findings:\n  - agent: codex-reviewer\n    file: \"['a.py', 'b.py']\"\n"
            "    line: 3\n    severity: high\n    summary: s\n    proposed_fix: f\n"
            "meta:\n  codex_failed: false\n",
        )
        d = _wrap('[{"category":["x","y"],"target_section":"#a","severity":"high",'
                  '"summary":"s","proposed_fix":"f"}]')
        self.assertEqual(
            run(d, argv_extra=("--emit-keys", "design")),
            "findings:\n  - agent: codex-reviewer\n    category: \"['x', 'y']\"\n"
            '    target_section: "#a"\n    severity: high\n    summary: s\n'
            "    proposed_fix: f\nmeta:\n  codex_failed: false\n",
        )


if __name__ == "__main__":
    unittest.main()
