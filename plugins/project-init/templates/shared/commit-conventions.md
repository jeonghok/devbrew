# Commit Conventions

이 프로젝트는 [Conventional Commits](https://www.conventionalcommits.org/)를 따른다.

## Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

## Rules

- **Subject line**: 명령형 동사 ("add" — "added" 아님), 최대 72자, 마침표 없음
- **Body**: 선택, *what*이 아니라 *why*를 설명, 72자에서 wrap
- **Footer**: breaking change에는 `BREAKING CHANGE:`, AI 보조 commit에는 `Co-Authored-By:`

## Types

| Type | When to use | Example |
|------|------------|---------|
| `feat` | 새 기능 | `feat(auth): add OAuth2 login` |
| `fix` | 버그 수정 | `fix(api): handle null response` |
| `docs` | 문서만 변경 | `docs(readme): add setup guide` |
| `style` | 포매팅, 로직 변경 없음 | `style: fix trailing whitespace` |
| `refactor` | 코드 재구성, 동작 변경 없음 | `refactor(db): extract query builder` |
| `perf` | 성능 개선 | `perf(search): add query caching` |
| `test` | 테스트 추가/수정 | `test(auth): add login edge cases` |
| `build` | 빌드 시스템·의존성 | `build: upgrade webpack to v6` |
| `ci` | CI 설정 | `ci: add deploy stage` |
| `chore` | 유지보수, 프로덕션 코드 변경 없음 | `chore: update .gitignore` |

## Scope

{{SCOPE_CONVENTION}}

## Breaking Changes

타입/scope 뒤에 `!`를 붙여 breaking change 표시:

```
feat(api)!: change response format for /users

BREAKING CHANGE: response now returns array instead of object
```

## AI-Assisted Commits

Claude가 commit 작성을 보조하거나 직접 작성하면 footer 추가:

```
Co-Authored-By: Claude <noreply@anthropic.com>
```

## Good Examples

| Message | Why it's good |
|---------|--------------|
| `feat(auth): add password reset flow` | type 명확, scope 부여, 설명적 |
| `fix(cart): prevent duplicate items on rapid click` | 시나리오 설명 |
| `refactor(db): extract connection pooling to module` | 무엇이 바뀌었는지 구체적 |

## Bad Examples

| Message | Problem | Fix |
|---------|---------|-----|
| `update code` | type 없음, 모호 | `refactor(utils): simplify date parsing` |
| `fix stuff` | scope 없음, 모호 | `fix(form): validate email format` |
| `FEAT: Add login` | type 대문자 | `feat(auth): add login page` |
| `feat(auth): Added login.` | 과거형, 마침표 | `feat(auth): add login page` |
