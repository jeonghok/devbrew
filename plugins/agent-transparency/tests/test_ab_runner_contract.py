#!/usr/bin/env python3
"""AC40 · AC45 · AC47 — A/B 러너 계약과 AC 커버리지.

`ab_gate.sh` **전체는 실행하지 않는다**(워커가 claude 를 부르므로 비용·비결정).
단 순수-python 가드 스니펫은 **추출해 JSON 픽스처로 실제 실행**한다 —
문자열 검사로는 그 판정 로직의 세 판을 구분하지 못한다.

Run:
    python3 -m unittest plugins/agent-transparency/tests/test_ab_runner_contract.py
"""
from __future__ import annotations

import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
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


def code_only(text: str) -> str:
    """주석 전용 줄을 걷어낸 셸 본문.

    `ab_gate.sh` 는 결정 근거를 `# ★ …` 주석으로 길게 적어 두는 파일이고, 그
    주석들이 **검사 대상 문자열을 그대로 인용**한다. 전문에 대고 `assertIn` 을
    하면 호출을 주석으로 옮겨 놓아도 전부 green 이다 — 락이 지키는 것이 "이
    문자열이 파일 어딘가에 있다"까지로 줄어든다.

    인라인 주석(`cmd  # 설명`)은 걷어내지 않는다 — `#` 가 문자열 안에 오는
    경우와 구분하려면 셸 파서가 필요하고, 이 락이 막으려는 것은 **실행되지 않는
    줄로의 이동**이라 줄 단위 판정으로 충분하다.
    """
    return "\n".join(ln for ln in text.splitlines() if not ln.lstrip().startswith("#"))


