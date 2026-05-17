---
name: project-init-docs-lint-hook
version: 1.0.0
created_at: 2026-05-17
session_id: brainstorm-2026-05-17
status: locked
next_phase: writing-plans
source: superpowers/brainstorming + 3개 병렬 리서치 (Anthropic 공식 Claude Code 문서, AGENTS.md 오픈 스펙 + OpenAI Codex/Cursor/Aider 벤더 가이드, Chroma "Context Rot" 2025 / Lost-in-the-Middle / MDEval WWW'25 / MAST taxonomy 등 경험적 findings)
---

# project-init — Agent-Readable Docs Convention Enforcement Hook 디자인 스펙 (v1.4.0)

> **For agentic workers:** 이 문서는 `plugins/project-init/`에 신규 `docs-lint` hook을 추가하고, `/project-init` command를 AGENTS.md primary + CLAUDE.md thin-pointer 패턴으로 갱신하기 위한 v1.4.0 변경 명세이다. Root context 파일(`CLAUDE.md`, `AGENTS.md`, `.claude/CLAUDE.md`)에 한정된 5개 deterministic 룰을 PostToolUse advisory hook으로 강제한다 — 기존 `post-tool-use.py`와 동일한 non-blocking systemMessage 패턴. 다음 단계는 superpowers `writing-plans` skill로 implementation plan을 생성하는 것이다.

## 목차

- §1 [Goal](#goal)
- §2 [Context / Why](#context--why)
- §3 [Goals](#goals)
- §4 [Non-goals](#non-goals)
- §5 [Constraints](#constraints)
- §6 [Acceptance Criteria](#acceptance-criteria)
- §7 [Files to Create / Modify](#files-to-create--modify)
- §8 [Verification Plan](#verification-plan)
- §9 [Rejected Alternatives](#rejected-alternatives)
- §10 [Metadata](#metadata)

## Goal

`plugins/project-init/`에 **(a)** root context 파일(`CLAUDE.md`/`AGENTS.md`/`.claude/CLAUDE.md`)의 agent-readable convention 5개 (size, TOC, fenced lang, links resolve, CLAUDE/AGENTS drift)를 PostToolUse advisory로 검증하는 `docs-lint.py` hook을 신설하고, **(b)** `/project-init` command가 AGENTS.md를 canonical content source로 작성하면서 CLAUDE.md를 `@AGENTS.md` 한 줄 thin pointer로 발행하도록 갱신한다. 두 변경을 한 PR (v1.4.0)로 동시 출시.

## Context / Why

devbrew는 Claude Code 플러그인 마켓플레이스로서 *agent가 읽는 문서*를 다루는 플러그인이 다수 존재하나, **"agent가 읽기 좋은 문서가 무엇인가"** 라는 메타-룰은 어디에도 없다. `project-init`은 이미 타깃 프로젝트의 `CLAUDE.md`와 `docs/git-workflow/`를 생성·검증하는 도메인을 가지고 있으므로 (v1.3.0의 `post-tool-use.py`가 branch·commit을 advisory로 검증), 자연스러운 확장 위치.

브레인스토밍 세션에서 3개 독립 리서치 에이전트가 다음을 강하게 수렴 확인:

1. **Anthropic 공식 가이드 ([code.claude.com/docs/en/memory.md], [code.claude.com/docs/en/best-practices])**: *"target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence."* "The over-specified CLAUDE.md" 를 명시적 anti-pattern으로 cite. `MEMORY.md`는 200줄 / 25 KB threshold에서 truncate.
2. **AGENTS.md 오픈 스펙 ([agents.md](https://agents.md/))**: 60k+ 레포 채택, 16+ 벤더 (OpenAI Codex, Google Jules, Cursor, Aider, GitHub Copilot, Gemini CLI, JetBrains Junie, Windsurf 등). OpenAI Codex는 `project_doc_max_bytes` = **32 KiB** hard cap, root→leaf concat 후 cap 도달 시 truncate.
3. **경험적 데이터**: Chroma 2025 *Context Rot* (18 frontier 모델 모두 input length에 monotonic degradation, *logically-coherent haystack이 shuffled보다 worse*), Lost-in-the-Middle (Liu 2023, U자형 accuracy curve), MDEval WWW'25 (markdown structure awareness benchmark), MAST taxonomy (Cemri 2025, 명세 모호성이 multi-agent failure의 41–86.7%). 커뮤니티 측정: CLAUDE.md가 11k–42k 토큰을 매 턴 소비하던 사례 → 500–1500 토큰으로 축소해도 instruction-following 손실 없음.

3개 리서치의 교집합에서 *deterministic하게 검증 가능한* 룰만 추출하면 10개 후보가 나오나, v1 출시 범위는 사용자 선택으로 **High-confidence 코어 5개** + **AGENTS.md/CLAUDE.md drift 검출 1개**로 한정 — false-positive를 최소화하고 점진적으로 확장.

또한 사용자 결정으로 **AGENTS.md를 canonical**, **CLAUDE.md를 `@AGENTS.md` thin pointer**로 채택. 이유: (a) AGENTS.md를 자동 인식하는 벤더가 16+로 Claude Code 단독 인식의 CLAUDE.md보다 reach가 크고, (b) Anthropic 자체도 *"import AGENTS.md via `@AGENTS.md` or symlink"* 패턴 권장, (c) source of truth 1개로 drift 위험 제거 (MAST 명세 모호성 회피).

## Goals

- **G1 — Root context 파일 5개 룰 강제**: R1 (size ≤200줄 warn, >300 strong warn), R2 (TOC required if >300줄), R5 (fenced code block에 언어 태그 필수), R6 (internal markdown link resolves), R-pointer (CLAUDE.md ↔ AGENTS.md drift 검출).
- **G2 — Non-blocking advisory 패턴 준수**: 기존 `post-tool-use.py`와 동일한 `systemMessage` 출력. `decision: "block"` 사용 안 함. Anthropic best-practice의 *"correcting-over-and-over"* anti-pattern 회피.
- **G3 — Worktree-safe**: `CLAUDE_PROJECT_DIR` env var를 기준으로 path resolve (기존 `post-tool-use.py:65` 패턴). worktree 내부에서 호출되면 worktree root 기준 동작. `.git/worktrees/**` 경로는 검사 스킵.
- **G4 — AGENTS.md primary migration**: `/project-init` command가 항상 두 파일을 생성 — `AGENTS.md` (canonical content)와 `CLAUDE.md` (`@AGENTS.md` 한 줄). 기존 CLAUDE.md가 발견되면 사용자에게 migrate 의사 확인.
- **G5 — Kill switch 호환**: devbrew 표준 (`DEVBREW_DISABLE_PROJECT_INIT=1` 전체 disable, `DEVBREW_SKIP_HOOKS=project-init:docs-lint` hook 단위 opt-out). 두 hook 한꺼번에 끄려면 `DEVBREW_SKIP_HOOKS=project-init:post-tool-use,project-init:docs-lint`.
- **G6 — devbrew Plugin Shape 준수**: `plugin.json` minor bump (`1.3.0` → `1.4.0`), `CHANGELOG.md`에 `[1.4.0] — 2026-05-17` entry, `README.md` Architecture/Hooks/Principles 섹션 동기화.
- **G7 — Unit test 동반**: 신규 hook의 모든 룰에 happy/violation 케이스를 Python stdlib `unittest`로 검증. 기존 `post-tool-use.py`엔 unit test가 부재 — 본 PR이 `hooks/tests/` 디렉토리를 신설하나 기존 hook의 backfill은 NG.

## Non-goals

- **NG1 — `docs/**/*.md` 룰 안 함**: R3 (`docs/specs/` 등 deterministic 파일명), R4 (모호한 파일명 금지) 등 docs/** 전반 룰은 v1.4.0 범위 밖. 사용자가 *"Root context 파일"* scope를 명시 선택. Future PR에서 별도 hook 또는 동일 hook의 추가 matcher로 확장 가능.
- **NG2 — `README.md`·`CHANGELOG.md` 검사 안 함**: 이미 markdownlint·keepachangelog 같은 외부 linter 영역. devbrew CHANGELOG 룰은 plugin-validator agent (plugin-dev:plugin-validator)가 부분 cover.
- **NG3 — `.claude/agents/**`·`.claude/commands/**`·`.claude/skills/**` 검사 안 함**: plugin-dev:skill-reviewer 등이 이미 일부 cover, 중복 영역 회피.
- **NG4 — LLM-judgment 기반 룰 안 함**: prose 품질, pushy description 강도, ALL-CAPS 빈도, 한국어/영어 선택, table vs list 등은 mechanical 검증 불가 — false-positive 폭발 위험. 명시적 거부.
- **NG5 — PreToolUse blocking 변형 안 함**: devbrew 표준은 advisory (qg의 reviewer 패턴, 기존 post-tool-use.py 모두). 블로킹이 정말 필요한 룰 (예: version bump 강제)은 별도 PR + 별도 플러그인 영역.
- **NG6 — 기존 `post-tool-use.py` 변경 안 함**: 분리된 hook 파일로 격리, 기존 검증 로직과 coupling 회피. hooks.json에 두 번째 entry만 추가.
- **NG7 — 자동 fix 안 함**: hook은 검증·경고만, mutation 안 함 (devbrew CLAUDE.md *"`SessionStart` 훅은 read-only 조언자"* 정신을 PostToolUse에도 확장). 사용자가 `systemMessage` 보고 수동 수정.

## Constraints

- **C1 — Python 3 stdlib only**: 기존 `post-tool-use.py`가 `json`/`os`/`re`/`sys`만 사용. `docs-lint.py`도 동일 — 외부 의존성 (markdownlint, lychee 등 CLI) 추가 안 함. 사용자 환경에 PyYAML도 가정 안 함 (frontmatter parse가 필요하면 정규식으로).
- **C2 — Hook timeout 10s**: 기존 `hooks.json`의 timeout과 동일. 큰 파일이라도 5개 룰 검증이 10초 안에 완료되어야 함 (200줄 파일 기준 수 ms로 충분).
- **C3 — JSON I/O 계약 준수**: stdin = Claude Code의 PostToolUse hook input (`tool_name`, `tool_input`, etc.), stdout = `{"systemMessage": "..."}` 또는 `{}`. parse 실패 시 `{}` exit 0 (graceful degradation).
- **C4 — Path traversal 방지**: `tool_input.file_path`를 `os.path.realpath`로 정규화한 뒤 `CLAUDE_PROJECT_DIR` 하위인지 확인. 밖이면 즉시 skip.
- **C5 — Symlink 처리**: `CLAUDE.md → AGENTS.md` symlink는 정상 (R-pointer가 권장하는 형태). hook은 `os.path.islink`로 감지하고 R-pointer 룰을 통과시킴. 그 외 룰은 symlink target에 적용.
- **C6 — Kill switch는 보안 컨트롤 (devbrew CLAUDE.md §Plugin Shape)**: 어떤 위반이 발견됐든 kill switch가 active면 무조건 `{}` exit. 우회 로직 금지.
- **C7 — Cross-plugin coupling 명시**: README "Hooks Installed"에 두 번째 hook의 한 줄 justification + kill switch 문서화. 의존 플러그인 없음 (standalone).

## Acceptance Criteria

### Hook 동작

- **AC1 — `docs-lint.py` 신설**: `plugins/project-init/hooks/docs-lint.py`가 `Write`/`Edit`/`MultiEdit` PostToolUse 이벤트를 받아 `tool_input.file_path`가 다음 4개 중 하나일 때만 검사를 수행한다 — `CLAUDE.md`, `AGENTS.md`, `.claude/CLAUDE.md`, `.claude/AGENTS.md` (모두 `CLAUDE_PROJECT_DIR` 기준 상대 경로 비교 후 절대 경로 normalize).
- **AC2 — 다른 파일 no-op**: 검사 대상 외 파일은 `{}` 즉시 반환, exit 0.
- **AC3 — Hook 등록**: `plugins/project-init/hooks/hooks.json`이 기존 `post-tool-use.py` entry는 그대로 두고 새 entry 추가 — matcher `Write|Edit|MultiEdit`, command `python3 ${CLAUDE_PLUGIN_ROOT}/hooks/docs-lint.py`, timeout 10.
- **AC4 — Kill switch 준수**: `DEVBREW_DISABLE_PROJECT_INIT=1` 또는 `DEVBREW_SKIP_HOOKS`에 `project-init:docs-lint`가 포함되면 즉시 `{}` exit. 기존 `post-tool-use.py`와 동일한 `kill_switch_active()` 함수 패턴 재사용 (코드 복제 OK — 두 hook 격리 유지).
- **AC5 — Worktree-safe**: `CLAUDE_PROJECT_DIR`가 worktree root를 가리킬 때 정상 동작. `.git/worktrees/**` 경로 (절대 경로 substring `os.sep + ".git" + os.sep + "worktrees" + os.sep` 포함) 는 즉시 skip.
- **AC6 — JSON 실패 graceful**: stdin이 valid JSON 아니면 `{}` exit 0 (stderr로 한 줄 log).

### 룰 R1 — Size

- **AC7 — Warn at 200**: 검사 대상 파일의 줄 수 (`\n` 카운트, 마지막 줄 포함)가 **200을 초과**하면 systemMessage에 `"project-init: <relpath> is <N> lines. Anthropic recommends ≤200. Move detailed content to docs/** and link from here."` 추가. 200 정확히는 통과.
- **AC8 — Strong warn at 300**: 줄 수 > **300**이면 동일 메시지에 `(STRONG: >300 lines means agent will likely truncate)` 접미사. AC7의 메시지 자체는 변경하지 않고 접미사만 append.

### 룰 R2 — TOC

- **AC9 — TOC required if >300 lines**: 줄 수 > 300 AND 파일 본문에 정규식 `^##\s+(목차|Table of Contents|Contents)\s*$` (다중라인 모드)이 매치 안 되면 `"project-init: <relpath> exceeds 300 lines without a TOC section. Add \"## 목차\" or \"## Table of Contents\" near the top."` 추가.
- **AC10 — TOC 위치 자유**: TOC는 파일 어디에 있어도 통과 (`near the top` 권장은 메시지에만, 검증은 위치 무관).

### 룰 R5 — Fenced code language

- **AC11 — Bare fence 검출 (stateful walk)**: 파일을 행 단위로 순회하며 `in_fence: bool` 상태를 유지한다. 행이 정규식 `^ {0,3}` ` ``` ` `(\S*)\s*$`에 매치되면 fence toggle 라인이다. `in_fence`가 False였다면 *opening fence* — capture group이 빈 문자열이면 위반. `in_fence`가 True였다면 *closing fence* — 검사 안 함 (close는 의도적으로 빈 ` ``` `). 어느 쪽이든 `in_fence`를 toggle. 위반 시 `"project-init: <relpath>:L<n> has a fenced code block without a language tag. Add the language (e.g. \"```bash\")."` 추가. 다중 위반은 줄 번호 모두 나열 (e.g. `:L23, L57, L102`).
- **AC12 — Fence in indented code 무시**: 행 시작 공백이 4칸 이상이면 markdown indented code block이라 fence 룰 적용 안 함 (정규식 `^ {0,3}` ` ``` ` 매치).

### 룰 R6 — Internal links resolve

- **AC13 — Relative link 검사**: 정규식 `\[([^\]]+)\]\(([^)]+)\)`로 모든 markdown link 추출. target이 정규식 `^[a-z][a-z0-9+.-]*:`에 매치되면 URL scheme (`http://`, `https://`, `mailto:`, `tel:`, `ftp:`, custom 등 모두) 으로 보고 skip. `#anchor`로 시작해도 skip (같은 파일 내 anchor 검증은 NG4와 충돌하므로 안 함). 나머지는 `target`의 `#fragment`를 strip한 뒤 `os.path.join(os.path.dirname(file_path), <stripped>)` → `os.path.realpath` → `os.path.exists` 검증.
- **AC14 — 위반 메시지**: 미해결 링크가 있으면 `"project-init: <relpath> has <N> unresolved internal link(s): [target1, target2, ...]"`. 최대 5개까지 나열, 초과 시 `... and M more` 접미사.
- **AC15 — Realpath escape 금지**: `realpath`이 `CLAUDE_PROJECT_DIR` 밖으로 escape하는 링크는 *외부 참조*로 보고 skip (C4와 일관).

### 룰 R-pointer — CLAUDE/AGENTS drift

- **AC16 — Drift 조건**: `CLAUDE_PROJECT_DIR`에 `CLAUDE.md` AND `AGENTS.md`가 둘 다 존재하면 다음 중 하나 만족해야 통과:
  1. `CLAUDE.md`가 symlink고 target == `AGENTS.md` (또는 `./AGENTS.md`), OR
  2. `CLAUDE.md`의 strip된 본문 (whitespace·주석 제외)이 정확히 `@AGENTS.md`.
- **AC17 — 위반 메시지**: 위 조건 미충족 시 `"project-init: Both CLAUDE.md and AGENTS.md exist with divergent content (drift risk). Make CLAUDE.md contain just \"@AGENTS.md\" or symlink it: \`ln -sf AGENTS.md CLAUDE.md\`"`.
- **AC18 — `.claude/CLAUDE.md`도 동일 검사**: 단 짝은 `.claude/AGENTS.md`. 두 위치 (root와 `.claude/`)는 독립 검사.

### 메시지 합성

- **AC19 — 다중 위반 합성**: 한 파일에 여러 룰 위반이면 한 `systemMessage`에 모두 합쳐 출력. 각 룰의 메시지를 `\n\n`로 구분. 위반 없으면 `{}` exit 0.

### `/project-init` command 갱신

- **AC20 — AGENTS.md primary**: `commands/project-init.md` Step 4가 strategy 선택 후 **항상 두 파일을 생성**:
  - `AGENTS.md`: 기존 `claude-md-section.md` template content가 들어가는 canonical 파일. `## LLM Coding Guidelines`와 `## Git Workflow` 섹션 포함.
  - `CLAUDE.md`: 한 줄 `@AGENTS.md`만 (UTF-8, trailing newline).
- **AC21 — 기존 CLAUDE.md migration**: Step 1에서 `CLAUDE.md`가 발견되면 사용자에게 묻는다 — *"기존 CLAUDE.md 발견. AGENTS.md로 migrate할까요? (CLAUDE.md는 `@AGENTS.md` thin pointer로 교체됩니다)"*. 거절하면 중단 (기존 동작과 일관).
- **AC22 — 4-state matrix 갱신**: 기존 Step 4c의 4-state matrix가 `AGENTS.md`를 primary로 다루도록 재작성. CLAUDE.md는 `@AGENTS.md` 한 줄 보장만 책임.
- **AC23 — Step 5 confirmation 갱신**: 보고 메시지에 *"AGENTS.md (canonical) + CLAUDE.md (`@AGENTS.md` thin pointer) 생성"* 명시.

### Template 정리

- **AC24 — Template rename**: `templates/<strategy>/claude-md-section.md` (3개 strategy) → `templates/<strategy>/agents-md-section.md`로 rename. 내용 변경 없음. git mv 사용 (history 보존).
- **AC25 — 신규 thin pointer template**: `templates/shared/claude-md-pointer.md` 신설, 내용은 `@AGENTS.md\n` 한 줄.

### 메타데이터·문서

- **AC26 — plugin.json bump**: `version`: `1.3.0` → `1.4.0`.
- **AC27 — CHANGELOG 갱신**: `## [1.4.0] — 2026-05-17` entry, sections:
  - **Added**: `hooks/docs-lint.py` (R1/R2/R5/R6/R-pointer); `templates/shared/claude-md-pointer.md`; `hooks/tests/` 디렉토리.
  - **Changed**: `commands/project-init.md` Step 4가 AGENTS.md primary + CLAUDE.md thin pointer 생성; `templates/<strategy>/claude-md-section.md` → `agents-md-section.md` rename.
- **AC28 — README 갱신**:
  - Architecture tree에 `docs-lint.py`와 신규 template 추가.
  - "Hooks Installed" 섹션에 두 번째 hook 한 줄 ("PostToolUse Write/Edit/MultiEdit matcher — agent-readable docs convention 검증") + kill switch 문서화 (`DEVBREW_SKIP_HOOKS=project-init:docs-lint`).
  - "Principles Instantiated"에 Law 1 (Clarity Before Code) 한 줄 추가 — *agent-readable docs convention enforcement (size, TOC, fenced lang, links, no drift)*.
  - "동작 방식" 섹션 step 4가 AGENTS.md + CLAUDE.md 둘 다 생성으로 갱신.

### 테스트

- **AC29 — Unit test 디렉토리**: `plugins/project-init/hooks/tests/test_docs_lint.py` (Python stdlib `unittest`) 신설. fixtures는 `plugins/project-init/hooks/tests/fixtures/`.
- **AC30 — Per-rule 테스트**: R1/R2/R5/R6/R-pointer 각 룰마다 최소 1 happy + 1 violation 케이스. R1/R2는 size threshold boundary (200, 201, 300, 301) 모두 cover.
- **AC31 — Kill switch 테스트**: `DEVBREW_DISABLE_PROJECT_INIT=1`과 `DEVBREW_SKIP_HOOKS=project-init:docs-lint` 두 경로 모두 `{}` exit 검증.
- **AC32 — Symlink 테스트**: `CLAUDE.md`가 `AGENTS.md` symlink인 경우 R-pointer 통과 검증 (`tempfile.TemporaryDirectory` + `os.symlink`).
- **AC33 — Worktree path 테스트**: `.git/worktrees/wt1/CLAUDE.md` 같은 경로가 검사 스킵되는지 검증.
- **AC34 — Invalid JSON 테스트**: stdin이 invalid면 `{}` exit 0 검증.

## Files to Create / Modify

### 신규 (Create)

- `plugins/project-init/hooks/docs-lint.py` — ~250줄 예상, 5개 룰 검증 로직
- `plugins/project-init/hooks/tests/__init__.py` — 빈 파일 (test discovery)
- `plugins/project-init/hooks/tests/test_docs_lint.py` — ~300줄 예상, 모든 AC 검증
- `plugins/project-init/hooks/tests/fixtures/valid_agents.md` — happy path
- `plugins/project-init/hooks/tests/fixtures/oversized.md` — 201 줄
- `plugins/project-init/hooks/tests/fixtures/strong_oversized.md` — 301 줄
- `plugins/project-init/hooks/tests/fixtures/missing_toc.md` — 350 줄, TOC 없음
- `plugins/project-init/hooks/tests/fixtures/bare_fence.md` — fence 언어 누락
- `plugins/project-init/hooks/tests/fixtures/broken_link.md` — 미해결 링크
- `plugins/project-init/hooks/tests/fixtures/drifted_claude.md` — drift 케이스
- `plugins/project-init/hooks/tests/fixtures/proper_claude_pointer.md` — `@AGENTS.md` 한 줄
- `plugins/project-init/templates/shared/claude-md-pointer.md` — `@AGENTS.md\n`

### 변경 (Modify)

- `plugins/project-init/.claude-plugin/plugin.json` — `version` `1.3.0` → `1.4.0`
- `plugins/project-init/hooks/hooks.json` — PostToolUse에 두 번째 entry 추가 (matcher `Write|Edit|MultiEdit`)
- `plugins/project-init/commands/project-init.md` — Step 4 전반 갱신 (AC20, AC21, AC22, AC23)
- `plugins/project-init/CHANGELOG.md` — `[1.4.0] — 2026-05-17` entry prepend
- `plugins/project-init/README.md` — Architecture tree, Hooks Installed, Principles Instantiated, 동작 방식 갱신

### Rename (git mv)

- `plugins/project-init/templates/github-flow/claude-md-section.md` → `agents-md-section.md`
- `plugins/project-init/templates/git-flow/claude-md-section.md` → `agents-md-section.md`
- `plugins/project-init/templates/trunk-based/claude-md-section.md` → `agents-md-section.md`

## Verification Plan

### 자동 검증

- **V1 — Unit tests pass**: `cd plugins/project-init && python3 -m unittest discover hooks/tests -v` 모두 통과. AC29–AC34 직접 cover.
- **V2 — Hook manual smoke test**: 임시 디렉토리에 fixture 복사 후 `echo '{"tool_name":"Write","tool_input":{"file_path":"<path>"}}' | CLAUDE_PROJECT_DIR=<dir> python3 hooks/docs-lint.py`로 각 룰의 systemMessage 형태 육안 검증.
- **V3 — Kill switch smoke**: `DEVBREW_DISABLE_PROJECT_INIT=1 echo '...' | python3 hooks/docs-lint.py` 가 `{}` 출력 확인.
- **V4 — Existing hook 회귀 없음**: 기존 `post-tool-use.py` 테스트 (없으면 manual: `git checkout -b feature/foo`로 branch 검증 발화 확인) 정상.

### Plugin Shape 검증

- **V5 — plugin-validator agent**: `plugin-dev:plugin-validator` agent로 `plugins/project-init/` 검증 — 1.4.0 bump, CHANGELOG entry, README 동기화 confirm.
- **V6 — Skill-reviewer agent** (optional): 신규 hook이 skill로 잘못 분류되지 않는지 (hook이 맞음을 README "Hooks Installed" justification으로 명시).

### 통합 시나리오

- **V7 — `/project-init` 신규 프로젝트**: 빈 디렉토리에서 `/project-init` 실행 → AGENTS.md (full content) + CLAUDE.md (`@AGENTS.md` 한 줄) 둘 다 생성 확인. AC20, AC23.
- **V8 — `/project-init` migration**: 기존 CLAUDE.md만 있는 디렉토리에서 `/project-init` 실행 → migration prompt → AGENTS.md로 content 이전, CLAUDE.md는 thin pointer로 교체. AC21.
- **V9 — Hook 발화 통합**: `/project-init` 실행 직후 AGENTS.md를 Edit으로 줄 추가해 201줄로 만들면 R1 systemMessage가 즉시 나타나는지 확인. AC7.

### 워크트리 시나리오

- **V10 — Worktree-safe**: `git worktree add ../wt1 feature/x`로 worktree 생성 후 그 안에서 AGENTS.md 편집 시 hook이 worktree root 기준 정상 발화. AC5.
- **V11 — `.git/worktrees/**` skip**: 실제 git 내부 metadata 디렉토리에 마크다운 파일을 임의로 두면 검사 스킵 확인. AC5.

## Rejected Alternatives

- **RA1 — PreToolUse blocking hook (Approach B)**: 위반을 디스크에 도달 못 하게 하나, Anthropic best-practice의 *"correcting-over-and-over"* anti-pattern 직접 유발. devbrew 표준 (qg reviewer, 기존 post-tool-use.py 모두 advisory)에서 이탈. 브레인스토밍에서 사용자가 명시적 거부.
- **RA2 — SessionStart baseline + PostToolUse incremental (Approach C)**: 매 세션 시작 시 noise 발생. devbrew CLAUDE.md *"`SessionStart` 훅은 read-only 조언자"* 룰은 통과하나 discoverability vs noise tradeoff 나쁨. 거부.
- **RA3 — `docs/**/*.md` 룰 동시 출시**: 사용자가 scope를 *"Root context 파일"*로 명시 선택. false-positive 위험 + 룰 ownership 분산 우려. Future PR로 분리.
- **RA4 — CLAUDE.md를 canonical 유지**: 기존 동작 변경 없으나 Codex/Cursor 등 16+ 벤더 호환 손해. AGENTS.md primary가 cross-vendor reach + Anthropic 권장 패턴 둘 다 만족.
- **RA5 — 두 파일 모두 생성 + content 동기 검증**: source of truth 2개 → MAST 명세 모호성 진입 위험. Thin pointer (1 source) 채택.
- **RA6 — `revert`/`refactor` 같은 추가 룰 (R7–R10) 포함**: 사용자가 *"High-confidence 코어만"* 선택. 후속 PR 여지로 보존.
- **RA7 — PyYAML로 frontmatter parse**: stdlib only 정책 위반 (C1). 정규식 (`^---\n(.*?)\n---\n`)으로 충분.
- **RA8 — `lychee`/`markdown-link-check` CLI 호출**: 외부 의존성 도입. devbrew 패턴 (`post-tool-use.py`가 stdlib만 사용) 이탈. `os.path.exists`로 internal link만 검사하면 R6 의도 충족.
- **RA9 — Hook이 자동 fix (e.g. fence 언어 자동 추론, TOC 자동 생성)**: NG7 — devbrew 룰 *"SessionStart는 read-only 조언자"* 정신 위반, mutation은 위험. 사용자가 systemMessage 보고 수동 수정.

## Metadata

- **Plugin**: `plugins/project-init/`
- **Version target**: `1.4.0` (minor — 새 surface 추가, 기존 동작은 backward-compatible)
- **Breaking changes**: 없음 — 기존 사용자에게 추가 hook은 advisory only, `/project-init`의 AGENTS.md migration도 명시적 confirmation 필요
- **Dependencies**: 없음 (stdlib only, cross-plugin 의존 없음)
- **Spawned subagents** (브레인스토밍 단계): 3 × `general-purpose` (Anthropic 공식 / AGENTS.md 스펙·Codex/Cursor/Aider / 경험적 findings) — 모두 완료
- **Estimated implementation**: hook ~250줄, test ~300줄, command/README/CHANGELOG 갱신 ~50줄 diff, template rename 3건. 단일 PR 권장.
- **Estimated review surface**: medium (신규 hook 1개 + command 변경 + template rename + 메타데이터 — qg 풀 파이프라인 권장).
