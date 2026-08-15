---
name: reviewing-spec
description: >
  Use this skill to dispatch the spec-reviewer agent against a brainstorming
  design doc (docs/superpowers/specs/...-design.md) and apply deterministic
  design-mode routing per the verdict table. Manages re-review cap (max 5,
  hard cap → forced escalate), stagnation detection, and the Phase 5 proceed gate +
  approve handoff. v0.12.0: design-mode only (spec-mode + spec-draft skill removed).
cost_class: medium
---

# Reviewing Spec (Phase 3)

당신은 spec-distill의 review phase를 진행 중입니다. spec-reviewer agent를 dispatch하고, 받은 verdict + 메타 신호를 *deterministic table*에 매핑해서 다음 phase를 결정합니다.

## Steps

1. **Load state.local.md (hook-facing 상태는 harness sid 로 명시 해석)** — 먼저 훅(Stop/UserPromptSubmit/PostToolUse)이 읽는 파일과 *정의상 동일한* harness session id + state root 로 상태 파일을 연다. 훅은 raw sid 가 아니라 `resolve_session_id`(env-first: `DEVBREW_SPEC_DISTILL_SESSION_ID` → `CLAUDE_CODE_SESSION_ID` → payload)를 쓰므로, 스킬도 같은 리졸버를 CLI 로 재사용한다(DRY, C4):

   ```bash
   harness_sid="$(python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/hooks/state_path.py" session-id)"
   ROOT="$(python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/hooks/state_path.py" state-root)"
   STATE="$ROOT/$harness_sid/state.local.md"   # 훅이 읽는 바로 그 파일
   ```

   이 `$STATE` 에서 `pending_review:`(→ `spec_path`·`mode`)를 읽는다. PostToolUse `spec-write-validator.py` 가 `pending_review:` 를 **항상 harness-sid 디렉토리**에 기록하므로, **read==write 디렉토리 불변식**(스킬의 pending/spec READ 와 `strip-pending`·`mark-reviewed` WRITE 가 같은 `$STATE` 를 가리킴)이 성립해야 원장(`armed_paths`)과 pending 이 훅이 읽는 바로 그 파일에 기록된다 — 어긋나면 arm-once 게이트가 훅과 다른 파일을 키잉해 통째로 무의미해진다. block 이 없으면 manual override(loud advisory). v0.12.0부터 **design mode 전용**: 11-section/locked_decisions schema 검사는 적용 안 함(brainstorming 자유 형식). 본문의 placeholder/ambiguity/scope-creep/approaches-comparison/isolation/testing/handoff_incomplete만 spec-reviewer 에게 요청.

   **불변식 (hook-facing 상태 vs continuity):** hook-facing 상태(`pending_review`·`armed_paths`·`dispatch_attempts`)의 read/write 는 harness sid(`$STATE`); `rereview_count`/`issue_history` continuity 는 이 fix 가 건드리지 않고 harness-sid 로 collapse 하지 않는다.

   **continuity read collapse 금지** — `rereview_count`/`issue_history`(아래 Step 5 에서 갱신) continuity 카운터는 인터뷰 선행 시 interview-UUID 파일(`conducting-interview/SKILL.md:35` self-`session_id`, `:41` `rereview_count`, `:43` `issue_history`)에 누적된다. **이 카운터의 읽기(이 Step)·쓰기(Step 5)를 `$harness_sid` 로 옮기지 말 것** — 옮기면 인터뷰-선행 플로우에서 `rereview_count` 가 0 으로 리셋돼 re-review cap(5)/round-level stagnation 조기-exit 가 약화된다. continuity 는 기존 메커니즘대로 읽고 쓴다(N1). 훅은 이 신호를 읽지 않으므로 read==write 불변식 대상이 아니다.

**pending strip (v0.25.0)** — state 로드 직후, `spec-reviewer` dispatch *전에* 이 문서의 pending 을 제거한다 (매 진입 — 최초 + revise 재진입):

```bash
python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/arm_ledger.py" strip-pending "$harness_sid" "$spec_path"
```

   `$harness_sid` 가 빈 값(env unset → `state_path.py session-id` exit 1)이면 **strip skip** — 조용히 넘어가지 말고 advisory 를 남긴다. pending 이 남아도 Law 1 fail-safe 방향(리뷰 강제)이라 안전하다.

