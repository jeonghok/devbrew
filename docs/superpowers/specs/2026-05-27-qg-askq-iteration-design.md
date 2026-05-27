---
name: qg-askq-iteration
version: 2.0.0
created_at: 2026-05-27
session_id: brainstorm-2026-05-27
status: locked
next_phase: writing-plans
source: superpowers/brainstorming (2026-05-27 세션) + quality-gates v1.x 현재 surface
locked_decisions:
  - direction: "Stop hook 기반 iteration 제거 + SKILL 단일 턴 시리얼 디스패치"
  - iteration_mechanism: "AskUserQuestion (tool call, 같은 턴 내 사용자 응답)"
  - happy_path: "Variant A — PASS는 한 줄 요약 후 자동 진행, AskUserQuestion은 결정 지점에서만"
  - gate2_iter_boundary: "매 iter 끝에서 AskUserQuestion (Retry / Proceed to Gate 3 / Stop)"
  - state_file: "단순화 (cross-turn pipeline state 제거; minimal GC metadata만 유지)"
  - version_bump: "v2.0.0 (breaking — hook/state/model contract 모두 변경)"
---

# quality-gates v2.0.0 — AskUserQuestion-Driven In-Turn Iteration

> **For agentic workers:** 본 문서는 `quality-gates` 플러그인 v1.x → v2.0.0 메이저 재설계 명세이다. Stop hook이 turn-end를 거부하고 가짜 user-message를 주입해 게이트를 진행시키던 메커니즘을 제거하고, **단일 어시스턴트 턴 안에서 SKILL이 Gate 1 → Gate 2 → Gate 3를 시리얼 디스패치**하는 구조로 전환한다. 게이트 간 진행 결정과 Gate 2 fix-loop iteration 경계는 **AskUserQuestion tool call**로 표면화된다 (같은 턴 안에서 사용자 응답을 받음). 결과적으로 `<qg-signal>` 태그, `# QG-STOP-HOOK-CONTINUATION` sentinel, 13-transition state machine, wall-clock budget guard, no-signal counter 등 hook 기반 autonomy를 떠받치던 인프라가 일괄 제거되어 stop-hook.py 1205줄이 사라진다. 다음 단계는 `superpowers:writing-plans` skill로 implementation plan을 생성하는 것이다.

## Handoff Context

> 이 design을 처음 보는 사람(또는 /compact 후 자기 자신)이 30초에 핵심 파악할 수 있게. 본문에 self-contained.

**TL;DR**: `quality-gates` v2.0.0은 (1) `hooks/stop-hook.py`와 동반 `<qg-signal>`/sentinel/state-machine 인프라를 일괄 제거하고 SKILL이 단일 턴에서 세 게이트를 시리얼 디스패치하도록 재구성, (2) 게이트 boundary 및 Gate 2 fix-loop iteration 경계의 진행 결정을 `AskUserQuestion` tool call로 옮긴다. Happy path(전 게이트 PASS)는 0 클릭이며, AskUserQuestion은 Gate 1 FAIL, Gate 2 iter boundary(매번), Gate 3 NEEDS_RESOLUTION에서만 fire한다.

**Implicit context** (Constraints에 안 박힌, 작업 진행에 필요한 외부 사실):

- Claude Code의 `AskUserQuestion`은 tool call이므로 응답이 같은 어시스턴트 턴 안의 tool result로 돌아옴 — 별도 턴 boundary를 만들지 않는다. 이게 Stop hook fake-user-message가 불필요해진 핵심 이유. **확정 근거**: (1) CC 시스템 프롬프트에 노출되는 `AskUserQuestion` 도구 스키마 자체에 "User answers collected by the permission component"가 명시되어 tool result로 반환됨, (2) devbrew 자체 P22 instantiation 운영 사례 (`quality-pipeline` v1.x SKILL이 fan-out ≥4 시 같은 턴에서 호출 후 dispatch 분기 — production 동작 검증됨). harness/모델 버전 변경 시 본 전제가 깨지면 본 재설계 전체가 무효 — plan 단계 첫 task로 V0 smoke test 1회 필수 (Verification Plan V0 참조).
- Stop hook의 `reason` 필드는 CC API상 user-message 채널로만 주입 가능. system-channel continuation은 native하게 없음. 따라서 hook을 통한 "정직한" continuation은 불가능 — hook을 유지하는 한 fake-user-message 구조는 피할 수 없다.
- 기존 `forward-only` 결정(v1.5.0, cross-gate restart 제거)은 본 재설계의 전제. NEEDS_RESTART에서 Gate 1 자동 재진입 시나리오는 이미 존재하지 않음.
- 외부 플러그인(`pr-review-toolkit`, `feature-dev`, `superpowers`, `chrome-devtools-mcp`) 인터페이스는 일체 변경 없음 — reviewer agent들은 그대로 dispatch됨.
- `quality-gates` v1.x state file을 가진 user의 in-flight pipeline은 SessionStart advisor가 안내해 `/cancel-qg`로 정리 — auto-migration 미제공 (의도적; legacy state machine에 의존하는 자동 변환 자체가 복잡도 증가).

**Deferred to plan**:

