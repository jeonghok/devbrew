# Commit Conventions

이 프로젝트는 [Conventional Commits](https://www.conventionalcommits.org/)를 따른다.

## Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

## Rules

- **Subject line**: 명령형 동사 ("add" — "added" 아님), **최대 50자**, 마침표 없음. `git log --oneline`, GitHub PR list, 80-col terminal이 50자에서 truncate (Tim Pope 50/72 rule)
- **Body**: 선택, *what*이 아니라 *why*를 설명, **72자에서 wrap**
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
| `revert` | 이전 commit 되돌림 | `revert: feat(auth): add OAuth2 login` |

## Scope

**Feature 영역 기준 scope** — 사용자가 보는 product surface(feature 영역) 단위로 scope 부여. 예: `feat(login): ...`, `fix(checkout): ...`, `feat(onboarding): ...`, `docs(dashboard): ...`. module/directory 이름과 반드시 1:1로 일치할 필요는 없음 — 같은 feature가 여러 디렉토리에 걸쳐 있어도 하나의 scope로 묶는다. 단일 feature가 명확히 식별되지 않는 cross-cutting 변경은 scope 생략 가능 (`chore: ...`).

## Breaking Changes

타입/scope 뒤에 `!`를 붙여 breaking change 표시:

```
feat(api)!: change response format for /users

BREAKING CHANGE: response now returns array instead of object
```

## SemVer Mapping

[Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) §1은 commit type을 [SemVer](https://semver.org/)에 직접 매핑:

| Commit | SemVer bump | 예시 |
|--------|-------------|------|
| `fix:` | PATCH | `1.2.3` → `1.2.4` |
| `feat:` | MINOR | `1.2.3` → `1.3.0` |
| `BREAKING CHANGE:` (any type) | MAJOR | `1.2.3` → `2.0.0` |

자동 릴리스 도구 (`release-please`, `semantic-release`)가 이 매핑으로 version bump + CHANGELOG 생성.

## AI-Assisted Commits

Claude가 commit 작성을 보조하거나 직접 작성하면 footer 추가:

```
Co-Authored-By: Claude <noreply@anthropic.com>
```

## Issue References

Conventional Commits v1.0.0 footer pattern으로 issue를 link:

```
fix(api): handle null response on /users endpoint

Closes: #123
Refs: #98
```

- `Closes: #N` — GitHub이 PR merge 시 issue #N 자동 close
- `Refs: #N` — 관련 issue 참조, close하지 않음 (CC footer 규약 — GitHub 자동 처리 없음, 단순 hyperlink만)

## Good Examples

| Message | Why it's good |
|---------|--------------|
| `feat(login): add password reset flow` | type 명확, feature scope, 설명적 |
| `fix(checkout): prevent duplicate items on rapid click` | 시나리오 설명 |
| `refactor(dashboard): extract chart rendering to module` | 무엇이 바뀌었는지 구체적 |

## Bad Examples

| Message | Problem | Fix |
|---------|---------|-----|
| `update code` | type 없음, 모호 | `refactor(profile): simplify form validation` |
| `fix stuff` | scope 없음, 모호 | `fix(signup): validate email format` |
| `FEAT: Add login` | type 대문자 | `feat(login): add password reset` |
| `feat(login): Added reset.` | 과거형, 마침표 | `feat(login): add password reset` |
