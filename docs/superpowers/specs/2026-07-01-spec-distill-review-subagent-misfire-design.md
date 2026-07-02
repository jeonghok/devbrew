---
name: spec-distill-review-subagent-misfire
status: draft
date: 2026-07-01
scope: spec-distill 리뷰 파이프라인 (reviewing-spec + review-dispatch Stop 훅 + pending-review-reminder + approve_handoff + cancel_review)
review_round: 4
---

# spec-distill 리뷰 파이프라인 — subagent 경계 Stop 훅 오발 제거

> subagent(async) dispatch 중 메인 에이전트의 `Stop`이 리뷰 흐름 도중 발생하고,
> revise로 재-arm된 `pending_review`를 훅이 집어 리뷰를 중복 강제(A)하거나 흐름을
> 절단(B)하는 오발을, **document-keyed(multi-key) `review_in_progress` 락**으로 봉쇄한다.
> 리뷰 강제 계약(load-bearing Law 1/2)은 그대로 유지한다.

## Handoff Context

### TL;DR
subagent async dispatch → 메인 `Stop` → 재-arm된 pending으로 리뷰 재발동(A/B)을,
document-keyed 락으로 봉쇄. 락은 **문서별 엔트리 리스트**(map)이고, *그 문서*가 *리뷰
진행 중*일 때만 그 문서의 dispatch를 게이트한다. clear는 approve/cancel, ④ 멈춤은
pause(clear+pending strip), set은 매 reviewing-spec 진입마다 refresh, stale(TTL 초과)
시 강제 재개(fail-safe = enforce).

### Implicit context (구현자가 알아야 할 것)
- **문서 정체성(canonical_key) 모델은 `suppress_state.py`가 단일 소스**(PREFIX 이후
  substring — worktree·절대·상대 경로가 같은 키로 수렴). 락도 이 함수를 import해 재사용하고
  별도 정규화를 만들지 않는다(suppress_state 단일-소스 원칙).
- **pending은 항상 armed 유지**(validator 무변경) — 강제의 substrate. 락은 그 위에서
  "같은 문서 + 신선"일 때만 dispatch를 게이트하는 *타이밍* 레이어.
- 락은 세션-전역 스칼라도, 단일 `{path,since}` 쌍도 아니라 **문서별 엔트리 리스트**다
  (`suppressed_paths`와 동형). 이래야 인터리브 2-문서 리뷰에서 한 문서의 set이 다른
  문서의 락을 clobber하지 않는다(round-3 [ad4e6c3f]).

### Deferred to plan
- `review_lock.py`의 원자적 write(flush+fsync)·엔트리 직렬화 포맷·CLI 인자 파싱·훅 삽입
  위치·stale 엔트리 pruning 정책은 writing-plans 단계에서 TDD로 확정.
- ④ pause에서 lock-엔트리 제거와 pending strip은 같은 스킬 턴 내 **순차 동기 실행**이며
  그 사이 Stop이 끼어들지 않음을 전제한다(단일-스레드 실행 모델) — 이 가정을 plan에 명기.
- 각 회귀 테스트의 fixture timestamp 설계(신선/스테일 경계, multi-round 누적).

## Context / Why

Claude Code가 subagent 실행 시 라이프사이클을 더 많이 타도록 바뀌면서,
`reviewing-spec`가 `spec-reviewer` subagent를 **async로 dispatch**하고 결과를 await하려
턴을 멈추면 — 메인 에이전트의 `Stop` 이벤트가 리뷰 흐름 *도중*에 발생한다. 현재
`review-dispatch.py`(Stop 훅)는 "`pending_review` 블록이 있으면 무조건 리뷰 강제"라는
무상태 판단만 하므로, 진행 중인 리뷰 한복판에서 `decision:block`을 다시 emit한다.

관찰된 두 증상:

- **(A) 중복/반복 발동** — `spec-reviewer` in-flight 중에도 `reviewing-spec`가 다시 강제됨.
- **(B) 흐름 절단** — subagent 결과를 처리하기 전에 `decision:block`이 끼어들어 흐름이 끊김.

