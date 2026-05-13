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
  - **Locked 판정 트리거 (decision table)** — issue `ca92935a` 해결:
    | 사용자 응답 유형 | path | locked? |
    |---|---|---|
    | 명시적 수락 (예/동의/선택지 1개 선택/자유 텍스트로 결정 명시) | b, d | ✅ true |
    | 명시적 거절 (아니오/거절/대안 제시) | b, d | ✅ true (반대 명제로 locked) |
    | 보류 ("잘 모르겠음", "둘 다 괜찮음", "나중에 결정") | b, d | ❌ false — Open Questions로 박제 |
    | "추가 정보 필요" / "더 설명해주세요" | b, d | ❌ false — re-ask 또는 OQ |
    | factual auto-confirm | a | ❌ false (사용자 미답변) |
    | sub-agent ambiguity 답안 | c | ✅ true ONLY IF 사용자 confirm 받음 |
    
    이 표는 `conducting-interview` SKILL.md에 그대로 복제되어야 한다 (Files to Modify 참조).

- **G2**: spec.md frontmatter에 `locked_decisions:` 리스트를 추가하여 spec을 self-contained, machine-verifiable contract로 만든다 (LD2).
- **G3**: spec-reviewer agent가 각 issue에 대해 `affects_locked_decisions: [LD ids]` 필드를 출력하도록 한다. reviewer는 여전히 *file write*에 대해서만 read-only (`disallowedTools: Write, Edit, MultiEdit, NotebookEdit` 유지). **`Read` tool은 frontmatter 추출에 사용 허용** — `affects_locked_decisions` 매핑은 reviewer가 spec.md frontmatter의 `locked_decisions:` 리스트를 Read tool로 읽고, 각 issue의 `target_section` 및 message 내용을 LD `section` + `summary`와 deterministic 매칭하여 산출한다 (issue `05b88e71` 해결).
- **G4**: reviewing-spec routing table에 `affects_locked` 차원을 추가하여 locked-affecting issue가 자동 Mode B로 가지 못하게 한다 (LD3).
- **G5**: Re-consensus sub-step에서 `AskUserQuestion`으로 LD별 3-옵션 (수용 / 유지 / 추가 인터뷰)을 제시한다 (LD4).
- **G6**: drafting-spec Mode B에 `allowed_issue_ids` 입력 계약을 추가하여, 입력에 없는 issue_id는 *건드리지 않도록* SKILL.md에 명시한다 (LD5, physical guard via contract).
- **G7** *(in-scope 정당화)*: stagnation 판정 (P18)을 `dismissed_by_user` 카운터와 분리하여 사용자 명시 거절이 stagnation으로 잘못 escalate되지 않도록 한다. **이 변경은 G5의 prerequisite** — re-consensus 게이트에서 사용자가 (2) 유지를 선택해도 같은 issue가 다음 round에서 raise되면 `raised_count`만 증가시키면 P18 stagnation으로 trigger되어 사용자 sovereignty 거절이 stagnation으로 잘못 escalate된다. 따라서 G7은 별도 spec으로 분리 불가하며 본 spec에 in-scope. (issue `c1d6c80a` 해결.)
- **G8** *(in-scope 정당화)*: 기존 v0.1.x spec.md (locked_decisions 필드 없음)와 하위 호환을 보장한다 — empty list로 해석 → 기존 자동 [4] path 유지. **이 변경은 마이그레이션 path의 일부로 본 feature와 함께 ship돼야 한다** — v0.2.0 출시 시 사용자가 보유한 v0.1.x spec.md가 즉시 깨지지 않도록. (issue `c1d6c80a` 해결.)

## Non-goals

- **NG1**: spec.md 본문 (Goal/Goals/AC 등 11 섹션) 형식 변경 없음 — 변경 범위는 frontmatter + routing + Mode B input contract (LD6).
- **NG2**: plan 단계 (drafting-plan / reviewing-plan, v0.2.0 추가 예정) 도입은 별도 spec — 본 design은 spec 단계 한정.
- **NG3**: 새로운 agent 추가 없음 — spec-reviewer agent의 *출력 형식 확장*만 (frontmatter scoping은 유지).
- **NG4**: numerical scoring 도입 없음 — locked_decisions는 boolean (locked or not) 차원, 점수 X (philosophy §5.3 준수).
- **NG5**: 자동 reviewer persona 학습 없음 — `dismissed_by_user >= 3` 시 *사용자에게* "reviewer persona 점검 필요" 알림만 (Law 3 trigger), 자동 persona 편집 X.
- **NG6** *(OQ6 격상 — issue `d3f1b70c` 해결)*: v0.2.0에서 superseded LD frontmatter archive cutoff 정책 *없음*. drafting-spec Mode B는 superseded LD를 *무제한 frontmatter에 보존* (`superseded_by` + `supersedes` 마커 모두 유지, count 제한 X). frontmatter 비대화에 대한 archive 정책은 v0.3.0+로 deferred — 이 spec의 범위 밖.

