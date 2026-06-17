# 인터뷰 월클락 완전 제거 — spec-distill v0.17.0

> 시계가 인터뷰에서 켜지고 리뷰 루프에서 트립한다 — 즉 재는 건 agent 자율성이 아니라 사람의 숙고 시간이다. count-cap이 진짜 가드다.

## Context / Why

`DEVBREW_SPEC_DISTILL_TIMEOUT_MIN`(default 30min) 월클락은 **cross-skill** 메커니즘이다:

- **conducting-interview** 가 state schema에 `wall_clock_started_at: <ISO8601>`를 *심는다* (`skills/conducting-interview/SKILL.md:42`).
- **reviewing-spec** Step 2(AC14)가 *검사한다* — `now - wall_clock_started_at > TIMEOUT_MIN`이면 advisory metric + Phase 5 강제 escalate (`skills/reviewing-spec/SKILL.md:19`).

시계가 **인터뷰 시작 시점에 켜지고 re-review 루프에서 트립**하므로, 실제로 재는 것은 *agent의 루프 자율성*이 아니라 **사람이 인터뷰+리뷰에 들인 숙고 시간**이다. 신중하게 40분 고민한 사용자는 *첫 spec 리뷰*에서 곧장 forced-escalate를 맞는다 — 신중함을 처벌하는 footgun.

AP16(unbounded autonomy)의 진짜 가드는 같은 re-review 루프에 **이미 결정론적으로 걸린** 두 바운드다 (`reviewing-spec/SKILL.md:45–52`):

1. **Hard cap** — `rereview_count >= 5` → [5] Human Gate forced escalate.
2. **Round-level stagnation early-exit** — `Stagnation_signal: true` → 즉시 escalate.

월클락은 그 위에 얹힌 **중복(redundant) + 오측정(mismeasuring)** 세 번째 바운드일 뿐이다. 제거는 harness-lightness 원칙(결정론은 보안/정확성 등 load-bearing 게이트에만)과 qg v2.0.0의 월클락 budget 제거 선례에 정합한다.

## Goals

- 월클락 메커니즘 **전체 제거**: state 필드 + AC14 체크 + env var + 모든 문서 동기화.
- AP16 커버리지를 count-cap(5) + stagnation early-exit + rhythm-guard(3) + web-budget로 **명시적으로 재선언**.
- 재도입 방지 **regression-lock 테스트** 추가 (v0.16.0 SessionStart-anchor 제거 선례 패턴).

## Non-goals

- re-review cap / stagnation / rhythm-guard / web-budget 로직 변경 — **불변**.
- 인터뷰 라운드 루프에 다른 시간 바운드 신설 — 안 함.
- stale state 마이그레이션 코드 — **불필요**. 필드 *reader* 제거는 forward-compatible이라, 구 세션 state의 잔여 `wall_clock_started_at` 필드는 단순히 무시된다 (YAML frontmatter의 미사용 키).

## Constraints

- devbrew: 플러그인을 건드리는 PR마다 plugin.json SemVer bump. `0.16.0 → 0.17.0` (env var 제거 = pre-1.0.0 breaking → minor 반영).
- Korean-primary 문서 컨벤션. CHANGELOG에 `## [0.17.0] — 2026-06-17` Removed 엔트리 (one-minor deprecation window은 v1.0.0+ 요건 — 해당 없음, hard remove 가능).
- regression-lock grep 스코프 주의:
  - **CHANGELOG.md는 history 보존이라 스캔 제외** (과거 엔트리가 "wall-clock"을 정당하게 언급).
  - 라이브 surface(2 SKILL + README)만 스캔.
  - 재사용된 `AC14` *번호*는 건드리지 않는다 — `test_cancel_review.py` / `test_review_dispatch.sh`의 AC14는 월클락과 **무관한 동명 번호**.

## Acceptance Criteria

