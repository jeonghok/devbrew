# Fixture: stagnation-cases

> AC6 검증. 새로운 stagnation 조건: `raised_count >= 3 AND dismissed_by_user == 0`.

## Case 1 — raised=3, dismissed=0 → stagnation true

state.local.md issue_history excerpt:
```yaml
- id: STG1
  raised_count: 3
  dismissed_by_user: 0
  accepted_by_user: 0
  reconsensus_count: 0
  resolved: false
```

Expected: Stagnation_signal == true → P3 forced escalate ([5]).

## Case 2 — raised=3, dismissed=1 → stagnation false

```yaml
- id: STG2
  raised_count: 3
  dismissed_by_user: 1
  accepted_by_user: 0
  reconsensus_count: 0
  resolved: false
```

Expected: Stagnation_signal == false (사용자 명시 거절 1회는 stagnation 제외).
다음 round에서 reviewer가 다시 raise해도 P18 trigger 안 됨.

## Case 3 — raised=3, dismissed=3 → reviewer-persona-warn (P4)

```yaml
- id: STG3
  raised_count: 3
  dismissed_by_user: 3
  accepted_by_user: 0
  reconsensus_count: 0
  resolved: false
```

Expected: Stagnation_signal == false. P4 trigger:
- 해당 issue [5] escalate.
- 사용자에게 advisory: "reviewer가 같은 issue를 3회 raise + 사용자가 3회 거절. reviewer persona 점검 필요 (NG5 — 자동 편집 X)."