### 라이브 재현 (2026-07-01 — 이 문서 자신의 리뷰 중 관찰)

이 design 문서가 자기 자신의 spec-distill 리뷰를 받는 도중 버그가 그대로 발동했다(3회).
`reviewing-spec`가 `spec-reviewer`를 async dispatch한 뒤 await하려 턴을 멈추자,
`review-dispatch.py`(Stop 훅)가 발동해 reviewing-spec를 재강제했다. state 증거:
`last_dispatched_at`이 갱신되고 `pending_review`가 strip됐다. 이 관찰이 근본 원인의
두 전제를 dogfood로 확정한다 — (a) 실제 발동 이벤트는 `SubagentStop`이 아니라 메인
`Stop`이다(`hooks.json`은 `Stop`에만 등록), (b) 훅이 읽은 state의 session_id는 부모와
동일(c34c4e8e…)했다(부모 pending을 찾아 strip). 즉 트리거는 "메인 에이전트가 async
subagent를 기다리려 멈추는 것"이며, 이는 정상 운영 경로다.

### 근본 원인

재발동의 **재-arm 소스**는 `spec-write-validator.py`의 `write_state()`다
(`hooks/spec-write-validator.py:145-187`). design 문서를 쓸/고칠 때마다 `pending_review`가
새로 기록된다. 최초 dispatch 때 `review-dispatch.py`가 pending을 strip하지만
(`hooks/review-dispatch.py:77-79`), **revise 루프에서 design 문서를 다시 편집하면 pending이
재-arm**되고, subagent 경계에서 발생한 Stop이 그 재-arm된 pending을 집는다.

고칠 지점은 "pending을 지우는 방식"이 아니라, **"그 문서의 리뷰가 진행 중인 동안
재-arm된 pending을 무시"** 하도록 훅이 참조하는 *상태의 표현력*을 늘리는 것이다.

### 제약: 리뷰 강제는 load-bearing

`review-dispatch` 훅의 `decision:block` 리뷰 강제는 devbrew 철학상 Law 1 + Law 2의
load-bearing 인스턴스이며 "불변"으로 취급된다(memory: `review 강제 = hook block(불변)`).
따라서 "Stop 훅 삭제"는 리뷰 우회 구멍을 여는 철학 위반이다. 목표는 **강제는 100%
보존하되 오발만 제거**하는 것이다.

## Goals

1. subagent 경계에서 발생하는 Stop으로 인한 (A) 중복 발동과 (B) 흐름 절단을 제거한다 —
   **인터리브 2-문서 리뷰에서도 각 문서의 보호가 유지**된다(한 문서의 락이 다른 문서에
   의해 clobber되지 않음).
2. 최초 "design 작성 → 리뷰 미시작" 경계에서의 리뷰 강제는 그대로 유지한다.
3. 강제 메커니즘이 어떤 실패에서도 "리뷰가 일어나는 쪽"으로 fail한다(Law 1). 특히
   **락은 자기가 걸린 그 문서에만 작용**하고, 무관한 다른 문서의 최초 강제는 절대
   억제하지 않는다.
4. 이번에 만지는 파일(`approve_handoff.sh`)의 작성자-확인된 dead 코드를 함께 제거한다.

## Non-goals

- interview 스테이지(`conducting-interview`, breadth-keeper, steelman-builder) — 스코프 밖.
- `spec-write-validator.py`의 arm 로직 변경 — 무변경(pending은 항상 arm되는 안전 substrate).
- `last_dispatched_at` 30초 self-ref 가드 제거 — 별개 실패 모드라 유지(Rejected R4).
- Claude Code의 Stop/SubagentStop 발동 시점 자체를 바꾸는 어떤 것 — 하니스 밖.
- 리뷰 verdict 라우팅 표·재리뷰 cap·stagnation 로직 변경 — 무관.

## Design — document-keyed(multi-key) `review_in_progress` 락

### 상태 스키마

