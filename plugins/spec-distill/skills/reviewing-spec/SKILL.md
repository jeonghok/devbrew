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

| Verdict | Stagnation_signal | rereview_count | affects_locked | → Next Phase |
|---|---|---|---|---|
| `approved` | - | - | - | **[5] Human Gate** (auto) |
| `needs_revise` | false | < 3 | **empty (모든 issue)** | **[4] Revise** (auto, dispatch drafting-spec Mode B with `allowed_issue_ids = [all]`) |
| `needs_revise` | false | < 3 | **non-empty (하나 이상)** | **[3.5] Re-consensus gate** (다음 sub-section 참조) |
| `needs_revise` | false | >= 3 | - | **[5] Human Gate** (forced escalate, full issue_history 첨부) |
| `needs_revise` | true | - | - | **[5] Human Gate** (P18 stagnation, forced escalate — 단 dismissed_by_user >= 1 issue는 stagnation count 제외) |
| `needs_interview` | - | - | - | **user confirm gate** → [1] Interview (확인) 또는 [5] (취소) |

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

state.local.md에 `mode_b_violation` marker 존재 시 (Mode B abort 후 복귀):
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

### Re-review cap (rereview_count)

`rereview_count >= 3` 도달 시 (즉 4번째 reviewer dispatch 시도 시): 자동으로 [5] Human Gate로 forced escalate, 전체 `issue_history` 첨부. (위 P1–P4와 별개 cap — 무한 review loop 방지.)

### Stagnation detection (P3 row 참조)

spec-reviewer agent가 `Stagnation_signal: true` 반환 시: 해당 issue에 대해 `raised_count >= 3 AND dismissed_by_user == 0` 검증. 두 조건 모두 충족 시 P3 trigger.

`dismissed_by_user >= 1`인 issue는 stagnation count에서 제외 — 사용자 명시 거절은 P17 sovereignty 행사이지 stagnation이 아님.

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
