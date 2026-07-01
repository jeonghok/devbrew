---
name: spec-distill-review-subagent-misfire
status: draft
date: 2026-07-01
scope: spec-distill 리뷰 파이프라인 (reviewing-spec + review-dispatch Stop 훅 + pending-review-reminder + approve_handoff)
---

# spec-distill 리뷰 파이프라인 — subagent 경계 Stop 훅 오발 제거

> subagent가 리뷰 흐름 도중 만든 Stop 경계에서 `review-dispatch` 훅이 다시 발동해
> 리뷰를 중복 강제(A)하거나 진행 중 흐름을 절단(B)하는 오발을, 리뷰 강제 계약을
> 그대로 유지한 채 `review_in_progress` 상태 락으로 봉쇄한다.

## Context / Why

Claude Code가 subagent 실행 시 라이프사이클을 더 많이 타도록 바뀌면서(예: subagent도
skill 로딩을 거침 — `using-superpowers`의 `<SUBAGENT-STOP>` 가드가 그 방증),
`reviewing-spec`가 `spec-reviewer` subagent를 dispatch하는 과정에서 메인 에이전트의
`Stop` 이벤트가 리뷰 흐름 *도중*에 발생한다. 현재 `review-dispatch.py`(Stop 훅)는
"`pending_review` 블록이 있으면 무조건 리뷰를 강제"라는 무상태 판단만 하므로,
진행 중인 리뷰 한복판에서 `decision:block`을 다시 emit한다.

관찰된 두 증상:

- **(A) 중복/반복 발동** — `spec-reviewer`가 끝난 뒤에도 `reviewing-spec`가 다시 강제 호출됨.
- **(B) 흐름 절단** — subagent 결과를 처리하기 전에 `decision:block`이 끼어들어 리뷰 흐름이 끊김.

### 근본 원인

재발동의 **재-arm 소스**는 `spec-write-validator.py`의 `write_state()`다
(`hooks/spec-write-validator.py:145-187`). design 문서를 쓸/고칠 때마다 `pending_review`가
새로 기록된다. 최초 dispatch 때 `review-dispatch.py`가 pending을 strip하지만
(`hooks/review-dispatch.py:77-79`), **revise 루프에서 design 문서를 다시 편집하면 pending이
재-arm**되고, subagent 경계에서 발생한 Stop이 그 재-arm된 pending을 집는다.

즉 고칠 지점은 "pending을 지우는 방식"이 아니라, **"리뷰가 진행 중인 동안 재-arm된
pending을 무시"** 하도록 훅이 참조하는 *상태의 표현력*을 늘리는 것이다. 훅은 지금
"리뷰가 지금 돌고 있는가?"를 알 방법이 없다.

### 제약: 리뷰 강제는 load-bearing

`review-dispatch` 훅의 `decision:block` 리뷰 강제는 devbrew 철학상 Law 1 + Law 2의
load-bearing 인스턴스이며 "불변"으로 취급된다(memory: `review 강제 = hook block(불변)`).
따라서 "Stop 훅 삭제"는 리뷰 우회 구멍을 여는 철학 위반이다. 이 설계의 목표는
**강제는 100% 보존하되 오발만 제거**하는 것이다.

## Goals

1. subagent 경계에서 발생하는 Stop으로 인한 (A) 중복 발동과 (B) 흐름 절단을 제거한다.
2. 최초 "design 작성 → 리뷰 미시작" 경계에서의 리뷰 강제는 그대로 유지한다.
3. 강제 메커니즘이 어떤 실패에서도 "리뷰가 일어나는 쪽"으로 fail한다(Law 1).
4. 이번에 만지는 파일(`approve_handoff.sh`)의 작성자-확인된 dead 코드를 함께 제거한다.

## Non-goals

- interview 스테이지(`conducting-interview`, breadth-keeper, steelman-builder) — 스코프 밖.
- `spec-write-validator.py`의 arm 로직 변경 — 무변경(pending은 항상 arm되는 안전 substrate).
- `last_dispatched_at` 30초 self-ref 가드 제거 — 별개 실패 모드라 유지(Rejected R4).
- Claude Code의 Stop/SubagentStop 발동 시점 자체를 바꾸는 어떤 것 — 하니스 밖.
- 리뷰 verdict 라우팅 표·재리뷰 cap·stagnation 로직 변경 — 무관.

