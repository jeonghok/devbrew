---
name: spec-distill-handoff-proceed-gate
version: 1.0.0
created_at: 2026-05-29
session_id: brainstorming-2026-05-29-handoff-proceed-gate
status: locked
next_phase: writing-plans
source: brainstorming-round-1
supersedes:
  - doc: 2026-05-27-spec-distill-handoff-idempotency-design.md
    decisions: [LD2, LD5]
    note: "LD2(Stop hook unmissable /compact induction) + LD5(.markers/ 파일) 메커니즘 폐기. LD4(git commit 제거)는 계승."
locked_decisions:
  - id: LD1
    summary: "compact-induction Stop hook + compact-detect UserPromptSubmit hook + .markers/ 메커니즘 완전 제거."
    rationale: "사용자 명시 응답('훅 완전 제거'). hook은 AskUserQuestion을 띄울 수 없어 /compact를 텍스트로 반복 주입하는 우회였고, dangling spec_path에서 실제 예외 + 탈출 어려운 UX를 만들었다."
  - id: LD2
    summary: "/compact 추천을 reviewing-spec Phase 5 approve 게이트의 단일 AskUserQuestion에 통합. approve 확정 후 별도 2차 질문 금지."
    rationale: "사용자 명시 응답('approve에서 같이 제안... approve 확인하고 또 question 나오는건 UX적으로도 로직적으로도 복잡'). /compact 추천은 본질적으로 skill이 띄우는 게이트의 일이지 hook의 일이 아니다."
  - id: LD3
    summary: "/compact은 강제가 아니라 권장 옵션 — 한 게이트 안에서 사용자가 선택."
    rationale: "사용자가 '옵션으로 제공' 방향 선택. 긴 인터뷰의 context 위생 이점은 유지하되 사용자 주권(P17)에 맡긴다."
  - id: LD4
    summary: "proceed 전 spec_path 존재(+repo 내) 검증. 없는 파일로 핸드오프하지 않음."
    rationale: "보고된 '실제 예외'의 root cause. PR #72 merge로 worktree가 제거된 뒤 남은 세션 state가 dangling worktree 경로를 가리켜 핸드오프가 없는 파일을 대상으로 돌며 예외 발생. 현행 메커니즘은 spec_path 유효성을 검증하지 않았다."
  - id: LD5
    summary: "AP2(polite stop) 방어를 hook 인프라 → skill의 *필수 종료* AskUserQuestion proceed 게이트로 전환. backstop hook 없음."
    rationale: "사용자 명시 응답('훅 완전 제거(권장)'). 철학 §AP2(line 413)가 직접 구분: approval gate(사용자 redirect 가능)는 polite stop이 아니라 P17 주권에 기여. AskUserQuestion 게이트는 hook injection보다 *더* unmissable(사용자가 응답해야 진행). 단 prose-enforced이므로 CLAUDE.md AP2 항목을 게이트 기준으로 갱신해 강제력을 문서화한다."
  - id: LD6
    summary: "approve_handoff.sh는 thin script로 유지하되 역할 축소: spec_path 검증 + 세션 cleanup. marker write·packet emit 제거, committed 검사는 advisory(block 아님)."
    rationale: "기본값 제안 → 사용자 승인. 격리 테스트 용이성 유지(Law 2 testable unit). dirty_blocked exit-1 제거로 에러 표면 축소 + devbrew lightness."
---

# spec-distill handoff — Stop-hook induction 제거 → AskUserQuestion proceed 게이트

> *명세를 다음 단계로 넘기는 seam은 hook이 텍스트를 반복 주입해서가 아니라, 사용자가 응답해야만 지나갈 수 있는 게이트로 잠겨야 한다 — 추천은 skill의 일이지 hook의 일이 아니다.*

## Goal

reviewing-spec Phase 5 handoff를 재설계해 (a) `compact-induction`/`compact-detect`/marker 메커니즘을 제거하고, (b) /compact 추천을 approve 게이트의 단일 `AskUserQuestion`에 통합하며, (c) proceed 전 `spec_path` 유효성을 검증해 dangling-path 예외를 봉쇄한다.

## Handoff Context

