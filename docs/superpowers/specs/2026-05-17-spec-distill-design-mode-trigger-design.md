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
  - id: LD13
    section: "#constraints"
    summary: 'Mandate obedience는 hard mechanism이 아니라 best-effort + redundancy. L4a/L4b 둘 다 무시되는 케이스는 사용자 의도(kill switch)로 간주하고 cleanup 정책(LD14)으로 state 누적만 방지. Claude를 강제로 obey시키는 메커니즘은 의도적으로 도입하지 않음 — devbrew Law 2 물리 분리 원칙과 상충 위험. (C7)'
    source: brainstorming-round-3 (spec-reviewer issue c4d18a52)
  - id: LD14
    section: "#constraints"
    summary: 'State cleanup 정책 = pending_review triggered_at > 24h → auto-purge, last_dispatched_at만 있는 state → 7일 후 파일 auto-delete. 신규 env var 없이 하드코딩 (LD10 일관성). (C8, P14 graceful state hygiene)'
    source: brainstorming-round-3 (spec-reviewer issue a1f3c2d0 Q2)
  - id: LD15
    section: "#non-goals"
    summary: 'drafting-spec skill은 본 design v0.4.0 범위 밖. design mode needs_revise → drafting-spec Mode B를 호출하지 *않고* brainstorming author(메인 agent)에게 control 반환. drafting-spec은 spec mode 전용 유지. (NG5)'
    source: brainstorming-round-3 (spec-reviewer issue f1b30d74)
---

# spec-distill Design-Mode Trigger Reliability (v0.4.0)

> **brainstorming flow가 design.md를 산출했는데 spec-reviewer가 fire하지 않는 silent-miss를 4-layer redundancy로 봉쇄한다. Trigger도 dispatch도 LLM 의지 의존을 없앤다.**

## Goal

PostToolUse hook이 `*-design.md` write를 감지한 후, 동일 session 또는 다음 turn에서 spec-reviewer agent가 반드시 dispatch되도록 trigger chain을 layer별로 redundancy 보강하고, reviewing-spec skill이 design mode를 정상 라우팅하도록 한다.

## Context / Why

직전 브랜치(spec-distill-hook-review v0.3.0)에서 L1(PostToolUse matcher + design mode 인식)은 정상 도입되었고 본 design 작성 dogfood 중에도 fire 확인됨. silent-miss는 **L4(dispatch obedience)와 L5(reviewing-spec design 분기 부재)** 두 layer에서 발생: Stop hook이 mandate를 emit해도 brainstorming flow의 terminal step("invoke writing-plans")과 충돌할 때 우선순위가 정해져 있지 않아 다음 turn에서 mandate가 무시될 수 있고, 가령 reviewing-spec이 호출되어도 design.md를 spec.md 양식으로 오인 판정할 수 있다.

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
- **NG5**: drafting-spec skill 수정 안 함 (spec mode 전용 유지). design.md `needs_revise` 시 re-draft는 brainstorming author(외부 skill) 책임으로 routing — drafting-spec Mode B는 호출하지 않는다. (review issue f1b30d74 대응)
- **NG6**: bare repo / submodule / nested worktree / `.git` symlink 환경은 v0.4.0 supported scope 밖. state_path.py에서 fallback 경로로 cwd-relative 처리 + stderr loud log만 보장. (review issue d9f47b03 대응)

## Constraints

