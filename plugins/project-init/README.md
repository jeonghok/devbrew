# project-init

Git workflow initialization plugin for Claude Code. Generates branching strategy, commit conventions, and PR process rules for any project.

## Architecture

```
plugins/project-init/
├── .claude-plugin/plugin.json       # Plugin metadata (v1.1.0)
├── README.md                        # This file
├── commands/
│   └── project-init.md              # /project-init — interactive setup
├── hooks/
│   ├── hooks.json                   # PostToolUse hook config
│   └── post-tool-use.py             # Branch naming + commit message validator
└── templates/
    ├── shared/
    │   ├── commit-conventions.md    # Conventional Commits rules (all strategies)
    │   └── pr-process.md            # PR template and merge strategy (all strategies)
    ├── github-flow/
    │   ├── claude-md-section.md     # CLAUDE.md injection template
    │   └── branch-strategy.md       # Branch rules + naming pattern
    ├── git-flow/
    │   ├── claude-md-section.md
    │   └── branch-strategy.md
    └── trunk-based/
        ├── claude-md-section.md
        └── branch-strategy.md
```

## How It Works

1. Run `/project-init`
2. Select a branching strategy (GitHub Flow / Git Flow / Trunk-based)
3. Answer 2-3 customization questions (commit scope, merge strategy)
4. Plugin generates:
   - `CLAUDE.md` — `## LLM Coding Guidelines` (4-bullet Karpathy baseline) + `## Git Workflow` (terse anchor, reference to `docs/git-workflow/`)
   - `docs/git-workflow/branch-strategy.md` — branch rules for the team
   - `docs/git-workflow/commit-conventions.md` — Conventional Commits rules
   - `docs/git-workflow/pr-process.md` — PR template and review checklist

## Features

| Component | Role |
|-----------|------|
| **`/project-init` command** | Interactive setup — select strategy, generate rules |
| **PostToolUse hook** | Auto-validates branch naming and commit message format |
| **LLM Coding Guidelines** | 4-bullet Karpathy-derived behavioral baseline injected into CLAUDE.md |
| **Templates** | Pre-built rules for 3 branching strategies |

## Branching Strategies

| Strategy | Branches | Best for |
|----------|----------|----------|
| **GitHub Flow** | `main` + `feature/*` / `fix/*` | Small teams, CI/CD, continuous deployment |
| **Git Flow** | `main` + `develop` + `feature/*` / `fix/*` / `release/*` / `hotfix/*` | Release cycles, version management |
| **Trunk-based** | `main` + short-lived `feature/*` / `fix/*` | Fast deployment, feature flags |

## Integration

Works alongside other plugins:
- **commit-commands**: `/commit` and `/commit-push-pr` read CLAUDE.md rules to format messages
- **superpowers**: `using-git-worktrees` follows branch naming conventions from docs/
- **quality-gates**: Auto-triggers quality pipeline on PR creation

## Principles Instantiated

- **Law 1 (Clarity Before Code)** — 4-bullet LLM Coding Guidelines (Karpathy-derived: assumptions explicit, no overengineering, surgical scope, verifiable success criteria) injected at the project boundary so Claude reads it on every session start.
- **Law 3 (Compounding)** — PostToolUse hook continuously enforces branch naming and Conventional Commits format; convention drift caught at the action layer.
- **Plugin shape — minimal pointer pattern** — CLAUDE.md keeps terse anchors (8-line LLM block + Git Workflow summary); details live in `docs/git-workflow/`. CLAUDE.md bloat 방지 + 룰 discoverability 양립.

## Usage

```
/project-init    # Start interactive git workflow setup
```