**TL;DR**:
- spec-distill v0.10.0의 marker 기반 compact induction(Stop hook이 매 turn `/compact required` 재주입)을 폐기한다.
- reviewing-spec Phase 5 Human Gate가 단일 `AskUserQuestion`으로 다음 단계(권장 `/compact` 포함)를 제안한다.
- proceed 직전 `spec_path` 존재를 검증해 보고된 실제 예외(dangling worktree 경로)를 막는다.

**Implicit context** (Constraints에 없지만 진행에 필요):
- **hook은 `AskUserQuestion`을 띄울 수 없다.** hook은 stdout/JSON으로 `additionalContext`·`systemMessage` 텍스트만 주입 가능. interactive 결정 게이트는 skill(메인 turn)만 띄운다 — 이것이 LD1/LD2의 근본 근거.
- **모델은 `/compact` slash command를 직접 실행할 수 없다** (Claude Code 본질적 제약, 2026-05-27 design LD2/NG2에서 확인). 따라서 옵션 ①(/compact 후 writing-plans)은 모델이 명령을 노출하고 *사용자가* 실행한다.
- spec-distill review hook(`review-dispatch`, `pending-review-reminder`)은 `docs/superpowers/specs/` 아래 `.md` write에 발화 — 이 design.md도 hook 대상. 본 변경은 그 review-강제 hook을 건드리지 않는다(Non-goal).
- reviewing-spec Phase 5는 이미 `AskUserQuestion`을 사용한다(현행 옵션: revise / more interview / edit / approve). 본 변경은 그 옵션 집합을 proceed 중심으로 재구성하는 것이지 새 게이트 신설이 아니다.
- 현재 main repo에 stale 세션 state(`.claude/spec-distill/d915fa62-.../state.local.md`)가 남아 dangling worktree 경로를 가리킨다 — 이 design의 LD4 검증이 막으려는 정확한 상황.

**Deferred to plan**:
- approve 게이트 4개 옵션의 *최종 label/description wording* — design은 옵션 의미·분기를 확정, 문구는 plan UX iteration.
- spec_path "repo 내" 판정의 정확한 구현(`git ls-files` vs `git rev-parse --show-toplevel` prefix 비교) — design은 "존재 + repo 내" semantics 확정, 구현 선택은 plan.

## Context / Why

사용자 보고 (2026-05-29):

> spec 디스틸 스탑훅 에러 발생함 — compact 핸드오프 과정에서 에러 발생. 스탑훅이 나오는건 별로임, 제안이 더 나은 방향. spec review 스킬이 끝나는 경우 제안을 진행이 나음. 실제 에러가 발생하고 훅 방식이 ask question으로 compact를 추천하지 못함.

현행 v0.10.0 흐름 분석:
- `approve` → `approve_handoff.sh`가 `.claude/spec-distill/.markers/<sid>.emitted` marker write → `compact-induction` Stop hook이 marker 살아있는 한 매 Stop turn `/compact required` 텍스트 재주입 → `compact-detect` UserPromptSubmit hook이 `/compact`/`writing-plans` prefix 감지 시 marker 삭제.
- **(버그)** handoff/induction이 `spec_path` 유효성을 검증하지 않는다. PR #72(`ac86d57`) merge로 worktree `feature-qg-v1322-followup`이 제거됐는데 세션 state의 `current_spec`이 그 worktree 절대경로를 가리켜, 핸드오프/compact가 *존재하지 않는 파일*을 대상으로 돌며 예외 발생.
- **(구조)** hook은 `AskUserQuestion`을 못 띄우므로 /compact를 텍스트로 반복 주입하는 우회. 사용자가 정확히 `/compact`로 *시작하는* 프롬프트를 칠 때까지 매 turn 재발화 → 탈출 어려운 UX.

devbrew 철학상 의미:
- **Law 1 (Clarity Before Code)**: spec lock 직후 핸드오프가 예외로 깨지면 clarity가 plan에 도달하지 못함 — spec lifecycle 1급 결함.
- **AP2 (Polite Stop) 재해석**: 철학 §AP2(line 413)는 *approval gate*(결정 전 pause, 사용자 redirect 가능)와 *polite stop*(verified-done 후 unrequested narrative)을 구분한다. 현행 Stop-hook induction은 "narrate-only 봉쇄"를 위한 인프라였으나, 그 역할은 **사용자가 응답해야만 지나가는 approval gate**가 *더* 잘 수행한다. 즉 본 변경은 AP2 위반이 아니라 AP2가 권장하는 형태로의 전환이다.
- **Law 3 (Compounding)**: 메커니즘 전환을 CLAUDE.md/README/memory에 반영해야 다음 cycle agent가 올바른 handoff 계약을 substrate로 활용한다.

