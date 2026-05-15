---
name: spec-distill-hook-review
version: 1.3.0
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
    summary: 'PostToolUse hooks.json matcher = `Write|Edit|MultiEdit` (tool-name regex, not path glob — quality-gates 검증). 경로 필터링은 *script 내부 로직*에서 prefix `docs/superpowers/specs/` + suffix `-spec.md`/`-design.md`로 분기. (G3)'
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
    summary: 'PostToolUse exit 2 + stderr 주입을 차단 메커니즘으로 활용 — quality-gates의 production 사용으로 검증된 패턴. (C2)'
    source: brainstorming-round-1
  - id: LD9
    section: "#constraints"
    summary: 'Layer1 → Layer2 coordination은 transcript signal이 아니라 **state.local.md `pending_review:` 플래그**로 수행 (file-based deterministic ledger). LLM 의지 의존도 0. (C7)'
    source: round-1 review fix
  - id: LD10
    section: "#goals"
    summary: 'Review cap 정책 = **hybrid** — hard cap=5 (이 이상은 무조건 사용자 escalate) + stagnation early-exit (그 전이라도 `Stagnation_signal: true` 나오면 즉시 종료). 기존 cap=3 (reviewing-spec v0.2.0)을 본 spec scope에서 갱신. (G8, C10)'
    source: round-4 lock decision
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
- **G3**: PostToolUse hook의 두 레이어 필터링 — (a) hooks.json `matcher` 필드 = `Write|Edit|MultiEdit` (tool-name regex; quality-gates의 동일 패턴), (b) script 내부에서 `tool_input.file_path` 검사로 prefix `docs/superpowers/specs/` + suffix `-spec.md` 또는 `-design.md` 만 통과. 파일명 suffix가 spec/design 모드 분기 single source of truth.
- **G4**: brainstorming(upstream)을 무수정으로 통합. brainstorming이 `-design.md`를 쓰는 그 순간 hook이 file system level에서 캐치 → 동일 reviewer 파이프라인.
- **G5**: reviewing-spec skill의 *routing table* (verdict×stagnation×rereview_count→next phase, P1–P4 escalation priority, [3.5] re-consensus gate 등)은 무수정 보존. SKILL.md 본문 중 Step 1만 갱신 (state.local.md `pending_review:` 플래그를 trigger source로 명시) — routing 로직은 그대로.
- **G6**: 모든 신규 hook은 kill switch 존중 (`DEVBREW_DISABLE_SPEC_DISTILL=1`, `DEVBREW_SKIP_HOOKS=spec-distill:<event>`, `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`, `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1`).
- **G7**: PostToolUse ↔ Stop hook 간 coordination은 transcript signal이 아닌 **state.local.md 파일 기반 ledger** — LLM 의지/메시지 형식 의존 0. quality-gates의 `<qg-signal>` 패턴 (LLM emit + transcript 파싱) 대신 의도적으로 file ledger 선택해 결정론 강화.
- **G8**: Review cap 정책을 **hybrid**로 갱신 (기존 v0.2.0의 hard cap=3을 본 spec에서 update). 두 가지 조건 중 *하나라도* 충족 시 reviewing-spec이 사용자 escalate로 분기: (a) `rereview_count >= 5` (hard cap), (b) `Stagnation_signal: true` (조기 종료). 이는 *unbounded autonomy* anti-pattern (CLAUDE.md Forbidden Patterns)을 회피하면서 *수렴 중인 review*에 충분한 budget를 부여한다.

## Non-goals

