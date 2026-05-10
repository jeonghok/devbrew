# Branch Strategy: GitHub Flow

## Model

- `main`은 production 브랜치 — 항상 deployable
- 모든 작업은 단명 `feature/*` 또는 `fix/*` 브랜치에서
- `develop`, `release`, `staging` 브랜치 없음

## Branch Naming Pattern

```regex
^(feature|fix)/[\w.-]+$
```

## Branch Prefixes

| Prefix | Use | Example |
|--------|-----|---------|
| `feature/<name>` | 새 기능 또는 enhancement | `feature/user-auth` |
| `fix/<name>` | 버그 수정 | `fix/login-redirect` |

- 설명에는 **kebab-case** 사용
- 간결하게: 2–4 단어
- 전체 50자 이하

## Branch Lifecycle

### Creating a branch

항상 최신 `main`에서 시작:

```bash
git checkout main
git pull origin main
git checkout -b feature/<name>
```

### Continuing work on an existing branch

작업 재개 전 main과 동기화:

```bash
git checkout feature/<name>
git fetch origin
git merge origin/main
```

### After PR merge

- 브랜치 삭제: `git branch -d feature/<name>`
- 또는 유지하고 main을 merge해 후속 작업

## Rules for Claude

- **ALWAYS** 작업 시작 전 현재 브랜치 확인: `git branch --show-current`
- **NEVER** `main`에 직접 commit
- **ALWAYS** `feature/*` 또는 `fix/*` 브랜치 명명 사용
- "X 작업 시작해" 요청 시 — 먼저 적절히 명명된 브랜치 생성
- `main`에 있고 변경하려 할 때 — STOP, 브랜치 먼저 생성
- 기존 feature 브랜치로 전환 시 — main에서 sync 필요한지 확인
- **ALWAYS** 기존 feature 브랜치는 `git merge origin/main`으로 sync, `git rebase`는 절대 안 됨. rebase는 commit SHA를 rewrite — push된 브랜치에 unsafe.
