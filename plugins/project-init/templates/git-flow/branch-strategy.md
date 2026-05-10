# Branch Strategy: Git Flow

## Model

- `main` — production release, version 번호로 태깅
- `develop` — feature 통합 브랜치, 항상 최신 개발 상태 반영
- `feature/*` — 새 기능, `develop`에서 분기, `develop`에 merge back
- `fix/*` — 버그 수정, `develop`에서 분기, `develop`에 merge back
- `release/*` — release 준비, `develop`에서 분기, `main` + `develop`에 merge
- `hotfix/*` — 긴급 production 수정, `main`에서 분기, `main` + `develop`에 merge

## Branch Naming Pattern

```regex
^(feature|fix|release|hotfix)/[\w.-]+$
```

## Branch Prefixes

| Prefix | From | Merge to | Example |
|--------|------|----------|---------|
| `feature/<name>` | `develop` | `develop` | `feature/user-auth` |
| `fix/<name>` | `develop` | `develop` | `fix/login-redirect` |
| `release/<version>` | `develop` | `main` + `develop` | `release/v1.2.0` |
| `hotfix/<name>` | `main` | `main` + `develop` | `hotfix/critical-crash` |

- 설명에는 **kebab-case** 사용
- 간결하게: 2–4 단어
- 전체 50자 이하

## Branch Lifecycle

### Feature / Fix branch

```bash
git checkout develop
git pull origin develop
git checkout -b feature/<name>
# ... 작업 ...
# PR로 develop에 merge back
```

### Release branch

```bash
git checkout develop
git pull origin develop
git checkout -b release/v<version>
# ... 버전 bump, 마지막 fix ...
# PR로 main과 develop 양쪽에 merge
# main 태깅: git tag -a v<version> -m "Release v<version>"
```

### Hotfix branch

```bash
git checkout main
git pull origin main
git checkout -b hotfix/<name>
# ... 긴급 수정 ...
# PR로 main과 develop 양쪽에 merge
# main에 patch version으로 태깅
```

### After PR merge

- 브랜치 삭제: `git branch -d <branch-name>`
- release의 경우: `main`에 version 번호로 태깅

## Rules for Claude

- **ALWAYS** 작업 시작 전 현재 브랜치 확인: `git branch --show-current`
- **NEVER** `main`이나 `develop`에 직접 commit
- **ALWAYS** `feature/*`와 `fix/*` 브랜치는 `develop`에서 생성, `main`에서 X
- **ALWAYS** `hotfix/*` 브랜치는 `main`에서 생성
- **ALWAYS** `release/*` 브랜치는 `develop`에서 생성
- "X 작업 시작해" 요청 시 — `develop`에서 feature 브랜치 생성
- `main`이나 `develop`에 있고 변경하려 할 때 — STOP, 브랜치 먼저 생성
- release나 hotfix merge 시 — `main`과 `develop` *양쪽*에 merge
- 기존 feature 브랜치로 전환 시 — `develop`에서 sync 필요한지 확인
- **ALWAYS** 기존 feature 브랜치는 `git merge origin/develop`으로 sync, `git rebase`는 절대 안 됨. rebase는 commit SHA를 rewrite — push된 브랜치에 unsafe.
