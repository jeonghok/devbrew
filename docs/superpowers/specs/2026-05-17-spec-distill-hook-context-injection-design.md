---
name: spec-distill-hook-context-injection
version: 1.0.0
created_at: 2026-05-17
session_id: brainstorm-2026-05-17
status: locked
next_phase: writing-plans
source: superpowers/brainstorming + empirical hook firing 증거 (state.local.md 흔적 + 수동 재현 stdout) + Claude Code 공식 hook 사양 (code.claude.com/docs/en/hooks) + quality-gates reference 패턴 (plugins/quality-gates/hooks/stop-hook.py:845-849)
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

`plugins/spec-distill/hooks/`의 5개 hook이 stdout으로 emit하는 메시지가 Claude의 다음 model request context에 *실제로* 포함되도록 JSON output schema를 정정한다. 동일 메시지를 `systemMessage` 필드로 user transcript에도 짧게 노출시켜 hook 발화 흔적을 디버깅 가능하게 유지한다. 동시에 모든 hook의 output JSON schema 회귀를 잡는 통합 테스트(`tests/test_hook_output_schema.py`)를 신설한다. 한 PR로 묶어 minor version bump (`0.4.0` → `0.5.0`).

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
- **G3 — Stop hook의 dispatch 보장이 즉시 continue로 실현**: `review-dispatch.py`의 `decision:"block"`이 Stop을 막고 Claude를 다음 model request로 즉시 진입시킴 → "다음 turn 첫 액션은 reviewing-spec" 강제가 user 입력 대기 없이 작동. 기존 TTL guard (`DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=30`)가 무한 block 루프 방지.
- **G4 — Output schema 회귀 방지 test**: 신규 `tests/test_hook_output_schema.py`가 5개 hook의 happy-path stdout을 jq schema assertion으로 검증. 누군가 다시 `systemMessage`-only로 떨어뜨리면 CI에서 즉시 잡힘.
- **G5 — 기존 동작 모두 보존**: state machine (`pending_review:` 블록 + `last_dispatched_at` TTL guard), kill switches (`DEVBREW_DISABLE_SPEC_DISTILL=1` + `DEVBREW_SKIP_HOOKS=spec-distill:<event>`), worktree path resolution (`state_path.state_root()`), cleanup 정책 (24h pending purge / 7일 state file purge), block 분기의 `decision:"block"+reason` 패턴 — 전부 무손상.
- **G6 — devbrew Plugin Shape 준수**: `plugin.json` minor bump (`0.4.0` → `0.5.0`, Claude 가시성 동작 변경 = new behavior surface), `CHANGELOG.md`에 `[0.5.0] — 2026-05-17` entry (Fixed + Changed), `README.md` Hook 섹션에 dual-target output 패턴 문서화.
- **G7 — devbrew Plugin Shape "Loud logging" 준수**: 만약 미래에 hookSpecificOutput schema가 plugin output에서 누락되면 stderr loud log (시작 시 self-check 또는 test에서). 현재 PR 범위에서는 `test_hook_output_schema.py`가 동등 기능.

## Non-goals

- **NG1 — quality-gates / project-init의 systemMessage audit 안 함**: 사용자가 보고한 plugin 경계 내로 한정 (Approach B). quality-gates `post-tool-use.py:81`의 PR-creation systemMessage 같은 건 의도적 user-only일 가능성 (user가 다음 prompt로 `/qg`를 직접 invoke하도록 설계됨) → 별도 audit/PR 필요. project-init `post-tool-use.py`는 advisory branch+commit 검증으로 user가 직접 보고 수정하는 흐름이 의도 → 손대지 않음. *향후 별도 PR에서* devbrew-wide systemMessage audit 가능.
- **NG2 — Hook stdout aggregation 인프라 conflict 해결 안 함**: 사용자 진단의 가설 3 (동일 PostToolUse event에 multi-hook 발화 시 stdout aggregation race condition)은 Claude Code 인프라 레이어 이슈로 plugin 범위 밖. 본 fix 이후에도 재현되면 별도 issue로 Anthropic에 보고.
- **NG3 — Hook 동작 로직 자체 변경 안 함**: 룰 추가/제거, threshold 조정, 신규 event matcher 등 일체 없음. Pure output field 교체 + 회귀 방지 test 추가만.
- **NG4 — State machine 변경 안 함**: `pending_review:` 블록 schema, `last_dispatched_at` field, TTL guard sec, 24h/7일 cleanup 정책 무손상.
- **NG5 — Kill switch 새로 추가 안 함**: 기존 `DEVBREW_DISABLE_SPEC_DISTILL=1` + `DEVBREW_SKIP_HOOKS=spec-distill:<event>` 그대로 사용. 신규 env var 없음 (devbrew LD10 일관성).
- **NG6 — reviewing-spec skill / spec-reviewer agent / drafting-spec skill 변경 안 함**: hook 정정으로 dispatch가 reach하기 시작하면 기존 skill/agent가 그대로 작동해야 함. 추가 변경 시 PR 분리.
- **NG7 — `decision:"block"` 사용을 PostToolUse advisory 분기로 확장 안 함**: PostToolUse advisory는 *정보 전달* 의도이지 차단이 아님 → `additionalContext`가 올바른 선택. block 분기 (현재 line 103–108)는 이미 `decision:"block"+reason` 사용 중이며 무손상.
- **NG8 — 한 turn 안에서 reviewing-spec skill 자동 invoke 안 함**: Stop hook의 `decision:"block"`이 Claude를 continue 시키지만, 실제 skill 호출은 Claude의 다음 model request에서 reason을 보고 *결정*함. hook이 skill을 직접 호출하지 않음 (Claude Code는 그런 메커니즘 없음).

