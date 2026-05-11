---
description: 4-block Korean Socratic 인터뷰로 모호한 요청을 spec.md로 변환. devbrew Law 1 instantiation.
argument-hint: "[rough request]"
---

# /interview

당신은 spec-distill 플러그인의 entry point입니다. 사용자가 `/interview`를 호출하면 다음 순서로 진행하십시오.

## Step 1: kill switch 존중

다음 환경변수가 set이면 즉시 종료 (no-op):

- `DEVBREW_DISABLE_SPEC_DISTILL=1` — 모든 spec-distill 동작 abort.

(`DEVBREW_SKIP_HOOKS` 는 hook 영역으로, command 자체에는 영향 없음.)

## Step 2: Trivia Escape Check (AP4 회피, AC10)

`$ARGUMENTS`가 다음 5 패턴 중 하나에 해당하는지 확인:

1. **Typo 1줄 수정** — 예: "fix typo on line 3", "오타 고쳐줘"
2. **주석-only diff** — 예: "add a comment explaining X"
3. **단일 파일 formatting** — 예: "reformat foo.py", "indentation 맞춰줘"
4. **단일 파일 내 단일 식별자 rename** — 예: "in `foo.py` rename `bar` to `baz`". *Repo-wide / multi-file rename은 trivia 아님 — 의미 변경 risk로 인터뷰 진입.*
5. **<10 토큰 + 명백히 안전한 syntactic action 동사** — 예: "fix typo", "add semicolon", "remove blank line". *다음 경우는 trivia 아님: (a) destructive 동사 `drop`/`truncate`/`reset`/`force-push` 등이 system noun (`table`/`branch`/`production`/`deployment`) 과 결합, (b) `delete`/`remove` + system noun (e.g., "remove auth middleware", "delete user table"). 의미론적 삭제는 syntactic 삭제와 구분.*

해당하면 다음 메시지를 출력하고 인터뷰를 시작하지 마십시오:

> ⚠ 이 요청은 trivia 패턴(<해당 패턴 이름>)으로 보입니다. 인터뷰 게이트를 우회해서 직접 처리할 수 있습니다.
> 그래도 인터뷰를 진행하시려면 명시적으로 "force interview" 또는 더 자세한 컨텍스트를 알려주세요.

→ END (사용자 후속 입력 대기).

## Step 3: 인터뷰 진입

Trivia 아닌 경우, `conducting-interview` skill을 invoke하십시오:

```
Skill conducting-interview $ARGUMENTS
```

`conducting-interview` skill이 4-block Korean format으로 첫 round를 진행합니다.

## Arguments

`$ARGUMENTS` — 사용자가 `/interview`에 함께 넘긴 rough request. 비어 있으면 `conducting-interview`가 첫 질문 ("어떤 것을 만들고 싶으신가요?")으로 시작.

## 다음 단계

`conducting-interview` skill로 흐름이 넘어갑니다. 이 command 자체는 trivia escape + skill dispatch 책임만 집니다.