- **NG1**: spec-reviewer agent persona 무수정. 결정론 강화는 hook layer에서만 발생. persona 약화 시도는 보안 리뷰 대상 (CLAUDE.md §Plugin Shape).
- **NG2**: design mode에서 11-section schema는 강제 안 함 — brainstorming의 design.md 포맷 자유도 유지. design mode는 ambiguity + TBD/TODO/placeholder 검출만.
- **NG3**: 신규 review-gate 플러그인 분리하지 않음 (현 단계). spec/design doc review라는 단일 책임이 spec-distill 안에서 자연스러움.
- **NG4**: spec-distill의 기존 UserPromptSubmit/SessionStart hook 동작 변경 없음.
- **NG5**: hook은 **dismiss 상태 추적 / 평가 / 분기를 일체 수행하지 않음**. 자격 경로의 spec/design 파일 Write/Edit는 무조건 fire. issue dismiss 처리 / `dismissed_by_user` 카운터 / P3 stagnation 평가 / P4 persona warn은 100% reviewing-spec skill (기존 v0.2.0 routing table) 책임. hook과 skill의 책임 boundary 명확화: hook = trigger + dispatch enforcement only.
- **NG6**: hook이 spec.md 본문을 직접 수정하는 일은 없음 (Law 2 — Writer 권한은 LLM의 Write tool에만). hook은 exit code + systemMessage + state.local.md 갱신만.

## Constraints

- **C1**: hook script는 5–10s timeout 안에 종료. structural validator는 Python으로 작성 (정규식 기반 파싱), agent dispatch는 systemMessage emit으로 즉시 종료 — 실제 LLM 호출은 다음 turn에서 발생.
- **C2**: PostToolUse exit 2 + stderr 주입은 quality-gates에서 production 사용으로 검증된 차단 패턴 (`plugins/quality-gates/hooks/post-tool-use.py`). 이중 안전을 위해 stdout `{"decision": "block", "reason": "..."}` JSON도 병행 출력 — runtime이 둘 중 하나만 honor해도 차단 보장.
- **C3**: state.local.md는 spec-distill 기존 ledger와 같은 파일. 신규 필드 (`pending_review:`, `last_validated_at:`, `validator_findings:`, `last_mode:`) 추가는 drafting-spec C10의 *in-flight migration* 패턴을 그대로 적용 — non-mutating read promote (필드 부재 시 in-memory default), 다음 write 시점에 frontmatter 추가, backward-rewriting 금지. 기존 hook들은 state.local.md에 키-merge 방식으로 쓰므로 신규 키가 기존 키를 덮지 않음.
- **C4**: hook이 fire하더라도 `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1` 설정 시 Layer 1만 동작하고 Layer 2 (dispatch) skip. 비상시 reviewer cost 회피.
- **C5**: ambiguity blacklist는 hardcoded list가 아니라 `plugins/spec-distill/scripts/ambiguity-blacklist.txt`에 별도 — 사용자 escape syntax (`~` prefix) 지원, false positive 발생 시 PR로 단어 추가/제거.
- **C6**: 다른 plugin의 PostToolUse hook과 공존. user-visible advisory text는 `[spec-distill]` prefix로 네임스페이스 (CLAUDE.md "loud logging" 요건). transcript signal tag는 **사용하지 않음** — Layer 1 → Layer 2 coordination은 C7의 file-based 메커니즘으로.
- **C7**: Layer 1 → Layer 2 coordination은 transcript 파싱이 아니라 **state.local.md `pending_review:` 플래그 파일 기반**으로 수행. PostToolUse가 (i) 검증 통과 시 `pending_review: {path, mode, triggered_at}` 기록, (ii) stdout `systemMessage`로 사용자/LLM에게 advisory 표시. Stop hook은 state.local.md를 직접 읽어서 dispatch 여부 결정 — LLM의 assistant message나 turn 내 상태를 거치지 않음. 이는 quality-gates의 `<qg-signal>` 패턴(LLM이 signal을 emit하고 Stop hook이 transcript 파싱)과 의도적으로 다른 선택 — 우리의 신호는 hook script가 직접 작성하므로 file이 더 결정론적.
- **C8**: Concrete Next Action은 reviewer verdict 분기를 반드시 포함. approved / needs_revise / needs_interview 각각의 다음 명령을 사전 명시.
- **C9**: Plan phase 진입 직전에 quality-gates의 `post-tool-use.py` 차단 동작 + `stop-hook.py`의 systemMessage 주입 동작을 *실제 Claude Code 환경에서* 한 번 smoke test하여 hook output protocol을 empirically 확인. V8.5로 트래킹.
- **C10**: Hybrid review cap 정책 (G8) 구현은 reviewing-spec SKILL.md의 "Re-review cap" 섹션을 갱신: hard cap 값 `>= 3` → `>= 5`, 동시에 Step 5 routing table에 stagnation early-exit 분기 추가 (verdict `needs_revise` + `Stagnation_signal: true` → 즉시 [5] Human Gate, P3 priority와 별개). 기존 P3 row (`raised_count >= 3 AND dismissed_by_user == 0`)는 *per-issue* stagnation이고 새 stagnation early-exit은 *round-level* stagnation으로 다른 trigger.

