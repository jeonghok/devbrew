# project-init Templates Industry Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `plugins/project-init/templates/`의 git-workflow 템플릿 + `hooks/post-tool-use.py`를 2026 industry baseline과 정렬한다 — 8개 파일 변경, version `1.2.3` → `1.3.0`. 사실 오류 (subject 72→50자), regex/prose 정합성 (kebab-case 강제), 누락된 맥락 (Driessen Git Flow caveat / Server-Side Enforcement / TBD release / SemVer mapping / `revert` type / issue-link footer)을 한 PR로 동시 해결.

**Architecture:** 9개 commit으로 분할 — (1) Pre-flight & verification baseline 캡처 → (2-3) shared templates 2개 → (4-6) per-strategy branch-strategy 3개 → (7) hook sync (template ↔ hook regex 정합) → (8) hook 동작 검증 (Python REPL) → (9) version bump + CHANGELOG + final integration verification. Hook 변경은 templates 변경 *후*에만 commit (template = source of truth, hook fallback = 동기화 대상).

**Tech Stack:** Markdown (no compilation), `grep` / `diff` 기반 verification, Python 3 `re` 모듈 REPL test (no test framework — hook은 stdlib만 사용), `git diff --stat` / `git log` 검증.

**Spec:** [`docs/superpowers/specs/2026-05-10-project-init-templates-design.md`](../specs/2026-05-10-project-init-templates-design.md)

---

## Global Notes for Implementer

**Markdown nesting escape:** plan 안에서 markdown 컨텐츠를 보여주는 코드 블록은 nested fence를 표현하기 위해 `` ``` `` (escape된 백틱 3개)를 사용한 곳이 있다. **실제 파일에 쓸 때는 일반 백틱 3개(```)로 작성**한다.

**한국어 prose / 영어 보존 가이드** (v1.2.3 확립 하이브리드 패턴):
- 식별자 영어: `feat`, `fix`, `revert`, `develop`, `main`, `feature/*`, `release/v1.2.0`, `BREAKING CHANGE`, `Closes`, `Refs`
- code/명령 영어: `git checkout`, `gh pr create`, regex, `${CLAUDE_PLUGIN_ROOT}`
- table 컬럼명 영어: `Use`, `Example`, `When to use`, `From`, `Merge to`, `Why it's good`, `Problem`, `Fix`
- 강조 토큰 영어: `**ALWAYS**`, `**NEVER**`
- 표준 카테고리 영어: `### Added`, `### Changed`, `### Fixed` (Keep a Changelog)
- anchor 헤더 영어: `## Git Workflow`, `## LLM Coding Guidelines` (devbrew CLAUDE.md와 coupling)

**Verification baseline 파일** — 모두 `/tmp/`에 저장. 세션 reboot 시 사라지므로 Task 1 → 9를 한 세션 내 실행 권장. 실패해도 Task 1을 재실행하면 복구.

**출처 cite 규칙** — CHANGELOG entry (Task 9)에 6개 출처를 entry 안에 한 줄씩 cite (Law 3 compounding, AC22):
- Tim Pope 2008 (subject 50자) — `https://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html`
- cbea.ms (50/72 룰 reference) — `https://cbea.ms/git-commit/`
- Driessen 2020 reflection (Git Flow caveat) — original `https://nvie.com/posts/a-successful-git-branching-model/` 의 2020 update note
- trunkbaseddevelopment.com (TBD release pattern) — `https://trunkbaseddevelopment.com/`
- GitHub branch protection docs — `https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches`
- Conventional Commits v1.0.0 §1 (SemVer mapping) — `https://www.conventionalcommits.org/en/v1.0.0/`

---

## Pre-flight: Branch & State Check

Plan 실행 전 정확히 한 번만 실행:

```bash
git branch --show-current
# Expected: main (또는 spec 작성 시 만든 feature 브랜치)

git status
# Expected: clean working tree (또는 untracked spec/plan 파일만)

git log --oneline -3
# Expected: 최신 commit이 spec/plan 관련이거나 main HEAD
```

작업용 브랜치를 새로 파야 한다면:

```bash
git checkout main
git pull origin main
git checkout -b feature/project-init-templates-v1.3.0
```

---

## Task 1: Verification Baseline Capture

스펙 V1 (placeholder 보존), V2 (regex 블록 1개씩), V3 (Types 표 row count) 같은 cross-task invariant를 확인하려면 변경 *전* 상태 기록 필요. 이 task는 코드를 바꾸지 않고 baseline만 capture.

**Files:**
- Create: `/tmp/project-init-baseline-placeholders.txt`
- Create: `/tmp/project-init-baseline-regex-blocks.txt`
- Create: `/tmp/project-init-baseline-types-rows.txt`
- Create: `/tmp/project-init-baseline-hook-regex.txt`

- [ ] **Step 1: Placeholder 토큰 baseline (V1)**

```bash
grep -rEn "\{\{[A-Z_]+\}\}" plugins/project-init/templates/ | sort > /tmp/project-init-baseline-placeholders.txt
cat /tmp/project-init-baseline-placeholders.txt
```

Expected output (정확히 5줄):
```
plugins/project-init/templates/git-flow/claude-md-section.md:7:- PR: {{MERGE_STRATEGY}}, `docs/git-workflow/pr-process.md` 참고
plugins/project-init/templates/github-flow/claude-md-section.md:7:- PR: {{MERGE_STRATEGY}}, `docs/git-workflow/pr-process.md` 참고
plugins/project-init/templates/shared/commit-conventions.md:38:{{SCOPE_CONVENTION}}
plugins/project-init/templates/shared/pr-process.md:41:Default: **{{MERGE_STRATEGY}}**
plugins/project-init/templates/trunk-based/claude-md-section.md:7:- PR: {{MERGE_STRATEGY}}, `docs/git-workflow/pr-process.md` 참고
```

만약 줄 수가 5와 다르면 STOP — spec C2 위반 가능. baseline 다시 검토.

