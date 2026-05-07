# Branch Strategy: GitHub Flow

## Model

- `main` is the production branch — always deployable
- All work happens on short-lived `feature/*` or `fix/*` branches
- No `develop`, `release`, or `staging` branches

## Branch Naming Pattern

```regex
^(feature|fix)/[\w.-]+$
```

## Branch Prefixes

| Prefix | Use | Example |
|--------|-----|---------|
| `feature/<name>` | New feature or enhancement | `feature/user-auth` |
| `fix/<name>` | Bug fix | `fix/login-redirect` |

- Use **kebab-case** for the description
- Keep it concise: 2-4 words
- Max 50 characters total

## Branch Lifecycle

### Creating a branch

Always start from latest `main`:

```bash
git checkout main
git pull origin main
git checkout -b feature/<name>
```

### Continuing work on an existing branch

Sync with main before continuing:

```bash
git checkout feature/<name>
git fetch origin
git merge origin/main
```

### After PR merge

- Delete the branch: `git branch -d feature/<name>`
- Or keep and merge main in for follow-up work

## Rules for Claude

- **ALWAYS** check current branch before starting work: `git branch --show-current`
- **NEVER** commit directly to `main`
- **ALWAYS** use `feature/*` or `fix/*` branch naming
- When asked to "start working on X" — create a properly named branch first
- If on `main` and about to make changes — STOP and create a branch first
- When switching to an existing feature branch — check if it needs sync from main
- **ALWAYS** sync an existing feature branch with `git merge origin/main`, never `git rebase`. Rebase rewrites commit SHAs — unsafe on any pushed branch.