## Design — `review_in_progress` 상태 락

### 상태 스키마

state.local.md에 0-indent 스칼라 필드 한 줄을 추가한다(`last_dispatched_at`과 동형):

```
review_in_progress: 2026-07-01T12:34:56Z
```

- **set**: `reviewing-spec`가 리뷰 세션을 시작하는 시점(Phase 3 Step 1).
- **clear**: 리뷰 세션이 종결되는 시점 — approve / forced-escalate / 사용자 중단.
- revise 루프(needs_revise < 5) 중에는 **유지**한다 — 재리뷰는 skill이 직접 재dispatch하므로
  훅이 강제할 필요가 없고, 훅은 *최초 강제*만 담당하기 때문.

### 훅의 판정 (fail-safe = 강제)

`review-dispatch.py`(Stop)와 `pending-review-reminder.py`(UserPromptSubmit)는 pending을
처리하기 전에 락을 조회한다:

- 락이 **신선**(현재 − ts < TTL)하면 → `return 0`. dispatch/block 없음, **pending strip도 없음**
  (pending은 보존되어 이후 정당한 강제의 substrate로 남는다).
- 락이 **stale**(≥ TTL)하거나, 필드가 없거나, 파싱/import에서 예외가 나면 → 락을 무시하고
  **정상 dispatch 경로로 진행**. load-bearing 강제가 조용히 꺼지는 일이 없다(Law 1 —
  over-review > under-review, 기존 suppress fail-open과 동일 방향).

TTL 기본값 **1800초(30분)** — revise가 여러 라운드로 길어져도 덮는다. env
`DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC`로 override.

### 왜 pending을 항상 arm 유지하는가 (안전 substrate)

락은 *타이밍만* 게이트하고, 강제의 substrate인 `pending_review`는 항상 존재하게 둔다.
그래서 락이 stale로 판정되는 순간 훅은 곧바로 pending을 집어 강제를 재개할 수 있다.
반대로 validator 쪽에서 arm 자체를 억제하면(Rejected R2), 락이 오판될 때 강제할 대상
자체가 사라져 under-review로 fail한다 — Law 1 방향과 반대다.

### 단일 소스 헬퍼: `scripts/review_lock.py`

정규화·strip을 `suppress_state.py`가 단일 소스로 갖듯, 락의 set/clear/freshness도
한 파일에 모은다.

- Python API: `set_lock(state_file, now)`, `clear_lock(state_file)`,
  `is_review_active(body, now, ttl) -> bool`.
- CLI(호출자: skill·bash): `python3 review_lock.py {set|clear} <session_id>`.
- 훅은 `is_review_active`를 import해 인라인 파싱 중복을 없앤다(`state_path`,
  `suppress_state` import 패턴과 동일).
- 원자적 write(flush + fsync)로 기록.
- kill switch(`DEVBREW_DISABLE_SPEC_DISTILL=1`) 방어 — CLI에서 no-op.

## Files to Modify

| 파일 | 변경 |
|---|---|
| `scripts/review_lock.py` **(신규)** | `set_lock`/`clear_lock`/`is_review_active` + `{set,clear}` CLI. 원자적 write, kill switch. |
| `hooks/review-dispatch.py` | suppress 체크 뒤·TTL 가드/ dispatch 앞에 `is_review_active` 게이트. 신선→`return 0`(strip 없음), stale/예외→강제. |
| `hooks/pending-review-reminder.py` | 동일 락 존중(mid-review 재-nag 방지). |
| `skills/reviewing-spec/SKILL.md` | Step 1에서 `review_lock.py set`; 종결 경로(approve/forced-escalate/stop)에서 `clear`. |
| `scripts/approve_handoff.sh` | (a) suppress 기록과 함께 `review_lock.py clear` 호출, (b) dead `git_common_dir`/`main_repo` 블록(line 63-70) 제거. |
| `hooks/spec-write-validator.py` | **무변경** (pending 항상 arm = 안전 substrate). |
| `.claude-plugin/plugin.json` | 0.17.0 → 0.18.0 (minor: 새 state 필드 + 동작). |
| `CHANGELOG.md` | `[0.18.0]` 항목. |
| `README.md` | "Hooks Installed"/state schema/kill switch·env 동기화. |
| `tests/*` | 아래 Verification Plan의 신규·회귀 테스트. |

