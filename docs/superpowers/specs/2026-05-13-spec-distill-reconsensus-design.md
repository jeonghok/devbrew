---
name: spec-distill-reconsensus
version: 1.0.0
created_at: 2026-05-13
status: design
source: brainstorming session 2026-05-13
next_phase: writing-plans
session_id: brainstorm-2026-05-13-spec-distill-reconsensus
locked_decisions:
  - id: LD1
    section: "#goals"
    summary: 'Locked decisions 정의 = 사용자가 인터뷰 (b) judgment / (d) ontological path에서 직접 답한 항목 only. (a) factual auto-confirm은 제외. (G1)'
    source: brainstorming-round-1
  - id: LD2
    section: "#goals"
    summary: 'spec.md frontmatter `locked_decisions:` 필드. reviewer는 spec.md만 읽고 deterministic하게 LD ID를 매칭. (G2, G3)'
    source: brainstorming-round-2
  - id: LD3
    section: "#non-goals"
    summary: 'Re-consensus는 별도 Phase 아닌 reviewing-spec skill 내부 sub-step (Phase [3.5]). (G4 + NG1 보강)'
    source: brainstorming-round-2
  - id: LD4
    section: "#goals"
    summary: '사용자 옵션 3개: (1) 수용 (re-consensus) / (2) 유지 (dismiss) / (3) 추가 인터뷰. (G5)'
    source: brainstorming-round-1
  - id: LD5
    section: "#goals"
    summary: 'drafting-spec Mode B는 `allowed_issue_ids` 입력만 적용 가능 (physical guard via SKILL.md contract). (G6)'
    source: brainstorming-round-3
  - id: LD6
    section: "#non-goals"
    summary: 'spec.md 본문(11 섹션) 형식 변경 없음 — 변경 범위는 frontmatter + routing + Mode B input contract. (NG1)'
    source: brainstorming-round-3
---

# spec-distill Re-consensus Gate (v0.2.0)

> **인터뷰에서 사용자와 합의된 결정은 reviewer + writer 페어가 사용자 동의 없이 뒤집을 수 없다.**

## Goal

spec-distill 플러그인의 spec-reviewer agent가 인터뷰 단계에서 사용자와 명시적으로 합의된 항목(*locked decisions*)에 영향을 주는 issue를 raise할 때, drafting-spec Mode B가 자동으로 spec을 수정하지 못하도록 차단하고, 사용자에게 *재합의 요청*(re-consensus)을 보내 (1) 수용 / (2) 유지 / (3) 추가 인터뷰 중 선택하게 하는 게이트를 reviewing-spec skill 내부 sub-step으로 도입한다.

## Context / Why

### 현재 빈틈 (v0.1.2)

`reviewing-spec` skill의 deterministic routing table은 verdict가 `needs_revise`이고 stagnation/cap 조건을 만족하지 않으면 **자동으로** `[4] Revise` (drafting-spec Mode B)로 분기한다. Mode B는 reviewer가 raise한 모든 issue를 적용하여 spec.md를 targeted-edit한다.

문제는 reviewer가 raise하는 issue 카테고리 중 일부 (`scope_creep`, `ambiguous_requirement`, `unstated_assumption`)가 *사용자가 인터뷰에서 명시적으로 답한 결정*과 충돌하는 권고를 포함할 수 있다는 것이다. 예:

- 인터뷰 round 3에서 사용자: "신규 사용자 onboarding은 in-scope" → spec.md G2
- reviewer round 1: "scope_creep — G2가 너무 광범위, Non-goals로 빼라"
- 현재 흐름: Mode B가 자동으로 G2를 NG3로 이동 → 사용자는 [5] Human Gate에 가서야 변경 사실을 본다

이는 devbrew **P17 (User sovereignty)** 위반이며, writer/reviewer 페어가 사용자 명시 결정을 사용자 부재 중 뒤집는 점에서 **AP1 (Self-approval)** 변종이다.

### 왜 지금 고쳐야 하나

