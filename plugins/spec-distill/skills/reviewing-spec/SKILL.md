---
name: reviewing-spec
description: >
  Use this skill to dispatch the spec-reviewer agent against a brainstorming
  design doc (docs/superpowers/specs/...-design.md) and apply deterministic
  design-mode routing per the verdict table. Manages re-review cap (max 5,
  hard cap → forced escalate), stagnation detection, wall-clock budget, and the Phase 5 proceed gate +
  approve handoff. v0.12.0: design-mode only (spec-mode + spec-draft skill removed).
cost_class: medium
---

# Reviewing Spec (Phase 3)

당신은 spec-distill의 review phase를 진행 중입니다. spec-reviewer agent를 dispatch하고, 받은 verdict + 메타 신호를 *deterministic table*에 매핑해서 다음 phase를 결정합니다.

## Steps

1. **Load state.local.md** — `session_id`, `rereview_count`, `wall_clock_started_at`, `issue_history` 읽기 + `pending_review:` block 확인. 이 skill은 PostToolUse hook이 design 파일 write를 감지해 `pending_review:` block을 기록하고 Stop hook이 다음 turn에 dispatch를 강제했기 때문에 호출됨 — block이 없으면 manual override(loud advisory). v0.12.0부터 **design mode 전용**: 11-section/locked_decisions schema 검사는 적용 안 함(brainstorming의 자유 형식 design doc). 본문의 placeholder/ambiguity/scope-creep/approaches-comparison/isolation/testing/handoff_incomplete만 spec-reviewer에게 요청.
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

## Deterministic Routing Table (AC15 — design-mode only, v0.12.0)

이 skill은 brainstorming의 `-design.md`만 검토합니다(spec-mode + 별도 spec-draft skill은 v0.12.0에서
제거됨 — interview는 brief까지 단독 완결, design doc만 Law 2 분리 reviewer 대상).

| Mode | Verdict | rereview_count | → Next Phase |
|---|---|---|---|
| **design** | `approved` | - | **[5] Human Gate** (proceed 게이트 — ①/② → `superpowers:writing-plans`) |
| **design** | `needs_revise` | < 5 | **brainstorming author 회귀**: 메인 agent가 design.md 직접 수정 후 reviewing-spec 재dispatch. |
| **design** | `needs_revise` | >= 5 | **[5] Human Gate** (forced escalate, full issue_history 첨부) |

매 dispatch 후 위 표를 *그대로* 적용. prose-based 결정 금지.

### Re-review cap (rereview_count, hybrid policy — v0.3.0 hook 통합)

두 조건 중 *하나라도* 충족 시 자동으로 [5] Human Gate로 forced escalate, 전체 `issue_history` 첨부:

1. **Hard cap**: `rereview_count >= 5` 도달 시 (즉 6번째 reviewer dispatch 시도 시). 기존 v0.2.0의 cap=3을 v0.3.0에서 cap=5로 상향 — multi-round drift detection을 위한 budget 확장.
2. **Round-level stagnation early-exit**: spec-reviewer가 `verdict: needs_revise` + `Stagnation_signal: true` 를 반환한 경우, `rereview_count`와 무관하게 즉시 [5] Human Gate로 escalate. 이는 *수렴 실패 조기 감지* — issue가 새로 발견되지 않고 같은 항목이 반복 raise되는 상황을 한 라운드 안에 끝낸다.

per-issue stagnation(`raised_count >= 3 AND dismissed_by_user == 0`)과 위 (2)의 round-level stagnation은 trigger가 다르다 — 둘 다 [5] Human Gate forced escalate로 수렴.

### Stagnation detection

