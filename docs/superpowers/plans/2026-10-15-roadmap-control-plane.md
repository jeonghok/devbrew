# R6 컨트롤 플레인 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 에픽 지도 · 단계 · 경고 · 진행 중 인터뷰 조사 수 · 마지막 fetch 경과를 Claude Code 안에서 늘 보이게 한다 — 상태줄 한 줄, 자세히는 진입 skill `roadmap-status`, 지휘 세션 작업 목록은 기계 줄.

**Architecture:** 새 스크립트 `plugins/spec-distill/scripts/control_plane.py` 하나가 세 출력(`statusline` · `show` · `show --tasks`)을 낸다. 단계 · 경고는 `roadmap_status.py <경로> --json` 을 하위 프로세스로 불러 읽기만 하고, 결과를 `<git 공용 디렉토리>/devbrew/control-plane.json` 에 캐시한다(키 = origin/main 커밋 · 브랜치 머리 목록 · 대상 로드맵 사본 · 진행 중 인터뷰 상태 파일). 「받은 지 N분」은 캐시 밖에서 매번 `FETCH_HEAD` 수정 시각으로 읽는다. 진입 skill 은 `show` 출력을 그대로 보이고, 상태줄은 README 가 주는 버전 없는 실행 스크립트가 설치본을 찾아 부른다.

**Tech Stack:** Python 3.9 (스크립트 · unittest), bash 락 테스트(`shared/tests/assert.sh`), Markdown skill.

**Spec:** `docs/superpowers/specs/2026-10-15-roadmap-control-plane-design.md` (리포 상대경로). 실행자는 계획과 설계문서를 함께 읽는다.

## Global Constraints

- 모든 경로는 worktree 절대경로 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-afc2943be6d4e4fe6` 아래다. main 레포(`/Users/jeonghokim/Downloads/devbrew/plugins/...`)의 같은 이름 파일을 고치지 않는다. 브랜치는 `r6-impl`(origin `feature/roadmap-control-plane` 을 추적).
- 커밋 설명은 한국어, `type(scope)` 는 영어 — 예 `feat(spec-distill): …`. 메시지 끝 트레일러 셋: `Spec: docs/superpowers/specs/2026-10-15-roadmap-control-plane-design.md` · `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` · `Claude-Session: https://claude.ai/code/session_01XKSh1VvN6kYTmLJS675MgX`.
- 커밋은 pathspec 으로 한다(`git add <파일들>` 뒤 커밋) — `git add -A` · `git add .` 금지. 커밋 뒤 `git show --stat HEAD` 의 파일 수가 그 Task 의 파일 수와 같은지 본다.
- 이 worktree 세션의 Bash 가드는 git 이 섞인 복합 명령(`cd … && git …`, 변수로 만든 경로를 쓰는 git)을 거부한다. git 은 `git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-afc2943be6d4e4fe6 <하위 명령>` 한 줄씩, 여러 단계는 `~/.claude/sdd-mirror/r6-impl/` 아래 스크립트 파일로 써서 `bash <파일>` 로 돈다. Bash 도구 셸은 zsh 라 `PIPESTATUS` 가 없다.
- 셸 테스트는 리포 루트에서 `bash plugins/spec-distill/tests/<이름>.sh` 로 돈다. 실패 줄은 `  ✗ ` 로 시작한다. 새 셸 테스트는 `chmod +x` 하고 커밋 뒤 `git ls-files -s <파일>` 이 `100755` 인지 본다.
- Python 은 레포의 `python3`(3.9.6) 로 돈다 — 3.9 문법만(`match` · 런타임 `X | Y` 타입 · `list[str]` 런타임 사용 금지). 새 `.py` 에 `"python3"` 문자열 리터럴을 두지 않는다(하위 프로세스는 `sys.executable`). 파일을 여는 모든 `open(` · `.read_text(` · `os.fdopen(` 에 `encoding="utf-8"` 를 단다(`plugins/quality-gates/tests/test_utf8_explicit.py`).
- 셸 안 인라인 python 은 `python3 -I`, 스크립트 호출에는 `-I` 를 쓰지 않는다. 테스트 · 변이 실행에는 `PYTHONDONTWRITEBYTECODE=1`.
- `scripts/*.py` 의 `re.compile` 리터럴이 `## 6. 사용자 원문` 머리를 3글자 이상 맞히면 RED 다(`test_check_brief.sh` §6 단일화) — 아래 정규식은 모두 `\s` · `[` 로 시작하거나 `docs/` 리터럴이라 맞지 않는다. 새 정규식을 더하지 않는다.
- 금지 토큰(레포 전역, `test_review_hook_removed.py`) — 새 코드 · 문서 어디에도: `parse_frontmatter` · `parse_iso` · `GIT_TIMEOUT_SEC` · `configure_utf8_streams` · `review-dispatch` · `spec-template` · `write_state_file` · `rewrite_state`. 월클락 락 토큰 `wall-clock` 을 README 에 쓰지 않는다.
- 20줄(200자 이상) 같은 블록을 두 파일에 두지 않는다(`shared/tests/test_no_new_duplication.sh`) — 특히 `test_roadmap_status.sh` 의 픽스처 함수를 복사하지 않는다.
- 진입 skill 본문에는 느낌표-백틱 조합이 사전 검사 줄 하나뿐이다. frontmatter 키는 공식 키 ∪ `cost_class` 만(`shared/entry/check_invocation_surface.py` 축 C · E).
- 출력 문구는 아래 코드의 리터럴 그대로다 — 다른 Task 의 테스트가 그 글자를 문다.
- `plugin.json` 은 Task 4 에서 5.5.0 → 5.6.0. 다른 에픽이 먼저 머지되면 머지 직전에 번호를 다시 정한다(PR 본문에 적는다).
- **계획이 쓴 테스트 코드도 심사 대상이다.** 각 Task 의 테스트 블록은 이 계획이 쓴 것이다(plan-authored) — 리뷰어는 구현뿐 아니라 그 테스트가 실제로 무는지(빈 통과 · 대체 가능한 합계 · 헤더만 맞는 grep)를 본다.

## Review Focus

1. **상태 계산이 죽거나 JSON 이 아닌 출력을 냄(사용법 오류 rc 2 포함)** — 0 · 1 로 보이지 않고 「검사 불가」로 보여야 한다. → Task 2 의 `garbage` 대역 케이스.
2. **로드맵 제목 · 사유 · 경고에 제어 문자(ESC · 줄바꿈 · 탭)** — 상태줄 한 줄과 작업 목록의 탭 두 칸이 깨지지 않아야 한다. → Task 1 의 `test_control_chars_*`.
3. **git 레포 밖 · origin 없는 레포에서 상태줄이 열림** — 오류 줄이 아니라 빈 줄이어야 한다(로드맵 없음). → Task 2 의 「레포 밖」 케이스.
4. **상태줄이 동시에 여러 번 불림** — 캐시 파일이 깨지거나 임시 파일이 남지 않아야 한다. → Task 2 의 병렬 케이스.
5. **반쯤 쓰인 · 깨진 인터뷰 상태 파일** — 「인터뷰 셀 수 없음」으로 보이고 로드맵 부분은 정상이어야 한다. → Task 1 의 `parse_interview_state` 케이스 + Task 2 의 끝에서 끝 케이스.

## 설계의 미룬 것 · 더 정한 것 (사용자에게 보고)

설계 본문의 결정을 바꾸는 것은 없다. `### Deferred to plan` 다섯 줄과 계획이 정한 세부를 이렇게 닫는다.

