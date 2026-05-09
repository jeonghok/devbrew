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
4. **Fill frontmatter** (7 fields): `name`, `version: 1.0.0`, `created_at`, `session_id`, `status: locked`, `next_phase: writing-plans`, `source: spec-distill v0.1.0`.
5. **Write file** with `Write` tool to resolved path.
6. **Update state.local.md**: `phase: 3` (다음은 reviewer phase).

## Mode B: Revise per review (Phase 4)

`reviewing-spec` skill에서 사용자가 "revise per review" 선택 시 호출됨.

### Steps

1. **Read current spec.md** + reviewer's `Issues` list.
2. **For each issue**, identify the target section (`#goals`, `#acceptance-criteria` 등) and apply targeted fix:
   - `missing_section` → 섹션 추가.
   - `concrete_action_missing` → "Concrete Next Action" 섹션 채움.
   - `ambiguous_requirement` → 측정 가능 표현으로 재작성.
   - `unstated_assumption` → "Constraints" 또는 "Context" 섹션에 명시 추가.
   - `untestable_AC` → AC를 verification 명령 + 예상 결과 형태로 재작성.
   - `scope_creep` → Non-goals 섹션 강화 또는 Goals 분리.
3. **Write file** with `Edit` tool (전체 rewrite 대신 targeted edit).
4. **Update state.local.md**: `issue_history`에 resolved 마커 표시 (해당 `issue_id`의 `resolved: true`).
5. **Re-dispatch reviewing-spec** for re-review.

## "유추 금지" 원칙 (사용자 #3 반영)

draft 중 인터뷰에서 답을 못 얻은 항목은 **유추하지 말고** "Open Questions"에 박제. 임의 가정은 spec contract violation.

## kill switch

- `DEVBREW_DISABLE_SPEC_DISTILL=1`: 즉시 abort, draft 미완성이면 그대로 보존.

## 다음 phase

`reviewing-spec` skill 호출. spec.md 경로를 input으로.
