---
name: spec-distill-handoff-idempotency
version: 1.0.0
created_at: 2026-05-27
session_id: brainstorming-2026-05-27-handoff-idempotency
status: locked
next_phase: writing-plans
source: brainstorming-round-1
locked_decisions:
  - id: LD1
    summary: "Scope는 brainstorming 측 가이드 + spec-distill 측 idempotent handoff 둘 다."
    rationale: "사용자 명시 응답 (AskUserQuestion Section 0). 한쪽만 고쳐서는 seam이 남는다."
  - id: LD2
    summary: "compact는 사용자에게 위임하되 Stop hook이 unmissable하게 SystemMessage로 유도."
    rationale: "사용자 명시 응답 (AskUserQuestion Section 0). 모델은 slash command 직접 실행 불가 — Claude Code 본질적 제약."
  - id: LD3
    summary: "Approach B (Ouroboros handoff_contract.py 패턴 instantiation) 선택."
    rationale: "사용자 명시 응답. devbrew design lightness 원칙(memory) 준수 + 검증된 reference 차용."
  - id: LD4
    summary: "approve_handoff.sh에서 git commit 단계 완전 제거. spec은 사용자 책임."
    rationale: "사용자 직접 지시 (원 요청 #1: '커밋은 빼자'). 실사용에서 사용자가 이미 commit한 상태가 다수."
  - id: LD5
    summary: ".handoff-emitted marker는 session 디렉토리 밖 (.claude/spec-distill/.markers/<sid>.emitted)."
    rationale: "session cleanup과 marker 수명을 분리. SessionEnd hook이 session 디렉토리를 삭제해도 Stop hook이 marker 감지 가능해야 함."
---

# spec-distill handoff idempotency + compact induction

> *명세는 잠긴 뒤에야 compounding된다 — 잠긴 명세를 다음 단계로 넘기는 seam이 깨지면 Law 3의 substrate가 새어나간다.*

## Goal

`approve_handoff.sh`를 idempotent state machine으로 재설계해 (a) 이미 commit된 spec 재진입을 정상 처리하고, (b) handoff packet emit 이후 사용자가 `/compact`를 실행할 때까지 Stop hook이 unmissable SystemMessage로 유도하도록 한다.

## Handoff Context

**TL;DR**:
- `approve_handoff.sh`가 더 이상 `git commit`을 직접 수행하지 않고, working tree clean + HEAD에 spec 존재를 *조건*으로 handoff packet emit한다.
- 신규 Stop hook + UserPromptSubmit hook 쌍이 marker 기반으로 `/compact` 명령을 사용자가 실행할 때까지 SystemMessage를 inject한다.

**Implicit context** (Constraints에 없지만 진행에 필요):
- Claude Code의 slash command (`/compact`, `/help` 등)는 본질적으로 *사용자 입력*이며 모델은 직접 실행 불가. SystemMessage로 induce는 가능하지만 실행 자체는 사용자.
- `brainstorming` skill은 upstream superpowers cache에 위치 (`~/.claude/plugins/cache/claude-plugins-official/superpowers/5.1.0/`). devbrew는 직접 편집 불가, CLAUDE.md guidance와 hook으로만 영향 가능.
- spec-distill v0.8.0부터 review hook은 `docs/superpowers/specs/` 아래 모든 `.md`에 발화 — brainstorming의 `*-design.md` 산출물도 hook 대상.
- 현행 v0.9.0 `approve_handoff.sh`는 Step 1에서 `git add` + `git commit` → "이미 committed" 또는 "변경 없음" 상황에서 `nothing to commit` 에러로 exit 1, 사용자 작업 차단.

**Deferred to plan**:
- Stop hook fire 카운트 임계치(5회 후 stagnation cleanup)의 구체 implementation — plan에서 결정.
- `compact-detect.py`의 `/compact` prefix 매칭 정확한 regex — plan에서 edge case 수집 후 결정.
- 기존 `.handoff-status` 파일 schema 정확한 YAML 또는 plaintext 형식 — plan에서 결정.

## Context / Why

사용자 보고 (2026-05-27 brainstorming):

> spec-distill에서 review compact plan으로 넘어가게 하는 스크립트가 잘 동작하지 않으며 현실적이지 않음
> 1. 커밋을 진행하려는 시점에 이미 커밋을 한 경우가 많아서 실패를 만들게 됨 (커밋은 빼자)
> 2. compact를 진행하게 유도하지 못함

현행 `approve_handoff.sh` v0.9.0 분석:
- Step 1 `git add` + `git commit`은 사용자가 자체적으로 commit한 일반적 케이스에서 `nothing to commit` → exit 1로 사용자 작업 차단.
- Step 2 handoff packet은 stdout 출력에 그침. 모델은 narrate만 하고 `/compact`를 실제로 induce하지 못함 — AP2 "polite stop"의 정확한 instantiation.

