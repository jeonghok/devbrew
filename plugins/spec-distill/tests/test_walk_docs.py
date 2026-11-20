"""걸음표 · 걸음 보기 · 보내는 글 틀 · 지휘 절차의 team 절 문서 검사."""
from __future__ import annotations

import re
import subprocess
import sys
import unittest
from pathlib import Path

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE.parent / "scripts"))
sys.path.insert(0, str(_HERE))
PLUGIN = _HERE.parent
REF = PLUGIN / "references"
REPO = PLUGIN.parents[1]

TAIL_SENTENCES = ("시작 묶음 명령이 0 이 아닌 종료 코드로 끝나면 일하지 않고 그 사유를 돌려보낸다",
                  "설계의 글자 · 수용 기준 · 사용자에게 보이는 동작에 닿는 물음은 스스로 정하지 않고 멈춰 돌려보낸다")
ALLOWED = {"<SD>", "<로드맵>", "<과제>", "<단계>", "<n>", "<역할>", "<작업 방식>", "<브랜치>", "<백업 경로 | 없음>",
           "<에픽 worktree 절대경로>", "<스위트 잠금 경로>", "<이 agent 이름>", "<초>", "<스위트 명령>", "<이 agent 폴더>", "<설계 파일>"}
BASE = "3b4e582a"   # 계획 2 가 시작한 기본 브랜치 커밋 — 옛 틀의 견줌 기준


def fence_under(text, heading):
    body = text.split("\n" + heading + "\n", 1)[1]
    return body.split("```text\n", 1)[1].split("\n```", 1)[0]


class DispatchTemplate(unittest.TestCase):   # R2 AC16 · AC21
    TEXT = (REF / "conductor-dispatch.md").read_text(encoding="utf-8")

    def test_team_template_is_one_command_and_the_fixed_tail(self):
        block = fence_under(self.TEXT, "### team 형식 — 계획 · 구현 담당자")
        first = block.splitlines()[0]
        self.assertTrue(first.startswith('python3 "<SD>"/scripts/start_bundle.py --roadmap <로드맵> --job <과제> --stage <단계>'), first)
        for flag in ("--plan <n>", "--role <역할>"):
            self.assertIn(flag, first)
        for s in TAIL_SENTENCES:
            self.assertIn(s, block)
        for word in ("git switch --ignore-other-worktrees <브랜치>", "「브랜치 그대로 두기」(3번)", "기준 브랜치 <브랜치>",
                     "작업 방식: <작업 방식>", "실행 방식은", "check_bundle_coverage.py --plan", "가벼운 다시 확인",
                     "AC<번호>: 구현됨 | 미룸 | 빠짐", "suite_lock.py run --lock <스위트 잠금 경로>", "git stash",
                     "TMPDIR=<이 agent 폴더>", "Spec: <설계 파일>", '"<SD>"/references/conductor-dispatch.md 의 `## 마지막 보고`'):
            self.assertIn(word, block, word)

    def test_no_slot_for_describing_the_job(self):
        block = fence_under(self.TEXT, "### team 형식 — 계획 · 구현 담당자")
        self.assertEqual(set(re.findall(r"<[^<>\n]+>", block)) - ALLOWED - {"<번호>"}, set())
        old = fence_under(self.TEXT, "### 계획 agent")                       # 양성 대조 — 찾는 식이 칸을 잡는다
        self.assertIn("<이유>", set(re.findall(r"<[^<>\n]+>", old)) - ALLOWED)

    def test_old_templates_do_not_change(self):   # AC21
        for heading in ("### 계획 agent", "### 구현 agent"):
            block = fence_under(self.TEXT, heading)
            self.assertNotIn("start_bundle", block, heading)
            self.assertTrue(block.startswith("너는 <에픽> 의 "), heading)
        got = subprocess.run(["git", "show", "%s:plugins/spec-distill/references/conductor-dispatch.md" % BASE],
                             cwd=str(REPO), stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        if got.returncode != 0:
            self.skipTest("기준 커밋 %s 을 읽지 못했다(얕은 클론) — 옛 세 틀의 바이트 견줌을 건너뛴다" % BASE)
        old = got.stdout.decode("utf-8")
        for heading in ("### 계획 agent", "### 구현 agent", "### 이어 부르기"):
            self.assertEqual(fence_under(self.TEXT, heading), fence_under(old, heading), heading)


if __name__ == "__main__":
    unittest.main()
