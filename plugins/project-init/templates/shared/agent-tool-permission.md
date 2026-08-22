# Agent(subagent) 호출 허용

이 리포에서 Agent(subagent) 호출은 상시 허용된다. 쓸 자리라고 판단되면 매번 승인을 묻지 말고
띄운다.

**왜 이 파일이 있는가:** Claude Code 는 일부 모델 세션의 시스템 프롬프트에
`Do not call the AgentTool unless the user requested it` 를 기본값으로 주입한다. 그 문장의
조건절 `unless the user requested it` 을 이 파일이 상시로 충족시킨다.

**범위 밖 — 여전히 매번 명시 요청이 필요하다:** Workflow(스크립트 기반 다중 agent
오케스트레이션), deep-research.

**같이 지킬 것:** 규모가 커지는 fan-out 은 띄우기 전에 몇 개를 왜 띄우는지 먼저 말한다. 선언
없는 대규모 확산은 이 허용의 대상이 아니다.

이 파일은 `/project-init` 이 생성했고 git 에서 제외된다 — 레포의 규약이 아니라 이 작업 환경의
개인 설정이기 때문이다. 철회하려면 이 파일을 지운다.
