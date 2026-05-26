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
- `/compact` 명령에 박은 next-step instruction이 compact 결과에 보존된다는 보장은 *없음* (Claude Code `/compact` 동작은 공식 사양 외 구현 detail에 의존). 따라서 [1] /compact 권장은 *best-effort* — 사용자의 [2] 다음 세션 첫 프롬프트가 진짜 안전망.

**Deferred to plan**:
- 신규 6개 테스트 파일의 정확한 fixture 구성 (스크립트 입출력 mock 방식).
- README "Principles Instantiated" 라인 추가 문구 — plan/구현 단계 wording.
- `hooks/state_path.py` 헬퍼 위치 여부 — 본 PR은 helper 신설 없이 reviewer agent 안 inline grep만 사용 (default to lightness).

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

- **G1**: spec-reviewer agent가 `handoff_incomplete` 카테고리를 spec mode + design mode 양쪽에서 block-severity로 검사. 위반 패턴 **3종** 정의됨 (섹션 부재 / 하위 항목 비어있음 / conversation reference 검출). TL;DR이 Goal 복붙 검출은 NG7/R7으로 v0.9.0 범위 제외.
- **G2**: `## Handoff Context` 섹션이 `templates/spec-template.md`에 의무 섹션으로 추가됨. TL;DR / Implicit context / Deferred to plan 3개 하위 항목 명시.
- **G3**: `approve_handoff.sh` Step 2가 "Handoff packet" 3-block 출력 (compact 명령 / 다음 세션 첫 프롬프트 / divider) 형식으로 emit. /compact 명령 텍스트는 next-step instruction을 preserve 지시어에 embed하되 *best-effort* — 진짜 안전망은 [2] 다음 세션 첫 프롬프트 라인이며 사용자가 /compact 후 그것을 복사하면 항상 동작.
- **G4**: `DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK=1` kill switch가 `handoff_incomplete` 카테고리만 우회. 다른 검사는 정상 동작. loud warning 출력.
- **G5**: `plugin.json` 0.8.1 → 0.9.0 bump, CHANGELOG/README 동기화.
- **G6**: 6개 신규 회귀 방지 테스트 (tests/) 추가.

(이전 G5 "grandfather pre-v0.9.0 spec.md" 항목은 R6에서 거절 — `source:` 필드 비정형 파싱 hole과 schema 복잡도 대비 이득 부족.)

## Non-goals

- **NG1**: `/compact` 슬래시 커맨드 실행 자동화 — 플러그인 dispatch surface 밖. 권장만 한다.
- **NG2**: sidecar handoff 파일 (`<spec>.next.md` 등) 생성. 콘솔 emit으로 충분 — /compact 명령 내부에 next-step instruction을 박는 트릭으로 compact-survival best-effort 지원 (Implicit context 참조 — 진짜 안전망은 [2] 다음 세션 첫 프롬프트 라인의 사용자 복사).
- **NG3**: brainstorming skill (superpowers) 자체 수정. design.md를 *생성*하는 책임은 외부이며 spec-distill은 *검사*만 한다.
- **NG4**: writing-plans skill 변경. /compact 후 writing-plans 진입은 superpowers 측이 처리.
- **NG5**: in-flight 진행 중인 v0.8.x 세션의 state.local.md schema migration. v0.9.0은 *신규* 작성되는 spec/design에만 enforce.
- **NG6**: spec-reviewer가 대화 history에 접근하여 "대화엔 있는데 spec엔 없는 것"을 검사 — agent는 파일만 본다 (Law 2 disallowedTools). 검사는 *파일 안의 signal* (placeholder/conversation reference/empty section)에 한정.
- **NG7**: TL;DR이 Goal과 동일/유사한지 검출 — v0.9.0에선 surface 축소를 위해 보류. LLM 판단 deterministic 검증 어려움 (R5 참조), v0.10.0+ defer.
- **NG8**: pre-v0.9.0 spec.md grandfather 처리 — `source:` 필드 비정형 파싱 hole 때문에 v0.9.0에서 제외 (R6). 기존 spec 재review 시 30초 분량 수동 Handoff Context 추가 필요 (CHANGELOG/README 안내).

## Constraints