## Goals

- **G1**: `compact-induction.py` Stop hook + `compact-detect.py` UserPromptSubmit hook + `.markers/` marker 메커니즘을 완전 제거한다. hooks.json에서 두 등록 제거.
- **G2**: reviewing-spec Phase 5 Human Gate가 단일 `AskUserQuestion`으로 다음 단계를 제안한다 — 권장 `/compact` 옵션을 게이트에 통합, approve 확정 후 별도 질문 없음.
- **G3**: proceed(approve_handoff.sh 호출 + writing-plans 진입) 전 `spec_path` 존재(+repo 내)를 검증한다. 부재 시 loud advisory + 비진행(stale state 재선택/리셋 경로).
- **G4**: `approve_handoff.sh`를 thin script로 축소 — spec_path 검증 + 세션 cleanup만. marker write·packet emit·`dirty_blocked` exit-1 제거. committed 검사는 advisory(non-blocking).
- **G5**: AP2 방어가 hook → skill의 *필수 종료 게이트*로 이동했음을 CLAUDE.md Forbidden Patterns / README / memory에 반영한다 (Law 3).
- **G6**: `spec-distill-gc.py`의 `_sweep_markers` dead code 제거 (marker 디렉토리가 더는 생성되지 않음).

## Non-goals

- **NG1**: `review-dispatch.py` Stop hook / `pending-review-reminder.py` UserPromptSubmit hook 변경 없음 — review 강제(Law 1/2)는 healthy.
- **NG2**: spec-reviewer persona, routing table(AC15), re-consensus gate([3.5]) 동작 변경 없음.
- **NG3**: brainstorming skill 편집 없음 (upstream cache, devbrew unowned).
- **NG4**: `/compact`을 모델이 자동 실행하게 만들지 않음 — Claude Code 본질적 제약. 사용자 입력 induce(권장 노출)만.
- **NG5**: 과거 docs/superpowers/specs·plans 문서 수정 없음 (역사 기록 — supersedes frontmatter로만 lineage 표기).
- **NG6**: 신규 P#(철학 원칙) 추가 없음 — 기존 AP2 approval-gate 구분의 instantiation으로 충분 (memory: design lightness).

## Constraints

- **C1**: 변경은 `plugins/spec-distill/`와 devbrew root `CLAUDE.md`, memory 외부로 spillover하지 않는다.
- **C2**: `AskUserQuestion` 옵션은 2–4개 — approve 게이트가 4개 한도 내.
- **C3**: hook 제거 후 Stop·UserPromptSubmit event에 각각 최소 1개 hook 잔존(review-dispatch, pending-review-reminder) → hooks.json 빈 배열 정리 불필요.
- **C4**: `approve_handoff.sh`는 `DEVBREW_DISABLE_SPEC_DISTILL=1` kill switch를 계속 존중한다 (CLAUDE.md "kill switch는 보안 컨트롤").
- **C5**: `plugin.json` version `0.10.0` → `0.11.0` (0.x minor = behavior/contract change). CHANGELOG.md에 `## [0.11.0] — 2026-05-29` entry.
- **C6**: hook 제거 + persona-인접 skill 편집은 보안-민감 (CLAUDE.md "Persona 파일은 보안-민감 코드") — reviewer가 약화되지 않음을 확인.
- **C7**: secret 기록 금지 (P21) — 해당 없음(marker 제거).

## Acceptance Criteria