- [ ] **Step 2: ```regex 블록 baseline (V2)**

```bash
grep -rEn '^\^\(' plugins/project-init/templates/*/branch-strategy.md > /tmp/project-init-baseline-regex-blocks.txt
cat /tmp/project-init-baseline-regex-blocks.txt
```

Expected output (정확히 3줄, 각 strategy의 regex 본문):
```
plugins/project-init/templates/git-flow/branch-strategy.md:15:^(feature|fix|release|hotfix)/[\w.-]+$
plugins/project-init/templates/github-flow/branch-strategy.md:12:^(feature|fix)/[\w.-]+$
plugins/project-init/templates/trunk-based/branch-strategy.md:13:^(feature|fix)/[\w.-]+$
```

- [ ] **Step 3: `## Types` 표 row count baseline (V3)**

```bash
awk '/^\| Type \| When to use \| Example \|$/,/^$/' plugins/project-init/templates/shared/commit-conventions.md | grep -c '^| `' > /tmp/project-init-baseline-types-rows.txt
cat /tmp/project-init-baseline-types-rows.txt
```

Expected output: `10` (현재 type 10개: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`).

만약 결과가 10이 아니면, 직접 확인:

```bash
awk '/^\| Type \| When to use \| Example \|$/,/^$/' plugins/project-init/templates/shared/commit-conventions.md
```

기록된 값 (post-task verification에서 +1 = `revert` 추가 후 값과 비교).

- [ ] **Step 4: Hook regex baseline (V4)**

```bash
grep -nE "DEFAULT_BRANCH_PATTERN|CONVENTIONAL_COMMIT_PATTERN" plugins/project-init/hooks/post-tool-use.py > /tmp/project-init-baseline-hook-regex.txt
cat /tmp/project-init-baseline-hook-regex.txt
```

Expected output (2줄):
```
19:DEFAULT_BRANCH_PATTERN = re.compile(r"^(feature|fix)/[\w.-]+$")
20:CONVENTIONAL_COMMIT_PATTERN = re.compile(
```

- [ ] **Step 5: 변경 없음 확인 (no commit)**

이 task는 verification baseline만 캡처. **commit 없음**. 다음 task로 진행.

```bash
git status
# Expected: clean (또는 spec/plan 파일만 untracked)
```

---

## Task 2: shared/commit-conventions.md — subject 50자 + `revert` + SemVer Mapping + footer 예제

스펙 AC1, AC2, AC3, AC4, AC5 구현. 4개 sub-change를 1 commit으로.

**Files:**
- Modify: `plugins/project-init/templates/shared/commit-conventions.md`

- [ ] **Step 1: 현재 파일 다시 확인**

```bash
cat plugins/project-init/templates/shared/commit-conventions.md
```

다음 4가지 변경 위치 확인:
- Line 17: subject line 룰 (현재 "최대 72자")
- Line 31 끝: `chore` 다음에 `revert` row 추가
- Line 49 (`## Breaking Changes` 다음): `## SemVer Mapping` 신설
- Line 56 (`## AI-Assisted Commits` 다음): `## Issue References` 신설

- [ ] **Step 2: Line 17 — Subject line 한계 50자로 수정 (AC1)**

Edit: 

old_string:
```
- **Subject line**: 명령형 동사 ("add" — "added" 아님), 최대 72자, 마침표 없음
- **Body**: 선택, *what*이 아니라 *why*를 설명, 72자에서 wrap
```

new_string:
```
- **Subject line**: 명령형 동사 ("add" — "added" 아님), **최대 50자**, 마침표 없음. `git log --oneline`, GitHub PR list, 80-col terminal이 50자에서 truncate (Tim Pope 50/72 rule)
- **Body**: 선택, *what*이 아니라 *why*를 설명, **72자에서 wrap**
```

- [ ] **Step 3: `## Types` 표 마지막에 `revert` row 추가 (AC2)**

Edit:

old_string:
```
| `chore` | 유지보수, 프로덕션 코드 변경 없음 | `chore: update .gitignore` |
```

new_string:
```
| `chore` | 유지보수, 프로덕션 코드 변경 없음 | `chore: update .gitignore` |
| `revert` | 이전 commit 되돌림 | `revert: feat(auth): add OAuth2 login` |
```

- [ ] **Step 4: `## SemVer Mapping` 섹션 신설 (AC3)**

Edit:

old_string:
```
BREAKING CHANGE: response now returns array instead of object
```
```

(주의: 위 코드 블록 닫는 `` ``` ``를 포함해 unique하게 매칭)

new_string:
```
BREAKING CHANGE: response now returns array instead of object
```

## SemVer Mapping

Conventional Commits v1.0.0 §1은 commit type을 [SemVer](https://semver.org/)에 직접 매핑:

| Commit | SemVer bump | 예시 |
|--------|-------------|------|
| `fix:` | PATCH | `1.2.3` → `1.2.4` |
| `feat:` | MINOR | `1.2.3` → `1.3.0` |
| `BREAKING CHANGE:` (any type) | MAJOR | `1.2.3` → `2.0.0` |

자동 릴리스 도구 (`release-please`, `semantic-release`)가 이 매핑으로 version bump + CHANGELOG 생성.
```

- [ ] **Step 5: `## Issue References` 섹션 신설 (AC4)**

Edit:

old_string:
```
Co-Authored-By: Claude <noreply@anthropic.com>
```
```

new_string:
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
- `Refs: #N` — 관련 issue 참조, close하지 않음
```

- [ ] **Step 6: 변경 검증**

```bash
# Subject line이 50자로 변경됐는지
grep -n "최대 50자" plugins/project-init/templates/shared/commit-conventions.md
# Expected: 1 line match

# revert row 존재
grep -n "| \`revert\` |" plugins/project-init/templates/shared/commit-conventions.md
# Expected: 1 line match

# SemVer Mapping 섹션 존재
grep -n "^## SemVer Mapping$" plugins/project-init/templates/shared/commit-conventions.md
# Expected: 1 line match

# Issue References 섹션 존재
grep -n "^## Issue References$" plugins/project-init/templates/shared/commit-conventions.md
# Expected: 1 line match

# Placeholder 보존
grep -c "{{SCOPE_CONVENTION}}" plugins/project-init/templates/shared/commit-conventions.md
# Expected: 1
```

모두 expected와 일치하면 다음 step. 불일치 시 해당 edit 재시도.

- [ ] **Step 7: Commit**

```bash
git add plugins/project-init/templates/shared/commit-conventions.md
git commit -m "$(cat <<'EOF'
fix(project-init): subject 50자 + revert + SemVer mapping + issue refs

Tim Pope 50/72 rule 정렬 (subject 72→50자, AC1).
revert type 추가 (CC v1.0.0 / Angular convention, AC2).
## SemVer Mapping 섹션 신설 (CC v1.0.0 §1, AC3).
## Issue References 섹션 신설 (Closes/Refs footer pattern, AC4).
EOF
)"
```

---

## Task 3: shared/pr-process.md — Server-Side Enforcement 섹션

스펙 AC6, AC7 구현.

**Files:**
- Modify: `plugins/project-init/templates/shared/pr-process.md`

- [ ] **Step 1: `## Server-Side Enforcement` 섹션 신설 (AC6)**

Edit:

old_string:
```
- [ ] PR 설명이 변경사항을 정확히 반영

## Plugin Integration
```

new_string:
```
- [ ] PR 설명이 변경사항을 정확히 반영

## Server-Side Enforcement

> **이 플러그인의 hook은 client-side 검증만** — server-side enforcement는 GitHub Settings → Branches → Branch protection rules (또는 organization 단위 Repository rulesets)에서 별도 설정 필요. Hook이 우회되거나 (`DEVBREW_DISABLE_PROJECT_INIT=1`) 다른 도구에서 push될 때 server-side만이 진정한 enforcement.

`main` (또는 보호 대상 브랜치) protection 권장 설정:

- **Require pull request reviews before merging** — 최소 1명 approval 필수
- **Require status checks to pass before merging** — CI 통과 강제 (예: `lint`, `test`, `build`)
- **Require branches to be up to date before merging** — base와 sync 강제
- **Require linear history** (선택) — merge commit 금지 → squash 또는 rebase merge만 허용
- **Require signed commits** (선택) — GPG/SSH 서명 강제 (보안 critical 프로젝트)
- **Do not allow bypassing the above settings** — admin도 룰 적용

설정 위치: GitHub repo → Settings → Branches → Add branch protection rule.
참조: [GitHub docs — About protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches).

## Plugin Integration
```

- [ ] **Step 2: 변경 검증**

```bash
# 새 섹션 존재
grep -n "^## Server-Side Enforcement$" plugins/project-init/templates/shared/pr-process.md
# Expected: 1 line match

# 6개 protection 항목 (bullet 라인) 존재
grep -cE "^- \*\*Require|^- \*\*Do not allow" plugins/project-init/templates/shared/pr-process.md
# Expected: 6

# 기존 placeholder 보존
grep -c "{{MERGE_STRATEGY}}" plugins/project-init/templates/shared/pr-process.md
# Expected: 1

# 기존 섹션 순서 보존 (## Plugin Integration이 새 섹션 다음에 옴)
grep -n "^## " plugins/project-init/templates/shared/pr-process.md
# Expected 순서:
#   ## PR Body Template
#   ## Creating a PR
#   ## PR Title
#   ## Merge Strategy
#   ## Review Checklist
#   ## Server-Side Enforcement
#   ## Plugin Integration
```

- [ ] **Step 3: Commit**

```bash
git add plugins/project-init/templates/shared/pr-process.md
git commit -m "$(cat <<'EOF'
feat(project-init): add Server-Side Enforcement section to pr-process

Hook은 client-side만 — server-side branch protection 6개 항목 명시.
GitHub docs branch protection 참조 (AC6).
EOF
)"
```

---

## Task 4: github-flow/branch-strategy.md — regex tighten

스펙 AC11, AC12 구현. 가장 작은 변경부터 시작 (다른 두 strategy의 regex tighten template으로 활용).

**Files:**
- Modify: `plugins/project-init/templates/github-flow/branch-strategy.md`

- [ ] **Step 1: ```regex 블록 tighten + 산문 한 줄 추가 (AC11)**

Edit:

old_string:
```
## Branch Naming Pattern

```regex
^(feature|fix)/[\w.-]+$
```

## Branch Prefixes
```

new_string:
```
## Branch Naming Pattern

```regex
^(feature|fix)/[a-z0-9][a-z0-9.-]*$
```

소문자 + 숫자 + 하이픈만 허용. URL-friendly + case-insensitive 파일시스템 충돌 방지 (예: macOS는 `feature/Foo`와 `feature/foo`를 같은 브랜치로 본다).

## Branch Prefixes
```

- [ ] **Step 2: 변경 검증**

```bash
# 새 regex 패턴 확인
grep -E "\^\(feature\|fix\)/\[a-z0-9\]\[a-z0-9\.-\]\*\\\$" plugins/project-init/templates/github-flow/branch-strategy.md
# Expected: 1 line match

# 기존 \w 패턴 사라짐
grep -E "\\\\w" plugins/project-init/templates/github-flow/branch-strategy.md
# Expected: 0 matches

# 산문 추가 확인
grep -n "case-insensitive 파일시스템" plugins/project-init/templates/github-flow/branch-strategy.md
# Expected: 1 line match
```

- [ ] **Step 3: Commit**

```bash
git add plugins/project-init/templates/github-flow/branch-strategy.md
git commit -m "$(cat <<'EOF'
fix(project-init): tighten github-flow branch regex to lowercase only

[\w.-]+ → [a-z0-9][a-z0-9.-]*. \w가 대문자/언더스코어 허용해
산문의 "kebab-case" 권장과 불일치했던 사실 오류 수정 (AC11).
hooks/post-tool-use.py가 이 regex를 동적 로드 (line 72) — 즉시 enforcement.
EOF
)"
```

---

## Task 5: trunk-based/branch-strategy.md — regex tighten + Releasing 섹션

스펙 AC13, AC14 구현.

**Files:**
- Modify: `plugins/project-init/templates/trunk-based/branch-strategy.md`

- [ ] **Step 1: ```regex 블록 tighten + 산문 한 줄 추가 (AC13)**

Edit:

old_string:
```
## Branch Naming Pattern

```regex
^(feature|fix)/[\w.-]+$
```

## Branch Prefixes
```

new_string:
```
## Branch Naming Pattern

```regex
^(feature|fix)/[a-z0-9][a-z0-9.-]*$
```

소문자 + 숫자 + 하이픈만 허용. URL-friendly + case-insensitive 파일시스템 충돌 방지.

## Branch Prefixes
```

- [ ] **Step 2: `## Releasing` 섹션 신설 (AC14)**

Edit:

old_string:
```
- 기능이 완성되고 테스트 끝나면 flag 활성화

## Rules for Claude
```

new_string:
```
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

```bash
# 1. trunk에서 release 브랜치 cut (1회만)
git checkout main
git checkout -b release/v1.x
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
```

- [ ] **Step 3: 변경 검증**

```bash
# 새 regex 확인
grep -E "\^\(feature\|fix\)/\[a-z0-9\]\[a-z0-9\.-\]\*\\\$" plugins/project-init/templates/trunk-based/branch-strategy.md
# Expected: 1 line match

# Releasing 섹션 존재
grep -n "^## Releasing$" plugins/project-init/templates/trunk-based/branch-strategy.md
# Expected: 1 line match

# Pattern A / Pattern B sub-section
grep -cE "^### Pattern [AB] —" plugins/project-init/templates/trunk-based/branch-strategy.md
# Expected: 2

# 기존 섹션 순서
grep -n "^## " plugins/project-init/templates/trunk-based/branch-strategy.md
# Expected 순서:
#   ## Model
#   ## Branch Naming Pattern
#   ## Branch Prefixes
#   ## Branch Lifecycle
#   ## Feature Flags
#   ## Releasing
#   ## Rules for Claude
```

- [ ] **Step 4: Commit**

```bash
git add plugins/project-init/templates/trunk-based/branch-strategy.md
git commit -m "$(cat <<'EOF'
feat(project-init): add Releasing section + tighten regex (trunk-based)

Pattern A (tag from trunk, default) + Pattern B (release branches for
legacy version support) — trunkbaseddevelopment.com canonical (AC14).
Regex [\w.-]+ → [a-z0-9][a-z0-9.-]* (AC13).
EOF
)"
```

---

## Task 6: git-flow/branch-strategy.md — regex tighten + Driessen caveat

스펙 AC8, AC9, AC10 구현.

**Files:**
- Modify: `plugins/project-init/templates/git-flow/branch-strategy.md`

- [ ] **Step 1: `## When NOT to use Git Flow` 섹션 신설 (AC8)**

Edit:

old_string:
```
- `hotfix/*` — 긴급 production 수정, `main`에서 분기, `main` + `develop`에 merge

## Branch Naming Pattern
```

new_string:
```
- `hotfix/*` — 긴급 production 수정, `main`에서 분기, `main` + `develop`에 merge

## When NOT to use Git Flow

> Vincent Driessen 본인이 2020년 3월 [원본 글](https://nvie.com/posts/a-successful-git-branching-model/)에 reflection을 추가했다 — *"continuous delivery 팀이라면 GitHub Flow 같은 더 단순한 모델을 권장. Git Flow는 explicitly versioned 소프트웨어 (mobile/desktop apps, OSS libraries, on-premise software)에 한정된 도구."*

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
```

- [ ] **Step 2: ```regex 블록 tighten (AC9)**

Edit:

old_string:
```
## Branch Naming Pattern

```regex
^(feature|fix|release|hotfix)/[\w.-]+$
```

## Branch Prefixes
```

new_string:
```
## Branch Naming Pattern

```regex
^(feature|fix|release|hotfix)/[a-z0-9][a-z0-9.-]*$
```

소문자 + 숫자 + 하이픈만 허용. URL-friendly + case-insensitive 파일시스템 충돌 방지. `release/v1.2.0`처럼 dot 포함은 OK (`v` 시작 → `[a-z0-9]` 통과, `1.2.0`은 `[a-z0-9.-]*` 통과).

## Branch Prefixes
```

- [ ] **Step 3: 변경 검증**

```bash
# When NOT to use Git Flow 섹션 존재
grep -n "^## When NOT to use Git Flow$" plugins/project-init/templates/git-flow/branch-strategy.md
# Expected: 1 line match

# Driessen 인용 + Atlassian "legacy" 인용 확인
grep -c "Driessen" plugins/project-init/templates/git-flow/branch-strategy.md
# Expected: 1

grep -c "legacy" plugins/project-init/templates/git-flow/branch-strategy.md
# Expected: 1

# 새 regex (release|hotfix 포함된 form)
grep -E "\^\(feature\|fix\|release\|hotfix\)/\[a-z0-9\]\[a-z0-9\.-\]\*\\\$" plugins/project-init/templates/git-flow/branch-strategy.md
# Expected: 1 line match

# 섹션 순서
grep -n "^## " plugins/project-init/templates/git-flow/branch-strategy.md
# Expected 순서:
#   ## Model
#   ## When NOT to use Git Flow
#   ## Branch Naming Pattern
#   ## Branch Prefixes
#   ## Branch Lifecycle
#   ## Rules for Claude
```

- [ ] **Step 4: `release/v1.2.0` 패턴이 새 regex로 통과하는지 검증 (regex sanity)**

```bash
python3 -c "import re; p = re.compile(r'^(feature|fix|release|hotfix)/[a-z0-9][a-z0-9.-]*\$'); assert p.match('release/v1.2.0'); assert p.match('hotfix/critical-crash'); assert p.match('feature/user-auth'); assert not p.match('feature/User_Auth'); assert not p.match('release/V1.2.0'); print('PASS')"
# Expected: PASS
```

- [ ] **Step 5: Commit**

```bash
git add plugins/project-init/templates/git-flow/branch-strategy.md
git commit -m "$(cat <<'EOF'
feat(project-init): add Driessen 2020 caveat + tighten regex (git-flow)

## When NOT to use Git Flow 섹션 — Driessen 본인의 2020 reflection
인용 + Atlassian "legacy" 분류 인용. SaaS/CD 팀에 GitHub Flow 안내 (AC8).
Regex [\w.-]+ → [a-z0-9][a-z0-9.-]* (AC9).
EOF
)"
```

---

## Task 7: hooks/post-tool-use.py — DEFAULT_BRANCH_PATTERN sync + revert type

스펙 AC16, AC17, AC18, AC19 구현. **Templates 변경 후에만 commit** — template = source of truth.

**Files:**
- Modify: `plugins/project-init/hooks/post-tool-use.py`

- [ ] **Step 1: Line 19 `DEFAULT_BRANCH_PATTERN` 동기화 (AC16)**

Edit:

old_string:
```
DEFAULT_BRANCH_PATTERN = re.compile(r"^(feature|fix)/[\w.-]+$")
```

new_string:
```
DEFAULT_BRANCH_PATTERN = re.compile(r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$")
```

- [ ] **Step 2: Line 21 `CONVENTIONAL_COMMIT_PATTERN`에 `revert` 추가 (AC17)**

Edit:

old_string:
```
CONVENTIONAL_COMMIT_PATTERN = re.compile(
    r"^(feat|fix|docs|style|refactor|perf|test|build|ci|chore)(\(.+\))?!?:\s.+"
)
```

new_string:
```
CONVENTIONAL_COMMIT_PATTERN = re.compile(
    r"^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?:\s.+"
)
```

- [ ] **Step 3: Line 141 error message에 `revert` 추가 (AC18)**

Edit:

old_string:
```
        f"Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore\n"
```

new_string:
```
        f"Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert\n"
```

- [ ] **Step 4: Hook 다른 로직 변경 없음 확인 (AC19)**

```bash
# validate_branch, validate_commit, get_branch_pattern, guess_commit_type, kill_switch_active, main 함수의 본문은 변경 없음
git diff plugins/project-init/hooks/post-tool-use.py | grep -E "^[+-]" | grep -vE "^(\+\+\+|---|@@)" | wc -l
# Expected: 6 (3 -, 3 +)

git diff plugins/project-init/hooks/post-tool-use.py
# 직접 확인: 정확히 line 19, 21, 141 세 줄만 변경됐는지
```

만약 6과 다르면 unintended 변경이 있다는 뜻. `git checkout plugins/project-init/hooks/post-tool-use.py`로 롤백 후 step 1부터 재시도.

- [ ] **Step 5: Commit**

```bash
git add plugins/project-init/hooks/post-tool-use.py
git commit -m "$(cat <<'EOF'
fix(project-init): sync hook regex with templates (revert + lowercase)

DEFAULT_BRANCH_PATTERN을 새 template fallback과 동기화 (AC16).
CONVENTIONAL_COMMIT_PATTERN과 error message에 revert 추가 (AC17, AC18).
Templates와 hook이 한 PR 안에서 둘 다 갱신되어야 사용자 fresh
init과 기존 프로젝트 양쪽이 동일하게 동작.
EOF
)"
```

---

## Task 8: Hook Behavioral Verification (Python REPL)

스펙 V5, V6 구현. Hook 동작이 새 regex로 정확히 작동하는지 invariant test.

**Files:**
- 변경 없음 (verification only)

- [ ] **Step 1: Branch regex 동작 — 통과 케이스**

```bash
python3 <<'EOF'
import re
import sys
sys.path.insert(0, 'plugins/project-init/hooks')
# DEFAULT_BRANCH_PATTERN을 직접 import할 수 없으니 새 패턴으로 컴파일
p = re.compile(r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$")

pass_cases = [
    "feature/foo-bar",
    "feature/user-auth",
    "fix/issue-123",
    "fix/login-redirect",
    "feature/v2-migration",
    "feature/abc.def",  # dot 허용
]
for c in pass_cases:
    assert p.match(c), f"Should pass: {c}"
print(f"✓ {len(pass_cases)} pass cases all PASS")
EOF
```

Expected output: `✓ 6 pass cases all PASS`

- [ ] **Step 2: Branch regex 동작 — 거부 케이스**

```bash
python3 <<'EOF'
import re
p = re.compile(r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$")

reject_cases = [
    "Foo_Bar",              # prefix 없음
    "feature/Foo-Bar",      # 대문자
    "feature/foo_bar",      # 언더스코어
    "feature/-foo",         # 첫 자가 하이픈 (정의: [a-z0-9] 시작)
    "Feature/foo-bar",      # prefix 대문자
    "feature/.foo",         # 첫 자가 dot
    "release/v1.0",         # release prefix는 GitHub Flow에 없음
    "chore/cleanup",        # chore prefix는 본 PR scope 밖 (NG1)
]
for c in reject_cases:
    assert not p.match(c), f"Should reject: {c}"
print(f"✓ {len(reject_cases)} reject cases all REJECT")
EOF
```

Expected output: `✓ 8 reject cases all REJECT`

- [ ] **Step 3: Commit pattern 동작 — `revert` 통과**

```bash
python3 <<'EOF'
import re
p = re.compile(r"^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?:\s.+")

pass_cases = [
    "feat: add login",
    "fix(auth): handle null",
    "revert: feat(auth): add OAuth2 login",
    "revert(api): undo breaking change",
    "feat!: breaking",
    "chore(deps): bump",
]
for c in pass_cases:
    assert p.match(c), f"Should pass: {c}"

reject_cases = [
    "update code",          # type 없음
    "FEAT: Add login",      # 대문자 type
    "wip: draft",           # 미정의 type
    "feat:no-space",        # `:` 다음 공백 없음
]
for c in reject_cases:
    assert not p.match(c), f"Should reject: {c}"
print(f"✓ commit pattern tests PASS")
EOF
```

Expected output: `✓ commit pattern tests PASS`

- [ ] **Step 4: Git Flow regex 동작**

```bash
python3 <<'EOF'
import re
p = re.compile(r"^(feature|fix|release|hotfix)/[a-z0-9][a-z0-9.-]*$")

pass_cases = [
    "feature/user-auth",
    "fix/login-redirect",
    "release/v1.2.0",       # AC9 산문에서 명시한 케이스
    "release/1.2.0",        # 숫자 시작도 OK ([a-z0-9] 통과)
    "hotfix/critical-crash",
]
for c in pass_cases:
    assert p.match(c), f"Should pass: {c}"

reject_cases = [
    "release/V1.2.0",       # 대문자 V → reject
    "Release/v1.2.0",       # prefix 대문자 → reject
    "hotfix/Critical_Crash", # 대문자 + 언더스코어 → reject
]
for c in reject_cases:
    assert not p.match(c), f"Should reject: {c}"

print(f"✓ git-flow regex tests PASS")
EOF
```

Expected output: `✓ git-flow regex tests PASS`

- [ ] **Step 5: 변경 없음 (no commit)**

이 task는 verification only. **commit 없음**. 다음 task로.

---

## Task 9: `/project-init` Smoke Test (rendered output verification)

스펙 V7, V8, V9 구현. 새 templates가 사용자 프로젝트에 렌더링됐을 때 모든 새 섹션이 정확히 들어가는지 확인.

**Files:**
- Create: `/tmp/project-init-smoke/` (temporary fixture)

- [ ] **Step 1: 임시 디렉토리 준비**

```bash
rm -rf /tmp/project-init-smoke
mkdir -p /tmp/project-init-smoke/docs/git-workflow
cd /tmp/project-init-smoke && pwd
# Expected: /tmp/project-init-smoke
```

- [ ] **Step 2: GitHub Flow strategy 시뮬레이션 — branch-strategy.md 복사 + placeholder 치환**

```bash
# commands/project-init.md Step 4의 로직을 수동 시뮬레이션
cp /Users/jeonghokim/Downloads/devbrew/plugins/project-init/templates/github-flow/branch-strategy.md /tmp/project-init-smoke/docs/git-workflow/branch-strategy.md

# placeholder 없는 파일이라 그대로 복사
cat /tmp/project-init-smoke/docs/git-workflow/branch-strategy.md | head -20
```

- [ ] **Step 3: commit-conventions.md + pr-process.md 복사 + 치환**

```bash
sed 's|{{SCOPE_CONVENTION}}|`auth`, `api`, `ui`, `db`|g' \
    /Users/jeonghokim/Downloads/devbrew/plugins/project-init/templates/shared/commit-conventions.md \
    > /tmp/project-init-smoke/docs/git-workflow/commit-conventions.md

sed 's|{{MERGE_STRATEGY}}|Squash merge|g' \
    /Users/jeonghokim/Downloads/devbrew/plugins/project-init/templates/shared/pr-process.md \
    > /tmp/project-init-smoke/docs/git-workflow/pr-process.md
```

- [ ] **Step 4: 새 섹션 존재 verification (V7, V8, V9)**

```bash
# V7 — branch-strategy regex가 새 패턴인지
grep -E "\^\(feature\|fix\)/\[a-z0-9\]\[a-z0-9\.-\]\*\\\$" /tmp/project-init-smoke/docs/git-workflow/branch-strategy.md
# Expected: 1 line match

# V8 — commit-conventions에 SemVer Mapping
grep -n "^## SemVer Mapping$" /tmp/project-init-smoke/docs/git-workflow/commit-conventions.md
# Expected: 1 line match

# 추가 — Issue References 섹션도
grep -n "^## Issue References$" /tmp/project-init-smoke/docs/git-workflow/commit-conventions.md
# Expected: 1 line match

# V9 — pr-process에 Server-Side Enforcement
grep -n "^## Server-Side Enforcement$" /tmp/project-init-smoke/docs/git-workflow/pr-process.md
# Expected: 1 line match

# Placeholder 모두 치환됐는지
grep -E "\{\{[A-Z_]+\}\}" /tmp/project-init-smoke/docs/git-workflow/*.md
# Expected: 0 matches
```

- [ ] **Step 5: hook이 새 regex를 실제로 동적 로드하는지 (`get_branch_pattern()` 시뮬레이션)**

```bash
python3 <<'EOF'
import re
strategy_path = "/tmp/project-init-smoke/docs/git-workflow/branch-strategy.md"
with open(strategy_path) as f:
    content = f.read()
match = re.search(r"```regex\n(.+?)\n```", content)
assert match, "regex 블록 못 찾음"
pattern_str = match.group(1)
print(f"Loaded pattern: {pattern_str}")
assert "[a-z0-9]" in pattern_str, f"새 패턴 아님: {pattern_str}"
p = re.compile(pattern_str)
assert p.match("feature/foo-bar")
assert not p.match("feature/Foo_Bar")
print("✓ hook get_branch_pattern() simulation PASS")
EOF
```

Expected output:
```
Loaded pattern: ^(feature|fix)/[a-z0-9][a-z0-9.-]*$
✓ hook get_branch_pattern() simulation PASS
```

- [ ] **Step 6: 정리**

```bash
rm -rf /tmp/project-init-smoke
```

- [ ] **Step 7: 변경 없음 (no commit)**

Verification only. **commit 없음**. 다음 task로.

---

## Task 10: plugin.json bump + CHANGELOG entry + Final Integration Verification

스펙 AC20, AC21, AC22 구현. 마지막 commit으로 version bump + CHANGELOG 마무리.

**Files:**
- Modify: `plugins/project-init/.claude-plugin/plugin.json`
- Modify: `plugins/project-init/CHANGELOG.md`

- [ ] **Step 1: plugin.json version bump (AC20)**

Edit `plugins/project-init/.claude-plugin/plugin.json`:

old_string:
```
  "version": "1.2.3",
```

new_string:
```
  "version": "1.3.0",
```

검증:

```bash
grep '"version"' plugins/project-init/.claude-plugin/plugin.json
# Expected: "version": "1.3.0",
```

- [ ] **Step 2: CHANGELOG.md `[1.3.0]` entry 추가 (AC21, AC22)**

Edit `plugins/project-init/CHANGELOG.md`:

old_string:
```
## [1.2.3] — 2026-05-10
```

new_string:
```
## [1.3.0] — 2026-05-10

### Added
- `templates/shared/commit-conventions.md`에 `revert` commit type row 추가 (Conventional Commits v1.0.0 / Angular convention 표준 type, AC2). `hooks/post-tool-use.py:21` `CONVENTIONAL_COMMIT_PATTERN`과 line 141 error message도 동기화 (AC17, AC18).
- `templates/shared/commit-conventions.md`에 `## SemVer Mapping` 섹션 신설. `fix→PATCH`, `feat→MINOR`, `BREAKING CHANGE→MAJOR` 매핑 명시 — [Conventional Commits v1.0.0 §1](https://www.conventionalcommits.org/en/v1.0.0/) 정의에 따라 `release-please`/`semantic-release` 자동화 enabler (AC3).
- `templates/shared/commit-conventions.md`에 `## Issue References` 섹션 신설. `Closes: #N` (issue auto-close), `Refs: #N` (참조) footer pattern 예제 (AC4).
- `templates/shared/pr-process.md`에 `## Server-Side Enforcement` 섹션 신설. 6개 GitHub branch protection 항목 (required reviews, status checks, up-to-date base, linear history, signed commits, no admin bypass) 명시. "client-side hook이 server-side를 대체하지 않음" 강조. [GitHub docs — About protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches) 참조 (AC6).
- `templates/git-flow/branch-strategy.md`에 `## When NOT to use Git Flow` 섹션 신설. [Vincent Driessen 2020 reflection](https://nvie.com/posts/a-successful-git-branching-model/) 인용 — "continuous delivery → GitHub Flow 권장, Git Flow는 versioned releases 한정". [Atlassian "legacy" 분류](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow) 인용 (AC8).
- `templates/trunk-based/branch-strategy.md`에 `## Releasing` 섹션 신설. Pattern A (tag from trunk, default) + Pattern B (release branches for legacy version support, cherry-pick from trunk). [trunkbaseddevelopment.com](https://trunkbaseddevelopment.com/) canonical 권장 패턴 (AC14).

### Changed
- 3개 strategy의 branch naming regex가 `[\w.-]+` → `[a-z0-9][a-z0-9.-]*`로 tighten. `\w`가 대문자/언더스코어 허용해 산문의 "kebab-case" 권장과 정합성 결여였던 사실 오류 수정 (AC9, AC11, AC13). `hooks/post-tool-use.py:19` `DEFAULT_BRANCH_PATTERN` fallback도 동기화 (AC16). 기존 컨벤션 따르던 사용자 (`feature/foo-bar`)는 영향 없음 — 잘못된 이름 (`feature/Foo_Bar`, `feature/foo_bar`) 쓰던 사용자만 거부됨 (의도된 fix).
- `templates/shared/commit-conventions.md` `## Rules` 섹션의 subject line 한계가 72자 → **50자**로 변경. body wrap 72자 별도 명시. [Tim Pope 2008 *"A Note About Git Commit Messages"*](https://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html) canonical "50/72 rule" 정렬 — `git log --oneline`, GitHub PR list, 80-col terminal이 50자에서 truncate. [cbea.ms *"How to Write a Git Commit Message"*](https://cbea.ms/git-commit/) 동일 권장 (AC1).

### Fixed
- v1.2.3 이전 templates는 subject line 한계를 72자로 표기해 Tim Pope 50/72 rule의 두 한계 (subject 50 / body 72)를 혼동하고 있었음. AC1으로 시정.

## [1.2.3] — 2026-05-10
```

(주의: 기존 `[1.2.3]` entry는 그대로 유지. 새 entry를 그 *위에* 삽입.)

검증:

```bash
# 새 entry 위치 확인 (1.3.0이 1.2.3 위에 와야 함)
grep -nE "^## \[(1\.3\.0|1\.2\.3)\]" plugins/project-init/CHANGELOG.md | head -2
# Expected:
# <line_a>:## [1.3.0] — 2026-05-10
# <line_b>:## [1.2.3] — 2026-05-10
# 그리고 line_a < line_b

# Added/Changed/Fixed 카테고리 모두 존재 (AC21)
grep -A 100 "## \[1.3.0\]" plugins/project-init/CHANGELOG.md | grep -E "^### (Added|Changed|Fixed)$"
# Expected (3줄):
# ### Added
# ### Changed
# ### Fixed

# 6개 출처 모두 cite (AC22)
sources_count=$(grep -c -E "tbaggery|cbea\.ms|nvie\.com|trunkbaseddevelopment\.com|docs\.github\.com|conventionalcommits\.org" plugins/project-init/CHANGELOG.md)
echo "Sources cited: $sources_count"
# Expected: >= 6 (각 출처 최소 1번)
```

- [ ] **Step 3: 모든 변경 final invariant 확인**

```bash
# placeholder count는 변경 전과 동일해야 함 (Task 1 baseline과 비교)
grep -rEn "\{\{[A-Z_]+\}\}" plugins/project-init/templates/ | sort > /tmp/project-init-final-placeholders.txt
diff /tmp/project-init-baseline-placeholders.txt /tmp/project-init-final-placeholders.txt
# Expected: no output (identical)

# regex 블록 3개 모두 새 패턴으로 변경됨
grep -rEn '^\^\(' plugins/project-init/templates/*/branch-strategy.md
# Expected (3줄, 모두 [a-z0-9][a-z0-9.-]* 포함):
# git-flow/branch-strategy.md:<line>:^(feature|fix|release|hotfix)/[a-z0-9][a-z0-9.-]*$
# github-flow/branch-strategy.md:<line>:^(feature|fix)/[a-z0-9][a-z0-9.-]*$
# trunk-based/branch-strategy.md:<line>:^(feature|fix)/[a-z0-9][a-z0-9.-]*$