| 항목 | 이 계획의 처리 |
|---|---|
| 상태줄 설치 덩어리 | README 가 버전 없는 실행 스크립트(`~/.claude/devbrew-statusline.sh` 로 저장)를 준다. 스크립트는 실행 때마다 `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json` 에서 `/spec-distill/` 이 든 `installPath` 를 읽어 `scripts/control_plane.py statusline` 을 부르고, 못 찾으면 「상태줄 꺼짐 — 플러그인을 못 찾음」. 실측(2026-10-15, Claude Code 2.1.299): 그 파일은 `{"version": 2, "plugins": {"spec-distill@devbrew": [{"installPath": ".../cache/devbrew/spec-distill/5.3.0", ...}]}}` 이고 캐시 폴더에는 옛 버전(4.5.0 ~ 5.3.0)이 함께 남는다 — 그래서 폴더 이름의 최신 버전이 아니라 `installPath` 를 읽는다. Task 4 가 이 사실을 다시 재고 README 문면에 날짜 · 버전과 함께 적는다 |
| 시간 측정 숫자(AC10) | Task 4 가 이 worktree(실데이터)에서 캐시 없음 · 캐시 맞음을 각 세 번 재 중앙값을 아래 `## 측정` 절에 적는다 |
| 「설계 · 구현 · 준비」 매핑 | 설계 = 설계 중 · 구현 = 계획 · 구현 중 · 구현 끝 · PR(뒤 셋은 R5 가 더할 이름) · 준비 = 준비. 세지 않음 = 대기 · 머지됨 · 끝남 · 알 수 없음. 그 밖의 이름은 `기타 <n>` 으로 따로 보인다(조용히 빠지지 않게) |
| 로드맵이 여럿 | 경로 정렬 첫 로드맵 폴더 이름 + `외 <n>`. 단계 수 · 경고 수 · 검사 불가는 고른 로드맵 전부의 합이다(둘째 로드맵의 드리프트가 숨지 않게) |
| brief 가 생긴 뒤 포화 판정(716bc436#r1.2) | 짝 brief 가 생긴 인터뷰는 보이지 않는다 — 그 판정은 audit §2 와 brief 게이트(`check_brief.py gate`)가 갖는다. 컨트롤 플레인은 진행 중 인터뷰만 보인다 |
| R7 이름 · 「셀 수 없음」과 「없음」(716bc436#r1.4) | R7 설계의 이름을 따른다 — `docs/superpowers/interview/*-interview.state.md`, 짝 brief 는 `.state` 를 뗀 `*-interview.md`(seed 로 시작한 `<날짜>-<주제>-brief-interview.state.md` 도 같은 규칙). 지원 여부 = 같은 플러그인의 `scripts/state_path.py` 에 `interview-state` 글자가 있는가(R7 AC1 의 하위 명령). 미지원 → 상태줄 조각 없음 · `show` 「인터뷰: 셀 수 없음 — 이 플러그인 버전은 인터뷰 상태 파일을 아직 남기지 않는다」. 지원 · 진행 중 없음 → 상태줄 조각 없음 · `show` 「인터뷰: 진행 중 없음」. 읽지 못한 상태 파일 → 상태줄 `인터뷰 셀 수 없음`. R5 `rulings`: 어느 블록에도 칸이 없으면 절 생략, 칸은 있고 비었으면 「없음」 |
| 경고 수 | 블록 경고 줄 수 + 맨 위 갈래(받드는 에픽 없는 발화 · 미배정 번호 · brief 에 없는 번호) 중 비지 않은 것 하나씩. `show` 첫 줄의 경고 수는 상태 계산 그대로(블록 경고만)라 상태줄 수와 다를 수 있다 — 맨 위 갈래는 `show` 에 따로 줄로 나온다 |
| `show --tasks` 의 끔 · 로드맵 없음 | 표준 출력을 비우고 표준 오류에 사유, rc 3 — 「0 이 아니면 작업 목록을 바꾸지 않는다」. 설계 AC6 의 rc 0 은 지도 `show` 에 적용한다 |
| origin/main 없는 레포 | 로드맵 없음과 같다(상태줄 빈 줄). 인자로 준 경로는 상태 계산의 3 으로 「검사 불가」 |
| 캐시 키의 «브랜치 머리 목록» | `refs/remotes/origin/main` 줄과 가리키는 참조(`origin/HEAD` 같은 symref) 줄은 뺀다 — 첫 요소(origin/main 커밋)와 겹쳐 그 요소의 이빨을 가리지 않게(계획 모의 실행에서 `origin/HEAD` 가 origin/main 을 따라 움직여 변이가 살아남은 것을 실측). 대상 로드맵 사본 요소는 origin/main 커밋에 딸려 따로 변이로 가를 수 없다(정직하게 그렇다고 둔다) |
| 상태줄의 작업 디렉토리 | 표준 입력 JSON 의 `workspace.current_dir` → `cwd` → 프로세스 cwd 순. 키가 없거나 JSON 이 아니면 프로세스 cwd 다 |
| `show` 의 기다림 | 의존 중 단계가 머지됨 · 끝남이 아닌 것만(설계 §1-4) |

## 측정

(Task 4 가 채운다.)

## 후속 (이 PR 밖)

- 로드맵 `## 지휘 절차` 1번 한 줄 — 로드맵 수정 PR(`feature/roadmap-<요지>`, 지휘 절차 6). 바꿀 문면 제안: `` `git fetch origin` → `python3 plugins/spec-distill/scripts/control_plane.py show --tasks docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md` → 작업 목록을 그 줄에 맞춘다(첫 칸 = 제목, 둘째 칸 = 상태, `keep` 은 바꾸지 않음). 종료 코드가 0 이 아니면 작업 목록을 바꾸지 않고 표준 오류의 사유를 사용자에게 그대로 보인다. `` (`roadmaps/` 는 금지 토큰 면제 밖 — 옛 훅 이름을 쓰지 않는다.)

---

## 파일 지도

| 파일 | 책임 | Task |
|---|---|---|
| `plugins/spec-distill/scripts/control_plane.py` (새) | 표시 순수 함수(Task 1) · git 읽기 · 캐시 · 명령줄(Task 2) | 1 · 2 |
| `plugins/spec-distill/tests/test_control_plane.py` (새) | 순수 함수 단위 테스트 | 1 |
| `plugins/spec-distill/tests/test_control_plane.sh` (새, 100755) | 버릴 git 저장소로 캐시 · 스위치 · 읽기 전용 · 받은 시각 · 변이(Task 2), README 스크립트(Task 4) | 2 · 4 |
| `plugins/spec-distill/skills/roadmap-status/SKILL.md` (새) | 진입 skill | 3 |
| `shared/entry/check_invocation_surface.py` · `shared/tests/test_invocation_surface.sh` | 진입 skill 목록에 `roadmap-status` | 3 |
| `plugins/spec-distill/README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json` | 상태줄 설치 · 스위치 · 진입 skill · 버전 | 4 |
| 이 계획 `## 측정` | AC10 숫자 | 4 |

---

### Task 1: 표시 순수 함수

**Files:**
- Create: `plugins/spec-distill/scripts/control_plane.py`
- Test: `plugins/spec-distill/tests/test_control_plane.py`

**Interfaces:**
- Consumes: `roadmap_status.render(report) -> str`(첫 줄만 쓴다), 상태 계산 JSON 보고서 dict(키: `roadmap` `source` `fetched_at` `notice` `blocks[]`(`id` `title` `kind` `stage` `reason` `task_status` `deps` `warnings` `notes`, R5 뒤 `rulings`) `unassigned` `orphans` `unknown_ids` `overlaps` `format_errors` `unknown_reasons` `exit`).
- Produces (Task 2 가 쓴다):
  - `clean(value) -> str` · `folder_name(path) -> str` · `count_warnings(report) -> int`
  - `parse_interview_state(text) -> {"n": int, "limit": int, "last": str | None}` — 셀 수 없으면 `ValueError(사유)`
  - interview 요약 dict `{"supported": bool, "items": [{"path", "n", "limit", "last", "mtime"}], "errors": [{"path", "reason"}]}`
  - `statusline_text(items, interview, minutes, select_error=None) -> str` — `items` 는 `[(경로, report)]`
  - `show_text(items, interview, notes, first_line, select_error=None) -> str`
  - `tasks_output(items, select_error=None) -> (list_of_lines, stderr_text, rc)`
  - `first_line(report) -> str` · `failed_report(path, reason) -> dict`

- [ ] **Step 1: 실패하는 테스트를 쓴다** (계획이 쓴 테스트 코드 — 리뷰어 심사 대상)

`plugins/spec-distill/tests/test_control_plane.py`:

```python
#!/usr/bin/env python3
"""control_plane.py 의 표시 순수 함수 — 상태줄 · 지도 · 작업 목록 줄의 모양(R6 AC1 · AC2 · AC3).

Run (리포 루트에서):
    python3 -m unittest plugins/spec-distill/tests/test_control_plane.py
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import control_plane as cp  # noqa: E402
import roadmap_status  # noqa: E402

RM = "docs/superpowers/roadmaps/rm/roadmap.md"


def blk(bid, stage, task, deps=(), warnings=(), title=None, reason="이유", **extra):
    b = {"id": bid, "title": title or "에픽 " + bid, "kind": "bundle", "stage": stage, "reason": reason,
         "task_status": task, "deps": list(deps), "warnings": list(warnings), "notes": []}
    b.update(extra)
    return b


def report(blocks, exit_code=0, **kw):
    r = {"roadmap": RM, "source": "origin/main", "fetched_at": "2026-10-15 10:00", "notice": "알림",
         "blocks": blocks, "unassigned": [], "orphans": [], "unknown_ids": [], "overlaps": [],
         "format_errors": [], "unknown_reasons": [], "exit": exit_code}
    r.update(kw)
    return r


BASE = [blk("R1", "설계 중", "in_progress", warnings=["경고 하나"]), blk("R2", "계획", "in_progress"),
        blk("R3", "준비", "pending"), blk("R4", "대기", "pending"), blk("R0", "머지됨", "completed")]
NO_IV = {"supported": True, "items": [], "errors": []}
IV = {"supported": True, "errors": [],
      "items": [{"path": "docs/superpowers/interview/2026-10-15-t-interview.state.md", "n": 3, "limit": 20,
                 "last": "포화 판정 1: 아직 — 빈 곳 2개", "mtime": 2.0},
                {"path": "docs/superpowers/interview/2026-10-14-u-interview.state.md", "n": 9, "limit": 20,
                 "last": None, "mtime": 1.0}]}

STATE = """---
type: interview-state
seed: none
orchestration:
  focused_dimension: null
  research_dispatches: {coverage_mapper: 1, blind_spot_prober: 1, steelman_builder: 0, repo_researcher: 1}  # 조사
  research_limit: 20
  saturation_limit: 5
---

## R1

본문.

## audit §2 대기 줄

- 상한 도달 20/20 — 사용자 선택 S4: 연장
- 포화 판정 1: 아직 — 빈 곳 2개
"""


class Statusline(unittest.TestCase):
    def test_base_shape(self):
        self.assertEqual(cp.statusline_text([(RM, report(BASE, 1))], NO_IV, 5),
                         "rm · 설계 1 · 구현 1 · 준비 1 · 경고 1 · 받은 지 5분")

    def test_no_warnings(self):
        line = cp.statusline_text([(RM, report([blk("R3", "준비", "pending")]))], NO_IV, 0)
        self.assertEqual(line, "rm · 설계 0 · 구현 0 · 준비 1 · 경고 없음 · 받은 지 0분")

    def test_top_level_warnings_count(self):
        r = report(BASE, 1, orphans=["S3", "S9"], unassigned=["C4"], unknown_ids=["X1"])
        self.assertIn("· 경고 4 ·", cp.statusline_text([(RM, r)], NO_IV, 5))

    def test_unknown_exit(self):
        line = cp.statusline_text([(RM, report(BASE, 3))], NO_IV, 5)
        self.assertTrue(line.endswith(" · 받은 지 5분 · 검사 불가"), line)

    def test_interview_segment_latest_first(self):
        line = cp.statusline_text([(RM, report(BASE, 1))], IV, 5)
        self.assertTrue(line.endswith(" · 받은 지 5분 · 인터뷰 조사 3/20 외 1"), line)

    def test_no_roadmap_with_interview(self):
        self.assertEqual(cp.statusline_text([], IV, None), "인터뷰 조사 3/20 외 1")

    def test_no_roadmap_no_interview_is_empty(self):
        self.assertEqual(cp.statusline_text([], NO_IV, 3), "")

    def test_unsupported_interview_has_no_segment(self):
        line = cp.statusline_text([(RM, report(BASE, 1))], {"supported": False, "items": [], "errors": []}, 5)
        self.assertNotIn("인터뷰", line)

    def test_interview_error(self):
        iv = {"supported": True, "items": [], "errors": [{"path": "x", "reason": "깨짐"}]}
        self.assertTrue(cp.statusline_text([(RM, report(BASE, 1))], iv, 5).endswith(" · 인터뷰 셀 수 없음"))

    def test_minutes_unknown(self):
        self.assertIn("· 받은 시각 모름", cp.statusline_text([(RM, report(BASE, 1))], NO_IV, None))

    def test_many_roadmaps_are_summed(self):
        other = ("docs/superpowers/roadmaps/rn/roadmap.md", report(BASE, 3))
        line = cp.statusline_text([(RM, report(BASE, 1)), other], NO_IV, 5)
        self.assertEqual(line, "rm 외 1 · 설계 2 · 구현 2 · 준비 2 · 경고 2 · 받은 지 5분 · 검사 불가")

    def test_future_stage_names(self):
        r = report([blk("R5", "구현 중", None), blk("R8", "검토", None)])
        self.assertEqual(cp.statusline_text([(RM, r)], NO_IV, 1),
                         "rm · 설계 0 · 구현 1 · 준비 0 · 기타 1 · 경고 없음 · 받은 지 1분")

    def test_select_error(self):
        self.assertEqual(cp.statusline_text([], NO_IV, 2, "목록을 못 읽었다"), "검사 불가")

    def test_control_chars_statusline(self):
        r = report([blk("R1", "설계 중", "in_progress")])
        line = cp.statusline_text([("docs/superpowers/roadmaps/a\x1b[31mb\nc/roadmap.md", r)], NO_IV, 1)
        self.assertNotIn("\x1b", line)
        self.assertNotIn("\n", line)


class Show(unittest.TestCase):
    def show(self, items, iv=NO_IV, notes=(), sel=None):
        return cp.show_text(items, iv, list(notes), cp.first_line, sel).split("\n")

    def test_first_line_is_status_first_line(self):
        r = report(BASE, 1)
        lines = self.show([(RM, r)])
        self.assertEqual(lines[0], roadmap_status.render(r).split("\n")[0])
        self.assertEqual(lines[1], "로드맵: " + RM)

    def test_waiting_marker_only_unfinished_deps(self):
        r = report([blk("R0", "머지됨", "completed"), blk("R2", "설계 중", "in_progress"),
                    blk("R7", "대기", "pending"), blk("R6", "설계 중", "in_progress", deps=["R0", "R2", "R7"]),
                    blk("R9", "준비", "pending", deps=["R0"])])
        lines = self.show([(RM, r)])
        self.assertIn("R6 에픽 R6 — 설계 중 · 이유 ← 기다림: R2 · R7", lines)
        self.assertIn("R9 에픽 R9 — 준비 · 이유", lines)

    def test_block_warnings_indented(self):
        self.assertIn("    경고: 경고 하나", self.show([(RM, report(BASE, 1))]))

    def test_top_level_warning_lines(self):
        r = report(BASE, 1, orphans=["S3", "S9"], unassigned=["C4"], unknown_ids=["X1"])
        lines = self.show([(RM, r)])
        self.assertIn("받드는 에픽 없는 발화: 2개 — S3 · S9", lines)
        self.assertIn("미배정 번호: 1개 — C4", lines)
        self.assertIn("brief 에 없는 번호: 1개 — X1", lines)

    def test_top_level_uncountable(self):
        lines = self.show([(RM, report(BASE, 3, orphans=None, unassigned=None))])
        self.assertIn("받드는 에픽 없는 발화: 셀 수 없음", lines)
        self.assertIn("미배정 번호: 셀 수 없음", lines)

    def test_empty_top_level_lines_absent(self):
        text = "\n".join(self.show([(RM, report(BASE, 0))]))
        self.assertNotIn("받드는 에픽 없는 발화", text)

    def test_unknown_reasons_lines(self):
        r = report(BASE, 3, format_errors=["형식 하나"], unknown_reasons=["로드맵을 못 읽었다: x (origin/main)"])
        lines = self.show([(RM, r)])
        self.assertIn("검사 불가: 형식 깨짐 — 형식 하나", lines)
        self.assertIn("검사 불가: 로드맵을 못 읽었다: x (origin/main)", lines)

    def test_rulings_absent_section_absent(self):
        self.assertNotIn("판정 줄:", self.show([(RM, report(BASE, 1))]))

    def test_rulings_present(self):
        r = report([blk("R5", "구현 중", None, rulings=["실행 판정 하나"]), blk("R6", "계획", "in_progress", rulings=[])])
        lines = self.show([(RM, r)])
        i = lines.index("판정 줄:")
        self.assertEqual(lines[i + 1], "    R5: 실행 판정 하나")

    def test_rulings_present_but_empty(self):
        lines = self.show([(RM, report([blk("R5", "계획", "in_progress", rulings=[])]))])
        i = lines.index("판정 줄:")
        self.assertEqual(lines[i + 1], "    없음")

    def test_no_roadmap(self):
        self.assertEqual(self.show([])[0], "로드맵 없음 — origin/main 에 끝나지 않은 블록이 있는 로드맵이 없다")

    def test_select_error(self):
        self.assertEqual(self.show([], sel="목록을 못 읽었다")[0], "검사 불가: 목록을 못 읽었다")

    def test_interview_sections(self):
        self.assertIn("인터뷰: 셀 수 없음 — 이 플러그인 버전은 인터뷰 상태 파일을 아직 남기지 않는다",
                      self.show([], {"supported": False, "items": [], "errors": []}))
        self.assertIn("인터뷰: 진행 중 없음", self.show([], NO_IV))
        lines = self.show([], IV)
        self.assertIn("인터뷰: 진행 중 2개", lines)
        self.assertIn("    docs/superpowers/interview/2026-10-15-t-interview.state.md — 조사 3/20 · 마지막 사건: "
                      "포화 판정 1: 아직 — 빈 곳 2개", lines)
        err = {"supported": True, "items": [], "errors": [{"path": "p.state.md", "reason": "깨짐"}]}
        self.assertIn("    p.state.md — 셀 수 없음(깨짐)", self.show([], err))

    def test_cache_note(self):
        self.assertEqual(self.show([], NO_IV, ["캐시 파일이 깨져 있었다"])[-1], "캐시를 쓰지 못했다 — 캐시 파일이 깨져 있었다")

    def test_control_chars_show(self):
        r = report([blk("R1", "설계 중", "in_progress", title="a\x1b]0;x\x07b", warnings=["w\nx"])])
        text = "\n".join(self.show([(RM, r)]))
        self.assertNotIn("\x1b", text)
        self.assertNotIn("\x07", text)
        self.assertIn("    경고: w x", text.split("\n"))


class Tasks(unittest.TestCase):
    def test_lines(self):
        r = report([blk("R1", "설계 중", "in_progress"), blk("R5", "구현 중", None, reason="R5 단계")], 1)
        out, err, rc = cp.tasks_output([(RM, r)])
        self.assertEqual((out, err, rc), (["R1 에픽 R1 — 설계 중\tin_progress",
                                           "R5 에픽 R5 — 구현 중 · 알 수 없음(R5 단계)\tkeep"], "", 0))

    def test_every_line_has_exactly_two_fields(self):
        r = report([blk("R1", "설계 중", "in_progress", title="탭\t제목")], 0)
        out, _err, _rc = cp.tasks_output([(RM, r)])
        self.assertEqual([len(x.split("\t")) for x in out], [2])

    def test_unknown_exit_prints_nothing(self):
        r = report(BASE, 3, unknown_reasons=["로드맵을 못 읽었다: x (origin/main)"])
        out, err, rc = cp.tasks_output([(RM, r)])
        self.assertEqual((out, rc), ([], 3))
        self.assertEqual(err, "검사 불가 — 로드맵을 못 읽었다: x (origin/main)")

    def test_many_roadmaps(self):
        out, err, rc = cp.tasks_output([(RM, report(BASE)), ("docs/superpowers/roadmaps/rn/roadmap.md", report(BASE))])
        self.assertEqual((out, rc), ([], 2))
        self.assertTrue(err.startswith("로드맵이 여럿이다 — 경로를 하나 주라: "), err)

    def test_none(self):
        self.assertEqual(cp.tasks_output([]), ([], "로드맵 없음 — 작업 목록을 바꾸지 않는다", 3))

    def test_select_error(self):
        self.assertEqual(cp.tasks_output([], "목록을 못 읽었다"), ([], "검사 불가 — 목록을 못 읽었다", 3))


class InterviewState(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(cp.parse_interview_state(STATE), {"n": 3, "limit": 20, "last": "포화 판정 1: 아직 — 빈 곳 2개"})

    def test_empty_dispatches(self):
        text = STATE.replace("{coverage_mapper: 1, blind_spot_prober: 1, steelman_builder: 0, repo_researcher: 1}", "{}")
        self.assertEqual(cp.parse_interview_state(text)["n"], 0)

    def test_no_queue(self):
        self.assertIsNone(cp.parse_interview_state(STATE.split("## audit")[0])["last"])

    def test_bad_inputs(self):
        cases = {
            "no frontmatter": "본문만",
            "unclosed": "---\ntype: interview-state\n",
            "wrong type": STATE.replace("type: interview-state", "type: interview-brief"),
            "bad count": STATE.replace("coverage_mapper: 1", "coverage_mapper: x"),
            "no limit": STATE.replace("  research_limit: 20\n", ""),
            "no dispatches": STATE.replace("research_dispatches", "research_other"),
        }
        for name, text in cases.items():
            with self.subTest(name):
                with self.assertRaises(ValueError):
                    cp.parse_interview_state(text)


class Failed(unittest.TestCase):
    def test_failed_report_renders(self):
        r = cp.failed_report(RM, "사유")
        self.assertEqual(r["exit"], 3)
        self.assertTrue(cp.first_line(r).startswith("로드맵 상태 — 블록 0개"))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패를 본다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_control_plane.py`
Expected: `ModuleNotFoundError: No module named 'control_plane'` 로 ERROR.

- [ ] **Step 3: 순수 함수를 쓴다**

`plugins/spec-distill/scripts/control_plane.py` (Task 2 가 이 파일 끝에 git · 캐시 · 명령줄 절을 붙인다):

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""control_plane.py — 로드맵 상태와 진행 중 인터뷰를 상태줄 한 줄 · 지도 · 작업 목록 줄로 보인다.

명령줄:
  control_plane.py statusline                    상태줄 한 줄. 늘 rc 0.
  control_plane.py show [<로드맵 경로>]           지도. rc 0.
  control_plane.py show --tasks [<로드맵 경로>]   작업 목록 줄 `<제목><탭><pending|in_progress|completed|keep>`.
                                                 검사 불가 · 로드맵 없음 · 꺼짐이면 표준 출력이 비고 표준 오류에
                                                 사유, rc 3. 로드맵이 여럿인데 경로가 없으면 rc 2.

단계 · 경고는 `roadmap_status.py <경로> --json`(origin/main 사본)을 하위 프로세스로 불러 읽기만 한다.
레포 파일과 git 상태를 바꾸지 않는다 — 쓰는 것은 `<git 공용 디렉토리>/devbrew/control-plane.json` 캐시 하나다.
받은 지 N분은 캐시 밖에서 매번 FETCH_HEAD 수정 시각으로 읽는다.
"""
from __future__ import annotations

import re

DONE = ("머지됨", "끝남")
# 상태줄 묶음 — 상태 계산의 단계 이름 + R5 가 더할 이름. 대기 · 끝난 단계 · 알 수 없음은 세지 않는다.
BUCKETS = (("설계", ("설계 중",)), ("구현", ("계획", "구현 중", "구현 끝", "PR")), ("준비", ("준비",)))
UNCOUNTED = ("대기", "머지됨", "끝남", "알 수 없음")
TASK_STATES = ("pending", "in_progress", "completed")
TOP_WARNINGS = (("받드는 에픽 없는 발화", "orphans"), ("미배정 번호", "unassigned"),
                ("brief 에 없는 번호", "unknown_ids"))
CTRL_RE = re.compile(r"[\x00-\x1f\x7f-\x9f]")
DISPATCH_RE = re.compile(r"\s+research_dispatches:\s*\{([^{}]*)\}\s*(?:#.*)?")
LIMIT_RE = re.compile(r"\s+research_limit:\s*(\d+)\s*(?:#.*)?")
QUEUE_HEADING = "## audit §2 대기 줄"
NO_ROADMAP = "로드맵 없음 — origin/main 에 끝나지 않은 블록이 있는 로드맵이 없다"


def clean(value) -> str:
    """제어 문자(탭 · 줄바꿈 · ESC 포함)를 공백으로 — 한 줄 출력과 탭 두 칸을 깨지 않게."""
    return CTRL_RE.sub(" ", str(value))


def folder_name(path: str) -> str:
    parts = path.strip("/").split("/")
    return parts[-2] if len(parts) >= 2 else parts[-1]


def count_warnings(report: dict) -> int:
    """블록 경고 줄 수 + 맨 위 경고 갈래 중 비지 않은 것 하나씩."""
    n = sum(len(b.get("warnings") or []) for b in report.get("blocks") or [])
    return n + sum(1 for _label, key in TOP_WARNINGS if report.get(key))


def bucket_counts(items):
    counts = dict((name, 0) for name, _stages in BUCKETS)
    other = 0
    for _path, report in items:
        for b in report.get("blocks") or []:
            stage = b.get("stage")
            for name, stages in BUCKETS:
                if stage in stages:
                    counts[name] += 1
                    break
            else:
                if stage not in UNCOUNTED:
                    other += 1
    return counts, other


def failed_report(path: str, reason: str) -> dict:
    """상태 계산을 못 읽었을 때의 보고서 — 상태 계산의 키를 모두 갖고 exit 3 이다."""
    return {"roadmap": path, "source": None, "fetched_at": None, "notice": "", "blocks": [],
            "unassigned": None, "orphans": None, "unknown_ids": [], "overlaps": [],
            "format_errors": [], "unknown_reasons": [reason], "exit": 3}


def first_line(report: dict) -> str:
    """상태 계산의 쉬운 첫 줄 그대로."""
    try:
        import roadmap_status
        return roadmap_status.render(report).split("\n", 1)[0]
    except Exception as exc:  # noqa: BLE001 — 첫 줄을 못 만들어도 지도의 나머지는 보인다
        return "로드맵 상태 — 첫 줄을 만들지 못했다(%s)" % type(exc).__name__


# ── 인터뷰 상태 파일 ──────────────────────────────────────────────────────────

def parse_interview_state(text: str) -> dict:
    """{"n": 조사 호출 합, "limit": 상한, "last": 대기 줄의 마지막 사건 | None}. 셀 수 없으면 ValueError."""
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        raise ValueError("frontmatter 가 없다")
    end = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None)
    if end is None:
        raise ValueError("frontmatter 가 닫히지 않았다")
    head = lines[1:end]
    if not head or head[0].strip() != "type: interview-state":
        raise ValueError("첫 키가 type: interview-state 가 아니다")
    n = limit = None
    for line in head:
        m = DISPATCH_RE.fullmatch(line)
        if m:
            n = 0
            for part in (p for p in m.group(1).split(",") if p.strip()):
                _key, sep, val = part.partition(":")
                if not sep or not val.strip().isdigit():
                    raise ValueError("research_dispatches 칸을 셀 수 없다: %s" % part.strip())
                n += int(val.strip())
        m = LIMIT_RE.fullmatch(line)
        if m:
            limit = int(m.group(1))
    if n is None or limit is None:
        raise ValueError("research_dispatches · research_limit 를 찾지 못했다")
    last, in_queue = None, False
    for line in lines[end + 1:]:
        if line.startswith("## "):
            in_queue = line.strip() == QUEUE_HEADING
        elif in_queue and line.startswith("- "):
            last = line[2:].strip()
    return {"n": n, "limit": limit, "last": last}


def _latest(interview):
    return sorted(interview.get("items") or [], key=lambda it: it.get("mtime", 0), reverse=True)


def interview_segment(interview) -> str:
    if not interview or not interview.get("supported"):
        return ""
    parts = []
    items = _latest(interview)
    if items:
        seg = "인터뷰 조사 %d/%d" % (items[0]["n"], items[0]["limit"])
        parts.append(seg + (" 외 %d" % (len(items) - 1) if len(items) > 1 else ""))
    if interview.get("errors"):
        parts.append("인터뷰 셀 수 없음")
    return " · ".join(parts)


def interview_lines(interview) -> list:
    if not interview or not interview.get("supported"):
        return ["인터뷰: 셀 수 없음 — 이 플러그인 버전은 인터뷰 상태 파일을 아직 남기지 않는다"]
    items, errors = _latest(interview), interview.get("errors") or []
    if not items and not errors:
        return ["인터뷰: 진행 중 없음"]
    out = ["인터뷰: 진행 중 %d개" % len(items)]
    for it in items:
        line = "    %s — 조사 %d/%d" % (it["path"], it["n"], it["limit"])
        if it.get("last"):
            line += " · 마지막 사건: %s" % it["last"]
        out.append(clean(line))
    out += [clean("    %s — 셀 수 없음(%s)" % (e["path"], e["reason"])) for e in errors]
    return out


# ── 세 출력 ──────────────────────────────────────────────────────────────────

def statusline_text(items, interview, minutes, select_error=None) -> str:
    """상태줄 한 줄. items 는 고른 로드맵 [(경로, 보고서)] — 수는 전부의 합이고 이름은 첫 로드맵이다."""
    parts = []
    if items:
        parts.append(folder_name(items[0][0]) + (" 외 %d" % (len(items) - 1) if len(items) > 1 else ""))
        counts, other = bucket_counts(items)
        parts += ["%s %d" % (name, counts[name]) for name, _stages in BUCKETS]
        if other:
            parts.append("기타 %d" % other)
        w = sum(count_warnings(r) for _p, r in items)
        parts.append("경고 %d" % w if w else "경고 없음")
        parts.append("받은 지 %d분" % minutes if minutes is not None else "받은 시각 모름")
    seg = interview_segment(interview)
    if seg:
        parts.append(seg)
    if select_error or any(r.get("exit") == 3 for _p, r in items):
        parts.append("검사 불가")
    return clean(" · ".join(parts))


def show_text(items, interview, notes, first_line_fn, select_error=None) -> str:
    lines = []
    if select_error:
        lines.append(clean("검사 불가: %s" % select_error))
    elif not items:
        lines.append(NO_ROADMAP)
    for path, report in items:
        lines.append(clean(first_line_fn(report)))
        lines.append(clean("로드맵: %s" % path))
        blocks = report.get("blocks") or []
        stages = dict((b.get("id"), b.get("stage")) for b in blocks)
        for b in blocks:
            line = "%s %s — %s · %s" % (b.get("id"), b.get("title"), b.get("stage"), b.get("reason"))
            waiting = [d for d in b.get("deps") or [] if stages.get(d) not in DONE]
            if waiting:
                line += " ← 기다림: " + " · ".join(waiting)
            lines.append(clean(line))
            lines += [clean("    경고: %s" % w) for w in b.get("warnings") or []]
        for label, key in TOP_WARNINGS:
            vals = report.get(key)
            if vals is None:
                lines.append("%s: 셀 수 없음" % label)
            elif vals:
                lines.append(clean("%s: %d개 — %s" % (label, len(vals), " · ".join(vals))))
        lines += [clean("검사 불가: 형식 깨짐 — %s" % e) for e in report.get("format_errors") or []]
        lines += [clean("검사 불가: %s" % r) for r in report.get("unknown_reasons") or []]
        if any("rulings" in b for b in blocks):
            lines.append("판정 줄:")
            rows = [clean("    %s: %s" % (b.get("id"), r)) for b in blocks for r in b.get("rulings") or []]
            lines += rows or ["    없음"]
    lines += interview_lines(interview)
    lines += [clean("캐시를 쓰지 못했다 — %s" % n) for n in notes]
    return "\n".join(lines)


def tasks_output(items, select_error=None):
    """(표준 출력 줄들, 표준 오류 글, rc). rc 가 0 이 아니면 지휘자는 작업 목록을 바꾸지 않는다."""
    if select_error:
        return [], clean("검사 불가 — %s" % select_error), 3
    if not items:
        return [], "로드맵 없음 — 작업 목록을 바꾸지 않는다", 3
    if len(items) > 1:
        return [], clean("로드맵이 여럿이다 — 경로를 하나 주라: %s" % " · ".join(p for p, _r in items)), 2
    _path, report = items[0]
    if report.get("exit") == 3:
        reasons = (["형식 깨짐 — %s" % e for e in report.get("format_errors") or []]
                   + list(report.get("unknown_reasons") or []))
        return [], clean("검사 불가 — %s" % (" · ".join(reasons) or "상태 계산이 3 을 냈다")), 3
    out = []
    for b in report.get("blocks") or []:
        title = "%s %s — %s" % (b.get("id"), b.get("title"), b.get("stage"))
        state = b.get("task_status")
        if state in TASK_STATES:
            out.append(clean(title) + "\t" + state)
        else:
            reason = b.get("reason") or "작업 상태가 없다"
            out.append(clean("%s · 알 수 없음(%s)" % (title, reason)) + "\tkeep")
    return out, "", 0
```

- [ ] **Step 4: 통과를 본다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_control_plane.py`
Expected: `OK`.

또 돌린다(새 파일이 걸리는 레포 락): `bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | tail -1` · `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/quality-gates/tests/test_utf8_explicit.py` · `bash shared/tests/test_python_floor.sh 2>&1 | tail -1` · `bash shared/tests/test_no_new_duplication.sh 2>&1 | tail -1` — 모두 Fail 0(또는 OK).

- [ ] **Step 5: 커밋**

```bash
git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-afc2943be6d4e4fe6 add plugins/spec-distill/scripts/control_plane.py plugins/spec-distill/tests/test_control_plane.py
git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-afc2943be6d4e4fe6 commit -F <메시지 파일>
```
메시지: `feat(spec-distill): 컨트롤 플레인 표시 함수 — 상태줄 · 지도 · 작업 목록 줄` + 트레일러 셋.

---

### Task 2: git 읽기 · 캐시 · 명령줄

**Files:**
- Modify: `plugins/spec-distill/scripts/control_plane.py` (import 블록 교체 + 파일 끝에 붙임)
- Create: `plugins/spec-distill/tests/test_control_plane.sh` (100755)

**Interfaces:**
- Consumes: Task 1 의 함수 전부. 같은 폴더의 `kill_switch_active.kill_switch_active(plugin, hook)` · `roadmap_status.py`(하위 프로세스) · `state_path.py`(글자 `interview-state` 유무만).
- Produces: 명령줄 `control_plane.py statusline` · `show [--tasks] [<경로>]`(rc 는 Task 1 docstring 대로). 캐시 파일 `<git 공용 디렉토리>/devbrew/control-plane.json` = `{"version": 1, "entries": {"<경로 또는 *>": {"key": str, "items": [[경로, 보고서]], "interview": {…}, "select_error": str|null}}}`. Task 3 의 skill 과 Task 4 의 README 스크립트가 이 명령줄을 부른다.

- [ ] **Step 1: 실패하는 테스트를 쓴다** (계획이 쓴 테스트 코드 — 리뷰어 심사 대상)

`plugins/spec-distill/tests/test_control_plane.sh`:

```bash
#!/usr/bin/env bash
# control_plane.py — 캐시 · 받은 시각 · 끄기 스위치 · 읽기 전용 · 작업 목록 rc 를 버릴 git 저장소에서 잰다
# (R6 AC3 · AC4 · AC5 · AC6 · AC7 · AC11 · AC13). 상태 계산은 대역으로 바꿔 호출 수를 센다 — 대역은
# 부를 때마다 calls.log 에 인자를 적는다. 끝에서 진짜 상태 계산으로 인자 계약을 한 번 잰다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_control_plane.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset DEVBREW_SPEC_DISTILL_DISABLE DEVBREW_SKIP_HOOKS CLAUDE_CONFIG_DIR
REAL="$ROOT/plugins/spec-distill/scripts"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
W="$T/work"; U="$T/up"; S="$T/scripts"; LOG="$S/calls.log"; CACHE="$W/.git/devbrew/control-plane.json"
RM="docs/superpowers/roadmaps/rm/roadmap.md"
g() { git -C "$W" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"; }
u() { git -C "$U" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"; }
push_file() {  # push_file <경로> <내용> — 다른 사본(U)이 main 에 올리고 W 는 받기만 한다 — W 의 로컬 브랜치는 그대로다
  mkdir -p "$(dirname "$U/$1")" && printf '%s\n' "$2" > "$U/$1" && u add -- "$1" && u commit -qm "$1" \
    && u push -q origin main && g fetch -q origin
}
calls() { if [ -f "$LOG" ]; then wc -l < "$LOG" | tr -d ' '; else echo 0; fi; }
sl()   { (cd "$W" && python3 "$S/control_plane.py" statusline </dev/null); }
show() { (cd "$W" && python3 "$S/control_plane.py" show "$@" </dev/null); }
age()  { python3 -I -c 'import os,sys,time; t=time.time()-int(sys.argv[2]); os.utime(sys.argv[1],(t,t))' "$1" "$2"; }

# ── 픽스처 ────────────────────────────────────────────────────────────────────
git init -q --bare -b main "$T/origin.git"
git clone -q "$T/origin.git" "$U" 2>/dev/null
printf 'x\n' > "$U/README.txt" && u add README.txt && u commit -qm init && u push -q -u origin main
git clone -q "$T/origin.git" "$W" 2>/dev/null
push_file "$RM" "로드맵"
mkdir -p "$S"
cp "$REAL/control_plane.py" "$REAL/kill_switch_active.py" "$S/"
cat > "$S/roadmap_status.py" <<'PY'
#!/usr/bin/env python3
"""테스트 대역 — 부를 때마다 calls.log 에 인자를 적고 stub-<로드맵 폴더>.json(없으면 report.json)을 낸다."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def render(report):
    return "대역 첫 줄 — 블록 %d개" % len(report.get("blocks") or [])


if __name__ == "__main__":
    with open(os.path.join(HERE, "calls.log"), "a", encoding="utf-8") as fh:
        fh.write(" ".join(sys.argv[1:]) + "\n")
    if os.path.exists(os.path.join(HERE, "garbage.flag")):
        print("상태 계산이 깨졌다")
        sys.exit(2)
    parts = sys.argv[1].split("/")
    path = os.path.join(HERE, "stub-%s.json" % (parts[-2] if len(parts) > 1 else ""))
    if not os.path.exists(path):
        path = os.path.join(HERE, "report.json")
    with open(path, encoding="utf-8") as fh:
        report = json.load(fh)
    print(json.dumps(report, ensure_ascii=False))
    sys.exit(report["exit"])
PY
cat > "$S/report.json" <<'JSON'
{"roadmap": "r", "source": "origin/main", "fetched_at": null, "notice": "", "overlaps": [],
 "unassigned": [], "orphans": ["S9"], "unknown_ids": [], "format_errors": [], "unknown_reasons": [], "exit": 1,
 "blocks": [
  {"id": "R1", "title": "하나", "kind": "bundle", "stage": "설계 중", "reason": "spec 있음", "task_status": "in_progress", "deps": [], "warnings": ["경고 하나"], "notes": []},
  {"id": "R2", "title": "둘", "kind": "bundle", "stage": "계획", "reason": "계획 있음", "task_status": "in_progress", "deps": ["R1"], "warnings": [], "notes": []},
  {"id": "R3", "title": "셋", "kind": "bundle", "stage": "준비", "reason": "의존 완료", "task_status": "pending", "deps": [], "warnings": [], "notes": []}]}
JSON
LINE="rm · 설계 1 · 구현 1 · 준비 1 · 경고 2 · 받은 지 0분"
STATE_DIR="$W/docs/superpowers/interview"
write_state() {  # write_state <폴더> <파일 이름> <조사 수 하나> — 진행 중 인터뷰 상태 파일
  mkdir -p "$1"
  printf -- '---\ntype: interview-state\nseed: none\norchestration:\n  research_dispatches: {coverage_mapper: %s, blind_spot_prober: 1, steelman_builder: 1, repo_researcher: 0}\n  research_limit: 20\n---\n\n## audit §2 대기 줄\n\n- 포화 판정 1: 아직 — 빈 곳 1개\n' "$3" > "$1/$2"
}

echo "=== 상태줄 · 캐시(AC1 · AC4) ==="
assert_eq "$(sl)" "$LINE" "상태줄 모양"
assert_eq "$(calls)" "1" "양성 대조: 첫 호출은 상태 계산을 부른다"
assert_eq "$(head -n 1 "$LOG")" "$RM --json" "상태 계산 인자 = <경로> --json"
assert_eq "$(sl)" "$LINE" "캐시가 맞는 둘째 호출도 같은 줄"
assert_eq "$(calls)" "1" "캐시가 맞으면 상태 계산을 다시 부르지 않는다"
g branch -q topic
sl >/dev/null; assert_eq "$(calls)" "2" "키 요소 — 브랜치 머리 목록이 바뀌면 다시 계산"
sl >/dev/null; assert_eq "$(calls)" "2" "다시 맞으면 부르지 않는다"
push_file other.txt "다른 파일"
sl >/dev/null; assert_eq "$(calls)" "3" "키 요소 — origin/main 커밋만 바뀌어도(로드맵 그대로) 다시 계산"
push_file "$RM" "로드맵 바뀜"
sl >/dev/null; assert_eq "$(calls)" "4" "키 요소 — 대상 로드맵 사본이 바뀌면 다시 계산"
printf 'interview-state\n' > "$S/state_path.py"
sl >/dev/null; assert_eq "$(calls)" "5" "인터뷰 상태 파일 지원이 켜지면 다시 계산"
write_state "$STATE_DIR" 2026-10-15-t-interview.state.md 1
assert_eq "$(sl)" "$LINE · 인터뷰 조사 3/20" "진행 중 인터뷰 조각"
assert_eq "$(calls)" "6" "키 요소 — 진행 중 인터뷰 상태 파일이 생기면 다시 계산"
age "$STATE_DIR/2026-10-15-t-interview.state.md" 3000
sl >/dev/null; assert_eq "$(calls)" "7" "키 요소 — 인터뷰 상태 파일 수정 시각이 바뀌면 다시 계산"
printf 'brief\n' > "$STATE_DIR/2026-10-15-t-interview.md"
assert_eq "$(sl)" "$LINE" "짝 brief 가 생기면 진행 중이 아니다"
printf -- '---\ntype: interview-state\n' > "$STATE_DIR/2026-10-16-u-interview.state.md"
assert_eq "$(sl)" "$LINE · 인터뷰 셀 수 없음" "읽지 못한 상태 파일은 셀 수 없음 — 로드맵 부분은 그대로"
assert_contains "$(show)" "    docs/superpowers/interview/2026-10-16-u-interview.state.md — 셀 수 없음(frontmatter 가 닫히지 않았다)" "지도에 사유"
rm -f "$STATE_DIR/2026-10-16-u-interview.state.md" "$S/state_path.py"

echo "=== 받은 시각은 캐시 밖(AC13) ==="
sl >/dev/null; before="$(calls)"
assert_contains "$(sl)" "· 받은 지 0분" "양성 대조: 방금 받았으면 0분"
age "$W/.git/FETCH_HEAD" 600
assert_contains "$(sl)" "· 받은 지 10분" "새 커밋 없이 FETCH_HEAD 만 바뀌어도 경과가 따라온다"
assert_eq "$(calls)" "$before" "그때 상태 계산은 다시 부르지 않는다"
assert_contains "$(show)" "대역 첫 줄" "지도 첫 줄은 상태 계산의 첫 줄"
g fetch -q origin

echo "=== 캐시를 못 쓸 때(AC5) ==="
printf 'not json' > "$CACHE"
out="$(show)"
assert_contains "$out" "캐시를 쓰지 못했다 — 캐시 파일이 깨져 있었다" "깨진 캐시 — 지도에 사유 한 줄"
assert_contains "$out" "R1 하나 — 설계 중 · spec 있음" "깨진 캐시 — 결과는 맞다"
printf 'not json' > "$CACHE"
assert_eq "$(sl)" "$LINE" "깨진 캐시 — 상태줄도 맞다"
rm -rf "$W/.git/devbrew"; printf 'x' > "$W/.git/devbrew"
out="$(show)"
assert_contains "$out" "캐시를 쓰지 못했다 — 캐시 파일을 쓰지 못했다" "쓸 수 없는 캐시 자리 — 사유 한 줄"
assert_contains "$out" "R1 하나 — 설계 중 · spec 있음" "쓸 수 없는 캐시 자리 — 결과는 맞다"
assert_eq "$(sl)" "$LINE" "쓸 수 없는 캐시 자리 — 상태줄도 맞다"
rm -f "$W/.git/devbrew"

echo "=== 동시 호출 ==="
rm -f "$CACHE"
for i in 1 2 3 4; do sl >/dev/null & done; wait
python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1],encoding="utf-8")); sys.exit(0 if d.get("version")==1 else 1)' "$CACHE" \
  && ok "동시 호출 뒤에도 캐시는 온전한 JSON" || no "동시 호출 뒤 캐시가 깨졌다"
