# project-init Karpathy LLM Guidelines Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** target 프로젝트 CLAUDE.md에 Karpathy 4원칙 4줄 압축 baseline을 `/project-init`이 always-on으로 inject하게 만든다.

**Architecture:** project-init 플러그인 안에 `templates/shared/llm-guidelines.md` 신규 템플릿 1개 추가. 기존 `/project-init` 슬래시 커맨드의 Step 4가 이 템플릿을 추가로 read하여 strategy별 `## Git Workflow` 섹션 위에 prepend. CLAUDE.md 재진입 안전성을 위해 Step 4c는 4-state matrix로 확장. 새 hook·새 명령·새 docs/ 파일 없음.

**Tech Stack:** Markdown templates, JSON manifest (`plugin.json`), Bash + git + gh CLI for orchestration. 코드 변경 없음 — 순수 template + command spec + 메타파일 편집.

**Spec reference:** [`docs/specs/2026-05-07-project-init-karpathy-design.md`](../specs/2026-05-07-project-init-karpathy-design.md)

**Branch:** `feature/karpathy-llm-guidelines` (already checked out)

---

## File Structure

| Path | Action | Single Responsibility |
|---|---|---|
| `plugins/project-init/templates/shared/llm-guidelines.md` | **CREATE** | 4-line LLM Guidelines body (정확히 8 lines: header + blank + attribution + blank + 4 bullets). Karpathy 압축본의 단일 source of truth. |
| `plugins/project-init/CHANGELOG.md` | **CREATE** | 플러그인 version history (Keep a Changelog format). 1.1.0 retroactive + 1.2.0 entries. |
| `plugins/project-init/.claude-plugin/plugin.json` | **MODIFY** | `version` `1.1.0` → `1.2.0`, `description`에 LLM baseline 언급 추가. |
| `plugins/project-init/commands/project-init.md` | **MODIFY** | Step 4a: 템플릿 read 1줄 추가. Step 4c: 단일 섹션 룰을 4-state matrix로 확장. Step 5: confirmation 메시지에 LLM 언급. |
| `plugins/project-init/README.md` | **MODIFY** | `## Principles Instantiated` 신설 + "How It Works" Step 4 갱신 + "Features" 표 행 추가. |
| `plugins/project-init/hooks/post-tool-use.py` | **UNCHANGED** | Karpathy 원칙은 judgment-based, regex 검증 불가. |
| `plugins/project-init/hooks/hooks.json` | **UNCHANGED** | 동상. |
| `plugins/project-init/templates/<strategy>/*` (3 dirs) | **UNCHANGED** | strategy 무관 baseline, shared가 정확함. |

총 5 files touched (신규 2 + 수정 3). 5 tasks + 1 verification + 1 PR.

---

### Task 1: LLM Guidelines 템플릿 파일 생성

**Files:**
- Create: `plugins/project-init/templates/shared/llm-guidelines.md`

- [ ] **Step 1: 파일 작성**

이 파일은 placeholder 없는 정적 템플릿이다. 모든 strategy(github-flow / git-flow / trunk-based)에 동일하게 사용된다.

다음 내용을 정확히 작성:

```markdown
## LLM Coding Guidelines

> Andrej Karpathy의 [LLM 코딩 관찰](https://x.com/karpathy/status/2015883857489522876) 4줄 압축.

- Think Before Coding — 가정·혼란·tradeoff 명시, 의심나면 묻기
- Simplicity First — 요청 이상 만들지 않기, 추측 금지
- Surgical Changes — 요청과 직결된 줄만, 인접 코드 청소 금지
- Goal-Driven Execution — 검증 가능한 성공 기준 정의 후 loop
```

