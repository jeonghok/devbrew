"""auditing-plugins/SKILL.md — codex 게이트가 **실행 가능한 형태**인가.

산문 게이트는 "껐다고 믿게만" 만든다: 모델이 게이트를 건너뛰면 kill switch가 우회되고,
그 우회는 아무 검사에도 걸리지 않는다. kill switch는 P21 보안 컨트롤이라 그 상태를
남길 수 없다. 이 파일은 착수 전 bash fence가 **0개**였다.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKILL = ROOT / "skills" / "auditing-plugins" / "SKILL.md"
BEGIN = re.compile(r"<!--\s*codex-gate:begin\s+runner=([A-Za-z0-9_.-]+)\s*-->")


class TestSkillCodexGate(unittest.TestCase):
    def setUp(self):
        self.body = SKILL.read_text(encoding="utf-8")

    def test_gate_marker_pair_exists(self):
        self.assertRegex(self.body, BEGIN, "codex-gate:begin 마커 부재")
        self.assertIn("<!-- codex-gate:end -->", self.body)

    def test_marker_names_the_runner_it_gates(self):
        m = BEGIN.search(self.body)
        self.assertIsNotNone(m)
        self.assertEqual(m.group(1), "run_audit_codex_reviewer.sh")
        self.assertTrue((ROOT / "scripts" / m.group(1)).is_file(),
                        "마커가 이름 댄 러너가 실재해야 한다")

    def _gate_block(self):
        m = BEGIN.search(self.body)
        self.assertIsNotNone(m, "codex-gate:begin 마커 부재")
        tail = self.body[m.end():]
        self.assertIn("<!-- codex-gate:end -->", tail, "begin 뒤에 end 마커가 없다")
        end = tail.index("<!-- codex-gate:end -->")
        fences = re.findall(r"```bash\n(.*?)\n```", tail[:end], re.DOTALL)
        self.assertEqual(len(fences), 1, "게이트 마커 사이에 bash fence가 정확히 1개여야 한다")
        return fences[0]

    def test_gate_is_a_literal_if_not_prose(self):
        block = self._gate_block()
        self.assertIn('if [[ "$codex_avail" == "true" ]]', block,
                      "게이트가 리터럴 조건이 아니다 — 산문은 집행되지 않는다")

    def test_gate_calls_detect_before_the_runner(self):
        block = self._gate_block()
        self.assertLess(block.index("detect_codex.sh"),
                        block.index("run_audit_codex_reviewer.sh"),
                        "detect가 러너보다 먼저 와야 게이트다")

    def test_kill_switch_is_documented(self):
        self.assertIn("DEVBREW_DISABLE_PLUGIN_AUDIT_CODEX", self.body,
                      "kill switch가 문서에서 발견 가능해야 한다 (P21)")

    def test_degrade_advisory_is_loud(self):
        block = self._gate_block()
        self.assertIn("모델 다양성", block,
                      "배너는 'codex 없음'이 아니라 'P11이 집행되지 않았다'를 말해야 한다")

    def test_routing_is_split_into_two_paths(self):
        """`findings`와 나머지 셋의 소비자가 다르다 — 한 문장으로 묶으면 오해가 남는다.

        실측: assemble()의 findings는 wf["findings"]에서만 온다(:49). codex_side["findings"]를
        읽는 코드는 **없다**. codex findings는 audit-workflow.js의 codexFindings 경로로
        이미 들어와 있다.
        """
        self.assertIn("codexFindings", self.body)
        self.assertIn("--codex-side", self.body)
        # 네 키를 한 문장에 묶은 옛 서술이 남아 있으면 안 된다.
        self.assertNotRegex(
            self.body,
            r"findings\(CX-\*\),\s*d_verdicts,\s*\n?\s*oq_answers,\s*new_open_questions\}`\s*—\s*post-1에서\s*`--codex-side`",
            "네 키를 한 문장으로 묶은 서술이 남아 있다 — 오해의 출처")

    def test_no_prose_codex_exec_left(self):
        """산문 `codex exec` 지시가 남아 있으면 후보 스캔이 못 보는 호출부가 남는다.

        이 SKILL은 이제 `run_audit_codex_reviewer.sh`를 부른다 — codex 바이너리를 직접
        언급할 이유가 없다. 백틱 인라인 코드 안의 것도 포함해 **문자열 부재**로 잰다:
        그것이 정확히 test_codex_runner_no_effort_pin.sh의 정규식(백틱 앞선 형태를
        못 봄)이 놓치던 모양이고, 여기서 놓치면 어디서도 안 잡힌다.
        """
        needle = "codex" + " exec"     # 아래 주석 참조 — 리터럴로 적으면 자기매칭이다
        offenders = [ln.strip() for ln in self.body.splitlines() if needle in ln]
        self.assertEqual(offenders, [],
                         f"산문/인라인 호출 지시가 남아 있다: {offenders[:3]}")
        # 이 파일 자신이 `codex`+`exec`를 **공백으로 이어 붙인** 형태로 적으면,
        # quality-gates/tests/test_codex_runner_no_effort_pin.sh의 리포 전역 스캔이
        # 그것을 "샌드박스 없는 invocation"으로 잡는다 (실측: 2026-08-09). 그 스캔의
        # INVOKE는 `(^|공백)codex\s+exec\s`라 백틱/따옴표 뒤 형태는 통과시키지만
        # 산문 속 공백-인접 형태는 실제 호출과 구별할 수 없다 — 스캐너가 옳다.
        # 스캐너를 느슨하게 하는 대신 여기서 문자열을 쪼갠다.


if __name__ == "__main__":
    unittest.main()