- **C1**: spec-reviewer agent의 `disallowedTools: Write, Edit, MultiEdit, NotebookEdit` 유지 (Law 2 frontmatter scoping). 검사 추가지 권한 변경 아님.
- **C2**: 신규 카테고리는 기존 issue_id 알고리즘 (`sha256_short(category + ":" + target_section)`) 그대로 사용. target_section은 `#handoff-context`.
- **C3**: 신규 카테고리는 기존 re-review cap (max 5) 안에서 계산됨 — 별도 cap 두지 않음.
- **C4**: `approve_handoff.sh` emit 실패 (printf/echo 실패, 극히 드문 케이스)는 commit 후이므로 exit 0 + advisory only. 핸드오프 전체 실패시키지 않음.
- **C5**: kill switch `DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK=1` 사용 시 reviewer는 stderr에 loud warning "handoff readiness 검증 비활성화 — /compact 이후 정보 손실 risk" 출력.
- **C6**: design mode에서 `handoff_incomplete` 위반 시 routing은 기존 `design + needs_revise + count < 5` 행 그대로 — "brainstorming author 회귀" (메인 agent가 design.md 직접 수정). 신규 routing 행 추가 없음.
- **C7**: 모든 검사 패턴(대화 reference regex 등)은 reviewer prompt 안에서 정의 — 별도 shared config 파일 안 만든다 (default to lightness).
- **C8 (conversation reference 패턴, v0.9.0 확정 집합)**: 검사 대상은 다음 **15개** substring (case-insensitive, normalize whitespace 후 매칭) — 영어 8개: `"as discussed"`, `"as we agreed"`, `"we talked about"`, `"the user mentioned"`, `"you mentioned"`, `"as mentioned before"`, `"per our discussion"`, `"earlier in this session"`; 한국어 7개: `"위에서 논의한"`, `"위에서 언급한"`, `"방금 결정한"`, `"아까 결정한"`, `"이전에 말했듯이"`, `"언급하셨던"`, `"말씀하신"`. **선정 근거**: spec-distill 운영 중 review iter에서 등장한 actual conversation reference 표현 + 영어/한국어 대칭 (각 언어의 가장 흔한 "지시 대명사 + 동사" 형태) — exhaustive 보장 아니라 *high-precision baseline*. 누락된 패턴이 발견되면 v0.10.0+ 별도 PR로 list 확장 (reviewer prompt 안 list에 라인 추가만 필요, 인프라 변경 없음). 본 v0.9.0 집합은 reviewer prompt + AC4 fixture + test에서 동일 사용.
- **C9 (4-surface dependency graph)**: 단일 v0.9.0 PR 내 task 순서 — (a) template 수정 → (b) reviewer agent에 카테고리 추가 (a의 섹션 anchor 참조) → (c) approve_handoff.sh 출력 교체 (병렬 가능, build-time은 (a)/(b)와 독립) → (d) plugin.json/CHANGELOG/README (마지막). (a)와 (b)는 fixture-reviewer 정합성 때문에 같은 PR이어야 함 (AC2–4 테스트가 둘 다 필요); (d)는 항상 마지막. **(c)의 runtime 의존성 주의**: approve_handoff.sh가 출력하는 `/compact` preserve directive는 `"Handoff Context"`, `"Acceptance Criteria"` 등 section name을 hardcode — pre-v0.9.0 spec에 대해 스크립트를 실행하면 존재하지 않는 섹션을 보존하라는 지시어가 나간다 (vacuous, 무해하지만 noise). (c)의 hardcoded section name은 (a)의 template과 의미적 coupling을 가지며 두 surface 간 section name drift 시 동시 갱신 필요.

## Acceptance Criteria

