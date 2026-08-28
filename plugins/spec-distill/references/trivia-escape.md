# Trivia Escape — 5 패턴

`$ARGUMENTS` 가 아래 다섯 중 하나에 해당하면 이 게이트를 우회한다.

1. **Typo 1줄 수정** — 예: "fix typo on line 3", "오타 고쳐줘"
2. **주석-only diff** — 예: "add a comment explaining X"
3. **formatting** — 예: "reformat foo.py", "indentation 맞춰줘". 파일 수는 기준이 아니다.
4. **단일 식별자 rename** — 예: "rename `bar` to `baz`". 파일 수는 기준이 아니다 — 판정 기준은 **한 문장으로 설명 가능한가**이다(philosophy P12). *의미가 바뀌는 rename(공개 API·직렬화 키 등)은 파일이 하나여도 trivia 아님.*
5. **<10 토큰 + 명백히 안전한 syntactic action 동사** — 예: "fix typo", "add semicolon", "remove blank line". *다음 경우는 trivia 아님: (a) destructive 동사 `drop`/`truncate`/`reset`/`force-push` 등이 system noun (`table`/`branch`/`production`/`deployment`) 과 결합, (b) `delete`/`remove` + system noun (e.g., "remove auth middleware", "delete user table"). 의미론적 삭제는 syntactic 삭제와 구분.*

해당하면 다음 메시지를 출력하고 진행하지 않는다. `<해당 패턴 이름>` 과 `<command>` 는
호출한 명령이 채운다 — `<command>` 는 그 명령의 slash-command 이름(예: `interview` ·
`request-framing`)이다:

> ⚠ 이 요청은 trivia 패턴(<해당 패턴 이름>)으로 보입니다. 게이트를 우회해서 직접 처리할 수 있습니다.
> 그래도 진행하시려면 명시적으로 "force <command>" 또는 더 자세한 컨텍스트를 알려주세요.

→ END (사용자 후속 입력 대기).