- **AC1**: `plugins/spec-distill/hooks/compact-induction.py`와 `compact-detect.py` 파일이 삭제됐다. `hooks.json`의 Stop 배열에 compact-induction 항목이, UserPromptSubmit 배열에 compact-detect 항목이 없다. (grep으로 단언: `compact-induction`·`compact-detect` 문자열이 hooks.json에 부재.)
- **AC2**: `hooks.json`의 Stop 배열에 `review-dispatch.py`가, UserPromptSubmit 배열에 `pending-review-reminder.py`가 여전히 존재한다 (review 강제 회귀 방지).
- **AC3**: `approve_handoff.sh <sid> <존재하는-clean-spec>` 호출 시 exit 0, stdout/stderr 어디에도 `.markers/`·`STATUS=`·`FIRE_COUNT=`·3-block handoff packet 문자열이 없다. `.claude/spec-distill/.markers/` 디렉토리가 생성되지 않는다.
- **AC4**: `approve_handoff.sh <sid> <존재하지-않는-경로>` 호출 시 exit 1, stderr advisory에 다음 토큰 포함: 1) `[spec-distill]` prefix, 2) `spec_path`(또는 동등) 부재를 가리키는 명시 문구, 3) 진행하지 않았다는(no handoff) 명시. 세션 디렉토리 cleanup은 *수행하지 않는다*(stale 판단 보류).
- **AC5**: `approve_handoff.sh <sid> <존재하지만-uncommitted-spec>` 호출 시 exit 0(비-block) + stderr advisory 1줄(미커밋 경고 + copy-pasteable `git add`/`git commit` 안내). 진행을 막지 않는다.
- **AC6**: `approve_handoff.sh`가 정상(AC3/AC5) 경로에서 `.claude/spec-distill/<sid>/` 세션 디렉토리를 cleanup한다 (cleanup 실패는 non-fatal advisory — SessionEnd hook이 backup).
- **AC7**: `DEVBREW_DISABLE_SPEC_DISTILL=1` 환경에서 `approve_handoff.sh`가 즉시 exit 0, cleanup 포함 모든 부작용 skip, state 보존.
- **AC8**: `reviewing-spec/SKILL.md` Phase 5 절이 단일 `AskUserQuestion` proceed 게이트를 명시한다. 옵션 의미가 다음 4종으로 문서화돼 있다 (label wording은 plan): ① /compact 후 writing-plans(권장), ② 바로 writing-plans, ③ 수정 필요(revise/interview/edit 후속 분기), ④ 멈춤(state 보존). approve 경로(①/②) 확정 후 *추가 AskUserQuestion 없음*이 명문화돼 있다.
- **AC9**: `reviewing-spec/SKILL.md`가 proceed 게이트를 띄우기 *전* `current_spec`(=spec_path) 존재 검증을 지시하고, 부재 시 게이트 대신 stale-state advisory + 리셋/재선택 경로를 지시한다.
- **AC10**: `reviewing-spec/SKILL.md`에서 marker/compact-induction/compact-detect/`.markers/` 참조가 모두 제거됐고, "Approve handoff sequence" 절이 marker·packet 없는 새 계약(검증→cleanup→옵션별 진행)으로 갱신됐다.
- **AC11**: `reviewing-spec/SKILL.md`에 "approve 후 proceed 게이트를 띄우지 않고 narrate-only로 멈추는 것은 polite stop(AP2)"이라는 명시적 금지 문구가 있다 (hook backstop 상실 보완 — prose 강제력 문서화).
- **AC12**: `spec-distill-gc.py`에서 `_sweep_markers` 함수 정의와 그 호출(`removed += _sweep_markers(...)`)이 제거됐다. GC가 marker 디렉토리를 참조하지 않는다.
- **AC13**: `plugin.json` version이 `0.11.0`이고 CHANGELOG.md 최상단 entry가 `## [0.11.0] — 2026-05-29` (Removed: compact-induction/compact-detect/marker; Changed: Phase 5 proceed 게이트; Fixed: dangling spec_path 예외; Added: spec_path 검증 섹션 포함).
- **AC14**: `README.md` "Hooks Installed"에서 compact-induction/compact-detect 2행이 제거됐고, marker/induction 기반 kill switch·Principles 서술이 게이트 기준으로 갱신됐다.
- **AC15**: devbrew root `CLAUDE.md`의 Forbidden Patterns "Polite handoff" 항목이 marker/Stop-hook induction 서술 대신 "approve 시 proceed 게이트(AskUserQuestion) 미제시 narrate-only = polite-stop"으로 갱신됐다.
- **AC16**: marker/induction을 전제한 기존 테스트(`test_compact_induction_hook.sh`, `test_compact_induction_stagnation.sh`, `test_compact_detect_hook.sh`, `test_handoff_compact_chain.sh`, `test_handoff_approve_packet_emit.sh`, `test_handoff_status_named.sh`)가 삭제 또는 새 계약으로 재작성됐고, 신규 회귀 테스트 `test_handoff_spec_path_validation.sh`(AC4 dangling-path 시나리오)가 추가돼 통과한다.

