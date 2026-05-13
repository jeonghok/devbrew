# Fixture: Interview Transcript (b/b/d/a paths)

> AC1 verification fixture — drafting-spec Mode A가 이 transcript를 input으로 받아
> 결과 spec.md frontmatter에 LD1/LD2/LD3 3개 (b/b/d 답변)만 emit해야 함.
> (a) factual auto-confirm은 LD 없음.

## state.local.md (excerpt)

```yaml
session_id: fixture-bbda-001
phase: 1
interview_round: 4
issue_history: []
pending_locked_decisions:
  - id: LD1
    section: "#goals"
    summary: "G2 = 신규 사용자 onboarding은 in-scope"
    source: interview-round-1
    source_path: b
  - id: LD2
    section: "#acceptance-criteria"
    summary: "AC3 — 테스트는 30초 이내 통과"
    source: interview-round-2
    source_path: b
  - id: LD3
    section: "#non-goals"
    summary: "NG2 = 결제 흐름은 별도 spec (이 spec의 essence가 아님)"
    source: interview-round-3
    source_path: d
```

## Round transcripts

### Round 1 (path b — judgment, locked=true)
**현재 이해:** 사용자가 todo 앱을 원함.
**막힌 결정:** 신규 사용자 onboarding 포함 여부.
**추천 답안:** in-scope (사용자 첫 진입이 가장 중요).
**질문:** 신규 사용자 onboarding은 spec에 포함시킬까요?

**사용자 답변 (round 1):** "네, in-scope으로 해주세요."
→ `pending_locked_decisions.append(LD1)`

### Round 2 (path b — judgment, locked=true)
**현재 이해:** todo 앱 + onboarding.
**막힌 결정:** 테스트 실행 시간 제약.
**추천 답안:** 30초 이내.
**질문:** 통합 테스트 실행 시간을 30초 이내로 제한할까요?

**사용자 답변 (round 2):** "30초로 합시다."
→ `pending_locked_decisions.append(LD2)`

### Round 3 (path d — ontological, locked=true)
**현재 이해:** todo 앱 + onboarding + 빠른 테스트.
**막힌 결정:** essence — 결제 흐름까지 포함하는가?
**추천 답안:** 결제는 별도 spec, todo essence가 아님.
**질문:** [ESSENCE] todo 앱의 essence를 무엇으로 정의할까요? (결제 제외/포함)

**사용자 답변 (round 3):** "결제는 빼고 todo 자체에 집중."
→ `pending_locked_decisions.append(LD3)`

### Round 4 (path a — factual auto-confirm, locked=false)
**현재 이해:** todo 앱 essence + onboarding + 30s 테스트.
**막힌 결정:** 현재 repo의 test runner.
**추천 답안:** (auto-confirm via grep) — pytest.
**질문:** (none — auto-confirmed via grep `pytest.ini`)

**[from-code][auto-confirmed]** test runner = pytest.
→ pending_locked_decisions에 추가하지 않음 (path a).

## Expected drafting-spec Mode A output

spec.md frontmatter `locked_decisions:`에 LD1/LD2/LD3 정확히 3개 (LD4는 path a이므로 없음).