state.local.md에 **문서별 엔트리 리스트**를 추가한다(`suppressed_paths`와 동형 — 단일
스칼라도 단일 쌍도 아님; round-3 [ad4e6c3f] 반영):

```
review_in_progress:
  - path: docs/superpowers/specs/2026-07-01-A-design.md   # canonical_key (PREFIX 이후)
    since: 2026-07-01T13:23:53Z
  - path: docs/superpowers/specs/2026-07-01-B-design.md
    since: 2026-07-01T13:40:00Z
```

- 각 엔트리의 `path`: `suppress_state.canonical_key(spec_path)` — pending_review.path와 같은
  정체성 모델로 비교하기 위해 정규화 키로 저장.
- `since`: 그 문서 락이 (재)설정된 ISO 시각.
- 직렬화 포맷 자체는 `review_lock.py`가 단일 파서/시리얼라이저로 소유(Deferred to plan).

### set / clear / refresh / pause

| 시점 | 동작 |
|---|---|
| `reviewing-spec` Step 1 (**매 진입** — 최초 + revise 재진입) | `review_lock.py set <sid> <spec_path>` → **그 문서 엔트리**를 `{path, since: now}`로 upsert(다른 엔트리 보존). **매번 refresh**([4c70bd68]). |
| Phase 5 **① / ②** (approve) | `approve_handoff.sh`가 suppress + pending strip과 함께 `review_lock.py clear <sid> <spec_path>` 호출 → **그 문서 엔트리만** 제거. |
| **`/spec-distill:cancel-review`** (중단) | `cancel_review.py`가 취소 문서 키의 엔트리를 `review_lock.py clear`로 제거(approve와 대칭 — [8ae8776c]). 키 불일치 엔트리는 불변. |
| Phase 5 **③** (수정 필요/revise) | clear 안 함. 다음 `reviewing-spec` 진입 Step 1이 그 문서 엔트리 refresh. |
| Phase 5 **④** (멈춤/나중에) | `review_lock.py pause <sid> <spec_path>` = **그 문서 엔트리 제거 + 같은-문서 pending strip**(suppress 없이 — resumable). "그 문서에 대해 pending 없음·lock 없음". 재개는 재편집(pending 재-arm)이 담당. |

**clear/pause 주체**: approve(①②)·cancel-review는 clear + **suppress**(재-arm 차단),
"④ 멈춤"은 **pause**(엔트리 제거 + pending strip, suppress 없이 — resumable), ③ revise만
그대로 두고 재진입이 refresh. ④에서 엔트리만 제거하고 pending을 남기면 즉시 재발동
([83dc5425]), 엔트리를 남기면 이후 재편집이 억제되는 bounded under-review 창([fa17d241])
— 그래서 ④(pause)는 **엔트리와 pending을 함께 제거**해 두 실패를 동시에 닫는다. 이 모든
동작은 **그 문서 엔트리에만** 작용하고 다른 문서 엔트리는 건드리지 않는다([ad4e6c3f]).

### 훅의 판정 (fail-safe = 강제)

`review-dispatch.py`(Stop)와 `pending-review-reminder.py`(UserPromptSubmit)는 pending을
처리하기 전에 락을 조회한다. **no-op은 오직 "그 pending 문서의 엔트리가 존재 + 신선"일 때만**:

```
is_review_active(body, pending_key, now, ttl):
    entry = find review_in_progress 엔트리 where entry.path == pending_key
    if entry 없음: return False                        # 이 문서 락 없음 → 강제
    if (now - entry.since) >= ttl: return False          # stale → 강제 (fail-safe)
    return True                                          # 그 문서 + 신선 → no-op
```

- `True` → `return 0`. dispatch/block 없음, **pending strip도 없음**(보존).
- `False`(그 문서 엔트리 없음 / stale / 파싱·import 예외) → **정상 dispatch 경로로 진행**.
  load-bearing 강제가 조용히 꺼지지 않는다(Law 1 — over-review > under-review, 기존
  suppress fail-open과 동일 방향). **다른 문서의 엔트리가 신선하게 존재해도 이 문서에는
  영향 없음**(엔트리 조회가 pending_key로 매칭되므로).