마지막 bullet 다음에 trailing newline 1개 (POSIX text file convention). 코드 펜스(```)는 spec 표기였음, 실제 파일에 들어가지 않음.

- [ ] **Step 2: 라인 수 검증**

```bash
wc -l < plugins/project-init/templates/shared/llm-guidelines.md
```

Expected: `8`

- [ ] **Step 3: 헤더·attribution·4 bullet 모두 존재 검증**

```bash
file=plugins/project-init/templates/shared/llm-guidelines.md
grep -q "^## LLM Coding Guidelines$" "$file" && \
grep -q "x.com/karpathy/status/2015883857489522876" "$file" && \
grep -q "Think Before Coding" "$file" && \
grep -q "Simplicity First" "$file" && \
grep -q "Surgical Changes" "$file" && \
grep -q "Goal-Driven Execution" "$file" && \
echo OK
```

Expected: `OK`

- [ ] **Step 4: 커밋**

```bash
git add plugins/project-init/templates/shared/llm-guidelines.md
git commit -m "$(cat <<'EOF'
feat(project-init): add Karpathy LLM Coding Guidelines template

새 shared 템플릿 추가. 8 lines (header + attribution + 4 bullets) 압축본.
모든 branching strategy에 공통 적용되는 universal baseline.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `/project-init` 커맨드를 4-state matrix로 확장

**Files:**
- Modify: `plugins/project-init/commands/project-init.md`

이 커맨드 파일은 Claude가 따르는 자연어 명세다 (실행 코드 아님). 3 곳 수정: Step 4a의 read 목록, Step 4c의 logic, Step 5의 confirmation 메시지.

- [ ] **Step 1: Step 4a — 템플릿 read 목록에 1줄 추가**

`commands/project-init.md` 파일 내 Step 4a 블록을 찾는다. 현재 read 목록은:

```
Read these files from the plugin:
- `${CLAUDE_PLUGIN_ROOT}/templates/<strategy>/claude-md-section.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/<strategy>/branch-strategy.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/shared/commit-conventions.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/shared/pr-process.md`
```

다음으로 교체:

```
Read these files from the plugin:
- `${CLAUDE_PLUGIN_ROOT}/templates/shared/llm-guidelines.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/<strategy>/claude-md-section.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/<strategy>/branch-strategy.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/shared/commit-conventions.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/shared/pr-process.md`
```

새 1줄을 맨 앞에 추가. shared/llm-guidelines.md는 placeholder 없음, 추가 처리 불필요.

- [ ] **Step 2: Step 4c — 4-state matrix로 교체**

현재 Step 4c 본문은 단일 섹션(`## Git Workflow`)만 다룬다:

```
#### 4c: Write CLAUDE.md section

- If `CLAUDE.md` exists and has a `## Git Workflow` section: **replace** that section only (preserve all other content)
- If `CLAUDE.md` exists but has no `## Git Workflow` section: **append** the section at the end
- If `CLAUDE.md` does not exist: **create** the file with the section

Use the content from `claude-md-section.md` (with placeholders replaced).
```

다음 본문으로 완전히 교체:

```
#### 4c: Write CLAUDE.md sections

The CLAUDE.md gets two project-init-managed sections, in this exact order:

1. `## LLM Coding Guidelines` (from `shared/llm-guidelines.md`, no placeholders)
2. `## Git Workflow` (from `<strategy>/claude-md-section.md` with placeholders replaced)

Apply this matrix based on the current CLAUDE.md state:

| State | Action |
|---|---|
| CLAUDE.md does not exist | Create the file with both sections, LLM Guidelines first, Git Workflow second |
| Exists, neither section present | Append both sections at the end (LLM Guidelines first, Git Workflow second) |
| Exists, only `## Git Workflow` present | Insert `## LLM Coding Guidelines` directly above `## Git Workflow`; replace Git Workflow content with the new template |
| Exists, only `## LLM Coding Guidelines` present | Replace LLM Guidelines content with the new template; append `## Git Workflow` directly after |
| Exists, both sections present | Replace each section's content independently in place |

In every state, preserve all non-managed content (other headings, paragraphs, code blocks) exactly as-is. The two managed sections must remain contiguous (no other content inserted between them).
```

- [ ] **Step 3: Step 5 — confirmation 메시지에 LLM 언급 추가**

현재 Step 5 본문:

```
> Git workflow initialized with **{strategy name}** strategy.
>
> Files created/updated:
> - `CLAUDE.md` — Git Workflow section added
> - `docs/git-workflow/branch-strategy.md` — Branch rules
> - `docs/git-workflow/commit-conventions.md` — Commit conventions
> - `docs/git-workflow/pr-process.md` — PR process
>
> The `project-init` plugin hook will auto-validate branch names and commit messages.
> Use `/commit` or `/commit-push-pr` (commit-commands plugin) for streamlined git operations.
```

다음으로 교체:

```
> Git workflow + LLM coding guidelines initialized with **{strategy name}** strategy.
>
> Files created/updated:
> - `CLAUDE.md` — `## LLM Coding Guidelines` and `## Git Workflow` sections added
> - `docs/git-workflow/branch-strategy.md` — Branch rules
> - `docs/git-workflow/commit-conventions.md` — Commit conventions
> - `docs/git-workflow/pr-process.md` — PR process
>
> The `project-init` plugin hook will auto-validate branch names and commit messages.
> The 4-line LLM Coding Guidelines baseline is derived from Andrej Karpathy's LLM coding observations.
> Use `/commit` or `/commit-push-pr` (commit-commands plugin) for streamlined git operations.
```

- [ ] **Step 4: 3개 변경 모두 들어갔는지 검증**

```bash
file=plugins/project-init/commands/project-init.md
grep -q "templates/shared/llm-guidelines.md" "$file" && \
grep -q "two project-init-managed sections" "$file" && \
grep -q "## LLM Coding Guidelines.* and .*## Git Workflow.* sections added" "$file" && \
grep -q "Karpathy" "$file" && \
echo OK
```

Expected: `OK`

- [ ] **Step 5: 커밋**

```bash
git add plugins/project-init/commands/project-init.md
git commit -m "$(cat <<'EOF'
feat(project-init): inject LLM Guidelines via /project-init command

- Step 4a: read shared/llm-guidelines.md template
- Step 4c: expand single-section logic to 4-state matrix managing
  ## LLM Coding Guidelines + ## Git Workflow as a contiguous block
- Step 5: confirmation message lists the new section and credits Karpathy

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: 플러그인 version 1.1.0 → 1.2.0 + description 갱신

**Files:**
- Modify: `plugins/project-init/.claude-plugin/plugin.json`

devbrew 룰: 플러그인 건드리는 모든 PR이 SemVer bump. 새 surface(LLM Guidelines section) 추가 → minor bump.

- [ ] **Step 1: version 필드 변경**

`plugin.json` 안의 `"version": "1.1.0"`를 `"version": "1.2.0"`으로 변경.

- [ ] **Step 2: description 필드 갱신**

현재:
```
"description": "Initialize git workflow rules for any project. Select a branching strategy (GitHub Flow, Git Flow, Trunk-based), generate CLAUDE.md and docs/ with branch naming, Conventional Commits, and PR process rules. Auto-validates via hooks."
```

새:
```
"description": "Initialize git workflow rules + LLM coding baseline for any project. Select a branching strategy (GitHub Flow, Git Flow, Trunk-based), generate CLAUDE.md and docs/ with branch naming, Conventional Commits, PR process, and Karpathy-derived LLM coding guidelines. Auto-validates via hooks."
```

- [ ] **Step 3: version + description 검증**

```bash
file=plugins/project-init/.claude-plugin/plugin.json
test "$(jq -r .version "$file")" = "1.2.0" && \
jq -r .description "$file" | grep -q "Karpathy" && \
jq -r .description "$file" | grep -q "LLM coding" && \
echo OK
```

Expected: `OK`

- [ ] **Step 4: 커밋**

```bash
git add plugins/project-init/.claude-plugin/plugin.json
git commit -m "$(cat <<'EOF'
chore(project-init): bump version 1.1.0 → 1.2.0

새 surface (LLM Coding Guidelines section). description에 Karpathy
baseline 언급 추가. devbrew 룰: 플러그인 건드리는 PR마다 SemVer bump.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: CHANGELOG.md 신규 작성 (1.1.0 retroactive + 1.2.0)

**Files:**
- Create: `plugins/project-init/CHANGELOG.md`

devbrew 룰: v1.0.0 이상 플러그인은 CHANGELOG.md 필수. 현재 파일 누락 상태 — 이 PR이 회복.

- [ ] **Step 1: CHANGELOG.md 작성**

다음 내용을 정확히 작성:

```markdown
# Changelog

All notable changes to the `project-init` plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] — 2026-05-07

