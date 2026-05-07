# Commit Conventions

This project uses [Conventional Commits](https://www.conventionalcommits.org/).

## Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

## Rules

- **Subject line**: imperative mood ("add", not "added"), max 72 characters, no period
- **Body**: optional, explain *why* not *what*, wrap at 72 characters
- **Footer**: `BREAKING CHANGE:` for breaking changes, `Co-Authored-By:` for AI-assisted commits

## Types

| Type | When to use | Example |
|------|------------|---------|
| `feat` | New feature | `feat(auth): add OAuth2 login` |
| `fix` | Bug fix | `fix(api): handle null response` |
| `docs` | Documentation only | `docs(readme): add setup guide` |
| `style` | Formatting, no logic change | `style: fix trailing whitespace` |
| `refactor` | Code restructuring, no behavior change | `refactor(db): extract query builder` |
| `perf` | Performance improvement | `perf(search): add query caching` |
| `test` | Adding or fixing tests | `test(auth): add login edge cases` |
| `build` | Build system or dependencies | `build: upgrade webpack to v6` |
| `ci` | CI configuration | `ci: add deploy stage` |
| `chore` | Maintenance, no production code change | `chore: update .gitignore` |

## Scope

Scope by module/directory name: `auth`, `api`, `ui`

## Breaking Changes

Mark breaking changes with `!` after the type/scope:

```
feat(api)!: change response format for /users

BREAKING CHANGE: response now returns array instead of object
```

## AI-Assisted Commits

When Claude assists with or creates a commit, include the footer:

```
Co-Authored-By: Claude <noreply@anthropic.com>
```

## Good Examples

| Message | Why it's good |
|---------|--------------|
| `feat(auth): add password reset flow` | Clear type, scoped, descriptive |
| `fix(cart): prevent duplicate items on rapid click` | Explains the scenario |
| `refactor(db): extract connection pooling to module` | Specific about what changed |

## Bad Examples

| Message | Problem | Fix |
|---------|---------|-----|
| `update code` | No type, vague | `refactor(utils): simplify date parsing` |
| `fix stuff` | No scope, vague | `fix(form): validate email format` |
| `FEAT: Add login` | Uppercase type | `feat(auth): add login page` |
| `feat(auth): Added login.` | Past tense, period | `feat(auth): add login page` |
