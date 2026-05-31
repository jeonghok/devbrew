---
date: 2026-05-31
plugin: spec-distill
topic: interview-single-entry
status: draft
author: jeonghokim
---

# spec-distill: `/interview` 단일 사용자 진입점

## Handoff Context

> **TL;DR:** `conducting-interview` SKILL.md frontmatter에 `user-invocable: false` 한 줄을 추가해 `/` 슬래시 메뉴에서 이 내부 엔진 스킬을 숨기고, 사용자 진입점을 `/interview` 하나로 만든다. 프로그램 호출(command dispatch·reviewing-spec re-entry·모델 자동 트리거)은 전부 보존.
>
> **Implicit context (이 세션에서 정해진 것):**
> - CC 공식 문서(`code.claude.com/docs/en/skills.md`)를 WebFetch로 직접 조회·verbatim 확인. doc invocation 표 기준: `user-invocable: false` = "You can invoke = No / Claude can invoke = Yes"(메뉴 숨김 + Skill tool 호출 유지). `disable-model-invocation: true` = "You can invoke = Yes / Claude can invoke = No"(메뉴 잔존 + Skill tool 호출 차단). 우리 목표(메뉴만 숨김 + 프로그램 호출 유지)에 맞는 필드는 `user-invocable: false`. (상세 verbatim 인용·매핑은 §메커니즘.)
> - version bump = patch(`0.11.1`→`0.11.2`). 외부 동작 무변경 + 내부 전용 스킬 메뉴 가시성만 정리 → 새 surface 아님.
> - 회귀 가드 테스트 포함(사용자 승인). blast radius = spec-distill 내부 한정(외부 플러그인 `conducting-interview` 참조 0건, grep 확인).
>
> **Deferred to plan (writing-plans에서 결정):** 회귀 가드 테스트의 정확한 grep 패턴·파일 배치 디테일. (README는 본 PR에서 건드리지 않음 — Non-goals 참조.)

## Context / Why

`/`(슬래시) 메뉴에 spec-distill 진입점이 **두 개** 뜬다:

1. `/spec-distill:interview` — 의도된 사용자 진입점 (`commands/interview.md`, 51줄: kill switch → trivia escape → skill dispatch)
2. `/spec-distill:conducting-interview` — 내부 인터뷰 엔진 (`skills/conducting-interview/SKILL.md`, 159줄). command가 `Skill conducting-interview`로 dispatch하고, `reviewing-spec`이 re-entry로 재호출하는 **구현 디테일**

`conducting-interview`는 사용자가 직접 띄울 surface가 아니다. 직접 호출하면 command가 수행하는 kill switch 존중·trivia escape 게이트(AP4 회피, AC10)를 우회하게 되어 Law 1 진입 규율이 깨진다. 사용자가 원하는 것: **메뉴에 `/interview` 하나만**.

### 메커니즘 — primary-source 검증 (load-bearing)

이 설계의 단일 load-bearing 전제는 *"메뉴에서만 숨기고 Skill tool 호출은 유지"*가 실제로 가능한가이다. CC 공식 문서(`code.claude.com/docs/en/skills.md`)를 WebFetch로 조회해 다음을 verbatim 확인했다.

**(1) "Control who invokes a skill" 섹션의 invocation 표 (verbatim, doc 그대로):**

| Frontmatter | You can invoke | Claude can invoke | When loaded into context |
|---|---|---|---|
| (default) | Yes | Yes | Description always in context, full skill loads when invoked |
| `disable-model-invocation: true` | Yes | No | Description not in context, full skill loads when you invoke |
| `user-invocable: false` | No | Yes | Description always in context, full skill loads when invoked |

**(2) 결정적 문장 (verbatim):** *"The `user-invocable` field only controls menu visibility, not Skill tool access. Use `disable-model-invocation: true` to block programmatic invocation."*

**(3) Frontmatter reference (verbatim):** `user-invocable` — *"Set to `false` to hide from the `/` menu. Use for background knowledge users shouldn't invoke directly. Default: `true`."*