dispatch 의 연료는 `pending_review` 다. 진입 시점에 연료를 없애면 subagent(async) 경계에서 발생하는 메인 `Stop` 이 진행 중인 리뷰를 재강제(중복/절단)할 수 없다 — v0.18.0 이 상태로 표현하던 불변식을 한 줄이 대체한다. 다른 문서의 pending 은 건드리지 않는다(같은-키만 strip). **여기서 원장(`armed_paths`)은 쓰지 않는다** — 진입은 리뷰의 *시작*일 뿐 완료가 아니다(§5.2).

2. **Dispatch spec-reviewer agent**:

   **Web kill switch (dispatch 직전 확인)**: `spec-reviewer`는 `WebSearch`/`WebFetch`를
   보유한다(v0.24.15에서 `WebSearch` 부여). `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`이면
   프롬프트에 `web_disabled: true`를 실어 **리포 근거만으로 리뷰**하게 하고 loud advisory를
   남긴다: `[spec-distill] web 비활성 — spec-reviewer가 리포 근거만 사용 (외부 사실 확인 없음)`.
   `spec-reviewer`는 `tools:`에 `Bash`가 없어 스스로 스위치를 읽을 수 없다(Law 2) —
   orchestrator가 유일한 집행 지점이다. 스위치는 보안 컨트롤이므로, egress를 가진
   dispatch가 하나라도 게이트 밖에 있으면 스위치는 꺼졌다고 *믿게만* 만든다.

   ```bash
   if [[ "${DEVBREW_SPEC_DISTILL_DISABLE_WEB:-0}" == "1" ]]; then
     web_disabled=true
     echo "[spec-distill] web 비활성 — spec-reviewer가 리포 근거만 사용 (외부 사실 확인 없음)" >&2
   else
     web_disabled=false
   fi
   ```

   ```
   Agent({
     description: "Spec adversarial review",
     subagent_type: "spec-distill:spec-reviewer",
     prompt: "Review spec.md at <path>. Previous issue history: <list>. web_disabled: <true|false — true면 WebSearch/WebFetch 사용 금지, 리포 근거만>"
   })
   ```

### Step 2.5 — codex 병렬 co-review + 결정론 병합 (v0.20.0)

전역 kill switch(`DEVBREW_DISABLE_SPEC_DISTILL=1`)가 켜져 있으면 이 스텝을 포함해 스킬 전체에 진입하지 않는다 — `review-dispatch.py`(Stop)가 dispatch 이전에 이미 걸러낸다. 아래는 codex 경로이며, **Claude 리뷰(Step 2)는 codex 가용성과 무관하게 항상 수행**된다 — codex kill switch가 Claude 리뷰를 막지 않는다(AC15: Claude dispatch는 codex-availability 조건 아래 nest되지 않음).

1. **⟦review-claude⟧ verbatim 저장 (C8)**: Step 2에서 받은 spec-reviewer의 **raw 출력을 요약·바꿔쓰기 없이 그대로(verbatim)** scratch 파일 `$CLAUDE_OUT`에 저장한다. 파싱은 merge_review가 그 파일에서 수행하므로, orchestrating 세션이 여기서 category/target_section을 전사(轉寫)하면 안 된다([fc2ef911] 재도입 금지).

2. **⟦detect⟧ + ⟦review-codex⟧ — 하나의 리터럴 게이트**:

   조건을 **산문으로 적지 않는다.** 이전 판은 `codex_avail=true일 때만`이라고 문장으로
   적고 bash fence는 무조건 실행되게 두었다 — 그 파일에 `codex_avail`을 검사하는 `if`가
   없었다. kill switch는 P21 보안 컨트롤이라 그 상태는 "껐다고 믿게만" 만든다.
   `reviewing-brief`의 게이트와 동형으로 맞춘다.