## Data Flow

### 정상 경로

1. design 작성 → validator가 `pending_review` arm.
2. 메인 Stop → 훅: 락 없음 → pending strip + `last_dispatched_at` set + `decision:block` → `reviewing-spec` 강제.
3. `reviewing-spec` Step 1 → **`review_lock.py set`** → `spec-reviewer` dispatch.
4. subagent 경계 Stop → 훅: 락 신선 → `return 0` (no-op). ← (B) 봉쇄.
5. verdict 처리 → approve → Phase 5 게이트 → `approve_handoff.sh` → suppress + **`review_lock.py clear`**.

### revise 루프

- verdict = needs_revise(< 5) → 메인 에이전트가 design 직접 편집 → validator가 pending 재-arm.
- 이 사이 어떤 Stop이든: 락 신선 → no-op. ← (A) 봉쇄.
- skill이 `reviewing-spec` 재dispatch(락 유지). 종결 시 clear.

### fail-safe (stale 락)

- 크래시 등으로 락이 30분 넘게 방치 → 다음 Stop이 락을 무시하고 pending으로 강제 → 강제 재개.
- session 폴더는 `spec-distill-gc.py`의 24h TTL GC가 정리하므로 락 필드도 함께 사라진다(별도 정리 불필요).

## Acceptance Criteria

- **AC1** `reviewing-spec` Step 1이 `review_lock.py set`을 호출해 `review_in_progress: <ISO>`를 upsert한다.
- **AC2** `reviewing-spec`의 forced-escalate / 사용자-중단 종결 경로가 `review_lock.py clear`를 직접 호출해 필드를 제거한다(approve 경로의 clear는 AC6이 담당 — 중복 clear는 멱등이라 무해하나 권위 주체는 approve_handoff).
- **AC3** `review-dispatch.py`는 락이 신선하면 pending이 있어도 dispatch/block하지 않고 `return 0`하며 pending을 strip하지 않는다.
- **AC4** `review-dispatch.py`는 락이 stale이거나 필드 부재·파싱 예외면 락을 무시하고 정상 dispatch한다(fail-safe = 강제, Law 1).
- **AC5** `pending-review-reminder.py`도 신선한 락을 존중해 mid-review 재-nag(재-emit)를 하지 않는다.
- **AC6** `approve_handoff.sh`가 suppress 기록과 함께 `review_lock.py clear`를 호출한다.
- **AC7** `spec-write-validator.py`는 변경되지 않는다 — pending은 여전히 항상 arm된다.
- **AC8** TTL은 `DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC`로 override 가능, 미설정 시 1800.
- **AC9** `last_dispatched_at` 30초 self-ref 가드는 유지된다(제거·병합 금지 — pre-lock 창·strip 실패 커버).
- **AC10** 기존 kill switch(`DEVBREW_DISABLE_SPEC_DISTILL`, `DEVBREW_SKIP_HOOKS:spec-distill:{Stop,review-dispatch,UserPromptSubmit,reminder}`)가 락 로직 위에서도 그대로 동작한다.
- **AC11** `approve_handoff.sh`의 dead `git_common_dir`/`main_repo` 블록(line 63-70)이 제거된다.
- **AC12** `plugin.json`=0.18.0, `CHANGELOG.md` `[0.18.0]`, `README.md` 동기화(README sync 테스트 통과).
- **AC13** 회귀 락은 teeth를 가진다 — body-unique 문구를 섹션 윈도우에서 grep + mutation으로 삭제 시 실패함을 증명(헤더-satisfiable 함정 회피).

