---
name: spec-distill-handoff-readiness
version: 0.9.0
created_at: 2026-05-26
session_id: brainstorm-2026-05-26
status: locked
next_phase: writing-plans
source: superpowers/brainstorming (2026-05-26 세션) + spec-distill v0.8.1 현재 surface + Claude Code `/compact` 슬래시 커맨드 사양
---

# spec-distill — Handoff Readiness 디자인 스펙 (v0.9.0)

> **For agentic workers:** 본 문서는 spec-distill 플러그인 v0.9.0 마이너 업그레이드 명세이다. 두 가지 신규 surface — (a) `## Handoff Context` 섹션을 spec/design 파일에 의무화하고 spec-reviewer가 self-containedness를 검사, (b) `[5] Human Gate` "approve" 시 `approve_handoff.sh`가 사용자에게 copy-paste 가능한 `/compact` 양식과 다음 세션 첫 프롬프트를 emit. 목적은 사용자가 의도한 세션 흐름 `brainstorming → review → /compact → writing-plans → 구현`에서 `/compact` 경계를 spec lifecycle의 1급 시민으로 승격시키는 것 — Law 1 (Clarity Before Code)의 자연스러운 확장. 플러그인은 `/compact`를 *실행*하지 않고 *권장*만 한다 (built-in 슬래시 커맨드는 플러그인 surface 밖). 다음 단계는 superpowers `writing-plans` skill로 implementation plan을 생성하는 것이다.

## Handoff Context

> 이 design을 처음 보는 사람(또는 /compact 후 자기 자신)이 30초에 핵심 파악할 수 있게. 본문에 self-contained.

**TL;DR**: spec-distill v0.9.0에서 (1) spec/design 파일에 `## Handoff Context` 섹션을 의무화하고 spec-reviewer agent에 `handoff_incomplete` 검사 카테고리를 추가하여 self-containedness를 강제, (2) `approve_handoff.sh`가 `/compact` 명령 + 다음 세션 첫 프롬프트로 구성된 "Handoff packet"을 emit하여 사용자가 `/compact` 경계를 안전하게 넘게 한다.

**Implicit context** (Constraints에 안 박힌, 작업 진행에 필요한 외부 사실):
- 플러그인은 `/compact`를 직접 호출할 수 없음 (Claude Code 내장 슬래시 커맨드, 플러그인 dispatch surface 밖).
- 본 design 자체가 dogfooding — `## Handoff Context` 섹션 형식을 본 문서가 시범 사용.
- spec-distill의 design mode reviewer는 brainstorming 단계 산출물 (`*-design.md`)을 검사하지만 brainstorming skill은 외부(superpowers)이므로 spec-distill이 design.md를 *생성*하는 방식을 제어하지 못함 — `## Handoff Context` 부재 시 reviewer가 needs_revise + recommendation으로 사용자/메인 agent에게 수동 추가 요구하는 방식만 가능.

**Deferred to plan**:
- 신규 7개 테스트 파일의 정확한 fixture 구성 (스크립트 입출력 mock 방식).
- `_frontmatter_source_version()` 헬퍼 위치 (`hooks/state_path.py` vs spec-reviewer agent 내부 검사) — plan 단계에서 결정.
- README "Principles Instantiated" 라인 추가 문구 — plan/구현 단계 wording.

## 목차

