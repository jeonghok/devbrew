#!/usr/bin/env python3
"""AC40 · AC45 · AC47 — A/B 러너 계약과 AC 커버리지.

`ab_gate.sh` **전체는 실행하지 않는다**(워커가 claude 를 부르므로 비용·비결정).
단 순수-python 가드 스니펫은 **추출해 JSON 픽스처로 실제 실행**한다 —
문자열 검사로는 그 판정 로직의 세 판을 구분하지 못한다.

Run:
    python3 -m unittest plugins/agent-transparency/tests/test_ab_runner_contract.py
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

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
        """계측기 자체가 고장 나면 빈 집합끼리 같아서 통과한다 — 먼저 막는다."""
        self.assertGreaterEqual(len(self.listed), 38)
        self.assertGreaterEqual(len(self.oqs), 20)

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


if __name__ == "__main__":
    unittest.main()
