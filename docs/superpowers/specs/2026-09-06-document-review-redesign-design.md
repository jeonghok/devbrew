---
name: document-review-redesign
type: design
created_at: 2026-09-06
source_interview: docs/superpowers/interview/2026-09-06-document-review-redesign-interview.md
next_phase: superpowers:writing-plans
---

# 문서 리뷰 재설계 — 설계

> **리뷰의 산출물은 verdict 가 아니라 수신자가 붙은 finding 목록이다.**

devbrew 에서 문서를 리뷰하는 자리 넷(design doc · interview brief · generic doc · interview seed)을
엔진 하나(agent 2 · 스크립트 4 · 절차 reference 1)와 프로필 넷으로 다시 짓는다. 탐지 리뷰어 한 명이 finding 마다 처분(`decide` 사용자 결정 ·
`ask` 묻기 · `fix` 저자 수정 · `defer` plan 이월 · `drop`)을 붙이고, 프레이밍을 못 보는 독립
재비판자가 오탐을 근거 인용으로 기각하며, 오케스트레이터는 처분을 올리기만 하고 수신자에게
배달한다. 수정이 새 결함을 만드는 회귀는 「finding 이 선언한 편집 범위 + finding 없던 섹션과
보호 부류의 얼림 + 헤딩 단위 diff 의 자동 `decide`」로 막는다. 결정론은 헤딩 diff 와 보호 부류
목록 둘뿐이고 나머지는 산문과 사용자 결정이다.

## 목차

