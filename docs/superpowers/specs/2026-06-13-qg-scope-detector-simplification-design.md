---
type: design
topic: qg scope detector 단순화 — routing 제거, verdict floor만 결정론 유지
plugin: quality-gates
target_version: 2.7.0
date: 2026-06-13
status: design
source_handoff: .claude/qg-detector-removal-handoff.md
related:
  - plugins/quality-gates/scripts/check-review-scope.sh            # 축소 — 120줄 detector → ~40줄 changes-exist 신호
  - plugins/quality-gates/tests/test_check_review_scope.sh         # 축소 — 새 contract 단위 테스트
  - plugins/quality-gates/skills/quality-pipeline/SKILL.md         # Step 1b 라우팅·redirect·$effective_diff_scope 제거 + floor 단순화 + honesty norm
  - plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh  # anchor 갱신(floor 유지·redirect 부재·env var 부재)
  - plugins/quality-gates/scripts/check-allowed-tools-order.sh    # 무변경(script 유지 확인용)
  - plugins/quality-gates/commands/qg.md                          # env var 문서 제거 + scope 문구 갱신
  - plugins/quality-gates/.claude-plugin/plugin.json              # 2.6.0 → 2.7.0
  - plugins/quality-gates/CHANGELOG.md                            # [2.7.0] — append-only, [2.6.0] 보존
  - plugins/quality-gates/README.md                              # Scope + Principles Instantiated 갱신
---

# qg scope detector 단순화 — routing 제거, verdict floor만 결정론 유지 (v2.7.0)

> v2.6.0의 120줄 결정론 detector는 *routing*(무엇이 바뀌었나를 git으로 재구성: mode/paths/
> union/merge_base/`$effective_diff_scope` 전파)과 *verdict 무결성*(0파일인데 clean 금지)을
> 한 덩어리로 했고, dogfood의 5개 버그가 **전부 routing 재구성**에서 나왔다. 이 설계는 두
> 책임을 분리한다 — routing은 모델 + `/qg branch` escape hatch에 위임(가볍게), verdict
> 무결성은 독립 결정론 1점(load-bearing)으로 축소·유지. detector는 `changes_exist?`만 emit하는
> ~40줄로 줄고, redirect 게이트·`$effective_diff_scope`·`DEVBREW_QG_DISABLE_SCOPE_REDIRECT`는
> 사라진다. 정상 경로(scope>0, 또는 진짜 변경 없음)는 v2.6.0과 동일하게 침묵·zero-click.

## 목차

