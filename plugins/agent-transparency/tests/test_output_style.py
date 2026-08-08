#!/usr/bin/env python3
"""output style 회귀 락 — AC1 · AC2 · AC3 · AC4 · AC5 · AC31 · AC38.

검사는 순수 함수다. 실물 파일과 **변형 문자열** 양쪽에 같은 함수를 돌려
mutation 이 실제로 red 를 내는지 확인한다(파일을 고쳤다 되돌리는 방식은
계측이 되지 않는다).

Run:
    python3 -m unittest plugins/agent-transparency/tests/test_output_style.py
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
STYLE = REPO_ROOT / "plugins" / "agent-transparency" / "output-styles" / "agent-transparency.md"

MOMENT_KEYS = [
    "ask the user to decide",
    "settled something without asking",
    "another agent's result comes back",
    "verdict or conclusion lands",
    "something you needed was unavailable",
    "starting a long task",
    "the work ends",
]
BOUNDARY_KEYS = ["long task", "verdict", "The work ends", "Unavailable",
                 "settled something without asking"]
RULE_ANCHORS = ["<!-- rule:jargon -->", "<!-- rule:standard-term -->",
                "<!-- rule:no-assumed-knowledge -->", "<!-- rule:pointer -->",
                "<!-- rule:analogy -->"]


def check_frontmatter(text: str) -> list[str]:
    """AC1 — 두 값이 **참으로** 선언돼 있다."""
    bad = []
    for key in ("keep-coding-instructions", "force-for-plugin"):
        if not re.search(r"(?m)^%s:\s*true\s*$" % re.escape(key), text):
            bad.append("frontmatter 에 %s: true 없음" % key)
    return bad


def check_explanatory(text: str) -> list[str]:
    """AC2 — Explanatory 4요소."""
    bad = []
    if "★ Insight" not in text:
        bad.append("Insight 블록 형식 없음")
    if "Before and after writing code" not in text:
        bad.append("코드 전후 시점 규정 없음")
    if "Do\nnot wait until the end" not in text and "not wait until the end" not in text:
        bad.append("미루지 않는다는 규정 없음")
    if "specific\nto this codebase" not in text and "specific to this codebase" not in text:
        bad.append("코드베이스 특유 요구 없음")
    return bad


def check_moments(text: str) -> list[str]:
    """AC3 — Moments 표가 7행이고 각 행이 「일곱 순간의 출처」와 1:1."""
    rows = [ln for ln in text.splitlines()
            if ln.startswith("|") and "---" not in ln
            and not ln.startswith("| Moment")]
    bad = []
    if len(rows) != 7:
        bad.append("Moments 표 행 수가 7이 아니라 %d" % len(rows))
    body = "\n".join(rows)
    for key in MOMENT_KEYS:
        if key not in body:
            bad.append("순간 누락: %s" % key)
    return bad


def check_boundaries(text: str) -> list[str]:
    """AC4 — Trigger boundaries 문단 + 5개 용어 + settled 의 제외절."""
    bad = []
    start = text.find("**Trigger boundaries.**")
    if start < 0:
        return ["Trigger boundaries 문단 없음"]
    end = text.find("\n\nExample,", start)
    para = text[start:end if end > 0 else len(text)]
    for key in BOUNDARY_KEYS:
        if key not in para:
            bad.append("경계 정의 누락: %s" % key)
    # 제외절은 **그 문단 안에** 있어야 한다 — 위치 축 mutation(문단 끝 밖으로 이동)에서 red.
    if "Formatting, naming, and the order of independent steps are not that." not in para:
        bad.append("settled 의 제외절이 Trigger boundaries 문단 안에 없음")
    return bad


def check_format(text: str) -> list[str]:
    """AC5 — Format 이 일곱 순간으로 스코프되고, 표는 항목 둘 이상일 때만."""
    bad = []
    if "When you explain at the moments above" not in text:
        bad.append("Format 규칙이 일곱 순간으로 스코프돼 있지 않음")
    if "a table around one row costs the reader more than it saves" not in text:
        bad.append("단일 항목 표 예외 문장 없음")
    return bad


def check_settled_row(text: str) -> list[str]:
    """AC38 — 「묻지 않고 정했을 때」 행이 세 항목 + 세 사유를 요구한다.

    행 번호가 아니라 **이름**으로 찾는다(표 안 위치는 바뀔 수 있다).
    """
    row = ""
    for line in text.splitlines():
        if line.startswith("|") and "settled something without asking" in line:
            row = line
            break
    if not row:
        return ["「묻지 않고 정했을 때」 행을 이름으로 찾을 수 없음"]
    bad = []
    if "what you decided" not in row:
        bad.append("무엇을 정했나 없음")
    if "why you did not ask" not in row:
        bad.append("왜 안 물었나 없음")
    if "what the user would say to reverse it" not in row:
        bad.append("되돌리는 말 없음")
    for reason in ("the evidence left one option", "a measurement ruled the others out",
                   "an earlier instruction from the user ruled them out"):
        if reason not in row:
            bad.append("사유 열거 누락: %s" % reason)
    return bad


CHECKS = (check_frontmatter, check_explanatory, check_moments,
          check_boundaries, check_format, check_settled_row)


class TestRealFile(unittest.TestCase):
    def setUp(self) -> None:
        self.text = STYLE.read_text(encoding="utf-8")

    def test_all_checks_pass(self) -> None:
        for check in CHECKS:
            self.assertEqual(check(self.text), [], check.__name__)

    def test_rule_anchors_present(self) -> None:
        """AC28 좌변 — 다섯 규칙 앵커. 우변은 test_readability_parity.py."""
        for anchor in RULE_ANCHORS:
            self.assertIn(anchor, self.text)

    def test_opposite_verdicts_instruction(self) -> None:
        """AC31 — 리뷰어·에이전트 간 상반 판정을 밝히라는 지시(K7)."""
        self.assertIn("two reviewers or agents reached opposite verdicts", self.text)


class TestMutation(unittest.TestCase):
    """표기 · 값 · 위치 세 축으로 흔든다. 내가 지운 바이트를 되돌리는 변형은 쓰지 않는다."""

    def setUp(self) -> None:
        self.text = STYLE.read_text(encoding="utf-8")

    def test_frontmatter_value_flip(self) -> None:
        """값 축 — true → false."""
        mutated = self.text.replace("keep-coding-instructions: true",
                                    "keep-coding-instructions: false")
        self.assertNotEqual(check_frontmatter(mutated), [])

    def test_frontmatter_notation_change(self) -> None:
        """표기 축 — YAML boolean 을 문자열로."""
        mutated = self.text.replace("force-for-plugin: true", 'force-for-plugin: "true"')
        self.assertNotEqual(check_frontmatter(mutated), [])

    def test_moments_row_deleted(self) -> None:
        """AC3 — 한 행을 지우면 red."""
        lines = self.text.splitlines()
        kept = [ln for ln in lines
                if "something you needed was unavailable" not in ln]
        self.assertNotEqual(check_moments("\n".join(kept)), [])

    def test_moments_row_added(self) -> None:
        """추가 축 — 8행이 되어도 red(리뷰어가 추가·반전으로 락을 통과한 전례)."""
        mutated = self.text.replace(
            "| When the work ends |",
            "| When you feel like it | anything |\n| When the work ends |")
        self.assertNotEqual(check_moments(mutated), [])

    def test_boundary_term_removed(self) -> None:
        mutated = self.text.replace("A *verdict* is any pass/fail", "A thing is any pass/fail")
        self.assertNotEqual(check_boundaries(mutated), [])

    def test_settled_exclusion_moved_out_of_paragraph(self) -> None:
        """위치 축 — 제외절을 문단 밖(예시 뒤)으로 옮겨도 red."""
        clause = "Formatting, naming, and the order of independent steps are not that."
        mutated = self.text.replace(clause, "")
        mutated = mutated.rstrip() + "\n\n" + clause + "\n"
        self.assertNotEqual(check_boundaries(mutated), [])

    def test_format_scope_removed(self) -> None:
        mutated = self.text.replace("**When you explain at the moments above**, use",
                                    "Always use")
        self.assertNotEqual(check_format(mutated), [])

    def test_table_exception_removed(self) -> None:
        mutated = self.text.replace(
            "a table around one row costs the reader more than it saves", "")
        self.assertNotEqual(check_format(mutated), [])

    def test_settled_reverse_item_removed(self) -> None:
        """AC38 — 되돌리는 항목이 빠지면 red(그것이 없으면 통보이지 투명성이 아니다)."""
        mutated = self.text.replace(
            " / **what the user would say to reverse it**", "")
        self.assertNotEqual(check_settled_row(mutated), [])

    def test_explanatory_element_removed(self) -> None:
        mutated = self.text.replace("Before and after writing code", "Sometimes")
        self.assertNotEqual(check_explanatory(mutated), [])


if __name__ == "__main__":
    unittest.main()
