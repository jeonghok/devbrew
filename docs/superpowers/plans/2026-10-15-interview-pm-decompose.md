# R4 PM 분해 · 로드맵 · 에픽 묶음 · 재분해 경로 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 인터뷰 종료 때 「spec 하나로 / 나눈다」를 사용자가 정하고, 나누면 승인된 분해안 표로 R0 형식의 로드맵 · 에픽 묶음을 기계가 만들고 검증하며, 하류의 재분해 신호는 같은 지도 위에서 승인 뒤에만 다시 나눈다.

**Architecture:** 순수 렌더 모듈 `roadmap_render.py`(표 파싱 · 블록 · 묶음 · 로드맵 글 만들기 · 로드맵에서 표 거꾸로 뽑기)와 I/O 모듈 `roadmap_write.py`(create · update · extract, 쓰기 트랜잭션, `roadmap_status.py --json` 검증, 실패 시 원래 바이트 복원)로 나눈다. 형식 해석은 기존 `roadmap_status.py` · `check_bundle_coverage.py` · `section6.py` 를 import 해 다시 만들지 않는다. 인터뷰 · spec-review 쪽은 문면(finishing.md 의 분해 판단 단계, 새 참조 `redecompose.md`, 게이트 ③ 분기)과 그 문면 락이다.

**Tech Stack:** Python 3.9(레포 `python3` 는 3.9.6 — 3.9 문법만), bash 3.2 셸 테스트(`shared/tests/assert.sh`), git.

**Spec:** `docs/superpowers/specs/2026-10-15-interview-pm-decompose-design.md`

## Global Constraints