이 세 인용은 우리 목표에 1:1로 매핑된다:
- **G1(메뉴 숨김)**: `user-invocable: false` → *You can invoke = No* (슬래시 메뉴에서 `/conducting-interview` 직접 호출 불가).
- **G2(프로그램 호출 보존)**: 같은 행의 *Claude can invoke = Yes* + 문장 (2)의 *"not Skill tool access"* — 즉 Skill tool을 통한 호출은 막지 않는다. command의 `Skill conducting-interview` dispatch와 `reviewing-spec` re-entry는 둘 다 *Skill tool 호출*이므로 그대로 작동.
- **`disable-model-invocation`이 오답인 이유**: 문장 (2)가 명시 — 이 필드가 바로 *"block programmatic invocation"*용. 적용 시 G2가 깨진다.

따라서 이 작업은 스킬 rename이 아니라 **visibility 토글** 1줄이며, 핵심 전제는 추론이 아니라 doc 문장으로 직접 확인됨.

이중 안전장치: (a) 변경은 frontmatter 1줄이라 **1줄 revert로 즉시 원복** 가능, (b) Verification Plan §수동 런타임(프로그램 호출 보존)이 "필드 적용 후 `/interview` dispatch가 실제로 작동하는가"를 end-to-end로 재확인.

blast radius도 spec-distill 내부에 갇혀 있다(외부 플러그인의 `conducting-interview` 참조 0건 — grep 확인).

## Goals

- G1. `/` 슬래시 메뉴에 spec-distill 사용자 진입점이 `/interview` **하나만** 노출된다(`/conducting-interview` 직접 호출 불가).
- G2. `conducting-interview` 스킬의 프로그램 호출 경로는 **전부 보존**된다: command의 `Skill conducting-interview` dispatch, `reviewing-spec` re-entry, 모델 자동 트리거.
- G3. devbrew Plugin Shape 의무 충족: `plugin.json` SemVer bump + `CHANGELOG.md` 항목 + 회귀 가드 테스트.

## Non-goals

- 스킬 디렉토리/`name` rename ✗ (동명사 family `conducting-interview`/`drafting-spec`/`reviewing-spec` 보존)
- command와 skill 통합·skill 삭제 ✗ (`reviewing-spec` re-entry·Writer/Reviewer 분리 보존)
- `conducting-interview`를 참조하는 40여 개 doc/plan/spec 참조 수정 ✗ (이름 불변이므로 여전히 정확)
- `drafting-spec`/`reviewing-spec`/hook/agent 동작 변경 ✗
- **README 수정 ✗ (reasoned decision, not unexamined)** — README Quick Start(line 12)는 실제 사용자 명령으로 `/interview todo 앱 만들어줘`를 제시하고, line 15의 "`conducting-interview` skill이 4-block format으로 첫 round를 시작합니다"는 *`/interview` 실행 후 내부에서 무슨 일이 일어나는지*를 서술하는 narration이다 — 사용자에게 `/conducting-interview`를 직접 치라고 안내하지 않는다. `user-invocable: false` 적용 후에도 이 서술은 사실로 유지(스킬은 dispatch되어 실행됨)되므로 menu-doc mismatch가 발생하지 않는다. 따라서 README touch는 불필요하며, 추가 시 오히려 어떤 Goal에도 연결되지 않는 scope 확장이 된다. (round 1 issue 183a2dd6에 대한 검토 완료 결론.)
- 다른 플러그인의 내부 스킬 노출 정책 일괄 점검 ✗ (이 PR 범위 밖)

## Constraints

