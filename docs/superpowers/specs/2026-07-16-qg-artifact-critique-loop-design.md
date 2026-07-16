# 설계: quality-gates 산출물 비평-수정 루프 모드 (v2.11.0)

> **한 줄 정체성:** 비-코드 산출물(문서·스펙·제안서·계획·설정·산문)을 대상으로,
> inherit-tier 강한 모델이 **비판 → 오케스트레이터가 수정 → 재비판**을 자율 반복하는
> `/qg`의 신규 모드. 버저닝은 라운드별 git 커밋.

- **플러그인:** `quality-gates`
- **버전:** `2.10.3 → 2.11.0` (minor — 새 표면)
- **브랜치:** `feature/qg-artifact-critique` (base `819da27`)
- **상태:** brainstorming 승인 → 이 설계 문서(리뷰 라운드 1 반영) → writing-plans 대기

## 목차

- [§1 Context / Why](#1-context--why)
- [§2 Goals](#2-goals)
- [§3 Non-goals](#3-non-goals)
- [§4 Constraints](#4-constraints)
- [§5 아키텍처 — 호출 & 라우팅](#5-아키텍처--호출--라우팅)
- [§6 아키텍처 — 루프 구조](#6-아키텍처--루프-구조)
- [§7 아키텍처 — 컴포넌트 & Law 2](#7-아키텍처--컴포넌트--law-2)
- [§8 종료 조건 & 안전장치](#8-종료-조건--안전장치)
- [§9 비평 루브릭](#9-비평-루브릭)
- [§10 데이터 계약 (finding & verdict 스키마)](#10-데이터-계약-finding--verdict-스키마)
- [§11 Acceptance Criteria](#11-acceptance-criteria)
- [§12 Files to Modify](#12-files-to-modify)
- [§13 Verification Plan](#13-verification-plan)
- [§14 Rejected Alternatives](#14-rejected-alternatives)
- [§15 Handoff Context](#15-handoff-context)
- [§16 Metadata](#16-metadata)

## §1 Context / Why

현재 `/qg`는 **코드 구현 QA에 치우쳐** 있다. Review 게이트(security-reviewer +
adversarial + optional codex, 전부 read-only)는 코드 diff의 보안 exploit·test-scope를
보고, Runtime 게이트(runtime-verifier)는 앱을 부팅해 spec AC 대비 동작을 검증한다.
두 게이트 모두 **코드-diff/실행**을 전제로 한다.

하지만 실제로 리뷰가 필요한 산출물의 상당수는 코드가 아니다 — 설계 문서, 스펙,
제안서, 계획, 설정 파일, 산문. 이들에 대해 **inherit-tier의 강한 모델**이 논리·완결성·
근거·품질을 **비판적으로 검토하고, 그 비판을 실제 수정으로 반영**하는 루프가 없다.
사용자는 이 공백을 메우는 `/qg`의 신규 모드를 원한다.

devbrew에는 부분 선례가 있다: spec-distill의 `spec-reviewer`가 *design 문서*를
adversarial하게 검토한다. 이 모드는 그 아이디어를 **임의 산출물로 일반화**하되,
read-only 지적에 그치지 않고 **수정-재검토 루프**를 돌려 산출물을 실제로 개선한다.

## §2 Goals

1. 비-코드 산출물을 대상으로 하는 **비평 → 수정 → 재비평** 자율 루프를 `/qg`의 신규
   모드로 제공.
2. 비평가는 **inherit-tier 모델**(세션 tier 상속 — `model:` frontmatter 미선언)으로
   동작. 값싼 리뷰어로 다운그레이드하지 않음.
3. 각 수정 라운드를 **git 커밋으로 버저닝** — 롤백·diff 검토가 공짜로 따라옴.
4. **자연어 + 명시 인자** 둘 다로 대상 지정 (`/qg critique <path>` 또는
   `/qg 이 문서 비평해줘`).
5. codex가 설치·인증돼 있으면 **model-diversity co-reviewer로 포함**, 없거나 런타임
   실패면 graceful degradation.
6. Law 2(writer ≠ reviewer)·P18(bounded autonomy)·GitHub Flow를 구조적으로 준수.

## §3 Non-goals

- **코드 리뷰 대체 아님.** 기존 2게이트(Review/Runtime)는 무변경. 이 모드는 비-코드
  산출물 전용.
- **spec-distill `spec-reviewer` 대체 아님.** 그것은 interview→design 흐름 전용으로
  유지. 이 모드는 *임의* 산출물 일반화이며, 그 흐름을 건드리지 않는다.
- **Runtime류 실행 검증 아님.** 대상이 비-코드라 부팅할 앱이 없다.
- **코드 파일 대상 아님.** 코드 리뷰 의도로 라우팅되면 기존 파이프라인으로 — §6 E1
  분류 가드가 실질 보장한다.

## §4 Constraints

- **C1 (Law 1):** 이 모드는 코드를 shipping하지 않지만 산출물을 mutate한다. 자율 수정
  전 **upfront 동의 게이트**(§6 E3)가 있어야 한다.
- **C2 (Law 2 — 물리적):** critic·adversarial·codex 리뷰어는 `disallowedTools`로
  `Write`/`Edit`/`MultiEdit`/`NotebookEdit`을 literally 못 함. 수정·커밋은 오케스트레이터
  (writer)만. 매 라운드 **독립 리뷰어 재디스패치**가 승인 게이트 — 자기 편집 자기 승인
  불가.
- **C3 (P18):** 루프는 max-rounds + stagnation + kill switch로 bounded. 무한 루프 금지.
- **C4 (GitHub Flow — 안전 규칙):** **`main`/기본 브랜치에서 자율 커밋 금지.** 이 가드의
  load-bearing 규칙은 "보호 브랜치에 자동 커밋하지 않음"이다 — `feature/*` *강제*가
  아님(브랜치 명명 검증은 project-init 소관이며 `fix/*`도 허용하므로, 이 모드는 non-default
  브랜치이기만 하면 진행). E2·§8·AC8이 동일 규칙을 서술한다.
- **C5 (커밋 위생):** 대상 산출물 경로만 `git add` — `git add -A` 금지(무관 변경
  쓸어담기 방지).
- **C6 (inherit-tier):** 신규 리뷰어 에이전트는 `model:` 키 미선언 → 세션 tier 상속.
  회귀 락으로 강제.
- **C7 (graceful degradation):** codex 부재 **또는 런타임 실패** 시 crash 아닌 downgrade
  + loud log.
- **C8 (버전):** plugin.json bump + CHANGELOG + README 갱신.
- **C9 (데이터 계약):** critic·codex·adversarial·synthesizer가 §10 finding/verdict
  스키마를 공유 — "결정론적 병합·dedup·stagnation"이 스키마 위에서만 성립.

## §5 아키텍처 — 호출 & 라우팅

`/qg`의 커맨드 계층(`commands/qg.md`)이 `$ARGUMENTS`를 보고 **산출물 모드 vs 코드
파이프라인**을 라우팅한다.

| 입력 | 라우팅 | 종류 |
|---|---|---|
| `/qg critique <path>` | 산출물 모드, 명시 대상 | **결정론적** |
| `/qg critique` (경로 없음) | 산출물 모드, 대상은 NL/컨텍스트로 해석 또는 E1에서 확인 | 결정론적 진입 + NL 대상 |
| `/qg <NL critique 의도>` (예: `이 설계문서 비평해줘`) | 모델 해석으로 산출물 모드 | **모델 소유(NL)** |
| bare `/qg`, `/qg both\|review\|runtime\|branch\|--paths ...` | 기존 코드 파이프라인 무변경 | **결정론적** |

**라우팅 철학 (P8 determinism-economy / [[feedback_harness_lightness_trust_model]]):** NL
의도 해석은 모델이 소유(별도 토큰 parser 없음). `critique <path>`는 결정론적 escape hatch.
코드/산출물 의도가 **진짜 모호**할 때만 mode-branch `AskUserQuestion`을 띄우고, 명확하면
안 띄운다 — dominant한 코드 경로에 마찰 0.

**테스트 경계 (리뷰 반영 — codex/Claude):** 위 표의 **결정론적** 행(`critique <path>`,
코드 인자, bare `/qg`)은 **단위 테스트 대상**(고정 입력→고정 라우팅). **모델 소유(NL)**
행은 단위 테스트로 결정론 boundary를 만들지 **않는다** — 그러려면 토큰 parser가 필요해
설계 철학과 충돌하므로, **수동 e2e로만 검증**한다. 대표 예(예시일 뿐, 결정론 계약 아님):
"이 설계문서 비평/검토해줘"→산출물, "PR 리뷰해줘"→코드, 모호한 "이거 봐줘"→§6 E1의
모호 분기(AskUserQuestion 확인). 즉 AC1의 검증은 *결정론 라우팅=단위테스트 /
NL 라우팅=수동 e2e*로 명확히 이원화된다.

**"맨 처음 ask question으로 분기"의 의미:** 이 모드의 첫 동작인 §6 upfront 게이트
(대상 확정 + 실행 동의)가 그 분기다. 산출물 모드로 진입한 뒤 파일에 손대기 전에
반드시 fire한다.

산출물 모드로 라우팅되면 커맨드는 신규 skill
`Skill("quality-gates:critiquing-artifacts")`를 호출한다(기존 `quality-pipeline`
대신). 이로써 `quality-pipeline` SKILL(786줄)은 무변경 — write-capable 문서 루프가
read-only 코드 게이트 파이프라인에 섞이지 않는다.

## §6 아키텍처 — 루프 구조

`critiquing-artifacts` SKILL이 단일 턴에서 다음을 실행한다.

**진입 (파일 손대기 전):**
- **E0** Preflight — 전역 kill switch(`DEVBREW_DISABLE_QUALITY_GATES=1`) + 모드 전용
  kill(`DEVBREW_QG_DISABLE_CRITIQUE=1`) 존중.
- **E1** 대상 해석 + **코드/비-코드 분류**(Non-goal 실질 가드):
  - **코드 확장자 allowlist**(`.py .js .ts .tsx .jsx .go .rs .java .kt .c .h .cpp .cc .rb .php .swift .scala .sh .bash .zsh` 등) → 코드로 판정 → "코드 리뷰는 `/qg`로" 안내 후 **종료**.
  - **비-코드 확장자**(`.md .markdown .txt .rst .adoc .org` + 문서화용 텍스트) → 산출물 모드 진행.
  - **모호**(확장자 없음 / allowlist·비-코드 목록 어디에도 없는 확장자 / 경계 사례) →
    E3 *이전에* `AskUserQuestion`으로 "이 파일을 산출물로 비평할까요?" 확인. **확인 없이
    자율 루프 진입 금지.** 이로써 코드가 security-reviewer 없는 prose-critic 자율 커밋
    루프로 새어들지 않는다.
  - allowlist는 결정론적(테스트 대상). 확장자 목록의 정확한 최종본은 plan에서 확정하되,
    "코드 확장자→종료 / 비-코드→진행 / 모호→확인"의 **3분기 계약은 이 설계가 고정**한다.
- **E2** 브랜치 안전(§8/C4) — `main`/기본 브랜치면 **거부**, non-default 브랜치 안내 후 종료.
- **E3** Upfront 게이트 (`AskUserQuestion`): *"대상=`<resolved path>`, 최대 5라운드
  비평-수정 루프를 브랜치 `<branch>`에 라운드별 커밋하며 실행할까요?"*
  → **실행** / **대상 변경** / **취소**. (라운드 수는 고정 상수 `max_rounds=5`(§8) —
  게이트는 N을 사용자에게 묻지 않는다; 문구의 "5"는 그 고정값을 알리는 것.)

**루프 (라운드 N = 1..max_rounds, §8):**
1. **critic** — `artifact-critic`(inherit-tier, read-only) 디스패치. *현재 커밋된*
   산출물을 §9 루브릭으로 검토 → §10 Finding 스키마 출력. `project_dir` 스레딩.
2. **codex co-reviewer (조건부)** — `detect_codex.sh`가 `codex_available: true`면
   문서-shaped 프롬프트(`build_artifact_codex_prompt.py`, §7)로 병렬 dispatch →
   §10 Finding 스키마로 병합.
   - `codex_available: false` → inherit-only + `> [quality-gates] codex 미가용(<skip_reason>) — inherit-tier 단독 비평.`
   - **가용 판정 후 런타임 실패**(nonzero exit / 파싱 실패 / timeout) → inherit-only +
     `> [quality-gates] codex 가용 판정 후 런타임 실패(<reason>) — degraded, inherit-tier 단독.` (crash 아님, C7)
3. **adversarial** — `artifact-adversarial`(inherit-tier, read-only)가 §10 verdict
   스키마로 finding을 반박·강화(FP=`reject`/`downgrade` + 놓친 것 추가). *자율 수정
   루프라 이 FP 거름망이 read-only 리뷰 때보다 load-bearing — 잘못된 지적이 실제 편집으로
   증폭되는 것을 커밋 전 차단.*
4. **synthesize** — §10 canonical-key로 결정론적 dedup + adversarial verdict 반영 →
   **kept 집합** 산출(`synthesize_findings.py` 계열 확장, §7).
5. **수렴 체크** (`convergence-check`, 순수 함수) — kept 중 CRITICAL/IMPORTANT == 0 →
   **수렴, 루프 종료**. SUGGESTION만 남으면 수렴으로 간주(목록만 surface, 수정 안 함).
6. **수정 적용** — 오케스트레이터(writer)가 kept CRITICAL/IMPORTANT를 해소하도록
   산출물을 `Edit`/`Write`. 리뷰어가 제안한 경로는 `path-auth`(canonicalize,
   symlink escape 방지 — 기존 Retry: file-write safety 재사용)로 검증.
7. **커밋** (`commit-scope`) — **대상 파일만** 명시 `git add <artifact-path>`(§C5) 후
   원자적 커밋: 메시지 `critique(round N): <해소한 finding 요약>`.
8. **stagnation 체크** (`stagnation-check`, 순수 함수 — §8 predicate) → 정체 시 종료.
9. N+1로 반복.

## §7 아키텍처 — 컴포넌트 & Law 2

**신규 에이전트 (둘 다 `model:` 미선언 → inherit-tier; read-only):**
- `artifact-critic` — 산출물을 §9 루브릭으로 비판, §10 Finding 스키마 생산.
  역할 프롬프트: *"You are the artifact critic. You are responsible for finding
  logical gaps, unstated assumptions, incompleteness, and ambiguity in a non-code
  artifact. You are NOT responsible for writing code, editing the artifact, or
  reviewing code diffs."*
- `artifact-adversarial` — critic findings를 §10 verdict 스키마로 반박·강화. 기존
  opus-핀 `adversarial`을 재사용하지 **않음**(§14 참조).

**결정론 헬퍼 (테스트 가능한 순수 단위 — isolation 지적 반영):**
- `synthesize` — canonical-key dedup + verdict 반영 → kept 집합 (`synthesize_findings.py` 확장/재사용).
- `convergence-check` — kept 집합 → `converged: bool` (CRITICAL/IMPORTANT count == 0).
- `stagnation-check` — (이번 kept, 직전 kept, git-diff 결과) → `stagnant: bool` (§8 predicate).
- `path-auth` — (project_dir, 후보 경로) → canonical 경로 or reject (symlink escape 가드).
- `commit-scope` — (artifact_path) → 대상 경로만 add + 커밋 (`-A` 금지).
각 헬퍼는 model dispatch·파일 편집과 독립적으로 단위 테스트된다.

**신규 스크립트:**
- `build_artifact_codex_prompt.py` — 문서-shaped codex 프롬프트 빌더(기존
  `build_codex_prompt.py`는 코드-diff+spec AC 전용이라 재사용 불가; 산출물 내용 +
  §9 루브릭을 입력으로 codex 프롬프트 구성). *이름은 이 설계에서 확정.*
- 위 결정론 헬퍼는 신규 스크립트 또는 SKILL 인라인 — 최종 파일 경계는 plan에서 확정하되
  **인터페이스(입력→출력)는 이 설계가 고정**.

**재사용:** `detect_codex.sh`(순수 가용성 체크), Retry: file-write safety 캐노니컬라이제이션,
`render-terminal.py`(최종 요약 표).

**Law 2 보증 (C2):**
- critic·adversarial·codex는 `disallowedTools`로 쓰기 tool 불가.
- 수정·커밋은 오케스트레이터만.
- **매 라운드 독립 critic이 게이트:** 라운드 N의 수정을 라운드 N+1의 *독립* critic이
  재검토. 최종 "수렴" 판정은 마지막 독립 critic 패스의 kept 집합(§10)이 결정 —
  오케스트레이터가 자기 편집을 자기 판단으로 승인하는 경로가 구조적으로 없다.
  (기존 Review 게이트 Retry 루프 + honest-verdict floor와 동형.)

## §8 종료 조건 & 안전장치

- **종료 (넷 중 하나):**
  1. **수렴** — kept CRITICAL/IMPORTANT == 0 (`convergence-check`).
  2. **max-rounds** — `max_rounds = 5` (고정 상수, Review 게이트와 대칭). env override
     `DEVBREW_QG_CRITIQUE_MAX_ROUNDS`(정수, 0..10 clamp)로만 조정 — E3 게이트는 N을
     사용자에게 묻지 않는다.
  3. **stagnation** (`stagnation-check` predicate, 결정론):
     stagnation ⟺ **(a)** 이번 라운드 kept 집합의 canonical-key 집합이 직전 라운드와
     동일(새 key 無 + 미해결 잔존) — set 비교(정확), **또는** **(b)** 수정 적용 후
     `git diff --quiet <artifact>` 참(파일 무변경). 둘 다 새 진전 없음의 결정론 신호.
  4. **kill switch** — 전역 `DEVBREW_DISABLE_QUALITY_GATES=1` + 모드 전용
     `DEVBREW_QG_DISABLE_CRITIQUE=1`.
  → 넷 다 bounded → P18 충족.
- **브랜치 안전 (C4):** `main`/기본 브랜치에서 자율 커밋 **거부**(경고 아님). E2에서
  차단하고 non-default 브랜치 안내.
- **커밋 스코핑 (C5, `commit-scope`):** 대상 산출물 경로만 add — dirty 워킹트리의 무관
  변경 미포함.
- **cost_class & fan-out (거버넌스 정합 — 리뷰 반영):**
  - `cost_class = variable`(라운드 수 의존). worst-case가 high이므로 **E3 upfront 동의
    게이트가 지출-전 명시 승인** — CLAUDE.md의 `high`-cost 규칙("지출 전 명시
    AskUserQuestion")의 취지를 충족한다.
  - **fan-out:** 라운드당 *동시* 디스패치 ≤3(critic + codex + adversarial) < 5 →
    "Fan-out factor N≥5 hard review gate" **미해당**. 누적 최대 15회(3×5)는 max 5라운드에
    걸친 **순차** 실행이며 동시 fan-out(subagent spray)이 아니다 — hard 게이트는 동시성
    척도이지 누적 척도가 아님.

## §9 비평 루브릭 (비-코드 산출물)

`spec-reviewer`를 일반화한 범용 렌즈. critic·adversarial이 공유하며 §10 Finding의
`category` 값이 된다:

- **logic** — 논리 정합성 / 내부 모순(섹션 간 상충, 전제-결론 불일치).
- **assumption** — 미명시 가정(근거 없이 전제된 것).
- **completeness** — 완결성 / 공백(빠진 섹션, 다루지 않은 케이스).
- **evidence** — 근거 / 사실성(뒷받침 없는 주장). *단 critic이 사실을 날조 금지 —
  "근거 없음"으로 flag하되 대체 사실을 지어내지 않음.*
- **ambiguity** — 모호성(두 갈래로 읽히는 문장).
- **actionability** — 스펙·계획의 검증 가능성.
- **structure** — 구조 / 조직(순서·중복·가독성).

각 finding은 severity(CRITICAL/IMPORTANT/SUGGESTION) 태그. 문서 종류 인지하되 범용.
adversarial은 이 축들 위에서 반론·약점을 추가하거나 FP를 `reject`한다.

## §10 데이터 계약 (finding & verdict 스키마)

critic·codex·adversarial·synthesize가 공유하는 machine-readable 계약. 이것이 §6의
"결정론적 병합·dedup"과 §8 stagnation predicate를 구현·테스트 가능하게 만든다(기존 qg
canonical finding YAML과 정렬).

**Finding 스키마** (critic·codex 출력):

```yaml
- agent: artifact-critic        # 또는 codex-reviewer
  category: logic               # §9 루브릭 축
  target: "#5-아키텍처--호출--라우팅"   # 섹션 앵커 또는 라인 범위
  severity: IMPORTANT           # CRITICAL | IMPORTANT | SUGGESTION
  summary: "한 줄 지적"
  proposed_fix: "제안 수정(선택)"
```

**Adversarial verdict 스키마** (adversarial 출력, finding별):

```yaml
- finding_key: "a1b2c3d4e5f6"   # 대상 finding의 canonical key (아래)
  verdict: confirm              # confirm | downgrade | reject
  evidence: "판정 근거"
```

**Canonical key & dedup:** finding의 canonical key =
`sha1(category + "\0" + normalized(target) + "\0" + normalized(summary))[:12]`.
`synthesize`는 같은 key를 dedup하고, adversarial `reject`(제거)·`downgrade`(severity
강등)를 반영해 **kept 집합**을 결정론 산출한다.

**kept 집합:** adversarial `confirm`, 또는 `downgrade` 후 severity ≥ IMPORTANT인
findings. 이 집합이 §6 수렴·수정·stagnation의 **단일 입력** — 세 판정이 동일 자료구조
위에서 동작하므로 각각 독립 단위 테스트 가능(§7 헬퍼).

## §11 Acceptance Criteria

- **AC1 — 라우팅:** `/qg critique <path>`는 명시 대상으로 산출물 모드 진입;
  `/qg <NL critique 의도>`는 모델 해석으로 산출물 모드; bare `/qg` 및 코드
  인자(`both|review|runtime|branch|--paths`)는 기존 코드 파이프라인 무변경.
  **검증 이원화(§5):** 결정론 행=단위 테스트, NL 행=수동 e2e.
- **AC2 — Upfront 게이트:** 파일 쓰기 전 (a) E1 분류, (b) 브랜치 안전 체크, (c) 대상
  확정 + 실행 동의 `AskUserQuestion`(실행/대상변경/취소)이 fire.
- **AC3 — 라운드 파이프라인:** 각 라운드가 critic → (codex if available) →
  adversarial → synthesize → 수렴체크 → 수정 → 커밋 → stagnation체크 순서.
- **AC4 — inherit-tier + read-only:** `artifact-critic`·`artifact-adversarial`
  frontmatter에 `model:` 키 부재(inherit) + `disallowedTools`에 Write/Edit/
  MultiEdit/NotebookEdit 포함.
- **AC5 — codex 조건부 + 런타임 실패 degrade:** `detect_codex.sh` available이면
  `build_artifact_codex_prompt.py`로 문서-shaped co-reviewer 실행; **미가용 또는 가용-후
  런타임 실패**면 inherit-only + loud degradation 라인(둘은 구분된 문구). crash 없음.
- **AC6 — 수렴:** kept CRITICAL/IMPORTANT == 0일 때만 루프 종료(SUGGESTION-only는
  수렴 허용). 수렴 판정은 독립 kept 집합(§10)이 결정(오케스트레이터 자기판단 아님).
- **AC7 — bounded + stagnation predicate:** `max_rounds=5`(env override), §8 stagnation
  predicate((a) canonical-key set 동일 OR (b) `git diff --quiet` 참), kill switch —
  무한 루프 불가. predicate가 결정론이라 단위 테스트 가능.
- **AC8 — 브랜치 안전:** `main`/기본(default) 브랜치에서 파일 손대기 전 거부 +
  non-default 브랜치 안내. (규칙 = 보호 브랜치 자동 커밋 금지; `feature/*` 강제 아님.)
- **AC9 — 커밋 스코핑:** 각 라운드가 대상 경로만 `git add` — `git add -A` 부재.
- **AC10 — Law 2:** writer(오케스트레이터) ≠ reviewer(subagent); 라운드 수정은
  후속 독립 critic 패스가 게이트; 독립 kept 집합이 남은 채 자기-certify 불가.
- **AC11 — 출력:** 최종 요약이 라운드별 히스토리 + 커밋 SHA + (중단 시) 잔여 kept 집합.
- **AC12 — 메타데이터:** plugin.json `2.11.0` + CHANGELOG `[2.11.0]` + README
  "Principles Instantiated"(Law 1/2/3) + 컴포넌트 문서.
- **AC13 — 회귀 락(teeth):** 테스트가 (a) 신규 에이전트 `model:` 부재,
  (b) read-only 도구 분리, (c) `-A` 부재 + 브랜치 거부, (d) codex graceful
  degradation(미가용 + 런타임 실패 둘 다)을 단언 — 각 mutation으로 teeth 증명.
- **AC14 — cost_class/fan-out:** `variable` 선언 + E3 게이트가 지출-전 승인 +
  라운드당 fan-out ≤3(<5)임을 §8이 명시.
- **AC15 — E1 분류:** 코드 확장자→코드 안내 종료; 비-코드 확장자→진행; 모호→
  AskUserQuestion 확인 후에만 루프 진입. allowlist는 결정론(단위 테스트).
- **AC16 — 데이터 계약:** critic/codex/adversarial가 §10 스키마 준수; `synthesize`가
  canonical-key로 결정론 dedup + verdict 반영 → kept 집합.
- **AC17 — 결정론 헬퍼 isolation:** `convergence-check`·`stagnation-check`·`path-auth`·
  `commit-scope`가 model dispatch와 독립적으로 단위 테스트됨(§7 인터페이스).
- **AC18 — max_rounds 상수:** `max_rounds=5` 고정 상수 + env override; E3 게이트는 N
  미질문(문구는 고정값 고지).

## §12 Files to Modify

**신규:**
- `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md` — 루프 오케스트레이터.
- `plugins/quality-gates/agents/artifact-critic.md`
- `plugins/quality-gates/agents/artifact-adversarial.md`
- `plugins/quality-gates/scripts/build_artifact_codex_prompt.py` — 문서-shaped codex 프롬프트.
- 결정론 헬퍼(`convergence-check`/`stagnation-check`/`path-auth`/`commit-scope` +
  `synthesize` 확장) — 스크립트 파일 경계는 plan 확정, 인터페이스는 §7 고정.
- `plugins/quality-gates/tests/` — AC13/AC15/AC16/AC17 회귀 락 + 라우팅/게이트/바운드 테스트.

**수정:**
- `plugins/quality-gates/commands/qg.md` — 산출물 모드 라우팅(§5).
- `plugins/quality-gates/.claude-plugin/plugin.json` — `2.10.3 → 2.11.0`.
- `plugins/quality-gates/CHANGELOG.md` — `[2.11.0]` 엔트리.
- `plugins/quality-gates/README.md` — 새 모드 문서 + Principles Instantiated.

## §13 Verification Plan

- **단위/셸 테스트:**
  - 라우팅(결정론 행): critique 인자·코드 인자·bare `/qg`가 올바른 경로로(AC1). NL 행은
    단위 테스트 제외(수동 e2e).
  - E1 분류: 코드 확장자→종료, 비-코드→진행, 모호→AskUserQuestion(AC15) — mutation 락.
  - 에이전트 frontmatter: `model:` 부재(AC4/AC13a) + read-only 도구(AC13b) — positive +
    mutation(키 추가/도구 제거 시 RED).
  - 브랜치 거부: main/default에서 진입 시 거부(AC8/AC13c) — mutation(거부 제거 시 RED).
  - 커밋 스코핑: `-A` 부재 grep(AC9/AC13c) — body-unique 문구 + 헤더-satisfiable
    함정 회피([[feedback_grep_lock_header_satisfiable]]).
  - codex degrade: 미가용 stub + 가용-후-실패 stub 각각 degradation 라인(AC5/AC13d).
  - 데이터 계약/헬퍼: canonical-key dedup 결정론(AC16), `convergence-check`·
    `stagnation-check` predicate가 고정 입력→고정 출력(AC7/AC17).
- **수동 e2e:** feature 브랜치에서 실제 문서에 `/qg critique <doc>` 실행 →
  라운드·커밋·수렴 관찰; NL 라우팅("이 문서 비평해줘") 확인; 잔여 findings·롤백 확인.
- **dogfood:** 이 브랜치 자체에 `/qg`(코드 Review 게이트) 실행 — 구현 검증.

## §14 Rejected Alternatives

- **읽기전용 비평(수정 없음)** — 거부: 사용자가 수정 루프를 명시 요구.
- **단일 깊은 비평 1회** — 거부: 사용자가 "루프" 요구.
- **매 라운드 사용자 동의(Retry식)** — 거부: 사용자가 upfront-동의 후 자율 선택.
- **다중-렌즈 패널 / codex-only 다양성** — 거부: 단일 critic + adversarial 채택
  (lightness), codex는 조건부 추가.
- **별도 커맨드 `/qg-critique`** — 거부: 사용자가 `/qg` 하이브리드 분기(option 1) 선택.
- **quality-pipeline SKILL에 3번째 게이트** — 거부: read-only 코드 파이프라인에
  write-capable 문서 루프 혼입 = 개념 충돌 + SKILL 비대화.
- **disposable 워크트리 샌드박스(Runtime식)** — 거부: 목적이 수정을 *영속*(커밋)하는
  것이라 폐기 모델 부적합.
- **opus-핀 `adversarial` 에이전트 재사용** — 거부: `model: opus` 하드코딩이
  inherit-tier 요건 위반 + 페르소나가 코드-diff 전용; 페르소나 약화 편집은 보안-민감
  (CLAUDE.md). 문서용 신규 에이전트가 정책·요건 양쪽으로 맞음.
- **NL 라우팅에 결정론 acceptance 표** — 거부: 토큰 parser 필요 → P8 철학과 충돌.
  결정론 escape(`critique <path>`) + 수동 e2e로 대체(§5).

## §15 Handoff Context

**TL;DR:** `/qg`에 비-코드 산출물용 **비평→수정→재비평 자율 루프** 모드를 추가한다.
inherit-tier critic + adversarial(+조건부 codex)가 read-only로 지적하고, 오케스트레이터가
수정·라운드별 커밋한다. 별도 skill `critiquing-artifacts`로 위임(기존 파이프라인 무변경),
`/qg critique <path>` 또는 NL로 진입. bounded(max 5라운드 + stagnation + kill switch),
Law 2(read-only 리뷰어 + 매 라운드 독립 게이트), GitHub Flow(main 커밋 거부) 준수.

**Implicit context (재발굴 방지):**
- **opus-핀 `adversarial` 재사용 거부 이유:** 그 에이전트는 `model: opus` 하드코딩이라
  "inherit 성능" 요건 위반 + 페르소나가 코드-diff 전용. 신규 문서용 에이전트가 정답.
- **worktree 언급 = 개발 workspace 지시**(모드 동작 아님). 버저닝은 git 커밋으로(사용자
  명시). 이 설계 자체가 `feature/qg-artifact-critique` 워크트리에서 저술됨.
- **N=5는 고정 상수**(env override만) — 사용자 5개 분기 질문으로 합의된 값들: 대상=비-코드,
  루프=비평-수정-재비평, 자율성=upfront-동의-후-자율, 버저닝=커밋, critic=단일+adversarial,
  packaging=하이브리드, codex=조건부.
- **stagnation·수렴·분류가 결정론인 이유:** 자율 수정 루프라 FP가 실제 편집으로 증폭됨 →
  판정을 산문이 아닌 §10 스키마 위 순수 함수로 두어 테스트·감사 가능하게.

**Deferred to plan (설계가 인터페이스만 고정, 구현 세부는 plan):**
- 코드 확장자 allowlist의 정확한 최종 목록(3분기 계약은 고정).
- 결정론 헬퍼들의 파일 경계(SKILL 인라인 vs 별도 스크립트) — 인터페이스는 §7 고정.
- codex 문서 프롬프트의 정확한 문구(`build_artifact_codex_prompt.py` 이름은 고정).
- critic/adversarial 페르소나 전문(역할 한 줄은 §7 고정).

## §16 Metadata

- **Principles Instantiated:**
  - Law 1 (Clarity Before Code) — 자율 수정 전 upfront 동의 게이트(E3).
  - Law 2 (Writer ≠ Reviewer) — read-only 리뷰어 + 오케스트레이터 writer + 매 라운드
    독립 critic 게이트(C2).
  - Law 3 (Compounding) — 라운드별 커밋 감사추적; 버그가 리뷰 탈출 시 critic/adversarial
    페르소나 편집이 compounding 이벤트.
  - P18 (bounded autonomy) — max-rounds + stagnation predicate + kill switch(§8).
  - P8 (determinism-economy) — NL 라우팅은 모델 신뢰, 결정론은 `critique <path>` +
    §10 스키마 기반 판정.
- **의존성:** codex CLI(선택; `detect_codex.sh` 게이트). pr-review-toolkit 등 불요.
- **관련 메모리:** [[project_qg_scope_capture]], [[feedback_respect_upstream_model_hardcoding]],
  [[feedback_harness_lightness_trust_model]], [[reference_workflow_law2_agenttype]],
  [[feedback_fix_introduces_regression]].