- 작업 위치는 worktree `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0`(브랜치 `r4-impl` → push 대상 `feature/interview-pm-decompose`). 모든 파일 경로는 이 절대경로 아래다. 다른 checkout 을 건드리지 않는다.
- 격리 가드가 git 이 섞인 복합 셸 명령을 막는다 — 여러 단계는 `~/.claude/sdd-mirror/r4-impl/` 아래 스크립트 파일로 쓰고 `bash <파일>` 로 돈다. 그 밖에는 `git -C <worktree> …` 단일 호출. Bash 도구 셸은 zsh 라 `PIPESTATUS` 가 없다.
- 외부 플러그인(superpowers 등)은 건드리지 않는다(C25 · C35 · D26).
- 있는 것을 다시 만들지 않는다(C32) — 형식 해석 · 검증은 `roadmap_status.py`, §6 은 `section6.body`, 번호 문법 · 절 읽기는 `check_bundle_coverage.py`.
- 분해 판단에 숫자 컷오프를 두지 않는다 — 신호를 보이고 사용자가 판정한다.
- 나누지 않는 일은 지금 흐름 그대로(brief 하나 → brainstorming 하나), 로드맵을 만들지 않는다.
- 생성 성공 조건: `roadmap_status.py --roadmap-file <로드맵> --json` 의 `format_errors` · `unassigned` · `orphans` · `unknown_ids` 넷이 모두 **목록이고 비었다**. 검사기 rc 는 성공 조건으로 쓰지 않는다. 실패면 만든 파일을 지우고 덮어쓴 파일은 원래 바이트로 되돌린 뒤 rc 1.
- 레포 락(새 스크립트 · 테스트가 걸린다):
  - `plugins/spec-distill/scripts/*.py` 의 모듈 수준 `re.compile` 리터럴이 `"## 6. 사용자 원문"` 맨 앞을 3글자 이상 맞히면 RED(`test_check_brief.sh` §6 단일화). 헤딩은 문자열 메서드나 `check_bundle_coverage.section_body` 로, §6 은 `section6.body` 로만 읽는다. `r".*"` · `r"^##\s"` 같은 일반 패턴 금지.
  - 모든 `open(` · `read_text(` · `write_text(` 에 `encoding="utf-8"`(qg `test_utf8_explicit.py` — 글자 검사라 `os.fdopen(` 도 `open(` 으로 걸릴 수 있다. 바이트 쓰기는 `os.write` 로).
  - `plugins/**/*.py` 에 `"python3"` 문자열 리터럴 금지(`shared/tests/test_python_floor.sh`) — 하위 프로세스는 `sys.executable`.
  - 20줄(200자 이상) 같은 블록이 plugins/* · shared/* 의 두 파일에 있으면 RED(`shared/tests/test_no_new_duplication.sh`) — 픽스처 brief 를 `test_roadmap_status.sh` 에서 복사하지 말고 다른 글로 쓴다.
  - 옛 식별자 토큰 금지(`test_review_hook_removed.py` — 예: `review-dispatch` · `parse_frontmatter` · `spec-template`).
  - 새 셸 테스트는 `chmod +x` 후 `git ls-files -s` 로 100755 확인.
  - CHANGELOG 새 머리는 바로 다음 버전, plugin.json 과 같게(`shared/tests/test_changelog_integrity.sh`).
- `PYTHONDONTWRITEBYTECODE=1` 로 python 을 돌린다(stale `.pyc` 함정). 스크립트 호출에 `-I` 를 붙이지 않는다(인라인 `python3 -c` 에만).
- 스위트 실행: 리포 루트에서 `bash ~/.claude/sdd-mirror/r4-impl/run_suite.sh <출력 파일>`(spec-distill · shared 전부, 실패 «이름» 정렬). 기준선 `~/.claude/sdd-mirror/r4-impl/baseline-before.txt` 의 선재 RED 둘(`test_hook_output_schema.py test_python_and_bash_resolvers_agree` · `test_review_hook_removed.py test_no_identifier_residue`) 밖의 새 실패 이름은 0 이어야 한다.
- 커밋 메시지: `<type>(spec-distill): <한국어 설명>` + 트레일러 셋:
  ```
  Spec: docs/superpowers/specs/2026-10-15-interview-pm-decompose-design.md
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01XKSh1VvN6kYTmLJS675MgX
  ```
  커밋은 경로 지정(`git add -- <경로들>`)으로만 한다.
- 버전: spec-distill 5.5.0 → 5.6.0(minor). 번호는 머지 직전에 다시 정할 수 있다.

## Review Focus

- 표 칸에 `|` 가 든 경우(범위 · 받는 것 문장) — 표가 깨지지 않고 왕복(쓰기 → 읽기)해야 한다. Task 1 의 `test_pipe_in_cell_round_trip`.
- macOS 임시 폴더(`/var/folders` → `/private/var`)처럼 심볼릭 링크 아래의 레포 — 묶음 frontmatter 의 `roadmap:` · `source_brief:` 는 절대경로가 아니라 레포 상대경로여야 하고 검사기와 같은 경로여야 한다. Task 2 셸 테스트의 frontmatter 단언(픽스처가 `mktemp -d` 아래).
- 첫 실행이 검증 실패로 되돌린 뒤 표를 고쳐 다시 도는 경우 — 남은 파일이 없으니 다시 돌면 성공해야 한다. Task 2 셸 테스트의 「실패 뒤 재실행」.
- 위험 줄(K)이 하나도 없는 brief — 위험 번호표는 `- 없음` 한 줄이고 검증을 통과해야 한다. Task 1 의 `test_roadmap_without_risks`.
- `origin/main` 이 없는 레포에서 update — 머지 여부를 모르므로 아무것도 쓰지 않고 rc 1. Task 3 셸 테스트의 「origin/main 없음」.

---

### Task 1: 렌더 모듈과 로드맵 틀 · 정답 견본 대조

**Files:**
- Create: `plugins/spec-distill/scripts/roadmap_render.py`
- Create: `plugins/spec-distill/templates/roadmap-template.md`
- Test: `plugins/spec-distill/tests/test_roadmap_render.py`
- Modify: `docs/superpowers/specs/2026-10-15-interview-pm-decompose-design.md`(`## 결정 기록` — 정답 견본 차이와 판정)

**Interfaces:**
- Consumes: `check_bundle_coverage.FormatError · bundle_ids · id_sort_key · parse_ids · section_body · frontmatter · unquote`, `roadmap_status.BLOCK_ID_RE · KEY_RE · OQ_LINE_RE · brief_universe · parse_roadmap`, `section6.body`.
- Produces (Task 2 · 3 이 쓴다):
  - `class TableError(ValueError)`
  - `TABLE_HEADING = "## 분해안"`, `COLUMNS`(열한 칸 튜플), `KIND_BUNDLE = "bundle"` · `KIND_BRANCH = "branch"` · `KIND_DECISION = "decision"`, `TEMPLATE: Path`
  - `@dataclass Row(id, title, kind, spec, intent, scope, deps, branch, reserved, ids: list, receives="없음", gives="없음")`
  - `parse_table(text: str) -> list[Row]` (TableError)
  - `format_table(rows) -> str`
  - `extract_rows(roadmap_text: str, read_bundle: Callable[[str], Optional[str]]) -> list[Row]` (TableError)
  - `@dataclass BriefIndex(lines: dict, k_lines: dict, goal: str, s6: str)`, `index_brief(brief: str, audit: str) -> BriefIndex` (FormatError)
  - `render_block(row) -> str` (끝 `\n`, 뒤 빈 줄 없음)
  - `render_bundle(row, idx, roadmap_rel, brief_rel, audit_rel) -> str` (TableError)
  - `render_roadmap(template, rows, idx, title, brief_rel, roadmap_rel, history) -> str`
  - `epic_block_texts(roadmap_text) -> dict[id, str]`, `replace_epics(roadmap_text, blocks: list[str]) -> str`, `append_history(roadmap_text, line: str) -> str`

정답 견본의 근거: R0 계획(`docs/superpowers/plans/2026-10-11-roadmap-walking-skeleton.md` Task 의 버리는 조립기 `assemble_bundles.py`)이 손으로 만든 묶음 10개를 만들었다. 그 조립기를 「조각 → 에픽」 이름만 바꿔 돌리면 R1~R5 · R7 · R8 · R2a 가 지금 파일과 바이트가 같고, R6 · R9 의 차이는 뒤에 고친 배정 · 인터페이스 문장(표의 데이터)뿐이다(계획 작성 때 실측). 그래서 이 모듈의 렌더 규칙은 그 조립기와 같다 — 번호는 `id_sort_key` 순, §2 C·D · §3 OQ(brief §0 결정 목록 줄) · §4 «key»(줄 중복 제거) · §5 RC 줄 → ST 줄 → K 줄.

- [ ] **Step 1: 로드맵 틀을 쓴다**

`plugins/spec-distill/templates/roadmap-template.md` — 아래 내용 그대로(마지막 줄 `{{RISKS}}` 뒤에 개행 하나):

````markdown
---
type: roadmap
source_brief: {{SOURCE_BRIEF}}
---

# {{TITLE}} — 로드맵

승인된 분해안의 에픽 지도다. 에픽마다 원본 brief · 이 로드맵 · 에픽 묶음을 넘긴다. 상태 칸은 없다 — 단계는 spec-distill 의 `scripts/roadmap_status.py` 가 git 에서 계산한다. 단위는 로드맵 > 에픽(spec 하나) > plan(PR 하나) > task 다.

## 에픽

{{EPICS}}
## 지휘 절차

지휘자 skill 이 생기기 전까지 지휘 세션이 따르는 절차다. 지휘 세션은 `/new` 뒤 첫 줄에 `@{{ROADMAP}}` 를 붙여 연다.

1. `git fetch origin` → spec-distill 의 `scripts/roadmap_status.py {{ROADMAP}}` → 작업 목록을 결과에 맞춘다. 에픽 하나에 작업 하나, 제목은 「<번호> <이름> — <단계>」. 대기 · 준비는 시작 전, 설계 중 · 계획은 진행 중, 머지됨 · 끝남은 완료다. 알 수 없음은 작업 상태를 바꾸지 않고 제목 끝에 「알 수 없음(이유)」을 붙인다. 종료 코드가 3 이면 작업 목록을 바꾸지 않고 「검사 불가」 사유를 사용자에게 그대로 보인다.
2. 준비 단계 에픽을 고른다. 블록의 `브랜치:` 이름으로 `origin/main` 에서 브랜치와 worktree 를 먼저 만들고, 그 에픽의 설계문서 · 계획은 모두 그 브랜치에 커밋한다. 설계(brainstorming → 설계문서 → spec-review 승인)는 한 세션 안에서 한 에픽씩 돈다 — spec 승인은 사용자가 에픽마다 한다.
3. 설계문서를 커밋한 뒤 spec-review 를 부르기 전에 spec-distill 의 `scripts/check_bundle_coverage.py <묶음> <설계문서>` 를 돌려 결과를 사용자에게 보인다. 빠진 번호가 있거나 종료 코드가 3 이면 고쳐 다시 돌리고, 0 이 나오기 전에는 spec-review 로 가지 않는다.
4. superpowers 가 묻는 자리(plan 검토 · 실행 방식 · 머지 메뉴)는 그대로 사용자에게 간다.
5. 구현은 에픽마다 worktree 에서 돌린다. SDD 가 마지막 메시지로 내는 판정 목록(「Rulings I made」)은 그대로 사용자에게 보이고 멈추지 않는다.
6. 에픽이 머지될 때마다 남은 에픽을 재평가하고, 바뀔 때만 사용자 승인 뒤 로드맵 수정을 전용 작은 브랜치(`feature/roadmap-<요지>`)와 PR 로 올린다. 에픽 경계를 다시 나누는 일은 spec-distill 의 `references/redecompose.md` 절차를 따른다. 머지는 사용자가 한다.
7. 구현 커밋에는 `Spec: <에픽 설계문서 레포 상대경로>` 트레일러를 단다.

## 결정 기록

줄 형식은 `- <블록> · <결정|머지> · <YYYY-MM-DD> · 「원문」` 이다. 인터뷰 뒤의 사용자 말은 새 S 번호 없이 원문 그대로 인용한다. squash · rebase 로 머지해 머지 커밋이 없는 에픽은 「머지」 줄로 적는다.

## 재분해 이력

{{HISTORY}}

## 위험 번호표

brief §5 의 번호 없는 위험 줄(숨은 가정 · 실패 양식 · 리뷰 참고 순)에 줄 순서대로 번호를 단다. 오른쪽은 brief 원문 그대로다.

{{RISKS}}
````

- [ ] **Step 2: 실패하는 테스트를 쓴다** *(plan-authored test code — 리뷰어: 이 테스트 코드도 검사 대상이다)*

`plugins/spec-distill/tests/test_roadmap_render.py`:

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_render.py — 분해안 표 · 블록 · 묶음 · 로드맵 글과 정답 견본 대조(R4 AC4 · AC6).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_roadmap_render.py
"""
from __future__ import annotations

import difflib
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "plugins" / "spec-distill" / "scripts"))
import roadmap_render as R  # noqa: E402
from check_bundle_coverage import frontmatter, section_body, unquote  # noqa: E402

RM_REL = "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose"
RM_DIR = REPO / RM_REL

MINI_BRIEF = """---
type: interview-brief
user_sourced_items:
  - id: C4
    statement: "넷째 확정"
  - id: D7
    statement: "일곱째 결정"
---

# 작은 brief

## 0. 한눈에

**결정 목록**

- OQ3 [열림] — 셋째 질문
- OQ5 [해결 ⟨S2⟩] — 다섯째 질문

## 1. Goal · Non-goal

- Goal: 작은 목표.
- Non-goal: 작은 비목표.

## 2. 제약

- ☑ confirmed **D7** — 일곱째 결정 ⟨S2⟩
- 🗣 provisional **C4** — 넷째 확정 ⟨S1⟩

## 3. Open Questions

- OQ3: 셋째 질문

## 4. External Landscape

- 둘을 한 줄에 «zeta» · «alpha» — [취함] [→ OQ3]

## 5. 기각 · Blind Spots

- 위험 — 사실 | 고칠 자리 — RC9 (p/q.py) [RC9 → OQ3]
- 기각 — 다른 갈래 — verdict: kept — ST4 — 부착 1/1
- 위험 — 실패 양식: 조용한 실패 — 근거 사례
- 위험 — 숨은 가정: 가정 셋 — 근거 약함

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > 작은 요청

## 7. Next Action

다음.
"""
MINI_AUDIT = """# audit

## 6. 사용자 원문

- **S2** ☑ 선택 (round 1):
  > 고른 말

## 7. 원자료

- 없음
"""
TABLE = """# state

## 분해안

| 번호 | 이름 | 종류 | 의도 | 범위 | 의존 | 브랜치 | 경로 예약 | 배정 번호 | 받는 것 | 넘기는 것 |
|---|---|---|---|---|---|---|---|---|---|---|
| P1 | 먼저 정할 것 | 결정 | 이름을 정한다 | 한다 결정 / 안 한다 코드 | 없음 | 없음 | 없음 | S2 · OQ5 | 없음 | 없음 |
| A1 | 첫 에픽 | 묶음 | 첫 의도 | 한다 가 / 안 한다 나 | P1 | feature/a1 | x/y.py, z/ | RC9 · C4 · «zeta» · «alpha» · K2 · ST4 · D7 · OQ3 · S1 · K1 | P1 의 이름 | 없음 |
| B1 | 앞선 브랜치 | 브랜치 docs/specs/b1-design.md | 브랜치를 머지 | 한다 머지 / 안 한다 새 일 | 없음 | feature/b1 | 없음 | S1 · C4 · OQ3 | 없음 | 없음 |
"""


def read(rel):
    return (REPO / rel).read_text(encoding="utf-8")


class Table(unittest.TestCase):
    def test_parse(self):
        rows = R.parse_table(TABLE)
        self.assertEqual([r.id for r in rows], ["P1", "A1", "B1"])
        self.assertEqual([r.kind for r in rows], [R.KIND_DECISION, R.KIND_BUNDLE, R.KIND_BRANCH])
        self.assertEqual(rows[2].spec, "docs/specs/b1-design.md")
        self.assertEqual(rows[1].reserved, "x/y.py, z/")
        self.assertEqual(rows[1].receives, "P1 의 이름")

    def test_round_trip(self):
        rows = R.parse_table(TABLE)
        self.assertEqual(R.parse_table(R.format_table(rows)), rows)

    def test_pipe_in_cell_round_trip(self):
        rows = R.parse_table(TABLE)
        rows[1].scope = "한다 a | b / 안 한다 c"
        text = R.format_table(rows)
        self.assertIn("a \\| b", text)
        self.assertEqual(R.parse_table(text)[1].scope, "한다 a | b / 안 한다 c")

    def test_rejects(self):
        bad = {
            "머리": TABLE.replace("| 넘기는 것 |", "| 넘김 |", 1),
            "빈 칸": TABLE.replace("| 첫 의도 |", "|  |"),
            "종류": TABLE.replace("| 묶음 |", "| 꾸러미 |"),
            "결정의 브랜치": TABLE.replace("| 결정 | 이름을 정한다 | 한다 결정 / 안 한다 코드 | 없음 | 없음 |",
                                      "| 결정 | 이름을 정한다 | 한다 결정 / 안 한다 코드 | 없음 | feature/p1 |"),
            "발화 없는 결정": TABLE.replace("| S2 · OQ5 |", "| OQ5 |"),
            "번호 문법": TABLE.replace("| S2 · OQ5 |", "| S2 · OQ5~OQ6 |"),
            "번호 두 번": TABLE.replace("| B1 | 앞선", "| A1 | 앞선"),
            "절 없음": TABLE.replace("## 분해안", "## 다른 절"),
        }
        for name, text in bad.items():
            with self.subTest(name):
                with self.assertRaises(R.TableError):
                    R.parse_table(text)


class Render(unittest.TestCase):
    def setUp(self):
        self.rows = R.parse_table(TABLE)
        self.idx = R.index_brief(MINI_BRIEF, MINI_AUDIT)

    def test_blocks(self):
        self.assertEqual(R.render_block(self.rows[0]), (
            "### P1 — 먼저 정할 것\n- 의도: 이름을 정한다\n- 범위: 한다 결정 / 안 한다 코드\n- 의존: 없음\n"
            "- 완료: 결정 기록\n- 묶음: 없음\n- 경로 예약: 없음\n- 발화: S2\n- 항목: OQ5\n"))
        self.assertEqual(R.render_block(self.rows[1]), (
            "### A1 — 첫 에픽\n- 의도: 첫 의도\n- 범위: 한다 가 / 안 한다 나\n- 의존: P1\n"
            "- 브랜치: feature/a1\n- 묶음: A1.md\n- 경로 예약: x/y.py, z/\n"))
        self.assertEqual(R.render_block(self.rows[2]), (
            "### B1 — 앞선 브랜치\n- 의도: 브랜치를 머지\n- 범위: 한다 머지 / 안 한다 새 일\n- 의존: 없음\n"
            "- 브랜치: feature/b1\n- 묶음: 없음\n- 경로 예약: 없음\n- spec: docs/specs/b1-design.md\n"
            "- 발화: S1\n- 항목: C4 · OQ3\n"))

    def test_bundle(self):
        got = R.render_bundle(self.rows[1], self.idx, "rm/roadmap.md", "iv/b.md", "iv/b.audit.md")
        self.assertTrue(got.startswith(
            "---\ntype: epic-bundle\nepic: A1\nroadmap: rm/roadmap.md\nsource_brief: iv/b.md\n"
            "ids: [C4, D7, OQ3, RC9, K1, K2, ST4, S1, «alpha», «zeta»]\n---\n\n# A1 — 첫 에픽 · 에픽 묶음\n"))
        self.assertIn("- 원본 brief: `iv/b.md` (audit `iv/b.audit.md`)\n- 로드맵: `rm/roadmap.md` 의 `### A1` 블록\n", got)
        self.assertIn("### 이 에픽의 Goal · Non-goal\n\n- 의도: 첫 의도\n- 범위: 한다 가 / 안 한다 나\n\n"
                      "### 공통 목표\n\n- Goal: 작은 목표.\n- Non-goal: 작은 비목표.\n\n## 2. 제약\n\n"
                      "- 🗣 provisional **C4** — 넷째 확정 ⟨S1⟩\n- ☑ confirmed **D7** — 일곱째 결정 ⟨S2⟩\n\n", got)
        self.assertIn("## 3. 열린 질문\n\n- OQ3 [열림] — 셋째 질문\n\n", got)
        self.assertIn("## 4. 웹 근거\n\n- 둘을 한 줄에 «zeta» · «alpha» — [취함] [→ OQ3]\n\n", got)
        self.assertIn("## 5. 기각 · 위험\n\n- 위험 — 사실 | 고칠 자리 — RC9 (p/q.py) [RC9 → OQ3]\n"
                      "- 기각 — 다른 갈래 — verdict: kept — ST4 — 부착 1/1\n"
                      "- K1 — 위험 — 숨은 가정: 가정 셋 — 근거 약함\n"
                      "- K2 — 위험 — 실패 양식: 조용한 실패 — 근거 사례\n\n", got)
        self.assertIn("## 6. 사용자 원문\n\n- **S1** 🗣 최초 요청:\n  > 작은 요청\n\n\n- **S2** ☑ 선택 (round 1):\n"
                      "  > 고른 말\n\n## 7. 인터페이스\n\n- 받는 것: P1 의 이름\n- 넘기는 것: 없음\n", got)
        self.assertTrue(got.endswith("- 넘기는 것: 없음\n"))

    def test_bundle_missing_line_refused(self):
        self.rows[1].ids.append("C99")
        with self.assertRaises(R.TableError):
            R.render_bundle(self.rows[1], self.idx, "rm/roadmap.md", "iv/b.md", "iv/b.audit.md")

    def test_roadmap(self):
        text = R.render_roadmap(R.TEMPLATE.read_text(encoding="utf-8"), self.rows, self.idx, "작은 일",
                                "iv/b.md", "rm/roadmap.md", "- 2026-10-15 · 처음 로드맵 · 승인 원문 「승인」")
        self.assertTrue(text.startswith("---\ntype: roadmap\nsource_brief: iv/b.md\n---\n\n# 작은 일 — 로드맵\n"))
        self.assertIn("## 에픽\n\n### P1 — 먼저 정할 것\n", text)
        self.assertIn("- 항목: C4 · OQ3\n\n## 지휘 절차\n", text)
        self.assertIn("`@rm/roadmap.md`", text)
        self.assertIn("## 재분해 이력\n\n- 2026-10-15 · 처음 로드맵 · 승인 원문 「승인」\n\n## 위험 번호표\n", text)
        self.assertTrue(text.endswith("- K1 — 위험 — 숨은 가정: 가정 셋 — 근거 약함\n"
                                      "- K2 — 위험 — 실패 양식: 조용한 실패 — 근거 사례\n"))
        self.assertNotIn("{{", text)
        self.assertEqual(section_body(text, "## 에픽"),
                         "\n" + "\n".join(R.render_block(r) for r in self.rows) + "\n")

    def test_roadmap_without_risks(self):
        brief = "\n".join(l for l in MINI_BRIEF.splitlines() if not l.startswith("- 위험 — 숨은")
                          and not l.startswith("- 위험 — 실패")) + "\n"
        idx = R.index_brief(brief, MINI_AUDIT)
        self.assertEqual(idx.k_lines, {})
        text = R.render_roadmap(R.TEMPLATE.read_text(encoding="utf-8"), self.rows, idx, "t", "iv/b.md",
                                "rm/roadmap.md", "- h")
        self.assertTrue(text.endswith("오른쪽은 brief 원문 그대로다.\n\n- 없음\n"))

    def test_splice(self):
        text = R.render_roadmap(R.TEMPLATE.read_text(encoding="utf-8"), self.rows, self.idx, "t", "iv/b.md",
                                "rm/roadmap.md", "- 첫 줄")
        blocks = R.epic_block_texts(text)
        self.assertEqual(list(blocks), ["P1", "A1", "B1"])
        self.assertEqual(blocks["A1"], R.render_block(self.rows[1]))
        swapped = R.replace_epics(text, [blocks["B1"], blocks["P1"]])
        self.assertEqual(list(R.epic_block_texts(swapped)), ["B1", "P1"])
        self.assertEqual(swapped.split("## 지휘 절차")[1], text.split("## 지휘 절차")[1])
        added = R.append_history(text, "- 둘째 줄")
        self.assertIn("## 재분해 이력\n\n- 첫 줄\n- 둘째 줄\n\n## 위험 번호표\n", added)

    def test_extract(self):
        text = R.render_roadmap(R.TEMPLATE.read_text(encoding="utf-8"), self.rows, self.idx, "t", "iv/b.md",
                                "rm/roadmap.md", "- h")
        bundle = R.render_bundle(self.rows[1], self.idx, "rm/roadmap.md", "iv/b.md", "iv/b.audit.md")
        rows = R.extract_rows(text, lambda name: bundle if name == "A1.md" else None)
        want = R.parse_table(TABLE)
        want[1].ids = sorted(set(want[1].ids), key=R.id_sort_key)  # 묶음은 정렬된 ids 를 싣는다
        want[2].ids = ["S1", "C4", "OQ3"]
        self.assertEqual(rows, want)


class GoldenSample(unittest.TestCase):
    """AC6 — 이번 로드맵에서 뽑은 표로 만든 묶음 · 블록이 손으로 만든 것과 바이트가 같다."""

    def setUp(self):
        self.roadmap = (RM_DIR / "roadmap.md").read_text(encoding="utf-8")
        self.rows = R.extract_rows(
            self.roadmap,
            lambda n: (RM_DIR / n).read_text(encoding="utf-8") if (RM_DIR / n).is_file() else None)
        self.brief_rel = unquote(frontmatter(self.roadmap)["source_brief"])
        self.audit_rel = self.brief_rel[:-3] + ".audit.md"
        self.idx = R.index_brief(read(self.brief_rel), read(self.audit_rel))

    def _diff(self, name, want, got):
        lines = difflib.unified_diff(want.splitlines(True), got.splitlines(True), "손", "생성", n=1)
        return name + "\n" + "".join(list(lines)[:30])

    def test_kinds_present(self):
        kinds = {r.id: r.kind for r in self.rows}
        self.assertEqual(kinds["P1"], R.KIND_BRANCH)
        self.assertEqual(kinds["P3"], R.KIND_DECISION)
        self.assertEqual(kinds["R0"], R.KIND_BRANCH)
        self.assertEqual(sum(1 for k in kinds.values() if k == R.KIND_BUNDLE), 10)

    def test_bundles_byte_equal(self):
        diffs = []
        for r in self.rows:
            if r.kind != R.KIND_BUNDLE:
                continue
            want = (RM_DIR / (r.id + ".md")).read_text(encoding="utf-8")
            got = R.render_bundle(r, self.idx, RM_REL + "/roadmap.md", self.brief_rel, self.audit_rel)
            if got != want:
                diffs.append(self._diff(r.id, want, got))
        self.assertEqual(diffs, [], "\n".join(diffs))

    def test_blocks_byte_equal(self):
        hand = R.epic_block_texts(self.roadmap)
        diffs = [self._diff(r.id, hand[r.id], R.render_block(r)) for r in self.rows
                 if R.render_block(r) != hand[r.id]]
        self.assertEqual(diffs, [], "\n".join(diffs))

    def test_epics_section_rebuilds(self):
        self.assertEqual(section_body(self.roadmap, "## 에픽"),
                         "\n" + "\n".join(R.render_block(r) for r in self.rows) + "\n")

    def test_risk_table(self):
        hand = [l for l in section_body(self.roadmap, "## 위험 번호표").splitlines() if l.startswith("- K")]
        self.assertEqual(list(self.idx.k_lines.values()), hand)

    def test_table_round_trip(self):
        self.assertEqual(R.parse_table(R.format_table(self.rows)), self.rows)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: 실패를 확인한다**

Run: `cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_roadmap_render.py`
Expected: `ModuleNotFoundError: No module named 'roadmap_render'`(ERROR).

- [ ] **Step 4: 렌더 모듈을 쓴다**

`plugins/spec-distill/scripts/roadmap_render.py`:

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_render.py — 분해안 표 · 로드맵 블록 · 에픽 묶음 · 로드맵의 글을 만든다. 파일을 쓰지 않는다.

`roadmap_write.py` 가 부른다. 형식의 정본은 R0 설계 §3(`docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md`)
이고, 로드맵 해석 · 번호 문법 · 절 읽기 · §6 경계는 `roadmap_status.py` · `check_bundle_coverage.py` · `section6.py` 의 것을 쓴다.
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import section6  # noqa: E402
from check_bundle_coverage import (  # noqa: E402
    FormatError, bundle_ids, id_sort_key, parse_ids, section_body)
from roadmap_status import (  # noqa: E402
    BLOCK_ID_RE, KEY_RE, OQ_LINE_RE, brief_universe, parse_roadmap)

TABLE_HEADING = "## 분해안"
COLUMNS = ("번호", "이름", "종류", "의도", "범위", "의존", "브랜치", "경로 예약", "배정 번호", "받는 것", "넘기는 것")
KIND_BUNDLE, KIND_BRANCH, KIND_DECISION = "bundle", "branch", "decision"
TEMPLATE = Path(__file__).resolve().parent.parent / "templates" / "roadmap-template.md"
C_LINE_RE = re.compile(r"- \S+ (?:confirmed|provisional) \*\*([CD]\d+)\*\* — ")
RC_LINE_RE = re.compile(r"(RC\d+) \(")
ST_LINE_RE = re.compile(r" — (ST\d+) — ")
PLACEHOLDER_RE = re.compile(r"\{\{([A-Z_]+)\}\}")


class TableError(ValueError):
    """분해안 표 · 묶음을 만들 수 없다 — 사유를 그대로 사용자에게 보인다."""


@dataclass
class Row:
    id: str
    title: str
    kind: str          # bundle · branch · decision
    spec: str          # branch 일 때 설계문서 경로, 아니면 ""
    intent: str
    scope: str
    deps: str          # 로드맵 `의존:` 값 그대로
    branch: str        # decision 이면 "없음"
    reserved: str      # 로드맵 `경로 예약:` 값 그대로
    ids: list = field(default_factory=list)   # 칸에 적힌 순서 그대로
    receives: str = "없음"
    gives: str = "없음"

    def kind_cell(self) -> str:
        if self.kind == KIND_BUNDLE:
            return "묶음"
        if self.kind == KIND_DECISION:
            return "결정"
        return "브랜치 " + self.spec


def _is_s(token: str) -> bool:
    return token.startswith("S") and token[1:].isdigit()


# ── 분해안 표 ────────────────────────────────────────────────────────────────

def _split_row(line: str) -> list:
    line = line.strip()
    if not (line.startswith("|") and line.endswith("|")):
        raise TableError("표 행이 | 로 시작하고 끝나지 않는다: %r" % line)
    body, cells, cur, i = line[1:-1], [], [], 0
    while i < len(body):
        if body[i] == "\\" and body[i + 1:i + 2] == "|":
            cur.append("|")
            i += 2
            continue
        if body[i] == "|":
            cells.append("".join(cur).strip())
            cur = []
        else:
            cur.append(body[i])
        i += 1
    cells.append("".join(cur).strip())
    return cells


def _row(c: list, line: str) -> Row:
    rid, title, kind_cell, intent, scope, deps, branch, reserved, ids_cell, recv, give = c
    if any(not v for v in c):
        raise TableError("빈 칸이 있다 — 없으면 「없음」이라 쓴다: %r" % line)
    if not BLOCK_ID_RE.fullmatch(rid):
        raise TableError("에픽 번호 %r 가 `<대문자><숫자>[소문자]` 가 아니다" % rid)
    if kind_cell == "묶음":
        kind, spec = KIND_BUNDLE, ""
    elif kind_cell == "결정":
        kind, spec = KIND_DECISION, ""
    elif kind_cell.startswith("브랜치 ") and kind_cell[len("브랜치 "):].strip():
        kind, spec = KIND_BRANCH, kind_cell[len("브랜치 "):].strip()
    else:
        raise TableError("%s: 종류는 「묶음」 · 「브랜치 <설계문서 경로>」 · 「결정」 중 하나다: %r" % (rid, kind_cell))
    if (kind == KIND_DECISION) != (branch == "없음"):
        raise TableError("%s: 브랜치 칸은 결정 블록만 「없음」이다" % rid)
    try:
        ids = parse_ids(ids_cell)
    except FormatError as exc:
        raise TableError("%s: 배정 번호 — %s" % (rid, exc))
    if kind != KIND_BUNDLE:
        n_s = sum(1 for t in ids if _is_s(t))
        if n_s == 0 or n_s == len(ids):
            raise TableError("%s: 묶음 없는 블록은 발화(S) 번호와 그 밖의 번호가 하나 이상씩 있어야 한다" % rid)
    return Row(rid, title, kind, spec, intent, scope, deps, branch, reserved, ids, recv, give)


def parse_table(text: str) -> list:
    try:
        body = section_body(text, TABLE_HEADING)
    except FormatError as exc:
        raise TableError(str(exc))
    if body is None:
        raise TableError("`%s` 절이 없다" % TABLE_HEADING)
    lines = [l for l in body.splitlines() if l.strip().startswith("|")]
    if len(lines) < 3:
        raise TableError("분해안 표가 없거나 에픽 행이 없다")
    if _split_row(lines[0]) != list(COLUMNS):
        raise TableError("분해안 표 머리가 칸 열하나(%s)가 아니다" % " · ".join(COLUMNS))
    sep = _split_row(lines[1])
    if len(sep) != len(COLUMNS) or not all(c.count("-") >= 3 and set(c) <= set("-:") for c in sep):
        raise TableError("분해안 표 구분 행이 칸 열하나가 아니다")
    rows, seen = [], set()
    for line in lines[2:]:
        cells = _split_row(line)
        if len(cells) != len(COLUMNS):
            raise TableError("분해안 표 행이 칸 열하나가 아니다: %r" % line)
        row = _row(cells, line)
        if row.id in seen:
            raise TableError("에픽 번호 %s 가 두 번 있다" % row.id)
        seen.add(row.id)
        rows.append(row)
    return rows


def format_table(rows: list) -> str:
    out = [TABLE_HEADING, "", "| " + " | ".join(COLUMNS) + " |", "|" + "---|" * len(COLUMNS)]
    for r in rows:
        cells = (r.id, r.title, r.kind_cell(), r.intent, r.scope, r.deps, r.branch, r.reserved,
                 " · ".join(r.ids), r.receives, r.gives)
        out.append("| " + " | ".join(c.replace("|", "\\|") for c in cells) + " |")
    return "\n".join(out) + "\n"


def extract_rows(roadmap_text: str, read_bundle) -> list:
    """로드맵 블록과 묶음(frontmatter ids · §7)에서 분해안 표를 거꾸로 뽑는다."""
    _meta, blocks, _records, _risks, errors = parse_roadmap(roadmap_text)
    if errors:
        raise TableError("로드맵 형식 깨짐 — " + " · ".join(errors))
    rows = []
    for b in blocks:
        f = b["fields"]
        if b["kind"] == "bundle":
            if f["묶음"] != b["id"] + ".md":
                raise TableError("%s: 묶음 이름이 `%s.md` 가 아니다" % (b["id"], b["id"]))
            text = read_bundle(f["묶음"])
            if text is None:
                raise TableError("%s 묶음을 읽지 못했다: %s" % (b["id"], f["묶음"]))
            try:
                ids = bundle_ids(text)
                s7 = section_body(text, "## 7.") or ""
            except FormatError as exc:
                raise TableError("%s 묶음 — %s" % (b["id"], exc))
            got = {}
            for line in s7.splitlines():
                for key in ("받는 것", "넘기는 것"):
                    if line.startswith("- %s: " % key):
                        got[key] = line[len("- %s: " % key):]
            if len(got) != 2:
                raise TableError("%s 묶음 §7 에 받는 것 · 넘기는 것 줄이 없다" % b["id"])
            rows.append(Row(b["id"], b["title"], KIND_BUNDLE, "", f["의도"], f["범위"], f["의존"],
                            f["브랜치"], f["경로 예약"], ids, got["받는 것"], got["넘기는 것"]))
            continue
        try:
            ids = parse_ids(f["발화"]) + parse_ids(f["항목"])
        except FormatError as exc:
            raise TableError("%s: %s" % (b["id"], exc))
        kind = KIND_BRANCH if b["kind"] == "branch" else KIND_DECISION
        rows.append(Row(b["id"], b["title"], kind, f.get("spec", ""), f["의도"], f["범위"], f["의존"],
                        f.get("브랜치", "없음"), f["경로 예약"], ids))
    return rows


# ── brief 색인 ───────────────────────────────────────────────────────────────

@dataclass
class BriefIndex:
    lines: dict      # 번호 → brief 줄(§2 C · D · §0 OQ · §4 «key» · §5 RC · ST)
    k_lines: dict    # K<n> → "- K<n> — <brief §5 위험 줄 원문>"
    goal: str        # brief §1 본문
    s6: str          # brief §6 본문 + 빈 줄 + audit §6 본문


def _body(text: str, heading: str) -> str:
    body = section_body(text, heading)
    if body is None:
        raise FormatError("brief 에 %s 절이 없다" % heading)
    return body


def index_brief(brief: str, audit: str) -> BriefIndex:
    _non_s, _s_ids, k_expected = brief_universe(brief, audit)
    lines = {}
    for line in _body(brief, "## 2.").splitlines():
        m = C_LINE_RE.match(line)
        if m:
            lines[m.group(1)] = line
    for line in _body(brief, "## 0.").splitlines():
        m = OQ_LINE_RE.match(line)
        if m:
            lines[m.group(1)] = line
    for line in _body(brief, "## 4.").splitlines():
        for key in KEY_RE.findall(line):
            lines[key] = line
    for line in _body(brief, "## 5.").splitlines():
        m = RC_LINE_RE.search(line)
        if m:
            lines[m.group(1)] = line
        m = ST_LINE_RE.search(line)
        if m:
            lines[m.group(1)] = line
    b6, a6 = section6.body(brief), section6.body(audit)
    if b6 is None or a6 is None:
        raise FormatError("brief 또는 audit 의 §6 을 하나로 읽을 수 없다")
    return BriefIndex(lines, {k: "- %s — %s" % (k, text) for k, text in k_expected},
                      _body(brief, "## 1."), b6.rstrip("\n") + "\n\n" + a6)


# ── 블록 · 묶음 · 로드맵 ─────────────────────────────────────────────────────

def render_block(r: Row) -> str:
    lines = ["### %s — %s" % (r.id, r.title), "- 의도: " + r.intent, "- 범위: " + r.scope,
             "- 의존: " + r.deps,
             "- 완료: 결정 기록" if r.kind == KIND_DECISION else "- 브랜치: " + r.branch,
             "- 묶음: " + (r.id + ".md" if r.kind == KIND_BUNDLE else "없음"),
             "- 경로 예약: " + r.reserved]
    if r.kind == KIND_BRANCH:
        lines.append("- spec: " + r.spec)
    if r.kind != KIND_BUNDLE:
        lines.append("- 발화: " + " · ".join(t for t in r.ids if _is_s(t)))
        lines.append("- 항목: " + " · ".join(t for t in r.ids if not _is_s(t)))
    return "\n".join(lines) + "\n"


BUNDLE_FORMAT = (
    "---\ntype: epic-bundle\nepic: %s\nroadmap: %s\nsource_brief: %s\nids: [%s]\n---\n\n"
    "# %s — %s · 에픽 묶음\n\n"
    "## 0. 역참조\n\n"
    "- 원본 brief: `%s` (audit `%s`)\n"
    "- 로드맵: `%s` 의 `### %s` 블록\n"
    "- 이 에픽의 설계문서는 frontmatter `source_interview:` 에 이 묶음 경로를, `roadmap:` 에 로드맵 경로를 적고, "
    "본문 `## 번호 대조` 표(칸: 번호 · 반영/기각 · 자리 또는 이유)에 위 `ids` 전부를 싣는다.\n\n"
    "## 1. Goal · Non-goal\n\n### 이 에픽의 Goal · Non-goal\n\n- 의도: %s\n- 범위: %s\n\n### 공통 목표\n%s"
    "## 2. 제약\n\n%s\n\n"
    "## 3. 열린 질문\n\n%s\n\n"
    "## 4. 웹 근거\n\n%s\n\n"
    "## 5. 기각 · 위험\n\n%s\n\n"
    "## 6. 사용자 원문\n%s"
    "## 7. 인터페이스\n\n- 받는 것: %s\n- 넘기는 것: %s\n")


def render_bundle(r: Row, idx: BriefIndex, roadmap_rel: str, brief_rel: str, audit_rel: str) -> str:
    ids = sorted(set(r.ids), key=id_sort_key)
    missing = [t for t in ids if not _is_s(t) and t not in idx.lines and t not in idx.k_lines]
    if missing:
        raise TableError("%s: brief 에서 줄을 찾지 못한 번호 — %s" % (r.id, " · ".join(missing)))

    def pick(prefix_ok):
        return [idx.lines[t] for t in ids if prefix_ok(t)]

    keys = []
    for t in ids:
        if t.startswith("«") and idx.lines[t] not in keys:
            keys.append(idx.lines[t])
    c_d = pick(lambda t: t[:1] in ("C", "D") and t[1:].isdigit())
    oq = pick(lambda t: t.startswith("OQ"))
    rest = (pick(lambda t: t.startswith("RC")) + pick(lambda t: t.startswith("ST"))
            + [idx.k_lines[t] for t in ids if t.startswith("K")])
    return BUNDLE_FORMAT % (
        r.id, roadmap_rel, brief_rel, ", ".join(ids), r.id, r.title, brief_rel, audit_rel, roadmap_rel, r.id,
        r.intent, r.scope, idx.goal,
        "\n".join(c_d) or "- 없음", "\n".join(oq) or "- 없음", "\n".join(keys) or "- 없음",
        "\n".join(rest) or "- 없음", idx.s6, r.receives, r.gives)


def render_roadmap(template: str, rows: list, idx: BriefIndex, title: str, brief_rel: str,
                   roadmap_rel: str, history: str) -> str:
    values = {"TITLE": title, "SOURCE_BRIEF": brief_rel, "ROADMAP": roadmap_rel,
              "EPICS": "\n".join(render_block(r) for r in rows), "HISTORY": history,
              "RISKS": "\n".join(idx.k_lines.values()) or "- 없음"}

    def sub(m):
        if m.group(1) not in values:
            raise TableError("로드맵 틀에 모르는 자리표 %s" % m.group(0))
        return values[m.group(1)]
    return PLACEHOLDER_RE.sub(sub, template)


# ── 로드맵 고쳐 쓰기(update) ─────────────────────────────────────────────────

def _span(lines: list, heading: str):
    start = next((i for i, l in enumerate(lines) if l.rstrip("\r\n") == heading), None)
    if start is None:
        raise TableError("로드맵에 `%s` 절이 없다" % heading)
    end = next((j for j in range(start + 1, len(lines)) if lines[j].startswith("## ")), len(lines))
    return start, end


def epic_block_texts(roadmap_text: str) -> dict:
    lines = roadmap_text.splitlines(keepends=True)
    start, end = _span(lines, "## 에픽")
    out, cur, buf = {}, None, []
    for line in lines[start + 1:end] + ["### \n"]:
        if line.startswith("### "):
            if cur is not None:
                out[cur] = "".join(buf).rstrip("\n") + "\n"
            cur, buf = line[4:].split(" — ", 1)[0].strip(), [line]
        elif cur is not None:
            buf.append(line)
    return out


def replace_epics(roadmap_text: str, blocks: list) -> str:
    lines = roadmap_text.splitlines(keepends=True)
    start, end = _span(lines, "## 에픽")
    return "".join(lines[:start + 1]) + "\n" + "\n".join(blocks) + "\n" + "".join(lines[end:])


def append_history(roadmap_text: str, line: str) -> str:
    lines = roadmap_text.splitlines(keepends=True)
    start, end = _span(lines, "## 재분해 이력")
    body = "".join(lines[start + 1:end]).rstrip("\n")
    tail = "".join(lines[end:])
    return "".join(lines[:start + 1]) + body + "\n" + line + "\n" + ("\n" + tail if tail else "")
```

주의: `epic_block_texts` 의 끝 표지 `"### \n"` 은 마지막 블록을 비우기 위한 것이고 `out` 에 키 `""` 로 들어가지 않는다(그 뒤에 flush 가 없다). 테스트 `test_splice` 의 `list(blocks) == ["P1","A1","B1"]` 가 이를 잡는다.

- [ ] **Step 5: 테스트를 돌린다**

Run: `cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v plugins/spec-distill/tests/test_roadmap_render.py`
Expected: 전부 PASS. `GoldenSample` 이 실패하면 그 차이(테스트가 낸 diff)마다 「생성기를 고친다 / 견본을 고친다」를 판정한다 — 견본(손 묶음)이 R0 형식 · 조립기 규칙에서 벗어난 손 편집이면 견본을 고치고, 생성 규칙이 형식에서 벗어났으면 생성기를 고친다. 판정 없이 테스트를 느슨하게 만들지 않는다. 계획 작성 때 실측으로는 차이 0 이 기대된다(조립기가 R6 · R9 를 뺀 여덟을 바이트 그대로 재현했고, 그 둘의 차이는 표 데이터다).

- [ ] **Step 6: 설계문서 결정 기록에 대조 결과를 적는다**

`docs/superpowers/specs/2026-10-15-interview-pm-decompose-design.md` 의 `## 결정 기록` 끝(번호 대조 절 앞)에 한 줄씩. 차이가 없으면:

```
- 판정 · 2026-10-15 · 정답 견본 대조(AC6) — 이번 로드맵에서 뽑은 표(묶음 없는 P1~P4 · R0 포함)로 만든 묶음 10개 · 블록 15개 · 위험 번호표가 손으로 만든 것과 바이트 차이 0. 견본은 PR #209 머지 전의 것이다(머지 여부 `git merge-base --is-ancestor` 로 확인 — 계획 실행 시점 미머지). #209 는 블록과 묶음의 같은 줄을 함께 바꾸므로 대조 결과가 바뀌지 않는다 — 머지 뒤 이 테스트가 다시 확인한다.
```

차이가 있었으면 차이마다 `- 판정 · 2026-10-15 · 정답 견본 차이 <에픽> <어느 줄> — <생성기를 고친다|견본을 고친다> · <이유>` 를 적는다.

견본과 설계 문면의 차이 하나는 계획 단계에서 이미 드러났다 — 반드시 함께 적는다:

```
- 판정 · 2026-10-15 · 정답 견본 차이 — 묶음 §2~§5 의 줄 순서: 설계 §2-3 은 「brief 에서 원래 순서로」라 했으나 손으로 만든 묶음 10개는 번호 순(`id_sort_key` — C · D · OQ · RC · K · ST · S · «key», §5 는 RC 줄 → ST 줄 → K 줄)이다 → 생성기를 견본에 맞춘다(번호 순). AC6 의 정답은 견본이고, 견본을 다시 쓰면 이미 머지된 에픽의 묶음까지 바뀐다. 설계 §2-3 의 「원래 순서」는 이 판정으로 읽는다.
``` PR #209 머지 여부는 `git -C <worktree> fetch origin` 뒤 `gh pr view 209 --json state,mergeCommit` 로 확인해 위 문장의 「미머지」를 사실대로 쓴다.

- [ ] **Step 7: 커밋**

```bash
git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 add -- plugins/spec-distill/scripts/roadmap_render.py plugins/spec-distill/templates/roadmap-template.md plugins/spec-distill/tests/test_roadmap_render.py docs/superpowers/specs/2026-10-15-interview-pm-decompose-design.md
git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 commit -m "feat(spec-distill): 분해안 표로 로드맵 · 에픽 묶음 글을 만드는 렌더 모듈" -m "<트레일러 셋>"
```

---

### Task 2: `roadmap_write.py` — create · extract · 검증 · 되돌리기

**Files:**
- Create: `plugins/spec-distill/scripts/roadmap_write.py`
- Test: `plugins/spec-distill/tests/test_roadmap_write.py`(순수 함수 · 트랜잭션)
- Test: `plugins/spec-distill/tests/test_roadmap_write.sh`(픽스처 git 저장소, 100755)

**Interfaces:**
- Consumes: Task 1 의 `roadmap_render` 전부, `check_bundle_coverage.FormatError · frontmatter · section_body · unquote`, `roadmap_status.DATE_RE`.
- Produces (Task 3 이 쓴다): `Refused(Exception)` · `Usage(Exception)`, `class Txn`(`ensure_dir(Path)` · `write(Path, str)` · `remove(Path)` · `rollback() -> list[str]`), `judge(stdout: str, rc: int) -> list[str]`, `validate(top: Path, roadmap: Path) -> list[str]`, `git_top(path) -> Path`, `rel(top, path) -> str`, `read(path) -> str`, `read_record(text) -> set`, `with_record(text, paths) -> str`, `main(argv=None) -> int`, CLI `create` · `extract`(Task 3 이 `update` 를 더한다).

명령줄 · 종료 코드(모듈 docstring 에 그대로 싣는다):

```
roadmap_write.py create --brief <brief> --audit <audit> --plan-table <표 파일> --out <로드맵 폴더>
                        --title <제목> --date <YYYY-MM-DD> --approval <승인 원문>
roadmap_write.py update --roadmap <로드맵> --brief <brief> --audit <audit> --plan-table <새 표 파일>
                        --date <YYYY-MM-DD> --change <바뀐 것 한 줄> --approval <승인 원문>
roadmap_write.py extract --roadmap <로드맵>
종료 코드: 0 성공 · 1 쓰지 않음(표 오류 · 덮어쓰기 거부 · 검증 실패 — 쓴 것은 모두 되돌렸다) · 2 사용법 오류.
```

- [ ] **Step 1: 실패하는 단위 테스트를 쓴다** *(plan-authored test code — 리뷰어: 이 테스트 코드도 검사 대상이다)*

`plugins/spec-distill/tests/test_roadmap_write.py`:

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_write.py 의 판정 · 되돌리기 · 생성 기록(R4 AC5 · AC10).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_roadmap_write.py
"""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "plugins" / "spec-distill" / "scripts"))
import roadmap_write as W  # noqa: E402


def report(**over):
    base = {"format_errors": [], "unassigned": [], "orphans": [], "unknown_ids": [], "unknown_reasons": []}
    base.update(over)
    return json.dumps(base, ensure_ascii=False)


class Judge(unittest.TestCase):
    def test_pass(self):
        self.assertEqual(W.judge(report(), 3), [])  # rc 는 보지 않는다(origin/main 없음 3 · 경고 1)

    def test_each_list(self):
        for key in W.LISTS:
            with self.subTest(key):
                reasons = W.judge(report(**{key: ["X1"]}), 0)
                self.assertEqual(len(reasons), 1)
                self.assertIn(key, reasons[0])
                self.assertIn("X1", reasons[0])

    def test_uncountable(self):
        reasons = W.judge(report(unassigned=None, unknown_reasons=["번호 전체 집합을 셀 수 없다"]), 3)
        self.assertTrue(any("셀 수 없음" in r and "unassigned" in r for r in reasons))
        missing = json.loads(report())
        del missing["orphans"]
        self.assertTrue(any("orphans" in r for r in W.judge(json.dumps(missing), 0)))

    def test_unreadable(self):
        for out in ("", "not json", "[]", "null"):
            with self.subTest(out):
                self.assertTrue(any("읽지 못했다" in r for r in W.judge(out, 3)))


class Transaction(unittest.TestCase):
    def test_rollback_restores_bytes(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            kept, gone, new = d / "kept.md", d / "gone.md", d / "sub" / "new.md"
            kept.write_bytes("원래\n".encode("utf-8"))
            gone.write_bytes(b"gone\n")
            txn = W.Txn()
            txn.write(kept, "바뀜\n")
            txn.write(kept, "두 번 바뀜\n")
            txn.remove(gone)
            txn.ensure_dir(new.parent)
            txn.write(new, "새 파일\n")
            self.assertEqual(kept.read_text(encoding="utf-8"), "두 번 바뀜\n")
            self.assertEqual(txn.rollback(), [])
            self.assertEqual(kept.read_bytes(), "원래\n".encode("utf-8"))
            self.assertEqual(gone.read_bytes(), b"gone\n")
            self.assertFalse(new.exists())
            self.assertFalse(new.parent.exists())
            self.assertEqual(sorted(p.name for p in d.iterdir()), ["gone.md", "kept.md"])


class Record(unittest.TestCase):
    def test_round_trip(self):
        text = "# state\n\n## 분해안\n\n| 표 |\n"
        once = W.with_record(text, {"docs/rm/roadmap.md", "docs/rm/A1.md"})
        self.assertEqual(W.read_record(once), {"docs/rm/roadmap.md", "docs/rm/A1.md"})
        self.assertTrue(once.startswith(text.rstrip("\n")))
        twice = W.with_record(once + "\n## 뒤 절\n\n뒤\n", {"docs/rm/roadmap.md"})
        self.assertEqual(W.read_record(twice), {"docs/rm/roadmap.md"})
        self.assertIn("## 뒤 절\n\n뒤\n", twice)
        self.assertEqual(twice.count("## 생성 기록"), 1)

    def test_empty(self):
        self.assertEqual(W.read_record("# state\n"), set())


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패하는 셸 테스트를 쓴다** *(plan-authored test code — 리뷰어: 이 테스트 코드도 검사 대상이다)*

`plugins/spec-distill/tests/test_roadmap_write.sh` (Task 3 이 update 절을 덧붙인다):

```bash
#!/usr/bin/env bash
# roadmap_write.py — 분해안 표로 로드맵 · 묶음을 만들고 검증 · 되돌린다(R4 AC4 · AC5 · AC10).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_roadmap_write.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
S="$ROOT/plugins/spec-distill/scripts"
RW="$S/roadmap_write.py"
RS="$S/roadmap_status.py"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
W="$T/repo"
g() { git -C "$W" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false \
        -c init.defaultBranch=main "$@"; }
four_empty() {   # four_empty <로드맵> — 검사기 네 목록이 모두 빈 목록이면 ok
  (cd "$W" && python3 "$RS" --roadmap-file "$1" --json) | python3 -c '
import json, sys
r = json.load(sys.stdin)
print("ok" if all(r.get(k) == [] for k in ("format_errors", "unassigned", "orphans", "unknown_ids")) else r)'
}
tree_of() { (cd "$1" && find . -type f | LC_ALL=C sort); }
assert_file_has() {  # assert_file_has <파일> <고정 문자열> <라벨>
  if grep -qF -- "$2" "$1" 2>/dev/null; then ok "$3"; else no "$3 — 없음: $2"; fi
}

# ── 픽스처: brief · audit (test_roadmap_status.sh 와 다른 글) ────────────────
mkdir -p "$W/docs/iv"
cat > "$W/docs/iv/brief.md" <<'MD'
---
type: interview-brief
user_sourced_items:
  - id: C1
    statement: "첫 확정"
  - id: D2
    statement: "둘째 확정"
  - id: C3
    statement: "셋째 확정"
---

# 픽스처 brief

## 0. 한눈에

**결정 목록**

- OQ1 [열림] — 열린 하나
- OQ2 [해결 ⟨S2⟩] — 닫힌 하나

## 1. Goal · Non-goal

- Goal: 픽스처 목표.
- Non-goal: 픽스처 비목표.

## 2. 제약

- 🗣 confirmed **C1** — 첫 확정 ⟨S1⟩
- ☑ confirmed **D2** — 둘째 확정 ⟨S2⟩
- 🗣 confirmed **C3** — 셋째 확정 ⟨S1⟩

## 3. Open Questions

- OQ1: 열린 하나

## 4. External Landscape

- 바깥 하나 «ext-a» — [취함] [→ OQ1]
- 바깥 둘 «ext-b» — [중립] [→ 없음]

## 5. 기각 · Blind Spots

- 기각 — 다른 길 — verdict: kept — ST1 — 부착 2/2
- 위험 — 숨은 가정: 가정 — 근거 약함
- 위험 — 실패 양식: 실패 — 근거 약함
- 위험 — 사실 | 사실 하나 — RC1 (a/b.py) [RC1 → OQ1]

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > 처음 말

## 7. Next Action

다음.
MD
cat > "$W/docs/iv/brief.audit.md" <<'MD'
# audit

## 6. 사용자 원문

- **S2** 🗣 발화 (round 1):
  > 둘째 말
- **S3** ☑ 선택 (round 2):
  > 셋째 말

## 7. 기타

- 없음
MD
git init -q --bare -b main "$T/origin.git"
git init -q -b main "$W"
g remote add origin "$T/origin.git"
g add -- docs && g commit -qm brief && g push -q origin main && g fetch -q origin

HEAD_ROW='| 번호 | 이름 | 종류 | 의도 | 범위 | 의존 | 브랜치 | 경로 예약 | 배정 번호 | 받는 것 | 넘기는 것 |'
SEP_ROW='|---|---|---|---|---|---|---|---|---|---|---|'
P1_ROW='| P1 | 결정 하나 | 결정 | 무엇을 정한다 | 한다 결정 / 안 한다 코드 | 없음 | 없음 | 없음 | S3 · OQ2 | 없음 | 없음 |'
E1_ROW='| E1 | 첫 에픽 | 묶음 | 첫 의도 | 한다 가 / 안 한다 나 | P1 | feature/e1 | a/x.py | C1 · D2 · OQ1 · RC1 · K1 · «ext-a» · S1 · S2 | 없음 | E2 에 x |'
E2_ROW='| E2 | 둘째 에픽 | 묶음 | 둘째 의도 | 한다 다 / 안 한다 라 | E1 | feature/e2 | 없음 | C3 · ST1 · K2 · «ext-b» · S1 | E1 의 x | 없음 |'
table() {  # table <파일> <행들…>
  local f="$1"; shift
  { printf '# state\n\n## 분해안\n\n%s\n%s\n' "$HEAD_ROW" "$SEP_ROW"; printf '%s\n' "$@"; } > "$f"
}
create() {  # create <표 파일> <폴더 레포 상대> — rc 를 echo 한다
  local rc=0
  (cd "$W" && python3 "$RW" create --brief docs/iv/brief.md --audit docs/iv/brief.audit.md \
     --plan-table "$1" --out "$2" --title "픽스처 일" --date 2026-10-15 --approval "이대로 승인 (권장)") \
     > "$T/out.txt" 2>&1 || rc=$?
  echo "$rc"
}

# ── create 성공 (AC4) ───────────────────────────────────────────────────────
table "$T/state.md" "$P1_ROW" "$E1_ROW" "$E2_ROW"
assert_eq "$(create "$T/state.md" docs/rm)" "0" "create: rc 0"
assert_eq "$(tree_of "$W/docs/rm")" "$(printf './E1.md\n./E2.md\n./roadmap.md')" "create: 로드맵 하나 · 묶음 둘"
assert_eq "$(four_empty docs/rm/roadmap.md)" "ok" "create: 검사기 네 목록이 빈 목록"
assert_file_has "$W/docs/rm/E1.md" "roadmap: docs/rm/roadmap.md" "묶음 frontmatter 의 roadmap 은 레포 상대경로"
assert_file_has "$W/docs/rm/E1.md" "source_brief: docs/iv/brief.md" "묶음 frontmatter 의 source_brief 는 레포 상대경로"
assert_file_has "$W/docs/rm/E1.md" "- 받는 것: 없음" "묶음 §7 받는 것은 표 칸 그대로"
assert_file_has "$W/docs/rm/E2.md" "- 받는 것: E1 의 x" "묶음 §7 받는 것은 표 칸 그대로(둘째)"
assert_file_has "$W/docs/rm/E1.md" "- 넘기는 것: E2 에 x" "묶음 §7 넘기는 것은 표 칸 그대로"
assert_file_has "$W/docs/rm/roadmap.md" "- 2026-10-15 · 처음 로드맵 · 승인 원문 「이대로 승인 (권장)」" "재분해 이력 첫 줄"
assert_file_has "$T/state.md" "## 생성 기록" "표 파일에 생성 기록 절"
assert_file_has "$T/state.md" "- docs/rm/E2.md" "생성 기록에 묶음 경로"

# ── 다시 생성 — 기록에 있는 파일만 덮어쓴다 (AC4 재생성) ─────────────────────
table "$T/state2.md" "$P1_ROW" "$E1_ROW" "${E2_ROW/둘째 의도/둘째 의도 고침}"
sed -n '/^## 생성 기록/,$p' "$T/state.md" >> "$T/state2.md"
cp "$W/docs/rm/E1.md" "$T/E1.before"
assert_eq "$(create "$T/state2.md" docs/rm)" "0" "다시 생성: rc 0"
assert_file_has "$W/docs/rm/E2.md" "- 의도: 둘째 의도 고침" "다시 생성: 바뀐 표가 묶음에 실린다"
cmp -s "$T/E1.before" "$W/docs/rm/E1.md" && ok "다시 생성: 안 바뀐 묶음은 같은 바이트" || no "다시 생성: E1 묶음이 바뀌었다"

# ── 기록에 없는 파일은 덮어쓰지 않는다 ──────────────────────────────────────
mkdir -p "$W/docs/rm2" && printf 'hand\n' > "$W/docs/rm2/roadmap.md"
table "$T/state3.md" "$P1_ROW" "$E1_ROW" "$E2_ROW"
cp "$T/state3.md" "$T/state3.before"
assert_eq "$(create "$T/state3.md" docs/rm2)" "1" "기록 밖 파일: rc 1"
assert_file_has "$T/out.txt" "덮어쓰지 않는다" "기록 밖 파일: 사유를 낸다"
assert_eq "$(cat "$W/docs/rm2/roadmap.md")" "hand" "기록 밖 파일: 바이트 그대로"
assert_eq "$(tree_of "$W/docs/rm2")" "./roadmap.md" "기록 밖 파일: 새 파일 없음"
cmp -s "$T/state3.before" "$T/state3.md" && ok "기록 밖 파일: 표 파일 그대로" || no "기록 밖 파일: 표 파일이 바뀌었다"

# ── 검증 실패 — 만든 파일을 지우고 미리 있던 파일은 그대로 (AC5) ────────────
mkdir -p "$W/docs/rm3" && printf 'keep\n' > "$W/docs/rm3/keep.md"
table "$T/state4.md" "${P1_ROW/S3 · OQ2/S3 · OQ2 · C99}" "$E1_ROW" "$E2_ROW"
cp "$T/state4.md" "$T/state4.before"
assert_eq "$(create "$T/state4.md" docs/rm3)" "1" "unknown_ids: rc 1"
assert_file_has "$T/out.txt" "unknown_ids" "unknown_ids: 사유에 목록 이름"
assert_file_has "$T/out.txt" "C99" "unknown_ids: 사유에 번호"
assert_eq "$(tree_of "$W/docs/rm3")" "./keep.md" "unknown_ids: 만든 파일이 남지 않는다"
assert_eq "$(cat "$W/docs/rm3/keep.md")" "keep" "unknown_ids: 미리 있던 파일은 그대로"
cmp -s "$T/state4.before" "$T/state4.md" && ok "unknown_ids: 생성 기록을 쓰지 않는다" || no "unknown_ids: 표 파일이 바뀌었다"

table "$T/state5.md" "$P1_ROW" "$E1_ROW" "${E2_ROW/ · K2/}"
assert_eq "$(create "$T/state5.md" docs/rm4)" "1" "unassigned: rc 1"
assert_file_has "$T/out.txt" "unassigned" "unassigned: 사유에 목록 이름"
[ -e "$W/docs/rm4" ] && no "unassigned: 만든 폴더가 남았다" || ok "unassigned: 만든 폴더도 남지 않는다"

table "$T/state6.md" "$P1_ROW" "${E1_ROW/ · S2 |/ |}" "$E2_ROW"
assert_eq "$(create "$T/state6.md" docs/rm5)" "1" "orphans: rc 1"
assert_file_has "$T/out.txt" "orphans" "orphans: 사유에 목록 이름"

# ── 실패 뒤 재실행 — 표를 고치면 성공한다 ───────────────────────────────────
table "$T/state4.md" "$P1_ROW" "$E1_ROW" "$E2_ROW"
assert_eq "$(create "$T/state4.md" docs/rm3)" "0" "실패 뒤 재실행: rc 0"
assert_eq "$(four_empty docs/rm3/roadmap.md)" "ok" "실패 뒤 재실행: 검사기 네 목록이 빈 목록"

# ── 표 오류 · 사용법 오류 ────────────────────────────────────────────────────
table "$T/state7.md" "$P1_ROW" "${E1_ROW/| 묶음 |/| 꾸러미 |}"
assert_eq "$(create "$T/state7.md" docs/rm6)" "1" "표 오류: rc 1"
[ -e "$W/docs/rm6" ] && no "표 오류: 폴더가 생겼다" || ok "표 오류: 아무것도 쓰지 않는다"
rc=0; (cd "$W" && python3 "$RW" create --brief docs/iv/brief.md) >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "2" "사용법 오류: rc 2"

# ── extract — 만든 로드맵에서 같은 표를 뽑는다 ──────────────────────────────
(cd "$W" && python3 "$RW" extract --roadmap docs/rm3/roadmap.md) > "$T/extracted.md"
assert_eq "$(sed -n '3,4p' "$T/extracted.md")" "$(printf '%s\n%s' "$HEAD_ROW" "$SEP_ROW")" "extract: 표 머리"
assert_file_has "$T/extracted.md" "$P1_ROW" "extract: 결정 행이 표 행과 같다"
assert_file_has "$T/extracted.md" "| E2 | 둘째 에픽 | 묶음 |" "extract: 묶음 행"

finish
```

`assert_eq` · `ok` · `no` · `finish` 는 `shared/tests/assert.sh` 의 것이고, `assert_file_has`(고정 문자열 포함)는 이 파일이 정의한다 — `assert.sh` 에는 파일 고정 문자열 단언이 없다(`assert_file_grep` 은 ERE 라 `·` · `(` 가 든 리터럴에 맞지 않는다). 끝에서 `chmod +x plugins/spec-distill/tests/test_roadmap_write.sh`.

- [ ] **Step 3: 실패를 확인한다**

Run: `cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_roadmap_write.py; bash plugins/spec-distill/tests/test_roadmap_write.sh | tail -5`
Expected: python 은 `No module named 'roadmap_write'`, 셸은 create 단언들이 ✗.

- [ ] **Step 4: 쓰기 모듈을 쓴다**

`plugins/spec-distill/scripts/roadmap_write.py`:

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_write.py — 승인된 분해안 표로 로드맵 · 에픽 묶음을 쓰고, 쓴 직후 검증한다.

명령줄:
  roadmap_write.py create --brief <brief> --audit <audit> --plan-table <표 파일> --out <로드맵 폴더>
                          --title <제목> --date <YYYY-MM-DD> --approval <승인 원문>
  roadmap_write.py update --roadmap <로드맵> --brief <brief> --audit <audit> --plan-table <새 표 파일>
                          --date <YYYY-MM-DD> --change <바뀐 것 한 줄> --approval <승인 원문>
  roadmap_write.py extract --roadmap <로드맵>     로드맵 블록 · 묶음에서 분해안 표를 뽑아 낸다(쓰지 않는다)

종료 코드: 0 성공 · 1 쓰지 않음(표 오류 · 덮어쓰기 거부 · 검증 실패 — 쓴 것은 모두 되돌렸다) · 2 사용법 오류.

검증은 쓴 로드맵에 `roadmap_status.py --roadmap-file <로드맵> --json` 을 돌려 format_errors · unassigned ·
orphans · unknown_ids 넷이 모두 빈 목록일 때만 성공이다. 검사기의 종료 코드는 보지 않는다 — origin/main 을
못 읽으면 3, 진행 경고면 1 이 나와 생성물의 유효성과 무관하다.
create 는 표 파일의 `## 생성 기록` 절에 자기가 만든 파일을 적고, 다시 돌 때 그 기록에 있는 파일만 덮어쓴다.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import roadmap_render as R  # noqa: E402
from check_bundle_coverage import FormatError, frontmatter, section_body, unquote  # noqa: E402
from roadmap_status import DATE_RE  # noqa: E402

RS = Path(__file__).resolve().parent / "roadmap_status.py"
RECORD_HEADING = "## 생성 기록"
LISTS = ("format_errors", "unassigned", "orphans", "unknown_ids")


class Refused(Exception):
    """쓰지 않는다 — 사유를 그대로 보이고 rc 1."""


class Usage(Exception):
    """사용법 오류 — rc 2."""


# ── 경로 · 읽기 ──────────────────────────────────────────────────────────────

def git_top(path) -> Path:
    d = Path(os.path.realpath(str(path)))
    while not d.is_dir():
        d = d.parent
    proc = subprocess.run(["git", "-C", str(d), "rev-parse", "--show-toplevel"],
                          stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    if proc.returncode != 0:
        raise Usage("git 작업 트리 밖이다: %s" % path)
    return Path(os.path.realpath(proc.stdout.decode("utf-8").strip()))


def rel(top: Path, path) -> str:
    try:
        return Path(os.path.realpath(str(path))).relative_to(top).as_posix()
    except ValueError:
        raise Usage("%s 가 작업 트리 %s 밖이다" % (path, top))


def read(path) -> str:
    try:
        return Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise Refused("못 읽었다: %s (%s)" % (path, exc))


# ── 쓰기 트랜잭션 ────────────────────────────────────────────────────────────

def _atomic(path: Path, data: bytes):
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".roadmap_write.")
    try:
        os.write(fd, data)
        os.close(fd)
        os.replace(tmp, str(path))
    except BaseException:
        try:
            os.close(fd)
        except OSError:
            pass
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


class Txn:
    """쓴 것을 기억했다가 되돌린다 — 덮어쓴 파일은 원래 바이트로, 새 파일 · 새 폴더는 지운다."""

    def __init__(self):
        self.saved, self.created, self.dirs = {}, [], []

    def ensure_dir(self, d: Path):
        missing = []
        while not d.exists():
            missing.append(d)
            d = d.parent
        for m in reversed(missing):
            m.mkdir()
            self.dirs.append(m)

    def _remember(self, path: Path):
        if path in self.saved or path in self.created:
            return
        if path.exists():
            self.saved[path] = path.read_bytes()
        else:
            self.created.append(path)

    def write(self, path: Path, text: str):
        self._remember(path)
        _atomic(path, text.encode("utf-8"))

    def remove(self, path: Path):
        self._remember(path)
        path.unlink()

    def rollback(self) -> list:
        errs = []
        for path, data in self.saved.items():
            try:
                _atomic(path, data)
            except OSError as exc:
                errs.append("%s 를 원래 바이트로 되돌리지 못했다: %s" % (path, exc))
        for path in self.created:
            try:
                if path.exists():
                    path.unlink()
            except OSError as exc:
                errs.append("%s 를 지우지 못했다: %s" % (path, exc))
        for d in reversed(self.dirs):
            try:
                d.rmdir()
            except OSError as exc:
                errs.append("%s 폴더를 지우지 못했다: %s" % (d, exc))
        return errs


def run_txn(txn: Txn, body):
    """body() 가 실패하면 되돌리고, 되돌리지 못한 것이 있으면 사유에 붙여 다시 올린다."""
    try:
        body()
    except BaseException as exc:
        errs = txn.rollback()
        if errs:
            raise Refused("%s / 되돌리지 못했다: %s" % (exc, " · ".join(errs)))
        raise


# ── 검증 ─────────────────────────────────────────────────────────────────────

def judge(stdout: str, rc: int) -> list:
    """검사기 JSON 에서 실패 사유 목록. 빈 목록이면 통과. rc 는 사유 글에만 쓴다."""
    try:
        report = json.loads(stdout)
    except ValueError:
        report = None
    if not isinstance(report, dict):
        return ["검사기 출력을 읽지 못했다(rc %d)" % rc]
    reasons = []
    for key in LISTS:
        value = report.get(key)
        if not isinstance(value, list):
            why = " · ".join(str(x) for x in report.get("unknown_reasons") or []) or "값 없음"
            reasons.append("%s: 셀 수 없음 — %s" % (key, why))
        elif value:
            reasons.append("%s: %s" % (key, " · ".join(str(x) for x in value)))
    return reasons


def _status_json(top: Path, roadmap: Path):
    try:
        proc = subprocess.run([sys.executable, str(RS), "--roadmap-file", str(roadmap), "--json"],
                              cwd=str(top), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except OSError as exc:
        return "", -1, str(exc)
    return proc.stdout.decode("utf-8", "replace"), proc.returncode, ""


def validate(top: Path, roadmap: Path) -> list:
    out, rc, err = _status_json(top, roadmap)
    if err:
        return ["검사기를 돌리지 못했다: %s" % err]
    return judge(out, rc)


# ── 생성 기록 ────────────────────────────────────────────────────────────────

def read_record(text: str) -> set:
    try:
        body = section_body(text, RECORD_HEADING)
    except FormatError as exc:
        raise Refused(str(exc))
    return {l[2:].strip() for l in (body or "").splitlines() if l.startswith("- ")}


def with_record(text: str, paths) -> str:
    block = RECORD_HEADING + "\n\n" + "".join("- %s\n" % p for p in sorted(paths))
    lines = text.splitlines(keepends=True)
    start = next((i for i, l in enumerate(lines) if l.rstrip("\r\n") == RECORD_HEADING), None)
    if start is None:
        return text.rstrip("\n") + "\n\n" + block
    end = next((j for j in range(start + 1, len(lines)) if lines[j].startswith("## ")), len(lines))
    tail = "".join(lines[end:])
    return "".join(lines[:start]) + block + ("\n" + tail if tail else "")


# ── 명령 ─────────────────────────────────────────────────────────────────────

def _date(value: str) -> str:
    if not DATE_RE.fullmatch(value):
        raise Usage("--date 는 YYYY-MM-DD 다: %r" % value)
    return value


def cmd_create(a) -> int:
    out_dir = Path(os.path.realpath(a.out))
    top = git_top(out_dir)
    roadmap = out_dir / "roadmap.md"
    brief_rel, audit_rel, roadmap_rel = rel(top, a.brief), rel(top, a.audit), rel(top, roadmap)
    date = _date(a.date)
    table_path = Path(a.plan_table)
    table_text = read(table_path)
    rows = R.parse_table(table_text)
    idx = R.index_brief(read(a.brief), read(a.audit))
    history = "- %s · 처음 로드맵 · 승인 원문 「%s」" % (date, a.approval)
    files = {roadmap: R.render_roadmap(read(R.TEMPLATE), rows, idx, a.title, brief_rel, roadmap_rel, history)}
    for r in rows:
        if r.kind == R.KIND_BUNDLE:
            files[out_dir / (r.id + ".md")] = R.render_bundle(r, idx, roadmap_rel, brief_rel, audit_rel)
    record = read_record(table_text)
    targets = {rel(top, p) for p in files}
    stray = sorted(rel(top, p) for p in files if p.exists() and rel(top, p) not in record)
    if stray:
        raise Refused("이 생성기가 만들지 않은 파일은 덮어쓰지 않는다 — %s" % " · ".join(stray))
    stale = [top / p for p in sorted(record - targets) if (top / p).parent == out_dir]
    txn = Txn()

    def body():
        txn.ensure_dir(out_dir)
        for path, text in files.items():
            txn.write(path, text)
        for path in stale:
            if path.exists():
                txn.remove(path)
        reasons = validate(top, roadmap)
        if reasons:
            raise Refused("검증 실패 — %s" % " / ".join(reasons))
        txn.write(table_path, with_record(table_text, targets))

    run_txn(txn, body)
    print("[spec-distill] 로드맵을 만들었다: %s (묶음 %d개) — 검사기 네 목록이 비었다"
          % (roadmap_rel, len(files) - 1))
    return 0


def cmd_extract(a) -> int:
    roadmap = Path(os.path.realpath(a.roadmap))
    rdir = roadmap.parent
    rows = R.extract_rows(read(roadmap),
                          lambda name: read(rdir / name) if (rdir / name).is_file() else None)
    sys.stdout.write(R.format_table(rows))
    return 0


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(prog="roadmap_write.py",
                                 description="분해안 표로 로드맵 · 에픽 묶음을 쓰고 검증한다.")
    sub = ap.add_subparsers(dest="cmd")
    sub.required = True
    c = sub.add_parser("create")
    for flag in ("--brief", "--audit", "--plan-table", "--out", "--title", "--date", "--approval"):
        c.add_argument(flag, required=True)
    e = sub.add_parser("extract")
    e.add_argument("--roadmap", required=True)
    return ap


COMMANDS = {"create": cmd_create, "extract": cmd_extract}


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    a = build_parser().parse_args(argv)   # 사용법 오류는 argparse 가 rc 2 로 끝낸다
    try:
        return COMMANDS[a.cmd](a)
    except Usage as exc:
        print("[spec-distill] 사용법 오류 — %s" % exc, file=sys.stderr)
        return 2
    except (Refused, R.TableError, FormatError) as exc:
        print("[spec-distill] 로드맵을 쓰지 않았다 — %s" % exc)
        return 1
    except Exception as exc:  # 쓰다 죽어도 성공(0)으로 내지 않는다 — 쓴 것은 run_txn 이 되돌렸다
        print("[spec-distill] 로드맵을 쓰지 않았다 — 내부 오류 %s: %s" % (type(exc).__name__, exc))
        return 1


if __name__ == "__main__":
    sys.exit(main())
```

주의: `cmd_create` 에서 표 파일의 생성 기록 쓰기는 같은 트랜잭션 안이다 — 검증이 통과한 뒤에만 쓰고, 그 쓰기가 실패하면 만든 파일도 함께 되돌린다.

- [ ] **Step 5: 테스트를 돌린다**

Run: `cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 && chmod +x plugins/spec-distill/tests/test_roadmap_write.sh && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v plugins/spec-distill/tests/test_roadmap_write.py && bash plugins/spec-distill/tests/test_roadmap_write.sh | tail -3`
Expected: python 전부 PASS, 셸 마지막 줄이 실패 0.

- [ ] **Step 6: 커밋**

```bash
git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 add -- plugins/spec-distill/scripts/roadmap_write.py plugins/spec-distill/tests/test_roadmap_write.py plugins/spec-distill/tests/test_roadmap_write.sh
git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 ls-files -s plugins/spec-distill/tests/test_roadmap_write.sh   # 100755 확인
git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 commit -m "feat(spec-distill): 로드맵 생성기 create · extract 와 쓴 직후 검증 · 되돌리기" -m "<트레일러 셋>"
```

---

### Task 3: `roadmap_write.py update` — 바뀐 블록만 · 머지된 에픽 불변 · 번호 규칙 · 되돌리기

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_write.py`
- Modify: `plugins/spec-distill/tests/test_roadmap_write.sh`(update 절을 `finish` 앞에 덧붙인다)

**Interfaces:**
- Consumes: Task 1 `extract_rows · parse_table · render_block · render_bundle · epic_block_texts · replace_epics · append_history · index_brief`, Task 2 `Txn · run_txn · validate · _status_json · git_top · rel · read · Refused · Usage`.
- Produces: CLI `update`, `stages(top, roadmap) -> dict[id, stage]`, `used_numbers(roadmap_text) -> dict[letter, int]`.

규칙:
- 바뀜 = 새 표와 지금 표(`extract_rows`)의 행이 다르다. 새 = 새 표에만 있다. 사라짐 = 지금 표에만 있다. 셋 다 없고 순서도 같으면 아무것도 쓰지 않고 rc 0(「바뀐 에픽이 없다」).
- 머지 여부는 `roadmap_status.py --roadmap-file <로드맵> --json` 의 블록 `stage` 로 본다. 바뀜 · 사라짐 에픽 중 `머지됨` · `끝남` 이 있으면 쓰기 전에 rc 1. 검사기 출력을 못 읽거나 블록 하나라도 단계가 `알 수 없음`/없음이면 머지 여부를 모르므로 rc 1.
- 새 에픽 번호는 `<대문자><숫자>`(소문자 꼬리 없음)이고, 같은 글자로 로드맵 블록 · `## 재분해 이력` 에 나온 가장 큰 숫자보다 커야 한다(사라진 번호 재사용 금지 — 이력 줄이 사라진 번호를 남긴다).
- 안 바뀐 블록은 로드맵의 원래 글을 그대로, 바뀐 · 새 블록은 `render_block`. 묶음은 바뀐 · 새 묶음 에픽만 다시 쓰고(바이트가 같으면 쓰지 않음), 사라진 에픽과 묶음에서 다른 종류로 바뀐 에픽의 묶음 파일은 지운다.
- 이력 줄: `- <date> · 재분해 · <change> · 바뀜 <…> · 새 <…> · 사라짐 <…> 「<approval>」`(빈 갈래는 뺀다).
- `--brief` 의 레포 상대경로가 로드맵 frontmatter `source_brief` 와 다르면 rc 1.
- 모든 글은 쓰기 전에 만든다. 쓴 뒤 `validate` 실패 → 덮어쓴 로드맵 · 묶음은 원래 바이트, 새 묶음은 지움, 지운 묶음은 복원, rc 1.

- [ ] **Step 1: 실패하는 셸 테스트를 덧붙인다** *(plan-authored test code — 리뷰어: 이 테스트 코드도 검사 대상이다)*

`plugins/spec-distill/tests/test_roadmap_write.sh` 의 마지막 `finish` 줄 **앞에** 넣는다:

```bash
# ── update 픽스처: docs/rm 을 main 에 올리고 E1 을 머지한다 ──────────────────
g add -- docs/rm && g commit -qm roadmap
g checkout -qb feature/e1 && mkdir -p "$W/a" && printf 'x\n' > "$W/a/x.py" && g add -- a && g commit -qm e1
g checkout -q main && g merge -q --no-ff feature/e1 -m "Merge pull request #1 from o/feature/e1"
g push -q origin main && g fetch -q origin
snap() { rm -rf "$T/snap" && cp -R "$W/docs/rm" "$T/snap"; }
same_as_snap() { diff -r "$T/snap" "$W/docs/rm" >/dev/null 2>&1 && echo same || echo changed; }
update() {  # update <표 파일> — rc 를 echo 한다
  local rc=0
  (cd "$W" && python3 "$RW" update --roadmap docs/rm/roadmap.md --brief docs/iv/brief.md \
     --audit docs/iv/brief.audit.md --plan-table "$1" --date 2026-10-16 --change "경계 조정" \
     --approval "이대로 다시 나눈다") > "$T/out.txt" 2>&1 || rc=$?
  echo "$rc"
}
(cd "$W" && python3 "$RW" extract --roadmap docs/rm/roadmap.md) > "$T/now.md"
E1_NOW="$(grep '^| E1 |' "$T/now.md")"
E2_NOW="$(grep '^| E2 |' "$T/now.md")"
P1_NOW="$(grep '^| P1 |' "$T/now.md")"

# 바뀐 것 없음 — 쓰지 않는다
snap
assert_eq "$(update "$T/now.md")" "0" "update 변화 없음: rc 0"
assert_eq "$(same_as_snap)" "same" "update 변화 없음: 아무것도 쓰지 않는다"

# 머지된 E1 은 그대로, 진행 전 E2 만 바뀐다 (AC10)
table "$T/u1.md" "$P1_NOW" "$E1_NOW" "${E2_NOW/한다 다 /한다 다 · 마 }"
cp "$W/docs/rm/E1.md" "$T/E1.keep"
assert_eq "$(update "$T/u1.md")" "0" "update: rc 0"
cmp -s "$T/E1.keep" "$W/docs/rm/E1.md" && ok "update: 머지된 E1 묶음은 바이트 그대로" || no "update: E1 묶음이 바뀌었다"
assert_file_has "$W/docs/rm/E2.md" "- 범위: 한다 다 · 마 / 안 한다 라" "update: 바뀐 E2 묶음 범위 줄"
assert_file_has "$W/docs/rm/roadmap.md" "- 범위: 한다 다 · 마 / 안 한다 라" "update: 바뀐 E2 블록 범위 줄"
assert_file_has "$W/docs/rm/roadmap.md" "- 2026-10-16 · 재분해 · 경계 조정 · 바뀜 E2 「이대로 다시 나눈다」" "update: 재분해 이력 줄"
assert_eq "$(four_empty docs/rm/roadmap.md)" "ok" "update: 검사기 네 목록이 빈 목록"

# 머지된 E1 을 바꾸는 표는 거부 — 아무것도 쓰지 않는다
snap
table "$T/u2.md" "$P1_NOW" "${E1_NOW/첫 의도/첫 의도 고침}" "$(grep '^| E2 |' "$T/u1.md")"
assert_eq "$(update "$T/u2.md")" "1" "머지된 에픽 변경: rc 1"
assert_file_has "$T/out.txt" "E1" "머지된 에픽 변경: 사유에 번호"
assert_eq "$(same_as_snap)" "same" "머지된 에픽 변경: 바이트 그대로"

# 새 에픽 E3 — 다음 번호 · 묶음 생성, 그다음 E3 를 지우고, 같은 번호 재사용은 거부
E2_U1="$(grep '^| E2 |' "$T/u1.md")"
E3_ROW='| E3 | 셋째 에픽 | 묶음 | 셋째 의도 | 한다 바 / 안 한다 사 | E2 | feature/e3 | 없음 | C3 · S1 | E2 의 결과 | 없음 |'
table "$T/u3.md" "$P1_NOW" "$E1_NOW" "$E2_U1" "$E3_ROW"
assert_eq "$(update "$T/u3.md")" "0" "새 에픽: rc 0"
[ -f "$W/docs/rm/E3.md" ] && ok "새 에픽: 묶음을 만든다" || no "새 에픽: E3.md 없음"
table "$T/u4.md" "$P1_NOW" "$E1_NOW" "$E2_U1"
assert_eq "$(update "$T/u4.md")" "0" "에픽 지우기: rc 0"
[ -e "$W/docs/rm/E3.md" ] && no "에픽 지우기: E3.md 가 남았다" || ok "에픽 지우기: 묶음을 지운다"
assert_file_has "$W/docs/rm/roadmap.md" "사라짐 E3" "에픽 지우기: 이력에 사라진 번호"
snap
assert_eq "$(update "$T/u3.md")" "1" "번호 재사용: rc 1"
assert_eq "$(same_as_snap)" "same" "번호 재사용: 바이트 그대로"
table "$T/u5.md" "$P1_NOW" "$E1_NOW" "$E2_U1" "${E3_ROW/| E3 |/| E4a |}"
assert_eq "$(update "$T/u5.md")" "1" "꼬리 붙은 새 번호: rc 1"

# 검증 실패 — 덮어쓴 파일은 원래 바이트, 새 묶음은 남지 않는다 (AC10)
snap
E4_ROW='| E4 | 넷째 에픽 | 묶음 | 넷째 의도 | 한다 아 / 안 한다 자 | E2 | feature/e4 | 없음 | C1 · S1 | 없음 | 없음 |'
table "$T/u6.md" "${P1_NOW/S3 · OQ2/S3 · OQ2 · C99}" "$E1_NOW" "${E2_U1/둘째 에픽/둘째 에픽 고침}" "$E4_ROW"
assert_eq "$(update "$T/u6.md")" "1" "update 검증 실패: rc 1"
assert_file_has "$T/out.txt" "unknown_ids" "update 검증 실패: 사유"
assert_eq "$(same_as_snap)" "same" "update 검증 실패: 로드맵 · 묶음이 원래 바이트, 새 묶음 없음"

# origin/main 없음 — 머지 여부를 모르면 쓰지 않는다
snap
MAIN_SHA="$(g rev-parse refs/remotes/origin/main)"
g update-ref -d refs/remotes/origin/main
assert_eq "$(update "$T/u3.md")" "1" "origin/main 없음: rc 1"
assert_file_has "$T/out.txt" "머지 여부를 알 수 없다" "origin/main 없음: 사유"
assert_eq "$(same_as_snap)" "same" "origin/main 없음: 바이트 그대로"
g update-ref refs/remotes/origin/main "$MAIN_SHA"
```

마지막 절이 `u3` 를 쓰는 이유: 그 시점의 로드맵에는 `u1` 이 이미 적용돼 있어 `u1` 은 「바뀐 것 없음」(rc 0)으로 끝난다. `u3` 는 E3 를 더하는 표라 바뀐 것이 있고, 구현 순서가 「바뀐 것 계산 → stages → 머지 거부 → 번호 규칙」이므로 번호 재사용 거부보다 먼저 「머지 여부를 알 수 없다」로 멈춘다.

- [ ] **Step 2: 실패를 확인한다**

Run: `cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 && bash plugins/spec-distill/tests/test_roadmap_write.sh | tail -5`
Expected: update 단언들이 ✗(argparse 가 `update` 를 모른다 — rc 2).

- [ ] **Step 3: update 를 구현한다**

`roadmap_write.py` 에 더한다(`import re` 를 위에 더한다):

```python
DONE = ("머지됨", "끝남")
NEW_ID_RE = re.compile(r"[A-Z][0-9]+")
ID_TOKEN_RE = re.compile(r"(?<![A-Za-z0-9])([A-Z])([0-9]+)")


def stages(top: Path, roadmap: Path) -> dict:
    out, rc, err = _status_json(top, roadmap)
    try:
        report = json.loads(out) if not err else None
    except ValueError:
        report = None
    if not isinstance(report, dict):
        raise Refused("머지 여부를 알 수 없다 — 검사기 출력을 읽지 못했다(rc %d) %s" % (rc, err))
    got = {b.get("id"): b.get("stage") for b in report.get("blocks") or []}
    unknown = sorted(i for i, s in got.items() if s in (None, "알 수 없음"))
    if not got or unknown:
        why = report.get("unknown_reasons") or report.get("format_errors") or unknown or ["블록 없음"]
        raise Refused("머지 여부를 알 수 없다 — %s" % " · ".join(str(x) for x in why))
    return got


def used_numbers(roadmap_text: str) -> dict:
    """글자마다 로드맵 블록 번호 · 재분해 이력에 나온 가장 큰 숫자."""
    corpus = " ".join(R.epic_block_texts(roadmap_text)) + "\n" + (section_body(roadmap_text, "## 재분해 이력") or "")
    best = {}
    for letter, num in ID_TOKEN_RE.findall(corpus):
        best[letter] = max(best.get(letter, -1), int(num))
    return best


def cmd_update(a) -> int:
    roadmap = Path(os.path.realpath(a.roadmap))
    top = git_top(roadmap)
    rdir = roadmap.parent
    roadmap_rel, brief_rel, audit_rel = rel(top, roadmap), rel(top, a.brief), rel(top, a.audit)
    date = _date(a.date)
    old_text = read(roadmap)
    if unquote(frontmatter(old_text).get("source_brief", "")) != brief_rel:
        raise Refused("로드맵의 source_brief 가 --brief(%s) 와 다르다" % brief_rel)
    old_rows = R.extract_rows(old_text, lambda n: read(rdir / n) if (rdir / n).is_file() else None)
    new_rows = R.parse_table(read(a.plan_table))
    idx = R.index_brief(read(a.brief), read(a.audit))
    old = {r.id: r for r in old_rows}
    new = {r.id: r for r in new_rows}
    changed = [i for i in new if i in old and new[i] != old[i]]
    added = [i for i in new if i not in old]
    removed = [i for i in old if i not in new]
    if not (changed or added or removed) and list(new) == list(old):
        print("[spec-distill] 바뀐 에픽이 없다 — 쓰지 않았다")
        return 0
    st = stages(top, roadmap)
    frozen = [i for i in changed + removed if st.get(i) in DONE]
    if frozen:
        raise Refused("머지되거나 끝난 에픽은 바꾸거나 지우지 않는다 — %s" % " · ".join(frozen))
    used = used_numbers(old_text)
    bad = [i for i in added if not NEW_ID_RE.fullmatch(i) or int(i[1:]) <= used.get(i[0], -1)]
    if bad:
        raise Refused("새 에픽은 쓴 적 없는 다음 번호(`<글자><가장 큰 수+1>` 이상)여야 한다 — %s" % " · ".join(bad))
    texts = R.epic_block_texts(old_text)
    blocks = [texts[r.id] if r.id in old and r.id not in changed else R.render_block(r) for r in new_rows]
    parts = [a.change] + ["%s %s" % (label, " · ".join(ids))
                          for label, ids in (("바뀜", changed), ("새", added), ("사라짐", removed)) if ids]
    new_text = R.append_history(R.replace_epics(old_text, blocks),
                                "- %s · 재분해 · %s 「%s」" % (date, " · ".join(parts), a.approval))
    writes, removes = {roadmap: new_text}, []
    for i in changed + added:
        path = rdir / (i + ".md")
        if new[i].kind == R.KIND_BUNDLE:
            text = R.render_bundle(new[i], idx, roadmap_rel, brief_rel, audit_rel)
            if not path.is_file() or path.read_text(encoding="utf-8") != text:
                writes[path] = text
        elif i in old and old[i].kind == R.KIND_BUNDLE and path.exists():
            removes.append(path)
    removes += [rdir / (i + ".md") for i in removed
                if old[i].kind == R.KIND_BUNDLE and (rdir / (i + ".md")).exists()]
    txn = Txn()

    def body():
        for path, text in writes.items():
            txn.write(path, text)
        for path in removes:
            txn.remove(path)
        reasons = validate(top, roadmap)
        if reasons:
            raise Refused("검증 실패 — %s" % " / ".join(reasons))

    run_txn(txn, body)
    print("[spec-distill] 로드맵을 다시 나눴다: %s — %s · 묶음 %d개 씀 · %d개 지움"
          % (roadmap_rel, " · ".join(parts[1:]) or "순서만", len(writes) - 1, len(removes)))
    return 0
```

`build_parser` 에 서브커맨드를 더한다:

```python
    u = sub.add_parser("update")
    for flag in ("--roadmap", "--brief", "--audit", "--plan-table", "--date", "--change", "--approval"):
        u.add_argument(flag, required=True)
```

`COMMANDS` 에 `"update": cmd_update` 를 더한다.

- [ ] **Step 4: 테스트를 돌린다**

Run: `cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 && bash plugins/spec-distill/tests/test_roadmap_write.sh | tail -3 && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_roadmap_write.py plugins/spec-distill/tests/test_roadmap_render.py`
Expected: 실패 0.

- [ ] **Step 5: 커밋**

```bash
git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 add -- plugins/spec-distill/scripts/roadmap_write.py plugins/spec-distill/tests/test_roadmap_write.sh
git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 commit -m "feat(spec-distill): 로드맵 재분해 update — 바뀐 블록만 · 머지된 에픽 불변 · 실패 시 원래 바이트" -m "<트레일러 셋>"
```

---

### Task 4: 인터뷰 종료의 분해 판단 · 생성 · 재생성 · 커밋 안내 · 다음 세션 줄

**Files:**
- Modify: `plugins/spec-distill/skills/spec-interview/references/finishing.md`
- Modify: `plugins/spec-distill/skills/spec-interview/SKILL.md`(`## 종료 — brief 작성 + optional handoff` 첫 문단 뒤 한 줄)
- Modify: `plugins/spec-distill/templates/interview-brief-template.md`(`## 7. Next Action` 안내)
- Test: `plugins/spec-distill/tests/test_decompose_surface.sh`(새, 100755)

**Interfaces:**
- Consumes: Task 2 · 3 의 CLI(`create` 인자 · 종료 코드 · `## 생성 기록`).
- Produces: state 본문 `## 분해안` 절(열한 칸 표 + `승인: 「…」` 줄), state 카운터 `decompose_edits`, 다음 세션 줄 표지 `**다음 세션 줄 — 분해된 일 ①/② 공통**`.

- [ ] **Step 1: 실패하는 문면 락을 쓴다** *(plan-authored test code — 리뷰어: 이 테스트 코드도 검사 대상이다)*

`plugins/spec-distill/tests/test_decompose_surface.sh`:

```bash
#!/usr/bin/env bash
# R4 분해 판단 · 재분해 문면 락(AC1 · AC2 · AC3 · AC7 · AC8 · AC11).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_decompose_surface.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SD="$ROOT/plugins/spec-distill"
FIN="$SD/skills/spec-interview/references/finishing.md"
SKILL="$SD/skills/spec-interview/SKILL.md"
TPL="$SD/templates/interview-brief-template.md"

win() {  # win <파일> <시작 줄 리터럴> <끝 줄 접두> — 시작 줄 다음부터 끝 줄 앞까지
  awk -v s="$2" -v e="$3" '$0==s{f=1;next} f&&index($0,e)==1{exit} f' "$1"
}
has() {  # has <창> <리터럴> <라벨>
  case "$1" in *"$2"*) ok "$3" ;; *) no "$3 — 없음: $2" ;; esac
}
assert_file_has() {  # assert_file_has <파일> <고정 문자열> <라벨>
  if grep -qF -- "$2" "$1" 2>/dev/null; then ok "$3"; else no "$3 — 없음: $2"; fi
}

# ── AC1 · AC2 — 분해 판단 단계 ──────────────────────────────────────────────
DEC="$(win "$FIN" '### 분해 판단 — Step A 직전' '### Step A')"
if [ -n "$DEC" ]; then ok "분해 판단 절이 Step A 앞에 있다"; else no "분해 판단 절 창이 비었다 — 앵커 파손"; fi
for lit in '따로 승인할 수 있는 덩어리 수' '파일 영역 수' '사용자 원문 갈래 수' '근거 번호' \
           '컷오프는 두지 않는다' '하나로 충분해 보인다' '나누는 게 좋아 보인다' \
           '"spec 하나로"' '"나눈다 — 분해안 보기"' \
           '| 번호 | 이름 | 종류 | 의도 | 범위 | 의존 | 브랜치 | 경로 예약 | 배정 번호 | 받는 것 | 넘기는 것 |' \
           '「묶음」' '「브랜치 <설계문서 경로>」' '「결정」' '걷는 뼈대' \
           '미배정 번호 <n> · 고아 발화 <m>' '「승인」' '「고치기」' '「spec 하나로」' '계속 고칠까요' \
           '자동으로 끝내지 않는다' '## 분해안' '분해됨 — <로드맵 경로>'; do
  has "$DEC" "$lit" "분해 판단: $lit"
done
# 부재 · 존재 짝 — 숫자 컷오프 문면이 없다(존재 짝은 위 「컷오프는 두지 않는다」).
cut="$(printf '%s\n' "$DEC" | grep -nE '[0-9]+ ?(개|곳|갈래|영역|덩어리)( 이상| 넘| 초과|보다 많)' || true)"
assert_eq "$cut" "" "분해 판단: 숫자 컷오프 문면이 없다"
assert_file_absent "$FIN" '이상이면 나눈다' "finishing: 「이상이면 나눈다」 문면이 없다"

# ── AC3 · AC4 — 생성 · 재생성 ───────────────────────────────────────────────
STEPA="$(win "$FIN" '### Step A — brief 작성 (terminal 산출물, 2파일)' '### Step A.5')"
has "$STEPA" 'roadmap_write.py" create' "Step A: 생성기 create 를 부른다"
has "$STEPA" '--plan-table' "Step A: 분해안 표를 넘긴다"
has "$STEPA" '분해 판단 3' "Step A: 실패하면 분해안 표로 돌아간다"
REGEN="$(win "$FIN" '#### B-R — 로드맵 다시 생성 (분해된 일만)' '#### ')"
if [ -n "$REGEN" ]; then ok "Step B: 다시 생성 절이 있다"; else no "Step B: B-R 창이 비었다"; fi
for lit in 'brief 를 마지막으로 쓴 직후' '언제나 한 번' '항목이 바뀌었는지와 상관없다' '## 생성 기록' \
           '커밋 전에 도는 단계' 'brief · audit · 상태 파일 · 로드맵 폴더를 함께 커밋하라'; do
  has "$REGEN" "$lit" "B-R: $lit"
done
assert_file_absent "$FIN" '항목이 바뀌면 확정 직후' "옛 「항목이 바뀌면」 재생성 조건이 없다"

# ── AC7 — 분해된 일의 다음 세션 줄 ──────────────────────────────────────────
MARK='**다음 세션 줄 — 분해된 일 ①/② 공통**'
DLINE="$(awk -v m="$MARK" '$0==m{f=1;next} f&&NF{print;exit}' "$FIN")"
case "$DLINE" in
  '> `@<roadmap-path> 이 로드맵의 지휘 절차대로 진행하라.'*) ok "분해된 일: 다음 세션 줄이 @<roadmap-path> 지휘 줄" ;;
  *) no "분해된 일: 다음 세션 줄이 다르다: $DLINE" ;;
esac
has "$DLINE" '사람에게 쓰는 글 규칙' "분해된 일: 다음 세션 줄이 글 규칙을 싣는다"
n_brief="$(grep -cE '^[[:space:]]*> `(@<[^<>]+> )+이 interview brief 로' "$FIN" || true)"
assert_eq "$n_brief" "1" "나누지 않은 일의 brief 줄은 그대로 하나"

# ── SKILL · 템플릿 ──────────────────────────────────────────────────────────
assert_file_has "$SKILL" "「분해 판단」 단계부터" "SKILL: 종료 뒤 분해 판단을 가리킨다"
assert_file_has "$TPL" "분해됨 — <로드맵 경로>" "brief 템플릿 §7: 분해 줄"

finish
```

`has` 의 리터럴에 `"` 가 든 두 줄(`"spec 하나로"` · `"나눈다 — 분해안 보기"`)은 `AskUserQuestion` 펜스의 label 문자열을 잰다. `assert_eq` · `assert_file_absent`(ERE) · `ok` · `no` · `finish` 는 `shared/tests/assert.sh` 의 것이고 `assert_file_has` 는 이 파일이 정의한다. 끝에서 `chmod +x`.

- [ ] **Step 2: 실패를 확인한다**

Run: `cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 && chmod +x plugins/spec-distill/tests/test_decompose_surface.sh && bash plugins/spec-distill/tests/test_decompose_surface.sh | tail -3`
Expected: 다수 ✗.

- [ ] **Step 3: finishing.md 에 분해 판단 절을 넣는다**

`### Step A — brief 작성 (terminal 산출물, 2파일)` 줄 **바로 앞**(「사용자-승인 박제로 닫힌 floor」 문단 뒤)에 이 절을 넣는다:

````markdown
### 분해 판단 — Step A 직전

종료가 정해진 뒤 brief 를 쓰기 전에 이 일을 spec 하나로 할지 나눌지 사용자와 정한다. 나누지 않으면 아래 Step A 부터 지금 흐름 그대로다 — 로드맵을 만들지 않는다.

1. **신호 셋.** 인터뷰가 모은 것에서 세 숫자를 한 줄씩 보인다. 숫자마다 근거 번호를 괄호에 붙인다. 컷오프는 두지 않는다 — 숫자는 판단 재료이고 판정은 사용자가 한다.
   - 따로 승인할 수 있는 덩어리 수 — 확정 항목 · 열린 질문을 닿는 대상(고칠 자리 · 하류 단계)으로 묶은 결정 묶음의 수. 보기: `따로 승인할 수 있는 덩어리 3 (C1 · C4 / OQ2 · RC3 / D5)`.
   - 파일 영역 수 — 조사에서 나온 고칠 자리(`RC<n>` 의 경로)의 플러그인 · 디렉토리 수. 보기: `파일 영역 2 (plugins/a/ ← RC1 · RC2 / shared/ ← RC4)`.
   - 사용자 원문 갈래 수 — 최초 요청(S1)과 이후 발화가 말하는 일의 갈래 수. 보기: `사용자 원문 갈래 2 (S1 · S7 / S12)`.

   이어서 권고 한 줄 — 「하나로 충분해 보인다 — <이유>」 또는 「나누는 게 좋아 보인다 — <이유>」.
2. **판정.** `AskUserQuestion` 하나:
   ```javascript
   AskUserQuestion({
     questions: [{
       question: "신호 셋과 권고를 위에 적었다. 이 일을 어떻게 진행할까?",
       header: "분해 판단",
       options: [
         {label: "spec 하나로", description: "지금처럼 brief 하나를 brainstorming 하나로 넘긴다. 로드맵을 만들지 않는다."},
         {label: "나눈다 — 분해안 보기", description: "에픽 표를 제안받아 고치거나 승인한다. 승인하면 로드맵과 에픽 묶음을 만든다."}
       ],
       multiSelect: false
     }]
   })
   ```
   「spec 하나로」면 Step A 로 간다.
3. **분해안 표.** 에픽 표를 제안한다. 칸은 열하나다:

   | 번호 | 이름 | 종류 | 의도 | 범위 | 의존 | 브랜치 | 경로 예약 | 배정 번호 | 받는 것 | 넘기는 것 |
   |---|---|---|---|---|---|---|---|---|---|---|

   - 번호는 `<대문자><숫자>`(보기: `R0` · `R1`, 먼저 확인할 일은 `P1`). 가능하면 첫 에픽은 걷는 뼈대 — 가장 얇게 끝에서 끝까지 도는 에픽이다.
   - 종류는 셋이다 — 「묶음」(에픽 묶음 파일을 만든다) · 「브랜치 <설계문서 경로>」(묶음 없이 이미 있는 설계문서를 가리킨다) · 「결정」(브랜치 없이 로드맵 결정 기록으로 끝난다). 「결정」이면 브랜치 칸은 「없음」이다.
   - 범위는 `한다 … / 안 한다 …`. 의존 · 경로 예약은 쉼표로 나열하고 없으면 「없음」. 빈 칸은 두지 않는다. 칸 안의 `|` 는 `\|` 로 쓴다.
   - 배정 번호 — brief 에 쓸 모든 번호(확정 C · D, 열린 질문 OQ, 레포 근거 RC, steelman ST, 웹 «key», 위험 K, 발화 S)를 하나 이상의 에픽에 배정한다. 모든 에픽이 받드는 공통 제약은 여러 에픽에 넣는다. 묶음 없는 두 종류에는 발화(S)와 그 밖의 번호가 하나 이상씩 있어야 한다. 위험 K 는 brief §5 의 번호 없는 위험 줄(숨은 가정 · 실패 양식 · 리뷰 참고 순)에 줄 순서대로 매길 번호다.
   - 받는 것 · 넘기는 것 — 에픽 사이 인터페이스다. 묶음 §7 에 이 두 칸이 글자 그대로 실린다.

   표 아래에 `미배정 번호 <n> · 고아 발화 <m>` 한 줄을 보이고, 0 이 아니면 그 번호를 나열한다. brief 를 쓰기 전이라 이 계산은 모델이 한다 — 인터뷰 state 의 번호 목록(위 일곱 종류)에서 표의 배정 번호 합집합을 뺀다. 확정 판정은 Step A 8 의 생성기 검증(`roadmap_status.py` 규칙)이 한다.
4. **고치기 · 승인.** `AskUserQuestion` 하나 — 옵션 셋: 「승인」(표를 확정하고 Step A 로) · 「고치기」(말로 받아 표를 고쳐 다시 보인다) · 「spec 하나로」(나누지 않고 Step A 로). 고친 횟수는 state `decompose_edits` 에 센다. 세 번 고칠 때마다 「계속 고칠까요」를 묻고(옵션: 「계속 고친다」 · 「지금 표로 승인」 · 「spec 하나로」) 자동으로 끝내지 않는다.
5. **기록.** 승인된 표를 state 파일(`$ROOT/<session-id>/state.local.md`) 본문의 `## 분해안` 절에 위 머리 그대로 적고, 표 아래에 `승인: 「<사용자가 고른 옵션 또는 말>」` 한 줄을 둔다. 로드맵 폴더는 `docs/superpowers/roadmaps/<YYYY-MM-DD>-<kebab-topic>/` 다(brief 와 같은 날짜 · 주제). Step A 는 brief §7 첫 줄에 `분해됨 — <로드맵 경로>` 를 쓴다.
````

- [ ] **Step 4: Step A 에 생성 단계를 넣는다**

Step A 의 7 항(「기계적 게이트 검증」) 끝 문단(「… 첫 게이트 실행이 항상 red입니다.」) 뒤에:

````markdown
8. **로드맵 · 묶음 생성 — 분해된 일만.** 분해 판단에서 표를 승인했으면 게이트를 통과한 직후 생성기를 돌린다:
   ```bash
   SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
   ROOT="$(python3 "$SD/scripts/state_path.py" state-root)"
   python3 "$SD/scripts/roadmap_write.py" create --brief "docs/superpowers/interview/<file>" \
     --audit "docs/superpowers/interview/<audit file>" --plan-table "$ROOT/<session-id>/state.local.md" \
     --out "docs/superpowers/roadmaps/<YYYY-MM-DD>-<kebab-topic>/" --title "<주제 한 줄>" \
     --date "<YYYY-MM-DD>" --approval "<승인 원문>"
   ```
   rc 0 이면 나온 `[spec-distill]` 줄을 그대로 보인다. rc 1 이면 사유 줄을 그대로 보이고 분해 판단 3(분해안 표)으로 돌아간다 — 생성기가 만든 파일은 이미 지워졌고 미리 있던 파일은 그대로다. 표를 고쳐 승인받은 뒤 다시 돈다. 생성기는 표 파일에 `## 생성 기록` 절을 남긴다 — Step B 의 다시 생성이 그 기록에 있는 파일만 덮어쓴다.
````

- [ ] **Step 5: Step B 에 다시 생성 · 커밋 안내 · 분해된 일의 다음 세션 줄을 넣는다**

`#### B-4 — 두 가드 (load-bearing)` 줄 **바로 앞**에:

````markdown
#### B-R — 로드맵 다시 생성 (분해된 일만)

분해된 일이면 Step B 를 끝내는 모든 갈래(① · ② · ④ · 확정 목록 재제시 상한의 종료 · B-1 superpowers 부재 정지)에서, 그 갈래가 brief 를 마지막으로 쓴 직후 · 두 줄이나 정지 문구를 보이기 전에 Step A 8 의 명령을 그대로 언제나 한 번 더 돌린다. 항목이 바뀌었는지와 상관없다 — 확정 반영은 brief 줄을 늘 바꾸고, 리뷰 · B-A 박제도 항목을 더한다. 두 번째 실행은 첫 실행이 표 파일에 적은 `## 생성 기록` 에 있는 파일만 덮어쓰고 기록 밖의 파일은 건드리지 않는다. rc 1 이면 사유를 보이고 분해 판단 3 으로 돌아간다(표를 고쳐 승인받은 뒤 Step A 8 부터 다시). 커밋 전에 도는 단계라 이 결과가 커밋 대상이다.

**커밋 — 분해된 일만.** 이 파일에 brief · audit · 상태 파일을 경로 지정으로 커밋하는 단계가 생기면(R7 의 커밋 규칙) 그 경로 지정에 로드맵 폴더를 더한다. 그 단계가 없는 동안은 다시 생성 직후, 두 줄이나 정지 문구 **앞에** 이 한 줄을 보인다:

> `[spec-distill] brief · audit · 상태 파일 · 로드맵 폴더를 함께 커밋하라 — <brief 경로> · <audit 경로> · <상태 파일 경로> · <로드맵 폴더>. 지휘 세션은 이 파일들이 기본 브랜치에 머지된 뒤 연다.`

**다음 세션 줄 — 분해된 일 ①/② 공통**

> `@<roadmap-path> 이 로드맵의 지휘 절차대로 진행하라. 에픽마다 그 에픽 묶음을 입력으로 brainstorming 을 시작하고, 설계문서를 커밋한 뒤 spec-distill:spec-review 를 부른다. confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지. 사람에게 쓰는 글 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 첫 줄에 상태, 끝에 할 일 하나)을 지킨다.`

분해된 일이면 ①/② 의 둘째 줄은 위 brief 줄 대신 이 줄이다. `<roadmap-path>` 는 로드맵의 절대경로로 치환한다 — 치환하지 못하거나 경로에 공백이 있으면 brief 줄과 같은 규칙(정본 `## 다음 세션 명령` 규칙 5)으로 `@` 를 뗀 문장을 보이고 멈춘다. 나누지 않은 일의 둘째 줄은 위 brief 줄 그대로다.
````

`#### B-3` 의 ① · ② 불릿은 고치지 않는다(둘째 줄이 무엇인지는 이 절이 정한다).

- [ ] **Step 6: SKILL.md · 템플릿에 한 줄씩**

`plugins/spec-distill/skills/spec-interview/SKILL.md` 의 `## 종료 — brief 작성 + optional handoff` 절 첫 문단(「… 이 분리의 목적이 그것이다(조건부 로드).」) 바로 뒤에 빈 줄과 함께:

```markdown
종료가 정해지면 brief 를 쓰기 전에 그 파일의 「분해 판단」 단계부터 돈다 — 이 일을 spec 하나로 할지 나눌지 사용자가 정하고, 나누면 승인된 분해안 표로 로드맵과 에픽 묶음을 만든다.
```

`plugins/spec-distill/templates/interview-brief-template.md` 의 `## 7. Next Action` 아래 괄호 문단 끝(`… 없으면: 이 brief가 완결 산출물 — 직접 사용.)`) 뒤에 빈 줄과 함께:

```markdown
(분해된 일이면 첫 줄은 `분해됨 — <로드맵 경로>` 이다 — 다음 단계는 brainstorming 하나가 아니라 그 로드맵의 지휘 절차다.)
```

- [ ] **Step 7: 테스트를 돌린다**

Run: `cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 && bash plugins/spec-distill/tests/test_decompose_surface.sh | tail -3 && bash ~/.claude/sdd-mirror/r4-impl/run_suite.sh ~/.claude/sdd-mirror/r4-impl/after-t4.txt && diff ~/.claude/sdd-mirror/r4-impl/baseline-before.txt ~/.claude/sdd-mirror/r4-impl/after-t4.txt`
Expected: 문면 락 실패 0. 스위트 diff 가 비었다(새 실패 이름 0). finishing.md 를 코퍼스로 쓰는 기존 락(`test_conducting_interview_stage.sh` · `test_next_session_command.sh` · `test_seed_at_path_handoff.sh` · `test_compression_adopters.sh` · `test_plain_gate_templates.sh` · `test_no_wall_clock.sh` 등)이 새 문면 때문에 RED 면 문면을 그 락의 규칙에 맞게 고친다 — 락을 약하게 만들지 않는다.

- [ ] **Step 8: 커밋**

```bash
git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 add -- plugins/spec-distill/skills/spec-interview/references/finishing.md plugins/spec-distill/skills/spec-interview/SKILL.md plugins/spec-distill/templates/interview-brief-template.md plugins/spec-distill/tests/test_decompose_surface.sh
git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 commit -m "feat(spec-distill): 인터뷰 종료에 분해 판단 · 로드맵 생성 · 재생성 · 분해된 일의 다음 세션 줄" -m "<트레일러 셋>"
```

---

### Task 5: 재분해 참조 · spec-review 게이트 ③ 로드맵 분기 · 재결정 규약 한 줄

**Files:**
- Create: `plugins/spec-distill/references/redecompose.md`
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md`(승인 게이트 2단계 표 바로 아래)
- Modify: `plugins/spec-distill/references/proceed-gate.md`(`## 재결정 규약 (P23)` 의 불릿 끝)
- Modify: `plugins/spec-distill/tests/test_review_handoff_order.sh`(게이트 절 단언)
- Modify: `plugins/spec-distill/tests/test_decompose_surface.sh`(redecompose · proceed-gate 단언)

**Interfaces:**
- Consumes: Task 2 · 3 CLI(`extract` · `update` 인자와 종료 코드).
- Produces: 로드맵 에픽 판정 기준 = 설계문서 frontmatter 의 `roadmap:` 줄.

- [ ] **Step 1: 실패하는 단언을 쓴다** *(plan-authored test code — 리뷰어: 이 테스트 코드도 검사 대상이다)*

`test_decompose_surface.sh` 의 `finish` 앞에:

```bash
# ── AC8 — 재분해 참조 ──────────────────────────────────────────────────────
RED="$SD/references/redecompose.md"
if [ -f "$RED" ]; then ok "redecompose.md 실재"; else no "redecompose.md 없음"; fi
RTXT="$(cat "$RED" 2>/dev/null)"
for lit in '빠짐 · 축소 · 여러 spec' '게이트 ③' '「인터뷰 다시 열기」' '지휘 세션' \
           'roadmap_write.py" extract' '`## 분해안`' \
           '| 에픽 | 바뀌는 것 | 옮겨 가는 번호 | 새 의존 | 진행 중인 브랜치 · 설계문서 |' \
           '"이대로 다시 나눈다"' '"고치기"' '"그만둔다"' \
           'R<max+1>' '사라지는 번호는 재사용하지 않는다' '머지된 에픽은 건드리지 않는다' '## 미룸' \
           'roadmap_write.py" update' '재분해 이력' 'feature/roadmap-<요지>' '원래 바이트'; do
  has "$RTXT" "$lit" "redecompose: $lit"
done

# ── AC11 — 재결정 규약 한 줄 ────────────────────────────────────────────────
PG="$SD/references/proceed-gate.md"
P23="$(win "$PG" '## 재결정 규약 (P23)' '## ')"
has "$P23" '분해 단위의 변경은 `references/redecompose.md` 로' "proceed-gate: 재결정 규약 절에 분해 단위 한 줄"
has "$P23" '보고 후 재결정 허용' "proceed-gate: 확정 항목 단위 규약은 그대로"
```

`test_review_handoff_order.sh` 의 `spec-review 승인 게이트 2단계` 블록 안, `r2` 단언들 뒤(`assert_not_contains "$rows" '바로' …` 줄 뒤)에:

```bash
  r3="$(printf '%s\n' "$rows" | grep -E '^\| ③ \|' || true)"
  assert_contains "$r3" '`spec-interview` 재진입' "spec-review ③ 행: 인터뷰 재진입 갈래는 그대로 있다"
  BR="$(printf '%s\n' "$GATE" | awk '/^\*\*③ 의 세 갈래와 로드맵 에픽\.\*\*/{f=1} f&&/^- \*\*①\/② 의 정지 요건\*\*/{exit} f')"
  if [ -n "$BR" ]; then ok "spec-review: ③ 로드맵 분기 문단 창"; else no "spec-review: ③ 로드맵 분기 문단이 없다"; fi
  for n in '「지적대로 고치기」' '「인터뷰 다시 열기」' '「직접 편집」' 'frontmatter 에 `roadmap:` 줄이 있으면' \
           'references/redecompose.md' '지금 그대로다'; do
    assert_contains "$BR" "$n" "spec-review ③ 로드맵 분기: $n"
  done
