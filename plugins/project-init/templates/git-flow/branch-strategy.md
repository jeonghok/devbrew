# Branch Strategy: Git Flow

## Model

- `main` — production releases, tagged with version numbers
- `develop` — integration branch for features, always reflects latest development state
- `feature/*` — new features, branched from `develop`, merged back to `develop`
- `fix/*` — bug fixes, branched from `develop`, merged back to `develop`
- `release/*` — release preparation, branched from `develop`, merged to `main` + `develop`
- `hotfix/*` — urgent production fixes, branched from `main`, merged to `main` + `develop`

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

- Use **kebab-case** for the description
- Keep it concise: 2-4 words
- Max 50 characters total

## Branch Lifecycle

### Feature / Fix branch

```bash
git checkout develop
git pull origin develop
git checkout -b feature/<name>
# ... work ...
# merge back to develop via PR
```

### Release branch

```bash
git checkout develop
git pull origin develop
git checkout -b release/v<version>
# ... version bumps, final fixes ...
# merge to main AND develop via PR
# tag main: git tag -a v<version> -m "Release v<version>"
```

### Hotfix branch

```bash
git checkout main
git pull origin main
git checkout -b hotfix/<name>
# ... urgent fix ...
# merge to main AND develop via PR
# tag main with patch version
```

### After PR merge

- Delete the branch: `git branch -d <branch-name>`
- For releases: tag `main` with the version number

## Rules for Claude

- **ALWAYS** check current branch before starting work: `git branch --show-current`
- **NEVER** commit directly to `main` or `develop`
- **ALWAYS** create `feature/*` and `fix/*` branches from `develop`, not from `main`
- **ALWAYS** create `hotfix/*` branches from `main`
- **ALWAYS** create `release/*` branches from `develop`
- When asked to "start working on X" — create a feature branch from `develop`
- If on `main` or `develop` and about to make changes — STOP and create a branch first
- When merging a release or hotfix — merge to BOTH `main` and `develop`
- When switching to an existing feature branch — check if it needs sync from `develop`
- **ALWAYS** sync an existing feature branch with `git merge origin/develop`, never `git rebase`. Rebase rewrites commit SHAs — unsafe on any pushed branch.
