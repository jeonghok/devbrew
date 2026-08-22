#!/usr/bin/env python3
"""AC40 · AC45 · AC47 — A/B 러너 계약과 AC 커버리지.

`ab_gate.sh` **전체는 실행하지 않는다**(워커가 claude 를 부르므로 비용·비결정).
단 순수-python 가드 스니펫은 **추출해 JSON 픽스처로 실제 실행**한다 —
문자열 검사로는 그 판정 로직의 세 판을 구분하지 못한다.

Run:
    python3 -m unittest plugins/agent-transparency/tests/test_ab_runner_contract.py
"""
from __future__ import annotations

import ast
import contextlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
import uuid
from pathlib import Path
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parents[3]
PLUGIN_DIR = REPO_ROOT / "plugins" / "agent-transparency"
REFERENCE = PLUGIN_DIR / "REFERENCE.md"

AC_ROW = re.compile(r"^\s*-\s+(AC\d+(?:[①②③④⑤⑥])?)\s*$")
ASSIGN_ROW = re.compile(r"^\|\s*(AC\d+(?:[①②③④⑤⑥])?)\s*\|\s*([^|]+?)\s*\|")
OQ_ROW = re.compile(r"^\s*-\s+(OQ-[A-Z]+)\s*(?:—|$)")


def mentions_ac(body: str, ac: str) -> bool:
    """산출물 본문이 그 AC 를 언급하는가 — **조각 id 는 정확 매치만.**

    프로덕션 술어를 한 곳에 둔다. 계측기 테스트가 이 함수를 직접 부르므로,
    여기를 헐겁게 고치면 계측기가 red 가 된다(로컬 리터럴에 술어를 재구현하던
    앞선 판은 그 성질이 없었다 — 리뷰가 G3 로 적발).

    번호만 있는 id 는 **숫자 경계**로 찾는다 — 경계가 없으면 `AC4` 가 `AC41` 에
    매치돼 검사가 조용히 헐거워진다. 조각 id(`AC16①`)에 `or <번호 매치>` 를
    붙이면 조각이 언제나 번호로 만족돼 조각 단위 커버리지가 죽는다(G5).
    """
    base = re.match(r"AC\d+", ac)
    if base is None:
        return ac in body
    if ac != base.group(0):                      # 조각 id
        return ac in body
    return re.search(r"(?<![A-Za-z0-9])%s(?![0-9])" % ac, body) is not None


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

    # 배정된 **산출물이 실제로 존재하는지**와 **그 산출물이 그 AC 를 실제로 다루는지**는
    # `TestAssignedArtifactsExist` 가 본다. 여기서는 배정표의 **좌변 집합**만 잠근다.

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


