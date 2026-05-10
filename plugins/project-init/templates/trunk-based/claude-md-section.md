## Git Workflow

Trunk-based development. 모든 작업이 `main`으로 빠르게 merge. 상세는 `docs/git-workflow/`.

- Branch: `main`에서 단명 `feature/*` 또는 `fix/*`. 1–2일 내 merge.
- Commit: Conventional Commits (`<type>(<scope>): <description>`)
- PR: {{MERGE_STRATEGY}}, `docs/git-workflow/pr-process.md` 참고
- 미완성 기능에는 feature flag 사용. `main`은 항상 deployable 유지.
- project-init 플러그인이 브랜치 명명·commit 포맷 자동 검증
