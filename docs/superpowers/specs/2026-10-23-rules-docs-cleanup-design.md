---
name: rules-docs-cleanup
type: design
created_at: 2026-10-23
source_interview: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R9.md
roadmap: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md
next_phase: superpowers:writing-plans
---

# R9 — 규칙 · 문서 정리 · Design

> 지금 장치와 어긋난 레포 규칙 · 철학 문장을 장치에 맞춰 고치고, 사용자가 정한 대로 모든 `cost_class: high` skill 의 지출 승인을 규모 공시 한 줄로 바꾼다 — 규칙 문면과 그 skill · 스크립트 · 락을 같은 에픽에서 함께 고친다.

## 목차

- [Context / Why](#context--why)
- [Goals](#goals)
- [Non-goals](#non-goals)
- [Anti-goals](#anti-goals)
- [Constraints](#constraints)
- [설계](#설계)
  - [§1 범위](#1-범위)
  - [§2 지출 승인을 규모 공시로 — 규칙 · P22](#2-지출-승인을-규모-공시로--규칙--p22)
  - [§3 지휘자 시작 승인 걷기](#3-지휘자-시작-승인-걷기)
  - [§4 plugin-audit 지출 동의 · artifact-critique 동의 게이트](#4-plugin-audit-지출-동의--artifact-critique-동의-게이트)
  - [§5 흐름 고정 점검 R9 행 다섯](#5-흐름-고정-점검-r9-행-다섯)
  - [§6 지금 장치와 어긋난 규칙 문장](#6-지금-장치와-어긋난-규칙-문장)
  - [§7 지휘자 권장을 옮기는 규칙](#7-지휘자-권장을-옮기는-규칙)
  - [§8 위험에 대한 답](#8-위험에-대한-답)
  - [§9 계획](#9-계획)
- [있는 것 검토](#있는-것-검토)
- [상류 · 하류 연계](#상류--하류-연계)
- [Acceptance Criteria](#acceptance-criteria)
- [Files to Modify](#files-to-modify)
- [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives)
- [결정 기록](#결정-기록)
- [번호 대조](#번호-대조)
- [원칙 · 입력 대조](#원칙--입력-대조)
- [미룸](#미룸)
- [지휘 기록](#지휘-기록)
- [Metadata](#metadata)

## Context / Why

묶음 R9 의 의도는 처음에 「바뀐 장치에 맞춰 레포 규칙 · 철학의 조항 문면을 고친다」였고 범위는 「안 한다 장치 동작 변경」이었다. 2026-10-23 사용자가 두 질문에 답했다.

- 지출 승인 조항의 범위 — 「모든 high skill 을 규모 공시만으로 (권장)」. 열린 질문 OQ35 가 풀렸다. high skill 의 승인 게이트(`AskUserQuestion`)를 걷는 일은 장치 변경이라 옛 범위와 부딪혔다.
- 그 게이트 제거를 받을 곳 — 「R9 가 규칙과 skill 을 함께 (권장)」. 그래서 이 설계와 같은 브랜치의 로드맵 커밋이 R9 범위를 넓히고 경로 예약을 늘린다(생성기 `roadmap_write.py update`, 재분해 이력 2026-10-23).

설계 전에 지휘 세션이 origin/main ad7efbb6 에서 읽기 전용 전수 조사를 했다(기록 `~/.claude/sdd-mirror/epic-decisions/r9/sweep.md`). 이 설계는 그 지도를 따르고, 아래 자리는 작성자가 같은 커밋에서 다시 확인했다.

1. **high skill 은 둘이다.** `cost_class: high` 는 `plugins/plugin-audit/skills/plugin-audit/SKILL.md:8` 과 `plugins/spec-distill/skills/epic-conductor/SKILL.md:7` 뿐이다. `variable` 넷 가운데 지출 승인 게이트를 가진 것은 `plugins/quality-gates/skills/artifact-critique/SKILL.md` E3(:166-192)뿐이다 — 「cost_class=variable(worst-case high)이라 이 upfront 게이트가 지출-전 명시 승인이다」(:191-192).
2. **지휘자 시작 승인.** epic-conductor `### 4. 시작 승인`(:139-178)이 `conductor_ledger.py approval` → rc 가 0 이 아니면 `AskUserQuestion` → `approve` 를 돈다. 「승인 전에는 agent 를 보내지 않는다」(:176), 이름 붙인 예외(:178). 스크립트는 `scale_check`(:132-140) · `_drop_approval`(:627-631, claim · takeover · release 가 부름) · `c_approval`(:682-689) · `c_approve`(:692-698) · 하위 명령 표(:1255-1256) · 사용법(:13). 기계 상태 `conductor_state.py` 의 절 `시작 승인`(:45)이 있고, 모르는 절은 「모르는 절」로 거부한다(:190-191). 빈 선택 절은 머리를 쓰지 않는 길(`OPTIONAL_SECTIONS` :48 · :213-214)이 이미 있다.
3. **plugin-audit 지출 동의.** phase 0 step 3(:83-94)이 (a) 축 고르기 질문과 (b) 규모 공시 뒤 「승인」 · 「중단」 질문을 한다. 동의 기록 `{approved, at, fanout, axes}`(:108)를 `validate-audit-data.py`(:30-35)가 `approved is True` · `at` · `fanout_declared == consent.fanout` 으로 검사한다. Workflow 의 근거 문장은 「command/skill이 Workflow opt-in 요건을 충족(cost_class 게이트 통과 후)」(:238)이다.
4. **규칙 문면.** CLAUDE.md:51 이 「`high`는 지출 전 명시적 `AskUserQuestion` 승인 게이트를 invoke해야 함」과 epic-conductor 예외를 적는다. 철학 P22(:62-64)가 같은 게이트와 죽은 장치 `<Use_When>`(쓰는 곳 0)을 적는다. 락 셋이 이 문장들을 잡는다 — `plugins/quality-gates/tests/test_governance_no_capability_caps.sh:127-140`(AC8a) · `plugins/spec-distill/tests/test_epic_conductor_skill.sh:215-223` · 같은 파일 :32-44(4절 순서).
5. **어긋난 문장.** CLAUDE.md 의 Law 1 필수 섹션 게이트(:24 — 설계문서 필수 섹션을 기계로 막는 검사는 없다, spec-distill README:72), `gh` 를 레포마다 정할 값으로 적음(:31 — R8 U1 로 필수 의존), 의존 문장(:50 — `dependencies.md` · `check_deps.py` 없음), state 두 종류(:70 — 실제 넷), kill switch 가 훅만(:71 — 진입 skill 도 끈다), Hooks Installed(:72 — 유일한 훅의 project-init README 에 절이 없음), degrade 만(:73 — 필수 의존은 멈춤), plugin-structure 먼저(:82), persona 편집(:97), 목차 규칙(:103 — 300줄 넘는 docs 의 절반이 목차 없음, 집행 없음), 「자동 검증」(:18 — 훅은 막지 않는다), 역할 프롬프트 공식(:48), 철학 P12 · P13 · P22 의 낡은 코드 가리킴, `docs/plugin-authoring.md:29`(qg 에 없는 `commands/` · `hooks/`) · :46(짧은 이름 `/plugin-audit`), `shared/README.md:36`(「15곳」 — 지금 SKILL.md 10곳).
6. **흐름 고정 점검 R9 행 다섯**(flexibility-audit.md :79-83). 「끝에 할 일 하나」는 정본 `shared/style/plain-language.md:5` 와 바이트 사본 10곳, 그리고 skill 자기 자리 여섯이다.
7. **옮김 규칙.** R13 · R8 설계문서 `## 지휘 기록`(R13 :415, R8 :479)이 같은 어긋남을 두 번 적었다 — skill 이 문장으로 낸 권장을 지휘자가 라벨 꼬리 「(권장)」 으로 옮겼고, 지휘자가 만든 질문의 자기 권장을 라벨 안에 넣었다. 둘 다 「R9 입력 — 지휘자가 만든 권장을 옮기는 규칙」이다.

## Goals

- G1 `cost_class: high` skill 은 크게 쓰기 전에 규모를 한 줄로 알리고 진행한다. 어느 skill 도 지출을 이유로 묻지 않는다. 대상 · 모드 · 취소처럼 일의 범위를 고르는 질문과 사용자가 상한을 여는 질문은 남는다.
- G2 CLAUDE.md · 철학 문서의 규칙 문장이 지금 장치가 하는 일과 같다. 기계로 막지 않는 것을 막는다고 쓰지 않는다.
- G3 흐름 고정 점검 R9 행 다섯이 「기본은 X, 일의 모양이 다르면 모델이 판단하고 이유를 적는다」 꼴이 된다(사용자 결정 둘 포함).
- G4 지휘자의 권장은 라벨 안으로 들어가지 않고, skill 의 문장 권장은 문장으로 옮겨진다. 옮김 대조 agent 가 그 둘을 어긋남으로 잡는다.
- G5 옛 기계 상태(`## 시작 승인` 절이 있는 `machine.md`)와 옛 감사 데이터(`approved: true`)는 계속 읽힌다.
- G6 R14 와 병렬로 가도 회귀 · 통합 문제가 없다 — 겹치는 파일의 주인과 머지 순서가 정해져 있다.

## Non-goals

- 원칙 옮기기 · 낡은 개념 삭제 · 플러그인 README · CHANGELOG 의 낡은 개념 정리(R11, 머지됨).
- 위 §1 표에 적지 않은 장치 동작 변경 · 새 기능. 특히 설계문서 필수 섹션을 기계로 막는 새 게이트는 만들지 않는다 — 문장을 사실대로 고칠 뿐이다(§6).
- R14 의 장치 결함들(R8 미룸 행). R5 설계 :642 · R2a 설계 :496 의 SKILL 문장 둘은 사용자 되비춤 답에 따라 R14 몫이다(`## 상류 · 하류 연계`).
- 에픽 단위 병렬 권장(지휘 절차 걸음 3) — 지휘자 수리 몫이다(사용자 원문 2026-10-23).
- superpowers 의 파일 · 동작(C25 · C35 · D26). Workflow 와 deep-research 의 명시 요청 규칙(CLAUDE.md:91)은 그대로다.
- reviewer persona 의 규칙을 약하게 하는 편집. 이 설계가 고치는 persona 는 옮김 대조 agent 하나이고 조이는 쪽이다(§7).

## Anti-goals

- 새 상태 절 · 새 상태 파일 · 새 하위 명령. 승인 기록을 「공시 기록」으로 이름만 바꿔 다시 쓰는 장치도 두지 않는다 — 공시는 화면의 한 줄이고 기록할 소비자가 없다.
- 규칙 문장에 출처 · 날짜 · 정당화를 넣기(Self-narrating artifact). 근거는 이 설계 · CHANGELOG · PR 에 둔다.
- 대상 목록을 손으로 적는 락. high skill 목록 · 쉬운 말 블록 사본 목록은 frontmatter · 글롭에서 도출한다.

## Constraints

- C5 — 비용을 이유로 품질을 제약하는 장치는 제거하고, 크게 쓰기 전에는 규모만 알린다.
- C25 · C35 · D26 — 외부 플러그인은 건드리지 않는다.
- C32 — 원래 있는 것을 다시 만들지 않는다(`## 있는 것 검토`).
- D18 — 비용으로만 작동하는 장치는 제거, 상한은 공시하고 사용자가 여는 꼴로.
- D21 — §8 이 원본 brief 의 위험 가운데 이 에픽에 닿는 것에 답한다.
- CLAUDE.md — 기본값과 판단 · 레포 전용 값 금지 · 상류 · 하류 연계 · 진입점에서 따라 내려가기 · 있는 것 먼저. persona 편집은 보안-민감이다. 호출 이름(slash · skill 이름)은 바꾸지 않는다.
- 락 원칙 — 문면을 바꾸는 락마다 양의 짝을 두고, 변이(삭제 · 추가 · 반전 · 형태 변경)로 이빨을 확인한다. 변이 전에 커밋한다. 셸은 macOS bash 3.2.
- 경로 예약 — 이 설계와 함께 로드맵 R9 블록의 경로 예약을 넓혔다. 예약 밖으로 고치는 파일은 `## Files to Modify` 에 «예약 밖» 으로 적는다.
- 병렬 — R14 와 병렬로 간다. 겹치는 파일은 R14 가 먼저 머지하고, R9 의 각 PR 은 기본 브랜치를 합친 뒤 스위트 대조와 통합 리뷰를 다시 돈다(`## 상류 · 하류 연계`).

## 설계

### §1 범위

| # | 항목 | 출처 | 자리 |
|---|---|---|---|
| 1 | CLAUDE.md:51 · 철학 P22 — high 는 규모 공시만 | 사용자 결정 U1 · OQ35 | §2 |
| 2 | epic-conductor 시작 승인 · `conductor_ledger.py` · `conductor_state.py` | U1 · U2 | §3 |
| 3 | plugin-audit 지출 동의 · 동의 기록 · Workflow 근거 문장 | U1 · U2 | §4 |
| 4 | artifact-critique E3 의 지출 부분 | U1 · U2 · RC64 | §4 |
| 5 | 흐름 고정 점검 R9 행 다섯 | flexibility-audit.md :79-83 · 사용자 결정 | §5 |
| 6 | 지금 장치와 어긋난 규칙 문장 | sweep §B · R8 :453 · R7 :235 · R11 :108 · :237 · R5 :630 | §6 |
| 7 | 지휘자 권장을 옮기는 규칙 | R13 :415 · R8 :479 지휘 기록 | §7 |
| 8 | N13 공유 문체 「이상 없음」 | R2 설계 :221 · :241 | §5 행 1 — 이미 있음, 락만 더함 |
| 9 | 인터뷰 진입 이름 바꾸기가 규칙 문서에 닿는가 | R10 설계 :214 | 이미 끝남 — CLAUDE.md · 철학 · 가이드에 옛 이름 0, 호출 표면 락이 지킨다 |
| 10 | RC14 Unbounded autonomy | 묶음 §5 | §8 — 이 에픽이 고치는 장치의 루프 상한이 남는지 확인 |

### §2 지출 승인을 규모 공시로 — 규칙 · P22

**CLAUDE.md:51** 을 아래 뜻으로 바꾼다(글자는 계획이 다듬는다).

> **모든 skill에 `cost_class` 선언** (`low`|`medium`|`high`|`variable`). `high` 는 크게 쓰기 전에 규모(띄울 agent 수 · 라운드 · 상한이 없으면 없다는 사실)를 한 줄로 알리고 진행한다 — 지출을 이유로 묻지 않는다. 어느 클래스의 skill 도 지출 승인을 묻지 않는다. 상한 · 압축은 공시하고, 사용자가 상한을 여는 질문은 지출 승인이 아니다. 대상 · 모드 · 취소처럼 일의 범위를 고르는 질문도 지출 승인이 아니라 그대로 묻는다. 클래스보다 비싸게 도는 skill 은 버그다.

- 규칙의 공시 의무는 `cost_class: high` 에 걸린다. `variable` 은 공시 의무 대신 「지출 승인을 묻지 않는다」만 받는다. 상한 · 압축 문장은 D18 을 그대로 옮긴 것이다. pm-interview 의 조사 상한 연장 질문과 리뷰 엔진의 추가 라운드 질문은 사용자가 상한을 여는 질문이라 이 규칙과 맞는다(지휘자 판단(사용자 결정 아님)).
- epic-conductor 의 「이름 붙인 예외」 문장은 지운다. 물을 게이트가 없어 예외가 할 일이 없다.
- 굵은 머리 「모든 skill에 `cost_class` 선언」은 그대로 둔다 — `plugins/plugin-audit/tests/test_check_shape_completeness.py:15` 의 앵커다.
- CLAUDE.md:91(Subagent spray · Workflow 명시 요청)은 그대로다. 규모 공시 줄이 곧 fan-out 선언이다.

**철학 P22** 를 바꾼다.

- 규칙 문장은 위와 같은 뜻이다. `cost_class: high` 리터럴은 남긴다.
- `<Use_When>` 에 fan-out N 을 적으라는 말을 지운다 — 쓰는 skill 이 0 이다. 대신 「fan-out 규모는 띄우기 전 공시 줄로 알린다」를 적는다.
- 코드 가리킴을 `quality-pipeline`(variable) 에서 규모 공시를 하는 high skill 의 자리로 바꾼다 — epic-conductor `### 4. 규모 공시` · plugin-audit phase 0 step 3. 가리키는 이름은 `shared/tests/test_charter_citations.sh` 가 실재를 잰다.
- AP9(Subagent spray, :108)는 그대로다.

**락.**

- qg `test_governance_no_capability_caps.sh` AC8a 는 옛 게이트 문장이 남아 있음을 잡던 락이다. 아래 넷으로 바꾼다.
  - CLAUDE.md 의 cost 줄에 새 공시 문장이 있다(양).
  - 옛 문장 「지출 전 명시적 `AskUserQuestion` 승인 게이트를 invoke해야 함」은 없다(음).
  - P22 절 안에 `cost_class: high` 와 공시 문장 · 범위 질문 문장이 있다.
  - P22 절 안에 「승인 게이트가 필수」가 없다.
  
  이 락의 원래 이유(「P17 사용자 주권 컨트롤 소실」)는 범위 질문 문장의 양성 단언으로 옮긴다 — 사용자 결정권이 남는 자리는 범위 고르기다.
- spec-distill `test_epic_conductor_skill.sh:215-223` 의 예외 락은 반대로 선다. CLAUDE.md 와 모든 SKILL.md 에 「이름 붙인 예외」가 0 이고(음), CLAUDE.md cost 줄에 새 문장이 있다(양).
- 새 공유 락 `shared/tests/test_cost_disclosure.sh` 를 둔다. 두 갈래로 잠근다(지휘자 판단(사용자 결정 아님)).
  - (가) 코퍼스 전체 음성 락. 대상은 `plugins/*/skills/*/SKILL.md` 글롭 전부이고 손으로 적은 목록이 없다. 도출한 수가 `find` 로 센 수와 같은지 본다(양성 대조). 어느 파일에도 지출 승인 문구 — 「지출 동의」 · 「지출 전 명시」 · 「지출-전 명시 승인」 · 「승인 전에는 agent 를 보내지 않는다」 · 「이름 붙인 예외」 — 가 없다. 낱말 목록의 마지막 모양은 계획이 정하되, 상한을 여는 질문(「더 연다」 · 「연장」)은 걸리지 않게 한다(양성 대조 — pm-interview · 리뷰 엔진 skill 이 GREEN).
  - (나) 게이트가 있던 세 skill(epic-conductor · plugin-audit · artifact-critique)마다 공시 줄 문장(계획이 정하는 본문 고유 문장 — 머리로 만족되지 않게)이 있다는 양성 단언.

### §3 지휘자 시작 승인 걷기

**skill.** `### 4. 시작 승인` 을 `### 4. 규모 공시` 로 바꾼다.

- 남는 것: `control_plane.py show` 펜스, 규모 줄 만들기(꼴 그대로 — 같은 상태면 같은 줄).
- 바뀌는 것: 「규모 줄을 보이고 5 로 간다 — 지출을 이유로 묻지 않는다. 그 뒤의 dispatch 도 띄우기 전에 규모만 알리고 간다」.
- 지우는 것: `approval` 펜스 · 갈래 셋(rc 0 · 옛 PR 캐시 줄 · 그 밖), `approve` 펜스, 「멈춤이면 표지를 풀고 멈춘다」 펜스, 「승인 전에는 agent 를 보내지 않는다」, 이름 붙인 예외 문단.
- :29 의 「시작 승인」 낱말과 :124 의 괄호(「새로 잡아야 이 세션의 옛 시작 승인이 지워진다」)도 고친다. :124 의 release → claim 걸음 자체는 남긴다 — `conducting.md`(R14 예약)가 같은 걸음을 적고 락이 잡는다. 이유 괄호만 뺀다. `references/conducting.md:13` 의 같은 괄호 「(새로 잡아야 그 세션의 옛 시작 승인이 지워진다)」도 계획 2 가 예약 밖 편집으로 뺀다. R14 가 먼저 머지하고 그 문장은 건드리지 않는다(지휘자 판단(사용자 결정 아님)).

**`conductor_ledger.py`.**

- 지운다: `approval` · `approve` 하위 명령, `scale_check`, `c_approval`, `c_approve`, 사용법 줄 :13.
- `_drop_approval` 과 그 호출 셋도 지운다 — 아래 상태 쪽 변경으로 할 일이 없다.
- 지운 하위 명령을 부르면 argparse 의 모르는 하위 명령 rc 2 다. 락은 rc 와 사유 글을 함께 본다.

**`conductor_state.py` — 고른 길: 읽되 버리는 절.**

- `시작 승인` 을 `SECTIONS` 에 남겨 옛 파일의 머리가 「모르는 절」 이 되지 않게 한다.
- 새 튜플 `RETIRED_SECTIONS = ("시작 승인",)` 을 두고, `parse_machine` 은 그 절의 줄을 이미 있는 `skip` 길처럼 검사 없이 버린다.
- `render_machine` 은 그 절을 쓰지 않는다. 그래서 옛 파일은 다음 저장 때 그 절이 사라지고, 새 파일에는 처음부터 없다.
- 이 판보다 옛 플러그인이 새 파일을 읽어도 된다. 빠진 절은 `empty()` 가 빈 목록으로 채운다(지금도 그렇다).
- 모듈 docstring :6 에서 「시작 승인」을 뺀다.

  더 작은 길로 「절을 남기고 쓰기만 멈춤」(`OPTIONAL_SECTIONS` 에 더하기)도 봤다. 그 길은 옛 행이 있으면 저장할 때마다 다시 써서 읽는 쪽 없는 행이 파일에 남는다. 고른 길은 같은 두 줄 크기에 옛 행까지 걷는다(Rejected Alternatives).

**README · CHANGELOG(spec-distill).**

- :17 · :120 · :144 · :159 의 시작 승인 · 예외 문장을 규모 공시로 고친다.
- CHANGELOG `Removed` 에 `approval` · `approve` · 이름 붙인 예외를 적는다. 사용자가 명시 결정한 재건이라 deprecation 창 없이 지운다(CLAUDE.md CHANGELOG 규칙).

**락.**

- `test_epic_conductor_skill.sh`:
  - 4절 단언(:32-44)을 「규모 줄 → 5 로」 순서로 바꾼다. 4절에 `approval` · `approve` · `AskUserQuestion` · `release` 펜스가 없다는 음성 단언을 두고, 양성 짝은 규모 줄 문장과 「지출을 이유로 묻지 않는다」다.
  - 세션 펜스 수 단언(:97 「5개 이상(claim · takeover · approval · approve · release)」)은 남는 펜스 수로 다시 센다.
  - 4절의 옛 PR 캐시 갈래 락은 4절에 그 갈래가 없어지므로 4절 쪽만 걷는다. 3절의 reset 갈래 락(:133-176)은 그대로다.
- `test_conductor_ledger.py` 의 승인 클래스(:135-205 · :1142-1181)는 걷는다. 대신 둘을 둔다 — 지운 하위 명령이 rc 2 와 모르는 하위 명령 사유를 낸다, claim · takeover · release 가 그대로 돈다.
- `test_conductor_state.py` 에 둘을 더한다.
  - 옛 꼴(`## 시작 승인` 과 행 하나)을 읽어 오류가 없고 그 절이 빈다. 다시 저장하면 그 머리가 없다.
  - 그 절이 없는 새 꼴을 읽는다.
- `test_conductor_e2e.sh` 의 2 단계(:42-47)와 :114 는 「표지 · 규모 공시」로 바꾼다. 「기계 상태를 잃으면 시작 승인을 다시 묻는다」 단언은 걷는다.

### §4 plugin-audit 지출 동의 · artifact-critique 동의 게이트

**plugin-audit step 3.**

- 이름을 「범위 고르기 · 규모 공시」로 바꾼다. (a) 축 고르기 질문은 범위 고르기라 남는다.
- (a) 의 첫 질문에 「중단」 선택지를 더한다 — 「여섯 축 전부 (권장)」 · 「축 골라서」 · 「중단」. 지휘자 판단(사용자 결정 아님): (b) 의 「승인」 · 「중단」 질문을 지우면 「여섯 축 전부」를 고르는 사용자에게 멈출 선택지가 없어진다. 범위 질문은 남긴다는 사용자 결정(U1 의 범위)을 지키면서 멈춤 길을 그 질문에 둔다.
- 규모는 고르기 전에 보인다. 첫 질문의 선택지 설명에 규모를 싣는다 — 「여섯 축 전부」는 감사자 6 · 반박 최대 6 · codex 감사 6회(설치돼 있으면)와 그 반박 1 · 심층검증은 반박을 통과한 심각 · 중요 지적마다 2회(상한 없음), 「축 골라서」는 축마다 감사자 1 · 반박 최대 1 · codex 감사 1회 꼴, 「중단」은 아무것도 띄우지 않고 실행 폴더도 만들지 않는다.
- (b) 는 질문이 아니라 공시 한 줄이다. 고른 축 수 k 로 지금 질문 본문의 내용을 그대로 싣는다 — 감사자 k · 반박 최대 k · codex 감사 k회와 반박 1 · 심층검증 상한 없음, 축을 뺐으면 「검증 안 됨」 줄, 보안 축을 뺐으면 맨 앞 경고 줄. 「승인」 · 「중단」 질문은 지운다. 고른 뒤 멈추고 싶은 사용자는 끼어들기나 kill switch 로 멈춘다.
- step 4 의 「승인 직후」는 「공시 직후」로 바꾼다. frontmatter description :7 의 「지출 동의 게이트」도 바꾼다.

**동의 기록 — 고른 길: `approved` 를 요구하지 않는다.**

- skill 은 `consent.json` 에 `{at, fanout, axes}` 를 쓴다 — `at` 은 공시한 때다. 파일 · 키 이름 `consent` 는 그대로 둔다. 이 기록은 사용자가 고른 축(a)과 공시한 규모를 담고, 이름이 바뀌면 옛 실행 폴더의 데이터가 갈라진다.
- `validate-audit-data.py` 는 `approved` 가 없어도 통과시킨다. 있는데 `True` 가 아니면 오류다 — 거절을 적은 기록이 지나가지 않게.
- `at` 필수와 `fanout_declared == consent.fanout` 일치는 그대로다. 이것이 「공시한 규모 = 실행한 규모」 를 잰다.
- 옛 데이터 · 픽스처(`approved: true`)는 고치지 않아도 계속 통과한다.

**Workflow 근거(:238)** 를 바꾼다 — 「사용자가 `/plugin-audit:plugin-audit` 를 부른 것이 이 Workflow 의 명시 요청이다. 모델은 이 skill 을 부르지 않는다(`disable-model-invocation: true`)」. CLAUDE.md:91 의 규칙은 그대로이고, 근거만 지운 게이트에서 사용자의 호출로 옮긴다.

**함께 고치는 곳.** `prepare-run-dir.py` docstring :2, `audit-workflow.js` 의 주석 :31 · :691(「consent gate」 → 범위 고르기), README :19 · :23-24 · :93, `tests/README.md:14`, CHANGELOG(:153 은 옛 판 기록이라 두고 새 판 항목을 쓴다).

**plugin-audit 락.**

- `test_skill_orchestration.py` — :15 의 `AskUserQuestion` 은 축 고르기 질문으로 남는다. :85 · :92 · :122 의 앵커를 「범위 고르기 · 규모 공시」로 바꾼다. 순서는 축 질문 → 공시 줄 → `prepare-run-dir.py`. 첫 축 질문에 「중단」 선택지와 선택지 설명의 규모 문장이 있다는 양성 단언, 「중단」이면 `prepare-run-dir.py` 앞에서 끝난다는 단언, step 3 (b) 에 「승인」 선택지가 없다는 음성 단언과 공시 문장의 양성 짝을 둔다. 첫 질문의 「중단」을 지우는 변이에 RED 다.
- `test_validate_audit_data.py` — `approved` 없는 동의는 통과, `approved: false` 는 오류, 옛 픽스처는 통과. 셋 다 변이로 확인한다.

**artifact-critique E3.**

- 머리를 「범위 고르기 · 규모 공시」로 바꾼다. 두 질문(대상 · 모드 · 상한 / 비평자 수)과 선택지(실행 · 대상 변경 · 모드 바꾸기 · 취소, 비평자 수)는 그대로다 — 범위 고르기다.
- 지우는 것: 「cost_class=variable(worst-case high)이라 이 upfront 게이트가 지출-전 명시 승인이다」. 대신 「이 질문은 범위를 고르는 질문이다 — 라운드마다 띄울 수와 상한은 본문에 공시한다」를 쓴다.
- 「동의 범위 = 실행 범위; consent-integrity」는 「고지 범위 = 실행 범위; disclosure-integrity」로 바꾼다.
- `test_critiquing_artifacts_skill.sh:43-67` 의 본문 고유 앵커를 새 낱말로 옮긴다. 옛 낱말 · 지출 승인 문장이 없다는 음성 단언을 둔다.
- qg README :28-32 · :210-211 은 「fan-out 동의 게이트는 없다 — 공시 두 줄」을 이미 말한다. P22 이름만 새 문면에 맞춘다.

### §5 흐름 고정 점검 R9 행 다섯

**행 1 — 「끝에 할 일 하나」(사용자 결정).** 정본 `shared/style/plain-language.md:5` 를 바꾼다.

> 순서: 첫 줄에 지금 상태(무엇을 했고 어디까지 왔나) 한 문장, 가운데에 이유·근거, 맨 끝에 사용자가 할 일. 할 일은 기본 하나다 — 여럿이거나 함께(병렬로) 할 수 있으면 그렇다고 밝히고 함께 쓴다. 할 일이 없으면 없다고 쓴다. 커밋·PR 본문에는 이 순서를 적용하지 않는다.

- 사본 10곳은 정본과 바이트 그대로 맞춘다. 이미 있는 `shared/tests/test_plain_language_block.sh` + `plain_language_block.py` 가 대상을 글롭에서 도출해 같음을 잰다.
- 그 락에 정본 단언 둘을 더한다 — 새 문장(양), 옛 「맨 끝에 사용자가 할 일 하나.」(음).
- skill 자기 자리 여섯은 「하나만」을 강제하는 곳만 고친다.
  - 고침: quality-pipeline 완료 보고 「end with exactly one next action」(:1498) · artifact-critique 최종 보고(:362) · plugin-audit 종료 보고(:300). 셋 다 「기본 하나, 여럿이거나 병렬이면 밝힌다」로.
  - 둠: roadmap-status(:77)는 규칙으로 할 일 하나를 고르는 자리다. project-init 보고(:320)는 예시 하나다. epic-conductor(:225)는 순서를 가리킬 뿐이다. 기본 하나와 맞다.
  - 테스트 `test_plain_qg_templates.sh:89` · `:156` · `test_plain_audit_text.py:62` 를 새 문장에 맞춘다.
- **N13(R2 넘김).** 「없음」 · 「확인 못 함」 구별은 이미 정본 :8 에 있다(「확인해서 남은 것도 경고도 없으면 「이상 없음」 한 줄로 쓴다. 확인하지 못한 것·빠진 검사·셀 수 없는 것은 따로 한 줄씩 쓴다 — 없는 것과 확인 못 한 것은 다르다」). 락이 없어서 같은 락에 양성 단언 하나를 더한다.

**행 2 — Law 1 중간 단계(사용자 결정, 헌법 변경).** CLAUDE.md Law 1(:24)과 철학 P12(:43)에 둔다.

> 기본은 설계 → 계획 → 구현이다. 중간 크기 일은 이유를 밝히고 가벼운 꼴(PR 본문의 계획 · 짧은 brief)을 고를 수 있다. 가벼운 꼴도 필수 섹션이 다루는 것을 짧게 덮고, 다루지 않는 섹션은 「해당 없음 — 이유」로 적는다.

- 가벼운 꼴도 필수 섹션을 짧게 덮는 것은 사용자 결정이다(U5 「짧게 덮는다 (권장)」).
- trivia escape 문장(「한 문장으로 설명 가능한 trivia diff … 파일 수와 무관하게」)은 그대로다. qg AC8c(P12 절 single-file 부재)도 그대로 GREEN 이다.
- 「중간 크기」 판정은 trivia 판정처럼 부르는 skill 의 몫이다.
- 기존 skill(request-framing 의 다음 단계 대안 · 지휘자의 흐름 고르기)은 이미 모델이 고른 대안을 이유와 함께 허용한다. 계획 첫 과제가 중간 단계를 막는 장치 문장이 없는지 다시 본다.
- 락: qg `test_governance_no_capability_caps.sh` 에 Law 1 · P12 의 중간 단계 문장(양)과 trivia escape 문장(양)을 더한다.

**행 3 — persona 편집.**

- CLAUDE.md:97 · 철학 P10(:35)을 「버그가 리뷰를 탈출하면 기본 해결책은 잡았어야 할 reviewer persona 파일을 편집하는 것이다 — 코드만 패치하지 않는다. 그 버그를 더 잘 잡는 자리가 락 · 스크립트 · skill 이면 그것을 고치고 이유를 적는다. 그 commit 이 compounding 이벤트다(Law 3)」로 바꾼다.
- 점검 문서 행의 「메모리」는 뺀다 — Law 3(CLAUDE.md:28 「교훈은 메모리가 아니라 …」)와 C44 에 어긋난다(지휘자 판단).
- 같은 뜻의 자리 qg README:13 · plugin-audit README:77 · plugin-audit SKILL.md:302 를 맞춘다. persona 파일 자체는 고치지 않는다.
- 락: 같은 governance 테스트에 새 문장(양)과, 그 문장에 「메모리」가 없다는 음성 단언을 둔다.

**행 4 — 특정 skill 강제.**

- CLAUDE.md:82 를 「새 플러그인을 설계할 때 기본은 `plugin-dev:plugin-structure` 로 컴포넌트 타입 · `plugin.json` 스키마를 실재하는 surface 위에서 확정하는 것이다 — 다른 길이 맞으면 이유를 적는다」로 바꾼다.
- `docs/plugin-authoring.md:42-48` 의 「해당 단계에 진입할 때만 로드 — 선행 일괄 로드는 progressive disclosure 위반」 · 「이 단계에서 필요한 유일한 것」을 기본 경로 문장으로 바꾼다.
- :46 의 `/plugin-audit` 를 완전명 `/plugin-audit:plugin-audit` 로 바꾼다.

**행 5 — 브랜치 규칙(`docs/git-workflow/branch-strategy.md`).**

- 접두 — 사용자 결정 U6 「docs/ · chore/ 를 더한다」. :12 의 정규식이 `^(feature|fix|docs|chore)/[a-z0-9][a-z0-9.-]*$` 가 된다. 문면과 project-init 템플릿은 서로 맞게 둔다 — 템플릿은 이미 `{{BRANCH_PREFIXES}}` · 추가 접두 선택지를 주므로 고치지 않고, 이 레포 문서의 문면을 템플릿 꼴에 맞춘다. `test_branch_prefix_templates.py` 는 그대로 GREEN 이어야 한다.
- **훅 동작이 바뀐다.** project-init 훅은 기본 브랜치에 커밋된 이 파일의 정규식을 읽는다(`post-tool-use.py:47` · :239). 그래서 이 레포에서 `docs/<이름>` · `chore/<이름>` 브랜치가 경고 없이 통과하고, 고침 안내의 허용 접두가 넷이 된다(`derive_prefixes` 가 정규식에서 도출 — 하드코딩 없음). 다른 레포에는 영향이 없다. 그 레포는 자기 파일을 읽고, project-init 템플릿은 이미 접두 선택지를 준다(`{{BRANCH_PREFIXES}}`).
- 문면(:6 · :21-22 · :32-38 · :57-61)은 project-init 템플릿 `templates/github-flow/branch-strategy.md` 의 지금 문면을 따른다.
  - 「모든 작업은 단명 브랜치(접두는 아래)에서」.
  - 접두 표에 `docs/<이름>`(문서만) · `chore/<이름>`(설정 · 잡일).
  - worktree 절을 더한다.
  - 「변경 작업(파일 편집 · 커밋)을 시작하기 전 현재 브랜치 확인 — 읽기만 하는 작업에는 확인하지 않는다」.
  - 「브랜치 이름은 위 접두 중 하나로 시작」.
- rebase 금지 원문은 그대로다(`plugins/project-init/tests/test_branch_strategy_rebase_clause.sh:39-45` 가 사용자 선호로 지킨다).
- CLAUDE.md:14 를 「`main`에서 `feature/*` · `fix/*`(문서만이면 `docs/*`, 설정 · 잡일이면 `chore/*`)」로 바꾼다.
- 락: `test_branch_strategy_rebase_clause.sh` 에 단언을 더한다 — 이 레포 문서의 정규식을 훅의 읽기 함수로 읽어 `docs/x` · `chore/x` · `feature/x` 통과, `misc/x` 거부, `derive_prefixes` 가 넷. 변이: `docs` 를 지우면 RED.

### §6 지금 장치와 어긋난 규칙 문장

문장마다 지금 장치가 하는 일을 쓴다. 기계가 막지 않는 것은 막는다고 쓰지 않는다.

| 자리 | 지금 | 고친 뜻 | 락 |
|---|---|---|---|
| CLAUDE.md:24 · 철학 :11 Law 1 | 필수 섹션 구조 게이트가 있다고 읽힌다 | 요구는 그대로 둔다(거절 메커니즘 필수). 지금 무엇이 막는지를 쓴다 — 인터뷰 brief 는 `check_brief.py` 가 구조로 막는다. 설계문서의 필수 섹션은 기계 게이트가 없고 설계문서 리뷰(doc-critic)와 사용자 승인 게이트가 본다(빈틈을 밝힘). spec-distill README:72 와 같은 사실 | governance 테스트에 문장 양성 |
| CLAUDE.md:31 | `gh` 를 레포마다 정할 값으로 적음 | `gh` 를 목록에서 뺀다 — 필수 의존이다(R8 U1, `dependencies.md` 강도 멈춤) | — |
| CLAUDE.md:50 | README prerequisites 만 | 「플러그인이 기대는 도구 · 다른 플러그인은 `dependencies.md` 표(이름 · 최소 판 · 강도 · 없을 때)에 적고 판은 `check_deps.py measure` 가 잰다(개발 · 검증할 때 깔려 있던 판). dispatch 하는 다른 플러그인은 README prerequisites 에도」. 굵은 머리 「최소 버전이 선언된 의존성」 유지(shape 앵커 :16) | shape 테스트 GREEN |
| CLAUDE.md:70 | 세션 · 문서 원장 둘 | 수명 넷 — 세션 단위(성공 시 지움, 실패 시 남김, qg 는 다음 시작 때 지우고 TTL GC) · 문서 단위 리뷰 원장(문서가 사라질 때) · 로드맵 단위 지휘 기계 상태(`machine.md`) · 실행 단위 산출(plugin-audit 실행 폴더, 지우지 않음). 상태 루트는 메인 레포 쪽이고 처음 만들 때 자기 `.gitignore` 를 둔다. 상태 폴더 쓰기는 링크를 따라가지 않는다(`nofollow_write`). 「JSON 이 아니라 마크다운」 · 「Secret 기록 금지」 유지 | — |
| CLAUDE.md:71 | 훅만 | 굵은 머리 「모든 훅에 kill switch」 유지(shape 앵커 :15) — 「진입 skill 도 같다」를 더한다. `DEVBREW_<PLUGIN>_DISABLE=1` 은 그 플러그인의 훅과 진입 skill 을 끈다(진입 사전 검사). `DEVBREW_SKIP_HOOKS=<plugin>:<이름>` 은 이름 붙은 한 곳만 끈다 — 훅이나 훅이 아닌 이름 붙은 자리(예: `spec-distill:review-entry` · `quality-gates:qg-gc`)이고 진입 skill 자체는 끄지 않는다 | shape 테스트 GREEN |
| CLAUDE.md:72 | Hooks Installed 규칙 — 유일한 훅의 README 에 절 없음 | 규칙은 그대로, `plugins/project-init/README.md` 에 「Hooks Installed」 절(PostToolUse 하나 · 왜 skill 이 아닌가 한 줄)을 더한다 | — |
| CLAUDE.md:73 | optional 만 | 「optional 은 downgrade 하고 알린다. 필수 의존(`dependencies.md` 강도 멈춤)은 이유와 설치 방법을 보이고 멈춘다. 훅은 사람에게 말할 자리가 없어 바닥 미만이면 건너뛰고 그 사실을 README Prerequisites 가 공시한다」 | — |
| CLAUDE.md:103 | 300줄 넘으면 목차 필수 — 집행 없음 | 「기본은 목차를 둔다 — 앵커로 인용되는 오래 사는 문서(가이드 · 철학 · 설계문서)는 둔다. 한 번 쓰고 닫는 계획 · 기록은 모델이 판단한다」. R5 설계 :630 의 「계획 목차 없음 수용」과 맞다 | — |
| CLAUDE.md:18 | 「자동 검증」 | 「project-init 훅이 브랜치 이름 · 커밋 꼴을 확인해 알린다(막지 않는다)」 | — |
| CLAUDE.md:48 | 역할 프롬프트를 영어 공식으로 시작 | 지금 agent 들이 실제로 하는 대로 쓴다 — 「역할 프롬프트는 첫머리에 맡는 일을 밝힌다. 맡지 않는 일(쓰기 · 고치기 등)은 `tools:` allowlist 가 막고, 프롬프트가 밝힐 때는 같은 첫머리에 둔다. 특정 영어 공식은 강제하지 않는다」. 계획 첫 과제가 agent 마다 첫머리의 역할 문장을 다시 확인해 문장이 그 사실과 맞는지 본다. agent 파일은 하나도 고치지 않는다(U7) | AC8 |
| 철학 P12 :44 | `## 진입 단계` 3 (trivia escape) | `plugins/spec-distill/references/trivia-escape.md` · CLAUDE.md Law 1 | citations GREEN |
| 철학 P13 :47-48 | hook=집행 레이어 · `plugins/*/hooks/hooks.json` | 훅은 사건에 붙는 관찰 · 알림, 진입 사전 검사(`!`)가 kill switch 를 모델 판단 밖에서 집행, 코드 `plugins/project-init/hooks/hooks.json` · `shared/entry/entry_preflight.py` | citations GREEN |
| docs/plugin-authoring.md:29 | qg 가 `commands/` · `hooks/` 를 shipping | 지금 폴더(`agents/` · `references/` · `scripts/` · `skills/`)와 「writer + reviewer 파이프라인」 | — |
| shared/README.md:36 | 「15곳」 | 「모든 진입 skill 의 SKILL.md 에 바이트 그대로(대상은 락이 글롭에서 도출)」 — 수를 박지 않는다 | — |

- 고친 앵커를 읽는 락은 도출로 찾는다. 테스트 가운데 `CLAUDE.md` · `devbrew-harness-philosophy` · `plugin-authoring` · `branch-strategy` 를 읽는 파일을 `git grep -l` 로 모으고 모두 돌린다. 문면이 바뀐 앵커마다 같은 PR 에서 락을 고치고 양의 짝을 둔다.
- R8 :453(의존 · degradation 문장에 gh 필수 · 개발 당시 판 · superpowers 부재 동작)은 :50 · :73 행이 받는다. superpowers 부재 동작은 `dependencies.md` 의 「없을 때」 칸을 가리켜 덮는다.
- R7 :235 의 「나머지 규칙 정리는 R9」는 이 표 전체다.

### §7 지휘자 권장을 옮기는 규칙

`plugins/spec-distill/references/conductor-dispatch.md` `## 사람 자리`(:32)를 고친다.

- 더한다: 「지휘자 자신의 권장은 라벨 안 「(권장)」으로 넣지 않는다 — 지휘자가 만든 질문에서도 같다. 지휘자 권장은 선택지 밖 「지휘자 의견:」 한 줄이다. skill 이 문장으로 낸 권장(예: 「I recommend …」)은 그 문장을 옮겨 싣고 라벨 꼬리 「(권장)」으로 바꾸지 않는다 — 라벨은 원문 라벨 그대로다」.
- 바꾼다: 「그 선택지의 「(권장)」 도 지휘자 것이라고 밝힌다」는 「그 선택지에는 「(권장)」을 달지 않는다」로.
- 옮김 대조 agent `plugins/spec-distill/agents/relay-checker.md` 의 항목 4(:32)와 「지휘자가 만든 질문」 문단(:35)을 같이 맞춘다 — 둘 다 어긋남으로 잡는다.
  - 지휘자가 만든 질문의 라벨에 「(권장)」이 있다.
  - 원문이 문장으로 권장했는데 보인 라벨에 「(권장)」 꼬리가 붙었다.
  
  persona 를 조이는 편집이다(보안-민감 — PR 에 밝힌다).
- 락: `test_conductor_dispatch_reference.sh` 에 새 문장(양)과 옛 「지휘자 것이라고 밝힌다」(음), `test_epic_conductor_skill.sh` 의 relay-checker 단언에 두 어긋남 문장(양).
- relay-1 관찰(「Native 설명 축약 · mid-tier 문장 빠짐」)은 이미 있는 「선택지 설명을 옮길 때 원문의 문장을 하나도 빼지 않는다」가 덮는다. 새 문장은 두지 않는다.

### §8 위험에 대한 답

묶음 §5 의 위험과 원본 brief 위험 가운데 이 에픽에 닿는 것:

- RC12 · RC84(high 는 지출 전 승인 필수) — §2 가 규칙을 바꾼다(U1). 사용자 결정권은 범위 고르기 질문에 남는다.
- RC13(Subagent spray) — 규모 공시 줄이 fan-out 선언이다. CLAUDE.md:91 은 그대로다.
- RC14(Unbounded autonomy) — 이 에픽이 걷는 것은 한 번 묻는 게이트이지 루프 상한이 아니다. 고치는 장치의 루프 상한은 그대로 남는다.
  - 지휘자: 로드맵의 유한한 에픽, spec 리뷰 라운드 상한, kill switch `DEVBREW_SPEC_DISTILL_DISABLE`.
  - plugin-audit: 고른 축 수, 심층검증은 반박을 통과한 지적마다 2회 — 상한 없음이지만 유한하고 공시한다. kill switch.
  - artifact-critique: `effective_max_rounds` · 정체 감지 · kill switch.
  - 인터뷰 조사 상한 60 · 연장 질문은 손대지 않는다.
  
  AC17 이 이 셋의 상한 문장이 남았음을 단언한다.
- RC62(qg PR 코멘트 상시 동의) — 지출 승인이 아니라 그대로다(P17).
- RC64(artifact-critique upfront 게이트) — §4. 묶음은 옛 경로 `skills/critiquing-artifacts/` 를 적지만 지금은 `skills/artifact-critique/` 다.
- K1(멈춤 판정의 주인이 모델로) — 지출 질문이 없어져도 멈출 길은 셋이다. 범위 질문의 「중단」 · 「취소」(plugin-audit 은 첫 축 질문에 「중단」을 새로 두고 규모를 선택지 설명에 보여, 고르기 전에 규모를 보고 멈출 수 있다 — 지휘자 판단(사용자 결정 아님)), 끼어들기, kill switch. epic-conductor 는 범위 질문이 없어 로드맵 고르기 뒤 끼어들기와 kill switch 로 멈춘다.
- K6 · K13(승인 피로 · 도장 찍기) — 지출 질문이 빠져 남은 사용자 결정(spec 승인 · 범위 고르기)이 덜 묻힌다.
- K7(사용자 자신의 통제 자리가 섞임) — 지출 승인은 사용자가 직접 걷자고 했다(U1). 범위 고르기는 사용자 통제 자리라 남긴다.
- K8(공유 파일 겹침) — R14 와 겹치는 파일의 주인 · 머지 순서(`## 상류 · 하류 연계`), 판 번호는 머지 직전.
- K14(봉인된 결정) — CLAUDE.md Sealed decision · P23 은 그대로다.

이 설계가 새로 여는 위험:

- 묻지 않고 큰 실행이 돈다 — 공시 줄은 띄우기 전에 보이고, 상한과 kill switch 는 그대로다. 사용자가 고른 결정이다.
- 옛 `machine.md` · 옛 감사 데이터를 못 읽는다 — §3 · §4 의 호환 길과 AC 가 막는다.
- 규칙 문장을 바꾸면 그 문장을 잡던 락이 공허해지거나 RED 가 된다 — §6 의 도출로 찾고 양의 짝을 둔다.
- `docs/` · `chore/` 로 이 레포의 훅 동작이 바뀐다 — §5 행 5 의 테스트.

### §9 계획

계획 둘. 계획 2 는 계획 1 이 머지된 뒤 기본 브랜치에서 시작한다(쌓은 PR 은 두지 않는다).

| 계획 | 브랜치 | 내용 |
|---|---|---|
| 1 | `feature/rules-docs-cleanup` | §5 행 1~5 · §6 · §7 · N13 락 |
| 2 | `feature/cost-scale-disclosure` | §2 · §3 · §4 — 규칙 문장과 high skill 게이트 · 스크립트 · 락을 한 PR 에서(규칙과 장치가 머지 사이에 어긋나지 않게) |

- 각 계획의 첫 과제는 가벼운 다시 확인이다. 이 설계의 자리(ad7efbb6 기준 줄 번호)가 그 뒤 바뀌었는지만 본다. 바뀐 자리를 표로 적고, 설계와 다른 사실이면 보고한다. 전수 조사는 설계 때 끝났다(사용자 결정 U3 · U4).
- 계획 1 의 그 과제는 셋을 함께 본다 — 중간 단계를 막는 장치 문장이 없는지(§5 행 2), R2 §4 처분 결과가 철학 문서와 어긋나지 않는지(R2 :241), §6 의 문장 사실(state 수명 넷 · qg TTL · 상태 루트)이 지금 코드와 같은지.

## 있는 것 검토

- 레포 안(쓴다):
  - `roadmap_write.py update`(로드맵 재범위)
  - `test_plain_language_block.sh` + `plain_language_block.py`(사본 동기화 — 대상 도출)
  - `conductor_state.py` 의 `skip` 읽기 길 · 빈 절 생략(§3)
  - `validate-audit-data.py` 의 `at` · `fanout` 검사(§4)
  - project-init 템플릿의 브랜치 문면 · `derive_prefixes`(§5 행 5)
  - `check_deps.py` · `dependencies.md`(§6 의존 문장)
  - `trivia-escape.md`(P12 가리킴)
  - governance · shape · citations · invocation surface 락
- 레포 안(맞지 않아 쓰지 않는다): `OPTIONAL_SECTIONS` 만 쓰는 길(옛 행이 남는다 — §3).
- 레포 밖: 쓰지 않는다.

## 상류 · 하류 연계

- 받는 곳: 묶음 R9.md · 사용자 결정 U1~U4 · 흐름 고정 점검 R9 절 · R8 :453 · R2a :418 · R5 :518 · :630 · R11 :108 · :237 · R2 :221 · :241 · R7 :235 · R13 :415 · R8 :479 지휘 기록 · sweep.md.
- 넘기는 곳:
  - 고친 규칙(CLAUDE.md · 철학) → 모든 에픽 · 모든 플러그인 작성자.
  - 규모만 공시하는 high skill → 지휘 · 감사 사용자.
  - 새 쉬운 말 블록 → 네 플러그인의 모든 진입 skill.
  - 옮김 규칙 → 지휘자 · 옮김 대조 agent.
- 되돌아오는 길: 계획 · 구현에서 설계를 다시 나눌 근거가 보이면 재분해 신호 · 설계 변경으로 지휘 세션에 보고한다(`references/redecompose.md`). 예: 규모 공시만으로 위험한 자리가 나옴, 옛 상태 호환이 깨짐.
- 같은 상태를 읽는 다른 표면:
  - 기계 상태 `machine.md` — `conductor_ledger.py` · `roadmap_status.py` · `control_plane.py` · `merge_check.py`(`시작 승인` 절을 읽는 곳은 ledger 뿐임을 계획 첫 과제가 다시 grep 한다)
  - 감사 데이터 `audit-data.json` — validate · assemble · render
  - 쉬운 말 블록 — 사본 10곳과 락
  - 브랜치 정규식 — project-init 훅
  - 이음매 담당은 이 에픽이다.

**R14 와의 병렬 · 통합** — 사용자 원문 「좋아 그리고 작업하는겇가장 먼저에 꼼꼼히 조사도 넣어주고 놓친거 있을 수 있으니, 파일이 안 겹치면 병렬 권장 이긴한데 회귀나 병렬 진행으로 인한 통한은 여전히 잘해야해」.

- 지휘자 판단(사용자 결정 아님): R14 가 먼저 머지한다. R9 의 각 PR 은 그 뒤 기본 브랜치를 합치고, 스위트 대조와 에픽 사이 통합 리뷰를 다시 돈다.
- 겹치는 파일과 고칠 주인:

| 파일 | R14 가 고치는 것 | R9 가 고치는 것 |
|---|---|---|
| `plugins/spec-distill/scripts/conductor_ledger.py` | 에픽이 자기 PR 번호를 적는 길 · `ledger add` 같은 키 · lazy fetch 등 R14 범위 | `approval` · `approve` · `scale_check` · `_drop_approval` 걷기(계획 2) |
| `plugins/spec-distill/tests/test_epic_conductor_skill.sh` | R14 범위의 단언 | 4절 · 예외 락(계획 2) · relay-checker 단언(계획 1) |
| `plugins/spec-distill/README.md` | R14 범위의 문장 | :17 · :120 · :144 · :159 시작 승인 문장(계획 2) |
| `plugins/spec-distill/skills/spec-review/SKILL.md` | R14 범위 | 쉬운 말 블록(:23) 한 줄만(계획 1) |
| `plugins/spec-distill/skills/request-framing/SKILL.md` | R14 범위 | 쉬운 말 블록(:19) 한 줄만(계획 1) |
| `plugins/spec-distill/tests/test_roadmap_status.sh` | 정적 락 후보 여덟 | 겹침 정보 단언 한 줄(이 설계의 로드맵 커밋 — 이미 함) |

- R14 는 위 R9 몫의 자리(4절 · 승인 코드 · 쉬운 말 블록)를 고치지 않는다. `references/conducting.md:13` 의 괄호 「(새로 잡아야 그 세션의 옛 시작 승인이 지워진다)」도 R14 는 건드리지 않고, R9 계획 2 가 예약 밖 편집으로 고친다(지휘자 판단(사용자 결정 아님)).
- R5 설계 :642 의 SKILL 문장(「approval rc≠0 → AskUserQuestion」)에 대해 R14 가 할 일은 없다. R9 계획 2 가 그 approval 갈래를 통째로 지운다. 지휘자가 R14 에 그렇게 알린다(지휘자 판단(사용자 결정 아님)). R2a 설계 :496 문장(artifact-critique 진입 'ok' 행)은 R14 몫으로 남는다. R9 는 같은 파일의 E3 만 고친다.
- 겹침 확인: R9 PR 마다 `merge_check.py --keep-merged` 사본에서 R14 가 넣은 줄이 남았는지 diff 로 본다(AC21).

## Acceptance Criteria

**계획 1 — 규칙 문장 · 쉬운 말 · 옮김 규칙**

- AC1 정본 `plain-language.md` 의 순서 줄이 §5 행 1 의 뜻(기본 하나 · 여럿이거나 병렬이면 밝힘 · 커밋 · PR 본문 제외)이다. 옛 「맨 끝에 사용자가 할 일 하나.」 는 정본에 없다. 사본 전부가 정본과 바이트 같다(기존 락 GREEN). 락이 정본의 새 문장(양) · 옛 문장(음) · N13 문장(양)을 단언하고, 정본에 옛 문장을 되돌리는 변이에 RED 다.
- AC2 quality-pipeline 완료 보고 · artifact-critique 최종 보고 · plugin-audit 종료 보고가 「기본 하나, 여럿이거나 병렬이면 밝힌다」고 지시한다. 테스트 셋이 새 문장을 단언하고 「exactly one」 · 「할 일 하나를 쓴다」 부재를 단언한다. roadmap-status · project-init · epic-conductor 자리는 바뀌지 않는다.
- AC3 CLAUDE.md Law 1 과 철학 P12 에 중간 단계 문장(기본 설계 → 계획 → 구현 · 이유 · 가벼운 꼴 · 필수 섹션을 짧게 덮음)이 있고, trivia escape 문장은 그대로다. qg AC8c 는 GREEN 이고, 새 단언은 중간 단계 문장 삭제 변이에 RED 다.
- AC4 CLAUDE.md Law 1 과 철학 Law 1 이 brief 는 `check_brief.py` 가 막고 설계문서 필수 섹션은 기계 게이트 없이 리뷰어 · 승인 게이트가 본다고 쓴다. 단언(양)이 있다.
- AC5 CLAUDE.md:97 · 철학 P10 이 persona 기본 · 락 · 스크립트 · skill 이 더 맞으면 그것 · 이유를 적는다고 쓰고, 그 문장에 「메모리」가 없다(양 · 음). qg README · plugin-audit README · SKILL.md:302 가 같은 뜻이다. persona 파일은 바뀌지 않는다(diff 에 `agents/` 는 relay-checker 하나뿐).
- AC6 CLAUDE.md:82 · `docs/plugin-authoring.md` 의 skill 강제 문장이 기본 경로 꼴이고, 「진입할 때만 로드」 · 「유일한 것」 이 없다. `/plugin-audit` 짧은 이름이 없다. 호출 표면 락 GREEN.
- AC7 `branch-strategy.md` 정규식이 넷을 받고, 문면이 §5 행 5 대로다. 훅의 읽기 함수로 읽은 이 레포 정규식이 `docs/x` · `chore/x` · `feature/x` 를 받고 `misc/x` 를 거부하며 `derive_prefixes` 가 넷을 낸다. `docs` 를 지우는 변이에 RED 다. rebase 원문 락 GREEN. CLAUDE.md:14 · :18 이 §5 · §6 대로다.
- AC8 §6 표의 모든 행이 고쳐졌다. shape 앵커 둘(`모든 훅에 kill switch` · `최소 버전이 선언된 의존성`)과 `test_check_shape_completeness.py` GREEN. `test_charter_citations.sh` GREEN(새 코드 가리킴이 실재). project-init README 에 「Hooks Installed」 절이 있다. `shared/README.md` 에 사본 수 숫자가 없다.
- AC9 `conductor-dispatch.md` 에 §7 의 두 문장이 있고 옛 「지휘자 것이라고 밝힌다」가 없다. relay-checker 가 두 어긋남을 적는다. 락이 양 · 음으로 단언하고, 옛 문장을 되돌리는 변이에 RED 다.
- AC10 CLAUDE.md · 철학 · 가이드 · branch-strategy 를 읽는 테스트를 `git grep -l` 로 모은 목록 전부가 GREEN 이고, 그 목록과 수를 PR 에 적는다.

**계획 2 — 지출 승인을 규모 공시로**

- AC11 CLAUDE.md cost 줄에 §2 의 공시 문장(`cost_class: high` 에 건다) · 「어느 클래스의 skill 도 지출 승인을 묻지 않는다」 · 「상한 · 압축은 공시하고, 사용자가 상한을 여는 질문은 지출 승인이 아니다」가 있고, 옛 게이트 문장 · 「이름 붙인 예외」 · 「worst-case 가 high 인 `variable`」이 없다. 굵은 머리 「모든 skill에 `cost_class` 선언」 유지(shape GREEN). CLAUDE.md:91 은 바뀌지 않는다(diff).
- AC12 P22 가 `cost_class: high` · 공시 · 범위 질문을 담고 `<Use_When>` 이 없다. 코드 가리킴이 실재한다(citations GREEN).
- AC13 epic-conductor `### 4. 규모 공시` 가 규모 줄을 보이고 5 로 간다. 그 절에 `approval` · `approve` · `AskUserQuestion` · `release` 펜스와 「승인 전에는 agent 를 보내지 않는다」가 없다. 변이(옛 approval 펜스 재삽입 · 공시 문장 삭제)에 RED 다.
- AC14 `conductor_ledger.py approval|approve` 는 rc 2 와 모르는 하위 명령 사유를 낸다(rc · 사유 함께 단언). claim · takeover · release 는 그대로 돈다. `conductor_state` 는 `## 시작 승인` 행이 있는 옛 파일을 오류 없이 읽고, 다시 저장하면 그 절 머리가 없다. 새로 만든 파일에는 처음부터 없다. 그 절이 없는 파일도 읽는다. e2e 가 규모 공시로 돈다.
- AC15 plugin-audit step 3 의 첫 축 질문에 「여섯 축 전부 (권장)」 · 「축 골라서」 · 「중단」이 있고, 선택지 설명에 규모가 있으며, 「중단」이면 실행 폴더를 만들지 않고 끝난다. (b) 에 「승인」 질문이 없고 공시 줄 문장이 있다. 순서는 축 질문 → 공시 → `prepare-run-dir.py`. `test_skill_orchestration.py` 가 이를 단언하고, 첫 질문의 「중단」을 지우는 변이에 RED 다. `consent.json` 은 `{at, fanout, axes}`. 검증기는 `approved` 없음 통과 · `approved: false` 오류 · 옛 픽스처 통과다(각 변이). :238 근거 문장이 사용자 호출 · `disable-model-invocation` 을 말한다.
- AC16 artifact-critique E3 의 두 질문 · 선택지가 그대로이고, 지출 승인 문장 · `consent-integrity` 가 없으며 새 낱말이 있다(양 · 음).
- AC17 `shared/tests/test_cost_disclosure.sh` 가 두 갈래로 잠근다. (가) 글롭으로 도출한 모든 SKILL.md(수 = `find` 수)에 지출 승인 문구가 없다. pm-interview 의 연장 질문 · 리뷰 엔진 skill 의 추가 라운드 질문은 걸리지 않는다(양성 대조). (나) epic-conductor · plugin-audit · artifact-critique 에 공시 줄 문장이 있다. 지휘자 · plugin-audit · artifact-critique 의 루프 상한 · kill switch 문장이 남았는지도 단언한다(RC14). 변이 — 아무 SKILL.md 하나(게이트가 없던 variable skill 포함)에 「지출 동의 게이트」 재삽입, 세 skill 중 하나의 공시 문장 삭제, 임시 사본에 지출 승인 문구를 가진 새 SKILL.md 하나 추가 — 셋 다 RED.
- AC18 qg AC8a · `test_epic_conductor_skill.sh` 예외 락이 §2 대로 바뀌고 양의 짝을 가진다.

**공통**

- AC19 바뀐 동작마다 테스트를 먼저 쓰고 RED 를 본 뒤 고쳤다. 변이는 커밋 뒤에 했고 양성 대조를 둔다. 셸은 `/bin/bash`(3.2).
- AC20 판 — 머지 시점 기본 브랜치 위에서 정한다.
  - 계획 1: 사본을 바꾼 네 플러그인 patch.
  - 계획 2: spec-distill · plugin-audit minor(동작 변경 · 하위 명령 제거), quality-gates patch.
  - CHANGELOG 를 쓴다. 계획 2 는 `Removed` 에 `approval` · `approve` · 이름 붙인 예외 · 지출 동의 질문을 적는다.
- AC21 각 PR 은 R14 머지 뒤 기본 브랜치를 합쳐 스위트 대조(공유 잠금 아래)에서 새 실패 0 이다. 통합 리뷰를 다시 돈다. 겹치는 파일에서 R14 가 넣은 줄이 합친 사본에 남아 있다(diff 로 확인해 PR 에 적는다).

## Files to Modify

**예약 안(R9 경로 예약 — 이 설계의 로드맵 커밋이 넓혔다)**

계획 1:
- `CLAUDE.md` · `docs/philosophy/devbrew-harness-philosophy.md` · `docs/plugin-authoring.md` · `docs/git-workflow/branch-strategy.md` · `shared/README.md`
- `shared/style/plain-language.md` · `shared/tests/test_plain_language_block.sh`
- 사본 10곳:
  - `plugins/plugin-audit/skills/plugin-audit/SKILL.md` · `plugins/project-init/skills/project-init/SKILL.md`
  - `plugins/quality-gates/skills/{artifact-critique,quality-pipeline}/SKILL.md`
  - `plugins/spec-distill/skills/{epic-conductor,pm-interview,request-framing,reviewing-brief,roadmap-status,spec-review}/SKILL.md`
- 테스트 · 문서: `plugins/plugin-audit/tests/test_plain_audit_text.py` · `plugins/quality-gates/tests/test_plain_qg_templates.sh` · `plugins/quality-gates/tests/test_governance_no_capability_caps.sh` · `plugins/project-init/README.md` · `plugins/project-init/tests/test_branch_strategy_rebase_clause.sh` · `plugins/quality-gates/README.md` · `plugins/plugin-audit/README.md`
- 옮김 규칙: `plugins/spec-distill/references/conductor-dispatch.md` · `plugins/spec-distill/agents/relay-checker.md` · `plugins/spec-distill/tests/test_conductor_dispatch_reference.sh` · `plugins/spec-distill/tests/test_epic_conductor_skill.sh`

계획 2:
- 규칙: `CLAUDE.md` · 철학 문서
- spec-distill:
  - `skills/epic-conductor/SKILL.md` · `scripts/conductor_ledger.py` · `scripts/conductor_state.py` · `README.md`
  - `tests/test_conductor_ledger.py` · `tests/test_conductor_state.py` · `tests/test_conductor_e2e.sh` · `tests/test_epic_conductor_skill.sh`
- plugin-audit:
  - `skills/plugin-audit/SKILL.md` · `scripts/validate-audit-data.py` · `scripts/prepare-run-dir.py` · `scripts/audit-workflow.js`(주석)
  - `README.md` · `tests/README.md` · `tests/test_skill_orchestration.py` · `tests/test_validate_audit_data.py`
- quality-gates: `skills/artifact-critique/SKILL.md` · `tests/test_critiquing_artifacts_skill.sh` · `tests/test_governance_no_capability_caps.sh` · `README.md`
- 새 파일: `shared/tests/test_cost_disclosure.sh`(100755)

**예약 밖**

- `plugins/spec-distill/tests/test_reviewing_brief_skill.sh:73` — 실패 메시지 「high 는 지출 승인 게이트를 요구한다(CLAUDE.md)」 를 새 규칙에 맞춘다(계획 2). 락 지도(`locks.md`)가 이 파일을 R13 행으로 적어, 예약하면 `test_roadmap_status.sh` 의 락 지도 단언이 깨진다. 그래서 예약하지 않고 경로 예약 정보 줄 하나를 받아들인다.
- `plugins/spec-distill/references/conducting.md:13` — 괄호 「(새로 잡아야 그 세션의 옛 시작 승인이 지워진다)」를 뺀다(계획 2, 예약 밖 편집). R14 가 예약한 파일이지만 R14 가 먼저 머지하고 그 문장은 건드리지 않는다(지휘자 판단(사용자 결정 아님)). 경로 예약 정보 줄 하나를 받아들인다.
- 네 플러그인의 `.claude-plugin/plugin.json` · `CHANGELOG.md` — 판 번호는 머지 직전.
- 이 설계의 로드맵 커밋(이미 함): `roadmap.md` · `R9.md` · `R14.md` · `plugins/spec-distill/tests/test_roadmap_status.sh`(겹침 정보 단언에 R9 ↔ R14 한 줄).

## Verification Plan

- 바뀐 동작마다 테스트를 먼저 쓰고 RED 를 본 뒤 고친다. 락은 변이 — 삭제 · 추가 · 반전 · 형태 변경 — 로 이빨을 확인한다. 변이 전에 커밋하고, 복원은 `git checkout HEAD --` 뒤 `git diff HEAD` 로 확인한다. `PYTHONDONTWRITEBYTECODE=1`.
- 옛 상태 호환은 진짜 옛 꼴의 픽스처로 확인한다 — ad7efbb6 의 `render_machine` 이 쓴 `machine.md` 와 지금 `ac6_*` 픽스처.
- 셸 펜스 · 테스트는 `/bin/bash` 3.2 로 돈다. 새 셸 테스트는 100755 다.
- 규칙 문장을 읽는 테스트는 도출 목록으로 모두 돌린다(AC10).
- 전체 스위트(`bash tools/suite/run-all.sh`) 대조를 R14 머지 뒤 기본 브랜치를 합친 사본에서 한다. 이어 에픽 사이 통합 리뷰(지휘자)를 돈다.

## Rejected Alternatives

같은 기준으로 견준다 — 사용자 결정과 맞는가 · 장치 무게(새 상태 · 명령 · 파일) · 옛 상태와의 호환 · 다른 표면과의 이음매.

- 지휘자만 규모 공시(다른 high skill 은 승인 유지) — 사용자가 「모든 high skill 을 규모 공시만으로 (권장)」을 골랐다.
- 규칙만 R9, skill 은 R14 — 사용자가 「R9 가 규칙과 skill 을 함께 (권장)」을 골랐다. 또 규칙과 장치가 다른 PR 에 있으면 그 사이 main 이 어긋난다.
- `approval` 을 「공시만」 내는 하위 명령으로 남김 — 소비자가 없는 표면이다. 규모 줄은 skill 이 이미 만든다.
- `conductor_state` 에서 `시작 승인` 절을 그냥 지움 — 옛 `machine.md` 가 「모르는 절」로 읽기 실패한다(:190-191). 지휘 재개가 막힌다.
- `시작 승인` 을 `OPTIONAL_SECTIONS` 에만 더함 — 옛 행이 있으면 저장마다 다시 써서, 읽는 쪽 없는 행이 남는다.
- 동의 기록에서 `approved` 를 `disclosed` 로 바꿈 — 옛 데이터를 위해 두 키를 다 받아야 하고, 이름만 바뀐 같은 불리언이다. `at` · `fanout` 일치가 이미 공시를 잰다.
- `approved` 를 그대로 `true` 로 계속 씀 — 승인이 없는데 승인했다고 적는 기록은 막지 않는 것을 막는다고 믿게 하는 선언이다.
- artifact-critique E3 질문까지 지움 — 대상 · 모드 · 취소 · 비평자 수는 범위 고르기다. 사용자가 남기라고 했다.
- 브랜치 접두를 `feature/` · `fix/` 그대로 두고 문면만 — 점검 문서 행 5 가 접두 선택지(`docs/` · `chore/`)를 적었고, 템플릿은 이미 선택지를 준다. 이 레포만 고정으로 남는다. 사용자가 더하기를 골랐다(U6).
- 설계문서 필수 섹션 기계 게이트를 지금 만듦 — 새 기능이고 R9 범위 밖이다. 문장을 사실대로 고치는 것이 이 에픽의 몫이다.
- 역할 프롬프트 공식을 지키려고 agent 열여섯에 한 줄씩 더함 — persona 편집 다수(보안-민감)다. 사용자가 규칙 문장을 맞추기로 골랐다(U7).
- Law 1 가벼운 꼴은 이유만 밝히고 섹션은 덮지 않음 — Law 1 의 「silent 하게 skip 불가」와 어긋난다. 사용자가 짧게 덮기를 골랐다(U5).
- variable skill 에도 공시 의무를 지움(「worst-case 가 high 인 variable」) — 공시 의무는 high 에 걸리고, variable 은 지출 승인을 묻지 않는다는 음성 규칙과 코퍼스 락으로 충분하다(지휘자 판단(사용자 결정 아님)).
- plugin-audit 을 공시만 하고 멈춤 선택지 없이 둠 — 「여섯 축 전부」를 고르면 멈출 길이 끼어들기뿐이다. 첫 축 질문에 「중단」을 둔다(지휘자 판단(사용자 결정 아님)).
- `shared/README.md` 에 「10곳」 — 다시 낡는다. 도출이라고 쓴다.

## 결정 기록

- U1 · 결정 · 2026-10-23 · 사용자 — 「모든 high skill 을 규모 공시만으로 (권장)」 (지출 승인 조항 범위 — OQ35 해결. 선택지는 「모든 high skill 을 규모 공시만으로 (권장)」 · 「지휘자만 규모 공시만으로」)
- U2 · 결정 · 2026-10-23 · 사용자 — 「R9 가 규칙과 skill 을 함께 (권장)」 (게이트 제거를 받을 곳 — R9 범위를 넓히는 재분해 원문. 선택지는 그것과 「R14 가 skill 을, R9 가 규칙을」)
- U3 · 결정 · 2026-10-23 · 사용자 — 「좋아 그리고 작업하는겇가장 먼저에 꼼꼼히 조사도 넣어주고 놓친거 있을 수 있으니, 파일이 안 겹치면 병렬 권장 이긴한데 회귀나 병렬 진행으로 인한 통한은 여전히 잘해야해」 (R9 되비춤 ①②③ — ③ SKILL 문장 둘은 R14, 에픽 병렬 권장은 지휘자 수리)
- U4 · 질문 · 2026-10-23 · 사용자 — 「아님 스펙 만들때 조사가 더 좋으려나」 → 지휘자 답: 설계 쓰기 전에 전수 조사(주) + 계획 첫 과제는 설계 뒤 바뀐 것만 다시 확인(가벼움). 조사는 sweep.md 로 끝났다.
- 흐름 고정 점검 결정 · 2026-10-17 · 사용자 — 「에픽 실행 방식 SDD 고정, 「끝에 할 일 하나」, Law 1 의 중간 단계, qg 리뷰어 모델 opus 고정, 1번의 경우 writing plan이 끝나면 권장 실행 방식이 있을거야 subagent driven이라고 되어있는걸 권장 구현 방식으로 간다고 해둬」 · 「좋아 이게 앞으로의 원칙이야」 (§5 행 1 · 2 의 근거. 행 3~5 는 같은 원칙으로 점검이 찾은 것)
- 지휘자 판단(사용자 결정 아님) · 2026-10-23:
  - R14 가 먼저 머지하고, R9 는 그 뒤 기본 브랜치를 합쳐 스위트 대조 · 통합 리뷰를 다시 돈다. R14 는 PR 번호 기록을, R9 는 게이트 제거와 쉬운 말 사본을 맡는다.
  - `conductor_state.py` 는 옛 `## 시작 승인` 을 계속 읽고, 요구 · 쓰기를 멈추며, `approval` · `approve` 는 공시 전용이 되거나 은퇴한다 — 더 작은 쪽을 고른다.
  - plugin-audit 동의 데이터 계약은 옛 데이터를 유효하게 두는 최소 변경으로 한다.
  - plugin-audit Workflow 근거는 사용자의 `/plugin-audit:plugin-audit` 호출 자체다.
  - 점검 행 3 의 대체에서 「메모리」를 뺀다(Law 3 · C44) — 「persona 기본, 락 · 스크립트 · skill 이 더 맞으면 그것」.
  - 행 5 는 정규식 변경을 최소로, `docs/` · `chore/` 를 더할지는 작성자가 정하고 더하면 훅 동작 변경과 테스트를 적는다. 문면 행은 어느 쪽이든 고친다.
  - sweep §B 의 문장을 지금 장치에 맞게 모두 고치고, 앵커를 잡는 락은 이빨(양의 짝)을 지킨다. persona · 리뷰어 규칙은 사용자 결정 밖으로 약하게 하지 않는다.
  - 행 1 정본과 사본 10곳 · skill 자리 여섯을 기존 락으로 맞춘다.
  - 행 2 문장은 사용자 결정 그대로, trivia escape 는 그대로.
  - 옮김 규칙 문장을 지휘자 dispatch reference 의 사람 자리에 둔다.
  - N13 은 확인해서 끝냄 또는 빠진 것만 더한다.
  - RC14 는 확인 뒤 표시한다.
  - 큰 에픽이라 계획 둘로 나누고 첫째 브랜치는 `feature/rules-docs-cleanup`.
- 작성자 판단(지휘자가 맡긴 자리 · 사용자 결정 아님) · 2026-10-23:
  - `conductor_state` 는 「읽되 버리는 절」(`RETIRED_SECTIONS` + `skip` 길 + 쓰지 않음)이다. `approval` · `approve` 는 은퇴(공시 전용으로 남기지 않음)한다. 옛 행까지 걷는 쪽이 같은 크기에 더 깨끗하다(§3).
  - 동의 기록은 키 이름 그대로 두고 `approved` 를 요구하지 않으며, 있으면 `true` 여야 한다(§4).
  - `docs/` · `chore/` 를 더하자고 제안했다 — 사용자가 U6 으로 정했다.
  - Law 1 의 가벼운 꼴도 필수 섹션을 짧게 덮자고 제안했다 — 사용자가 U5 로 정했다.
  - 역할 프롬프트 규칙은 문장만 맞추자고 제안했다 — 사용자가 U7 로 정했다.
  - 쉬운 말 skill 자리는 「하나만」을 강제하는 셋만 고친다.
  - `test_reviewing_brief_skill.sh` 는 예약하지 않는다(락 지도).
  - qg `dependencies.md` 의 `pr-review-toolkit` 행은 `check_deps.py measure` 가 외부 플러그인 판을 못 재서 새 측정 길이 필요하다 → `## 미룸`.
  - 계획 2 브랜치 이름은 `feature/cost-scale-disclosure`.
  - 로드맵 재분해의 원문은 U1 · U2 둘을 실었다.
- U5 · 결정 · 2026-10-23 · 사용자 — 「짧게 덮는다 (권장)」 (Law 1 중간 단계의 가벼운 꼴도 필수 섹션을 짧게 덮고, 다루지 않는 섹션은 「해당 없음 — 이유」로 적는다 — §5 행 2)
- U6 · 결정 · 2026-10-23 · 사용자 — 「docs/ · chore/ 를 더한다」 (branch-strategy.md:12 정규식에 두 접두를 더하고 훅 테스트를 단다. 문면과 템플릿은 서로 맞게 — §5 행 5)
- U7 · 결정 · 2026-10-23 · 사용자 — 「규칙 문장을 맞춘다 (권장)」 (CLAUDE.md:48 문장을 agent 들의 실제 모양에 맞추고 agent 파일은 하나도 고치지 않는다 — §6)
- 지휘자 판단(사용자 결정 아님) · 2026-10-23 · 설계 점검 뒤:
  - plugin-audit 멈춤 길 — (b) 질문을 지우면 「여섯 축 전부」를 고른 사용자에게 멈출 선택지가 없다. 첫 축 질문에 「중단」을 더하고 규모를 선택지 설명에 실어 고르기 전에 보이게 한다. 범위 질문은 남긴다는 사용자 결정을 지킨다(§4 · §8 K1 · AC15 · `test_skill_orchestration.py`).
  - `references/conducting.md:13` 의 낡은 괄호 「(새로 잡아야 그 세션의 옛 시작 승인이 지워진다)」는 R9 계획 2 가 예약 밖 편집으로 고친다(`test_reviewing_brief_skill.sh` 와 같은 꼴). R14 가 먼저 머지하고 그 문장은 건드리지 않는다.
  - 비용 규칙은 `cost_class: high` 에 건다. D18 의 문장 「상한 · 압축은 공시하고, 사용자가 상한을 여는 질문은 지출 승인이 아니다」를 규칙 문장에 넣어 pm-interview 의 연장 질문 · 리뷰 엔진의 추가 라운드 질문과 맞춘다. `variable` 은 지출 승인을 묻지 않는다는 규칙만 받는다. 락은 둘 — (가) 글롭으로 도출한 모든 SKILL.md 의 지출 승인 문구 부재, (나) 게이트가 있던 세 skill 의 공시 줄 양성. 「worst-case 가 high 인 variable」 문구는 지운다(§2 · AC11 · AC17).
  - R5 설계 :642 문장에 대해 R14 는 할 일이 없다 — R9 계획 2 가 approval 갈래를 지운다(`## 상류 · 하류 연계`).

## 번호 대조

| 번호 | 반영/기각 | 자리 또는 이유 |
|---|---|---|
| C5 | 반영 | §2 · §3 · §4 — 비용을 이유로 묻는 장치를 걷고 규모만 공시 |
| C25 | 반영 | Constraints · Non-goals — superpowers 파일 · 동작 그대로 |
| C32 | 반영 | `## 있는 것 검토` · §3(있는 `skip` 길) · §4(있는 `at` · `fanout` 검사) · §5(있는 사본 락 · 템플릿 문면) |
| C35 | 반영 | Constraints · Non-goals |
| C44 | 반영 | §5 행 3 — 대체에서 「메모리」를 뺌(교훈은 따로 다루지 않고 장치를 고쳐 남김) |
| D18 | 반영 | §2 · §3 · §4 — 지출로만 작동하는 게이트는 제거, 상한 · 심층검증 수는 공시 |
| D21 | 반영 | §8 — RC12 · RC13 · RC14 · RC62 · RC64 · RC84 와 K1 · K6 · K7 · K8 · K13 · K14 에 답함, 새 위험 넷 |
| D26 | 반영 | Constraints — devbrew 쪽만 바꿈 |
| D34 | 반영 | Anti-goals · Non-goals — 개선을 재는 새 장치 없음, 사용자가 쓰면서 판단 |
| OQ16 | 반영 | 해결(S32) 그대로 — 측정 장치를 두지 않음(Anti-goals) |
| OQ26 | 반영 | 해결(S44) 그대로 — §5 행 3 이 교훈을 장치 편집으로만 남김 |
| OQ35 | 반영 | §2 — U1 로 해결, 문안은 §2 |
| RC12 | 반영 | §2 · §8 — CLAUDE.md:51 개정 |
| RC13 | 반영 | §2 · §8 — 공시 줄이 fan-out 선언, CLAUDE.md:91 그대로 |
| RC14 | 반영 | §8 · AC17 — 루프 상한 · kill switch 가 남음을 확인 · 단언 |
| RC62 | 반영 | §8 — qg PR 코멘트 상시 동의는 지출 승인이 아니라 그대로 |
| RC64 | 반영 | §4 — artifact-critique E3 의 지출 부분만 걷음(지금 경로 `skills/artifact-critique/`) |
| RC84 | 반영 | §2 — P22 개정 |
| S1 | 반영 | §2 — 「비용을 이유로 품질을 제약하는 장치는 제거하고, 크게 쓰기 전에는 규모만 알린다」 |
| S10 | 반영 | §2 · §3 · §4 — 비용으로만 작동하는 게이트 제거 · 상한 공시 |
| S13 | 반영 | §8 |
| S17 | 반영 | Constraints · Non-goals |
| S18 | 반영 | Constraints |
| S30 | 반영 | `## 있는 것 검토` · Anti-goals |
| S32 | 반영 | Anti-goals — 측정 장치 없음 |
| S34 | 반영 | Constraints · Non-goals |
| S44 | 반영 | §5 행 3 — 교훈을 따로 다루지 않음 |
| S49 | 반영 | §1 — 묶음 범위와 넓힌 범위를 줄이지 않고 받은 넘김을 모두 실음 |

## 원칙 · 입력 대조

| 입력 | 자리 |
|---|---|
| CLAUDE.md 기본값과 판단 | §5 전체 · §6 목차 행 |
| CLAUDE.md 레포 전용 값 금지 | §6 `gh` 행 · §2 락(high skill 도출) · §6 `shared/README.md` 행 |
| CLAUDE.md 상류 · 하류 연계 | `## 상류 · 하류 연계` |
| CLAUDE.md 진입점에서 따라 내려가기 | §3(4절 → 5) · §4(축 질문 → 공시 → 실행 폴더) |
| CLAUDE.md 있는 것 먼저 | `## 있는 것 검토` |
| CLAUDE.md persona 보안-민감 | Non-goals · §5 행 3 · §7(조이는 편집 하나) |
| 흐름 고정 점검 R9 행 1~5 | §5 |
| R8 :453 | §6 :50 · :73 행 |
| R2a :418 | §5 행 3 |
| R5 :518 | §2 · §5 행 1 · 2 |
| R5 :630 | §6 목차 행 |
| R5 :642 | `## 상류 · 하류 연계` — R14 로 간 문장이 R9 계획 2 로 할 일이 없어짐 |
| R2a :496 | `## 상류 · 하류 연계` — R14 몫 |
| R11 :108 · :237 | §2 · §5 행 2 · 3 · 4 · §6 Law 1 행 |
| R2 :221 · :241 | §5 행 1 N13 · §9 계획 첫 과제(§4 처분과 철학) |
| R7 :235 | §6 |
| R10 :214 | §1 행 9 — 이미 끝남 |
| R13 :415 · R8 :479 지휘 기록 | §7 |
| sweep §A~§D | §2~§7 |

## 미룸

| 항목 | 이유 | 받는 곳 |
|---|---|---|
| qg `dependencies.md` 에 `pr-review-toolkit` 행 — qg 가 그 agent 를 dispatch 하는데 의존 표에 없다 | 판 칸은 `check_deps.py measure` 만 쓰는데 외부 플러그인 판을 재는 길이 없다 — 새 측정 길은 장치 변경이고 `shared/deps/check_deps.py` 는 R14 가 예약했다. 지휘자가 R14 범위에 싣거나 다른 받는 곳을 사용자에게 묻는다 | R14 |

## 지휘 기록

- 2026-10-23 · 설계 전 읽기 전용 전수 조사를 ad7efbb6 에서 했다(기록 `~/.claude/sdd-mirror/epic-decisions/r9/sweep.md` · 입력 `inputs.md`).
- 2026-10-23 · 설계문서는 하위 agent 가 지휘자 판단 안에서 썼다. 판단 밖의 다듬음은 `## 결정 기록` 「작성자 판단」에 있다.
- 2026-10-23 · 로드맵 R9 재범위는 같은 브랜치의 따로 된 커밋이다(생성기 `roadmap_write.py update`, 원문 U1 · U2).
  - R14 블록 받는 것의 괄호 「R9 는 장치 동작을 바꾸지 않는다」는 생성기가 R14 묶음 §7 과 함께 지웠다.
  - 재분해 이력 2026-10-22 머리(roadmap.md:465)의 같은 괄호는 그때의 기록이라 두었다 — 지휘자가 정한다.

## Metadata

- 에픽: R9 · 묶음 `R9.md`
- 브랜치: 계획 1 `feature/rules-docs-cleanup` · 계획 2 `feature/cost-scale-disclosure`
- 크기: 계획 둘(§9)
- 의존: R8 · R11(머지됨). R14 와 병렬 — R14 가 먼저 머지한다.
- 버전: AC20. 번호는 머지 직전에 정한다.

### Deferred to plan

- 공통 공시 문장의 정확한 글자(§2 락의 본문 고유 문장) — CLAUDE.md · P22 · high skill 셋이 같은 낱말을 쓰게.
- `RETIRED_SECTIONS` 를 `parse_machine` 의 `skip` 기본값에 얹을지 따로 갈래를 둘지.
- `test_conductor_ledger.py` 승인 클래스 가운데 claim · takeover 의 다른 성질을 함께 재던 단언이 있는지 — 있으면 그 단언은 남긴다.
- relay-checker 의 두 어긋남 문장 글자.
- §6 표 각 행의 정확한 문면(뜻은 표대로).