- `hooks/post-tool-use.py`(gh pr create 안내)의 코드 변경 *불요* (본 spec에서 KEEP 확정). advisor 변경 범위는 본 spec C9 + AC14에서 잠금.
- 사용자가 AskUserQuestion 응답으로 "Stop" 선택 시 partial pipeline의 final summary 포맷 (텍스트 템플릿).
- `tests/test_skill_orchestration.sh`의 정확한 fixture 행렬 (4 시나리오 각각의 mock SKILL.md instruction line 패턴 — 본 spec V6에서 정적 grep 접근 *방식*만 lock, fixture 행렬은 plan).
- README 신규 ASCII 시퀀스 다이어그램의 정확한 줄 구성 (본 spec G5에서 *형태*만 lock).

## Context / Why

`quality-gates` v1.x는 Stop hook을 iteration engine으로 사용한다:

1. 사용자가 `/qg` 호출 → SKILL이 Gate N 실행 → `<qg-signal>` 태그 emit → Stop event 발화
2. `hooks/stop-hook.py`가 transcript에서 signal 파싱 → `compute_transition()`로 다음 상태 계산 → `{"decision": "block", "reason": next_gate_prompt}` 반환
3. CC harness가 `reason`을 다음 턴 user message로 주입 → SKILL이 `# QG-STOP-HOOK-CONTINUATION` sentinel을 감지해 continuation 분기 진입 → Gate N+1 실행

이 구조의 어색함:

- **의미 불일치**: Stop event는 "어시스턴트 턴 종료"인데 qg는 그 종료를 막고 다음 prompt를 위조해 새 턴을 시작한다. 모델 입장에서 "방금 끝났는데 사용자가 자동으로 다음 명령을 보낸 것처럼" 보인다.
- **모델 ↔ hook 계약이 magic-string**: `<qg-signal>` 태그, `# QG-STOP-HOOK-CONTINUATION` sentinel을 모델이 정확히 emit/감지해야 함. 모델이 signal을 까먹으면 `consecutive_no_signal` 카운터로 N회 재주입 (P18 unbounded autonomy 방어).
- **State machine 비대화**: 13 transition type(`next_gate`, `retry_gate`, `complete`, `abort`, `continue`, `gate2_user_choice`, `max_gate2_exceeded`, `gate3_fail`, `gate3_needs_resolution`, `gate3_repeat_detected`, `wall_clock_exceeded`, `no_signal_inc`, `no_signal_max`)이 hook-driven autonomy 안전 가드 누적으로 형성. 각 가드 자체는 합리적이지만, "hook이 자율적으로 게이트를 진행시킨다"는 전제가 없으면 대부분 불필요.

CC API에서 `AskUserQuestion`이 tool call로 동작한다는 사실(같은 턴 안의 tool result로 사용자 응답이 돌아옴)은 이 모든 마찰을 우회할 수 있는 primitive를 제공한다. devbrew는 이미 P22(subagent spray) 회피에서 AskUserQuestion을 consent gate로 쓰고 있어, 본 재설계는 **그 패턴을 progression gate로 일반화**하는 것에 불과하다 — 새 P# 도입 없이 기존 원칙 흡수(memory: `feedback_devbrew_design_lightness`).

## Goals

- **G1**: `hooks/stop-hook.py`(현재 1205 LOC) 및 `hooks/hooks.json`의 Stop 항목을 완전히 제거하고, `quality-pipeline` SKILL이 단일 어시스턴트 턴 안에서 Gate 1 → Gate 2 → Gate 3을 시리얼 디스패치하도록 재구성.
- **G2**: 게이트 boundary 및 Gate 2 fix-loop iteration 경계의 진행 결정을 `AskUserQuestion` tool call로 표면화. Happy path(전 게이트 PASS)는 0 사용자 클릭으로 끝남.
- **G3**: `<qg-signal>` 태그 emission 규약, `# QG-STOP-HOOK-CONTINUATION` sentinel, `compute_transition()` 13-type state machine, `consecutive_no_signal` 카운터, `DEVBREW_QG_NO_SIGNAL_MAX`, wall-clock budget(`DEVBREW_QG_DEADLINE_MIN`)를 일괄 제거.
- **G4**: 기존 reviewer agent의 Law 2 frontmatter scoping(`disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]`) 및 외부 플러그인 dispatch 인터페이스(`pr-review-toolkit`, `feature-dev`, `superpowers`, `chrome-devtools-mcp`)는 변경 없음.
- **G5**: `plugin.json`을 v2.0.0으로 bump하고 `CHANGELOG.md`에 Added/Changed/Removed/Breaking을 명시. README의 Hook 표·게이트 흐름·state 다이어그램을 신규 구조로 교체 — 신규 다이어그램은 v1.x의 mermaid `stateDiagram-v2`(13 transition)를 *대체*하는 단순 ASCII 시퀀스로, **단일 어시스턴트 턴 boundary를 명시적으로 라벨링**(`┌─ single assistant turn ────────────┐` 형태 박스)하고 내부에 `setup-qg.sh → SKILL preflight → Gate 1 dispatch → [verdict 분기 with AskUserQuestion on FAIL] → Gate 2 dispatch + iter loop with AskUserQuestion at each boundary → [Gate 3 dispatch + NEEDS_RESOLUTION AskUserQuestion if applicable] → final summary`의 7-step 시퀀스를 표시. (정확한 줄 art는 plan 단계 산출물.)

