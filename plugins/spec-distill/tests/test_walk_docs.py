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
import human_lines as H
import walk_table as W
import conductor_toc as TOC
from test_team_docs import changelog_entries

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
                     "TMPDIR=<이 agent 폴더>", "Spec: <설계 파일>"):
            self.assertIn(word, block, word)
        start = self.TEXT.index("### team 형식 — 계획 · 구현 담당자")
        rest = self.TEXT[start + 1:]
        ends = [i for i in (rest.find("\n### "), rest.find("\n## ")) if i >= 0]
        section = rest[:min(ends)] if ends else rest
        self.assertNotIn("## 마지막 보고", block)
        self.assertNotIn("`## 마지막 보고` 절을 펜스 뒤에 그대로 붙인다", section)
        self.assertIn("펜스 뒤에 `## 마지막 보고` 절을 붙이지 않는다 — 보고는 과제 폴더 `results/` 의 결과 파일 줄이다(세션 길 · 하위 agent 길 모두).", section)

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
            then = fence_under(old, heading)
            if heading == "### 이어 부르기":
                want = then
            else:   # 기준 틀에 금지 줄의 그 한 구절만 끼운 것과 바이트로 같다 — 양성 대조: 옛 블록에 그 구절이 정확히 한 번 있다
                self.assertEqual(then.count("HEAD 뒤로 옮기기."), 1, heading)
                want = then.replace("HEAD 뒤로 옮기기.", "HEAD 뒤로 옮기기 · 기계 상태의 확인한 끝 절과 상태 브랜치 쓰기.", 1)
            self.assertEqual(fence_under(self.TEXT, heading), want, heading)


POINTER = "team 형식 로드맵이면 `<SD>/references/conducting-team.md` 를 따른다"


def team_section(text):
    text = "\n" + text   # team 지시서는 그 절 머리로 시작한다
    return text.split("\n## team 형식 로드맵\n", 1)[1].split("\n## ", 1)[0] if "\n## team 형식 로드맵\n" in text else ""


_TOC = TOC.load(PLUGIN)
_NAMED = [PLUGIN / TOC.TOC_REL] + [TOC.resolve(PLUGIN, sd) for sd in TOC.named_files(_TOC)]
_TEAM_FILE = next(TOC.resolve(PLUGIN, e.guide) for e in _TOC.extras if e.guide.endswith("/conducting-team.md"))


def step(text, n):
    body = text.split("\n### %d. " % n, 1)[1]
    return body.split("\n### ", 1)[0].split("\n## ", 1)[0]


class ConductingTeam(unittest.TestCase):   # R2 AC17 · AC16 · AC23
    TEXT = "".join(p.read_text(encoding="utf-8") for p in _NAMED)   # 차례 + 이름 붙은 지시서(차례의 차례대로)
    TEAM = team_section(_TEAM_FILE.read_text(encoding="utf-8"))

    def test_five_seats_and_the_walk_first(self):
        for seat in ("방향 확인", "설계 대화와 승인", "계획 확인", "구현 중 물음", "PR 전 확인"):
            self.assertIn("| %s |" % seat, self.TEAM, seat)
        for word in ("scripts/walk_table.py next --roadmap <로드맵> --job <과제>", "걸음표를 따른다", "다음 걸음의 칸으로",
                     "conductor-dispatch.md` 의 `### team 형식 — 계획 · 구현 담당자",
                     "ledger ask-head --human <종류> --roadmap <로드맵> --job <과제>", "ledger record --human <종류> --roadmap <로드맵> --job <과제>",
                     "ledger human-check --roadmap <로드맵> --job <과제>", "그대로 보인다", "계획이 나올 때마다", "목록으로 보이고",
                     "실행 방식은 그 칸으로 답한다"):
            self.assertIn(word, self.TEAM, word)
        self.assertIn("본 테스트 실패 이름과 쓴 미리 받은 답이 결과 파일의 글(기계가 읽지 않는 줄)에 있어", self.TEAM)
        self.assertNotIn("--approval", self.TEAM)
        self.assertNotIn("--choice", self.TEAM)

    def test_team_send_does_not_attach_last_report(self):
        self.assertNotIn("`## 마지막 보고` 절을 그대로 붙인다", self.TEAM)
        for word in ("`## 마지막 보고` 절을 붙이지 않는다", "멈춤 파일", "`## 세션 담당자`"):
            self.assertIn(word, self.TEAM, word)

    def test_stage_and_plan_come_from_the_next_step_name(self):   # 걸음 보기의 다음 걸음 줄에는 단계 · 계획 번호 칸이 없다
        for word in ("계획 → plan", "(계획 n)"):
            self.assertIn(word, self.TEAM, word)

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

    def test_team_guide_carries_the_three_handed_over_items(self):   # R3 설계 §1.7 — 넘겨받은 셋
        team = _TEAM_FILE.read_text(encoding="utf-8")
        for word in ("받음 줄", "검수 묶음", "`<SD>/references/conducting-step-5.md` 의 「승인 기록 다시 보이기」",
                     "confirm --confirmed",
                     "작업 방식과 도구는 걸음 보기(`walk_table.py next`)가 낸 칸을 쓴다 — 걸음 지시서의 부를 skill 칸은 옛 형식의 값이다"):
            self.assertIn(word, team, word)
        self.assertIn("승인 기록 다시 보이기", step(self.TEXT, 5))   # 가리키는 자리가 실재한다

    def test_conducting_team_is_named_only_under_the_team_condition(self):   # AC5 — 옛 형식 로드맵에서는 읽으라고 하지 않는다
        self.assertEqual(unconditioned(self.TEXT), [])
        mutated = self.TEXT + "\n- 이 줄은 `<SD>/references/conducting-team.md` 를 읽는다\n"   # 양성 대조 — 조건 글 없는 줄을 잡는다
        self.assertEqual(len(unconditioned(mutated)), 1)