TTL 기본값 **1800초(30분)** — 단, refresh-on-reentry 때문에 실제로 걸리는 건 *한 라운드
간 gap*이지 전체 리뷰 누적시간이 아니다. env `DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC`로 override.
`set`/`clear` 시 TTL 초과 stale 엔트리를 opportunistic prune해 리스트를 bounded하게 유지한다.

### 왜 pending을 항상 arm 유지하는가 (안전 substrate)

락은 *타이밍만* 게이트하고, 강제의 substrate인 `pending_review`는 항상 존재하게 둔다.
그래서 그 문서 엔트리가 stale/부재로 판정되는 순간 훅은 곧바로 pending을 집어 강제를
재개할 수 있다. 반대로 validator 쪽에서 arm 자체를 억제하면(Rejected R2), 락이 오판될 때
강제할 대상 자체가 사라져 under-review로 fail한다 — Law 1 방향과 반대다. multi-key
document-keying이 더해지면서 "무관 문서가 억제되는"(R6) / "한 문서 리뷰가 다른 문서 락을
clobber하는"(R7) 두 창이 모두 닫힌다.

### 단일 소스 헬퍼: `scripts/review_lock.py`

- Python API: `set_lock(state_file, raw_path, now)`(그 키 엔트리 upsert, 나머지 보존),
  `clear_lock(state_file, raw_path)`(그 키 엔트리만 제거), `pause(state_file, raw_path)`
  (`clear_lock` + 같은-키 pending strip, suppress 없음), `is_review_active(body, pending_key, now, ttl) -> bool`.
- `canonical_key`는 `suppress_state`에서 import(별도 정규화 금지).
- CLI(호출자: skill·bash): `python3 review_lock.py {set|clear|pause} <session_id> <spec_path>`.
- 훅은 `is_review_active`를 import(인라인 파싱 중복 제거).
- 원자적 write(flush + fsync). kill switch(`DEVBREW_DISABLE_SPEC_DISTILL=1`) → no-op.

## Files to Modify

| 파일 | 변경 |
|---|---|
| `scripts/review_lock.py` **(신규)** | `set_lock`/`clear_lock`/`pause`/`is_review_active` + `{set,clear,pause}` CLI. **문서별 엔트리 리스트**, 원자적 write, stale prune, kill switch. |
| `hooks/review-dispatch.py` | suppress 체크 뒤·TTL 가드/dispatch 앞에 `is_review_active(body, canonical_key(pending.path), now, ttl)` 게이트. True→`return 0`(strip 없음), False→강제. |
| `hooks/pending-review-reminder.py` | 동일 document-keyed 락 존중(같은 문서 mid-review 재-nag 방지). |
| `skills/reviewing-spec/SKILL.md` | Step 1(매 진입)에서 `review_lock.py set`(refresh); Phase 5 옵션↔락 매핑 표 추가 — ①②=`approve_handoff.sh`(clear+suppress), ③=refresh(재진입), **④=`review_lock.py pause`**(엔트리+같은-문서 pending strip). ④의 pending strip은 `review_lock.py pause`가 수행([83a2e2ee] — 코드 위치 명시). |
| `scripts/approve_handoff.sh` | (a) suppress + `review_lock.py clear` 호출, (b) dead `git_common_dir`/`main_repo` 블록(line 63-70) 제거. |
| `scripts/cancel_review.py` | 취소 문서 키의 엔트리를 `review_lock.py clear`로 제거(approve와 대칭). 키 불일치 엔트리 불변. |
| `hooks/spec-write-validator.py` | **무변경** (pending 항상 arm = 안전 substrate). |
| `.claude-plugin/plugin.json` | 0.17.0 → 0.18.0 (minor: 새 state 블록 + 동작). |
| `CHANGELOG.md` | `[0.18.0]` 항목. |
| `README.md` | "Hooks Installed"/state schema/kill switch·env 동기화. |
| `tests/*` | 아래 Verification Plan의 신규·회귀 테스트. |

## Data Flow

