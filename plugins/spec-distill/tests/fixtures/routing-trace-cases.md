# Fixture: routing-trace-cases

> AC3, AC7 검증. reviewing-spec SKILL.md의 deterministic routing table을
> 각 case별로 expected branch에 매핑. manual review로 verify.

## Case A — all unlocked, count < 3 → [4] Revise (자동)

Input:
- reviewer issues = [{id: A1, affects_locked_decisions: []}, {id: A2, affects_locked_decisions: []}]
- rereview_count = 0
- stagnation_signal = false

Expected routing: **[4] Revise** with `allowed_issue_ids = [A1, A2]`.

## Case B — mixed locked + unlocked → [3.5] Re-consensus

Input:
- reviewer issues = [{id: B1, affects_locked_decisions: [LD1]}, {id: B2, affects_locked_decisions: []}]
- rereview_count = 0

Expected routing: **[3.5] Re-consensus** (AskUserQuestion for LD1).
B2는 사용자 응답 후 [4]로 진행.

## Case C — needs_interview verdict → user confirm → [1]

Input:
- reviewer verdict = needs_interview

Expected routing: user confirm gate → [1] Interview (확인) 또는 [5] (취소).

## Case D — stagnation_signal: true → [5] forced escalate

Input:
- reviewer issues = [{id: D1, raised_count: 3, dismissed_by_user: 0}]
- stagnation_signal = true

Expected routing: **[5] Human Gate** (forced, P18 stagnation).

## Case E — v0.1.x spec (locked_decisions 부재) → empty default → [4]

Input:
- spec.md frontmatter에 `locked_decisions` 키 없음 (v0.1.x).
- reviewer issues = [{id: E1, affects_locked_decisions: []}]  # empty default

Expected routing: **[4] Revise** (자동, 기존 v0.1.x path 동작). AC7 충족.
