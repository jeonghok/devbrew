---
type: design
topic: qg scope-capture self-honest verdict + transparency
plugin: quality-gates
target_version: 2.6.0
date: 2026-06-07
status: design
source_interview: docs/superpowers/interview/2026-06-07-qg-scope-capture-interview.md
related:
  - plugins/quality-gates/scripts/check-review-scope.sh            # 신규 — 결정론 scope 신호
  - plugins/quality-gates/tests/test_check_review_scope.sh         # 신규 — 단위 테스트
  - plugins/quality-gates/skills/quality-pipeline/SKILL.md         # redirect 게이트 + 정직 floor + runtime 라인
  - plugins/quality-gates/scripts/check-trivia.sh                  # 형제 패턴 참조(무변경)
  - plugins/quality-gates/scripts/pre-pipeline-check.sh            # scope 해석 선행(무변경)
  - plugins/quality-gates/scripts/detect-runtime.sh               # runtime manifest 데이터원(무변경)
  - plugins/quality-gates/hooks/post-tool-use-session-tracker.py  # files.md 생산자(무변경)
  - plugins/quality-gates/commands/qg.md                          # kill switch + scope 문서
  - plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh  # anchor grep
  - plugins/quality-gates/.claude-plugin/plugin.json              # 2.5.0 → 2.6.0
  - plugins/quality-gates/CHANGELOG.md                            # [2.6.0]
  - plugins/quality-gates/README.md                              # Scope + Principles Instantiated
  - docs/philosophy/devbrew-harness-philosophy.md                # P8 흡수(새 P# 없음)
---

# qg scope-capture — self-honest verdict + scope transparency (v2.6.0)

> qg verdict가 *사용자가 검토받았다고 믿는 scope*가 아니라 *qg가 resolve한 scope*를
> 반영하면서 둘이 silent하게 발산할 수 있다 — 가장 날카롭게는 커밋 후 빈 세션에서
> "clean"이 나오는 false-clean. 이 설계는 (1) "변경 있는데 resolved scope=0"을 결정론으로
> 탐지해 거짓 "clean"을 구조적으로 막는 **정직-verdict floor**와, (2) 그 위에 깨진
> 케이스에서만 1클릭으로 branch 리뷰를 제안하는 **redirect 게이트**, (3) Runtime이
> Review와 달리 항상 full-project로 돈다는 사실을 실행 전 드러내는 **transparency 한 줄**을
> 더한다. 정상 경로(scope>0, 또는 진짜 변경 없음)는 침묵·zero-click 유지.

## 목차