### Added
- `## LLM Coding Guidelines` section injected into target CLAUDE.md alongside `## Git Workflow`. Hybrid format (English headers + Korean explainers), 4 lines compressed from Andrej Karpathy's LLM coding observations.
- New shared template `templates/shared/llm-guidelines.md`.
- README "Principles Instantiated" section citing Law 1 (Clarity Before Code).
- This `CHANGELOG.md` (devbrew rule recovery — was missing for v1.1.0).

### Changed
- `commands/project-init.md` Step 4 now reads and prepends the LLM Guidelines section before the strategy section. Step 5 confirmation lists the new section.
- `plugin.json` description updated to reflect dual-purpose initialization.
- `commands/project-init.md` Step 4c expanded from single-section logic to a 4-state matrix that manages `## LLM Coding Guidelines` and `## Git Workflow` as a contiguous block while preserving all non-managed content.

## [1.1.0] — 2026-04-12

### Added
- Initial public release with three branching strategies: GitHub Flow, Git Flow, Trunk-based.
- `/project-init` interactive command for selecting a strategy and generating CLAUDE.md + `docs/git-workflow/` files.
- PostToolUse hook validating branch naming and Conventional Commits format.
- Templates: shared `commit-conventions.md` and `pr-process.md`; per-strategy `claude-md-section.md` and `branch-strategy.md`.
```

- [ ] **Step 2: 두 entry 모두 존재하는지 검증**

```bash
file=plugins/project-init/CHANGELOG.md
grep -q "^## \[1.2.0\] — 2026-05-07$" "$file" && \
grep -q "^## \[1.1.0\] — 2026-04-12$" "$file" && \
grep -q "Keep a Changelog" "$file" && \
grep -q "Karpathy" "$file" && \
echo OK
```

Expected: `OK`

- [ ] **Step 3: 커밋**

```bash
git add plugins/project-init/CHANGELOG.md
git commit -m "$(cat <<'EOF'
docs(project-init): add CHANGELOG (1.1.0 retroactive + 1.2.0)

