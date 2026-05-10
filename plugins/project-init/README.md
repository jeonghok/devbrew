# project-init 플러그인

Claude Code용 git workflow + LLM coding baseline 초기화 플러그인. 어떤 프로젝트에든 branching strategy, commit conventions, PR process 룰을 생성한다.

## 아키텍처

```
plugins/project-init/
├── .claude-plugin/plugin.json       # 플러그인 메타데이터
├── README.md                        # 본 파일
├── commands/
│   └── project-init.md              # /project-init — 인터랙티브 셋업
├── hooks/
│   ├── hooks.json                   # PostToolUse hook 설정
│   └── post-tool-use.py             # 브랜치 명명 + 커밋 메시지 검증기
└── templates/
    ├── shared/
    │   ├── commit-conventions.md    # Conventional Commits 룰 (모든 strategy 공통)
    │   ├── llm-guidelines.md        # Karpathy LLM coding baseline (모든 strategy 공통)
    │   └── pr-process.md            # PR template과 merge 전략 (모든 strategy 공통)
    ├── github-flow/
    │   ├── claude-md-section.md     # CLAUDE.md 주입 템플릿
    │   └── branch-strategy.md       # 브랜치 룰 + 명명 패턴
    ├── git-flow/
    │   ├── claude-md-section.md
    │   └── branch-strategy.md
    └── trunk-based/
        ├── claude-md-section.md
        └── branch-strategy.md
```

## 동작 방식

1. `/project-init` 실행
2. branching strategy 선택 (GitHub Flow / Git Flow / Trunk-based)
3. 커스터마이징 질문 2–3개 답변 (commit scope, merge strategy)
4. 플러그인이 다음을 생성:
   - `CLAUDE.md` — `## LLM Coding Guidelines` (4-bullet Karpathy baseline) + `## Git Workflow` (terse anchor, `docs/git-workflow/` 참조)
   - `docs/git-workflow/branch-strategy.md` — 팀의 브랜치 룰
   - `docs/git-workflow/commit-conventions.md` — Conventional Commits 룰
   - `docs/git-workflow/pr-process.md` — PR 템플릿과 리뷰 체크리스트

## 기능

| 컴포넌트 | 역할 |
|---------|------|
| **`/project-init` command** | 인터랙티브 셋업 — strategy 선택, 룰 생성 |
| **PostToolUse hook** | 브랜치 이름·커밋 메시지 포맷 자동 검증 |
| **LLM Coding Guidelines** | Karpathy 유래 4-bullet 행동 baseline을 CLAUDE.md에 주입 |
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

- **`PostToolUse` (Bash matcher)** — 브랜치 명·커밋 메시지 검증. **왜 hook인가 (skill이 아닌)?**: 검증은 모델 attention 여부와 무관하게 모든 Bash invocation에 발화해야 한다. skill은 모델이 invoke하는 단위라 action 레이어에서의 결정적 실행을 보장하지 못함. hook은 모든 Bash tool use 후 무조건 실행됨.
- **Kill switch:** `DEVBREW_DISABLE_PROJECT_INIT=1`로 비활성화하거나, 더 좁은 단위로 `DEVBREW_SKIP_HOOKS=project-init:post-tool-use` 사용 (devbrew CLAUDE.md §Plugin Shape).

## 인스턴스화한 원칙

이 플러그인은 다음 devbrew 법칙·원칙을 인스턴스화합니다
([`docs/philosophy/devbrew-harness-philosophy.md`](../../docs/philosophy/devbrew-harness-philosophy.md) 참고):

- **Law 1 (Clarity Before Code)** — 4-bullet LLM Coding Guidelines (Karpathy 유래: 가정 명시, overengineering 금지, surgical scope, verifiable 성공 기준)을 프로젝트 boundary에 주입해 Claude가 매 session start마다 읽도록.
- **Law 3 (Compounding)** — PostToolUse hook이 브랜치 명명과 Conventional Commits 포맷을 지속적으로 강제; 컨벤션 drift를 action 레이어에서 잡음.
- **Plugin shape — minimal pointer pattern** — CLAUDE.md는 짧은 anchor만 (8줄 LLM 블록 + Git Workflow 요약), 상세는 `docs/git-workflow/`에 거주. CLAUDE.md bloat 방지 + 룰 discoverability 양립.

## 사용

```
/project-init    # 인터랙티브 git workflow 셋업 시작
```