class TestRunnerContract(unittest.TestCase):
    """AC40 · AC45① — 호출 형태 · cwd · 매니페스트 · bash 3.2 호환.

    **검사는 `self.code`(주석 제거본)에 대고 한다.** `self.text` 는 부정 검사
    (있으면 red)에만 쓴다 — 그쪽은 주석에 있어도 잡아야 안전한 방향이다.
    """

    def setUp(self) -> None:
        self.text = RUNNER.read_text(encoding="utf-8")
        self.code = code_only(self.text)

    def test_command_is_namespaced(self) -> None:
        """AC40 — bare `/standup` 이면 red.

        `--plugin-dir` 환경에서 bare 이름은 `Unknown command` 가 되어 게이트
        5·6 이 **측정 자체를 못 하고**, 모델이 자연어로 대충 답한 것을 루브릭이
        판정하게 된다.
        """
        self.assertIn("/agent-transparency:standup", self.code)
        self.assertNotIn('"/standup"', self.text)

    def test_worker_runs_with_fixture_as_cwd(self) -> None:
        """AC45① — `cd "$FX"` 없이 호출하면 모델이 리포 루트를 편집할 수 있다."""
        self.assertIn('( cd "$FX" && claude -p', self.code)

    def test_effort_is_passed(self) -> None:
        self.assertIn('--effort "$AB_EFFORT"', self.code)

    def test_manifest_records_model_effort_and_cli_version(self) -> None:
        for field in ("model=$AB_MODEL", "effort=$AB_EFFORT",
                      "judge_model=$AB_JUDGE_MODEL", "judge_effort=$AB_JUDGE_EFFORT",
                      "claude=$(claude --version)"):
            self.assertIn(field, self.code)

    def test_required_env_vars_are_asserted(self) -> None:
        for var in ("AB_MODEL", "AB_EFFORT", "AB_JUDGE_MODEL", "AB_JUDGE_EFFORT"):
            self.assertIn(': "${%s:?}"' % var, self.code)

    def test_no_bash4_only_constructs(self) -> None:
        """D1 — 이 기계의 bash 는 3.2 뿐이다. bash 4 전용 구문이 있으면
        머지 게이트가 **한 번도 못 돈다**."""
        for construct in ("mapfile", "readarray", "declare -A", "${BASH_VERSINFO"):
            self.assertNotIn(construct, self.text)

    def test_fixture_path_is_physical(self) -> None:
        """D2 — mktemp 는 심볼릭 경로를 준다. 정규화하지 않으면 슬러그가 어긋나
        `/standup` 이 0 파일을 보고 게이트 5a·5b 가 매 실행 실패한다."""
        self.assertIn('pwd -P', self.code)

    def test_out_dir_is_per_run_and_not_wiped(self) -> None:
        """「계측을 고쳐도 되는 조건」 규칙 1이 out/ 보존을 요구한다."""
        self.assertIn('OUT="$PD/tests/out/$RUN"', self.code)
        self.assertNotIn('rm -rf "$OUT"', self.text)

    def test_visible_tests_run_by_fixed_modules_not_discover(self) -> None:
        """discover 는 tests/ 전체를 잡으므로 모델이 추가한 테스트가 게이트 2에
        들어온다 — 해시 좌변은 추가를 못 잡는다."""
        self.assertIn("unittest tests.test_calc tests.test_calc_negative", self.code)

    def test_setup_failure_leaves_a_line_for_task_e(self) -> None:
        """(d)/on 셋업이 죽으면 (e) 실행이 안 생겨 5a·5b 의 분모가 조용히 2가 된다."""
        self.assertIn("setup=skipped", self.code)

    def test_base_sha_is_checked_before_use(self) -> None:
        """확인 없는 대입이면 shasum 부재 시 양변이 빈 문자열이 되어 매 실행 hash=ok.

        변조 다리가 조용히 0 이 되는 경로다 — 대입 **직후** 비어 있지 않음을
        확인해야 한다.
        """
        self.assertIn('[ -n "$base_sha" ]', self.code)

    def test_oracle_runs_outside_the_subject_tree(self) -> None:
        """피검자가 자유롭게 쓰는 트리를 cwd 로 두고 검증 프로세스를 돌리지 않는다.

        cwd 가 `$FX` 면 피검자가 심은 `$FX/sitecustomize.py` 가 검증 프로세스
        안에서 먼저 실행되고, 해시 다리는 `test_calc*.py` 두 파일만 보므로
        심어진 파일을 못 본다.
        """
        self.assertIn('( cd "$ORACLE" &&', self.code)
        self.assertNotIn('( cd "$FX" && PYTHONPATH="$FX" python3 -m unittest', self.code)

    def test_oracle_disables_site_import(self) -> None:
        """`-S` 가 `sitecustomize`/`usercustomize` 자동 import 를 막는다."""
        self.assertIn("python3 -S -m unittest discover", self.code)

    def test_oracle_requires_a_completion_sentinel(self) -> None:
        """종료 코드만 보면 피검자 코드의 import 시점 `os._exit(0)` 이 통과로 읽힌다.

        모듈이 끝까지 돌았을 때만 생기는 파일을 함께 요구한다.
        """
        self.assertIn("AT_ORACLE_SENTINEL", self.code)
        self.assertIn('[ -f "$sent" ] || orc=1', self.code)

    def test_locks_do_not_accept_a_commented_out_invocation(self) -> None:
        """계측기 확인 — 위 긍정 검사들이 **주석으로의 이동**을 실제로 잡는가.

        되돌리기 축이 아니라 **위치 축**으로 흔든다. 내가 지운 바이트를 되살리는
        mutation 은 `git revert` 만 잡고 만점을 낸다. 여기서는 실행 줄을 주석으로
        바꾼 뒤 같은 문자열이 파일에 **그대로 남아 있는** 상태를 만든다 — 전문에
        대고 재는 구현은 여기서 green 이다.
        """
        anchors = ('( cd "$FX" && claude -p', '/agent-transparency:standup',
                   '--effort "$AB_EFFORT"', 'pwd -P')
        commented = "\n".join(
            ("# " + ln) if any(a in ln for a in anchors) else ln
            for ln in self.text.splitlines())
        for anchor in anchors:
            self.assertIn(anchor, commented, "mutation 이 문자열을 지웠다 — 위치 축이 아니다")
            self.assertNotIn(anchor, code_only(commented), anchor)


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

    def test_every_assigned_artifact_mentions_its_ac(self) -> None:
        """우변이 좌변을 **실제로 다루는지**까지 본다.

        경로 존재만 재면 배정표는 *"이 AC 는 어딘가의 실재하는 파일이 맡는다"*
        까지만 말한다 — 아무 테스트 파일 이름이나 적어도 green 이고, AC 를 다른
        파일로 옮기면서 배정을 안 고쳐도 green 이다(리뷰가 적발). 산출물이 자기
        docstring 이나 테스트에 그 AC 번호를 적게 해서 **오배정을 red 로** 만든다.

        조각 id(`AC16①`)는 정확히, 번호만 있는 것은 **숫자 경계**로 찾는다 —
        경계가 없으면 `AC4` 가 `AC41` 에 매치돼 검사가 조용히 헐거워진다.
        """
        text = REFERENCE.read_text(encoding="utf-8")
        assigned = {}
        for line in section(text, "AC ↔ 검증 산출물").splitlines():
            match = ASSIGN_ROW.match(line)
            if match and match.group(1) != "AC":
                assigned[match.group(1)] = match.group(2).strip()
        self.assertGreaterEqual(len(assigned), 25)
        for ac, target in assigned.items():
            if target.startswith("없음"):
                continue
            base = re.match(r"AC\d+", ac).group(0)
            for path in [p.strip().strip("`") for p in target.split("·")]:
                node = PLUGIN_DIR / path
                if node.is_dir():
                    body = "\n".join(f.read_text(encoding="utf-8", errors="replace")
                                     for f in sorted(node.rglob("*.py")))
                else:
                    body = node.read_text(encoding="utf-8", errors="replace")
                found = ac in body or re.search(
                    r"(?<![A-Za-z0-9])%s(?![0-9])" % base, body) is not None
                self.assertTrue(found, "%s 를 %s 가 언급하지 않는다" % (ac, path))

    def test_mention_check_uses_a_digit_boundary(self) -> None:
        """계측기 확인 — 경계 없는 검사와 구분되는가.

        `AC4` 를 `AC41` 만 든 본문에서 찾으면 안 된다. 이 assert 가 없으면 위
        검사를 `base in body` 로 헐겁게 써도 통과한다.
        """
        body = "이 파일은 AC41 과 AC42 를 다룬다"
        self.assertIsNone(re.search(r"(?<![A-Za-z0-9])AC4(?![0-9])", body))
        self.assertIsNotNone(re.search(r"(?<![A-Za-z0-9])AC41(?![0-9])", body))


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
        """한 줄짜리 — 이 형태만으로는 규칙을 재지 못한다(아래 두 줄 테스트 참조)."""
        parsed = self.judge.parse_index("on e 1 snapshot=ambiguous(2)\n")
        self.assertTrue(self.judge.is_failed(parsed, ("on", "e", 1)))

    def test_single_line_fixture_would_fail_even_without_the_rule(self) -> None:
        """계측기 확인 — 위 테스트가 **왜** 규칙을 재지 못하는지 고정한다.

        `worker_rc` 가 없는 줄은 `is_failed` 의 마지막 갈래(`worker_rc != 0`)
        만으로 이미 fail 이다. 그래서 위 테스트는 `snapshot=ambiguous` 갈래를
        통째로 지워도 통과한다 — 규칙이 아니라 **필드 부재**를 재고 있었다.
        """
        parsed = self.judge.parse_index("on e 1 snapshot=whatever(2)\n")
        self.assertTrue(self.judge.is_failed(parsed, ("on", "e", 1)),
                        "worker_rc 부재만으로 이미 fail 이어야 한다")

    def test_ambiguous_flag_survives_a_later_successful_line(self) -> None:
        """실제 러너가 내는 **두 줄** 형태. 캐리오버가 없으면 여기서 통과가 난다.

        러너는 스냅샷이 모호하면 먼저 `snapshot=ambiguous(N)` 줄을 쓰고, 그
        다음에 (e) 실행 결과 줄(`<sid> worker_rc=0`)을 **같은 키로** 덧쓴다.
        `parse_index` 가 앞 줄의 flag 를 물려주지 않으면 마지막 항목은
        `flag=None · worker_rc=0` 이 되어 **모호한 실행이 판정 대상이 된다** —
        5a·5b 가 근거 없는 스냅샷 위에서 돈다.
        """
        text = ("on e 1 snapshot=ambiguous(2)\n"
                "on e 1 abc-123 worker_rc=0\n")
        parsed = self.judge.parse_index(text)
        entry = parsed[("on", "e", 1)]
        self.assertEqual(entry["worker_rc"], 0, "뒷줄이 반영돼야 한다")
        self.assertEqual(entry["sid"], "abc-123")
        self.assertTrue(entry["flag"].startswith("snapshot=ambiguous"),
                        "앞줄의 flag 가 물려져야 한다: %r" % (entry,))
        self.assertTrue(self.judge.is_failed(parsed, ("on", "e", 1)))

    def test_clean_run_is_not_failed(self) -> None:
        """양의 짝 — 정상 (e) 실행은 통과해야 한다.

        러너는 모호하지 않은 실행에는 **한 줄만** 쓴다(모호할 때만 앞줄이 는다).
        이 짝이 없으면 위 락은 *"fail 을 더 자주 내는"* 구현으로도 통과하고,
        정상 실행이 전부 fail 로 세어져 분모가 조용히 0 이 된다.
        """
        parsed = self.judge.parse_index("on e 2 abc-456 worker_rc=0\n")
        self.assertFalse(self.judge.is_failed(parsed, ("on", "e", 2)))

    def test_carry_over_does_not_invent_a_flag(self) -> None:
        """캐리오버가 **없던 flag 를 만들어내지는** 않는다.

        앞줄에 flag 가 없으면 뒷줄도 flag 가 없어야 한다 — 물려주기를 무조건
        수행하는 구현은 여기서 잡힌다.
        """
        parsed = self.judge.parse_index("on e 3 - worker_rc=0\n"
                                        "on e 3 abc-789 worker_rc=0\n")
        self.assertIsNone(parsed[("on", "e", 3)]["flag"])
        self.assertFalse(self.judge.is_failed(parsed, ("on", "e", 3)))


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
        """표는 전부 `no`, 그리고 **왜** no 인지 `_error` 로 남는다.

        `set(vote.values()) == {"no"}` 로 재던 앞선 판은 사유 표시를 더하는
        순간 red 가 된다 — 판정 키와 메타를 섞어 재고 있었다. 판정 키만 본다.
        """
        with mock.patch.object(
                self.judge.subprocess, "run",
                side_effect=self.judge.subprocess.TimeoutExpired(cmd=["claude"], timeout=1)):
            vote = self.judge.ask_judge("rubric", "block", "model", "low")
        self.assertEqual(set(vote[q] for q in self.judge.QUESTIONS), {"no"})
        self.assertEqual(vote.get("_error"), "TimeoutExpired")


