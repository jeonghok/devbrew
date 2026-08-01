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
  - [6.1 리뷰 라운드 1에서 추가된 AC (AC31–AC37)](#61-리뷰-라운드-1에서-추가된-ac-ac31ac37)
  - [6.2 리뷰 라운드 2에서 추가된 AC (AC38–AC44)](#62-리뷰-라운드-2에서-추가된-ac-ac38ac44)
  - [6.3 리뷰 라운드 3에서 추가된 AC (AC45–AC51)](#63-리뷰-라운드-3에서-추가된-ac-ac45ac51)
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
- 이 spec은 그 문장을 지우고 그 자리에 **영향-구동 + 기준선 대비 차등 실행**을 놓는다. 산출: **신규 스크립트 5 · 기존 파일 수정 7**(SKILL · verifier 페르소나 · 스크립트 5) **· 문서 3**. **신규 에이전트 0 · 신규 훅 0 · 신규 verdict 토큰 0.**
- **가장 중요한 단일 불변식**: `run-test-selection.sh`는 기준선 측·HEAD 측 **둘 다 오케스트레이터가 직접** 호출한다. verifier가 자기 턴 안에서 테스트를 돌려 결과를 self-report하는 경로는 금지 — 그러면 LD5의 "결정론은 모델 주장과 독립"이 무너진다 (§5.1 불변식 ②, AC31).
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

- 신규 스크립트 5종의 **내부 구현 문체·헬퍼 분해**. 입출력 계약·exit code·**호출 주체**는 §5가 lock한다.
- `runtime-verifier` 페르소나의 **수사·예시 순서**. 역할 경계(무엇을 하지 않는가 — 특히 "테스트 실행 결과는 판정에 안 들어간다")와 입력 필드는 §5.1·§5.2가 lock한다.
- 테스트 파일 배치(기존 `tests/` 구조에 맞춰 구현이 결정).
- `CHANGELOG.md`·README 항목 **문구**.
- 계획 산문의 **어투**(필수 필드는 §5.8이 lock).

**더 이상 defer하지 않는 것** (§4 위험 논의 + 리뷰 라운드 1에서 이 문서로 끌어올림): **기준선 deps 전략**(§5.4 — 옵션 ② 기각이 판정 정확성을 직접 결정) · **러너별 지원 등급과 degrade 조건**(§5.9 — verdict를 직접 결정) · **`qg-gc.py` 수정 방식**(§5.11 — denylist는 시간에 fail-open) · **`run-test-selection.sh`의 호출 주체**(§5.1 불변식 ② — LD5 독립성이 여기 걸림) · **러너 어댑터 8종의 닫힌 집합과 미지원 처리**(§5.9 — 추측 실행 금지가 안전 계약) · **baseline 캐시의 부분적중·원자성·손상 처리 소유자**(§5.4 — 반쯤 신뢰한 캐시가 조용히 틀린 귀속을 만든다) · **verdict 동시-성립 우선순위**(§5.7).

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
   이 목표는 **두 층으로 나뉜다** — "쉽다"를 통째로 사람 판정에 맡기면 측정 불가이기 때문이다:
   - **기계 검증 층 (AC19·AC20)** — §5.8의 6개 필수 필드가 모두 존재하고, 선택 비율이 `N개 선택 (전체 M개 중)` 형태이며, 생략 0일 때 게이트가 발화하지 않는다. 여기까지가 자동 테스트 대상이다.
   - **사람 판정 층 (V8)** — 그 필드들이 *읽히는지*. LD4의 "전문용어 나열은 산출물 실패"는 이 층이며, 기계로 임계를 세우지 않는다(어휘 금지 목록·최대 길이 같은 규칙은 LD7이 경계한 천장이 된다). **이 층은 통과 기준이 사람이라는 것 자체가 설계 결정이고, §11 ⑧에 잔여 갭으로 기록한다.**
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
- **`detect-runtime.sh` / `create-sandbox` / `mutation-guard` 계약 변경** — LD5 "배관은 기존 고정 계약이 기본값". 바이트 무변경 (AC21, AC22).
- **`/qg runtime` 단일게이트 동작 변경** — 기존 non-goal 승계 (AC23).
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
| **실행 (판단 있음)** | `runtime-verifier` (sandbox executor) | HEAD 샌드박스의 setup fix · 부팅 · 브라우저 플로우 | 실패마다 무엇을 고칠지 판단이 필요하다 |
| **실행 (판단 없음)** | `run-test-selection.sh` — **오케스트레이터가 직접 호출** | 기준선 측·HEAD 측 테스트 실행 | 판단이 없으므로 스크립트이고, **verifier 턴 밖에서 호출**해야 결과가 self-report를 거치지 않는다 |
| **대조** | `diff-test-results.py` (결정론) | 기준선×HEAD 짝짓기 → 귀속 + 침묵 백스톱 | 모델 주장과 독립이어야 백스톱이 된다 (LD5) |

**핵심 불변식 ①:** 모델은 **무엇을 돌릴지 한 번** 고르고, 그 선택은 **결정론적으로 두 번** 실행된다. 결정론이 지키는 것은 *선택*이 아니라 *짝짓기*다.

**핵심 불변식 ② (호출 주체 — LD5 독립성의 실제 담보):** `run-test-selection.sh`는 **양쪽 모두 오케스트레이터가 직접 호출한다.** `runtime-verifier`가 자기 턴 안에서 테스트를 돌리고 결과를 evidence-log로 self-report하는 경로는 **금지**다 — 그러면 오케스트레이터가 받는 것은 raw 출력이 아니라 모델의 요약이 되고, LD5가 정확히 막으려던 *"모델 주장이 자기 검증을 결정"* 이 재입장한다.

이것은 새 패턴이 아니라 **같은 파일에 이미 있는 R4/mutation-guard 패턴의 이식**이다 (`SKILL.md:696-714`): 오케스트레이터가 verifier dispatch가 *끝난 뒤* 별도로 스크립트를 호출하고, `SKILL.md:702`가 *"The verifier's own `writes:` self-report is advisory only; this git result is authoritative"* 라고 못박는다. 새 계약도 같은 문장을 갖는다:

> **verifier의 evidence-log에 적힌 테스트 결과는 advisory다. `run-test-selection.sh`의 오케스트레이터 호출 결과가 authoritative이며, 둘이 다르면 후자를 쓴다.**

verifier가 디버깅 중 테스트를 돌리는 것 자체를 막지는 않는다(Bash를 갖고 있고, setup이 됐는지 확인하려면 필요하다). 막는 것은 **그 결과가 판정에 들어가는 경로**다.

```
                  ┌─ 판정 (모델 · 오케스트레이터) ──┐
                  │  영향 스코프 · 계획 · 갭 게이트  │
                  └──────────────┬────────────────┘
                                 │ 같은 선택
                    ┌────────────┴────────────┐
                    ▼                         ▼
      기준선 측 (merge_base)            HEAD 측 (샌드박스)
      ┌──────────────────────┐        ┌──────────────────────────┐
      │ baseline-cache.sh get│        │ [verifier 턴] setup·부팅  │
      │ 미적중 → create-      │        │            ·플로우        │
      │ baseline → 오케스트    │        ├──────────────────────────┤
      │ 레이터가 run-test-    │        │ [verifier 턴 종료 후]     │
      │ selection.sh 호출     │        │ 오케스트레이터가 run-test-│
      │ → baseline-cache.sh   │        │ selection.sh 직접 호출    │
      │   put                 │        │ (self-report 아님)        │
      └──────────┬───────────┘        └────────────┬─────────────┘
                 └───────────┬────────────────────┘
                             ▼
                diff-test-results.py (결정론)
                귀속 8종 + SILENT_DROP 백스톱
```

**두 측 모두 `run-test-selection.sh`의 호출자는 오케스트레이터다** — 위 상자에서 verifier는 setup·부팅·플로우만 갖는다.

### 5.2 데이터 흐름 — R-init ~ R9

```
R-init  resolve-baseline.sh                          [신규]
          → base · base_ref · merge_base · degraded
          공유: check-review-scope.sh · compute-test-scope-candidates.sh · 이 게이트

R1a     러너 감지 ── run-test-selection.sh detect <project_dir>   [신규]
          → 어댑터 **집합** (runner · granularity · setup_cmd) × N
          이 집합이 R2 산문 · R4 · R5b · R6(--granularity)로 스레드된다.
          오케스트레이터는 감지 표를 재구현하지 않는다.

R1b     영향 판정 ── 오케스트레이터(모델)               ← LD5 전반부
          스코프 보조 입력 4종 (§5.3) — 러너 신호와 별개 축
          산출: 영향 unit 목록(어댑터별로 배정) + unclaimed 목록
                + 상황별 층 여부
          이 unit 목록이 R6의 `--expected` 독립 입력이 된다.

R2      계획 산문 + 비용 신호 ── 오케스트레이터          ← LD4 · B5
          필수 필드 §5.8

R3      갭 게이트 ── 생략이 있을 때만 AskUserQuestion   ← B3
          생략 0 → zero-click

R4      기준선 측 — 전 단계 오케스트레이터 소유 (verifier 미개입)
          ① baseline-cache.sh get   (키 = merge_base × runner × unit)      [신규]
          ② 미적중분만: qg-worktree.sh create-baseline <merge_base> <sid>  [서브커맨드 추가]
             → **기준선 트리에서 detect 재실행** (HEAD 집합 재사용 금지)
             → 어댑터마다 run-test-selection.sh run … (setup_cmd 포함)     [신규]
          ③ baseline-cache.sh put · 워크트리 폐기

R5a     HEAD 측 — verifier 턴 (판단이 필요한 것만)
          기존 create-sandbox (무변경) → runtime-verifier (페르소나 개정)
          **앱 부팅용** setup fix · 상황별 부팅/플로우.
          **테스트 실행도, 테스트 러너용 deps 설치도 여기 없다.**

R5b     HEAD 측 — verifier 턴 *종료 후*, 오케스트레이터가 직접
          run-test-selection.sh run <sandbox> <runner> …
          ← 불변식 ②. verifier의 evidence-log 테스트 결과는 advisory,
            이 호출 결과가 authoritative.
          ← setup_cmd를 R4와 **동일하게** 실행 (양측 준비 동등성)

R6      대조 ── diff-test-results.py (어댑터마다)      [신규]  ← OQ1 + LD5 백스톱
          --expected 는 R1b의 unit 목록 (생산자 산출물이 아닌 독립 입력)
          귀속 8종(총 함수) + SILENT_DROP + BASELINE_UNRUNNABLE
          + granularity=bulk의 PRE_EXISTING → attribution 원장 degraded

R7      mutation-guard ── 기존, 바이트 무변경             ← Law 2

R8      원장 5차원 닫힘 검사 (check_qa_ledger.py) → verdict  [신규]

R9      샌드박스 폐기 (기존 remove)
```

**기존 SKILL.md 스텝 → 새 스텝 매핑 (라운드 3 Finding 5 — 라벨이 같은데 내용이 다르다).** 기존 Runtime 섹션도 `R-init`/`R0`…`R6`를 쓰고 그 중 다섯 개는 `tests/harness/test_skill_orchestration_behavior.sh`가 **이름+위치로 락**한다. 새 흐름이 같은 라벨을 다른 뜻으로 재사용하므로, 매핑을 명시하고 **기존 로직이 전부 새 자리를 갖는지** 못박는다. 자리 없는 기존 로직은 삭제가 아니라 누락이다.

| 기존 스텝 | 기존 내용 | 새 자리 |
|---|---|---|
| `R-init` | `detect-runtime.sh` manifest · `approved_surfaces` · `block_policy` · **zero-click 폴백**(AC23이 보존 요구) | **R5a⁰** — R5a 진입 직전. 내용·조건 무변경 |
| `R0` | `create-sandbox` (3줄 파싱 + digest) | **R5a¹** — R5a 시작. 무변경 |
| `R1` | `test-scope-validator` dispatch | **R1b⁰** — 영향 판정의 보조 입력 하나(§5.3 4번째 행). dispatch 지점만 이동, 계약 무변경 |
| `R2` | spec AC 수집 + Runtime scope transparency 문구 | **R5a²** — 상황별 층의 assertion basis. transparency 문구는 §5.8 계획 산문으로 흡수(AC1/AC2 락 이전) |
| `R3` | `runtime-verifier` dispatch | **R5a³** — 페르소나만 개정 |
| `R4` | `mutation-guard` | **R7** — 무변경 |
| `R5` | sandbox `remove` | **R9** — 무변경 |
| `R6` | outcome routing + publish sentinel | **R8** — verdict 규칙만 §5.7로 교체, sentinel 경로 무변경 |

**락 이전 의무.** 위 테스트가 락하는 스텝 라벨(`Step R0`/`Step R-init`/`Step R2`/`Step R3`/`Step R6`)은 SKILL.md 개정과 **같은 커밋에서** 새 라벨로 옮긴다. AC1/AC2의 "regardless of Review scope" 락 이전과 같은 처리이며, 라벨만 지우고 테스트를 남기면 스위트가 빨개지고 테스트만 지우면 회귀 방어가 사라진다.

**"상황별 층"의 정의 (floor 위에 얹히는 것).** LD3의 floor는 R4·R5b의 테스트 러너 표면까지다(R5a의 부팅·플로우는 floor가 아니다). 그 **위**는 기존 계약이 그대로 담당한다 — `spec_acceptance_criteria` → `plan_features` → smoke의 fallback 사슬(`runtime-verifier.md:85-88`)과 `approved_surfaces` 부팅. 이 사슬은 내용이 바뀌지 않고 **위치만 재배치**된다: 예전엔 그것이 게이트의 전부였고, 이제는 floor 위의 선택 층이다. R1b에서 모델이 "이 변경에 이 층이 필요한가"를 판정하고 그 판단을 계획 산문에 쓴다.

**R4가 R5a/R5b보다 먼저인 이유** — 기준선 실행이 HEAD 샌드박스와 **다른 트리에서, verifier 개입 없이** 끝나야 한다. 같은 트리에서 코드를 되감았다 복원하면 mutation-guard의 의미가 흐려지고, verifier가 기준선을 조작해 진짜 회귀를 `PRE_EXISTING`으로 위장할 수 있는 경로가 생긴다 (누락 방향).

**R5b가 R5a *뒤*인 이유** — deps 설치·`.env` 같은 setup은 판단이 필요해 verifier의 몫이고, 테스트는 그 setup이 끝난 트리에서 돌아야 한다. 순서를 뒤집으면 setup 전 상태를 재는 셈이다. 그러나 **같은 턴 안에서 섞으면 안 된다** — 불변식 ②.

**테스트 실행이 남기는 아티팩트 (`.pytest_cache`/`__pycache__`/`.tox` 등)와 mutation-guard의 충돌.** R7의 guard는 Layer 1에서 `add -A`를 `-f` 없이 돌리므로 **baseline `.gitignore`에 등재된 아티팩트는 무해**하다. 등재되지 않은 레포에서는 `disallowed_new_files`로 잡혀 `forced_downgrade: yes` → 거짓 FAIL이 된다. 이 위험은 원래도 존재했지만(verifier가 Bash로 테스트를 돌릴 수 있었으므로) **이 설계는 테스트 실행을 floor로 만들어 상시화한다.** 대응은 §5.9의 러너 어댑터가 소유한다 — 각 어댑터가 아티팩트 억제 인자(예: pytest `-p no:cacheprovider`, `PYTHONDONTWRITEBYTECODE=1`)를 선언하고, 억제가 불가능한 러너는 §11 ⑨에 잔여 갭으로 기록한다.

### 5.3 영향 판정 — 모델 소유 + 보조 입력 4종 등급

스코프 결정은 모델이 한다. 아래 넷은 **입력이지 규칙이 아니다** (CE `ce-test-browser/SKILL.md:51` — *"a starting point of common patterns, not an exhaustive rule set — apply judgment"*).

> **용어 경계.** 이 절의 "**스코프 보조 입력**"은 *어떤 파일을 돌릴까*의 입력이고, §5.9의 "**러너 감지 신호**"는 *무엇으로 돌릴까*의 입력이다. 축이 다르므로 아래 4종에 러너 신호는 포함되지 않는다. `detect-runtime.sh` 매니페스트는 **스코프 보조 입력이 아니며**, 이 설계에서 그것이 쓰이는 곳은 R5a의 상황별 층 하나뿐이다(`approved_surfaces` 기반 부팅 — 기존 계약 그대로). 실행할 러너 식별에는 쓰지 않는다(§5.9).

| 스코프 보조 입력 | 무엇 | 신뢰 등급 |
|---|---|---|
| `compute-test-scope-candidates.sh` 후보 목록 | diff의 src → 이름 매칭 test 파일 (Python/JS/TS) | **구조적** — 있으면 강한 신호, 없다고 없는 것은 아님 |
| git diff + commit message + PR description | 무엇이 바뀌었고 무엇을 **의도**했나 | **구조적** — gstack `:1190` 의도 대조 |
| 레포 CI 설정의 test-selection | CI가 무엇을 고르는가 | **참고** — 대체 금지, 차이는 계획에 명시 (B7) |
| `test-scope-validator` 분류 | `outdated-suspicion`/`cherry-pick-suspicion` | **부정 신호** — 그렇게 찍힌 테스트는 커버리지로 세지 않음 |

**신뢰 등급의 근거**(CE `SKILL.md:70`): *"prose mentions (docs, examples, troubleshooting) are unreliable and false-positive-prone — config files and `.env` are the trustworthy sources"*. 같은 정보라도 출처로 등급이 갈린다.

**빈 스코프 fail-safe** (gstack `:1173` 이식, 결정론 코드 없이 프로즈로):

> 후보 목록이 비었다고 검증을 건너뛰지 않는다. 백엔드·설정·인프라 변경도 앱 동작에 영향을 준다 — 영향분이 안 잡히면 그것 자체를 `gap` 차원에 기록하고, 러너 전체 실행 또는 smoke로 폭을 넓힐지 계획에 쓴다.

### 5.4 차등 실행과 기준선 캐시

**캐시 키 = `(merge_base sha, runner, unit)`.** 전부 결정론적·내용주소. `unit`의 의미는 어댑터의 `granularity`가 정한다(아래 계약 참조).

- **무효화 로직이 없다.** rebase나 main 머지로 merge_base가 바뀌면 키 자체가 바뀐다. 구조적으로 stale이 불가능하다.
- **기준선 실행은 `/qg` 호출당이 아니라 merge_base당 1회.** 브랜치 수명 동안 `/qg`를 8번 돌리면 설치+실행 비용은 1번.
- 저장 위치: `.claude/quality-gates/baseline-cache/<merge_base_short>.md` — 마크다운 state (JSON 아님, CLAUDE.md 런타임 상태 규약). **세션 스코프가 아니다** — 세션을 넘어 살아남는 것이 목적이므로 `<sid>/` 형제로 둔다. GC 충돌은 §5.11이 닫는다.

파일 형식 (한 줄 = 한 결과. 파싱 실패 시 미적중 취급):

```markdown
<!-- qg-baseline-cache:v1 -->
merge_base: <full sha>
---
<runner>\t<unit>\t<pass|fail|error|unrun|absent>\t<exit-code>
```

`merge_base` 전체 sha를 **본문에도** 적는다 — 파일명은 short sha라 충돌 가능성이 0이 아니고, 본문 sha가 요청한 merge_base와 다르면 미적중으로 떨어뜨린다. 캐시 키의 세 요소(merge_base × runner × unit)가 전부 파일 안에 있으므로 조회는 순수 문자열 매칭이다.

**`unrun`은 캐시에 넣지 않는다.** 실행하지 못했다는 사실은 환경 상태(설치 실패·네트워크)에 달렸고 merge_base의 함수가 아니므로, 캐시하면 다음 실행에서 복구 가능한 실패가 영구화된다. `absent`는 캐시한다 — merge_base 트리의 함수라 안정적이다.

**소유 컴포넌트 — `scripts/baseline-cache.sh` (신규).** 캐시의 조회·검증·부분적중·갱신·동시성을 **한 스크립트가 전부** 갖는다. §5.1의 3분업 어디에도 안 들어가는 로직을 남기지 않기 위한 것이며, 오케스트레이터는 이 두 서브커맨드만 호출한다:

```
usage: baseline-cache.sh get <cache-root> <merge_base> <runner> <file>...
  stdout: 적중한 항목만 한 줄씩 `<file>\t<status>\t<exit-code>`
          (미적중 파일은 출력하지 않는다 → 호출자가 stdin 목록과 차집합해 미적중분을 얻는다)
  exit:   0 = 정상(0건 적중 포함) · 4 = 캐시 손상(전량 미적중으로 취급, loud)

usage: baseline-cache.sh put <cache-root> <merge_base> <runner> < results.tsv
  stdin:  `<file>\t<status>\t<exit-code>` 줄들
  exit:   0 = 기록 완료 · 4 = 기록 실패(advisory, 게이트를 막지 않음)
```

| 항목 | 규칙 |
|---|---|
| **부분 적중** | 정상 경로다. `get`이 적중분만 emit하고, 호출자가 미적중분만 R4②로 보낸다. 부분적중 병합은 "적중 줄 ∪ 새 실행 줄"이며 **키 충돌 시 새 실행이 이긴다** (같은 merge_base면 내용도 같아야 하므로 충돌 자체가 이상 신호 — `put`이 loud advisory를 낸다). |
| **원자적 쓰기** | `put`은 같은 디렉토리의 임시 파일에 전량을 쓴 뒤 `mv`로 rename한다. 부분 기록된 파일이 관측되지 않는다. |
| **동시성** | 락을 쓰지 않는다. 키가 내용주소(merge_base sha)라 **동시 실행이 쓰는 내용이 동일**하므로 rename의 last-write-wins가 안전하다. 이것이 시간주소 캐시 대비 이 설계의 부수 이득이다. |
| **손상 처리** | 헤더 마커 불일치 · `merge_base` 줄 불일치 · 파싱 실패 → exit 4 + 전량 미적중. **부분 파싱해서 일부만 신뢰하지 않는다** (반쯤 신뢰한 캐시가 조용히 틀린 귀속을 만든다). |
| **수명** | GC 대상이 아니다(§5.11). merge_base가 바뀌면 새 파일이 생기고 옛 파일은 남는다 — 누적은 `.claude/quality-gates/baseline-cache/`의 파일 수로 보이며, 정리는 `/cancel-qg --all` 경로에 위임한다(§11 ⑩). |

**gstack 대비 개선.** gstack의 `baseline.json`(`qa/SKILL.md:1330,1341-1345`)은 **시간주소**다 — *"이전 실행"* 과 비교하지 *변경 전 코드 상태*와 비교하지 않는다(brief §8이 지적한 약점). 같은 아이디어를 merge_base sha로 내용주소화하면 그 갭이 사라진다.

**deps 전략 — 옵션 ②(HEAD의 deps를 기준선으로 복사) 기각.** lockfile을 건드리는 diff에서 기준선이 HEAD의 의존성으로 돌아 어느 쪽도 아닌 hybrid 상태가 되고, 귀속이 **조용히** 틀린다. 누락 방향 fail-open이고 하필 가장 위험한 diff(의존성 변경)에서 발동한다. 채택: 각 트리에 정직하게 설치하되 생태계 공유 캐시를 가리켜 다운로드 비용을 없애고, 나머지는 기준선 캐시로 상각한다.

**공유 범위는 "다운로드 캐시만, 빌드 산출물은 절대 아님" (라운드 3 Finding 3).** 이 구분이 옵션 ② 기각 사유와 같은 오염을 뒷문으로 들이지 않는 경계다:

| 공유함 (머신 전역, 기본 위치 그대로) | 공유 안 함 (트리별 독립) |
|---|---|
| `GOMODCACHE` · `CARGO_HOME/registry` · npm `_cacache` · uv/pip wheel 캐시 | `CARGO_TARGET_DIR` · `target/` · `node_modules/` · `.venv/` |

왼쪽은 **내용주소**(패키지 해시가 키)라 두 트리가 같은 항목을 봐도 정의상 같은 바이트다. 오른쪽은 **트리 의존**(그 트리 소스로 빌드된 산출물)이라 공유하면 기준선이 HEAD의 컴파일 결과를 재사용해 조용히 틀린 귀속을 만든다 — 옵션 ②를 기각한 바로 그 이유다. 재컴파일을 아끼려 `CARGO_TARGET_DIR`를 공유하려는 유혹이 특히 강하므로 명시적으로 금지한다.

**실행 형태 — 2단.** 파일당 실행이 아니다.

1. 각 측에서 영향 파일 **전체를 한 번에 bulk 실행**.
2. HEAD가 green이면 종료 — 귀속할 것이 없다.
3. HEAD가 red면 **실패한 파일에 대해서만** 양측에서 파일 단위 재실행.

흔한 경우(green) 2회, 비싼 경우에만 정밀해진다. 러너별 출력 파서 없이 **exit code만** 쓰므로 §5.9의 러너 전부에 같은 코드가 적용된다.

**`run-test-selection.sh` 계약 — 2개 서브커맨드.**

```
usage: run-test-selection.sh detect <worktree-abs>
stdout: 감지된 어댑터 **하나당 3줄** (0개 이상 — 폴리글랏 레포는 복수)
  runner: <8개 식별자 중 하나>
  granularity: file | package | bulk
  setup_cmd: <결정론적 설치 명령 | ->    # '-' = 설치 불필요
  (빈 줄로 구분; 감지 0개면 stdout 비움)
exit: 0 = 감지 완료(0개 포함) · 2 = 사용 오류

usage: run-test-selection.sh run <worktree-abs> <runner> <mode> <unit>...
  mode = bulk | per-unit
stdout: **입력 unit 하나당 정확히 한 줄** (총 함수 — 빠짐 없음)
  <unit>\t<pass|fail|error|unrun|absent>\t<exit-code>
exit: 0 = 실행 시도 완료(테스트 실패 포함) · 3 = 러너 부재/설치 실패 · 2 = 사용 오류
      exit 3 이어도 **모든 unit에 대해 `unrun` 행을 emit**한다.
```

**`detect`는 어댑터를 **집합**으로 반환한다 (라운드 3 block).** 초안은 정확히 하나를 반환했는데, 그러면 **폴리글랏 레포에서 우선순위 밖 러너의 테스트가 floor에서 영구 누락**된다. 이 레포에서 실측한 결과가 그 실패의 정확한 사례다:

```
devbrew: .sh 테스트 130개 · .py 테스트 50개 · repo-root 러너 설정 없음
단일-러너 계약 → unittest 선택 → shell 테스트 130개 전량 미실행 (조용히)
```

LD5가 금지한 **누락 방향 실패**이고, 하필 이 게이트가 처음 돌 레포다. 따라서 다중 어댑터는 선택이 아니라 floor가 의미를 갖기 위한 필수 조건이다.

**우선순위 표(§5.9)의 역할이 바뀐다 — 배제가 아니라 소유권 충돌 해소다.** 각 어댑터는 자기가 **소유하는 파일 패턴**이 있고, 표의 순서는 *같은 패턴을 두 어댑터가 주장할 때만* 발동한다:

| 파일 패턴 | 주장하는 어댑터 | 충돌 해소 |
|---|---|---|
| `test_*.py` / `*_test.py` | pytest · unittest | pytest 설정이 있으면 pytest, 없으면 unittest |
| 실행비트 `tests/*.sh` | shell | 단독 |
| `*.test.[jt]sx?` / `*.spec.*` | jest · vitest | devDeps에 있는 쪽 |
| 패키지 내 `*_test.go` | go | 단독 |
| (패턴 무관) | cargo · make · npm-script | bulk — 아래 참조 |

**unit → 어댑터 배정.** R1b가 고른 각 unit은 파일 패턴으로 **정확히 하나의 어댑터**에 배정된다. 어느 어댑터도 주장하지 않는 unit은 **`unclaimed`** 로 기록되고 `gap` 차원에 열거된다 — 조용히 사라지지 않는다. bulk 어댑터(cargo/make/npm-script)는 패턴 소유가 없으므로, **다른 어댑터가 주장하지 않은 unit이 남아 있고 bulk 어댑터가 감지됐을 때만** 그 잔여를 `BULK` 하나로 흡수한다.

**실행은 어댑터별로 반복된다.** R4·R5b는 감지된 어댑터마다 `run`을 호출하고, R6은 어댑터마다 대조한다. 캐시 키가 이미 `runner`를 포함하므로(§5.4) 어댑터 간 결과가 섞이지 않는다. verdict는 어댑터별 결과를 §5.7 우선순위로 **집계**한다 — 한 어댑터의 확증 회귀는 다른 어댑터가 green이어도 FAIL이다.

**양측 재감지 (라운드 3 Finding 2).** `detect`는 **HEAD 트리(R1a)와 기준선 워크트리(R4②) 양쪽에서** 실행된다. diff가 테스트 인프라 자체를 바꾸는 경우(unittest→pytest 마이그레이션, `package.json`에 jest 신규 추가)에 두 집합이 다를 수 있고, 그때 한쪽에만 있는 어댑터의 unit은 반대편에서 `unrun`이 되어 **귀속 불가로 degrade**된다. HEAD 감지를 기준선에 그대로 재사용하면 spurious `error`가 나와 회귀를 `PRE_EXISTING`으로 은폐할 수 있다 — 이 설계의 존재 이유를 정면으로 훼손하는 경로다. 두 집합이 다르면 그 사실을 계획 산문과 `gap`에 명시한다.

**`detect`가 별도 서브커맨드인 이유 (라운드 2 Finding B).** `<runner>`가 `run`의 CLI 인자인데 감지가 스크립트 내부 로직이면 순환이다. 또 계획 산문(R2)은 R4/R5b **이전**에 러너 이름을 노출해야 한다. `detect`를 분리하면 감지 지식은 여전히 한 스크립트가 단독 소유하고(어댑터 표 = 유일 소유자), 오케스트레이터는 R1a(HEAD)와 R4②(기준선) 양쪽에서 호출해 그 어댑터 집합을 R2 산문·R4·R5b·R6에 스레드한다. 오케스트레이터가 감지 표를 재구현하는 경로는 없다.

**`unit`이 `file`을 대체한다.** `granularity`에 따라 의미가 정해진다:

| granularity | unit의 의미 | 이 러너들 |
|---|---|---|
| `file` | 테스트 파일 경로 (repo-relative) | pytest · unittest · shell · jest/vitest |
| `package` | 패키지 디렉토리 | go |
| `bulk` | 리터럴 `BULK` **하나뿐** | cargo · make · npm-script |

**`BULK`가 캐시 키로 안전한 이유 — 그리고 그 논증이 보장하지 *않는* 것 (라운드 2·3).** `granularity: bulk`인 어댑터는 §5.9 표대로 **파일 인자를 무시한다** — `cargo test`·`make test`·`npm test`는 선택 집합과 무관하게 같은 명령이다. 따라서 그 결과는 `(merge_base, runner)`만의 함수이고, 서로 다른 선택이 한 키를 공유하는 **캐시 오염은 원리적으로 불가능**하다.

> **이 논증은 *재현성*만 증명하고 *커버리지 완전성*은 증명하지 않는다** (라운드 3 Finding 3). 같은 명령이 같은 결과를 준다는 것과, 그 명령이 diff가 건드린 코드를 전부 커버한다는 것은 별개다. 실제 함정: 루트 패키지가 있는 Cargo 워크스페이스에서 `--workspace` 없는 `cargo test`는 sibling crate를 조용히 건너뛴다 — exit 0 + green이라 어떤 degrade 신호도 없다. 우리가 명령 내부를 통제하지 않으므로 이것은 **검증할 수 없다**.
>
> **처리:** bulk 어댑터에서는 `verification` 차원 evidence에 `커버리지 미보장(러너가 선택을 무시함)`을 **의무 기재**하고, 같은 문구를 계획 산문(§5.8)과 최종 보고서에 항상 노출한다. verdict를 막지는 않는다 — 막으면 cargo/make 레포에서 게이트가 영구히 무용해진다. 대신 **주장의 강도를 낮춘다**: 그 실행은 "영향분을 확인했다"가 아니라 "러너 전체를 돌렸고 그 안에 영향분이 포함되기를 기대한다"이다. §11 ⑫에 잔여 갭으로 기록.
반대로 `granularity ∈ {file, package}`에서는 **`BULK` 키가 아예 생기지 않는다**: bulk 모드로 green이 나오면 *"집합 전체가 통과했으므로 각 unit이 통과했다"* 가 성립하므로 **unit별 `pass` 행으로 분해해** 캐시에 넣는다. red이면 unit별 재실행 결과를 넣는다. 캐시의 키 공간은 언제나 unit 하나다.

**5개 상태값과 총 함수 (라운드 2 codex Finding).** §5.5 귀속 표의 `없음`·`미실행` 축을 생산하는 주체가 여기다:

| 상태 | 의미 | §5.5 축 |
|---|---|---|
| `pass` / `fail` | 러너가 판정함 | pass / fail |
| `error` | 수집·import 실패 등 러너가 실행조차 못한 결함 | fail로 접힘 + `(error)` 병기 |
| `absent` | 그 워크트리에 unit이 존재하지 않음 (스크립트가 직접 확인) | **없음** |
| `unrun` | 어댑터 부재(exit 3)이거나 러너가 그 unit에 판정을 안 냄 | **미실행** |

**행이 빠지는 것은 계약 위반이다.** 소비자(`diff-test-results.py`)는 입력 unit 목록과 수신 행을 대조해, 행이 없는 unit이 있으면 `SILENT_DROP`으로 fail-closed한다 — 부재를 추론으로 메우지 않는다.

**`setup_cmd`가 어댑터 소유인 이유 (라운드 2 codex Finding).** deps 설치가 기준선은 오케스트레이터, HEAD는 verifier 소유이면 두 측이 다른 명령·다른 환경으로 준비되어 **차등 비교가 사과와 오렌지**가 된다 — OQ1의 존재 이유가 무너진다. 그래서 **테스트 러너용 설치는 어댑터가 선언하고 `run`이 양측에서 동일하게 실행**한다. verifier가 하는 setup은 *앱 부팅용*(서버 `.env` 등)에 한정되며 테스트 러너 준비와 겹치지 않는다. HEAD에만 적용된 추가 setup이 있으면 그것은 양측 비대칭이므로 evidence-log와 `gap` 차원에 **기록하고 표면화**한다.

exit 0과 테스트 실패를 분리하는 것이 핵심이다 — UltraQA의 *"misleading success output: success phrases with non-zero exits"* 의 뒤집힌 형태로, 실행 실패와 테스트 실패를 뭉치면 귀속이 무너진다.

### 5.5 귀속 표 · flaky 처리

**`diff-test-results.py` 계약 (라운드 3 Finding 4 — 다른 넷과 달리 이것만 계약이 없었다):**

```
usage: diff-test-results.py --expected <file> --baseline <file> --head <file>
                            --granularity file|package|bulk --runner <id>
  --expected  R1b가 고른 unit 목록 (한 줄에 하나) — **독립 입력**
  --baseline  기준선 측 run 출력 (캐시 적중분 병합 후)
  --head      HEAD 측 run 출력
stdout (YAML):
  runner: <id>
  attributions:
    - unit: <unit>
      verdict: STILL_GREEN|NEW_REGRESSION|PRE_EXISTING|FIXED|NEW_TEST_GREEN
               |NEW_TEST_RED|SILENT_DROP|BASELINE_UNRUNNABLE
      note: "<(error) 병기 등>"
  attribution_status: closed | degraded
  counts: {new_regression: N, pre_existing: N, ...}
exit: 0 = 대조 완료 · 4 = 입력 파싱 실패/중복 unit 행(fail-closed) · 2 = 사용 오류
```

**`--expected`가 독립 입력인 것이 이 계약의 핵심이다.** `SILENT_DROP`을 *두 생산자 산출물의 상호 대조*로 계산하면, 두 스크립트가 **같은 unit-이름 정규화 버그**로 같은 unit을 대칭적으로 누락할 때 아무도 눈치채지 못한다 — "총 함수" 보장이 소비자의 독립 검증이 아니라 **생산자의 자기일관성**에 기대게 된다. 그래서 기준은 R1b가 고른 원본 목록이다: `--expected`에 있는데 어느 쪽 산출물에도 행이 없으면 `SILENT_DROP`이다.

**중복 unit 행은 exit 4다.** 같은 unit이 두 번 나오면 어느 쪽을 믿을지 결정할 근거가 없고, 조용히 last-wins하면 결과가 입력 순서에 의존한다.

아래는 그 `attributions[].verdict`의 전 범위다. 기준선 × HEAD 짝짓기:

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

**표의 축 ← `run-test-selection.sh`의 5개 상태값 (§5.4).** 축은 추론이 아니라 스크립트가 emit한 값에서 온다:

| 표의 축 | 스크립트 상태값 |
|---|---|
| pass | `pass` |
| fail | `fail` · `error`(라벨에 `(error)` 병기) |
| 없음 | `absent` |
| 미실행 | `unrun` |
| (행 자체가 없음) | **계약 위반 → `SILENT_DROP`** |

- **`error`는 `fail`로 접는다.** 수집 에러·import 실패는 *실제 결함*이지 실행 불능이 아니다 — 이번 변경이 import를 깼다면 그것은 회귀다. 다만 귀속 라벨에 `(error)`를 병기해 원인이 assertion이 아님을 보인다: `NEW_REGRESSION(error)`.
- **러너 부재·설치 실패(스크립트 exit 3)는 `error`가 아니라 `unrun`이다.** 표의 `미실행` 축으로 가서 `BASELINE_UNRUNNABLE` 또는 `SILENT_DROP`이 된다. 이 둘을 뭉치면 "실행했는데 깨졌다"와 "아예 못 돌렸다"가 같은 결론을 받게 되므로 §5.4 계약이 상태값과 exit code로 분리한다.
- **양측 모두 `unrun`이면** 그 unit은 어느 방향으로도 판정되지 않았다 → `BASELINE_UNRUNNABLE`과 같은 취급(귀속 불가, PASS 불가). 조용히 `STILL_GREEN`으로 떨어지지 않는다.

**`granularity`가 표를 바꾸지는 않는다 — 원장 상태를 바꾼다 (라운드 2 Finding A).** `diff-test-results.py`는 `--granularity file|package|bulk`를 **명시적 인자로** 받는다(어댑터 표를 재구현하지 않는다). 8종 귀속 표는 granularity와 무관하게 **총 함수로 그대로** 적용되고 — `BULK` unit의 fail/fail도 `PRE_EXISTING`이다 — 대신 다음 한 줄이 얹힌다:

> `granularity == bulk` 이고 어떤 unit이 `PRE_EXISTING`이면, 그 실행의 **`attribution` 원장 차원을 `degraded`로** 표시한다. 그 안에 새 회귀가 숨었는지 구분할 수 없기 때문이다.

즉 **귀속 카테고리(§5.5)와 원장 상태(§5.6)와 verdict(§5.7)는 서로 다른 층**이고, bulk-only의 모호성은 카테고리 층이 아니라 원장 층에서 표현된다. 이렇게 하면 AC11의 *"8종 전부"* 가 granularity와 무관하게 참이 되고, §5.9의 bulk 표와 이 표가 서로 다른 답을 주는 모순이 사라진다.

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
- floor:gap          — closed   — 부팅 미수행(웹 표면 없음); 대상 spec의 AC4는 정책이라 런타임 확인 불가
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

**우선순위 (동시 성립 시 — 표의 행은 배타가 아니다).** 예컨대 확증된 `NEW_REGRESSION`과 `SILENT_DROP`이 한 실행에서 같이 나올 수 있다. 총 순서를 못 박는다:

```
확증 제품결함(FAIL, terminal)  >  NEEDS_RESOLUTION  >  SKIP_WITH_EVIDENCE  >  PASS
```

- **확증 제품결함 = `NEW_REGRESSION`(재실행 확증) · `NEW_TEST_RED` · `forced_downgrade: yes`.** 이것은 **terminal**이며 어떤 degrade 사유로도 downgrade되지 않는다. `SILENT_DROP`이나 floor degraded가 같이 성립해도 verdict는 `FAIL`이고, degrade 사실은 원장의 `attribution`/`gap` 차원과 보고서에 **함께** 기록된다(삼켜지지 않는다).
- **그 외의 FAIL 사유(부팅 실패 등)와 `NEEDS_RESOLUTION`이 동시면 `NEEDS_RESOLUTION`이 이긴다** — 기존 `runtime-verifier.md:141`의 선례(*"if both FAIL and NEEDS_RESOLUTION match, choose NEEDS_RESOLUTION"* + *"Product-bug FAIL is terminal"*)를 그대로 승계한다.
- 나머지는 표대로. **어느 방향으로도 degrade 사유가 PASS를 만들지 못하고, degrade 사유가 확증 결함을 지우지도 못한다.**

**`attribution degraded → PASS 불가`는 새 규칙이 아니라 기존 불변식의 두 번째 인스턴스다.** 샌드박스 비활성 시 `PASS → SKIP_WITH_EVIDENCE` cap(SKILL.md:641 I-A)과 같은 논리: **구조적 보장이 없으면 인증하지 않는다.**

### 5.8 계획 산문 · 갭 게이트

**계획 산문 필수 필드** (어투는 재량, 필드는 lock):

1. **무엇이 바뀌었나** — 사람 말로 (파일 나열이 아니라 "무엇을 하는 코드가")
2. **어떤 행동에 닿나** — 행동/경로 이름
3. **무엇을 돌리나 + 선택 비율** — `영향 테스트 12개 선택 (레포 전체 47개 중)`
4. **비용 신호** — 기준선 캐시 적중 여부 · 설치 필요 여부 · 대략 시간
5. **무엇을 안 돌리나** — 미선택분 · 자동화 불가 플로우 · blocked 표면
6. **CI와 다르면 그 차이** (B7)

**분모 M의 출처는 스크립트다 — 모델 자기보고가 아니다.** `compute-test-scope-candidates.sh`에 `--total` 모드를 추가해 레포 전체 테스트 파일 수를 emit한다(후보 산출과 같은 `TESTRE` 정규식을 재사용하되 diff가 아니라 전 트리를 스캔). 분모가 모델 주장이면 과선택이 심해질수록 분모도 같이 부풀려 비율이 정상으로 보이는 경로가 열린다 — 방어 장치가 방어 대상에 의해 조작되면 방어가 아니다. 분자(선택 수)는 모델 소유가 맞다: 그것이 판정 결과 자체이므로.

**선택 비율이 과선택 방어 장치다.** 과선택이 실전에서 수렴하면 그 줄이 매번 `47개 중 47개`로 찍혀 안 보일 수가 없다 — 실패 양식이 스스로를 고발한다. 결정론적 상한(최대 N)은 두지 않는다: 그건 LD7의 천장이고, 사용자가 redirect할 수 있는 갭 게이트가 이미 escape hatch다.

**갭 게이트 발화 조건 (B3):**

- 위 5번(안 돌리는 것)이 **비어 있으면 발화하지 않는다** — 한 줄 계획 출력 후 zero-click.
- 비어 있지 않으면 `AskUserQuestion` 1회: 생략 목록을 보여주고 `그대로 진행` / `범위 넓혀서 다시 계획` / `중단`.
- 기존 Decision 2(`requires_decision` 있을 때만 발화)와 **동형**이다. 새 상호작용 패턴이 아니다.

질문 빈도가 **생략의 양에 비례**하므로, 질문이 뜰 때는 반드시 정보가 있다. 이것이 approval fatigue 문헌에 대한 구조적 응답이다.

### 5.9 러너 지원 행렬 · degrade 정밀화

**러너 어댑터 계약.** `run-test-selection.sh`의 `<runner>` 인자는 **닫힌 식별자 집합**에서만 온다. 각 식별자는 아래 5개 필드를 갖는 어댑터 하나에 대응하며, 어댑터는 스크립트 내부의 `case` 절이다(별도 플러그인 메커니즘 없음 — 확장은 case 절 추가).

| 식별자 | 감지 조건 | 명령 구성 | 파일 인자 | 아티팩트 억제 | 입도 |
|---|---|---|---|---|---|
| `pytest` | `pytest.ini`\|`pyproject.toml`\[tool.pytest\]\|`tests/` + pytest 설치 | `pytest <files>` | 경로 그대로 | `-p no:cacheprovider` + `PYTHONDONTWRITEBYTECODE=1` | 파일 |
| `unittest` | `pyproject.toml` 무-pytest + `test_*.py` 존재 | `python -m unittest <dotted>` | **경로→dotted 변환** (`a/b/test_c.py` → `a.b.test_c`; 각 디렉토리에 `__init__.py` 없으면 `discover -s <dir> -p <basename>`로 폴백) | `PYTHONDONTWRITEBYTECODE=1` | 파일 |
| `shell` | 실행 비트가 선 `tests/*.sh` | `bash <file>` (파일당 1회) | 경로 그대로 | 해당 없음 | 파일 |
| `jest` \| `vitest` | `package.json` devDeps에 해당 패키지 | `npx <runner> --run <files>` | 경로 그대로 | `--cache=false` (jest) | 파일 |
| `go` | `go.mod` | `go test <pkgs>` | **파일→패키지 디렉토리로 축약** | `GOCACHE` 공유 캐시 밖 지정 안 함 | 패키지 |
| `cargo` | `Cargo.toml` | `cargo test` | **무시** | `CARGO_TARGET_DIR` 공유 | bulk |
| `make` | `Makefile`에 `test:` | `make test` | **무시** | 해당 없음 | bulk |
| `npm-script` | `package.json` `"test"` 이며 위 jest/vitest 미해당 | `npm test` | **무시** | 해당 없음 | bulk |

**미지원 러너 처리.** 위 8개 중 어느 것도 감지되지 않으면 `run-test-selection.sh`는 **exit 3**(실행 불가)을 내고 그 표면은 미실행으로 기록된다. **임의 명령을 추측해 실행하지 않는다** — 추측한 명령이 배포·마이그레이션 같은 부작용을 낼 수 있다.

**표의 행 순서는 배제 우선순위가 아니라 *같은 파일 패턴을 두 어댑터가 주장할 때*의 충돌 해소 순서다** (§5.4의 소유권 표 참조). 감지된 어댑터는 **모두** 반환되고 **모두** 실행된다 — 폴리글랏 레포에서 한 러너만 골라 나머지를 버리는 것은 라운드 3에서 block으로 잡힌 누락 방향 실패다.

**감지의 실행 지점 — `run-test-selection.sh detect` (§5.4).** 감지 지식은 이 스크립트가 **단독 소유**하되, 오케스트레이터가 **R1a(HEAD 트리)와 R4②(기준선 워크트리) 양쪽에서** `detect`를 호출해 어댑터 집합을 얻는다. 그 값이 R2 계획 산문의 러너 이름들, R4·R5b의 `<runner>` 인자, `diff-test-results.py --granularity`로 스레드된다. 오케스트레이터가 이 표를 재구현하는 경로는 **없다** — 라운드 2 Finding B가 지적한 "CLI 인자 vs 내부 감지" 순환을 서브커맨드 분리로 끊었다.

**`detect-runtime.sh`와의 관계 — 겹치지 않는 두 축.** 기존 매니페스트의 `test_runners: [npm|pytest|cargo|go|make]`는 이 8개 집합과 **일치하지 않는다**(`unittest`·`shell`·`jest`/`vitest` 분리가 없다). 해소는 **역할 분리**다:

| | 무엇을 정하나 | 소유 |
|---|---|---|
| `detect-runtime.sh` 매니페스트 | 상황별 층의 **부팅 표면**(`runnable_surfaces`·`approved_surfaces`) | 기존 계약, 바이트 무변경 (AC21) |
| `run-test-selection.sh detect` | floor의 **테스트 러너 식별**(`runner`/`granularity`/`setup_cmd`) | 이 설계의 신규 |

매니페스트의 `test_runners` 필드는 **이 설계의 실행 경로에서 소비되지 않는다** — 부팅 표면 목록만 쓴다. 두 집합이 다른 것은 결함이 아니라 두 축이 다르기 때문이며(§5.3의 용어 경계 참조), 이 사실을 계획 산문에 노출할 필요는 없다. 다만 매니페스트가 **스코프 보조 입력이 아니라는 것**은 §5.3에 못박혀 있다.

**bulk-only는 확실성이 아니라 입도만 떨어뜨린다.** 아래는 §5.5의 귀속 표를 **대체하지 않는다** — 같은 표를 `granularity: bulk`에서 읽은 결과이고, 마지막 행에서만 §5.6 원장 상태가 갈린다(§5.5의 granularity 규칙):

| `BULK` 기준선 | `BULK` HEAD | §5.5 귀속 | 원장 `attribution` | verdict 영향 |
|---|---|---|---|---|
| pass | pass | `STILL_GREEN` | `closed` | **통과 확정** |
| pass | fail | `NEW_REGRESSION` | `closed` | **새 회귀 확정** (unit 분해 불필요) |
| fail | pass | `FIXED` | `closed` | 확정 |
| **fail** | **fail** | `PRE_EXISTING` | **`degraded`** | **`SKIP_WITH_EVIDENCE`** — 유일한 모호 지점 |

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
| 러너 부재 (exit 3) — **영향분을 못 돌림** | `verification: degraded` → **PASS 불가** | `> [quality-gates] 영향 테스트를 돌릴 러너가 없습니다 (<사유>) — floor 미충족, 인증 없음` |
| 러너 부재 (exit 3) — **영향분과 무관한 표면** | `gap: closed`에 열거, PASS 가능 | `> [quality-gates] runner <x> 부재 — 이 표면 미실행(영향분 아님)` |
| bulk-only 러너 양쪽 red | `attribution: degraded` → SKIP_WITH_EVIDENCE | §5.9의 정직한 문장 |
| 캐시 파일 손상/파싱 실패 | 미적중으로 취급, 재실행 | `> [quality-gates] baseline 캐시 손상 — 재계산` |
| 영향분 0개 | `SKIP_WITH_EVIDENCE` + gap 기록 | `> [quality-gates] 영향분에 해당하는 기존 테스트 없음 — 실행 없음, 인증 없음` |
| `check_qa_ledger.py` 실패 | verdict를 PASS로 올리지 않음 | 게이트의 stderr verbatim |

**모든 degrade가 PASS를 막는 것은 아니다 — 판별 기준은 "영향분인가"다** (라운드 2 codex Finding). 라운드 1 초안은 *"어느 floor 차원이 degraded면 PASS 불가"*(§5.7)와 *"러너 부재는 PASS를 막지 않는다"* 를 나란히 써서 **자기모순**이었다. 정정된 단일 규칙:

| 못 확인한 것 | 원장 | PASS |
|---|---|---|
| **영향분**을 못 돌림 (러너 부재·baseline 불가·귀속 불가) | `verification` 또는 `attribution`이 **`degraded`** | **불가** |
| **영향분과 무관한** 표면을 안 돌림 (다른 러너 부재, 자동화 불가 플로우, 미선택분) | `gap`에 **열거하고 `closed`** | 가능 |

핵심은 **`gap: closed`와 `verification: degraded`가 다른 뜻**이라는 것이다 — `gap`은 *"못 확인한 것을 빠짐없이 열거했다"* 이므로 열거가 곧 닫힘이고, `degraded`는 *"확인하기로 한 것을 못 확인했다"* 이므로 인증 불가다. LD3의 floor가 "영향분을 실제로 실행"이므로, floor에 해당하는 것을 못 돌린 순간 인증 근거가 없다.

### 5.11 GC 충돌 — 신규 위험이 드러낸 기존 결함

```python
qg-gc.py:27   SESSION_PATTERN = re.compile(r"^[A-Za-z0-9_-]{8,}$")
```

`baseline-cache`(14자)가 매치한다 → 24시간 TTL로 세션 폴더인 줄 알고 삭제된다.

**같은 패턴에 기존 `worktrees`(9자)도 매치한다.** 그 디렉토리엔 직접 파일이 없으므로 `_folder_mtime_ns`(`:51-55`)가 디렉토리 자신의 mtime으로 떨어지고, 24시간 넘게 새 worktree가 추가되지 않았다면 `rename` → `rmtree`된다(`:89-94`) — 안에 살아있는 worktree가 있어도. **코드 경로상의 결함이며 실행 재현(T49)을 수정보다 먼저 쓴다.**

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
- **AC3** — `scripts/check-allowed-tools-order.sh`가 신규 스크립트 5종을 포함한 순서로 갱신되고 통과한다.

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

- **AC29** — `plugin.json` version이 **major bump**(major digit == 3)되고 `CHANGELOG.md`에 `## [3.0.0] — <날짜>` 항목이 Added/Changed/Removed로 기록된다. `<날짜>`는 **그 CHANGELOG 항목을 커밋하는 날의 UTC `YYYY-MM-DD`** 이다(리터럴 placeholder 금지 — 검증은 `^## \[3\.0\.0\] — [0-9]{4}-[0-9]{2}-[0-9]{2}$`).
- **AC30** — `README.md`의 "Principles Instantiated"에 LD3/LD5/LD7 instantiation 줄이 추가되고, 컴포넌트 트리에 신규 스크립트 **5종**이 등재된다.

### 6.1 리뷰 라운드 1에서 추가된 AC (AC31–AC37)

> **번호를 재사용하지 않고 뒤에 붙인다.** 라운드 1에서 발견된 결함 중 하나가 *"§6 중간에 AC를 삽입하면서 §3의 역참조 두 개가 +4 오프셋으로 stale해진 것"* 이었다. 같은 클래스를 재생산하지 않기 위해 신규 AC는 항상 append-only다.

- **AC31** (호출 주체 — §5.1 불변식 ②) — `SKILL.md`의 `run-test-selection.sh` 호출이 `runtime-verifier` dispatch **블록 밖**에 있고, *"이 호출 결과가 authoritative"* 취지의 문장이 그 호출 근처에 존재한다. verifier 페르소나에는 *"테스트 결과 self-report는 판정에 쓰이지 않는다"* 가 명시된다.
- **AC32** (캐시 조회) — `baseline-cache.sh get`이 **적중분만** emit한다(미적중 파일은 무출력). 헤더 마커·`merge_base` 줄 불일치·파싱 실패 시 **exit 4 + 전량 미적중**이며, 부분 파싱된 일부를 적중으로 내지 않는다.
- **AC33** (캐시 기록) — `baseline-cache.sh put`이 임시 파일에 전량을 쓴 뒤 `mv` rename한다. 중단 시 부분 기록된 캐시 파일이 남지 않는다.
- **AC34** (러너 어댑터) — `run-test-selection.sh`가 받는 `<runner>`가 §5.9의 **8개 닫힌 집합**에 속한다. 어느 어댑터도 감지되지 않으면 **exit 3**이며, 감지되지 않은 러너에 대해 명령을 추측해 실행하는 코드 경로가 없다.
- **AC35** (verdict 우선순위) — 확증 제품결함과 `SILENT_DROP`(또는 floor degraded)이 **동시 성립**하는 입력에서 verdict가 `FAIL`이고, degrade 사실이 원장/보고서에 **함께** 기록된다.
- **AC36** (`error` 매핑) — `error` 상태는 `fail`로 접히고 귀속 라벨에 `(error)`가 병기된다. 스크립트 **exit 3**은 `error`가 아니라 미실행 축(`BASELINE_UNRUNNABLE`/`SILENT_DROP`)으로 간다.
- **AC37** (분모 M) — 계획 산문의 분모 M이 `compute-test-scope-candidates.sh --total`의 출력이며, 모델이 산출한 값이 아니다.

### 6.2 리뷰 라운드 2에서 추가된 AC (AC38–AC44)

- **AC38** (감지 분리) — `run-test-selection.sh detect <worktree>`가 `runner`/`granularity`/`setup_cmd` 3줄을 emit한다. `SKILL.md`가 R1a에서 이를 호출하고 그 값을 R2 산문·R4·R5b·`--granularity`로 스레드하며, **오케스트레이터 쪽에 어댑터 감지 표의 재구현이 없다**.
- **AC39** (총 함수) — `run-test-selection.sh run`이 **입력 unit 하나당 정확히 한 행**을 emit한다. exit 3에서도 모든 unit에 `unrun` 행이 나온다. 행이 빠진 입력에 대해 `diff-test-results.py`는 `SILENT_DROP`으로 fail-closed한다.
- **AC40** (상태 5종) — 상태값 집합이 `pass|fail|error|unrun|absent` 5종이며, `absent`는 워크트리 부재, `unrun`은 미판정이다. `unrun`은 캐시에 기록되지 않고 `absent`는 기록된다.
- **AC41** (setup 동등성) — 테스트 러너용 설치는 어댑터의 `setup_cmd`이며 **기준선·HEAD 양측이 같은 명령**으로 실행된다. `runtime-verifier` 페르소나에 *"테스트 러너용 deps 설치는 하지 않는다"* 가 명시된다. HEAD-only 추가 setup은 evidence-log와 `gap`에 기록된다.
- **AC42** (bulk 키 안전성) — `BULK` unit은 `granularity: bulk` 어댑터에서만 생성된다. `granularity ∈ {file, package}`에서는 bulk-green이 unit별 `pass` 행으로 분해되어 캐시되고 `BULK` 키가 생기지 않는다.
- **AC43** (granularity → 원장) — `diff-test-results.py`가 `--granularity`를 인자로 받고, `bulk`에서 `PRE_EXISTING`이 나오면 `attribution` 원장 차원을 `degraded`로 표시한다. 귀속 카테고리 자체는 8종에서 벗어나지 않는다.
- **AC44** (영향분 러너 부재) — 영향분을 돌릴 러너가 없으면 `verification: degraded` → **PASS 불가**. 영향분과 무관한 표면의 러너 부재는 `gap`에 열거되어 `closed`이며 PASS를 막지 않는다.

### 6.3 리뷰 라운드 3에서 추가된 AC (AC45–AC51)

- **AC45** (다중 어댑터 — block 해소) — `detect`가 어댑터를 **집합**으로 반환한다(0개 이상). `test_*.py`와 실행비트 `tests/*.sh`가 공존하는 픽스처에서 **2개 이상**이 반환되고, 둘 다 실행된다. 첫 어댑터만 반환·실행하는 코드 경로가 없다.
- **AC46** (unit 배정) — R1b가 고른 각 unit이 파일 패턴으로 정확히 한 어댑터에 배정된다. 어느 어댑터도 주장하지 않는 unit은 `unclaimed`로 `gap` 차원에 **열거**된다(조용히 누락 금지).
- **AC47** (양측 재감지) — `detect`가 HEAD 트리와 기준선 워크트리 **양쪽에서** 실행된다. 두 어댑터 집합이 다르면 한쪽에만 있는 어댑터의 unit은 반대편에서 `unrun`이 되어 귀속이 `degraded`이며, 그 사실이 계획 산문과 `gap`에 나타난다. HEAD 감지 결과를 기준선에 재사용하는 경로가 없다.
- **AC48** (대조기 계약) — `diff-test-results.py`가 §5.5의 `usage:` 블록대로 `--expected`/`--baseline`/`--head`/`--granularity`/`--runner`를 받는다. `SILENT_DROP`은 **`--expected` 기준**으로 계산되며(두 산출물의 상호 대조가 아님), 중복 unit 행은 **exit 4**다.
- **AC49** (bulk 커버리지 공시) — `granularity: bulk` 어댑터가 실행되면 `verification` evidence·계획 산문·최종 보고서에 `커버리지 미보장(러너가 선택을 무시함)` 취지의 문구가 **항상** 나타난다. verdict는 막지 않는다.
- **AC50** (캐시 공유 경계) — 다운로드 캐시(`GOMODCACHE`·`CARGO_HOME/registry`·npm `_cacache`·wheel 캐시)는 공유하고, **빌드 산출물 디렉토리(`CARGO_TARGET_DIR`·`target/`·`node_modules/`·`.venv/`)를 두 트리가 공유하는 코드 경로가 없다.**
- **AC51** (스텝 락 이전) — 기존 SKILL.md의 락된 스텝 라벨 5종(`Step R0`/`Step R-init`/`Step R2`/`Step R3`/`Step R6`)이 `tests/harness/test_skill_orchestration_behavior.sh`에서 새 라벨로 이전되고, §5.2 매핑표의 기존 로직 8종이 모두 새 자리에 존재한다(`detect-runtime.sh` 호출 · `approved_surfaces`/`block_policy` zero-click 폴백 · `create-sandbox` 3줄 파싱 · `test-scope-validator` dispatch · spec AC 수집 · `runtime-verifier` dispatch · `mutation-guard` · publish sentinel).

---

## 7. Files to Modify

### 신규 (5 + 테스트)

| 경로 | 무엇 |
|---|---|
| `scripts/resolve-baseline.sh` | base/base_ref/merge_base/degraded 공유 resolution (OQ5) |
| `scripts/run-test-selection.sh` | `detect`(러너·입도·setup 감지) + `run`(결정론 실행, unit당 1행 총 함수). 러너 어댑터 8종 단독 소유 |
| `scripts/baseline-cache.sh` | 기준선 결과 캐시 get/put — 부분적중·원자적 쓰기·손상 처리 소유 |
| `scripts/diff-test-results.py` | 기준선×HEAD 짝짓기 → 귀속 8종 + SILENT_DROP |
| `scripts/check_qa_ledger.py` | floor 5차원 구조 게이트 (Law 1) |

### 수정 (7)

| 경로 | 무엇 |
|---|---|
| `skills/quality-pipeline/SKILL.md` | Runtime 섹션 전면 개정 · `allowed-tools` 5종 추가 · AC1/AC2 락 이전 · R5a/R5b 분리(AC31) |
| `agents/runtime-verifier.md` | 페르소나 개정 — "전체 앱 부팅+AC 단언" → "setup·부팅·플로우만". **테스트 실행 결과 self-report가 판정에 쓰이지 않음을 명시**(AC31). 매니페스트 verbatim 소비 유지, 스코프 판정은 여전히 비-책임 |
| `scripts/compute-test-scope-candidates.sh` | `main` 하드코딩 → `resolve-baseline.sh` 소비 (C2 수정) · `--total` 모드 추가 (AC37) |
| `scripts/check-review-scope.sh` | baseline resolution을 `resolve-baseline.sh`로 위임 (출력 계약 불변 — AC6) |
| `scripts/qg-worktree.sh` | `create-baseline` case 절 추가 (기존 절 무변경 — AC22) |
| `scripts/qg-gc.py` | 내용 기반 세션 식별 (§5.11) |
| `scripts/check-allowed-tools-order.sh` | 신규 5종 순서 등재 (C5) |

### 구현 의존 순서 (라운드 3 Finding 9 — `writing-plans`가 12파일 단일 diff로 뭉치지 않도록)

신규 5종은 인과적으로 결합돼 있어 설계 문서를 쪼갤 대상은 아니지만, **구현 순서는 강제된다**:

```
1) resolve-baseline.sh          ← 독립. 소비자(check-review-scope · compute-test-scope)와 함께
2) run-test-selection.sh        ← 독립(어댑터 8종 + detect/run). 5-상태값 계약을 여기서 확정
3) baseline-cache.sh            ← 2의 상태값 계약에 의존
4) diff-test-results.py         ← 2·3 둘 다에 의존
5) check_qa_ledger.py           ← 독립(원장 형식만). 1~4와 병행 가능
6) qg-worktree.sh create-baseline · qg-gc.py 수정   ← 독립. 1~5와 병행 가능
7) SKILL.md · runtime-verifier.md · 락 이전         ← 전부에 의존. 마지막
```

1·2·5·6은 병행 가능하고 3→4→7이 직렬이다. 각 단계가 자기 테스트와 함께 닫히는 단위이므로 최소 6개 task로 분해된다.

### 문서 (3)

`plugin.json` (major bump) · `CHANGELOG.md` · `README.md` (컴포넌트 트리 + Principles Instantiated)

### 테스트 (신규 파일 예상)

`tests/test_resolve_baseline.sh` · `tests/test_run_test_selection.sh` · `tests/test_runner_adapters.sh` · `tests/test_baseline_cache.sh` · `tests/test_diff_test_results.py` · `tests/test_qa_ledger.sh` · `tests/test_runtime_verdict_precedence.sh` · `tests/test_qg_gc.py`(기존 확장) · `tests/harness/test_skill_orchestration_behavior.sh`(락 이전 + AC31 호출-주체 검사)

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
| T21 | **재실행 호출 횟수 == 1** — `NEW_REGRESSION` 후보 1건에 대해 `run-test-selection.sh` 호출 카운터가 정확히 1 증가. **stub 러너는 3회째 `pass`로 전환**한다(항상 `fail`이면 버그 루프가 종료하지 않아 RED가 아니라 타임아웃이 된다 — 이빨이 시계에 의존하면 안 됨) | AC12 |
| T22 | `SKILL.md`에서 `run-test-selection.sh` 호출이 verifier dispatch 블록 밖 + authoritative 문장 존재 + verifier 페르소나에 self-report 배제 문구 | AC31 |
| T23 | `baseline-cache.sh get` — 전량 적중 / 부분 적중(적중분만 출력) / 헤더 손상(exit 4 + 무출력) / `merge_base` 불일치(무출력) 4 픽스처 | AC32 |
| T24 | `baseline-cache.sh put` — 임시파일+rename 사용 확인, 중단 시 부분 파일 부재 | AC33 |
| T25 | 러너 어댑터 — 8개 각각 감지 픽스처 + 미감지 레포에서 exit 3 + **추측 명령 실행 0회** | AC34 |
| T26 | 확증 회귀 + `SILENT_DROP` 동시 입력 → verdict `FAIL` 이며 degrade가 원장에 함께 기록 | AC35 |
| T27 | `error` 입력 → `fail`로 접힘 + 라벨 `(error)` 병기 / exit 3 입력 → 미실행 축 | AC36 |
| T28 | 계획 산문 6필드 존재 + 선택 비율이 `N개 선택 (전체 M개 중)` 포맷 | AC19 |
| T29 | 분모 M이 `compute-test-scope-candidates.sh --total` 출력과 일치 | AC37 |
| T30 | `/qg runtime` 단일게이트 경로 — R-init zero-click 폴백 포함 보존 | AC23 |
| T31 | **영향분 0개 → `SKIP_WITH_EVIDENCE`** + gap 차원에 "기존 테스트 없음" 기록 + verdict ≠ PASS | AC15(빈 스코프 분기) |
| T32 | `check-allowed-tools-order.sh` 통과 (신규 5종 등재) | AC3 |
| T33 | `README.md` — Principles Instantiated 3줄 + 컴포넌트 트리 신규 5종 등재 | AC30 |
| T34 | `detect` 서브커맨드 — 8 어댑터 각각 3줄 emit · 미감지 `runner: none` · **SKILL 쪽 감지-표 재구현 0회**(어댑터 표의 감지 조건 문자열이 SKILL.md에 없음) | AC38 |
| T35 | `run`이 입력 unit 수 == 출력 행 수 (정상·exit 3·일부 absent 3 픽스처) + 행 누락 입력에서 `SILENT_DROP` | AC39 |
| T36 | 상태 5종 각각 1 픽스처 + `unrun`은 `put` 후 캐시에 부재 / `absent`는 존재 | AC40 |
| T37 | `setup_cmd`가 기준선·HEAD 호출에서 **동일 문자열**로 실행됨(호출 로그 대조) + verifier 페르소나에 deps-설치 배제 문구 | AC41 |
| T38 | `granularity=file`에서 bulk-green → unit별 `pass` 캐시 · `BULK` 키 부재 / `granularity=bulk`에서만 `BULK` 키 생성 | AC42 |
| T39 | `diff-test-results.py --granularity bulk` + fail/fail → 귀속 `PRE_EXISTING` **이면서** `attribution: degraded` | AC43 |
| T40 | 영향분 러너 부재 → verdict ≠ PASS + `verification: degraded` / 무관 표면 러너 부재 → PASS 가능 + `gap: closed` (두 픽스처) | AC44 |
| T41 | **아티팩트 유출** — `make`/`npm-script` 스텁 레포에서 `run` 실행 후 비-ignored 신규 파일이 생기는지 실측 (§11 ⑨의 측정 경로) | §11 ⑨ |
| T42 | `detect` 다중 반환 — `test_*.py` + 실행비트 `tests/*.sh` 공존 픽스처에서 어댑터 **2개** 반환 · 둘 다 `run` 호출됨 (호출 로그) | AC45 |
| T43 | 어느 패턴에도 안 걸리는 unit → `unclaimed`로 `gap`에 열거 (조용한 누락 0) | AC46 |
| T44 | 기준선 트리에서 `detect` 재실행 · HEAD와 집합이 다른 픽스처(한쪽만 pytest)에서 해당 unit 귀속 `degraded` | AC47 |
| T45 | `diff-test-results.py` — `--expected`에 있으나 양측 산출물에 행 없음 → `SILENT_DROP` / 중복 unit 행 → exit 4 | AC48 |
| T46 | bulk 어댑터 실행 → `verification` evidence·계획 산문에 커버리지 미보장 문구 존재 | AC49 |
| T47 | 기준선·HEAD 실행의 `CARGO_TARGET_DIR`/`node_modules`/`.venv` 경로가 서로 다름 (env·경로 대조) | AC50 |
| T48 | 락 라벨 5종이 새 라벨로 이전 + §5.2 매핑표의 기존 로직 8종이 새 SKILL.md에 모두 존재 (grep 8건) | AC51 |
| T49 | `qg-gc.py` **실패 재현** — TTL 초과 + 직접 파일 없는 `worktrees`가 수정 전 코드에서 삭제됨을 먼저 증명 (§5.11이 약속한 재현) | §5.11 |

**AC ↔ 검증 완전성.** **AC1–AC51 전부**가 위 T 또는 §8.3의 V에 대응한다. 자동 테스트가 없는 것은 **AC20 하나**이며 `V4`(대화형 게이트 미발화)가 담당한다 — `AskUserQuestion` 발화 여부는 대화형이라 자동화하지 않는다. 이 매핑 자체를 구현 시 표로 유지하고, **AC 추가 시 대응 T/V 없이 머지하지 않는다.** (라운드 3에서 이 선언문이 AC38–AC44를 반영하지 않은 채 stale했다 — 선언문도 갱신 대상이다.)

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
| **M10** | `run-test-selection.sh`가 exit 3과 테스트 실패를 뭉침 | T7·T27 |
| **M11** | 영향분 0개일 때 `SKIP_WITH_EVIDENCE` 대신 `PASS`를 냄 | T31 — **LD5 백스톱의 "누락 방향" 절반을 지키는 유일한 mutation** |
| **M12** | `run-test-selection.sh` 호출을 verifier dispatch 블록 **안**으로 옮김 | T22 — 불변식 ② 무력화. 결과값이 같아 보이므로 **위치**를 검사해야 잡힌다 |
| **M13** | `baseline-cache.sh get`이 손상 파일을 부분 파싱해 일부를 적중으로 냄 | T23 |
| **M14** | 미감지 러너에서 exit 3 대신 `npm test`를 추측 실행 | T25 |
| **M15** | precedence를 뒤집어 `SILENT_DROP`이 확증 회귀를 `SKIP`으로 downgrade | T26 |
| **M16** | `run`이 실패한 unit의 행을 **생략**(총 함수 위반) | T35 — 결과 배열이 짧아질 뿐 값은 정상이라 **개수 대조**로만 잡힌다 |
| **M17** | `setup_cmd`를 HEAD 측에서만 다른 명령으로 바꿈 | T37 — 양측 결과가 그럴듯하게 나오므로 **호출 문자열 대조**로만 잡힌다 |
| **M18** | `granularity=file`에서도 bulk-green을 `BULK` 한 행으로 캐시 | T38 — 캐시 적중률이 오히려 올라가 성능만 보면 개선처럼 보인다 |
| **M19** | 영향분 러너 부재에서 `gap: closed`로 처리해 PASS 허용 | T40 — 라운드 2에서 실제로 문서에 있던 모순 그 자체 |
| **M20** | `detect`가 우선순위 1위 어댑터만 반환 (라운드 3 block 재도입) | T42 — **이 레포에서 실측된 실패**(shell 130개 누락). 단일 어댑터 픽스처만 쓰면 GREEN이므로 **폴리글랏 픽스처**가 필수 |
| **M21** | 기준선에서 HEAD의 어댑터 집합을 재사용 | T44 — 동종 레포에서는 결과가 같아 보이므로 **인프라 변경 픽스처**로만 잡힌다 |
| **M22** | `SILENT_DROP`을 `--expected` 대신 두 산출물 상호 대조로 계산 | T45 — 대칭 누락 픽스처(양측이 같은 unit을 빠뜨림)로만 잡힌다 |
| **M23** | `CARGO_TARGET_DIR`를 양측 공유로 변경 | T47 — 속도만 보면 개선처럼 보이고 결과도 대개 같다 |

> **M6·M8·M12가 이 계획의 취약 지점이다.** 셋 다 "결과가 같아 보이는" mutation이라 결과값만 보는 assert로는 GREEN이 나온다 — M6은 **호출 카운터**(+ 유한 종료 stub), M8은 **body-unique + 섹션 윈도우**, M12는 **호출 위치**가 필요하다. 구현 시 이 셋을 **먼저** 쓴다.
>
> **M11은 방향이 반대라 특히 주의한다.** "PASS를 SKIP으로 바꾸는" mutation은 안전 방향이라 놓쳐도 덜 아프지만, M11이 잡는 것은 그 **역방향**(SKIP이어야 할 것이 PASS가 됨)이다. 테스트가 `verdict != PASS`만 assert하면 verdict가 `FAIL`로 바뀌어도 GREEN이므로, `verdict == SKIP_WITH_EVIDENCE` **정확 일치**로 쓴다.

### 8.3 수동 검증

| id | 시나리오 | 왜 수동인가 |
|---|---|---|
| **V1** | devbrew 자신에 `/qg runtime` self-dogfood — **실측상 `unittest`(50개) + `shell`(130개) 두 어댑터가 감지되어 둘 다 실행되는지**, 그리고 어느 쪽도 조용히 누락되지 않는지 | 실제 폴리글랏 레포의 전체 파이프라인 동작은 픽스처로 근사만 가능(T42가 감지·실행 계약은 이미 커버) |
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
8. **LD4의 "쉽게"는 기계 검증 밖이다.** Goal 5의 사람 판정 층(V8)은 통과 기준이 사람이다. 어휘 금지 목록·최대 길이 같은 기계 임계는 LD7이 경계한 천장이 되므로 세우지 않았다 — 대신 필드 존재/포맷만 기계로 잡는다(AC19). **"필드는 다 있는데 읽히지 않는 계획"은 자동으로 잡히지 않는다.**
9. **아티팩트 억제가 불가능한 러너가 있다.** `make`·`npm-script`는 내부 명령을 우리가 모르므로 `.pytest_cache` 같은 산출물을 억제할 수단이 없다. 대상 레포의 `.gitignore`가 그것을 덮지 않으면 mutation-guard가 `disallowed_new_files`로 잡아 **거짓 FAIL**을 낸다.
   **측정 경로 정정 (라운드 2 Finding C).** 초안은 *"첫 dogfood(V1)에서 실측"* 이라 썼지만 **V1은 이것을 측정할 수 없다** — V1은 devbrew 자신을 대상으로 하고 devbrew에는 Makefile 기반 테스트도 npm-script 테스트도 없다. 측정은 **T41**(픽스처 기반: `Makefile`/`package.json` 스텁 레포에서 `run` 실행 후 비-ignored 신규 파일 발생 여부)이 담당한다. 실측 결과가 "흔함"이면 guard 예외 목록이 아니라 **어댑터별 작업 디렉토리 격리**로 푼다 — guard를 느슨하게 하는 방향은 금지다(Law 2 표면).
10. **baseline 캐시는 GC되지 않는다.** merge_base마다 파일이 하나씩 쌓이고 정리는 `/cancel-qg --all`에 위임했다. 장수 브랜치·잦은 rebase 환경에서 파일 수가 늘어나는데, 각 파일이 수 KB라 실질 부담은 아니지만 **자동 정리 경로가 없다**는 사실은 남는다.
11. **러너 어댑터 8종은 초기 집합이며 커버리지 주장이 아니다.** Java/Gradle·Ruby/RSpec·PHP/PHPUnit·.NET 등은 감지 0개로 떨어져 그 레포에서는 이 게이트가 floor를 제공하지 못한다. 확장은 case 절 추가지만, **미지원 레포에서 이 게이트가 무엇을 못 하는지가 사용자에게 보여야** 한다(§5.10의 loud 경로).
12. **bulk 어댑터는 커버리지를 보장하지 못한다.** `cargo test`가 `--workspace` 없이 sibling crate를 건너뛰는 식의 함정이 발동하면 영향분이 조용히 미실행되는데 exit 0 + green이라 신호가 없다. 명령 내부를 통제하지 않으므로 **검증 불가**이며, 대응은 봉쇄가 아니라 **공시**다(AC49). 즉 cargo/make/npm-script 레포에서 이 게이트의 주장은 "영향분을 확인했다"가 아니라 "러너 전체를 돌렸다"로 약해진다.
13. **verifier의 부팅용 setup이 만드는 환경 비대칭은 기계로 안 잡힌다.** AC41은 `setup_cmd` 채널만 결정론적으로 맞춘다. R5a에서 verifier가 앱 부팅을 위해 설치한 것이 우연히 테스트 결과에 영향을 주면, 그것은 git-외부 상태라 mutation-guard가 못 보고 `gap` 기재는 verifier 자기보고에 의존한다 — 불변식 ②가 *결과값*에서 없앤 self-report 신뢰가 *실행 환경* 축에는 남아 있다. 완화: R5b는 R5a와 같은 샌드박스에서 돌므로 비대칭이 발생하면 **양측 차등에 나타난다**(기준선에는 그 setup이 없으므로) — 즉 조용한 오귀속이 아니라 시끄러운 불일치로 드러날 가능성이 높다. 그래도 보장은 아니다.

---

## 12. Metadata

| 항목 | 값 |
|---|---|
| 입력 brief | `docs/superpowers/interview/2026-07-26-qg-impact-driven-qa-runtime-interview.md` |
| 대상 플러그인 | `plugins/quality-gates` |
| 버전 영향 | **major — v2.14.x → v3.0.0** (`/qg runtime` 인터페이스 유지, "전체 앱 실행" 동작 제거) |
| 브랜치 | `feature/qg-impact-driven-runtime` |
| 신규/수정/문서 | 신규 5 · 수정 7 · 문서 3 |
| 리뷰 라운드 1 | Claude `spec-reviewer` 8건(block 1·high 4·medium 3) + codex 4건(high 3·medium 1) → combined `needs_revise` → 전량 반영 + 전수 스캔 자체 발견 3건 (AC3·AC20 검증 부재, §5.6 예시의 `AC4` 토큰 충돌) |
| 리뷰 라운드 2 | Claude 4건(high 3·medium 1) + codex 4건(high 4) → combined `needs_revise`, stagnation 없음(반복 이슈 0). **두 리뷰어의 발견이 거의 disjoint** — 라운드 1 수정이 연 새 계약 지점을 서로 다른 각도에서 적발. 핵심: 러너 감지 소유권 순환 · `BULK` 키 식별 · `없음`/`미실행` 생산자 부재 · §5.10↔§5.7 자기모순 · deps setup 비대칭 |
| 리뷰 라운드 3 | Claude 9건(**block 1**·high 4·medium 4) + codex 3건(high 2·medium 1) → combined `needs_revise`. 원장 3개 이슈가 `raised_count == 3`에 도달해 **per-issue stagnation → Human Gate 강제 escalate**(같은 결함 미해결이 아니라 §5.9/§5.4/§5.2 세 영역이 매 라운드 새 계약 표면을 낳은 패턴). 사용자 선택으로 라운드 4 진행. **block = 단일-러너 `detect`가 폴리글랏 레포에서 누락 방향 실패** — 이 레포 실측으로 확인(`.sh` 130 / `.py` 50 → shell 전량 미실행). 다중 어댑터로 해소 |
| 신규 에이전트 | **0** |
| 신규 훅 | **0** |
| 신규 verdict 토큰 | **0** |
| 선행 레퍼런스 (통독) | `gstack/qa/SKILL.md` (1685줄) · `compound-engineering-plugin/skills/ce-test-browser/` (SKILL + references 2) · `oh-my-codex/skills/ultraqa/SKILL.md` + 자매 2 · `ECC/.agents/skills/e2e-testing/` · `ECC/agents/e2e-runner.md` · `gbrain/skills/testing/` · `gbrain/skills/smoke-test/` |
| 다음 단계 | `spec-distill:reviewing-spec` → `superpowers:writing-plans` |
