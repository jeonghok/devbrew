# spec-distill v0.1.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement v0.1.0 of `spec-distill` plugin — interview→spec phase replacement for superpowers/brainstorming, embodying devbrew Laws 1+2 with Writer/Reviewer physical separation, 4-block Korean Socratic interview, and loop-aware Phase 0–5 flow.

**Architecture:** devbrew plugin with `/interview` command (entry + trivia escape), 3 skills (`conducting-interview` / `drafting-spec` / `reviewing-spec`), 2 sub-agents (`breadth-keeper` / `spec-reviewer` with `disallowedTools` frontmatter physically blocking Write/Edit), 2 hooks (UserPromptSubmit `interview-trigger.sh` / SessionStart `session-anchor.sh`, both with `DEVBREW_SKIP_HOOKS` kill switch), 1 spec template. Per-session state persists in `.claude/spec-distill/<session-id>/state.local.md` (markdown frontmatter + transcript body). Output `spec.md` goes to `docs/superpowers/specs/` for superpowers `writing-plans` drop-in compatibility.

**Tech Stack:** Markdown (frontmatter + body), Bash (hooks with kill switch), YAML frontmatter, jq/grep for structural verification, Git for spec commit, devbrew Plugin Shape conventions (referenced from `plugins/quality-gates/` and `plugins/project-init/`).

**Spec reference:** `docs/superpowers/specs/2026-05-09-spec-distill-design.md`

---

## Pre-Implementation Checks

Before starting Task 1, verify environment:

- [ ] **Working directory is devbrew repo root.** Run: `pwd && test -d plugins/quality-gates && echo OK` — expected: path ending in `devbrew` and `OK`.
- [ ] **On a feature branch, NOT main.** If on `main`, run:

```bash
git checkout -b feature/spec-distill-v0.1.0
```

- [ ] **Spec exists.** Run: `test -f docs/superpowers/specs/2026-05-09-spec-distill-design.md && echo OK` — expected: `OK`.

---

## Task 1: Plugin scaffold + marketplace registration

**Files:**
- Create: `plugins/spec-distill/.claude-plugin/plugin.json`
- Create: `plugins/spec-distill/README.md` (skeleton; full content in Task 11)
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Create plugin directory structure**

```bash
mkdir -p plugins/spec-distill/.claude-plugin
mkdir -p plugins/spec-distill/commands
mkdir -p plugins/spec-distill/skills/conducting-interview
mkdir -p plugins/spec-distill/skills/drafting-spec
mkdir -p plugins/spec-distill/skills/reviewing-spec
mkdir -p plugins/spec-distill/agents
mkdir -p plugins/spec-distill/hooks
mkdir -p plugins/spec-distill/templates
ls -la plugins/spec-distill/
```

Expected: 7 subdirectories (`.claude-plugin`, `commands`, `skills`, `agents`, `hooks`, `templates`) + `skills/` has 3 sub-skill dirs.

- [ ] **Step 2: Write `plugin.json`**

File: `plugins/spec-distill/.claude-plugin/plugin.json`

```json
{
  "name": "spec-distill",
  "description": "집요한 인터뷰로 모호함을 명확함으로 변환해 superpowers 호환 spec.md를 생성. devbrew Laws 1+2 instantiation (Writer/Reviewer 물리적 분리, 4-block Korean Socratic interview).",
  "version": "0.1.0",
  "author": {
    "name": "jeonghokim"
  }
}
```

- [ ] **Step 3: Verify `plugin.json` valid + required fields**

```bash
jq -e '.name == "spec-distill" and .version == "0.1.0" and (.description | length > 0)' plugins/spec-distill/.claude-plugin/plugin.json
```

Expected: `true`

- [ ] **Step 4: Register plugin in `marketplace.json`**

Modify `.claude-plugin/marketplace.json` — append the new entry to the `plugins` array (after the `project-init` entry). Final `plugins` array:

```json
"plugins": [
    {
      "name": "quality-gates",
      "description": "3-gate quality verification pipeline: plan verification, iterative PR review, and runtime verification.",
      "source": "./plugins/quality-gates",
      "category": "development"
    },
    {
      "name": "project-init",
      "description": "Git workflow initialization: select branching strategy (GitHub Flow, Git Flow, Trunk-based), generate rules and auto-validate.",
      "source": "./plugins/project-init",
      "category": "development"
    },
    {
      "name": "spec-distill",
      "description": "집요한 인터뷰로 모호함을 명확함으로 변환해 superpowers 호환 spec.md를 생성하는 devbrew-native 플러그인. Drop-in 대체 of superpowers/brainstorming.",
      "source": "./plugins/spec-distill",
      "category": "development"
    }
]
```

- [ ] **Step 5: Verify `marketplace.json` valid + 3 plugins listed**

```bash
jq -e '.plugins | length == 3 and (map(.name) | contains(["spec-distill"]))' .claude-plugin/marketplace.json
```

Expected: `true`

- [ ] **Step 6: Write `README.md` skeleton**

File: `plugins/spec-distill/README.md`

```markdown
# spec-distill

> 집요한 인터뷰로 모호함을 명확함으로 변환해 superpowers 호환 `spec.md`를 생성하는 devbrew-native 플러그인 — interview → spec phase.

## What it does

`/interview <rough request>` 또는 `/interview` 호출 시 4-block Korean Socratic 인터뷰로 모호한 요청을 명확한 spec.md로 변환합니다. 산출물은 `docs/superpowers/specs/YYYY-MM-DD-<topic>-spec.md` (superpowers `writing-plans` input 호환). v0.1.0은 interview → spec phase까지 — plan 단계는 v0.2.0 또는 superpowers `writing-plans`로 위임.

## Quick start

```
/interview todo 앱 만들어줘
```

## Principles Instantiated

(Task 11에서 Laws/P/C/AP cite 추가 예정 — 이 skeleton은 Task 1에서 placeholder.)
```

- [ ] **Step 7: Commit**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/README.md .claude-plugin/marketplace.json
git commit -m "feat(spec-distill): scaffold plugin + register in marketplace (v0.1.0)"
```

---

## Task 2: Spec template (`spec-template.md`)

**Files:**
- Create: `plugins/spec-distill/templates/spec-template.md`

- [ ] **Step 1: Write template**

File: `plugins/spec-distill/templates/spec-template.md`

```markdown
---
name: <kebab-case-topic>
version: 1.0.0
created_at: YYYY-MM-DD
session_id: <uuid>
status: locked
next_phase: writing-plans
source: spec-distill v0.1.0
---

# <Topic title>

## Goal

(One sentence — testable outcome.)

## Context / Why