```

- [ ] **Step 2: 실패를 확인한다**

Run: `cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 && bash plugins/spec-distill/tests/test_decompose_surface.sh | tail -3; bash plugins/spec-distill/tests/test_review_handoff_order.sh | tail -3`
Expected: redecompose · proceed-gate · ③ 분기 단언 ✗.

- [ ] **Step 3: `references/redecompose.md` 를 쓴다**

````markdown
# 재분해 — 로드맵 에픽의 경계를 다시 나눈다

로드맵으로 나뉜 일에서 하류가 에픽 경계가 틀렸다는 신호를 내면, 인터뷰를 처음부터 다시 열지 않고 같은 로드맵 위에서 사용자 승인 뒤에만 다시 나눈다. 확정 항목 하나를 뒤집는 일은 이 절차가 아니라 재결정 규약(P23)이다 — 이 절차는 에픽 단위의 변경만 다룬다.

## 1. 신호

이 절차로 오는 신호는 셋이다. 신호를 잡는 일은 이 절차의 몫이 아니다.

- 번호 대조 경고 — 빠짐 · 축소 · 여러 spec(`roadmap_status.py` · 번호 대조 검사가 낸다).
- spec-review 게이트 ③ — 로드맵 에픽의 설계문서에서 「인터뷰 다시 열기」 갈래를 골랐을 때.
- 지휘 세션 — 에픽이 머지될 때 남은 에픽을 재평가하다 경계를 바꿔야 한다고 볼 때.

## 2. 지금 표

- 인터뷰 상태 파일이 docs 에 커밋돼 있으면 그 파일의 `## 분해안` 표가 지금 표다.
- 아니면 로드맵 블록과 묶음(frontmatter 번호 · §7)에서 거꾸로 뽑는다:

  ```bash
  SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
  python3 "$SD/scripts/roadmap_write.py" extract --roadmap "<로드맵 경로>"
  ```

  출력(`## 분해안` 머리와 열한 칸 표)이 지금 표다. rc 1 이면 사유를 그대로 보이고 멈춘다.