- [1. Context / Why](#1-context--why)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. Constraints](#4-constraints)
- [5. Architecture](#5-architecture)
  - [5.1 책임 분리 (before → after)](#51-책임-분리-before--after)
  - [5.2 축소된 신호 — `check-review-scope.sh`](#52-축소된-신호--check-review-scopesh)
  - [5.3 verdict floor (Step 4.5) — 단일 소비자](#53-verdict-floor-step-45--단일-소비자)
  - [5.4 routing = 모델 (honesty norm + escape hatch)](#54-routing--모델-honesty-norm--escape-hatch)
- [6. Acceptance Criteria](#6-acceptance-criteria)
- [7. Files to Modify](#7-files-to-modify)
- [8. Verification Plan](#8-verification-plan)
- [9. Rejected Alternatives](#9-rejected-alternatives)
- [Handoff Context](#handoff-context)
- [10. Metadata](#10-metadata)

## 1. Context / Why

v2.6.0 "self-honest verdict + scope-capture"(PR #85, `c700360`)는 false-clean —
커밋 후 빈 세션에서 resolved scope=0인데 "clean"이 나오는 verdict 무결성 결함 —
을 봉쇄했다. 메커니즘은 단일 결정론 신호(`check-review-scope.sh`, 120줄)가 git을
재구성해 `signal`(`empty_scope_with_changes`/`normal`/`genuine_noop`/`degraded`)을 emit하면
SKILL Step 1b가 그것을 (A) redirect 게이트와 (B) Step 4.5 정직-verdict floor 두 소비자에
먹이는 구조였다.

그러나 v2.6.0의 `/qg` self-dogfood가 **prior 2단계 리뷰가 놓친 REAL 버그 5개**를 적발했고
(F2 remote-only base fail-open, F1 stale signal, worktree-only false-clean,
stale-after-redirect class, paths union under-count), **다섯 개 전부가 "무엇이 바뀌었나"를
결정론으로 git을 흉내내 재구성하는 부분** = *routing*에서 나왔다. 정작 *"변경이 존재하나?"*
라는 원시 git 체크는 한 번도 틀린 적이 없다. 무거운 건 재구성이고, load-bearing인 건 verdict
무결성 한 점인데, 둘이 같은 코드에 묶여 있던 게 결함의 근원이다.

사용자 directive(2026-06-13): **하네스를 가볍게.** 결정론은 load-bearing 보안/정확성
게이트에만; 모델이 잘 처리하는 routing/convenience 영역은 옥죄지 말고 모델을 신뢰
([[feedback_harness_lightness_trust_model]]). 동시에 false-clean 차단은 사용자 본인이
*verdict 무결성 = load-bearing*으로 분류한 영역이라([[project_qg_empty_scope_guard]]),
결정론 backstop을 통째로 버리는 건 Law 2("검증=load-bearing 인프라")와 긴장한다.

이 설계는 그 둘을 동시에 만족한다: routing 재구성은 제거(lightness), verdict 무결성 floor는
독립 결정론 1점으로 축소·유지(Law 2). 사용자는 brainstorming에서 (A 완전제거 vs B 최소
floor 유지) 중 **B**를, redirect 운명(유지 vs 제거) 중 **구조적 redirect 제거**를 선택했다.

## 2. Goals

- G1. v2.6.0 detector에서 **routing 재구성 전부 제거**: script의 mode/paths/union/signal,
  SKILL Step 1b 4-way 라우팅, Empty-scope redirect decision, `$effective_diff_scope` 배선,
  `DEVBREW_QG_DISABLE_SCOPE_REDIRECT` env var.
- G2. **verdict 무결성 floor는 유지하되 단일 독립 신호로 축소**: `check-review-scope.sh`는
  `changes_exist?`만 emit, Step 4.5 floor가 그것만 소비. false-clean 차단력 무손실.
- G3. **routing을 모델 + `/qg branch` escape hatch에 위임**: 빈 scope 감지 시 모델이 자연어로
  branch 리뷰를 제안하는 honesty norm 한 줄로 redirect 게이트 대체.
- G4. **dogfood가 고친 load-bearing fix 보존**: F2 remote-only base 해석(`base`/`base_ref`
  분리), NG4 untracked 처리(`--exclude-standard`), degraded fail-open + loud advisory.
- G5. v2.7.0 SemVer bump + CHANGELOG/README/qg.md 동기화. allowed-tools/linter 무변경.

## 3. Non-goals

- N1. **scope 계산을 다른 script로 이관하지 않는다** (scout.py / run_codex_reviewer.sh 등).
  이번 세션에 명시 기각된 over-correction. tiny script는 *기존* 단일 책임을 좁힐 뿐.
- N2. **"SKILL prose에 raw git 부재" negative guard를 추가하지 않는다.** 역시 기각된
  over-correction (모델 시야 축소 = 옥죄기).
- N3. **allowed-tools에 raw `git`을 추가하지 않는다.** floor의 git 체크는 기존
  `Bash(...check-review-scope.sh:*)` 권한 안에서 (축소된) script로 수행. determinism boundary 유지.
- N4. Runtime 게이트·trivia escape·gate-scope Decision 1/2·session 기본값은 무변경.
- N5. 새 P# / anti-pattern을 철학 doc에 추가하지 않는다 (P8 absorption — [[feedback_devbrew_design_lightness]]).

## 4. Constraints

- C1. **Law 2 (verdict 무결성 = load-bearing).** floor가 "clean"을 구조적으로 무를 수 없게
  하는 독립 신호는 *script의 `changes_exist`* (모델의 clean 주장과 무관한 출처)다. floor의 다른
  입력 `resolved_scope_file_count`는 모델 자유 주장이 아니라 concrete artifact(files.md 줄 수 /
  script `branch_ahead_count` / glob 매치)에 대한 결정론 연산이며, 연산이 불확실하면 degraded로
  fail-open(silent 0 금지 — §5.3). 봉쇄 대상 systemic false-clean("빈 scope 성실 리뷰 후 clean")은
  두 결정론 신호의 곱으로 차단 → self-approval 우회 불가. (도덕적 인센티브 논증에 기대지 않는다.)
- C2. **fail-open + loud logging.** script가 changes_exist를 확정 못 하면(detached HEAD /
  no base / shallow / non-git) `degraded: yes` emit, exit 0, floor는 fail-open(clean 허용)하되
  반드시 loud advisory 동반 (CLAUDE.md loud-logging; silent false-clean 금지).
- C3. **단일 호출·캐시.** script는 Review iter N=1에 1회 호출·캐시, iter 2–5는 재호출 없이
  캐시 소비 (소비자가 floor 하나뿐이라 발산 위험은 사라졌지만 재호출 회피).
- C4. **happy-path 무회귀.** scope>0(리뷰 대상 존재)이면 floor 미발동, verdict는 v2.6.0과
  비트 동일. genuine no-op(변경 없음)·`/qg branch`도 무변경.
- C5. **append-only CHANGELOG.** [2.6.0] 항목 보존, [2.7.0]만 추가. 제거-grep ACs는
  CHANGELOG.md(history)를 제외하고 active doc(SKILL/qg.md/README)만 검사.
- C6. **trivia escape 우선.** 한 문장 trivia diff는 게이트 우회(무변경). 이 설계는 게이트
  진입 후 verdict 단계에만 관여.

## 5. Architecture

### 5.1 책임 분리 (before → after)

```
v2.6.0 (한 덩어리 — 버그원천)            v2.7.0 (분리)
┌───────────────────────────┐         ┌─ Routing (모델) ──────────┐ ┌─ Verdict 무결성 (결정론) ─┐
│ check-review-scope.sh 120줄│         │ 모델 소유 scope 해석       │ │ check-review-scope.sh ~40줄│
│  mode/paths/union/merge_base│   →    │ + /qg branch escape hatch │ │  changes_exist? 만 emit    │
│  /signal → 2 consumers     │         │ + honesty norm 1줄        │ │   ↓ iter1 1회 호출·캐시     │
│  (A) redirect (B) floor    │         │ (redirect 게이트 제거)    │ │ Step 4.5 floor: 단일 소비  │
└───────────────────────────┘         └───────────────────────────┘ └───────────────────────────┘
```

routing(무엇을 리뷰?)은 모델/escape-hatch가 소유 — 가볍게. verdict 무결성(0파일인데 clean
금지)은 독립 결정론 1점 — load-bearing 유지. 버그원천(재구성)과 가치원천(floor)을 분리한다.

### 5.2 축소된 신호 — `check-review-scope.sh`

단일 책임을 좁힌다: ~~"resolved review scope가 비었는데 변경이 있나?"~~ →
**"이 브랜치/워킹트리에 변경이 존재하나?"** (scope 해석은 모델 소유이므로 script에서 제거).

- **유지(load-bearing, dogfood가 옳게 고침):** git sanity → fail-open, base 해석
  (`base`/`base_ref` 분리 — F2 remote-only fix), branch-ahead 변경 **파일** 수
  (`git diff --name-only merge_base..HEAD | wc -l` — 커밋 수 아님), worktree-dirty(tracked
  `git diff HEAD` + 비-ignore untracked `--exclude-standard` — NG4).
- **제거:** `mode` 파라미터, `paths` glob + union, `resolved_count`(모델이 scope 소유),
  `signal` 4-way 라우팅, redirect-union용 `merge_base` emit.
- **emit (structured stdout):**
  ```
  changes_exist: yes|no        # branch_ahead>0 OR worktree_dirty=yes
  branch_ahead_count: <M>      # 변경 *파일* 수 (merge_base..HEAD `git diff --name-only | wc -l` —
                               #   커밋 수 아님; v2.6.0 동작 유지). branch 모드 resolved_scope_file_count 대리값
  worktree_dirty: yes|no       # honest 메시지용
  base: <name|->               # honest 메시지 표시명
  degraded: yes|no             # fail-open 마커 (C2)
  ```
- exit code: 항상 0 (`degraded: yes`가 fail-open 상태를 carry).
- read-only, 인자 없음(`mode`/`globs` 제거), 프로젝트 root에서 호출.

내부 base 해석(merge_base 계산)은 branch-ahead를 위해 *내부적으로* 필요하므로 남지만,
redirect-union 소비자가 사라졌으므로 `merge_base`는 더는 emit하지 않는다.

### 5.3 verdict floor (Step 4.5) — 단일 소비자

SKILL Step 1b는 4-way 라우팅에서 **1회 호출·캐시**로 축소된다:

```
Step 1b (iter N=1 only) — changes-exist cross-check (floor용 캐시):
  check-review-scope.sh 1회 실행 → $changes_exist / $branch_ahead_count /
  $worktree_dirty / $base / $degraded 캐시. 라우팅·redirect 없음.
  $degraded == yes → 이 run은 floor 미보호; loud advisory 한 줄을 verdict 시 출력하도록 표시.
```

Step 4.5 floor 로직 (clean으로 갈 때 = kept findings == 0):

```
resolved_scope_file_count  := Step 1에서 해석한 review scope의 파일 수 — 결정론 도출:
   · session → grep -c '^- ' .claude/quality-gates/<sid>/files.md   (파일 부재 시 0)
   · branch  → script의 $branch_ahead_count                          (이미 결정론: git diff name 수)
   · paths   → --paths glob 매치 수
   도출이 불확실하면(files.md unreadable 등) 0으로 silent fall-through 금지 →
   degraded 경로로 합류(아래 ELSE IF + loud advisory). v2.5.0 transparency 라인이
   이미 session count를 표면화하므로 신규 측정이 아니라 기존 값 재사용.

IF resolved_scope_file_count == 0 AND $changes_exist == yes:
    print "## Review gate iter N: no scope reviewed (0 files; branch <M> ahead of <base>,
           worktree <dirty|clean>) — NOT certified clean."   # clean 금지
ELSE IF $degraded == yes AND resolved_scope_file_count == 0:
    print "## Review gate iter N: clean"
    print "> [quality-gates] scope check degraded (detached HEAD / no base / shallow) —
           empty-scope detection skipped (fail-open; verdict not floor-protected this run)."
ELSE:
    print "## Review gate iter N: clean"                       # 정상 (scope>0 또는 genuine no-op)
```

floor의 load-bearing 핵심(C1): 독립 backstop은 **`$changes_exist`** — script가 모델의 clean
주장과 무관하게 emit하는 객관 신호다. resolved scope가 비었을 때(0파일) 변경이 존재하면
"clean"이 구조적으로 금지된다. 다른 입력 `resolved_scope_file_count`는 모델 자유 주장이 아니라
concrete artifact(files.md 줄 수 / script의 branch_ahead_count / glob 매치)에 대한 결정론
연산 결과이고, 그 연산이 불확실하면 degraded로 fail-open(silent 0 금지). 따라서 봉쇄하려는
systemic false-clean — "빈 scope를 성실히 리뷰하고 clean 보고" — 은 모델 정직성이 아니라
`changes_exist × (결정론 scope count == 0)`의 곱으로 차단된다. 조건이 `== 0`인 점에 유의:
partial coverage(scope>0인데 branch 일부만)는 floor 미발동 — 그건 routing/convenience라 모델·
transparency 라인이 처리(N4 비대상, [[project_qg_empty_scope_guard]]).

### 5.4 routing = 모델 (honesty norm + escape hatch)

Empty-scope redirect decision 섹션(AskUserQuestion 3옵션 + union 재계산)과
`$effective_diff_scope` 전파는 제거. 대체로 SKILL에 **honesty norm 한 줄**을 둔다:

> *You own review-scope resolution. If your resolved scope is empty (0 files) but the
> branch/worktree has changes, you MUST NOT certify clean — offer to review the full branch
> (`/qg branch`) or emit the honest "no scope reviewed" verdict. The Step 4.5 floor enforces
> this structurally.*

빈 scope 시 모델은 자연어로 "branch가 <M> ahead입니다 — `/qg branch`로 리뷰할까요?"를
제안할 수 있고(routing = 모델), floor가 honest verdict를 구조적으로 보장한다. scout/reviewer
dispatch/inlined-blob는 `$effective_diff_scope` 대신 모델-소유 scope를 직접 참조한다.

## 6. Acceptance Criteria

- AC1. `check-review-scope.sh`는 `changes_exist`/`branch_ahead_count`/`worktree_dirty`/
  `base`/`degraded`만 emit한다. `signal:`/`resolved_count:`/`merge_base:` 라인, `mode`/`paths`
  인자 처리가 없다. (단위 테스트 + grep)
- AC2. **F2 회귀 보존:** `origin/main`만 있고 local `main`이 없는 토폴로지에서 script는
  `degraded: no` + 올바른 `base`/branch_ahead를 낸다 (fail-open 아님). (단위 테스트)
- AC3. **NG4 회귀 보존:** `.gitignore`된 산출물은 `changes_exist`를 트립하지 않고, 비-ignore
  untracked 파일은 `worktree_dirty: yes` + `changes_exist: yes`를 만든다. (단위 테스트)
- AC4. script는 detached HEAD / no base / shallow / non-git에서 `degraded: yes` emit, 항상
  exit 0. (단위 테스트)
- AC5. SKILL Step 4.5 floor: `resolved_scope_file_count == 0 AND changes_exist == yes`이면
  honest "no scope reviewed … NOT certified clean" 라벨을 출력하고 bare "clean"을 절대 출력하지
  않는다. **검증:** (i) `test_skill_orchestration_behavior.sh`의 prose-anchor assert로 SKILL에
  이 조건+라벨 블록이 존재함을 확인(기존 line 348-349 `assert_line` 패턴 재사용), (ii) 실제
  동작은 AC13 e2e fixture가 검증.
- AC6. `degraded == yes`이고 scope==0이면 "clean"은 허용하되 `verdict not floor-protected
  this run` loud advisory가 동반된다. **검증:** SKILL anchor assert(advisory 문구 존재) +
  AC13 fixture의 degraded 변종(base branch 없는 repo).
- AC7. **happy-path 무회귀:** resolved scope>0이면 floor 미발동, "Review gate iter N: clean"이
  v2.6.0과 동일하게 출력된다. **검증:** AC13 fixture의 scope>0 변종(files.md ≥1항목 + 변경)에서
  bare clean 출력 확인.
- AC8. 문자열 `review scope is empty`가 SKILL.md에서 사라진다 (grep == 0; CHANGELOG 제외).
  Empty-scope redirect decision 섹션 전체가 제거된다.
- AC9. `$effective_diff_scope`(및 `effective_diff_scope`)가 SKILL.md에서 사라진다
  (grep == 0; CHANGELOG 제외). scout/reviewer dispatch/inlined-blob는 모델-소유 scope를 참조.
- AC10. `DEVBREW_QG_DISABLE_SCOPE_REDIRECT`가 SKILL.md·qg.md·README.md에서 사라진다
  (grep == 0; CHANGELOG history만 보존).
- AC11. allowed-tools 무변경: `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-review-scope.sh:*)`
  유지, raw `git` 미추가. `check-allowed-tools-order.sh` 및 그 테스트가 무변경 통과.
- AC12. honesty norm 한 줄이 SKILL.md에 존재한다 (G3; grep으로 핵심 문구 확인).
- AC13. **false-clean e2e (TDD):** harness가 **격리된 임시 repo**(`mktemp -d` + `git init` +
  base branch + ahead 커밋)를 만들고 files.md를 빈 채로 둔 뒤 floor 로직을 실행 — honest verdict
  (NOT certified clean)를 내고 "clean"을 내지 않는다. **fixture는 fail-closed**: `cd`/`git init`
  실패 시 즉시 abort — 절대 live repo에서 git 파괴 연산 금지(v2.6.0 dogfood가 `set -u`-only
  fixture의 live-repo `git branch -D main` 위험을 적발, [[project_qg_scope_capture]]). 변종으로
  scope>0(AC7)·degraded=base branch 없음(AC6)·genuine no-op(변경 없음→clean — C4 happy-path
  보조: floor 오발동 없음 확인)도 같은 fixture 골격으로 커버. red→green.
- AC14. plugin.json 2.6.0 → 2.7.0; CHANGELOG `## [2.7.0] — 2026-06-13` (Removed/Changed);
  README "Principles Instantiated" + Scope 문서 갱신.
- AC15. **baseline 무회귀:** 작업 후 main의 기존 8 stale red(환경의존)만 남고 신규 red 0.

## 7. Files to Modify

| 파일 | 변경 |
|---|---|
| `scripts/check-review-scope.sh` | 120→~40줄 축소. mode/paths/union/signal/resolved_count/merge_base-emit 제거; changes_exist emit 추가; F2/NG4/degraded 보존 (§5.2, AC1–4) |
| `skills/quality-pipeline/SKILL.md` | Step 1b 4-way 라우팅 → 1회 호출·캐시; Empty-scope redirect decision 섹션 삭제; `$effective_diff_scope` 배선 제거; Step 4.5 floor를 changes_exist 단일 소비로 단순화; honesty norm 추가; v2.7.0 헤더 (§5.3–5.4, AC5–9,12) |
| `tests/test_check_review_scope.sh` | 새 contract로 축소 (changes_exist/degraded/F2/NG4); mode/paths/signal 테스트 삭제 (AC1–4) |
| `tests/harness/test_skill_orchestration_behavior.sh` | anchor 갱신 — script 호출(유지)·floor 발동·redirect 부재·env var 부재·effective_diff_scope 부재 (AC5–10) + e2e false-clean (AC13) |
| `commands/qg.md` | `DEVBREW_QG_DISABLE_SCOPE_REDIRECT` 문서 제거; scope 문구 갱신 (AC10) |
| `.claude-plugin/plugin.json` | 2.6.0 → 2.7.0 (AC14) |
| `CHANGELOG.md` | `## [2.7.0] — 2026-06-13` Removed/Changed 추가 (append-only, AC14, C5) |
| `README.md` | env var/signal 참조 제거, Scope 설명 + Principles Instantiated 갱신 (AC10,14) |
| `scripts/check-allowed-tools-order.sh` | **무변경** (script 유지 확인용 — Files 목록에 포함은 "건드리지 않음을 verify"의 의미) |

## 8. Verification Plan

1. **TDD 순서 (AC13 우선):** harness e2e false-clean 시나리오를 먼저 red로 작성 → SKILL
   floor 단순화 구현 → green. 그 다음 script 축소 + 단위 테스트.
2. **단위:** `bash tests/test_check_review_scope.sh` — AC1–4 (changes_exist yes/no, F2
   remote-only, NG4 untracked, degraded fail-open). repo root에서 실행.
3. **harness:** `bash tests/harness/test_skill_orchestration_behavior.sh` — AC5–10,12.
4. **grep ACs:** AC8/9/10 — `grep -c` 0 검증 (SKILL/qg.md/README; CHANGELOG 제외).
5. **linter 무회귀:** `bash scripts/check-allowed-tools-order.sh` 통과 (AC11).
6. **baseline (AC15):** 작업 전 전체 테스트 baseline 캡처(기존 8 red 확인) → 작업 후 동일
   8개만, 신규 red 0. ([[project_qg_pre_existing_test_reds]] — repo root 실행)
7. **/qg self-dogfood (필수 — floor는 보안/무결성 컨트롤):** feature 브랜치에 `/qg branch`로
   Review 게이트를 돌려 **codex model-diversity가 floor의 fail-open을 적발하는지** 확인. §1이
   기록하듯 v2.6.0 dogfood가 prior 2단계 리뷰를 뚫은 fail-open(F2)을 codex 독립리뷰로만 잡았고
   ([[project_qg_scope_capture]]: "보안 컨트롤=codex 독립리뷰 필수"), floor 자체가 C1/Law 2
   컨트롤이므로 이 pass를 optional로 두면 설계가 §1의 자기 교훈을 위반한다. **plan에 별도 task로
   포함**(권장이 아니라 verification의 일부).

## 9. Rejected Alternatives

- **A — 완전 제거 (norm only).** script·Step 1b·floor·redirect 전부 삭제, prose norm 한 줄만.
  가장 가벼우나 독립 backstop 상실 → verdict 무결성이 전적으로 모델 self-honesty 의존.
  dogfood가 false-clean 버그를 *실제로* 잡았다는 증거가 있어 Law 2상 backstop 1점은 값한다.
  사용자가 brainstorming에서 B 선택. (→ §1)
- **슬림 redirect 유지.** 빈 scope 시 AskUserQuestion(branch/honest/stop) affordance 유지(union
  산술만 제거). in-flow UX는 낫지만 routing은 모델 영역이라 구조적 게이트가 불필요(lightness).
  사용자가 "구조적 redirect 제거" 선택.
- **inline git floor.** floor의 git 체크를 orchestrator가 raw git으로 inline 수행, script 삭제.
  script 파일은 사라지나 writer에 raw `git` 권한 신규 부여 + linter 갱신 + determinism boundary
  위반([[project_qg_scope_capture]] 잔여 IMPORTANT) = 무게를 더 위험한 곳으로 이동. 기각 → §5.2 tiny script.
- **script-owned scope 전면 refactor + negative-git guard.** scope 계산을 scout.py/
  run_codex_reviewer.sh로 이관 + "raw git 부재" guard. 이번 세션 명시 기각 (모델 시야 축소 =
  옥죄기, [[feedback_harness_lightness_trust_model]]). N1/N2.
- **script rename (`check-changes-exist.sh`).** 좁아진 책임에 더 정확하나 allowed-tools 항목 +
  linter EXPECTED_ORDER + 테스트 + SKILL 참조 churn 유발. 헤더 주석으로 책임 갱신하고 파일명
  유지가 더 가벼움. (재고 여지 있음 — Metadata Open 참조)
- **lazy floor 호출 (scope==0일 때만 script 실행).** happy-path에서 script subprocess 1회를
  아끼나, floor의 독립 신호 포착이 모델의 scope 판단에 조건부가 되어 load-bearing 안전성이 약화.
  C3대로 **eager(iter1 1회 호출·캐시)로 확정** — single-call 패턴 일관 + 신호를 리뷰 전 포착.

## Handoff Context

- **TL;DR:** v2.6.0 detector의 routing 재구성(script modes/paths/union/signal, redirect 게이트,
  `$effective_diff_scope`, `DEVBREW_QG_DISABLE_SCOPE_REDIRECT`)을 제거하고 verdict 무결성 floor만
  결정론으로 유지. floor = `resolved_scope_file_count == 0 AND changes_exist == yes → "clean" 금지`.
  3 결정 locked: B floor 유지 / 구조적 redirect 제거 / tiny script(raw git 미부여).
- **Implicit context (plan이 알아야 할 비자명):**
  - `check-review-scope.sh`는 *유지·축소*(삭제 아님) → allowed-tools `Bash(...check-review-scope.sh:*)`
    + `check-allowed-tools-order.sh:17`의 EXPECTED_ORDER 항목 **무변경**. raw `git`을 allowed-tools에
    추가하지 말 것(N3) — floor의 git은 축소된 script가 수행.
  - CHANGELOG는 append-only — [2.6.0] 보존, [2.7.0]만 추가. 제거-grep ACs(AC8/9/10)는 CHANGELOG 제외.
  - 테스트는 **repo root에서** 실행([[project_qg_pre_existing_test_reds]]); main에 기존 8 stale
    red(환경의존, 무관) — 작업 후 정확히 그 8개여야(AC15).
  - 모든 테스트 fixture는 **fail-closed** 필수(live-repo git 파괴 방지 — v2.6.0 교훈, AC13).
  - `resolved_scope_file_count` 도출이 불확실하면 degraded fail-open(silent 0 금지) — floor의
    load-bearing 핵심이자 C1 검증 가능성의 근거(§5.3).
- **Deferred to plan (차단 아님):** TDD 순서(AC13 red 먼저 → SKILL floor → script 축소 → 단위);
  codex dogfood를 별도 task로 배치(§8 step 7, 필수). script rename·eager 호출은 §9/§10에서 닫힘.

## 10. Metadata

- **Plugin / Version:** quality-gates, 2.6.0 → **2.7.0** (minor — surface 제거 + 동작 단순화,
  게이트 핵심 contract(false-clean 차단) 보존).
- **Origin:** `.claude/qg-detector-removal-handoff.md` (2026-06-13 `/qg` self-dogfood 세션).
- **Decisions locked (brainstorming):** (1) floor 전략 = **B 최소 floor 유지**; (2) redirect
  운명 = **구조적 redirect 제거**; (3) floor 메커니즘 = **tiny script** (allowed-tools script-only 사실 기반).
- **Memory:** [[project_qg_scope_capture]], [[feedback_harness_lightness_trust_model]],
  [[project_qg_empty_scope_guard]], [[project_qg_pre_existing_test_reds]],
  [[feedback_devbrew_design_lightness]], [[feedback_evidence_before_approved]].
- **Decided (was open):** script 파일명 `check-review-scope.sh` **유지**(rename은 allowed-tools/
  linter/테스트/SKILL 참조 churn 유발 — §9; 헤더 주석으로 좁아진 책임 갱신). eager floor 호출 확정
  (C3/§9). **차단 open 이슈 없음.**
- **Law 1 게이트:** 이 design doc은 활성 설계(AC·동작 변경)라 spec-distill auto-review hook을
  정상 honor (documentary skip 아님 — [[feedback_spec_distill_documentary_edit_skip]]).
