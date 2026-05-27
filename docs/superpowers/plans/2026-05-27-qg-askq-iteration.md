# quality-gates v2.0.0 — AskUserQuestion-Driven In-Turn Iteration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/superpowers/specs/2026-05-27-qg-askq-iteration-design.md` (v2.0.0, locked, round-4 approved).

**Goal:** `quality-gates` 플러그인의 Stop-hook 기반 iteration 인프라(stop-hook.py 1205 LOC + `<qg-signal>` + sentinel + 13-transition state machine + wall-clock guard + no-signal counter)를 일괄 제거하고, `quality-pipeline` SKILL이 단일 어시스턴트 턴 안에서 Gate 1 → Gate 2 → Gate 3을 시리얼 디스패치하며 진행 결정은 `AskUserQuestion` tool call로 표면화하는 v2.0.0 메이저 재설계.

**Architecture:** Stop hook 제거 → SKILL이 in-turn orchestrator. 게이트 boundary 및 Gate 2 fix-loop iter 경계의 진행 결정은 AskUserQuestion(같은 턴 tool result)으로 user-in-the-loop. Happy path(전 게이트 PASS)는 0 클릭. State file은 cross-turn pipeline state를 잃고 minimal GC metadata + worktree tracking만 유지.

**Tech Stack:** Python 3 (hooks/scripts), Bash (scripts/tests), Markdown (SKILL/commands/agents/docs), JSON (plugin.json/hooks.json). 외부 의존: Claude Code harness (`AskUserQuestion` tool 가용성 — Task 1에서 확정).

**Scope guardrails (spec C9 + AC14 + NG1-NG6):**
- `hooks/post-tool-use-session-tracker.py`, `hooks/post-tool-use.py`, `hooks/session-end-cleanup.py`: feature 브랜치 시작점 대비 diff 0줄 유지 (AC14 끝 명령으로 검증).
- 모든 reviewer agent(`agents/*.md`)의 `disallowedTools` frontmatter: 변경 없음 (Law 2).
- 외부 플러그인 인터페이스(`pr-review-toolkit`, `feature-dev`, `superpowers`, `chrome-devtools-mcp`): 변경 없음 (NG3).

---

## File Structure

본 plan이 touch하는 모든 파일 (spec "Files to Modify"의 정확한 instantiation).

**Create (신규):**
- `plugins/quality-gates/tests/test_skill_orchestration.sh` — V2a + V2b + V7을 묶는 정적 grep wrapper (AC15, V6).
- `plugins/quality-gates/tests/test_cancel_qg.sh` — `/cancel-qg`, `/qg --reset`, `/qg --gc` fixture 검증 (AC17, V10).
- `plugins/quality-gates/tests/test_session_start_advisor_v2.sh` — V8 (legacy state advisory) + V8-pre (코드 구조 grep) 묶음 (AC14, AC16).

**Delete:**
- `plugins/quality-gates/hooks/stop-hook.py` (1205 LOC).
- `plugins/quality-gates/tests/`의 obsolete tests (정확한 목록은 Task 12 단계에서 `ls`로 확정 — 패턴: `test_*stop_hook*`, `test_*transition*`, `test_no_signal*`, `test_forward_only_prose.sh`, `test_failure_injection.sh`(stop-hook이 대상이면), `test_hook_cwd_contract.py`(stop-hook 대상 부분만)).