`spec-distill v0.1.x`는 plan-reviewer/writing-plans로의 핸드오프를 가정하므로, spec lock 시점에 사용자 합의가 *forensically traceable*해야 한다. plan 단계로 합의가 silent하게 옮겨지면 후속 단계가 잘못된 contract 위에서 구축된다. 이는 Law 1 (Clarity Before Code)의 기반을 흔든다.

## Goals

- **G1**: 인터뷰 (b) judgment + (d) ontological path에서 사용자가 직접 답한 항목을 *locked decision*으로 식별하고 `LD1, LD2, ...` ID를 부여한다 (LD1).
- **G2**: spec.md frontmatter에 `locked_decisions:` 리스트를 추가하여 spec을 self-contained, machine-verifiable contract로 만든다 (LD2).
- **G3**: spec-reviewer agent가 각 issue에 대해 `affects_locked_decisions: [LD ids]` 필드를 출력하도록 한다 (reviewer는 여전히 read-only).
- **G4**: reviewing-spec routing table에 `affects_locked` 차원을 추가하여 locked-affecting issue가 자동 Mode B로 가지 못하게 한다 (LD3).
- **G5**: Re-consensus sub-step에서 `AskUserQuestion`으로 LD별 3-옵션 (수용 / 유지 / 추가 인터뷰)을 제시한다 (LD4).
- **G6**: drafting-spec Mode B에 `allowed_issue_ids` 입력 계약을 추가하여, 입력에 없는 issue_id는 *건드리지 않도록* SKILL.md에 명시한다 (LD5, physical guard via contract).
- **G7**: stagnation 판정 (P18)을 `dismissed_by_user` 카운터와 분리하여 사용자 명시 거절이 stagnation으로 잘못 escalate되지 않도록 한다.
- **G8**: 기존 v0.1.x spec.md (locked_decisions 필드 없음)와 하위 호환을 보장한다 — empty list로 해석 → 기존 자동 [4] path 유지.

## Non-goals

- **NG1**: spec.md 본문 (Goal/Goals/AC 등 11 섹션) 형식 변경 없음 — 변경 범위는 frontmatter + routing + Mode B input contract (LD6).
- **NG2**: plan 단계 (drafting-plan / reviewing-plan, v0.2.0 추가 예정) 도입은 별도 spec — 본 design은 spec 단계 한정.
- **NG3**: 새로운 agent 추가 없음 — spec-reviewer agent의 *출력 형식 확장*만 (frontmatter scoping은 유지).
- **NG4**: numerical scoring 도입 없음 — locked_decisions는 boolean (locked or not) 차원, 점수 X (philosophy §5.3 준수).
- **NG5**: 자동 reviewer persona 학습 없음 — `dismissed_by_user >= 3` 시 *사용자에게* "reviewer persona 점검 필요" 알림만 (Law 3 trigger), 자동 persona 편집 X.

## Constraints

- **C1**: spec-reviewer agent의 `disallowedTools: Write, Edit, MultiEdit, NotebookEdit` frontmatter 유지 (Law 2 보장). 새 출력 필드는 *prompt-level*에서 emit, file write 없음.
- **C2**: drafting-spec Mode B는 기존 `Edit` tool 사용 (전체 rewrite 금지 정책 유지).
- **C3**: reviewing-spec skill은 `cost_class: medium`. Re-consensus sub-step 추가로도 medium 초과 금지 (한 round당 최대 1번의 AskUserQuestion 묶음 dispatch).
- **C4**: state.local.md frontmatter schema 확장은 *추가* only (기존 필드 의미 변경 금지). 마이그레이션 path = empty 기본값.
- **C5**: P22 (cost class) 준수 — 새 sub-step이 fan-out factor를 늘리지 않아야 함 (AskUserQuestion 1회 = sub-agent dispatch 아님).
- **C6**: P21 (secret 기록 금지) — locked_decisions의 `summary` 필드는 token/key/credential 패턴 placeholder 치환.
- **C7**: README "Principles Instantiated"에 P17 instantiation 한 줄 추가 (Law 3 compounding substrate).