## Files to Modify

```
삭제:
plugins/spec-distill/hooks/compact-induction.py
plugins/spec-distill/hooks/compact-detect.py
plugins/spec-distill/tests/test_compact_induction_hook.sh
plugins/spec-distill/tests/test_compact_induction_stagnation.sh
plugins/spec-distill/tests/test_compact_detect_hook.sh
  — marker/induction 메커니즘 전용 테스트.

수정:
plugins/spec-distill/hooks/hooks.json
  — Stop 배열에서 compact-induction 항목 제거, UserPromptSubmit 배열에서 compact-detect 항목 제거.
    description 문자열도 두 hook 언급 제거.

plugins/spec-distill/scripts/approve_handoff.sh
  — marker write·packet emit·dirty_blocked exit-1 제거. spec_path 존재 검증(부재 시 exit 1) 추가.
    committed 검사는 advisory(exit 0). 세션 cleanup 유지. kill switch 유지.

plugins/spec-distill/scripts/spec-distill-gc.py
  — _sweep_markers 함수 + 호출 제거 (dead code).

plugins/spec-distill/skills/reviewing-spec/SKILL.md
  — Phase 5 Human Gate를 단일 AskUserQuestion proceed 게이트(4 옵션)로 재구성.
    spec_path 선검증 지시 추가. "Approve handoff sequence" 절을 marker·packet 없는 계약으로 갱신.
    polite-stop(AP2) 금지 문구 추가.

plugins/spec-distill/tests/test_handoff_compact_chain.sh
  — V9 end-to-end를 "approve → 검증 → cleanup → (marker/induction 없음)"로 재작성.
plugins/spec-distill/tests/test_handoff_approve_packet_emit.sh
plugins/spec-distill/tests/test_handoff_status_named.sh
  — packet/named-status가 제거됐으므로 새 계약으로 재작성 또는 삭제(plan에서 결정).
plugins/spec-distill/tests/test_approve_handoff.sh
plugins/spec-distill/tests/test_handoff_kill_switch.sh
plugins/spec-distill/tests/test_handoff_context_section_required.sh
plugins/spec-distill/tests/test_handoff_context_empty_subsections.sh
plugins/spec-distill/tests/test_handoff_design_mode.sh
plugins/spec-distill/tests/test_handoff_conversation_reference.sh
  — approve_handoff.sh 새 동작(검증/advisory/cleanup, marker 부재)에 맞춰 갱신.
plugins/spec-distill/tests/test_gc.py
plugins/spec-distill/tests/test_session_end_cleanup.py
  — marker sweep 제거 반영.

plugins/spec-distill/.claude-plugin/plugin.json
  — version 0.10.0 → 0.11.0.
plugins/spec-distill/CHANGELOG.md
  — ## [0.11.0] — 2026-05-29 (Removed/Changed/Fixed/Added).
plugins/spec-distill/README.md
  — Hooks Installed −2행, Principles·kill switch 서술 게이트 기준 갱신.

CLAUDE.md (devbrew root)
  — Forbidden Patterns "Polite handoff" 항목을 게이트 기준으로 갱신.

신규:
plugins/spec-distill/tests/test_handoff_spec_path_validation.sh
  — AC4 dangling/존재하지-않는 spec_path → exit 1 + advisory + 비진행 회귀 테스트.

memory: project_spec_distill_review_hardening.md
  — 메커니즘 전환(marker-induction → AskUserQuestion proceed 게이트) 기록, plugin v0.11.0.
```

## Verification Plan

