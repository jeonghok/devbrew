# Trivia Escape — 한 문장 기준

「풀린 입력」(진입 skill 의 `## 진입 단계` 2 의 결과)이 한 문장으로 설명 가능한 사소한 변경이면(philosophy P12 — 파일 수는 기준이 아니다) 이 게이트를 우회한다. 아래 다섯은 그 기준에 드는 흔한 예시다 — 목록에 없어도 한 문장으로 설명되는 변경이면 trivia 로 보고, 목록에 들어도 의미가 바뀌는 변경이면 trivia 가 아니다. 판정은 모델이 하고 근거를 질문에 적는다.

「풀린 입력」의 첫 토큰이 정확히 `force` 면 그 토큰을 떼고 이 판정을 건너뛴다 — 나머지가 「풀린 입력」이 된다.

1. **Typo 1줄 수정** — 예: "fix typo on line 3", "오타 고쳐줘"
2. **주석-only diff** — 예: "add a comment explaining X"
3. **formatting** — 예: "reformat foo.py", "indentation 맞춰줘". 파일 수는 기준이 아니다.
4. **단일 식별자 rename** — 예: "rename `bar` to `baz`". 파일 수는 기준이 아니다 — 판정 기준은 **한 문장으로 설명 가능한가**이다(philosophy P12). *의미가 바뀌는 rename(공개 API·직렬화 키 등)은 파일이 하나여도 trivia 아님.*
5. **짧은 요청 + 명백히 안전한 syntactic action 동사** — 예: "fix typo", "add semicolon", "remove blank line"(보기: 10 토큰 안팎). *다음 경우는 trivia 아님: (a) destructive 동사 `drop`/`truncate`/`reset`/`force-push` 등이 system noun (`table`/`branch`/`production`/`deployment`) 과 결합, (b) `delete`/`remove` + system noun (e.g., "remove auth middleware", "delete user table"). 의미론적 삭제는 syntactic 삭제와 구분.*

해당하면 진행하기 전에 `AskUserQuestion` 한 번으로 사용자에게 묻는다 — 판정은 모델이 했고, 건너뛸지는 사용자가
고른다. `<판정 근거>` 와 `<command>` 는 호출한 진입 skill 이 채운다 — `<command>` 는 호출한 진입 skill 의
완전명(`spec-distill:pm-interview` · `spec-distill:request-framing`)이다:

```javascript
AskUserQuestion({ questions: [{
  header: "trivia 판정",
  question: "사소한 일로 보고 게이트를 건너뛴다 — 그대로 / 전체 과정으로. 판정 근거: <판정 근거>.",
  multiSelect: false,
  options: [
    {label: "그대로", description: "게이트를 건너뛴다. 아래 안내를 내고 이 skill 을 끝낸다 — 직접 처리하면 된다."},
    {label: "전체 과정으로", description: "trivia 판정을 건너뛰고 이 skill 의 다음 단계로 간다."}
  ]
}]})
```

- **그대로** — 다음 안내를 내고 진행하지 않는다:

  > ⚠ 이 요청은 trivia(<판정 근거>)으로 보입니다. 게이트를 우회해서 직접 처리할 수 있습니다.
  > 그래도 진행하시려면 `/<command> force <요청>` 으로 다시 부르거나 더 자세한 컨텍스트를 알려주세요.

  → END (사용자 후속 입력 대기).
- **전체 과정으로** — 이 판정을 건너뛰고 진입 skill 이 정한 다음 단계(request-framing `### 4.` · pm-interview `### 3.5`)로 간다. 「풀린 입력」은 그대로다.
