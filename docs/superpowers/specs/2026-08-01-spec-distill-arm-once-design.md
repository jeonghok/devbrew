---
name: spec-distill-arm-once
date: 2026-08-01
plugin: spec-distill
target_version: 0.25.0
branch: worktree-feature+spec-distill-arm-once
---

# spec-distill — 스펙 리뷰 훅을 arm-once로

> 원인을 지우면 그 원인을 막던 방어층도 같이 지워진다.

design doc auto-review를 **문서가 처음 생길 때 한 번만** 발동시키고, 그 결과로 존재 이유를 잃는 방어 하니스를 제거한다.

## 목차

- [§1 Context / Why](#1-context--why)
- [§2 Goals](#2-goals)
- [§3 Non-goals](#3-non-goals)
- [§4 확정된 결정](#4-확정된-결정)
- [§5 Architecture](#5-architecture)
  - [§5.1 arm 판정의 단일 지점](#51-arm-판정의-단일-지점)
  - [§5.2 기록 시점 — dispatch가 기록한다](#52-기록-시점--dispatch가-기록한다)
  - [§5.3 상태 스키마](#53-상태-스키마)
  - [§5.4 리뷰 진입 시 pending strip](#54-리뷰-진입-시-pending-strip--지연-재소비-봉쇄)
- [§6 컴포넌트](#6-컴포넌트)
- [§7 제거 목록](#7-제거-목록)
- [§8 에러 처리와 degradation](#8-에러-처리와-degradation)
- [§9 Files to Modify](#9-files-to-modify)
- [§10 Verification Plan](#10-verification-plan)
- [§11 Rejected Alternatives](#11-rejected-alternatives)
- [§12 Handoff Context](#12-handoff-context)

## 1. Context / Why

`spec-write-validator.py`(PostToolUse)는 `docs/superpowers/specs/` 아래 `.md`에 대한 **모든** Write/Edit/MultiEdit에서 두 가지 일을 한다.

- **Layer 1 — 구조 검증**: ambiguity/placeholder 스캔, 실패 시 `exit 2`로 차단. 싸고 결정론적.
- **Layer 2 — arm**: `pending_review:`를 상태 파일에 기록. Stop 훅(`review-dispatch.py`)이 이를 읽고 `decision: block`으로 `reviewing-spec` skill 호출을 강제한다. 그 skill은 `spec-reviewer` 서브에이전트 + codex co-reviewer를 돌린다. 비싸다.

문제는 Layer 2가 **편집 한 번마다** 다시 발동한다는 것이다. 오탈자 하나를 고쳐도, 이미 승인된 문서의 서술을 다듬어도 전체 리뷰 파이프라인이 다시 돈다.

이 재발동을 막으려고 세 번의 릴리스가 **같은 근본 원인의 증상을 하나씩** 패치해 왔다.

| 릴리스 | 추가된 것 | 막으려던 증상 |
|---|---|---|
| v0.14.0 | `suppress_state.py` + `suppressed_paths` + `/cancel-review` | 사용자가 중단을 요청해도 다음 편집이 재arm |
| v0.15.0 | `approve_handoff.sh`의 suppress 기록 순서 역전 | approve 후 같은 턴에 재dispatch |
| v0.18.0 | `review_lock.py` + `review_in_progress` | 리뷰 진행 중 재arm된 pending이 subagent 경계 Stop에서 오발 |

세 층 모두 **훅이 자기가 만든 재발동을 자기가 막는** 구조다. 사용자 기능이 아니다. 원인을 제거하면 셋 다 근거를 잃는다.

## 2. Goals

- G1. design doc auto-review의 **dispatch emit**(Stop 훅이 `decision: block`을 내는 횟수)이 한 문서에 대해, 그 문서가 git-tracked가 되기 전에는 **세션당 최대 1회**, git-tracked가 된 뒤로는 **0회**. 정상 경로(생성 → 리뷰 → 커밋)에서 이것이 "생애 1회"로 귀결되지만 무조건적 불변식은 아니다 — 커밋하지 않은 채 세션을 넘기면 한 번 더 발동한다. 세는 단위는 pending 파일 쓰기 횟수가 아니라 dispatch emit 횟수다(§5.2의 덮어쓰기는 의도된 동작).
- G2. Layer 1 구조 검증은 **모든** Write/Edit/MultiEdit에서 그대로 유지된다 (Law 1).
- G3. 재발동을 막으려고 존재하던 하니스를 제거한다 — 축소가 아니라 삭제.
- G4. arm 판정 로직은 **한 파일에만** 존재한다.
- G5. 신규 환경변수·신규 커맨드·신규 훅 없음. 하니스 총량이 순감소한다.

## 3. Non-goals

- NG1. 커밋된 design doc의 사후 변경에 대한 자동 재리뷰 경로를 만들지 않는다. 사용자가 요청하면 모델이 skill을 호출한다.
- NG2. "실질 변경 대 서술 변경"을 판별하는 휴리스틱을 만들지 않는다.
- NG3. interview brief 파이프라인(`reviewing-brief`, `check_brief.py`, brief 리뷰어 3종)은 건드리지 않는다. 이 설계는 design doc 경로에만 해당한다.
- NG4. 진행 중인 세션의 상태 파일을 마이그레이션하지 않는다. `.claude/spec-distill/` 아래 상태는 git-ignored·세션 스코프·GC 대상이다.
- NG5. arm-once를 끄고 옛 동작으로 되돌리는 escape hatch를 만들지 않는다.

리뷰에서 NG5에 대한 반론이 나왔다. `/cancel-review`는 README(`plugins/spec-distill/README.md:99`, `:165`)에서 kill switch 3종과 **명시적으로 구분되는 per-doc P17 주권 경로**로 문서화돼 있다. 3종은 모두 세션-전역·all-or-nothing이므로, 문서 단위 remediation을 잃으면 남는 선택지가 "플러그인 전체 끄기"뿐이라는 지적은 사실이다.

이 설계는 그 remediation이 **필요한 상태 자체를 없애서** 답한다. `/cancel-review`가 실제로 고치던 것은 두 가지였다 — approve 후 재arm, 그리고 고착된 pending. 재arm은 arm-once가 없애고, 고착된 pending은 §5.4의 entry-strip이 없앤다. 억제 수단을 뺏는 것이 아니라 억제할 대상을 없애는 것이므로 P17 주권은 줄지 않는다. README의 P17 instantiation 서술은 이에 맞춰 갱신한다(§9).

## 4. 확정된 결정

브레인스토밍 대화에서 사용자가 명시적으로 고른 것들이다. 재논의 대상이 아니다.

| # | 결정 | 대안 |
|---|---|---|
| D1 | arm 조건 = 세션 원장에 없음 **AND** git이 모르는 문서 | 세션 원장 단독 / Write 도구만 arm |
| D2 | 커밋된 문서의 사후 변경에 **자동 재리뷰 경로 없음** | 명시적 재리뷰 커맨드 / 실질 변경 휴리스틱 |
| D3 | fix 루프(needs_revise → 수정 → 재리뷰)의 훅 강제를 **떼낸다** | 미커밋 조건만 써서 fix 루프 강제 유지 |
| D4 | `approve_handoff.sh`를 shim으로 남기지 않고 **삭제** | ~25줄 advisory shim 유지 |
| D5 | UserPromptSubmit reminder 훅은 **유지** | 통째 삭제 |

D3의 대가를 명시한다. fix 루프의 재리뷰는 이제 `reviewing-spec` skill의 결정론 라우팅 표(verdict → 재dispatch)와 re-review cap이 담당하며, 훅이 강제하지 않는다. Law 1이 그만큼 얇아진다는 것을 알고 선택했다.

## 5. Architecture

### 5.1 arm 판정의 단일 지점

Layer 2 진입 앞에 게이트 하나를 둔다.

```
should_arm(state_file, path) =
      not is_armed(state_file, path)     # 세션 원장 — 세션 안쪽 시간축
  and not is_born(path)                  # git 추적 여부 — 세션 바깥 시간축
```

두 조건이 서로 다른 시간축을 덮는다. 원장 단독이면 세션이 바뀔 때마다 그 문서가 한 번씩 다시 리뷰된다. git 단독이면 리뷰 fix 루프(문서가 아직 미커밋인 구간)에서 계속 재arm되어 지금 문제가 남는다. 둘을 AND로 묶어야 "생애 한 번"이 된다.

`is_born`은 `git ls-files --error-unmatch -- <path>`의 exit 0 여부다. **git이 아는 문서 = 이미 태어난 문서**로 본다. index 조회라 history walk보다 가볍고, `git add`만 된 문서도 태어난 것으로 취급한다 — 저자가 그 문서를 리포에 넣기로 이미 결정했다는 뜻이므로 의도한 경계다.

이 판정은 `scripts/arm_ledger.py`에만 존재한다 (G4). 훅은 `should_arm()` 하나만 호출한다.

### 5.2 기록 시점 — dispatch가 기록한다

원장에 키를 넣는 주체는 **Stop 훅의 성공한 dispatch**다. validator가 아니다.

validator가 `pending_review:`를 쓰는 시점에 기록하면, dispatch가 실패한 경우(상태 rewrite OSError 등) 그 문서는 "arm 완료"로 표시된 채 **리뷰를 한 번도 받지 못한다**. 되돌릴 경로가 없다 — 이것이 이 설계에서 가장 위험한 실패 모드다.

dispatch 시점 기록은 이를 구조적으로 막는다.

```
편집 1 → validator: should_arm=true → pending_review 기록
편집 2 → validator: should_arm=true → pending_review 덮어쓰기 (같은 문서, 멱등)
턴 종료 → Stop: pending 읽음 → 단일 원자적 write로
                  (a) pending strip  (b) armed_paths 추가  (c) last_dispatched_at 갱신
              → fsync → decision:block emit
편집 3 → validator: should_arm=false (원장에 있음) → arm 없음
```

기록·strip·타임스탬프가 **한 번의 `rewrite_state()` 원자적 write**로 묶인다. 실패하면 셋 다 안 일어나고 emit도 안 된다 — 기존 AC7.2 계약(rewrite 실패 시 무-emit) 위에 그대로 얹힌다.

reminder 훅(UserPromptSubmit)은 원장에 기록하지 않는다. reminder는 pending을 strip하지 않는 재-nag이므로, 여기서 기록하면 "리뷰 안 받았는데 arm 완료" 창이 다시 열린다. reminder만으로 리뷰가 진행된 경우 원장이 비어 재arm될 수 있으나, 방향이 과리뷰 쪽이라 안전하다.

### 5.3 상태 스키마

```diff
  ---
  session_id: <sid>
  ---

  pending_review:
    path: / mode: / worktree_path: / triggered_at:

- suppressed_paths:          # approve·cancel이 사후 기록하던 "다시 arm 마라" 집합
-   - docs/superpowers/specs/...
- review_in_progress:        # 리뷰 중 재arm 오발을 막던 문서별 락
-   - path: ...
-     since: ...
+ armed_paths:               # dispatch가 즉시 기록. 사후 기록자 없음
+   - docs/superpowers/specs/...

  last_dispatched_at: ...
```

`suppressed_paths`와 `armed_paths`는 자료구조가 동형이고 의미도 같다 — "이 문서는 더 이상 arm하지 마라". 다른 것은 **누가 언제 쓰는가**뿐이다. `suppressed_paths`는 사후 기록이라 기록자가 셋 필요했다(`cancel_review.py`, `approve_handoff.sh`, skill의 pause 경로). `armed_paths`는 arm한 주체가 그 자리에서 쓰므로 기록자가 하나다. 제거되는 하니스 대부분이 이 한 줄에서 나온다.

기존 세션의 상태 파일에 남은 `suppressed_paths`/`review_in_progress` 키는 읽는 사람이 없어져 무시된다 (NG4).

### 5.4 리뷰 진입 시 pending strip — 지연 재소비 봉쇄

`reviewing-spec` skill은 Step 1에서 상태를 로드한 직후 그 문서의 pending을 strip한다.

```bash
python3 "$PLUGIN_ROOT/scripts/arm_ledger.py" strip-pending "$harness_sid" "$spec_path"
```

이 한 줄이 `review_lock.py`(240줄)를 대체한다. 락은 "이 문서의 리뷰가 진행 중이니 dispatch하지 마라"를 상태로 표현했지만, **dispatch의 연료는 pending**이므로 연료를 없애면 락이 필요 없다.

이것이 없으면 arm-once가 닫지 못하는 경로가 남는다. 라운드 1 리뷰가 적발한 시나리오다.

1. validator가 arm → `pending_review` 기록
2. Stop의 `rewrite_state()`가 OSError → pending 미-strip, 원장 미기록, 무-emit (§8)
3. 다음 UserPromptSubmit에서 reminder가 재-nag → 리뷰가 실제로 시작됨
4. reminder는 pending을 strip하지 않으므로(§5.2) pending이 살아 있다
5. redispatch TTL 30초가 지나고 근본 장애가 풀리면, 다음 Stop이 그 pending을 소비해 **진행 중인 리뷰 도중 두 번째 dispatch를 emit**한다

arm-once가 구조적으로 막는 것은 "재arm"(새 pending 생성)뿐이지 **"아직 strip되지 않은 pending의 지연 재소비"가 아니다**. entry-strip은 3단계에서 pending을 없애 5단계를 불가능하게 만든다.

리뷰가 중도에 버려져도 안전하다. 2단계에서 원장 기록이 실패했으므로 그 문서는 여전히 arm 대상이고, 이후 편집이 다시 arm한다. entry-strip이 잃는 것은 **이미 실패한 dispatch의 잔해**뿐이고, 리뷰를 받을 권리는 pending이 아니라 원장이 지킨다.

결과적으로 approve(①/②)와 멈춤(④)은 pending에 대해 할 일이 없다 — entry-strip이 이미 처리했다.

## 6. 컴포넌트

### `scripts/arm_ledger.py` (신규 — `suppress_state.py` 대체)

`suppress_state.py`(242줄)에서 억제 의미를 걷어내고 arm 판정을 넣는다. 목표 ~120줄.

| 함수 | 책임 |
|---|---|
| `canonical_key(raw_path)` | `docs/superpowers/specs/` 이후 substring. 워크트리·절대·상대 경로를 같은 키로. 스코프 밖이면 `None` |
| `state_file_for(sid)` | sid → `state.local.md` 경로 |
| `pending_path(body)` / `strip_pending(body)` | pending 블록 조회·제거 (훅이 공유) |
| `armed_keys(body)` | `armed_paths` 항목 |
| `is_armed(state_file, raw_path)` | 원장 조회 |
| `is_born(raw_path)` | git 추적 여부 |
| `should_arm(state_file, raw_path)` | 위 둘의 AND 부정 — **훅이 부르는 유일한 판정 진입점** |
| `mark_armed(body, raw_path)` | body에 키를 멱등 추가해 **문자열로 반환** (파일 write 안 함 — 호출자가 원자적 write에 합류시킨다) |

CLI는 두 개만 남긴다 (`suppress_state.py`의 add/remove/is-suppressed 3종 삭제).

| CLI | 호출자 | 역할 |
|---|---|---|
| `strip-pending <sid> <raw_path>` | `reviewing-spec` Step 1 진입 | §5.4 — 지연 재소비 봉쇄 |
| `check-born <raw_path>` | `reviewing-spec` approve(①/②) | 미커밋 문서 loud advisory |

`check-born`은 `is_born()`을 그대로 노출한다 (신규 로직 없음). approve 시점에 문서가 아직 git-tracked가 아니면 이렇게 알린다.

> `[spec-distill] '<path>'가 아직 git에 없다 — 지금 커밋하지 않으면 다음 세션에서 이 문서의 리뷰가 한 번 더 발동한다.`

이 advisory는 `approve_handoff.sh`(줄 77–96)가 내던 미커밋 권고를 승계한다. 라운드 1 리뷰가 지적한 대로 그 권고는 단순 편의가 아니라 **G1의 cross-session 보장이 기대는 `is_born` 전제를 사용자가 충족하도록 유도하는 유일한 신호**였다. 동시에 approve가 관측 가능한 부수효과를 남기게 해 AP2 앵커 역할도 한다.

`mark_armed`가 파일이 아니라 문자열을 반환하는 것은 §5.2의 원자성 요구 때문이다. Stop 훅이 pending strip·armed 추가·타임스탬프를 하나의 write로 커밋해야 하는데, 여기서 파일을 따로 쓰면 write가 둘로 갈라져 중간 크래시에 부분 상태가 남는다.

### `hooks/spec-write-validator.py`

suppression 게이트를 arm 게이트로 교체한다. Layer 1은 위치·동작 모두 불변.

```
Layer 1 검증 (모든 경로)
  → 실패면 exit 2
  → 통과 시:
      should_arm(state_file, file_path) 이 false면 → advisory만 내고 return 0
      true면 → pending_review 기록 + 기존 advisory
```

arm이 skip될 때의 advisory 문구는 사용자가 **왜** 리뷰가 안 붙었는지 알 수 있어야 한다 (loud degradation). 두 사유를 구분해 표시한다: 이미 이 세션에서 arm됨 / git이 아는 문서.

### `hooks/review-dispatch.py`

suppress 블록과 review_lock 블록을 삭제한다(~35줄). `rewrite_state()`가 armed 키 추가를 흡수한다. TTL 가드는 유지.

### `hooks/pending-review-reminder.py`

review_lock 블록만 삭제한다(~20줄). 훅 자체는 유지 (D5) — arm 기회가 문서당 한 번뿐이라 놓친 dispatch의 복구가 이전보다 더 중요해진다.

### `skills/reviewing-spec/SKILL.md`

- Step 1의 리뷰 락 refresh 절을 `arm_ledger.py strip-pending` 한 줄로 교체 (§5.4)
- Phase 5 "옵션 ↔ 리뷰 락 매핑" 표 삭제 — 네 옵션 모두 pending에 대해 할 일이 없다
- "Approve handoff sequence" 절을 `arm_ledger.py check-born` 한 줄 + advisory 노출로 교체
- ④ 멈춤은 상태 조작 없이 종료

AP2(polite stop) 검증 앵커는 `approve_handoff.sh` 호출에서 approve 시점의 `check-born` 호출로 옮겨간다 — approve가 여전히 **관측 가능한 행위**로 남으므로 "approved라고 말만 하고 끝내기"는 그대로 검출 가능하다.

## 7. 제거 목록

| 대상 | 줄수 | 조치 | 근거 |
|---|---|---|---|
| `scripts/review_lock.py` | 240 | 삭제 | §5.4의 entry-strip이 같은 불변식을 한 줄로 보장 (연료 제거 > 상태 표현) |
| `scripts/cancel_review.py` | 99 | 삭제 | 억제할 자동 발동도, 고착될 pending도 없음 (NG5) |
| `commands/cancel-review.md` | — | 삭제 | 진행 중 리뷰 중단은 skill 옵션 ④가 담당 |
| `scripts/approve_handoff.sh` | 98 | 삭제 | 상태 변경은 entry-strip이 흡수, 미커밋 advisory는 `check-born`이 승계, 존재 검증은 Phase 5 Step A와 중복 |
| `scripts/suppress_state.py` | 242 | `arm_ledger.py`로 대체 (~120) | CLI 3종·`remove`·`suppress_path` 삭제 |
| env `DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC` | — | 삭제 | 락 소멸 |
| 테스트 5종 | ~900 | 삭제 | 대상 소멸 (§9) |

**유지**: redispatch TTL 30초(reminder의 매-프롬프트 nag 억제에 여전히 필요), GC·SessionEnd 정리, kill switch 3종(`DEVBREW_DISABLE_SPEC_DISTILL`, `DEVBREW_SKIP_HOOKS`, `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW`).

spec-distill은 0.24.4로 v1.0.0 미만이므로 CLAUDE.md의 "제거 전 one-minor deprecation window"(v1.0.0 이상 플러그인 대상)가 구속하지 않는다. `/cancel-review`를 즉시 삭제한다.

## 8. 에러 처리와 degradation

**판정 신호**의 실패는 **arm하는 쪽으로 fail-open**한다 (Law 1: 과리뷰 > under-review). 원장 기록이 1회로 제한하므로 storm이 되지 않는다.

| 실패 | 동작 | 관측 |
|---|---|---|
| `git` 미설치·timeout·exit ≥ 2 | `is_born=false` → arm | stderr loud (exit code 포함) |
| 경로가 git 리포 밖 (exit 128) | `is_born=false` → arm | stderr loud |
| 원장 read 실패 | `is_armed=false` → arm | stderr loud |
| 원장 write 실패 (Stop) | 무-emit·무-기록 → 다음 턴 reminder가 회수 | stderr loud (기존 AC7.2) |
| `session_id` 미해석 | **규칙의 예외** — arm 없음 (아래) | stderr loud, 기존 동작 |

`session_id` 미해석이 예외인 이유를 명시한다. session_id는 arm 여부를 정하는 **판정 신호가 아니라 상태를 어디에 쓸지 정하는 주소**다. 미해석 상태에서는 arm하려 해도 기록할 파일이 없고, arm된 척 진행하면 원장 없는 pending이 생겨 dispatch가 반복될 수 있다 — fail-open의 취지(누락된 리뷰를 살린다)와 반대 결과가 된다. 그래서 이 경우만 arm 없이 advisory로 끝낸다. 리뷰 한 번이 누락되지만 사용자가 stderr로 인지하며, 다음 편집에서 session_id가 해석되면 정상 arm된다(원장이 비어 있으므로).

git 호출 timeout은 5초로 둔다 (PostToolUse 훅 전체 timeout이 10초).

## 9. Files to Modify

### 삭제

```
plugins/spec-distill/scripts/review_lock.py
plugins/spec-distill/scripts/cancel_review.py
plugins/spec-distill/scripts/approve_handoff.sh
plugins/spec-distill/commands/cancel-review.md
plugins/spec-distill/tests/test_review_lock.py
plugins/spec-distill/tests/test_review_lock_session_id.sh
plugins/spec-distill/tests/test_reviewing_spec_lock.sh
plugins/spec-distill/tests/test_cancel_review.py
plugins/spec-distill/tests/test_approve_handoff.sh
```

### 대체

```
plugins/spec-distill/scripts/suppress_state.py → plugins/spec-distill/scripts/arm_ledger.py
```

### 수정

```
plugins/spec-distill/hooks/spec-write-validator.py       arm 게이트
plugins/spec-distill/hooks/review-dispatch.py            suppress+lock 삭제, armed 기록 흡수
plugins/spec-distill/hooks/pending-review-reminder.py    lock 블록 삭제
plugins/spec-distill/skills/reviewing-spec/SKILL.md      락 절 → entry-strip, handoff 절 → check-born
plugins/spec-distill/skills/conducting-interview/SKILL.md  :469 approve_handoff 참조
plugins/spec-distill/tests/test_stale_terms.sh           F0 + 신규 stale term
plugins/spec-distill/tests/test_readme_sync.sh           죽은 키워드 3종 제거, 0.25.x
plugins/spec-distill/tests/test_spec_write_validator.sh  arm 게이트 반영
plugins/spec-distill/tests/test_review_dispatch.sh       suppress·lock 케이스 제거
plugins/spec-distill/tests/test_reminder_hook.sh         lock 케이스 제거
plugins/spec-distill/tests/test_hook_output_schema.py    suppress·lock 참조 제거
plugins/spec-distill/tests/test_handoff_compact_chain.sh       approve_handoff 참조 분류
plugins/spec-distill/tests/test_handoff_spec_path_validation.sh approve_handoff 참조 분류
plugins/spec-distill/README.md                           Hooks Installed·Principles 동기화 + :99·:165의 /cancel-review P17 instantiation 서술 갱신 (NG5)
plugins/spec-distill/CHANGELOG.md                        [0.25.0] Removed/Changed
plugins/spec-distill/.claude-plugin/plugin.json          0.25.0
```

### 신규

```
plugins/spec-distill/tests/test_arm_once.sh              T1–T3
```

## 10. Verification Plan

### 베이스라인 (측정 완료)

이 워크트리(`e45619b`, main과 동일 커밋)에서 측정한 pre-existing red 2건. 회귀 판정의 기준선이다.

| 스위트 | 상태 | 사유 |
|---|---|---|
| bash 51종 | 50 pass / 1 fail | `test_stale_terms.sh` — F0 (아래) |
| python 10종 | 9 OK / 1 fail | `test_hook_output_schema.py::test_python_and_bash_resolvers_agree` — 알려진 NG9 cross-resolver, 워크트리 환경 의존 |

### F0 — `test_stale_terms.sh`의 find 필터 버그 (이 작업에서 수정)

`test_stale_terms.sh`는 production 파일 집합을 이렇게 만든다.

```bash
find "$SD" -type f -not -path '*/.claude/*' ...
```

`*/.claude/*`에 앵커가 없어서 **절대경로 어디에든** `/.claude/`가 있으면 제외된다. 하니스가 만드는 워크트리는 `<repo>/.claude/worktrees/<name>/` 아래 살므로, 워크트리 안에서는 production 파일 279개가 전부 걸러진다. 락은 empty-guard 덕분에 조용히 통과하지 않고 FAIL하지만(fail-closed 설계가 제 역할을 했다), **워크트리에서는 실행 자체가 불가능**하다.

의도는 "플러그인 디렉토리 *아래의* `.claude/` 세션 상태 제외"였으므로 `$SD` 기준으로 앵커한다.

```diff
- -not -path '*/.claude/*'
+ -not -path "$SD/.claude/*"
```

실측: 워크트리에서 0개 → 47개. main 체크아웃에서 48개이고 플러그인-로컬 `.claude/` 7개 파일은 여전히 제외됨(의도 보존).

이 수정은 T4의 전제다 — 고치지 않으면 삭제 스윕 완결을 증명하는 락을 green으로 볼 수 없다.

### 신규 회귀 락

각 락은 **mutation으로 이빨을 증명**한다. 통과가 정답인 assert는 모양만으로 판별할 수 없으므로, 대응하는 production 코드를 망가뜨렸을 때 실제로 RED가 되는지 확인한 결과를 커밋 메시지에 남긴다.

| ID | 락 | mutation |
|---|---|---|
| T1 | 같은 문서 2회 Write + Stop 2회 → 그 문서에 대한 **dispatch emit 총 1회**(두 번째 Stop은 무-emit) | 원장 게이트 제거 → RED |
| T2 | git-tracked 문서 Write → `armed_paths`가 비어 있어도 arm 없음 | git 조건 제거 → RED |
| T3 | `git` 미가용(PATH 조작) → arm 발생 **및** stderr advisory 존재 | fail 방향을 arm-skip으로 뒤집기 → RED |
| T4 | stale-term 스윕에 개념 별칭 전수 추가 | 각 항목을 production에 되살리기 → RED |
| T5 | 삭제 대상 파일 부재 + production 무참조 | 파일 복원 → RED |
| T6 | pending이 살아 있는 상태에서 entry-strip 실행 후 Stop 재발화 → 무-emit (§5.4 5단계 재현) | entry-strip 제거 → RED |

T1은 **파일 쓰기 횟수가 아니라 dispatch emit 횟수**를 잰다. §5.2가 명시한 대로 두 번째 편집이 pending을 덮어쓰는 것은 의도된 동작이므로, "기록 1회"를 assert하면 설계와 모순되는 것을 재게 된다 (라운드 1 codex 지적).

T3은 **양방향** 락이다. fail-open 방향(arm 발생)만 잠그면 advisory 없이 조용히 arm해도 통과하므로, stderr 존재도 함께 assert한다.

T6은 §5.4가 닫는 경로를 직접 재현한다 — `rewrite_state` 실패를 주입할 필요 없이, pending이 남아 있는 상태를 픽스처로 만들고 entry-strip 전후의 Stop 동작 차이를 잰다.

T4의 스윕 대상은 식별자만이 아니라 **같은 것을 다른 이름으로 부른 참조**까지다: `review_lock`, `review_in_progress`, `suppress_state`, `suppressed_paths`, `cancel_review`, `cancel-review`, `approve_handoff`, `DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC`. 스코프는 기존 락과 동일한 production-only(테스트·CHANGELOG 제외) — 테스트의 토큰 참조는 집행 층이지 stale 참조가 아니다.

### 종료 조건

- bash 스위트: F0 수정 후 `test_stale_terms.sh` green, 그 외 red 0건. 스위트 규모는 베이스라인(51종)에서 삭제 3·신규 1을 반영해 49종이 된다 — 종료 조건은 개수가 아니라 **red 0건**이다
- python 스위트: 삭제 2를 반영해 8종. NG9 cross-resolver 1건(워크트리 환경 의존) 외 green — 베이스라인과 동일
- T1–T6 각각의 mutation 결과 기록
- `git grep`으로 삭제 대상 식별자가 production에 0건

### 수동 검증 (자동화 밖)

- V1. 새 design doc을 Write → 리뷰 1회 발동
- V2. 그 리뷰의 fix 루프에서 문서 수정 → 재발동 없음, skill 라우팅 표로 재리뷰 진행
- V3. 문서 커밋 후 편집 → 리뷰 없음, Layer 1 구조 검증은 여전히 동작(placeholder 삽입 시 차단)
- V4. 새 세션에서 **커밋된** 문서 편집 → 리뷰 없음
- V5. V4의 대칭 케이스 — approve했지만 **커밋하지 않은** 문서를 새 세션에서 편집 → 리뷰가 한 번 더 발동한다(G1의 조건부성이 실제로 그렇게 동작함을 확인). 아울러 approve 시점에 `check-born` advisory가 실제로 떴는지 확인 — 이 advisory가 V5 상황을 사용자에게 미리 알리는 유일한 신호다

## 11. Rejected Alternatives

| 대안 | 기각 사유 |
|---|---|
| **미커밋 조건만** (git 단독) | 커밋 전 편집마다 재arm되므로 `review_lock.py`가 살아남는다. 사용자 고통은 해결되나 하니스 제거량이 ~250줄에 그친다. 사용자가 D3에서 arm-once를 명시 선택 |
| **Write 도구만 arm** | 원장·git 모두 불필요해 가장 가볍지만, arm-once 보장이 도구 선택에 의존한다. Write로 전체 재작성하면 재arm |
| **실질 변경 휴리스틱** (Goals/AC 섹션 diff) | 자동성은 유지되나 섹션-diff 파서가 신규로 필요하다. "덜어내기" 요청과 반대 방향 |
| **명시적 재리뷰 커맨드 유지** | D2에서 사용자가 "완전 신뢰"를 선택. 커맨드 하나가 남으면 그 커맨드의 상태 조작 경로도 남는다 |
| **`approve_handoff.sh`를 advisory shim으로 축소 유지** | 라운드 1 리뷰가 지적한 대로 그 스크립트의 미커밋 advisory는 correctness-relevant였다 — G1의 `is_born` 전제를 사용자가 충족하도록 유도하는 유일한 신호였기 때문이다. 그러나 그 **내용**을 지키려고 98줄 bash **형태**를 남길 이유는 없다. `arm_ledger.py check-born` 한 줄이 같은 신호를 내면서 `is_born`을 재사용하고 AP2 앵커도 겸한다(§6). 형태가 아니라 내용을 승계한다 (D4) |
| **`review_lock.py`를 축소 유지** | 락은 "리뷰 진행 중"을 상태로 표현하지만 dispatch의 연료는 pending이다. 연료를 없애는 entry-strip 한 줄이 같은 불변식을 보장하므로(§5.4), 락 유지는 하나의 불변식에 두 표현을 두는 것 — 두 표현이 어긋나는 순간이 곧 버그다 |
| **`/cancel-review`를 per-doc P17 경로로 존치** | 라운드 1 리뷰의 반론이 타당하나(README가 kill switch와 구분해 문서화), 그 커맨드가 고치던 두 상태(재arm·고착 pending)를 arm-once와 entry-strip이 각각 없앤다. 억제할 대상이 없는 억제 수단은 P17 주권에 기여하지 않는다 (NG5) |
| **`suppressed_paths`를 `armed_paths`로 마이그레이션** | 상태 파일은 git-ignored·세션 스코프·GC 대상이고, approve된 문서는 커밋되어 git 조건에 걸린다. 마이그레이션 코드의 수명이 그 코드가 막는 창보다 길다 (NG4) |
| **`arm-once` kill switch 신설** | 옛 동작으로 되돌리는 스위치는 두 동작 경로를 영구 유지한다는 뜻. 기존 kill switch 3종으로 충분 (NG5) |

## 12. Handoff Context

**TL;DR** (무엇을·왜): spec-distill의 design doc auto-review가 지금은 편집 한 번마다 재발동한다. 이 재발동을 막으려 v0.14.0~v0.18.0에 방어층 세 개(`suppress_state.py`·`review_lock.py`·`cancel_review.py` + `approve_handoff.sh`)가 누적됐는데, 셋 다 훅이 자기가 만든 문제를 자기가 막는 내부 하니스다. arm 조건을 `(세션 원장에 없음) AND (git이 모르는 문서)`로 바꿔 재발동 자체를 없애고, 근거를 잃은 방어층을 삭제한다(순감소 ~800줄). 락 대신 `reviewing-spec` 진입 시 pending을 strip해(§5.4) 같은 불변식을 한 줄로 보장한다. Layer 1 구조 검증은 모든 편집에서 그대로 유지된다 — 얇아지는 것은 비싼 Layer 2뿐이다. 목표 버전 0.25.0.

**Implicit context** (Constraints에 안 박힌, 작업에 필요한 외부 사실):

- 작업 위치는 워크트리 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+spec-distill-arm-once`, 브랜치 `worktree-feature+spec-distill-arm-once`, 기준 커밋 `e45619b`. 모든 편집을 이 절대경로 아래에서 수행한다
- 상태 파일은 `state_path.py`가 `git rev-parse --git-common-dir`로 해석하므로 워크트리에서도 **main repo의 `.claude/spec-distill/`**을 가리킨다 (실측 확인)
- `suppress_state`·`review_lock`·`cancel_review` 참조는 **전부 spec-distill 내부**다. 크로스-플러그인 커플링 없음 (리포 루트 `docs/` 아래 과거 plan/spec의 언급은 역사 기록이라 스코프 밖)
- 이 워크트리에서 `test_hook_output_schema.py`의 cross-resolver 테스트는 **환경 의존으로 red**다(python은 main repo `.claude/`, bash는 워크트리 `.claude/`로 해석). 회귀로 오인하지 말 것
- Python 테스트는 `-m unittest`로 실행한다
- `run_spec_codex_reviewer.sh`는 `set -u` 아래 `$CLAUDE_PLUGIN_ROOT`를 참조하므로 **export**된 상태여야 한다
- 이 design doc 자체가 `spec-write-validator.py`의 Layer 1 대상이다. `scripts/ambiguity-blacklist.txt` 항목과 placeholder 토큰을 본문에 넣으면 Write가 `exit 2`로 차단된다. 매칭은 substring·대소문자 무시이며 **인용과 사용을 구분하지 않는다** — 이 문서의 초안이 금지어를 예시로 나열했다가 실제로 차단당했다. 인용이 필요하면 그 occurrence 앞에 `~`를 붙여 opt-out한다

**Deferred to plan** (이 spec이 의도적으로 lock하지 않은 것 — 판정에 영향을 주지 않는 것만):

- `arm_ledger.py` 내부의 함수 배치·정규식 형태·docstring 문구. 공개 API 목록(§6 표)과 `should_arm`의 논리식은 lock됐고 그 아래 구현 재량은 열려 있다
- arm skip advisory의 정확한 문면. **두 사유(원장/git)를 구분해 표시한다**는 요건은 lock, 문장은 자유
- T1–T6 픽스처의 구성 방식(임시 리포 생성 대 기존 리포 사용 등). 각 락이 재는 **대상**은 lock, 재는 방법은 자유
- `test_handoff_compact_chain.sh`·`test_handoff_spec_path_validation.sh`의 처리 — 삭제할지 수정할지는 실제 참조 내용을 보고 계획 단계에서 분류한다

**구현 순서** (의존 관계 — 이것은 lock):

1. **F0** — `test_stale_terms.sh` find 앵커 수정. 다른 모든 검증의 전제
2. **arm_ledger.py** — TDD. `should_arm`/`is_born`/`mark_armed` 단위 테스트 먼저
3. **훅 3종** — validator 게이트 → dispatch 원자적 write → reminder 정리
4. **skill** — `reviewing-spec` entry-strip + approve `check-born` (§5.4·§6)
5. **T1–T3·T6** — 훅·skill 레벨 통합 락 + mutation
6. **삭제 스윕** — 파일 9종 삭제 → skill·테스트 참조 정리 → T4·T5
7. **문서 동기화** — README(P17 서술 포함)·CHANGELOG·plugin.json 0.25.0

3번이 2번보다 먼저 가면 훅이 존재하지 않는 모듈을 import한다. 6번을 3–4번보다 먼저 하면 아직 참조 중인 파일이 사라진다.

알려진 함정은 위 **Implicit context**에 통합했다 — 압축 이후 한 곳만 읽으면 되도록.
