# project-init 플러그인

Claude Code용 git workflow 초기화 플러그인. 어떤 프로젝트에든 branching strategy, commit conventions, PR process 룰을 생성한다.

## 아키텍처

```
plugins/project-init/
├── .claude-plugin/plugin.json       # 플러그인 메타데이터
├── README.md                        # 본 파일
├── CHANGELOG.md                     # 변경 이력
├── commands/
│   └── project-init.md              # /project-init — 인터랙티브 셋업
├── hooks/
│   ├── hooks.json                   # PostToolUse hook 설정 (2개 entry)
│   ├── post-tool-use.py             # 브랜치 명명 + 커밋 메시지 검증기 (Bash matcher)
│   ├── docs-lint.py                 # v1.4.0 — agent-readable docs convention 검증 (Write/Edit/MultiEdit matcher)
│   └── tests/
│       ├── test_docs_lint.py        # 60+ Python stdlib unittest (charter rule 포함)
│       ├── smoke.sh                 # V2 자동화 smoke script
│       └── fixtures/                # 13개 서브디렉토리 (valid, oversized, drifted, charter_*, ...)
└── templates/
    ├── shared/
    │   ├── commit-conventions.md
    │   ├── pr-process.md
    │   └── claude-md-pointer.md     # @AGENTS.md 한 줄 thin pointer
    ├── github-flow/
    │   ├── agents-md-section.md
    │   └── branch-strategy.md
    ├── git-flow/
    │   ├── agents-md-section.md
    │   └── branch-strategy.md
    ├── trunk-based/
    │   ├── agents-md-section.md
    │   └── branch-strategy.md
    └── project/                     # v1.6.0 — Project Charter skeletons
        ├── agents-md-section.md     # ## Project Charter 요약
        ├── charter.md               # vision·goals·non-goals·success·personas
        ├── conventions.md           # naming·구조·error·anti-patterns·build&test
        └── glossary.md              # 조건부 도메인 용어집
```

## 동작 방식

1. `/project-init` 실행
2. branching strategy 선택 (GitHub Flow / Git Flow / Trunk-based)
3. 커스터마이징 질문 2–3개 답변 (commit scope, merge strategy)
4. 플러그인이 다음을 생성:
   - `AGENTS.md` — `## Git Workflow` (canonical content source, OpenAI Codex/Cursor/Aider 등 16+ 벤더 자동 인식)
   - `CLAUDE.md` — `@AGENTS.md` 한 줄 thin pointer (Claude Code가 AGENTS.md content를 자동 import)
   - `docs/git-workflow/branch-strategy.md` — 팀의 브랜치 룰
   - `docs/git-workflow/commit-conventions.md` — Conventional Commits 룰
   - `docs/git-workflow/pr-process.md` — PR 템플릿과 리뷰 체크리스트
5. (v1.6.0) charter step — Phase 0가 manifest를 스캔해 tech-stack을 자동 감지하고, Phase 1이 vision·non-goals·conventions·tech-stack 확인을 ≤4개 질문으로 elicit. 결과를 `AGENTS.md ## Project Charter` 요약 + `docs/project/charter.md`·`conventions.md`(+ 조건부 `glossary.md`)로 발행.

## 기능

| 컴포넌트 | 역할 |
|---------|------|
| **`/project-init` command** | 인터랙티브 셋업 — strategy 선택, 룰 생성 |
| **PostToolUse hook** | 브랜치 이름·커밋 메시지 포맷 자동 검증 |
| **Templates** | 3개 branching strategy의 사전 작성된 룰 |

## 브랜치 전략

| Strategy | Branches | Best for |
|----------|----------|----------|
| **GitHub Flow** | `main` + `feature/*` / `fix/*` | 작은 팀, CI/CD, continuous deployment |
| **Git Flow** | `main` + `develop` + `feature/*` / `fix/*` / `release/*` / `hotfix/*` | release cycle, version 관리 |
| **Trunk-based** | `main` + 단명 `feature/*` / `fix/*` | 빠른 배포, feature flag |

## 통합

