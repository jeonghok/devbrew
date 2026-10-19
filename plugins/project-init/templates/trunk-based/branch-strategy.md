# Branch Strategy: Trunk-Based Development

## Model

- `main` (trunk) — 항상 deployable, 단일 source of truth
- 단명 브랜치(접두는 아래 `Branch Naming Pattern`) — 1–2일 내 merge
- 장수명 브랜치 없음 (`develop`, `release`, `staging`)
- production에서 미완성 기능을 숨기려면 **feature flag** 사용

## Branch Naming Pattern

```regex
^({{BRANCH_PREFIXES}})/[a-z0-9][a-z0-9.-]*$
```

소문자 + 숫자 + 하이픈 + dot만 허용 (예: `feature/v1.2-fix`). URL-friendly + case-insensitive 파일시스템 충돌 방지.

## Branch Prefixes

| Prefix | Use | Example |
|--------|-----|---------|
| `feature/<name>` | 새 기능 (미완성이면 flag 뒤) | `feature/user-auth` |
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

### Working in a worktree

브랜치를 전환하지 않고 별도 폴더에서 작업할 때도 trunk 에서 짧게 쓴다.

```bash
git fetch origin
git worktree add -b <접두>/<이름> ../<폴더> origin/main
git worktree remove ../<폴더>   # merge 직후
```

첫 push 는 `git push -u origin <접두>/<이름>` 으로 한다(origin 기준 브랜치를 따라가므로 -u 가 필요하다).

이름은 `Branch Naming Pattern` 과 같은 규칙이다. 훅(project-init)은 `git checkout -b` · `git switch -c` 로 만든 이름만 확인한다 — `git worktree add -b` 로 만든 이름은 확인하지 않는다.

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

> **Note:** `release/*` 브랜치는 본 strategy의 `Branch Naming Pattern` 스코프 밖이라 project-init hook이 **advisory 경고**(허용 prefix 목록을 제시하는 다중 줄 메시지 — 이 전략엔 관용 없는 예외)를 냅니다. 단, project-init hook은 **non-blocking**(PostToolUse advisory)이라 브랜치 생성을 **차단하지 않습니다** — 의도된 backport 예외이므로 경고를 무시하고 진행하세요. hook 전체를 끄지 마세요(commit 검증까지 함께 꺼집니다).

```bash
# 1. 마지막 v1 태그에서 release 브랜치 cut (1회만; hook advisory 경고는 무시하고 진행)
#    현재 main 은 이미 다음 major 라 v1 을 고칠 수 없다 — main 이 아니라 태그에서 자른다.
git fetch --tags
git checkout -b release/v1.x v1.2.4   # v1.2.4 = 마지막 v1 릴리스 태그 (git tag -l 'v1.*' --sort=-v:refname | head -1 로 확인)
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

- **변경 작업(파일 편집 · 커밋)을 시작하기 전** 현재 브랜치 확인: `git branch --show-current` — 읽기만 하는 작업에는 확인하지 않는다
- **NEVER** `main`에 직접 commit
- **ALWAYS** 브랜치 이름은 위 `Branch Naming Pattern` 의 접두 중 하나로 시작
- **ALWAYS** 브랜치 단명 유지 — 1–2일 내 merge
- "X 작업 시작해" 요청 시 — 최신 `main`에서 브랜치 생성
- 기능이 클 때 — feature flag 사용 + 부분 merge 제안
- `main`에 있고 변경하려 할 때 — STOP, 브랜치 먼저 생성하거나 worktree 를 만든다(위)
- PR merge 후 — 브랜치 즉시 삭제