# `tests/harness/` 에 있다 — 회귀 러너와 `/plugin-audit` 수집기가 둘 다 그 디렉토리를
# 제외하기 때문이다. 이 파일은 러너를 **실행하지 않고 읽기만** 하므로 위치와 무관하지만,
# 경로 리터럴이라 이동하면 여기도 같이 고쳐야 한다.
RUNNER = PLUGIN_DIR / "tests" / "harness" / "ab_gate.sh"


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
        """다섯 필드가 매니페스트에 실린다.

        CLI 버전은 **접두사로** 잰다 — 값을 못 구했을 때의 대체 문구까지 리터럴로
        박으면, 그 대체 경로를 더하는 것만으로 락이 red 가 된다(실제로 그랬다).
        재는 것은 *"이 필드를 기록한다"* 이지 그 표현식의 전문이 아니다.
        """
        for field in ("model=$AB_MODEL", "effort=$AB_EFFORT",
                      "judge_model=$AB_JUDGE_MODEL", "judge_effort=$AB_JUDGE_EFFORT",
                      "claude=$(claude --version"):
            self.assertIn(field, self.code)

    def test_manifest_records_a_placeholder_when_a_value_is_missing(self) -> None:
        """매니페스트는 *"이 측정이 무엇에서 나왔나"* 의 유일한 기록이다.

        빈 문자열을 박으면 **어떤 버전에서 돌았는지 모른다**는 사실 자체가
        사라진다 — 빈 값과 "안 적힌 값" 이 구분되지 않는다.
        """
        self.assertIn("(구하지 못함)", self.code)

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
        self.assertIn('OUT="$OUT_ROOT/$RUN"', self.code)
        self.assertNotIn('rm -rf "$OUT"', self.text)

    def test_out_dir_is_outside_the_tree_handed_to_the_subject(self) -> None:
        """산출물이 `$PD` 안에 있으면 판정의 근거를 피검체가 쥔다.

        앞선 판은 `$PD/tests/out/$RUN` 이었고, `$PD` 는 켠 조건에서 `--plugin-dir`
        로 통째로 건네졌으며 `tests/out/latest` 가 현재 RUN 을 광고했다 —
        `tests.txt` 에 줄을 덧붙이는 것만으로 게이트 2 의 세 다리가 전부 뒤집혔다
        (2026-08-15 리뷰가 재현). 판정 원장은 피검체가 이름을 아는 트리 밖에 산다.
        """
        self.assertNotIn('$PD/tests/out', self.code)
        self.assertIn("OUT_ROOT=", self.code)

    def test_visible_tests_run_by_fixed_modules_not_discover(self) -> None:
        """discover 는 tests/ 전체를 잡으므로 모델이 추가한 테스트가 게이트 2에
        들어온다 — 해시 좌변은 추가를 못 잡는다."""
        self.assertIn("tests.test_calc tests.test_calc_negative", self.code)
        self.assertNotIn("unittest discover", self.code)

    def test_setup_failure_leaves_a_line_for_task_e(self) -> None:
        """(d)/on 셋업이 죽으면 (e) 실행이 안 생겨 5a·5b 의 분모가 조용히 2가 된다."""
        self.assertIn("setup=skipped", self.code)

    def test_base_sha_is_checked_before_use(self) -> None:
        """확인 없는 대입이면 shasum 부재 시 양변이 빈 문자열이 되어 매 실행 hash=ok.

        변조 다리가 조용히 0 이 되는 경로다 — 대입 **직후** 비어 있지 않음을
        확인해야 한다.
        """
        self.assertIn('[ -n "$base_sha" ]', self.code)

    def test_verification_runs_outside_the_subject_tree(self) -> None:
        """피검자가 자유롭게 쓰는 트리를 cwd 로 두고 검증 프로세스를 돌리지 않는다.

        cwd 가 `$FX` 면 피검자가 심은 `$FX/sitecustomize.py` 가 검증 프로세스
        안에서 먼저 실행되고, 해시 다리는 `test_calc*.py` 두 파일만 보므로
        심어진 파일을 못 본다.
        """
        self.assertIn('( cd "$VER" &&', self.code)
        self.assertNotIn('( cd "$FX" && PYTHONPATH="$FX" python3 -m unittest', self.code)

    def test_verification_runs_from_a_throwaway_copy(self) -> None:
        """검증 사본은 **다리마다 새로** 만든다 — `$PD/tests/` 에서 돌리지 않는다.

        드라이버의 `__file__` 은 피검체 코드가 한 줄로 읽는 값이고(그 코드는 검증
        프로세스 **안에서** 돈다), 그것이 `$PD/tests/…` 이면 곧 신뢰 기반의
        주소다. 사본을 다리 사이에 재사용해도 같은 구멍이 난다 — 가시 다리에서
        경로를 알아낸 피검체가 오라클 파일을 자기 것으로 갈아 끼운다.
        """
        self.assertIn('VER="$(mktemp -d)"', self.code)
        self.assertIn('cp "$TRUST/ab_driver.py" "$VER/"', self.code)
        self.assertNotIn('python3 "$PD/tests/ab_driver.py" run', self.code)

    def test_verification_disables_env_and_site_import(self) -> None:
        """`-I` 가 `PYTHONPATH` 를, `-S` 가 `sitecustomize` 자동 import 를 막는다.

        둘 다 필요하다 — `-I` 만으로는 `site` 가 여전히 돌고, `-S` 만으로는
        피검체가 심은 트리가 `PYTHONPATH` 로 들어온다. 드라이버는 `sys.path` 를
        스스로 조립하므로 두 경로 다 필요 없다.
        """
        self.assertIn("python3 -I -S ./ab_driver.py run", self.code)

    def test_completion_sentinel_is_owned_by_the_runner_not_the_subject(self) -> None:
        """종료 코드만 보면 피검자 코드의 import 시점 `os._exit(0)` 이 통과로 읽힌다.

        모듈이 끝까지 돌았을 때만 생기는 파일을 함께 요구한다. **그 경로는
        stdin 으로만 건넨다** — 앞선 판은 `AT_ORACLE_SENTINEL` 환경변수로 넘겼고,
        오라클은 정의상 피검체 코드를 import 하므로 피검체가 그 한 줄을 읽어
        자기가 써 놓고 `_exit(0)` 할 수 있었다(2026-08-15 리뷰가 재현).
        """
        self.assertIn('[ -f "$leg_sent" ] || leg_rc=1', self.code)
        self.assertIn("""printf '%s\\n' "$leg_sent" \\""", self.code)
        self.assertNotIn("AT_ORACLE_SENTINEL", self.text)

    def test_worker_is_given_a_permission_mode(self) -> None:
        """권한 플래그가 없으면 헤드리스 워커는 **아무것도 못 쓰면서 rc=0** 을 낸다.

        2026-08-15 실측(같은 과업·네 변형): 플래그 없음 → rc=0·편집 차단,
        `--permission-mode acceptEdits` → rc=0·편집 허용,
        `--dangerously-skip-permissions` → rc=0·편집 허용. 즉 앞선 판에서는
        편집 과업 (a)·(b) 가 **아무 일도 일어나지 않은 채** "완료" 로 끝났고,
        게이트 2 는 구조적으로 통과 불가였다 — 측정이 무엇도 재지 않는다.
        이 락이 없으면 그 상태가 조용히 돌아온다.

        음의 검사만 이 클래스의 관례(`self.text`)와 달리 `self.code` 에 댄다 —
        러너는 **기각한 대안을 이름으로 적어 두고**, 그 기록을 지우는 것보다
        실행되는 줄에 대고 재는 편이 정확하다. 인라인 주석으로의 이동은 `code_only`
        가 걷어내지 않으므로 여전히 잡힌다.
        """
        self.assertIn("--permission-mode acceptEdits", self.code)
        self.assertNotIn("--dangerously-skip-permissions", self.code)

    def test_subject_gets_a_plugin_copy_not_the_original(self) -> None:
        """원본을 건네면 피검체가 자기 채점 기준을 쓸 수 있다.

        `REFERENCE.md` 는 루브릭 **원본**이고, 루브릭은 판정 프롬프트에서 데이터
        경계 **밖**(지시 위치)에 들어간다(`ab_judge.build_judge_prompt`). 원본
        트리를 `--plugin-dir` 로 주면 피검체가 그 파일도, 숨김 오라클도, 판정
        스크립트도 고칠 수 있다(2026-08-15 리뷰가 적발).
        """
        self.assertIn('--plugin-dir "$PLUG"', self.code)
        self.assertNotIn('--plugin-dir "$PD"', self.code)
        self.assertIn('rm -rf "$PLUG/tests" "$PLUG/REFERENCE.md"', self.code)

    def test_trust_base_is_sealed_before_and_verified_after_every_iteration(self) -> None:
        """사본은 *"건네받은 경로를 고치는"* 길만 막는다 — 나머지는 탐지한다.

        피검체 코드는 검증 프로세스 안에서 사용자 권한으로 도니까 파일시스템을
        훑어 `$PD` 를 찾아낼 수 있다. 그것을 막을 수는 없고, **바뀌었다는 사실**을
        잡아 측정을 중단할 수는 있다. 봉인은 첫 반복 **전에** 뜨고 매 반복 뒤와
        판정 직전에 다시 맞춰 본다 — 판정 스크립트 자신이 봉인 대상 안에 있으므로
        마지막 확인이 없으면 바뀐 판정자로 판정하게 된다.
        """
        self.assertIn('seal="$(python3 "$TRUST/ab_seal.py" seal "$PD")"', self.code)
        self.assertEqual(
            self.code.count('ab_seal.py" verify "$PD" "$seal"'), 2,
            "봉인 확인은 반복마다 한 번 · 판정 직전 한 번, 모두 두 곳이어야 한다")

    def test_the_positive_locks_actually_consume_the_code_view(self) -> None:
        """계측기 확인 — 위 긍정 검사들이 **주석으로의 이동**을 실제로 잡는가.

        되돌리기 축이 아니라 **위치 축**으로 흔든다. 내가 지운 바이트를 되살리는
        mutation 은 `git revert` 만 잡고 만점을 낸다. 여기서는 실행 줄을 주석으로
        바꾼 뒤 같은 문자열이 파일에 **그대로 남아 있는** 상태를 만든다.

        앞선 판은 그 상태를 만들어 놓고 `code_only()` **자신**이 주석을 벗기는지만
        확인했다 — 구성상 참인 테스트라, 긍정 검사 하나를 `self.code` 에서
        `self.text` 로 되돌려도 GREEN 이었다(리뷰가 G4 로 적발). 재려던 것은
        *"`code_only` 가 동작한다"* 가 아니라 *"긍정 검사들이 그것을 소비한다"* 다.
        그래서 검사들을 **변이한 본문 위에서 직접 실행**해 red 가 나는지 본다.
        """
        anchors = {
            "test_worker_runs_with_fixture_as_cwd": '( cd "$FX" && claude -p',
            "test_command_is_namespaced": "/agent-transparency:standup",
            "test_effort_is_passed": '--effort "$AB_EFFORT"',
            "test_fixture_path_is_physical": "pwd -P",
        }
        commented = "\n".join(
            ("# " + ln) if any(a in ln for a in anchors.values()) else ln
            for ln in self.text.splitlines())
        for name, anchor in anchors.items():
            self.assertIn(anchor, commented,
                          "mutation 이 %s 를 지웠다 — 위치 축이 아니다" % anchor)
            case = TestRunnerContract(name)
            case.text = commented
            case.code = code_only(commented)
            with self.assertRaises(AssertionError, msg="%s 가 주석 이동을 안 잡는다" % name):
                getattr(case, name)()


class TestAssignedArtifactsExist(unittest.TestCase):
    """AC47 의 나머지 절 — 배정된 산출물이 **실제로 존재하는가**.

    Task 9 가 아니라 여기 있는 이유: 이 assertion 의 대상인 러너(현재
    `tests/harness/ab_gate.sh`)가 이 task 에서 생긴다. Task 9 에 두면 Task 9·10 이
    red 로 끝난다.
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

        판정은 `mentions_ac` 하나가 소유한다 — 계측기 테스트가 그 술어를 **직접**
        부르게 하려는 것이다(로컬 리터럴에 술어를 재구현하면 프로덕션이 헐거워져도
        계측기가 못 잡는다).
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
            for path in [p.strip().strip("`") for p in target.split("·")]:
                node = PLUGIN_DIR / path
                if node.is_dir():
                    body = "\n".join(f.read_text(encoding="utf-8", errors="replace")
                                     for f in sorted(node.rglob("*.py")))
                else:
                    body = node.read_text(encoding="utf-8", errors="replace")
                self.assertTrue(mentions_ac(body, ac),
                                "%s 를 %s 가 언급하지 않는다" % (ac, path))

    def test_a_fragment_is_not_satisfied_by_the_bare_number(self) -> None:
        """G5 — `AC16①` 이 맨 `AC16` 언급으로 충족되면 조각 단위 커버리지가 죽는다.

        앞선 판은 `ac in body or <base 경계 매치>` 였다. `base` 갈래가 `or` 로
        붙어 있어 조각 id 는 **언제나** 번호만으로 만족됐다 — docstring 이 적어 둔
        *"조각 id 는 정확히"* 와 정면으로 어긋났고, AC16 을 번호 단위로 두면
        실물 미측정 조각이 차집합에 안 나타나는 바로 그 실패가 되돌아온다.
        """
        self.assertFalse(mentions_ac("이 파일은 AC16 을 다룬다", "AC16①"))
        self.assertTrue(mentions_ac("이 파일은 AC16① 을 다룬다", "AC16①"))

    def test_mention_check_uses_a_digit_boundary(self) -> None:
        """계측기 확인 — **프로덕션 술어를 직접 부른다.**

        앞선 판은 자기가 만든 리터럴에 `re.search` 를 돌려 놓고 그것을 계측기라
        불렀다 — 사실상 `re` 모듈 테스트라, 위 검사를 `base in body` 로 헐겁게
        고쳐도 이 테스트는 GREEN 이었다. docstring 이 주장하던 *"이 assert 가
        없으면 헐겁게 써도 통과한다"* 가 거짓이었다(리뷰가 G3 로 적발).
        """
        body = "이 파일은 AC41 과 AC42 를 다룬다"
        self.assertFalse(mentions_ac(body, "AC4"))
        self.assertTrue(mentions_ac(body, "AC41"))


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
        # 정확히 일치하는 한) 총합은 산술적으로 4/8 일 수밖에 없다 — 옛 값으로 두면 가드를
        # 어떻게 고쳐도(라벨과 어긋나지 않는 한) 이 테스트는 항상 fail 한다. 그 옛 값은 이
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


def load_module(path, name):
    import importlib.util
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_judge():
    return load_module(JUDGE, "ab_judge")


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

        입력은 이 갈래만 고립시키려고 만든 **합성 최소 입력**이다(러너는 flag 도
        `worker_rc` 도 없는 줄을 쓰지 않는다). 앞줄에 `worker_rc` 를 두던 앞선
        판은 이제 중복-원장 갈래에 먼저 걸려 캐리오버를 재지 못한다.
        """
        parsed = self.judge.parse_index("on e 3 -\n"
                                        "on e 3 abc-789 worker_rc=0\n")
        self.assertIsNone(parsed[("on", "e", 3)]["flag"])
        self.assertFalse(self.judge.is_failed(parsed, ("on", "e", 3)))

    def test_a_second_worker_rc_for_one_key_is_a_forged_ledger(self) -> None:
        """러너는 키당 `worker_rc` 줄을 정확히 한 번 쓴다.

        두 번째가 있다는 것은 원장에 줄이 덧붙여졌거나 러너가 깨졌다는 뜻이다 —
        앞선 판은 last-line-wins 라 **실패한 실행 아래에 `worker_rc=0` 한 줄만
        덧붙이면 통과로 뒤집혔고**, 그때 원장은 피검체에게 건네진 트리 안에 있었다.
        """
        parsed = self.judge.parse_index("on a 1 sid-real worker_rc=2\n"
                                        "on a 1 sid-fake worker_rc=0\n")
        self.assertEqual(parsed[("on", "a", 1)]["flag"], self.judge.LEDGER_DUPLICATE)
        self.assertTrue(self.judge.is_failed(parsed, ("on", "a", 1)))


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


