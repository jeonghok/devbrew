# Fixture: reconsensus-loop-case

> AC9 검증. P1 (global) vs P2 (per-issue) priority + 동시 충족 처리.

## Scenario A — per-issue [5] escalate (P2 path)

state.local.md issue_history excerpt:
```yaml
- id: LOOP1
  raised_count: 2
  dismissed_by_user: 0
  accepted_by_user: 1
  reconsensus_count: 2          # AC9 cap에 도달
  resolved: false
- id: OTHER1
  raised_count: 1
  reconsensus_count: 0
  resolved: false
```

Expected routing:
- LOOP1만 [5] forced escalate (해당 issue만 인간 검토). `issue_history[LOOP1].escalated = true`.
- OTHER1은 [4] Revise로 계속 (per-issue scope이므로 spec 전체 stop X).

## Scenario B — global [5] escalate (P1 path)

reviewer output:
- 5개 locked-affecting issue 동시 raise (각각 다른 LD 영향):
  - I1: affects_locked_decisions: [LD1]
  - I2: affects_locked_decisions: [LD2]
  - I3: affects_locked_decisions: [LD3]
  - I4: affects_locked_decisions: [LD4]
  - I5: affects_locked_decisions: [LD5]

Expected routing:
- C3 한 round 최대 3 LD 묶음 초과 (5개) → P1 trigger.
- spec 전체 [5] forced escalate (5개 issue 모두 묶어서 인간 검토).
- issue_history 변경 X (P1은 spec-level이므로 per-issue 카운터 무영향).

## Scenario C — P1 + P2 동시 충족

reviewer output 같은 round:
- 4개 locked-affecting issue (P1 trigger condition: ≥4).
- 그 중 하나 (I3)가 reconsensus_count: 2 (P2 trigger condition).

Expected routing: **P1 우선** — spec 전체 [5]로 가고, I3의 per-issue P2는 미실행.
이유: C3 P1 우선 명시 규칙 ("global이 per-issue 우선").
