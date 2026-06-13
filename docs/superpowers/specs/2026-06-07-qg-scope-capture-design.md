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
  - plugins/quality-gates/scripts/discover-spec.sh               # spec AC 수 데이터원(무변경)
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
> Review와 달리 항상 full-project로 돈다는 사실을 boot 직전 드러내는 **transparency 한 줄**을
> 더한다. 정상 경로(scope>0, 또는 진짜 변경 없음)는 침묵·zero-click 유지.

## 목차

- [1. Context / Why](#1-context--why)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. Constraints](#4-constraints)
- [5. Architecture](#5-architecture)
  - [5.1 결정론 신호 — `check-review-scope.sh`](#51-결정론-신호--check-review-scopesh)
  - [5.2 호출·캐시 + 소비자 A — redirect 게이트](#52-호출캐시--소비자-a--redirect-게이트)
  - [5.3 소비자 B — 정직-verdict floor](#53-소비자-b--정직-verdict-floor)
  - [5.4 Runtime transparency 라인](#54-runtime-transparency-라인)
- [6. Acceptance Criteria](#6-acceptance-criteria)
- [7. Files to Modify](#7-files-to-modify)
- [8. Verification Plan](#8-verification-plan)
- [9. Rejected Alternatives](#9-rejected-alternatives)
- [10. Open Questions](#10-open-questions)
- [11. Concrete Next Action](#11-concrete-next-action)
- [Handoff Context](#handoff-context)
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
  full-project로 돈다*는 비대칭을 boot 직전 한 줄로 드러낸다.
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
- **NG7:** 기존 `/qg branch` 명시 경로의 base 해석 동작을 바꾸지 않는다. C6 parity는 *redirect
  "Review branch diff" 경로*에만 적용된다(같은 스크립트 run의 `base:` 재사용으로 보장) — 기존
  branch 경로와의 수렴은 권장이되 이 작업 범위 밖.

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
- **C6 (단일 base 진실원):** redirect "Review branch diff" 경로에서 표시하는 변경 수와 실제 리뷰하는
  diff는 같은 스크립트 run이 emit한 `merge_base:` 커밋 SHA에서 출발해야 한다 — base **이름**을
  orchestration 계층에서 재-resolve하지 않는다(SHA 재사용 → remote-only base fail-open 회피). redirect는
  signal을 유발한 모든 변경의 **union**(`git diff $merge_base`[working-tree inclusive] + non-ignored
  untracked)을 리뷰하므로 worktree-only trigger에서도 빈 diff를 clean으로 인증하지 않는다(review-iter4);
  표시 "M files" == 그 union count.
- **C7 (단일 턴·단일 호출):** v2.0.0 파이프라인 규칙 유지 — setup/check-trivia 1회, Stop
  hook·continuation sentinel 없음. `check-review-scope.sh`도 Review iter-1에서 **1회만** 호출하고
  결과를 SKILL-turn 변수로 캐시(§5.2).
- **C8 (플러그인 shape):** plugin.json SemVer bump(2.5.0→2.6.0), CHANGELOG, README Principles
  Instantiated 갱신(모든 PR 필수).

## 5. Architecture

설계의 핵심: **하나의 결정론 신호, 두 소비자.** 탐지 로직을 SKILL 프롬프트에 흩뿌리지 않고
read-only 스크립트 하나로 격리하고, 그 신호를 (A) redirect 게이트와 (B) 정직-verdict floor가
소비한다. 스크립트를 iter-1에서 **1회** 호출해 결과를 캐시하므로 두 소비자가 동일 값을 본다 —
발산 불가.

```
                         ┌─────────────────────────────┐
                         │  check-review-scope.sh       │  (신규, read-only)
  scope mode (session/   │                              │
   branch/paths) ──────▶ │  resolved_count              │
  session files.md ────▶ │  branch_ahead_count          │── stdout ──────────┐
  git (merge-base/diff)  │  worktree_dirty / base       │  (1회 호출,        │
                         └─────────────────────────────┘   SKILL이 캐시)     │
                                                                              │
        SKILL-turn 캐시: $scope_signal $branch_ahead_count $base ◀───────────┘
                         │                                  │
                         ▼ (Review iter-1, scout 이전)      ▼ (verdict 방출부, Step 4.5)
   ┌────────────────────────────────┐     ┌────────────────────────────────┐
   │ 소비자 A: redirect 게이트       │     │ 소비자 B: 정직-verdict floor    │
   │ signal==empty_scope_with_changes│     │ signal==empty_scope_with_changes│
   │  → AskUserQuestion 발화         │     │  → "no scope reviewed … NOT     │
   │    (kill switch로 끌 수 있음)   │     │     certified clean" (결정론)   │
   └────────────────────────────────┘     └────────────────────────────────┘
       UX 층 (P17, redirect 가능)              correctness 층 (P8, kill 불가)
```

### 5.1 결정론 신호 — `check-review-scope.sh`

신규 read-only 스크립트(`check-trivia.sh`·`detect-runtime.sh`와 형제 패턴: structured stdout,
SKILL이 분기). **단일 책임:** "resolved review scope가 비었는데 검토할 변경이 존재하는가?"

**입력(인자/env):**
- scope mode: `session` | `branch` | `paths`(SKILL이 preflight 해석 결과로 인자 전달).
- `CLAUDE_CODE_SESSION_ID`(→ `.claude/quality-gates/<sid>/files.md` 위치).
- paths mode면 glob 목록 인자.

**base 해석(C6 단일 진실원 — 존재 확인까지 고정):**
```
base(표시용 short name) / base_ref(그 ref의 git-usable 형태) = 첫 번째로 성공하는 것:
  (1) git symbolic-ref --short refs/remotes/origin/HEAD  → base="origin/" strip, base_ref=그대로(origin/main)
  (2) git rev-parse --verify --quiet refs/remotes/origin/main   → base="main",   base_ref="origin/main"
  (3) git rev-parse --verify --quiet refs/remotes/origin/master → base="master", base_ref="origin/master"
  (4) git rev-parse --verify --quiet refs/heads/main   → base="main",   base_ref="main"   (remote 없는 local)
  (5) git rev-parse --verify --quiet refs/heads/master → base="master", base_ref="master"
  모두 실패 → signal: degraded (fail-open)
merge_base = git merge-base "$base_ref" HEAD   (실패 → degraded)   # base_ref는 실제 존재하는 ref
branch_ahead_count = git diff --name-only "$merge_base"..HEAD | wc -l
# emit: base(표시), merge_base(SHA — SKILL redirect가 재사용)
```
존재 확인은 전부 `git rev-parse --verify --quiet`로 통일 — local-only/remote 브랜치를 일관되게
구분하고 detached HEAD/shallow에서 `degraded`로 떨어진다. base **이름**과 git-usable `base_ref`를
분리해 `origin/main`만 있고 local `main`이 없는 흔한 토폴로지(fresh clone/CI/worktree)에서도 merge-base가
실패하지 않는다(review-iter1 fix). SKILL의 redirect "Review branch diff" 경로는 emit된 `merge_base:`
커밋 SHA를 그대로 받아 `$merge_base..HEAD`로 리뷰 대상을 만든다(C6 parity; base 이름 재-resolve 없음).

**계산:**
- `resolved_count`:
  - session mode → `files.md`의 `- ` 항목 수(없으면 0).
  - paths mode → `git diff HEAD --name-only -- <globs> | wc -l`(glob에 매칭되면서 *동시에*
    `git diff HEAD`에 등장하는 파일 수 — 변경 없는 glob 매칭은 제외; 단순 glob 매칭 수가 아님).
  - branch mode → `branch_ahead_count`.
- `worktree_dirty`: `git diff HEAD --name-only` 비어있지 않음 OR untracked(`git ls-files
  --others --exclude-standard`) 존재면 `yes`. **`--exclude-standard`는 의도적** — `.gitignore`
  대상(빌드 아티팩트·`node_modules`·`*.log` 등)은 "변경"으로 치지 않아 진짜 no-op(NG4)을
  false-positive로 `empty_scope_with_changes`로 오분류하지 않는다. tracked 변경 + non-ignored
  untracked만 센다.
- `changes_exist` = `branch_ahead_count > 0` OR `worktree_dirty == yes`.

**출력(structured stdout):**
```
resolved_count: <N>
branch_ahead_count: <M>
worktree_dirty: yes|no
base: <branch-name|->
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

### 5.2 호출·캐시 + 소비자 A — redirect 게이트

**호출·캐시(C7, 격리 계약):** SKILL은 `check-review-scope.sh`를 **Review iter-1 step 1**에서
(scope 해석 + v2.5.0 transparency 한 줄 직후, scout dispatch 이전) **1회만** 호출하고 출력을
SKILL-turn 변수 `$scope_signal` / `$branch_ahead_count` / `$base`에 캐시한다. 소비자 A(redirect
게이트)와 소비자 B(floor)는 **재호출 없이 이 캐시를 소비**한다. iter 2–5에서 재호출하지 않는
이유: empty-scope 케이스는 iter-1의 redirect 게이트에서 branch/honest-empty/stop 중 하나로
*해소*되므로, 이후 iteration은 항상 non-empty(branch) scope로만 돌아 floor의
`resolved_count==0` 술어가 iter-1에 한정된다. allowed-tools에 스크립트 추가.

**소비자 A 발화:** `$scope_signal == empty_scope_with_changes`이고 kill switch 미설정이면
`AskUserQuestion` 발화. **고유 anchor 구절:** 질문 본문에 리터럴 `review scope is empty` 포함
(SKILL 내 타 decision-tool과 충돌 없음 — `findings remain`/`both gates`/`Runtime verifier
needs`와 같은 격의 protocol anchor. orchestration grep이 존재·고유성 검증).

```
AskUserQuestion({
  questions: [{
    question: "Review scope is empty (session: 0 files) but the branch is <M> files
               ahead of <base>. These changes were never reviewed this session.
               What should I review?",
    header: "Review scope",
    options: [
      {label: "Review branch diff (recommended)",
       description: "merge_base(<base>)..HEAD 변경분을 리뷰. scope=branch로 재해석 후 정상 진행."},
      {label: "Proceed (honest-empty, not clean)",
       description: "리뷰어 dispatch 건너뛰고 정직 verdict 직행 — 'no scope reviewed, NOT clean'."},
      {label: "Stop",
       description: "정직 요약으로 파이프라인 중단. /qg branch로 재실행 권장."}
    ],
    multiSelect: false
  }]
})
```

**분기 (각 분기는 transcript-observable output을 남긴다 — AC7 검증용):**
- **Review branch diff** → scope=branch로 재해석(`$base`로 `merge_base..HEAD`), 가시 출력
  `> Review scope: branch (<M> files vs <base>).` → scout부터 정상 진행. 이후 iteration 기존과 동일.
- **Proceed (honest-empty)** → scout/reviewer dispatch **건너뜀**(0개 파일에 리뷰어 돌리는 낭비
  회피). positive observable 라인 출력(부재가 아니라 명시적 출력으로 검증 가능):
  `> Review gate: skipping reviewer dispatch — 0 files reviewed (honest-empty path).`
  → 5.3 정직 verdict 직행 → 다음 게이트/요약.
- **Stop** → final summary에 `aborted at Review gate (empty scope, branch <M> ahead)` 표기로 중단.

**kill switch:** `DEVBREW_QG_DISABLE_SCOPE_REDIRECT=1` → 게이트 생략, advisory 한 줄만 출력
(`> [quality-gates] review scope empty but branch <M> ahead — redirect gate disabled; floor still applies.`)
→ 그대로 진행하되 floor(5.3)가 verdict를 잡음. devbrew kill-switch 규범 충족(C3).

### 5.3 소비자 B — 정직-verdict floor

결정론 backstop. verdict 방출부(SKILL Review 게이트 **Step 4.5**)에서, 캐시된 `$scope_signal`이
`empty_scope_with_changes`이면 clean-equivalent 라벨을 honest로 교체. **Step 4.5의 clean으로
귀결되는 두 sub-case 모두**에 적용한다:

- `kept=0 & suppressed=0` (`## Review gate iter N: clean`) → honest 라벨로 교체.
- `kept=0 & suppressed>0` (`No high-confidence findings. N low-confidence findings suppressed.` —
  현재 clean으로 treat해 loop exit) → 이 케이스도 사용자가 "검토됨·문제없음"으로 읽을 위험이
  있으므로 honest 라벨을 **함께** 출력(suppressed count 라인은 유지).

honest 라벨:
`## Review gate iter N: no scope reviewed (0 files; branch <M> ahead of <base>) — NOT certified clean.`

이 분기는 redirect 게이트와 **동일 캐시 신호**를 소비하므로 발산 불가. 게이트가 어떤 이유로든
(kill switch / AskUserQuestion 부재 / "Proceed honest-empty" 선택) 우회돼도 거짓 "clean"은
구조적으로 불가 = G1 load-bearing(P8). `normal`/`genuine_noop` 경로의 `clean`/transparency
문구는 **무변경**(NG4).

최종 요약(Final Summary)의 `Review gate:` 줄도 honest-empty 케이스를 그대로 반영
(`no scope reviewed (branch <M> ahead)`).

### 5.4 Runtime transparency 라인

순수 additive 한 줄(LD3 — 새 게이트·diff-scope 강제·동작 변경 전무, NG3). Review의
`> Review scope: ...`와 대칭.

```
> Runtime scope: full project (<project_type>) — boots <surface 요약>, asserts <K> spec AC.
  Runtime runs the whole app regardless of Review scope.
```

- **마지막 절 `regardless of Review scope` = OQ4 비대칭 명시**(리터럴, grep 검증).
- **데이터원(새 계산 없음):** `detect-runtime.sh` manifest(`project_type` +
  `runnable_surfaces`/`test_runners` 요약) + spec AC 개수(R2 `discover-spec`에서 수집).
  `<K>` = spec AC 수(spec 없으면 `0 spec AC (smoke fallback)`).
- **발화 지점(단일 — 타이밍 정합):** Runtime 게이트 **Step R2 직후·R3(runtime-verifier
  dispatch) 직전 1회**. 출력 라인 시작 anchor: `> Runtime scope: full project`. 근거: Decision
  2(Upfront 단계)와 R-init은 R2의 spec AC 수집 *이전*에 실행되므로 그 시점엔 `<K>`가 미확정 —
  라인을 R2 뒤로 두면 manifest·approved_surfaces·spec AC가 모두 확정된 상태로 정확히 출력된다.
  **Runtime 게이트가 실행되는 모든 경로(both-gates, 단일 `/qg runtime`)가 R3를 통과**하므로 단일
  지점이 그 경로들을 전부 커버한다. Review-gate-only 경로(`gate=review`/"Review gate only"/
  `effective_skip_runtime`)는 Runtime 게이트 섹션을 통째 skip하므로 R3에 도달하지 않고 — 이는
  정상이다(돌리지 않는 Runtime을 설명할 라인도 없어야 함). R3는 앱 boot 직전이라 "before
  execution" 의도도 만족한다(라인은 SKILL.md에 1회 등장 — grep -c == 1, 위치는 §8 proximity 검증).

## 6. Acceptance Criteria

- **AC1:** `check-review-scope.sh`는 `resolved_count==0` AND (`branch_ahead_count>0` OR
  `worktree_dirty`)일 때 `signal: empty_scope_with_changes`를 emit한다(session·branch·paths mode 각각).
- **AC2:** `resolved_count==0` AND 변경 전무일 때 `signal: genuine_noop`을 emit한다.
- **AC3:** `resolved_count>0`일 때 `signal: normal`을 emit한다(paths mode 포함 — glob∩diff>0).
- **AC4:** git 부재/detached HEAD/merge-base 없음/shallow일 때 `signal: degraded` + exit 0
  (fail-open)을 emit하고, SKILL은 이를 no-gate(redirect·floor 미발화)로 처리한다.
- **AC5:** `check-review-scope.sh`는 파일을 생성/수정/삭제하지 않는다(read-only — 실행 전후
  `git status --porcelain` + working tree 불변).
- **AC6:** SKILL Review 게이트 iter 1은 `$scope_signal==empty_scope_with_changes` AND kill switch
  미설정일 때만 redirect `AskUserQuestion`을 발화하며, 그 질문에 리터럴 `review scope is empty`가
  있고, 이 구절은 SKILL 내 다른 어떤 decision-tool 호출에도 없다(고유 — grep -c == 1).
- **AC7:** redirect 게이트 3옵션이 명세대로 분기하며 각각 transcript-observable **positive**
  anchor를 남긴다 — "Review branch diff"→`> Review scope: branch (<M> files vs <base>)` 출력 +
  scope=branch 진행; "Proceed (honest-empty)"→`> Review gate: skipping reviewer dispatch — 0 files
  reviewed (honest-empty path).` 출력 + 정직 verdict(부재가 아닌 명시 출력으로 검증); "Stop"→final
  summary `aborted at Review gate (empty scope...)`.
- **AC8 (floor, 결정론):** `$scope_signal==empty_scope_with_changes`이면 Step 4.5의 clean-귀결
  **두 sub-case 모두**(`suppressed=0`·`suppressed>0`)에서 Review verdict 라벨이
  `no scope reviewed … NOT certified clean`이며 절대 단독 `clean`이 아니다. redirect 게이트와
  독립적으로 verdict 방출부에서 보장된다(게이트 우회·kill switch에도 불변).
- **AC9:** `DEVBREW_QG_DISABLE_SCOPE_REDIRECT=1`이면 redirect 게이트는 발화하지 않되(advisory
  한 줄), floor(AC8)는 여전히 적용된다.
- **AC10 (무회귀):** `normal`/`genuine_noop` 경로는 추가 클릭 없이 기존 verdict("clean")·
  transparency 문구를 그대로 유지한다.
- **AC11:** Runtime transparency 라인은 Step R2 직후·R3 직전 **1회** 출력되며(SKILL.md에 리터럴
  1회 등장, `grep -c 'regardless of Review scope' == 1` + §8 proximity 검증으로 R2·R3 step marker
  (`**bold**`, `##` 헤더 아님) *사이* 위치 확인 — 단순 존재가 아니라 위치까지), transcript-observable
  anchor `> Runtime scope: full
  project`로 시작해 `project_type` + surface 요약 + spec AC 수(`<K>`)를 포함한다. Runtime 게이트가
  실행되는 모든 경로(both-gates / 단일 `/qg runtime`)가 R3를 통과하므로 단일 지점이 그 경로들을
  커버한다(Review-gate-only은 Runtime 미실행이라 라인 없음 = 정상, AC12).
- **AC12 (Runtime 무변경):** Runtime은 여전히 full-project로 돌고 diff-scope 강제·새 게이트가
  없다(라인은 additive). 단일 게이트 `/qg runtime` 동작 불변(라인 추가 외).
- **AC13 (SKILL-스크립트 계약, C6):** redirect "Review branch diff" 경로의 리뷰 대상은 스크립트가
  emit한 `merge_base:` 커밋 SHA에서 출발해, signal을 유발한 **모든 변경의 union**을 리뷰한다 —
  `git diff $merge_base`(merge_base SHA→**워킹트리**: committed-ahead + tracked-uncommitted 포함) +
  non-ignored untracked. two-dot `$merge_base..HEAD`(committed-only)는 **쓰지 않는다**: worktree-only
  trigger(`branch_ahead_count=0`)에서 그 diff는 비어 0 files를 clean으로 인증하는 false-clean이 되기
  때문(review-iter4). base **이름**을 재-resolve하지 않으므로 remote-only base(`origin/main` + no local
  `main`)에서도 orchestration 계층에서 fail-open되지 않고(review-iter1 강화), SHA는 항상 resolve 가능.
  union이 `changes_exist`(branch_ahead OR worktree_dirty)와 정확히 일치하므로 `scope_signal=normal` 설정이
  항상 valid. 정적 검증: SKILL redirect-branch 블록이 script-emitted `merge_base` SHA를 참조(앵커
  `script-emitted commit SHA`) + working-tree-inclusive union(앵커 `UNION of every change that triggered`)
  + retry persistence(앵커 `CANONICAL for ALL remaining`) 라인 존재(orchestration grep). 단위 테스트는
  스크립트의 `base:` / `merge_base:` 출력 정확성을 담당.
- **AC14:** plugin.json `2.6.0`, CHANGELOG `## [2.6.0] — 2026-06-07`, README Scope +
  Principles Instantiated 갱신, philosophy P8에 floor 한 문장 흡수(새 P# 없음).

## 7. Files to Modify

| 파일 | 변경 |
|---|---|
| `plugins/quality-gates/scripts/check-review-scope.sh` | **신규** — 결정론 신호(§5.1) |
| `plugins/quality-gates/tests/test_check_review_scope.sh` | **신규** — AC1–AC5 fixture 단위 테스트 |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | allowed-tools에 `check-review-scope.sh` 추가; Review iter-1 step 1에 1회 호출+캐시(§5.2); redirect 게이트(§5.2, AC6/AC7); Step 4.5 floor 두 sub-case(§5.3, AC8); Runtime R2 직후 단일 transparency 라인(§5.4, AC11); kill switch 분기(AC9); redirect-branch가 `$base` 참조(AC13) |
| `plugins/quality-gates/commands/qg.md` | Quick Reference에 `DEVBREW_QG_DISABLE_SCOPE_REDIRECT=1` 행 + Scope 섹션 한 줄(floor/redirect 설명) |
| `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` | redirect anchor(`review scope is empty`, grep -c==1) + Runtime 라인(`regardless of Review scope`, grep -c==1) + AC13 정적 계약(redirect-branch `$base` 참조) grep |
| `plugins/quality-gates/.claude-plugin/plugin.json` | `2.5.0` → `2.6.0` (AC14) |
| `plugins/quality-gates/CHANGELOG.md` | `## [2.6.0] — 2026-06-07` (Added: floor/redirect/runtime line; Changed: empty-scope verdict label) |
| `plugins/quality-gates/README.md` | Scope 설명 + Principles Instantiated에 P8 floor 한 줄 |
| `docs/philosophy/devbrew-harness-philosophy.md` | P8 determinism-economy에 self-honest verdict floor 한 문장 흡수(새 P# 없음) |

## 8. Verification Plan

- **단위(신규) — `tests/test_check_review_scope.sh`:** git fixture로 AC1–AC5:
  - session: 빈 세션(`files.md` 없음/0항목) + 브랜치 base보다 앞섬 → `empty_scope_with_changes`.
  - session: `files.md` ≥1항목 → `normal`.
  - paths: glob 매칭 ∩ `git diff HEAD` > 0 → `normal`; 변경 없는 glob 매칭만 → `empty_scope_with_changes`(변경이 타 파일에 있을 때) / `genuine_noop`(변경 전무).
  - 빈 세션 + 변경 전무(clean tree, 브랜치 base와 동일) → `genuine_noop`.
  - merge-base 없음(무관 root) / detached HEAD → `degraded` + exit 0 (fail-open).
  - read-only 확인: 실행 전후 `git status --porcelain` 동일(AC5).
  - `base:` 출력값 정확성(fixture가 origin/HEAD·local main·master 케이스별 기대 base).
- **orchestration grep — `test_skill_orchestration_behavior.sh` 확장:**
  - redirect anchor `review scope is empty` `grep -c == 1`(존재+고유, AC6).
  - Runtime 라인 `regardless of Review scope` `grep -c == 1`(단일 지점) + **위치 검증**: awk/sed로
    SKILL.md에서 그 라인이 `Step R2` step marker와 `Step R3` step marker(둘 다 `**bold**` 인라인
    라벨 — `##` 마크다운 헤더 아님; 각 SKILL.md 전체에서 1회 등장) *사이*에 위치함을 확인(단순
    존재가 아니라 R2-직후·R3-직전 — AC11). observable anchor `> Runtime scope: full project`도 grep.
  - honest-empty positive anchor `> Review gate: skipping reviewer dispatch` `grep -c == 1`(AC7
    회귀 보호 — non-event 대신 positive 출력 확인).
  - AC13 정적 계약: SKILL redirect-branch 블록이 `$base`(스크립트 출력) 참조 라인 존재.
- **수동 e2e(스크립트화 곤란 — 메모리 V10 패턴, observable anchor 명시):**
  1. 편집→커밋→**새 세션**→`/qg` → redirect 게이트 발화(AC6). 3옵션 각각:
     "Review branch diff"→`> Review scope: branch (M files vs <base>)` 확인(AC7);
     "Proceed honest-empty"→`> Review gate: skipping reviewer dispatch — 0 files reviewed
     (honest-empty path).` + verdict `NOT certified clean`(AC7/AC8);
     "Stop"→final `aborted at Review gate (empty scope...)`(AC7).
  2. `DEVBREW_QG_DISABLE_SCOPE_REDIRECT=1` 재실행 → 게이트 없이 advisory + verdict
     `NOT certified clean`(AC9).
  3. 진짜 no-op(clean tree, 브랜치 base와 동일) `/qg` → 침묵·기존 `clean`(AC10).
  4. web 프로젝트 Runtime 도달 → R3 직전 transparency 라인 + `regardless of Review scope` +
     spec AC 수(AC11).
- **baseline:** 작업 전 repo root에서 기존 테스트 baseline 캡처(메모리: main에 8개 stale red —
  codex/consent/security/sandbox 환경의존, 작업과 무관 확인). 테스트는 repo root에서 실행.
- **Law 2:** persona(`agents/*.md`) diff 없음 확인(C1).

## 9. Rejected Alternatives

- **강제 branch/PR-diff 기본값 전환** → 버림. 개발 중 빠른 피드백(좁은 '방금 한 작업' scope)
  파괴 + 무거운 기본값이 인지부하·friction↑·채택률↓(brief §5, steelman ①④⑤). session 유지(NG1).
- **generic empty-scope hard block(전면 차단)** → 버림. 이 repo '옥죄기' 폐기 패턴 +
  idempotent no-op은 정상. "변경 있는데 scope=0"만 좁게 잡는 redirect 게이트+floor로 대체(NG2).
- **Runtime을 변경 diff-scope로 강제** → 버림. 앱 부팅엔 전체 앱 필요 — 비대칭은 본질. additive
  transparency만(NG3).
- **Advisory-only(redirect 질문 없음)** → 버림. 사용자가 redirect 게이트 채택(이 세션 Q) —
  자동 교정 제안이 가치, 깨진 케이스에서만 1클릭이라 lightness 위배 아님.
- **탐지 로직을 `pre-pipeline-check.sh` 확장/SKILL 인라인** → 버림. pre-pipeline은
  staleness/branch-mismatch state mutation 책임 — scope-vs-changes 탐지를 섞으면 책임 혼탁. 새
  read-only 스크립트가 단일 책임·독립 테스트(G5).
- **Runtime 라인 3지점 발화(Decision 2 + R-init + R3)** → 버림. Decision 2·R-init은 R2의 spec AC
  수집 *이전*이라 `<K>` 미확정(타이밍 충돌). 모든 경로가 통과하는 R2-직후·R3-직전 단일 지점으로
  수렴 — 정확성 + grep 검증 단순화(§5.4).
- **no-op "clean"을 "nothing to review"로 변경** → 버림. brief "전자는 두지만" 명시 —
  scope creep. 진짜 no-op verdict는 무변경(NG4).
- **새 P# 신설** → 버림. floor는 P8 determinism-economy의 직접 사례 — 흡수(NG5,
  design-lightness).

## 10. Open Questions

- **OQ-A (범위 밖, 의도적):** session tracker가 *이번 세션 밖*에서 편집된 파일(다른 세션·외부
  에디터)을 못 잡는 더 넓은 문제는 이 작업 범위 밖 — floor가 `worktree_dirty`로 부분 포착하나
  근본 해결(브랜치 기준 항상 비교)은 NG1과 충돌하므로 의도적으로 다루지 않음.

(round-1 리뷰가 제기한 base 해석 방법·paths count·C6 주입 메커니즘·floor suppressed 케이스·
Runtime 라인 타이밍은 모두 §5.1–§5.4/§6에서 *해소*됨 — 더 이상 open 아님.)

## 11. Concrete Next Action

이 design을 spec-distill:reviewing-spec(Law 2 분리 reviewer)이 검증 → 통과 시 writing-plans로
구현 계획 작성. writing-plans는 §7 Files to Modify를 task로 분해하고 §6 AC를 검증 단위로 매핑.
구현은 subagent-driven 엄격 순차(메모리: 병렬·투기적 dispatch 금지, evidence-before-approved).

## Handoff Context

**TL;DR:** qg의 false-clean(커밋 후 빈 세션 → resolved scope 0 → "clean") 봉쇄. 새 read-only
스크립트 `check-review-scope.sh`가 단일 신호(`empty_scope_with_changes`)를 emit하면 SKILL이
iter-1에서 1회 호출·캐시해 (A) redirect 게이트(P17, kill 가능)와 (B) 정직-verdict floor(P8, kill
불가)로 소비. Runtime은 R2 직후 transparency 한 줄(비대칭 명시)만 additive. session 기본값·
no-op clean·`/qg branch` 동작은 무변경.

**Implicit context (구현자가 알아야 할 비명시 사실):**
- 현재 SKILL.md에는 `branch` scope용 **canonical base resolver가 없다**(qg.md는 "vs main"으로만
  서술). 이 설계가 `check-review-scope.sh`를 단일 base 진실원으로 도입한다 — 구현자는 redirect
  "Review branch diff" 경로에서 SKILL이 스크립트 `base:` 출력을 *직접 받아* `merge_base..HEAD`를
  구성하게 해야 한다(AC13). 기존 `/qg branch` 경로 base 동작은 건드리지 않는다(NG7).
- floor는 Step 4.5의 **두** clean-귀결 분기에 모두 걸어야 한다(`suppressed=0` 단독으로 충분치
  않음 — `suppressed>0`도 사용자에게 clean으로 읽힘).
- 스크립트는 iter-1에서 1회만 호출하고 캐시 소비(C7) — empty-scope는 iter-1에서 해소되므로
  iter 2–5 재호출 불필요.
- bash 3.2(macOS) 호환 유의(메모리: NUL command-substitution 함정 — `git ... -z` 변수 캡처 회피,
  `--name-only | wc -l` 라인 카운트로 충분).
- 기존 main에 8개 stale red(codex/consent/security/sandbox, 환경의존) — baseline 캡처 후 무관 확인.

**Deferred to plan(writing-plans에서 task 분해):**
- §7 9개 파일 변경의 순서(스크립트+단위테스트 먼저 → SKILL 편집 → orchestration grep → 문서/버전).
- fixture git 셋업 디테일(origin/HEAD 모사, shallow/detached 케이스 생성).

## 12. Metadata

- **target_version:** 2.6.0 (minor — 새 surface: redirect 게이트 + 신규 스크립트 + honest 라벨
  + runtime 라인).
- **source_interview:** `docs/superpowers/interview/2026-06-07-qg-scope-capture-interview.md`
  (LD1–LD4 기정사실, OQ1–OQ5 본 design에서 해결).
- **principles instantiated:** Law 1(계산=스크립트, 분기=SKILL), Law 2(persona 무변경), P8
  determinism-economy(floor=정확성 결정론, redirect/routing=모델 신뢰), P17(redirect 게이트=
  사용자 redirect 가능), harness-lightness(정상 경로 zero-click).
- **no new P#:** floor는 P8에 흡수.
- **review history:** round-1 spec-reviewer `needs_revise`(10 issues: paths count/base 해석/AC7·
  AC11 testability/isolation 호출·캐시/C6 주입/floor suppressed/AC13 단위범위/Runtime 타이밍/
  Handoff 부재) → 전부 해소. round-2 `needs_revise`(8/10 완전 해소 확인 + 4 신규: NEW-001
  "모든 경로 R3" 과장 주장 / NEW-002 AC11 위치 미검증 / NEW-003 honest-empty non-event anchor /
  NEW-004 worktree_dirty gitignore 의도) → 본 개정에서 전부 해소(문구 정확화 + positive anchor +
  proximity 검증 + 의도 명시). Stagnation_signal: false(두 라운드).
