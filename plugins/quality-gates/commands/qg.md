---
description: "Run the quality gates pipeline (plan verification → PR review → runtime verification)"
argument-hint: "[gate1|gate2|gate3] [branch [<name>]|--paths <glob>...|--reset] [--skip-runtime] [--plan <path>] [--pr-url <url>]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh:*)", "Bash(rm:*)", "Bash(test:*)", "Agent", "Skill", "Bash", "Read", "Edit", "Write", "Glob", "Grep"]
---

# Quality Gates Pipeline

Run the 3-gate quality verification pipeline to ensure code quality before PR merge.

**Arguments:** $ARGUMENTS

## Special argument: `--reset`

`$ARGUMENTS` 가 `--reset` 포함 시 setup 안 돌리고 자기 세션 폴더 + legacy 파일 정리:

```!
SID="${CLAUDE_CODE_SESSION_ID:-}"
if [ -n "$SID" ]; then
  rm -rf ".claude/quality-gates/$SID"
fi
rm -f .claude/quality-gates.local.md \
      .claude/quality-gates-session.local.md \
      .claude/quality-gates-branch.local.md \
      .claude/qg-diff-cache.txt \
      .claude/qg-code-paths.tmp
```

종료 후 "Quality-gates state cleared." 보고.

## Special argument: `--gc`

`$ARGUMENTS` 가 `--gc` 포함 시 (단독 또는 다른 인자와 함께) TTL GC를 명시 실행:

```!
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/qg-gc.py"
```

`--gc` 단독: 종료. 다른 인자와 함께: GC 후 setup 진행.

## Instructions

Execute the setup script to initialize the pipeline:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh" $ARGUMENTS
```

Now invoke `Skill("quality-gates:quality-pipeline")` with gate=1 (or the gate specified in $ARGUMENTS) to begin the first gate.

When you finish the gate, emit a `<qg-signal>` tag. The Stop hook handles pipeline progression automatically.

### Quick Reference

| Command | Effect |
|---------|--------|
| `/qg` | Full pipeline (Gate 1 → 2 → 3), session-scoped diff |
| `/qg branch` | Full pipeline, full-branch diff (vs `main`) |
| `/qg branch <name>` | Full pipeline against branch `<name>` in isolated worktree |
| `/qg --paths <glob>...` | Full pipeline, scope to matched paths |
| `/qg --reset` | Clear current session folder + legacy v1.5.0 flat files and exit |
| `/qg --gc` | Run TTL GC on stale session folders |
| `/qg gate1` | Plan verification only |
| `/qg gate2` | PR review only |
| `/qg gate3` | Runtime verification only |
| `/qg --skip-runtime` | Gates 1 & 2 only (skip runtime) |
| `/qg --plan <path>` | Use specific plan file |
| `/qg --pr-url <url>` | Specify PR URL |
| `/cancel-qg` | Cancel active pipeline |
| `DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1` | Disable `/qg branch <name>` auto-worktree mode |
| `DEVBREW_QG_KEEP_WORKTREE=1` | Preserve branch worktree after pipeline completes or is cancelled (default: removed) |

### Scope (default: session)

`/qg` reviews files **edited in the current Claude Code session** by default.
A PostToolUse hook (`post-tool-use-session-tracker.py`) accumulates touched
files into `.claude/quality-gates/<session-id>/files.md`. The pre-pipeline check
(`pre-pipeline-check.sh`) clears this file when the branch changes mid-session
or when 24+ hours pass without activity.

Override with `/qg branch` (full branch) or `/qg --paths <glob>...` (manual).

### Cost guidance

Approximate cost per run vs default-Opus baseline (full-branch + cross-gate
loop, the pre-redesign behavior):

| Auto-detected depth | Cost | Trigger |
|---|---|---|
| Trivia | ~0% | ≤3 lines whitespace/rename single file |
| Quick | ~25–35% | <50 LOC, single concern, no new files |
| Standard | ~30–45% | 50–199 LOC or multi-file simple |
| Deep | ~55–75% | ≥200 LOC, new files, config changes (AskUserQuestion gate fires) |

Set `DEVBREW_DISABLE_QUALITY_GATES=1` to globally disable. Set
`DEVBREW_SKIP_HOOKS=quality-gates:session-tracker` to disable just the
session-tracker hook (keeps Stop hook + advisor active).

### Gates

1. **Plan Verification** — Checks all planned items are implemented
2. **PR Review** — Iterative code review (scout → Phase 1+2 → adversarial → synthesizer); within-gate fix-loop up to 5 iterations
3. **Runtime Verification** — Launches app and verifies behavior with browser automation

### Pipeline Rules

- Pipeline progression managed by Stop hook (no manual gate transitions needed)
- **Forward-only state machine**: Gate 2/3 NEEDS_RESTART terminates with user
  choice ("apply changes and re-run /qg"); does NOT auto-restart from Gate 1
- Gate 2 iterates up to 5 times internally (`max_gate2_iterations`)
- Repeat-detection: identical iterations trigger early user choice
- State tracked in `.claude/quality-gates/<session-id>/{pipeline,files,branch}.md` (managed by hook scripts; see plugin README)
