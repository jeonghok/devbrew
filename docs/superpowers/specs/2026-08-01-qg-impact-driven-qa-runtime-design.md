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
  - [6.4 리뷰 라운드 4에서 추가된 AC (AC52–AC57)](#64-리뷰-라운드-4에서-추가된-ac-ac52ac57)
  - [6.5 `/qg` iter-1 리뷰에서 추가된 AC (AC58–AC59)](#65-qg-iter-1-리뷰에서-추가된-ac-ac58ac59)
  - [6.6 `/qg` iter-2 리뷰에서 추가된 AC (AC60–AC63)](#66-qg-iter-2-리뷰에서-추가된-ac-ac60ac63)
  - [6.7 `/qg` iter-3 정정 (AC64 + AC61–AC63 수정)](#67-qg-iter-3)
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

**더 이상 defer하지 않는 것** (§4 위험 논의 + 리뷰 라운드 1에서 이 문서로 끌어올림): **기준선 deps 전략**(§5.4 — 옵션 ② 기각이 판정 정확성을 직접 결정) · **러너별 지원 등급과 degrade 조건**(§5.9 — verdict를 직접 결정) · **`qg-gc.py` 수정 방식**(§5.11 — denylist는 시간에 fail-open) · **`run-test-selection.sh`의 호출 주체**(§5.1 불변식 ② — LD5 독립성이 여기 걸림) · **러너 어댑터 9종의 닫힌 집합과 미지원 처리**(§5.9 — 추측 실행 금지가 안전 계약) · **baseline 캐시의 부분적중·원자성·손상 처리 소유자**(§5.4 — 반쯤 신뢰한 캐시가 조용히 틀린 귀속을 만든다) · **verdict 동시-성립 우선순위**(§5.7).

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
- **`create-sandbox` / `mutation-guard` 계약 변경** — LD5 "배관은 기존 고정 계약이 기본값". 두 서브커맨드 본문은 바이트 무변경 (AC22, 실측 -0줄).
  `detect-runtime.sh` 는 **여기서 빠진다** — C2 수정이 테스트 러너를 `runnable_surfaces` 에서 분리하며 실제로 55줄을 바꿨다. 원래 AC21 은 이 파일도 바이트 무변경이라 적었고 그 주장이 구현과 어긋난 채 남아 있었다 (`/qg` iter-6 E7 → **AC21′** 참조).
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
          ② 항상(캐시 적중 무관): qg-worktree.sh create-baseline <merge_base> <sid>
             + 그 트리에서 detect 재실행 → baseline_detected (AC60)
             ※ '미적중분이 있을 때만' 이던 옛 조건이 §5.4 의 fail-open 이었다
             (기준선에서 red 였던 유닛은 get 이 적중으로 내주지 않으므로 **언제나**
              미적중분에 포함된다 — 재검증에 별도 스텝이 필요 없다)
             → **기준선 트리에서 detect 재실행** (HEAD 집합 재사용 금지)
             → 어댑터마다 run-test-selection.sh run … (setup_cmd 포함)     [신규]
          ③ baseline-cache.sh put · 워크트리 폐기

R5a     HEAD 측 — verifier 턴 (판단이 필요한 것만)
          기존 create-sandbox (무변경) → runtime-verifier (페르소나 개정)
          **앱 부팅용** setup fix · 상황별 부팅/플로우.
          **테스트 실행도, 테스트 러너용 deps 설치도 여기 없다.**

R5b     HEAD 측 — verifier 턴 *종료 후*, 오케스트레이터가 직접
          qg-worktree.sh create-head <B> → **HEAD 축 전용 일회용 워크트리**
          run-test-selection.sh run <head-tree> <runner> …
          ← 불변식 ②. verifier의 evidence-log 테스트 결과는 advisory,
            이 호출 결과가 authoritative.
          ← setup_cmd를 R4와 **동일하게** 실행 (양측 준비 동등성)
          ← **verifier 샌드박스가 아니다** (§11 ⑬). 양축 모두 오케스트레이터가
            만든 커밋 detached 트리 — 대칭이 구조적이다.

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

**R5b가 R5a *뒤*인 이유 (근거 교체 — 옛 근거는 §11 ⑬을 낳은 바로 그 전제였다).** 앞 판본은 *"deps 설치·`.env` 같은 setup은 verifier의 몫이고, 테스트는 그 setup이 끝난 트리에서 돌아야 한다"* 로 적었다. 그 문장이 R5b를 verifier 샌드박스에 묶어 두 축의 환경을 비대칭으로 만들었고, 그것이 §11 ⑬이다. **이제 R5b는 `create-head`가 봉인 커밋 `B`에 만든 자기 트리에서 돈다** — verifier의 setup이 닿지 않는다.

두 종류의 setup을 구별하지 못한 것이 옛 근거의 오류였다:

- **테스트 러너용 setup** (`uv sync`·`npm ci`·venv) — 어댑터가 선언하고 `run-test-selection.sh`가 **양축에서 동일하게** 실행한다. 이것이 양측 준비 동등성의 실체다.
- **앱 부팅용 setup** (`.env`·DB·외부 서비스) — 판단이 필요해 verifier의 몫이고, **부팅/플로우 층에만** 필요하다. 테스트 러너 표면은 이것을 요구하지 않는다.

**치르는 대가 (숨기지 않는다).** 테스트가 진짜로 부팅 setup을 요구하는 레포에서는 HEAD 축이 pristine 트리에서 실패한다. 그러나 그것은 **손실이 아니라 정직화**다 — 기준선 축(R4)은 원래부터 verifier setup 없는 merge_base 트리였으므로, 예전 배치는 *HEAD에만 `.env`가 있는* 비대칭을 만들어 거짓 `NEW_REGRESSION`(또는 반대 방향의 거짓 `STILL_GREEN`)을 생산했다. 이제 양축이 같은 이유로 함께 실패해 `PRE_EXISTING` 또는 degrade로 라우팅된다 — 조용한 오귀속이 아니라 **판정 불가의 공시**다.

순서 자체는 유지한다. 다만 그 근거는 이제 "setup이 끝나야 해서"가 아니라 **불변식 ②(verifier 턴 안에서 섞지 않는다)와 재시도 계약(재시도는 새 `B`를 만들고 R5b가 그것을 다시 읽어야 한다)** 뿐이다.

**테스트 실행이 남기는 아티팩트 (`.pytest_cache`/`__pycache__`/`.tox` 등)와 mutation-guard의 충돌 — 트리 분리로 닫혔다.** R7의 guard는 `sandbox_dir`만 검사하는데, R5b가 자기 트리(`create-head`)로 옮겨간 뒤로 **게이트가 만드는 테스트 아티팩트는 그 트리에 닿지 않는다.** 예전에는 HEAD 측 테스트가 샌드박스 안에서 돌아, 대상 레포의 `.gitignore`가 아티팩트를 덮지 않으면 `disallowed_new_files`로 잡혀 `forced_downgrade: yes` → **게이트가 자기 부작용에 거짓 FAIL**을 냈다. `make`·`npm-script`는 내부 명령을 우리가 모르므로 억제할 수단조차 없었다(옛 §11 ⑨).

이 해소는 **guard를 느슨하게 하는 방향이 아니다** — 검사 대상에서 게이트 자신을 뺐을 뿐, verifier가 만드는 변경에 대한 guard의 권한은 그대로다(Law 2 표면 무변경). §5.9의 어댑터별 아티팩트 억제 인자(pytest `-p no:cacheprovider`, `PYTHONDONTWRITEBYTECODE=1` 등)는 유지한다 — 일회용 트리라도 깨끗한 편이 낫고, 억제 불가 러너가 더 이상 **거짓 FAIL을 낳지 않는다**는 것이 달라진 점이다.

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

**집행자 없음 — §11 ⑭에 등재됨.** 위 규칙은 산문뿐이고 이를 강제하는 코드가 없다. 이 자인이 어느 갭 목록에도 없어 2라운드 연속 지적됐으므로(U2) §11의 갭 원장 ⑭로 등재했다 — **잔여 결함** 등급. *스스로 프로즈-only라고 선언하는 것과 그 사실이 갭 목록에 오르는 것은 다른 일이다.*

### 5.4 차등 실행과 기준선 캐시

**캐시 키 = `(merge_base sha, runner, unit)`.** 전부 결정론적·내용주소. `unit`의 의미는 어댑터의 `granularity`가 정한다(아래 계약 참조).

- **무효화 로직이 없다.** rebase나 main 머지로 merge_base가 바뀌면 키 자체가 바뀐다. 구조적으로 stale이 불가능하다.
- **기준선 실행은 `/qg` 호출당이 아니라 merge_base당 1회 — 단 `pass`·`absent` 유닛에 한한다.** 브랜치 수명 동안 `/qg`를 8번 돌리면 그 유닛들의 설치+실행 비용은 1번이다. **기준선에서 red 였던 유닛은 매번 재실행된다**(아래 재검증 규칙) — 그 비용은 상각되지 않는다. devbrew 자신처럼 stale red를 다수 보유한 레포에서는 이 예외가 눈에 띄게 나타난다.
- 저장 위치: `.claude/quality-gates/baseline-cache/<merge_base_short>.md` — 마크다운 state (JSON 아님, CLAUDE.md 런타임 상태 규약). **세션 스코프가 아니다** — 세션을 넘어 살아남는 것이 목적이므로 `<sid>/` 형제로 둔다. GC 충돌은 §5.11이 닫는다.

파일 형식 (한 줄 = 한 결과. 파싱 실패 시 미적중 취급):

```markdown
<!-- qg-baseline-cache:v1 -->
merge_base: <full sha>
---
<runner>\t<unit>\t<pass|fail|error|unrun|absent>\t<exit-code>
```

`merge_base` 전체 sha를 **본문에도** 적는다 — 파일명은 short sha라 충돌 가능성이 0이 아니고, 본문 sha가 요청한 merge_base와 다르면 미적중으로 떨어뜨린다. 캐시 키의 세 요소(merge_base × runner × unit)가 전부 파일 안에 있으므로 조회는 순수 문자열 매칭이다.

**`unrun`·`error`는 캐시에 넣지 않는다.** 실행하지 못했다는 사실은 환경 상태(설치 실패·네트워크·OOM·timeout·권한)에 달렸고 merge_base의 함수가 아니므로, 캐시하면 다음 실행에서 복구 가능한 실패가 영구화된다. `absent`는 캐시한다 — merge_base 트리의 함수라 안정적이다.

**`fail`은 저장하되 적중으로 서빙하지 않는다 — 항상 재검증한다** (v3.0.0, /qg iter-1 리뷰 반영). 캐시 파일은 `.claude/quality-gates/baseline-cache/` 에 살고 `runtime-verifier`는 무제한 `Bash`로 그 형제 디렉토리에 쓰라고 지시받는다. 더구나 `run`은 저장소가 통제하는 코드(`bash tests/*.sh`·npm lifecycle·`make`·`build.rs`)를 호스트 사용자 권한으로 돌리므로, **적대적 subagent 없이도** 리뷰 대상 저장소의 평범한 테스트 하나가 `git merge-base`로 경로를 계산해 쓸 수 있다. 심어지거나 낡은 `fail`은 `(F,F)=PRE_EXISTING`으로 진짜 회귀를 숨긴다. (전량 적중이 §5.2 R4②의 기준선 워크트리 생성 자체를 억제하던 두 번째 경로는 **AC60이 별도로 닫았다** — 아래 표의 마지막 줄. 그 경로는 `fail` 재검증만으로는 닫히지 않는다.)

봉인(digest-seal — `plugins/quality-gates/scripts/qg-worktree.sh:201,262-272` 의 create-sandbox 스냅샷 선례. 이 문서의 §6.1이 아니다)을 쓰지 않는 이유: 캐시는 **실행 사이에 살아남는 것이 존재 이유**(merge_base당 1회 상각)라 세션 컨텍스트에 든 오케스트레이터 비밀로 봉인할 수 없고, 파일에 둔 비밀은 verifier의 `Bash`가 읽는다. 대신 **오류 방향의 비대칭**을 쓴다:

| 잘못된 캐시 값 | 실제값 | 귀속 결과 | 방향 |
|---|---|---|---|
| `fail` | pass | `PRE_EXISTING` — 결함 밖 | **회귀가 숨는다 (fail-open)** |
| `pass` | fail | `NEW_REGRESSION` | 결함으로 뜬다 (fail-closed) |
| `absent` | pass/fail | `NEW_TEST_GREEN`/`NEW_TEST_RED` | 결함으로 뜨거나 무해 |
| `pass`/`absent` | **`unrun`** | `STILL_GREEN`/`NEW_TEST_*` → `closed` | **인증이 새어 나간다 (fail-open)** — 아래 |

**표의 마지막 줄이 iter-2 에서 추가됐다 (`/qg` security-reviewer, CRITICAL).** 앞의 세 줄은 실제값을 pass 또는 fail 로만 놓고 6조합을 셌다 — spec-reviewer 가 "전수 케이스 분석"으로 exhaustive 를 독립 확인했지만 그 리뷰도 **같은 전제를 공유**했다. 다른 렌즈(보안)를 가진 리뷰어만 이 줄을 봤다.

실제값이 `unrun` 인 줄은 정직한 캐시가 만들 수 없다(`put` 이 `unrun` 을 쓰지 않는다 — AC58). **그러나 심어진 것은 만든다.** 사슬: 선택된 전 unit 에 `pass` 를 심으면 → 전량 적중 → "미적중분이 있을 때만" 이던 R4②가 **기준선 워크트리를 아예 만들지 않음** → merge_base 에 어댑터가 없어 원래 전량 `unrun` → `BASELINE_UNRUNNABLE` → `degraded` → PASS 불가였던 실행이 `STILL_GREEN` → `closed` → **PASS**.

> **이 줄은 결함 축이 아니라 인증 축이다.** 그래서 `fail` 전용 재검증이 닿지 않는다 — 위 세 줄의 논증은 여전히 옳지만 *충분하지 않다*. **"따라서 `fail` 만 재검증하면 비밀 없이 충분하다"는 쓰인 그대로 거짓이었다.**

닫는 방법은 캐시 안이 아니라 밖에 있다 (**AC60**): R4②의 기준선 워크트리 생성과 `detect` 를 **캐시 적중 여부와 무관하게 항상** 수행하고, 그 `detect` 결과를 `diff-test-results.py --baseline-detected`(필수 인자)로 넘긴다. 러너가 그 집합에 없으면 캐시가 무엇을 내줬든 기준선 축이 `unrun` 으로 강등된다. 즉 **캐시 행은 실행 비용만 낮출 수 있고 `attribution_status: closed` 의 유일 근거가 될 수 없다.** 상각되는 것은 테스트 *실행*이지 기준선 *관측*이 아니다.

`fail` 재검증은 그대로 유지된다 — 같은 규칙이 **flaky 기준선 red의 영구 동결**도 함께 닫는다(한 번 빨갛게 나온 unit이 브랜치 수명 내내 `PRE_EXISTING`을 찍어내던 경로가 사라진다). 상각은 `pass`·`absent`(대부분)에 대해 그대로 유지된다.

**소유 컴포넌트 — `scripts/baseline-cache.sh` (신규).** 캐시의 조회·검증·부분적중·갱신·동시성을 **한 스크립트가 전부** 갖는다. §5.1의 3분업 어디에도 안 들어가는 로직을 남기지 않기 위한 것이며, 오케스트레이터는 이 두 서브커맨드만 호출한다:

```
usage: baseline-cache.sh get <cache-root> <merge_base> <runner> <unit>...
  stdout: 적중한 항목만 한 줄씩 `<unit>\t<status>\t<exit-code>`
          (미적중 unit은 출력하지 않는다 → 호출자가 입력 목록과 차집합해 미적중분을 얻는다)
          **`fail`·`error`·`unrun` 상태 행은 적중으로 emit하지 않는다** — 저장돼 있어도
          미적중으로 떨어져 호출자의 차집합에 들어가고 R4②에서 재실행된다. 이것이 위
          "fail은 항상 재검증" 불변식의 **집행 지점**이다: 산문이 아니라 이 계약이 그것을
          보장하므로, 호출자가 규칙을 잊어도 재검증이 빠지지 않는다.
  exit:   0 = 정상(0건 적중 포함) · 4 = 캐시 손상(전량 미적중으로 취급, loud)

usage: baseline-cache.sh put <cache-root> <merge_base> <runner> < results.tsv
  stdin:  `<unit>\t<status>\t<exit-code>` 줄들
  exit:   0 = 기록 완료 · 4 = 기록 실패(advisory, 게이트를 막지 않음)
```

| 항목 | 규칙 |
|---|---|
| **부분 적중** | 정상 경로다. `get`이 적중분만 emit하고, 호출자가 미적중분만 R4②로 보낸다. `fail` 유닛은 정의상 항상 미적중분에 포함되므로 별도 분기가 필요 없다 — 재검증은 **자동**이다. 부분적중 병합은 "적중 줄 ∪ 새 실행 줄"이며 **키 충돌 시 새 실행이 이긴다** (같은 merge_base면 내용도 같아야 하므로 충돌 자체가 이상 신호 — `put`이 loud advisory를 낸다). |
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

**unit → 어댑터 배정은 세 번째 서브커맨드가 소유한다 — 모델이 아니다 (라운드 4).** 초안은 배정을 R1b(모델)에 맡겼는데, 그러면 AC45–AC47을 오케스트레이션과 분리해 단위 테스트할 수 없고, 파일→패키지 변환 같은 결정론적 작업이 모델 판단에 섞인다:

```
usage: run-test-selection.sh assign <worktree-abs>          # stdin: 후보 파일 경로 (한 줄에 하나)
stdout: <unit>\t<runner|unclaimed>\t<granularity>
  granularity=file    → unit = 입력 파일 경로 그대로
  granularity=package → unit = 그 파일이 속한 패키지 디렉토리 (중복 제거)
  granularity=bulk    → unit = 리터럴 BULK (흡수 어댑터당 한 줄)
  어느 어댑터도 주장하지 않음 → unit = 입력 경로, runner = unclaimed
exit: 0 · 2 = 사용 오류
```

**모델이 고르는 것은 *후보 파일*이고, 그것을 unit으로 바꾸는 것은 스크립트다.** 이 분리가 라운드 4가 지적한 go 어댑터의 모순(§5.4의 unit = 패키지 디렉토리인데 배정은 파일 패턴으로)을 해소한다 — 배정 입력은 언제나 **파일 경로**이고, 패키지 축약은 `assign`이 수행한다. §5.3의 스코프 보조 입력이 전부 file-oriented인 것과도 정합된다.

**소유권 충돌 규칙 (라운드 4 codex).** AC46이 "정확히 하나"를 요구하므로 모호한 경우를 남기지 않는다:

| 충돌 | 규칙 |
|---|---|
| `test_*.py`를 pytest·unittest가 함께 주장 | pytest 설정 존재 → pytest, 없으면 unittest |
| `*.test.ts`를 jest·vitest가 함께 주장 | `package.json`의 `test` 스크립트가 호출하는 쪽. **판별 불가면 둘 다 버리고 `npm-script`(bulk)로 폴백** — 잘못된 러너로 돌리느니 그 프로젝트가 정의한 명령을 쓴다 |
| bulk 어댑터가 복수 감지 (cargo·make·npm-script) | 잔여 흡수는 **표 순서상 첫 하나만**. 나머지는 감지됐어도 **실행하지 않고** `gap`에 `미실행 러너`로 열거 — 같은 스위트를 두 번 돌리지 않는다 |

**`unclaimed`는 `gap`이 아니라 `verification: degraded`다 (라운드 4 block).** 초안은 `unclaimed`를 `gap`에 열거하고 끝냈는데, `gap: closed`는 §5.10에서 **PASS를 막지 않는 경로**다. 그런데 `unclaimed` unit은 정의상 R1b가 **영향분으로 판정한** 것이고, 실행 수단이 없다는 것은 §5.10 자신의 *"영향분을 못 돌림"* 정의를 만족한다. 초안대로면 러너 어댑터 9종 미지원 레포(Ruby/Java 등)에서 **테스트가 한 개도 안 돌고도 PASS**가 가능하다 — 라운드 3에서 detect 레이어에 잠근 누락 방향 실패가 배정 레이어로 한 칸 내려와 재발한 것이다.

> **규칙:** `unclaimed`가 하나라도 있으면 `verification` 차원은 `degraded`이고 **PASS 불가**(≤`SKIP_WITH_EVIDENCE`)다. 목록은 `gap`에도 열거하되, 열거가 인증을 대신하지 않는다.

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

**집계도 같은 스크립트가 소유한다 (라운드 4 Finding C).** 다중 어댑터에서는 위 호출이 어댑터마다 한 번씩 일어나 N개의 YAML이 나온다. 그것을 하나의 verdict로 합치는 주체가 없으면, 오케스트레이터(모델)가 N개를 읽고 최악값을 고르는 셈이 되어 **불변식 ②가 결과값에서 없앤 "모델 요약이 판정을 결정"이 집계 레이어에서 재입장**한다. 두 번째 모드가 그것을 막는다:

```
usage: diff-test-results.py --aggregate --expected-adapters <N> <per-adapter.yaml>...
stdout (YAML):
  adapters: [<runner>, ...]
  verdict_input:                     # §5.7 우선순위 표의 기계 입력
    confirmed_product_defect: true|false
    silent_drop: true|false
    baseline_unrunnable: true|false
  attribution_status: closed | degraded
  per_adapter: {<runner>: {new_regression: N, pre_existing: N, ...}, ...}
exit: 0 · 4 = 입력 YAML 개수 != --expected-adapters (낙관적 누락 방지) · 2 = 사용 오류
```

`--expected-adapters`가 있는 이유는 **어댑터 하나의 결과 파일이 통째로 빠졌을 때 verdict가 낙관적으로 새는 것**을 막기 위해서다. 개수가 안 맞으면 조용히 남은 것만 합치지 않고 exit 4로 fail-closed한다 — `--expected`가 unit 축에서 하는 일을 어댑터 축에서 반복하는 것이다. 한 어댑터가 회귀, 다른 어댑터가 green이면 `confirmed_product_defect: true`이고 §5.7대로 `FAIL`이다.

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

**같은 층에서 두 줄이 더 얹힌다 (iter-2, AC61).** 원장 층은 카테고리를 바꾸지 않고 인증만 막을 수 있는 자리라, 이 라운드의 두 fail-open 이 여기로 들어온다:

> · 어느 축에든 `error` 상태가 닿았으면 `attribution` 원장 차원은 `degraded` 다. `error` = 러너가 0/1/127 이 아닌 코드로 끝났다 = **판정하지 못했다**. 그런데 `error` 는 fail 축으로 접히므로 양측 `error` 는 `(F,F)=PRE_EXISTING` → DEFECTS 밖 → `closed` → **테스트를 하나도 판정하지 않고 PASS** 였다. 축을 옮기지 않고 원장에서 막는 이유: 비대칭 `(P,error)` 는 확증 회귀로 남아야 하고, iter-2 에서 이 방향을 `unrun` 축으로 옮긴 수정이 "이 diff 가 import 를 깼다"를 terminal FAIL 에서 비차단으로 내렸다(실측).
> · `SILENT_DROP` 이 하나라도 있으면 `attribution` 원장 차원은 `degraded` 다. §5.10 이 이미 verdict 를 `SKIP_WITH_EVIDENCE` 로 cap 하지만, 원장에 `closed` 라고 적히면 **영구 기록이 "attribution 정상 종료" 라고 말한다** — 100% 가 drop 된 실행에서도. verdict 층과 원장 층이 같은 사실에 대해 다른 말을 하면 안 된다.

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
4. **비용 신호** — 기준선 캐시 적중 여부 · 설치 필요 여부 · **비용 등급 3단계**(`즉시`= 캐시 전량 적중(정의상 `pass`·`absent`만 적중이므로 기준선 red 유닛이 하나라도 선택되면 이 등급이 아니다)·설치 불필요 / `수 분`= 기준선 실행 필요·설치 불필요 / `설치 포함`= deps 설치 필요). **숫자 시간 추정은 쓰지 않는다** — 추정기가 없으므로 지어낸 숫자가 되고, 라운드 4에서 "대략 시간"의 출처·단위·허용오차가 미정의라고 지적됐다
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
| `cargo` | `Cargo.toml` | `cargo test` | **무시** | `CARGO_TARGET_DIR`를 **트리별 독립 경로**로 지정(§5.4 공유 경계) | bulk |
| `make` | `Makefile`에 `test:` | `make test` | **무시** | 해당 없음 | bulk |
| `npm-script` | `package.json` `"test"` 이며 위 jest/vitest 미해당 | `npm test` | **무시** | 해당 없음 | bulk |

**미지원 러너 처리 — 계약 단일화 (라운드 4 codex).** `detect`는 감지 0개일 때 **stdout을 비우고 exit 0**을 낸다(감지 실패는 오류가 아니라 결과다). `run`은 인자로 받은 어댑터를 그 트리에서 쓸 수 없을 때 **exit 3 + 전 unit `unrun` 행**을 낸다. 두 서브커맨드의 실패 표현을 섞지 않는다 — 이전 초안은 `runner: none`·빈 stdout·exit 3 세 갈래를 동시에 써서 구현자가 어느 것을 믿을지 알 수 없었다. **임의 명령을 추측해 실행하지 않는다** — 추측한 명령이 배포·마이그레이션 같은 부작용을 낼 수 있다.

**표의 행 순서는 배제 우선순위가 아니라 *같은 파일 패턴을 두 어댑터가 주장할 때*의 충돌 해소 순서다** (§5.4의 소유권 표 참조). 감지된 어댑터는 **모두** 반환되고 **모두** 실행된다 — 폴리글랏 레포에서 한 러너만 골라 나머지를 버리는 것은 라운드 3에서 block으로 잡힌 누락 방향 실패다.

**감지의 실행 지점 — `run-test-selection.sh detect` (§5.4).** 감지 지식은 이 스크립트가 **단독 소유**하되, 오케스트레이터가 **R1a(HEAD 트리)와 R4②(기준선 워크트리) 양쪽에서** `detect`를 호출해 어댑터 집합을 얻는다. 그 값이 R2 계획 산문의 러너 이름들, R4·R5b의 `<runner>` 인자, `diff-test-results.py --granularity`로 스레드된다. 오케스트레이터가 이 표를 재구현하는 경로는 **없다** — 라운드 2 Finding B가 지적한 "CLI 인자 vs 내부 감지" 순환을 서브커맨드 분리로 끊었다.

**`detect-runtime.sh`와의 관계 — 겹치지 않는 두 축.** 기존 매니페스트의 `test_runners: [npm|pytest|cargo|go|make]`는 이 8개 집합과 **일치하지 않는다**(`unittest`·`shell`·`jest`/`vitest` 분리가 없다). 해소는 **역할 분리**다:

| | 무엇을 정하나 | 소유 |
|---|---|---|
| `detect-runtime.sh` 매니페스트 | 상황별 층의 **부팅 표면**(`runnable_surfaces`·`approved_surfaces`) | C2 로 55줄 변경 — 테스트 러너를 `test_runners` 로 분리(AC21′). SHA 핀 + T9 의 5축 ∀ 가 계약을 잠근다 |
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
- **AC3** — `scripts/check-allowed-tools-order.sh`가 신규 스크립트 5종 **+ 비-플러그인 명령 `Bash(mktemp:*)` 1종**(AC69)을 포함한 순서로 갱신되고 통과한다. 이 린터는 개수·순서 **정확** 일치이므로 SKILL 과 canonical 배열 양쪽을 잠근다 — 한쪽만 고치면 red 다.

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

- **AC21** — ~~`scripts/detect-runtime.sh`가 **바이트 무변경**이다.~~
  **AC21′ 정정 (`/qg` iter-6 E7 — 이 AC 는 구현과 어긋난 채로 남아 있었다).**
  이 브랜치는 C2 수정으로 `detect-runtime.sh` 를 **55줄 바꿨다** — 테스트 러너를
  `runnable_surfaces` 에서 분리해, verifier 가 같은 스위트를 두 번째로 돌리거나 러너 deps 를
  HEAD 샌드박스에만 설치하는 경로(§5.1 불변식 ②·AC41 충돌)를 없앴다. 즉 변경은 **blast
  radius 를 줄이는 방향**이고 판단 자체는 옳지만, AC 원장이 이 브랜치의 머지 oracle 인데
  **거짓을 인증하고 있었다.** 다른 모든 정정은 append-only 개정을 받았고 이것만 못 받은 채
  `test_runtime_contract_invariance.sh` 의 핀 SHA 를 bump 하는 것으로 대체됐다 — 핀은
  *변경이 있었음*을 기록할 뿐 *그 변경이 허가됐음*을 기록하지 못한다.
  **새 계약:** `detect-runtime.sh` 는 바이트 무변경이 **아니다.** 대신 (a) SHA 핀으로 무단
  변경을 막고, (b) `runnable_surfaces` 는 **프로세스를 띄우는 표면만** 담으며 테스트 러너는
  `test_runners` 로 분리된다(T9 가 5축 ∀ 로 잠근다), (c) 남는 표면은 전부
  `requires_decision: true` 다. **AC22 는 이 정정의 대상이 아니며 실측으로 성립한다** —
  `qg-worktree.sh` 는 이 브랜치에서 +44/**-0** 즉 순수 추가(`create-baseline` 새 case 절)이고
  `create-sandbox`·`mutation-guard` 본문은 한 줄도 바뀌지 않았다. 두 AC 를 한 문장에 묶어
  적었던 것(§3 Non-goals)이 "둘 다 깨졌다" 는 오독을 부를 수 있어 거기도 분리했다.
- **AC22** — `qg-worktree.sh`의 `create-sandbox` · `mutation-guard` 본문이 **바이트 무변경**이다. 다른 case 절은 이 AC의 대상이 아니다: `create-baseline`·`create-head`는 두 축 트리를 만드는 공유 헬퍼(`make_detached_worktree`)를 부르는 얇은 절이며, `create-baseline`의 **동작**은 기존 행위 테스트(경로 emit · merge_base 내용 · detached · 충돌 거부 · idempotent)로 잠겨 있다. T17은 두 절의 case 본문만 잘라 해시하므로 이 리팩터에 영향을 받지 않는다.
- **AC65** — HEAD 축 테스트는 **verifier 샌드박스가 아닌 자기 트리**에서 돈다. `create-head` 는 넘어온 sha 를 **이 세션 샌드박스의 봉인 커밋과 대조**하고 다르면 die 한다(merge_base·stale 값 거부). 트리 수명은 **R6 끝**까지다 — R6 의 flaky 재실행이 그 트리를 쓴다. `qg-worktree.sh create-head <B> <sid>`가 봉인 커밋에 detached된 일회용 워크트리를 기준선 트리와 **다른 경로**에 만들고(동시 공존), R5b의 `run` 호출이 그 트리를 받는다. 재시도 경로는 refresh된 `baseline_sha`로 이를 다시 만든다. (§11 ⑬·⑨ 해소. 검증: T88 + 오케스트레이션 창 락 4종.)
- **AC67** — R5b 는 R6·R7 과 같은 모양의 **실패 라우팅 표**를 갖는다. `create-head`/`run` 이 non-zero 면 그 축을 전량 `unrun` 으로 기록하고 `verification: degraded` 로 두며, `$runtime_project_dir`·`$project_dir` 로 **폴백하지 않는다**. (§11 ⑬ (c). 검증: 오케스트레이션 락.)
- **AC68** — R8 의 원장 게이트가 **`unclaimed` → `verification: degraded` 를 집행**한다. `check_qa_ledger.py --assign-rows <배정 TSV>` 는 필수 인자이며, `unclaimed` 행이 1건 이상인데 `floor:verification` 이 `degraded` 가 아니면 non-zero. 파일이 없거나 3필드 문법을 어긴 행이 있으면 통과가 아니다(fail-closed — 셀 수 없는 입력을 0건으로 접지 않는다). R1b 는 `assign` stdout 을 `$assign_rows_file` 로 남긴다. **인자를 개수(`--unclaimed-count N`)가 아니라 경로로 받는 이유**: 개수는 모델이 옮겨 적는 값이라 AC66 이 방금 닫은 전사 구멍을 같은 이음매에 다시 뚫는다 — `0` 하나로 검사가 사라진다. (§11 ㉓ 해소. 검증: T93 · T94.)
- **AC68′** (종료 코드 축 분리 — iter-8 리뷰) — `check_qa_ledger.py` 의 종료 코드가 **인자 모양(2)** 과 **내용(4)** 을 구분한다. 형제 스크립트의 규약과 같다(AC60: *"생략 시 exit 2, 빈 값은 exit 4"*). 앞 버전은 둘 다 2 라 *"부르는 법을 틀렸다"* 와 *"읽었는데 믿을 수 없다"* 가 같은 신호였다. 소비자(R8)는 어느 쪽이든 non-zero → PASS 불가로 라우팅하므로 **동작이 아니라 진단**을 고치는 것이다. 함께: 원장 파일 read 경로에 `UnicodeDecodeError` 핸들러가 없어 비-UTF-8 원장이 트레이스백이었다 — 형제 두 경로에서 이미 고친 **같은 버그의 세 번째 인스턴스**. (검증: T95.)
- **AC69** — 오케스트레이터 소유 중간 파일 6종의 **위치가 R-init 에서 정의**된다. `mktemp -d` 로 만든 실행-스코프 디렉토리 하나에 살며, `$project_dir` 안도 `$evidence_dir` 안도 아니어야 한다. 앞의 금지는 실측이다: `create-sandbox` 는 `ls-files --others --exclude-standard` 로 **미추적·비-ignore 파일을 샌드박스로 복사한 뒤 커밋 `B` 로 봉인**하고 `.claude/quality-gates/worktrees/*` 만 건너뛴다 — 레포가 `.claude/` 를 ignore 하지 않으면 중간 파일이 기준선 커밋 안으로 들어간다. 뒤의 금지는 `$evidence_dir` 이 R5a³ 에서 verifier 에게 넘어가기 때문이다(피검자가 대조 원본을 쓰면 대조가 자기 자신을 대조한다). 어댑터별 4종은 러너 이름으로 가른다. 이 요구가 SKILL `allowed-tools` 에 **유일한 비-플러그인 명령** `Bash(mktemp:*)` 을 추가시키며, 그 목록은 개수·순서 정확 린터(`check-allowed-tools-order.sh`)가 양쪽에서 잠근다. **custody 는 여전히 열려 있다**(§6.7 S1) — 이 AC 는 위치만 정한다. (§11 ㉕ 해소. 검증: **T96** + T94 ⓪ + 린터. 앞 버전은 T94 ⓪ 만 인용했는데 그것은 6종 중 하나의 *정의 순서*만 재고 (a)·(b)·(c) 어느 것도 재지 않았다 — iter-8 리뷰 high.)
- **AC66** — R8 의 원장 게이트가 **기계 집계값과 원장 전사값을 대조**한다. `check_qa_ledger.py --aggregate <집계 YAML>` 는 필수 인자이며, 집계의 `attribution_status` 와 `floor:attribution` 의 status 가 다르면 non-zero. 집계 파일이 없거나 `attribution_status` 줄이 정확히 1개가 아니면 통과가 아니다(fail-closed). R6 은 집계 stdout 을 `$aggregate_yaml` 로 남긴다. (§11 ⑱ 해소. 검증: T90 · T91.)
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
- **AC32** (캐시 조회) — `baseline-cache.sh get`이 **적중분만** emit한다(미적중 unit은 무출력). 적중 집합은 `pass`·`absent` 두 상태로 한정되며 `fail`·`error`·`unrun` 행은 저장 여부와 무관하게 미적중으로 떨어진다(AC58·AC59). 헤더 마커·`merge_base` 줄 불일치·파싱 실패 시 **exit 4 + 전량 미적중**이며, 부분 파싱된 일부를 적중으로 내지 않는다.
- **AC33** (캐시 기록) — `baseline-cache.sh put`이 임시 파일에 전량을 쓴 뒤 `mv` rename한다. 중단 시 부분 기록된 캐시 파일이 남지 않는다.
- **AC34** (러너 어댑터) — `run-test-selection.sh`가 받는 `<runner>`가 §5.9의 **8개 닫힌 집합**에 속한다. 감지되지 않은 러너에 대해 명령을 추측해 실행하는 코드 경로가 없다. **`detect`의 0-어댑터는 빈 stdout + exit 0이다**(§5.9·AC56·T34·T54와 일치; 실측 확인). `exit 3`은 `run`이 요청받은 어댑터를 이 트리에서 쓸 수 없을 때만 쓴다 — 옛 문구는 두 서브커맨드의 계약을 뒤섞어 문서 안에서 자기모순이었다(codex 독립 지적).
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

### 6.4 리뷰 라운드 4에서 추가된 AC (AC52–AC57)

- **AC52** (배정 소유자) — `run-test-selection.sh assign`이 후보 **파일 경로**를 받아 `<unit>\t<runner|unclaimed>\t<granularity>`를 emit한다. 파일→패키지 축약이 이 스크립트 안에서 일어나며, 오케스트레이터가 unit 변환을 수행하는 경로가 없다.
- **AC53** (`unclaimed` → PASS 불가 — block 해소) — `unclaimed` unit이 하나라도 있으면 `verification: degraded`이고 verdict가 `PASS`가 **아니다**. 러너 어댑터 9종 미지원 레포에서 아무 테스트도 안 돈 채 `PASS`가 나오는 경로가 없다.
- **AC54** (충돌 규칙) — pytest/unittest · jest/vitest · 복수 bulk 어댑터 각각에 결정론적 소유권 규칙이 있고, 모든 unit이 정확히 하나의 어댑터 또는 `unclaimed`에 배정된다. 같은 스위트를 두 bulk 어댑터가 중복 실행하는 경로가 없다.
- **AC55** (집계 소유자) — `diff-test-results.py --aggregate`가 N개 어댑터 YAML을 `verdict_input`으로 합친다. 입력 개수가 `--expected-adapters`와 다르면 **exit 4**이며, 남은 것만 낙관적으로 합치지 않는다. 오케스트레이터가 N개 YAML을 읽고 최악값을 고르는 경로가 없다.
- **AC56** (0-어댑터 계약 단일화) — `detect`는 감지 0개에서 **빈 stdout + exit 0**, `run`은 어댑터 사용 불가에서 **exit 3 + 전 unit `unrun`**. production 파일(`scripts/`·`skills/`·`agents/`)에 `runner: none` 문자열이 없다.
- **AC57** (비용 신호 형식) — 계획 산문의 비용 신호가 `즉시`/`수 분`/`설치 포함` 3단계 범주값이며, 숫자 시간 추정을 포함하지 않는다.

### 6.5 `/qg` iter-1 리뷰에서 추가된 AC (AC58–AC59)

번호는 append-only(§6.1 preamble 승계). 두 규칙 모두 §5.4 amendment가 도입했고, 이 문서 자신이 요구하는 "AC 추가 시 대응 T/V 없이 머지하지 않는다"를 만족시키기 위해 T56·T57·M27·M28과 함께 들어온다.

- **AC58** (환경-유래 상태 미캐시) — `baseline-cache.sh put`이 `unrun`과 **`error`** 를 캐시에 기록하지 않는다. 기록 가능한 상태는 `pass`·`fail`·`absent` 셋이다. 근거는 AC40과 동일하다: 두 상태 모두 환경(설치 실패·네트워크·OOM·timeout·권한)에 달렸고 merge_base의 함수가 아니므로, 캐시하면 복구 가능한 실패가 영구화된다.
- **AC59** (`fail` 강제 재검증) — `baseline-cache.sh get`의 **적중 집합이 `pass`·`absent` 두 상태로 한정된다.** `fail`은 파일에 저장되지만 적중으로 emit되지 않으므로 호출자의 미적중분에 들어가 R4②에서 재실행된다. 이 규칙이 (a) 봉인 없는 캐시에 심어진 `fail`이 회귀를 `PRE_EXISTING`으로 숨기는 경로와 (b) flaky 기준선 red의 영구 동결을 **하나의 변경으로** 닫는다. 이전 버전이 남긴 캐시의 `error`·`fail` 행도 같은 필터에 걸려 스스로 낫는다.

### 6.6 `/qg` iter-2 리뷰에서 추가된 AC (AC60–AC63)

> ⚠️ **AC61·AC62·AC63 은 §6.7 이 정정했다 — 아래 정의문만 읽고 구현하지 말 것.**
> append-only 관례상 원문을 지우지 않지만, 세 항목은 이후 실측으로 **반증되거나 유해함이 드러난** 서술을 포함한다. 유효한 것은 §6.7 의 정정본이다:
> · **AC61** — 아래가 열거한 `error` 트리거 중 jest/vitest·shell 은 거짓(실측 exit 1). 잔여는 go 가 아니라 **exit 1 전체**다.
> · **AC62** — `same_as_head: yes` **단독**으로 R4 를 스킵하는 규칙은 양성 케이스에 **해로운 것으로 측정됐다**(진짜 FAIL → SKIP). 판별자는 `same_as_head` × `worktree_dirty` 다. 또한 "R6 에 집행자가 있다" 는 거짓이다.
> · **AC63** — 아래 술어는 ∃ 조건이고 **실측으로 뚫렸다**(mixed 파일·docstring 예제). 유효한 것은 모듈-레벨 bare `def test_` 부재를 AND 한 ∀ 조건이다.

번호는 append-only(§6.1 preamble 승계). 네 규칙 모두 iter-2 의 CRITICAL 4건에 대응하고, T58–T61 · M29–M32 와 함께 들어온다.

**공통 근거 — 이 라운드의 결함은 전부 한 모양이다.** §5.4 의 비대칭 표(AC59)와 §5.9 의 "판정할 수 있는 파일만 claim", R4② 의 "두 집합이 다르면 한쪽에만 있는 어댑터의 unit 은 반대편에서 `unrun` 이 된다" — 셋 다 **산문으로만 존재했고 집행자가 없었다.** 아래 AC 는 각 규칙에 결정론 소유자를 하나씩 붙인다.

- **AC60** (기준선 관측 접지) — `diff-test-results.py`의 per-adapter 모드가 **`--baseline-detected`를 필수 인자로** 받는다(생략 시 exit 2, 빈 값은 exit 4, 감지 0개는 리터럴 `NONE`). `--runner`가 이 집합의 **원소가 아니면**(부분문자열 아님) 그 어댑터의 모든 unit 은 기준선 축이 `unrun` 으로 강등돼 `BASELINE_UNRUNNABLE` → `degraded` → PASS 불가가 된다. **캐시 행이 무엇을 내줬든 무관하다.** 이 인자를 정직하게 만드는 경로는 merge_base 워크트리에서 `detect`를 돌리는 것뿐이므로, 심어진 캐시가 전량 적중을 만들어 R4②를 억제하던 경로가 사라진다 — §5.4 의 비대칭 표는 실제값이 pass/fail 인 줄만 셌기 때문에 **실제값이 `unrun`인 줄**을 놓쳤고, 그 줄은 결함 축이 아니라 **인증 축**이라 `fail` 전용 재검증(AC59)이 닿지 않는다. 짝으로 R4②의 기준선 워크트리 생성은 **캐시 적중 여부와 무관하게 항상** 수행된다(상각 대상은 테스트 *실행*이지 기준선 *관측*이 아니다).
  **메커니즘 정정 (/qg iter-5 CRITICAL SR1).** 위 문장의 *"이 인자를 정직하게 만드는 경로는 merge_base 워크트리에서 `detect`를 돌리는 것뿐"* 은 **틀렸다.** `detect`는 *이 트리가 무엇을 선언했는가*(`go.mod`가 있다·`pyproject.toml`에 pytest 설정이 있다)만 보므로, **선언은 있고 toolchain이 없는 트리에서도 러너 이름을 내준다.** 실행 가능성을 재는 관문(환경 디렉토리 gitignore → `setup_cmd` → 러너 바이너리)은 `run` 안에만 있었고, 캐시가 **전량 적중**이면 R4의 `run`이 호출되지 않아 그 관문이 한 번도 돌지 않는다. 즉 AC60이 닫았다고 주장한 사슬은 **한 칸 옆으로 옮겨간 채 살아 있었다** — 원래 전량 `unrun` → `BASELINE_UNRUNNABLE` → `degraded` → PASS 불가였을 실행이 다시 `STILL_GREEN` → `closed` → **PASS**가 된다. 해소: `run-test-selection.sh`에 **`probe` 서브커맨드**를 추가해 `run`과 **같은** 관문을 테스트 없이 통과시키고, `--baseline-detected`의 출처를 `detect`의 집합이 아니라 **`probe`가 `usable: yes`를 낸 러너의 집합**으로 옮겼다(R4②-a, 캐시 적중 여부와 무관하게 항상). 관문은 이제 두 서브커맨드가 **한 함수**(`adapter_usable`)를 공유하므로 한쪽만 고치는 drift가 T72에서 죽는다. **캐시의 존재 이유는 유지된다** — 상각되는 것은 테스트 *실행*이고 `probe`가 되살리는 것은 *관측*이다(전량 적중을 이유로 기준선 스위트를 다시 돌리는 것은 해법이 아니라 캐시를 없애는 것이다). *잔여(명시)*: `--baseline-detected`에 **정직한 값을 넘기는 것 자체**는 여전히 오케스트레이터의 의무다 — 스크립트는 값의 provenance를 검사하지 않으며 `"$runner"`를 그대로 넘기면 항상 grounded가 된다(codex block 2 "귀속 입력 소유·provenance"와 같은 뿌리). 검증: T70(선언≠실행) · T71(probe는 테스트를 돌리지 않는다) · T72(probe↔run 관문 일치, ∀) · T73(R4②-a 스텝 4축) · T74(출처 ∀).

- **AC61** (판정 못 한 실행은 인증하지 않는다) — `diff-test-results.py`가 어느 축에든 `error` 상태가 닿은 어댑터를 `attribution_status: closed`로 내보내지 않는다. `error`는 fail 축으로 접히므로 **양측 `error`가 `(F,F)=PRE_EXISTING` → DEFECTS 밖 → `closed` → 테스트를 하나도 판정하지 않고 PASS**였다. 축은 그대로 두고 **인증만** 막는 이유: 비대칭 `(P,error)`는 확증 회귀로 남아야 하고(iter-2 에서 이 방향을 `unrun`으로 옮긴 수정이 "이 diff 가 import 를 깼다"를 terminal FAIL 에서 비차단으로 내렸다 — 실측), 라벨을 바꾸면 8종 카테고리 계약(AC11)이 깨진다. **종료 코드를 러너별로 열거하지 않는다** — 열거는 공간·시간 양쪽으로 fail-open 이고, 같은 코드가 러너마다 다른 의미를 갖는다. *잔여(명시)*: 러너가 판정 실패를 **exit 1**로 내면(go 컴파일 에러가 실측 exit 1) 이 규칙에 닿지 않는다. 출력 파서 없이는 테스트 실패와 구분 불가이며, 러너별 파서는 §5.9가 금지한다.
- **AC62** (기준선 ref 사실 공개) — `resolve-baseline.sh`가 `same_as_head`(yes|no|-)와 `ahead`(커밋 수|-)를 **6키 계약의 일부로** emit 한다(degrade 경로 포함 — 키 누락은 소비자의 빈-문자열 조회를 fail-open 으로 만든다). Runtime 게이트는 `degraded: yes` **또는** `same_as_head: yes`를 차등 증거 불가로 읽어 PASS 를 막는다. **이 스크립트는 판정하지 않는다** — `merge_base == HEAD`는 정상(`main` 위 미커밋 작업)으로도 변조(base 후보 ref 는 전부 공유 common gitdir 에 있고 `run`이 실행하는 저장소 코드가 `git update-ref`를 할 수 있다)로도 생기며 구분할 방법이 없기 때문이다. Review 게이트의 changes-exist floor 는 이 키를 **읽지 않는다**(거기서는 `worktree_dirty`가 변경을 잡으므로 정상 케이스를 죽이면 v2.6.0 이 닫은 false-clean 이 돌아온다). *잔여(명시)*: base 를 HEAD 가 아니라 브랜치 **중간 커밋**으로 옮기는 부분 변조는 `same_as_head: no`이고 기준선 트리도 만들어진다 — 신뢰 채널이 없어 결정론으로 닫을 수 없고, `ahead` 공개가 사람에게 보이는 유일한 신호다.
- **AC63** (unittest 판정가능성 술어) — `unittest_can_judge`가 **선언 위치에 앵커된** 두 신호만 받는다: 줄 시작의 `class <ident>(…TestCase…)` 또는 `def load_tests(`. 앵커 없는 파일-전체 부분문자열(`grep -qE '(unittest|TestCase)'`)은 `from unittest.mock import patch`·`# run with pytest, not unittest`·`class TestCaseHelpers:`를 전부 통과시켰고, 실측으로 claim → `discover` 0개 수집 → **exit 0 → `pass`**가 재현됐다(같은 파일을 pytest 로 돌리면 `1 failed`). 미매치는 `unclaimed` → `verification: degraded`(AC53)로 fail-closed 다. 이 게이트는 **`unittest` 어댑터에만** 적용된다 — pytest 는 bare `def test_`를 정상 수집하므로, 한정을 빼면 평범한 pytest 레포가 구조적으로 인증 불가가 된다.

---

### 6.7 `/qg` iter-3 정정 (AC64 + AC61–AC63 수정)

iter-3 리뷰(리뷰어 5종 + adversarial 15 CONFIRMED)가 **iter-2 수정 자체의 결함 7건**을 올렸다. 그중 둘은 코드 주석이 *실측 사실*로 단언한 내용이 실제로는 거짓이었던 것이다. append-only 로 정정을 기록한다.

- **AC64** (판정 0건은 인증이 아니다) — `diff-test-results.py` 가 **아무 unit 도 대조하지 않은 실행**을 `attribution_status: closed` 로 내보내지 않는다. per-adapter 는 `--expected` 가 비면, aggregate 는 어댑터가 0개면 `degraded` 다. 빈 `--expected` 는 attributions 를 비우고 모든 카운트를 0 으로 만들어 기존 degrade 조건 **전부**를 비껴갔고, 결과는 `closed` + `verdict_input` 3플래그 전부 false — R8 PASS 행의 결정론 조건을 **완전히** 충족한다. 이를 막던 유일한 것은 SKILL.md 의 한국어 문장(`영향분 0개 → SKIP_WITH_EVIDENCE`)이었고, 그 동작을 통째로 지워도 그 문장의 grep 락은 GREEN 이다(실측). 러너 어댑터 9종 미지원 레포(Ruby/Java 등)가 테스트를 한 개도 돌리지 않고 PASS 를 받는 경로였다. 리뷰어 2명이 독립 보고. **주의:** `test_zero_adapters_is_a_legal_empty_result` 가 이 fail-open 을 *계약으로* 못 박고 있었다 — 테스트가 취약점을 단언한 경우이므로 케이스 이름과 함께 정정했다.
- **AC61 정정** (트리거 열거가 거짓이었다) — 근거 주석과 CHANGELOG 가 `error` 트리거로 열거한 **jest/vitest "No tests found"** 와 **전제조건 없는 shell 하니스**는 실측 결과 **exit 1** 이라 `fail` 로 접히고 이 규칙에 **닿지 않는다**. 실제 트리거는 pytest(2·4·5)와 cargo(101) 뿐이다. 잔여는 "go 컴파일 에러" 가 아니라 **exit 1 전체**다 — 이 수정이 닫는 범위보다 크다. 규칙 자체는 유효하나 **범위 주장이 과장돼 있었다**.
- **AC62 정정** (집행자 주장 철회 + 판별자 교체) — (a) `same_as_head` 를 **읽는 스크립트가 하나도 없다**(grep 확인). 실제 git 으로 `update-ref main→HEAD` + 정직한 `detect` + 진짜 회귀 → `PRE_EXISTING` → `closed` 가 재현됐다. (b) SKILL.md 의 *"이 규칙에는 R6 에 집행자가 있다"* 는 **거짓**이다 — `--baseline-detected` 는 *문자열이 도착했음*만 강제하고, `"$runner"` 를 그대로 넘기면 항상 grounded 다(mutation GREEN). 주장을 철회하고 부분 집행자로 다시 적었다. (c) `same_as_head: yes` 만으로 R4 를 스킵하던 규칙은 **양성 케이스에 해로웠다**: `main` 위 미커밋 작업에서 측정된 `NEW_REGRESSION`/FAIL 이 `BASELINE_UNRUNNABLE`/SKIP 으로 내려갔다. 차등이 실제로 불가능한 것은 `same_as_head: yes` **이고 워킹 트리가 깨끗할 때**뿐이므로 판별자를 `worktree_dirty` 로 좁혔다.
- **AC63 정정** (∃ → ∀) — 술어가 *"discover 가 수집할 것이 하나라도 있는가"* 를 물었는데 필요한 것은 *"discover 가 놓치는 것이 없는가"* 였다. 실측 탈출 셋: mixed 파일(진짜 TestCase + 모듈-레벨 bare `def test_`) → `pass 0` 인데 pytest 는 2 failed · **docstring 예제 안의 들여쓴 `class T(unittest.TestCase):`** → 매치(같은 함수의 주석이 "docstring 은 만족시킬 수 없다" 고 단언했다 — 거짓) · `test_` 메서드 없는 TestCase 하위클래스 → `Ran 0 tests` → exit 0. 앞의 둘을 **모듈-레벨 bare `def test_` 부재** 라는 음성 조건 AND 로 함께 닫았다. 셋째는 별도 축이라 **열려 있다**.

**검증:** T62 · T63 · M33 (아래 §8.1/§8.2 표에 실제로 들어간 항목). — 앞 버전은 이 자리에 **§8 어디에도 없는 `T62`/`T63`과, 이미 다른 mutation 에 배정된 `M17`–`M22`**(M17=`setup_cmd` 비대칭, M18=bulk-green 추가 캐싱, M19=`gap:closed` PASS 허용, M20=단일 어댑터 반환, M21=HEAD 어댑터 집합 재사용, M22=`SILENT_DROP` 상호대조)를 근거로 적었다 — **실재하지 않는 커버리지를 있는 것처럼 보이게 하는 거짓 안심 신호**였고, 이 문서가 경계하라고 적은 패턴의 검증-계획 버전이다 (/qg iter-3 spec review, block).

**닫지 않은 것 (iter-3 잔여 — 이 브랜치는 병합 불가).** 아래 열거는 **16 항목**이고, 그중 ⑬(`SKILL.md` 산문 락)은 10개 락을 한 줄로 묶은 것이라 **락 단위로 세면 25**다. 앞 버전은 이 자리에 "21건"이라 적었는데 **어느 세는 규칙으로도 재현되지 않는다** — 열거와 수가 어긋나면 다음 독자가 목록을 세지 않고 수를 믿는다(라운드 7 spec review, medium). 세는 규칙을 함께 적는다. **이 목록은 append-only 기록이며, 살아 있는 갭 원장은 §11이다** — 이후 발견된 갭은 여기가 아니라 §11에 등재한다.

귀속 입력 파일 4종의 custody 부재(S1) · 부분 merge_base 변조(S3) · bulk 흡수자가 `unclaimed` 행 삭제(F5) · `resolve-baseline.sh` 부재 시 조용한 false-clean(F6) · `$baseline_rows_file` 조립 규칙 부재(C3) · `$adapter_count` 미정의(C4) · R7 이 R5b 뒤라 게이트 자기 부작용이 거짓 terminal FAIL(S4) · `dir_is_ignored` 신뢰모델 불일치(S5) · `*.spec.*` 글롭(S6) · aggregate 의 flag/count 미대조(X1) · 후보에 staged/untracked 누락(X3) · 캐시 락(X4) · SKILL.md 산문 락 10종의 부정문 취약 · AC60 값 provenance 미잠금 · 종료코드 열거 락 · AC63 경계 미잠금.

**이후 닫힌 것 (열거는 append-only 기록이므로 지우지 않고 여기 표시한다).** 위 16 항목 중 **S4 는 `/qg` iter-7 에서 닫혔다** — R5b 가 verifier 샌드박스를 떠나 `create-head` 의 자기 트리로 옮겨가면서, R7 의 guard 가 검사하는 트리에 게이트 자신의 테스트 아티팩트가 더 이상 떨어지지 않는다. **순서(R7 이 R5b 뒤)를 바꿔 닫은 것이 아니라 두 단계가 서로 다른 트리를 보게 해서 닫았다** — 순서는 그대로다. 상세와 검증은 §11 ⑬. 따라서 열거는 여전히 16 항목이고 **열려 있는 것은 15 항목**이다. 이 문단이 세는 규칙의 일부이므로, 이후 항목이 닫힐 때마다 여기 함께 적는다.

## 7. Files to Modify

### 신규 (5 + 테스트)

| 경로 | 무엇 |
|---|---|
| `scripts/resolve-baseline.sh` | base/base_ref/merge_base/degraded 공유 resolution (OQ5) |
| `scripts/run-test-selection.sh` | `detect`(러너·입도·setup 감지) + `run`(결정론 실행, unit당 1행 총 함수). 러너 어댑터 9종 단독 소유 |
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
| `scripts/qg-worktree.sh` | `create-baseline` + `create-head` case 절 추가 · 두 절이 공유하는 `make_detached_worktree` 헬퍼 (`create-sandbox`/`mutation-guard` 본문 무변경 — AC22) |
| `scripts/qg-gc.py` | 내용 기반 세션 식별 (§5.11) |
| `scripts/check-allowed-tools-order.sh` | 신규 5종 순서 등재 (C5) |

### 구현 의존 순서 (라운드 3 Finding 9 — `writing-plans`가 12파일 단일 diff로 뭉치지 않도록)

신규 5종은 인과적으로 결합돼 있어 설계 문서를 쪼갤 대상은 아니지만, **구현 순서는 강제된다**:

```
1) resolve-baseline.sh          ← 독립. 소비자(check-review-scope · compute-test-scope)와 함께
2) run-test-selection.sh        ← 독립(러너 어댑터 9종 + detect/run). 5-상태값 계약을 여기서 확정
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
| T16 | `detect-runtime.sh` 가 **핀된 sha 와 동일** — 무단 변경 차단(바이트 *무변경* 이 아니다: C2 가 55줄 바꿨고 핀은 그에 맞춰 갱신됐다) | AC21′ |
| T17 | `create-sandbox`/`mutation-guard` 본문 바이트 동일 | AC22 |
| T18 | `hooks.json` 항목 수 · `agents/` 파일 수 · verdict 토큰 집합 불변 | AC24–26 |
| T19 | `qg-gc.py` — `worktrees`/`baseline-cache` 생존 + 세션 폴더 삭제 (양방향) | AC27, AC28 |
| T20 | `plugin.json` major digit == 3 (patch digit unpin) | AC29 |
| T21 | **재실행 호출 횟수 == 1** — `NEW_REGRESSION` 후보 1건에 대해 `run-test-selection.sh` 호출 카운터가 정확히 1 증가. **stub 러너는 3회째 `pass`로 전환**한다(항상 `fail`이면 버그 루프가 종료하지 않아 RED가 아니라 타임아웃이 된다 — 이빨이 시계에 의존하면 안 됨) | AC12 |
| T22 | `SKILL.md`에서 `run-test-selection.sh` 호출이 verifier dispatch 블록 밖 + authoritative 문장 존재 + verifier 페르소나에 self-report 배제 문구 | AC31 |
| T23 | `baseline-cache.sh get` — 전량 적중 / 부분 적중(적중분만 출력) / 헤더 손상(exit 4 + 무출력) / `merge_base` 불일치(무출력) 4 픽스처 | AC32 |
| T24 | `baseline-cache.sh put` — 임시파일+rename 사용 확인, 중단 시 부분 파일 부재 | AC33 |
| T25 | 러너 어댑터 — 8개 각각 감지 픽스처 + 미감지 레포에서 `detect`가 빈 stdout + exit 0 + **추측 명령 실행 0회**. `run`의 미가용 어댑터 exit 3은 T54가 잰다 | AC34 |
| T26 | 확증 회귀 + `SILENT_DROP` 동시 입력 → verdict `FAIL` 이며 degrade가 원장에 함께 기록 | AC35 |
| T27 | `error` 입력 → `fail`로 접힘 + 라벨 `(error)` 병기 / exit 3 입력 → 미실행 축 | AC36 |
| T28 | 계획 산문 6필드 존재 + 선택 비율이 `N개 선택 (전체 M개 중)` 포맷 | AC19 |
| T29 | 분모 M이 `compute-test-scope-candidates.sh --total` 출력과 일치 | AC37 |
| T30 | `/qg runtime` 단일게이트 경로 — R-init zero-click 폴백 포함 보존 | AC23 |
| T31 | **영향분 0개 → `SKIP_WITH_EVIDENCE`** + gap 차원에 "기존 테스트 없음" 기록 + verdict ≠ PASS | AC15(빈 스코프 분기) |
| T32 | `check-allowed-tools-order.sh` 통과 — 신규 5종 **+ `Bash(mktemp:*)`** 등재. 개수·순서 정확 일치라 SKILL 만 고치거나 canonical 배열만 고치면 red (mutation 2축 RED) | AC3 |
| T33 | `README.md` — Principles Instantiated 3줄 + 컴포넌트 트리 신규 5종 등재 | AC30 |
| T34 | `detect` — 러너 어댑터 9종 각각 3줄 emit · **감지 0개면 빈 stdout + exit 0** · **SKILL 쪽 감지-표 재구현 0회**(어댑터 표의 감지 조건 문자열이 SKILL.md에 없음) | AC38 |
| T35 | `run`이 입력 unit 수 == 출력 행 수 (정상·exit 3·일부 absent 3 픽스처) + 행 누락 입력에서 `SILENT_DROP` | AC39 |
| T36 | 상태 5종 각각 1 픽스처 + `unrun`은 `put` 후 캐시에 부재 / `absent`는 존재 | AC40 |
| T37 | `setup_cmd`가 기준선·HEAD 호출에서 **동일 문자열**로 실행됨(호출 로그 대조) + verifier 페르소나에 deps-설치 배제 문구 | AC41 |
| T38 | `granularity=file`에서 bulk-green → unit별 `pass` 캐시 · `BULK` 키 부재 / `granularity=bulk`에서만 `BULK` 키 생성 | AC42 |
| T39 | `diff-test-results.py --granularity bulk` + fail/fail → 귀속 `PRE_EXISTING` **이면서** `attribution: degraded` | AC43 |
| T40 | 영향분 러너 부재 → verdict ≠ PASS + `verification: degraded` / 무관 표면 러너 부재 → PASS 가능 + `gap: closed` (두 픽스처) | AC44 |
| T41 | **아티팩트 유출** — `make`/`npm-script` 스텁 레포에서 `run` 실행 후 비-ignored 신규 파일이 생기는지 실측. **iter-7 이후 역할이 바뀌었다**: 이 유출은 더 이상 거짓 FAIL 을 낳지 않는다(R5b 가 guard 검사 대상 밖 트리에서 돌기 때문 — §11 ⑬). 이제 재는 것은 *일회용 트리의 청결도*이지 봉쇄의 유무가 아니다 | §11 ⑨(해소) |
| T42 | `detect` 다중 반환 — `test_*.py` + 실행비트 `tests/*.sh` 공존 픽스처에서 어댑터 **2개** 반환 · 둘 다 `run` 호출됨 (호출 로그) | AC45 |
| T43 | 어느 패턴에도 안 걸리는 unit → `unclaimed`로 `gap`에 열거 (조용한 누락 0) | AC46 |
| T44 | 기준선 트리에서 `detect` 재실행 · HEAD와 집합이 다른 픽스처(한쪽만 pytest)에서 해당 unit 귀속 `degraded` | AC47 |
| T45 | `diff-test-results.py` — `--expected`에 있으나 양측 산출물에 행 없음 → `SILENT_DROP` / 중복 unit 행 → exit 4 | AC48 |
| T46 | bulk 어댑터 실행 → `verification` evidence·계획 산문에 커버리지 미보장 문구 존재 | AC49 |
| T47 | 기준선·HEAD 실행의 `CARGO_TARGET_DIR`/`node_modules`/`.venv` 경로가 서로 다름 (env·경로 대조) | AC50 |
| T48 | 락 라벨 5종이 새 라벨로 이전 + §5.2 매핑표의 기존 로직 8종이 새 SKILL.md에 모두 존재 (grep 8건) | AC51 |
| T49 | `qg-gc.py` **실패 재현** — TTL 초과 + 직접 파일 없는 `worktrees`가 수정 전 코드에서 삭제됨을 먼저 증명 (§5.11이 약속한 재현) | §5.11 |
| T50 | `assign` — 파일 경로 입력 → file/package/bulk unit 산출 (go 픽스처에서 파일→패키지 축약 확인) · SKILL 쪽 unit 변환 0회 | AC52 |
| T51 | `unclaimed` 1개 이상 → `verification: degraded` **AND** verdict == `SKIP_WITH_EVIDENCE` (정확 일치) · 미지원 레포 픽스처에서 PASS 0회 | AC53 |
| T52 | 충돌 3종 픽스처 — pytest+unittest · jest+vitest(판별불가→npm-script 폴백) · cargo+make(첫 하나만 흡수, 나머지 `미실행 러너`) | AC54 |
| T53 | `--aggregate` — 어댑터 A 회귀 + B green → `confirmed_product_defect: true` / 입력 YAML 개수 부족 → exit 4 | AC55 |
| T54 | `detect` 감지 0개 → 빈 stdout + exit 0 / `run` 어댑터 사용 불가 → exit 3 + 전 unit `unrun`. **금지 문자열 스코프 = `scripts/`+`skills/`+`agents/` 의 production 파일만** (design doc·테스트 자신은 그 문자열을 *금지 서술*로 담으므로 제외 — 스코프를 안 좁히면 락이 자기 자신을 잡는다) | AC56 |
| T55 | 계획 산문 비용 신호가 3단계 범주값 중 하나 · 숫자 시간 문자열 0회 | AC57 |
| T56 | `put` 후 **캐시 파일 본문을 직접 검사** — `error` 행 부재 · `pass` 행 존재(양의 짝). get 을 통해 재면 get 의 필터가 put 의 필터를 가려 mutation 이 GREEN 이 된다(실측) | AC58 |
| T57 | 손으로 심은 `fail` 행이 적중으로 나오지 않고, **같은 파일의 `pass` 행은 정상 적중** + `exit 0`(옛 캐시는 손상이 아니다). 양의 짝이 없으면 "get 이 아무것도 안 내주는" mutation 이 통과한다 | AC59 |
| T58 | `--baseline-detected` — (a) 러너가 집합 밖이면 **양측 `pass` 인데도** `BASELINE_UNRUNNABLE`/`degraded` (심어진 캐시의 정확한 공격 형상) · (b) 같은 입력이 grounded 면 `STILL_GREEN`/`closed`(양의 짝) · (c) 플래그 생략 → exit 2 · (d) 빈 값 → exit 4 · (e) `NONE` → 아무도 grounded 아님 · (f) 멤버십이 **원소**이지 부분문자열이 아님 | AC60 |
| T59 | `error` 가 baseline·head·양측 어디에 있어도 `attribution_status: degraded` · **`error` 없는 같은 형상은 `closed`**(양의 짝 — 없으면 "항상 degraded" mutation 이 통과) · `(pass, error)` 는 여전히 `NEW_REGRESSION` + `confirmed_product_defect: true`(과잉 강화 방지) | AC61 |
| T60 | `resolve-baseline.sh` — (a) feature 브랜치 → `same_as_head: no`/`ahead: 1` · (b) `git update-ref refs/heads/main HEAD` 후 → `same_as_head: yes`(`degraded` 는 여전히 no — 별개 키) · (c) degrade 경로도 6키 전부 · (d) **`main` 위 미커밋 변경에서 `check-review-scope.sh` 가 `changes_exist: yes`/`degraded: no` 유지**(floor 보존 락) | AC62 |
| T61 | `assign` — (a) `from unittest.mock import patch`·`# … not unittest` 주석·`class TestCaseHelpers:` 3축 전부 `unclaimed` · (b) django 상속·다중 상속·`load_tests` 3형태는 여전히 `unittest` claim(양의 짝) · (c) **pytest 감지 레포의 bare `def test_` 는 `pytest` 로 claim**(게이트가 unittest 한정임을 잠금) | AC63 |
| T62 | `assign` ∀-조건 — (a) mixed 파일(진짜 `TestCase` + 모듈-레벨 bare `def test_`) · (b) docstring 예제 안 들여쓴 `class T(unittest.TestCase):` — 둘 다 `unclaimed` (앞 술어는 둘 다 claim 하고 `pass 0` 을 냈다, 실측) | AC63′ (§6.7) |
| T63 | vacuity — (a) 빈 `--expected` → `degraded` · (b) `--expected-adapters 0` + YAML 0개 → `degraded` · (c) **양의 짝**: unit 1개 green → `closed`, 어댑터 1개 all-green → `closed` (양의 짝 없으면 "언제나 degraded" mutation 이 통과) | AC64 |
| T65 | `SILENT_DROP` 이 **단독으로** 인증을 막는다 — (a) `silent_drop > 0` 이면 다른 항목이 전부 정상이어도 `degraded` · (b) 같은 형상에서 drop 만 없애면 `closed`(양의 짝) | AC64′ (§6.7) |
| T70 | **선언 ≠ 실행** — 같은 트리에서 `detect` 는 `go` 를 내주고 `probe` 는 toolchain 없는 PATH 에서 `usable: no`/`reason: runner_missing`/exit 3 을 낸다 · **양의 짝**: 실행 가능한 어댑터는 `usable: yes`/exit 0 (없으면 "항상 no" mutation 이 통과) | AC60′ |
| T71 | `probe` 는 **테스트를 하나도 돌리지 않는다** — 센티널을 쓰는 shell unit 에서 `probe` 후 센티널 부재 · **계측기 확인**: 같은 픽스처에 `run` 을 돌리면 센티널이 생긴다 (없으면 "테스트가 원래 아무것도 안 쓴다" 는 고장이 GREEN 으로 보인다) | AC60′ |
| T72 | **`probe` ↔ `run` 관문 일치 (∀)** — 미가용 **4사유**(`not_detected`·`env_dir_not_ignored`·`setup_failed`·`runner_missing`, **사유 문자열까지 대조**) + 가용 1건 전부에서 두 서브커맨드의 답이 같다. 관문을 한쪽에만 다시 구현하거나 한 단계를 빼면 해당 행이 갈린다 | AC60′ |
| T73 | R4②-a 스텝 4축 — 섹션 윈도우 안에 (a) `probe` 호출 코드 블록 · (b) `usable: yes` 를 **본** 러너만 넣는다는 소비 규칙 · (c) 부재≠통과(fail-closed) 방향 · (d) 무조건성 선언. needle 로 `usable: yes` 자체를 쓰면 출처 진술이 그것을 만족시켜 소비 규칙을 통째로 지워도 GREEN 이다(실측) | AC60′ |
| T74 | **출처 ∀** — `baseline_detected` 와 백틱 `` `detect` `` 를 함께 담은 **모든** 줄이 `probe` 를 말하거나 부정/불충분을 표시한다 + **양의 짝**: 올바른 출처 진술이 실재한다(부정 락만 있으면 통째 삭제도 통과) | AC60′ |
| T66 | R-init 판별자 표가 락돼 있다 (/qg iter-5 TA4) | AC62 정정 (§6.7) |
| T67 | R4 가 판별자를 **자기 스텝 안에서** 구한다 — 상류 값을 물려받지 않는다 (/qg iter-5 SF3) | AC62 정정 (§6.7) |
| T68 | 좁힌 규칙의 **원래(넓은) 형태가 문서 어디에도 인용 가능한 채로 남지 않는다** (∀) | AC62 정정 (§6.7) |
| T69 | 도말(smear)이 인증을 막는다 (/qg iter-5 SF1) | AC60′ |
| T75 | `--granularity` 의 provenance — 소유자에게 물어 대조, 불일치는 exit 4 (/qg iter-5 C5) | AC60′ |
| T76 | R8 PASS 행이 **floor 절 + `verdict_input` 3플래그 + `forced_downgrade`** 를, SKIP 행이 floor disjunct 를 요구 (/qg iter-5 SF5 · floor 축은 iter-6 E3 에서 추가 — 그 전에는 절을 통째로 지워도 GREEN) | AC15 AC17 AC44 AC53 |
| T77 | `FLAKY` 는 귀속 카테고리가 **아니다** — 원장 note 다 (/qg iter-5 SF2) | AC11 |
| T78 | 폴백에서 R4 를 건너뛴다 (/qg iter-5 SR4) | AC62 정정 (§6.7) |
| T79 | `assign` 이 **후행 개행 없는 stdin 의 마지막 후보**를 버리지 않는다 — 개행 유무 두 입력이 같은 unit 집합 (/qg iter-6 C6) | AC46 AC53 |
| T80 | `unittest` 가 모듈-레벨 `async def test_` 를 담은 파일을 claim 하지 않는다 · **양의 짝**: async 없는 동종 파일은 claim 유지 (/qg iter-6 E12 — AC63′ escape (a) 재개방) | AC63′ |
| T81 | 파손된 `package.json` 이 "JS 어댑터 없음" 과 **구분 가능**하다(fail-closed 유지 + 원인 loud) · **양의 짝**: 정상 파일엔 무경고 (/qg iter-6 C4) | AC45 |
| T82 | jest·vitest 판별 불가 시 bulk 강등이 **loud** 하다 · **양의 짝**: 판별 가능하면 무경고 + file 귀속 (/qg iter-6 C3) | AC54 |
| T83 | `plugins/quality-gates/tests/` 하위 `.sh` 전부가 **인덱스 모드** `100755` (∀ + 코퍼스 실재) — 아니면 셸 어댑터가 claim 못 해 self-dogfood 가 구조적으로 인증 불가 (/qg iter-6 D6) | AC53 |
| T84 | poetry 의 in-project venv 를 **단정하지 않고 물어본다**(env·`poetry.toml` 두 축에서 `.venv` 요구) · **양의 짝**: 끄면 요구하지 않는다 (/qg iter-6 C2(b)) | AC41 |
| T85 | **bulk red** 실행이 전 unit 에 실패 코드를 찍는다(도말 서명 = `(status,exit)` 쌍 1종) — 이전엔 red bulk 픽스처가 스위트에 하나도 없어 "항상 `pass 0`" mutation 이 통과했다 (/qg iter-6 E1) | AC12 AC43 AC49 |
| T86 | 그 도말이 **하류에서 `degraded` 로 읽힌다** — `--mode per-unit` 이라 선언해도 (/qg iter-6 E1 + C1) | AC60′ |
| T87 | `async def` 의 **형제 토큰** — pytest 스타일 bare 클래스(`class TestBare:`, `TestCase` 미상속)가 있는 파일을 `unittest` 가 claim 하지 않는다 · **양의 짝 2종**(bare 없는 동종 파일은 claim 유지 · `TestCase` 상속본은 claim). (/qg iter-6 iteration 2 I4 — **이 행 자체가 iter-7 등재분**: 테스트는 iter-6 에 들어갔는데 §8.1 행이 없어 §6.7 이 처벌하는 *등록 없는 등록* 상태로 한 라운드를 넘겼다) | AC63 정정 (§6.7) |
| T88 | **두 축 트리의 분리** — `create-baseline`(merge_base)과 `create-head`(봉인 커밋 `B`)가 서로 다른 경로에 **동시 공존**하고 각자 자기 커밋 내용을 갖는다 · detached · 네임스페이스 · remove 적용. mutation 3축 RED(경로 붕괴 · 형제 파괴 · 커밋 동일화) | AC65 |
| T89 | **HEAD 축이 도는 트리** (오케스트레이션 창 락 4종) — R5b 창 안에서 ① `create-head` 배선 ② `run` 호출 인자가 **전부**(∀) HEAD 축 트리 ③ `create-head` 인자가 봉인 커밋 ④ 재시도 문단이 refresh 후 재호출을 지시. `$runtime_project_dir` 0회 방식은 쓰지 않는다 — 그 변수는 폴백 문단에서 정당하게 등장하므로 **거꾸로 된 이빨**이 된다. mutation 5축 RED | AC65 |
| T90 | **전사 대조** — 집계 `attribution_status` 와 `floor:attribution` 불일치가 **양방향** 으로 red · **양의 짝 2종**(closed/closed · degraded/degraded 는 green — degraded 는 1급 상태이지 실패가 아니다) · 대조 입력 부재·불량 4종(인자 누락 · 파일 부재 · 0개 · 2개) 전부 non-zero | AC66 |
| T91 | **R6→R8 집계 전달 사슬** — R6 이 집계 stdout 을 `$aggregate_yaml` 로 남기고 R8 이 그것을 `--aggregate` 로 넘긴다. 두 지점을 함께 잠근다 — 하나만 잠그면 다른 하나를 지워 사슬을 끊을 수 있다 | AC66 |
| T93 | **`unclaimed` 집행** — unclaimed ≥1 + `verification: closed` 는 red(유출 방향) · **양의 짝 2종**(unclaimed ≥1 + `degraded` 는 green · unclaimed 0 + `closed` 도 green — 과차단 방지) · 3필드 위반 배정 행은 exit 2(fail-closed) · `--assign-rows` 부재·파일부재·값부재 전부 non-zero. mutation 6축 RED(삭제 · 술어반전 · 발화조건확대 · 인자를선택으로 · 후속재대입 · 파싱 fail-open) | AC68 |
| T94 | **R1b→R8 `unclaimed` 집행 사슬** — ⓪ `$assign_rows_file` 이 R-init 창에서 **사용 전에** 정의된다 ① R1b 가 `assign` stdout 을 그 파일로 남긴다 ② R8 의 게이트 호출 **블록 전체**가 두 대조 인자를 함께 넘긴다(∀ — 맞는 호출 뒤에 인자 빠진 두 번째 호출을 덧붙이는 ∃-탈출이 실측으로 통과했다). 블록은 후행 `\` 를 따라 잇는다 — 형제 락 T91 은 `NR+1` 만 봐서 **인자를 3번째 줄로 옮기는 형태 변경에 뚫린다**; 두 락이 서로 다른 축을 덮는다. mutation 6축 RED + **위양성 대조 1축 GREEN**(둘 다 유지한 채 한 줄로 접기 = 정당한 형태) | AC68 · AC69 |
| T89′ | **R5b 실패 라우팅** (오케스트레이션 창 락) — R5b 창 본문이 `create-head` · `unrun` · `폴백하지 않는다` 셋을 함께 담는다. **iter-7 이 AC67 을 대응 행 없이 추가**해 한 라운드를 넘겼고 iter-8 리뷰가 적발했다 — 테스트는 처음부터 있었고 표에만 없었다(§6.7 이 처벌하는 *등록 없는 등록*의 정확한 형태) | AC67 |
| T95 | **종료 코드가 축을 구분한다** — 인자 모양(`--aggregate` 누락 · `--assign-rows` 값 부재) → **2**, 내용(파일 부재 · `attribution_status` 0개 · 배정 3필드 위반 · 비-UTF-8 원장) → **4**, 구조 위반 → 1, 통과 → 0. **non-zero 가 아니라 정확한 코드**를 단언한다 — 동작이 아니라 진단을 재는 락이라 non-zero 로는 이빨이 없다. mutation 3축 RED(내용→2 되돌림 · 모양→4 · `UnicodeDecodeError ⊄ OSError` 가드 제거) | AC68′ |
| T96 | **중간 파일 custody** — ① 뿌리가 `mktemp -d` ② 그 뿌리가 `$project_dir`·`$evidence_dir` 파생이 **아니다**(음의 짝) ③ 여섯 이름이 **전부**(∀) 그 뿌리 파생. 창은 R-init..R1a — R1b 까지 열면 R1b 의 *사용*이 정의로 오인돼 ③ 이 vacuous 해진다. mutation 5축 RED(mktemp 제거 · 뿌리를 project_dir 로 · 뿌리를 evidence_dir 로 · 여섯 중 하나만 탈출 · 정의 블록을 창 밖으로) | AC69 |
| T92 | **create-head 의 봉인 대조** — 샌드박스 부재·`merge_base`·비-봉인 커밋 3종을 거부하고 봉인 커밋 `B` 는 수락(양의 짝). 엄격 동일→접두 매치 변이는 **도달 가능한 입력에서 동작이 같아** GREEN 이며 그 사실을 케이스 주석에 적었다(억지 assert 를 만들지 않는다) | AC65 |

**AC ↔ 검증 완전성.** **AC1–AC69 전부**가 위 T 또는 §8.3의 V에 대응한다.
**이 선언문은 이번이 세 번째 stale 이다** (iter-8 spec review, high). 라운드 3 은
AC38–AC44 를, iter-6 은 `AC1–AC63` 방치를 같은 자리에서 겪었고, 이번엔 AC65–AC69 가
표에 실재하는데 선언문이 AC64 에서 멈춰 있었다. **같은 실패가 세 번 나면 그것은 사람이
기억할 일이 아니라 기계가 셀 일이다** — 프로즈 범위 표기를 유지하되, 구현 시
`§6 의 AC id 집합 ⊆ §8.1∪§8.3 의 인용 집합` 을 세는 검사를 두는 것이 이 반복의 근본
해소다(이 문서 자신에 대한 검사이므로 `V10` 축, 플러그인 테스트 아님).
**AC67 은 stale 선언보다 나빴다** — 표에 행 자체가 없었다(미등록). iter-7 이 AC 를
추가하면서 대응 T 행을 안 만든 것이고, 바로 아래 *"AC 추가 시 대응 T/V 없이 머지하지
않는다"* 를 스스로 어긴 것이다. T89′ 로 등재했다.
**역방향도 이제 등재한다 (/qg iter-6 E6):** 앞 버전은 AC→T 방향만 단속했고 T→표 방향은
무단속이라 **테스트가 인용하는 T-id 16개가 이 표에 없었다**(T66–T69 · T75–T78 · T79–T86).
실제 커버리지는 있었고 미래 리뷰어가 읽는 문서에서만 보이지 않았다 — 그 자체가 이 문서가
스스로에게 부과한 규칙의 위반이다. 자동 테스트가 없는 것은 **AC20**(`V4` — `AskUserQuestion` 발화 여부는 대화형이라 자동화하지 않는다)과 **AC61′·AC62′·AC63′ 의 *정정 완전성* 축**(`V9` — 이 문서 자신에 대한 검사라 플러그인 테스트가 담당할 수 없다. 앞 버전은 이것을 `T64` 라는 **구현되지 않은 자동 테스트**로 적어 이 선언문을 거짓으로 만들었다 — /qg iter-5 TA1) 둘이다. 이 매핑 자체를 구현 시 표로 유지하고, **AC 추가 시 대응 T/V 없이 머지하지 않는다.** (라운드 3에서 이 선언문이 AC38–AC44를 반영하지 않은 채 stale했다 — 선언문도 갱신 대상이다.)

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
| **M29** | `--baseline-detected` 를 선택 인자로 되돌림 / grounded 를 상수 참으로 / 축 강등(`b_axis = "U"`) 삭제 / **극성 반전**(`if not runner_grounded` → `if runner_grounded`) / 멤버십을 부분문자열로 | T58 (5축 각각) |
| **M30** | degraded 식에서 `error_axis_seen` 삭제 / **역방향** `error_axis_seen` 을 항상 참으로(과잉 강화) / 빈 `--baseline-detected` 허용 | T59·T58 — 양방향이라야 "언제나 degraded" 가 막힌다 |
| **M31** | `same_as_head` **극성 반전**(`==` → `!=`) / 상수 `no` / degrade 경로 키 삭제 / `ahead` 상수 / **`check-review-scope.sh` 가 `same_as_head` 를 읽어 degrade** | T60 (마지막 것이 floor 보존 락의 이빨) |
| **M32** | `unittest_can_judge` 를 옛 부분문자열 술어로 복원 / 항상 판정 불가로(양의 짝 파괴) / `[[ "$claimed" == "unittest" ]] &&` 한정 삭제 | T61 (3축 각각) |
| **M34** | `probe` 를 `detect` 의 별칭으로 재구현 / `usable` 을 상수 yes / 상수 no(양의 짝 파괴) / `probe` 가 테스트를 실행 / 공유 관문에서 `runner_available` 삭제 / `dir_is_ignored` 단계 무력화 / `probe` arm 통째 삭제 | T70·T71·T72 (7/7 RED 실측 — arm 삭제는 exit 2 로 떨어져 "부재를 통과로 읽지 않음"도 함께 잰다) |
| **M35** | R4②-a 의 probe 호출 코드 블록 삭제(산문만 남김) / 소비 규칙 문단 제거 / 무조건성 선언을 "미적중분이 없을 때만" 조건부 최적화로 되돌림(SR1 재도입) / ②-a 앵커 파괴 / 출처 진술 2곳을 각각 옛 `detect` 형태로 revert / **새 오지정 줄 삽입**(∃ 아닌 ∀ 인지) / 올바른 출처 진술 삭제(양의 짝) / SKILL.md 통째 삭제 | T73·T74 (9/9 RED 실측. 첫 판에서 `usable: yes` needle 이 body-unique 하지 않아 "소비 규칙 제거"가 GREEN 이었다 — needle 교체 후 RED) |
| **M33** | vacuity 3축(`not expected` 삭제 / **극성 반전** `not expected`→`expected` / aggregate `if not adapters` 삭제) + ∀-조건 3축(음성 조건 삭제 / **극성 반전** `return 1`→`return 0` / `^def`→`^[[:space:]]*def` 로 완화) | T63·T62 (6/6 RED 실측) |
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
| **M24** | `unclaimed`를 `gap: closed`로 되돌려 PASS 허용 | T51 — **라운드 4 block 그 자체**. `verdict != PASS`가 아니라 `== SKIP_WITH_EVIDENCE` 정확 일치로 써야 FAIL로 새는 것도 잡힌다 |
| **M25** | `--aggregate`가 입력 개수 불일치에서 남은 것만 합침 | T53 — 결과가 그럴듯해서 **개수 대조**로만 잡힌다 |
| **M26** | `assign`을 건너뛰고 오케스트레이터가 unit을 직접 만듦 | T50 — 동종(file-granularity) 레포에서는 결과가 같아 **go 픽스처**로만 잡힌다 |
| **M27** | `put`의 허용 상태 집합에 `error`를 되돌림 | T56 — 관측을 캐시 파일로 해야 잡힌다. get 출력으로 재면 get 필터가 가려 GREEN |
| **M28** | `get`의 적중 필터에 `fail`을 되돌림 | T57 |

> **M6·M8·M12가 이 계획의 취약 지점이다.** 셋 다 "결과가 같아 보이는" mutation이라 결과값만 보는 assert로는 GREEN이 나온다 — M6은 **호출 카운터**(+ 유한 종료 stub), M8은 **body-unique + 섹션 윈도우**, M12는 **호출 위치**가 필요하다. 구현 시 이 셋을 **먼저** 쓴다.
>
> **M11은 방향이 반대라 특히 주의한다.** "PASS를 SKIP으로 바꾸는" mutation은 안전 방향이라 놓쳐도 덜 아프지만, M11이 잡는 것은 그 **역방향**(SKIP이어야 할 것이 PASS가 됨)이다. 테스트가 `verdict != PASS`만 assert하면 verdict가 `FAIL`로 바뀌어도 GREEN이므로, `verdict == SKIP_WITH_EVIDENCE` **정확 일치**로 쓴다.

### 8.3 수동 검증

| id | 시나리오 | 왜 수동인가 |
|---|---|---|
| **V1** | devbrew 자신에 `/qg runtime` self-dogfood — **실측상 `unittest`(50개) + `shell`(130개) 두 어댑터가 감지되어 둘 다 실행되는지**, 그리고 어느 쪽도 조용히 누락되지 않는지 | 실제 폴리글랏 레포의 전체 파이프라인 동작은 픽스처로 근사만 가능(T42가 감지·실행 계약은 이미 커버) |
| **V2** | 기준선 캐시 적중 — 같은 브랜치에서 `/qg runtime` 2회. 두 번째 실행에서 **`pass`·`absent` 유닛은 기준선을 안 돌리고, 기준선 red 유닛만 재검증되는지**. 전량 스킵을 기대하면 안 된다 — stale red 를 건드리는 diff 에서는 부분 재실행이 정상이다 | 캐시 수명이 세션을 넘음 |
| **V3** | stale red 위에서의 첫 실행 — devbrew의 알려진 pre-existing red가 `PRE_EXISTING`으로 찍히고 FAIL을 안 만드는지 | 실제 red 목록이 환경 의존 |
| **V4** | 갭 게이트 zero-click — 생략 0인 diff에서 질문이 안 뜨는지 | AskUserQuestion 발화는 대화형 |
| **V5** | 갭 게이트 발화 — 자동화 불가 플로우가 있는 diff에서 질문이 뜨고 redirect가 되는지 | 위와 동일 |
| **V6** | Node 레포에서 기준선 deps 설치 — 실제 비용과 실패율 (§11 ②의 미실측 항목) | 외부 레지스트리 의존 |
| **V7** | `worktrees` 생존 — 실제 `/qg branch` 워크트리를 만들고 TTL 초과 후 GC를 돌려 생존 확인 | 실제 worktree + 시계 조작 |
| **V8** | 계획 산문의 가독성 — LD4 "전문용어 나열은 산출물 실패" 판정 | 사람만 판정 가능 |
| **V9** | **정정의 완전성** — §6.6 의 AC61·AC62·AC63 정의문에 §6.7 전방 포인터가 있고, §8.1 완전성 선언문이 최신 AC 번호를 담는지 (삭제된 규칙이 인용 가능한 형태로 살아남으면 삭제 전보다 나쁘다) | **이 문서에 대한 검사이지 플러그인에 대한 검사가 아니다.** 앞 버전은 이것을 §8.1 에 `T64` 로 적었지만 **어떤 테스트도 구현하지 않았다** — 자동 T 를 자칭한 수동 항목이라 §8.1 의 완전성 선언문을 거짓으로 만들었다(/qg iter-5 TA1). 플러그인 테스트가 리포 문서를 읽게 만드는 것은 레이어 위반이고 문서 편집마다 stale-red 를 낸다 |

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

> **등급 어휘 (라운드 7 spec review, U4).** 이 절과 §6.7의 잔여 목록은 **같은 사실에 서로 다른 어휘를 써 왔다** — §11은 "완화 가능한 갭", §6.7은 "merge-blocking 잔여". 두 리뷰어가 독립적으로 같은 충돌을 지적했으므로 어휘를 여기서 고정한다:
>
> - **갭(gap)** — 이 설계가 *의도적으로 답하지 않기로 한 것*, 또는 측정 전이라 아직 등급을 매길 수 없는 것. 병합을 막지 않는다.
> - **잔여 결함(residual)** — 이 설계가 답한다고 주장하는 범위 안에서 *구현이 실제로 뚫려 있는* 것. **병합을 막는다.** §6.7의 16항목이 전부 여기 속한다.
>
> 한 항목이 두 등급에 걸치면 **잔여 결함이 이긴다**(더 엄한 쪽). 아래에서 그런 항목은 명시적으로 표시한다.

1. **`PRE_EXISTING`의 사후 처리 경로가 없다.** 이 게이트는 pre-existing red를 *보고*할 뿐 고치라고 하지 않는다(Non-goal: 버그 수정 루프). 레포가 stale red를 계속 쌓으면 보고서가 길어지기만 한다. 축적 추이를 볼 장치는 이번 범위 밖.
2. **기준선 deps 설치의 실제 비용·실패율이 미실측이다.** §5.4의 캐시가 상각을 가정하지만 Node 대형 레포에서 첫 설치가 얼마나 걸리는지, 사설 레지스트리에서 얼마나 자주 실패하는지는 V6에서 처음 잰다. 실패율이 높으면 `BASELINE_UNRUNNABLE` degrade가 흔해지고 OQ1의 답이 실질적으로 기각안 2번으로 미끄러진다 — **그때 이 문서를 다시 열어야 한다.**
3. **OQ3(과선택 수렴)에 실증이 없다.** brief의 프로버도 *"추론적 확장, 직접 실증 아님"* 이라 자인했다. §5.8은 실패 양식을 **보이게** 만들 뿐 막지 못한다.
4. **의존 그래프 기반 영향 판정이 없다.** 보조 입력은 `compute-test-scope-candidates.sh`의 이름 매칭 휴리스틱이 전부다 — Python/JS/TS 외 언어는 변경된 테스트 파일 자체만 잡힌다. pytest-testmon 같은 coverage 기반 매핑은 계측 전제라 범용 플러그인에 넣지 않았다.
5. **부팅/플로우 층은 차등화하지 않는다.** 기준선에서 브라우저 플로우를 다시 돌리는 것은 비용·비결정성 모두에서 감당 불가다. 따라서 *"이 UI 깨짐이 원래 있었나"* 는 이 설계가 답하지 못한다 — 테스트 러너 표면에서만 귀속이 나온다.
6. **bulk-only 러너의 "양쪽 red" 빈도가 미실측이다.** cargo/make 레포에서 이 상태가 흔하면 그 레포들은 사실상 늘 `SKIP_WITH_EVIDENCE`를 받는다.
7. **`test-scope-validator`의 `ac_coverage`는 여전히 advisory다.** 이 spec은 그 출력을 `verification` 차원의 입력으로 소비하지만 블로킹으로 승격하지 않는다 (v2.1.0 계약 유지).
8. **LD4의 "쉽게"는 기계 검증 밖이다.** Goal 5의 사람 판정 층(V8)은 통과 기준이 사람이다. 어휘 금지 목록·최대 길이 같은 기계 임계는 LD7이 경계한 천장이 되므로 세우지 않았다 — 대신 필드 존재/포맷만 기계로 잡는다(AC19). **"필드는 다 있는데 읽히지 않는 계획"은 자동으로 잡히지 않는다.**
9. **아티팩트 억제가 불가능한 러너가 있다.** `make`·`npm-script`는 내부 명령을 우리가 모르므로 `.pytest_cache` 같은 산출물을 억제할 수단이 없다. 대상 레포의 `.gitignore`가 그것을 덮지 않으면 mutation-guard가 `disallowed_new_files`로 잡아 **거짓 FAIL**을 낸다.
   **등급 정정 (라운드 7 spec review, U4).** 이 항목은 §6.7의 **S4와 같은 메커니즘**이다 — 게이트 자신의 부작용이 mutation-guard에 잡혀 거짓 terminal FAIL을 낸다. §6.7은 이것을 merge-blocking 잔여로, 이 절은 "측정 대기 중인 완화 가능 갭"으로 적어 **같은 사실에 두 등급을 부여했다**(Claude·codex 독립 지적). 위 어휘 규칙에 따라 **잔여 결함(병합 차단)이 이긴다.** T41은 *빈도*를 재는 장치이지 이 실패를 막는 장치가 아니다 — 빈도 측정과 봉쇄를 같은 칸에 적은 것이 등급 혼선의 출처였다.

   **✅ 해소됨 (`/qg` iter-7 — ⑬과 같은 수정 하나로).** R5b가 `create-head`가 만든 **자기 트리**로 옮겨가면서 게이트의 테스트 아티팩트는 더 이상 `sandbox_dir`에 떨어지지 않는다. mutation-guard는 그 트리를 보지 않으므로 **억제 불가능한 러너가 있어도 거짓 FAIL이 생기지 않는다.** 봉쇄 지점이 "모든 러너의 아티팩트를 억제한다"(불가능)에서 "검사 대상 트리에서 게이트 자신을 뺀다"(구조적)로 옮겨간 것이다. guard의 권한은 verifier 변경에 대해 그대로다 — Law 2 표면 무변경. 검증: T88 · 오케스트레이션 창 락(R5b의 `run` 인자 ∀). **T41은 유효한 채로 남는다** — 이제 그것이 재는 것은 거짓 FAIL의 빈도가 아니라 일회용 트리의 청결도이며, 그 사실을 §8.1에 적었다.

   **측정 경로 정정 (라운드 2 Finding C).** 초안은 *"첫 dogfood(V1)에서 실측"* 이라 썼지만 **V1은 이것을 측정할 수 없다** — V1은 devbrew 자신을 대상으로 하고 devbrew에는 Makefile 기반 테스트도 npm-script 테스트도 없다. 측정은 **T41**(픽스처 기반: `Makefile`/`package.json` 스텁 레포에서 `run` 실행 후 비-ignored 신규 파일 발생 여부)이 담당한다. 실측 결과가 "흔함"이면 guard 예외 목록이 아니라 **어댑터별 작업 디렉토리 격리**로 푼다 — guard를 느슨하게 하는 방향은 금지다(Law 2 표면).
10. **baseline 캐시는 GC되지 않는다.** merge_base마다 파일이 하나씩 쌓이고 정리는 `/cancel-qg --all`에 위임했다. 장수 브랜치·잦은 rebase 환경에서 파일 수가 늘어나는데, 각 파일이 수 KB라 실질 부담은 아니지만 **자동 정리 경로가 없다**는 사실은 남는다.
11. **러너 어댑터 9종은 초기 집합이며 커버리지 주장이 아니다.** Java/Gradle·Ruby/RSpec·PHP/PHPUnit·.NET 등은 감지 0개로 떨어져 그 레포에서는 이 게이트가 floor를 제공하지 못한다. 확장은 case 절 추가지만, **미지원 레포에서 이 게이트가 무엇을 못 하는지가 사용자에게 보여야** 한다(§5.10의 loud 경로).
12. **bulk 어댑터는 커버리지를 보장하지 못한다.** `cargo test`가 `--workspace` 없이 sibling crate를 건너뛰는 식의 함정이 발동하면 영향분이 조용히 미실행되는데 exit 0 + green이라 신호가 없다. 명령 내부를 통제하지 않으므로 **검증 불가**이며, 대응은 봉쇄가 아니라 **공시**다(AC49). 즉 cargo/make/npm-script 레포에서 이 게이트의 주장은 "영향분을 확인했다"가 아니라 "러너 전체를 돌렸다"로 약해진다.
13. **verifier의 부팅용 setup이 만드는 환경 비대칭은 기계로 안 잡힌다.** AC41은 `setup_cmd` 채널만 결정론적으로 맞춘다. R5a에서 verifier가 앱 부팅을 위해 설치한 것이 우연히 테스트 결과에 영향을 주면, 그것은 git-외부 상태라 mutation-guard가 못 보고 `gap` 기재는 verifier 자기보고에 의존한다 — 불변식 ②가 *결과값*에서 없앤 self-report 신뢰가 *실행 환경* 축에는 남아 있다. 완화: R5b는 R5a와 같은 샌드박스에서 돌므로 비대칭이 발생하면 **양측 차등에 나타난다**(기준선에는 그 setup이 없으므로) — 즉 조용한 오귀속이 아니라 시끄러운 불일치로 드러날 가능성이 높다. 그래도 보장은 아니다.

   **완화 주장 약화 (라운드 7, codex 단독 high).** 위 "시끄럽게 드러난다"는 완화는 **차등이 신호로 읽힌다는 전제**에 기대는데, 그 전제가 스스로를 약화시킨다 — R5a의 setup이 만든 차이는 `NEW_REGRESSION`과 **구별 불가능한 모양**으로 나타난다. 즉 이 완화는 오귀속을 *조용한 것에서 시끄러운 것으로* 바꿀 뿐, **어느 쪽이 원인인지는 여전히 verifier 자기보고로만 갈린다.** codex의 표현대로: 권위 있는 테스트가 도는 바로 그 HEAD 샌드박스를 verifier가 비구조적으로 변형할 수 있는 한, 이 설계가 파는 "같은 선택을 두 번 돌려 짝짓는다"는 **두 축이 같은 환경이라는 전제 위에서만 성립**한다. 제대로 된 해소는 부팅과 테스트 실행의 환경 분리, 또는 양축에 동일 재생되는 결정론적 setup 매니페스트다 — 둘 다 이번 범위 밖이므로 **갭이 아니라 잔여 결함으로 등재**한다.

   **✅ 해소됨 (`/qg` iter-7 — codex가 지정한 두 정답 중 첫째, "부팅과 테스트 실행의 환경 분리").** `qg-worktree.sh create-head <B>`가 봉인 커밋에 detached된 **두 번째 일회용 워크트리**를 만들고 R5b가 거기서 돈다. 이제 양축이 대칭이다 — 기준선은 `create-baseline`이 merge_base에, HEAD는 `create-head`가 `B`에 만든 커밋 detached 트리이고, **두 트리에서 실행되는 것은 어댑터의 `setup_cmd`뿐**이다. verifier의 부팅 setup은 어느 축에도 닿지 않으므로 "두 축이 같은 환경"이 전제가 아니라 **구조**가 됐고, 완화가 기대던 자기보고 의존이 사라졌다.

   **함께 닫힌 것:** ⑨(= §6.7 S4) — R7의 guard가 검사하는 트리에서 게이트 자신의 테스트 실행이 빠졌다. 한 수정이 두 항목을 닫는 이유는 둘이 *같은 뿌리*(권위 있는 HEAD 축이 감시 대상 트리 안에서 돈다)였기 때문이다.

   **새로 연 것과 그 봉쇄:** 재시도(NEEDS_RESOLUTION → retry)는 **새 `B`**를 만든다. R5b가 refresh된 `baseline_sha`로 `create-head`를 다시 부르지 않으면 HEAD 축이 *고쳐지기 전 코드*에 붙는데, 트리도 행도 정상이라 **어떤 degrade 신호도 서지 않는다.** SKILL.md 재시도 문단에 명시했고 오케스트레이션 락이 그 지시의 존재를 잠근다.

   **⚠️ 이 수정 자체가 리뷰에서 3 CRITICAL 을 낳았다 (iter-7 Review 게이트, 리뷰어 5 + adversarial).** 구조 방향은 맞았지만 계약이 불완전했다: **(a)** R5b 끝에서 트리를 폐기하면서 *"R6 은 이 트리를 필요로 하지 않는다"* 고 적었는데 **다음 스텝이 그 문장을 반증한다** — R6 의 flaky 규칙이 `NEW_REGRESSION` 후보를 HEAD 에서 1회 재실행하고 그것을 authoritative 로 선언한다(리뷰어 4명 독립 수렴). 도달 가능한 결말 넷 중 둘이 fail-open 이었고 그중 하나가 **이 항목이 닫았다고 선언한 §11 ⑬ 을 flaky 경로로 되여는 것**이었다. **(b)** `create-head` 가 sha 를 무검증으로 받아, 형제 `create-baseline "$merge_base"` 와 인자 모양이 같은 탓에 오값 하나로 HEAD 축이 기준선 복사본이 되고 **degrade 신호 없이 PASS** 가 났다 — 내가 §11 ⑰ 로 등재한 *선언된 자유 변수* 의 더 나쁜 변종(부재가 아니라 오값이라 fail-closed 조차 아님). **(c)** R5b 에만 exit 라우팅이 없어 관측 실패가 "고른 것이 사라졌다" 로 오보됐고, verifier 가 그 경로를 선점해 실패를 결정론적으로 유발할 수 있었다.

   **닫은 방법:** (a) 트리 수명을 R6 뒤로 옮기고 flaky 재실행에 `$head_tree_dir` 를 리터럴로 명시 · ∀ 락의 창을 R5b..**R7** 로 넓혀 R6 의 재실행이 감사 대상에 들어오게 함(앞 락은 R5b..R6 이라 **자기가 지키려던 결함을 볼 수 없는 자리**에 있었다). (b) `create-head` 가 이 세션 샌드박스의 봉인 커밋과 **대조**하고 다르면 die — *도출*이 아니라 *대조*인 이유는 verifier 가 그 샌드박스에서 Write·Bash 를 쥐고 `B` 위에 커밋할 수 있어 도출은 신뢰 앵커를 피검자에게 넘기기 때문이다(digest 로 봉인된 스냅샷은 7필드에 baseline SHA 가 없어 사용 불가). 대조는 **거부만 하고 선택은 못 한다.** (c) R6·R7 과 같은 모양의 실패 라우팅 표를 R5b 에 추가하고 두 폴백 트리를 명시 금지. 검증: T92 + 오케스트레이션 락 6종, mutation 9축 RED.

   **함께 드러난 것:** 이 수정을 지키려고 내가 단 락 3개가 전부 뚫려 있었다 — ∃(두 번째 호출을 덧붙이면 통과) · 토큰 grep(지시문을 반전해도 통과) · 비대칭 needle(호출을 한 줄로 접으면 통과). 셋 다 **내 mutation 이 '삭제' 축만 흔들었기 때문**이고, 리뷰어는 추가·반전·형태변경으로 통과시켰다. 세 락 모두 파일의 기존 관례(∀ over call-site)로 변환했다.

   **치르는 대가:** 테스트가 진짜로 부팅 setup을 요구하는 레포에서 HEAD 축이 pristine 트리에서 실패한다. §5.2의 "치르는 대가" 문단에 근거를 적었다 — 요약하면 **손실이 아니라 정직화**다(기준선 축은 원래부터 verifier setup이 없었으므로 옛 배치는 거짓 차등을 생산하고 있었다). 검증: T88 · 오케스트레이션 창 락 4종(배선 · `run` 인자 ∀ · `create-head` 인자 · 재시도 지시), mutation 5축 RED.
14. **§5.3의 "빈 스코프 fail-safe"에는 집행자가 없다.** (라운드 6·7 spec review, U2 — **이월 2라운드째**.) 그 규칙은 §5.3에서 스스로 *"결정론 코드 없이 프로즈로"* 라고 선언하는데, 그 자인이 **어느 갭 목록에도 등재되지 않아** 왔다 — §11에도 §6.7의 16항목에도 없었다. 스스로 인정한 갭이 갭 목록에 없으면 다음 독자에게는 **존재하지 않는 갭**이다. 이제 등재한다. 실효 범위: 후보 목록이 비었을 때 "그 자체를 `gap` 차원에 기록하고 폭을 넓힌다"를 강제하는 것은 이 산문 한 줄뿐이고, 모델이 그것을 건너뛰어도 **막는 코드가 없다.** AC64가 *판정 0건 → `degraded`* 를 결정론으로 닫았으므로 최악(테스트 0건 실행 + PASS)은 봉쇄돼 있으나, *스코프는 비었는데 다른 어댑터가 green이라 인증되는* 중간 경로는 열려 있다. 등급: **잔여 결함**(이 설계가 답한다고 주장하는 범위 안).
15. **T37은 아무것도 재지 않는다 (동어반복).** (`/qg` iter-6 E8. §12가 T37/T46을 "전부
    §11/§6.7 잔여로 이월"이라 적었으나 **두 id 어느 쪽도 어느 목록에도 등재된 적이 없다** —
    §6.7이 처벌한 바로 그 클래스(등록 없는 등록 주장)를 이 문서가 스스로 저질렀다. 이제
    실제로 등재한다.) `case_setup_cmd_identical_both_sides`는 구조적으로 동일한 두 트리를
    만들고 `detect`가 양쪽에 같은 `setup_cmd`를 반환하는지 본다. `detect`는 트리 내용의
    **결정론적 순수함수**라 동일 입력 두 호출이 불일치할 수 없다 — 이 assert는 실패할 수
    없다. M17의 실제 표적(HEAD 측에서만 다른 `setup_cmd`)은 `detect` 안이 아니라
    **오케스트레이터의 두 invocation** 에 산다. 속성 자체는 구조적으로 성립하므로(양측이
    setup 실행을 소유한 같은 `run`을 부른다) 살아 있는 구멍은 아니고 등급은 **갭** — 다만
    *잠겨 있다고 믿고 있던 것이 잠겨 있지 않다*가 위험이다. 해소: 같은 파일이 이미 쓰는
    PATH-스텁 로깅으로 실제 invocation을 재거나, 재지 못함을 인정하고 삭제.
16. **T46은 bulk 커버리지 공시를 *존재*로만 잰다.** (`/qg` iter-6 — 위 이월 주장의 나머지
    절반.) AC49의 요구는 "커버리지 미보장이 공시된다"인데 그 문구가 **어떤 조건에서**
    나오는지는 잠겨 있지 않다. 실제 bulk 실행과 공시를 짝짓는 검사가 없으므로 공시가
    상수처럼 늘 붙어도, 반대로 조건이 좁아져도 표면상 통과한다. 등급: **갭**.
    (`/qg` iter-6의 T85/T86이 bulk **red** 경로를 처음으로 실행 커버했으므로 — 그전에는
    red bulk 픽스처가 스위트에 하나도 없었다 — 여기에 이어 붙일 자리가 생겼다.)
17. **실행 mode 의 provenance 는 검증되지 않는다.** (`/qg` iter-6 iteration 2 — 리뷰어
    3명(codex · security-reviewer · code-reviewer)이 독립 수렴.) `--baseline-mode` /
    `--head-mode` 는 각 `run` 호출이 실제로 무엇이었는지를 오케스트레이터가 **선언**하는
    값이고, 그 값이 실제 실행에서 왔는지는 아무도 검사하지 않는다 — 형제
    `--baseline-detected`(§6.7 "AC60 값 provenance 미잠금")와 **같은 등급의 잔여**다.
    잘못 선언하면 도말이 `PRE_EXISTING` 으로 접혀 `closed` → PASS 가 된다.
    **이번 라운드에 좁힌 것:** 앞선 판본은 인자가 하나(`--mode`)여서, 양측 mode 가 다를 때
    *"배치였던 쪽을 기준으로 `bulk` 를 넘긴다"* 는 규칙으로 두 독립 호출을 **한 토큰에
    접었다.** 그 접기의 유일한 집행자가 그 토큰 자신이었고, 특히 위험한 조합(기준선 bulk ×
    HEAD per-unit)은 R4 가 기준선을 언제나 `run … bulk` 로 돌리므로 **기본 경로**였다.
    축을 쪼개 그 손실 변환을 없앴다.
    **철회한 것:** 데이터에서 도말을 추론하는 서명(present unit ≥2 인데 `(status, exit)`
    쌍이 1종). (a) head 축만 봐서 위험한 축을 못 봤고, (b) 정직한 per-unit 실행이 "고른
    unit 전부 양측 red" 일 때를 degrade 시켜 §5.5 가 *"stale red 가 첫 실행부터 게이트를
    막으면 이 설계는 쓸 수 없다"* 를 이유로 통과시키기로 한 결정을 되돌렸다. 순감이었다.
    **닫는 방법과 그 장애물:** `run` 이 자기 실행을 증거 파일로 남기고 스크립트가 그것을
    읽으면 닫힌다(`--baseline-detected` 도 같은 메커니즘으로 함께 닫힌다 — 한 번만 만들면
    된다). 장애물은 **기준선이 캐시 적중으로 올 때 그 실행이 아예 없다**는 것이다. 캐시
    항목에 mode 를 함께 저장하는 설계가 필요하고 이번 범위 밖이다. 등급: **잔여 결함**.

18. **✅ 해소됨 — 기계 집계값과 원장 전사값이 대조되지 않았다.** (라운드 6·7 의 **U3**.
    §12 가 "이월" 이라 적었으나 **어느 목록에도 등재된 적이 없었다** — iter-6 이 그
    미등재 자체를 공시만 했고, 이제 실제로 등재하며 같은 라운드에 닫는다.)
    R8 은 R6 이 낸 `attribution_status` 를 `floor:attribution` 의 status 로 **모델이
    옮겨 적게** 하는데, 옮겨 적은 값이 기계값과 같은지는 아무도 보지 않았다.
    `degraded` 를 `closed` 로 옮기면 floor 5차원이 전부 `closed` 가 되어 **PASS 행을
    그대로 만족시킨다** — 불변식 ②가 결과값 축에서 없앤 "모델 요약이 판정을 결정" 이
    *전사* 축으로 재입장한 자리다.
    **해소:** `check_qa_ledger.py --aggregate <집계 YAML>`(필수 인자)가 두 값을 대조하고
    다르면 non-zero. 의미 판정이 아니라 **두 필드의 일치**를 보는 구조 검사이므로 이
    스크립트의 기존 계약("의미 판정은 하지 않는다")을 넘지 않는다. R6 은 집계 stdout 을
    `$aggregate_yaml` 로 남기고 R8 이 그것을 넘긴다 — 두 지점을 함께 잠근다(하나만
    잠그면 다른 하나를 지워 사슬을 끊을 수 있다). 검증: T90(양방향 불일치 red + 양의 짝
    2종) · T91(R6→R8 전달 사슬), mutation 5축 RED.
    **닫지 못한 이웃 (과장하지 않는다):** 이 대조는 *전사* 축만 닫는다. 넘긴 파일이 정말
    그 실행의 집계 출력인지(**custody**)는 여전히 검사하지 않으며 §6.7 S1 과 같은 축으로
    열려 있다. `verdict_input` 3플래그는 원장에 실리지 않아 이 경로로 대조할 대상이 없다.
19. **`qg-gc.py` 수정이 이 브랜치의 범위를 넘는다.** (라운드 7 codex, **U5** — U3 와
    같은 상태였다: §12 의 한 문장 밖 어디에도 없었다. 이제 등재한다.)
    §5.11 이 고치는 것(`SESSION_PATTERN` 이 `worktrees`·`baseline-cache` 형제 디렉토리를
    매치해 살아 있는 트리를 지운다)은 **이 기능이 만든 결함이 아니라 기존 결함**이고,
    이 브랜치는 그것을 함께 고친다. 그 자체가 나쁜 것은 아니지만 — 신규 `baseline-cache`
    가 그 버그의 사정권에 들어가므로 **이 기능이 실제로 그것을 건드린다** — 무관한 수정이
    기능 PR 에 얹히면 리뷰 표면이 커지고 되돌리기 단위가 뭉친다.
    **정직한 상태 표기:** codex 의 원문 표현은 어느 원장에도 남지 않았고 위 서술은 §5.11
    과 라운드 7 기록에서 **재구성한 것**이다 — 인용이 아니다. 등급은 **갭**(병합을 막지
    않는다): 결함이 아니라 *범위 결정*이며, 결정은 둘 중 하나다 — (a) 별도 PR 로 분리,
    (b) 유지하되 "신규 캐시가 이 버그의 사정권에 들어가므로 이 기능의 일부" 라는 근거를
    §5.11 에 명시. **이 라운드에서 (b) 쪽 근거가 하나 더 생겼다**: ⑬ 이 만든 `head-*`
    워크트리도 같은 `worktrees/` 디렉토리에 살아 GC 버그의 사정권이다.
20. **일회용 트리의 누수 지점이 하나에서 둘로 늘었다.** (`/qg` iter-7 — ⑬ 수정의
    부작용이며, 숨기지 않고 등재한다.) `create-baseline` 이 만든 `base-*` 는 R4③ 이,
    `create-head` 가 만든 `head-*` 는 **R6 끝**이 지운다(iter-7 의 F1 수정 전에는 R5b 끝이었다 — 그 배치가 R6 의 flaky 재실행을 불가능하게 만들었다). 두 경우 모두 **그 사이에서 실행이
    죽으면 트리가 남는다** — `cancel-qg-core.sh` 의 정리는 `pipeline.md` 의
    `worktree_path`(= `/qg branch <name>` 트리)만 보고 이 둘을 열거하지 않는다.

    **정정 (iter-7 리뷰 — 아래 완화 주장은 거짓이었다).** *"다음 실행이 idempotent 하게 갈아엎는다"* 는 재현으로 반증됐다: `make_detached_worktree` 는 **non-force** `git worktree remove` 만 시도하고 거부되면 die 하는데, 누수된 축 트리의 내용물은 정의상 테스트 산출물이고 §11 ⑨ 가 적었듯 `make`·`npm-script` 계열은 그것을 억제할 수단이 없어 **비-ignored 로 남을 수 있다** — 그 경우가 정확히 non-force 가 거부하는 경우다. 즉 자동 복구가 아니라 loud die 이고, 경로가 고정이라 **그 세션에서는 HEAD 축을 다시 만들 수 없다**(수동 제거 또는 새 세션이 유일한 복구). 데이터 손실은 없지만 '디스크 점유' 등급은 과소평가였다. **추가로 iter-7 의 F1 수정이 HEAD 축 트리 수명을 R5b 끝 → R6 끝으로 늘려 누수 창이 그만큼 넓어졌다.** `--force` 로 바꾸는 것은 금지 — 그 non-force 거부가 사용자의 더러운 워크트리를 지키는 유일한 가드다(adversarial 판정).
    완화: 두 서브커맨드 모두 **경로가 `<prefix>-<sid8>` 로 고정**돼 있어 다음 실행이
    idempotent 하게 갈아엎고, 사용자의 미커밋 작업이 그 경로에 있으면 non-force
    `git worktree remove` 가 거부해 파괴하지 않는다. 즉 누수는 **디스크 점유**이지 데이터
    손실이 아니다 — **위 정정이 이 문장을 뒤집는다. 자동 복구는 보장되지 않는다.**
    등급: **갭**(데이터 손실은 없으나 세션이 잠길 수 있다). 제대로 닫으려면 정리 경로가
    네임스페이스를 열거해야 하고, 그것은 §11 ⑩(baseline 캐시 GC 없음)과 같은 자리에서
    함께 설계할 일이다.

21. **bulk green 이 테스트 0건으로 인증한다.** (`/qg` iter-7, silent-failure-hunter
    CRITICAL — 재현 2변종.) *"bulk green 은 전 unit 이 통과했다는 뜻"* 이라는 전제가
    **거짓**이다 — bulk green 은 *배치 명령이 exit 0 을 냈다* 는 뜻일 뿐이다.
    변종 A(bulk 입도): no-op `make test:` → `BULK pass 0 exit=0` → 양축 동일 →
    `STILL_GREEN` → R8 PASS 행 충족. 변종 B(**파일 입도, 더 흔함**): SKILL 은 모든
    어댑터를 `bulk` 로 먼저 돌리고 *"bulk 가 green 이면 per-unit 재실행을 하지 않는다"*
    고 지시하는데, `pytest -q <테스트있음> <수집0건>` 은 exit 0 이고 `<수집0건>` 단독만
    exit 5 다 — per-unit 이면 `error → degraded`(fail-closed)로 갈 것이 bulk 에서는
    `pass` 로 도말된다. **최적화 자체가 은폐 수단이다.** 변종 A 는 §11 ⑫(공시하되 봉쇄
    안 함)의 기등재 범위지만 **변종 B 는 아니다** — ⑫ 는 bulk *어댑터* 를 말하고 이것은
    파일 입도 어댑터의 실행 *mode* 다. 닫으려면 "bulk green 은 어댑터가 ≥1건 실행했음을
    증명할 수 있을 때만 증거" 라는 설계 결정이 필요하고 `probe` 는 그것을 세우지 않는다.
    등급: **잔여 결함**.
22. **bulk 도말이 인자 순서만으로 확증 회귀를 지운다.** (`/qg` iter-7 — 재현.)
    `run_units` 가 `|| rc=$?` 를 리셋 없이 누산해 rc 가 **마지막** 실패 unit 의 코드가
    되고 그 하나를 present unit 전부에 찍는다. 같은 3 unit 의 **인자 순서만** 뒤집으면
    전부 `fail 1` ↔ 전부 `unrun 127` 로 갈리고, 후자에서 진짜 exit 1 회귀가 "못 돌렸다"
    로 소거돼 비차단 SKIP 이 된다. 증폭: `unrun` 은 green 도 red 도 아니라 SKILL 의
    *"red 일 때만"* per-unit 승격이 **발화하지 않아** 도말이 종착점이다. 기계는
    4-status 를 내는데 산문은 2분기로만 지시한다. 등급: **잔여 결함**.
23. **✅ 해소됨 — `unclaimed → verification: degraded` 에 기계 집행자가 없었다.**
    (`/qg` iter-7 — grep 확인: `unclaimed` 를 소비하는 스크립트 **0개**.)
    `run-test-selection.sh` 의 구조적 거부 3곳(워크트리 밖 unit · `unittest_can_judge`
    실패 · 실행 수단 없음)이 전부 SKILL 산문 한 문장에 종착했다. `unclaimed` unit 은
    어느 어댑터의 unit 목록에도 없어 `--expected` 에도 안 들어가므로 `SILENT_DROP`
    백스톱도 닿지 않는다 — 3플래그 false + 5차원 `closed`(모델 전사) → **PASS**,
    그동안 그 unit 들은 한 번도 안 돌았다. §11 ⑭ 의 더 날카로운 형태다.

    **어떻게 닫았나 (AC68).** `check_qa_ledger.py --assign-rows <배정 TSV>` 를 필수
    인자로 만들고, `unclaimed` 행이 1건 이상인데 `floor:verification` 이 `degraded` 가
    아니면 non-zero 를 낸다. R1b 가 `assign` stdout 을 `$assign_rows_file` 로 남긴다.

    **처방을 그대로 쓰지 않았다.** 원 처방은 `--unclaimed-count <N>` 이었는데 그대로
    두면 N 이 *모델이 옮겨 적는 숫자*가 되어, ⑱ 이 방금 닫은 전사 구멍을 **같은
    이음매에 다시 뚫는다** — `0` 하나로 검사가 사라진다. 처방이 인용한 *"⑱ 이
    `--aggregate` 로 한 것과 같은 모양"* 은 실제로는 **경로를 받아 스크립트가 직접 세는**
    모양이므로, 그 모양을 따랐다.

    **닫히지 않은 이웃:** 그 파일이 정말 이번 실행의 `assign` 출력인지(custody)는 여전히
    검사하지 않는다 — `--aggregate` 와 **같은** 기등재 갭이다(§6.7 S1). 그리고 배정 행이
    0개인 경우(빈 스코프)는 `unclaimed` 0건과 구분되지 않으므로 이 인자가 판정하지
    않는다 — 그 축은 **⑭ 이며 열려 있다**. 검증: T93 · T94(mutation 12축 RED + 위양성
    대조 1축 GREEN).
24. **`mutation-guard` 의 `.git/info/exclude` 조작이 동시성·중단에 안전하지 않다.**
    (`/qg` iter-7 adversarial — **리뷰어 5명 전원이 안 본 축**. 이 문서가 적어 둔
    *"안 본 축에 finding 이 없는 것은 부재의 증거가 아니다"* 의 실증이다.) 가드는
    샌드박스 안에서 `--git-common-dir` 로 **메인 레포의 `.git`** 을 얻은 뒤
    `info/exclude` 를 고정 이름 `.qgbak` 로 옮기고 비운다. (a) 동시 `/qg` 두 개 — 또는
    한 실행과 사용자의 git — 이 빈 exclude 를 보고, 둘째 가드의 백업이 첫째의 `.qgbak`
    를 덮어써 원본이 소실된다. (b) SIGKILL 후 live 파일은 빈 채 남고 고아 `.qgbak` 가
    원본을 쥐는데, 다음 세션의 스냅샷이 **빈 파일의 해시**를 기록하므로 sha-게이트 복원이
    영원히 불일치하고 그 다음 백업이 고아를 덮어쓴다 → **`.git/info/exclude` 영구 소실.**

    **판정: 선행 결함 — 이 브랜치의 병합을 막지 않는다** (iter-8 에서 확인). 근거:
    merge_base `e45619b` 의 `qg-worktree.sh` 에 `.qgbak` 가 **이미 18곳** 있고 현재도
    18곳이며, 이 브랜치가 그 파일에 넣은 것은 hunk 3개 +102줄(`@@ -6,+6` · `@@ -39,+50`
    · `@@ -494,+551`)로 **전부 그 블록 밖**이다. v2.2.0(#78, sandbox-executor)에서 들어온
    코드다. 등급: **선행 잔여 결함**(사용자 데이터 손실 경로) — 별도 이슈로 분리하며,
    이 문서의 병합 차단 목록에서는 뺀다. 닫을 때의 모양(잊지 않기 위해 적어 둔다):
    백업 이름을 고정 `.qgbak` 가 아니라 **세션-고유**로 만들고, 중단 내성을 위해
    `O_EXCL` 획득 + 크래시 트랩 복원을 함께 둔다.
25. **✅ 해소됨 — 오케스트레이터 소유 중간 파일의 위치가 정의되지 않았다.** (`/qg`
    iter-7 adversarial.) SKILL 은 `$expected_units_file`·`$baseline_rows_file`·
    `$head_rows_file`·`$per_adapter_yaml`·`$aggregate_yaml` 을 이름으로만 쓰고 **어디에
    사는지 말하지 않았다.** 근처에서 정의된 유일한 경로는 `evidence_dir` 인데 그것은
    verifier 에게 넘어간다.

    **어떻게 닫았나 (AC69).** R-init 이 `mktemp -d` 로 실행-스코프 디렉토리를 만들고
    여섯 이름(㉓ 이 추가한 `$assign_rows_file` 포함)을 거기에 정의한다. 두 금지가
    명시된다: `$project_dir` 안이면 `create-sandbox` 가 커밋 `B` 로 **봉인**한다 —
    실측이다, 그 절이 `ls-files --others --exclude-standard` 로 미추적·비-ignore 파일을
    샌드박스로 복사하고 건너뛰는 것은 `.claude/quality-gates/worktrees/*` 뿐이다;
    `$evidence_dir` 안이면 **피검자가 대조 원본을 쓰게** 되어 `--aggregate`·`--assign-rows`
    대조가 자기 자신을 대조하는 것이 된다. 어댑터별 4종은 러너 이름으로 갈라
    폴리글랏 레포에서 어댑터 A 의 행이 어댑터 B 의 대조에 들어가지 않게 한다.

    **부수로 드러난 것:** 이 요구는 SKILL 이 `mktemp` 를 부를 수 있어야 한다는 뜻인데
    `allowed-tools` 는 **개수·순서 정확 린터가 지키는 fail-closed 목록**이고 거기 없었다.
    이 목록의 유일한 비-플러그인 명령으로 `Bash(mktemp:*)` 을 등재했다 — 필요한 명령을
    선언하는 것이 allowlist 의 용도다. 린터가 SKILL 과 canonical 배열 양쪽을 잠근다.

    **닫히지 않은 이웃:** 이것은 *위치*만 정하고 **custody 를 증명하지 않는다** — 그
    경로의 파일이 정말 이번 실행의 스크립트 출력인지는 여전히 검사하지 않는다(§6.7 S1,
    열려 있음). 검증: T94 ⓪(정의가 사용보다 앞선다 — 정의를 R2 뒤로 옮기는 mutation RED).
26. **검증 표면의 이빨 갭 6종 (iter-7 mutation 45개 중 11개 생존).** 프로덕션은 현재
    옳지만 락이 회귀를 못 잡는다: ① symlink escape 락이 실패 불가(픽스처의 `*_test.go`
    가 assert **이후에** 생성돼 `has_go_tests` 가 단락 — containment fix 를 지워도 GREEN;
    프로덕션 영향은 pytest 가 워크트리 밖 실행) · ② `test_resolve_baseline.sh` 의
    baseline 우선순위 5갈래 중 **4개 미실행**(origin/* 픽스처 없음)이라 우선순위
    **역전**도 GREEN → stale local main 이 기준선이 된다 · ③ AC5 금지-리터럴 락이 손으로
    적은 4항목 열거라 다른 표기의 하드코딩이 생존 · ④ `--total` 분모가 상위집합으로만
    단언돼 분모 부풀리기가 생존 · ⑤ T68 qualifier 집합이 금지 형태를 **자기 금지어로
    면제** · ⑥ 도말 규칙 단방향(수용 측을 재는 테스트 없음) — **이 축의 수정은 테스트이지
    코드가 아니다**: 코드를 조이면 §11 ⑫(공시하되 봉쇄 안 함)를 정면 위반한다.
    함께: §8.1 10행이 자기 id 를 인용하는 테스트가 없고(table→test 방향 미검사),
    `AC24–26` 범위 표기 탓에 AC25/AC26 이 리터럴 grep 으로 기계-미발견이다. 등급: **갭**.
27. **전체 스위트 실행이 추적 픽스처를 덮어쓴다 (선행).** (iter-8 — 스위트 실행 중
    우연히 관측.) `tests/spike/test_codex_json_extraction.sh` 는 **live `codex exec` 를
    호출**하고 그 응답을 `tests/spike/fixtures/codex_jsonl_sample.json` 에 **cp 로 덮어쓴다**
    (`:72`). 그래서 스위트를 한 번 돌리면 작업 트리에 자기 것이 아닌 수정이 생기고,
    확인 없이 커밋하면 *녹화된 표본* 이어야 할 픽스처가 **매번 바뀌는 값**이 되어 그
    픽스처가 지키던 회귀를 못 잡는다(이번에 `thread_id`·`line`·토큰 수가 바뀌었다).
    비용도 있다 — 스위트 실행마다 codex 호출 1회. **이 브랜치 diff 밖**이며(merge_base 에
    이미 존재) 이 설계의 범위도 아니다. 등급: **선행 갭** — 병합을 막지 않는다. 닫을 때의
    모양: 갱신을 `--freeze` 같은 명시 플래그 뒤로 옮기고 기본 실행은 읽기 전용으로 둔다.
28. **"영향분"의 적절성 기준이 없어, 비어 있지 않기만 하면 임의의 집합도 자동 AC 를
    전부 충족한다.** (iter-8 codex, **block**.) 기존 세 항목 **어느 것도 이 주장을 담고
    있지 않다** — ⑭ 는 *빈* 스코프, ③ 은 *과*선택(OQ3), ④ 는 의존그래프 부재다. codex 가
    가리키는 것은 셋 **사이에 난 구멍**이다: 후보가 1건이라도 있으면 `--expected` 가
    비지 않아 AC64 를 지나가고, 그 1건이 green 이면 5차원 `closed` + 3플래그 false 로
    PASS 행이 선다. 즉 *"영향분을 골랐다"* 와 *"영향분을 옳게 골랐다"* 사이에 기계가
    없다. §5.3 이 스코프를 모델 소유로 둔 것은 의도된 설계(P8)이므로 **닫는 방법은
    모델을 묶는 것이 아니다** — codex 처방은 대표 변경 유형별 fixture corpus 와 기대
    선택 결과를 두어 *선택기 자체를 회귀 테스트*하는 것이다. 그것은 이 브랜치 범위 밖의
    새 검증 층이다. 등급: **잔여 결함**(이 설계가 답한다고 주장하는 범위 안 — §5.3 이
    "영향 판정"을 자기 산출물로 선언한다).
29. **AC31·AC49 의 *"…취지의 문장/문구"* 가 합격 텍스트를 정하지 않는다.** (iter-8
    codex, medium.) 두 AC 는 특정 *의미*를 요구하는데 무엇이 그 의미를 만족하는지는
    구현자와 테스트 작성자가 각자 정한다 — 실제로 iter-5 가 AC31 락을 고친 이유가
    *"body-contract assert 가 frontmatter 로 만족됐다"* 였고, 그것이 바로 이 모호성의
    발현이다. §11 ㉖(이빨 갭)은 이 축을 담고 있지 않다. 닫는 모양: 각 AC 에 canonical
    anchor 문자열을 지정하거나 구조화 필드로 바꾼다. 등급: **갭**(현재 락이 우연히
    맞는 문자열을 잡고 있어 프로덕션은 옳다).

---

## 12. Metadata

| 항목 | 값 |
|---|---|
| 입력 brief | `docs/superpowers/interview/2026-07-26-qg-impact-driven-qa-runtime-interview.md` |
| 대상 플러그인 | `plugins/quality-gates` |
| 버전 영향 | **major — v2.14.x → v3.0.0** (`/qg runtime` 인터페이스 유지, "전체 앱 실행" 동작 제거) |
| 브랜치 | `feature/qg-impact-driven-runtime` |
| 신규/수정/문서 | 신규 5 · 수정 7 · 문서 3 (신규 스크립트는 서브커맨드가 늘었을 뿐 파일 수 불변) |
| 리뷰 라운드 1 | Claude `spec-reviewer` 8건(block 1·high 4·medium 3) + codex 4건(high 3·medium 1) → combined `needs_revise` → 전량 반영 + 전수 스캔 자체 발견 3건 (AC3·AC20 검증 부재, §5.6 예시의 `AC4` 토큰 충돌) |
| 리뷰 라운드 2 | Claude 4건(high 3·medium 1) + codex 4건(high 4) → combined `needs_revise`, stagnation 없음(반복 이슈 0). **두 리뷰어의 발견이 거의 disjoint** — 라운드 1 수정이 연 새 계약 지점을 서로 다른 각도에서 적발. 핵심: 러너 감지 소유권 순환 · `BULK` 키 식별 · `없음`/`미실행` 생산자 부재 · §5.10↔§5.7 자기모순 · deps setup 비대칭 |
| 리뷰 라운드 3 | Claude 9건(**block 1**·high 4·medium 4) + codex 3건(high 2·medium 1) → combined `needs_revise`. 원장 3개 이슈가 `raised_count == 3`에 도달해 **per-issue stagnation → Human Gate 강제 escalate**(같은 결함 미해결이 아니라 §5.9/§5.4/§5.2 세 영역이 매 라운드 새 계약 표면을 낳은 패턴). 사용자 선택으로 라운드 4 진행. **block = 단일-러너 `detect`가 폴리글랏 레포에서 누락 방향 실패** — 이 레포 실측으로 확인(`.sh` 130 / `.py` 50 → shell 전량 미실행). 다중 어댑터로 해소 |
| 리뷰 라운드 4 | Claude 4건(**block 1**·high 2·medium 1) + codex 6건(high 4·medium 2) → combined `needs_revise`. Claude가 **라운드 3의 9건 전부 계약 수준 해소 확인**. 신규 block = `unclaimed` unit이 `gap: closed`로 가서 아무 테스트도 안 돌고 PASS 가능(라운드 3에서 detect 레이어에 잠근 누락 방향 실패가 배정 레이어로 한 칸 내려옴). **남은 9건 중 5건이 한 뿌리** — 다중 어댑터의 *배정*과 *집계*를 결정론 컴포넌트가 아니라 모델에 맡긴 것 → `assign` 서브커맨드 + `--aggregate` 모드로 근본 봉쇄. 나머지 4건은 라운드 4가 만든 자기모순(0-어댑터 계약 3갈래 · cargo 행의 `CARGO_TARGET_DIR` 공유 · 캐시 usage의 `file` 용어 · 미정의 "대략 시간") |
| 신규 에이전트 | **0** |
| 신규 훅 | **0** |
| 신규 verdict 토큰 | **0** |
| 리뷰 라운드 5 | **집계가 이 표에 기록되지 않았다.** 라운드 5는 실행됐으나 그 시점에 이 표가 갱신되지 않았고, 원장·아티팩트 어느 쪽에서도 건수를 복원할 수 없다. 추정치를 적는 대신 **누락 사실 자체를 기록한다** — 이 표는 라운드 4 이후 3라운드 동안 stale했고, 그 자체가 라운드 7 block(F1)의 일부다 |
| 리뷰 라운드 6 | Claude 9건(**block 4**·high 3·medium 2) + codex 5건(block 2·high 2·medium 1) → combined `needs_revise`, stagnation 없음. **block 4건이 전부 저자(메인 에이전트)가 바로 앞 커밋에서 만든 결함**이었다. 최악: §6.7의 `**검증:**` 줄이 §8 표에 **없는** `T62`/`T63`과 **이미 다른 mutation에 배정된** `M17`–`M22`를 근거로 인용 — 임시 mutation 하니스의 로컬 ID를 문서 좌표계로 옮기며 충돌을 확인하지 않았다. **문서가 자기 커버리지에 대해 거짓말을 한 것.** 나머지 셋: AC64를 대응 T/M 없이 추가 + 완전성 선언문 `AC1–AC63` 방치(라운드 3에서 이미 겪은 stale 선언문의 재발) · §6.7이 AC61–AC63을 정정했는데 §6.6 원문에 전방 포인터가 없어 **§6.6만 읽는 구현자가 실측으로 반증된 술어를 재구현**하게 됨. 수정 `85103d6` |
| 리뷰 라운드 7 | Claude 12건(**block 1**·high 4·medium 7) + codex 4건(**block 2**·high 1·medium 1) → combined `needs_revise`, stagnation 없음. **라운드 6의 block 4건은 held**(재제기 0, 독립 확인). 신규 block = **이 표 자신**(F1: 아래 "다음 단계"가 미착수를 암시하는데 `plugin.json`은 이미 `3.0.0`이고 구현·CHANGELOG·신규 스크립트 5종이 전부 존재 — 문서가 계획서인 척하는 완료된 일의 기록). codex 단독 신규 high = **R5a의 boot setup이 나중에 권위 있는 테스트를 돌릴 바로 그 HEAD 샌드박스를 변형** → 두 축이 같은 환경이라는 이 설계의 전제를 직접 겨눔(§11 ⑬에 등급 하향 없이 반영). 라운드 6 이월 5건(U1–U5)은 **하나도 닫히지 않았다.** `rereview_count 7 ≥ cap 5` → Human Gate forced escalate → 사용자 결정: **문서 정직화만 하고 design 리뷰 루프 종료.** 이 라운드에서 닫은 것 = F1(이 표) · U4(§11 등급 어휘 고정) · U2(§11 ⑭ 등재) · §6.7 "21건" 수 정합 · T60 판별자 픽스처 · U1 `SILENT_DROP` degrade assert. **닫지 않은 것 = codex block 2건(21항목 미완 · 귀속 입력 소유·provenance) · U3(원장↔기계출력 대조) · U5(GC scope-creep) · T37/T46 커버리지 갭** — 전부 §11/§6.7 잔여로 이월. **(정정 — `/qg` iter-6 E6: 이 "이월" 주장은 작성 시점에 거짓이었다. `T37`·`T46` 은 §11 에도 §6.7 에도 등재된 적이 없었고, 그것은 §6.7 이 직접 처벌한 클래스 — *등록 없는 등록 주장* — 이다. 이제 §11 ⑮·⑯ 으로 실제 등재했다. **같은 문장의 `U3`(원장↔기계출력 대조)·`U5`(GC scope-creep)도 같은 상태였다** — 두 id 역시 이 줄 외에는 문서 어디에도 없다(§11 ⑩ 은 "GC 가 일어나지 않는다" 로 다른 사실). 이 두 건은 iter-6 범위 밖이라 닫지 않았고, **이 정정문이 그 미등재 자체를 공시하는 것으로 대신한다** — 다음 라운드의 등재 대상이다.)** |
| 선행 레퍼런스 (통독) | `gstack/qa/SKILL.md` (1685줄) · `compound-engineering-plugin/skills/ce-test-browser/` (SKILL + references 2) · `oh-my-codex/skills/ultraqa/SKILL.md` + 자매 2 · `ECC/.agents/skills/e2e-testing/` · `ECC/agents/e2e-runner.md` · `gbrain/skills/testing/` · `gbrain/skills/smoke-test/` |
| **문서 상태** | **기록 + 갭 원장 — 계획서가 아니다.** 이 설계는 **이미 구현됐다**(`plugin.json` `3.0.0`, CHANGELOG `[3.0.0]`, 신규 스크립트 5종 + 수정 7종 전부 브랜치에 존재). `writing-plans`는 이 문서에 대해 **실행되지 않으며 실행될 필요도 없다.** 앞으로 이 문서의 역할은 ① 무엇을 왜 이렇게 지었나의 기록, ② §11·§6.7의 **미해결 잔여 원장**이다 |
| `/qg` iter-5 수정 라운드 | iter-5 리뷰의 **CRITICAL 1(SR1) + code-reviewer 5(C2–C6) + SF2·SF5·SR4·TA1** 를 처리했다. 굵직한 둘: **SR1** — iter-2 의 AC60 이 닫았다고 주장한 사슬이 한 칸 옆으로 살아 있었다(`detect` 는 선언만 보고, 캐시 전량 적중이면 실행 관문이 한 번도 안 돈다) → `probe` 서브커맨드로 근거를 실행 기반으로 이전. **C2** — 매니페스트가 테스트 러너를 verifier 에게 부팅 표면으로 넘겨 §5.1 불변식 ②와 충돌(스위트 2회 실행 + HEAD 전용 deps 설치로 AC41 파괴) → `runnable_surfaces` = 부팅 표면 전용. **나머지 셋은 락 자신의 결함**이었다: verdict-토큰 락이 SKILL.md 부재를 통과로 읽음(grep exit 2) · body-contract assert 가 frontmatter 로 만족돼 보안 Hard Rule 삭제를 못 잡음 · 어댑터 개수 6곳이 9종을 8종이라 적음. mutation 합계 **56 RED**. ★이 라운드에서 **내 mutation·needle 이 5번 고장**났다(파일 목록 누락 1 · body-unique 아닌 needle 3 · `source` 가 `exit 0` 을 만나 assert 가 한 줄도 실행되지 않음 1) — 매번 락이 아니라 계측기가 문제였다. ★T9 의 ∀ 가 러너 5축 중 **3축을 아예 지나가지 않았다**(픽스처에 그 레포 형태가 없었다): **∀ 의 범위는 코퍼스가 정하지 술어가 정하지 않는다.** |
| `/qg` iter-6 수정 라운드 | 리뷰어 5명(security-reviewer · **codex** · silent-failure-hunter · code-reviewer · **pr-test-analyzer**) + adversarial. **42건 판정.** adversarial 이 해소한 핵심 충돌: `code-reviewer` 의 *"fail-open 없음 · Critical 없음"* 은 **자기 findings 에 대해서는 옳지만 브랜치 전체 속성으로 일반화한 것이 틀렸다** — 인자-provenance·R5b/R7 순서·테스트-이빨 세 축을 아예 안 봤고, **안 본 축에 finding 이 없는 것은 부재의 증거가 아니다**. 그리고 A/B/C 의 CRITICAL 중 **8건은 이 문서의 §6.7/§11 잔여 원장에 이미 등재**돼 있었다(리뷰어들이 원장을 독립 재발견 — 원장이 정직하다는 증거). **미등록 CRITICAL 은 정확히 1건: `--mode` provenance.** 형제 `--granularity` 가 iter-5 C5 로 그 처방을 받았는데 이 인자만 못 받았고, adversarial 이 C5(도말)와의 **합성 경로**까지 찾아냈다. 닫은 것: `--mode` 데이터 대조 · `async def test_` 프로덕션 버그(AC63′ escape (a) 재개방) · `assign` 후행개행 무음 소실 · 실행비트 4개(**self-dogfood 가 구조적으로 인증 불가였다**) · 무음 degrade 2종 · 옵션 주입 · 분모⊉분자 · `resolve-baseline` fail-open · poetry env-dir 단정 · 폴백 라우팅 산문과 **그 틀린 주장을 방어하던 락** · 이빨 없던 락 7종(음의 락 3 · R8 floor 절 · `setup_failed` · 2단 재실행 red 방향 · ATTR 7셀 · 필수 인자 ∀ · red bulk 픽스처 부재) · 원장 정합(§8.1 T-id 16개 미등재 · §12 의 등록 없는 등록 주장 · **AC21′**). 교훈: **정정 노트가 옛 값을 인용하면 그 인용이 스캔 코퍼스에 들어가 자기 자신을 위반으로 만든다**(이번에 두 번 물렸다) |
| `/qg` iter-7 구조 라운드 | **§11 ⑬ 해소 — 두 번째 일회용 워크트리.** codex 가 라운드 7 에서 지정한 두 정답 중 첫째(*부팅과 테스트 실행의 환경 분리*)를 실행했다: `qg-worktree.sh create-head <B>` 가 봉인 커밋에 detached 된 HEAD 축 전용 트리를 만들고 R5b 가 거기서 돈다. **⑨(= §6.7 S4)가 같은 수정으로 함께 닫혔다** — 두 항목이 *권위 있는 HEAD 축이 감시 대상 트리 안에서 돈다* 는 한 뿌리였다. 부수로 잡힌 것: (a) §5.2 의 *"테스트는 setup 이 끝난 트리에서 돌아야 한다"* 는 근거가 **바로 ⑬ 을 낳은 전제**여서 교체 — 러너용 setup 과 부팅용 setup 을 구별하지 못한 것이 오류였다, (b) 재시도가 **새 `B`** 를 만드는데 옛 sha 로 트리를 만들면 *고쳐지기 전 코드*를 HEAD 로 재는 새 fail-open — 지시와 락으로 봉쇄, (c) `mutation-guard` 3-arg 락의 앵커가 *이름 첫 등장*이라 내 산문에 latch — `scripts/` 접두를 요구하는 호출-줄 앵커로 교정(반대 방향이 더 나빴다: 호출에서 인자를 지워도 산문이 만족시켰다), (d) 재시도 순서 락이 `R5b(새` 로 **괄호 안 낱말까지** 핀해 사실 갱신을 RED 로 만들던 것 — 락이 문서에 거짓을 요구하는 형태라 구조 앵커(`R5b(`)로 교정, (e) **T87 미등재** 적발 — iter-6 이 만든 테스트가 §8.1 행 없이 한 라운드를 넘겼다(§6.7 이 처벌하는 *등록 없는 등록*). 신규 검증: T88 · T89 · AC65, mutation 8축 RED(계측기 3회 고장 후 재설계 — 도달불가·앵커 잔존·heredoc 이스케이프). 스위트: bash 81 green / 알려진 6 red · python 128 OK. **이 라운드는 아직 `/qg` 재검증을 받지 않았다.** |
| `/qg` iter-7 (2) — 전사 대조 | **U3 해소 + U3·U5 실등재.** 라운드 6·7 이 "이월" 이라 적어 온 U3(원장↔기계출력 대조)·U5(GC scope-creep)는 **어느 목록에도 등재된 적이 없었다** — iter-6 이 그 미등재를 공시만 했다. 둘 다 §11 에 실제로 등재했고, U3 는 같은 라운드에 닫았다: R8 이 R6 의 `attribution_status` 를 *모델이 옮겨 적는* 자리에 집행자가 없어 `degraded`→`closed` 전사가 그대로 PASS 행을 만족시켰다 → `check_qa_ledger.py --aggregate`(필수)가 두 값을 대조. **의미 판정이 아니라 두 필드의 일치**라 이 스크립트의 기존 계약을 넘지 않는다. 함께 등재한 것: §11 ⑳ — ⑬ 수정이 일회용 트리 누수 지점을 하나에서 둘로 늘렸다(디스크 점유이지 데이터 손실 아님, 갭). 부수로 잡힌 것: 새 필수 인자가 기존 음성 테스트들을 **엉뚱한 이유로 통과**시킬 뻔했다(전부 exit 2 로 죽어 재려던 축이 판정되지 않음) → 러너에 일치 집계를 심어 각 축을 제자리로 되돌림 · 내 새 케이스가 다른 케이스의 파일을 참조해 파일 부재로 통과할 뻔한 것 1건 · 새로 생긴 두 번째 read 경로에 로케일 독립 픽스처(한글) 추가. 신규 검증: AC66 · T90 · T91, mutation 5축 RED(계측기 2회 고장 — derived 블록 동반 삭제 · zsh 무분할). |
| `/qg branch` iter-7 Review 게이트 | 리뷰어 5(security-reviewer · pr-review-toolkit:code-reviewer · silent-failure-hunter · pr-test-analyzer · **codex**) + adversarial. **29건 판정 — 3 CRITICAL / 19 IMPORTANT / 8 SUGGESTION.** 이 라운드의 핵심 사실: **CRITICAL 과 IMPORTANT 의 다수가 iter-7 의 내 두 커밋에서 나왔다.** `create-head` 도입이 (a) R6 flaky 재실행이 쓸 트리를 먼저 지웠고(리뷰어 4명 독립 수렴), (b) sha 를 무검증으로 받아 **degrade 신호 없는 silent PASS** 를 열었고, (c) R5b 에만 실패 라우팅이 없었다. 게다가 **그 수정을 지키려고 내가 단 락 3개가 전부 뚫려 있었다** — ∃·토큰 grep·비대칭 needle. ★ **내 mutation 이 '삭제' 축만 흔들었기 때문**이고 리뷰어는 추가·반전·형태변경으로 통과시켰다. **adversarial 이 잘못된 수정 4건을 막았다**: `env_dir_not_ignored` 게이트 제거(살아있는 근거가 있어 순감) · `create-head` 를 샌드박스 HEAD 에서 *도출*(신뢰 앵커를 피검자에게 넘김) · 도말 규칙 코드 조이기(§11 ⑫ 정면 위반) · `--force` 전환(F12 를 격상). 또 **5명 전원이 안 본 축**을 하나 찾았다(§11 ㉔ `.git/info/exclude` 영구 소실). 이번에 닫은 것: F1(트리 수명 + ∀ 창 R7 확장) · F3(봉인 대조) · F2/AC67(R5b 라우팅) · F4(mode 보수적 fold) · F6·§11 ⑳ 정정 · F11·H4(상류 degrade loud) · M6·M8·M9·M2 · PT2·PT3·PT4·PT5 락. mutation 이번 라운드 합계 **19축 RED**(계측기 4회 고장 후 재설계 — 도달불가 · 앵커 잔존 · heredoc 이스케이프 · zsh 무분할). 스위트 bash 81 green / 알려진 6 red · python 128 OK. |
| `/qg` iter-7 iteration 2 (수정분 재리뷰) | codex + security-reviewer 재dispatch. **security-reviewer 가 iteration 1 의 CRITICAL 3건이 실제로 닫혔음을 추적으로 확인** — 특히 `create-head` 의 대조가 *거부 전용* 임을 verifier 의 다섯 선택지(B 위 커밋 · `reset --hard` · 샌드박스 삭제 · 평범한 디렉토리로 교체 · `head-<sid8>` 선점)를 하나씩 밟아 검증했고, 두 경로 도출이 같은 idiom 이라 심볼릭 링크에서도 어긋나지 않음을 확인했다. **그리고 내 수정에서 새 결함 5건을 찾았다**: ① flaky 재실행 결과의 **캡처·병합 규칙이 없어** *"마지막 호출이 authoritative"* 가 닿을 데가 없었다 · ② R5b 라우팅이 실패 후에도 진행하는데 폐기가 **무조건**이라 `remove ""` 가 죽어 **이미 확정된 degrade 가 R7·R8 에 도달하기 전에 파이프라인이 끊긴다** · ③ `2>&1` 캡처가 성공 경로의 git 경고를 **파일명 스트림에 섞는다**(codex·security 독립 수렴) · ④ ★**내 `exit 4` 를 같은 파일 세 줄 위 헤더가 무력화**하고 있었다 — *"Skill must fail-open (treat non-zero as empty)"* 가 그 스크립트의 유일한 reader-facing 계약이라, `|| true` 를 걷어낸 수정이 **문서에 의해 그대로 F11 로 되읽히는** 상태였다. **코드를 고치고 계약을 안 고치면 고친 것이 아니다.** · ⑤ 폐기가 R6 의 정상 종료 경로에만 있어 exit-4 라우팅에서 트리가 새고, 그 트리의 산출물 때문에 다음 `create-head` 가 die 해 **세션이 영영 PASS 에 도달 못 하게** 된다. 다섯 건 전부 수정. |
| iter-8 — `unclaimed` 집행 + 중간 파일 위치 | **㉓·㉕ 해소, ㉔ 판정.** ㉓: SKILL 산문의 *"`unclaimed` 하나면 `verification: degraded`"* 를 **읽는 기계가 0개**였다 → `check_qa_ledger.py --assign-rows`(필수)가 배정 TSV 에서 직접 센다. ★**처방을 문자 그대로 쓰지 않았다** — 원 처방 `--unclaimed-count <N>` 은 N 이 *모델이 옮겨 적는 숫자*라 ⑱ 이 방금 닫은 전사 구멍을 **같은 이음매에 다시 뚫는다**(`0` 하나로 검사 소멸). 처방이 인용한 *"`--aggregate` 와 같은 모양"* 의 실체는 **경로를 받아 스크립트가 직접 세는 것**이었고 그 모양을 따랐다. ㉕: 그 대조가 파일을 요구하는데 SKILL 은 중간 파일 6종의 위치를 말한 적이 없었다 → R-init 이 `mktemp -d` 로 정의하고 `$project_dir`(봉인 대상) · `$evidence_dir`(피검자 소유) 두 금지를 명시. ㉔: **선행 결함으로 판정** — merge_base 에 `.qgbak` 18곳이 이미 있고 이 브랜치의 `qg-worktree.sh` diff(3 hunk +102줄)는 전부 그 블록 밖 → 병합 차단 목록에서 제외, 별도 이슈. 신규 검증: AC68 · AC69 · T93 · T94. **mutation 12축 RED + 위양성 대조 1축 GREEN.** ★그중 하나가 **∃-탈출로 생존**했다(맞는 호출 뒤에 인자 빠진 두 번째 호출) — 지난 라운드가 남긴 *"추가 축"* 교훈이 **내가 그 라운드에 새로 단 락에서 그대로 재현**된 것이라, ∀ 로 고치고 전량 재측정했다. ★부수: `mktemp` 를 쓰는 지시를 써 놓고 보니 `allowed-tools` 는 **개수·순서 정확 린터가 지키는 fail-closed 목록**이고 거기 없었다 — 계약을 쓰면서 그 계약을 집행하는 표면을 안 본 것이다(iteration 2 의 ④ 와 같은 모양). 등재했다. 스위트: bash 81 green / 알려진 6 red · python 128 OK (baseline 과 동일 — 새 테스트 *파일* 이 아니라 기존 파일에 케이스를 더했다). |
| iter-8 spec review (Claude + codex) | **양쪽 독립 `needs_revise` — 8건**(Claude 4: high 2·medium 2 / codex 4: block 1·medium 3), stagnation 없음. **Claude 4건이 전부 내가 iter-7·iter-8 에 만든 것**이다: ① §8.1 완전성 선언문이 `AC1–AC64` 에서 멈춤 — **세 번째 재발**(라운드 3, iter-6 에 이어) · ② AC69 가 주장하는 (a)한 디렉토리 (b)`$project_dir` 밖 (c)`$evidence_dir` 밖 **셋 다 미검증**(T94 ⓪ 은 6종 중 1종의 정의 순서만 잼) · ③ §12 가 새로 등재한 ㉗ 을 안 적음 · ④ T93 의 `exit 2` 가 문서 규약(2=모양, 4=내용)과 어긋남. **내가 기계로 확인하니 ①·④ 둘 다 리뷰어 말보다 나빴다**: ① 은 stale 선언에 더해 **AC67 이 §8.1 에 행 자체가 없었고**(미등록 — 이 문서가 §6.7 에서 처벌하는 클래스), ④ 는 규약을 맞추다 보니 원장 read 경로에 `UnicodeDecodeError` 핸들러가 없어 비-UTF-8 원장이 **트레이스백**이었다(형제 두 경로에서 이미 고친 같은 버그의 세 번째 인스턴스). codex 4건 중 3건은 기등재 갭(⑧·⑲·③④⑭ 분산)의 독립 재발견이고, **신규 2건을 ㉘·㉙ 로 등재**했다 — ㉘(block)이 특히 중요하다: ⑭·③·④ **어느 것도** *"비어 있지 않기만 하면 임의의 집합도 자동 AC 를 충족한다"* 를 담고 있지 않았다(세 갭 사이의 구멍). 수정: 위 4건 + AC67 등재 + AC3/T32 갱신, 신규 T89′·T95·T96, **mutation 8축 RED**(뿌리를 `$project_dir`/`$evidence_dir` 로 옮기기 · 여섯 중 하나만 탈출 · 정의를 창 밖으로 · mktemp 제거 · 내용→2 되돌림 · 모양→4 · UnicodeDecodeError 가드 제거). 스위트: bash **80 green / 알려진 6 red**(86 파일 — spike 1종은 ㉗ 사유로 제외) · python 128 OK. 사용자 결정으로 **reviewing-spec 재진입은 하지 않는다.** |
| 다음 단계 | **`/qg branch` 재실행(iter-8 코드 리뷰)** — iter-7·iter-8 수정분은 아직 `/qg` 재검증을 안 받았고, 직전 다섯 라운드가 모두 그 자리에서 새 CRITICAL 을 냈다. **이 브랜치는 여전히 병합 불가.** 남은 잔여(병합 차단): §11 **⑭**(빈 스코프 무집행 — B1 선결) · **⑰**(mode provenance) · **㉑**(bulk green 이 0건 인증 — 설계 결정 필요) · **㉒**(도말 인자 순서) · **㉘**(영향분 적절성 기준 부재 — codex block; 닫으려면 선택기 회귀 fixture 층이 필요해 이 브랜치 범위 밖) · §6.7 **15 항목**. 열린 갭: §11 **⑲**(GC scope-creep) · **⑳**(트리 누수, 수명 연장으로 창 확대) · **㉖**(이빨 갭 6종 + 원장 table→test) · **㉙**(AC31·AC49 의 "취지" 문구). 브랜치 밖으로 분리(선행, 병합 비차단): **㉔**(`.git/info/exclude` 영구 소실 — v2.2.0) · **㉗**(spike 테스트가 live codex 호출 + 추적 픽스처 덮어쓰기). 그 밖: 수동 V-행 · Runtime 게이트 실측(`claude -p --plugin-dir` 별도 세션) · **V10**(§6 AC id 집합 ⊆ §8 인용 집합을 세는 검사 — 같은 stale 이 세 번 났으므로 사람이 기억할 일이 아니다). **의도적으로 열어 둔 것**: B1(§6.7 F5) · C5. A1/C2 · U3 · ㉓ · ㉕ 는 닫혔다. |
