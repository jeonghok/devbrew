---
description: "Run the quality gates pipeline (review → runtime verification)"
argument-hint: "[review|runtime|both] [branch [<name>]|--paths <glob>...|--reset] [--skip-runtime] [--plan <path>] [--pr-url <url>]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh:*)", "Bash(rm:*)", "Bash(test:*)", "Agent", "Skill", "Bash", "Read", "Edit", "Write", "Glob", "Grep"]
---

# Quality Gates Pipeline

Run the 2-gate quality verification pipeline to ensure code quality before PR merge.

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

Now invoke `Skill("quality-gates:quality-pipeline")` with the parsed
arguments. The skill runs the pipeline in this turn — after the
gate-scope question it runs the Review gate (with internal fix-loop) and,
when both gates are selected, the Runtime gate — surfacing decision points
via AskUserQuestion. No further commands are needed unless the pipeline
is aborted at a decision point.

### Quick Reference

| Command | Effect |
|---------|--------|
| `/qg` | Ask gate scope (Review only / both), then run; session-scoped diff |
| `/qg both` | Full pipeline (both gates), no gate-scope question; session-scoped diff |
| `/qg branch` | Ask gate scope, then run; full-branch diff (vs `main`) |
| `/qg branch <name>` | Ask gate scope, then run against branch `<name>` in isolated worktree |
| `/qg --paths <glob>...` | Ask gate scope, then run; scope to matched paths |
| `/qg --reset` | Clear current session folder + legacy v1.5.0 flat files and exit |
| `/qg --gc` | Run TTL GC on stale session folders |
| `/qg review` | Review gate only |
| `/qg runtime` | Runtime gate only |
| `/qg --skip-runtime` | Review gate only (skip runtime) |
| `/qg --plan <path>` | Use specific plan file |
| `/qg --pr-url <url>` | Specify PR URL |
| `/cancel-qg` | Cancel active pipeline |
| `/qg-publish [--dry-run]` | Generate + publish a PR-understanding comment (separate skill; consent-gated; not a gate) |
| `DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1` | Disable `/qg branch <name>` auto-worktree mode |
| `DEVBREW_QG_KEEP_WORKTREE=1` | Preserve branch worktree after pipeline completes or is cancelled (default: removed) |
| `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1` | Disable the Runtime gate sandbox executor (read-only smoke fallback; verdict capped at SKIP_WITH_EVIDENCE) |

### Scope (default: session)

`/qg` reviews files **edited in the current Claude Code session** by default.
A PostToolUse hook (`post-tool-use-session-tracker.py`) accumulates touched
files into `.claude/quality-gates/<session-id>/files.md`. The pre-pipeline check
(`pre-pipeline-check.sh`) clears this file when the branch changes mid-session
or when 24+ hours pass without activity.

Override with `/qg branch` (full branch) or `/qg --paths <glob>...` (manual).

빈 세션에서 커밋된 변경이 있어 resolved scope가 0인데 브랜치는 base보다 앞서 있으면 (false-clean),
qg는 "clean"이라 하지 않는다 — read-only `check-review-scope.sh`가 `changes_exist`를 결정론으로
emit하고, Review gate의 **정직-verdict floor**가 `resolved scope 0 AND changes_exist == yes`이면
verdict를 `no scope reviewed … NOT certified clean`으로 교체한다(load-bearing, kill 불가). 무엇을
리뷰할지(routing)는 모델이 소유 — 빈 scope면 모델이 `/qg branch`(전체 브랜치 리뷰)를 제안한다.
진짜 변경 없음(genuine no-op)은 그대로 `clean`; 신호가 degraded면 fail-open + loud advisory.

암묵 session scope로 돌 때 qg는 그 사실을 한 줄로 밝힌다 (`Review scope: session (N files)` — 전체
PR/브랜치는 `/qg branch`). 자연어로 브랜치/전체 리뷰 의도를 말하면 모델이 `/qg branch`(branch
scope)로 해석한다 — 별도 토큰 alias 없음 (P8 determinism-economy: non-load-bearing 라우팅은
모델 신뢰, 결정론적 보장은 literal `/qg branch`에).

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
session-tracker hook (keeps SessionStart advisor active). v1.32.0 has no
Stop hook.

### Gates

- **Review gate** — Iterative code review (scout → Phase 1+2 → adversarial → synthesizer); within-gate fix-loop up to 5 iterations
- **Runtime gate** — Launches app and verifies behavior with browser automation

### Pipeline Rules (v2.0.0)

- Pipeline runs in a single assistant turn (no Stop hook, no continuation
  sentinel, no cross-turn state machine).
- **Forward-only**: code-change verdicts terminate. The Review gate fix-loop applies
  user-consented fixes inline (orchestrator-as-writer); does NOT auto-restart
  from an earlier gate.
- The Review gate iterates up to 5 times internally; AskUserQuestion fires at every
  iteration boundary with `Retry` / `Proceed to Runtime gate` / `Stop`.
- AskUserQuestion also fires on Review gate max-iter and Runtime gate
  NEEDS_RESOLUTION.
- State tracked minimally in `.claude/quality-gates/<session-id>/pipeline.md`
  (managed by `scripts/setup-qg.sh`; SKILL reads worktree_path only).
