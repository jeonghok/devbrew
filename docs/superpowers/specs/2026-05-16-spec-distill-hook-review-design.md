---
name: spec-distill-hook-review
version: 1.0.0
created_at: 2026-05-16
status: design
source: brainstorming session 2026-05-16
next_phase: writing-plans
session_id: brainstorm-2026-05-16-spec-distill-hook-review
locked_decisions:
  - id: LD1
    section: "#goals"
    summary: 'Hook은 spec-distill 플러그인 안에 PostToolUse + Stop 두 이벤트로 확장. 신규 플러그인 분리 안 함. (G1)'
    source: brainstorming-round-1
  - id: LD2
    section: "#goals"
    summary: '결정론을 2-layer로 분리. Layer 1(structural) = hook script, Layer 2(adversarial) = spec-reviewer agent를 Stop hook이 강제 dispatch. (G2)'
    source: brainstorming-round-1
  - id: LD3
    section: "#goals"
    summary: 'PostToolUse matcher = `Write|Edit`, 경로 패턴 = `docs/superpowers/specs/**-{spec,design}.md`. 두 파일명 suffix로 spec/design 모드 분기. (G3)'
    source: brainstorming-round-1
  - id: LD4
    section: "#goals"
    summary: 'brainstorming(upstream)은 코드 수정 없음 — `-design.md` 작성 시점에 hook이 file system level에서 가로채는 방식으로만 통합. (G4)'
    source: brainstorming-round-1
  - id: LD5
    section: "#goals"
    summary: 'reviewing-spec skill의 routing table (verdict×signal→next phase, P1–P4, [3.5] re-consensus)은 *무수정 보존*. SKILL.md 본문 중 Step 1 (trigger 메커니즘 설명)만 갱신. (G5)'
    source: brainstorming-round-1
  - id: LD6
    section: "#non-goals"
    summary: 'spec-reviewer agent persona 무수정. 결정론 강화는 hook layer에서만. (NG1)'
    source: brainstorming-round-1
  - id: LD7
    section: "#non-goals"
    summary: 'design mode에서도 11-section schema는 강제하지 않음. brainstorming의 design.md 포맷 자유도 유지. (NG2)'
    source: brainstorming-round-1
  - id: LD8
    section: "#constraints"
    summary: 'PostToolUse exit 2의 stderr 주입을 차단 메커니즘으로 활용. Anthropic hook 명세상 LLM이 무시 불가. (C2)'
    source: brainstorming-round-1
---

# spec-distill Hook-Driven Deterministic Review (v0.3.0)

> **Writer가 spec/design 파일을 쓰는 순간 reviewer가 turn boundary에서 강제로 dispatch된다. Trigger도 dispatch도 LLM 의지에서 분리해 결정론으로 끌어내린다.**

## Goal

spec/design 문서 작성을 detect한 hook이 *그 turn 안에서* structural validation을 차단성 게이트로 강제하고, *다음 turn boundary*에서 spec-reviewer agent dispatch를 강제하여, spec-distill과 brainstorming 두 워크플로우 모두에 동일한 결정론적 review 파이프라인을 적용한다.

## Context / Why

**현재 상태의 gap**: spec-distill의 `reviewing-spec` skill은 verdict×signal→next phase의 routing table은 결정론적이지만, *agent dispatch 자체는 LLM이 skill instruction을 따라야 발동*된다. 즉 "routing은 결정론, trigger는 비결정론". brainstorming은 LLM이 자기가 작성한 design.md를 자기가 inline self-review — Law 2 (Writer ≠ Reviewer)의 회색지대.

**병목**: 모델이 아니라 review 게이트의 *발동 메커니즘*. spec/design 문서의 약점은 LLM이 "지나가도 되겠지"라고 판단할 때 통과한다.

**해결**: file-write를 trigger로, turn boundary를 dispatch 강제 지점으로 사용. quality-gates가 Stop hook으로 게이트 진행을 controlling하는 검증된 패턴을 spec review에 적용.

## Goals