- §1 [Goal](#goal)
- §2 [Context / Why](#context--why)
- §3 [Goals](#goals)
- §4 [Non-goals](#non-goals)
- §5 [Constraints](#constraints)
- §6 [Acceptance Criteria](#acceptance-criteria)
- §7 [Files to Modify](#files-to-modify)
- §8 [Verification Plan](#verification-plan)
- §9 [Rejected Alternatives](#rejected-alternatives)
- §10 [Open Questions](#open-questions)
- §11 [Concrete Next Action](#concrete-next-action)

## Goal

본 PR은 spec-distill 플러그인 v0.8.1 → **v0.9.0** 마이너 업그레이드로, *세션 경계(/compact)를 spec lifecycle의 1급 시민으로 만든다*. 단일 deliverable이며 4개 surface 패치로 구성:

- **(a) Template surface**: `templates/spec-template.md`에 `## Handoff Context` 섹션 (TL;DR / Implicit context / Deferred to plan 3개 하위 항목) 추가. `drafting-spec` Mode A가 첫 draft 시 채움.
- **(b) Reviewer surface**: `agents/spec-reviewer.md`에 `handoff_incomplete` 검사 카테고리 추가. spec mode (11→12 섹션 검사), design mode (6→7 카테고리 검사) 양쪽 모두 enforce. block-severity.
- **(c) Handoff surface**: `scripts/approve_handoff.sh` Step 2 출력 교체 — "다음 단계" 한 줄에서 3-block "Handoff packet" (compact 명령 / 다음 세션 첫 프롬프트 / divider)으로 확장. /compact 텍스트가 next-step instruction을 preserve 지시어 내부에 포함하여 compact-survival 자동화.
- **(d) Metadata surface**: `plugin.json` 0.8.1 → 0.9.0, `CHANGELOG.md` 신규 entry, `README.md` Kill switches 표 + Principles Instantiated 갱신.

## Context / Why

현재 spec-distill flow는 `[5] Human Gate "approve" → approve_handoff.sh → git commit + "다음 단계: Skill superpowers:writing-plans <path>" → cleanup` 으로 종료한다. 그러나 실사용 세션 흐름에서 사용자는 review 직후 컨텍스트가 너무 부풀어 있어 `/compact`를 수동 실행하는 것이 자연스럽다. 현재 약점 2개:

1. **Spec self-containedness 미검증**: spec-reviewer는 11 섹션 존재 / AC testability / unstated_assumption 등을 검사하지만 "이 파일만으로 /compact 이후 핸드오프가 가능한가"는 명시적 기준이 없다. spec.md 본문이 "as discussed", "the user mentioned" 같은 대화 reference를 포함해도 통과 — /compact 후 reader가 막힌다.
2. **`/compact` 권장 부재**: 사용자가 `/compact`를 실행할 때 *무엇을 보존하고 무엇을 drop할지* 정해야 하지만 현재 핸드오프 시점에 가이드가 없다. 잘못 작성된 `/compact` 명령은 spec 본문 일부를 잃을 수 있다.

본 PR은 두 약점을 동시에 닫는다 — (1)은 reviewer 검사 강화로, (2)는 approve_handoff.sh 출력 확장으로. Coupling 근거: (1) 없이 (2)만 도입하면 자체로 부족한 spec을 /compact 권장으로 보내게 됨. (2) 없이 (1)만 도입하면 self-contained spec을 사용자가 임의 /compact 텍스트로 보내 일부 손실 위험. 두 surface가 한 묶음일 때만 *살아있는 핸드오프 baseline*이 성립.

devbrew 철학 정렬:
- **Law 1**: handoff readiness ≡ spec self-containedness ≡ "코드보다 명세 먼저"의 자연스러운 강한 적용.
- **Law 3 (Compounding)**: /compact가 대화 컨텍스트를 drop해도 spec.md (named, versioned, diff-able artifact, P5) 안에 모든 결정이 보존됨이 보장 — 미래 세션이 실제로 spec만 가지고 work 재개 가능.
- **default to lightness** (CLAUDE.md): 신규 agent 없이 기존 spec-reviewer 확장 — AP9 (subagent spray) 회피.

## Goals

- **G1**: spec-reviewer agent가 `handoff_incomplete` 카테고리를 spec mode + design mode 양쪽에서 block-severity로 검사. 위반 패턴 4종 정의됨 (섹션 부재 / 하위 항목 비어있음 / conversation reference 검출 / TL;DR이 Goal 복붙).
- **G2**: `## Handoff Context` 섹션이 `templates/spec-template.md`에 의무 섹션으로 추가됨. TL;DR / Implicit context / Deferred to plan 3개 하위 항목 명시.
- **G3**: `approve_handoff.sh` Step 2가 "Handoff packet" 3-block 출력 (compact 명령 / 다음 세션 첫 프롬프트 / divider) 형식으로 emit. /compact 명령 텍스트는 next-step instruction을 preserve 지시어에 embed.
- **G4**: `DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK=1` kill switch가 `handoff_incomplete` 카테고리만 우회. 다른 검사는 정상 동작. loud warning 출력.
- **G5**: Pre-v0.9.0 spec.md (frontmatter `source: spec-distill v0.8.x` 이하)는 grandfather — `handoff_incomplete` 검사 skip + one-shot advisory.
- **G6**: `plugin.json` 0.8.1 → 0.9.0 bump, CHANGELOG/README 동기화.
- **G7**: 7개 신규 회귀 방지 테스트 (tests/) 추가.

## Non-goals

- **NG1**: `/compact` 슬래시 커맨드 실행 자동화 — 플러그인 dispatch surface 밖. 권장만 한다.
- **NG2**: sidecar handoff 파일 (`<spec>.next.md` 등) 생성. 콘솔 emit으로 충분 — /compact 명령 내부에 next-step instruction을 박는 트릭으로 compact-survival 보장.
- **NG3**: brainstorming skill (superpowers) 자체 수정. design.md를 *생성*하는 책임은 외부이며 spec-distill은 *검사*만 한다.
- **NG4**: writing-plans skill 변경. /compact 후 writing-plans 진입은 superpowers 측이 처리.
- **NG5**: in-flight 진행 중인 v0.8.x 세션의 state.local.md schema migration. v0.9.0은 *신규* 작성되는 spec/design에만 enforce.
- **NG6**: spec-reviewer가 대화 history에 접근하여 "대화엔 있는데 spec엔 없는 것"을 검사 — agent는 파일만 본다 (Law 2 disallowedTools). 검사는 *파일 안의 signal* (placeholder/conversation reference/empty section)에 한정.

## Constraints

- **C1**: spec-reviewer agent의 `disallowedTools: Write, Edit, MultiEdit, NotebookEdit` 유지 (Law 2 frontmatter scoping). 검사 추가지 권한 변경 아님.
- **C2**: 신규 카테고리는 기존 issue_id 알고리즘 (`sha256_short(category + ":" + target_section)`) 그대로 사용. target_section은 `#handoff-context`.
- **C3**: 신규 카테고리는 기존 re-review cap (max 5) 안에서 계산됨 — 별도 cap 두지 않음.
- **C4**: `approve_handoff.sh` emit 실패 (printf/echo 실패, 극히 드문 케이스)는 commit 후이므로 exit 0 + advisory only. 핸드오프 전체 실패시키지 않음.
- **C5**: kill switch `DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK=1` 사용 시 reviewer는 stderr에 loud warning "handoff readiness 검증 비활성화 — /compact 이후 정보 손실 risk" 출력.
- **C6**: design mode에서 `handoff_incomplete` 위반 시 routing은 기존 `design + needs_revise + count < 5` 행 그대로 — "brainstorming author 회귀" (메인 agent가 design.md 직접 수정). 신규 routing 행 추가 없음.
- **C7**: 모든 검사 패턴(대화 reference regex 등)은 reviewer prompt 안에서 정의 — 별도 shared config 파일 안 만든다 (default to lightness).

## Acceptance Criteria

- **AC1**: `templates/spec-template.md`를 읽어 `## Handoff Context`, `**TL;DR**`, `**Implicit context**`, `**Deferred to plan**` 4개 문자열이 모두 존재함을 grep으로 확인 가능.
- **AC2**: `tests/test_handoff_context_section_required.sh` — `## Handoff Context` 섹션이 없는 spec.md fixture를 reviewer에 dispatch 시 `handoff_incomplete` issue가 Issues 블록에 포함됨.
- **AC3**: `tests/test_handoff_context_empty_subsections.sh` — TL;DR/Implicit/Deferred 중 하나라도 빈 fixture에서 `handoff_incomplete` issue emit.
- **AC4**: `tests/test_conversation_reference_detection.sh` — spec 본문에 "as discussed", "we talked about", "위에서 논의한", "방금 결정한", "the user mentioned" 중 하나라도 포함된 fixture에서 `handoff_incomplete` issue emit.
- **AC5**: `tests/test_handoff_context_tldr_dup.sh` — TL;DR이 Goal 섹션 본문과 동일한 (normalize whitespace 후 exact match) fixture에서 `handoff_incomplete` issue emit.
- **AC6**: `tests/test_approve_handoff_packet_emit.sh` — `approve_handoff.sh <session_id> <spec_path>` stdout이 (a) `===== spec-distill handoff packet =====` divider, (b) `/compact spec at` 으로 시작하는 라인, (c) `Skill superpowers:writing-plans` 라인을 모두 포함.
- **AC7**: `tests/test_handoff_kill_switch.sh` — `DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK=1` 환경에서 reviewer dispatch 시 `handoff_incomplete` issue 없음 + stderr에 "handoff readiness 검증 비활성화" 문자열 포함.
- **AC8**: `tests/test_grandfather_pre_v090_specs.sh` — frontmatter `source: spec-distill v0.8.x` (또는 v0.7.x, v0.6.x 등) 인 fixture에서 `handoff_incomplete` issue 없음 + stderr/advisory 출력.
- **AC9**: `tests/test_handoff_design_mode.sh` — design.md 형식 fixture (frontmatter `locked_decisions` 부재, `## Handoff Context` 없음)에서 `handoff_incomplete` issue emit (design mode 7번째 카테고리로 작동 확인).
- **AC10**: `plugin.json` `version` 필드가 `"0.9.0"`.
- **AC11**: `CHANGELOG.md`에 `## [0.9.0] — 2026-05-26` 섹션 존재, Added/Changed 하위 항목 포함.
- **AC12**: `README.md` Kill switches 섹션에 `DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK=1` 행 추가.

## Files to Modify

```
plugins/spec-distill/.claude-plugin/plugin.json       # version 0.8.1 → 0.9.0
plugins/spec-distill/templates/spec-template.md       # 신규 ## Handoff Context 섹션, source 기본값 v0.9.0
plugins/spec-distill/agents/spec-reviewer.md          # handoff_incomplete 카테고리 (spec+design), grandfather logic
plugins/spec-distill/scripts/approve_handoff.sh       # Step 2 출력 → 3-block Handoff packet
plugins/spec-distill/README.md                        # Kill switches 표, Phase 5 설명, Principles Instantiated
plugins/spec-distill/CHANGELOG.md                     # [0.9.0] — 2026-05-26 entry

plugins/spec-distill/tests/test_handoff_context_section_required.sh    # AC2
plugins/spec-distill/tests/test_handoff_context_empty_subsections.sh   # AC3
plugins/spec-distill/tests/test_conversation_reference_detection.sh    # AC4
plugins/spec-distill/tests/test_handoff_context_tldr_dup.sh            # AC5
plugins/spec-distill/tests/test_approve_handoff_packet_emit.sh         # AC6
plugins/spec-distill/tests/test_handoff_kill_switch.sh                 # AC7
plugins/spec-distill/tests/test_grandfather_pre_v090_specs.sh          # AC8
plugins/spec-distill/tests/test_handoff_design_mode.sh                 # AC9
```

## Verification Plan

- **V1**: `bash plugins/spec-distill/tests/test_handoff_*.sh` — 7개 신규 테스트 모두 통과.
- **V2**: `bash plugins/spec-distill/tests/test_approve_handoff_packet_emit.sh` — handoff packet 3-block 출력 확인.
- **V3**: `bash plugins/spec-distill/tests/test_grandfather_pre_v090_specs.sh` — 이전 버전 spec backward compat.
- **V4**: 기존 테스트 회귀 — `bash plugins/spec-distill/tests/test_*.sh` 전체 실행, 모두 통과.
- **V5**: 수동 dogfood — 본 design.md 자체를 spec-distill reviewing-spec skill에 dispatch (v0.9.0 빌드 후), `handoff_incomplete` 검사가 `## Handoff Context` 존재로 통과함을 확인. self-validation.
- **V6**: `jq -r '.version' plugins/spec-distill/.claude-plugin/plugin.json` → `0.9.0`.
- **V7**: `grep -q "0.9.0" plugins/spec-distill/CHANGELOG.md` → exit 0.

## Rejected Alternatives

- **R1 — 신규 `handoff-verifier` agent**: 별도 agent 파일로 검사 책임 분리. **거절**: AP9 (subagent spray) risk, devbrew "default to lightness" 위배. handoff readiness는 spec quality와 orthogonal하지 않음 — 신규 agent 정당화 부족.
- **R2 — reviewing-spec skill 안에서 spec-reviewer 두 번 dispatch (general review + handoff-only)**: approved 직후 별도 handoff dispatch. **거절**: dispatch cost 2배, re-review cap 계산 복잡, AP14 ceremony 패턴.
- **R3 — sidecar `<spec>.next.md` 파일 생성**: handoff packet을 git-tracked 파일로 보존. **거절**: 추가 파일 surface 증가, /compact 명령에 next-step instruction을 embed하는 트릭으로 compact-survival 이미 보장됨. v0.10.0에서 사용자 피드백 보고 재검토.
- **R4 — `## Handoff Context` 대신 frontmatter 필드로 (`handoff_context: ...`)**: YAML 안에 텍스트 박기. **거절**: multi-paragraph 텍스트는 markdown 본문이 자연스러움, frontmatter는 키-값 메타데이터에 한정 (P5).
- **R5 — Conversation reference 검출 패턴을 별도 config 파일로**: `templates/ambiguity-blacklist.txt` 처럼 외부화. **거절**: 패턴 5–7개 수준, reviewer prompt 안 정의가 가장 명확 (C7).

## Open Questions

- **OQ1**: `_frontmatter_source_version()` 헬퍼 (grandfather 판정용) 위치 — `hooks/state_path.py` 추가 vs spec-reviewer agent 안 inline shell? plan 단계에서 결정. (현재 agent는 Bash 권한이 있으므로 inline grep으로 frontmatter `source:` 라인 파싱 가능 — agent inline이 더 간단할 수 있음.)
- **OQ2**: `## Handoff Context` 섹션 위치 — 11개 기존 섹션 어디 사이에 넣을지? 제안: `## Goal` 바로 다음 (가장 가시적이고 reader가 먼저 본다). 또는 `## Concrete Next Action` 직전 (handoff 의미 그룹). plan에서 확정.
- **OQ3**: `tests/test_handoff_design_mode.sh` fixture 생성 방식 — design.md를 임시 파일로 생성 후 reviewer 직접 dispatch vs 기존 design-mode 테스트 패턴 답습? 후자가 일관성↑. plan에서 패턴 비교.

## Concrete Next Action

다음 단계: `Skill superpowers:writing-plans docs/superpowers/specs/2026-05-26-spec-distill-handoff-readiness-design.md`.

- Spec 경로: `docs/superpowers/specs/2026-05-26-spec-distill-handoff-readiness-design.md`
- Plan 산출물: `docs/superpowers/plans/2026-05-26-spec-distill-handoff-readiness.md`
- 명령: `Skill superpowers:writing-plans <this file>`
- 구현 worktree: writing-plans 후 implementation 진입 직전 `Skill superpowers:using-git-worktrees` invoke (브랜치 명 제안: `feature/spec-distill-handoff-readiness`).
