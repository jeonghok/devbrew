---
name: spec-distill-hook-context-injection
version: 1.2.0
created_at: 2026-05-17
session_id: brainstorm-2026-05-17
status: locked
next_phase: writing-plans
review_rounds: 2
source: superpowers/brainstorming + empirical hook firing 증거 (state.local.md 흔적 + 수동 재현 stdout) + Claude Code 공식 hook 사양 (code.claude.com/docs/en/hooks, 본 doc §C4에 verbatim quote) + quality-gates reference 패턴 (plugins/quality-gates/hooks/stop-hook.py:845-849)
---

# spec-distill — Hook Output Context Injection Fix 디자인 스펙 (v0.5.0)

> **For agentic workers:** 이 문서는 `plugins/spec-distill/`의 5개 hook 모두가 stdout에 `systemMessage` 필드만 사용하여 Claude LLM context로 메시지를 도달시키지 못하던 silent failure를 수정하기 위한 v0.5.0 변경 명세이다. `systemMessage`는 Claude Code 사양상 user transcript 표시 전용이며 LLM context inject 메커니즘이 아니다. 올바른 필드는 `hookSpecificOutput.additionalContext` (PostToolUse/UserPromptSubmit/SessionStart) 또는 Stop hook의 `decision:"block" + reason` 페어. 5개 hook을 모두 정정하여 reviewer dispatch 안전망(L1 PostToolUse advisory → L3 Stop mandate → L4b UserPromptSubmit reminder)이 *실제로* Claude에게 도달하게 만든다. 다음 단계는 superpowers `writing-plans` skill로 implementation plan을 생성하는 것이다.

## 목차

