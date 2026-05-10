## Git Workflow

Git Flow. release용 `main`, 통합용 `develop`. 상세는 `docs/git-workflow/`.

- Branch: `develop`에서 `feature/*`, `main`에서 `hotfix/*`. kebab-case, 2–4 단어.
- Commit: Conventional Commits (`<type>(<scope>): <description>`)
- PR: {{MERGE_STRATEGY}}, `docs/git-workflow/pr-process.md` 참고
- feature 브랜치는 `develop`에 merge, release와 hotfix는 `main`과 `develop` 양쪽에 merge
- project-init 플러그인이 브랜치 명명·commit 포맷 자동 검증