- **G1**: spec-distill 플러그인 안에 PostToolUse + Stop 두 hook 추가 — 신규 플러그인 분리 없이 확장.
- **G2**: 2-layer 결정론 구조. Layer 1 (structural, script-only, 무료) = mechanical schema/keyword 검증. Layer 2 (adversarial, agent dispatch) = spec-reviewer를 Stop hook의 systemMessage 주입으로 mandatory dispatch.
- **G3**: PostToolUse matcher `Write|Edit`, 경로 매칭 `docs/superpowers/specs/**-{spec,design}.md`. 파일명 suffix로 spec/design 모드 분기.
- **G4**: brainstorming(upstream)을 무수정으로 통합. brainstorming이 `-design.md`를 쓰는 그 순간 hook이 file system level에서 캐치 → 동일 reviewer 파이프라인.
- **G5**: reviewing-spec skill의 *routing table* (verdict×stagnation×rereview_count→next phase, P1–P4 escalation priority, [3.5] re-consensus gate 등)은 무수정 보존. SKILL.md 본문 중 Step 1만 갱신 (state.local.md `pending_review:` 플래그를 trigger source로 명시) — routing 로직은 그대로.
- **G6**: 모든 신규 hook은 kill switch 존중 (`DEVBREW_DISABLE_SPEC_DISTILL=1`, `DEVBREW_SKIP_HOOKS=spec-distill:<event>`, `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`, `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1`).

## Non-goals

- **NG1**: spec-reviewer agent persona 무수정. 결정론 강화는 hook layer에서만 발생. persona 약화 시도는 보안 리뷰 대상 (CLAUDE.md §Plugin Shape).
- **NG2**: design mode에서 11-section schema는 강제 안 함 — brainstorming의 design.md 포맷 자유도 유지. design mode는 ambiguity + TBD/TODO/placeholder 검출만.
- **NG3**: 신규 review-gate 플러그인 분리하지 않음 (현 단계). spec/design doc review라는 단일 책임이 spec-distill 안에서 자연스러움.
- **NG4**: spec-distill의 기존 UserPromptSubmit/SessionStart hook 동작 변경 없음.
- **NG5**: 사용자가 명시적으로 dismiss한 issue (`dismissed_by_user >= 1`)에 대해 reviewer가 같은 issue를 재제기해도 hook은 별도로 차단하지 않음. 기존 reviewing-spec의 P3/P4 priority table이 처리.
- **NG6**: hook이 spec.md 본문을 직접 수정하는 일은 없음 (Law 2 — Writer 권한은 LLM의 Write tool에만). hook은 exit code + systemMessage + state.local.md 갱신만.

## Constraints

- **C1**: hook script는 5–10s timeout 안에 종료. structural validator는 Python으로 작성 (정규식 기반 파싱), agent dispatch는 systemMessage emit으로 즉시 종료 — 실제 LLM 호출은 다음 turn에서 발생.
- **C2**: PostToolUse exit 2 시 stderr가 Claude tool result에 "blocked"로 표시됨. 이 메커니즘에 의존 — Anthropic hook spec 변경 시 회귀 가능성. fallback으로 stdout `{"decision": "block"}` JSON 출력도 병행 (이중 안전).
- **C3**: state.local.md는 spec-distill 기존 ledger와 같은 파일을 공유. 신규 필드 `pending_review:` / `last_validated_at:` / `validator_findings:`를 추가 (in-flight migration 패턴, drafting-spec C10과 동일 방식).
- **C4**: hook이 fire하더라도 `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1` 설정 시 Layer 1만 동작하고 Layer 2 (dispatch) skip. 비상시 reviewer cost 회피.
- **C5**: ambiguity blacklist는 hardcoded list가 아니라 `plugins/spec-distill/scripts/ambiguity-blacklist.txt`에 별도 — 사용자 escape syntax (`~` prefix) 지원, false positive 발생 시 PR로 단어 추가/제거.
- **C6**: 다른 plugin의 PostToolUse hook과 공존. signal tag는 `<spec-distill-signal>` 네임스페이스 (CLAUDE.md "Signal tag namespace" 요건).

## Acceptance Criteria

