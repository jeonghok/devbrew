# 설계: quality-gates 산출물 비평-수정 루프 모드 (v2.11.0)

> **한 줄 정체성:** 비-코드 산출물(문서·스펙·제안서·계획·설정·산문)을 대상으로,
> inherit-tier 강한 모델이 **비판 → 오케스트레이터가 수정 → 재비판**을 자율 반복하는
> `/qg`의 신규 모드. 버저닝은 라운드별 git 커밋.

- **플러그인:** `quality-gates`
- **버전:** `2.10.3 → 2.11.0` (minor — 새 표면)
- **브랜치:** `feature/qg-artifact-critique` (base `819da27`)
- **상태:** brainstorming 승인 완료 → 이 설계 문서 → writing-plans 대기

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
- [§10 Acceptance Criteria](#10-acceptance-criteria)
- [§11 Files to Modify](#11-files-to-modify)
- [§12 Verification Plan](#12-verification-plan)
- [§13 Rejected Alternatives](#13-rejected-alternatives)
- [§14 Metadata](#14-metadata)

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
5. codex가 설치·인증돼 있으면 **model-diversity co-reviewer로 포함**, 없으면 graceful
   degradation.
6. Law 2(writer ≠ reviewer)·P18(bounded autonomy)·GitHub Flow를 구조적으로 준수.

## §3 Non-goals

- **코드 리뷰 대체 아님.** 기존 2게이트(Review/Runtime)는 무변경. 이 모드는 비-코드
  산출물 전용.
- **spec-distill `spec-reviewer` 대체 아님.** 그것은 interview→design 흐름 전용으로
  유지. 이 모드는 *임의* 산출물 일반화이며, 그 흐름을 건드리지 않는다.
- **Runtime류 실행 검증 아님.** 대상이 비-코드라 부팅할 앱이 없다.
- **코드 파일 대상 아님.** 코드 리뷰 의도로 라우팅되면 기존 파이프라인으로.

## §4 Constraints

- **C1 (Law 1):** 이 모드는 코드를 shipping하지 않지만 산출물을 mutate한다. 자율 수정
  전 **upfront 동의 게이트**(§6/§8)가 있어야 한다.
- **C2 (Law 2 — 물리적):** critic·adversarial·codex 리뷰어는 `disallowedTools`로
  `Write`/`Edit`/`MultiEdit`/`NotebookEdit`을 literally 못 함. 수정·커밋은 오케스트레이터
  (writer)만. 매 라운드 **독립 리뷰어 재디스패치**가 승인 게이트 — 자기 편집 자기 승인
  불가.
- **C3 (P18):** 루프는 max-iter + stagnation + kill switch로 bounded. 무한 루프 금지.
- **C4 (GitHub Flow):** `main`/기본 브랜치에서 자율 커밋 **금지**. feature/* 요구.
- **C5 (커밋 위생):** 대상 산출물 경로만 `git add` — `git add -A` 금지(무관 변경
  쓸어담기 방지).
- **C6 (inherit-tier):** 신규 리뷰어 에이전트는 `model:` 키 미선언 → 세션 tier 상속.
  회귀 락으로 강제.
- **C7 (graceful degradation):** codex 부재 시 crash 아닌 downgrade + loud log.
- **C8 (버전):** plugin.json bump + CHANGELOG + README 갱신.

## §5 아키텍처 — 호출 & 라우팅

`/qg`의 커맨드 계층(`commands/qg.md`)이 `$ARGUMENTS`를 보고 **산출물 모드 vs 코드
파이프라인**을 라우팅한다.

| 입력 | 라우팅 |
|---|---|
| `/qg critique <path>` | 산출물 모드, 명시 대상(결정론적 진입) |
| `/qg critique` (경로 없음) | 산출물 모드, 대상은 NL/컨텍스트로 해석하거나 게이트에서 확인 |
| `/qg <NL critique 의도>` (예: `이 설계문서 비평해줘`) | 모델 해석으로 산출물 모드 라우팅 |
| bare `/qg`, `/qg both\|review\|runtime\|branch\|--paths ...` | **기존 코드 파이프라인 무변경** |

**라우팅 철학 (P8 determinism-economy / [[feedback_harness_lightness_trust_model]]):** NL 의도 해석은
모델이 소유(별도 토큰 parser 없음). `critique <path>`는 결정론적 escape hatch.
코드/산출물 의도가 **진짜 모호**할 때만 mode-branch `AskUserQuestion`을 띄우고,
명확하면 안 띄운다 — dominant한 코드 경로에 마찰 0.

**"맨 처음 ask question으로 분기"의 의미:** 이 모드의 첫 동작인 §6 upfront 게이트
(대상 확정 + 최대 N라운드 동의)가 그 분기다. 산출물 모드로 진입한 뒤 파일에 손대기
전에 반드시 fire한다.

산출물 모드로 라우팅되면 커맨드는 신규 skill
`Skill("quality-gates:critiquing-artifacts")`를 호출한다(기존 `quality-pipeline`
대신). 이로써 `quality-pipeline` SKILL(786줄)은 무변경 — write-capable 문서 루프가
read-only 코드 게이트 파이프라인에 섞이지 않는다.

## §6 아키텍처 — 루프 구조

`critiquing-artifacts` SKILL이 단일 턴에서 다음을 실행한다.

**진입 (파일 손대기 전):**
- **E0** Preflight — 전역 kill switch(`DEVBREW_DISABLE_QUALITY_GATES=1`) + 모드 전용
  kill(`DEVBREW_QG_DISABLE_CRITIQUE=1`) 존중.
- **E1** 대상 해석 — 명시 경로 또는 NL에서 대상 산출물 경로를 확정. 코드 파일로
  판정되면 "코드 리뷰는 `/qg`로" 안내하고 종료.
- **E2** 브랜치 안전(§8/C4) — `main`/기본 브랜치면 **거부**, feature/* 안내 후 종료.
- **E3** Upfront 게이트 (`AskUserQuestion`): *"대상=`<resolved path>`, 최대 N라운드
  비평-수정 루프를 브랜치 `<branch>`에 라운드별 커밋하며 실행할까요?"*
  → **실행** / **대상 변경** / **취소**.

**루프 (라운드 N = 1..max_iterations, 기본 5):**
1. **critic** — `artifact-critic`(inherit-tier, read-only) 디스패치. *현재 커밋된*
   산출물을 §9 루브릭으로 검토 → severity 태그 findings(CRITICAL / IMPORTANT /
   SUGGESTION). `project_dir` 스레딩.
2. **codex co-reviewer (조건부)** — `detect_codex.sh`가 `codex_available: true`면
   문서-shaped 프롬프트로 병렬 dispatch → findings 병합. false면 inherit-only +
   `> [quality-gates] codex 미가용(<skip_reason>) — inherit-tier 단독 비평.` loud log.
3. **adversarial** — `artifact-adversarial`(inherit-tier, read-only)가 findings를
   반박·강화(FP 제거 + 놓친 것 추가). *자율 수정 루프라 이 FP 거름망이 read-only
   리뷰 때보다 load-bearing — 잘못된 지적이 실제 편집으로 증폭되는 것을 커밋 전 차단.*
4. **synthesize** — kept findings 산출(결정론적 병합·dedup).
5. **수렴 체크** — kept 중 CRITICAL/IMPORTANT == 0 → **수렴, 루프 종료**.
   SUGGESTION만 남으면 수렴으로 간주(목록만 surface, 수정 안 함).
6. **수정 적용** — 오케스트레이터(writer)가 kept CRITICAL/IMPORTANT를 해소하도록
   산출물을 `Edit`/`Write`. 리뷰어가 제안한 경로는 canonicalize(symlink escape 방지,
   기존 Retry: file-write safety 패턴 재사용).
7. **커밋** — **대상 파일만** 명시 `git add <artifact-path>`(§C5) 후 원자적 커밋:
   메시지 `critique(round N): <해소한 findings 요약>`.
8. **stagnation 체크** — 이번 라운드 findings가 직전과 실질 동일(진전 없음) 또는
   수정이 파일을 바꾸지 않음 → **stagnation 종료**.
9. N+1로 반복.

## §7 아키텍처 — 컴포넌트 & Law 2

**신규 에이전트 (둘 다 `model:` 미선언 → inherit-tier; read-only):**
- `artifact-critic` — 산출물을 §9 루브릭으로 비판, severity 태그 findings 생산.
  역할 프롬프트: *"You are the artifact critic. You are responsible for finding
  logical gaps, unstated assumptions, incompleteness, and ambiguity in a non-code
  artifact. You are NOT responsible for writing code, editing the artifact, or
  reviewing code diffs."*
- `artifact-adversarial` — critic findings를 반박·강화(FP hunt + 누락 보강).
  기존 opus-핀 `adversarial`을 재사용하지 **않음**(§13 참조).

**재사용:**
- `detect_codex.sh` — 순수 가용성 체크라 그대로 재사용.
- Retry: file-write safety의 path canonicalization 로직.
- `render-terminal.py` — 최종 요약 표.

**신규 스크립트:**
- 문서-shaped codex 프롬프트 빌더(`run_codex_reviewer.sh`는 코드-diff+spec AC 전용이라
  재사용 불가; 산출물 내용을 입력으로 받는 별도 경로).
- (선택) 브랜치 안전·커밋 스코핑 헬퍼 — 인라인 Bash로 충분하면 생략.

**Law 2 보증 (C2):**
- critic·adversarial·codex는 `disallowedTools`로 쓰기 tool 불가.
- 수정·커밋은 오케스트레이터만.
- **매 라운드 독립 critic이 게이트:** 라운드 N의 수정을 라운드 N+1의 *독립* critic이
  재검토. 최종 "수렴" 판정은 마지막 독립 critic 패스의 synth 출력이 결정 —
  오케스트레이터가 자기 편집을 자기 판단으로 승인하는 경로가 구조적으로 없다.
  (기존 Review 게이트 Retry 루프 + honest-verdict floor와 동형.)

## §8 종료 조건 & 안전장치

- **종료 (넷 중 하나):** ① 수렴(kept CRITICAL/IMPORTANT == 0) ② max-iterations(기본
  **5**, Review 게이트와 대칭) ③ stagnation(findings 정체 또는 파일 무변경)
  ④ kill switch. → P18(bounded autonomy) 충족.
- **브랜치 안전 (C4):** `main`/기본 브랜치에서 자율 커밋 **거부**(경고 아님). E2에서
  차단하고 feature/* 안내.
- **커밋 스코핑 (C5):** 대상 산출물 경로만 add — dirty 워킹트리의 무관 변경 미포함.
- **Kill switch:** 전역 `DEVBREW_DISABLE_QUALITY_GATES=1` + 모드 전용
  `DEVBREW_QG_DISABLE_CRITIQUE=1`. 어떤 훅/스킬도 kill switch 존중을 거부 못 함.
- **cost_class:** `variable`(라운드 수에 따라). high-cost 지출은 **E3 upfront 동의
  게이트**가 사전 승인 — devbrew high-cost 규칙 충족.

## §9 비평 루브릭 (비-코드 산출물)

`spec-reviewer`를 일반화한 범용 렌즈. critic·adversarial이 공유:

- **논리 정합성 / 내부 모순** — 섹션 간 상충, 전제-결론 불일치.
- **미명시 가정** — 근거 없이 전제된 것.
- **완결성 / 공백** — 빠진 섹션, 다루지 않은 케이스.
- **근거 / 사실성** — 뒷받침 없는 주장. *단 critic이 사실을 날조 금지 — "근거
  없음"으로 flag하되 대체 사실을 지어내지 않음.*
- **모호성** — 두 갈래로 읽히는 문장.
- **actionability / testability** — 스펙·계획의 검증 가능성.
- **구조 / 조직** — 순서·중복·가독성.
- **(adversarial) 반론 / 약점** — 가장 강한 반대 논거.

각 finding은 severity(CRITICAL/IMPORTANT/SUGGESTION) 태그. 문서 종류 인지하되 범용.

## §10 Acceptance Criteria

- **AC1 — 라우팅:** `/qg critique <path>`는 명시 대상으로 산출물 모드 진입;
  `/qg <NL critique 의도>`는 모델 해석으로 산출물 모드 라우팅; bare `/qg` 및 코드
  인자(`both|review|runtime|branch|--paths`)는 기존 코드 파이프라인 무변경.
- **AC2 — Upfront 게이트:** 파일 쓰기 전 (a) 브랜치 안전 체크, (b) 대상 확정 +
  최대 N라운드 동의 `AskUserQuestion`(실행/대상변경/취소)이 fire.
- **AC3 — 라운드 파이프라인:** 각 라운드가 critic → (codex if available) →
  adversarial → synthesize → 수렴체크 → 수정 → 커밋 → stagnation체크 순서.
- **AC4 — inherit-tier + read-only:** `artifact-critic`·`artifact-adversarial`
  frontmatter에 `model:` 키 부재(inherit) + `disallowedTools`에 Write/Edit/
  MultiEdit/NotebookEdit 포함.
- **AC5 — codex 조건부:** `detect_codex.sh`가 available이면 문서-shaped codex
  co-reviewer 실행; 미가용이면 inherit-only + loud degradation 라인 출력.
- **AC6 — 수렴:** kept CRITICAL/IMPORTANT == 0일 때만 루프 종료(SUGGESTION-only는
  수렴 허용). 수렴 판정은 독립 synth 출력이 결정(오케스트레이터 자기판단 아님).
- **AC7 — bounded:** max-iterations=5, stagnation 감지, kill switch(전역+모드) —
  무한 루프 불가.
- **AC8 — 브랜치 안전:** main/기본 브랜치에서 파일 손대기 전 거부 + feature/* 안내.
- **AC9 — 커밋 스코핑:** 각 라운드가 대상 경로만 `git add` — `git add -A` 부재.
- **AC10 — Law 2:** writer(오케스트레이터) ≠ reviewer(subagent); 라운드 수정은
  후속 독립 critic 패스가 게이트; 독립 findings가 남은 채 자기-certify 불가.
- **AC11 — 출력:** 최종 요약이 라운드별 히스토리 + 커밋 SHA + (중단 시) 잔여 findings.
- **AC12 — 메타데이터:** plugin.json `2.11.0` + CHANGELOG `[2.11.0]` + README
  "Principles Instantiated"(Law 1/2/3) + 컴포넌트 문서.
- **AC13 — 회귀 락(teeth):** 테스트가 (a) 신규 에이전트 `model:` 부재,
  (b) read-only 도구 분리, (c) `-A` 부재 + 브랜치 거부, (d) codex graceful
  degradation을 단언 — 각 mutation으로 teeth 증명.
- **AC14 — cost_class:** `variable` 선언 + high-cost 지출이 E3 upfront 게이트로 사전
  승인됨을 문서화.

## §11 Files to Modify

**신규:**
- `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md` — 루프 오케스트레이터.
- `plugins/quality-gates/agents/artifact-critic.md`
- `plugins/quality-gates/agents/artifact-adversarial.md`
- 문서-shaped codex 프롬프트 빌더 스크립트(`scripts/` 하위, 이름은 plan에서 확정).
- `plugins/quality-gates/tests/` — AC13 회귀 락 + 라우팅/게이트/바운드 테스트.

**수정:**
- `plugins/quality-gates/commands/qg.md` — 산출물 모드 라우팅(§5).
- `plugins/quality-gates/.claude-plugin/plugin.json` — `2.10.3 → 2.11.0`.
- `plugins/quality-gates/CHANGELOG.md` — `[2.11.0]` 엔트리.
- `plugins/quality-gates/README.md` — 새 모드 문서 + Principles Instantiated.

## §12 Verification Plan

- **단위/셸 테스트:**
  - 라우팅: critique 인자·NL 의도가 산출물 모드로, 코드 인자가 기존 경로로.
  - 에이전트 frontmatter: `model:` 부재(AC4/AC13a) + read-only 도구(AC13b) — 각각
    positive + mutation(키 추가/도구 제거 시 RED) 락.
  - 브랜치 거부: main에서 진입 시 거부(AC8/AC13c) — mutation(거부 제거 시 RED).
  - 커밋 스코핑: `-A` 부재 grep(AC9/AC13c) — body-unique 문구 + 헤더-satisfiable
    함정 회피([[feedback_grep_lock_header_satisfiable]]).
  - codex graceful: 미가용 stub에서 degradation 라인 출력(AC5/AC13d).
  - bounded: max-iter/stagnation 상수·감지 로직 단언(AC7).
- **수동 e2e:** feature 브랜치에서 실제 문서에 `/qg critique <doc>` 실행 →
  라운드·커밋·수렴 관찰; 잔여 findings·롤백 확인.
- **dogfood:** 이 브랜치 자체에 `/qg`(코드 Review 게이트) 실행 — 구현 검증.

## §13 Rejected Alternatives

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

## §14 Metadata

- **Principles Instantiated:**
  - Law 1 (Clarity Before Code) — 자율 수정 전 upfront 동의 게이트(E3).
  - Law 2 (Writer ≠ Reviewer) — read-only 리뷰어 + 오케스트레이터 writer + 매 라운드
    독립 critic 게이트(C2).
  - Law 3 (Compounding) — 라운드별 커밋 감사추적; 버그가 리뷰 탈출 시 critic/adversarial
    페르소나 편집이 compounding 이벤트.
  - P18 (bounded autonomy) — max-iter + stagnation + kill switch(§8).
  - P8 (determinism-economy) — NL 라우팅은 모델 신뢰, 결정론은 `critique <path>`.
- **의존성:** codex CLI(선택; `detect_codex.sh` 게이트). pr-review-toolkit 등 불요.
- **관련 메모리:** [[project_qg_scope_capture]], [[feedback_respect_upstream_model_hardcoding]],
  [[feedback_harness_lightness_trust_model]], [[reference_workflow_law2_agenttype]].