## 3. 영향 보이기

지금 표를 고쳐 새 표를 만들고, 바뀌는 것을 표로 보인다:

| 에픽 | 바뀌는 것 | 옮겨 가는 번호 | 새 의존 | 진행 중인 브랜치 · 설계문서 |
|---|---|---|---|---|

진행 중인 브랜치 · 설계문서는 `roadmap_status.py <로드맵 경로>` 의 단계 · spec 에서 읽는다. 이어서 `AskUserQuestion` 하나:

```javascript
AskUserQuestion({
  questions: [{
    question: "다시 나눌 표와 영향을 위에 적었다. 어떻게 할까?",
    header: "재분해",
    options: [
      {label: "이대로 다시 나눈다", description: "새 표로 로드맵 블록과 묶음을 다시 쓰고 재분해 이력에 한 줄을 남긴다."},
      {label: "고치기", description: "말로 받아 새 표를 고쳐 다시 보인다."},
      {label: "그만둔다", description: "아무것도 쓰지 않고 끝낸다."}
    ],
    multiSelect: false
  }]
})
```

## 4. 번호 규칙

- 새 에픽은 다음 번호(`R<max+1>` — 블록과 재분해 이력에 나온 같은 글자 번호 중 가장 큰 것 다음)다.
- 사라지는 번호는 재사용하지 않는다.
- 머지된 에픽은 건드리지 않는다 — 블록도 묶음도 그대로다. 생성기가 거부한다.
- 진행 중 에픽의 범위가 바뀌면 그 에픽의 설계문서에 남기라고 사용자에게 알린다 — 그 문서에 `## 미룸` 절이 있으면 거기에, 없으면 `## 결정 기록` 에 `재분해 · <날짜> · <바뀐 범위>` 줄로.

