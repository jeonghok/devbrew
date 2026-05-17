---
name: spec-distill-design-mode-trigger
version: 1.0.0
created_at: 2026-05-17
status: design
source: brainstorming session 2026-05-17
next_phase: writing-plans
session_id: brainstorm-2026-05-17-spec-distill-design-mode-trigger
locked_decisions:
  - id: LD1
    section: "#goals"
    summary: 'Trigger 신뢰성은 layer-별 분해로 해결한다. L1(PostToolUse 매칭), L4a(Stop mandate), L4b(UserPromptSubmit 재emit), L5(reviewing-spec design 분기) 4개 layer 모두 보강. (G1)'
    source: brainstorming-round-1
  - id: LD2
    section: "#goals"
    summary: 'brainstorming(superpowers 플러그인 소속)은 수정하지 않는다. spec-distill 내부 hook + skill layer에서만 trigger 결정론 강화. (G2)'
    source: brainstorming-round-1
  - id: LD3
    section: "#goals"
    summary: 'UserPromptSubmit reminder hook을 신규 추가한다. Stop hook의 single-shot mandate가 next-turn에서 무시될 경우 재emit하는 redundancy layer. TTL guard로 spam 방지. (G3)'
    source: brainstorming-round-1
  - id: LD4
    section: "#goals"
    summary: 'Hook이 spec-reviewer agent를 직접 invoke하지 않는다. Agent dispatch는 Claude 책임. Hook은 systemMessage signaling만. devbrew Law 2 (writer/reviewer 물리 분리) 유지. (G4)'
    source: brainstorming-round-1
  - id: LD5
    section: "#goals"
    summary: 'reviewing-spec skill의 routing table에 design row를 추가하고 design mode 분기를 Step 1에 명시. 기존 spec mode routing은 무손상. (G5)'
    source: brainstorming-round-1
  - id: LD6
    section: "#non-goals"
    summary: 'spec-reviewer agent의 spec-mode 본문(verdict format, 11-section 검사)은 무수정. design checklist는 분기 섹션으로 추가만. (NG1)'
    source: brainstorming-round-1
  - id: LD7
    section: "#non-goals"
    summary: 'design mode에서도 locked_decisions/11-sections schema 강제하지 않는다. brainstorming이 산출하는 design.md 자유도는 보존 (spec-distill-hook-review v0.3.0 LD7 승계). (NG2)'
    source: brainstorming-round-1
  - id: LD8
    section: "#constraints"
    summary: 'UserPromptSubmit reminder는 last_dispatched_at TTL(default 30s) 안이면 silent skip. Stop hook이 막 fire한 직후 중복 emit 방지. (C1)'
    source: brainstorming-round-1
  - id: LD9
    section: "#constraints"
    summary: 'Version bump: 0.3.0 → 0.4.0 (minor, 신규 surface = UserPromptSubmit hook + reviewing-spec design routing). plugin.json + CHANGELOG.md 같은 commit. (C2)'
    source: brainstorming-round-1
  - id: LD10
    section: "#constraints"
    summary: 'Kill switch는 기존 namespace 재사용. DEVBREW_DISABLE_SPEC_DISTILL=1, DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit (또는 :reminder). 신규 env var 도입 금지. (C3)'
    source: brainstorming-round-1
  - id: LD11
    section: "#goals"
    summary: 'State 파일 위치는 항상 main repo root 기준으로 해석한다. 워크트리에서 호출되더라도 `<main_repo>/.claude/spec-distill/<session-id>/state.local.md`에 기록 — git rev-parse --git-common-dir로 main repo .git 위치를 얻고 dirname으로 root 도출. 비-git/git 실패 시 cwd fallback + stderr loud log. (G6, philosophy §4.8 instantiation)'
    source: brainstorming-round-2 (worktree investigation)
  - id: LD12
    section: "#goals"
    summary: 'pending_review block에 worktree_path 필드 추가 — Write 시점의 절대경로(cwd 기반)를 기록. Stop hook의 mandate systemMessage에도 worktree_path를 포함시켜 reviewing-spec이 main repo cwd로 돌아왔을 때도 spec 파일의 절대경로를 잃지 않도록 한다. (G7)'
    source: brainstorming-round-2 (worktree investigation)
