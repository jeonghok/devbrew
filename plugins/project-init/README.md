# project-init 플러그인

프로젝트의 git 작업 규칙(브랜치 이름 · 커밋 메시지 · PR 절차)과 프로젝트 헌장을 짧은 대화로 만들어 준다.
결과는 에이전트가 읽는 `AGENTS.md`(그리고 그것을 가리키는 `CLAUDE.md`)와 `docs/` 문서다. 그 뒤로는 훅 하나가
`Bash` 호출에서 브랜치 이름과 커밋 메시지를 확인해 알려 준다(막지는 않는다).

## 아키텍처

```
plugins/project-init/
├── .claude-plugin/plugin.json       # 플러그인 메타데이터
├── README.md                        # 본 파일
├── CHANGELOG.md                     # 변경 이력
├── skills/
│   └── project-init/SKILL.md        # /project-init — 인터랙티브 셋업(사용자 전용)
├── hooks/
│   ├── hooks.json                   # PostToolUse hook 설정 (1개 entry)
│   └── post-tool-use.py             # 브랜치(fail-open advisory) + 커밋 검증기 (Bash matcher)
├── tests/                           # 플러그인 최상위, hooks/의 형제 — 3규약(hooks/tests 포함)을 1종으로 통일
│   ├── __init__.py
│   ├── test_post_tool_use.py        # post-tool-use fail-open/F2/main 검증
│   ├── test_command_contract.py     # skills/project-init 산문 계약 회귀 락 (4c S2a H1 · 이전 거절 선택지 · 헌장 게이트 선택)
│   ├── test_branch_prefix_templates.py  # 템플릿 브랜치 접두 placeholder · worktree 절 락
│   ├── test_branch_strategy_rebase_clause.sh  # AC8e, rebase 무조건 금지 조항 부재 락
│   └── test_no_write_matcher_hooks.sh  # PostToolUse에 쓰기-도구(Write/Edit/MultiEdit/NotebookEdit) matcher 부재 회귀 락 (A1–A3)
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
    └── project/                     # Project Charter skeletons
        ├── agents-md-section.md     # ## Project Charter 요약
        ├── charter.md               # vision·goals·non-goals·success·personas
        ├── conventions.md           # naming·구조·error·anti-patterns·build&test
        └── glossary.md              # 조건부 도메인 용어집
```

## 동작 방식

1. `/project-init` 실행
2. branching strategy 선택 (GitHub Flow / Git Flow / Trunk-based)
3. 커스터마이징 질문 3–4개 답변 (commit scope, merge strategy, 브랜치 접두 추가)
4. 플러그인이 다음을 생성:
   - `AGENTS.md` — `## Git Workflow` (canonical content source, OpenAI Codex/Cursor/Aider 등 16+ 벤더 자동 인식). 기존 `CLAUDE.md` 가 있으면 옮길지 묻는다 — 「CLAUDE.md 에 바로 쓰기」를 고르면 `AGENTS.md` 를 만들지 않고 관리 절을 `CLAUDE.md` 안에 쓴다.
   - `CLAUDE.md` — 기본은 `@AGENTS.md` 한 줄 thin pointer (Claude Code가 AGENTS.md content를 자동 import). 「CLAUDE.md 에 바로 쓰기」면 관리 절을 담고, 「CLAUDE.md 는 그대로 두기」면 손대지 않는다 — 이 선택에서 헌장 절이 CLAUDE.md 에만 있고 이번 실행이 헌장 절을 새로 쓰거나 갱신하지 않았다면(헌장 갱신을 거절했거나 빠진 `docs/project/` 파일만 만들었거나 헌장 단계를 건너뛰었을 때) AGENTS.md 에 `## Project Charter` 가 생기지 않아 실행마다 CLAUDE.md 의 헌장 절을 다시 읽는다.
   - `docs/git-workflow/branch-strategy.md` — 팀의 브랜치 룰
   - `docs/git-workflow/commit-conventions.md` — Conventional Commits 룰
   - `docs/git-workflow/pr-process.md` — PR 템플릿과 리뷰 체크리스트
5. charter step — Phase 0가 manifest를 스캔해 tech-stack을 자동 감지하고, Phase 1이 vision·non-goals·conventions·tech-stack 확인을 기본 4개 질문으로(쓴 수를 공시하고 「더 묻기」로 더 받는다) elicit. 결과를 `AGENTS.md ## Project Charter` 요약 + `docs/project/charter.md`·`conventions.md`(+ 조건부 `glossary.md`)로 발행.

## 기능

| 컴포넌트 | 역할 |
|---------|------|
| **`/project-init` skill** | 인터랙티브 셋업 — strategy 선택, 룰 생성 |
| **PostToolUse hook** | 브랜치 이름·커밋 메시지 포맷 자동 검증 |
| **Templates** | 3개 branching strategy의 사전 작성된 룰 |

## 브랜치 전략

| Strategy | Branches | Best for |
|----------|----------|----------|
| **GitHub Flow** | `main` + `feature/*` / `fix/*` | 작은 팀, CI/CD, continuous deployment |
| **Git Flow** | `main` + `develop` + `feature/*` / `fix/*` / `release/*` / `hotfix/*` | release cycle, version 관리 |
| **Trunk-based** | `main` + 단명 `feature/*` / `fix/*` | 빠른 배포, feature flag |