## Constraints

- **C1**: spec-reviewer agent의 `disallowedTools: Write, Edit, MultiEdit, NotebookEdit` frontmatter 유지 (Law 2 보장). 새 출력 필드는 *prompt-level*에서 emit, file write 없음. `Read` tool은 frontmatter 추출 목적으로 허용 (G3 참조).
- **C2**: drafting-spec Mode B는 기존 `Edit` tool 사용 (전체 rewrite 금지 정책 유지).
- **C3** *(OQ3 격상)*: reviewing-spec skill은 `cost_class: medium`. Re-consensus sub-step 추가로도 medium 초과 금지. **한 round당 최대 1번의 AskUserQuestion 묶음 dispatch, 묶음 안에 최대 3개 LD까지 노출** (AskUserQuestion 의 max 4 questions 중 1개는 escalation summary로 reserve). 4개 이상 locked-affecting issue가 raise되면 [5] forced escalate.
- **C4** *(state schema 변경 명시)*: state.local.md frontmatter schema 확장은 *추가* only (기존 필드 의미 변경 금지). 마이그레이션 path = empty 기본값. **신규 필드**: `pending_locked_decisions: []` (conducting-interview append 대상), `dismissed_by_user: 0` 및 `accepted_by_user: 0` 카운터 (issue_history 각 항목에 추가), `reconsensus_accepted_ids: []` (reviewing-spec [3.5] sub-step이 기록, Mode B로 전달). (issue `40f517cf`, `ca92935a` 해결.)
- **C5**: P22 (cost class) 준수 — 새 sub-step이 fan-out factor를 늘리지 않아야 함 (AskUserQuestion 1회 = sub-agent dispatch 아님).
- **C6**: P21 (secret 기록 금지) — locked_decisions의 `summary` 필드는 token/key/credential 패턴 placeholder 치환.
- **C7**: README "Principles Instantiated"에 P17 instantiation 한 줄 추가 (Law 3 compounding substrate).
- **C8** *(frontmatter source 허용값)*: spec.md frontmatter `locked_decisions[].source` 필드 허용값은 `interview-round-<N>` (정상 운영 경로) 또는 `brainstorming-round-<N>` (본 design spec과 같은 meta-spec dogfooding 경로) 중 하나. drafting-spec Mode A는 *interview-round-N* 형식만 생성하고 brainstorming-round 형식은 수동 작성에 한정.
- **C9** *(fixture 순서 의존성 — implementation-blocking, issue `c9f1a3b2` 해결)*: Verification Plan의 fixture-기반 검증은 fixture 파일 *존재 검증을 사전 게이트로 실행*해야 한다. 실행 순서: (1) state schema migration → (2) fixture 파일 생성 → (3) reviewer/Mode B 코드 변경 → (4) Verification Plan 실행. **위반 시 enforcement**: V0 pre-gate (V1 직전 실행)이 `test -d plugins/spec-distill/tests/fixtures && ls plugins/spec-distill/tests/fixtures/*.md | wc -l` ≥ 8 검증 + 9개 명시 fixture 파일명 각각 `test -f` 검증. 미충족 시 Verification Plan 전체 abort (exit 1). 또한 모든 V command의 grep은 `set -e -o pipefail` 환경에서 실행하여 `grep -q` 부재 파일에 대해 silent pass 차단.
- **C10** *(in-flight state migration — issue `a8e2d194` 해결)*: v0.1.x에서 진행 중인 세션의 state.local.md (신규 필드 부재) 처리 명세. reviewing-spec / drafting-spec / conducting-interview SKILL.md가 state.local.md 로드 시 *missing field*를 발견하면 다음 규칙 적용:
  - `pending_locked_decisions` 부재 → `[]`로 자동 promote (다음 state write 시 frontmatter에 명시).
  - `issue_history[].dismissed_by_user` / `accepted_by_user` / `reconsensus_count` 부재 → 각각 `0`으로 자동 promote.
  - `reconsensus_accepted_ids` 부재 → `[]`로 자동 promote.
  - 자동 promote는 *non-mutating read* (in-memory default) — 다음 state write 시점에 frontmatter에 자연스럽게 추가. 사용자에게 한 줄 advisory 출력 ("state.local.md schema migration: <fields> added with defaults"). state.local.md를 *backward-rewriting*하지 않음.
  - 자동 promote 실패 시 (예: 파일 corruption) → 사용자에게 "v0.1.x in-flight state 호환 실패 — 세션 재시작 권장" 알림 + state.local.md 보존 (P14).