1. conducting-interview state schema에서 `wall_clock_started_at` 라인 제거.
2. reviewing-spec Step 2(월클락 AC14 체크) 제거 + 후속 step(3–6 → 2–5) 재번호; Step 1이 `wall_clock_started_at`를 더 이상 로드하지 않음.
3. reviewing-spec frontmatter `description`에서 "wall-clock budget" 문구 제거.
4. `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN` env var를 양쪽 SKILL kill-switch 섹션 + README kill-switch 문서에서 제거.
5. README AP16 라인에서 "wall-clock 30min" 제거; 잔여 바운드(re-review max 5 + stagnation + rhythm guard 3 + web budget)가 AP16을 충족함이 라인에 드러남.
6. forced-escalate 경로가 re-review cap + stagnation으로 **여전히 작동** (회귀 0) — reviewing-spec:45–58 unchanged.
7. regression-lock 테스트(`tests/test_no_wall_clock.sh`): `wall_clock_started_at` / `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN` / `wall-clock`이 2 SKILL 파일 + README에 부재함을 단언, green.
8. `.claude-plugin/plugin.json` version = `0.17.0`; CHANGELOG `[0.17.0]` Removed 엔트리 존재.
9. 구 세션 state의 잔여 `wall_clock_started_at` 필드가 무해하게 무시됨 (no migration code; design 상 명시).

## Files to Modify

| 파일 | 변경 |
|---|---|
| `plugins/spec-distill/skills/conducting-interview/SKILL.md` | 42행 schema 필드 삭제, 335행 env-var kill-switch 라인 삭제 |
| `plugins/spec-distill/skills/reviewing-spec/SKILL.md` | 7행 desc, 18행 Step 1 load 목록, 19행 Step 2 삭제+후속 재번호, 138행 kill-switch 라인 |
| `plugins/spec-distill/README.md` | 90행 AP16 라인, 120행 kill-switch 문서 라인 |
| `plugins/spec-distill/.claude-plugin/plugin.json` | version `0.17.0` |
| `plugins/spec-distill/CHANGELOG.md` | `[0.17.0] — 2026-06-17` Removed 엔트리 |
| `plugins/spec-distill/tests/test_no_wall_clock.sh` (신규) | regression-lock (라이브 surface 3파일 스캔, CHANGELOG 제외) |

## Verification Plan

- 신규 regression-lock 테스트 실행 → green.
- 기존 spec-distill 테스트 스위트 실행 → 회귀 0 (AC14 동명 테스트가 unchanged로 통과하는지 확인).
- `grep`으로 라이브 surface 제로 참조 확인 (`wall_clock_started_at`, `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN`, `wall-clock`).
- reviewing-spec step 재번호 가독성 수동 확인.
- 본 design doc은 brainstorming → spec-reviewer Law-2 리뷰(PostToolUse arm + Stop dispatch) 통과 후 writing-plans로 진행.

## Rejected Alternatives

- **B — timestamp 보존, escalate 행동만 제거**: state.local.md가 git-ignored + 성공 시 auto-delete라 reader가 없어 dead data → Law 3 theater("어떤 미래 agent도 읽지 않는 파일에 기록하는 것은 theater"). 사용자가 완전 제거를 명시 선택.
- **C — 시계를 인터뷰 라운드 루프의 실제 바운드로 이전**: 인터뷰는 이미 rhythm-guard(non_user_streak≥3) + web-budget(sweep≤4/session≤8)로 bound됨. 시간 바운드는 human think-time를 오측정 + 비결정성 추가, load-bearing 이득 없음. harness-lightness 위반.
- **D — rename / no-op**: 중복·오측정 바운드를 그대로 둠 — 문제 미해결.

## Metadata

- Plugin: spec-distill `0.16.0 → 0.17.0` (minor; pre-1.0.0 breaking = env-var 제거)
- Branch: `feature/spec-distill-remove-interview-wall-clock`
- Date: 2026-06-17
- Principles Instantiated: AP16(재선언 — count-cap이 load-bearing 가드), harness-lightness(결정론은 load-bearing 게이트에만), Law 3(theater 회피), qg v2.0.0 월클락 제거 선례