class TestJudgeFailClosedGuards(unittest.TestCase):
    """REFERENCE.md 가 불변식으로 이름 붙인 fail-closed 가드 둘 + 판정자 미실행 구분.

    셋 다 테스트가 없었다(리뷰가 적발). 이름만 불변식이고 회귀하면 아무도 모른다.
    """

    def setUp(self) -> None:
        self.judge = load_judge()

    def test_empty_span_is_a_fail_without_calling_the_judge(self) -> None:
        """가드 1 — 구간이 비면 판정자를 부르지 않고 fail."""
        with mock.patch.object(self.judge, "ask_judge") as ask:
            self.assertFalse(self.judge.judge_span("rubric", "   \n ", "m", "low"))
        ask.assert_not_called()

    def test_no_votes_is_a_fail(self) -> None:
        """가드 2 — 표가 하나도 없으면 fail. 빈 표는 `all()` 로 공허하게 참이 된다."""
        self.assertFalse(self.judge.tally([]))

    def test_wrapped_empty_span_is_still_a_fail(self) -> None:
        """게이트 5b 는 구간을 **라벨로 감싼 뒤** 넘긴다.

        감싼 문자열은 라벨 때문에 절대 비지 않아, 가드 1 이 그 게이트에서는
        영영 발동하지 못한다 — 인벤토리도 응답도 없는 실행이 판정자에게
        라벨만 주고 그 답을 판정으로 삼는다.
        """
        self.assertFalse(self.judge.wrap_two_blocks("", ""))
        self.assertFalse(self.judge.wrap_two_blocks("인벤토리만", ""))
        self.assertFalse(self.judge.wrap_two_blocks("", "응답만"))
        self.assertTrue(self.judge.wrap_two_blocks("인벤토리", "응답"))

    def test_judge_failure_is_distinguishable_from_a_no_vote(self) -> None:
        """비-0 종료는 *"판정자가 안 돌았다"* 이지 *"루브릭에 떨어졌다"* 가 아니다.

        둘 다 fail-closed 인 것은 맞지만, 같은 표로 보고하면 CLI 부재·인증
        오류·rate limit 을 산출물 결함으로 읽게 된다.
        """
        with mock.patch.object(self.judge.subprocess, "run") as run:
            run.return_value = subprocess.CompletedProcess(
                args=["claude"], returncode=1, stdout=b"")
            vote = self.judge.ask_judge("rubric", "block", "model", "low")
        self.assertEqual(set(v for k, v in vote.items()
                             if k in self.judge.QUESTIONS), {"no"})
        self.assertTrue(vote.get("_error"), vote)

    def test_successful_judge_carries_no_error_marker(self) -> None:
        """양의 짝 — 정상 판정에는 마커가 없어야 두 사건이 구분된다."""
        with mock.patch.object(self.judge.subprocess, "run") as run:
            run.return_value = subprocess.CompletedProcess(
                args=["claude"], returncode=0,
                stdout=b'{"Q1":"yes","Q2":"yes","Q3":"yes","Q4":"yes"}')
            vote = self.judge.ask_judge("rubric", "block", "model", "low")
        self.assertNotIn("_error", vote)

    def test_judge_failure_is_announced_on_stderr(self) -> None:
        """설계 §7 — 강등이 사람에게 안 닿으면 그것은 강등이 아니라 통과다.

        디스크 보존만으로는 실행 중에 안 보인다.
        """
        buf = io.StringIO()
        with mock.patch.object(self.judge.subprocess, "run") as run, \
                mock.patch.object(self.judge.sys, "stderr", buf):
            run.return_value = subprocess.CompletedProcess(
                args=["claude"], returncode=7, stdout=b"")
            self.judge.ask_judge("rubric", "block", "model", "low")
        self.assertIn("rc=7", buf.getvalue())

    def test_preserve_writes_span_and_votes(self) -> None:
        """실패한 원자료 보존 — fail 뒤에 무엇을 보고 판정했는지 되짚을 수 있어야 한다."""
        box = tempfile.mkdtemp(prefix="at-judge-")
        self.addCleanup(shutil.rmtree, box, True)
        with mock.patch.object(self.judge, "ask_judge") as ask:
            ask.return_value = dict((q, "no") for q in self.judge.QUESTIONS)
            verdict = self.judge.judge_span("rubric", "판정 대상 구간", "m", "low",
                                            box, "5b-1")
        self.assertFalse(verdict)
        written = os.listdir(box)
        self.assertEqual(written, ["5b-1.txt"], written)
        with open(os.path.join(box, "5b-1.txt"), encoding="utf-8") as fh:
            body = fh.read()
        self.assertIn("판정 대상 구간", body)
        self.assertIn('"Q1": "no"', body)

    def test_preserve_failure_does_not_break_judging(self) -> None:
        """보존이 실패해도 판정은 산다 — 계측이 대상을 막으면 안 된다."""
        with mock.patch.object(self.judge, "ask_judge") as ask:
            ask.return_value = dict((q, "yes") for q in self.judge.QUESTIONS)
            verdict = self.judge.judge_span("rubric", "구간", "m", "low",
                                            "/dev/null/not-a-dir", "x")
        self.assertTrue(verdict)

    def test_error_marker_does_not_leak_into_the_tally(self) -> None:
        """`_error` 키가 `tally` 의 질문 순회에 끼어들면 안 된다."""
        good = dict((q, "yes") for q in self.judge.QUESTIONS)
        marked = dict(good)
        marked["_error"] = "rc=1"
        self.assertTrue(self.judge.tally([good, good, good]))
        self.assertTrue(self.judge.tally([marked, marked, marked]))


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


