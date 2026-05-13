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
- **Law 3 (Compounding)** — spec.md 파일 자체가 named, versioned, diff-able artifact (P5). state.local.md 보존 (실패 시) → 디버깅 + future session 추적.

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

- **`UserPromptSubmit` (`interview-trigger.sh`)** — build/make/create 키워드 + 짧은 prompt 감지 시 `{"systemMessage": "..."}` JSON 출력 (Claude Code hook protocol — quality-gates Python hook과 동일). 강제 X (advisory). **왜 skill이 아닌가**: 사용자가 명시적으로 `/interview` 안 쳐도 인터뷰 진입을 권장하려면 모든 prompt event를 가로채야 함 — skill로는 사용자 명시 호출 후에만 작동.
- **`SessionStart` (`session-anchor.sh`)** — 이전 세션 state 존재 시 `{"systemMessage": "..."}` JSON 출력 (read-only, P14 mutate X). **왜 skill이 아닌가**: 세션 시작 직후 자동 표시 필요 — skill은 사용자 명시 호출 후만.

## Kill switches

- `DEVBREW_DISABLE_SPEC_DISTILL=1` — plugin 전체 abort, state 보존.
- `DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit` — UserPromptSubmit hook만 skip.
- `DEVBREW_SKIP_HOOKS=spec-distill:SessionStart` — SessionStart hook만 skip.
- `DEVBREW_RHYTHM_GUARD_THRESHOLD=N` — Dialectic Rhythm Guard threshold (default 3).
- `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN=N` — wall-clock budget (default 30 min).
- `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS=1` (v0.2.0) — [3.5] Re-consensus gate 우회. **loud warning**: locked decisions 보호 비활성화 — 사용자 sovereignty 약화 위험.

## Future Roadmap

| Version | 추가 |
|---|---|
| **v0.2.0** | `drafting-plan` skill, `reviewing-plan` 별도 skill (phase별 분리), `steelman-critic` agent (spec/plan 양쪽 도입). |
| **v0.3.0** | (사용자 패턴 확인 후) `PreCompact` hook + cross-session resume. |
| **v0.4.0+** | (마찰 측정 후) reviewer high-confidence trivial revise auto-apply 토글. |
| **v1.0.0** | API 안정화 + `CHANGELOG.md` 시작. |

## Prerequisites

- **Claude Code built-in `general-purpose` agent** — 항상 사용 가능 (별도 설치 불필요). `conducting-interview` skill의 C43 ambiguity path가 dispatch.
- **`jq`** (CLI, recommended) — hook 스크립트가 stdin JSON payload 파싱과 `{"systemMessage": "..."}` JSON 출력에 사용. 없으면 regex fallback + loud warning (devbrew "loud-logging graceful degradation").
- **superpowers** (외부, optional) — `writing-plans` skill을 다음 단계로 호출. 없으면 spec.md만 commit하고 종료.

## License

(devbrew root 정책 따름.)
