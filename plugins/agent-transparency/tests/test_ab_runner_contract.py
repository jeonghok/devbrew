#!/usr/bin/env python3
"""AC40 · AC45 · AC47 — A/B 러너 계약과 AC 커버리지.

`ab_gate.sh` **전체는 실행하지 않는다**(워커가 claude 를 부르므로 비용·비결정).
단 순수-python 가드 스니펫은 **추출해 JSON 픽스처로 실제 실행**한다 —
문자열 검사로는 그 판정 로직의 세 판을 구분하지 못한다.

Run:
    python3 -m unittest plugins/agent-transparency/tests/test_ab_runner_contract.py
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parents[3]
PLUGIN_DIR = REPO_ROOT / "plugins" / "agent-transparency"
REFERENCE = PLUGIN_DIR / "REFERENCE.md"

AC_ROW = re.compile(r"^\s*-\s+(AC\d+(?:[①②③④⑤⑥])?)\s*$")
ASSIGN_ROW = re.compile(r"^\|\s*(AC\d+(?:[①②③④⑤⑥])?)\s*\|\s*([^|]+?)\s*\|")
OQ_ROW = re.compile(r"^\s*-\s+(OQ-[A-Z]+)\s*(?:—|$)")


def section(text: str, heading: str) -> str:
    """`## <heading>` 부터 다음 `## ` 까지."""
    start = text.index("## " + heading)
    rest = text[start + 3:]
    end = rest.find("\n## ")
    return rest if end < 0 else rest[:end]


class TestCoverageLedger(unittest.TestCase):
    """AC47 — 모든 AC 가, 쪼개진 것은 그 조각까지, 검증 산출물에 배정돼 있다.

    **`REFERENCE.md` 한 파일만** 파싱한다. 설계 문서도 §8 트리도 읽지 않는다 —
    배포되지 않는 파일에 의존하면 정본을 옮긴 이유 그대로 stale 해진다.
    """

    def setUp(self) -> None:
        self.text = REFERENCE.read_text(encoding="utf-8")
        self.listed = {m.group(1) for m in
                       (AC_ROW.match(ln) for ln in
                        section(self.text, "AC 번호 목록").splitlines()) if m}
        self.assigned = {}
        for line in section(self.text, "AC ↔ 검증 산출물").splitlines():
            match = ASSIGN_ROW.match(line)
            if match and match.group(1) != "AC":
                self.assigned[match.group(1)] = match.group(2).strip()
        self.oqs = {m.group(1) for m in
                    (OQ_ROW.match(ln) for ln in
                     section(self.text, "미해결(OQ) 식별자 목록").splitlines()) if m}

    def test_lists_are_non_trivial(self) -> None:
        """계측기 자체가 고장 나면 빈 집합끼리 같아서 통과한다 — 먼저 막는다.

        **하한은 개수 단언이 아니다.** 파싱이 죽으면 집합이 0 이나 한 자리로
        떨어지므로 그것만 잡으면 충분하고, 실제 개수에 붙여 두면 AC 를 더하거나
        지울 때마다 이 줄을 고쳐야 하는 churn 이 된다(2026-08-13 훅 제거로 AC 8 개가
        빠지면서 실제로 red 가 났다). AC 를 **잃어버리는** 사고는 이 하한이 아니라
        아래 대칭차 검사가 잡는다 — 목록과 배정표는 서로의 증인이다.
        """
        self.assertGreaterEqual(len(self.listed), 25)
        self.assertGreaterEqual(len(self.oqs), 20)

    def test_floor_would_catch_a_dead_parser(self) -> None:
        """계측기 확인 — 하한이 실제로 파싱 실패를 구분하는가.

        하한을 내리는 편집은 락을 조용히 0 으로 만들기 쉬운 자리라 그 축을 고정한다.
        **헤딩이 사라지는 축은 여기서 재지 않는다** — `section()` 이 `ValueError` 를
        올려 red 가 되므로 하한이 필요 없다. 조용히 비는 축은 **행 형식이 바뀌어
        행 정규식이 하나도 안 맞는 경우**이고, 그것이 이 하한이 실제로 지키는 것이다.
        """
        renumbered = self.text.replace("\n- AC", "\n* AC")
        dead = {m.group(1) for m in
                (AC_ROW.match(ln) for ln in
                 section(renumbered, "AC 번호 목록").splitlines()) if m}
        self.assertEqual(dead, set(), "행 형식을 바꿨는데 여전히 파싱된다 — 계측기 고장")
        self.assertLess(len(dead), 25)

    def test_symmetric_difference_is_empty(self) -> None:
        self.assertEqual(self.listed - set(self.assigned), set(),
                         "목록에 있는데 배정이 없다")
        self.assertEqual(set(self.assigned) - self.listed, set(),
                         "배정에 있는데 목록에 없다")

    # NOTE: 배정된 **산출물이 실제로 존재하는지**를 보는 assertion 은 Task 11 에서
    # 더한다. 여기서 더하면 `tests/ab_gate.sh` · `tests/oracle/` 가 아직 없어
    # Task 9·10 이 red 로 끝나고, "각 task 는 독립적으로 테스트 가능한 산출물로
    # 끝난다" 는 규칙이 깨진다. 배정표의 **좌변 집합**은 여기서 이미 잠긴다.

    def test_unassigned_fragments_cite_a_real_oq(self) -> None:
        """`없음` 이 만능 탈출구가 되면 이 AC 자체가 새 fail-open 이 된다."""
        for ac, target in self.assigned.items():
            if not target.startswith("없음"):
                continue
            cited = re.findall(r"OQ-[A-Z]+", target)
            self.assertTrue(cited, "%s: 없음인데 OQ 식별자가 없다" % ac)
            for oq in cited:
                self.assertIn(oq, self.oqs, "%s 가 인용한 %s 가 목록에 없다" % (ac, oq))

    def test_split_ac_is_listed_by_fragment(self) -> None:
        """AC16 은 조각 단위로 오른다 — 번호 단위로 두면 실물 미측정 조각이
        차집합에 안 나타나 커버리지가 100%로 보고된다(이 AC 가 만들어진 계기)."""
        self.assertIn("AC16①", self.listed)
        self.assertIn("AC16②", self.listed)
        self.assertNotIn("AC16", self.listed)


class TestRubrics(unittest.TestCase):
    """AC32 좌변 — 루브릭 네 종 · 각 4문항. (게이트 표의 판정 방식은 계약 테스트.)"""

    def setUp(self) -> None:
        self.text = REFERENCE.read_text(encoding="utf-8")

    def test_four_rubrics_each_with_four_questions(self) -> None:
        for name in ("루브릭 A", "루브릭 B", "루브릭 C", "루브릭 D"):
            block = section(self.text, name)
            questions = re.findall(r"(?m)^\s*Q[1-4]\.", block)
            self.assertEqual(len(questions), 4, name)


RUNNER = PLUGIN_DIR / "tests" / "ab_gate.sh"


def extract_guard(text: str) -> str:
    """러너 안의 순수-python 가드 스니펫을 추출한다.

    문자열 검사만으로는 이 판정 로직의 세 판을 구분할 수 없다 — 실제로 돌린다.
    """
    start = text.index("python3 -c '")
    body = text[start + len("python3 -c '"):]
    return body[:body.index("\n'")]


class TestRunnerContract(unittest.TestCase):
    """AC40 · AC45① — 호출 형태 · cwd · 매니페스트 · bash 3.2 호환."""

    def setUp(self) -> None:
        self.text = RUNNER.read_text(encoding="utf-8")

    def test_command_is_namespaced(self) -> None:
        """AC40 — bare `/standup` 이면 red.

        `--plugin-dir` 환경에서 bare 이름은 `Unknown command` 가 되어 게이트
        5·6 이 **측정 자체를 못 하고**, 모델이 자연어로 대충 답한 것을 루브릭이
        판정하게 된다.
        """
        self.assertIn("/agent-transparency:standup", self.text)
        self.assertNotIn('"/standup"', self.text)

    def test_worker_runs_with_fixture_as_cwd(self) -> None:
        """AC45① — `cd "$FX"` 없이 호출하면 모델이 리포 루트를 편집할 수 있다."""
        self.assertIn('( cd "$FX" && claude -p', self.text)

    def test_effort_is_passed(self) -> None:
        self.assertIn('--effort "$AB_EFFORT"', self.text)

    def test_manifest_records_model_effort_and_cli_version(self) -> None:
        for field in ("model=$AB_MODEL", "effort=$AB_EFFORT",
                      "judge_model=$AB_JUDGE_MODEL", "judge_effort=$AB_JUDGE_EFFORT",
                      "claude=$(claude --version)"):
            self.assertIn(field, self.text)

    def test_required_env_vars_are_asserted(self) -> None:
        for var in ("AB_MODEL", "AB_EFFORT", "AB_JUDGE_MODEL", "AB_JUDGE_EFFORT"):
            self.assertIn(': "${%s:?}"' % var, self.text)

    def test_no_bash4_only_constructs(self) -> None:
        """D1 — 이 기계의 bash 는 3.2 뿐이다. bash 4 전용 구문이 있으면
        머지 게이트가 **한 번도 못 돈다**."""
        for construct in ("mapfile", "readarray", "declare -A", "${BASH_VERSINFO"):
            self.assertNotIn(construct, self.text)

    def test_fixture_path_is_physical(self) -> None:
        """D2 — mktemp 는 심볼릭 경로를 준다. 정규화하지 않으면 슬러그가 어긋나
        `/standup` 이 0 파일을 보고 게이트 5a·5b 가 매 실행 실패한다."""
        self.assertIn('pwd -P', self.text)

    def test_out_dir_is_per_run_and_not_wiped(self) -> None:
        """「계측을 고쳐도 되는 조건」 규칙 1이 out/ 보존을 요구한다."""
        self.assertIn('OUT="$PD/tests/out/$RUN"', self.text)
        self.assertNotIn('rm -rf "$OUT"', self.text)

    def test_visible_tests_run_by_fixed_modules_not_discover(self) -> None:
        """discover 는 tests/ 전체를 잡으므로 모델이 추가한 테스트가 게이트 2에
        들어온다 — 해시 좌변은 추가를 못 잡는다."""
        self.assertIn("unittest tests.test_calc tests.test_calc_negative", self.text)

    def test_setup_failure_leaves_a_line_for_task_e(self) -> None:
        """(d)/on 셋업이 죽으면 (e) 실행이 안 생겨 5a·5b 의 분모가 조용히 2가 된다."""
        self.assertIn("setup=skipped", self.text)


class TestAssignedArtifactsExist(unittest.TestCase):
    """AC47 의 나머지 절 — 배정된 산출물이 **실제로 존재하는가**.

    Task 9 가 아니라 여기 있는 이유: 이 assertion 의 대상인 `tests/ab_gate.sh` 가
    이 task 에서 생긴다. Task 9 에 두면 Task 9·10 이 red 로 끝난다.
    """

    def test_every_assigned_path_exists(self) -> None:
        text = REFERENCE.read_text(encoding="utf-8")
        assigned = {}
        for line in section(text, "AC ↔ 검증 산출물").splitlines():
            match = ASSIGN_ROW.match(line)
            if match and match.group(1) != "AC":
                assigned[match.group(1)] = match.group(2).strip()
        # 하한의 목적은 개수 단언이 아니라 파서 사망 감지다 — 위
        # TestCoverageLedger.test_lists_are_non_trivial 의 주석 참조.
        self.assertGreaterEqual(len(assigned), 25)
        for ac, target in assigned.items():
            if target.startswith("없음"):
                continue
            for path in [p.strip().strip("`") for p in target.split("·")]:
                self.assertTrue((PLUGIN_DIR / path).exists(), "%s → %s" % (ac, path))


class TestPluginStateGuard(unittest.TestCase):
    """AC45② — 12개 입력 형태를 계약대로 판정한다.

    통과해야 하는 넷과 멈춰야 하는 여덟이 정확히 갈려야 한다(아래 CASES 표
    라벨 집계와 일치 — M1: "셋과 아홉"은 CASES 표와 모순되는 stale 한 수치였다).
    이 판정 로직은 설계 과정에서 **세 판 연속 틀렸고 문자열 검사로는 세 판이
    구분되지 않았다** — 매번 실행이 잡았다.
    """

    PASS = "pass"
    STOP = "stop"
    CASES = [
        ("미설치(빈 목록)", "[]", PASS),
        ("다른 플러그인만 활성",
         '[{"id": "other@devbrew", "enabled": true}]', PASS),
        ("대상 비활성",
         '[{"id": "agent-transparency@devbrew", "enabled": false}]', PASS),
        ("대상 활성",
         '[{"id": "agent-transparency@devbrew", "enabled": true}]', STOP),
        ("비활성과 활성 공존",
         '[{"id": "agent-transparency@a", "enabled": false},'
         ' {"id": "agent-transparency@b", "enabled": true}]', STOP),
        ("enabled 키 부재",
         '[{"id": "agent-transparency@devbrew"}]', STOP),
        ("접두사만 같은 다른 이름",
         '[{"id": "agent-transparency-extra@devbrew", "enabled": true}]', PASS),
        ("JSON 파손", "{ not json", STOP),
        ("리스트가 아님", '{"id": "agent-transparency@d", "enabled": false}', STOP),
        ("enabled 가 문자열",
         '[{"id": "agent-transparency@d", "enabled": "true"}]', STOP),
        ("enabled 가 정수",
         '[{"id": "agent-transparency@d", "enabled": 1}]', STOP),
        ("enabled 가 null",
         '[{"id": "agent-transparency@d", "enabled": null}]', STOP),
    ]

    def setUp(self) -> None:
        self.guard = extract_guard(RUNNER.read_text(encoding="utf-8"))

    def run_guard(self, payload: str) -> int:
        proc = subprocess.run([sys.executable, "-c", self.guard],
                              input=payload.encode("utf-8"),
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return proc.returncode

    def test_twelve_fixtures_split_exactly_four_and_eight(self) -> None:
        # M1: CASES 자체를 세어 보면 PASS 라벨이 4개(미설치·다른 플러그인
        # 활성·대상 비활성·접두사만 같은 이름), STOP 라벨이 8개다 — 모두 가드의 문서화된
        # 설계 의도(정확 id 매치·bool 타입 검사·리스트 타입 검사)와 일치한다. 위 루프의
        # per-case assertEqual 이 12개 전부를 통과하는 한(즉 가드가 각 케이스의 라벨과
        # 정확히 일치하는 한) 총합은 산술적으로 4/8 일 수밖에 없다 — "3/9" 로 두면 가드를
        # 어떻게 고쳐도(라벨과 어긋나지 않는 한) 이 테스트는 항상 fail 한다. 3/9 는 이
        # CASES 표(와 스펙 §9 AC45, docs/superpowers/specs/2026-08-05-agent-transparency-design.md)
        # 와 모순되는 stale 한 수치였다 — 메서드 이름·spec 서술 둘 다 4/8 로 고쳤다(가드 로직은 무변경).
        outcomes = []
        for name, payload, expected in self.CASES:
            rc = self.run_guard(payload)
            actual = self.PASS if rc == 0 else self.STOP
            outcomes.append(actual)
            self.assertEqual(actual, expected, "%s → rc=%d" % (name, rc))
        self.assertEqual(outcomes.count(self.PASS), 4)
        self.assertEqual(outcomes.count(self.STOP), 8)

    def test_non_bool_enabled_is_not_treated_as_disabled(self) -> None:
        """`"true"`(문자열)가 `is True` 에도 `키 부재` 검사에도 안 걸려
        **활성인 채로 통과**하던 결함 — bool 검사를 앞에 두어 닫았다."""
        self.assertNotEqual(
            self.run_guard('[{"id": "agent-transparency@d", "enabled": "true"}]'), 0)


JUDGE = PLUGIN_DIR / "tests" / "ab_judge.py"


def load_judge():
    import importlib.util
    spec = importlib.util.spec_from_file_location("ab_judge", JUDGE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class TestDenominator(unittest.TestCase):
    """판정 단계 1 — **3/3 의 분모는 언제나 3이다.**

    셋업 실패로 실행이 통째로 건너뛰어지면 존재하는 것만 훑는 판정이 2/2 를
    3/3 처럼 읽는다.
    """

    def setUp(self) -> None:
        self.judge = load_judge()

    def test_expected_runs_is_twentyseven(self) -> None:
        runs = self.judge.expected_runs()
        self.assertEqual(len(runs), 27)
        self.assertIn(("on", "e", 3), runs)
        self.assertNotIn(("off", "e", 1), runs)

    def test_missing_combination_counts_as_fail(self) -> None:
        parsed = self.judge.parse_index("on a 1 sid-1 worker_rc=0\n")
        self.assertTrue(self.judge.is_failed(parsed, ("on", "a", 2)))

    def test_nonzero_worker_rc_counts_as_fail(self) -> None:
        parsed = self.judge.parse_index("on a 1 sid-1 worker_rc=2\n")
        self.assertTrue(self.judge.is_failed(parsed, ("on", "a", 1)))

    def test_setup_failed_line_has_no_worker_rc_and_fails(self) -> None:
        """`worker_rc=` 필드 자체가 없는 줄도 fail 이다."""
        parsed = self.judge.parse_index("on d 1 sid-1 setup=failed\n")
        self.assertTrue(self.judge.is_failed(parsed, ("on", "d", 1)))

    def test_snapshot_ambiguous_counts_as_fail(self) -> None:
        parsed = self.judge.parse_index("on e 1 snapshot=ambiguous(2)\n")
        self.assertTrue(self.judge.is_failed(parsed, ("on", "e", 1)))


class TestVoteParsing(unittest.TestCase):
    """판정자 호출 규약 — 관대하게 읽으면 판정자가 형식을 어길수록 통과하기 쉬워진다."""

    def setUp(self) -> None:
        self.judge = load_judge()

    def test_well_formed_vote(self) -> None:
        parsed = self.judge.parse_vote('{"Q1":"yes","Q2":"yes","Q3":"no","Q4":"yes"}')
        self.assertEqual(parsed, {"Q1": "yes", "Q2": "yes", "Q3": "no", "Q4": "yes"})

    def test_malformed_inputs_all_become_no(self) -> None:
        for raw in ('not json',
                    '{"Q1":"yes","Q2":"yes","Q3":"yes"}',            # 문항 누락
                    '{"Q1":"yes","Q2":"yes","Q3":"yes","Q4":"yes","Q5":"yes"}',  # 추가 키
                    '{"Q1":"maybe","Q2":"yes","Q3":"yes","Q4":"yes"}',           # 값 위반
                    '{"Q1":"yes","Q1":"no","Q2":"yes","Q3":"yes","Q4":"yes"}',   # 중복 키
                    'yes yes yes yes',
                    ''):
            parsed = self.judge.parse_vote(raw)
            self.assertEqual(set(parsed.values()), {"no"}, raw)

    def test_tally_requires_all_questions_yes(self) -> None:
        yes = {"Q1": "yes", "Q2": "yes", "Q3": "yes", "Q4": "yes"}
        mixed = {"Q1": "yes", "Q2": "no", "Q3": "yes", "Q4": "yes"}
        self.assertTrue(self.judge.tally([yes, yes, mixed]))    # Q2 는 2/3 yes
        self.assertFalse(self.judge.tally([yes, mixed, mixed]))  # Q2 가 2/3 no


class TestAskJudgeTimeout(unittest.TestCase):
    """M8 — 판정자 호출(`claude -p`)이 hang 하면 머지 게이트가 영원히 막힌다.

    timeout 만료는 파싱 실패와 같은 취급이어야 한다 — fail-closed 로 그 표를
    전부 `no` 로 계산한다(다른 오류 경로와 일관).
    """

    def setUp(self) -> None:
        self.judge = load_judge()

    def test_run_is_called_with_a_bounded_timeout(self) -> None:
        with mock.patch.object(self.judge.subprocess, "run") as run:
            run.return_value = subprocess.CompletedProcess(
                args=["claude"], returncode=0,
                stdout=b'{"Q1":"yes","Q2":"yes","Q3":"yes","Q4":"yes"}')
            self.judge.ask_judge("rubric", "block", "model", "low")
        self.assertIn("timeout", run.call_args.kwargs)
        self.assertGreater(run.call_args.kwargs["timeout"], 0)

    def test_timeout_expiry_counts_as_no_vote(self) -> None:
        with mock.patch.object(
                self.judge.subprocess, "run",
                side_effect=self.judge.subprocess.TimeoutExpired(cmd=["claude"], timeout=1)):
            vote = self.judge.ask_judge("rubric", "block", "model", "low")
        self.assertEqual(set(vote.values()), {"no"})


class TestSpanCutting(unittest.TestCase):
    """판정 구간 — "텍스트 블록을 담은"이 load-bearing 이다.

    어시스턴트 레코드는 text·thinking·tool_use 중 하나만 담는 경우가 많아
    순진한 정의는 3분의 2 확률로 텍스트 없는 레코드에 착지한다.
    """

    def setUp(self) -> None:
        self.judge = load_judge()

    @staticmethod
    def records():
        def assistant(items, **kw):
            base = {"type": "assistant", "message": {"content": items}}
            base.update(kw)
            return base
        return [
            assistant([{"type": "text", "text": "before"}]),
            assistant([{"type": "tool_use", "name": "Agent", "id": "a1"}]),
            {"type": "user", "message": {"content": [
                {"type": "tool_result", "tool_use_id": "a1", "content": "…"}]}},
            assistant([{"type": "thinking", "thinking": "…"}]),      # 건너뛴다
            assistant([{"type": "tool_use", "name": "Read", "id": "r1"}]),  # 건너뛴다
            assistant([{"type": "text", "text": "이 에이전트가 X를 찾았다"}]),
        ]

    def test_gate3_skips_text_less_records(self) -> None:
        span = self.judge.span_after_tool(self.records(), "Agent")
        self.assertEqual(span, "이 에이전트가 X를 찾았다")

    def test_empty_span_is_a_failure_not_a_pass(self) -> None:
        self.assertEqual(self.judge.span_after_tool([], "Agent"), "")


class TestGate1Span(unittest.TestCase):
    """I1 — 게이트 1은 게이트 6의 전체-텍스트 구간(`span_all_text`)이 아니라
    **최종 응답만** 본다. 게이트 표(*"최종 응답이 존재하고 … 그 안에"*)와
    REFERENCE.md 판정 구간 표(게이트 1이 의도적으로 빠져 있다 — 게이트 표
    자체가 유일한 정의)가 그 근거다.
    """

    def setUp(self) -> None:
        self.judge = load_judge()

    @staticmethod
    def assistant(items):
        return {"type": "assistant", "message": {"content": items}}

    def test_intermediate_table_does_not_fail_gate1(self) -> None:
        """중간 메시지에 표가 있어도 최종 응답에 없으면 게이트 1은 통과다."""
        records = [
            self.assistant([{"type": "text",
                             "text": "중간 결과\n| a | b |\n|---|---|"}]),
            self.assistant([{"type": "text", "text": "최종 응답 — 표 없음"}]),
        ]
        self.assertEqual(
            self.judge.final_response(records), "최종 응답 — 표 없음")
        self.assertTrue(self.judge.gate1_ok(records))

    def test_final_response_table_fails_gate1(self) -> None:
        """역방향 — 최종 응답 자체에 표가 있으면 fail 이어야 한다."""
        records = [
            self.assistant([{"type": "text", "text": "중간 설명, 표 없음"}]),
            self.assistant([{"type": "text",
                             "text": "결과\n| a | b |\n|---|---|"}]),
        ]
        self.assertFalse(self.judge.gate1_ok(records))

    def test_no_final_response_fails_gate1(self) -> None:
        """최종 응답 자체가 없으면(텍스트 블록 0개) fail — "부재" 조건."""
        self.assertEqual(self.judge.final_response([]), "")
        self.assertFalse(self.judge.gate1_ok([]))


class TestRubricLoading(unittest.TestCase):
    """루브릭은 REFERENCE.md 에서 읽는다 — 코드에 사본을 박으면 정본이 둘이 된다."""

    def setUp(self) -> None:
        self.judge = load_judge()
        self.reference = REFERENCE.read_text(encoding="utf-8")

    def test_prefix_line_is_prepended_to_every_rubric(self) -> None:
        for letter in "ABCD":
            block = self.judge.load_rubric(self.reference, letter)
            self.assertIn('{"Q1":"yes"', block.splitlines()[0])
            self.assertEqual(len(re.findall(r"(?m)^Q[1-4]\.", block)), 4, letter)

    def test_prompt_excludes_document_internal_commentary(self) -> None:
        """루브릭 C 리뷰에서 실측 — 절 전체를 본문으로 삼으면 사람용 산문
        (markdown 링크·"여기서는 반복하지 않는다" 같은 문서-내부 주석)이
        판정자 프롬프트에 새어 들어간다. 펜스가 그 경계를 강제하는지 고정한다.

        누군가 나중에 주석을 다시 펜스 **안**으로 옮기면 이 테스트가 RED 여야
        한다 — 문서 본문에 이 주석이 있는지가 아니라 **조립된 프롬프트에**
        섞였는지를 재는 것이 이 락의 이빨이다.
        """
        for letter in "ABCD":
            block = self.judge.load_rubric(self.reference, letter)
            self.assertNotIn("](#", block, letter)               # markdown 링크 문법
            self.assertNotIn("두 블록", block, letter)             # 루브릭 C 산문 특유 문구
            self.assertNotIn("여기서는 반복하지 않는다", block, letter)  # 사람 독자 대상 문구
            self.assertNotIn("판정자에게 그대로 보내는 블록은", block, letter)  # 경계 안내문 자체


if __name__ == "__main__":
    unittest.main()