- **V1 — hook 제거 정적 검증**: `compact-induction.py`/`compact-detect.py` 파일 부재 확인. `grep -c 'compact-induction\|compact-detect' plugins/spec-distill/hooks/hooks.json` → 0. Stop 배열에 `review-dispatch`, UserPromptSubmit 배열에 `pending-review-reminder` 존재 (AC1/AC2).
- **V2 — approve_handoff happy/advisory path**: `bash plugins/spec-distill/tests/test_approve_handoff.sh` PASS. 정상 경로 stdout/stderr에 `.markers/`·`STATUS=`·`packet` 문자열 부재 단언 (AC3/AC5).
- **V3 — spec_path 검증 회귀**: `bash plugins/spec-distill/tests/test_handoff_spec_path_validation.sh` PASS — 존재하지 않는 경로 → exit 1 + `[spec-distill]` advisory + 세션 디렉토리 미삭제 (AC4).
- **V4 — 세션 cleanup**: 정상 경로에서 `.claude/spec-distill/<sid>/` 삭제 확인, cleanup 실패 시 non-fatal advisory (AC6).
- **V5 — kill switch**: `DEVBREW_DISABLE_SPEC_DISTILL=1` → approve_handoff.sh 즉시 exit 0, cleanup 포함 부작용 skip (AC7).
- **V6 — GC dead code 제거**: `grep -c '_sweep_markers' plugins/spec-distill/scripts/spec-distill-gc.py` → 0. `bash`/`python3` GC 테스트 PASS (AC12).
- **V7 — skill 계약 정적 검증**: `reviewing-spec/SKILL.md`에 marker/compact-induction/compact-detect/`.markers/` 참조 0건. proceed 게이트 4 옵션 + spec_path 선검증 + polite-stop 금지 문구 존재 (AC8/AC9/AC10/AC11).
- **V8 — meta/docs**: `jq -r .version plugins/spec-distill/.claude-plugin/plugin.json` → `0.11.0`. CHANGELOG 최상단 `## [0.11.0] — 2026-05-29`. README Hooks 표에 compact-* 부재. CLAUDE.md "Polite handoff" 항목 게이트 기준 (AC13/AC14/AC15).
- **V9 — full plugin test suite**: `plugins/spec-distill/tests/`의 모든 test PASS (재작성·삭제 반영). marker/induction 전제 테스트가 남아 실패하지 않음 (AC16).
- **V10 — manual smoke (advisory only)**: 실제 session에서 임의 design.md → review-dispatch → approve → proceed 게이트(AskUserQuestion) 노출 → 옵션 ② 선택 → writing-plans 진입을 1회 실측. 옵션 ① 선택 시 /compact 명령이 복사 가능하게 노출되는지 확인. PR pre-merge checklist (자동 CI 게이트 아님).

## Rejected Alternatives

- **R1 — 2-step (approve → 별도 /compact 질문)**: 사용자 명시 거부 ('approve 확인하고 또 question 나오는건 UX적으로도 로직적으로도 복잡'). proceed 게이트에 /compact를 통합(LD2)하는 것으로 대체.
- **R2 — /compact 완전 제거(approve → 무조건 바로 writing-plans)**: 긴 인터뷰의 context 위생 이점 상실. 사용자는 /compact를 권장-옵션으로 유지하는 방향 선택(LD3). 단 옵션 ②로 "바로 writing-plans"는 제공.
- **R3 — /compact 강제 유지 + 다른 unmissable 장치**: 모델이 /compact를 자체 실행 불가하므로 hook 외 unmissable 수단이 없고, 사용자 '스탑훅 별로' 의도와 정면 배치.
- **R4 — 경량 backstop hook 유지(반복 발화 없이 1회 경고)**: 사용자가 '훅 완전 제거(권장)' 선택. AskUserQuestion 게이트가 응답을 강제하므로 hook backstop보다 오히려 unmissable; 잔존 hook은 lightness 위반.
- **R5 — approve_handoff.sh 폐기, skill이 검증·cleanup 인라인 흡수**: 격리 테스트 용이성 저하. thin script 유지가 Law 2 testable-unit + 결정론적 cleanup에 유리(LD6).
- **R6 — committed 미달 시 block 유지(dirty_blocked exit-1)**: 에러 표면 유지 + devbrew lightness 위반. spec은 사용자 소유(2026-05-27 LD4 계승)이므로 advisory로 충분 — writing-plans는 working-tree content를 읽으므로 미커밋 spec도 안전.

## Concrete Next Action

다음 단계: `Skill superpowers:writing-plans`.
- Spec 경로: `docs/superpowers/specs/2026-05-29-spec-distill-handoff-proceed-gate-design.md`
- Plan 산출물 예상 경로: `docs/superpowers/plans/2026-05-29-spec-distill-handoff-proceed-gate.md`
- 호출 명령: `Skill superpowers:writing-plans docs/superpowers/specs/2026-05-29-spec-distill-handoff-proceed-gate-design.md`
