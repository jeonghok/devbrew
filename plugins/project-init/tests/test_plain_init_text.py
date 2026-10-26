"""쉬운 말 출력 PR 4 — project-init 이 사람에게 내는 보고 틀.

초기화 보고(SKILL Step 5)의 첫 줄은 무엇을 했는지 한 문장이고 맨 끝 줄은 사용자가 할 일 하나다.
부재 단언마다 같은 블록의 양성 짝이 있다.
"""
import unittest
from pathlib import Path

PLUGIN = Path(__file__).resolve().parents[1]
SKILL = PLUGIN / "skills" / "project-init" / "SKILL.md"


def report_block(text):
    lines = text.splitlines()
    heads = [i for i, ln in enumerate(lines) if ln.startswith("> 생성/업데이트된 파일:")]
    if len(heads) != 1:
        raise AssertionError("보고 블록 앵커가 유일하지 않다: %d건" % len(heads))
    start = end = heads[0]
    while start > 0 and lines[start - 1].startswith(">"):
        start -= 1
    while end < len(lines) and lines[end].startswith(">"):
        end += 1
    return lines[start:end]


class CompletionReportTest(unittest.TestCase):
    def setUp(self):
        self.block = report_block(SKILL.read_text(encoding="utf-8"))

    def test_first_line_says_what_was_done(self):
        self.assertEqual(self.block[0], "> **{strategy 이름}** 전략으로 git workflow 를 초기화했다.")

    def test_last_line_is_one_next_action(self):
        self.assertEqual(
            self.block[-1],
            "> 다음 할 일: 이 파일들을 커밋해 원격 기본 브랜치에 머지하고 받아 와라(`git fetch`) — 훅은 브랜치 이름 규칙을 "
            "`origin/HEAD` 판에서 읽는다. 이번 실행이 `docs/git-workflow/branch-strategy.md` 를 새로 만들었거나 바꿨다면 "
            "머지 전까지는 기본 브랜치에 있는 판으로 검사한다(그 판이 없으면 새 브랜치 이름을 확인하지 않고 규칙을 읽지 "
            "못했다고만 알리고, 옛 판이면 옛 규칙으로 검사한다). git 규칙을 그대로 뒀다면 훅은 기본 브랜치의 규칙으로 바로 "
            "검사한다(`origin/HEAD` 가 없으면 `git remote set-head origin --auto`, `origin` 원격이 없으면 먼저 원격을 더한다).")
        self.assertEqual(sum(1 for ln in self.block if ln.startswith("> 다음 할 일:")), 1)

    def test_no_promise_of_check_before_merge(self):
        """셋업 직후 규칙 파일은 기본 브랜치에 없다 — 훅이 바로 확인한다고 약속하지 않는다."""
        joined = "\n".join(self.block)
        self.assertIn("> 다음 할 일:", joined, "보고 블록에 할 일 줄이 없다 — 아래 부재 단언이 공허하다")
        self.assertNotIn("이름을 바로 확인한다", joined)

    def test_next_action_names_each_rule_state(self):
        """할 일 줄이 규칙 파일의 세 상태(새로 만듦 · 옛 판 · 그대로 둠)를 가른다 — 한 상태만 단정하지 않는다."""
        last = self.block[-1]
        self.assertTrue(last.startswith("> 다음 할 일:"), last)
        self.assertIn("새로 만들었거나 바꿨다면", last)
        self.assertIn("옛 판이면 옛 규칙으로 검사한다", last)
        self.assertIn("git 규칙을 그대로 뒀다면 훅은 기본 브랜치의 규칙으로 바로 검사한다", last)
        self.assertIn("`origin` 원격이 없으면", last)
        self.assertNotIn("그 전에는 새 브랜치 이름을 확인하지 않고", last, "조건 없이 「확인하지 않는다」고 단정하는 옛 문장")

    def test_old_lines_are_gone(self):
        joined = "\n".join(self.block)
        self.assertTrue(joined, "보고 블록이 비었다 — 아래 부재 단언이 공허하다")
        self.assertNotIn("초기화 완료", joined)
        self.assertNotIn("16+ 벤더", joined)
        self.assertNotIn("/commit-push-pr", joined)


README = PLUGIN / "README.md"


class ReadmeTest(unittest.TestCase):
    def setUp(self):
        self.text = README.read_text(encoding="utf-8")

    def test_lead_says_what_it_does(self):
        lead = " ".join(self.text.split("\n## ", 1)[0].split("\n", 1)[1].split())
        self.assertTrue(lead.startswith("프로젝트의 git 작업 규칙(브랜치 이름 · 커밋 메시지 · PR 절차)과 프로젝트 헌장을 "
                                        "짧은 대화로 만들어 준다."), lead[:80])
        self.assertIn("브랜치 이름과 커밋 메시지를 확인해 알려 준다(막지는 않는다).", lead)

    def test_principles_heading_is_the_canonical_one(self):
        lines = self.text.splitlines()
        self.assertEqual(lines.count("## Principles Instantiated"), 1)
        self.assertNotIn("## 인스턴스화한 원칙", lines)


if __name__ == "__main__":
    unittest.main()