## Acceptance Criteria

각 AC는 verification 명령 또는 수동 검증 절차를 동반한다.

- **AC1** (LD ID 부여): conducting-interview skill이 종료 시 state.local.md에 `pending_locked_decisions: [...]` 리스트를 produce. drafting-spec Mode A가 이를 읽어 spec.md frontmatter `locked_decisions:`로 변환. **Verification**: 4-round interview fixture (`b/b/d/a` paths)로 통합 테스트 — 결과 spec.md frontmatter에 LD1, LD2, LD3 (b/b/d 답변)만 존재, (a) factual은 부재.
- **AC2** (reviewer 출력 형식): spec-reviewer agent의 출력 schema에 `affects_locked_decisions: [LD ids]` 필드 emit. **Verification**: fixture spec.md (LD1, LD2 포함) + reviewer prompt → output에 issue별 `affects_locked_decisions` 줄 존재. `grep -E '^  affects_locked_decisions:' reviewer-output.md | wc -l` == issue 수.
- **AC3** (routing): reviewing-spec skill이 `needs_revise` verdict 처리 시, 모든 issue의 `affects_locked_decisions == []`이면 자동 [4] Revise; 하나라도 non-empty면 [3.5] Re-consensus. **Verification**: unit test 두 케이스 (all-empty vs mixed) → 분기 결과 확인.
- **AC4** (user options): Re-consensus sub-step의 AskUserQuestion이 LD별로 정확히 3개 옵션 (수용/유지/추가 인터뷰) 노출. **Verification**: AskUserQuestion mock으로 question 객체 검증 — options.length == 3.
- **AC5** (Mode B guard): drafting-spec Mode B가 `allowed_issue_ids`에 없는 issue_id를 적용 시도하면 abort + reviewing-spec에 escalate. **Verification**: SKILL.md에 명시된 contract 위반 시나리오를 fixture로 (`allowed_issue_ids: [I1]`, reviewer issues: `[I1, I2]`) → Mode B는 I1만 적용, I2는 무시 + warning 로그.
- **AC6** (stagnation 분리): `dismissed_by_user >= 1`인 issue는 stagnation count에서 제외. `raised_count >= 3 AND dismissed_by_user == 0`만 P18 trigger. **Verification**: state.local.md fixture 3종 (`raised=3 dismissed=0` → stagnation true / `raised=3 dismissed=1` → false / `raised=3 dismissed=3` → reviewer-persona-warn).
- **AC7** (하위 호환): v0.1.x spec.md (frontmatter에 locked_decisions 없음) 입력 시 reviewing-spec이 empty list로 해석 → 기존 [4] 자동 path. **Verification**: fixture (no locked_decisions key) + reviewer issue → 자동 [4] 분기 확인. backwards-compat regression test.
- **AC8** (kill switch): `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS=1` 설정 시 [3.5] sub-step 우회 + loud warning 출력. **Verification**: env var set + locked-affecting issue → 자동 [4] path + stderr에 warning message.
- **AC9** (re-consensus 무한 루프 방지): 같은 issue_id에 대해 두 번째 re-consensus 게이트 진입 시 [5] forced escalate. **Verification**: state.local.md `reconsensus_count[issue_id] >= 2` 시뮬레이션 → [5] 직행.
- **AC10** (plugin.json bump): v0.1.2 → v0.2.0. CHANGELOG.md 생성 (`## [0.2.0] — 2026-MM-DD` with Added/Changed). **Verification**: `jq -r .version plugins/spec-distill/.claude-plugin/plugin.json` == `0.2.0`; `test -f plugins/spec-distill/CHANGELOG.md`.

## Files to Modify

### 핵심 변경

