# Branch Strategy: Git Flow

## Model

- `main` — production release, version 번호로 태깅
- `develop` — feature 통합 브랜치, 항상 최신 개발 상태 반영
- `feature/*` — 새 기능, `develop`에서 분기, `develop`에 merge back
- `fix/*` — 버그 수정, `develop`에서 분기, `develop`에 merge back
- `release/*` — release 준비, `develop`에서 분기, `main` + `develop`에 merge
- `hotfix/*` — 긴급 production 수정, `main`에서 분기, `main` + `develop`에 merge

## When NOT to use Git Flow

> Vincent Driessen 본인이 2020년 3월 [원본 글](https://nvie.com/posts/a-successful-git-branching-model/)에 reflection을 추가했다 — continuous delivery 팀이라면 GitHub Flow 같은 더 단순한 모델을 권장하며, Git Flow는 explicitly versioned 소프트웨어 (mobile/desktop apps, OSS libraries, on-premise software)에 한정된 도구라고.

Atlassian도 현재 Git Flow를 ["legacy" workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow)로 분류.

**Git Flow가 적합한 경우:**
- App store / package registry로 배포되는 versioned releases
- 옛 major version의 동시 maintenance 필요 (예: v1.x와 v2.x 병행)
- 모바일/데스크탑 앱, OSS 라이브러리, on-premise 소프트웨어

**Git Flow가 부적합한 경우 (→ GitHub Flow / Trunk-Based로 전환):**
- 하루 여러 번 deploy하는 SaaS / 웹 서비스
- 단일 production version만 유지
- 작은 팀 (5명 미만) — Git Flow의 ceremony가 overhead

## Branch Naming Pattern

```regex
^(feature|fix|release|hotfix)/[a-z0-9][a-z0-9.-]*$
```

소문자 + 숫자 + 하이픈만 허용. URL-friendly + case-insensitive 파일시스템 충돌 방지. `release/v1.2.0`처럼 dot 포함은 OK (`v` 시작 → `[a-z0-9]` 통과, `1.2.0`은 `[a-z0-9.-]*` 통과).

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
- **공유된 브랜치는 rebase하지 않는다.** 기존 feature 브랜치는 `git merge origin/develop`으로 sync한다. rebase는 commit SHA를 rewrite하므로, 이미 push돼 다른 사람이 받아간 브랜치에서는 unsafe하다. 아직 공유되지 않은 로컬 브랜치를 정리하는 것은 각자의 판단이다.