left="$(find "$W/.git/devbrew" -name '.control-plane.*' | wc -l | tr -d ' ')"
assert_eq "$left" "0" "임시 파일이 남지 않는다"

echo "=== 끄기 스위치(AC6) ==="
before="$(calls)"
out="$(cd "$W" && DEVBREW_SPEC_DISTILL_DISABLE=1 python3 "$S/control_plane.py" statusline </dev/null)"; rc=$?
assert_eq "$out|$rc" "|0" "DISABLE=1 — 상태줄 빈 줄 · rc 0"
out="$(cd "$W" && DEVBREW_SPEC_DISTILL_DISABLE=1 python3 "$S/control_plane.py" show)"; rc=$?
assert_eq "$out|$rc" "꺼져 있다 — DEVBREW_SPEC_DISTILL_DISABLE=1|0" "DISABLE=1 — 지도 한 줄 · rc 0"
out="$(cd "$W" && DEVBREW_SKIP_HOOKS="x:y,spec-distill:statusline" python3 "$S/control_plane.py" statusline </dev/null)"; rc=$?
assert_eq "$out|$rc" "|0" "SKIP_HOOKS — 상태줄 빈 줄 · rc 0"
out="$(cd "$W" && DEVBREW_SKIP_HOOKS="spec-distill:statusline" python3 "$S/control_plane.py" show)"; rc=$?
assert_eq "$out|$rc" "꺼져 있다 — DEVBREW_SKIP_HOOKS 의 spec-distill:statusline|0" "SKIP_HOOKS — 지도 한 줄 · rc 0"
out="$(cd "$W" && DEVBREW_SPEC_DISTILL_DISABLE=1 python3 "$S/control_plane.py" show --tasks 2>"$T/err")"; rc=$?
assert_eq "$out|$rc" "|3" "꺼짐 — 작업 목록 줄은 비고 rc 3"
assert_contains "$(cat "$T/err")" "꺼져 있다 — DEVBREW_SPEC_DISTILL_DISABLE=1" "꺼짐 — 사유는 표준 오류"
assert_eq "$(calls)" "$before" "꺼져 있으면 상태 계산을 부르지 않는다"
assert_eq "$(cd "$W" && DEVBREW_SPEC_DISTILL_DISABLE=0 python3 "$S/control_plane.py" statusline </dev/null)" "$LINE" "양성 대조: DISABLE=0 은 끄지 않는다"
assert_eq "$(cd "$W" && DEVBREW_SKIP_HOOKS="spec-distill:statusline-x" python3 "$S/control_plane.py" statusline </dev/null)" "$LINE" "양성 대조: 다른 토큰은 끄지 않는다"

