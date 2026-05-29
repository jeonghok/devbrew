---
name: reviewing-spec
description: >
  Use this skill to dispatch the spec-reviewer agent against a spec.md draft
  and apply deterministic routing per the verdict × signal table. Manages re-
  review cap (max 5, AC6 — v0.3.0+), stagnation detection (AC7), wall-clock budget (AC14),
  and approve handoff sequence (AC11). Routing table is defined below in this
  SKILL.md (AC15) — agent verdict × stagnation signal × rereview count → next phase.
cost_class: medium
---

# Reviewing Spec (Phase 3)

당신은 spec-distill의 review phase를 진행 중입니다. spec-reviewer agent를 dispatch하고, 받은 verdict + 메타 신호를 *deterministic table*에 매핑해서 다음 phase를 결정합니다.

## Steps

1. **Load state.local.md** — `session_id`, `rereview_count`, `wall_clock_started_at`, `issue_history` 읽기. 또한 `pending_review:` block 존재 여부 확인. *이 skill은 PostToolUse hook이 spec/design 파일 write를 감지해 file ledger에 `pending_review:` block을 기록한 직후, Stop hook이 다음 turn에 systemMessage로 dispatch를 강제했기 때문에* 호출됨 — `pending_review:` block이 *없는 채로* invoke되면 manual override로 간주 (loud advisory). **`pending_review.mode` 분기**: `mode: design`일 때 11-section 누락 / locked_decisions schema 검사는 *skip* (brainstorming의 design 모드 파일은 spec 모드와 다른 양식 — `*-design.md` suffix 또는 frontmatter `locked_decisions` 부재로 content-aware 분류된 임의 `.md`). 본문의 placeholder / ambiguity / scope-creep / approaches-comparison / isolation / testing 검사만 spec-reviewer에게 요청. `session_id`가 unbound이거나 placeholder `<session-id>` 인 채로면 Step 3 cleanup이 charset 검증으로 자동 skip되지만, 사용자에게 명시적 통보 필요 (P14 + AP2).
2. **Wall-clock check (AC14)**: `now - wall_clock_started_at > DEVBREW_SPEC_DISTILL_TIMEOUT_MIN` (default 30) 이면 advisory metric 표기 + Phase 5 forced escalate.
3. **Dispatch spec-reviewer agent**:
   ```
   Agent({
     description: "Spec adversarial review",
     subagent_type: "spec-reviewer",
     prompt: "Review spec.md at <path>. Previous issue history: <list>"
   })
   ```
4. **Parse output** — Status, Issues, Recommendations, Stagnation_signal.
5. **Apply routing table** (다음 섹션).
6. **Update state.local.md** — `rereview_count += 1`, `issue_history`에 새 issues 추가/raised_count 증가.

## Deterministic Routing Table (AC15)

| Mode | Verdict | Stagnation_signal | rereview_count | affects_locked | → Next Phase |
|---|---|---|---|---|---|
| spec | `approved` | - | - | - | **[5] Human Gate** (auto) |
| spec | `needs_revise` | false | < 5 | **empty** | **[4] Revise** (auto, dispatch drafting-spec Mode B with `allowed_issue_ids = [all]`) |
| spec | `needs_revise` | false | < 5 | **non-empty** | **[3.5] Re-consensus gate** |
| spec | `needs_revise` | false | >= 5 | - | **[5] Human Gate** (forced escalate, full issue_history 첨부) |
| spec | `needs_revise` | true | - | - | **[5] Human Gate** (P18 stagnation, forced escalate — dismissed_by_user >= 1 issue는 stagnation count 제외) |
| spec | `needs_interview` | - | - | - | **user confirm gate** → [1] Interview 또는 [5] (취소) |
| **design** | `approved` | - | - | - | **[5] Human Gate** (proceed 게이트 — ①/② → `superpowers:writing-plans`) |
| **design** | `needs_revise` | - | < 5 | - | **brainstorming author 회귀**: 메인 agent가 design.md 직접 수정 후 reviewing-spec 재dispatch. **drafting-spec Mode B 호출하지 않음** (spec mode 전용). |
| **design** | `needs_revise` | - | >= 5 | - | **[5] Human Gate** (forced escalate, full issue_history 첨부) |