- **AC1**: `docs/superpowers/specs/2026-05-16-test-spec.md`에 11 sections + valid frontmatter 가진 spec을 작성하면 PostToolUse hook이 exit 0 + stdout에 `<spec-distill-signal>review_required` 토큰 포함. 검증: `bash plugins/spec-distill/tests/test_spec_write_validator.sh` 의 case #1.
- **AC2**: 같은 spec에서 "Goals" 섹션 제거 시 PostToolUse hook이 exit 2 + stderr가 substring `missing sections:` 와 substring `#goals` 둘 다 포함 (regex: `missing sections:.*#goals`). tool result에 "blocked" 표시 확인. 검증: case #2.
- **AC3**: spec 본문에 `AC1: system works correctly` 줄 (가령 12번째 줄) 포함 시 hook이 exit 2 + stderr가 substring `ambiguity hit:`, 실제 줄 번호 (예: `line 12`), 그리고 키워드 `works correctly` 셋 다 포함. 검증: case #3 (실제 line number는 fixture에 hardcoded).
- **AC4**: 같은 줄을 `AC1: system ~works correctly` (escape prefix)로 작성 시 exit 0. 검증: case #4.
- **AC5**: `docs/superpowers/specs/2026-05-16-test-design.md` (suffix `-design.md`) 작성 시 frontmatter 없어도 exit 0. ambiguity scan은 적용. 검증: case #6.
- **AC6**: design.md에 `## Goals\n\nTBD` 포함 시 exit 2 + stderr에 `placeholder hit: TBD at line N`. 검증: case #7.
- **AC7**: Stop hook을 mock transcript (`<spec-distill-signal>review_required` 포함)에 대해 실행 시 stdout `{"systemMessage": "MANDATORY: 다음 turn 첫 액션으로 reviewing-spec skill 호출..."}`. 검증: `bash plugins/spec-distill/tests/test_review_dispatch.sh` 의 case #1.
- **AC8**: Stop hook이 signal 없는 transcript에 대해선 silent exit 0. 검증: case #2.
- **AC9**: `DEVBREW_DISABLE_SPEC_DISTILL=1` 환경에서 validator hook은 모든 입력에 대해 silent exit 0, signal 미emit. 검증: case #8.
- **AC10**: `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1` 환경에서 valid spec 작성 시 Layer 1은 정상 동작 (structural check), Layer 2 signal 미emit. 검증: case #9.
- **AC11**: `docs/README.md`처럼 spec/design 경로 외 파일 Write/Edit 시 hook이 silent exit 0 (matcher가 우회). 검증: case #11.
- **AC12**: `plugin.json` 버전이 `0.3.0`. 검증: `jq -r '.version' plugins/spec-distill/.claude-plugin/plugin.json`.
- **AC13**: `CHANGELOG.md`에 `## [0.3.0]` 섹션 존재하고 Added(spec-write-validator hook, review-dispatch hook, design.md coverage) / Changed(reviewing-spec dispatch trigger) 항목 명시. 검증: `grep -E '^## \[0\.3\.0\]' plugins/spec-distill/CHANGELOG.md`.
- **AC14**: 기존 `tests/test_hooks.sh` (interview-trigger + session-anchor regression)가 모두 그대로 통과 — 신규 hook이 기존 hook과 충돌하지 않음. 검증: 전체 run의 exit code 0.

## Files to Modify

**신규 (4)**:
- `plugins/spec-distill/hooks/spec-write-validator.py` — PostToolUse Layer 1 validator.
- `plugins/spec-distill/hooks/review-dispatch.py` — Stop hook, transcript scan + systemMessage 주입.
- `plugins/spec-distill/scripts/parse-spec-structure.py` — validator가 import하는 라이브러리 (11 section / frontmatter / locked_decisions schema parser, ambiguity scanner, escape handler).
- `plugins/spec-distill/scripts/ambiguity-blacklist.txt` — 측정 불가 키워드 리스트 (`works correctly`, `fast`, `good UX`, `as needed`, `properly`, `efficient`, `seamless`, `robust` 등; 한 줄당 한 패턴, `#`로 주석).

**수정 (5)**:
- `plugins/spec-distill/hooks/hooks.json` — PostToolUse + Stop event 추가, matcher `Write|Edit`, timeout 10s.
- `plugins/spec-distill/skills/reviewing-spec/SKILL.md` — Step 1 수정 ("state.local.md `pending_review:` 플래그 검증"), 신규 trigger 메커니즘 명시.
- `plugins/spec-distill/skills/drafting-spec/SKILL.md` — Mode A/B 종료 부분의 *"reviewing-spec 호출"*을 *"hook이 자동 발동 — 별도 호출 불필요"*로 변경.
- `plugins/spec-distill/.claude-plugin/plugin.json` — version `0.2.0` → `0.3.0`.
- `plugins/spec-distill/CHANGELOG.md` — `## [0.3.0] — 2026-05-16` 섹션 추가.
- `plugins/spec-distill/README.md` — "Hooks Installed" 표에 PostToolUse + Stop 추가, 각각 "왜 skill이 아닌가" 한 줄 justification. "Principles Instantiated"에 Law 2 강화 명시.

**테스트 (2)**:
- `plugins/spec-distill/tests/test_spec_write_validator.sh` — 신규, AC1–AC6 + AC9–AC11 케이스.
- `plugins/spec-distill/tests/test_review_dispatch.sh` — 신규, AC7–AC8.

## Verification Plan