# Hook regex가 templates와 정합
grep -nE "DEFAULT_BRANCH_PATTERN|CONVENTIONAL_COMMIT_PATTERN" plugins/project-init/hooks/post-tool-use.py
# Expected:
# 19:DEFAULT_BRANCH_PATTERN = re.compile(r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$")
# 20:CONVENTIONAL_COMMIT_PATTERN = re.compile(

# 그리고 line 21에 revert 포함
grep -n "revert" plugins/project-init/hooks/post-tool-use.py
# Expected: 2줄 (line 21 regex + line 141 error message)
```

- [ ] **Step 4: 변경 파일 수 확인 (8개여야 함)**

```bash
git diff main --name-only
# Expected (정확히 8개 파일):
# plugins/project-init/.claude-plugin/plugin.json
# plugins/project-init/CHANGELOG.md
# plugins/project-init/hooks/post-tool-use.py
# plugins/project-init/templates/git-flow/branch-strategy.md
# plugins/project-init/templates/github-flow/branch-strategy.md
# plugins/project-init/templates/shared/commit-conventions.md
# plugins/project-init/templates/shared/pr-process.md
# plugins/project-init/templates/trunk-based/branch-strategy.md
```

만약 8개가 아니면 어떤 파일이 빠졌거나 추가됐는지 확인.

- [ ] **Step 5: README "Hooks Installed", "Principles Instantiated" 섹션 변경 없음 확인 (V13, V14)**

```bash
# README는 본 PR scope 밖
git diff main -- plugins/project-init/README.md
# Expected: no output (no changes)
```

- [ ] **Step 6: Commit (final)**

```bash
git add plugins/project-init/.claude-plugin/plugin.json plugins/project-init/CHANGELOG.md
git commit -m "$(cat <<'EOF'
chore(project-init): bump 1.2.3 → 1.3.0 + CHANGELOG entry