## Acceptance Criteria

각 AC는 verification 명령 또는 fixture-based 절차를 동반한다. LLM-skill 기반 컴포넌트의 verification은 (a) SKILL.md/agent.md 정의 파일의 grep 검증 (skill contract가 명시되었는지), (b) fixture 파일의 expected output 패턴 매칭 (transcript 기반 replay) 두 형태를 사용한다 — spec-distill에는 코드 실행 unit test runner가 없다.

- **AC1** (LD ID 부여): `conducting-interview` SKILL.md에 G1의 decision table이 명시되고, 종료 시 state.local.md에 `pending_locked_decisions: [...]` 리스트가 append되도록 명시. `drafting-spec` Mode A는 이를 읽어 spec.md frontmatter `locked_decisions:`로 변환. **Verification (fixture-based)**:
  - 신규 fixture `plugins/spec-distill/tests/fixtures/interview-transcript-bbda.md` 생성 (4 round, paths `b/b/d/a` — 각 round에 사용자 응답과 path tag transcript 포함).
  - 검증 명령: `bash plugins/spec-distill/tests/run-fixture-ac1.sh` — 이 스크립트는 `drafting-spec` Mode A를 fixture transcript에 dispatch하고, 결과 spec.md frontmatter를 `yq` 또는 `python3 -c "import yaml..."`로 파싱하여 `len(locked_decisions) == 3 AND all(LD.source.startswith('interview-round'))` assert.
  - SKILL.md 자체 검증: `grep -q "Locked 판정 트리거" plugins/spec-distill/skills/conducting-interview/SKILL.md`.
  - (issue `c3ad4bdf` 해결.)
- **AC2** (reviewer 출력 형식): `spec-reviewer.md` agent definition의 "Output 형식" 섹션에 `affects_locked_decisions:` 필드가 명시되고, agent definition + contract fixture가 일관된 schema를 정의. **Verification (definition-grep only — issue `f4a7c021` 해결, manual replay 의존성 제거)**:
  - Agent definition grep: `grep -q "affects_locked_decisions" plugins/spec-distill/agents/spec-reviewer.md`.
  - Output 형식 코드 블록 검증: `awk '/^## Output 형식/,/^## /' plugins/spec-distill/agents/spec-reviewer.md | grep -qE '^[[:space:]]*affects_locked_decisions:.*\[.*\]'` (필드가 markdown code block 안에 list-bracket 형태로 명시).
  - Contract fixture `plugins/spec-distill/tests/fixtures/reviewer-output-mixed.md`는 *expected schema 예시*로만 사용 (실제 LLM replay 검증 X — LLM 출력 비결정성 수용). fixture grep: `grep -cE '^[[:space:]]*affects_locked_decisions:' plugins/spec-distill/tests/fixtures/reviewer-output-mixed.md` ≥ 2 (mixed locked + unlocked 두 sample issue 모두 필드 포함).
  - **Pass 기준**: 위 3개 grep 모두 exit 0. LLM replay는 *runtime 검증*이지 AC2 검증 항목 아님 (AC2는 contract definition 검증).
  - (issue `8078f608`, `f4a7c021` 해결.)
- **AC3** (routing): `reviewing-spec` SKILL.md의 Deterministic Routing Table에 `affects_locked` column이 추가되고, "all-empty → [4]" 및 "any non-empty → [3.5]" 분기 행이 명시. **Verification (SKILL.md-grep + manual trace)**:
  - SKILL.md grep: `grep -cE '^\| .* affects_locked' plugins/spec-distill/skills/reviewing-spec/SKILL.md` ≥ 4 (헤더 + 분기 row 3개 이상).
  - Fixture trace: `plugins/spec-distill/tests/fixtures/routing-trace-cases.md`에 5개 case (all-empty / mixed-locked / stagnation / count>=3 / dismissed) 각각의 routing 결과를 expected하게 기재. SKILL.md routing table을 case별로 매핑하여 manual review.
  - (issue `8078f608` 해결.)
- **AC4** (user options): `reviewing-spec` SKILL.md의 [3.5] Re-consensus sub-step 섹션이 `AskUserQuestion` 호출 명세를 포함하고, 옵션이 정확히 3개 (수용/유지/추가 인터뷰)로 정의. **Verification (SKILL.md-grep)**:
  - `grep -A 20 "## \[3.5\] Re-consensus" plugins/spec-distill/skills/reviewing-spec/SKILL.md | grep -cE "^[[:space:]]*[-*][[:space:]].+→"` == 3 (옵션 3개 + arrow notation).
  - 직접 호출 검증: SKILL.md에 `AskUserQuestion` 호출 코드 블록이 포함되고 그 안의 `options:` 리스트가 3개 항목임을 확인 (`yq` 또는 정규식 grep).
  - (issue `8078f608` 해결.)