### 정상 경로

1. design 작성 → validator가 `pending_review`(문서 A) arm.
2. 메인 Stop → 훅: A 엔트리 없음 → pending strip + `last_dispatched_at` set + `decision:block` → `reviewing-spec` 강제.
3. `reviewing-spec` Step 1 → **`review_lock.py set`(A 엔트리, since=now)** → `spec-reviewer` async dispatch.
4. subagent 경계 Stop → 훅: A 엔트리 신선 → `return 0` (no-op). ← (A)/(B) 봉쇄.
5. verdict 처리 → approve → Phase 5 ①/② → `approve_handoff.sh` → suppress + **`review_lock.py clear`(A 엔트리)**.

### revise 루프 (multi-round)

- verdict = needs_revise(< 5) → 메인 에이전트가 design 직접 편집 → validator가 pending 재-arm.
- 이 사이 어떤 Stop이든: A 엔트리 신선 → no-op.
- `reviewing-spec` 재진입 Step 1 → **A 엔트리 refresh(since=now)** → 라운드가 5회, 각 수 분이라도
  *라운드-간 gap*만 TTL에 걸리므로 누적시간이 30분을 넘어도 fail-safe 오발 없음.

### 인터리브 2-문서 리뷰 (round-1 [8ae8776c] + round-3 [ad4e6c3f] 봉쇄)

- 문서 A 락(A 엔트리) 신선한 상태에서 사용자가 무관한 문서 B 작성 → validator가 B pending arm.
- 메인 Stop → 훅: `is_review_active(B)` — A 엔트리는 있지만 **B 엔트리는 없음** → False → **B 정상 강제 dispatch**(Goal 3).
- B의 `reviewing-spec` Step 1 → `set_lock(B)` → **B 엔트리 추가(A 엔트리 보존 — multi-key)**.
- 이후 A가 revise로 재편집(A pending 재-arm) → 훅: `is_review_active(A)` — **A 엔트리 여전히 신선** → no-op → **A 보호 유지**(Goal 1). 한 문서의 리뷰가 다른 문서 락을 clobber하지 않는다.

### 멈춤(④) 후 재개 (round-2 [fa17d241] 봉쇄)

- 사용자가 Phase 5에서 ④ 멈춤 → `review_lock.py pause` → 그 문서 엔트리 제거 + 같은-문서 pending strip → "그 문서에 pending 없음·lock 없음".
- 그 턴 Stop → 훅: pending 없음(`if not m: return 0`) → no-op. 즉시 재발동 없음([83dc5425]).
- 이후 사용자가 같은 문서를 재편집 → validator가 pending 재-arm → 그 문서 엔트리 없음 → **Stop이 정상 강제**.
  멈춤과 재편집 사이에 억제 창이 존재하지 않는다(bounded under-review 없음).

### fail-safe (stale 엔트리)

- 크래시/방치로 그 문서 엔트리가 마지막 refresh 이후 TTL 초과 → 다음 Stop이 엔트리를 무시하고 pending으로 강제.
- **세션-내 유일한 fail-safe는 `is_review_active`의 1800초 TTL이다.** `spec-distill-gc.py`는
  self-session protection이 있어 *현재 살아있는 세션*의 폴더/락은 건드리지 않는다 — 24h GC는
  세션-간 leftover만 정리하며 이 시나리오에 관여하지 않는다(round-1 [6f4649f8]: "2겹 보호" 아님).

## Acceptance Criteria