다른 플러그인과 함께 동작:
- **commit-commands**: `/commit`과 `/commit-push-pr`이 CLAUDE.md 룰을 읽어 메시지 포맷 적용
- **superpowers**: `using-git-worktrees`가 `docs/`의 브랜치 명명 컨벤션을 따름
- **quality-gates**: PR 생성 시 quality 파이프라인 자동 트리거

## 설치된 Hook

- **`PostToolUse` (Bash matcher) — `post-tool-use.py`**: 브랜치 명·커밋 메시지 검증. **왜 hook인가?**: 검증은 모델 attention 여부와 무관하게 모든 Bash invocation에 발화해야 한다. skill은 모델이 invoke하는 단위라 action 레이어에서의 결정적 실행을 보장하지 못함.
  - Kill switch: `DEVBREW_DISABLE_PROJECT_INIT=1` 또는 `DEVBREW_SKIP_HOOKS=project-init:post-tool-use`

- **`PostToolUse` (Write|Edit|MultiEdit matcher) — `docs-lint.py`**: root context 파일 (CLAUDE.md, AGENTS.md, .claude/CLAUDE.md, .claude/AGENTS.md) **및 `docs/project/*.md` (v1.6.0)**의 agent-readable convention (size ≤200, TOC if >300, fenced code language, internal links resolve, CLAUDE/AGENTS drift) + `AGENTS.md`의 `## Project Charter` 필수 하위항목(vision·non-goals·tech-stack: 존재·비어있지 않음·placeholder 잔존 없음, v1.6.0) 검증. **왜 hook인가?**: Write/Edit이 일어날 때마다 deterministic하게 발화해야 함, advisory only (non-blocking).
  - Kill switch: `DEVBREW_DISABLE_PROJECT_INIT=1` (전체) 또는 `DEVBREW_SKIP_HOOKS=project-init:docs-lint` (이 hook만). 새 토큰 없음 — 헌장 검증도 동일 스위치가 커버.
  - 두 hook 모두 끄려면: `DEVBREW_SKIP_HOOKS=project-init:post-tool-use,project-init:docs-lint`

## 인스턴스화한 원칙

이 플러그인은 다음 devbrew 법칙·원칙을 인스턴스화합니다
([`docs/philosophy/devbrew-harness-philosophy.md`](../../docs/philosophy/devbrew-harness-philosophy.md) 참고):

- **Law 3 (Compounding)** — PostToolUse hook이 브랜치 명명과 Conventional Commits 포맷을 지속적으로 강제; 컨벤션 drift를 action 레이어에서 잡음.
- **Plugin shape — minimal pointer pattern** — CLAUDE.md는 짧은 anchor만 (Git Workflow 요약), 상세는 `docs/git-workflow/`에 거주. CLAUDE.md bloat 방지 + 룰 discoverability 양립.
- **Law 1 (Clarity Before Code) — v1.4.0** — agent-readable docs convention enforcement (size ≤200, TOC ≥300줄, fenced code language tag, internal links resolve, CLAUDE/AGENTS drift). Anthropic 공식 가이드 + AGENTS.md 오픈 스펙 + Chroma 2025 *Context Rot* / Lost-in-the-Middle / MDEval / MAST 3-source 합의로 도출된 deterministic baseline.
- **Law 1 (Clarity Before Code) — v1.6.0** — Project Charter가 project-init에 *처음으로* 생기는 clarity 구조 게이트. 최초 실행에서 vision·non-goals·tech-stack·conventions가 채워질 때까지 진행을 막되, 각 항목 최대 3회 재질문 후 loud abort (bounded — Unbounded-autonomy anti-pattern 회피).
- **Law 3 (Compounding) — v1.6.0** — 헌장이 AGENTS.md 계층에 거주해 매 세션·모든 spec-distill 인터뷰가 자동 상속하는 compounding substrate. 한 번 정의한 프로젝트 불변이 미래 모든 사이클에 discoverable하게 흐른다.

## 사용

```
/project-init    # 인터랙티브 git workflow 셋업 시작
```
