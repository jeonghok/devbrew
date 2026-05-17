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
- §9 [Rejected Alternatives](#rejected-alternatives) — §9.0 Adopted Approach / §9.1 Rejected
- §10 [Metadata](#metadata)

## Goal

`plugins/project-init/`에 **(a)** root context 파일(`CLAUDE.md`/`AGENTS.md`/`.claude/CLAUDE.md`/`.claude/AGENTS.md`)의 agent-readable convention 5개 (size, TOC, fenced lang, links resolve, CLAUDE/AGENTS drift)를 PostToolUse advisory로 검증하는 `docs-lint.py` hook을 신설하고, **(b)** `/project-init` command가 AGENTS.md를 canonical content source로 작성하면서 CLAUDE.md를 `@AGENTS.md` 한 줄 thin pointer로 발행하도록 갱신한다. 두 변경을 한 PR (v1.4.0)로 동시 출시.

**Coupling 근거 (왜 단일 PR인가)**: 두 변경은 독립 배포 시 chicken-and-egg failure를 일으킨다. (a) hook만 먼저 깔면 기존 사용자 환경에는 CLAUDE.md만 존재 (AGENTS.md 없음) → R-pointer 룰의 두 파일 동시 존재 조건이 false → drift 검사가 영원히 발화 안 함, hook의 의도된 보호 효과 0. (b) command 변경만 먼저 출시하면 신규 `/project-init` 실행 결과물 (AGENTS.md + thin pointer CLAUDE.md) 이 어떤 룰로도 검증되지 않아 thin pointer가 사람 손에 의해 다시 full content로 drift할 위험 무방비. 둘을 한 PR로 묶어야 R-pointer가 의도대로 작동하는 *살아있는 baseline* 이 동시에 만들어진다. 롤백 단위 (`git revert <pr-merge-sha>`) 도 단일 commit이 되어 단순.

## Context / Why

devbrew는 Claude Code 플러그인 마켓플레이스로서 *agent가 읽는 문서*를 다루는 플러그인이 다수 존재하나, **"agent가 읽기 좋은 문서가 무엇인가"** 라는 메타-룰은 어디에도 없다. `project-init`은 이미 타깃 프로젝트의 `CLAUDE.md`와 `docs/git-workflow/`를 생성·검증하는 도메인을 가지고 있으므로 (v1.3.0의 `post-tool-use.py`가 branch·commit을 advisory로 검증), 자연스러운 확장 위치.

브레인스토밍 세션에서 3개 독립 리서치 에이전트가 다음을 강하게 수렴 확인:

1. **Anthropic 공식 가이드 ([code.claude.com/docs/en/memory.md], [code.claude.com/docs/en/best-practices])**: *"target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence."* "The over-specified CLAUDE.md" 를 명시적 anti-pattern으로 cite. `MEMORY.md`는 200줄 / 25 KB threshold에서 truncate.
2. **AGENTS.md 오픈 스펙 ([agents.md](https://agents.md/))**: 60k+ 레포 채택, 16+ 벤더 (OpenAI Codex, Google Jules, Cursor, Aider, GitHub Copilot, Gemini CLI, JetBrains Junie, Windsurf 등). OpenAI Codex는 `project_doc_max_bytes` = **32 KiB** hard cap, root→leaf concat 후 cap 도달 시 truncate.
3. **경험적 데이터**: Chroma 2025 *Context Rot* (18 frontier 모델 모두 input length에 monotonic degradation, *logically-coherent haystack이 shuffled보다 worse*), Lost-in-the-Middle (Liu 2023, U자형 accuracy curve), MDEval WWW'25 (markdown structure awareness benchmark), MAST taxonomy (Cemri 2025, 명세 모호성이 multi-agent failure의 41–86.7%). 커뮤니티 측정: CLAUDE.md가 11k–42k 토큰을 매 턴 소비하던 사례 → 500–1500 토큰으로 축소해도 instruction-following 손실 없음.

3개 리서치의 교집합에서 *deterministic하게 검증 가능한* 룰만 추출하면 10개 후보가 나오나, v1 출시 범위는 사용자 선택으로 **High-confidence 코어 5개** + **AGENTS.md/CLAUDE.md drift 검출 1개**로 한정 — false-positive를 최소화하고 점진적으로 확장.

또한 사용자 결정으로 **AGENTS.md를 canonical**, **CLAUDE.md를 `@AGENTS.md` thin pointer**로 채택. 이유: (a) AGENTS.md를 자동 인식하는 벤더가 16+로 Claude Code 단독 인식의 CLAUDE.md보다 reach가 크고, (b) Anthropic 자체도 *"import AGENTS.md via `@AGENTS.md` or symlink"* 패턴 권장, (c) source of truth 1개로 drift 위험 제거 (MAST 명세 모호성 회피).

## Goals

- **G1 — Root context 파일 5개 룰 강제**: 검사 대상 파일 — `CLAUDE.md`, `AGENTS.md`, `.claude/CLAUDE.md`, `.claude/AGENTS.md` (4개, AC1과 동일). 룰: R1 (size ≤200줄 warn, >300 strong warn), R2 (TOC required if >300줄), R5 (fenced code block에 언어 태그 필수), R6 (internal markdown link resolves), R-pointer (CLAUDE.md ↔ AGENTS.md drift 검출).
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
- **AC4 — Kill switch 준수**: `DEVBREW_DISABLE_PROJECT_INIT=1` 또는 `DEVBREW_SKIP_HOOKS`에 정확히 토큰 **`project-init:docs-lint`** (대소문자 정확 일치, 콤마 split 후 strip한 결과)가 포함되면 즉시 `{}` exit. 기존 `post-tool-use.py:149-154`의 `kill_switch_active()` 함수를 그대로 복사하되 line 154의 `"project-init:post-tool-use"` 하드코딩 문자열만 `"project-init:docs-lint"`로 교체 — 두 hook은 토큰만 다른 독립 인스턴스. G5와 AC4가 같은 토큰을 가리킴을 명시.
- **AC5 — Worktree-safe**: `CLAUDE_PROJECT_DIR`가 worktree root를 가리킬 때 정상 동작. `.git/worktrees/**` 경로 (절대 경로 substring `os.sep + ".git" + os.sep + "worktrees" + os.sep` 포함) 는 즉시 skip.
- **AC6 — JSON 실패 graceful**: stdin이 valid JSON 아니면 `{}` exit 0 (stderr로 한 줄 log).

### 룰 R1 — Size

- **AC7 — Warn at 200**: 검사 대상 파일의 줄 수 (`\n` 카운트, 마지막 줄 포함)가 **200을 초과**하면 R1은 정확히 *한 줄의 systemMessage*를 emit한다. 200 < lines ≤ 300 구간 메시지: `"project-init: <relpath> is <N> lines. Anthropic recommends ≤200. Move detailed content to docs/** and link from here."` 그대로. 200 정확히는 통과 (R1 발화 안 함).
- **AC8 — Strong warn at 300**: 줄 수 > **300**이면 AC7의 메시지 *대신* 다음 한 줄을 emit한다 (중복 emit 안 함, 단일 R1 메시지): `"project-init: <relpath> is <N> lines. Anthropic recommends ≤200. Move detailed content to docs/** and link from here. (STRONG: >300 lines means agent will likely truncate)"`. 즉 base 메시지 + suffix 한 문장으로 합성된 단일 string.

### 룰 R2 — TOC

- **AC9 — TOC required if >300 lines**: 줄 수 > 300 AND 파일 본문에 정규식 `^##\s+(목차|Table of Contents|Contents)\s*$` (Python `re.MULTILINE` flag — `^`/`$`가 각 라인의 시작/끝에 매치) 이 매치 안 되면 `"project-init: <relpath> exceeds 300 lines without a TOC section. Add \"## 목차\" or \"## Table of Contents\" near the top."` 추가.
- **AC10 — TOC 위치 자유**: TOC는 파일 어디에 있어도 통과 (`near the top` 권장은 메시지에만, 검증은 위치 무관).

### 룰 R5 — Fenced code language

- **AC11 — Bare fence 검출 (stateful walk, 3-backtick only)**: 파일을 행 단위로 순회하며 `in_fence: bool` 상태를 유지한다. **정확히 3개**의 backtick (`` ``` ``)을 갖는 fence만 본 룰의 검사 대상이다 — 정규식 (Python raw string 표기): `r"^ {0,3}`{3}(\S*)\s*$"`. **Scope-outs (v1.4.0 false-negative 허용)**: (a) CommonMark §4.5의 4+ backtick (`` ```` ``, `` ````` ``) 또는 tilde fence (`~~~`) — 구현 단순화, 실제 사용 빈도 낮음. (b) Space-separated info string (예: `` ``` bash `` 처럼 backtick 직후 공백 + 언어명) — `\S*` 패턴은 space를 매치 안 하므로 미감지 (false-negative). CommonMark는 허용하지만 일반 컨벤션은 `` ```bash ``로 공백 없음. 위 모두 Future PR로 분리. 매치된 라인 처리: `in_fence == False`였다면 *opening fence* — capture group이 빈 문자열이면 위반 (L<n> 기록). `in_fence == True`였다면 *closing fence* — 검사 안 함 (close는 의도적으로 빈 `` ``` ``). 어느 쪽이든 `in_fence` toggle. 위반 메시지 (count + 목록 패턴, AC14와 동일 스타일): 단일 위반 시 `"project-init: <relpath> has 1 fenced code block without a language tag at line L<n>. Add the language (e.g. \"` `` ` `bash\")."`. 다중 위반 시 `"project-init: <relpath> has <N> fenced code blocks without language tags at lines [L<n1>, L<n2>, ...]. Add the language (e.g. \"` `` ` `bash\")."` — 최대 5개까지 라인 번호 나열, 초과 시 `... and M more` 접미사.
- **AC12 — Fence in indented code 무시**: 행 시작 공백이 4칸 이상이면 markdown indented code block이라 fence 룰 적용 안 함 (위 정규식의 `^ {0,3}` prefix가 이미 처리).

### 룰 R6 — Internal links resolve

- **AC13 — Relative link 검사**: 정규식 `\[([^\]]+)\]\(([^)]+)\)`로 모든 markdown link 추출. target이 정규식 `^[a-z][a-z0-9+.-]*:`에 매치되면 URL scheme (`http://`, `https://`, `mailto:`, `tel:`, `ftp:`, custom 등 모두) 으로 보고 skip. `#anchor`로 시작해도 skip — 근거: same-file anchor 검증은 heading 파서 + slug 변환 로직이 필요해 C1 (stdlib only) 정신에 부담 + R6의 *internal link* 의도 (파일 존재 여부) 와 결이 다름. 별도 PR로 분리 가능 (R6.5 후보). 나머지는 `target`의 `#fragment`를 strip한 뒤 `os.path.join(os.path.dirname(file_path), <stripped>)` → `os.path.realpath` → `os.path.exists` 검증.
- **AC14 — 위반 메시지**: 미해결 링크가 있으면 `"project-init: <relpath> has <N> unresolved internal link(s): [target1, target2, ...]"`. 최대 5개까지 나열, 초과 시 `... and M more` 접미사.
- **AC15 — Realpath escape 금지**: `realpath`이 `CLAUDE_PROJECT_DIR` 밖으로 escape하는 링크는 *외부 참조*로 보고 skip (C4와 일관).

### 룰 R-pointer — CLAUDE/AGENTS drift

- **AC16 — Drift 조건**: `CLAUDE_PROJECT_DIR`에 `CLAUDE.md` AND `AGENTS.md`가 둘 다 존재하면 다음 중 하나 만족해야 통과:
  1. `CLAUDE.md`가 symlink고 `os.readlink` 결과가 `AGENTS.md` 또는 `./AGENTS.md`, OR
  2. `CLAUDE.md`의 *정규화된 본문* (아래 정의)이 정확히 문자열 `@AGENTS.md`.

  **정규화 절차** (순서대로 적용 — 이 순서는 frontmatter 정규식이 HTML 주석에 의해 오작동하는 것을 방지하기 위해 유지해야 한다; 리팩터링 시 (1)→(2) 순서 변경 금지):
  1. YAML frontmatter 제거: 파일이 `---\n`으로 시작하면 다음 closing `---`까지의 블록 전체 제거. 정규식 `^---\n.*?\n---(?:\n|$)` (re.DOTALL) — closing `---` 뒤 trailing newline이 없는 EOF 케이스도 매치 (표준 텍스트 편집기 케이스 모두 커버).
  2. HTML 주석 제거: `<!--.*?-->` 모든 매치 제거 (re.DOTALL — 다중 라인 주석 포함). frontmatter가 (1)에서 이미 제거됐으므로 frontmatter 내 `<!-- -->`가 정규식 boundary를 망가뜨릴 위험 없음.
  3. `str.strip()` — leading/trailing whitespace 모두 제거.

  정규화 후 결과가 정확히 `@AGENTS.md` (대소문자 정확, trailing newline 무관) 이면 통과. 그 외 모든 경우 (frontmatter + `@AGENTS.md` + 추가 본문, `@AGENTS.md` + 코드 주석 외 텍스트 등) 위반.
- **AC17 — 위반 메시지**: 위 조건 미충족 시 `"project-init: Both CLAUDE.md and AGENTS.md exist with divergent content (drift risk). Make CLAUDE.md contain just \"@AGENTS.md\" or symlink it: \`ln -sf AGENTS.md CLAUDE.md\`"`.
- **AC18 — `.claude/CLAUDE.md`도 동일 검사**: 단 짝은 `.claude/AGENTS.md`. 두 위치 (root와 `.claude/`)는 독립 검사.
- **AC18.5 — R-pointer trigger 양방향**: AC1에 열거된 4개 파일 (CLAUDE.md / AGENTS.md / .claude/CLAUDE.md / .claude/AGENTS.md) 중 *어느 것이라도* Write/Edit/MultiEdit 시 해당 짝의 R-pointer를 검사한다. 즉 AGENTS.md 편집 시에도 같은 디렉토리의 CLAUDE.md drift 여부를 확인. 한 방향만 검사하면 AGENTS.md 수정으로 인한 drift가 영원히 감지 안 됨 — 양방향 trigger로 R-pointer의 cover를 완전화. **짝 파일 worktree check**: R-pointer가 짝 파일을 읽을 때, 짝 파일의 절대 경로에도 AC5의 `.git/worktrees/**` skip 조건을 적용 (직접 trigger된 파일과 짝 파일 모두 git 내부 메타 경로에 있다면 R-pointer skip). C4의 `CLAUDE_PROJECT_DIR` 하위 escape 금지도 동일하게 짝 파일에 적용.

### 메시지 합성

- **AC19 — 다중 위반 합성**: 한 파일에 여러 룰 위반이면 한 `systemMessage`에 모두 합쳐 출력. 각 룰의 메시지를 `\n\n`로 구분. 위반 없으면 `{}` exit 0.

### `/project-init` command 갱신

- **AC20 — AGENTS.md primary**: `commands/project-init.md` Step 4가 strategy 선택 후 **항상 두 파일을 생성**:
  - `AGENTS.md`: 기존 `claude-md-section.md` template content가 들어가는 canonical 파일. `## LLM Coding Guidelines`와 `## Git Workflow` 섹션 포함.
  - `CLAUDE.md`: 한 줄 `@AGENTS.md`만 (UTF-8, trailing newline).
- **AC21 — 기존 CLAUDE.md migration**: Step 1에서 `CLAUDE.md`가 발견되면 사용자에게 묻는다 — *"기존 CLAUDE.md 발견. AGENTS.md로 migrate할까요? (CLAUDE.md는 `@AGENTS.md` thin pointer로 교체됩니다)"*. 사용자 거절 시: **전체 `/project-init` 실행 abort** — Step 2 이후의 docs/git-workflow/ 생성도 skip (기존 Step 1의 *"기존 git workflow 룰 감지 + 사용자 거절 → 중단"*과 동일 시맨틱). 부분 진행 (CLAUDE.md 유지 + docs/만 생성) 금지.
- **AC22 — 4-state matrix 갱신**: 기존 Step 4c의 단일-파일 5-state matrix를 *AGENTS.md × CLAUDE.md 2축 4-state matrix*로 재작성. 검사 대상은 root `AGENTS.md`와 root `CLAUDE.md` 두 파일의 (존재 + 상태) 조합:

  | State | AGENTS.md | CLAUDE.md | Action |
  |---|---|---|---|
  | **S1 (clean slate)** | 없음 | 없음 | AGENTS.md 신규 작성 (full content); CLAUDE.md 신규 작성 (`@AGENTS.md` 한 줄). |
  | **S2 (CLAUDE-only legacy)** | 없음 | 존재 | AC21 migration 프롬프트 → 승인 시 *CLAUDE.md content type 분기 — AC16의 정규화 절차 (frontmatter strip → HTML comment strip → str.strip()) 를 그대로 준용해 분류*: (S2a) 정규화 결과가 `@AGENTS.md` 가 아니면 full content — (a) `## LLM Coding Guidelines`/`## Git Workflow` 섹션 추출, (b) AGENTS.md로 이전·새 template과 merge, (c) CLAUDE.md를 `@AGENTS.md` 한 줄로 교체. (S2b) 정규화 결과가 정확히 `@AGENTS.md` 인 thin pointer (dangling — AGENTS.md 부재) — 추출 불가, 새 template만으로 AGENTS.md 신규 작성, CLAUDE.md는 unchanged (이미 thin pointer). 거절 시 AC21에 따라 abort. |
  | **S3 (AGENTS canonical, CLAUDE pointer)** | 존재 | 존재 + `@AGENTS.md` (R-pointer 통과) | AGENTS.md의 `## LLM Coding Guidelines`/`## Git Workflow` 섹션만 in-place로 갱신 (기존 §Step 4c의 in-place 패턴 적용). CLAUDE.md는 건드리지 않음. |
  | **S4 (AGENTS exists, CLAUDE divergent or absent)** | 존재 | 없음 또는 존재 + divergent content | 사용자에게 advisory + 두 옵션 제시 — (i) CLAUDE.md를 `@AGENTS.md` 한 줄로 *재작성* (AGENTS.md 그대로), (ii) abort. 승인 시 (i) 수행 + S3 action 진행. |

  4 state는 *mutually exclusive AND exhaustive*: (a) AGENTS.md 존재 여부 × (b) CLAUDE.md 존재 여부 × (있을 때) thin pointer 여부 = 2×3 = 6 raw combinations. **6→4 압축은 두 곳에서 발생**: (i) S2는 CLAUDE.md content type 두 종류 (full vs thin pointer) 를 *한 state로 묶고 action 내부에서 S2a/S2b 분기*; (ii) S4는 두 raw combination (AGENTS=있음 + CLAUDE=없음, AGENTS=있음 + CLAUDE=divergent) 을 *한 state로 묶음 (두 경우 모두 동일 advisory + 옵션 동작)*. 따라서 raw 6 = S1(1) + S2(2, 압축) + S3(1) + S4(2, 압축). 모든 raw combination이 정확히 한 state에 속함.
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
- `plugins/project-init/hooks/tests/fixtures/` — **서브디렉토리별 layout**: hook은 AC1 정의 상 정확한 4개 파일명 (CLAUDE.md / AGENTS.md / .claude/CLAUDE.md / .claude/AGENTS.md) 만 검사하므로, 각 fixture 케이스를 자체 서브디렉토리에 두고 그 디렉토리를 `CLAUDE_PROJECT_DIR`로 설정 + 내부에 실제 4개 이름 중 하나의 파일 배치. layout:
  - `fixtures/valid/AGENTS.md` — happy path: 100줄 미만 (R1 통과), TOC 없음 (300줄 미만이라 R2 비대상), 모든 fenced code block에 언어 태그 (R5 통과), internal link 0개 또는 모두 같은 디렉토리 파일 가리킴 (R6 통과). 
  - `fixtures/valid/CLAUDE.md` — `@AGENTS.md` 한 줄 (R-pointer 통과 sibling).
  - `fixtures/oversized/AGENTS.md` — 201 줄 (R1 warn at 200 trigger).
  - `fixtures/strong_oversized/AGENTS.md` — 301 줄 (R1 STRONG suffix trigger).
  - `fixtures/missing_toc/AGENTS.md` — 350 줄, TOC 없음 (R2 trigger; R1 STRONG도 동시 trigger).
  - `fixtures/bare_fence/AGENTS.md` — fence 언어 누락 위반 라인 포함.
  - `fixtures/broken_link/AGENTS.md` — 미해결 internal link 포함.
  - `fixtures/drifted/AGENTS.md` + `fixtures/drifted/CLAUDE.md` — 두 파일 동시 존재 + CLAUDE.md가 thin pointer 아님 (R-pointer drift trigger).
  - `fixtures/proper_pointer/AGENTS.md` + `fixtures/proper_pointer/CLAUDE.md` — `@AGENTS.md` 한 줄 정상 case (R-pointer 통과).
  - `fixtures/dangling_pointer/CLAUDE.md` — `@AGENTS.md` 한 줄만, AGENTS.md 의도적 부재 (S2b sub-case 검증용). V2 스크립트는 이 fixture의 target으로 CLAUDE.md를 선택하고 기대값 `{}` — R-pointer는 두 파일 동시 존재 조건이라 trigger 안 함 (no-op 정상). 추후 유지보수자는 이 fixture에 AGENTS.md를 추가하면 안 됨 (S2b의 dangling 의도 파괴).
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
- **V2 — Hook smoke (자동화 가능, golden-output)**: 각 fixture 서브디렉토리를 `CLAUDE_PROJECT_DIR`로 설정하고 그 안의 AGENTS.md (또는 CLAUDE.md) 를 file_path로 넘김 — AC1의 4-파일 제한과 정합. 셸 스크립트:
  ```bash
  FIX=plugins/project-init/hooks/tests/fixtures
  declare -A EXPECT=(
    [valid]="{}"
    [oversized]="systemMessage"
    [strong_oversized]="systemMessage"
    [missing_toc]="systemMessage"
    [bare_fence]="systemMessage"
    [broken_link]="systemMessage"
    [drifted]="systemMessage"
    [proper_pointer]="{}"
    [dangling_pointer]="{}"
  )
  for d in "${!EXPECT[@]}"; do
    target="$FIX/$d/AGENTS.md"
    [ -f "$target" ] || target="$FIX/$d/CLAUDE.md"
    out=$(CLAUDE_PROJECT_DIR="$FIX/$d" \
          python3 plugins/project-init/hooks/docs-lint.py \
          <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$target\"}}")
    expected="${EXPECT[$d]}"
    if [ "$expected" = "{}" ]; then
      [ "$out" = "{}" ] || { echo "FAIL: $d expected {} got $out"; exit 1; }
    else
      echo "$out" | grep -q "$expected" || { echo "FAIL: $d expected $expected got $out"; exit 1; }
    fi
  done
  echo "V2 PASS"
  ```
  CI/local 동일 실행 가능. 육안 검증 아님.
- **V3 — Kill switch smoke (자동화)**: 두 kill switch 경로 모두 `{}` 출력 검증. shell 변수 scoping 정확:
  ```bash
  # 전체 disable
  out1=$(DEVBREW_DISABLE_PROJECT_INIT=1 \
    python3 plugins/project-init/hooks/docs-lint.py \
    <<< '{"tool_name":"Write","tool_input":{"file_path":"plugins/project-init/hooks/tests/fixtures/oversized.md"}}')
  [ "$out1" = "{}" ] || { echo "FAIL: full disable"; exit 1; }
  # hook 단위 opt-out
  out2=$(DEVBREW_SKIP_HOOKS=project-init:docs-lint \
    python3 plugins/project-init/hooks/docs-lint.py \
    <<< '{"tool_name":"Write","tool_input":{"file_path":"plugins/project-init/hooks/tests/fixtures/oversized.md"}}')
  [ "$out2" = "{}" ] || { echo "FAIL: hook opt-out"; exit 1; }
  ```
  env var이 `python3`까지 inherit되도록 *같은 라인*에 배치 (이전 spec의 `echo '...' | python3 ...` 형식은 env var이 `echo`에만 적용되는 shell scoping 오류였음 — 수정).
- **V4 — Existing hook 회귀 없음**: 기존 `post-tool-use.py` 동작 unchanged. 검증: `echo '{"tool_name":"Bash","tool_input":{"command":"git checkout -b feature/Foo_Bar"}}' | CLAUDE_PROJECT_DIR=$(pwd) python3 plugins/project-init/hooks/post-tool-use.py | grep -q "naming convention"` 성공 (v1.3.0 branch validator 정상).

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
- **V12 — Hook matcher harness 지원 확인**: Claude Code harness가 `hooks.json`의 `"matcher": "Write|Edit|MultiEdit"` 표현을 **regex alternation으로 실제 지원**하는지 검증 (기존 `post-tool-use.py`는 단일 값 `"Bash"`만 사용해 검증된 적 없음). 검증 절차: (a) 임시 디렉토리에 hook 등록, (b) `Write`/`Edit`/`MultiEdit` 각 도구를 한 번씩 호출, (c) hook stdout이 매번 발화하는지 stderr/log 확인. 만약 미지원이면 fallback — 3개 entry로 분리 (각각 단일 matcher) 또는 matcher 없이 모든 PostToolUse 받고 hook 내부에서 `tool_name` 분기. AC3 구현 전 *반드시* 확인.

## Rejected Alternatives

### §9.0 — Adopted Approach (for symmetric comparison)

**Approach A — PostToolUse advisory hook**, 채택. 동작: `Write|Edit|MultiEdit` matcher에 신규 `docs-lint.py` 등록 → 검사 대상 파일이면 5개 룰 평가 → 위반 시 `systemMessage` (non-blocking) 출력 → 위반 없으면 `{}`. 채택 근거: (i) 기존 `post-tool-use.py`와 정확히 동일 격리 패턴 — devbrew P15 (plugin coexistence) 준수, kill switch도 동일 메커니즘. (ii) Anthropic best-practice의 *"correcting-over-and-over"* anti-pattern 회피 (RA1 비교). (iii) hooks.json에 한 entry 추가 + Python 한 파일로 완결 — 변경 표면적 최소. (iv) 향후 strict 강제가 필요한 룰 (e.g. version bump 강제) 은 다른 플러그인에서 PreToolUse로 추가 가능 — 본 hook의 advisory 정신은 보존. RA1, RA2와 직접 비교 (브레인스토밍 단계에서 사용자가 3-옵션 중 명시적 A 선택).

### §9.1 — Rejected

- **RA1 — PreToolUse blocking hook (Approach B)**: A vs B의 결정적 차이는 *blocking semantics* — B는 위반 시 도구 실행 자체를 거부해 사용자가 룰 위반된 상태로 디스크에 도달하는 것을 강제 차단한다. A는 advisory라 진행을 허용하고 메시지만 출력. B의 거부 근거 (강한 순서로, 모두 *기술적 근거*): (i) devbrew 표준이 advisory (qg reviewer, 기존 post-tool-use.py 모두). blocking은 사용자가 룰을 *동의*하지 않을 때 escape 경로가 (kill switch 외엔) 없어 작업 흐름을 강제 중단시킴 — devbrew CLAUDE.md *"룰 위반은 advisory로 출력, 결정은 사용자"* 정신 위반. (ii) A도 같은 파일을 반복 edit하면 매번 같은 메시지를 emit하므로 *"correcting-over-and-over"* 자체는 A에도 적용 — 이 anti-pattern은 A/B 변별 근거가 아님 (round 1 § 9.0의 RA1 근거 부정확 수정). 위 (i)(ii) *기술적 근거만으로* B 거부는 결정적. (브레인스토밍에서 사용자가 명시적으로 A를 선택했다는 context는 보조 사실로 기록 — 기술 근거가 결정적이며 사용자 선택은 이를 confirm한 것일 뿐, 향후 사용자 선택이 바뀌어도 (i)(ii)는 그대로 유효.)
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
