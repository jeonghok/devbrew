# R3 번호 인계 · 대조 · 깊이 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** brief · 에픽 묶음의 모든 번호가 설계문서 · 계획 · 구현까지 가고, 빠지거나 얕거나 미뤄지면 경고된다.

**Architecture:** 번호 문법 · 로드맵 해석 · brief 번호 계산을 새 공유 모듈 `roadmap_model.py` 로 옮기고, `check_bundle_coverage.py` 가 그 위에 자리 확인(얕음) · 기각 에픽 확인 · 받드는 에픽 없는 발화 · brief 입력 · `--plan` · `--impl` 을 더한다. `roadmap_status.py` 는 설계문서 `## 미룸` 의 받는 곳 없는 행을 경고한다. spec-review 는 새 스크립트 `spec_review_bundle.py` 로 `--bundle` 을 확인하고 진입 대조 · 승인 때 로드맵 위치와 이웃 결정을 보인다. 넘김 글(brief 다음 세션 줄 · 새 에픽 넘김 줄 · spec-review 다음 세션 줄)은 덮어쓰기 문장을 빼고 번호째 읽기 · `--bundle` · `--plan` · `--impl` 지시를 싣는다.

**Tech Stack:** Python 3.9 (스크립트 · 표준 라이브러리만), bash 3.2 락 테스트(`shared/tests/assert.sh`), Markdown skill/reference.

**Spec:** `docs/superpowers/specs/2026-10-15-numbered-handoff-coverage-design.md` (레포 상대경로). 실행자는 계획과 설계문서를 함께 읽는다.

## 목차

