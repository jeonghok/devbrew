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
                     "TMPDIR=<이 agent 폴더>", "Spec: <설계 파일>", "이 글 끝에 붙은 `## 마지막 보고`"):
            self.assertIn(word, block, word)
        start = self.TEXT.index("### team 형식 — 계획 · 구현 담당자")
        rest = self.TEXT[start + 1:]
        ends = [i for i in (rest.find("\n### "), rest.find("\n## ")) if i >= 0]
        section = rest[:min(ends)] if ends else rest
        self.assertIn("`## 마지막 보고` 절을 펜스 뒤에 그대로 붙인다", section)

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


POINTER = "team 형식 로드맵이면 아래 `## team 형식 로드맵` 절을 따른다"


def team_section(text):
    return text.split("\n## team 형식 로드맵\n", 1)[1].split("\n## ", 1)[0] if "\n## team 형식 로드맵\n" in text else ""


def step(text, n):
    body = text.split("\n### %d. " % n, 1)[1]
    return body.split("\n### ", 1)[0].split("\n## ", 1)[0]


class ConductingTeam(unittest.TestCase):   # R2 AC17 · AC16 · AC23
    TEXT = (REF / "conducting.md").read_text(encoding="utf-8")
    TEAM = team_section(TEXT)

    def test_five_seats_and_the_walk_first(self):
        for seat in ("방향 확인", "설계 대화와 승인", "계획 확인", "구현 중 물음", "PR 전 확인"):
            self.assertIn("| %s |" % seat, self.TEAM, seat)
        for word in ("scripts/walk_table.py next --roadmap <로드맵> --job <과제>", "걸음표를 따른다", "다음 걸음의 칸으로",
                     "conductor-dispatch.md` 의 `### team 형식 — 계획 · 구현 담당자",
                     "ledger ask-head --human <종류> --roadmap <로드맵> --job <과제>", "ledger record --human <종류> --roadmap <로드맵> --job <과제>",
                     "ledger human-check --roadmap <로드맵> --job <과제>", "그대로 보인다", "계획이 나올 때마다", "목록으로 보이고",
                     "실행 방식은 그 칸으로 답한다"):
            self.assertIn(word, self.TEAM, word)
        self.assertNotIn("--approval", self.TEAM)
        self.assertNotIn("--choice", self.TEAM)

    def test_section_sits_before_the_manual_steps(self):   # test_conducting_loop.sh:11 과 같은 사실을 여기서도
        heads = [l for l in self.TEXT.splitlines() if l.startswith("## ")]
        self.assertEqual(heads[-2:], ["## team 형식 로드맵", "## 손으로 따르는 절차"])

    def test_one_pointer_per_step_before_the_skill_cell(self):   # AC21 · K17 — 걸음마다 「- 부를 skill:」 바로 앞
        self.assertIn("ledger record --spec <설계문서> --approval --date <YYYY-MM-DD> --choice", self.TEXT)   # 옛 형식 줄은 그대로
        for n in (2, 3, 4, 5):
            lines = step(self.TEXT, n).splitlines()
            at = [i for i, l in enumerate(lines) if POINTER in l]
            self.assertEqual(len(at), 1, n)
            self.assertTrue(lines[at[0] + 1].startswith("- 부를 skill:"), n)
        for n in (1, 6, 7):
            self.assertNotIn(POINTER, step(self.TEXT, n), n)

    def test_gate_docs_carry_the_head_record_human_and_the_off_path(self):
        for path in (REF / "proceed-gate.md", PLUGIN / "skills/spec-review/SKILL.md", PLUGIN / "skills/epic-conductor/SKILL.md"):
            self.assertIn("ask-head", path.read_text(encoding="utf-8"), path.name)
        for path in (REF / "proceed-gate.md", PLUGIN / "skills/spec-review/SKILL.md"):
            text = path.read_text(encoding="utf-8")
            self.assertIn('record --human "spec 승인"', text, path.name)
            self.assertIn("human_gate: 끔", text, path.name)


class ReviewProfile(unittest.TestCase):   # R2 AC18 · K19
    def test_scope_axis_flags_unmarked_decisions(self):
        text = (REF / "docreview-profiles/design-doc.md").read_text(encoding="utf-8")
        scope = next(l for l in text.splitlines() if l.startswith("- `scope` — "))
        for word in ("「작성자 제안」", "근거가 없", "표시도 없는 결정"):
            self.assertIn(word, scope, word)


if __name__ == "__main__":
    unittest.main()