Industry baseline 정렬 PR의 마무리 — version bump (minor: 새 surface
= SemVer Mapping / Issue References / Server-Side Enforcement /
When NOT to use Git Flow / Releasing 5개 새 섹션) + CHANGELOG entry
6개 출처 cite (Tim Pope, cbea.ms, Driessen 2020, trunkbaseddevelopment,
GitHub docs, CC v1.0.0).
EOF
)"
```

- [ ] **Step 7: 최종 git log 확인**

```bash
git log --oneline -10
# Expected: 8개의 새 commit (Task 2-7 + Task 10 = 6 commit, Task 1/8/9는 no-commit)
# 사실은 Task 2-7이 6개 commit + Task 10이 1개 commit = 총 7개 commit
```

- [ ] **Step 8: PR 본문 임시 작성 (review 후 PR 생성 시 사용)**

```bash
cat <<'EOF' > /tmp/project-init-v1.3.0-pr-body.md
## Summary
- `templates/`를 2026 industry baseline과 정렬 — 사실 오류 (subject 72→50자), regex/prose 정합성 (kebab-case 강제), 누락된 맥락 (Driessen Git Flow caveat / Server-Side Enforcement / TBD release / SemVer mapping / `revert` type / issue-link footer) 한 PR로 동시 해결.
- `hooks/post-tool-use.py` 동기화 — `DEFAULT_BRANCH_PATTERN`이 새 template fallback과 일치, `CONVENTIONAL_COMMIT_PATTERN`에 `revert` 추가.
- `plugin.json` `1.2.3` → `1.3.0` (minor — 5개 새 섹션 = 새 surface). CHANGELOG entry에 6개 출처 cite (Law 3 compounding).

