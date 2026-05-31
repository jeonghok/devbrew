# Spec: quality-gates v2.2.0 — runtime-verifier를 샌드박스 기능-executor로

> 실제 서비스를 *띄우고 보기만* 하던 runtime-verifier를, **일회용 git-worktree
> 샌드박스에서 서비스를 띄우고 real user flow를 구동하며 spec AC 대비 동작을 단언하는
> executor**로 전환한다. 쓰기는 허용하되 product 변경은 *git이 ground-truth로* 잡아
> 절대 PASS를 못 만들고 커밋되지 않으며, 운영 DB/네트워크는 절대 건드리지 않는다.

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
  - [6.3 샌드박스 생애주기 (git worktree, write-and-discard)](#63-샌드박스-생애주기-git-worktree-write-and-discard)
  - [6.4 spec AC 대비 기능 단언](#64-spec-ac-대비-기능-단언)
  - [6.5 Upfront Execution Plan](#65-upfront-execution-plan)
  - [6.6 Blocked-path 처리](#66-blocked-path-처리)
  - [6.7 Verdict 분류 + 구조적 self-approval 가드](#67-verdict-분류--구조적-self-approval-가드)
  - [6.8 운영 안전](#68-운영-안전)
  - [6.9 Law 2 scoped exception 문서화](#69-law-2-scoped-exception-문서화)
- [7. Acceptance Criteria](#7-acceptance-criteria)
- [8. Files to Modify](#8-files-to-modify)
- [9. Verification Plan](#9-verification-plan)
- [10. Rejected Alternatives](#10-rejected-alternatives)
- [11. Open Questions (plan 단계 세부)](#11-open-questions-plan-단계-세부)
- [12. Handoff Context](#12-handoff-context)
- [13. Metadata](#13-metadata)
- [14. Review revisions](#14-review-revisions)

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
메커니즘으로 — **그러나 여전히 *물리적/구조적으로*** — 지키는 것이다. 핵심 장치는
**git worktree 샌드박스 + git-diff 기반 product-mutation 가드 + 절대 무커밋**(§6.7).

## 2. Goals

- **조작 가능한 기능 단언.** 브라우저 상호작용으로 real user flow를 구동하고, **spec
  AC 대비** behavior를 **증거-접지(evidence-grounded)** 방식으로 단언. 적용 범위는
  **web + CLI** (library는 현행 pytest/test-runner 유지).
- **`model: sonnet → inherit`.** flow 구동·AC 판단의 reasoning에 세션 모델 사용.
  in-plugin 선례: `security-reviewer`(이미 inherit).
- **일회용 git-worktree 샌드박스 쓰기.** verifier가 샌드박스에서 자유롭게 쓰되, gate
  종료 시 통째 폐기. product는 *git-diff 가드로 구조적으로* 무오염·무커밋.
- **Upfront Execution Plan.** qg 진입 시 "gate 범위 + runtime 실행 범위 + block
  정책"을 **`requires_decision` surface가 있을 때만** 1회 확정(아니면 zero-click 유지).
  mid-stream 깜짝 질문 제거.
- **Blocked-path 명시.** executor가 막혔을 때의 분류·라우팅·terminal 동작을 빠짐없이
  정의 (P18 bounded, 상한 수치 명시).
- **운영 안전 최우선.** 운영 DB/네트워크/외부 시스템은 절대 건드리지 않는다.
- SemVer `v2.1.0 → v2.2.0` (새 surface = 기능 단언·executor; §10에 영향 분석).

## 3. Non-goals / Out-of-Scope

- **product 버그 자동 수정 후 self-green.** verifier가 product 소스를 고쳐 "내 fix로
  AC 통과함"이라 green을 내는 것은 Law 2 self-approval 위반 — **구조적으로 차단**(§6.7
  git-diff 가드). product 버그는 FAIL + evidence까지.
- **후보 diff의 in-gate accept/apply 흐름.** verifier가 "이렇게 고치면 뜬다"는 후보
  diff를 *evidence-only 진단 텍스트*로 evidence-log에 남길 수는 있으나, gate 안에서
  그것을 apply하거나 accept하는 메커니즘은 **만들지 않는다**. product fix는 gate 밖의
  일반 writer→review 사이클(사용자 수동) 소관. (이 후보 diff는 §6.7 가드가 캡처한
  tracked diff 그 자체이며 별도 생성물이 아니다 — 따라서 항상 ≤FAIL과 동반.)
- **executor/reviewer 별도 agent 분리.** Law 2 무수정을 위해 read-only reviewer +
  write executor를 나누는 안은 표면/handoff 비용으로 기각(§10). scoped exception 채택.
- **네트워크 egress 완전 차단 샌드박스.** 외부 의존 서비스 실행과 충돌하므로 default
  제외. 운영 안전은 *test-config-only + 판단 게이트*로 달성(§6.8).
- **library 기능 단언 신규.** pytest/cargo test/go test가 이미 기능 확인 — 현행 유지.
- **major bump(3.0.0).** §10 영향 분석 결과 minor가 SemVer-defensible; 사용자도 2.2.0
  선택.

## 4. Constraints (헌장 정합)

- **Law 1 (Clarity / evidence-required).** 기능 PASS는 구체 evidence(스크린샷 + DOM
  snapshot 텍스트 + network status) 인용 필수. 증거 없는 "동작함"은 거부 — v1.8.0의
  "evidence-required SKIP"을 단언으로 확장.
- **Law 2 (Writer ≠ Reviewer).** verifier에 Write를 주되, *scoped exception*으로
  정합화. 핵심: self-approval 방지는 verifier의 *내부 판단*이 아니라 **orchestrator가
  git-diff로 산출하는 ground-truth**가 강제(§6.7) — behavioral expectation이 아닌
  구조적 가드. `test-scope-validator`는 순수 read-only reviewer로 **불변**.
- **P18 (Bounded autonomy).** 두 레이어 모두 상한: executor-내부 setup 자동수정 retry
  ≤ 3/dispatch, SKILL re-dispatch 루프 ≤ `runtime_max_resolutions`(기본 3, env
  `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS=0..10`). 곱이 hard ceiling. surface별 wall-clock
  kill. 기존 `needed_hash` repeat-detection 유지.
- **P21 (Secret 미노출).** AskUserQuestion은 결정·포인터(yes/no/path)만. secret 값은
  절대 받지 않음. 운영 자격증명은 disk(.env)에 사용자가 직접.
- **zero-click happy path 보존.** quality-pipeline의 happy-path-zero-click 가치
  유지 — upfront plan은 `requires_decision` surface가 있을 때만 prompt.
- **project_dir 단일 좌표.** verifier의 `project_dir`는 샌드박스 경로로 frozen,
  재-derive 금지(기존 Reviewer Dispatch Contract 불변).

## 5. 핵심 결정 요약

| 축 | 결정 | 근거 |
|---|---|---|
| model | `sonnet` → **`inherit`** | flow·AC 판단 reasoning; security-reviewer 선례 |
| 깊이 | full-stack 기능 단언 (상호작용 + AC behavior + richer evidence) | "볼 수만" → "조작" |
| 단언 기준 | **spec AC 우선** → plan_feature fallback → 둘 다 없으면 기능 skip/smoke (loud log) | spec-as-truth(v2.1.0) 연장 |
| 샌드박스 | **git worktree** (working-tree 반영 temp ref) + 폐기 + git-diff product 가드 | self-approval 구조적 차단 |
| 범위 | **web + CLI** 기능 단언; library 현행 유지 | 조작 공백은 web/CLI; lightness |
| 실행 게이트 | blast-radius 분류 → 프로세스 기동/CLI/side-effecting/불확실 = `requires_decision`; test runner만 자동 | 운영 안전 |
| 운영 안전 | 샌드박스 **test/isolated config만**; prod-pointing surface는 gate/거부 | "운영 DB/네트워크 안 터짐" |
| fix 루프 | bounded; **setup만 자동수정+retry**; product 변경은 git-diff로 ≤FAIL 강제 | Law 2 self-approval 회피 |
| upfront plan | gate 범위 + runtime 범위 + block 정책을 **requires_decision 있을 때만** 1회 확정 | mid-stream 질문 제거 + zero-click |
| block 정책 | `stop` / `skip`(SKIP_WITH_EVIDENCE 후 계속) / `ask`(mid-run 질문); per-surface 격리 | P18 |
| Law 2 | scoped exception 문서화; test-scope-validator 불변 | 헌장 정합 |
| version | **2.2.0 minor** (+CHANGELOG Security 섹션) | §10 영향 분석 |
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
  snapshot/console/new_page/close_page/wait_for에 더해; 최종 subset은 도구 가용성
  확인 후 — §11).
- `disallowedTools`: `Write`/`Edit`/`MultiEdit`를 제거. `NotebookEdit`는 불필요하므로
  유지(deny). 즉 deny 목록은 빈 목록이 아니라 명시적으로 남김(default-everything 금지).
- 이 변경은 **보안-민감**. persona 편집은 test-suite 편집과 같은 신중함으로 취급.
- **권한 완화의 안전판은 도구가 아니라 §6.7 git-diff 가드**다 — Write를 줘도 product
  변경은 orchestrator가 git으로 잡아 PASS를 못 만든다.
- **`Bash` policy:** executor는 서비스 기동·CLI 실행을 위해 `Bash`가 필수이므로
  `allowedTools`에 유지(기존에도 있음). **product 소스 안전은 도구 제한이 아니라 §6.7
  git-diff 가드가 보장**(Bash로 `git commit`이나 파일 수정을 해도 immutable baseline
  `B` 대비 diff가 잡고, 샌드박스는 폐기됨). **host/네트워크 blast-radius**(예: 샌드박스
  밖 `rm -rf`, 외부 호출)는 §6.8 blast-radius 분류 + upfront 사용자 판단 + test-config로
  governance — 단 OS-수준 egress/host 격리는 명시적 non-goal(§3)이라, destructive host
  명령 방어는 §6.8 판단 게이트(구조) + verifier instruction(behavioral)의 조합이며 완전한
  OS sandbox가 아님을 인정한다.

### 6.3 샌드박스 생애주기 (git worktree, write-and-discard)

SKILL이 Runtime gate dispatch 전 **검토 대상 코드(uncommitted 변경 포함)를 반영한
일회용 git worktree 샌드박스를 생성**하고, 그 상태를 **immutable baseline commit
`B`로 봉인**한다. 메커니즘(locked, feasibility 확인):

1. `git worktree add --detach <sandbox> HEAD` (`.claude/quality-gates/worktrees/`
   하위 runtime 전용 prefix `rt-<sid_short>`; `qg-worktree.sh`에 신규 subcommand —
   별도 helper 안 만듦). 샌드박스는 git worktree라 git 컨텍스트 보존(§6.7 가드 요구);
   *plain dir-copy를 샌드박스로 쓰는 안은 기각*.
2. **code-under-review를 byte-faithful 재현** (worktree 위에 working-tree 내용 overlay):
   (a) tracked 파일의 working-tree 내용을 `cp -a`/`rsync -a`로 복사(mode·symlink·binary
   보존) — `git diff | git apply`는 binary/mode/symlink에서 silent partial-apply가 있어
   **사용 안 함**(baseline `B`가 불완전 봉인되면 가드 전체가 무력); (b) untracked이지만
   **git-ignored 아닌** 파일(검토 대상 신규 소스)도 복사; (c) **git-ignored 파일은 복사
   안 함** — 특히 prod를 가리킬 수 있는 `.env`·자격증명·deps·build(운영 접근 차단,
   §6.8). (정확한 복사 커맨드·exclude·submodule은 §11; byte-faithful·prod-config-미복사
   *속성*은 design에서 locked.)
3. **baseline 봉인:** orchestrator가 `git -C <sandbox> add -A && git -C <sandbox>
   commit`으로 code-under-review 상태를 commit `B`로 고정. `B`(SHA)는 orchestrator가
   보관하는 **immutable** 값 — 이후 verifier가 샌드박스 안에서 무슨 git 조작을 해도
   `B`는 변하지 않는다. §6.7 가드는 항상 `B` 기준.

- verifier `project_dir` = 샌드박스 경로 (frozen).
- gate 종료 시 **verdict 무관 샌드박스 통째 제거**(namespace-guarded remove). 샌드박스는
  버려지므로 verifier가 그 안에서 commit을 해도 product에 닿지 못한다 — **무커밋은
  behavioral 규칙이 아니라 discard로 인한 구조적 결과**.
- kill switch `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1` → 샌드박스 끄면 현재 read-only
  smoke-test 동작으로 graceful fallback + **loud log 한 줄**.

### 6.4 spec AC 대비 기능 단언

- **입력 계약(locked):** SKILL이 spec의 Acceptance Criteria를 **구조화 입력**(AC
  리스트: `{ac_id, text}`)으로 verifier에 thread한다(신규 입력 필드, `discover-spec.sh`
  출력 재사용). 현재 verifier는 spec을 받지 않으므로 이는 실제 입력 계약 확장.
- **flow 도출(locked):** verifier는 각 testable AC를 구체 flow로 *추론*하되, 산출한
  모든 단언은 (a) 대응 `ac_id`를 인용하고 (b) 구체 evidence를 인용해야 한다. 즉 도출은
  reasoned이지만 출력은 ac_id-bound + evidence-bound라 검증 가능(자유 추론의 비결정성
  ≠ 무근거 단언).
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
2. **Execution Plan 확정.** **발화 조건(mechanical, locked):** `detect-runtime.sh`
   출력에 `requires_decision: true` surface가 **1개 이상** 존재하고 그것을 pre-answer
   하는 arg(`gate=`/`skip_runtime`/명시 surface 선택)가 없을 때 → AskUserQuestion.
   그 외(순수-로컬 only / review-only / arg로 pre-answer됨) → plan 1줄 표시 +
   zero-click 진행. ("scope 모호" 같은 주관적 trigger는 두지 않음 — detect-runtime
   출력만으로 결정.) 확정 항목:
   - **gate 범위:** review만 / runtime만 / 둘 다.
   - **runtime 실행 범위:** pure-local test runner는 자동, `requires_decision`
     surface 목록 제시(opt-in/out).
   - **block 정책:** setup 자동수정 소진 후 막혔을 때 → `stop` / `skip` / `ask`.
3. 확정 plan대로 review → runtime을 **재질문 없이** 실행. **upfront 승인이 권위**다 —
   upfront에서 opt-in된 surface는 mid-run에서 *다시 묻지 않는다*. mid-run
   AskUserQuestion은 *실행 중 새로 발견된* block(setup 소진/런타임 안전 이슈)에 대해
   block 정책=`ask`일 때만 발화(§6.6, §6.8 precedence).

### 6.6 Blocked-path 처리

executor가 surface 실행 중 **block**(완료 불가)되면:

| block 종류 | 처리 |
|---|---|
| setup-fixable (.env·deps 누락) | 샌드박스에서 자동수정 + retry (executor 내부, **≤3/dispatch**). 성공→계속 / 소진→escalate |
| operational-safety 위반 (prod config/네트워크 필요) | **실행 안 함**. blocked-for-safety 기록 → NEEDS_RESOLUTION("test config 제공") 또는 SKIP. prod 대상 자동 실행 금지 |
| needs-decision (requires_decision인데 upfront 미승인) | NEEDS_RESOLUTION |
| product 버그 (AC 불충족 / product 결함으로 안 뜸) | FAIL + evidence (+선택 evidence-only 후보 diff). retry 아님 — verdict |
| hang/timeout | surface별 wall-clock kill, blocked 기록, 나머지 surface 계속 |

**block 이후 라우팅:**

- **per-surface 격리:** 한 surface block이 gate 전체를 abort하지 않음 — 나머지
  surface attempt 후 집계(기존 "모든 surface attempt" 불변과 정합).
- **bounded 해소 루프:** setup-fixable → executor-내부 자동수정+retry ≤3/dispatch.
  소진 시 executor가 NEEDS_RESOLUTION emit → SKILL이 **upfront block 정책** 적용:
  - `stop` → gate를 block 지점에서 abort, terminal 요약.
  - `skip` → blocked surface를 SKIP_WITH_EVIDENCE로 기록 후 나머지로 계속, partial
    결과로 finalize.
  - `ask` → AskUserQuestion(retry / skip-with-evidence / stop); retry 시 executor
    re-dispatch(iteration++).
- **SKILL re-dispatch 상한(locked):** `runtime_max_resolutions`(기본 3). executor-내부
  retry(≤3)와 곱한 값이 hard ceiling. 어느 레이어도 무한 루프 불가(P18).
- **`ask` 정책 mid-run 질문 상한(locked):** `ask` 선택 시 발화하는 mid-run
  AskUserQuestion 총 횟수도 `runtime_max_resolutions` 이하 — 소진 시 자동
  skip-with-evidence로 fall through. (§2의 "mid-stream 깜짝 질문 제거" Goal은 *요청하지
  않은* mid-run 질문 대상이며, `ask`는 사용자가 upfront에서 명시 opt-in한 것이라 충돌이
  아니다 — 그래도 P18로 상한.)
- **terminal:** 루프 소진 또는 사용자 중단 → gate가 terminal verdict(FAIL/
  SKIP_WITH_EVIDENCE) emit + block 문서화 + **샌드박스 폐기** + 최종 요약.

### 6.7 Verdict 분류 + 구조적 self-approval 가드

**구조적 가드 (이 설계의 안전 핵심).** gate 종료 시 **orchestrator(SKILL)가
샌드박스의 product-mutation 여부를 git ground-truth로 산출**한다 — verifier의 자기
판단에 의존하지 않는다. 기준은 §6.3에서 봉인한 **immutable baseline commit `B`**:

1. **tracked 파일 변경:** `git -C <sandbox> diff --name-only B --`로 `B` 대비 *tracked*
   파일의 *net* 변경 검출. `B`가 고정 SHA이고 diff가 `B`↔현재 working-tree 비교라
   verifier가 중간에 `git commit`을 하든 말든 net 변경이 잡힌다(commit-agnostic).
   **비어있지 않으면 product 변경 → verdict 강제 ≤FAIL**(PASS 불가), 그 diff를
   evidence로 surface. verifier가 "non-product"라 주장해도 무관 — git-diff가
   authoritative. binary·mode-change(chmod)·symlink 타겟 변경도 tracked 파일이면
   `--name-only`에 파일명이 잡혀 동일 처리.
2. **신규 파일 생성:** `git -C <sandbox> ls-files --others`로 본 신규 파일은
   **git-ignored일 때만 non-product**(`git check-ignore`). 근거: git-ignored 파일은 정상
   경로로 product에 편입 불가(`.env`·deps·build·scratch가 여기 해당) → product 무해.
   git-ignored 아닌 신규 파일(예: `src/newfix.js`) → product-affecting → ≤FAIL. `src/.env.local`
   같은 경계 케이스도 "ignored면 무해(편입 불가), 아니면 product"로 git이 일관 판정 —
   별도 allowlist glob 불필요. **신규 symlink는 타겟 무관 conservative하게
   product-affecting**(타겟이 product/외부 경로를 가리킬 수 있음).
3. 이 산출은 orchestrator가 수행(`B`도 orchestrator가 보관 — verifier가 옮길 수 없음;
   product/main working-tree 미변경). verifier의 `writes:` 분류는 *advisory 진단*일 뿐
   verdict gating의 권위가 아니다. → Law 2 self-approval이 **구조적으로 불가능**.
4. **"후보 diff"의 정체:** verifier가 product를 고쳐 띄우려 시도하면 그 변경이 곧 1번의
   tracked diff다 — 별도 patch 생성 메커니즘이 아니라 **가드가 캡처한 diff 그 자체**가
   evidence-only 후보 diff로 surface되고 *항상* ≤FAIL과 동반된다. 따라서 "후보 diff
   생성이 또 다른 product 변경 아닌가"라는 우려는 성립하지 않는다 — 그 변경은 이미
   가드에 잡혀 downgrade를 유발한 바로 그 diff다.

**verdict 매핑:**
- 기능 단언 실패(폼은 떴는데 AC대로 동작 안 함) → **FAIL** (expected vs observed
  evidence 첨부).
- **fix-to-green:** §6.7 가드가 product 변경을 잡으면 → **절대 PASS 불가**(FAIL/
  NEEDS_RESOLUTION) + diff surface(evidence-only; in-gate accept 없음 — §3 Non-goals).
- **setup-only fix → PASS 가능.** git-ignored 신규 파일(.env·deps)만 + tracked 무변경
  으로 떴다면 정상 PASS 후보.

evidence-log 신규 섹션:
- `writes:` — `{path, class: product|non-product, committed: never}` (advisory 진단).
- `mutation_guard:` — `{tracked_diff: <empty|files>, disallowed_new_files: [...],
  forced_downgrade: yes|no}` (orchestrator 산출, 권위).
- `functional_assertions:` — `{ac_id, flow, expected, observed, evidence_refs,
  verdict}`.

### 6.8 운영 안전

"운영 DB/네트워크 안 터짐"의 teeth:

- **blast-radius 분류** (`detect-runtime.sh`가 surface별로). 분류 기준(대표 케이스):
  - *순수-로컬-결정적* → **자동 실행**: surface kind가 test runner(`pytest`,
    `npm-script:test`, `cargo-test`, `go-test`, `makefile:test`).
  - *프로세스 기동 / 외부 변경 / 파괴 가능 / 불확실* → **`requires_decision: true`**:
    process-start kind(`npm-script:dev|start|serve`, `cargo-run`, `go-run`,
    `makefile:run|serve`), `docker-compose`(기존), 그리고 명령 문자열에 네트워크/배포/
    파괴 신호(`curl`/`wget`/`ssh`/`deploy`/`push`/`rm -rf` 등) 매칭 surface.
  - **불확실 = gate** (deny-by-default).
- **test/isolated config 우선.** 샌드박스는 실제 `.env`(prod 가리킬 수 있음)보다
  `.env.example`/`.env.test`를 우선 사용. **이는 §6.3(c)로 구조적으로 강제** — git-ignored
  파일(기존 `.env` 포함)은 샌드박스에 *복사되지 않으므로*, prod `.env`가 샌드박스 실행에
  쓰여 운영 DB/네트워크에 닿는 경로가 원천 차단된다. config가 필요하면 verifier가
  `.env.example`→`.env`로 setup 자동수정(§6.6). 띄우려면 *반드시* prod 자격증명/엔드포인트가
  필요한 surface는 자동 실행이 아니라 `requires_decision`/거부.
- **판단 주체 = verifier(inherit).** `requires_decision` surface에 대해 verifier가
  보안·운영 영향 요약(네트워크 egress? 외부 mutation? 파괴적? 과금?)을 제시.
- **upfront와의 precedence(중복 제거):** 운영 안전 영향 요약은 upfront plan(§6.5)에서
  사용자가 판단·승인한다. upfront에서 opt-in된 surface는 **mid-run 재질문 없음**.
  mid-run NEEDS_RESOLUTION은 *실행 중 새로 드러난* 안전 이슈(예: 런타임에 prod
  엔드포인트 접근 시도 감지)에만 발화.

### 6.9 Law 2 scoped exception 문서화

- **README "Principles Instantiated":** 현 Law 2 bullet(runtime-verifier가
  `disallowedTools: [Write, Edit, ...]` 자랑)을 재작성 — runtime-verifier는
  **sandbox-executor**이며 Law 2 준수는 *git worktree 격리 + git-diff product-mutation
  가드(orchestrator 산출, 권위) + 무커밋*으로 달성됨을 명시. 즉 "도구 deny" → "git
  ground-truth 가드"로 *물리적 보장의 형태가 바뀐 것*이지 보장이 사라진 것이 아님을
  강조. **test-scope-validator는 순수 read-only reviewer로 그대로**(disallowedTools
  유지)임을 대비로 명확화.
- **`docs/philosophy/devbrew-harness-philosophy.md` + `CLAUDE.md`:** runtime gate
  executor를 *문서화된 scoped exception*으로 note 추가 (Law 본문 rewrite 아닌 가벼운
  단서 — "executor는 도구-deny가 아닌 git-diff 가드로 Law 2 self-approval을 구조적으로
  차단"). TOC 동기화.
- 신규 원칙 bullet: 운영-안전 게이트(blast-radius), 기능 단언(spec AC), upfront plan.

## 7. Acceptance Criteria

1. **AC1 (frontmatter):** `runtime-verifier.md`가 `model: inherit`, `allowedTools`에
   `Write`/`Edit`/`MultiEdit` + 상호작용 MCP(`click`/`fill`/`type_text`/…),
   `disallowedTools`에서 `Write`/`Edit`/`MultiEdit` 제거(NotebookEdit는 deny 유지).
2. **AC2 (blast-radius):** `detect-runtime.sh`가 process-start/docker/네트워크-신호
   surface를 `requires_decision: true`로 표시; test runner kind는 `requires_decision`
   없이 자동. (fixture별 출력 assert)
3. **AC3 (샌드박스, behavioral):** SKILL이 **git worktree** 샌드박스를 생성하되 *주
   working-tree의 uncommitted 변경이 byte-faithful 반영*된다 — text뿐 아니라 binary·
   mode-change·symlink 변경도 봉인 `B`에 정확히 반영(§9 baseline 충실도 테스트).
   git-ignored 파일(prod `.env` 등)은 미복사(§6.3c). gate 종료 시 verdict 무관 제거.
   gate는 아무것도 commit 안 함. (커맨드 세부는 plan; 이 *동작/속성*은 testable)
4. **AC4 (upfront plan):** `requires_decision` surface ≥1 이고 pre-answer arg 없을
   때만 실행 전 1회 plan 확정(gate 범위·runtime 범위·block 정책); 순수-로컬/review-only/
   arg-answered는 zero-click. upfront 승인된 surface는 mid-run 재질문 0회.
5. **AC5 (운영 안전):** 샌드박스가 test/isolated config 우선; prod 자격증명/엔드포인트가
   필요한 surface는 `requires_decision`/거부 — prod 대상 자동 실행 0건. (prod-pointing
   `.env` fixture로 회귀)
6. **AC6 (기능 단언, testable):** spec(AC 포함) 존재 시 evidence-log의
   `functional_assertions`에 `ac_id`↔flow↔`evidence_refs` 매핑 엔트리 ≥1; spec 부재 시
   fallback 모드가 loud-log 1줄. (evidence-log 구조 + 로그 라인 assert; 추론 알고리즘
   자체는 비고정)
7. **AC7 (verdict + 가드):** orchestrator가 **immutable baseline `B`** 대비 `git diff`로
   tracked 변경 검출 시 verdict 강제 ≤FAIL(PASS 불가) + diff surface; **git-ignored 아닌
   신규 파일**(및 신규 symlink)도 동일; git-ignored 신규 파일(.env/deps)만 + tracked
   무변경은 PASS 가능. `mutation_guard.forced_downgrade`가 verifier 주장과 무관하게 git
   결과로 결정됨(독립성은 §9 테스트로 검증).
8. **AC8 (fix-loop bounded):** executor-내부 setup retry ≤3/dispatch, SKILL re-dispatch
   ≤`runtime_max_resolutions`; product 변경은 자동수정 대상 아님(가드로 ≤FAIL).
9. **AC9 (blocked-path):** block 종류별 처리·per-surface 격리·정책별(stop/skip/ask)
   라우팅·terminal verdict·샌드박스 폐기가 모두 정의·구현; 무한 루프 불가(상한 수치
   명시).
10. **AC10 (Law 2 docs):** README/philosophy/CLAUDE.md가 git-diff 가드 기반 scoped
    exception 문서화; `test-scope-validator`는 disallowedTools(Write/Edit) 불변.
11. **AC11 (버전·CHANGELOG):** `plugin.json` 2.2.0; `CHANGELOG.md` `[2.2.0]`에
    Added/Changed/Security; `e2e-scenarios.md`의 stale `runtime-verifier:
    model=sonnet, cost_class=low` 갱신.
12. **AC12 (kill switch):** `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1` → read-only
    smoke-test로 graceful fallback + loud log.
13. **AC13 (cost):** cost_class `variable` 유지; web-functional 무거운 경로 진입 전
    SKILL이 1줄 cost heads-up.

## 8. Files to Modify

- **`plugins/quality-gates/agents/runtime-verifier.md`** — frontmatter(model
  inherit, allowedTools 확장, disallowed 정리) + body 재작성(executor 정체성, AC 단언
  절차, evidence-log 신규 섹션 `mutation_guard`/`functional_assertions`, blast-radius
  판단, 운영 안전, "product 고쳐 PASS 금지" 명시).
- **`plugins/quality-gates/scripts/detect-runtime.sh`** — surface별 blast-radius
  분류(`requires_decision`); test runner kind는 자동.
- **`plugins/quality-gates/skills/quality-pipeline/SKILL.md`** — Upfront Execution
  Plan(§6.5), 샌드박스 create/discard 배선, spec AC thread, **git-diff mutation
  가드 산출 + verdict 강제 강등**(§6.7), blocked-path 라우팅(§6.6), 운영 안전
  precedence(§6.8), cost heads-up. 최종 요약 v2.2.0.
- **`plugins/quality-gates/scripts/qg-worktree.sh`** — working-tree 반영 샌드박스용
  신규 subcommand(create-from-worktree + remove); `rt-<sid>` prefix. (신규 helper
  만들지 않음)
- **`plugins/quality-gates/.claude-plugin/plugin.json`** — version 2.2.0.
- **`plugins/quality-gates/CHANGELOG.md`** — `[2.2.0]` Added/Changed/Security.
- **`plugins/quality-gates/README.md`** — Law 2 bullet 재작성(git-diff 가드) + 신규
  원칙(운영-안전·기능 단언·upfront plan) + model=inherit·table 갱신.
- **테스트:**
  - `tests/test_runtime_verifier_frontmatter.sh` **재작성** — model inherit, Write/Edit
    in allowedTools, 상호작용 도구, body의 sandbox/mutation-guard/무커밋 contract assert.
  - `tests/test_runtime_verifier_behavior.py` 확장 — 기능 단언·write 분류·증거-접지.
  - **신규** — 샌드박스 uncommitted 반영(AC3), **git-diff 가드 강등(AC7, product write
    유발 fixture → verdict ≠ PASS + diff surface)**, 운영-안전(prod config 거부),
    upfront plan/scope 게이트(AC4), blocked-path 라우팅(AC9).
  - `tests/test_detect_runtime.sh` 확장 — blast-radius 분류 assert(AC2).
  - `tests/e2e-scenarios.md:136` stale 갱신.
- **`docs/philosophy/devbrew-harness-philosophy.md` + `/CLAUDE.md`** — git-diff 가드
  기반 scoped exception note (light touch; TOC 동기화).

## 9. Verification Plan

- **자동:** 위 bash/py 테스트를 **repo root에서** 실행(qg 테스트 cwd 계약). qg는 CI가
  없고 main에 기존 stale red(codex/consent/security/sandbox)가 있으므로 작업 전
  **baseline 캡처** 후 신규/수정 테스트의 green만 회귀 판정.
- **핵심 positive 테스트 (reviewer 지적 반영):** `git status clean`만으로는 격리를
  증명 못 한다(샌드박스가 분리 경로면 항상 clean). 따라서 **product write를 *일부러*
  유발하는 fixture**(앱이 tracked 소스 1줄 수정 후에만 부팅) → orchestrator git-diff
  가드가 `forced_downgrade: yes` + verdict ≠ PASS + diff surface임을 assert(AC7). 이게
  fix-to-green 차단의 실제 검증.
- **독립성 테스트 (round 2 반영):** verifier가 `mutation_guard.forced_downgrade: no`
  (또는 자기 write를 non-product라) 주장하도록 만든 stub + 실제 tracked 변경이 있는
  fixture → orchestrator git-diff가 verifier 주장을 *override*해 ≤FAIL을 강제함을 assert.
  "orchestrator가 verifier 판단을 passthrough"하는 구현 버그를 잡는다.
- **baseline 충실도 테스트 (round 3 반영):** working-tree에 binary 변경·mode-change
  (chmod +x)·symlink를 심은 fixture → 샌드박스 봉인 `B`가 그 변경을 *정확히* 반영함을
  assert(`git apply` silent-loss로 B가 불완전 봉인되는 회귀 차단).
- **git-ignore 경계 테스트 (round 3 반영):** (i) verifier가 git-ignored 신규 파일
  (`.env`) 생성 → non-product, PASS 가능; (ii) git-ignored 아닌 신규 파일(`src/x.js`)
  생성 → product-affecting, ≤FAIL; (iii) prod-pointing `.env`(git-ignored)가 샌드박스에
  복사되지 *않음*(§6.3c) assert.
- **수동(2개 fixture):**
  - `tests/fixtures/gate3/web-compose/` — web 경로: scope 게이트 발화 → 샌드박스 기동 →
    상호작용 단언 → 샌드박스 폐기 → 주 working-tree `git status` clean.
  - CLI fixture(신규 작성) — CLI 경로: requires_decision 확인 → 자동 실행 거부/허용 →
    AC 대비 stdout 검증 → 샌드박스 폐기.
- **운영 안전 회귀:** prod-pointing `.env` fixture에서 자동 실행 0건 + 거부 경로 확인.
- **Law 2 회귀:** `test-scope-validator` disallowedTools 불변 + verifier가 product
  diff를 commit하지 않음 + git-diff 가드가 verifier 주장과 독립적으로 동작함 확인.

## 10. Rejected Alternatives

- **executor/reviewer 별도 agent 분리** (Law 2 무수정 순수) — verifier를 read-only
  reviewer로 두고 write executor를 신설. agent+handoff 표면 증가(두 dispatch가 한
  샌드박스 공유) 비용으로 기각; git-diff 가드(§6.7)가 단일 agent로도 self-approval을
  구조적으로 막으므로 분리 불필요.
- **product 버그 자동 수정 후 verifier 자체 green** — git-diff 가드가 *구조적으로*
  차단. 기각.
- **product 버그 수정 + 독립 reviewer가 fix를 green 판정(2-agent)** — surface 증가.
  현 범위에서 기각(향후 별도 작업 가능).
- **dir-copy 샌드박스** — §6.7 git-diff 가드가 git 컨텍스트를 요구하므로 탈락. git
  worktree 확정.
- **`git diff HEAD | git apply`로 델타 재현** — binary/mode/symlink에서 silent
  partial-apply가 있어 baseline `B`를 불완전 봉인할 수 있음(round 3 [a4f2c8e1]). `--3way`
  도 충돌 시 불완전. → tracked 파일 **byte-faithful 복사**(`cp -a`/`rsync -a`)로 확정,
  binary/mode/symlink 보존(§6.3).
- **`.env*`/build glob allowlist로 non-product 판정** — `src/.env.local`·`dist/main.js`
  류 경계 우회 가능(round 3 [c1e6b4d2]). → **git-ignore 상태**(`git check-ignore`)를
  canonical 기준으로 확정 — git-ignored면 product 편입 불가라 무해(§6.7-2).
- **네트워크 egress 차단 샌드박스** — 외부 의존 서비스 실행과 충돌. 운영 안전은
  test-config + 판단 게이트로 충분하므로 deferred.
- **upfront plan 무조건 항상 prompt** — zero-click happy path 가치와 충돌.
  `requires_decision` 존재 시에만 prompt로 절충.
- **후보 diff: surface vs 미surface.** product 변경 시 단순 FAIL만 낼 수도 있으나,
  §6.7 가드가 그 diff를 *이미* 산출하므로 evidence로 surface하는 한계비용·위험이 0이고
  사용자에게 "뜨려면 이 변경이 필요했다"는 actionable 진단을 준다. in-gate apply는 안
  하므로(§3) self-approval 위험도 없음. → surface 채택(diff 미생성/미surface 대안 기각).
- **3.0.0 major bump — 영향 분석.** Law 2 메커니즘이 "도구 deny → git-diff 가드"로
  바뀌지만, `runtime-verifier`는 quality-pipeline SKILL만 dispatch하는 **qg 내부
  agent**이고 "disallowedTools: Write"는 외부에 약속된 공개 계약이 아니라 내부 격리
  세부다. 외부 표면(`/qg` command)은 하위호환(zero-click happy path 보존, 신능력은
  additive + gated, 기존 arg 존중). 따라서 제거·비호환 변경 없는 **additive surface =
  minor**가 SemVer-defensible. 보안 메커니즘 이전은 CHANGELOG `Security` note로
  auditor에게 명시. → 사용자 선택(2.2.0)과 semantic 근거 일치.

## 11. Open Questions (plan 단계 세부)

설계 결정은 모두 closed. 다음은 *구현 세부*로 writing-plans에서 결정(설계 공백 아님):

- **byte-faithful 복사의 정확한 커맨드·exclude** — `cp -a` vs `rsync -a`, `.git`·샌드박스
  자기경로·대용량 dep 디렉토리 exclude, submodule 처리, 성능. (§6.3 메커니즘은 "worktree
  from HEAD + tracked byte-faithful 복사 + git-ignored 미복사 + baseline commit `B` 봉인"
  으로 locked; baseline `B` 고정·byte-faithful·prod-config-미복사 *속성*은 design-level
  locked — 커맨드 선택만 plan.)
- **chrome-devtools 상호작용 도구의 실제 가용 subset** — 환경에서 available한 MCP 도구
  확인 후 §6.2 목록 최종 확정.
- **AC prose → browser step 추론의 프롬프트 구조** — verifier 프롬프트에서 testable AC
  선별·flow 도출을 어떻게 안내할지(입력=AC 리스트로 locked; 프롬프트 wording만 plan).
- **CLI AC-단언 fixture 신규 작성** — 대표 CLI 프로젝트 fixture 형태.

## 12. Handoff Context

**TL;DR (핵심 결정 3줄).**
1. runtime-verifier를 read-only 관찰자 → git-worktree 샌드박스에서 서비스를 띄우고
   user flow를 구동하며 spec AC 대비 동작을 단언하는 sandbox-executor로 (model inherit).
2. Write를 주되 **orchestrator의 git-diff 가드**가 product 변경을 ground-truth로 잡아
   PASS를 구조적으로 차단 → Law 2 self-approval 불가, 무커밋.
3. 운영 안전 최우선: blast-radius 분류 + upfront 1회 승인(requires_decision 있을 때만)
   + test-config-only → 운영 DB/네트워크 절대 미접근. v2.2.0 minor.

**Implicit context (brainstorming에서 결정, 코드만 봐선 안 보이는 것).**
- 사용자는 *운영 안전 > 자율성*을 명확히 우선(직접 발화: "운영db네트워크 등에 문제가
  터져선 안되겠고").
- Law 2 정합 방식으로 *scoped exception 문서화*를 선택(agent 분리·Law reframe 대신).
- fix 루프는 *setup만* 자동 — product 버그 자동수정은 명시 거부(self-approval 우려).
- version은 3.0.0 추천을 누르고 *2.2.0 minor* 선택; §10 영향 분석이 이를 뒷받침.
- zero-click happy path는 보존할 가치로 합의 — upfront plan은 위험할 때만 발화.

**Deferred to plan (§11 요약).** git 포착 커맨드 / chrome-devtools 도구 가용 subset /
AC→step 프롬프트 wording / CLI fixture — 전부 구현 세부, 설계 공백 아님.

## 13. Metadata

- **Plugin:** quality-gates
- **Version:** v2.1.0 → **v2.2.0** (minor — §10 영향 분석)
- **요청자:** 사용자 (2026-05-31 brainstorming 세션)
- **관련 선행 작업:** v2.1.0 spec-as-truth(#75, discover-spec.sh), v1.8.0 evidence-
  required SKIP, v1.14.0/worktree-cwd-contract, gate3-active-verification(runtime
  gate origin).
- **헌장 영향:** Law 2 scoped exception (git-diff 가드; CLAUDE.md + philosophy note),
  신규 kill switch `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX`.
- **보안-민감:** persona(runtime-verifier.md) 편집 + Law 2 메커니즘 이전(도구 deny →
  git-diff 가드) — 신중 리뷰 대상.

## 14. Review revisions

- **round 1 (spec-reviewer, 2026-05-31):** needs_revise 12건 전부 반영.
  - self-approval 구조적 보장 누락(a1b2c3d4) → §6.7 **git-diff mutation 가드**
    신설(orchestrator 산출, verifier 주장과 독립). 핵심 보강.
  - product/non-product 분류 기준 미정의(b3c4d5e6) → §6.7 canonical 정의(tracked 변경
    = product; 신규 파일은 non-product allowlist).
  - AC3/AC6 untestable(c5d6e7f8, e9f0a1b2) → behavioral AC로 재작성 + 메커니즘/입력
    계약 locked, Open Question에서 제거.
  - upfront 발화 조건 모호(d7e8f9a0) → mechanical(`requires_decision` ≥1) 확정.
  - 운영안전 vs upfront 중복(f1a2b3c4) → §6.8 precedence(upfront 권위, mid-run 재질문
    없음).
  - SKILL re-dispatch 상한 미정(a3b4c5d6) → §6.6 수치 확정(≤runtime_max_resolutions).
  - 후보 diff scope creep(b5c6d7e8) → §3 Non-goals(evidence-only, in-gate accept 없음).
  - SemVer 근거 빈약(c7d8e9f0) → §10 영향 분석.
  - verification git-status 불충분(d9e0f1a2) → §9 product-write 유발 positive 테스트.
  - 경로/파일 OR placeholder(e1f2a3b4) → §6.3/§8 path·helper locked.
  - Handoff Context 부재(f3a4b5c6) → §12 신설.
- **round 2 (spec-reviewer, 2026-05-31):** needs_revise 7건(11/12 round-1 해소 확인,
  신규는 git-diff 가드 신뢰성을 더 파고든 것). 전부 반영.
  - baseline-ref 산정 주체/시점 미정의(3a9f1c2e) → §6.3 **immutable baseline commit `B`
    봉인**(orchestrator가 샌드박스 생성 시 고정, verifier 변경 불가) + §6.7 가드가 `B`
    기준.
  - sandbox 내 `git commit` 차단 모호(7b4d2e8a) → §6.3 "무커밋은 discard의 구조적
    결과" + §6.7 commit-agnostic diff(`B`↔working-tree net 비교)로 commit 무해.
  - git stash vs tree-object feasibility(2c6a4f9d) → §6.3 메커니즘을 `worktree add HEAD
    + apply delta + commit B`로 feasible하게 lock.
  - `Bash` policy 누락(5e1b3d7f) → §6.2 Bash policy 명시(product 안전=가드, host/네트워크
    =§6.8 + OS-sandbox 한계 인정).
  - `ask` mid-run 질문 무상한(8d2e5a1c) → §6.6 `ask` 질문 ≤`runtime_max_resolutions`.
  - 후보 diff 근거·생성 안전성(4f9c7b2a) → §6.7-4 "후보 diff = 가드 캡처 diff 그 자체"
    + §10 surface 채택 근거.
  - 가드 독립성 테스트 부재(1a7e4d3b) → §9 독립성 테스트(verifier 오주장 override).
- **round 3 (spec-reviewer, 2026-05-31):** needs_revise 4건(round-2 7건 전부 closed
  확인; 신규는 가드 edge-case 보안 경계). 전부 반영.
  - `git apply` silent partial-apply로 baseline 불완전 봉인(a4f2c8e1) → §6.3 **byte-faithful
    복사**(`cp -a`/`rsync -a`)로 교체, binary/mode/symlink 보존.
  - binary/mode/symlink 가드 처리 + symlink 우회(b7d3a9f5) → §6.7-1 binary/mode/symlink
    tracked 변경 잡힘 명시 + §6.7-2 신규 symlink conservative product-affecting.
  - allowlist canonical 정의 부재(c1e6b4d2) → §6.7-2를 **git-ignore 기반**(`git
    check-ignore`)으로 재정의 — glob allowlist 폐기, 경계 우회 제거.
  - untracked prod `.env` 복사로 운영 접근(d9a5f7c3) → §6.3(c) git-ignored 파일 미복사
    (prod `.env` 차단) + §6.8 구조적 강제 cross-ref.