## Constraints

- **C1 — Python 3 stdlib + jq only**: 기존 hook들이 `json`/`os`/`re`/`sys` + bash `jq`만 사용. 외부 의존성 추가 없음. `test_hook_output_schema.py`는 Python stdlib `unittest` + `subprocess` + `json`.
- **C2 — Hook timeout 5–10s 유지**: `hooks.json`의 기존 timeout 값 (5초 reminder, 10초 그 외) 변경 없음. output field 교체는 ms 수준 성능 차이.
- **C3 — JSON I/O 계약 준수**: stdin = Claude Code의 hook input payload, stdout = 단일 JSON object. parse 실패 / 출력 실패 시 `{}` exit 0 (graceful degradation, 기존 동작 보존).
- **C4 — Output JSON 구조 (Claude Code 공식 사양)**:
  - PostToolUse / UserPromptSubmit / SessionStart 등 *additionalContext 지원 event*:
    ```json
    {
      "hookSpecificOutput": {
        "hookEventName": "PostToolUse",  // event 이름 정확히 일치 필수
        "additionalContext": "..."
      },
      "systemMessage": "<짧은 흔적 라인>"
    }
    ```
  - Stop event:
    ```json
    {
      "decision": "block",
      "reason": "<Claude가 볼 본문>",
      "systemMessage": "<짧은 흔적 라인>"
    }
    ```
- **C5 — `hookSpecificOutput.hookEventName`은 호출 event와 정확히 일치**: `"PostToolUse"`, `"UserPromptSubmit"`, `"SessionStart"`. typo / 다른 event 이름이면 Claude Code가 silent drop 가능 — `test_hook_output_schema.py`가 assertion으로 검증.
- **C6 — `decision:"block"`의 TTL guard 필수 (Stop hook)**: 무한 block 루프 방지. `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC` (default 30s) 이미 구현됨, 무손상. block한 직후 `last_dispatched_at`을 now로 rewrite → 30초 안에 다시 Stop이 fire되면 guard에 의해 통과 (block 안 함).
- **C7 — Kill switch는 보안 컨트롤 (devbrew CLAUDE.md §Plugin Shape)**: 어떤 dispatch 메시지든 kill switch active면 모두 `{}` exit. 우회 로직 금지. 기존 5개 hook의 kill switch 로직 무손상.
- **C8 — `systemMessage` 짧게 유지**: dual-target output에서 systemMessage는 *user transcript에 hook 발화 흔적*이 목적 → 짧게 (한 줄, ≤80자). 본문은 additionalContext / reason에 들어감. 중복 노출 회피.
- **C9 — bash hook의 fallback (no-jq) JSON 출력 보존**: `interview-trigger.sh` / `session-anchor.sh`의 manual JSON escape fallback 경로도 함께 정정. jq 없는 환경에서 동일 schema 출력.

## Acceptance Criteria

### Hook output schema