## Test Plan
- [x] Hook regex behavioral test (Python REPL, Task 8): branch pass/reject 14 케이스, commit pattern pass/reject 10 케이스 모두 통과
- [x] `/project-init` smoke test (Task 9): 임시 디렉토리에 렌더링 후 모든 새 섹션 존재 확인
- [x] Placeholder 보존 invariant (Task 1 baseline ↔ Task 10 final diff): 매치 0
- [x] 변경 파일 수 정확히 8개 (Task 10 Step 4)
- [x] README 변경 없음 (V13, V14)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF

cat /tmp/project-init-v1.3.0-pr-body.md
```

PR은 *사용자 명시 승인 후* `gh pr create`로 별도 실행. 본 plan 범위 밖.

---

## Spec Coverage Check

| Spec section | Implemented in |
|---|---|
| Goal — 8 파일 변경, 1.2.3 → 1.3.0 | Task 2-7, Task 10 |
| AC1 (subject 50자) | Task 2 Step 2 |
| AC2 (revert row) | Task 2 Step 3 |
| AC3 (SemVer Mapping) | Task 2 Step 4 |
| AC4 (Issue References) | Task 2 Step 5 |
| AC5 (기존 섹션 변경 없음) | Task 2 Step 6 검증 |
| AC6 (Server-Side Enforcement) | Task 3 |
| AC7 (기존 섹션 변경 없음, placeholder 보존) | Task 3 Step 2 검증 |
| AC8 (When NOT to use Git Flow) | Task 6 Step 1 |
| AC9 (git-flow regex tighten) | Task 6 Step 2 |
| AC10 (기존 섹션 변경 없음) | Task 6 Step 3 검증 |
| AC11 (github-flow regex tighten) | Task 4 |
| AC12 (다른 섹션 변경 없음) | Task 4 Step 2 검증 |
| AC13 (trunk-based regex tighten) | Task 5 Step 1 |
| AC14 (Releasing 섹션) | Task 5 Step 2 |
| AC15 (claude-md-section.md 변경 없음) | Task 1 baseline + Task 10 Step 4 (변경 파일 수 8개에 claude-md-section 없음) |
| AC16 (DEFAULT_BRANCH_PATTERN sync) | Task 7 Step 1 |
| AC17 (CONVENTIONAL_COMMIT_PATTERN revert) | Task 7 Step 2 |
| AC18 (error message revert) | Task 7 Step 3 |
| AC19 (다른 hook 로직 변경 없음) | Task 7 Step 4 검증 |
| AC20 (plugin.json 1.3.0) | Task 10 Step 1 |
| AC21 (CHANGELOG entry 카테고리) | Task 10 Step 2 |
| AC22 (6개 출처 cite) | Task 10 Step 2 + Step 2 검증 |
| V1 (placeholder 보존) | Task 1 Step 1 + Task 10 Step 3 diff |
| V2 (regex 블록 3개) | Task 1 Step 2 + Task 10 Step 3 |
| V3 (Types row count) | Task 1 Step 3 (baseline) + 직접 확인 |
| V4 (hook regex baseline) | Task 1 Step 4 + Task 10 Step 3 |
| V5 (branch hook 동작) | Task 8 Step 1, 2 |
| V6 (revert commit hook) | Task 8 Step 3 |
| V7 (smoke test branch regex) | Task 9 Step 4 |
| V8 (smoke test SemVer Mapping) | Task 9 Step 4 |
| V9 (smoke test Server-Side Enforcement) | Task 9 Step 4 |
| V10 (plugin.json 1.3.0) | Task 10 Step 1 검증 |
| V11 (CHANGELOG 카테고리 3개) | Task 10 Step 2 검증 |
| V12 (6개 출처 cite) | Task 10 Step 2 검증 |
| V13 (README Hooks Installed 변경 없음) | Task 10 Step 5 |
| V14 (README Principles Instantiated 변경 없음) | Task 10 Step 5 |

모든 AC와 V가 task에 매핑됨 — coverage 완전.

---

## Self-Review Notes

- **Placeholder scan**: 본 plan 안에 "TBD"/"TODO"/"implement later" 없음. 모든 Edit step이 정확한 old_string + new_string 제공.
- **Type consistency**: 모든 task가 동일한 regex `^(feature|fix)/[a-z0-9][a-z0-9.-]*$` (또는 git-flow의 `^(feature|fix|release|hotfix)/[a-z0-9][a-z0-9.-]*$`) 사용. Hook의 `CONVENTIONAL_COMMIT_PATTERN` 새 형태가 Task 7 Step 2와 Task 8 Step 3에서 일치.
- **Spec coverage gap**: 없음 (위 표 참조).
- **Commit 분할 균형**: Task 2 (큰 변경 4개 sub-step, 1 commit) ↔ Task 4 (작은 변경 1개, 1 commit) — 의도적. Task 2의 4개 변경은 같은 파일 같은 주제 (commit format)라 한 commit이 적절. 분리하면 git history 노이즈.
- **Rollback 전략**: 각 commit이 독립 reviewable이므로 문제 발생 시 `git revert <sha>` 단위로 부분 롤백 가능. Task 7 (hook sync)만 templates와 강 결합 — 만약 rollback 시 templates도 같이 revert해야 enforcement 일관성 유지.
- **사용자 프로젝트 영향**: zero (재실행하지 않으면 기존 사용자의 `docs/git-workflow/` 변경 없음). spec NG8과 일치.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-10-project-init-templates-industry-alignment-plan.md`.

Two execution options:

**1. Subagent-Driven (recommended)** — fresh subagent per task + 두 단계 review (구현 → 리뷰). 8개 파일 변경에 적합 — task 간 isolation 보장, 각 commit이 독립 검토 가능.

**2. Inline Execution** — 현재 세션에서 task 일괄 실행, checkpoint마다 리뷰. 빠르지만 context noise 증가.

어떤 방식으로 진행할까요?
