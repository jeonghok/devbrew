---
name: drafting-spec
description: >
  Use this skill to (a) draft initial spec.md from interview transcript at end
  of conducting-interview phase, or (b) revise spec.md per spec-reviewer issues
  (Phase 4 of spec-distill flow). Writes to docs/superpowers/specs/YYYY-MM-DD-
  <topic>-spec.md using templates/spec-template.md as scaffolding.
cost_class: low
---

# Drafting Spec (Phase 2 / Phase 4)

당신은 spec-distill의 spec writer입니다. 두 가지 모드로 동작합니다.

## Mode A: Initial draft (Phase 2)

`conducting-interview` skill의 종료 후 호출됨. 인터뷰 transcript를 input으로 받아 첫 spec.md draft를 생성합니다.

### Steps

1. **Read template**: `${CLAUDE_PLUGIN_ROOT}/templates/spec-template.md` 로 11 섹션 + frontmatter 구조 확보.
2. **Resolve filename**: `docs/superpowers/specs/<YYYY-MM-DD>-<kebab-case-topic>-spec.md`. `<topic>`는 인터뷰에서 도출한 Goal에서 추출 (kebab-case, 4-6 words max).
3. **Fill 11 sections** from transcript (AC3):
   - **Goal** — 한 문장 (인터뷰에서 도출한 최종 Goal).
   - **Context / Why** — motivation, who asked, what's at stake.
   - **Goals** — bullet list with G1, G2, ... (testable).
   - **Non-goals** — bullet list with NG1, NG2, ... (명시적 제외).
   - **Constraints** — bullet list with C1, C2, ... (tech/시간/팀 제약).
   - **Acceptance Criteria** — bullet list with AC1, AC2, ... (*측정 가능* 표현, untestable 표현 금지).
   - **Files to Modify** — 인터뷰에서 도출한 경로 (없으면 "TBD — implementation phase에서 결정").
   - **Verification Plan** — bullet list with V1, V2, ... (manual/automated check + exact command).
   - **Rejected Alternatives** — 인터뷰 중 거절된 옵션을 R1, R2, ... 형태로.
   - **Open Questions** — 인터뷰 종료 시 미해결 항목 (없으면 "None").
   - **Concrete Next Action** — 다음 단계 명시 (default: superpowers writing-plans 호출 + spec 경로 + plan 산출 경로 + 명령).
4. **Fill frontmatter** (8 fields):
   - `name`, `version: 1.0.0`, `created_at`, `session_id`, `status: locked`, `next_phase: writing-plans`, `source: spec-distill v0.2.0`.
   - **`locked_decisions:`** — state.local.md의 `pending_locked_decisions:` 리스트를 그대로 frontmatter로 변환. (G2, AC1)
     - 각 LD entry: `id`, `section`, `summary` (160자 이내 단일 라인, P21 secret placeholder 치환), `source` (`interview-round-<N>` 형식), `source_path` (b/c/d).
     - `pending_locked_decisions`가 빈 리스트면 `locked_decisions: []`로 emit (frontmatter에 키는 존재, 값만 빈 리스트).
5. **Write file** with `Write` tool to resolved path.
> **v0.3.0+ 변경**: Step 5의 `Write` 직후 PostToolUse hook이 spec.md를 감지해 `pending_review:` block을 state.local.md에 기록하고, Stop hook이 다음 turn에 reviewer dispatch를 systemMessage로 강제한다. drafting-spec skill 본체가 `reviewing-spec` skill을 명시 호출하지 않아도 trigger 결정론적으로 발동.
6. **Update state.local.md**: `phase: 3` (다음은 reviewer phase).

### Superseded LD 보존 정책 (NG6)

v0.2.0에서 superseded LD는 frontmatter에 *무제한 보존* — count cutoff 없음. archive 정책은 v0.3.0+로 deferred.
- 새 LD가 기존 LD를 superseded할 때 (Mode B가 호출): 기존 LD에 `superseded_by: LD<new>` 추가, 새 LD에 `supersedes: LD<old>` 추가.
- Mode A는 *initial draft*이므로 supersession 마커를 직접 생성하지 않음 (Mode B 전용).

## Mode B: Revise per review (Phase 4)

`reviewing-spec` skill에서 사용자가 "revise per review" 선택 시 호출됨.

### Input contract (G6, AC5)

Mode B는 다음 입력을 reviewing-spec skill로부터 받음:

- `spec_path`: 수정할 spec.md 경로
- `issues`: reviewer가 raise한 전체 issue 리스트
- **`allowed_issue_ids`** (필수, 빈 리스트도 명시): 적용 허가받은 issue ID 리스트. 이 리스트에 *없는* issue ID의 변경은 *절대 적용 금지*.
- (선택) `superseded_LD_ids`: re-consensus [3.5]에서 사용자가 (1) 수용한 LD ID 리스트. 해당 LD를 `superseded_by` 마커와 함께 유지하고 새 LD 추가.