- [Global Constraints](#global-constraints) · [Review Focus](#review-focus) · [설계와 다르게 · 더 정한 것](#설계와-다르게--더-정한-것-사용자에게-보고)
- [Task 1 — 공유 모듈 `roadmap_model.py`](#task-1-공유-모듈-roadmap_modelpy)
- [Task 2 — 번호 대조: 자리 · 기각 에픽 · 받듦 · brief 입력](#task-2-번호-대조-자리--기각-에픽--받듦--brief-입력)
- [Task 3 — `--plan` · `--impl` · `## 미룸` 표](#task-3---plan----impl----미룸-표)
- [Task 4 — `roadmap_status.py` 의 미룸 경고](#task-4-roadmap_statuspy-의-미룸-경고)
- [Task 5 — brief 다음 세션 줄 · 에픽 넘김 줄](#task-5-brief-다음-세션-줄--에픽-넘김-줄)
- [Task 6 — `spec_review_bundle.py`](#task-6-spec_review_bundlepy)
- [Task 7 — spec-review SKILL 배선 · writing-plans 다음 세션 줄](#task-7-spec-review-skill-배선--writing-plans-다음-세션-줄)
- [Task 8 — design-doc 프로필의 정답 출처 모드](#task-8-design-doc-프로필의-정답-출처-모드)
- [Task 9 — README · CHANGELOG · 버전](#task-9-readme--changelog--버전)
- [Task 10 — 끝에서 끝 · 실데이터 · 스위트 비교](#task-10-끝에서-끝--실데이터--스위트-비교)

## Global Constraints

- 모든 경로는 worktree 절대경로 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-afc055cc240cbc3a5` 아래다. main 레포(`/Users/jeonghokim/Downloads/devbrew/plugins/...`)나 다른 worktree 의 같은 이름 파일을 고치지 않는다.
- 구현 커밋 메시지: 설명은 한국어, `type(scope)` 는 영어(예 `feat(spec-distill): …`). 끝에 트레일러 세 줄 —
  `Spec: docs/superpowers/specs/2026-10-15-numbered-handoff-coverage-design.md` ·
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` ·
  `Claude-Session: https://claude.ai/code/session_01XKSh1VvN6kYTmLJS675MgX`.
- 커밋은 pathspec 으로 한다(`git -C <worktree> add <파일들>` 뒤 커밋) — `git add -A` · `git add .` 금지.
- 이 worktree 세션의 Bash 가드는 git 이 섞인 복합 명령(`cd … && git …`, `$(git …)`)을 거부한다. git 은 `git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-afc055cc240cbc3a5 …` 한 줄씩. 여러 단계 스크립트는 `~/.claude/sdd-mirror/r3-impl/<task 이름>/` 아래 자기 하위 폴더에 써서 `bash <파일>` 로 돌린다. 공유 tmp 를 glob 으로 지우지 않는다.
- Bash 도구 셸은 zsh 다(`PIPESTATUS` 없음). `.sh` 테스트는 macOS bash 3.2 로 돈다 — `$var` 바로 뒤에 한글 · 전각 글자를 붙이지 말고 `${var}` 로 쓴다. 손으로 `\uXXXX` 이스케이프를 쓰지 않는다.
- 파이썬은 3.9 문법만. 스크립트(`plugins/*/scripts/*.py`)에서 파일을 열 때 `encoding="utf-8"` 를 명시하고, `"python3"` 리터럴을 쓰지 않는다. 셸 안 인라인 python 은 `python3 -I`(테스트의 `cd "$S" && python3 -c 'import …'` 처럼 스크립트 폴더 import 가 필요한 곳은 예외 — 기존 테스트 관행), 스크립트 호출에는 `-I` 를 쓰지 않는다.
- `plugins/spec-distill/scripts/*.py` 의 모듈 수준 `re.compile` 리터럴이 `## 6. 사용자 원문` 맨 앞을 3글자 이상 맞으면 `test_check_brief.sh` 가 RED 다 — 제목은 문자열 메서드로 찾고, §6 은 `section6.body` 로만 읽는다.
- 20줄(200자 이상) 같은 블록이 `plugins/*` · `shared/*` 두 파일에 있으면 `shared/tests/test_no_new_duplication.sh` 가 RED 다. 픽스처 글은 다른 테스트의 것과 문장을 다르게 쓴다.
- 새 셸 테스트는 `chmod +x` 하고 커밋 뒤 `git -C <worktree> ls-files -s <파일>` 이 `100755` 인지 본다. `# guards:` 머리를 달면 `--emit-scanned` 에 답해야 한다.
- 테스트 실행 · 변이 검증에는 `PYTHONDONTWRITEBYTECODE=1`. 변이 전에 커밋하고, 변이는 언제나 `$T` 아래 사본에서 한다(작업 트리 파일을 고치지 않는다). 변이 사본 폴더에는 `roadmap_model.py` · `section6.py` · `check_bundle_coverage.py` · `roadmap_status.py` 를 함께 둔다(import 사슬).
- 셸 테스트는 리포 루트에서 `bash plugins/spec-distill/tests/<이름>.sh` 로 돌린다. 실패 줄은 `  ✗ ` 로 시작한다. 각 Task 끝에 그 Task 가 닿은 테스트 파일 전부와 `shared/tests/test_no_new_duplication.sh` · `plugins/spec-distill/tests/test_check_brief.sh` 를 돌린다.
- 기준선(작업 전 실패 «이름» 집합)은 `~/.claude/sdd-mirror/r3-impl/baseline-before.txt` — 선재 RED 둘: `test_hook_output_schema.py test_python_and_bash_resolvers_agree` · `test_review_hook_removed.py test_no_identifier_residue`(main 의 `roadmap.md:166` 의 `review-dispatch`, R3 와 무관). 전체 비교는 `bash ~/.claude/sdd-mirror/r3-impl/run_suite.sh <출력 파일>`.
- 넘김 줄(다음 세션 줄 · 에픽 넘김 줄)의 인용 줄 안에는 백틱을 넣지 않는다(바깥 인라인 코드가 깨진다). 줄 안의 꺾쇠 자리표는 줄 앞 `@<…>` 토큰의 이름만 쓴다(spec-interview · spec-review 줄). 실행 시점에 정해지는 경로(설계문서 · 계획 · 보고 파일)는 꺾쇠 없이 말로 쓴다 — 규칙 5 가 「치환하지 않은 자리표가 남으면 노출하지 않는다」이기 때문이다.
- 버전은 Task 9 에서 `plugins/spec-distill` minor 를 올린다(main 5.5.0 → 5.6.0). 병렬 에픽이 먼저 머지되면 머지 직전에 번호를 다시 정한다 — PR 본문에 적는다.
- `references/reviewing-document.md` · `shared/docreview/` 의 codex 러너 · spec-review 의 dispatch 블록 둘(`Agent({...})`)은 바꾸지 않는다(R2a 예약, AC13).

## Review Focus

1. **같은 파일을 다른 표기로 준 `--bundle`** — `@docs/…` · `./docs/../docs/…` · 절대경로 · 따옴표 친 `source_interview: "docs/…"` 가 모두 같은 파일로 통과해야 하고, 다른 묶음은 거부돼야 한다. → Task 6 의 entry 케이스 다섯.
2. **`AC1` 과 `AC10`, 펜스 안의 `### §2`** — 자리 토큰이 낱말 경계 없이 맞거나 펜스 안 제목을 절로 세면 얕은 답을 놓친다. → Task 2 의 loc 픽스처(AC1 행 · §2 행), Task 3 의 `--plan` 경계 케이스.
3. **로드맵을 찾지 못한 묶음** — 종료 코드는 0 이어도 첫 줄이 「셀 수 없음 N개」를 반드시 말해야 한다(조용한 0 금지). → Task 2 의 lone 케이스.
4. **`## 미룸` 이 없음 · 「없음」 한 줄 · 깨진 표 · 백틱 친 받는 곳** — 앞의 둘은 0행, 깨진 표는 「셀 수 없음」(roadmap_status rc 3 · `--impl` rc 3), 백틱은 벗겨 읽는다. → Task 3 · Task 4 케이스.
5. **비UTF-8 로캘(`LC_ALL=C`)** — 새 하위 명령들도 한국어 출력이 깨지거나 죽지 않아야 한다(`sys.stdout.reconfigure(encoding="utf-8")`). → Task 3 · Task 6 의 `LC_ALL=C` 케이스.

## 설계와 다르게 · 더 정한 것 (사용자에게 보고)

설계문서의 `### Deferred to plan` 여섯 건과 계획이 정할 일을 이렇게 닫는다. 결정 기록(B1~B12 · D2.1~D2.3)은 바꾸지 않는다.

| 항목 | 이 계획의 처리 |
|---|---|
| 자리 표기 정규식 · 제목 낱말(Deferred 1) | `§<n>` · `§<n>-<m>` 은 `§(\d+)(?:-(\d+))?(?!\d)`, `§<n>` 은 펜스 밖 `### §<n>` 제목, `-<m>` 은 그 절 안의 `m. ` 로 시작하는 줄. `AC<n>` 은 `(?<![A-Za-z0-9])AC(\d+)(?!\d)` 이고 `## Acceptance Criteria` 의 항목 머리(`- AC1` · `- AC1.` · `- **AC1**`)에 있어야 한다. 제목 낱말은 펜스 밖 `## ` 제목 전체와 ` / ` · ` · ` 로 나눈 조각(`## 번호 대조` 제외)이고 칸 안에서 글자 · 숫자 경계로 맞춘다. 실데이터(R0 · R1 · R7)는 Task 10 이 재서 보고한다 |
| brief 번호 계산 함수의 자리(Deferred 2) | 새 `scripts/roadmap_model.py` — 번호 문법(`parse_ids` · `frontmatter` · `section_body` …) · `parse_roadmap` · `collect_assigned`(build 의 묶음 읽기 루프) · `brief_universe`. 두 스크립트가 import 하고 이 모듈은 둘 다 import 하지 않는다. 옛 이름은 두 스크립트에서 다시 내보낸다(기존 테스트의 `c.section_body` · `rs.parse_roadmap` 이 그대로 돈다) |
| `--impl` 보고 파일의 자리(Deferred 3) | 넘김 줄이 「git 이 추적하지 않는 파일에 적는다」고 시킨다(SDD 작업 공간 등 — 외부 skill 의 폴더 이름을 가정하지 않는다). 형식은 `AC<n>: 구현됨|미룸|빠짐 — <한 줄>` 한 줄씩, 앞의 `- ` · `* ` 는 허용 |
| spec-review SKILL 줄 예산 · 게이트 앞 순서(Deferred 4) | spec-review SKILL 에는 줄 상한 락이 없다. 판정 로직은 `spec_review_bundle.py` 로 빼고 SKILL 에는 펜스 둘(진입 · 로드맵 위치)과 문장 넷만 더한다. 게이트 앞 순서: 엔진 렌더 첫 줄 → 번호 대조 줄 → advisory 목록(2단계) → 로드맵 위치 · 이웃 결정 → 질문 |
| N17 — 배정만으로 받듦을 세는 문제(Deferred 5) | 받듦 = 다른 블록에 배정됐고, **그 블록의 작업 트리 설계문서가 그 S 를 「기각」하지 않았다.** 설계문서가 아직 없거나 표를 못 읽으면 배정이 받듦이다. `roadmap_status.py` 의 고아 발화 계산은 바꾸지 않는다 |
| N18 — 「기각」 행을 덮음으로 셀지(Deferred 6) | 「기각」 행은 덮은 것으로 센다(빠진 번호 아님 — rc 1 이 아니다). 대신 기각 이유의 에픽 번호는 로드맵에 있어야 하고(없으면 얕음), 기각한 S 는 받드는 블록이 있어야 한다(없으면 받드는 에픽 없는 발화). 둘 다 rc 를 바꾸지 않는 경고다(D2.2) |
| brief 입력의 기각 에픽 확인 | brief 흐름에는 로드맵이 없으므로 §2-2 · §2-3 둘 다 하지 않는다(셀 수 없음으로도 세지 않는다 — 없는 것을 셀 수는 없다) |
| 로드맵 찾기 | 명령줄에서는 묶음 파일의 디렉토리부터 위로 올라가며 `<조상>/<묶음 roadmap: 값>` 이 파일인 첫 조상을 레포 루트로 쓴다. 못 찾으면 그 검사만 「셀 수 없음」 |
| 셀 수 없음의 단위 | 번호마다 한 항목(`S7 — <사유>`). 로드맵이 없을 때 기각 행에 에픽 번호가 있으면 그 행의 번호 전부, 없으면 그 행의 S 만 |
| `--impl` 종료 코드 | 0 경고 없음 · 1 경고 있음 · 3 검사 불가(AC 절 없음 · 보고 줄 형식 밖 · 같은 AC 두 번 · `## 미룸` 표 깨짐 · 파일 못 읽음). 넘김 줄은 경고를 보이라고만 하고 막지 않는다. 경고는 넷 — 보고에 없는 AC · 미룸/빠짐인데 `## 미룸` 에 없음 · 받는 곳이 `없음` · 빠짐 |
| 다음 세션 줄의 꺾쇠 락 | `test_next_session_command.sh` · `test_review_handoff_order.sh` 의 「꺾쇠 자리표는 줄 앞 토큰에만」을 「줄 안의 꺾쇠 자리표는 줄 앞 `@<…>` 토큰의 이름만」으로 바꾼다 — `--bundle <brief-path>` 는 같은 자리표라 함께 치환된다. 모르는 이름(`<x>`)은 여전히 RED(합성 양성 대조) |
| finishing.md 줄의 플러그인 경로 | reference 는 `${CLAUDE_PLUGIN_ROOT}` 가 치환되지 않은 채 읽힌다 — 노출 전에 플러그인 절대경로로 바꾸라는 문장을 줄 아래 치환 규칙에 더한다. spec-review SKILL 본문의 줄은 하니스가 치환한다 |
| 에픽 넘김 줄의 자리표 | `<bundle-abs>`(첨부 · 절대경로) · `<bundle-rel>`(`source_interview` · `--bundle`, 레포 루트 기준 — `roadmap_status.py` 의 spec 찾기가 이 글자로 맞춘다) · `<roadmap-rel>` · `<epic-id>`. 표지는 `**에픽 넘김 줄**`(spec-interview 표지와 다르다 — 채택자 락에 들지 않는다). 고아 reference 락 때문에 `finishing.md` 가 이 파일을 `${CLAUDE_PLUGIN_ROOT}/references/epic-handoff.md` 로 가리킨다 |
| `proceed-gate.md` | 바꾸지 않는다 — 규칙 5 는 「모든 자리표를 치환한 뒤 노출」이고 같은 자리표를 두 번 쓰는 것을 막지 않는다 |
| 로드맵 지휘 절차(Files to Modify 마지막 줄) | 이 PR 밖 — 로드맵 수정 PR(지휘 절차 6)로 미룬다. 받는 곳: 로드맵 PR. 이 브랜치 마무리에서 설계문서 `## 미룸` 에 올린다 |
| R3 설계문서 자신의 `## 미룸` | 브랜치 마무리(PR 전)에 이 계획의 미룸 · 최종 리뷰의 미룸 · 빠짐을 올리고, 이 에픽 자신의 `--impl` 로 대조한다(Task 10 · 마무리) |

---

### Task 1: 공유 모듈 `roadmap_model.py`

순수 이동이다 — 동작이 바뀌면 안 된다. 기존 스위트(`test_bundle_coverage.sh` · `test_roadmap_status.sh`)가 그대로 녹색이어야 한다.

**Files:**
- Create: `plugins/spec-distill/scripts/roadmap_model.py`
- Modify: `plugins/spec-distill/scripts/check_bundle_coverage.py` (번호 문법 정의를 옮기고 다시 내보냄)
- Modify: `plugins/spec-distill/scripts/roadmap_status.py` (로드맵 해석 · brief 번호 계산 · 묶음 읽기 루프를 옮김)
- Test: `plugins/spec-distill/tests/test_bundle_coverage.sh` (변이 사본 폴더 · 새 단언), `plugins/spec-distill/tests/test_roadmap_status.sh` (변이 사본 폴더 · 정적 검사 대상)

**Interfaces:**
- Produces (`roadmap_model`): `FormatError` · `TOKEN_RE` · `SEP_RE` · `SEP_CELL_RE` · `PREFIX_ORDER` · `parse_ids(cell)->list` · `id_sort_key(token)` · `frontmatter(text)->dict` · `unquote(value)->str` · `section_body(text, heading)->str|None` · `bundle_ids(text)->list` · `split_list(value)->list` · `parse_roadmap(text)->(meta, blocks, records, risk_rows, errors)` · `brief_universe(brief, audit)->(non_s, s_ids, k_expected)` · `collect_assigned(blocks, meta, roadmap_rel, read, exists)->(bundles: dict, union: set, errors: list)`. 블록 dict 의 키(`id` · `title` · `fields` · `kind` · `deps` · `reserved` · `assigned`)는 지금 그대로.
- `check_bundle_coverage` 는 위 이름을 `from roadmap_model import …` 로 받아 모듈 속성으로 다시 내보낸다. `roadmap_status` 는 `parse_roadmap` · `brief_universe` · `overlaps` · `_reserves` 를 모듈 속성으로 계속 갖는다.

- [ ] **Step 1: 실패하는 테스트 — 공유 모듈 단언을 `test_bundle_coverage.sh` 끝(`finish` 앞)에 더한다** *(계획이 쓴 테스트 코드 — 리뷰어는 이것도 검사한다)*

```bash
# 10. 공유 모듈(R3 §2-5) — 두 스크립트가 같은 함수를 쓰고 순환 import 가 없다
out="$(cd "$S" && python3 -c '
import roadmap_model as m, check_bundle_coverage as c, roadmap_status as r
print(c.section_body is m.section_body, c.frontmatter is m.frontmatter,
      r.parse_roadmap is m.parse_roadmap, r.brief_universe is m.brief_universe)' 2>&1)"
assert_eq "$out" "True True True True" "공유 모듈: 두 스크립트가 roadmap_model 의 같은 함수를 쓴다"
assert_file_absent "$C" '^(import|from) roadmap_status' "check_bundle_coverage 는 roadmap_status 를 import 하지 않는다"
assert_file_absent "$S/roadmap_model.py" '^(import|from) (check_bundle_coverage|roadmap_status)' "roadmap_model 은 두 스크립트 어느 쪽도 import 하지 않는다(순환 없음)"
```

- [ ] **Step 2: 실패 확인** — `bash plugins/spec-distill/tests/test_bundle_coverage.sh` → 새 단언 RED(`ModuleNotFoundError: roadmap_model`).

- [ ] **Step 3: `roadmap_model.py` 를 만든다** — 머리는 아래 그대로, 몸통은 **글자 그대로 옮긴다**:

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_model.py — 번호 문법 · 로드맵 해석 · 블록별 배정 번호 · brief 번호 집합.

`check_bundle_coverage.py` 와 `roadmap_status.py` 가 함께 쓴다. 이 모듈은 둘 중 어느 것도 import 하지
않는다(순환 없음). 읽기만 한다 — 파일을 쓰지 않고 git · 네트워크를 부르지 않는다.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import section6  # noqa: E402
```

  - `check_bundle_coverage.py` 에서 옮길 것(글자 그대로): 주석 두 줄과 `TOKEN_RE` · `SEP_RE` · `SEP_CELL_RE` · `PREFIX_ORDER`, `class FormatError`, `parse_ids`, `id_sort_key`, `frontmatter`, `unquote`, `_heading_indexes`, `section_body`, `bundle_ids`. (`TABLE_HEADING` · `_cells` · `table_ids` · `check` · `render` · `main` 은 남는다.)
  - `roadmap_status.py` 에서 옮길 것(글자 그대로): `FIELDS` · `REQUIRED` · `FORBIDDEN` · `RISK_PREFIXES` · `BLOCK_HEAD_RE` · `BLOCK_ID_RE` · `BUNDLE_NAME_RE` · `RISK_ROW_RE` · `DATE_RE` · `ID_ITEM_RE` · `OQ_LINE_RE` · `RC_RE` · `ST_RE` · `KEY_RE` · `S_ANCHOR_RE` · `LIST_SEP_RE`, `split_list`, `parse_roadmap`, `_validate_block`, `_cycles`, `brief_universe`. (`MAIN_REF` · `GIT_ALLOWED` · `NOTICE` · `SHARED_BASENAMES` · `TASK_STATUS` · `DONE` · `MERGE_MSG_RE` · `BACKTICK_RE` · `Git` · `Source` · `_reserves` 이하는 남는다.)
  - 새 함수(파일 끝) — `build` 의 묶음 읽기 루프를 그대로 옮긴 것:

```python
def collect_assigned(blocks: list, meta: dict, roadmap_rel: str, read, exists):
    """묶음 블록의 `assigned` 를 그 묶음 `ids:` 로 채운다. 반환 (bundles, union, errors).

    bundles 는 블록 번호 → 묶음 글(못 읽으면 None), union 은 모든 블록의 배정 번호 합집합,
    errors 는 형식 깨짐 사유들. read(path) 는 글 또는 None, exists(path) 는 참/거짓 — 경로는 로드맵과
    같은 기준(레포 상대)이다.
    """
    roadmap_dir = roadmap_rel.rsplit("/", 1)[0] if "/" in roadmap_rel else "."
    bundles, union, errors = {}, set(), []
    for b in blocks:
        if b["kind"] != "bundle":
            union.update(b["assigned"])
            continue
        bpath = roadmap_dir + "/" + b["fields"]["묶음"]
        btext = read(bpath)
        bundles[b["id"]] = btext
        if btext is None:
            if exists(bpath):
                errors.append("%s 묶음을 읽지 못했다: %s" % (b["id"], bpath))
            continue
        fm = frontmatter(btext)
        bad = [k for k, want in (("type", "epic-bundle"), ("epic", b["id"]),
                                 ("roadmap", roadmap_rel), ("source_brief", meta.get("source_brief")))
               if unquote(fm.get(k, "")) != want]
        try:
            if bad:
                raise FormatError("frontmatter 가 맞지 않는다: %s" % " · ".join(bad))
            b["assigned"] = bundle_ids(btext)
        except FormatError as exc:
            errors.append("%s 묶음 — %s" % (b["id"], exc))
            continue
        union.update(b["assigned"])
    return bundles, union, errors
```

- [ ] **Step 4: `check_bundle_coverage.py` 머리를 바꾼다** — 옮긴 정의를 지우고 `import re` 아래에 넣는다(`re` 는 이 Task 에서 쓰지 않아도 Task 2 가 쓴다 — 지금 쓰지 않으면 `import re` 를 지워도 된다):

```python
sys.path.insert(0, str(Path(__file__).resolve().parent))
from roadmap_model import (  # noqa: E402,F401 — 이 이름들은 이 모듈의 공개 표면이기도 하다
    FormatError, PREFIX_ORDER, SEP_CELL_RE, SEP_RE, TOKEN_RE, bundle_ids, frontmatter,
    id_sort_key, parse_ids, section_body, unquote)
```
  (`from pathlib import Path` 를 import 줄에 더한다. docstring 의 「`roadmap_status.py` 는 `check(bundle_text, spec_text)` 를 import …」 줄은 둔다.)

- [ ] **Step 5: `roadmap_status.py` 를 바꾼다**
  - import 를 다음으로 바꾼다(`import section6` 줄은 지운다 — 더 이상 쓰지 않는다):

```python
sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_bundle_coverage import check  # noqa: E402
from roadmap_model import (  # noqa: E402,F401 — 테스트가 rs.parse_roadmap · rs.brief_universe 로 부른다
    FormatError, brief_universe, collect_assigned, frontmatter, id_sort_key, parse_ids,
    parse_roadmap, section_body, split_list, unquote)
```
  - `build` 안의 `bundles, union = {}, set()` 부터 `union.update(b["assigned"])` 로 끝나는 루프 전체를 아래로 바꾼다(`roadmap_dir = …` 줄은 남긴다 — `compute` 에 넘긴다):

```python
    roadmap_dir = rel.rsplit("/", 1)[0] if "/" in rel else "."
    bundles, union, errs = collect_assigned(blocks, meta, rel, src.read, src.exists)
    report["format_errors"].extend(errs)
    if report["format_errors"]:
        return report
```

- [ ] **Step 6: 변이 사본 폴더를 고친다** — import 사슬에 `roadmap_model.py` 가 들었다.
  - `test_bundle_coverage.sh` 9번: `cp "$S/section6.py" "$T/" 2>/dev/null` → `cp "$S/section6.py" "$S/roadmap_model.py" "$T/" 2>/dev/null`.
  - `test_roadmap_status.sh` 6번: `cp "$S/section6.py" "$S/check_bundle_coverage.py" "$M/"` → `cp "$S/section6.py" "$S/check_bundle_coverage.py" "$S/roadmap_model.py" "$M/"`.
  - `test_roadmap_status.sh` 5번 정적 검사: `out="$(static_check "$RS" "$S/check_bundle_coverage.py")"` → `out="$(static_check "$RS" "$S/check_bundle_coverage.py" "$S/roadmap_model.py")"`, 기대값 `CHECKED 2` → `CHECKED 3`, 메시지 「두 스크립트」 → 「세 스크립트」.

- [ ] **Step 7: 통과 확인** — `PYTHONDONTWRITEBYTECODE=1 bash plugins/spec-distill/tests/test_bundle_coverage.sh` · `… test_roadmap_status.sh` · `… test_check_brief.sh` · `bash shared/tests/test_no_new_duplication.sh` 전부 실패 0. `test_bundle_coverage.sh` 9번 변이 단언(「status 를 0 으로 고정하면 … rc 0」)이 여전히 통과하는지 본다(사본 폴더 누락이면 rc 1 이 아니라 import 오류로 엉뚱하게 통과/실패한다 — 출력에서 「변이 적용됨」과 함께 본다).

- [ ] **Step 8: 커밋** — `refactor(spec-distill): 번호 문법 · 로드맵 해석을 공유 모듈 roadmap_model 로 옮김` (트레일러 셋).

---

### Task 2: 번호 대조 — 자리 · 기각 에픽 · 받듦 · brief 입력

설계 §2 · AC3~AC7 · AC15(AC3 변이). 종료 코드의 뜻은 그대로(0 · 1 · 3), 새 검사는 rc 를 바꾸지 않는 경고 줄이다.

**Files:**
- Modify: `plugins/spec-distill/scripts/check_bundle_coverage.py`
- Test: `plugins/spec-distill/tests/test_bundle_coverage.sh`

**Interfaces:**
- Consumes: Task 1 의 `roadmap_model` 이름들, `collect_assigned`, `parse_roadmap`, `brief_universe`.
- Produces:
  - `class Repo(root)` — `.read(rel)->str|None` · `.exists(rel)->bool` · `.specs_for(source_rel)->list[(rel, text)]`.
  - `find_repo(bundle_path, roadmap_rel)->Repo|None`.
  - `table_rows(spec_text)->list[(ids: list, verb: str, cell: str)]` (FormatError 는 지금 `table_ids` 와 같다), `table_ids(spec_text)->set` (그대로).
  - `acceptance_ids(spec_text)->list[str]|None` (예 `["AC1", "AC2"]`, 절 없으면 None).
  - `check(bundle_text, spec_text, *, audit_text=None, repo=None)->dict` — 키 `status · mode("bundle"|"brief"|None) · missing · extra · shallow[{id, reason}] · unserved · unknown · bundle_count · table_count · reason`.
  - `coverage(first_path, spec_path)->dict` (파일 읽기 + brief 면 audit, 묶음이면 `find_repo` → `check`).
  - `render(result)->str`, `warning_count(result)->int` (status 3 이면 1, 아니면 missing+shallow+unserved+unknown 개수).
  - `AC_TOKEN_RE` · `SEP_CELL_RE` · `_cells` · `_read(path)->(text|None, exc|None)` — Task 3 이 쓴다.

- [ ] **Step 1: 기존 픽스처를 새 규칙에 맞춘다** — `table_spec()` 의 printf 첫 줄에서 `# 설계\n\n` 다음에 `### §1 설계\n\n- 하나\n\n` 를 넣는다(행들이 `§1` 을 가리키므로, 없으면 전부 얕음이 되어 1번의 「빠진 번호 없음 (…)」 줄이 첫 줄에서 사라진다). 2번 단언 `"빠진 번호 3개 — RC4 · ST1 · «web-key»"` 는 둘째 줄로 그대로 남는다.

- [ ] **Step 2: 실패하는 테스트를 더한다** — `test_bundle_coverage.sh` 의 Task 1 단언 뒤, `finish` 앞 *(계획이 쓴 테스트 코드 — 리뷰어는 이것도 검사한다)*:

```bash
# ── 11~16: R3 §2 — 자리 · 기각 에픽 · 받듦 · 셀 수 없음 · brief 입력 · 출력 ─────────
R="$T/repo"; mkdir -p "$R/docs/x" "$R/docs/superpowers/specs"
cat > "$R/docs/x/roadmap.md" <<'MD'
---
type: roadmap
source_brief: docs/x/brief.md
---

# 대조 로드맵

## 에픽

### R9 — 이 에픽
- 의도: 아홉
- 범위: 아홉
- 의존: 없음
- 브랜치: feature/r9
- 묶음: R9.md
- 경로 예약: 없음

### R8 — 이웃 에픽
- 의도: 여덟
- 범위: 여덟
- 의존: 없음
- 브랜치: feature/r8
- 묶음: R8.md
- 경로 예약: 없음

### P1 — 묶음 없는 블록
- 의도: 하나
- 범위: 하나
- 의존: 없음
- 브랜치: feature/p1
- 묶음: 없음
- 경로 예약: 없음
- spec: docs/superpowers/specs/p1-design.md
- 발화: S5
- 항목: C5
MD
mkbundle() {  # mkbundle <에픽> <ids>
  printf -- '---\ntype: epic-bundle\nepic: %s\nroadmap: docs/x/roadmap.md\nsource_brief: docs/x/brief.md\nids: [%s]\n---\n\n# %s 묶음\n' "$1" "$2" "$1" > "$R/docs/x/$1.md"
}
mkbundle R9 "C1, D2, S7, S8, S9"
mkbundle R8 "S8, S9"
# R8 의 설계문서는 S9 를 기각한다 — 배정만으로는 받듦이 아니다(N17)
printf -- '---\nsource_interview: docs/x/R8.md\n---\n\n# R8 설계\n\n## Goals\n\n- 이웃\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| S8 | 반영 | Goals |\n| S9 | 기각 | 범위 밖 |\n' > "$R/docs/superpowers/specs/r8-design.md"
r9_design() {  # r9_design <표 행들 — printf %b 로 푼다> — R9 설계문서를 낸다
  printf -- '---\nsource_interview: docs/x/R9.md\n---\n\n# R9 설계\n\n## Goals\n\n- 목표\n\n## 설계\n\n### §1 첫 절\n\n1. 하나\n2. 둘\n\n```\n### §2 펜스 안 제목\n```\n\n## Acceptance Criteria\n\n- **AC10** 열째\n- AC2. 둘째\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n'
  printf '%b' "$1"
  printf '\n## Metadata\n\n- 끝\n'
}
jget() {  # jget <json 문자열> <파이썬 식 — r 이 결과>. 식은 이 테스트가 쓴 고정 문자열뿐이다.
  J="$1" python3 -I -c 'import json, os, sys; r = json.loads(os.environ["J"]); print(eval(sys.argv[1]))' "$2"
}

# 11. 자리 확인(AC3) — §n-m · ACn(낱말 경계) · 펜스 안 제목 · 제목 낱말
r9_design '| C1 | 반영 | §1-2 — 둘째 항목 |\n| D2 | 반영 | §1-7 — 없는 항목 |\n| S7 | 반영 | AC1 — AC10 과 헷갈리면 안 된다 |\n| S8 | 반영 | AC10 · Goals |\n| S9 | 반영 | §2 — 펜스 안에만 있다 |\n' > "$R/loc.md"
out="$(python3 "$C" --json "$R/docs/x/R9.md" "$R/loc.md")"; rc=$?
assert_eq "$rc" "0" "AC7: 얕은 답만 있으면 rc 0 (리뷰 전에 막을 것 없음)"
assert_eq "$(jget "$out" "sorted(s['id'] for s in r['shallow'])")" "['D2', 'S7', 'S9']" "AC3: 없는 §1-7 · AC1(AC10 만 있다) · 펜스 안 §2 를 얕음으로 센다"
assert_eq "$(jget "$out" "[s['reason'] for s in r['shallow'] if s['id']=='D2']")" "['가리킨 자리가 설계문서에 없다: §1-7']" "AC3: 얕음 사유가 가리킨 자리를 말한다"
r9_design '| C1 | 반영 | 그냥 설명만 있다 |\n| D2 | 반영 | §1 |\n| S7 | 반영 | AC2 |\n| S8 | 반영 | Goals — 목표 |\n| S9 | 반영 | 설계 — §1-1 |\n' > "$R/loc2.md"
out="$(python3 "$C" --json "$R/docs/x/R9.md" "$R/loc2.md")"
assert_eq "$(jget "$out" "[(s['id'], s['reason']) for s in r['shallow']]")" "[('C1', '가리킨 자리가 없다')]" "AC3: 자리 표기가 하나도 없으면 얕음, 있으면(§1 · AC2 · 제목 낱말 · §1-1) 세지 않는다(양성 짝)"
txt="$(python3 "$C" "$R/docs/x/R9.md" "$R/loc2.md")"
assert_contains "$txt" "얕은 답 — C1: 가리킨 자리가 없다" "번호별 줄"
# 변이(AC15) — 「자리 표기 없음」 판정을 끄면 위 단언이 무너진다
M2="$T/mut2"; mkdir -p "$M2"; cp "$S/section6.py" "$S/roadmap_model.py" "$M2/"
sed 's/^    if not found:$/    if False:/' "$C" > "$M2/check_bundle_coverage.py"
cmp -s "$C" "$M2/check_bundle_coverage.py" && no "변이 적용 안 됨(자리 표기 없음)" || ok "변이 적용됨(자리 표기 없음)"
out="$(python3 "$M2/check_bundle_coverage.py" --json "$R/docs/x/R9.md" "$R/loc2.md")"
assert_eq "$(jget "$out" "len(r['shallow'])")" "0" "변이: 「자리 표기 없음」을 끄면 C1 이 얕음에서 빠진다 — AC3 단언에 이빨이 있다"

# 12. 기각 행(AC4 · AC5) — 로드맵에 없는 에픽 · 받드는 에픽 없음 · 배정됐지만 그 설계문서가 기각(N17)
r9_design '| C1 | 반영 | §1 |\n| D2 | 기각 | R99 로 넘긴다 |\n| S7 | 기각 | 범위 밖 |\n| S8 | 기각 | R8 이 받는다 |\n| S9 | 기각 | R8 이 받는다 |\n' > "$R/rej.md"
out="$(python3 "$C" --json "$R/docs/x/R9.md" "$R/rej.md")"; rc=$?
assert_eq "$rc" "0" "AC7: 얕음 · 받드는 에픽 없는 발화만 있으면 rc 0"
assert_eq "$(jget "$out" "[(s['id'], s['reason']) for s in r['shallow']]")" "[('D2', '넘긴 에픽이 로드맵에 없다: R99')]" "AC4: 기각 칸의 에픽이 로드맵에 없으면 얕음"
assert_eq "$(jget "$out" "r['unserved']")" "['S7', 'S9']" "AC5: 받드는 블록 없는 S7 과, 배정된 R8 의 설계문서가 기각한 S9(N17)가 받드는 에픽 없는 발화다 — R8 이 받드는 S8 은 아니다"
assert_eq "$(jget "$out" "r['unknown']")" "[]" "로드맵을 읽었으면 셀 수 없음 0"
cp -R "$R" "$T/repo2"
sed 's/^| S9 | 기각 | 범위 밖 |$/| S9 | 반영 | Goals |/' "$R/docs/superpowers/specs/r8-design.md" > "$T/repo2/docs/superpowers/specs/r8-design.md"
out="$(python3 "$C" --json "$T/repo2/docs/x/R9.md" "$R/rej.md")"
assert_eq "$(jget "$out" "r['unserved']")" "['S7']" "N17 양성 짝: R8 설계문서가 S9 를 반영하면 S9 는 받든 것이다"

# 13. 로드맵을 못 찾음(AC5 · AC7) — 그 항목만 셀 수 없음, rc 0, 첫 줄이 개수를 말한다
mkdir -p "$T/lone"; cp "$R/docs/x/R9.md" "$T/lone/R9.md"
txt="$(python3 "$C" "$T/lone/R9.md" "$R/rej.md")"; rc=$?
assert_eq "$rc" "0" "AC7: 셀 수 없음만 있으면 rc 0"
assert_eq "$(printf '%s\n' "$txt" | head -n 1)" "번호 대조: 빠진 번호 0개 · 얕은 답 0개 · 받드는 에픽 없는 발화 0개 · 셀 수 없음 4개" "AC7: 첫 줄이 셀 수 없음 개수를 말한다(조용한 0 이 아니다)"
assert_contains "$txt" "셀 수 없음 — S7 — 로드맵을 찾지 못했다: docs/x/roadmap.md" "셀 수 없음 사유 줄"

# 14. 출력 · 종료 코드(AC7) — 빠진 번호가 하나면 rc 1(양성 짝), JSON 키
r9_design '| C1 | 반영 | §1 |\n| D2 | 반영 | §1 |\n| S7 | 반영 | §1 |\n| S8 | 반영 | §1 |\n' > "$R/miss1.md"
txt="$(python3 "$C" "$R/docs/x/R9.md" "$R/miss1.md")"; rc=$?
assert_eq "$rc" "1" "AC7 양성 짝: 빠진 번호 하나 → rc 1"
assert_eq "$(printf '%s\n' "$txt" | head -n 1)" "번호 대조: 빠진 번호 1개 · 얕은 답 0개 · 받드는 에픽 없는 발화 0개" "AC7: 첫 줄 형식"
out="$(python3 "$C" --json "$R/docs/x/R9.md" "$R/miss1.md")"
assert_eq "$(jget "$out" "sorted(k for k in r if k in ('missing','shallow','unserved','unknown','extra','status'))")" "['extra', 'missing', 'shallow', 'status', 'unknown', 'unserved']" "AC7: --json 키"
r9_design '| C1 · D2 · S7 · S8 · S9 | 반영 | §1-1 |\n' > "$R/ok9.md"
txt="$(python3 "$C" "$R/docs/x/R9.md" "$R/ok9.md")"; rc=$?
assert_eq "$rc" "0" "전부 정상 → rc 0"
assert_eq "$txt" "번호 대조: 빠진 번호 없음 (묶음 번호 5개 · 표 번호 5개)" "전부 0 이면 지금의 「빠진 번호 없음」 한 줄"

# 15. brief 입력(AC6) — brief 의 전체 번호로 대조하고 roadmap_status 와 같은 집합이다
B="$T/brief"; mkdir -p "$B"
cat > "$B/b.md" <<'MD'
---
type: interview-brief
user_sourced_items:
  - id: C3
    statement: "셋째 확정"
---

# 대조용 brief

## 0. 한눈에

- OQ2 [열림] — 둘째 물음

## 4. External Landscape

- 대조 사례 «cov» — [취함]

## 5. 기각 · Blind Spots

- 기각 — 다른 길 — verdict: kept — ST2 — 부착 1/1
- 위험 — 실패 양식: 대조가 빠진다 — 근거 없음 [RC3]

## 6. 사용자 원문

- **S3** 🗣 요청:
  > 번호를 다 대조해 줘

## 7. Next Action

다음.
MD
printf '# audit\n\n## 6. 사용자 원문\n\n- **S4** 🗣 발화:\n  > 넷째 말\n\n## 7. 확산 원자료\n\n- 없음\n' > "$B/b.audit.md"
bdesign() { printf -- '---\nsource_interview: x\n---\n\n# 설계\n\n### §1 절\n\n1. 하나\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| %s | 반영 | §1 |\n' "$1"; }
bdesign "C3 · OQ2 · «cov» · RC3 · ST2 · K1 · S3 · S4" > "$B/d-all.md"
txt="$(python3 "$C" "$B/b.md" "$B/d-all.md")"; rc=$?
assert_eq "$rc" "0" "AC6: brief 입력 — 전체 번호가 표에 있으면 rc 0"
assert_eq "$txt" "번호 대조: 빠진 번호 없음 (brief 번호 8개 · 표 번호 8개)" "AC6: brief 번호 8개(§2 · §0 OQ · §4 key · §5 RC · ST · K · §6 S)를 센다"
bdesign "C3 · OQ2 · «cov» · RC3 · ST2 · K1 · S3" > "$B/d-miss.md"
txt="$(python3 "$C" "$B/b.md" "$B/d-miss.md")"; rc=$?
assert_eq "$rc" "1" "AC6: audit §6 의 S4 가 빠지면 rc 1"
assert_contains "$txt" "빠진 번호 1개 — S4" "AC6: 빠진 번호 S4"
out="$(cd "$S" && python3 -c '
import sys, check_bundle_coverage as c, roadmap_model as m
b = open(sys.argv[1], encoding="utf-8").read(); a = open(sys.argv[2], encoding="utf-8").read()
non_s, s_ids, _k = m.brief_universe(b, a)
r = c.coverage(sys.argv[1], sys.argv[3])
print(r["bundle_count"] == len(non_s | s_ids) and r["mode"] == "brief")' "$B/b.md" "$B/b.audit.md" "$B/d-all.md")"
assert_eq "$out" "True" "AC6: brief 모드의 번호 집합이 roadmap_status 의 brief_universe 와 같다"
mkdir -p "$T/noaudit"; cp "$B/b.md" "$T/noaudit/b.md"
txt="$(python3 "$C" "$T/noaudit/b.md" "$B/d-all.md")"; rc=$?
assert_eq "$rc" "3" "AC6: brief 옆 audit 을 못 읽으면 rc 3"
assert_contains "$txt" "brief 또는 audit 을 못 읽었다" "rc 3 사유"

# 16. 함수 경로의 경고 수(spec-review 가 쓴다)
out="$(cd "$S" && python3 -c '
import sys, check_bundle_coverage as c
print(c.warning_count(c.coverage(sys.argv[1], sys.argv[2])), c.warning_count({"status": 3}))' "$R/docs/x/R9.md" "$R/rej.md")"
assert_eq "$out" "3 1" "warning_count: 얕음 1 + 받드는 에픽 없음 2 = 3, 검사 불가는 1"
```

- [ ] **Step 3: 실패 확인** — 새 단언들 RED(`--json` 결과에 `shallow` 없음 등).

- [ ] **Step 4: `check_bundle_coverage.py` 를 아래 전문으로 바꾼다**(Task 1 의 import 줄 포함):

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_bundle_coverage.py — 정답 출처(에픽 묶음 · brief)의 번호와 설계문서 `## 번호 대조` 표를 맞춘다.

명령줄: check_bundle_coverage.py <묶음|brief> <설계문서> [--json]
종료 코드 — 리뷰 전에 막을 것만 말한다: 0 빠진 번호 없음 · 1 빠진 번호 있음 · 2 사용법 오류 ·
3 검사 불가(`ids:` 없음 · 표 깨짐 · `## 번호 대조` 절 없음 · 파일이나 brief · audit 을 못 읽음 · 내부 오류).
얕은 답 · 받드는 에픽 없는 발화 · 셀 수 없음(로드맵을 못 읽음)은 종료 코드를 바꾸지 않는다 — 첫 줄의 개수와
번호별 줄, `--json` 의 `shallow` · `unserved` · `unknown` 이 말한다. rc 0 은 「리뷰 전에 막을 것 없음」이다.

계수 규칙(R3 설계 Deferred N17 · N18):
- 「기각」 행은 그 번호를 덮은 것으로 센다(빠진 번호가 아니다). 대신 기각 이유의 에픽 번호는 로드맵에 있어야
  하고(없으면 얕음), 기각한 발화(S)는 로드맵의 다른 블록이 받들어야 한다(없으면 받드는 에픽 없는 발화).
- 받듦은 배정만으로 세지 않는다 — 다른 블록에 배정됐어도 그 블록의 작업 트리 설계문서가 그 S 를 「기각」했으면
  받들지 않는다. 설계문서가 아직 없거나 표를 못 읽으면 배정이 받듦이다.
- brief 입력에는 로드맵이 없어 기각 에픽 · 받듦 검사를 하지 않는다.

`roadmap_status.py` 는 `check(bundle_text, spec_text)` 를 import 해 `git show` 로 읽은 글을 넘기고 status 만 본다.
읽기만 한다 — 파일을 쓰지 않고 git · 네트워크를 부르지 않는다.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from roadmap_model import (  # noqa: E402,F401 — 이 이름들은 이 모듈의 공개 표면이기도 하다
    FormatError, PREFIX_ORDER, SEP_CELL_RE, SEP_RE, TOKEN_RE, brief_universe, bundle_ids,
    collect_assigned, frontmatter, id_sort_key, parse_ids, parse_roadmap, section_body, unquote)

TABLE_HEADING = "## 번호 대조"
AC_HEADING = "## Acceptance Criteria"
# 자리 표기 — `§<n>` · `§<n>-<m>` · `AC<n>`. 숫자 뒤에 숫자가 이어지면 다른 토큰이다(AC1 ≠ AC10).
SECTION_TOKEN_RE = re.compile(r"§(\d+)(?:-(\d+))?(?!\d)")
AC_TOKEN_RE = re.compile(r"(?<![A-Za-z0-9])AC(\d+)(?!\d)")
AC_ITEM_RE = re.compile(r"\s*[-*]\s+(?:\*\*)?AC(\d+)(?!\d)")
EPIC_TOKEN_RE = re.compile(r"(?<![A-Za-z0-9])(R\d+[a-z]?|P\d+)(?![A-Za-z0-9])")


class Repo:
    """레포 루트 기준 읽기 — 로드맵 · 다른 묶음 · 작업 트리 설계문서. 읽기만 한다."""

    def __init__(self, root: str):
        self.root = root
        self._specs = None

    def read(self, rel: str):
        try:
            with open(os.path.join(self.root, rel), encoding="utf-8") as fh:
                return fh.read()
        except (OSError, UnicodeDecodeError):
            return None

    def exists(self, rel: str) -> bool:
        return os.path.exists(os.path.join(self.root, rel))

    def specs_for(self, source: str) -> list:
        """`docs/superpowers/specs/*.md` 중 frontmatter `source_interview` 가 source 인 (경로, 글)."""
        if self._specs is None:
            self._specs = []
            try:
                names = sorted(os.listdir(os.path.join(self.root, "docs", "superpowers", "specs")))
            except OSError:
                names = []
            for name in names:
                if not name.endswith(".md"):
                    continue
                rel = "docs/superpowers/specs/" + name
                text = self.read(rel)
                if text is not None:
                    self._specs.append((rel, unquote(frontmatter(text).get("source_interview", "")), text))
        return [(rel, text) for rel, src, text in self._specs if src == source]


def find_repo(bundle_path: str, roadmap_rel: str):
    """묶음 파일의 디렉토리부터 위로 — `<조상>/<roadmap_rel>` 이 파일인 첫 조상을 레포 루트로 쓴다."""
    if not roadmap_rel:
        return None
    here = Path(os.path.abspath(bundle_path)).parent
    for anc in [here, *here.parents]:
        if (anc / roadmap_rel).is_file():
            return Repo(str(anc))
    return None


def _cells(row: str) -> list:
    if not (row.startswith("|") and row.endswith("|")):
        raise FormatError("표 행이 | 로 시작하고 끝나지 않는다: %r" % row)
    return [c.strip() for c in row[1:-1].split("|")]


def table_rows(spec_text: str) -> list:
    """`## 번호 대조` 표의 (번호 목록, 처리, 셋째 칸) 행들. 절이 없거나 표가 깨졌으면 FormatError."""
    body = section_body(spec_text, TABLE_HEADING)
    if body is None:
        raise FormatError("spec 에 `## 번호 대조` 절이 없다")
    rows = [l.strip() for l in body.splitlines() if l.strip().startswith("|")]
    if len(rows) < 3:
        raise FormatError("번호 대조 표가 없거나 데이터 행이 없다")
    if len(_cells(rows[0])) != 3:
        raise FormatError("번호 대조 표 머리 행이 칸 셋이 아니다")
    sep = _cells(rows[1])
    if len(sep) != 3 or not all(SEP_CELL_RE.fullmatch(c) for c in sep):
        raise FormatError("번호 대조 표 구분 행이 칸 셋이 아니다")
    out = []
    for row in rows[2:]:
        cells = _cells(row)
        if len(cells) != 3:
            raise FormatError("번호 대조 표 행이 칸 셋이 아니다: %r" % row)
        if not (cells[1].startswith("반영") or cells[1].startswith("기각")):
            raise FormatError("둘째 칸이 반영/기각이 아니다: %r" % row)
        if not cells[2]:
            raise FormatError("셋째 칸(자리 또는 이유)이 비었다: %r" % row)
        out.append((parse_ids(cells[0]), cells[1], cells[2]))
    return out


def table_ids(spec_text: str) -> set:
    """`## 번호 대조` 표의 첫 칸 번호 전부."""
    out = set()
    for ids, _verb, _cell in table_rows(spec_text):
        out.update(ids)
    return out


def _outside_fences(text: str):
    in_fence = False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if not in_fence:
            yield line


def design_sections(spec_text: str) -> dict:
    """펜스 밖 `### §<n>` 절마다 본문 줄 — {n: [줄]}. 다음 `## ` · `### ` 제목에서 끝난다."""
    out, cur = {}, None
    for line in _outside_fences(spec_text):
        if line.startswith("## ") or line.startswith("### "):
            cur = None
            if line.startswith("### §"):
                digits = ""
                for ch in line[len("### §"):]:
                    if ch not in "0123456789":
                        break
                    digits += ch
                if digits:
                    cur = out.setdefault(int(digits), [])
            continue
        if cur is not None:
            cur.append(line)
    return out


def heading_parts(spec_text: str) -> set:
    """펜스 밖 `## ` 제목 전체와 ` / ` · ` · ` 로 나눈 조각들(`## 번호 대조` 는 빼고)."""
    parts = set()
    for line in _outside_fences(spec_text):
        if not line.startswith("## ") or line.rstrip() == TABLE_HEADING:
            continue
        title = line[3:].strip()
        if not title:
            continue
        parts.add(title)
        for sep in (" / ", " · "):
            parts.update(p.strip() for p in title.split(sep) if p.strip())
    return parts


def _word_char(ch: str) -> bool:
    return ch.isalnum() or ch == "_"


def has_word(cell: str, word: str) -> bool:
    """cell 안에 word 가 글자 · 숫자 경계로 있는가(「Goals」는 「Goals —」에 맞고 「Goalsx」에 안 맞는다)."""
    start = 0
    while True:
        i = cell.find(word, start)
        if i < 0:
            return False
        j = i + len(word)
        if (i == 0 or not _word_char(cell[i - 1])) and (j == len(cell) or not _word_char(cell[j])):
            return True
        start = i + 1


def acceptance_ids(spec_text: str):
    """`## Acceptance Criteria` 항목 머리의 AC 번호(등장 순서, 중복 제거). 절이 없으면 None."""
    body = section_body(spec_text, AC_HEADING)
    if body is None:
        return None
    out = []
    for line in body.splitlines():
        m = AC_ITEM_RE.match(line)
        if m and "AC" + m.group(1) not in out:
            out.append("AC" + m.group(1))
    return out


def location_problem(cell: str, sections: dict, acs: list, parts: set):
    """반영 칸의 자리 표기 문제 — 없으면 None, 있으면 사유."""
    found, absent = False, []
    for m in SECTION_TOKEN_RE.finditer(cell):
        found = True
        body = sections.get(int(m.group(1)))
        sub = m.group(2)
        if body is None or (sub is not None and not any(l.startswith("%d. " % int(sub)) for l in body)):
            absent.append(m.group(0))
    for m in AC_TOKEN_RE.finditer(cell):
        found = True
        if "AC" + m.group(1) not in acs:
            absent.append("AC" + m.group(1))
    if any(has_word(cell, p) for p in parts):
        found = True
    if absent:
        return "가리킨 자리가 설계문서에 없다: " + " · ".join(absent)
    if not found:
        return "가리킨 자리가 없다"
    return None


def _is_s(token: str) -> bool:
    return token.startswith("S") and token[1:].isdigit()


def _roadmap_view(fm: dict, repo):
    """(view, 사유). view 는 {"blocks", "rel", "errors"} — 로드맵을 못 읽으면 None 과 사유."""
    rel = unquote(fm.get("roadmap", ""))
    if not rel:
        return None, "묶음 frontmatter 에 roadmap 이 없다"
    if repo is None:
        return None, "로드맵을 찾지 못했다: %s" % rel
    text = repo.read(rel)
    if text is None:
        return None, "로드맵을 못 읽었다: %s" % rel
    meta, blocks, _records, _risk, errors = parse_roadmap(text)
    if errors:
        return None, "로드맵 형식이 깨졌다: %s" % errors[0]
    _bundles, _union, errs = collect_assigned(blocks, meta, rel, repo.read, repo.exists)
    return {"blocks": blocks, "rel": rel, "errors": errs}, None


def _block_specs(block: dict, view: dict, repo) -> list:
    """그 블록의 작업 트리 설계문서 글들."""
    if block["kind"] == "branch":
        rel = block["fields"].get("spec", "").strip().strip("`")
        text = repo.read(rel) if rel else None
        return [text] if text is not None else []
    if block["kind"] == "bundle":
        rdir = view["rel"].rsplit("/", 1)[0] if "/" in view["rel"] else "."
        return [text for _rel, text in repo.specs_for(rdir + "/" + block["fields"]["묶음"])]
    return []


def _serves(block: dict, s: str, view: dict, repo, epic: str) -> bool:
    """다른 블록이 S 를 받드는가 — 배정됐고, 그 블록의 설계문서가 그 S 를 기각하지 않았다(N17)."""
    if block["id"] == epic or s not in block.get("assigned", []):
        return False
    for text in _block_specs(block, view, repo):
        try:
            rows = table_rows(text)
        except FormatError:
            continue
        if any(s in ids and verb.startswith("기각") for ids, verb, _cell in rows):
            return False
    return True


def _unchecked(reason: str) -> dict:
    return {"status": 3, "mode": None, "missing": [], "extra": [], "shallow": [], "unserved": [],
            "unknown": [], "bundle_count": None, "table_count": None, "reason": reason}


def check(bundle_text: str, spec_text: str, *, audit_text=None, repo=None) -> dict:
    """정답 출처의 번호 중 표에 없는 번호(missing) · 얕은 답 · 받드는 에픽 없는 발화 · 셀 수 없음."""
    fm = frontmatter(bundle_text)
    mode = "brief" if unquote(fm.get("type", "")) == "interview-brief" else "bundle"
    try:
        if mode == "brief":
            if audit_text is None:
                raise FormatError("brief 또는 audit 을 못 읽었다")
            non_s, s_ids, _k = brief_universe(bundle_text, audit_text)
            want = sorted(non_s | s_ids, key=id_sort_key)
        else:
            want = bundle_ids(bundle_text)
        rows = table_rows(spec_text)
        acs = acceptance_ids(spec_text) or []
    except FormatError as exc:
        return _unchecked(str(exc))
    have = set()
    for ids, _verb, _cell in rows:
        have.update(ids)
    seen, missing = set(), []
    for token in want:
        if token not in have and token not in seen:
            missing.append(token)
        seen.add(token)
    extra = sorted(have - seen, key=id_sort_key)
    sections, parts = design_sections(spec_text), heading_parts(spec_text)
    view, note = _roadmap_view(fm, repo) if mode == "bundle" else (None, None)
    epic = unquote(fm.get("epic", ""))
    shallow, unserved, unknown = [], [], []
    for ids, verb, cell in rows:
        if verb.startswith("반영"):
            why = location_problem(cell, sections, acs, parts)
            if why:
                shallow += [{"id": t, "reason": why} for t in ids]
            continue
        if mode != "bundle":
            continue
        epics = EPIC_TOKEN_RE.findall(cell)
        rejected_s = [t for t in ids if _is_s(t) and t in seen]
        if view is None:
            targets = list(ids) if epics else rejected_s
            unknown += ["%s — %s" % (t, note) for t in targets]
            continue
        known = {b["id"] for b in view["blocks"]}
        absent = [e for e in epics if e not in known]
        if absent:
            shallow += [{"id": t, "reason": "넘긴 에픽이 로드맵에 없다: " + " · ".join(absent)} for t in ids]
        for s in rejected_s:
            if any(_serves(b, s, view, repo, epic) for b in view["blocks"]):
                continue
            if view["errors"]:
                unknown.append("%s — 로드맵의 묶음을 다 읽지 못했다: %s" % (s, view["errors"][0]))
            else:
                unserved.append(s)
    return {"status": 1 if missing else 0, "mode": mode, "missing": missing, "extra": extra,
            "shallow": shallow, "unserved": unserved, "unknown": unknown,
            "bundle_count": len(seen), "table_count": len(have), "reason": None}


def warning_count(result: dict) -> int:
    """spec-review 게이트의 「경고 N개」에 더할 수 — 검사 불가는 1."""
    if result.get("status") == 3:
        return 1
    return sum(len(result[k]) for k in ("missing", "shallow", "unserved", "unknown"))


def render(result: dict) -> str:
    if result["status"] == 3:
        return "번호 대조 검사 불가 — %s" % result["reason"]
    brief = result.get("mode") == "brief"
    m, sh, un, uk = (result[k] for k in ("missing", "shallow", "unserved", "unknown"))
    if not (m or sh or un or uk):
        lines = ["번호 대조: 빠진 번호 없음 (%s %d개 · 표 번호 %d개)"
                 % ("brief 번호" if brief else "묶음 번호", result["bundle_count"], result["table_count"])]
    else:
        head = "번호 대조: 빠진 번호 %d개 · 얕은 답 %d개 · 받드는 에픽 없는 발화 %d개" % (len(m), len(sh), len(un))
        if uk:
            head += " · 셀 수 없음 %d개" % len(uk)
        lines = [head]
        if m:
            lines.append("빠진 번호 %d개 — %s" % (len(m), " · ".join(m)))
        lines += ["얕은 답 — %s: %s" % (s["id"], s["reason"]) for s in sh]
        lines += ["받드는 에픽 없는 발화 — %s: 이 설계문서가 기각했는데 로드맵의 다른 에픽이 받들지 않는다" % s
                  for s in un]
        lines += ["셀 수 없음 — %s" % u for u in uk]
    if result["extra"]:
        lines.append("정보: %s 없는 번호 %d개가 표에 있다 — %s"
                     % ("brief 에" if brief else "묶음에", len(result["extra"]), " · ".join(result["extra"])))
    return "\n".join(lines)


def _read(path: str):
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read(), None
    except (OSError, UnicodeDecodeError) as exc:
        return None, exc


def coverage(first_path: str, spec_path: str) -> dict:
    """번호 대조 한 번 — 파일을 읽고, brief 면 옆 audit 을, 묶음이면 로드맵이 있는 레포를 찾아 check 를 부른다."""
    texts = []
    for path in (first_path, spec_path):
        text, exc = _read(path)
        if text is None:
            return _unchecked("파일을 못 읽었다: %s (%s)" % (path, exc))
        texts.append(text)
    try:
        fm = frontmatter(texts[0])
        if unquote(fm.get("type", "")) == "interview-brief":
            audit = _read(first_path[:-3] + ".audit.md")[0] if first_path.endswith(".md") else None
            return check(texts[0], texts[1], audit_text=audit)
        return check(texts[0], texts[1], repo=find_repo(first_path, unquote(fm.get("roadmap", ""))))
    except Exception as exc:  # 검사 자체가 죽어도 이상 없음(0)으로 내지 않는다
        return _unchecked("내부 오류 — %s: %s" % (type(exc).__name__, exc))


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(prog="check_bundle_coverage.py",
                                 description="정답 출처(에픽 묶음 · brief)의 번호와 설계문서 번호 대조 표를 맞춘다.")
    ap.add_argument("first", help="에픽 묶음 또는 interview brief")
    ap.add_argument("second", help="설계문서")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    result = coverage(args.first, args.second)
    print(json.dumps(result, ensure_ascii=False) if args.json else render(result))
    return result["status"]


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: 통과 확인** — `test_bundle_coverage.sh` 실패 0, `test_roadmap_status.sh` 실패 0(번호 대조 rc 뜻이 그대로라 V1 · X1 단언이 그대로다), `test_check_brief.sh`(§6 락) · `test_no_new_duplication.sh` 실패 0. 11번 변이 단언과 「변이 적용됨」이 둘 다 ✓ 인지 본다.

- [ ] **Step 6: 커밋** — `feat(spec-distill): 번호 대조가 얕은 답 · 기각 에픽 · 받드는 에픽 없는 발화 · brief 입력을 센다` (트레일러 셋).

---

### Task 3: `--plan` · `--impl` · `## 미룸` 표

설계 §3-1 · §3-2 · §3-4(기계 쪽) · AC8 · AC10(기계 쪽).

**Files:**
- Modify: `plugins/spec-distill/scripts/check_bundle_coverage.py`
- Test: `plugins/spec-distill/tests/test_bundle_coverage.sh`

**Interfaces:**
- Consumes: Task 2 의 `acceptance_ids` · `AC_TOKEN_RE` · `SEP_CELL_RE` · `_cells` · `_read` · `section_body`.
- Produces: `deferred_rows(spec_text)->list[(item, reason, receiver)]` (FormatError — 깨진 표), `receiver_ok(receiver, epic_ids: set)->bool`, `check_plan(spec_text, plan_text)->dict{status, missing, ac_count, reason}`, `check_impl(spec_text, report_text)->dict{status, unreported, unlisted, no_receiver, dropped, unknown_acs, counts, ac_count, reason}`, `render_plan`, `render_impl`, 명령줄 `--plan` · `--impl`. Task 4 가 `deferred_rows` · `receiver_ok` 를 import 한다.

- [ ] **Step 1: 실패하는 테스트** — `test_bundle_coverage.sh` 의 16번 뒤 *(계획이 쓴 테스트 코드 — 리뷰어는 이것도 검사한다)*:

```bash
# 17. --plan(AC8) — 계획 Task 절에 없는 AC, 낱말 경계, 펜스 안 토큰, AC 절 없음
P="$T/plan"; mkdir -p "$P"
printf -- '# 설계\n\n## Acceptance Criteria\n\n- AC1 하나\n- **AC2** 둘\n- AC10. 열\n  - 하위 항목 AC77 은 AC 가 아니다\n\n## Files to Modify\n\n- x\n' > "$P/d.md"
printf -- '# 계획\n\n## Global\n\nAC2 는 여기에만 있다.\n\n### Task 1: 하나\n\n- AC10 을 만든다\n\n```bash\n# AC1 도 펜스 안에서 센다\n```\n\n### Task 2: 둘\n\n- 끝\n' > "$P/p-miss.md"
txt="$(python3 "$C" --plan "$P/d.md" "$P/p-miss.md")"; rc=$?
assert_eq "$rc" "1" "AC8: 계획에 없는 AC 가 있으면 rc 1"
assert_eq "$txt" "계획 대조: 계획에 없는 AC 1개 — AC2" "AC8: Task 절 밖의 AC2 는 계획에 없는 것이다(펜스 안 AC1 · AC10 은 있다)"
printf -- '# 계획\n\n### Task 1: 하나\n\n- AC10 만 있다\n' > "$P/p-ten.md"
txt="$(python3 "$C" --plan "$P/d.md" "$P/p-ten.md")"
assert_eq "$txt" "계획 대조: 계획에 없는 AC 2개 — AC1 · AC2" "AC8: AC10 이 AC1 을 덮지 않는다(낱말 경계)"
printf -- '# 계획\n\n### Task 1: 전부\n\n- AC1 · AC2 · AC10\n' > "$P/p-ok.md"
txt="$(python3 "$C" --plan "$P/d.md" "$P/p-ok.md")"; rc=$?
assert_eq "$rc" "0" "AC8 양성 짝: 다 있으면 rc 0"
assert_eq "$txt" "계획 대조: 계획에 없는 AC 없음 (AC 3개)" "AC8: 하위 항목의 AC77 은 AC 로 세지 않는다"
printf -- '# 설계\n\n## Goals\n\n- x\n' > "$P/d-noac.md"
txt="$(python3 "$C" --plan "$P/d-noac.md" "$P/p-ok.md")"; rc=$?
assert_eq "$rc" "3" "AC8: AC 절이 없으면 rc 3"
assert_contains "$txt" "계획 대조 검사 불가 — 설계문서에 \`## Acceptance Criteria\` 절이 없다" "rc 3 사유"
out="$(python3 "$C" --plan --json "$P/d.md" "$P/p-miss.md")"
assert_eq "$(jget "$out" "r['missing']")" "['AC2']" "--plan --json missing"

# 18. --impl(AC10) — 보고의 미룸 · 빠짐과 ## 미룸 표
printf -- '# 설계\n\n## Acceptance Criteria\n\n- AC1 하나\n- AC2 둘\n- AC3 셋\n- AC10 열\n\n## 미룸\n\n| 항목 | 이유 | 받는 곳 |\n|---|---|---|\n| AC2 | 다음 에픽에서 | 없음 |\n| r1.2 | 리뷰 후속 | `#12` |\n' > "$P/di.md"
printf 'AC1: 구현됨 — 됐다\n- AC2: 미룸 — 다음에\nAC3: 빠짐 — 못 했다\nAC10: 구현됨 — 됐다\nAC99: 구현됨 — 설계문서에 없는 AC\n' > "$P/rep.md"
txt="$(python3 "$C" --impl "$P/di.md" "$P/rep.md")"; rc=$?
assert_eq "$rc" "1" "AC10: 경고가 있으면 rc 1"
assert_eq "$(printf '%s\n' "$txt" | head -n 1)" "구현 대조: 경고 3개 — 보고에 없는 AC 0개 · 미룸 표에 없는 미룸/빠짐 1개 · 받는 곳 없는 미룸 1개 · 빠짐 1개" "AC10: 첫 줄"
assert_contains "$txt" "미룸 표에 없는 미룸/빠짐 — AC3(빠짐)" "AC10: 빠짐인데 ## 미룸 에 없는 AC"
assert_contains "$txt" "받는 곳 없는 미룸 — AC2" "AC10: 받는 곳이 없음인 행"
assert_contains "$txt" "정보: 설계문서에 없는 AC 가 보고에 있다 — AC99" "설계문서에 없는 AC 는 정보"
printf 'AC1: 구현됨 — a\nAC2: 구현됨 — b\nAC3: 구현됨 — c\n' > "$P/rep-short.md"
txt="$(python3 "$C" --impl "$P/di.md" "$P/rep-short.md")"
assert_contains "$txt" "보고에 없는 AC — AC10" "AC10: 보고에 없는 AC 를 경고한다"
printf -- '# 설계\n\n## Acceptance Criteria\n\n- AC1 하나\n\n## 미룸\n\n없음\n' > "$P/di-none.md"
printf 'AC1: 구현됨 — 됐다\n' > "$P/rep-one.md"
txt="$(python3 "$C" --impl "$P/di-none.md" "$P/rep-one.md")"; rc=$?
assert_eq "$rc" "0" "AC10 양성 짝: 전부 구현됨 · ## 미룸 「없음」 → rc 0"
assert_eq "$txt" "구현 대조: 경고 없음 (AC 1개 · 구현됨 1개 · 미룸 0개)" "경고 없음 줄"
printf 'AC1: 됐음 — 형식 밖\n' > "$P/rep-bad.md"
python3 "$C" --impl "$P/di-none.md" "$P/rep-bad.md" >/dev/null; rc=$?
assert_eq "$rc" "3" "보고 줄이 형식 밖이면 rc 3"
printf 'AC1: 구현됨 — a\nAC1: 빠짐 — b\n' > "$P/rep-dup.md"
python3 "$C" --impl "$P/di-none.md" "$P/rep-dup.md" >/dev/null; rc=$?
assert_eq "$rc" "3" "같은 AC 가 두 번이면 rc 3"
printf -- '# 설계\n\n## Acceptance Criteria\n\n- AC1 하나\n\n## 미룸\n\n| 항목 | 받는 곳 |\n|---|---|\n| AC1 | 없음 |\n' > "$P/di-broken.md"
txt="$(python3 "$C" --impl "$P/di-broken.md" "$P/rep-one.md")"; rc=$?
assert_eq "$rc" "3" "## 미룸 표가 깨지면 rc 3"
assert_contains "$txt" "구현 대조 검사 불가 — " "rc 3 첫 줄"
python3 "$C" --impl "$P/di.md" "$P/없음.md" >/dev/null; rc=$?
assert_eq "$rc" "3" "보고 파일이 없으면 rc 3"
python3 "$C" --plan --impl "$P/di.md" "$P/rep.md" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "--plan 과 --impl 은 함께 쓸 수 없다(rc 2)"
lc="$(LC_ALL=C LANG=C PYTHONIOENCODING= python3 "$C" --impl "$P/di.md" "$P/rep.md" 2>&1)"
assert_contains "$lc" "구현 대조: 경고 3개" "비UTF-8 로캘에서도 한국어 출력이 깨지지 않는다"

# 19. deferred_rows · receiver_ok(Task 4 가 쓴다)
out="$(cd "$S" && python3 -c '
import sys, check_bundle_coverage as c
rows = c.deferred_rows(open(sys.argv[1], encoding="utf-8").read())
print(rows)
print([c.receiver_ok(r, {"R5"}) for r in ("없음", "#12", "R5", "R99", "다음에")])' "$P/di.md")"
assert_contains "$out" "[('AC2', '다음 에픽에서', '없음'), ('r1.2', '리뷰 후속', '#12')]" "deferred_rows: 받는 곳의 백틱을 벗긴다"
assert_contains "$out" "[False, True, True, False, False]" "receiver_ok: 없음 · 로드맵에 없는 에픽 · 그 밖 글은 받는 곳이 아니다"
```

- [ ] **Step 2: 실패 확인** — `--plan` 이 모르는 인자라 rc 2 등.

- [ ] **Step 3: 구현** — `check_bundle_coverage.py` 에서 `warning_count` 앞에 아래를 더하고, `main` 을 아래 `main` 으로 바꾼다. 모듈 docstring 의 「명령줄:」 줄을 세 줄로 바꾼다:

```
명령줄:
  check_bundle_coverage.py <묶음|brief> <설계문서> [--json]        번호 대조(설계문서 단계)
  check_bundle_coverage.py --plan <설계문서> <계획> [--json]        계획 `### Task` 절에 없는 AC — 0 · 1 · 3
  check_bundle_coverage.py --impl <설계문서> <보고 파일> [--json]   구현 보고의 미룸 · 빠짐 — 0 · 1(경고) · 3
```

```python
DEFER_HEADING = "## 미룸"
RECEIVER_EPIC_RE = re.compile(r"R\d+[a-z]?|P\d+")
RECEIVER_PR_RE = re.compile(r"#\d+")
REPORT_HEAD_RE = re.compile(r"AC\d+:")
REPORT_LINE_RE = re.compile(r"AC(\d+): (구현됨|미룸|빠짐) — (\S.*)")
VERDICTS = ("구현됨", "미룸", "빠짐")


def deferred_rows(spec_text: str) -> list:
    """`## 미룸` 표의 (항목, 이유, 받는 곳) 행들. 절이 없거나 「없음」뿐이면 []. 표가 깨졌으면 FormatError."""
    body = section_body(spec_text, DEFER_HEADING)
    if body is None:
        return []
    rows = [l.strip() for l in body.splitlines() if l.strip().startswith("|")]
    if not rows:
        rest = [l.strip().lstrip("-*").strip() for l in body.splitlines() if l.strip()]
        if all(r == "없음" for r in rest):
            return []
        raise FormatError("`## 미룸` 절에 표가 없다")
    if len(rows) < 2 or len(_cells(rows[0])) != 3:
        raise FormatError("`## 미룸` 표 머리 행이 칸 셋이 아니다")
    sep = _cells(rows[1])
    if len(sep) != 3 or not all(SEP_CELL_RE.fullmatch(c) for c in sep):
        raise FormatError("`## 미룸` 표 구분 행이 칸 셋이 아니다")
    out = []
    for row in rows[2:]:
        cells = _cells(row)
        if len(cells) != 3 or not all(cells):
            raise FormatError("`## 미룸` 표 행이 빈칸 없는 칸 셋이 아니다: %r" % row)
        out.append((cells[0], cells[1], cells[2].strip("`").strip()))
    return out


def receiver_ok(receiver: str, epic_ids: set) -> bool:
    """받는 곳이 `#<숫자>` 이거나 로드맵에 있는 에픽 번호인가. `없음` · 그 밖 글은 받는 곳이 아니다."""
    if RECEIVER_PR_RE.fullmatch(receiver):
        return True
    return bool(RECEIVER_EPIC_RE.fullmatch(receiver)) and receiver in epic_ids


def plan_task_text(plan_text: str) -> str:
    """`### Task` 절들(머리 줄 포함)을 이어 붙인 글. 펜스 안 줄은 절 경계가 아니지만 본문에는 든다."""
    out, on, in_fence = [], False, False
    for line in plan_text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
        elif not in_fence and (line.startswith("## ") or line.startswith("### ")):
            on = line.startswith("### Task")
        if on:
            out.append(line)
    return "\n".join(out)


def _acs_or_error(spec_text: str) -> list:
    acs = acceptance_ids(spec_text)
    if acs is None:
        raise FormatError("설계문서에 `## Acceptance Criteria` 절이 없다")
    if not acs:
        raise FormatError("`## Acceptance Criteria` 절에 AC 항목이 없다")
    return acs


def _plan_unchecked(reason: str) -> dict:
    return {"status": 3, "missing": [], "ac_count": None, "reason": reason}


def check_plan(spec_text: str, plan_text: str) -> dict:
    try:
        acs = _acs_or_error(spec_text)
    except FormatError as exc:
        return _plan_unchecked(str(exc))
    have = {"AC" + m.group(1) for m in AC_TOKEN_RE.finditer(plan_task_text(plan_text))}
    missing = [a for a in acs if a not in have]
    return {"status": 1 if missing else 0, "missing": missing, "ac_count": len(acs), "reason": None}


def render_plan(r: dict) -> str:
    if r["status"] == 3:
        return "계획 대조 검사 불가 — %s" % r["reason"]
    if r["missing"]:
        return "계획 대조: 계획에 없는 AC %d개 — %s" % (len(r["missing"]), " · ".join(r["missing"]))
    return "계획 대조: 계획에 없는 AC 없음 (AC %d개)" % r["ac_count"]


def parse_report(text: str) -> dict:
    """{AC: (판정, 한 줄)}. `AC<n>:` 로 시작하는데 형식이 다르거나 같은 AC 가 두 번이면 FormatError."""
    out = {}
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("- ") or s.startswith("* "):
            s = s[2:].strip()
        if not REPORT_HEAD_RE.match(s):
            continue
        m = REPORT_LINE_RE.fullmatch(s)
        if not m:
            raise FormatError("보고 줄이 `AC<n>: 구현됨|미룸|빠짐 — <한 줄>` 이 아니다: %r" % s)
        ac = "AC" + m.group(1)
        if ac in out:
            raise FormatError("보고에 %s 가 두 번 있다" % ac)
        out[ac] = (m.group(2), m.group(3))
    return out


def _impl_unchecked(reason: str) -> dict:
    return {"status": 3, "unreported": [], "unlisted": [], "no_receiver": [], "dropped": [],
            "unknown_acs": [], "counts": None, "ac_count": None, "reason": reason}


def check_impl(spec_text: str, report_text: str) -> dict:
    try:
        acs = _acs_or_error(spec_text)
        report = parse_report(report_text)
        if not report:
            raise FormatError("보고에 AC 판정 줄이 없다")
        deferred = deferred_rows(spec_text)
    except FormatError as exc:
        return _impl_unchecked(str(exc))
    listed = {"AC" + m.group(1) for item, _why, _recv in deferred for m in AC_TOKEN_RE.finditer(item)}
    judged = [a for a in acs if a in report]
    return {
        "status": 0, "reason": None, "ac_count": len(acs),
        "unreported": [a for a in acs if a not in report],
        "unlisted": ["%s(%s)" % (a, report[a][0]) for a in judged
                     if report[a][0] != "구현됨" and a not in listed],
        "no_receiver": [item for item, _why, recv in deferred if recv == "없음"],
        "dropped": ["%s: %s" % (a, report[a][1]) for a in judged if report[a][0] == "빠짐"],
        "unknown_acs": sorted((a for a in report if a not in acs), key=lambda a: int(a[2:])),
        "counts": {v: sum(1 for a in judged if report[a][0] == v) for v in VERDICTS},
    }


IMPL_GROUPS = (("보고에 없는 AC", "unreported"), ("미룸 표에 없는 미룸/빠짐", "unlisted"),
               ("받는 곳 없는 미룸", "no_receiver"), ("빠짐", "dropped"))


def _impl_status(r: dict) -> dict:
    if r["status"] != 3:
        r["status"] = 1 if any(r[k] for _label, k in IMPL_GROUPS) else 0
    return r


def render_impl(r: dict) -> str:
    if r["status"] == 3:
        return "구현 대조 검사 불가 — %s" % r["reason"]
    n = sum(len(r[k]) for _label, k in IMPL_GROUPS)
    if n:
        lines = ["구현 대조: 경고 %d개 — %s"
                 % (n, " · ".join("%s %d개" % (label, len(r[k])) for label, k in IMPL_GROUPS))]
        lines += ["%s — %s" % (label, " · ".join(r[k])) for label, k in IMPL_GROUPS if r[k]]
        if r["dropped"]:
            lines.append("빠짐은 머지 전에 고치거나 사용자가 미룸으로 옮긴다(설계문서 `## 미룸` 표).")
    else:
        c = r["counts"]
        lines = ["구현 대조: 경고 없음 (AC %d개 · 구현됨 %d개 · 미룸 %d개)" % (r["ac_count"], c["구현됨"], c["미룸"])]
    if r["unknown_acs"]:
        lines.append("정보: 설계문서에 없는 AC 가 보고에 있다 — %s" % " · ".join(r["unknown_acs"]))
    return "\n".join(lines)


def _two_files(first: str, second: str, fn, unchecked) -> dict:
    texts = []
    for path in (first, second):
        text, exc = _read(path)
        if text is None:
            return unchecked("파일을 못 읽었다: %s (%s)" % (path, exc))
        texts.append(text)
    try:
        return fn(texts[0], texts[1])
    except Exception as exc:  # 검사 자체가 죽어도 이상 없음(0)으로 내지 않는다
        return unchecked("내부 오류 — %s: %s" % (type(exc).__name__, exc))


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(prog="check_bundle_coverage.py",
                                 description="정답 출처의 번호와 설계문서 AC 를 설계문서 · 계획 · 구현 보고와 맞춘다.")
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--plan", action="store_true", help="<설계문서> <계획>: 계획 Task 절에 없는 AC")
    mode.add_argument("--impl", action="store_true", help="<설계문서> <보고 파일>: 구현 보고의 미룸 · 빠짐")
    ap.add_argument("first", help="묶음 · brief(기본) 또는 설계문서(--plan · --impl)")
    ap.add_argument("second", help="설계문서(기본) · 계획(--plan) · 보고 파일(--impl)")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    if args.plan:
        result = _two_files(args.first, args.second, check_plan, _plan_unchecked)
        text = render_plan(result)
    elif args.impl:
        result = _impl_status(_two_files(args.first, args.second, check_impl, _impl_unchecked))
        text = render_impl(result)
    else:
        result = coverage(args.first, args.second)
        text = render(result)
    print(json.dumps(result, ensure_ascii=False) if args.json else text)
    return result["status"]
```

- [ ] **Step 4: 통과 확인** — `test_bundle_coverage.sh` · `test_roadmap_status.sh` · `test_check_brief.sh` · `test_no_new_duplication.sh` 실패 0.

- [ ] **Step 5: 커밋** — `feat(spec-distill): 계획 · 구현 대조(--plan · --impl)와 설계문서 ## 미룸 표` (트레일러 셋).

---

### Task 4: `roadmap_status.py` 의 미룸 경고

설계 §3-3 · AC9 · AC15(AC9 변이). 에픽이 머지된 뒤에도 남는다.

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_status.py` (`compute` 의 spec 루프)
- Test: `plugins/spec-distill/tests/test_roadmap_status.sh`

**Interfaces:**
- Consumes: Task 3 의 `deferred_rows` · `receiver_ok` (import 줄 `from check_bundle_coverage import check, deferred_rows, receiver_ok`).
- Produces: 블록 경고 문구 `받는 곳 없는 미룸 <n>개: <spec> — <항목들>` · `미룸 셀 수 없음(<사유>): <spec>`(검사 불가로도 올라가 rc 3). R6 · Task 10 이 이 문구를 읽는다.

- [ ] **Step 1: 실패하는 테스트** — `test_roadmap_status.sh` 의 7번(실데이터) 앞에 새 절을 더한다 *(계획이 쓴 테스트 코드 — 리뷰어는 이것도 검사한다)*:

```bash
# ── 6b. 미룸 경고(R3 AC9) — 받는 곳 없는 행 · 머지 뒤에도 · 깨진 표는 셀 수 없음 · 변이 ─────
mkdir -p "$W/docs/rm8" "$W/docs/rm9"
bundle docs/rm8 D8 "C1, D2, OQ1, RC1, ST1, «k1», K1, K2, S1, S2"
bundle docs/rm8 E8 "C1"
bundle docs/rm9 F9 "C1, D2, OQ1, RC1, ST1, «k1», K1, K2, S1, S2"
{ roadmap_head; block D8 feature/d8 없음 없음; block E8 feature/e8 없음 없음; roadmap_tail ""; } > "$W/docs/rm8/roadmap.md"
{ roadmap_head; block F9 feature/f9 없음 없음; roadmap_tail ""; } > "$W/docs/rm9/roadmap.md"
g checkout -q main
g add -- docs/rm8 docs/rm9 && g commit -qm "rm8 · rm9" && g push -q origin main
defer_spec() {  # defer_spec <source_interview> <미룸 절 본문>
  printf -- '---\nsource_interview: %s\n---\n\n# 설계\n\n### §1 절\n\n1. 하나\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| C1 · D2 · OQ1 · RC1 · ST1 · «k1» · K1 · K2 · S1 · S2 | 반영 | §1 |\n\n## 미룸\n\n%b\n' "$1" "$2"
}
g checkout -q -b feature/d8 main; mkdir -p "$W/docs/superpowers/specs"
defer_spec docs/rm8/D8.md '| 항목 | 이유 | 받는 곳 |\n|---|---|---|\n| AC2 | 시간 | 없음 |\n| AC3 | 넘김 | R99 |\n| AC4 | 후속 | #12 |\n| r1.2 | 리뷰 후속 | `E8` |' > "$W/docs/superpowers/specs/d8-design.md"
g add -- docs/superpowers/specs/d8-design.md && g commit -qm "d8 spec"
pr_merge 81 feature/d8; g push -q origin main
g checkout -q -b feature/f9 main
defer_spec docs/rm9/F9.md '| 항목 | 받는 곳 |\n|---|---|\n| AC2 | 없음 |' > "$W/docs/superpowers/specs/f9-design.md"
g add -- docs/superpowers/specs/f9-design.md && g commit -qm "f9 spec"; g checkout -q main
g fetch -q origin
(cd "$W" && python3 "$RS" --json docs/rm8/roadmap.md > "$T/d8.json"); rc=$?
assert_eq "$(stage "$T/d8.json" D8)" "머지됨" "D8 은 머지됐다"
assert_contains "$(warns "$T/d8.json" D8)" "받는 곳 없는 미룸 2개: docs/superpowers/specs/d8-design.md — AC2 · AC3" "AC9: 받는 곳이 없음 · 로드맵에 없는 에픽인 행을 경고한다(머지 뒤에도)"
assert_not_contains "$(warns "$T/d8.json" D8)" "AC4" "AC9 양성 짝: #12 · 로드맵에 있는 에픽(백틱 친 E8)은 경고하지 않는다"
assert_eq "$rc" "1" "AC9: 미룸 경고는 경고(rc 1)다"
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm9/roadmap.md > "$T/f9.json"); rc=$?
assert_eq "$rc" "3" "AC9: ## 미룸 표가 깨지면 검사 불가(rc 3)"
assert_contains "$(warns "$T/f9.json" F9)" "미룸 셀 수 없음(" "AC9: 깨진 표는 「셀 수 없음」"
assert_contains "$(js "$T/f9.json" "r['unknown_reasons']")" "F9 미룸 표" "AC9: 셀 수 없음이 검사 불가 사유로 올라온다"
# 변이(AC15) — 받는 곳 판정을 끄면 경고가 사라진다
M3="$T/mut3"; mkdir -p "$M3"; cp "$S/section6.py" "$S/check_bundle_coverage.py" "$S/roadmap_model.py" "$M3/"
sed 's/^            bad = \[item for item, _why, recv in rows if not receiver_ok(recv, known_ids)\]$/            bad = []/' "$RS" > "$M3/roadmap_status.py"
cmp -s "$RS" "$M3/roadmap_status.py" && no "변이 적용 안 됨(받는 곳 판정)" || ok "변이 적용됨(받는 곳 판정)"
(cd "$W" && python3 "$M3/roadmap_status.py" --json docs/rm8/roadmap.md > "$T/md8.json")
assert_not_contains "$(warns "$T/md8.json" D8)" "받는 곳 없는 미룸" "변이: 받는 곳 판정을 끄면 경고가 사라진다 — AC9 단언에 이빨이 있다"
```

- [ ] **Step 2: 실패 확인** — `받는 곳 없는 미룸` 단언 RED.

- [ ] **Step 3: 구현** — import 줄을 `from check_bundle_coverage import check, deferred_rows, receiver_ok  # noqa: E402` 로 바꾸고, `compute` 의 `if b["kind"] == "bundle" and bundles.get(bid) is not None:` 블록(번호 대조 루프) 전체를 아래로 바꾼다:

```python
        tree = main if b["stage"] == "머지됨" else tip
        known_ids = set(by_id)
        for spec in b["specs"]:
            spec_text = git.blob(tree, spec)
            if spec_text is None:
                b["warnings"].append("번호 대조 검사 불가(spec 을 읽지 못했다): %s" % spec)
                cov_unknown.append("%s spec 을 읽지 못했다" % bid)
                continue
            if b["kind"] == "bundle" and bundles.get(bid) is not None:
                result = check(bundles[bid], spec_text)
                if result["status"] == 1:
                    b["warnings"].append("생략: %s 이 번호 %d개를 빠뜨렸다 — %s" % (
                        spec, len(result["missing"]), " · ".join(result["missing"])))
                elif result["status"] == 3:
                    b["warnings"].append("번호 대조 검사 불가(%s): %s" % (result["reason"], spec))
                    cov_unknown.append("%s %s" % (bid, result["reason"]))
            # 미룸(R3 §3-3) — 받는 곳이 `#<숫자>` 나 로드맵의 에픽이 아닌 행. 머지 뒤에도 남는다.
            try:
                rows = deferred_rows(spec_text)
            except FormatError as exc:
                b["warnings"].append("미룸 셀 수 없음(%s): %s" % (exc, spec))
                cov_unknown.append("%s 미룸 표 — %s" % (bid, exc))
                continue
            bad = [item for item, _why, recv in rows if not receiver_ok(recv, known_ids)]
            if bad:
                b["warnings"].append("받는 곳 없는 미룸 %d개: %s — %s" % (len(bad), spec, " · ".join(bad)))
```
  (`tip` 은 이 루프 위에서 이미 정해진 지역 변수다 — 결정 블록은 앞에서 `continue` 하므로 이 줄에 오지 않는다. 결정 블록 · spec 없는 블록은 `b["specs"]` 가 비어 루프를 돌지 않는다.) docstring 의 종료 코드 줄 「번호 대조 검사 불가」 뒤에 「 · 미룸 표 깨짐」을 더한다.

- [ ] **Step 4: 통과 확인** — `test_roadmap_status.sh` 실패 0(1번 절의 기존 단언 — V1 생략 · X1 검사 불가 · M1 spec 여럿 — 이 그대로인지 특히 본다), `test_bundle_coverage.sh` 실패 0.

- [ ] **Step 5: 커밋** — `feat(spec-distill): 로드맵 상태가 설계문서 ## 미룸 의 받는 곳 없는 행을 경고` (트레일러 셋).

---

### Task 5: brief 다음 세션 줄 · 에픽 넘김 줄

설계 §1-1 ~ §1-5 · AC1(앞 절반) · AC2 · AC10(셋 중 둘) · AC15(AC1 부재 변이).

**Files:**
- Modify: `plugins/spec-distill/skills/spec-interview/references/finishing.md` (B-3 의 다음 세션 줄 · 치환 문장 · 에픽 넘김 줄 포인터)
- Create: `plugins/spec-distill/references/epic-handoff.md`
- Modify: `plugins/spec-distill/tests/test_review_handoff_order.sh` (AC1 · AC10 · 꺾쇠 규칙 완화 · 변이)
- Modify: `plugins/spec-distill/tests/test_next_session_command.sh` (꺾쇠 규칙 완화)
- Create: `plugins/spec-distill/tests/test_epic_handoff.sh` (100755)

**Interfaces:**
- Produces: finishing.md 다음 세션 줄(아래 문면), `references/epic-handoff.md` 의 표지 `**에픽 넘김 줄**` 과 그 아래 인용 줄 하나. Task 7 이 spec-review 다음 세션 줄에 같은 두 지시 문장(계획 대조 · 구현 대조)을 싣는다 — 문장은 이 Task 의 것을 그대로 쓴다(spec-review 줄은 `<spec_path>` 를 넣는다).

- [ ] **Step 1: 실패하는 테스트 — `test_review_handoff_order.sh`** *(계획이 쓴 테스트 코드 — 리뷰어는 이것도 검사한다)*
  - 머리(`. assert.sh` 아래)에 임시 폴더를 연다:

```bash
TMP="$(mktemp -d)" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
trap 'rm -rf "$TMP"' EXIT
```
  - `lead_only()` 를 아래로 바꾼다(꺾쇠 자리표는 줄 앞 `@<…>` 토큰의 이름만):

```bash
lead_only() { LINE="$1" python3 -I -c '
import os, re
l = os.environ["LINE"]
m = re.match(r"((?:@<[^<>]+> )+)", l)
names = set(re.findall(r"@<([^<>]+)>", m.group(1))) if m else set()
rest = re.findall(r"<([^<>]+)>", l[m.end():]) if m else ["(앞 토큰 없음)"]
print("ok" if m and all(x in names for x in rest) else "no")'; }
```
  - 다음 세션 줄 블록의 `assert_contains "$ONE" "보다 이 순서가 우선한다" …` 줄을 지우고, 그 자리에 아래를 넣는다:

```bash
  assert_not_contains "$ONE" "보다 이 순서가 우선한다" "AC1: 다음 세션 줄에 brainstorming 지시를 덮어쓰는 문장이 없다(D42)"
  for n in '§3 열린 질문 · §4 조사 · §5 위험' '번호째' '## 번호 대조 표' 'source_interview' '--bundle <brief-path>' \
           'check_bundle_coverage.py --plan' '## Acceptance Criteria 의 AC 목록' '구현됨 · 미룸 · 빠짐' \
           'git 이 추적하지 않는 파일' '## 미룸 표' 'check_bundle_coverage.py --impl' '/compact 요약에 기대지 말고'; do
    assert_contains "$ONE" "$n" "AC1 · AC10: brief 다음 세션 줄에 「$n」"
  done
  order "다음 세션 줄" "$ONE" "--plan" "--impl"
```
  - `lead_only` 단언 뒤(같은 `if` 안)에 합성 양성 대조와 AC1 부재 변이를 넣는다:

```bash
  assert_eq "$(lead_only '@<a> x <a> y')" "ok" "꺾쇠 규칙: 줄 앞 토큰의 이름은 줄 안에 다시 쓸 수 있다"
  assert_eq "$(lead_only '@<a> x <b> y')" "no" "꺾쇠 규칙 양성 대조: 줄 앞 토큰에 없는 이름은 거부한다"
  sed 's/Skill superpowers:brainstorming 을 시작하라\./Skill superpowers:brainstorming 을 시작하라. brainstorming 의 「다음은 writing-plans 뿐」 지시보다 이 순서가 우선한다./' "$FIN" > "$TMP/fin_mut.md"
  case "$(nsl "$TMP/fin_mut.md")" in
    *"보다 이 순서가 우선한다"*) ok "변이(AC15): 덮어쓰기 문장을 되넣으면 같은 추출이 그것을 본다 — AC1 부재 단언에 이빨이 있다" ;;
    *) no "변이(AC15): 되넣은 덮어쓰기 문장을 추출이 못 본다 — 부재 단언이 공허하다" ;;
  esac
```
  - 파일 끝 `finish` 앞에 에픽 넘김 줄 포인터 단언:

```bash
assert_file_grep "$FIN" '\$\{CLAUDE_PLUGIN_ROOT\}/references/epic-handoff\.md' "finishing.md 가 에픽 넘김 줄 reference 를 가리킨다(AC2 · 고아 reference 방지)"
```

- [ ] **Step 2: 실패하는 테스트 — `test_next_session_command.sh`** — 파이썬 파서 안의 다음 줄들을

```python
    left = re.findall(r"<[^<>]+>", tail)
    if left:
        no(f"{name}: 꺾쇠 자리표가 줄 앞 @ 토큰 밖에 있다: {left}")
    else:
        ok(f"{name}: 꺾쇠 자리표는 줄 앞 @ 토큰에만 있다")
```
  아래로 바꾼다(앞쪽에서 줄 앞 토큰 묶음을 잡은 변수가 slash 줄 · 평문 줄 갈래마다 무엇인지 읽고, 두 갈래 모두에서 그 토큰 묶음 문자열로 `lead` 를 정한다 — 토큰을 못 잡은 갈래는 `lead = ""`):

```python
    names = set(re.findall(r"@<([^<>]+)>", lead))
    left = [x for x in re.findall(r"<([^<>]+)>", tail) if x not in names]
    if left:
        no(f"{name}: 줄 안의 꺾쇠 자리표가 줄 앞 @ 토큰의 이름 밖이다: {left}")
    else:
        ok(f"{name}: 줄 안의 꺾쇠 자리표는 줄 앞 @ 토큰의 이름뿐이다")
```
  머리 주석의 「꺾쇠 자리표는 줄 앞 `@<…>` 토큰에만 있다.」를 「줄 안의 꺾쇠 자리표는 줄 앞 `@<…>` 토큰의 이름뿐이다(같은 자리표를 다시 쓰는 것은 함께 치환된다).」로 고친다.

- [ ] **Step 3: 실패하는 테스트 — 새 `test_epic_handoff.sh`** *(계획이 쓴 테스트 코드 — 리뷰어는 이것도 검사한다)*

```bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/references/epic-handoff.md
#
# R3 AC2 · AC10 — 에픽 넘김 줄(`references/epic-handoff.md`)이 묶음을 첨부하고 로드맵 속 위치를 밝히며,
# brief 다음 세션 줄과 같은 지시(번호째 읽기 · 번호 대조 · source_interview · --bundle · --plan · --impl)를 싣는가.
# 정적 락이다 — 지휘 세션이 이 줄을 실제로 치환해 쓰는지는 재지 못한다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
EH="$ROOT/plugins/spec-distill/references/epic-handoff.md"
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/references/epic-handoff.md"
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
MARK='**에픽 넘김 줄**'
[ -f "$EH" ] && ok "epic-handoff.md 가 있다" || { no "epic-handoff.md 가 없다"; finish; exit $?; }
assert_eq "$(grep -cxF "$MARK" "$EH" || true)" "1" "AC2: 표지 줄이 정확히 하나"
LINE="$(awk -v m="$MARK" '$0==m{f=1;next} f&&NF{print;exit}' "$EH")"
case "$LINE" in
  '> `'*'`') ok "AC2: 표지 아래 첫 줄이 인용 줄이다" ;;
  *) no "AC2: 표지 아래 첫 줄이 인용 줄이 아니다: $LINE" ;;
esac
ONE="$(printf '%s' "$LINE" | sed -e 's/^> `//' -e 's/`$//')"
case "$ONE" in
  "@<bundle-abs> 이 에픽 묶음으로 Skill superpowers:brainstorming 을 시작하라."*) ok "AC2: 줄이 @<bundle-abs> 첨부로 시작해 brainstorming 을 부른다" ;;
  *) no "AC2: 줄의 머리가 다르다: $ONE" ;;
esac
for n in '승인된 로드맵 <roadmap-rel> 의 에픽 <epic-id> 다' '번호째' '## 번호 대조 표' 'source_interview 에 <bundle-rel>' \
         '--bundle <bundle-rel>' 'check_bundle_coverage.py --plan' '## Acceptance Criteria 의 AC 목록' \
         '구현됨 · 미룸 · 빠짐' 'git 이 추적하지 않는 파일' '## 미룸 표' 'check_bundle_coverage.py --impl' \
         '게이트 없이 끝나면 brainstorming 의 사용자 리뷰 게이트로 돌아간다'; do
  assert_contains "$ONE" "$n" "AC2 · AC10: 에픽 넘김 줄에 「$n」"
done
assert_not_contains "$ONE" "보다 이 순서가 우선한다" "에픽 넘김 줄도 외부 지시를 덮어쓰지 않는다"
pos() { WIN="$ONE" A="$1" python3 -I -c 'import os; print(os.environ["WIN"].find(os.environ["A"]))'; }
a="$(pos 'Skill superpowers:brainstorming')"; b="$(pos 'spec-distill:spec-review')"; c="$(pos 'writing-plans')"
[ "$a" -ge 0 ] && [ "$a" -lt "$b" ] && [ "$b" -lt "$c" ] && ok "순서: brainstorming → spec-review → writing-plans" || no "순서가 다르다($a · $b · $c)"
names_ok() { LINE="$1" python3 -I -c '
import os, re
bad = [x for x in re.findall(r"<([^<>]+)>", os.environ["LINE"])
       if x not in ("bundle-abs", "bundle-rel", "roadmap-rel", "epic-id")]
print("ok" if not bad else "no " + " ".join(bad))'; }
assert_eq "$(names_ok "$ONE")" "ok" "AC2: 자리표는 넷(bundle-abs · bundle-rel · roadmap-rel · epic-id)뿐"
assert_eq "$(names_ok "$ONE <spec>")" "no spec" "양성 대조: 모르는 자리표를 잡는다"
assert_file_grep "$EH" '치환되지 않은 자리표가 남거나 경로에 공백이 있으면 쓰지 않는다' "AC2: 자리표 규칙"
assert_file_grep "$EH" '\$\{CLAUDE_PLUGIN_ROOT\}' "줄의 스크립트 경로는 플러그인 루트 기준이고 치환 대상이다"
assert_eq "$(grep -c '^> `@<' "$EH" || true)" "1" "인용 줄이 하나뿐이다(표지 밖에 둘째 정의가 없다)"
finish
```

- [ ] **Step 4: 실패 확인** — 세 테스트가 RED(덮어쓰기 문장 있음 · 새 문구 없음 · 파일 없음).

- [ ] **Step 5: finishing.md B-3 다음 세션 줄을 바꾼다** — `**다음 세션 줄 — ①/② 공통**` 아래 인용 줄을 아래 한 줄로 바꾼다(한 줄 · 인용 줄 안에 백틱 없음):

```markdown
> `@<brief-path> 이 interview brief 로 Skill superpowers:brainstorming 을 시작하라. confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지. brief 의 §2 확정 항목뿐 아니라 §3 열린 질문 · §4 조사 · §5 위험을 번호째 설계의 입력으로 읽는다 — /compact 요약에 기대지 말고 첨부한 brief 를 다시 읽는다. 설계문서에 ## 번호 대조 표(칸: 번호 · 반영/기각 · 자리 또는 이유)를 두어 brief 의 모든 번호를 싣고, 설계문서 frontmatter source_interview 에 이 brief 의 레포 루트 기준 상대경로를 적는다. 설계문서를 쓰고 커밋한 뒤, brainstorming 의 사용자 리뷰 게이트 자리에서 그 설계문서 경로 뒤에 --bundle <brief-path> 를 붙여 Skill spec-distill:spec-review 를 부른다. superpowers:writing-plans 는 spec-review 의 승인 게이트에서 진행이 선택된 뒤에만 부른다. spec-review 가 게이트 없이 끝나면 brainstorming 의 사용자 리뷰 게이트로 돌아간다. writing-plans 가 계획을 쓴 뒤 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_bundle_coverage.py --plan 에 설계문서와 계획 경로를 넘겨 돌리고, 계획에 없는 AC 는 계획에 더한다. SDD 의 마지막 전체 리뷰에 설계문서 ## Acceptance Criteria 의 AC 목록을 싣고, 리뷰가 AC 마다 한 줄씩 AC1: 구현됨 — 근거 꼴(판정은 구현됨 · 미룸 · 빠짐 중 하나)로 보고하게 해 그 보고를 git 이 추적하지 않는 파일에 적는다. 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 ## 미룸 표(항목 · 이유 · 받는 곳)에 올리고, PR 을 만들기 전에 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_bundle_coverage.py --impl 에 설계문서와 보고 파일 경로를 넘겨 돌려 경고를 사용자에게 보인다. 사람에게 쓰는 글 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 첫 줄에 상태, 끝에 할 일 하나)을 지킨다.`
```

  바로 아래 치환 문단의 첫 문장 「`<brief-path>` 는 Step A.5 의 `PAYLOAD` 값, 곧 brief 의 절대경로로 치환한 뒤 노출한다.」를 다음으로 바꾼다(필수 문구 「절대경로로 치환한 뒤 노출한다」 유지):

```markdown
`<brief-path>` 는 두 자리 모두 Step A.5 의 `PAYLOAD` 값, 곧 brief 의 절대경로로 치환한 뒤 노출한다. 줄 안의 `${CLAUDE_PLUGIN_ROOT}` 는 이 플러그인의 절대경로로 바꿔 노출한다 — 이 파일에서는 그 변수가 치환되지 않은 채 읽히고, 새 세션에는 그 변수가 없다.
```

  그 문단 끝(「사람이 이 줄의 유일한 운반자다 — 자동으로 이어지지 않는다.」 뒤)에 한 문장을 더한다:

```markdown
로드맵 에픽의 설계를 여는 줄은 이 줄이 아니라 `${CLAUDE_PLUGIN_ROOT}/references/epic-handoff.md` 의 에픽 넘김 줄이다 — 지휘 세션이 쓴다.
```

- [ ] **Step 6: `references/epic-handoff.md` 를 만든다** — 다른 reference 를 가리킬 때는 `${CLAUDE_PLUGIN_ROOT}/…` 형태로만 쓴다(`shared/tests/test_skill_reference_pointers.sh` 가 `skills/…/references/…` 같은 맨 접두사를 거부한다):

```markdown
# 에픽 넘김 줄

승인된 로드맵의 에픽 하나를 설계하는 세션을 열 때 지휘 세션이 붙여 넣는 줄이다. brief 흐름의 다음 세션 줄(`${CLAUDE_PLUGIN_ROOT}/skills/spec-interview/references/finishing.md` 의 B-3)과 같은 모양이고, 첨부와 정답 출처가 brief 가 아니라 그 에픽의 묶음이다.

**에픽 넘김 줄**

> `@<bundle-abs> 이 에픽 묶음으로 Skill superpowers:brainstorming 을 시작하라. 이 묶음은 승인된 로드맵 <roadmap-rel> 의 에픽 <epic-id> 다 — 이 에픽의 몫만 설계하고 묶음을 다시 나누지 않는다. confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지. 묶음의 모든 번호(확정 · 열린 질문 · 조사 · 위험 · 발화)를 번호째 설계의 입력으로 읽는다 — /compact 요약에 기대지 말고 첨부한 묶음을 다시 읽는다. 설계문서에 ## 번호 대조 표(칸: 번호 · 반영/기각 · 자리 또는 이유)를 두어 묶음 ids 의 모든 번호를 싣고, 다른 에픽으로 넘기는 번호는 기각 칸에 그 에픽 번호를 적는다. 설계문서 frontmatter source_interview 에 <bundle-rel> 을 적는다. 설계문서를 쓰고 커밋한 뒤, brainstorming 의 사용자 리뷰 게이트 자리에서 그 설계문서 경로 뒤에 --bundle <bundle-rel> 을 붙여 Skill spec-distill:spec-review 를 부른다. superpowers:writing-plans 는 spec-review 의 승인 게이트에서 진행이 선택된 뒤에만 부른다. spec-review 가 게이트 없이 끝나면 brainstorming 의 사용자 리뷰 게이트로 돌아간다. writing-plans 가 계획을 쓴 뒤 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_bundle_coverage.py --plan 에 설계문서와 계획 경로를 넘겨 돌리고, 계획에 없는 AC 는 계획에 더한다. SDD 의 마지막 전체 리뷰에 설계문서 ## Acceptance Criteria 의 AC 목록을 싣고, 리뷰가 AC 마다 한 줄씩 AC1: 구현됨 — 근거 꼴(판정은 구현됨 · 미룸 · 빠짐 중 하나)로 보고하게 해 그 보고를 git 이 추적하지 않는 파일에 적는다. 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 ## 미룸 표(항목 · 이유 · 받는 곳)에 올리고, PR 을 만들기 전에 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_bundle_coverage.py --impl 에 설계문서와 보고 파일 경로를 넘겨 돌려 경고를 사용자에게 보인다. 사람에게 쓰는 글 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 첫 줄에 상태, 끝에 할 일 하나)을 지킨다.`

## 자리표

- `<bundle-abs>` — 묶음의 절대경로(첨부). 상대경로는 하니스가 세션 작업 디렉토리 기준으로 풀어 다른 파일을 붙일 수 있다.
- `<bundle-rel>` — 같은 묶음의 레포 루트 기준 상대경로(로드맵 블록의 `묶음:` 값을 로드맵 디렉토리에 붙인 것). `roadmap_status.py` 가 설계문서를 이 글자로 찾는다.
- `<roadmap-rel>` — 로드맵의 레포 루트 기준 상대경로. `<epic-id>` — 블록 번호(예 `R3`).
- `${CLAUDE_PLUGIN_ROOT}` — spec-distill 플러그인의 절대경로.

모든 자리표를 치환한 뒤 쓴다. 치환되지 않은 자리표가 남거나 경로에 공백이 있으면 쓰지 않는다 — 지휘 세션은 그 사유를 사용자에게 보인다(`proceed-gate.md` `## 다음 세션 명령` 규칙 5 와 같다). 새 세션(`/new`)의 첫 줄로 붙여 넣는다.
```

- [ ] **Step 7: 통과 확인** — `chmod +x plugins/spec-distill/tests/test_epic_handoff.sh`. `test_review_handoff_order.sh` · `test_next_session_command.sh` · `test_epic_handoff.sh` · `shared/tests/test_skill_reference_pointers.sh` · `test_proceed_gate_adopters.sh` · `test_finishing_block_scope.py`(`python3 -m unittest plugins/spec-distill/tests/test_finishing_block_scope.py`) · `test_no_new_duplication.sh` · `test_stale_terms.sh` · `shared/tests/test_plugin_root_no_cwd_fallback.sh` 실패 0. RED 가 나면 그 락의 의도를 읽고 문면을 맞춘다(락을 약하게 고치지 않는다 — 고쳐야 하면 판정으로 남긴다).

- [ ] **Step 8: 커밋** — `feat(spec-distill): 넘김 글이 외부 지시를 덮어쓰지 않고 번호 대조 · 계획 · 구현 대조를 싣는다` (트레일러 셋). 커밋 뒤 `git -C <worktree> ls-files -s plugins/spec-distill/tests/test_epic_handoff.sh` 가 `100755`.

---

### Task 6: `spec_review_bundle.py`

설계 §4-1 · §4-2(스크립트) · §4-4 · AC11 · AC12(스크립트) · AC14.

**Files:**
- Create: `plugins/spec-distill/scripts/spec_review_bundle.py`
- Create: `plugins/spec-distill/tests/test_spec_review_bundle.sh` (100755)
- Modify: `plugins/spec-distill/tests/test_roadmap_status.sh` (정적 읽기 전용 검사 대상에 이 스크립트를 더한다 — `CHECKED 4`)

**Interfaces:**
- Consumes: `check_bundle_coverage.coverage` · `render` · `warning_count`, `roadmap_status.Git` · `build` · `MAIN_REF`, `roadmap_model.frontmatter` · `section_body` · `unquote` · `FormatError`.
- Produces: 명령줄 `entry --spec <설계문서> [--bundle <값>] --root <레포 루트>` — 마지막 줄 `bundle-entry: PROCEED <절대경로|->` 또는 `bundle-entry: REFUSE`, PROCEED(번들 있음) 바로 앞 줄 `번호 대조 경고 <N>개`; `neighbors --bundle <묶음> --root <레포 루트>` — `로드맵 속 위치 — <로드맵>` 머리와 `이웃 에픽의 결정` 머리, 또는 빈 출력. 종료 코드는 언제나 0(사용법 오류만 2). Task 7 의 펜스가 이 줄들을 읽는다.

- [ ] **Step 1: 실패하는 테스트 — 새 `test_spec_review_bundle.sh`** *(계획이 쓴 테스트 코드 — 리뷰어는 이것도 검사한다)*

```bash
#!/usr/bin/env bash
# R3 AC11 · AC12 · AC14 — spec-review 의 --bundle 확인 · 진입 번호 대조 · 승인 때 로드맵 위치와 이웃 결정.
# 스크립트(spec_review_bundle.py)를 픽스처 git 저장소에서 돌린다. SKILL 펜스 배선은 아래 절이 잰다(Task 7).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_spec_review_bundle.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
S="$ROOT/plugins/spec-distill/scripts"
SRB="$S/spec_review_bundle.py"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
W="$T/work"
g() { git -C "$W" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false \
        -c init.defaultBranch=main "$@"; }
put() { mkdir -p "$(dirname "$W/$1")" && printf '%b' "$2" > "$W/$1"; }   # put <경로> <내용(%b)>

git init -q --bare -b main "$T/origin.git"
git clone -q "$T/origin.git" "$W" 2>/dev/null
put docs/nb/brief.md '---\ntype: interview-brief\nuser_sourced_items:\n  - id: C1\n    statement: "이웃 확정"\n---\n\n# 이웃 brief\n\n## 0. 한눈에\n\n- OQ1 [열림] — 이웃 물음\n\n## 4. External Landscape\n\n- 이웃 사례 «nb» — 참고\n\n## 5. 기각 · Blind Spots\n\n- 위험 — 숨은 가정: 이웃이 안 보인다 — 없음 [RC1]\n\n## 6. 사용자 원문\n\n- **S1** 🗣 요청:\n  > 이웃 결정을 보여 줘\n\n## 7. Next Action\n\n없음.\n'
put docs/nb/brief.audit.md '# audit\n\n## 6. 사용자 원문\n\n- **S2** 🗣 발화:\n  > 둘째 요청\n\n## 7. 확산 원자료\n\n- 없음\n'
nb_bundle() {  # nb_bundle <에픽> <ids>
  put "docs/rm/$1.md" "---\ntype: epic-bundle\nepic: $1\nroadmap: docs/rm/roadmap.md\nsource_brief: docs/nb/brief.md\nids: [$2]\n---\n\n# $1 이웃 묶음\n"
}
nb_bundle R1 "C1, OQ1"; nb_bundle R3 "C1, S1"; nb_bundle R4 "RC1"; nb_bundle R5 "«nb», K1"; nb_bundle R6 "S2"
nb_block() {  # nb_block <id> <의존> <경로 예약>
  printf '### %s — 이웃 %s\n- 의도: %s\n- 범위: %s\n- 의존: %s\n- 브랜치: feature/%s\n- 묶음: %s.md\n- 경로 예약: %s\n\n' "$1" "$1" "$1" "$1" "$2" "$(printf '%s' "$1" | tr 'A-Z' 'a-z')" "$1" "$3"
}
{ printf -- '---\ntype: roadmap\nsource_brief: docs/nb/brief.md\n---\n\n# 이웃 로드맵\n\n## 에픽\n\n'
  nb_block R1 없음 없음; nb_block R3 R1 "src/shared.txt"; nb_block R4 없음 "src/shared.txt"
  nb_block R5 R3 없음; nb_block R6 없음 없음
  printf '## 결정 기록\n\n## 위험 번호표\n\n- K1 — 위험 — 숨은 가정: 이웃이 안 보인다 — 없음 [RC1]\n'
} > "$W/docs/rm/roadmap.md"
g add -- docs && g commit -qm "이웃 로드맵" && g push -q origin main
spec_with() {  # spec_with <경로> <source_interview> <결정 기록 본문(%b)>
  put "$1" "---\nsource_interview: $2\n---\n\n# 설계\n\n### §1 절\n\n1. 하나\n\n## 결정 기록\n\n$3\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| C1 | 반영 | §1 |\n| S1 | 반영 | 없는 자리만 말한다 |\n"
}
g checkout -q -b feature/r1 main
spec_with docs/superpowers/specs/r1-design.md docs/rm/R1.md '- B1 · 결정 · 2026-10-15 · 첫 결정 — 「그대로 (권장)」\n- 판정 · 2026-10-15 · 보이지 않는 줄'
g add -- docs && g commit -qm "r1 spec"; g checkout -q main
g merge -q --no-ff feature/r1 -m "Merge pull request #1 from o/feature/r1"; g push -q origin main
g checkout -q -b feature/r4 main
spec_with docs/superpowers/specs/r4-design.md docs/rm/R4.md '- 없음'
g add -- docs && g commit -qm "r4 spec"; g checkout -q main
g checkout -q -b feature/r6 main
spec_with docs/superpowers/specs/r6-design.md docs/rm/R6.md '- B9 · 결정 · 2026-10-15 · 무관한 이웃 — 「보이면 안 된다」'
g add -- docs && g commit -qm "r6 spec"; g checkout -q main
g checkout -q -b feature/r3 main
spec_with docs/superpowers/specs/r3-design.md docs/rm/R3.md '- 없음'
spec_with docs/superpowers/specs/q-design.md '"docs/rm/R3.md"' '- 없음'
spec_with docs/superpowers/specs/b-design.md docs/nb/brief.md '- 없음'
put docs/superpowers/specs/none-design.md '---\nname: x\n---\n\n# 출처 없음\n'
g add -- docs && g commit -qm "r3 spec"
g fetch -q origin
SPEC="$W/docs/superpowers/specs/r3-design.md"
entry() { (cd "$T" && python3 "$SRB" entry --spec "$1" ${2+--bundle "$2"} --root "$W"); }
last() { printf '%s\n' "$1" | tail -n 1; }

# 1. AC11 — 같은 파일은 표기가 달라도 통과(양성 짝)
for v in docs/rm/R3.md @docs/rm/R3.md ./docs/rm/../rm/R3.md "$W/docs/rm/R3.md"; do
  out="$(entry "$SPEC" "$v")"
  assert_eq "$(last "$out")" "bundle-entry: PROCEED $(cd "$W" && pwd -P)/docs/rm/R3.md" "AC11: --bundle '$v' 은 source_interview 와 같은 파일이라 통과한다"
done
out="$(entry "$W/docs/superpowers/specs/q-design.md" docs/rm/R3.md)"
assert_contains "$(last "$out")" "bundle-entry: PROCEED " "AC11: 따옴표 친 source_interview 도 같은 파일로 읽는다"
# 2. AC11 — 거부 넷
out="$(entry "$SPEC" docs/rm/없음.md)"
assert_eq "$(last "$out")" "bundle-entry: REFUSE" "AC11: 없는 파일 → 거부"
assert_contains "$out" "[spec-distill] --bundle 'docs/rm/없음.md' 을 정답 출처로 쓸 수 없다 — 파일이 없다." "AC11: 거부 사유 문면"
out="$(entry "$SPEC" docs/rm/roadmap.md)"
assert_contains "$out" "frontmatter type 이 epic-bundle · interview-brief 가 아니다(roadmap)" "AC11: 틀린 type → 거부"
out="$(entry "$SPEC" docs/rm/R4.md)"
assert_contains "$out" "설계문서 source_interview(docs/rm/R3.md) 와 다른 파일이다" "AC11: 다른 묶음 → 거부"
out="$(entry "$W/docs/superpowers/specs/none-design.md" docs/rm/R3.md)"
assert_contains "$out" "설계문서 frontmatter 에 source_interview 가 없다" "AC11: source_interview 없는 설계문서 → 거부"
# 3. AC11 — --bundle 없는 호출은 검사를 건너뛴다
out="$(entry "$SPEC")"
assert_eq "$(last "$out")" "bundle-entry: PROCEED -" "AC11: --bundle 없으면 건너뛴다"
assert_contains "$out" "번호 대조 건너뜀" "건너뜀을 말한다"
# 4. AC12 — 진입 대조 출력과 경고 수(얕은 행 하나)
out="$(entry "$SPEC" docs/rm/R3.md)"
assert_contains "$out" "번호 대조: 빠진 번호 0개 · 얕은 답 1개 · 받드는 에픽 없는 발화 0개" "AC12: §2 출력 첫 줄을 그대로 보인다"
assert_eq "$(printf '%s\n' "$out" | tail -n 2 | head -n 1)" "번호 대조 경고 1개" "AC12: PROCEED 앞 줄이 경고 수"
out="$(entry "$W/docs/superpowers/specs/b-design.md" docs/nb/brief.md)"
assert_contains "$out" "번호 대조: 빠진 번호 " "AC12: brief 로 불려도 대조한다(brief 모드)"
assert_contains "$(last "$out")" "bundle-entry: PROCEED " "brief --bundle 은 통과"
lc="$(cd "$T" && LC_ALL=C LANG=C PYTHONIOENCODING= python3 "$SRB" entry --spec "$SPEC" --bundle docs/rm/R3.md --root "$W" 2>&1)"
assert_contains "$lc" "번호 대조 경고 1개" "비UTF-8 로캘에서도 한국어 출력이 깨지지 않는다"

# 5. AC14 — 에픽 묶음이면 로드맵 위치와 이웃 결정
nbr="$(cd "$T" && python3 "$SRB" neighbors --bundle docs/rm/R3.md --root "$W")"
assert_contains "$nbr" "로드맵 속 위치 — docs/rm/roadmap.md" "AC14: 위치 머리"
assert_grep "$nbr" '^  R3 이웃 R3 — 설계 중 · ' "AC14: 이 에픽 한 줄(roadmap_status 줄 모양)"
assert_grep "$nbr" '^  의존: R1 이웃 R1 — 머지됨 · ' "AC14: 의존 에픽 한 줄"
assert_grep "$nbr" '^  이 에픽에 의존: R5 이웃 R5 — ' "AC14: 이 에픽에 의존하는 에픽 한 줄"
assert_contains "$nbr" "    - B1 · 결정 · 2026-10-15 · 첫 결정 — 「그대로 (권장)」" "AC14: 의존 이웃의 사용자 결정 줄을 그대로"
assert_contains "$nbr" "  R4 — 결정 줄 없음 — docs/superpowers/specs/r4-design.md" "AC14: 경로 예약이 겹치는 이웃(결정 줄 없음)"
assert_not_contains "$nbr" "보이지 않는 줄" "AC14: 결정 줄(B<n> · 결정)이 아닌 줄은 내지 않는다"
assert_not_contains "$nbr" "무관한 이웃" "AC14: 의존도 겹침도 없는 R6 은 내지 않는다"
g show feature/r6:docs/superpowers/specs/r6-design.md | grep -q 'B9 · 결정' && ok "양성 대조: R6 설계문서에는 결정 줄이 있다 — 위 부재가 공허하지 않다" || no "양성 대조: R6 설계문서에 결정 줄이 없다 — 위 부재 단언이 공허하다"
nbr="$(cd "$T" && python3 "$SRB" neighbors --bundle docs/nb/brief.md --root "$W")"
assert_eq "$nbr" "" "AC14: brief 로 불리면 내지 않는다"
put docs/rm/R9.md '---\ntype: epic-bundle\nepic: R9\nroadmap: docs/rm/roadmap.md\nsource_brief: docs/nb/brief.md\nids: [C1]\n---\n'
nbr="$(cd "$T" && python3 "$SRB" neighbors --bundle docs/rm/R9.md --root "$W")"
assert_eq "$nbr" "" "AC14: 로드맵 밖 에픽이면 내지 않는다"
(cd "$T" && python3 "$SRB" >/dev/null 2>&1); rc=$?
assert_eq "$rc" "2" "하위 명령 없음 → rc 2"
finish
```

- [ ] **Step 2: 실패 확인** — 스크립트가 없어 RED.

- [ ] **Step 3: 구현 — `spec_review_bundle.py`**:

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""spec_review_bundle.py — spec-review 의 `--bundle`: 정답 출처 확인 · 진입 번호 대조 · 승인 때 로드맵 위치와 이웃 결정.

명령줄:
  spec_review_bundle.py entry --spec <설계문서> [--bundle <묶음|brief>] --root <레포 루트>
  spec_review_bundle.py neighbors --bundle <묶음> --root <레포 루트>

entry 의 마지막 줄은 `bundle-entry: PROCEED <정답 출처 절대경로 또는 ->` 이거나 `bundle-entry: REFUSE` 다.
`--bundle` 이 있으면 PROCEED 바로 앞 줄이 `번호 대조 경고 <N>개` 다. `--bundle` 은 리뷰어에게 가지 않는다 —
그 값이 설계문서 frontmatter `source_interview` 와 같은 파일인지 확인하고 진입 대조 · 로드맵 위치의 입력이 된다.
neighbors 는 정답 출처가 에픽 묶음이 아니거나 그 에픽이 로드맵에 없으면 아무것도 내지 않는다.
종료 코드는 0 이다(사용법 오류만 2) — 판정은 줄이 말한다. 읽기만 한다(roadmap_status 의 읽기 전용 git 만 부른다).
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_bundle_coverage as cbc  # noqa: E402
import roadmap_status as rs  # noqa: E402
from roadmap_model import FormatError, frontmatter, section_body, unquote  # noqa: E402

KINDS = ("epic-bundle", "interview-brief")
DECISION_LINE_RE = re.compile(r"- B\d+ · 결정 · ")


def _resolve(value: str, root: str) -> str:
    v = unquote(value.strip())
    if v.startswith("@"):
        v = v[1:]
    return os.path.realpath(v if os.path.isabs(v) else os.path.join(root, v))


def _read(path: str):
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError):
        return None


def entry(spec: str, bundle: str, root: str) -> list:
    if not bundle:
        return ["번호 대조 건너뜀 — --bundle 없이 불렸다(정답 출처 확인과 진입 번호 대조를 하지 않는다).",
                "bundle-entry: PROCEED -"]

    def refuse(why):
        return ["[spec-distill] --bundle '%s' 을 정답 출처로 쓸 수 없다 — %s." % (bundle, why),
                "bundle-entry: REFUSE"]

    bpath = _resolve(bundle, root)
    if not os.path.isfile(bpath):
        return refuse("파일이 없다")
    btext = _read(bpath)
    if btext is None:
        return refuse("파일을 읽지 못했다")
    kind = unquote(frontmatter(btext).get("type", ""))
    if kind not in KINDS:
        return refuse("frontmatter type 이 epic-bundle · interview-brief 가 아니다(%s)" % (kind or "없음"))
    spath = _resolve(spec, root)
    stext = _read(spath)
    if stext is None:
        return refuse("설계문서를 읽지 못했다: %s" % spec)
    src = unquote(frontmatter(stext).get("source_interview", ""))
    if not src:
        return refuse("설계문서 frontmatter 에 source_interview 가 없다")
    if _resolve(src, root) != bpath:
        return refuse("설계문서 source_interview(%s) 와 다른 파일이다" % src)
    result = cbc.coverage(bpath, spath)
    return [cbc.render(result), "번호 대조 경고 %d개" % cbc.warning_count(result),
            "bundle-entry: PROCEED %s" % bpath]


def _line(b: dict) -> str:
    return "%s %s — %s · %s" % (b["id"], b["title"], b["stage"], b["reason"])


def neighbors(bundle: str, root: str) -> list:
    bpath = _resolve(bundle, root)
    btext = _read(bpath)
    if btext is None:
        return ["[spec-distill] 로드맵 속 위치를 보일 수 없다 — 묶음을 읽지 못했다: %s" % bundle]
    fm = frontmatter(btext)
    if unquote(fm.get("type", "")) != "epic-bundle":
        return []
    epic, rel = unquote(fm.get("epic", "")), unquote(fm.get("roadmap", ""))
    git = rs.Git(root)
    report = rs.build(git, argparse.Namespace(roadmap=None, roadmap_file=os.path.join(root, rel), json=True))
    blocks = {b["id"]: b for b in report["blocks"]}
    problems = report["format_errors"] + report["unknown_reasons"]
    if epic not in blocks:
        return ["[spec-distill] 로드맵 속 위치를 보일 수 없다 — %s" % " · ".join(problems)] if problems else []
    me = blocks[epic]
    deps = [d for d in me["deps"] if d in blocks]
    dependents = [b["id"] for b in report["blocks"] if epic in b["deps"]]
    out = ["로드맵 속 위치 — %s" % rel, "  " + _line(me)]
    out += ["  의존: " + _line(blocks[d]) for d in deps]
    out += ["  이 에픽에 의존: " + _line(blocks[d]) for d in dependents]
    if problems:
        out.append("  로드맵 상태 검사 불가 %d개 — 위 단계가 틀릴 수 있다: %s" % (len(problems), " · ".join(problems)))
    overlap = {x for o in report["overlaps"] if epic in o["blocks"] for x in o["blocks"] if x != epic}
    near = set(deps) | set(dependents) | overlap
    main = git.commit(rs.MAIN_REF)
    dec = []
    for b in report["blocks"]:
        if b["id"] not in near or not b["specs"]:
            continue
        branch = (b.get("branch") or "").strip().strip("`")
        tree = main if b["stage"] == "머지됨" else (
            git.commit("refs/heads/" + branch) or git.commit("refs/remotes/origin/" + branch))
        for spec in b["specs"]:
            text = git.blob(tree, spec) if tree else None
            if text is None:
                dec.append("  %s — 설계문서를 읽지 못했다: %s" % (b["id"], spec))
                continue
            try:
                body = section_body(text, "## 결정 기록") or ""
            except FormatError:
                body = ""
            lines = [l for l in body.splitlines() if DECISION_LINE_RE.match(l)]
            if lines:
                dec.append("  %s — %s" % (b["id"], spec))
                dec += ["    " + l for l in lines]
            else:
                dec.append("  %s — 결정 줄 없음 — %s" % (b["id"], spec))
    out.append("이웃 에픽의 결정" + ("" if dec else " — 설계문서가 있는 이웃 에픽 없음"))
    return out + dec


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(prog="spec_review_bundle.py",
                                 description="spec-review --bundle: 정답 출처 확인 · 진입 대조 · 로드맵 위치와 이웃 결정.")
    sub = ap.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("entry")
    e.add_argument("--spec", required=True)
    e.add_argument("--bundle", default="")
    e.add_argument("--root", required=True)
    n = sub.add_parser("neighbors")
    n.add_argument("--bundle", required=True)
    n.add_argument("--root", required=True)
    args = ap.parse_args(argv)
    try:
        lines = entry(args.spec, args.bundle, args.root) if args.cmd == "entry" else neighbors(args.bundle, args.root)
    except Exception as exc:  # 확인이 죽어도 조용히 통과로 내지 않는다 — 사유를 줄로 낸다
        if args.cmd == "entry":
            lines = ["[spec-distill] 번호 대조 진입 검사 내부 오류 — %s: %s. --bundle 확인과 번호 대조 없이 리뷰한다."
                     % (type(exc).__name__, exc), "번호 대조 경고 1개", "bundle-entry: PROCEED -"]
        else:
            lines = ["[spec-distill] 로드맵 속 위치를 보일 수 없다 — 내부 오류 %s: %s" % (type(exc).__name__, exc)]
    if lines:
        print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: `test_roadmap_status.sh` 정적 검사를 넓힌다** — `static_check "$RS" "$S/check_bundle_coverage.py" "$S/roadmap_model.py"` 에 `"$S/spec_review_bundle.py"` 를 더하고 기대값을 `CHECKED 4`, 메시지를 「네 스크립트」로.

- [ ] **Step 5: 통과 확인** — `chmod +x plugins/spec-distill/tests/test_spec_review_bundle.sh`. 그 테스트 · `test_roadmap_status.sh` · `test_bundle_coverage.sh` · `test_check_brief.sh` · `test_no_new_duplication.sh` · `shared/tests/test_python_floor.sh` 실패 0. (픽스처 R3 의 단계 줄은 「설계 중」이다 — R3 는 로컬 브랜치만 있고 spec 이 있다. 단계 문구가 다르게 나오면 roadmap_status 출력의 실제 줄을 보고 단언의 정규식을 맞추되 「이 에픽 · 의존 · 이 에픽에 의존」 세 줄을 다 재는 것은 유지한다.)

- [ ] **Step 6: 커밋** — `feat(spec-distill): spec-review --bundle 확인 · 진입 대조 · 로드맵 위치와 이웃 결정 스크립트` (트레일러 셋). `test_spec_review_bundle.sh` 가 `100755` 인지 본다.

---

### Task 7: spec-review SKILL 배선 · writing-plans 다음 세션 줄

설계 §1-6 · §4-1 · §4-2 · §4-4 · §4-6 · AC1(뒤 절반) · AC10(셋째) · AC11 · AC12 · AC14 의 SKILL 쪽.

**Files:**
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md`
- Modify: `plugins/spec-distill/tests/test_review_handoff_order.sh` (spec-review 다음 세션 줄)
- Modify: `plugins/spec-distill/tests/test_spec_review_bundle.sh` (펜스 실행 · 배선 단언 절을 `finish` 앞에 더함)

**Interfaces:**
- Consumes: Task 6 의 명령줄 두 하위 명령과 출력 줄.
- Produces: SKILL 표지 `<!-- bundle-entry:begin -->` / `<!-- bundle-entry:end -->` · `<!-- roadmap-position:begin -->` / `<!-- roadmap-position:end -->`.

- [ ] **Step 1: 실패하는 테스트 — `test_review_handoff_order.sh` 의 spec-review 다음 세션 줄 블록**(`assert_grep "$RSL" '임의 변경.*금지' …` 뒤) *(계획이 쓴 테스트 코드 — 리뷰어는 이것도 검사한다)*:

```bash
    for n in 'check_bundle_coverage.py --plan <spec_path>' '계획에 없는 AC 는 계획에 더한다' \
             '## Acceptance Criteria 의 AC 목록' '구현됨 · 미룸 · 빠짐' 'git 이 추적하지 않는 파일' \
             '## 미룸 표' 'check_bundle_coverage.py --impl <spec_path>'; do
      assert_contains "$RSL" "$n" "AC1 · AC10: spec-review 다음 세션 줄(writing-plans 진행 안내)에 「$n」"
    done
    assert_eq "$(lead_only "$RSL")" "ok" "spec-review 다음 세션 줄의 꺾쇠 자리표는 <spec_path> 뿐이다"
```

- [ ] **Step 2: 실패하는 테스트 — `test_spec_review_bundle.sh` 끝(`finish` 앞)에 SKILL 배선 절** *(계획이 쓴 테스트 코드 — 리뷰어는 이것도 검사한다)*:

```bash
# ── 6. SKILL 배선(Task 7) — 펜스를 실제로 돌린다 ───────────────────────────────
SKILL="$ROOT/plugins/spec-distill/skills/spec-review/SKILL.md"
fence() {  # fence <표지 이름> — 표지 사이 bash 펜스 본문
  awk -v b="<!-- $1:begin -->" -v e="<!-- $1:end -->" 'index($0,b){f=1;next} index($0,e){f=0} f' "$SKILL" | sed -e '/^```/d'
}
EF="$(fence bundle-entry)"; NF_="$(fence roadmap-position)"
[ -n "$EF" ] && ok "진입 펜스(bundle-entry)가 있다" || no "진입 펜스(bundle-entry)가 없다"
[ -n "$NF_" ] && ok "위치 펜스(roadmap-position)가 있다" || no "위치 펜스(roadmap-position)가 없다"
run_fence() {  # run_fence <펜스 본문> <플러그인 루트> <앞에 붙일 대입들>
  printf '%s\n%s\n' "$3" "$1" > "$T/fence.sh"
  (cd "$W" && CLAUDE_PLUGIN_ROOT="$2" bash "$T/fence.sh" 2>&1)
}
SDROOT="$ROOT/plugins/spec-distill"
out="$(run_fence "$EF" "$SDROOT" "spec_path='$SPEC' bundle_arg='docs/rm/R4.md' repo_root='$W'")"
assert_contains "$out" "bundle-entry: REFUSE" "AC11: 펜스가 다른 묶음을 거부한다"
assert_contains "$out" "[spec-distill] 리뷰 없이 끝났다 — writing-plans 로 가기 전에" "AC11: 거부에 복귀 문장이 붙는다"
out="$(run_fence "$EF" "$SDROOT" "spec_path='$SPEC' bundle_arg='docs/rm/R3.md' repo_root='$W'")"
assert_contains "$(last "$out")" "bundle-entry: PROCEED " "AC12: 펜스가 통과 줄로 끝난다"
assert_contains "$out" "번호 대조 경고 1개" "AC12: 펜스가 경고 수를 보인다"
mkdir -p "$T/emptyroot"
out="$(run_fence "$EF" "$T/emptyroot" "spec_path='$SPEC' bundle_arg='docs/rm/R3.md' repo_root='$W'")"
assert_eq "$(last "$out")" "bundle-entry: PROCEED -" "스크립트가 없으면 대조 없이 리뷰한다고 말하고 통과한다(경고 1)"
assert_contains "$out" "번호 대조 진입 검사가 실패했다" "실패를 말한다"
out="$(run_fence "$NF_" "$SDROOT" "bundle_path='$W/docs/rm/R3.md' repo_root='$W'")"
assert_contains "$out" "로드맵 속 위치 — docs/rm/roadmap.md" "AC14: 위치 펜스가 위치를 낸다"
out="$(run_fence "$NF_" "$SDROOT" "bundle_path='-' repo_root='$W'")"
assert_eq "$out" "" "위치 펜스: 경로가 - 면 아무것도 내지 않는다"
INPUT_SEC="$(awk '/^## 입력$/{f=1;next} f&&/^## /{exit} f' "$SKILL")"
assert_contains "$INPUT_SEC" "--bundle" "AC11: ## 입력 이 --bundle 을 받는다"
assert_contains "$INPUT_SEC" "source_interview" "AC11: ## 입력 이 source_interview 대조를 말한다"
GATE_SEC="$(awk '/^## 게이트$/{f=1;next} f&&/^## /{exit} f' "$SKILL")"
assert_contains "$GATE_SEC" "번호 대조 경고" "AC12: 게이트가 번호 대조 경고 수를 「경고 N개」에 더한다"
assert_file_grep "$SKILL" '^argument-hint: .*--bundle' "argument-hint 에 --bundle"
```

- [ ] **Step 3: 실패 확인.**

- [ ] **Step 4: SKILL.md 를 고친다.**
  - frontmatter: `argument-hint: <설계문서 경로>` → `argument-hint: <설계문서 경로> [--bundle <에픽 묶음|interview brief>]`. description 의 「Pass the design doc path as the argument.」 뒤에 「Optionally pass `--bundle <epic bundle or interview brief>` — it must be the file the design doc's `source_interview` names.」를 더한다(「path as the argument」 문구 유지).
  - `## 입력` 의 첫 문단(「`$spec_path` 는 **호출 인자**다 …」) 바로 뒤에 아래를 넣는다:

````markdown
인자에 `--bundle <에픽 묶음|interview brief>` 가 붙으면 그 값을 `bundle_arg` 로 뗀다 — 설계문서 경로는 첫 인자다. 상태 디렉토리 블록 다음, 엔진 라운드 전에 아래 펜스를 한 번 돌린다. 펜스 앞에 `spec_path='<절대 경로로 바꾼 설계문서 경로>' bundle_arg='<--bundle 값, 없으면 빈 값>' repo_root='<감시줄 root= 값>'` 한 줄을 붙여 같은 Bash 호출로 돌린다. `--bundle` 은 리뷰어에게 가지 않는다 — 리뷰어는 설계문서 frontmatter `source_interview` 로 정답 출처에 닿고, 이 펜스는 그 값이 `source_interview` 와 같은 파일인지 확인해 진입 대조와 승인 때 로드맵 위치의 입력으로 쓴다.

<!-- bundle-entry:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라 — 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트)." >&2; exit 1; }
RETURN_MSG="[spec-distill] 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트)."
be_rc=0
be_out="$(python3 "$SD/scripts/spec_review_bundle.py" entry --spec "${spec_path:-}" --bundle "${bundle_arg:-}" --root "${repo_root:-}" 2>&1)" || be_rc=$?
be_last="$(printf '%s\n' "$be_out" | tail -n 1)"
case "$be_last" in
  "bundle-entry: REFUSE")
    printf '%s\n' "$be_out" | sed '$d'
    printf '%s\n' "$RETURN_MSG" "$be_last" ;;
  "bundle-entry: PROCEED "*)
    printf '%s\n' "$be_out" ;;
  *)
    [ -n "$be_out" ] && printf '%s\n' "$be_out"
    echo "[spec-distill] 번호 대조 진입 검사가 실패했다(rc $be_rc) — --bundle 확인과 번호 대조 없이 리뷰한다."
    echo "번호 대조 경고 1개"
    echo "bundle-entry: PROCEED -" ;;
esac
```
<!-- bundle-entry:end -->

마지막 줄이 `bundle-entry: REFUSE` 면 펜스가 낸 `[spec-distill]` 두 줄(쓸 수 없는 사유 · 복귀 문장)을 그대로 보이고 게이트 없이 끝낸다 — `### 대상 부재` 와 같은 예외 경로다. `bundle-entry: PROCEED` 면 그 앞 줄들(번호 대조 출력)을 사용자에게 그대로 보이고 리뷰를 시작한다. `번호 대조 경고 <N>개` 의 N 과 `PROCEED` 뒤의 경로(`-` 면 없음)는 `## 게이트` 가 쓴다. 번호 대조가 「검사 불가」여도 리뷰는 계속한다 — 사람이 보는 경고이지 리뷰의 정답이 아니다.
````
  - `## 게이트` 의 「승인 게이트를 띄우기 직전에 `$spec_path` 가 working-tree 에 있는지 다시 본다 …」 문단 바로 앞에 아래를 넣는다:

````markdown
**번호 대조 경고 — 라운드 · 승인 게이트 모두.** `## 입력` 의 진입 펜스가 낸 번호 대조 줄은 게이트 앞 글에 엔진 렌더 첫 줄 다음으로 그대로 다시 싣고, `번호 대조 경고 <N>개` 의 N 을 질문의 「경고 N개 — 위에 적었다」의 N 에 더한다. 그 N 이 0 이 아니면 「이상 없음」·「경고 없음」을 쓰지 않는다. 번호 대조 경고는 degrade 가 아니라 정답 출처 대조의 경고다 — 채널은 진입 펜스의 출력이다.

**로드맵 속 위치와 이웃 결정 — 2단계 질문 바로 앞.** 진입 펜스의 `PROCEED` 뒤 경로가 `-` 가 아니면 아래 펜스를 돌려 출력을 게이트 앞 글의 맨 끝(질문 바로 앞)에 그대로 싣는다. 출력이 없으면(brief · 로드맵 밖) 아무것도 싣지 않는다. 펜스 앞에 `bundle_path='<PROCEED 뒤 경로>' repo_root='<감시줄 root= 값>'` 한 줄을 붙인다.

<!-- roadmap-position:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라 — 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트)." >&2; exit 1; }
if [ -n "${bundle_path:-}" ] && [ "${bundle_path}" != "-" ]; then
  python3 "$SD/scripts/spec_review_bundle.py" neighbors --bundle "${bundle_path}" --root "${repo_root:-}" \
    || echo "[spec-distill] 로드맵 속 위치를 보일 수 없다 — 스크립트가 실패했다."
fi
```
<!-- roadmap-position:end -->
````
  - `**다음 세션 줄 — ①/② 공통**` 아래 인용 줄을 아래 한 줄로 바꾼다(인용 줄 안에 백틱 없음, `${CLAUDE_PLUGIN_ROOT}` 는 SKILL 본문이라 하니스가 치환한다):

```markdown
> `@<spec_path> 이 설계문서로 Skill superpowers:writing-plans 를 시작하라. confirmed 항목은 근거 있으면 보고 후 재결정 가능하고 임의 변경은 금지다. 계획을 쓴 뒤 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_bundle_coverage.py --plan <spec_path> 뒤에 계획 경로를 붙여 돌리고, 계획에 없는 AC 는 계획에 더한다. SDD 의 마지막 전체 리뷰에 이 설계문서 ## Acceptance Criteria 의 AC 목록을 싣고, 리뷰가 AC 마다 한 줄씩 AC1: 구현됨 — 근거 꼴(판정은 구현됨 · 미룸 · 빠짐 중 하나)로 보고하게 해 그 보고를 git 이 추적하지 않는 파일에 적는다. 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 ## 미룸 표(항목 · 이유 · 받는 곳)에 올리고, PR 을 만들기 전에 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_bundle_coverage.py --impl <spec_path> 뒤에 보고 파일 경로를 붙여 돌려 경고를 사용자에게 보인다. 사람에게 쓰는 글 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 첫 줄에 상태, 끝에 할 일 하나)을 지킨다.`
```
  - 그 아래 치환 문단의 「`<spec_path>` 는 `## 입력` 에서 바꾼 설계문서의 절대경로로 치환한 뒤 노출한다.」를 「`<spec_path>` 는 세 자리 모두 `## 입력` 에서 바꾼 설계문서의 절대경로로 치환한 뒤 노출한다.」로 바꾼다. 이 줄은 ①/② 에만 노출된다(③ · ④ 는 노출하지 않는다 — 그대로).
  - dispatch 블록 둘(`Agent({...})`)과 `<!-- codex-gate -->` · `<!-- profile-content -->` 펜스는 한 글자도 바꾸지 않는다.

- [ ] **Step 5: 통과 확인** — `test_spec_review_bundle.sh` · `test_review_handoff_order.sh` · `test_next_session_command.sh` · `test_reviewing_spec_entry_fence.sh` · `test_reviewing_spec_disclosure.sh` · `test_reviewing_spec_residue.sh` · `test_reviewing_spec_design_only.sh` · `test_proceed_gate_adopters.sh` · `test_plain_gate_templates.sh` · `test_stale_terms.sh` · `test_no_wall_clock.sh` · `shared/tests/test_invocation_surface.sh` · `test_inline_python_isolated.sh` · `test_plugin_root_no_cwd_fallback.sh` · `test_skill_body_no_positional_tokens.sh` · `test_dispatch_disposition.sh` · `test_docreview_round_gate_split.sh` · `test_adjudication_wiring.sh` · `test_docreview_procedure_paths.sh` · `test_variant_of_contract.sh` · `test_docreview_advice_procedure.sh` 실패 0. `git -C <worktree> diff HEAD~1 -- plugins/spec-distill/skills/spec-review/SKILL.md` 에서 `Agent({` 블록 줄이 바뀌지 않았는지 본다.

- [ ] **Step 6: 커밋** — `feat(spec-distill): spec-review 가 --bundle 을 확인하고 진입 대조 · 로드맵 위치 · 계획 · 구현 대조 안내를 싣는다` (트레일러 셋).

---

### Task 8: design-doc 프로필의 정답 출처 모드

설계 §4-3 · AC13. dispatch 슬롯 · `references/reviewing-document.md` · codex 러너는 바꾸지 않는다.

**Files:**
- Modify: `plugins/spec-distill/references/docreview-profiles/design-doc.md`
- Create: `plugins/spec-distill/tests/test_design_profile_source.sh` (100755)

- [ ] **Step 1: 실패하는 테스트 — 새 `test_design_profile_source.sh`** *(계획이 쓴 테스트 코드 — 리뷰어는 이것도 검사한다)*:

```bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/references/docreview-profiles/design-doc.md
#
# R3 AC13 — design-doc 프로필이 정답 출처를 설계문서 `source_interview` 파일의 종류로 정한다(묶음 · brief · 기존 §2).
# 정답 출처를 말하는 세 자리(ground_truth · 층 1 첫 문장 · 층 1 판정 관계 줄)가 같은 모드 문장이고, 깊이 판정이
# scope 축 설명에 붙는다. layer_rubric 은 그대로다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
P="$ROOT/plugins/spec-distill/references/docreview-profiles/design-doc.md"
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/references/docreview-profiles/design-doc.md"
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
GT="$(grep -E '^ground_truth: ' "$P" || true)"
for n in 'source_interview' '`epic-bundle` 이면 묶음 모드' '`interview-brief` 면 brief 모드' '§3 열린 질문 · §4 조사 · §5 위험' '그 밖의 종류면 brief §2 확정 항목'; do
  assert_contains "$GT" "$n" "AC13: ground_truth 에 「$n」"
done
L1="$(awk '/^## 층 1 — /{f=1;next} f&&NF{print;exit}' "$P")"
for n in 'source_interview' 'epic-bundle' 'interview-brief'; do
  assert_contains "$L1" "$n" "AC13: 층 1 첫 문장이 모드 문장이다 — 「$n」"
done
REL="$(grep -F '**층 1 판정 관계** —' "$P" || true)"
assert_contains "$REL" "같은 정답 출처 파일의 §1 Goal" "AC13: 판정 관계 줄의 과설계 기준이 정답 출처 파일의 §1 Goal"
assert_not_contains "$REL" "브리프 §2 확정 항목" "AC13: 판정 관계 줄이 정답 출처를 brief §2 하나로 적지 않는다"
assert_file_absent "$P" '정답의 출처는 인터뷰 브리프 §2 의 확정 항목이다' "AC13: 옛 층 1 첫 문장이 없다(한 프로필에 정답 출처 두 가지 금지)"
assert_file_grep "$P" '^- `scope` — .*번호 대조 표의 반영 칸이 가리킨 자리가 그 번호에 실제로 답하는가' "AC13: 깊이 판정이 scope 축 설명에 붙는다"
assert_file_grep "$P" '^  layer1: \[goal_fit, problem_definition, scope, architecture, component_relations, data_flow, tradeoffs, feasibility, overdesign\]$' "layer_rubric layer1 은 그대로"
finish
```

- [ ] **Step 2: 실패 확인.**

- [ ] **Step 3: `design-doc.md` 를 고친다.**
  - frontmatter `ground_truth:` 줄 전체를:

```yaml
ground_truth: "설계문서 frontmatter `source_interview` 가 가리키는 파일 — `type` 이 `epic-bundle` 이면 묶음 모드(번호 항목 · 이 에픽의 몫 · 사용자 원문), `interview-brief` 면 brief 모드(§2 확정 항목과 §3 열린 질문 · §4 조사 · §5 위험), `source_interview` 가 없거나 그 밖의 종류면 brief §2 확정 항목"
```
  - 층 1 첫 문장 「정답의 출처는 인터뷰 브리프 §2 의 확정 항목이다. 문서가 그 확정과 **하나의 그림**으로 정합한지 본다.」를:

```markdown
정답의 출처는 설계문서 frontmatter `source_interview` 가 가리키는 파일이고, 그 파일의 `type` 이 모드를 정한다 — `epic-bundle` 이면 묶음(번호 항목 · 이 에픽의 몫 · 사용자 원문), `interview-brief` 면 brief 의 §2 확정 항목과 §3 열린 질문 · §4 조사 · §5 위험, 없거나 그 밖의 종류면 brief §2 확정 항목이다. 문서가 그 정답 출처와 **하나의 그림**으로 정합한지 본다.
```
  - 「**층 1 판정 관계** —」 줄 전체를:

```markdown
**층 1 판정 관계** — 문서가 `ground_truth`(위 모드가 정한 정답 출처)와 **하나의 그림으로 정합한가**. 어긋남은 문서 쪽의 결함이다. 단 `overdesign` 은 정합이 아니라 **과함**을 잰다 — 기준이 정답 출처의 확정이 아니라 **같은 정답 출처 파일의 §1 Goal**(묶음 모드면 묶음 `## 1. Goal · Non-goal` — 이 에픽의 Goal · 공통 목표)이라, 이 축만 정답 출처의 확정 자체를 의심할 수 있다.
```
  - `- \`scope\` —` 줄 끝에 한 문장을 붙인다: ` 번호 대조 표의 반영 칸이 가리킨 자리가 그 번호에 실제로 답하는가도 본다 — 얕으면 고칠 자리를 적어 낸다.`
  - `overdesign` 불릿 · 「층 1 `overdesign` — 설계자 시선」 절 본문은 바꾸지 않는다(R2 의 몫).

- [ ] **Step 4: 통과 확인** — `chmod +x`. 새 테스트 · `test_overdesign_rubric.sh` · `shared/tests/test_docreview_profiles.sh` · `test_docreview_profile_schema.sh` · `test_docreview_layer1_wiring.sh` · `test_docreview_codex.sh` · `test_docreview_golden.sh` · `test_dispatch_profile_inline.sh` · `test_no_new_duplication.sh` 실패 0.

- [ ] **Step 5: 커밋** — `feat(spec-distill): 설계문서 리뷰의 정답 출처를 source_interview 파일 종류로 정한다` (트레일러 셋). 새 테스트 `100755` 확인.

---

### Task 9: README · CHANGELOG · 버전

AC16.

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` (`5.5.0` → `5.6.0`)
- Modify: `plugins/spec-distill/CHANGELOG.md` (`## [5.6.0] — 2026-10-15` 를 맨 위에)
- Modify: `plugins/spec-distill/README.md` (`## 로드맵 · 에픽 묶음` · `## Principles Instantiated`)

- [ ] **Step 1: 버전 재측정** — `git -C <worktree> show origin/main:plugins/spec-distill/.claude-plugin/plugin.json` 의 version 을 본다. 5.5.0 이면 5.6.0, 이미 올라갔으면 그 minor + 1.

- [ ] **Step 2: CHANGELOG** — 맨 위(`# Changelog` 아래)에:

```markdown
## [5.6.0] — 2026-10-15

### Added
- `check_bundle_coverage.py` 번호 대조가 반영 칸의 자리(`§<n>` · `§<n>-<m>` · `AC<n>` · 설계문서 제목)를 확인해 「얕은 답」을, 기각 칸의 에픽 번호가 로드맵에 있는지를, 기각한 발화를 다른 에픽이 받드는지를 센다. 셋은 종료 코드를 바꾸지 않는 경고 줄이고 첫 줄 · `--json`(`shallow` · `unserved` · `unknown`)이 말한다. 받듦은 배정만으로 세지 않는다 — 그 에픽의 설계문서가 기각했으면 받들지 않는다.
- 첫 인자가 interview brief 면 brief 의 모든 번호(`roadmap_status.py` 와 같은 집합)로 대조한다.
- `check_bundle_coverage.py --plan <설계문서> <계획>` — 계획 `### Task` 절에 없는 AC. `--impl <설계문서> <보고 파일>` — 구현 보고(`AC<n>: 구현됨|미룸|빠짐 — <한 줄>`)의 미룸 · 빠짐이 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 없거나 받는 곳이 없음인 것.
- `roadmap_status.py` 가 에픽 설계문서 `## 미룸` 의 받는 곳 없는 행을 그 에픽의 경고로 낸다(머지 뒤에도). 표가 깨지면 검사 불가.
- `spec-review <설계문서> --bundle <에픽 묶음|brief>` — 값이 설계문서 `source_interview` 와 같은 파일인지 확인하고(아니면 리뷰하지 않는다), 진입에서 번호 대조를 보여 그 경고 수를 게이트의 「경고 N개」에 더하며, 에픽 묶음이면 승인 게이트 앞에 로드맵 속 위치와 이웃 에픽의 사용자 결정 줄을 보인다(`scripts/spec_review_bundle.py`).
- `references/epic-handoff.md` — 로드맵 에픽의 설계를 여는 넘김 줄(묶음 첨부 · 로드맵 경로 · 에픽 번호 · `--bundle`).
- 공유 모듈 `scripts/roadmap_model.py` — 번호 문법 · 로드맵 해석 · brief 번호 계산을 두 스크립트가 함께 쓴다.

### Changed
- interview 의 다음 세션 줄이 brainstorming 의 「다음은 writing-plans 뿐」 지시를 덮어쓰는 문장을 뺐다. 대신 brief 의 §3 열린 질문 · §4 조사 · §5 위험까지 번호째 읽게 하고, 설계문서에 번호 대조 표와 `source_interview` 를 두게 하며, spec-review 를 `--bundle <brief>` 로 부르고, 계획 뒤 `--plan` · PR 전 `--impl` 대조를 시킨다. spec-review 의 writing-plans 다음 세션 줄도 `--plan` · `--impl` 지시를 싣는다.
- 설계문서 리뷰 프로필(`design-doc.md`)의 정답 출처가 설계문서 `source_interview` 파일의 종류로 정해진다 — 에픽 묶음이면 묶음, brief 면 §2~§5, 없으면 지금처럼 brief §2. 번호 대조 표의 반영 칸이 실제로 답하는지를 scope 축이 본다.
```

- [ ] **Step 3: README** — `## 로드맵 · 에픽 묶음` 의 `check_bundle_coverage.py` 줄을 아래 넷으로 바꾸고, `## Principles Instantiated` 끝에 한 줄을 더한다:

```markdown
- `scripts/check_bundle_coverage.py <묶음|brief> <설계문서>` — 정답 출처의 번호가 설계문서 `## 번호 대조` 표에 다 있는지(빠지면 종료 코드 1), 반영 칸이 설계문서의 실제 자리를 가리키는지 · 기각한 번호를 받드는 에픽이 있는지(경고 줄 — 종료 코드는 그대로) 봅니다. 로드맵을 못 찾으면 그 항목은 「셀 수 없음」으로 셉니다.
- `scripts/check_bundle_coverage.py --plan <설계문서> <계획>` · `--impl <설계문서> <보고 파일>` — 설계문서 AC 가 계획 Task 에 다 있는지, 구현 보고의 미룸 · 빠짐이 설계문서 `## 미룸` 표에 받는 곳과 함께 올랐는지 봅니다.
- `scripts/spec_review_bundle.py` — `spec-review <설계문서> --bundle <묶음|brief>` 의 정답 출처 확인 · 진입 대조 · 승인 때 로드맵 위치와 이웃 결정.
- `references/epic-handoff.md` — 로드맵 에픽의 설계를 여는 넘김 줄. 지휘 세션이 자리표를 채워 씁니다.
```

```markdown
- **Law 1 · Law 3 — 번호 인계 (5.6.0)** — brief · 에픽 묶음의 번호가 설계문서 · 계획 · 구현으로 넘어가는 이음매마다 기계 대조가 있다: 번호 대조(빠짐은 리뷰 전에 막고, 얕음 · 받드는 에픽 없음은 승인 때의 경고) · `--plan` · `--impl` · `roadmap_status.py` 의 받는 곳 없는 미룸 경고. 외부 skill(brainstorming · writing-plans · SDD)은 고치지 않는다 — 넘길 때 보내는 글과 돌아온 결과 검사만 devbrew 쪽에 있다. 내용이 실제로 답하는지는 리뷰어(design-doc 프로필의 scope 축)가 판정한다.
```

- [ ] **Step 4: 통과 확인** — `test_readme_sync.sh` · `shared/tests/test_changelog_integrity.sh` · `shared/tests/test_plugin_description_parity.sh` · `test_no_new_duplication.sh` 실패 0.

- [ ] **Step 5: 커밋** — `chore(spec-distill): 5.6.0 — 번호 인계 · 대조 · 깊이` (트레일러 셋).

---

### Task 10: 끝에서 끝 · 실데이터 · 스위트 비교

설계 Verification Plan. 끝에서 끝 절은 테스트로 남기고, 실데이터 · 스위트 비교는 측정해 ledger 에 적는다.

**Files:**
- Modify: `plugins/spec-distill/tests/test_roadmap_status.sh` (끝에서 끝 절)

- [ ] **Step 1: 끝에서 끝 절** — `test_roadmap_status.sh` 의 6b 절 뒤에 *(계획이 쓴 테스트 코드 — 리뷰어는 이것도 검사한다)*:

```bash
# ── 6c. 끝에서 끝(R3 Verification) — 묶음 → 설계문서(얕은 행 하나) → spec-review 진입 → 계획(AC 하나 빠짐)
#        → --plan → ## 미룸 → --impl → roadmap_status 경고 ─────────────────────────────
mkdir -p "$W/docs/rm7"
bundle docs/rm7 G7 "C1, D2, OQ1, RC1, ST1, «k1», K1, K2, S1, S2"
{ roadmap_head; block G7 feature/g7 없음 없음; roadmap_tail ""; } > "$W/docs/rm7/roadmap.md"
g checkout -q main; g add -- docs/rm7 && g commit -qm "rm7" && g push -q origin main
g checkout -q -b feature/g7 main; mkdir -p "$W/docs/superpowers/specs" "$W/docs/superpowers/plans"
printf -- '---\nsource_interview: docs/rm7/G7.md\n---\n\n# G7 설계\n\n### §1 절\n\n1. 하나\n\n## Acceptance Criteria\n\n- AC1 하나\n- AC2 둘\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| C1 · D2 · OQ1 · RC1 · ST1 · «k1» · K1 · K2 · S1 | 반영 | §1 · AC1 |\n| S2 | 반영 | 자리를 말하지 않는다 |\n\n## 미룸\n\n| 항목 | 이유 | 받는 곳 |\n|---|---|---|\n| AC2 | 다음에 | 없음 |\n' > "$W/docs/superpowers/specs/g7-design.md"
printf '# 계획\n\n**Spec:** `docs/superpowers/specs/g7-design.md`\n\n### Task 1: 하나\n\n- AC1\n' > "$W/docs/superpowers/plans/g7.md"
g add -- docs/superpowers && g commit -qm "g7 설계 · 계획"; g checkout -q main
g checkout -q feature/g7
E2E="$(cd "$W" && python3 "$S/spec_review_bundle.py" entry --spec docs/superpowers/specs/g7-design.md --bundle docs/rm7/G7.md --root "$W")"
assert_contains "$E2E" "얕은 답 — S2: 가리킨 자리가 없다" "끝에서 끝: spec-review 진입이 얕은 행을 보인다"
assert_contains "$E2E" "번호 대조 경고 1개" "끝에서 끝: 경고 수 1"
PLN="$(cd "$W" && python3 "$S/check_bundle_coverage.py" --plan docs/superpowers/specs/g7-design.md docs/superpowers/plans/g7.md)"; rc=$?
assert_eq "$rc:$PLN" "1:계획 대조: 계획에 없는 AC 1개 — AC2" "끝에서 끝: --plan 이 빠진 AC2 를 잡는다"
printf 'AC1: 구현됨 — 됐다\nAC2: 미룸 — 다음에\n' > "$T/g7-report.md"
IMP="$(cd "$W" && python3 "$S/check_bundle_coverage.py" --impl docs/superpowers/specs/g7-design.md "$T/g7-report.md")"
assert_contains "$IMP" "받는 곳 없는 미룸 — AC2" "끝에서 끝: --impl 이 받는 곳 없는 미룸을 잡는다"
g checkout -q main
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm7/roadmap.md > "$T/g7.json")
assert_eq "$(stage "$T/g7.json" G7)" "계획" "끝에서 끝: G7 은 계획 단계"
assert_contains "$(warns "$T/g7.json" G7)" "받는 곳 없는 미룸 1개: docs/superpowers/specs/g7-design.md — AC2" "끝에서 끝: roadmap_status 가 같은 미룸을 경고한다"
```
  돌려서 실패 0 을 확인하고 커밋한다 — `test(spec-distill): 번호 인계 끝에서 끝 픽스처` (트레일러 셋). (이 절은 Task 2~7 의 결과를 함께 재는 통합 단언이다 — 실패하면 앞 Task 의 결함이다. 그 Task 의 코드를 고치고 이 절은 약하게 고치지 않는다.)

- [ ] **Step 2: 실데이터 측정(코드 변경 없음 — ledger 에 기록)** — 리포 루트에서:
  - `python3 plugins/spec-distill/scripts/check_bundle_coverage.py docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R1.md docs/superpowers/specs/2026-10-12-interview-persistent-explore-design.md` (R1 묶음 · R1 설계문서)
  - `python3 plugins/spec-distill/scripts/check_bundle_coverage.py docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R3.md docs/superpowers/specs/2026-10-15-numbered-handoff-coverage-design.md` (이 에픽 자신)
  - `python3 plugins/spec-distill/scripts/check_bundle_coverage.py docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md` (R0 — `source_interview` 가 brief 라 brief 모드. R0 표는 자기 몫 번호만 싣으므로 빠진 번호가 많이 나오는 것이 정상이다 — 수만 적는다)
  - R7 설계문서 — `git -C <worktree> ls-remote origin feature/state-storage-redesign` 가 비면 「설계문서 없음(브랜치가 origin 에 없다)」으로 적는다.
  - 각 결과 첫 줄과 얕은 답 · 받드는 에픽 없는 발화 번호를 `~/.claude/sdd-mirror/r3-impl/real-data.txt` 에 적는다. R1 이 0 이 아니면 R1 문서를 고치지 않는다 — PR 본문 「후속」에 「R1 설계문서를 고칠지 사용자에게 묻는다」로 싣는다(설계 Verification Plan). R3 자신이 0 이 아니면(얕은 답 등) 그 행을 이 브랜치에서 고친다(이 에픽의 설계문서다).

- [ ] **Step 3: 스위트 비교** — `bash ~/.claude/sdd-mirror/r3-impl/run_suite.sh ~/.claude/sdd-mirror/r3-impl/after-task10.txt` 를 돌려 기준선(`baseline-before.txt`)과 FAIL «이름» 집합을 비교한다(`comm -13 baseline-before.txt after-task10.txt` 가 비어야 한다). 새 이름이 있으면 그 테스트를 고친 Task 로 돌아가 고친다. 결과를 ledger 에 적는다.

- [ ] **Step 4: AC13 diff 0 확인** — `git -C <worktree> diff --stat origin/main...HEAD -- plugins/spec-distill/references/reviewing-document.md shared/docreview/ plugins/spec-distill/scripts/run_docreview_codex_reviewer.sh` 가 비어야 한다. 비지 않으면 그 변경을 되돌린다.