## Non-goals

- **NG1**: Gate 1 plan-verifier, Gate 2 scout/adversarial/synthesizer, Gate 3 runtime-verifier의 **내부 로직** 재설계 ❌ (오케스트레이션만 변경; agent 페르소나·output 포맷은 그대로).
- **NG2**: `/qg branch <name>` worktree 모드 동작 변경 ❌ (setup-qg.sh 워크트리 생성 로직, qg-worktree.sh 그대로).
- **NG3**: 외부 플러그인 통합(project-init 등) 인터페이스 변경 ❌.
- **NG4**: v1.x state file에서 v2.0.0 state file 형식으로의 auto-migration 도구 제공 ❌ (SessionStart advisor가 legacy 감지 시 `/cancel-qg` 안내만; 자동 변환은 의도적으로 미제공 — legacy state machine에 의존하는 도구 자체가 복잡도 증가).
- **NG5**: Trivia escape 감지기(`scripts/check-trivia.sh`)의 trivia kind coverage 확장 ❌ (별도 spec `2026-05-17-qg-tier2-3-improvements-design.md` 영역).
- **NG6**: `cost_class: variable` 산정 모델 변경 ❌ (Gate 비용 구조 동일).

## Constraints

- **C1**: 본 재설계로 인해 어떤 reviewer agent도 `Write`/`Edit` 권한을 얻으면 안 됨 (Law 2 — Writer ≠ Reviewer). 오케스트레이터(SKILL)는 **writer 역할로 명시 분류**되며, Gate 2 fix-loop의 "Retry" 선택 시 SKILL 본인이 `Edit`/`Write` 도구로 직접 fix를 적용함. **Law 2 무결 논증** (명시 lock — OQ로 defer하지 않음): (i) Law 2 분리의 본질은 "리뷰 verdict를 *낸 턴* = 코드를 *쓰는 턴*" 금지이며 devbrew 철학이 이를 frontmatter `disallowedTools`로 *물리적* 강제. (ii) 본 설계에서 모든 verdict 산출 agent(`plan-verifier`/`scout`/`adversarial`/`synthesizer`/`codex-reviewer`/`security-reviewer`/`runtime-verifier`/`test-scope-validator`)는 별도 subagent로 dispatch되고 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 유지 (AC13). (iii) 오케스트레이터 SKILL은 *verdict를 산출하지 않고* 단지 verdict를 받아 다음 단계로 분기 + 사용자 승인된 fix를 적용 — 리뷰어가 아님. 따라서 SKILL이 `Write`/`Edit` 권한을 가지는 것은 Law 2 위반이 아니며 **이 결정은 spec 단계에서 locked, plan에서 재고 대상 아님**.
- **C2**: Gate 3 NEEDS_RESOLUTION의 secret 처리 정책(P21 — 비밀 값을 prompt에 안 받음)은 변경 없이 유지. AskUserQuestion은 yes/no/path만 묻고, 사용자가 disk의 `.env` 등에 직접 추가 후 "Yes, retry" 선택.
- **C3**: `MAX_GATE3_RESOLUTIONS_CAP=10` 및 기본값 3(env override `DEVBREW_GATE3_MAX_RESOLUTIONS=0..10`)은 유지. in-loop이라도 무한 NEEDS_RESOLUTION 루프 방지(P18).
- **C4**: Gate 2 fix-loop의 `max_gate2_iterations=5` cap은 유지. 매 iter 경계 AskUserQuestion에 더해, **iter 5 직후(5회 완료 시) 별도 max-iter AskUserQuestion이 fire** — 문구 "Gate 2 reached max 5 iterations. Last findings: \<summary\>. Proceed to Gate 3 or stop?" + 2-옵션(`Proceed to Gate 3` / `Stop`). silent termination을 금지하여 P18(unbounded autonomy)을 consent termination으로 만족. v1.x의 "5회 도달 시 silent halt" 경로는 제거.
- **C5**: `DEVBREW_DISABLE_QUALITY_GATES=1` 전역 kill switch는 동작해야 함 — SKILL preflight에서 검사 후 즉시 종료.
- **C6**: `cost_class: variable` 선언(SKILL frontmatter) 유지. `cost_class: high`로 escalation 없음 — AskUserQuestion이 비용 의사결정 gate를 자연스럽게 제공.
- **C7**: Plugin Shape 충족: `plugin.json` v2.0.0 bump, `CHANGELOG.md`에 SemVer breaking 항목 추가, README "Principles Instantiated" 섹션 갱신.
- **C8**: Korean-primary 문서 규정 준수(memory: `feedback_devbrew_korean_primary_docs`). 영어는 식별자/고유명사/원문 인용/번역 어색한 기술 용어에만.
- **C9 (advisor scope lock)**: `hooks/session-start-advisor.py`의 변경 범위는 정확히 *in-flight pipeline 감지 분기 제거 + legacy v1.x state file 1회 stderr 안내 emit* 두 가지에 한정. **frontmatter scan 기능**(`scan_agent_frontmatter_keys` 또는 동등 함수 + `tests/test_agent_frontmatter_keys.sh` 동반)은 **코드 변경 없이 유지**. 기타 `hooks/post-tool-use-session-tracker.py`, `hooks/post-tool-use.py`, `hooks/session-end-cleanup.py`는 일체 변경 없음.