- **AC5** (Mode B guard + 전달 메커니즘 + abort flow): `reviewing-spec` SKILL.md의 [3.5] sub-step이 사용자 "수용" 응답을 state.local.md `reconsensus_accepted_ids:` 리스트에 기록하고, Mode B dispatch 시 이 리스트를 `allowed_issue_ids` 파라미터로 전달함을 명시. `drafting-spec` Mode B SKILL.md는 입력에 `allowed_issue_ids`가 있으면 이 리스트에 *없는* issue_id의 변경을 *적용하지 않음*을 명시. **Abort flow (issue `e5f208a0` 해결)**: Mode B가 reviewer issues 중 `allowed_issue_ids`에 없는 issue_id 적용을 *시도*할 경우:
  1. spec.md edit 즉시 중단 (이미 적용된 partial edit 있으면 git reset HEAD --),
  2. state.local.md에 `mode_b_violation: { attempted_issue_id: <id>, allowed: [...] }` 마커 기록,
  3. reviewing-spec [3.5] sub-step으로 제어 반환 (reviewing-spec이 violation marker 감지),
  4. 사용자에게 advisory 표시 ("Mode B contract 위반 — `<id>` 가 `allowed_issue_ids`에 없음. 재합의 round 누락 가능성. 옵션: (i) 해당 issue를 re-consensus에 추가 / (ii) Mode B 재dispatch (수동 issue 선택) / (iii) [5] Human Gate로 escalate").
  
  **Verification (SKILL.md-grep + fixture)**:
  - 전달 메커니즘 grep: `grep -q "reconsensus_accepted_ids" plugins/spec-distill/skills/reviewing-spec/SKILL.md` && `grep -q "allowed_issue_ids" plugins/spec-distill/skills/drafting-spec/SKILL.md`.
  - Abort flow grep: `grep -q "mode_b_violation" plugins/spec-distill/skills/drafting-spec/SKILL.md` && `grep -q "mode_b_violation" plugins/spec-distill/skills/reviewing-spec/SKILL.md`.
  - Fixture `plugins/spec-distill/tests/fixtures/mode-b-guard-case.md`: **두 시나리오** 포함:
    - *정상 케이스*: 입력 spec.md + `allowed_issue_ids: [I1]` + reviewer issues `[I1, I2]` → expected diff (I1만 적용, I2 unchanged).
    - *abort 케이스*: 입력 spec.md + `allowed_issue_ids: [I1]` + Mode B가 I2 적용 시도 → expected outcome (spec.md unchanged, state.local.md에 `mode_b_violation` 마커, reviewing-spec [3.5] re-entry).
  - fixture를 contract 명세로 사용 (manual replay 의존성 없음, 형식 grep만 요구): `grep -q "mode_b_violation" plugins/spec-distill/tests/fixtures/mode-b-guard-case.md`.
  - (issue `40f517cf`, `8078f608`, `f4a7c021`, `e5f208a0` 해결.)
- **AC6** (stagnation 분리 + state schema): state.local.md issue_history 각 항목에 `dismissed_by_user: 0`, `accepted_by_user: 0` 카운터 신규 필드 추가. stagnation 판정 로직이 `raised_count >= 3 AND dismissed_by_user == 0` 조건으로 변경. **Verification (SKILL.md-grep + fixture trace)**:
  - State schema grep: `grep -q "dismissed_by_user" plugins/spec-distill/skills/conducting-interview/SKILL.md` && `grep -q "dismissed_by_user" plugins/spec-distill/skills/reviewing-spec/SKILL.md`.
  - Fixture `plugins/spec-distill/tests/fixtures/stagnation-cases.md`: 3 case (raised=3 dismissed=0 / raised=3 dismissed=1 / raised=3 dismissed=3) → expected outcome (stagnation / no-stagnation / reviewer-persona-warn). reviewing-spec SKILL.md routing 조건과 manual 매핑.
  - (issue `ca92935a` 해결.)
- **AC7** (하위 호환): v0.1.x spec.md (frontmatter에 `locked_decisions` 키 없음) 입력 시 reviewing-spec이 empty list로 해석. **Verification (fixture)**:
  - 신규 fixture `plugins/spec-distill/tests/fixtures/v0.1.x-spec-no-locked.md` (frontmatter에 `locked_decisions` 키 부재).
  - SKILL.md에 명시: `locked_decisions` 키 부재 시 `[]`로 default. grep: `grep -qE "locked_decisions.*default.*\[\]" plugins/spec-distill/skills/reviewing-spec/SKILL.md`.
  - Manual replay: fixture + reviewer dispatch → 모든 issue `affects_locked_decisions: []` 출력 → routing이 자동 [4] 분기로 매핑됨을 routing-trace-cases.md case와 비교.
