## Git Workflow

GitHub Flow. `main`에서 분기, PR로 merge back. 상세는 `docs/git-workflow/`.

- Branch: `main`에서 `feature/*` 또는 `fix/*`. kebab-case, 2–4 단어.
- Commit: Conventional Commits (`<type>(<scope>): <description>`)
- PR: {{MERGE_STRATEGY}}, `docs/git-workflow/pr-process.md` 참고
- project-init 플러그인이 브랜치 명명·commit 포맷 자동 검증