매 dispatch 후 위 표를 *그대로* 적용. prose-based 결정 금지.

## [3.5] Re-consensus gate (G4, G5, AC4)

`needs_revise` + `affects_locked: non-empty` 시 자동 [4] 대신 이 sub-step 실행. *별도 phase 아님* — reviewing-spec skill 내부 게이트.

### Steps

1. **묶음 만들기**: reviewer issue 중 `affects_locked_decisions: non-empty` 항목을 LD ID 기준으로 묶음. 한 round당 최대 3개 LD까지 (C3). **4개 이상이면 → P1 forced escalate** ([5], `Escalate priority table` 참조).
2. **AskUserQuestion dispatch** (한 묶음 = 한 dispatch, 최대 3개 question):

```javascript
   AskUserQuestion({
     questions: [
       {
         question: "LD<id>: \"<summary>\"에 대해 reviewer가 변경을 제안합니다: \"<issue.message>\". 어떻게 처리할까요?",
         header: "LD<id>",
         options: [
           {label: "수용 (re-consensus)", description: "이 항목의 합의를 갱신. spec 수정 진행."},
           {label: "유지 (dismiss)", description: "원래 합의 유지. issue dismissed-by-user 마커."},
           {label: "추가 인터뷰", description: "이 dimension에 대해 인터뷰 round 추가 ([1]로 회귀)."}
         ],
         multiSelect: false
       },
       // ... 묶음의 다른 LD에 대해 동일 형식 ...
     ]
   })
```

3. **응답 처리**:
   - **(1) 수용**: 해당 issue ID를 state.local.md `reconsensus_accepted_ids:` 리스트에 append. `issue_history[<id>].accepted_by_user += 1`.
   - **(2) 유지**: spec.md 변경 X. `issue_history[<id>].dismissed_by_user += 1`. `resolved: dismissed_by_user`.
   - **(3) 추가 인터뷰**: state phase = 1로 reset (interview_round 유지). `under_revision: [LD ids]` 마킹. conducting-interview skill 호출.

4. **routing 분기**:
   - 모든 (2)/(3): spec.md 변경 없음 → reviewing-spec 재dispatch (reviewer가 dismissed 마커 본 상태에서 재평가).
   - 하나라도 (1): Mode B dispatch with `allowed_issue_ids = reconsensus_accepted_ids` + (관련 LD의 superseded 마커 처리).
   - (3) 우선: 다른 옵션과 혼합 시 → [1] 회귀 우선 (인터뷰 후 다시 reviewing-spec).

5. **`reconsensus_count` 갱신**: 각 issue에 대해 `issue_history[<id>].reconsensus_count += 1`. `reconsensus_count >= 2` 도달 시 → P2 escalate (`Escalate priority table` 참조).

### mode_b_violation 감지 (AC5)

state.local.md에 `mode_b_violation` flag가 설정된 경우 (Mode B abort 후 복귀):
1. 사용자에게 AskUserQuestion으로 3-옵션 advisory ((i) re-consensus에 추가 / (ii) Mode B 재dispatch / (iii) [5] escalate).
2. 응답에 따라 분기. (i) → Step 1로 돌아가 묶음 재구성. (ii) → Mode B 재dispatch (사용자 선택 issue). (iii) → [5] Human Gate.

### Escalate priority table (AC9, P1–P4)

routing이 [5] forced escalate를 trigger할 수 있는 조건들. 다음 우선순위로 평가 (P1 최우선):

