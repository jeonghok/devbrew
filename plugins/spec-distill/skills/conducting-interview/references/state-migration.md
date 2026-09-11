## In-flight state migration

판정은 **키 단위**다 — 「구조가 통째로 없는가」가 아니라 「§2.4 스키마의 **부재 키가 있는가**」.
구조 부재로 좁히면 정작 **가장 흔한 업그레이드 경로가 빠진다**: 직전 릴리스 세션은
`coverage`·`orchestration` 을 이미 갖고 있고 이 릴리스가 더한 세 키
(`coverage.floor.*.reopened` · `.reopen_log` · `orchestration.coverage_mapper_dispatches`)만
없어서, 어느 조건에도 안 걸린 채 그 키를 읽는 코드로 들어간다.

state.local.md 로드 시 아래 중 **하나라도** 부재면 *non-mutating read* 로 승격한다
(부재 키만 기본값으로 채우고, 이미 있는 값은 손대지 않는다):

- `coverage.floor` 의 5개 차원(root_problem/landscape/skepticism/blind_spot/open_questions) —
  차원 자체가 없으면 `{status: open, evidence: "", reopened: 0, reopen_log: []}` 로 seed.
  **차원은 있는데 `reopened`/`reopen_log` 만 없으면 그 둘만 `0`/`[]` 로 추가**하고
  `status`·`evidence` 는 그대로 둔다 — 진행 중인 인터뷰의 닫힘 판정을 되돌리지 않는다.
- `coverage.derived` — 없으면 `[]`. 있으면 각 항목에 `reopened`/`reopen_log` 를 같은 규칙으로 보충.
- `orchestration`: `{focused_dimension: null, blind_spot_dispatched: false, coverage_mapper_dispatches: 0}`
  — 절이 없으면 이 값 그대로 seed. **있으면 부재 키만** 그 기본값으로 추가한다(직전 릴리스
  세션에서 실제로 빠져 있는 것은 `coverage_mapper_dispatches` 하나다).

구세션(`interview_round` 존재 / `coverage` 통째 부재)은 위 규칙의 한 경우일 뿐이다 — 그때는
모든 키가 부재라 전부 seed 된다.

기존 필드(`non_user_streak`·`web_*`·`trivia_escape_armed` 등)는 유지.
**단 `rereview_count`·`issue_history` 두 키는 승계하지 않고 지운다** — 옛 design doc 리뷰
파이프라인이 쓰던 것이고, 그 자리가 공유 문서 리뷰 엔진으로 넘어가면서 산출자도 소비자도
없어졌다(재리뷰 카운터의 정본은 이제 엔진의 `docreview-state.md` 다). 남겨두면 아무도
갱신하지 않는 `0`·`[]` 가 스키마에 계속 실려 다음 사람이 실재하는 상태로 읽는다. **구세션에 한해**(위 정의 —
`coverage` 통째 부재) 라운드별 잠금 레코드 리스트(v0.22.0까지의 잠금 필드)는 승계하지 않고
`user_statements: []`로 fresh seed합니다 — 잠금 레코드를 발화 레코드로 승격하면 판정이 없던 척하는
잠금이 그대로 넘어옵니다. **직전 릴리스 세션의 `user_statements` 는 절대 비우지 않습니다** —
그것은 이미 발화 레코드이고, 키 몇 개를 보충하려다 §6 원문을 통째로
버리는 것은 마이그레이션이 아니라 손실입니다.

**영속화 시점**: 승격된 스키마는 재개된 세션의 첫 액션으로, 첫 probe보다 먼저 Bash 전체-frontmatter
write로 즉시 디스크에 반영합니다(PN1) — coverage-mapper 상한 카운터(`coverage_mapper_dispatches`)와
재개방 원장(`reopen_log`)이 그 디스크 값을 직접 읽기 때문입니다. 신규 필드(coverage/orchestration)만
추가하는 forward promotion이지 backward-rewrite가 아닙니다(`interview_round`는 자연 소멸, 다른
기존 필드는 불변) — "다음 명시적 write"를 기다리는 연기가 아니라 resume 직후 1회입니다.

사용자에게 advisory 한 줄 출력:
```
[spec-distill v0.57.0] state schema migration: reopen ledger + coverage_mapper_dispatches added (stall trigger retired).
```

자동 promote 실패 시(파일 corruption 등) → "구세션 in-flight state 호환 실패 — 세션 재시작 권장"
알림 + state.local.md 보존 (P14).