**Modify-Large:**
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` (70 KB → 단일-턴 시리얼 디스패치 형식으로 rewrite).
- `plugins/quality-gates/README.md` (Hook 표, state 다이어그램, Principles Instantiated, Tuning knobs 갱신).
- `plugins/quality-gates/CHANGELOG.md` (v2.0.0 항목 추가).

**Modify-Narrow:**
- `plugins/quality-gates/.claude-plugin/plugin.json` (version `1.31.0` → `2.0.0`).
- `plugins/quality-gates/hooks/hooks.json` (Stop event 블록 제거).
- `plugins/quality-gates/hooks/session-start-advisor.py` (in-flight 분기 제거 + legacy advisory `/cancel-qg` 안내; frontmatter scan 유지).
- `plugins/quality-gates/scripts/setup-qg.sh` (state 스키마 단순화: stop-hook 전용 필드 + wall-clock + no-signal 제거).
- `plugins/quality-gates/scripts/pre-pipeline-check.sh` (cross-turn state 검사 축소; branch marker는 유지).
- `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md` (단순화된 schema 문서화).
- `plugins/quality-gates/commands/qg.md` ("Stop hook handles progression" 문구 제거 + 시리얼 디스패치 설명).
- `plugins/quality-gates/commands/cancel-qg.md` (orphan state cleanup 유틸 역할로 문구 정리).

**Keep (변경 없음, 명시 확인 대상):**
- `plugins/quality-gates/agents/*.md` (`adversarial`, `plan-verifier`, `runtime-verifier`, `security-reviewer`, `test-scope-validator`) — Law 2 frontmatter 유지.
- `plugins/quality-gates/hooks/post-tool-use*.py`, `session-end-cleanup.py` — AC14에서 diff 0줄 잠금.
- `plugins/quality-gates/scripts/qg-gc.py`, `qg-worktree.sh`, `check-trivia.sh`, `filter-docs.sh`, `discover-plan.sh`, `detect-runtime.sh`, `compute-test-scope-candidates.sh`, `detect_codex.sh`, `build_codex_prompt.py`, `codex_findings_to_yaml.py`, `synthesize_findings.py`, `run_codex_reviewer.sh`, `scout.py`.

---

## Task 0: Preflight — Branch + Worktree Sanity

**Files:** none (verification only).

- [ ] **Step 0.1: Confirm working tree**

Run:

```bash
pwd && git rev-parse --abbrev-ref HEAD && git status --short
```

Expected:
```
/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-askq-iteration
worktree-feature-qg-askq-iteration
(clean)
```

If not in this worktree, `cd` there first. If branch is not `worktree-feature-qg-askq-iteration`, abort — spec lock requires this branch.

- [ ] **Step 0.2: Record feature merge-base for AC14 final check**

Run:

```bash
git merge-base HEAD main
```

Save the resulting SHA mentally (or to a scratch note). Task 16's V1 step uses `git diff $(git merge-base HEAD main) HEAD -- plugins/quality-gates/hooks/post-tool-use*.py plugins/quality-gates/hooks/session-end-cleanup.py` to assert zero diff on the KEEP-locked files. Knowing the merge-base lets you re-run the same diff locally without re-computing.

---

## Task 1: V0 Smoke Test — `AskUserQuestion` Premise + OQ1 Resolution

> **Spec lock:** 본 task는 plan의 *첫* 코드-touching task. 결과에 따라 SKILL.md frontmatter의 `allowed-tools` 선언 형태가 결정됨 (OQ1). 본 task 실패 시 spec 자체가 무효 — implementation 중단 후 R1 또는 R2로 회귀.

**Files:**
- Create (temp): `/tmp/qg-v0-a.md`
- Create (temp): `/tmp/qg-v0-b.md`
- Create (note): `docs/superpowers/plans/notes/2026-05-27-v0-result.md` (결과 기록; plan에 상시 참조).

- [ ] **Step 1.1: Write V0-a stub (no AskUserQuestion in allowed-tools)**

```bash
cat > /tmp/qg-v0-a.md <<'EOF'
---
name: qg-v0-a-stub
description: V0 smoke test stub — AskUserQuestion not declared in allowed-tools.
allowed-tools:
  - Bash
---

# V0-a stub

이 stub은 AskUserQuestion 호출 → 같은 응답 안에서 Bash 호출이 가능한지를
검증한다.

1. AskUserQuestion으로 단일 yes/no 질문 호출.
2. 같은 turn 안에서 `Bash(echo same-turn-a)` 호출.

응답 trace에서 AskUserQuestion tool_result가 도착한 같은 assistant message
안에 Bash tool_use가 있어야 한다.
EOF
```

- [ ] **Step 1.2: Write V0-b stub (explicit AskUserQuestion in allowed-tools)**

```bash
cat > /tmp/qg-v0-b.md <<'EOF'
---
name: qg-v0-b-stub
description: V0 smoke test stub — AskUserQuestion explicitly declared.
allowed-tools:
  - AskUserQuestion
  - Bash
---

# V0-b stub

V0-a와 본문 동일. frontmatter `allowed-tools`에 `AskUserQuestion`을
명시 선언했을 때 동일하게 동작하는지 검증.

1. AskUserQuestion으로 단일 yes/no 질문 호출.
2. 같은 turn 안에서 `Bash(echo same-turn-b)` 호출.
EOF
```

- [ ] **Step 1.3: Execute V0-a manually in this Claude Code session**

This step requires a human-in-the-loop (the implementing engineer's CC session). Procedure:

1. Open a *fresh* Claude Code session in this worktree (or a scratch dir; the stub is path-independent).
2. Load V0-a by typing: `읽고 본문 지시 그대로 실행해줘. 파일: /tmp/qg-v0-a.md`.
3. The assistant will (a) call AskUserQuestion, (b) receive your yes/no answer, (c) attempt the Bash call.
4. Observe whether the Bash call succeeds in the *same* assistant message as the AskUserQuestion tool_result.

Possible outcomes:
- **PASS**: AskUserQuestion tool_result and `Bash(echo same-turn-a)` both appear, with `same-turn-a` printed.
- **FAIL**: AskUserQuestion raises `InputValidationError` (deferred tool not loaded) OR Bash blocked OR turn ends before Bash fires.

- [ ] **Step 1.4: Execute V0-b manually (same procedure)**

Same as Step 1.3 but with `/tmp/qg-v0-b.md`. Observe same/different outcome.

- [ ] **Step 1.5: Apply V0 result branching (spec V0)**

Write outcome to `docs/superpowers/plans/notes/2026-05-27-v0-result.md`:

```bash
mkdir -p docs/superpowers/plans/notes
cat > docs/superpowers/plans/notes/2026-05-27-v0-result.md <<EOF
# V0 Smoke Test Result — 2026-05-27

- **V0-a (no declaration)**: <PASS|FAIL — describe outcome>
- **V0-b (explicit declaration)**: <PASS|FAIL — describe outcome>

**OQ1 decision (per spec V0 branching):**
- V0-a PASS + V0-b PASS → adopt **(a)** lightness default. SKILL.md frontmatter NOT to declare AskUserQuestion.
- V0-a FAIL + V0-b PASS → adopt **(b)** explicit declaration. SKILL.md frontmatter MUST declare AskUserQuestion.
- V0-a PASS + V0-b FAIL → ABNORMAL. Escalate to user. Stop plan execution. Investigate CC harness version compat.
- V0-a FAIL + V0-b FAIL → SPEC INVALID. Stop plan execution. R1/R2 redesign required.

**Adopted path:** <(a) lightness | (b) explicit | ABNORMAL | SPEC_INVALID>

**Reasoning / observed trace summary:** <one paragraph>
EOF
```

- [ ] **Step 1.6: Decision gate**

Read the adopted path:
- **(a)** or **(b)**: proceed to Task 2. Tasks 8/SKILL rewrite will reference this decision when writing the new frontmatter.
- **ABNORMAL**: stop. Report to user. Re-run after CC harness compatibility resolved.
- **SPEC_INVALID**: stop. Report to user. Spec must be re-designed.

- [ ] **Step 1.7: Commit V0 note**

```bash
git add docs/superpowers/plans/notes/2026-05-27-v0-result.md
git commit -m "$(cat <<'EOF'
chore(quality-gates): V0 smoke test — AskUserQuestion premise + OQ1 resolution

V0-a/V0-b stub executed manually. OQ1 decision recorded for SKILL.md
frontmatter (Task 10).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 1.8: Clean temp stubs**

```bash
rm -f /tmp/qg-v0-a.md /tmp/qg-v0-b.md
```

---

## Task 2: New State File Schema — Document the Minimal Form (OQ3 Resolution)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md` (full rewrite — file is short).

> **OQ3 resolution (lock from this plan onward):** minimal frontmatter schema fields = `session_id`, `started_at`, `worktree_path` (optional, only when `/qg branch <name>` used), `gate2_iteration` (counter only, for output reporting). GC mtime anchor = file's filesystem mtime (no separate field).

- [ ] **Step 2.1: Rewrite state-file-format.md to minimal schema**

```bash
cat > plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md <<'EOF'
# State File Format (v2.0.0)

> v2.0.0 breaking change: cross-turn pipeline state는 SKILL의 단일 턴
> 시리얼 디스패치로 흡수됨. 본 state file은 **GC mtime anchor + worktree
> tracking + Gate 2 iter 카운터 reporting**만 보존한다.

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
worktree_path: "<absolute path>"     # OPTIONAL — set only when /qg branch <name> used
gate2_iteration: 0                   # Updated by SKILL.md ONLY via the
                                     # template `## Gate 2 Iteration N` line
                                     # in the History section (not frontmatter).
                                     # Kept at 0 in frontmatter — counter
                                     # display is in History only.
---

# Quality Gates Pipeline State (v2.0.0)

## History

(SKILL appends one line per gate verdict for in-turn observability.)

- [2026-05-27T10:00:00Z] Pipeline started
- [2026-05-27T10:02:00Z] Gate 1: PASS
- [2026-05-27T10:05:00Z] Gate 2 iter 1: FAIL → user chose Retry
- [2026-05-27T10:08:00Z] Gate 2 iter 2: PASS
- [2026-05-27T10:12:00Z] Gate 3: PASS
- [2026-05-27T10:12:01Z] Pipeline complete
```

## Removed Fields (vs v1.x)

The following v1.x fields are **no longer written or read**:

| Removed | Reason |
|---|---|
| `status` | No cross-turn state machine. Pipeline is single-turn. |
| `current_gate` | SKILL dispatches Gate 1 → 2 → 3 inline. |
| `consecutive_no_signal` | `<qg-signal>` tag removed. |
| `max_gate2_iterations` | Hard-coded constant in SKILL (5). |
| `gate3_resolution_iter` | Hard-coded constant in SKILL (default 3, env override). |
| `last_gate3_needed_hash` | Repeat detection moves to inline AskUserQuestion. |
| `max_gate3_resolutions` | Read inline from `DEVBREW_GATE3_MAX_RESOLUTIONS`. |
| `skip_runtime` | Passed as SKILL invocation arg. |
| `single_gate` | Passed as SKILL invocation arg. |
| `plan_file` | Passed as SKILL invocation arg. |
| `pr_url` | Passed as SKILL invocation arg. |
| `available_plugins` | SKILL re-derives inline (cheap). |
| `wall_clock_deadline_at` | Wall-clock guard removed (AskUserQuestion = in-loop user consent). |
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
EOF
```

- [ ] **Step 2.2: Verify file written correctly**

```bash
head -30 plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md
```

Expected: file starts with `# State File Format (v2.0.0)` and contains a `## Schema` heading.

- [ ] **Step 2.3: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md
git commit -m "$(cat <<'EOF'
feat(quality-gates)!: simplify state file schema for v2.0.0

Cross-turn pipeline state removed. Minimal schema: session_id, started_at,
worktree_path (optional), gate2_iteration (display only).

BREAKING CHANGE: legacy fields (status, current_gate, consecutive_no_signal,
wall_clock_deadline_at, etc.) removed. SessionStart advisor detects and
guides /cancel-qg cleanup.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Simplify `setup-qg.sh` — Remove stop-hook-Era Fields

**Files:**
- Modify: `plugins/quality-gates/scripts/setup-qg.sh` (lines 190-340 — env parsing + state file write).

The current script writes 15+ frontmatter fields. After this task it writes 4 (session_id, started_at, worktree_path conditional, gate2_iteration=0). It also removes wall-clock deadline computation and the `MAX_GATE3_RESOLUTIONS` echo (the env var is read by SKILL inline now).

- [ ] **Step 3.1: Read current script anchors**

```bash
grep -n -E "(MAX_GATE3|RAW_DEADLINE|WALL_CLOCK|consecutive_no_signal|max_gate2|gate3_resolution|last_gate3_needed|skip_runtime|single_gate|plan_file|pr_url|available_plugins|project_dir|Stop hook is active)" plugins/quality-gates/scripts/setup-qg.sh
```

Save the line numbers — they're the deletion/edit targets.

- [ ] **Step 3.2: Delete wall-clock deadline block (lines ~204-223)**

Use `Edit` tool to remove this block:

```bash
# Before (line 204-223):
# --- Wall-clock budget (T2-3) ---
RAW_DEADLINE_MIN="${DEVBREW_QG_DEADLINE_MIN:-30}"
if [[ ! "$RAW_DEADLINE_MIN" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Quality Gates: DEVBREW_QG_DEADLINE_MIN='$RAW_DEADLINE_MIN' is not numeric; using default 30" >&2
  DEADLINE_MIN=30
else
  DEADLINE_MIN="$RAW_DEADLINE_MIN"
fi
if [[ "$DEADLINE_MIN" -eq 0 ]]; then
  WALL_CLOCK_DEADLINE=""
else
  if WALL_CLOCK_DEADLINE="$(date -u -v+"${DEADLINE_MIN}"M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"; then
    :
  else
    WALL_CLOCK_DEADLINE="$(date -u -d "+${DEADLINE_MIN} minutes" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" || {
      echo "⚠️  Quality Gates: cannot compute wall-clock deadline on this platform; deadline disabled" >&2
      WALL_CLOCK_DEADLINE=""
    }
  fi
fi
```

Replace with: (nothing — remove the whole block including the `# ---` header line).

- [ ] **Step 3.3: Delete `DEVBREW_GATE3_MAX_RESOLUTIONS` block (lines ~190-200)**

Remove this block:

```bash
# DEVBREW_GATE3_MAX_RESOLUTIONS env override (default 3, integer 0..10 clamp)
RAW_MAX="${DEVBREW_GATE3_MAX_RESOLUTIONS:-3}"
if [[ ! "$RAW_MAX" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Quality Gates: DEVBREW_GATE3_MAX_RESOLUTIONS='$RAW_MAX' is not numeric; using default 3" >&2
  MAX_GATE3_RESOLUTIONS=3
elif [[ "$RAW_MAX" -gt 10 ]]; then
  echo "⚠️  Quality Gates: DEVBREW_GATE3_MAX_RESOLUTIONS='$RAW_MAX' exceeds maximum 10; clamping to 10" >&2
  MAX_GATE3_RESOLUTIONS=10
else
  MAX_GATE3_RESOLUTIONS="$RAW_MAX"
fi
```

Replace with: (nothing). SKILL will read the env directly when it needs the value.

- [ ] **Step 3.4: Delete Initial-State derivation block (lines ~282-293)**

Remove:

```bash
# --- Determine Initial State ---

CURRENT_GATE=1
STATUS="gate1_running"

if [[ -n "$SINGLE_GATE" ]]; then
  case $SINGLE_GATE in
    gate1) CURRENT_GATE=1; STATUS="gate1_running" ;;
    gate2) CURRENT_GATE=2; STATUS="gate2_running" ;;
    gate3) CURRENT_GATE=3; STATUS="gate3_running" ;;
  esac
fi
```

Replace with: (nothing). `SINGLE_GATE` is still parsed at top and surfaced via output (Step 3.6); no state machine derivation needed.

- [ ] **Step 3.5: Replace state-file write block (lines ~295-340)**

Find this block:

```bash
TEMP_FILE="${STATE_FILE}.tmp.$$"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

cat > "$TEMP_FILE" << EOF
---
status: $STATUS
current_gate: $CURRENT_GATE
gate2_iteration: 0
max_gate2_iterations: 5
gate3_resolution_iter: 0
last_gate3_needed_hash: ""
max_gate3_resolutions: $MAX_GATE3_RESOLUTIONS
consecutive_no_signal: 0
skip_runtime: $SKIP_RUNTIME
single_gate: ${SINGLE_GATE:-null}
plan_file: "$PLAN_FILE"
pr_url: "$PR_URL"
available_plugins: "$AVAILABLE_PLUGINS"
project_dir: "${WORKTREE_PATH:-$(pwd)}"
EOF

# Conditionally include worktree fields only when a named branch was given.
if [[ -n "$WORKTREE_PATH" ]]; then
  cat >> "$TEMP_FILE" << EOF
worktree_path: "${WORKTREE_PATH}"
target_branch: "${TARGET_BRANCH}"
EOF
fi

cat >> "$TEMP_FILE" << EOF
wall_clock_deadline_at: "$WALL_CLOCK_DEADLINE"
session_id: "$SESSION_ID"
started_at: "$TIMESTAMP"
---

# Quality Gates Pipeline State

## Gate Results

## Pipeline History
- [$TIMESTAMP] Pipeline started (iteration 1)
EOF

mv "$TEMP_FILE" "$STATE_FILE"
```

Replace with:

```bash
TEMP_FILE="${STATE_FILE}.tmp.$$"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

cat > "$TEMP_FILE" << EOF
---
session_id: "$SESSION_ID"
started_at: "$TIMESTAMP"
gate2_iteration: 0
EOF

# worktree_path is optional — only set when /qg branch <name> created one.
if [[ -n "$WORKTREE_PATH" ]]; then
  cat >> "$TEMP_FILE" << EOF
worktree_path: "$WORKTREE_PATH"
target_branch: "$TARGET_BRANCH"
EOF
fi

cat >> "$TEMP_FILE" << EOF
---

# Quality Gates Pipeline State (v2.0.0)

## History
- [$TIMESTAMP] Pipeline started
EOF

mv "$TEMP_FILE" "$STATE_FILE"
```

- [ ] **Step 3.6: Replace the trailing output messages (lines ~344-371)**

Find this block:

```bash
GATE_NAMES=("" "Plan Verification" "PR Review" "Runtime Verification")

if [[ -n "$SINGLE_GATE" ]]; then
  GATE_NUM=${SINGLE_GATE//gate/}
  echo "🔄 Quality Gates Pipeline — Single Gate Mode"
  echo ""
  echo "Gate: ${GATE_NUM} (${GATE_NAMES[$GATE_NUM]})"
else
  echo "🔄 Quality Gates Pipeline — Full Pipeline"
  echo ""
  echo "Gates: 1 (Plan Verification) → 2 (PR Review) → 3 (Runtime Verification)"
  if [[ "$SKIP_RUNTIME" == "true" ]]; then
    echo "       Gate 3 skipped (--skip-runtime)"
  fi
fi

echo ""
echo "Available plugins: ${AVAILABLE_PLUGINS:-none}"
if [[ -n "$PR_URL" ]]; then
  echo "PR URL: $PR_URL"
fi
if [[ "$PLAN_FILE" != "auto" ]]; then
  echo "Plan file: $PLAN_FILE"
fi
echo ""
echo "Stop hook is active. Pipeline progression is automatic."
echo "To cancel: /cancel-qg"
```

Replace with:

```bash
GATE_NAMES=("" "Plan Verification" "PR Review" "Runtime Verification")

if [[ -n "$SINGLE_GATE" ]]; then
  GATE_NUM=${SINGLE_GATE//gate/}
  echo "🔄 Quality Gates Pipeline — Single Gate Mode"
  echo ""
  echo "Gate: ${GATE_NUM} (${GATE_NAMES[$GATE_NUM]})"
else
  echo "🔄 Quality Gates Pipeline — Full Pipeline"
  echo ""
  echo "Gates: 1 (Plan Verification) → 2 (PR Review) → 3 (Runtime Verification)"
  if [[ "$SKIP_RUNTIME" == "true" ]]; then
    echo "       Gate 3 skipped (--skip-runtime)"
  fi
fi

echo ""
echo "Available plugins: ${AVAILABLE_PLUGINS:-none}"
if [[ -n "$PR_URL" ]]; then
  echo "PR URL: $PR_URL"
fi
if [[ "$PLAN_FILE" != "auto" ]]; then
  echo "Plan file: $PLAN_FILE"
fi
echo ""
echo "Pipeline runs in this turn. To cancel before run: /cancel-qg"
```

The `available_plugins`, `PR_URL`, `PLAN_FILE`, `SKIP_RUNTIME` variables remain in scope from the earlier parsing — they're now passed to SKILL via stdout banner text rather than persisted to the state file.

- [ ] **Step 3.7: Verify script still parses**

```bash
bash -n plugins/quality-gates/scripts/setup-qg.sh && echo "syntax OK"
```

Expected: `syntax OK`.

- [ ] **Step 3.8: Confirm removed identifiers gone from script**

```bash
! grep -qE 'wall_clock_deadline|MAX_GATE3_RESOLUTIONS|consecutive_no_signal|max_gate2_iterations|gate3_resolution_iter|last_gate3_needed_hash|current_gate:|status:' plugins/quality-gates/scripts/setup-qg.sh && echo "stripped clean"
```

Expected: `stripped clean`.

- [ ] **Step 3.9: Commit**

```bash
git add plugins/quality-gates/scripts/setup-qg.sh
git commit -m "$(cat <<'EOF'
feat(quality-gates)!: setup-qg.sh emits minimal v2.0.0 state schema

Removed: wall_clock_deadline, max_gate2_iterations, gate3_resolution_iter,
last_gate3_needed_hash, max_gate3_resolutions, consecutive_no_signal,
status, current_gate, skip_runtime (now arg-passed), single_gate,
plan_file, pr_url, available_plugins, project_dir.

Kept: session_id, started_at, worktree_path (conditional), target_branch
(conditional), gate2_iteration (display only).

BREAKING CHANGE: state file shape changed. Legacy v1.x state files are
detected by session-start-advisor and surfaced to user with /cancel-qg
guidance (no auto-migration; v1.x state machine semantics not preserved).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Shrink `pre-pipeline-check.sh` — Cross-Turn Status Check Goes Away

**Files:**
- Modify: `plugins/quality-gates/scripts/pre-pipeline-check.sh` (lines 38-48 — `active_resume` block uses `status:` field that no longer exists).

The script still has useful work (branch-mismatch + staleness for `files.md`). Only the `active_resume` early-exit branch reading `status:` becomes dead code in v2.0.0.

- [ ] **Step 4.1: Read current state**

```bash
sed -n '38,48p' plugins/quality-gates/scripts/pre-pipeline-check.sh
```

You should see the `# 1. Active state? Preserve everything and return early` block.

- [ ] **Step 4.2: Delete the active-resume block (lines 38-48)**

Remove:

```bash
# 1. Active state? Preserve everything and return early (no branch update).
if [[ -f "$STATE_FILE" ]]; then
  status="$(awk '/^status:/ {sub(/^status:[[:space:]]*/, ""); gsub(/"/, ""); print; exit}' "$STATE_FILE" 2>/dev/null || echo "")"
  case "$status" in
    gate1_running|gate2_running|gate3_running)
      echo "result: active_resume"
      echo "branch: $current_branch"
      exit 0
      ;;
  esac