| 우선순위 | 조건 | scope | 동작 |
|---|---|---|---|
| **P1 (highest)** | C3: 한 round에 locked-affecting issue ≥ 4 | spec 전체 | [5] forced escalate, *전체 spec* 인간 검토. issue_history 변경 X. |
| **P2** | AC9: 특정 `issue_id`의 `reconsensus_count >= 2` | per-issue | 해당 issue 만 [5] forced escalate, *나머지 issue는 [4] Revise로 계속*. `issue_history[<id>].escalated = true`. |
| **P3** | P18 stagnation: `raised_count >= 3 AND dismissed_by_user == 0` | per-issue | 해당 issue 만 [5] forced escalate. |
| **P4 (lowest)** | `dismissed_by_user >= 3` | per-issue + persona warn | 해당 issue [5] escalate + advisory: "reviewer가 같은 issue를 3회 raise + 사용자가 3회 거절. reviewer persona 점검 필요 (NG5 — 자동 편집 X)." |

**두 조건 동시 충족 시**: P1이 P2/P3/P4보다 우선 (global이 per-issue 우선). 같은 우선순위 내 동시 충족 시 모든 해당 issue를 묶어서 한 번에 [5] escalate.

### Re-review cap (rereview_count, hybrid policy — v0.3.0 hook 통합)

두 조건 중 *하나라도* 충족 시 자동으로 [5] Human Gate로 forced escalate, 전체 `issue_history` 첨부:

1. **Hard cap**: `rereview_count >= 5` 도달 시 (즉 6번째 reviewer dispatch 시도 시). 기존 v0.2.0의 cap=3을 v0.3.0에서 cap=5로 상향 — multi-round drift detection을 위한 budget 확장.
2. **Round-level stagnation early-exit**: spec-reviewer가 `verdict: needs_revise` + `Stagnation_signal: true` 를 반환한 경우, `rereview_count`와 무관하게 즉시 [5] Human Gate로 escalate. 이는 *수렴 실패 조기 감지* — issue가 새로 발견되지 않고 같은 항목이 반복 raise되는 상황을 한 라운드 안에 끝낸다.

기존 P3 row (`raised_count >= 3 AND dismissed_by_user == 0`)는 *per-issue* stagnation, 위 (2)는 *round-level* stagnation으로 trigger가 다르다.

### Stagnation detection (P3 row 참조)

spec-reviewer agent가 `Stagnation_signal: true` 반환 시: 해당 issue에 대해 `raised_count >= 3 AND dismissed_by_user == 0` 검증. 두 조건 모두 충족 시 P3 trigger.

`dismissed_by_user >= 1`인 issue는 stagnation count에서 제외 — 사용자 명시 거절은 P17 sovereignty 행사이지 stagnation이 아님.

## Phase 5 Human Gate — proceed 게이트

### Step A — spec_path 선검증 (게이트 *이전* 필수)

`current_spec`(= spec_path)이 working-tree에 존재하는지 먼저 확인. 부재 시(예: 삭제된 worktree 경로) **proceed 게이트를 띄우지 말고** loud advisory + 사용자에게 재선택/리셋 요청, handoff 진행 금지:

> `[spec-distill] current_spec '<path>' 부재 (working-tree에 없음) — stale state. current_spec 재선택 또는 세션 리셋 필요. handoff 진행 안 함.`

### Step B — 단일 `AskUserQuestion` proceed 게이트 (AC8)

spec_path 유효 시, reviewer 결과를 표시하고 **한 번의** `AskUserQuestion`으로 다음 단계를 제안 (approve 후 별도 2차 질문 없음):

```javascript
AskUserQuestion({
  questions: [{
    question: "spec '<path>' review: <verdict 요약>. 다음 단계?",
    header: "Proceed",
    options: [
      {label: "/compact 후 writing-plans (권장)", description: "approve_handoff(검증+cleanup) 후 verbatim /compact 명령 노출 → 사용자 /compact 실행 시 writing-plans. 긴 인터뷰 context 정리 이점."},
      {label: "바로 writing-plans", description: "approve_handoff 후 즉시 Skill superpowers:writing-plans <path> 호출 (compact 없이)."},
      {label: "수정 필요", description: "approve 아님 — 후속 질문으로 revise per review / more interview / edit myself 분기."},
      {label: "멈춤 (나중에)", description: "state 보존하고 종료."}
    ],
    multiSelect: false
  }]
})
```

