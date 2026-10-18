# Branch Strategy: GitHub Flow

## Model

- `main`은 production 브랜치 — 항상 deployable
- 모든 작업은 단명 브랜치(접두는 아래 `Branch Naming Pattern`)에서
- `develop`, `release`, `staging` 브랜치 없음

## Branch Naming Pattern

```regex
^({{BRANCH_PREFIXES}})/[a-z0-9][a-z0-9.-]*$
```

소문자 + 숫자 + 하이픈 + dot만 허용 (예: `feature/v1.2-fix`). URL-friendly + case-insensitive 파일시스템 충돌 방지 (예: macOS는 `feature/Foo`와 `feature/foo`를 같은 브랜치로 본다).

## Branch Prefixes

| Prefix | Use | Example |
|--------|-----|---------|
| `feature/<name>` | 새 기능 또는 enhancement | `feature/user-auth` |
| `fix/<name>` | 버그 수정 | `fix/login-redirect` |

추가 접두: {{EXTRA_PREFIX_LIST}}

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

### Working in a worktree

브랜치를 전환하지 않고 별도 폴더에서 작업하려면 최신 `main` 에서 worktree 를 만든다.

```bash
git fetch origin
git worktree add -b <접두>/<이름> ../<폴더> origin/main
# ... ../<폴더> 에서 작업 ...
git worktree remove ../<폴더>
```

첫 push 는 `git push -u origin <접두>/<이름>` 으로 한다(origin 기준 브랜치를 따라가므로 -u 가 필요하다).

이름은 위 `Branch Naming Pattern` 과 같은 규칙을 따른다. project-init 훅은 `git checkout -b` · `git switch -c` 로 만든 이름만 확인한다 — `git worktree add -b` 로 만든 이름은 확인하지 않는다.

## Rules for Claude

- **변경 작업(파일 편집 · 커밋)을 시작하기 전** 현재 브랜치 확인: `git branch --show-current` — 읽기만 하는 작업에는 확인하지 않는다
- **NEVER** `main`에 직접 commit
- **ALWAYS** 브랜치 이름은 위 `Branch Naming Pattern` 의 접두 중 하나로 시작
- "X 작업 시작해" 요청 시 — 먼저 적절히 명명된 브랜치 생성
- `main`에 있고 변경하려 할 때 — STOP, 브랜치 먼저 생성하거나 worktree 를 만든다(위)
- 기존 feature 브랜치로 전환 시 — main에서 sync 필요한지 확인
- **공유된 브랜치는 rebase하지 않는다.** 기존 feature 브랜치는 `git merge origin/main`으로 sync한다. rebase는 commit SHA를 rewrite하므로, 이미 push돼 다른 사람이 받아간 브랜치에서는 unsafe하다. 아직 공유되지 않은 로컬 브랜치를 정리하는 것은 각자의 판단이다.
