---
description: 강한 문제공간 stage — 메타프롬프팅·웹리서치·steelman으로 방향을 끌어내 brainstorming용 interview brief를 생성. devbrew Law 1 instantiation.
argument-hint: "[rough request | @<seed 경로>]"
---

# /interview

<!-- plain-language:begin -->
## 사람에게 쓰는 글
이 절은 사용자에게 보이는 글(답변·보고·질문·선택지·경고·PR 본문·커밋)에만 적용한다. 지시문·subagent 프롬프트·state 파일에는 적용하지 않는다. 아래 절차가 출력 형식·원문 보존·분량을 따로 정한 자리에서는 그 절차를 따른다.
- 처음 보는 사람이 한 번에 이해하게 쓴다. 번호·해시·필드 이름·내부 용어는 가리키는 내용을 문장으로 먼저 쓰고 괄호 안에만 둔다. 지어낸 말은 쓰지 않거나 처음 쓸 때 풀어 쓴다.
- 순서: 첫 줄에 지금 상태(무엇을 했고 어디까지 왔나) 한 문장, 가운데에 이유·근거, 맨 끝에 사용자가 할 일 하나. 할 일이 없으면 없다고 쓴다.
- 질문 하나에 결정 하나. 선택지 이름은 짧은 쉬운 말로, 설명에는 고르면 무엇이 달라지는지만 쓴다. 본문에 없던 주제를 선택지에서 꺼내지 않는다. 추천은 「(권장)」으로 표시한다.
- 제목과 목록으로 나누되 표의 칸은 짧게 쓴다. 굵은 글씨는 꼭 필요한 곳에만 쓴다.
- 사용자가 알 필요 없는 글은 쓰지 않는다: 도구 호출 사이의 진행 설명, 전부 정상인 항목의 나열. 확인해서 남은 것도 경고도 없으면 「이상 없음」 한 줄로 쓴다. 확인하지 못한 것·빠진 검사·셀 수 없는 것은 따로 한 줄씩 쓴다 — 없는 것과 확인 못 한 것은 다르다.
- 판정·개수·공시 줄은 스크립트가 낸 쉬운 첫 줄을 그대로 쓰고, 자기 말로 다시 풀거나 덧붙이지 않는다. 스크립트·subagent 가 낸 원문은 고치지 않는다. 스크립트가 풀어 두지 않은 오류에만 쉬운 설명을 앞에 붙이되 통과·실패는 말하지 않는다.
- 사용자와 대화하는 언어로 쓴다. 코드·명령·고유명사·자연스러운 대응어가 없는 기술어는 영어 그대로 둔다. 커밋·PR은 그 레포의 규칙을 따르고, 없으면 대화 언어로 쓴다.
예) 전: `[미적용 fix] 3720b2b7#r1.1` → 후: 리뷰가 고치라고 한 곳 하나가 아직 안 고쳐졌다(3720b2b7#r1.1).
예) 전: (codex 정상 · 재비판 정상 · 저자 편집 없음 · ask_open 0건) → 후: 이상 없음.
<!-- plain-language:end -->

당신은 spec-distill 플러그인의 entry point입니다. `/interview`는 superpowers brainstorming
**앞단의 강한 문제공간 stage**로, 사용자에게서 방향을 끌어내고(메타프롬프팅), 외부 사례를
웹으로 조사하고, 약한 방향을 steelman으로 깨뜨려 **interview brief**(meta-prompt)를 산출합니다.
사용자가 `/interview`를 호출하면 다음 순서로 진행하십시오.

## Step 1: kill switch 존중

다음 환경변수가 set이면 즉시 종료 (no-op):

- `DEVBREW_SPEC_DISTILL_DISABLE=1` — 모든 spec-distill 동작 abort.

(`DEVBREW_SKIP_HOOKS` 는 hook 영역으로, command 자체에는 영향 없음.)

## Step 1.5: `@경로` 인자 풀기

앞뒤 공백을 걷은 `$ARGUMENTS` 가 `@` 로 시작하는 **공백 없는 한 토큰**일 때만 이 단계가 발동한다.
문장 중간에 `@` 가 섞인 입력은 건드리지 않는다.

