---
description: "Generate a PR-understanding artifact and publish it to the GitHub PR (consent-gated)"
argument-hint: "[--dry-run]"
---

# PR-Understanding Publish

`/qg-publish`는 현재 브랜치의 diff로부터 PR-understanding artifact를 **로컬에서** 생성하고,
GitHub에 쓰기 전 반드시 사용자 동의를 구한다. 이 커맨드 자체는 얇은 dispatcher — `gh`를
직접 호출하지 않는다. 실제 생성·미리보기·(동의 후) 게시는 전부
`quality-gates:publishing-pr-understanding` 스킬이 담당한다.

**Arguments:** $ARGUMENTS

- `/qg-publish` — artifact를 생성하고 미리보기를 보여준 뒤, 게시 전 동의를 요청한다.
- `/qg-publish --dry-run` — 미리보기까지만 진행하고 멈춘다. GitHub에 쓰지 않는다.

## Instructions

Invoke `Skill("quality-gates:publishing-pr-understanding")` with `$ARGUMENTS`.
그 스킬이 artifact 생성, 미리보기 표시, `--dry-run` 시 조기 종료, 그리고 (dry-run이
아닐 때) 게시 전 명시적 동의 확보까지 전부 수행한다.