- **C1**: UserPromptSubmit reminder는 `last_dispatched_at` TTL(default 30s) 내면 silent skip. (cf. LD8)
- **C2**: Version bump 0.3.0 → 0.4.0 (minor; 신규 surface = UserPromptSubmit hook + design routing). plugin.json + CHANGELOG.md 동일 commit. (cf. LD9)
- **C3**: Kill switch는 기존 namespace 재사용. `DEVBREW_DISABLE_SPEC_DISTILL=1`, `DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit` (또는 `:reminder`). (cf. LD10)
- **C4**: 모든 신규/변경 hook은 graceful degradation — state I/O 실패 시 exit 0 + stderr loud log. crash 금지.
- **C5**: PostToolUse hook(`spec-write-validator.py`) 본문 변경 최소화. 이미 design mode 처리 중 — 추가 회귀 테스트 fixture만 보강.
- **C6**: state path 해석은 `hooks/state_path.py` 단일 helper로 중앙화. 모든 hook(spec-write-validator, review-dispatch, pending-review-reminder)이 이 helper만 호출. git 부재/실패 시 cwd fallback + `[spec-distill] state root fallback: cwd ({path}) — main repo 미해석` stderr 한 줄 emit. (cf. LD11)
- **C7**: **Mandate obedience는 hard mechanism이 아닌 best-effort + redundancy** — Claude가 systemMessage를 obey한다는 강제 수단은 없다. L4a Stop mandate가 무시되면 L4b UserPromptSubmit reminder가 매 next turn 재emit. 둘 다 무시되는 케이스(예: 사용자가 kill switch 활성화)는 cleanup 정책(C8)으로 누적 방지. (review issue c4d18a52 대응)
- **C8**: **state cleanup 정책** — pending_review block의 `triggered_at` > 24h 경과 시 다음 hook fire 때 stale로 간주하고 자동 purge + stderr 통보. last_dispatched_at만 있고 pending_review 없는 state는 7일 후 파일 단위 auto-delete (P14 graceful state hygiene). 임계치는 신규 env var 없이 하드코딩 (C3 일관성). (review issue a1f3c2d0 Q2 대응)
- **C9**: **session_id 해석 순서** — `DEVBREW_SPEC_DISTILL_SESSION_ID` env var → conducting-interview가 frontmatter에 박은 session_id → `"default"` fallback. hook runtime 기준이며 spec/design.md frontmatter는 참조하지 않는다. 같은 design.md를 두 session에서 열어도 각 session의 env(또는 default)로 분리. (review issue a1f3c2d0 Q3 대응)

## Acceptance Criteria

- **AC1**: `docs/superpowers/specs/2026-MM-DD-foo-design.md`를 Write tool로 작성하면 PostToolUse hook이 `pending_review: mode=design` block을 state.local.md에 기록한다. (L1 회귀 보장)
- **AC2**: pending_review block이 기록된 직후 turn 종료 시 Stop hook이 systemMessage emit. 메시지 본문에 "reviewing-spec 호출" + "타 terminal handoff(writing-plans 등) 보류" 두 문구 모두 포함.
- **AC3**: Stop hook fire 후 next turn UserPromptSubmit에서 reminder hook은 silent skip (TTL=30s 가드).
- **AC4**: pending_review block이 next turn 시작에도 살아있고 `last_dispatched_at` > TTL이면 UserPromptSubmit reminder가 systemMessage 재emit.
- **AC5**: `test_reviewing_spec_design_routing.py`가 design mode 입력에 대해 spec-reviewer dispatch prompt에 `mode: design` 토큰이 포함되고 reviewer 출력에 11-section 또는 locked_decisions 누락을 issue로 raise하지 *않음*을 검증 (behavior assertion, SKILL.md 텍스트 검증이 아님). (review issue b7e20f91 대응)
- **AC6**: reviewing-spec routing table에 design rows 3개 추가 — (approved → Human Gate → writing-plans), (needs_revise & count<3 → **brainstorming author 회귀** = 사용자가 design.md 직접 수정 후 다음 turn에서 reviewing-spec 재dispatch; drafting-spec Mode B 호출하지 *않음*), (needs_revise & count≥3 → forced Human Gate). 표 본문에 "drafting-spec 미호출" 명시. (review issue f1b30d74 대응)
- **AC7**: `test_spec_reviewer_design_checklist.py`가 spec-reviewer를 `mode=design` 프롬프트로 실제 호출(또는 fixture 기반 dry-run)하여, 출력 issue 카테고리에 placeholder / ambiguity / scope-creep / approaches-comparison / isolation / testing 중 최소 3개 카테고리가 등장 가능함을 검증한다 (behavior assertion, persona 텍스트 grep이 아님). *이 6개 카테고리는 본 design Files-to-Modify의 `agents/spec-reviewer.md` design checklist 섹션에서 정의된다.* 동일 fixture로 spec mode 호출 시 기존 verdict format이 무손상함도 검증. (review issue b7e20f91 대응)
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
    ├── test_reviewing_spec_design_routing.py                 # NEW: L5 routing rows 검증 + behavior (design mode dispatch prompt에 mode 토큰)
    ├── test_spec_reviewer_design_checklist.py                # NEW: AC7 behavior assertion (design mode 호출 시 issue 카테고리 출현)
    ├── test_state_path_worktree.py                           # NEW: state_path helper가 worktree에서 main repo root 반환
    ├── test_state_path_fallback.py                           # NEW: git 부재 시 cwd fallback + loud log
    └── test_state_cleanup.py                                 # NEW: 24h/7일 TTL auto-purge 동작
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
- **V8**: `python3 -m pytest plugins/spec-distill/tests/test_spec_reviewer_design_checklist.py -v` — AC7 behavior (design mode prompt 호출 시 reviewer 출력에 design-relevant 카테고리 출현 + spec mode regression 안전).
- **V9**: `python3 -m pytest plugins/spec-distill/tests/test_state_cleanup.py -v` — 24h pending_review purge + 7일 file auto-delete 검증.

