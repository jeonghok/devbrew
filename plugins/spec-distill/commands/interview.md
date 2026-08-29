---
description: 강한 문제공간 stage — 메타프롬프팅·웹리서치·steelman으로 방향을 끌어내 brainstorming용 interview brief를 생성. devbrew Law 1 instantiation.
argument-hint: "[rough request]"
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

## Step 2: Trivia Escape Check (AP4 회피, AC10)

5 패턴 정의는 `${CLAUDE_PLUGIN_ROOT}/references/trivia-escape.md` 에 있습니다. 그 파일을
읽고 `$ARGUMENTS` 를 대조하십시오. 해당하면 그 파일의 안내 문면을 `<command>` = `interview`
으로 채워 출력하고 인터뷰를 시작하지 않습니다.

## Step 2.5: seed 아닌 입력에 대한 조언 (차단 아님)

`$ARGUMENTS` 가 `interview-seed` 가 아니면 한 줄 안내를 낸다 — **막지 않는다.**

> 💡 `/request-framing` 을 먼저 거치면 첫 턴이 정리된 상태로 시작합니다. 지금 그대로
> 진행해도 됩니다.

## Step 3: 인터뷰 진입

Trivia 아닌 경우, `conducting-interview` skill을 invoke하십시오:

```
Skill conducting-interview $ARGUMENTS
```

`conducting-interview` skill이 4-block Korean format으로 첫 round를 진행합니다.

## Arguments

`$ARGUMENTS` — 사용자가 `/interview`에 함께 넘긴 rough request. 비어 있으면 `conducting-interview`가 첫 질문 ("어떤 것을 만들고 싶으신가요?")으로 시작.

## 다음 단계

`conducting-interview` skill로 흐름이 넘어가 5 통과 의례(R1–R5)를 거쳐 interview brief를
`docs/superpowers/interview/`에 생성합니다. 이 command 자체는 trivia escape + skill dispatch
책임만 집니다(NG6 — trivia escape 불변).
