---
name: framing-intent-drift
type: design
created_at: 2026-09-16
source_interview: docs/superpowers/interview/2026-09-15-framing-intent-drift-interview.md
next_phase: superpowers:writing-plans
---

# Phase 0 의도 이탈 차단 — 설계

> **공시는 무응답이 가능하지만 질문은 아니다.**

spec-distill Phase 0(`/request-framing` command · `framing-requests` skill)이 만드는 interview-seed 가
사용자 의도에서 벗어나는 문제를 고친다. 고치는 방법은 단계를 더하는 것이 아니라 **처분의 주체를
옮기는 것**이다 — 리뷰어의 탐지 역할은 그대로 두고, 지적을 반영할지는 저자가 아니라 사용자가
항목마다 정한다. 같은 릴리스에서 문서 리뷰 재설계의 마지막 PR(seed 자리를 공유 엔진으로)을 함께
수행한다. 자기보고 공시 블록 하나를 질문으로 바꾸고, seed 프로필 한 줄로 저자 단독 반영 경로를
닫고, 엔진이 손대지 않는 자리(헤딩 없는 문서의 얼림 검사)는 호스트가 diff 공시로 메운다.

## 목차

- [1. Context · Why](#1-context--why)
  - [1.1 현행 판본에서 재현되는가](#11-현행-판본에서-재현되는가)
  - [1.2 엔진에서 처분이 하는 일](#12-엔진에서-처분이-하는-일)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. Constraints](#4-constraints)
- [5. Architecture](#5-architecture)
  - [5.1 한 사이클의 흐름](#51-한-사이클의-흐름)
  - [5.2 변경 A — 형성 라운드의 확인 질문](#52-변경-a--형성-라운드의-확인-질문)
  - [5.3 변경 B — seed 프로필 `immutable`](#53-변경-b--seed-프로필-immutable)
  - [5.4 변경 C — 검증 절을 엔진으로 배선](#54-변경-c--검증-절을-엔진으로-배선)
  - [5.5 변경 D — 저자 편집 diff 공시](#55-변경-d--저자-편집-diff-공시)
  - [5.6 변경 E — Phase 1 출처 규약](#56-변경-e--phase-1-출처-규약)
- [6. 데이터 흐름 — 무엇이 어디서 나와 어디로 가나](#6-데이터-흐름--무엇이-어디서-나와-어디로-가나)
- [7. 위험](#7-위험)
- [8. Acceptance Criteria](#8-acceptance-criteria)
- [9. Files to Modify](#9-files-to-modify)
- [10. Verification Plan](#10-verification-plan)
- [11. Rejected Alternatives](#11-rejected-alternatives)
- [12. Open Questions](#12-open-questions)
- [결정 기록](#결정-기록)
- [Handoff Context](#handoff-context)
  - [Deferred to plan](#deferred-to-plan)

## 1. Context · Why

브리프(`source_interview`)가 문제를 이렇게 재구성했다: 사용자가 처음 말한 것은 «과함»이었으나
(C1), 되물었을 때 고른 것은 **«내 의도와 seed 의 의도가 안 맞음, 내가 원하지 않는 방향으로
가는듯함»**이었다(C2). 새는 지점 셋을 사용자가 직접 골랐다(C3): 사용자 없이 도는 리뷰→수정,
짧은 답이 에이전트 말로 굳는 것, 에이전트 추론이 seed 에 실리는 것.

### 1.1 현행 판본에서 재현되는가

브리프가 설계의 **첫 확인 대상**으로 지정한 것이다(C14 · OQ0).

**재현된다. 일화가 아니라 구조로 재현된다.** 근거는 현행 `framing-requests/SKILL.md`(3.1.0) 전문을
읽어 확인했다.

| 관측 | 자리 |
|---|---|
| 검증과 게이트 사이에 **항목별 처분 단계가 없다** | 절 구성이 확산 → 상태 → 검증 → 확정 게이트다. 그 사이에 사용자가 지적마다 답해야 진행되는 자리가 없다 |
| 세 리뷰의 raw 출력은 사용자에게 가지만 **답을 요구하지 않는다** | `SKILL.md:488-491` — 「사용자에게 직접 갑니다 — orchestrator 는 판정하지도 병합하지도 않습니다」. 배달은 있고 처분은 없다 |
| 게이트 ③ 을 고른 뒤 다시 깎는 주체가 **저자 혼자다** | `SKILL.md:602` — 「수정 필요 — 압축을 다시 깎고 이 게이트로 돌아옵니다」 |
| 형성 중 공시가 **자기보고**다 | `SKILL.md:166-167` 의 네 블록 중 «원문과 다른 점». 저자가 인지한 이탈만 오른다(C11) |
| 원 설계의 «사용자 편집» 단계가 **구현에 없다** | `docs/superpowers/specs/2026-08-23-request-framing-design.md:124-125` 의 §2.4 3번. `plugins/spec-distill` 전체에서 해당 단계 0건 |

0.57.0 이 넣은 산문 규약(«(사용자 확인)» 표시 · «다시 검증할 것 —» 문단, `SKILL.md:34-54`)은 이
누수를 닫지 못한다. 그것은 **표기 규약**이지 처분 장치가 아니다. 그리고 같은 절이 스스로 적는다 —
마커 오용(추론 문장에 «(사용자 확인)» 을 잘못 붙이는 것)은 냉독의 몫이 아니라 격리 critic 축 4 의
몫이다(`SKILL.md:49-54`). 그 critic 의 지적은 다시 위 표의 저자-단독 경로로 돌아온다. **고리가 자기
자신으로 닫힌다.**

**본 것과 안 본 것** — 이 판정은 현행 스킬·엔진 소스를 읽어 내린 것이고, 파이프라인을 실제로 한
바퀴 돌려 관측한 것이 아니다. 9/5 당시 판본과의 대조도 하지 않았다.

### 1.2 엔진에서 처분이 하는 일

수단을 고르기 전에 공유 엔진의 처분 다섯이 각각 무엇을 보장하는지 실측·정독으로 확인했다. 요약:

| 처분 | 승인을 막나 | 사용자 문구를 남기나 | 근거 |
|---|---|---|---|
| `decide` | **막는다** | **요구한다**(`--quote` 필수) | `docreview_state.py` 의 `GATE_ROWS` 행 `open_decide`(open·blocks 둘 다 참) · `cmd_decide` 의 `--quote` required |
| `ask`(전제 fix 있음) | 안 막는다(라운드 게이트만 연다) | 안 남긴다 | `GATE_ROWS` 행 `blocking_ask_open`(open 참 · blocks 거짓) |
| `ask`(전제 없음) | **안 막는다** | 안 남긴다 | `GATE_ROWS` 행 `ask_open`(open·blocks 둘 다 거짓) · `cmd_ask` 는 `--answered` 플래그만 받는다 |
| `fix` | 막는다 | 안 남긴다 | 저자가 `check-intent` 통과 후 **혼자** 적용한다 |
| `drop` · recritic `reject` | 안 막는다 | — | 회계에만 남고 개수 공시(`reviewing-document.md:51`) |

**따라서 «지적 처분은 사용자 앞에서»(C7 · C9)를 실제로 보장하는 처분은 `decide` 하나뿐이다.**
브리프 §2 의 ✎ 배경 메모가 후보로 적은 «허용 처분에서 `fix` 빼기»는 이 표 때문에 기각된다 —
프로필 검증기가 허용 목록에 `decide` 와 `ask` 를 **둘 다 강제**하므로(`docreview_state.py:137-140`)
`fix` 를 빼면 강제 승격 규칙(`docreview_route.py:398-403`, `RANK` 는 `docreview_state.py:36`)상
`ask` 로 떨어지고, 전제 fix 가 사라졌으므로 그 `ask` 는 `blocks` 가 비어 **승인도 라운드 게이트도
막지 않는다.** 아무것도 안 하는 것보다 나쁘다.

같은 메모의 둘째 후보(«seed 에 헤딩 주기»)가 계약과 부딪친다는 서술도 부정확했다. `check_seed.py`
가 막는 것은 **답-슬롯 헤딩 넷**(`미해결 질문|Open Questions|대안|Alternatives|인수 조건|Acceptance
Criteria|기각|Rejected`, `check_seed.py:28-30`)이고, 「슬롯 존재 검사를 추가하지 마라」는 금지는
**검사기에 검사를 더하는 것**에 대한 것이다(`SKILL.md:640-646` · `tests/test_seed_one_sentence.sh`).
seed 가 제목 헤딩을 갖는 것 자체는 어느 쪽에도 안 걸린다. 그럼에도 이 설계는 헤딩을 넣지 않는다 —
근거는 §11.

## 2. Goals

- seed 가 사용자 의도와 맞는다. 브리프 §1 의 goal 이자 사용자 원문 S2 가 가리키는 상태다.
- 저자가 리뷰 지적을 혼자 반영하는 경로를 **구조적으로** 닫는다 — 게이트 전 선반영과 게이트 ③ 뒤의
  반영 둘 다(C10).
- 저자의 해석이 사용자에게 **질문으로** 닿는다 — 공시가 아니라(C11).
- 문서 리뷰 재설계의 마지막 자리(seed)를 공유 엔진으로 옮긴다(C13 · 재설계 계획서 PR 5).

## 3. Non-goals

- 리뷰어의 탐지 역할 제거 — 브리프 ST1 에서 기각. PR 5 가 `seed-critic` 파일을 엔진 탐지기로
  바꾸는 것은 이와 부딪치지 않는다.
- 묶음 질문을 한 번에 하나로 바꾸는 것 · 매 문장 확인 — ST1 에서 기각(C7).
- Phase 0 과 Phase 1 병합 · Phase 0 을 짧은 요청 정리로 경량화 — C6.
- 압축해서 새 세션으로 넘기는 인계 구조 변경 — C4.
- Phase 0 에 웹 조사·원인 분석을 더하는 것 — C6.
- 번호 답 형식을 바꾸는 것 — 사용자가 «번호 답도 괜찮다»로 거부(C4).
- 재리뷰 상한을 이 자리에서 정하는 것 — 상한의 정본은 공유 엔진의 한 줄이다(§4 C-E).
- **사용자 편집 단계를 되살리는 것** — C7 이 확정했으나 사용자가 재결정으로 뺐다(§결정 기록 D3).

## 4. Constraints

브리프 §2 의 확정 항목에서 이 설계를 직접 구속하는 것들. 괄호 안이 브리프의 id 다.

- **C-A** 사용자 앞 처분은 9/5 식 게이트 공시와 달라야 한다 — 9/5 오독은 공시된 뒤 사용자가
  승인한 경로로 샜다(C9).
- **C-B** 초안 뒤 검증·게이트는 사용자가 과하다고 고른 자리다 — 사용자 처분이 그 자리의 부담을
  늘리는지를 설계가 따진다(C12).
- **C-C** 탐지기가 `drop` 으로 매기거나 재비판자가 `reject` 한 지적은 **개수 공시로 충분하다**.
  사용자 앞 처분은 그 항목까지 덮지 않는다(C15 — 사용자가 에이전트 추천과 반대로 고른 결정).
- **C-D** Phase 0 은 맡길 일을 사용자 말로 확정하는 자리다. 조사·반론·원인 후보는 Phase 1 의
  몫이다(C6).
- **C-E** 재리뷰 상한의 정본은 `shared/docreview/references/reviewing-document.md` 의
  `` `rereview_cap: N` `` 한 줄이다. 이 자리는 그 숫자를 **다시 적지 않는다**(사용자 지시,
  §결정 기록 D2).

## 5. Architecture

### 5.1 한 사이클의 흐름

굵은 것이 이 설계가 더하거나 바꾸는 자리다.

```
진입(워크트리 질문)
  └─ 확산 라운드 N회 — 라운드마다: 지금 이해 / 아직 안 잡힌 것 / 질문
        └─ **확인 질문 1개**(변경 A) — 이 라운드의 풀이를 원문과 나란히
  └─ 압축(긴 초안 → 깎기) → seed 작성 → check_seed.py
  └─ **엔진 리뷰 라운드**(변경 C) — 상한은 엔진 정본
        1 스냅샷·begin-round   2 kill switch   3 탐지(doc-critic)
        4 codex               5 익명화        6 재비판(doc-recritic)
        7 얼림 검사·라우팅 — **모든 fix 가 decide 로 승격**(변경 B)
        8 라운드 게이트 — 항목별 처분 + **저자 편집 diff 공시**(변경 D)
  └─ 냉독(seed-readback) — 엔진 밖 advisory
  └─ proceed 게이트(현행 4옵션, 변경 없음)
        └─ ①/② → /interview @<seed 경로> → Phase 1(**출처 규약 변경 E**)
```

### 5.2 변경 A — 형성 라운드의 확인 질문

**없애는 것**: 매 라운드 네 블록 중 «원문과 다른 점»(`SKILL.md:166-167`). 이것은 저자가 인지한
이탈만 싣는 자기보고라, 저자가 옳다고 믿은 오독은 구조적으로 오를 수 없다(C11). 9/5 에 실제로
오독이 이 블록에 올라 사용자에게 보였으나 응답 없이 지나갔다.

**대신 두는 것**: 그 라운드에 저자가 사용자 말을 풀어 쓴 문장을 **원문과 나란히** 놓은
`AskUserQuestion` **하나**. 형식:

```
질문: 이 중 제 뜻과 다른 것을 고르세요 (없으면 아무것도 고르지 마세요)   [multiSelect]
  □ 원문 「<사용자가 실제로 한 말>」 → 제 풀이 「<저자 문장>」
  □ 원문 「…」                      → 제 풀이 「…」
```

- 고르지 **않은** 문장에만 seed 에서 «(사용자 확인)» 이 붙는다. 고른 문장은 그 라운드의 다음
  질문 재료가 된다.
- 문장마다 질문을 만들지 않는다 — 그것이 곧 승인 피로이고 C-B 를 정면으로 어긴다. 한 라운드의
  풀이 수는 그 라운드의 답 수에 묶여 자연히 작다.
- 이 질문은 그 라운드의 본 질문과 **같은 `AskUserQuestion` 호출**에 실을 수 있다(묶음 질문
  유지, C7). 도구 상한은 호출당 4개다.

**남는 한계**: «내가 풀어 썼는가»의 판정은 여전히 저자가 한다. 저자가 풀어 쓴 줄 모르는 문장은
이 목록에 오르지 않는다. 그 잔여를 잡는 것은 리뷰 층 1 의 `inference_as_decision` 축이다 —
자기보고와 외부 탐지가 **다른 실패를 막는다**는 것이 이 배치의 요점이고, 하나로 다른 하나를
대신할 수 있다고 주장하지 않는다.

### 5.3 변경 B — seed 프로필 `immutable`

`plugins/spec-distill/references/docreview-profiles/seed.md` 의 `immutable: []` 를 `["*"]` 로
바꾼다. 그것이 변경의 전부다.

**왜 이것이 저자 단독 반영을 닫나** — 라우터(`docreview_route.py` 의 `_classify_items`)에
「앵커가 불변 부류이고 처분이 `fix` 면 `decide` 로 승격」 규칙이 있다. 승격은 **같은 라운드**에
일어나고 `origin: auto` · `promotion: immutable` 로 기록된다. 그래서 저자가 혼자 적용할 수 있는
처분이 하나도 남지 않는다.

**실측(2026-09-16, 설치본 3.1.0 스크립트)** — 산문으로 단정하지 않고 실제 seed 와 같은 모양
(헤딩 0)의 문서로 돌렸다:

```
headingless=True  anchors=['#__doc__']
anchors_matching(['*'])        -> ['#__doc__']
classify_anchor immutable:[*]  -> {immutable: True,  fix_allowed: True}
classify_anchor immutable:[]   -> {immutable: False, fix_allowed: True}
```

`docreview_state.py profile-check` 도 rc 0 으로 통과했다. `"*"` 가 `fix_anchors` 전용 특례가
아니라 `anchors_matching` 의 일반 동작임이 이 실행으로 확정됐다.

**같이 두는 것**: `fix_anchors: ["*"]` 는 그대로 둔다. 채택된 `decide` 의 permit 이 불변 앵커일 때
`fix_anchors` 에서 적용 범위를 뽑으므로(`cmd_decide`), 비우면 채택된 결정조차 적용 범위를 갖지
못한다. `allowed_dispositions` 도 그대로 둔다 — `fix` 를 빼면 §1.2 의 표대로 `ask` 로 떨어진다.

### 5.4 변경 C — 검증 절을 엔진으로 배선

재설계 계획서가 PR 5 로 지정한 작업이다(`docs/superpowers/plans/2026-09-06-document-review-engine.md:4261`).
착수 전임을 확인했다 — `framing-requests/SKILL.md` 에 `docreview` 문자열 0건, 지울 파일 넷 전부 실재.

| | |
|---|---|
| 사라지는 것 | `agents/seed-critic.md` · `scripts/run_seed_codex_reviewer.sh` · `scripts/build_seed_codex_prompt.py` · `scripts/seed-codex-suppression-checklist.md` |
| 남는 것 | `agents/seed-readback.md` · `scripts/build_seed_inline_blob.py` · `scripts/check_seed.py` |
| 진입 껍데기 | `framing-requests` 의 `## 검증` 절이 프로필 경로를 정하고 `references/reviewing-document.md` 를 읽어 따른다 |

**슬롯 배정** — 형제 자리(`reviewing-brief`)와 같은 모양이다:

- 엔진의 `--doc` = **seed 파일**(절대경로). 저자가 고치는 파일이고 스냅샷·얼림 검사의 대상이다.
- 탐지·재비판의 문서 슬롯 = **번들**. `build_seed_inline_blob.py <seed> <audit> CLAUDE.md` 가
  초안 + 사용자 원문(audit `## 1. 원문`) + 레포 `CLAUDE.md` 를 조립한 것이다. 프로필의
  `ground_truth` 가 audit `## 1. 원문` 을 가리키므로 리뷰어가 그 원문을 봐야 한다.
- `--profile` = `references/docreview-profiles/seed.md`.
- 결정 기록 = audit 의 절. **현행 프로필의 `## 8. 리뷰 결정` 을 `## 5. 리뷰 결정` 으로 바꾼다** —
  Phase 0 audit 은 절이 넷(`## 1. 원문` · `## 2. 라운드 기록` · `## 3. 긴 초안` · `## 4. 검증 라운드`)
  이라 8 번은 번호가 비어 보인다. 엔진은 없으면 헤딩부터 만든다(`append_under_heading`).
- 냉독은 엔진 밖 advisory 로 유지한다 — 판정·점수를 내지 않는 측정이라 finding 계약 밖이다.

**상한** — 이 절은 상한 숫자를 적지 않는다(C-E). 대신 `test_rereview_cap_consistency.sh` 의
`TARGETS` 배열에 이 SKILL 을 한 줄 더한다. 그 락이 「이후 PR 이 코퍼스를 넓히는 자리」로
`framing-requests` 를 이름까지 적어 두고 비워 놓았다.

### 5.5 변경 D — 저자 편집 diff 공시

seed 는 헤딩이 없어 엔진이 문서 전체를 섹션 하나로 보고(`docreview_anchor.py:71-74`) 얼림 diff 가
모든 변경을 면제로 보낸다(`docreview_state.py:284` · `:294-296`). 이것은 결함이 아니라 계약이다 —
계획서 T44 가 「헤딩 0 → 얼림·보호 비활성. 「앵커 불가」 advisory. **차단은 호스트 구조 게이트의
일**」이라고 책임을 호스트로 명시적으로 넘긴다(`…document-review-engine.md:135`).

호스트가 그 자리를 메운다:

1. 라운드를 시작할 때 seed 사본을 세션 디렉토리(`$SEED_DIR`)에 뜬다. 경로는 세션의 순수 함수여야
   한다 — `mktemp` 은 다음 셸이 재발견하지 못한다(`SKILL.md:222-224` 가 같은 이유로 이미 그렇게
   적고 있다).
2. 다음 라운드 게이트 텍스트에 그 사본과 현재 seed 의 diff 를 싣는다. **저자가 고친 것 전부**가
   사용자 눈앞에 온다.
3. diff 가 비면 「저자 편집 없음」을 한 줄로 명시한다 — 침묵과 구분한다.

**정직한 한계**: 판정 주체가 기계가 아니라 사용자의 눈이다. 엔진의 자동 `decide` 처럼 진행을
막지 않는다. 막는 힘은 변경 B 가 대고, 이 장치는 **보이게 하는** 일만 한다.

### 5.6 변경 E — Phase 1 출처 규약

현행 `conducting-interview/references/seed-input.md:13-15` 는 seed 전문을 사용자 **출처**로
규정한다. 그러면 저자가 쓴 «다시 검증할 것 —» 문단의 문장까지 출처 라벨이 사용자가 된다
(브리프 OQ5 · 위험 H2).

**좁힌다** — «(사용자 확인)» 이 붙은 문장만 사용자 출처다. 그 밖의 문장은 Phase 0 저자의 것이고,
brief §2 의 `user_sourced_items` 로 승격되지 않는다(모델 추론은 본문에 ✎ 프로즈로 쓴다는 현행
규약이 그대로 적용된다).

**바꾸지 않는 것**: `S1` 은 그대로 seed 전문이다. `check_verbatim_coverage.py` 가 payload §6 의
앵커 집합을 `{S1}` 로 못 박고 그 텍스트를 state 와 대조하므로, `S1` 의 내용을 좁히면 그 게이트가
red 가 된다. 출처(provenance)와 원문 보존(verbatim)은 다른 축이고, 이 변경은 앞의 것만 건드린다.

## 6. 데이터 흐름 — 무엇이 어디서 나와 어디로 가나

| 산출 | 생산자 | 소비자 |
|---|---|---|
| 사용자 원문 | 확산 1번 | audit `## 1. 원문` → 번들 → 탐지·재비판·codex |
| 라운드 풀이 확인 결과 | 변경 A 의 질문 | seed 의 «(사용자 확인)» 표시 → 변경 E 로 Phase 1 |
| 긴 초안 | 압축 직전 | audit `## 3. 긴 초안` (seed 로 나가지 않는다) |
| seed | 압축 직후 | 엔진 `--doc` · 번들의 초안 부분 · 냉독 · 다음 세션 |
| 번들 | `build_seed_inline_blob.py` | 탐지 리뷰어 · 재비판자 · codex 러너 |
| finding + 처분 | 엔진 7단계 | 라운드 게이트 → **사용자** |
| 사용자 결정 + 문구 | 라운드 게이트 | audit `## 5. 리뷰 결정` · 다음 라운드 permit |
| 저자 편집 diff | 변경 D | 라운드 게이트 텍스트 → 사용자 |
| 냉독 산문 | `seed-readback` | proceed 게이트 텍스트 → 사용자 |
| degrade record | 엔진 + 호스트 | proceed 게이트 텍스트 → 사용자 |

소비자 없는 산출물과 생산자 없는 소비자는 없다. 냉독만 판정 경로 밖이고, 그것이 의도다 —
싱크됐는지는 사용자가 읽고 판정한다.

## 7. 위험

| | 위험 | 완화 | 잔여 |
|---|---|---|---|
| R1 | 전부 `decide` 로 승격돼 지적이 많으면 질문이 많다(처분 피로 · 브리프 OQ3 · 위험 H5·F3) | 변경 A 가 형성 중에 `inference_as_decision`·`premature_closure` 를 미리 잡아 압축 뒤 지적 수를 줄인다. seed 프로필은 층 1 네 범주뿐이고 층 2 가 없다 | **완화가 가설이다.** 측정된 바 없다. §12 OQ-A |
| R2 | 엔진이 `--quote` 를 **요구만 하고 그것이 사용자 말인지 검증하지 못한다** | 없음 | C3 의 누수가 처분 단계에서 재현될 수 있다. 규율 의존이고, 규율은 9/5 에 실패한 수단이다 |
| R3 | 사용자가 seed 본문을 직접 만지는 자리가 **하나도 없다** — 모든 단어를 저자가 쓴다 | 변경 A 의 라운드 확인과 처분 게이트가 교정 경로다 | Goal 에 직접 걸린다. D3 재결정의 대가이고, 되돌리려면 §2.4 3번을 살린다 |
| R4 | 확인 질문이 늘면 저자 문장에 도장을 찍는 경로가 커진다(확인 표시 세탁 · 위험 H1) | 원문을 나란히 싣는다. 문장마다 질문하지 않는다 | 9/5 사례에서는 반증됐으나(C5) 확인 턴이 늘면 다시 열린다 |
| R5 | 같은 세션에서 만든 게이트의 «맞다» 감각이 부풀려진다(위험 H4·F6) | 없음 — 불일치는 하류에서만 관측된다(C8) | §12 OQ-B |
| R6 | `test_readme_sync.sh` 가 **선재 RED**(추출기 고장, 스스로 「아래 판정은 증거가 아니다」라고 낸다)라 이 작업의 README 편집을 검증해 주지 못한다 | plan 이 README 편집을 눈으로 대조하거나 그 락을 먼저 고친다 | 락을 고치는 것은 이 설계의 범위 밖 |

## 8. Acceptance Criteria

- **AC1** `framing-requests/SKILL.md` 의 확산 절에 «원문과 다른 점» 블록이 없고, 그 자리에 원문과
  저자 풀이를 나란히 싣는 `AskUserQuestion` 하나가 있다.
- **AC2** seed 프로필의 `immutable` 이 `["*"]` 이고 `docreview_state.py profile-check` 가 rc 0 이다.
- **AC3** 헤딩 없는 문서에서 `fix` 처분 finding 이 같은 라운드에 `decide` 로 승격되는 것이 픽스처로
  관측된다(`origin: auto` · `promotion: immutable`).
- **AC4** `framing-requests/SKILL.md` 에 `seed-critic` · `run_seed_codex_reviewer.sh` 참조가 0건이고,
  삭제 대상 넷이 리포에서 사라졌으며, 그 넷을 가리키던 락이 함께 갱신됐다.
- **AC5** `framing-requests/SKILL.md` 가 재리뷰 상한 숫자를 **적지 않는다**. `test_rereview_cap_consistency.sh`
  의 `TARGETS` 에 이 파일이 들어 있고 락이 GREEN 이다.
- **AC6** 라운드 게이트 텍스트에 저자 편집 diff(또는 「저자 편집 없음」)가 실린다.
- **AC7** `seed-input.md` 가 «(사용자 확인)» 붙은 문장만 사용자 출처로 규정하고, `S1` 규약은
  바뀌지 않았으며 `check_verbatim_coverage.py` 가 red 를 내지 않는다.
- **AC8** seed 프로필의 `decision_log` 헤딩이 Phase 0 audit 의 실제 절 번호와 이어진다.
- **AC9** `plugin.json` 3.2.0 · CHANGELOG `## [3.2.0]` · README 「Principles Instantiated」 갱신이
  같은 커밋에 있다.
- **AC10** baseline 대비 새 RED 0. 선재 RED 둘(`test_no_write_matcher_hooks_repo.sh` fails=1 ·
  `test_readme_sync.sh` fails=1)은 **실패 줄 수까지** 같아야 한다 — rc 만으로는 이미 RED 인 파일
  안의 새 실패가 안 보인다.

## 9. Files to Modify

| 파일 | 무엇 |
|---|---|
| `plugins/spec-distill/skills/framing-requests/SKILL.md` | 확산 블록(변경 A) · 검증 절 전체 배선(변경 C) · diff 공시(변경 D) · 상한 언급 제거 |
| `plugins/spec-distill/references/docreview-profiles/seed.md` | `immutable: ["*"]` · `decision_log` 헤딩 |
| `plugins/spec-distill/skills/conducting-interview/references/seed-input.md` | 출처 규약(변경 E) |
| `plugins/spec-distill/tests/test_rereview_cap_consistency.sh` | `TARGETS` 에 한 줄 |
| `plugins/spec-distill/tests/test_seed_gate_wiring.sh` | **재작성** — 지워지는 러너의 게이트 블록을 재던 락이다 |
| `plugins/spec-distill/tests/test_seed_inline_blob.sh` | 소비자가 바뀐다(critic → 엔진 문서 슬롯) |
| `shared/tests/test_docreview_profiles.sh` | seed 의 `immutable` 에 대한 단언 추가(오늘은 없다) |
| `plugins/spec-distill/.claude-plugin/plugin.json` | 3.1.0 → 3.2.0 |
| `plugins/spec-distill/CHANGELOG.md` · `README.md` | minor 항목 · Principles |
| 삭제 | `agents/seed-critic.md` · `scripts/run_seed_codex_reviewer.sh` · `scripts/build_seed_codex_prompt.py` · `scripts/seed-codex-suppression-checklist.md` |

전수는 plan 이 도출한다 — 식별자 · 개념 별칭 · 의존 폐포 · 배포 링크 네 축으로. 이 표는 씨앗이다.

## 10. Verification Plan

**무엇이 관측되면 통과인가.** 명령·픽스처·순서는 plan 의 일이다.

1. **프로필 변경이 실제로 처분을 바꾸는가** — 헤딩 없는 픽스처 문서에 `fix` finding 하나를 넣고
   라우팅을 돌려, 승격 전(`immutable: []`)에는 `fix` 로 남고 승격 후(`["*"]`)에는 `decide` 가 되는
   것을 **양쪽 다** 관측한다. 한쪽만 재면 「전부 decide 로 떨어지는 고장」과 구별되지 않는다.
2. **배선이 실제로 도는가** — 형제 자리(`test_seed_gate_wiring.sh`)처럼 블록을 잘라내 stub 위에서
   돌리고, 엔진이 받은 인자 넷과 산출물의 생사를 본다.
3. **상한 락** — `TARGETS` 에 넣은 뒤, 이 SKILL 에 상한 숫자를 하나 심는 변이가 RED 를 내는지
   확인한다(음의 짝). 통과만으로는 이빨을 판별할 수 없다.
4. **출처 규약** — «(사용자 확인)» 없는 문장이 `user_sourced_items` 로 올라가는 픽스처가
   잡히는지. 그리고 `S1` 을 건드리지 않았음을 `check_verbatim_coverage.py` rc 0 으로 확인한다.
5. **회귀** — §8 AC10 대로 실패 **줄 수**까지 대조한다.

## 11. Rejected Alternatives

- **허용 처분에서 `fix` 빼기** — §1.2 의 표. `ask` 로 강제되고 그 `ask` 는 승인도 라운드 게이트도
  막지 못하며 사용자 답을 기록하지 않는다. 아무것도 안 하는 것보다 나쁘다.
- **seed 에 제목 헤딩 하나 주기** — 검사기에는 안 걸린다(§1.2). 그래도 버린다: 채택된 결정이 있는
  라운드는 permit 이 문서 전체 앵커를 덮으므로 그 라운드의 무단 편집이 함께 통과한다. 정밀도가
  낮은 데다 seed 가 「라벨 없는 산문」에서 한 줄 벗어나는 대가를 치른다. 같은 목적을 변경 D 가 더
  높은 정밀도로 달성한다.
- **엔진의 헤딩 없는 문서 면제를 고치기** — 자리 넷이 공유하는 엔진을 건드려 범위를 벗어나고,
  계획서 T44 가 이 책임을 이미 호스트로 넘겨 뒀다.
- **처분을 확정 게이트에 합치기** — 불가능하다. 열린 `decide` 가 하나라도 있으면 승인 게이트가
  열리지 않으므로(`approval_ready`) 두 게이트를 한 자리로 합칠 방법이 없다.
- **리뷰를 1라운드로 고정** — 상한은 공유 엔진의 정본이라 자리별로 낮출 수 없다(C-E). 규율로
  1회만 돌겠다는 뜻이 되고, 규율은 이 문제에서 이미 실패한 수단이다. 그리고 저자의 수정이 만든
  새 결함을 잡을 자리가 사라진다.
- **리뷰를 압축 전으로 옮기기** — 억제 검사는 「압축이 무엇을 떨어뜨렸나」를 보는 뺄셈인데, 아직
  깎지 않은 초안에는 그 대상이 없다.

## 12. Open Questions

이 설계가 닫지 않은 것. 유추하지 않는다.

- **OQ-A** 변경 A 가 압축 뒤 지적 수를 실제로 줄이는가(R1 완화의 전제). 값싼 신호 하나만 둔다 —
  엔진 회계의 `inference_as_decision` finding 수. 임계값은 정하지 않는다.
- **OQ-B** 개선을 무엇으로 재나(브리프 OQ1). 불일치는 하류로 넘어간 뒤에야 보였다(C8). 하류가
  seed 의 어느 문장을 달리 읽었는지 되돌려 받는 자리가 필요한지, 필요하면 어떤 모양인지.
- **OQ-C** 추론이 «Phase 0 관찰» 같은 머리말을 달고 seed 에 남는 통로(브리프 OQ6). 9/5 에 그
  머리말은 저자가 먼저 썼고 리뷰어가 접두를 제안했다 — 양쪽이 대상이다. 변경 A 가 그 문장들을
  확인 목록에 올리므로 부분적으로 닿지만, 통로 자체를 닫지는 않는다.
- **OQ-D** 처분이 많은 라운드에서 결정을 어떤 단위로 묶을 것인가. 엔진이 「결정 단위로 묶은
  decide」를 렌더하지만 그 묶음의 기준은 plan 이 관측해 정한다.

## 결정 기록

이 설계 세션에서 사용자가 답한 것과 설계가 혼자 닫은 것. 뒤집힘은 *원래 / 재결정 / 근거* 세 칸이다.

| id | 결정 | 출처 |
|---|---|---|
| D1 | 사용자 확인의 부담을 **형성 중으로** 옮긴다 — 라운드마다 풀이를 확인받고, 초안 뒤에는 리뷰 지적 처분만 남긴다 | 사용자, 2026-09-16 게이트 |
| D2 | 리뷰 라운드 횟수는 **공유 엔진이 이미 갖고 있는 값**을 쓴다. 이 자리에서 정하지 않는다 | 사용자, 2026-09-16 — 「이러한 횟수의 경우 리뷰관련 공용에서 횟수가 있을걸」 |
| D3 | **사용자 편집 단계를 두지 않는다** | 사용자, 2026-09-16 게이트 |
| D4 | 저자의 무단 편집은 **호스트 diff 공시**로 잡는다. seed 는 헤딩 없는 산문으로 남는다 | 사용자, 2026-09-16 게이트 |
| D5 | Phase 1 의 seed 출처 규약(브리프 OQ5)을 **이번 범위에 넣는다** | 사용자, 2026-09-16 게이트 |
| D6 | 리뷰는 압축 뒤에 두고 엔진 기본 흐름을 따른다(접근 1) | 사용자, 2026-09-16 게이트 |
| D7 | 차단 수단은 `immutable: ["*"]` 로 한다 | 설계 — §5.3 실측 |
| D8 | seed 프로필의 `decision_log` 헤딩을 Phase 0 audit 의 절 번호에 맞춘다 | 설계 — §5.4 |

**D3 의 뒤집힘**

| | |
|---|---|
| 원래 | 브리프 C7 — 「빠졌던 사용자 편집 단계를 되살린다」(ST1 게이트에서 «보완»을 고르며 함께 확정, 근거 S12) |
| 재결정 | 사용자 편집 단계를 두지 않는다 |
| 근거 | 사용자가 2026-09-16 게이트에서 직접 골랐다. 선행 답 D1(확인 부담을 형성 중으로)이 이 단계의 기능을 라운드 쪽으로 옮긴다는 점과, 이것이 C7 의 다섯 항목 중 하나를 빼는 재결정이라는 점을 선택지 텍스트에 밝힌 상태였다. 대가는 §7 R3 에 이름을 붙여 뒀다 |

**브리프의 ✎ 배경 메모 정정 둘** — 확정 항목이 아니라 모델 추론으로 표시된 배경이라 재결정
대상은 아니지만, 이 설계가 그 서술과 다르게 판단했으므로 기록한다. (1) 「`fix` 를 빼면 `ask` 로
떨어진다」는 맞으나 그 `ask` 가 승인도 라운드 게이트도 막지 않고 사용자 답을 기록하지 않는다는
점이 빠져 있었다(§1.2). (2) 「seed 에 헤딩을 주면 슬롯 존재 검사 금지 계약과 부딪친다」는
부정확하다 — 그 금지는 검사기에 검사를 더하는 것에 대한 것이다(§1.2).

## Handoff Context

**TL;DR** — Phase 0 의 누수는 「검증과 게이트 사이에 항목별 처분이 없다」는 구조에서 나오고
현행 3.1.0 에서 재현된다(§1.1). 고치는 수단은 넷이다: 확산 라운드의 자기보고 블록을 질문으로
바꾸고(A), seed 프로필 `immutable: ["*"]` 로 모든 지적을 `decide` 로 올려 저자 단독 반영 경로를
닫고(B), 검증 절을 공유 엔진으로 배선하며(C, = 재설계 PR 5), 엔진이 손대지 않는 헤딩 없는
문서의 얼림 자리는 호스트 diff 공시로 메운다(D). Phase 1 의 seed 출처 규약도 함께 좁힌다(E).
spec-distill 3.1.0 → 3.2.0 minor.

**Implicit context** — 이 문서 밖에 있으면 안 되는 것.

1. **엔진에서 승인을 막고 사용자 문구를 남기는 처분은 `decide` 하나뿐이다.** 이 한 문장이
   설계 전체의 축이고, 근거 표가 §1.2 에 있다. 이것을 모르면 「`fix` 를 빼면 되지 않나」로
   되돌아간다 — 그 길은 §11 에서 기각됐다.
2. **`immutable: ["*"]` 는 실측으로 확정했다**(2026-09-16, 설치본 3.1.0 스크립트). 프로필
   검증기 통과만으로는 부족하다 — 그것은 「문자열 목록인가」만 본다. `anchors_matching` 이
   헤딩 없는 문서의 `#__doc__` 를 실제로 잡는지를 돌려서 확인했다.
3. **재리뷰 상한을 이 자리에 적으면 안 된다**(사용자 지시 D2). 정본은
   `shared/docreview/references/reviewing-document.md` 의 한 줄이고, `test_rereview_cap_consistency.sh`
   가 ∀ 로 잰다 — 숫자를 다시 적으면 그 락이 정본 밖 두 번째 출처로 잡아 RED 를 낸다.
4. **작업 전 baseline(2026-09-16, `feature/framing-intent-drift` 브랜치, base `add4c9cd`)** —
   bash 89 파일 중 2 RED, python 157 tests OK(skipped 1). 선재 RED 둘은 **둘 다 양성 대조
   실패**이지 제품 회귀가 아니다: `test_no_write_matcher_hooks_repo.sh`(fails=1, 「Bash matcher
   훅이 1개뿐」 — 대조군이 부족해 스캔이 살아 있음을 증명 못 한다) · `test_readme_sync.sh`
   (fails=1, 「추출기가 고장났다 — 아래 판정은 증거가 아니다」). 뒤엣것 때문에 **이 작업의
   README 편집은 그 락이 검증해 주지 않는다**(§7 R6).
5. **브리프의 §7 Next Action 은 낡았다** — 「설계 대상은 framing-requests SKILL」이라고 적혀
   있으나 그것은 C13(PR 5 위에서 설계) 이전의 서술이다. 브리프 §0 이 그 사실을 적고 있다.
6. 브리프와 audit 은 이 브랜치에 함께 커밋됐다. 이 설계의 층 1 정답 출처가 그 §2 확정 항목이다.
7. 같은 리포에 다른 워크트리 하나가 돌고 있다(`fix/plugin-root-cwd-fallback`, `.claude/worktrees/`
   아래). 버전 번호는 머지 직전에 정한다 — 먼저 머지되는 쪽이 이긴다.

### Deferred to plan

| 출처 | 항목 |
|---|---|
| §9 | 삭제 전수 — 식별자 · 개념 별칭 · 의존 폐포 · 배포 링크 네 축으로 도출 |
| §10 | 검증 **절차**(명령 · 픽스처 · 순서) 전부 |
| §5.4 | 진입 껍데기의 정확한 bash 펜스 모양(경로 도출 · 가드 · degrade record 호출) |
| §5.5 | diff 를 만드는 수단과 게이트 텍스트에서의 분량 상한 |
| §12 OQ-D | 결정 묶음 단위 — 엔진 렌더를 관측해 정한다 |
| §7 R6 | README 편집을 무엇으로 대조할지(선재 RED 인 락을 고칠지, 눈 대조로 갈지) |