echo "=== 읽기 전용(AC7) ==="
rm -f "$CACHE"
s0="$(g status --porcelain --untracked-files=all)"; h0="$(g rev-parse HEAD)"; r0="$(g for-each-ref)"
sl >/dev/null; show >/dev/null; show --tasks >/dev/null 2>&1
assert_eq "$(g status --porcelain --untracked-files=all)" "$s0" "작업 트리 상태가 같다"
assert_eq "$(g rev-parse HEAD)|$(g for-each-ref)" "$h0|$r0" "HEAD 와 참조가 같다"
[ -f "$CACHE" ] && ok "양성 짝: 캐시는 git 디렉토리 안에 실제로 쓰였다" || no "캐시 파일이 없다 — 읽기 전용 단언이 공허하다"

echo "=== 작업 목록(AC3) ==="
out="$(show --tasks 2>/dev/null)"; rc=$?
assert_eq "$rc" "0" "작업 목록 rc 0"
assert_eq "$(printf '%s\n' "$out" | head -n 1)" "$(printf 'R1 하나 — 설계 중\tin_progress')" "첫 줄 = 제목 탭 상태"
cp "$S/report.json" "$S/stub-rm.json"
python3 -I -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p,encoding="utf-8")); d["exit"]=3; d["unknown_reasons"]=["로드맵을 못 읽었다: x"]; json.dump(d,open(p,"w",encoding="utf-8"),ensure_ascii=False)' "$S/stub-rm.json"
rm -f "$CACHE"
out="$(show --tasks 2>"$T/err")"; rc=$?
assert_eq "$out|$rc" "|3" "상태 계산이 3 이면 표준 출력이 비고 rc 3"
assert_eq "$(cat "$T/err")" "검사 불가 — 로드맵을 못 읽었다: x" "사유는 표준 오류"
assert_eq "$(sl)" "rm · 설계 1 · 구현 1 · 준비 1 · 경고 2 · 받은 지 0분 · 검사 불가" "상태줄은 검사 불가 조각"
rm -f "$S/stub-rm.json" "$CACHE"

