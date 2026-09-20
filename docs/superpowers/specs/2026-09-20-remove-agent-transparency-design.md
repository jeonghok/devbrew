---
name: remove-agent-transparency
type: design
created_at: 2026-09-20
source_interview: 없음 — /brainstorming 직접 진입. 사용자 결정은 「결정 기록」 절이 정본이다
next_phase: superpowers:writing-plans
---

# agent-transparency 플러그인 제거 — 애초에 없던 상태로 · Design

> 지우는 것은 플러그인 디렉토리 하나가 아니라, 그 플러그인 때문에 리포의 다른 곳에 생긴 줄 전부다.
> 이력은 이력으로 남기고, 흔적은 없앤다.

## Handoff Context

**TL;DR** — `plugins/agent-transparency/` 와 마켓플레이스 항목을 지운다. 그리고 이 플러그인 **때문에** 리포의
다른 곳에 생긴 줄을 이 플러그인이 없던 상태로 되돌린다. 무엇이 그런 줄인지는 §2 의 판정 규칙(R1–R4)이 정하고,
목록의 확정은 plan 의 첫 Task 가 도출 절차(S1–S3)를 돌려서 한다 — 지금까지 도출된 것은 T1–T9 다. 이력 문서와
과거 시점의 개수 서술은 건드리지 않는다.
남는 플러그인의 파일은 하나도 편집하지 않으므로 버전 bump·CHANGELOG 는 없다.