## Verification Plan

신규 `tests/test_review_lock.py` (unittest):

- `set_lock`이 필드를 upsert(신규/기존 값 갱신), `clear_lock`이 제거, 둘 다 멱등.
- `is_review_active`: 신선 ts → True, stale ts(> ttl) → False, 필드 부재 → False, 파싱 불가 문자열 → False.
- CLI `set`/`clear`가 state 파일을 원자적으로 갱신, kill switch에서 no-op.

훅 테스트(기존 `test_review_dispatch.sh` / `test_reminder_hook.sh` 확장):

- 락 신선 + pending 존재 → Stop 훅 no-op(빈 stdout, exit 0) + pending 보존(strip 안 됨).
- 락 stale + pending 존재 → Stop 훅이 `decision:block` emit + pending strip(기존 강제 동작).
- 락 부재 → 기존 동작 불변(회귀 없음).
- reminder도 락 신선 시 재-emit 안 함 / stale 시 재-emit.

스크립트/스킬 테스트:

- `test_approve_handoff.sh` — approve 시 `review_lock.py clear`가 호출됨 + dead `main_repo` 블록 부재 확인(grep).
- `reviewing-spec` SKILL.md에 set·clear 지시 문구 존재 — **body-unique** 문구를 해당 섹션 윈도우에서 grep(AC13 teeth: 헤더에도 있는 문구로 satisfiable하지 않게, mutation으로 삭제 시 red 증명).

동기화·통합:

- `test_readme_sync.sh` 통과(README에 새 env/state 필드 반영).
- 전체 `/qg` 파이프라인(security-reviewer + codex 포함) clean.

## Rejected Alternatives

- **R1 — 강제를 UserPromptSubmit로 이동, Stop 경량화.** UserPromptSubmit는 subagent-발 Stop에 면역이나, 같은-턴 즉시 강제(Law 1 즉시성)를 잃는다. 강제 계약 자체를 바꾸는 침습.
- **R2 — validator에서 재-arm 억제.** Stop 훅 무변경으로 더 가볍지만, 락 오판 시 강제 substrate(pending)가 사라져 under-review로 fail — Law 1 방향과 반대. 안전 substrate 원칙 위반.
- **R3 — `stop_hook_active` 방어층 추가.** `review_in_progress` 락이 (A)+(B)를 완전 커버(최초 block 후 pending은 strip, 이후 재-arm은 락이 무시)하므로 중복. 결정론 가드는 load-bearing에만(memory: harness lightness) — 제외.
- **R4 — `last_dispatched_at`을 락으로 병합.** 락은 리뷰-도중을, `last_dispatched_at`은 strip-실패·pre-lock 창을 커버하는 별개 실패 모드. 병합하면 pre-lock 창에 구멍 → 회귀.
- **R5 — Stop 훅 삭제.** 리뷰 강제는 Law 1/Law 2 load-bearing "불변" — 삭제는 리뷰 우회 구멍. 사용자 확인 방향(삭제 없이 개선).

## Metadata

- **Version**: `plugin.json` 0.17.0 → **0.18.0** (minor — 새 state 필드 + 훅 동작 추가, breaking 아님).
- **CHANGELOG** `[0.18.0]`: Added=`review_lock.py` + `review_in_progress` 필드 + `REVIEW_LOCK_TTL_SEC` env; Changed=Stop 훅·reminder가 락 존중, `approve_handoff.sh`가 락 clear; Fixed=subagent 경계 Stop 재발동(중복/절단); Removed=`approve_handoff.sh` dead `main_repo` 블록.
- **철학 인스턴스**: Law 1(강제 유지 + fail-safe=enforce), Law 2(훅은 state만·product write 불가, 락 set/clear는 skill이 스크립트로), Law 3(회귀 락 teeth로 미래 회귀 포획 + dead 코드 클린업).
- **선행 조사**: `docs/superpowers/specs/2026-05-16-spec-distill-hook-review-design.md`(원 리뷰 훅 설계), memory `project_spec_distill_review_hardening`.
