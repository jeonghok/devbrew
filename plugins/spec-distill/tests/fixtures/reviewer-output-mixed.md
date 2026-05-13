# Fixture: Reviewer output — mixed locked + unlocked issues

> AC2 contract 명세. reviewer가 위 locked-decisions-spec.md에 dispatch될 때
> 모든 issue 라인 다음에 indented `affects_locked_decisions: [...]` 필드 emit.
> LLM 출력 비결정성 수용 — 이 fixture는 schema 검증용 (manual replay 없음).

## Spec Review (round 1)

**Status:** needs_revise

**Issues:**

- [abc12345] [#goals]: scope_creep — "G2 (onboarding)가 너무 광범위, Non-goals로 빼라"
  affects_locked_decisions: [LD1]

- [def67890] [#non-goals]: missing_section — "Non-goals 섹션이 비어있음"
  affects_locked_decisions: []

- [ghi13579] [#acceptance-criteria]: untestable_AC — "AC3의 30s 기준이 어느 hardware인지 불명"
  affects_locked_decisions: [LD2]

**Recommendations (advisory):**
- G2를 in-scope 정당화 단락 추가 권장.

**Stagnation_signal:** false