def unconditioned(text):
    return [l for l in text.splitlines() if "conducting-team.md" in l and "team 형식" not in l and "layout: team" not in l]


class ReviewProfile(unittest.TestCase):   # R2 AC18 · K19
    def test_scope_axis_flags_unmarked_decisions(self):
        text = (REF / "docreview-profiles/design-doc.md").read_text(encoding="utf-8")
        scope = next(l for l in text.splitlines() if l.startswith("- `scope` — "))
        for word in ("「작성자 제안」", "근거가 없", "표시도 없는 결정"):
            self.assertIn(word, scope, word)


NEW_P8 = ("정석 흐름(brainstorming → 계획 → 구현)의 걸음 안은 모델이 판단한다. 사람이 정하는 자리(설계 승인 · 계획 확인)를 건너뛰지 못하게 "
          "하는 것은 정확성 게이트라 스크립트가 지키고, 사람이 승인하면 건너뛰거나 바꾼다. 게이트가 재는 것은 모델이 적은 줄이 아니라 사람이 한 것이다.")
OLD_P8 = "정석 흐름(brainstorming → 계획 → 구현)의 의도는 지키되 순서를 강제하는 결정론은 두지 않는다."
NEW_CLAUDE = "결정론은 보안 · 정확성 게이트에만 — 사람이 정하는 자리를 지키는 관문이 그 게이트다(철학 P8)."
OLD_CLAUDE = "결정론은 보안 · 정확성 게이트에만(철학 P8)."


class Philosophy(unittest.TestCase):   # R2 AC19 — §7 의 문장 그대로
    def test_p8_flow_line(self):
        text = (REPO / "docs/philosophy/devbrew-harness-philosophy.md").read_text(encoding="utf-8")
        flow = [l for l in text.splitlines() if l.startswith("- (흐름) ")]
        self.assertEqual(len(flow), 1)
        self.assertIn(NEW_P8, flow[0])
        self.assertNotIn(OLD_P8, text)
        self.assertNotIn("순서를 강제하는 결정론", text)   # 뜻으로 — 옛 문장의 가운데 말

    def test_claude_md_bullet(self):
        text = (REPO / "CLAUDE.md").read_text(encoding="utf-8")
        line = next(l for l in text.splitlines() if l.startswith("- **기본값과 판단.**"))
        self.assertIn(NEW_CLAUDE, line)
        self.assertNotIn(OLD_CLAUDE, text)


class Docs(unittest.TestCase):   # R2 AC22 — 계획 2 몫
    def test_team_files_documents_the_walk_table(self):
        text = (REF / "team-files.md").read_text(encoding="utf-8")
        for word in ("### 걸음표", "references/walk-table.md", "walk_table", "walk_table.py next --roadmap <로드맵> --job <과제>",
                     "walk_table.py check", "관문은 이 표로 바뀌지 않는다", "기본 표로 넘어가지 않는다", "계획 n/m",
                     H.LATER_ANSWER, H.NOT_TOUCHED, "(끝남)", "다음 걸음의 칸으로") + W.COLUMNS:
            self.assertIn(word, text, word)

    def test_readme_and_changelog(self):
        readme = (PLUGIN / "README.md").read_text(encoding="utf-8")
        for word in ("walk_table", "walk_table.py next", "걸음표"):
            self.assertIn(word, readme, word)
        sections = [body for ver, body in changelog_entries((PLUGIN / "CHANGELOG.md").read_text(encoding="utf-8"))
                    if ver == (8, 27, 0)]
        self.assertEqual(len(sections), 1)   # 걸음표가 들어온 판의 절 — 지금 판으로 고르면 다음 판 올림에 다른 절을 본다
        for word in ("walk_table", "walk_table.py", "걸음표", "conductor-dispatch.md", "P8"):
            self.assertIn(word, sections[0], word)


if __name__ == "__main__":
    unittest.main()
