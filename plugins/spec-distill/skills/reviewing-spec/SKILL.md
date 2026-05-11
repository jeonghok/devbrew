---
name: reviewing-spec
description: >
  Use this skill to dispatch the spec-reviewer agent against a spec.md draft
  and apply deterministic routing per the verdict × signal table. Manages re-
  review cap (max 3, AC6), stagnation detection (AC7), wall-clock budget (AC14),
  and approve handoff sequence (AC11). Routing table is defined below in this
  SKILL.md (AC15) — agent verdict × stagnation signal × rereview count → next phase.
cost_class: medium
---

# Reviewing Spec (Phase 3)

당신은 spec-distill의 review phase를 진행 중입니다. spec-reviewer agent를 dispatch하고, 받은 verdict + 메타 신호를 *deterministic table*에 매핑해서 다음 phase를 결정합니다.

## Steps

1. **Load state.local.md** — `session_id`, `rereview_count`, `wall_clock_started_at`, `issue_history` 읽기. `session_id`가 unbound이거나 placeholder `<session-id>` 인 채로면 Step 3 cleanup이 charset 검증으로 자동 skip되지만, 사용자에게 명시적 통보 필요 (P14 + AP2).
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

| Verdict | Stagnation_signal | rereview_count | → Next Phase |
|---|---|---|---|
| `approved` | - | - | **[5] Human Gate** (auto) |
| `needs_revise` | false | < 3 | **[4] Revise** (auto, dispatch drafting-spec Mode B) |
| `needs_revise` | false | >= 3 | **[5] Human Gate** (forced escalate, full issue_history 첨부) |
| `needs_revise` | true | - | **[5] Human Gate** (P18 stagnation, forced escalate) |
| `needs_interview` | - | - | **user confirm gate** → [1] Interview (확인) 또는 [5] (취소) |

매 dispatch 후 위 표를 *그대로* 적용. prose-based 결정 금지.

### Re-review cap (AC6)

`rereview_count >= 3` 도달 시 (즉 4번째 reviewer dispatch 시도 시): 자동으로 [5] Human Gate로 forced escalate, 전체 `issue_history` 첨부.

### Stagnation detection (AC7)

spec-reviewer agent가 `Stagnation_signal: true` 반환 시 (이전 review 동일 issue_id `raised_count >= 3 unresolved`): 자동 [5] forced escalate, P18 stagnation 명시.

## Phase 5 Human Gate

사용자에게 reviewer 결과를 표시하고, 다음 옵션 중 선택받습니다 (`AskUserQuestion` 활용):

- **"revise per review"** → drafting-spec Mode B 호출.
- **"more interview"** → conducting-interview skill 호출 (state phase = 1로 reset, interview_round 유지).
- **"edit spec myself"** → 사용자가 직접 spec.md 편집 후 반환 → reviewing-spec 재진입.
- **"approve"** → Approve handoff sequence (다음 섹션).

## Approve handoff sequence (AC11)

사용자 "approve" 선택 시 다음 4 step을 *그대로* 실행:

```bash
# Step 1: Commit spec.md
git add docs/superpowers/specs/<file>-spec.md
git commit -m "spec: <topic> (v1.0.0, spec-distill v0.1.0)"

# Step 2: Output handoff pointer
echo "Spec lock 완료. 다음 단계:"
echo "  superpowers writing-plans skill 호출"
echo "  Spec 경로: docs/superpowers/specs/<file>-spec.md"
echo "  명령: Skill superpowers:writing-plans <위 경로>"

# Step 3: State cleanup (guarded — charset allowlist; '.', '..', whitespace, traversal 모두 거부)
case "$session_id" in
  ''|*[!A-Za-z0-9_-]*)
    echo "[spec-distill] cleanup skipped: session_id invalid or unresolved ('${session_id:-<unset>}'). State preserved at .claude/spec-distill/ — 수동 cleanup 필요." >&2
    ;;
  *)
    rm -rf -- ".claude/spec-distill/$session_id/"
    ;;
esac

# Step 4: Plugin termination
echo "spec-distill v0.1.0 종료."
```

**polite stop 금지** (AP2): "spec is approved!"만 narrate하고 위 4 step을 skip하면 안 됨. 4 step 모두 *실제로* 실행.

### 실패 시 state 보존 (P14)

git commit 실패 / handoff 실패 / cleanup 실패 시: state.local.md 보존, 사용자에게 실패 원인 명시.

## kill switch

- `DEVBREW_DISABLE_SPEC_DISTILL=1`: 즉시 abort, state.local.md 보존.
- `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN=N`: wall-clock budget override (default 30).