## Acceptance Criteria

- **AC1**: `hooks/stop-hook.py` 파일이 삭제되어 있음 (`test ! -f plugins/quality-gates/hooks/stop-hook.py`).
- **AC2**: `hooks/hooks.json`에 `Stop` event 항목이 존재하지 않음 (`! jq -e '.hooks.Stop' plugins/quality-gates/hooks/hooks.json`).
- **AC3**: `skills/quality-pipeline/SKILL.md`에 `<qg-signal>` 태그 emission 지시문이 없음 (`! grep -q '<qg-signal>' plugins/quality-gates/skills/quality-pipeline/SKILL.md`).
- **AC4**: `# QG-STOP-HOOK-CONTINUATION` sentinel 문자열이 plugins 트리 어디에도 없음 (`! grep -r 'QG-STOP-HOOK-CONTINUATION' plugins/quality-gates/`).
- **AC5**: SKILL의 Gate Execution 섹션이 Gate 1 → Gate 2 → Gate 3을 명시적으로 시리얼 호출하는 의사코드/실제 instruction을 포함하며, **호출 순서가 텍스트상 단조 증가**. 자동 검증: `awk '/Gate 1/{if(!g1)g1=NR} /Gate 2/{if(!g2)g2=NR} /Gate 3/{if(!g3)g3=NR} END{exit !(g1 && g2 && g3 && g1<g2 && g2<g3)}' plugins/quality-gates/skills/quality-pipeline/SKILL.md` exit 0 (각 라벨의 *첫* 등장 줄 번호가 1 < 2 < 3 순).
- **AC6**: Gate 2 fix-loop가 매 iter 끝에서 `AskUserQuestion` 호출을 지시하며, 3-옵션(`Retry` / `Proceed to Gate 3` / `Stop`)을 명시. 자동 grep smoke: 세 라벨 문자열 모두 SKILL.md에 등장 (V2b 참조).
- **AC7**: Gate 1 FAIL 시 AskUserQuestion 호출 + 3-옵션(`Continue anyway` / `Stop` / `View detail`) 명시. 자동 grep smoke: 세 라벨 문자열 모두 SKILL.md에 등장.
- **AC8**: Gate 3 NEEDS_RESOLUTION 시 AskUserQuestion 호출 + 3-옵션(`Yes, retry` / `Skip with evidence` / `Stop`) 명시 + P21 secret-not-in-prompt 정책 재확인 문구 포함. 자동 grep smoke: 세 라벨 + `P21` 토큰 모두 SKILL.md에 등장.
- **AC9**: `DEVBREW_QG_DEADLINE_MIN`, `DEVBREW_QG_NO_SIGNAL_MAX` 환경변수 처리 코드가 SKILL/scripts/hooks에서 제거됨 (`! grep -r 'DEVBREW_QG_DEADLINE_MIN\|DEVBREW_QG_NO_SIGNAL_MAX' plugins/quality-gates/`).
- **AC10**: `compute_transition`, `extract_last_signal`, `extract_signal_from_hook_input`, `consecutive_no_signal`, `compute_no_signal_transition` 등 stop-hook 관련 식별자가 plugins 트리에 없음 (`! grep -rn 'compute_transition\|consecutive_no_signal' plugins/quality-gates/`).
- **AC11**: `plugin.json`의 `version`이 `2.0.0`이고, `CHANGELOG.md`에 `## [2.0.0] — 2026-MM-DD` 섹션이 Added/Changed/Removed/Breaking을 포함하며 `hooks/stop-hook.py` 제거와 `<qg-signal>`/sentinel 제거를 명시.
- **AC12**: README의 "설치된 Hook" 표에서 `stop-hook.py` 행이 제거(`! grep 'stop-hook.py' plugins/quality-gates/README.md`), v1.x mermaid `stateDiagram-v2` 블록이 제거(`! grep -q 'stateDiagram-v2' plugins/quality-gates/README.md`), 신규 ASCII 시퀀스 다이어그램에 "single assistant turn" 라벨 등장(`grep -q 'single assistant turn' plugins/quality-gates/README.md`), "Principles Instantiated"에 P22 일반화 문구 추가(`grep -qE 'progression primitive|progression gate' plugins/quality-gates/README.md`).
- **AC13**: 기존 reviewer agent(`plan-verifier`, `scout`, `adversarial`, `synthesizer`, `codex-reviewer`, `security-reviewer`, `runtime-verifier`, `test-scope-validator`)의 frontmatter `disallowedTools` 선언이 그대로 유지됨 (Law 2 무결).
- **AC14 (C9 잠금 검증)**: `hooks/session-start-advisor.py`의 in-flight pipeline 감지 코드 경로가 제거됨 (`! grep -qE 'pipeline_status|current_gate|in_flight_pipeline' plugins/quality-gates/hooks/session-start-advisor.py`). 동 hook의 frontmatter scan 함수는 그대로 유지(`grep -qE 'frontmatter|scan_agent' plugins/quality-gates/hooks/session-start-advisor.py`). `hooks/post-tool-use-session-tracker.py`, `hooks/post-tool-use.py`, `hooks/session-end-cleanup.py`는 코드 diff 없음 (`git diff --quiet HEAD~ -- plugins/quality-gates/hooks/post-tool-use*.py plugins/quality-gates/hooks/session-end-cleanup.py` exit 0).
- **AC15**: `tests/` 디렉토리에서 stop-hook/state-machine 전용 테스트(`test_*stop_hook*`, `test_*transition*`, `test_no_signal*`)가 제거되거나 신규 SKILL 오케스트레이션 테스트로 대체됨.
- **AC16**: SessionStart advisor가 legacy v1.x state file(`current_gate`/`consecutive_no_signal` 등 신규 schema에 없는 키 보유) 감지 시 사용자에게 `/cancel-qg`로 정리 안내를 1회 emit (read-only, mutation 없음).
- **AC17**: 다음 3개 명령의 동작을 v2.0.0 minimal state schema 상에서 확정 (각각 fixture 폴더로 검증, 검증 명령은 V10):
  - `/cancel-qg`: `.claude/quality-gates/$CLAUDE_CODE_SESSION_ID/` 폴더가 존재하면 `rm -rf` 후 "Quality-gates session state cleared." stdout emit. 폴더 없으면 no-op + exit 0.
  - `/qg --reset`: 위와 동일 + 추가로 legacy v1.x flat state file(`.claude/quality-gates.local.md`, `.claude/quality-gates-session.local.md`, `.claude/quality-gates-branch.local.md`, `.claude/qg-diff-cache.txt`, `.claude/qg-code-paths.tmp`) `rm -f`. 종료 후 "Quality-gates state cleared." stdout emit.
  - `/qg --gc`: `python3 plugins/quality-gates/scripts/qg-gc.py` 호출 — `DEVBREW_QG_TTL_HOURS`(기본 24)보다 mtime이 오래된 sibling 폴더 일괄 제거. v1.x와 알고리즘 동일.