## Acceptance Criteria

**Convention**: 각 AC<N>은 `test_spec_write_validator.sh` 또는 `test_review_dispatch.sh`의 *case <N>*에 1:1 매핑된다. test script 작성 시 이 매핑을 깨지 않을 것.

- **AC1**: `docs/superpowers/specs/2026-05-16-test-spec.md`에 11 sections + valid frontmatter (locked_decisions 포함) 가진 spec을 작성 → PostToolUse hook script가 exit 0. 동시에 state.local.md에 `pending_review:` block 기록되고 그 안에 `path: <abs path>`, `mode: spec`, `triggered_at: <ISO8601>` 세 필드 존재. (※ "Claude tool result가 'blocked' 표시 안 함"의 검증은 V9 E2E manual로 위임 — shell 단에서 관찰 불가.) 검증: case 1.
- **AC2**: 같은 spec에서 "Goals" 섹션 제거 → PostToolUse hook이 exit 2 + stderr가 substring `missing sections:` 와 substring `#goals` 둘 다 포함 (regex: `missing sections:.*#goals`). state.local.md에 `pending_review:` block은 *기록되지 않음*. 검증: case 2.
- **AC3**: spec 본문 N번째 줄에 `AC1: system works correctly` 포함 (fixture `tests/fixtures/spec-ambiguity-line12.md`로 N=12 fix) → hook이 exit 2 + stderr가 substring `ambiguity hit:`, `line 12`, `works correctly` 셋 다 포함. 검증: case 3.
- **AC4**: 같은 줄을 `AC1: system ~works correctly` (`~` escape prefix)로 작성 → exit 0 + state.local.md `pending_review:` 정상 기록. 검증: case 4.
- **AC5**: 매처 자격 외 파일 (`docs/README.md` 등 spec/design 경로 외) Write 시 hook이 silent exit 0. state.local.md 변경 없음. 검증: case 5.
- **AC6**: `docs/superpowers/specs/2026-05-16-test-design.md` (suffix `-design.md`) 작성 시 frontmatter 없어도 exit 0. ambiguity + placeholder scan은 적용. state.local.md `pending_review:` block의 `mode: design` 기록. 검증: case 6.
- **AC7**: design.md 본문에 `## Goals\n\nTBD` (또는 `TODO`, `tbd`, `<placeholder>`) 포함 시 hook이 exit 2 + stderr가 substring `placeholder hit:` 와 substring `TBD` 둘 다 포함. 검증: case 7.
- **AC8**: `DEVBREW_DISABLE_SPEC_DISTILL=1` 환경에서 validator hook이 모든 입력에 대해 silent exit 0, state.local.md 변경 없음. 검증: case 8.
- **AC9**: `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1` 환경에서 valid spec 작성 시 Layer 1 정상 동작 (structural check 수행), state.local.md `pending_review:` block은 *기록되지 않음* (Layer 2 우회). 검증: case 9.
- **AC10**: `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` 환경에서 `-design.md` 작성 시 hook이 silent exit 0 (design mode 전체 우회). 검증: case 10.
- **AC11**: Stop hook을 state.local.md에 `pending_review: {path, mode, triggered_at}` block 있는 상태로 실행 → stdout JSON `{"systemMessage": "..."}` 에 substring `MANDATORY`, 실제 spec path, `reviewing-spec` 셋 다 포함. 검증: `bash plugins/spec-distill/tests/test_review_dispatch.sh` case 11.
- **AC12**: Stop hook을 `pending_review:` block 없는 state.local.md에 대해 실행 → silent exit 0 (systemMessage 미emit). 검증: case 12.
- **AC13**: Stop hook이 dispatch 후 state.local.md에서 `pending_review:` block 제거 + `last_dispatched_at:` 갱신 (재dispatch 방지). 검증: case 13 — Stop hook 두 번 연속 호출 시 두 번째는 silent exit 0.
- **AC14**: `plugin.json` 버전이 `0.3.0`. 검증: `jq -r '.version' plugins/spec-distill/.claude-plugin/plugin.json` 의 output이 `"0.3.0"`.
- **AC15**: `CHANGELOG.md`에 `## [0.3.0]` 섹션 존재 + Added (spec-write-validator hook, review-dispatch hook, design.md coverage) + Changed (reviewing-spec dispatch trigger from skill-invoked to hook-injected). 검증: `grep -E '^## \[0\.3\.0\]' plugins/spec-distill/CHANGELOG.md` 1+ matches.
- **AC16**: 기존 `tests/test_hooks.sh` (interview-trigger + session-anchor regression) 전체 통과 — 신규 hook이 기존 hook과 충돌하지 않음. 검증: 전체 run의 exit code 0.
- **AC17**: 메타 self-referential 검증 — 이 spec 자체 (`docs/superpowers/specs/2026-05-16-spec-distill-hook-review-design.md`)를 hook이 활성화된 상태에서 *재저장*했을 때 hook이 fire하고 structural pass + Stop hook이 dispatch 강제. self-reference 사이클이 무한 재귀로 폭주하지 않음을 확인 (한 번 fire 후 `last_dispatched_at` 가드로 중단). 검증: **V11 manual case** (단 Q4의 TTL 미결 상태에서는 manual run 시 TTL을 `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC` 환경변수로 fixture 주입 — 예: `=10` — 후 두 번째 저장이 차단되는지 확인. TTL 값이 plan phase에서 확정되면 fixture 값을 default와 일치시킴).
- **AC18**: reviewing-spec SKILL.md의 "Re-review cap" 섹션이 hard cap `>= 5` + round-level stagnation early-exit 두 조건을 모두 명시. 검증: `grep -E 'rereview_count >= 5' plugins/spec-distill/skills/reviewing-spec/SKILL.md` 1+ matches AND `grep -E 'Stagnation_signal.*true.*Human Gate' plugins/spec-distill/skills/reviewing-spec/SKILL.md` 1+ matches.
- **AC19**: 본 spec 작성 과정 자체가 새 cap 정책의 첫 instantiation 사례임을 메타 검증 — multi-round review (round 1–5)가 각 라운드 `Stagnation_signal: false` 유지 + 발견된 모든 issue가 `ambiguous_requirement` / `unstated_assumption` / `missing_section` 범주 (cross-reference drift, wording, missing header)에 속하며 *implementation-blocking 아님* (reviewer가 round 4–5에서 명시적으로 분류). 최종 lock은 round 5 fix 적용 후 *사용자 명시 승인* 시점. 검증: V13.

