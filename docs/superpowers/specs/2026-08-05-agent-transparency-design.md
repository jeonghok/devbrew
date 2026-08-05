# agent-transparency — 설계

> **이해부채를 줄인다.** 위임한 에이전트가 무엇을 했고 판단이 무엇에 근거하는지를, 결정·판정
> 시점에 먼저 드러낸다.

devbrew의 다섯 번째 플러그인. 사용자가 판단해야 하는 순간에 판단할 재료가 이미 나와 있게 만든다.
입력은 [`docs/superpowers/interview/2026-08-02-comprehension-debt-plugin-interview.md`](../interview/2026-08-02-comprehension-debt-plugin-interview.md)
(문제공간 brief)이며, 이 문서는 그 해답공간이다.

## 목차

- [1. Context · Why](#1-context--why)
- [2. Goals · Non-goals](#2-goals--non-goals)
- [3. 불변식](#3-불변식)
- [4. 제약](#4-제약)
- [5. 아키텍처](#5-아키텍처)
  - [5.1 부품 4개](#51-부품-4개)
  - [5.2 데이터 흐름](#52-데이터-흐름)
  - [5.3 왜 이 조합인가 — 측정 근거](#53-왜-이-조합인가--측정-근거)
- [6. 컴포넌트 상세](#6-컴포넌트-상세)
  - [6.1 output style — 이 플러그인의 본체](#61-output-style--이-플러그인의-본체)
  - [6.2 SubagentStop 훅](#62-subagentstop-훅)
  - [6.3 명령 + skill](#63-명령--skill)
  - [6.4 추출 스크립트](#64-추출-스크립트)
- [7. 에러 처리 · 강등](#7-에러-처리--강등)
- [8. 파일 목록](#8-파일-목록)
- [9. Acceptance Criteria](#9-acceptance-criteria)
- [10. 검증 계획](#10-검증-계획)
- [11. 기각된 대안](#11-기각된-대안)
- [12. 미해결](#12-미해결)
- [13. Metadata](#13-metadata)

## 1. Context · Why

작업이 진행되는 속도가 사용자가 이해하는 속도보다 빠르다. 특히 **subagent 사이의 대화가 대화창에
드러나지 않아서**, 사용자는 결론만 받고 그 결론이 어디서 왔는지 모르는 상태로 다음 결정을 요구받는다.
이 상태에서 고른 방향은 자주 틀린다.

이 격차는 문헌에서 **comprehension debt**(이해부채)로 불린다 — 존재하는 것과 사람이 이해하는 것
사이의 격차가 보이지 않게 누적되는 현상. 정보 비대칭 쪽 이름은 **Hidden Profile**이다 — 한쪽만
가진 정보가 공유되지 않은 채 결정에 쓰이는 상태.

**핵심 진단**: 문제는 설명의 *부재*가 아니라 **설명했다고 착각하는 것**이다. 자기가 무엇을 이미
아는지는 자기가 판단할 수 없다. 이 설계는 그 판단을 모델에게 맡기지 않고, 순간과 담을 것을 미리
못박는다.

### 무엇이 이미 해결돼 있나 (재구현 방지)

브리프 작성 중 실측한 결과, 플랫폼이 이미 상당 부분을 shipping하고 있었다.

| 이미 되는 것 | 어디서 | 남는 것 |
|---|---|---|
| subagent의 존재·진행·비용 | 에이전트 패널이 행마다 `이름 · 상태 · 토큰 · 모델 · effort` 렌더 | **무엇을 찾았는지·근거가 뭔지** |
| 대화 기록의 영구 보관 | `~/.claude/projects/<슬러그>/<세션>/subagents/agent-*.jsonl` — 에이전트 대화 전문이 그대로 | **선별과 압축** |
| 매 턴 적용되는 지침 | `output style`이 시스템 프롬프트를 직접 수정 | 그 안에 넣을 **내용** |

그래서 이 플러그인은 **저장하지 않는다.** 원장도 상태 파일도 만들지 않는다. 하는 일은 이미 있는
것에서 **골라내고 줄이는 것**이다.

## 2. Goals · Non-goals

### Goals

- **G1** — 사용자가 판단을 요구받는 순간에, 판단할 재료가 이미 화면에 있게 한다.
- **G2** — subagent가 무엇을 찾았고 그것이 판단을 어떻게 바꿨는지가 대화창 표면에 나오게 한다.
- **G3** — 사용자가 나중에 물었을 때, 이미 디스크에 있는 기록에서 답을 만들어 준다.
- **G4** — 이 프로젝트에서만 통하는 말이 설명 없이 나가지 않게 한다.
- **G5** — 내장 `Explanatory` 스타일이 하던 일을 **전부** 계속 한다. 대체하는 이상 못해지면 안 된다.

### Non-goals

- **N1** — 설명의 **총량**을 늘리는 것. 성공은 길이가 아니라 *빠짐없음 + 형식*으로 달성한다.
- **N2** — 작업을 늦추거나 막는 것. → [불변식](#3-불변식)
- **N3** — 새 기록 장치(원장·로그·상태 파일)를 만드는 것. 트랜스크립트가 이미 그 역할을 한다.
- **N4** — subagent 내부에 지침을 심는 것. subagent는 자기 시스템 프롬프트를 따로 가지므로
  닿지 않으며, 리포 안 17개 agent 정의를 고치는 방식은 devbrew 밖에서 작동하지 않는다.
- **N5** — 프로젝트 고유 용어의 **사용 금지**. 금지하면 이 리포에서는 말을 할 수 없다
  (`qg`·`floor`·`steelman` 등은 실재하는 물건의 이름이라 대체어가 없다).
- **N6** — 말투·어조·응답 언어를 바꾸는 것. output style은 그것들을 바꿀 수 있지만, 이 스타일에는
  그런 규칙을 한 줄도 두지 않는다.

## 3. 불변식

> **이 플러그인은 설명을 *더할* 뿐, 어떤 작업도 늦추거나 막지 않는다.**
>
> 훅은 자리만 만들고 검사·차단하지 않는다. 어떤 경로에도 사용자를 기다리게 하거나 도구 실행을
> 되돌리는 지점이 없다. `decision: "block"`은 어느 훅에서도 내지 않는다.

이 불변식은 나중에 *"확실하게 하려면 검사를 넣자"*는 유혹이 왔을 때 거절할 근거다. 확실함을
얻으려고 억제를 들이는 순간 이 플러그인의 존재 이유가 뒤집힌다.

**유일한 예외는 비밀 유출이다.** 한 번 새면 되돌릴 수 없으므로 마스킹만은 결정론이며,
마스킹이 불가능하면 본문을 내지 않는다([§7](#7-에러-처리--강등)).

## 4. 제약

| # | 제약 | 출처 |
|---|---|---|
| K1 | 억제 금지 — 모델 능력을 깎는 어떤 장치도 안 된다 | 사용자 |
| K2 | 토큰 비용이 설계 제약이다. 빠짐없음을 포기하지 말고 **압축**으로 달성한다 | 사용자 |
| K3 | 적용 범위는 이 리포의 모든 작업. 특정 플러그인 안이 아니다 | 사용자 |
| K4 | 표준 용어를 쓰고, 이 프로젝트에서만 통하는 말은 지양하며, 비유를 쓰지 않는다 | 사용자 원 요청 |
| K5 | 설명 시점은 수행 전 · 수행 뒤 · 혹은 중간 | 사용자 원 요청 |
| K6 | 성공 기준은 "빠짐없음"이며 "빠른 파악"으로 **교체**하지 않는다 | 사용자 |
| K7 | 모든 훅에 kill switch 2종 | devbrew 규약 |
| K8 | 모든 skill에 `cost_class` 선언 | devbrew 규약 |

K4는 **자기 자신에게도 적용된다** — 이 플러그인의 이름·설명·본문이 자기 규칙을 통과해야 한다.

## 5. 아키텍처

### 5.1 부품 4개

| # | 부품 | 하는 일 | 상태 | 비중 |
|---|---|---|---|---|
| 1 | **output style** | 5개 순간에 무엇을 담아야 하는지 규정 + `Explanatory` 흡수 | 없음 | **본체** |
| 2 | **`SubagentStop` 훅** | 에이전트가 끝난 직후 설명 자리를 만든다 | 없음 | 백스톱 1건 |
| 3 | **명령 + skill** | `/why`(근거) · `/recap`(현황) 진입점 | 없음 | 풀 경로 |
| 4 | **추출 스크립트** | 트랜스크립트를 읽고 비밀을 마스킹해 넘긴다 | 없음 | 풀 경로 |

**상태 파일이 하나도 없다.** 훅은 사실상 상수를 출력하고, 스크립트는 읽기만 한다. 실패할 지점이
구조적으로 적다.

### 5.2 데이터 흐름

```
[푸시 — 자동]

   output style ──(시스템 프롬프트, 매 턴)──▶ 모델 ──▶ 대화창: 다섯 순간의 설명
                                              ▲
   SubagentStop 훅 ──(additionalContext)───────┘
        "방금 끝난 에이전트에 대해 내라 — 누가 / 무엇을 찾았나 / 근거 위치 / 판단 변화"


[풀 — 사용자가 물을 때만]

   /why · /recap ──▶ skill ──▶ extract_transcript.py
                                    │  ① 세션 디렉토리 글롭
                                    │  ② jsonl 파싱 · 발췌
                                    │  ③ 비밀 마스킹  ← 유일한 결정론 지점
                                    ▼
                              마스킹된 발췌 ──▶ 모델 ──▶ 압축 답변
```

푸시가 담는 것은 각 순간의 필수 항목이고, 근거 전문·기각 목록·에이전트 원문은 풀에 남는다.
**설명 끝에 `/why`를 안내하지 않는다** — 매 순간 안내 문구를 붙이면 그 자체가 소음이 된다.
명령은 README와 명령 목록에서 발견된다([§12 OQ-E](#12-미해결)).

분량은 순간마다 다르고 줄 수로 고정하지 않는다(가짜 정밀함이 된다). 대신 **무엇을 담느냐**를
고정한다. 읽는 시간은 줄 수가 아니라 **형식**이 줄인다 — 표 · 고정된 순서 · 굵은 라벨.

### 5.3 왜 이 조합인가 — 측정 근거

플랫폼이 이 구조를 **강제한다.** 선택이 아니다.

| 순간 | 훅이 잡나 | 그래서 |
|---|---|---|
| 결정을 요청하기 직전 | ❌ `PreToolUse`는 `additionalContext`를 **지원하지 않는다** (`permissionDecision`·`updatedInput`만) | output style만 가능 |
| 판정이 나왔을 때 | ❌ 어떤 훅 이벤트도 아니다 — 모델만 안다 | output style만 가능 |
| 긴 작업 착수 직전 | ❌ `TaskCreated`는 `additionalContext` 없음 | output style만 가능 |
| **다른 에이전트 결과 도착** | ✅ `SubagentStop` — `additionalContext` 지원 | 훅 백스톱 |
| 작업 종료 | ⚠️ `Stop`은 지원하지만 **대화를 계속시킨다** → 턴이 안 끝나는 루프 | 훅 안 씀 |

그리고 statusline 계열은 **원리적으로** 내용을 못 싣는다 — `subagentStatusLine`이 받는 `tasks[]`에는
`id`·`name`·`status`·`tokenCount`·`model`·`effort`만 있고 findings 필드가 없다. 출력 토큰이 0이라
매력적이지만 담을 것이 메타데이터뿐이라 이번 목표(내용)에 못 쓴다.

## 6. 컴포넌트 상세

### 6.1 output style — 이 플러그인의 본체

`output-styles/agent-transparency.md` 파일 하나가 이 플러그인이 하는 일의 대부분을 담는다. 훅은
한 순간을 보조할 뿐이다.

#### 왜 이렇게 썼나 — 근거 4종

| 출처 | 규칙 | 반영 |
|---|---|---|
| Anthropic 프롬프트 가이드 | *"하지 말 것"보다 "할 것"을 말하라* | 부정문 최소화, 남긴 것엔 이유를 붙임 |
| 같은 곳 | *예시는 형식을 보여줄 때 빛난다. 하나(one-shot)로 시작* | `결정 요청 직전` 형식 예시 1개 |
| 같은 곳 | *이유를 설명하면 모델이 목표를 더 잘 이해한다* | 각 절에 이유 문장 |
| 같은 곳 | *짧게 시작하라. 길수록 좋은 게 아니다* | 약 380 단어 |
| **내장 `Explanatory` 본문** | 역할 문장 → **균형 조항** → 형식 예시 → 안티패턴 | 구조를 그대로 따름 |
| output style 공식 예시 · `Explanatory` | 마크다운 헤더 사용 | XML 태그 대신 마크다운 |

**언어는 영어다.** `Explanatory` 원문이 영어이고, 그 원문이 이 파일의 모범이기 때문이다.
지침이 영어인 것은 응답 언어와 무관하다 — 언어 규칙을 두지 않으므로 사용자가 쓰는 언어를 따른다(N6).

#### 전문

```markdown
---
name: agent-transparency
description: Reduces comprehension debt — surfaces what delegated agents did and what
  your judgment rests on, at decision and verdict points
keep-coding-instructions: true
force-for-plugin: true
---

You are in 'agent-transparency' output style mode, where you put the material for a
judgment in front of the user before you ask them to make it. The user understands more
slowly than you work, and never sees the conversations of the agents you delegate to.

Balance transparency with task completion. Explain at the moments below; between them,
work as usual. A task that takes one sentence to describe takes one sentence to report.

## Moments that require an explanation

| Moment | What it must contain |
|---|---|
| Just before you ask the user to decide | what you are asking / why these options / **what you discarded and why** / your recommendation and its basis |
| When another agent's result comes back | who / what they found / where the evidence is / **how it changed your judgment** |
| When a verdict or conclusion lands | the verdict / its basis / what was examined / **what was not examined** |
| Just before starting a long task | the steps / how many / what it will produce |
| When the work ends | what changed / what remains / what is next |

Always include the bolded items. Without them the user cannot imagine anything outside
the options you offered.

Example, just before asking the user to decide:

"**What I'm asking** — where cache expiry should be handled.
**Why these options** — expiry is checked only on the read path today, so the write path
cannot catch stale entries.
**What I discarded** — a background job: this repo has no scheduler, so it would need new
infrastructure.
**Recommendation** — ②, because it attaches to existing middleware and adds no new moving parts."

## Format

**When you explain at the moments above**, use tables, a fixed order, and bold labels, so
the user can find one item without reading the whole block. Structure does this, not
brevity — a shorter explanation that drops an item is worse, not better. Elsewhere, write
however the content wants to be written.

## Vocabulary

Terms that mean something only inside this project — tool names, abbreviations, internal
concepts — get one clause of explanation the first time they appear. Use them freely; just
pay for them on the spot. Prefer a standard term when one exists; otherwise say plainly
what the thing does. Do not assume the user knows a word because you know it — that is not
a judgment you are in a position to make.

## Insights

Before and after writing code, provide brief educational explanations about implementation
choices using (with backticks):

"`★ Insight ─────────────────────────────────────`
[2-3 key educational points]
`─────────────────────────────────────────────────`"

These insights belong in the conversation, not in the codebase. Focus on insights specific
to this codebase or the code you just wrote, rather than general programming concepts. Do
not wait until the end to provide insights. Provide them as you write code.
```

#### frontmatter 두 값의 의미

- `keep-coding-instructions: true` — **빠뜨리면 안 된다.** 기본값이 `false`라서 생략하면 Claude
  Code의 내장 소프트웨어 엔지니어링 지침이 통째로 사라진다. 그것이 K1이 금지한 억제다.
- `force-for-plugin: true` — 설치하면 자동 적용되고 사용자의 `outputStyle` 설정을 **덮어쓴다**.

#### `force-for-plugin: true`의 대가 (문서로 확인된 사실)

| 확인한 것 | 문서 원문 |
|---|---|
| `/config` 선택이 진다 | *"Overrides the user's `outputStyle` setting"* |
| 플러그인 `settings.json`으로 기본값을 넣는 우회로가 없다 | *"Only the `agent` and `subagentStatusLine` keys are currently supported"* |
| 컴포넌트만 따로 끄는 기능이 없다 | `claude plugin disable`은 플러그인 단위 |
| 여러 플러그인이 켜면 순서 의존 | *"Claude Code uses the first one loaded"* |

**따라서 이 스타일을 끄는 유일한 방법은 플러그인 전체를 비활성화하는 것이고, 그러면 훅과
`/why`·`/recap`도 함께 꺼진다.** devbrew 규약의 kill switch(K7)는 훅에만 걸 수 있고 output style에는
걸 수 없다 — 플랫폼이 플러그인 디렉토리에서 직접 읽어가므로 환경변수가 개입할 지점이 없다.
이 사실을 README 맨 앞에 경고로 둔다(AC17).

#### `Explanatory` 흡수 (G5의 검증 가능한 형태)

`## Insights` 절은 `Explanatory` 원문에서 문장 구조를 그대로 가져왔다(도입구 `"In order to
encourage learning,"`만 생략). 넘어와야 하는 요소는 넷이고, 그대로 [AC2](#9-acceptance-criteria)가 된다.

1. `★ Insight ─────` 블록 형식
2. 코드를 쓰기 **전과 후** 둘 다
3. **끝까지 미루지 않는다** — 쓰면서 낸다
4. 일반 프로그래밍 개념이 아니라 **이 코드베이스에 특유한** 것

> **주목** — `Explanatory`의 시점 규정(*"코드 쓰기 전과 후에, 미루지 말고"*)은 사용자 원 요청의
> "수행 전 · 수행 뒤 · 혹은 중간"(K5)과 **같은 구조**다. 이 플러그인이 하는 일은 새 규칙을 얹는
> 것이 아니라 그 시점 규정을 *코드*에서 *작업 흐름*으로 넓히는 것이다.

#### 용어를 왜 금지가 아니라 상환 의무로 쓰나

금지로 쓰면 이 리포에서 말을 할 수 없다(N5). 그리고 금지는 **검사할 대상이 무엇인지 정의해야
하는데**, 그 정의가 바로 K1이 금지한 억제 장치가 된다.

상환 의무는 검사 없이 작동하고, 실제 실패 양식을 정확히 겨냥한다 — 인터뷰 진행 중 모델이
`M1~M8`·`L1~L4` 같은 라벨을 정의 없이 쓴 것, 그리고 이 설계 대화에서 `output style`을 여덟 번
쓰도록 한 번도 설명하지 않은 것. 둘 다 "모르는 말을 썼다"가 아니라 **"설명했다고 착각했다"**였다.

### 6.2 SubagentStop 훅

`hooks/hooks.json`:

```json
{
  "hooks": {
    "SubagentStop": [
      { "hooks": [ { "type": "command",
                     "command": "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/subagent-explain.py\"" } ] }
    ]
  }
}
```

`SubagentStop`은 도구 매처를 받지 않으므로 `matcher` 키가 없다.

`hooks/subagent-explain.py`가 하는 일 전부:

1. kill switch 확인 — `DEVBREW_DISABLE_AGENT_TRANSPARENCY=1` 또는
   `DEVBREW_SKIP_HOOKS`에 `agent-transparency:subagent-explain` 포함 → **stdout 없이 exit 0**
2. 고정 JSON 출력 (dual-target — devbrew 규약)

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SubagentStop",
    "additionalContext": "방금 끝난 에이전트에 대해 대화창에 표로 내라 — 누가 / 무엇을 찾았나 / 근거가 어디 있나 / 내 판단이 어떻게 바뀌었나. 결과를 그대로 옮기지 말고 판단에 미치는 영향을 쓸 것."
  },
  "systemMessage": "[agent-transparency] 에이전트 결과 설명 자리"
}
```

**검사하지 않는다.** 트랜스크립트를 읽지도, 조건을 따지지도, 파일을 쓰지도 않는다. stdin은 읽고
버린다(파이프 깨짐 방지). `decision` 키를 절대 내지 않는다([불변식](#3-불변식)).

### 6.3 명령 + skill

| 명령 | 묻는 것 | skill에 넘기는 것 |
|---|---|---|
| `/why [대상]` | **왜 그렇게 했나** — 직전 판단의 근거. 대상을 주면 그 에이전트의 근거 | `mode=why`, `target` |
| `/recap` | **여기까지 무슨 일이 있었나** — 이번 세션의 현황 | `mode=recap` |

둘 다 `skills/explaining-past-work/SKILL.md`를 호출한다. 명령은 진입점일 뿐 절차를 갖지 않는다
(devbrew의 `/interview`·`/qg`와 같은 모양). skill이 절차를 소유하므로 자연어로도 잡힐 여지가 생긴다.

- `cost_class: low` — 스크립트 1회 + 모델 1턴. fan-out 없음.
- skill은 `Bash`(스크립트 호출)와 `Read`만 필요하다.

### 6.4 추출 스크립트

`scripts/extract_transcript.py` — 이 플러그인에서 유일하게 실질적인 코드.

```
python3 extract_transcript.py --mode why|recap [--target <에이전트>] [--max-bytes N]
```

| 단계 | 하는 일 | 방식 |
|---|---|---|
| 1 | 세션 디렉토리 해석 | `CLAUDE_CODE_SESSION_ID` → `~/.claude/projects/*/<sid>*` **글롭**. 디렉토리 이름 규칙을 유도하지 않는다 |
| 2 | 파싱 | 메인 `<sid>.jsonl` + `<sid>/subagents/agent-*.jsonl` (+ `.meta.json`) |
| 3 | 발췌 | `why` = 최종 응답 + 인용된 근거 / `recap` = 시간순 사건 골격 |
| 4 | **마스킹** | 아래 |
| 5 | 상한 적용 | `--max-bytes` 기본 40 KB. 넘으면 잘라내고 **잘랐다고 명시** |

**판단은 스크립트가 하지 않는다.** 선별과 마스킹만 하고, 압축과 서술은 모델이 한다.

#### 단계 1이 글롭인 이유

디렉토리 이름은 작업 경로에서 만들어진다(`/` → `-`, `.` → `-`, `+` → `-`). 이것은 **문서화되지 않은
규칙**이고 워크트리에서 특히 어긋나기 쉽다(`devbrew/.claude/worktrees/...` → `devbrew--claude-...`).
세션 id는 환경변수로 정확히 주어지므로, 이름 규칙을 재현하는 대신 **id로 찾는다**.

#### 단계 4 — 마스킹

패턴 표는 `plugins/quality-gates/scripts/secret-scan.py`의 것을 **가져온다**(AWS 액세스 키 · GitHub
토큰/PAT · Slack 토큰 · Google API 키 · Stripe 키 · PEM 개인키 · JWT · 접속 문자열 안의 자격증명),
여기에 키워드+엔트로피 휴리스틱(`password|token|api_key` 등의 대입 우변, Shannon ≥ 4.0, 길이 ≥ 16)을 더한다.

**참조가 아니라 사본을 둔다.** 이유는 하나다 — 보안 장치가 *다른 플러그인이 설치돼 있지 않아서*
동작을 멈추면 안 된다. 대신 `tests/test_mask_parity.py`가 두 표를 대조해 원본에 패턴이 추가됐는데
사본에 없으면 **red**를 낸다(quality-gates가 없으면 skip).

## 7. 에러 처리 · 강등

| 상황 | 동작 | 원칙 |
|---|---|---|
| kill switch set | 훅이 아무 것도 안 함, exit 0 | kill switch는 보안 컨트롤 |
| 세션 디렉토리 못 찾음 | *"세션 기록을 찾지 못했습니다 (`<시도한 경로>`)"* 출력 | **못 읽은 것은 없는 것이 아니다** |
| jsonl 파싱 실패 | 읽힌 부분만 내고 *"N줄을 읽지 못했습니다"* 명시 | 부분 결과에 부분임을 표시 |
| **마스킹 모듈 로드 실패** | **본문을 내지 않고 메타데이터만** (누가·언제·어느 파일) + 큰 경고 | 비밀은 fail-closed |
| 상한 초과 | 자르고 *"N바이트에서 잘랐습니다"* 명시 | 조용한 절단 금지 |
| 훅 스크립트 예외 | stderr에 남기고 exit 0 | 설명 장치가 작업을 막으면 불변식 위반 |

강등이 사람에게 안 닿으면 그것은 강등이 아니라 통과다. 모든 강등은 출력에 남는다.

## 8. 파일 목록

```
plugins/agent-transparency/
├── .claude-plugin/plugin.json          # name · description · version 0.1.0
├── README.md                           # 맨 앞에 force-for-plugin 경고 · Principles Instantiated · Hooks Installed
├── CHANGELOG.md
├── output-styles/
│   └── agent-transparency.md           # §6.1 전문
├── hooks/
│   ├── hooks.json                      # SubagentStop 1건
│   └── subagent-explain.py             # 상수 출력 + kill switch
├── commands/
│   ├── why.md
│   └── recap.md
├── skills/
│   └── explaining-past-work/
│       └── SKILL.md                    # cost_class: low
├── scripts/
│   └── extract_transcript.py
└── tests/
    ├── test_output_style.py            # AC1–AC4
    ├── test_subagent_hook.py           # AC5–AC8
    ├── test_extract_transcript.py      # AC9, AC12, AC13
    ├── test_masking.py                 # AC10, AC11
    ├── test_mask_parity.py             # 패턴 표 drift 감시
    └── test_plugin_contract.py         # AC14–AC17
```

리포 루트 변경 하나:

- `docs/plugin-authoring.md` — **`output-styles` 언급이 현재 0건**이다. devbrew의 첫 output style
  이므로 컴포넌트 작성 절을 추가한다(frontmatter 필드 · `keep-coding-instructions` 함정 ·
  `force-for-plugin`의 대가 · subagent 미적용).

`CLAUDE.md`는 건드리지 않는다 — 규칙이 output style에 살기 때문이다.

## 9. Acceptance Criteria

| # | 기준 | 검증 |
|---|---|---|
| AC1 | output style frontmatter에 `keep-coding-instructions: true`와 `force-for-plugin: true`가 있다 | 파싱 |
| AC2 | 본문이 `Explanatory`의 4요소를 전부 담는다 — 블록 형식 · 코드 전후 · 미루지 않음 · 코드베이스 특유 | 문구 존재 + mutation |
| AC3 | 본문이 5개 순간 각각에 "담을 것" 목록을 갖고, 형식 예시가 **최소 1개** 있다 | 5개 순간 각각 + 예시 블록 |
| AC4 | 본문과 description에 비유가 없고, 정의 없이 쓰인 프로젝트 고유어가 없다 | 금지 표현 목록 + 사람 리뷰 |
| **AC5** | `## Format` 규칙이 **다섯 순간으로 스코프**돼 있다 (모든 출력에 무조건 적용되지 않는다) | 문구 검사 |
| AC6 | 훅이 kill switch 2종을 존중한다 — set이면 stdout 비고 exit 0 | 실행 |
| AC7 | 훅이 유효한 `hookSpecificOutput.additionalContext` JSON을 낸다 | 실행 + JSON 파싱 |
| AC8 | 훅이 파일시스템에 아무것도 쓰지 않는다 | 실행 전후 트리 비교 |
| AC9 | 훅 출력에 `decision` 키가 어떤 경우에도 없다 | 실행 (불변식) |
| AC10 | 추출이 디렉토리 이름 규칙을 유도하지 않고 세션 id 글롭으로 찾는다 | 픽스처 + 이름 규칙 위반 경로 |
| AC11 | 알려진 비밀 패턴 전량이 마스킹된다 | 패턴별 픽스처 |
| AC12 | 마스킹 불가 시 본문을 내지 않고 메타데이터만 낸다 | import 실패 주입 |
| AC13 | 읽기 실패 시 "없다"가 아니라 "못 읽었다"를 낸다 | 손상 픽스처 |
| AC14 | 발췌에 크기 상한이 있고 잘랐을 때 명시한다 | 큰 픽스처 |
| AC15 | `/why`와 `/recap`이 같은 skill을 호출하고 절차를 복제하지 않는다 | 명령 파일 검사 |
| AC16 | skill이 `cost_class`를 선언한다 | frontmatter |
| AC17 | plugin.json에 name·description·version이 있고 description이 output style과 같은 문구다 | 대조 |
| AC18 | README 맨 앞에 *"끄려면 플러그인 전체를 비활성화해야 한다"* 경고가 있다 + Principles Instantiated · Hooks Installed | 절 존재 |
| **AC19** | **A/B 측정을 통과한다** — 스타일을 켠 세션과 끈 세션에서 같은 작업을 돌려 ① 코드 품질 동등 ② 사소한 작업에 다섯 순간 규칙이 안 돎 ③ 응답 길이가 과도하지 않음 | [§10-6](#10-검증-계획) |

AC19는 **머지 게이트**다. 통과 못 하면 머지하지 않는다.

## 10. 검증 계획

1. **단위** — 위 AC별 테스트. Python `unittest`(리포 관행: `-m unittest`로만 실행).
2. **mutation** — 통과가 정답인 assert는 모양으로 이빨을 판별할 수 없다. AC2·AC3·AC5·AC11은 대상
   바이트를 **표기·값·위치 세 축**으로 흔들어 red가 나는지 확인한다. 내가 지운 바이트를 되돌리는
   mutation은 계측이 안 되므로 쓰지 않는다.
3. **훅 실물** — `SubagentStop` 페이로드 샘플을 stdin으로 넣어 실행. kill switch on/off 양방향.
4. **수동 e2e** — 실제 세션에서 `Agent` 호출 후 설명이 나오는지, `/why`·`/recap`이 도는지.
5. **자기 적용** — 이 플러그인의 output style 본문·README·description을 자기 블록(Vocabulary)으로
   읽어본다. AC4가 이 검사를 부분적으로 기계화한다.
6. **A/B 측정 (AC19, 머지 게이트)** — 시스템 프롬프트를 건드리는 변경이라 주장 대신 측정한다.

   ```bash
   # 끈 상태 기준선
   claude -p "<동일 작업>" > baseline.txt
   # 켠 상태
   claude -p --plugin-dir plugins/agent-transparency "<동일 작업>" > with-style.txt
   ```

   작업 3종을 돌린다: (a) 사소한 작업(오타 수정) — 다섯 순간 규칙이 **안 돌아야** 한다,
   (b) 코드 작성 작업 — 결과 코드가 동등해야 한다, (c) subagent를 부르는 작업 — 결과 설명이
   나와야 한다. 판정은 사람이 하되 세 항목을 명시적으로 기록한다.

## 11. 기각된 대안

| 기각한 것 | 이유 |
|---|---|
| `Stop` 훅으로 종료 설명 강제 | `additionalContext`가 *"대화를 계속시킨다"* — 턴이 안 끝나는 루프. devbrew 금지 패턴(unbounded autonomy) |
| `PreToolUse`로 결정 순간 검사·차단 | 유일하게 확실하지만 사용자 질문 자체를 막는다. [불변식](#3-불변식) 위반 |
| statusline · subagentStatusLine | 출력 토큰 0이 매력적이나 `tasks[]`에 findings 필드가 없어 **내용을 실을 수 없다** |
| 원장 · 상태 파일 | 트랜스크립트가 이미 전문을 보관한다. 남은 일은 저장이 아니라 선별 |
| `project-init` 개명·흡수 | `project-init` 문자열이 리포에 1,055회 / 40+ 파일. 성격도 다르다(초기화 vs 상시) |
| 17개 agent 정의에 반환 규약 추가 | devbrew 안에서만 작동 → K3 위반. 메인이 반환값을 읽어 요약하면 불필요 |
| 프로젝트 고유어 grep 금지 검사 | K1 위반. 그리고 "무엇이 고유어인가"를 정의하는 순간 그 정의가 억제 장치가 된다 |
| 순간별 줄 수 고정 | 가짜 정밀함. 상황마다 틀리고 지켜지지도 않는다. 담을 것만 고정한다 |
| 마스킹을 모델에게 맡김 | 한 번 새면 되돌릴 수 없다. 이 설계의 유일한 결정론 지점 |
| quality-gates 모듈 직접 import | 보안 장치가 남의 플러그인 설치 여부에 달리면 안 된다. 사본 + 대조 테스트 |
| 각 설명 끝에 `상세: /why` 안내 | 매 순간 붙는 안내가 그 자체로 소음이 된다. 명령은 README·명령 목록에서 발견 |
| `force-for-plugin: false` (수동 선택) | 사용자가 기본 적용을 선택. 대신 끄는 경로가 좁아지는 대가를 문서화 |
| output style만 별도 플러그인으로 분리 | 스타일만 끄는 길이 생기지만 plugin.json·README·버전이 2벌이 되고 둘이 따로 논다 |
| 지침을 XML 태그로 구조화 | 일반 프롬프트 가이드는 권하나, output style 공식 예시와 `Explanatory` 둘 다 마크다운 헤더를 쓴다 |

## 12. 미해결

- **OQ-A** — `/recap`의 기본 범위. 세션 전체인지, 마지막 N개 사건인지. 세션이 길면 발췌가 커진다.
- **OQ-B** — 트랜스크립트 형식은 **문서화돼 있지 않다**. 바뀌면 `/why`·`/recap`이 깨진다.
  깨졌을 때 알아채는 경로는 AC13(못 읽었다고 말하기)뿐이고, 사전 감지 장치는 없다.
- **OQ-C** — `force-for-plugin`이 다른 플러그인의 스타일과 충돌할 때 "먼저 로드된 것이 이긴다"는
  규칙에 우리가 개입할 방법이 없다. README 경고 외의 완화책이 없다.
- **OQ-D** — 도입부의 두 문장(*"Balance transparency with task completion"* · *"한 문장 작업은 한
  문장으로"*)이 과잉 발화를 실제로 막는지는 **AC19를 돌려봐야 안다.** 못 막으면 문구를 강화하거나
  순간 수를 줄여야 한다.
- **OQ-E** — `/why`·`/recap`의 발견 가능성. 각 설명 끝의 안내를 없앴으므로 사용자가 명령의 존재를
  README나 명령 목록에서만 알게 된다. 실사용에서 안 쓰이면 안내를 되살릴지 재검토한다.
- **OQ-F** — `Explanatory` 원문이 앞으로 개선되면 우리 사본은 낡는다. **감지 장치가 없다.**
- **OQ-G** — 시스템 프롬프트 끝에 약 500 토큰이 붙는 것이 내장 지침의 주의를 얼마나 가져가는지는
  외부에서 측정할 수 없다. AC19가 간접 신호를 주지만 직접 계측은 아니다.

## 13. Metadata

| 항목 | 값 |
|---|---|
| 플러그인 | `plugins/agent-transparency/` (신규) |
| 버전 | `0.1.0` |
| 브랜치 | `feature/comprehension-debt-plugin` |
| 문제공간 입력 | `docs/superpowers/interview/2026-08-02-comprehension-debt-plugin-interview.md` |
| 의존 | 없음 (quality-gates는 테스트 시 선택적 대조 대상) |
| 신규 훅 | `SubagentStop` 1건 |
| kill switch | `DEVBREW_DISABLE_AGENT_TRANSPARENCY=1` · `DEVBREW_SKIP_HOOKS=agent-transparency:subagent-explain` — **훅에만 적용된다.** output style은 플러그인 비활성화로만 끈다 |
| 리포 루트 변경 | `docs/plugin-authoring.md`에 output style 컴포넌트 절 추가 |
| 머지 게이트 | AC19 (A/B 측정) |
