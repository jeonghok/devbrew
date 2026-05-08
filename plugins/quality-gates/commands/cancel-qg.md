---
description: "Cancel active quality gates pipeline"
argument-hint: "[--gc | --all]"
allowed-tools: ["Bash(test:*)", "Bash(rm:*)", "Bash(rm -rf:*)", "Read", "Bash(python3 ${CLAUDE_PLUGIN_ROOT}/scripts/qg-gc.py:*)"]
hide-from-slash-command-tool: "true"
---

# Cancel Quality Gates

`$ARGUMENTS` 처리:

## Default (no flags) — cancel current session's pipeline

1. session ID 결정:
   - 환경변수 `CLAUDE_CODE_SESSION_ID` 사용. 비어있으면 "Cannot determine session ID — no active pipeline."로 종료.
2. 자기 세션 폴더 검사:
   ```!
   test -d ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID" && echo EXISTS || echo NOT_FOUND
   ```
3. **NOT_FOUND**: "No active quality gates pipeline found for this session." 종료.
4. **EXISTS**:
   - `Read(.claude/quality-gates/$CLAUDE_CODE_SESSION_ID/pipeline.md)`로 frontmatter (`status`, `current_gate`, `gate2_iteration`) 읽기.
   - 폴더 통째 삭제: `Bash("rm -rf .claude/quality-gates/$CLAUDE_CODE_SESSION_ID")`.
   - 보고: "Cancelled quality gates pipeline (was at Gate N, iteration M)".

## `--gc` — cancel + immediate TTL sweep

1. Default 액션 수행 (자기 세션 폴더 삭제).
2. `Bash("python3 ${CLAUDE_PLUGIN_ROOT}/scripts/qg-gc.py")` 실행 → stale sibling 폴더 정리.

## `--all` — wipe all session folders (REQUIRES CONFIRM)

1. 살아있는 sibling 카운트 (mtime < 1h):
   ```!
   find .claude/quality-gates -mindepth 1 -maxdepth 1 -type d -mmin -60 2>/dev/null | wc -l
   ```
2. `AskUserQuestion`을 사용해 사용자에게 확인:
   - 질문: "Delete ALL quality-gates session folders? N appear active (mtime < 1h)."
   - 옵션: "Yes, delete all" / "No, abort"
3. **Yes**: `Bash("rm -rf .claude/quality-gates")` + 보고 "Removed all session folders."
4. **No**: 보고 "Aborted." 종료.