- **AC8** (kill switch): `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS=1` 설정 시 [3.5] sub-step 우회 + loud warning 출력. **Verification (SKILL.md + README grep)**:
  - SKILL.md grep: `grep -q "DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS" plugins/spec-distill/skills/reviewing-spec/SKILL.md`.
  - README grep: `grep -q "DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS" plugins/spec-distill/README.md` (Kill switches 섹션).
  - Warning 메시지 명시: SKILL.md에 "locked decisions 보호 비활성화됨 — 사용자 sovereignty 약화 위험" 문구 포함.
- **AC9** (re-consensus 무한 루프 방지 + escalate priority — issue `7b6c9a1d` 해결): state.local.md issue_history 각 항목에 `reconsensus_count: 0` 카운터. **Escalate priority table** (reviewing-spec SKILL.md에 명시 + 다음 순서로 평가):
  
  | 우선순위 | 조건 | scope | 동작 |
  |---|---|---|---|
  | P1 (highest) | C3: 한 round에 locked-affecting issue ≥ 4 | spec 전체 | [5] forced escalate, *전체 spec* 인간 검토. issue_history 변경 X. |
  | P2 | AC9: 특정 issue_id의 `reconsensus_count >= 2` | per-issue | 해당 issue 만 [5] forced escalate, *나머지 issue는 [4] Revise로 계속*. issue_history에 `escalated: true` 마커. |
  | P3 | AC6: P18 stagnation (`raised_count >= 3 AND dismissed_by_user == 0`) | per-issue | 해당 issue 만 [5] forced escalate. |
  | P4 (lowest) | AC6 보강: `dismissed_by_user >= 3` | per-issue + persona warn | 해당 issue [5] escalate + reviewer persona 점검 advisory. |
  
  두 조건이 동시 충족 시 P1 우선 (global이 per-issue 우선). 같은 우선순위 내 동시 충족 시 모든 해당 issue를 묶어서 한 번에 [5] escalate.
  
  **Verification (SKILL.md-grep)**:
  - State schema grep: `grep -q "reconsensus_count" plugins/spec-distill/skills/reviewing-spec/SKILL.md`.
  - Priority table grep: `grep -cE '^\| P[1-4]' plugins/spec-distill/skills/reviewing-spec/SKILL.md` ≥ 4.
  - 우선순위 명시 grep: `grep -q "P1.*우선\|global.*우선\|per-issue.*가 아닌" plugins/spec-distill/skills/reviewing-spec/SKILL.md`.
  - Fixture `plugins/spec-distill/tests/fixtures/reconsensus-loop-case.md`: 두 시나리오 — (a) issue_history에 `reconsensus_count: 2` 시뮬레이션 → expected per-issue [5] 직행 (P2 path), (b) locked-affecting issue 5개 시뮬레이션 → expected spec 전체 [5] (P1 path).
- **AC10** (plugin.json bump): v0.1.2 → v0.2.0. CHANGELOG.md 생성 (`## [0.2.0] — YYYY-MM-DD` with Added/Changed). **Verification (exec)**: `jq -e '.version == "0.2.0"' plugins/spec-distill/.claude-plugin/plugin.json` && `test -f plugins/spec-distill/CHANGELOG.md` && `grep -q "## \[0.2.0\]" plugins/spec-distill/CHANGELOG.md`.

## Files to Modify

### 핵심 변경

