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


if __name__ == "__main__":
    unittest.main()