echo "=== 상태 계산이 깨짐 ==="
: > "$S/garbage.flag"
assert_eq "$(sl)" "rm · 설계 0 · 구현 0 · 준비 0 · 경고 없음 · 받은 지 0분 · 검사 불가" "JSON 이 아닌 출력은 검사 불가"
assert_contains "$(show)" "검사 불가: 상태 계산 출력을 읽지 못했다(rc 2)" "지도에 사유"
rm -f "$S/garbage.flag" "$CACHE"

echo "=== 로드맵 여럿 · 고르기 ==="
printf '{"roadmap":"d","source":"origin/main","fetched_at":null,"notice":"","overlaps":[],"unassigned":[],"orphans":[],"unknown_ids":[],"format_errors":[],"unknown_reasons":[],"exit":0,"blocks":[{"id":"A1","title":"끝","kind":"bundle","stage":"머지됨","reason":"r","task_status":"completed","deps":[],"warnings":[],"notes":[]}]}\n' > "$S/stub-done.json"
push_file docs/superpowers/roadmaps/done/roadmap.md "끝난 로드맵"
assert_eq "$(sl)" "$LINE" "블록이 다 끝난 로드맵은 고르지 않는다"
push_file docs/superpowers/roadmaps/rn/roadmap.md "둘째 로드맵"
assert_eq "$(sl)" "rm 외 1 · 설계 2 · 구현 2 · 준비 2 · 경고 4 · 받은 지 0분" "로드맵 둘 — 첫 이름 + 외 1, 수는 합"
out="$(show --tasks 2>"$T/err")"; rc=$?
assert_eq "$out|$rc" "|2" "로드맵이 여럿인데 경로 없음 — rc 2"
out="$(show --tasks "docs/superpowers/roadmaps/rn/roadmap.md" 2>/dev/null)"; rc=$?
assert_eq "$rc|$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "0|3" "경로를 주면 그 로드맵만"
out="$(show --tasks "$W/docs/superpowers/roadmaps/rn/roadmap.md" 2>/dev/null)"; rc=$?
assert_eq "$rc" "0" "절대 경로 인자도 레포 상대로 바뀐다"
assert_eq "$(tail -n 1 "$LOG")" "docs/superpowers/roadmaps/rn/roadmap.md --json" "절대 경로 → 상대 경로로 상태 계산에"
out="$(show -- -x 2>/dev/null)"; rc=$?
assert_eq "$rc" "2" "- 로 시작하는 경로는 사용법 오류"

echo "=== 레포 밖 · 표준 입력 작업 디렉토리 ==="
mkdir -p "$T/plain"
assert_eq "$(cd "$T/plain" && python3 "$S/control_plane.py" statusline </dev/null)" "" "레포 밖 — 빈 줄"
out="$(cd "$T/plain" && printf '{"workspace":{"current_dir":"%s"}}' "$W" | python3 "$S/control_plane.py" statusline)"
assert_contains "$out" "rm 외 1 · " "표준 입력 JSON 의 workspace.current_dir 를 쓴다"
out="$(cd "$T/plain" && printf '{"cwd":"%s"}' "$W" | python3 "$S/control_plane.py" statusline)"
assert_contains "$out" "rm 외 1 · " "표준 입력 JSON 의 cwd 도 쓴다"
git init -q "$T/noorigin"
assert_eq "$(cd "$T/noorigin" && python3 "$S/control_plane.py" statusline </dev/null)" "" "origin 없는 레포 — 빈 줄"
mkdir -p "$T/noorigin/docs/superpowers/interview"
printf 'interview-state\n' > "$S/state_path.py"
write_state "$T/noorigin/docs/superpowers/interview" 2026-10-15-v-interview.state.md 2
assert_eq "$(cd "$T/noorigin" && python3 "$S/control_plane.py" statusline </dev/null)" "인터뷰 조사 4/20" "로드맵 없이 진행 중 인터뷰 — 인터뷰 조각만"
rm -f "$S/state_path.py"

echo "=== 진짜 상태 계산과의 인자 계약 ==="
out="$(cd "$W" && python3 "$REAL/control_plane.py" show docs/superpowers/roadmaps/none/roadmap.md)"
assert_contains "$out" "검사 불가: 로드맵을 못 읽었다: docs/superpowers/roadmaps/none/roadmap.md (origin/main)" "main 에 없는 로드맵 — 검사 불가"
out="$(cd "$W" && python3 "$REAL/control_plane.py" show --tasks docs/superpowers/roadmaps/none/roadmap.md 2>"$T/err")"; rc=$?
assert_eq "$out|$rc" "|3" "진짜 상태 계산이 3 — 작업 목록 비고 rc 3"
assert_contains "$(cat "$T/err")" "로드맵을 못 읽었다" "진짜 사유가 표준 오류에"

echo "=== 변이(AC11) — 통과가 정답인 단언이 이빨을 갖는가 ==="
mutant() {  # mutant <이름> <옛 글자> <새 글자> — 대역 폴더 사본에 한 곳을 바꾼다. 못 심으면 계측기 고장
  rm -rf "$T/m-$1"; cp -R "$S" "$T/m-$1"; rm -f "$T/m-$1/calls.log"
  python3 -I -c 'import sys
p, old, new = sys.argv[1:4]
t = open(p, encoding="utf-8").read()
if t.count(old) != 1:
    sys.exit(1)
open(p, "w", encoding="utf-8").write(t.replace(old, new))' "$T/m-$1/control_plane.py" "$2" "$3" \
    || no "변이 심기 실패: $1 — '$2' 가 정확히 한 번 있지 않다"
}
mcalls() { if [ -f "$T/m-$1/calls.log" ]; then wc -l < "$T/m-$1/calls.log" | tr -d ' '; else echo 0; fi; }
msl() { (cd "$W" && python3 "$T/m-$1/control_plane.py" statusline </dev/null); }

# 각 변이: 캐시를 비우고 한 번 → 호출 수 c1 → 그 요소만 바꾸고 한 번 → c2. 원본은 위 단언에서 c2 > c1 이었다.
mutant hit "    if hit is not None:" "    if False:"
rm -f "$CACHE"; msl hit >/dev/null; c1="$(mcalls hit)"; msl hit >/dev/null; c2="$(mcalls hit)"
[ "$c2" -gt "$c1" ] && ok "변이 잡힘: 캐시를 안 쓰면 호출 수 단언이 RED" || no "변이 생존: 캐시 끄기($c1 → $c2)"
mutant refs 'main or "-", refs_hash,' 'main or "-", "refs",'
rm -f "$CACHE"; msl refs >/dev/null; c1="$(mcalls refs)"; g branch -q topic2; msl refs >/dev/null; c2="$(mcalls refs)"
[ "$c2" = "$c1" ] && ok "변이 잡힘: 브랜치 요소를 빼면 브랜치 단언이 RED" || no "변이 생존: 브랜치 요소($c1 → $c2)"
mutant main 'mode, main or "-",' 'mode, "-",'
rm -f "$CACHE"; msl main >/dev/null; c1="$(mcalls main)"; push_file other2.txt "또"; msl main >/dev/null; c2="$(mcalls main)"
[ "$c2" = "$c1" ] && ok "변이 잡힘: origin/main 요소를 빼면 커밋 단언이 RED" || no "변이 생존: origin/main 요소($c1 → $c2)"
mutant stamps '"\n".join(stamps)]' '""]'
printf 'interview-state\n' > "$T/m-stamps/state_path.py"
rm -f "$CACHE"; msl stamps >/dev/null; c1="$(mcalls stamps)"
age "$STATE_DIR/2026-10-15-t-interview.state.md" 9000; rm -f "$STATE_DIR/2026-10-15-t-interview.md"
msl stamps >/dev/null; c2="$(mcalls stamps)"
[ "$c2" = "$c1" ] && ok "변이 잡힘: 인터뷰 요소를 빼면 인터뷰 단언이 RED" || no "변이 생존: 인터뷰 요소($c1 → $c2)"
rm -rf "$W/docs/superpowers/interview"
mutant switch "        if switch_name():" "        if False:"
out="$(cd "$W" && DEVBREW_SPEC_DISTILL_DISABLE=1 python3 "$T/m-switch/control_plane.py" statusline </dev/null)"
[ -n "$out" ] && ok "변이 잡힘: 끄기 스위치를 안 보면 빈 줄 단언이 RED" || no "변이 생존: 끄기 스위치"
mutant place 'Path(repo.cwd, common) / "devbrew"' 'Path(repo.cwd) / "devbrew"'
s0="$(g status --porcelain --untracked-files=all)"; msl place >/dev/null
[ "$(g status --porcelain --untracked-files=all)" != "$s0" ] && ok "변이 잡힘: 캐시를 작업 트리에 쓰면 읽기 전용 단언이 RED" || no "변이 생존: 캐시 자리"
rm -rf "$W/devbrew"