## 5. 적용

승인된 새 표를 세션 상태 폴더의 `redecompose-table.md`(첫 절 `## 분해안`)로 쓰고 생성기를 부른다:

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
ROOT="$(python3 "$SD/scripts/state_path.py" state-root)"
python3 "$SD/scripts/roadmap_write.py" update --roadmap "<로드맵 경로>" --brief "<원본 brief>" \
  --audit "<원본 audit>" --plan-table "$ROOT/<session-id>/redecompose-table.md" \
  --date "<YYYY-MM-DD>" --change "<바뀐 것 한 줄>" --approval "<승인 원문>"
```

- 바뀐 블록과 그 묶음만 다시 쓰고, 재분해 이력에 한 줄(날짜 · 바뀐 것 · 바뀜/새/사라짐 번호 · 승인 원문)을 더한다.
- 쓴 직후 생성 때와 같은 검증(`format_errors` · `unassigned` · `orphans` · `unknown_ids` 넷이 빈 목록)이 돈다. 실패하면 덮어쓴 파일은 원래 바이트로 돌아가고 새로 만든 파일은 지워진 채 rc 1 — 사유를 그대로 보이고 3 으로 돌아간다.
- 머지된 에픽을 바꾸거나 지우는 표, 쓴 적 있는 번호를 다시 쓰는 표, 머지 여부를 알 수 없는 레포는 쓰기 전에 rc 1 이다.

## 6. 올리기

로드맵 수정은 지휘 절차 6 대로 전용 작은 브랜치(`feature/roadmap-<요지>`)와 PR 로 올린다. 머지는 사용자가 한다.
````

주의: 이 파일에 `references/proceed-gate.md` 경로를 적지 않는다(`test_proceed_gate_adopters.sh` 의 채택자 도출에 걸려 proceed 게이트 앵커를 요구받는다).

- [ ] **Step 4: spec-review 게이트 ③ 로드맵 분기**

`plugins/spec-distill/skills/spec-review/SKILL.md` 승인 게이트 2단계 표(`| ④ | 멈춤 — 상태 보존하고 종료 |` 줄) 바로 아래, `**다음 세션 줄 — ①/② 공통**` 앞에 빈 줄을 두고:

````markdown
**③ 의 세 갈래와 로드맵 에픽.** ③ 을 고르면 후속 질문 하나로 갈래를 묻는다 — 「지적대로 고치기」(revise per findings) · 「인터뷰 다시 열기」(`spec-interview` 재진입) · 「직접 편집」(사용자 직접 편집). 설계문서 frontmatter 에 `roadmap:` 줄이 있으면 그 문서는 로드맵 에픽이다 — 그때 「인터뷰 다시 열기」 갈래는 인터뷰를 다시 열지 않고 같은 로드맵 위의 재분해 절차로 간다:

```
Read ${CLAUDE_PLUGIN_ROOT}/references/redecompose.md
```

「지적대로 고치기」 · 「직접 편집」 갈래와, `roadmap:` 줄이 없는 문서의 세 갈래는 지금 그대로다.
````

`test_review_handoff_order.sh` 의 창(`**③ 의 세 갈래와 로드맵 에픽.**` 부터 `- **①/② 의 정지 요건**` 앞까지)이 이 문단을 잡는다.

- [ ] **Step 5: proceed-gate.md 한 줄**

`## 재결정 규약 (P23)` 절의 불릿 목록 마지막(`- **기록** — … 조용히 덮어쓰지 않는다.` 의 끝) 다음 줄에:

```markdown
- **분해 단위의 변경은 `references/redecompose.md` 로** — 로드맵 에픽의 경계를 다시 나누는 일은 이 규약이 아니라 그 절차다. 확정 항목 단위의 이 규약은 그대로다.
```

- [ ] **Step 6: 테스트를 돌린다**

Run: `cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 && bash plugins/spec-distill/tests/test_decompose_surface.sh | tail -2 && bash plugins/spec-distill/tests/test_review_handoff_order.sh | tail -2 && bash ~/.claude/sdd-mirror/r4-impl/run_suite.sh ~/.claude/sdd-mirror/r4-impl/after-t5.txt && diff ~/.claude/sdd-mirror/r4-impl/baseline-before.txt ~/.claude/sdd-mirror/r4-impl/after-t5.txt`
Expected: 실패 0, 스위트 diff 빈 출력. `test_skill_reference_pointers.sh` · `test_proceed_gate_adopters.sh` · `test_no_wall_clock.sh` · `test_plain_gate_templates.sh` 가 새 파일을 코퍼스로 잡아 RED 면 문면을 그 규칙에 맞춘다.

- [ ] **Step 7: 커밋**

```bash
git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 add -- plugins/spec-distill/references/redecompose.md plugins/spec-distill/skills/spec-review/SKILL.md plugins/spec-distill/references/proceed-gate.md plugins/spec-distill/tests/test_review_handoff_order.sh plugins/spec-distill/tests/test_decompose_surface.sh
git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 commit -m "feat(spec-distill): 재분해 절차와 spec-review 게이트 ③ 의 로드맵 분기" -m "<트레일러 셋>"
```