## Files to Modify

**신규 (4)**:
- `plugins/spec-distill/hooks/spec-write-validator.py` — PostToolUse Layer 1 validator.
- `plugins/spec-distill/hooks/review-dispatch.py` — Stop hook. **state.local.md `pending_review:` block을 직접 read** 후 존재 시 systemMessage 주입으로 다음 turn 첫 액션 강제. transcript 파싱 미사용 (C7).
- `plugins/spec-distill/scripts/parse-spec-structure.py` — validator가 import하는 라이브러리 (11 section / frontmatter / locked_decisions schema parser, ambiguity scanner, escape handler).
- `plugins/spec-distill/scripts/ambiguity-blacklist.txt` — 측정 불가 키워드 리스트 (`works correctly`, `fast`, `good UX`, `as needed`, `properly`, `efficient`, `seamless`, `robust` 등; 한 줄당 한 패턴, `#`로 주석).

**수정 (6)**:
- `plugins/spec-distill/hooks/hooks.json` — PostToolUse + Stop event 추가. PostToolUse는 `matcher: "Write|Edit|MultiEdit"` (tool-name regex), Stop은 matcher 없음. 각 timeout 10s.
- `plugins/spec-distill/skills/reviewing-spec/SKILL.md` — 두 곳 갱신: (a) Step 1 — "state.local.md `pending_review:` 플래그가 hook으로부터 전달된 dispatch 명령임을 명시", (b) "Re-review cap" 섹션 — hard cap `>= 3` → `>= 5` + stagnation early-exit (round-level: verdict `needs_revise` + `Stagnation_signal: true` 시 즉시 [5] Human Gate). routing table / [3.5] gate / Escalate priority table (P1–P4) 본문은 무수정.
- `plugins/spec-distill/skills/drafting-spec/SKILL.md` — Mode A/B 종료 단계의 *"reviewing-spec 호출"* 표현을 *"hook이 file write를 감지해 reviewing-spec dispatch를 자동 강제 — 별도 명시 호출 불필요"*로 변경.
- `plugins/spec-distill/.claude-plugin/plugin.json` — version `0.2.0` → `0.3.0`.
- `plugins/spec-distill/CHANGELOG.md` — `## [0.3.0] — 2026-05-16` 섹션 추가.
- `plugins/spec-distill/README.md` — "Hooks Installed" 표에 PostToolUse + Stop 두 줄 추가 (각각 "왜 skill이 아닌가" justification 한 줄). "Principles Instantiated"에 Law 2 강화 (turn boundary level dispatch) 명시.

