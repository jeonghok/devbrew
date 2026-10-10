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
            "> 다음 할 일: 새 브랜치를 하나 만들어 보라 — `git checkout -b feature/<이름>` 이면 훅이 이름을 바로 확인한다.")
        self.assertEqual(sum(1 for ln in self.block if ln.startswith("> 다음 할 일:")), 1)

    def test_old_lines_are_gone(self):
        joined = "\n".join(self.block)
        self.assertTrue(joined, "보고 블록이 비었다 — 아래 부재 단언이 공허하다")
        self.assertNotIn("초기화 완료", joined)
        self.assertNotIn("16+ 벤더", joined)
        self.assertNotIn("/commit-push-pr", joined)


if __name__ == "__main__":
    unittest.main()