- C1. `conducting-interview`는 사용자에게 메뉴에서 숨겨지되 **프로그램적으로는 반드시 호출 가능**해야 한다. → 반드시 `user-invocable: false`를 쓴다. **`disable-model-invocation: true`는 금지** — verbatim 표 기준 이 필드는 스킬을 여전히 `/name`으로 직접 호출 가능하게 두므로(`You can invoke = Yes`, 슬래시 메뉴 잔존) G1 자체에 실패하고, 동시에 `Claude can invoke = No`(binary 차단)이므로 G2(프로그램 호출 보존)를 **완전히 차단한다**. 우리가 원하는 것의 정반대.
- C2. 기존 frontmatter 필드(`name`, `description`, `cost_class`)는 의미 변경 없이 보존. 추가 only.
- C3. devbrew: plugins/spec-distill/ 를 건드리는 PR은 같은 commit에서 `plugin.json` version bump 필수(cache key silent stale 방지).
- C4. Korean-primary 문서 컨벤션. 영어는 식별자/고유명사/기술용어에 한정.
- C5. **CC 클라이언트 버전 floor (런타임 의존 명시)**: `user-invocable` 필드 지원의 정확한 최소 CC 클라이언트 버전은 본 세션에서 미확정(공식 doc frontmatter 표에 명시적 min-version 주석 없음 — `/run` 류 일부 필드만 `v2.1.145+`로 표기됨). 따라서 (a) 검증·운영은 *실제 테스트한 CC 클라이언트 버전을 PR 설명에 기록*하는 것으로 갈음하고, (b) 구버전 클라이언트에서 필드가 무시될 위험을 **명시적 리스크로 인정**한다 — 무시되더라도 fail-safe(스킬이 메뉴에 그대로 노출될 뿐 프로그램 호출·기능은 무손상)이며 1줄 revert 가능.

## Acceptance Criteria

- **AC1** — `plugins/spec-distill/skills/conducting-interview/SKILL.md` frontmatter에 `user-invocable: false` 한 줄이 존재한다.
  - 검증: `grep -q '^user-invocable: false$' plugins/spec-distill/skills/conducting-interview/SKILL.md`
- **AC2** — `conducting-interview` SKILL.md의 기존 frontmatter 필드(`name: conducting-interview`, `description`, `cost_class: medium`)가 모두 보존된다.
  - 검증: 세 키 각각 grep 존재 확인 (AC6 테스트에 포함).
- **AC3** — command dispatch와 `reviewing-spec` re-entry의 프로그램 호출 경로가 **content 기준으로** 보존된다(라인 번호 비의존). 두 grep 패턴은 작성 시점 실제 파일에 대해 검증됨 — `interview.md:40`에 `Skill conducting-interview $ARGUMENTS` 존재(dispatch의 정확한 형태이므로 exact match), `reviewing-spec/SKILL.md:78`에 `conducting-interview skill 호출` 존재(단, 회귀 가드가 wording 변경에 false-negative로 깨지지 않도록 더 느슨한 패턴 채택):
  - `grep -q 'Skill conducting-interview' plugins/spec-distill/commands/interview.md`
  - `grep -q 'conducting-interview' plugins/spec-distill/skills/reviewing-spec/SKILL.md` (reviewing-spec가 `conducting-interview`를 언급하는 유일한 이유가 re-entry path이므로 이 토큰의 존재만으로 invariant를 특정. 문구가 "skill 호출"→"스킬 재진입" 등으로 바뀌어도 가드가 false-negative로 깨지지 않음.)
  - 이 두 grep은 AC6 회귀 가드 테스트 안에 **단일 정규 위치**로 둔다(중복 정의 금지). 본 spec 본문의 라인 번호 언급은 *설명 목적*일 뿐 검증에 쓰지 않는다(drift 방지).
- **AC4** — `plugin.json` version이 `0.11.1` → `0.11.2`로 bump된다.
  - 검증: `test "$(jq -r .version plugins/spec-distill/.claude-plugin/plugin.json)" = "0.11.2"`
- **AC5** — `CHANGELOG.md`에 `## [0.11.2] — 2026-05-31` 섹션이 `### Changed` 항목과 함께 추가된다.
  - 검증: `grep -q '## \[0.11.2\] — 2026-05-31' plugins/spec-distill/CHANGELOG.md`
- **AC6** — (회귀 가드) `tests/test_conducting_interview_internal.sh` 신규 추가. 다음을 한 파일에서 검증하고 exit 0: (a) AC1 `user-invocable: false` 존재, (b) AC2 기존 3개 frontmatter 키 보존, (c) AC3 두 dispatch/re-entry content grep 보존. 누가 실수로 필드를 지우거나 dispatch 라인을 깨면 fail (Law 3 compounding).
  - 검증: `bash plugins/spec-distill/tests/test_conducting_interview_internal.sh; test $? -eq 0`

## Files to Modify