**테스트 신규 (3)**:
- `plugins/spec-distill/tests/test_spec_write_validator.sh` — 신규. AC1–AC10 케이스. fixture 의존.
- `plugins/spec-distill/tests/test_review_dispatch.sh` — 신규. AC11–AC13 케이스.
- `plugins/spec-distill/tests/fixtures/` — 신규 디렉토리, 7개 fixture 파일:
  - `spec-valid.md` (AC1)
  - `spec-missing-goals.md` (AC2)
  - `spec-ambiguity-line12.md` (AC3, line 12 hardcoded)
  - `spec-ambiguity-escaped.md` (AC4)
  - `design-no-frontmatter.md` (AC6)
  - `design-tbd.md` (AC7)
  - `state-pending-review.md` (AC11 — pre-existing state.local.md 시뮬레이션)

## Verification Plan

- **V1** (AC1–AC10): `bash plugins/spec-distill/tests/test_spec_write_validator.sh` — exit 0 expected.
- **V2** (AC11–AC13): `bash plugins/spec-distill/tests/test_review_dispatch.sh` — exit 0 expected.
- **V3** (AC16): `bash plugins/spec-distill/tests/test_hooks.sh` — exit 0 expected (기존 regression).
- **V4** (AC14): `jq -r '.version' plugins/spec-distill/.claude-plugin/plugin.json` — output `"0.3.0"`.
- **V5** (AC15): `grep -E '^## \[0\.3\.0\]' plugins/spec-distill/CHANGELOG.md` — 1+ matches.
- **V6** (hooks.json validity): `jq . plugins/spec-distill/hooks/hooks.json > /dev/null` — exit 0.
- **V7** (kill switch 회귀): `DEVBREW_DISABLE_SPEC_DISTILL=1 bash plugins/spec-distill/tests/test_spec_write_validator.sh` — 모든 case exit 0 (silent).
- **V8** (plan-phase prerequisite, **C9에 의해 필수**): C7이 file-based coordination을 *확정*했으므로 V8 범위는 다음 두 항목으로 축소된다 — (a) `plugins/quality-gates/hooks/post-tool-use.py` 의 exit code 차단 패턴 (exit 2 시 stderr/stdout이 어떻게 사용되는지) 정적 분석, (b) `plugins/quality-gates/hooks/stop-hook.py`의 stdout JSON schema (`systemMessage` 등 키의 정확한 의미) 정적 분석. *transcript 파싱 메커니즘은 우리 디자인 scope 밖이므로 V8에서 다루지 않음*. 결과를 plan 문서의 prerequisite 섹션에 기록.
- **V9** (E2E manual, spec-distill, post-merge): spec-distill `/interview` 한 사이클 돌려서 spec.md 작성 → reviewer가 turn boundary에서 강제 dispatch되는지 + tool result의 차단 표시 (structural fail case)가 실제로 LLM에게 보이는지 확인.
- **V10** (E2E manual, brainstorming, post-merge): superpowers brainstorming 한 세션 돌려서 `-design.md` 작성 → reviewer agent가 강제 dispatch되는지 확인.
- **V11** (AC17, self-reference): 이 spec 파일 자체를 (hook 활성 상태에서) `touch` 후 일부 줄 수정 + 저장 → hook이 1회 fire 후 `last_dispatched_at` 가드로 추가 fire 방지 확인.
- **V12** (AC18): `grep -E 'rereview_count >= 5' plugins/spec-distill/skills/reviewing-spec/SKILL.md && grep -E 'Stagnation_signal.*true.*Human Gate' plugins/spec-distill/skills/reviewing-spec/SKILL.md` — 두 grep 모두 1+ matches.
- **V13** (AC19, meta): 본 spec의 Concrete Next Action 도입부에 기록된 review history (round 1: 10 issues / round 2: 5 / round 3: 2 / round 4: 1 / round 5: 2 — 누적 20개, 모두 cross-reference drift + 매 라운드 `stagnation_signal: false`)가 실제 PR description / commit log와 일치. final lock 시점 = 사용자가 round 5 결과를 보고 명시 승인한 turn.

