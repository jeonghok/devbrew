# Quality Gates Plugin

3-gate quality verification pipeline for Claude Code with multi-plugin review delegation.

## Principles Instantiated

This plugin instantiates the following devbrew laws/principles
(see [`docs/philosophy/devbrew-harness-philosophy.md`](../../docs/philosophy/devbrew-harness-philosophy.md)
once that file lands on `main`):

- **Law 1 (Clarity Before Code)** — Gate 1 plan-verifier blocks Gate 2 entry on FAIL via the `gate1_summary` YAML handoff.
- **Law 2 (Writer ≠ Reviewer)** — every reviewer agent declares `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]`.
- **Law 3 (Compounding)** — scout `rationale` field is logged to state file per iteration; reviewer-persona edits are how we encode lessons learned.
- **AP3 (Trivia ceremony) avoidance** — `check-trivia.sh` skips pipeline entirely on whitespace/rename ≤3 lines single-file changes.
- **AP9 (Subagent spray) hard gate** — AskUserQuestion fires when Phase 1+2 dispatch count ≥ 4.
- **AP15 (Unbounded autonomy) avoidance** — within-Gate-2 loop bounded by `max_gate2_iterations=5` + repeat-detection (no-progress check) + kill switches.
- **P5 (Filesystem as Memory) + P14 (State Survives Compaction) + §4.8 (State File)** — per-session markdown state under `.claude/quality-gates/<session-id>/` (auto-ignored by `*.local.md` gitignore pattern; folder GC'd by TTL sweep + SessionEnd hook).

## Architecture

```
quality-gates/
├── .claude-plugin/         # Plugin metadata
│   └── plugin.json
├── agents/                 # Gate agents (leaf agents; dispatched by pipeline)
│   ├── plan-verifier.md    # Gate 1
│   ├── runtime-verifier.md # Gate 3 (Gate 2 is orchestrated directly by SKILL.md)
│   ├── scout.md            # Phase 0 of Gate 2 — model-driven dispatch planner
│   ├── adversarial.md      # Phase 1.5 of Gate 2 — false-positive hunter
│   └── synthesizer.md      # Phase 1.6 of Gate 2 — dedupe/rank findings
├── commands/
│   ├── qg.md               # /qg slash command (with --reset, --paths, branch flags)
│   └── cancel-qg.md        # /cancel-qg command
├── hooks/
│   ├── hooks.json                            # Hook configuration
│   ├── stop-hook.py                          # Pipeline progression (state machine)
│   ├── post-tool-use-session-tracker.py      # Tracks files edited this session
│   ├── post-tool-use.py                      # PostToolUse(Bash) — auto-trigger detector
│   ├── session-start-advisor.py              # Read-only advisor for in-flight pipelines
│   └── session-end-cleanup.py                # Removes current session folder on graceful close
├── scripts/
│   ├── setup-qg.sh                           # Pipeline initialization
│   ├── pre-pipeline-check.sh                 # In-skill session-lifecycle check
│   ├── check-trivia.sh                       # Trivia escape detector
│   ├── filter-docs.sh                        # Docs-path filter for code reviewers
│   └── qg-gc.py                              # TTL-based stale-session GC (fcntl-locked)
└── skills/
    └── quality-pipeline/
        ├── SKILL.md         # Single-gate executor
        └── references/
            ├── dependency-check.md   # Pre-flight dependency checks
            └── state-file-format.md  # Pipeline state file format
```

## Hooks Installed

| Hook | Event | Mutating? | Why a hook (not a skill)? |
|---|---|---|---|
| `stop-hook.py` | Stop | yes (state file) | Pipeline progression must run *after* every assistant turn. |
| `post-tool-use-session-tracker.py` | PostToolUse(Edit/Write/MultiEdit) | yes (session file) | Must observe every file mutation deterministically; only a hook can. |
| `post-tool-use.py` | PostToolUse(Bash) | no — read-only check | Detect commit/PR Bash activity to suggest `/qg`; scoped to current session only. |
| `session-start-advisor.py` | SessionStart | **no — read-only advisor** | Surface in-flight pipelines (current session) without mutation (CLAUDE.md hook coexistence rule). |
| `session-end-cleanup.py` | SessionEnd | yes (removes own session folder) | Graceful per-session cleanup on close; crashes fall back to TTL sweep. |

All hooks honor `DEVBREW_DISABLE_QUALITY_GATES=1` (global) and the per-hook
override `DEVBREW_SKIP_HOOKS=quality-gates:<hook-name>`.

## Cost Classes

The `quality-pipeline` skill is `cost_class: variable` — actual cost depends on auto-detected depth:

| Depth | Cost vs default-Opus baseline |
|---|---|
| Trivia | ~0% (instant skip) |
| Quick | ~25–35% |
| Standard | ~30–45% |
| Deep | ~55–75% (AskUserQuestion gate fires) |

See [`commands/qg.md`](commands/qg.md) for trigger criteria and override flags.

## Gates

| Gate | Driven by | Purpose | Delegates To |
|------|-----------|---------|-------------|
| 1 | plan-verifier agent | Cross-references plan checkboxes with git diff; emits `gate1_summary` YAML handoff to Gate 2 | feature-dev:code-explorer (impl trace), superpowers:verification-before-completion (evidence) |
| 2 | quality-pipeline skill (inline) | Scout-driven orchestration: depth-aware dispatch + Phase 1.5 adversarial + Phase 1.6 synthesizer | pr-review-toolkit, feature-dev, superpowers (review agents) |
| 3 | runtime-verifier agent | Starts the app, checks console errors, takes screenshots | chrome-devtools-mcp or playwright |

**Architecture note — why Gate 2 has no agent**: Claude Code only allows skills (not agents) to use `Agent()` with `subagent_type`. Gate 2 needs to dispatch several review agents in phases, so its orchestration logic lives in `skills/quality-pipeline/SKILL.md` directly. Gates 1 and 3 still use leaf agents (they do not dispatch sub-agents).

## Gate 2 Review Phases (v1.5.0 redesign)

```
Phase 0  Scout (always, sonnet) — produces dispatch plan: depth + agent subset
Phase 1  Critical analysis (depth-aware, parallel)
  ├── pr-review-toolkit:code-reviewer        (always; upstream Opus)
  ├── pr-review-toolkit:silent-failure-hunter (Standard/Deep; sonnet override)
  └── feature-dev:code-reviewer              (Deep only)
Phase 2  Conditional (scout-recommended only)
  ├── pr-review-toolkit:type-design-analyzer  → new types
  ├── pr-review-toolkit:pr-test-analyzer      → test changes
  ├── pr-review-toolkit:comment-analyzer      → documentation
  ├── superpowers:code-reviewer               → plan alignment
  └── feature-dev:code-architect              → architecture
Phase 1.5  Adversarial (Standard/Deep, opus) — false-positive hunting
Phase 1.6  Synthesizer (always when Phase 1 ran, sonnet) — dedupe/rank
Phase 3  Polish (one-shot, upstream Opus): pr-review-toolkit:code-simplifier
```

AskUserQuestion fires when `len(phase1) + len(phase2) >= 4` (philosophy AP9).

## Pipeline Flow (forward-only state machine, v1.5.0)

```
/qg → setup-qg.sh → pre-pipeline-check → trivia escape?
   ├── yes → instant PASS, 0 dispatches
   └── no → SKILL.md (Gate 1) → Stop hook → SKILL.md (Gate 2)
              → Stop hook → SKILL.md (Gate 3) → done
```

**Cross-gate restart removed in v1.5.0**: Gate 2 / Gate 3 NEEDS_RESTART verdicts
now terminate with a user-choice prompt ("apply changes and re-run /qg") instead
of auto-restarting from Gate 1. The within-Gate-2 fix-loop (max 5 iterations)
is preserved.

## Usage

```
/qg                            # Full pipeline; session-scoped diff
/qg branch                     # Full pipeline; full-branch diff vs main
/qg --paths <glob>...          # Full pipeline; explicit path scope
/qg --reset                    # Clear current session folder + legacy v1.5.0 files; exit
/qg --gc                       # Sweep stale sibling sessions (TTL) and exit
/qg gate1                      # Plan verification only
/qg gate2                      # PR review only
/qg gate3                      # Runtime verification only
/qg --skip-runtime             # Gates 1 & 2 only
/qg --plan <path>              # Use specific plan file
/qg --pr-url <url>             # Specify PR URL
/cancel-qg                     # Cancel active pipeline (current session)
/cancel-qg --gc                # TTL sweep of stale sessions
/cancel-qg --all               # Wipe all sessions (confirms; lists active siblings first)
```

## Prerequisites

| Plugin | Required | Used By | Purpose |
|--------|----------|---------|---------|
| pr-review-toolkit | Yes | Gate 2 | Core review agents |
| feature-dev | No | Gate 1, 2 | Convention review, architecture, impl trace |
| superpowers | No | Gate 1, 2 | Plan alignment, evidence verification |
| chrome-devtools-mcp / playwright | No | Gate 3 | Browser automation |

## Configuration

- `MAX_GATE2_ITERATIONS`: 5 (review-fix cycles within Gate 2)
- `QG_STALE_HOURS`: 24 (session file staleness threshold for pre-pipeline-check.sh)
- `DEVBREW_QG_TTL_HOURS`: 24 (TTL for sibling session folders; older folders GC'd on `/qg` or `/cancel-qg --gc`)
- `DEVBREW_QG_GC_VERBOSE`: unset (set to `1` for GC sweep diagnostics on stderr)

(`MAX_TOTAL_ITERATIONS` and the cross-gate restart loop were removed in v1.5.0.)

## Pipeline state

State is tracked per Claude Code session in `.claude/quality-gates/<session-id>/`:
- `pipeline.md` — pipeline frontmatter (status, current_gate, iteration counters) + body (Gate Results, History).
- `files.md` — files edited in this session (used for `/qg` scope narrowing).
- `branch.md` — last seen git branch (for branch-mismatch detection).
- `diff-cache.txt`, `code-paths.tmp` — transient caches.

Stale sibling folders (mtime older than `DEVBREW_QG_TTL_HOURS`, default 24h) are
garbage-collected when `/qg` or `/cancel-qg --gc` runs. The `SessionStart` hook
is strictly read-only (per CLAUDE.md rule); the `SessionEnd` hook removes the
current session's folder on graceful close. Crashes fall back to the TTL sweep.

All files match the `*.local.md` gitignore pattern; no `.gitignore` changes are
needed.
