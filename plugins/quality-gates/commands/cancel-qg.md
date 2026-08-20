---
description: "Cancel a quality-gates pipeline session (single-turn execution in v1.32.0; this clears orphan state)"
argument-hint: "[--gc | --all]"
allowed-tools: ["Bash(test:*)", "Bash(rm:*)", "Bash(rm -rf:*)", "Bash(find:*)", "Bash(wc:*)", "Read", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/cancel-qg-core.sh:*)", "Bash(python3 ${CLAUDE_PLUGIN_ROOT}/scripts/qg-gc.py:*)", "AskUserQuestion"]
hide-from-slash-command-tool: "true"
---

# Cancel Quality Gates

v1.32.0 pipelines run in a single assistant turn — `/cancel-qg` mainly
cleans orphan state from aborted turns or `/qg` invocations that crashed
before completion.

`$ARGUMENTS` 처리:

## Default (no flags) — cancel current session's pipeline

**왜 Bash 블록 안에서 SID 가드를 다시 검사하는가:** `$CLAUDE_CODE_SESSION_ID`가
비어 있거나 패턴이 깨진 채 `rm -rf ".claude/quality-gates/$SID"`로 expand되면
`rm -rf ".claude/quality-gates/"`가 되어 **동시에 실행 중인 모든 세션 폴더가
지워짐**. LLM prose ("비어있으면 종료")는 가드가 아니다. 셸이 보장한다.

1. **세션 ID 가드 + 폴더 검사** (한 Bash 블록에서):
   ```!
   SID="${CLAUDE_CODE_SESSION_ID:-}"
   if [[ -z "$SID" || ! "$SID" =~ ^[A-Za-z0-9_-]{8,}$ ]]; then
     echo "NO_VALID_SID"
     exit 0
   fi
   if test -d ".claude/quality-gates/$SID"; then
     echo "EXISTS:$SID"
   else
     echo "NOT_FOUND:$SID"
   fi
   ```
2. **NO_VALID_SID**: "Cannot determine session ID — no active pipeline." 종료.
3. **NOT_FOUND**: "No active quality gates pipeline found for this session." 종료.
4. **EXISTS**:
   - `Read(.claude/quality-gates/<SID>/pipeline.md)`로 frontmatter 읽기. v1.32.1 minimal schema의 실제 필드: `session_id`, `started_at`, `runtime_max_resolutions` (v1.32.1 C3 복구), optional `worktree_path` / `target_branch`. (v1.5.x의 `status` / `current_gate` / review-iteration 필드는 v1.32.0/v1.32.1에서 제거됨 — 실제 iteration counter는 `## History` 섹션의 append-only 라인으로 추적.)
   - 폴더 삭제: `cancel-qg-core.sh` 헬퍼 호출 (SID 가드 + worktree-aware cleanup 내장; command와 test가 동일 코드 경로 사용 — spec §5.8 TQ-2):
     ```!
     bash "${CLAUDE_PLUGIN_ROOT}/scripts/cancel-qg-core.sh"
     ```
   - 헬퍼는 성공 시 `cancel-qg-core: removed ...`을 stdout으로 출력, 실패 시 stderr + non-zero exit. `worktree_path:` 필드가 있고 `DEVBREW_QUALITY_GATES_KEEP_WORKTREE=1`이 아니면 헬퍼가 `qg-worktree.sh remove`도 호출.
   - 보고: "Cancelled quality gates pipeline (session_id: <SID>, started_at: <ISO>, worktree: <path or 'none'>)".

## `--gc` — cancel + immediate TTL sweep

1. Default 액션 수행 (자기 세션 폴더 삭제 — 위 SID 가드 적용).
2. `Bash("python3 ${CLAUDE_PLUGIN_ROOT}/scripts/qg-gc.py")` 실행 → stale sibling 폴더 정리.

## `--all` — wipe all session folders (REQUIRES CONFIRM)

1. 살아있는 sibling 카운트 (mtime < 1h):
   ```!
   find .claude/quality-gates -mindepth 1 -maxdepth 1 -type d -mmin -60 2>/dev/null | wc -l
   ```
2. `AskUserQuestion`을 사용해 사용자에게 확인:
   - 질문: "Delete ALL quality-gates session folders? N appear active (mtime < 1h)."
   - 옵션: "Yes, delete all" / "No, abort"
3. **Yes**: 정확한 경로만 지우도록 가드된 Bash 블록 사용:
   ```!
   [[ -d ".claude/quality-gates" ]] || { echo "NOTHING_TO_DELETE"; exit 0; }
   rm -rf -- ".claude/quality-gates" && echo "REMOVED_ALL" || echo "FAILED_ALL"
   ```
   보고: "Removed all session folders."
4. **No**: 보고 "Aborted." 종료.
