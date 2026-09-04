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
│   ├── hooks.json                   # PostToolUse hook 설정 (1개 entry)
│   └── post-tool-use.py             # 브랜치(fail-open advisory) + 커밋 검증기 (Bash matcher)
├── tests/                           # 플러그인 최상위, hooks/의 형제 — 3규약(hooks/tests 포함)을 1종으로 통일
│   ├── __init__.py
│   ├── test_post_tool_use.py        # v1.7.0 — post-tool-use fail-open/F2/main 검증
│   ├── test_command_contract.py     # v1.7.2 — commands/ 산문 계약 회귀 락 (4c S2a H1, AC21 abort)
│   ├── test_branch_strategy_rebase_clause.sh  # v1.7.3 — AC8e, rebase 무조건 금지 조항 부재 락
│   └── test_no_write_matcher_hooks.sh  # v3.0.0 — PostToolUse에 쓰기-도구(Write/Edit/MultiEdit/NotebookEdit) matcher 부재 회귀 락 (A1–A3)
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
- **quality-gates**: `/qg` 로 리뷰·런타임 파이프라인을 수동 기동 (PR 생성 자동 트리거는 quality-gates v7.0.0 에서 제거)

## 설치된 Hook

- **`PostToolUse` (Bash matcher) — `post-tool-use.py`**: 브랜치 명·커밋 메시지 검증 (advisory, non-blocking). 브랜치 검증은 `docs/git-workflow/branch-strategy.md`의 선언된 전략 패턴을 런타임에 읽어 수행하며, 전략 미선언(파일/`` ```regex `` 블록 부재·malformed·빈 블록·비-UTF-8 파일)이면 GitHub Flow를 단정하지 않고 **loud advisory로 검증을 건너뛴다**(fail-open, v1.7.0). 교정 제안은 활성 패턴에서 파생된 prefix를 제시한다. **왜 hook인가?**: 검증은 모델 attention 여부와 무관하게 모든 Bash invocation에 발화해야 한다. skill은 모델이 invoke하는 단위라 action 레이어에서의 결정적 실행을 보장하지 못함.
  - Kill switch: `DEVBREW_PROJECT_INIT_DISABLE=1` (전체) 또는 `DEVBREW_SKIP_HOOKS=project-init:post-tool-use` — 또는 이벤트명 하나로 `DEVBREW_SKIP_HOOKS=project-init:PostToolUse`. 이벤트명 별칭은 spec-distill 이 쓰던 형태를 이 플러그인으로 통일한 것이다 — 한 플러그인에서 배운 형태가 다른 곳에서 조용히 안 먹는 것이 결함이었다.

## 인스턴스화한 원칙

이 플러그인은 다음 devbrew 법칙·원칙을 인스턴스화합니다
([`docs/philosophy/devbrew-harness-philosophy.md`](../../docs/philosophy/devbrew-harness-philosophy.md) 참고):

- **Law 3 (Compounding)** — PostToolUse hook이 브랜치 명명과 Conventional Commits 포맷을 지속적으로 강제; 컨벤션 drift를 action 레이어에서 잡음.
- **Plugin shape — minimal pointer pattern** — CLAUDE.md는 짧은 anchor만 (Git Workflow 요약), 상세는 `docs/git-workflow/`에 거주. CLAUDE.md bloat 방지 + 룰 discoverability 양립.
- **Law 1 (Clarity Before Code) — v1.6.0** — Project Charter가 project-init에 *처음으로* 생기는 clarity 구조 게이트. 최초 실행에서 vision·non-goals·tech-stack·conventions가 채워질 때까지 진행을 막되, 각 항목 최대 3회 재질문 후 loud abort (bounded — Unbounded-autonomy anti-pattern 회피).
- **Law 3 (Compounding) — v1.6.0** — 헌장이 AGENTS.md 계층에 거주해 매 세션·모든 spec-distill 인터뷰가 자동 상속하는 compounding substrate. 한 번 정의한 프로젝트 불변이 미래 모든 사이클에 discoverable하게 흐른다.

## 사용

```
/project-init    # 인터랙티브 git workflow 셋업 시작
```