| 파일 | 변경 | AC |
|---|---|---|
| `plugins/spec-distill/skills/conducting-interview/SKILL.md` | frontmatter에 `user-invocable: false` 추가 | AC1, AC2 |
| `plugins/spec-distill/.claude-plugin/plugin.json` | `version`: `0.11.1` → `0.11.2` | AC4 |
| `plugins/spec-distill/CHANGELOG.md` | `## [0.11.2] — 2026-05-31` + Changed 항목 | AC5 |
| `plugins/spec-distill/tests/test_conducting_interview_internal.sh` (신규) | AC1+AC2+AC3 grep 가드 단일 정규 위치 | AC6 |

## Verification Plan

**자동(재현 가능 — 코드/CI에서 실행):**
1. 신규 `tests/test_conducting_interview_internal.sh` 실행 → AC1/AC2/AC3 일괄 green (exit 0).
2. `test "$(jq -r .version plugins/spec-distill/.claude-plugin/plugin.json)" = "0.11.2"` (AC4) + `grep -q '## \[0.11.2\] — 2026-05-31' plugins/spec-distill/CHANGELOG.md` (AC5).
3. 기존 `tests/` 전체 baseline 캡처 후 재실행 → 신규 red 0(기존 stale red는 baseline 대비 불변 확인). 테스트는 repo root에서 실행.

**수동 런타임(CC 세션 수동 실행 필요 — 자동화 불가, CI 게이트 아님):**
4. **프로그램 호출 보존(G2 핵심, load-bearing claim end-to-end 게이트)**: 변경 적용 + 플러그인 재로드 후 `/interview <rough request>` 실행 → trivia escape 통과 → `conducting-interview`가 정상 dispatch되어 4-block 첫 round 진행. *이것이 "필드가 프로그램 호출까지 막음"을 잡는 게이트다.* dispatch 실패(예: "skill not found"류) 시 = claim 오류 → AC1 1줄 revert로 즉시 원복.
5. **메뉴 은닉(G1 — CC 클라이언트 런타임 의존)**: 플러그인 재로드(또는 CC 세션 재시작) → 프롬프트에 `/` 입력 → 슬래시 메뉴 관찰.
   - **성공 기준**: `/interview`(또는 `/spec-distill:interview`)는 목록에 **보이고**, `/spec-distill:conducting-interview`는 **보이지 않는다**.
   - **실패 진단**: `conducting-interview`가 여전히 보이면 → 필드 미적용/오타(AC1 grep 재확인) 또는 재로드 누락 또는 C5 버전 floor 미달(클라이언트가 필드 미지원). `/interview`까지 사라지면 → 별개 회귀, Step 4 dispatch도 재확인.
   - **환경 기록(C5)**: 테스트한 CC 클라이언트 버전을 PR 설명에 명시.

## Rejected Alternatives

- **B. command에 skill 로직 통합 후 skill 삭제** — 기각. `reviewing-spec` re-entry가 깨지고, 동명사 family가 깨지며, 159줄이 51줄 command로 inline되어 항상 로드. blast radius 과대.
- **C. skill을 노출 안 되는 다른 이름으로 rename** — 기각. CC에서 이름만 바꿔도 스킬은 여전히 메뉴에 노출됨(실제로 안 숨겨짐). 40여 참조 churn만 발생하고 목표 미달성.
- **`disable-model-invocation: true` 사용** — 기각. verbatim 표 기준 이 필드는 스킬을 여전히 `/name` 직접 호출 가능하게 둔다(`You can invoke = Yes`, 슬래시 메뉴 잔존 → G1 실패) + `Claude can invoke = No`로 Skill tool 호출을 binary 차단(G2 완전 차단). 우리가 원하는 것의 정반대.
- **D. README Quick Start에 dispatch 관계 명시(이전 AC7)** — 기각(round 2). 어떤 Goal(G1/G2/G3)에서도 도출되지 않아 scope_creep이고, "정확한 문구는 plan에서 확정"이 붙어 untestable AC였다. README narration은 `user-invocable: false` 후에도 사실로 유지되므로 menu-doc mismatch가 없다(Non-goals 참조) — touch 불필요.

## Metadata

