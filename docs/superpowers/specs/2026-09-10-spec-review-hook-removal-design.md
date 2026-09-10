---
name: spec-review-hook-removal
type: design
created_at: 2026-09-10
source_interview: 없음 — /brainstorming 직접 진입. 사용자 결정은 「결정 기록」 절이 정본이다
next_phase: superpowers:writing-plans
---

# spec-distill 리뷰 훅 제거 — 설계문서 리뷰를 오케스트레이터가 이어 간다 · Design

> 강제는 표준 흐름에서 이미 발동하지 않고 있었다. 지우는 것은 작동하지 않는 강제와 그것을 떠받치던 원장이다.

## Handoff Context

**TL;DR** — spec-distill 의 Stop 훅 `hooks/review-dispatch.py` 와, 그 훅만을 위해 존재하던 arm 원장·발견·구조
검사를 삭제한다. 설계문서 리뷰(`spec-distill:reviewing-spec`)로의 진입은 턴 경계 강제 대신 **인터뷰 핸드오프가
싣는 지시문**과 **skill description** 을 읽은 오케스트레이터(세션을 운전하는 메인 모델)가 스스로 한다. 훅이
대신 해 주던 끄기 판정과 은퇴 토큰 공시는 새 진입 검사 모듈 `scripts/review_entry.py` 가 맡는다. GC 기동은
SessionEnd 훅으로 옮긴다. spec-distill major, quality-gates patch.

**Implicit context** —
(1) 사용자 요청 원문: 「spec review 훅 제거」, 「이제 훅방식 아님 가능하면 오케스트레이터가 알아서 진행해주면
좋겠어」.
(2) 2026-08-27 이음매 감사(`docs/audits/2026-08-27-cross-skill-seam-handoff.md`)가 미결로 남긴 D1
(①Stop 훅 확장 / ②sentinel 을 advisor 가 읽게 / ③자동화 포기·문서 축소)에 대한 답이 ③의 변형이다 —
자동 진행은 유지하고 **강제만** 버린다.
(3) 루트 `CLAUDE.md` 에는 아무것도 쓰지 않는다(사용자 결정 D5).
(4) 작업 위치: 브랜치 `feature/remove-spec-review-hook`, 워크트리
`.claude/worktrees/feature+remove-spec-review-hook`, base `c7b4f580`(#147 머지 — design doc 리뷰가 공유
docreview 엔진으로 전환된 직후).
(5) 이 문서는 인터뷰 없이 쓰였다. design-doc 프로필의 층 1 정답 출처(브리프 §2)가 없으므로 「결정 기록」이
그 자리를 대신한다.
(6) plan 이 정할 것은 문서 끝 「결정 기록」 아래 `### Deferred to plan` 에 모여 있다.

## 목차