devbrew 룰: v1.0.0 이상 플러그인은 CHANGELOG.md 필수. 1.1.0 (initial
release, 2026-04-12)를 retroactive entry로 보존하고 1.2.0 (LLM Guidelines)
entry를 추가. Keep a Changelog 형식.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: README — Principles Instantiated 신설 + How It Works 갱신 + Features 표

**Files:**
- Modify: `plugins/project-init/README.md`

devbrew 룰: 모든 README는 "Principles Instantiated" 섹션 필수. 현재 누락 상태 회복 + 새 surface 반영.

- [ ] **Step 1: "How It Works" Step 4의 CLAUDE.md 라인 갱신**

현재 Step 4의 첫 라인:
```
   - `CLAUDE.md` — minimal Git Workflow section (reference to docs/)
```

다음으로 교체:
```
   - `CLAUDE.md` — `## LLM Coding Guidelines` (4-line Karpathy baseline) + `## Git Workflow` (5-line anchor, reference to `docs/git-workflow/`)
```

- [ ] **Step 2: "Features" 표에 LLM Guidelines 행 추가**

현재 표 (3 행):
```
| Component | Role |
|-----------|------|
| **`/project-init` command** | Interactive setup — select strategy, generate rules |
| **PostToolUse hook** | Auto-validates branch naming and commit message format |
| **Templates** | Pre-built rules for 3 branching strategies |
```

PostToolUse hook 행과 Templates 행 사이에 1행 추가하여 4행으로 만든다:
```
| Component | Role |
|-----------|------|
| **`/project-init` command** | Interactive setup — select strategy, generate rules |
| **PostToolUse hook** | Auto-validates branch naming and commit message format |
| **LLM Coding Guidelines** | 4-line Karpathy-derived behavioral baseline injected into CLAUDE.md |
| **Templates** | Pre-built rules for 3 branching strategies |
```

- [ ] **Step 3: README 끝부분에 새 섹션 "Principles Instantiated" 추가**

`## Usage` 섹션 직전에 (또는 README 맨 끝에 — 둘 중 하나, 다음 Step 4 검증으로 위치 확정) 다음 섹션을 추가:

```markdown
## Principles Instantiated

- **Law 1 (Clarity Before Code)** — 4-line LLM Coding Guidelines (Karpathy-derived: assumptions explicit, no overengineering, surgical scope, verifiable success criteria) injected at the project boundary so Claude reads it on every session start.
- **Law 3 (Compounding)** — PostToolUse hook continuously enforces branch naming and Conventional Commits format; convention drift caught at the action layer.
- **Plugin shape — minimal pointer pattern** — CLAUDE.md keeps terse anchors (4-line LLM block + 5-line Git Workflow); details live in `docs/git-workflow/`. CLAUDE.md bloat 방지 + 룰 discoverability 양립.
```

`## Usage` 섹션 직전이 권장 위치(현재 README 구조: Architecture → How It Works → Features → Branching Strategies → Integration → Usage; "Principles Instantiated"는 메타 섹션이라 Integration 다음, Usage 직전이 자연스러움).

- [ ] **Step 4: 3개 변경 모두 들어갔는지 검증**

```bash
file=plugins/project-init/README.md
grep -q "^## Principles Instantiated$" "$file" && \
grep -q "Law 1 (Clarity Before Code)" "$file" && \
grep -q "Law 3 (Compounding)" "$file" && \
grep -q "minimal pointer pattern" "$file" && \
grep -q "## LLM Coding Guidelines.*4-line Karpathy baseline" "$file" && \
grep -q "Karpathy-derived behavioral baseline injected" "$file" && \
echo OK
```

Expected: `OK`

- [ ] **Step 5: 커밋**

```bash
git add plugins/project-init/README.md
git commit -m "$(cat <<'EOF'
docs(project-init): add Principles Instantiated, reflect LLM Guidelines

- 새 ## Principles Instantiated 섹션 (Law 1, Law 3, plugin-shape) —
  devbrew 룰 회복 (현재 누락 상태 회복).
- How It Works Step 4의 CLAUDE.md 생성물 표기에 LLM Guidelines section 추가.
- Features 표에 LLM Coding Guidelines 행 추가.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: 최종 검증 (static checks against acceptance criteria)

**Files:**
- None (read-only verification)

`/project-init` 슬래시 커맨드의 실제 실행 시나리오는 플러그인 install이 필요하므로 머지 후 사용자가 수동 검증한다 (Spec Verification §2 §3). 이 단계에서는 spec의 acceptance criteria를 static check로 모두 통과하는지 확인한다.

- [ ] **Step 1: 모든 acceptance criteria static check**

다음 스크립트를 실행:

```bash
set -e

PLUGIN=plugins/project-init

echo "AC #2 — 템플릿 본문 정확성"
file=$PLUGIN/templates/shared/llm-guidelines.md
test "$(wc -l < "$file")" = "8"
grep -q "^## LLM Coding Guidelines$" "$file"
grep -q "x.com/karpathy/status/2015883857489522876" "$file"
grep -q "Think Before Coding — 가정·혼란·tradeoff 명시" "$file"
grep -q "Simplicity First — 요청 이상 만들지 않기" "$file"
grep -q "Surgical Changes — 요청과 직결된 줄만" "$file"
grep -q "Goal-Driven Execution — 검증 가능한 성공 기준" "$file"

echo "AC #7, #8 — plugin.json"
test "$(jq -r .version $PLUGIN/.claude-plugin/plugin.json)" = "1.2.0"
jq -r .description $PLUGIN/.claude-plugin/plugin.json | grep -q "Karpathy"
jq -r .description $PLUGIN/.claude-plugin/plugin.json | grep -q "LLM coding"

