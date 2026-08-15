#!/usr/bin/env python3
"""AC28 — output style `## Vocabulary` ↔ SKILL.md `## 쓰는 방식` 다섯 규칙 파리티.

**이 검사의 한계를 여기 적는다**: 순수 unittest 가 영어 산문과 한국어 산문의
의미 대응을 판정할 수는 없다. 그래서 두 파일에 **규칙마다 주석 앵커**를 달고,
테스트는 **다섯 앵커가 양쪽에 모두 있는지**만 본다. 산문 일치는 사람 리뷰이고,
이 검사가 잡는 것은 *한쪽에서 규칙이 통째로 사라지는 것*뿐이다.

규칙이 살 수 있는 자리는 셋(output style · SKILL.md · agent 정의)인데 이 검사는
둘만 본다. 세 번째 사본을 만드는 편집이 오면 이 파일의 좌우변부터 늘려야 한다.

Run:
    python3 -m unittest plugins/agent-transparency/tests/test_readability_parity.py
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
PLUGIN_DIR = REPO_ROOT / "plugins" / "agent-transparency"
STYLE = PLUGIN_DIR / "output-styles" / "agent-transparency.md"
SKILL = PLUGIN_DIR / "skills" / "briefing-current-state" / "SKILL.md"
AGENT = PLUGIN_DIR / "agents" / "transcript-reader.md"

ANCHORS = ("<!-- rule:jargon -->", "<!-- rule:pointer -->",
           "<!-- rule:standard-term -->", "<!-- rule:analogy -->",
           "<!-- rule:no-assumed-knowledge -->")

# 규칙 본문이 사는 절. 앵커만 재면 **본문을 통째로 지우고 앵커 다섯 개를 한 줄에
# 남겨도** 통과한다 — 이 파일 docstring 은 "규칙이 통째로 사라지는 것" 을 잡는다고
# 적었지만 실제로 잡던 것은 **HTML 주석이 사라지는 것**뿐이었다(리뷰가 F6 로 적발).
RULE_SECTIONS = (("output style", "Vocabulary"), ("SKILL.md", "쓰는 방식"))
# 하한은 길이 단언이 아니라 **본문 소실 감지**다. 실측 964(style) · 456(skill) 이라
# 산문을 손봐도 안 걸리고, 앵커만 남긴 상태(≈0)는 걸린다.
BODY_FLOOR = 200


def section_of(text: str, heading: str) -> str:
    """`## <heading>` 부터 다음 `## ` 까지."""
    marker = "## " + heading
    start = text.find(marker)
    if start < 0:
        return ""
    rest = text[start + len(marker):]
    end = rest.find("\n## ")
    return rest if end < 0 else rest[:end]


def rule_body(text: str, heading: str) -> str:
    """앵커와 공백을 걷어낸 절 본문 — 규칙이 **실제로 적혀 있는** 분량."""
    block = section_of(text, heading)
    for anchor in ANCHORS:
        block = block.replace(anchor, "")
    return re.sub(r"\s+", " ", block).strip()


class TestFiveRuleParity(unittest.TestCase):
    def setUp(self) -> None:
        self.style = STYLE.read_text(encoding="utf-8")
        self.skill = SKILL.read_text(encoding="utf-8")

    def test_all_five_anchors_on_both_sides(self) -> None:
        for anchor in ANCHORS:
            self.assertIn(anchor, self.style, "output style 에 %s 없음" % anchor)
            self.assertIn(anchor, self.skill, "SKILL.md 에 %s 없음" % anchor)

    def test_anchor_sets_are_equal(self) -> None:
        """한쪽에만 있는 앵커가 있으면 red — 좌우변이 갈리는 것을 잡는다."""
        left = {a for a in ANCHORS if a in self.style}
        right = {a for a in ANCHORS if a in self.skill}
        self.assertEqual(left, right)

    def test_no_third_copy_in_agent_definition(self) -> None:
        """세 번째 사본 금지 — 파리티가 못 보는 자리에 규칙을 두지 않는다."""
        agent = AGENT.read_text(encoding="utf-8")
        for anchor in ANCHORS:
            self.assertNotIn(anchor, agent)

    def test_mutation_rule_removed_from_one_side(self) -> None:
        """SKILL.md 에서 한 규칙이 사라지면 red."""
        mutated = self.skill.replace("<!-- rule:pointer -->", "")
        left = {a for a in ANCHORS if a in self.style}
        right = {a for a in ANCHORS if a in mutated}
        self.assertNotEqual(left, right)

    def test_each_side_carries_actual_rule_text(self) -> None:
        """F6 — 앵커만 재면 **본문을 통째로 지워도** 통과한다.

        이 파일이 잡는다고 적어 둔 것은 *"규칙이 통째로 사라지는 것"* 인데, 실제로
        잡던 것은 **HTML 주석이 사라지는 것**뿐이었다. 앵커 다섯 개를 한 줄에
        남기고 절 본문을 비우면 규칙은 없는데 파리티는 초록이다.
        """
        for label, heading in RULE_SECTIONS:
            text = self.style if label == "output style" else self.skill
            body = rule_body(text, heading)
            self.assertGreater(len(body), BODY_FLOOR,
                               "%s 「%s」 본문이 %d자 — 규칙이 비었다"
                               % (label, heading, len(body)))

    def test_an_anchors_only_section_is_detected(self) -> None:
        """계측기 확인 — F6 를 그대로 재현한다(본문 삭제 · 앵커 보존).

        앵커 검사 넷은 이 mutation 에서 전부 GREEN 이다 — 그 차이가 위 락의 이빨이다.
        """
        gutted = self.skill.replace(section_of(self.skill, "쓰는 방식"),
                                    "\n\n" + "".join(ANCHORS) + "\n")
        for anchor in ANCHORS:
            self.assertIn(anchor, gutted, "앵커가 사라졌다 — 축이 아니다")
        # `< 10` 이라 **앵커를 걷어내는 것**이 load-bearing 이다. `<= BODY_FLOOR`
        # 로 두면 앵커 다섯 개(≈150자)가 그대로 남아도 통과해, `rule_body` 가
        # 앵커를 세고 있는지 아닌지를 이 테스트가 구분하지 못한다.
        self.assertLess(len(rule_body(gutted, "쓰는 방식")), 10)


if __name__ == "__main__":
    unittest.main()