- **AC1** `reviewing-spec` Step 1이 **매 진입(최초 + revise 재진입)** `review_lock.py set`을 호출해 그 문서 엔트리를 `{path: canonical_key, since: now}`로 upsert(refresh)하며 **다른 문서 엔트리는 보존**한다.
- **AC2** Phase 5 옵션↔락 매핑: ①/②(approve)=`approve_handoff.sh`가 clear+suppress; ③(revise)=clear 안 함(재진입이 refresh); ④(멈춤)=`review_lock.py pause`(그 문서 엔트리 제거 + 같은-문서 pending strip, suppress 없이). SKILL.md에 이 매핑이 표로 명시된다.
- **AC3** `review-dispatch.py`는 `is_review_active`가 True(pending_key 엔트리 존재 + 신선)일 때만 `return 0`하고 pending을 strip하지 않는다.
- **AC4** `review-dispatch.py`는 pending_key 엔트리 부재 / stale(≥TTL) / 파싱·import 예외 중 하나라도면 락을 무시하고 정상 dispatch한다(fail-safe = 강제, Law 1).
- **AC5** `pending-review-reminder.py`도 동일 document-keyed 신선 엔트리를 존중해 같은 문서 mid-review 재-emit을 하지 않는다.
- **AC6** `approve_handoff.sh`가 suppress 기록과 함께 `review_lock.py clear`(그 문서 엔트리)를 호출한다.
- **AC7** `spec-write-validator.py`는 변경되지 않는다 — pending은 여전히 항상 arm된다.
- **AC8** TTL은 `DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC`로 override 가능, 미설정 시 1800.
- **AC9** `last_dispatched_at` 30초 self-ref 가드는 유지된다(제거·병합 금지 — pre-lock 창·strip 실패 커버).
- **AC10** 기존 kill switch(`DEVBREW_DISABLE_SPEC_DISTILL`, `DEVBREW_SKIP_HOOKS:spec-distill:{Stop,review-dispatch,UserPromptSubmit,reminder}`)가 락 로직 위에서도 그대로 동작한다.
- **AC11** `cancel_review.py`가 취소 문서의 canonical_key 엔트리를 `review_lock.py clear`로 제거한다(approve와 대칭). 키 불일치 엔트리는 불변.
- **AC12** `approve_handoff.sh`의 dead `git_common_dir`/`main_repo` 블록(line 63-70)이 제거된다.
- **AC13** `plugin.json`=0.18.0, `CHANGELOG.md` `[0.18.0]`, `README.md` 동기화(README sync 테스트 통과).
- **AC14** 회귀 락은 teeth를 가진다 — body-unique 문구를 섹션 윈도우에서 grep + mutation으로 삭제 시 실패함을 증명(헤더-satisfiable 함정 회피).
- **AC15** **multi-round 시나리오**: 한 문서가 5개 라운드로 각각 TTL 미만 gap으로 이어질 때(재진입마다 refresh) fail-safe가 스테일로 오판하지 않는다 — 시뮬레이션 timestamp로 단위 검증.
- **AC16** **무관 문서 비억제**: 문서 A 엔트리가 신선한 동안 (별개 canonical_key인) 문서 B의 pending이 arm되면 `is_review_active`가 B에 대해 False를 반환하고 B의 최초 dispatch가 억제되지 않는다 — 회귀 테스트.
- **AC17** **멈춤 후 재개(under-review 창 없음)**: "④ 멈춤"(pause)이 그 문서 엔트리 + 같은-문서 pending을 함께 제거하므로, 멈춤 뒤 TTL 잔여 시간 내에 같은 문서를 재편집(pending 재-arm)해도 엔트리가 없어 Stop 훅이 정상 dispatch한다 — 시나리오(멈춤→재편집→Stop enforce) 테스트([fa17d241]).
- **AC18** **인터리브 락 비-clobber(Goal 1 커버)**: 문서 A 엔트리가 신선한 동안 무관 문서 B가 dispatch되어 `set_lock(B)`가 실행돼도 A 엔트리는 보존된다(multi-key). 이후 A pending 재-arm 시 `is_review_active(A)`가 True를 유지해 A의 (A)/(B) 오발이 재발하지 않는다 — 회귀 테스트([ad4e6c3f]).

## Verification Plan

신규 `tests/test_review_lock.py` (unittest):

