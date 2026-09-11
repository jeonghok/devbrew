# depth audit 제거 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill 인터뷰에서 Step A.7 사후 깊이 측정 전체와 «직전 답에서» 라운드 형식을 제거하고, 라운드를 «지금 이해 / 다음 결정 / 질문 하나»로 대체한다 — 기준선 대비 새 실패 0 으로 검증하고 major 로 출하한다.

**Architecture:** 삭제는 서로를 가리키는 묶음이 한 커밋에 들어가야 테스트가 깨지지 않으므로(C1) 측정 층을 먼저 원자 커밋으로 걷어 내고, 그 다음 SKILL 산문(라운드 규약 → 옮겨 가는 규칙 → seed 문단 → README)을 갈아 끼운 뒤, 마지막에 부재 락(stale-term 축)을 세운다. 부재 락이 마지막인 이유는 그 락이 모든 산문 교체가 끝난 상태에서만 GREEN 이기 때문이다. 매 task 커밋마다 리포 밖(gitignore 된 `.claude/rda/`)의 판정기로 «완료 − 기준선» 실패 멀티셋이 빈지 잰다.

**Tech Stack:** bash(테스트 셸 — shebang `/usr/bin/env bash`) · python3 3.9(시스템 — PEP 604 표기 금지, `from __future__ import annotations`) · git · 마크다운(모델이 읽는 SKILL 산문).

**Spec:** `docs/superpowers/specs/2026-09-10-remove-depth-audit-design.md` (커밋 `c8f70ac8`). 실행자는 이 계획과 설계를 함께 읽는다 — 이 계획의 «설계 C<n> · AC<n> · V<n> · §<n>» 는 그 문서의 절·항목 번호다.

## 목차