- `plugins/spec-distill/skills/reviewing-spec/SKILL.md` — routing table에 `affects_locked` column 추가, [3.5] Re-consensus sub-step 섹션 추가 (`AskUserQuestion` 호출 명세 + 3-옵션 + state.local.md `reconsensus_accepted_ids:` 기록 + Mode B로 `allowed_issue_ids` 전달), kill switch 항목 추가, stagnation 조건 변경 (`raised_count >= 3 AND dismissed_by_user == 0`), `reconsensus_count` 카운터 + **AC9 escalate priority table (P1–P4)** 추가, **`mode_b_violation` marker 감지 → [3.5] re-entry 로직** 추가, **in-flight state migration**: load 시 missing field 자동 promote + advisory 출력.
- `plugins/spec-distill/skills/drafting-spec/SKILL.md` — Mode A에 locked_decisions frontmatter 생성 로직 추가 (state.local.md `pending_locked_decisions` 읽어 변환); Mode A에 **superseded LD 무제한 보존** 정책 명시 (NG6 — count cutoff 없음, archive는 v0.3.0+); Mode B에 `allowed_issue_ids` 입력 contract 추가 + **abort flow** (위반 시: edit 중단 → git reset → state.local.md에 `mode_b_violation` 기록 → reviewing-spec [3.5] 복귀); Mode B에 **in-flight state migration** 동일 적용.
- `plugins/spec-distill/skills/conducting-interview/SKILL.md` — state.local.md 신규 필드 (`pending_locked_decisions: []`, `issue_history[].dismissed_by_user`, `issue_history[].accepted_by_user`, `issue_history[].reconsensus_count`); G1 decision table을 "Locked 판정 트리거" 섹션으로 복제; (b)/(d) path에서 사용자 명시 응답을 `pending_locked_decisions`에 append 명시 (보류/추가 정보 요청은 Open Questions로); **in-flight state migration** 동일 적용 (load 시 missing field 자동 promote).
- `plugins/spec-distill/agents/spec-reviewer.md` — Input 섹션에 "spec.md frontmatter의 `locked_decisions:` 리스트 (Read tool로 추출)" 추가; "Output 형식"에 `affects_locked_decisions: [LD ids]` 필드 명시 (모든 issue 라인 다음 indented 줄); "What to check"에 LD 매핑 가이드 (issue의 `target_section`과 LD `section` deterministic 매칭, message 내용과 `summary` 의미 매칭) 추가.
- `plugins/spec-distill/templates/spec-template.md` — frontmatter에 `locked_decisions:` 필드 (빈 리스트 기본값) + `source` 필드 허용값 주석 추가.

### 메타데이터 / 컴플라이언스

- `plugins/spec-distill/.claude-plugin/plugin.json` — version `0.1.2` → `0.2.0`.
- `plugins/spec-distill/CHANGELOG.md` — 신규. `## [0.2.0] — YYYY-MM-DD` entry with Added (re-consensus gate, locked_decisions frontmatter, state schema `pending_locked_decisions` / `dismissed_by_user` / `accepted_by_user` / `reconsensus_count` 필드, `reconsensus_accepted_ids` 전달 메커니즘, AC9 무한 루프 cap, `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS` kill switch) / Changed (stagnation 판정 조건).
- `plugins/spec-distill/README.md` — "Principles Instantiated"에 P17 explicit instantiation 한 줄; "Flow" 다이어그램에 [3.5] node 추가; "Kill switches"에 `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS` 추가.

### 테스트 / fixtures (모두 신규 생성)

- `plugins/spec-distill/tests/fixtures/interview-transcript-bbda.md` — AC1 검증. 4-round transcript, paths b/b/d/a.
- `plugins/spec-distill/tests/fixtures/locked-decisions-spec.md` — LD1/LD2 포함 spec.md 샘플 (AC2, AC5에서 input으로 사용).
- `plugins/spec-distill/tests/fixtures/reviewer-output-mixed.md` — AC2 contract 명세. reviewer expected output 형식 (mixed locked + unlocked).
- `plugins/spec-distill/tests/fixtures/routing-trace-cases.md` — AC3, AC7 검증. 5개 routing case 매핑.
- `plugins/spec-distill/tests/fixtures/mode-b-guard-case.md` — AC5 검증. 두 시나리오: (a) 정상 (`allowed_issue_ids: [I1]` + issues `[I1, I2]` → I1만 적용), (b) abort (Mode B가 I2 시도 → mode_b_violation marker + [3.5] re-entry).
- `plugins/spec-distill/tests/fixtures/stagnation-cases.md` — AC6 검증. 3개 stagnation case.
- `plugins/spec-distill/tests/fixtures/v0.1.x-spec-no-locked.md` — AC7 검증. 하위 호환.
- `plugins/spec-distill/tests/fixtures/reconsensus-loop-case.md` — AC9 검증. 두 시나리오: (a) per-issue (issue_history에 `reconsensus_count: 2` → 해당 issue [5] escalate, 나머지 continue), (b) global (locked-affecting issue 5개 → spec 전체 [5]).
- `plugins/spec-distill/tests/run-fixture-ac1.sh` — AC1 검증 실행 스크립트 (Mode A dispatch + yaml parse + assert).

## Verification Plan

**실행 순서 의존성 (C9 — implementation-blocking)**: Verification 실행 전 사전 조건:
1. State schema migration 적용 (conducting-interview SKILL.md + reviewing-spec SKILL.md + drafting-spec SKILL.md 변경).
2. Fixture 파일 생성 (Files to Modify의 9개 fixture + run-fixture-ac1.sh).
3. Skill/agent definition 파일 변경 (reviewer/Mode A/Mode B/routing/abort flow).
4. **V0 pre-gate 실행** (아래) — 실패 시 V1–V12 abort.