<!-- codex-gate:begin runner=run_spec_codex_reviewer.sh -->
```bash
SD="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}"
DETECT_OUT="$(bash "$SD/scripts/detect_codex.sh")"
codex_avail="$(printf '%s\n' "$DETECT_OUT" | sed -n 's/^codex_available: //p')"
skip_reason="$(printf '%s\n' "$DETECT_OUT" | sed -n 's/^skip_reason: //p')"
if [[ "$codex_avail" == "true" ]]; then
  bash "$SD/scripts/run_spec_codex_reviewer.sh" "$spec_path" "$(pwd)" "$CODEX_YAML"; runner_rc=$?
  # 러너는 fail-closed 산출물을 **쓰지 못하면** exit 3으로 죽는다(쓰기 불가·디렉토리
  # 부재). 그 경우 직전 라운드 YAML이 그대로 남아 이번 라운드 판정으로 읽히므로,
  # 잔존물을 제거하고 degraded로 기록한다 — 부재는 아래 merge_review.py의
  # 양성-마커 규칙이 degraded로 잡는다(reviewing-brief SKILL과 동일 패턴).
  if [[ "$runner_rc" -eq 3 ]]; then rm -f "$CODEX_YAML"; fi
else
  echo "[spec-distill] codex co-review SKIPPED (reason: ${skip_reason:-unknown}) — Claude-only, 이 리뷰에는 모델 다양성이 없었다 (degraded)." >&2
fi
```
<!-- codex-gate:end -->

   `DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1`이면 `detect_codex.sh`가
   `codex_available: false` + `skip_reason: kill_switch`를 내므로 codex만 skip되고
   **Claude 리뷰(Step 2)는 이미 정상 수행됐다** — codex kill switch가 Claude 리뷰를
   막지 않는다(AC15). `codex_avail=false`인 경우의 advisory는 위 블록이 stderr로 내며,
   사용자에게 그대로 노출한다.

3. **⟦merge⟧ (barrier)** — 두 리뷰가 모두 끝난 뒤 결정론 병합:
   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/merge_review.py" \
     --claude-output "$CLAUDE_OUT" \
     --codex-yaml "${CODEX_YAML:-/nonexistent}" \
     --history "$LEDGER_JSON"
   ```
   `$LEDGER_JSON`은 **continuity(interview-UUID) state dir**에 둔다(harness-sid로 collapse 금지 — /compact 넘어 re-review cap/stagnation 보존, N1). merge_review가 read-modify-write하므로 issue_history id/count를 세션이 손으로 전사하지 않는다.

   merge_review stdout(`combined_verdict` / `claude_verdict` / `codex_verdict` / `stagnation` / `codex_degraded` / `claude_degraded` / `claude_verdict_unrecoverable` / `codex_findings` / `advisory`)을 파싱한다. `advisory:` 항목은 사용자에게 **그대로 표시**(degrade 인지 + codex overturn 인지 — combined_verdict가 claude_verdict를 뒤집었을 때 merge_review가 내는 advisory도 여기 포함). `--codex-yaml`이 없거나 codex가 실패했으면 merge_review가 `codex_degraded: true`로 처리한다.

4. **blind-across-rounds (AC12, NG6)**: 각 리뷰어에게는 **same-origin history만** 전달한다 — Step 2의 spec-reviewer 프롬프트에는 codex 과거 findings를 넣지 않는다(두 리뷰 pass는 상호 blind). 통합 판정은 merge_review(orchestrator-side)만 수행한다.

3. **Parse merge_review output** — `combined_verdict`, `claude_verdict`, `codex_verdict`, `stagnation.per_issue`, `stagnation.round_level`, degrade flags, `codex_findings`, advisory. (Claude raw 출력 중 Status/Recommendations **prose**만 사람 표시용으로 사용 — verdict는 merge_review의 `combined_verdict`에서 온다. `Stagnation_signal`은 이 display-only 범위 밖이다: 아래 Re-review cap 항목 2 / "Stagnation detection" 절의 **보조 OR-trigger**로 계속 escalate 판정에 투입된다 — display-only 취급하지 말 것.)

   **codex 귀속 표시 (v0.20.1 — §5 codex 이슈 노출)**: `combined_verdict == needs_revise`이면 `codex_findings`(현재 라운드, category/target_section/severity/summary — 있는 키만) + (있다면) codex-overturn advisory를 저자에게 렌더한다. `issue_history`는 opaque id만 담고 codex의 실제 내용(category/summary 등)은 버리므로, `codex_findings`가 codex가 잡은 것이 **무엇**인지 보여주는 유일한 채널이다 — codex 소스 라벨을 붙여 표시(Claude 이슈는 prose로, codex 이슈는 이 블록으로 구분). Re-review cap이 hard cap/round-level stagnation으로 [5] Human Gate forced escalate할 때도 이 `codex_findings`를 (opaque id 대신) 함께 첨부한다 — 저자/사람이 codex가 실제로 무엇을 잡았는지 보게 한다.

   **리뷰 완료 기록 (v0.25.0)** — verdict 파싱 직후 원장에 이 문서를 기록한다. arm-once 의 종결 사건이며, 이 기록 이후의 같은-세션 편집은 재arm 되지 않는다:

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/arm_ledger.py" mark-reviewed "$harness_sid" "$spec_path"
   ```

   **예외 — 실질 리뷰가 0인 라운드에서는 호출하지 않는다.** merge_review 가 `claude_verdict_unrecoverable: true` **이면서** `codex_degraded: true` 인 both-dead fail-safe 분기는 아무도 리뷰하지 않았는데도 `combined_verdict: needs_revise` 를 낸다. 그 값을 원장에 기록하면 "리뷰가 실제로 일어났을 때만 표시된다"는 기록 시점의 근거가 그대로 무너진다. 배제된 라운드는 원장이 비어 다음 편집이 재시도하며, `dispatch_attempts` 는 계속 올라 G6 상한(3)이 결국 멈춘다. merge_review 자신도 이 분기에서 `issue_history` 원장을 갱신하지 않는다 — 같은 규칙의 두 적용이다.

   `$harness_sid` 가 빈 값이면 이 기록을 남길 수 없다. 조용히 넘어가지 말고 advisory 를 낸다:

   > `[spec-distill] harness_sid 미해석 — 이 세션의 상태 파일을 특정할 수 없어 리뷰 완료 기록(mark-reviewed)을 남기지 못했다. 같은 문서가 다시 dispatch될 수 있다. 해소: DEVBREW_SPEC_DISTILL_SESSION_ID로 sid를 명시하거나, 이 세션 동안 DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1로 arm을 끈다.`