- **AC18**: 사용자가 happy path 시나리오(trivia가 아닌 3-게이트 PASS)를 실행했을 때 AskUserQuestion이 단 한 번도 호출되지 않음 — V7 reproducible checklist로 검증.

## Files to Modify

```
plugins/quality-gates/
├── .claude-plugin/plugin.json                     [MODIFY] version: "1.x" → "2.0.0"
├── CHANGELOG.md                                   [MODIFY] ## [2.0.0] — YYYY-MM-DD 섹션 추가
├── README.md                                      [MODIFY] Hook 표 / 파이프라인 흐름 / state 다이어그램 / Principles Instantiated / Tuning knobs 표 갱신
├── hooks/
│   ├── hooks.json                                 [MODIFY] Stop event 항목 삭제
│   ├── stop-hook.py                               [DELETE] (1205 LOC 제거)
│   ├── post-tool-use-session-tracker.py           [KEEP]
│   ├── post-tool-use.py                           [KEEP]
│   ├── session-start-advisor.py                   [MODIFY-NARROW] (C9 잠금) in-flight pipeline 감지 분기 제거(`pipeline_status`/`current_gate`/`in_flight_pipeline` 참조 코드 삭제) + legacy v1.x state file 감지 시 1회 stderr 안내 emit. frontmatter scan 함수는 변경 없이 유지
│   └── session-end-cleanup.py                     [KEEP]
├── skills/quality-pipeline/
│   ├── SKILL.md                                   [REWRITE-LARGE] preflight + Gate 1 → Gate 2 (with iter loop) → Gate 3 시리얼 디스패치; AskUserQuestion 호출 지점 명시; <qg-signal> 규약 / sentinel / 13-transition 문서 일괄 제거
│   └── references/
│       ├── dependency-check.md                    [KEEP]
│       └── state-file-format.md                   [MODIFY] 단순화된 frontmatter 스키마 (worktree_path, gate2_iteration tally, started_at만)
├── scripts/
│   ├── setup-qg.sh                                [MODIFY] 신규 state file 스키마 (단순) 생성; wall-clock deadline / no-signal 카운터 초기화 제거
│   ├── pre-pipeline-check.sh                      [MODIFY] cross-turn state 검사 로직 축소
│   ├── check-trivia.sh                            [KEEP]
│   ├── filter-docs.sh                             [KEEP]
│   ├── discover-plan.sh                           [KEEP]
│   ├── detect-runtime.sh                          [KEEP]
│   ├── compute-test-scope-candidates.sh           [KEEP]
│   ├── detect_codex.sh                            [KEEP]
│   ├── build_codex_prompt.py                      [KEEP]
│   ├── codex_findings_to_yaml.py                  [KEEP]
│   ├── synthesize_findings.py                     [KEEP]
│   ├── run_codex_reviewer.sh                      [KEEP]
│   ├── scout.py                                   [KEEP]
│   ├── qg-gc.py                                   [KEEP]
│   └── qg-worktree.sh                             [KEEP]
├── commands/
│   ├── qg.md                                      [MODIFY] "Stop hook handles pipeline progression" 문구 제거; SKILL이 단일 턴에서 끝까지 진행한다는 설명으로 교체; 표의 Pipeline Rules 섹션 갱신
│   └── cancel-qg.md                               [MODIFY] orphan state cleanup 유틸 역할로 문구 정리
├── agents/                                        [NO CHANGE] (모든 agent frontmatter scoping 유지)
└── tests/                                         [MODIFY-LARGE]
    ├── test_*stop_hook*                           [DELETE]
    ├── test_*transition*                          [DELETE]
    ├── test_no_signal*                            [DELETE]
    ├── test_adversarial_model_consistency.sh      [KEEP]
    ├── test_agent_frontmatter_keys.sh             [KEEP]
    ├── test_discover_plan.sh                      [KEEP]
    ├── test_branch_worktree.sh                    [KEEP]
    ├── test_no_secret_prompts.py                  [KEEP]
    └── test_skill_orchestration.sh                [NEW] **정적 SKILL.md instruction grep 방식** (V6 (a) approach, lock됨 — 실제 CC harness subprocess 호출은 v2.0.0 first-pass 범위 외). 4 시나리오 각각이 SKILL.md에서 해당 instruction 패턴을 grep으로 찾을 수 있는지 검증: (1) happy-path serial dispatch instruction 존재 + AskUserQuestion 호출 마커가 PASS 경로에 없음, (2) Gate 2 iter boundary AskUserQuestion + 3-옵션 라벨, (3) Gate 1 FAIL AskUserQuestion + 3-옵션 라벨, (4) Gate 3 NEEDS_RESOLUTION AskUserQuestion + 3-옵션 라벨 + P21 토큰. 정확한 grep 패턴 행렬은 plan 단계 fixture로 산출
```