발동하면 `@` 를 뗀 경로를 세션 작업 디렉토리 기준으로 풀어 **절대경로로** Read 도구에 넘긴다. Read 출력의
줄번호·탭 접두를 뗀 **파일 원문 전체(frontmatter 포함)** 가 「풀린 입력」이다. 대화형에서 같은 파일이 따로
첨부되더라도 「풀린 입력」의 출처는 이 Read 결과다.

Read 가 실패하면(파일 부재 · 경로가 디렉토리 · 권한 등) 관측한 실패 사유를 담아 아래 문구를 내고 멈춘다. **인터뷰를 시작하지 않는다.**

> `[spec-distill] '@<경로>' 를 읽지 못했다(<관측한 사유>) — seed 를 만든 워크트리 디렉토리에서 세션을 열었는지 확인하라. 인터뷰를 시작하지 않는다.`

**seed 면 원문 기록의 경로를 한 줄로 낸다.** 「풀린 입력」의 frontmatter 에 `type: interview-seed` 가 있으면,
읽은 파일의 절대경로에서 audit 경로를 도출한다 — 같은 디렉토리에서 파일명 끝의 `.md` 를 `.audit.md` 로 바꾼
파일이다. seed frontmatter 의 `audit_file:` 은 따라가지 않는다. 그 파일을
Read 로 확인하고, 인터뷰에 들어가기 전에 아래 한 줄을 그대로 낸다:

> `[spec-distill] seed 원문 대조: seed=<seed 절대경로> · audit=<audit 절대경로>`

읽지 못하면 `audit=없음(<관측한 사유>)` 로 낸다. 이 줄은 「풀린 입력」에 넣지 않는다 — 「풀린 입력」은 seed 전문
그대로여야 brief §6 의 `S1` 이 바뀌지 않는다. `conducting-interview` 의 seed 입력 규약이 이 줄의 두 경로로
문장마다 출처와 확인을 가른다.

발동하지 않았으면 「풀린 입력」은 이 command 가 받은 입력 그대로다.

## Step 2: Trivia Escape Check (AP4 회피, AC10)

5 패턴 정의는 `${CLAUDE_PLUGIN_ROOT}/references/trivia-escape.md` 에 있습니다. 그 파일을
읽고 「풀린 입력」을 대조하십시오. 해당하면 그 파일의 안내 문면을 `<command>` = `interview`
으로 채워 출력하고 인터뷰를 시작하지 않습니다.

## Step 2.5: seed 아닌 입력에 대한 조언 (차단 아님)

Phase 0 을 거친 세션은 이 command 를 `/interview @<seed 경로>` 로 부르고, Step 1.5 가 그 파일을
전문으로 풉니다 — seed 는 별도 채널이 아니라 「풀린 입력」으로 옵니다. 그래서 「풀린 입력」의 frontmatter 에
`type: interview-seed` 가 있으면 이 안내는 나가지 않습니다.

「풀린 입력」이 `interview-seed` 가 아니면 한 줄 안내를 낸다 — **막지 않는다.**

> 💡 `/request-framing` 을 먼저 거치면 첫 턴이 정리된 상태로 시작합니다. 지금 그대로
> 진행해도 됩니다.

## Step 3: 인터뷰 진입

Trivia 아닌 경우, `conducting-interview` skill을 invoke하십시오. 인자는 「풀린 입력」입니다 — Step 1.5 가
발동했으면 경로 문자열이 아니라 파일 전문(frontmatter 포함)입니다:

```
Skill conducting-interview <풀린 입력>
```

`conducting-interview` skill이 «지금 이해 · 다음 결정 · 질문 하나» 형식으로 첫 round를 진행합니다.

## Arguments

「풀린 입력」 — Step 1.5 의 결과. 사용자가 `/interview`에 함께 넘긴 rough request 그대로이거나, `/interview @<seed 경로>` 로 불렸으면 Phase 0 이 만든 `interview-seed` 파일 전문(frontmatter 포함)이다. 사용자가 seed 전문을 직접 붙여넣은 입력도 그대로 받는다. 비어 있으면 `conducting-interview`가 첫 질문 ("어떤 것을 만들고 싶으신가요?")으로 시작.

## 다음 단계

`conducting-interview` skill로 흐름이 넘어가 5 통과 의례(R1–R5)를 거쳐 interview brief를
`docs/superpowers/interview/`에 생성합니다. 이 command 자체는 trivia escape + `@경로` 풀기 + skill dispatch
책임만 집니다(NG6 — trivia escape 불변).
