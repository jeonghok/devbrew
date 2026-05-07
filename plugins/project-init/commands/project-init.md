---
description: "Initialize git workflow rules + LLM coding baseline for the project (branch strategy, commit conventions, PR process, Karpathy-derived LLM guidelines)"
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---

# project-init

Initialize git workflow rules by selecting a branching strategy template, then generating CLAUDE.md and docs/ files for the project.

## Instructions

Follow these steps exactly in order.

### Step 1: Detect project state

1. Check if `CLAUDE.md` exists in the project root
2. If it exists, check if a `## Git Workflow` section already exists
3. Check if `docs/git-workflow/` directory exists

If existing Git Workflow configuration is found, ask the user:
> "Existing git workflow rules detected. Replace them with the new template?"

If the user declines, stop.

### Step 2: Select branching strategy

Present these 3 options to the user:

| Strategy | Branches | Best for |
|----------|----------|----------|
| **GitHub Flow** | `main` + `feature/*` / `fix/*` | Small teams, CI/CD, continuous deployment |
| **Git Flow** | `main` + `develop` + `feature/*` / `fix/*` / `release/*` / `hotfix/*` | Teams with release cycles, version management |
| **Trunk-based** | `main` + short-lived `feature/*` / `fix/*` | Fast deployment, feature flag teams |

Wait for the user to choose.

### Step 3: Customization questions

Ask these questions based on the selected strategy:

**For all strategies:**

1. **Commit scope convention** — "How should commit scopes be defined?"
   - By module/directory name (e.g., `feat(auth):`, `fix(api):`)
   - By feature area (e.g., `feat(login):`, `fix(checkout):`)
   - No scope required (e.g., `feat:`, `fix:`)

2. **Default merge strategy** — "What's the default PR merge strategy?"
   - Squash merge (recommended for clean history)
   - Merge commit (preserves all commits)
   - Rebase (linear history)

**Additional for Git Flow:**

3. **Release branch naming** — "Release branch format?"
   - `release/v*` (e.g., `release/v1.2.0`) — default
   - Custom format

### Step 4: Generate files

Based on the selected strategy and answers, generate the following files.

**Important:** The template files are located at `${CLAUDE_PLUGIN_ROOT}/templates/`. Read them, replace placeholders, and write to the project.

#### 4a: Read templates

Read these files from the plugin:
- `${CLAUDE_PLUGIN_ROOT}/templates/shared/llm-guidelines.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/<strategy>/claude-md-section.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/<strategy>/branch-strategy.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/shared/commit-conventions.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/shared/pr-process.md`

Where `<strategy>` is one of: `github-flow`, `git-flow`, `trunk-based`.

#### 4b: Replace placeholders

Replace these placeholders in the template content:

| Placeholder | Replace with |
|-------------|-------------|
| `{{SCOPE_CONVENTION}}` | The scope rule from Step 3 question 1 (e.g., "Scope by module/directory name: `auth`, `api`, `ui`") |
| `{{MERGE_STRATEGY}}` | The merge strategy from Step 3 question 2 (e.g., "squash merge") |

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

#### 4d: Write docs/git-workflow/ files

Create the directory `docs/git-workflow/` if it doesn't exist. Write these 3 files:

1. `docs/git-workflow/branch-strategy.md` — from `templates/<strategy>/branch-strategy.md`
2. `docs/git-workflow/commit-conventions.md` — from `templates/shared/commit-conventions.md` (with placeholders replaced)
3. `docs/git-workflow/pr-process.md` — from `templates/shared/pr-process.md` (with placeholders replaced)

### Step 5: Confirm

Report what was created:

> Git workflow + LLM coding guidelines initialized with **{strategy name}** strategy.
>
> Files created/updated:
> - `CLAUDE.md` — `## LLM Coding Guidelines` and `## Git Workflow` sections added
> - `docs/git-workflow/branch-strategy.md` — Branch rules
> - `docs/git-workflow/commit-conventions.md` — Commit conventions
> - `docs/git-workflow/pr-process.md` — PR process
>
> The `project-init` plugin hook will auto-validate branch names and commit messages.
> The 4-bullet LLM Coding Guidelines baseline is derived from Andrej Karpathy's LLM coding observations.
> Use `/commit` or `/commit-push-pr` (commit-commands plugin) for streamlined git operations.