## Prerequisites

- **Python 3.12+** — 이 플러그인의 훅이 요구하는 바닥입니다. 숫자는 도출된 값입니다 —
  「개발 당시 훅이 실제로 쓴 해석기 판(`dependencies.md` 의 `python-hook` 행) — 측정 명령이 잰다」,
  다음 재검토는 3.12 EOL(2028-10).
  바닥 미만이면 훅은 **막지 않고** 건너뜁니다. 그 사실을 알리는 세션 시작 안내는 `SessionStart`
  훅 자리에서만 나가는데, 지금 devbrew 에는 그 자리가 없어 안내 없이 조용히 건너뜁니다.
  `$DEVBREW_PYTHON`으로 인터프리터를 직접 지정할 수 있습니다.

## 통합

다른 플러그인과 함께 동작:
- **commit-commands**: `/commit`과 `/commit-push-pr`이 CLAUDE.md 룰을 읽어 메시지 포맷 적용
- **superpowers**: `using-git-worktrees`가 `docs/`의 브랜치 명명 컨벤션을 따름
- **quality-gates**: `/quality-gates:quality-pipeline` 으로 리뷰·런타임 파이프라인을 수동 기동

## 설치된 Hook

- **`PostToolUse` (Bash matcher) — `post-tool-use.py`**: 브랜치 명·커밋 메시지 검증 (advisory, non-blocking). 브랜치 검증은 `docs/git-workflow/branch-strategy.md`의 선언된 전략 패턴을 런타임에 읽어 수행하며, 전략 미선언(파일/`` ```regex `` 블록 부재·malformed·빈 블록·비-UTF-8 파일)이면 GitHub Flow를 단정하지 않고 **loud advisory로 검증을 건너뛴다**(fail-open). 교정 제안은 활성 패턴에서 파생된 prefix를 제시한다. **왜 hook인가?**: 검증은 모델 attention 여부와 무관하게 모든 Bash invocation에 발화해야 한다. skill은 모델이 invoke하는 단위라 action 레이어에서의 결정적 실행을 보장하지 못함.
  - Kill switch: `DEVBREW_PROJECT_INIT_DISABLE=1` (전체) 또는 `DEVBREW_SKIP_HOOKS=project-init:post-tool-use` — 또는 이벤트명 하나로 `DEVBREW_SKIP_HOOKS=project-init:PostToolUse`. 이벤트명 별칭은 spec-distill 이 쓰던 형태를 이 플러그인으로 통일한 것이다 — 한 플러그인에서 배운 형태가 다른 곳에서 조용히 안 먹는 것이 결함이었다.
  - `DEVBREW_PROJECT_INIT_DISABLE=1` 은 훅만이 아니라 `/project-init` 진입도 `disabled` no-op 으로 만든다. `DEVBREW_SKIP_HOOKS` 는 진입 skill 에 걸리지 않는다.
  - 사전 검사 스크립트(`scripts/entry_preflight.py`)나 `python3` 가 없으면 플랫폼이 호출을 끊는다(헤드리스에서는 출력 없이 끝난다).

## Principles Instantiated

이 플러그인은 다음 devbrew 법칙·원칙을 인스턴스화합니다
([`docs/philosophy/devbrew-harness-philosophy.md`](../../docs/philosophy/devbrew-harness-philosophy.md) 참고):

- **Law 3 (Compounding)** — PostToolUse hook이 브랜치 명명과 Conventional Commits 포맷을 지속적으로 강제; 컨벤션 drift를 action 레이어에서 잡음.
- **Plugin shape — minimal pointer pattern** — 기본은 `CLAUDE.md` 가 `@AGENTS.md` 한 줄 thin pointer 이고 규칙 본문은 `AGENTS.md` 와 `docs/git-workflow/` 에 산다. 「CLAUDE.md 에 바로 쓰기」를 고르면 관리 절이 `CLAUDE.md` 안에 있고, 「CLAUDE.md 는 그대로 두기」를 고르면 `CLAUDE.md` 는 손대지 않는다.
- **Law 1 (Clarity Before Code)** — Project Charter가 project-init에 *처음으로* 생기는 clarity 구조 게이트. 최초 실행에서 vision·non-goals·tech-stack·conventions가 채워질 때까지 진행을 막되, 각 항목 최대 3회 재질문 뒤 사용자가 건너뛰기 · 계속 묻기 · 중단을 고른다(기계가 멈추지 않는다 — 반복은 사용자 선택이 연다).
- **Law 3 (Compounding)** — 헌장이 AGENTS.md 계층에 거주해 매 세션·모든 spec-distill 인터뷰가 자동 상속하는 compounding substrate. 한 번 정의한 프로젝트 불변이 미래 모든 사이클에 discoverable하게 흐른다.

## 사용

```
/project-init    # 인터랙티브 git workflow 셋업 시작
```

같은 이름이 설치 환경에 있으면 `/project-init:project-init` 로 부른다.