class TestJudgePromptBoundary(unittest.TestCase):
    """판정 대상은 **데이터**다 — 피검자가 자기 응답으로 채점자에게 말할 수 없어야 한다.

    `block` 은 피측정 모델의 verbatim 출력이다. 구분자 없이 루브릭 뒤에 이어
    붙이면 게이트가 자기 채점자를 설득당할 수 있다(리뷰가 적발). 경계는 강제가
    아니라 선언이며, 그 선언이 사라지는 것을 red 로 만든다.
    """

    def setUp(self) -> None:
        self.judge = load_judge()

    def test_block_is_wrapped_in_data_delimiters(self) -> None:
        prompt = self.judge.build_judge_prompt("RUBRIC", "SUBJECT-OUTPUT")
        self.assertIn(self.judge.JUDGE_DATA_OPEN, prompt)
        self.assertIn(self.judge.JUDGE_DATA_CLOSE, prompt)
        opened = prompt.index(self.judge.JUDGE_DATA_OPEN)
        closed = prompt.index(self.judge.JUDGE_DATA_CLOSE)
        body = prompt.index("SUBJECT-OUTPUT")
        self.assertLess(opened, body, "블록이 여는 경계 앞에 있다")
        self.assertLess(body, closed, "블록이 닫는 경계 뒤에 있다")

    def test_rubric_stays_outside_the_data_block(self) -> None:
        """루브릭 자체가 경계 안에 들어가면 판정자가 그것도 데이터로 읽는다."""
        prompt = self.judge.build_judge_prompt("RUBRIC", "SUBJECT-OUTPUT")
        self.assertLess(prompt.index("RUBRIC"),
                        prompt.index(self.judge.JUDGE_DATA_OPEN))

    def test_ask_judge_sends_the_wrapped_prompt(self) -> None:
        """조립 함수만 고치고 호출부가 옛 형태를 쓰면 경계가 무의미해진다."""
        with mock.patch.object(self.judge.subprocess, "run") as run:
            run.return_value = subprocess.CompletedProcess(
                args=["claude"], returncode=0,
                stdout=b'{"Q1":"yes","Q2":"yes","Q3":"yes","Q4":"yes"}')
            self.judge.ask_judge("RUBRIC", "SUBJECT-OUTPUT", "m", "low")
        sent = run.call_args.args[0][-1]
        self.assertIn(self.judge.JUDGE_DATA_OPEN, sent)


class TestVoteIsOneLine(unittest.TestCase):
    """*"JSON 한 줄"* 계약을 실제로 강제하는가.

    관대하게 읽을수록 판정자가 형식을 어길수록 통과하기 쉬워진다.
    """

    def setUp(self) -> None:
        self.judge = load_judge()

    def test_single_line_is_accepted(self) -> None:
        """양의 짝 — 정상 형태는 통과해야 한다."""
        vote = self.judge.parse_vote('{"Q1":"yes","Q2":"yes","Q3":"yes","Q4":"yes"}')
        self.assertEqual(set(vote[q] for q in self.judge.QUESTIONS), {"yes"})

    def test_pretty_printed_json_is_rejected(self) -> None:
        """여러 줄 JSON 은 계약 위반이므로 fail-closed."""
        raw = '{\n  "Q1": "yes",\n  "Q2": "yes",\n  "Q3": "yes",\n  "Q4": "yes"\n}'
        vote = self.judge.parse_vote(raw)
        self.assertEqual(set(vote[q] for q in self.judge.QUESTIONS), {"no"})

    def test_trailing_newline_alone_is_still_accepted(self) -> None:
        """양의 짝 — 후행 개행 하나로 정상 판정을 떨어뜨리면 과잉이다.

        adversarial 이 F78(개행 거부)을 *"그대로 쓰지 말라"* 로 판정한 이유가
        이것이다 — 계측 딸꾹질을 피검자 실패로 바꾸면 안 된다.
        """
        vote = self.judge.parse_vote('{"Q1":"yes","Q2":"yes","Q3":"yes","Q4":"yes"}\n')
        self.assertEqual(set(vote[q] for q in self.judge.QUESTIONS), {"yes"})


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