4. **Apply routing table** — `combined_verdict`를 그대로 표에 투입한다(표 자체는 불변).
5. **Ledger는 merge_review가 소유** — `rereview_count += 1`은 기존 continuity 메커니즘대로 갱신. `issue_history`는 merge_review가 `$LEDGER_JSON`에 기록하므로 세션이 손으로 갱신하지 않는다(id/count 전사 금지). 세션은 merge_review가 emit한 `issue_history`를 표시만 한다.

## Deterministic Routing Table (AC15 — design-mode only, v0.12.0)

이 skill은 brainstorming의 `-design.md`만 검토합니다(spec-mode + 별도 spec-draft skill은 v0.12.0에서
제거됨). **이것은 이 skill의 스코프이지 brief에 리뷰가 없다는 뜻이 아닙니다** — v0.24.0부터
interview brief에는 전용 분리 리뷰어 3종(`brief-critic`·`brief-direction-reviewer`·`brief-readback`)과
별-모델 codex co-review가 `reviewing-brief` skill로 붙습니다. 여기서 다루는 것은 design doc 경로뿐입니다.

| Mode | Verdict | rereview_count | → Next Phase |
|---|---|---|---|
| **design** | `approved` | - | **[5] Human Gate** (proceed 게이트 — ①/② → `superpowers:writing-plans`) |
| **design** | `needs_revise` | < 5 | **brainstorming author 회귀**: 메인 agent가 design.md 직접 수정 후 reviewing-spec 재dispatch. |
| **design** | `needs_revise` | >= 5 | **[5] Human Gate** (forced escalate, full issue_history + codex_findings 첨부) |

매 dispatch 후 위 표를 *그대로* 적용. prose-based 결정 금지.

### Re-review cap (rereview_count, hybrid policy — v0.3.0 hook 통합)

두 조건 중 *하나라도* 충족 시 자동으로 [5] Human Gate로 forced escalate, 전체 `issue_history` + `codex_findings` 첨부:

1. **Hard cap**: `rereview_count >= 5` 도달 시 (즉 6번째 reviewer dispatch 시도 시). 기존 v0.2.0의 cap=3을 v0.3.0에서 cap=5로 상향 — multi-round drift detection을 위한 budget 확장.
2. **Round-level stagnation early-exit**: `rereview_count`와 무관하게 즉시 [5] Human Gate로 escalate. **Primary trigger**는 merge_review.py의 통합-원장 스캔이 emit하는 `stagnation.round_level == true`(상세는 아래 "Stagnation detection" 절) — blind-across-rounds 때문에 Claude 단독 self-report로는 codex-only로 반복된 이슈를 못 잡으므로, 이 통합 스캔이 round-level stagnation의 주 판정 경로다. spec-reviewer가 `verdict: needs_revise` + `Stagnation_signal: true`를 반환하는 경우도 **보조 OR-trigger**로 함께 escalate에 기여한다(단독 primary 트리거는 아님 — merge_review 미가용/degraded 상황에서도 fallback으로 작동). 이는 *수렴 실패 조기 감지* — issue가 새로 발견되지 않고 같은 항목이 반복 raise되는 상황을 한 라운드 안에 끝낸다.

per-issue stagnation(`raised_count >= 3 AND dismissed_by_user == 0`)과 위 (2)의 round-level stagnation은 trigger가 다르다 — 둘 다 [5] Human Gate forced escalate로 수렴.

### Stagnation detection (v0.20.0)

stagnation escalate는 이제 **merge_review.py의 통합-원장 스캔** 결과(`stagnation` flag)로 발동한다 — Claude의 `Stagnation_signal: true` self-report 단독이 아니다. blind-across-rounds 때문에 Claude는 codex가 과거에 올린 이슈를 못 보므로, codex-only로 반복된 이슈는 Claude self-report로는 절대 잡히지 않는다([6647ebfa] fail-open). merge_review가 통합 원장 위에서 독립적으로 스캔한다:

- **per-issue**: `stagnation.per_issue`에 든 issue_id는 `raised_count >= 3 AND dismissed_by_user == 0` — 두 조건 충족 시 [5] Human Gate forced escalate.
- **round-level**: `stagnation.round_level == true`(새 issue_id 無 + 미해결 잔존)면 즉시 [5] Human Gate escalate. `round_level == inconclusive`(claude_degraded 라운드 — 파싱 실패를 수렴으로 오독 금지, OQ4)면 escalate 트리거로 쓰지 않는다.

Claude의 `Stagnation_signal: true`는 **보조 신호**로 남는다(유일 트리거 아님) — merge_review flag가 primary trigger. `dismissed_by_user >= 1`인 issue는 stagnation에서 제외(P17) — 사용자 명시 거절은 P17 sovereignty 행사이지 stagnation이 아님.

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
      {label: "/compact 후 writing-plans (권장)", description: "미커밋 advisory(check-born) 후 verbatim /compact 명령 노출 → 사용자 /compact 실행 시 writing-plans. 긴 인터뷰 context 정리 이점."},
      {label: "바로 writing-plans", description: "미커밋 advisory(check-born) 후 즉시 Skill superpowers:writing-plans <path> 호출 (compact 없이)."},
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
- **④ 멈춤**: state 보존하고 종료. **상태 조작 없음** — 이 문서의 pending 은 Step 1 에서 이미 제거됐고, 원장에는 verdict 시점에 이미 기록됐다(§5.2). 그 세션에서 자동 재발동은 없다. 재개는 사용자 요청 시 skill 수동 호출로 한다(D2·NG1).

### polite stop 금지 (AP2 — verifiable, AC11)

approve(①/②) 선택 후 "approved!"만 narrate하고 Approve handoff sequence 호출/다음 phase 진입을 skip하는 것은 **polite stop**. Phase 5를 *종료*하는 모든 경로는 (a) 위 proceed 게이트 제시를 거치거나(①/②/③/④), (b) 게이트를 거치지 않는 예외 경로(Step A spec_path 부재, kill switch)는 명시적 advisory 단락을 동반해야 한다 — 게이트-less silent 종료 금지. (게이트는 사용자가 redirect 가능한 approval gate이므로 P17 주권에 기여하며 polite-stop이 아니다 — 철학 §AP2.)

### cross-compact 조기 진행 금지 (AC19 — polite stop의 *반대* 실패 모드, verifiable)