echo "AC #9 — CHANGELOG"
test -f $PLUGIN/CHANGELOG.md
grep -q "^## \[1.2.0\] — 2026-05-07$" $PLUGIN/CHANGELOG.md
grep -q "^## \[1.1.0\] — 2026-04-12$" $PLUGIN/CHANGELOG.md

echo "AC #10, #11, #12 — README"
grep -q "^## Principles Instantiated$" $PLUGIN/README.md
grep -q "Law 1 (Clarity Before Code)" $PLUGIN/README.md
grep -q "Law 3 (Compounding)" $PLUGIN/README.md
grep -q "minimal pointer pattern" $PLUGIN/README.md
grep -q "LLM Coding Guidelines.*4-line Karpathy" $PLUGIN/README.md
grep -q "Karpathy-derived behavioral baseline" $PLUGIN/README.md

echo "AC #13 — command file"
grep -q "templates/shared/llm-guidelines.md" $PLUGIN/commands/project-init.md
grep -q "two project-init-managed sections" $PLUGIN/commands/project-init.md
grep -q "Karpathy" $PLUGIN/commands/project-init.md

echo "AC #14 — hooks unchanged"
test -z "$(git diff main..HEAD -- $PLUGIN/hooks/)"

echo "ALL OK"
```

Expected 마지막 줄: `ALL OK`. 어떤 한 단언이라도 실패하면 set -e가 즉시 exit 1.

- [ ] **Step 2: AC #14 보강 — hook 파일 손대지 않았는지 git log로도 확인**

```bash
git log main..HEAD --oneline -- plugins/project-init/hooks/
```

Expected: 빈 출력. 어떤 commit도 hooks/ 디렉토리를 건드리지 않음.

- [ ] **Step 3: AC #15 — branch 이름 검증**

```bash
test "$(git branch --show-current)" = "feature/karpathy-llm-guidelines" && echo OK
```

Expected: `OK`.

- [ ] **Step 4: 커밋 graph 미리보기**

```bash
git log main..HEAD --oneline
```

Expected: 5개 commit (Task 1~5의 commits) — Task 1 template, Task 2 command, Task 3 plugin.json, Task 4 CHANGELOG, Task 5 README. (Spec commit은 main으로부터 이미 갈라진 첫 커밋이므로 6개일 수 있음 — 이미 `f066794`로 commit된 spec 포함.)

verification 단계는 commit 없음.

---

### Task 7: PR 생성 (push + gh pr create)

**Files:**
- None (remote action)

- [ ] **Step 1: 현재 상태 점검 (push 전)**

```bash
git status -s
git log --oneline main..HEAD
```

Expected: 워킹 디렉토리 clean. 6개 commit (spec + 5 implementation commits) 또는 7개.

- [ ] **Step 2: branch push**

```bash
git push -u origin feature/karpathy-llm-guidelines
```

Expected: `Branch 'feature/karpathy-llm-guidelines' set up to track 'origin/feature/karpathy-llm-guidelines'.`

- [ ] **Step 3: PR 생성**

```bash
gh pr create --title "feat(project-init): inject Karpathy LLM coding guidelines (v1.2.0)" --body "$(cat <<'EOF'
## Summary

