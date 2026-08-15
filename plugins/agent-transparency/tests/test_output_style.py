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
# 각 순간이 **담아야 하는 항목**. 행 이름만 잠그면 표는 7행을 유지한 채 내용이
# 통째로 빠질 수 있다 — 이 표의 값은 이름이 아니라 항목에 있다(리뷰가 적발).
# 「묻지 않고 정했을 때」 행은 AC38 이 세 항목을 따로 잠그므로 여기서는
# 나머지 여섯 행을 덮는다. 문구는 output style 본문에서 **verbatim** 이다.
MOMENT_ITEMS = {
    "ask the user to decide": [
        "what you are asking", "why these options",
        "what you discarded and why", "your recommendation and its basis"],
    "another agent's result comes back": [
        "who", "what they found", "where the evidence is",
        "how it changed your judgment"],
    "verdict or conclusion lands": [
        "the verdict", "its basis", "what was examined", "what was not examined"],
    "something you needed was unavailable": [
        "what was missing", "what that makes weaker in the result"],
    "starting a long task": [
        "the steps", "how many", "what it will produce"],
    "the work ends": [
        "what changed", "what remains", "what is next"],
}
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
    """AC3 — Moments 표가 7행이고, 각 행이 이름 **과 필수 항목**을 함께 담는다.

    앞선 판은 행 **이름**과 행 수만 봤다. 그러면 표는 7행을 유지한 채 오른쪽
    열이 통째로 비어도 green 이다 — 이 표의 값은 이름이 아니라 항목에 있고,
    항목을 빼는 것이 정확히 이 플러그인이 막으려는 실패다(리뷰가 적발).
    항목은 **그 행 안에서** 찾는다. 표 전체에 대고 찾으면 다른 행의 항목이
    빠진 행을 대신 만족시킨다.
    """
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
            continue
        row = next((r for r in rows if key in r), "")
        for item in MOMENT_ITEMS.get(key, []):
            if item not in row:
                bad.append("항목 누락: %s → %s" % (key, item))
    return bad


def check_boundaries(text: str) -> list[str]:
    """AC4 — Trigger boundaries 문단 + 5개 용어 + settled 의 제외절.

    **창의 끝은 문단 구분(빈 줄)이다 — 피검 파일의 산문이 아니다.** 앞선 판은
    `"\\n\\nExample,"` 을 종결자로 썼는데 그 문장은 피검 파일 자신이 쥐고 있다:
    *"For example,"* 로 리워딩하면 `find` 가 `-1` 을 돌려주고 창이 **파일 끝까지**
    벌어져, 아래 제외절의 위치 축이 조용히 죽는다(리뷰가 G7 로 적발). 앵커를
    피검자가 통제하는 문자열에 걸면 피검자가 자기를 감사에서 빼낼 수 있다.
    """
    bad = []
    start = text.find("**Trigger boundaries.**")
    if start < 0:
        return ["Trigger boundaries 문단 없음"]
    end = text.find("\n\n", start)
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

    @staticmethod
    def _rewrite_row(text, key, transform):
        """`key` 를 담은 행 하나만 바꾼다. 나머지는 그대로."""
        out = []
        for line in text.splitlines():
            out.append(transform(line) if line.startswith("|") and key in line else line)
        return "\n".join(out)

    def test_moment_item_removed_from_each_row(self) -> None:
        """행 수·이름은 그대로 두고 **항목만** 지운다 — 앞선 판이 못 잡던 축.

        여섯 행 각각을 따로 흔든다. 한 행만 흔들면 나머지 다섯의 항목 락이
        도달 불가여도 통과한다. 항목 일부는 본문에서 `**볼드**` 라 행 안에서
        항목 문자열만 지운다 — 구분자까지 맞추려 들면 mutation 이 아무것도
        안 바꾸고 조용히 통과한다(첫 판이 실제로 그랬다).
        """
        for key, items in MOMENT_ITEMS.items():
            for item in items:
                mutated = self._rewrite_row(
                    self.text, key, lambda ln: ln.replace(item, "", 1))
                self.assertNotEqual(mutated, self.text,
                                    "mutation 이 아무것도 안 바꿨다: %s" % item)
                self.assertNotEqual(check_moments(mutated), [],
                                    "%s 의 %s 가 사라져도 green" % (key, item))

    def test_moment_item_moved_to_another_row(self) -> None:
        """항목을 **다른 행으로 옮기는** 축 — 표 전체에 대고 재는 구현은 여기서 green.

        삭제 축만 흔들면 *"표 어딘가에 그 문구가 있다"* 로 재는 구현과
        구분되지 않는다.
        """
        item = "what was not examined"
        mutated = self._rewrite_row(self.text, "verdict or conclusion lands",
                                    lambda ln: ln.replace(item, "", 1))
        mutated = self._rewrite_row(
            mutated, "the work ends",
            lambda ln: ln.rstrip().rstrip("|").rstrip() + " / " + item + " |")
        self.assertIn(item, mutated, "mutation 이 문구를 지웠다 — 이동 축이 아니다")
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

    def test_the_window_survives_rewording_of_the_following_prose(self) -> None:
        """G7 — 창 종결자가 **피검 파일이 통제하는 산문**이면 안 된다.

        앞선 판은 문단 뒤에 오는 `"Example,"` 로 창을 닫았다. 파일이 그 문장을
        *"For example,"* 로 바꾸면 창이 파일 끝까지 벌어져, 바로 위 테스트가 재는
        **위치 축이 조용히 사라진다** — 리워딩하는 사람은 자기가 감사를 껐다는
        것을 모른다. 두 축을 함께 흔든다: 산문을 리워딩한 **뒤에도** 제외절 이동이
        여전히 red 여야 한다.
        """
        reworded = self.text.replace("\n\nExample, just before",
                                     "\n\nFor example, just before")
        self.assertNotIn("\n\nExample,", reworded,
                         "mutation 이 안 먹었다 — 계측기 고장")
        self.assertEqual(check_boundaries(reworded), [],
                         "리워딩만으로 실물이 red 가 되면 과잉이다")
        clause = "Formatting, naming, and the order of independent steps are not that."
        moved = reworded.replace(clause, "").rstrip() + "\n\n" + clause + "\n"
        self.assertNotEqual(check_boundaries(moved), [],
                            "산문 리워딩 하나로 위치 축이 죽었다")

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