옵션 ① 선택 시 `/compact`를 노출한 *직후* 같은 턴에서 `writing-plans`로 직진하는 것은 금지. compact가 무거운 plan-write *뒤에* 오면 context 위생 이점이 사라져 옵션 ①이 무의미해진다 (2026-05-29 본 design 세션에서 실측된 실패: "handoff"라 말하고 compact 전에 plan을 그대로 써버림). 다음 턴 진입은 *사용자 트리거*(예: `/compact write plan` 인자)로만 일어나며 모델 자동 진입이 아니다(NG4·P17). polite stop이 "진행해야 할 때 멈춤"이라면 이것은 "멈춰야 할 때 진행" — 두 방향 모두 게이트의 사용자-주권(P17)을 우회한다. **verifiable (두-레이어, AC11 선례)**: (i) `grep -cE "턴 종료|다음 턴"` ≥ 1, **AND** (ii) 옵션 ① 서술 *블록 안에서* 'turn-ending(STOP)' + 'writing-plans 같은 턴 호출 금지' + '다음 턴 = 사용자 트리거'가 *함께* 명시됐음을 리뷰에서 확인 (grep 단독은 두 문구의 같은-블록 공존을 보장 못 하므로 — false-positive: '턴 종료' 문구와 '같은 턴 호출' 문구가 떨어져 공존해도 통과 — 공존·정합 판정은 리뷰 레이어 담당; mechanical 한계는 AC11과 동일 수준 인정). 옵션 ②는 이 정지 요건의 *명시적 예외*(compact 없이 즉시 writing-plans). **AC8 경계** (round-2 advisory 반영): AC8 '추가 AskUserQuestion 없음'은 *approve 옵션이 최종 확정된 그 어시스턴트 응답 턴*에 한정한다 (Phase 5 내 revise/interview 루프의 다른 턴이 아님 — 그 턴들은 본래 질문을 띄움). 다음 턴에 진입한 writing-plans가 자체 실행-방식 선택 게이트를 띄우는 것은 별개 skill scope이므로 AC8 해당 없음.

## Approve handoff sequence (①/② 공통)

approve(①/②) 시 상태 조작은 없다. 이 시점에 남은 유일한 할 일은 **문서가 아직 git 에 없으면 알리는 것**이다:

```bash
python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/arm_ledger.py" check-born "$spec_path"
```

exit 0 = git-tracked (할 말 없음). exit 1 = 미커밋 — 스크립트가 stderr 로 낸 advisory 를 **그대로 사용자에게 노출**한다:

> `[spec-distill] '<path>'가 아직 git에 없다 — 지금 커밋하지 않으면 다음 세션에서 이 문서의 리뷰가 한 번 더 발동한다.`

arm-once 의 세션-바깥 조건은 `is_born`(git 추적 여부)이다. 커밋하지 않은 채 세션을 넘기면 이 문서의 리뷰가 한 번 더 발동한다 — 이 advisory 가 그 사실을 사용자에게 미리 알리는 유일한 신호이며, 비용을 0으로 만드는 행위(문서를 커밋하는 것)를 촉구한다. 동시에 approve 가 **관측 가능한 부수효과**를 남기게 해 AP2 검증 앵커도 겸한다.

**polite stop 금지** (AP2): approve 인데 이 호출/게이트를 skip 하고 narrate 만 하지 말 것.

### 실패 시 state 보존 (P14)

`check-born` 은 판정만 하고 상태를 쓰지 않는다 — 실패해도 잃을 상태가 없다. out-of-scope 경로면 exit 2 + advisory(비-fatal). in-scope 이지만 working-tree 에 없는 dangling 경로는 abort 를 유발하지 않고 "미커밋" 판정 + advisory 로 끝난다. 세션 dir 정리는 SessionEnd hook / TTL-GC 가 담당한다. git commit 실패 경로는 존재하지 않는다(스크립트가 commit 을 시도하지 않는다).

## In-flight state migration (C10)

reviewing-spec dispatch 시작 시 state.local.md 로드. v0.1.x schema (신규 필드 부재)면 *non-mutating read*로 자동 promote:

- `issue_history[].dismissed_by_user` 부재 → `0`으로 in-memory default (stagnation count 제외 판정에 사용).

다음 state write 시점에 frontmatter에 자연스럽게 추가 (backward-rewriting 금지).

사용자에게 advisory: `[spec-distill v0.2.0] state.local.md schema migration: <fields> added with defaults.`

corruption 시 → "v0.1.x in-flight state 호환 실패 — 세션 재시작 권장" 알림 + state.local.md 보존 (P14).

## kill switch

- `DEVBREW_DISABLE_SPEC_DISTILL=1`: 즉시 abort, state.local.md 보존.
- `DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1`: codex co-review만 skip(Claude 리뷰 정상). combined = Claude verdict + loud degrade advisory.
