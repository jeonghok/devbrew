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
                    ├─ needs_revise (all unlocked) → [4]
                    ├─ needs_revise (any locked) → [3.5] Re-consensus  ← v0.2.0
                    │       ├─ (1) 수용 → [4] with allowed_issue_ids
                    │       ├─ (2) 유지 → [3] re-dispatch (dismissed)
                    │       └─ (3) 추가 인터뷰 → [1]
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
- **Law 2 강화 (v0.3.0)** — Writer/Reviewer 분리를 turn-boundary 결정론으로 끌어올림. PostToolUse가 spec/design write를 감지해 *해당 turn 안* structural gate를 차단(exit 2)하고, Stop hook이 *다음 turn 첫 액션*으로 reviewer dispatch를 systemMessage 주입으로 강제. file-based ledger (`state.local.md` `pending_review:` block)가 trans-hook coordination을 LLM 의지에서 분리.
- **Law 2 (Writer/Reviewer Never Share a Pass) — infrastructure operability**: spec-reviewer agent의 writer/reviewer 물리 분리가 의미를 가지려면 reviewer dispatch가 Claude context에 *실제로* 도달해야 한다. v0.5.0의 dual-target output fix가 이 baseline을 보장. dispatch가 silent하게 lost되면 reviewer persona 분리 자체가 무의미.
- **Law 3 (Compounding)** — spec.md 파일 자체가 named, versioned, diff-able artifact (P5). state.local.md 보존 (실패 시) → 디버깅 + future session 추적.
- **Law 3 (Every Cycle Must Leave the System Smarter)**: v0.5.0 PR이 hook 코드 fix + `tests/test_hook_output_schema.py` 회귀 방지 test + CHANGELOG 명시 + design.md (`docs/superpowers/specs/2026-05-17-spec-distill-hook-context-injection-design.md`) — 4-layer compounding 흔적. 같은 클래스의 silent-output mistake가 미래에 들어오면 CI에서 즉시 잡힘.

### Principles 흡수

- **P2 (Ambiguity Gate)** — 구조적 (필수 11 섹션) default, numerical 거부 (philosophy §5.3).
- **P5 (Spec as artifact)** — `docs/superpowers/specs/...spec.md` named, versioned (frontmatter `version: 1.0.0`).
- **P12 (Trivia escape)** — `/interview` first-step rule (typo / 주석-only / formatting / 단일 rename / <10 토큰 + 단일 action).
- **P14 (State preservation)** — `.claude/spec-distill/<session-id>/state.local.md` (실패/abort 시 보존).
- **P17 (User sovereignty)** — `needs_interview` user confirm gate, [5] Human Review, all kill switches.
- **P17 (User sovereignty) — locked_decisions 추적 + [3.5] Re-consensus gate** — 인터뷰 합의가 writer/reviewer 페어에 의해 사용자 동의 없이 뒤집히는 것을 frontmatter-level로 차단. (v0.2.0)
- **P18 (Stagnation detection)** — issue `raised_count ≥ 3 unresolved` 시 P18 stagnation 명시 + forced [5] escalate.
- **P21 (Secret 기록 금지)** — state.local.md token/key/credential placeholder 치환.
- **P22 (Cost class)** — 모든 skill cost_class 선언 (medium/low/medium).
- **§4.8 worktree path convention**: state 파일 위치를 `state_path.state_root()`로 단일화하여 worktree 호출 시에도 main repo `.claude/spec-distill/`에만 기록 — `ExitWorktree action: remove` 시 pending_review state silent loss 차단.

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
- **AP16 (Unbounded autonomy)** — re-review max 5 (hybrid policy, v0.3.0: hard cap + stagnation early-exit), rhythm guard 3, wall-clock 30min, kill switch.
- **AP17 (Compaction-killed facts)** — state.local.md frontmatter 보존.

## External source absorption

- **devbrother2024 deep-interview** — 4-block Korean format (현재 이해 / 막힌 결정 / 추천 답안 / 질문).
- **gstack** — Structural baseline (11 필수 섹션) + concrete-next-action refusal pattern + ETHOS ("AI recommends, users decide").
- **OMC** — env-var configurable threshold (steelman antithesis는 plan-reviewer PR로 defer, v0.2.0+ 회귀 도입).
- **superpowers** — 산출물 위치(`docs/superpowers/specs/`) + plan-document-reviewer 출력 형식 (Status / Issues / Recommendations) + brainstorming drop-in 대체.
- **Ouroboros** — inner/outer loop spirit (graph back-edges), spec lifecycle as named/versioned. (단 numerical ambiguity gate 거부, philosophy §5.3 비추천.)

