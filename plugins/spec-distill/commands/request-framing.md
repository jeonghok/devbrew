---
description: 파이프라인 맨 앞의 회의 — 사용자의 의도·steering·방향·goal 을 싱크해 새 세션 첫 턴의 `/interview` 인자로 붙여넣을 `interview-seed` 로 압축한다.
argument-hint: "[raw request / 생각 / 대화 / 자료]"
---

# /request-framing

당신은 spec-distill 파이프라인의 **Phase 0** 에 있습니다. 여기서 하는 일은 요구사항
인터뷰가 아니라 **회의**입니다 — 사용자와 함께 「다음 에이전트에게 정확히 무엇을
맡기는가」를 정하고, 그것을 새 세션의 첫 턴에 그대로 붙여넣을 메시지 하나로 압축합니다.

## Step 1: kill switch

`DEVBREW_SPEC_DISTILL_DISABLE=1` 이 set 이면 즉시 종료(no-op). 상태를 만들지 않습니다.

## Step 2: trivia escape

5 패턴 정의는 `${CLAUDE_PLUGIN_ROOT}/references/trivia-escape.md` 에 있습니다. 그 파일을
읽고 `$ARGUMENTS` 를 대조하십시오. 해당하면 그 파일의 안내 문면을 `<command>` =
`request-framing` 으로 채워 출력하고 진행하지 않습니다.

## Step 3: 회의 진입

trivia 가 아니면 `framing-requests` skill 을 invoke 합니다.

```
Skill framing-requests $ARGUMENTS
```

## Arguments

`$ARGUMENTS` — 거친 프롬프트·생각·대화 로그·자료 무엇이든. 비어 있으면 skill 이
「무엇을 맡기려 하시나요」로 시작합니다.

## 다음 단계

skill 이 확산 후 압축을 거쳐 `interview-seed` 를 `docs/superpowers/interview/` 에
만듭니다. 그 seed 는 **새 세션의 첫 턴에 붙여넣는 메시지**이고, 그 첫 턴은
`/interview <seed 파일 전문>` 한 줄입니다 — frontmatter 세 줄까지 그대로 인자로
넣습니다. 이 모양의 정본과 그렇게 정한 이유는 `framing-requests` skill 의
`## 확정 — proceed 게이트` 안 「호출 모양」 절에 있습니다. 여기서 다시 정하지 않습니다.