---

# spec-distill Design-Mode Trigger Reliability (v0.4.0)

> **brainstorming flow가 design.md를 산출했는데 spec-reviewer가 fire하지 않는 silent-miss를 4-layer redundancy로 봉쇄한다. Trigger도 dispatch도 LLM 의지 의존을 없앤다.**

## Goal

PostToolUse hook이 `*-design.md` write를 감지한 후, 동일 session 또는 다음 turn에서 spec-reviewer agent가 반드시 dispatch되도록 trigger chain을 layer별로 redundancy 보강하고, reviewing-spec skill이 design mode를 정상 라우팅하도록 한다.

## Context / Why

직전 브랜치(spec-distill-hook-review v0.3.0)에서 PostToolUse matcher와 design mode 인식은 도입되었으나, **brainstorming flow의 terminal step("invoke writing-plans")이 Stop hook의 mandate systemMessage("invoke reviewing-spec")와 충돌**할 때 어느 쪽이 이기는지 명세 부재. 결과: design.md 작성 직후 spec-reviewer가 fire하지 않고 writing-plans로 직진하는 silent-miss가 관측됨.

추가로 reviewing-spec skill 자체는 spec mode(11 sections, locked_decisions, interview re-entry) 전제로 짜여 있어, 가령 dispatch 되더라도 design.md를 spec.md로 오인 판정할 위험이 있음.

**워크트리 환경 추가 발견 (round-2 investigation)**: 본 design 작성 자체를 worktree 안(`<repo>/.claude/worktrees/spec-distill-design-trigger/`)에서 수행하면서 dogfood로 검증 중, PostToolUse hook이 state를 **worktree's `.claude/spec-distill/`** 에 기록하는 것을 관측. main repo의 `.claude/spec-distill/`은 빈 상태. 이는 philosophy §4.8 ("State 자체는 main repo의 `.claude/<plugin>/<session-id>/`에 머무르며...") 컨벤션 위반이며, `ExitWorktree action: remove` 시 pending_review state silent loss → reviewer dispatch 실패의 두 번째 root cause. 4-layer redundancy가 무력화되는 시나리오.

devbrew Law 2(*Writer and Reviewer Must Never Share a Pass*)의 instantiation 신뢰성 문제다. brainstorming은 superpowers 플러그인 소속이라 우리가 수정할 수 없으므로, spec-distill 내부의 hook + skill layer에서만 결정론을 끌어올린다.

## Goals

- **G1**: Trigger chain 4-layer 모두 보강 — L1 매칭(이미 v0.3.0 도입), L4a Stop mandate 강화, L4b UserPromptSubmit redundancy 신규, L5 reviewing-spec design 분기. (cf. LD1)
- **G2**: brainstorming(upstream) 무수정. spec-distill 내부 layer에서만 변경. (cf. LD2)
- **G3**: UserPromptSubmit reminder hook 추가 — Stop hook의 single-shot mandate가 다음 turn에서 무시될 경우 매 user prompt에 재emit. TTL guard. (cf. LD3)
- **G4**: Hook은 agent를 직접 invoke하지 않는다. systemMessage signaling 한정. Law 2 물리 분리 유지. (cf. LD4)
- **G5**: reviewing-spec skill의 routing table에 design row 추가 + Step 1 mode 분기. 기존 spec mode 경로 무손상. (cf. LD5)
- **G6**: State 파일 위치를 worktree-aware로 통일 — 모든 hook이 `git rev-parse --git-common-dir`로 main repo root를 해석하고 거기에 state를 기록/읽기. worktree에서 호출돼도 main repo `.claude/spec-distill/`에만 state가 살아 `ExitWorktree action: remove` silent-loss 차단. (cf. LD11, philosophy §4.8)
- **G7**: pending_review block에 `worktree_path:` 필드 추가. Stop mandate systemMessage에도 포함 → reviewing-spec이 main repo cwd로 돌아와도 spec 절대경로 보존. (cf. LD12)

