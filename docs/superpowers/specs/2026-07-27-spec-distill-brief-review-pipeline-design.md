# spec-distill brief 리뷰 파이프라인 (Spec B)

> *하네스를 무겁게 만들어서 능력을 제한하는건 절대 안돼.*
> — 사용자, 2026-07-26 (제약 E10 — 최상위)

interview brief에 Law 2 분리 리뷰를 붙인다. 축은 둘(충실도·방향성), 담당은 셋(격리된 critic · 웹 조사 방향성 리뷰어 · 순진한 readback) + 별-모델 codex 2회. 훅은 늘지 않고 상한은 실재 루프에만 붙는다.

## 목차

- [Handoff Context](#handoff-context)
- [1. Context / Why](#1-context--why)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. Constraints](#4-constraints)
- [5. 설계](#5-설계)
  - [5.1 아키텍처 — 컴포넌트 넷](#51-아키텍처--컴포넌트-넷)
  - [5.2 데이터 흐름 — 3단계](#52-데이터-흐름--3단계)
  - [5.3 산출물 형식](#53-산출물-형식)
  - [5.4 수정 권한 · C4 재결정 경로](#54-수정-권한--c4-재결정-경로)
  - [5.5 게이트 · 원문 완전성](#55-게이트--원문-완전성)
  - [5.6 에러 처리 · graceful degradation](#56-에러-처리--graceful-degradation)
  - [5.7 모듈 구조 · 상태 · 비용](#57-모듈-구조--상태--비용)
- [6. Acceptance Criteria](#6-acceptance-criteria)
  - [6.1 기계 검증의 한계 (명시)](#61-기계-검증의-한계-명시)
  - [6.2 충실도 루프 전이 표 (AC13)](#62-충실도-루프-전이-표-ac13)
  - [6.3 신규 결정론 체크 전수 열거 (AC22c)](#63-신규-결정론-체크-전수-열거-ac22c)
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

- spec-distill의 interview brief는 지금 **분리 리뷰어가 없다.** Law 1 구조 게이트(`check_brief.py`)만 있고, *"모델이 사용자 말을 왜곡했는가"* 와 *"사용자가 잡은 방향 자체가 틀린 것은 아닌가"* 를 볼 주체가 없다. 이 spec이 그 리뷰 파이프라인을 만든다.
- Spec A(v0.23.0, merge 5b0caff)가 **의도적으로 후속으로 미룬 것**이다. Spec A는 포맷·producer 교체(권위 문법 제거 + payload/audit 2파일 + `source × status × evidence` 계약)만 했고 *"신규 에이전트 0개"* 를 명시했다.
- 산출: **신규 에이전트 3 + codex 2회 호출 + 신규 skill 1 + 스크립트 4.** 훅은 **0개 추가**.

**Implicit context** (Constraints에 안 박힌, 작업에 필요한 외부 사실):

- **v0.23.0 포맷 실물 brief가 리포에 0건이다.** `2026-07-25-...-interview.md`는 새 포맷을 손으로 근사한 dogfood라 shipped 게이트를 통과하지 못하고(6 failures — 실측), 최신 `2026-07-26-qg-...-interview.md`는 `locked_directions`를 쓰는 v0.22.0 구 포맷이다. 그래서 이 spec의 설계 입력은 **shipped 템플릿 + 게이트 계약**이고(E1), 실물 검증은 V1로 배치했다. **Spec A의 미완 수동 e2e도 V1에서 함께 닫힌다.**
- **codex는 웹 검색을 한다** (codex-cli 0.144.6, 2026-07-26 실측: `codex exec -s read-only`가 라이브 검색으로 npm `zod` 버전 + URL 반환). `--search`는 TUI 전용 플래그이고 `codex exec`에서는 `-c tools.web_search=true` 경로다. 현재 환경에선 **기본 활성**이지만(오버라이드 없는 대조군도 `web.run` 보유) 버전·config 의존이므로 명시적으로 켠다.
- **`codex exec`는 `project_dir`에서 돌아 repo 전체를 읽을 수 있다** — audit 파일도 포함. 즉 D2의 프레이밍 격리는 codex에 자동 적용되지 않는다.
- **`state.local.md`의 `user_statements` 스키마**: `- id: S<N> / source / round / text`. payload §6의 `**S<N>**` 앵커와 **같은 id 체계**라 기계 대조가 가능하다.
- `check_brief.py`는 현재 **brief 파일만 읽는다**(state를 읽지 않는다). 이건 유지할 성질이다 — 임의 brief 파일에 게이트를 돌릴 수 있다는 뜻.
- `web_budget.py`의 `SESSION_CAP = 8`. 인터뷰 종료 시점이면 R2 landscape sweep이 이미 상당량을 소비했을 수 있다. **codex의 웹 사용은 이 카운터 밖이다.**
- `superpowers:brainstorming`은 spec-distill을 모르고 brief frontmatter를 읽지 않는다 — 전달은 순수 프로즈 경로이며 계약 전달 채널은 orchestrator의 호출 프롬프트뿐이다(Spec A §5.1).
- 리포 이력: **별-모델 codex가 same-family opus 다단계 리뷰가 통과시킨 fail-open을 반복 적발**했다(qg v2.13.0 C5, spec-distill v0.20.0/v0.22.0 등). 모델 다양성은 장식이 아니라 유일한 backstop이다.
- `docs/handoffs/2026-07-26-harness-capability-suppression-sweep.md` — E10을 리포 전역에 집행하는 별 작업. 이 spec과 독립이고 서로 블록하지 않는다.

**Deferred to plan** (이 spec이 의도적으로 lock하지 않은 것):

- 3 에이전트 역할 프롬프트의 **문구**. `tools:`·`model:`·입력 계약·산출 형식만 lock하고 체크리스트 항목의 표현은 구현 재량.
- `prompts/brief-codex-*.md` 체크리스트의 **개별 항목**. 축 분리와 파일 경계만 lock.
- `check_verbatim_coverage.py`의 정규화 함수 세부(공백 collapse 방식, 인용 마커 제거 범위).
- 테스트 파일 배치(기존 `tests/` 구조에 맞춰 구현이 결정).
- `CHANGELOG.md` 항목 문구.
- **사용자 오타·발언 철회 경로** — §6 append-only의 대가. Spec A가 *"기록 이후 원문 정정 경로"* 로 defer한 것을 그대로 유지한다(§11).

---

## 1. Context / Why

**입력**: `docs/superpowers/interview/2026-07-25-spec-distill-brief-handoff-redesign-interview.md` (+ `.audit.md`) — Spec A와 같은 brief. 그 brief는 *"포맷·producer 교체"* 와 *"리뷰 파이프라인 신설"* 두 덩어리를 담았고, 사용자 결정으로 두 spec으로 갈렸다(B1). 이 문서가 후자다.

**증상**: brief에 리뷰가 없다. 구체적으로 세 구멍:

| 구멍 | 지금 누가 보나 | 결과 |
|---|---|---|
| §2 요약이 §6 원문을 왜곡·삽입했는가 | 아무도 | `evidence: S<N>`는 앵커의 *존재*만 검사한다 — 실재하는 아무 id나 붙여도 통과(Spec A가 V9 수동으로 분리한 갭) |
| §6 원문 자체가 완전한가 | 아무도 | 사용자 발화가 통째로 빠져도 게이트는 모른다. 비교 대상(state 원장)이 문서 밖에 있어 payload-only로는 원리적으로 불가 |
| 사용자가 잡은 방향 자체가 틀렸을 가능성 | 아무도 | C4가 *"뒤집을 이유가 있으면 보고하고 재결정"* 인데 **뒤집을 이유를 찾는 역할이 없다** — C4가 사문이 된다(D5의 근거) |

**구조적 근거**: `superpowers` brainstorming 체크리스트 7번이 *"Spec self-review"* — 자기 문서 자기 리뷰(Law 2 위반)다. spec-distill이 design doc에 `spec-reviewer`를 덧댄 이유가 이것이고, **brief에는 같은 구멍이 그대로 있다.** NG3(`check_brief.py:20`·`spec-reviewer.md:17`)가 *"brief는 분리 review 대상이 아니다"* 라고 쓰는 반면 NG6는 *"게이트는 form·존재만 본다. 의미는 orchestrator + 독립 adversary가 담보"* 라고 쓴다 — brief용 adversary는 존재하지 않는다. 이 문서가 그 긴장을 NG6 쪽으로 해소한다.

---

## 2. Goals

1. **충실도 축에 실제 거절 메커니즘.** 격리된 리뷰어가 §2↔§6 왜곡을 hard gate로 잡는다.
2. **방향성 축의 발화 조건 생성.** C4가 작동하려면 *뒤집을 이유를 찾는 역할*이 있어야 한다. 산출은 판정이 아니라 **사용자에게 낼 질문**이다.
3. **원문 완전성의 기계 집행.** payload-only 리뷰어가 볼 수 없는 축(발화 누락·요약 삽입)을 state 원장 대조로 닫는다.
4. **핸드오프 품질의 측정.** 순진한 냉독으로 *"이 문서가 실제로 어떻게 읽히나"* 를 재고, 판정은 사용자에게 남긴다.
5. **모델 다양성을 두 축 모두에.** codex를 축별 2회 호출로 붙이고, codex 부재가 어느 축도 죽이지 않게 한다.
6. **하니스의 *제약* 무증가** (E10). 리뷰가 지적한 대로 *"무게 0 증가"* 는 비측정 표현이었다 — 이 spec은 에이전트 3 · 모델 호출 5 · 스크립트 4 · state 키 3 · 승인 게이트 1을 **늘린다.** 그것들은 **능력 증가**이고 E10의 대상이 아니다. E10이 금지하는 것은 *모델을 옥죄는 규칙*이며, 측정 가능한 세 항목으로 못 박는다:
   - **훅 파일 · `hooks.json` 항목 추가 0개** (AC22)
   - **이빨 없는 결정론 체크 0개** — 검사 대상이 통과 조건을 직접 쓰는 검사를 도입하지 않는다(§9의 기각 항목)
   - **횟수 상한은 실재 루프에만** — 단일 호출(codex `exec`, 각 에이전트 1회 dispatch)에 상한 **0개**. 상한이 붙는 곳은 **실재 루프 둘**뿐이다: critic 재리뷰(`brief_critic_rounds` ≤ 2, AC13)와 오염 재시도(`brief_contamination_retries` ≤ 2, AC2c). 둘 다 종료 조건 없는 반복이 가능한 진짜 루프이므로 상한이 load-bearing이다 (round-2 리뷰가 후자의 무상한을 **block**으로 적발 — 초안은 *"루프는 하나뿐"* 이라 쓰면서 두 번째를 무상한으로 만들었다)

---

## 3. Non-goals

- **`superpowers` 플러그인 수정** — 외부 플러그인. 체크리스트 7번의 self-review 구멍은 관측 사실로만 기록한다.
- **정정 이벤트 스키마 신설** — Spec A의 defer 유지(§11 ①).
- **payload 포맷 변경** — Spec A가 확정한 8섹션·frontmatter 계약을 소비만 한다. audit 템플릿의 텔레메트리 절 추가는 포맷 변경이 아니다.
- **기존 brief 3건 리뷰** — 파이프라인은 방금 쓴 brief에만 돈다. 과거 brief를 리뷰에 넣는 경로를 만들지 않는다(게이트의 선례와 동일).
- **`check_brief.py`의 state 의존 추가** — "brief 파일만 읽는다" 불변식 유지(AC16).
- **훅 표면 확장** — `spec-write-validator.py`의 `PATH_PREFIX`를 interview 디렉토리로 넓히지 않는다.
- **리포 전역 억제 제거** — E10의 전역 집행은 `docs/handoffs/2026-07-26-...-sweep.md`의 몫. 이 spec은 **자기 신규 컴포넌트에만** 선제 적용한다(`model: inherit` 등).

---

## 4. Constraints

`source`(누가) × `status`(얼마나 굳었나) 두 축. 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론.

### 4.1 인터뷰에서 확정된 것 (Spec A와 공유)

| id | source | 내용 |
|---|---|---|
| **C5 (최상위)** | 🗣 | brief는 방향을 잡는 문서다. 규약·프로토콜은 brief가 아니라 그것을 집행하는 곳(템플릿·SKILL·에이전트 프롬프트)에 산다 |
| C4 | 🗣 | 사용자 출처 항목도 이유가 있으면 보고 후 재결정 가능. 임의 변경만 불가 |
| C6 | ☑ | `source`와 `status`를 직교 분해 |
| D1 | ☑ | payload + audit 2파일. 분할선 = 재논쟁 차단에 쓰이는 것은 payload / 순수 텔레메트리만 audit |
| **D2** | ☑ | brief-critic은 payload 파일 하나만 받는 **hard gate**. 쓰기 도구 없음(Law 2). audit·transcript 미제공 — 인터뷰 프레이밍을 흡수하면 그 프레이밍의 오역을 못 보기 때문 |
| **D3** | 🗣 | 리뷰는 2단계. critic 이후 최종 도달 시 **readback**(순진한 cold read → 요약 보고). 대상은 "사용자와 Claude 양쪽" |
| **D4** | 🗣 | brief 리뷰에 **codex도 활용** — 별-모델 독립 리뷰어 |
| **D5** | 🗣 | 리뷰의 축은 **둘**. (a) 충실도 — 모델이 사용자 말을 왜곡·누락·삽입했는가. (b) 방향성 타당성 — 사용자가 잡은 방향 자체가 틀린 것은 아닌가 |

### 4.2 이 브레인스토밍에서 확정한 것

| id | source | 내용 |
|---|---|---|
| **E10 (최상위)** | 🗣 | **하니스를 무겁게 만들어서 능력을 제한하는 것은 절대 안 된다.** 트레이드오프가 아니다 — 능력 제한이 확인되면 제거가 default이고, 유지를 주장하는 쪽이 load-bearing 근거를 댄다. **다른 제약과 충돌 시 C5와 나란히 이긴다** |
| E11 | 🗣 | 스크립트·스킬 등 **모듈화는 devbrew 전역에서 진행되어야 하는 부분**이다 |
| E1 | ☑ | 설계 입력 = shipped 템플릿 + `check_brief.py` 게이트 계약(실물 brief 대용). 첫 실물 dogfood는 검증 계획으로 |
| E2 | ☑ | 한 스펙에 D2~D5 전부 |
| E3 | ☑ | **3 에이전트 + codex, 계약별 분리** (OQ8 해소) |
| E4 | ☑ | in-skill 배치 + 새 훅 0개 |
| E5 | 🗣 | 순서 = **방향성(codex 동반) 먼저 → 충실도는 루프 없이 단발.** 더 필요하면 orchestrator가 요청할 수 있게 |
| E6 | 🗣 | **codex도 당연히 repo를 볼 수 있어야 한다** |
| E7 | 🗣 | **codex도 웹서치가 가능하다** (사용자 지적 → 실측 확인, Implicit context) |
| E8 | ☑ | 수정 발생 시 fresh critic **재리뷰 1회 필수**, 그 뒤 Issues면 orchestrator 판단 + 상한 |
| E9 | 🗣 | **codex는 두 번 나눠서 축별로** 돌리는 것이 더 깔끔하다 |
| E12 | ☑ | 원문 완전성 검사를 게이트가 아니라 **별도 모듈**로 (E11의 귀결) |
| E13 | ☑ | readback에 **출력 형식을 주지 않는다** — 형식 자체가 오염원 |
| E14 | ☑ | §6은 **append-only** — 추가 허용, 기존 항목 본문 변경 금지 |

> ✎ **E10은 이 문서 자신에게 두 번 적용됐다.** 초안은 (i) codex 검색 횟수를 프롬프트로 묶고 (ii) 게이트에 *"리뷰 라운드 기록이 있는가"* 검사를 넣으려 했다. 사용자가 *"코덱스나 클로드를 억제하는 느낌"* 으로 교정해 둘 다 철회했다. (i)은 단일 `exec` 호출에 이미 턴 경계가 있어 순수 손실이었고, (ii)는 검사 대상이 통과 조건을 직접 쓰는 이빨 없는 의례였다. §9에 기각 항목으로 남긴다.

### 4.3 보안 · 정책

`CLAUDE.md` P21(state·프롬프트에 secret 금지 — placeholder 참조) · Law 2(리뷰어는 `tools:` allowlist로 쓰기 차단) · 킬 스위치 `DEVBREW_DISABLE_SPEC_DISTILL=1` / `DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1` / **신규** `DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW=1` · 플러그인 편집 시 `plugin.json` SemVer bump 필수 · persona 파일은 보안-민감 코드(리뷰어 약화 PR은 보안 리뷰 대상).

---

## 5. 설계

### 5.1 아키텍처 — 컴포넌트 넷

D5의 두 축은 **한 에이전트에 들어갈 수 없다.** (a)는 문서 내부 대조라 외부 정보가 오염원이고, (b)는 외부 근거 조사가 본질이라 도구 표면이 정반대다. 이것이 OQ8의 답이며 E3의 근거다.

| 컴포넌트 | 책임 (X / NOT Z) | `tools:` | `model:` | 입력 | 입력 통제 | 판정 권한 |
|---|---|---|---|---|---|---|
| **`brief-critic`** | 충실도(D5a) — §2 요약이 §6 원문을 왜곡·누락·삽입했나. **NOT** 방향의 옳음, **NOT** 외부 근거 | `Read` (inert) | `inherit` | payload **전문 inline**(`audit_file`·`name`·`created_at` redact), **경로 미제공** | 3층 (아래 층 0·1·2) — **격리 보장 아님**, 보장은 층 0(V9 미확정) | **hard gate** (D2) |
| **`brief-direction-reviewer`** | 방향성(D5b) — 사용자가 잡은 방향 자체가 틀렸을 가능성. **NOT** 충실도, **NOT** 문서 수정, **NOT** 방향 변경 | `Read, Grep, Glob, WebSearch, WebFetch` | `inherit` | payload 경로 + repo + 웹 | 없음 — 이 축엔 근거 폭이 본질 | **보고만** → C4 경로 |
| **`brief-readback`** | 냉독(D3) — 이 문서가 실제로 어떻게 읽히나. **NOT** 검증, **NOT** 의도 확인, **NOT** 결함 사냥 | `Read` (inert) | `inherit` | payload **전문 inline**(`audit_file`·`name`·`created_at` redact), **판정 기준·출력 스키마 무제공** | 3층 (아래 층 0·1·2) — 격리 보장 아님 | **advisory 측정** |
| **codex** (에이전트 파일 아님) | 별-모델 독립(D4) — 축별 2회 호출 | `codex exec -s read-only`, `-c tools.web_search=true` | 사용자 config 상속 | payload 경로 + repo + 웹 | 없음 (E6) | 축별로 위 1·2에 병합 |

**inert `Read`가 유일한 도구인 이유.** `tools:`를 비우면 agent 정의가 유효하지 않고, `Grep`/`Glob`을 주면 `docs/superpowers/interview/*`를 훑어 audit(`<payload-basename>.audit.md` — 이름이 결정론적)에 도달한다. 리포 선례: `quality-gates:pr-understanding-builder`(*"단일 inline 컨텍스트 blob만 받는, 호출하지 않는 inert `Read`가 유일한 도구인 read-nothing 생성기"*).

**입력 통제는 3층이고, 그중 보장은 층 0 하나다.** 초안은 *"경로를 안 주면 도달 불가"* 로 완전 격리를 주장했으나 두 경로로 뚫린다:

1. **payload frontmatter의 `audit_file`** 키에 audit 파일 basename이 그대로 실려 있다(`templates/interview-brief-template.md:8`). payload 전문을 inline하면 그 basename도 함께 들어간다.
2. **재구성.** `audit_file`을 redact해도 payload의 `name:`(kebab-topic) + `created_at:`으로 `<date>-<topic>-interview.audit.md` 를 조립할 수 있고, 관행 디렉토리(`docs/superpowers/interview/`)는 리포 전역에 서술돼 있다.

즉 **`Read`를 가진 에이전트에게 완전 격리는 원리적으로 불가능하다.** 이 절에서 쓰는 말은 *"격리"* 가 아니라 **입력 통제**다 — 보장하는 것과 보장하지 못하는 것을 나눠 적는다.

**층 0 — 구조적 강제 (목표 상태, plan 첫 태스크의 blocking probe).** payload가 프롬프트에 inline되므로 critic·readback은 **도구가 하나도 필요 없다.** `tools:`를 빈 값으로 선언한 agent가 런타임에서 유효하게 resolve·dispatch되면 audit 도달 경로가 **물리적으로 사라지고** 아래 층 1·2가 전부 불필요해진다.

> **이 세션에서 실측할 수 없다.** 에이전트 레지스트리는 **세션 시작 스냅샷**이라 지금 새 agent 정의를 만들어도 이 세션에서 resolve되지 않는다. 실측하지 못한 것을 보장으로 쓰지 않기 위해, **구현 첫 태스크로 probe를 강제**하고 결정 규칙을 미리 못 박는다:
>
> | probe 결과 | 결정 |
> |---|---|
> | zero-tool agent가 **유효** | critic·readback을 zero-tool로 선언. 층 2 검출은 **순수 defense-in-depth**로 남고(발화하지 않음이 정상), AC2c 재시도 상한은 dead code로 유지 |
> | zero-tool agent가 **무효**(런타임 거부) | `Read` + 층 1·2 유지. 이 문서의 주장은 *"입력 최소화 + 오염 검출"* 이며 **어디서도 "격리"라고 쓰지 않는다** |
>
> probe는 `plugin-audit:smoke-probe`가 이미 하는 일(*"project-level agent 정의가 resolve되고 frontmatter tools allowlist가 런타임에 실제로 집행되는지 검증"*)의 변형이다.

**층 1 — 예방(부분).** inline blob을 만들 때 frontmatter의 **`audit_file` · `name` · `created_at` 세 값을 redact**한다. `audit_file`은 직접 벡터이고, `name`+`created_at`은 `<date>-<topic>-interview.audit.md` **재구성** 재료다. 세 값을 잃어도 손실이 없다 — 충실도 판정은 body §2 ↔ §6 대조이고 frontmatter ↔ body 일치는 게이트 bijection B가 기계 보장하며, 주제는 본문 H1 제목에 남아 readback의 냉독에도 지장이 없다.

> ⚠️ **재구성이 완전히 닫히지는 않는다.** H1 제목이 주제를 담고 관행 디렉토리는 리포 전역에 서술돼 있어, 날짜를 추측하면 여전히 조립 가능하다. 층 1은 *쉬운 길*을 없애는 것이고 보장이 아니다 — 보장은 층 0뿐이다.

**층 2 — 검출(defense-in-depth, 격리 메커니즘이 아니다).** audit에는 payload 템플릿에 **실측으로 0건인** 어휘가 있고 그것은 닫힌 열거다(각 항목 `grep -cF` payload=0 / audit=1 확인, 2026-07-27):

`Coverage Ledger` · `floor:root_problem` · `floor:landscape` · `floor:skepticism` · `floor:blind_spot` · `floor:open_questions` · `probe_count` · `web_sweep_count` · `web_search_count` · `type: interview-audit` · `Interview Audit` · `프로세스 로그` · `게이트 실행 기록` — **13항목.**

> **`ST<N>`은 이 열거에서 제외한다** (round-2 리뷰가 적발). payload 템플릿 `:75`가 `verdict: defended — ST1`을 **설계상** 담으므로(payload=1 실측) *"payload에 결코 없다"* 는 전제가 거짓이고, critic이 §5의 그 항목을 지적하며 `ST1`을 인용만 해도 **깨끗한 라운드가 오염으로 오판**된다. 헤딩 포맷(`#### ST<N>`)으로 좁히는 안도 검토했으나, critic 산출물이 헤딩 문법을 재현할 이유가 없어 실효가 낮고 오판 위험만 남는다 → 제거하고 검증된 4항목으로 대체.

critic·readback **산출물**에 13항목 중 하나라도 나타나면 그 에이전트가 audit에 도달했다는 증거이므로 **그 라운드를 무효화하고 fresh 에이전트로 재dispatch**한다.

**층 2의 재시도에도 상한이 있다** (round-2 리뷰가 **block**으로 적발). 무상한 재dispatch는 `brief_critic_rounds`와 별개의 **두 번째 실재 루프**이고, 층 1이 재구성을 완전히 닫지 못하므로 같은 입력을 받은 fresh 에이전트가 같은 재구성을 반복할 개연성이 있다(결정론적 입력 → 상관된 행동) — 그러면 detect→invalidate→redispatch가 무한 반복된다. CLAUDE.md의 *Unbounded autonomy* 금지 패턴이다. 그래서:

| 카운터 | 상한 | 초과 시 |
|---|---|---|
| `brief_contamination_retries` | **2** | **Step B forced escalate** — 오염 사실과 재시도 이력을 사용자에게 올리고 그 축을 *"검증 불가"* 로 표시. 자동 재시도 없음 |

이 카운터는 `brief_critic_rounds`와 **독립**이다(오염 라운드는 리뷰가 아니었으므로 리뷰 라운드로 세지 않는다). 그래서 **이 spec에 상한이 붙는 루프는 둘**이며 Goal 6이 그것을 그대로 적는다.

**프롬프트에 *"audit을 읽지 마라"* 를 넣지 않는다.** audit의 존재와 그것이 인터뷰 프레이밍을 담는다는 사실을 알리는 것 자체가 힌트이며, readback 오염(기준을 알면 그 답을 회피)의 같은 클래스다. 금지 문구 대신 **모르게 두고 검출**한다.

**격리는 능력 억제가 아니라 실험 설계다** — E10의 적용 대상이 아니다. critic이 audit을 읽으면 *"왜 이렇게 재구성했는지"* 를 먼저 납득해 재구성 오류 자체를 정당화하고(D2의 명시 근거), readback이 판정 기준을 읽으면 확인해주는 쪽으로 붕괴한다(Spec A 인터뷰에서 **실측**: 시범 에이전트가 payload 안 red-flag 기준을 읽고 그 답을 회피했다고 스스로 보고).

**codex의 비격리는 손실이 아니라 정보로 쓴다.** codex는 repo를 보므로(E6) audit에 도달할 수 있고 프레이밍을 흡수할 수 있다. 격리된 critic이 잡은 것과 전체를 본 codex가 잡은 것의 **차이가 곧 "사정을 알면 안 보이게 되는 것"의 측정치**다.

**권위 계약 (precedence) — 명시.** 두 리뷰어의 관계를 한 가지로 못 박는다:

| 층 | 규칙 |
|---|---|
| **verdict** | **fail-closed 합집합.** critic 또는 codex 중 **어느 쪽이든** Issues를 내면 `fidelity_verdict = needs_revise`. codex는 advisory가 아니라 **binding**이며 verdict를 단독으로 만들 수 있다 |
| **finding 기각** | 저자(orchestrator)는 어느 리뷰어의 finding도 **임의로 기각하지 못한다.** 반영하지 않을 findings는 이유와 함께 Step B 게이트에서 **사용자에게 올린다**(P17) — 저자의 자기승인 경로 차단 |
| **`codex_isolated: false`** | **verdict 입력이 아니다.** 저자가 findings를 *읽을 때* 붙는 라벨 — 이 finding은 프레이밍을 흡수한 리뷰어가 낸 것일 수 있으니 그 가능성을 함께 고려하라는 뜻. 등급을 낮추는 근거가 아니다 |
| **disagreement** | 합집합이므로 verdict를 흔들지 않는다. 어느 한쪽만 올린 finding도 그대로 verdict를 만든다 |

`reviewing-spec`의 기존 `merge_review.py`가 이미 이 모델이다 — codex verdict가 Claude verdict를 **overturn**할 수 있고 그때 advisory를 낸다. codex를 advisory로 두는 것은 리포가 반복 학습한 것(별-모델이 유일 backstop)의 정반대 방향 회귀다.

### 5.2 데이터 흐름 — 3단계

E5의 순서다. 방향성이 먼저인 이유: 방향성 지적은 C4 경로로 사용자 재결정을 유발하고, 재결정이 나면 §2 제약·§3 OQ가 바뀐다. 충실도를 먼저 수렴시키면 그 수렴이 무효화된다. **충실도는 문서가 더 이상 바뀌지 않는 시점에 본다.**

```
진입   check_verbatim_coverage.py <payload> <state>   ← 첫 액션 (5.5)
         ↓  red면 §6 보완 후 재실행
[1] 방향성   payload 경로 ─┬─→ brief-direction-reviewer   (repo + 웹)
                          └─→ codex #1  (repo + 웹, 방향성 전용 체크리스트)
                                   ↓  두 리뷰어의 C4 항목을 나란히 (병합 없음)
                       ⟦사용자⟧ 보고 → 재결정 → payload 수정 (선택, 5.4)
                                   ↓
[2] 충실도   payload 전문 inline ─→ brief-critic  (격리)
             payload 경로 ────────→ codex #2  (repo, 충실도 전용 체크리스트)
                                   ↓
                       merge_brief_review.py → fidelity_verdict
                                   ↓
              Issues → §2 수정 → fresh critic 재리뷰 1회 (필수, E8)
                     → 또 Issues → orchestrator 판단 (brief_critic_rounds 상한 2)
                                   ↓
[3] 냉독     payload 전문 inline ─→ brief-readback → 자유 프로즈 요약
                                   ↓
              orchestrator가 요약 ↔ payload §0/§1/§2/§3/§7 대조 → gap 목록
                                   ↓
Step B  proceed 게이트 = 확정 후보 + 방향성 C4 항목 + readback 요약 전문 + gap + 모든 degrade
```

**codex 2회 축별 분리(E9)가 지우는 것들.** 초안의 "codex 1회 + payload 해시 비교 + 조건부 재실행 + stale 표시"는 장부를 하나 만들고 있었다. 무조건 2회로 가면 `payload_changed` 플래그·해시 비교·`codex_findings_to_yaml.py`의 `axis` 필드 확장·병합의 축 분기·stale 개념이 **전부 사라진다.** 그리고 각 프롬프트가 한 축만 담아 *"이것만 봐라"* 가 되므로 깊이가 올라간다 — 능력을 깎는 상한과 **반대 방향의 집중**이다. **codex #2는 항상 최종 문서를 보므로 stale이 원리적으로 불가능하다.**

**방향성은 병합하지 않는다.** verdict가 없고 산출물이 *사용자에게 낼 질문*이라 합칠 대상이 없다. Claude와 codex의 C4 항목을 나란히 제시하고, 같은 지적이 겹치면 orchestrator가 합쳐 보여준다 — 문구가 달라 결정론 dedup은 불가하며 모델 판단에 맡긴다(E10).

**충실도 루프를 두지 않는 이유.** `reviewing-spec`의 라운드 루프 + cap 5는 design doc 리뷰가 *설계 결함*을 찾는 반복 개선이라 정당하다. 충실도는 *"§2 요약이 §6 원문을 왜곡했나"* 라는 좁고 거의 기계적인 축이라 반복 수렴 대상이 아니다 — 루프는 trivia ceremony였다. 대신 E8이 Law 2 최소선을 지킨다: **수정이 발생하면 fresh critic 1회는 구조적으로 필수**(writer가 자기 수정을 승인하는 경로 차단)이고, 그 뒤는 orchestrator 판단 + 상한 2.

**readback이 3단계인 이유.** 문서가 더 이상 바뀌지 않는 시점의 문서를 읽어야 측정에 의미가 있다. 방향성·충실도는 payload를 바꿀 수 있으므로 그 뒤다.

### 5.3 산출물 형식

| 산출 | 형식 | 근거 |
|---|---|---|
| `critic-issues` | `**Status:** Approved \| Issues Found` + `brief-critic-issues` sentinel JSON (`category`/`target_section`/`severity`/`message`) | `spec-reviewer`의 기존 포맷 재사용 — 파싱 선례가 있고 저자가 아는 모양 |
| `direction-findings` | `brief-direction-findings` sentinel YAML (`id` / `무엇을 뒤집자는 것인가` / `근거 URL` / `사용자가 결정할 질문`) | verdict 필드가 **없다** — 산출물이 판정이 아니라 질문이므로 |
| readback | **자유 프로즈. sentinel·스키마 없음** | E13 — 필드 이름이 곧 "무엇을 찾아야 하는지"의 힌트가 되어 측정을 오염시킨다. 구조화는 받는 쪽(orchestrator)이 한다 |
| codex | `codex_findings_to_yaml.py` 스키마 **무변경** | 호출별로 축이 이미 정해져 `axis` 필드가 불필요(E9의 배당금) |
| 병합 | `merge_brief_review.py` stdout: `fidelity_verdict` · `fidelity_findings` · `codex_isolated: false` · `codex_degraded` · `advisory[]` | 충실도만 병합(방향성은 병합 대상 아님) |

**`critic-issues`의 `category` 6종** — 이 열거가 Law 3 compounding substrate다(리뷰가 놓친 결함류가 나오면 여기와 체크리스트를 편집하는 것이 compounding 이벤트):

| category | 무엇 |
|---|---|
| `distortion` | §2 statement가 §6 원문의 뜻을 바꿈 |
| `omission` | 원문의 핵심이 §2에서 빠짐 |
| `insertion` | 사용자가 하지 않은 말이 제약으로 들어옴 |
| `provenance_mislabel` | 🗣/☑/✎ 오표기 (Spec A가 자기 초안에서 저지른 클래스) |
| `authority_syntax` | 권위 문법 재도입 (*"확정·재논쟁 금지"* 계열) |
| `evidence_unsupported` | `evidence: S<N>`가 실재하지만 그 원문이 statement를 뒷받침하지 않음 — **Spec A가 V9 수동으로 미룬 갭을 여기서 닫는다** |

### 5.4 수정 권한 · C4 재결정 경로

| 섹션 | 권한 |
|---|---|
| §0 / §1 / §3 / §4 / §5 / §7 | 자유 수정 |
| §2 제약 | 자유 수정 — **단 frontmatter `user_sourced_items`와 동시.** bijection B가 statement 내용까지 대조하므로 한쪽만 고치면 게이트 red |
| **§6 사용자 원문** | **append-only** (E14). `S<N>` 항목 **추가**만 허용. 기존 항목 본문 변경 금지 — P21 secret placeholder 치환만 예외 |

**§6를 append-only로 묶는 이유.** §6는 재구성 대 재구성의 순환 검증을 막는 유일한 앵커다(인터뷰 Blind Spots가 경고한 실패 양식). 자유롭게 고칠 수 있으면 *critic이 지적 → orchestrator가 원문을 지적에 맞게 고쳐 통과* 라는 laundering이 열린다. 추가는 덮어쓰기가 아니므로 provenance가 온전히 남는다.

**C4 재결정이 일어났을 때** (방향성 보고 → 사용자가 제약을 뒤집음):

1. `user_sourced_items`의 해당 항목 `status` 변경 또는 항목 교체.
2. 그 **결정 발화를 §6에 새 `S<N>`으로 추가**한다 — 기존 항목 수정이 아니다(E14와 정합). state의 `user_statements`에도 append되므로 `check_verbatim_coverage.py`가 다음 실행에서 대조 대상으로 삼는다.
3. 뒤집힌 방향은 §5 `기각` 항목에 *무엇을 왜 버렸는지* 로 남긴다 — **증거 문장**이며 권위 문장이 아니다(C5).
4. payload 재저장 → `check_brief.py gate` 재실행 → `check_verbatim_coverage.py` 재실행.

리뷰어는 방향을 **바꾸지 않는다.** 사용자에게 올리고 사용자가 결정한다(D5b·P17).

### 5.5 게이트 · 원문 완전성

**`check_brief.py`의 변경은 docstring 한 곳뿐이다.** 현행 *"This is NOT a Law 2 reviewer (NG3) — the brief gets no separated review."* 가 이 spec으로 거짓이 된다. 게이트는 여전히 Law 1 구조 자기검사이고 **그 위에 Law 2 분리 리뷰가 얹혔다**로 고친다. `agents/spec-reviewer.md:17`의 같은 서술도 동일하게 교정(AC17).

**"brief 파일만 읽는다" 불변식은 유지한다**(AC16). state 의존을 게이트에 넣으면 임의 brief 파일에 게이트를 돌릴 수 없게 된다.

**원문 완전성은 별도 모듈** — `scripts/check_verbatim_coverage.py <payload> <state>` (E12·E11):

| 레벨 | 검사 | 판정 |
|---|---|---|
| **L1** | state `user_statements[].id` 집합 ⊆ payload §6 `**S<N>**` 앵커 집합 | **red** — 발화가 통째로 빠짐 |
| **L2** | 정규화(공백 collapse · `>` 인용 마커 제거) 후 §6 해당 항목이 state `text`를 **포함**하는가 | **red** — 앵커는 있는데 요약해서 넣음(은밀한 누락) |
| 예외 | P21 placeholder 토큰이 양쪽 중 하나에 관여하면 L2를 **advisory로 강등** | secret 치환은 허용 변환 |

출력 JSON: `{"missing_ids": [...], "not_contained": [...], "advisories": [...]}`.

**exit code를 두 실패로 가른다** — 호출자가 구분할 수 없으면 하나를 다른 하나로 오독한다(qg의 `exit 3`/`exit 4` 선례):

| exit | 뜻 | 호출자 동작 |
|---|---|---|
| `0` | 위반 없음 | 진행 |
| `1` | **위반 발견** (`missing_ids` 또는 `not_contained` 비어 있지 않음) | **차단** — §6 보완 후 재실행. 리뷰 단계로 넘어가지 않는다 |
| `3` | **검사 불가** (state 파일 부재·파싱 실패 — *의도적으로 매핑된* 경로) | **degrade 후 계속** — degradation record 기록 + Step B 게이트까지 전파 |
| `4` | **내부 오류** (미처리 예외) | `3`과 동일 처리 + 오류 전문을 record의 `reason`에 |
| 그 외 non-zero | 예측 못 한 실패 | `3`과 동일하게 취급(indeterminate ≠ clean) |

`1`과 `3`을 합치면 *"검사를 못 했다"* 가 *"원문이 빠졌다"* 로 읽혀 정상 brief를 막거나, 반대로 합쳐서 degrade로 처리하면 실제 누락이 통과한다.

> ⚠️ **`4`가 반드시 필요한 이유 (리뷰가 적발).** Python 미처리 예외의 **기본 종료 코드가 `1`** 이다. 예외 처리 규율을 안 적으면 예상 못 한 버그가 *"위반 발견"* 으로 오분류돼 **정상 brief를 차단**한다. 그래서 `main()`을 top-level `try/except`로 감싸 **어떤 예외도 `4`로 내리는 것을 계약으로** 못 박는다 — *"exit 1은 오직 명시적 위반 판정에서만 나온다"*. T20이 이 계약을 잠그고 mutation(고의 `raise` 주입)으로 이빨을 증명한다.

**L2가 실질 값이다** — Spec A가 *"§6은 압축 대상이 아니다"* 를 못 박았지만 집행 수단이 없었다. L2는 §6 append-only(E14)를 **부분적으로** 집행한다: 기존 항목 본문만 바뀌면 state `text` 포함이 깨져 red가 난다.

> ⚠️ **L2는 append-only를 완전히 봉쇄하지 않는다.** orchestrator가 §6과 state의 `user_statements[].text`를 **함께** 고치면 포함 검사가 통과한다 — 양쪽 다 orchestrator가 쓸 수 있고 state는 git-ignored라 이력 대조도 불가능하다. L2가 잡는 것은 *§6만 고친 흔한 경우* 이고, 조율된 양쪽 편집은 V5(사람)가 본다. 이 한계를 §6.1에 명시한다 — *"기계적으로 봉쇄"* 라고 쓰지 않는다(Spec A가 같은 과장을 round-5에서 기각한 클래스).

**호출 시점**: `reviewing-brief` **진입 첫 액션**, 그리고 §6에 append가 일어날 때마다 재실행. 진입에 두는 이유 — §6가 불완전하면 방향성 리뷰도 불완전한 문서를 보고, critic은 §6를 ground truth로 쓰므로 판정 자체가 무의미해진다.

**이 검사가 payload-only critic의 구조적 한계를 닫는다.** critic은 비교 대상이 문서 밖에 있어 원리적으로 이 축을 볼 수 없다. 결정론이 여기 정당한 이유는 (a) 정확성 게이트이고 (b) **기계가 서로 다른 두 파일을 대조**하므로 우회하려면 양쪽을 다 조작해야 한다는 것 — 이빨이 있다.

### 5.6 에러 처리 · graceful degradation

**3-에이전트 분리(E3)의 배당금이 여기서 나온다.** codex가 사라지면 두 축 모두 Claude 담당자가 남아 **축이 죽지 않고 모델 다양성만 잃는다.** 기각한 "방향성을 codex에 몰기" 안에서는 같은 부재가 축 전체의 fail-open이었다.

**"loud advisory"의 정의 — degradation record.** 초안은 이 말을 반복하면서 표현·목적지·지속성·렌더링을 정의하지 않았다(리뷰가 적발). 구조를 못 박는다:

```yaml
brief_review_degradations:          # state.local.md, append-only
  - component: critic | direction_reviewer | readback | codex | verbatim_coverage | pipeline
    reason: <한 줄 — 원인. exit 4면 오류 전문>
    affected_axis: fidelity | direction | readback | completeness | all
    verification_status: skipped | degraded | unavailable | retried
```

> `component`에 **`critic`이 있어야** 하고 `verification_status`에 **`retried`가 있어야** 한다 (round-2 리뷰가 적발). 초안의 열거는 critic 오염 이벤트를 표현할 수단이 없었고 — critic이 빠져 있었다 — *"탐지 후 fresh 재시도로 자체 복구"* 에 맞는 status 값도 없었다(`skipped`/`degraded`/`unavailable` 어느 것도 사실이 아니다: 축은 결국 커버된다). 재시도 상한 초과로 축이 죽은 경우는 `unavailable`이다.

- **목적지**: state의 `brief_review_degradations[]`에 append(지속) **AND** 발생 즉시 사용자에게 표시(즉시성).
- **렌더링**: Step B `AskUserQuestion`의 **question 텍스트에** 각 record를 한 줄로 싣는다 — 옵션 description이 아니라 question 본문이어야 사용자가 옵션을 고르기 *전에* 본다.
- **비어 있음의 의미**: 배열이 비면 *"degrade 없음"* 이고, 그 자체를 게이트에 한 줄로 명시한다(침묵과 구분).

| 실패 | 처리 | 축 생존 | AC |
|---|---|---|---|
| `DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1` 또는 codex 미설치 | 두 codex 호출 skip + record(`component: codex`, `affected_axis: all`). `codex_degraded: true` | ✅ 양 축 — Claude 담당자 잔존 | AC9 |
| **웹 예산 소진** (`SESSION_CAP = 8`) | **orchestrator가 dispatch 전에** `web_budget.py check` → 소진이면 *"웹 없이 repo+payload 근거로"* 조건을 프롬프트에 실어 dispatch + record. **dispatch 후 `increment` 1회**(dispatch 단위 — 아래 한계 참조). **codex #1의 웹은 이 예산 밖이라 살아 있음** | ✅ 외부 근거가 완전히 죽지 않음 (이중화) | **AC24** |
| `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` | 양쪽 웹 없이 진행 + record (게이트의 인용 완화 선례와 정합) | ⚠️ 방향성이 repo 근거만으로 축소 — 명시 | **AC24** |
| `check_verbatim_coverage.py` exit `3`/`4` | degrade 후 계속 + record(`affected_axis: completeness`, `verification_status: skipped`). 조용한 통과 금지 | ⚠️ 명시된 미검증 | AC12 · AC15 |
| `brief-readback` 실패·빈 출력 | record(`verification_status: unavailable`). **"gap 0"으로 읽지 않음** (indeterminate ≠ clean — qg mutation guard 선례) | — advisory 축 | AC15 |
| critic·readback 산출에 **audit 전용 어휘 13항목** 검출 | 그 라운드 무효화 + fresh 재dispatch + record(`verification_status: retried`). `brief_critic_rounds`와 **독립**인 `brief_contamination_retries` **≤ 2**, 초과 시 Step B forced escalate + 그 축 `unavailable`(§5.1 층 2) | ✅ 오염 라운드 폐기 · 상한 초과 시 사용자 판정 | **AC2b · AC2c** |
| critic 재리뷰 상한 2 초과 | Step B 게이트에 전체 issue 이력 첨부해 **사용자 판정**(forced escalate — `reviewing-spec` hard-cap 선례) | ✅ 사용자가 최종 | AC13 |
| `DEVBREW_DISABLE_SPEC_DISTILL=1` | 즉시 abort, state 보존 | — | — |
| `DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW=1` (신규) | `reviewing-brief` 전체 skip + record 후 Step B로 직행 | 사용자 통제(P17) | AC18 |

**`brief-direction-reviewer`는 자기 예산을 확인할 수 없다** — `tools:`에 `Bash`가 없다(Law 2). 그래서 `web_budget.py` 판정은 **orchestrator 책임**이다. 리뷰어에게 `Bash`를 주는 것은 Law 2 위반이므로 대안이 아니다.

> ⚠️ **계측 단위가 다르다 — 초안의 등치는 부정확했다** (round-2 리뷰가 적발). `web_budget.py`의 기존 관행(`conducting-interview`)은 **매 웹 호출 전 `increment`** 하는 **호출 단위** 계측이다. 여기서는 리뷰어 turn *내부*의 개별 `WebSearch`/`WebFetch`를 리뷰어도(`Bash` 없음) orchestrator도(내부 호출을 볼 수 없음) 셀 수 없으므로, 할 수 있는 것은 **dispatch 단위** 계측(dispatch당 `increment` 1회)뿐이다. 따라서 이 컴포넌트에 대해 `SESSION_CAP = 8`은 *"검색 8회"* 가 아니라 *"dispatch 8회"* 를 의미한다. 초안은 *"기존 increment-then-check 관행과 같은 위치"* 라고 썼는데 **사실과 다르다** — 그 관행은 호출 단위이고 이것은 dispatch 단위 스냅숏이다.
>
> 이 갭은 현재 도구로 닫히지 않는다(리뷰어의 내부 도구 호출 수를 orchestrator에 노출하는 경로가 없다). **§11 ⑩에 명시적 한계로 등재**하고, AC24는 *"호출 단위 계측"* 을 주장하지 **않는다.** 프롬프트로 검색 횟수를 묶는 것은 E10 위반이므로 대안이 아니다.

**모든 degrade는 Step B 게이트 question 텍스트까지 전파된다**(AC15). 사용자가 *"무엇이 안 돌았는지"* 를 옵션 선택 **전에** 본다 — **리뷰 생략 방지의 실제 메커니즘이 이것이다.** 결정론 체크가 아니다: 게이트는 *존재*만 보고 사용자는 *내용*을 보므로 사람이 더 강한 백스톱이며, 그래서 이빨 없는 기록 검사를 넣지 않는다(§9).

### 5.7 모듈 구조 · 상태 · 비용

**신규 skill로 가른다**(E11). `conducting-interview/SKILL.md`는 이미 557줄이고, 파이프라인 3단계를 넣으면 종료 절차가 문서를 지배한다.

- **`skills/reviewing-brief/SKILL.md`** — 파이프라인 3단계 + 병합 + 상한 + 산출 전달. `reviewing-spec`과 대칭.
- **`conducting-interview/SKILL.md`** — Step A.5 = *"여기서 `reviewing-brief`로 넘어간다"* **한 블록만** 추가. 종료 조건·Step A 게이트·Step B 구조는 불변(Step B는 산출물 실기만 추가).

**codex 두 호출의 모듈 경계** — 호출 경로는 같고 체크리스트만 다르다:

| | 개수 | 이유 |
|---|---|---|
| `scripts/run_brief_codex_reviewer.sh <axis> <payload> <project_dir> <out>` | **1** | codex 플래그·샌드박스·에러 처리·`detect_codex.sh` 연동이 동일. 2개로 복제하면 모듈화가 아니라 중복이고 한쪽만 고치는 drift가 생김 |
| `scripts/build_brief_codex_prompt.py --axis direction\|fidelity` | **1** | 조립 로직 동일 |
| `scripts/brief-codex-direction-checklist.md` · `scripts/brief-codex-fidelity-checklist.md` | **2 (데이터)** | 축마다 완전히 다른 내용. 코드가 아니라 데이터라 분리가 자연스럽다 — `ambiguity-blacklist.txt`가 같은 패턴의 선례 |

즉 **코드 1곳 · 데이터 2곳**. `build_spec_codex_prompt.py`는 재사용하지 않는다 — 최신 spec의 AC를 주입하는 성질이 brief 리뷰에서 모델 다양성을 죽이는 오염원이다.

**체크리스트가 `scripts/`에 사는 이유.** `docs/plugin-authoring.md`의 canonical 트리가 정의하는 optional 디렉토리는 `commands/` · `skills/` · `agents/` · `hooks/` · `scripts/` · `templates/` 여섯 개뿐이고 `prompts/`는 없다. 데이터 파일 선례는 `scripts/ambiguity-blacklist.txt`이며, `templates/`는 *"플러그인이 설치하는 정적 파일"* 이라 의미가 다르다. 새 디렉토리를 만들어 canonical 트리를 넓히는 것은 이 spec의 스코프가 아니다.

**축 분리의 검증 가능성.** 각 체크리스트 파일은 **body-unique 마커 한 줄**을 갖는다(예: 축 이름을 포함한 고유 문구). `build_brief_codex_prompt.py --axis direction` 출력은 자기 마커를 **포함**하고 타 축 마커를 **포함하지 않아야** 한다 — 이것이 T11의 판정 기준이다. 마커 없이는 *"한 축만 담았다"* 가 기계 검증 불가능하다.

**상태** — 새 파일 없음. 기존 `.claude/spec-distill/<session-id>/state.local.md`에 키 2개:

```yaml
brief_review_stage: direction | fidelity | readback | done
brief_critic_rounds: 0              # 리뷰 재라운드 상한 2 (E8·AC13). 오염 라운드는 카운트 안 함
brief_contamination_retries: 0      # 오염 재시도 상한 2 (AC2c). brief_critic_rounds와 독립
brief_review_degradations: []       # §5.6 degradation record, append-only
```

in-flight migration: 키 부재 → in-memory default(`direction`, `0`, `0`, `[]`) + advisory. 기존 선례 그대로(backward-rewriting 금지).

**비용** — `reviewing-brief`의 `cost_class: high`(에이전트 3 + codex 2). **동시 fan-out은 최대 2**(1단계)라 `N ≥ 5` hard 게이트에는 해당 없다. `high`이므로 CLAUDE.md 규약에 따라 **진입 시 1회** `AskUserQuestion` 승인 게이트를 둔다 — Step B의 proceed 게이트와 목적이 다르다(*"돈 쓸까요"* vs *"다음 단계"*)이므로 중복 의례가 아니다.

> **이 결정은 무조건이다** (리뷰가 적발). 초안은 이 게이트의 존속을 별 문서(억제 제거 sweep)의 *미래 결론*에 조건부로 걸었다 — hard AC를 외부 문서의 미정 결론에 의존시키면 이행 시점도 주체도 없어 집행할 수 없다. AC21은 조건 없이 성립하며, sweep이 나중에 `cost_class: high` 게이트 관행을 바꾸면 **그때 이 문서를 재오픈하는 별 사이클**로 처리한다(§11 ⑧에 갭으로 명시).

---

## 6. Acceptance Criteria

**표 무결성 규칙(저술용).** 모든 hard AC는 검증 열에 T-case 또는 V-item이 배정돼야 한다 — 검증이 배정되지 않은 AC는 *"미충족 시 미완료"* 를 집행할 수단이 없어 사실상 주석이다. 그리고 **참조는 양방향**이어야 한다: 여기서 인용한 모든 T/V는 §8에 실재해야 하고, §8의 모든 T/V는 여기서 최소 1회 인용돼야 한다(Spec A에서 편도 참조가 두 번 재발한 클래스).

| # | 기준 | 등급 | 검증 |
|---|---|---|---|
| AC1 | 파이프라인이 선언된 순서로 실행된다 — 진입 완전성 검사 → 방향성 → 충실도 → 냉독 → Step B | hard | V1 |
| AC2 | `brief-critic` dispatch 프롬프트에 payload 전문이 inline되고 **payload 경로가 실리지 않으며**, inline blob의 frontmatter `audit_file` 값이 **redact**된다 | hard | T8 · T24 · V6 |
| AC2b | critic·readback **산출물**에 audit 전용 어휘(**검증된 13항목** — `ST<N>` 제외)가 나타나면 그 라운드가 **무효화**되고 fresh 재dispatch된다. 열거의 각 항목은 payload 템플릿에 `grep -cF` **0건**이어야 한다 | hard | T23 · T26 · V6 |
| **AC2c** | 오염 재dispatch에 **독립 상한 `brief_contamination_retries` ≤ 2**가 있고, 초과 시 Step B forced escalate + 그 축을 `unavailable`로 표시한다. `brief_critic_rounds`와 상호 독립 | hard | T27 |
| AC2d | critic·readback의 zero-tool 가능성이 **구현 첫 태스크의 blocking probe**로 실측되고, §5.1 층 0의 결정 규칙대로 분기된다. probe 미실행 상태로 구현을 진행하지 않는다 | hard | V9 |
| AC3 | `brief-readback` dispatch 프롬프트에 출력 스키마·판정 기준이 없고, *"audit을 읽지 마라"* 류 금지 문구도 없다(존재 누설 방지) | hard | T9 · T24 · V2 |
| AC4 | 3 신규 에이전트의 `tools:`에 쓰기·실행·위임 도구가 없다 (Law 2) | hard | T7 |
| AC5 | 3 신규 에이전트의 `model:`이 `inherit`이다 (리터럴 핀 금지 — E10 선제 적용) | hard | T7 |
| AC6 | codex는 축별로 2회 호출되고 각 호출 프롬프트는 **한 축의 체크리스트만** 담는다 | hard | T11 · V1 |
| AC7 | `merge_brief_review.py`는 **어느 리뷰어든** Issues가 있으면 `needs_revise`를 낸다 (fail-closed 합집합). codex는 **binding** — 단독으로 verdict를 만들 수 있다 | hard | T5 |
| AC7b | 저자는 어느 리뷰어의 finding도 임의 기각하지 못한다 — 미반영 findings는 이유와 함께 Step B 게이트에서 사용자에게 올라간다 | hard | T25 · V4 |
| AC8 | 병합 산출에 `codex_isolated: false`가 **항상** 있다. 이 필드는 **verdict 입력이 아니라 저자용 라벨**이며 finding 등급을 낮추는 근거가 아니다 | hard | T5 |
| AC9 | codex 부재 시 두 축 모두 Claude 담당자로 진행되고 `codex_degraded: true` + loud advisory | hard | T5 · V4 |
| AC10 | `check_verbatim_coverage.py`가 state `S<N>` 누락(L1)을 red로 낸다 | hard | T1 |
| AC11 | 동 스크립트가 §6의 원문 미포함(L2)을 red로 내고, P21 placeholder 관여 시 advisory로 강등한다 | hard | T2 · T3 |
| AC12 | exit code가 **위반(`1`) · 검사 불가(`3`) · 내부 오류(`4`)를 가른다.** 호출자는 `1`에 차단, `3`/`4`에 degrade-and-continue. `main()`이 top-level `try/except`로 감싸여 **미처리 예외가 `1`로 새지 않는다** | hard | T4 · T19 · T20 |
| AC13 | 충실도 루프가 **§6.2의 전이 표대로** 동작한다 — 카운터 증가 시점·escalate 경계값(`== 2`)·orchestrator의 허용 행위가 닫힌 열거로 정의된다 | hard | T6 · V1 |
| AC14 | payload §6은 append-only — **§6만 고친 경우** 기존 항목 본문 변경이 red (P21 치환 예외). 조율된 양쪽 편집은 기계 검증 밖(§6.1) | hard | T2 · V5 |
| AC15 | 모든 degrade가 §5.6의 **degradation record 4필드**(`component`/`reason`/`affected_axis`/`verification_status`)로 state에 append되고 Step B `AskUserQuestion`의 **question 텍스트**에 렌더된다. 빈 배열도 *"degrade 없음"* 으로 한 줄 명시 | hard | T22 · V4 |
| AC16 | `check_brief.py`의 "brief 파일만 읽는다" 불변식 유지 — state 의존 추가 없음 | hard | T12 · T10 |
| AC17 | NG3 서술 2곳(`check_brief.py` docstring · `spec-reviewer.md`)이 교정된다 | hard | T13 |
| AC18 | `DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW=1`이 파이프라인 전체를 skip하고 loud advisory를 낸다 | hard | T14 · V4 |
| AC19 | `plugin.json` `0.24.0` + `CHANGELOG.md` 항목 + `README.md` Principles Instantiated | hard | T15 |
| AC20 | runner·빌더는 각 1개, 축별 체크리스트는 데이터 파일 2개. `build_spec_codex_prompt.py` 미참조 | hard | T16 |
| AC21 | `reviewing-brief`에 `cost_class: high` 선언 + 진입 승인 게이트. **조건 없음** — 외부 문서의 미래 결론에 의존하지 않는다 | hard | T17 · V7 |
| AC22a | 훅 파일 · `hooks.json` 항목 추가 **0개** | hard | T18 |
| AC22b | **단일 호출 상한 0개** — 신규 skill·agent·체크리스트 파일에서 *단일 dispatch/exec 문맥*의 횟수 상한 표현(`최대 N회`·`N회까지`·`max_\w+\s*=\s*\d`)이 부재. 상한이 등장하는 곳은 `brief_critic_rounds`·`brief_contamination_retries` 두 루프 문맥뿐 | hard | T28 |
| AC22c | **이빨 없는 결정론 체크 0개** — 분류 규칙: *"통과 조건을 검사 대상 자신이 쓸 수 있는 검사"*. 신규 결정론 체크를 §6.3 표에 전수 열거하고 각 항목에 **통과 조건의 작성자**를 명시한다 | hard | T29 · **V8** |
| ~~AC23~~ | **삭제** — *"findings 차이가 관측된다"* 는 판정 기준이 없어 AC가 될 수 없었다(리뷰 적발). 연구 가설로 §11 ⑦로 이동하고 V3를 그쪽에 배정 | — | — |
| **AC24** | 웹 예산 degrade 경로가 배정된다 — orchestrator가 dispatch **전** `web_budget.py check`(소진이면 프롬프트 조건 분기) + dispatch **후** `increment` 1회. 리뷰어에게 `Bash`를 주지 않는다(Law 2). **계측 단위는 dispatch이며 호출 단위 계측을 주장하지 않는다**(§11 ⑩) | hard | T21 · V4 |

### 6.1 기계 검증의 한계 (명시)

- **AC2·AC3의 개방 절반**: *"어디에도 경로/기준이 없다"* 는 개방형 부정 명제라 리터럴 락으로 증명할 수 없다. T8·T9는 **dispatch 블록 윈도우 안**만 보는 닫힌 열거이고 나머지는 V6(사람 판단)로 분리한다 — Spec A의 AC8 처리 선례.
- **검출은 사후이고 불완전하다 — 담보가 아니다.** AC2의 redaction은 쉬운 경로만 없애고(H1 제목 + 날짜 추측으로 여전히 조립 가능), AC2b의 검출은 (i) **사후**라 오염 라운드가 한 번 발생하는 것을 막지 못하며 그 라운드를 폐기할 뿐이고, (ii) *어휘가 산출물에 드러난 경우*만 잡아 **패러프레이즈는 통과**한다. 그래서 검출은 defense-in-depth이고 **담보는 층 0(zero-tool, V9 미확정)뿐이다.** 잔여는 V6가 본다.
- **표 무결성 규칙의 범위 (명시)**: 규칙의 목적은 *"검증이 어디에도 연결되지 않아 고아가 되는 것"* 방지다. 따라서 V-item은 §6 또는 **§11(갭·연구 가설)** 중 한 곳에서 인용되면 규칙을 만족한다 — AC23 삭제로 V3는 §11 ⑦이 인용한다.
- **AC14는 부분 집행이다.** L2는 *§6만 고친 경우* 를 잡는다. orchestrator가 §6과 state `user_statements[].text`를 **함께** 고치면 통과한다 — 양쪽 다 orchestrator가 쓸 수 있고 state는 git-ignored라 이력 대조가 불가능하다. 조율된 양쪽 편집은 V5(사람)가 본다. **"기계적으로 봉쇄"라고 주장하지 않는다.**
- **`evidence_unsupported`는 모델 판단이다.** *"요약이 그 원문을 뒷받침하는가"* 는 기계 검증 대상이 아니다. critic이 잡고, 못 잡으면 category·체크리스트 편집이 compounding 이벤트다(Law 3).
- **AC19의 버전 핀**: `0.24.0`의 minor 자리만 검증하고 patch 자리는 unpin한다 — doc-only bump마다 stale-red가 되는 함정을 피한다.
- **T12의 grep 토큰**: `state` 단독으로 걸면 **항상 red**가 된다 — 실측(2026-07-27): `check_brief.py`의 `grep -c state` 와 `grep -c statement` 가 **둘 다 15** 로, 모든 `state` 매칭이 `statement`다. 락은 `state.local.md` · `state_path` · `state-root` **정확 토큰**으로만 건다. (수치를 인용하지 않고 *"모든 매칭이 `statement`"* 로 적는 편이 stale에 강하다 — 초안은 `10곳`이라 써서 round-2에 stale로 지적됐다.)
- **격리 주장의 최종 형태**: 층 0(zero-tool) probe 결과가 나오기 전까지 이 문서는 **어디서도 "격리(isolation)"를 보장으로 쓰지 않는다.** 쓰는 말은 *"입력 통제"* 이고, 그 내용은 (i) 프롬프트에 경로·포인터 없음, (ii) `audit_file`·`name`·`created_at` redaction, (iii) 오염 검출 = **defense-in-depth**, (iv) V6 사람 판단이다. **검출은 격리 메커니즘 자리에 앉지 않는다** — 패러프레이즈(audit을 읽고 자기 말로만 반영)는 원리적으로 못 잡는다.

### 6.2 충실도 루프 전이 표 (AC13)

초안은 *"orchestrator 판단"* 과 *"상한 2 초과"* 로 써서 카운터 증가 시점·경계값·허용 행위가 전부 미정이었다(round-2 리뷰가 적발). 전이를 못 박는다:

| # | 상태 | 이벤트 | 동작 | `brief_critic_rounds` |
|---|---|---|---|---|
| 1 | 2단계 진입 | critic #1 dispatch (+ codex #2 병렬) | 병합 → `fidelity_verdict` | **0 유지** — 최초 리뷰는 *재*라운드가 아니다 |
| 2 | `approved` | — | 3단계(readback)로 | 0 유지 |
| 3 | `needs_revise` | 저자가 **허용 행위**로 수정 | **fresh critic 재dispatch 필수**(E8 — writer가 자기 수정을 승인 못 함) | **+1 → 1** |
| 4 | 재리뷰 `approved` | — | 3단계로 | 1 유지 |
| 5 | 재리뷰 `needs_revise`, 카운터 `== 1` | orchestrator 판단 → 수정 + 재dispatch 선택 | fresh critic 재dispatch | **+1 → 2** |
| 6 | 카운터 `== 2` **이고** Issues 잔존 | — | **Step B forced escalate.** 더 이상 재dispatch 없음 | 2 고정 |

**경계값**: escalate는 `== 2` 에서 발화한다(`> 2` 가 아니다). 즉 **fresh 재dispatch는 최대 2회**이고 critic dispatch 총계는 최대 3회(#1 + 재2)다. 카운터는 **수정 후 재dispatch 시점에** 증가한다(리뷰 결과 수신 시점이 아니다).

**orchestrator의 허용 행위 — 닫힌 열거:**

| | 행위 |
|---|---|
| ✅ | §0·§1·§2·§3·§4·§5·§7 수정 (§2는 frontmatter와 **동시** — bijection B) |
| ✅ | §6에 `S<N>` **추가** |
| ✅ | 미반영 findings를 **이유와 함께** Step B로 이월 |
| ❌ | finding 임의 기각 (AC7b 위반) |
| ❌ | §6 기존 항목 본문 변경 (AC14 위반) |
| ❌ | 상한을 넘긴 추가 재dispatch (AC13 경계값 위반) |

### 6.3 신규 결정론 체크 전수 열거 (AC22c)

분류 규칙: **"통과 조건을 검사 대상 자신이 쓸 수 있는 검사는 이빨이 없다."**

| 체크 | 통과 조건을 **누가** 쓰는가 | 이빨 |
|---|---|---|
| `check_brief.py gate` (기존, 로직 무변경) | brief 파일 — **저자** | ⚠️ 부분 — 3 bijection이 body ↔ frontmatter ↔ §6 **교차** 대조라 한쪽만 고치면 red. 단일 파일 자기충족은 아니지만 조율 편집엔 열림 |
| `check_verbatim_coverage.py` L1·L2 | **두 파일**(state 원장 + payload) | ✅ — 우회에 양쪽 조작 필요(조율 편집 한계는 §11 ⑥) |
| audit 어휘 검출 13항목 | **리뷰어 산출물** — 저자가 쓰지 않음 | ✅ |
| `merge_brief_review.py` fail-closed 합집합 | **리뷰어 findings** — 저자가 쓰지 않음 | ✅ |
| T-lock 계열 (T1–T29) | 저자가 쓴 파일 — 단 **mutation으로 이빨 증명**(§8.2) | ✅ mutation 배정된 것만. T10은 락이 아님(회귀 실행) |
| ~~audit에 *"리뷰 라운드 기록"* 요구~~ | 저자 — 한 줄 쓰면 통과 | ❌ → **도입하지 않음**(§9 기각) |

이 표에 ❌ 항목이 새로 들어오면 AC22c 위반이다. **분류의 정확성은 V8이 판정한다** — 기계는 표의 존재와 열거 완전성(신규 결정론 체크 전부가 표에 있는지)만 본다.

---

## 7. Files to Modify

### 신규 (11 + 테스트)

| 파일 | 성격 |
|---|---|
| `plugins/spec-distill/agents/brief-critic.md` | 충실도 리뷰어. inert `Read`, `model: inherit` |
| `plugins/spec-distill/agents/brief-direction-reviewer.md` | 방향성 리뷰어. `Read, Grep, Glob, WebSearch, WebFetch` |
| `plugins/spec-distill/agents/brief-readback.md` | 냉독. inert `Read`, 출력 스키마 없음 |
| `plugins/spec-distill/skills/reviewing-brief/SKILL.md` | 파이프라인 3단계. `cost_class: high` |
| `plugins/spec-distill/scripts/check_verbatim_coverage.py` | 원문 완전성 L1/L2 |
| `plugins/spec-distill/scripts/build_brief_codex_prompt.py` | 축 인자로 체크리스트 조립 |
| `plugins/spec-distill/scripts/run_brief_codex_reviewer.sh` | codex 호출 1곳. `detect_codex.sh` 재사용 |
| `plugins/spec-distill/scripts/merge_brief_review.py` | 충실도 병합 |
| `plugins/spec-distill/scripts/brief-codex-direction-checklist.md` | 방향성 체크리스트 (데이터) |
| `plugins/spec-distill/scripts/brief-codex-fidelity-checklist.md` | 충실도 체크리스트 (데이터) |
| `plugins/spec-distill/tests/*` | T1–T18 |

### 수정 (7)

| 파일 | 무엇 |
|---|---|
| `skills/conducting-interview/SKILL.md` | Step A.5 진입 **한 블록** + Step B에 산출물·degrade 실기 |
| `scripts/check_brief.py` | docstring NG3 서술만 (AC17). 로직 무변경 |
| `agents/spec-reviewer.md` | docstring NG3 서술만 (AC17) |
| `templates/interview-audit-template.md` | §4·§5에 리뷰 라운드 텔레메트리 (순수 텔레메트리 → audit, D1의 분할선과 정합) |
| `.claude-plugin/plugin.json` | `0.23.0` → **`0.24.0`** (minor — 새 surface) |
| `CHANGELOG.md` | Added/Changed 항목 |
| `README.md` | Principles Instantiated + 신규 컴포넌트·kill switch 문서화 |

**`hooks/` 는 건드리지 않는다** (AC22).

---

## 8. Verification Plan

**baseline 먼저.** 착수 전 `plugins/spec-distill/tests/` 전체를 돌려 기존 red를 캡처한다 — main에 stale red가 있어 회귀와 구분해야 한다. python 테스트는 `-m unittest`로만 실행하고, 생성 파일 read는 `encoding="utf-8"`을 명시한다(non-UTF-8 locale fail-open 방지).

### 8.1 자동 테스트

| # | 대상 | 검사 | AC |
|---|---|---|---|
| T1 | `check_verbatim_coverage.py` L1 | state `S<N>`이 §6에 없으면 red | AC10 |
| T2 | 동 L2 | 정규화 후 §6 항목이 state `text`를 포함하지 않으면 red | AC11 · AC14 |
| T3 | 동 P21 예외 | placeholder 관여 시 L2가 advisory로 강등 | AC11 |
| T4 | 동 state 부재 | exit ≠ 0 + degrade 메시지. 조용한 통과 없음 | AC12 |
| T5 | `merge_brief_review.py` | `codex_isolated: false` 항상 출력 · codex 부재 시 `codex_degraded: true` + Claude verdict 보존 · 어느 쪽이든 Issues면 `needs_revise` | AC7 · AC8 · AC9 |
| T6 | 충실도 루프 전이 | §6.2 표의 **모든 전이와 경계값**: 최초 리뷰는 카운터 0 유지 · 수정 후 재dispatch 시 +1 · **`== 2` 에서 escalate**(`== 1`에서는 안 함, `> 2`를 기다리지 않음) · 키 부재 → default 0 | AC13 |
| T7 | 3 신규 에이전트 frontmatter | `tools:`에 쓰기·실행·위임 도구 부재 · `model: inherit` | AC4 · AC5 |
| T8 | critic dispatch 블록 | **그 블록 윈도우 안에** `docs/superpowers/interview/` 문자열 부재 | AC2 |
| T9 | readback dispatch 블록 | 출력 스키마 어휘(`category`/`severity`/`sentinel`/`JSON`) 부재 | AC3 |
| T10 | 기존 스위트 | `check_brief.py` docstring 변경 후 회귀 0 | AC16 |
| T11 | `build_brief_codex_prompt.py` | `--axis direction` 출력이 direction 체크리스트의 **body-unique 마커를 포함** AND fidelity 마커를 **미포함**. 축을 바꿔 대칭으로 | AC6 |
| T12 | `check_brief.py` | 소스에 state 읽기 부재 — **정확 토큰** `state.local.md` · `state_path` · `state-root` 로만 grep(`state` 단독은 `statement`에 매칭돼 항상 red) | AC16 |
| T13 | NG3 문구 | 옛 문구 부재 **AND** 새 문구 존재, 2파일 각각 | AC17 |
| T14 | kill switch | `DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW` 가 `reviewing-brief` skip 경로에 실재 | AC18 |
| T15 | 메타데이터 | `plugin.json` minor == `24` (patch unpin) · CHANGELOG에 `0.24.0` 항목 · README에 신규 컴포넌트 3 + kill switch | AC19 |
| T16 | 모듈 경계 | runner 1개 · 빌더 1개 · `scripts/brief-codex-{direction,fidelity}-checklist.md` 2개 존재 · 어느 신규 파일도 `build_spec_codex_prompt` 미참조 · `prompts/` 디렉토리 부재(canonical 트리 준수) · **runner가 `${CLAUDE_PLUGIN_ROOT:-...}` fallback 보유**(§11 ⑨의 기존 스크립트 결함 미반복) | AC20 |
| T17 | `reviewing-brief` frontmatter | `cost_class: high` 존재 · 진입 승인 게이트 서술 존재 | AC21 |
| T18 | 훅 무증가 | `hooks/` 파일 집합이 **고정 열거와 정확히 일치**(`hooks.json` · `pending-review-reminder.py` · `review-dispatch.py` · `session-end-cleanup.py` · `spec-write-validator.py` · `state_path.py` — 6개) · `hooks.json`에 `brief` 문자열 부재. *"변경 전과 동일"* 은 테스트가 알 수 없으므로 집합을 못 박는다 | AC22a |
| T19 | `check_verbatim_coverage.py` exit code | 위반 fixture → **exit 1** · state 부재 → **exit 3**. 두 값이 서로 달라야 하고 둘 다 0이 아니어야 한다 | AC12 |
| T20 | 동 예외 계약 | `main()`이 top-level `try/except`로 감싸여 있고, 고의 예외 주입 시 **exit 4**(≠ `1`) | AC12 |
| T21 | 웹 degrade 경로 | `reviewing-brief`가 direction dispatch **전에** `web_budget.py check`를 호출하는 서술 존재 · 소진 시 프롬프트 조건 분기 서술 존재 · `brief-direction-reviewer` `tools:`에 `Bash` **부재** | AC24 |
| T22 | degradation record | `brief_review_degradations` state 키 + 4필드(`component`/`reason`/`affected_axis`/`verification_status`) 열거 · Step B **question 텍스트** 렌더 서술 · 빈 배열 명시 서술 | AC15 |
| T23 | audit 전용 어휘 검출기 | 검증된 **13항목**이 `reviewing-brief`에 실재 · **`ST` 계열이 열거에 부재**(오판 벡터 제거) · 검출 시 라운드 무효화 서술 존재 | AC2b |
| T26 | 열거의 전제 검증 | 13항목 **각각**이 `templates/interview-brief-template.md`에 `grep -cF` **0건** AND `templates/interview-audit-template.md`에 ≥1건. 열거가 템플릿 변경으로 거짓이 되면 red | AC2b |
| T27 | 오염 재시도 상한 | `brief_contamination_retries` state 키 실재 · 상한 **2** · 초과 시 Step B forced escalate + 축 `unavailable` 서술 · `brief_critic_rounds`와 **독립**(한쪽 증가가 다른 쪽을 건드리지 않음) | AC2c |
| T28 | 단일 호출 상한 부재 | 신규 skill·agent·체크리스트 파일에서 `최대 [0-9]+회`·`[0-9]+회까지`·`max_\w+\s*=\s*[0-9]` 패턴이 **두 루프 문맥 밖**에 부재 | AC22b |
| T29 | 결정론 체크 열거표 | §6.3 표 실재 · 신규 결정론 체크 전부가 표에 등재(`check_verbatim_coverage`·어휘 검출·`merge_brief_review`·T-lock) · 각 행에 *"누가 쓰는가"* 열 값 존재 | AC22c |
| T24 | inline blob redaction | 빌드된 critic·readback blob에 `.audit.md` 문자열 **부재** · `audit_file: <redacted>` 형태 존재 | AC2 · AC3 |
| T25 | finding 기각 경로 | *"저자 임의 기각 금지"* + *"미반영 findings를 Step B 게이트에 이유와 함께"* 서술이 `reviewing-brief`에 실재 | AC7b |

**락 작성 규율** (리포 누적 교훈):

- **body-unique 문구를 섹션 윈도우에서 grep.** assert 문구가 헤더·주석에도 있으면 body를 삭제해도 통과한다 — T8·T9·T13은 **awk 섹션 스코프**로 걸어 헤더 만족을 불가능하게 한다.
- **셸 파싱 3종 확인** — `IFS`·`nullglob`·후행 개행이 집행을 조용히 0으로 만든다. zsh와 bash의 word-split 차이 주의.
- **`grep` exit ≥ 2는 fail-closed** 처리(파일 부재를 "위반 없음"으로 읽지 않는다).
- **락 스코프에서 `.claude/` 세션 상태 제외**.

### 8.2 mutation — 이빨 증명

통과가 정답인 assert는 모양으로 이빨을 판별할 수 없다. 각 락에 대해 **양방향**을 태운다.

| 락 | mutation | 기대 |
|---|---|---|
| T1 | 정상 fixture에서 §6 항목 1개 삭제 | red |
| T2 | 정상 fixture의 state `text` 중간을 잘라 요약본으로 교체 — **맨앞·중간·맨끝 3곳 각각** | 3회 모두 red |
| T3 | placeholder 토큰 제거 | advisory → red로 승격 |
| T4 · T19 | state 경로를 빈 파일로 / 별도로 위반 fixture 투입 | 각각 **exit 3** / **exit 1** — 두 값이 같아지면 red(호출자가 차단과 degrade를 구분 못 함) |
| T5 | codex findings만 비우기 / Claude findings만 비우기 | 각각 verdict 유지 · codex-only Issues가 verdict를 만듦 |
| T6 | `brief_critic_rounds`를 3으로 세팅 | escalate 발화 |
| T7 | `Write` 추가 / `model: sonnet`으로 교체 | 각각 red |
| T8 | critic dispatch 블록 **안에** payload 경로 삽입 | red (블록 밖 삽입은 통과 — 닫힌 열거의 한계를 명시) |
| T9 | readback 블록 안에 `severity:` 문구 삽입 | red |
| T11 | fidelity 체크리스트를 direction 출력에 섞기 | red |
| T12 | `check_brief.py`에 state 읽기 한 줄 추가 | red |
| T13 | 옛 NG3 문구 복원 | red |
| T16 | runner를 2개로 복제 / `build_spec_codex_prompt` 참조 추가 | 각각 red |
| T18 | `hooks.json`에 항목 1개 추가 / `hooks/`에 새 `.py` 파일 추가 | 각각 red |
| T14 | kill switch 이름을 한 글자 바꿈 | red |
| T15 | `plugin.json` minor를 `23`으로 되돌림 / CHANGELOG 항목 삭제 | 각각 red |
| T17 | `cost_class`를 `medium`으로 / 승인 게이트 서술 삭제 | 각각 red |
| T20 | `main()` 안에 `raise RuntimeError` 주입 | **exit 4** (1이 나오면 red — 계약 파괴) |
| T21 | `web_budget.py check` 호출 서술 삭제 / `brief-direction-reviewer`에 `Bash` 추가 | 각각 red |
| T22 | record 4필드 중 하나 삭제 / 렌더 위치를 옵션 description으로 옮김 | 각각 red |
| T23 | 열거에서 `Coverage Ledger` 삭제 / 무효화 서술 삭제 | 각각 red |
| T24 | blob 빌더에서 redaction 제거 | red (`.audit.md`가 blob에 등장) |
| T25 | 기각 금지 서술 삭제 | red |
| T6 | escalate 조건을 `> 2`로 바꿈 / 최초 리뷰에서 카운터를 +1 | 각각 red (경계값·증가 시점 양방향) |
| T23 · T26 | 열거에 `ST<N>` 재추가 / payload 템플릿에 `Coverage Ledger` 한 줄 삽입 | 각각 red (전제 검증이 템플릿 변경을 잡는지) |
| T27 | 상한을 제거 / `brief_contamination_retries` 증가가 `brief_critic_rounds`도 올리게 함 | 각각 red |
| T28 | 신규 체크리스트에 `최대 3회` 한 줄 삽입 | red |
| T29 | 표에서 `merge_brief_review` 행 삭제 / *"누가 쓰는가"* 열 값 비움 | 각각 red |

**효과 0인 mutation이 나오면 그 락은 가짜다** — 없애거나 다시 설계하고, 못 잠그는 것은 정직하게 §6.1에 한계로 적는다.

### 8.3 수동 검증

| # | 항목 | 왜 수동인가 |
|---|---|---|
| **V1** | **첫 실물 dogfood** — 새 인터뷰 1회로 v0.23.0 payload+audit 실물을 산출하고 `reviewing-brief` 전 단계를 돌린다. **Spec A의 미완 수동 e2e도 여기서 함께 닫힌다** (현재 리포에 v0.23.0 포맷 실물이 0건) | 실물 산출이 필요 |
| **V2** | **readback 순진함 실측** — 요약이 red-flag 기준을 언급하지 않는지. Spec A 인터뷰에서 **오염이 실측된** 항목이라 사라졌는지 확인해야 한다 | 모델 출력 판정 |
| **V3** | **codex 비격리 대조** — 격리된 critic이 잡은 것 vs codex #2가 잡은 것의 차이가 실제로 프레이밍 효과를 보이는지. **차이가 0이면 `codex_isolated: false` 명시의 값이 없다는 뜻이고 §5.1의 전제가 반증된다** | 비교 판정 |
| **V4** | **degrade 전파** — codex kill switch를 켜고 1회 돌려 Step B 게이트 화면에 advisory가 실제로 보이는지. 리뷰 생략 방지의 유일한 메커니즘이라 이게 안 보이면 봉쇄가 없다 | 게이트 렌더 확인 |
| **V5** | **§6 append-only** — 사용자 재결정 시나리오를 1회 수행해 기존 항목이 불변인지 | 시나리오 실행 |
| **V6** | **격리의 개방 절반** — critic·readback 프롬프트 어디에도 audit 도달 경로가 없음 (T8·T9의 닫힌 열거 밖) | 개방형 부정 명제 |
| **V7** | **`cost_class: high` 승인 게이트**가 실제로 뜨는지 | 대화형 게이트 |
| **V8** | **§6.3 분류의 정확성** — 표의 *"누가 쓰는가"* 판정과 이빨 등급이 맞는지. 기계는 표의 존재·완전성만 보고 분류가 옳은지는 못 본다 | 판단 |
| **V9** | **zero-tool agent probe** (§5.1 층 0, **구현 첫 태스크·blocking**) — `tools:`를 빈 값으로 선언한 agent가 런타임에서 resolve·dispatch되는지. **새 세션에서 실행해야 한다**(레지스트리가 세션 시작 스냅샷). 결과에 따라 층 0 결정 규칙대로 분기 | 런타임 실측 |

---

## 9. Rejected Alternatives

| 안 | 기각 이유 |
|---|---|
| **방향성을 codex에 몰기 (2 에이전트)** | codex 부재·kill switch 시 D5(b) 축이 통째로 fail-open. Claude fallback + loud downgrade가 필요해지고 그러면 fallback 에이전트가 다시 필요해 파일 수는 안 줄고 경로만 늘어난다 (인터뷰 OQ8이 이미 지적) |
| **critic이 두 축 다 (2 에이전트, 웹 도구 부여)** | D2가 확정한 payload-only 계약을 C4 경로로 재결정해야 하고, 한 에이전트가 *문서 내부 대조* 와 *외부 근거 조사* 를 섞으면 주의 배분을 모델이 임의로 해 둘 다 얕아진다 |
| **3분할 spec (critic / codex / readback)** | codex를 미루는 시점이 생기는데 리포 이력은 반대를 가리킨다 — 별-모델 codex가 same-family opus 다단계 리뷰가 통과시킨 fail-open을 반복 적발했다. codex를 늦게 넣는 것 자체가 리스크 |
| **훅 강제 (design doc 경로와 대칭)** | design doc이 훅을 쓰는 이유는 writer가 외부 플러그인(`superpowers:brainstorming`)이라 가로챌 in-skill 지점이 없기 때문이다. brief의 writer는 spec-distill 자신이라 그 제약이 없다. 훅·락·suppress·`cancel-review` 네 곳이 brief를 배워야 하고, 미해결 seam(#93 harness-sid ↔ interview-UUID)을 끌어들이며, 보안-민감 훅 표면을 넓힌다 |
| **critic 라운드 루프 + cap 5 (`reviewing-spec` 미러)** | 충실도는 *"§2 요약이 §6를 왜곡했나"* 라는 좁고 거의 기계적인 축이라 반복 수렴 대상이 아니다. design doc 리뷰의 루프는 *설계 결함* 개선이라 정당하지만 여기선 **trivia ceremony**. E8이 Law 2 최소선(수정 후 fresh critic 1회)만 남긴다 |
| **게이트에 "리뷰 라운드 기록" 검사 (초안)** | orchestrator가 audit에 한 줄 쓰면 통과한다 — **검사 대상이 통과 조건을 직접 쓰므로 이빨이 없고**, 더 나쁘게는 통과를 보장으로 오독시킨다. 생략 방지는 Step B 게이트의 degrade 전파(사용자가 *내용* 을 본다)가 담당한다. **E10 위반으로 사용자가 교정** |
| **codex 검색 횟수를 프롬프트에 상한으로 박기 (초안)** | 단일 `codex exec` 호출은 이미 턴으로 경계가 있어 상한은 순수 손실이다. 초안이 "unbounded는 아니다"라고 스스로 적고도 상한을 씌웠다 — **E10 위반으로 사용자가 교정** |
| **codex 1회 + payload 해시 비교 + 조건부 재실행 + stale 표시 (초안)** | 장부를 하나 만든다 — `payload_changed` 플래그·해시 비교·`axis` 스키마 확장·병합의 축 분기·stale 개념. **축별 2회 무조건이 더 깔끔**하고 codex #2가 항상 최종 문서를 보므로 stale이 원리적으로 불가능해진다 (사용자 판정, E9) |
| **codex 프롬프트에 두 축을 함께 담기** | codex가 주의 배분을 스스로 결정하게 되고, findings에 축 태그를 요구해야 하고, 병합에서 다시 갈라야 한다. 호출을 나누면 각 호출이 *"이것만 봐라"* 가 되어 깊이가 오른다 |
| **readback에 출력 스키마 부여** | `category`/`severity` 같은 필드 이름이 곧 *"무엇을 찾아야 하는지"* 의 힌트가 되어 순진함이 깨진다. Spec A 인터뷰에서 실측된 오염(payload 안 red-flag 기준을 읽고 회피)의 같은 클래스. 구조화는 받는 쪽이 한다 (E13) |
| **readback을 hard verdict로** | 프레시 에이전트는 *잘못 재구성된* payload도 정확히 요약할 수 있다 — readback은 "수신자가 무엇을 이해했나"를 재는 **가독성 테스트**이고 원래 의도와 비교할 독립 ground truth가 없다(codex의 OQ10 지적). false block이 나오고 P17도 줄어든다 → advisory + orchestrator의 gap 표면화 + 사용자 최종 |
| **완전성 검사를 `check_brief.py`에 병합** | 게이트가 state 의존이 되어 *"brief 파일만 읽는다"* 불변식이 깨지고 임의 brief 파일에 게이트를 돌릴 수 없게 된다. 별 모듈이 E11과도 정합 |
| **runner를 축별 2개로 복제** | codex 플래그·샌드박스·에러 처리·`detect_codex.sh` 연동이 두 곳에 중복돼 한쪽만 고치는 drift가 생긴다. 모듈화는 *중복* 이 아니라 *책임 분리* 다 — 코드 1곳 + 데이터 2곳이 정답 |
| **`build_spec_codex_prompt.py` 재사용** | 최신 spec의 AC를 주입하는 성질이 brief 리뷰에서 모델 다양성을 죽이는 오염원이다 (인터뷰가 이미 지적) |
| **§6 자유 수정** | 재구성 대 재구성의 순환 검증이 성립하고, critic 지적을 원문 수정으로 무력화하는 laundering이 열린다 (Blind Spots가 경고한 실패 양식) |
| **정정 이벤트 스키마를 지금 신설** | 스키마·게이트·테스트가 이미 큰 스코프에 또 붙는다. Spec A의 defer를 유지하고 §11에 갭으로 명시 |
| **`model:`을 리터럴로 핀 (기존 4 에이전트 관행 답습)** | 세션이 더 강한 모델일 때 downgrade가 되고, 리포가 반복 실증한 *"모델 강도·다양성이 fail-open 적발의 유일 backstop"* 과 정면으로 어긋난다. `plugin-audit`(가장 최근 플러그인)은 이미 전부 `inherit` — 신규 컴포넌트는 그 패턴을 따른다 |
| **기존 4 에이전트의 `model: sonnet` 핀을 이 spec에서 함께 제거** | 이 spec의 스코프가 아니고 별 작업(`docs/handoffs/2026-07-26-...-sweep.md`)이 전수 조사와 함께 다룬다. 여기서 부분 제거하면 sweep의 열거가 어긋난다 |
| **`check_verbatim_coverage.py`의 exit code를 하나로 (초안)** | *"위반 발견"* 과 *"검사 불가"* 를 같은 non-zero로 내면 호출자가 구분할 수 없다 — 합쳐서 차단하면 state 부재가 정상 brief를 막고, 합쳐서 degrade하면 실제 누락이 통과한다. `1`/`3`으로 분리 (**self-review가 적발**) |
| **AC14(§6 append-only)를 기계 집행으로 서술 (초안)** | L2 포함 검사는 orchestrator가 §6과 state `text`를 **함께** 고치면 통과한다 — 양쪽 다 orchestrator가 쓰고 state는 git-ignored라 이력 대조도 없다. *"기계적으로 봉쇄"* 는 사실과 다른 확정 진술이었다. 주장을 *부분 집행* 으로 낮추고 §6.1·§11에 한계 명시 + V5 배정 (**self-review가 적발** — Spec A round-5가 `evidence` 서술에서 기각한 것과 같은 클래스) |
| **`prompts/` 신규 디렉토리 (초안)** | `docs/plugin-authoring.md`의 canonical 트리에 없다(정의된 것은 `commands/`·`skills/`·`agents/`·`hooks/`·`scripts/`·`templates/` 여섯). 데이터 파일 선례는 `scripts/ambiguity-blacklist.txt` → 체크리스트를 `scripts/`로. 새 디렉토리로 트리를 넓히는 것은 이 spec의 스코프가 아니다 (**self-review가 적발**) |
| **T18을 *"변경 전과 동일"* 로 서술 (초안)** | 테스트는 *before* 를 알 수 없다 — 실행 시점에 비교 대상이 없는 assert는 이빨이 없다. `hooks/` 파일 집합을 6개 고정 열거로 못 박는다 (**self-review가 적발**) |
| **T12를 `state` 토큰으로 grep (초안)** | `check_brief.py`에 `statement`가 10곳 있어 **항상 red**가 된다(실측 확인). 정확 토큰 `state.local.md`·`state_path`·`state-root`로 좁힌다 (**self-review가 적발** — 값싼 assert가 대상을 구분 못 하는 클래스) |
| **V3를 AC 배정 없이 두기 (초안)** | §8의 V-item이 §6에서 인용되지 않아 **편도 참조**가 됐다 — Spec A에서 두 번 재발한 클래스이고 이 문서 자신의 표 무결성 규칙 위반. soft AC23으로 배정 (**self-review가 적발**) → 그 AC23마저 판정 기준이 없어 round-1 리뷰가 다시 기각. 최종: AC23 삭제 + §11 ⑦ 가설 + 규칙 범위 명시 |
| **격리를 "경로 미제공 = 도달 불가"로 주장 (초안)** | payload frontmatter의 `audit_file`에 audit basename이 **그대로 실려** inline blob에 들어간다(`templates/interview-brief-template.md:8`). 더 나아가 redact해도 `name:`+`created_at:`으로 **재구성** 가능하고 관행 디렉토리는 리포 전역에 서술돼 있다 — `Read`를 가진 에이전트에게 완전 격리는 **원리적으로 불가능**하다. 예방(redaction) + **검출**(audit 전용 어휘 닫힌 열거 → 라운드 무효화) 2층으로 교체 (**round-1 Claude 리뷰가 적발 — 이 라운드의 최대 값**) |
| **프롬프트에 *"audit을 읽지 마라"* 를 넣기** | audit의 존재와 그것이 인터뷰 프레이밍을 담는다는 사실을 알리는 것 자체가 힌트다 — readback 오염(기준을 알면 그 답을 회피)의 같은 클래스. 금지 대신 **모르게 두고 검출**한다 |
| **codex findings를 advisory로 두기 (초안)** | §5.1은 *"보조 입력"*·*"최종 권위는 격리된 critic"* 이라 쓰고 AC7은 *"어느 리뷰어든 Issues면 `needs_revise`"* 라고 썼다 — advisory는 verdict를 만들 수 없으므로 **권위 계약이 자기모순**이고 precedence가 미정의였다. fail-closed 합집합 + codex binding으로 통일. codex를 advisory로 두는 것은 리포가 반복 학습한 것(별-모델이 유일 backstop)의 정반대 회귀 (**round-1 codex 리뷰가 block으로 적발**) |
| **`check_verbatim_coverage.py`의 예외 계약을 안 적기 (초안)** | Python 미처리 예외의 **기본 종료 코드가 `1`** 이라 예상 못 한 버그가 *"위반 발견"* 으로 오분류돼 **정상 brief를 차단**한다. exit `4` 신설 + top-level `try/except` 계약 + T20 mutation (**round-1 Claude 리뷰가 적발**) |
| **"loud advisory"를 정의 없이 반복 (초안)** | 표현·목적지·지속성·렌더링이 전부 미정이라 AC15가 집행 불가였다. `component`/`reason`/`affected_axis`/`verification_status` 4필드 record + state append + **Step B question 텍스트** 렌더로 구체화 (**round-1 codex 리뷰가 적발**) |
| **웹 예산 degrade를 AC 배정 없이 서술 (초안)** | 이 문서 자신의 표 무결성 규칙 위반. 게다가 `brief-direction-reviewer`에 `Bash`가 없어 자기 예산 소진을 확인할 경로가 없었다 → **orchestrator 사전 체크 + 프롬프트 조건 분기** 명시 + AC24 신설. 리뷰어에게 `Bash`를 주는 것은 Law 2 위반이므로 대안이 아니다 (**round-1 양쪽이 적발**) |
| **Goal 6을 *"하니스 무게 0 증가"* 로 표현 (초안)** | 비측정이고 사실과도 어긋난다 — 이 설계는 에이전트·모델 호출·스크립트·state·게이트를 **늘린다**(그건 능력 증가이고 E10 대상이 아니다). 측정 가능한 세 항목(훅 0 · 이빨 없는 체크 0 · 단일 호출 상한 0)으로 교체 (**round-1 codex 리뷰가 적발**) |
| **AC21(hard)의 존속을 외부 문서의 미래 결론에 조건부로 걸기 (초안)** | hard AC를 미정 결론에 의존시키면 이행 시점도 주체도 없어 집행할 수 없다. 무조건 확정 + 미래 변경은 재오픈 사이클(§11 ⑧) (**round-1 Claude 리뷰가 적발**) |
| **`ST<N>`을 audit 전용 어휘 열거에 포함 (round-1 fix)** | payload 템플릿 `:75`가 `verdict: defended — ST1`을 **설계상** 담는다(`grep -cF` payload=1 실측). *"payload에 결코 없는 어휘"* 전제가 거짓이고, critic이 §5의 그 항목을 지적하며 `ST1`을 인용만 해도 **깨끗한 라운드가 오염으로 오판**된다. 헤딩 포맷(`#### ST<N>`)으로 좁히는 안도 검토했으나 critic 산출물이 헤딩 문법을 재현할 이유가 없어 실효가 낮고 오판 위험만 남는다 → 제거 + 실측 검증된 4항목(`type: interview-audit`·`Interview Audit`·`프로세스 로그`·`게이트 실행 기록`)으로 대체, 13항목 전부 payload=0 확인 (**round-2 Claude 리뷰가 적발**) |
| **오염 재dispatch를 무상한으로 (round-1 fix)** | `brief_critic_rounds`와 별개의 **두 번째 실재 루프**를 만들었는데 cap·escalate·갭 등재가 전무했다. 층 1이 재구성을 완전히 닫지 못해 fresh 에이전트가 같은 재구성을 반복할 개연성이 있고(결정론적 입력 → 상관된 행동) detect→invalidate→redispatch가 무한 반복될 수 있다. **CLAUDE.md *Unbounded autonomy* 위반이고 이 문서 Goal 6의 *"루프는 하나뿐"* 주장과 정면 모순** → `brief_contamination_retries ≤ 2` + escalate + Goal 6 정정 (**round-2 Claude 리뷰가 block으로 적발**) |
| **검출을 격리 메커니즘 자리에 앉히기 (round-1 fix)** | 검출은 audit 전용 *어휘*가 산출물에 드러난 경우만 잡는다 — audit을 읽고 **자기 말로만** 반영하면 통과한다. 격리를 주장할 수 없다 → 용어를 *"입력 통제"* 로 바꾸고, 실제 보장은 **층 0(zero-tool agent)** 으로 올리고 검출은 defense-in-depth로 내림. 층 0은 레지스트리 세션-스냅샷 때문에 이 세션에서 실측 불가 → **구현 첫 태스크의 blocking probe(V9) + 양쪽 결정 규칙** (**round-2 codex 리뷰가 적발**) |
| **degradation record 열거에 `critic` 누락 (round-1 fix)** | 바로 아래 실패표가 critic 오염 시에도 record를 요구하는데 `component` 닫힌 열거에 `critic`이 없어 **표현 불가**했고, *"탐지 후 자체 복구"* 에 맞는 `verification_status` 값도 없었다. 게다가 그 행이 메커니즘을 정의한 **AC2b가 아니라 AC2·AC3를 인용**했다 → `critic` 추가 · `retried` 추가 · 인용 정정 (**round-2 Claude 리뷰가 적발**) |
| **AC24를 *"기존 increment-then-check 관행과 같은 위치"* 라 서술 (round-1 fix)** | **부정확한 등치.** 그 관행은 매 웹 호출 전 `increment` 하는 **호출 단위** 계측이고, 여기서는 리뷰어 turn 내부 호출을 리뷰어도 orchestrator도 셀 수 없어 **dispatch 단위** 스냅숏뿐이다. `SESSION_CAP` 가드가 이 축에서 형식화된다 → 등치 삭제 · dispatch 후 `increment` 1회 추가 · 계측 단위를 명시 · §11 ⑩에 한계 등재 (**round-2 Claude 리뷰가 적발**) |
| **AC13을 *"orchestrator 판단"* + *"상한 2 초과"* 로 서술 (초안)** | 카운터 증가 시점·escalate 경계값(`== 2` vs `> 2`)·허용 행위가 전부 미정이라 상태 기계가 집행 불가였다 → §6.2 전이 표 + 닫힌 허용 행위 열거 + T6 경계값 mutation (**round-2 codex 리뷰가 적발**) |
| **AC22를 세 절이 한 AC에 묶인 형태로 (round-1 fix)** | *"이빨 없는 결정론 체크 0개"* 에 객관적 분류 규칙이 없고 배정된 T18은 **훅 파일만** 검사했다 — 세 절 중 둘이 무검증이었다 → AC22a/b/c로 분할 + 분류 규칙 명문화 + §6.3 전수 열거표 + T28·T29·V8 (**round-2 codex 리뷰가 적발**) |

---

## 10. Open Questions 처리

인터뷰 brief의 OQ 중 Spec B로 이월된 여섯 개, 전부 닫힌다.

| OQ | 처리 |
|---|---|
| **OQ2** — critic·readback 재실행 cap | 루프 제거로 **축소**. 남는 것은 재리뷰 상한 2뿐이고 그건 실재 루프에 붙은 Unbounded-autonomy 가드다(§5.2·AC13). readback·방향성은 각 1회라 cap 대상이 아니다 |
| **OQ3** — readback 판정자 | **orchestrator가 gap을 표면화하고 사용자가 최종.** gap ≥1이면 Step B 게이트에 "gap 수정 후 재확인" 옵션이 추천으로 오르지만 사용자는 그대로 진행할 수 있다(P17) — advisory이면서 Polite handoff는 아니다(게이트 필수 경유 + gap 명시 표면화) |
| **OQ4** — red-flag 기준 위치 | **orchestrator의 gap 판정 로직에만.** payload에도 readback 프롬프트에도 넣지 않는다(AC3). Spec A가 payload 쪽을 이미 선제 처리했고 이 spec이 프롬프트 쪽을 닫는다 |
| **OQ5** — "사용자와 Claude 양쪽"의 의미 | **에이전트 1 · 판정자 2.** readback 에이전트가 *Claude-독자 대리* 이고, 같은 산출물(요약 전문)을 Step B 게이트에서 *사람* 이 판정한다. 별도 절차가 필요 없다 |
| **OQ8** — 리뷰 역할 배치 (D2 ↔ D5 도구 계약 충돌) | **3 에이전트 계약별 분리 + codex 축별 2회**(E3·E9). 두 축은 증거 범위가 정반대라 한 바니에 들어갈 수 없고, 분리한 결과 codex의 repo 접근이 D2와 충돌하지 않게 된다(codex가 방향성 단계에 있으므로) |
| **OQ10** — readback을 hard verdict로 쓸 수 있는가 | **아니오. advisory.** 독립 ground truth가 없다(§9). 대신 gap을 구체적으로 표면화해 사용자가 판정한다 |

---

## 11. 남는 갭 (명시)

*"안 닫히는 갭은 명시한다"* — Spec A가 세운 규율.

1. **사용자 오타·발언 철회 경로 없음.** §6 append-only(E14)의 대가다. 사용자가 인터뷰 중 오타를 쳤거나 발언을 철회하고 싶으면 경로가 없고, 기존 항목은 그대로 남는다. Spec A가 *"기록 이후 원문 정정 경로"* 로 defer한 것을 유지한다 — 스키마·저장 위치·검증 배정이 전부 미정이고, 검증 배정 없는 규칙을 문서에 남기지 않기 위해 스코프에서 뺀다.
2. **`evidence_unsupported`는 기계 검증이 없다.** *"요약이 그 원문을 뒷받침하는가"* 는 critic의 모델 판단이다. 게이트의 bijection C는 앵커의 존재만 본다. critic이 못 잡으면 category·체크리스트 편집이 compounding 이벤트(Law 3).
3. **격리의 개방형 절반은 사람 판단.** *"어디에도 경로/기준이 없다"* 는 리터럴 락으로 증명 불가 — T8·T9는 dispatch 블록 윈도우만 보고 나머지는 V6가 본다.
4. **codex의 웹 사용은 예산 계측 밖.** `web_budget.py`는 Claude 측 카운터라 codex 내부 검색을 세지 않는다. 단일 `exec` 호출이라 턴으로 경계가 있어 unbounded는 아니지만, 총량 관측치는 없다. E10에 따라 상한을 씌우지 않는다.
5. **방향성 findings의 중복 제거가 결정론이 아니다.** Claude와 codex가 같은 지적을 다른 문구로 내면 orchestrator가 판단해 합친다. 판단이 틀리면 사용자가 중복을 보거나 하나를 놓친다 — E10에 따라 모델을 신뢰하는 쪽을 택했다.
6. **§6 append-only의 조율된 우회는 잡히지 않는다.** orchestrator가 §6과 state `user_statements[].text`를 함께 고치면 L2 포함 검사가 통과한다 — 둘 다 orchestrator가 쓸 수 있고 state는 git-ignored라 이력 대조가 없다. L2는 *§6만 고친 흔한 경우* 를 잡고, 조율된 편집은 V5(사람)가 본다. AC14를 *"기계적으로 봉쇄"* 라고 주장하지 않는다.
7. **연구 가설 (AC 아님) — 프레이밍 효과의 실재.** *"격리 critic과 비격리 codex의 findings 차이가 프레이밍 효과를 보인다"* 는 **판정 기준이 없어 AC가 될 수 없다**(리뷰 적발: 무엇을 유의미한 차이로 볼지, 그 차이가 프레이밍 때문인지 단순 모델 분산인지 구분하는 규칙이 없다). 그래서 삭제하고 여기 가설로 남긴다. **V3**가 이 가설을 관측하며, 차이가 0이면 `codex_isolated: false` 라벨의 값이 없다는 뜻이고 §5.1의 프레이밍-오염 전제가 반증된다. 후속 처리는 이 spec이 정하지 않는다(관측 후 결정). 정식 검증으로 승격하려면 비교 rubric·코딩된 finding 분류·최소 관측 수·모델 분산과의 구분 규칙이 필요하다.
8. **AC21의 미래 변경 경로.** 억제 제거 sweep이 `cost_class: high` 승인 게이트 관행을 바꾸면 AC21이 낡는다. 이 spec은 그 결론에 **조건부로 의존하지 않고**(초안의 결함) 무조건 확정하며, 변경이 필요해지면 **이 문서를 재오픈하는 별 사이클**로 처리한다. 자동 이행 메커니즘은 없다 — 없는 것이 정직하다.
9. **패러프레이즈 오염은 검출되지 않는다.** 층 2는 audit 전용 *어휘*가 산출물에 드러난 경우만 잡는다. 에이전트가 audit을 읽고 그 내용을 **자기 말로만** 반영하면 통과한다 — 그래서 검출은 격리 메커니즘이 아니라 defense-in-depth이고, 실제 보장은 층 0(zero-tool)뿐이며 그것은 V9까지 미확정이다. V6가 잔여를 본다.
10. **웹 예산 계측 단위 (닫히지 않음).** `brief-direction-reviewer`의 turn 내부 `WebSearch`/`WebFetch` 호출 수를 셀 경로가 없다 — 리뷰어는 `Bash`가 없고(Law 2), orchestrator는 subagent 내부 도구 호출을 보지 못한다. 그래서 `SESSION_CAP = 8`은 이 컴포넌트에 대해 **dispatch 단위** 상한이며 *"검색 8회"* 가 아니다. 프롬프트로 검색 횟수를 묶는 것은 E10 위반이므로 대안이 아니다. 리뷰어 도구 호출 수를 orchestrator에 노출하는 경로가 생기면 호출 단위로 승격할 수 있다.
11. **`run_spec_codex_reviewer.sh`의 env 의존 (부수 발견, 이 spec 스코프 밖).** 이 문서를 리뷰하는 과정에서 실측: 그 스크립트 `:57`이 `CLAUDE_PLUGIN_ROOT`를 fallback 없이 참조하는데 `set -u`가 걸려 있어, 훅이 env를 주지 않는 컨텍스트(스킬 수동 호출)에서 즉시 죽는다. 스킬 문서는 `${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}` fallback을 쓰는데 스크립트에는 없다 — 비대칭. loud하게 죽으므로 치명적이지 않지만, **신규 `run_brief_codex_reviewer.sh`는 같은 실수를 반복하지 않는다**(fallback 필수).

---

## 12. Metadata

- **작성일**: 2026-07-27
- **입력 brief**: `docs/superpowers/interview/2026-07-25-spec-distill-brief-handoff-redesign-interview.md` (+ `.audit.md`)
- **선행 spec**: `docs/superpowers/specs/2026-07-25-spec-distill-brief-format-producer-design.md` (Spec A, v0.23.0, merge 5b0caff) — 이 문서가 그 §11이 예고한 후속이다
- **대상 플러그인**: `plugins/spec-distill` — `v0.23.0` → `v0.24.0`
- **병행 작업(독립)**: `docs/handoffs/2026-07-26-harness-capability-suppression-sweep.md` — E10의 리포 전역 집행. 이 spec은 자기 신규 컴포넌트에만 선제 적용
- **철학 근거**:
  - **Law 1** — 구조 게이트(`check_brief.py`)는 그대로, 그 위에 Law 2 분리 리뷰가 얹힌다. NG3 교정이 이 변화의 기록
  - **Law 2** — 3중: (a) `tools:` allowlist 물리 분리, (b) **입력 격리**(payload inline·경로 미제공), (c) **수정 후 fresh critic 재리뷰 1회 필수** — writer가 자기 수정을 승인하는 경로 차단
  - **Law 3** — `critic-issues` category 6종이 compounding substrate. 리뷰가 놓친 결함류가 나오면 persona 편집이 compounding 이벤트(persona = 보안-민감 코드)
  - **P17** — 방향성은 보고만(C4), readback advisory, Step B 게이트가 사용자 최종, 신규 kill switch
  - **P21** — placeholder 예외 처리, codex 프롬프트에 secret 미주입
  - **E10 (절대 조항)** — codex 검색 무상한, 신규 에이전트 전부 `model: inherit`, 방향성 리뷰어에 `WebSearch`+`WebFetch` 둘 다, 이빨 없는 게이트 체크 0개, 훅 0개 추가
  - **E11 (전역 모듈화)** — 신규 skill 분리, runner 1 + 체크리스트 데이터 2, 완전성 검사를 게이트에서 떼어 별 모듈로
  - **금지 패턴 회피** — *trivia ceremony*(루프 제거 · 이빨 없는 체크 철회) · *unbounded autonomy*(상한은 실재 루프에만) · *subagent spray*(동시 fan-out 2) · *polite handoff*(degrade 전파 + Step B 게이트 필수 경유)
- **Law 2 tool posture**: 신규 에이전트 3개 전부 fail-closed `tools:` allowlist, 쓰기·실행·위임 도구 0개. 기존 8 에이전트의 posture는 무변경(v2.12.0 #104 락 유지)
- **실측 기록**: codex 웹 검색 가용성(2026-07-26, codex-cli 0.144.6, `codex exec -s read-only`가 라이브 검색 수행) · v0.23.0 포맷 실물 brief 0건(같은 날, `check_brief.py gate` 6 failures)
- **리뷰 이력**: **round-2** — Claude 4건(**block 1** + high 3) + codex 3건(high 2 · medium 1) → `combined_verdict: needs_revise`, **`stagnation.round_level: true`**. 그 stagnation은 **수렴이 아니라 id 충돌**이다: `issue_id = sha256(category:target_section)[:12]`(`compute_issue_id.py:10`)이라 round-2의 *새* 결함이 round-1과 같은 (category, section)에 떨어져 같은 id로 합쳐졌다. 라우팅 표대로 forced escalate → **사용자가 ③(7건 반영 후 재리뷰)를 선택**. round-1 지적 4건은 리뷰어가 *전부 fixed*로 확인(예외 계약은 mutation까지). 그러나 **가장 크게 손댄 두 곳(§5.1 2층 격리, §5.6 AC24)이 각각 새 결함을 만들었다** — 7건 전부 반영, 기각 0. 최대 값: `ST<N>`이 payload 템플릿에 실재해 열거 전제가 거짓이었던 것(실측 확인), 오염 재dispatch가 무상한 두 번째 루프였던 것(block), 검출을 격리 자리에 앉힌 것(codex)
- **리뷰 이력**: **round-1** — Claude `spec-reviewer` 4건(high 4, `Stagnation_signal: false`) + codex 4건(block 1 · high 2 · medium 1) → `merge_review.py` 결정론 병합: `combined_verdict: needs_revise`, distinct 6건(both 2 · claude-only 2 · codex-only 2), stagnation false. **6건 전부 반영**(기각 0). 최대 값: **Claude가 `audit_file` basename 누출로 격리 전제를 무너뜨린 것**(예방→예방+검출 2층으로 재설계), codex가 **권위 계약 자기모순을 block으로** 적발한 것. 두 리뷰어가 서로 다른 결함류를 잡았다 — 겹친 2건은 §5.1 격리와 §5.6 degrade
- **self-review 이력**: 인라인 자기검토가 6건 적발 — exit code 단일화 모순 · AC14 기계 집행 과장 · `prompts/` canonical 트리 위반 · T18의 비교 불가 assert · T12의 `statement` 오매칭 · V3 편도 참조. 전부 §9에 기각 항목으로 기록. placeholder 0건, TOC 존재 확인
- **브레인스토밍 이력**: 사용자 교정 3회 — (1) 에이전트 개수 확인 질문으로 역할↔에이전트 매핑 명료화, (2) 파이프라인 순서 재배치(방향성 먼저 + critic 루프 제거) — 초안의 재작업 결함을 사용자가 적발, (3) **E10 위반 2건 적발**(codex 검색 상한 · 이빨 없는 게이트 체크) → 철회 + 리포 전역 sweep 핸드오프 분리. 그리고 codex 웹 검색 가용성 지적 → 실측으로 초안 서술 반증