- `plugins/spec-distill/skills/reviewing-spec/SKILL.md` — routing table에 `affects_locked` column 추가, [3.5] Re-consensus sub-step 섹션 추가, kill switch 항목 추가.
- `plugins/spec-distill/skills/drafting-spec/SKILL.md` — Mode A에 locked_decisions frontmatter 생성 로직 추가; Mode B에 `allowed_issue_ids` 입력 contract 추가.
- `plugins/spec-distill/skills/conducting-interview/SKILL.md` — state.local.md에 `pending_locked_decisions:` produce 명시 ((b)/(d) path만 append).
- `plugins/spec-distill/agents/spec-reviewer.md` — 출력 schema에 `affects_locked_decisions: [LD ids]` 필드 추가, "What to check"에 locked_decisions 매핑 가이드.
- `plugins/spec-distill/templates/spec-template.md` — frontmatter에 `locked_decisions:` 필드 (빈 리스트 기본값) 추가.

### 메타데이터 / 컴플라이언스

- `plugins/spec-distill/.claude-plugin/plugin.json` — version `0.1.2` → `0.2.0`.
- `plugins/spec-distill/CHANGELOG.md` — 신규. `## [0.2.0]` entry with Added (re-consensus gate, locked_decisions frontmatter, AC9 무한 루프 cap, kill switch).
- `plugins/spec-distill/README.md` — "Principles Instantiated"에 P17 explicit instantiation 한 줄; "Flow" 다이어그램에 [3.5] node 추가; "Kill switches"에 `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS` 추가.

### 테스트 / fixtures

- `plugins/spec-distill/tests/fixtures/locked-decisions-spec.md` — 신규. LD1/LD2 포함 spec.md 샘플.
- `plugins/spec-distill/tests/fixtures/reviewer-output-mixed.md` — 신규. issue 일부에 `affects_locked_decisions: [LD1]` 포함.
- `plugins/spec-distill/tests/fixtures/v0.1.x-spec-no-locked.md` — 신규. AC7 backwards-compat 검증용.
- `plugins/spec-distill/tests/routing-test.md` — 신규 또는 기존 확장. AC3, AC6, AC7, AC8, AC9 시나리오.

## Verification Plan

- **V1** (lint): `jq empty plugins/spec-distill/.claude-plugin/plugin.json && jq -r .version plugins/spec-distill/.claude-plugin/plugin.json == 0.2.0`.
- **V2** (template schema): `python3 -c "import yaml; d=yaml.safe_load(open('plugins/spec-distill/templates/spec-template.md').read().split('---')[1]); assert 'locked_decisions' in d"`.
- **V3** (reviewer output): fixture-based — reviewer를 fixture spec에 dispatch, output에 모든 issue가 `affects_locked_decisions:` 필드 가짐을 grep으로 확인.
- **V4** (routing dispatch): reviewing-spec skill 내 routing 분기 로직 unit test (mock reviewer output → 분기 결과 assert).
- **V5** (Mode B guard): drafting-spec Mode B fixture run — `allowed_issue_ids: [I1]`, reviewer output `[I1, I2]` → diff에 I1 관련 변경만 존재, I2 관련 변경 부재.
- **V6** (integration): 4-round interview → draft → reviewer (locked-affecting issue 포함) → re-consensus mock (수용 1개, 유지 1개, 추가 인터뷰 0개) → Mode B → re-review → approve → handoff. 전체 flow E2E 통과.
- **V7** (kill switch): `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS=1` env로 V6 재실행 → [3.5] skip + stderr warning 출력 + 기존 [4] path 동작.
- **V8** (backwards-compat): v0.1.x spec.md (locked_decisions 없음) fixture → reviewing-spec 자동 [4] path → 정상 동작.
- **V9** (README + CHANGELOG): `grep -q "P17" plugins/spec-distill/README.md` && `grep -q "0.2.0" plugins/spec-distill/CHANGELOG.md`.

## Rejected Alternatives

