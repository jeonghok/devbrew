"""Regression lock on `commands/project-init.md` prose contracts.

`/project-init` is a model-followed markdown instruction, not executable code, so
a test cannot exercise its behaviour. What it *can* lock is the existence of the
contract the model is meant to follow. Each assertion is scoped to the text that
owns the rule and matches a phrase unique to that body — a phrase that also
appeared in a heading, or in a table cell quoting the rule, would leave the lock
satisfiable after the rule itself is deleted.

Discovered by the WS5 sandbox re-run: an S2a migration of a repo whose CLAUDE.md
is titled `# CLAUDE.md` produced an AGENTS.md carrying that same H1, because the
title fell under the "비-관리 컨텐츠는 보존" rule and nothing overrode it.
"""

from __future__ import annotations

import unittest
from pathlib import Path

COMMAND = Path(__file__).resolve().parents[1] / "commands" / "project-init.md"


def section(text: str, start_marker: str, end_marker: str) -> str:
    """Return the body between two markers, exclusive of the end marker.

    Both markers must be unique in `text`; a marker that also occurs inside a
    table cell would silently open the window in the wrong place, scoping the
    assertion to prose it was never meant to guard.
    """
    for label, marker in (("start", start_marker), ("end", end_marker)):
        if text.count(marker) != 1:
            raise AssertionError(f"{label} marker not unique: {marker!r}")
    start = text.index(start_marker)
    end = text.index(end_marker, start + len(start_marker))
    return text[start:end]


def standalone_line(text: str, prefix: str) -> str:
    """Return the single line that BEGINS with `prefix`.

    The preservation rule's opening words are also quoted inside the 4c S2a
    table cell, so a plain substring search finds the quotation, not the rule.
    Anchoring to the start of a line disambiguates them.
    """
    hits = [ln for ln in text.splitlines() if ln.startswith(prefix)]
    if len(hits) != 1:
        raise AssertionError(f"expected exactly one line starting with {prefix!r}, found {len(hits)}")
    return hits[0]


class TestS2aH1Retitle(unittest.TestCase):
    """4c S2a (d): a migrated H1 that names the source file must be retitled."""

    def setUp(self) -> None:
        self.text = COMMAND.read_text(encoding="utf-8")
        self.matrix = section(self.text, "#### 4c:", "#### 4d:")

    def test_s2a_row_mandates_retitle_when_h1_names_the_file(self) -> None:
        self.assertIn(
            "원본 파일명을 지칭",
            self.matrix,
            "4c S2a lost the rule that an H1 naming the source file is retitled",
        )
        self.assertIn("`# AGENTS.md`로 재제목", self.matrix)

    def test_retitle_rule_lives_in_the_s2a_row_not_elsewhere(self) -> None:
        s2a = self.matrix[self.matrix.index("**S2a**"):self.matrix.index("**S2b**")]
        self.assertIn("재제목", s2a, "retitle rule drifted out of the S2a row")

    def test_project_titles_are_still_preserved(self) -> None:
        """The rule must stay narrow: only a filename-naming H1 is rewritten."""
        self.assertRegex(
            self.matrix,
            r"`# My Project`.*비-관리 컨텐츠로 보존",
            "the narrowing clause that preserves real project titles is gone",
        )

    def test_preservation_rule_declares_the_h1_exception(self) -> None:
        """The blanket 'preserve non-managed content' line must name its exception.

        Scoped to that standalone line — not to the whole 4c section — because the
        same opening words are quoted inside the S2a table cell.
        """
        rule = standalone_line(self.text, "비-관리 컨텐츠 (다른 헤딩")
        self.assertIn(
            "파일명을 지칭하는 제목은 이전 후 대상 파일을 잘못 가리키므로",
            rule,
            "the preservation rule no longer discloses the S2a (d) H1 exception",
        )


class TestMigrationPromptStillGated(unittest.TestCase):
    """AC21: refusing the CLAUDE.md→AGENTS.md migration aborts the whole run."""

    def test_refusal_aborts_entire_run(self) -> None:
        text = COMMAND.read_text(encoding="utf-8")
        step1 = section(text, "### Step 1:", "### Step 2:")
        self.assertRegex(
            step1,
            r"사용자 거절 시.*전체 `/project-init` 실행 abort",
            "the migration refusal no longer aborts the run",
        )
        self.assertIn("부분 진행 금지", step1)


if __name__ == "__main__":
    unittest.main()
