# seed `@경로` 핸드오프 — framing 게이트를 `/new` · `@경로` 로 · Design

> 전문을 옮기는 것은 사람이 아니라 파일이다.

## Handoff Context

**TL;DR** — framing 게이트(`framing-requests` 의 확정 proceed 게이트)의 핸드오프를
`/interview <seed 전문>` 붙여넣기에서 `/interview @<seed 경로>` 로 바꾸고, 권장 선택지를 「`/new`
후 그 명령」으로 한다. 헤드리스 실측(§A)에서 커맨드 인자 안의 `@경로` 는 풀리지 않았고 대화형은 재지
않았다. 어느 쪽이든 `/interview` 입구(`commands/interview.md` 새 Step 1.5)가 그 파일을 읽어 전문으로 푼다 — 하류는
오늘 붙여넣기 때와 같은 값을 받는다. 공유 게이트 계약(`references/proceed-gate.md`)의 옵션 ①/② 는
「권장/차선 핸드오프」로 일반화하고, 다른 두 채택자(`reviewing-spec`, `conducting-interview`)는
고치지 않는다. spec-distill minor bump.

**Implicit context**
1. `/new` 는 `/clear` 의 alias 이고 문법은 `/clear [name]` 이다 — 같은 줄에 붙인 텍스트는
   세션 이름이 된다(출처: code.claude.com/docs/en/commands.md). 그래서 `/new` 와 `/interview …` 는
   두 번 따로 입력해야 한다.
2. `/compact <지시>` 의 텍스트는 요약 지시로만 쓰이고 다음 프롬프트로 전달되지 않는다(같은 문서) —
   ② 도 `/interview …` 줄을 따로 입력해야 한다.
3. 사용자의 원 요청에는 `reviewing-spec` 게이트 순서 변경(「writing-plans 후 compact」)도 있었으나
   사용자가 2026-09-10 철회했다(§결정 기록 D3). 이 문서의 범위가 아니다.
4. 같은 시각 다른 세션이 잠근 워크트리 `feature/remove-spec-review-hook` 가 있다(커밋 0, 이름으로 보아
   spec-distill 을 건드릴 수 있음). 버전 번호는 머지 직전에 정한다(C5).
5. 작업 전 baseline: spec-distill 테스트 80개 중 2개가 선재 RED —
   `test_no_write_matcher_hooks_repo.sh`(실패 줄 1), `test_hook_output_schema.py`(실패 1).
6. base = `c7b4f580`(origin/main 과 같음). 브랜치 `feature/handoff-gate-reorder`.

### Deferred to plan

| 출처 | 항목 |
|---|---|
| 저자 | 새 테스트의 정확한 블록 추출 경계와 regex 문면(요건은 AC1–AC6 이 정한다). |
| 저자 | 이빨 확인(AC8)에 쓸 구체 변이 목록(축은 AC8 이 정한다). |
| 저자 | V4 픽스처 seed 의 본문, 헤드리스 실행 플래그(`--plugin-dir` · kill switch · 모델), 판정 문구. |
| 저자 | CHANGELOG 문안과 최종 버전 번호. |
| 저자 | 이름 가드 공백 거부(§3)의 테스트 단언 — 이 문서의 AC 에 없다 — 과, 그 가드를 재는 기존 락과의 정합. |
| 02bb058a#r1.1 | 권장 옵션 ①(`/new`)의 성립이 OQ2(`/new` 뒤 cwd 가 워크트리로 유지되는가)에 달려 있는데 이를 관측할 V 단계가 없다(V4 는 헤드리스 `/spec-distill:interview` 만 잰다). framing 의 기본 권장이 「워크트리 만들고 시작」이므로 cwd 가 유지되지 않으면 ①이 흔한 경로에서 매번 부재 문구로 끝난다. plan 에 수동 관측 단계(EnterWorktree 후 `/new` → cwd 확인)를 넣는다. |
| 2e6610eb#r1.1 | 구현 계획에 S1 보존 검증을 추가해야 한다. 현재 실동작 판정은 seed 인식과 본문 일부 활용만 확인하므로, 파일을 읽고도 하류 인자에는 경로를 넘기거나 본문을 일부만 보존하는 실패를 놓칠 수 있다. 생성된 brief §6 S1이 frontmatter를 포함한 픽스처 전문과 일치하는지 확인하는 검증이 필요하다. |

## 목차