- [Global Constraints](#global-constraints)
- [파일 지도](#파일-지도)
- [작업 흐름](#작업-흐름)
- [Tasks](#tasks)
  - [Task 1: 기준선 수집기와 기준선](#task-1-기준선-수집기와-기준선)
  - [Task 2: 사람 e2e 실행 여부 확인](#task-2-사람-e2e-실행-여부-확인)
  - [Task 3: 사후 측정 층 원자 삭제](#task-3-사후-측정-층-원자-삭제)
  - [Task 4: 라운드 규약 대체](#task-4-라운드-규약-대체)
  - [Task 5: 옮겨 가는 규칙](#task-5-옮겨-가는-규칙)
  - [Task 6: seed 문단 소비 자리](#task-6-seed-문단-소비-자리)
  - [Task 7: README와 command 문구](#task-7-readme와-command-문구)
  - [Task 8: stale-term 축](#task-8-stale-term-축)
  - [Task 9: 사람 e2e](#task-9-사람-e2e)
  - [Task 10: 브랜치 전체 리뷰](#task-10-브랜치-전체-리뷰)
  - [Task 11: 릴리스](#task-11-릴리스)
- [설계 대조표](#설계-대조표)

## Global Constraints

모든 task 의 요구사항은 이 절을 암묵적으로 포함한다.

**작업 공간**
- 워크트리 `WT` = `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+remove-depth-audit`, 브랜치 `feature/remove-depth-audit`. 설계 시점 base 는 `e5234326`(spec-distill 1.0.1)이고, 계획 작성 시점 `origin/main` 은 `efb8aa16`(1.1.0 — #151 이 `references/steelman.md` Step 3 질문 줄 · stage 테스트 R3 블록 +41줄 · `plugin.json` · CHANGELOG 를 바꿨다)이다. **Task 1 이 그것을 먼저 merge 한다** — 이 계획의 문자열 · 기대 개수는 그 merge 뒤 트리로 모의 실행해 확인했다. 계획에 적힌 행 번호는 설계 시점 base 기준이라 merge 뒤 밀린 곳이 있다 — 편집 위치는 행 번호가 아니라 앵커 문자열로 찾는다. **모든 명령은 WT 에서 돈다. 메인 체크아웃(`/Users/jeonghokim/Downloads/devbrew`)으로 `cd` 하지 않는다** — 다른 세션이 그 체크아웃을 쓰며 브랜치를 바꾼다.
- Read/Edit/Write 도구의 `file_path` 는 **항상 WT 절대경로**다(이 계획은 가독성 때문에 WT 기준 상대경로로 적는다 — 도구에 넘길 때 `WT/` 를 붙인다). 상대경로를 쓰면 같은 이름의 파일을 메인 체크아웃에 쓰는 사고가 난다.
- bare `git stash` / `git stash pop` 금지(스택을 다른 세션과 공유). 작업을 치워 둘 일이 있으면 임시 WIP 커밋.
- Bash 가드: 실행 시점 계산값(`$(...)`, 따옴표 없는 변수)과 반복문 안의 `bash` 실행은 거부된다. 명령은 **리터럴 경로의 평범한 명령**으로 쓴다. 여러 테스트를 도는 일은 `.claude/rda/collect.py` 가 맡는다. `$` 가 든 문자열을 변이·편집에 실어야 하면 Write 도구로 파일에 쓰고 `@<파일>` 로 넘긴다(Task 1 의 `mutate.py`).
- 커밋 메시지는 Write 도구로 `.claude/rda/msg-<task>.txt` 에 쓰고 `git commit -F .claude/rda/msg-<task>.txt` 로 커밋한다(heredoc-in-`$()` 금지). 형식은 Conventional Commits `<type>(spec-distill): <설명>` 이고 끝에 두 줄:
  ```
  Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01Um5Znb7UcRUQ4SP3u3TobS
  ```
- push · PR 생성은 사용자 승인 뒤에만(Task 11 마지막 단계).

**설계 제약 (원문 요약 — 값은 설계 그대로)**
- **C1 원자 삭제 단위**: 커밋마다 기준선 대비 새 실패 0. `agents/depth-auditor.md` · `scripts/depth_pairs.py` · `scripts/depth_record.py` · 그 테스트 3개와 fixture 11개 · `finishing.md` Step A.7 절과 B-2 깊이 슬롯 · audit 템플릿 §2 깊이 줄 · stage 테스트의 A.7 · B-2 깊이 · 템플릿 깊이 줄 락 · `test_finishing_block_scope.py` 양성 대조 · `test_brief_agents.sh` 격리 목록 · `COMP_BASELINE` · `docs/superpowers/interview/depth/.gitkeep` 은 **한 커밋**(Task 3).
- **C2 버전**: 머지 직전 `origin/main` 을 **merge**(rebase 아님)하고 `plugin.json` 을 그 시점 main 의 spec-distill 보다 **한 major 위**로(계획 작성 시점 main 1.1.0 → 2.0.0). CHANGELOG 최상단 헤딩이 같은 값. 버전은 Task 11 에서만 바꾼다.
- **C3 Deprecated**: CHANGELOG `### Deprecated` 에 one-minor deprecation window 와의 충돌을 적고 «제3자 설치 없음(사용자 확인, 2026-09-10)» 조건으로 수용, «제3자 설치가 생기면 다음 제거에는 창을 둔다» 조항.
- **C4 부재 락 + 양성 짝**: 제거 식별자의 부재는 `test_stale_terms.sh` 한 축으로 잰다(Task 8). README 는 제거 식별자를 인용하지 않고 개념으로 서술한다.
- **C5 락 규약**: 산문 락은 절 스코프 + 본문 고유 문구. 새로 쓰거나 고친 락은 변이(통째 삭제 · 문구 반전 · 값 변경)로 RED 확인. **변이 전에 커밋**하고 `git checkout -- <파일>` 로 복원(HEAD = 변이 전 상태). `PYTHONDONTWRITEBYTECODE=1`.
- **C6 기준선**: (파일, 실패 식별자) 멀티셋, 셸 파일마다 완료 증거, rc≠0 인데 단언이 없으면 `(파일, rc=<N>)`. 판정 «완료 − 기준선 = ∅». 머지 직전 `origin/main` merge 뒤에는 그 끝 커밋에서 기준선을 다시 잡는다.
- **C7**: `COMP_BASELINE` 은 `ast` 실측값(예상 52 는 값이 아니다). 리터럴 == 실측을 따로 확인한다.
- **C8 G7 어휘**: 새 SKILL 산문은 `4-block` · `막힌 결정` · `teach-lite` · `teach-heavy` · `teach-beat` · `general-purpose` 를 쓰지 않는다(예외는 `references/steelman.md` 하나).
- **C9**: `conducting-interview/SKILL.md` 는 388줄 미만이 된다.
- **설계와 main 의 어긋남 하나**: 설계 §2.2 의 «게이트의 고정 순서 · 추천 라벨 없음은 … 지킨다» 중 «추천 라벨 없음» 은 #151 이 출처별 추천 라벨(`(builder 추천)` 등)로 재결정했다. 이 계획의 라운드 규약 문구는 «`references/steelman.md` 가 묻는 질문은 그 파일의 규약을 따른다» 는 도출 규칙이라 그 변경과 모순하지 않고, #151 이 steelman 게이트에 금지한 `(권장)` 도 그 질문들에는 적용하지 않는다고 적는다. 설계문서는 고치지 않는다.
- **AC8 무변경**: `scripts/check_brief.py` · `hooks/*` · `skills/reviewing-brief/*` · `skills/reviewing-spec/*` · `agents/coverage-mapper.md` · `agents/steelman-builder.md` · `agents/blind-spot-prober.md` · 0.57.0 설계문서 · 과거 interview 문서는 건드리지 않는다.
- **새 production 산문에 쓰지 않는 토큰**(Task 8 이 락으로 굳힌다): 식별자 `depth_pairs` · `depth_record` · `depth-auditor` · `직전 답에서` · `provisional_on` · `깊이 측정`, 별칭 `되비추` · `되비춘` · `판정자 조건` · `판정자 투입`(README 는 별칭만 면제). CHANGELOG · `tests/` 는 스코프 밖이다.
- **Self-narrating artifact 금지**(CLAUDE.md): 모델이 읽는 SKILL · references · 템플릿에는 행동에 필요한 것만 둔다 — «0.57.0 에서 바뀌었다» 같은 이력·정당화는 CHANGELOG 에.
- 문서는 Korean-primary.
- 플러그인 안에 새 스크립트 · agent · kill switch 를 두지 않는다(NG6). 판정기 · 변이기 · 편집기는 `.claude/rda/` (gitignore `/.claude/*`)에 두고 커밋하지 않는다.

## 파일 지도

| 파일 (WT 기준) | 책임 | Task |
|---|---|---|
| `.claude/rda/collect.py` | 판정기 — 세 스위트 실행 · 기록 · 멀티셋 비교 · 양성 대조 (커밋 안 함) | 1 |
| `.claude/rda/mutate.py` | 변이기 — 정확히 한 번 나오는 문자열만 바꾼다 (커밋 안 함) | 1 |
| `.claude/rda/splice.py` | 구간 편집기 — 앵커 두 개 사이를 파일 내용으로 바꾼다 (커밋 안 함) | 1 |
| `plugins/spec-distill/agents/depth-auditor.md` | 삭제 | 3 |
| `plugins/spec-distill/scripts/depth_pairs.py` · `depth_record.py` | 삭제 | 3 |
| `plugins/spec-distill/tests/test_depth_pairs.py` · `test_depth_record.py` · `test_depth_auditor_frontmatter.sh` | 삭제 | 3 |
| `plugins/spec-distill/tests/fixtures/depth-state-*.md` (11) | 삭제 | 3 |
| `docs/superpowers/interview/depth/.gitkeep` | 삭제 | 3 |
| `plugins/spec-distill/skills/conducting-interview/references/finishing.md` | Step A.7 삭제 · B-2 깊이 슬롯 삭제(3) · 76행 발화(5) | 3, 5 |
| `plugins/spec-distill/templates/interview-audit-template.md` | §2 한 줄 | 3 |
| `plugins/spec-distill/skills/conducting-interview/references/state-migration.md` | 32행 | 3 |
| `plugins/spec-distill/skills/conducting-interview/SKILL.md` | 56행(3) · 도입부 · 라운드 규약 · `provisional_on`(4) · 닫힘 · 재개방 · blind-spot 전이 · C43(5) | 3, 4, 5 |
| `plugins/spec-distill/skills/conducting-interview/references/steelman.md` | 84–87행 삭제 | 4 |
| `plugins/spec-distill/skills/conducting-interview/references/seed-input.md` | 11–12행 | 6 |
| `plugins/spec-distill/skills/framing-requests/SKILL.md` | 44 · 46행 | 6 |
| `plugins/spec-distill/templates/interview-seed-template.md` | 41행 표 한 칸 | 6 |
| `plugins/spec-distill/README.md` | 108 · 136행(3) · 7 · 22 · 36 · 145행(7) | 3, 7 |
| `plugins/spec-distill/commands/interview.md` | 46행 | 7 |
| `plugins/spec-distill/tests/test_conducting_interview_stage.sh` | A.7 · B-2 깊이 · 템플릿 깊이 락 삭제(3) · 라운드 규약 락(4) · 닫힘 · 발화 · blind-spot · C43 락(5) · seed 락(6) | 3–6 |
| `plugins/spec-distill/tests/test_finishing_block_scope.py` | 양성 대조를 남는 펜스로 | 3 |
| `plugins/spec-distill/tests/test_brief_agents.sh` | `EXPECTED_ISOLATED` 5 → 4 | 3 |
| `shared/tests/test_adjudication_wiring.sh` | `COMP_BASELINE` 실측값 | 3 |
| `plugins/spec-distill/tests/test_request_framing_command.sh` | seed 문단 소비 락 | 6 |
| `plugins/spec-distill/tests/test_stale_terms.sh` | V13 축 · V10 목록 20 → 37 | 8 |
| `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/spec-distill/CHANGELOG.md` | 다음 major · 최상단 절 | 11 |

`depth` 를 문자열로 담은 다른 테스트 8개(`test_arm_ledger.py` · `test_brief_codex_axes.sh` · `test_brief_review_entry.sh` · `test_proceed_gate_adopters.sh` · `test_reviewing_brief_skill.sh` · `test_seed_agents.sh` · `shared/tests/test_docreview_mutations.sh` · `shared/tests/test_skill_reference_pointers.sh`)는 `defense-in-depth` · `-maxdepth` · 경로 «깊이» 같은 **다른 뜻**이다 — 계획 작성 시점(2026-09-10) 확인. 건드리지 않는다.

## 작업 흐름

```
T1 기준선 ─ T2 e2e 여부 ─ T3 측정 층 원자 삭제 ─ T4 라운드 규약 ─ T5 옮겨 가는 규칙
   ─ T6 seed 문단 ─ T7 README·command ─ T8 stale-term 축 ─ (T9 사람 e2e) ─ T10 브랜치 리뷰 ─ T11 릴리스
```

**매 구현 task(3–8)의 공통 마무리** — 각 task 의 마지막 단계들이 이 순서를 따른다:
1. 그 task 의 표적 테스트 GREEN.
2. 판정기로 전체 기록 → 기준선과 비교 → `판정: 새 실패 0 · 완료 증거 전부 있음` (AC10). RED 면 커밋하지 않고 고친다.
3. `git status --porcelain` 이 그 task 의 파일만 보인다(테스트가 남긴 부산물이 없다).
4. 커밋.
5. 새로 쓰거나 고친 락의 변이 — 변이마다 `mutate.py` 적용 → 표적 테스트에서 **그 단언 줄**이 ✗ 인지 확인 → `git checkout -- <파일>` → `git status --porcelain` 빈 출력.

**판정기 실행 규칙** — 셸 파일이 90개 가까이라 Bash 도구의 10분 상한을 넘을 수 있다. `collect` 는 `run_in_background: true` 로 실행하고 완료 알림을 기다린다(폴링하지 않는다). `compare` 는 즉시 끝난다.

**계획 모의 실행(2026-09-11)** — `origin/main`(`efb8aa16`) 트리를 `git archive` 로 뽑은 복사본(심볼릭 링크 보존)에 이 계획의 편집 · 락 · 변이를 그대로 적용해 확인했다: 편집 문자열 전부 정확히 1회 일치 · 변이 25건 전부 기대한 단언 하나만 RED(README 면제 1건은 GREEN 유지) · 판정기 양성 대조 4/4 · `COMP_BASELINE` 실측 52 · stage 222 → Task 3 뒤 208 → 최종 218 · stale-terms 77 · framing 41 · `test_check_brief.sh` · `test_adjudication_wiring.sh` GREEN · SKILL.md 336줄 · 잔존 스윕 0건. 복사본에서 못 돌린 것 — `test_dispatch_disposition.sh`(`git ls-files` 를 쓴다)와 전체 스위트. 둘은 Task 3 에서 워크트리로 처음 잰다.

**새 실패가 보고되면** 먼저 그 파일을 단독으로 두 번 돌려 재현한다(`bash <파일>`). 재현되면 회귀다 — 고친다. 재현되지 않으면(flaky) 그 파일을 기준선 커밋에서도 같은 방식으로 돌려 보고, 사실을 `.claude/rda/flaky.txt` 에 적어 Task 11 의 CHANGELOG Verification 에 옮긴다. 판정을 손으로 GREEN 으로 바꾸지 않는다.

## Tasks

### Task 1: 기준선 수집기와 기준선

**Files:**
- Create: `.claude/rda/collect.py`, `.claude/rda/mutate.py`, `.claude/rda/splice.py` (gitignore — 커밋 안 함)
- Create: `.claude/rda/base.json`, `.claude/rda/v0-before.txt`, `.claude/rda/base-movement.txt`
- Commit: `docs/superpowers/plans/2026-09-10-remove-depth-audit.md` (이 계획)

**Interfaces:**
- Consumes: 없음.
- Produces:
  - `python3 .claude/rda/collect.py collect --root <WT 절대경로> --out <json>` — 기록.
  - `python3 .claude/rda/collect.py compare <기준선.json> <완료.json> [--deleted <셸 경로>]... [--deleted-py <모듈>]...` — exit 0 = 새 실패 0 · 완료 증거 전부 · 의도 밖 소실 0. 마지막 줄 `판정: …`.
  - `python3 .claude/rda/collect.py selftest --root <WT 절대경로>` — 양성 대조 넷.
  - `python3 .claude/rda/mutate.py <파일> <OLD|@파일> <NEW|@파일>` — OLD 가 정확히 1번일 때만 바꾼다, 아니면 exit 2.
  - `python3 .claude/rda/splice.py <파일> <START 앵커> <END 앵커> <내용 파일|->` — START(포함)~END(제외)를 바꾼다. 앵커는 각각 정확히 1번 · 줄 머리여야 한다, 아니면 exit 2.
  - `.claude/rda/base.json` — 이후 모든 비교의 기준선(Task 11 의 merge 전까지).
  - 이후 task 가 쓰는 **의도 삭제 목록**(compare 인자): `--deleted plugins/spec-distill/tests/test_depth_auditor_frontmatter.sh --deleted-py test_depth_pairs --deleted-py test_depth_record`

- [ ] **Step 1: 이 계획을 커밋한다**

Write 도구로 `WT/.claude/rda/msg-plan.txt`:
```
docs(spec-distill): depth audit 제거 구현 계획

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Um5Znb7UcRUQ4SP3u3TobS
```
Run:
```bash
git add docs/superpowers/plans/2026-09-10-remove-depth-audit.md
git commit -F .claude/rda/msg-plan.txt
```
Expected: 커밋 1개, `git status --porcelain` 빈 출력(`.claude/` 는 gitignore).

- [ ] **Step 2: origin/main 을 merge 한다**

리뷰는 움직인 base 를 못 보고, 기준선은 merge 뒤 트리에서 잡아야 하므로(C6) 착수 전에 한다. rebase 가 아니라 merge 다.
```bash
git fetch origin
git log --oneline HEAD..origin/main
git diff --stat HEAD...origin/main -- plugins/spec-distill shared/tests docs/superpowers/interview
git merge --no-ff --no-edit origin/main
```
출력을 Write 도구로 `.claude/rda/base-movement.txt` 에 옮겨 적는다. 계획 작성 시점 기대: `origin/main` = `efb8aa16`, 겹치는 파일은 `plugin.json` · `CHANGELOG.md` · `references/steelman.md` · `tests/test_conducting_interview_stage.sh` 넷이고 충돌은 없다(이 브랜치는 설계 · 계획 문서만 더했다). **`origin/main` 이 `efb8aa16` 보다 더 움직였고 그 추가분이 [파일 지도](#파일-지도)의 파일을 건드리면 merge 뒤 멈추고 보고한다** — 그 변경은 이 계획의 모의 실행 밖이라 앵커 · 기대 개수가 틀릴 수 있다.

- [ ] **Step 3: 판정기를 쓴다**

Write 도구로 `WT/.claude/rda/collect.py`:
```python
#!/usr/bin/env python3
"""depth audit 제거 작업의 회귀 판정기 (설계 C6 · V1 · V2). 리포에 커밋하지 않는다.

  collect  --root <워크트리> --out <json>
  compare  <기준선.json> <완료.json> [--deleted <셸 경로>]... [--deleted-py <모듈>]...
  selftest --root <워크트리>

compare 는 아래가 전부 참일 때만 exit 0 이다.
  · 파일마다 실패 식별자 멀티셋의 «완료 − 기준선» = ∅
  · 모든 셸 파일에 완료 증거가 있다 — 요약 줄(`Total: N | Pass: P | Fail: F`)이 있거나,
    기준선에서도 요약 줄이 없던 파일이면 마지막 출력 줄이 기준선과 같다
  · 기준선에 있던 셸 파일 · unittest id 가 의도 삭제 목록 밖에서 사라지지 않았다
  · unittest 출력에 `Ran N tests` 줄이 있다
"""
from __future__ import annotations

import argparse
import collections
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

SUMMARY_RE = re.compile(r"^Total: \d+ \| Pass: \d+ \| Fail: \d+\s*$")
# 실패 줄 모양 — assert.sh 의 no()(✗) · 자체 헬퍼의 no()(NO) · [FAIL] · FAIL 접두.
FAIL_RES = (
    re.compile(r"^\s*(?:✗|NO)\s+(.*\S)\s*$"),
    re.compile(r"^\s*\[FAIL\]\s*(.*\S)\s*$"),
    re.compile(r"^\s*FAIL[: ]\s*(.*\S)\s*$"),
)
TMP_RE = re.compile(r"(?:/private)?/(?:tmp|var/folders)/[^\s'\"]*")
UT_RAN_RE = re.compile(r"^Ran (\d+) tests? in ")
UT_ID_RE = re.compile(r"^(test\w*) \(([\w.]+)\)")
UT_FAIL_RE = re.compile(r"^(FAIL|ERROR): (\S+) \(([\w.]+)\)(.*)$")
TIMEOUT = 900
EMPTY_UT = {"rc": 0, "n_ran": 0, "ran": [], "failures": [], "fail_lines": 0}


def norm(line, root):
    return TMP_RE.sub("<TMP>", line.replace(str(root), "<ROOT>")).strip()


def clean_env():
    # 사용자 셸의 kill switch · 플러그인 루트가 기준선과 이후 실행을 갈라놓지 않게 뺀다.
    env = {k: v for k, v in os.environ.items()
           if not k.startswith("DEVBREW_") and k != "CLAUDE_PLUGIN_ROOT"}
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    return env


def run(cmd, root):
    try:
        p = subprocess.run(cmd, cwd=str(root), stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, env=clean_env(), timeout=TIMEOUT)
        return p.stdout.decode("utf-8", "replace"), p.returncode
    except subprocess.TimeoutExpired as e:
        return (e.stdout or b"").decode("utf-8", "replace"), None


def run_shell(path, root):
    out, rc = run(["bash", str(path)], root)
    lines = out.splitlines()
    fails = []
    for ln in lines:
        for rx in FAIL_RES:
            m = rx.match(ln)
            if m:
                fails.append(norm(m.group(1), root))
                break
    summary = next((ln.strip() for ln in lines if SUMMARY_RE.match(ln.strip())), None)
    nonempty = [ln for ln in lines if ln.strip()]
    rec = {"rc": rc, "fail_lines": len(fails), "summary": summary,
           "last_line": norm(nonempty[-1], root) if nonempty else ""}
    if rc is None:
        fails.append("timeout")
    elif rc != 0 and not fails:
        fails.append("rc=%d" % rc)
    rec["failures"] = fails
    return rec


def _strip_name(cls, name):
    return cls[: -len(name) - 1] if cls.endswith("." + name) else cls


def run_unittest(root):
    out, rc = run(["python3", "-m", "unittest", "discover", "-s",
                   "plugins/spec-distill/tests", "-v"], root)
    ran, fails, n_ran = set(), [], None
    for ln in out.splitlines():
        m = UT_FAIL_RE.match(ln)
        if m:
            fails.append(norm("%s: %s.%s%s" % (m.group(1), _strip_name(m.group(3), m.group(2)),
                                               m.group(2), m.group(4)), root))
            continue
        m = UT_RAN_RE.match(ln)
        if m:
            n_ran = int(m.group(1))
            continue
        m = UT_ID_RE.match(ln)
        if m:
            ran.add("%s.%s" % (_strip_name(m.group(2), m.group(1)), m.group(1)))
    rec = {"rc": rc, "n_ran": n_ran, "ran": sorted(ran), "fail_lines": len(fails)}
    if n_ran is None:
        fails.append("rc=%s" % rc)
    rec["failures"] = fails
    return rec


def git(root, *args):
    return subprocess.run(["git", "-C", str(root)] + list(args), stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT).stdout.decode("utf-8", "replace").strip()


def collect(root, out):
    root = Path(root).resolve()
    shells = (sorted(root.glob("plugins/spec-distill/tests/test_*.sh"))
              + sorted(root.glob("shared/tests/test_*.sh")))
    data = {"root": str(root), "head": git(root, "rev-parse", "HEAD"),
            "dirty": git(root, "status", "--porcelain", "--untracked-files=no"),
            "shell": {}, "unittest": None}
    for p in shells:
        rel = str(p.relative_to(root))
        rec = run_shell(p, root)
        data["shell"][rel] = rec
        print("%-72s rc=%-4s 실패=%-3d %s" % (rel, rec["rc"], rec["fail_lines"],
              "요약" if rec["summary"] else "요약없음"), flush=True)
    data["unittest"] = u = run_unittest(root)
    print("unittest: Ran %s · 실패 %d · rc=%s" % (u["n_ran"], u["fail_lines"], u["rc"]), flush=True)
    Path(out).write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    n_fail = sum(len(r["failures"]) for r in data["shell"].values()) + len(u["failures"])
    print("기록: %s · 셸 %d개 · 실패 식별자 %d개 · head %s%s" % (
        out, len(shells), n_fail, data["head"][:8], " (DIRTY)" if data["dirty"] else ""))
    return 0


def compare(base, cur, deleted, deleted_py, quiet=False):
    problems, info = [], []
    bs, cs = base["shell"], cur["shell"]
    for rel in sorted(set(deleted) - set(bs)):
        problems.append("의도 삭제 목록의 파일이 기준선에 없다(목록 오타?): %s" % rel)
    for rel in sorted(set(bs) - set(cs)):
        if rel not in deleted:
            problems.append("사라진 셸 파일(의도 목록 밖): %s" % rel)
    for rel, rec in sorted(cs.items()):
        b = bs.get(rel)
        complete = rec["summary"] is not None or (
            b is not None and b["summary"] is None and rec["rc"] is not None
            and rec["last_line"] == b["last_line"])
        if not complete:
            problems.append("완료 증거 없음: %s (rc=%s · 마지막 줄 «%s»)"
                            % (rel, rec["rc"], rec["last_line"][:120]))
        base_f = collections.Counter(b["failures"] if b else [])
        cur_f = collections.Counter(rec["failures"])
        for fid, n in sorted((cur_f - base_f).items()):
            problems.append("새 실패: (%s, %s) ×%d" % (rel, fid, n))
        for fid, n in sorted((base_f - cur_f).items()):
            info.append("사라진 기준선 실패: (%s, %s) ×%d" % (rel, fid, n))
        if b and (b["rc"] != rec["rc"] or b["fail_lines"] != rec["fail_lines"]):
            info.append("보조: %s rc %s→%s · 실패 줄 %d→%d"
                        % (rel, b["rc"], rec["rc"], b["fail_lines"], rec["fail_lines"]))
    bu, cu = base["unittest"], cur["unittest"]
    if cu["n_ran"] is None:
        problems.append("unittest 완료 증거 없음(Ran 줄 부재, rc=%s)" % cu["rc"])
    for t in sorted(set(bu["ran"]) - set(cu["ran"])):
        if t.split(".")[0] not in deleted_py:
            problems.append("사라진 unittest(의도 목록 밖): %s" % t)
    base_u, cur_u = collections.Counter(bu["failures"]), collections.Counter(cu["failures"])
    for fid, n in sorted((cur_u - base_u).items()):
        problems.append("새 실패: (unittest, %s) ×%d" % (fid, n))
    for fid, n in sorted((base_u - cur_u).items()):
        info.append("사라진 기준선 실패: (unittest, %s) ×%d" % (fid, n))
    if not quiet:
        for ln in info:
            print(ln)
        for ln in problems:
            print("✗ " + ln)
        print("판정: %s (문제 %d건)" % (
            "새 실패 0 · 완료 증거 전부 있음" if not problems else "RED", len(problems)))
    return 1 if problems else 0


def selftest(root):
    root = Path(root).resolve()
    asrt = root / "shared" / "tests" / "assert.sh"
    results = []
    with tempfile.TemporaryDirectory(dir=str(root / ".claude" / "rda")) as td:
        td = Path(td)
        a = td / "t_noassert.sh"
        a.write_text("#!/usr/bin/env bash\nexit 1\n", encoding="utf-8")
        results.append(("대조 1 — 단언 없이 exit 1 → (파일, rc=1)",
                        run_shell(a, root)["failures"] == ["rc=1"]))
        full = td / "t_full.sh"
        full.write_text('#!/usr/bin/env bash\n. "%s"\nno "기존 실패 A"\nno "기존 실패 B"\nfinish\n'
                        % asrt, encoding="utf-8")
        cut = td / "t_cut.sh"
        cut.write_text('#!/usr/bin/env bash\n. "%s"\nno "기존 실패 A"\nexit 1\nno "기존 실패 B"\nfinish\n'
                       % asrt, encoding="utf-8")
        rf, rcut = run_shell(full, root), run_shell(cut, root)
        base = {"shell": {"x.sh": rf}, "unittest": EMPTY_UT}
        cur = {"shell": {"x.sh": rcut}, "unittest": EMPTY_UT}
        subset = not (collections.Counter(rcut["failures"]) - collections.Counter(rf["failures"]))
        results.append(("대조 2 — 기존 실패 하나 찍고 중단: 멀티셋 차는 ∅ 인데도 RED",
                        subset and compare(base, cur, [], [], quiet=True) == 1))
        results.append(("대조 3 — 같은 기록끼리는 GREEN (판정기가 전부 거부하지 않는다)",
                        compare(base, base, [], [], quiet=True) == 0))
        again = {"shell": {"x.sh": run_shell(full, root)}, "unittest": EMPTY_UT}
        results.append(("대조 4 — 같은 파일 재실행도 GREEN (식별자가 실행마다 흔들리지 않는다)",
                        compare(base, again, [], [], quiet=True) == 0))
    for name, passed in results:
        print("%s: %s" % (name, "통과" if passed else "실패"))
    return 0 if all(p for _, p in results) else 1


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("collect")
    c.add_argument("--root", required=True)
    c.add_argument("--out", required=True)
    m = sub.add_parser("compare")
    m.add_argument("base")
    m.add_argument("cur")
    m.add_argument("--deleted", action="append", default=[])
    m.add_argument("--deleted-py", action="append", default=[])
    s = sub.add_parser("selftest")
    s.add_argument("--root", required=True)
    a = ap.parse_args()
    if a.cmd == "collect":
        return collect(a.root, a.out)
    if a.cmd == "selftest":
        return selftest(a.root)

    def load(p):
        return json.loads(Path(p).read_text(encoding="utf-8"))
    return compare(load(a.base), load(a.cur), a.deleted, a.deleted_py)


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: 변이기와 구간 편집기를 쓴다**

Write 도구로 `WT/.claude/rda/mutate.py`:
```python
#!/usr/bin/env python3
"""변이 한 번: FILE 안의 OLD 가 정확히 한 번 나올 때만 NEW 로 바꾼다.

OLD · NEW 가 '@<경로>' 면 그 파일 내용(끝 줄바꿈 제거)을 쓴다 — 셸 인자에 `$` 를 싣지 않기
위해서다. 0회 · 여러 회면 exit 2: 변이가 실제로 일어났다는 것이 이 계측기의 양성 대조다.
되돌리기는 `git checkout -- FILE` (변이 전에 커밋했으므로 HEAD 가 곧 변이 전 상태다).
"""
import sys
from pathlib import Path


def arg(v):
    return Path(v[1:]).read_text(encoding="utf-8").rstrip("\n") if v.startswith("@") else v


def main():
    path, old, new = sys.argv[1], arg(sys.argv[2]), arg(sys.argv[3])
    p = Path(path)
    s = p.read_text(encoding="utf-8")
    n = s.count(old)
    if n != 1:
        sys.stderr.write("mutate: OLD 가 %s 에 %d번 — 정확히 1번이어야 한다\n" % (path, n))
        return 2
    p.write_text(s.replace(old, new), encoding="utf-8")
    print("mutate: %s 변이 적용" % path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Write 도구로 `WT/.claude/rda/splice.py`:
```python
#!/usr/bin/env python3
"""FILE 에서 START 앵커(포함)부터 END 앵커(제외)까지를 CONTENT 파일 내용으로 바꾼다.

CONTENT 가 '-' 면 그 구간을 지운다. 두 앵커는 각각 정확히 한 번 나오고 줄 머리에 있어야 하며
START 가 END 보다 앞이어야 한다 — 아니면 exit 2 (앵커가 틀린 편집은 조용히 엉뚱한 곳을 바꾼다).
내용의 끝 줄바꿈은 빈 줄 하나로 맞춘다(다음 헤딩 앞 빈 줄 유지).
"""
import sys
from pathlib import Path


def main():
    path, start, end, content = sys.argv[1:5]
    p = Path(path)
    s = p.read_text(encoding="utf-8")
    for a in (start, end):
        n = s.count(a)
        if n != 1:
            sys.stderr.write("splice: 앵커 %r 가 %s 에 %d번 — 정확히 1번이어야 한다\n" % (a, path, n))
            return 2
    i, j = s.index(start), s.index(end)
    for k in (i, j):
        if k > 0 and s[k - 1] != "\n":
            sys.stderr.write("splice: 앵커가 줄 머리에 있지 않다 (위치 %d)\n" % k)
            return 2
    if i >= j:
        sys.stderr.write("splice: START 가 END 보다 뒤다\n")
        return 2
    new = "" if content == "-" else Path(content).read_text(encoding="utf-8").rstrip("\n") + "\n\n"
    p.write_text(s[:i] + new + s[j:], encoding="utf-8")
    print("splice: %s — %d자 → %d자" % (path, j - i, len(new)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: 판정기의 양성 대조를 돌린다 (V1)**

Run: `python3 .claude/rda/collect.py selftest --root /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+remove-depth-audit`
Expected:
```
대조 1 — 단언 없이 exit 1 → (파일, rc=1): 통과
대조 2 — 기존 실패 하나 찍고 중단: 멀티셋 차는 ∅ 인데도 RED: 통과
대조 3 — 같은 기록끼리는 GREEN (판정기가 전부 거부하지 않는다): 통과
대조 4 — 같은 파일 재실행도 GREEN (식별자가 실행마다 흔들리지 않는다): 통과
```
하나라도 `실패` 면 판정기가 고장 난 것이다 — 고치기 전에 다음 단계로 가지 않는다.

- [ ] **Step 6: 기준선을 기록한다 (V1 · C6)**

Run (`run_in_background: true`):
`python3 .claude/rda/collect.py collect --root /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+remove-depth-audit --out .claude/rda/base.json`
Expected 마지막 줄: `기록: .claude/rda/base.json · 셸 <n>개 · 실패 식별자 <m>개 · head <Step 2 의 merge 커밋 8자>` — `(DIRTY)` 가 붙으면 안 된다. 셸 수는 계획 작성 시점 기준 88(spec-distill 59 + shared 29)이다. 알려진 기존 실패: `plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh`(rc 1)와 unittest `test_hook_output_schema.TestCrossResolverAdvisory.test_python_and_bash_resolvers_agree`(워크트리 환경 의존). `test_web_kill_switch.sh` 는 병렬 실행에서 한 번 흔들린 기록이 있다(단독 51/51 — 판정기는 순차로 돌린다). 그 밖의 실패가 있으면 목록을 `.claude/rda/base-notes.txt` 에 적는다 — 기준선의 실패는 고치지 않는다(범위 밖).

그리고 기준선 자신과의 비교가 GREEN 인지 확인한다(판정기 · 기록 형식 점검):
Run: `python3 .claude/rda/collect.py compare .claude/rda/base.json .claude/rda/base.json`
Expected 마지막 줄: `판정: 새 실패 0 · 완료 증거 전부 있음 (문제 0건)`

- [ ] **Step 7: 자기 적용 스윕을 기록한다 (V0)**

Run:
```bash
git grep -n -I -F -e depth_pairs -e depth_record -e depth-auditor -e '직전 답에서' -e provisional_on -e '깊이 측정' -e '되비추' -e '되비춘' -e '판정자 조건' -e '판정자 투입' -- plugins/spec-distill ':!plugins/spec-distill/CHANGELOG.md' ':!plugins/spec-distill/tests'
```
출력을 Write 도구로 `.claude/rda/v0-before.txt` 에 옮긴다. Expected: 걸리는 파일이 전부 [파일 지도](#파일-지도) 안이다 — `README.md` · `agents/depth-auditor.md` · `commands/interview.md` · `scripts/depth_pairs.py` · `scripts/depth_record.py` · `conducting-interview/SKILL.md` · `references/finishing.md` · `references/seed-input.md` · `references/state-migration.md` · `references/steelman.md` · `framing-requests/SKILL.md` · `templates/interview-audit-template.md` · `templates/interview-seed-template.md`. 목록 밖 파일이 걸리면 멈추고 보고한다(설계가 모르는 참조자).

이 task 는 리포에 계획 문서 외의 커밋을 남기지 않는다.

---

### Task 2: 사람 e2e 실행 여부 확인

**컨트롤러가 직접 한다** — subagent 에 넘기지 않는다(사용자 결정이다).

**Files:**
- Create: `.claude/rda/e2e-decision.txt`

**Interfaces:**
- Produces: `.claude/rda/e2e-decision.txt` 첫 줄 `실행` 또는 `미실행` — Task 9 수행 여부와 Task 11 의 CHANGELOG Verification 을 정한다.

- [ ] **Step 1: 사용자에게 묻는다**

```javascript
AskUserQuestion({ questions: [{
  header: "사람 e2e",
  question: "구현이 끝난 뒤(Task 8 다음) 이 워크트리의 플러그인으로 실제 /interview 를 한 번 돌려 새 라운드 형식을 확인할까요? 라운드 규약은 모델이 읽는 산문이라 테스트는 문구가 있는지만 재고, 라운드마다 질문이 정말 하나씩 나오는지는 사람만 볼 수 있습니다. 0.57.0 의 라운드 형식은 라이브로 한 번도 돌지 않은 채 출하됐고, 그것이 이번 제거의 이유 중 하나(쓰이지 않는 무게)였습니다.",
  options: [
    {label: "실행 (권장)", description: "Task 9 에서 짧은 인터뷰(3라운드 이상, 도중 종료 요청 포함)를 직접 돌리고 체크리스트 5개를 확인합니다. 10–20분. 결과를 CHANGELOG Verification 에 적습니다."},
    {label: "미실행", description: "e2e 없이 출하합니다. CHANGELOG Verification 에 «사람 e2e 미실행» 으로 적고 Task 9 를 건너뜁니다."}
  ],
  multiSelect: false }] })
```

- [ ] **Step 2: 답을 기록한다**

Write 도구로 `WT/.claude/rda/e2e-decision.txt` 에 첫 줄 `실행` 또는 `미실행`, 둘째 줄에 날짜와 사용자 답 원문.

---

### Task 3: 사후 측정 층 원자 삭제

설계 §1 · §3.1 · §3.3 · C1 · C7 · AC1 · AC5 · AC6 · AC7. **이 task 의 편집은 전부 한 커밋이다**(C1) — 중간 커밋을 만들지 않는다.

**Files:**
- Delete: `plugins/spec-distill/agents/depth-auditor.md` · `plugins/spec-distill/scripts/depth_pairs.py` · `plugins/spec-distill/scripts/depth_record.py` · `plugins/spec-distill/tests/test_depth_pairs.py` · `plugins/spec-distill/tests/test_depth_record.py` · `plugins/spec-distill/tests/test_depth_auditor_frontmatter.sh` · `plugins/spec-distill/tests/fixtures/depth-state-{allnone,badstatements,elig0,elig1,elig3,emptystatements,nofrontmatter,normal,noround,nostatementskey,templatecomment}.md` · `docs/superpowers/interview/depth/.gitkeep`
- Modify: `plugins/spec-distill/skills/conducting-interview/references/finishing.md` (Step A.7 절 · B-2 두 자리)
- Modify: `plugins/spec-distill/templates/interview-audit-template.md` (§2)
- Modify: `plugins/spec-distill/skills/conducting-interview/references/state-migration.md:31-32`
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md:56`
- Modify: `plugins/spec-distill/README.md:108,136`
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` (migration 절 주석 · A.7 락 블록 · B-2 깊이 락 · 템플릿 깊이 네 줄 락)
- Modify: `plugins/spec-distill/tests/test_finishing_block_scope.py` (전체 재작성)
- Modify: `plugins/spec-distill/tests/test_brief_agents.sh:104-110`
- Modify: `shared/tests/test_adjudication_wiring.sh:189` 과 그 주석 블록 끝

**Interfaces:**
- Consumes: Task 1 의 `collect.py` · `mutate.py` · `splice.py` · `base.json` · 의도 삭제 목록.
- Produces: 측정 층이 없는 트리. `SKILL.md` 56행 문구 «`## R<n>` 기록(«라운드 규약» 형식)» — Task 4 가 라운드 규약 절을 갈아 끼울 때 이 포인터가 그대로 맞는다. `COMP_BASELINE` 실측값 `<N>` — Task 11 CHANGELOG 가 인용한다(`.claude/rda/comp.txt`).

- [ ] **Step 1: 파일 18개를 지운다**

```bash
git rm -q plugins/spec-distill/agents/depth-auditor.md plugins/spec-distill/scripts/depth_pairs.py plugins/spec-distill/scripts/depth_record.py plugins/spec-distill/tests/test_depth_pairs.py plugins/spec-distill/tests/test_depth_record.py plugins/spec-distill/tests/test_depth_auditor_frontmatter.sh docs/superpowers/interview/depth/.gitkeep
git rm -q plugins/spec-distill/tests/fixtures/depth-state-allnone.md plugins/spec-distill/tests/fixtures/depth-state-badstatements.md plugins/spec-distill/tests/fixtures/depth-state-elig0.md plugins/spec-distill/tests/fixtures/depth-state-elig1.md plugins/spec-distill/tests/fixtures/depth-state-elig3.md plugins/spec-distill/tests/fixtures/depth-state-emptystatements.md plugins/spec-distill/tests/fixtures/depth-state-nofrontmatter.md plugins/spec-distill/tests/fixtures/depth-state-normal.md plugins/spec-distill/tests/fixtures/depth-state-noround.md plugins/spec-distill/tests/fixtures/depth-state-nostatementskey.md plugins/spec-distill/tests/fixtures/depth-state-templatecomment.md
```

- [ ] **Step 2: `finishing.md` 의 Step A.7 절을 지운다**

Run:
```bash
python3 .claude/rda/splice.py plugins/spec-distill/skills/conducting-interview/references/finishing.md '### Step A.7 — 깊이 측정' '### Step B — proceed 게이트' -
```
Expected: `splice: … — <약 5000>자 → 0자`. 지운 뒤 `### Step A.5` 절 끝(`Step B 게이트로 넘어옵니다.`) 다음에 빈 줄 하나, 그 다음이 `### Step B — proceed 게이트 (handoff 방식 제안)` 다.

- [ ] **Step 3: `finishing.md` B-2 의 깊이 두 자리를 지운다**

Edit 도구 (둘 다 파일 안에 한 번씩 있다):
- old: `유일한 자리입니다. 같은 이유로 Step A.7 의 깊이 측정 세 줄 요약도 여기 싣습니다.`
  new: `유일한 자리입니다.`
- old: `readback gap은 위 목록대로. 깊이: <audit §2 의 깊이 측정 세 줄 요약 | 측정 불가 — <이유>>. 게이트 advisory:`
  new: `readback gap은 위 목록대로. 게이트 advisory:`

`check_brief` advisories 슬롯(`게이트 advisory: <… (예: coverage-mapper 0 (unavailable: …)) | 없음>`)은 그대로 둔다(AC5).

- [ ] **Step 4: audit 템플릿 §2 를 한 줄로 만든다**

Write 도구로 `WT/.claude/rda/t3-budget.md`:
```markdown
## 2. Budget

(한 줄. 이 줄의 두 계수는 **다른 것을 센다**: `agent dispatch: <n>` 은 이 인터뷰의 subagent
 dispatch **총계**이고, `coverage-mapper <k>` 는 그중 coverage-mapper **하나만**의 횟수라
 언제나 `<k> ≤ <n>` 이다. 게이트가 보는 것은 후자뿐이며 k≥1이면 통과한다 — dispatch 를 못
 했으면 `coverage-mapper 0 (unavailable: <사유>)`처럼 사유를 붙인다(advisory). 사유 없는 0은
 게이트 red(AC4). 게이트가 읽는 것은 아래 **불릿 줄**뿐이고 이 설명 산문은 판정에 참여하지
 않는다. `<k>` 는 **반드시 실제 횟수로 치환한다** — 템플릿이 통과값을 미리 채워 두면
 dispatch 를 한 번도 안 한 턴이 그대로 옮겨 적어 게이트가 조용히 통과한다. 채우지 않은
 `<k>` 는 게이트 red 다(«coverage-mapper <k> line missing»): 침묵보다 red 가 낫다.)

- 질문 라운드: <n> · agent dispatch: <n> · coverage-mapper <k> · codex 실호출: <n> (성공 <n>)
```
Run:
```bash
python3 .claude/rda/splice.py plugins/spec-distill/templates/interview-audit-template.md '## 2. Budget' '## 3. Steelman 원문' .claude/rda/t3-budget.md
```

- [ ] **Step 5: 측정 흔적 문장 셋을 고친다**

Edit 도구:
- `plugins/spec-distill/skills/conducting-interview/references/state-migration.md` — old `§6 원문과 깊이 측정의 근거를 통째로` → new `§6 원문을 통째로`
- `plugins/spec-distill/skills/conducting-interview/SKILL.md` — old ``State body: 각 라운드의 §1.1 기록(`## R<n>` 형식 그대로 — `depth_pairs.py` 가 읽는 계약) + coverage-mapper 출력 transcript.`` → new ``State body: 각 라운드의 `## R<n>` 기록(«라운드 규약» 형식) + coverage-mapper 출력 transcript.``
- `plugins/spec-distill/README.md` — 108행 한 줄(아래 전문)을 통째로 지운다:
  ```
  - **Law 3 (Compounding) — 깊이 측정 원장 (v0.57.0)** — 인터뷰마다 «답→다음 행동» 짝을 세 층(스크립트·`depth-auditor`·사람 ≤4 라벨)으로 재어 `docs/superpowers/interview/depth/<basename>.json` 에 남긴다. `depth_record.py` 가 `depth/*.json` 을 읽어 판정자 투입 조건(적격 5건·not_dug 30%·일치 70%)을 audit 에 한 줄로 낸다 — 게이트 아님(spec C5).
  ```
- `plugins/spec-distill/README.md` — old `` `plugins/spec-distill/agents/` 11종(doc-critic·doc-recritic·steelman-builder·coverage-mapper·blind-spot-prober·brief-critic·brief-direction-reviewer·brief-readback·seed-critic·seed-readback·depth-auditor).`` → new `` `plugins/spec-distill/agents/` 10종(doc-critic·doc-recritic·steelman-builder·coverage-mapper·blind-spot-prober·brief-critic·brief-direction-reviewer·brief-readback·seed-critic·seed-readback).``

SKILL.md 의 나머지 두 언급(81행 · `references/steelman.md` 86행)은 그 문단째 Task 4 가 지운다.

- [ ] **Step 6: stage 테스트의 측정 락을 지운다**

Run (A.7 락 블록 — `# --- v0.57.0 Step A.7` 주석부터 B-2 주석 직전까지):
```bash
python3 .claude/rda/splice.py plugins/spec-distill/tests/test_conducting_interview_stage.sh '# --- v0.57.0 Step A.7 깊이 측정 (finishing.md, 블록 스코프)' '# B-2 게이트 텍스트에 깊이 요약과 advisories 슬롯' -
```
Edit 도구 — B-2 깊이 락(old 세 줄 → new 두 줄):
```
# B-2 게이트 텍스트에 깊이 요약과 advisories 슬롯
b2_block="$(awk '/^#### B-2/{f=1;print;next} /^#### /{f=0} f' "$FIN")"
grep -qF '깊이:' <<<"$b2_block" && ok "B-2: question 에 깊이 요약 슬롯" || no "B-2: 깊이 요약 슬롯 부재"
```
→
```
# B-2 게이트 텍스트의 advisories 슬롯
b2_block="$(awk '/^#### B-2/{f=1;print;next} /^#### /{f=0} f' "$FIN")"
```
Edit 도구 — 템플릿 깊이 네 줄 락(old 13줄 → new 1줄):
```
TPL="$REPO_ROOT/plugins/spec-distill/templates/interview-audit-template.md"
# `depth_record.py` 는 stdout 으로 **네 줄**을 내고 finishing.md Step A.7 이 그 넷을 §2 에
# 그대로 붙이라고 지시한다. 락이 셋만 세는 동안 `- 판정자 조건:` 줄은 템플릿에서 지워도
# 스위트가 GREEN 이었다(실측) — 그 줄은 spec §3.4 의 판정자 투입 조건이 사람에게 도달하는
# 유일한 자리다. 넷 다 데이터 불릿으로 실재하는지 센다.
depth_rows=0
for key in '깊이 측정(형식)' '깊이 측정(auditor)' '깊이 측정(사람)' '판정자 조건:'; do
  grep -qE "^- .*$(printf '%s' "$key" | sed 's/[][\.*^$(){}?+|/]/\\&/g')" "$TPL" \
    && depth_rows=$((depth_rows + 1))
done
[[ "$depth_rows" -eq 4 ]] \
  && ok "AC10: audit 템플릿 §2 깊이 네 줄 (형식·auditor·사람·판정자 조건) 이 전부 데이터 불릿" \
  || no "AC10: 템플릿 §2 깊이 줄이 4 가 아니라 $depth_rows — depth_record.py 의 네 줄과 어긋난다"
```
→
```
TPL="$REPO_ROOT/plugins/spec-distill/templates/interview-audit-template.md"
```
Edit 도구 — migration 절 주석: old `그건 마이그레이션이 아니라 §6 원문·깊이 측정 근거의 손실이다.` → new `그건 마이그레이션이 아니라 §6 원문의 손실이다.`

- [ ] **Step 7: `test_finishing_block_scope.py` 의 양성 대조를 남는 펜스로 옮긴다**

Write 도구로 `WT/plugins/spec-distill/tests/test_finishing_block_scope.py` 전체를 덮어쓴다:
```python
"""finishing.md 의 bash 펜스는 앞 펜스의 변수를 물려받지 못한다.

Bash 도구는 호출마다 새 셸이고 유지되는 것은 cwd 뿐이다. 이 문서의 절차는 `Skill` 호출과
`AskUserQuestion` 을 사이에 끼고 여러 셸에 걸쳐 돈다 — 한 펜스가 앞 펜스에서만 정의된
`$ROOT`·`$harness_sid` 같은 값을 쓰면 빈 문자열로 전개돼 `'/scripts/…'` 같은 경로가 만들어지고,
실패는 rc≠0 하나로 조용히 지나간다. 이 락이 생긴 실측(지금은 삭제된 사후 측정 단계):

    $ bash <<'B'
    > python3 "$PR/scripts/depth_record.py" ...
    > B
    can't open file '/scripts/depth_record.py': [Errno 2]   rc=2

그 단계는 사라졌지만 불변식은 남는 펜스(Step A 5 게이트 · Step A.5 · B-0)에 그대로 걸린다.

**이 락은 열거가 아니라 도출이다.** 변수 이름 목록을 핀하지 않고, 펜스마다 «쓰인 변수»와
«그 펜스가 정의한 변수»를 각각 뽑아 차집합을 본다. 새 블록이 생기거나 변수 이름이 바뀌어도
축이 그대로 산다 — 열거였다면 다음 블록은 검사 밖이었을 것이다.

환경에서 오는 것만 예외다(`ENV_PROVIDED`). 이 집합을 넓히는 것은 곧 검사를 무르게 하는
것이므로, 항목마다 «누가 그 값을 넣어 주는가» 를 답할 수 있어야 한다.
"""
import re
import unittest
from pathlib import Path

FIN = (Path(__file__).resolve().parent.parent / "skills" / "conducting-interview"
       / "references" / "finishing.md")

# 하니스가 넣어 주는 값. `CLAUDE_PLUGIN_ROOT` 는 플러그인 실행 시 Claude Code 가 export 한다
# (그래서 문서의 블록들도 `${CLAUDE_PLUGIN_ROOT:-...}` 로 fallback 을 단다).
ENV_PROVIDED = {"CLAUDE_PLUGIN_ROOT"}

FENCE_OPEN = re.compile(r"^\s*```bash\s*$")
FENCE_CLOSE = re.compile(r"^\s*```\s*$")
# `$VAR` · `${VAR}` — `$?`·`$1` 같은 셸 특수변수는 이름 규칙에 안 맞아 자연히 빠진다.
USE_RE = re.compile(r"\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?")
ASSIGN_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)=")


def bash_fences(text):
    """(시작줄, 끝줄, 본문줄들) 목록. 열거가 아니라 파일에서 도출한다."""
    out, cur, inb, start = [], [], False, 0
    for i, ln in enumerate(text.splitlines(), 1):
        if not inb and FENCE_OPEN.match(ln):
            inb, cur, start = True, [], i
            continue
        if inb and FENCE_CLOSE.match(ln):
            out.append((start, i, cur))
            inb = False
            continue
        if inb:
            cur.append(ln)
    return out


class FinishingBlockScope(unittest.TestCase):
    def setUp(self):
        self.text = FIN.read_text(encoding="utf-8")
        self.fences = bash_fences(self.text)

    def test_corpus_is_actually_read(self):
        """양성 대조 — 펜스를 못 찾으면 아래 단언이 통째로 공허해진다.

        부재 검사만으로 된 락은 대상 파일을 지워도 통과한다. 여기서는 '펜스가 셋 이상 있고
        그중 게이트 호출(check_brief.py)을 담은 것이 있다' 를 먼저 못 박는다.
        """
        self.assertGreaterEqual(len(self.fences), 3,
                                "finishing.md 에서 bash 펜스를 셋 이상 못 찾았다 — 추출기가 깨졌다")
        joined = "\n".join("\n".join(b) for _, _, b in self.fences)
        self.assertIn("check_brief.py", joined,
                      "게이트 호출이 어떤 bash 펜스에도 없다 — 락이 겨눌 대상이 사라졌다")

    def test_no_variable_carried_across_fences(self):
        """펜스마다: 쓰인 변수 ⊆ 그 펜스가 정의한 변수 ∪ 환경 제공."""
        offenders = []
        for start, end, body in self.fences:
            used, assigned = set(), set()
            for ln in body:
                m = ASSIGN_RE.match(ln)
                if m:
                    assigned.add(m.group(1))
                used.update(USE_RE.findall(ln))
            unbound = used - assigned - ENV_PROVIDED
            if unbound:
                offenders.append((start, end, sorted(unbound)))
        self.assertEqual(
            offenders, [],
            "블록 간에 변수를 나르는 bash 펜스가 있다 (줄범위, 미정의 변수): %r\n"
            "각 펜스는 머리에서 경로를 다시 도출해야 한다 — Bash 도구는 호출마다 새 셸이다."
            % (offenders,))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 8: 격리 agent 목록에서 depth-auditor 를 뺀다**

Edit 도구 — `plugins/spec-distill/tests/test_brief_agents.sh`:
```
# v0.57.0 depth-auditor 편입 — 짝 목록만 인라인으로 받고 파일을 열지 않는 다섯째
# 격리 에이전트다(도구 표면 0). 리터럴이라 넣지 않으면 좌변이 다섯으로 늘어 RED 다.
EXPECTED_ISOLATED="brief-critic
brief-readback
depth-auditor
seed-critic
seed-readback"
```
→
```
# depth-auditor 는 depth audit 제거로 빠졌다 — 격리 에이전트는 넷이다. 리터럴이라 그 파일이
# 되살아나면 좌변이 다섯으로 늘어 RED 다.
EXPECTED_ISOLATED="brief-critic
brief-readback
seed-critic
seed-readback"
```

- [ ] **Step 9: `COMP_BASELINE` 을 실측한다 (C7)**

Run:
```bash
PYTHONDONTWRITEBYTECODE=1 python3 shared/tests/fixtures/adjudication/run_wiring_scan.py /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+remove-depth-audit
```
출력에서 `comprehensions=<N>` 줄을 읽어 Write 도구로 `.claude/rda/comp.txt` 에 `<N>` 을 적는다. 예상은 52(58 − `depth_record.py` 가 더한 6)다. **52 가 아니면 멈춘다** — `tools/adjudication/check_wiring.py` 의 `comprehension_count` 대상 파일을 `ast` 로 열거해 차이의 출처를 찾고, 설명할 수 있을 때만 그 값을 쓴다.

Edit 도구 — `shared/tests/test_adjudication_wiring.sh`:
- old `COMP_BASELINE=58   # Task 1 F5 census 28` → new `COMP_BASELINE=<N>   # Task 1 F5 census 28` (`<N>` = 방금 잰 값)
- 주석 블록 마지막 줄 `                   # 라벨로 그대로 대응된다 — 버려지는 원소가 없다.` 바로 아래에 세 줄을 더한다:
```
                   # depth audit 제거가 6 줄였다(58→52) — depth_record.py 가 삭제되며 그 파일의
                   # 컴프리헨션 여섯(v0.57.0 Task 8 의 다섯 + 최종 fix wave 의 하나)이 ㉮ 에서
                   # 함께 빠졌다. run_wiring_scan.py 의 `ast` 실측값이다.
```
(측정값이 52 가 아니라 설명된 다른 값이면 괄호 안 숫자와 사유를 그 값에 맞춘다.)

- [ ] **Step 10: 표적 테스트를 돌린다**

Run (각각 따로):
```bash
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh
bash plugins/spec-distill/tests/test_brief_agents.sh
bash plugins/spec-distill/tests/test_check_brief.sh
bash shared/tests/test_dispatch_disposition.sh
bash shared/tests/test_adjudication_wiring.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_finishing_block_scope.py'
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_audit_template_gate_shape.py'
```
Expected: 셸 다섯은 마지막 줄 `Total: … | Fail: 0`, unittest 둘은 `OK`. stage 는 merge 뒤 222개에서 A.7 락 12개 · B-2 깊이 1개 · 템플릿 깊이 1개가 빠져 208개가 된다(모의 실행 실측) — 숫자보다 `Fail: 0` 이 판정이다. `test_adjudication_wiring.sh` 에 `컴프리헨션 내포 52 <= baseline 52` 줄이 보여야 한다(AC7 — 좌변과 우변이 **같은** 값).

- [ ] **Step 11: AC1 · AC5 · AC6 을 직접 확인한다**

Run:
```bash
git ls-files plugins/spec-distill/agents/depth-auditor.md plugins/spec-distill/scripts/depth_pairs.py plugins/spec-distill/scripts/depth_record.py plugins/spec-distill/tests/test_depth_pairs.py plugins/spec-distill/tests/test_depth_record.py plugins/spec-distill/tests/test_depth_auditor_frontmatter.sh plugins/spec-distill/tests/fixtures docs/superpowers/interview/depth
test -d docs/superpowers/interview/depth && echo "depth dir EXISTS" || echo "depth dir absent"
grep -c 'Step A.7' plugins/spec-distill/skills/conducting-interview/references/finishing.md
grep -c '깊이' plugins/spec-distill/skills/conducting-interview/references/finishing.md
grep -n 'coverage-mapper 0 (unavailable' plugins/spec-distill/skills/conducting-interview/references/finishing.md
grep -c '^- ' plugins/spec-distill/templates/interview-audit-template.md
```
Expected: 첫 명령은 `tests/fixtures` 아래의 `depth-state-` 아닌 fixture 만 낸다(`depth` 가 든 경로 0건) · `depth dir absent` · `0` · `0` · B-2 advisories 슬롯 줄이 1건 이상 · 템플릿 불릿 수는 §1 여섯 + §2 하나 + 나머지 절 — §2 안의 불릿이 하나인지는 `awk '/^## 2\. Budget/{f=1;next} /^## /{f=0} f && /^- /' plugins/spec-distill/templates/interview-audit-template.md` 로 확인해 정확히 1줄.

- [ ] **Step 12: 판정기로 전체를 잰다 (AC10)**

Run (`run_in_background: true`):
`python3 .claude/rda/collect.py collect --root /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+remove-depth-audit --out .claude/rda/t3.json`
그 다음:
`python3 .claude/rda/collect.py compare .claude/rda/base.json .claude/rda/t3.json --deleted plugins/spec-distill/tests/test_depth_auditor_frontmatter.sh --deleted-py test_depth_pairs --deleted-py test_depth_record`
Expected 마지막 줄: `판정: 새 실패 0 · 완료 증거 전부 있음 (문제 0건)`

- [ ] **Step 13: 커밋한다**

Write 도구로 `WT/.claude/rda/msg-t3.txt`:
```
refactor(spec-distill): 사후 깊이 측정 층(Step A.7) 제거

depth-auditor agent · depth_pairs.py · depth_record.py · 그 테스트 3개와 fixture 11개 ·
측정 원장 디렉토리를 지우고, 그것을 부르던 finishing.md Step A.7 절 · B-2 깊이 슬롯 ·
audit 템플릿 §2 깊이 네 줄과 이를 재던 락을 같은 커밋에서 걷어 냈다(설계 C1 — 처분 락이
consumer 경로의 실재를 git ls-files 로 재므로 갈라진 중간 커밋은 RED 다).
test_finishing_block_scope.py 의 양성 대조는 남는 펜스의 게이트 호출로, 격리 agent 목록은
넷으로, COMP_BASELINE 은 ast 실측값으로 옮겼다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Um5Znb7UcRUQ4SP3u3TobS
```
Run:
```bash
git add -A plugins/spec-distill shared/tests docs/superpowers/interview
git status --porcelain
git commit -F .claude/rda/msg-t3.txt
```
Expected: `git status --porcelain` 이 커밋 전에 이 task 의 파일만 보인다(`D` 18 · `M` 9). 커밋 후 빈 출력.

- [ ] **Step 14: 고친 락을 변이로 흔든다 (V3 · AC7)**

변이 A — 남는 펜스가 앞 펜스 변수를 쓰게 한다(B-0 펜스가 A.5 펜스의 `$harness_sid` 를 쓴다). Write 도구로 `WT/.claude/rda/m3a-old.txt` 에 `STATE="$ROOT/<session-id>/state.local.md"`, `WT/.claude/rda/m3a-new.txt` 에 `STATE="$ROOT/$harness_sid/state.local.md"` (각각 한 줄, 끝 줄바꿈 없어도 된다).
```bash
python3 .claude/rda/mutate.py plugins/spec-distill/skills/conducting-interview/references/finishing.md @.claude/rda/m3a-old.txt @.claude/rda/m3a-new.txt
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_finishing_block_scope.py'
git checkout -- plugins/spec-distill/skills/conducting-interview/references/finishing.md
```
Expected: `FAIL: test_no_variable_carried_across_fences` 와 메시지에 `'harness_sid'`. 복원 뒤 `git status --porcelain` 빈 출력.

변이 B — 양성 대조의 대상을 없앤다(게이트 호출을 산문으로 바꾼다):
```bash
python3 .claude/rda/mutate.py plugins/spec-distill/skills/conducting-interview/references/finishing.md 'scripts/check_brief.py" gate "docs/superpowers/interview/<file>"' 'scripts/gate-placeholder" gate "docs/superpowers/interview/<file>"'
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_finishing_block_scope.py'
git checkout -- plugins/spec-distill/skills/conducting-interview/references/finishing.md
```
Expected: `FAIL: test_corpus_is_actually_read` (게이트 호출 부재). mutate 가 exit 2 를 내면(OLD 가 1번이 아니면) 변이가 일어나지 않은 것이다 — 파일을 Read 로 열어 그 호출 줄의 정확한 문자열로 OLD 를 고친다.

변이 C — 격리 목록에 depth-auditor 를 되넣는다:
```bash
python3 .claude/rda/mutate.py plugins/spec-distill/tests/test_brief_agents.sh 'brief-readback
seed-critic' 'brief-readback
depth-auditor
seed-critic'
bash plugins/spec-distill/tests/test_brief_agents.sh
git checkout -- plugins/spec-distill/tests/test_brief_agents.sh
```
Expected: `✗ L: 격리 집합 불일치.` 줄. 복원 뒤 `git status --porcelain` 빈 출력.

결과(변이 3개 · 각각 RED 확인)를 `.claude/rda/mutations.txt` 에 한 줄씩 적는다.

---

### Task 4: 라운드 규약 대체

설계 §2.1 · §2.2 · §2.4 · §2.5(SKILL 도입부) · §3.2(라운드 규약 · 되묻기 행) · C8 · C9 · AC3.

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (17–18 도입부 · 78–169 라운드 규약 절 교체 · 201 `provisional_on` 줄 · 274 문장)
- Modify: `plugins/spec-distill/skills/conducting-interview/references/steelman.md:84-87` (삭제)
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` (323–354 교체 · coverage-mapper 절 락 한 줄 추가)

**Interfaces:**
- Consumes: Task 3 이 남긴 SKILL.md 56행 «`## R<n>` 기록(«라운드 규약» 형식)».
- Produces: 절 제목 `## 라운드 규약 — 지금 이해 · 다음 결정 · 질문 하나`(접두 `## 라운드 규약` — stage 테스트 · Task 8 V13 의 awk 앵커가 이 접두에 묶인다). 본문 고유 문구 `AskUserQuestion 1회, **질문 1개**` · `같은 주제의 연속 되묻기는 최대 2회` — Task 8 의 양성 짝이 이 둘을 잰다. SKILL.md 에 `provisional_on` 0건.

- [ ] **Step 1: 새 라운드 규약 절을 파일로 쓴다**

Write 도구로 `WT/.claude/rda/t4-skill-round.md`:
````markdown
## 라운드 규약 — 지금 이해 · 다음 결정 · 질문 하나

사용자에게 보이는 출력과 state 본문 기록이 같은 형식이다.

```markdown
## R<n>

### 지금 이해
<문제의 현재 재구성 — 바뀐 부분만 한두 문장. 코드·문서에서 확인한 사실(경로 a)과
 외부 근거(landscape·premortem)가 있으면 여기 싣는다. 재개방이면 «→ <차원> 재개방: <사유>»>

### 다음 결정
<무엇을 정하는지 한 줄> · 추천: <첫 선택지> · 트레이드오프: <선택지별 한 줄>

### 질문
<본문>

### 답
→ S<m>
```

- `## R<n>` 은 1부터 순증한다.
- 라운드마다 AskUserQuestion 1회, **질문 1개**다. 첫 선택지가 추천이고 그 라벨 끝에 `(권장)` 을 단다 —
  steelman 절차의 질문만 예외다(아래).
- question 본문은 무엇을 정하는지·용어·기술 사실을 풀고, 각 선택지의 `description` 은 «고르면 무엇이
  달라지는가»를 담는다. 기계 검사는 없다.
- **되묻기** — 직전 답이 보류(«모르겠다/둘 다/아무거나»)·한 단어·이유 없는 추천 수락·근거 없는 단정이면,
  그 라운드의 질문은 이유·사례·실패 조건 중 하나를 되묻고 인터뷰어의 추측을 첫 선택지로 둔다.
  같은 주제의 연속 되묻기는 최대 2회다 — 그 뒤에도 약한 답이면 답을 그대로 기록하고(보류는 «사용자 발화
  기록» 표대로 §3 Open Questions 로도 이월) 다음 질문으로 넘어간다. 그 차원을 자동으로 닫지 않는다.
- **한 라운드에 겹치면** 되묻기 → 외부 근거 처분(landscape·premortem 출력을 받아들일지) → 새 결정 순서로
  앞선 하나가 그 라운드의 질문이 되고, 나머지는 다음 라운드의 «다음 결정»으로 넘어간다. landscape·
  blind_spot 은 그 처분 S 로만 닫힌다.
- **steelman 절차의 질문** — `references/steelman.md` 가 사용자에게 묻는 질문은 전부 그 파일의 규약(선택지
  순서·라벨·추천 표기·시점)을 따르고 각각 `## R<n>` 한 라운드로 기록한다. 이 절의 질문 수·`(권장)` 표기·
  «추천: <첫 선택지>»·겹침 순서는 그 질문들에 적용하지 않으며, steelman 절차가 진행 중이면 그 질문이 겹침
  순서보다 앞선다.
- **인자 없이 `/interview` 를 부른 경로의 R1** 은 seed 도 직전 답도 없으므로 «지금 이해»를 «아직 없음»으로
  두고 질문으로 무엇을 다룰지 묻는다. coverage-mapper 첫 dispatch 시점은 아래 coverage-mapper 절이 정한다.
- 답은 `user_statements` 에 `S<m>` 하나로 append 한다(선택지 = `chosen`, «기타» 자유 입력 = `verbatim`).
  번호 공식은 «사용자 발화 기록» 절 그대로.
````

- [ ] **Step 2: SKILL.md 의 옛 절(라운드 규약 · 질문 둘 · 되묻기로 바뀌는 조건)을 갈아 끼운다**

Run:
```bash
python3 .claude/rda/splice.py plugins/spec-distill/skills/conducting-interview/SKILL.md '## 라운드 규약 — «직전 답에서» 블록 + 질문 둘' '## C43 3-path routing' .claude/rda/t4-skill-round.md
```
Expected: `splice: … — <약 5500>자 → <약 2200>자`. 이 한 번으로 설계 §2.4 의 블록 형식 · 네 줄 규칙 · 질문 둘 절 전체 · R1 블록 면제 · «되묻기로 바뀌는 조건» 절과 예시 · 원칙 문장 «인터뷰어의 다음 행동은…» · 81행의 «측정 스크립트가 읽기 때문» 문장이 함께 빠진다.

- [ ] **Step 3: 도입부와 `provisional_on` 두 자리를 고친다**

Edit 도구 — `plugins/spec-distill/skills/conducting-interview/SKILL.md`:
- old:
  ```
  매 라운드를 «직전 답에서» 블록으로 시작하고 AskUserQuestion 질문
  둘로 묻되, 종료는
  ```
  new: `매 라운드를 «지금 이해 · 다음 결정 · 질문 하나»로 묻되, 종료는`
- «사용자 발화 기록» 절 yaml 에서 이 한 줄을 통째로 지운다:
  ```
    provisional_on: S<k>       # optional — Q1 이 «모르겠다»/«기타»일 때만. 해소(Q1 «맞다») 전엔 닫힘 근거 불가. 기계 검사 없음 — orchestrator 판단.
  ```
- «닫힘 · 재개방» 절: old ``확인 S. `provisional_on` 이 해소되지 않은 S 는 닫힘 근거가 아니다.`` → new `확인 S.`

- [ ] **Step 4: `steelman.md` 84–87행을 지운다**

Run:
```bash
python3 .claude/rda/splice.py plugins/spec-distill/skills/conducting-interview/references/steelman.md '같은 출력(`case_for_alternative`' '#### Step 4 — 기록' -
```
Expected: 지운 뒤 `conducting-interview 는 builder 출력을 **약화·편집하지 않는다** — verbatim 계약이다.` 다음에 빈 줄 하나, 그 다음이 `#### Step 4 — 기록`.

- [ ] **Step 5: SKILL 쪽 결과를 확인한다**

Run:
```bash
grep -c '' plugins/spec-distill/skills/conducting-interview/SKILL.md
grep -n -e provisional_on -e 'Q1' -e 'Q2' -e '직전 답에서' -e depth_pairs plugins/spec-distill/skills/conducting-interview/SKILL.md
grep -n -e '4-block' -e '막힌 결정' -e teach- -e general-purpose plugins/spec-distill/skills/conducting-interview/SKILL.md
grep -n -e depth_pairs -e '상충' plugins/spec-distill/skills/conducting-interview/references/steelman.md
```
Expected: 줄 수 < 388(약 335) · 둘째 · 셋째 · 넷째 명령 출력 없음.

- [ ] **Step 6: stage 테스트의 라운드 규약 락을 쓴다**

Write 도구로 `WT/.claude/rda/t4-stage-round.sh`:
````bash
# --- 라운드 규약 (블록 스코프) — 지금 이해 · 다음 결정 · 질문 하나 -----------------------
# 스코프 안의 예시 fenced block 이 `## R<n>` 헤딩 리터럴을 담고 있어 — 단순 "다음 `## `
# 헤딩에서 닫는다" idiom 이 예시 자체를 다음 섹션 시작으로 오판한다(fence 미인식). 그래서 이
# 스코프만 ``` 토글로 fence 안쪽을 닫힘-판정에서 뺀다. 절 제목은 `## 라운드 규약` 으로 시작해야
# 이 앵커가 절을 뜬다.
round_block="$(awk '/^```/{c=!c} /^## 라운드 규약/{f=1;print;next} !c && /^## /{f=0} f' "$SKILL")"
round_flat="$(tr '\n' ' ' <<<"$round_block" | tr -s ' ')"
[[ -n "$round_block" ]] \
  && ok "AC3(양성대조): 라운드 규약 절을 떴다 (아래 단언이 실재한다)" \
  || no "AC3(양성대조): 라운드 규약 절 부재 — 아래 단언이 공허하다"
for h in '### 지금 이해' '### 다음 결정' '### 질문' '### 답'; do
  grep -qxF -- "$h" <<<"$round_block" && ok "AC3: 소제목 $h" || no "AC3: 소제목 $h 부재"
done
grep -qF '## R<n>' <<<"$round_block" && ok "AC3: state 본문 헤딩 ## R<n>" || no "AC3: ## R<n> 헤딩 부재"
grep -qF 'AskUserQuestion 1회, **질문 1개**' <<<"$round_flat" \
  && ok "AC3: 라운드마다 AskUserQuestion 1회 · 질문 1개" || no "AC3: 질문 1개 규칙 부재"
grep -qE '첫 선택지가 추천이고[^.]{0,30}\(권장\)' <<<"$round_flat" \
  && ok "AC3: 첫 선택지가 추천 (권장)" || no "AC3: 추천 첫 선택지 규칙 부재"
grep -qF '고르면 무엇이 달라지는가' <<<"$round_flat" \
  && ok "AC3: description = 고르면 무엇이 달라지는가" || no "AC3: description 규칙 부재"
grep -qF '이유·사례·실패 조건 중 하나를 되묻고 인터뷰어의 추측을 첫 선택지로' <<<"$round_flat" \
  && ok "C1: 되묻기 세 축(이유·사례·실패 조건) + 추측이 첫 선택지" || no "C1: 되묻기 규칙 부재"
grep -qF '같은 주제의 연속 되묻기는 최대 2회' <<<"$round_flat" \
  && ok "AC3: 되묻기 상한 — 같은 주제 최대 2회" || no "AC3: 되묻기 상한 부재 또는 값이 2회가 아니다"
grep -qF '그 차원을 자동으로 닫지 않는다' <<<"$round_flat" \
  && ok "AC3: 상한 뒤에도 차원을 자동으로 닫지 않는다" || no "AC3: 상한 뒤 자동 닫힘 금지 문장 부재"
grep -qE '되묻기 → 외부 근거 처분[^→]{0,60}→ 새 결정' <<<"$round_flat" \
  && ok "AC3: 겹침 순서 — 되묻기 → 외부 근거 처분 → 새 결정" || no "AC3: 겹침 순서 부재 또는 뒤바뀜"
grep -qF '`references/steelman.md` 가 사용자에게 묻는 질문은 전부 그 파일의 규약' <<<"$round_flat" \
  && ok "AC3: steelman 절차 질문의 예외 (그 파일이 묻는 질문 — 도출 규칙)" || no "AC3: steelman 예외 도출 규칙 부재"
grep -qE '인자 없이 `/interview` 를 부른 경로의 R1\*\* 은[^.]{0,60}«아직 없음»' <<<"$round_flat" \
  && ok "AC3: 인자 없는 R1 — «지금 이해» 는 «아직 없음»" || no "AC3: 인자 없는 R1 모양 부재"
# 부재 — 이 절로 스코프한다. coverage-mapper 절의 «인자 없이 부른 경로에서는 R1 답을 받은 뒤 R2
# 전에» 는 정본으로 남아야 하므로(아래 coverage-mapper 락) 전-파일 부재로 재지 않는다.
for tok in 'Q1' 'Q2' 'provisional_on' '블록 없이' '직전 답에서'; do
  grep -qF -- "$tok" <<<"$round_block" \
    && no "AC3: 라운드 규약 절에 «${tok}» 잔존" || ok "AC3: 라운드 규약 절에 «${tok}» 없음"
done
[[ "$(wc -l < "$SKILL")" -lt 388 ]] \
  && ok "AC3/C9: SKILL.md 줄 수 $(wc -l < "$SKILL") < 388 (순감)" \
  || no "AC3/C9: SKILL.md 줄 수 $(wc -l < "$SKILL") ≥ 388"
````
Run:
```bash
python3 .claude/rda/splice.py plugins/spec-distill/tests/test_conducting_interview_stage.sh '# --- v0.57.0 §1 라운드 규약 (블록 스코프' '# 제거 (G7·AC1·AC14)' .claude/rda/t4-stage-round.sh
```
이 교체로 옛 락(블록 · 네 줄 키 · Q1/Q2 · `provisional_on` 존재 · R1 예외 · `q_js` 질문 둘 · «되묻기로 바뀌는 조건» 절 락)이 빠진다.

- [ ] **Step 7: coverage-mapper 절에 남는 정본 자리를 잠근다**

Edit 도구 — `plugins/spec-distill/tests/test_conducting_interview_stage.sh`:
- old:
  ```
  grep -qE '재개방[^.]{0,20}최대 1회' <<<"$covmap_flat" \
    && ok "C4: 재개방 시 최대 1회" || no "C4: 재개방 dispatch 규칙 부재"
  ```
  new:
  ```
  grep -qE '재개방[^.]{0,20}최대 1회' <<<"$covmap_flat" \
    && ok "C4: 재개방 시 최대 1회" || no "C4: 재개방 dispatch 규칙 부재"
  # 인자 없는 경로의 첫 dispatch 시점은 이 절이 정본이다(라운드 규약 절은 여기를 가리키기만 한다).
  grep -qF '인자 없이 부른 경로에서는 R1 답을 받은 뒤 R2 전에' <<<"$covmap_flat" \
    && ok "AC3: 인자 없는 경로의 coverage-mapper 첫 dispatch — R1 답 뒤 R2 전 (정본 자리)" \
    || no "AC3: coverage-mapper 절에서 인자 없는 경로의 첫 dispatch 시점이 사라졌다"
  ```

- [ ] **Step 8: 표적 테스트를 돌린다**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh`
Expected: 마지막 줄 `Total: … | Fail: 0`, 그리고 `✓ AC3/C9: SKILL.md 줄 수 3…< 388 (순감)` 과 `✓ G7 양성 대조: «4-block» 이 steelman.md 에 실재` 가 보인다.

- [ ] **Step 9: 판정기로 전체를 잰다 (AC10)**

Run (`run_in_background: true`): `python3 .claude/rda/collect.py collect --root /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+remove-depth-audit --out .claude/rda/t4.json`
Run: `python3 .claude/rda/collect.py compare .claude/rda/base.json .claude/rda/t4.json --deleted plugins/spec-distill/tests/test_depth_auditor_frontmatter.sh --deleted-py test_depth_pairs --deleted-py test_depth_record`
Expected: `판정: 새 실패 0 · 완료 증거 전부 있음 (문제 0건)`

- [ ] **Step 10: 커밋한다**

Write 도구로 `WT/.claude/rda/msg-t4.txt`:
```
refactor(spec-distill): 라운드 규약을 지금 이해 · 다음 결정 · 질문 하나로

«직전 답에서» 블록과 네 줄 규칙, 질문 둘 절(Q1 되비추기 확인 · Q2 · 재되비추기 · 독립성),
인자 없는 R1 의 블록 면제, «되묻기로 바뀌는 조건» 절, provisional_on 을 지우고 라운드를
지금 이해 / 다음 결정 / 질문 / 답 으로 대체했다. AskUserQuestion 1회에 질문 1개, 첫 선택지가
추천. 약한 답에는 이유·사례·실패 조건 중 하나를 되묻고 같은 주제 최대 2회. 겹치면 되묻기 →
외부 근거 처분 → 새 결정. steelman.md 가 묻는 질문은 그 파일의 규약을 따른다.
steelman.md 의 «상충 줄에도 싣는다» 문단(측정 스크립트용 한 줄 규칙)도 함께 지웠다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Um5Znb7UcRUQ4SP3u3TobS
```
Run:
```bash
git add plugins/spec-distill/skills/conducting-interview/SKILL.md plugins/spec-distill/skills/conducting-interview/references/steelman.md plugins/spec-distill/tests/test_conducting_interview_stage.sh
git status --porcelain
git commit -F .claude/rda/msg-t4.txt
```

- [ ] **Step 11: 새 락을 변이로 흔든다 (V3 · C5)**

변이마다: mutate → `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh` 출력에서 **해당 ✗ 줄**을 찾는다 → `git checkout -- plugins/spec-distill/skills/conducting-interview/SKILL.md` → `git status --porcelain` 빈 출력. `S` = `plugins/spec-distill/skills/conducting-interview/SKILL.md`.

| # | 축 | 명령 | 기대 ✗ 줄 |
|---|---|---|---|
| 1 | 삭제 | `python3 .claude/rda/mutate.py S 'AskUserQuestion 1회, **질문 1개**다.' 'AskUserQuestion 1회다.'` | `✗ AC3: 질문 1개 규칙 부재` |
| 2 | 값 | `python3 .claude/rda/mutate.py S '연속 되묻기는 최대 2회다' '연속 되묻기는 최대 3회다'` | `✗ AC3: 되묻기 상한 부재 또는 값이 2회가 아니다` |
| 3 | 반전 | `python3 .claude/rda/mutate.py S '그 차원을 자동으로 닫지 않는다.' '그 차원을 자동으로 닫는다.'` | `✗ AC3: 상한 뒤 자동 닫힘 금지 문장 부재` |
| 4 | 위치(순서) | `python3 .claude/rda/mutate.py S '되묻기 → 외부 근거 처분(landscape·premortem 출력을 받아들일지) → 새 결정' '새 결정 → 외부 근거 처분(landscape·premortem 출력을 받아들일지) → 되묻기'` | `✗ AC3: 겹침 순서 부재 또는 뒤바뀜` |
| 5 | 잔존 | `python3 .claude/rda/mutate.py S '- `## R<n>` 은 1부터 순증한다.' '- `## R<n>` 은 1부터 순증한다. Q1 은 생략할 수 없다.'` | `✗ AC3: 라운드 규약 절에 «Q1» 잔존` |
| 6 | 삭제 | `python3 .claude/rda/mutate.py S '`references/steelman.md` 가 사용자에게 묻는 질문은 전부' 'steelman 질문은 전부'` | `✗ AC3: steelman 예외 도출 규칙 부재` |
| 7 | 반전 | `python3 .claude/rda/mutate.py S '«지금 이해»를 «아직 없음»으로' '«지금 이해»를 채워'` | `✗ AC3: 인자 없는 R1 모양 부재` |

(표의 `S` 는 셸에 그 경로를 그대로 적는다 — 변수로 쓰지 않는다. 변이 5 의 인자는 백틱을 담으므로 작은따옴표로 감싼다.) 각 변이는 **그 줄 하나**가 ✗ 여야 한다 — 다른 줄까지 여럿 무너지면 변이 선택이 틀린 것이니 더 좁은 변이로 바꾼다. 결과 7줄을 `.claude/rda/mutations.txt` 에 더한다.

---

### Task 5: 옮겨 가는 규칙

설계 §2.3 의 다섯 행 중 넷(닫힘 근거 · landscape 발화 · 재개방 표시 · 경로 표시)과 blind-spot-prober 전이 문장 · §3.2 닫힘 · 발화 · C43 행 · AC4. 다섯째 행(seed 문단)은 Task 6.

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` («C43 3-path routing» 절 끝 문장 · «닫힘 · 재개방» 절 · «blind-spot-prober dispatch» 절 전이 문장)
- Modify: `plugins/spec-distill/skills/conducting-interview/references/finishing.md:76`
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` (닫힘 락 두 개 재조준 · 신설 넷)

**Interfaces:**
- Consumes: Task 4 의 라운드 규약(«지금 이해» 가 재개방 표시 · 외부 근거 · 경로 (a) 사실을 싣는 자리라는 정의).
- Produces: 닫힘 발화 문구 `landscape = 외부 근거 처분 S`(SKILL · finishing 양쪽). SKILL.md · finishing.md 에 `되비추` 0건 — Task 8 의 별칭 축이 전제한다.

- [ ] **Step 1: 닫힘 · 재개방 절을 새 문구로 쓴다**

Write 도구로 `WT/.claude/rda/t5-close.md`:
```markdown
## 닫힘 · 재개방

**차원은 그 차원에 관한 질문에 사용자가 답한 S 를 근거로만 닫는다**(floor · derived 모두).
sweep·steelman·prober 의 **횟수**는 닫힘 근거가 아니다 — landscape·premortem 출력은 «지금 이해»에 실려,
steelman 출력은 자기 게이트 제시 형식(`references/steelman.md` Step 3)으로 사용자 처분 S 를 받은 뒤 닫힌다.
원장 행의 evidence 는 그 S 를 인용하고, `check_brief.py`가 앵커 실재를 검사한다(«어느 S 가 닫힘을
정당화하는가»는 보지 않는다 — 그 한계는 spec OQ6).
다섯 floor 의 닫힘 발화: root_problem = 재구성 동의 S · landscape = 외부 근거 처분 S ·
skepticism = steelman 판정 S · blind_spot = 숨은 가정·실패 양식 처분 S · open_questions = OQ 목록
확인 S.

**재개방 — `closed → open` 을 허용한다.** 조건: 새 답·외부 근거·코드 사실이 그 차원의 닫힘 근거 S 와
충돌할 때(판단은 orchestrator). 기록: 그 차원의 `reopened` +1, `reopen_log` 에
`{round, reason, conflicts_with: S<N>}` append, 그 라운드의 «지금 이해»에 «→ <차원> 재개방: <사유>».
상한 없음 — 라운드는 사용자 답으로만 돌아 사용자가 시계다. 재개방된 차원이 다시 닫힐 때는 **새 S** 를
인용한다(게이트는 최신 닫힘의 evidence 를 본다).
```
Run:
```bash
python3 .claude/rda/splice.py plugins/spec-distill/skills/conducting-interview/SKILL.md '## 닫힘 · 재개방' '## blind-spot-prober dispatch' .claude/rda/t5-close.md
```

- [ ] **Step 2: blind-spot-prober 전이 문장 · C43 경로 표시 · finishing 76행을 고친다**

Edit 도구 — `plugins/spec-distill/skills/conducting-interview/SKILL.md`:
- old:
  ```
  으로 기록하고, `blind_spot` floor
  차원을 in-progress→closed로 전이한다. web 비활성 시 advisory:
  ```
  new:
  ```
  으로 기록하고, 다음 라운드의
  «지금 이해»에 실어 사용자 처분 S 를 받은 뒤 `blind_spot` floor 차원을 closed 로 전이한다. web 비활성 시 advisory:
  ```
- old: `매 라운드의 «확인한 사실»·«질문» 에 어떤 path 인지 transcript에 명시하십시오.`
  new:
  ```
  매 라운드의 «지금 이해»·«질문» 에 어떤 path 인지 명시하십시오 — 경로 (a) 로 찾을 수 있는 것은 묻기 전에
  먼저 찾아 «지금 이해»에 싣습니다.
  ```

Edit 도구 — `plugins/spec-distill/skills/conducting-interview/references/finishing.md`: old `landscape = 외부 근거 되비추기 처분 S` → new `landscape = 외부 근거 처분 S`

Run:
```bash
grep -n -e '되비추' -e '상충' -e '확인한 사실' plugins/spec-distill/skills/conducting-interview/SKILL.md plugins/spec-distill/skills/conducting-interview/references/finishing.md
```
Expected: 출력 없음.

- [ ] **Step 3: stage 테스트의 닫힘 락을 재조준하고 신설한다**

Edit 도구 — `plugins/spec-distill/tests/test_conducting_interview_stage.sh`, 다섯 자리:

(a) 닫힘 근거 — old:
```
{ [[ -n "$close_block" ]] && grep -qE '사용자가 답한 S[^.]{0,10}뒤에만 닫' <<<"$close_flat"; } \
  && ok "AC1/G2: «차원은 사용자가 답한 S 뒤에만 닫는다»" || no "AC1/G2: 닫힘 규칙 부재"
```
new:
```
# 한정어 «그 차원에 관한» 을 문구째 잡는다 — 어느 S 로 닫혔는지 보는 게이트가 없어(OQ2) 이 산문이
# 유일한 방어선이고, 한정어가 빠지면 아무 S 나 인용해 닫는 것이 규칙상 허용된다.
{ [[ -n "$close_block" ]] && grep -qF '차원은 그 차원에 관한 질문에 사용자가 답한 S 를 근거로만 닫는다' <<<"$close_flat"; } \
  && ok "AC4/G2: «차원은 그 차원에 관한 질문에 사용자가 답한 S 를 근거로만 닫는다»" \
  || no "AC4/G2: 닫힘 규칙(한정어 «그 차원에 관한» 포함) 부재"
```
(b) 재개방 표시 — old:
```
grep -qF '→ <차원> 재개방' <<<"$close_block" \
  && ok "AC5: 상충 줄에 → 재개방" || no "AC5: 상충-재개방 표기 부재"
```
new:
```
grep -qF '«지금 이해»에 «→ <차원> 재개방' <<<"$close_flat" \
  && ok "AC4/AC5: 재개방 표시 자리가 그 라운드의 «지금 이해»" || no "AC4/AC5: 재개방 표시 자리(«지금 이해») 부재"
```
(c) landscape 발화(SKILL) — old:
```
for dim in root_problem landscape skepticism blind_spot open_questions; do
  grep -q "$dim" <<<"$close_block" && ok "§2.1: $dim 의 닫힘 발화 규약" || no "§2.1: $dim 닫힘 발화 규약 부재"
done
```
new:
```
for dim in root_problem landscape skepticism blind_spot open_questions; do
  grep -q "$dim" <<<"$close_block" && ok "§2.1: $dim 의 닫힘 발화 규약" || no "§2.1: $dim 닫힘 발화 규약 부재"
done
# landscape 닫힘 발화는 문구까지 잰다(위 루프는 차원 이름만 본다). finishing.md Step A 4 항도 같은
# 문구여야 한다 — 아래 Step A 4 락이 그쪽을 잰다. 한쪽만 고치면 종료 직렬화가 다른 S 를 인용한다.
grep -qF 'landscape = 외부 근거 처분 S' <<<"$close_flat" \
  && ok "AC4: 닫힘 절의 landscape 닫힘 발화 = 외부 근거 처분 S" || no "AC4: 닫힘 절의 landscape 닫힘 발화 문구 부재"
```
(d) blind-spot 전이 — old:
```
grep -qE 'web 비활성|inline premortem' <<<"$blindspot_block" \
  && ok "C5: web-absent loud degrade to inline premortem" \
  || no "C5: web-absent loud degrade to inline premortem"
```
new:
```
grep -qE 'web 비활성|inline premortem' <<<"$blindspot_block" \
  && ok "C5: web-absent loud degrade to inline premortem" \
  || no "C5: web-absent loud degrade to inline premortem"
blindspot_flat="$(tr '\n' ' ' <<<"$blindspot_block" | tr -s ' ')"
grep -qE '사용자 처분 S 를 받은 뒤[^.]{0,30}closed 로 전이' <<<"$blindspot_flat" \
  && ok "AC4: blind_spot 은 prober 출력의 처분 S 뒤에 closed (닫힘 절과 같은 규칙)" \
  || no "AC4: blind-spot-prober 절이 처분 S 없이 closed 로 전이한다 — 닫힘 절과 어긋난다"
```
(e) finishing Step A 4 — old:
```
grep -qF 'coverage-mapper <k>' <<<"$stepa4" && ok "Step A 4: §2 coverage-mapper <k> 직렬화" || no "Step A 4: coverage-mapper <k> 부재"
```
new:
```
grep -qF 'coverage-mapper <k>' <<<"$stepa4" && ok "Step A 4: §2 coverage-mapper <k> 직렬화" || no "Step A 4: coverage-mapper <k> 부재"
grep -qF 'landscape = 외부 근거 처분 S' <<<"$(tr '\n' ' ' <<<"$stepa4" | tr -s ' ')" \
  && ok "AC4: finishing.md Step A 4 항의 landscape 닫힘 발화 = 외부 근거 처분 S" \
  || no "AC4: Step A 4 항의 landscape 닫힘 발화 문구 부재 (닫힘 절과 갈렸다)"
```
(f) C43 경로 표시 — old:
```
[[ "$c43_prose_n" == "$c43_rows" ]] \
  && ok "C43: 산문이 선언한 경로 수 $c43_prose_n == 표 행 수 $c43_rows" \
  || no "C43: 산문 «다음 ${c43_prose_n:-∅} 경로 중» 이 표 행 수 ${c43_rows:-∅} 와 다르다"
```
new:
```
[[ "$c43_prose_n" == "$c43_rows" ]] \
  && ok "C43: 산문이 선언한 경로 수 $c43_prose_n == 표 행 수 $c43_rows" \
  || no "C43: 산문 «다음 ${c43_prose_n:-∅} 경로 중» 이 표 행 수 ${c43_rows:-∅} 와 다르다"
c43_flat="$(tr '\n' ' ' <<<"$c43_block" | tr -s ' ')"
grep -qF '매 라운드의 «지금 이해»·«질문» 에 어떤 path 인지' <<<"$c43_flat" \
  && ok "AC4: C43 경로 표시 자리 = 매 라운드의 «지금 이해»·«질문»" \
  || no "AC4: C43 경로 표시 자리가 «지금 이해»·«질문» 이 아니다"
```

- [ ] **Step 4: 표적 테스트를 돌린다**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh`
Expected: `Total: … | Fail: 0`, 신설 5줄(`AC4: 닫힘 절의 landscape…` · `AC4: blind_spot 은…` · `AC4: finishing.md Step A 4…` · `AC4: C43 경로 표시…` · `AC4/AC5: 재개방 표시…`)이 ✓.

- [ ] **Step 5: 판정기로 전체를 잰다 (AC10)**

Run (`run_in_background: true`): `python3 .claude/rda/collect.py collect --root /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+remove-depth-audit --out .claude/rda/t5.json`
Run: `python3 .claude/rda/collect.py compare .claude/rda/base.json .claude/rda/t5.json --deleted plugins/spec-distill/tests/test_depth_auditor_frontmatter.sh --deleted-py test_depth_pairs --deleted-py test_depth_record`
Expected: `판정: 새 실패 0 · 완료 증거 전부 있음 (문제 0건)`

- [ ] **Step 6: 커밋한다**

Write 도구로 `WT/.claude/rda/msg-t5.txt`:
```
refactor(spec-distill): 블록에 기대던 닫힘 · 재개방 · 경로 표시 규칙을 새 자리로

닫힘 근거를 «그 차원에 관한 질문에 사용자가 답한 S» 로(blind-spot-prober 절의 전이 문장도
처분 S 뒤로), landscape 닫힘 발화를 «외부 근거 처분 S» 로(SKILL · finishing 양쪽), 재개방
표시와 C43 경로 표시를 그 라운드의 «지금 이해» 로 옮겼다. 각 자리에 문구 락을 걸었다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Um5Znb7UcRUQ4SP3u3TobS
```
Run:
```bash
git add plugins/spec-distill/skills/conducting-interview/SKILL.md plugins/spec-distill/skills/conducting-interview/references/finishing.md plugins/spec-distill/tests/test_conducting_interview_stage.sh
git status --porcelain
git commit -F .claude/rda/msg-t5.txt
```

- [ ] **Step 7: 새 락을 변이로 흔든다 (V3 · AC4)**

`S` = `plugins/spec-distill/skills/conducting-interview/SKILL.md`, `F` = `plugins/spec-distill/skills/conducting-interview/references/finishing.md`. 변이마다 stage 테스트를 돌려 기대 ✗ 줄 확인 → 그 파일 `git checkout --` → `git status --porcelain` 빈 출력.

| # | 축 | 명령 | 기대 ✗ 줄 |
|---|---|---|---|
| 1 | 반전(한정어 제거) | `python3 .claude/rda/mutate.py S '차원은 그 차원에 관한 질문에 사용자가 답한 S' '차원은 사용자가 답한 S'` | `✗ AC4/G2: 닫힘 규칙(한정어 «그 차원에 관한» 포함) 부재` |
| 2 | 위치 | `python3 .claude/rda/mutate.py S '그 라운드의 «지금 이해»에 «→ <차원> 재개방' '그 라운드의 «상충» 줄에 «→ <차원> 재개방'` | `✗ AC4/AC5: 재개방 표시 자리(«지금 이해») 부재` |
| 3 | 값 | `python3 .claude/rda/mutate.py S 'landscape = 외부 근거 처분 S' 'landscape = 외부 근거 확인 S'` | `✗ AC4: 닫힘 절의 landscape 닫힘 발화 문구 부재` |
| 4 | 값 | `python3 .claude/rda/mutate.py F 'landscape = 외부 근거 처분 S' 'landscape = 외부 근거 확인 S'` | `✗ AC4: Step A 4 항의 landscape 닫힘 발화 문구 부재 (닫힘 절과 갈렸다)` |
| 5 | 삭제 | `python3 .claude/rda/mutate.py S '사용자 처분 S 를 받은 뒤 `blind_spot` floor' '`blind_spot` floor'` | `✗ AC4: blind-spot-prober 절이 처분 S 없이 closed 로 전이한다 — 닫힘 절과 어긋난다` |
| 6 | 값 | `python3 .claude/rda/mutate.py S '매 라운드의 «지금 이해»·«질문» 에 어떤 path' '매 라운드의 «확인한 사실»·«질문» 에 어떤 path'` | `✗ AC4: C43 경로 표시 자리가 «지금 이해»·«질문» 이 아니다` |

결과 6줄을 `.claude/rda/mutations.txt` 에 더한다.

---

### Task 6: seed 문단 소비 자리

설계 §2.3 다섯째 행 · §2.5(seed 템플릿) · §3.2 seed 문단 소비 행 · AC4.

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/references/seed-input.md:11-12`
- Modify: `plugins/spec-distill/skills/framing-requests/SKILL.md:44-46`
- Modify: `plugins/spec-distill/templates/interview-seed-template.md:41`
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` (seed 락 뒤 한 개 신설)
- Modify: `plugins/spec-distill/tests/test_request_framing_command.sh` (AC11 블록에 두 개 신설)

**Interfaces:**
- Consumes: Task 4 의 «지금 이해» 정의.
- Produces: seed 쪽 세 파일에 `직전 답에서` · `되비추` · `되비춘` 0건 — Task 8 전제.

- [ ] **Step 1: 세 파일의 문구를 고친다**

Edit 도구 — `plugins/spec-distill/skills/conducting-interview/references/seed-input.md`:
- old:
  ```
  - **seed 의 마지막 문단 «다시 검증할 것 —»** 이 R1 의 «직전 답에서 — S1» 블록(함의·상충·위험)과
    coverage-mapper 첫 dispatch 의 입력이다. 문단이 없으면 seed 본문 전체를 그 입력으로 쓰되 무표시 문장은 전부 미확인이다.
  ```
  new:
  ```
  - **seed 의 마지막 문단 «다시 검증할 것 —»** 은 R1 의 «지금 이해»·질문의 재료이자 coverage-mapper 첫
    dispatch 의 입력이다. 문단이 없으면 seed 본문 전체를 그 입력으로 쓰되 무표시 문장은 전부 미확인이다.
  ```

Edit 도구 — `plugins/spec-distill/skills/framing-requests/SKILL.md`:
- old: `Phase 1 은 이 문단을 R1 의 «직전 답에서 — S1» 블록과 coverage-mapper 첫`
  new: `Phase 1 은 이 문단을 R1 의 «지금 이해»·질문의 재료와 coverage-mapper 첫`
- old: `필요하면 Phase 1 이 되비추기로 검증합니다.`
  new: `필요하면 Phase 1 이 질문으로 검증합니다.`

Edit 도구 — `plugins/spec-distill/templates/interview-seed-template.md`:
- old: `| 방향의 근거이되 미확인 — Phase 1 이 되비춘다 |`
  new: `| 방향의 근거이되 미확인 — Phase 1 이 질문으로 확인한다 |`

Run:
```bash
grep -n -e '직전 답에서' -e '되비추' -e '되비춘' plugins/spec-distill/skills/conducting-interview/references/seed-input.md plugins/spec-distill/skills/framing-requests/SKILL.md plugins/spec-distill/templates/interview-seed-template.md
```
Expected: 출력 없음.

- [ ] **Step 2: 두 테스트에 소비 자리 락을 신설한다**

Edit 도구 — `plugins/spec-distill/tests/test_conducting_interview_stage.sh`:
- old:
  ```
  grep -qF '다시 검증할 것' <<<"$seed_flat" \
    && ok "AC11: seed 의 «다시 검증할 것» 문단을 R1/coverage-mapper 입력으로" \
    || no "AC11: seed 재검증 문단 소비 부재"
  ```
  new:
  ```
  grep -qF '다시 검증할 것' <<<"$seed_flat" \
    && ok "AC11: seed 의 «다시 검증할 것» 문단을 R1/coverage-mapper 입력으로" \
    || no "AC11: seed 재검증 문단 소비 부재"
  # 위 단언은 낱말 하나만 봐서 그 문단을 «어디에» 쓰는지는 못 잰다. 한 문장 안에서 R1 의
  # «지금 이해» · coverage-mapper 첫 dispatch 둘 다와 결속됐는지 본다.
  grep -qF '«다시 검증할 것 —»** 은 R1 의 «지금 이해»·질문의 재료이자 coverage-mapper 첫 dispatch 의 입력' <<<"$seed_flat" \
    && ok "AC4: seed 재검증 문단 = R1 «지금 이해»·질문의 재료 + coverage-mapper 첫 dispatch 입력" \
    || no "AC4: seed 재검증 문단의 소비 자리가 R1 «지금 이해»·coverage-mapper 로 결속되지 않았다"
  ```

Edit 도구 — `plugins/spec-distill/tests/test_request_framing_command.sh`:
- old:
  ```
  grep -qE '그 밖[^.]{0,30}미확인|나머지[^.]{0,30}미확인' <<<"$conv_flat" && ok "AC11: 무표시 = 미확인" || no "AC11: 무표시=미확인 문장 부재"
  ```
  new:
  ```
  grep -qE '그 밖[^.]{0,30}미확인|나머지[^.]{0,30}미확인' <<<"$conv_flat" && ok "AC11: 무표시 = 미확인" || no "AC11: 무표시=미확인 문장 부재"
  # Phase 1 이 이 문단을 어디에 쓰는가 — conducting-interview references/seed-input.md 와 같은 자리여야
  # 한다(두 문서가 갈라지면 Phase 0 은 없는 블록을 겨냥해 문단을 쓴다).
  grep -qF 'Phase 1 은 이 문단을 R1 의 «지금 이해»·질문의 재료와 coverage-mapper 첫 dispatch 의 입력으로 씁니다' <<<"$conv_flat" \
    && ok "AC4: 재검증 문단의 소비 자리 = R1 «지금 이해»·질문 + coverage-mapper 첫 dispatch" \
    || no "AC4: 재검증 문단의 소비 자리가 seed-input.md 와 갈렸다"
  grep -qF '필요하면 Phase 1 이 질문으로 검증합니다' <<<"$conv_flat" \
    && ok "AC4: 무표시 문장은 Phase 1 이 질문으로 검증한다" || no "AC4: 무표시 문장의 검증 방식 문장 부재"
  ```

- [ ] **Step 3: 표적 테스트를 돌린다**

Run (각각):
```bash
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh
bash plugins/spec-distill/tests/test_request_framing_command.sh
```
Expected: 둘 다 `Fail: 0` — stage 218개 · framing 41개(모의 실행 실측).

- [ ] **Step 4: 판정기로 전체를 잰다 (AC10)**

Run (`run_in_background: true`): `python3 .claude/rda/collect.py collect --root /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+remove-depth-audit --out .claude/rda/t6.json`
Run: `python3 .claude/rda/collect.py compare .claude/rda/base.json .claude/rda/t6.json --deleted plugins/spec-distill/tests/test_depth_auditor_frontmatter.sh --deleted-py test_depth_pairs --deleted-py test_depth_record`
Expected: `판정: 새 실패 0 · 완료 증거 전부 있음 (문제 0건)`

- [ ] **Step 5: 커밋한다**

Write 도구로 `WT/.claude/rda/msg-t6.txt`:
```
refactor(spec-distill): seed 재검증 문단의 소비 자리를 R1 «지금 이해» 로

Phase 0 seed 의 «다시 검증할 것» 문단은 이제 R1 의 «지금 이해»·질문의 재료이자
coverage-mapper 첫 dispatch 의 입력이다(seed-input.md · framing-requests 양쪽 · seed 템플릿 표).
무표시 문장은 Phase 1 이 질문으로 검증한다. 두 문서의 결속을 각자의 테스트가 문구로 잰다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Um5Znb7UcRUQ4SP3u3TobS
```
Run:
```bash
git add plugins/spec-distill/skills/conducting-interview/references/seed-input.md plugins/spec-distill/skills/framing-requests/SKILL.md plugins/spec-distill/templates/interview-seed-template.md plugins/spec-distill/tests/test_conducting_interview_stage.sh plugins/spec-distill/tests/test_request_framing_command.sh
git status --porcelain
git commit -F .claude/rda/msg-t6.txt
```

- [ ] **Step 6: 새 락을 변이로 흔든다 (V3 · AC4)**

| # | 축 | 명령 | 테스트 | 기대 ✗ 줄 |
|---|---|---|---|---|
| 1 | 값 | `python3 .claude/rda/mutate.py plugins/spec-distill/skills/conducting-interview/references/seed-input.md 'R1 의 «지금 이해»·질문의 재료이자' 'R1 의 첫 블록의 재료이자'` | stage | `✗ AC4: seed 재검증 문단의 소비 자리가 R1 «지금 이해»·coverage-mapper 로 결속되지 않았다` |
| 2 | 값 | `python3 .claude/rda/mutate.py plugins/spec-distill/skills/framing-requests/SKILL.md 'R1 의 «지금 이해»·질문의 재료와' 'R1 의 블록과'` | framing | `✗ AC4: 재검증 문단의 소비 자리가 seed-input.md 와 갈렸다` |
| 3 | 반전 | `python3 .claude/rda/mutate.py plugins/spec-distill/skills/framing-requests/SKILL.md 'Phase 1 이 질문으로 검증합니다.' 'Phase 1 이 검증하지 않습니다.'` | framing | `✗ AC4: 무표시 문장의 검증 방식 문장 부재` |

각 변이 뒤 해당 파일 `git checkout --` · `git status --porcelain` 빈 출력. 결과 3줄을 `.claude/rda/mutations.txt` 에 더한다.

---

### Task 7: README와 command 문구

설계 §2.5 · C4. 이 task 는 락을 새로 쓰지 않는다 — 문구의 부재는 Task 8 이 잰다.

**Files:**
- Modify: `plugins/spec-distill/README.md:7,22,36,145`
- Modify: `plugins/spec-distill/commands/interview.md:46`

**Interfaces:**
- Produces: README · command 에 제거 식별자(`직전 답에서` · `깊이 측정` · `depth-*` · `provisional_on`) 0건, `질문 둘` 0건 — Task 8 의 식별자 축 GREEN 전제. **README 새 문구에 `깊이 측정` 을 쓰지 않는다**(설계 Deferred — 식별자 축이 README 를 포함한다).

- [ ] **Step 1: README 네 자리를 고친다**

Edit 도구 — `plugins/spec-distill/README.md`:
- 7행 old: `` `/interview <rough request>` 호출 시 «직전 답에서» 블록 + 질문 둘 형식의 Korean Socratic``
  new: `` `/interview <rough request>` 호출 시 «지금 이해 · 다음 결정 · 질문 하나» 형식의 Korean Socratic``
- 22행 old: `` `conducting-interview` skill이 «직전 답에서» 블록 + 질문 둘 형식으로 첫 round를 시작합니다.``
  new: `` `conducting-interview` skill이 «지금 이해 · 다음 결정 · 질문 하나» 형식으로 첫 round를 시작합니다.``
- 36행 old: `· «직전 답에서» 블록 + 질문 둘 + 3-path (web=path(a))`
  new: `· 지금 이해 · 다음 결정 · 질문 하나 + 3-path (web=path(a))`
- 145행 old: `v0.57.0에서 **라운드 규약의** 4-block 이 «직전 답에서» 블록 + 질문 둘로 대체됐다. 형식 자체가 리포에서 사라진 것은 아니다 —`
  new: `라운드 규약은 v0.57.0 에서 4-block 을 다른 블록 구성으로 바꿨다가, 지금은 그 후손인 «지금 이해 / 다음 결정 / 질문 하나»로 돌아왔다. 4-block 형식 자체도 리포에 남아 있다 —`

Edit 도구 — `plugins/spec-distill/commands/interview.md`:
- old: `` `conducting-interview` skill이 «직전 답에서» 블록 + 질문 둘 형식으로 첫 round를 진행합니다.``
  new: `` `conducting-interview` skill이 «지금 이해 · 다음 결정 · 질문 하나» 형식으로 첫 round를 진행합니다.``

Run:
```bash
git grep -n -e '직전 답에서' -e '질문 둘' -e '깊이 측정' -e depth- -e depth_ -e provisional_on -- plugins/spec-distill/README.md plugins/spec-distill/commands/interview.md
```
Expected: 출력 없음.

- [ ] **Step 2: 표적 테스트를 돌린다**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh`
Expected: `Fail: 0` — 특히 `✓ C43: SKILL·README 의 «<n>-path» 표기가 하나뿐이고 표 행 수 3 와 같다` (36행의 `3-path` 가 살아 있다).

- [ ] **Step 3: 판정기로 전체를 잰다 (AC10)**

Run (`run_in_background: true`): `python3 .claude/rda/collect.py collect --root /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+remove-depth-audit --out .claude/rda/t7.json`
Run: `python3 .claude/rda/collect.py compare .claude/rda/base.json .claude/rda/t7.json --deleted plugins/spec-distill/tests/test_depth_auditor_frontmatter.sh --deleted-py test_depth_pairs --deleted-py test_depth_record`
Expected: `판정: 새 실패 0 · 완료 증거 전부 있음 (문제 0건)`

- [ ] **Step 4: 커밋한다**

Write 도구로 `WT/.claude/rda/msg-t7.txt`:
```
docs(spec-distill): README · /interview 의 라운드 형식 서술을 지금 이해 · 다음 결정 · 질문 하나로

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Um5Znb7UcRUQ4SP3u3TobS
```
Run:
```bash
git add plugins/spec-distill/README.md plugins/spec-distill/commands/interview.md
git status --porcelain
git commit -F .claude/rda/msg-t7.txt
```

---

### Task 8: stale-term 축

설계 §3.4 · C4 · AC2 · V0 · V5.

**Files:**
- Modify: `plugins/spec-distill/tests/test_stale_terms.sh` (V10 목록 · 개수 락 · V13 신설)

**Interfaces:**
- Consumes: Task 3–7 이 끝낸 production 트리(식별자 · 별칭 0건). `alias_files` 배열(이 파일 V9 절이 정의 — README 를 뺀 prod_files) · `scan()` · `$SKILL`.
- Produces: 부재 락 V13(식별자 6 · 별칭 4 · 양성 짝 2) · V10 부재 목록 37개.

- [ ] **Step 1: V10 목록에 17개를 더하고 개수 락을 37 로 고친다**

Edit 도구 — `plugins/spec-distill/tests/test_stale_terms.sh`:
- old:
  ```
    'tests/test_stale_state_truncate.sh'
  )
  ```
  new:
  ```
    'tests/test_stale_state_truncate.sh'
    # depth audit 제거 — 사후 측정 층. 되살아나면 무참조로 조용히 눌러앉는다.
    # docs/superpowers/interview/depth/.gitkeep 은 $SD 밖이라 여기 넣지 않는다.
    'agents/depth-auditor.md'
    'scripts/depth_pairs.py'
    'scripts/depth_record.py'
    'tests/test_depth_pairs.py'
    'tests/test_depth_record.py'
    'tests/test_depth_auditor_frontmatter.sh'
    'tests/fixtures/depth-state-allnone.md'
    'tests/fixtures/depth-state-badstatements.md'
    'tests/fixtures/depth-state-elig0.md'
    'tests/fixtures/depth-state-elig1.md'
    'tests/fixtures/depth-state-elig3.md'
    'tests/fixtures/depth-state-emptystatements.md'
    'tests/fixtures/depth-state-nofrontmatter.md'
    'tests/fixtures/depth-state-normal.md'
    'tests/fixtures/depth-state-noround.md'
    'tests/fixtures/depth-state-nostatementskey.md'
    'tests/fixtures/depth-state-templatecomment.md'
  )
  ```
- old:
  ```
  [[ ${#removed_files[@]} -eq 20 ]] \
    && ok "V10/T5: 부재 락 목록이 20개다 (항목이 조용히 빠지지 않았다)" \
    || no "V10/T5: 부재 락 목록이 ${#removed_files[@]}개 — 20개여야 한다. 항목을 의도적으로 더하거나 뺐다면 이 숫자도 같은 커밋에서 고쳐라"
  ```
  new:
  ```
  [[ ${#removed_files[@]} -eq 37 ]] \
    && ok "V10/T5: 부재 락 목록이 37개다 (항목이 조용히 빠지지 않았다)" \
    || no "V10/T5: 부재 락 목록이 ${#removed_files[@]}개 — 37개여야 한다. 항목을 의도적으로 더하거나 뺐다면 이 숫자도 같은 커밋에서 고쳐라"
  ```

- [ ] **Step 2: V13 축을 신설한다**

Edit 도구 — 파일 끝의 V11 둘째 단언과 `finish` 사이에 넣는다. old:
```
  || no "V11: Stop 훅의 armed 판정이 소비 위치에 없다 (주석/neutered 호출 의심 — 게이트 증발)"
finish
```
new:
````
  || no "V11: Stop 훅의 armed 판정이 소비 위치에 없다 (주석/neutered 호출 의심 — 게이트 증발)"

# --- V13: depth audit 제거 — 사후 측정 층과 옛 라운드 형식의 어휘가 production 에 0건 ---
# 번호는 다음 빈 번호다(V10 · V11 · V12 가 이미 쓰인다).
# 식별자 축 — 스코프 = prod_files 그대로(README.md 포함). README 는 이 제거를 개념으로 서술하고
# 식별자를 인용하지 않는다. `depth-audit`(센티널 이름)은 넣지 않는다: 이 제거의 설계문서
# 파일명(…-remove-depth-audit-design.md)과 겹치고, production 은 설계문서 경로를 출처로 인용하는
# 관례가 있어 정직한 인용까지 RED 가 된다. 그 이름이 살던 두 파일은 V10 이 부재를 잰다.
depth_terms=(
  'depth_pairs'
  'depth_record'
  'depth-auditor'
  '직전 답에서'
  'provisional_on'
  '깊이 측정'
)
for term in "${depth_terms[@]}"; do
  scan -inIF -- "$term" "${prod_files[@]}"
  if [[ $SCAN_RC -ge 2 ]]; then
    no "V13: '$term' 검사가 실행되지 않았다 — grep 자체 실패(exit=$SCAN_RC):"
    printf '%s\n' "$SCAN_OUT"
  elif [[ $SCAN_RC -eq 0 ]]; then
    no "V13: '$term' 가 production에 잔존:"; printf '%s\n' "$SCAN_OUT"
  else
    ok "V13: '$term' 잔존 0건 (production)"
  fi
done
# 개념 별칭 축 — 식별자만 재면 활용 · 어순이 다른 서술(«되비춘다» · «판정자 투입 조건»)이
# 살아남는다. V9 별칭과 같은 이유로 README 는 뺀다(alias_files): README 는 삭제 연혁을 정직하게
# 적는 자리라 별칭까지 재면 정직한 서술이 RED 가 되고, 그러면 락이 무시된다.
# `Q1` 은 넣지 않는다 — `OQ1` 과 겹친다.
depth_alias_terms=(
  '되비추'
  '되비춘'
  '판정자 조건'
  '판정자 투입'
)
for term in "${depth_alias_terms[@]}"; do
  scan -inIF -- "$term" "${alias_files[@]}"
  if [[ $SCAN_RC -ge 2 ]]; then
    no "V13: 별칭 '$term' 검사가 실행되지 않았다 — grep 자체 실패(exit=$SCAN_RC):"
    printf '%s\n' "$SCAN_OUT"
  elif [[ $SCAN_RC -eq 0 ]]; then
    no "V13: 별칭 '$term' 가 production에 잔존:"; printf '%s\n' "$SCAN_OUT"
  else
    ok "V13: 별칭 '$term' 잔존 0건 (README 제외 production)"
  fi
done
# 양성 짝 — 부재 락은 대상 절을 통째로 지워도 통과한다. 새 라운드 규약에만 있는 문구 둘이
# 그 절에 실재하는가(`### 지금 이해` 는 옛 형식에도 있던 소제목이라 새 형식의 증거가 못 된다).
v13_round="$(awk '/^```/{c=!c} /^## 라운드 규약/{f=1;print;next} !c && /^## /{f=0} f' "$SKILL")"
v13_flat="$(tr '\n' ' ' <<<"$v13_round" | tr -s ' ')"
[[ -n "$v13_round" ]] \
  && ok "V13(양성대조): 라운드 규약 절을 떴다" \
  || no "V13(양성대조): 라운드 규약 절 부재 — 아래 양성 짝이 공허하다"
grep -qF '**질문 1개**' <<<"$v13_flat" \
  && ok "V13 양성 짝: 라운드 규약에 «질문 1개»" \
  || no "V13 양성 짝: 라운드 규약에 «질문 1개» 가 없다 — 새 형식이 사라졌다"
grep -qF '같은 주제의 연속 되묻기는 최대 2회' <<<"$v13_flat" \
  && ok "V13 양성 짝: 라운드 규약에 되묻기 상한 문구" \
  || no "V13 양성 짝: 라운드 규약에 되묻기 상한 문구가 없다 — 새 형식이 사라졌다"
finish
````

- [ ] **Step 3: 표적 테스트를 돌린다**

Run: `bash plugins/spec-distill/tests/test_stale_terms.sh`
Expected: `Fail: 0`. 계획 작성 시점 47개 + V10 17 + V13 13(식별자 6 · 별칭 4 · 양성 3) = 77개.

- [ ] **Step 4: 잔존 스윕 두 개를 돌린다 (V0 · V5)**

Run:
```bash
git grep -n -I -F -e depth_pairs -e depth_record -e depth-auditor -e '직전 답에서' -e provisional_on -e '깊이 측정' -e '되비추' -e '되비춘' -e '판정자 조건' -e '판정자 투입' -- plugins/spec-distill ':!plugins/spec-distill/CHANGELOG.md' ':!plugins/spec-distill/tests'
git grep -n -I -E -e 'A\.7' -e 'depth/' -e '상충 줄' -e '질문 둘' -e '(^|[^O])Q[12]([^0-9]|$)' -- plugins/spec-distill ':!plugins/spec-distill/CHANGELOG.md' ':!plugins/spec-distill/tests'
git grep -n -l -e 'interview/depth' -e depth_record -e depth-auditor -- . ':!docs/superpowers/specs' ':!docs/superpowers/plans' ':!docs/superpowers/interview' ':!plugins/spec-distill/CHANGELOG.md' ':!plugins/spec-distill/tests'
```
Expected: 셋 다 출력 없음. 걸리면 그 줄을 Read 로 열어 판정한다 — 살아 있는 참조면 이 task 에서 고치고(파일 지도 밖이면 멈추고 보고), 다른 뜻이면 사유를 `.claude/rda/v5.txt` 에 적는다.

- [ ] **Step 5: 판정기로 전체를 잰다 (AC10)**

Run (`run_in_background: true`): `python3 .claude/rda/collect.py collect --root /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+remove-depth-audit --out .claude/rda/t8.json`
Run: `python3 .claude/rda/collect.py compare .claude/rda/base.json .claude/rda/t8.json --deleted plugins/spec-distill/tests/test_depth_auditor_frontmatter.sh --deleted-py test_depth_pairs --deleted-py test_depth_record`
Expected: `판정: 새 실패 0 · 완료 증거 전부 있음 (문제 0건)`

- [ ] **Step 6: 커밋한다**

Write 도구로 `WT/.claude/rda/msg-t8.txt`:
```
test(spec-distill): depth audit 제거 어휘의 stale-term 축(V13) · V10 부재 목록 37

식별자 여섯(README 포함) · 개념 별칭 넷(README 제외, V9 와 같은 이유) · 새 라운드 규약의
양성 짝 둘. 삭제 파일 17개를 V10 부재 목록에 더하고 개수 락을 20 → 37 로 고쳤다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Um5Znb7UcRUQ4SP3u3TobS
```
Run:
```bash
git add plugins/spec-distill/tests/test_stale_terms.sh
git status --porcelain
git commit -F .claude/rda/msg-t8.txt
```

- [ ] **Step 7: 변이로 흔든다 (AC2)**

`S` = `plugins/spec-distill/skills/conducting-interview/SKILL.md`, `R` = `plugins/spec-distill/README.md`, `T` = `plugins/spec-distill/tests/test_stale_terms.sh`. SKILL 마지막 줄은 `- \`DEVBREW_SPEC_DISTILL_DISABLE_WEB=1\`: web landscape(R2) 비활성 — loud advisory 후 codebase 근거만 사용.` 이다 — 이것을 OLD 로 쓰는 변이는 Write 도구로 `.claude/rda/m8-old.txt` 에 그 한 줄을 쓰고 `@` 로 넘긴다. 변이마다 `bash plugins/spec-distill/tests/test_stale_terms.sh` → 기대 줄 확인 → 그 파일 `git checkout --` → `git status --porcelain` 빈 출력.

| # | 축 | 준비 · 명령 | 기대 줄 |
|---|---|---|---|
| 1 | 식별자 → SKILL | `.claude/rda/m8-new1.txt` = m8-old 내용 + 줄바꿈 + `provisional_on` · `python3 .claude/rda/mutate.py S @.claude/rda/m8-old.txt @.claude/rda/m8-new1.txt` | `✗ V13: 'provisional_on' 가 production에 잔존:` |
| 2 | 별칭 → SKILL | `.claude/rda/m8-new2.txt` = m8-old 내용 + 줄바꿈 + `Phase 1 이 되비춘다` · `python3 .claude/rda/mutate.py S @.claude/rda/m8-old.txt @.claude/rda/m8-new2.txt` | `✗ V13: 별칭 '되비춘' 가 production에 잔존:` |
| 3 | 별칭 → README (면제 동작) | `python3 .claude/rda/mutate.py R '# spec-distill' '# spec-distill

Phase 1 이 되비춘다'` | `✓ V13: 별칭 '되비춘' 잔존 0건 (README 제외 production)` 이 **그대로 ✓** |
| 4 | 식별자 → README (포함 동작) | `python3 .claude/rda/mutate.py R '# spec-distill' '# spec-distill

depth-auditor'` | `✗ V13: 'depth-auditor' 가 production에 잔존:` |
| 5 | 양성 짝 삭제 | `python3 .claude/rda/mutate.py S 'AskUserQuestion 1회, **질문 1개**다.' 'AskUserQuestion 1회다.'` | `✗ V13 양성 짝: 라운드 규약에 «질문 1개» 가 없다 — 새 형식이 사라졌다` |
| 6 | V10 항목 제거 | `python3 .claude/rda/mutate.py T "  'tests/fixtures/depth-state-allnone.md'" ''` | `✗ V10/T5: 부재 락 목록이 36개 — 37개여야 한다.` |

변이 3·4 의 `'# spec-distill'` 은 README 첫 줄이고 파일 안에 한 번뿐이다(모의 실행 확인). 두 변이의 NEW 는 개행을 담으므로 작은따옴표 안에 줄바꿈을 그대로 쓰거나 `@파일` 로 넘긴다. 결과 6줄을 `.claude/rda/mutations.txt` 에 더한다.

---

### Task 9: 사람 e2e

**`.claude/rda/e2e-decision.txt` 첫 줄이 `실행` 일 때만** 한다. `미실행` 이면 이 task 를 건너뛰고 Task 10 으로 간다. **사용자가 직접 한다** — 컨트롤러는 안내하고 결과를 받아 적는다.

**Files:**
- Create: `.claude/rda/e2e.txt`

**Interfaces:**
- Produces: `.claude/rda/e2e.txt` — 체크리스트 5줄의 통과/실패와 관찰. Task 11 CHANGELOG Verification 이 인용한다.

- [ ] **Step 1: 사용자에게 실행 방법과 체크리스트를 보인다**

사용자에게 아래를 그대로 보인다:
```
다른 터미널에서:
  cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+remove-depth-audit
  claude --plugin-dir /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+remove-depth-audit/plugins/spec-distill
그 세션에서 `/interview <작은 주제 한 줄>` 로 시작해 3라운드 이상 답하고, 한 번은 한 단어로 답한 뒤,
«여기서 종료» 를 요청해 종료 절차(brief 작성 → proceed 게이트)까지 가 주세요.

확인할 것:
1. 각 라운드 출력이 `## R<n>` · 지금 이해 · 다음 결정 · 질문 · 답 모양이다.
2. 라운드마다 AskUserQuestion 한 번에 질문이 하나다(steelman 게이트 질문은 예외).
3. 첫 선택지 라벨 끝에 (권장) 이 붙는다.
4. 한 단어로 답한 다음 라운드가 이유 · 사례 · 실패 조건 중 하나를 되묻는다.
5. 종료 때 깊이 라벨 질문이 없고, proceed 게이트 질문에 «깊이:» 줄이 없다.
```

- [ ] **Step 2: 결과를 기록한다**

사용자의 보고를 Write 도구로 `.claude/rda/e2e.txt` 에 항목별 통과/실패 + 한 줄 관찰로 적는다. 실패 항목이 있으면 **멈추고** 사용자와 원인을 본다 — 산문 수정이 필요하면 Task 4–5 와 같은 방식(편집 → 표적 테스트 → 판정기 → 커밋 → 변이)으로 한 커밋을 더한다.

---

### Task 10: 브랜치 전체 리뷰

설계 V7. 컨트롤러가 리뷰어를 dispatch 한다 — 리뷰어는 쓰기 도구가 없는 agent 여야 한다(Law 2).

**Files:** 리뷰가 지적한 것만.

**Interfaces:**
- Consumes: 브랜치 `feature/remove-depth-audit` 의 `origin/main...HEAD`.
- Produces: 지적별 처분 기록 `.claude/rda/review.txt`.

- [ ] **Step 1: 리뷰어를 dispatch 한다**

```
Agent({
  description: "Whole-branch review of depth audit removal",
  subagent_type: "feature-dev:code-reviewer",
  prompt: "리포 루트는 /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+remove-depth-audit (git 워크트리, 브랜치 feature/remove-depth-audit). 모든 경로는 이 절대경로 기준으로 읽어라 — 메인 체크아웃 /Users/jeonghokim/Downloads/devbrew 의 파일은 다른 상태다.
설계: docs/superpowers/specs/2026-09-10-remove-depth-audit-design.md · 계획: docs/superpowers/plans/2026-09-10-remove-depth-audit.md.
리뷰 대상: `git diff origin/main...HEAD` 로 보이는 이 브랜치의 변경(Task 1 이 origin/main 을 merge 했으므로 이 브랜치의 것만 보인다 · 계획 문서 제외). 볼 것:
(1) 설계 AC1–AC10 중 어느 것이 코드·문서로 충족되지 않았는가 — 항목마다 file:line 근거.
(2) 삭제된 것(depth-auditor · depth_pairs.py · depth_record.py · Step A.7 · «직전 답에서» 블록 · 질문 둘 · provisional_on · 되비추기)을 현재형으로 가리키는 살아 있는 참조가 production(plugins/spec-distill 아래, CHANGELOG.md·tests/ 제외)이나 리포 루트 문서(CLAUDE.md · docs/philosophy/)에 남았는가 — 식별자만이 아니라 개념 별칭으로도 찾아라.
(3) 새로 쓰거나 고친 락(tests/test_conducting_interview_stage.sh 의 라운드 규약 · 닫힘 · seed · C43 블록, tests/test_stale_terms.sh V13 · V10, tests/test_request_framing_command.sh 의 AC4 두 줄, tests/test_finishing_block_scope.py)이 대상 문구를 통째로 지우거나 반전해도 GREEN 인 자리가 있는가(헤더 · 다른 문장이 문구를 대신 만족시키는 경우 포함).
(4) 새 SKILL 산문(conducting-interview/SKILL.md 의 «라운드 규약» · «닫힘 · 재개방» 절)이 서로 · references/steelman.md · references/finishing.md 와 모순하는가.
각 지적은 심각도(critical/important/minor) · file:line · 실패 시나리오 한 줄로. 확신이 없으면 그렇게 적어라."
})
```

- [ ] **Step 2: 지적을 처분한다**

지적마다 `.claude/rda/review.txt` 에 «수용 — 무엇을 고쳤나 / 기각 — 근거(file:line)» 한 줄. 수용한 것은 Task 4–5 와 같은 순서(편집 → 표적 테스트 → 판정기 compare → 커밋 → 새 락이면 변이)로 고친다. 커밋 메시지는 `fix(spec-distill): <지적 요지> (브랜치 리뷰)`. critical/important 가 남아 있으면 Task 11 로 가지 않는다.

- [ ] **Step 3: 브랜치가 붙어 있는지 확인한다**

Run: `git branch --show-current`
Expected: `feature/remove-depth-audit` (리뷰 agent 의 checkout 이 detached HEAD 를 남기는 사고가 있었다 — 비었으면 `git checkout feature/remove-depth-audit`).

---

### Task 11: 릴리스

설계 C2 · C3 · C6(merge 뒤 재기준선) · §4 · AC8 · AC9 · AC10 · V0 · V4. **PR 을 머지하기 직전에** 한다 — 사이에 `origin/main` 이 또 움직이면 Step 1–7 을 다시 한다(버전은 먼저 머지되는 쪽이 이긴다).

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` (`version`)
- Modify: `plugins/spec-distill/CHANGELOG.md` (최상단 절)

**Interfaces:**
- Consumes: `.claude/rda/comp.txt`(Task 3) · `.claude/rda/mutations.txt` · `.claude/rda/e2e-decision.txt` · `.claude/rda/e2e.txt`(있으면) · `.claude/rda/flaky.txt`(있으면) · `.claude/rda/base-notes.txt`(있으면).
- Produces: 릴리스 커밋. 사용자에게 push/PR 여부 질문.

- [ ] **Step 1: `origin/main` 을 merge 한다**

```bash
git fetch origin
git rev-parse origin/main
git merge --no-ff --no-edit origin/main
```
`Already up to date.` 면(Task 1 의 merge 뒤 main 이 안 움직였으면) Step 2 를 건너뛰고 기준선은 `.claude/rda/base.json` 그대로다. 동시에 진행 중인 브랜치 둘이 먼저 머지됐을 수 있다 — `feature/handoff-gate-reorder`(`commands/interview.md` 의 Step 2–3 교체 · `framing-requests` proceed 게이트 · `references/proceed-gate.md`)와 `feature/remove-spec-review-hook`. 그러면 `commands/interview.md` · `framing-requests/SKILL.md` · `plugin.json` · `CHANGELOG.md` 에서 충돌이 날 수 있다 — 양쪽 의도를 모두 살려 해소하고, 이 브랜치가 고친 문장(Task 6 · 7)이 살아 있는지 Task 8 Step 4 의 스윕으로 확인한다. 충돌이 나면 해소한다 — `plugin.json` 은 **origin/main 쪽 값**을 받고(버전은 Step 4 에서 정한다), `CHANGELOG.md` 는 origin/main 의 새 절을 모두 받는다(이 브랜치의 절은 아직 없다). 해소 뒤 `git commit --no-edit`.

- [ ] **Step 2: merge 한 `origin/main` 끝에서 기준선을 다시 잡는다 (C6)**

```bash
git worktree add --detach /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/rda-main-base origin/main
```
Run (`run_in_background: true`): `python3 .claude/rda/collect.py collect --root /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/rda-main-base --out .claude/rda/base-main.json`
Expected 마지막 줄의 head 가 Step 1 의 `git rev-parse origin/main` 과 같다.
```bash
git worktree remove /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/rda-main-base
```
(기준선 워크트리는 이 작업 워크트리와 같은 `.claude/worktrees/` 아래에 둔다 — 경로 모양이 달라지면 경로를 재는 테스트가 무관한 RED 를 낸다.) 이후 이 task 의 비교는 `.claude/rda/base-main.json` 과 한다.

- [ ] **Step 3: 자기 적용 스윕을 다시 돈다 (V0 — merge 뒤)**

Run: Task 8 Step 4 의 첫 명령.
Expected: 출력 없음. main 이 가져온 파일이 걸리면 멈추고 보고한다(그 파일은 이 설계가 몰랐던 참조자다).

- [ ] **Step 4: 버전을 정한다 (C2)**

Run: `git show origin/main:plugins/spec-distill/.claude-plugin/plugin.json`
그 `"version"` 의 major 에 1 을 더한 `X.0.0` 이 이번 버전이다(계획 작성 시점 main: `1.1.0` → `2.0.0`). Edit 도구로 `plugins/spec-distill/.claude-plugin/plugin.json` 의 `"version": "<main 값>"` 을 `"version": "X.0.0"` 으로.

- [ ] **Step 5: CHANGELOG 최상단 절을 쓴다 (§4 · C3)**

Edit 도구 — `plugins/spec-distill/CHANGELOG.md` 의 `# Changelog` 다음 빈 줄 뒤, 기존 첫 `## [` 헤딩 앞에 아래 절을 넣는다. 꺾쇠 자리는 오른쪽 출처의 값으로 바꾼다 — 출처에 값이 없으면 그 문장을 지우지 말고 «기록 없음» 이라고 쓴다.

| 자리 | 출처 |
|---|---|
| `X.0.0` | Step 4 |
| `YYYY-MM-DD` | 이 커밋을 만드는 날짜 |
| `<N>` | `.claude/rda/comp.txt` |
| `<기준선 커밋>` | Step 2 의 head 8자(Step 2 를 건너뛰었으면 `base.json` 의 head) |
| `<기준선 실패>` | 기준선 json 의 실패 식별자 목록(compare 의 `사라진 기준선 실패` 가 아닌, 기준선에 있던 것 전부) |
| `<변이 수>` | `.claude/rda/mutations.txt` 의 줄 수 |
| `<e2e>` | `e2e-decision.txt` 가 `미실행` 이면 `미실행`, `실행` 이면 `e2e.txt` 의 다섯 항목 결과 한 줄 |
| `<flaky>` | `.claude/rda/flaky.txt` 가 있으면 그 내용, 없으면 이 불릿 전체를 뺀다 |

```markdown
## [X.0.0] — YYYY-MM-DD

major인 이유: **dispatch 가능한 agent 하나(`spec-distill:depth-auditor`)가 사라지고, 인터뷰의 라운드 형식과 audit §2 형식이 바뀐다.** 인터뷰 종료 직전의 사후 깊이 측정(Step A.7) 전체와, 그 측정이 읽던 라운드 형식(«직전 답에서» 블록 + 질문 둘)을 제거했다. 라운드는 «지금 이해 / 다음 결정 / 질문 하나»로 돈다. 사용자 결정(2026-09-10)의 이유는 셋이다 — 쓰이지 않는 무게(0.57.0 도입 뒤 측정 기록 0건 · 사람 e2e 미실행), 인터뷰가 번거로움, 방향이 틀렸다. 설계: `docs/superpowers/specs/2026-09-10-remove-depth-audit-design.md`.

### Removed

- **사후 깊이 측정 층 전체** — `agents/depth-auditor.md` · `scripts/depth_pairs.py` · `scripts/depth_record.py`, 그 테스트 셋(`test_depth_pairs.py` · `test_depth_record.py` · `test_depth_auditor_frontmatter.sh`)과 fixture 11개(`tests/fixtures/depth-state-*.md`), 측정 원장 디렉토리 `docs/superpowers/interview/depth/`. 함께 사라진 것: `finishing.md` Step A.7 절, 종료 시 사람 라벨 질문(≤4개), proceed 게이트 질문의 «깊이:» 슬롯, audit §2 의 깊이 네 줄.
- **판정자 투입 조건**(누적 5건 · not_dug 30% · 일치 70%) — 닫힘 거부권 에이전트를 언제 들일지 알려 주던 유일한 신호였다(설계 OQ3 로 이월).
- **라운드의 «직전 답에서» 블록과 질문 둘** — 네 줄(함의 · 상충 · 확인한 사실 · 위험) 블록, Q1 되비추기 확인 · Q2 새 결정, Q1 수정 시 재되비추기, Q2 독립성 규칙, 인자 없는 경로의 R1 블록 면제, «되묻기로 바뀌는 조건» 절, `steelman.md` 의 «상충 줄에도 한 줄로 싣는다» 문단.
- **`provisional_on`** — `user_statements` 스키마 필드와 그 규칙. 진행 중 세션에 남은 필드는 읽는 자가 없어 무해하므로 마이그레이션을 두지 않는다.

### Changed

- **라운드 규약** — `## R<n>` 한 라운드 = 지금 이해 / 다음 결정 / 질문 / 답. AskUserQuestion 1회에 질문 1개, 첫 선택지가 추천(`(권장)`). 약한 답(보류 · 한 단어 · 이유 없는 추천 수락 · 근거 없는 단정)에는 이유 · 사례 · 실패 조건 중 하나를 되묻고, 같은 주제의 연속 되묻기는 최대 2회다(그 뒤엔 기록하고 넘어간다 · 차원을 자동으로 닫지 않는다). 한 라운드에 겹치면 되묻기 → 외부 근거 처분 → 새 결정 순. `references/steelman.md` 가 묻는 질문은 그 파일의 규약을 따른다.
- **옮겨 간 규칙 다섯** — 닫힘 근거(«그 차원에 관한 질문에 사용자가 답한 S» — blind-spot-prober 절의 전이 문장도 처분 S 뒤로 맞췄다) · landscape 닫힘 발화(«외부 근거 처분 S», SKILL · `finishing.md` 양쪽) · 재개방 표시 자리(«상충» 줄 → 그 라운드의 «지금 이해». `reopen_log` · audit §1 접미는 그대로) · seed «다시 검증할 것» 문단의 소비 자리(R1 «지금 이해»·질문의 재료 + coverage-mapper 첫 dispatch 입력 — `seed-input.md` · `framing-requests` · seed 템플릿) · C43 경로 표시 자리(«지금 이해»·«질문»).
- **audit 템플릿 §2** — 데이터 줄 하나(질문 라운드 · agent dispatch · coverage-mapper `<k>` · codex 실호출). 게이트가 보는 `coverage-mapper <k>` 는 그대로다.
- **proceed 게이트 질문 텍스트** — «깊이:» 슬롯 제거. `check_brief` advisories 슬롯은 유지.
- **`shared/tests/test_adjudication_wiring.sh` 의 `COMP_BASELINE` 58 → <N>** — `depth_record.py` 가 더했던 컴프리헨션이 파일과 함께 사라졌다(`ast` 실측).
- **락** — `tests/test_stale_terms.sh` V13(식별자 축은 README 포함 · 개념 별칭 축은 README 제외 · 새 라운드 규약의 양성 짝 둘) · V10 부재 목록 20 → 37 · `test_conducting_interview_stage.sh` 의 라운드 규약 · 닫힘 · 재개방 · landscape 발화 · blind-spot 전이 · seed 문단 · C43 경로 표시 락을 재조준 · 신설 · `test_request_framing_command.sh` 의 seed 문단 소비 락 · `test_finishing_block_scope.py` 의 양성 대조를 남는 펜스의 게이트 호출로 · `test_brief_agents.sh` 격리 목록 5 → 4.

### Deprecated

- `spec-distill:depth-auditor` agent · 두 측정 스크립트 · 옛 라운드 형식 · audit §2 깊이 네 줄은 **fallback 없이 즉시 제거**됐다 — CLAUDE.md 메타데이터의 one-minor deprecation window 규정과 충돌한다. 이 충돌을 다음 조건 아래 수용한다: 이 플러그인의 제3자 설치가 현재 없다(사용자 확인, 2026-09-10). **제3자 설치가 생기면 이 근거가 사라지므로, 그 뒤의 제거에는 창을 둔다.**

### Verification

- **회귀 0** — spec-distill 셸 스위트 · `python3 -m unittest discover -s plugins/spec-distill/tests` · `shared/tests` 를 (파일, 실패 식별자) 멀티셋으로 기록해 «완료 − 기준선 = ∅» 를 확인했다. 기준선은 `origin/main` merge 뒤 그 끝 커밋 `<기준선 커밋>` 이고, 기준선에 이미 있던 실패(<기준선 실패>)는 그대로다. task 커밋마다 같은 판정을 거쳤다(착수 전 기준선 대비).
- **완료 증거** — 셸 파일마다 요약 줄(`Total: …`) 또는 기준선과 같은 마지막 출력 줄을 요구했다. 단언 없이 죽은 파일이 `(파일, rc=<N>)` 로 잡히는 것과, 기존 실패 하나를 찍고 중단된 실행이 멀티셋 비교를 통과하지 못하는 것을 합성 양성 대조로 확인했다.
- **변이** — 새로 쓰거나 고친 락마다 통째 삭제 · 문구 반전 · 값 변경 · 위치 변경으로 해당 단언의 RED 를 확인했다(<변이 수>건).
- **flaky** — <flaky>
- **사람 e2e** — <e2e>.
```

- [ ] **Step 6: 최종 판정 (AC8 · AC9 · AC10 · V4)**

Run:
```bash
git diff --stat origin/main -- plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/hooks plugins/spec-distill/skills/reviewing-brief plugins/spec-distill/skills/reviewing-spec plugins/spec-distill/agents/coverage-mapper.md plugins/spec-distill/agents/steelman-builder.md plugins/spec-distill/agents/blind-spot-prober.md docs/superpowers/specs/2026-09-06-interview-depth-redesign-design.md
grep -n '"version"' plugins/spec-distill/.claude-plugin/plugin.json
grep -n -m1 '^## \[' plugins/spec-distill/CHANGELOG.md
bash shared/tests/test_changelog_integrity.sh
```
Expected: 첫 명령 출력 없음(AC8) · 두 버전 값이 같다(AC9) · `test_changelog_integrity.sh` `Fail: 0`.

Run (`run_in_background: true`): `python3 .claude/rda/collect.py collect --root /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+remove-depth-audit --out .claude/rda/final.json`
Run: `python3 .claude/rda/collect.py compare .claude/rda/base-main.json .claude/rda/final.json --deleted plugins/spec-distill/tests/test_depth_auditor_frontmatter.sh --deleted-py test_depth_pairs --deleted-py test_depth_record`
(Step 2 를 건너뛰었으면 `base-main.json` 대신 `base.json`.)
Expected: `판정: 새 실패 0 · 완료 증거 전부 있음 (문제 0건)` (AC10)

- [ ] **Step 7: 커밋한다**

Write 도구로 `WT/.claude/rda/msg-t11.txt`:
```
chore(spec-distill): X.0.0 — depth audit 제거 릴리스(버전 · CHANGELOG)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Um5Znb7UcRUQ4SP3u3TobS
```
(`X.0.0` 을 Step 4 의 값으로.) Run:
```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md
git status --porcelain
git commit -F .claude/rda/msg-t11.txt
git log --oneline e5234326..HEAD
```

- [ ] **Step 8: push · PR 여부를 사용자에게 묻는다**

push 와 PR 생성은 외부로 나가는 행동이라 사용자 승인 뒤에만 한다. 컨트롤러가 브랜치 커밋 목록 · 최종 판정 · 남은 것(설계 OQ1–OQ3)을 보이고 `AskUserQuestion` 으로 «push 후 PR 생성 / 로컬에 둠» 을 묻는다. PR 을 만들면 본문 끝에:
```
🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01Um5Znb7UcRUQ4SP3u3TobS
```
머지는 사용자가 `! gh pr merge <번호> --merge` 로 한다(auto mode 판정기가 모델의 머지를 막는다). 머지 뒤 `gh pr view <번호> --json state` 로 `MERGED` 를 확인한다.

## 설계 대조표

| 설계 항목 | Task |
|---|---|
| G1 · §1 삭제 18 · AC1 | 3 (확인 Step 11), 11 (V4) |
| §1 편집 — finishing A.7 · B-2 · 템플릿 §2 · state-migration · README 108/136 · AC5 · AC6 | 3 |
| §2.1 · §2.2 새 형식과 규칙 · §2.4 지우는 것 · C8 · C9 · AC3 | 4 |
| §2.3 닫힘 · landscape 발화 · 재개방 표시 · 경로 표시 · blind-spot 전이 · AC4 (행 1·2·3·5) | 5 |
| §2.3 seed 문단 · §2.5 seed 템플릿 · AC4 (행 4) | 6 |
| §2.5 SKILL 도입부 | 4 |
| §2.5 README 7·22·36·145 · command 46 · C4 | 7 |
| §3.2 stage 락 — 라운드 규약 · 되묻기 | 4 |
| §3.2 stage 락 — 닫힘 · 재개방 · 발화 · C43 | 5 |
| §3.2 stage 락 — seed 문단(stage · framing 테스트) | 6 |
| §3.2 stage 락 — A.7 · B-2 깊이 · 템플릿 깊이 삭제 | 3 |
| §3.3 finishing_block_scope · brief_agents · COMP_BASELINE · AC7 · C7 | 3 |
| §3.4 V13 · V10 37 · 양성 짝 · AC2 | 8 |
| §4 · C2 · C3 · AC9 | 11 |
| AC8 | 11 (Step 6), 매 task 의 파일 범위 |
| AC10 · C6 · V2 | 3–8 공통 마무리, 11 (merge 뒤 재기준선) |
| V0 자기 적용 스윕 | 1, 8, 11 |
| V1 기준선 · 양성 대조 · 완료 증거 | 1 |
| V3 변이 · C5 | 3, 4, 5, 6, 8 |
| V5 개념 별칭 스윕 | 8 |
| V6 사람 e2e | 2 (결정), 9 (실행), 11 (기록) |
| V7 리뷰 | 10 |
| Deferred — 최종 산문 · 락 정규식 · COMP 실측 · 수집기 · README 에 `깊이 측정` 금지 · e2e 질문 | 4·5 · 4–8 · 3 · 1 · 7 · 2 |