- target 프로젝트 CLAUDE.md에 4줄짜리 `## LLM Coding Guidelines` section을 always-on으로 inject. Hybrid 형식 (EN 헤더 verbatim + KO 설명) + 1줄 attribution. 출처: [Andrej Karpathy의 LLM 코딩 관찰](https://x.com/karpathy/status/2015883857489522876).
- `/project-init` Step 4c를 4-state matrix로 확장 — `## LLM Coding Guidelines`과 `## Git Workflow`을 contiguous managed block으로 다루며 사용자 콘텐츠 보존.
- devbrew 플러그인 룰 회복: `CHANGELOG.md` 신규 + README `## Principles Instantiated` 섹션 신규 + `plugin.json` v1.1.0 → v1.2.0.

## Spec & Plan

- Spec: `docs/specs/2026-05-07-project-init-karpathy-design.md`
- Plan: `docs/plans/2026-05-07-project-init-karpathy.md`

## Test plan

- [ ] `wc -l plugins/project-init/templates/shared/llm-guidelines.md` → 8
- [ ] `jq -r .version plugins/project-init/.claude-plugin/plugin.json` → `1.2.0`
- [ ] `head plugins/project-init/CHANGELOG.md` → 1.2.0 + 1.1.0 entries
- [ ] `grep "Principles Instantiated" plugins/project-init/README.md` → 매치
- [ ] `git diff main..HEAD plugins/project-init/hooks/` → empty
- [ ] 빈 디렉토리에서 `/project-init` 실행 → `## LLM Coding Guidelines`이 `## Git Workflow` 직전에 생성됨 (수동, post-merge)
- [ ] 기존 CLAUDE.md 가진 디렉토리에서 `/project-init` 재실행 → 사용자 섹션 보존 + 두 managed section만 갱신 (수동, post-merge)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL 출력.

- [ ] **Step 4: PR URL 사용자에게 보고**

PR 생성 결과의 URL을 그대로 출력. 사용자가 GitHub에서 검토 후 squash merge:
```bash
gh pr merge --squash --delete-branch
```

(merge는 사용자가 수동 실행 — auto mode는 destructive/shared 액션 자동 수행 안 함.)

---

## Self-Review

### 1. Spec coverage

| Acceptance | Implementing Task |
|---|---|
| AC #1 (`## LLM Coding Guidelines`이 `## Git Workflow` 직전) | Task 2 Step 2 (4-state matrix 의 첫 두 row) |
| AC #2 (섹션 본문 정확성) | Task 1 Step 1, AC verified by Task 6 Step 1 |
| AC #3 (사용자 다른 섹션 보존) | Task 2 Step 2 (matrix의 "preserve all non-managed content") |
| AC #4 (Git Workflow만 있을 때 LLM 위에 삽입) | Task 2 Step 2 (matrix row 3) |
| AC #5 (LLM만 있을 때 Git Workflow 아래 append) | Task 2 Step 2 (matrix row 4) |
| AC #6 (둘 다 있을 때 독립 교체) | Task 2 Step 2 (matrix row 5) |
| AC #7 (version 1.2.0) | Task 3 Step 1 |
| AC #8 (description LLM 언급) | Task 3 Step 2 |
| AC #9 (CHANGELOG.md 존재 + 두 entry) | Task 4 |
| AC #10 (Principles Instantiated 섹션) | Task 5 Step 3 |
| AC #11 (How It Works Step 4) | Task 5 Step 1 |
| AC #12 (Features 표 행) | Task 5 Step 2 |
| AC #13 (command Step 4a/4c/5) | Task 2 Steps 1-3 |
| AC #14 (hooks 무변경) | Task 6 Step 2 (검증) |
| AC #15 (PR title prefix) | Task 7 Step 3 |

모든 15개 AC가 task로 매핑됨. 갭 없음.

### 2. Placeholder scan

검사: TBD, TODO, "implement later", "fill in details", "Add appropriate error handling", "handle edge cases", "Write tests for the above", "Similar to Task N", 코드 없는 step. → 없음.

### 3. Type consistency

- 템플릿 path는 모든 task에서 `plugins/project-init/templates/shared/llm-guidelines.md` 일관.
- 섹션 이름은 모든 task에서 `## LLM Coding Guidelines` 일관 (오타 없음, English).
- Bullet 텍스트는 Task 1과 Task 6 검증 단계에서 동일 wording.
- Branch 이름은 plan 헤더와 Task 7에서 모두 `feature/karpathy-llm-guidelines`.
- PR title prefix는 spec AC #15 / Task 7 Step 3에서 모두 `feat(project-init):`.

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-05-07-project-init-karpathy.md`. Two execution options:

**1. Subagent-Driven (recommended)** — fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** — execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