## Verification Plan

- **V0 (premise verification — plan 단계 첫 task, implementation 착수 전 1회 필수)**: AskUserQuestion이 같은 어시스턴트 턴 내 tool result로 응답을 반환하는 전제를 smoke test. 절차: (a) 임시 SKILL stub 작성 (`/tmp/qg-v0-smoke.md`) — `AskUserQuestion` 호출 직후 같은 응답 안에서 `Bash(echo same-turn)` 호출, (b) Claude Code에서 stub 호출, (c) trace 확인: `AskUserQuestion` tool result가 도착한 *같은* assistant message 안에 `Bash` tool call이 있어야 함. 실패 시 (즉 AskUserQuestion 응답이 별도 턴으로 떨어짐) 본 spec 전체가 무효이며 plan/implementation 중단 — R1(continuation 명시화) 또는 R2(user-driven)로 재설계 회귀 필요.
- **V1**: AC1–AC4, AC9, AC10 일괄 검증 — `bash` 스크립트로 grep/test 명령 실행:
  ```bash
  test ! -f plugins/quality-gates/hooks/stop-hook.py && \
  ! jq -e '.hooks.Stop' plugins/quality-gates/hooks/hooks.json > /dev/null && \
  ! grep -rqE '<qg-signal>|QG-STOP-HOOK-CONTINUATION|compute_transition|consecutive_no_signal|DEVBREW_QG_DEADLINE_MIN|DEVBREW_QG_NO_SIGNAL_MAX' plugins/quality-gates/
  ```
- **V2a (AC5 자동 순서 검증)**:
  ```bash
  awk '/Gate 1/{if(!g1)g1=NR} /Gate 2/{if(!g2)g2=NR} /Gate 3/{if(!g3)g3=NR} END{exit !(g1 && g2 && g3 && g1<g2 && g2<g3)}' \
    plugins/quality-gates/skills/quality-pipeline/SKILL.md
  ```
  exit 0이면 PASS.
- **V2b (AC6/AC7/AC8 grep smoke)**: SKILL.md에 옵션 라벨 + P21 토큰 일괄 존재 검증:
  ```bash
  S=plugins/quality-gates/skills/quality-pipeline/SKILL.md
  for label in "Continue anyway" "View detail" "Retry" "Proceed to Gate 3" "Yes, retry" "Skip with evidence"; do
    grep -q -- "$label" "$S" || { echo "missing label: $label"; exit 1; }
  done
  grep -q "P21" "$S"
  ```
  exit 0이면 PASS.
- **V2c (AC6–AC8 보조 수동 검수)**: 자동 grep PASS 후 사람이 SKILL.md를 읽고 *호출 컨텍스트*(어느 verdict 직후 어느 옵션이 fire하는지) 적합성을 검수. 자동 grep은 문자열 존재만 보장하므로 호출 시점 맥락은 수동 보조 필요.
- **V3 (AC11)**: `jq -r .version plugins/quality-gates/.claude-plugin/plugin.json`이 `"2.0.0"` 출력. `grep -c '^## \[2.0.0\]' plugins/quality-gates/CHANGELOG.md`가 ≥1.
- **V4 (AC12)**:
  ```bash
  R=plugins/quality-gates/README.md
  ! grep -q 'stop-hook.py' "$R" && \
  ! grep -q 'stateDiagram-v2' "$R" && \
  grep -q 'single assistant turn' "$R" && \
  grep -qE 'progression primitive|progression gate' "$R"
  ```