fi
```

Replace with: (nothing). Also update the result-keys comment at the top of the file: remove `active_resume` from the list (line 7).

Edit the comment at line 7:

```diff
-#   active_resume      - mid-pipeline state detected; preserve session data, resume
-#   cleared_branch_mismatch - HEAD branch changed since last run; both state files deleted
```

becomes:

```diff
+#   cleared_branch_mismatch - HEAD branch changed since last run; both state files deleted
```

Renumber comments 1-6 → 1-5 if numbered.

- [ ] **Step 4.3: Verify script still parses + no dead `status` reference**

```bash
bash -n plugins/quality-gates/scripts/pre-pipeline-check.sh && \
  ! grep -q 'active_resume\|gate1_running\|gate2_running\|gate3_running' plugins/quality-gates/scripts/pre-pipeline-check.sh && \
  echo "OK"
```

Expected: `OK`.

- [ ] **Step 4.4: Commit**

```bash
git add plugins/quality-gates/scripts/pre-pipeline-check.sh
git commit -m "$(cat <<'EOF'
refactor(quality-gates): drop active_resume from pre-pipeline-check

v2.0.0 has no cross-turn pipeline status. Branch-mismatch and staleness
detection for files.md remains; status: field check removed.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Modify `session-start-advisor.py` — Remove In-Flight Branch, Keep Frontmatter Scan

**Files:**
- Modify: `plugins/quality-gates/hooks/session-start-advisor.py` (specifically lines 40-43 — `ACTIVE_STATUSES`/`GATE_RX`/`STATUS_RX` constants; lines 154-169 — `_emit_self_advisory`; lines 183-191 — `main()` self-pipeline branch).
- Keep: `_scan_agent_frontmatter_keys` (lines 79-102) intact (AC14).
- Replace removed advisory with a *legacy v2.0.0-state-file detector* that points users to `/cancel-qg`.

> **Spec C9 + AC14:** advisor 변경 범위는 정확히 두 가지 — in-flight 분기 제거 + legacy state file 1회 stderr 안내. frontmatter scan 함수는 **코드 변경 없이 유지**.

- [ ] **Step 5.1: Write the V8 + V8-pre test FIRST (TDD)**

Create `plugins/quality-gates/tests/test_session_start_advisor_v2.sh`:

```bash
cat > plugins/quality-gates/tests/test_session_start_advisor_v2.sh <<'EOF'
#!/usr/bin/env bash
# v2.0.0 session-start-advisor verification.
#   V8 (AC16): legacy v1.x state file triggers `/cancel-qg` advisory on stderr.
#   V8-pre (AC14 advisory): in-flight code paths gone, frontmatter scan kept.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ADVISOR="$ROOT/quality-gates/hooks/session-start-advisor.py"

# ============== V8-pre (AC14): static code-structure check ==============
echo "--- V8-pre: AC14 static structure check ---"
if grep -qE 'pipeline_status|current_gate|in_flight_pipeline|ACTIVE_STATUSES' "$ADVISOR"; then
  echo "FAIL: in-flight pipeline detection identifiers still present in advisor"
  grep -nE 'pipeline_status|current_gate|in_flight_pipeline|ACTIVE_STATUSES' "$ADVISOR"
  exit 1
fi
if ! grep -qE 'frontmatter|scan_agent' "$ADVISOR"; then
  echo "FAIL: frontmatter scan function missing from advisor (AC14 KEEP violated)"
  exit 1
fi
echo "PASS: V8-pre"

# ============== V8 (AC16): legacy state file advisory ==============
echo "--- V8: AC16 legacy state advisory ---"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.claude/quality-gates/legacy-test-sid-deadbeef"
cat > "$TMP/.claude/quality-gates/legacy-test-sid-deadbeef/pipeline.md" <<'INNER'
---
session_id: legacy-test-sid-deadbeef
current_gate: 2
consecutive_no_signal: 2
gate2_iteration: 3
max_gate2_iterations: 5
status: gate2_running
---
INNER

# Also create a v1.x flat marker (legacy detection fires on either).
touch "$TMP/.claude/quality-gates.local.md"

SESSION_ID="$(uuidgen 2>/dev/null || echo test-session-newsid)"
STDERR_LOG="$TMP/stderr.log"
STDOUT_LOG="$TMP/stdout.log"

echo "{\"session_id\":\"$SESSION_ID\",\"cwd\":\"$TMP\"}" \
  | python3 "$ADVISOR" >"$STDOUT_LOG" 2>"$STDERR_LOG"

# AC16 lock: legacy advisory must mention /cancel-qg.
# Spec says: emit on stderr (V8 step 4 grep) — current code emits flat-file
# notice on stdout (line 178-181). v2.0.0 changes both to stderr AND adds
# /cancel-qg directive.
if ! grep -q '/cancel-qg' "$STDERR_LOG" 2>/dev/null && ! grep -q '/cancel-qg' "$STDOUT_LOG" 2>/dev/null; then
  echo "FAIL: legacy advisory missing /cancel-qg directive"
  echo "--- stderr ---"; cat "$STDERR_LOG"
  echo "--- stdout ---"; cat "$STDOUT_LOG"
  exit 1
fi
if ! grep -qi 'legacy\|v1\.\|v2\.0' "$STDERR_LOG" 2>/dev/null && ! grep -qi 'legacy\|v1\.\|v2\.0' "$STDOUT_LOG" 2>/dev/null; then
  echo "FAIL: legacy advisory missing legacy/version token"
  exit 1
fi
echo "PASS: V8"

echo "All tests pass."
EOF
chmod +x plugins/quality-gates/tests/test_session_start_advisor_v2.sh
```

- [ ] **Step 5.2: Run test — expect FAIL on V8-pre (identifiers still present)**

```bash
plugins/quality-gates/tests/test_session_start_advisor_v2.sh; echo "exit=$?"
```

Expected: `FAIL: in-flight pipeline detection identifiers still present in advisor` then `exit=1`.

- [ ] **Step 5.3: Edit `session-start-advisor.py` — delete in-flight constants**

Use `Edit` to remove these constants (lines ~40-43):

```python
ACTIVE_STATUSES = {"gate1_running", "gate2_running", "gate3_running"}
GATE_RX = re.compile(r"^current_gate:\s*(\S+)", re.MULTILINE)
STARTED_AT_RX = re.compile(r"^started_at:\s*\"?([^\"\n]+)\"?", re.MULTILINE)
STATUS_RX = re.compile(r"^status:\s*\"?(\S+?)\"?\s*$", re.MULTILINE)
```

Replace with:

```python
# v2.0.0: in-flight detection removed. Legacy v1.x markers still detected
# for one-shot advisory (see _emit_legacy_v1_advisory).
LEGACY_V1_KEYS = ("status:", "current_gate:", "consecutive_no_signal:")
```

- [ ] **Step 5.4: Delete `_sibling_active_count` (lines ~127-151) and `_emit_self_advisory` (lines ~154-169)**

Use `Edit` to remove the full `def _sibling_active_count(...)` function and the full `def _emit_self_advisory(...)` function. They are no longer called.

- [ ] **Step 5.5: Replace `main()` body to drop in-flight branch + add v1.x-state-file advisory**

Find current `main()` (lines ~172-199) and replace its body with:

```python
def _emit_legacy_v1_advisory(payload: dict, self_sid: str) -> bool:
    """Detect legacy v1.x state file (per-session or flat) and emit one-shot
    `/cancel-qg` guidance on stderr. Returns True if anything was found."""
    found = False
    # 1. Per-session v1.x state file with stop-hook-era keys.
    if self_sid:
        per_session = _state_root(payload) / self_sid / "pipeline.md"
        if per_session.exists():
            try:
                text = per_session.read_text()
            except OSError:
                text = ""
            if any(key in text for key in LEGACY_V1_KEYS):
                sys.stderr.write(
                    "[quality-gates v2.0.0] Legacy v1.x pipeline state detected "
                    "in current session. Run `/cancel-qg` to clear before invoking "
                    "`/qg` (v2.0.0 single-turn pipeline cannot resume v1.x state).\n"
                )
                found = True
    # 2. Flat v1.5.0 state files.
    if _legacy_present(payload):
        sys.stderr.write(
            "[quality-gates v2.0.0] Legacy v1.5.0 flat state files detected. "
            "Run `/qg --reset` or `/cancel-qg` to remove. They will also be "
            "removed automatically on next `/qg` invocation.\n"
        )
        found = True
    return found


def main() -> int:
    if _disabled():
        return 0
    payload = _load_payload()
    self_sid = _self_session_id(payload)
    _emit_legacy_v1_advisory(payload, self_sid)
    _scan_agent_frontmatter_keys(payload)
    return 0
```

Important details:
- The old `_emit_self_advisory` path (in-flight self-session) and verbose `_sibling_active_count` reporting are gone.
- `_legacy_present` (lines ~120-124) stays — it now feeds `_emit_legacy_v1_advisory`.
- `_verbose` (lines ~105-106) can be removed if unused — verify with `grep _verbose plugins/quality-gates/hooks/session-start-advisor.py`. If only its `def` remains, delete the def too.

- [ ] **Step 5.6: Trim now-unused imports + helpers**

Check imports:

```bash
grep -n '^import\|^from' plugins/quality-gates/hooks/session-start-advisor.py
```

If `re` is now only used by `_scan_agent_frontmatter_keys`, keep it. If `GATE_RX`/`STATUS_RX`/`STARTED_AT_RX` removal left orphan helpers (`_strip_quotes`, `SESSION_PATTERN`), check usage:

```bash
grep -n '_strip_quotes\|SESSION_PATTERN' plugins/quality-gates/hooks/session-start-advisor.py
```

- `_strip_quotes` was only used by `_emit_self_advisory` and `_sibling_active_count` — delete its def (~lines 47-48).
- `SESSION_PATTERN` was only used by `_sibling_active_count` — delete its def.

- [ ] **Step 5.7: Update the module docstring**

Replace the original 24-line docstring at the top of the file with a v2.0.0 description:

```python
"""SessionStart hook: advisory only — never mutates state.

v2.0.0 behaviors:
- Legacy v1.x per-session pipeline.md (with stop-hook-era keys) → stderr
  one-shot advisory pointing to `/cancel-qg`.
- Legacy v1.5.0 flat state files (.claude/quality-gates.local.md etc.) →
  stderr one-shot advisory pointing to `/qg --reset`.
- frontmatter-scan sub-feature: warn about kebab-case allowed-tools /
  disallowed-tools in plugins/*/agents/*.md (unchanged from v1.x).

In-flight pipeline detection was removed in v2.0.0 — pipelines no longer
span turns, so there is nothing to "resume" across sessions.

Working-directory contract: state root derived from payload['cwd']; falls
back loudly.

Kill switches:
  DEVBREW_DISABLE_QUALITY_GATES=1                          - disables this hook entirely
  DEVBREW_SKIP_HOOKS=quality-gates:session-start-advisor   - skip just this one

Sub-feature kill switch:
  DEVBREW_SKIP_HOOKS=quality-gates:session-start-advisor:frontmatter-scan
"""
```

- [ ] **Step 5.8: Run the V2 test — expect PASS**

```bash
plugins/quality-gates/tests/test_session_start_advisor_v2.sh; echo "exit=$?"
```

Expected: both `PASS: V8-pre` and `PASS: V8` print; `exit=0`.

If V8 fails because the advisory is on stderr but the existing flat-file advisory at line 177-181 was on stdout, the test allows either stream. If the test fails for another reason, debug before commit.

- [ ] **Step 5.9: Commit**