- **AC1 — `review-dispatch.py` (Stop) stdout JSON에 다음 fields 모두 존재 (pending_review 있고 TTL 안 지났을 때)**:
  - `.decision == "block"`
  - `.reason` (non-empty, "MANDATORY" 단어와 `spec path:` substring 포함, `mode:` substring 포함, 있으면 `worktree_path:`)
  - `.systemMessage` (non-empty, ≤120자, "[spec-distill]" prefix)
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
- **AC7 — `last_dispatched_at` rewrite 무변화**: `review-dispatch.py` block 발사 후 (decision:"block" 출력 후) state의 `pending_review:` 블록 제거 + `last_dispatched_at` now로 rewrite — 기존 동작 그대로.
- **AC8 — TTL guard 작동**: Stop hook 발화 시점에 `last_dispatched_at`이 30초 이내면 `{}` exit (no block, no continue). `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC` 환경변수 override 작동.
- **AC9 — Cleanup 정책 무변화**: 24h pending_review 자동 purge + 7일 state file 자동 delete 기존 동작 그대로.

### Kill switches

- **AC10 — 5개 hook 모두 `DEVBREW_DISABLE_SPEC_DISTILL=1` 존중**: 어떤 dispatch 메시지든 stdout `{}` (또는 빈 출력) exit 0.
- **AC11 — Hook-단위 opt-out 존중**: `DEVBREW_SKIP_HOOKS=spec-distill:Stop` → review-dispatch만 skip. `DEVBREW_SKIP_HOOKS=spec-distill:PostToolUse` → spec-write-validator만 skip. CSV 다중 토큰도 작동 (`spec-distill:Stop,spec-distill:UserPromptSubmit`).

### 회귀 방지

- **AC12 — `tests/test_hook_output_schema.py` 신설**: 5개 hook 모두에 대해 stdin payload 주입 → stdout JSON 캡처 → schema assertion (AC1–AC5의 각 field 존재 + 값 형태). Python `unittest`, `subprocess.run`으로 hook 실행. `unittest.skipUnless`로 jq 의존 케이스(AC4-b/AC5-b 의 jq-없음 fallback)는 환경 감지 후 skip.
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

- `plugins/spec-distill/hooks/review-dispatch.py` (line 122): `print(json.dumps({"systemMessage": msg}), flush=True)` → `print(json.dumps({"decision":"block","reason":msg,"systemMessage":"<짧은 흔적>"}), flush=True)`. block 분기 의미 변경 docstring 갱신 (lines 1–16).
- `plugins/spec-distill/hooks/spec-write-validator.py` (lines 167–175 advisory 분기): `{"systemMessage": "..."}` → `{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"..."},"systemMessage":"<짧은 흔적>"}`. block 분기 (line 103–108)는 *무변경*.
- `plugins/spec-distill/hooks/pending-review-reminder.py` (line 105): `{"systemMessage": "..."}` → `{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"..."},"systemMessage":"<짧은 흔적>"}`.
- `plugins/spec-distill/hooks/interview-trigger.sh` (lines 60–67): jq invocation + no-jq fallback 둘 다 갱신 — `{systemMessage: $m}` → `{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$m},systemMessage:"<짧은 흔적>"}`. shell-escape 안전.
- `plugins/spec-distill/hooks/session-anchor.sh` (lines 44–51): 동일 — jq + no-jq fallback 둘 다 `hookEventName:"SessionStart"` 형태로.

### 수정 (test — 4 files)

- `plugins/spec-distill/tests/test_review_dispatch.sh`: 기존 systemMessage substring grep을 `jq -e '.decision == "block"'` + `jq -er '.reason' | grep MANDATORY` + `jq -er '.systemMessage' | grep '\[spec-distill\]'`로 교체. 기존 시나리오 (pending_review 있음 / 없음 / TTL within / kill switch) 모두 그대로 PASS.
- `plugins/spec-distill/tests/test_review_dispatch_design_mandate.sh`: 동일 패턴으로 갱신.
- `plugins/spec-distill/tests/test_hooks.sh` (있는 spec-write-validator advisory 케이스): `jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"'` + `jq -er '.hookSpecificOutput.additionalContext' | grep "structural OK"`로 갱신.
- `plugins/spec-distill/tests/test_reminder_hook.sh`: `jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"'` + additionalContext substring grep.
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
- **V5 — `decision:"block"` 의미 검증 (수동 E2E)**: 새 spec 파일 commit → spec-write-validator의 additionalContext가 Claude tool result 직후 system reminder로 보임 → Claude가 Stop 시도 → review-dispatch의 `decision:"block"` 발화 → Claude가 즉시 continue, 다음 model request에서 reason을 보고 reviewing-spec skill 호출. 수동 한 사이클 (≤5분).
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