- [A. 측정](#a-측정)
- [Context / Why](#context--why)
- [Goals](#goals) · [Non-goals](#non-goals) · [Constraints](#constraints)
- [설계](#설계)
  - [1. framing 게이트](#1-framing-게이트-framing-requestsskillmd-호출-모양-절)
  - [2. 공유 계약](#2-공유-계약-referencesproceed-gatemd)
  - [3. `/interview` 입구 해석](#3-interview-입구-해석-commandsinterviewmd-새-step-15)
  - [4. 문구 동기화](#4-문구-동기화-동작-변화-없음)
- [Acceptance Criteria](#acceptance-criteria) · [Files to Modify](#files-to-modify) · [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives) · [Open Questions](#open-questions)
- [결정 기록](#결정-기록) · [Metadata](#metadata) · [Concrete Next Action](#concrete-next-action)

## A. 측정

2026-09-10, 헤드리스 `claude -p`, haiku, 탐침 플러그인 `argprobe`(command `echoargs` 가
`ARGS=[$ARGUMENTS]` 를 출력하고 파일의 canary 문자열이 컨텍스트에 있는지 답한다). 탐침 seed 파일은
`type: interview-seed` frontmatter 와 canary `CANARY-7Q2` 를 담는다.

| # | 입력 | 결과 | 역할 |
|---|---|---|---|
| A1 | `/argprobe:echoargs @<seed 경로>` | `ARGS=[@<seed 경로>]`, canary **없음** | 측정 |
| A2 | 평문 `@<seed 경로> …` (슬래시 커맨드 아님) | canary **있음** — Read 결과 system-reminder 로 첨부 | 양성 대조: `-p` 에서도 `@` 확장 자체는 동작 |
| A3 | `/argprobe:echoargs hello` | `ARGS=[hello]`, canary 없음 | 음성 대조 |

**결론** — 헤드리스에서 커맨드 인자의 `@경로` 는 리터럴 그대로 `$ARGUMENTS` 에 들어가고 파일 내용은
첨부되지 않는다. **재지 않은 것** — 대화형 터미널 입력, skill 형식 호출. 설계는 두 경우 모두에서
동작하도록 인자의 출처를 Read 결과 하나로 고정한다(§설계 3).

## Context / Why

사용자 원문(2026-09-10, verbatim):

> framing 이후 '/comapct' 명령 선택지로 나오는데 이거를 interview 이후로 잡는 경우 '@'을 문서 경로 앞에 붙이게 해서 프롬프트
>   전문으로서 들어갈 수 있게 하자 다른건 불필요하고 그리고 가장 추천 선택지는 '/new' 이후 명령어 붙이는거야

오늘 framing 게이트는 ① `/compact` 후 `/interview <seed 전문>`(권장) · ② 바로 `/interview <seed 전문>` ·
③ 수정 · ④ 멈춤이다. 전문 붙여넣기는 사람이 seed 파일(frontmatter 포함 수십 줄)을 복사해 인자로
옮기는 일이고, 그 모양이 필요했던 이유는 소비자 계약이 전부 `$ARGUMENTS` 에 키잉돼 있어서다 —
인자가 비면 S1 미보존 · seed 규약 미발동 · 틀린 조언이 함께 조용히 실패한다
(`framing-requests/SKILL.md` 「호출 모양」 절).

`@경로` 로 바꾸면 옮기는 일은 사라지지만 §A 의 헤드리스 실측에서 `@` 는 풀리지 않았다(대화형은
재지 않았다). 소비자가 풀지 않으면
`$ARGUMENTS` 가 경로 문자열이 되어 위 세 실패가 그대로 재현된다: `type: interview-seed` 표지가 없어
seed 로 인식되지 않고, brief §6 S1 에 경로 문자열만 남고, `/interview` 가 방금 Phase 0 을 거친
사용자에게 「`/request-framing` 을 먼저 거치면…」 조언을 낸다.

권장을 `/new` 로 두는 이유: framing skill 은 이미 자신을 「다음 세션의 첫 턴」으로 넘기는 설계이고,
seed 는 framing 대화를 대신하려고 존재한다. `/compact` 는 그 대화의 요약을 남긴다.

## Goals

- **G1** — framing 게이트 옵션이 ① `/new` → `/interview @<seed 경로>`(권장) · ② `/compact` →
  `/interview @<seed 경로>` · ③ 수정 · ④ 멈춤이다. ①/② 는 명령을 보여주고 턴을 끝낸다.
- **G2** — `/interview` 가 `@경로` 한 토큰 인자를 그 파일 전문으로 풀어, 하류(trivia 검사 · seed 인식 ·
  `conducting-interview`)가 전문 붙여넣기 때와 같은 값을 받는다.
- **G3** — 공유 계약의 Step B 표 · 가드 1 · 가드 2 · Step A 가 「권장/차선 핸드오프」로 일반화되고, 다른
  두 채택자는 **표 구조**에서 그대로 계약에 맞는다. 두 채택자의 가드 1 문면(「①/② 선택 후 … 다음 단계
  진입을 skip 하면 polite stop」 — `reviewing-spec/SKILL.md` 280행 · `finishing.md` 380행)이 자기 ① 의
  정지 요건과 어긋나는 것은 이번 변경 전부터 있던 불일치라 범위 밖이다(후속 과제, D3.6).
- **G4** — 옛 호출 모양 서술이 플러그인 문서에서 사라지고 새 모양으로 동기화된다.

## Non-goals

- **NG1** — `reviewing-spec` 승인 게이트의 순서 변경(철회, D3).
- **NG2** — interview→brainstorming 게이트(`conducting-interview` 종료 Step B).
- **NG3** — `conducting-interview` 를 슬래시로 직접 호출할 때의 `@경로` 해석. framing 은 `/interview` 로만 안내한다.
- **NG4** — 전문 붙여넣기 차단. 옛 방식은 계속 동작한다(호환).
- **NG5** — `@경로` 해석을 스크립트로 결정화.

## Constraints

- **C1** — `AskUserQuestion` 은 한 질문에 옵션 최대 4개다. 그래서 「바로 진행」을 뺐다(D2).
- **C2** — `/new` 와 `/interview …` 는 두 번 따로 입력하게 안내한다(Implicit 1).
- **C3** — seed 를 알아보는 유일한 표지는 frontmatter `type: interview-seed` 다(`interview.md` Step 2.5,
  `seed-input.md`). 풀어낸 값은 frontmatter 를 포함한 파일 전문이어야 한다.
- **C4** — 게이트 채택자 테스트의 코퍼스 규칙: 앵커는 각 skill 이 소유한 표면에 살고, 정본
  `proceed-gate.md` 는 presence 코퍼스에 넣지 않는다(`proceed-gate.md` 「앵커는 각 skill 에 있고」 절).
  새 테스트도 이 규칙을 따른다 — 정본에 대한 단언은 정본 **자체**를 대상으로 하는 별도 단언이다.
- **C5** — 버전 번호와 CHANGELOG 날짜는 머지 직전에 정한다(Implicit 4).
- **C6** — `@` 뒤 경로는 `$SEED` 의 상대경로 값 그대로다(R5).

## 설계

### 1. framing 게이트 (`framing-requests/SKILL.md` 「호출 모양」 절)

| # | 이 skill 의 옵션 |
|---|---|
| ① | `/new` 후 `/interview @<seed 경로>` (권장, 커밋 후) — 두 줄 명령을 노출하고 **턴 종료** |
| ② | `/compact` 후 `/interview @<seed 경로>` (커밋 후) — 두 줄 명령을 노출하고 **턴 종료** |
| ③ | 수정 필요 — 압축을 다시 깎고 이 게이트로 돌아옵니다 |
| ④ | 멈춤 — seed 와 audit 을 남기고 종료 |

노출 모양(① 의 예):

```
/new
/interview @docs/superpowers/interview/2026-09-10-<topic>-interview.md
```

- `<seed 경로>` 는 `$SEED` 실제 값으로 치환한 뒤 노출한다. 치환하지 않은 자리표가 나가면 사용자가
  깨진 명령을 실행하고, 그것을 잡는 자리가 없다.
- 「`/new` 뒤 같은 줄에 붙이면 그 텍스트가 세션 이름이 된다 — 두 번 따로 입력」 안내 한 줄.
- 정본 문장 「다음 세션의 첫 턴은 `/interview <seed 파일 전문>` 한 줄」 → 「`/interview @<seed 경로>`
  한 줄」. 「전문을 인자로 넣는 이유」 단락은 「커맨드 인자의 `@경로` 는 헤드리스 실측(§A)에서 풀리지
  않았고 대화형은 재지 않았다 — 어느 쪽이든 `/interview` 가 푼다. 풀린 값에 소비자 계약이 키잉돼 있다」로
  고친다. 측정 범위를 문장에 함께 적는 것은, 대화형에서 파일이 첨부되더라도 Step 1.5 가 불필요해지지 않기
  때문이다 — 하류가 읽는 것은 첨부가 아니라 `$ARGUMENTS` 치환 값이다(§3). 「frontmatter 를
  떼지 않는 이유」 단락은 유지한다(파일 자체가 frontmatter 를 가진다).
- 핸드오프 직전 커밋(①/② 에서만)과 워크트리 절대경로 안내는 유지한다 — 절대경로는 다른 터미널에서
  새로 열 경우를 위한 것이다.
- 「두 가드」의 cross-compact 가드 → 「①/② 어느 쪽이든 명령을 노출하면 거기서 턴 종료(STOP). 같은
  턴에서 인터뷰를 시작하지 않는다. 다음 단계는 사용자가 그 명령을 실제로 친 다음 턴의 사용자
  트리거로만 일어난다」.
- 「두 가드」의 polite stop 가드 → 「①/② 는 둘 다 핸드오프다. 이 옵션에서 polite stop 은 두 줄 명령을
  노출하지 않고 설명만 하고 끝내는 것이다 — 명령을 노출하고 턴을 끝내는 것이 이 옵션의 완료다」. 오늘
  문면(「승인 옵션인데 … 다음 단계로 가지 않는 것은 polite stop」)은 새 정지 가드와 충돌하므로 그대로 두지 않는다.

### 2. 공유 계약 (`references/proceed-gate.md`)

- **Step B 표**

  | # | 뜻 |
  |---|---|
  | ① | 권장 핸드오프 — skill 이 정한 명령을 노출하고 **턴 종료** |
  | ② | 차선 핸드오프 — skill 이 정한다: 명령을 노출하고 **턴 종료**, 또는 바로 진행 |
  | ③ | 수정 필요 — 후속 질문으로 분기 |
  | ④ | 멈춤 — 상태 보존하고 종료 |

- **「각 skill 이 채우는 것」** 목록에 「①/② 의 핸드오프 종류(`/compact` · `/new` · 바로 진행)와
  노출할 명령」을 더한다.
- **가드 2** — 「명령을 노출하는 옵션을 고르면 노출 직후 턴 종료. 다음 단계 진입은 사용자가 그 명령을
  실행한 다음 턴의 사용자 트리거로만. 바로 진행 옵션은 이 정지 요건의 명시적 예외」. 제목의
  「cross-compact」는 유지한다(기존 인용 AC19 가 가리키는 이름).
- **가드 1** — 「approve(①/②) 를 고른 뒤 그 옵션의 완료 동작을 skip 하고 narrate 만 하는 것이 polite
  stop 이다. 완료 동작은 핸드오프 종류가 정한다: 명령을 노출하는 옵션은 명령 노출(그 뒤 턴 종료), 바로
  진행 옵션은 다음 단계 진입」. 오늘 문면의 「다음 단계 진입을 skip」은 바로 진행만 가정한 것이다.
- **Step A** — 「`/compact` 도 노출하지 않는다」 → 「핸드오프 명령도 노출하지 않는다」.
- **「검증」 절의 리뷰 레이어** — 「옵션 ① 서술 블록 안에서」 → 「명령을 노출하는 각 옵션의 서술 블록
  안에서」. 「앵커는 각 skill 에 있고」 절의 framing 앵커 서술에 ② 행을 더한다.
- `reviewing-spec`(① `/compact` · ② 바로 진행)과 `conducting-interview`(같음)는 새 표에 그대로 맞는다 — 무수정.

### 3. `/interview` 입구 해석 (`commands/interview.md` 새 Step 1.5)

Step 1(kill switch) 다음, Step 2(trivia) 앞.

- **발동** — 앞뒤 공백을 걷은 `$ARGUMENTS` 가 `@` 로 시작하는 공백 없는 한 토큰일 때만. 문장 중간에
  `@` 가 섞인 입력은 건드리지 않는다.
- **동작** — `@` 를 뗀 경로를 세션 작업 디렉토리 기준으로 풀어(Read 도구에는 절대경로로 넘긴다) 읽는다.
  인자로 쓰는 것은 Read 출력의 줄번호·탭 접두를 뗀 파일 원문이다. 이후 이 command 의 모든 단계와 `Skill conducting-interview`
  호출 인자는 그 **파일 전문(frontmatter 포함)** 이다. 대화형에서 같은 파일이 따로 첨부되더라도 인자의
  출처는 이 Read 결과다.
- **부재·읽기 실패** — Read 가 실패하면(파일 부재 · 경로가 디렉토리 · 권한 등) 관측한 실패 사유를
  담아 아래 문구를 내고 멈춘다. 인터뷰를 시작하지 않는다.

  > `[spec-distill] '@<경로>' 를 읽지 못했다(<관측한 사유>) — seed 를 만든 워크트리 디렉토리에서 세션을 열었는지 확인하라. 인터뷰를 시작하지 않는다.`

- **「풀린 입력」** — Step 1.5 의 결과에 이 이름을 붙인다. `@` 로 발동하지 않았으면 「풀린 입력」은
  `$ARGUMENTS` 그대로다. command 본문의 `$ARGUMENTS` 는 Claude Code 가 입력 문자열로 텍스트 치환하므로
  (§A1), 오늘 `$ARGUMENTS` 를 문자 그대로 참조하는 자리 — Step 2 의 trivia 대조, Step 2.5 의 seed 판별,
  **Step 3 펜스 `Skill conducting-interview $ARGUMENTS`**, Arguments 절 — 는 `@` 입력에서 경로 문자열로
  렌더된다. 그래서 Step 2 · 2.5 · 3 은 `$ARGUMENTS` 대신 「풀린 입력」을 가리키게 고친다. Step 3 은
  「`Skill conducting-interview` 의 인자 = 풀린 입력」이 된다 — 핸드오프를 실제로 수행하는 줄이 이것이다.
- **공백** — seed 경로가 한 토큰이어야 Step 1.5 가 발동한다. 오늘 framing 의 이름 가드(`framing-requests`
  「## 상태」의 `TOPIC`·`IV_NAME` `case` 패턴)는 `/`·`<`·`>` 만 거르고 공백은 거르지 않으며, kebab 은
  자리표 지시일 뿐 강제되지 않는다. 이 변경은 두 가드에 공백 거부 패턴을 더해, framing 이 만드는 seed
  경로가 항상 한 토큰이게 한다. 사람이 공백 든 경로를 손으로 넘기면 Step 1.5 는 발동하지 않고 오늘의
  거친 요청 경로로 간다(NG4).

### 4. 문구 동기화 (동작 변화 없음)

- `interview.md` Step 2.5 · Arguments 절: 「`/interview <seed 파일 전문>` 으로 부른다」 → 「`/interview @<seed
  경로>` 로 부르고 Step 1.5 가 전문으로 푼다」.
- `conducting-interview/references/seed-input.md` 3–7행: 「전문으로 이 command 의 인자에 붙여넣게 하고」 →
  「`/interview @<seed 경로>` 를 치게 하고, `/interview` 가 파일 전문으로 풀어 이 skill 에 넘긴다」.
- `conducting-interview/references/finishing.md` 43행 S1 문장: 「그 `$ARGUMENTS` 가 `interview-seed` 파일
  전문이고」 → 「`/interview` 가 `@경로` 를 풀어 넘겼든 사용자가 전문을 붙여넣었든(NG4) `interview-seed`
  파일 전문이고」. 그 밖의 줄은 손대지 않는다.
- 옛 핸드오프를 풀어 쓴 문장(「붙여넣는」 류). 꺾쇠 리터럴이 아니라서 AC6 의 부재 락이 보지 못하는
  자리들이며, 아래 목록이 이 동기화의 완결성 근거다:
  - `framing-requests/SKILL.md` — frontmatter description(4–7행, 모델 컨텍스트에 로드됨) · 13–14행 ·
    127행 흐름 서술 · 203–205행 · 567–569행 · 595–596행 「`/compact` 노출(①) 또는 `/interview` 진입(②)」
    (새 ② 에서 틀린 문장이 된다 → 「명령 노출(①/②) 바로 앞」).
  - `commands/request-framing.md` — frontmatter description(2행) · 10–11행 · 38–40행 「다음 단계」.
  - `templates/interview-seed-audit-template.md` — 11행 「다음 세션의 첫 턴에 붙여넣는 것은 payload(seed)
    파일 전문이고」. 모든 seed audit 이 이 템플릿으로 만들어지므로 새 audit 마다 복제된다.
  - `README.md` — 32–34행 도식(33행 「다음 세션 첫 턴에 붙여넣는 메시지」 포함). 71행 v0.41.0 이력 단락은
    그 버전이 한 일을 적은 기록이라 **유지한다**.
  - 이 목록은 개념어(「붙여넣」 · 「전문으로」 · 「인자로 넣」 · 「seed 전문」) 전수 grep 으로 도출했다.
    제외와 사유:
    - CHANGELOG · `tests/` — 이력과 락은 동기화 대상이 아니다.
    - `finishing.md:352` — brainstorming 쪽 `/compact` 명령(NG2).
    - `check_brief.py:720` — 다른 뜻의 「전문」.
    - `framing-requests/SKILL.md:463`(냉독 `cat` 이 seed 전문을 출력한다는 서술) · `conducting-interview/SKILL.md:228` ·
      `agents/coverage-mapper.md:51`(「seed 전문(S1)」 — 하류가 받는 값의 이름) — 새 방식에서도 참이다.
- 새 서술의 요지: seed 는 「다음 세션 첫 턴에 붙여넣는 메시지」가 아니라 「다음 세션 첫 턴의
  `/interview @<seed 경로>` 가 가리키는 파일」이다.

## Acceptance Criteria

- **AC1** — framing 「호출 모양」 절 옵션 표: ① 행에 `/new` · `/interview @` · 권장 · 턴 종료, ② 행에
  `/compact` · `/interview @` · 턴 종료가 있고, 「바로」 진행 행이 없다.
- **AC2** — 같은 절에 `<seed 경로>` 를 실제 값으로 치환하라는 지시와, `/new` 뒤 같은 줄에 붙이지 말라는 안내가 있다.
- **AC3** — framing 「두 가드」의 정지 가드가 ①/② 모두를 대상으로 턴 종료 · 같은 턴 인터뷰 금지 ·
  다음 턴 사용자 트리거 셋을 함께 적는다.
- **AC4** — `proceed-gate.md` Step B 표 ① 행이 `/compact` 를 못박지 않고 핸드오프 종류를 skill 에 위임하며,
  가드 2 가 「명령 노출 → 턴 종료 / 바로 진행 → 예외」를, Step A 가 「핸드오프 명령도 노출하지 않는다」를 적는다.
- **AC5** — `interview.md` 에 Step 1.5 가 Step 2 보다 앞에 있고, 발동 조건(한 토큰 `@`) · 동작(Read →
  전문을 인자로) · 부재 문구 · 「인터뷰를 시작하지 않는다」가 그 블록 안에 있다.
- **AC6** — 옛 호출 모양(`<seed 전문>` · `<seed 파일 전문>`)이 CHANGELOG 를 뺀 `plugins/spec-distill/`
  문서에서 0건이고, 짝으로 새 모양 `/interview @` 가 `framing-requests/SKILL.md` ·
  `commands/request-framing.md` · `commands/interview.md` · `README.md` 에 각각 있다.
- **AC7** — `reviewing-spec/SKILL.md` 는 main 대비 diff 0 이고, `finishing.md` 의 변경은 S1 규칙 단락 안에만 있다.
- **AC8** — 새 테스트 `test_seed_at_path_handoff.sh` 가 GREEN 이고, 단언 종류마다 맞는 변이에서 RED 가
  된다: 존재 단언은 대상 문구의 삭제 · 치환 · 순서 뒤집기, 부재 단언(AC1 의 바로 진행 행 없음 · AC6 의
  옛 모양 0건)은 옛 문구·행의 재삽입. 부재 단언마다 코퍼스를 실제로 읽었다는 양성 짝이 함께 있다.
- **AC9** — 기존 spec-distill 테스트 80개: baseline 대비 새 RED 0, 선재 RED 2개의 실패 줄 수 불변.
- **AC10** — 실동작(V4): 실제 플러그인에 `/spec-distill:interview @<픽스처 seed>` 를 넣으면 (a) 「`/request-framing`
  을 먼저」 조언이 나오지 않고, (b) 첫 라운드 출력이 픽스처 본문의 고유 문장을 반영한다.
  `/spec-distill:interview @<없는 경로>` 는 (c) 부재 문구를 내고 인터뷰 질문을 내지 않는다.
- **AC11** — `plugin.json` version 이 minor bump 되고 CHANGELOG 에 그 엔트리가 있다.

## Files to Modify

```
plugins/spec-distill/skills/framing-requests/SKILL.md          — 옵션 표 · 호출 모양 정본 · 두 가드 · 이름 가드 공백 거부 · 풀어 쓴 문장(§4)
plugins/spec-distill/references/proceed-gate.md                 — Step A · Step B 표 · 채우는 것 · 가드 2 · 검증 절
plugins/spec-distill/commands/interview.md                      — Step 1.5 신설 · Step 2 · 2.5 · 3 을 「풀린 입력」으로 · Arguments
plugins/spec-distill/commands/request-framing.md                — description · 10–11행 · 다음 단계 문구
plugins/spec-distill/skills/conducting-interview/references/seed-input.md — 도착 경로 문구
plugins/spec-distill/skills/conducting-interview/references/finishing.md  — S1 문장 한 곳
plugins/spec-distill/templates/interview-seed-audit-template.md  — 11행 핸드오프 서술
plugins/spec-distill/README.md                                  — 32–34행 도식
plugins/spec-distill/.claude-plugin/plugin.json                 — minor bump
plugins/spec-distill/CHANGELOG.md                               — 엔트리
plugins/spec-distill/tests/test_seed_at_path_handoff.sh         — 신설: AC1–AC6 단언
```

## Verification Plan

- **V1** — `bash plugins/spec-distill/tests/test_seed_at_path_handoff.sh` GREEN (AC1–AC6).
- **V2** — 이빨 확인: AC8 의 축대로 존재 단언은 삭제 · 치환 · 순서 뒤집기, 부재 단언은 재삽입으로 변이해
  RED 를 확인하고 되돌린다.
  변이 전에 커밋해 둔다(복원 기준이 HEAD 가 되도록). 양성 대조 없이 RED 를 증거로 읽지 않는다 (AC8).
- **V3** — 전체 스위트를 baseline 러너로 다시 돌려 파일별 rc 와 실패 줄 수를 baseline 과 비교한다 (AC9).
  `test_proceed_gate_adopters.sh` · `test_request_framing_command.sh` 가 GREEN 을 유지하는지 따로 본다.
- **V4** — 실동작: 헤드리스로 `--plugin-dir plugins/spec-distill` 을 준 세션에 `/spec-distill:interview @<픽스처>`
  와 `@<없는 경로>` 를 각각 넣고 출력을 AC10 (a)(b)(c) 로 판정한다. 픽스처는 `type: interview-seed`
  frontmatter 와 고유 문장을 가진 임시 파일이다. 모델 호출이 여러 번 든다.
- **V5** — `git diff main -- plugins/spec-distill/skills/reviewing-spec/` 가 비고, `finishing.md` diff 가 S1
  단락 안에 있다 (AC7).

## Rejected Alternatives

- **R1 — framing 을 계약에서 빼기**: 정지 가드와 polite stop 금지를 재는 채택자 테스트가 framing 에 걸리지
  않게 되어 보호를 잃는다.
- **R2 — 계약에 framing 전용 예외 조항**: 정본이 특정 skill 을 예외로 들고 있게 되고, 다음 변형마다 예외가 는다(D4).
- **R3 — `/new /interview @…` 한 줄**: `/new` 뒤 텍스트는 세션 이름이 된다(Implicit 1).
- **R4 — 「바로 진행」 유지, `/compact` 제거**: 사용자가 `/compact` 선택지를 명시했고, 바로 진행은 seed 가
  대신하려던 framing 대화를 그대로 안고 간다(D2).
- **R5 — 절대경로**: 워크트리 밖에서 연 세션에서도 조용히 읽혀, 틀린 디렉토리에서 인터뷰가 시작된다.
  상대경로면 그 디렉토리에 seed 파일이 **없을 때** Step 1.5 부재 문구가 그 상황을 잡는다. 다른 체크아웃에
  같은 이름의 seed 가 있으면 가르지 못한다 — seed 이름에 날짜·topic 이 박히고 그 워크트리 브랜치에만
  커밋되므로 드문 경우로 보고 수용한다.
- **R6 — 파일이 없으면 거친 요청으로 받기**: 경로 한 줄짜리 인터뷰가 조용히 시작된다.
- **R7 — `conducting-interview` 에서 해석**: `$ARGUMENTS` 의 의미가 command 와 skill 두 곳에서 갈린다.
  입구 한 곳이면 하류 계약이 오늘과 같다.
- **R8 — Claude Code 의 `@` 확장에 의존**: §A1 에서 헤드리스로 풀리지 않았다.
- **R9 — 스크립트 resolver**: 파일 하나 읽는 일에 결정론 장치를 더하는 무게. 읽기 실패는 §3 의 정지
  문구로 드러나고, 옮겨 적기 손실은 스크립트로도 사라지지 않는다 — 인자는 결국 모델이 `Skill` 호출에 싣는다.
- **R10 — Bash `cat` 으로 원문 읽기**(framing `### 냉독` 의 선례): 두 방식 모두 모델이 읽은 텍스트를
  `Skill conducting-interview` 호출 인자로 옮겨 적는 단계가 남고, 차이는 Read 출력의 줄번호 접두 하나다.
  그 접두 제거는 §3 동작 절이 명시하므로 Read 를 유지한다.

## Open Questions

- **OQ1** — 대화형 입력에서 커맨드 인자의 `@경로` 가 첨부되는가. 설계는 어느 쪽이든 동작하므로 결정을
  막지 않는다. V4 는 헤드리스만 잰다.
- **OQ2** — `/new` 뒤 작업 디렉토리가 워크트리로 유지되는가. 미측정. 유지되지 않으면 Step 1.5 부재
  문구가 잡고, 게이트의 워크트리 절대경로 안내가 복구 경로다.

## 결정 기록

| # | 날짜 | 결정 | 출처 |
|---|---|---|---|
| D1 | 2026-09-10 | 핸드오프 명령에 `@경로`, 그 밖의 것은 불필요, 권장 = `/new` 후 명령 | 사용자 원문(§Context) |
| D2 | 2026-09-10 | 옵션 = ① `/new` · ② `/compact` · ③ 수정 · ④ 멈춤 (바로 진행 제거) | 사용자 선택 |
| D3 | 2026-09-10 | `reviewing-spec` 순서 변경 요청 철회 — 「이 문구는 잊자 여기서 상관은안할게」 | 사용자 원문 |
| D4 | 2026-09-10 | 계약은 일반화(①/② = 권장/차선 핸드오프) | 사용자 선택 |
| D5 | 2026-09-10 | 실동작 측정(V4) 포함 | 사용자 선택 |
| D6 | 2026-09-10 | 해석 위치 = `/interview` 입구 · 부재 시 멈춤 · 상대경로 · S1 = 풀어낸 전문 · 두 줄 입력 | 모델 결정, 사용자에게 공시 후 이의 없음 |

### 리뷰 결정
- D1.1 · r1 · adopt · 0b618227#r1.1 · "채택 (Recommended)" — AC8 의 변이 축(삭제 · 치환 · 순서 뒤집기)은 부재 단언(AC1 「바로 진행 행이 없다」, AC6 옛 모양 0건)에 공허하다 — 없어야 할 문구는 지울 대상이 없다. 부재 단언의 이빨은 「추가」 축(옛 모양·바로 행 재삽입)과 코퍼스를 실제로 읽었다는 양성 짝으로만 확인된다. AC8 을 「존재 단언은 삭제·치환·순서, 부재 단언은 삽입 변이 + 양성 짝」으로 바꿀지 사용자가 정한다.
- D2.2 · r2 · adopt · 1dfa0ba5#r2.1 · "V2 (Verification Plan)" — finding 없이 바뀜: Verification Plan (modified)
- D2.3 · r2 · adopt · 6c8b9494#r2.1 · "Files to Modify" — finding 없이 바뀜: Files to Modify (modified)
- D2.4 · r2 · adopt · 9cb89df0#r2.1 · "목차" — finding 없이 바뀜: 목차 (added)
- D2.5 · r2 · adopt · b0ccc2f3#r2.1 · "### 리뷰 결정" — finding 없이 바뀜: 리뷰 결정 (added)
- D3.6 · r3 · adopt · 237272b4#r3.1 · "(a) 범위 밖 명시 (Recommended)" — G3·§2 는 reviewing-spec·conducting-interview 가 일반화된 계약에 「무수정」으로 맞는다 하고 AC7 은 reviewing-spec 을 diff 0 으로 잠그지만, 설계가 framing(§1)과 정본 가드 1(§2)에서 「새 정지 가드와 충돌」한다며 고치는 바로 그 문면(①/② 선택 후 다음 단계 진입·호출을 skip 하면 polite stop)이 두 채택자 자기 표면에 그대로 있다 — 개정 뒤 정본 가드 1 은 「완료 동작은 핸드오프 종류가 정한다」로 바뀌므로 두 채택자는 옛 문면을 든 채 남는다. 선택: (a) G3 을 「표 구조는 맞고 가드 1 문면의 선재 불일치는 범위 밖」으로 좁혀 명시(AC7 유지), (b) 두 채택자의 가드 1 한 줄도 같이 고침(AC7 을 풀어야 하며 D3 이 철회한 것은 순서 변경이지 이 문면이 아님). 영향: 어느 쪽도 고르지 않으면 정본과 채택자 문면이 갈리고, 그 차이를 잡는 락은 이 편집 뒤에 없다(test_proceed_gate_adopters.sh 는 'polite stop' 리터럴 존재만 잰다).
- D3.7 · r3 · adopt · 6c8b9494#r3.1 · "Files to Modify 템플릿 줄" — finding 없이 바뀜: Files to Modify (modified)
- D3.8 · r3 · adopt · b0ccc2f3#r3.1 · "### 리뷰 결정" — finding 없이 바뀜: 리뷰 결정 (modified)

## Metadata

- 작성: 2026-09-10 · base `c7b4f580` · 브랜치 `feature/handoff-gate-reorder`
- 대상 플러그인: spec-distill (현재 1.0.0)
- 선행 인터뷰 brief: 없음(brainstorming 직행)

## Concrete Next Action

다음 단계: `superpowers:writing-plans`.
- Spec 경로: `docs/superpowers/specs/2026-09-10-seed-at-path-handoff-design.md`
- Plan 산출물: `docs/superpowers/plans/2026-09-10-seed-at-path-handoff.md`
- 명령: `Skill superpowers:writing-plans docs/superpowers/specs/2026-09-10-seed-at-path-handoff-design.md`