## Non-goals

- **NG1**: spec-reviewer agent의 spec-mode 본문(verdict format, 11-section 검사) 수정 안 함. design checklist는 분기 섹션으로 *추가만*. (cf. LD6)
- **NG2**: design mode에 locked_decisions/11-sections schema 강제하지 않음. brainstorming 산출물 자유도 보존. (cf. LD7)
- **NG3**: brainstorming SKILL.md 수정 안 함 (superpowers 플러그인 소속, cross-plugin coupling 회피).
- **NG4**: 신규 env var 도입 없음 — 기존 `DEVBREW_DISABLE_SPEC_DISTILL`/`DEVBREW_SKIP_HOOKS` namespace 재사용.

## Constraints

- **C1**: UserPromptSubmit reminder는 `last_dispatched_at` TTL(default 30s) 내면 silent skip. (cf. LD8)
- **C2**: Version bump 0.3.0 → 0.4.0 (minor; 신규 surface = UserPromptSubmit hook + design routing). plugin.json + CHANGELOG.md 동일 commit. (cf. LD9)
- **C3**: Kill switch는 기존 namespace 재사용. `DEVBREW_DISABLE_SPEC_DISTILL=1`, `DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit` (또는 `:reminder`). (cf. LD10)
- **C4**: 모든 신규/변경 hook은 graceful degradation — state I/O 실패 시 exit 0 + stderr loud log. crash 금지.
- **C5**: PostToolUse hook(`spec-write-validator.py`) 본문 변경 최소화. 이미 design mode 처리 중 — 추가 회귀 테스트 fixture만 보강.
- **C6**: state path 해석은 `hooks/state_path.py` 단일 helper로 중앙화. 모든 hook(spec-write-validator, review-dispatch, pending-review-reminder)이 이 helper만 호출. git 부재/실패 시 cwd fallback + `[spec-distill] state root fallback: cwd ({path}) — main repo 미해석` stderr 한 줄 emit. (cf. LD11)

## Acceptance Criteria