spec-reviewer agent가 `Stagnation_signal: true` 반환 시: 해당 issue에 대해 `raised_count >= 3 AND dismissed_by_user == 0` 검증. 두 조건 모두 충족 시 [5] Human Gate forced escalate.

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
      {label: "/compact 후 writing-plans (권장)", description: "approve_handoff(검증+suppress) 후 verbatim /compact 명령 노출 → 사용자 /compact 실행 시 writing-plans. 긴 인터뷰 context 정리 이점."},
      {label: "바로 writing-plans", description: "approve_handoff 후 즉시 Skill superpowers:writing-plans <path> 호출 (compact 없이)."},
      {label: "수정 필요", description: "approve 아님 — 후속 질문으로 revise per review / more interview / edit myself 분기."},
      {label: "멈춤 (나중에)", description: "state 보존하고 종료."}
    ],
    multiSelect: false
  }]
})
```

### Step C — 응답 처리

- **① /compact 후 writing-plans**: Approve handoff sequence 실행 → 사용자에게 아래 verbatim `/compact` 명령을 *그대로 보이게* 노출 (`<path>`는 실제 spec_path로 치환) + "compact 후 writing-plans 진입 준비됨" 안내:

  > `/compact spec at <path> 보존 — 본문(특히 Handoff Context, Acceptance Criteria, Files to Modify) 유지하고 인터뷰 대화·기각된 대안·중간 추론은 drop. 다음 단계: Skill superpowers:writing-plans <path>.`

  → **여기서 턴 종료(STOP). 같은 턴에서 `writing-plans`를 호출하지 말 것** (compact 전 writing-plans 진입 = 옵션 ① 무력화). `Skill superpowers:writing-plans <path>` 진입은 사용자가 `/compact`를 *실제 실행한 다음 턴*에 **사용자 트리거**(예: `/compact write plan`처럼 compact 뒤에 붙인 진행 인자, 또는 명시적 진행 요청)로만 일어난다 — 모델은 다음 턴에 자동 진입하지 *않고* 신호를 기다리며, 사용자가 redirect하면 미진입(NG4·P17). compact된 fresh context에서 plan 작성 (AC19).
- **② 바로 writing-plans**: Approve handoff sequence 실행 → 즉시 `Skill superpowers:writing-plans <path>` 호출.
- **③ 수정 필요**: 후속 `AskUserQuestion`으로 분기 — "revise per review" → 메인 agent가 design.md 직접 수정 후 reviewing-spec 재진입; "more interview" → conducting-interview (state phase=1 reset); "edit myself" → 사용자 편집 후 reviewing-spec 재진입.
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

스크립트(v0.15.0+)가 thin finalizer로 동작: (1) kill switch + charset guard, (2) **approved spec를 `suppressed_paths`에 기록 + 같은-키 pending strip** (`suppress_state.py add` — canonical_key 기반, 파일 존재 불필요; 가장 먼저 수행돼 상대경로·서브디렉토리 cwd·dangling 경로 어떤 경우에도 기록 보장), (3) spec_path working-tree 존재 검증을 **non-blocking advisory로** (부재 시 stale/dangling 안내; suppress는 이미 (2)에서 기록됨, exit 0), (4) 미커밋 spec advisory (non-blocking, exit 0). 세션 dir는 더 이상 여기서 삭제하지 않음 — SessionEnd hook / TTL-GC가 정리(승인 기억을 세션 동안 보존). 다음-단계 추천은 proceed 게이트가 담당. idempotent by set-membership(재호출은 키를 최대 1회 추가). (v0.15.0: (2)↔(3) 순서 역전이 같은-턴 재dispatch 순서 버그를 닫음.)

**polite stop 금지** (AP2): approve인데 스크립트 호출/게이트를 skip하고 narrate만 하지 말 것. SessionEnd hook이 backup cleanup이나 user-explicit approve 의도는 즉시 반영.

### 실패 시 state 보존 (P14)

approve_handoff.sh의 exit 1은 **session_id charset/arg 검증 실패에 한정**한다(v0.15.0). spec_path가 in-scope(`docs/superpowers/specs/` prefix)이면 working-tree 부재여도 suppress를 기록하고 exit 0 + stale advisory를 낸다 — 부재는 더 이상 abort가 아니다(Step A 통과 후 race로 사라진 경우 포함). 에이전트는 스크립트 stderr advisory를 그대로 노출한다. suppress 기록 실패(out-of-scope 경로 등)는 advisory only (non-fatal) — 사용자가 `/spec-distill:cancel-review`로 수동 억제 가능, 세션 dir 정리는 SessionEnd/TTL-GC. git commit 실패 경로는 존재하지 않음 (스크립트가 commit 시도 안 함; 미커밋은 advisory).

## In-flight state migration (C10)

reviewing-spec dispatch 시작 시 state.local.md 로드. v0.1.x schema (신규 필드 부재)면 *non-mutating read*로 자동 promote:

- `issue_history[].dismissed_by_user` 부재 → `0`으로 in-memory default (stagnation count 제외 판정에 사용).

다음 state write 시점에 frontmatter에 자연스럽게 추가 (backward-rewriting 금지).

사용자에게 advisory: `[spec-distill v0.2.0] state.local.md schema migration: <fields> added with defaults.`

corruption 시 → "v0.1.x in-flight state 호환 실패 — 세션 재시작 권장" 알림 + state.local.md 보존 (P14).

## kill switch

- `DEVBREW_DISABLE_SPEC_DISTILL=1`: 즉시 abort, state.local.md 보존.
- `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN=N`: wall-clock budget override (default 30).