- **AC1**: `templates/spec-template.md`를 읽어 `## Handoff Context`, `**TL;DR**`, `**Implicit context**`, `**Deferred to plan**` 4개 문자열이 모두 존재함을 grep으로 확인 가능. 섹션 위치는 `## Goal` 직후, `## Context / Why` 직전 (OQ2 resolve).
- **AC2**: `tests/test_handoff_context_section_required.sh` — `## Handoff Context` 섹션이 없는 spec.md fixture를 reviewer에 dispatch 시 `handoff_incomplete` issue가 Issues 블록에 포함됨.
- **AC3**: `tests/test_handoff_context_empty_subsections.sh` — TL;DR/Implicit/Deferred 중 하나라도 빈 fixture에서 `handoff_incomplete` issue emit.
- **AC4**: `tests/test_handoff_conversation_reference.sh` — spec 본문에 C8의 15개 패턴 각각에 대해 1개 fixture씩 (총 15개 fixture or table-driven) 검증 — 각 fixture에서 `handoff_incomplete` issue emit.
- **AC5**: `tests/test_handoff_approve_packet_emit.sh` — `approve_handoff.sh <session_id> <spec_path>` stdout이 다음 *모두* 포함:
  - (a) divider 라인 `===== spec-distill handoff packet =====` 정확 매치.
  - (b) `/compact ` 으로 시작하는 라인 (leading whitespace 무관), 해당 라인 본문에 `<spec_path>` substring + `Handoff Context` + `Acceptance Criteria` + `Files to Modify` 모두 포함 (preserve directive 본문 검증, full section name으로 false-positive 회피).
  - (c) 동일 `/compact` 라인 안에 `drop` 또는 `버리` substring (drop directive 검증).
  - (d) 동일 `/compact` 라인 또는 같은 block 안에 `Skill superpowers:writing-plans <spec_path>` substring (next-step embed 검증).
  - (e) [2] block에 별도로 `Skill superpowers:writing-plans <spec_path>` 라인 (안전망 검증).
  - (f) divider 종료 라인 (`====...===` 8+ 문자).
- **AC6**: `tests/test_handoff_kill_switch.sh` — `DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK=1` 환경에서 reviewer dispatch 시 `handoff_incomplete` issue 없음 + stderr에 "handoff readiness 검증 비활성화" 문자열 포함.
- **AC7**: `tests/test_handoff_design_mode.sh` — design.md 형식 fixture (frontmatter `locked_decisions` 부재, `## Handoff Context` 없음)에서 `handoff_incomplete` issue emit (design mode 7번째 카테고리로 작동 확인).
- **AC8**: `plugin.json` `version` 필드가 `"0.9.0"`.
- **AC9**: `CHANGELOG.md`에 `## [0.9.0] — 2026-05-26` 섹션 존재, Added/Changed 하위 항목 포함, `Removed: grandfather logic from initial draft` advisory 또는 NG8 참조 포함.
- **AC10**: `README.md` Kill switches 섹션에 `DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK=1` 행 추가.

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
plugins/spec-distill/tests/test_handoff_conversation_reference.sh      # AC4 (15 fixtures / table-driven)
plugins/spec-distill/tests/test_handoff_approve_packet_emit.sh         # AC5
plugins/spec-distill/tests/test_handoff_kill_switch.sh                 # AC6
plugins/spec-distill/tests/test_handoff_design_mode.sh                 # AC7

# 모든 신규 테스트 파일은 `test_handoff_*.sh` prefix로 통일 — V1 glob 일관성 (round 2 fix).
```

## Verification Plan

- **V1**: `bash plugins/spec-distill/tests/test_handoff_*.sh` — 6개 신규 테스트 모두 통과 (모두 `test_handoff_*` prefix이므로 glob 포착 — round 2 round-tested).
- **V2**: `bash plugins/spec-distill/tests/test_handoff_approve_packet_emit.sh` — handoff packet 6개 sub-assertion (AC5 a–f) 모두 통과.
- **V3**: 기존 테스트 회귀 — `bash plugins/spec-distill/tests/test_*.sh` 전체 실행, 모두 통과.
- **V4 (positive dogfood)**: 본 design.md 자체를 spec-distill reviewing-spec skill에 dispatch (v0.9.0 빌드 후). `## Handoff Context` 존재 + 비어있지 않음 + conversation reference 패턴 부재 → `handoff_incomplete` issue 없음 확인.
- **V5 (negative dogfood)**: 본 design.md의 `## Handoff Context` 섹션을 임시 제거한 사본을 reviewing-spec skill에 dispatch (v0.9.0 빌드 후). `handoff_incomplete` issue가 emit되어야 함 — reviewer가 카테고리를 항상 skip하는 silent-fail 회귀 차단. (test_handoff_design_mode.sh와 fixture는 다르지만 같은 카테고리 검증.)
- **V6**: `jq -r '.version' plugins/spec-distill/.claude-plugin/plugin.json` → `0.9.0`.
- **V7**: `grep -q "0.9.0" plugins/spec-distill/CHANGELOG.md` → exit 0.