finish
```

`chmod +x plugins/spec-distill/tests/test_control_plane.sh`

- [ ] **Step 2: 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_control_plane.sh 2>&1 | tail -5`
Expected: 첫 단언부터 `✗`(명령줄이 없어 출력이 비거나 오류) · `Fail:` 0 이 아님.

- [ ] **Step 3: 구현한다**

`control_plane.py` 의 import 블록(`from __future__ import annotations` 다음의 `import re` 한 줄)을 아래로 바꾼다:

```python
import argparse
import datetime
import hashlib
import json
import os
import re
import select
import subprocess
import sys
import tempfile
import time
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))
from kill_switch_active import kill_switch_active  # noqa: E402
```

그리고 파일 끝에 붙인다:

```python


# ── git · 인터뷰 파일 · 캐시 (읽기 전용 — 쓰는 것은 캐시 파일 하나) ──────────────────

MAIN_REF = "refs/remotes/origin/main"
ROADMAP_RE = re.compile(r"docs/superpowers/roadmaps/[^/]+/roadmap\.md")
GIT_OK = frozenset({"rev-parse", "ls-tree", "for-each-ref"})
CACHE_VERSION = 1
STATE_SUFFIX = "-interview.state.md"


class Repo:
    def __init__(self, cwd: str):
        self.cwd = cwd
        self.env = dict(os.environ, GIT_OPTIONAL_LOCKS="0", GIT_TERMINAL_PROMPT="0",
                        GIT_NO_LAZY_FETCH="1", LC_ALL="C")

    def git(self, *args):
        if not args or args[0] not in GIT_OK:
            raise RuntimeError("허용하지 않은 git 하위 명령: %r" % (args[:1],))
        try:
            proc = subprocess.run(["git", "-c", "core.quotePath=false"] + list(args), cwd=self.cwd,
                                  env=self.env, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE, timeout=30)
        except (OSError, subprocess.SubprocessError):
            return 1, ""
        return proc.returncode, proc.stdout.decode("utf-8", "replace")

    def line(self, *args):
        rc, out = self.git(*args)
        return out.strip() if rc == 0 and out.strip() else None


def open_repo(cwd: str):
    top = Repo(cwd).line("rev-parse", "--show-toplevel")
    return Repo(top) if top else None


def fetch_stamp(repo: Repo):
    """이 워크트리와 공용 git 디렉토리의 FETCH_HEAD 수정 시각 중 새것 — 상태 계산의 fetched_at 과 같은 출처."""
    stamps = []
    for args, tail in ((("rev-parse", "--git-path", "FETCH_HEAD"), ""),
                       (("rev-parse", "--git-common-dir"), "FETCH_HEAD")):
        out = repo.line(*args)
        if out:
            try:
                stamps.append(Path(repo.cwd, out, tail).stat().st_mtime)
            except OSError:
                continue
    return max(stamps) if stamps else None


def candidates(repo: Repo, main):
    """([(경로, blob)], 사유). origin/main 이 없으면 고를 것이 없다(로드맵 없음과 같다)."""
    if not main:
        return [], None
    rc, out = repo.git("ls-tree", "-r", "-z", MAIN_REF, "--", "docs/superpowers/roadmaps/")
    if rc != 0:
        return [], "origin/main 의 로드맵 목록을 읽지 못했다(git ls-tree rc %d)" % rc
    found = []
    for entry in (e for e in out.split("\0") if e):
        meta, _tab, path = entry.partition("\t")
        if ROADMAP_RE.fullmatch(path):
            found.append((path, meta.split()[-1]))
    return sorted(found), None


def interview_files(root: str):
    """(지원 여부, [(레포 상대 경로, Path, mtime_ns)] 짝 brief 없는 것, 폴더 사유 | None)."""
    try:
        supported = "interview-state" in (SCRIPTS / "state_path.py").read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        supported = False
    if not supported:
        return False, [], None
    folder = Path(root, "docs", "superpowers", "interview")
    try:
        names = sorted(os.listdir(str(folder)))
    except FileNotFoundError:
        return True, [], None
    except OSError as exc:
        return True, [], "인터뷰 폴더를 읽지 못했다(%s)" % type(exc).__name__
    files = []
    for name in names:
        if not name.endswith(STATE_SUFFIX):
            continue
        if (folder / (name[: -len(".state.md")] + ".md")).exists():
            continue
        try:
            files.append(("docs/superpowers/interview/" + name, folder / name, (folder / name).stat().st_mtime_ns))
        except OSError:
            files.append(("docs/superpowers/interview/" + name, folder / name, -1))
    return True, files, None


def read_interviews(supported, files, folder_error) -> dict:
    summary = {"supported": supported, "items": [], "errors": []}
    if folder_error:
        summary["errors"].append({"path": "docs/superpowers/interview", "reason": folder_error})
    for rel, path, mtime_ns in files:
        try:
            item = parse_interview_state(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError) as exc:
            summary["errors"].append({"path": rel, "reason": "읽지 못했다(%s)" % type(exc).__name__})
            continue
        except ValueError as exc:
            summary["errors"].append({"path": rel, "reason": str(exc)})
            continue
        item.update(path=rel, mtime=mtime_ns / 1e9)
        summary["items"].append(item)
    return summary


def cache_key(repo: Repo, main, mode, targets, stamps):
    """origin/main 커밋 · 브랜치 머리 목록(origin/main · symref 줄 뺌) · 대상 로드맵의 origin/main 사본 · 진행 중 인터뷰
    상태 파일. git 을 못 읽으면 None — 캐시를 쓰지 않는다."""
    rc, out = repo.git("for-each-ref", "--format=%(refname) %(objectname) %(symref)", "refs/heads", "refs/remotes")
    if rc != 0:
        return None
    kept = []
    for row in out.splitlines():
        name, _oid, symref = (row.split(" ") + ["", ""])[:3]
        if name != MAIN_REF and not symref:  # origin/main 은 첫 요소가, 가리키는 참조(origin/HEAD)는 그 대상이 맡는다
            kept.append(row)
    refs = "\n".join(kept)
    refs_hash = hashlib.sha256(refs.encode("utf-8")).hexdigest()
    parts = [mode, main or "-", refs_hash, "\n".join("%s=%s" % t for t in targets), "\n".join(stamps)]
    return hashlib.sha256("\0".join(parts).encode("utf-8")).hexdigest()


def cache_file(repo: Repo):
    common = repo.line("rev-parse", "--git-common-dir")
    if not common:
        return None
    return Path(repo.cwd, common) / "devbrew" / "control-plane.json"


def load_cache(path):
    """(entries, 사유 | None). 없는 캐시는 사유가 아니다."""
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return {}, None
    except (OSError, UnicodeDecodeError) as exc:
        return {}, "캐시 파일을 읽지 못했다(%s)" % type(exc).__name__
    try:
        data = json.loads(text)
        if data.get("version") != CACHE_VERSION or not isinstance(data.get("entries"), dict):
            raise ValueError("모양이 다르다")
    except (ValueError, AttributeError):
        return {}, "캐시 파일이 깨져 있었다"
    return data["entries"], None


def save_cache(path, entries):
    """임시 파일 + os.replace 로 원자적으로 쓴다. 실패하면 사유를 낸다."""
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(prefix=".control-plane.", suffix=".tmp", dir=str(path.parent))
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as fh:
                json.dump({"version": CACHE_VERSION, "entries": entries}, fh, ensure_ascii=False)
            os.replace(tmp, str(path))
        except BaseException:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            raise
    except OSError as exc:
        return "캐시 파일을 쓰지 못했다(%s)" % (exc.strerror or type(exc).__name__)
    return None


def cached_view(entry, key):
    """캐시 항목이 이 키에 맞고 모양이 온전하면 (items, interview, select_error), 아니면 None."""
    if key is None or not isinstance(entry, dict) or entry.get("key") != key:
        return None
    try:
        items = [(str(p), r) for p, r in entry["items"] if isinstance(r, dict)]
        interview = entry["interview"]
        if not isinstance(interview, dict) or len(items) != len(entry["items"]):
            return None
        return items, interview, entry.get("select_error")
    except (KeyError, TypeError, ValueError):
        return None


def run_status(repo: Repo, path: str) -> dict:
    """roadmap_status.py <경로> --json 을 부른다. 못 읽으면 검사 불가(3) 보고서."""
    try:
        proc = subprocess.run([sys.executable, str(SCRIPTS / "roadmap_status.py"), path, "--json"],
                              cwd=repo.cwd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, timeout=120)
    except (OSError, subprocess.SubprocessError) as exc:
        return failed_report(path, "상태 계산을 부르지 못했다(%s)" % type(exc).__name__)
    try:
        report = json.loads(proc.stdout.decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        report = None
    if (not isinstance(report, dict) or not isinstance(report.get("blocks"), list)
            or report.get("exit") not in (0, 1, 3)):
        return failed_report(path, "상태 계산 출력을 읽지 못했다(rc %d)" % proc.returncode)
    return report


def unfinished(report: dict) -> bool:
    return report.get("exit") == 3 or any(b.get("stage") not in DONE for b in report.get("blocks") or [])


def gather(cwd: str, arg):
    """화면에 필요한 것 전부. 받은 시각은 캐시 밖에서 매번 읽는다."""
    view = {"items": [], "interview": None, "notes": [], "minutes": None, "select_error": None}
    repo = open_repo(cwd)
    supported, files, folder_error = interview_files(repo.cwd if repo else cwd)
    if repo is None:
        view["interview"] = read_interviews(supported, files, folder_error)
        if arg:
            view["items"] = [(arg, failed_report(arg, "git 레포 안이 아니다"))]
        return view
    stamp = fetch_stamp(repo)
    fetched = None
    if stamp is not None:
        view["minutes"] = max(0, int((time.time() - stamp) // 60))
        fetched = datetime.datetime.fromtimestamp(stamp).strftime("%Y-%m-%d %H:%M")
    main = repo.line("rev-parse", "--verify", "--quiet", MAIN_REF + "^{commit}")
    if arg:
        if os.path.isabs(arg):
            arg = os.path.relpath(os.path.realpath(arg), os.path.realpath(repo.cwd))
        arg = arg[2:] if arg.startswith("./") else arg
        blob = repo.line("rev-parse", "--verify", "--quiet", "%s:%s" % (MAIN_REF, arg)) if main else None
        targets, select_error = [(arg, blob or "-")], None
    else:
        targets, select_error = candidates(repo, main)
    mode = arg or "*"
    stamps = ["supported=%d" % supported] + ["%s=%d" % (rel, m) for rel, _p, m in files]
    if folder_error:
        stamps.append("folder=" + folder_error)
    key = cache_key(repo, main, mode, targets, stamps)
    path = cache_file(repo)
    entries, note = load_cache(path) if path else ({}, "git 공용 디렉토리를 찾지 못했다")
    if note:
        view["notes"].append(note)
    hit = cached_view(entries.get(mode), key)
    if hit is not None:
        items, interview, select_error = hit
    else:
        reports = [(p, run_status(repo, p)) for p, _blob in targets]
        items = reports if arg else [(p, r) for p, r in reports if unfinished(r)]
        interview = read_interviews(supported, files, folder_error)
        if key is None:
            view["notes"].append("캐시 키를 만들지 못했다(git 읽기 실패)")
        elif path is not None:
            kept = dict((k, v) for k, v in entries.items() if k == "*" and k != mode)
            kept[mode] = {"key": key, "items": [[p, r] for p, r in items], "interview": interview,
                          "select_error": select_error}
            err = save_cache(path, kept)
            if err:
                view["notes"].append(err)
    for _p, r in items:
        r["fetched_at"] = fetched  # 첫 줄의 받은 시각도 캐시 밖에서
    view.update(items=items, interview=interview, select_error=select_error)
    return view


# ── 명령줄 ───────────────────────────────────────────────────────────────────

def switch_name():
    if os.environ.get("DEVBREW_SPEC_DISTILL_DISABLE") == "1":
        return "DEVBREW_SPEC_DISTILL_DISABLE=1"
    if kill_switch_active("spec-distill", "statusline"):
        return "DEVBREW_SKIP_HOOKS 의 spec-distill:statusline"
    return None


def stdin_dir():
    """상태줄 표준 입력 JSON 의 workspace.current_dir → cwd. 없거나 읽을 수 없으면 None."""
    try:
        if sys.stdin is None or sys.stdin.isatty():
            return None
        ready, _w, _x = select.select([sys.stdin], [], [], 0.2)
        if not ready:
            return None
        data = json.loads(sys.stdin.read() or "{}")
        for cand in ((data.get("workspace") or {}).get("current_dir"), data.get("cwd")):
            if isinstance(cand, str) and os.path.isdir(cand):
                return cand
    except Exception:  # noqa: BLE001 — 표준 입력이 이상하면 프로세스 cwd 를 쓴다
        return None
    return None


def cmd_statusline() -> int:
    try:
        if switch_name():
            print("")
            return 0
        v = gather(stdin_dir() or os.getcwd(), None)
        print(statusline_text(v["items"], v["interview"], v["minutes"], v["select_error"]))
    except Exception as exc:  # noqa: BLE001 — 상태줄은 늘 한 줄을 낸다
        print(clean("검사 불가 — 상태줄 내부 오류(%s)" % type(exc).__name__))
    return 0


def cmd_show(tasks: bool, arg) -> int:
    sw = switch_name()
    if sw:
        if tasks:
            sys.stderr.write("꺼져 있다 — %s\n" % sw)
            return 3
        print("꺼져 있다 — %s" % sw)
        return 0
    try:
        v = gather(os.getcwd(), arg)
    except Exception as exc:  # noqa: BLE001 — 계산이 죽어도 0 · 1 로 보이지 않는다
        msg = clean("검사 불가 — 내부 오류(%s: %s)" % (type(exc).__name__, exc))
        if tasks:
            sys.stderr.write(msg + "\n")
            return 3
        print(msg)
        return 0
    if tasks:
        out, err, rc = tasks_output(v["items"], v["select_error"])
        if out:
            print("\n".join(out))
        if err:
            sys.stderr.write(err + "\n")
        return rc
    print(show_text(v["items"], v["interview"], v["notes"], first_line, v["select_error"]))
    return 0


def main(argv=None) -> int:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    ap = argparse.ArgumentParser(prog="control_plane.py",
                                 description="로드맵 상태를 상태줄 · 지도 · 작업 목록 줄로 보인다.")
    sub = ap.add_subparsers(dest="cmd")
    sub.add_parser("statusline")
    sp = sub.add_parser("show")
    sp.add_argument("--tasks", action="store_true")
    sp.add_argument("roadmap", nargs="?")
    args = ap.parse_args(argv)
    if args.cmd == "statusline":
        return cmd_statusline()
    if args.cmd == "show":
        if args.roadmap is not None and (not args.roadmap.strip() or args.roadmap.startswith("-")):
            sys.stderr.write("사용법: 로드맵 경로는 비지 않고 - 로 시작하지 않는다\n")
            return 2
        return cmd_show(args.tasks, args.roadmap)
    ap.print_usage(sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
```