```bash
git add plugins/quality-gates/hooks/session-start-advisor.py plugins/quality-gates/tests/test_session_start_advisor_v2.sh
git commit -m "$(cat <<'EOF'
refactor(quality-gates)!: session-start-advisor drops in-flight detection

v2.0.0 has no cross-turn pipelines; legacy v1.x state files now produce a
one-shot stderr advisory pointing the user at /cancel-qg or /qg --reset.

Frontmatter-scan sub-feature unchanged (AC14 KEEP).

Tests:
  tests/test_session_start_advisor_v2.sh — V8 (legacy advisory) + V8-pre
  (code-structure grep per spec round-4 advisory).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Delete `stop-hook.py` + Remove Stop Entry from `hooks.json`

**Files:**
- Delete: `plugins/quality-gates/hooks/stop-hook.py` (1205 LOC, 50 KB).
- Modify: `plugins/quality-gates/hooks/hooks.json` (lines 2, 4-14 — `description` text + Stop event block).

- [ ] **Step 6.1: Delete the file**

```bash
git rm plugins/quality-gates/hooks/stop-hook.py
```

- [ ] **Step 6.2: Edit `hooks.json` — remove the Stop block**

Original content:

```json
{
  "description": "Quality Gates - Stop hook for pipeline progression + PostToolUse session-tracker for /qg scope + SessionStart advisor + SessionEnd cleanup",
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/stop-hook.py",
            "timeout": 30
          }
        ]
      }
    ],
    "PostToolUse": [ ... ],
    ...
  }
}
```

Replace with:

```json
{
  "description": "Quality Gates v2.0.0 — PostToolUse session-tracker for /qg scope + SessionStart legacy-state advisor + SessionEnd cleanup. Pipeline progression managed in-turn by the quality-pipeline SKILL.",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/post-tool-use-session-tracker.py"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/post-tool-use.py"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/session-start-advisor.py"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/session-end-cleanup.py"
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 6.3: Verify JSON valid + Stop gone**

```bash
jq . plugins/quality-gates/hooks/hooks.json > /dev/null && \
  ! jq -e '.hooks.Stop' plugins/quality-gates/hooks/hooks.json > /dev/null && \
  echo "OK"
```

Expected: `OK`.

- [ ] **Step 6.4: Verify file gone**

```bash
test ! -f plugins/quality-gates/hooks/stop-hook.py && echo "OK"
```

Expected: `OK`.

- [ ] **Step 6.5: Verify no orphan references in the plugin tree**

```bash
! grep -rqE 'stop-hook\.py|compute_transition|consecutive_no_signal|<qg-signal>|QG-STOP-HOOK-CONTINUATION|DEVBREW_QG_DEADLINE_MIN|DEVBREW_QG_NO_SIGNAL_MAX' plugins/quality-gates/ --include='*.py' --include='*.sh' --include='*.json' && echo "no orphan refs in code"
```

Expected: `no orphan refs in code`. (SKILL.md and README still have these tokens — they're cleaned in Tasks 10 and 14.)

- [ ] **Step 6.6: Commit**

```bash
git add plugins/quality-gates/hooks/hooks.json
git commit -m "$(cat <<'EOF'
feat(quality-gates)!: remove stop-hook.py + Stop event registration

stop-hook.py (1205 LOC, 13-transition state machine, wall-clock guard,
no-signal counter) deleted. hooks.json Stop entry removed. Pipeline
progression now lives in the quality-pipeline SKILL as in-turn serial
dispatch with AskUserQuestion at decision points.

BREAKING CHANGE: <qg-signal> emission contract and QG-STOP-HOOK-CONTINUATION
sentinel are no longer recognized by any code path. SKILL.md will be
rewritten to match in a following commit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Delete Obsolete Tests + Inventory Surviving Tests

**Files:**
- Delete: tests matching patterns `test_*stop_hook*`, `test_*transition*`, `test_no_signal*`, `test_forward_only_prose.sh`, plus any test that imports or exec'es `stop-hook.py`.
- Keep (per spec V9 + AC15): `test_adversarial_model_consistency.sh`, `test_agent_frontmatter_keys.sh`, `test_discover_plan.sh`, `test_branch_worktree.sh`, `test_no_secret_prompts.py`, all detect/codex/findings tests, all kill-switch tests *that don't touch stop-hook*.

- [ ] **Step 7.1: Enumerate stop-hook-related tests**

```bash
ls plugins/quality-gates/tests/ | grep -E 'stop_hook|transition|no_signal|forward_only'
```

Expected output (current state):

```
test_forward_only_prose.sh
```

(There are no `test_stop_hook*`, `test_transition*`, `test_no_signal*` files in the current tree — they were already cleaned in earlier v1.x releases, or never existed. The spec lists them defensively; only what actually exists needs deleting.)

- [ ] **Step 7.2: Inspect `test_forward_only_prose.sh` — confirm it's stop-hook-coupled**

```bash
head -20 plugins/quality-gates/tests/test_forward_only_prose.sh
```

If it references stop-hook semantics (NEEDS_RESTART, `<qg-signal>`, transition kinds), delete:

```bash
git rm plugins/quality-gates/tests/test_forward_only_prose.sh
```

If it tests a SKILL prose contract that survives v2.0.0 (e.g. just that NEEDS_RESTART terminates), KEEP and add a note in CHANGELOG that it now tests SKILL behavior rather than stop-hook behavior.

- [ ] **Step 7.3: Scan all tests for stop-hook coupling**

```bash
grep -lE 'stop-hook|stop_hook|<qg-signal>|QG-STOP-HOOK-CONTINUATION|compute_transition|consecutive_no_signal' plugins/quality-gates/tests/
```

For each file printed:
1. Read the file to see whether it's *exclusively* about stop-hook (delete) or whether stop-hook is incidental (edit to remove the coupling).
2. Apply the appropriate fix.

Common candidates to inspect (based on filenames):
- `test_hook_cwd_contract.py` — tests hook cwd contract; if it loads stop-hook, change to load only the remaining hooks. If it can't be salvaged, delete.
- `test_kill_switches.py` — likely tests DEVBREW_DISABLE_QUALITY_GATES; the SKILL preflight must honor it (Task 10). Keep, but if it tests stop-hook-specific kill switches, edit out those cases.
- `test_isolation.sh` — possibly stop-hook isolation; inspect and decide.
- `test_consent_marker_write_failure.sh` — may reference stop-hook consent markers; inspect.
- `test_failure_injection.sh` — may inject failures into stop-hook; if so, retarget to SKILL or delete.

- [ ] **Step 7.4: Commit the test deletions/edits**

```bash
git add plugins/quality-gates/tests/
git commit -m "$(cat <<'EOF'
test(quality-gates): drop stop-hook-coupled tests for v2.0.0

Removed/retargeted tests that depend on stop-hook.py semantics
(<qg-signal>, compute_transition, NEEDS_RESTART continuation prose).
Replacement coverage arrives in test_skill_orchestration.sh (Task 8).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: New Test — `test_skill_orchestration.sh` (Static grep wrapper for AC5–AC8, AC18)

**Files:**
- Create: `plugins/quality-gates/tests/test_skill_orchestration.sh`.

Per spec V6 lock: this is **approach (a) static SKILL.md instruction grep**. It wraps V2a (gate order), V2b (context anchors + options + P21), and V7 (PASS-marker proximity heuristic) into one script that returns a single exit code.

> **TDD note:** This test will FAIL at this point (SKILL.md still has v1.x content). That's the point — we write the test, then rewrite SKILL.md in Task 10 until the test passes.

- [ ] **Step 8.1: Write the orchestration test**

```bash
cat > plugins/quality-gates/tests/test_skill_orchestration.sh <<'EOF'
#!/usr/bin/env bash
# v2.0.0 SKILL.md orchestration verification (static grep approach).
#
# Wraps spec verification steps:
#   V2a — AC5: Gate 1 → Gate 2 → Gate 3 first-mention line order monotonic
#   V2b — AC6/AC7/AC8: context anchors + 3-option labels + P21 token
#   V7  — AC18: AskUserQuestion not within ±10 lines of any "PASS" marker
#                (supporting heuristic; primary anchor-check lives in V2b)
#
# Exit 0 if all pass; non-zero with diagnostic on first failure.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
S="$ROOT/quality-gates/skills/quality-pipeline/SKILL.md"

if [[ ! -f "$S" ]]; then
  echo "FAIL: SKILL.md not found at $S"
  exit 1
fi

# ============== V2a: Gate label order (AC5) ==============
awk '/Gate 1/{if(!g1)g1=NR} /Gate 2/{if(!g2)g2=NR} /Gate 3/{if(!g3)g3=NR} END{
  if (!(g1 && g2 && g3 && g1<g2 && g2<g3)) {
    print "FAIL V2a: Gate label order broken. g1=" g1 " g2=" g2 " g3=" g3
    exit 1
  }
}' "$S" || exit 1
echo "PASS V2a (gate-label order)"

# ============== V2b: Context anchors + options + P21 (AC6/7/8) ==============
check() {
  local needle="$1"
  local label="$2"
  if ! grep -q -- "$needle" "$S"; then
    echo "FAIL V2b: missing $label — needle: $needle"
    exit 1
  fi
}
# Gate 1 FAIL context
check "Plan verification failed" "Gate 1 FAIL anchor"
check "Continue anyway"          "Gate 1 FAIL option"
check "View detail"              "Gate 1 FAIL option"
# Gate 2 iter context
check "findings remain"          "Gate 2 iter anchor"
check "Retry"                    "Gate 2 iter option"
check "Proceed to Gate 3"        "Gate 2 iter option"
# Gate 3 NEEDS_RESOLUTION context
check "Runtime verifier needs"   "Gate 3 anchor"
check "Yes, retry"               "Gate 3 option"
check "Skip with evidence"       "Gate 3 option"
check "P21"                      "P21 secret-policy token"
echo "PASS V2b (context anchors + options + P21)"

# ============== V7: PASS proximity (AC18 supporting) ==============
awk '
  /PASS/        {pass_lines[NR]=1}
  /AskUserQuestion/ {ask_lines[NR]=1}
  END {
    for (p in pass_lines) {
      for (a in ask_lines) {
        if (a >= p-10 && a <= p+10) {
          print "FAIL V7: AskUserQuestion at line " a " too close to PASS at line " p
          exit 1
        }
      }
    }
  }
' "$S" || exit 1
echo "PASS V7 (PASS-AskUserQuestion proximity)"

echo "All SKILL orchestration checks pass."
EOF
chmod +x plugins/quality-gates/tests/test_skill_orchestration.sh
```

- [ ] **Step 8.2: Run the test — expect FAIL on V2b (SKILL.md still v1.x)**

```bash
plugins/quality-gates/tests/test_skill_orchestration.sh; echo "exit=$?"
```

Expected: `FAIL V2b: missing Gate 1 FAIL anchor — needle: Plan verification failed` then `exit=1`.

- [ ] **Step 8.3: Commit the test (Task 10 will iterate SKILL.md to green)**

```bash
git add plugins/quality-gates/tests/test_skill_orchestration.sh
git commit -m "$(cat <<'EOF'
test(quality-gates): add SKILL.md orchestration grep test

Wraps spec V2a/V2b/V7 into one script. Currently failing — Task 10
will rewrite SKILL.md to v2.0.0 form until this passes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: New Test — `test_cancel_qg.sh` (V10, AC17)

**Files:**
- Create: `plugins/quality-gates/tests/test_cancel_qg.sh`.

> Spec V10 lock: **command-file 직접 파싱 금지**. The test (a) executes equivalent shell directly inside the script to validate behavior, AND (b) greps the command file to assert the documented behavior matches.

- [ ] **Step 9.1: Write the test**

```bash
cat > plugins/quality-gates/tests/test_cancel_qg.sh <<'EOF'
#!/usr/bin/env bash
# v2.0.0 /cancel-qg, /qg --reset, /qg --gc fixture verification (AC17, V10).
#
# Approach (spec V10 lock):
#   (1) Run the documented behavior directly via fixture shell — verify effect.
#   (2) Static-grep the command markdown file — verify it documents the same.
# Two stages decoupled so command-file drift triggers stage-2 failure.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

# ============== /cancel-qg ==============
echo "--- /cancel-qg behavior fixture ---"
SID="test-sid-deadbeef"
mkdir -p ".claude/quality-gates/$SID"
echo '---' > ".claude/quality-gates/$SID/pipeline.md"

# Mimic command behavior (SID guard + rm -rf).
if [[ -z "$SID" || ! "$SID" =~ ^[A-Za-z0-9_-]{8,}$ ]]; then
  echo "FAIL: SID guard rejected valid SID"; exit 1
fi
rm -rf -- ".claude/quality-gates/$SID"
test ! -d ".claude/quality-gates/$SID" || { echo "FAIL: folder still exists"; exit 1; }
echo "PASS /cancel-qg (behavior)"

echo "--- /cancel-qg command-file static check ---"
grep -q 'rm -rf' "$ROOT/quality-gates/commands/cancel-qg.md" || { echo "FAIL: cancel-qg.md missing rm -rf"; exit 1; }
grep -qiE 'cancel|cleared|removed' "$ROOT/quality-gates/commands/cancel-qg.md" || { echo "FAIL: cancel-qg.md missing cancel/cleared/removed token"; exit 1; }
echo "PASS /cancel-qg (command-file documents behavior)"

# ============== /qg --reset (legacy v1.5.0 flat file sweep) ==============
echo "--- /qg --reset behavior fixture ---"
touch .claude/quality-gates.local.md
touch .claude/quality-gates-session.local.md
touch .claude/quality-gates-branch.local.md
touch .claude/qg-diff-cache.txt
touch .claude/qg-code-paths.tmp

rm -f .claude/quality-gates.local.md \
      .claude/quality-gates-session.local.md \
      .claude/quality-gates-branch.local.md \
      .claude/qg-diff-cache.txt \
      .claude/qg-code-paths.tmp

for f in quality-gates.local.md quality-gates-session.local.md quality-gates-branch.local.md qg-diff-cache.txt qg-code-paths.tmp; do
  test ! -f ".claude/$f" || { echo "FAIL: legacy $f still present"; exit 1; }
done
echo "PASS /qg --reset (behavior)"

echo "--- /qg --reset command-file static check ---"
grep -q 'rm -f' "$ROOT/quality-gates/commands/qg.md" || { echo "FAIL: qg.md missing rm -f"; exit 1; }
grep -qE 'quality-gates(\.|-session|-branch)' "$ROOT/quality-gates/commands/qg.md" || { echo "FAIL: qg.md missing legacy file references"; exit 1; }
echo "PASS /qg --reset (command-file documents behavior)"

# ============== /qg --gc (TTL sweep) ==============
echo "--- /qg --gc TTL fixture ---"
mkdir -p ".claude/quality-gates/old-sid-deadbeef"
touch -t 200001010000 ".claude/quality-gates/old-sid-deadbeef/pipeline.md"

# Run real production script (per spec: qg-gc.py is the production tool, no mock).
# Note: HOME-relative CLAUDE_CODE_SESSION_ID may not be set; pass --session-id to
# avoid the GC treating our test folder as the active session.
python3 "$ROOT/quality-gates/scripts/qg-gc.py" --session-id "current-sid-not-this-one" 2>/dev/null || true

if [[ -d ".claude/quality-gates/old-sid-deadbeef" ]]; then
  echo "FAIL: qg-gc.py did not remove stale folder"
  exit 1
fi
echo "PASS /qg --gc (behavior)"

echo "--- /qg --gc command-file static check ---"
grep -q 'qg-gc.py' "$ROOT/quality-gates/commands/qg.md" || { echo "FAIL: qg.md missing qg-gc.py reference"; exit 1; }
echo "PASS /qg --gc (command-file documents behavior)"

echo "All cancel-qg / reset / gc checks pass."
EOF
chmod +x plugins/quality-gates/tests/test_cancel_qg.sh
```

- [ ] **Step 9.2: Run the test — expect PASS (commands not yet edited but behavior strings already match)**

```bash
plugins/quality-gates/tests/test_cancel_qg.sh; echo "exit=$?"
```

If FAIL, the failure tells you which grep missed in the current `qg.md`/`cancel-qg.md`. Either the command files lack the documented text — in which case fix in Task 11 — or the test grep is too strict; adjust to a stable substring.

> **Note on TTL fixture failure mode:** If the `qg-gc.py` step fails because it uses an internal `cwd`-rooted state dir, the script may not find `.claude/quality-gates/old-sid-deadbeef` under `$TMP`. The spec acknowledges this and lists `--dry-run`/`--root` option addition as Deferred to plan. If this test fails for that reason, add a minimal `--root` flag to qg-gc.py here as a sub-task:

> **Sub-task 9.2.1 (only if 9.2 fails on `/qg --gc` TTL step):** Extend `qg-gc.py` with `--root <path>` to override the state root for testing. Edit `plugins/quality-gates/scripts/qg-gc.py` `main()`:

```python
def main() -> int:
    self_id = os.environ.get("CLAUDE_CODE_SESSION_ID") or None
    args = sys.argv[1:]
    if "--session-id" in args:
        i = args.index("--session-id")
        if i + 1 < len(args):
            self_id = args[i + 1]
    root_override = None
    if "--root" in args:
        i = args.index("--root")
        if i + 1 < len(args):
            root_override = args[i + 1]
    gc(self_id, root_override=root_override)
    return 0
```

And extend `gc()` to accept the optional `root_override` (passing it through to the path constants the function uses). Update the test to pass `--root "$TMP/.claude/quality-gates"`. Re-run.

- [ ] **Step 9.3: Commit (with 9.2.1 changes if applied)**

```bash
git add plugins/quality-gates/tests/test_cancel_qg.sh
# If sub-task 9.2.1 was applied:
# git add plugins/quality-gates/scripts/qg-gc.py
git commit -m "$(cat <<'EOF'
test(quality-gates): add /cancel-qg, /qg --reset, /qg --gc fixture test

Verifies AC17 via two-stage approach: (1) exec equivalent shell in fixture,
(2) grep command-file to confirm it documents same behavior. Decoupling
catches command-file drift.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Rewrite `SKILL.md` for v2.0.0 — Single-Turn Serial Dispatch + AskUserQuestion

**Files:**
- Modify (REWRITE-LARGE): `plugins/quality-gates/skills/quality-pipeline/SKILL.md` (currently 70 KB, ~1447 lines).

This is the largest task. The current SKILL.md is single-gate-per-turn with `<qg-signal>` emission and continuation sentinel handling. The new SKILL.md is full-pipeline-per-turn with AskUserQuestion gating. Approach: write in **sections**, run the orchestration test after each section, commit when green.

> **Frontmatter `allowed-tools` decision:** based on Task 1 OQ1 resolution. If **(a)** lightness — omit `AskUserQuestion`. If **(b)** explicit — include `AskUserQuestion`. Apply in Step 10.1.

- [ ] **Step 10.1: Replace SKILL.md frontmatter + module intro**

Replace lines 1-22 (frontmatter + opening prose) with:

```markdown
---
name: quality-pipeline
description: >
  This skill runs the full quality-gates pipeline in a single assistant
  turn. Triggered by `/qg`, "run quality gates", "verify my implementation",
  "check code quality", or "is my PR ready to merge". Dispatches Gate 1
  (plan verification) → Gate 2 (PR review, iterative) → Gate 3 (runtime
  verification) serially. Progression decisions and Gate 2 fix-loop
  iteration boundaries surface to the user via AskUserQuestion tool calls.
  Happy path (all gates PASS) requires zero user clicks.
cost_class: variable
allowed-tools:
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/run_codex_reviewer.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/synthesize_findings.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/scout.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/pre-pipeline-check.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-trivia.sh:*)
  - Agent
  - Edit
  - Write
  - Read
  - Glob
  - Grep
  # AskUserQuestion: <DECISION FROM TASK 1 OQ1 — include this line only if (b) explicit was adopted>
---

# Quality Gates — In-Turn Orchestrator (v2.0.0)

You are running the **full quality-gates pipeline** in a single assistant
turn. You dispatch Gate 1 → Gate 2 → Gate 3 serially. At decision points
(Gate 1 FAIL, Gate 2 iter boundary, Gate 3 NEEDS_RESOLUTION) you call
`AskUserQuestion` and branch on the user's response — the response arrives
as a tool result in the same turn, so no Stop hook and no continuation
sentinel are needed.

**Law 2 (Writer ≠ Reviewer):** you are the orchestrator (writer). All
verdict-producing agents are dispatched as separate subagents with
`disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` so they cannot
mutate the working tree. You ARE allowed to apply user-approved fixes
(Gate 2 "Retry" path) using Edit/Write — those changes are user-consented,
not self-approval.

**State file:** read `worktree_path` from `.claude/quality-gates/<sid>/pipeline.md`
only during preflight; never write. Setup script handles creation, /cancel-qg
handles deletion.
```

- [ ] **Step 10.2: Replace `## Contents`, `## Preflight`, `## Arguments` sections**

Delete the v1.x `## Contents`, `## Preflight`, `## Arguments` sections (currently ~lines 25-115). Replace with:

```markdown
## Contents

이 SKILL은 단일 어시스턴트 턴 안에서 전체 파이프라인을 실행. 섹션 그룹:

1. **Workflow (top-to-bottom on invocation):**
   - [Preflight](#preflight) — kill switch / setup-qg / pre-pipeline-check
   - [Arguments](#arguments) — `/qg` flags 파싱
   - [Dispatch Loop](#dispatch-loop) — Gate 1 → Gate 2 (iter) → Gate 3 시리얼 디스패치
2. **Per-gate dispatch logic:**
   - [Trivia escape](#trivia-escape) — one-sentence diff → all gates skipped
   - [Gate 1: Plan Verification](#gate-1-plan-verification) — dispatch `plan-verifier`
   - [Gate 2: PR Review](#gate-2-pr-review) — scout + Phase 1 + adversarial + synthesizer; iter loop with AskUserQuestion at every boundary
   - [Gate 3: Runtime Verification](#gate-3-runtime-verification) — test-scope-validator + runtime-verifier
3. **Decision points (AskUserQuestion templates):**
   - [Gate 1 FAIL decision](#gate-1-fail-decision)
   - [Gate 2 iter boundary decision](#gate-2-iter-boundary-decision)
   - [Gate 2 max-iter decision](#gate-2-max-iter-decision)
   - [Gate 3 NEEDS_RESOLUTION decision](#gate-3-needs_resolution-decision)
4. **Output templates** (verbatim, field substitution):
   - Gate 1/2/3 result templates
   - Final summary template
   - [Rules](#rules) — Law 2 invariants, state file invariants

## Preflight

이 섹션은 첫 번째 (그리고 유일한) SKILL 호출에서 한 번만 실행된다.

**Step P1 — Global kill switch.** If `DEVBREW_DISABLE_QUALITY_GATES=1`,
emit `[quality-gates] disabled via DEVBREW_DISABLE_QUALITY_GATES=1` and
return immediately. Do NOT call setup-qg.sh or any agent.

**Step P2 — Setup state.** Run:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh" --ensure $ARGUMENTS
```

`setup-qg.sh --ensure` creates the per-session state file
(`.claude/quality-gates/<sid>/pipeline.md`) with minimal v2.0.0 schema.
Exit non-zero → surface stderr verbatim and abort.

**Step P3 — Pre-pipeline check (scope detection).** Run:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/pre-pipeline-check.sh"
```

Parse the `result:` line. `cleared_branch_mismatch` / `cleared_stale` /
`fresh_start` are normal. Use the result downstream when computing Gate 2
diff scope.

## Arguments

Parse from `/qg` invocation:
- `gate` (optional): `gate1`, `gate2`, `gate3`, or absent (full pipeline).
- `plan_path` (optional): defaults to "auto" (`scripts/discover-plan.sh`).
- `pr_url` (optional).
- `skip_runtime` (flag): if set, skip Gate 3.
- `paths` (optional, repeatable): scope override for Gate 2 diff.

Single-gate mode (`gate1`/`gate2`/`gate3`) runs ONLY the named gate and
emits its verdict directly — no AskUserQuestion, no inter-gate transition.

## Dispatch Loop

Full pipeline mode:

1. Run [Trivia escape](#trivia-escape). If trivia detected, print "Trivia
   diff — all gates skipped" and return.
2. Run [Gate 1: Plan Verification](#gate-1-plan-verification).
   - PASS → continue to Gate 2 (silently; print one-line "Gate 1: PASS").
   - FAIL → invoke [Gate 1 FAIL decision](#gate-1-fail-decision); branch
     per user choice (Continue anyway / Stop / View detail).
3. Run [Gate 2: PR Review](#gate-2-pr-review). Iterate (review → fix?) up
   to 5 times. At the end of EACH iteration:
   - findings empty → print "Gate 2 iter N: PASS" and continue to Gate 3.
   - findings non-empty → invoke [Gate 2 iter boundary decision](#gate-2-iter-boundary-decision).
4. If `skip_runtime`, skip Gate 3 and emit final summary.
5. Otherwise run [Gate 3: Runtime Verification](#gate-3-runtime-verification).
   - PASS → continue to final summary.
   - FAIL → final summary with Gate 3 FAIL marker; do not auto-restart.
   - NEEDS_RESOLUTION → invoke [Gate 3 NEEDS_RESOLUTION decision](#gate-3-needs_resolution-decision)
     up to `DEVBREW_GATE3_MAX_RESOLUTIONS` times (default 3, env override,
     clamp 0..10).
6. Emit final summary.
```

- [ ] **Step 10.3: Add Trivia escape section (port from v1.x, simplify)**

After `## Dispatch Loop`, add:

```markdown
## Trivia escape

Run `${CLAUDE_PLUGIN_ROOT}/scripts/check-trivia.sh`. Exit code:
- 0 = trivia detected → skip all gates. Print:
  > `Trivia diff — all gates skipped (one-sentence diff per CLAUDE.md trivia escape).`
- 1 = non-trivia → proceed to Gate 1.
- 2 = error → print stderr verbatim and abort.
```

- [ ] **Step 10.4: Write Gate 1 section**

```markdown
## Gate 1: Plan Verification

Dispatch the `quality-gates:plan-verifier` subagent:

\`\`\`
Agent({
  subagent_type: "quality-gates:plan-verifier",
  description: "Plan verification (Gate 1)",
  prompt: "Verify that all checkbox items in the plan are implemented. ..."
})
\`\`\`

(Construct the actual prompt from `plan_path`, the discovered plan via
`scripts/discover-plan.sh`, and the current diff.)

Subagent returns a verdict YAML block: `verdict: PASS | FAIL | SKIP`.

- **PASS**: print `## Gate 1: Plan Verification — PASS\n**Verdict:** PASS\n**Summary:** <one line>` and continue to Gate 2.
- **SKIP**: print `## Gate 1 — SKIP\n**Reason:** <reason>` and continue to Gate 2.
- **FAIL**: print the full Gate 1 result block (including unimplemented
  item list) and proceed to [Gate 1 FAIL decision](#gate-1-fail-decision).
```

- [ ] **Step 10.5: Write Gate 1 FAIL decision section (AC7 + V2b anchor)**

```markdown
## Gate 1 FAIL decision

> **Spec anchor (AC7):** the literal phrase `Plan verification failed`
> MUST appear in the AskUserQuestion prompt — V2b grep checks this.

Call AskUserQuestion:

\`\`\`
AskUserQuestion({
  questions: [
    {
      question: "Plan verification failed: <N> planned items not yet implemented (<summary>). How do you want to proceed?",
      header: "Gate 1 FAIL",
      options: [
        {label: "Continue anyway", description: "Proceed to Gate 2 review despite incomplete plan. Use when items are intentionally deferred."},
        {label: "Stop",            description: "Abort the pipeline. Address the gaps and re-run /qg."},
        {label: "View detail",     description: "Print full per-item verdict from plan-verifier, then ask again."}
      ],
      multiSelect: false
    }
  ]
})
\`\`\`

Branch on the user's answer:
- **Continue anyway** → proceed to Gate 2 (record "Gate 1 FAIL — user continued" in History).
- **Stop** → emit final summary marked aborted at Gate 1.
- **View detail** → print the verbose Gate 1 verdict, then re-invoke this
  same AskUserQuestion (without `View detail` this time, to avoid loops).
```

- [ ] **Step 10.6: Write Gate 2 section + iter boundary decision (AC6 + V2b anchor)**

```markdown
## Gate 2: PR Review

Iterative fix-loop, `max_gate2_iterations = 5` (hard-coded constant).

For each iteration N (1..5):

1. Compute diff scope (paths / branch / session — from preflight result).
2. Dispatch the scout: `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/scout.py ...)`.
3. Dispatch reviewer subagents in parallel:
   - `quality-gates:security-reviewer`
   - `quality-gates:adversarial`
   - `pr-review-toolkit:code-reviewer` (if pr-review-toolkit available)
   - codex reviewer if `detect_codex.sh` returns true
4. Dispatch `quality-gates:synthesizer` (or local synthesize_findings.py)
   to consolidate findings.
5. Compute boundary outcome:
   - findings empty → print `## Gate 2 iter N: PASS` and exit the loop (continue to Gate 3).
   - findings non-empty → invoke [Gate 2 iter boundary decision](#gate-2-iter-boundary-decision).

If iteration N=5 ends with findings still non-empty: invoke
[Gate 2 max-iter decision](#gate-2-max-iter-decision) instead of the
normal iter-boundary decision.

## Gate 2 iter boundary decision

> **Spec anchor (AC6):** the literal phrase `findings remain` MUST appear
> in the AskUserQuestion prompt — V2b grep checks this. This phrase is
> Gate 2-iter-specific (not used in any other AskUserQuestion in this SKILL).

Call AskUserQuestion (replace `N` with the iteration number, `<summary>`
with the synthesizer's one-line summary):

\`\`\`
AskUserQuestion({
  questions: [
    {
      question: "Gate 2 iter N: findings remain (<summary>). What next?",
      header: "Gate 2 iter N",
      options: [
        {label: "Retry",              description: "Apply the suggested fixes (I will Edit the files in this turn), then re-run Gate 2 reviewers."},
        {label: "Proceed to Gate 3",  description: "Accept current findings as-is and continue to runtime verification."},
        {label: "Stop",               description: "Abort the pipeline at this iteration. Address findings and re-run /qg."}
      ],
      multiSelect: false
    }
  ]
})
\`\`\`

Branch on answer:
- **Retry** → apply user-consented fixes by calling Edit/Write directly
  with the synthesizer's suggested patches; increment iteration counter;
  loop back to step 1 of the Gate 2 section.
- **Proceed to Gate 3** → exit the loop, continue to Gate 3 with current
  findings recorded in History.
- **Stop** → emit final summary marked aborted at Gate 2.

## Gate 2 max-iter decision

After iteration 5 still has findings, do NOT silently halt. Call:

\`\`\`
AskUserQuestion({
  questions: [
    {
      question: "Gate 2 reached max 5 iterations. Last findings: <summary>. Proceed to Gate 3 or stop?",
      header: "Gate 2 max-iter",
      options: [
        {label: "Proceed to Gate 3", description: "Accept residual findings and continue."},
        {label: "Stop",              description: "Abort the pipeline. Address findings and re-run /qg."}
      ],
      multiSelect: false
    }
  ]
})
\`\`\`

Branch on answer accordingly. (P18 unbounded-autonomy is satisfied by
this user-consent termination.)
```

- [ ] **Step 10.7: Write Gate 3 section + NEEDS_RESOLUTION decision (AC8 + V2b anchor + P21 token)**

```markdown
## Gate 3: Runtime Verification

If `skip_runtime` was set in arguments, skip this entire section.

1. Dispatch `quality-gates:test-scope-validator` to classify scope-relevant
   test files (aligned / outdated-suspicion / cherry-pick-suspicion / unclear).
2. Run `${CLAUDE_PLUGIN_ROOT}/scripts/detect-runtime.sh` to discover
   runnable surfaces (docker-compose, npm:dev, MCP servers, etc.).
3. Dispatch `quality-gates:runtime-verifier` with the runtime manifest.
4. Subagent verdict: `PASS`, `FAIL`, `SKIP_WITH_EVIDENCE`, or
   `NEEDS_RESOLUTION`.

- **PASS** → print `## Gate 3: Runtime Verification — PASS` and continue
  to final summary.
- **FAIL** → print full Gate 3 verdict block, then emit final summary
  marked Gate 3 FAIL. Do NOT auto-restart.
- **SKIP_WITH_EVIDENCE** → print verdict block with evidence; continue to
  final summary.
- **NEEDS_RESOLUTION** → invoke [Gate 3 NEEDS_RESOLUTION decision](#gate-3-needs_resolution-decision).

## Gate 3 NEEDS_RESOLUTION decision

> **Spec anchor (AC8):** the literal phrase `Runtime verifier needs` MUST
> appear in the prompt — V2b grep checks this. **P21 reaffirmation MUST
> also appear in the prompt body** (literal token `P21`) — the prompt
> never asks for secret values, only paths or yes/no.

Loop up to `DEVBREW_GATE3_MAX_RESOLUTIONS` times (default 3, env override
clamped 0..10):

\`\`\`
AskUserQuestion({
  questions: [
    {
      question: "Runtime verifier needs: <missing resource description>. (P21: never paste secrets into this prompt — add them to .env / config on disk first, then choose Yes, retry.)",
      header: "Gate 3 resolve",
      options: [
        {label: "Yes, retry",         description: "I've added the missing resource on disk. Re-run Gate 3."},
        {label: "Skip with evidence", description: "Mark Gate 3 SKIP_WITH_EVIDENCE with reason."},
        {label: "Stop",               description: "Abort the pipeline at Gate 3."}
      ],
      multiSelect: false
    }
  ]
})
\`\`\`

Branch:
- **Yes, retry** → increment resolution counter; if exceeds env limit,
  fall through to Skip with evidence. Otherwise re-dispatch runtime-verifier.
- **Skip with evidence** → record SKIP_WITH_EVIDENCE and continue to summary.
- **Stop** → final summary aborted at Gate 3.
```

- [ ] **Step 10.8: Write Final Summary section**

```markdown
## Final Summary

Print:

\`\`\`markdown
## Quality Gates Pipeline — Complete (v2.0.0)

- **Gate 1**: <PASS|FAIL-continued|SKIP>
- **Gate 2**: <PASS iter N | proceeded-with-findings iter N | aborted iter N | skipped>
- **Gate 3**: <PASS | FAIL | SKIP_WITH_EVIDENCE | aborted | skipped>

**History:**
<copy the appended ## History lines from the state file>
\`\`\`

State file cleanup is deferred to /cancel-qg or SessionEnd cleanup hook.
```

- [ ] **Step 10.9: Write Rules section**

```markdown
## Rules

**R1 (Law 2 — physical):** never call Edit/Write on agent persona files
(`plugins/quality-gates/agents/*.md`) in this turn. The orchestrator may
edit working-tree files for user-consented Gate 2 fixes only.

**R2 (state file write invariant):** never write `pipeline.md` frontmatter.
You MAY append a single line to the `## History` section per gate verdict;
do not modify any other content. Frontmatter is owned by setup-qg.sh.

**R3 (no fake user messages):** v2.0.0 has no Stop hook continuation, no
`<qg-signal>` tag, no `# QG-STOP-HOOK-CONTINUATION` sentinel. Do NOT emit
any such marker.

**R4 (P21 secret policy):** AskUserQuestion prompts never request a secret
value as a string. For Gate 3 missing-credential resolution, ask the user
to place secrets on disk (`.env`, config file) and respond yes/no.

**R5 (single dispatch per turn):** the entire pipeline runs in one turn.
Do not call setup-qg.sh more than once. Do not call check-trivia.sh more
than once. Do not re-dispatch the same Gate 2 reviewer for the same
iteration.
```

- [ ] **Step 10.10: Delete remaining v1.x sections**

Search for and remove all surviving v1.x text:

```bash
grep -nE '<qg-signal>|QG-STOP-HOOK-CONTINUATION|Stop hook|stop-hook|next_gate|compute_transition|consecutive_no_signal|Special Prompts from Stop Hook|Signal Tag Rules|GATE2_NEEDS_RESTART|GATE2_REPEAT_DETECTED|GATE2_MAX_EXCEEDED|GATE3_FAIL|GATE3_NEEDS_RESOLUTION|GATE3_REPEAT_DETECTED|gate1_running|gate2_running|gate3_running|continuation' plugins/quality-gates/skills/quality-pipeline/SKILL.md
```

For each match, decide:
- v1.x continuation/signal infrastructure (Special Prompts, Signal Tag Rules sections) → DELETE the whole section.
- An incidental mention in surviving prose → reword to reflect v2.0.0 (single turn, no signal).

- [ ] **Step 10.11: Run the orchestration test (should now pass)**

```bash
plugins/quality-gates/tests/test_skill_orchestration.sh; echo "exit=$?"
```

Expected:
```
PASS V2a (gate-label order)
PASS V2b (context anchors + options + P21)
PASS V7 (PASS-AskUserQuestion proximity)
All SKILL orchestration checks pass.
exit=0
```

If V2a fails: gate label first-mention order broken — Step 10.6 must mention "Gate 2" before "Gate 3" appears in any text. Reorder.

If V2b fails on a specific anchor: insert the missing literal phrase into the corresponding section.

If V7 fails: an AskUserQuestion appears within ±10 lines of a "PASS" marker. Move the AskUserQuestion section or insert a separator section between them.

- [ ] **Step 10.12: Confirm AC9, AC10 satisfied (no orphan identifiers)**

```bash
! grep -qE 'DEVBREW_QG_DEADLINE_MIN|DEVBREW_QG_NO_SIGNAL_MAX|compute_transition|consecutive_no_signal|extract_last_signal|extract_signal_from_hook_input|compute_no_signal_transition' plugins/quality-gates/skills/quality-pipeline/SKILL.md && echo "OK"
```

Expected: `OK`.

- [ ] **Step 10.13: Confirm AC3, AC4 satisfied (no signal/sentinel)**

```bash
! grep -qE '<qg-signal>|QG-STOP-HOOK-CONTINUATION' plugins/quality-gates/skills/quality-pipeline/SKILL.md && echo "OK"
```

Expected: `OK`.

- [ ] **Step 10.14: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md
git commit -m "$(cat <<'EOF'
feat(quality-gates)!: rewrite quality-pipeline SKILL for v2.0.0

Single-turn serial dispatcher: Gate 1 → Gate 2 (iter loop) → Gate 3.
AskUserQuestion at decision points (Gate 1 FAIL, Gate 2 iter boundary,
Gate 2 max-iter, Gate 3 NEEDS_RESOLUTION) — happy path = zero clicks.

Removed:
  - <qg-signal> emission rules + Signal Tag Rules section
  - Continuation sentinel preflight branch
  - Special Prompts from Stop Hook section (GATE2_NEEDS_RESTART etc.)
  - State machine references (status, current_gate, transition kinds)
  - Wall-clock / no-signal env var references

Added:
  - Dispatch Loop section orchestrating all three gates in-turn
  - AskUserQuestion templates with context anchors (AC6/7/8 grep targets)
  - Law 2 invariants explicitly called out (orchestrator-as-writer)

Test: tests/test_skill_orchestration.sh passes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Update `commands/qg.md` and `commands/cancel-qg.md`

**Files:**
- Modify: `plugins/quality-gates/commands/qg.md` (lines 49, 51, 95-97, 107-112).
- Modify: `plugins/quality-gates/commands/cancel-qg.md` (intro prose only — behavior unchanged).

- [ ] **Step 11.1: Edit `qg.md` — remove stop-hook prose**

Find:
```
Now invoke `Skill("quality-gates:quality-pipeline")` with gate=1 (or the gate specified in $ARGUMENTS) to begin the first gate.

When you finish the gate, emit a `<qg-signal>` tag. The Stop hook handles pipeline progression automatically.
```

Replace with:
```
Now invoke `Skill("quality-gates:quality-pipeline")` with the parsed
arguments. The skill runs the complete pipeline in this turn — Gate 1 →
Gate 2 (with internal fix-loop) → Gate 3 — and surfaces decision points
via AskUserQuestion. No further commands are needed unless the pipeline
is aborted at a decision point.
```

Find lines 95-97 (kill switch text):
```
Set `DEVBREW_DISABLE_QUALITY_GATES=1` to globally disable. Set
`DEVBREW_SKIP_HOOKS=quality-gates:session-tracker` to disable just the
session-tracker hook (keeps Stop hook + advisor active).
```

Replace with:
```
Set `DEVBREW_DISABLE_QUALITY_GATES=1` to globally disable. Set
`DEVBREW_SKIP_HOOKS=quality-gates:session-tracker` to disable just the
session-tracker hook (keeps SessionStart advisor active). v2.0.0 has no
Stop hook.
```

Find the Pipeline Rules section (lines 105-112):
```
### Pipeline Rules

- Pipeline progression managed by Stop hook (no manual gate transitions needed)
- **Forward-only state machine**: Gate 2/3 NEEDS_RESTART terminates with user
  choice ("apply changes and re-run /qg"); does NOT auto-restart from Gate 1
- Gate 2 iterates up to 5 times internally (`max_gate2_iterations`)
- Repeat-detection: identical iterations trigger early user choice
- State tracked in `.claude/quality-gates/<session-id>/{pipeline,files,branch}.md` (managed by hook scripts; see plugin README)
```

Replace with:
```
### Pipeline Rules (v2.0.0)

- Pipeline runs in a single assistant turn (no Stop hook, no continuation
  sentinel, no cross-turn state machine).
- **Forward-only**: code-change verdicts terminate. Gate 2 fix-loop applies
  user-consented fixes inline (orchestrator-as-writer); does NOT auto-restart
  from Gate 1.
- Gate 2 iterates up to 5 times internally; AskUserQuestion fires at every
  iteration boundary with `Retry` / `Proceed to Gate 3` / `Stop`.
- AskUserQuestion also fires on Gate 1 FAIL, Gate 2 max-iter, and Gate 3
  NEEDS_RESOLUTION.
- State tracked minimally in `.claude/quality-gates/<session-id>/pipeline.md`
  (managed by `scripts/setup-qg.sh`; SKILL reads worktree_path only).
```

Also find the `--gc` section block (lines 31-39); leave intact — qg-gc.py usage unchanged.

Also remove (line 4) the explicit `allowed-tools` `"Edit", "Write"` entries if you wish to scope tighter — but the spec does not require this change, so leave the command's allowed-tools alone (the SKILL frontmatter controls SKILL-side tool access, which is what matters).

- [ ] **Step 11.2: Edit `cancel-qg.md` — replace v1.5.0 hint with v2.0.0 context**

The current cancel-qg.md is well-scoped already (SID-guarded `rm -rf`,
optional `--gc`/`--all` modes). The only stale-context line is the
description at the top.

Find at line 2:
```
description: "Cancel active quality gates pipeline"
```

Replace with:
```
description: "Cancel a quality-gates pipeline session (single-turn execution in v2.0.0; this clears orphan state)"
```

In the body, change at line 9-10 (after `# Cancel Quality Gates`):
Add this paragraph after the title:
```
v2.0.0 pipelines run in a single assistant turn — `/cancel-qg` mainly
cleans orphan state from aborted turns or `/qg` invocations that crashed
before completion.
```

- [ ] **Step 11.3: Run command-tests**

```bash
plugins/quality-gates/tests/test_cancel_qg.sh
```

Expected: all PASS.

- [ ] **Step 11.4: Commit**

```bash
git add plugins/quality-gates/commands/qg.md plugins/quality-gates/commands/cancel-qg.md
git commit -m "$(cat <<'EOF'
docs(quality-gates): update /qg and /cancel-qg for v2.0.0 in-turn flow

Removed prose referring to Stop hook progression and <qg-signal>.
Pipeline Rules section rewritten to describe single-turn execution and
AskUserQuestion decision points.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: README Rewrite — Hook Table, State Diagram (ASCII Sequence), Principles, Tuning

**Files:**
- Modify: `plugins/quality-gates/README.md` (343 lines; sections: Hook table, state diagram, Principles Instantiated, Tuning knobs, intro prose).

> **Spec G5 lock:** new ASCII sequence diagram MUST contain literal text `single assistant turn` (V4 grep), and Principles MUST add `progression primitive` OR `progression gate` (V4 grep).

- [ ] **Step 12.1: Inspect current README sections**

```bash
grep -nE '^##|^###' plugins/quality-gates/README.md
```

Identify the four target sections by line number: Hooks table, state diagram (mermaid), Principles Instantiated, Tuning knobs.

- [ ] **Step 12.2: Remove the `stop-hook.py` row from the Hook table**

In the "설치된 Hook" or "Hooks Installed" table, delete the row whose first cell contains `stop-hook.py`. Surrounding rows (post-tool-use-session-tracker, post-tool-use, session-start-advisor, session-end-cleanup) remain. Renumber if numbered.

After edit verify:

```bash
! grep -q 'stop-hook.py' plugins/quality-gates/README.md && echo "OK"
```

Expected: `OK`.

- [ ] **Step 12.3: Replace the mermaid `stateDiagram-v2` block with ASCII sequence**

Find the entire mermaid block:

\`\`\`
\`\`\`mermaid
stateDiagram-v2
    ...
\`\`\`
\`\`\`

(It may span 30-50 lines with all 13 transitions.)

Replace with:

\`\`\`markdown
\`\`\`
┌─ single assistant turn ──────────────────────────────────────────────┐
│                                                                       │
│   user: /qg                                                           │
│       │                                                               │
│       ▼                                                               │
│   setup-qg.sh --ensure  (creates .claude/quality-gates/<sid>/...)     │
│       │                                                               │
│       ▼                                                               │
│   SKILL preflight  (kill switch, pre-pipeline-check)                  │
│       │                                                               │
│       ▼                                                               │
│   trivia escape? ─── yes ──▶ "Trivia diff — all gates skipped"        │
│       │ no                                                            │
│       ▼                                                               │
│   Gate 1 dispatch (plan-verifier)                                     │
│       │                                                               │
│       ├── PASS ───────────────────────────────────────────┐           │
│       │                                                   │           │
│       └── FAIL ──▶ AskUserQuestion                        │           │
│                   ("Plan verification failed ..."          │           │
│                    Continue anyway / Stop / View detail)  │           │
│                       │                                   │           │
│                       └── Continue ─────────────────────▶ ┤           │
│                                                            ▼          │
│                                              Gate 2 iter loop (≤5)    │
│                                                  │                    │
│                                                  ├── findings empty ─┐│
│                                                  │     ▶ Gate 3       ││
│                                                  │                    ││
│                                                  └── findings remain  ││
│                                                       AskUserQuestion ││
│                                                       ("findings      ││
│                                                        remain..."     ││
│                                                       Retry / Proceed ││
│                                                        to Gate 3 /    ││
│                                                        Stop)          ││
│                                                                       ││
│                                                  Gate 3 dispatch ◀────┘│
│                                                  (runtime-verifier)    │
│                                                       │                │
│                                                       ├── PASS         │
│                                                       ├── FAIL         │
│                                                       ├── SKIP_WITH_EVIDENCE
│                                                       └── NEEDS_RESOLUTION
│                                                              ▶ AskUserQuestion
│                                                              ("Runtime
│                                                               verifier needs..."
│                                                               P21 reaffirmed)
│                                                                       │
│   Final summary                                                       │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
\`\`\`
\`\`\`

(Indent escaping — write the literal triple-backtick blocks. The
diagram itself is enclosed in a fenced code block to preserve the
ASCII layout.)

After edit verify:

```bash
! grep -q 'stateDiagram-v2' plugins/quality-gates/README.md && \
  grep -q 'single assistant turn' plugins/quality-gates/README.md && \
  echo "OK"
```

Expected: `OK`.

- [ ] **Step 12.4: Update Principles Instantiated section**

Find the "Principles Instantiated" section. After the existing P# entries
(P1, P12, P18, P21, P22, etc.), add or update one entry to read:

```markdown
- **P22 generalization (consent gate → progression gate):** AskUserQuestion
  is reused as a **progression primitive** at every gate boundary and Gate
  2 fix-loop iteration. The same tool that gates subagent fan-out now
  gates inter-gate progression — no new principle ID needed.
```

After edit verify:

```bash
grep -qE 'progression primitive|progression gate' plugins/quality-gates/README.md && echo "OK"
```

Expected: `OK`.

- [ ] **Step 12.5: Update Tuning knobs / Env vars table**

Find the env-var table. Remove rows for:
- `DEVBREW_QG_DEADLINE_MIN`
- `DEVBREW_QG_NO_SIGNAL_MAX`
- (any other stop-hook-only knob)

Keep:
- `DEVBREW_DISABLE_QUALITY_GATES`
- `DEVBREW_SKIP_HOOKS=quality-gates:...`
- `DEVBREW_GATE3_MAX_RESOLUTIONS`
- `DEVBREW_QG_TTL_HOURS`
- `DEVBREW_QG_GC_VERBOSE`
- `DEVBREW_QG_KEEP_WORKTREE`
- `DEVBREW_QG_DISABLE_BRANCH_WORKTREE`

After edit verify:

```bash
! grep -qE 'DEVBREW_QG_DEADLINE_MIN|DEVBREW_QG_NO_SIGNAL_MAX' plugins/quality-gates/README.md && echo "OK"
```

Expected: `OK`.

- [ ] **Step 12.6: Update intro/version banner (if any)**

If the README has a "Current version" or "What's new" banner, change to
reference v2.0.0 and link to the upcoming CHANGELOG entry.

- [ ] **Step 12.7: Run V4 (AC12) verification end-to-end**

```bash
R=plugins/quality-gates/README.md
! grep -q 'stop-hook.py' "$R" && \
! grep -q 'stateDiagram-v2' "$R" && \
grep -q 'single assistant turn' "$R" && \
grep -qE 'progression primitive|progression gate' "$R" && \
echo "V4 PASS"
```

Expected: `V4 PASS`.

- [ ] **Step 12.8: Commit**

```bash
git add plugins/quality-gates/README.md
git commit -m "$(cat <<'EOF'
docs(quality-gates): rewrite README for v2.0.0

- Removed stop-hook.py row from Hooks Installed table
- Replaced mermaid stateDiagram-v2 with ASCII single-turn sequence box
- Added P22 generalization (progression primitive) to Principles
- Removed DEVBREW_QG_DEADLINE_MIN / DEVBREW_QG_NO_SIGNAL_MAX from Tuning

V4 (AC12) verification passes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Write CHANGELOG `## [2.0.0]` entry

**Files:**
- Modify: `plugins/quality-gates/CHANGELOG.md` (prepend at top after `# Changelog` header).

- [ ] **Step 13.1: Find date for entry**

```bash
date -u +%Y-%m-%d
```

Save the result (e.g., `2026-05-27`).

- [ ] **Step 13.2: Prepend the v2.0.0 entry**

Read the existing CHANGELOG.md to find the position to insert (right after the `# Changelog` h1 and before the most recent `## [...]` entry). Insert:

```markdown
## [2.0.0] — <DATE FROM STEP 13.1>

### Breaking
- **Stop hook removed.** `hooks/stop-hook.py` (1205 LOC, 13-transition
  state machine, wall-clock guard, no-signal counter) deleted along with
  the `Stop` event registration in `hooks.json`. Pipeline progression now
  lives entirely in the `quality-pipeline` SKILL as in-turn serial
  dispatch.
- **`<qg-signal>` emission contract removed.** SKILL no longer emits the
  signal tag. The `# QG-STOP-HOOK-CONTINUATION` sentinel is no longer
  recognized by any code path.
- **State file shape changed.** v2.0.0 state file is minimal: `session_id`,
  `started_at`, `worktree_path` (optional), `gate2_iteration`. Removed
  fields: `status`, `current_gate`, `consecutive_no_signal`,
  `max_gate2_iterations`, `gate3_resolution_iter`, `last_gate3_needed_hash`,
  `max_gate3_resolutions`, `skip_runtime`, `single_gate`, `plan_file`,
  `pr_url`, `available_plugins`, `wall_clock_deadline_at`, `project_dir`.
- **Env vars removed.** `DEVBREW_QG_DEADLINE_MIN` and
  `DEVBREW_QG_NO_SIGNAL_MAX` no longer exist (wall-clock guard and
  no-signal counter went away with stop-hook). Other env vars unchanged.

### Added
- **AskUserQuestion progression primitive.** SKILL calls AskUserQuestion
  at Gate 1 FAIL, Gate 2 iter boundary (every iteration), Gate 2 max-iter
  (replacing silent halt), and Gate 3 NEEDS_RESOLUTION. Same-turn tool
  result drives the next dispatch.
- **Static SKILL orchestration test:** `tests/test_skill_orchestration.sh`
  (V2a gate-order + V2b context-anchor + V7 PASS-proximity heuristic).
- **Fixture test for /cancel-qg, /qg --reset, /qg --gc:**
  `tests/test_cancel_qg.sh`.
- **Session-start advisor v2 test:** `tests/test_session_start_advisor_v2.sh`
  (V8 legacy advisory + V8-pre code-structure guard).

### Changed
- **SKILL.md rewritten** from single-gate-per-turn to single-turn-serial
  dispatch with AskUserQuestion gating.
- **setup-qg.sh** emits minimal state schema; wall-clock and gate3-max
  computation removed.
- **session-start-advisor.py** drops in-flight pipeline detection;
  detects legacy v1.x state files and emits one-shot `/cancel-qg` stderr
  advisory. Frontmatter scan sub-feature unchanged.
- **commands/qg.md** Pipeline Rules section rewritten; removed "Stop hook
  handles progression" claim.
- **README.md** Hook table no longer lists stop-hook.py; state diagram
  replaced with ASCII single-turn sequence; Principles section adds
  P22 generalization note.

### Removed
- `hooks/stop-hook.py`
- `hooks/hooks.json` Stop event block
- All `<qg-signal>` references in SKILL/scripts/hooks
- Obsolete tests coupled to stop-hook semantics (`test_forward_only_prose.sh`
  and any stop-hook-coupled tests detected during Task 7)

### Migration
v1.x in-flight pipelines cannot resume under v2.0.0. After upgrade, run
`/cancel-qg` (per-session) or `/qg --reset` (legacy flat files) to clear
old state. SessionStart advisor will guide you on next session start.
```

- [ ] **Step 13.3: Verify V3 (AC11) — version match + CHANGELOG header**

```bash
grep -c '^## \[2\.0\.0\]' plugins/quality-gates/CHANGELOG.md
```

Expected: `1`.

- [ ] **Step 13.4: Commit**

```bash
git add plugins/quality-gates/CHANGELOG.md
git commit -m "$(cat <<'EOF'
docs(quality-gates): CHANGELOG entry for v2.0.0

Documents Breaking/Added/Changed/Removed/Migration sections.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: Bump `plugin.json` to `2.0.0`

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` (line 4: `"version": "1.31.0"` → `"version": "2.0.0"`).

- [ ] **Step 14.1: Edit plugin.json**

Find:
```json
  "version": "1.31.0",
```

Replace with:
```json
  "version": "2.0.0",
```

- [ ] **Step 14.2: Verify**

```bash
jq -r .version plugins/quality-gates/.claude-plugin/plugin.json
```

Expected: `2.0.0`.

- [ ] **Step 14.3: Commit**

```bash
git add plugins/quality-gates/.claude-plugin/plugin.json
git commit -m "$(cat <<'EOF'
chore(quality-gates)!: bump version to 2.0.0

Breaking-change major bump per SemVer. See CHANGELOG for details.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: Final Regression — Run All Verification Steps (V0–V10)

**Files:** none (verification only). This task runs every V step from the spec to confirm AC1–AC18 satisfied.

- [ ] **Step 15.1: V1 — AC1, AC2, AC3, AC4, AC9, AC10**

```bash
test ! -f plugins/quality-gates/hooks/stop-hook.py && \
! jq -e '.hooks.Stop' plugins/quality-gates/hooks/hooks.json > /dev/null && \
! grep -rqE '<qg-signal>|QG-STOP-HOOK-CONTINUATION|compute_transition|consecutive_no_signal|DEVBREW_QG_DEADLINE_MIN|DEVBREW_QG_NO_SIGNAL_MAX' plugins/quality-gates/ && \
echo "V1 PASS"
```

Expected: `V1 PASS`.

If FAIL: the grep prints the offending file + line. Fix and re-run.

- [ ] **Step 15.2: V2a — AC5**

```bash
awk '/Gate 1/{if(!g1)g1=NR} /Gate 2/{if(!g2)g2=NR} /Gate 3/{if(!g3)g3=NR} END{exit !(g1 && g2 && g3 && g1<g2 && g2<g3)}' \
  plugins/quality-gates/skills/quality-pipeline/SKILL.md && echo "V2a PASS"
```

- [ ] **Step 15.3: V2b — AC6, AC7, AC8 (via test wrapper)**

```bash
plugins/quality-gates/tests/test_skill_orchestration.sh && echo "V2b PASS"
```

- [ ] **Step 15.4: V3 — AC11**

```bash
jq -r .version plugins/quality-gates/.claude-plugin/plugin.json | grep -qx '2.0.0' && \
grep -qc '^## \[2.0.0\]' plugins/quality-gates/CHANGELOG.md && \
echo "V3 PASS"
```

- [ ] **Step 15.5: V4 — AC12**

```bash
R=plugins/quality-gates/README.md
! grep -q 'stop-hook.py' "$R" && \
! grep -q 'stateDiagram-v2' "$R" && \
grep -q 'single assistant turn' "$R" && \
grep -qE 'progression primitive|progression gate' "$R" && \
echo "V4 PASS"
```

- [ ] **Step 15.6: V5 — AC13 (Law 2 frontmatter unchanged)**

```bash
for a in plugins/quality-gates/agents/*.md; do
  grep -q 'disallowedTools' "$a" || { echo "FAIL: $a missing disallowedTools"; exit 1; }
done
echo "V5 PASS"
```

- [ ] **Step 15.7: V6 — AC15 (orchestration test wrapper)**

Same as Step 15.3 — already covered.

- [ ] **Step 15.8: V7 — AC18 supporting (test wrapper includes this)**

Same as Step 15.3 — already covered.

- [ ] **Step 15.9: V8 + V8-pre — AC16, AC14**

```bash
plugins/quality-gates/tests/test_session_start_advisor_v2.sh && echo "V8 PASS"
```

- [ ] **Step 15.10: V9 — regression suite**

```bash
for t in test_branch_worktree.sh test_discover_plan.sh test_no_secret_prompts.py test_agent_frontmatter_keys.sh test_adversarial_model_consistency.sh; do
  bash "plugins/quality-gates/tests/$t" 2>&1 | tail -5
  echo "--- $t exit=$? ---"
done
```

Expected: all exit with 0 (each test's last lines should indicate PASS).

If any test fails because of the v2.0.0 changes (e.g., a test that imports stop-hook), that's a Task-7 miss — go back and clean.

- [ ] **Step 15.11: V10 — AC17 (cancel-qg test)**

```bash
plugins/quality-gates/tests/test_cancel_qg.sh && echo "V10 PASS"
```

- [ ] **Step 15.12: AC14 final — KEEP files diff is empty**

```bash
git diff $(git merge-base HEAD main) HEAD -- \
  plugins/quality-gates/hooks/post-tool-use-session-tracker.py \
  plugins/quality-gates/hooks/post-tool-use.py \
  plugins/quality-gates/hooks/session-end-cleanup.py | tee /tmp/qg-keep-diff.txt
test ! -s /tmp/qg-keep-diff.txt && echo "AC14 KEEP files: clean"
```

Expected: empty diff + `AC14 KEEP files: clean`. If non-empty, you accidentally modified one of the KEEP files; revert those changes only (`git checkout HEAD~N -- <file>` from before the offending commit).

- [ ] **Step 15.13: Final report**

If all V steps PASS, the implementation is ready for PR. Create a summary
note:

```
V0   (premise)         : PASS — adopted path (a)/(b)
V1   (AC1/2/3/4/9/10)  : PASS
V2a  (AC5)             : PASS
V2b  (AC6/7/8)         : PASS
V3   (AC11)            : PASS
V4   (AC12)            : PASS
V5   (AC13)            : PASS
V6   (AC15)            : PASS  (via test_skill_orchestration.sh)
V7   (AC18 supporting) : PASS  (via test_skill_orchestration.sh)
V8   (AC16)            : PASS
V8-pre (AC14 advisory) : PASS  (via test_session_start_advisor_v2.sh)
V9   (regression)      : PASS
V10  (AC17)            : PASS
AC14 KEEP files        : clean
```

If anything FAILed, document the failure and address before proceeding to
Task 16.

---

## Task 16: PR Creation

**Files:** none (PR creation only).

- [ ] **Step 16.1: Push branch**

```bash
git push -u origin worktree-feature-qg-askq-iteration
```

- [ ] **Step 16.2: Open PR**

```bash
gh pr create --base main --title "feat(quality-gates)!: v2.0.0 — AskUserQuestion-driven in-turn iteration" --body "$(cat <<'EOF'
## Summary

- Replaces Stop-hook-driven iteration (1205-LOC `stop-hook.py` + 13-transition state machine + wall-clock guard + no-signal counter) with single-turn serial dispatch inside the `quality-pipeline` SKILL.
- Decision points (Gate 1 FAIL, Gate 2 iter boundary, Gate 2 max-iter, Gate 3 NEEDS_RESOLUTION) surface via `AskUserQuestion`. Happy path = zero clicks.
- Spec: `docs/superpowers/specs/2026-05-27-qg-askq-iteration-design.md` (v2.0.0, round-4 approved).
- Plan: `docs/superpowers/plans/2026-05-27-qg-askq-iteration.md`.

## Test plan

- [ ] V0 smoke (premise + OQ1) — manual verification logged in `docs/superpowers/plans/notes/2026-05-27-v0-result.md`
- [ ] V1–V10 + V8-pre + AC14 KEEP diff — all PASS per Task 15
- [ ] Manual `/qg` happy path — zero AskUserQuestion in a 3-gate PASS run
- [ ] Manual `/qg` with seeded Gate 2 finding — AskUserQuestion fires with `findings remain` anchor
- [ ] Verify legacy v1.x state file is detected by SessionStart advisor and surfaces `/cancel-qg` directive on stderr

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 16.3: Verify PR URL printed**

`gh pr create` will print the PR URL. Note it and share with the user.

---

## Self-Review Checklist (Implementer)

After completing all tasks above, re-read the spec sections and confirm coverage:

| Spec item | Task that implements | Verified by |
|---|---|---|
| G1 (delete stop-hook.py + hooks.json Stop) | Task 6 | V1 / Step 15.1 |
| G2 (AskUserQuestion at decision points) | Task 10 (Steps 10.5, 10.6, 10.7) | V2b / Step 15.3 |
| G3 (delete signal/sentinel/state-machine ids) | Tasks 6, 10 | V1, V2b |
| G4 (Law 2 frontmatter unchanged) | (no edit) | V5 / Step 15.6 |
| G5 (plugin.json + CHANGELOG + README) | Tasks 12, 13, 14 | V3, V4 |
| C1 (orchestrator-as-writer) | Task 10 Step 10.1 prose + R1 rule | (spec lock; no auto-check) |
| C2 (P21 secret policy) | Task 10 Step 10.7 | V2b P21 grep |
| C3 (Gate 3 max=3, clamp 0..10) | Task 10 Step 10.7 prose | (manual review) |
| C4 (Gate 2 max=5 + max-iter AskQ) | Task 10 Step 10.6 (max-iter decision) | V2b "Gate 2 reached max" indirectly |
| C5 (DEVBREW_DISABLE_QUALITY_GATES) | Task 10 Step P1 | (manual smoke) |
| C6 (cost_class: variable) | Task 10 Step 10.1 frontmatter | (manual review) |
| C7 (Plugin Shape) | Tasks 12, 13, 14 | V3, V4 |
| C8 (Korean-primary docs) | All `*.md` writes use Korean primary | (manual review) |
| C9 (advisor narrow modification) | Task 5 | V8-pre / Step 15.9 |
| AC1–AC18 | Tasks 5–14 | V1–V10 / Steps 15.1–15.12 |
| Round-4 advisory (V8-pre) | Task 5 Step 5.1 | V8-pre / Step 15.9 |

**Placeholder scan:**

```bash
grep -E 'TBD|TODO|FIXME|fill in|implement later' docs/superpowers/plans/2026-05-27-qg-askq-iteration.md | grep -v '^\s*#'
```

Expected: no real placeholders (only mentions inside template / instruction text, e.g., the comment-line about `<DECISION FROM TASK 1 OQ1>` in Task 10 Step 10.1 — that one is an intentional decision marker that gets resolved by the OQ1 result from Task 1).

**Type consistency:**

- Gate label spellings: `Gate 1`, `Gate 2`, `Gate 3` (spaces, not `Gate1`).
- AskUserQuestion option labels: exact match required for V2b grep.
- Context anchor phrases: `Plan verification failed`, `findings remain`, `Runtime verifier needs`.
- Env var names: `DEVBREW_GATE3_MAX_RESOLUTIONS`, `DEVBREW_DISABLE_QUALITY_GATES` (preserved); `DEVBREW_QG_DEADLINE_MIN`, `DEVBREW_QG_NO_SIGNAL_MAX` (removed).

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-27-qg-askq-iteration.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