## Hooks Installed

| Event | Script | 책임 | 왜 skill이 아닌가 |
|---|---|---|---|
| UserPromptSubmit | `hooks/interview-trigger.sh` | vague build/make 요청 감지 → advisory | 사용자 자동 prompt에 반응해야 함 (skill은 사용자가 invoke해야 동작). |
| SessionStart | `hooks/session-anchor.sh` | resumed session에 spec-distill anchor 표시 | session-level lifecycle event는 hook 전용. |
| PostToolUse | `hooks/spec-write-validator.py` | spec/design 파일 write 시 mechanical Layer 1 검증 + `pending_review:` ledger 기록 (v0.3.0) | spec writer가 *자기 작업을 자기가 검증*하는 회색지대를 file-system level에서 가로채는 것이 Law 2의 가장 강력한 구현. skill은 LLM이 invoke해야 동작하므로 trigger 결정론이 부족함. |
| Stop | `hooks/review-dispatch.py` | `pending_review:` block 있으면 systemMessage 주입으로 reviewer dispatch 강제 (v0.3.0) | turn boundary는 LLM의 메시지 형식과 무관한 결정론적 지점 — skill로는 hit 불가. |
| UserPromptSubmit | `hooks/pending-review-reminder.py` | pending_review가 살아있고 TTL 만료 시 mandate 재emit (L4b redundancy). TTL(30s) 가드로 spam 방지. Kill switch: `DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit` / `:reminder`. | Stop hook single-shot mandate가 next-turn에서 silent drop될 경우 매 user prompt에 mandate 재emit하는 redundancy layer 필요 — turn boundary 이벤트라 skill로 처리 불가. |

**Output schema (v0.5.0+):** 모든 hook이 *dual-target output* 패턴 — Claude-target field (`hookSpecificOutput.additionalContext` for PostToolUse/UserPromptSubmit/SessionStart, `decision:"block" + reason` for Stop) + `systemMessage` (짧은 흔적, ≤120자, `[spec-distill]` prefix). Claude는 context로 dispatch 메시지를 받고, user는 transcript에서 hook 발화 흔적을 확인 가능. 이전 (`v0.4.0` 이하) 의 `systemMessage`-only 출력은 user transcript에는 보였으나 Claude LLM context로 inject되지 않는 silent failure였음 — `v0.5.0`에서 fix. Reference 패턴: `plugins/quality-gates/hooks/stop-hook.py:845-849`.

## Kill switches

- `DEVBREW_DISABLE_SPEC_DISTILL=1` — plugin 전체 abort, state 보존.
- `DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit` — UserPromptSubmit hook만 skip.
- `DEVBREW_SKIP_HOOKS=spec-distill:SessionStart` — SessionStart hook만 skip.
- `DEVBREW_RHYTHM_GUARD_THRESHOLD=N` — Dialectic Rhythm Guard threshold (default 3).
- `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN=N` — wall-clock budget (default 30 min).
- `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS=1` (v0.2.0) — [3.5] Re-consensus gate 우회. **loud warning**: locked decisions 보호 비활성화 — 사용자 sovereignty 약화 위험.
- `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1` (v0.3.0) — PostToolUse Layer 1 (structural check) 정상 동작, Layer 2 (`pending_review:` ledger 기록) skip. 비상시 reviewer dispatch cost 회피용.
- `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` (v0.3.0) — `-design.md` 파일에 대한 hook 처리 전체 skip. brainstorming 산출물 review를 일시 정지하고 싶을 때.
- `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=<int>` (v0.3.0) — Stop hook redispatch TTL guard (default 30초). spec self-reference cycle 방지용. plan phase에서 default 값 재검토.
- `DEVBREW_SKIP_HOOKS=spec-distill:PostToolUse` (alias: `spec-distill:validator`) — PostToolUse hook만 skip.
- `DEVBREW_SKIP_HOOKS=spec-distill:Stop` (alias: `spec-distill:review-dispatch`) — Stop hook만 skip.

## Prerequisites

- **Claude Code built-in `general-purpose` agent** — 항상 사용 가능 (별도 설치 불필요). `conducting-interview` skill의 C43 ambiguity path가 dispatch.
- **`jq`** (CLI, recommended) — hook 스크립트가 stdin JSON payload 파싱과 `{"systemMessage": "..."}` JSON 출력에 사용. 없으면 regex fallback + loud warning (devbrew "loud-logging graceful degradation").
- **superpowers** (외부, optional) — `writing-plans` skill을 다음 단계로 호출. 없으면 spec.md만 commit하고 종료.

## License

(devbrew root 정책 따름.)