## Rejected Alternatives

- **R1 — UserPromptSubmit이 Stop hook을 대체 (single-layer 단독)**: Stop 제거하고 reminder만 남기는 안. 사유: brainstorming 같은 multi-turn 외부 flow에서는 turn boundary가 분리되어 있어 reminder도 fire 시점 보장 안 됨. **두 layer 모두 필요** — Stop은 즉시 mandate, reminder는 follow-up redundancy.
- **R2 — Hook이 spec-reviewer agent 직접 invoke (shell→Claude API)**: shell이 agent orchestration을 우회. devbrew Law 2의 *물리적 분리* 원칙 위배 + Claude의 tool 트래킹/감사 경로 이탈. **거절**.
- **R3 — brainstorming SKILL.md 편집해서 terminal step에 reviewing-spec 추가**: cross-plugin 결합. brainstorming은 superpowers 소속이라 우리가 ship 안 함 → drift 위험 + 사용자 환경별 버전 차이로 silent miss.
- **R4 — PostToolUse가 즉시 dispatch mandate emit (Stop 무관)**: turn 중간이라 Claude가 이미 다음 액션 결정 중일 수 있음. PostToolUse의 systemMessage는 advisory에 적합, mandate는 turn boundary(Stop)에 두는 게 안전.
- **R5 — Pattern matcher만 수정**: v0.3.0에서 design mode 추가로 매칭은 이미 통과. L4(dispatch obedience) / L5(reviewing-spec design 분기)가 미해결이라 부분 fix.

## Open Questions (resolved ledger)

round-1 review(spec-reviewer agent)에서 4개 미해결 질문이 잠복해 있음을 발견. 모두 round-2에서 LD/Constraint/Non-goal로 승격하여 박제 완료. 본 섹션은 *질문이 어디로 흡수되었는지의 ledger*로 보존 — 미래 reviewing-spec에서 stagnation 오인 방지를 위해 헤더에 "resolved ledger" 명시.

- **OQ1 (mandate obedience 강제 메커니즘)**: "Stop hook mandate를 Claude가 obey하지 않으면?" → **C7로 흡수**. hard mechanism 없음 — best-effort + L4b redundancy. 둘 다 무시되는 경우는 사용자 의도(kill switch)로 간주하고 C8의 cleanup 정책으로 누적 방지.
- **OQ2 (state TTL spam/stale)**: "UserPromptSubmit reminder TTL 30s 만료 후 stale state 처리?" → **C8로 흡수**. pending_review `triggered_at` > 24h → auto-purge. last_dispatched_at만 있는 state → 7일 후 파일 단위 auto-delete.
- **OQ3 (session_id 해석 우선순위)**: "frontmatter session_id vs hook runtime session_id 충돌?" → **C9로 흡수**. env → conducting-interview 박은 ID → "default" 순서. frontmatter는 참조하지 않음.
- **OQ4 (reviewer가 worktree_path를 어떻게 활용?)**: "reviewing-spec이 main repo cwd로 돌아왔을 때 spec 절대경로 보존?" → **G7/LD12로 흡수**. pending_review.path가 이미 절대경로이므로 worktree_path는 advisory(사용자 통보용). reviewer는 path만으로 동작.

## Concrete Next Action

**현재 review status가 approved 인지 needs_revise 인지에 따라 분기.**

- **approved**: 다음 단계 `superpowers:writing-plans` skill 호출 (이 design을 기반으로 step-by-step 구현 plan 작성).
  - Spec 경로: `docs/superpowers/specs/2026-05-17-spec-distill-design-mode-trigger-design.md`
  - Plan 산출물: `docs/superpowers/plans/2026-05-17-spec-distill-design-mode-trigger.md`
  - 명령: `/superpowers:writing-plans` (현 session 내 chained invocation)
- **needs_revise**: 다음 단계 brainstorming author(현 session의 메인 agent)가 reviewer의 issue 목록을 design.md에 반영. 수정 후 같은 turn 또는 다음 turn에서 reviewing-spec 재dispatch — `Agent({subagent_type: "spec-distill:spec-reviewer", prompt: "previous_issues=[<id list>]; review design.md 재검토"})`. routing table의 rereview_count guard(<3)에 따라 3회 초과 시 Human Gate로 forced escalate.
- **needs_interview**: spec-distill의 `/interview` 명령으로 회귀하여 ambiguous dimension 추가 인터뷰. design mode에서는 거의 발생하지 않음(brainstorming이 이미 인터뷰 기능 일부 수행).