- **V1** (AC1–AC6, AC9–AC11): `bash plugins/spec-distill/tests/test_spec_write_validator.sh` — exit 0 expected.
- **V2** (AC7–AC8): `bash plugins/spec-distill/tests/test_review_dispatch.sh` — exit 0 expected.
- **V3** (AC14): `bash plugins/spec-distill/tests/test_hooks.sh` — exit 0 expected (기존 regression).
- **V4** (AC12): `jq -r '.version' plugins/spec-distill/.claude-plugin/plugin.json` — output `"0.3.0"`.
- **V5** (AC13): `grep -E '^## \[0\.3\.0\]' plugins/spec-distill/CHANGELOG.md` — 1+ matches.
- **V6** (hooks.json validity): `jq . plugins/spec-distill/hooks/hooks.json > /dev/null` — exit 0.
- **V7** (kill switch 회귀): `DEVBREW_DISABLE_SPEC_DISTILL=1 bash plugins/spec-distill/tests/test_spec_write_validator.sh` — 모든 case exit 0 (silent).
- **V8** (E2E manual, post-merge): spec-distill `/interview` 한 사이클 돌려서 spec.md 작성 → reviewer dispatch 강제 발동 확인 → 기존 routing 정상 동작.
- **V9** (E2E manual, brainstorming): superpowers brainstorming 한 세션 돌려서 `-design.md` 작성 → reviewer agent가 강제 dispatch 되는지 확인.

## Rejected Alternatives

- **R1 — 신규 review-gate 플러그인 분리**: 두 워크플로우 횡단하는 design-doc reviewer를 별도 플러그인으로. *거절 이유*: 현재 spec/design doc review라는 단일 책임이 spec-distill의 책임 범위 안에 자연스럽게 포함됨. 분리 시 spec-distill ↔ review-gate 의존성 관리 비용 + 두 플러그인 모두 SemVer bump 필요. 미래에 *다른 doc 종류 reviewer*가 추가되면 그 시점에 추출 (YAGNI).
- **R2 — 양쪽 플러그인에 각각 hook (분산)**: spec-distill에 hook + devbrew 루트의 settings.json에 brainstorming용 hook 따로. *거절 이유*: 코드 중복 + devbrew의 "plugin-shape 일관성" (CLAUDE.md) 깨짐.
- **R3 — Pure agent dispatcher hook (Layer 1 없음)**: hook은 단순히 reviewer dispatch만 요청, structural check는 reviewer가 처리. *거절 이유*: structural check는 mechanical하고 무료 — agent dispatch (cost_class medium) 이전에 cheap layer에서 잡는 것이 layered defense + cost-aware. 또한 structural fail은 즉시 차단(exit 2) 가능하므로 reviewer dispatch round 1회 절약.
- **R4 — Full script review (LLM-free)**: structural + adversarial을 모두 grep-based로 처리. *거절 이유*: unstated assumption, scope creep, locked-decision conflict 같은 진짜 adversarial 분석은 LLM 필요. spec-reviewer agent의 핵심 가치 폐기.
- **R5 — PostToolUse 대신 Stop hook 단독**: 모든 처리를 turn 종료 시 일괄 처리. *거절 이유*: structural fail이 *해당 turn 안*에 차단되지 못함 — writer가 잘못된 spec을 쓰고 다음 작업까지 진행한 뒤 차단. 즉시성 손실.

## Open Questions

- **Q1** (deferred to plan phase): ambiguity-blacklist.txt의 초기 단어 셋은 약 10개로 시작 (`works correctly`, `fast`, `good UX`, `as needed`, `properly`, `efficient`, `seamless`, `robust`, `easy to use`, `intuitive`)? 정확한 목록은 plan 단계 + 첫 실사용 후 PR로 다듬기.
- **Q2** (deferred to plan phase): `<spec-distill-signal>` 토큰의 정확한 stdout 위치 — `additionalContext` 필드 vs `systemMessage` 필드. quality-gates의 신호 emission 패턴 (`<qg-signal>`)을 그대로 따를 예정이지만 hook output schema의 최신 spec 재확인 필요.
- **Q3** (deferred): brainstorming의 `-design.md`가 frontmatter를 가질 경우의 처리 — 현 design은 "suffix 기준 분기"이지만 미래에 frontmatter `mode: spec`/`mode: design`을 명시 옵션으로 추가할 수 있음. v0.3.0에서는 suffix만, v0.4.0+에서 검토.

## Concrete Next Action

1. **승인**: 사용자가 본 spec을 검토하고 변경 사항 요청 또는 승인.
2. **Plan phase**: `Skill superpowers:writing-plans docs/superpowers/specs/2026-05-16-spec-distill-hook-review-design.md` 호출. plan 산출 경로: `docs/superpowers/plans/2026-05-16-spec-distill-hook-review-plan.md`.
3. **Implementation**: plan에 따라 hook script / library / 테스트 / SKILL.md 수정 / version bump 진행.
4. **Verification**: V1–V7 자동 실행 + V8/V9 manual E2E.
5. **PR**: feature/spec-distill-hook-review → main. plugin.json v0.3.0 bump 포함된 단일 PR.