주의:
- 변이 단계가 무는 글자 여섯 — `    if hit is not None:` · `main or "-", refs_hash,` · `mode, main or "-",` · `"\n".join(stamps)]` · `        if switch_name():` · `Path(repo.cwd, common) / "devbrew"` — 는 파일에 정확히 한 번씩만 있어야 한다(테스트가 센다).
- `kill_switch_active.py` 는 같은 폴더의 사본이다(`# copy-of:`). 고치지 않는다.

- [ ] **Step 4: 통과를 본다**

Run: `bash plugins/spec-distill/tests/test_control_plane.sh 2>&1 | tail -3` → `Fail: 0`.
Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_control_plane.py` → `OK`.
또: `bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | tail -1` · `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/quality-gates/tests/test_utf8_explicit.py` · `bash shared/tests/test_python_floor.sh 2>&1 | tail -1` · `bash shared/tests/test_no_new_duplication.sh 2>&1 | tail -1` · `bash shared/tests/test_inline_python_isolated.sh 2>&1 | tail -1` · `bash shared/tests/test_copy_of_contract.sh 2>&1 | tail -1` — 모두 Fail 0.

변이 단계의 RED 를 손으로도 한 번 본다(양성 대조): 테스트의 `mutant hit …` 줄의 새 글자를 옛 글자와 같게 바꿔 돌리면 `변이 생존` 이 나와야 한다 — 확인 뒤 되돌린다(`git -C … diff -- plugins/spec-distill/tests/test_control_plane.sh` 가 비었는지).

- [ ] **Step 5: 커밋**

`chmod +x` 뒤 두 파일을 pathspec 으로 커밋하고 `git -C … ls-files -s plugins/spec-distill/tests/test_control_plane.sh` 가 `100755` 인지 본다.
메시지: `feat(spec-distill): 컨트롤 플레인 캐시 · 받은 시각 · 끄기 스위치 · 명령줄` + 트레일러 셋.

---

### Task 3: 진입 skill `roadmap-status` 와 호출 표면 락

**Files:**
- Create: `plugins/spec-distill/skills/roadmap-status/SKILL.md`
- Modify: `shared/entry/check_invocation_surface.py:26-32` (`ENTRY_SKILLS`)
- Modify: `shared/tests/test_invocation_surface.sh` (`mk_repo` 의 `ENTRY` 목록)

**Interfaces:**
- Consumes: `control_plane.py show [<경로>]`(Task 2), 사전 검사 스크립트 `scripts/entry_preflight.py`(있음).
- Produces: `/spec-distill:roadmap-status [<로드맵 경로>]`.

- [ ] **Step 1: 락에 새 진입 skill 을 먼저 올리고 RED 를 본다**

`shared/entry/check_invocation_surface.py` 의 `ENTRY_SKILLS` 에 한 줄을 더한다(`spec-review` 다음):

```python
    ("spec-distill", "roadmap-status"),
```

`shared/tests/test_invocation_surface.sh` 의 `mk_repo` 안 `ENTRY = [...]` 에 `("spec-distill", "roadmap-status", False),` 를 `spec-review` 항목 다음에 더한다(합성 리포도 같은 목록을 만족해야 양성 대조가 GREEN 이다).

Run: `bash shared/tests/test_invocation_surface.sh 2>&1 | grep -E '✗|Total' | head`
Expected: 2부(이 리포)에서 `I … 새 이름 진입 skill 'roadmap-status' 가 자기 자리에 없다(양성 짝)` 로 RED.

- [ ] **Step 2: skill 을 쓴다**

사전 검사 머리는 락이 내는 모양 그대로 쓴다 — `python3 shared/entry/check_invocation_surface.py --print-head spec-distill roadmap-status` 출력과 글자가 같아야 한다. 「사람에게 쓰는 글」 블록은 `shared/style/plain-language.md` 전체(표시 줄 포함)를 바이트 그대로 붙인다(`shared/tests/test_plain_language_block.sh`). 블록 자리는 H1 바로 다음 첫 비지 않은 줄이다.

`plugins/spec-distill/skills/roadmap-status/SKILL.md`:

````markdown
---
name: roadmap-status
description: >
  사용자가 `/spec-distill:roadmap-status [<로드맵 경로>]` 로 부른다. origin/main 의 로드맵마다 에픽 단계 ·
  기다리는 에픽 · 경고 · 진행 중 인터뷰의 조사 수 · 판정 줄을 한 화면에 보인다. 읽기만 한다.
cost_class: low
argument-hint: "[<로드맵 경로>]"
allowed-tools:
  - Bash(python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" spec-distill roadmap-status)
---

# roadmap-status — 에픽 지도

<shared/style/plain-language.md 전체를 여기에 바이트 그대로>

지도는 `scripts/control_plane.py show` 가 만든다. 이 skill 은 그것을 한 번 돌려 그대로 보인다.

!`python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" spec-distill roadmap-status`

## 진입 단계

이 절이 다른 모든 절보다 먼저 돈다. 이 제목 바로 위, 사전 검사 줄이 남긴 자리를 읽고 아래 순서대로 간다.

### 1. 감시줄 판독

| 그 자리의 내용 | 동작 |
|---|---|
| `[devbrew-entry] ok …` | 2 로 간다. 그 줄의 `root=` 값을 2 에서 쓴다 |
| `[devbrew-entry] disabled …` | 그 줄을 그대로 보이고 멈춘다(no-op) |
| `[devbrew-entry] error …` | `[spec-distill] roadmap-status 사전 검사 실패 — <reason= 값>. 지도를 내지 않는다.` 를 내고 멈춘다 |
| `[shell command execution disabled by policy]` | `[spec-distill] roadmap-status 사전 검사 불가(정책) — disableSkillShellExecution 이 사전 검사를 막았다. 지도를 내지 않는다.` 를 내고 멈춘다 |
| 감시줄 없음 · 그 밖 | `[spec-distill] roadmap-status 사전 검사 결과 없음 — 그 자리에 감시줄이 없다(치환 실패 · 출력 소실). 정책 설정과는 무관하다. 지도를 내지 않는다.` 를 내고 멈춘다 |

이 표가 보는 kill switch 는 `DEVBREW_SPEC_DISTILL_DISABLE=1` 하나다. 지도 스크립트는 `DEVBREW_SKIP_HOOKS` 의 `spec-distill:statusline` 도 본다.

### 2. 지도 내기

받은 인자(`$ARGUMENTS`)를 본다. 비었으면 경로 없이 부른다. 공백 없는 한 토큰이면 그 토큰을 로드맵 경로로 넘긴다. 공백이 섞였거나 `-` 로 시작하면 `[spec-distill] roadmap-status 인자는 로드맵 경로 하나다 — 받은 것: <인자>.` 를 내고 멈춘다.

아래 펜스의 `<root>` 를 감시줄의 `root=` 값으로 바꾸고, 경로가 있으면 `<경로>` 를 그 토큰으로, 없으면 `"<경로>"` 를 지워 Bash 로 한 번 돌린다.

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라." >&2; exit 1; }
cd "<root>" && python3 "$SD/scripts/control_plane.py" show "<경로>"
```

## 보이기

출력을 고치지 않고 그대로 보인다 — 첫 줄이 지금 상태다. 맨 끝에 할 일 한 줄만 더한다: 「검사 불가」 줄이 있으면 그 첫 사유를 고치는 것, 없고 경고가 있으면 첫 경고를 다루는 것, 둘 다 없으면 「할 일 없음」.
````

- [ ] **Step 3: 락들을 돌린다**

Run(각각 `Fail: 0` 또는 GREEN):
- `bash shared/tests/test_invocation_surface.sh 2>&1 | tail -3`
- `bash shared/tests/test_entry_preflight.sh 2>&1 | tail -1`
- `bash shared/tests/test_plain_language_block.sh 2>&1 | tail -1`
- `bash shared/tests/test_skill_body_no_positional_tokens.sh 2>&1 | tail -1`
- `bash shared/tests/test_plugin_root_no_cwd_fallback.sh 2>&1 | tail -1`
- `bash shared/tests/test_skill_reference_pointers.sh 2>&1 | tail -1`
- `bash plugins/spec-distill/tests/test_web_kill_switch.sh 2>&1 | tail -1` · `bash plugins/spec-distill/tests/test_proceed_gate_adopters.sh 2>&1 | tail -1` · `bash plugins/spec-distill/tests/test_compression_adopters.sh 2>&1 | tail -1` · `bash plugins/spec-distill/tests/test_plain_gate_templates.sh 2>&1 | tail -1`(새 SKILL 을 도출 코퍼스에 넣는 락들)

한 번은 skill 펜스를 실제로 돌려 본다 — `SD` 를 이 worktree 의 `plugins/spec-distill` 절대경로로, `<root>` 를 worktree 루트로 바꿔 Bash 로 돌리면 지도 첫 줄이 `로드맵 상태 — ` 로 시작한다(실데이터).

- [ ] **Step 4: 커밋**

세 파일 pathspec 커밋. 메시지: `feat(spec-distill): 에픽 지도 진입 skill roadmap-status` + 트레일러 셋.

---

### Task 4: README 상태줄 설치 · 스위치 · 버전 · 측정

**Files:**
- Modify: `plugins/spec-distill/README.md` (`## 쓰는 법` · `## 로드맵 · 에픽 묶음` 아래 새 `### 상태줄` · `### 스위치 목록` · `## Principles Instantiated`)
- Modify: `plugins/spec-distill/CHANGELOG.md` · `plugins/spec-distill/.claude-plugin/plugin.json`
- Modify: `plugins/spec-distill/tests/test_control_plane.sh` (README 스크립트 절 — `finish` 앞)
- Modify: `docs/superpowers/plans/2026-10-15-roadmap-control-plane.md` (`## 측정`)

