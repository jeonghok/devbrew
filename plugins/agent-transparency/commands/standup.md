---
description: "지금 이 작업이 어떤 상태인가 — 코드가 무엇이 됐고, 무엇이 열려 있고, 왜 그렇게 됐는지를 대화 기록과 git 에서 꺼낸다."
argument-hint: "[범위 조정 — 예: \"main 브랜치도 같이\" · \"최근 3일만\"]"
---

# standup

Skill agent-transparency:briefing-current-state $ARGUMENTS

`$ARGUMENTS` 는 **프롬프트 텍스트로만** 흐른다 — 셸에 도달하는 경로가 없다.
범위 조정은 에이전트가 인벤토리의 `in-scope` / `out-of-scope` 라벨을 보고 수행한다.
