---
description: "Cancel a quality-gates pipeline session (single-turn execution in v1.32.0; this clears orphan state)"
argument-hint: "[--gc | --all]"
hide-from-slash-command-tool: "true"
---

# Cancel Quality Gates

<!-- plain-language:begin -->
## 사람에게 쓰는 글
이 절은 사용자에게 보이는 글(답변·보고·질문·선택지·경고·PR 본문·커밋)에만 적용한다. 지시문·subagent 프롬프트·state 파일에는 적용하지 않는다. 아래 절차가 출력 형식·원문 보존·분량을 따로 정한 자리에서는 그 절차를 따른다.
- 처음 보는 사람이 한 번에 이해하게 쓴다. 번호·해시·필드 이름·내부 용어는 가리키는 내용을 문장으로 먼저 쓰고 괄호 안에만 둔다. 지어낸 말은 쓰지 않거나 처음 쓸 때 풀어 쓴다.
- 순서: 첫 줄에 지금 상태(무엇을 했고 어디까지 왔나) 한 문장, 가운데에 이유·근거, 맨 끝에 사용자가 할 일 하나. 할 일이 없으면 없다고 쓴다.
- 질문 하나에 결정 하나. 선택지 이름은 짧은 쉬운 말로, 설명에는 고르면 무엇이 달라지는지만 쓴다. 본문에 없던 주제를 선택지에서 꺼내지 않는다. 추천은 「(권장)」으로 표시한다.
- 제목과 목록으로 나누되 표의 칸은 짧게 쓴다. 굵은 글씨는 꼭 필요한 곳에만 쓴다.
- 사용자가 알 필요 없는 글은 쓰지 않는다: 도구 호출 사이의 진행 설명, 전부 정상인 항목의 나열. 확인해서 남은 것도 경고도 없으면 「이상 없음」 한 줄로 쓴다. 확인하지 못한 것·빠진 검사·셀 수 없는 것은 따로 한 줄씩 쓴다 — 없는 것과 확인 못 한 것은 다르다.
- 판정·개수·공시 줄은 스크립트가 낸 쉬운 첫 줄을 그대로 쓰고, 자기 말로 다시 풀거나 덧붙이지 않는다. 스크립트·subagent 가 낸 원문은 고치지 않는다. 스크립트가 풀어 두지 않은 오류에만 쉬운 설명을 앞에 붙이되 통과·실패는 말하지 않는다.
- 사용자와 대화하는 언어로 쓴다. 코드·명령·고유명사·자연스러운 대응어가 없는 기술어는 영어 그대로 둔다. 커밋·PR은 그 레포의 규칙을 따르고, 없으면 대화 언어로 쓴다.
예) 전: `[미적용 fix] 3720b2b7#r1.1` → 후: 리뷰가 고치라고 한 곳 하나가 아직 안 고쳐졌다(3720b2b7#r1.1).
예) 전: (codex 정상 · 재비판 정상 · 저자 편집 없음 · ask_open 0건) → 후: 이상 없음.
<!-- plain-language:end -->

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
   - `Read(.claude/quality-gates/<SID>/pipeline.md)`로 frontmatter 읽기. v1.32.1 minimal schema의 실제 필드: `session_id`, `started_at`, optional `worktree_path` / `target_branch`. (v1.5.x의 `status` / `current_gate` / review-iteration 필드는 v1.32.0/v1.32.1에서 제거됨 — 실제 iteration counter는 `## History` 섹션의 append-only 라인으로 추적.)
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
3. **Yes**: 정확한 경로만 지우도록 가드된 Bash 블록 사용(`-d` 는 링크를 따라가므로 링크 검사가 먼저다):
   ```!
   [[ -L ".claude" || -L ".claude/quality-gates" ]] && { echo "REFUSED_SYMLINKED_ROOT"; exit 0; }
   [[ -d ".claude/quality-gates" ]] || { echo "NOTHING_TO_DELETE"; exit 0; }
   rm -rf -- ".claude/quality-gates" && echo "REMOVED_ALL" || echo "FAILED_ALL"
   ```
   보고 — `REMOVED_ALL`: "Removed all session folders." · `REFUSED_SYMLINKED_ROOT`: "state root 가 심볼릭 링크라 지우지 않았다 — 링크 너머는 저장소 밖일 수 있다. 직접 확인하고 지워라." · `NOTHING_TO_DELETE`: "No session folders to delete." · `FAILED_ALL`: "Failed to remove session folders."
4. **No**: 보고 "Aborted." 종료.