**Interfaces:**
- Consumes: `control_plane.py statusline`(Task 2), 진입 skill(Task 3).
- Produces: README 의 표시 줄 사이 실행 스크립트(`<!-- control-plane-statusline:begin -->` ~ `<!-- control-plane-statusline:end -->` 사이 첫 ```` ```sh ```` 펜스).

- [ ] **Step 1: 설치 사실을 다시 잰다**

`claude --version` 과 `grep -n -A3 '"spec-distill@' ~/.claude/plugins/installed_plugins.json` 을 돌려 `installPath` 줄의 모양(`"installPath": "<…>/spec-distill/<버전>"`)이 위 표의 실측과 같은지 본다. 다르면 멈추고 보고한다(스크립트의 grep 이 그 모양에 기댄다).

- [ ] **Step 2: 실패하는 테스트를 더한다** (계획이 쓴 테스트 코드 — 리뷰어 심사 대상)

`test_control_plane.sh` 의 마지막 `finish` 줄 바로 앞에 붙인다:

```bash
echo "=== README 상태줄 스크립트(AC9) ==="
README="$ROOT/plugins/spec-distill/README.md"
awk '/<!-- control-plane-statusline:begin -->/{f=1;next} /<!-- control-plane-statusline:end -->/{f=0} f&&/^```sh$/{b=1;next} f&&b&&/^```$/{exit} f&&b' "$README" > "$T/sl.sh"
[ -s "$T/sl.sh" ] && ok "README 에서 스크립트를 뽑았다" || no "README 표시 줄 사이에 sh 펜스가 없다"
assert_not_grep "$(cat "$T/sl.sh")" '[0-9]+\.[0-9]+\.[0-9]+' "스크립트에 버전 붙은 폴더가 박혀 있지 않다"
mkdir -p "$T/cfg-none"
out="$(cd "$W" && CLAUDE_CONFIG_DIR="$T/cfg-none" sh "$T/sl.sh" </dev/null)"; rc=$?
assert_eq "$out|$rc" "상태줄 꺼짐 — 플러그인을 못 찾음|0" "설치본이 없으면 꺼짐 문구(빈 줄 아님)"
mkdir -p "$T/cache/devbrew/spec-distill/9.9.9/scripts" "$T/cfg/plugins"
cp "$S/"*.py "$S/"*.json "$T/cache/devbrew/spec-distill/9.9.9/scripts/"
printf '{\n  "version": 2,\n  "plugins": {\n    "spec-distill@devbrew": [\n      {\n        "scope": "user",\n        "installPath": "%s/cache/devbrew/spec-distill/9.9.9",\n        "version": "9.9.9"\n      }\n    ]\n  }\n}\n' "$T" > "$T/cfg/plugins/installed_plugins.json"
out="$(cd "$W" && CLAUDE_CONFIG_DIR="$T/cfg" sh "$T/sl.sh" </dev/null)"
assert_contains "$out" "rm 외 1 · 설계 2" "installPath 의 control_plane.py 를 실행 때 찾아 부른다"
rm -f "$T/cache/devbrew/spec-distill/9.9.9/scripts/control_plane.py"
out="$(cd "$W" && CLAUDE_CONFIG_DIR="$T/cfg" sh "$T/sl.sh" </dev/null)"
assert_eq "$out" "상태줄 꺼짐 — 플러그인을 못 찾음" "installPath 에 control_plane.py 가 없으면(옛 버전) 꺼짐 문구"
for want in '"statusLine"' '이어 붙' 'spec-distill:statusline' '플러그인이 대신 켜 줄 수 없'; do
  assert_contains "$(cat "$README")" "$want" "README 에 '$want'"
done
```

Run: `bash plugins/spec-distill/tests/test_control_plane.sh 2>&1 | grep -E '✗|Total'` → 새 단언이 `✗`.

- [ ] **Step 3: README 를 고친다**

(a) `## 쓰는 법` 첫 줄 「사용자가 부르는 진입 skill 은 셋입니다.」를 「넷입니다.」로, 목록 끝에 한 줄:

```markdown
- `/roadmap-status` — 로드맵의 에픽 지도(단계 · 기다리는 에픽 · 경고 · 진행 중 인터뷰 조사 수)를 보고 싶을 때. 읽기만 합니다.
```

(b) `## 로드맵 · 에픽 묶음` 절 끝(`## Hooks Installed` 앞)에 새 하위 절:

````markdown
### 상태줄

에픽 단계 요약 · 경고 수 · 마지막 fetch 경과 · 진행 중 인터뷰 조사 수를 Claude Code 상태줄 한 줄로 늘 볼 수 있습니다. 예: `2026-10-11-persistent-explore-pm-decompose · 설계 2 · 구현 1 · 준비 3 · 경고 없음 · 받은 지 12분`. 자세히는 `/spec-distill:roadmap-status`, 지휘 세션의 작업 목록은 `python3 <플러그인>/scripts/control_plane.py show --tasks <로드맵>` 의 줄(`<제목>` 탭 `<pending|in_progress|completed|keep>`)로 맞춥니다.

플러그인이 대신 켜 줄 수 없습니다 — 메인 `statusLine` 은 사용자 · 프로젝트 설정만 정합니다. 직접 켭니다.

1. 아래 스크립트를 `~/.claude/devbrew-statusline.sh` 로 저장합니다. 버전 붙은 플러그인 폴더를 박아 두지 않고, 실행할 때마다 설치된 spec-distill 을 찾습니다(Claude Code 가 설치 기록 `plugins/installed_plugins.json` 의 `installPath` 에 적은 폴더 — 2026-10-15 · 2.1.299 실측). 못 찾으면 빈 줄이 아니라 `상태줄 꺼짐 — 플러그인을 못 찾음` 을 냅니다. 로드맵도 진행 중 인터뷰도 없으면 빈 줄입니다.

<!-- control-plane-statusline:begin -->
```sh
#!/bin/sh
d="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
p=$(grep -o '"installPath": *"[^"]*/spec-distill/[^"]*"' "$d/plugins/installed_plugins.json" 2>/dev/null | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/')
if [ -n "$p" ] && [ -f "$p/scripts/control_plane.py" ]; then
  exec python3 "$p/scripts/control_plane.py" statusline
fi
echo "상태줄 꺼짐 — 플러그인을 못 찾음"
```
<!-- control-plane-statusline:end -->

2. 사용자 설정 `~/.claude/settings.json` 에 넣습니다(devbrew 레포의 프로젝트 설정에는 커밋하지 않습니다):

```json
{ "statusLine": { "type": "command", "command": "sh ~/.claude/devbrew-statusline.sh" } }
```

이미 상태줄을 쓰고 있으면 기존 명령 뒤에 이어 붙입니다 — 상태줄 입력(JSON)을 두 명령에 똑같이 넘깁니다:

```sh
in=$(cat); a=$(printf '%s' "$in" | <기존 명령>); b=$(printf '%s' "$in" | sh ~/.claude/devbrew-statusline.sh); printf '%s  %s\n' "$a" "$b"
```

캐시는 `<git 공용 디렉토리>/devbrew/control-plane.json` 하나이고 레포 파일과 git 상태는 바꾸지 않습니다. 상태 계산이 실패하면 `검사 불가` 조각이 붙습니다 — 「없음」과 섞지 않습니다.
````

(c) `### 스위치 목록` 의 `DEVBREW_SPEC_DISTILL_DISABLE=1` 항목 둘째 줄의 「진입 skill 셋(`request-framing` · `spec-interview` · `spec-review`)」을 「진입 skill 넷(`request-framing` · `spec-interview` · `spec-review` · `roadmap-status`)」으로, 그 항목 뒤에 한 줄:

```markdown
- `DEVBREW_SKIP_HOOKS=spec-distill:statusline` (5.6.0) — 컨트롤 플레인(`scripts/control_plane.py`)을 끈다: 상태줄은 빈 줄, `/spec-distill:roadmap-status` 의 지도는 `꺼져 있다 — <스위치>` 한 줄, `show --tasks` 는 표준 출력을 비우고 rc 3. 훅이 아니지만 지목할 이름을 갖는다. `DEVBREW_SPEC_DISTILL_DISABLE=1` 도 같은 효과다.
```

(d) `## Principles Instantiated` 의 `### Three Laws` 목록 끝에 한 줄:

```markdown
- **Law 3 (컨트롤 플레인, 5.6.0)** — 에픽 단계 · 경고 · 받은 시각을 상태줄과 `roadmap-status` 가 늘 보여, 모르는 사이의 드리프트를 다음 세션이 아니라 지금 본다. 「없음」과 「확인 못 함」(`검사 불가` · `셀 수 없음`)을 섞지 않는다.
```

- [ ] **Step 4: 버전 · CHANGELOG**

`plugin.json` `"version": "5.6.0"`. `CHANGELOG.md` 맨 위(`# Changelog` 다음)에:

```markdown
## [5.6.0] — 2026-10-15

### Added
- `scripts/control_plane.py` — 로드맵 상태(`roadmap_status.py --json`)와 진행 중 인터뷰를 상태줄 한 줄(`statusline`) · 지도(`show`) · 작업 목록 줄(`show --tasks`)로 보인다. 결과는 `<git 공용 디렉토리>/devbrew/control-plane.json` 에 캐시하고(origin/main 커밋 · 브랜치 머리 · 로드맵 사본 · 인터뷰 상태 파일이 같으면 다시 계산하지 않는다), 받은 지 N분은 매번 `FETCH_HEAD` 에서 읽는다. 읽기만 한다.
- 진입 skill `roadmap-status`(`/spec-distill:roadmap-status [<로드맵 경로>]`) — 에픽 지도를 보인다. 블록 줄에 끝나지 않은 의존(`← 기다림: …`), 받드는 에픽 없는 발화 · 미배정 번호를 경고로 보인다.
- README 「상태줄」 — 버전 없는 상태줄 실행 스크립트와 설치 · 이어 붙이기 안내. 플러그인은 상태줄을 대신 켤 수 없다.
- 끄기 스위치 `DEVBREW_SKIP_HOOKS=spec-distill:statusline`.
```

- [ ] **Step 5: 통과를 본다**

Run: `bash plugins/spec-distill/tests/test_control_plane.sh 2>&1 | tail -1` → `Fail: 0`. 이어 `bash shared/tests/test_changelog_integrity.sh 2>&1 | tail -1` · `bash plugins/spec-distill/tests/test_readme_sync.sh 2>&1 | tail -1` · `bash plugins/spec-distill/tests/test_no_wall_clock.sh 2>&1 | tail -1` · `bash shared/tests/test_python_floor.sh 2>&1 | tail -1` · `bash shared/tests/test_plugin_description_parity.sh 2>&1 | tail -1` · `bash shared/tests/test_invocation_surface.sh 2>&1 | tail -1` — 모두 Fail 0.

진짜 설치본으로 한 번: README 스크립트를 `$TMPDIR` 에 뽑아 `CLAUDE_CONFIG_DIR` 없이 돌린다 — 설치된 5.3.0 에는 `control_plane.py` 가 없으므로 `상태줄 꺼짐 — 플러그인을 못 찾음` 이 나와야 한다(실환경의 못 찾음 분기).

- [ ] **Step 6: 실데이터 시간을 재 이 계획에 적는다(AC10)**

`~/.claude/sdd-mirror/r6-impl/measure.sh` 를 써서 돈다 — worktree 루트에서 `git fetch origin` 한 번 뒤, (a) 캐시 없음: 매번 `<git 공용 디렉토리>/devbrew/control-plane.json` 을 지우고 `python3 plugins/spec-distill/scripts/control_plane.py statusline </dev/null` 를 `/usr/bin/time -p` 로 세 번, (b) 캐시 맞음: 지우지 않고 세 번. 공용 디렉토리는 `git -C <worktree> rev-parse --git-common-dir` 로 얻는다. 각 중앙값(`real`)과 상태줄 출력 한 줄을 이 계획의 `## 측정` 절에 적는다(`(Task 4 가 채운다.)` 를 바꾼다): `- 2026-10-15 · 이 worktree(로드맵 1개) · 캐시 없음 중앙값 <a>초 · 캐시 맞음 중앙값 <b>초 · 출력 \`<줄>\``. b < a 가 아니면 멈추고 보고한다.

- [ ] **Step 7: 커밋**

다섯 파일 pathspec 커밋. 메시지: `feat(spec-distill): 상태줄 설치 안내 · 스위치 공시 · 5.6.0` + 트레일러 셋.

---

## Self-Review 기록

- 설계 대조: §1-1(읽는 것 · 맨 위 경고) → Task 1 `TOP_WARNINGS` · Task 2 `read_interviews`/`run_status`. §1-2(고르기 · origin/main 사본 · 인자) → Task 2 `candidates`/`gather`. §1-3(상태줄 · 로드맵 없음 · 인터뷰만) → Task 1 `statusline_text`. §1-4(지도 · 기다림 · 판정 줄) → Task 1 `show_text`. §1-5(`keep` · 3 이면 빈 출력) → Task 1 `tasks_output` · Task 2 rc. §1-6(캐시 키 넷 · 원자적 쓰기 · 사유 한 줄) → Task 2. §1-7(받은 시각 캐시 밖) → Task 2 `fetch_stamp` · AC13 케이스. §1-8(읽기 전용 · `-I` 없음) → Task 2 git 허용 목록 · AC7. §2-1 → Task 3. §2-2 → Task 4. §2-3 → 「후속」. §2-4 → Task 2 `switch_name` · Task 4 공시. AC1~AC13 → 각 Task 의 단언(AC8 = Task 3, AC9 = Task 4 Step 2, AC10 = Task 4 Step 6, AC12 = Task 4 Step 4).
- 자리표 없음 확인: 「(Task 4 가 채운다.)」는 Task 4 Step 6 이 채우는 측정 자리이고 그 Step 이 문구를 정한다.
- 이름 일치: `statusline_text` · `show_text` · `tasks_output` · `first_line` · `failed_report` · `parse_interview_state` · `gather` · `cached_view` · `cache_key` · `cache_file` · `switch_name` — Task 1 정의와 Task 2 사용이 같다. 변이가 무는 글자 여섯은 Task 2 코드에 한 번씩 있다.