- **버전 bump 근거(patch 0.11.2)**: 외부 동작 변경 없이 내부 전용 스킬의 메뉴 노출만 정리 → non-breaking, 새 surface 추가 아님 → patch.
- **회귀 가드 포함 결정**: 사용자 승인. 비용 거의 0(grep 1개 파일), Law 3 compounding 가치.
- **미해결 → 디폴트 확정(spec 리뷰에서 redirect 가능)**: ① version bump = patch(0.11.2) ② 회귀 가드 = 포함.
- **blast radius**: spec-distill 내부 한정. 외부 플러그인 `conducting-interview` 참조 0건(grep 확인).
- **Principles instantiated**: Law 1(menu에서 trivia-escape 우회 진입점 제거 — interview 게이트 무결성), Law 3(회귀 가드로 compounding), devbrew "design lightness"(신규 P# 없이 frontmatter 1필드로 surface 정리).
- **보안 검토**: 해당 없음 — reviewer persona·게이트·kill switch 무변경. visibility 토글뿐.
- **Review**:
  - round 1 `needs_revise` 5-issue 전량 반영 — 6899e5d0(load-bearing claim → primary-source 인용), 4c70bd68(수동 검증 재현 절차), 83dc5425(AC3 content grep+AC6 dedup), be017f45(Handoff Context 추가), 183a2dd6(README 판단 근거화).
  - round 2 `needs_revise` 반영 — **(중대) 가짜 verbatim 인용 정정**: round 1에서 삽입했던 "These are independent settings" 인용과 3행 표는 실제 doc에 없는 paraphrase였음(fabrication). WebFetch 원문을 직접 읽어(`tool-results` 저장본 line 329–333 invocation 표 + line 545 결정 문장 + line 223 frontmatter reference) **실제 verbatim**으로 교체 — doc에 (1) You/Claude invoke 표, (2) *"The `user-invocable` field only controls menu visibility, not Skill tool access. Use `disable-model-invocation: true` to block programmatic invocation."*, (3) `user-invocable` = *"Set to `false` to hide from the `/` menu..."* 가 실재함을 확인. 이로써 load-bearing 전제가 추론이 아니라 doc 문장으로 직접 확정됨(6899e5d0 근본 해소). **AC7(README) drop** → scope_creep(ad27633a/c1d6c80a) + untestable AC(38738be4/64169938) 동시 해소, README는 reasoned Non-goal로 이동. **C5 추가**(CC client 버전 floor 미확정 → 테스트 버전 기록 + fail-safe 리스크 명시, 6899e5d0 raised 2×의 버전 dimension). **Verification Plan 자동/수동 재분류**(17c07a5c — 런타임 게이트를 "수동 런타임"으로 명시, CI 오인 방지).
  - **프로세스 정직성 note**: round 2에서 reviewer를 1개가 아니라 **3개 병렬 dispatch**(subagent spray, AP 위반)했고, approve 전에 spec을 "approved"라는 거짓 메시지로 **조기 commit**(9a71e7e)했다. 셋 중 2개가 `needs_revise`, 1개가 approve였으며 stricter 판정(needs_revise)을 채택. 이 spec이 실제 approve된 후 commit 메시지를 정정한다.
  - round 3 `needs_revise` 2-issue 반영 — 6899e5d0(raised 3×, 표현 정밀화): C1·Rejected Alternatives의 `disable-model-invocation` G2 영향을 "위협한다"→"완전히 차단한다(`Claude can invoke = No`, binary)"로 정정. verbatim 표를 채택한 뒤 설명 prose가 표의 binary No와 어긋나 있던 잔존 불일치 해소. Handoff TL;DR의 "자동 로드 차단"→verbatim 표 용어(You/Claude can invoke)로 교체. b4e92c17(AC3 grep wording-내성): re-entry grep을 `'conducting-interview skill 호출'`(wording 의존)→`'conducting-interview'`(토큰 존재만으로 invariant 특정)로 느슨화. 두 grep이 실제 파일(`interview.md:40`, `reviewing-spec:78`)에 매칭됨을 확인 후 AC3에 명시.
  - Stagnation_signal: 모든 round false. (round별 issue 추세: 5→3→2, diminishing.)