devbrew 철학상 의미:
- **Law 1 (Clarity Before Code)**: spec lock 직후 다음 phase 진입을 막는 결함은 spec lifecycle의 1급 결함 — clarity가 코드(plan)에 도달하지 못하면 law가 무력화.
- **Law 2 (Writer ≠ Reviewer)**: 현행 commit collision은 *reviewer-side* 인프라가 *writer-side*의 작업(commit)을 대체하려는 책임 침범 — separation of duties 위반.
- **Law 3 (Compounding)**: handoff seam이 매번 사용자 수동 개입을 요구하면 next-cycle agent가 spec lifecycle을 reliable한 substrate로 활용 못함.

## Goals

- **G1**: `approve_handoff.sh`가 commit 책임을 갖지 않고, spec working tree clean + HEAD에 존재 조건만 검증. 이미 committed 상태에서 정상 dedupe (Ouroboros invariant #1).
- **G2**: dirty/uncommitted 상태는 *user-fixable* 에러로 명확히 분류하고, copy-pasteable git 명령을 advisory에 표시. 자동 commit 시도 없음.
- **G3**: handoff packet emit 후 `/compact` 실행까지 Stop hook이 unmissable SystemMessage inject (additionalContext). polite-stop AP2 발화를 봉쇄.
- **G4**: `/compact` 또는 `Skill superpowers:writing-plans` 입력 감지 시 UserPromptSubmit hook이 marker 즉시 삭제 — Stop hook 무한 fire 차단.
- **G5**: Stop hook이 5회 이상 fire되도 marker가 남아있으면 자동 cleanup + loud advisory — stagnation escape (P18 stagnation detection pattern).
- **G6**: 변경된 `approve_handoff.sh`가 crash/resume safe — 같은 `session_id`로 재진입 시 marker 기반 dedupe (Ouroboros invariant #3).

## Non-goals

- **NG1**: brainstorming skill 자체를 편집하지 않는다 (upstream cache, devbrew unowned). CLAUDE.md 한 줄 가이드만 추가.
- **NG2**: 모델이 `/compact`를 자동 실행하게 만들지 않는다 — Claude Code 본질적 제약. 사용자 입력 induce만 한다.
- **NG3**: spec mode (interview 산출물) handoff 동작 변경하지 않는다. 본 spec은 design mode handoff와 spec mode handoff 모두에 적용되지만 동작 변경은 *commit 제거 + idempotency + compact induction*에 한정.
- **NG4**: 신규 P# (devbrew 철학 원칙) 추가하지 않는다 (memory feedback: "design lightness, default" — 기존 인프라 instantiation으로 충분).
- **NG5**: 기존 v0.9.0 spec 파일에 대한 grandfather migration 처리 안 함 — 기존 `.handoff-status` marker 없으면 첫 실행 시 정상 생성.

## Constraints

- **C1**: 변경되는 모든 파일은 `plugins/spec-distill/`와 devbrew root `CLAUDE.md` 한 줄 외부로 spillover하지 않는다.
- **C2**: 두 신규 hook은 `DEVBREW_DISABLE_SPEC_DISTILL=1` 및 `DEVBREW_SKIP_HOOKS=spec-distill:<hook>` 형식 kill switch를 모두 존중한다 (CLAUDE.md "kill switch는 보안 컨트롤").
- **C3**: spec-distill `plugin.json` version은 `0.9.0` → `0.10.0` (minor bump: 신규 surface 2개 hook + idempotent contract). CHANGELOG.md에 0.10.0 entry 추가.
- **C4**: 신규 marker 디렉토리 `.claude/spec-distill/.markers/`는 SessionEnd hook 또는 TTL-GC에서 24h 이상 stale marker 자동 정리한다 (v0.6.0 GC 패턴 재사용).
- **C5**: `.handoff-status` 파일은 일반 텍스트 또는 단순 key=value 형식 — secret 기록 금지 (CLAUDE.md P21).
- **C6**: README.md "Principles Instantiated" 섹션에 "Ouroboros handoff_contract.py replay-safety/named-status/dedupe instantiation" 추가 (Law 3: 미래 검색 discoverability).

## Acceptance Criteria

- **AC1**: spec 파일이 working tree clean이고 HEAD에 존재할 때 `approve_handoff.sh <sid> <path>` 호출 → exit 0, stdout에 v0.9.0 동일 형식 3-block handoff packet, `.claude/spec-distill/.markers/<sid>.emitted` marker 파일 생성, `.handoff-status` 파일에 `STATUS=already_handed_off` 기록.
- **AC2**: spec 파일이 uncommitted 또는 dirty인 상태에서 호출 → exit 1, stderr에 advisory (현재 `git status` 결과 spec 관련 + 정확한 `git add` + `git commit` 명령 string), marker 미생성, state.local.md 보존.
- **AC3**: 같은 `session_id`로 두 번 호출 → 두 번째도 exit 0, marker 보존 (touch 갱신만), packet 재emit, `STATUS=already_handed_off` 유지 (Ouroboros invariant #1 dedupe).
- **AC4**: marker 존재 상태에서 Stop hook fire → stdout(Claude Code hook protocol)에 additionalContext JSON으로 `/compact` 명령 verbatim + writing-plans 안내 emit. marker 부재 시 no-op + exit 0.
- **AC5**: UserPromptSubmit event payload `user_message`가 `/compact` prefix로 시작 또는 `Skill superpowers:writing-plans` 포함 → marker 파일 삭제, stderr 1줄 loud advisory.
- **AC6**: 같은 marker에 대해 Stop hook이 5회 fire되어도 marker 살아있으면 marker 자동 삭제 + stderr advisory `[spec-distill] compact-induction stagnation: 5 fires without /compact — manual confirmation required`.
- **AC7**: `DEVBREW_DISABLE_SPEC_DISTILL=1` 환경에서 모든 신규 hook + approve_handoff.sh가 즉시 exit 0, marker 생성/삭제 모두 skip.
- **AC8**: `DEVBREW_SKIP_HOOKS=spec-distill:compact-induction` 환경에서 compact-induction hook은 즉시 exit 0, compact-detect와 approve_handoff.sh는 정상 동작.
- **AC9**: `plugin.json` version이 `0.10.0`이고 CHANGELOG.md에 `## [0.10.0] — 2026-05-27` entry 존재 (Added/Changed/Notes 섹션 포함).
- **AC10**: 기존 `tests/test_approve_handoff.sh` Case 1, 5, 7이 신규 AC1, AC2, AC3 의미로 재작성되어 통과. 신규 4개 test (`test_handoff_status_named.sh`, `test_compact_induction_hook.sh`, `test_compact_detect_hook.sh`, `test_compact_induction_stagnation.sh`) 모두 통과.

## Files to Modify

```
수정:
plugins/spec-distill/scripts/approve_handoff.sh
  — commit 단계 제거. Ouroboros 패턴 named-status 상수 헤더 + idempotent state 판정 + marker write.

plugins/spec-distill/tests/test_approve_handoff.sh
  — Case 1 (happy path), Case 5 (commit fail), Case 7 (idempotent re-run)을 AC1/AC2/AC3 의미로 재작성.

plugins/spec-distill/hooks/hooks.json
  — Stop event에 compact-induction.py 등록. UserPromptSubmit event에 compact-detect.py 등록.

plugins/spec-distill/.claude-plugin/plugin.json
  — version `0.9.0` → `0.10.0`.

plugins/spec-distill/CHANGELOG.md
  — `## [0.10.0] — 2026-05-27` entry 추가 (Added/Changed/Notes).

plugins/spec-distill/README.md
  — Hooks Installed 표에 compact-induction/compact-detect 2행 추가. Principles Instantiated 섹션에 Ouroboros handoff_contract.py 인용 한 줄.

plugins/spec-distill/skills/reviewing-spec/SKILL.md
  — "Approve handoff sequence (AC11)" 절의 "4-step" 표현을 신규 step 수에 맞춰 갱신. 실패 시 state 보존 절은 "dirty_blocked 상태" 명시.

CLAUDE.md (devbrew root)
  — "Plugin Shape" 또는 "Forbidden Patterns" 인접 위치에 brainstorming → spec-distill handoff 1줄 가이드 추가.

신규:
plugins/spec-distill/hooks/compact-induction.py
  — Stop event hook. marker 감지 → additionalContext SystemMessage emit. 5회 fire 후 self-cleanup.

plugins/spec-distill/hooks/compact-detect.py
  — UserPromptSubmit event hook. /compact 또는 Skill 호출 감지 → marker 삭제.

plugins/spec-distill/tests/test_handoff_status_named.sh
  — Named-status 상수가 export되고 STATUS 값이 named string인지 검증.

plugins/spec-distill/tests/test_compact_induction_hook.sh
  — marker 존재/부재 별 Stop hook 동작 검증.

plugins/spec-distill/tests/test_compact_detect_hook.sh
  — UserPromptSubmit /compact prefix 감지 + marker 삭제 검증.

plugins/spec-distill/tests/test_compact_induction_stagnation.sh
  — 5회 fire 후 self-cleanup + advisory 검증.
```

## Verification Plan

- **V1 — approve_handoff happy path**: `bash plugins/spec-distill/tests/test_approve_handoff.sh` (재작성된 Case 1-8 모두 PASS). 실행 결과의 stdout이 `===== spec-distill handoff packet =====`로 시작해야 한다.
- **V2 — named-status invariant**: `bash plugins/spec-distill/tests/test_handoff_status_named.sh` 통과. grep으로 `approve_handoff.sh` 안에 `readonly HANDOFF_STATUS_*` 3개 상수 존재 검증.
- **V3 — compact-induction Stop hook**: `bash plugins/spec-distill/tests/test_compact_induction_hook.sh` 통과. marker 존재 시 hook stdout JSON에 `additionalContext` 필드 존재, marker 부재 시 빈 stdout.
- **V4 — compact-detect UserPromptSubmit hook**: `bash plugins/spec-distill/tests/test_compact_detect_hook.sh` 통과. `/compact` prefix 입력 시 marker 삭제 확인, 일반 prompt 시 marker 보존.
- **V5 — stagnation escape**: `bash plugins/spec-distill/tests/test_compact_induction_stagnation.sh` 통과. 5회 fire 후 marker 부재 + stderr에 `stagnation` 키워드 advisory.
- **V6 — kill switch**: 환경변수 `DEVBREW_DISABLE_SPEC_DISTILL=1` 설정 후 V1-V5 모두 즉시 exit 0 (no-op).
- **V7 — version bump**: `jq -r .version plugins/spec-distill/.claude-plugin/plugin.json` 출력이 `0.10.0`이고, CHANGELOG.md 최상단 entry가 `## [0.10.0] — 2026-05-27`.
- **V8 — full plugin test suite**: `bash plugins/spec-distill/tests/run_all.sh` (또는 individual test 모두) PASS.
- **V9 — manual end-to-end**: brainstorming으로 임의 design.md 작성 + commit → spec-distill review-dispatch → reviewing-spec approve → approve_handoff.sh emit packet → Stop hook이 한 번 더 SystemMessage emit → `/compact` 입력 → marker 삭제 → fresh context로 writing-plans 진입. 전체 흐름이 인간 개입 없이 packet emit ~ /compact prompting까지 자동.

## Rejected Alternatives

- **R1 — Approach A (Minimal commit 제거)**: commit 제거만 하고 idempotency contract 부재. crash/resume 시 marker 충돌 가능 (G6 미달성). Ouroboros 패턴의 검증된 design을 활용 안 함. devbrew "design lightness"는 만족하지만 crash-safety + discoverability에서 Approach B에 열등.
- **R2 — Approach C (풀 리아키텍처 — bridging-design-to-plan skill)**: 신규 skill 추가, PR 3~4개 분할 필요. devbrew "design lightness" 원칙(memory)과 충돌. YAGNI 위반 가능성 — 현행 seam 결함이 명확한데 새 추상화 도입은 과잉.
- **R3 — 자동 `/compact` 트리거**: Claude Code 본질적 제약 (모델은 slash command 직접 실행 불가). 가능한 우회 (예: PreCompact hook으로 임의 시점 trigger)는 사용자 의도 무시 → autonomy 위반 (AP "unbounded autonomy" 인접).
- **R4 — subagent dispatch로 compact 우회**: `writing-plans`을 Agent({subagent_type: "general-purpose"})로 dispatch하면 fresh context 확보 가능. 그러나 (a) `writing-plans` skill 자체가 subagent context에서 정상 동작하는지 미검증, (b) 사용자가 plan을 main context에서 보기 원하는 경우 작업 흐름 끊김, (c) brainstorming skill의 "Invoke writing-plans skill" 지시와 정렬되지 않음.
- **R5 — approve_handoff.sh를 폐기하고 Stop hook이 모든 책임 흡수**: hook이 너무 무거워지고 (`Approve 의도 감지 → status 판정 → packet emit → marker 작성` 모두 한 hook) testability 저하. 현행 explicit script + light hook 분리가 더 명료.

## Open Questions

- **OQ1**: Stop hook이 SystemMessage를 emit할 때 `additionalContext` 필드의 정확한 JSON schema — Claude Code의 hook protocol 문서 또는 superpowers/oh-my-codex의 기존 hook 구현 참조 필요. (Plan 단계에서 reference 확인 후 결정.)
- **OQ2**: `compact-detect.py`의 `/compact` prefix 매칭이 leading whitespace, fullwidth slash 등 edge case를 어떻게 다룰지 — plan에서 spec.

## Concrete Next Action

다음 단계: `Skill superpowers:writing-plans`.
- Spec 경로: `docs/superpowers/specs/2026-05-27-spec-distill-handoff-idempotency-design.md`
- Plan 산출물 예상 경로: `docs/superpowers/plans/2026-05-27-spec-distill-handoff-idempotency.md`
- 호출 명령: `Skill superpowers:writing-plans docs/superpowers/specs/2026-05-27-spec-distill-handoff-idempotency-design.md`