## Rejected Alternatives

- **R1 — 신규 review-gate 플러그인 분리**: 두 워크플로우 횡단하는 design-doc reviewer를 별도 플러그인으로. *거절 이유*: 현재 spec/design doc review라는 단일 책임이 spec-distill의 책임 범위 안에 자연스럽게 포함됨. 분리 시 spec-distill ↔ review-gate 의존성 관리 비용 + 두 플러그인 모두 SemVer bump 필요. 미래에 *다른 doc 종류 reviewer*가 추가되면 그 시점에 추출 (YAGNI).
- **R2 — 양쪽 플러그인에 각각 hook (분산)**: spec-distill에 hook + devbrew 루트의 settings.json에 brainstorming용 hook 따로. *거절 이유*: 코드 중복 + devbrew의 "plugin-shape 일관성" (CLAUDE.md) 깨짐.
- **R3 — Pure agent dispatcher hook (Layer 1 없음)**: hook은 단순히 reviewer dispatch만 요청, structural check는 reviewer가 처리. *거절 이유*: structural check는 mechanical하고 무료 — agent dispatch (cost_class medium) 이전에 cheap layer에서 잡는 것이 layered defense + cost-aware. 또한 structural fail은 즉시 차단(exit 2) 가능하므로 reviewer dispatch round 1회 절약.
- **R4 — Full script review (LLM-free)**: structural + adversarial을 모두 grep-based로 처리. *거절 이유*: unstated assumption, scope creep, locked-decision conflict 같은 진짜 adversarial 분석은 LLM 필요. spec-reviewer agent의 핵심 가치 폐기.
- **R5 — PostToolUse 대신 Stop hook 단독**: 모든 처리를 turn 종료 시 일괄 처리. *거절 이유*: structural fail이 *해당 turn 안*에 차단되지 못함 — writer가 잘못된 spec을 쓰고 다음 작업까지 진행한 뒤 차단. 즉시성 손실.

## Open Questions