- `set_lock`이 그 키 엔트리를 upsert(신규/기존 refresh)하며 **다른 키 엔트리 보존**, `clear_lock`이 그 키만 제거, `pause`가 그 키 엔트리 제거 + 같은-키 pending strip, 모두 멱등.
- `is_review_active`: pending_key 엔트리+신선 → True; 그 키 엔트리 없음(다른 문서만 존재 포함) → False(AC16); stale(> ttl) → False; 락 부재 → False; 파싱 불가 → False.
- **인터리브(AC18)**: `set_lock(A)` → `set_lock(B)` 후 두 엔트리 모두 존재, `is_review_active(A)`·`is_review_active(B)` 둘 다 True; `clear_lock(A)` 후 B 엔트리 불변.
- **multi-round(AC15)**: 한 키의 since를 매 라운드 refresh하면 5라운드×(TTL−ε) 누적이어도 각 시점 True.
- stale prune: TTL 초과 엔트리가 set/clear 시 제거됨. CLI `set`/`clear`/`pause` 원자적 갱신, kill switch no-op.

훅 테스트(기존 `test_review_dispatch.sh` / `test_reminder_hook.sh` 확장):

- 같은 문서 엔트리 신선 + pending → Stop 훅 no-op(빈 stdout, exit 0) + pending 보존.
- **다른 문서만 엔트리 존재 + 이 문서 pending(AC16)** → Stop 훅 `decision:block` emit(억제 안 됨).
- 엔트리 stale + pending → `decision:block` emit + pending strip(기존 강제).
- 엔트리 부재 → 기존 동작 불변.
- **멈춤(pause)→재편집(AC17)**: pause가 엔트리+pending 제거 후 같은 문서 재-arm → Stop `decision:block` emit(억제 안 됨).
- reminder: 같은 문서 신선 → 재-emit 안 함 / 다른 문서·stale → 재-emit.

**Fixture 현실성 (round-2 [da7c35b6] + round-3 잔여).** lock-matching 테스트는 기존
`/tmp/*.md`류 out-of-scope fixture(= `canonical_key` → None, 비교가 vacuous 통과)를
재사용하지 않고 `docs/superpowers/specs/`-prefixed 실제 형태 경로를 쓴다. **두 시나리오
유형을 구분**한다:

- **AC15/AC17/AC18(같은 문서 정체성)**: 같은 파일을 **다른 경로 형태**(worktree-absolute
  vs main-repo-absolute)로 참조해 `canonical_key` 수렴을 실제 exercise.
- **AC16(서로 다른 문서)**: PREFIX 아래 **파일명이 다른 진짜 두 문서**(A-design.md /
  B-design.md)를 써 canonical_key가 실제로 갈리게 함 — 같은 문서의 경로 변형을 "A/B"로
  재사용하면 두 키가 수렴해 다시 vacuous가 되므로 금지.

스크립트/스킬 테스트:

- `test_approve_handoff.sh` — approve 시 `review_lock.py clear` 호출 + dead `main_repo` 블록 부재(grep).
- `test_cancel_review.py` — 취소 키 엔트리 → clear 호출; 다른 키 엔트리 불변(AC11).
- `reviewing-spec` SKILL.md에 set(refresh)·Phase5 매핑(④=pause) 문구 존재 — **body-unique** 문구를 섹션 윈도우에서 grep(AC14 teeth: mutation 삭제 시 red).

동기화·통합:

- `test_readme_sync.sh` 통과(새 env/state 반영).
- 전체 `/qg` 파이프라인(security-reviewer + codex 포함) clean.

## Rejected Alternatives