- §1 [Goal](#goal)
- §2 [Context / Why](#context--why)
- §3 [Goals](#goals)
- §4 [Non-goals](#non-goals)
- §5 [Constraints](#constraints)
- §6 [Acceptance Criteria](#acceptance-criteria)
- §7 [Files to Modify](#files-to-modify)
- §8 [Verification Plan](#verification-plan)
- §9 [Rejected Alternatives](#rejected-alternatives) — §9.0 Adopted Approach / §9.1 Rejected
- §10 [Metadata](#metadata)

## Goal

본 PR은 **3개 독립 deliverable**을 한 묶음으로 ship한다. 각 deliverable은 독립적으로 implementation 가능하지만 한 PR로 머지하는 이유는 §Coupling 근거에 명시. writing-plans 단계에서 task 순서는 (a) → (b) → (c) — (b)는 (a)에 의존, (c)는 (a)+(b) 검증 통과 후 마지막에.

- **(a) Hook 코드 정정 (load-bearing 변경)**: `plugins/spec-distill/hooks/`의 5개 hook (`review-dispatch.py`, `spec-write-validator.py` advisory 분기, `pending-review-reminder.py`, `interview-trigger.sh`, `session-anchor.sh`) stdout JSON을 dual-target 패턴으로 변경. Claude-target field (`hookSpecificOutput.additionalContext` 또는 `decision:"block"+reason`) + `systemMessage` (짧은 user-visible 흔적, ≤120자). 기존 `systemMessage`-only 출력은 모두 제거. Stop hook의 경우 추가로 `rewrite_state()` 호출 순서를 `print()` *이전*으로 변경 (TTL guard race condition fix, §AC7 참조).
- **(b) 회귀 방지 test 신설 (compounding 산출물)**: `plugins/spec-distill/tests/test_hook_output_schema.py` 신설. 5개 hook 모두에 대해 (env_setup, stdin_payload | state_fixture, expected_fields) 테이블로 parametrize된 unittest 케이스. Stop hook은 stdin 대신 temp state file fixture로 dispatch trigger (§AC12 fixture strategy 참조). 기존 4개 bash test 파일의 assertion도 systemMessage substring grep → jq JSON path assertion으로 갱신.
- **(c) 메타데이터 + 문서 동기화**: `plugin.json` v0.4.0 → v0.5.0 minor bump (cache key 갱신). `CHANGELOG.md`에 `[0.5.0] — 2026-05-17` Fixed/Changed/Security entry. `README.md` Hooks 섹션에 dual-target output 패턴 문서화 + "Principles Instantiated"에 Law 2/3 instantiation 라인 추가.

**Coupling 근거 (왜 5개 hook을 한 PR에)**: 본 plugin의 reviewer dispatch는 *3단 안전망* (L1 PostToolUse advisory + L3 Stop mandate + L4b UserPromptSubmit reminder)으로 설계됐다. 셋 중 어느 하나만 systemMessage-only로 남기면 그 단의 fallback이 그대로 silent fail — 다른 두 단이 (인프라 race condition 등으로) 실패할 때 안전망이 작동하지 않는다. 사용자가 보고한 incident 자체가 "Stop hook은 발화했으나 Claude context에 도달 안 함"이었고, 같은 시점에 후속 UserPromptSubmit reminder도 *같은 버그로* silent fail이 보장된 상태였다. 5개 hook을 한 묶음으로 고쳐야 안전망이 의도대로 작동하는 *살아있는 baseline*이 만들어진다. (interview-trigger / session-anchor는 의도가 user advisory 우선이나 `additionalContext`로 보내도 user는 동일 메시지를 `systemMessage` 짧은 라인으로 보고 Claude도 컨텍스트를 가져 더 잘 보조 — 손실 없음). 롤백 단위(`git revert <pr-merge-sha>`)도 단일 commit이 되어 단순.

## Context / Why

사용자가 본 세션 직전에 다음 incident를 보고했다:

- 05:02:15 UTC — `2026-05-17-project-init-docs-lint-hook-design.md` spec commit (5ba3c4a)
- 05:02:50 UTC — `review-dispatch.py` (Stop) 발화, state의 `last_dispatched_at` 35초 후 갱신 (디스크 흔적 확인됨)
- 그러나 다음 user turn에서 Claude에게 "MANDATORY: 다음 turn 첫 액션으로 reviewing-spec skill 호출" 메시지는 *전달되지 않음*. Claude는 reviewer dispatch가 mandated된 사실을 인지하지 못한 채 다른 작업으로 진행.

사용자의 진단 (state 흔적 + 수동 hook 재현으로 검증):

| Layer | 상태 | 비고 |
|---|---|---|
| hooks.json 등록 | ✅ | plugins/spec-distill/hooks/hooks.json:31,43 |
| spec-write-validator 실행 | ✅ | state에 `pending_review:` 기록 흔적 |
| review-dispatch 실행 | ✅ | state의 `last_dispatched_at` 35초 후 갱신 |
| 두 hook의 stdout JSON 출력 | ✅ | 수동 재현 확인 |
| Claude Code: hook stdout → LLM context inject | ❌ | **silent loss** |

Root cause는 plugin 코드가 아니라 *output schema 선택* 이다. Claude Code hook 사양 (code.claude.com/docs/en/hooks 확인):

- `systemMessage` — user에게만 표시되는 warning 메시지. **LLM context inject 안 됨**.
- `hookSpecificOutput.additionalContext` — Claude LLM context에 system reminder로 inject됨. PostToolUse / UserPromptSubmit / SessionStart 등에서 지원.
- Stop hook의 `decision:"block"` + `reason` — Stop을 막고 Claude를 즉시 continue 시키며, `reason`이 Claude system message로 보임 (사용자에게는 reason도 함께 표시됨, dual-target).

reference 구현: `plugins/quality-gates/hooks/stop-hook.py:845-849` 가 정확한 패턴 (Claude-target field + systemMessage 페어):
```python
print(json.dumps({
    "decision": "block",
    "reason": prompt,         # ← Claude가 봄
    "systemMessage": sys_msg, # ← user transcript에 보존
}))
```

본 plugin의 5개 hook 모두 stdout이 `{"systemMessage": "..."}` 한 줄이라 reviewer dispatch 메시지가 Claude에게 전혀 도달하지 않는다. 따라서 v0.3.0(`review-dispatch.py` 도입)부터 v0.4.0(`pending-review-reminder.py` 도입) 까지 본 plugin의 dispatch 신뢰성은 *완전히 silent하게* 0%였다. spec/design 작성자가 reviewer 호출을 "수동으로" 기억해서 호출한 경우에만 실제로 reviewer가 돌았다. 안전망 3단이 모두 같은 버그로 inoperative.

devbrew CLAUDE.md *§The Three Laws*: "**Law 2 — Writer and Reviewer Must Never Share a Pass.** ... 검증은 load-bearing 인프라, 나중 생각이 아님." 이번 fix는 Law 2의 *infrastructure operability* 자체를 보장하는 fix이다 — 분리 설계는 이미 좋았으나 dispatch가 reach하지 않으면 어떤 reviewer persona 분리도 무의미.

devbrew CLAUDE.md *§Forbidden Patterns*: "**버그가 리뷰를 탈출하면**, 해결책은 잡았어야 할 reviewer persona 파일을 편집하는 것 — 코드만 패치하는 게 아님. 그 commit이 compounding 이벤트 (Law 3)." 이번 incident에서 reviewer가 *아예 호출되지 않았으므로* persona 편집은 적용 불가. 대신 Law 3 instantiation은 (a) hook 코드 수정 + (b) output schema 회귀 방지 test (`test_hook_output_schema.py`) 추가 + (c) CHANGELOG/README의 명시적 기록 + (d) 본 design doc 자체. 회귀가 다시 발생하면 test가 잡고, 패턴이 잊혀지면 design doc과 README가 다시 찾아준다.

## Goals

- **G1 — 5개 hook의 Claude-target 메시지가 실제로 inject됨**: `review-dispatch.py` (Stop), `spec-write-validator.py` advisory branch (PostToolUse), `pending-review-reminder.py` (UserPromptSubmit), `interview-trigger.sh` (UserPromptSubmit), `session-anchor.sh` (SessionStart) 모두 적절한 Claude-target 필드 사용.
- **G2 — Dual-target output 패턴 채택**: 모든 hook이 Claude-target field와 `systemMessage`를 함께 emit. Claude는 context로 받고, user는 transcript에서 hook 발화 흔적 확인 가능. 디버깅 가능성 보존.
- **G3 — Stop hook의 dispatch 보장이 즉시 continue로 실현 (조건부)**: `review-dispatch.py`의 `decision:"block"`이 Stop을 막고 Claude를 다음 model request로 즉시 진입시킴 → "다음 turn 첫 액션은 reviewing-spec" 강제가 user 입력 대기 없이 작동. TTL guard (`DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=30`)가 무한 block 루프 방지하나, **이는 `rewrite_state()`가 `print()`보다 먼저 실행되어 OS에 flush된다는 ordering 전제 위에서만 성립** (§AC7). 현재 코드는 print→rewrite 순서로 race condition 가능 (Reviewer round-1 issue 83dc5425) — 본 PR이 ordering 정정 포함.
- **G4 — Output schema 회귀 방지 test**: 신규 `tests/test_hook_output_schema.py`가 5개 hook의 happy-path stdout을 jq schema assertion으로 검증. 누군가 다시 `systemMessage`-only로 떨어뜨리면 CI에서 즉시 잡힘.
- **G5 — 기존 동작 모두 보존**: state machine (`pending_review:` 블록 + `last_dispatched_at` TTL guard), kill switches (`DEVBREW_DISABLE_SPEC_DISTILL=1` + `DEVBREW_SKIP_HOOKS=spec-distill:<event>`), worktree path resolution (`state_path.state_root()`), cleanup 정책 (24h pending purge / 7일 state file purge), block 분기의 `decision:"block"+reason` 패턴 — 전부 무손상.
- **G6 — devbrew Plugin Shape 준수**: `plugin.json` minor bump (`0.4.0` → `0.5.0`, Claude 가시성 동작 변경 = new behavior surface), `CHANGELOG.md`에 `[0.5.0] — 2026-05-17` entry (Fixed + Changed), `README.md` Hook 섹션에 dual-target output 패턴 문서화.
- **G7 — devbrew Plugin Shape "Loud logging" 준수 (test-only 범위)**: hookSpecificOutput schema 회귀를 잡는 메커니즘은 **`test_hook_output_schema.py`만**으로 한정 (runtime self-check 추가 안 함 — hook 코드 추가 변경 회피). 현재 PR 범위에서는 CI 통과 시 schema가 보장됨. 향후 runtime self-check 필요성 발견 시 별도 PR. Round-2 advisory NEW (G7 명확화) fix.

## Non-goals

- **NG1 — quality-gates / project-init의 systemMessage audit 안 함**: 사용자가 보고한 plugin 경계 내로 한정 (Approach B). quality-gates `post-tool-use.py:81`의 PR-creation systemMessage 같은 건 의도적 user-only일 가능성 (user가 다음 prompt로 `/qg`를 직접 invoke하도록 설계됨) → 별도 audit/PR 필요. project-init `post-tool-use.py`는 advisory branch+commit 검증으로 user가 직접 보고 수정하는 흐름이 의도 → 손대지 않음. *향후 별도 PR에서* devbrew-wide systemMessage audit 가능.
- **NG2 — Hook stdout aggregation 인프라 conflict 해결 안 함**: 사용자 진단의 가설 3 (동일 PostToolUse event에 multi-hook 발화 시 stdout aggregation race condition)은 Claude Code 인프라 레이어 이슈로 plugin 범위 밖. 본 fix 이후에도 재현되면 별도 issue로 Anthropic에 보고.
- **NG3 — Hook 동작 로직 자체 변경 안 함**: 룰 추가/제거, threshold 조정, 신규 event matcher 등 일체 없음. Pure output field 교체 + 회귀 방지 test 추가만.
- **NG4 — State machine 변경 안 함**: `pending_review:` 블록 schema, `last_dispatched_at` field, TTL guard sec, 24h/7일 cleanup 정책 무손상.
- **NG5 — Kill switch 새로 추가 안 함**: 기존 `DEVBREW_DISABLE_SPEC_DISTILL=1` + `DEVBREW_SKIP_HOOKS=spec-distill:<event>` 그대로 사용. 신규 env var 없음 (devbrew LD10 일관성).
- **NG6 — reviewing-spec skill / spec-reviewer agent / drafting-spec skill 변경 안 함**: hook 정정으로 dispatch가 reach하기 시작하면 기존 skill/agent가 그대로 작동해야 함. 추가 변경 시 PR 분리.
- **NG7 — `decision:"block"` 사용을 PostToolUse advisory 분기로 확장 안 함**: PostToolUse advisory는 *정보 전달* 의도이지 차단이 아님 → `additionalContext`가 올바른 선택. block 분기 (현재 line 103–108)는 이미 `decision:"block"+reason` 사용 중이며 무손상.
- **NG8 — 한 turn 안에서 reviewing-spec skill 자동 invoke 안 함**: Stop hook의 `decision:"block"`이 Claude를 continue 시키지만, 실제 skill 호출은 Claude의 다음 model request에서 reason을 보고 *결정*함. hook이 skill을 직접 호출하지 않음 (Claude Code는 그런 메커니즘 없음).
- **NG9 — Cross-hook path resolver unification 안 함**: `state_path.state_root()` (Python) 와 `${CLAUDE_PROJECT_DIR:-$PWD}/.claude/spec-distill` (bash session-anchor.sh) 의 다른 resolution 전략. 본 PR은 output schema fix 범위로 한정, path resolver 통합은 후속 PR에서 진행. 본 PR에서는 `test_hook_output_schema.py`에 advisory 비교 test만 추가 (skipUnless).

## Constraints

- **C1 — Python 3 stdlib + jq only**: 기존 hook들이 `json`/`os`/`re`/`sys` + bash `jq`만 사용. 외부 의존성 추가 없음. `test_hook_output_schema.py`는 Python stdlib `unittest` + `subprocess` + `json`.
- **C2 — Hook timeout 5–10s 유지**: `hooks.json`의 기존 timeout 값 (5초 reminder, 10초 그 외) 변경 없음. output field 교체는 ms 수준 성능 차이.
- **C3 — JSON I/O 계약 준수**: stdin = Claude Code의 hook input payload, stdout = 단일 JSON object. parse 실패 / 출력 실패 시 `{}` exit 0 (graceful degradation, 기존 동작 보존).
- **C4 — Output JSON 구조 (Claude Code 공식 사양 verbatim)**:

  본 문서 작성 시점(2026-05-17) `code.claude.com/docs/en/hooks`에서 직접 fetch한 인용:

  - **PostToolUse 예시 (decision + additionalContext 결합 가능)**:
    ```json
    {
      "decision": "block",
      "reason": "Tool output validation failed",
      "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": "File created but contains syntax errors"
      }
    }
    ```
    → 본 PR의 spec-write-validator advisory 분기는 `decision` 없이 hookSpecificOutput만 사용:
    ```json
    {
      "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": "[spec-distill] <mode> structural OK. Reviewer will be dispatched at turn end (Stop hook will mandate reviewing-spec skill invocation)."
      },
      "systemMessage": "[spec-distill] <mode> OK · reviewer dispatch pending"
    }
    ```

  - **UserPromptSubmit 사양 (verbatim 인용)**:
    > `additionalContext` | String added to Claude's context alongside the submitted prompt.

    예시:
    ```json
    {
      "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": "My additional context here"
      }
    }
    ```

  - **SessionStart 사양 (verbatim 인용)**:
    > `additionalContext` | String added to Claude's context at the start of the conversation, before the first prompt.

    예시:
    ```json
    {
      "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": "Current branch: feat/auth-refactor\n..."
      }
    }
    ```

  - **Stop 사양 (verbatim 인용 — hookSpecificOutput 미사용, top-level decision 패턴)**:
    > Events | Decision pattern | Key fields
    > `Stop`, `SubagentStop` | Top-level `decision` | `decision: "block"`, `reason`

    예시:
    ```json
    {
      "decision": "block",
      "reason": "Tests must pass before stopping"
    }
    ```
    → 본 PR의 review-dispatch.py는 `systemMessage`를 추가하여 dual-target:
    ```json
    {
      "decision": "block",
      "reason": "MANDATORY: 다음 turn 첫 액션으로 reviewing-spec skill 호출. spec path: <path>. mode: <mode>. worktree_path: <wt>. 호출 skill의 terminal handoff(writing-plans 등)는 review pass 이후로 보류.",
      "systemMessage": "[spec-distill] reviewing-spec dispatch enforced"
    }
    ```

  - **글로벌 character cap (verbatim 인용)**:
    > Hook output strings, including `additionalContext`, `systemMessage`, and plain stdout, are capped at 10,000 characters. Output that exceeds this limit is saved to a file and replaced with a preview and file path.

- **C5 — `hookSpecificOutput.hookEventName`은 OPTIONAL hint (verbatim 사양)**: 공식 문서에 명시적으로 "hookEventName"이 required로 표기되지 않음. SessionStart 문서는 *"a hook that only loads context can print to stdout directly without building JSON"* 라고 plain stdout도 허용. 그럼에도 본 PR은 dual-target 출력에 `systemMessage` 등을 결합하므로 JSON form 필수이며, hookEventName을 명시 포함하여 (a) 미래 docs 변경에 대비한 defensive, (b) IDE/grep 친화 (어느 hook의 output인지 즉시 인지). `test_hook_output_schema.py`가 schema assertion으로 검증 (AC12).
- **C6 — `decision:"block"`의 TTL guard 필수 + ordering 전제 (Stop hook)**: 무한 block 루프 방지. `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC` (default 30s) 이미 구현됨. **핵심: `rewrite_state()` 호출이 `print()` 이전에 완료**되어야 race-free. 현재 코드(review-dispatch.py line 122 print → lines 123–127 rewrite)는 inverted ordering으로 race 위험 — 본 PR이 ordering 정정 (§AC7).
- **C7 — Kill switch는 보안 컨트롤 (devbrew CLAUDE.md §Plugin Shape)**: 어떤 dispatch 메시지든 kill switch active면 모두 `{}` exit. 우회 로직 금지. 기존 5개 hook의 kill switch 로직 무손상.
- **C8 — `systemMessage` 길이 가이드 (단일 기준)**: dual-target output에서 systemMessage는 *user transcript에 hook 발화 흔적*이 목적 → 한 줄, **≤120자** (글로벌 10,000자 cap의 1.2% 사용). 본문은 additionalContext / reason에 들어가므로 중복 회피. AC1과 동일 기준 (C8/AC1 contradiction 해소).
- **C9 — bash hook의 fallback (no-jq) JSON 출력 보존**: `interview-trigger.sh` / `session-anchor.sh`의 manual JSON escape fallback 경로도 함께 정정. jq 없는 환경에서 동일 schema 출력.
- **C10 — Reason / additionalContext 안의 경로/문자열은 JSON 안전 round-trip 보장**: `json.dumps()` (Python) / `jq -n --arg` (bash)는 quote/backslash/newline 정확히 escape. 그러나 *bash test assertion*에서 `jq -er '.reason'` → pipe → grep으로 검증할 때 path가 shell-special 문자 (공백, `$`, backtick) 포함 시 grep 패턴이 잘못 해석될 수 있음. `test_hook_output_schema.py`는 Python `json.loads` 직접 사용으로 round-trip 안전. bash test는 `jq -e '.reason | contains("...")'` 형태로 jq 내부에서 substring 검증하여 shell 노출 회피.
- **C11 — Cross-hook path resolution 일관성**: Python hook 3개는 `state_path.state_root()` 사용, bash hook 2개 중 `session-anchor.sh`는 `${CLAUDE_PROJECT_DIR:-$PWD}/.claude/spec-distill` 직접 사용 — 두 path resolver가 동일 결과를 내야 함. `state_path.py`의 `git rev-parse --git-common-dir` 기반 resolution과 bash의 직접 path가 worktree 시나리오에서 *다른* 결과를 낼 수 있음 (worktree 내부에서 호출 시 bash는 worktree root, Python은 main repo root). 본 PR은 output schema 변경만이므로 path resolution 로직 자체는 무변화 — 하지만 `test_hook_output_schema.py`에 cross-resolver 일관성 advisory test 추가 (skipUnless로 worktree env 감지 시만 실행). 본격 fix는 후속 PR (NG 추가).

## Acceptance Criteria

### Hook output schema

- **AC1 — `review-dispatch.py` (Stop) stdout JSON에 다음 fields 모두 존재 (pending_review 있고 TTL 안 지났을 때)**:
  - `.decision == "block"`
  - `.reason` (non-empty, "MANDATORY" 단어와 `spec path:` substring 포함, `mode:` substring 포함, 있으면 `worktree_path:`)
  - `.systemMessage` (non-empty, ≤120자, "[spec-distill]" prefix)
- **AC1a — `.reason` 인코딩 안전성**: spec path가 공백 / `$` / backtick / 따옴표 / 백슬래시 / 개행 포함하더라도 `json.loads(stdout).get("reason")`로 round-trip 후 원본 path 문자열 그대로 복원되어야 함. test_hook_output_schema.py가 fixture path `"/tmp/spec dir/with $special `chars`.md"` 같은 케이스로 검증.
- **AC2 — `spec-write-validator.py` (PostToolUse) advisory 분기 stdout JSON**:
  - `.hookSpecificOutput.hookEventName == "PostToolUse"`
  - `.hookSpecificOutput.additionalContext` (non-empty, mode 단어 + "structural OK" + "Reviewer will be dispatched" 포함)
  - `.systemMessage` (non-empty, 짧음)
  - block 분기 (line 103–108)는 *변경 없음* — `{"decision":"block","reason":"..."}` 그대로 (이미 올바른 패턴).
- **AC3 — `pending-review-reminder.py` (UserPromptSubmit) stdout JSON (pending_review 있고 TTL 안 지났을 때)**:
  - `.hookSpecificOutput.hookEventName == "UserPromptSubmit"`
  - `.hookSpecificOutput.additionalContext` (non-empty, "REMINDER" + "pending_review" + "reviewing-spec" 포함)
  - `.systemMessage` (non-empty, 짧음)
- **AC4 — `interview-trigger.sh` (UserPromptSubmit) stdout JSON (build/make/create keyword + 짧은 prompt 만족 시)**:
  - `.hookSpecificOutput.hookEventName == "UserPromptSubmit"`
  - `.hookSpecificOutput.additionalContext` (non-empty, "interview" + "advisory" 포함)
  - `.systemMessage` (non-empty, 짧음)
  - jq 있는 환경 + jq 없는 환경(fallback) 둘 다 동일 schema 출력 (AC4-a / AC4-b).
- **AC5 — `session-anchor.sh` (SessionStart) stdout JSON (이전 세션 state 있을 때)**:
  - `.hookSpecificOutput.hookEventName == "SessionStart"`
  - `.hookSpecificOutput.additionalContext` (non-empty, "이전 인터뷰 세션" + "/interview" 포함)
  - `.systemMessage` (non-empty, 짧음)
  - jq 있는 환경 + jq 없는 환경(fallback) 둘 다 동일 schema 출력 (AC5-a / AC5-b).

### State machine 보존

- **AC6 — `pending_review:` 블록 schema 무변화**: `spec-write-validator.py`가 state에 쓰는 4-field 블록(path/mode/worktree_path/triggered_at) 정확히 동일.
- **AC7 — `rewrite_state()` ordering 정정 (write-before-emit) + rewrite 실패 시 emit 금지**:
  - **AC7.1 — Ordering 요구**: `review-dispatch.py`는 `rewrite_state(state_path, body, now)` 호출이 **`print(json.dumps(...))` 보다 먼저** 완료되어야 함 + `rewrite_state()` 내부에 `f.write()` 후 `f.flush()` + `os.fsync(f.fileno())` 로 OS-level durability 보장. 이는 기존 v0.4.0 코드(line 122 print → lines 123–127 rewrite) 와 다른 ordering — Reviewer round-1 issue 83dc5425 fix.
  - **AC7.2 — Rewrite 실패 시 동작 (race-free 보장)**: rewrite_state가 OSError로 실패하면 hook은 stderr loud log + `{}` exit 0 (block 안 함). 이는 G3/C6의 race-free TTL guard 전제를 절대적으로 유지 — rewrite 실패 후 block emit 시 다음 Stop이 stale state를 읽고 또 block → block storm. Tradeoff: 이번 Stop의 dispatch 1회는 누락되나, L4b UserPromptSubmit reminder가 다음 user prompt에 dispatch를 살림 (안전망 design intent). Round-2 issue NEW-f8e20d44 (contradiction) fix.
  - **AC7.3 — Ordering 검증 전략 (NEW-a7f3c291 fix)**: `test_hook_output_schema.py`는 mtime/시각 비교 대신 다음 3가지 중 *최소 1개*를 구현하여 ordering을 *실제로* 검증:
    1. **AST inspection**: `ast.parse(open("review-dispatch.py").read())` → main() 함수 body 노드를 순회하여 `rewrite_state` Call node가 `print` Call node 보다 *먼저* 등장하는지 line number 비교. ordering 위반 시 fail.
    2. **Fault injection**: 임시 read-only state file로 fixture 구성 → rewrite_state가 OSError raise → stdout이 `{}` (또는 empty) 임을 검증 (AC7.2 동시 검증). emit이 발생하면 fail.
    3. **Mock-based ordering trace**: `unittest.mock.patch` 로 `rewrite_state`를 wrap하여 호출 순서를 list에 기록 + `print`도 wrap. 순서 list가 `["rewrite_state", "print"]` 인지 검증.
  - 권장: 위 3가지 모두 구현 (AST + fault injection + mock trace) 하여 isolation 보장. mtime 비교는 dead assertion이므로 제거.
- **AC8 — TTL guard 작동**: Stop hook 발화 시점에 `last_dispatched_at`이 30초 이내면 `{}` exit (no block, no continue). `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC` 환경변수 override 작동. AC7의 ordering 정정 전제 위에서만 신뢰 가능.
- **AC9 — Cleanup 정책 무변화**: 24h pending_review 자동 purge + 7일 state file 자동 delete 기존 동작 그대로.

### Kill switches

- **AC10 — 5개 hook 모두 `DEVBREW_DISABLE_SPEC_DISTILL=1` 존중**: 어떤 dispatch 메시지든 stdout `{}` (또는 빈 출력) exit 0.
- **AC11 — Hook-단위 opt-out 존중**: `DEVBREW_SKIP_HOOKS=spec-distill:Stop` → review-dispatch만 skip. `DEVBREW_SKIP_HOOKS=spec-distill:PostToolUse` → spec-write-validator만 skip. CSV 다중 토큰도 작동 (`spec-distill:Stop,spec-distill:UserPromptSubmit`).

### 회귀 방지

- **AC12 — `tests/test_hook_output_schema.py` 신설 (parametrized fixture 기반)**:
  - **Structure**: Python `unittest.TestCase` 1개 + `subTest()` 또는 `parameterized` 스타일로 5개 hook을 row로 처리 — 각 row = `(hook_name, exec_args, env_setup, stdin_payload_or_state_fixture, expected_schema_dict)`.
  - **Stop hook 케이스 (review-dispatch.py)**: stdin payload 없음 (Stop hook은 stdin 무시, state file 읽음). Setup:
    1. `tempfile.TemporaryDirectory()` 로 임시 state root 생성.
    2. `<temp_root>/<session_id>/state.local.md` 에 frontmatter + pending_review block 작성 (path/mode/worktree_path/triggered_at).
    3. `DEVBREW_SPEC_DISTILL_SESSION_ID=<session_id>` env로 hook이 그 state 읽도록 유도.
    4. `state_path.state_root()`의 resolution을 redirect — **`CLAUDE_PROJECT_DIR=<temp_root>` env 사용 (env-redirect 채택)**. monkey-patch는 `state_path.py` 내부 구현에 결합하여 향후 internal refactor를 깨뜨릴 위험이 있고, env-redirect는 hook이 운영 환경에서 사용하는 동일한 외부 인터페이스를 그대로 사용 → test가 implementation detail이 아닌 contract를 검증. Round-2 advisory에 따라 writing-plans 단계가 아닌 design 단계에서 결정.
    5. `subprocess.run(["python3", "review-dispatch.py"], env=..., capture_output=True)` 실행.
    6. `json.loads(result.stdout)` → schema assertion + state mtime < stdout receipt time (AC7 ordering).
    7. tearDown: tempdir 자동 cleanup.
  - **PostToolUse / UserPromptSubmit / SessionStart 케이스**: stdin payload 주입 (`{"session_id": "...", "hook_event_name": "...", "tool_name": "Write", "tool_input": {"file_path": "<temp_spec_path>"}, ...}`). spec-write-validator는 `<temp_spec_path>` 가 `docs/superpowers/specs/*-design.md` 형태여야 trigger되므로 fixture spec 파일도 생성.
  - **bash hook 케이스 (interview-trigger.sh, session-anchor.sh)**: `subprocess.run(["bash", "interview-trigger.sh"], ...)` 또는 `["bash", "session-anchor.sh"]`. jq 의존 케이스(AC4-b/AC5-b)는 `unittest.skipUnless(not shutil.which("jq"), "jq not available — testing no-jq fallback")` 로 jq-없는 환경 감지 후 fallback path 검증. jq 있는 환경에서는 정상 path 검증.
  - **Encoding 안전성 (AC1a)**: Stop hook 케이스 중 1개는 fixture path에 공백/특수 문자 포함 → round-trip 검증.
  - **subTest 실패 격리**: 한 hook의 schema 위반이 다른 hook test를 막지 않음. CI 출력에서 5개 row 모두의 PASS/FAIL이 보임.
  - **devbrew kill switch 케이스도 같은 파일에**: `DEVBREW_DISABLE_SPEC_DISTILL=1` 설정 후 5개 hook 모두 stdout이 `{}` 또는 empty임을 검증 (AC10/AC11과 통합).
  - **Cross-resolver advisory (NG9, skipUnless 패턴)**: worktree env (`git rev-parse --is-inside-work-tree` 확인) 감지 시에만 실행되는 advisory test. `@unittest.skipUnless(_in_worktree(), "cross-resolver test runs only inside a git worktree")` 로 환경 감지. 실행되면 Python `state_path.state_root()` 결과와 bash `${CLAUDE_PROJECT_DIR:-$PWD}/.claude/spec-distill` 결과를 비교하여 동일하면 PASS, 다르면 FAIL (실제 mismatch 발견 시 PR reviewer가 NG9의 후속 PR을 즉시 작성하도록 신호). `expectedFailure`는 의도된 실패 마킹이므로 본 advisory 의도와 부합하지 않아 사용 안 함 — Round-2 issue NEW-d4c91b38 fix. 후속 PR이 path resolver 통합을 ship하면 본 test의 fail 가능성이 0이 되며 그 시점에 test는 그대로 유지 (no-op cost).
- **AC13 — 기존 `tests/test_review_dispatch.sh`, `tests/test_review_dispatch_design_mandate.sh` assertion 갱신**: 기존 systemMessage substring grep → `jq '.reason'` 기반 assertion + `jq '.decision'` == "block" assertion. 기존 PASS 시나리오 모두 PASS.
- **AC14 — 기존 `tests/test_hooks.sh`, `tests/test_spec_write_validator.sh`, `tests/test_reminder_hook.sh` assertion 갱신**: 동일 — JSON path assertion으로 변경.
- **AC15 — 5개 hook 모두에서 `systemMessage`-only output 발생 시 새 test가 즉시 FAIL**: 회귀 시 CI 블록.

### Versioning / docs

- **AC16 — `plugins/spec-distill/.claude-plugin/plugin.json`의 `version` 필드가 `0.4.0` → `0.5.0`**: PR commit에 포함.
- **AC17 — `plugins/spec-distill/CHANGELOG.md`에 `[0.5.0] — 2026-05-17` entry 신규 추가**: Fixed 섹션에 systemMessage→additionalContext/decision:block 전환 명시, Changed 섹션에 Stop hook의 즉시 continue 의미 변경 명시, Security 섹션에 kill switch 무변화 명시. v0.4.0 entry 무손상.
- **AC18 — `plugins/spec-distill/README.md`의 Hooks 섹션에 dual-target output 패턴 한 문단 추가**: 각 hook이 Claude-target field와 `systemMessage`를 함께 emit하는 이유 (Law 3 compounding의 일부 — 미래 reviewer가 같은 패턴 따르도록).
- **AC19 — devbrew Law 2 / 3 instantiation 명시**: README "Principles Instantiated"에 본 fix가 Law 2 infrastructure operability 보장 + Law 3 compounding (test 추가 + design doc 작성) 라인 추가.

## Files to Modify

### 수정 (hook 코드 — 5 files)

각 hook의 literal systemMessage text는 ≤120자 (C8/AC1) + "[spec-distill]" prefix + hook 식별 키워드.

- `plugins/spec-distill/hooks/review-dispatch.py` (lines 122–127, **ordering 정정 + output schema 정정**):
  - 현재 code:
    ```python
    print(json.dumps({"systemMessage": msg}), flush=True)
    try:
        rewrite_state(state_path, body, now)
    except OSError as e:
        print(f"[spec-distill] state rewrite failed (non-fatal): {e}", file=sys.stderr)
    ```
  - 신규 code (**rewrite-BEFORE-emit 순서**, fsync 추가):
    ```python
    try:
        rewrite_state(state_path, body, now)  # fsync 포함, AC7
    except OSError as e:
        print(f"[spec-distill] state rewrite failed (non-fatal): {e}", file=sys.stderr)
        # rewrite 실패 시에도 decision:block은 emit (사용자 알람 우선) — 다만 stale TTL guard로 storm 가능성 stderr로 loud log
    print(json.dumps({
        "decision": "block",
        "reason": msg,
        "systemMessage": "[spec-distill] reviewing-spec dispatch enforced for next turn"
    }), flush=True)
    ```
  - `rewrite_state()` 본문에 `f.flush(); os.fsync(f.fileno())` 추가 (현재 `path.write_text()`는 내부적으로 close하나 OS-level fsync는 보장 안 함).
  - docstring lines 1–16 갱신: "Stop hook이 `decision:'block'`을 emit하여 Claude를 즉시 continue시킴" 추가, "rewrite-before-emit ordering guarantee" 명시.

- `plugins/spec-distill/hooks/spec-write-validator.py` (lines 167–175 advisory 분기, **output schema 정정만**):
  - 현재 code:
    ```python
    print(json.dumps({"systemMessage": (
        f"[spec-distill] {mode} structural OK. "
        "Reviewer will be dispatched at turn end."
    )}), flush=True)
    ```
  - 신규 code:
    ```python
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": (
                f"[spec-distill] {mode} structural OK. "
                "Reviewer will be dispatched at turn end "
                "(Stop hook will mandate reviewing-spec skill invocation)."
            )
        },
        "systemMessage": f"[spec-distill] {mode} OK · reviewer dispatch pending"
    }), flush=True)
    ```
  - block 분기 (line 103–108 `emit_block()`)는 *무변경* — 이미 `{"decision":"block","reason":"..."}` 올바른 패턴.

- `plugins/spec-distill/hooks/pending-review-reminder.py` (line 105, **output schema 정정만**):
  - 현재 code:
    ```python
    print(json.dumps({"systemMessage": " ".join(parts)}), flush=True)
    ```
  - 신규 code:
    ```python
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": " ".join(parts)
        },
        "systemMessage": "[spec-distill] pending review reminder re-dispatched"
    }), flush=True)
    ```

- `plugins/spec-distill/hooks/interview-trigger.sh` (lines 60–67, **jq + no-jq fallback 둘 다 정정**):
  - 신규 jq path:
    ```bash
    jq -n --arg m "$msg" '{
        hookSpecificOutput: {
            hookEventName: "UserPromptSubmit",
            additionalContext: $m
        },
        systemMessage: "[spec-distill] interview suggestion (see context)"
    }'
    ```
  - 신규 no-jq fallback:
    ```bash
    escaped=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
    printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"},"systemMessage":"[spec-distill] interview suggestion (see context)"}\n' "$escaped"
    ```

- `plugins/spec-distill/hooks/session-anchor.sh` (lines 44–51, **jq + no-jq fallback 둘 다 정정**):
  - 신규 jq path:
    ```bash
    jq -n --arg m "$msg" '{
        hookSpecificOutput: {
            hookEventName: "SessionStart",
            additionalContext: $m
        },
        systemMessage: "[spec-distill] previous interview session(s) detected"
    }'
    ```
  - 신규 no-jq fallback (literal — interview-trigger.sh와 동일 escape 전략):
    ```bash
    escaped=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ' | tr -d '\r')
    printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"},"systemMessage":"[spec-distill] previous interview session(s) detected"}\n' "$escaped"
    ```
  - **No-jq fallback scope 제한**: bash sed 기반 escape는 backslash + double-quote + LF + CR 만 처리. null byte / 기타 control char / unicode 고위 codepoint는 처리 대상 아님 — devbrew state 파일 / 사용자 prompt에 그런 문자가 들어오는 시나리오는 본 PR scope 밖 (AC1a의 path 예시는 공백/`$`/backtick/일반 quote만 보장). jq 있는 환경에서는 jq가 full JSON escape 처리. CI에서 jq 있는 환경을 default로 가정 (AC4-b/AC5-b의 no-jq path는 fallback 안전망이지 임의 입력 처리 메커니즘 아님).

### 수정 (test — 5 files)

- `plugins/spec-distill/tests/test_review_dispatch.sh`: 기존 systemMessage substring grep을 `jq -e '.decision == "block"'` + `jq -e '.reason | contains("MANDATORY")'` + `jq -e '.systemMessage | startswith("[spec-distill]")'`로 교체 (C10에 따라 grep 대신 jq 내부 substring). 기존 시나리오 (pending_review 있음 / 없음 / TTL within / kill switch) 모두 그대로 PASS.
- `plugins/spec-distill/tests/test_review_dispatch_design_mandate.sh`: 동일 패턴으로 갱신.
- `plugins/spec-distill/tests/test_hooks.sh` (spec-write-validator advisory 케이스 포함 시): `jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"'` + `jq -e '.hookSpecificOutput.additionalContext | contains("structural OK")'`로 갱신.
- `plugins/spec-distill/tests/test_reminder_hook.sh`: `jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"'` + additionalContext substring (`contains("REMINDER")`).
- `plugins/spec-distill/tests/test_spec_write_validator.sh`: advisory 케이스 같은 패턴. block 케이스 (이미 `decision`+`reason` 사용 중)는 무변경.

### 신규 (test — 1 file)

- `plugins/spec-distill/tests/test_hook_output_schema.py`: Python `unittest`. 5개 hook 모두에 대해 happy-path stdin payload 주입 → stdout JSON 캡처 → AC1–AC5의 schema assertion 통합 검증. `unittest.skipUnless`로 jq 의존 fallback 케이스 (AC4-b/AC5-b) 환경 감지. CI / pre-merge 모두 실행 가능.

### 수정 (메타데이터 — 3 files)

- `plugins/spec-distill/.claude-plugin/plugin.json`: `version`: `"0.4.0"` → `"0.5.0"`. `description` 무변경.
- `plugins/spec-distill/CHANGELOG.md`: 파일 상단 (현재 `## [0.4.0] — 2026-05-17` 위)에 `## [0.5.0] — 2026-05-17` entry 신규 삽입.
  - Fixed: 5개 hook output schema 정정. systemMessage→additionalContext/decision:block 전환. silent failure 해결.
  - Changed: Stop hook의 `decision:"block"`이 Claude를 즉시 continue시키므로 dispatch 보장이 user 입력 대기 없이 작동. TTL guard 무변화.
  - Security: kill switch 5개 모두 무변경. 신규 env var 없음.
- `plugins/spec-distill/README.md`:
  - "Hooks Installed" 섹션의 각 hook 라인에 dual-target output 패턴 한 문장 (additionalContext / decision+reason + systemMessage 함께 emit).
  - "Principles Instantiated" 섹션에 본 fix가 Law 2 infrastructure operability 보장 + Law 3 compounding 라인 추가.

### 수정 안 함 (변경 없음을 명시)

- `plugins/spec-distill/hooks/hooks.json`: hook 등록 그대로.
- `plugins/spec-distill/hooks/state_path.py`: state 경로 헬퍼 그대로.
- `plugins/spec-distill/scripts/parse_spec_structure.py`: spec 파싱 라이브러리 그대로.
- `plugins/spec-distill/skills/*`: 모든 skill 무변경.
- `plugins/spec-distill/agents/*`: spec-reviewer / breadth-keeper agent 무변경.
- `plugins/spec-distill/commands/*`: `/interview` 등 command 무변경.
- 다른 plugin (quality-gates, project-init 등): 본 PR 범위 밖.

## Verification Plan

- **V1 — Hook 출력 schema 통합 검증**: `python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py` 실행 → 5개 hook 모두 schema PASS. jq 없는 환경에서도 AC4-b/AC5-b 케이스가 skip 후 나머지 PASS.
- **V2 — 기존 테스트 회귀 없음**: `bash plugins/spec-distill/tests/test_review_dispatch.sh`, `bash plugins/spec-distill/tests/test_review_dispatch_design_mandate.sh`, `bash plugins/spec-distill/tests/test_hooks.sh`, `bash plugins/spec-distill/tests/test_reminder_hook.sh`, `bash plugins/spec-distill/tests/test_spec_write_validator.sh` 모두 PASS. assertion 변경에도 시나리오 outcome 동일.
- **V3 — Kill switch 회귀 없음**: `DEVBREW_DISABLE_SPEC_DISTILL=1`, `DEVBREW_SKIP_HOOKS=spec-distill:Stop`, `DEVBREW_SKIP_HOOKS=spec-distill:PostToolUse`, `DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit`, `DEVBREW_SKIP_HOOKS=spec-distill:SessionStart` 각각 active일 때 해당 hook stdout `{}` (또는 empty) — `test_hook_output_schema.py`에 케이스 추가.
- **V4 — TTL guard 회귀 없음**: Stop hook을 30초 내 연속 2회 발화 시 두 번째 호출은 stdout `{}` exit 0 (no block). `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=1` 환경에서 1초 sleep 후 fire하면 두 번째도 block 출력.
- **V5a — Hook output schema 자동 검증 (CI 가능)**: `test_hook_output_schema.py`의 5개 hook 케이스가 stdout JSON을 `json.loads()` 후 전체 schema dict 비교 (top-level key set, `hookSpecificOutput.hookEventName` 정확 일치, `additionalContext`/`reason` 비어있지 않음, `systemMessage` prefix + ≤120자, ordering: state file mtime < stdout receipt 시각). 수동 단계 없음, CI 통과 가능.
- **V5b — Claude Code E2E 동작 검증 (수동, inherent)**: 새 design.md commit → spec-write-validator의 additionalContext가 Claude tool result 직후 system reminder로 보임 → Claude가 Stop 시도 → review-dispatch의 `decision:"block"` 발화 → Claude가 즉시 continue, 다음 model request에서 reason을 보고 reviewing-spec skill 호출. **이 시나리오는 Claude Code 인프라 행동을 stub 불가능** — 수동 E2E (≤5분) 외에 자동화 수단 없음. 실패 시 본 PR의 핵심 가설(공식 doc verbatim quote, C4)이 invalidate되므로 PR 차단 사유.
- **V6 — Worktree path 회귀 없음**: worktree 내부에서 spec 생성 → state file이 main repo `.claude/spec-distill/<session>/state.local.md`에 기록 → 다음 Stop hook에서 worktree_path 필드가 reason에 포함됨. 기존 V2/V3에서 cover.
- **V7 — `plugin.json` version bump 확인**: `git diff plugins/spec-distill/.claude-plugin/plugin.json` → `"version": "0.4.0"` → `"version": "0.5.0"` 단일 변경.
- **V8 — CHANGELOG entry 확인**: `head -20 plugins/spec-distill/CHANGELOG.md` → `## [0.5.0] — 2026-05-17` 신규 entry. v0.4.0 entry 위치 무변.
- **V9 — README 갱신 확인**: `grep -A3 "Hooks Installed\|Principles Instantiated" plugins/spec-distill/README.md` → dual-target output 패턴 + Law 2/3 instantiation 문장 존재.
- **V10 — `cost_class` 무영향**: 본 fix는 skill 추가/제거 없음 → cost_class 선언 무관. 확인 only.
- **V11 — devbrew CLAUDE.md Forbidden Patterns 위반 없음**: Self-approval (Law 2 위반) 없음 — writer는 사용자/Claude, reviewer는 본 PR 머지 전 사용자 spec review + writing-plans + executing-plans + quality-gates 체인. Polite stop 없음 (다음 단계 = writing-plans 명시). Trivia ceremony 아님 (5 file 코드 변경 + 1 file 신규 test + 3 file 메타데이터). Subagent spray 없음 (단일 PR, fan-out 없음). Unbounded autonomy 없음 (TTL guard 보존).

## Rejected Alternatives

### §9.0 Adopted Approach

**Approach B — Full spec-distill 5-hook audit + 신규 회귀 방지 test + v0.5.0 minor bump + dual-target output (Claude-target field + systemMessage 페어).**

채택 근거:

- 사용자가 보고한 incident의 root class를 plugin 경계 안에서 *완전히* 해결 (3단 안전망 회복).
- quality-gates `stop-hook.py:845-849`의 dual-target output 패턴이 reference로 존재 → 새로운 패턴 발명이 아니라 적용.
- 회귀 방지 test (`test_hook_output_schema.py`)가 미래의 동일 mistake를 즉시 잡음 → devbrew Law 3 compounding.
- 5개 hook 변경이 모두 mechanical (output JSON field 교체) → 변경 risk 낮고 PR review 비용 낮음.
- v0.5.0 minor bump가 cache key 갱신 (사용자가 plugin 재설치 시 즉시 fix 도달).

### §9.1 Rejected

- **Approach A — 보고된 2 hook (`review-dispatch` + `spec-write-validator` advisory) 만 fix.** 거절 이유: `pending-review-reminder.py`가 *완전히 같은 버그* (line 105 `{"systemMessage": "..."}`)이며, L3 Stop이 어떤 이유로 missed되면 L4b reminder fallback이 dispatch를 살리도록 v0.4.0에서 도입됐는데, 그 안전망이 같은 버그로 silent fail 보장 상태. Approach A는 사용자가 보고한 incident만 해결하고 안전망 갈증을 그대로 둠 → 다음 incident가 인프라 race condition (가설 3) 으로 발생하면 L4b도 동일 silent fail. 가성비 낮음.

- **Approach C — devbrew-wide systemMessage audit (quality-gates `post-tool-use.py:81`, project-init hook 포함).** 거절 이유: (a) 사용자 보고 범위 초과, (b) quality-gates의 PR-creation systemMessage 같은 건 *의도된 user-only display* 가능성 (user가 다음 prompt로 `/qg`를 직접 invoke하는 흐름이 design), 일률적 변경 시 의도하지 않은 동작 변경 위험, (c) PR 크기 폭발로 review/롤백 단위 비대화. *향후 별도 PR*로 plugin별 의도 확인 후 진행 가능.

- **Two-phase migration (Stop hook patch PR 먼저, 4개 advisory hook 후속 PR).** 거절 이유: (a) Stop hook만 먼저 ship하면 advisory L1 (`spec-write-validator`) 이 여전히 systemMessage-only로 남아 Claude가 "structural OK, reviewer dispatched" advisory를 받지 못함 → 사용자가 디스크 흔적으로만 dispatch 상태 추적 가능, 사용자 경험 enrichment 누락. (b) **중간 상태 silent fail 위험**: phase 1 후 phase 2 전 시기에 사용자가 spec을 작성하면 (b1) L3 Stop hook은 fix되어 dispatch가 reach하지만 (b2) L1 PostToolUse advisory + L4b UserPromptSubmit reminder는 여전히 systemMessage-only로 silent — 이 인터림 baseline은 안전망 일관성 측면에서 v0.4.0보다 더 혼란스러움 (작동 안 함이 아니라 *부분 작동*, 디버깅이 어려움). (c) 롤백 단위가 2개 commit으로 분산 → `git revert <single-sha>` 단순성 손실. (d) `test_hook_output_schema.py`도 2번에 걸쳐 추가하거나 후속 PR로 미루는 어색함. 한 PR로 cutover하는 atomic 변경이 *부분 작동 인터림 baseline 회피*/test/롤백 모두에서 더 단순. 다만 Reviewer round-1 issue adcd1c89가 지적했듯 이 옵션이 명시되지 않으면 reader가 "고려됐는가?"를 알 수 없음 → 본 round-2 spec revision에서 명시 추가. Round-2 issue NEW-e9a3bb52 (circular SemVer argument) fix: 기존 (b) "SemVer 정책상 모호"는 부정확한 논거여서 "부분 작동 인터림 baseline 위험"으로 교체.

- **Feature flag (`DEVBREW_SPEC_DISTILL_NEW_SCHEMA=1`) dual-output mode.** 거절 이유: (a) systemMessage + additionalContext + decision+reason을 동시에 출력하는 코드는 이미 본 PR이 채택 (dual-target의 "dual"이 feature flag dual이 아니라 *user-vs-Claude target dual*). flag로 새 schema를 gating해도 Claude는 항상 새 schema field를 보거나 못 봄 — production에서 *부분 enable*이 의미 없음 (Claude Code 한 인스턴스가 한 hook output을 한 번에 처리). (b) Hook 출력 schema는 binary contract — 옳거나 silent fail이거나. 점진적 ramp가 hook output에 적용 불가능 (network rollout 아님). (c) flag 추가는 신규 env var → NG5 위반 (devbrew LD10 일관성). 적절한 안전 장치는 *기존* kill switch (`DEVBREW_DISABLE_SPEC_DISTILL=1`) + 회귀 test + plugin.json minor bump로 충분.

- **Stop hook에 `decision:"block"` 대신 `additionalContext`-like 메커니즘만 사용 (event 변경).** 거절 이유: Stop event는 `hookSpecificOutput.additionalContext` 미지원 (공식 사양상 SessionStart/Setup/SubagentStart/UserPromptSubmit/UserPromptExpansion/PreToolUse/PostToolUse/PostToolUseFailure/PostToolBatch에 한정). Stop hook의 유일한 Claude-target 메커니즘이 `decision:"block"+reason`. 우회 불가.

- **Stop hook의 `decision:"block"` 대신 다음 UserPromptSubmit에서 `additionalContext`로만 dispatch.** 거절 이유: (a) UserPromptSubmit은 user가 prompt를 보낼 때만 fire → user 입력 대기 동안 dispatch 보장 없음, (b) Stop 시점에 즉시 강제하는 것이 design intent (사용자가 다른 작업으로 옮기기 전에 reviewer가 돌아야 함), (c) `pending-review-reminder.py` 가 이미 그 fallback을 담당 → 1차 dispatch는 Stop이 즉시 처리, 2차 fallback은 reminder가 처리하는 2-layer 설계가 더 안정적.

- **`systemMessage` 제거하고 Claude-target field만 남김 (single-target output).** 거절 이유: hook 발화 흔적이 user transcript에서 사라짐 → 디버깅 가능성 손실. 본 incident도 user가 transcript / state 흔적 비교로 진단했음 — *user-visible 흔적은 hook reliability의 일부*. dual-target output이 정답.

- **회귀 방지 test 생략 (`test_hook_output_schema.py` 신설 안 함).** 거절 이유: 본 incident 자체가 *output schema가 잘못된 채 무한히 silent fail*하던 것 → 같은 패턴이 다시 들어가지 않으리란 보장 없음. devbrew Law 3 ("Every Cycle Must Leave the System Smarter") instantiation으로 test 추가가 본 PR의 *핵심 compounding 산출물*. 생략 시 다음 reviewer가 같은 실수를 잡을 방법 없음.

- **PostToolUse advisory 분기에서 `decision:"block"+reason` 사용 (block 분기와 통일).** 거절 이유: PostToolUse `decision:"block"`은 agentic loop을 차단 → spec/design 정상 작성 후 advisory를 *block 신호로 보내면 의도하지 않은 차단*. advisory는 정보 전달 의도 → `additionalContext`가 올바른 선택. block 분기 (검증 실패) 만 `decision:"block"` 유지.

- **bash hook의 jq 의존성 강화 (no-jq fallback 제거).** 거절 이유: 기존 `interview-trigger.sh` / `session-anchor.sh`가 jq-없는 환경 fallback을 유지하는 것은 graceful degradation 정책 (devbrew Plugin Shape "Loud logging을 동반한 graceful degradation"). 제거 시 jq 미설치 환경에서 hook 완전 inoperable. 유지 + 같은 schema 출력으로 갱신.

- **5개 hook 변경을 5개 PR로 분리.** 거절 이유: 안전망 3단 (L1+L3+L4b)이 *전부 같이 작동해야* 의도된 reliability 발휘. 단계적 머지 시 중간 상태에서 한두 단만 fix된 어색한 시기 발생. 한 PR로 한 번에 머지하여 v0.5.0 baseline 단일 cutover.

## Metadata

- **devbrew principles instantiated**:
  - *Law 1 (Clarity Before Code)*: 본 design doc 자체. 코드 변경 전 spec.
  - *Law 2 (Writer/Reviewer Never Share a Pass) — infrastructure operability*: writer/reviewer 분리는 이미 잘 됐으나 dispatch가 reach해야 분리가 의미를 가짐. 본 fix는 그 인프라 baseline 보장.
  - *Law 3 (Every Cycle Must Leave the System Smarter)*: hook 코드 fix + 회귀 방지 test 신설 + CHANGELOG 명시 + 본 design doc — 4-layer compounding 흔적. 미래 동일 mistake가 즉시 잡힘.
  - *Plugin Shape — SemVer bump*: v0.4.0 → v0.5.0 (new behavior surface = Claude 가시성 동작).
  - *Plugin Shape — CHANGELOG required (v ≥1.0.0)*: v0.5.0은 아직 미만이지만 본 plugin은 이미 v0.3.0부터 CHANGELOG 유지 중 → 일관성 유지.
  - *Plugin Shape — Loud logging + graceful degradation*: bash hook의 no-jq fallback 보존.
  - *Doc Conventions — Korean-primary, English-terms-only*: 본 doc 자체.
- **Source 자료**:
  - 사용자 incident 진단 (`spec-write-validator.py` + `review-dispatch.py` 수동 재현 stdout + state.local.md timeline).
  - Claude Code 공식 hook 사양 (code.claude.com/docs/en/hooks): `systemMessage` vs `additionalContext` vs `decision:"block"+reason`.
  - quality-gates reference: `plugins/quality-gates/hooks/stop-hook.py:845-849` (dual-target output 패턴).
  - devbrew philosophy: `CLAUDE.md` §The Three Laws, §Plugin Shape, §Forbidden Patterns.
- **Affected plugin**: `plugins/spec-distill/` (v0.4.0 → v0.5.0).
- **Out-of-scope plugins**: `plugins/quality-gates/`, `plugins/project-init/` (별도 PR로 audit 가능).
- **다음 단계**: superpowers `writing-plans` skill로 implementation plan 생성.
- **Revision history**:
  - v1.0.0 (2026-05-17, commit c0bc790): initial draft.
  - v1.1.0 (2026-05-17, round-1 spec-reviewer adversarial review 반영): 10개 issue 모두 fix — rewrite-before-emit ordering 의무화 (AC7), reason 인코딩 round-trip 안전성 (AC1a + C10), `test_hook_output_schema.py` Stop-hook state fixture 명세 (AC12), V5 split (V5a 자동/V5b 수동), test 파일 count 정정 (4→5), §9.1에 two-phase migration + feature flag 거절 alternative 추가, C4 hook 사양 verbatim 인용, C5 hedging 제거, Goal 3개 deliverable로 enumerate, G3 조건부 표현 명시, hook 별 literal systemMessage 텍스트 명시 (`<짧은 흔적>` placeholder 제거), C11 + NG9에 cross-resolver consistency 명시 (본 PR scope 한정).
  - v1.2.0 (2026-05-17, round-2 spec-reviewer adversarial review 반영): 5개 신규 issue + 3개 advisory 모두 fix — AC7 ordering assertion 강화 (mtime dead-assertion 제거, AST inspection + fault injection + mock trace 3-prong 검증, NEW-a7f3c291), AC7.2 rewrite 실패 시 emit 금지 (block storm 회피, NEW-f8e20d44), session-anchor.sh no-jq fallback literal snippet 명시 + scope 제한 명시 (NEW-b2c1e6f7), AC12 cross-resolver test가 `skipUnless` 사용 (`expectedFailure` 폐기, NEW-d4c91b38), §9.1 two-phase 거절 (b) "SemVer 정책상 모호" 순환 논거를 "부분 작동 인터림 baseline 위험"으로 교체 (NEW-e9a3bb52), AC12 monkey-patch vs env-redirect 결정 (env-redirect 채택, design 단계 결정), G7 test-only 범위 명확화.