- [Goal](#goal)
- [Context / Why](#context--why)
- [Goals](#goals)
- [Non-goals](#non-goals)
- [Constraints](#constraints)
- [설계](#설계)
  - [1. 제거](#1-제거)
  - [2. 제거가 끊는 것 다섯의 처리](#2-제거가-끊는-것-다섯의-처리)
  - [3. 오케스트레이터 경로](#3-오케스트레이터-경로)
  - [4. reviewing-spec 진입 계약](#4-reviewing-spec-진입-계약)
  - [5. 죽은 인용 정정](#5-죽은-인용-정정)
  - [6. 문서·버전·CHANGELOG](#6-문서버전changelog)
  - [7. 축적](#7-축적)
- [Acceptance Criteria](#acceptance-criteria)
- [Files to Modify](#files-to-modify)
- [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives)
- [알려진 한계](#알려진-한계)
- [Concrete Next Action](#concrete-next-action)
- [결정 기록](#결정-기록)

## Goal

설계문서 리뷰가 훅 없이, 오케스트레이터의 판단으로 brainstorming 과 writing-plans 사이에 들어간다.

## Context / Why

**훅이 하는 일 셋** (`hooks/review-dispatch.py` docstring): ① 발견 — `git status` 로 `docs/superpowers/specs/`
아래 dirty·untracked 문서를 찾는다 ② 구조 검사 — 실패하면 `decision:"block"` ③ dispatch — 다음 턴 첫
액션으로 `reviewing-spec` 을 강제한다.

**표준 흐름에서 이미 발동하지 않는다.** `superpowers:brainstorming` 은 「작성 → 커밋 → 사용자 리뷰」 순서로
턴 안에서 설계문서를 커밋한다. 발견은 dirty·untracked 만 보고(`discover_candidates.py`), dispatch 는 git 이 아는
문서를 건너뛴다(`review-dispatch.py:356-357` `if c.born: continue`). 턴이 끝날 때 커밋된 설계문서는 후보조차
아니다. 실패 양식도 조용하다 — 리뷰가 안 돌았다는 사실을 알리는 자리가 없다.

**그 강제를 떠받치려고 쌓인 구조** — arm 원장(`arm_ledger.py`: `armed_paths`·`inflight_paths`·
`dispatch_attempts`, 같은 문서를 반복 강제하지 않게 센다), 발견(`discover_candidates.py`), content-aware 모드
판정(`resolve_mode.py`), 구조 파서(`parse_spec_structure.py`). 훅이 없으면 넷 다 읽는 곳이 없다(비-테스트
사용처 전수 확인: 훅 · 서로 · `reviewing-spec` 의 `## 원장` 뿐).

**brainstorming 과의 충돌을 지금은 훅이 누르고 있다.** brainstorming 본문은 「Do NOT invoke any other skill.
writing-plans is the next step.」이라 적는다. 훅 mandate 의 「호출 skill의 terminal handoff(writing-plans 등)는
review pass 이후로 보류.」(`review-dispatch.py:768-770`)가 그것을 턴 경계에서 눌러 왔다. 훅이 사라지면 텍스트
지시가 그 자리를 이어받아야 한다 — §3.

**구조 검사가 더하는 것이 작다.** design 모드 검사는 placeholder 4토큰(`TBD`·`TODO`·`FIXME`·`<placeholder>`)과
영어 모호어 10개(`fast`·`robust`·…)다. 이 리포의 문서는 한국어가 주 언어이고, `design-doc.md` 프로필의
`doc-critic` 층 2 가 `placeholder`·`ambiguity` 를 한국어 표현(「적절히」「빠르게」)까지 덮는다. 스캐너 자신이
「이 검사가 실제로 설계 문서 작성을 세 번 막았다」(`parse_spec_structure.py:160`, 오탐)를 기록한다. spec 모드
검사(필수 섹션·`locked_decisions`)는 그런 문서를 만드는 skill 이 없다 — `templates/spec-template.md` 를 읽는 것은 테스트 둘(`test_handoff_context_empty_subsections.sh` · `test_handoff_conversation_reference.sh`)뿐이고, 둘 다 저자 쪽 Handoff Context 계약의 정답 출처로 그 템플릿을 쓴다(§알려진 한계 · Deferred to plan).

## Goals

- **G1** — Stop 훅과, 그 훅만을 위해 존재하는 코드·상태 필드·테스트를 제거한다.
- **G2** — 인터뷰 경유 경로에서 오케스트레이터가 brainstorming 뒤·writing-plans 앞에 `reviewing-spec` 을
  부르도록, 핸드오프 세 자리가 그 순서를 싣는다.
- **G3** — `/brainstorming` 직접 경로는 `reviewing-spec` description 이 최선 노력으로 덮는다.
- **G4** — 훅이 대신 해 주던 끄기(전역 · design 모드)가 `reviewing-spec` 진입에서 계속 집행되고, 은퇴한
  토큰은 공시된다.
- **G5** — 훅 제거가 부수적으로 끊는 것(GC 기동 · 배선 락 · README kill switch 키)을 같은 변경에서 복구한다.

## Non-goals

- 루트 `CLAUDE.md` 수정 — 사용자 결정 D5. 다른 리포 사용자에게 CLAUDE.md 에 줄을 넣으라고 권하는 README
  안내도 넣지 않는다.
- 어떤 이벤트 훅의 신설(SessionStart·UserPromptSubmit 텍스트 주입 포함).
- Law 1 필수 섹션 게이트의 새 구현 — 이 변경 뒤 리포 내 구현이 0 이 됨을 기록만 한다(§알려진 한계).
- `superpowers:brainstorming` 수정 — 외부 플러그인이다.
- 이미 사용처가 없던 fixture 4개(`locked-decisions-spec.md` · `v0.1.x-spec-no-locked.md` ·
  `reviewer-output-mixed.md` · `2026-05-17-test-design-bad.md`) 정리.
- `docs/audits/README.md:12` 의 감사 요약, 과거 spec·plan·interview·archive 문서 수정 — 그 시점의 사실이다.
- deprecation window 2단계 릴리스 — 사용자 결정 D3.

## Constraints

- **C1** — 리뷰 진입에 어떤 이벤트 훅도 쓰지 않는다. SessionEnd 정리 훅은 리뷰와 무관하므로 유지한다.
- **C2** — 루트 `CLAUDE.md` 불변.
- **C3** — kill switch 는 보안 컨트롤이다(철학 P21). 사용자가 끈 것이 켜진 것으로 동작하거나 보이면 안 된다.
  **명시적 예외 하나(사용자 결정 D9)**: 은퇴하는 `spec-distill:Stop`·`:review-dispatch` 는 advisory 만 내고 리뷰를
  막지 않는다. 이 토큰으로 자동 리뷰를 꺼 둔 사용자에게는 오케스트레이터 경유 리뷰가 되살아나고, advisory 가 그
  사실과 새 끄기 스위치를 알린다 — 「보이면 안 된다」 절반은 지키고 「동작하면 안 된다」 절반은 이 토큰에서 포기한다. 같은 두 토큰이 부수효과로 막던 TTL-GC 도 SessionEnd 에서
  다시 돈다(§2 #1) — 「은퇴 토큰은 옮겨간 기능을 막지 않는다」는 같은 원칙의 적용이고, 이쪽은 advisory 도 없다(그
  advisory 를 내는 `review_entry.py` 는 리뷰 호출 때만 돈다). 즉 GC 에 대해서는 C3 의 두 절반을 모두 포기한다.
- **C4** — 새 책임은 별도 모듈에 두고 기존 파일에는 진입 한 줄만 둔다.
- **C5** — 플러그인을 건드리면 같은 변경에서 bump. 번호는 머지 직전에 정한다(병렬 브랜치와의 동일 번호
  무충돌 병합 방지).
- **C6** — Law 2: 리뷰어 `doc-critic`·`doc-recritic` 의 `tools:` 는 바뀌지 않는다.
- **C7** — `# copy-of` 물리 사본은 함께 바뀐다.
- **C8** — 오케스트레이터가 읽는 산출물(핸드오프 문구 · description)은 행동에 필요한 것만 담는다 — 출처·
  배경·존재 정당화 금지(CLAUDE.md **Self-narrating artifact**).

## 설계

### 1. 제거

| 묶음 | 대상 |
|---|---|
| 본체 | `hooks/review-dispatch.py` + `hooks/hooks.json` 의 `Stop` 블록(과 그 파일 `description` 의 Stop 서술) · `scripts/arm_ledger.py` · `scripts/discover_candidates.py` · `scripts/parse_spec_structure.py` · `scripts/resolve_mode.py` · `scripts/ambiguity-blacklist.txt` · `templates/spec-template.md` |
| `scripts/hook_common.py` 중 훅 전용 | `LAST_DISPATCHED_RE` · `parse_iso` · `state_file_for` · `configure_utf8_streams`. 모듈 이름은 유지한다(`test_yaml_scalar_single_definition.py` 가 `hook_common` 이름을 핀). `_yaml_scalar` 계열과 `fire_and_forget_gc`·`GC_SCRIPT` 는 남는다 |
| 상태 필드 | `state.local.md` 의 `last_dispatched_at` · `armed_paths` · `inflight_paths` · `dispatch_attempts` · `validation_attempts` · `discovery_cursor` · `git_unavailable_advised` · `retired_token_advised` — 쓰는 곳이 훅과 원장뿐이라 함께 사라진다 |
| 테스트 13 | 삭제된 코드만 검사하는 파일(목록은 Files to Modify) |
| fixture 9 | 위 테스트가 사라지면 사용처가 0 이 되는 것 |

### 2. 제거가 끊는 것 다섯의 처리

| # | 끊기는 것 | 처리 |
|---|---|---|
| 1 | TTL-GC(`scripts/spec-distill-gc.py`)의 **유일한 기동자**가 훅이다(`review-dispatch.py:481` → `hook_common.fire_and_forget_gc`) | `hooks/session-end-cleanup.py` 가 이 순서로 한다: ① 자기 kill switch(`spec-distill:SessionEnd` · `:session-end-cleanup` · 전역 `DISABLE`) 검사 ② 끝나는 세션의 폴더 삭제 ③ `try/finally` 의 `finally` 에서 `fire_and_forget_gc()`. ① 이 참이면 훅은 아무것도 하지 않는다 — GC 도 돌지 않는다(CLAUDE.md: 어떤 훅도 자기 kill switch 존중을 거부할 수 없다). 그래서 **`spec-distill:SessionEnd` 는 이번 세션 정리와 TTL-GC 를 함께 끈다** — README 의 이 스위치 설명(「SessionEnd cleanup hook만 skip」)을 같은 변경에서 고친다. ③ 이 `finally` 라서 ② 의 payload 조기 return(`:33-44`)이나 stdin 디코딩 예외가 GC 를 건너뛰게 하지 않는다. GC 자신은 `spec-distill:spec-distill-gc` 와 전역 `DISABLE` 을 스스로 검사한다(`spec-distill-gc.py:81`). 루트는 옛 훅과 같이 **프로세스 cwd** 의 `state_root()` 다(`spec-distill-gc.py:83`) — per-session 삭제는 payload `cwd` 를 쓰고, 두 층은 원래 서로 다른 훅에서 각자 루트를 풀었다. 이 함수는 이름과 달리 동기다(`subprocess.run`, `timeout=5`). 훅 `timeout: 10` 을 넘기면 끊기는 것은 **맨 뒤의 GC** 다 — 끝나는 세션의 자기 폴더 삭제는 그 앞에서 이미 끝났고, GC 는 다음 SessionEnd 가 다시 돈다. 옛 훅에서는 `spec-distill:Stop` 이 GC 까지 부수효과로 막았다(`review-dispatch.py:479` 가 `:481` 앞) — 이 변경 뒤 그 사용자의 GC 는 다시 돈다(C3 예외 · 알려진 한계) |
| 2 | `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE` 의 유일한 독자가 `resolve_mode.py:50` 이다 | `reviewing-spec` 진입(§4.2)이 이 스위치를 존중한다. 의미는 **끄는 쪽으로 넓어진다** — 예전에는 자동 dispatch·구조 검사만 껐고 수동 호출은 살아 있었지만, 이제는 수동 호출을 포함해 skill 전체를 끈다. content-aware 판별(접미사 없는 `.md` 를 frontmatter 로 design 분류)도 함께 사라진다. 둘 다 README·CHANGELOG 에 적는다. 은퇴시키면 이 스위치로 리뷰를 꺼 둔 사용자에게 리뷰가 조용히 되살아난다(C3) |
| 3 | `tools/adjudication/check_wiring.py` 의 `review-dispatch.py` 줄번호 키 `EXEMPT` 10개 · `TERMINAL_CONSUMERS` 1개 · `_T5_SELECT_LOOP*` 가 stale 이 되어 `test_adjudication_wiring.sh` 가 RED | 항목을 제거하고 `EXEMPT_BASELINE`·`COMP_BASELINE` 과 그 주석은 **재계수**한 값으로 쓴다(손으로 뺄셈하지 않는다) |
| 4 | README `:227` 의 `spec-distill:review-dispatch` 키가 도출 키 집합에서 사라져 `shared/tests/test_dispatch_name_defined.sh` 가 RED(`spec-distill:Stop` 은 그 락의 참조 정규식이 소문자로 시작하는 이름만 잡아 걸리지 않는다 — 그래도 거짓이 되는 문장이라 함께 옮긴다) | 활성 kill switch 목록에서 빼고 「은퇴한 스위치」 절로 옮긴다. 표기는 그 락을 이미 통과하는 v0.36.0 은퇴 절의 방식을 따른다(확인은 plan) |
| 5 | `reviewing-spec/SKILL.md:159` — 「`DEVBREW_SPEC_DISTILL_DISABLE=1` 은 훅이 dispatch 이전에 이미 걸러낸다」가 거짓이 된다. 전역 끄기를 적용하는 자리는 엔진 절차서 2단계의 산문 확인 하나만 남는다 | §4.2 — 결정론 모듈이 한 번 더 보고, 그 모듈이 실패하면 끔으로 친다 |

### 3. 오케스트레이터 경로

#### 3.1 지시가 실리는 자리

| 자리 | 넣는 것 (문구는 plan 에서 확정, 요지는 고정) |
|---|---|
| `skills/conducting-interview/references/finishing.md` 옵션 ① 의 verbatim `/compact` 템플릿 끝 `다음 단계:` | brainstorming 호출 → 설계문서를 쓰고 커밋 → **그 설계문서 경로로** `Skill spec-distill:reviewing-spec` → 승인 게이트에서 진행이 선택된 뒤 writing-plans. 템플릿에 새 꺾쇠 placeholder 를 넣지 않는다 — 이 문장은 사용자가 그대로 붙여넣는 것이고, 치환되지 않은 placeholder 를 잡는 fail-closed 검사가 없다(`finishing.md:351-353`) |
| 같은 파일 옵션 ② 의 호출 프롬프트(재결정 규약 C4 문장 옆) | 같은 순서 + 「brainstorming 의 사용자 리뷰 게이트 자리에서 `reviewing-spec` 을 부른다. brainstorming 의 『다음은 writing-plans 뿐』 지시보다 이 순서가 우선한다」 + 「`reviewing-spec` 이 게이트 없이 끝나면 brainstorming 의 사용자 리뷰 게이트로 돌아간다」 |
| `templates/interview-brief-template.md` `## 7. Next Action` | 「reviewer 검증」을 `spec-distill:reviewing-spec` 이라는 이름과 순서(작성·커밋 → 리뷰 → 승인 게이트 뒤 writing-plans)로 바꾼다 |
| `skills/reviewing-spec/SKILL.md` frontmatter `description` | 「superpowers:brainstorming 이 `docs/superpowers/specs/…-design.md` 를 쓰고 커밋한 직후, writing-plans 전에 쓴다. brainstorming 의 사용자 리뷰 게이트를 대신한다. 설계문서 경로를 인자로 받는다」 |

전달 경로의 성질은 이미 정해져 있다: brainstorming 은 spec-distill 을 모르고 brief frontmatter 를 읽지 않으므로
규약은 **오케스트레이터의 호출 프롬프트**에 싣는다(`finishing.md:333` 「규약의 거처 (C5)」). 이 설계는 그 선례에
순서 한 문장을 더하는 것이다.

#### 3.2 사용자가 보는 게이트는 하나다

`reviewing-spec` 의 승인 게이트(① `/compact` 후 writing-plans · ② 바로 writing-plans · ③ 수정 · ④ 멈춤,
정본 `references/proceed-gate.md`)가 brainstorming 의 「Please review it」 사용자 리뷰 게이트 자리를 대신한다.
`reviewing-spec` 이 게이트 없이 끝나는 경로는 정본(`references/proceed-gate.md:57`)이 적은 둘이다 — kill switch(§4.2, 진입 검사 실패 포함)와 대상 경로 부재. 인자 없이 불려 사용자가 후보를
고르지 않은 경우는 **대상 경로 부재**(Step A)로 친다 — 정본을 고치지 않는다. 두 경로 모두 advisory 단락의 **마지막 문장**이 같은 복귀 지시다: 「리뷰 없이 끝났다 — writing-plans
로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트).」 §3.1 ②
의 호출 프롬프트도 같은 분기를 싣는다. 이 둘이 「게이트가 0 개가 되는 경로는 없다」를 받치는 메커니즘이다 —
정적 문구이므로 AC16 은 문구의 존재와 위치만 잰다.

### 4. reviewing-spec 진입 계약

#### 4.1 입력

- `$spec_path` 는 **호출 인자**다(Skill 호출의 args / `/spec-distill:reviewing-spec <path>`). 이 skill 에는
  `user-invocable: false` 가 없어 사용자도 직접 부를 수 있다.
- 인자가 없으면 `docs/superpowers/specs/` 아래 `-design.md` 후보(현재 브랜치의 최근 커밋 50개 안에서 추가된 것
  중 최신 5개 + untracked 전부)를 보이고
  `AskUserQuestion` 으로 확인한다. 후보 산출은 git 명령 한두 줄이다 — 삭제되는 `discover_candidates.py` 를
  되살리지 않는다.
- 훅 mandate 의 `mode:` 슬롯은 없어진다. 프로필은 `design-doc.md` 로 고정이다(이미 `design`·`spec` 이 같은
  프로필로 갔다).
- `## 입력` 의 sid · `STATE_DIR` 도출(`state_path.py session-id` / `state-root`)은 **유지**한다 — 엔진 상태
  `docreview-state.md` 와 codex 산출물이 그 디렉토리에 산다. `$STATE`(`state.local.md`)와 「read==write 디렉토리
  불변식」 서술은 삭제한다.

#### 4.2 진입 검사 모듈 `scripts/review_entry.py`

`reviewing-spec` 이 엔진 라운드 전에 한 번 부른다. 출력은 stdout JSON 한 줄이다:

```json
{"disabled": false, "reason": null, "advisories": ["[spec-distill] ..."]}
```

- **끄기** — `kill_switch_active("spec-distill", "review-entry")`(공용 헬퍼, `shared/killswitch/kill_switch_active.py:29`
  — hook 이름 인자가 필수라 `DEVBREW_SKIP_HOOKS=spec-distill:review-entry` 이라는 이름 붙은 스위치가 함께
  생긴다. GC 스크립트가 스크립트 이름을 스위치 이름으로 쓴 선례와 같다. skill 이름 `reviewing-spec` 을 쓰지 않는 이유: `check_names.py` 가 README 참조를 skill 이름으로도 해소하므로, 이 스위치의 수신처가 사라져도 매달림으로 잡히지 않는다) 또는 `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE == "1"`.
  `disabled: true` 면 skill 은 `reason` 과 advisories 를 단락으로 내고 게이트 없이 끝난다 — `proceed-gate.md` 가
  이미 규정한 「kill switch 예외 경로」다.
- **진입 검사 실패는 끔으로 친다(fail-closed).** `review_entry.py` 가 없거나 rc≠0 이거나 stdout 이 JSON 한 줄로
  파싱되지 않거나, 파싱돼도 스키마(최상위 객체 · `disabled` 는 boolean 필수 · `reason` 은 문자열 또는 null ·
  `advisories` 는 문자열 배열)를 어기면 skill 은 `disabled: true` · `reason: entry_check_failed` 로 간주하고, 실패 사실(경로 · rc · stderr
  첫 줄)을 advisory 로 낸 뒤 §3.2 의 복귀 지시로 끝난다. 끔 여부를 모르는 채 리뷰를 돌리면 사용자가 끈 스위치를
  무시할 수 있고, 끔으로 치면 잃는 것은 이번 자동 리뷰 한 번뿐이다 — 사용자는 brainstorming 의 사용자 리뷰 게이트를
  그대로 받는다. 엔진은 스키마가 유효하고 `disabled` 가 정확히 `false` 일 때만 돈다.
- **공유 엔진 2단계와의 관계 — 병존.** 엔진 절차서 2단계(`references/reviewing-document.md:15`)의
  `DEVBREW_<HOST>_DISABLE` 확인은 그대로 둔다 — 네 자리가 공유하는 절차라 이 자리만을 위해 고치지 않는다. 전역
  끄기를 두 번 보지만 둘 다 끄는 방향이라 충돌하지 않는다. `review_entry.py` 가 더하는 것은 결정론 판정과
  `DESIGN_MODE_DISABLE` · `spec-distill:review-entry` · 은퇴 토큰 공시다.
- **은퇴 토큰 공시** — `DEVBREW_SKIP_HOOKS` 의 전체 토큰 대조로 `spec-distill:Stop` · `spec-distill:review-dispatch`
  (이번에 은퇴) · `spec-distill:validator` · `spec-distill:PostToolUse` · `spec-distill:reminder` ·
  `spec-distill:UserPromptSubmit`(v0.36.0 은퇴), 그리고 독립 변수 `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW == "1"`.
  발견되면 사용자의 토큰을 되읽어 「가리키던 훅은 삭제돼 아무것도 끄지 않는다. 설계문서 리뷰를 끄려면
  `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` 또는 `DEVBREW_SKIP_HOOKS=spec-distill:review-entry`, 플러그인
  전체는 `DEVBREW_SPEC_DISTILL_DISABLE=1`」을 advisory 로 낸다.
  - 매칭 규칙은 훅의 `retired_switch_advisory`(`review-dispatch.py:117-170`)를 **옮긴다** — 각 스위치를 읽던
    방식 그대로(토큰은 콤마 분리·양끝 공백 제거 후 전체 일치, `SKIP_AUTOREVIEW` 는 `== "1"`). 부분 문자열
    매칭이면 `spec-distill:validator-v2` 에 오발화하고, `is not None` 이면 `=0` 으로 꺼 둔 사용자에게 거짓을 말한다.
  - v0.36.0 토큰 넷을 포함하는 이유: 지금 그 넷의 advisory 는 「`spec-distill:Stop` 을 쓰라」고 말하는데 훅 삭제
    뒤에는 그 문장이 거짓이 된다. 문구를 고칠 자리가 이 모듈뿐이다.
  - 세션당 1회 마커는 두지 않는다 — 훅은 매 턴 돌아서 필요했지만 이 검사는 리뷰 호출마다 한 번 돈다.
  - `spec-distill:Stop`·`:review-dispatch` 는 지금 자동 리뷰를 끄는 **살아 있는** 스위치다. 그래서 이 둘의 advisory 는
    「이 토큰은 더 이상 리뷰를 막지 않는다」를 먼저 말하고, 다음 문장은 **최종 판정에 따라 갈린다** — `disabled:
    false` 면 「이번 리뷰는 진행된다」, 다른 끄기 스위치 때문에 `disabled: true` 면 「이번 리뷰는 <그 스위치> 때문에
    꺼졌다」. 그리고 새 끄기 스위치를 댄다. 막지 않는
    것은 사용자 결정 D9(C3 의 명시적 예외)다. 나머지 다섯은 v0.36.0 부터 이미 아무것도 끄지 않으므로 현상 유지다.
  - **대체재는 기능이 남아 있는 토큰에만 댄다** — 옛 `retired_switch_advisory` 의 「없는 대체재를 가리키지 않는다」
    규칙을 유지한다. 리뷰 끄기 스위치를 대안으로 대는 것은 자동 리뷰를 끄던 셋(`Stop` · `review-dispatch` ·
    `SKIP_AUTOREVIEW`)뿐이다. `validator` · `PostToolUse` · `reminder` · `UserPromptSubmit` 이 끄던 구조 검사 ·
    리마인더는 삭제돼 등가물이 없으므로 「대상이 삭제돼 아무것도 끄지 않는다」만 말한다.
- **환경변수 `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC`** 은 끄기 스위치가 아니라 조율 값이므로 advisory 대상이
  아니다. CHANGELOG Removed 에만 적는다.

#### 4.3 원장 삭제와 미커밋 advisory

`## 원장` 절(`mark-reviewed` · `check-born` · `clear-inflight` A/B)을 삭제한다. `check-born` 이 사용자에게 주던
효과 하나만 원장 없이 남긴다: 승인 게이트 ①/② 직전 `git status --porcelain -- "$spec_path"` 가 비어 있지
않으면 「리뷰 수정분이 커밋되지 않았다」 advisory 를 낸다. 문서 부재 경로의 advisory 는 유지하고 원장 호출만
뺀다. codex 펜스 주석의 「훅 mandate 의 슬롯」은 「호출 인자」로 바꾼다. 사용자에게 나가는 런타임 `echo` 문구
(`SKILL.md:131` 「dispatch mandate 의 'spec path:' 슬롯 값을 대입해라」)도 같이 바꾼다.

### 5. 죽은 인용 정정

존재하지 않게 되는 대상을 현재형으로 가리키는 자리:

| 자리 | 인용 |
|---|---|
| `codex_prompt_common.py` 사본 셋(`shared/codex/` · `plugins/spec-distill/scripts/` · `plugins/quality-gates/scripts/`) | docstring 이 `review-dispatch.py` 의 reconfigure 루프를 「형제 관용구」로 가리킨다 |
| `tools/adjudication/check_names.py:112` | `dispatch` 가 든 키 이름의 예로 `spec-distill:review-dispatch` |
| `scripts/check_brief.py:19` | 「specs의 parse_spec_structure.py와 같은 층」(import 아님, docstring) |
| `scripts/state_path.py:86-90` | Stop 훅과 `mark-reviewed` 가 같은 파일을 키잉한다는 주석 |
| `skills/reviewing-brief/SKILL.md:62` | 「훅이 읽는 파일과 같은 리졸버」 |
| `shared/docreview/scripts/docreview_state.py:8` | 「그 파일은 훅과 brief 파이프라인의 줄 파서가 소유한다」 |
| `scripts/hook_common.py:2-21` | 모듈 docstring 의 소비자 목록 |

`docreview_state.py` 는 quality-gates 와 spec-distill 이 심볼릭 링크로(모드 120000), `codex_prompt_common.py` 는
두 플러그인이 물리 사본으로 싣는다 — 둘 다 quality-gates 의 bump 를 부른다. plugin-audit 은 어느 쪽도 싣지 않는다.

### 6. 문서·버전·CHANGELOG

- **spec-distill README** — 흐름도(`:51` Stop 상자 → 「오케스트레이터가 `reviewing-spec` 호출 — 강제 아님」),
  Principles Instantiated 의 훅·원장·구조 검사 서술(`:81` · `:84-86` · `:89` · `:91-94` · `:112` · `:134` ·
  `:138` · `:140`. `:146` 은 gstack 흡수 이력이라 역사 서술이면 유지 — plan 에서 판정), Hooks Installed(Stop 행 삭제, `:158` 출력 스키마 문장 수정), 「발견의 한계」·
  「행동 케이스 테스트」 절 삭제, kill switch 절(Stop·`review-dispatch`·`REDISPATCH_TTL` 삭제, `DESIGN_MODE_DISABLE`
  의미 재서술, `spec-distill:review-entry` 추가, TTL-GC 줄(`:228` 「TTL-GC가 backup으로 작동」)은 SessionEnd 의 `finally` 기동 사실로), 「먼저 — 무엇이 리뷰의 범위를 정하는가」 절(`:186-217`) · G6 상한 bullet(`:244-247`) 삭제 또는 재서술,
  SessionEnd 스위치 설명(두 층을 함께 끈다), 은퇴 절(v0.36.0 항목 `:255`·`:259` 의 「끄려면 `spec-distill:Stop`」
  권고 제거 — 훅 삭제 뒤 거짓이 되는 문장이다 + 새 토큰 둘 +
  advisory 가 `reviewing-spec` 진입으로 옮겨감).
- **원칙 서술의 정직성** — 「리뷰 진입은 집행(hook)이 아니라 skill 표면과 핸드오프 지시다」를 명시한다. 철학 P13
  (hook = 집행 / skill = capability 표면) 기준으로 이 자리의 집행이 사라졌다는 사실을 숨기지 않는다. Law 2
  분리는 그대로다.
- **CHANGELOG** — Removed(훅 · 원장 · 발견 · 구조 검사 · 템플릿 · 토큰 · env) / Changed(`reviewing-spec` 입력 계약 ·
  GC 기동자 · `DESIGN_MODE_DISABLE` 의 집행 지점 · 새 스위치 `spec-distill:review-entry`) / Deprecated(window
  면제 — 선례와 같은 「제3자 설치가 현재 없다」 조건 수용 문구, 확인 시점의 사실 PUBLIC · fork 0 · star 0
  (2026-09-10), 선례의 「조용한 재활성화 없음」 논거가 여기서는 성립하지 않는다는 점과 그래서 두는 advisory) /
  알려진 결과(§알려진 한계 전부).
- **버전** — spec-distill major(공개 표면 제거), quality-gates patch(§5). 번호는 머지 직전.
- **`plugin.json` description** — 「design docs reviewed by a physically-separated Law 2 reviewer」는 여전히 참이라
  무수정.

### 7. 축적

Law 3 — 다음 세션이 찾는 자리를 갱신한다:

- 메모리 「턴 끝나기 전 커밋이 리뷰 훅을 끈다」(`reference_commit_before_turn_end_disarms_review_hook.md`) — 대상
  메커니즘이 사라지므로 삭제하거나 「해소(이 변경)」로 표기하고 `MEMORY.md` 인덱스 줄을 맞춘다.
- 메모리 「이음매 진단 핸드오프」(`project_cross_skill_seam_handoff.md`) — 미결 D1 을 「③의 변형으로 결정됨」으로
  갱신한다.
- 새 사실 둘은 CHANGELOG 와 이 문서가 담는다: Law 1 필수 섹션 게이트 구현 0, 직접 경로의 약함.

## Acceptance Criteria

- **AC1** — `hooks/hooks.json` 에 `Stop` 항목이 없고 `SessionEnd` 항목은 있다.
- **AC2** — §1 본체 7개 파일이 없다. 삭제 집합의 식별자와 개념 별칭(Stop 훅 · dispatch mandate · arm 원장 ·
  arm-once · 구조 검증 · in-flight · born · `REDISPATCH_TTL` 등)이 CHANGELOG·과거 문서 밖에서 현재형으로 인용되지
  않는다. 검사 목록은 손으로 적지 않고 삭제 집합에서 도출한다.
  「현재형」은 기계로 가르지 않고 **면제 코퍼스**로 정한다: (a) 역사 — `*/CHANGELOG.md` · `docs/archive/**` · `docs/audits/README.md`(항목마다 날짜가 붙은 감사 요약 인덱스) ·
  `docs/superpowers/{specs,plans,interview}/**` · 날짜 붙은 `docs/audits/*.md`. (b) 은퇴 토큰 리터럴(`spec-distill:Stop`
  · `:review-dispatch` · v0.36.0 넷 · `SKIP_AUTOREVIEW`)에 한해 `scripts/review_entry.py` · 그 테스트 · README 「은퇴한
  스위치」 절(절 헤딩으로 줄 범위를 자른다). (b) 는 **토큰 리터럴만** 면제한다 — 같은 파일이라도 다른 삭제
  식별자(`arm_ledger` 등)가 나오면 RED 다. 면제 목록은 락 파일 한 곳에 두고, 넓힐 때 이유를 함께 적는다.
  **별칭 검사의 범위**: 개념 별칭(`in-flight` · `born` · `구조 검증` 등)은 다른 플러그인이 자기 개념으로 쓰는
  일반어라(quality-gates 의 in-flight advisor 등) 리포 전체에 걸면 무관한 파일이 걸린다. 별칭 검사는 spec-distill
  플러그인과 삭제 대상을 인용하는 공용 파일(§5)로 한정한다. 식별자 검사는 리포 전체다. 별칭 목록과 범위의
  확정은 plan 이 한다.
- **AC3** — `session-end-cleanup.py` 를 실행하면 프로세스 cwd 의 `state_root()` 아래 TTL 이 지난 **다른** 세션 폴더가
  지워진다 — stdin 이 JSON 이 아니거나 payload 에 sid 가 없을 때도(GC 는 `finally` 에 있다). `spec-distill:spec-distill-gc`
  또는 전역 `DISABLE` 이 켜져 있으면 지워지지 않는다. `spec-distill:SessionEnd` 가 켜져 있으면 이번 세션 폴더도
  다른 세션 폴더도 지워지지 않는다. 테스트는 `tests/test_session_end_cleanup.py` 에 더하고, SessionEnd 훅을 띄우는
  **어떤 테스트 호출도** 러너 cwd 의 실제 상태 루트에서 GC 를 돌리지 않는다.
- **AC4** — `review_entry.py` 의 `disabled` 판정: `DEVBREW_SPEC_DISTILL_DISABLE=1` → true ·
  `DEVBREW_SKIP_HOOKS=spec-distill:review-entry` → true · `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` → true ·
  아무것도 없음 → false · 각 변수 `=0` → false.
- **AC5** — 은퇴 스위치 일곱(토큰 여섯 + `SKIP_AUTOREVIEW=1`)이 각각 사용자의 토큰을 이름으로 대는 advisory 를
  내고, 접미 토큰(`spec-distill:validator-v2`)과 `SKIP_AUTOREVIEW=0` 은 내지 않는다. advisory 는 존재하는
  스위치만 가리킨다. 은퇴 토큰만 설정된 경우 `disabled` 는 false 다(D9). 은퇴 토큰과 유효한 끄기 스위치를 함께 설정하면 `disabled` 는
  true 이고, 은퇴 토큰 advisory 는 「리뷰가 진행된다」가 아니라 꺼진 사유를 말한다. `validator` 류 넷의 advisory 는
  대체 스위치를 대지 않는다.
- **AC6** — `reviewing-spec` 이 엔진 라운드 전에 `review_entry.py` 를 부르고, `disabled: true` 이거나 진입 검사가 실패하면(모듈 부재 · rc≠0 · JSON 파싱 실패 · 스키마 위반 — `{}` · `disabled` 비-boolean · 최상위 null/배열) 게이트 없이
  advisory 단락으로 끝난다.
- **AC7** — `reviewing-spec` `## 입력` 은 호출 인자에서 경로를 받고, 인자 없음 경로는 후보 제시 + 사용자 확인이다.
  `mode:` 슬롯 · `$STATE` · `arm_ledger.py` 호출이 skill 어디에도 없고, 그것을 가리키는 문장(게이트 표 ④ 행의
  `clear-inflight B` · polite stop 줄의 「`## 원장` 의 두 호출」 · 런타임 echo 의 「dispatch mandate」)도 없다.
- **AC8** — `finishing.md` ①의 `/compact` 템플릿 · ②의 호출 프롬프트 · brief 템플릿 §7 · `reviewing-spec`
  description 넷이 `spec-distill:reviewing-spec` 을 writing-plans **앞**에 적는다(순서까지). ①의 템플릿에 새
  꺾쇠 placeholder 가 없다.
- **AC9** — 승인 게이트 ①/② 직전에 `$spec_path` 가 미커밋이면 advisory 가 나온다.
- **AC10** — `shared/tests/test_adjudication_wiring.sh` · `shared/tests/test_dispatch_name_defined.sh` 가 GREEN 이고,
  `check_wiring.py` 의 baseline 값은 재계수 결과와 같다.
- **AC11** — §5 의 일곱 자리에 삭제된 대상의 현재형 인용이 없고, `codex_prompt_common.py` 사본 일치 검사가 GREEN 이다.
- **AC12** — 착수 전 baseline 대비 새 실패가 0 이다. 비교 키는 **실패한 테스트 식별자**(파일 + 케이스 이름)의
  집합이다 — 의도적으로 삭제한 테스트를 뺀 뒤, 변경 후 집합이 baseline 집합의 부분집합이어야 한다. rc 와 파일별
  실패 줄 수는 보조 지표다(줄 수만 비교하면 사라진 실패 자리에 새 실패가 들어와도 같은 수가 된다).
- **AC13** — 새 락은 전부 커밋 뒤 변이를 넣어 RED 를 확인했다(양성 대조 포함).
- **AC14** — 수동 e2e 1회: 스크래치 리포에서 **워크트리의 수정된 플러그인을 `claude --plugin-dir
  <워크트리>/plugins/spec-distill` 로 실어** 짧은 `/interview` → brainstorming 을 돌려, 오케스트레이터가
  writing-plans 전에 `reviewing-spec` 을 부르는지 관찰하고 결과를 PR 에 적는다. 부르지 않았으면 그 사실을 그대로
  적는다. **통과 조건(D11)**: 옵션 ②(바로 brainstorming) 경로에서 writing-plans 전에 `reviewing-spec` 호출이
  관찰돼야 한다. 관찰되지 않으면 §3.1 의 핸드오프 문구를 보강하고 다시 관찰한다 — 최대 2회. 그래도 관찰되지 않으면
  머지 전에 사용자가 결정한다(머지 보류 / 한계로 기록하고 진행). 옵션 ①(`/compact` 후) 경로는 compact 요약이
  운반자라 손실이 있을 수 있으므로(`finishing.md:347` 「사람이 유일한 운반자다」) 관찰·기록만 하고, 두 경로의 결과를
  PR 에 구분해 적는다. **교란 배제**: 세션 시작 때 **이 변경에만 있는** 표식으로 새 판이 실렸는지 확인한다 — 실린 spec-distill 의 경로가 워크트리이고 그 `hooks/hooks.json` 에 `Stop` 항목이 없어야 한다. agent 이름(
  `doc-critic` 있음 · `spec-reviewer` 없음)은 표식이 못 된다 — base `c7b4f580` 도 그 조건을 만족하면서 Stop 훅을 싣는다(옛 판의 그
  훅이 스스로 `reviewing-spec` 을 강제할 수 있다). 표식이 확인되지 않으면 그 관찰은 무효다. 확인 방법(세션 안에서 무엇을 보고 PR 에 무엇을 남기는가)은 plan 이 정한다. superpowers 는 사용자의 기존
  설치를 쓴다 — `CLAUDE_CONFIG_DIR` 격리 설치는 superpowers 까지 빠져 brainstorming 을 부를 수 없으므로 쓰지 않는다.
- **AC15** — README·CHANGELOG 가 §6 대로 갱신되고, spec-distill 은 major, quality-gates 는 patch 로 bump 된다.
- **AC16** — `reviewing-spec` 의 게이트 없는 종료 경로 둘(kill switch — 진입 검사 실패 포함 · 대상 경로 부재 — 인자 없음 미선택 포함)의 advisory 가
  각각 §3.2 의 복귀 지시로 끝나고, §3.1 ② 의 호출 프롬프트가 같은 분기를 싣는다.

## Files to Modify

**삭제** — `plugins/spec-distill/`:
- `hooks/review-dispatch.py`
- `scripts/arm_ledger.py` · `scripts/discover_candidates.py` · `scripts/parse_spec_structure.py` ·
  `scripts/resolve_mode.py` · `scripts/ambiguity-blacklist.txt`
- `templates/spec-template.md`
- `tests/test_arm_ledger.py` · `tests/test_arm_ledger_timing.sh` · `tests/test_arm_once.sh` ·
  `tests/arm_test_helpers.sh` · `tests/test_discover_candidates.py` · `tests/test_discovery_driven_dispatch.py` ·
  `tests/test_parse_spec_structure.sh` · `tests/test_resolve_mode_scope.sh` · `tests/test_review_dispatch.sh` ·
  `tests/test_review_dispatch_design_mandate.sh` · `tests/test_review_dispatch_disposition.sh` ·
  `tests/test_stop_absorbs_validation.py` · `tests/test_write_path_behavior.sh`
- `tests/fixtures/`: `2026-05-17-test-design.md` · `spec-valid.md` · `spec-missing-goals.md` ·
  `spec-ambiguity-line12.md` · `spec-ambiguity-escaped.md` · `design-no-frontmatter.md` · `design-tbd.md`

**삭제** — `shared/tests/fixtures/adjudication/`: `block_disposition_decoy.py` · `run_block_disposition_count.py`

**신설** — `plugins/spec-distill/scripts/review_entry.py`, 그 단위 테스트(훅 테스트의 `TestRetiredSwitchAdvisory`
를 옮겨 온다), 부재·연결 지점 문구 락(이름은 plan).

**수정** — `plugins/spec-distill/`:
- `hooks/hooks.json` · `hooks/session-end-cleanup.py` · `scripts/hook_common.py` · `scripts/state_path.py` ·
  `scripts/check_brief.py` · `scripts/codex_prompt_common.py`
- `skills/reviewing-spec/SKILL.md` · `skills/reviewing-brief/SKILL.md` ·
  `skills/conducting-interview/references/finishing.md` · `templates/interview-brief-template.md`
- `README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json`
- 테스트: `test_hook_output_schema.py` — `TestCrossResolverAdvisory`(`state_path` 만 쓴다)만 남긴다. 훅을 실행하는
  클래스(`TestReviewDispatchSchema` · `TestReviewDispatchMandateScope` · `TestMandateClaimsAreTrue` ·
  `TestReviewDispatchOrdering` · `TestKillSwitches` · `TestInterviewDirectionLayerScope` — 마지막은 조사상 훅만
  실행한다, plan 에서 재확인)는 삭제하고, `TestRetiredSwitchAdvisory` 는 `review_entry.py` 테스트로 옮긴다 ·
  `test_reviewing_spec_design_only.sh`(CONVERGE 락 `:46-51` 이 §4.1 이 없애는 `mode:` 매핑 문장에 기대고 헤더
  `:13-16` 이 「훅이 내는 `mode:`」를 인용한다 — 「프로필은 `design-doc.md` 고정」 문장으로 증인을 다시 건다) ·
  `test_session_end_cleanup.py`(AC3 신설 케이스 + **기존 호출 전부 격리** — `run_hook` 의 기본값이 `cwd=None` 이라
  cwd 를 넘기는 호출은 `:66` 하나뿐이다. GC 가 붙으면 나머지 호출이 러너 cwd 의 실제 상태 루트 — 워크트리에서
  돌리면 main 체크아웃의 `.claude/spec-distill/` — 에서 오래된 세션 폴더를 지운다. `run_hook` 의 기본 cwd 를 임시
  리포로 바꾸거나 기본 env 에 `DEVBREW_SKIP_HOOKS=spec-distill:spec-distill-gc` 를 넣는다. SessionEnd 훅을 띄우는
  다른 테스트도 plan 이 전수로 찾아 같은 조건을 건다) · `test_brainstorming_entry.sh` ·
  `test_brief_review_meta.sh` · `test_stale_terms.sh` · `test_readme_sync.sh` ·
  `test_reviewing_spec_state_keying.sh`(원장 호출 창을 재던 케이스는 삭제, sid · `STATE_DIR` 도출 케이스는 유지하고
  `$STATE` 단언은 `STATE_DIR` 로 재조준) · `test_handoff_context_empty_subsections.sh`(처분은 Deferred to plan) ·
  `test_handoff_conversation_reference.sh`

**수정** — `plugins/quality-gates/`: `scripts/codex_prompt_common.py` · `CHANGELOG.md` · `.claude-plugin/plugin.json`

**수정** — 리포 공용: `shared/codex/codex_prompt_common.py` · `shared/docreview/scripts/docreview_state.py` ·
`shared/tests/test_adjudication_wiring.sh` · `tools/adjudication/check_wiring.py` · `tools/adjudication/check_names.py`

**수정** — 리포 밖: 메모리 파일 둘과 `MEMORY.md` 인덱스(§7).

## Verification Plan

1. **baseline** — 착수 전 base(`c7b4f580`)에서 spec-distill · shared · quality-gates 스위트를 돌려 실패한 테스트
   식별자(파일 + 케이스) 집합(AC12 의 비교 키)과, 보조 지표로 파일별 실패 줄
   수를 기록한다. 이미 RED 인 파일은 이유를 함께 적는다.
2. **새 락** — AC3·AC4·AC5 는 행동 테스트(프로세스 실행 · 환경변수 행렬), AC1·AC2·AC7·AC8·AC16 은 정적 락이다. 정적
   락은 문구의 존재와 순서를 증명할 뿐 모델이 따르는지는 재지 못한다 — 그 한계를 락 헤더에 적는다. 부재 락에는
   양성 짝을 붙인다(`Stop` 부재 ↔ `SessionEnd` 존재, `$STATE` 부재 ↔ `STATE_DIR` 존재).
3. **mutation** — 새 락마다 커밋 뒤 변이를 넣고 RED 를 확인한다. 삭제만이 아니라 추가 · 반전 · 형태 변경으로
   흔들고, 양성 대조를 둔다. `PYTHONDONTWRITEBYTECODE=1`.
4. **구현 리뷰** — kill switch 변경은 보안 컨트롤이므로 `/qg` 에 codex 교차 리뷰를 포함한다.
5. **수동 e2e** — AC14.
6. **이 문서 자신** — 커밋 뒤 현재 설치본의 `spec-distill:reviewing-spec` 으로 리뷰한다.

## Rejected Alternatives

| 대안 | 기각 이유 |
|---|---|
| 구조 검사만 하는 가벼운 훅 유지 | C1(훅 방식 아님)과 정면 충돌 |
| 구조 검사를 `reviewing-spec` 진입부로 이전 | 「고침 → 재검사」 루프가 skill 에 생기고 상한·kill switch 가 필요해진다. `doc-critic` 층 2 와 중복. 사용자 결정 D2 |
| placeholder 4토큰 스캔만 이전 | 같은 루프 비용에 얻는 것이 `doc-critic` · brainstorming 자기검토와 겹친다 |
| 순서를 소유하는 래퍼 skill | 새 공개 표면. 래퍼 안에서도 brainstorming 의 「다른 skill 금지」 충돌이 그대로다. 직접 `/brainstorming` 경로를 덮지 못한다. 사용자 결정 D4 |
| description 만 고치기 | 인터뷰 경로를 확실히 하자는 D1 과 불일치 |
| 루트 `CLAUDE.md` 에 한 줄 | 사용자 거절(D5) |
| SessionStart · UserPromptSubmit 텍스트 주입 | 훅이다(C1) |
| deprecation window 2단계(예고 → 제거) | PR 둘 + 창 동안 훅 강제와 오케스트레이터 호출의 이중 경로. 사용자 결정 D3 |
| GC 제거 | SessionEnd 가 안 돈 세션(크래시 등)의 상태 폴더가 영구히 쌓인다 |
| GC 를 skill 진입에서 기동 | 정리가 skill 사용 여부에 묶인다 |
| `DESIGN_MODE_DISABLE` 은퇴 | 그 스위치로 리뷰를 꺼 둔 사용자에게 리뷰가 조용히 되살아난다(C3) |
| 게이트된 헤드리스 행동 테스트 | 모델 행동이라 흔들린다 — 흔들리는 RED 는 풍경이 된다. 헤드리스 `claude -p` 는 rc 0 으로 조용히 실패하는 모드가 기록돼 있다. 사용자 결정 D8 |
| brainstorming 전체 헤드리스 실행 | `AskUserQuestion` 게이트에 답할 수 없어 실행이 멈춘다 |
| 은퇴하는 `spec-distill:Stop`·`:review-dispatch` 를 끄기로 존중(수동 포함 disabled) | C3 를 온전히 지키지만 사용자가 advisory 만을 골랐다(D9) |
| 은퇴 토큰을 호출 주체로 나눔(오케스트레이터 호출이면 disabled, 사용자 직접 호출이면 advisory) | 두 호출을 기계적으로 가를 표식이 없어 skill 인자에 새 표식을 발명해야 한다 |
| `review_entry.py` 에 Law 1 필수 섹션 advisory 전용 존재 검사 | 「고침 → 재검사」 루프는 없지만, brainstorming 설계문서는 Law 1 섹션 목록을 따르지 않아 거의 매 리뷰 소음이 된다. 사용자는 구현 0 수용을 골랐다(D10) |
| 새 스위치 이름을 skill 이름(`spec-distill:reviewing-spec`)으로 | `check_names.py` 가 README 참조를 skill 이름으로도 해소해 수신처가 사라져도 매달림으로 잡히지 않는다 |
| GC 를 SessionEnd kill switch 검사 앞에 둠 | `spec-distill:SessionEnd` 로 꺼 둔 훅이 다른 세션 폴더를 지운다 — 훅은 자기 kill switch 를 거부할 수 없다(CLAUDE.md). 리뷰 라운드 1 이 선택지로 권했고 라운드 2 가 이 규칙으로 기각했다 |
| GC 를 per-session 삭제보다 앞에 둠 | 훅 timeout 을 넘기면 끝나는 세션의 자기 폴더 삭제가 끊긴다 — 우선순위가 더 높은 층을 잃는다 |
| 은퇴 Stop 토큰이 있으면 GC 도 건너뜀 | 은퇴 토큰을 SessionEnd 코드에 영구히 살려 둔다. D9 와 같은 원칙(은퇴 토큰은 옮겨간 기능을 막지 않는다)으로 두지 않는다 |
| 진입 검사 실패 시 리뷰 진행(fail-open) | 끔 여부를 모르는 채 리뷰하면 사용자가 끈 스위치를 무시할 수 있다. 끔으로 치는 비용은 자동 리뷰 한 번이고 사용자 리뷰 게이트는 남는다 |

## 알려진 한계

- **강제가 없다.** 리뷰 진입은 오케스트레이터 재량이다. 2026-08-27 이음매 감사의 원문은 「전수 조사된 19개 이음매 중 18개는 산문 지시이거나 텍스트 주입이다」 ·
  「19개 중 강제력을 가진 것은 1개」다(`docs/audits/2026-08-27-cross-skill-seam-handoff.md:27` · `:214`) — 이 변경은
  그 1개를 지운다. 다만 표준 흐름에서 훅은 이미 발동하지 않았으므로 실제로 잃는
  강제력은 작다(§Context).
- **`/brainstorming` 직접 경로는 약하다.** `reviewing-spec` description 하나가 brainstorming 본문의 「Do NOT invoke
  any other skill」과 정면으로 부딪친다. 이 경로에서는 리뷰를 건너뛰고 writing-plans 로 가는 경우가 흔할 것으로
  본다. 우회는 `/spec-distill:reviewing-spec <path>` 수동 호출이다.
- **Law 1 필수 섹션 게이트의 리포 내 구현이 0 이 된다(사용자 결정 D10 으로 수용).** CLAUDE.md Law 1 이 나열한 섹션(Context/Why · Goals ·
  Non-goals · …)을 검사하던 유일한 코드가 spec 모드 검사였다 — 생산자가 없어 발동하지 않았지만 삭제 뒤에는 코드도
  없다. 다른 플러그인(quality-gates · project-init)에 같은 게이트는 없다(project-init 의 charter 게이트는 대상이
  다르다).
- **자동 리뷰를 꺼 둔 사용자에게 리뷰가 되살아난다(사용자 결정 D9).** `spec-distill:Stop`·`:review-dispatch` 를
  설정한 사용자는 advisory 를 보고 `spec-distill:review-entry` 또는 `DESIGN_MODE_DISABLE` 로 옮겨야 한다. 옮기기 전
  첫 리뷰는 codex 호출을 포함해 한 번 돈다. 같은 사용자의 TTL-GC 도 advisory 없이 다시 돈다.
- **저자 쪽 Handoff Context 지시의 앵커가 사라진다.** `templates/spec-template.md` 는 두 락(`test_handoff_*.sh`)이
  저자 쪽 Handoff Context 계약(세 라벨 · 「대화 컨텍스트 가정 금지」)의 정답 출처로 쓰던 파일이다. brainstorming 은
  그 템플릿을 읽지 않으므로 실제 저자에게 닿던 지시는 아니었지만, 삭제 뒤에는 그 계약이 리뷰어 쪽(`design-doc.md`
  프로필의 `handoff_incomplete`)에만 남는다.
- **deprecation window 면제의 근거가 약하다.** 리포가 PUBLIC 이라 누구든 마켓플레이스로 추가할 수 있고, fork 0 ·
  star 0 은 「설치가 없다」의 증명이 아니다.

## Concrete Next Action

다음 단계: `superpowers:writing-plans` — 입력은 이 문서
(`docs/superpowers/specs/2026-09-10-spec-review-hook-removal-design.md`). 그 전에 이 문서를
`spec-distill:reviewing-spec` 으로 리뷰하고 그 승인 게이트를 거친다.

## 결정 기록

사용자 결정(2026-09-10, 이 세션):

| # | 질문 | 결정 |
|---|---|---|
| D1 | 오케스트레이터 진입이 덮을 입구 | 둘 다 — 인터뷰 경유는 핸드오프 지시로 확실히, `/brainstorming` 직접은 description 으로 최선 노력 |
| D2 | 훅의 결정론 구조 검사 | 삭제 |
| D3 | one-minor deprecation window | 면제·한 번에 제거 + 은퇴 토큰 advisory |
| D4 | 접근 | A — 기존 이음매에 지시 문장 |
| D5 | 루트 `CLAUDE.md` 한 줄 | 적지 않는다(D4 에서 고른 CLAUDE.md 줄을 섹션 2 검토 때 철회) |
| D6 | 설계 섹션 1 | 승인 — GC→SessionEnd · `DESIGN_MODE_DISABLE` 존중 · 배선 락 재계수 · README 은퇴 절 · 인용 정정(quality-gates bump 포함) |
| D7 | 설계 섹션 3 | 승인 |
| D8 | 핵심 주장의 행동 검증 | 수동 e2e 1회 |
| D9 | 은퇴하는 `spec-distill:Stop`·`:review-dispatch` (리뷰 라운드 1 이후) | advisory 만 — 리뷰를 막지 않는다. 이 토큰 사용자에게 리뷰가 되살아나는 것을 수용(C3 의 명시적 예외) |
| D10 | Law 1 필수 섹션 게이트의 리포 내 구현 0 (리뷰 라운드 1 이후) | 수용 — CHANGELOG·알려진 한계에 기록 |
| D11 | AC14 통과 기준 (리뷰 라운드 1 이후) | ② 경로 호출 관찰 필수. 실패하면 핸드오프 문구 보강·재관찰 최대 2회, 그래도 실패면 머지 전 사용자 결정. ① 경로는 관찰·기록 |
| D12 | 리뷰 라운드 3 반복 지적 게이트 | ③ 수정 필요 — 리뷰대로 저자가 수정(틀린 문장 수정 + 검증 절차 세부는 plan 요구로), 수정 뒤 재리뷰 1회 |

오케스트레이터가 정하고 사용자에게 알린 것(되돌리려면 괄호 안의 한마디):

| 정한 것 | 근거 |
|---|---|
| 새 스위치 `spec-distill:review-entry` 신설 (「새 토큰 없이」) | 공용 헬퍼가 이름을 요구한다. 이름은 스크립트 이름을 따른다(GC 선례 `spec-distill-gc`) — 처음 정한 `spec-distill:reviewing-spec` 은 skill 이름과 같아 이름 락이 수신처 소실을 못 잡는다(리뷰 라운드 1 지적) |
| 은퇴 advisory 의 세션당 1회 마커 폐지 | 리뷰 호출마다 한 번만 돈다 |
| v0.36.0 은퇴 토큰 넷을 advisory 대상에 포함 (「이번 두 개만」) | 지금의 그 advisory 문구가 훅 삭제 뒤 거짓이 된다 |
| 다른 리포용 CLAUDE.md 안내를 README 에서 제외 (「README 안내는 남겨라」) | devbrew 가 스스로 하지 않는 일을 권하는 문장이 된다(D5) |
| `check-born` → 원장 없는 미커밋 advisory | 사용자에게 보이던 효과만 남기고 원장 의존을 끊는다 |
| GC 순서: SessionEnd kill switch → per-session 삭제 → `finally` 에서 GC (리뷰 라운드 2) | 훅은 자기 kill switch 를 거부할 수 없고(CLAUDE.md), timeout 에 잃는 층은 우선순위가 낮은 GC 여야 한다 |
| 진입 검사 실패는 끔으로(fail-closed) (「실패하면 리뷰를 진행하라」) | 끈 스위치를 무시할 위험이 자동 리뷰 한 번을 잃는 비용보다 크다 |
| 은퇴 Stop 토큰 사용자의 TTL-GC 재개를 D9 원칙으로 수용 (「은퇴 Stop 토큰이 있으면 GC 도 건너뛰어라」) | 같은 토큰 · 같은 원칙. advisory 가 없어 C3 의 두 절반을 모두 포기한다는 점을 C3 와 알려진 한계에 적었다 |
| 인자 없음 미선택을 Step A 「대상 경로 부재」로 흡수 (리뷰 라운드 3) (「정본에 셋째 경로를 추가하라」) | 게이트 정본과 채택자 락(`test_proceed_gate_adopters.sh`)을 건드리지 않는다. 고르지 않은 경로는 대상이 없는 것과 같다 |

### Deferred to plan

- `test_dispatch_name_defined.sh` 가 README 은퇴 절의 토큰 표기를 어떻게 다루는지 확인하고 표기를 정한다.
- `codex_prompt_common.py` 사본 일치 검사가 `# copy-of` 마커를 어떻게 비교하는지 확인한다(정본 blob 이 사본과 다르다).
- `check_wiring.py` 의 `EXEMPT_BASELINE` · `COMP_BASELINE` 재계수.
- `review_entry.py` 의 정확한 CLI 형태 · 종료 코드, README kill switch 표 문구.
- 삭제 오라클(AC2)의 개념 별칭 최종 목록.
- 핸드오프 문구 넷의 확정 문안과, `finishing.md` ① 템플릿을 고정하는 기존 락의 갱신.
- (닫힘 — 리뷰 라운드 2) `.claude-plugin/marketplace.json` 의 spec-distill 항목에는 version 필드가 없어 bump 대상이 아니다.
- baseline 실행 명령(spec-distill 의 python 테스트는 `-m unittest` 로만 돈다).
- 두 `test_handoff_*.sh` 의 처분 — 저자 쪽 앵커(`spec-template.md`)를 잃는다. 리뷰어 쪽(`design-doc.md` 프로필
  `handoff_incomplete`) 단독 앵커로 재조준하거나 삭제한다. 어느 쪽이든 잃는 것(저자 쪽 절반)을 커밋 메시지와
  CHANGELOG 에 적는다 — 조용히 약해지지 않게.
- AC14 새 판 표식의 확인 방법 — 세션 안에서 무엇을 보고(로드된 플러그인 경로 · 활성 훅 목록) PR 에 무엇을 남기는가.
- AC2 의 별칭 목록과 별칭 검사 범위의 확정.