(Why now, what problem, who asked, what's at stake.)

## Goals

- **G1**: ...
- **G2**: ...

## Non-goals

- **NG1**: ...

## Constraints

- **C1**: ...

## Acceptance Criteria

- **AC1**: (testable, measurable)
- **AC2**: ...

## Files to Modify

```
(exact paths to create/modify, with one-line responsibility per file)
```

## Verification Plan

- **V1**: (manual or automated check, with exact command)
- **V2**: ...

## Rejected Alternatives

- **R1 — <name>**: <reason rejected>

## Open Questions

- **OQ1**: ... (TBD if not resolved by spec time)
- (Or "None" if all resolved)

## Concrete Next Action

다음 단계: `<next skill or command>`.
- Spec 경로: `<this file path>`
- Plan 산출물: `docs/superpowers/plans/<date>-<topic>.md`
- 명령: `<exact command to invoke next phase>`
```

- [ ] **Step 2: Verify template has all 11 sections**

```bash
grep -cE "^## (Goal$|Context|Goals$|Non-goals$|Constraints$|Acceptance Criteria$|Files to Modify$|Verification Plan$|Rejected Alternatives$|Open Questions$|Concrete Next Action$)" plugins/spec-distill/templates/spec-template.md
```

Expected: `11`

- [ ] **Step 3: Verify frontmatter has 7 required fields**

```bash
head -10 plugins/spec-distill/templates/spec-template.md | grep -cE "^(name|version|created_at|session_id|status|next_phase|source):"
```

Expected: `7`

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/templates/spec-template.md
git commit -m "feat(spec-distill): add spec template with 11 required sections + 7-field frontmatter"
```

---

## Task 3: `/interview` command + trivia escape rule (AC10)

**Files:**
- Create: `plugins/spec-distill/commands/interview.md`

- [ ] **Step 1: Write `interview.md` command**

File: `plugins/spec-distill/commands/interview.md`

```markdown
---
description: 4-block Korean Socratic 인터뷰로 모호한 요청을 spec.md로 변환. devbrew Law 1 instantiation.
argument-hint: "[rough request]"
---

# /interview

당신은 spec-distill 플러그인의 entry point입니다. 사용자가 `/interview`를 호출하면 다음 순서로 진행하십시오.

## Step 1: kill switch 존중

다음 환경변수가 set이면 즉시 종료 (no-op):

- `DEVBREW_DISABLE_SPEC_DISTILL=1` — 모든 spec-distill 동작 abort.

(`DEVBREW_SKIP_HOOKS` 는 hook 영역으로, command 자체에는 영향 없음.)

## Step 2: Trivia Escape Check (AP4 회피, AC10)

`$ARGUMENTS`가 다음 5 패턴 중 하나에 해당하는지 확인:

1. **Typo 1줄 수정** — 예: "fix typo on line 3", "오타 고쳐줘"
2. **주석-only diff** — 예: "add a comment explaining X"
3. **단일 파일 formatting** — 예: "reformat foo.py", "indentation 맞춰줘"
4. **단일 변수/함수 rename** — 예: "rename `foo` to `bar`"
5. **<10 토큰 + 명확한 단일 action 동사** — 예: "fix typo", "add semicolon", "remove blank line"

해당하면 다음 메시지를 출력하고 인터뷰를 시작하지 마십시오:

> ⚠ 이 요청은 trivia 패턴(<해당 패턴 이름>)으로 보입니다. 인터뷰 게이트를 우회해서 직접 처리할 수 있습니다.
> 그래도 인터뷰를 진행하시려면 명시적으로 "force interview" 또는 더 자세한 컨텍스트를 알려주세요.

→ END (사용자 후속 입력 대기).

## Step 3: 인터뷰 진입

Trivia 아닌 경우, `conducting-interview` skill을 invoke하십시오:

```
Skill conducting-interview $ARGUMENTS
```

`conducting-interview` skill이 4-block Korean format으로 첫 round를 진행합니다.

## Arguments

`$ARGUMENTS` — 사용자가 `/interview`에 함께 넘긴 rough request. 비어 있으면 `conducting-interview`가 첫 질문 ("어떤 것을 만들고 싶으신가요?")으로 시작.

## 다음 단계

`conducting-interview` skill로 흐름이 넘어갑니다. 이 command 자체는 trivia escape + skill dispatch 책임만 집니다.
```

- [ ] **Step 2: Verify command file structure**

```bash
test -f plugins/spec-distill/commands/interview.md && \
  head -5 plugins/spec-distill/commands/interview.md | grep -q "argument-hint" && \
  grep -q "Trivia Escape Check" plugins/spec-distill/commands/interview.md && \
  grep -q "DEVBREW_DISABLE_SPEC_DISTILL" plugins/spec-distill/commands/interview.md && \
  echo OK
```

Expected: `OK`

- [ ] **Step 3: Verify 5 trivia patterns enumerated**

```bash
grep -cE "^[0-9]+\. \*\*" plugins/spec-distill/commands/interview.md
```

Expected: `5`

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/commands/interview.md
git commit -m "feat(spec-distill): add /interview command with trivia escape (5 patterns, AC10/AP4 회피)"
```

---

## Task 4: hooks/hooks.json + interview-trigger.sh (UserPromptSubmit, AC8/9)

**Files:**
- Create: `plugins/spec-distill/hooks/hooks.json`
- Create: `plugins/spec-distill/hooks/interview-trigger.sh`

- [ ] **Step 1: Write `hooks.json` (UserPromptSubmit only — SessionStart added in Task 5)**

File: `plugins/spec-distill/hooks/hooks.json`

```json
{
  "description": "spec-distill — UserPromptSubmit interview suggestion + SessionStart anchor for resumed sessions.",
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/interview-trigger.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Write `interview-trigger.sh`**

File: `plugins/spec-distill/hooks/interview-trigger.sh`

```bash
#!/usr/bin/env bash
# spec-distill UserPromptSubmit hook
# Emits a <spec-distill-signal> tag when the user prompt looks like a build/make/create request.
# Strictly advisory — does not block.

set -u

# Kill switches (devbrew convention)
if [[ "${DEVBREW_DISABLE_SPEC_DISTILL:-}" == "1" ]]; then
  exit 0
fi
if [[ "${DEVBREW_SKIP_HOOKS:-}" == *"spec-distill:UserPromptSubmit"* ]]; then
  exit 0
fi

# Read prompt from stdin (Claude Code passes JSON event payload via stdin)
payload=$(cat 2>/dev/null || echo "")
prompt=$(echo "$payload" | grep -oE '"user_prompt"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"user_prompt"[[:space:]]*:[[:space:]]*"\(.*\)"$/\1/' || echo "")

# Fallback: treat whole stdin as prompt if JSON parse failed
if [[ -z "$prompt" ]]; then
  prompt="$payload"
fi

# Skip if already an explicit /interview call
if [[ "$prompt" =~ ^/interview ]]; then
  exit 0
fi

# Detect build/make/create keywords (Korean + English)
keywords_pattern='build|make|create|implement|design|구축|만들|생성|구현|디자인'

# Detect short prompts (< 20 words) — heuristic for "vague request"
word_count=$(echo "$prompt" | wc -w | tr -d ' ')

if echo "$prompt" | grep -qiE "$keywords_pattern" && [[ "$word_count" -lt 20 ]]; then
  cat <<EOF
<spec-distill-signal>
이 요청은 spec 작성 인터뷰가 필요해 보입니다 (build/make/create 키워드 + 짧은 prompt).
명시적으로 \`/interview\`를 호출하면 4-block Korean Socratic 인터뷰로 모호함을 줄일 수 있습니다.
(이 신호는 advisory — 강제하지 않습니다. 무시하고 진행해도 됩니다.)
</spec-distill-signal>
EOF
fi

exit 0
```

- [ ] **Step 3: Make executable + bash syntax check**

```bash
chmod +x plugins/spec-distill/hooks/interview-trigger.sh
bash -n plugins/spec-distill/hooks/interview-trigger.sh
echo "syntax exit: $?"
```

Expected: `syntax exit: 0`, no other output.

- [ ] **Step 4: Verify `hooks.json` valid + UserPromptSubmit registered**

```bash
jq -e '.hooks.UserPromptSubmit | length > 0' plugins/spec-distill/hooks/hooks.json
```

Expected: `true`

- [ ] **Step 5: Smoke test — kill switch (plugin-wide, AC8)**

```bash
DEVBREW_DISABLE_SPEC_DISTILL=1 bash plugins/spec-distill/hooks/interview-trigger.sh <<< '{"user_prompt": "build me a todo app"}'
echo "exit: $?"
```

Expected: `exit: 0`, no `<spec-distill-signal>` output.

- [ ] **Step 6: Smoke test — kill switch (hook-specific, AC9)**

```bash
DEVBREW_SKIP_HOOKS="spec-distill:UserPromptSubmit" bash plugins/spec-distill/hooks/interview-trigger.sh <<< '{"user_prompt": "build me a todo app"}'
echo "exit: $?"
```

Expected: `exit: 0`, no signal.

- [ ] **Step 7: Smoke test — happy path (signal emitted)**

```bash
bash plugins/spec-distill/hooks/interview-trigger.sh <<< '{"user_prompt": "build me a todo app"}'
```

Expected: output contains `<spec-distill-signal>` and mentions `/interview`.

- [ ] **Step 8: Commit**

```bash
git add plugins/spec-distill/hooks/hooks.json plugins/spec-distill/hooks/interview-trigger.sh
git commit -m "feat(spec-distill): add UserPromptSubmit hook with kill switch + Korean/English keyword detection (AC8/9)"
```

---

## Task 5: SessionStart `session-anchor.sh` hook (P14 read-only advisor)

**Files:**
- Create: `plugins/spec-distill/hooks/session-anchor.sh`
- Modify: `plugins/spec-distill/hooks/hooks.json` (add SessionStart entry)

- [ ] **Step 1: Write `session-anchor.sh`**

File: `plugins/spec-distill/hooks/session-anchor.sh`

```bash
#!/usr/bin/env bash
# spec-distill SessionStart hook — read-only advisor (P14 mutate X).
# Emits anchor message if previous session state exists.

set -u

# Kill switches
if [[ "${DEVBREW_DISABLE_SPEC_DISTILL:-}" == "1" ]]; then
  exit 0
fi
if [[ "${DEVBREW_SKIP_HOOKS:-}" == *"spec-distill:SessionStart"* ]]; then
  exit 0
fi

state_dir=".claude/spec-distill"

# Check if state directory exists with active sessions
if [[ -d "$state_dir" ]]; then
  active_sessions=$(find "$state_dir" -mindepth 2 -maxdepth 2 -name "state.local.md" 2>/dev/null | head -3)
  if [[ -n "$active_sessions" ]]; then
    cat <<EOF
<spec-distill-anchor>
이전 인터뷰 세션이 있습니다. 다음 위치에 state 파일이 보존돼 있습니다:
$active_sessions

\`/interview resume\`로 재진입하거나, 새 세션은 \`/interview\` 그대로 시작.
(이 anchor는 read-only advisory — state는 자동 mutate되지 않습니다.)
</spec-distill-anchor>
EOF
  fi
fi

exit 0
```

- [ ] **Step 2: Replace `hooks.json` with both events registered**

File: `plugins/spec-distill/hooks/hooks.json`

```json
{
  "description": "spec-distill — UserPromptSubmit interview suggestion + SessionStart anchor for resumed sessions.",
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/interview-trigger.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/session-anchor.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 3: Make executable + bash syntax check**

```bash
chmod +x plugins/spec-distill/hooks/session-anchor.sh
bash -n plugins/spec-distill/hooks/session-anchor.sh
echo "syntax exit: $?"
```

Expected: `syntax exit: 0`.

- [ ] **Step 4: Verify `hooks.json` now has both events**

```bash
jq -e '.hooks | has("UserPromptSubmit") and has("SessionStart")' plugins/spec-distill/hooks/hooks.json
```

Expected: `true`

- [ ] **Step 5: Smoke test — no state dir (no anchor expected)**

```bash
rm -rf .claude/spec-distill 2>/dev/null
bash plugins/spec-distill/hooks/session-anchor.sh
echo "exit: $?"
```

Expected: `exit: 0`, no anchor output.

- [ ] **Step 6: Smoke test — state dir exists (anchor expected)**

```bash
mkdir -p .claude/spec-distill/test-session-id
echo "---" > .claude/spec-distill/test-session-id/state.local.md
bash plugins/spec-distill/hooks/session-anchor.sh
```

Expected: output contains `<spec-distill-anchor>`.

- [ ] **Step 7: Cleanup test state**

```bash
rm -rf .claude/spec-distill/test-session-id
```

- [ ] **Step 8: Commit**

```bash
git add plugins/spec-distill/hooks/session-anchor.sh plugins/spec-distill/hooks/hooks.json
git commit -m "feat(spec-distill): add SessionStart anchor hook (P14 read-only advisor)"
```

---

## Task 6: `breadth-keeper` agent (C45, AC4/13)

**Files:**
- Create: `plugins/spec-distill/agents/breadth-keeper.md`

- [ ] **Step 1: Write `breadth-keeper.md`**

File: `plugins/spec-distill/agents/breadth-keeper.md`

```markdown
---
name: breadth-keeper
model: sonnet
cost_class: low
color: blue
disallowedTools:
  - Write
  - Edit
  - MultiEdit
  - NotebookEdit
description: >
  Use this agent during a spec-distill interview round to detect narrow tunneling
  (예: 사용자와 interviewer가 한 dimension에 너무 깊이 들어가서 다른 가능성을
  놓치고 있는 패턴) and suggest lateral questions. Read-only by design (Law 2
  Writer/Reviewer 분리, frontmatter scoping). Maximum 1 invocation per interview
  round (AC13 subagent spray 회피).

  <example>Context: Interviewer just asked 3 follow-ups about authentication mechanism.
  user: "이 라운드에서 breadth check 해줘"
  assistant: "I'll use the breadth-keeper agent to scan if we're missing other dimensions."</example>
---

# Breadth-Keeper Agent (C45 흡수)

당신은 spec-distill 인터뷰의 breadth-keeper입니다. 단일 dimension에 깊이 들어가는 narrow tunneling 패턴을 감지하고, 사용자가 놓칠 수 있는 lateral question을 제안하는 역할을 합니다.

## Input

다음 컨텍스트를 받습니다:

- 현재 인터뷰 round 번호
- 직전 3개 round의 transcript (대화 발췌)
- 현재 spec draft snapshot (있는 경우)

## Output 형식 (이 형식을 정확히 준수)

```yaml
narrow_tunneling: true | false
focused_dimension: "<현재 깊이 들어간 dimension 이름, 예: 'auth mechanism', 'database choice'>"
neglected_dimensions:
  - "<예: 'deployment target'>"
  - "<예: 'expected scale'>"
suggested_lateral_questions:
  - "<lateral question 1>"
  - "<lateral question 2>"
confidence: 0.0-1.0
```

## 동작 규칙

1. **read-only**: 어떤 파일도 Write/Edit/MultiEdit/NotebookEdit 하지 않습니다 (frontmatter 강제). spec.md를 직접 수정 금지.
2. **frequency**: 인터뷰 round당 *최대 1회* 호출됨 (AC13). 자동 fan-out 없음.
3. **lateral, not deeper**: 같은 dimension에서 더 깊은 질문 제안 금지 — 다른 dimension 제안만.
4. **confidence**: 0.5 미만이면 `narrow_tunneling: false`로 응답. 약한 신호로 사용자를 산만하게 하지 않음.

## 사용하지 않는 경우

- 인터뷰 첫 round (탐색 시기)
- spec draft가 이미 lock된 후 (회복 불가능한 routing)
- trivia 요청 (P12)

## 호출 컨텍스트

`conducting-interview` skill이 round당 최대 1회 dispatch합니다.
```

- [ ] **Step 2: Verify `disallowedTools` has 4 entries (AC4)**

```bash
grep -A5 "^disallowedTools:" plugins/spec-distill/agents/breadth-keeper.md | grep -cE "^\s*-\s*(Write|Edit|MultiEdit|NotebookEdit)\s*$"
```

Expected: `4`

- [ ] **Step 3: Verify `cost_class` declared**

```bash
grep -E "^cost_class: low" plugins/spec-distill/agents/breadth-keeper.md
```

Expected: line matches.

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/agents/breadth-keeper.md
git commit -m "feat(spec-distill): add breadth-keeper agent (C45 흡수, Law 2 frontmatter scoping, AC4/13)"
```

---

## Task 7: `spec-reviewer` agent (Law 2 + AC4/5/7)

**Files:**
- Create: `plugins/spec-distill/agents/spec-reviewer.md`

- [ ] **Step 1: Write `spec-reviewer.md`**

File: `plugins/spec-distill/agents/spec-reviewer.md`

```markdown
---
name: spec-reviewer
model: sonnet
cost_class: medium
color: orange
disallowedTools:
  - Write
  - Edit
  - MultiEdit
  - NotebookEdit
description: >
  Use this agent to adversarially review a spec.md draft produced by the
  spec-distill plugin's drafting-spec skill. Hunts for unstated assumptions,
  missing required sections, untestable acceptance criteria, and concrete-
  next-action absence. Output: Status / Issues / Recommendations / Stagnation_signal
  (compatible with superpowers plan-document-reviewer-prompt format). Physically
  blocked from editing files (Law 2 frontmatter scoping).

  <example>Context: drafting-spec just produced a spec.md draft.
  user: "이 spec.md 검토해줘"
  assistant: "I'll dispatch the spec-reviewer agent to adversarially review the spec draft."</example>
---

# Spec-Reviewer Agent (Law 2 + AP14 회피)

당신은 spec-distill 플러그인의 spec-reviewer 입니다. 사용자의 인터뷰 결과로 작성된 spec.md draft를 *공격적으로* (adversarially) 리뷰하여 unstated assumption, 누락 섹션, untestable AC, concrete-next-action 부재를 찾아냅니다.

## Input

- spec.md 파일 경로 (`docs/superpowers/specs/<file>-spec.md`)
- (선택) 이전 review history — 같은 issue ID 추적용

## Required reading (review 시작 전)

1. spec.md 전체 — 모든 섹션 정독.
2. (있다면) 이전 review의 issue history — `Stagnation_signal` 판정 위해 비교.

## What to check

| Category | What to flag | Severity |
|---|---|---|
| `missing_section` | 11 필수 섹션 (Goal/Context/Goals/Non-goals/Constraints/Acceptance Criteria/Files to Modify/Verification Plan/Rejected Alternatives/Open Questions/Concrete Next Action) 중 하나라도 누락 | block |
| `concrete_action_missing` | "Concrete Next Action" 섹션 누락 또는 모호 (다음 명령 명시 없음) | block (gstack pattern) |
| `ambiguous_requirement` | Goal/Goals/AC에 측정 불가능한 표현 ("works correctly", "fast", "good UX") | high |
| `unstated_assumption` | spec이 가정하는 인프라/외부/팀 컨텍스트 명시 안 됨 | high |
| `untestable_AC` | AC가 verification 명령으로 검증 불가 | high |
| `scope_creep` | Non-goals와 Goals 충돌, 또는 한 spec에 multiple subsystem | medium |

## Issue ID 정의 (rephrase dodge 방지)

```
issue_id = sha256_short(category + ":" + target_section)
```

- Categories: 위 6개
- Target section: spec.md markdown anchor (e.g., `#goals`, `#acceptance-criteria`)

## Stagnation_signal 판정 (AC7)

이전 review history에서 같은 `issue_id`가 `raised_count >= 3` *unresolved* 상태로 raise됐으면 `Stagnation_signal: true`.

## Output 형식 (이 형식을 정확히 준수, AC5)

```markdown
## Spec Review (round N)

**Status:** approved | needs_revise | needs_interview

**Issues:**
- [<#section>]: <category> — "<message>" — raised <N>x ⚠ unresolved (if applicable)
- ...

**Recommendations (advisory):**
- ...

**Stagnation_signal:** true | false
```

## verdict 규칙

- **approved**: 11 섹션 모두 + concrete next action 명시 + AC 모두 측정 가능 + unstated assumption 없음.
- **needs_revise**: 위 중 일부 누락이지만 인터뷰 round 추가는 불필요 (drafting-spec에서 해결 가능).
- **needs_interview**: 사용자 의도가 spec에 약하게 표현돼 있어 추가 인터뷰 round가 필요.

## 동작 제약 (Law 2 frontmatter)

- **read-only**: Write/Edit/MultiEdit/NotebookEdit 모두 frontmatter로 차단됨. 어떤 파일도 직접 수정 시도 금지.
- **adversarial 색채**: "괜찮아 보임" 식의 polite review 금지. 약점 찾기에 적극적.
- **calibration**: minor wording / stylistic preferences는 issue 아님. block-worthy issue는 implementation-blocking 약점만.
```

- [ ] **Step 2: Verify `disallowedTools` has 4 entries (AC4)**

```bash
grep -A5 "^disallowedTools:" plugins/spec-distill/agents/spec-reviewer.md | grep -cE "^\s*-\s*(Write|Edit|MultiEdit|NotebookEdit)\s*$"
```

Expected: `4`

- [ ] **Step 3: Verify output format keywords (AC5)**

```bash
for keyword in "Status:" "Issues:" "Recommendations" "Stagnation_signal:"; do
  grep -q "$keyword" plugins/spec-distill/agents/spec-reviewer.md && echo "$keyword OK"
done
```

Expected: 4 lines, all "OK".

- [ ] **Step 4: Verify all 6 issue categories enumerated**

```bash
grep -cE "^\| \`(missing_section|concrete_action_missing|ambiguous_requirement|unstated_assumption|untestable_AC|scope_creep)\`" plugins/spec-distill/agents/spec-reviewer.md
```

Expected: `6`

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/agents/spec-reviewer.md
git commit -m "feat(spec-distill): add spec-reviewer agent (Law 2 + AP14 회피, superpowers-compatible output, AC4/5/7)"
```

---

## Task 8: `conducting-interview` skill (Phase 1, AC1/2/13 + C43-C45+C51)

**Files:**
- Create: `plugins/spec-distill/skills/conducting-interview/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

File: `plugins/spec-distill/skills/conducting-interview/SKILL.md`

```markdown
---
name: conducting-interview
description: >
  Use this skill to run the spec-distill 4-block Korean Socratic interview.
  Called by /interview command after trivia escape check passes. Implements
  C43 4-path routing (factual auto-confirm / judgment→user / ambiguity→sub-agent /
  ontological→5-type), C44 Dialectic Rhythm Guard, C45 breadth-keeper dispatch
  (max 1 per round, AC13). Persists state to .claude/spec-distill/<session-id>/state.local.md.
cost_class: medium
---

# Conducting Interview (Phase 1)

당신은 spec-distill의 인터뷰 phase를 진행 중입니다. 사용자의 모호한 요청을 명확한 spec으로 변환하기 위해 4-block Korean Socratic format으로 round를 진행합니다.

## State location (AC2)

`.claude/spec-distill/<session-id>/state.local.md` (per-session 격리, devbrew §4.8 준수)

State frontmatter schema:

```yaml
---
session_id: <uuid>
phase: 1
interview_round: <int>
non_user_streak: <int>
rereview_count: 0
wall_clock_started_at: <ISO8601>
trivia_escape_armed: false
issue_history: []
---
```

State body: 각 round의 4-block 출력 + 사용자 답변 + (있다면) breadth-keeper 출력 transcript.

**Secret 기록 금지** (P21): 사용자 답변에 token/key/credential 패턴 감지 시 placeholder로 치환 후 기록.

## 4-block Korean format (devbrother2024 deep-interview 흡수, AC1)

매 round마다 다음 4 block을 출력하십시오:

```markdown
**현재 이해:**
(지금까지 인터뷰로 파악한 사용자 요청의 *현재 이해*를 한두 문장으로 요약. 1라운드는 사용자 prompt에서 추출.)

**막힌 결정:**
(가장 큰 단일 불확실성 — goal/scope/constraints/AC 중 가장 모호한 한 가지를 명시.)

**추천 답안:**
(막힌 결정에 대한 *내 추천 답*. 사용자가 No만 골라도 진행 가능하게.)

**질문:**
(한 번에 하나의 질문. 다지선다 형태 권장. open-ended는 신중히.)
```

## C43 4-path routing

질문을 만들 때 다음 4 경로 중 하나로 분류해서 routing 하십시오:

| Path | When | Action |
|---|---|---|
| (a) **factual** | 답이 codebase/git history에 있는 경우 | grep/Read로 *auto-confirm*, 사용자에게 묻지 않음. transcript에 `[from-code][auto-confirmed]` 마커 표시. |
| (b) **judgment** | 사용자 선호/우선순위/제약 | 사용자에게 묻기 (default path). 4-block 출력. |
| (c) **ambiguity** | 여러 해석 가능한 핵심 가정 | sub-agent에 adversarial draft 요청 (`general-purpose` agent에 "이 가정이 잘못됐다면 어떤 시나리오가 가능한가?" 형태로 dispatch). 답을 그대로 사용자에게 보여주고 confirm. |
| (d) **ontological** | "이게 무엇인가" 종류 (essence/root cause 등) | C51 5-type framework 사용 — ESSENCE / ROOT_CAUSE / PREREQUISITES / HIDDEN_ASSUMPTIONS / EXISTING_CONTEXT 중 하나로 라벨링 후 사용자에게 묻기. |

매 round의 4-block에서 어떤 path로 routing했는지 transcript에 명시하십시오.

## C44 Dialectic Rhythm Guard

`non_user_streak` 카운터 — 직전 N round 동안 *사용자 답변이 없었던* 횟수.

- (a) factual auto-confirm: streak +1
- (c) sub-agent adversarial: streak +1
- (b) 사용자 답변 받음: streak = 0
- (d) ontological 사용자 답변 받음: streak = 0

`non_user_streak >= DEVBREW_RHYTHM_GUARD_THRESHOLD` (default 3) 도달 시:

→ 다음 round의 질문은 **반드시 (b) judgment path** (사용자에게 직접 질문)로 라우팅. 강제.

## breadth-keeper dispatch (C45, AC13)

매 round 끝에 다음 조건 모두 만족하면 `breadth-keeper` agent를 1회 dispatch:

1. `interview_round >= 2` (첫 round는 탐색기 — skip)
2. 직전 3 round가 같은 dimension(같은 spec 섹션)에 집중함
3. 이번 round에서 dispatch 안 한 경우 (round당 max 1, AC13)

dispatch 결과 (`narrow_tunneling: true`) 면 다음 round 시작 시 `suggested_lateral_questions` 중 하나를 추천 답안으로 제시.

## 종료 조건

다음을 모두 만족하면 phase 1 종료, drafting-spec skill로 전환:

- Goal 명확 (한 문장으로 표현 가능)
- Goals/Non-goals 일관 (충돌 없음)
- Constraints 명시
- Acceptance Criteria 측정 가능 형태로 도출
- Open Questions 사용자 인지 (불명확한 것은 OQ로 박제)

종료 시 다음 메시지 출력:

> 인터뷰 phase 종료 조건 충족. `drafting-spec` skill로 전환합니다.

## kill switch

- `DEVBREW_DISABLE_SPEC_DISTILL=1`: 즉시 abort, state.local.md 보존 (실패 분석용).
- `DEVBREW_RHYTHM_GUARD_THRESHOLD=N`: rhythm guard threshold override.
- `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN=N`: wall-clock budget (default 30) — 초과 시 advisory metric에 기록.

## 다음 phase

`drafting-spec` skill 호출. 인터뷰 transcript와 결정된 정보를 input으로 넘김.
```

- [ ] **Step 2: Verify `cost_class` declared**

```bash
grep -E "^cost_class: medium" plugins/spec-distill/skills/conducting-interview/SKILL.md
```

Expected: line matches.

- [ ] **Step 3: Verify 4-block format keywords (AC1)**

```bash
for keyword in "현재 이해" "막힌 결정" "추천 답안" "질문"; do
  grep -q "$keyword" plugins/spec-distill/skills/conducting-interview/SKILL.md && echo "$keyword OK"
done
```

Expected: 4 lines, all "OK".

- [ ] **Step 4: Verify state schema fields (AC2)**

```bash
for field in "session_id" "phase" "interview_round" "non_user_streak" "rereview_count" "wall_clock_started_at" "trivia_escape_armed" "issue_history"; do
  grep -q "$field" plugins/spec-distill/skills/conducting-interview/SKILL.md && echo "$field OK"
done
```

Expected: 8 lines, all "OK".

- [ ] **Step 5: Verify C43 routing references all 4 paths**

```bash
for path in "factual" "judgment" "ambiguity" "ontological"; do
  grep -q "$path" plugins/spec-distill/skills/conducting-interview/SKILL.md && echo "$path OK"
done
```

Expected: 4 lines, all "OK".

- [ ] **Step 6: Verify breadth-keeper dispatch rule (AC13)**

```bash
grep -q "round당 max 1" plugins/spec-distill/skills/conducting-interview/SKILL.md && echo "AC13 OK"
```

Expected: `AC13 OK`

- [ ] **Step 7: Commit**

```bash
git add plugins/spec-distill/skills/conducting-interview/SKILL.md
git commit -m "feat(spec-distill): add conducting-interview skill (4-block + C43-C45+C51, AC1/2/13)"
```

---

## Task 9: `drafting-spec` skill (Phase 2 + Phase 4, AC3)

**Files:**
- Create: `plugins/spec-distill/skills/drafting-spec/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

File: `plugins/spec-distill/skills/drafting-spec/SKILL.md`

```markdown
---
name: drafting-spec
description: >
  Use this skill to (a) draft initial spec.md from interview transcript at end
  of conducting-interview phase, or (b) revise spec.md per spec-reviewer issues
  (Phase 4 of spec-distill flow). Writes to docs/superpowers/specs/YYYY-MM-DD-
  <topic>-spec.md using templates/spec-template.md as scaffolding.
cost_class: low
---

# Drafting Spec (Phase 2 / Phase 4)

당신은 spec-distill의 spec writer입니다. 두 가지 모드로 동작합니다.

## Mode A: Initial draft (Phase 2)

`conducting-interview` skill의 종료 후 호출됨. 인터뷰 transcript를 input으로 받아 첫 spec.md draft를 생성합니다.

### Steps

1. **Read template**: `${CLAUDE_PLUGIN_ROOT}/templates/spec-template.md` 로 11 섹션 + frontmatter 구조 확보.
2. **Resolve filename**: `docs/superpowers/specs/<YYYY-MM-DD>-<kebab-case-topic>-spec.md`. `<topic>`는 인터뷰에서 도출한 Goal에서 추출 (kebab-case, 4-6 words max).
3. **Fill 11 sections** from transcript (AC3):
   - **Goal** — 한 문장 (인터뷰에서 도출한 최종 Goal).
   - **Context / Why** — motivation, who asked, what's at stake.
   - **Goals** — bullet list with G1, G2, ... (testable).
   - **Non-goals** — bullet list with NG1, NG2, ... (명시적 제외).
   - **Constraints** — bullet list with C1, C2, ... (tech/시간/팀 제약).
   - **Acceptance Criteria** — bullet list with AC1, AC2, ... (*측정 가능* 표현, untestable 표현 금지).
   - **Files to Modify** — 인터뷰에서 도출한 경로 (없으면 "TBD — implementation phase에서 결정").
   - **Verification Plan** — bullet list with V1, V2, ... (manual/automated check + exact command).
   - **Rejected Alternatives** — 인터뷰 중 거절된 옵션을 R1, R2, ... 형태로.
   - **Open Questions** — 인터뷰 종료 시 미해결 항목 (없으면 "None").
   - **Concrete Next Action** — 다음 단계 명시 (default: superpowers writing-plans 호출 + spec 경로 + plan 산출 경로 + 명령).
4. **Fill frontmatter** (7 fields): `name`, `version: 1.0.0`, `created_at`, `session_id`, `status: locked`, `next_phase: writing-plans`, `source: spec-distill v0.1.0`.
5. **Write file** with `Write` tool to resolved path.
6. **Update state.local.md**: `phase: 3` (다음은 reviewer phase).

## Mode B: Revise per review (Phase 4)

`reviewing-spec` skill에서 사용자가 "revise per review" 선택 시 호출됨.

### Steps

1. **Read current spec.md** + reviewer's `Issues` list.
2. **For each issue**, identify the target section (`#goals`, `#acceptance-criteria` 등) and apply targeted fix:
   - `missing_section` → 섹션 추가.
   - `concrete_action_missing` → "Concrete Next Action" 섹션 채움.
   - `ambiguous_requirement` → 측정 가능 표현으로 재작성.
   - `unstated_assumption` → "Constraints" 또는 "Context" 섹션에 명시 추가.
   - `untestable_AC` → AC를 verification 명령 + 예상 결과 형태로 재작성.
   - `scope_creep` → Non-goals 섹션 강화 또는 Goals 분리.
3. **Write file** with `Edit` tool (전체 rewrite 대신 targeted edit).
4. **Update state.local.md**: `issue_history`에 resolved 마커 표시 (해당 `issue_id`의 `resolved: true`).
5. **Re-dispatch reviewing-spec** for re-review.

## "유추 금지" 원칙 (사용자 #3 반영)

draft 중 인터뷰에서 답을 못 얻은 항목은 **유추하지 말고** "Open Questions"에 박제. 임의 가정은 spec contract violation.

## kill switch

- `DEVBREW_DISABLE_SPEC_DISTILL=1`: 즉시 abort, draft 미완성이면 그대로 보존.

## 다음 phase

`reviewing-spec` skill 호출. spec.md 경로를 input으로.
```

- [ ] **Step 2: Verify `cost_class` declared**

```bash
grep -E "^cost_class: low" plugins/spec-distill/skills/drafting-spec/SKILL.md
```

Expected: line matches.

- [ ] **Step 3: Verify both modes documented**

```bash
grep -cE "^## Mode [AB]" plugins/spec-distill/skills/drafting-spec/SKILL.md
```

Expected: `2`

- [ ] **Step 4: Verify all 6 issue categories handled in Mode B**

```bash
for cat in "missing_section" "concrete_action_missing" "ambiguous_requirement" "unstated_assumption" "untestable_AC" "scope_creep"; do
  grep -q "\`$cat\`" plugins/spec-distill/skills/drafting-spec/SKILL.md && echo "$cat OK"
done
```

Expected: 6 lines, all "OK".

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/skills/drafting-spec/SKILL.md
git commit -m "feat(spec-distill): add drafting-spec skill (Mode A draft + Mode B revise, AC3)"
```

---

## Task 10: `reviewing-spec` skill with deterministic routing (AC5/6/7/11/14/15)

**Files:**
- Create: `plugins/spec-distill/skills/reviewing-spec/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

File: `plugins/spec-distill/skills/reviewing-spec/SKILL.md`

```markdown
---
name: reviewing-spec
description: >
  Use this skill to dispatch the spec-reviewer agent against a spec.md draft
  and apply deterministic routing per the verdict × signal table. Manages re-
  review cap (max 3, AC6), stagnation detection (AC7), wall-clock budget (AC14),
  and approve handoff sequence (AC11). Routing table is defined below in this
  SKILL.md (AC15) — agent verdict × stagnation signal × rereview count → next phase.
cost_class: medium
---

# Reviewing Spec (Phase 3)

당신은 spec-distill의 review phase를 진행 중입니다. spec-reviewer agent를 dispatch하고, 받은 verdict + 메타 신호를 *deterministic table*에 매핑해서 다음 phase를 결정합니다.

## Steps

1. **Load state.local.md** — `rereview_count`, `wall_clock_started_at`, `issue_history` 읽기.
2. **Wall-clock check (AC14)**: `now - wall_clock_started_at > DEVBREW_SPEC_DISTILL_TIMEOUT_MIN` (default 30) 이면 advisory metric 표기 + Phase 5 forced escalate.
3. **Dispatch spec-reviewer agent**:
   ```
   Agent({
     description: "Spec adversarial review",
     subagent_type: "spec-reviewer",
     prompt: "Review spec.md at <path>. Previous issue history: <list>"
   })
   ```
4. **Parse output** — Status, Issues, Recommendations, Stagnation_signal.
5. **Apply routing table** (다음 섹션).
6. **Update state.local.md** — `rereview_count += 1`, `issue_history`에 새 issues 추가/raised_count 증가.

## Deterministic Routing Table (AC15)

| Verdict | Stagnation_signal | rereview_count | → Next Phase |
|---|---|---|---|
| `approved` | - | - | **[5] Human Gate** (auto) |
| `needs_revise` | false | < 3 | **[4] Revise** (auto, dispatch drafting-spec Mode B) |
| `needs_revise` | false | >= 3 | **[5] Human Gate** (forced escalate, full issue_history 첨부) |
| `needs_revise` | true | - | **[5] Human Gate** (P18 stagnation, forced escalate) |
| `needs_interview` | - | - | **user confirm gate** → [1] Interview (확인) 또는 [5] (취소) |

매 dispatch 후 위 표를 *그대로* 적용. prose-based 결정 금지.

### Re-review cap (AC6)

`rereview_count >= 3` 도달 시 (즉 4번째 reviewer dispatch 시도 시): 자동으로 [5] Human Gate로 forced escalate, 전체 `issue_history` 첨부.

### Stagnation detection (AC7)

spec-reviewer agent가 `Stagnation_signal: true` 반환 시 (이전 review 동일 issue_id `raised_count >= 3 unresolved`): 자동 [5] forced escalate, P18 stagnation 명시.

## Phase 5 Human Gate

사용자에게 reviewer 결과를 표시하고, 다음 옵션 중 선택받습니다 (`AskUserQuestion` 활용):

- **"revise per review"** → drafting-spec Mode B 호출.
- **"more interview"** → conducting-interview skill 호출 (state phase = 1로 reset, interview_round 유지).
- **"edit spec myself"** → 사용자가 직접 spec.md 편집 후 반환 → reviewing-spec 재진입.
- **"approve"** → Approve handoff sequence (다음 섹션).

## Approve handoff sequence (AC11)

사용자 "approve" 선택 시 다음 4 step을 *그대로* 실행:

```bash
# Step 1: Commit spec.md
git add docs/superpowers/specs/<file>-spec.md
git commit -m "spec: <topic> (v1.0.0, spec-distill v0.1.0)"

# Step 2: Output handoff pointer
echo "Spec lock 완료. 다음 단계:"
echo "  superpowers writing-plans skill 호출"
echo "  Spec 경로: docs/superpowers/specs/<file>-spec.md"
echo "  명령: Skill superpowers:writing-plans <위 경로>"

# Step 3: State cleanup
rm -rf .claude/spec-distill/<session-id>/

# Step 4: Plugin termination
echo "spec-distill v0.1.0 종료."
```

**polite stop 금지** (AP2): "spec is approved!"만 narrate하고 위 4 step을 skip하면 안 됨. 4 step 모두 *실제로* 실행.

### 실패 시 state 보존 (P14)

git commit 실패 / handoff 실패 / cleanup 실패 시: state.local.md 보존, 사용자에게 실패 원인 명시.

## kill switch

- `DEVBREW_DISABLE_SPEC_DISTILL=1`: 즉시 abort, state.local.md 보존.
- `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN=N`: wall-clock budget override (default 30).
```

- [ ] **Step 2: Verify `cost_class` declared**

```bash
grep -E "^cost_class: medium" plugins/spec-distill/skills/reviewing-spec/SKILL.md
```

Expected: line matches.

- [ ] **Step 3: Verify routing table present (AC15)**

```bash
grep -cE "^\| \`(approved|needs_revise|needs_interview)\`" plugins/spec-distill/skills/reviewing-spec/SKILL.md
```

Expected: `>= 5`

- [ ] **Step 4: Verify approve handoff has 4 steps (AC11)**

```bash
grep -cE "^# Step [1-4]:" plugins/spec-distill/skills/reviewing-spec/SKILL.md
```

Expected: `4`

- [ ] **Step 5: Verify rereview cap reference (AC6)**

```bash
grep -q "rereview_count >= 3" plugins/spec-distill/skills/reviewing-spec/SKILL.md && echo "AC6 OK"
```

Expected: `AC6 OK`

- [ ] **Step 6: Verify wall-clock budget reference (AC14)**

```bash
grep -q "DEVBREW_SPEC_DISTILL_TIMEOUT_MIN" plugins/spec-distill/skills/reviewing-spec/SKILL.md && echo "AC14 OK"
```

Expected: `AC14 OK`

- [ ] **Step 7: Commit**

```bash
git add plugins/spec-distill/skills/reviewing-spec/SKILL.md
git commit -m "feat(spec-distill): add reviewing-spec skill with deterministic routing (AC5/6/7/11/14/15)"
```

---

## Task 11: README "Principles Instantiated" complete (AC12)

**Files:**
- Modify: `plugins/spec-distill/README.md`

- [ ] **Step 1: Replace `README.md` with full content**

File: `plugins/spec-distill/README.md`

```markdown
# spec-distill

> 집요한 인터뷰로 모호함을 명확함으로 변환해 superpowers 호환 `spec.md`를 생성하는 devbrew-native 플러그인 — interview → spec phase.

## What it does

`/interview <rough request>` 또는 `/interview` 호출 시 4-block Korean Socratic 인터뷰로 모호한 요청을 명확한 spec.md로 변환합니다. 산출물은 `docs/superpowers/specs/YYYY-MM-DD-<topic>-spec.md` (superpowers `writing-plans` input 호환). v0.1.0은 interview → spec phase까지 — plan 단계는 v0.2.0 또는 superpowers `writing-plans`로 위임.

## Quick start

```
/interview todo 앱 만들어줘
```

`conducting-interview` skill이 4-block format ("현재 이해 / 막힌 결정 / 추천 답안 / 질문")으로 첫 round를 시작합니다.

## Flow (Phase 0–5)

```
[0] Trigger ──→ [1] Interview ←──────────────┐
                    │                        │
                    ↓                        │
                [2] Draft                    │
                    │                        │
                    ↓                        │
                [3] Spec Reviewer ── verdict │
                    ├─ needs_interview → user confirm → [1]
                    ├─ needs_revise ────→ [4]
                    └─ approved ────────→ [5]
                [4] Revise → [3] (auto re-review, max 3)
                [5] Human Gate
                    ├─ "more interview" → [1]
                    ├─ "edit spec"      → [4]
                    └─ "approve"        → handoff (commit + pointer + cleanup)
```

## Principles Instantiated

이 플러그인이 instantiate하는 devbrew 철학.

### Three Laws

- **Law 1 (Clarity Before Code)** — Plugin의 raison d'être. 인터뷰 → spec lock → reviewer → human gate. "spec 이전엔 코딩 안 한다" 강제.
- **Law 2 (Writer/Reviewer 분리)** — `disallowedTools: Write, Edit, MultiEdit, NotebookEdit` frontmatter로 spec-reviewer + breadth-keeper agent의 *물리적* 분리. 프롬프트가 아닌 frontmatter scoping.
- **Law 3 (Compounding)** — spec.md 파일 자체가 named, versioned, diff-able artifact (P5). state.local.md 보존 (실패 시) → 디버깅 + future session 추적.

### Principles 흡수

- **P2 (Ambiguity Gate)** — 구조적 (필수 11 섹션) default, numerical 거부 (philosophy §5.3).
- **P5 (Spec as artifact)** — `docs/superpowers/specs/...spec.md` named, versioned (frontmatter `version: 1.0.0`).
- **P12 (Trivia escape)** — `/interview` first-step rule (typo / 주석-only / formatting / 단일 rename / <10 토큰 + 단일 action).
- **P14 (State preservation)** — `.claude/spec-distill/<session-id>/state.local.md` (실패/abort 시 보존).
- **P17 (User sovereignty)** — `needs_interview` user confirm gate, [5] Human Review, all kill switches.
- **P18 (Stagnation detection)** — issue `raised_count ≥ 3 unresolved` 시 P18 stagnation 명시 + forced [5] escalate.
- **P21 (Secret 기록 금지)** — state.local.md token/key/credential placeholder 치환.
- **P22 (Cost class)** — 모든 skill cost_class 선언 (medium/low/medium).

### Roadmap absorption (C-numbers)

- **C43** 4-path Socratic routing (factual auto-confirm / judgment→user / ambiguity→sub-agent / ontological→5-type).
- **C44** Dialectic Rhythm Guard (env: `DEVBREW_RHYTHM_GUARD_THRESHOLD`, default 3).
- **C45** breadth-keeper agent (`disallowedTools: Write, Edit, MultiEdit, NotebookEdit`).
- **C51** 5-type ontology (ESSENCE / ROOT_CAUSE / PREREQUISITES / HIDDEN_ASSUMPTIONS / EXISTING_CONTEXT).

### Anti-pattern 회피

- **AP1 (Self-approval)** — writer/reviewer 물리적 분리 (frontmatter scoping).
- **AP2 (Polite stop)** — Phase 5 approve tail = handoff sequence (commit + pointer + cleanup), narrate-only 금지.
- **AP4 (Trivia ceremony)** — `/interview` first-step trivia escape (5 패턴).
- **AP9 (Subagent spray)** — agent 2개, breadth-keeper round당 max 1 invoke.
- **AP14 (Unchallenged consensus)** — sub-agent reviewer adversarial review. (Steelman은 plan-reviewer PR로 defer.)
- **AP16 (Unbounded autonomy)** — re-review max 3, rhythm guard 3, wall-clock 30min, kill switch.
- **AP17 (Compaction-killed facts)** — state.local.md frontmatter 보존.

## External source absorption

- **devbrother2024 deep-interview** — 4-block Korean format (현재 이해 / 막힌 결정 / 추천 답안 / 질문).
- **gstack** — Structural baseline (11 필수 섹션) + concrete-next-action refusal pattern + ETHOS ("AI recommends, users decide").
- **OMC** — env-var configurable threshold (steelman antithesis는 plan-reviewer PR로 defer, v0.2.0+ 회귀 도입).
- **superpowers** — 산출물 위치(`docs/superpowers/specs/`) + plan-document-reviewer 출력 형식 (Status / Issues / Recommendations) + brainstorming drop-in 대체.
- **Ouroboros** — inner/outer loop spirit (graph back-edges), spec lifecycle as named/versioned. (단 numerical ambiguity gate 거부, philosophy §5.3 비추천.)

## Hooks Installed

- **`UserPromptSubmit` (`interview-trigger.sh`)** — build/make/create 키워드 + 짧은 prompt 감지 시 `<spec-distill-signal>` 출력. 강제 X (advisory). **왜 skill이 아닌가**: 사용자가 명시적으로 `/interview` 안 쳐도 인터뷰 진입을 권장하려면 모든 prompt event를 가로채야 함 — skill로는 사용자 명시 호출 후에만 작동.
- **`SessionStart` (`session-anchor.sh`)** — 이전 세션 state 존재 시 anchor message 출력 (read-only, P14 mutate X). **왜 skill이 아닌가**: 세션 시작 직후 자동 표시 필요 — skill은 사용자 명시 호출 후만.

## Kill switches

- `DEVBREW_DISABLE_SPEC_DISTILL=1` — plugin 전체 abort, state 보존.
- `DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit` — UserPromptSubmit hook만 skip.
- `DEVBREW_SKIP_HOOKS=spec-distill:SessionStart` — SessionStart hook만 skip.
- `DEVBREW_RHYTHM_GUARD_THRESHOLD=N` — Dialectic Rhythm Guard threshold (default 3).
- `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN=N` — wall-clock budget (default 30 min).

## Future Roadmap

| Version | 추가 |
|---|---|
| **v0.2.0** | `drafting-plan` skill, `reviewing-plan` 별도 skill (phase별 분리), `steelman-critic` agent (spec/plan 양쪽 도입). |
| **v0.3.0** | (사용자 패턴 확인 후) `PreCompact` hook + cross-session resume. |
| **v0.4.0+** | (마찰 측정 후) reviewer high-confidence trivial revise auto-apply 토글. |
| **v1.0.0** | API 안정화 + `CHANGELOG.md` 시작. |

## Prerequisites

- **superpowers** (외부, optional) — `writing-plans` skill을 다음 단계로 호출. 없으면 spec.md만 commit하고 종료.

## License

(devbrew root 정책 따름.)
```

- [ ] **Step 2: Verify "Principles Instantiated" section exists**

```bash
grep -q "^## Principles Instantiated" plugins/spec-distill/README.md && echo "AC12 section OK"
```

Expected: `AC12 section OK`

- [ ] **Step 3: Verify Laws 1-3 cite**

```bash
for law in "Law 1" "Law 2" "Law 3"; do
  grep -q "$law" plugins/spec-distill/README.md && echo "$law OK"
done
```

Expected: 3 lines, all "OK".

- [ ] **Step 4: Verify P-numbers cite (8 expected)**

```bash
grep -cE "\*\*P(2|5|12|14|17|18|21|22)" plugins/spec-distill/README.md
```

Expected: `>= 8`

- [ ] **Step 5: Verify C-numbers cite (4 expected)**

```bash
grep -cE "\*\*C(43|44|45|51)" plugins/spec-distill/README.md
```

Expected: `>= 4`

- [ ] **Step 6: Verify AP-numbers cite (7 expected)**

```bash
grep -cE "\*\*AP(1|2|4|9|14|16|17)" plugins/spec-distill/README.md
```

Expected: `>= 7`

- [ ] **Step 7: Verify "Hooks Installed" with "왜 skill이 아닌가" rationale**

```bash
grep -c "왜 skill이 아닌가" plugins/spec-distill/README.md
```

Expected: `2` (one per hook).

- [ ] **Step 8: Commit**

```bash
git add plugins/spec-distill/README.md
git commit -m "docs(spec-distill): complete README with Principles Instantiated + Hooks rationale (AC12)"
```

---

## Task 12: Final structural verification + plugin reload

- [ ] **Step 1: V11 — README cite coverage (regex)**

```bash
grep -cE "Law [123]|P(2|5|12|14|17|18|21|22)|C(43|44|45|51)|AP(1|2|4|9|14|16|17)" plugins/spec-distill/README.md
```

Expected: `>= 22` (3 Laws + 8 P + 4 C + 7 AP).

- [ ] **Step 2: V12 — all skills declare cost_class**

```bash
for s in plugins/spec-distill/skills/*/SKILL.md; do
  grep -L "^cost_class:" "$s"
done
```

Expected: empty output.

- [ ] **Step 3: V13 — both agents have full disallowedTools**

```bash
for agent in plugins/spec-distill/agents/*.md; do
  count=$(grep -A5 "^disallowedTools:" "$agent" | grep -cE "^\s*-\s*(Write|Edit|MultiEdit|NotebookEdit)\s*$")
  echo "$agent: $count"
done
```

Expected: each line shows `: 4`.

- [ ] **Step 4: V14 — bash hooks syntax + kill switch behavior**

```bash
bash -n plugins/spec-distill/hooks/interview-trigger.sh
bash -n plugins/spec-distill/hooks/session-anchor.sh

DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit bash plugins/spec-distill/hooks/interview-trigger.sh < /dev/null
echo "trigger exit: $?"

DEVBREW_SKIP_HOOKS=spec-distill:SessionStart bash plugins/spec-distill/hooks/session-anchor.sh < /dev/null
echo "anchor exit: $?"
```

Expected: no syntax errors, both `exit: 0` with no signal output.

- [ ] **Step 5: Plugin manifest validity**

```bash
jq -e '.name == "spec-distill" and .version == "0.1.0"' plugins/spec-distill/.claude-plugin/plugin.json
jq -e '.plugins | map(.name) | contains(["spec-distill"])' .claude-plugin/marketplace.json
```

Expected: `true` x 2.

- [ ] **Step 6: File presence checklist (12 expected files)**

```bash
for f in \
  plugins/spec-distill/.claude-plugin/plugin.json \
  plugins/spec-distill/README.md \
  plugins/spec-distill/commands/interview.md \
  plugins/spec-distill/skills/conducting-interview/SKILL.md \
  plugins/spec-distill/skills/drafting-spec/SKILL.md \
  plugins/spec-distill/skills/reviewing-spec/SKILL.md \
  plugins/spec-distill/agents/breadth-keeper.md \
  plugins/spec-distill/agents/spec-reviewer.md \
  plugins/spec-distill/hooks/hooks.json \
  plugins/spec-distill/hooks/interview-trigger.sh \
  plugins/spec-distill/hooks/session-anchor.sh \
  plugins/spec-distill/templates/spec-template.md \
; do
  test -f "$f" && echo "OK $f" || echo "MISSING $f"
done
```

Expected: 12 lines, all `OK`.

- [ ] **Step 7: No CHANGELOG.md (v0.1.0 — P23)**

```bash
test ! -f plugins/spec-distill/CHANGELOG.md && echo "OK — no CHANGELOG at v0.1.0 (P23 — only required at v1.0.0+)"
```

Expected: `OK ...`

- [ ] **Step 8: Reload plugins in Claude Code**

```
/reload-plugins
```

Expected: load count includes spec-distill (e.g., "26 plugins · 23 skills · 29 agents · 16 hooks · ...").

- [ ] **Step 9: Smoke test — `/interview` command available**

Type in Claude Code:

```
/interview
```

Expected: command runs. Either:
(a) trivia escape check fires (if argument is trivia pattern), or
(b) `conducting-interview` skill prompts for first 4-block round.

- [ ] **Step 10: Final milestone commit**

```bash
git add -A
git diff --cached --quiet && echo "No staged changes (already committed)" || git commit -m "chore(spec-distill): final structural verification (V11-V14, all 12 files present)"
```

(빈 변경이면 commit 생략.)

---

## Self-Review (writing-plans skill spec)

### 1. Spec coverage (AC × Task matrix)

| AC | Implemented in | Verified by |
|---|---|---|
| AC1 (4-block first round) | Task 8 | Task 8 Step 3, Task 12 Step 9 |
| AC2 (state.local.md frontmatter + body) | Task 8 | Task 8 Step 4 |
| AC3 (11 sections + 7 frontmatter fields) | Task 2 (template), Task 9 (drafting-spec) | Task 2 Step 2-3 |
| AC4 (disallowedTools physical block) | Task 6, Task 7 | Task 6 Step 2, Task 7 Step 2, Task 12 Step 3 |
| AC5 (Status/Issues/Recommendations/Stagnation_signal) | Task 7 | Task 7 Step 3 |
| AC6 (re-review cap 3) | Task 10 | Task 10 Step 5 |
| AC7 (Stagnation_signal) | Task 7, Task 10 | Task 7 Step 3 |
| AC8 (DEVBREW_DISABLE_SPEC_DISTILL=1) | Task 4, Task 5 | Task 4 Step 5 |
| AC9 (DEVBREW_SKIP_HOOKS hook-specific) | Task 4 | Task 4 Step 6, Task 12 Step 4 |
| AC10 (trivia 5 patterns) | Task 3 | Task 3 Step 3 |
| AC11 (4-step approve handoff) | Task 10 | Task 10 Step 4 |
| AC12 (README cite Laws/P/C/AP) | Task 11 | Task 11 Step 2-7, Task 12 Step 1 |
| AC13 (breadth-keeper max 1/round) | Task 6, Task 8 | Task 8 Step 6 |
| AC14 (wall-clock budget) | Task 10 | Task 10 Step 6 |
| AC15 (deterministic routing table) | Task 10 | Task 10 Step 3 |

All 15 ACs covered. ✓

### 2. Placeholder scan

- "TBD" 단 1회 — Task 9 drafting-spec Mode A "Files to Modify" 섹션 default value (인터뷰에서 도출 못 했을 때 명시적 placeholder). 의도된 사용. ✓
- "TODO" / "implement later" / "fill in details" 없음. ✓

### 3. Type / name consistency

- `spec-distill` plugin name — plugin.json, marketplace.json, README, hooks (`spec-distill:UserPromptSubmit`, `spec-distill:SessionStart`) 모두 일치. ✓
- `disallowedTools` 4-tuple `[Write, Edit, MultiEdit, NotebookEdit]` — breadth-keeper, spec-reviewer 모두 동일. ✓
- `cost_class` values — `conducting-interview: medium`, `drafting-spec: low`, `reviewing-spec: medium`; `breadth-keeper: low`, `spec-reviewer: medium`. 일관. ✓
- File paths — Spec "Files to Modify" 12 path와 Task 12 Step 6 checklist 12 path 일치. ✓
- Env vars — `DEVBREW_DISABLE_SPEC_DISTILL`, `DEVBREW_SKIP_HOOKS`, `DEVBREW_RHYTHM_GUARD_THRESHOLD`, `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN` — 5개 hook/skill에서 일관 명명. ✓

No placeholder violations. No naming drift. Plan complete.
