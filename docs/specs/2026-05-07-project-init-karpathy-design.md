# Spec: project-init — Karpathy LLM Coding Guidelines Integration

> **Status:** Approved (brainstorming complete 2026-05-07)
> **Plugin:** `plugins/project-init/`
> **Version target:** 1.1.0 → 1.2.0 (minor — new surface)

## Context / Why

`project-init` 플러그인은 현재 target 프로젝트에 git workflow 룰만 inject한다 — `## Git Workflow` 섹션을 CLAUDE.md에 5줄, 디테일은 `docs/git-workflow/` 3개 파일로 분리. 이 플러그인의 mechanism("프로젝트 시작 시 CLAUDE.md에 룰 주입")은 git 외 다른 baseline 룰에도 적용 가능하다.

Andrej Karpathy의 LLM 코딩 관찰 ([X post](https://x.com/karpathy/status/2015883857489522876), 보존 repo [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills))은 4개 원칙으로 정리된, Claude Code류 LLM의 흔한 실수를 줄이는 보편적 행동 가이드다:

1. **Think Before Coding** — Don't assume. Don't hide confusion. Surface tradeoffs.
2. **Simplicity First** — Minimum code that solves the problem. Nothing speculative.
3. **Surgical Changes** — Touch only what you must. Clean up only your own mess.
4. **Goal-Driven Execution** — Define success criteria. Loop until verified.

이를 project-init이 inject하는 모든 새 프로젝트에 baseline으로 깔면, Claude가 그 프로젝트에서 일할 때 동일한 행동 baseline을 일관되게 따르게 된다. 이는 devbrew Three Laws 중 **Law 1 (Clarity Before Code)**의 구체화다 — 명세 baseline을 사전에 깔아두는 mechanism이다.

devbrew 자체 CLAUDE.md엔 Karpathy 원칙이 이미 Three Laws 및 Forbidden Patterns에 흡수되어 있으므로 본 변경은 devbrew 자체엔 손대지 않고, project-init이 만드는 *target 프로젝트*의 CLAUDE.md baseline만 보강한다.

## Goals

- target 프로젝트 CLAUDE.md에 Karpathy 4원칙을 4줄 inline 섹션으로 자동 inject (always-on, opt-in 없음).
- Hybrid 형식 — EN 헤더 (verbatim Karpathy framing) + KO 설명 (devbrew Korean-primary 정책 일치).
- 1줄 attribution으로 출처 명시 (압축본임을 명시).
- `/project-init` 한 번 실행으로 LLM Guidelines + Git Workflow 둘 다 완료.
- Re-init 안전성 — 기존 CLAUDE.md 사용자 콘텐츠 보존, 두 managed section만 정확히 교체.
- devbrew 플러그인 룰 회복 — README "Principles Instantiated" 섹션 + CHANGELOG.md 신규 작성 (현재 누락 상태 회복).

## Non-Goals

- Karpathy 원문 ~70줄 verbatim full-text inject 안 함 — 압축본 4줄.
- Hook validation 추가 안 함 — Karpathy 원칙은 judgment-based, regex 검증 불가.
- 별도 `docs/llm-guidelines.md` 디테일 파일 생성 안 함 — 4줄이면 inline 충분.
- 새 customization 질문 추가 안 함 — `/project-init` Q 흐름은 그대로 유지.
- devbrew 자체 CLAUDE.md (이 repo)는 변경 안 함 — Karpathy 원칙은 이미 Three Laws + Forbidden Patterns에 흡수.
- 새 별도 플러그인 만들지 않음 — project-init scope 안에서 처리.
- 영어/한국어 선택 옵션 없음 — Hybrid 단일 형식.
- 강제 hook 검증 없음 (judgment 룰의 본질).

## Constraints

- **분량 제약:** "너무 크게 키우지 않음" — CLAUDE.md inject 분량은 정확히 8줄 (header + blank + attribution + blank + 4 bullets) 또는 그 이하로 유지. inline 4-line의 "minimal pointer pattern" 준수.
- **Devbrew 플러그인 룰** ([CLAUDE.md](../../CLAUDE.md)):
  - 모든 PR마다 SemVer bump (이 PR: 1.1.0 → 1.2.0 minor).
  - v1.0.0 이상이면 CHANGELOG.md 필수 — 현재 누락된 파일 신규 작성 의무.
  - README "Principles Instantiated" 섹션 필수 — 현재 누락 회복.
  - 한국어 primary, 영어는 식별자/원문 인용/번역 어색한 기술 용어에 한정.
  - 모든 hook에 `DEVBREW_DISABLE_<PLUGIN>=1` kill switch — 본 변경에 새 hook 없으므로 해당 없음.
- **Karpathy verbatim 보존:** EN 헤더 4개는 원문 그대로 ("Think Before Coding", "Simplicity First", "Surgical Changes", "Goal-Driven Execution"). 번역 안 함.
- **재진입 안전성:** `/project-init` 재실행 시 사용자가 손댄 다른 CLAUDE.md 콘텐츠 (예: `## Project Overview`, `## Architecture`) 보존. project-init managed sections만 정확히 교체.
- **Conventional Commits:** PR title `feat(project-init):` prefix, branch `feature/<2-4-words-kebab>`.

## Acceptance Criteria

1. `/project-init`을 빈 디렉토리에서 실행하면 CLAUDE.md에 `## LLM Coding Guidelines` 섹션이 `## Git Workflow` **직전에** (다른 콘텐츠 사이에 끼지 않고 contiguous) 생성된다.
2. 섹션 본문은 다음 마크다운 콘텐츠와 정확히 일치한다 (placeholder 없음, 모든 strategy 동일, 아래 코드 펜스는 spec 표기일 뿐 실제 파일엔 포함 안 됨):
   ```markdown
   ## LLM Coding Guidelines

   > Andrej Karpathy의 [LLM 코딩 관찰](https://x.com/karpathy/status/2015883857489522876) 4줄 압축.

   - Think Before Coding — 가정·혼란·tradeoff 명시, 의심나면 묻기
   - Simplicity First — 요청 이상 만들지 않기, 추측 금지
   - Surgical Changes — 요청과 직결된 줄만, 인접 코드 청소 금지
   - Goal-Driven Execution — 검증 가능한 성공 기준 정의 후 loop
   ```
3. 사용자가 CLAUDE.md에 다른 섹션(`## Project Overview`, `## Architecture` 등)을 가진 상태에서 `/project-init` 재실행해도 그 섹션들이 보존된다.
4. CLAUDE.md에 이미 `## Git Workflow`만 존재하면 그 직전에 `## LLM Coding Guidelines`이 삽입된다.
5. CLAUDE.md에 이미 `## LLM Coding Guidelines`만 존재하면 그 직후에 `## Git Workflow`가 append되며, LLM 섹션은 새 템플릿으로 교체된다.
6. CLAUDE.md에 두 섹션이 모두 존재하면 각각 독립 교체되며 다른 섹션·텍스트는 손대지 않는다.
7. `plugin.json`의 `version` 필드 값이 `"1.2.0"`이다.
8. `plugin.json`의 `description`에 LLM coding baseline / Karpathy 언급이 포함된다.
9. `plugins/project-init/CHANGELOG.md` 파일이 존재한다 (1.2.0 entry + 1.1.0 retroactive entry, Keep a Changelog 형식).
10. `plugins/project-init/README.md`에 `## Principles Instantiated` 섹션이 존재한다 (Law 1, Law 3, plugin shape 3개 항목).
11. README "How It Works" Step 4의 생성 파일 목록이 LLM Guidelines section을 반영한다.
12. README "Features" 표에 LLM Coding Guidelines 행이 추가된다.
13. `commands/project-init.md`의 Step 4a, Step 4c, Step 5가 LLM Guidelines 처리를 명시한다 (Step 4c는 4-state matrix 포함).
14. `hooks/post-tool-use.py`와 `hooks/hooks.json`은 변경되지 않는다.
15. PR 제목은 `feat(project-init):` prefix를 사용하며, branch 이름은 `feature/karpathy-llm-guidelines` (또는 동등한 2-4 단어 kebab-case).

## Files to Modify

| Path | Action | Purpose |
|---|---|---|
| `plugins/project-init/templates/shared/llm-guidelines.md` | **CREATE** | 4-line LLM Guidelines template body, attribution 포함 6줄 |
| `plugins/project-init/CHANGELOG.md` | **CREATE** | devbrew 룰 회복, Keep a Changelog 형식, 1.1.0 retroactive (2026-04-12) + 1.2.0 (2026-05-07) entries |
| `plugins/project-init/.claude-plugin/plugin.json` | **MODIFY** | `version` `1.1.0` → `1.2.0`, `description` 업데이트 |
| `plugins/project-init/commands/project-init.md` | **MODIFY** | Step 4a (read 1줄 추가), Step 4c (4-state matrix로 확장), Step 5 (confirmation 메시지에 LLM 언급 추가) |
| `plugins/project-init/README.md` | **MODIFY** | `## Principles Instantiated` 신설 + "How It Works" Step 4 갱신 + "Features" 표 행 추가 |
| `plugins/project-init/hooks/post-tool-use.py` | **UNCHANGED** | Karpathy 원칙은 regex 검증 불가, 의도적 |
| `plugins/project-init/hooks/hooks.json` | **UNCHANGED** | 동상 |
| `plugins/project-init/templates/<strategy>/*` (3 dirs) | **UNCHANGED** | strategy 무관 baseline, shared가 정확함 |

총 5 files touched: 신규 2 (`shared/llm-guidelines.md`, `CHANGELOG.md`) + 수정 3 (`plugin.json`, `commands/project-init.md`, `README.md`).

## Verification Plan

자동 테스트가 어려운 template + 명세 위주 변경. 수동 검증 절차:

1. **템플릿 syntax 점검** — `templates/shared/llm-guidelines.md` Markdown lint pass, x.com 링크 작동.

2. **빈 프로젝트 init 시나리오** — 임시 빈 디렉토리에서 `/project-init` 실행:
   - GitHub Flow 선택 → CLAUDE.md에 `## LLM Coding Guidelines`이 `## Git Workflow` 위에 생성됨 확인.
   - Git Flow / Trunk-based로 동일 시나리오 반복 → strategy 무관하게 LLM 섹션 동일.

3. **재진입 안전성 4-state matrix 검증** — 다음 5 시나리오 각각:
   - **A.** CLAUDE.md 없음 → 둘 다 새로 생성, LLM 위 / Git 아래.
   - **B.** CLAUDE.md에 `## Project Overview` 등 사용자 콘텐츠만 → 끝에 두 섹션 append, 사용자 콘텐츠 보존.
   - **C.** CLAUDE.md에 `## Git Workflow`만 → 그 직전에 `## LLM Coding Guidelines` 삽입, Git Workflow 콘텐츠 교체.
   - **D.** CLAUDE.md에 `## LLM Coding Guidelines`만 → LLM 섹션 새 템플릿으로 교체, 그 직후에 `## Git Workflow` append.
   - **E.** CLAUDE.md에 두 섹션 다 존재 + 사용자 다른 섹션도 존재 → 두 섹션 독립 교체, 다른 콘텐츠 모두 보존.

4. **Devbrew 플러그인 룰 점검**:
   - `cat plugins/project-init/.claude-plugin/plugin.json | jq -r .version` → `1.2.0`.
   - `test -f plugins/project-init/CHANGELOG.md && head -20 plugins/project-init/CHANGELOG.md` → 1.2.0 + 1.1.0 entries 보임.
   - `grep -A 5 "## Principles Instantiated" plugins/project-init/README.md` → 3개 bullet (Law 1, Law 3, plugin shape) 보임.

5. **Hook 무변경 확인** — `git diff main..HEAD plugins/project-init/hooks/`가 빈 결과.

6. **PR 정책 검증** — branch `feature/karpathy-llm-guidelines`, commit `feat(project-init): inject Karpathy LLM coding guidelines (v1.2.0)`, squash merge with `--delete-branch`.

## Rejected Alternatives

| Rejected | Why |
|---|---|
| `docs/llm-guidelines.md` 별도 파일 생성 | 4줄 분량엔 과함. inline이 가벼움. |
| Karpathy 원문 70줄 verbatim inline | "너무 크게 키우지 않음" 위반. user가 explicit reject. |
| 4번째/5번째 customization Q (opt-in) | 4줄 비용 대비 user friction이 큼. always-on이 lightness 정책에 부합. |
| 별도 `/init-llm-rules` sub-command | discovery friction. project-init이 이미 baseline 다루므로 자연스러운 확장. |
| 새 플러그인 (e.g., `karpathy-baseline`) | 4줄 추가에 새 plugin tree는 trivia ceremony anti-pattern. |
| Pure English 형식 | devbrew Korean-primary 정책에 약간 부합 안 함. punch는 EN 헤더가 보존. |
| Pure Korean 형식 | Karpathy "punch" loss ("Think Before Coding" → "코드 전에 생각"은 약함). |
| Devbrew 자체 CLAUDE.md에 Karpathy 추가 | 이미 Three Laws (특히 Law 1) + Forbidden Patterns에 흡수됨. 중복. |
| Hook 추가 (validation) | Karpathy 원칙은 judgment-based, regex 검증 불가능. |
| Per-strategy 복제 | 4줄을 3개 strategy 템플릿에 중복. drift 위험. shared 단일 파일이 DRY. |
| HTML 주석 attribution | 렌더링 안 보여 추적성 약화. 가시 1-line이 더 정직. |

## Metadata

- **Spec date:** 2026-05-07
- **Plugin scope:** `plugins/project-init/`
- **Plugin version target:** 1.2.0 (semver minor — new surface)
- **Branch:** `feature/karpathy-llm-guidelines`
- **Commit type:** `feat(project-init):`
- **PR base:** `main` (GitHub Flow)
- **Merge strategy:** `gh pr merge --squash --delete-branch`
- **Source materials:**
  - [Karpathy X post](https://x.com/karpathy/status/2015883857489522876) (paywalled at fetch time)
  - [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) (verbatim Karpathy CLAUDE.md preserved here)
- **devbrew principles instantiated:** Law 1 (Clarity Before Code) — baseline 명세 사전 주입; Law 3 (Compounding) — 모든 신규 프로젝트가 동일 baseline 받음; plugin-shape minimal pointer.
- **Brainstorming dialog summary:** 3 clarifying questions resolved → form (4-line inline), integration (always-on), language (hybrid EN/KO), attribution (1-line link). Implementation approach: shared template (DRY).
- **Next step:** Invoke `superpowers:writing-plans` skill to produce implementation plan.
