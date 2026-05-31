# Spec: quality-gates v2.2.0 — runtime-verifier를 샌드박스 기능-executor로

> 실제 서비스를 *띄우고 보기만* 하던 runtime-verifier를, **일회용 샌드박스에서
> 서비스를 띄우고 real user flow를 구동하며 spec AC 대비 동작을 단언하는
> executor**로 전환한다. 쓰기는 허용하되 product는 절대 오염·커밋되지 않으며,
> 운영 DB/네트워크는 절대 건드리지 않는다.

요청자: 사용자 (2026-05-31, brainstorming 세션). 원하는 결과: runtime-verifier가
"실제 서비스를 실행하며 테스트하는 역할"이 되도록 + `model: inherit`.

## 목차

- [1. Context / Why](#1-context--why)
- [2. Goals](#2-goals)
- [3. Non-goals / Out-of-Scope](#3-non-goals--out-of-scope)
- [4. Constraints (헌장 정합)](#4-constraints-헌장-정합)
- [5. 핵심 결정 요약](#5-핵심-결정-요약)
- [6. 설계 상세](#6-설계-상세)
  - [6.1 정체성 & 모델](#61-정체성--모델)
  - [6.2 도구 권한 (완화)](#62-도구-권한-완화)
  - [6.3 샌드박스 생애주기 (write-and-discard)](#63-샌드박스-생애주기-write-and-discard)
  - [6.4 spec AC 대비 기능 단언](#64-spec-ac-대비-기능-단언)
  - [6.5 Upfront Execution Plan](#65-upfront-execution-plan)
  - [6.6 Blocked-path 처리](#66-blocked-path-처리)
  - [6.7 Verdict 분류 확장](#67-verdict-분류-확장)
  - [6.8 운영 안전](#68-운영-안전)
  - [6.9 Law 2 scoped exception 문서화](#69-law-2-scoped-exception-문서화)
- [7. Acceptance Criteria](#7-acceptance-criteria)
- [8. Files to Modify](#8-files-to-modify)
- [9. Verification Plan](#9-verification-plan)
- [10. Rejected Alternatives](#10-rejected-alternatives)
- [11. Open Questions (plan 단계 결정)](#11-open-questions-plan-단계-결정)
- [12. Metadata](#12-metadata)

## 1. Context / Why

현 `runtime-verifier`(qg v2.1.0, Runtime gate Step 3)는 manifest의 각
runnable surface를 attempt하고 evidence-log를 쓴 뒤 4-verdict(PASS / FAIL /
SKIP_WITH_EVIDENCE / NEEDS_RESOLUTION)를 emit한다. 그런데 코드를 실증 조사하면 "실제
서비스를 실행하며 테스트"하기에는 세 가지 공백이 있다.

- **조작 불가.** `agents/runtime-verifier.md`의 chrome-devtools `allowedTools`는
  navigate·screenshot·snapshot·console·new_page·close_page·wait_for 뿐이다.
  `click`·`fill`·`fill_form`·`type_text`·`evaluate_script`가 없어 페이지를 *볼 수만*
  있고 *건드릴 수는* 없다. 로그인 폼 제출→결과 검증 같은 real user flow가 구조적으로
  불가능하다. 그래서 테스트가 얕다(떴나? 2xx? console error 0개? 라우트 navigate +
  스크린샷).
- **기대 동작 기준 부재.** verifier는 plan에서 긁은 `/auth`·"login form" 같은 얕은
  패턴(`plan_features`)만 받고 spec은 받지 않는다. "이 기능이 *올바르게* 동작했나"를
  단언할 truth가 없다. 마침 v2.1.0이 `discover-spec.sh`로 spec의 Acceptance
  Criteria를 이미 찾으므로(test-scope-validator·codex 경로), AC를 runtime까지 연장하면
  자연스러운 truth가 된다.
- **setup 잡일조차 못 함.** `disallowedTools: [Write, Edit, MultiEdit,
  NotebookEdit]`로 물리 차단이라 `cp .env.example .env` 같은 사소한 setup도
  NEEDS_RESOLUTION으로 사용자에게 떠넘긴다. "실제로 서비스를 띄워 본다"는 목표와
  마찰한다.

**핵심 긴장.** "실제 서비스를 실행"하려면 verifier가 (1) 조작하고 (2) setup을 고치고
(3) 동작을 판단해야 한다. 이는 Law 2("리뷰어는 Write 물리 차단")와 정면 충돌한다.
해소는 Law 2의 *의도*("writer가 자기 코드를 product에 approve 못 함")를 다른
메커니즘으로 지키는 것이다 — **샌드박스 격리 + 절대 무커밋 + fix-to-green 강등**.

## 2. Goals

- **조작 가능한 기능 단언.** 브라우저 상호작용으로 real user flow를 구동하고, **spec
  AC 대비** behavior를 **증거-접지(evidence-grounded)** 방식으로 단언. 적용 범위는
  **web + CLI** (library는 현행 pytest/test-runner 유지).
- **`model: sonnet → inherit`.** flow 구동·AC 판단의 reasoning에 세션 모델 사용.
  in-plugin 선례: `security-reviewer`(이미 inherit).
- **일회용 샌드박스 쓰기.** verifier가 샌드박스에서 자유롭게 쓰되, gate 종료 시
  통째 폐기. product는 구조적으로 무오염·무커밋.
- **Upfront Execution Plan.** qg 진입 시 "gate 범위 + runtime 실행 범위 + block
  정책"을 **위험/모호할 때만** 1회 확정(아니면 zero-click 유지). mid-stream 깜짝
  질문 제거.
- **Blocked-path 명시.** executor가 막혔을 때의 분류·라우팅·terminal 동작을 빠짐없이
  정의 (P18 bounded).
- **운영 안전 최우선.** 운영 DB/네트워크/외부 시스템은 절대 건드리지 않는다.
- SemVer `v2.1.0 → v2.2.0` (새 surface = 기능 단언·executor; 사용자 선택 minor).

## 3. Non-goals / Out-of-Scope

- **product 버그 자동 수정 후 self-green.** verifier가 product 소스를 고쳐 "내 fix로
  AC 통과함"이라 green을 내는 것은 Law 2 self-approval 위반 — 금지. product 버그는
  FAIL + evidence + (선택) 후보 diff *제안*까지만.
- **executor/reviewer 별도 agent 분리.** Law 2 무수정을 위해 read-only reviewer +
  write executor를 나누는 안은 표면/handoff 비용으로 기각(§10). scoped exception 채택.
- **네트워크 egress 완전 차단 샌드박스.** 외부 의존 서비스 실행과 충돌하므로 default
  제외. 운영 안전은 *test-config-only + 판단 게이트*로 달성(§6.8).
- **library 기능 단언 신규.** pytest/cargo test/go test가 이미 기능 확인 — 현행 유지.
- **major bump(3.0.0).** 사용자가 2.2.0 minor 선택.

## 4. Constraints (헌장 정합)

- **Law 1 (Clarity / evidence-required).** 기능 PASS는 구체 evidence(스크린샷 + DOM
  snapshot 텍스트 + network status) 인용 필수. 증거 없는 "동작함"은 거부 — v1.8.0의
  "evidence-required SKIP"을 단언으로 확장.
- **Law 2 (Writer ≠ Reviewer).** verifier에 Write를 주되, *scoped exception*으로
  정합화: 준수 메커니즘을 "도구 deny" → "**샌드박스-discard + 무커밋 + fix-to-green
  강등 + write 분류**"로 이전(§6.9). `test-scope-validator`는 순수 read-only reviewer로
  **불변**(disallowedTools 유지).
- **P18 (Bounded autonomy).** setup 자동수정 retry와 SKILL re-dispatch 모두
  `runtime_max_resolutions`(기본 3, env `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS=0..10`)로
  상한. surface별 wall-clock kill. 기존 `needed_hash` repeat-detection 유지.
- **P21 (Secret 미노출).** AskUserQuestion은 결정·포인터(yes/no/path)만. secret 값은
  절대 받지 않음. 운영 자격증명은 disk(.env)에 사용자가 직접.
- **zero-click happy path 보존.** quality-pipeline의 happy-path-zero-click 가치
  유지 — upfront plan은 위험/모호할 때만 prompt.
- **project_dir 단일 좌표.** verifier의 `project_dir`는 샌드박스 경로로 frozen,
  재-derive 금지(기존 Reviewer Dispatch Contract 불변).

## 5. 핵심 결정 요약

| 축 | 결정 | 근거 |
|---|---|---|
| model | `sonnet` → **`inherit`** | flow·AC 판단 reasoning; security-reviewer 선례 |
| 깊이 | full-stack 기능 단언 (상호작용 + AC behavior + richer evidence) | "볼 수만" → "조작" |
| 단언 기준 | **spec AC 우선** → plan_feature fallback → 둘 다 없으면 기능 skip/smoke (loud log) | spec-as-truth(v2.1.0) 연장 |
| 쓰기 격리 | 일회용 샌드박스 + 폐기 + product diff surface(무커밋) + fix-to-green 강등 | Law 2 의도 보존 |
| 범위 | **web + CLI** 기능 단언; library 현행 유지 | 조작 공백은 web/CLI; lightness |
| 실행 게이트 | blast-radius 분류 → 프로세스 기동/CLI/side-effecting/불확실 = `requires_decision`; test runner만 자동 | 운영 안전 |
| 운영 안전 | 샌드박스 **test/isolated config만**; prod-pointing surface는 gate/거부 | "운영 DB/네트워크 안 터짐" |
| fix 루프 | bounded; **setup만 자동수정+retry**; product 버그 → FAIL+evidence+선택 후보 diff(self-green 금지) | Law 2 self-approval 회피 |
| upfront plan | gate 범위 + runtime 범위 + block 정책을 **위험/모호할 때만** 1회 확정 | mid-stream 질문 제거 + zero-click |
| block 정책 | `stop` / `skip`(SKIP_WITH_EVIDENCE 후 계속) / `ask`(mid-run 질문); per-surface 격리 | P18 |
| Law 2 | scoped exception 문서화; test-scope-validator 불변 | 헌장 정합 |
| version | **2.2.0 minor** (+CHANGELOG Security 섹션) | 사용자 선택 |
| cost_class | **variable 유지 + web-functional 진입 전 1줄 heads-up** | library=저렴~web Opus flow=고가 |

## 6. 설계 상세

### 6.1 정체성 & 모델

`agents/runtime-verifier.md`의 역할 프롬프트를 **"does it run + 스크린샷" 관찰자** →
**"샌드박스에서 서비스를 띄우고 user flow를 구동하며 spec AC 대비 동작을 단언하는
sandbox-executor"**로 재정의. "You are NOT responsible for" 블록은 유지하되 정밀화:
*product 소스를 고쳐 PASS를 만드는 것*과 *운영 시스템을 건드리는 것*을 명시 금지.

frontmatter `model: sonnet` → `model: inherit`. SKILL dispatch(Runtime gate Step 3)는
`model:` param을 넘기지 않으므로 frontmatter가 authoritative.

### 6.2 도구 권한 (완화)

- `allowedTools`에 추가: **`Write`, `Edit`, `MultiEdit`** (project_dir=샌드박스에서만
  의미) + chrome-devtools 상호작용 도구 **`click`, `fill`, `fill_form`,
  `type_text`, `hover`, `press_key`, `evaluate_script`** (기존 navigate/screenshot/
  snapshot/console/new_page/close_page/wait_for에 더해).
- `disallowedTools`: `Write`/`Edit`/`MultiEdit`를 제거. `NotebookEdit`는 불필요하므로
  유지(deny). 즉 deny 목록은 빈 목록이 아니라 명시적으로 남김(default-everything 금지).
- 이 변경은 **보안-민감**. persona 편집은 test-suite 편집과 같은 신중함으로 취급.

### 6.3 샌드박스 생애주기 (write-and-discard)

- SKILL이 Runtime gate dispatch 전 **검토 대상 코드(uncommitted 변경 포함)를 반영한
  일회용 샌드박스를 생성**. namespace는 기존 `.claude/quality-gates/worktrees/`(또는
  병렬 `sandboxes/`) 하위, `qg-worktree.sh`의 namespace-guard·idempotent create·
  remove·kill switch 패턴 재사용.
- verifier `project_dir` = 샌드박스 경로 (frozen).
- gate 종료 시 **verdict 무관 샌드박스 통째 제거**. gate는 아무것도 commit 안 함.
- kill switch `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1` → 샌드박스 끄면 현재 read-only
  smoke-test 동작으로 graceful fallback + **loud log 한 줄**.
- **uncommitted 반영 필수.** /qg는 보통 머지 전 working-tree 변경을 검증하므로,
  커밋된 브랜치만 잡는 `git worktree add --detach`로는 부족. 정확한 메커니즘은
  §11(Open Questions).

### 6.4 spec AC 대비 기능 단언

- SKILL이 **spec AC를 verifier 입력으로 thread** (신규 입력 필드, 예:
  `spec_acceptance_criteria` 또는 `spec_path` → `discover-spec.sh` 출력 재사용).
  현재 verifier는 spec을 받지 않으므로 이는 실제 입력 계약 확장.
- verifier는 testable AC → 구체 flow로 매핑:
  - **web:** navigate + interact(click/fill/...) → 기대 결과 단언, evidence 캡처
    (스크린샷 + DOM snapshot 텍스트 + network status).
  - **CLI:** 명령 실행 → stdout/exit-code/동작을 AC 대비 검증(Bash + grep), evidence는
    명령·출력 캡처.
- **증거-접지 필수:** 모든 기능 PASS는 구체 evidence를 인용. 증거 없는 단언은 거부.
- **Fallback 체인:** spec AC 발견 → AC 단언 / spec 없음 → plan_feature(현 crude
  route) / 둘 다 없음 → 기능 단언 skip, smoke-test만. 어느 모드인지 **loud log**.

### 6.5 Upfront Execution Plan

qg 진입 흐름을 재배치. 현재: review → runtime 도달 → surface 탐지 → 그때 scope 질문.
변경: **scope 결정을 앞으로**.

1. trivia check → preflight(project_dir·샌드박스 준비) → **detect-runtime +
   blast-radius 분류**(§6.8).
2. **Execution Plan 확정** (위험/모호할 때만 AskUserQuestion; 아니면 plan 1줄 표시 +
   zero-click 진행; `gate=`/`skip_runtime` arg가 pre-answer):
   - **gate 범위:** review만 / runtime만 / 둘 다.
   - **runtime 실행 범위:** pure-local test runner는 자동, `requires_decision`
     surface(CLI·프로세스 기동·side-effecting) 목록 제시(opt-in/out).
   - **block 정책:** setup 자동수정 소진 후 막혔을 때 → `stop` / `skip` / `ask`.
3. 확정 plan대로 review → runtime을 **재질문 없이** 실행 (진짜 NEEDS_RESOLUTION +
   정책=`ask`일 때만 mid-run 질문).

**프롬프트 발화 조건(위험/모호):** `requires_decision` surface 존재, 또는 scope
모호(예: runtime 범위 추론 불가). 순수-로컬/review-only는 prompt 없이 진행.

### 6.6 Blocked-path 처리

executor가 surface 실행 중 **block**(완료 불가)되면:

| block 종류 | 처리 |
|---|---|
| setup-fixable (.env·deps 누락) | 샌드박스에서 자동수정 + retry (executor 내부, bounded). 성공→계속 / 소진→escalate |
| operational-safety 위반 (prod config/네트워크 필요) | **실행 안 함**. blocked-for-safety 기록 → NEEDS_RESOLUTION("test config 제공") 또는 SKIP. prod 대상 자동 실행 금지 |
| needs-decision (requires_decision인데 plan 미승인) | NEEDS_RESOLUTION |
| product 버그 (AC 불충족 / product 결함으로 안 뜸) | FAIL + evidence + 후보 diff 제안 (retry 아님 — verdict) |
| hang/timeout | surface별 wall-clock kill, blocked 기록, 나머지 surface 계속 |

**block 이후 라우팅:**

- **per-surface 격리:** 한 surface block이 gate 전체를 abort하지 않음 — 나머지
  surface attempt 후 집계(기존 "모든 surface attempt" 불변과 정합).
- **bounded 해소 루프:** setup-fixable → 자동수정+retry는 `runtime_max_resolutions`
  안에서. 소진 시 → **upfront block 정책** 적용:
  - `stop` → gate를 block 지점에서 abort, terminal 요약.
  - `skip` → blocked surface를 SKIP_WITH_EVIDENCE로 기록 후 나머지로 계속, partial
    결과로 finalize.
  - `ask` → AskUserQuestion(retry / skip-with-evidence / stop), bounded; retry 시
    executor re-dispatch(iteration++).
- **terminal:** 루프 소진 또는 사용자 중단 → gate가 terminal verdict(FAIL/
  SKIP_WITH_EVIDENCE) emit + block 문서화 + **샌드박스 폐기** + 최종 요약. 무한 루프
  불가(P18).
- executor는 자기 dispatch 내에서만 bounded retry; 그 이상은 SKILL이 정책대로
  re-dispatch(역시 bounded). 양 레이어 모두 상한.

### 6.7 Verdict 분류 확장

PASS/FAIL/SKIP_WITH_EVIDENCE/NEEDS_RESOLUTION 유지. 신규 매핑:

- 기능 단언 실패(폼은 떴는데 AC대로 동작 안 함) → **FAIL** (expected vs observed
  evidence 첨부).
- **fix-to-green:** product 소스를 써야 떴다/통과했다 → **절대 PASS 불가** →
  FAIL(또는 NEEDS_RESOLUTION) + product diff를 evidence + "proposed-diff"로 surface
  (사용자가 gate 밖에서 별도 accept 가능; gate는 auto-commit 안 함).
- **setup-only fix → PASS 가능.** 비-product write(.env·deps·fixture)로 떴다면 정상
  PASS 후보.
- verifier가 **자기 write를 분류**: product-affecting(tracked 소스) vs
  non-product(gitignored config/deps/scratch). evidence-log가 write마다 분류 기록.

evidence-log 신규 섹션:
- `writes:` — `{path, class: product|non-product, committed: never}` 목록.
- `functional_assertions:` — `{ac_id, flow, expected, observed, evidence_refs,
  verdict}` 목록.

### 6.8 운영 안전

"운영 DB/네트워크 안 터짐"의 teeth:

- **blast-radius 분류** (`detect-runtime.sh`가 surface별로):
  - *순수-로컬-결정적*(pytest, `*test`, cargo test, go test): side effect 없음 →
    **자동 실행**.
  - *프로세스 기동 / 외부 변경 / 파괴 가능 / 불확실*(npm start·dev, cargo/go run,
    makefile run, 임의 CLI): → **`requires_decision: true`**.
  - **불확실 = gate** (deny-by-default).
- **test/isolated config 우선.** 샌드박스는 실제 `.env`(prod 가리킬 수 있음)보다
  `.env.example`/`.env.test`를 우선 사용. 띄우려면 *반드시* prod 자격증명/엔드포인트가
  필요한 surface는 자동 실행이 아니라 `requires_decision`/거부.
- **판단 주체 = verifier(inherit).** `requires_decision` surface에 대해 verifier가
  보안·운영 영향 요약(네트워크 egress? 외부 mutation? 파괴적? 과금?)을 제시,
  SKILL이 사용자 판단을 받음.

### 6.9 Law 2 scoped exception 문서화

- **README "Principles Instantiated":** 현 Law 2 bullet(runtime-verifier가
  `disallowedTools: [Write, Edit, ...]` 자랑)을 재작성 — runtime-verifier는
  **sandbox-executor**이며 Law 2 준수는 *샌드박스-discard + 무커밋 + fix-to-green 강등
  + write 분류*로 달성됨을 명시. **test-scope-validator는 순수 read-only reviewer로
  그대로**(disallowedTools 유지)임을 대비로 명확화.
- **`docs/philosophy/devbrew-harness-philosophy.md` + `CLAUDE.md`:** runtime gate
  executor를 *문서화된 scoped exception*으로 note 추가 (Law 본문 rewrite 아닌 가벼운
  단서 — "executor는 도구-deny가 아닌 격리-discard로 Law 2를 만족").
- 신규 원칙 bullet: 운영-안전 게이트(blast-radius), 기능 단언(spec AC), upfront plan.

## 7. Acceptance Criteria

1. **AC1 (frontmatter):** `runtime-verifier.md`가 `model: inherit`, `allowedTools`에
   `Write`/`Edit`/`MultiEdit` + 상호작용 MCP(`click`/`fill`/`type_text`/…),
   `disallowedTools`에서 `Write`/`Edit`/`MultiEdit` 제거(NotebookEdit는 deny 유지).
2. **AC2 (blast-radius):** `detect-runtime.sh`가 프로세스 기동/CLI/side-effecting
   surface를 `requires_decision: true`로 표시; 순수-로컬 test runner(pytest/`*test`)는
   `requires_decision` 없이 자동.
3. **AC3 (샌드박스):** SKILL이 검토 대상 코드(uncommitted 포함)를 반영한 일회용
   샌드박스를 생성하고 gate 종료 시 verdict 무관 제거; gate는 아무것도 commit 안 함.
4. **AC4 (upfront plan):** `requires_decision` surface 존재 또는 scope 모호 시
   실행 전 1회 plan 확정(gate 범위·runtime 범위·block 정책); 순수-로컬/review-only는
   zero-click; `gate=`/`skip_runtime` arg가 pre-answer.
5. **AC5 (운영 안전):** 샌드박스가 test/isolated config 우선; prod 자격증명/엔드포인트가
   필요한 surface는 `requires_decision`/거부 — prod 대상 자동 실행 0건.
6. **AC6 (기능 단언):** spec AC 발견 시 AC-유래 flow를 증거-접지로 단언; spec 없으면
   plan_feature, 둘 다 없으면 smoke-test; 어느 모드인지 loud log.
7. **AC7 (verdict):** 기능 단언 실패 → FAIL; product 소스 write가 필요했던 run → 절대
   PASS 아님(FAIL/NEEDS_RESOLUTION) + diff surface; setup-only fix는 PASS 가능.
8. **AC8 (fix-loop):** setup 자동수정+retry는 `runtime_max_resolutions` 상한; product
   버그는 FAIL+evidence+선택적 후보 diff 제안(self-approval green 0건).
9. **AC9 (blocked-path):** block 종류별 처리·per-surface 격리·정책별(stop/skip/ask)
   라우팅·terminal verdict·샌드박스 폐기가 모두 정의·구현; 무한 루프 불가.
10. **AC10 (Law 2 docs):** README/philosophy/CLAUDE.md가 scoped exception 문서화;
    `test-scope-validator`는 disallowedTools(Write/Edit) 불변.
11. **AC11 (버전·CHANGELOG):** `plugin.json` 2.2.0; `CHANGELOG.md` `[2.2.0]`에
    Added/Changed/Security; `e2e-scenarios.md`의 stale `runtime-verifier:
    model=sonnet, cost_class=low` 갱신.
12. **AC12 (kill switch):** `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1` → read-only
    smoke-test로 graceful fallback + loud log.
13. **AC13 (cost):** cost_class `variable` 유지; web-functional 무거운 경로 진입 전
    SKILL이 1줄 cost heads-up.

## 8. Files to Modify

- **`plugins/quality-gates/agents/runtime-verifier.md`** — frontmatter(model
  inherit, allowedTools 확장, disallowed 정리) + body 재작성(executor 정체성, write
  분류, fix-to-green 규칙, AC 단언 절차, evidence-log 신규 섹션, blast-radius 판단,
  운영 안전).
- **`plugins/quality-gates/scripts/detect-runtime.sh`** — surface별 blast-radius
  분류(`requires_decision`); test runner는 자동.
- **`plugins/quality-gates/skills/quality-pipeline/SKILL.md`** — Upfront Execution
  Plan(§6.5), 샌드박스 create/discard 배선, spec AC thread, scope/blast-radius
  게이트, blocked-path 라우팅(§6.6), product diff surface(무커밋), cost heads-up,
  운영 안전(test-config). 최종 요약 v2.2.0.
- **`plugins/quality-gates/scripts/qg-worktree.sh`** (또는 신규 helper) —
  working-tree 반영 샌드박스 create/discard (§11 메커니즘 결정).
- **`plugins/quality-gates/.claude-plugin/plugin.json`** — version 2.2.0.
- **`plugins/quality-gates/CHANGELOG.md`** — `[2.2.0]` Added/Changed/Security.
- **`plugins/quality-gates/README.md`** — Law 2 bullet 재작성 + 신규 원칙(운영-안전·
  기능 단언·upfront plan) + model=inherit·table 갱신.
- **테스트:**
  - `tests/test_runtime_verifier_frontmatter.sh` **재작성** — model inherit, Write/Edit
    in allowedTools, 상호작용 도구, body의 sandbox/무커밋 contract assert.
  - `tests/test_runtime_verifier_behavior.py` 확장 — 기능 단언·fix-to-green 강등·write
    분류·증거-접지.
  - **신규** — 샌드박스 confinement(write가 샌드박스 밖 안 나감), fix-to-green 강등,
    운영-안전(prod config 거부), upfront plan/scope 게이트, blocked-path 라우팅.
  - `tests/e2e-scenarios.md:136` stale 갱신.
  - `tests/test_detect_runtime.sh` 확장 — blast-radius 분류 assert.
- **`docs/philosophy/devbrew-harness-philosophy.md` + `/CLAUDE.md`** — runtime gate
  executor scoped exception note (light touch; TOC 동기화).

## 9. Verification Plan

- **자동:** 위 bash/py 테스트를 **repo root에서** 실행(qg 테스트 cwd 계약). qg는 CI가
  없고 main에 기존 stale red(codex/consent/security/sandbox)가 있으므로 작업 전
  **baseline 캡처** 후 신규/수정 테스트의 green만 회귀 판정.
- **수동(2개 fixture):**
  - `tests/fixtures/gate3/web-compose/` — web 경로: scope 게이트 발화 → 샌드박스 기동 →
    상호작용 단언 → 샌드박스 폐기 → product 무변경 확인(`git status` clean).
  - CLI fixture(신규 또는 기존 활용) — CLI 경로: requires_decision 확인 → 자동 실행
    거부/허용 → AC 대비 stdout 검증 → 샌드박스 폐기.
- **운영 안전 회귀:** prod-pointing `.env` fixture에서 자동 실행 0건 + 거부 경로 확인.
- **Law 2 회귀:** `test-scope-validator` disallowedTools 불변 + verifier가 product
  diff를 commit하지 않음 확인.

## 10. Rejected Alternatives

- **executor/reviewer 별도 agent 분리** (Law 2 무수정 순수) — verifier를 read-only
  reviewer로 두고 write executor를 신설. agent+handoff 표면 증가(두 dispatch가 한
  샌드박스 공유) 비용으로 기각; 사용자 선택(scoped exception)에 따름.
- **product 버그 자동 수정 후 verifier 자체 green** — Law 2 self-approval 정면 위반.
  기각.
- **product 버그 수정 + 독립 reviewer가 fix를 green 판정(2-agent)** — 가장 강력하나
  surface 증가. 현 범위에서 기각(향후 별도 작업 가능).
- **네트워크 egress 차단 샌드박스** — 외부 의존 서비스 실행과 충돌. 운영 안전은
  test-config + 판단 게이트로 충분하므로 deferred.
- **3.0.0 major bump** — 보안 contract 완화이나 사용자가 2.2.0 minor 선택.
- **upfront plan 무조건 항상 prompt** — zero-click happy path 가치와 충돌. 위험/모호할
  때만 prompt로 절충.

## 11. Open Questions (plan 단계 결정)

- **샌드박스 메커니즘:** uncommitted 변경을 반영한 일회용 샌드박스를 어떻게 만들지 —
  (a) working-tree를 temp commit/stash → `git worktree add`로 그 ref 체크아웃 → 폐기,
  (b) 디렉토리 복사(rsync/cp, git 컨텍스트 손실), (c) 기존 `qg-worktree.sh` 확장. 트레이드오프
  (uncommitted 충실도 vs git 인지 vs 속도)는 writing-plans에서 결정.
- **spec AC → flow 매핑의 구체 형식:** AC 텍스트에서 testable flow를 어떻게 추출/표현할지
  (verifier 자유 추론 vs 구조화 입력). plan에서 구체화.

## 12. Metadata

- **Plugin:** quality-gates
- **Version:** v2.1.0 → **v2.2.0** (minor)
- **요청자:** 사용자 (2026-05-31 brainstorming 세션)
- **관련 선행 작업:** v2.1.0 spec-as-truth(#75, discover-spec.sh), v1.8.0 evidence-
  required SKIP, v1.14.0/worktree-cwd-contract, gate3-active-verification(runtime
  gate origin).
- **헌장 영향:** Law 2 scoped exception (CLAUDE.md + philosophy note), 신규 kill
  switch `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX`.
- **보안-민감:** persona(runtime-verifier.md) 편집 + Law 2 메커니즘 이전 — 신중 리뷰
  대상.