- **R1**: 별도 Phase [3.5] 추가 (별도 SKILL.md 파일). **거절**: P22 cost class 증가 + skill 디스커버리 부담 증가. reviewing-spec 내부 sub-step이 충분하고 가벼움 (LD3).
- **R2**: reviewer 출력 형식 변경 없이 reviewing-spec post-processing이 issue의 `target_section` anchor를 locked_decisions와 매칭. **거절**: section anchor만으로는 어떤 LD가 영향받는지 ambiguous (한 섹션에 여러 LD 가능). reviewer가 직접 출력하는 게 deterministic.
- **R3**: locked_decisions를 spec.md가 아닌 별도 `.claude/spec-distill/<session>/locked.md` 파일. **거절**: spec.md self-contained 원칙 위반. handoff 시 별도 파일 전달 부담. 또한 reviewer가 추가 input을 받게 되면 frontmatter scoping이 복잡해짐.
- **R4**: locked_decisions를 spec.md 본문 (12번째 섹션)으로 추가. **거절**: NG1 위반 (본문 11 섹션 형식 유지). frontmatter는 metadata, 본문은 contract — 분리 유지.
- **R5**: 사용자 옵션 2개 (수용/유지)만, "추가 인터뷰"는 [5] Human Gate에서만. **거절**: 사용자가 합의 변경 필요는 인지했지만 새 정보 필요시 곧장 [1]로 갈 path가 없으면 Human Gate에서 dead-end. 3-옵션이 UX적으로 자연스러움.
- **R6**: numerical scoring으로 "locked-ness 정도" 측정 (예: 0.0-1.0). **거절**: NG4 위반 (philosophy §5.3 — numerical scoring 비추천). boolean으로 충분.
- **R7**: 자동 reviewer persona 학습 (dismissed_by_user 누적 시 reviewer prompt 자동 weakening). **거절**: NG5 위반 — persona 편집은 보안-민감 (CLAUDE.md 명시). 자동 mutation 위험, 사용자에게 알림만.

## Open Questions

- **OQ1**: `pending_locked_decisions` 추출 시점 — conducting-interview의 *매 round 끝*에 append vs. *phase 1 종료 시* 한 번에 batch? **잠정 결정 (drafting-spec Mode A에서 확정)**: 매 round 끝 append (state.local.md transcript와 동기화). 다만 (c) sub-agent ambiguity path는 사용자 confirm까지 도달한 경우만 locked. 미확인.
- **OQ2**: spec.md frontmatter `locked_decisions:` 의 `summary` 필드 길이 제한 — 1줄 (80 char)? 다줄 허용? **잠정**: 1줄 (P21 secret 치환과 grep 검증 단순화). 향후 길어지면 별도 `details:` 필드 추가 검토.
- **OQ3**: Re-consensus AskUserQuestion이 한 번에 노출할 LD 수 — 1개? 전체 묶음? AskUserQuestion 최대 4개 questions/select. **잠정**: 한 round당 최대 3개 LD까지 묶음 (4번째 question은 escalation summary로 reserve). 3개 초과면 [5] forced escalate.
- **OQ4**: dismissed_by_user 카운터가 *세션 간*에 persistent한가, 세션 한정인가? state.local.md는 세션 한정 → 새 세션엔 reset. **잠정**: 세션 한정 (현재 spec-distill state 모델 유지). cross-session learning은 별도 spec (v0.3.0+).
- **OQ5**: `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS=1` 사용 시 로그 외에 README의 어디에 표기할지 — Kill switches 섹션 하단에 "loud warning" 명시. **잠정 결정됨**.

## Concrete Next Action

**다음 명령** (사용자가 design 검토 후):

```
Skill superpowers:writing-plans docs/superpowers/specs/2026-05-13-spec-distill-reconsensus-design.md
```

writing-plans skill이 위 11 섹션을 input으로 받아 *implementation plan* (체크박스 단위 task breakdown)을 생성. plan 산출 경로: `docs/superpowers/plans/2026-05-13-spec-distill-reconsensus-plan.md`.

Plan 단계 이후:
1. Plan 검토 (사용자) → 수정 round → approve.
2. Implementation (별도 세션 권장 — quality-gates 파이프라인 활용).
3. Gate 1 (plan-verifier) + Gate 2 (PR 리뷰) + Gate 3 (runtime verify) 통과.
4. PR merge → spec-distill v0.2.0 release.
