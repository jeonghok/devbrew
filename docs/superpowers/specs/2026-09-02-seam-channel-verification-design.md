---
name: seam-channel-verification
type: design
created_at: 2026-09-02
source_interview: docs/superpowers/interview/2026-09-02-seam-channel-verification-interview.md
next_phase: superpowers:writing-plans
---

# 이음매 채널 검증 — 설계

> **강제처럼 보이는 자리가 실은 서술이었다. 고치는 것은 채널이지 강제가 아니다.**

devbrew 의 이음매(한 단계가 끝나고 다음으로 넘어가야 하는 자리) 아홉 곳을 **결함의 종류**로
다섯 묶음에 나눠 처리한다. 처방은 대부분 삭제와 채널 교정이며 새 훅·새 검사층·새 추상을
만들지 않는다. 자리 목록이 아니라 종류로 나누는 이유는 다음에 생길 자리도 같은 다섯 중 하나로
분류되게 하기 위해서다.

## 목차

- [1. 무엇을 만드는가](#1-무엇을-만드는가)
  - [1.1 정체](#11-정체)
  - [1.2 진짜 문제 — 도달 검사층 부재](#12-진짜-문제--도달-검사층-부재)
  - [1.3 아홉 자리와 다섯 묶음](#13-아홉-자리와-다섯-묶음)
  - [1.4 불변식](#14-불변식)
- [2. 묶음 1 — 채널 오배정](#2-묶음-1--채널-오배정)
  - [2.1 두 자리](#21-두-자리)
  - [2.2 폭주 가드 — 새로 만들 것이 없다](#22-폭주-가드--새로-만들-것이-없다)
- [3. 묶음 2 — 소비자 없는 약속](#3-묶음-2--소비자-없는-약속)
  - [3.1 qg 발행 offer 와 sentinel](#31-qg-발행-offer-와-sentinel)
  - [3.2 `/compact` — 철회할 것이 안내 문구 한 줄이다](#32-compact--철회할-것이-안내-문구-한-줄이다)
- [4. 묶음 3 — 배포 경계](#4-묶음-3--배포-경계)
  - [4.1 zero-tool probe 선결조건](#41-zero-tool-probe-선결조건)
  - [4.2 N5 — 대상을 열거에서 도출로](#42-n5--대상을-열거에서-도출로)
  - [4.3 `next_phase` 값 고정 해제](#43-next_phase-값-고정-해제)
- [5. 묶음 4 — 재사용을 막는 리터럴](#5-묶음-4--재사용을-막는-리터럴)
  - [5.1 핸드오프 펜스 — 결함이 상정보다 작다](#51-핸드오프-펜스--결함이-상정보다-작다)
  - [5.2 하드코딩](#52-하드코딩)
- [6. 묶음 5 — 질문의 재생](#6-묶음-5--질문의-재생)
- [7. 검증](#7-검증)
  - [7.1 mutation 매트릭스](#71-mutation-매트릭스)
  - [7.2 삭제에는 부재 락을 만들지 않는다](#72-삭제에는-부재-락을-만들지-않는다)
  - [7.3 작업 순서와 형제 세션](#73-작업-순서와-형제-세션)
- [8. 컴포넌트와 버전](#8-컴포넌트와-버전)
- [9. 재결정 기록](#9-재결정-기록)
- [10. 기각한 길](#10-기각한-길)
- [11. 남은 것](#11-남은-것)
- [Handoff Context](#handoff-context)

## 1. 무엇을 만드는가

### 1.1 정체

새 기능이 아니다. **기존 아홉 자리의 교정과 삭제**다. 순증하는 것은 훅 출력 필드
`hookSpecificOutput`(두 훅에 각각, 묶음 1), 상수 둘(묶음 4), 감사 축 질문 한 줄(묶음 5)이고
나머지는 전부 순감이다.

### 1.2 진짜 문제 — 도달 검사층 부재

이음매가 전부 「모델에게 다음에 무엇을 하라고 적어 두는 것」으로 구현돼 있는데, **그 적힌 것이
실제로 도달하는지 검사된 적이 없다.** 그래서 강제처럼 보이는 자리가 실은 서술이다.

다만 이 명제는 **부분적으로 거짓**이다 — 인터뷰의 적대적 premortem 이 잡았고 코드가 확증했다.
핸드오프 자리에는 `build_brief_bundle.py` 의 인자 검사라는 fail-closed 도달 검사가 실재하고
작동한다. 부재한 것은 검사가 아니라 **집계와 명명**이다. 그래서 이 설계는 검사층을 신설하지
않는다(§10).

### 1.3 아홉 자리와 다섯 묶음

인터뷰가 축 넷 — 무엇이 넘어가나(제어/payload) × 언제(같은 턴/턴 경계/컨텍스트 경계) ×
누가 운반하나(모델 산문/하니스 훅/파일시스템/셸/사람) × 어디로(같은 플러그인/다른 플러그인/
배포단위 밖) — 로 열한 자리를 도출했고, 그중 이번 범위가 아홉이다. 자리별이 아니라 **결함의
종류**로 묶는다:

| 묶음 | 결함의 종류 | 자리 | 처방 |
|---|---|---|---|
| **1** | 모델용 지시가 사람 채널로 나간다 | ⑥ project-init · ⑧ qg 자동기동 | `additionalContext` 병행 |
| **2** | 소비자가 없는 약속·산출물 | ② qg offer + sentinel · ④ `/compact` | 약속 철회 + 죽은 산출물 제거 |
| **3** | 배포 단위 밖 파일을 선결조건으로 읽는다 | ③ zero-tool probe · ⑦ `next_phase` | 분기 제거, 참인 갈래만 |
| **4** | 목적지·인자가 코드 리터럴로 박혀 있다 | ① 핸드오프 펜스 · ⑤ 하드코딩 | 상수 하나로 통합 |
| **5** | 다음 자리가 같은 질문을 안 받는다 | ⑨ plugin-audit 축 3 | 축 질문 한 줄 |

### 1.4 불변식

- **N1 (채널)** — 모델에게 하는 말은 `hookSpecificOutput.additionalContext` 로, 사람에게 하는
  말은 `systemMessage` 로 나간다. 한 훅이 둘 다 할 말이 있으면 **둘 다 낸다.** 한쪽으로
  «옮기는» 것은 다른 쪽 수신자를 잃는 것이므로 교정이 아니다.
- **N2 (소비자)** — 아무도 읽지 않는 파일을 쓰지 않는다. 소비자가 사라지면 생산도 사라진다.
- **N3 (배포 경계)** — 플러그인 코드는 자기 배포 단위 밖의 파일을 **실행 시점 선결조건**으로
  읽지 않는다. 근거 기록으로서의 참조는 허용되고, 실행 분기의 입력이 되는 것이 금지다.
- **N4 (리터럴)** — 강제기의 목적지와 경로 접두는 플러그인 안 **한 자리**에서 온다. 새 설정
  파일도 새 레지스트리도 만들지 않는다 — 상수와 import 다.
- **N5 (도출)** — 격리 에이전트의 검사 대상은 손으로 적은 이름 목록이 아니라 `tools: []` 를
  선언한 파일 집합에서 **도출**한다.

## 2. 묶음 1 — 채널 오배정

**측정 근거.** 설치 번들 `2.1.258` 의 훅 문서가 두 필드를 명시적으로 가른다 —
`systemMessage` = *"Display a message to the user (all hooks)"*, `hookSpecificOutput.
additionalContext` = *"Text injected into model context"*. 그 문서의 예제가 쓰는
`hookEventName` 이 바로 `PostToolUse` 이며, 이 리포의 선행 설계문서
(`docs/superpowers/specs/2026-08-05-agent-transparency-design.md:359`)의 배달지 표도 같은
이벤트를 ✅ 로 적는다.

**이 근거의 지위** — 번들의 **서술**과 **스키마**이지 런타임 실측이 아니다. 배달지 표에서
라이브 probe 가 확증한 행은 `SubagentStop` 이다. 그리고 「모델이 `systemMessage` 를 못 본다」는
이 서술에서 직접 나오지 않는다 — 두 필드를 나눠 둔 이유일 뿐이다. **그래서 N1 은 «옮기기» 가
아니라 «병행» 이다**: 서술이 틀렸어도 잃는 것이 없다.

### 2.1 두 자리

| 파일 | 지금 | 바꾼 뒤 |
|---|---|---|
| `plugins/quality-gates/hooks/post-tool-use.py:85-91` | `systemMessage` 에 *"You MUST now initialize … Run: Bash(…) Then invoke Skill(…)"* | `systemMessage` = PR 생성 사실 한 줄(사람) · `additionalContext` = 기동 지시(모델) |
| `plugins/project-init/hooks/post-tool-use.py:137, :212` | `systemMessage` 에 수정 명령을 포함한 경고 전체 | `systemMessage` = 규약 위반 사실 + 기대 패턴(사람) · `additionalContext` = 수정 명령(모델) |

### 2.2 폭주 가드 — 새로 만들 것이 없다

C16 은 새 강제에 폭주 방지를 요구한다. 두 자리 다 **이미 구조적으로 닫혀 있다**:

- qg: `post-tool-use.py:57-60` 이 `.claude/quality-gates/<sid>/pipeline.md` 존재를 검사하고
  있으면 즉시 `{}` 를 낸다 → 세션당 1회.
- project-init: 제안하는 수정 명령(브랜치 개명)이 자기 정규식
  `git\s+(?:checkout\s+-b|switch\s+-c)`(`:32`)에 **걸리지 않는다** → 모델이 그 명령을 실행해도
  재발동이 불가능하다.

두 사실 다 코드에서 확인했다. 새 가드를 추가하지 않는다.

## 3. 묶음 2 — 소비자 없는 약속

### 3.1 qg 발행 offer 와 sentinel

`publish-eligible.md` 를 **쓰는 곳이 둘, 읽는 곳이 하나**다. 읽는 하나가 offer 이므로 offer 를
지우면 소비자가 0이 된다 → N2 에 따라 생산도 지운다.

| 지울 것 | 자리 |
|---|---|
| offer 블록 | `plugins/quality-gates/commands/qg.md:73-117` |
| 표의 자동 offer 행 | `plugins/quality-gates/commands/qg.md:138` |
| sentinel 쓰기 (Final Summary) | `plugins/quality-gates/skills/quality-pipeline/SKILL.md:944` |
| sentinel 쓰기 (Runtime R8) | `plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md:1201-1202` |
| sentinel 형식 절과 목차 항목 | `.../quality-pipeline/SKILL.md:93, :144-145, :905-910` |
| stale 청소 (global-kill · 매 setup) | `plugins/quality-gates/scripts/setup-qg.sh:37, :179` |
| GC 마커 | `plugins/quality-gates/scripts/qg-gc.py:49` |
| sentinel 배선 락 4개 | `tests/harness/test_skill_orchestration_behavior.sh:538-620` · `tests/test_setup_qg.sh:107-147` · `tests/test_qg_publish_offer.sh` · `tests/test_qg_gc.py:165-176` |

**남기는 것** — `/qg-publish`. `commands/qg-publish.md` 전문을 읽어 확인했다: 브랜치 diff 로부터
독립 동작하는 얇은 dispatcher 이고 sentinel 을 읽지 않는다. 아무것도 고치지 않는다.
`qg.md` 에는 파이프라인 종료 후 한 줄만 남긴다 — *"이어서 PR 이해글을 게시하려면 `/qg-publish`"*.

**확인이 필요한 것** — `DEVBREW_QUALITY_GATES_DISABLE_PUBLISH` 의 관할. offer 전용이면 함께
제거하고, `/qg-publish` 경로도 존중해야 하는 스위치면 유지한다. **kill switch 는 보안 컨트롤이므로
지우기 전에 소비자를 전수 확인한다**(계획 단계 선결).

### 3.2 `/compact` — 철회할 것이 안내 문구 한 줄이다

인터뷰는 이 자리에 기계 채널(`PreCompact matcher=manual`)을 붙이기로 확정했으나, 코드를 읽고
**두 가지가 드러나 재결정했다**(§9):

1. 이 리포 전체에 `PreCompact`/`PostCompact` 훅이 **0개**다. 채널 «선택» 이 아니라 «신설»이고
   §1 Non-goal 이 그것을 금지한다.
2. `finishing.md:243-244` 가 이미 *"사용자가 `/compact` 를 실제 실행한 다음 턴에 **사용자
   트리거**로만 일어난다"* 고 적는다. 철회할 «자동 이어짐 약속» 이 애초에 없다.

**실제로 바꾸는 것** — `finishing.md:237` 의 *"compact 후 brainstorming 진입 준비됨"* 안내.
「준비됨」은 압축 뒤의 상태에 대한 주장인데 아무도 확인하지 않는다. *"다음 턴에 직접
`Skill superpowers:brainstorming <경로>` 를 부르세요"* 로 바꾼다 — 사람이 유일한 운반자임을
숨기지 않는 문면이다.

`:239` 템플릿의 `<brief-path>` 자리표시자 둘은 §5 에서 자리 ① 과 함께 다룬다(같은 결함이다).

## 4. 묶음 3 — 배포 경계

### 4.1 zero-tool probe 선결조건

`reviewing-brief/SKILL.md:107` 이 `docs/audits/2026-07-27-spec-distill-zero-tool-probe.md` 의
`**분기 판정:**` 한 줄을 **cwd 상대경로**로 읽고, 없으면 파이프라인을 시작하지 않는다.
그 파일은 `docs/audits/` 에 있어 **플러그인 배포 단위 밖**이다 — devbrew 리포 밖 사용자에게는
존재하지 않으므로 fail-closed 가 곧 100% 차단이다. N3 위반.

현재 판정은 `ZERO_TOOL_OK`(`docs/audits/2026-07-27-…:121`)이므로 **오늘 도는 갈래는 차단
게이트**다. 분기를 지우고 그 갈래만 남긴다 — 완화가 아니라 유지다.

| 파일 | 지금 | 바꾼 뒤 |
|---|---|---|
| `skills/reviewing-brief/SKILL.md:105-125` | 감사 파일 판정으로 두 갈래 | 절 삭제. 충실도 verdict = 무조건 **hard gate** |
| `tests/test_brief_agents.sh:9, :18-25` | 감사 파일 부재 시 `exit 1` | 삭제 |
| `tests/test_brief_agents.sh:100-108` | verdict 따라 `tools: []` ↔ `tools: Read` | **무조건 `tools: []`** |
| `tests/test_reviewing_brief_skill.sh:162` | `P1`·`P2`·`P3`·`canary`·`census`·`ZERO_TOOL_*` 토큰 존재 락 | 삭제 |
| `templates/interview-audit-template.md:57` | `- 격리: zero-tool probe <…>` 줄 | 삭제 |

**대체물이 아닌 이유.** 무조건 `tools: []` 요구는 신설이 아니다 — 같은 플러그인의
`tests/test_seed_agents.sh:123-134` 가 `seed-critic`·`seed-readback` 에 대해 **감사 파일 종속
없이 정확히 그 형태**로 이미 출하돼 있다. 뒤쪽을 앞쪽 모양으로 맞추는 것이고, 결과적으로
기계가 **줄어든다**.

**함께 사라지는 것, 명시적으로** — ⑴ 격리 실패 시 남기던 degrade record 2건(`component: critic`
/ `component: readback`). 실패 분기 자체가 없어진다. ⑵ `ZERO_TOOL_UNAVAILABLE` 일 때의 D2
미충족 보고 경로.

**감사 문서 자체는 지우지 않는다.** 그것이 `tools: []` 집행의 근거 기록이다. 지우는 것은
**실행 시점에 그 파일을 읽는 코드**이며, 이 구별이 N3 의 전부다.

### 4.2 N5 — 대상을 열거에서 도출로

`tests/test_brief_agents.sh:10` 의 `ISOLATED=("brief-critic" "brief-readback")` 은 손으로 적은
둘이다. 이 플러그인에서 `tools: []` 를 선언한 에이전트는 **넷**이다:

| 파일 | 줄 | 선언 |
|---|---|---|
| `agents/brief-critic.md` | 14 | `tools: []` |
| `agents/brief-readback.md` | 13 | `tools: []` |
| `agents/seed-critic.md` | 14 | `tools: []` |
| `agents/seed-readback.md` | 15 | `tools: []` |
| `agents/brief-direction-reviewer.md` | 14 | `tools: Read, Grep, Glob, WebSearch, WebFetch` |

두 테스트가 각자 둘씩 덮어 **우연히** 넷이 다 걸린다. 다섯 번째가 생기면 아무 락도 안 걸린다.
`agents/*.md` 를 스캔해 `tools: []` 인 파일을 대상으로 도출한다.

### 4.3 `next_phase` 값 고정 해제

`scripts/check_brief.py:909-910` 이 `next_phase: superpowers:brainstorming` 을 **정확 일치**로
요구한다. superpowers 없는 사용자에게 구조 게이트가 통과 불가가 되므로 probe 선결조건과 같은
결과를 낸다(C19).

**`next_phase` 를 읽는 런타임 소비자는 없다.** 템플릿·픽스처·이 게이트뿐이고, superpowers 부재
처리는 `finishing.md:172` 가 스스로 한다(loud advisory 후 STOP). 게이트만 하드 요구하고 스킬은
graceful degrade 하는 **정책 불일치**가 여기 있다.

**처방** — 값 고정을 형태 검사로 바꾼다: `next_phase:` 키가 있고 값이 비어 있지 않을 것.
`interview-seed` 가 이미 `next_phase: spec-distill:interview` 를 쓰므로 형태 검사가 두 산출물
타입에 모두 맞는다.

## 5. 묶음 4 — 재사용을 막는 리터럴

### 5.1 핸드오프 펜스 — 결함이 상정보다 작다

`finishing.md` 의 두 펜스 사이가 자리 ①이다. 앞 bash 펜스가 `PAYLOAD`·`CODEX_DIR_YAML`·
`CODEX_FID_YAML` 을 정하고(`:93-98`), 뒤 펜스가 그 값으로 skill 을 호출한다(`:101`). 셸 변수는
펜스를 넘지 않으므로 **운반자는 모델 산문**이다.

코드를 읽고 인터뷰의 서술을 두 가지 정정한다:

**정정 ⑴ — `<file>` 자리표시자는 이미 fail-closed 다.** `PAYLOAD="docs/superpowers/interview/
<file>"`(`:95`)를 그대로 복사하면 `build_brief_bundle.py` 의 파일 존재 검사가 실패해 rc 2 를
내고, `reviewing-brief` 는 *"critic 을 dispatch 하지 않는다"* 로 간다. 도달 검사가 실재하고
작동한다 — §1.2 가 말한 「검사는 있고 명명이 없다」의 실례다.

**정정 ⑵ — 진짜 결함은 인자 하나다.** `reviewing-brief` 는 `$PAYLOAD`·`$AUDIT`·
`$CODEX_DIR_YAML`·`$CODEX_FID_YAML` **네 개**를 호출자가 쥐고 넘기는 값이라고 명시하는데,
`:101` 은 **세 개**만 넘긴다. `$AUDIT` 이 빠지면 조용히 죽지는 않으나 충실도 리뷰가 통째로
skip 되어 degrade record 로만 남고, 사용자가 Step B 게이트에서 그것을 읽어야만 알 수 있다.

**그리고 락이 결함을 고정하고 있다.** `tests/test_brief_review_entry.sh:172` 가 세 변수만
순회하고 `:190` 이 세 할당만 확인한다. 이 락은 결함을 통과시키는 것이 아니라 **결함을
요구한다** — 인자를 넷으로 고치려면 락도 함께 고쳐야 한다.

**처방** — `:95` 에 `AUDIT=` 를 추가하고, `:101` 을 네 인자로, `:104` 산문의 "세 인자"를
"네 인자"로, 두 락을 넷으로. `<file>` 자리표시자는 유지한다(그 자리는 Step A 가 방금 쓴 경로를
모델이 넣는 자리이고, 틀리면 fail-closed 로 잡힌다).

### 5.2 하드코딩

| 대상 | 지금 | 바꾼 뒤 |
|---|---|---|
| 목적지 스킬 이름 | `hooks/review-dispatch.py` 의 **런타임 메시지 문자열 6곳** — `:89` `:466` `:585` `:700` `:721` `:754` | `scripts/hook_common.py` 의 상수 하나 + f-string 보간 |
| 〃 (문서) | 같은 파일 `:16` 의 **모듈 docstring** | 보간 대상이 **아니다** — 모듈 docstring 은 f-string 이 될 수 없다. 설계 의도를 적는 산문이므로 리터럴을 유지하고 상수와 함께 손으로 갱신한다 |
| 경로 접두 | `scripts/arm_ledger.py:41` `PREFIX` ↔ `scripts/resolve_mode.py:9` `PATH_PREFIX` — 같은 값의 두 정의 | `scripts/hook_common.py` 로 통합, 양쪽이 import |
| `/compact` 템플릿 | `finishing.md:239` 의 `<brief-path>` ×2 | Step A 가 쓴 경로로 채워 노출 |

**`/compact` 자리표시자는 자리 ①과 처방이 다르다.** 자리 ①의 `<file>` 은 치환에 실패하면
`build_brief_bundle.py` 가 잡는다(§5.1 정정 ⑴). `/compact` 템플릿은 **사용자에게 그대로 보이게
노출**되므로 치환에 실패하면 사용자가 깨진 명령을 붙여넣게 되고, 그것을 잡는 자리가 **없다.**
결함의 종류는 같지만 fail-closed 유무가 갈리므로 이쪽만 실제 치환을 요구한다.

**새 추상을 만들지 않는 근거는 파일 자신에 있다.** `hook_common.py` 의 docstring 이 *"사본이
아니다 — 같은 플러그인 안이므로 import 하나로 중복이 소멸한다"* 라고 적고, 같은 이유로
`arm_ledger.py` 의 `state_file_for` 를 이미 흡수했다(census #122). 세 번째 항목을 같은 자리에
넣는 것이며 설정 파일도 레지스트리도 아니다 — 상수다(N4).

**목적지 상수의 형태.** `review-dispatch.py` 는 목적지 skill 을 직접 호출하지 않는다 —
`decision: "block"` 과 `reason` 텍스트를 내고 모델이 그것을 읽는다. 즉 「목적지」는 **메시지에
박힌 이름**이다. 상수 하나 + 보간이면 충분하고, 그 이상은 C8 이 기각한 전면 데이터-구동이다.

## 6. 묶음 5 — 질문의 재생

§1 Goal 의 뒷문장 *"다음에 생길 자리도 같은 질문을 받게 한다"* 를 무엇으로 받치는가.
설계문서의 축 표는 어느 쪽이든 남으므로, 질문은 **그 위에 무엇을 더하는가**다.

`plugins/plugin-audit/scripts/audit-workflow.js:294` 의 `AXES` 여섯 중 3번
「enforcement 능력」(`:345`)이 *"대상의 hook/enforcement 가 실제로 무엇을 **막는가**"* 는 묻지만
*"그 지시가 수신자에게 **도달하는가**"* 는 안 묻는다. **빈칸을 채우는 것이지 축을 만드는 것이
아니다.** 그 축의 질문 목록에 한 항목을 더한다:

> 훅·스킬·커맨드가 **모델에게** 하는 지시가 모델이 실제로 읽는 채널로 나가는가 —
> `systemMessage` 는 사람 채널이다. 그리고 한 산출물이 다음 산출물에 넘기는 값(경로·인자·표식
> 파일)에 **그것이 도착했는지 확인하는 자리**가 있는가, 아니면 도착을 가정만 하는가.

CLAUDE.md 의 *"버그가 리뷰를 탈출하면 잡았어야 할 reviewer persona 를 편집하는 것이 해결책 —
그 commit 이 compounding 이벤트(Law 3)"* 가 이 형태의 이름이다.

**한계, 명시적으로** — 이 질문은 사용자가 `/plugin-audit` 을 실행할 때만 발화한다. 감사 없이
새 자리가 생기면 여전히 안 묻는다. 상시 발화하는 자리(CLAUDE.md)는 상시 로드 표면을 늘려
기각했다(§10).

## 7. 검증

### 7.1 mutation 매트릭스

새로 넣는 락은 전부 mutation 으로 이빨을 확인한다. **통과가 정답인 assert 는 모양으로 이빨을
판별할 수 없다** — 이 리포가 반복해서 겪은 실패다.

| # | 락 | 변이 | 기대 |
|---|---|---|---|
| M1 | qg 훅이 모델용 문장을 `additionalContext` 에 낸다 | 그 문장을 `systemMessage` 로 되돌린다 | RED |
| M2 | qg 훅이 사람용 문장을 `systemMessage` 에 낸다 | `systemMessage` 키를 제거한다 | RED |
| M3 | project-init 훅 동일 (M1·M2 대칭) | 동일 | RED |
| M4 | 격리 에이전트 전원이 `tools: []` | 하나를 `tools: Read` 로 | RED |
| M5 | 대상이 도출된다(N5) | 다섯째 `tools: []` 에이전트를 픽스처로 추가하고 그것을 `tools: Read` 로 | RED |
| M6 | 핸드오프가 네 인자 | `$AUDIT` 를 뺀다 | RED |
| M7 | 목적지 상수가 한 자리에서 온다 | 상수 **값을 바꾸고** 런타임 메시지 6곳이 전부 따라오는지 | 6곳 모두 변화 (docstring `:16` 은 대상 아님 — §5.2) |
| M8 | `next_phase` 형태 검사 | 값을 지워 빈 값으로 | RED |

**M5 가 이 표에서 가장 중요하다.** M4 만으로는 열거와 도출이 구별되지 않는다 — 오늘의 넷은
열거로도 통과한다. 다섯째를 만들어야 N5 가 실제로 도출인지가 갈린다.

**M7 은 값 변경 변이다.** 삭제 변이로는 안 잡힌다 — 상수를 지우면 import 에러로 전부
죽으므로 「함께 죽었다」가 「한 자리에서 온다」의 증거가 되지 못한다.

### 7.2 삭제에는 부재 락을 만들지 않는다

지운 것들(sentinel, probe 선결조건, offer)에 대해 「없음」을 확인하는 락을 만들지 않는다.
부재만 보는 락은 **대상을 통째로 지워도 통과**하므로 스위트의 GREEN 을 완료로 오독하게 만든다.
지운 것의 검증은 **기존 스위트가 깨지지 않는 것**으로 한다.

### 7.3 작업 순서와 형제 세션

| 순서 | 무엇 | 형제 겹침 |
|---|---|---|
| 1 | **baseline 캡처** — 네 플러그인 스위트를 손대기 전에 돌려 선재 RED 를 기록 | — |
| 2 | 묶음 1 (채널) — quality-gates · project-init | 없음 |
| 3 | 묶음 2 (약속 철회) — quality-gates · spec-distill | 없음 |
| 4 | 묶음 3 (배포 경계) — spec-distill | 없음 |
| 5 | 묶음 4 (리터럴) — spec-distill | **`hooks/review-dispatch.py` 겹침** |
| 6 | 묶음 5 (감사 축) — plugin-audit | 없음 |

**1번이 먼저인 이유** — 이 리포에는 CI 가 없고 `main` 에 오래된 RED 가 있다. baseline 없이
시작하면 이후의 RED 가 내 것인지 원래 것인지 가릴 수 없다.

**형제 세션 조율.** 병행 세션이 같은 `review-dispatch.py` 의 **차단 결정 두 자리**(`:599` 구조
검증 실패 차단, `:752` dispatch 강제)를 자기 범위로 열어 두었다. 이쪽은 **메시지 문자열 7곳과
상수**이고 줄이 겹치지 않는다. 합의된 규칙대로 **편집 직전에 무엇을 어떻게 바꾸는지 한 줄을
보내고, 답을 기다리지 않고 진행하되 받은 쪽이 이의가 있으면 되돌리기 전에 말한다.**
머지는 먼저 끝난 쪽을 다른 쪽이 따라가며 rebase 가 아니라 merge 다.

**이 설계는 PR 을 배정하지 않는다.** 몇 개의 커밋·PR 로 나뉘는지는 계획이 정한다.

## 8. 컴포넌트와 버전

| 플러그인 | 무엇이 바뀌나 | bump |
|---|---|---|
| `quality-gates` | 묶음 1(훅 출력) · 묶음 2(offer + sentinel 제거) | **major** — 출하된 자동 offer 가 사라진다 |
| `spec-distill` | 묶음 2(안내 문구) · 묶음 3(probe·게이트) · 묶음 4(리터럴·인자) | minor |
| `project-init` | 묶음 1(훅 출력) | minor |
| `plugin-audit` | 묶음 5(축 질문) | minor |

네 플러그인 전부 같은 커밋에서 `plugin.json` bump + `CHANGELOG.md` 항목. 안 하면 cache key 가
조용히 stale 이 된다.

**`quality-gates` 의 major 근거** — 자동 offer 는 사용자에게 보이던 동작이고 제거하면 예고 없이
사라진다. CLAUDE.md 의 one-minor deprecation window 대상인지 계획 단계에서 판정한다.
(`project-init` v2.2.0 이 non-blocking advisory 훅을 window 없이 제거한 전례가 있으나, 그
CHANGELOG 이 *"이 근거는 훅이 blocking 이었다면 성립하지 않는다"* 고 스스로 적어 두었다 —
offer 는 사용자 상호작용이므로 그 전례를 그대로 인용할 수 없다.)

## 9. 재결정 기록

인터뷰 종료 게이트에서 사용자가 31항목을 확정했다. 그중 하나를 **보고 후 재결정**했다(P23 —
재발견 금지는 반증 금지가 아니다).

| | |
|---|---|
| **원래 (C12)** | `/compact` 이음매의 채널은 `PreCompact matcher=manual` 로 한다 — 수동 압축에만 걸려 사람이 진행을 트리거한다는 보장이 유지된다 |
| **재결정** | 채널을 붙이지 않고 안내 문구의 도착 주장만 거둔다 |
| **근거** | ⑴ 이 리포 전체에 `PreCompact`/`PostCompact` 훅이 0개다(유일한 언급이 측정 픽스처) — 채널 선택이 아니라 **신설**이고 §1 Non-goal 이 그것을 금지한다. ⑵ `finishing.md:243-244` 가 이미 사람을 유일 트리거로 적고 있어 철회할 자동 이어짐 약속이 없다. ⑶ C3 이 qg 에서 같은 형태(자동 이어짐 철회 + 명시 호출이 정본)를 이미 택했다 |

**측정은 원안을 지지했다는 사실도 남긴다** — `PreCompact manual` 이 발화하고 그 출력이 압축을
넘어 모델에 도달하는 것은 인터뷰에서 실측됐다(`shared/tests/fixtures/seamprobe/MEASUREMENT.md`
의 `COMPACT_CHANNEL_OK`). 기각의 근거는 「되지 않는다」가 아니라 「새로 만들 값어치가 없다」다.
반증되면 재측정 없이 되살릴 수 있다.

**brief 의 C12 기록은 고치지 않는다.** 문제공간 산출물을 사후 편집하면 출처가 흐려진다.

## 10. 기각한 길

| 길 | 왜 버렸나 |
|---|---|
| `/compact` 에 `PreCompact` 훅 신설 | §9 |
| `/compact` 에 `SessionStart matcher=compact` | 인터뷰가 이미 기각 — 그 훅의 필터는 수동/자동 압축을 구별하지 못해, 진행을 요청한 적 없는 세션에도 다음 단계 지시가 도착한다 |
| `/compact` 에 `PostCompact` | 도달지가 사람인지 모델인지 번들 서술과 실측이 어긋난다(OQ 미해소) + 자동 압축에도 걸린다 |
| 모델용 지시를 `additionalContext` 로 **옮기기** | 사람이 그 경고를 못 보게 된다. 한 채널을 고치면서 다른 채널을 깬다 — N1 이 «병행» 인 이유 |
| sentinel 을 남기고 offer 만 지우기 | 아무도 안 읽는 파일을 계속 쓰는 것. Law 3 이 이름 붙인 theater |
| sentinel 의 소비자를 `/qg-publish` 로 옮기기 | C3·C9 를 동시에 뒤집고, 지금 브랜치 diff 만으로 독립 동작하는 `/qg-publish` 를 세션 상태에 묶는다 |
| probe 판정의 앵커만 다른 파일로 옮기기 | C7 이 금지한 «대체물». 검사 대상이 자기 앵커를 쥐는 문제가 그대로 따라온다 |
| 감사 문서를 배포 단위 안으로 복사 | 낡은 판정 텍스트를 설치본에 동결한다 |
| 새 도달 «검사층» 신설 | 기존 암묵 검사와 갈라져 어느 쪽이 정본인지 미정의로 남는다. 그리고 검사 결과를 누가 읽는지 미정의인 채 배포하면 **검사층 자체가 새 이음매**가 된다 |
| 질문의 재생을 CLAUDE.md 조항으로 | 도달률은 가장 높으나 비용이 상시다. 리포가 최근 로드 표면을 19.8% 줄였다(#122) |
| 질문의 재생을 처분 회계 락에 얹기 | 형제 세션 소관이고, 결정론 락 확장이라 Non-goal 의 "새 검사층"에 걸린다 |
| 강제기를 전면 데이터-구동으로 재설계 | 인터뷰 steelman 에서 switched — 중복은 틀린 추상보다 훨씬 싸다 |

## 11. 남은 것

- **OQ-A `stop_hook_active`** — 하니스가 `Stop` 훅 payload 에 실어 보내고(번들 스키마 + 선행
  사이클 실측이 `False → True → True` 전이를 기록) 이 리포의 실행 코드 참조는 **0곳**이다.
  반복 억제는 원장(`dispatch_attempts`·`armed_paths`·in-flight 표시)이 맡는다.
  **범위 밖으로 정했다** — C8 은 리터럴 추출이고 이것은 참조 추가이며, 대상이 이 훅의 유일한
  폭주 방지 장치라 회귀 위험이 가장 크다. **처방까지 적어 둔다**: 참조를 넣으면 기존 억제의
  발동 조건이 줄어들 수 있는데 스위트를 돌려서는 보이지 않는다(GREEN 이 유지된다). 무엇이 그
  억제를 트리거하는지를 코드에서 **먼저 전수 열거**한 뒤 수정 전후로 그 집합을 비교하라.
- **OQ-B 삭제의 효과** — 이 설계는 삭제의 효과를 재지 않는다. 재는 것은 「삭제가 무엇을 깨지
  않았는지」(스위트)뿐이다.
- **OQ-C 증상** — 감사가 발단으로 든 두 증상(「brief 리뷰가 잘 안 불린다」·「qg 가 끝나도 PR
  발행으로 안 이어진다」)이 실제로 줄었는지는 이 작업으로 답해지지 않는다. 범위 완료와 증상
  개선은 같은 것이 아니다.
- **OQ-D 하니스 목록 오표시** — 하니스의 에이전트 목록이 `tools: []` 선언 넷을 전부
  **"All tools"** 로 표시한다(`brief-critic`·`brief-readback`·`seed-critic`·`seed-readback`).
  같은 목록이 `brief-direction-reviewer` 는 정확히 표시하므로 **오표시는 빈 allowlist 에만**
  걸린다. 집행 자체는 2026-07-27 probe 가 확인했으므로 표시만 틀렸다. 플러그인 쪽에서 고칠
  수단이 없고, 위험은 다음 저자가 그 목록을 믿고 선언을 «고치는» 것이다. **처분 미판정.**
- **OQ-E subagent 왕복** — dispatch·복귀의 «운반» 절반. 이쪽 소관이나 이번 미착수.
- **OQ-F 스킬↔스크립트 왕복 · 스킬 계층 권한 키** — 범위 밖.
- **OQ-G 정책 불일치의 나머지** — §4.3 이 게이트 쪽을 맞췄으나, 외부 플러그인 의존을 스킬 층은
  graceful degrade 로 다루고 게이트 층은 형태 검사로 다루는 두 층의 규약을 어디서 하나로 적을지.
- **OQ-H 훅 커버리지 서술** — 감사의 서술이 삭제된 파일 둘을 인용한다. 다시 쓰거나 인용을
  그만두거나 — 이번에 고르지 않았다.
- **관찰 하나(범위 밖)** — `project-init` 의 브랜치 검사 정규식(`post-tool-use.py:32`)이
  `checkout -b`·`switch -c` 두 형태만 잡는다. 브랜치 개명과 워크트리 생성 시의 브랜치 지정은
  안 걸린다 — 이 워크트리의 브랜치가 검사를 안 받은 이유다. 하드코딩이 아니라 커버리지 갭이라
  이번 범위에 넣지 않았다.

## Handoff Context

`/compact` 를 지나면 대화가 사라진다. 이 문서만 읽고 이어갈 수 있어야 하는 것을 남긴다.

### TL;DR

아홉 자리를 **결함의 종류**로 다섯 묶음에 나눠 고친다. 순증은 셋뿐이다 — 훅 출력 필드
`additionalContext`(묶음 1), `hook_common.py` 의 상수 둘(묶음 4), 감사 축 질문 한 줄(묶음 5).
나머지는 전부 삭제이거나 분기 제거다. **새 훅 0 · 새 검사층 0 · 새 추상 0.**

### 이 문서 밖에 있으면 안 되는 암묵 컨텍스트

- **작업은 워크트리 `.claude/worktrees/feature+seam-channel-verification`, 브랜치
  `feature/seam-channel-verification`, base `094ecbc`(= `origin/main`)에서 한다.** 인터뷰
  산출물 셋(brief · audit · `shared/tests/fixtures/seamprobe/`)이 이미 그 안으로 옮겨져 있고
  `main` 쪽 원본은 삭제됐다.
- **인용한 사실은 전부 `094ecbc` 의 코드에서 직접 확인했다.** 감사 문서를 전제로 쓴 것이
  아니다 — 그리고 확인 과정에서 인터뷰의 서술 셋이 틀린 것으로 드러났다: ⑴ probe 선결조건은
  두 자리가 아니라 **네 파일** ⑵ `/compact` 자리의 자동 이어짐 약속은 **존재하지 않는다**
  ⑶ `<file>` 자리표시자는 **이미 fail-closed** 다. 계획 단계에서 다시 확인할 것.
- **번들 사실을 재기 전에 `docs/superpowers/specs/` 를 먼저 훑어라.** 이번 사이클도 지난
  사이클도 리포에 이미 있는 실측을 못 찾고 다시 쟀다. 배달지 표는
  `2026-08-05-agent-transparency-design.md:359` 에 있다.
- **번들에는 사람용 서술과 payload 스키마가 따로 있고 서술이 스키마보다 적게 적혀 있다.**
  서술만 읽고 「그 필드는 없다」를 단정하면 틀린다. 추출 방법 둘은
  `shared/tests/fixtures/seamprobe/MEASUREMENT.md` 의 부록이 가른다.
- **`tools: []` 집행은 두 하니스 버전에서 확인됐다**(2026-07-27 probe + 2026-09-02 인터뷰).
  범위 안의 다른 측정 셋은 단일 버전이다.
- **형제 세션이 `plugins/spec-distill/hooks/review-dispatch.py` 의 차단 결정 두 자리를 자기
  범위로 열어 두었다.** 그 파일을 편집하기 직전에 한 줄 통지한다.