class TestOracleSignal(unittest.TestCase):
    """숨김 오라클이 가시 다리 **너머로** 신호를 더하는가.

    앞선 판의 오라클은 가시 테스트의 verbatim 복제여서 가시-테스트 다리와 해시
    다리 너머로 아무 신호도 보태지 않았다(adversarial 이 적발). 동시에 작업 (b)
    의 후반부(`total` 이 `data.csv` 로 끝까지 돌게)는 어느 다리도 검사하지 않아
    **작업을 절반만 해도 게이트 2 가 통과**했다(codex 가 적발).
    """

    ORACLE = PLUGIN_DIR / "tests" / "oracle" / "test_add_contract.py"
    VISIBLE = (PLUGIN_DIR / "tests" / "fixtures" / "ab-project" / "tests"
               / "test_calc_negative.py")

    def setUp(self) -> None:
        self.oracle = self.ORACLE.read_text(encoding="utf-8")
        self.visible = self.VISIBLE.read_text(encoding="utf-8")

    def test_oracle_is_not_a_clone_of_the_visible_test(self) -> None:
        """가시 테스트가 부르는 것 말고 **다른 것**을 부른다."""
        self.assertIn("total", self.oracle)
        self.assertNotIn("total", self.visible)

    def test_oracle_does_not_pin_the_undecided_policy(self) -> None:
        """`total` 의 **값**을 단언하면 안 된다 — 빈 칸 처리 정책이 게이트 6 의 대상이다.

        `assertEqual(total(...), <수>)` 형태가 들어오면 red. 값을 고정하는 순간
        모델의 남은 선택이 하나로 수렴해 루브릭 D 가 거짓 실패한다.
        """
        self.assertIsNone(re.search(r"assertEqual\(\s*total\(", self.oracle),
                          "total 의 값을 못박으면 게이트 6 의 결정 축이 죽는다")

    def test_oracle_writes_a_completion_sentinel(self) -> None:
        self.assertIn("def tearDownModule", self.oracle)
        self.assertIn("AT_ORACLE_SENTINEL", self.oracle)