- **V5 (AC13)**: 모든 agent 파일의 frontmatter에 `disallowedTools` 키가 변경 없이 존재:
  ```bash
  for a in plugins/quality-gates/agents/*.md; do
    grep -q 'disallowedTools' "$a" || { echo "missing: $a"; exit 1; }
  done
  ```
- **V6 (AC15 — mock 접근 방식 lock)**: `ls plugins/quality-gates/tests/`에 deleted 패턴(`*stop_hook*`, `*transition*`, `*no_signal*`)이 없고 `test_skill_orchestration.sh` 존재. 본 spec은 mock 접근으로 **(a) 정적 SKILL.md instruction grep 방식**을 채택 — V2a/V2b/V2c가 이미 정적 grep을 수행하므로, `test_skill_orchestration.sh`는 V2a+V2b+V2c를 1개 스크립트로 묶고 종합 exit code를 반환하는 wrapper로 구현. **(b) 실제 CC harness subprocess 호출 통합 테스트**(`claude-code --prompt /qg ...` → trace parse)는 v2.0.0 first-pass 범위 외 (장점: end-to-end; 단점: CC binary 의존 + 비결정적 + 비용). 검증 명령: `bash plugins/quality-gates/tests/test_skill_orchestration.sh` exit 0.
- **V7 (AC18, reproducible checklist)**: fixture는 본 worktree의 `main` 대비 작은 합성 변경. 절차:
  1. `git checkout -b qg-happy-path-fixture`
  2. `printf '\n<!-- happy-path fixture: harmless content line -->\n' >> plugins/quality-gates/README.md` (단일 파일 단일 commit, ~1 LOC, comment 형식이라 typo trivia 미트리거)
  3. `git commit -am "test: happy-path fixture"`
  4. trivia escape 사전 확인: `bash plugins/quality-gates/scripts/check-trivia.sh`. 출력에 `trivia=` 또는 trivia kind 라벨이 나오면 fixture를 2-line으로 확장 (예: `## happy-path` 헤더 추가 — `comment` trivia kind 우회).
  5. `/qg` 실행.
  6. 검증: 어시스턴트 trace에 `AskUserQuestion` tool call 0회 (`grep -c AskUserQuestion <trace-file>` = 0). 최종 텍스트에 `Gate 1: PASSED`, `Gate 2: PASSED`, `Gate 3:` (verdict) 각 1개씩. 단일 turn 안에서 final summary 도달.
  7. 정리: `git checkout main && git branch -D qg-happy-path-fixture`.
- **V8 (AC16, reproducible legacy-state fixture)**:
  1. `mkdir -p .claude/quality-gates/legacy-test-sid-deadbeef`
  2. fixture state 작성:
     ```bash
     cat > .claude/quality-gates/legacy-test-sid-deadbeef/pipeline.md <<'EOF'
     ---
     session_id: legacy-test-sid-deadbeef
     current_gate: 2
     consecutive_no_signal: 2
     gate2_iteration: 3
     max_gate2_iterations: 5
     ---
     EOF
     ```
  3. SessionStart 트리거: 새 Claude Code 세션 시작 (`claude --new-session` 또는 separate terminal).
  4. 검증: stderr에 `[quality-gates] legacy state file detected` 또는 동등한 패턴 + `/cancel-qg` 안내 1회 emit. 정확한 문구는 plan에서 확정, 본 spec은 (a) `legacy` 토큰 + (b) `/cancel-qg` 문자열 두 가지가 stderr 안에 등장하는 것을 요구.
  5. 정리: `rm -rf .claude/quality-gates/legacy-test-sid-deadbeef`.
- **V9 (regression)**: `tests/test_branch_worktree.sh`, `tests/test_discover_plan.sh`, `tests/test_no_secret_prompts.py`, `tests/test_agent_frontmatter_keys.sh`, `tests/test_adversarial_model_consistency.sh` 모두 PASS.
- **V10 (AC17, /cancel-qg + /qg --reset + /qg --gc fixture 검증)**: 신규 `plugins/quality-gates/tests/test_cancel_qg.sh` 작성. 절차:
  1. fixture: `mkdir -p .claude/quality-gates/test-sid-deadbeef && echo '---' > .claude/quality-gates/test-sid-deadbeef/pipeline.md`.
  2. `/cancel-qg` 시뮬레이션: `bash plugins/quality-gates/commands/cancel-qg.md` 내 명령 추출 실행 (또는 동등 `rm -rf` 호출), 폴더 부재 + stdout에 "session state cleared" 등장 확인.
  3. legacy file fixture: `touch .claude/quality-gates.local.md .claude/quality-gates-session.local.md`. `/qg --reset` 시뮬레이션 실행 후 이들 파일 부재 확인.
  4. TTL fixture: `mkdir -p .claude/quality-gates/old-sid && touch -t 200001010000 .claude/quality-gates/old-sid/pipeline.md`. `python3 plugins/quality-gates/scripts/qg-gc.py` 실행 후 `old-sid` 폴더 부재 확인.