### Step C — 응답 처리

- **① /compact 후 writing-plans**: Approve handoff sequence 실행 → 사용자에게 verbatim `/compact` 명령을 *그대로 보이게* 노출 + "compact 후 writing-plans 진입 준비됨" 안내 → **여기서 턴 종료(STOP). 같은 턴에서 `writing-plans`를 호출하지 말 것** (compact 전 writing-plans 진입 = 옵션 ① 무력화). `Skill superpowers:writing-plans <path>` 진입은 사용자가 `/compact`를 *실제 실행한 다음 턴*에 **사용자 트리거**(예: `/compact write plan`처럼 compact 뒤에 붙인 진행 인자, 또는 명시적 진행 요청)로만 일어난다 — 모델은 다음 턴에 자동 진입하지 *않고* 신호를 기다리며, 사용자가 redirect하면 미진입(NG4·P17). compact된 fresh context에서 plan 작성 (AC19).
- **② 바로 writing-plans**: Approve handoff sequence 실행 → 즉시 `Skill superpowers:writing-plans <path>` 호출.
- **③ 수정 필요**: 후속 `AskUserQuestion`으로 분기 — "revise per review" → drafting-spec Mode B (spec mode) / 메인 agent design.md 직접 수정 (design mode); "more interview" → conducting-interview (state phase=1 reset, interview_round 유지); "edit spec myself" → 사용자 편집 후 reviewing-spec 재진입.
- **④ 멈춤**: state 보존, 종료.

### polite stop 금지 (AP2 — verifiable, AC11)

approve(①/②) 선택 후 "approved!"만 narrate하고 Approve handoff sequence 호출/다음 phase 진입을 skip하는 것은 **polite stop**. Phase 5를 *종료*하는 모든 경로는 (a) 위 proceed 게이트 제시를 거치거나(①/②/③/④), (b) 게이트를 거치지 않는 예외 경로(Step A spec_path 부재, kill switch)는 명시적 advisory 단락을 동반해야 한다 — 게이트-less silent 종료 금지. (게이트는 사용자가 redirect 가능한 approval gate이므로 P17 주권에 기여하며 polite-stop이 아니다 — 철학 §AP2.)

### cross-compact 조기 진행 금지 (AC19 — polite stop의 *반대* 실패 모드, verifiable)

옵션 ① 선택 시 `/compact`를 노출한 *직후* 같은 턴에서 `writing-plans`로 직진하는 것은 금지. compact가 무거운 plan-write *뒤에* 오면 context 위생 이점이 사라져 옵션 ①이 무의미해진다 (2026-05-29 본 design 세션에서 실측된 실패: "handoff"라 말하고 compact 전에 plan을 그대로 써버림). 다음 턴 진입은 *사용자 트리거*(예: `/compact write plan` 인자)로만 일어나며 모델 자동 진입이 아니다(NG4·P17). polite stop이 "진행해야 할 때 멈춤"이라면 이것은 "멈춰야 할 때 진행" — 두 방향 모두 게이트의 사용자-주권(P17)을 우회한다. **verifiable (두-레이어, AC11 선례)**: (i) `grep -cE "턴 종료|다음 턴"` ≥ 1, **AND** (ii) 옵션 ① 서술 *블록 안에서* 'turn-ending(STOP)' + 'writing-plans 같은 턴 호출 금지' + '다음 턴 = 사용자 트리거'가 *함께* 명시됐음을 리뷰에서 확인 (grep 단독은 두 문구의 같은-블록 공존을 보장 못 하므로 — false-positive: '턴 종료' 문구와 '같은 턴 호출' 문구가 떨어져 공존해도 통과 — 공존·정합 판정은 리뷰 레이어 담당; mechanical 한계는 AC11과 동일 수준 인정). 옵션 ②는 이 정지 요건의 *명시적 예외*(compact 없이 즉시 writing-plans). **AC8 경계** (round-2 advisory 반영): AC8 '추가 AskUserQuestion 없음'은 *approve 옵션이 최종 확정된 그 어시스턴트 응답 턴*에 한정한다 (Phase 5 내 revise/interview 루프의 다른 턴이 아님 — 그 턴들은 본래 질문을 띄움). 다음 턴에 진입한 writing-plans가 자체 실행-방식 선택 게이트를 띄우는 것은 별개 skill scope이므로 AC8 해당 없음.