`allowed_issue_ids`가 빈 리스트인 경우: 어떤 issue도 적용하지 않음 (no-op return, state.local.md 변경 X).

### Steps

1. **Read current spec.md** + `issues` 리스트 + `allowed_issue_ids` 입력 + (있다면) `superseded_LD_ids`.
2. **Filter issues**: `issues` 중 `id in allowed_issue_ids` 만 추출. 나머지는 무시.
3. **For each filtered issue**, identify the target section (`#goals`, `#acceptance-criteria` 등) and apply targeted fix:
   - `missing_section` → 섹션 추가.
   - `concrete_action_missing` → "Concrete Next Action" 섹션 채움.
   - `ambiguous_requirement` → 측정 가능 표현으로 재작성.
   - `unstated_assumption` → "Constraints" 또는 "Context" 섹션에 명시 추가.
   - `untestable_AC` → AC를 verification 명령 + 예상 결과 형태로 재작성.
   - `scope_creep` → Non-goals 섹션 강화 또는 Goals 분리.
4. **Apply supersession markers** (만약 `superseded_LD_ids` 제공됨): spec.md frontmatter `locked_decisions:` 안에서 각 superseded LD에 `superseded_by: LD<new_id>` 추가, 새 LD entry에 `supersedes: LD<old_id>` 추가. NG6 — 무제한 보존, 둘 다 frontmatter에 남김.
5. **Pre-write guard check**: 적용하려는 모든 변경이 `allowed_issue_ids` 안에 있는지 한 번 더 검증. 외부 issue 변경 시도가 감지되면 → 즉시 abort (다음 sub-section 참조).
6. **Write file** with `Edit` tool (전체 rewrite 대신 targeted edit).
7. **Update state.local.md**: `issue_history`에 resolved 마커 표시 (해당 `issue_id`의 `resolved: true`).
> **v0.3.0+ 변경**: Step 6의 `Edit` 직후 hook이 동일 메커니즘으로 reviewing-spec dispatch를 강제. 단 `last_dispatched_at` TTL 가드로 self-ref cycle 방지 — Mode B의 정상 edit cycle은 TTL 만료 후 통과.
8. **Re-dispatch reviewing-spec** for re-review.

### Abort flow (issue `e5f208a0`, AC5)

`allowed_issue_ids`에 없는 issue 적용이 감지되면 (Step 5 또는 Step 3 도중):

1. spec.md edit 즉시 중단. 이미 적용된 partial edit이 있으면 `git restore <spec-path>` 실행 — Edit tool은 working tree를 직접 수정하므로 `git reset HEAD --`는 효과 없음, `git restore`로 working tree를 HEAD 상태로 복원.
2. state.local.md에 다음 marker 기록:
   ````yaml
   mode_b_violation:
     attempted_issue_id: <id>
     allowed: [<allowed_issue_ids>]
     timestamp: <ISO8601>
   ````
3. reviewing-spec [3.5] sub-step으로 제어 반환 (reviewing-spec이 `mode_b_violation` marker 감지).
4. 사용자에게 advisory 표시:
   > Mode B contract 위반 — `<id>`가 `allowed_issue_ids`에 없음. 재합의 round 누락 가능성. 옵션: (i) 해당 issue를 re-consensus에 추가 / (ii) Mode B 재dispatch (수동 issue 선택) / (iii) [5] Human Gate로 escalate.

### In-flight state migration (C10)

state.local.md 로드 시 v0.1.x schema (신규 필드 부재)면 *non-mutating read*로 자동 promote:
- `issue_history[].dismissed_by_user` / `accepted_by_user` / `reconsensus_count` 부재 → `0`으로 in-memory default.
- 다음 state write 시점에 frontmatter에 자연스럽게 추가.
- backward-rewriting 금지 — 명시적 write 시점에만 frontmatter 갱신.
- 사용자에게 advisory: `[spec-distill v0.2.0] state.local.md schema migration: <fields> added with defaults.`
- corruption 시 → "v0.1.x in-flight state 호환 실패 — 세션 재시작 권장" + state.local.md 보존.

## "유추 금지" 원칙 (사용자 #3 반영)

draft 중 인터뷰에서 답을 못 얻은 항목은 **유추하지 말고** "Open Questions"에 박제. 임의 가정은 spec contract violation.

## kill switch

- `DEVBREW_DISABLE_SPEC_DISTILL=1`: 즉시 abort, draft 미완성이면 그대로 보존.
- `DEVBREW_SKIP_HOOKS=spec-distill:<event>`: hook-specific skip — skill 자체에는 직접 영향 없으나, 관련 hook(UserPromptSubmit/SessionStart)이 비활성화될 수 있어 명시 (doc consistency).

## 다음 phase

`reviewing-spec` skill 호출. spec.md 경로를 input으로.