- **R1 — 강제를 UserPromptSubmit로 이동, Stop 경량화.** UserPromptSubmit는 subagent-발 Stop에 면역이나, 같은-턴 즉시 강제(Law 1 즉시성)를 잃는다. 강제 계약 자체를 바꾸는 침습.
- **R2 — validator에서 재-arm 억제.** Stop 훅 무변경으로 더 가볍지만, 락 오판 시 강제 substrate(pending)가 사라져 under-review로 fail — Law 1 방향과 반대. document-keyed 락은 pending을 substrate로 보존해 이 문제를 피한다.
- **R3 — `stop_hook_active` / subagent-origin 신호로 대체.** 라이브 재현이 보여주듯 문제의 Stop은 *메인 에이전트가 async subagent를 기다리려 멈춘* 진짜 메인 Stop이라, "origin"으로는 "리뷰-도중 stop"과 "리뷰-완료 stop"을 구분할 수 없다(둘 다 같은 메인 Stop). 게다가 subagent가 개입하지 않는 revise-편집 재-arm 경로는 origin 신호로 아예 안 잡힌다. 필요한 신호는 "이 문서의 리뷰가 진행 중"이라는 *의도*이며 document-keyed 락이 그 추상 수준.
- **R4 — `last_dispatched_at`을 락으로 병합.** 락은 리뷰-도중을, `last_dispatched_at`은 strip-실패·pre-lock 창을 커버하는 별개 실패 모드. 병합하면 pre-lock 창에 구멍 → 회귀.
- **R5 — Stop 훅 삭제.** 리뷰 강제는 Law 1/Law 2 load-bearing "불변" — 삭제는 리뷰 우회 구멍. 사용자 확인 방향(삭제 없이 개선).
- **R6 — 세션-전역 스칼라 락(v1 draft).** round-1 [8ae8776c] 기각: 세션 단일 스칼라면 문서 A 락이 무관한 문서 B의 최초 강제까지 억제(under-review, Law 1 위반). document-keyed로 대체.
- **R7 — 단일 `{path, since}` 쌍 락(round-2 draft).** round-3 [ad4e6c3f] 기각: path를 가져 "document-keyed"라 불렀지만 엔트리가 하나뿐이라 `set_lock`이 매번 덮어씀 → 인터리브 2-문서 리뷰에서 B의 set이 A 엔트리를 clobber, A 보호 붕괴(Goal 1 재발). **문서별 엔트리 리스트(multi-key, `suppressed_paths` 동형)**로 대체.

## Metadata

- **Version**: `plugin.json` 0.17.0 → **0.18.0** (minor — 새 state 블록 + 훅 동작 추가, breaking 아님).
- **CHANGELOG** `[0.18.0]`: Added=`review_lock.py`(multi-key document-keyed) + `review_in_progress` 엔트리 리스트 + `REVIEW_LOCK_TTL_SEC` env; Changed=Stop 훅·reminder가 document-keyed 락 존중, `approve_handoff.sh`·`cancel_review.py`가 락 clear, `reviewing-spec`가 매 진입 refresh + ④=pause; Fixed=subagent 경계 Stop 재발동(중복/절단); Removed=`approve_handoff.sh` dead `main_repo` 블록.
- **철학 인스턴스**: Law 1(강제 유지 + fail-safe=enforce + 무관 문서 비억제 + 인터리브 비-clobber), Law 2(훅은 state만·product write 불가, 락 set/clear는 skill·스크립트로 — 이 설계 자체가 물리 분리 리뷰어에게 3라운드에 걸쳐 실버그 다수를 잡혔다), Law 3(회귀 락 teeth + dead 코드 클린업 + 라이브 재현 기록).
- **선행 조사**: `docs/superpowers/specs/2026-05-16-spec-distill-hook-review-design.md`, memory `project_spec_distill_review_hardening`.
- **Round-1 반영**: be017f45(Handoff Context) · 83dc5425(멈춤 재발동 방지→round-2 정착) · 8ae8776c(document-keyed + cancel_review) · 4c70bd68(refresh-on-reentry + AC15) · 8953275b(라이브 재현 각주) · adcd1c89(R3 강화) · 6f4649f8(GC 서술 정정).
- **Round-2 반영**: fa17d241(④ pause=엔트리+pending 동시 제거, AC17 + Data Flow) · da7c35b6(lock-matching 테스트 실경로 fixture).
- **Round-3 반영**: ad4e6c3f(단일 쌍 → **multi-key 엔트리 리스트**, R7 + AC18 + 인터리브 Data Flow) · 83a2e2ee(Files의 ④=유지 옛 표현 → `review_lock.py pause`로 정정 + pending-strip 코드 위치 명시) · da7c35b6 잔여(AC16 fixture를 "서로 다른 두 문서"로 분리 명시).
