# PR Process

## PR Body Template

```markdown
## Summary
- [1–3 bullet으로 변경사항 설명]

## Test Plan
- [ ] [검증 단계]
- [ ] [엣지 케이스 테스트]
```

## Creating a PR

1. 브랜치가 base 브랜치와 동기화되어 있는지 확인
2. upstream tracking으로 push: `git push -u origin <branch-name>`
3. PR 생성:

```bash
gh pr create --title "<type>: <description>" --body "$(cat <<'EOF'
## Summary
- <무엇이 왜 바뀌었는지>

## Test Plan
- [ ] <검증 단계>

Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

## PR Title

- 70자 미만
- Conventional Commits prefix 사용: `feat:`, `fix:`, `refactor:` 등
- 명령형 동사: "add" — "added" 아님

## Merge Strategy

Default: **{{MERGE_STRATEGY}}**

| Strategy | When to use |
|----------|------------|
| **Squash merge** | 브랜치에 WIP/지저분한 commit 다수, base에 깨끗한 단일 commit 원할 때 |
| **Merge commit** | 모든 commit이 깔끔하고 의미 있을 때, 전체 history 보존 원할 때 |
| **Rebase** | linear history 원할 때, 모든 commit이 잘 형성되어 있을 때 |

## Review Checklist

리뷰 요청 전:

- [ ] 모든 테스트 로컬 통과
- [ ] 의도하지 않은 파일 변경 없음 (`git diff --stat`)
- [ ] 브랜치가 base 브랜치와 동기화됨
- [ ] commit 메시지가 컨벤션 따름 (`docs/git-workflow/commit-conventions.md`)
- [ ] PR 설명이 변경사항을 정확히 반영

## Server-Side Enforcement

> **이 플러그인의 hook은 client-side 검증만** — server-side enforcement는 GitHub Settings → Branches → Branch protection rules (또는 organization 단위 Repository rulesets)에서 별도 설정 필요. Hook이 우회되거나 (`DEVBREW_PROJECT_INIT_DISABLE=1`) 다른 도구에서 push될 때 server-side만이 진정한 enforcement.

`main` (또는 보호 대상 브랜치) protection 권장 설정:

- **Require pull request reviews before merging** — 최소 1명 approval 필수
- **Require status checks to pass before merging** — CI 통과 강제 (예: `lint`, `test`, `build`)
- **Require linear history** (선택) — merge commit 금지 → squash 또는 rebase merge만 허용
- **Do not allow force pushes** — protected 브랜치 history 무결성 보장
- **Require signed commits** (선택) — GPG/SSH 서명 강제 (보안 critical 프로젝트)
- **Dismiss stale pull request approvals when new commits are pushed** — 새 commit이 들어오면 이전 approval 자동 무효화

설정 위치: GitHub repo → Settings → Branches → Add branch protection rule.
참조: [GitHub docs — About protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches).

## Plugin Integration

- **commit-commands**: 간소화된 PR 생성을 위해 `/commit-push-pr` 사용
- **quality-gates** (설치 시): `gh pr create`에 quality 파이프라인 자동 트리거