- [1. Context / Why](#1-context--why)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. Constraints](#4-constraints)
- [5. Architecture](#5-architecture)
  - [5.1 결정론 신호 — `check-review-scope.sh`](#51-결정론-신호--check-review-scopesh)
  - [5.2 소비자 A — redirect 게이트](#52-소비자-a--redirect-게이트)
  - [5.3 소비자 B — 정직-verdict floor](#53-소비자-b--정직-verdict-floor)
  - [5.4 Runtime transparency 라인](#54-runtime-transparency-라인)
- [6. Acceptance Criteria](#6-acceptance-criteria)
- [7. Files to Modify](#7-files-to-modify)
- [8. Verification Plan](#8-verification-plan)
- [9. Rejected Alternatives](#9-rejected-alternatives)
- [10. Open Questions](#10-open-questions)
- [11. Concrete Next Action](#11-concrete-next-action)
- [12. Metadata](#12-metadata)

## 1. Context / Why

qg의 Review 게이트는 기본 **session scope**로 돈다. `post-tool-use-session-tracker.py`가
이번 세션에서 Edit/Write한 파일을 **session-id별** `.claude/quality-gates/<sid>/files.md`에
누적하고, Review 게이트가 그 목록을 리뷰 대상으로 삼는다.

**false-clean의 코드 경로(근본 문제):**

1. 세션에서 파일 편집 → `/qg` → 리뷰 → 커밋 → **새 세션** 시작.
2. 새 세션은 새 session-id라 `files.md`가 아예 없음 → resolved scope = **0 파일**.
3. `check-trivia.sh`는 **working tree만** 본다(`git diff HEAD` + untracked). 커밋 후엔
   working tree가 clean → trivia 아님 → Review 게이트 진입.
4. Review 게이트가 0개 파일에 reviewer를 돌림 → findings 없음 →
   `## Review gate iter N: clean`.
5. **칼날:** 브랜치는 base보다 N커밋 앞서 있는데(한 번도 이번 세션에서 검토 안 됨)
   verdict는 "clean". v2.5.0 transparency 한 줄이 `session (0 files)`를 찍지만 *verdict
   자체*는 여전히 "clean"이라 사용자는 "내 코드 검토됐고 깨끗"으로 읽는다.

**핵심 구분선(이 작업 전체의 칼날):**

- **"변경 없음 → clean"** = 진짜 아무 변경도 없음(clean tree, 브랜치 base와 동일, 빈 세션).
  idempotent graceful no-op. **정상 — 건드리지 않는다.**
- **"변경 있는데 resolved scope=0 → clean"** = 의도 scope ≠ resolved scope의 silent 발산.
  **false-clean — 유일한 정직성 문제.**

업계 관례상 리뷰 scope 기본값은 merge-base diff(브랜치/PR 변경분)이고(CodeRabbit, Codex/Claude
`/code-review`), empty-diff false-pass는 인정된 anti-pattern이다("시스템이 할 일이 있다고
판단했으면 '한 일 없음'이 완료로 카운트되면 안 된다"). 그러나 이 repo에서 결정론을
convenience/routing에 쌓는 것은 '옥죄기'로 폐기된 history가 있고(P8 determinism-economy,
harness-lightness), 기본값을 강제 branch로 바꾸면 개발 중 빠른 피드백 UX를 파괴한다. 따라서
**기본값은 session 유지**, 결정론은 "검토 안 한 걸 clean이라 하지 않기"라는 **정확성 floor**
한 점에만 적용한다.

(전체 문제공간 분석·steelman·landscape 인용은 `source_interview` brief 참조.)

## 2. Goals

- **G1 (정직-verdict floor):** resolved scope에서 실제 검토한 파일이 0인데 변경이 존재하면
  qg는 "clean"이라 말하지 않는다. 결정론적·load-bearing(P8). 게이트가 우회돼도 불변.
- **G2 (redirect 게이트):** false-clean을 탐지하면, 깨진 케이스에서만 1클릭으로 "branch
  diff를 리뷰할까?"를 제안한다. P17 redirect 가능(hard block 아님).
- **G3 (Runtime transparency):** Runtime이 *무엇을·어떻게* 검증하는지 + *Review scope와 무관하게
  full-project로 돈다*는 비대칭을 실행 전 한 줄로 드러낸다.
- **G4 (lightness 보존):** 정상 경로(scope>0) / 진짜 no-op(변경 없음)은 추가 클릭·마찰 0.
  새 게이트는 verdict가 거짓이 될 케이스에서만 발화.
- **G5 (격리·테스트성):** 탐지 로직은 read-only 스크립트 하나로 격리해 독립 단위 테스트.
  orchestrator는 신호에 분기만(Law 1 — 계산은 스크립트, 분기는 SKILL).

## 3. Non-goals

- **NG1:** session 기본값을 branch/PR-diff로 바꾸지 않는다(빠른 피드백 UX). `/qg branch`는
  명시 escape hatch로 유지.
- **NG2:** generic empty-scope hard block을 만들지 않는다. floor는 *라벨 정직성*이지 *차단*이
  아니다(redirect 가능).
- **NG3:** Runtime을 변경 diff-scope로 강제하지 않는다. Review↔Runtime 비대칭은 본질(앱
  부팅엔 전체 앱 필요)이며 유지. Runtime 변경은 **순수 additive 한 줄**뿐 — 새 게이트·동작
  변경 없음.
- **NG4:** 진짜 no-op("변경 없음 → clean") 경로의 verdict·문구를 바꾸지 않는다(brief "전자는
  두지만" — scope creep 차단).
- **NG5:** 새 P# 신설하지 않는다. floor는 P8 determinism-economy에 흡수(design-lightness).
- **NG6:** 자연어 scope 의도("전체 PR", "지금 브랜치") 파싱용 결정론 토큰 parser를 만들지
  않는다. non-load-bearing routing은 모델 신뢰(P8) — 결정론적 보장은 `/qg branch`에만.

## 4. Constraints

- **C1 (Law 2):** reviewer persona 파일(`agents/*.md`) 미편집. orchestrator는 user-consented
  Review fix에만 Edit. 이 작업은 persona 무변경.
- **C2 (P8 determinism-economy):** 결정론은 정확성 floor(G1) 한 점에만. redirect 게이트(G2)·
  runtime 라인(G3)·자연어 routing은 모델 신뢰/UX. floor만 kill 불가.
- **C3 (kill switch):** redirect 게이트는 `DEVBREW_QG_DISABLE_SCOPE_REDIRECT=1`로 끌 수
  있다(advisory-only 강등). 단 floor(G1)는 correctness라 kill 불가(security-gate와 동일 격).
- **C4 (read-only 신호 스크립트):** `check-review-scope.sh`는 파일을 생성/수정/삭제하지
  않는다(`detect-runtime.sh`와 동일 보장). git 상태만 읽음.
- **C5 (fail-open):** git 부재/detached HEAD/merge-base 없음/shallow 등 불확실 상태는
  `degraded`로 fail-open → 게이트 미발화(happy-path 마찰 0). 확신할 때만 발화 → false-positive
  차단.
- **C6 (단일 base 진실원):** `branch_ahead_count`가 세는 diff와 redirect "Review branch diff"가
  실제 리뷰하는 diff는 **동일 base**(merge-base)를 써야 한다 — 표시된 "M files ahead"와
  실제 검토 대상이 일치해야 정직.
- **C7 (단일 턴·단일 dispatch):** v2.0.0 파이프라인 규칙 유지 — setup/check-trivia 1회,
  Stop hook·continuation sentinel 없음. 신규 스크립트도 preflight/Review-iter-1에서 1회 호출.
- **C8 (플러그인 shape):** plugin.json SemVer bump(2.5.0→2.6.0), CHANGELOG, README Principles
  Instantiated 갱신(모든 PR 필수).

## 5. Architecture

설계의 핵심: **하나의 결정론 신호, 두 소비자.** 탐지 로직을 SKILL 프롬프트에 흩뿌리지 않고
read-only 스크립트 하나로 격리하고, 그 신호를 (A) redirect 게이트와 (B) 정직-verdict floor가
소비한다. 신호원이 하나라 둘이 절대 발산하지 않는다.

```
                         ┌─────────────────────────────┐
                         │  check-review-scope.sh       │  (신규, read-only)
  scope mode (session/   │                              │
   branch/paths) ──────▶ │  resolved_count              │
  session files.md ────▶ │  branch_ahead_count          │── signal: ─────────┐
  git (merge-base/diff)  │  worktree_dirty              │  empty_scope_with_  │
                         └─────────────────────────────┘  changes|normal|    │
                                                           genuine_noop|      │
                                                           degraded            │
                         ┌──────────────────────────────────────────────────┘
                         ▼
   ┌────────────────────────────────┐     ┌────────────────────────────────┐
   │ 소비자 A: redirect 게이트       │     │ 소비자 B: 정직-verdict floor    │
   │ (Review iter 1, scout 이전)     │     │ (verdict 방출부, Step 4.5)      │
   │ signal==empty_scope_with_changes│     │ resolved_count==0 & 변경 존재   │
   │  → AskUserQuestion 발화         │     │  → "no scope reviewed … NOT     │
   │    (kill switch로 끌 수 있음)   │     │     certified clean" (결정론)   │
   └────────────────────────────────┘     └────────────────────────────────┘
       UX 층 (P17, redirect 가능)              correctness 층 (P8, kill 불가)
```

### 5.1 결정론 신호 — `check-review-scope.sh`

신규 read-only 스크립트(`check-trivia.sh`·`detect-runtime.sh`와 형제 패턴: structured stdout,
SKILL이 분기). **단일 책임:** "resolved review scope가 비었는데 검토할 변경이 존재하는가?"

**입력(인자/env):**
- scope mode: `session` | `branch` | `paths`(SKILL이 preflight 해석 결과로 전달).
- `CLAUDE_CODE_SESSION_ID`(→ `.claude/quality-gates/<sid>/files.md` 위치).
- paths mode면 glob 목록.

**base 해석(C6 단일 진실원):**
```
base = 첫 번째로 가능한 것:
  git symbolic-ref --short refs/remotes/origin/HEAD  → "origin/" strip
  → "main"(존재 시) → "master"(존재 시)
merge_base = git merge-base "$base" HEAD
branch_ahead_count = git diff --name-only "$merge_base"..HEAD | wc -l
```
(redirect "Review branch diff" 경로의 리뷰 대상도 이 `merge_base..HEAD`와 동일해야 함 — C6.)

**계산:**
- `resolved_count`: session mode면 `files.md`의 `- ` 항목 수; paths mode면 glob 매칭 + 변경된
  파일 수; branch mode면 `branch_ahead_count`.
- `worktree_dirty`: `git diff HEAD --name-only` 비어있지 않음 OR untracked(exclude-standard)
  존재면 `yes`.
- `changes_exist` = `branch_ahead_count > 0` OR `worktree_dirty == yes`.

**출력(structured stdout):**
```
resolved_count: <N>
branch_ahead_count: <M>
worktree_dirty: yes|no
base: <branch-name>
signal: empty_scope_with_changes | normal | genuine_noop | degraded
```

**신호 결정:**
| 조건 | signal | 발화? |
|---|---|---|
| `resolved_count==0` AND `changes_exist` | `empty_scope_with_changes` | ✅ 게이트+floor |
| `resolved_count==0` AND NOT `changes_exist` | `genuine_noop` | ❌ 침묵(NG4) |
| `resolved_count>0` | `normal` | ❌ 침묵(기존 동작) |
| git 부재/detached/merge-base 없음/shallow/오류 | `degraded` | ❌ fail-open(C5), loud advisory 1줄 |

**exit code:** 0 = ok(신호 파싱); 비정상 환경은 `signal: degraded` + exit 0(fail-open, SKILL이
no-gate 처리). `detect-runtime.sh`의 graceful-degradation 규율과 동일.

### 5.2 소비자 A — redirect 게이트

Review 게이트 iter 1에서 **scope 해석 + v2.5.0 transparency 한 줄 직후, scout dispatch 이전**에
`check-review-scope.sh` 호출. `signal == empty_scope_with_changes`이고 kill switch
미설정이면 `AskUserQuestion` 발화.

**고유 anchor 구절:** 질문 본문에 리터럴 `review scope is empty` 포함(SKILL 내 타 decision-tool
호출과 충돌 없음 — `findings remain`/`both gates`/`Runtime verifier needs`와 같은 격의 protocol
anchor. orchestration grep 테스트로 존재·고유성 검증).

```
AskUserQuestion({
  questions: [{
    question: "Review scope is empty (session: 0 files) but the branch is <M> files
               ahead of <base>. These changes were never reviewed this session.
               What should I review?",
    header: "Review scope",
    options: [
      {label: "Review branch diff (recommended)",
       description: "merge-base(<base>)..HEAD 변경분을 리뷰. scope=branch로 재해석 후 정상 진행."},
      {label: "Proceed (honest-empty, not clean)",
       description: "리뷰어 dispatch 건너뛰고 정직 verdict 직행 — 'no scope reviewed, NOT clean'."},
      {label: "Stop",
       description: "정직 요약으로 파이프라인 중단. /qg branch로 재실행 권장."}
    ],
    multiSelect: false
  }]
})
```

**분기:**
- **Review branch diff** → scope=branch로 재해석(`merge_base..HEAD`), scout부터 정상 진행. 이후
  iteration은 기존과 동일.
- **Proceed (honest-empty)** → scout/reviewer dispatch 건너뜀(0개 파일에 리뷰어 돌리는 낭비
  회피) → 5.3 정직 verdict 직행 → 다음 게이트/요약.
- **Stop** → 정직 요약으로 중단(aborted at Review gate).

**kill switch:** `DEVBREW_QG_DISABLE_SCOPE_REDIRECT=1` → 게이트 생략, advisory 한 줄만 출력
(`> [quality-gates] review scope empty but branch <M> ahead — redirect gate disabled; floor still applies.`)
→ 그대로 진행하되 floor(5.3)가 verdict를 잡음. devbrew kill-switch 규범 충족(C3).

### 5.3 소비자 B — 정직-verdict floor

결정론 backstop. verdict 방출부(현재 SKILL Review 게이트 **Step 4.5**의 `kept=0 & suppressed=0`
분기)에서, `check-review-scope.sh` 신호가 `empty_scope_with_changes`이면(= `resolved_count==0
& changes_exist`) 라벨을 honest로 교체:

- 기존: `## Review gate iter N: clean`
- floor: `## Review gate iter N: no scope reviewed (0 files; branch <M> ahead of <base>) — NOT certified clean.`

이 분기는 redirect 게이트와 **동일 신호원**을 소비하므로 발산 불가. 게이트가 어떤 이유로든
(kill switch / AskUserQuestion 부재 / "Proceed honest-empty" 선택) 우회돼도 거짓 "clean"은
구조적으로 불가 = G1 load-bearing(P8). `normal`/`genuine_noop` 경로의 `clean`/transparency
문구는 **무변경**(NG4).

최종 요약(Final Summary)의 `Review gate:` 줄도 honest-empty 케이스를 그대로 반영
(`no scope reviewed (branch <M> ahead)` 등).

### 5.4 Runtime transparency 라인

순수 additive 한 줄(LD3 — 새 게이트·diff-scope 강제·동작 변경 전무, NG3). Review의
`> Review scope: session (N files)`와 대칭.

```
> Runtime scope: full project (<project_type>) — boots <surface 요약>, asserts <K> spec AC.
  Runtime runs the whole app regardless of Review scope.
```

- **마지막 절 `regardless of Review scope` = OQ4 비대칭 명시**(리터럴, grep 검증).
- **데이터원(새 계산 없음):** `detect-runtime.sh` manifest(`project_type` +
  `runnable_surfaces`/`test_runners` 요약) + spec AC 개수(R2 `discover-spec`에서 이미 수집).
  `<K>` = spec AC 수(spec 없으면 `0 spec AC (smoke fallback)`).
- **발화 지점(기존 surface 확장, 새 surface 없음 — OQ3):** Runtime 게이트 도달 *모든* 경로에서
  dispatch 직전 1회:
  - Decision 2 발화 경로(`requires_decision` surface 존재) → 질문 직전.
  - Decision 2 zero-click 경로(현재 "print a one-line plan and proceed zero-click"의 그 줄) →
    이 줄로 구체화.
  - 단일 게이트 `/qg runtime`의 Step R-init → 동일.

## 6. Acceptance Criteria

- **AC1:** `check-review-scope.sh`는 `resolved_count==0` AND (`branch_ahead_count>0` OR
  `worktree_dirty`)일 때 `signal: empty_scope_with_changes`를 emit한다.
- **AC2:** `resolved_count==0` AND 변경 전무일 때 `signal: genuine_noop`을 emit한다.
- **AC3:** `resolved_count>0`일 때 `signal: normal`을 emit한다.
- **AC4:** git 부재/detached HEAD/merge-base 없음/shallow일 때 `signal: degraded` + exit 0
  (fail-open)을 emit하고, SKILL은 이를 no-gate(redirect·floor 미발화)로 처리한다.
- **AC5:** `check-review-scope.sh`는 파일을 생성/수정/삭제하지 않는다(read-only — 실행 전후
  `git status --porcelain` + working tree 불변).
- **AC6:** SKILL Review 게이트 iter 1은 `signal==empty_scope_with_changes` AND kill switch
  미설정일 때만 redirect `AskUserQuestion`을 발화하며, 그 질문에 리터럴 `review scope is empty`가
  있고, 이 구절은 SKILL 내 다른 어떤 decision-tool 호출에도 없다(고유).
- **AC7:** redirect 게이트 3옵션이 명세대로 분기한다 — "Review branch diff"→scope=branch 재해석
  후 진행; "Proceed (honest-empty)"→리뷰어 skip + 정직 verdict; "Stop"→정직 요약 중단.
- **AC8 (floor, 결정론):** `resolved_count==0 & changes_exist`이면 Review verdict 라벨은
  `no scope reviewed … NOT certified clean`이며 절대 `clean`이 아니다. 이는 redirect 게이트와
  독립적으로 verdict 방출부에서 보장된다(게이트 우회·kill switch에도 불변).
- **AC9:** `DEVBREW_QG_DISABLE_SCOPE_REDIRECT=1`이면 redirect 게이트는 발화하지 않되(advisory
  한 줄), floor(AC8)는 여전히 적용된다.
- **AC10 (무회귀):** `normal`/`genuine_noop` 경로는 추가 클릭 없이 기존 verdict("clean")·
  transparency 문구를 그대로 유지한다.
- **AC11:** Runtime 게이트에 도달하는 모든 경로(Decision 2 발화/zero-click, 단일 `/qg runtime`
  R-init)는 dispatch 직전 transparency 라인을 출력하며, 그 라인에 리터럴 `regardless of Review
  scope` + `project_type` + spec AC 수가 포함된다.
- **AC12 (Runtime 무변경):** Runtime은 여전히 full-project로 돌고 diff-scope 강제·새 게이트가
  없다(라인은 additive). 단일 게이트 `/qg runtime` 동작 불변(라인 추가 외).
- **AC13:** `branch_ahead_count`가 세는 diff와 "Review branch diff" 리뷰 대상이 동일 base
  (merge-base)를 쓴다(C6 — 표시 M == 실제 검토 대상).
- **AC14:** plugin.json `2.6.0`, CHANGELOG `## [2.6.0] — 2026-06-07`, README Scope +
  Principles Instantiated 갱신, philosophy P8에 floor 한 문장 흡수(새 P# 없음).

## 7. Files to Modify

| 파일 | 변경 |
|---|---|
| `plugins/quality-gates/scripts/check-review-scope.sh` | **신규** — 결정론 신호(§5.1) |
| `plugins/quality-gates/tests/test_check_review_scope.sh` | **신규** — AC1–AC5,AC13 fixture 단위 테스트 |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | allowed-tools에 `check-review-scope.sh` 추가; Review iter 1에 redirect 게이트(§5.2, AC6/AC7); Step 4.5에 floor 라벨(§5.3, AC8); Runtime 3지점 transparency 라인(§5.4, AC11); kill switch 분기(AC9) |
| `plugins/quality-gates/commands/qg.md` | Quick Reference에 `DEVBREW_QG_DISABLE_SCOPE_REDIRECT=1` 행 + Scope 섹션 한 줄(floor/redirect 설명) |
| `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` | redirect anchor(`review scope is empty`) 존재·고유성 + Runtime 라인(`regardless of Review scope`) grep(AC6/AC11) |
| `plugins/quality-gates/.claude-plugin/plugin.json` | `2.5.0` → `2.6.0` (AC14) |
| `plugins/quality-gates/CHANGELOG.md` | `## [2.6.0] — 2026-06-07` (Added: floor/redirect/runtime line; Changed: empty-scope verdict label) |
| `plugins/quality-gates/README.md` | Scope 설명 + Principles Instantiated에 P8 floor 한 줄 |
| `docs/philosophy/devbrew-harness-philosophy.md` | P8 determinism-economy에 self-honest verdict floor 한 문장 흡수(새 P# 없음) |

## 8. Verification Plan

- **단위(신규):** `tests/test_check_review_scope.sh` — git fixture 4종으로 AC1–AC5,AC13:
  - 빈 세션(`files.md` 없음/0항목) + 브랜치 base보다 앞섬 → `empty_scope_with_changes`.
  - session `files.md` ≥1항목 → `normal`.
  - 빈 세션 + 변경 전무(clean tree, 브랜치 base와 동일) → `genuine_noop`.
  - merge-base 없음(무관 root) / shallow → `degraded` + exit 0 (fail-open).
  - read-only 확인: 실행 전후 `git status --porcelain` 동일(AC5).
- **orchestration grep:** `test_skill_orchestration_behavior.sh` 확장 — redirect anchor
  `review scope is empty` 1회 존재 + 타 decision-tool 미포함(고유); Runtime 라인
  `regardless of Review scope` 존재(AC6/AC11/AC14 anchor).
- **수동 e2e(스크립트화 곤란 — 메모리 V10 패턴):**
  1. 파일 편집→커밋→**새 세션**→`/qg` → redirect 게이트 발화 확인(AC6), 3옵션 각각 분기
     (AC7); "Proceed honest-empty" 선택 시 verdict가 `NOT certified clean`(AC8).
  2. `DEVBREW_QG_DISABLE_SCOPE_REDIRECT=1`로 재실행 → 게이트 없이 advisory + floor 적용(AC9).
  3. 진짜 no-op(clean tree, 브랜치 base와 동일) `/qg` → 침묵·기존 clean(AC10).
  4. web 프로젝트에서 Runtime 도달 → transparency 라인 + `regardless of Review scope`(AC11).
- **baseline:** 작업 전 repo root에서 기존 테스트 baseline 캡처(메모리: main에 8개 stale red —
  codex/consent/security/sandbox 환경의존, 작업과 무관 확인). 테스트는 repo root에서 실행.
- **Law 2:** persona(`agents/*.md`) diff 없음 확인(C1).

## 9. Rejected Alternatives

- **강제 branch/PR-diff 기본값 전환** → 버림. 개발 중 빠른 피드백(좁은 '방금 한 작업' scope)
  파괴 + 무거운 기본값이 인지부하·friction↑·채택률↓(brief §5, steelman ①④⑤). session 유지(NG1).
- **generic empty-scope hard block(전면 차단)** → 버림. 이 repo '옥죄기' 폐기 패턴 +
  idempotent no-op은 올바름. "변경 있는데 scope=0"만 좁게 잡는 redirect 게이트+floor로 대체(NG2).
- **Runtime을 변경 diff-scope로 강제** → 버림. 앱 부팅엔 전체 앱 필요 — 비대칭은 본질. additive
  transparency만(NG3).
- **Advisory-only(redirect 질문 없음)** → 버림. 사용자가 redirect 게이트 채택(이 세션 Q) —
  자동 교정 제안이 가치, 깨진 케이스에서만 1클릭이라 lightness 위배 아님.
- **탐지 로직을 `pre-pipeline-check.sh` 확장/SKILL 인라인** → 버림. pre-pipeline은
  staleness/branch-mismatch state mutation 책임 — scope-vs-changes 탐지를 섞으면 책임 혼탁. 새
  read-only 스크립트가 단일 책임·독립 테스트(G5).
- **no-op "clean"을 "nothing to review"로 변경** → 버림. brief "전자는 두지만" 명시 —
  scope creep. 진짜 no-op verdict는 무변경(NG4).
- **새 P# 신설** → 버림. floor는 P8 determinism-economy의 직접 사례 — 흡수(NG5,
  design-lightness).

## 10. Open Questions

- **OQ-A(구현 세부, 차단 아님):** `branch_ahead_count` diff와 scope=branch 리뷰 대상의 base
  parity(C6/AC13)는 `check-review-scope.sh`가 base를 정의하고 SKILL의 branch-scope 경로가 그
  값을 재사용하는 형태로 writing-plans에서 확정. 현 SKILL은 단일 canonical base resolver가
  없으므로(qg.md "vs main"), 신규 스크립트가 단일 진실원이 된다.
- **OQ-B(범위 밖):** session tracker가 *이번 세션 밖*에서 편집된 파일(다른 세션·외부 에디터)을
  못 잡는 더 넓은 문제는 이 작업 범위 밖 — floor가 `worktree_dirty`로 부분 포착하나 근본
  해결(브랜치 기준 항상 비교)은 NG1과 충돌하므로 의도적으로 다루지 않음.

## 11. Concrete Next Action

이 design을 spec-distill:reviewing-spec(Law 2 분리 reviewer)이 검증 → 통과 시 writing-plans로
구현 계획 작성. writing-plans는 §7 Files to Modify를 task로 분해하고 §6 AC를 검증 단위로 매핑.
구현은 subagent-driven 엄격 순차(메모리: 병렬·투기적 dispatch 금지, evidence-before-approved).

## 12. Metadata

- **target_version:** 2.6.0 (minor — 새 surface: redirect 게이트 + 신규 스크립트 + honest 라벨
  + runtime 라인).
- **source_interview:** `docs/superpowers/interview/2026-06-07-qg-scope-capture-interview.md`
  (LD1–LD4 기정사실, OQ1–OQ5 본 design에서 해결).
- **principles instantiated:** Law 1(계산=스크립트, 분기=SKILL), Law 2(persona 무변경), P8
  determinism-economy(floor=정확성 결정론, redirect/routing=모델 신뢰), P17(redirect 게이트=
  사용자 redirect 가능), harness-lightness(정상 경로 zero-click).
- **no new P#:** floor는 P8에 흡수.