**Implicit context** —
(1) 사용자 요청 원문: 「agent-transparency 플러그인을 제거하자」. 이유는 D1(안 쓴다 · 무게 감축).
(2) 판정 기준은 D3 의 사용자 원문 「어떤게 가장 없던 상태 디폴트로 원복하는거야?」다. 흔적은 "이 플러그인을
**이름으로 부르는** 줄"이 아니라 "이 플러그인 **때문에 생긴** 줄"이다. 이름이 박히지 않은 흔적(T3 정규식 갈래,
T7 하한 값, T8 `context: fork` 주석, T9 이름 경계)은 개념 별칭 grep 에 걸리지 않고 출생 추적(`git log -S` ·
이력 문서 역추적)으로만 드러났다. 반대로 과거 시점의 개수·순번(「20 개 agent」, 「18 중 16」 등)은 이 플러그인을
셌더라도 이력으로 둔다(D6).
(3) 작업 위치: 브랜치 `feature/remove-agent-transparency`, 워크트리
`/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency`, base `84222ee1`(#157 머지).
메인 체크아웃(`feature/framing-intent-drift`, PR #158)은 동시 세션이 편집 중이라 **건드리지 않는다**. #158 은 이
설계가 고치는 파일과 겹치지 않고 T7 의 코퍼스 수도 바꾸지 않는다(실측). 다만 #158 은 `framing-requests/SKILL.md`
의 dispatch 를 둘에서 셋으로 늘리므로, 그쪽이 먼저 머지되면 **AC7 의 인쇄 기대값이 21/21 이 아니라 22/22 가
된다** — 「Verification Plan」 1 이 base 이동 시 그 값을 다시 잰다.
(4) 영향 측정은 끝났다 — 버리는 워크트리에서 base 에 삭제만 적용하고 스위트 252개를 전후로 비교했다.
원자료는 job 임시 디렉토리 `/Users/jeonghokim/.claude/jobs/f7a2563a/tmp/`(`run_all.sh` · `analyze.py` ·
`baseline/` · `after/` · `diff-summary.txt` · `sweep-after.txt`)에 있고 job 이 지워지면 사라진다. 러너는
「Verification Plan」 2 로 재구성할 수 있다.
(5) 이 문서는 인터뷰 없이 쓰였다. design-doc 프로필의 층 1 정답 출처(브리프 §2)가 없으므로 「결정 기록」이
그 자리를 대신한다.
(6) plan 이 정할 것은 문서 끝 `### Deferred to plan` 에 모여 있다.

## 목차

- [Goal](#goal)
- [Context / Why](#context--why)
- [Goals](#goals)
- [Non-goals](#non-goals)
- [Constraints](#constraints)
- [설계 (Architecture)](#설계-architecture)
  - [1. 삭제](#1-삭제)
  - [2. 흔적 — 판정 규칙과 도출 절차](#2-흔적--판정-규칙과-도출-절차)
  - [3. 불변인 것](#3-불변인-것)
- [Acceptance Criteria](#acceptance-criteria)
- [Files to Modify](#files-to-modify)
- [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives)
- [알려진 한계](#알려진-한계)
- [Concrete Next Action](#concrete-next-action)
- [결정 기록](#결정-기록)
  - [Deferred to plan](#deferred-to-plan)

## Goal

리포의 살아 있는 표면을 agent-transparency 가 devbrew 에 존재한 적 없는 상태로 되돌린다.

## Context / Why

**쓰이지 않는다.** 로컬 `~/.claude/settings.json` 의 `enabledPlugins` 에 없고 `installed_plugins.json` 에도 기록이
없다. 캐시 `~/.claude/plugins/cache/devbrew/agent-transparency/`(0.3.2 · 0.4.0, 1.0M)만 고아로 남아 있고,
A/B 산출물 디렉토리 `~/.claude/agent-transparency-ab/` 는 존재하지 않는다.

**그런데 유지비는 든다.** 34 파일(output style · command · skill · agent · 준비 스크립트 각 1, 나머지는
테스트·A/B 하니스·픽스처·문서)이 `plugins/*` 글롭을 쓰는 공용 락들에 계속 잡힌다. agent 20 중 1, dispatch
자리 22 중 1이 이 플러그인 몫이다.

**이 플러그인이 유일한 실례인 구조가 둘 있다.** output style 컴포넌트와 frontmatter `agent:` dispatch 표기다.
저술 가이드와 dispatch 락이 그 실례에 맞춰 늘어나 있었다.

**측정한 영향 범위** (base `84222ee1` 에 삭제만 적용):

| 종류 | 자리 |
|---|---|
| 새로 RED | `shared/tests/test_plugin_root_no_cwd_fallback.sh:472` 코퍼스 하한 `≥30` — 31 → 29 |
| GREEN 인 채 거짓이 됨 | `docs/plugin-authoring.md:24` · `:49–55`, `shared/tests/test_dispatch_disposition.sh:143–145`, `tools/adjudication/check_slots.py:46` (같은 파일 `:26` 「20 개 agent」는 과거 시점의 개수 — D6) |
| GREEN 인 채 아무것도 안 잼 | `shared/tests/test_dispatch_disposition.sh:85` 의 `agent:` 갈래 — 코퍼스 유일 실례가 `briefing-current-state/SKILL.md:6` |
| 측정 뒤 발견 | `tools/adjudication/check_names.py:19` docstring 이 위 정규식을 글자 그대로 인용 |
| 설계 리뷰가 발견 | `shared/tests/test_agent_input_slots.sh:86` · `shared/tests/fixtures/adjudication/run_slots.py:34` 주석의 `context: fork` 갈래 — 리포 유일 실례가 `briefing-current-state/SKILL.md:5` |
| 선재 RED (전후 동일) | 7 파일 — 실패 케이스 집합과 파일별 실패 줄 수가 같다. 목록은 「Verification Plan」 1 |
| 모델 호출 | claude/codex stub 호출 0 |

## Goals

- **G1.** 플러그인 디렉토리와 마켓플레이스 항목을 지운다.
- **G2.** 이 플러그인 때문에 생긴 줄을 §2 의 규칙 R1–R4 로 가려 없던 상태로 되돌린다. 목록은 도출 절차 S1–S3
  이 확정한다(지금까지 T1–T9).
- **G3.** 스위트에 새 실패가 0이다.
- **G4.** 제거 뒤 살아 있는 표면(LIVE)에 이 플러그인의 개념 별칭이 0건이다. 단, 보존하는 이력 spec 을 가리키는
  경로 리터럴은 실재하는 파일의 인용이라 흔적이 아니다(D7, AC4).

## Non-goals

- **이력 문서** — **이 제거 작업 이전부터 리포에 있던 것**을 말한다(이 설계문서와 plan 은 이 작업의 산출물이라
  해당하지 않는다). 각 플러그인 `CHANGELOG.md`, `docs/archive/**`, `docs/audits/**`,
  `docs/superpowers/{specs,plans,interview}/**` 는 과거에 참이었던 서술이다. 특히
  `docs/superpowers/specs/2026-08-05-agent-transparency-design.md` 는 **제자리에 그대로** 둔다 —
  `shared/tests/fixtures/seamprobe/MEASUREMENT.md:22` · `:178–184` 가 이 문서를 경로와 줄 번호로 인용한다.
  옮기면 경로가 깨지고, 상단에 "제거됨" 배너를 달면 줄 번호가 밀려 인용이 조용히 어긋난다.
- **과거 시점의 개수·순번**(D6). 이 플러그인을 셈에 넣었더라도 과거 사건의 개수는 이력으로 둔다 —
  `shared/tests/test_dispatch_disposition.sh:6–8`(「5표기 중 1개만」, 「표기 ②④를 놓쳐 18 중 16」) · `:84`
  (「19번째 dispatch」) · `:101`(「A①(17 != 18)」) · `:292`(「오늘 18/18」), `tools/adjudication/check_slots.py:26`
  (「20 개 agent」), `shared/tests/variant_of.py:66`(「실제 agent 파일 24개 … 에서 도출했다」). 그때의 사실이라
  고쳐 쓰면 이력의 날조다. 지우는 것은 **없어진 실체를 이름으로 가리키는 줄**뿐이다(T6 의 bullet).
- **리포 전역 스윕이 남긴 변경.** 이 플러그인을 함께 건드린 스윕 커밋(모델 키 제거 `eef761e0`, UTF-8 명시
  `8443b59b`, `tools:` 어순 통일 `e359c841` 등)이 다른 파일에 남긴 변경은 이 플러그인과 무관하다. 원복은 커밋
  revert 가 아니라 "이 플러그인 때문에 생긴 줄"의 삭제다.
- **도출값만 줄어드는 락.** agent 수 20→19, dispatch 22→21, 코퍼스·단언 수 등은 하드코딩이 아니라 도출이라
  고칠 것이 없다.
- **여유를 둔 붕괴 바닥**(R3 · D11). 모집단에 이 플러그인이 들어갔더라도 여유를 두고 박은 하한은 둔다 —
  `test_variant_of_contract.sh:379` 의 `≥20`(핀 당시 24, 여유 4) 등. 훑은 목록과 판정은 §2 의 S3 표에 있다.
  `plugins/quality-gates/tests/test_codex_runner_no_effort_pin.sh:69` 의 `≥4` 는 R1 밖이다 — 2026-08-04
  (`ecb5bf26`), 이 플러그인이 생기기 전에 플러그인 4개로 박았다(확인함). 제거 뒤 여유가 0이 되지만 그대로 둔다.
  하한이 현재 수와 같다는 것은 하나라도 더 사라지면 즉시 알린다는 뜻이다.
- **루트 `README.md` 의 선재 stale 플러그인 표**(원래 quality-gates · project-init 만 있음).
- **리포 밖 정리.** 고아 캐시 삭제와 메모리 갱신은 머지 후 사용자에게 제안만 한다.

## Constraints

- **C1.** 메인 체크아웃을 건드리지 않는다. 모든 편집·실행은 위 워크트리의 절대경로로 한다.
- **C2.** 삭제와 흔적 정리는 **한 커밋**이다. 중간 상태가 RED 이기 때문이다 — T3 만 먼저 지우면 이 플러그인의
  처분 앵커가 짝을 잃어 축 A① 가 22 ≠ 21 로, 플러그인만 먼저 지우면 T7 하한이 RED 다.
- **C3.** 남는 `plugins/*` 파일을 편집하지 않는다. 편집 대상은 `.claude-plugin/` · `docs/` · `shared/` · `tools/`
  뿐이다. plan 이 `plugins/*` 편집이 필요하다고 판명하면 그 플러그인은 같은 커밋에서 bump 한다.
- **C4.** 이력은 고쳐 쓰지 않는다.
- **C5.** 흔적의 판정 근거는 **출생 원인**이다 — 출생 커밋(`git log -S`)이나 설계 문서의 전수 조사로 이 플러그인이
  원인임을 댈 수 있어야 한다. 이름이 박혀 있다는 것만으로는 흔적이 아니고(이력일 수 있다), 이름이 없다는 것만으로
  흔적이 아닌 것도 아니다(T3 · T7 · T8).

## 설계 (Architecture)

### 1. 삭제

- `plugins/agent-transparency/` 전체(34 파일).
- `.claude-plugin/marketplace.json` 의 `agent-transparency` 객체와, 앞 객체(`plugin-audit`) 뒤의 쉼표.

### 2. 흔적 — 판정 규칙과 도출 절차

**목록이 아니라 규칙이 정본이다(D13).** 라운드 1·2 의 리뷰가 손으로 적은 목록에서 빠진 흔적을 연달아 찾았다 —
열거는 사각지대를 남긴다. 그래서 설계는 규칙과 절차를 고정하고, 목록의 확정은 plan 의 첫 Task 가 절차를 끝까지
돌려서 한다. 아래 표는 **지금까지 도출된 것**이지 닫힌 목록이 아니다.

**확정 표의 정본은 plan 이다(D15).** 이 문서는 규칙·절차와 출발점 표를 갖고, 절차가 확정한 표는 plan 문서에
산다 — 그래서 구현 중에 이 설계문서를 다시 열 필요가 없다. AC3·AC8 의 대상은 그 확정 표다.

**판정 규칙**

- **R1 출생 원인**(C5). 이름이 박혔는지가 아니라 이 플러그인 **때문에 생겼는지**다. 근거는 출생 커밋
  (`git log -S`)이나 이력 설계 문서의 전수 조사여야 한다.
- **R2 개수는 이력**(D6). 과거 시점의 개수·순번은 이 플러그인을 셌더라도 둔다. 지우는 것은 없어진 실체를
  이름으로 가리키는 줄뿐이다.
- **R3 하한**(D11). 모집단에 이 플러그인 파일이 들어간 하한 중 **핀 당시의 수 − 1**(여유 1)로 박은 것만
  흔적이다. 여유를 둔 붕괴 바닥은 둔다 — 그 값이 재는 것은 「도출이 통째로 무너졌는가」이지 모집단의 크기가 아니다.
- **R4 매칭 폭**(D10). 락의 표기·경계가 이 플러그인의 줄 때문에 넓어졌고, 제거 뒤 그 넓힘의 실례가 0이면
  흔적이다. 대가(미래의 표기 변형에 대한 fail-open)는 ∀ 도출(`ZERO_AGENTS`)이 일부만 받는다 — 「알려진 한계」.

**도출 절차** — plan 의 첫 Task 가 셋을 모두 돌리고, 나온 항목을 R1–R4 로 분류해 표를 확정한다. 규칙이 가르지
못하는 항목은 사용자 결정으로 올린다.

- **S1 이름.** LIVE 전수에 개념 별칭 `git grep`(목록은 AC4).
- **S2 역추적.** 이력 문서(`docs/superpowers/{specs,plans}` · `docs/archive` · 각 `CHANGELOG.md`)에서 이
  플러그인의 식별자·경로를 **근거로 든** 자리를 찾고, 그 근거가 떠받치는 live 파일의 줄로 따라가 R1·R4 로
  분류한다. T3(설계 `2026-08-22-…:84`) · T8(`quality-gates/CHANGELOG.md:235`) · T9(설계 `2026-08-22-…:350`)
  셋이 이 경로로 나왔다 — 별칭 grep 으로는 셋 다 안 나온다.
- **S3 숫자.** 모집단에 이 플러그인 파일이 들어가는 락의 핀 숫자를 전수로 모아 R3 으로 분류한다. 지금까지 훑은
  것은 표 아래에 있다.

**지금까지 도출된 것**

| # | 자리 | 출생 | 지금 | 없던 상태 |
|---|---|---|---|---|
| T1 | `docs/plugin-authoring.md:49–56` output style 절(도입 줄 · bullet 셋 · 「output style 은 subagent 에 닿지 않는다」 단락과 사이 빈 줄) | `8303cc24` — 이 플러그인 PR 이 추가 | 삭제된 경로로 가는 링크 + 리포에 사례 없는 컴포넌트 설명 | 절 전체 삭제. 앞 단락(`plugin-dev` 문법·정책)과 뒤 `**Merge 전:**` 단락 사이에 빈 줄 하나 |
| T2 | `docs/plugin-authoring.md:24` model 재량 문단의 예시 목록 | `df47c49a` | `smoke-probe`, `transcript-reader`, `pr-understanding-builder` | `transcript-reader` 를 빼고 둘 |
| T3 | `shared/tests/test_dispatch_disposition.sh:85` `NOTATION` 의 `\|^\s*agent:\s` 갈래 | `8b07f9f3` — 설계 `2026-08-22-subagent-adjudication-contract-design.md:84` 의 표기 전수 조사 ④. 그 유일 실례가 이 플러그인 | 실례 0 — 아무것도 재지 않는다 | `re.compile(r'subagent_type:\|agentType:\|Agent\(')` |
| T4 | 같은 파일 `:142–145` 「아래」 방향의 근거 문단(앞의 빈 `#` 줄 포함) | `f835f31f` | 삭제된 파일을 근거로 인용 | 네 줄 삭제. 규칙 자체는 `:137–138` 에 그대로 남는다 |
| T5 | `tools/adjudication/check_names.py:19` docstring 의 표기 필터 인용 | T3 의 글자 그대로 사본 | `^\\s*agent:` 포함 | T3 와 같은 세 표기만 인용 |
| T6 | `tools/adjudication/check_slots.py:46` `transcript-reader.inventory` bullet | 전수 스윕이 이 플러그인의 agent 슬롯을 분류 | 없어진 agent·스크립트를 이름으로 가리킴 | bullet 삭제. 같은 스윕의 「20 개 agent」(`:26`)는 과거 시점의 개수라 둔다(D6) |
| T7 | `shared/tests/test_plugin_root_no_cwd_fallback.sh:472` 코퍼스 하한 `-ge 30` | `aff6a8ee` — 코퍼스 31(이 플러그인의 `briefing-current-state/SKILL.md` · `commands/standup.md` 포함)에 여유 1 | 29 → RED | `-ge 28` — 29 에 원저자와 같은 여유 1 |
| T8 | `shared/tests/test_agent_input_slots.sh:86` · `shared/tests/fixtures/adjudication/run_slots.py:33–34` 주석의 「Workflow JS 나 (skill frontmatter 의) `context: fork` 에 있는 agent」 | 최종 리뷰 K4(`plugins/quality-gates/CHANGELOG.md:235–237`) — 「못 잼」 넷 중 `context: fork` 쪽이 이 플러그인의 `transcript-reader` 하나 | 리포에 실례 없는 갈래를 서술 | 「`context: fork`」 갈래를 걷고 「Workflow JS」만 남긴다 |
| T9 | `shared/tests/test_dispatch_disposition.sh:87–92` 이름 경계 `PRE`/`POST` 의 줄머리·공백 허용과 그 주석 | 설계 `2026-08-22-subagent-adjudication-contract-design.md:350–352` — 「표기 ④는 따옴표가 없으므로 (`agent: agent-transparency:transcript-reader`) 따옴표를 경계로 쓸 수 없다」 | 그 허용의 실례가 0 — 남는 dispatch 21줄은 이름이 전부 따옴표 안이다(실측) | 경계를 따옴표(와 접두사 콜론)로 좁히고 주석에서 ④ 근거를 걷는다. 정확한 문자 집합은 plan 이 21줄 실측으로 확정한다 |

**S3 이 지금까지 훑은 하한**(R3 판정):

| 하한 | 핀 당시 | 판정 |
|---|---|---|
| `shared/tests/test_plugin_root_no_cwd_fallback.sh:472` `-ge 30` | 코퍼스 31 (`aff6a8ee`) — 여유 1 | **흔적 = T7** |
| `shared/tests/test_variant_of_contract.sh:379` `-ge 20` | agent 파일 24 (`fdb3ac3d`, 2026-09-11) — 여유 4 | 둔다 (붕괴 바닥) |
| `plugins/quality-gates/tests/test_codex_runner_no_effort_pin.sh:69` `-ge 4` | 플러그인 4, 이 플러그인 **이전** (`ecb5bf26`, 2026-08-04) | 둔다 (R1 밖. 제거 뒤 여유 0 은 가장 촘촘한 상태다) |
| `test_plugin_root_no_cwd_fallback.sh` 의 `n_a2 -ge 22` · `n_a3` · `N_GUARD_FENCE_MIN=45` | — | 둔다 — 이 플러그인은 reference 펜스·가드 펜스가 없어 모집단에 기여 0(측정에서 값 불변) |
| `check_wiring.EXEMPT_BASELINE=11` · `check_slots.EXEMPT_SLOTS_BASELINE=5` · `COMP_BASELINE=40` · no_new_duplication 붕괴 바닥 50 | — | 둔다 — 측정에서 값 불변(기여 0) |

### 3. 불변인 것

- dispatch 락의 **위치 규칙**(앵커는 dispatch 줄 «아래» `WINDOW` 줄 안)은 그대로다. 근거 문단만 사라진다 — 규칙은
  축 A② 본문(`:137–138`)이 이미 선언한다.
- dispatch 락의 **∀ 도출**(`ZERO_AGENTS`)은 그대로다. T3 이후에도 frontmatter `agent:` 로만 불리는 새 agent 는
  dispatch 0건으로 RED 가 된다(「알려진 한계」 참고).

## Acceptance Criteria

- **AC1.** `git ls-files plugins/agent-transparency` 가 0줄이다.
- **AC2.** `.claude-plugin/marketplace.json` 이 JSON 으로 파싱되고, `plugins[].name` 이 정확히
  `quality-gates, project-init, spec-distill, plugin-audit`(이 순서)다.
- **AC3.** **plan 의 확정 표**(D15 — 정본)의 모든 행이 그 표의 「없던 상태」 열과 일치한다. 그 표는 §2 표의
  T1–T9 를 전부 포함하고, 도출 절차가 더 낸 행이 있으면 함께 담는다. 아래 세부는 T1–T9 의 관측 형태다.
  - T1: `docs/plugin-authoring.md` 에 `output style` · `output-styles` · `keep-coding-instructions` ·
    `force-for-plugin` 이 0건이고, `**Merge 전:**` 단락이 남아 있다.
  - T2: 24행 문단에 `transcript-reader` 가 없고 `smoke-probe` · `pr-understanding-builder` 는 있다.
  - T3: `NOTATION` 정규식 리터럴이 정확히 `subagent_type:|agentType:|Agent\(` 다.
  - T4: 파일에 `briefing-current-state` 가 0건이고, 축 A② 의 「바로 아래」 규칙 문장은 남아 있다.
  - T5: `check_names.py` 에 `agent:` 표기 인용이 0건이고, 나머지 세 표기 인용은 남아 있다.
  - T6: `check_slots.py` 에 `transcript-reader` · `prepare_standup` 이 0건이고, 「20 개 agent」는 그대로 있다.
  - T7: 하한 리터럴이 `-ge 28` 이다.
  - T8: 두 파일에 `context: fork` 가 0건이고, 「Workflow JS」 서술은 남아 있다.
  - T9: `PRE`/`POST` 리터럴에 줄머리(`^`)와 공백(`\s`) 갈래가 없고, 주석에 표기 ④ 근거가 0건이며, 그러고도
    AC7 의 dispatch 수가 유지된다(경계를 좁혀 잃은 줄이 없다는 증거).
- **AC4.** 개념 별칭 `git grep -n -I -i` 가 LIVE 에서 0건이다. LIVE 는 이력 분류(`**/CHANGELOG.md`,
  `docs/archive/**`, `docs/audits/**`, `docs/superpowers/{specs,plans,interview}/**`) 밖의 모든 추적 파일이다.
  별칭: `agent-transparency` · `agent_transparency` · `transcript-reader` · `briefing-current-state` ·
  `prepare_standup` · `standup` · `ab_gate` · `ab_judge` · `ab_seal` · `ab_driver` · `AT_ORACLE` ·
  `comprehension debt` · `comprehension-debt` · `이해부채` · `output-styles` · `output style` ·
  `force-for-plugin` · `keep-coding-instructions` · `context: fork`.
  **예외는 하나다(D7)** — 경로 리터럴 `docs/superpowers/specs/2026-08-05-agent-transparency-design.md` **안의**
  일치. 보존하는 이력 spec 을 가리키는 인용이다(오늘 `shared/tests/fixtures/seamprobe/MEASUREMENT.md:22` · `:178`).
  판정은 줄 단위로 그 리터럴을 지운 뒤 남은 부분에 별칭이 없는지로 한다 — 파일을 통째로 빼지 않으므로 같은
  파일에 새로 생기는 다른 언급은 여전히 걸린다.
- **AC5.** 전체 스위트 전후 대조에서 base 대비 **새 실패 케이스 집합이 공집합**이고, 파일별 실패 줄 수가
  같다(선재 RED 7 파일 포함). claude/codex stub 호출은 0이다.
- **AC6.** T7 하한의 양성 대조(D9 · D14): 커밋 뒤, 락의 코퍼스 글롭 안 마크다운 2개를 `git rm`(index 와 작업
  트리 **둘 다**) 으로 지워 27개로 만든다. 락의 코퍼스는 `git ls-files --cached --others --exclude-standard`
  (`test_plugin_root_no_cwd_fallback.sh:130–131`)라 **반쪽 삭제는 둘 다 아무것도 재지 않는다** — 작업 트리에서만
  지우면 경로가 `--cached` 로 계속 나와 파서가 없는 파일을 열다 죽고(그 ✗ 는 하한을 재지 않은 「0개뿐」이다),
  index 에서만 지우면(`git rm --cached`) 파일이 untracked 가 되어 `--others` 로 되돌아오므로 수가 29 로 남고
  ✗ 자체가 발화하지 않는다. 통과 관측은 둘이 함께다: 하한 단언의 ✗ 메시지가 「27개뿐」이고, 같은 실행에서
  「파서가 끝까지 돌았다 (rc 0)」가 ✓ 다. 복원(`git checkout HEAD --`) 뒤 같은 단언이 ✓ 이고 `git diff HEAD` 와
  `git diff --cached` 가 비었음을 확인한다.
- **AC7.** 제거 뒤 dispatch 락의 인쇄값이 `PRINT_2_dispatch` = `PRINT_3_anchors` = (제거 전 값 − 1)이고
  `ZERO_AGENTS` 가 빈 값이다 — base `84222ee1` 에서는 21/21 이다. T3 · T9 가 이 플러그인 밖의 dispatch 를 하나도
  잃지 않았다는 증거다.
- **AC8.** 도출 절차 S1–S3 을 끝까지 돌린 결과가 **plan 의 확정 표**에 담겨 있고, 그 표가 §2 표의 행을 하나도
  빠뜨리지 않는다. 절차가 새로 낸 항목은 R1–R4 로 분류돼 그 표에 들어가고, 규칙이 가르지 못한 항목은 0이거나
  사용자 결정으로 올라가 있다. 「돌렸다」의 증거는 S1 의 grep 출력, S2 가 훑은 이력 문서 히트 목록과 각 히트의
  판정, S3 의 하한 표다.

## Files to Modify

| 동작 | 파일 |
|---|---|
| 삭제 | `plugins/agent-transparency/**` (34) |
| 편집 | `.claude-plugin/marketplace.json` |
| 편집 | `docs/plugin-authoring.md` (T1 · T2) |
| 편집 | `shared/tests/test_dispatch_disposition.sh` (T3 · T4 · T9) |
| 편집 | `shared/tests/test_plugin_root_no_cwd_fallback.sh` (T7) |
| 편집 | `tools/adjudication/check_names.py` (T5) |
| 편집 | `tools/adjudication/check_slots.py` (T6) |
| 편집 | `shared/tests/test_agent_input_slots.sh` · `shared/tests/fixtures/adjudication/run_slots.py` (T8) |
| 추가 | 이 문서, 그리고 writing-plans 의 plan |

## Verification Plan

1. **base 확인과 baseline.** 착수 시 `git rev-parse origin/main` 이 `84222ee1` 이면 측정 때의 baseline 을 쓴다.
   움직였으면 `git merge-tree` 로 충돌을 보고, 새 base 에서 **셋을 다시 잰다** — ① baseline(선재 RED 집합과
   파일별 실패 줄 수) ② T7 코퍼스 수(29 가 아니면 하한 = 새 수 − 1) ③ **AC7 의 인쇄 기대값**(제거 전
   `PRINT_2_dispatch`·`PRINT_3_anchors` 를 재고 각각 − 1) ④ **AC6 의 기대 ✗ 메시지**(= 제거 후 코퍼스 수 − 2,
   base `84222ee1` 에서는 「27개뿐」). ③ 은 #158 이 `framing-requests/SKILL.md` 의 dispatch 를 둘에서 셋으로
   늘리기 때문에 실제로 움직이고, ②④ 는 코퍼스 수에 매여 함께 움직인다. base `84222ee1` 의 선재 RED 7 파일:
   `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` ·
   `plugins/quality-gates/tests/test_codex_backward_compat.sh` · `plugins/quality-gates/tests/test_runner_adapters.sh` ·
   `plugins/quality-gates/tests/test_findings_parser.sh` · `plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh` ·
   `plugins/spec-distill/tests/test_hook_output_schema.py`(NG9) · `shared/tests/test_assert_behavior.sh`(rc 0, 의도된 ✗).
2. **러너(측정과 동일).** 모두 워크트리 루트에서 돈다.
   - `.sh` — `bash <file>`. 대상은 추적 파일 중 `^(shared/tests|plugins/[^/]+/tests)/(harness/)?test_[^/]*\.sh$`.
     실패 줄 패턴 `✗|^\s*FAIL\b|^\s*not ok\b`.
   - `.py` — 파일마다 `python3 -m unittest discover -v -s <tests dir> -t <tests dir> -p <file>`. 패턴
     `^(FAIL|ERROR): `.
   - `.mjs` — `node --test --test-reporter=tap <file>`. 패턴 `not ok N -`.
   - 환경 — `PATH` 맨 앞에 `claude` · `codex` stub(인자를 로그에 적고 `exit 97`), `PYTHONDONTWRITEBYTECODE=1`,
     UTF-8 locale, 스위트마다 별도 `TMPDIR`, stdin `/dev/null`.
   - 제외 — `plugins/quality-gates/tests/spike/test_codex_json_extraction.sh`(추적 픽스처를 바꾸는 수동 spike).
3. **정적·도출 확인** — AC1 · AC2 · AC3 · AC4 · AC7 · AC8(도출 절차 S1–S3 의 실행과 증거).
4. **양성 대조** — AC6.
5. **구현 리뷰** — `/qg review` 1회(D5, Law 2).
6. **이 문서** — `spec-distill:reviewing-spec` 으로 리뷰한다.

## Rejected Alternatives

- **마켓플레이스 항목만 삭제(비공개).** 코드가 `plugins/*` 에 남아 공용 락이 계속 세고 유지해야 한다 — D1 의
  무게 감축을 이루지 못한다.
- **deprecation 창 먼저.** CLAUDE.md 의 one-minor 창은 v1.0.0 이상의 CHANGELOG 규칙 아래 있고, 이 플러그인은
  0.4.0 이다. 로컬 설치는 없다. 제3자 설치는 확인할 수 없다 — 리포가 공개라 누구든 마켓플레이스로 추가할 수 있어,
  로컬 부재는 설치 부재의 증명이 아니다(선례 `plugins/spec-distill/CHANGELOG.md:137`). 그 설치자에게 미치는 영향은
  PR 본문에 적는다(「Deferred to plan」).
- **`agent:` 갈래 유지 + 「실례 0」 공시**(처음 추천). 이 플러그인이 없던 세계의 락에는 이 갈래가 없다(D3 · D4).
- **`agent:` 갈래에 합성 fixture.** 락에 fixture 모드를 새로 들여야 해 범위가 커지고, 없던 상태 기준과도 어긋난다.
- **output style 절 보존**(플랫폼 지식이라서). 이 플러그인 PR 이 추가한 절이다(D4). 그 지식은 이력 spec 과 git
  이력에 남는다.
- **이력 spec 을 `docs/archive/specs/` 로 이동, 또는 상단에 "제거됨" 배너.** 이동은 `MEASUREMENT.md` 의 경로
  인용을, 배너는 줄 번호 인용을 깬다. 얻는 것이 없다.
- **하한 `≥25`**(처음 안). 원저자의 규칙(현재 수 − 1)과 다르다. 없던 상태 기준이면 29 − 1 이다.
- **과거 개수를 반사실로 전부 고침**(D6 에서 기각). 「18 중 16」을 「17 중 16」으로 바꾸는 식이라, 실제로 있었던
  프로토타입 실패 기록이 사실과 달라진다.
- **AC4 에서 `MEASUREMENT.md` 를 통째로 제외 · 이력 분류를 `shared/tests/fixtures/**` 로 넓힘**(D7 에서 기각). 앞은
  그 파일에 생길 새 언급을 못 보고, 뒤는 다른 픽스처의 진짜 흔적까지 가린다.

## 알려진 한계

- **T3 이후 frontmatter `agent:` dispatch 의 가시성.** 이 표기로만 불리는 새 agent 는 dispatch 0건이 되어
  `ZERO_AGENTS` 로 RED — 드러난다. 그러나 **다른 표기로도 불리는** agent 를 어떤 skill 이 frontmatter `agent:` 로
  추가 호출하면, 그 자리는 dispatch 로 세어지지 않아 처분 앵커 검사를 조용히 빠져나간다. 이 플러그인이 없던
  세계와 같은 상태다. 그 표기를 다시 들이는 PR 이 `NOTATION` 에 갈래를 더해야 한다 — 락 머리말 6–9행의
  「열거는 fail-open」 경고가 그 위험을 이미 말한다.
- ~~**T9 이후 따옴표 없는 dispatch 표기.**~~ **해당 없음 — T9 은 철회됐다**(위 표의 마지막 행). 구현 리뷰가
  이 대가를 추상이 아니라 구체로 보였다: 놓치는 것은 `subagent_type: adversarial`, 즉 이 플러그인과 무관한
  **표기 ①**이다. 그리고 좁힌 경계도 삭제된 실례를 이미 매치하므로 애초에 흔적이 아니었다. 이름 경계는 base
  형태 그대로다.
- **output style 지식이 저술 가이드에서 사라진다.** 필요해지면 이력 spec 과 `8303cc24` 에서 찾는다.
- **측정 원자료는 job 임시 디렉토리에 있다.** job 이 지워지면 사라지며, 러너는 「Verification Plan」 2 로
  재구성한다.
- **선재 RED `test_findings_parser.sh`** 는 측정 locale(`en_US.UTF-8`) 탓으로 추정된다(이전 baseline 의
  `C.UTF-8` 에서는 GREEN). 전후가 같아 판정에는 영향이 없다.

## Concrete Next Action

이 문서를 `spec-distill:reviewing-spec` 으로 리뷰하고 그 승인 게이트를 거친 뒤 `superpowers:writing-plans` 로
간다. 입력은 이 문서(`docs/superpowers/specs/2026-09-20-remove-agent-transparency-design.md`)다.

## 결정 기록

사용자 결정(2026-09-19~20, 이 세션):

| # | 질문 | 결정 |
|---|---|---|
| D1 | 제거 이유 | 안 쓴다 · 무게 감축 — 교훈 회수는 최소로 |
| D2 | 경로 분류 | architectural(선례 #153 · #154) — 사용자 이의 없음 |
| D3 | `agent:` 갈래를 어떻게 둘지 | 사용자 원문 「어떤게 가장 없던 상태 디폴트로 원복하는거야?」 — 판정 기준을 "이 플러그인 때문에 생긴 줄"로 확정 |
| D4 | 설계 §1 (D3 기준 개정판) | 「좋다 — 없던 상태로」 — 채팅 표의 일곱 줄 전부: output style 절 삭제(T1) · 예시 목록의 `transcript-reader` 삭제(T2) · `agent:` 갈래 삭제(T3) · 「아래」 근거 문단 삭제(T4) · `check_slots.py` 정정(T6, 범위는 D6 이 좁힘) · 하한 `≥28`(T7) · 디렉토리와 마켓플레이스 항목 삭제. 이력 문서 무수정 |
| D5 | 설계 §2 | 승인 — 별도 워크트리, 삭제와 흔적 정리를 한 커밋으로, AC, `/qg review` 1회, bump 없음 |
| D6 | 이 플러그인을 셈에 넣은 과거 시점의 개수 서술 (설계 리뷰 라운드 1) | 「(a) 개수는 이력」 — 개수·순번은 전부 두고 없어진 실체를 이름으로 가리키는 줄만 지운다. T6 은 bullet 삭제만 |
| D7 | AC4 와 이력 spec 경로 인용의 충돌 (라운드 1) | 「경로 리터럴만 예외」 — 파일 통째가 아니라 그 경로 문자열 안의 일치만 뺀다. G4 문구도 함께 |
| D8 | `context: fork` 주석 두 자리 (라운드 1) | 「T8 로 추가」 — 「Workflow JS」만 남기고 AC4 별칭에 `context: fork` 추가 |
| D9 | AC6 양성 대조가 파서 사망으로도 통과하는 구멍 (라운드 1) | 「고친다」 — index 에서 지우고, 「27개뿐」 ✗ 와 파서 rc 0 ✓ 를 함께 관측 |
| D10 | dispatch 락 이름 경계의 줄머리·공백 허용 (라운드 2) | 「(a) T9: 따옴표로 좁힘」 — 대가는 T3 과 같은 부류이고 「알려진 한계」에 적는다 |
| D11 | 코드에 박힌 하한을 가르는 규칙 (라운드 2) | 「(a) 규칙 + 훑은 목록」 — 핀 당시 수 − 1 만 흔적(R3), 훑은 목록은 §2 의 S3 표 |
| D12 | 라운드 2 자동 decide 7건(D6–D9 를 반영한 내 편집: Handoff · Context · Goals · Non-goals · Constraints · §2 · Files) | 전부 채택 |
| D13 | 흔적 목록의 층위 (라운드 2) | 「도출 절차로 전환」 — 설계는 규칙 R1–R4 와 절차 S1–S3 을 고정하고, 목록 확정은 plan 의 첫 Task 가 한다. 표는 「지금까지 도출된 것」이다 |
| D14 | AC6 이 근거로 든 도구 사실이 틀렸다 (라운드 3) | 「고친다」 — 코퍼스는 `--cached --others --exclude-standard`. 제거는 `git rm`(index+작업 트리)으로 못 박고, 반쪽 삭제 두 경로가 각각 어떻게 무력해지는지 적는다 |
| D15 | 확정 표의 정본이 살 자리 (라운드 3) | 「정본은 plan」 — 설계는 규칙·절차와 출발점 표를, 확정 표는 plan 이 갖는다. AC3·AC8 은 그 표를 가리키고, 이력 분류는 「이 작업 이전부터 있던 문서」로 좁힌다 |
| D16 | 라운드 3 자동 decide 7건(D10·D11·D13 을 반영한 내 편집: Files · §2 · AC · 목차 · 알려진 한계 · Goals · Handoff) | 전부 채택 |
| D17 | 재리뷰 상한 도달 뒤 추가 라운드 (라운드 3) | 「열지 않음」 — 라운드 3 은 새 흔적을 못 찾았고 낸 것은 문서 정확성 둘과 기재 하나였다. 전수성은 plan 의 도출 스윕(AC8)과 구현 리뷰가 맡는다 |

오케스트레이터가 정하고 사용자에게 알린 것(되돌리려면 괄호 안의 한마디):

| 정한 것 | 근거 |
|---|---|
| T5 추가 — D4 승인 뒤 발견 (「check_names 인용은 두라」) | T3 정규식의 글자 그대로 사본이다. 두면 T3 이 반쪽이 된다 |
| 이력 spec 제자리 · 배너 없음 (「archive 로 옮겨라」) | 경로·줄 번호 인용(`MEASUREMENT.md`) |
| 「알려진 한계」의 `agent:` 서술을 채팅 때보다 좁힘 | 채팅에서는 "미래의 `agent:` dispatch 가 빠져나간다"고 했으나, ∀ 도출(`ZERO_AGENTS`) 때문에 그 표기로**만** 불리는 agent 는 드러난다. 빠져나가는 것은 다른 표기로도 불리는 agent 의 추가 호출뿐이다 |
| **T9(이름 경계 좁힘) 철회 — D10 의 근거 있는 재결정** (「다시 좁혀라」) | 구현 리뷰가 C5 를 실측으로 반증했다. ① 좁힌 경계도 삭제된 실례 `agent: agent-transparency:transcript-reader` 를 **이미 매치한다** — 접두사의 콜론이 경계이므로 `^\|\s` 갈래는 그 줄 때문에 있던 것이 아니다. ② 좁히면 `subagent_type: adversarial`(따옴표 없는 평범한 YAML, **표기 ①**)을 놓친다 — 손실이 이 플러그인과 무관한 표기에 떨어진다. 되돌려도 오늘 잡히는 dispatch 는 22줄 그대로다(네 조합 동일 집합). 되돌린 뒤 양성 대조로 이빨 확인(처분 앵커를 뺀 따옴표 없는 dispatch → 축 A① 23 ≠ 22 RED). **T3 은 그대로다** — 그쪽은 출생 근거가 반증되지 않았고 리뷰 실측이 「알려진 한계」를 확인했을 뿐이다 |

### Deferred to plan

- 구현 커밋의 Conventional Commits type · scope, 그리고 설계 · plan · 구현 커밋의 순서.
- 측정 러너를 job 임시 디렉토리의 `run_all.sh` · `analyze.py` 로 재사용할지 재구성할지.
- T1 삭제 뒤 빈 줄 경계의 정확한 편집 문자열.
- AC6 에서 임시로 지울 마크다운 2개의 선택(T7 락의 코퍼스 글롭 안).
- PR 본문에 적을 사용자 측 영향 — 마켓플레이스를 갱신한 설치자에게서 플러그인이 사라지고, `force-for-plugin`
  output style 도 함께 사라진다.
- AC4 예외 판정(경로 리터럴을 지운 뒤 별칭 재검사)의 구현 형태.
- T9 의 정확한 경계 문자 집합 — 남는 dispatch 21줄(base 이동 시 그 수) 실측으로 정하고, 좁힌 뒤에도 축 A③
  (`adversarial` ⊂ `artifact-adversarial`)이 사는지 변이로 확인한다.
- 도출 절차 S1–S3 의 실행 형태와 증거 보관 자리(AC8).
- plan 안에서 확정 표가 사는 자리와 형식(D15) — §2 표의 다섯 열을 그대로 쓸지, T# 를 이어 붙일지.

설계 리뷰 라운드 1 이 미룬 것:

| 엔진 원장 id | 요지 |
|---|---|
| 2e6610eb#r1.1 | 두 가지가 비어 있다. (1) Verification Plan 1 의 「측정 때의 baseline 을 쓴다」는 곧 지워질 job 임시 디렉토리에 기대고 있어, 디렉토리가 없을 때의 경로가 없다. (2) Verification Plan 2 에는 .py·.mjs 대상 파일 선택 규칙이 없어 252개 모집단을 재현할 수 없다. plan 이 선택 규칙을 못 박고, job 디렉토리가 없으면 base 에서 baseline 을 다시 재도록 정한다. |
