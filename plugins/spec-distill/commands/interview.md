---
description: 강한 문제공간 stage — 메타프롬프팅·웹리서치·steelman으로 방향을 끌어내 brainstorming용 interview brief를 생성. devbrew Law 1 instantiation.
argument-hint: "[rough request | @<seed 경로>]"
---

# /interview

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