- **AC1**: `docs/superpowers/specs/2026-MM-DD-foo-design.md`를 Write tool로 작성하면 PostToolUse hook이 `pending_review: mode=design` block을 state.local.md에 기록한다. (L1 회귀 보장)
- **AC2**: pending_review block이 기록된 직후 turn 종료 시 Stop hook이 systemMessage emit. 메시지 본문에 "reviewing-spec 호출" + "타 terminal handoff(writing-plans 등) 보류" 두 문구 모두 포함.
- **AC3**: Stop hook fire 후 next turn UserPromptSubmit에서 reminder hook은 silent skip (TTL=30s 가드).
- **AC4**: pending_review block이 next turn 시작에도 살아있고 `last_dispatched_at` > TTL이면 UserPromptSubmit reminder가 systemMessage 재emit.
- **AC5**: reviewing-spec skill 본문 Step 1에서 `pending_review.mode` 분기 명시 — design일 때 locked_decisions / 11-sections 점검 skip.
- **AC6**: reviewing-spec routing table에 design rows 3개 추가 — (approved → Human Gate → writing-plans), (needs_revise & count<3 → re-draft path), (needs_revise & count≥3 → forced Human Gate).
- **AC7**: spec-reviewer agent persona에 design mode checklist 분기 섹션 추가 — placeholder, ambiguity, scope creep, 2-3 approaches 비교 유무, isolation/boundaries, testing 언급. 기존 spec-mode 본문 무손상.
- **AC8**: `DEVBREW_DISABLE_SPEC_DISTILL=1` 또는 `DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit` 환경변수 설정 시 reminder hook은 exit 0 (no emit).
- **AC9**: plugin.json `version: 0.4.0`, CHANGELOG.md `## [0.4.0] — 2026-MM-DD` 섹션에 Added/Changed 분류로 변경사항 기재. README.md "Hooks Installed" 섹션에 UserPromptSubmit reminder 항목 추가, 한 줄 justification ("Stop hook single-shot mandate가 silent drop될 경우 매 turn 재확인하는 redundancy layer — skill로 처리 불가, turn boundary 이벤트가 필요").
- **AC10**: 신규 테스트 4개 파일 전체 통과. 커버 시나리오: (a) design mode 인식 + state 기록, (b) Stop mandate 본문 검증("reviewing-spec" + "terminal handoff 보류" 둘 다), (c) reminder TTL 가드 — skip / 초과 시 재emit 두 분기, (d) reviewing-spec design routing rows 3개.
- **AC11**: worktree cwd(`<repo>/.claude/worktrees/<wt>/`)에서 PostToolUse가 fire해도 state 파일은 `<main_repo>/.claude/spec-distill/<session-id>/state.local.md`에 기록된다. worktree 안 `.claude/spec-distill/`에는 state 파일이 *생기지 않는다*.
- **AC12**: pending_review block에 `worktree_path: <write 시점 cwd>` 필드 포함. Stop hook이 emit하는 mandate systemMessage 본문에 spec 파일 절대경로 + worktree_path 둘 다 포함되어, reviewing-spec이 main repo로 돌아온 turn에서도 spec을 찾을 수 있다.
- **AC13**: git 부재 환경(예: tarball checkout)에서 hook이 호출되면 state는 cwd-relative로 fallback 기록되고, stderr에 `[spec-distill] state root fallback: cwd (...) — main repo 미해석` 한 줄이 emit된다 (loud log). 사용자가 fallback 동작을 인지 가능.

## Files to Modify

```
plugins/spec-distill/
├── .claude-plugin/plugin.json                                # version 0.3.0 → 0.4.0
├── CHANGELOG.md                                              # [0.4.0] 섹션 추가
├── README.md                                                 # Hooks Installed에 UserPromptSubmit reminder + Principles Instantiated 갱신
├── hooks/
│   ├── hooks.json                                            # UserPromptSubmit에 reminder 등록 (기존 interview-trigger.sh 옆)
│   ├── pending-review-reminder.py                            # NEW: TTL-guarded redundancy hook (state_path helper 사용)
│   ├── review-dispatch.py                                    # systemMessage 본문 강화 + state_path helper + mandate에 worktree_path 포함
│   ├── spec-write-validator.py                               # state write에 state_path helper + pending_review에 worktree_path 필드 추가
│   └── state_path.py                                         # NEW: main repo root 해석 helper (git rev-parse --git-common-dir, cwd fallback loud log)
├── skills/reviewing-spec/SKILL.md                            # Step 1 mode 분기 + Routing Table design rows 3개
├── agents/spec-reviewer.md                                   # design mode checklist 분기 섹션
└── tests/
    ├── fixtures/2026-05-17-test-design.md                    # NEW: valid design fixture
    ├── fixtures/2026-05-17-test-design-bad.md                # NEW: placeholder+ambiguity hit fixture
    ├── test_design_mode_validator.py                         # NEW: L1 mode=design 인식 검증
    ├── test_review_dispatch_design_mandate.py                # NEW: L4a mandate 본문 검증
    ├── test_reminder_hook.py                                 # NEW: L4b TTL skip / 초과 시 재emit
    ├── test_reviewing_spec_design_routing.py                 # NEW: L5 routing rows 검증
    ├── test_state_path_worktree.py                           # NEW: state_path helper가 worktree에서 main repo root 반환
    └── test_state_path_fallback.py                           # NEW: git 부재 시 cwd fallback + loud log
```