## Rejected Alternatives

- **R1 — Hook을 유지하되 continuation을 명시화** (sentinel 대신 `<qg-continuation gate="2">` 구조적 태그, prompt 앞에 `[quality-gates auto-continuation]` 표기): 사용자가 답변에서 명시적으로 거부. 구조적 부자연스러움의 root cause인 "Stop event로 turn-end를 거부하는 메커니즘 자체"는 그대로라 표면적 개선에 그침.
- **R2 — Hook 제거 + user-driven progression** (게이트마다 `/qg next` 명시 입력): 자동화 가치 상실. 한 PR 검증에 3-5번 명령 입력 강제. Brainstorming Q2에서 사용자가 거부.
- **R3 — Always-confirm progression** (Variant B; 모든 게이트 boundary에 AskUserQuestion): happy path도 3-5 클릭 필요. 자동화 이점 상실. Brainstorming Q3에서 사용자가 거부.
- **R4 — Gate 3 진입 직전에도 AskUserQuestion** (Variant C; 브라우저 MCP/runtime setup 비용 의식적 의사결정): 이미 `--skip-runtime` flag가 동일 UX 제공. inline prompt 추가는 redundancy. Brainstorming Q3에서 사용자가 거부.
- **R5 — Subagent orchestrator 패턴** (parent → long-running subagent가 게이트 시리즈 진행): 본 spec 기각의 **primary 이유** — (i) 서브에이전트 비용 (별도 context window 운용 + 모든 verdict 산출 agent 호출이 parent-of-parent 구조가 됨), (ii) 가시성 손실 (중간 verdict가 메인 turn에서 보이지 않고 subagent 최종 summary만 노출되어 사용자가 게이트별 의사결정 정보를 받지 못함), (iii) 본 spec의 단순함 우선 원칙(devbrew lightness)과 충돌. **Secondary 미검증 사항** — AskUserQuestion이 subagent 내에서 정상 동작하는지 (CC 도구 스키마에 해당 제약은 명시 없으나, devbrew는 subagent 내 AskUserQuestion 운영 사례 없음). 이 secondary 사항은 본 spec 기각 근거에 *포함되지 않으므로* 검증 부재가 R5 재고를 강제하지 않음 — 미래에 subagent-AskUserQuestion 동작이 확정되어도 primary (i)–(iii)이 여전히 유효.
- **R6 — Auto-migration tool for v1.x state files** (legacy state 자동 변환 후 신규 schema로 이어 진행): legacy state machine을 이해해야 하는 migration 코드가 그 자체로 stop-hook과 동등한 복잡도. 자동 정리(`/cancel-qg`) 안내만으로 충분 — in-flight pipeline은 본래 단일 세션 단위 작업이므로 user가 재실행 가능.
- **R7 — wall-clock budget guard 유지** (`DEVBREW_QG_DEADLINE_MIN=30`): hook-driven autonomy 안전망. AskUserQuestion이 매 iter 경계에서 in-the-loop user 결정을 제공하므로 wall-clock guard 자체가 redundancy. P18(unbounded autonomy)는 user-consent gate로 더 직접적으로 만족.

## Open Questions

- **OQ1 (tool 선언 best practice)**: `skills/quality-pipeline/SKILL.md`의 신규 `allowed-tools` frontmatter에 `AskUserQuestion`을 명시 선언해야 하는지 (현재 deferred tool로 ToolSearch 통해 로드됨). 본 spec의 *전제 검증* V0이 통과한 *후*에 결정 — V0이 명시 선언 없이 호출 성공을 확인하면 선언 생략 가능, 호출 실패 시 명시 선언 추가. plan 단계에서 V0 결과에 따라 분기.
- **OQ2 (CLOSED — C1으로 격상)**: ~~Gate 2 fix-loop의 fix 적용 권한~~ → C1에서 orchestrator-as-writer로 lock됨. plan/구현 단계에서 재고 대상 아님.
- **OQ3 (state schema 세부)**: `pipeline.md` minimal schema의 정확한 필드 — `started_at`, `worktree_path`, `gate2_iteration` 외 GC를 위한 mtime anchor가 별도로 필요한가(파일 자체의 mtime으로 충분한가). plan에서 확정. *주의*: AC17 검증 명령은 schema에 직접 의존하지 않고 폴더 부재/존재 + stdout 패턴만 확인하므로 OQ3 미해결이 AC17 검증을 막지 않음.

## Concrete Next Action

다음 단계: `superpowers:writing-plans` skill로 implementation plan 생성.

- Spec 경로: `docs/superpowers/specs/2026-05-27-qg-askq-iteration-design.md`
- Plan 산출물: `docs/superpowers/plans/2026-05-27-qg-askq-iteration.md`
- 명령: `Skill(superpowers:writing-plans)` 호출 시 본 spec 경로 전달
- 작업 브랜치/워크트리: `worktree-feature-qg-askq-iteration` (이미 진입 상태)
- PR base: `main`