---

### Task 6: 문서 · 버전 · 변이 확인

**Files:**
- Modify: `plugins/spec-distill/README.md`(`## 로드맵 · 에픽 묶음` · `## 흐름`)
- Modify: `plugins/spec-distill/CHANGELOG.md`(`## [5.6.0] — 2026-10-15`)
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`(`"version": "5.6.0"`)
- Modify: `docs/superpowers/specs/2026-10-15-interview-pm-decompose-design.md`(`## 결정 기록` — 변이 결과 한 줄)

- [ ] **Step 1: README**

`## 로드맵 · 에픽 묶음` 절 첫 문단의 「큰 일을 에픽으로 나눠 진행할 때 쓰는 읽기 전용 스크립트 둘이 있습니다. 둘 다 파일을 쓰지 않고 네트워크에 나가지 않습니다.」를 「큰 일을 에픽으로 나눠 진행할 때 쓰는 스크립트 셋이 있습니다. 앞의 둘은 읽기 전용이고, 셋째가 로드맵과 묶음을 씁니다. 셋 다 네트워크에 나가지 않습니다.」로 바꾸고, `check_bundle_coverage.py` 불릿 뒤에:

```markdown
- `scripts/roadmap_write.py create · update · extract` — 인터뷰가 승인받은 분해안 표(`## 분해안`, 칸 열하나)로 로드맵과 에픽 묶음을 쓰고(create), 재분해 때 바뀐 블록과 그 묶음만 다시 쓰고(update), 로드맵에서 표를 거꾸로 뽑습니다(extract). 쓴 직후 `roadmap_status.py --json` 의 `format_errors` · `unassigned` · `orphans` · `unknown_ids` 가 모두 빈 목록이 아니면 쓴 것을 원래 바이트로 되돌리고 1 로 끝납니다. 머지된 에픽은 바꾸지 않고 사라진 번호는 다시 쓰지 않습니다. 재분해 절차는 `references/redecompose.md` 에 있습니다.
```

같은 절 끝의 「종료 코드는 둘 다 0 이상 없음 · 1 경고 · 2 사용법 오류 · 3 검사 불가입니다.」 뒤에 「`roadmap_write.py` 는 0 성공 · 1 쓰지 않음 · 2 사용법 오류입니다.」를 붙인다. `## 흐름` 절에서 인터뷰 종료를 말하는 자리에 한 문장: 「인터뷰가 끝나면 brief 를 쓰기 전에 일을 spec 하나로 할지 나눌지 사용자가 정합니다(분해 판단). 나누면 로드맵과 에픽 묶음이 함께 만들어지고, 다음 세션은 그 로드맵의 지휘 절차로 시작합니다.」 (`## 흐름` 의 구조를 먼저 읽고 맞는 자리에 넣는다.)