**모든 V command는 `set -e -o pipefail` 환경에서 실행** — `grep -q` 없는 파일에 대한 silent pass 차단 (C9 enforcement).

- **V0** (pre-gate, fixture 존재 검증): 
  ```bash
  set -e -o pipefail
  test -d plugins/spec-distill/tests/fixtures
  for f in interview-transcript-bbda.md locked-decisions-spec.md reviewer-output-mixed.md \
           routing-trace-cases.md mode-b-guard-case.md stagnation-cases.md \
           v0.1.x-spec-no-locked.md reconsensus-loop-case.md; do
    test -f "plugins/spec-distill/tests/fixtures/$f"
  done
  test -x plugins/spec-distill/tests/run-fixture-ac1.sh
  ```
  V0 실패 시 *전체 Verification Plan abort* — fixture 부재 상태에서 V1–V12를 실행하면 false-pass 위험 (issue `c9f1a3b2` 해결).
- **V1** (lint): `jq empty plugins/spec-distill/.claude-plugin/plugin.json && jq -e '.version == "0.2.0"' plugins/spec-distill/.claude-plugin/plugin.json`.
- **V2** (template schema): `python3 -c "import yaml; d=yaml.safe_load(open('plugins/spec-distill/templates/spec-template.md').read().split('---')[1]); assert 'locked_decisions' in d"`.
- **V3** (reviewer agent contract): `grep -q "affects_locked_decisions" plugins/spec-distill/agents/spec-reviewer.md` && `grep -cE '^[[:space:]]*affects_locked_decisions:' plugins/spec-distill/tests/fixtures/reviewer-output-mixed.md` ≥ 2.
- **V4** (routing table): `grep -cE '^\| .* affects_locked' plugins/spec-distill/skills/reviewing-spec/SKILL.md` ≥ 4. routing-trace-cases.md의 5 case가 routing table의 각 row와 매핑되는지 manual 확인.
- **V5** (Mode B guard contract): `grep -q "allowed_issue_ids" plugins/spec-distill/skills/drafting-spec/SKILL.md` && mode-b-guard-case.md fixture의 expected diff와 SKILL.md 명세 일치 manual 확인.
- **V6** (state schema): `grep -q "pending_locked_decisions" plugins/spec-distill/skills/conducting-interview/SKILL.md` && `grep -q "reconsensus_accepted_ids" plugins/spec-distill/skills/reviewing-spec/SKILL.md` && `grep -q "dismissed_by_user" plugins/spec-distill/skills/reviewing-spec/SKILL.md`.
- **V7** (AC1 integration): `bash plugins/spec-distill/tests/run-fixture-ac1.sh` exit code 0 (Mode A를 interview-transcript-bbda.md fixture에 dispatch → resulting spec.md frontmatter parse → `len(locked_decisions) == 3` assert).
- **V8** (kill switch): `grep -q "DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS" plugins/spec-distill/skills/reviewing-spec/SKILL.md` && `grep -q "DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS" plugins/spec-distill/README.md` && SKILL.md 내 warning 문구 ("locked decisions 보호 비활성화됨") 존재.
- **V9** (backwards-compat): `grep -qE "locked_decisions.*default.*\[\]" plugins/spec-distill/skills/reviewing-spec/SKILL.md` && v0.1.x-spec-no-locked.md fixture가 SKILL.md의 empty-default 명세와 일치 manual 확인.
- **V10** (re-consensus loop cap): `grep -q "reconsensus_count" plugins/spec-distill/skills/reviewing-spec/SKILL.md` && `grep -qE "reconsensus_count.*>=.*2" plugins/spec-distill/skills/reviewing-spec/SKILL.md` && reconsensus-loop-case.md fixture와 매핑 manual 확인.
- **V11** (README + CHANGELOG): `grep -q "P17" plugins/spec-distill/README.md` && `grep -q "## \[0.2.0\]" plugins/spec-distill/CHANGELOG.md`.
- **V12** (E2E manual replay): conducting-interview → drafting-spec Mode A (4-round transcript) → spec-reviewer (locked-affecting issue 포함) → reviewing-spec [3.5] (수용 1 / 유지 1 / 추가 인터뷰 0) → Mode B (allowed_issue_ids로 limited edit) → re-review (수용된 issue 해결됨, 유지된 issue dismissed 마커) → approve → handoff. 각 단계에서 state.local.md 필드 변화 검증 + spec.md frontmatter locked_decisions 갱신 (superseded_by + new LD).

## Rejected Alternatives

