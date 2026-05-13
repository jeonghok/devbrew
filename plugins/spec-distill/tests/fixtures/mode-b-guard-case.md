# Fixture: mode-b-guard-case

> AC5 검증. drafting-spec Mode B의 allowed_issue_ids contract + abort flow.

## Scenario A — 정상 케이스

Input:
- spec.md = locked-decisions-spec.md
- allowed_issue_ids = [I1]
- reviewer issues = [{id: I1, target: #goals}, {id: I2, target: #acceptance-criteria}]

Expected behavior:
- Mode B는 I1 (#goals 섹션) 적용.
- I2 (#acceptance-criteria 섹션)는 *건드리지 않음*.
- state.local.md `issue_history[I2].resolved` 변경 없음.
- spec.md diff: #goals 섹션만 변경.

## Scenario B — abort 케이스 (allowed_issue_ids 위반)

Input:
- spec.md = locked-decisions-spec.md
- allowed_issue_ids = [I1]
- Mode B가 I2 적용 시도 (구현 버그 또는 잘못된 dispatch).

Expected behavior (4단계):
1. spec.md edit 즉시 중단.
2. 이미 적용된 partial edit 있으면 `git restore plugins/spec-distill/tests/fixtures/locked-decisions-spec.md` (working tree 복원).
3. state.local.md에 다음 marker 추가:
   ```yaml
   mode_b_violation:
     attempted_issue_id: I2
     allowed: [I1]
     timestamp: <ISO8601>
   ```
4. reviewing-spec [3.5] sub-step으로 제어 반환. 사용자에게 advisory:
   > Mode B contract 위반 — `I2`가 `allowed_issue_ids`에 없음. 재합의 round 누락 가능성.
   > 옵션: (i) 해당 issue를 re-consensus에 추가 / (ii) Mode B 재dispatch (수동 issue 선택) / (iii) [5] Human Gate로 escalate.

Expected schema grep:
   ```
   grep -q "mode_b_violation" plugins/spec-distill/tests/fixtures/mode-b-guard-case.md
   ```