## Approve handoff sequence (①/② 공통)

approve(①/②) 시:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/approve_handoff.sh" "$session_id" "$spec_path"
```

스크립트(v0.11.0+)가 thin finalizer로 동작: (1) kill switch + charset guard, (2) **spec_path working-tree 존재 검증** (`[[ -f ]]`, 모든 git 조회 이전 — 부재 시 exit 1 + advisory + cleanup 미수행, state 보존), (3) 미커밋 spec advisory (non-blocking, exit 0), (4) 세션 디렉토리 cleanup. **상태 추적 artifact를 남기지 않는다** — 다음-단계 추천은 proceed 게이트가 담당. idempotent by statelessness(재호출은 clean tree에서 no-op).

**polite stop 금지** (AP2): approve인데 스크립트 호출/게이트를 skip하고 narrate만 하지 말 것. SessionEnd hook이 backup cleanup이나 user-explicit approve 의도는 즉시 반영.

### 실패 시 state 보존 (P14)

approve_handoff.sh가 exit 1 시(spec_path 부재 — Step A 통과 후 race로 사라진 경우 포함 — 또는 session_id charset/arg 검증 실패) state.local.md 보존 + 세션 cleanup 미수행 (사용자 재선택 대기). 에이전트는 스크립트 stderr advisory를 그대로 노출하고 사용자 입력을 기다린다 (게이트 재표시는 사용자 요청 시). cleanup rm 실패는 advisory only — SessionEnd hook이 재시도. git commit 실패 경로는 존재하지 않음 (스크립트가 commit 시도 안 함; 미커밋은 advisory).

## In-flight state migration (C10)

reviewing-spec dispatch 시작 시 state.local.md 로드. v0.1.x schema (신규 필드 부재)면 *non-mutating read*로 자동 promote:

- `issue_history[].dismissed_by_user` / `accepted_by_user` / `reconsensus_count` 부재 → `0`으로 in-memory default.
- `reconsensus_accepted_ids` 부재 → `[]`로 in-memory default.

다음 state write 시점에 frontmatter에 자연스럽게 추가 (backward-rewriting 금지).

사용자에게 advisory: `[spec-distill v0.2.0] state.local.md schema migration: <fields> added with defaults.`

corruption 시 → "v0.1.x in-flight state 호환 실패 — 세션 재시작 권장" 알림 + state.local.md 보존 (P14).

## kill switch

- `DEVBREW_DISABLE_SPEC_DISTILL=1`: 즉시 abort, state.local.md 보존.
- `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN=N`: wall-clock budget override (default 30).
- **`DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS=1`** (v0.2.0): [3.5] Re-consensus gate 우회 + loud warning 출력.
  - 비상시 사용. v0.1.x 원래 자동 [4] path로 fallback.
  - 출력: `[spec-distill v0.2.0] WARNING: locked decisions 보호 비활성화됨 — 사용자 sovereignty 약화 위험. DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS=1로 [3.5] 우회됨.`
  - reviewer가 locked-affecting issue를 raise해도 자동 Mode B (모든 issue 적용).