- [1. Context · Why](#1-context--why)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. Constraints](#4-constraints)
- [5. Architecture](#5-architecture)
  - [5.1 물리 배치 — `shared/docreview/` 정본 + 심볼릭 링크 · agent 는 사본](#51-물리-배치--shareddocreview-정본--심볼릭-링크--agent-는-사본)
  - [5.2 컴포넌트 여섯](#52-컴포넌트-여섯)
  - [5.3 프로필 넷](#53-프로필-넷)
  - [5.4 진입 자리 넷과 배선](#54-진입-자리-넷과-배선)
  - [5.5 치환되는 것과 남는 것](#55-치환되는-것과-남는-것)
- [6. 한 라운드의 데이터 흐름](#6-한-라운드의-데이터-흐름)
  - [6.1 여덟 단계](#61-여덟-단계)
  - [6.2 finding 계약](#62-finding-계약)
  - [6.3 라우팅 규칙](#63-라우팅-규칙)
  - [6.4 승인의 도출](#64-승인의-도출)
- [7. 회귀 장치](#7-회귀-장치)
- [8. 게이트 · 상한 · 결정 기록](#8-게이트--상한--결정-기록)
  - [8.1 라운드 게이트](#81-라운드-게이트)
  - [8.2 승인 게이트](#82-승인-게이트)
  - [8.3 재리뷰 상한 2 와 추가 라운드](#83-재리뷰-상한-2-와-추가-라운드)
  - [8.4 stagnation 술어의 교체](#84-stagnation-술어의-교체)
  - [8.5 결정 기록](#85-결정-기록)
- [9. 오류 처리 · degrade · kill switch](#9-오류-처리--degrade--kill-switch)
- [10. 이관](#10-이관)
- [11. Acceptance Criteria](#11-acceptance-criteria)
- [12. Files to Modify](#12-files-to-modify)
- [13. Verification Plan](#13-verification-plan)
- [14. Rejected Alternatives](#14-rejected-alternatives)
- [15. Open Questions](#15-open-questions)
- [16. 결정 기록](#16-결정-기록)
- [17. Concrete Next Action](#17-concrete-next-action)
- [Handoff Context](#handoff-context)

## 1. Context · Why

지금 네 자리는 전부 「결함 탐지기 + 수정 루프」이고 산출물이 verdict(`approved` / `needs_revise`)다.
finding 에 수신자가 없어 방향 결함도 상세 결함도 plan 이 정할 것도 전부 「저자가 고쳐서 재리뷰」
한 갈래로 흐르고, 그 즉흥 수정이 새 결함을 만든다. 스펙 리뷰가 request framing → interview →
brainstorming → writing-plans → 구현의 큰 그림에서 스펙의 역할을 넘어 plan 의 일(자동 검증 절차)
까지 요구해 왔다. 근본 원인은 브리프 D1 — **리뷰 산출물이 verdict 라 finding 에 수신자가 없는
것**이다.

입력은 인터뷰 브리프(`source_interview`)이며, 그 §2 의 확정 항목 C1~C10 · D1~D19 는 이 설계의
전제다. 브리프의 Open Questions 열 개 중 넷(OQ1 배치 · OQ2 두 층 · OQ5 결정 기록 · OQ8 탐지 수)은
이 설계 세션에서 사용자가 답했고(§16), 나머지 여섯은 이 문서가 닫거나(§5.3 OQ10 · §6.3 OQ7 ·
§9 OQ4·OQ6 · §10 OQ3) 이월 처분을 적었다(§15 의 09-02 OQ 표, OQ9).

## 2. Goals

- 네 문서 리뷰 자리가 같은 엔진(처분 어휘 · 라우팅 · 앵커 묶기/얼림 · finding 정체성 · codex
  co-review · degrade 공시)을 쓰고 프로필(정답의 출처 · 허용 처분값 · 검토 순서 · handoff 목적지)만
  다르게 갖는다. 방향 실패는 라운드마다 사용자에게, 상세 결함은 저자에게, plan 의 일은 plan 으로 간다.
- 수정이 새 결함을 만드는 회귀를 리뷰어의 눈에만 맡기지 않고 **수정 범위 자체**로 막는다.
- 하니스는 가볍게 — 판정·차단하는 결정론은 헤딩 단위 diff 와 보호 섹션 목록 둘뿐이다.
- 재리뷰 상한을 네 자리 모두 2 로 통일하고, 상한을 넘는 라운드는 사용자에게 제안만 한다.

## 3. Non-goals

- superpowers brainstorming 의 자체 self-review 단계. superpowers 는 건드리지 않는다.
- codex 병렬 co-review · 문서 발견용 Stop 훅 · `/compact` proceed 게이트를 바꾸는 것. 셋은
  그대로 둔다. Stop 훅의 목적지 상수 `reviewing-spec` 도 그대로다(§5.4).
- 08-27 핸드오프의 M2·M4(오케스트레이터 1차 재비판 · 재비판 subagent 제거)를 되살리는 것.
  현행 기준은 09-02 인터뷰 C3(M1·M3 유지 · M2·M4 반전)이다.
- CLAUDE.md Law 1 필수 섹션 목록의 개정.
- 코드 리뷰(`/qg` Review 게이트 · quality-pipeline)의 변경. `quality-pipeline/SKILL.md` 의 「max 5
  iterations」는 코드 게이트의 것이라 손대지 않는다.
- 냉독(`brief-readback` · `seed-readback`)을 엔진에 넣는 것 — 처분 없는 가독성 측정이라 대상이 아니다.
- 문장 단위 diff. 같은 섹션 안의 회귀는 다음 라운드 리뷰어의 눈에 남긴다(§7).

## 4. Constraints

브리프 §2 의 C1~C10 · D1~D19 전부. 그중 이 문서가 직접 형태를 정한 것만 다시 적는다.

| id | 제약 | 이 설계에서의 실체 |
|---|---|---|
| C2·D12 | 목표·범위·제약·Non-goal·아키텍처·trade-off·AC 를 바꾸는 수정은 사용자 결정 뒤에 | 보호 부류 = 프로필의 `protected_headings`. 매칭되는 앵커의 finding 은 처분 무관하게 `decide` |
| C3·C4·D7 | 방향 결함은 사용자에게 · 하나라도 올리라 하면 올림 · 오케스트레이터는 올리기만 | `docreview_route.py` 의 전순서 max 규칙. 하향은 사용자(라운드 게이트 「보류」)와 재비판자(근거 인용 `reject`)만 |
| C5·D4·D13·D14 | 회귀 = 수정이 새 결함을 만드는 것 · 편집 범위 선언 · 얼림 · 패치 의도 | §7 |
| C6 | 산문 + 구조, 무거운 하니스 지양 | 결정론 둘(헤딩 diff · 보호 부류). 나머지는 persona·skill 산문 |
| C8 | 기존 구현 모양에 끌려가지 않음 · 공통은 shared · 특화는 분화 | §5.1 배치 · §5.3 프로필 · §5.5 치환 |
| D2·D3·D11 | 탐지 하나 · 처분 다섯 · 전순서 `decide` > `ask` > `fix` > `defer` > `drop` | §6.2 · §6.3 |
| D5·D15 | 엔진 하나 + 프로필 넷 · brief/seed 의 fix 앵커 §0·§2, §6 불변 | §5.3 |
| D6·D18 | 스펙은 검증 가능성까지, plan 은 절차부터 · `testing` = 검증 전략 부재 | design-doc 프로필 rubric 의 `testing` 정의 + `defer_target` |
| D8·D16 | `decide` 는 결정 단위로 라운드마다 · fix 전제인 `ask` 는 비차단 동반 | §8.1 |
| D10 | 탐지·재비판은 프레이밍을 못 보는 독립 critic · 재비판 subagent 유지 | `doc-critic` · `doc-recritic` 둘 다 dispatch 프롬프트 밖의 대화를 받지 않음 |
| D17·D19 | 재리뷰 상한 2 통일 · 추가 라운드는 제안만 | §8.3 |
| 설치 경계 | 다른 플러그인의 스크립트는 `${CLAUDE_PLUGIN_ROOT}` 에서 도달 불가. `shared/` 의 상대 심볼릭 링크는 설치 시점에 실제 파일로 풀린다(2026-08-17 실측, weight-reduction 설계 §16.1) | §5.1 |

## 5. Architecture

### 5.1 물리 배치 — `shared/docreview/` 정본 + 심볼릭 링크 · agent 는 사본

엔진(agent 둘 · 스크립트 넷 · 절차 reference 하나)은 `shared/docreview/` 에 정본으로 살고,
spec-distill 과 quality-gates 에 배포된다. `scripts/` · `references/` 는 **파일 단위 상대 심볼릭
링크**(디렉토리 링크가 아니다)이고, 이미 `shared/adjudication/` · `shared/codex/` 가 같은 방식으로
두 플러그인의 `scripts/` 에 들어가 있다. **`agents/` 만은 링크가 아니라 바이트 동일 사본 + `copy-of:`
마커다** — 심볼릭 링크로 둔 agent 는 dispatch 되지 않는다(2026-09-06 링크 로더 실측, `agents/` 확정
`no`: `--plugin-dir` 세션에서 `Agent type … not found` 이고 세션 `init` 의 `agents` 배열에도 없다.
같은 트리의 링크 아닌 대조군은 정상 dispatch 돼 `--plugin-dir` 자체의 한계가 아님을 배제했다).
§13 항목 0 이 지시한 배포 방식 교체이고 아키텍처는 바뀌지 않는다.

**skill 본문은 공유하지 않는다.** 처분 락(`shared/tests/test_dispatch_disposition.sh` 축 A⑤)은
dispatch 앵커가 사는 파일의 플러그인과 `consumer=` 경로의 플러그인이 같기를 요구하므로, 한 SKILL.md
를 두 호스트에 링크하면 한쪽에서 반드시 RED 다. 그래서 `Agent()` dispatch 블록(critic · recritic)은
각 호스트의 **진입 skill 안**에 살고(`consumer=plugins/<host>/scripts/docreview_route.py`), 공유되는
것은 그 블록이 따르는 절차 — `references/reviewing-document.md` — 다. 같은 호스트 안의 진입 skill
둘(`reviewing-spec` · `reviewing-brief`)이 같은 dispatch 블록을 갖는 것은 `test_no_new_duplication.sh`
의 20줄 임계 아래로 유지한다(블록은 프롬프트 한 줄 + 처분 한 줄이다).

**링크 락은 확장한다 — 새 락이 아니라 도출 축 하나다.** `test_copy_of_contract.sh` 축 1a 의 구조
도출은 지금 `plugins/*/scripts/<basename>` 만 본다(371–397행). reference 링크가 배포 지점
0건으로 도출돼 RED 가 되므로, 구조 도출을 `plugins/*/{scripts,agents,references}/<basename>` 로
넓힌다(agent 는 사본이라 축 1a 의 정본 목록에 안 들지만, 미래에 링크로 배포되는 것이 생겨도 조용히
빠지지 않게 세 디렉토리를 함께 넓힌다). 산문 도출(395행의 `scripts/<basename>` 참조 패턴)도 같은 세
디렉토리로 넓힌다 — 구조만 넓히면 「참조는 하는데 배포 지점이 없는 플러그인」을 reference 에 대해
못 잡는다. 값이 안
변한다는 것을 먼저 잰다 — 기존 정본(codex 3 · adjudication 2)의 도출 수가 확장 전후로 같아야 한다(그
락 자신이 2026-08-18 에 같은 방법으로 넓혔다). 링크 로더 가정 자체는 §13 항목 0 이 PR 1 전에 잰다.

같은 agent 가 두 네임스페이스로 설치된다(`spec-distill:doc-critic` · `quality-gates:doc-critic`).
캐시 중복은 있으나 기능 문제는 없고, 각 플러그인이 설치본에서 자기 완결이라 cross-plugin 의존이
새로 생기지 않는다.

프로필은 엔진이 아니라 **호스트 플러그인의 데이터**다 — `plugins/<host>/references/docreview-profiles/
<name>.md`. spec-distill 이 셋(`design-doc` · `brief` · `seed`), quality-gates 가 하나(`generic`)를 갖는다.

### 5.2 컴포넌트 여섯

| 컴포넌트 | 무엇을 하나 | 도구 표면 | 의존 |
|---|---|---|---|
| `doc-critic` (agent) | 탐지 리뷰어 한 명. 층 1(큰 그림 정합)을 먼저 검토해 sentinel 블록 `docreview-layer1` 로 써내고, 그다음 층 2(상세 완결)를 `docreview-layer2` 로 써낸다. finding 마다 처분과 편집 범위를 붙인다 | `Read, Grep, Glob`. 프로필이 `web: true` 면 `WebSearch, WebFetch` 추가 — 단, 도구 표면은 agent 정의의 상수이므로 웹 허용 여부는 dispatch 프롬프트의 `web_disabled` 슬롯으로 전달한다(현행 spec-reviewer 와 같은 방식) | 프로필 `layer_rubric` |
| `doc-recritic` (agent) | 프레이밍을 못 보는 독립 재비판자. 입력은 **셋뿐** — 문서 · 출처 라벨 없는 finding 목록 · 프로필 파일(허용 처분값 · 층 rubric · 보호 헤딩 — 정적 데이터이지 프레이밍이 아니다). 오탐은 근거 인용 `reject`, 층 오분류·과소 처분은 상향(`raise`), 처분 없는 finding(codex)에 처분을 붙이고, 놓친 finding 을 추가한다. dispatch 사유 · 이전 대화 · 출처 라벨은 받지 않는다 | `Read, Grep, Glob` | 프로필 |
| `docreview_anchor.py` | 서브커맨드 다섯 — `snapshot`(헤딩 파싱 → 섹션 앵커·해시) · `diff`(두 스냅샷의 헤딩 단위 변경, `applied_scopes`·`permit` 앵커 제외) · `protected`(앵커가 보호 부류인가) · `refs <anchor>`(그 앵커를 본문에서 인용하는 섹션 수 — auto `decide` 의 「영향」) · `check-intent <finding-id> <intent>`(패치 의도의 앵커가 **그 finding 의 `edit_scope` 안**이고 프로필 `fix_anchors` 안이며 보호 부류·`immutable` 이 아닌가. `decision_id` 를 인용한 의도는 유효한 `permit.apply_anchors` 안이면 `edit_scope`·`fix_anchors`·보호 부류를 우회하고 `immutable` 만 못 넘는다) | python | 프로필 `protected_headings` · `fix_anchors` · `immutable`, state 의 `permits`·`applied_scopes` |
| `docreview_route.py` | critic · codex · recritic 세 원장을 합쳐 finding 별 최종 처분을 확정. 회계는 `shared/adjudication` 의 `Ledger` 에 위임하고, stdout 은 처분별 목록 + `adjudication_*` 키 + `advisory[]` | python | `adjudication.py`(shared, 이미 링크됨) |
| `docreview_state.py` | 세션 state 의 라운드 원장 — 스냅샷 해시 · finding 목록 · `permits`(채택된 결정이 연 편집 허가) · `applied_scopes` · 결정 기록 포인터 · `rereview_count` · 추가 라운드 승인 기록. **state 디렉토리는 인자로 받는다**(`--state-dir <dir>`) — 두 호스트의 `state_path.py` 는 이름만 같고 시그니처가 다르므로(spec-distill 은 `resolve_session_id`+`state_root(cwd)`, quality-gates 는 `state_root(hook_input, hook_name)` 뿐) 공유 스크립트가 그것을 import 하지 않는다. 디렉토리 해석은 진입 skill 이 자기 호스트의 리졸버로 하고, 인자가 없으면 스크립트는 진입 실패(§9 「세션 id 미해석」)다 | python | 없음(호스트 모듈 import 0) |
| `reviewing-document.md` (reference) | 한 라운드의 절차. kill switch → 스냅샷 → dispatch(critic · codex · recritic) → 라우팅 → 얼림 검사 → 배달 → 게이트. 진입 skill 이 `Read` 로 읽고 따른다 — dispatch 블록 자체는 진입 skill 에 있다(§5.1) | reference | 위 전부 + `shared/codex/runner_common.sh` |

codex 러너는 하나로 합친다: `run_docreview_codex_reviewer.sh <profile> <doc-or-bundle> <project_dir>
<out_yaml>`. 자리별 `build_*_codex_prompt.py` 넷은 사라지고 러너가 프로필의 `layer_rubric` ·
`allowed_dispositions` 와 `shared/codex/prompt-preamble.md` 로 프롬프트를 조립한다(빌더는 러너 안의
함수 하나다). 출력 변환은 기존 `codex_findings_to_yaml.py` 를 쓰되 **그 스크립트에 emit keyset 하나를
더한다**(`--emit-keys docreview` = §6.2 의 리뷰어 출력 필드 전부 — `ref` · `layer` · `category` · `anchor` ·
`disposition` · `summary` · `edit_scope` · `blocks` · `supersedes` · `evidence`). 지금 스크립트는
고정 keyset 밖의 키를 조용히 버리므로(`yaml_emit` 의 `for k in keys`), 더하지 않으면 codex 처분이
전부 소실돼 §6.3 의 coerced 규칙이 매 finding 에 발동한다. `shared/codex/` 는 그래서 무변경이
아니라 **추가 수정** 대상이다(§12).

### 5.3 프로필 넷

프로필 파일의 frontmatter 는 **열 필드**로 고정한다. 필드가 빠지면 엔진이 진입에서 멈춘다(fail-closed).

| 필드 | 뜻 | design-doc | brief | seed | generic |
|---|---|---|---|---|---|
| `detectors` | 탐지 리뷰어 수(§16 Q1). 이 판본의 허용값은 `1` 뿐이며 다른 값은 진입 실패다 — 필드를 두는 이유는 측정 근거가 생겼을 때 설계를 다시 열지 않기 위해서다 | 1 | 1 | 1 | 1 |
| `ground_truth` | 정답의 출처 | 인터뷰 브리프 §2 | payload §6 + audit §6 원문 | audit `## 1. 원문` | 문서 자체 |
| `allowed_dispositions` | 낼 수 있는 처분값 | 다섯 전부 | `decide` `ask` `fix` `drop` | `decide` `ask` `fix` `drop` | `decide` `ask` `fix` `drop` |
| `fix_anchors` | `fix` 가 허용되는 섹션 | 보호 부류 밖 전부 | §0 · §2 | seed 본문 전체(§6 상당 없음) | 전부 |
| `immutable` | 어떤 처분도 닿지 못하는 섹션 | 없음 | §6 | 없음 | 없음 |
| `protected_headings` | 보호 부류의 헤딩 패턴(정규식 목록) | Goals · Non-goals · Constraints · Architecture · trade-off · Acceptance Criteria(+ 한국어 대응 헤딩) | §1 Goal·Non-goal | 없음 | 없음 — 헤딩이 없을 수도 있다(§9) |
| `layer_rubric` | 층 1 · 층 2 의 검토 항목. 층 2 를 **비운 프로필**은 층 2 블록을 요구하지 않는다(§9 — 부재가 degrade 가 아니다) | 층 1: 목표·문제정의·범위·아키텍처·컴포넌트 관계·데이터 흐름·trade-off·구현 가능성의 정합 / 층 2: placeholder · ambiguity · scope_creep · approaches_comparison · isolation · `testing`(=검증 전략 부재) · handoff_incomplete | 층 1: 방향성(사용자 방향이 틀렸을 근거) / 층 2: 충실도(왜곡·누락·발명) | 층 1: 억제(근거 없는 추가·예시의 요구화·조기 닫힘) / 층 2: 비움 | 층 1: logic · assumption / 층 2: completeness · evidence · ambiguity · actionability · structure |
| `decision_log` | 결정 기록 목적지 | 문서 끝 `## 결정 기록` 절 | `.audit.md` 의 `## 8. 리뷰 결정` | `.audit.md` 의 `## 8. 리뷰 결정` | 세션 state + 게이트 텍스트 |
| `defer_target` | `defer` 의 목적지 | `## Handoff Context › ### Deferred to plan` 표 | 없음(`defer` 불허) | 없음 | 없음 |
| `web` | critic 의 웹 허용 | false | true(방향성 축은 근거 폭이 본질) | false | false |

`protected_headings` 가 프로필 선언인 이유(브리프 OQ10): 헤딩 이름 매칭을 엔진에 박으면 문서
양식이 바뀔 때 엔진을 고쳐야 하고, 프로필이 선언하면 그 자리의 양식을 아는 쪽이 목록을 소유한다.
브리프 프로필의 `decide` 는 D15 대로 「원문 자체가 모호할 때」로 좁힌다 — rubric 문구로 지시하고
결정론으로 잡지 않는다.

### 5.4 진입 자리 넷과 배선

| 자리 | 진입 skill(이름 유지) | 프로필 | 부르는 쪽 |
|---|---|---|---|
| design doc | `spec-distill:reviewing-spec` | `design-doc` | Stop 훅 `review-dispatch.py` 의 mandate(무변경) |
| brief | `spec-distill:reviewing-brief` | `brief` | `conducting-interview` 종료 Step A |
| generic doc | `quality-gates:critiquing-artifacts` | `generic` | `/qg critique <path>` |
| seed | `spec-distill:framing-requests` 의 검증 절 | `seed` | 같은 skill 내부 — 배선은 마지막 PR(D5) |

진입 skill 본문은 「프로필 경로를 정하고 `references/reviewing-document.md` 를 읽어 따른다」 한 절 +
critic·recritic 의 `Agent()` dispatch 블록 둘(§5.1 — 처분 락 때문에 호스트 안에 산다) + 자리 고유의
진입 게이트(brief 의 `check_brief.py gate` · `check_verbatim_coverage.py`, generic 의 코드/비코드
분류 · 경로 인가 · 브랜치 안전, design doc 의 arm-once 원장 기록)만 남는다. 진입 게이트는 엔진
밖이다 — 엔진은 「게이트를 통과한 문서」만 받는다.

**라운드 루프의 소유자와 턴 경계** — 라운드 1 → n 의 루프는 진입 skill 이 **한 턴 안에서** 돈다
(`reviewing-document.md` 의 절차, 라운드 게이트의 `AskUserQuestion` 도 그 턴 안이다). 세션 state 의
라운드 원장(`rereview_count` · `permits` · `applied_scopes` · 스냅샷)은 라운드마다 저장되므로 어느
시점에 끊겨도 다음 진입이 그 라운드부터 잇는다. **자동 재개는 없다** — 재진입은 호출자의 수동
재호출(네 자리 공통)이거나, design doc 자리에 한해 아래 현행 훅 계약이 허용하는 재발동이다.

**design doc 자리 — 현행 Stop 훅 계약과의 접점(훅은 무변경).** 훅은 dispatch 와 같은 write 에서
문서를 `inflight_paths` 에 찍고, 그 표시가 있는 동안(`INFLIGHT_TTL_SEC` = 900초) 발견에서 제외하며,
총 dispatch 를 `DISPATCH_ATTEMPT_CAP` = 3 으로 센다. 표시를 지우는 손은 `mark-reviewed` 와
`clear-inflight` 둘이다. 새 엔진의 시점은 이렇다:

| 시점 | 호출 | 결과 |
|---|---|---|
| 승인 게이트에서 사용자가 진행(①/②)을 고른 뒤 | `mark-reviewed` | 완료 기록 + inflight 해제. 이후 같은 세션 편집은 재arm 되지 않는다(현행과 같다) |
| 승인 게이트 ④ 「멈춤」 | `clear-inflight` 만 | 완료 기록 없음. 다음 편집이 발견되면 훅이 재dispatch 할 수 있고 라운드 원장이 이어진다 |
| 라운드 게이트에서 사용자가 답하지 않고 턴이 끝남 | 아무 호출도 못 한다(코드가 돌 자리가 없다) | TTL 900초 뒤 표시가 만료돼 다음 편집에서 재dispatch. 그때까지는 수동 재호출 |

라운드 수와 attempt cap 의 관계: 정상 루프는 **훅 dispatch 1회 안에서** 라운드 3 + 추가 라운드까지
전부 돈다(루프가 in-turn 이라 라운드는 dispatch 를 소모하지 않는다). cap 3 이 세는 것은 끊긴 뒤의
재진입 횟수다 — 재진입 2회 뒤에는 훅이 멈추고 수동 재호출만 남는다. 이 수치는 훅의 것이라 이 설계가
바꾸지 않는다. 주 판정자 사망으로 라운드를 세지 않는 경우(§9)에는 `mark-reviewed` 를 부르지 않는다 —
현행 both-dead 예외와 같은 규칙이다.

진입 skill 이름을 유지하는 이유는 배선이다. Stop 훅이 `reviewing-spec` 을 상수로 갖고(Non-goal),
`conducting-interview` 가 `reviewing-brief` 를, `/qg critique` 가 `critiquing-artifacts` 를 부른다.
이름은 배선이지 「기존 구현의 모양」(C8)이 아니다.

### 5.5 치환되는 것과 남는 것

통일은 **치환**이지 추가가 아니다(09-02 OQ22 — 옛 어휘를 남긴 채 새 계약을 얹으면 drift 쌍이 된다).

| 자리 | 사라지는 것 | 남는 것 |
|---|---|---|
| design doc | `spec-reviewer` · `merge_review.py` · `compute_issue_id.py` · `run_spec_codex_reviewer.sh` · `build_spec_codex_prompt.py` · verdict 세 값 · `issue_history` 원장 · `raised_count`/`dismissed_by_user` stagnation | `review-dispatch.py`(Stop 훅) · `resolve_mode.py`(Stop 훅이 import 한다) · `arm_ledger.py` · `proceed-gate.md` · `ambiguity-blacklist.txt`(critic rubric 이 참조) |
| brief | `brief-critic` · `brief-direction-reviewer` · `merge_brief_review.py` · `build_brief_codex_prompt.py` · `run_brief_codex_reviewer.sh` · 충실도 재리뷰 루프(fresh-critic 상한 2) | `brief-readback` · `build_brief_bundle.py` · `check_brief.py` · `check_verbatim_coverage.py` · `brief_review_state.py`(degrade 원장 — `docreview_state.py` 가 같은 파일의 다른 키를 쓴다) |
| generic doc | `artifact-critic` · `artifact-adversarial` · `synthesize_artifact_findings.py` · `artifact_stagnation.py` · `artifact_commit.sh` · `artifact_max_rounds.sh` · `run_artifact_codex_reviewer.sh` · `build_artifact_codex_prompt.py` · **라운드별 자동 커밋 루프** | `classify_artifact_target.py` · `artifact_path_auth.py` · `artifact_branch_guard.sh` · `artifact_change_signal.sh` |
| seed | `seed-critic` · `build_seed_codex_prompt.py` · `run_seed_codex_reviewer.sh` · `seed-codex-suppression-checklist.md` | `seed-readback` · `build_seed_inline_blob.py` · `check_seed.py` |

전수 목록은 plan 이 도출한다(§Handoff Context D0). 이 표는 씨앗이다.

## 6. 한 라운드의 데이터 흐름

### 6.1 여덟 단계

1. **스냅샷** — `docreview_anchor.py snapshot <doc>` 이 헤딩 단위 섹션 목록과 해시를 세션 state 에
   적는다. 라운드 1 의 스냅샷이 기준선이다(D13 — git 커밋이 아니다).
2. **탐지** — `doc-critic` 을 한 번 dispatch. 입력은 문서 경로(brief·seed 는 번들 inline — 그
   자리들은 정답이 원문이라 외부 정보가 오염원이다) + 프로필 `layer_rubric` + 같은 출처의 이전
   라운드 finding id 목록. 출력은 sentinel 블록 둘 — `docreview-layer1` 뒤에 `docreview-layer2`.
3. **codex** — 기존 `codex-gate:begin … end` 블록 형태를 그대로 쓰고 러너만 하나로. codex 도
   문서(또는 번들)만 받는다.
4. **재비판** — `doc-recritic` 을 한 번 dispatch. 입력은 문서 + critic·codex finding 을 **출처 라벨
   없이 섞은** 목록. dispatch 프롬프트·이전 대화는 받지 않는다(프레이밍 차단, D10). 출력은
   finding 별 `verdict ∈ {confirm, reject, raise}` 와 추가 finding.
5. **라우팅** — `docreview_route.py` 가 세 원장을 합쳐 finding 별 최종 처분을 확정하고 `Ledger` 로
   회계한다(§6.3).
6. **얼림 검사** — 라운드 2 이상이면 `docreview_anchor.py diff` 가 이전 스냅샷 대비 헤딩 단위 변경을
   낸다. 바뀐 앵커 중 **§7 의 예외 넷 밖의 모든 것**이 자동 `decide` finding 으로 목록에 추가된다 —
   finding 이 없던 섹션과 보호 부류(D12)는 물론, finding 이 있던 섹션이라도 `check-intent` 를 거치지
   않은 변경은 자동 `decide` 다. 술어는 §7 한 곳에 있고 여기서는 그것을 부른다.
7. **배달** — `decide` → 결정 묶음으로 라운드 게이트 · `ask`(fix 전제) → 같은 묶음에 비차단 ·
   `fix` → 저자 세션에 패치 의도 요구 · `defer` → `defer_target` 절에 append · `drop`·`reject` →
   회계에만 남고 게이트 텍스트에 개수 공시.
8. **저자 적용** — 저자는 `fix` 마다 「무엇을 · 어느 앵커에」 패치 의도를 내고, `check-intent` 가
   통과시킨 것만 적용한다(D14). 그다음 라운드 n+1.

### 6.2 finding 계약

```yaml
- ref: c3                     # 리뷰어가 자기 출력 안에서만 유효한 임시 참조를 붙인다 (c=critic, x=codex)
  layer: 1 | 2
  category: <프로필 layer_rubric 의 값>
  anchor: "#heading-anchor"                     # 편집 범위의 기본값
  disposition: decide | ask | fix | defer | drop
  summary: "<한 문장>"
  edit_scope: "#anchor" | "insert-after:#anchor"  # 선택 — 기본은 anchor (D13)
  blocks: [c5, …]                               # ask 전용 — 이 답이 전제인 fix 의 ref (D16)
  supersedes: <이전 라운드 id>                    # 선택 — 이전 라운드 finding 을 대체할 때
  evidence: "<인용>"                            # reject · decide 에는 필수
# 라우터가 붙이는 필드
  id: <bucket>#r<round>.<k>                     # 최종 id — 라운드가 박혀 다른 라운드에서 재사용되지 않는다
  origin: reviewer | auto                       # auto = 보호 부류 승격 · 얼림 diff 생성
  lineage: <계보 뿌리 id>                        # supersedes 사슬의 가장 오래된 조상
```

**참조와 id 의 두 단계.** 리뷰어는 최종 id 를 모른다 — 자기 출력 안의 `ref` 만 쓴다(`blocks` 도
`ref` 로 가리킨다). 라우터는 재비판 **전에** critic·codex 의 finding 을 출처를 지운 일련번호(`f1…fN`)로
다시 붙여 재비판자에게 주고, 재비판자의 `verdict` · `same_as: [f3, f7]`(출처가 다른 같은 결함) 은 그
번호로 온다. 라우팅 후 최종 `id` 를 붙이고 `blocks` · `same_as` 를 최종 id 로 변환한다. `same_as` 로
묶인 것은 높은 처분을 남기고 나머지를 `Ledger.absorbed()` 로 계수한다 — 소실이 아니다.

**정체성** — `bucket` 은 `(layer, category, anchor)` 의 해시, `r<round>` 는 그 finding 이 처음 난
라운드, `k` 는 그 라운드·그 bucket 안의 순번이다. 같은 섹션·같은 category 의 서로 다른 결함은 같은
bucket 의 다른 순번이라 **합쳐지지 않고**, 라운드가 박혀 있어 다음 라운드의 다른 결함이 같은 id 를
받지 않는다. **계보(lineage)** 는 `supersedes` 사슬이다 — 리뷰어가 지목하면 그대로, 지목이 없으면
라우터가 결정론으로 잇는다: 같은 bucket 에 아직 열린 이전 라운드 finding 이 있으면 순번이 낮은 것부터
하나씩 잇고, 남는 것은 새 계보다(리뷰어가 지목을 빠뜨려 stagnation 을 피하는 길을 막는다). 한 bucket 에
순번이 둘 이상이면 게이트 텍스트에 「bucket 충돌 N」으로 공시한다(계수). 사용자 기각·재비판자
reject 는 **그 id 하나**에만 닿는다.

`decide` finding 은 C2 의 네 항목(변경 내용 · 근거 · 대안 · 영향)을 `summary` 와 `evidence` 안에
채운다 — 라운드 게이트가 그것을 그대로 보인다(§8.1). **`origin: auto` 인 `decide`**(보호 부류 승격 ·
얼림 diff 생성)는 리뷰어가 네 항목을 채울 수 없으므로 라우터가 채운다: 변경 내용 = 원 finding 의
`summary`(승격) 또는 헤딩 diff 요약(얼림), 근거 = 원 finding 의 `evidence` 또는 「finding 없이 바뀜」,
대안 = 「적용 / 원복 / 보류」 고정 셋, 영향 = 앵커와 그 앵커를 본문에서 인용하는 섹션 수(`docreview_anchor.py
refs`). 자동 채움은 게이트 텍스트에 `[auto]` 로 표시돼 사람이 리뷰어 판단과 구별한다. 형식은 sentinel YAML 이며 JSON 강제 출력은
쓰지 않는다(브리프 landscape «two-calls» 의 정확도 붕괴 실측).

### 6.3 라우팅 규칙

결정론은 이 표와 헤딩 diff 둘뿐이다.

| 입력 상황 | 결과 |
|---|---|
| critic 과 codex 가 같은 finding 에 다른 처분 | 전순서에서 높은 쪽(D7·D11) |
| recritic 이 `raise` | 그 값으로 상향. 하향 요청은 무시하고 `coerced(gate=False)` 로 계수 |
| recritic 이 `reject` + `evidence` | 목록에서 제외, `Ledger.reject()` 계수, 게이트 텍스트에 「기각 N건」과 인용 |
| recritic 이 `reject` 인데 `evidence` 없음 | reject 무효 — `confirm` 으로 취급 + `coerced` 계수 |
| codex finding 에 처분 없음 | recritic 이 붙인 값. recritic 도 못 붙였으면 `ask` 로 `coerced(gate=False)` — 기본값이 사람 쪽으로 기우는 유일한 자리(브리프 OQ7 의 답) |
| 처분이 `defer` 인데 프로필이 `defer` 를 불허 | **`ask` 로 상향** + `coerced` — plan 이 없는 자리에서 「plan 의 일」의 수신자는 저자가 아니라 사용자다. 「상위 최소값」 규칙(다음 행)의 명시적 예외이고 AC10 이 이것을 잰다 |
| 그 밖의 처분이 프로필 `allowed_dispositions` 밖 | 허용값 중 그보다 높은 최소값으로 상향 + `coerced`. 더 높은 허용값이 없으면 `decide` |
| 앵커가 `protected_headings` 에 매칭 | 처분 무관하게 `decide`(D12). 단 그 앵커에 유효한 `permit`(§8.1) 이 있으면 리뷰어의 처분 그대로 |
| 앵커가 `immutable` 에 매칭 | 어떤 처분도 그 본문을 바꾸지 않는다. `fix` 는 `decide` 로 상향되되 그 결정의 **적용처는 원문이 아니라 요약**(brief 의 §0·§2 — 「원문을 어떻게 읽을 것인가」의 해석 결정)이고, `permit` 의 앵커도 요약 쪽에 열린다. D15 의 「원문 자체가 모호할 때의 decide」가 이것이다 |
| 얼린 섹션이 바뀜 | `decide` finding 자동 생성(`origin: auto`, 사후 전이 §6.4), `evidence` = 헤딩 diff 요약. `permit` 이 있는 앵커는 그 라운드 한 번 제외(§8.1) |
| `ask` 의 `blocks` 대상이 승격(보호 부류 → `decide`)되거나 `same_as` 로 병합됨 | `blocks` 는 **최종 id 를 따라간다**. 전제 `ask` 가 미응답이면 대상이 `fix` 든 `adopted` 된 `decide` 든 적용을 보류하고(`applied` 로 못 간다) 승인 집계에 「보류」로 남는다 |
| `supersedes` 가 실재하지 않는 id | 새 finding 으로 취급하고 게이트 텍스트에 「계보 지목 불일치」로 계수 |
| 기각된 계보의 부활(같은 bucket 에 새 finding, 그 bucket 의 직전 계보가 사용자 기각 또는 reject) | **라우터**가 원장으로 대조한다(재비판자는 이력을 받지 않으므로 할 수 없다). 새 finding 은 지우지 않고 게이트 텍스트에 「기각 계보 재상승 — <기각 사유>」를 붙여 사람이 본다 |
| sentinel 블록 파손 | §9 의 source_failed 표 |

오케스트레이터(진입 skill 을 실행하는 세션)는 이 표 밖에서 처분을 바꾸지 않는다. 내리는 손은
사용자(라운드 게이트의 「보류」)와 재비판자(근거 인용 `reject`)뿐이다.

### 6.4 승인의 도출

verdict 는 산출물이 아니라 집계다. `decide` 의 상태는 다섯이다 — `open`(게이트 대기) → 사용자
선택으로 `adopted`(적용 대기, `permit` 발급) / `rejected` / `held`(`ask` 로 하향) → `adopted` 는 다음
라운드 얼림 diff 가 `permit.apply_anchors` 의 변경을 관측하면 `applied`, 관측하지 못하면 `expired`
(같은 계보의 새 `decide` 로 다시 올라온다). **`open` 과 `adopted` 가 0 이고 미적용 `fix` 가 0** 이면
승인 게이트가 열린다 — 채택만 되고 안 고친 결정은 승인을 막는다.

**여기서 `adopted` 는 문자 그대로의 상태값이 아니라 승인을 막는 술어다.** 실제로 집계되는 것은
`state == "adopted"` 이거나, **`state == "expired"` 이면서 아직 그 계보의 후속(다른 finding 의
`supersedes` 가 이 id 를 가리킴)이 없는 것**이다 — 후속이 실제로 생기면(같은 계보에 새 `decide` 가
열리거나, 사용자가 그 후속을 기각·보류하면) 의무는 후속이 지고 만료 항목 자신은 더 이상 막지 않는다.
「같은 계보의 새 `decide` 로 다시 올라온다」는 그 재상승 변환이 항상 성공한다는 전제 위에 있는데,
실제로는 재상승이 두 단계다 — `docreview_state.py` 의 `observe-diff` 가 예약만 `st["reraise"]` 에
적어 두는데, 그 대입(`st["reraise"] = reraise`)은 append 가 아니라 라운드마다 덮어쓰기다. 그 예약을
실제 `decide` finding 으로 바꾸는 재상승 루프는 `docreview_route.py` 의 `finalize` 안에 있다. 그
라운드의 `finalize` 가 그 루프에 이르기 전에 빠져나가면(예: `pending_recritic` 부재로 조기
반환하는 `no_pending_recritic` 가드) 예약은 디스크에 남은 채 소비되지 않고, 다음 라운드
`observe-diff` 가 새로 계산한 값으로 그 자리를 덮어써 예약 자체가 사라진다. 그 창에서는 후속도
사용자도 의무를 지지 않으므로 만료 항목 자신이 계속 승인을 막는다 — fail-closed.

**알려진 한계 둘(PR 2 가 고칠 것).** (a) 해제 술어는 「나를 가리키는 finding 이 있다」뿐이라, 의무를
실제로 지지 않는 후속 — 비차단 `ask` · `drop` · `defer` · 재비판자 `reject` — 도 차단을 푼다. (b)
후속이 영영 안 생기면 사용자에게 탈출구가 없다 — `cmd_decide` 는 `state != "open"` 인 finding 의
재결정을 거부하고(만료 항목은 이미 `open` 이 아니다), `render_gate` 는 `adopted` 집합을 렌더하지
않아 막힌 사실 자체가 게이트 텍스트에 보이지 않는다.

**사후 `decide`(얼림 diff 가 만든 `origin: auto`)는 변경이 이미 일어난 것**이라 전이가 다르다 —
「채택」은 관측된 변경을 승인하는 것이므로 즉시 `applied` 이고, 「기각」은 **원복 의무**를 만든다:
그 앵커에 원복 `permit` 이 열리고 다음 라운드 diff 가 그 앵커의 해시를 기각 시점 이전 스냅샷과 같게
관측해야 `applied`(원복 완료)다. 원복되지 않으면 `expired` 로 다시 올라온다.

상한·stagnation 으로 열리는 승인 게이트에 열린 `decide` 나 미적용 `fix` 가 남아 있을 수 있다. 그때
게이트는 **두 단계**다. 1단계는 라운드 게이트와 같은 형태 — 열린 `decide` 묶음(채택 / 기각 / 보류)과
미적용 `fix` 목록(적용 예정 / **`drop`**)을 묻는다. `fix` 의 `drop` 이 사용자에게 열리는 곳이 여기다
(C4 — 리뷰어와 저자는 올리기만 하고 내리는 손은 사용자다; 재비판을 통과한 오탐 `fix` 하나가 승인을
영구히 막지 않게 한다). 1단계의 답으로 `open`·`adopted` 가 0 **이고** 미적용 `fix` 가 0(적용 또는
`drop`) 이 된 뒤에만 2단계 — `proceed-gate.md` 의 진행 옵션(①/②) — 이 활성이다. 그렇지 않으면
선택지는 「다음 라운드」와 「멈춤」(④)뿐이다: 재리뷰 예산이 남았으면(stagnation 이 상한 전에 열린
경우) 그 라운드는 예산을 쓰고, 상한에 도달했으면 D19 의 개별 승인 라운드다(§8.3). C10 의 「방향이
틀리면 승인 불가」가 상한에서도 유지된다. 답을 못 받아 **보류된 `fix`**(전제 `ask` 미응답)는 미적용으로 세지 않고 승인 게이트에
「보류」로 보인다 — 거기서 사용자가 답하거나 `drop` 한다. `ask`·`defer` 는 승인을 막지 않고 승인
게이트에서 한 번 보인다(D8·D16). 「세부가 완전해도 방향이 틀리면 승인 불가」(C10)는 층 1 의 `decide` 가
열려 있는 상태 그 자체다. design doc 자리의 `mark-reviewed` 는 게이트 도달이 아니라 **2단계에서
사용자가 진행(①/②)을 고른 뒤**다(§5.4 표) — 게이트 표시 · 미응답 · ④ 멈춤에서는 완료 기록이 생기지
않는다.

## 7. 회귀 장치

| 장치 | 무엇을 막나 | 결정론인가 |
|---|---|---|
| 편집 범위 선언(D13) | 저자가 **그 finding 의 `edit_scope`** 밖을 고치는 것 — `check-intent` 는 finding id 를 받아 그 finding 의 범위와 대조한다. 프로필 `fix_anchors` 는 그 위의 상한이다. `insert-after:#x` 는 「#x 바로 뒤에 새 섹션 하나」만 허용한다 | `check-intent` — 예 |
| 얼림(D12) | 이번 라운드에 finding 이 없던 섹션이 바뀌는 것 | 헤딩 diff — 예 |
| 보호 부류(D12) | 목표·범위·제약·Non-goal·아키텍처·trade-off·AC 가 사용자 결정 없이 바뀌는 것 | `protected` — 예 |
| 적용 전 패치 의도(D14) | 즉흥 수정 | 산문(저자 세션의 준수) + `check-intent` |
| 기준선 스냅샷(D13) | 「무엇에 대한 diff 인가」의 모호성 | 세션 state — git 커밋을 요구하지 않는다 |

**못 잡는 것** — 같은 섹션 안에서 한 `fix` 가 다른 문장을 망가뜨리는 회귀. 이것은 다음 라운드
critic 의 눈에 남는다. 문장 단위 diff 로 더 촘촘히 가는 것은 C6 에 걸려 넣지 않는다(§3).

**얼림의 예외 넷** — ① 그 라운드에 `check-intent` 를 통과해 적용된 `fix` 의 `edit_scope`(새 앵커
`insert-after` 포함 — 통과 기록이 state 의 `applied_scopes` 에 남고 다음 라운드 diff 가 그 앵커를
제외한다; 이것이 없으면 규칙대로 삽입한 섹션이 매번 회귀로 오인된다) · ② `permit.apply_anchors`
(§8.1) · ③ `decision_log` · `defer_target` 절의 append · ④ 헤딩 없는 문서(§9). ①②는 라운드 하나만
유효하고, 그 밖의 모든 변경은 자동 `decide` 다.

## 8. 게이트 · 상한 · 결정 기록

### 8.1 라운드 게이트

라운드에 `decide` 가 1건 이상이거나 **`blocks` 가 비어 있지 않은 `ask`** 가 1건 이상이면
`AskUserQuestion` 하나를 띄운다. 질문 텍스트의 첫 줄은 degrade 공시(codex 부재 포함, D7)다. 본문은
결정 단위로 묶은 `decide`(finding 의 변경 내용 · 근거 · 대안 · 영향) + `fix` 의 전제인 `ask`(비차단 —
답이 없어도 라운드는 진행하되 `blocks` 에 든 `fix` 는 보류된다) + 기각 계수다. 선택지는 결정마다
「채택 / 기각 / 보류」이고, 보류는 `decide` 를 `ask` 로 내려 승인 게이트로 넘기는 **사용자의
권한**이다. 둘 다 0 이면 이 게이트는 뜨지 않는다.

**채택의 결과 — `permit`.** 「채택」은 기록만이 아니라 상태 전이다(§6.4 의 `adopted`).
`docreview_state.py` 가 `permits` 에 `{decision_id, apply_anchors: […], round: n+1}` 을 남긴다.
`apply_anchors` 는 그 `decide` 의 `edit_scope`(기본 = 앵커)이고, 앵커가 `immutable` 이면 프로필의
`decision_apply_anchor`(brief · seed = §0·§2 — 열 필드 중 `fix_anchors` 와 같은 값이라 별도 필드가
아니다)다. 그 라운드 한 번에 한해 ① `check-intent` 는 `decision_id` 를 인용한 패치 의도를
`apply_anchors` 안이면 **`fix_anchors` · 보호 부류와 무관하게** 통과시키고(`immutable` 만은 절대
아니다) ② 얼림 diff 가 그 앵커들의 변경을 자동 `decide` 로 만들지 않는다. 적용하는 손은 저자
세션이고 무엇을 바꾸는지는 채택된 `decide` 의 변경 내용이다. 라운드가 지나 변경이 관측되지 않으면
`expired` — 같은 계보의 `decide` 로 다시 올라온다.
「기각」은 그 finding id 를 다음 라운드 집합에서 빼고 결정 기록에 남긴다(§8.4 의 stagnation 입력).

### 8.2 승인 게이트

열린 `decide` 0 · `adopted`(후속 없는 `expired` 포함, §6.4) 0 · 미적용 `fix` 0 일 때, 또는 상한
도달·stagnation 시에 뜬다. 보이는 것은 남은 `ask`·`defer` 목록 · 기각 계수 · degrade · (상한
도달이면) 마지막 라운드의 새 결함 목록이다.
선택지는 `references/proceed-gate.md` 의 4옵션 그대로이고(Non-goal), 열린 것이 남아 있으면 §6.4 의
두 단계 규칙이 앞에 선다 — 그때의 「다음 라운드」는 예산이 남았으면 예산을 쓰고, 상한 도달 시에만
「추가 라운드 1회 열기」(D19, 개별 승인)가 된다. 두 가드(AP2 polite stop 금지 · AC19 cross-compact 조기
진행 금지)는 정본을 그대로 따른다.

### 8.3 재리뷰 상한 2 와 추가 라운드

**계수의 뜻** — 최초 리뷰가 라운드 1 이고 그때 `rereview_count` 는 0 이다. 저자가 고친 뒤의 리뷰마다
+1 이므로 라운드 2 = 1, 라운드 3 = 2 = 상한 도달. 즉 총 리뷰는 **최대 3회**이고 라운드 4 는 사용자가
승인 게이트에서 열어야만 돈다(AC7).

`rereview_count` 는 `docreview_state.py` 가 세션 state 에 두고 프로필·env 는 덮어쓰지 못한다 —
「반드시 필요한 경우」의 판단은 사용자가 게이트에서 하는 것이지 설정값이 아니다. 상한 도달 후
사용자가 추가 라운드를 열면 카운터 대신 **개별 승인 기록**(`extra_rounds: [{round, 사용자 문구}]`)이
남고 라운드마다 다시 묻는다. 자동 연장 경로는 없다.

### 8.4 stagnation 술어의 교체

현행 「`raised_count >= 3 AND dismissed_by_user == 0`」은 상한 2 아래에서 도달 불가능하다(3회
raise 가 남지 않는다). 대체 술어는 하나 — **라운드 n 의 열린 계보(`lineage`) 집합이 n−1 과 같고 그
사이 진행이 0건**이면 저자가 움직이지 않은 것이므로 승인 게이트를 즉시 연다(§6.4 의 두 단계 형태로).
「진행」은 `check-intent` 를 통과한 `fix` 적용과 `permit` 을 통한 채택 결정의 적용(`applied` 전이)
둘을 센다 — 채택된 결정대로 고친 라운드는 계보가 같아도 stagnation 이 아니다. 비교 단위는 id
문자열이 아니라 계보 뿌리다(§6.2 — id 에는 라운드가 박혀 라운드마다 다르다; 계보는 라우터의 자동
연결로 리뷰어가 지목을 빠뜨려도 이어진다). `dismissed_by_user` 의 역할은 라운드 게이트의 「기각」이
대신한다(기각된 계보는 열린 집합에서 빠진다).

### 8.5 결정 기록

append-only, 항목 = `{decision_id, round, finding_ids, 선택(채택/기각/보류), 사용자 문구 verbatim,
supersedes?}`. 뒤집힘은 삭제가 아니라 `supersedes` 가 붙은 새 항목이다. 목적지는 프로필
`decision_log`(§5.3). design doc 의 `## 결정 기록` 절은 없으면 엔진이 만든다 — 이것이 얼림 예외다.

## 9. 오류 처리 · degrade · kill switch

공시와 차단은 다른 술어다(CLAUDE.md). 막는 것은 항목이 소실됐거나 셀 수 없거나 주 판정자가
죽었을 때뿐이다.

| 상황 | 공시(`Ledger`) | 차단 |
|---|---|---|
| codex 부재·실패 | 게이트 첫 줄 「codex 없음 — 모델 다양성 0」 · `source_failed(primary=False)` | 아니오 |
| `doc-critic` 출력에 sentinel 블록이 없거나 깨짐 | `source_failed(primary=True)` | **예** — 라운드를 세지 않고 재dispatch 1회, 또 실패면 승인 게이트를 「미검증」 라벨로 연다 |
| `doc-recritic` 사망 또는 skip | `source_failed(primary=False)` + 「기각 경로 0 — 오탐이 걸러지지 않았다」 | 아니오 — critic 처분이 그대로 간다(올리기만이라 안전 방향) |
| 층 1 블록만 있고 층 2 가 없음 — **프로필이 층 2 를 요구할 때만** | 층 2 `uncountable` | 아니오 — 게이트에 「상세 미검증」. seed 처럼 `layer_rubric` 이 층 2 를 비운 프로필에서는 부재가 정상이라 아무 기록도 남기지 않는다 |
| 문서에 헤딩이 없음(브리프 OQ6) | 「앵커 불가 — 얼림·보호 부류 비활성, 모든 `fix` 가 문서 전체 범위」 | 아니오 — generic 프로필만 허용. 나머지 셋은 구조 게이트가 먼저 막는다 |
| seed 자리 — `state.local.md` 없음(브리프 OQ4) | `framing-requests` 가 이미 만드는 세션 디렉토리에 `docreview-state.md` 를 따로 둔다. `state.local.md` 는 만들지 않는다 | 아니오 |
| 세션 id 미해석(진입 skill 이 `--state-dir` 를 못 만듦) | 스냅샷·카운터 불가 → 얼림 diff 불가 | **예** — 회귀 장치가 통째로 없는 라운드는 돌리지 않는다. 안내문은 호스트의 것 — spec-distill 은 `DEVBREW_SPEC_DISTILL_SESSION_ID`, quality-gates 는 `CLAUDE_CODE_SESSION_ID` |
| 프로필 필드 누락 | 진입 실패 advisory | **예** |
| `check-intent` 실패(앵커 밖·보호 부류) | 그 `fix` 는 적용되지 않고 `decide` 로 상향돼 다음 라운드 게이트에 | 그 finding 만 |

**kill switch** — 호스트 플러그인의 기존 스위치를 상속한다(`DEVBREW_SPEC_DISTILL_DISABLE` ·
`…_DISABLE_CODEX` · `…_DISABLE_WEB` · `DEVBREW_QUALITY_GATES_DISABLE` · `…_DISABLE_CRITIQUE`). 새
스위치는 호스트 관례(`DEVBREW_<PLUGIN>_…`)대로 둘 — `DEVBREW_SPEC_DISTILL_DISABLE_RECRITIC=1` ·
`DEVBREW_QUALITY_GATES_DISABLE_RECRITIC=1`(재비판 skip, 위 표의 「recritic 사망」과 같은 공시). 모든
스위치는 dispatch **직전**에 확인하고 캐시하지 않는다. 두 리뷰어 agent 는 `Bash` 가 없어 스스로 확인할
수 없으므로 집행 지점은 dispatch 블록이 사는 **진입 skill 넷**이고, 스위치 락의 코퍼스도 그 넷이다.

## 10. 이관

원칙은 「자리 하나씩, 자리 안에서는 치환」이다. 두 계약이 공존하는 창은 자리 **사이**에만 있고
한 자리 안에서 옛 리뷰어와 새 엔진이 같은 문서를 보는 라운드는 없다(브리프 OQ3).

| PR | 내용 | 버전 |
|---|---|---|
| 1 | `shared/docreview/` 엔진 + 프로필 스키마 + 행동 락. 호출자 0 인 상태로 머지(링크만 두 플러그인에 심는다) | spec-distill minor · quality-gates minor |
| 2 | design doc 자리 — `reviewing-spec` 껍데기화, §5.5 의 삭제, 상한 락 **재작성**(아래), stagnation 술어 교체, `mark-reviewed` 시점 이동(§5.4). Stop 훅 무변경 | spec-distill **major**(verdict 계약이 깨진다 → 1.0.0) |
| 3 | brief 자리 — `reviewing-brief` 껍데기화, §5.5 의 삭제 | spec-distill minor |
| 4 | generic 자리 — `critiquing-artifacts` 껍데기화, 자율 커밋 루프 소멸 | quality-gates **major** |
| 5 | seed 자리 — `framing-requests` 검증 절 배선, §5.5 의 삭제 | spec-distill minor |

상한 락 `test_rereview_cap_consistency.sh` 는 상수 5 를 갖지 않고 `reviewing-spec/SKILL.md` 의 「Hard
cap」 문구 · design 라우팅 행 · README 흐름도에서 CAP 을 **도출**한다 — 껍데기화가 그 앵커를 전부
지우므로 「5 를 2 로 바꾸는」 치환이 아니라 재작성이다. 새 락의 정본은 `references/reviewing-document.md`
의 `rereview_cap: 2` 한 줄이고, 검사 대상은 네 진입 skill 과 두 README 의 상한 언급 전부다(PR 2 에서
design doc 자리부터, 이후 PR 마다 코퍼스에 자리를 더한다).

각 PR 은 그 자리의 README 「Principles Instantiated」 · CHANGELOG · `plugin.json` bump 를 같은
커밋에 담는다(CLAUDE.md). 삭제 자리의 전수는 plan 이 네 축(식별자 · 개념 별칭 · 의존 폐포 ·
생산자↔소비자 양방향)으로 도출한다.

## 11. Acceptance Criteria

- AC1 — 네 자리 모두 `references/reviewing-document.md` 를 따르고, 자리별 리뷰어 agent 는
  `doc-critic` · `doc-recritic` 둘(+ 냉독 둘)만 남는다. §5.5 의 「사라지는 것」 이름이 **실행 표면**
  (`plugins/*/{agents,skills,scripts,hooks,commands,references}/`)에서 0건이다 — `CHANGELOG.md` ·
  `README.md` 의 이력 언급은 코퍼스 밖이다.
- AC2 — 리뷰 산출물에 `approved` / `needs_revise` / `needs_interview` 문자열이 없다. 승인은 §6.4 의
  집계로만 도출된다.
- AC3 — `docreview_route.py` 가 §6.3 표의 각 행에 대해 픽스처로 그 결과를 내고, 규칙을 하향으로
  뒤집는 mutation 마다 락이 RED 다.
- AC4 — 이전 라운드에 finding 이 없던 섹션을 바꾸면 다음 라운드에 자동 `decide` finding 이 생기고,
  그 `evidence` 에 헤딩 diff 가 실린다. 얼림을 끄는 mutation 이 RED 다.
- AC5 — `protected_headings` 에 매칭되는 앵커의 finding 은 리뷰어가 `fix` 를 내도 `decide` 로 온다.
  매칭을 지우는 mutation 이 RED 다.
- AC6 — `check-intent <finding-id> <intent>` 가 일반 `fix` 에 대해 그 finding 의 `edit_scope` 밖 ·
  프로필 `fix_anchors` 밖 · 보호 부류 · `immutable` 의 패치 의도를 거부하고 그 `fix` 를 `decide` 로
  상향한다. `decision_id` 를 인용한 의도는 유효한 `permit.apply_anchors` 안이면 `edit_scope` ·
  `fix_anchors` · 보호 부류와 무관하게 통과하되 `immutable` 은 거부하고, 라운드가 지난 `permit` 은
  통과시키지 않는다(계약은 둘이고 픽스처도 둘이다).
- AC6b — 라운드 게이트에서 「채택」된 `decide` 는 `permits` 항목을 남기고, 다음 라운드의 얼림 diff 가
  그 앵커의 변경을 자동 `decide` 로 만들지 않는다. `permit` 없이 같은 앵커가 바뀌면 자동 `decide` 다.
- AC6c — `blocks` 가 비어 있지 않은 `ask` 는 `decide` 가 0 인 라운드에도 라운드 게이트를 연다.
  미응답이면 `blocks` 의 `fix` 는 「보류」로 표시되고 미적용 `fix` 로 세지 않으며 승인 게이트에 보인다.
- AC7 — 최초 리뷰(라운드 1)에서 `rereview_count` 는 0 이고 수정 후 리뷰마다 +1 이다. 2 에 도달하면
  (라운드 3 뒤) 승인 게이트가 열리고 선택지에 「추가 라운드 1회 열기」가 있다. 그 선택 없이는 라운드 4 가
  돌지 않는다(자동 연장 경로 0).
- AC8 — codex 부재 라운드의 라운드 게이트·승인 게이트 질문 텍스트 **첫 줄**이 codex 부재 공시다.
- AC9 — `doc-recritic` 의 dispatch 프롬프트 슬롯은 셋뿐이다 — 문서 · 출처 라벨 없는 finding 목록 ·
  프로필 파일. dispatch 사유 · 이전 대화 · 출처 라벨 슬롯이 없다. 락이 **진입 skill 넷**(`reviewing-spec` ·
  `reviewing-brief` · `framing-requests` · `critiquing-artifacts`)의 프롬프트 템플릿을 전부 잰다.
- AC10 — `defer` finding 은 design-doc 프로필에서만 나오고, 그 목적지는 문서의
  `### Deferred to plan` 표다. 다른 세 프로필에서 `defer` 가 나오면 §6.3 의 명시 예외로 `ask` 로
  상향되고(`fix` 가 아니다) `coerced` 로 계수된다 — 세 프로필 픽스처가 같은 결과를 낸다.
- AC11 — brief 프로필에서 §6 앵커의 `fix` 는 `decide` 로 오고 그 결정의 `permit` 앵커는 §0·§2 다.
  어떤 처분도, 채택된 `decide` 도 §6 본문을 바꾸지 않는다.
- AC12 — 결정 기록이 프로필 `decision_log` 목적지에 append-only 로 남고, 뒤집힘은 `supersedes`
  항목이다. 기존 항목이 바뀌면 락이 RED 다.
- AC13 — 재작성된 상한 락이 `references/reviewing-document.md` 의 `rereview_cap: 2` 를 정본으로
  도출하고, 네 진입 skill 과 두 README 의 상한 언급이 전부 그 값과 같다. 정본을 3 으로 바꾸는 mutation
  에 RED 다(도출이 살아 있다는 증거).
- AC14 — `shared/tests/test_copy_of_contract.sh` 축 1a 의 구조 도출이 `plugins/*/{scripts,agents,references}/`
  를 덮고, 새 링크 전부(링크 정본 5 = 스크립트 4 · reference 1, 호스트 2 → 10)를 잰다. agent 둘은
  링크가 아니라 사본이므로(§5.1) 축 1a 가 아니라 **축 1b**(copy-of 바이트 동일)가 호스트 2 → 사본 4 를
  잰다. 프로필은 호스트 데이터라 둘 다 아니다. 확장 전후로 기존 정본의 도출 수가 같다. 링크 하나를
  사본으로 바꾸는 mutation 이 RED 다.
- AC15 — `/qg critique` 가 라운드마다 git 커밋을 만들지 않는다. `artifact_commit.sh` 가 없다.
- AC16 — 두 리뷰어 agent 의 `tools:` 에 `Write` · `Edit` · `Bash` 가 없다(Law 2).
- AC17 — 모든 dispatch 자리에 처분 한 줄이 있고 `shared/tests/test_dispatch_disposition.sh` 가 GREEN 이다.
- AC18 — `codex_findings_to_yaml.py --emit-keys docreview` 가 `layer` · `disposition` · `edit_scope` 를
  emit 한다. 기존 `default` · `design` keyset 의 출력은 바이트 단위로 변하지 않는다.
- AC19 — 한 bucket 에 finding 이 둘 이상이면 각각 다른 `#r<round>.<k>` 를 갖고, 다른 라운드의 새 finding 은 이전 라운드의 id 를 재사용하지 않으며, 한 id 의 reject·기각이 같은
  bucket 의 다른 id 를 지우지 않는다.

## 12. Files to Modify

영향 범위다. 정확한 줄과 삭제 전수는 plan 이 도출한다.

**신규(`shared/docreview/`)** — `agents/doc-critic.md` · `agents/doc-recritic.md` ·
`scripts/docreview_anchor.py` · `scripts/docreview_route.py` · `scripts/docreview_state.py` ·
`scripts/run_docreview_codex_reviewer.sh` · `references/reviewing-document.md` ·
`shared/tests/test_docreview_route.sh` · `shared/tests/test_docreview_anchor.sh` · 픽스처.

**신규(호스트)** — `plugins/spec-distill/references/docreview-profiles/{design-doc,brief,seed}.md` ·
`plugins/quality-gates/references/docreview-profiles/generic.md` · 두 플러그인의 `scripts/` ·
`references/` 에 파일 단위 상대 심볼릭 링크 · `agents/` 에 `copy-of:` 사본(§5.1).

**수정(shared, 추가만)** — `shared/codex/codex_findings_to_yaml.py`(`--emit-keys docreview` 추가, 기존
keyset 불변) · `shared/tests/test_copy_of_contract.sh`(축 1a 구조 도출을 `agents`·`references` 로 확장).

**수정** — `plugins/spec-distill/skills/reviewing-spec/SKILL.md`(껍데기화) · `reviewing-brief/SKILL.md` ·
`framing-requests/SKILL.md`(검증 절) · `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md` ·
`plugins/quality-gates/commands/`(critique 진입 문구) · 두 README · 두 CHANGELOG · 두 `plugin.json` ·
`plugins/spec-distill/tests/test_rereview_cap_consistency.sh`(재작성 — 정본을 reference 의
`rereview_cap` 으로) · `shared/README.md`(디렉토리 표에 `docreview/` 행) ·
`docs/philosophy/devbrew-harness-philosophy.md` 의 코드 지도(리뷰 자리 목록).

**삭제** — §5.5 의 「사라지는 것」과 그것만 재는 테스트(`test_spec_reviewer_*` ·
`test_merge_review*` · `test_brief_agents.sh` 의 critic/direction 부분 · `test_brief_codex_axes.sh` ·
`test_seed_codex_axes.sh` · `test_artifact_*` 중 critic/adversarial/commit/stagnation/max_rounds ·
`test_synthesize_artifact_*` 등 — 전수는 plan).

**무변경(명시)** — `plugins/spec-distill/hooks/review-dispatch.py` · `references/proceed-gate.md` ·
`plugins/quality-gates/skills/quality-pipeline/` 전부 · `shared/adjudication/` · `shared/codex/` 중
`codex_findings_to_yaml.py` 를 제외한 전부.

## 13. Verification Plan

「무엇이 관측되면 통과인가」만 적는다. 절차·명령은 plan 의 것이다.

0. **PR 1 착수 전 측정 — 링크 로더 가정.** `agents/` · `references/` 의 파일 단위 심볼릭 링크를
   Claude Code 가 따라가는지는 실측이 `scripts/`(실행·source 소비)에 대해서만 있다. 관측 기준:
   임시 플러그인에 `agents/doc-critic.md` 를 `shared/` 로의 상대 링크로 두고 `--plugin-dir` 와
   `claude plugin install`(격리 `CLAUDE_CONFIG_DIR`) 양쪽에서 `<plugin>:doc-critic` 이 dispatch 되고
   `references/` 링크가 `Read` 로 읽힌다. 한쪽이라도 실패하면 그 디렉토리는 링크 대신 **바이트 동일
   사본 + `copy-of:` 마커**(기존 잔여 계약)로 가고 §5.1 · AC14 를 그에 맞게 고친다 — 아키텍처는
   바뀌지 않고 배포 방식만 바뀐다.
1. **행동 락(`shared/tests/`)** — `docreview_route.py` 와 `docreview_anchor.py` 를 픽스처 위에서
   실행해 §6.3 표의 행마다 양성 케이스와 mutation 케이스(상향→하향 · 보호 매칭 제거 · 얼림 diff
   비활성 · reject 의 evidence 요구 제거)가 각각 GREEN/RED 다. GREEN 만 있는 락은 두지 않는다.
2. **구조 락(기존 재사용)** — `test_copy_of_contract.sh`(링크) · `test_dispatch_disposition.sh`(처분
   한 줄) · `test_agent_input_slots.sh` · `test_skill_reference_pointers.sh` 의 코퍼스에 새 자리가
   들어가 GREEN 이다.
3. **프롬프트 락** — 진입 skill 넷의 `doc-recritic` dispatch 템플릿이 슬롯 **셋**(문서 · 출처 없는
   finding 목록 · 프로필 파일)을 갖고 그 밖의 슬롯(dispatch 사유 · 이전 대화 · 출처 라벨 · 이전 라운드
   이력)이 없다(AC9). 프로필이 들어가는 것은 프레이밍 차단과 충돌하지 않는다 — 차단하는 것은 「왜
   이 리뷰가 열렸고 앞 라운드에 무슨 일이 있었나」이지 그 자리의 공개 계약(허용 처분값 · rubric ·
   보호 헤딩)이 아니며, 그 계약 없이는 처분 상향 판정이 성립하지 않는다(09-02 OQ12 의 입력 비대칭은
   이 둘 사이에 선다).
4. **자리별 e2e(사람이 관측)** — 각 PR 머지 전에 그 자리의 실제 문서 하나로 **최초 리뷰 + 재리뷰
   2회 = 라운드 3회**를 돌려 다음 넷을 본다: 라운드 게이트에 `decide` 묶음이 C2 의 네 항목을 채워
   보인다 · 얼린 섹션을 일부러 건드리면 자동 `decide` 가 뜬다 · 라운드 3 뒤 승인 게이트에 「추가
   라운드 1회 열기」가 선택지에 있다 · 그 선택 없이 라운드 4 가 돌지 않는다. design doc 자리의 e2e
   대상은 이 설계 문서 자체다(OQ-A 의 `decide` 비율이 그 자리에서 바로 보인다).
5. **baseline** — 각 PR 착수 전에 두 플러그인 테스트의 선재 RED 를 rc 가 아니라 **실패 줄 수**로
   기록한다(이미 RED 인 파일 안의 새 실패를 잡기 위해).

## 14. Rejected Alternatives

| 대안 | 왜 버렸나 |
|---|---|
| 두 층을 별개 리뷰어로, 층 1 은 verdict 없이 질문만 | 근본 원인(수신자 부재)의 약은 리뷰어 분할이 아니라 finding 의 수신자 필드다. 같은 모델을 하나 더 두는 것은 독립 표를 더하지 않는다(브리프 ST1) |
| 탐지 리뷰어 병렬 N명 + 합집합 | 같은 모델 복제는 독립 표를 거의 더하지 않고 finding 수를 N배로 늘려 `decide` 인플레이션을 키운다. 이 리포에서 두 번째 판정자가 단독으로 잡은 사례는 전부 다른 계열(codex)이거나 다른 역할(adversarial)이었다. 프로필에 `detectors` 값을 두어 측정 근거가 생기면 열 수 있게만 한다(§16 Q1) |
| 같은 persona 를 층별로 두 번 호출 | 후광을 원리적으로 0 으로 만들지만 라운드당 dispatch·파싱 지점이 하나씩 는다. 순차 생성에서 층 1 블록을 먼저 써내면 상세 finding 이 아직 없는 시점이라 브리프가 걱정한 방향(상세→방향 오염)은 출력 순서가 줄이고, 재비판자의 층 상향이 두 번째 가드다(§16 Q2) |
| 층 1 은 라운드 1 만, 층 2 는 `decide` 0 이후 | 상한 2 아래에서 층 2 가 한 번밖에 못 돈다 |
| spec-distill 이 호스팅, quality-gates 가 cross-plugin dispatch | quality-gates 가 라우팅·헤딩 diff 스크립트에 도달 못 해 결국 링크가 필요하고 spec-distill 하드 의존이 새로 생긴다 |
| 새 플러그인 `doc-review` | 소유권은 깔끔하나 스크립트 도달 불가를 풀지 못하고 Stop 훅 목적지·brief state 네임스페이스가 플러그인 경계를 넘는다(Non-goal 충돌). 훗날 훅 목적지가 데이터가 되면 옮기는 길은 열려 있다 |
| 결정 기록을 항상 문서 본문에 | brief §6 불변·bijection 락과 충돌하고 남의 generic 문서를 오염한다 |
| 결정 기록을 항상 별도 사이드카에 | writing-plans 가 그 파일을 읽는 계약을 새로 만들어야 한다 |
| 결정 기록을 세션 state 에만 | TTL-GC 가 걷어간다 — 다음 세션이 읽을 수 없다(Law 3) |
| finding id 를 리뷰어가 self-report | 현행 `compute_issue_id.py` 가 「LLM in-head 해싱 신뢰 불가」로 이미 기각한 길 |
| 문장 단위 diff 로 같은 섹션 안의 회귀까지 | C6 위반 — 무거운 하니스 |
| 옛 stagnation 술어 유지 | 상한 2 에서 도달 불가 |
| 진입 skill 이름도 새로 | Stop 훅 상수·`conducting-interview`·`/qg critique` 배선 세 곳이 범위에 들어온다. 이름은 배선이지 모양이 아니다 |
| `defer` 를 네 프로필 모두 허용 | plan 이 읽는 목적지가 design doc 에만 있다. 목적지 없는 `defer` 는 침묵 삭제와 같다 |

## 15. Open Questions

이 설계가 닫지 않은 것. 유추하지 않는다.

- **OQ-A** — 첫 e2e 에서 재비판자의 `reject` 비율과 사용자 「기각」 비율을 재는가(09-02 OQ14 의
  로컬 측정). 설계는 측정 자리(승인 게이트의 기각 계수)만 두고 임계값을 정하지 않는다. 같은 자리에서
  **`decide` 비율**도 잰다 — design-doc 프로필의 `protected_headings` 에 Architecture 가 들어가면 이
  문서처럼 §5 가 큰 설계에서는 상세 finding 대부분이 `decide` 로 승격될 수 있다. 그 비율이 높으면
  보호 부류를 헤딩 단위가 아니라 소절 단위로 좁히는 것이 다음 사이클의 후보다.
- **OQ-B** — 헤딩이 있으되 계층이 얕은 문서(`##` 하나뿐)에서 얼림 단위가 문서 전체가 되는 경우의
  취급. 지금은 헤딩 없음과 같은 advisory 로 간다.
- **OQ-C** — `doc-critic` 의 웹 허용을 brief 프로필에만 두었다. design-doc 프로필에서 외부 근거가
  필요한 finding(구현 가능성)이 나오면 그때 `web: true` 로 열지, 별도 처분값으로 둘지.
- **OQ-D** — 두 네임스페이스로 설치된 같은 agent 의 캐시 중복이 `claude plugin install` 크기에
  실제로 얼마나 더해지는지. 측정하지 않았다.

09-02 인터뷰 OQ11~OQ19 의 처분(브리프 OQ9):

| 09-02 | 처분 |
|---|---|
| OQ11 분기 판정자의 프레이밍 공유 | 닫힘 — 처분의 최종 판정자는 프레이밍을 못 보는 `doc-recritic` 이고 오케스트레이터는 올리기만 한다 |
| OQ12 입력 비대칭을 설계 수단으로 | 채택 — critic 은 문서 + 프로필 + 같은 출처 이력을, recritic 은 문서 + 출처 없는 finding + 프로필을 받는다. 비대칭은 「이력과 출처」에 있다(§13 항목 3) |
| OQ13 1명 vs N명 | 닫힘 — 1명(§16 Q1) |
| OQ14 통일의 로컬 측정 부재 | 남김 — OQ-A |
| OQ15 프레이밍 누출 경로 전수 | 부분 — recritic 프롬프트는 문서+finding 뿐이라고 계약(AC9). 다른 dispatch 자리는 범위 밖 |
| OQ16 별계열 모델을 계약 안에 | 밖 — codex 는 공시만, 차단 안 함(D7) |
| OQ17 기각 계수 | 닫힘 — `Ledger.reject()` 가 별도 칸. 환산 없이 상태별 카운트 공시 |
| OQ18 회계 어휘 통일 반례 | 회피 — 어휘를 통일하지 않고 `Ledger` 하나를 재사용. 렌더는 각 게이트 텍스트 |
| OQ19 집행 층 | 남김 — 행동 락이 재고, agent 정의 집합은 이번에 만들지 않는다 |

## 16. 결정 기록

이 설계 세션에서 사용자가 답한 것 넷(브리프 OQ 해소)과 설계가 혼자 닫은 것. 뒤집힘은 여기에
`supersedes` 항목으로 붙는다.

| id | 결정 | 근거 | 뒤집는 말 |
|---|---|---|---|
| Q1 | 탐지 리뷰어 한 명. 프로필에 `detectors` 값만 둔다(브리프 OQ8) | 같은 모델 복제는 독립 표를 더하지 않는다 · 리포의 단독 적발 사례는 전부 별계열·별역할 | 「병렬 N 으로」 |
| Q2 | 한 호출, 층별 sentinel 블록 둘(브리프 OQ2) | 순차 생성이 상세→방향 오염을 줄인다 · 재비판자의 층 상향이 두 번째 가드 · dispatch 증가 0 | 「층별 두 호출로」 |
| Q3 | 결정 기록은 프로필별 기본값(브리프 OQ5) | design doc 은 본문, brief/seed 는 audit, generic 은 state | 「항상 본문에」 |
| Q4 | `shared/docreview/` 정본 + 심볼릭 링크, 진입 skill 이름 유지(브리프 OQ1) | 실측된 메커니즘 · 새 의존 0 · 새 락 0 | 「이름도 새로」 → Stop 훅 상수 1줄 + 커맨드 2줄이 범위에 |
| S1 | 방향성 리뷰어의 웹 탐색은 brief 프로필의 `web: true` 로 흡수 | 근거 폭이 본질인 축은 brief 의 방향성 하나뿐 | 「방향 리뷰어는 별도 agent 로」(ST1 재개) |
| S2 | 냉독 둘은 엔진 밖에 그대로 | 처분 없는 측정 | 「냉독도 엔진에」 → 처분 없는 산출물 어휘가 하나 는다 |
| S3 | finding id = `(layer, category, anchor)` 해시 + `supersedes` | self-report 는 이미 기각된 길 | 「id 는 리뷰어가」 |
| S4 | stagnation = 「id 집합 동일 + fix 적용 0」 | 옛 술어가 상한 2 에서 도달 불가 | 「stagnation 없이 상한만」 |
| S5 | 두 플러그인 모두 major bump | verdict → 처분은 계약 변경 | 「0.x 유지」 |
| S6 | `defer` 는 design-doc 프로필만 | 목적지가 거기만 있다 | 「brief 에도 `defer`」 → 목적지 절을 새로 정해야 한다 |
| S7 (리뷰 라운드 1 이후) | Q4 의 「엔진 skill 본문 1 링크」를 「절차 reference 1 링크 + dispatch 블록은 호스트 진입 skill 안」으로 | 처분 락 축 A⑤ 가 dispatch 앵커의 플러그인과 `consumer=` 의 플러그인 동일성을 요구한다(리뷰어 인용, 파일에서 확인). Q4 의 배치 자체는 유지 | 「락을 고쳐서 skill 공유」 |
| S8 (리뷰 라운드 1 이후) | Q4 의 「새 락 0」을 「기존 링크 락의 도출 축 확장」으로 정정 | `test_copy_of_contract.sh` 구조 도출이 `scripts/` 한정(371–397행) | 「agent·reference 는 링크 말고 `copy-of` 사본」 — **agent 에 대해서는 §5.1 이 이미 이 방향으로 뒤집었다**(2026-09-06 링크 로더 실측 실패, `agents/` 만 `copy-of` 사본; `references/` 는 이 행의 전제대로 링크 유지) |
| S9 (리뷰 라운드 1 이후) | `shared/codex/codex_findings_to_yaml.py` 를 무변경에서 추가 수정으로 | 고정 keyset 이 `disposition` 을 버린다 | 「codex 처분은 안 받고 recritic 이 전부 붙인다」 |
| S10 (리뷰 라운드 1 이후) | 채택된 `decide` 는 `permit` 을 연다 · `check-intent` 는 finding 의 `edit_scope` 를 본다 · `ask` 는 `blocks` 로 `fix` 에 연결 · id 는 bucket+순번 · 불허 `defer` 는 `ask` · `immutable` 의 decide 적용처는 요약 | codex 5건 · Claude 2건이 계약 공백을 지적. 어느 것도 브리프 확정을 뒤집지 않고 채운다 | 각 행의 규칙을 이름으로 |
| S11 (리뷰 라운드 2 이후) | 리뷰어 임시 `ref` + 라운드 박힌 id + 라우터 자동 계보 · `permit.apply_anchors` · `decide` 상태 다섯 · `applied_scopes` 얼림 예외 · 완료 기록은 승인 게이트 도달 시점 · 링크 로더 사전 측정(§13 항목 0) | Claude 6건 · codex 7건 — 라운드 1 수정이 만든 계약 공백. 브리프 확정 불변 | 각 행의 규칙을 이름으로 |
| S12 (리뷰 라운드 3 이후) | `docreview_state.py` 는 state 디렉토리를 인자로 받고 호스트 모듈을 import 하지 않음 · 완료 기록은 승인 게이트 **진행 선택 뒤**, ④ 는 `clear-inflight` 만, 자동 재개 없음 · 얼림 술어는 §7 한 곳 · 상한/stagnation 게이트는 두 단계 · 진행 = fix 적용 + permit 적용 · 부활 대조는 라우터 · emit keyset 은 §6.2 전부 · 스위치는 호스트별 둘 · 집행·락 코퍼스는 진입 skill 넷 | Claude 6건 · codex 4건 — 라운드 2 수정이 남긴 좁은 공백 | 각 행의 규칙을 이름으로 |
| S13 (리뷰 라운드 4 이후 — 사용자 승인 추가 라운드) | 사후 auto `decide` 의 전이(채택=즉시 applied · 기각=원복 permit) · 승인 게이트 1단계에서 사용자가 미적용 `fix` 를 `drop` 가능 · 완료 기록은 진행 선택 뒤로 문구 통일 · stagnation 게이트의 「다음 라운드」는 예산 우선 · `blocks` 는 최종 id 를 따름 · `refs` 서브커맨드 표 등재 · `check-intent` 계약 둘 | Claude 2건 · codex 5건 — 상태 기계의 문장 정합 | 각 행의 규칙을 이름으로 |

## 17. Concrete Next Action

이 문서가 리뷰를 통과하면 `Skill superpowers:writing-plans docs/superpowers/specs/2026-09-06-document-review-redesign-design.md`.
plan 의 첫 태스크는 §10 PR 1(`shared/docreview/` 엔진 + 행동 락, 호출자 0)이다.

## Handoff Context

`/compact` 를 지나면 대화가 사라진다. 이 문서만 읽고 이어갈 수 있어야 하는 것을 남긴다.

### TL;DR

문서 리뷰 자리 넷을 `shared/docreview/` 의 엔진 하나(agent 2 · 스크립트 4 · 절차 reference 1 —
dispatch 블록은 처분 락 때문에 호스트 진입 skill 안에)와 호스트 플러그인의 프로필 넷으로 치환한다. 산출물은 verdict 가 아니라 처분 다섯 값이 붙은 finding 목록이고,
오케스트레이터는 올리기만 하며, 내리는 손은 사용자와 프레이밍을 못 보는 재비판자뿐이다. 회귀는
편집 범위 선언 · 얼림 · 보호 부류 · 패치 의도로 막고 결정론은 헤딩 diff 와 보호 목록 둘이다.
재리뷰 상한 2, 추가 라운드는 제안만. 이관은 PR 다섯, 자리 하나씩 치환.

### Deferred to plan — 이 설계가 의도적으로 정하지 않은 것

| # | plan 이 정할 것 | 어디서 왔나 |
|---|---|---|
| D0 | **삭제 자리 전수 목록** — §5.5 는 씨앗이다. 네 축(식별자 · 개념 별칭 · 의존 폐포 · 생산자↔소비자 양방향)으로 도출한다 | §5.5 · §12 |
| D1 | `docreview_anchor.py` 의 헤딩 파싱 규칙(setext 헤딩 · 코드 펜스 안의 `#` · 앵커 slug 생성)과 해시 단위 | §5.2 · §6.1 |
| D2 | `docreview_route.py` 의 입출력 형식(stdin YAML 인가 파일 경로인가) · `adjudication_*` 키 렌더 | §5.2 · §6.3 |
| D3 | `docreview_state.py` 가 `state.local.md` 의 어느 키를 쓰는지 · `brief_review_state.py` 와의 키 충돌 회피 · seed 자리의 `docreview-state.md` 스키마 | §5.2 · §9 |
| D4 | sentinel 블록 이름과 파서(`docreview-layer1` · `docreview-layer2` · recritic 의 verdict 블록) · 파손 판정 규칙 | §6.1 · §9 |
| D5 | 프로필 파일의 frontmatter 문법과 `protected_headings` 정규식의 정확한 값(한국어 헤딩 대응 포함) | §5.3 |
| D6 | 라운드 게이트 질문 텍스트의 렌더 형식(결정 묶음 하나가 몇 줄인가) | §8.1 |
| D7 | 행동 락의 픽스처 집합과 mutation 매트릭스의 정확한 셀. 락이 `docreview_route.py` 를 실행할 때 `import adjudication` 이 형제로 잡히도록 호스트 경로(`plugins/<host>/scripts/`)로 부른다(`shared/codex` 관례) | §13 |
| D8 | 상한 5 파생 위치의 전수(§12 는 씨앗)와 재작성된 상한 락의 코퍼스 도출 방식 | §10 · AC13 |
| D11 | `permits` 의 state 스키마와 소멸 규칙의 구현(라운드 번호 비교) · `blocks` 미응답 `fix` 의 「보류」 렌더 | §8.1 · AC6b · AC6c |
| D12 | `test_copy_of_contract.sh` 축 1a 확장의 정확한 glob 과 「도출 수 불변」 사전 측정 절차 | §5.1 · AC14 |
| D13 | **finding·decide 상태 전이표 한 장** — §6.2 · §6.3 · §6.4 · §7 · §8.1 · §8.4 에 흩어진 규칙(처분 다섯 · decide 상태 다섯 · permit · applied_scopes · blocks · 계보 · 사후 auto decide)을 상태 × 사건 표로 접고, 그 표의 셀 하나하나를 `docreview_route.py` 픽스처로 만든다. 리뷰 4 라운드가 매번 이 산문의 이음매에서 새 공백을 찾았다 — 산문이 아니라 표가 정본이어야 하고, 표에서 산문과 어긋나는 칸이 나오면 표가 이긴다(보고 후) | §6 · §7 · §8 · 리뷰 라운드 1~4 |
| D9 | 각 PR 의 커밋 분해와 CHANGELOG 문구 | §10 |
| D10 | 자리별 e2e 의 대상 문서와 절차 | §13 |

**plan 으로 미루지 않은 것** — kill switch 목록(§9: 상속 + 신규 1) · 버전 bump 방향(§10: major 둘) ·
Stop 훅 무변경(§3) · 진입 skill 이름 유지(§5.4). 넷 다 설계 단계에서 닫았다.

### Implicit context — 이 문서 밖에 있으면 안 되는 암묵 컨텍스트

- 작업은 워크트리 `.claude/worktrees/document-review-redesign`, base `main@5a56e4c` 에서 한다.
  인터뷰 산출물 넷(09-05 seed·audit · 09-06 brief·audit)은 그 안에 있고 아직 git 에 없다.
- 브리프의 확정 항목은 **근거가 있으면 보고 후 재결정 가능하고 임의 변경은 금지**다. 이 문서의
  §16 이 그 기록 자리다.
- 브리프 D10 의 현행 기준은 09-02 인터뷰 C3(M1·M3 유지 · M2·M4 반전)이다. 08-27 핸드오프의
  M2·M4 를 현행으로 읽으면 틀린다.
- `shared/` 링크는 설치 시점에 풀린다는 사실은 weight-reduction 설계 §16.1 의 실측이고 그 실측은
  `scripts/` 소비에 대한 것이다. agent·reference 파일에 대한 링크는 이 설계가 처음 쓴다 — PR 1 착수
  **전에** §13 항목 0 의 측정을 먼저 하고, 실패하면 `copy-of` 사본으로 간다.
- 상한 5 는 `quality-pipeline`(코드 Review 게이트)에도 있으나 Non-goal 이다. 그 5 를 바꾸지 않는다.
- `resolve_mode.py` 는 Stop 훅 `review-dispatch.py` 가 import 한다(확인됨) — 삭제 목록이 아니라
  무변경 목록이다. plan 의 D0 도출은 삭제 후보마다 이런 import 의존을 먼저 확인한다.