## Rejected Alternatives

- **R1 — 신규 `handoff-verifier` agent**: 별도 agent 파일로 검사 책임 분리. **거절**: AP9 (subagent spray) risk, devbrew "default to lightness" 위배. handoff readiness는 spec quality와 orthogonal하지 않음 — 신규 agent 정당화 부족.
- **R2 — reviewing-spec skill 안에서 spec-reviewer 두 번 dispatch (general review + handoff-only)**: approved 직후 별도 handoff dispatch. **거절**: dispatch cost 2배, re-review cap 계산 복잡, AP14 ceremony 패턴.
- **R3 — sidecar `<spec>.next.md` 파일 생성**: handoff packet을 git-tracked 파일로 보존. **거절**: 추가 파일 surface 증가. compact-survival은 *best-effort*이지 보장 아님 — 진짜 안전망은 [2] 다음 세션 첫 프롬프트 라인(사용자 복사 가능). v0.10.0에서 사용자 피드백 보고 재검토.
- **R4 — `## Handoff Context` 대신 frontmatter 필드로 (`handoff_context: ...`)**: YAML 안에 텍스트 박기. **거절**: multi-paragraph 텍스트는 markdown 본문이 자연스러움, frontmatter는 키-값 메타데이터에 한정 (P5).
- **R5 — Conversation reference 검출 패턴을 별도 config 파일로**: `templates/ambiguity-blacklist.txt` 처럼 외부화. **거절**: 패턴 10개 수준, reviewer prompt 안 정의가 가장 명확 (C7+C8).
- **R6 — pre-v0.9.0 spec.md grandfather 처리**: frontmatter `source:` 또는 `version:` 필드 기반으로 옛 spec은 `handoff_incomplete` 검사 skip. **거절**: 실제 spec/design 파일의 `source:` 값이 비정형(`source: superpowers/brainstorming + ...` 등 자유 문자열) — semver 추출 hole 발생. `version:` 필드는 spec 내용 version이지 schema version 아니라 의미 충돌. 신규 schema 필드 도입은 complexity 증가. 대안: 옛 spec 재review 시 사용자가 30초 분량 `## Handoff Context` 수동 추가 (reviewer recommendation에 템플릿 snippet 포함). CHANGELOG/README v0.9.0 release notes에 명시.
- **R7 — TL;DR이 Goal과 동일/유사 검출 (이전 AC5)**: LLM 판단 deterministic 테스트 불가, fixture 신뢰성 약화. **거절**: v0.9.0 surface 축소. v0.10.0+에서 spec-reviewer agent prompt에 advisory(non-block) 카테고리로 재시도 검토.

## Open Questions

- **OQ1**: `tests/test_handoff_design_mode.sh` fixture 생성 방식 — design.md를 임시 파일로 생성 후 reviewer 직접 dispatch vs 기존 design-mode 테스트 패턴 답습? 후자가 일관성↑. plan에서 패턴 비교.

(이전 OQ1 "frontmatter source 헬퍼 위치"는 R6 grandfather 폐기로 무효. 이전 OQ2 "섹션 위치"는 AC1에서 resolve — `## Goal` 직후, `## Context / Why` 직전.)

## Concrete Next Action

다음 단계: `Skill superpowers:writing-plans docs/superpowers/specs/2026-05-26-spec-distill-handoff-readiness-design.md`.

- Spec 경로: `docs/superpowers/specs/2026-05-26-spec-distill-handoff-readiness-design.md`
- Plan 산출물: `docs/superpowers/plans/2026-05-26-spec-distill-handoff-readiness.md`
- 명령: `Skill superpowers:writing-plans <this file>`
- 구현 worktree: writing-plans 후 implementation 진입 직전 `Skill superpowers:using-git-worktrees` invoke (브랜치 명 제안: `feature/spec-distill-handoff-readiness`).
