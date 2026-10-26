# project-init 플러그인

프로젝트의 git 작업 규칙(브랜치 이름 · 커밋 메시지 · PR 절차)과 프로젝트 헌장을 짧은 대화로 만들어 준다.
결과는 에이전트가 읽는 `AGENTS.md`(그리고 그것을 가리키는 `CLAUDE.md`)와 `docs/` 문서다. 그 뒤로는 훅 하나가
`Bash` · `EnterWorktree` 호출 뒤 새로 생긴 브랜치 이름과 커밋 메시지를 확인해 알려 준다(막지는 않는다).

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
│   └── post-tool-use.py             # 새 브랜치 관찰(fail-open advisory) + 커밋 검증기 (Bash|EnterWorktree matcher)
├── tests/                           # 플러그인 최상위, hooks/의 형제 — 3규약(hooks/tests 포함)을 1종으로 통일
│   ├── __init__.py
│   ├── test_post_tool_use.py        # post-tool-use fail-open/F2/main 검증
│   ├── test_post_tool_use_branch.sh # 명령 · EnterWorktree 뒤 새 브랜치 관찰 · 기본 브랜치 규칙 · kill switch (임시 레포)
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
| **PostToolUse hook** | 새 브랜치 이름·커밋 메시지 포맷 자동 검증 |
| **Templates** | 3개 branching strategy의 사전 작성된 룰 |

## 브랜치 전략

| Strategy | Branches | Best for |
|----------|----------|----------|
| **GitHub Flow** | `main` + `feature/*` / `fix/*` | 작은 팀, CI/CD, continuous deployment |
| **Git Flow** | `main` + `develop` + `feature/*` / `fix/*` / `release/*` / `hotfix/*` | release cycle, version 관리 |
| **Trunk-based** | `main` + 단명 `feature/*` / `fix/*` | 빠른 배포, feature flag |

## Prerequisites

의존마다의 최소 판 · 잰 날짜 · 없을 때 동작은 [`dependencies.md`](dependencies.md) 에 있다. 최소 판은 이 판을 개발 · 검증할 때 깔려 있던 판이고, 진입마다 쓰는 의존의 판을 그 표와 대조해(`scripts/check_deps.py entry`) 없거나 낮으면 멈춘다. 이 플러그인은 gh 를 쓰지 않는다 — 훅의 Python 바닥은 아래 줄과 표의 `python-hook` 행이다.

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

