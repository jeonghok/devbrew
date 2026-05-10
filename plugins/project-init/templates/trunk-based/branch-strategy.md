# Branch Strategy: Trunk-Based Development

## Model

- `main` (trunk) — 항상 deployable, 단일 source of truth
- 단명 `feature/*` 또는 `fix/*` 브랜치 — 1–2일 내 merge
- 장수명 브랜치 없음 (`develop`, `release`, `staging`)
- production에서 미완성 기능을 숨기려면 **feature flag** 사용

## Branch Naming Pattern

```regex
^(feature|fix)/[a-z0-9][a-z0-9.-]*$
```

소문자 + 숫자 + 하이픈 + dot만 허용 (예: `feature/v1.2-fix`). URL-friendly + case-insensitive 파일시스템 충돌 방지.

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

## Releasing

[trunkbaseddevelopment.com](https://trunkbaseddevelopment.com/) canonical은 두 가지 release 패턴을 권장:

### Pattern A — Tag from trunk (default)

`main`에서 직접 version 태그를 찍고 그 시점에서 build/deploy:

```bash
git checkout main
git pull origin main
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0
```

CI/CD가 tag push를 트리거로 deploy. 별도 release 브랜치 없음 — `main`이 곧 release source.

### Pattern B — Release branches for legacy support

이미 출시된 옛 version (예: v1.x)에 hotfix를 backport해야 할 때만:

> **Note:** `release/*` 브랜치는 본 strategy의 regex (`^(feature|fix)/...`) 스코프 밖이라 project-init hook이 거부한다. 예외적 1회 작업이므로 kill switch로 우회: `DEVBREW_DISABLE_PROJECT_INIT=1 git checkout -b release/v1.x`.

```bash
# 1. trunk에서 release 브랜치 cut (1회만, kill switch 사용)
git checkout main
git pull origin main
DEVBREW_DISABLE_PROJECT_INIT=1 git checkout -b release/v1.x
git push -u origin release/v1.x

# 2. fix는 항상 trunk에 먼저 commit
git checkout main
# ... fix 작업, commit, PR merge ...

# 3. trunk에서 release 브랜치로 cherry-pick
git checkout release/v1.x
git cherry-pick <fix-commit-sha>
git tag -a v1.2.5 -m "Patch v1.2.5"
git push origin release/v1.x v1.2.5
```

- 새 개발은 항상 `main` (trunk)에서. release 브랜치는 receive-only.
- release 브랜치를 새 기능 개발에 쓰지 말 것 — 그 순간 long-lived feature branch가 되어 TBD 위반.

## Rules for Claude

- **ALWAYS** 작업 시작 전 현재 브랜치 확인: `git branch --show-current`
- **NEVER** `main`에 직접 commit
- **ALWAYS** `feature/*` 또는 `fix/*` 브랜치 명명 사용
- **ALWAYS** 브랜치 단명 유지 — 1–2일 내 merge
- "X 작업 시작해" 요청 시 — 최신 `main`에서 브랜치 생성
- 기능이 클 때 — feature flag 사용 + 부분 merge 제안
- `main`에 있고 변경하려 할 때 — STOP, 브랜치 먼저 생성
- PR merge 후 — 브랜치 즉시 삭제