- **R1**: 별도 Phase [3.5] 추가 (별도 SKILL.md 파일). **거절**: P22 cost class 증가 + skill 디스커버리 부담 증가. reviewing-spec 내부 sub-step이 충분하고 가벼움 (LD3).
- **R2**: reviewer 출력 형식 변경 없이 reviewing-spec post-processing이 issue의 `target_section` anchor를 locked_decisions와 매칭. **거절**: section anchor만으로는 어떤 LD가 영향받는지 ambiguous (한 섹션에 여러 LD 가능). reviewer가 직접 출력하는 게 deterministic.
- **R3**: locked_decisions를 spec.md가 아닌 별도 `.claude/spec-distill/<session>/locked.md` 파일. **거절**: spec.md self-contained 원칙 위반. handoff 시 별도 파일 전달 부담. 또한 reviewer가 추가 input을 받게 되면 frontmatter scoping이 복잡해짐.
- **R4**: locked_decisions를 spec.md 본문 (12번째 섹션)으로 추가. **거절**: NG1 위반 (본문 11 섹션 형식 유지). frontmatter는 metadata, 본문은 contract — 분리 유지.
- **R5**: 사용자 옵션 2개 (수용/유지)만, "추가 인터뷰"는 [5] Human Gate에서만. **거절**: 사용자가 합의 변경 필요는 인지했지만 새 정보 필요시 곧장 [1]로 갈 path가 없으면 Human Gate에서 dead-end. 3-옵션이 UX적으로 자연스러움.
- **R6**: numerical scoring으로 "locked-ness 정도" 측정 (예: 0.0-1.0). **거절**: NG4 위반 (philosophy §5.3 — numerical scoring 비추천). boolean으로 충분.
- **R7**: 자동 reviewer persona 학습 (dismissed_by_user 누적 시 reviewer prompt 자동 weakening). **거절**: NG5 위반 — persona 편집은 보안-민감 (CLAUDE.md 명시). 자동 mutation 위험, 사용자에게 알림만.

## Open Questions

- **OQ1** *(확정됨)*: `pending_locked_decisions` 추출 시점 — **매 round 끝 append** (state.local.md transcript와 동기화). G1 decision table이 (a)/(c-unconfirmed)/보류 모두 미append로 명시하므로 round 단위 append의 모호함은 제거됨.
- **OQ2** *(확정됨)*: spec.md frontmatter `locked_decisions:` 의 `summary` 필드 길이 제한 — **1줄 (160 char 권장)**. P21 secret 치환과 grep 검증 단순화. 향후 길어지면 별도 `details:` 필드 추가 검토 (v0.3.0+).
- **OQ3** *(확정됨 → C3로 격상)*: AskUserQuestion 최대 3개 LD 묶음, 4개 이상이면 [5] forced escalate.
- **OQ4**: `dismissed_by_user` / `accepted_by_user` / `reconsensus_count` 카운터가 *세션 간*에 persistent한가? **잠정**: 세션 한정 (현재 spec-distill state 모델 유지, state.local.md는 세션 한정). cross-session learning은 별도 spec (v0.3.0+).
- **OQ5** *(확정됨)*: kill switch는 README "Kill switches" 섹션에 loud warning과 함께 명시 (AC8 verification 참조).
- **OQ6** *(NG6로 격상 — issue `d3f1b70c` 해결, 더 이상 OQ 아님)*: superseded LD 보존 정책은 NG6 참조 (v0.2.0에서 무제한 보존, archive cutoff는 v0.3.0+).

## Concrete Next Action

**다음 명령** (사용자가 design 검토 후):

```
Skill superpowers:writing-plans docs/superpowers/specs/2026-05-13-spec-distill-reconsensus-design.md
```

writing-plans skill이 위 11 섹션을 input으로 받아 *implementation plan* (체크박스 단위 task breakdown)을 생성. plan 산출 경로: `docs/superpowers/plans/2026-05-13-spec-distill-reconsensus-plan.md`.

**Worktree context note** (issue `1cd064fe`): 본 design은 worktree `.claude/worktrees/spec-distill-reconsensus-design/`에서 작성됨. writing-plans skill은 spec.md의 *상대 경로*만 input으로 받아 worktree-agnostic 동작이 보장됨. plan 작성 후 main branch로 merge 시 spec.md와 plan.md가 같은 PR로 묶이는 것을 권장.

Plan 단계 이후:
1. Plan 검토 (사용자) → 수정 round → approve.
2. Implementation (별도 세션 권장 — quality-gates 파이프라인 활용).
3. Gate 1 (plan-verifier) + Gate 2 (PR 리뷰) + Gate 3 (runtime verify) 통과.
4. PR merge → spec-distill v0.2.0 release.