- **`PostToolUse` (`Bash|EnterWorktree` matcher) — `post-tool-use.py`**: 새 브랜치 이름·커밋 메시지 검증 (advisory, non-blocking). 브랜치는 명령 문자열이 아니라 **실행 뒤 상태**로 본다 — 도구 호출이 끝난 뒤 공용 git 디렉토리의 브랜치 reflog 를 읽어, 60초 안의 만들기(`branch: Created from …`) · 이름 바꾸기 · 복사 줄이 있는 브랜치를 새 브랜치로 잡는다(`worktree add -b` · `branch -m` · `checkout -B` · `switch --create` · `git -C <dir> branch` 가 모두 이 줄을 남긴다). 마지막 줄만 보지 않아서 `git checkout -b X && git commit …` 처럼 만든 뒤 바로 커밋해도 잡는다 — reflog 를 끝에서부터 60초 밖의 줄이 나올 때까지 거슬러 읽고, 1MiB 상한까지 읽고도 다 못 보면 그 사실을 알리고 건너뛴다. 그 가운데 **이 호출이 만든 브랜치만** 다룬다 — 도구 입력 글(Bash 의 명령)이 그 이름을 한 낱말로 가리키거나 cwd 가 지금 그 브랜치를 쓰고 있어야 알린다. 이름 바꾸기 명령의 근거는 명령 글의 해석이 아니라 git 상태다 — 호출 뒤 cwd 의 지금 브랜치이면서 명령 글이 그 이름을 가리키거나(`checkout -b X` · `switch -c X` · 지금 브랜치의 `branch -m 옛 X`), EnterWorktree 가 만든 작업 트리의 브랜치일 때만 낸다. 이름을 가리키기만 했거나(`git log X` · `npm test` 의 `test` · 커밋 메시지 안의 글 · `git -C <다른 레포>`) 만들고 옮겨 가지 않은 브랜치(`git branch X`)는 다른 세션의 같은 이름일 수 있어 알리기만 한다. 같은 체크아웃을 두 세션이 함께 쓰며 한 세션이 옮겨 간 브랜치의 이름을 다른 세션의 명령이 가리키는 경우만 남은 위험이다. `name` 없이 부른 EnterWorktree(무작위 이름)는 cwd 가 새 작업 트리면 그 지금 브랜치를 이 호출의 것으로 보고, cwd 가 옮기기 전 레포면 어느 브랜치인지 몰라 그 사실을 알리고 건너뛴다. 상태 파일을 두지 않아서 60초 안의 다음 호출에서는 같은 알림이 다시 날 수 있고, 60초가 지난 규칙 밖 옛 브랜치는 다시 알리지 않는다. 규칙은 작업 트리가 아니라 **기본 브랜치 판**(`refs/remotes/origin/HEAD` 의 `docs/git-workflow/branch-strategy.md`)의 선언된 전략 패턴을 런타임에 읽는다. `origin` 원격이 없거나 기본 브랜치(`origin/HEAD`)가 없거나 전략 미선언(파일/`` ```regex `` 블록 부재·malformed·빈 블록·비-UTF-8 파일)이면 GitHub Flow를 단정하지 않고 그 사실을 **loud advisory로 알리고 검증을 건너뛴다**(fail-open). 한 번 실행의 git 호출은 모두 합쳐 8초 안(hooks.json timeout 10초 안)에 끝내고, 넘으면 브랜치 검사를 건너뛴다고 알린다(커밋 메시지 검증은 그대로 낸다). 교정 제안은 활성 패턴에서 파생된 prefix로 `git branch -m <옛 이름> <접두>/<이름>` 을 모델 채널에 낸다 — 다른 작업 트리에서 쓰고 있는 브랜치에는 내지 않고(이름을 바꾸면 그 작업 트리의 세션이 깨진다) 그 작업 트리 경로를 사람 채널에 적으며, 작업 트리 목록을 못 읽으면 명령을 내지 않는다고 알린다. 커밋 메시지 검증은 `Bash` 에서만 한다. **왜 hook인가?**: 검증은 모델 attention 여부와 무관하게 모든 Bash · EnterWorktree invocation 뒤에 발화해야 한다. skill은 모델이 invoke하는 단위라 action 레이어에서의 결정적 실행을 보장하지 못함.
  - EnterWorktree 뒤에 이 훅이 실제로 불리는지는 실측하지 못했다(Claude Code 훅 문서는 PostToolUse 가 모든 도구 호출 뒤에 불린다고 적는다 — 문서 근거, 실측 아님). 불리지 않으면 EnterWorktree 로 만든 브랜치는 검사 밖일 수 있다(60초 안에 그 작업 트리를 cwd 로 다음 Bash 호출이 오면 그때 잡힌다). 불리면 그 호출의 브랜치는 cwd 의 지금 브랜치이거나 입력 `name` 으로 끝나는 경로(`…/<name>`, name 의 `/` 는 `+` 또는 하위 폴더)의 작업 트리가 쓰는 브랜치다 — payload 의 cwd 가 옮기기 전 레포여도 잡는다(그때는 다른 작업 트리의 브랜치라 이름 바꾸기 명령 없이 알린다). 작업 트리 목록을 못 읽으면 그 사실을 알리고 건너뛴다. `name` 없이 부른 EnterWorktree 는 payload 의 cwd 가 새 작업 트리일 때만 잡힌다.
  - 관찰 범위: 공용 git 디렉토리를 보지만 같은 레포의 다른 세션 · 다른 작업 트리가 만든 브랜치는 이 호출의 입력이 그 이름을 가리키지 않고 cwd 의 지금 브랜치도 아니면 다루지 않는다(알리지도, 이름 바꾸기 명령을 내지도 않는다). 그래서 변수 · 스크립트로 만들어 이름이 명령 글에 드러나지 않고 지금 브랜치로 옮겨 가지도 않은 브랜치는 검사 밖이다. 이 호출이 가리킨 브랜치라도 다른 작업 트리에서 쓰고 있으면 이름 바꾸기 명령 없이 알린다. 세션 cwd 의 레포가 아닌 다른 레포에 `git -C <dir>` 로 만든 브랜치는 보지 않는다. reflog 가 없는 레포(`core.logAllRefUpdates=false` · reftable 저장소)에서는 새 브랜치를 볼 수 없어 이 검사가 알림 없이 돌지 않는다.
  - spec-distill 의 레포 설정 `branch_prefix` 는 이 플러그인의 브랜치 규칙과 맞춘다 — 두 플러그인은 서로의 설정을 읽지 않으므로, 어긋나면 지휘자가 만드는 브랜치마다 이 훅이 알린다.
  - Kill switch: `DEVBREW_PROJECT_INIT_DISABLE=1` (전체) 또는 `DEVBREW_SKIP_HOOKS=project-init:post-tool-use` — 또는 이벤트명 하나로 `DEVBREW_SKIP_HOOKS=project-init:PostToolUse`. 이벤트명 별칭은 spec-distill 이 쓰던 형태를 이 플러그인으로 통일한 것이다 — 한 플러그인에서 배운 형태가 다른 곳에서 조용히 안 먹는 것이 결함이었다.
  - `DEVBREW_PROJECT_INIT_DISABLE=1` 은 훅만이 아니라 `/project-init` 진입도 `disabled` no-op 으로 만든다. `DEVBREW_SKIP_HOOKS` 는 진입 skill 에 걸리지 않는다.
  - 사전 검사 스크립트(`scripts/entry_preflight.py`)나 `python3` 가 없으면 플랫폼이 호출을 끊는다(헤드리스에서는 출력 없이 끝난다).

## Principles Instantiated

이 플러그인은 다음 devbrew 법칙·원칙을 인스턴스화합니다
([`docs/philosophy/devbrew-harness-philosophy.md`](../../docs/philosophy/devbrew-harness-philosophy.md) 참고):

- **P8 (이식성) — 의존 판** — 의존의 최소 판을 손으로 적지 않는다. `scripts/check_deps.py measure` 가 개발 당시 깔린 판을 재서 `dependencies.md` 에 쓰고, 진입은 그 표와 지금 판을 대조해 없거나 낮으면 멈춘다(`check_deps.py entry`).
- **Law 3 (Compounding)** — PostToolUse hook이 브랜치 명명과 Conventional Commits 포맷을 지속적으로 강제; 컨벤션 drift를 action 레이어에서 잡음.
- **Plugin shape — minimal pointer pattern** — 기본은 `CLAUDE.md` 가 `@AGENTS.md` 한 줄 thin pointer 이고 규칙 본문은 `AGENTS.md` 와 `docs/git-workflow/` 에 산다. 「CLAUDE.md 에 바로 쓰기」를 고르면 관리 절이 `CLAUDE.md` 안에 있고, 「CLAUDE.md 는 그대로 두기」를 고르면 `CLAUDE.md` 는 손대지 않는다.
- **Law 1 (Clarity Before Code)** — Project Charter가 project-init에 *처음으로* 생기는 clarity 구조 게이트. 최초 실행에서 vision·non-goals·tech-stack·conventions가 채워질 때까지 진행을 막되, 각 항목 최대 3회 재질문 뒤 사용자가 건너뛰기 · 계속 묻기 · 중단을 고른다(기계가 멈추지 않는다 — 반복은 사용자 선택이 연다).
- **Law 3 (Compounding)** — 헌장이 AGENTS.md 계층에 거주해 매 세션·모든 spec-distill 인터뷰가 자동 상속하는 compounding substrate. 한 번 정의한 프로젝트 불변이 미래 모든 사이클에 discoverable하게 흐른다.

## 사용

```
/project-init    # 인터랙티브 git workflow 셋업 시작
```

같은 이름이 설치 환경에 있으면 `/project-init:project-init` 로 부른다.