- [ ] **Step 2: CHANGELOG · plugin.json**

`plugins/spec-distill/CHANGELOG.md` 의 `# Changelog` 다음, `## [5.5.0]` 앞에:

```markdown
## [5.6.0] — 2026-10-15

### Added
- 인터뷰 종료의 「분해 판단」 단계 — brief 를 쓰기 전에 신호 셋(따로 승인할 수 있는 덩어리 · 파일 영역 · 사용자 원문 갈래, 근거 번호 포함)과 권고 한 줄을 보이고 사용자가 「spec 하나로 / 나눈다」를 고른다. 숫자 컷오프는 없다. 나누면 에픽 표(칸 열하나)를 제안받아 고치거나 승인하고, 승인된 표는 state `## 분해안` 에 남는다.
- `scripts/roadmap_write.py`(create · update · extract)와 `scripts/roadmap_render.py` · `templates/roadmap-template.md` — 승인된 표로 R0 형식의 로드맵 · 에픽 묶음을 쓰고 `roadmap_status.py --json` 의 네 목록(`format_errors` · `unassigned` · `orphans` · `unknown_ids`)이 모두 비었는지 바로 검증한다. 실패하면 만든 파일을 지우고 덮어쓴 파일을 원래 바이트로 되돌린다. create 는 `## 생성 기록` 에 적은 파일만 다시 덮어쓴다.
- `references/redecompose.md` — 하류의 재분해 신호(번호 대조 경고 · spec-review 게이트 ③ · 지휘 세션)를 같은 로드맵으로 받아 영향 표 · 승인 뒤에만 다시 나눈다. 새 번호만 쓰고 사라진 번호는 재사용하지 않으며 머지된 에픽은 건드리지 않는다.

### Changed
- 분해된 일의 다음 세션 줄은 brief 하나 대신 `@<로드맵>` 지휘 줄이다. Step B 의 마지막 brief 쓰기 직후 언제나 로드맵 · 묶음을 한 번 더 생성하고, 함께 커밋하라는 안내 한 줄을 보인다. 나누지 않은 일은 그대로다.
- `spec-review` 게이트 ③ — 설계문서 frontmatter 에 `roadmap:` 줄이 있으면 「인터뷰 다시 열기」 갈래가 재분해 절차로 간다. 다른 갈래와 로드맵 밖 문서는 그대로다.
- `references/proceed-gate.md` 재결정 규약에 「분해 단위의 변경은 `references/redecompose.md` 로」 한 줄. brief 템플릿 §7 에 분해 줄.
```

`plugins/spec-distill/.claude-plugin/plugin.json` 의 `"version": "5.5.0"` → `"version": "5.6.0"`.

- [ ] **Step 3: 변이로 이빨을 확인한다 (AC12)**

변이 전에 커밋돼 있어야 한다(복원은 `git -C <worktree> checkout HEAD -- <파일>` 뒤 `git -C <worktree> diff HEAD --stat` 이 빈지 확인). 각 변이는 `~/.claude/sdd-mirror/r4-impl/mutation.sh` 같은 스크립트로 한 번에 하나씩, `PYTHONDONTWRITEBYTECODE=1` 로. 기록은 `~/.claude/sdd-mirror/r4-impl/mutation.md` 에 「변이 · 기대 · 실측 RED 단언 이름」으로.

| # | 변이 | 기대 RED |
|---|---|---|
| M1 | `roadmap_write.py` `LISTS` 에서 `"unknown_ids"` 를 뺀다 | 셸 「unknown_ids: rc 1」 · python `Judge.test_each_list` |
| M2 | `judge` 의 `if not isinstance(value, list)` 분기를 `if value is None and False` 로 바꾼다(셀 수 없음을 통과로) | python `Judge.test_uncountable` |
| M3 | `Txn.rollback` 의 `saved` 복원 루프를 지운다 | python `Transaction.test_rollback_restores_bytes` · 셸 「update 검증 실패: 로드맵 · 묶음이 원래 바이트」 |
| M4 | `Txn.rollback` 의 `created` 삭제 루프를 지운다 | 셸 「unknown_ids: 만든 파일이 남지 않는다」 |
| M5 | `cmd_update` 의 `frozen` 거부를 지운다 | 셸 「머지된 에픽 변경: rc 1」 |
| M6 | finishing.md 분해 판단 절 1 항에 `덩어리 3개 이상이면 나눈다.` 한 줄을 더한다 | 문면 락 「숫자 컷오프 문면이 없다」 · 「이상이면 나눈다」 |
| M7 | finishing.md 분해 판단 절에서 「컷오프는 두지 않는다」를 지운다 | 문면 락 존재 짝 |

양성 대조: 변이 없이 같은 스크립트를 돌려 해당 단언이 모두 ✓ 인 것을 먼저 기록한다(계측기 고장 판별). 모든 변이 뒤 `git diff HEAD --stat` 빈 출력을 확인한다.

설계문서 `## 결정 기록` 에 한 줄: `- 판정 · 2026-10-15 · AC12 변이 M1~M7 — 모두 RED(양성 대조 GREEN). 기록 ~/.claude/sdd-mirror/r4-impl/mutation.md` (실측이 다르면 사실대로 — RED 가 안 난 변이는 테스트를 보강하고 다시 잰다).

- [ ] **Step 4: 전체 스위트**

Run: `bash ~/.claude/sdd-mirror/r4-impl/run_suite.sh ~/.claude/sdd-mirror/r4-impl/after-t6.txt && diff ~/.claude/sdd-mirror/r4-impl/baseline-before.txt ~/.claude/sdd-mirror/r4-impl/after-t6.txt`
Expected: diff 빈 출력. 새 셸 테스트 둘의 모드가 100755(`git -C <worktree> ls-files -s plugins/spec-distill/tests/test_roadmap_write.sh plugins/spec-distill/tests/test_decompose_surface.sh`).

- [ ] **Step 5: 커밋**

```bash
git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 add -- plugins/spec-distill/README.md plugins/spec-distill/CHANGELOG.md plugins/spec-distill/.claude-plugin/plugin.json docs/superpowers/specs/2026-10-15-interview-pm-decompose-design.md
git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a82ab43f9c82fa3b0 commit -m "docs(spec-distill): 분해 판단 · 로드맵 생성기 · 재분해 문서와 5.6.0" -m "<트레일러 셋>"
```

---

## 범위 밖(후속)

- 로드맵 R4 블록 `경로 예약:` 갱신(이 에픽이 만든 파일 — `roadmap_write.py` · `roadmap_render.py` · `templates/roadmap-template.md` · `references/redecompose.md` · 테스트 넷) — 지휘 절차 6 의 로드맵 수정 PR(`feature/roadmap-<요지>`)로.
- R7 머지 뒤: R7 의 세 파일 커밋 규칙 경로 지정에 로드맵 폴더를 더하고 finishing.md 의 임시 커밋 안내를 지운다. 재분해 지금 표의 출처는 docs 의 상태 파일 `## 분해안` 으로.
- R2 머지 뒤: 분해안 고치기 상한(지금 임시 세 번마다 묻기)을 R2 의 결정으로.
- R3 머지 뒤: 에픽 넘김 줄은 R3 `references/epic-handoff.md` 로, 미룸은 R3 의 `## 미룸` 으로.
