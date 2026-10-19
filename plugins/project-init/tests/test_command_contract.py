"""Regression lock on `skills/project-init/SKILL.md` prose contracts.

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

import ast
import json
import re
import unittest
from pathlib import Path

PLUGIN = Path(__file__).resolve().parents[1]
COMMAND = PLUGIN / "skills" / "project-init" / "SKILL.md"
HOOKS_JSON = PLUGIN / "hooks" / "hooks.json"

#: 인용 블록 안의 코드 스팬. 보고 블록이 «무엇을 만들었는지» 와 «훅이 무엇을 검사하는지»
#: 를 둘 다 이 표기로 적으므로, 두 집합의 교집합이 곧 「만든 문서를 사후 검증한다」는
#: 약속이 된다.
CODE_SPAN = re.compile(r"`([^`]+)`")


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


def _report_block(text: str) -> list[str]:
    """Step 5 완료 보고 인용 블록의 `>` 줄 전부.

    앵커를 「생성/업데이트된 파일:」 불릿 머리로 잡고 인용 블록의 양끝까지 넓힌다.
    줄 번호나 주변 헤딩으로 잡지 않는 이유는 그것이 편집마다 움직이기 때문이다.
    """
    lines = text.splitlines()
    heads = [i for i, ln in enumerate(lines) if ln.startswith("> 생성/업데이트된 파일:")]
    if len(heads) != 1:
        raise AssertionError(f"보고 블록 앵커가 유일하지 않다: {len(heads)}건")
    start = heads[0]
    while start > 0 and lines[start - 1].startswith(">"):
        start -= 1
    end = heads[0]
    while end < len(lines) and lines[end].startswith(">"):
        end += 1
    return lines[start:end]


def _shipped_post_tool_use_scripts() -> set[str]:
    """`hooks.json` 이 실제로 등록한 `PostToolUse` 스크립트 파일명."""
    entries = json.loads(HOOKS_JSON.read_text(encoding="utf-8"))["hooks"]["PostToolUse"]
    scripts = {
        Path(h["command"].split()[-1]).name
        for e in entries for h in e.get("hooks", [])
    }
    return scripts


def _shipped_validator_subjects() -> set[str]:
    """배포되는 `PostToolUse` 훅들이 실제로 가진 검증 주제 (`validate_*` 에서 도출).

    리터럴로 적지 않고 훅 자신에서 **도출한다** — 이 락이 재는 것은 「산문이 훅보다
    많은 것을 약속하지 않는다」이고, 비교 대상을 테스트가 손으로 적으면 훅이 줄어들
    때 락이 함께 줄지 않는다(락의 앵커를 피검자가 아니라 상수가 쥐게 된다).
    """
    subjects: set[str] = set()
    for name in sorted(_shipped_post_tool_use_scripts()):
        path = PLUGIN / "hooks" / name
        if not path.exists():
            continue
        tree = ast.parse(path.read_text(encoding="utf-8"))
        subjects |= {
            n.name[len("validate_"):] for n in ast.walk(tree)
            if isinstance(n, ast.FunctionDef) and n.name.startswith("validate_")
        }
    return subjects


class TestCompletionReportPromisesOnlyWhatShips(unittest.TestCase):
    """A23 — 완료 보고가 **사후 플래그를 약속하지 않는다**.

    이 플러그인의 `PostToolUse` 훅은 `Bash` 호출에만 발화하고 Bash payload 에는
    파일 내용이 없다. 그러므로 「위에서 만든 문서를 훅이 사후에 검증한다」는 문장은
    무엇으로 표현하든 구조적으로 거짓이다. 그 약속을 하던 검사들(`docs-lint.py` 가
    수행하던 크기·목차·코드펜스·링크·drift·헌장 필수항목)은 이 릴리스에서
    **삭제**됐고 대체 훅·테스트·게이트가 없다 — CHANGELOG 의 Removed 항목이 그렇게
    적고 있다.

    **앵커는 문자열 `docs-lint` 가 아니다.** 그 문자열로 스윕한 앞선 라운드가 정확히
    이 문장을 놓쳤다 — 문장이 그 이름을 한 번도 담지 않았기 때문이다. 그래서 두 축을
    쓰되 둘 다 배포본에서 **도출한다**:

      · 축 A — 보고 블록의 검증 주장 줄이, **같은 보고 블록이 만들었다고 적은 산출물**
        (파일명·섹션 제목)을 하나라도 이름으로 대면 위반. 「만든 것을 사후 검증한다」의
        정의 그 자체다.
      · 축 B — 검증 주장 절이 열거하는 주제 묶음 수가, 배포되는 훅이 실제로 가진
        `validate_*` 수를 넘으면 위반. 축 A 는 코드 스팬으로 이름 대지 않은 약속
        (예: 괄호로 나열한 문서 컨벤션)을 못 잡는데, 그 절반을 이 축이 잡는다.
      · 축 C — 「그 둘이 전부」라는 부인이 남아 있어야 한다. 축 A·B 는 둘 다 **부재**
        검사라, 그 문장을 통째로 지워 버리면 함께 통과한다.
      · 축 D — 검증 주장 줄의 **개수**가 배포된 `PostToolUse` 스크립트 수를 넘지 않는다.
        축 A~C 는 전부 **기존 줄**을 본다 — 부인을 그대로 둔 채 **새 줄**로 약속을
        덧붙이면 셋 다 통과한다(실측 확인). 훅이 하나면 그 능력을 서술하는 줄도 하나다.

    남는 구멍은 하나다: 코드 스팬 없이, `+` 없이, **기존 그 한 줄 안에서** 약속을
    늘리는 편집. 그것은 부인 문장과 같은 줄에서 서로 모순되게 되므로 사람 리뷰에
    걸리는 모양이고, 기계로 더 좁히려면 자연어 함의 판정이 필요하다.
    """

    def setUp(self) -> None:
        self.block = _report_block(COMMAND.read_text(encoding="utf-8"))
        self.produced = {
            span for ln in self.block if ln.startswith("> - ")
            for span in CODE_SPAN.findall(ln)
        }
        self.claims = [
            ln for ln in self.block
            if not ln.startswith("> - ")
            and ("hook" in ln or "훅" in ln) and "검증" in ln
        ]

    def test_preconditions_the_axes_have_something_to_measure(self) -> None:
        """양성 대조 — 두 축의 정의역이 비면 아래 부재 검사는 공허하게 통과한다."""
        self.assertTrue(
            self.produced,
            "보고 블록이 만든 산출물을 더 이상 열거하지 않는다 — 축 A 가 공허하다")
        self.assertTrue(
            self.claims,
            "보고 블록이 훅 검증을 더 이상 서술하지 않는다 — 축 B 가 공허하다")
        self.assertTrue(
            _shipped_validator_subjects(),
            "배포 훅에서 validate_* 를 하나도 못 찾았다 — 축 B 의 상계가 0 이 된다")

    def test_axis_a_no_claim_names_a_document_this_command_produces(self) -> None:
        for claim in self.claims:
            overlap = set(CODE_SPAN.findall(claim)) & self.produced
            self.assertEqual(
                overlap, set(),
                msg=("완료 보고가 «이 커맨드가 만든 산출물»을 훅이 사후 검증한다고 "
                     f"약속한다: {sorted(overlap)} — 훅은 Bash 호출에만 발화하고 "
                     f"Bash payload 에는 파일 내용이 없다. 줄: {claim!r}"))

    def test_axis_b_claim_enumerates_no_more_than_the_hook_validates(self) -> None:
        cap = len(_shipped_validator_subjects())
        for claim in self.claims:
            groups = claim.split("자동 검증")[0].split(" + ")
            self.assertLessEqual(
                len(groups), cap,
                msg=(f"완료 보고가 배포 훅의 validate_* {cap}개보다 많은 "
                     f"{len(groups)}묶음을 검증 대상으로 약속한다: {groups!r}"))

    def test_axis_c_the_disclaimer_survives(self) -> None:
        """부인 문장 — 축 A·B 가 둘 다 부재 검사라 이 양의 짝이 필요하다."""
        joined = "\n".join(self.claims)
        self.assertIn(
            "그 둘이 이 hook이 검사하는 전부입니다", joined,
            "훅이 검사하는 범위의 상한을 밝히는 부인이 사라졌다")
        self.assertIn(
            "사후에 검증하는 것은 없습니다", joined,
            "생성 문서의 사후 검증이 없다는 부인이 사라졌다")

    def test_axis_d_claim_line_count_does_not_exceed_shipped_hooks(self) -> None:
        """부인을 남긴 채 **새 줄**로 약속을 덧붙이는 편집을 잡는다."""
        cap = len(_shipped_post_tool_use_scripts())
        self.assertLessEqual(
            len(self.claims), cap,
            msg=(f"배포된 PostToolUse 스크립트는 {cap}개인데 완료 보고의 훅-검증 "
                 f"주장 줄이 {len(self.claims)}개다 — 없는 훅의 능력을 서술하고 있다: "
                 f"{self.claims!r}"))


class TestMigrationRefusalChoices(unittest.TestCase):
    """AC32 — 이전 거절이 실행 전체를 멈추지 않는다(옛 AC21 「부분 진행 금지」 폐지)."""

    def setUp(self):
        self.text = COMMAND.read_text(encoding="utf-8")
        self.step1 = section(self.text, "### Step 1:", "### Step 2:")
        self.matrix = section(self.text, "#### 4c:", "#### 4d:")

    def test_s2_offers_three_choices(self):
        for label in ("「AGENTS.md 로 옮기기 (권장)」", "「CLAUDE.md 에 바로 쓰기」", "「중단」"):
            self.assertIn(label, self.step1)

    def test_git_workflow_files_continue(self):
        self.assertIn("`docs/git-workflow/` 파일은 그대로 만든다", self.step1)

    def test_old_whole_run_abort_is_gone(self):
        self.assertTrue(self.step1.strip())
        self.assertNotIn("부분 진행 금지", self.step1)
        self.assertNotRegex(self.step1, r"사용자 거절 시.*전체 `/project-init:project-init` 실행 abort")
        s2 = self.matrix[self.matrix.index("**S2 (CLAUDE-only legacy)**"):self.matrix.index("**S3 (")]
        self.assertNotIn("거절 시 전체", s2)
        self.assertIn("「CLAUDE.md 에 바로 쓰기」", s2)

    def test_s4_offers_keep_claude_md(self):
        s4 = self.matrix[self.matrix.index("**S4 ("):]
        for label in ("「옮기기 (권장)」", "「CLAUDE.md 는 그대로 두기」", "「중단」"):
            self.assertIn(label, s4)

    def test_charter_detection_reads_the_canonical_file(self):
        detect = section(self.text, "#### Charter 상태 감지", "### Step 2:")
        self.assertIn("「CLAUDE.md 에 바로 쓰기」를 고른 실행에서는 CLAUDE.md", detect)
        self.assertIn("AGENTS.md 가 있으면 AGENTS.md, 없으면 CLAUDE.md", detect)

    def test_git_rules_detection_reads_the_canonical_file(self):
        # 「git 규칙은 그대로 두고 헌장만」 + 「AGENTS.md 로 옮기기」 뒤 재실행에서 기존 `## Git Workflow` 는
        # AGENTS.md 에 산다. CLAUDE.md 만 보면 감지가 비어 S3 action 이 그 절을 덮는다. 거꾸로 S4
        # (AGENTS.md 가 있고 CLAUDE.md 가 포인터가 아님)에서는 그 절이 CLAUDE.md 에만 있을 수 있다 —
        # 두 파일을 모두 본다.
        detect = section(self.step1, "### Step 1:", "기존 Git Workflow 설정이 발견되면")
        self.assertIn("AGENTS.md 와 CLAUDE.md 가 각각 존재하는지", detect)
        self.assertIn("AGENTS.md 와 CLAUDE.md 중 어느 쪽에 있어도 기존 규칙이다", detect)
        self.assertNotIn("존재한다면 `## Git Workflow` 섹션이 이미 있는지", detect)
        self.assertNotIn("그 파일에 `## Git Workflow` 섹션이 이미 있는지", detect)

    def test_s4_old_abort_is_gone(self):
        s4 = self.matrix[self.matrix.index("**S4 ("):]
        self.assertIn("「CLAUDE.md 는 그대로 두기」", s4)
        self.assertNotIn("(ii) abort", s4)

    def test_s2a_moves_the_charter_section_too(self):
        s2 = self.matrix[self.matrix.index("**S2 (CLAUDE-only legacy)**"):self.matrix.index("**S3 (")]
        self.assertIn("`## Git Workflow` 섹션과 `## Project Charter` 섹션(있으면, 관리 섹션이다) 추출", s2)

    def test_template_target_names_claude_md_case(self):
        step4e = section(self.text, "#### 4e:", "### Step 5:")
        self.assertIn("`AGENTS.md`(「CLAUDE.md 에 바로 쓰기」를 고른 실행에서는 CLAUDE.md)의", step4e)

    def test_step4_canonical_line_has_exception(self):
        step4 = section(self.text, "### Step 4:", "#### 4a:")
        self.assertIn("「CLAUDE.md 에 바로 쓰기」를 골랐다면 AGENTS.md 를 만들지 않고", step4)

    def test_step5_notes_direct_claude_md_write(self):
        step5 = self.text[self.text.index("### Step 5:"):]
        self.assertIn("CLAUDE.md 에 바로 썼다면: 관리 절이 CLAUDE.md 에 있다", step5)

    def test_step5_notes_kept_git_rules(self):
        step5 = self.text[self.text.index("### Step 5:"):]
        self.assertIn("git 규칙을 그대로 뒀다면: 브랜치 전략과 git 규칙 파일은 바꾸지 않았다", step5)

    def test_keep_git_choice_outranks_git_workflow_file_clauses(self):
        self.assertIn("그 선택이 이 문서에서 git 규칙 파일을 만든다는 모든 문장", self.step1)
        self.assertIn("바로 위 「CLAUDE.md 에 바로 쓰기」의", self.step1)
        gate = section(self.text, "#### Law 1 구조적 게이트", "### Step 4:")
        self.assertIn("「git 규칙 파일도 바꾸지 않았다.」로 바꾼다", gate)
        self.assertIn("S1 · S2b 는 헌장 절과 포인터만 쓴다", self.step1)


class TestGitWorkflowReplaceRefusal(unittest.TestCase):
    """설계에 없던 결정 1 — git 규칙 교체 거절이 헌장까지 멈추지 않는다."""

    def test_three_choices(self):
        step1 = section(COMMAND.read_text(encoding="utf-8"), "### Step 1:", "### Step 2:")
        git_para = section(step1, "기존 Git Workflow 설정이 발견되면", "또한 root에")
        for label in ("「교체 (권장)」", "「git 규칙은 그대로 두고 헌장만」", "「중단」"):
            self.assertIn(label, git_para)
        self.assertNotIn("사용자가 거절하면 중단.", step1)


class TestCharterGateChoice(unittest.TestCase):
    """AC31 — 재질문 3회 뒤 기계가 멈추지 않고 사용자가 고른다."""

    def setUp(self):
        self.text = COMMAND.read_text(encoding="utf-8")
        self.gate = section(self.text, "#### Law 1 구조적 게이트", "### Step 4:")

    def test_three_choices_after_three_asks(self):
        for label in ("「건너뛰기」", "「계속 묻기」", "「중단」"):
            self.assertIn(label, self.gate)
        self.assertIn("최대 3회", self.gate)

    def test_machine_abort_is_gone(self):
        self.assertTrue(self.gate.strip(), "게이트 절이 비었다 — 부재 단언이 공허하다")
        self.assertNotIn("abort", self.gate)
        self.assertNotIn("charter 미완료: <항목> 비어 abort", self.gate)

    def test_skip_discloses_incomplete_items(self):
        self.assertIn("[project-init] 헌장 단계를 건너뛰었다 — 미완 항목: <항목>", self.gate)

    def test_skip_writes_no_charter(self):
        self.assertIn("헌장 절과 `docs/project/` 파일을 쓰지 않는다", self.gate)
        step4e = section(self.text, "#### 4e:", "### Step 5:")
        self.assertIn("헌장 단계를 건너뛰지 않았다면", step4e)
        self.assertNotIn("abort(Law 1 게이트 실패)", step4e)


class TestQuestionDefaultsDisclosed(unittest.TestCase):
    """AC31 — 질문 4개 · 관례 1–3개는 기본값, 쓴 수를 공시하고 「더 묻기」로 연다."""

    def setUp(self):
        text = COMMAND.read_text(encoding="utf-8")
        self.phase1 = section(text, "#### Phase 1", "#### Law 1 구조적 게이트")

    def test_no_hard_cap_wording(self):
        self.assertTrue(self.phase1.strip())
        self.assertNotIn("≤4개", self.phase1)
        self.assertNotIn("4개만 묻는다", self.phase1)

    def test_disclosure_line_and_more_option(self):
        self.assertIn("헌장 질문 <n>개를 물었고(기본 4개) 관례 <m>개를 받았다(기본 1–3개)", self.phase1)
        self.assertIn("「이대로 진행 (권장)」", self.phase1)
        self.assertIn("「더 묻기」", self.phase1)
        for slot in ("{{GOALS}}", "{{SUCCESS_CRITERIA}}", "{{PERSONAS}}"):
            self.assertIn(slot, self.phase1)


class TestPhase0MayOverlap(unittest.TestCase):
    """AC31 — 질문 순서는 기본 직렬, 질문 없는 Phase 0 스캔은 겹쳐 돌 수 있다."""

    def test_serial_default_and_scan_overlap(self):
        text = COMMAND.read_text(encoding="utf-8")
        head = section(text, "### Step 3.5:", "#### Phase 0")
        self.assertIn("기본은 직렬", head)
        self.assertIn("Phase 0 스캔은 질문이 없으므로", head)
        self.assertNotIn("*모두 끝난 뒤* 시작한다", head)


if __name__ == "__main__":
    unittest.main()