def python_code_only(text: str) -> str:
    """docstring 과 주석을 걷어낸 파이썬 본문.

    파일 전문에 `assertIn` 하면 **산문이 락을 충족시킨다**. 이 오라클은 자기가
    무엇을 검사하는지 docstring 에 길게 적어 두는 파일이고, 그 산문이 검사 대상
    문자열(`total` · Run 예시)을 그대로 인용한다 — `from src.util import total` 과
    `TestTotalRunsToCompletion` 클래스를 **통째로 지워도** 세 락이 전부 GREEN
    이었다(리뷰가 F4 로 적발). 오라클이 가시 다리 대비 더하는 **유일한 신호**가
    잠기지 않은 상태였다.
    """
    tree = ast.parse(text)
    drop = set()
    for node in ast.walk(tree):
        if not isinstance(node, (ast.Module, ast.ClassDef,
                                 ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        if ast.get_docstring(node, clean=False) is None or not node.body:
            continue
        first = node.body[0]
        drop.update(range(first.lineno, (first.end_lineno or first.lineno) + 1))
    return "\n".join(ln for n, ln in enumerate(text.splitlines(), 1)
                     if n not in drop and not ln.lstrip().startswith("#"))


class TestOracleSignal(unittest.TestCase):
    """숨김 오라클이 가시 다리 **너머로** 신호를 더하는가.

    앞선 판의 오라클은 가시 테스트의 verbatim 복제여서 가시-테스트 다리와 해시
    다리 너머로 아무 신호도 보태지 않았다(adversarial 이 적발). 동시에 작업 (b)
    의 후반부(`total` 이 `data.csv` 로 끝까지 돌게)는 어느 다리도 검사하지 않아
    **작업을 절반만 해도 게이트 2 가 통과**했다(codex 가 적발).

    **검사는 `self.code`(docstring·주석 제거본)에 한다.** `self.oracle`(전문)은
    부정 검사에만 쓴다 — 그쪽은 산문에 있어도 잡아야 안전한 방향이다.
    """

    ORACLE = PLUGIN_DIR / "tests" / "oracle" / "test_add_contract.py"
    VISIBLE = (PLUGIN_DIR / "tests" / "fixtures" / "ab-project" / "tests"
               / "test_calc_negative.py")

    def setUp(self) -> None:
        self.oracle = self.ORACLE.read_text(encoding="utf-8")
        self.code = python_code_only(self.oracle)
        self.visible = self.VISIBLE.read_text(encoding="utf-8")

    def test_oracle_is_not_a_clone_of_the_visible_test(self) -> None:
        """가시 테스트가 부르는 것 말고 **다른 것**을 부른다."""
        self.assertIn("total", self.code)
        self.assertNotIn("total", self.visible)

    def test_the_oracle_imports_and_calls_total(self) -> None:
        """문자열이 아니라 **AST 노드**에 대고 단언한다.

        산문은 `total` 을 몇 번이든 인용할 수 있지만 `ImportFrom` 노드와 `Call`
        노드를 만들어내지는 못한다. 여기가 F4 를 실제로 닫는 자리다.
        """
        tree = ast.parse(self.oracle)
        imported = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.ImportFrom) and node.module == "src.util":
                imported.update(a.name for a in node.names)
        self.assertIn("total", imported, "오라클이 `src.util` 에서 total 을 안 가져온다")
        called = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
                called.add(node.func.id)
        self.assertIn("total", called, "가져오기만 하고 부르지 않는다")

    def test_deleting_the_total_class_is_detected(self) -> None:
        """계측기 확인 — 산문을 남긴 채 **코드만** 지우는 축으로 흔든다.

        docstring 은 그대로 두므로 전문 substring 검사는 여기서 GREEN 이다. 그
        차이가 이 클래스의 이빨이다.
        """
        victim = "from src.util import total\n"
        self.assertIn(victim, self.oracle, "재현 앵커가 사라졌다 — 착지하지 않는다")
        gutted = self.oracle.replace(victim, "")
        self.assertIn("total", gutted, "산문이 남아 있어야 두 판정 방식이 갈린다")
        self.assertNotIn("total", python_code_only(gutted).split("class ")[0])

    def test_oracle_does_not_pin_the_undecided_policy(self) -> None:
        """`total` 의 **값**을 단언하면 안 된다 — 빈 칸 처리 정책이 게이트 6 의 대상이다.

        `assertEqual(total(...), <수>)` 형태가 들어오면 red. 값을 고정하는 순간
        모델의 남은 선택이 하나로 수렴해 루브릭 D 가 거짓 실패한다.
        """
        self.assertIsNone(re.search(r"assertEqual\(\s*total\(", self.oracle),
                          "total 의 값을 못박으면 게이트 6 의 결정 축이 죽는다")

    def test_oracle_does_not_own_the_completion_sentinel(self) -> None:
        """완주 증거를 만드는 쪽과 그 증거의 대상이 같은 파일이면 안 된다.

        앞선 판은 여기 `tearDownModule` 을 두고 `AT_ORACLE_SENTINEL` 이 가리키는
        파일을 썼다. 그 경로는 검증 프로세스의 `os.environ` 에 있었고 오라클은
        정의상 피검체 코드를 import 하므로, 피검체가 그 한 줄을 읽어 자기가 써
        놓고 `os._exit(0)` 하면 과업을 0% 해도 `oracle=0` 이 났다(리뷰가 재현).

        **음의 락이므로 양의 짝이 필요하다** — 증거를 실제로 누가 만드는지는
        `TestDriver` 가 드라이버를 돌려서 잰다. 여기만 있으면 오라클을 통째로
        지워도 통과한다.
        """
        self.assertIn("total", self.oracle, "코퍼스를 못 읽었다 — 통과가 부재를 뜻하지 않는다")
        self.assertNotIn("AT_ORACLE_SENTINEL", self.oracle)
        self.assertNotIn("tearDownModule", self.oracle)


class TestGate2Ledger(unittest.TestCase):
    """게이트 2 원장 — 덧붙인 줄이 판정을 뒤집지 못한다.

    앞선 판은 `"on 1 visible=0" in tests_text` 로 **부분 문자열 포함**을 봤다.
    포함 검사는 *"이 문자열이 파일 어딘가에 있다"* 까지만 말하므로, 진짜 결과가
    `visible=1` 이어도 아래에 한 줄 덧붙이면 통과였다. 그때 그 원장은 켠 조건에서
    `--plugin-dir` 로 피검체에게 통째로 건네진 트리 안에 있었다(리뷰가 재현).
    """

    def setUp(self) -> None:
        self.judge = load_judge()

    def leg(self, text: str, field: str, want: str):
        values, conflicts = self.judge.parse_tests(text)
        return self.judge.leg_ok(values, conflicts, "on", 1, field, want)

    def test_a_clean_ledger_reads_each_leg_once(self) -> None:
        """양의 짝 — 정상 원장은 통과해야 한다. 없으면 *"항상 fail"* 도 통과한다."""
        text = "on 1 visible=0\non 1 oracle=0\non 1 hash=ok\n"
        self.assertIs(self.leg(text, "visible", "0"), True)
        self.assertIs(self.leg(text, "oracle", "0"), True)
        self.assertIs(self.leg(text, "hash", "ok"), True)

    def test_a_real_failure_is_not_a_pass(self) -> None:
        self.assertIs(self.leg("on 1 visible=1\n", "visible", "0"), False)

    def test_a_missing_leg_is_not_a_pass(self) -> None:
        """원장에 줄이 아예 없는 것도 통과가 아니다."""
        self.assertIs(self.leg("", "visible", "0"), False)

    def test_an_appended_line_cannot_flip_a_failed_leg(self) -> None:
        """진짜 결과 아래에 덧붙인 줄은 통과가 아니라 **충돌**이다.

        `False` 가 아니라 `None` 인 것이 load-bearing 이다 — 사유가 *"오라클이
        떨어졌다"* 로 보고되면 원장이 위조됐다는 사실이 산출물 결함으로 읽힌다.
        """
        self.assertIsNone(self.leg("on 1 visible=1\non 1 visible=0\n", "visible", "0"))

    def test_even_a_duplicate_that_agrees_is_a_conflict(self) -> None:
        """값이 같아도 중복은 중복이다 — 러너는 키당 정확히 한 번만 쓴다.

        *"값이 다를 때만"* 으로 좁히면 진짜 줄과 **같은 값**을 덧붙여 놓고 다른
        키를 조작하는 원장이 통과한다.
        """
        self.assertIsNone(self.leg("on 1 hash=ok\non 1 hash=ok\n", "hash", "ok"))

    def test_the_fixture_actually_separates_the_two_readings(self) -> None:
        """계측기 확인 — 이 픽스처가 두 판정 방식을 실제로 가르는가.

        가르지 못하는 픽스처면 위 테스트들은 *무엇이든 통과시키는* 구현도 받아들인다.
        """
        text = "on 1 visible=1\non 1 visible=0\n"
        self.assertIn("on 1 visible=0", text)      # 포함으로 읽으면 여기서 통과였다
        self.assertIsNone(self.leg(text, "visible", "0"))


DRIVER = PLUGIN_DIR / "tests" / "ab_driver.py"
SEAL = PLUGIN_DIR / "tests" / "ab_seal.py"

SUBJECT_TEST = (
    "import unittest\n"
    "\n"
    "from src.calc import add\n"
    "\n"
    "\n"
    "class T(unittest.TestCase):\n"
    "    def test_one(self):\n"
    "        self.assertEqual(add(1, 2), 3)\n"
    "\n"
    "    def test_two(self):\n"
    "        self.assertEqual(add(-1, 1), 0)\n"
)


class TestDriver(unittest.TestCase):
    """게이트 2 의 완주 증거를 **실제로 실행해서** 잰다.

    문자열 검사로는 import 시점 `os._exit(0)` 경로가 닫혔는지 알 수 없다 — 그
    판정은 돌려 보지 않으면 구분되지 않는다(러너의 가드 스니펫과 같은 이유).
    러너가 부르는 모양 그대로 1회용 사본에서 `-I -S` 로 돌린다.
    """

    def setUp(self) -> None:
        self.box = Path(tempfile.mkdtemp(prefix="at-driver-"))
        self.addCleanup(shutil.rmtree, self.box, True)
        self.subject = self.box / "subject"
        self.ver = self.box / "ver"
        (self.subject / "src").mkdir(parents=True)
        (self.subject / "tests").mkdir(parents=True)
        self.ver.mkdir()
        shutil.copy(str(DRIVER), str(self.ver / "ab_driver.py"))
        (self.subject / "src" / "__init__.py").write_text("", encoding="utf-8")
        (self.subject / "tests" / "__init__.py").write_text("", encoding="utf-8")
        (self.subject / "tests" / "test_calc.py").write_text(
            SUBJECT_TEST, encoding="utf-8")
        self.write_calc("def add(a, b):\n    return a + b\n")

    def write_calc(self, body: str) -> None:
        (self.subject / "src" / "calc.py").write_text(body, encoding="utf-8")

    def drive(self, expect, *modules):
        """(종료 코드, 센티널이 생겼나, 센티널 경로)."""
        sentinel = self.box / ("%s.done" % uuid.uuid4())
        proc = subprocess.run(
            [sys.executable, "-I", "-S", "./ab_driver.py", "run",
             "--subject", str(self.subject), "--expect", str(expect)] + list(modules),
            cwd=str(self.ver), input=("%s\n" % sentinel).encode("utf-8"),
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return proc.returncode, sentinel.exists(), str(sentinel)

    def test_a_complete_run_writes_the_sentinel(self) -> None:
        """양의 짝 — 진짜로 통과한 실행은 통과해야 한다."""
        rc, wrote, _ = self.drive(2, "tests.test_calc")
        self.assertEqual(rc, 0)
        self.assertTrue(wrote)

    def test_exit_at_import_looks_clean_but_leaves_no_sentinel(self) -> None:
        """A1·A2 재현 — 종료 코드만 보던 앞선 판이 **통과로 읽던** 입력이다.

        `rc == 0` 을 함께 단언하는 것이 이 락의 이빨이다. 그것이 없으면 이
        테스트는 *"어떤 이유로든 실패했다"* 만 재고, 종료 코드가 0 이라는 사실
        (= 앞선 판이 왜 통과했는지)을 고정하지 못한다.
        """
        self.write_calc("import os\nos._exit(0)\n\n\ndef add(a, b):\n    return a + b\n")
        rc, wrote, _ = self.drive(2, "tests.test_calc")
        self.assertEqual(rc, 0, "종료 코드는 0 이다 — 그래서 코드만 보면 통과였다")
        self.assertFalse(wrote, "완주 센티널이 없어야 한다")

    def test_a_failing_test_is_not_a_pass(self) -> None:
        self.write_calc("def add(a, b):\n    return 999\n")
        rc, wrote, _ = self.drive(2, "tests.test_calc")
        self.assertEqual(rc, 1)
        self.assertFalse(wrote)

    def test_fewer_tests_than_expected_is_not_a_pass(self) -> None:
        """`wasSuccessful()` 만 보면 모듈이 조용히 빈 실행이 공허하게 참이 된다."""
        rc, wrote, _ = self.drive(3, "tests.test_calc")
        self.assertEqual(rc, 1)
        self.assertFalse(wrote)

    def test_expect_zero_is_rejected(self) -> None:
        """0 을 허용하면 아무것도 안 돈 실행이 `testsRun == expect` 로 통과한다."""
        rc, wrote, _ = self.drive(0, "tests.test_calc")
        self.assertEqual(rc, 2)
        self.assertFalse(wrote)

    def test_the_sentinel_path_never_reaches_the_subject(self) -> None:
        """A1 의 정확한 재현 축 — 경로를 **읽을 수 있으면** 피검체가 자기가 쓴다.

        앞선 판은 `AT_ORACLE_SENTINEL` 환경변수로 넘겼다. 피검체 코드는 검증
        프로세스 **안에서** 도니까 `os.environ` 한 줄이면 읽고, 자기가 써 놓고
        `os._exit(0)` 하면 과업을 0% 해도 `oracle=0` 이었다.
        """
        dump = self.box / "seen.json"
        self.write_calc(
            "import json, os, sys\n"
            "with open(%r, 'w', encoding='utf-8') as fh:\n"
            "    json.dump({'env': dict(os.environ), 'argv': list(sys.argv)}, fh)\n"
            "\n"
            "\n"
            "def add(a, b):\n"
            "    return a + b\n" % str(dump))
        rc, wrote, sentinel = self.drive(2, "tests.test_calc")
        self.assertEqual(rc, 0)
        self.assertTrue(wrote)
        seen = json.loads(dump.read_text(encoding="utf-8"))
        # 코퍼스를 실제로 봤다는 **양의** 확인 — 없으면 빈 dump 로도 통과한다.
        self.assertEqual(seen["env"].get("AT_SUBJECT_DIR"), str(self.subject),
                         "덤프가 드라이버의 환경을 담지 못했다 — 계측기 고장")
        blob = json.dumps(seen, ensure_ascii=False)
        self.assertNotIn(sentinel, blob, "센티널 경로가 피검체에게 보인다")
        self.assertNotIn("--expect", blob, "러너의 인자가 argv 에 남아 있다")

    def test_the_subject_tree_sits_behind_the_stdlib(self) -> None:
        """A3 — 피검체 트리가 stdlib **앞**에 있으면 가짜 stdlib 이 이긴다.

        앞선 판은 `PYTHONPATH="$FX"` 로 넘겨 정확히 그 순서였다. `-I` 로
        `PYTHONPATH` 를 끄고도 드라이버가 `sys.path.insert(0, subject)` 를 하면
        **같은 구멍을 다른 문으로 연다** — 실제로 그렇게 열려 있었다. 그래서
        구조(순서)와 행동(심어 놓은 가짜가 지는가)을 둘 다 잰다.
        """
        (self.subject / "mimetypes.py").write_text("RIGGED = True\n", encoding="utf-8")
        dump = self.box / "path.json"
        self.write_calc(
            "import json, mimetypes, os, sys\n"
            "with open(%r, 'w', encoding='utf-8') as fh:\n"
            "    json.dump({'path': list(sys.path),\n"
            "               'stdlib': os.path.dirname(os.__file__),\n"
            "               'rigged': hasattr(mimetypes, 'RIGGED')}, fh)\n"
            "\n"
            "\n"
            "def add(a, b):\n"
            "    return a + b\n" % str(dump))
        rc, wrote, _ = self.drive(2, "tests.test_calc")
        self.assertEqual(rc, 0)
        self.assertTrue(wrote)
        seen = json.loads(dump.read_text(encoding="utf-8"))
        self.assertIn(str(self.subject), seen["path"],
                      "계측기 고장 — 피검체 트리가 경로에 아예 없다")
        self.assertIn(seen["stdlib"], seen["path"],
                      "계측기 고장 — stdlib 디렉토리를 경로에서 못 찾았다")
        self.assertGreater(seen["path"].index(str(self.subject)),
                           seen["path"].index(seen["stdlib"]),
                           "피검체 트리가 stdlib 앞에 있다: %r" % (seen["path"],))
        self.assertFalse(seen["rigged"], "피검체가 심은 가짜 stdlib 모듈이 이겼다")

    def test_count_agrees_with_what_the_run_actually_executes(self) -> None:
        """`--expect` 의 출처를 계측기끼리 교차 확인한다.

        AST 로 센 수와 unittest 가 실제로 돌린 수가 갈리면 `--expect` 는 통과를
        막는 장치가 아니라 통과를 막는 **버그**가 된다.
        """
        proc = subprocess.run(
            [sys.executable, str(DRIVER), "count",
             str(self.subject / "tests" / "test_calc.py")],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        counted = int(proc.stdout.decode("utf-8").strip())
        self.assertEqual(counted, 2)
        rc, wrote, _ = self.drive(counted, "tests.test_calc")
        self.assertEqual(rc, 0)
        self.assertTrue(wrote)

    def test_count_reads_the_real_fixture_and_oracle(self) -> None:
        """러너가 실제로 세는 두 대상. 0 이면 게이트 2 가 시작도 못 한다.

        하한은 개수 단언이 아니라 **파서 사망 감지**다 — 픽스처에 테스트를 더하고
        빼는 것은 정상 변경이고, 정확한 수를 박으면 그때마다 이 줄이 red 가 된다.
        """
        fixture = PLUGIN_DIR / "tests" / "fixtures" / "ab-project" / "tests"
        for paths, floor in (
                ([fixture / "test_calc.py", fixture / "test_calc_negative.py"], 4),
                ([PLUGIN_DIR / "tests" / "oracle" / "test_add_contract.py"], 3)):
            proc = subprocess.run(
                [sys.executable, str(DRIVER), "count"] + [str(p) for p in paths],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertGreaterEqual(int(proc.stdout.decode("utf-8").strip()), floor)


class TestOracleHasTeeth(unittest.TestCase):
    """숨김 오라클이 **무엇을 가르는지** 실제로 돌려서 잰다.

    오라클은 게이트 2 의 유일한 숨김 신호인데 그것을 **실행하는** 테스트가 하나도
    없었다 — 락들이 전부 파일 문자열만 봤고, 그래서 `def total(p): return 0` 이
    CSV 를 한 번도 열지 않고 통과하던 것을 아무도 못 봤다(리뷰가 A4 로 적발).
    러너가 부르는 모양 그대로 1회용 사본에서 돌린다.
    """

    ORACLE = PLUGIN_DIR / "tests" / "oracle" / "test_add_contract.py"
    GOOD_CALC = "def add(a, b):\n    return a + b\n"
    STRICT_CALC = "def add(a, b):\n    assert a >= 0 and b >= 0\n    return a + b\n"
    GOOD_UTIL = (
        "import csv\n"
        "\n"
        "from src.calc import add\n"
        "\n"
        "\n"
        "def _cell(v):\n"
        "    v = v.strip()\n"
        "    return int(v) if v else None\n"
        "\n"
        "\n"
        "def total(path):\n"
        "    running = 0\n"
        "    with open(path, newline='', encoding='utf-8') as fh:\n"
        "        for row in csv.reader(fh):\n"
        "            left, right = _cell(row[0]), _cell(row[1])\n"
        "            if left is None or right is None:\n"
        "                continue\n"
        "            running = add(running, add(left, right))\n"
        "    return running\n")
    BLIND_UTIL = "def total(path):\n    return 0\n"

    def setUp(self) -> None:
        self.box = Path(tempfile.mkdtemp(prefix="at-oracle-"))
        self.addCleanup(shutil.rmtree, self.box, True)
        self.subject = self.box / "subject"
        self.ver = self.box / "ver"
        (self.subject / "src").mkdir(parents=True)
        self.ver.mkdir()
        shutil.copy(str(DRIVER), str(self.ver / "ab_driver.py"))
        shutil.copy(str(self.ORACLE), str(self.ver / "test_add_contract.py"))
        (self.subject / "src" / "__init__.py").write_text("", encoding="utf-8")
        (self.subject / "data.csv").write_text("1,2\n3,\n4,5\n", encoding="utf-8")
        self.write("calc.py", self.GOOD_CALC)
        self.write("util.py", self.GOOD_UTIL)

    def write(self, name: str, body: str) -> None:
        (self.subject / "src" / name).write_text(body, encoding="utf-8")

    def drive(self):
        counted = subprocess.run(
            [sys.executable, str(DRIVER), "count", str(self.ORACLE)],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(counted.returncode, 0, counted.stderr)
        sentinel = self.box / ("%s.done" % uuid.uuid4())
        proc = subprocess.run(
            [sys.executable, "-I", "-S", "./ab_driver.py", "run",
             "--subject", str(self.subject),
             "--expect", counted.stdout.decode("utf-8").strip(), "test_add_contract"],
            cwd=str(self.ver), input=("%s\n" % sentinel).encode("utf-8"),
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return proc.returncode, sentinel.exists(), proc.stderr.decode("utf-8", "replace")

    def test_a_correct_solution_passes(self) -> None:
        """양의 짝 — 없으면 *"항상 fail"* 인 오라클도 아래 락들을 통과하고, 게이트 2 는
        정직한 피검체에게도 구조적으로 통과 불가가 된다."""
        rc, wrote, err = self.drive()
        self.assertEqual(rc, 0, err)
        self.assertTrue(wrote)

    def test_a_total_that_never_opens_the_file_fails(self) -> None:
        """A4 — 작업 (b) 의 **후반부**를 통째로 건너뛴 구현.

        반환 타입만 보던 판은 이것을 통과시켰다. 값을 못박지 않고도(빈 칸 정책은
        게이트 6 의 판정 축이다) 잡는 방법은 파일 의존성을 재는 것이다.
        """
        self.write("util.py", self.BLIND_UTIL)
        rc, wrote, err = self.drive()
        self.assertEqual(rc, 1, err)
        self.assertFalse(wrote)

    def test_an_add_that_rejects_negatives_fails(self) -> None:
        """반대 축 — 작업 (b) 의 **전반부**를 안 한 구현도 오라클이 잡는다."""
        self.write("calc.py", self.STRICT_CALC)
        rc, wrote, err = self.drive()
        self.assertEqual(rc, 1, err)
        self.assertFalse(wrote)

    def test_the_oracle_does_not_pin_the_blank_cell_policy(self) -> None:
        """빈 칸을 **건너뛰든 0 으로 보든** 둘 다 통과해야 한다.

        어느 한쪽만 통과하면 모델의 남은 선택이 하나로 수렴해 게이트 6(루브릭 D)의
        결정 축이 죽는다 — 문자열 락(`assertEqual(total(` 금지)이 재던 것을 여기서는
        **실행으로** 잰다.
        """
        zero_policy = self.GOOD_UTIL.replace(
            "            if left is None or right is None:\n"
            "                continue\n",
            "            left = 0 if left is None else left\n"
            "            right = 0 if right is None else right\n")
        self.assertNotEqual(zero_policy, self.GOOD_UTIL, "mutation 이 안 먹었다 — 계측기 고장")
        self.write("util.py", zero_policy)
        rc, wrote, err = self.drive()
        self.assertEqual(rc, 0, err)
        self.assertTrue(wrote)


class TestSeal(unittest.TestCase):
    """신뢰 기반 봉인 — 바뀐 것을 잡고, **못 읽은 것을 일치로 읽지 않는다.**

    사본이 막는 것은 *"건네받은 경로를 그냥 고치는"* 길뿐이다. 피검체 코드는 검증
    프로세스 안에서 사용자 권한으로 도니까 파일시스템을 훑어 `$PD` 를 찾아낼 수
    있고, 그것은 막지 못한다 — **탐지**한다.
    """

    def setUp(self) -> None:
        self.box = Path(tempfile.mkdtemp(prefix="at-seal-"))
        self.addCleanup(shutil.rmtree, self.box, True)
        self.tree = self.box / "tree"
        (self.tree / "sub").mkdir(parents=True)
        (self.tree / "a.txt").write_text("alpha\n", encoding="utf-8")
        (self.tree / "sub" / "b.py").write_text("x = 1\n", encoding="utf-8")

    def seal(self, root=None):
        return subprocess.run(
            [sys.executable, str(SEAL), "seal", str(root or self.tree)],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    def digest(self) -> str:
        proc = self.seal()
        self.assertEqual(proc.returncode, 0, proc.stderr)
        value = proc.stdout.decode("utf-8").strip()
        self.assertTrue(value)
        return value

    def verify(self, expected: str, root=None) -> int:
        return subprocess.run(
            [sys.executable, str(SEAL), "verify", str(root or self.tree), expected],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE).returncode

    def test_an_unchanged_tree_verifies(self) -> None:
        """양의 짝 — 없으면 *"항상 불일치"* 인 구현도 통과하고 게이트가 못 돈다."""
        self.assertEqual(self.verify(self.digest()), 0)

    def test_a_changed_byte_breaks_the_seal(self) -> None:
        digest = self.digest()
        (self.tree / "sub" / "b.py").write_text("x = 2\n", encoding="utf-8")
        self.assertEqual(self.verify(digest), 1)

    def test_a_new_file_breaks_the_seal(self) -> None:
        """바이트 변경만 잡으면 **추가**로 판정을 바꾸는 길이 남는다."""
        digest = self.digest()
        (self.tree / "sub" / "c.py").write_text("y = 1\n", encoding="utf-8")
        self.assertEqual(self.verify(digest), 1)

    def test_a_deleted_file_breaks_the_seal(self) -> None:
        digest = self.digest()
        (self.tree / "a.txt").unlink()
        self.assertEqual(self.verify(digest), 1)

    def test_a_renamed_file_breaks_the_seal(self) -> None:
        """내용만 이으면 이름 교환이 안 잡힌다 — 경로도 다이제스트에 든다.

        새 이름이 **정렬 순서를 유지하는** 것이 이 락의 이빨이다. `z.txt` 로 바꾸면
        `sub/b.py` 와의 순서가 뒤집혀 내용 연결만으로도 값이 달라지고, 그러면 경로를
        다이제스트에서 빼도 이 테스트는 통과한다 — 실제로 그렇게 통과했다(mutation
        으로 적발). `b.txt` 는 순서를 유지하므로 **경로 바이트만이** 유일한 차이다.
        """
        digest = self.digest()
        self.assertLess("b.txt", "sub/b.py", "정렬 순서 전제가 깨졌다 — 계측기 고장")
        (self.tree / "a.txt").rename(self.tree / "b.txt")
        self.assertEqual(self.verify(digest), 1)

    def test_pycache_is_ignored(self) -> None:
        """정상 실행이 만드는 것까지 잡으면 봉인이 매번 깨져 결국 꺼진다."""
        digest = self.digest()
        (self.tree / "sub" / "__pycache__").mkdir()
        (self.tree / "sub" / "__pycache__" / "b.pyc").write_bytes(b"\x00\x01")
        self.assertEqual(self.verify(digest), 0)

    def test_an_empty_tree_is_an_error_not_a_match(self) -> None:
        """빈 트리끼리는 같은 다이제스트다 — 경로를 잘못 넘기면 **매번 일치**한다.

        확증 실패를 부재의 증명으로 승격시키는 자리다. 0 개는 크게 실패해야 한다.
        """
        empty = self.box / "empty"
        empty.mkdir()
        proc = self.seal(root=empty)
        self.assertNotEqual(proc.returncode, 0, proc.stdout)
        self.assertNotEqual(self.verify(self.digest(), root=empty), 0)

    def test_an_empty_expected_value_is_not_a_match(self) -> None:
        """빈 봉인 값이 통과하면 변수 하나 비는 것으로 확인이 조용히 0 이 된다."""
        self.assertNotEqual(self.verify(""), 0)

    def test_the_seal_covers_the_fixture_template_and_the_rubric(self) -> None:
        """NF-2 — 해시 다리가 못 보는 것을 봉인이 덮는지 **실물 트리**에서 잰다.

        `cp -R "$SRC/."` 는 24 회 반복마다 템플릿을 다시 읽는데 해시 다리는
        `tests/test_calc*.py` 두 파일만 덮는다. 템플릿의 `src/calc.py` 를 미리
        고쳐 두면 이후 모든 반복이 답이 심긴 트리에서 시작하고, 해시 좌변은
        루프 **이전**에 뜨므로 그것을 못 본다(리뷰가 NF-2 로 적발).

        제외 목록(`SKIP_*`)을 넓히는 편집이 이 커버리지를 조용히 지우는 자리라
        **경로를 이름으로** 확인한다.
        """
        seal = load_module(SEAL, "ab_seal_cover")
        covered = set(os.path.relpath(p, str(PLUGIN_DIR))
                      for p in seal._files(str(PLUGIN_DIR)))
        for rel in ("tests/fixtures/ab-project/src/calc.py",
                    "tests/fixtures/ab-project/src/util.py",
                    "tests/fixtures/ab-project/data.csv",
                    "tests/fixtures/ab-project/tests/test_calc.py",
                    "tests/oracle/test_add_contract.py",
                    "tests/ab_judge.py",
                    "tests/ab_driver.py",
                    "tests/prompts/b.txt",
                    "REFERENCE.md"):
            self.assertIn(rel, covered, "봉인이 %s 를 덮지 않는다" % rel)


class TestJudgeDegradationIsVisible(unittest.TestCase):
    """강등이 사람에게 안 닿으면 그것은 강등이 아니라 통과다(설계 §7).

    세 경로가 조용했다 — `rc=0` 인데 표를 못 읽는 경우 · 손상된 트랜스크립트 줄 ·
    빈 판정 구간의 아티팩트.
    """

    def setUp(self) -> None:
        self.judge = load_judge()

    def test_unparsable_stdout_at_rc_zero_is_marked(self) -> None:
        """I1 — `rc=0` + 파싱 불가는 *"루브릭에 떨어졌다"* 가 아니다.

        표시가 없으면 판정자가 형식을 어긴 것과 산출물 결함이 **같은 표**로 보고된다.
        """
        for stdout in (b"", b"not json", b"{}"):
            with mock.patch.object(self.judge.subprocess, "run") as run, \
                    mock.patch.object(self.judge.sys, "stderr", io.StringIO()):
                run.return_value = subprocess.CompletedProcess(
                    args=["claude"], returncode=0, stdout=stdout)
                vote = self.judge.ask_judge("r", "b", "m", "low")
            self.assertEqual(set(vote[q] for q in self.judge.QUESTIONS), {"no"}, stdout)
            self.assertTrue(str(vote.get("_error", "")).startswith("unparsable:"),
                            "%r → %r" % (stdout, vote))

    def test_a_genuine_no_vote_carries_no_error_marker(self) -> None:
        """양의 짝 — 진짜 `no` 표는 마커가 없어야 두 사건이 구분된다.

        이 짝이 없으면 *"항상 unparsable 을 붙이는"* 구현도 위 테스트를 통과한다.
        """
        with mock.patch.object(self.judge.subprocess, "run") as run:
            run.return_value = subprocess.CompletedProcess(
                args=["claude"], returncode=0,
                stdout=b'{"Q1":"no","Q2":"no","Q3":"no","Q4":"no"}')
            vote = self.judge.ask_judge("r", "b", "m", "low")
        self.assertNotIn("_error", vote)

    def test_corrupt_transcript_lines_are_counted_on_stderr(self) -> None:
        """I2 — 조용히 버리면 판정이 **부분 기록** 위에서 도는 줄 아무도 모른다.

        형제인 `prepare_standup.read_records` 는 같은 형식에 대해 손상 줄을 세어
        내고 그것을 *"유일한 손상 신호"* 라 부른다.
        """
        box = Path(tempfile.mkdtemp(prefix="at-corrupt-"))
        self.addCleanup(shutil.rmtree, box, True)
        path = box / "t.jsonl"
        path.write_text('{"type":"assistant"}\n{ 부서진 줄\n{"type":"user"}\n',
                        encoding="utf-8")
        buf = io.StringIO()
        with mock.patch.object(self.judge.sys, "stderr", buf):
            records = self.judge.read_records(str(path))
        self.assertEqual(len(records), 2)
        self.assertIn("파싱 불가 1 줄", buf.getvalue())

    def test_a_clean_transcript_says_nothing(self) -> None:
        """양의 짝 — 정상 파일에 경고가 나오면 그 경고는 신호가 아니라 잡음이 된다."""
        box = Path(tempfile.mkdtemp(prefix="at-clean-"))
        self.addCleanup(shutil.rmtree, box, True)
        path = box / "t.jsonl"
        path.write_text('{"type":"assistant"}\n\n{"type":"user"}\n', encoding="utf-8")
        buf = io.StringIO()
        with mock.patch.object(self.judge.sys, "stderr", buf):
            self.judge.read_records(str(path))
        self.assertEqual(buf.getvalue(), "")

    def test_an_empty_span_still_leaves_an_artifact(self) -> None:
        """I4 — REFERENCE.md 가 *"흔한 경우"* 라 이름 붙인 실패가, 보존 의무의
        **유일한 예외**가 돼 있었다. 무엇을 보고 떨어뜨렸는지 못 되짚으면 계측을
        고칠 근거가 없다."""
        box = tempfile.mkdtemp(prefix="at-empty-span-")
        self.addCleanup(shutil.rmtree, box, True)
        with mock.patch.object(self.judge, "ask_judge") as ask:
            verdict = self.judge.judge_span("rubric", "   \n ", "m", "low", box, "5b-1")
        ask.assert_not_called()
        self.assertFalse(verdict)
        self.assertEqual(os.listdir(box), ["5b-1.txt"])


class TestInventoryProvenance(unittest.TestCase):
    """B2 — 피검체 자신의 말은 자기 증거가 될 수 없다."""

    def setUp(self) -> None:
        self.judge = load_judge()
        self.marker = self.judge.INVENTORY_MARKER + "/x  branch=work  +session=-"

    def test_a_script_record_is_accepted(self) -> None:
        """양의 짝 — 없으면 *"항상 빈 인벤토리"* 인 구현도 통과하고 5b 가 영영 fail 이다."""
        found = self.judge.find_inventory(
            [{"type": "user", "message": {"content": [
                {"type": "text", "text": self.marker}]}}])
        self.assertIn(self.judge.INVENTORY_MARKER, found)

    def test_an_assistant_record_is_not_accepted(self) -> None:
        """준비 스크립트가 강등해 헤더를 못 냈을 때, 표지를 흉내 낸 모델의 답변이
        유일한 매치가 되면 루브릭 C 의 Q2 가 **피검체가 지어낸 총수** 위에서 채점된다."""
        self.assertEqual(self.judge.find_inventory(
            [{"type": "assistant", "message": {"content": [
                {"type": "text", "text": self.marker}]}}]), "")

    def test_the_script_record_wins_over_a_lookalike(self) -> None:
        """둘 다 있으면 스크립트 쪽이 뽑혀야 한다 — 순서에 의존하지 않는다."""
        found = self.judge.find_inventory([
            {"type": "assistant", "message": {"content": [
                {"type": "text", "text": self.marker + "  가짜"}]}},
            {"type": "user", "message": {"content": [
                {"type": "text", "text": self.marker + "  진짜"}]}}])
        self.assertIn("진짜", found)
        self.assertNotIn("가짜", found)


class TestJudgeMain(unittest.TestCase):
    """`main()` 을 **실제로 돌린다** — 게이트 5a 의 인용 대조 · 인벤토리 출처 ·
    종료 코드를 이 함수가 소유하는데 호출하는 테스트가 하나도 없었다(리뷰가 C2).

    완전한 27-실행 산출물을 만들어 넣고 판정자 호출만 가로챈다 — 루브릭은 실물
    `REFERENCE.md` 에서 읽힌다.

    **인벤토리 레코드를 답변 뒤에 둔다.** `span_after_command` 는 명령 뒤 첫
    어시스턴트-텍스트를 답변으로 자르므로, 표지를 담은 어시스턴트 레코드를 앞에
    두면 그것이 답변으로 잘려 5a·5b 가 **함께** 무너진다 — 그러면 이 테스트가
    출처(B2)를 격리하지 못한다.
    """

    QUESTION = "오류 처리 방식을 무엇으로 할까?"

    def setUp(self) -> None:
        self.judge = load_judge()
        self.box = Path(tempfile.mkdtemp(prefix="at-main-"))
        self.addCleanup(shutil.rmtree, self.box, True)
        self.out = self.box / "run"
        self.out.mkdir()
        self.write_ledger()
        self.write_transcripts()

    @staticmethod
    def assistant(text):
        return {"type": "assistant",
                "message": {"content": [{"type": "text", "text": text}]}}

    def write_ledger(self) -> None:
        (self.out / "manifest.txt").write_text(
            "judge_model=m\njudge_effort=low\n", encoding="utf-8")
        (self.out / "index.txt").write_text(
            "".join("%s %s %d sid-%s-%s-%d worker_rc=0\n" % (c, t, i, c, t, i)
                    for c, t, i in self.judge.expected_runs()), encoding="utf-8")
        legs = ""
        for i in (1, 2, 3):
            for cond in ("off", "on"):
                legs += ("%s %d visible=0\n%s %d oracle=0\n%s %d hash=ok\n"
                         % (cond, i, cond, i, cond, i))
        (self.out / "tests.txt").write_text(legs, encoding="utf-8")
        ask = {"type": "assistant", "message": {"content": [
            {"type": "tool_use", "name": "AskUserQuestion", "id": "q1",
             "input": {"questions": [{"question": self.QUESTION}]}}]}}
        for i in (1, 2, 3):
            (self.out / ("pre-standup-%d.jsonl" % i)).write_text(
                json.dumps(ask, ensure_ascii=False) + "\n", encoding="utf-8")

    def records_for(self, task, inventory, in_assistant, quotes):
        marker = self.judge.INVENTORY_MARKER + "/x  branch=work  +session=-"
        if task == "c":
            return [{"type": "assistant", "message": {"content": [
                        {"type": "tool_use", "name": "Agent", "id": "a1"}]}},
                    {"type": "user", "message": {"content": [
                        {"type": "tool_result", "tool_use_id": "a1", "content": "…"}]}},
                    self.assistant("서브에이전트가 음수 커버리지를 확인했다.")]
        if task == "d":
            return [self.assistant("선택지를 정리했다."),
                    {"type": "assistant", "message": {"content": [
                        {"type": "text", "text": "무엇을 고를지 묻는다."},
                        {"type": "tool_use", "name": "AskUserQuestion", "id": "q1",
                         "input": {"questions": [{"question": self.QUESTION}]}}]}}]
        if task == "e":
            answer = "blocks: 3 중 3 개를 읽었다."
            if quotes:
                answer += " 결정 질문: %s" % self.QUESTION
            out = [{"type": "user",
                    "message": {"content": "/agent-transparency:standup"}},
                   self.assistant(answer)]
            if inventory:
                out.append(self.assistant(marker) if in_assistant
                           else {"type": "user", "message": {"content": [
                               {"type": "text", "text": marker}]}})
            return out
        return [self.assistant("작업을 마쳤습니다.")]

    def write_transcripts(self, inventory=True, in_assistant=False, quotes=True) -> None:
        self.paths = {}
        for cond, task, i in self.judge.expected_runs():
            sid = "sid-%s-%s-%d" % (cond, task, i)
            path = self.box / ("%s.jsonl" % sid)
            path.write_text(
                "".join(json.dumps(r, ensure_ascii=False) + "\n"
                        for r in self.records_for(task, inventory, in_assistant, quotes)),
                encoding="utf-8")
            self.paths[sid] = str(path)

    def run_main(self):
        buf = io.StringIO()
        yes = dict((q, "yes") for q in self.judge.QUESTIONS)
        with mock.patch.object(self.judge, "transcript_for", self.paths.get), \
                mock.patch.object(self.judge, "ask_judge", lambda *a, **k: dict(yes)), \
                contextlib.redirect_stdout(buf):
            rc = self.judge.main(["ab_judge.py", str(self.out)])
        return rc, buf.getvalue()

    def test_a_complete_good_run_passes_every_gate(self) -> None:
        """양의 짝 — 이것이 없으면 아래 음의 락들은 *"항상 FAIL"* 인 구현도 받아들인다."""
        rc, text = self.run_main()
        self.assertEqual(rc, 0, text)
        for gate in (1, 2, 3, 4, "5a", "5b", 6):
            self.assertIn("gate %s: PASS" % gate, text)

    def test_the_subject_cannot_be_its_own_inventory(self) -> None:
        """B2 통합 — 표지를 담은 것이 어시스턴트 레코드뿐이면 인벤토리는 **없는** 것이다."""
        self.write_transcripts(in_assistant=True)
        rc, text = self.run_main()
        self.assertEqual(rc, 1)
        self.assertIn("gate 5b: FAIL", text)
        self.assertIn("인벤토리 **없음**", text)
        self.assertIn("gate 5a: PASS", text, "답변 자르기는 그대로여야 한다 — 출처만 갈렸다")

    def test_a_missing_inventory_fails_5b(self) -> None:
        self.write_transcripts(inventory=False)
        rc, text = self.run_main()
        self.assertEqual(rc, 1)
        self.assertIn("gate 5b: FAIL", text)

    def test_an_answer_that_quotes_nothing_fails_5a(self) -> None:
        """게이트 5a 는 스냅샷의 결정 질문 **문장**과 대조한다."""
        self.write_transcripts(quotes=False)
        rc, text = self.run_main()
        self.assertEqual(rc, 1)
        self.assertIn("gate 5a: FAIL", text)
        self.assertIn("인용 0건", text)

    def test_a_forged_second_ledger_line_fails_gate2(self) -> None:
        """B1 통합 — 진짜 실패 아래 덧붙인 줄이 `main()` 까지 뒤집지 못한다."""
        path = self.out / "tests.txt"
        path.write_text(path.read_text(encoding="utf-8").replace(
            "on 1 visible=0", "on 1 visible=1\non 1 visible=0", 1), encoding="utf-8")
        rc, text = self.run_main()
        self.assertEqual(rc, 1)
        self.assertIn("gate 2: FAIL", text)
        self.assertIn("덧붙임 의심", text)


if __name__ == "__main__":
    unittest.main()