- **Q1** (deferred to plan phase): ambiguity-blacklist.txt의 초기 단어 셋은 약 10개로 시작 (`works correctly`, `fast`, `good UX`, `as needed`, `properly`, `efficient`, `seamless`, `robust`, `easy to use`, `intuitive`)? 정확한 목록은 plan 단계 + 첫 실사용 후 PR로 다듬기.
- **Q2 (resolved)**: round 1 review가 hook output schema 불확실성을 지적함. quality-gates의 `post-tool-use.py` / `stop-hook.py` grep 결과 → (a) hooks.json `matcher`는 tool-name regex, (b) Stop hook은 transcript에서 LLM emit signal (`<qg-signal>`)을 파싱, (c) hook script가 stdout `{"systemMessage": "..."}` JSON을 emit해서 다음 turn에 LLM에 advisory 주입 — 모두 production에서 동작. C7 결정: **우리 디자인은 transcript signal 대신 state.local.md 파일 기반 coordination**을 채택 (file-based가 더 결정론적). V8에서 empirical 재확인.
- **Q3** (deferred to v0.4.0+): brainstorming의 `-design.md`가 frontmatter를 가질 경우의 처리 — 현 design은 "suffix 기준 분기"이지만 미래에 frontmatter `mode: spec`/`mode: design`을 명시 옵션으로 추가 가능. v0.3.0에서는 suffix만.
- **Q4** (deferred to plan phase): `last_dispatched_at` 가드의 정확한 TTL — self-reference 사이클 방지에 충분하면서 *합법적인 reviewer-→ drafting-spec Mode B → 재Write 사이클*에서는 다시 fire 가능해야. 첫 추정: 30초 정도면 사람 가독 turn 사이는 차단되지만 LLM의 Mode B 재writing은 통과. plan에서 fix.

## Concrete Next Action

이 spec은 reviewer round 1–5를 거쳤다 (round 1: 10 / round 2: 5 / round 3: 2 / round 4: 1 / round 5: 2 — 누적 20 issue, 모두 cross-reference drift 또는 wording-only로 *implementation-blocking 아님*, round 5에서 reviewer 명시 분류. 각 round `Stagnation_signal: false`). round 5 fix 적용 후 `rereview_count = 5` 도달 — hybrid cap (G8 / LD10) 의 hard cap branch trigger 직전. 다음 dispatch는 정책상 자동 사용자 escalate. 사용자 lock 결정 후의 verdict별 분기:

- **`approved` 경우**:
  1. `git add docs/superpowers/specs/2026-05-16-spec-distill-hook-review-design.md && git commit -m "spec: finalize round 1–5 review + hybrid cap policy (v1.3.0)"`
  2. `Skill superpowers:writing-plans docs/superpowers/specs/2026-05-16-spec-distill-hook-review-design.md` 호출. plan 산출 경로: `docs/superpowers/plans/2026-05-16-spec-distill-hook-review-plan.md`.
  3. Plan phase에서 V8 (quality-gates hook script 분석) 먼저 수행 — C9 prerequisite.
  4. Plan에 따라 hook script / library / 테스트 fixture / SKILL.md 수정 / version bump.
  5. Verification: V1–V7 자동, V8 분석, V9–V11 manual E2E.
  6. PR: `feature/spec-distill-hook-review` → `main`. plugin.json v0.3.0 bump 포함된 단일 PR.

- **`needs_revise` 경우**: reviewer가 다시 issue를 raise. issue별 targeted fix 적용 후 reviewer 재dispatch. 종료 조건은 **hybrid cap (G8 / LD10)**: (a) `rereview_count >= 5` (hard cap) 또는 (b) `Stagnation_signal: true` (수렴 실패 조기 감지) 둘 중 *하나라도* 충족 시 자동 사용자 escalate. 그 전까지는 reviewer가 새 valid issue를 raise하면서 stagnation false면 계속 진행. 근거: 기존 v0.2.0의 hard cap=3은 *unbounded autonomy* 회피에는 충분했지만 *수렴 중인 multi-round review*에 budget이 너무 짧음 — 본 spec 작성 자체가 round 4까지 valid issue를 발견하면서 stagnation false로 수렴함을 증거. (이 spec의 reviewing-spec SKILL.md 수정 사항이 정책을 함께 갱신.)

- **`needs_interview` 경우**: 사용자에게 즉시 escalate. 추가 brainstorming round 필요 — spec을 그대로 두고 사용자 의도 재확인 후 Mode B로 spec 재구성.
