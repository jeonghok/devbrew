---
type: design
topic: spec-distill review cancel + per-doc suppression
plugin: spec-distill
target_version: 0.14.0
date: 2026-06-04
status: design
related:
  - plugins/spec-distill/hooks/spec-write-validator.py        # arm 지점 — suppression 게이트 추가
  - plugins/spec-distill/hooks/review-dispatch.py             # Stop dispatch — 무변경(자연 no-op)
  - plugins/spec-distill/scripts/approve_handoff.sh           # 완료 경로 — rm→strip+suppress 전환
  - plugins/spec-distill/hooks/state_path.py                  # session/root resolution 재사용
  - plugins/spec-distill/scripts/parse_spec_structure.py      # Layer 1 스캔(불변, 직교)
---

# spec-distill 리뷰 취소 + per-doc suppression (v0.14.0)

> 리뷰 완료 후 또는 중단 요청 후에도 같은 design 문서를 다시 건드리면
> Stop 훅이 reviewing-spec를 다시 강제 dispatch하는 문제를, 단일
> session-scoped `suppressed_paths` 집합으로 해소한다 — 취소(사용자)와
> 완료(approve)가 같은 신호를 쓰고, PostToolUse가 arm 직전 조회한다.

## 목차

- [1. Context / Why](#1-context--why)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. Constraints](#4-constraints)
- [5. Architecture](#5-architecture)
- [6. Acceptance Criteria](#6-acceptance-criteria)
- [7. Files to Modify](#7-files-to-modify)
- [8. Verification Plan](#8-verification-plan)
- [9. Rejected Alternatives](#9-rejected-alternatives)
- [Handoff Context](#handoff-context)
- [10. Metadata](#10-metadata)

## 1. Context / Why

spec-distill의 리뷰 상태머신은 **path heuristic으로 arm하고, 명시적 신호로만
disarm**하는 구조다:

- **arm (PostToolUse `spec-write-validator.py`)**: `docs/superpowers/specs/`
  아래 `-design.md`/`-spec.md` write가 구조 검증을 통과하면 `state.local.md`에
  `pending_review:` 블록을 무조건 기록한다. 이 문서가 이미 승인됐는지는 모른다.
- **dispatch & disarm (Stop `review-dispatch.py`)**: 턴 종료 시 `pending_review:`가
  있으면 reviewing-spec를 강제 호출하고, 그 블록을 strip + `last_dispatched_at`을
  기록한다.
- **cleanup 경로는 세 개뿐**: `approve_handoff.sh`(approve + Phase 5 옵션 선택
  시만), `SessionEnd`(세션이 실제 종료될 때만), `spec-distill-gc.py`(24h TTL).
  어느 것도 "지금, 이 문서는 그만"을 표현하지 못한다.

이 구조에서 두 증상이 나온다:

- **증상 A — 리뷰 완료 후 재발동**: approve 후 cleanup이 됐더라도, 같은
  `-design.md`를 다시 편집하면(supersede 포인터·오타·후속 작업) PostToolUse가
  다시 arm한다. 상태머신에 "이 문서는 이미 settled"라는 개념이 없다.
- **증상 B — 중단 요청 후 재발동**: 사용자가 "그만"이라고 해도 `pending_review:`를
  지우는 사용자용 경로가 없다. `DEVBREW_DISABLE_SPEC_DISTILL=1` env뿐인데, 이는
  세션 전체를 무력화하며 env를 직접 설정해야 하고, GC는 24h다. 그래서 매 턴
  Stop/UserPromptSubmit reminder가 계속 nag한다.

**근본 원인은 per-doc "settled/muted" 상태의 부재다.** 취소와 완료는 의미상 같은
신호 — "이 문서는 더 이상 auto-review arm 대상이 아니다" — 이므로 하나의 집합으로
통합할 수 있다.

## 2. Goals

- **G1**: 사용자가 명시 슬래시 커맨드로 현재(또는 특정) 문서의 `pending_review`를
  취소하고 해당 문서의 재arm을 세션 동안 억제할 수 있다.
- **G2**: approve 완료 후 같은 문서를 다시 편집해도 reviewing-spec가 다시
  dispatch되지 않는다.
- **G3**: 억제는 session-scoped(다음 세션은 fresh), 멱등, 결정론적이다.
- **G4**: 재리뷰가 필요하면 명시적 re-enable 경로(`--reset <path>`, 또는 다른
  경로의 새 문서, 또는 reviewing-spec 직접 호출)가 존재한다.
- **G5**: Law 1 구조 게이트(Layer 1)·Law 2 reviewer 분리·kill switch는 불변이다.

## 3. Non-goals

- **NG1**: Layer 1 구조 검증(ambiguity/placeholder 스캔)을 우회하지 않는다 —
  suppression은 arm/dispatch(Layer 2)만 끈다.
- **NG2**: 콘텐츠 해시·material-change 휴리스틱을 도입하지 않는다 (문서 편집도
  콘텐츠를 바꾸므로 해시 기반은 증상 A를 해소하지 못한다 — §9 참조).
- **NG3**: 자연어 의도 파싱(UserPromptSubmit 훅의 "그만" 감지)을 하지 않는다.
- **NG4**: 크로스-세션 영속 ledger를 만들지 않는다 (세션 스코프가 의도된 의미).
- **NG5**: state-storage 대재설계(resume 제거·훅 축소)는 본 스펙 범위 밖이다 —
  본 변경은 그 재설계와 호환되는 작은 표면 추가다.

## 4. Constraints

- **C1**: 훅은 결정론적이어야 한다 (콘텐츠 휴리스틱·NL 파싱 금지 — devbrew P21/훅 원칙).
- **C2**: state는 `state.local.md` 마크다운, plugin namespace(`.claude/spec-distill/<sid>/`)
  안에 산다. secret 기록 금지.
- **C3**: 파싱 — `pending_review` strip 정규식 `^pending_review:\n(?:  [^\n]*\n)*`이
  2-space 들여쓰기 라인만 흡수하고 **0-indent 라인에서 멈춘다**. `suppressed_paths:`가
  0-indent top-level 헤더이므로 그 헤더와 이후 `  - <path>` 항목은 strip에 영향받지
  않는다(round-1 reviewer 실증 확인). 정확성의 핵심은 "`suppressed_paths:`를 0-indent
  키로 둔다"이며, 블록 간 빈 줄은 가독성·방어적 hygiene(필수 아님).
- **C4**: 정규화 키 = 경로에서 `docs/superpowers/specs/` 이후 substring. worktree·절대·
  상대 경로 무관하게 같은 문서가 같은 키로 매핑된다. **정규화는 `suppress_state.py` 한
  곳에만 구현**(single source) — bash 호출자(approve_handoff.sh)·cancel_review.py·validator는
  모두 *raw 경로*를 넘기고 정규화를 위임한다(bash가 `${path#*...}`를 독자 재구현하지
  않아 세 곳 규칙 divergence 차단).
- **C5**: session_id는 `state_path.SESSION_PATTERN` charset/length guard를 재사용한다.
- **C6**: kill switch `DEVBREW_DISABLE_SPEC_DISTILL=1`을 모든 신규 컴포넌트가 존중한다.
- **C7**: python 테스트는 `python3 -m unittest`로만 실행(직접 실행은 vacuous —
  reference 메모).
- **C8**: 구현은 main에서 분기한 워크트리에서 진행한다 (writing-plans 승인 후).
- **C9**: plugin.json SemVer bump(0.13.0 → 0.14.0) + CHANGELOG + README가 같은
  PR에서 동기화된다.

## 5. Architecture

### 5.1 통합 원리

두 gap을 단일 신호로 묶는다: **session-scoped `suppressed_paths` 집합.** 취소(사용자)와
완료(approve)가 같은 집합에 기록하고, PostToolUse가 arm 직전 조회한다. 의미론적으로
suppression = "이 문서에 대한 per-doc·persisted auto-review skip" — 기존
`DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW` env의 per-doc 버전이다.

### 5.2 State 스키마 (`state.local.md`)

```
---
session_id: <sid>
---

pending_review:
  path: <p>
  mode: <spec|design>
  worktree_path: <abs>
  triggered_at: <iso>

suppressed_paths:
  - docs/superpowers/specs/2026-06-04-x-design.md

last_dispatched_at: <iso>
```

- **정규화 키**(C4): `canonical_key(p) = p[p.index(PREFIX):]` (PREFIX = `docs/superpowers/specs/`).
  prefix 부재 시 None(스코프 밖). `suppress_state.py`에만 구현.
- **파싱**(C3): suppressed_paths 추출 정규식 `^suppressed_paths:\n((?:  - [^\n]+\n)*)`.
  보존의 핵심은 `suppressed_paths:`가 0-indent 헤더라는 것(pending strip 정규식이 거기서
  멈춤). 마지막 항목 뒤 개행 부재 시 group(1)이 빈 문자열일 수 있어 `suppress_state.py`가
  trailing newline을 normalize한다.
- **블록 순서 비-규범적**: 위 예시 배치는 예시일 뿐 — 파서는 위치가 아닌 0-indent 헤더
  정규식으로 키를 찾는다. `write_state()`는 `pending_review`를 파일 끝에 append하므로
  런타임 순서는 예시와 다를 수 있다(정확성 무관).

### 5.3 컴포넌트

| 컴포넌트 | 종류 | 변경 |
|---|---|---|
| `scripts/suppress_state.py` | 신규 공유 헬퍼 | 정규화·strip·suppress의 **single source**. Python API + thin CLI. 정확한 시그니처는 §5.5. |
| `scripts/cancel_review.py` | 신규 | session 해석 후 `suppress_state` API 호출. 기본(인자 없음): `pending_review.path`를 raw로 → strip_pending + add. `<path>` 명시 시: 그 키 add, pending이 **같은 키**일 때만 strip(다른 문서 pending 보존 — 특정 문서 targeting). `--reset <path>`: remove. pending 없고 인자 없으면 advisory. kill switch + charset guard. 스코프 밖 경로 거부. |
| `commands/cancel-review.md` | 신규 | 짧은 명령형 래퍼 → `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/cancel_review.py "$ARGUMENTS"`. cost_class: low. |
| `hooks/spec-write-validator.py` | 편집 | `write_state` 직전 `suppress_state.is_suppressed` 조회 → 일치 시 **전용 suppress 분기**: arm skip + 전용 advisory(기존 "Reviewer will be dispatched" 출력을 *교체*) + early return 0. strip은 `suppress_state.strip_pending` import(중복 제거). **Layer 1은 그대로 실행**(NG1·AC10). 문자열은 §5.5. |
| `hooks/review-dispatch.py` (Stop) | 무변경 | 억제는 arm 단계에서 끝나 `pending_review`가 안 생기므로 Stop은 자연 no-op. (자체 `rewrite_state` inline strip은 last_dispatched 갱신과 결합 — 본 PR 범위 밖, 기존 중복 인정·확대 안 함.) |
| `hooks/pending-review-reminder.py` | 무변경 | `pending_review` 부재 시 자연 no-op. |
| `scripts/approve_handoff.sh` | 편집 | dir `rm -rf` → `python3 suppress_state.py add <sid> <raw_spec_path>` 호출(내부서 정규화+strip_pending+add). dir는 SessionEnd/GC가 청소. spec_path-missing exit 1 불변. "idempotent by statelessness" 주석 → "idempotent by set-membership(AC4)" 갱신. |

### 5.4 동작 흐름

- **취소**: `/spec-distill:cancel-review` → 현재 pending strip + 키 suppress →
  이번 턴 Stop·다음 턴 reminder·이후 edit 모두 no-op.
- **완료**: approve_handoff가 pending strip + 승인 키 suppress → 승인 문서 재편집
  시에도 재nag 없음.
- **재리뷰**: `--reset <path>`로 키 제거, 또는 *다른* 경로의 새 문서가 자동 arm,
  또는 reviewing-spec 직접 호출.
- **새 세션**: SessionEnd가 dir 삭제 → 다음 세션은 stale suppression 없이 시작.

### 5.5 모듈 표면 & advisory (round-1 리뷰 반영)

**`suppress_state.py` — 단일 책임**: 키 정규화 + suppression set 조작 + pending strip.
정규화·파싱이 이 한 파일에만 존재(C4 single source — 이슈 d17201ad·e1fceb30 해소).

- **Python API** (validator·cancel_review가 import):
  - `canonical_key(raw_path) -> str | None` — PREFIX 이후 substring, 스코프 밖이면 None.
  - `state_file_for(sid) -> Path` — `state_path.state_root()/sid/state.local.md`
    (sid→state_file 해석 단일화 — 호출자 중복 제거).
  - `is_suppressed(state_file, raw_path) -> bool`
  - `add(state_file, raw_path) -> None` — 멱등. 파일 부재 시 frontmatter+블록 생성.
    내부서 canonical_key로 정규화.
  - `remove(state_file, raw_path) -> None` — 멱등.
  - `strip_pending(body) -> str` — `pending_review` 블록 제거(validator가 import).
- **CLI** (approve_handoff.sh 등 bash 호출자):
  `python3 suppress_state.py {add|remove|is-suppressed} <sid> <raw_path>`. 내부서
  `state_file_for(sid)` → API 호출. **인자 순서 고정: `<sid>` 먼저, `<raw_path>` 다음**
  (이슈 42003e22 해소). is-suppressed는 exit 0(suppressed)/1(아님)로 반환.

**validator suppress 분기 advisory**(이슈 da7c35b6 해소) — `is_suppressed` 참이면 현행
validator 말미의 "Reviewer will be dispatched" 출력을 방출하지 *않고* 아래로 교체 후
early return 0:
- `additionalContext`: `[spec-distill] <key> review suppressed this session (cancel-review/approved) — arm skipped. Re-enable: /spec-distill:cancel-review --reset <key>`
- `systemMessage`: `[spec-distill] <mode> arm suppressed for <key>`
- stderr: 동일 advisory 1줄.

## 6. Acceptance Criteria

- **AC1**: `cancel_review.py`가 `pending_review` 존재 시 그것을 strip하고 정규화 키를
  `suppressed_paths`에 추가한다.
- **AC2**: `cancel_review.py <path>`가 pending 부재 시 state(필요하면 신규 생성)에 키를
  추가한다(pre-emptive suppress).
- **AC3**: pending 부재 + 인자 부재 → 상태 변경 없이 advisory만 출력(exit 0).
- **AC4**: 멱등 — 같은 문서에 cancel 2회 → `suppressed_paths` 항목 1개.
- **AC5**: `--reset <path>`가 키를 제거한다. 부재 키 reset → advisory no-op.
- **AC6**: `DEVBREW_DISABLE_SPEC_DISTILL=1` → cancel_review no-op + advisory.
- **AC7**: session_id 미해석/charset 실패 → 상태 변경 없이 loud stderr.
- **AC8**: 스코프 밖 경로(prefix 없음) → 거부 + advisory, 상태 변경 없음.
- **AC9**: validator — 문서 키 ∈ `suppressed_paths`면 `write_state` skip, `pending_review`
  미생성, advisory 방출, return 0.
- **AC10**(경계): validator — suppressed 문서도 Layer 1은 실행. 구조 실패는 여전히
  exit 2로 차단(NG1 검증).
- **AC11**: `suppressed_paths`가 *다른* 비-suppressed 문서의 `write_state` 사이클
  이후에도 보존된다(pending strip이 clobber하지 않음).
- **AC12**: approve_handoff가 승인 키를 `suppressed_paths`에 기록 + `pending_review`
  strip + 세션 dir를 삭제하지 않음. 재실행 멱등.
- **AC13**: approve_handoff의 spec_path-missing 경로 불변(exit 1, suppress 미기록,
  state 보존).
- **AC14**: state에 두 블록(pending + suppressed)이 공존할 때 round-trip 파싱이
  깨지지 않음 — 보존 근거는 0-indent 헤더가 strip 정규식을 멈추는 것(C3, 빈 줄은 선택).
- **AC15**: 새 세션 SessionEnd cleanup이 dir를 삭제 → suppression이 세션 간 누출되지
  않음.
- **AC16**: plugin.json = 0.14.0, CHANGELOG `[0.14.0]`, README(커맨드·Hooks Installed·
  Principles Instantiated) 동기화.
- **AC17**: 키 정규화·strip 로직이 `suppress_state.py` 한 곳에만 존재(bash·cancel_review·
  validator는 raw 경로 위임) — 다른 파일에 PREFIX-slice 중복 없음(grep 검증).
- **AC18**: validator suppress 분기는 기존 "Reviewer will be dispatched" 출력을 방출하지
  않고 전용 suppress advisory로 교체 + early return(이중 출력 없음).
- **AC19**(경계): `cancel_review.py <path>`에서 `<path>`가 *현재 pending과 다른 문서*일 때
  그 pending을 strip하지 않고 보존함을 `test_cancel_review.py`가 명시 커버(round-2 reviewer
  지적 — §5.3 "같은 키일 때만 strip" 로직의 경계).

## 7. Files to Modify

신규:
- `plugins/spec-distill/scripts/suppress_state.py`
- `plugins/spec-distill/scripts/cancel_review.py`
- `plugins/spec-distill/commands/cancel-review.md`
- `plugins/spec-distill/tests/test_cancel_review.py`

편집:
- `plugins/spec-distill/hooks/spec-write-validator.py` (is_suppressed 게이트)
- `plugins/spec-distill/scripts/approve_handoff.sh` (rm → strip+suppress)
- `plugins/spec-distill/.claude-plugin/plugin.json` (0.14.0)
- `plugins/spec-distill/CHANGELOG.md` (`[0.14.0]`)
- `plugins/spec-distill/README.md` (커맨드·Hooks·Principles)
- `plugins/spec-distill/tests/test_spec_write_validator.sh` (suppressed→skip 케이스)
- `plugins/spec-distill/tests/test_approve_handoff.sh` (strip+suppress·dir 보존)
- `plugins/spec-distill/tests/test_readme_sync.sh` (필요 시 커맨드 목록 동기화)

## 8. Verification Plan

- **단위/통합**: §6 AC를 커버하는 `test_cancel_review.py`(`-m unittest`),
  확장된 `test_spec_write_validator.sh`·`test_approve_handoff.sh`.
- **전체 스위트**: repo root에서 spec-distill 테스트 전부 green(작업 전 baseline 캡처).
- **수동 e2e**: ① design 문서 write→arm 확인 → `/spec-distill:cancel-review` → 턴
  종료 시 Stop dispatch 없음 확인. ② approve 흐름 → 같은 문서 재편집 → 재arm 없음
  확인. ③ `--reset` → 재편집 → 재arm 확인.
- **Law 2 dogfood**: 본 design 문서 자체가 PostToolUse arm을 발생시키므로,
  reviewing-spec reviewer가 본 설계를 리뷰한다.

## 9. Rejected Alternatives

- **콘텐츠-해시 게이팅**(NG2): 정규화 해시 변경 시만 재arm. 그러나 supersede 포인터
  같은 문서 편집도 *실제 콘텐츠를 바꾸므로* 해시가 달라져 재arm된다 → 증상 A를
  해소 못 함. "material"의 정의가 휴리스틱·취약하고 결정론을 약화.
- **세션 전체 pause 토글**: `review_paused` 플래그로 나머지 세션 전체 no-op. 코드는
  최단순이나 그 세션의 *새* 문서 리뷰까지 죽이고 per-doc "settled"를 표현 못 함 —
  env kill switch와 사실상 동급으로 무딤.
- **doc frontmatter 마커**: 승인 시 design 문서 자체에 `review_status: approved`를
  써넣음. dir 삭제와 무관하게 생존하나, **사용자 문서를 훅이 침습적으로 편집**(persona/
  문서 편집은 보안-민감 — CLAUDE.md)하는 단점.
- **UserPromptSubmit NL 감지**(NG3): "스펙 리뷰 그만"을 훅이 인식. 마찰은 적으나
  fragile·false-trigger·비결정론적.
- **env-only(현 상태)**: 전역이고 env 직접 설정 필요, GC 24h — 증상 B를 가볍게
  해소 못 함.

## Handoff Context

**TL;DR**: spec-distill 리뷰 상태머신에 per-doc·session-scoped `suppressed_paths`를 추가해
(A) 리뷰 완료 후·(B) 중단 요청 후 같은 design 문서 재편집 시 reviewing-spec가 재dispatch되는
문제를 해소. 취소(`/spec-distill:cancel-review`)와 완료(approve_handoff)가 같은 집합에 기록,
PostToolUse가 arm 직전 조회. 정규화·strip·suppress는 `suppress_state.py` 단일 소스.

**Implicit context (writing-plans가 알아야 할 것)**:
- C3 파싱 근거: `suppressed_paths:`를 0-indent 헤더로 두는 것이 보존의 핵심(2-space strip
  정규식이 0-indent에서 멈춤). round-1 reviewer 실증 확인.
- `suppress_state.py` CLI 인자 순서 `<sid> <raw_path>` 고정, 정규화는 내부 단일 구현(§5.5).
- approve_handoff.sh `rm -rf` → strip+suppress 전환 이유: 삭제하면 "승인됨" 기억이 사라져
  증상 A 재발. dir cleanup은 SessionEnd/GC로 이관.
- validator는 suppress 분기에서 기존 "Reviewer will be dispatched" 출력을 전용 advisory로
  *교체*(이중 방출 금지).
- Layer 1(구조 검증)은 suppression과 직교 — 우회 안 함(NG1·AC10). Layer 1 실패는 suppress
  체크 *이전* exit 2.

**Deferred to plan**:
- `test_readme_sync.sh`가 커맨드 목록을 강제하는지 확인 후 필요 시 갱신.
- review-dispatch.py inline strip 중복은 본 PR 범위 밖(기존 부채) — plan에서 재확인만.
- `state_file_for(sid)`의 `state_path.state_root()` 의존 — state-storage redesign(NG5)과
  인터페이스 충돌 가능성을 plan 단계에서 확인(round-2 reviewer advisory).
- 구현은 main 분기 워크트리 `feature/spec-distill-cancel-suppress`.

## 10. Metadata

- **선행 작업/메모리**: spec-distill review hardening 누적(v0.7.0–v0.13.0),
  state-storage redesign(계획), documentary-edit review skip(사용자 피드백 —
  본 스펙이 그 워크플로를 메커니즘으로 승격).
- **devbrew 원칙 instantiation**: P17(사용자 주권 — 명시적 cancel/reset 게이트),
  결정론적 훅, kill switch=보안 컨트롤, Law 1 게이트 직교성(Layer 1 불변),
  Law 2 reviewer 분리 불변, design-lightness(새 P# 없이 기존 원칙 흡수).
- **구현**: main 분기 워크트리 `feature/spec-distill-cancel-suppress`(C8).
