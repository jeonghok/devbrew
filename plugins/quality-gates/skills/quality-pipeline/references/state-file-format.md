# State File Format (v1.32.1)

> v1.32.0 breaking change: cross-turn pipeline state는 SKILL의 단일 턴
> 시리얼 디스패치로 흡수됨. 본 state file은 **GC mtime anchor + worktree
> tracking + Runtime gate resolution-cap reporting**만 보존한다.
>
> v1.32.1 (review-driven): review-iteration phantom 필드 제거(I11),
> `runtime_max_resolutions:` 필드 추가(C3).

The state file `.claude/quality-gates/<session-id>/pipeline.md` (per-session)
is created by the setup script (`scripts/setup-qg.sh`) on `/qg` invocation
and deleted by `/cancel-qg`, `/qg --reset`, or the TTL GC
(`scripts/qg-gc.py`, default 24h).

`<session-id>` resolves from `$CLAUDE_CODE_SESSION_ID`; siblings under
`.claude/quality-gates/` belong to other concurrent Claude Code sessions
and must not be touched.

**SKILL.md must NOT write this file.** SKILL.md MAY read `worktree_path`
during preflight to confirm working directory; nothing else.

## Schema

```yaml
---
session_id: "<session_id>"           # CLAUDE_CODE_SESSION_ID
started_at: "<ISO-8601 UTC>"         # setup-qg.sh timestamp
runtime_max_resolutions: 3           # DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS clamped 0..10
worktree_path: "<absolute path>"     # OPTIONAL — set only when /qg branch <name> used
target_branch: "<branch name>"       # OPTIONAL — paired with worktree_path
---

# Quality Gates Pipeline State (v1.32.1)

## History

(SKILL appends one line per gate verdict for in-turn observability.)

- [2026-05-27T10:00:00Z] Pipeline started
- [2026-05-27T10:05:00Z] Review gate iter 1: 1 CRITICAL / 2 IMPORTANT / 1 SUGGESTION → user chose Retry
- [2026-05-27T10:08:00Z] Review gate iter 2: PASS
- [2026-05-27T10:12:00Z] Runtime gate: PASS
- [2026-05-27T10:12:01Z] Pipeline complete
```

## Removed Fields (vs v1.x)

The following v1.x fields are **no longer written or read**:

| Removed | Reason |
|---|---|
| `status` | No cross-turn state machine. Pipeline is single-turn. |
| `current_gate` | SKILL dispatches Review gate → Runtime gate inline. |
| `consecutive_no_signal` | `<qg-signal>` tag removed. |
| `max_review_iterations` | Hard-coded constant in SKILL (5). |
| `runtime_resolution_iter` | Hard-coded constant in SKILL (default 3, env override). |
| `last_runtime_needed_hash` | Repeat detection moves to inline AskUserQuestion. |
| `max_runtime_resolutions` | Renamed to `runtime_max_resolutions:` (C3 restored in v1.32.1). |
| `review_iteration` | Phantom field — counter lives in `## History` section only (I11 v1.32.1). |
| `skip_runtime` | Passed as SKILL invocation arg. |
| `single_gate` | Passed as SKILL invocation arg. |
| `plan_file` | Passed as SKILL invocation arg. |
| `pr_url` | Passed as SKILL invocation arg. |
| `available_plugins` | SKILL re-derives inline (cheap). |
| `project_dir` | Derived from `pwd` at SKILL preflight (single-turn invariant). |

Companion files in the same folder (`files.md` for session-scope tracking,
`branch.md` for branch-mismatch detection) follow the same per-session
lifecycle and are unchanged from v1.x.

## Lifecycle

1. **Created by**: `scripts/setup-qg.sh` (on `/qg`) — also `mkdir -p`s the
   per-session folder.
2. **Updated by**: SKILL.md may *append* to the `## History` section for
   observability. Frontmatter is write-once at setup.
3. **Deleted by**: `/cancel-qg`, `/qg --reset`, `hooks/session-end-cleanup.py`
   on graceful session end, or `scripts/qg-gc.py` (TTL GC).
