# Branch Strategy: GitHub Flow

## Model

- `main`은 production 브랜치 — 항상 deployable
- 모든 작업은 단명 `feature/*` 또는 `fix/*` 브랜치에서
- `develop`, `release`, `staging` 브랜치 없음

## Branch Naming Pattern

```regex
^(feature|fix)/[a-z0-9][a-z0-9.-]*$
```

소문자 + 숫자 + 하이픈 + dot만 허용 (예: `feature/v1.2-fix`). URL-friendly + case-insensitive 파일시스템 충돌 방지 (예: macOS는 `feature/Foo`와 `feature/foo`를 같은 브랜치로 본다).

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
- **공유된 브랜치는 rebase하지 않는다.** 기존 feature 브랜치는 `git merge origin/main`으로 sync한다. rebase는 commit SHA를 rewrite하므로, 이미 push돼 다른 사람이 받아간 브랜치에서는 unsafe하다. 아직 공유되지 않은 로컬 브랜치를 정리하는 것은 각자의 판단이다.
