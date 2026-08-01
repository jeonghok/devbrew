# qg 영향-구동 QA Runtime

> *격리는 목적이 아니라 부수 조건이다. 산출물은 인프라가 아니라 "이 변경으로 무엇이 달라지고, 그중 무엇을 실제로 확인했는가"다.*
> — interview brief §1 설계 표어

Runtime 게이트가 *"전체 앱을 무조건 돌린다"* 를 버리고 **이번 변경의 영향분을 골라 기준선 대비로 돌린다**. 모델이 무엇을 돌릴지 한 번 고르고, 그 선택을 결정론이 두 번 실행해 짝짓는다 — 귀속(이 fail은 내 탓인가)과 백스톱(결과가 조용히 비었나)이 같은 메커니즘에 얹힌다.

## 목차

- [Handoff Context](#handoff-context)
- [1. Context / Why](#1-context--why)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. Constraints](#4-constraints)
  - [4.1 인터뷰에서 확정된 것 (재논쟁 금지)](#41-인터뷰에서-확정된-것-재논쟁-금지)
  - [4.2 이 브레인스토밍에서 확정한 것](#42-이-브레인스토밍에서-확정한-것)
  - [4.3 코드에서 확인한 사실](#43-코드에서-확인한-사실)
- [5. 설계](#5-설계)
  - [5.1 아키텍처 — 판정 · 실행 · 대조 3분업](#51-아키텍처--판정--실행--대조-3분업)
  - [5.2 데이터 흐름 — R-init ~ R9](#52-데이터-흐름--r-init--r9)
  - [5.3 영향 판정 — 모델 소유 + 보조 입력 4종 등급](#53-영향-판정--모델-소유--보조-입력-4종-등급)
  - [5.4 차등 실행과 기준선 캐시](#54-차등-실행과-기준선-캐시)
  - [5.5 귀속 표 · flaky 처리](#55-귀속-표--flaky-처리)
  - [5.6 LD7 원장 — floor 5차원 + derived](#56-ld7-원장--floor-5차원--derived)
  - [5.7 verdict 규칙](#57-verdict-규칙)
  - [5.8 계획 산문 · 갭 게이트](#58-계획-산문--갭-게이트)
  - [5.9 러너 지원 행렬 · degrade 정밀화](#59-러너-지원-행렬--degrade-정밀화)
  - [5.10 에러 처리 · graceful degradation](#510-에러-처리--graceful-degradation)
  - [5.11 GC 충돌 — 신규 위험이 드러낸 기존 결함](#511-gc-충돌--신규-위험이-드러낸-기존-결함)
- [6. Acceptance Criteria](#6-acceptance-criteria)
- [7. Files to Modify](#7-files-to-modify)
- [8. Verification Plan](#8-verification-plan)
  - [8.1 자동 테스트](#81-자동-테스트)
  - [8.2 mutation — 이빨 증명](#82-mutation--이빨-증명)
  - [8.3 수동 검증](#83-수동-검증)
- [9. Rejected Alternatives](#9-rejected-alternatives)
- [10. Open Questions 처리](#10-open-questions-처리)
- [11. 남는 갭 (명시)](#11-남는-갭-명시)
- [12. Metadata](#12-metadata)

---

## Handoff Context

> 이 spec을 처음 보는 사람(또는 `/compact` 후 자기 자신)이 30초에 핵심을 파악할 수 있게. 대화 컨텍스트를 가정하지 않는다.

**TL;DR** (무엇을·왜):

- qg Runtime 게이트는 *무엇을 어떻게 돌릴지*를 정적 manifest + 고정 격리 레시피로 굳혀놨다. 계약에 리터럴로 박혀 있다 — `SKILL.md:667` *"Runtime runs the whole app regardless of Review scope."*
- 무엇을 돌릴지 정할 여지가 없으니 남는 답이 "전부 안전하게 돌리기"였고, 그래서 노력이 격리 강화(worktree→컨테이너, 64커밋 ~10k줄)로 흘렀다가 **전량 폐기**됐다. 격리는 목적이 아니었다.
- 이 spec은 그 문장을 지우고 그 자리에 **영향-구동 + 기준선 대비 차등 실행**을 놓는다. 산출: **신규 스크립트 4 · 기존 파일 수정 7**(SKILL · verifier 페르소나 · 스크립트 5) **· 문서 3**. **신규 에이전트 0 · 신규 훅 0 · 신규 verdict 토큰 0.**
- **SemVer major (v3.0.0)** — `/qg runtime` 인터페이스는 유지되지만 "전체 앱을 돌린다"에 의존하던 동작이 사라진다.

**Implicit context** (Constraints에 안 박힌, 작업에 필요한 외부 사실):

- **폐기된 시도가 실재한다.** qg v2.14.0 container-runtime(64커밋, `qg-container.sh` 2451줄, `parse-spec-runtime.py` 343줄)은 미푸시·미머지 상태로 소실됐고 코드는 남아 있지 않다. 재탐색 차단 기록이며, 이 spec은 그 방향으로 돌아가지 않는다.
- **`SKILL.md:667`의 리터럴은 테스트에 락돼 있다** — `tests/harness/test_skill_orchestration_behavior.sh:408`(존재) + `:417`(`grep -cE` 유일성 == 1). 그냥 지우면 스위트가 빨개진다. **락을 반대 불변식으로 이전**하는 것이 정답이다.
- **`compute-test-scope-candidates.sh:27-32`는 baseline을 `main` 하드코딩 + merge-base 없이 계산한다.** 반면 `check-review-scope.sh:43-79`는 origin/HEAD → origin/main → origin/master → local 순 resolution + merge-base + shallow/detached 감지를 갖는다 (v2.6.0→v2.7.0 3라운드 하드닝의 산물). Runtime 쪽은 Review가 이미 고친 버그 클래스를 아직 갖고 있다.
- **`compute-test-scope-candidates.sh`는 `allowed-tools`에 등재돼 있으나(`SKILL.md:25`) SKILL 본문에 호출 지점이 없다.** Step R1은 `candidate_test_files: <list from scope-detection step>`(`:654`)라고만 쓴다 — 출처가 미지정이다.
- **`test-scope-validator`의 출력은 소비처가 없다.** 사용자에게 출력되고 evidence-log에 실릴 뿐, 어떤 판정에도 들어가지 않는다.
- **`qg-gc.py:27`의 `SESSION_PATTERN = ^[A-Za-z0-9_-]{8,}$`은 세션 폴더만이 아니라 `worktrees`(9자)·`baseline-cache`(14자) 같은 형제 디렉토리도 매치한다.** §5.11 참조.
- **`create-sandbox`는 git-ignored 파일을 의도적으로 복사하지 않는다**(`qg-worktree.sh:107-115`, 운영 안전 §6.3c). 그래서 어떤 샌드박스에도 `node_modules`/`.venv`가 없다 — §5.4가 정면으로 다루는 제약.
- **레포 이력: 별-모델 codex가 same-family opus 다단계 리뷰가 통과시킨 fail-open을 반복 적발했다** (qg v2.13.0 C5, spec-distill v0.20.0/v0.22.0 등). 모델 다양성은 장식이 아니라 유일한 backstop이다.
- **devbrew 자신이 stale red를 다수 보유한다** — 이 설계는 첫 실행부터 그 위에서 돈다. `PRE_EXISTING`이 FAIL이 아닌 이유가 이것이다.

**Deferred to plan** — **판정에 영향을 주지 않는 것만.**

- 신규 스크립트 4종의 **내부 구현 문체·헬퍼 분해**. 입출력 계약과 exit code는 §5가 lock한다.
- `runtime-verifier` 페르소나의 **수사·예시 순서**. 역할 경계(무엇을 하지 않는가)와 입력 필드는 §5.1·§5.2가 lock한다.
- 테스트 파일 배치(기존 `tests/` 구조에 맞춰 구현이 결정).
- `CHANGELOG.md`·README 항목 **문구**.
- 계획 산문의 **어투**(필수 필드는 §5.8이 lock).

**더 이상 defer하지 않는 것** (§4 위험 논의에서 이 문서로 끌어올림): **기준선 deps 전략**(§5.4 — 옵션 ② 기각이 판정 정확성을 직접 결정) · **러너별 지원 등급과 degrade 조건**(§5.9 — verdict를 직접 결정) · **`qg-gc.py` 수정 방식**(§5.11 — denylist는 시간에 fail-open).

---

## 1. Context / Why

**입력**: `docs/superpowers/interview/2026-07-26-qg-impact-driven-qa-runtime-interview.md` (spec-distill v0.22.0 포맷, `locked_directions` 7건).

**증상**: Runtime 게이트가 상황을 못 읽는다. 세 구멍:

| 구멍 | 지금 어떻게 되나 | 결과 |
|---|---|---|
| 무엇을 돌릴지 정하는 주체가 없다 | `detect-runtime.sh`가 정적 manifest를 emit하고 verifier가 그걸 verbatim 소비 (`runtime-verifier.md:56` *"Read it verbatim; do NOT re-detect"*) | 레포·변경 상황에 맞는 전략이 나올 여지가 없음 |
| 실행 결과를 귀속할 근거가 없다 | Review 게이트엔 *"pre-existing → downgrade"* 개념이 있으나(`adversarial.md:45`) **실행 결과용 대응물이 없다** | stale red 보유 레포에서 첫 실행부터 오귀속 |
| 사용자가 전략에 개입할 지점이 없다 | Decision 2는 *표면 opt-in*(무엇을 부팅할지)만 묻고 *무엇을 확인할지*는 묻지 않는다 | LD1의 ②통제 상실 |

**구조적 근거**: 이 레포는 **Review 게이트에서 이미 반대 방향으로 진화했다.** `check-review-scope.sh:2-8`이 스크립트 책임을 *"스코프가 비었나"* → *"변경이 존재하나"* 로 좁히며 주석에 못박았다:

> *"Scope resolution (WHAT to review) is the MODEL's responsibility now"*

Runtime은 그 전환을 아직 받지 않았다. 이 문서가 같은 모양을 Runtime에 이식한다 — 새 아키텍처가 아니라 **이미 착지한 아키텍처의 두 번째 인스턴스**다.

---

## 2. Goals

1. **영향-구동 스코프.** Runtime이 *이번 변경이 무엇을 건드렸는지* 읽고 그 상황에 맞는 검증 계획을 세운다. 스코프 판정은 모델이 하고, 결정론 신호는 보조 입력이다 (LD5).
2. **floor는 실행이다.** 레포에 이미 있는 테스트 중 영향분을 골라 **실제로 돌리는 것**까지가 무조건. 그 위(부팅/플로우/탐색적)는 상황별 재량 (LD3).
3. **결과 귀속에 반박불가 근거.** fail이 나오면 *내 변경 탓인가*를 기준선 대비 차등 실행으로 판정한다. 차등이 불가능하면 그 사실이 **보인다** (OQ1).
4. **누락 방향 실패 금지의 결정론 백스톱.** "결과가 조용히 비었나 / 변경이 있는데 안 돌렸나"를 모델 주장과 독립으로 검사한다 (LD5 후반부).
5. **쉬운 설명 — 단, rubber-stamp를 낳지 않는 형태로.** 계획과 결과를 이해 가능한 언어로 알린다(LD4). 승인 질문은 **커버리지 갭이 있을 때만** 발화한다 (OQ2).
6. **질문형 루브릭.** floor 5차원 + 의무 derived. 점수형·테스트종류 메뉴 금지 (LD7).
7. **하니스의 *제약* 무증가.** 이 spec은 스크립트 4 · 캐시 1 · 원장 1 · 구조 게이트 1을 **늘린다**. 그것들은 능력 증가다. 금지 대상은 *모델을 옥죄는 규칙*이며 측정 가능한 세 항목으로 못 박는다:
   - **신규 훅 · `hooks.json` 항목 0개** (AC24)
   - **신규 에이전트 0개** — 기존 `runtime-verifier`/`test-scope-validator` 재사용 (AC25)
   - **결정론적 선택 상한 0개** — 영향 판정에 최대 N 같은 천장을 두지 않는다. 과선택 방어는 가시성(§5.8)이 담당한다 (AC19의 선택 비율 + §9-⑦의 기각 기록)

---

## 3. Non-goals

- **컨테이너 격리 재도입** — LD1·brief §7. 재탐색 차단 기록.
- **테스트 프레임워크 부트스트랩** — gstack B2–B8이 하는 일. qg는 검증 게이트지 셋업 게이트가 아니다. 영향분 테스트가 0개면 `SKIP_WITH_EVIDENCE` + gap 차원 기록으로 끝낸다.
- **신규 테스트 작성** — gstack Phase 8e.5가 하는 일. qg가 테스트를 쓰면 writer≠reviewer 경계가 무너진다 (Law 2).
- **버그 수정 루프** — gstack Phase 8 fix loop. Runtime은 판정하고, 수정은 사용자 또는 Review 게이트 Retry 경로.
- **레포 CI의 test-selection 대체** — 신호로 읽고 차이를 설명하되 대체하지 않는다 (OQ4).
- **Review 게이트 스코프와의 강제 동기화** — 두 스코프는 다를 수 있고, 다르면 설명만 한다.
- **`detect-runtime.sh` / `create-sandbox` / `mutation-guard` 계약 변경** — LD5 "배관은 기존 고정 계약이 기본값". 바이트 무변경 (AC17, AC18).
- **`/qg runtime` 단일게이트 동작 변경** — 기존 non-goal 승계 (AC19).
- **부팅/플로우 층의 차등화** — 차등 실행은 **테스트 러너 표면에만** 적용한다. 브라우저 플로우를 기준선에서도 돌리는 것은 비용·비결정성 모두에서 감당 불가 (§11 ⑤).
- **의존 그래프 기반 영향 판정** — `compute-test-scope-candidates.sh`의 이름 매칭 휴리스틱을 보조 입력으로 쓰되, import 그래프 분석기를 새로 만들지 않는다 (§11 ④).

---

## 4. Constraints

`source`(누가) × `status`(얼마나 굳었나) 두 축. 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론 · 🔬 코드 실측.

### 4.1 인터뷰에서 확정된 것 (재논쟁 금지)

| id | 내용 | source |
|---|---|---|
| **LD6** | 문제 = 게이트가 무엇을/어떻게 돌릴지를 정적 manifest + 고정 격리로 굳혀 상황을 못 읽음. goal = 임의 레포에서 변경을 읽고 계획→쉬운 설명→합의→실행하는 QA 동반자 | 🗣 |
| **LD1** | container-runtime 기각 사유 = ①범용성 상실 ②사용자 통제 상실. *"impact 부재가 유일한 뿌리"* 는 사용자가 명시 기각 | 🗣 |
| **LD3** | floor = 레포에 이미 있는 테스트 중 영향분을 **실제 실행**. *"증거만 남으면 방법은 자유"* 는 기각됨 | 🗣 |
| **LD4** | 계획과 결과를 **쉽게** 설명. 전문용어 나열은 산출물 실패 | 🗣 |
| **LD5** | 영향판정 = 모델. 결정론 = *"결과가 조용히 비었나"* 를 검사하는 반박불가 백스톱. 누락 방향 실패 금지(불확실하면 과선택). **배관은 기존 고정 계약이 기본값**, 이탈은 이유와 함께 제안만 | ☑ (steelman 부분전환 후 premortem 재개정) |
| **LD7** | 질문형 floor + **의무** derived. 점수·테스트종류 메뉴 금지. spec-distill 커버리지 원장과 동형 | 🗣 |

### 4.2 이 브레인스토밍에서 확정한 것

| id | 내용 | source |
|---|---|---|
| **B1** (OQ6) | 산출물 단위 = **기존 Runtime 게이트 개정**. 제3 게이트 신설도, 별도 플러그인도 아님 | ☑ |
| **B2** (OQ1) | fail 귀속 = **기준선 차등 실행이 floor**, 기준선 실행 불가 시 git-귀속 분류로 loud degrade하되 "확증"으로 표기 금지 | ☑ |
| **B3** (OQ2) | 승인 질문 발화 조건 = **커버리지 갭이 있을 때만**. 전부 돌리면 zero-click | ☑ |
| **B4** (LD7 구체화) | floor 차원 = **5개**: `changed` / `behavior` / `verification` / **`attribution`** / `gap`. 귀속 축을 루브릭으로 승격 | ☑ |
| **B5** (OQ3) | 계획 노출 = **산문 + 비용 신호**. gstack식 명명 모드 4개는 이식하지 않음 | ☑ |
| **B6** (OQ5) | baseline resolution을 **공유 모듈로 추출**. `check-review-scope.sh` 확장이 아님 | ✎ (사용자 미이의) |
| **B7** (OQ4) | 레포 CI는 LD5의 보조 입력 하나. 차이는 계획 산문에 한 줄 | ✎ (사용자 미이의) |
| **B8** | 기준선 결과를 **merge_base 내용주소로 캐시**. 기준선 실행은 /qg 호출당이 아니라 merge_base당 1회 | ☑ (위험 해소 요구에 대한 응답) |
| **B9** | deps 복사 전략 **기각**. 각 트리에 정직하게 설치 + 생태계 공유 캐시 | ☑ |
| **B10** | `qg-gc.py`를 **내용 기반 식별**로 수정. denylist 금지 | ☑ |

### 4.3 코드에서 확인한 사실

| id | 내용 | source |
|---|---|---|
| **C1** | `SKILL.md:667` 리터럴이 `test_skill_orchestration_behavior.sh:408,417`에 존재+유일성으로 락됨 | 🔬 |
| **C2** | `compute-test-scope-candidates.sh:27-32`가 `main` 하드코딩 + merge-base 없음 | 🔬 |
| **C3** | `qg-gc.py:27` 패턴이 `worktrees`·`baseline-cache`를 매치. `_folder_mtime_ns:51-55`는 직접 파일이 없으면 디렉토리 mtime으로 떨어짐 | 🔬 |
| **C4** | `create-sandbox`가 git-ignored를 복사하지 않음 (`qg-worktree.sh:107-115`) | 🔬 |
| **C5** | `check-allowed-tools-order.sh:25`가 `allowed-tools` 순서를 락 | 🔬 |
| **C6** | gbrain `skills/testing/SKILL.md:146-171`이 git-귀속 5분류(REGRESSION/STALE/FLAKE/NEW/INFRA)를 갖는다 — **brief §8의 "어느 하니스도 이걸 풀지 않았다"는 부정확**. B2의 degrade 경로가 이 선례를 소비한다 | 🔬 |

---

## 5. 설계

### 5.1 아키텍처 — 판정 · 실행 · 대조 3분업

| 층 | 주체 | 무엇 | 왜 여기 |
|---|---|---|---|
| **판정** | 오케스트레이터 (SKILL, 모델) | 영향 스코프 결정 · 계획 산문 · 갭 게이트 | 계획을 설명하고 합의받는 주체가 판정 주체여야 한다 (LD4·LD6) |
| **실행** | `runtime-verifier` (sandbox executor) · `run-test-selection.sh` (결정론) | HEAD 측 setup·부팅·플로우는 verifier. 테스트 실행은 스크립트 | verifier는 판단이 필요한 곳에만. 테스트 실행은 판단이 없으므로 스크립트 |
| **대조** | `diff-test-results.py` (결정론) | 기준선×HEAD 짝짓기 → 귀속 + 침묵 백스톱 | 모델 주장과 독립이어야 백스톱이 된다 (LD5) |

**핵심 불변식:** 모델은 **무엇을 돌릴지 한 번** 고르고, 그 선택은 **결정론적으로 두 번** 실행된다. 결정론이 지키는 것은 *선택*이 아니라 *짝짓기*다.

```
                  ┌─ 판정 (모델) ─────────────────┐
                  │  영향 스코프 · 계획 · 갭 게이트  │
                  └──────────────┬────────────────┘
                                 │ 같은 선택
                    ┌────────────┴────────────┐
                    ▼                         ▼
      기준선 측 (merge_base)            HEAD 측 (샌드박스)
      run-test-selection.sh            verifier setup → run-test-selection.sh
      + baseline-cache 적중 시 skip     + 부팅/플로우 (상황별)
                    │                         │
                    └────────────┬────────────┘
                                 ▼
                    diff-test-results.py (결정론)
                    귀속 8종 + SILENT_DROP 백스톱
```

### 5.2 데이터 흐름 — R-init ~ R9

```
R-init  resolve-baseline.sh                          [신규]
          → base · base_ref · merge_base · degraded
          공유: check-review-scope.sh · compute-test-scope-candidates.sh · 이 게이트

R1      영향 판정 ── 오케스트레이터(모델)               ← LD5 전반부
          보조 입력 4종 (§5.3)
          산출: 영향 테스트 파일 목록 + 상황별 층 여부

R2      계획 산문 + 비용 신호 ── 오케스트레이터          ← LD4 · B5
          필수 필드 §5.8

R3      갭 게이트 ── 생략이 있을 때만 AskUserQuestion   ← B3
          생략 0 → zero-click

R4      기준선 측
          ① baseline-cache 조회 (키 = merge_base × runner × file)
          ② 미적중분만: qg-worktree.sh create-baseline <merge_base> <sid>  [서브커맨드 추가]
             → deps 설치 (생태계 공유 캐시) → run-test-selection.sh       [신규]
          ③ 결과를 캐시에 기록 · 워크트리 폐기

R5      HEAD 측
          기존 create-sandbox (무변경) → runtime-verifier (페르소나 개정)
          setup fix · run-test-selection.sh · 상황별 부팅/플로우

R6      대조 ── diff-test-results.py                   [신규]  ← OQ1 + LD5 백스톱
          귀속 8종 + SILENT_DROP + BASELINE_UNRUNNABLE

R7      mutation-guard ── 기존, 바이트 무변경             ← Law 2

R8      원장 5차원 닫힘 검사 (check_qa_ledger.py) → verdict  [신규]

R9      샌드박스 폐기 (기존 remove)
```

**"상황별 층"의 정의 (floor 위에 얹히는 것).** LD3의 floor는 R4·R5의 테스트 러너 표면까지다. 그 **위**는 기존 계약이 그대로 담당한다 — `spec_acceptance_criteria` → `plan_features` → smoke의 fallback 사슬(`runtime-verifier.md:85-88`)과 `approved_surfaces` 부팅. 이 사슬은 내용이 바뀌지 않고 **위치만 재배치**된다: 예전엔 그것이 게이트의 전부였고, 이제는 floor 위의 선택 층이다. R1에서 모델이 "이 변경에 이 층이 필요한가"를 판정하고 그 판단을 계획 산문에 쓴다.

**R4가 R5보다 먼저인 이유** — 기준선 실행이 HEAD 샌드박스와 **다른 트리에서, verifier 개입 없이** 끝나야 한다. 같은 트리에서 코드를 되감았다 복원하면 mutation-guard의 의미가 흐려지고, verifier가 기준선을 조작해 진짜 회귀를 `PRE_EXISTING`으로 위장할 수 있는 경로가 생긴다 (누락 방향).

### 5.3 영향 판정 — 모델 소유 + 보조 입력 4종 등급

스코프 결정은 모델이 한다. 아래 넷은 **입력이지 규칙이 아니다** (CE `ce-test-browser/SKILL.md:51` — *"a starting point of common patterns, not an exhaustive rule set — apply judgment"*).

| 보조 입력 | 무엇 | 신뢰 등급 |
|---|---|---|
| `compute-test-scope-candidates.sh` 후보 목록 | diff의 src → 이름 매칭 test 파일 (Python/JS/TS) | **구조적** — 있으면 강한 신호, 없다고 없는 것은 아님 |
| git diff + commit message + PR description | 무엇이 바뀌었고 무엇을 **의도**했나 | **구조적** — gstack `:1190` 의도 대조 |
| 레포 CI 설정의 test-selection | CI가 무엇을 고르는가 | **참고** — 대체 금지, 차이는 계획에 명시 (B7) |
| `test-scope-validator` 분류 | `outdated-suspicion`/`cherry-pick-suspicion` | **부정 신호** — 그렇게 찍힌 테스트는 커버리지로 세지 않음 |

**신뢰 등급의 근거**(CE `SKILL.md:70`): *"prose mentions (docs, examples, troubleshooting) are unreliable and false-positive-prone — config files and `.env` are the trustworthy sources"*. 같은 정보라도 출처로 등급이 갈린다.

**빈 스코프 fail-safe** (gstack `:1173` 이식, 결정론 코드 없이 프로즈로):

> 후보 목록이 비었다고 검증을 건너뛰지 않는다. 백엔드·설정·인프라 변경도 앱 동작에 영향을 준다 — 영향분이 안 잡히면 그것 자체를 `gap` 차원에 기록하고, 러너 전체 실행 또는 smoke로 폭을 넓힐지 계획에 쓴다.

### 5.4 차등 실행과 기준선 캐시

**캐시 키 = `(merge_base sha, runner, test file path)`.** 전부 결정론적·내용주소.

- **무효화 로직이 없다.** rebase나 main 머지로 merge_base가 바뀌면 키 자체가 바뀐다. 구조적으로 stale이 불가능하다.
- **기준선 실행은 `/qg` 호출당이 아니라 merge_base당 1회.** 브랜치 수명 동안 `/qg`를 8번 돌리면 설치+실행 비용은 1번.
- 저장 위치: `.claude/quality-gates/baseline-cache/<merge_base_short>.md` — 마크다운 state (JSON 아님, CLAUDE.md 런타임 상태 규약). **세션 스코프가 아니다** — 세션을 넘어 살아남는 것이 목적이므로 `<sid>/` 형제로 둔다. GC 충돌은 §5.11이 닫는다.

파일 형식 (한 줄 = 한 결과. 파싱 실패 시 미적중 취급):

```markdown
<!-- qg-baseline-cache:v1 -->
merge_base: <full sha>
---
<runner>\t<file-or-BULK>\t<pass|fail|error>\t<exit-code>
```

`merge_base` 전체 sha를 **본문에도** 적는다 — 파일명은 short sha라 충돌 가능성이 0이 아니고, 본문 sha가 요청한 merge_base와 다르면 미적중으로 떨어뜨린다. 캐시 키의 세 요소(merge_base × runner × file)가 전부 파일 안에 있으므로 조회는 순수 문자열 매칭이다.

**gstack 대비 개선.** gstack의 `baseline.json`(`qa/SKILL.md:1330,1341-1345`)은 **시간주소**다 — *"이전 실행"* 과 비교하지 *변경 전 코드 상태*와 비교하지 않는다(brief §8이 지적한 약점). 같은 아이디어를 merge_base sha로 내용주소화하면 그 갭이 사라진다.

**deps 전략 — 옵션 ②(HEAD의 deps를 기준선으로 복사) 기각.** lockfile을 건드리는 diff에서 기준선이 HEAD의 의존성으로 돌아 어느 쪽도 아닌 hybrid 상태가 되고, 귀속이 **조용히** 틀린다. 누락 방향 fail-open이고 하필 가장 위험한 diff(의존성 변경)에서 발동한다. 채택: 각 트리에 정직하게 설치하되 생태계 공유 캐시(`GOMODCACHE` · `CARGO_HOME` · npm/uv 캐시)를 가리켜 다운로드 비용을 없애고, 나머지는 캐시로 상각한다.

**실행 형태 — 2단.** 파일당 실행이 아니다.

1. 각 측에서 영향 파일 **전체를 한 번에 bulk 실행**.
2. HEAD가 green이면 종료 — 귀속할 것이 없다.
3. HEAD가 red면 **실패한 파일에 대해서만** 양측에서 파일 단위 재실행.

흔한 경우(green) 2회, 비싼 경우에만 정밀해진다. 러너별 출력 파서 없이 **exit code만** 쓰므로 §5.9의 러너 전부에 같은 코드가 적용된다.

**`run-test-selection.sh` 계약:**

```
usage: run-test-selection.sh <worktree-abs> <runner> <mode> <file>...
  mode = bulk | per-file
stdout (per invocation): 한 줄에 하나
  <file-or-BULK>\t<pass|fail|error>\t<exit-code>
exit: 0 = 실행 완료(테스트 실패 포함) · 3 = 러너 부재/설치 실패(BASELINE_UNRUNNABLE) · 2 = 사용 오류
```

exit 0과 테스트 실패를 분리하는 것이 핵심이다 — UltraQA의 *"misleading success output: success phrases with non-zero exits"* 의 뒤집힌 형태로, 실행 실패와 테스트 실패를 뭉치면 귀속이 무너진다.

### 5.5 귀속 표 · flaky 처리

`diff-test-results.py`의 전 출력. 기준선 × HEAD 짝짓기:

| 기준선 | HEAD | 귀속 | 게이트 영향 |
|---|---|---|---|
| pass | pass | `STILL_GREEN` | — |
| pass | fail | `NEW_REGRESSION` | **FAIL** (재실행 1회 확증 후) |
| fail | fail | `PRE_EXISTING` | 보고만 — FAIL 아님 |
| fail | pass | `FIXED` | 보고 (긍정 증거) |
| 없음 | pass | `NEW_TEST_GREEN` | — |
| 없음 | fail | `NEW_TEST_RED` | **FAIL** (이 브랜치가 넣은 테스트) |
| 실행됨 | 미실행 | `SILENT_DROP` | **PASS 불가** ← LD5 백스톱 발화 |
| 미실행 | 실행됨 | `BASELINE_UNRUNNABLE` | degrade → git귀속 + **PASS 불가** |

**`PRE_EXISTING`이 FAIL이 아닌 것이 이 표의 핵심이다.** devbrew 자신의 stale red가 첫 실행부터 게이트를 막지 않으면서도 침묵하지 않는다 — `attribution` 차원에 기록되고 보고서에 나온다.

**flaky — 재실행은 정확히 1회, green이 나올 때까지가 아니다.**

- `NEW_REGRESSION` 후보만 HEAD에서 1회 재실행한다.
- 또 fail → 확증 `NEW_REGRESSION` → FAIL.
- pass → `FLAKY` 기록. 게이트를 FAIL시키지 않되 **보고서에 올린다**.
- 기준선에서 이미 red인 것은 재실행 대상이 아니다(이미 `PRE_EXISTING`) → 재실행 횟수가 구조적으로 유계.

UltraQA의 *"avoiding false green from a single lucky pass"* 를 뒤집은 형태다. 여기서 위험은 false green이 아니라 false red이고, **무한 재실행이 바로 false green 경로**이므로 1회로 잠근다 (P18 unbounded autonomy).

**`BASELINE_UNRUNNABLE` degrade 경로** — gbrain `skills/testing/SKILL.md:146-171` 이식. fail마다 ① 그 테스트 파일이 이번 diff에서 수정됐나 ② 그 테스트가 닿는 코드가 이번 diff에 있나 를 보고 `REGRESSION_SUSPECT` / `PRE_EXISTING_SUSPECT` / `UNKNOWN`으로 분류한다. **`_SUSPECT` 접미사가 계약이다** — 확증이 아니라는 표시이고, 이 경로에서는 verdict가 PASS가 될 수 없다.

### 5.6 LD7 원장 — floor 5차원 + derived

evidence-log 안에 산다. spec-distill 커버리지 원장과 같은 줄 모양:

```
- floor:changed      — closed   — 4 files, all plugins/x/scripts/; runner=pytest
- floor:behavior     — closed   — CLI --dry-run 경로 + 종료코드 계약
- floor:verification — closed   — 영향 테스트 3개 실행 (레포 전체 47개 중), 기준선 대비 차등
- floor:attribution  — closed   — 1 NEW_REGRESSION(확증) · 2 PRE_EXISTING · 0 FLAKY
- floor:gap          — closed   — 부팅 미수행(웹 표면 없음); AC4는 정책이라 런타임 확인 불가
- derived: 없음 — 순수 로직 변경으로 이 diff 특유의 확인 축 없음
```

**5차원의 질문형 정의** (열거가 아니라 질문 — LD7):

| 차원 | 질문 | 닫힘 조건 |
|---|---|---|
| `changed` | 무엇이 바뀌었나? | 변경 파일과 러너가 특정됨 |
| `behavior` | 그게 어떤 행동에 닿나? | 최소 1개 행동/경로가 이름으로 지목됨 |
| `verification` | 어떻게 확인하나? | 실행된 것 + 실행 방식(차등/bulk)이 기록됨 |
| `attribution` | 나온 결과가 무엇을 뜻하나? | 모든 fail에 귀속 라벨이 붙음 |
| `gap` | 못 확인하는 건 뭔가? | 미확인 항목이 열거됨 (0개면 "없음"도 명시) |

**`derived`의 "의무"는 "만들어라"가 아니라 "판단을 기록하라"다.** 0개여도 되지만 **왜 0개인지는 써야 한다**. 이래야 LD7이 경계한 천장(모델이 목록까지만 하고 멈춤)이 안 생기고 silent skip도 막힌다.

**구조적 게이트 `check_qa_ledger.py` (Law 1) — 구조만 본다.** floor 5키 존재 + 각 status ∈ {`closed`, `degraded`} + evidence 절이 비어있지 않음 + `derived:` 줄 존재. 의미 판정 없음.

`degraded`는 실패가 아니라 **1급 상태**다. "확증 못 했다"를 정직하게 표현할 자리가 있어야 "확인했다"로 반올림되지 않는다.

### 5.7 verdict 규칙

**새 verdict 토큰을 추가하지 않는다.** CE의 `PARTIAL`이 담던 정직함은 기존 `SKIP_WITH_EVIDENCE`가 이미 담는다.

| verdict | 조건 |
|---|---|
| `PASS` | floor 5차원 전부 `closed` **and** `NEW_REGRESSION`/`NEW_TEST_RED` 0 **and** `SILENT_DROP` 없음 **and** `forced_downgrade: no` **and** 상황별 층 통과 |
| `FAIL` | 확증된 `NEW_REGRESSION` ≥1 **or** `NEW_TEST_RED` ≥1 **or** `forced_downgrade: yes` **or** 상황별 층(부팅/플로우) 실패 |
| `SKIP_WITH_EVIDENCE` | 영향분 0개 **or** `BASELINE_UNRUNNABLE` **or** `SILENT_DROP` 감지 **or** 어느 floor 차원이 `degraded` |
| `NEEDS_RESOLUTION` | setup-fixable 잔존 — **기존 무변경** |

**`attribution degraded → PASS 불가`는 새 규칙이 아니라 기존 불변식의 두 번째 인스턴스다.** 샌드박스 비활성 시 `PASS → SKIP_WITH_EVIDENCE` cap(SKILL.md:641 I-A)과 같은 논리: **구조적 보장이 없으면 인증하지 않는다.**

### 5.8 계획 산문 · 갭 게이트

**계획 산문 필수 필드** (어투는 재량, 필드는 lock):

1. **무엇이 바뀌었나** — 사람 말로 (파일 나열이 아니라 "무엇을 하는 코드가")
2. **어떤 행동에 닿나** — 행동/경로 이름
3. **무엇을 돌리나 + 선택 비율** — `영향 테스트 12개 선택 (레포 전체 47개 중)`
4. **비용 신호** — 기준선 캐시 적중 여부 · 설치 필요 여부 · 대략 시간
5. **무엇을 안 돌리나** — 미선택분 · 자동화 불가 플로우 · blocked 표면
6. **CI와 다르면 그 차이** (B7)

**선택 비율이 과선택 방어 장치다.** 과선택이 실전에서 수렴하면 그 줄이 매번 `47개 중 47개`로 찍혀 안 보일 수가 없다 — 실패 양식이 스스로를 고발한다. 결정론적 상한(최대 N)은 두지 않는다: 그건 LD7의 천장이고, 사용자가 redirect할 수 있는 갭 게이트가 이미 escape hatch다.

**갭 게이트 발화 조건 (B3):**

- 위 5번(안 돌리는 것)이 **비어 있으면 발화하지 않는다** — 한 줄 계획 출력 후 zero-click.
- 비어 있지 않으면 `AskUserQuestion` 1회: 생략 목록을 보여주고 `그대로 진행` / `범위 넓혀서 다시 계획` / `중단`.
- 기존 Decision 2(`requires_decision` 있을 때만 발화)와 **동형**이다. 새 상호작용 패턴이 아니다.

질문 빈도가 **생략의 양에 비례**하므로, 질문이 뜰 때는 반드시 정보가 있다. 이것이 approval fatigue 문헌에 대한 구조적 응답이다.

### 5.9 러너 지원 행렬 · degrade 정밀화

| 러너 | 파일 지목 | 귀속 입도 |
|---|---|---|
| `pytest <path>` | 가능 | 파일 |
| `python -m unittest <dotted>` | 가능 (경로→모듈 변환) | 파일 |
| 직접 실행 `tests/*.sh` | 가능 | 파일 |
| jest / vitest `<path>` | 가능 | 파일 |
| `go test ./pkg/...` | 부분 | 패키지 |
| `cargo test` | 불가 | bulk |
| `make test` · 커스텀 `npm test` | 불가 | bulk |

**bulk-only는 확실성이 아니라 입도만 떨어뜨린다:**

| bulk 기준선 | bulk HEAD | 판정 |
|---|---|---|
| green | green | **통과 확정** |
| green | red | **새 회귀 확정** (파일 단위 불필요) |
| red | green | `FIXED` 확정 |
| **red** | **red** | **유일한 진짜 모호 지점** → `attribution: degraded` + `SKIP_WITH_EVIDENCE` |

모호 지점의 정직한 문장 (필수):

> `기준선도 빨간 상태입니다. 이 러너(<runner>)는 파일 단위 지목이 안 되므로 그 안에 새 회귀가 숨었는지 구분하지 못했습니다.`

**bulk-only 러너의 flaky 재실행.** §5.5의 "1회 재실행"은 여기서 *bulk 단위 재실행 1회*가 된다 (파일 단위가 불가능하므로). 재실행 대상은 `green → red` 조합 하나뿐이고, 횟수는 동일하게 1회로 잠긴다. `red → red`는 재실행하지 않는다 — 이미 모호 판정이라 재실행이 정보를 늘리지 못한다.

흔한 두 경우가 확정이므로 cargo/make 레포도 실전에서 정상 동작하고, 진짜 모호할 때만 물러선다. devbrew 자신은 pytest + `python -m unittest` + bash 스크립트 셋 다 파일 단위라 self-dogfood는 최상 입도로 돈다.

### 5.10 에러 처리 · graceful degradation

모든 degrade는 **loud**하다 (CLAUDE.md "Loud logging을 동반한 graceful degradation").

| 실패 | 동작 | 사용자에게 보이는 것 |
|---|---|---|
| `resolve-baseline.sh` degraded (detached/shallow/base 없음) | 차등 불가 → git-귀속 degrade, PASS 불가 | `> [quality-gates] baseline 확정 불가 (<사유>) — 차등 귀속 없이 진행, verdict는 PASS 불가` |
| 기준선 deps 설치 실패 / 오프라인 | `BASELINE_UNRUNNABLE` → git-귀속 degrade, PASS 불가 | `> [quality-gates] 기준선 실행 불가 (<사유>) — 귀속을 git 이력 추론으로 대체(확증 아님)` |
| 러너 부재 (exit 3) | 해당 러너 표면 skip, 다른 표면 계속 | `> [quality-gates] runner <x> 부재 — 이 표면 미실행` |
| bulk-only 러너 양쪽 red | `attribution: degraded` → SKIP_WITH_EVIDENCE | §5.9의 정직한 문장 |
| 캐시 파일 손상/파싱 실패 | 미적중으로 취급, 재실행 | `> [quality-gates] baseline 캐시 손상 — 재계산` |
| 영향분 0개 | `SKIP_WITH_EVIDENCE` + gap 기록 | `> [quality-gates] 영향분에 해당하는 기존 테스트 없음 — 실행 없음, 인증 없음` |
| `check_qa_ledger.py` 실패 | verdict를 PASS로 올리지 않음 | 게이트의 stderr verbatim |

**모든 degrade가 PASS를 막는 것은 아니다.** 러너 부재로 한 표면을 못 돌린 것은 `gap`에 기록되고 다른 표면의 PASS를 막지 않는다. **귀속에 관한 degrade만** PASS를 막는다 — 귀속이 없으면 "이 변경이 깼는가"에 답을 못 한 것이고, 그게 이 게이트의 존재 이유이기 때문이다.

### 5.11 GC 충돌 — 신규 위험이 드러낸 기존 결함

```python
qg-gc.py:27   SESSION_PATTERN = re.compile(r"^[A-Za-z0-9_-]{8,}$")
```

`baseline-cache`(14자)가 매치한다 → 24시간 TTL로 세션 폴더인 줄 알고 삭제된다.

**같은 패턴에 기존 `worktrees`(9자)도 매치한다.** 그 디렉토리엔 직접 파일이 없으므로 `_folder_mtime_ns`(`:51-55`)가 디렉토리 자신의 mtime으로 떨어지고, 24시간 넘게 새 worktree가 추가되지 않았다면 `rename` → `rmtree`된다(`:89-94`) — 안에 살아있는 worktree가 있어도. **코드 경로상의 결함이며 실행 재현은 구현 시 먼저 쓴다** (V-M1).

**수정: 이름의 charset이 아니라 내용으로 세션 폴더를 식별한다.** 알려진 세션 상태 파일 중 하나라도 든 디렉토리만 sweep 대상:

```
SESSION_MARKERS = {"pipeline.md", "files.md", "publish-eligible.md", "runtime-evidence.md"}
```

- **시간에 대해 fail-closed**다 — 미래에 형제 디렉토리가 추가돼도 자동으로 안전하다. denylist(`{"worktrees", "baseline-cache"}` 제외)를 쓰지 않는 이유가 이것이다: CLAUDE.md가 denylist를 금지하는 것과 같은 근거로, 내일 추가될 디렉토리를 오늘 열거할 수 없다.
- **오판 방향도 옳다**: 안 지우는 누수(빈 디렉토리 0바이트)가 살아있는 것을 지우는 것보다 안전하다.
- `SESSION_PATTERN`은 **함께 유지한다** (내용 + 이름 둘 다 만족해야 sweep) — 두 조건의 교집합이 단독보다 좁다.

---

## 6. Acceptance Criteria

**계약 이전**

- **AC1** — `skills/quality-pipeline/SKILL.md`에 리터럴 `regardless of Review scope`가 **0회** 등장한다.
- **AC2** — 새 transparency 앵커 문구가 `SKILL.md`에 **정확히 1회** 등장하고, `test_skill_orchestration_behavior.sh`가 존재+유일성을 검사한다 (락 이전, 삭제 아님).
- **AC3** — `scripts/check-allowed-tools-order.sh`가 신규 스크립트 4종을 포함한 순서로 갱신되고 통과한다.

**baseline 공유 모듈 (OQ5)**

- **AC4** — `scripts/resolve-baseline.sh`가 `base` · `base_ref` · `merge_base` · `degraded` 4키를 emit한다. detached HEAD · shallow clone · base 미해결 시 `degraded: yes`, exit 0.
- **AC5** — `check-review-scope.sh`와 `compute-test-scope-candidates.sh`가 **둘 다** `resolve-baseline.sh`를 소비한다. 두 파일에 리터럴 `main` 하드코딩 baseline이 **0회**.
- **AC6** — `check-review-scope.sh`의 기존 출력 5키(`changes_exist`/`branch_ahead_count`/`worktree_dirty`/`base`/`degraded`)와 exit 0 계약이 **불변**이다 (v2.7.0 단일책임 유지).

**차등 실행 · 캐시**

- **AC7** — `qg-worktree.sh create-baseline <sha> <session-id>`가 merge_base에 detached worktree를 만들고 절대경로를 emit한다. `remove`의 네임스페이스 가드(`:516-519`)가 이 경로에도 적용된다.
- **AC8** — baseline 캐시 키가 merge_base sha를 포함한다. merge_base가 바뀌면 **미적중**한다.
- **AC9** — `run-test-selection.sh`가 실행 실패(exit 3)와 테스트 실패(exit 0 + `fail`)를 **분리**해 emit한다.
- **AC10** — HEAD bulk가 green이면 파일 단위 재실행이 **0회**다 (2단 구조).

**귀속**

- **AC11** — `diff-test-results.py`가 §5.5의 귀속 8종을 전부 산출한다.
- **AC12** — `NEW_REGRESSION` 후보 재실행이 **정확히 1회**다. 2회 이상 재실행하는 코드 경로가 없다.
- **AC13** — `PRE_EXISTING`만 있는 실행은 verdict가 `FAIL`이 **아니다**.
- **AC14** — `SILENT_DROP` 감지 시 verdict가 `PASS`가 **아니다**.
- **AC15** — `BASELINE_UNRUNNABLE` 또는 어느 floor 차원 `degraded` 시 verdict가 `PASS`가 **아니다**.
- **AC16** — degrade 경로의 귀속 라벨에 `_SUSPECT` 접미사가 붙는다 (확증 아님 표시).

**원장 · 계획**

- **AC17** — `check_qa_ledger.py`가 floor 5키(`changed`/`behavior`/`verification`/`attribution`/`gap`) 존재 + status ∈ {`closed`,`degraded`} + 비어있지 않은 evidence 절 + `derived:` 줄을 검사한다. 하나라도 빠지면 non-zero.
- **AC18** — `derived: 없음`도 통과하되 **이유 절이 없으면 non-zero**다.
- **AC19** — 계획 산문에 §5.8의 6개 필수 필드가 모두 나타나며, 3번(선택 비율)은 `N개 선택 (전체 M개 중)` 형태를 갖는다.
- **AC20** — 생략 항목이 0개이면 갭 `AskUserQuestion`이 **발화하지 않는다**.

**기존 계약 보존**

- **AC21** — `scripts/detect-runtime.sh`가 **바이트 무변경**이다.
- **AC22** — `qg-worktree.sh`의 `create-sandbox` · `mutation-guard` 본문이 **바이트 무변경**이다 (`create-baseline` 추가는 새 case 절).
- **AC23** — `/qg runtime` 단일게이트 경로가 보존된다 (Step R-init의 zero-click 폴백 포함).
- **AC24** — `hooks/hooks.json` 항목 수가 **불변**이고 신규 훅 파일이 **0개**다.
- **AC25** — `agents/` 디렉토리의 파일 수가 **불변**이다 (신규 에이전트 0).
- **AC26** — verdict 토큰 집합이 `PASS`/`FAIL`/`SKIP_WITH_EVIDENCE`/`NEEDS_RESOLUTION` 4종으로 **불변**이다.

**GC**

- **AC27** — `qg-gc.py`가 `worktrees` · `baseline-cache` 디렉토리를 **삭제하지 않는다** (TTL 초과 상태에서도).
- **AC28** — `qg-gc.py`가 `pipeline.md` 또는 `files.md`를 가진 TTL 초과 세션 폴더는 **여전히 삭제한다**.

**메타**

- **AC29** — `plugin.json` version이 **major bump**(v3.0.0)되고 `CHANGELOG.md`에 `## [3.0.0] — 2026-XX-XX` 항목이 Added/Changed/Removed로 기록된다.
- **AC30** — `README.md`의 "Principles Instantiated"에 LD3/LD5/LD7 instantiation 줄이 추가되고, 컴포넌트 트리에 신규 스크립트 4종이 등재된다.

---

## 7. Files to Modify

### 신규 (4 + 테스트)

| 경로 | 무엇 |
|---|---|
| `scripts/resolve-baseline.sh` | base/base_ref/merge_base/degraded 공유 resolution (OQ5) |
| `scripts/run-test-selection.sh` | 결정론 테스트 실행 (bulk/per-file, exit 3 = 실행 불가) |
| `scripts/diff-test-results.py` | 기준선×HEAD 짝짓기 → 귀속 8종 + SILENT_DROP |
| `scripts/check_qa_ledger.py` | floor 5차원 구조 게이트 (Law 1) |

### 수정 (7)

| 경로 | 무엇 |
|---|---|
| `skills/quality-pipeline/SKILL.md` | Runtime 섹션 전면 개정 · `allowed-tools` 4종 추가 · AC1/AC2 락 이전 |
| `agents/runtime-verifier.md` | 페르소나 개정 — "전체 앱 부팅+AC 단언" → "합의된 계획 실행". 매니페스트 verbatim 소비 유지, 스코프 판정은 여전히 비-책임 |
| `scripts/compute-test-scope-candidates.sh` | `main` 하드코딩 → `resolve-baseline.sh` 소비 (C2 수정) |
| `scripts/check-review-scope.sh` | baseline resolution을 `resolve-baseline.sh`로 위임 (출력 계약 불변 — AC6) |
| `scripts/qg-worktree.sh` | `create-baseline` case 절 추가 (기존 절 무변경 — AC22) |
| `scripts/qg-gc.py` | 내용 기반 세션 식별 (§5.11) |
| `scripts/check-allowed-tools-order.sh` | 신규 4종 순서 등재 (C5) |

### 문서 (3)

`plugin.json` (major bump) · `CHANGELOG.md` · `README.md` (컴포넌트 트리 + Principles Instantiated)

### 테스트 (신규 파일 예상)

`tests/test_resolve_baseline.sh` · `tests/test_run_test_selection.sh` · `tests/test_diff_test_results.py` · `tests/test_qa_ledger.sh` · `tests/test_baseline_cache.sh` · `tests/test_qg_gc.py`(기존 확장) · `tests/harness/test_skill_orchestration_behavior.sh`(락 이전)

---

## 8. Verification Plan

### 8.1 자동 테스트

| id | 검사 | AC |
|---|---|---|
| T1 | `SKILL.md`에 구 리터럴 0회 · 신 앵커 1회 | AC1, AC2 |
| T2 | `resolve-baseline.sh` — 정상 / detached / shallow / base 미해결 4 픽스처 | AC4 |
| T3 | 두 소비자에 `main` 하드코딩 0회 (grep) + 실제 호출 존재 | AC5 |
| T4 | `check-review-scope.sh` 5키 출력 + exit 0 불변 (기존 `test_check_review_scope.sh` 그대로 통과) | AC6 |
| T5 | `create-baseline` — 경로 emit · detached 확인 · `remove` 네임스페이스 가드 적용 | AC7 |
| T6 | 캐시 키에 merge_base 포함 · merge_base 변경 시 미적중 | AC8 |
| T7 | `run-test-selection.sh` — 러너 부재(exit 3) vs 테스트 실패(exit 0 + fail) 분리 | AC9 |
| T8 | HEAD bulk green → per-file 호출 0회 (호출 카운터 stub) | AC10 |
| T9 | `diff-test-results.py` — 귀속 8종 각각 1 픽스처 | AC11 |
| T10 | `PRE_EXISTING`만 있는 입력 → verdict ≠ FAIL | AC13 |
| T11 | `SILENT_DROP` 입력 → verdict ≠ PASS | AC14 |
| T12 | `BASELINE_UNRUNNABLE` / floor degraded → verdict ≠ PASS | AC15 |
| T13 | degrade 라벨에 `_SUSPECT` 접미사 | AC16 |
| T14 | `check_qa_ledger.py` — 5키 각각을 하나씩 뺀 5 픽스처 전부 non-zero | AC17 |
| T15 | `derived: 없음` + 이유 있음 → 0 / 이유 없음 → non-zero | AC18 |
| T16 | `detect-runtime.sh` 바이트 동일 (sha 핀) | AC21 |
| T17 | `create-sandbox`/`mutation-guard` 본문 바이트 동일 | AC22 |
| T18 | `hooks.json` 항목 수 · `agents/` 파일 수 · verdict 토큰 집합 불변 | AC24–26 |
| T19 | `qg-gc.py` — `worktrees`/`baseline-cache` 생존 + 세션 폴더 삭제 (양방향) | AC27, AC28 |
| T20 | `plugin.json` major digit == 3 (patch digit unpin) | AC29 |
| T21 | **재실행 호출 횟수 == 1** — `NEW_REGRESSION` 후보 1건에 대해 `run-test-selection.sh` 호출 카운터가 정확히 1 증가 (stub 러너) | AC12 |

> **T20의 형태 주의** — 버전을 `"version": "3.0.0"` 리터럴로 핀하면 doc-only bump마다 stale-red가 된다. major 불변식만 검사하고 patch digit은 unpin한다.

### 8.2 mutation — 이빨 증명

통과가 정답인 assert는 모양만으로 이빨을 판별할 수 없다. 아래는 **수정을 되돌리면 RED가 되어야** 한다.

| id | mutation | RED가 되어야 할 테스트 |
|---|---|---|
| **M1** | `qg-gc.py`를 charset 패턴 단독으로 되돌림 | T19 전반 (`worktrees` 삭제됨) |
| **M2** | `qg-gc.py`가 아무것도 sweep하지 않게 만듦 | T19 후반 (세션 폴더 생존) — **양방향이라야 "안 지우게 만들어도 GREEN"이 막힌다** |
| **M3** | 신 앵커 문장을 삭제 / 두 번 삽입 | T1 (존재 / 유일성 각각) |
| **M4** | `PRE_EXISTING`을 FAIL로 승격 | T10 |
| **M5** | `attribution degraded`에서 PASS 허용 | T12 |
| **M6** | 재실행을 while 루프(green까지)로 변경 | **T21** — 결과만 보면 1회와 3회가 구분되지 않으므로 **호출 카운터**로만 잡힌다 |
| **M7** | 캐시 키에서 merge_base 제거 | T6 |
| **M8** | `check_qa_ledger.py`에서 키 검사를 헤딩 매칭으로 완화 | T14 — **body-unique 문구를 섹션 윈도우 안에서** 검사해야 헤딩만 남긴 mutation이 잡힌다 |
| **M9** | `resolve-baseline.sh`의 shallow 감지 제거 | T2 |
| **M10** | `run-test-selection.sh`가 exit 3과 테스트 실패를 뭉침 | T7 |

> **M6·M8이 이 계획의 취약 지점이다.** 둘 다 "결과가 같아 보이는" mutation이라, 결과값만 보는 assert로는 GREEN이 나온다. M6은 호출 카운터, M8은 body-unique + 섹션 윈도우가 필요하다. 구현 시 이 두 개를 **먼저** 쓴다.

### 8.3 수동 검증

| id | 시나리오 | 왜 수동인가 |
|---|---|---|
| **V1** | devbrew 자신에 `/qg runtime` self-dogfood — pytest + unittest + bash 셋 다 파일 단위 귀속이 나오는지 | 실제 러너 3종 동시 존재는 픽스처로 재현 불가 |
| **V2** | 기준선 캐시 적중 — 같은 브랜치에서 `/qg runtime` 2회, 두 번째가 기준선을 안 돌리는지 | 캐시 수명이 세션을 넘음 |
| **V3** | stale red 위에서의 첫 실행 — devbrew의 알려진 pre-existing red가 `PRE_EXISTING`으로 찍히고 FAIL을 안 만드는지 | 실제 red 목록이 환경 의존 |
| **V4** | 갭 게이트 zero-click — 생략 0인 diff에서 질문이 안 뜨는지 | AskUserQuestion 발화는 대화형 |
| **V5** | 갭 게이트 발화 — 자동화 불가 플로우가 있는 diff에서 질문이 뜨고 redirect가 되는지 | 위와 동일 |
| **V6** | Node 레포에서 기준선 deps 설치 — 실제 비용과 실패율 (§11 ②의 미실측 항목) | 외부 레지스트리 의존 |
| **V7** | `worktrees` 생존 — 실제 `/qg branch` 워크트리를 만들고 TTL 초과 후 GC를 돌려 생존 확인 | 실제 worktree + 시계 조작 |
| **V8** | 계획 산문의 가독성 — LD4 "전문용어 나열은 산출물 실패" 판정 | 사람만 판정 가능 |

---

## 9. Rejected Alternatives

1. **deps를 HEAD 샌드박스에서 기준선으로 복사 (§5.4 옵션 ②)** — lockfile을 건드리는 diff에서 기준선이 HEAD의 의존성으로 돌아 hybrid 상태가 되고 귀속이 **조용히** 틀린다. 누락 방향 fail-open이고 하필 가장 위험한 diff에서 발동한다.
2. **git-귀속 분류 단독 (OQ1 B안, gbrain 방식)** — 싸지만 추론이다. 진짜 회귀를 `PRE_EXISTING`으로 오분류하는 누락 방향 실패가 조용히 가능하다 (LD5 금지). **degrade 경로로는 채택**했다.
3. **git-귀속 선별 → 의심만 차등 확증 (OQ1 C안)** — 1단계가 `PRE_EXISTING`으로 잘못 친 것은 2단계가 아예 안 돌아 false green이 그대로 통과한다. 2번과 같은 구멍을 계층화로 감춘 모양.
4. **gstack식 명명 모드 4개 이식 (Diff-aware/Full/Quick/Regression)** — 그 4개는 *스코프를 무엇이 정하는가*로 나뉘는데 LD5가 그 답을 이미 하나로 고정했다. 남는 3개는 "이유와 함께 제안하는 이탈"일 뿐이고, 이름 붙은 메뉴는 LD7이 금지한 satisficing 천장이 된다.
5. **새 verdict `PARTIAL` 도입 (CE 3값)** — 기존 `SKIP_WITH_EVIDENCE`가 이미 그 정직함을 담는다. 어휘를 늘리면 4개 verdict를 소비하는 기존 라우팅·테스트·문서가 전부 갈라진다.
6. **컨테이너 격리 (qg v2.14.0 시도)** — LD1·brief §7. 목적이 아닌 격리에 노력이 전부 갔고 *"이 PR로 무엇이 깨지나"* 에 대한 답은 한 줄도 늘지 않았다. 재탐색 차단.
7. **영향 선택에 결정론적 상한 N** — LD7의 천장. 과선택 방어는 §5.8의 선택 비율 가시성이 담당하고, 사용자 redirect 가능한 갭 게이트가 escape hatch다.
8. **`check-review-scope.sh`를 확장해 merge_base·파일 목록도 emit (OQ5의 순진한 형태)** — v2.7.0이 의도적으로 좁힌 단일 책임(`:2-8`)을 되돌리는 것. 추출이 맞다.
9. **gstack `baseline.json` 그대로 (시간주소)** — *"이전 실행"* 과 비교하지 *변경 전 코드 상태*와 비교하지 않는다. merge_base 내용주소가 그 갭을 닫는다.
10. **`NEW_REGRESSION` 재실행을 green 나올 때까지** — false green 경로 그 자체. 1회로 잠근다 (P18).
11. **`qg-gc.py`를 denylist로 수정 (`worktrees`/`baseline-cache` 제외 목록)** — 공간에는 맞지만 **시간에 fail-open**이다. 내일 추가될 형제 디렉토리를 오늘 열거할 수 없다 (CLAUDE.md).
12. **제3의 게이트 신설 / 별도 플러그인 (OQ6 나머지 두 안)** — 전자는 LD1이 기각한 "전부 돌리기"를 남겨둬 실전에서 어느 쪽을 쓸지 모호해지고, 후자는 `resolve-baseline.sh` 공유가 cross-plugin 의존이 되며 레퍼런스 3개의 수렴 증거(command+skill 한 쌍)에 반한다.

---

## 10. Open Questions 처리

| OQ | 질문 | 처리 |
|---|---|---|
| **OQ1** | pre-existing red / flaky / 신규 회귀 구분 | **닫힘 (B2)** — 기준선 차등이 floor, git-귀속은 `_SUSPECT` degrade. §5.5. brief가 "레퍼런스에 답 없음"으로 못박았으나 gbrain 선례가 실재해 degrade 경로로 흡수 (C6) |
| **OQ2** | 쉬운 설명 + 합의가 rubber-stamp로 수렴 | **닫힘 (B3)** — 승인 질문을 커버리지 갭이 발화시킨다. 전부 돌리면 zero-click. §5.8 |
| **OQ3** | 과선택이 전체 실행으로 수렴 | **부분 닫힘 (B5)** — 계획 산문의 선택 비율로 자기고발형. 결정론 상한 없음. **실증은 없다** (§11 ③) |
| **OQ4** | 레포 CI의 test-selection과 두 진실 | **흡수 (B7)** — 별도 메커니즘 없이 OQ3의 답에 병합. CI는 보조 입력이고 차이는 계획 한 줄 |
| **OQ5** | Runtime의 baseline이 Review 로직을 재사용해야 하나 | **닫힘 (B6)** — 재사용하되 **추출** 형태. §5.2 R-init |
| **OQ6** | 산출물 단위 | **닫힘 (B1)** — 기존 Runtime 게이트 개정 |

---

## 11. 남는 갭 (명시)

1. **`PRE_EXISTING`의 사후 처리 경로가 없다.** 이 게이트는 pre-existing red를 *보고*할 뿐 고치라고 하지 않는다(Non-goal: 버그 수정 루프). 레포가 stale red를 계속 쌓으면 보고서가 길어지기만 한다. 축적 추이를 볼 장치는 이번 범위 밖.
2. **기준선 deps 설치의 실제 비용·실패율이 미실측이다.** §5.4의 캐시가 상각을 가정하지만 Node 대형 레포에서 첫 설치가 얼마나 걸리는지, 사설 레지스트리에서 얼마나 자주 실패하는지는 V6에서 처음 잰다. 실패율이 높으면 `BASELINE_UNRUNNABLE` degrade가 흔해지고 OQ1의 답이 실질적으로 기각안 2번으로 미끄러진다 — **그때 이 문서를 다시 열어야 한다.**
3. **OQ3(과선택 수렴)에 실증이 없다.** brief의 프로버도 *"추론적 확장, 직접 실증 아님"* 이라 자인했다. §5.8은 실패 양식을 **보이게** 만들 뿐 막지 못한다.
4. **의존 그래프 기반 영향 판정이 없다.** 보조 입력은 `compute-test-scope-candidates.sh`의 이름 매칭 휴리스틱이 전부다 — Python/JS/TS 외 언어는 변경된 테스트 파일 자체만 잡힌다. pytest-testmon 같은 coverage 기반 매핑은 계측 전제라 범용 플러그인에 넣지 않았다.
5. **부팅/플로우 층은 차등화하지 않는다.** 기준선에서 브라우저 플로우를 다시 돌리는 것은 비용·비결정성 모두에서 감당 불가다. 따라서 *"이 UI 깨짐이 원래 있었나"* 는 이 설계가 답하지 못한다 — 테스트 러너 표면에서만 귀속이 나온다.
6. **bulk-only 러너의 "양쪽 red" 빈도가 미실측이다.** cargo/make 레포에서 이 상태가 흔하면 그 레포들은 사실상 늘 `SKIP_WITH_EVIDENCE`를 받는다.
7. **`test-scope-validator`의 `ac_coverage`는 여전히 advisory다.** 이 spec은 그 출력을 `verification` 차원의 입력으로 소비하지만 블로킹으로 승격하지 않는다 (v2.1.0 계약 유지).

---

## 12. Metadata

| 항목 | 값 |
|---|---|
| 입력 brief | `docs/superpowers/interview/2026-07-26-qg-impact-driven-qa-runtime-interview.md` |
| 대상 플러그인 | `plugins/quality-gates` |
| 버전 영향 | **major — v2.14.x → v3.0.0** (`/qg runtime` 인터페이스 유지, "전체 앱 실행" 동작 제거) |
| 브랜치 | `feature/qg-impact-driven-runtime` |
| 신규/수정/문서 | 신규 4 · 수정 7 · 문서 3 |
| 신규 에이전트 | **0** |
| 신규 훅 | **0** |
| 신규 verdict 토큰 | **0** |
| 선행 레퍼런스 (통독) | `gstack/qa/SKILL.md` (1685줄) · `compound-engineering-plugin/skills/ce-test-browser/` (SKILL + references 2) · `oh-my-codex/skills/ultraqa/SKILL.md` + 자매 2 · `ECC/.agents/skills/e2e-testing/` · `ECC/agents/e2e-runner.md` · `gbrain/skills/testing/` · `gbrain/skills/smoke-test/` |
| 다음 단계 | `spec-distill:reviewing-spec` → `superpowers:writing-plans` |
