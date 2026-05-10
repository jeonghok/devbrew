# Branch Strategy: Trunk-Based Development

## Model

- `main` (trunk) — 항상 deployable, 단일 source of truth
- 단명 `feature/*` 또는 `fix/*` 브랜치 — 1–2일 내 merge
- 장수명 브랜치 없음 (`develop`, `release`, `staging`)
- production에서 미완성 기능을 숨기려면 **feature flag** 사용

## Branch Naming Pattern

```regex
^(feature|fix)/[\w.-]+$
```

## Branch Prefixes

| Prefix | Use | Example |
|--------|-----|---------|
| `feature/<name>` | 새 기능 (미완성이면 flag 뒤) | `feature/user-auth` |
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

### Working on the branch

- 단명 유지: 최대 1–2일
- 작고 잦은 commit
- 더 오래 걸리면, feature flag 사용하고 중간 작업 merge

### Merging back

- `main`으로 PR 생성
- 리뷰 통과 즉시 merge
- merge 직후 브랜치 삭제

```bash
# PR merge 후
git checkout main
git pull origin main
git branch -d feature/<name>
```

## Feature Flags

여러 날에 걸친 기능의 경우:
- 새 코드를 feature flag 뒤로 wrap
- flag 비활성화 상태로 `main`에 merge
- 기능이 완성되고 테스트 끝나면 flag 활성화

## Rules for Claude

- **ALWAYS** 작업 시작 전 현재 브랜치 확인: `git branch --show-current`
- **NEVER** `main`에 직접 commit
- **ALWAYS** `feature/*` 또는 `fix/*` 브랜치 명명 사용
- **ALWAYS** 브랜치 단명 유지 — 1–2일 내 merge
- "X 작업 시작해" 요청 시 — 최신 `main`에서 브랜치 생성
- 기능이 클 때 — feature flag 사용 + 부분 merge 제안
- `main`에 있고 변경하려 할 때 — STOP, 브랜치 먼저 생성
- PR merge 후 — 브랜치 즉시 삭제