## Verification Plan

- **V1**: `python3 -m pytest plugins/spec-distill/tests/test_design_mode_validator.py -v` — L1이 design.md를 mode=design으로 state에 기록.
- **V2**: `python3 -m pytest plugins/spec-distill/tests/test_review_dispatch_design_mandate.py -v` — L4a systemMessage 본문이 "reviewing-spec" + "terminal handoff 보류" 둘 다 포함.
- **V3**: `python3 -m pytest plugins/spec-distill/tests/test_reminder_hook.py -v` — TTL 가드 동작 (skip + 재emit 두 분기).
- **V4**: `python3 -m pytest plugins/spec-distill/tests/test_reviewing_spec_design_routing.py -v` — routing table design rows 3개가 모두 정의되어 있고 의도된 next phase로 매핑.
- **V5**: 수동 E2E — temp 디렉토리에서 `docs/superpowers/specs/2026-05-17-e2e-design.md`를 Write tool로 작성 → state.local.md에 pending_review 확인 → Claude session 종료 후 재시작 → 첫 user prompt에 reminder systemMessage 관측.
- **V5a**: 수동 E2E — worktree (`<repo>/.claude/worktrees/<name>/`)에서 같은 파일을 Write → state.local.md가 `<main_repo>/.claude/spec-distill/<session-id>/`에만 기록되었는지 확인 (worktree 안에는 없어야 함). `ExitWorktree action: remove` 후에도 state 보존 확인.
- **V6**: kill switch 검증 — `DEVBREW_SKIP_HOOKS=spec-distill:reminder python3 hooks/pending-review-reminder.py < payload.json`가 exit 0 + no stdout emit.
- **V7**: 회귀 검증 — 기존 `tests/test_*.py` 전체 통과 (spec mode 경로 무손상).

## Rejected Alternatives

- **R1 — UserPromptSubmit이 Stop hook을 대체 (single-layer 단독)**: Stop 제거하고 reminder만 남기는 안. 사유: brainstorming 같은 multi-turn 외부 flow에서는 turn boundary가 분리되어 있어 reminder도 fire 시점 보장 안 됨. **두 layer 모두 필요** — Stop은 즉시 mandate, reminder는 follow-up redundancy.
- **R2 — Hook이 spec-reviewer agent 직접 invoke (shell→Claude API)**: shell이 agent orchestration을 우회. devbrew Law 2의 *물리적 분리* 원칙 위배 + Claude의 tool 트래킹/감사 경로 이탈. **거절**.
- **R3 — brainstorming SKILL.md 편집해서 terminal step에 reviewing-spec 추가**: cross-plugin 결합. brainstorming은 superpowers 소속이라 우리가 ship 안 함 → drift 위험 + 사용자 환경별 버전 차이로 silent miss.
- **R4 — PostToolUse가 즉시 dispatch mandate emit (Stop 무관)**: turn 중간이라 Claude가 이미 다음 액션 결정 중일 수 있음. PostToolUse의 systemMessage는 advisory에 적합, mandate는 turn boundary(Stop)에 두는 게 안전.
- **R5 — Pattern matcher만 수정**: v0.3.0에서 design mode 추가로 매칭은 이미 통과. L4(dispatch obedience) / L5(reviewing-spec design 분기)가 미해결이라 부분 fix.

## Open Questions

- 없음 (모든 결정 LD1–LD10에 박제).

## Concrete Next Action

다음 단계: `superpowers:writing-plans` skill 호출 (이 design을 기반으로 step-by-step 구현 plan 작성).
- Spec 경로: `docs/superpowers/specs/2026-05-17-spec-distill-design-mode-trigger-design.md`
- Plan 산출물: `docs/superpowers/plans/2026-05-17-spec-distill-design-mode-trigger.md`
- 명령: `/superpowers:writing-plans` (현 session 내 chained invocation)
