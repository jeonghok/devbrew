---
name: request-framing
type: design
created_at: 2026-08-23
source_brief: docs/superpowers/interview/2026-08-22-request-framing-phase0-interview.md
status: draft
---

# request-framing — 설계

> 첫 턴이 그 세션 전체를 결정한다. 그러니 첫 턴에 들어갈 말을 사용자와 함께 미리 만든다.

파이프라인 맨 앞에 **회의** 단계를 세우고, 그 회의의 결과를 새 세션의 첫 턴 메시지 하나로
압축해 넘긴다. 압축 규약은 공유 계약으로 두되 이번에는 **seed 에만 집행**하고, 앞 단계의
확정이 뒤 단계를 영구히 닫지 않게 하는 원칙(P23)을 devbrew 전체에 신설한다.

## 목차

- [1. 무엇을 만드는가](#1-무엇을-만드는가) — [1.1 정체](#11-정체) · [1.2 왜](#12-왜) · [1.3 두 산출물](#13-두-산출물)
- [2. 어떻게 도는가 — 확산 후 압축](#2-어떻게-도는가--확산-후-압축) — [2.1 전체 그림](#21-전체-그림) · [2.2 확산](#22-확산) · [2.3 압축](#23-압축) · [2.4 검증과 확정](#24-검증과-확정) · [2.5 상한을 두지 않는다](#25-상한을-두지-않는다)
- [3. 두 단계의 R&R](#3-두-단계의-rr) — [3.1 검토한 대안](#31-검토한-대안--새-단계-대신-기존-단계-확장)
- [4. 압축 규약](#4-압축-규약)
- [5. 산출물](#5-산출물) — [5.1 interview-seed](#51-interview-seed) · [5.2 brief 는 이번에 바꾸지 않는다](#52-brief-는-이번에-바꾸지-않는다)
- [6. P23 — Decisions Stay Refutable](#6-p23--decisions-stay-refutable)
- [7. 컴포넌트](#7-컴포넌트)
- [8. 검증](#8-검증)
- [9. PR 분해](#9-pr-분해)
- [10. 재결정 기록](#10-재결정-기록)
- [11. 남은 것](#11-남은-것)
- [Handoff Context](#handoff-context)

---

## 1. 무엇을 만드는가

### 1.1 정체

파이프라인 맨 앞의 **회의**다. 사용자와 에이전트가 **의도 · steering · 방향 · goal** 을 싱크한
뒤, 그것을 새 세션의 첫 턴 메시지 하나로 **압축**한다.

사용자-facing 단계명은 `request-framing`, 산출물명은 `interview-seed`. `meta-prompting` 은
내부 메커니즘 명칭으로만 쓴다.

### 1.2 왜

**첫 턴이 그 세션 전체를 결정한다.** 에이전트는 첫 턴에서 가정을 세우고 거기 매인다 — Laban
et al. 의 다중턴 실측이 잰 것이 그것이다(정보를 여러 턴에 나눠 주면 평균 39% 저하, 그리고 그
저하는 능력 손실보다 **신뢰성 저하**가 주도한다 — 이른 턴의 가정에 매여 회복하지 못하는 것).
devbrew 파이프라인은 interview → brainstorming → writing-plans → 구현으로 며칠이 가고, 넷이
어긋나면 각 단계가 그 어긋남을 **증폭**시킨다.

새 세션은 목적이 아니라 그 첫 턴이 **진짜 첫 턴이 되게 하는 수단**이다 — 컨텍스트가 비어
있어야 그 메시지가 세션의 전부가 된다.

이 증폭은 이 설계를 만드는 대화에서 실제로 관측됐다. 넷이 안 맞은 채 열 몇 턴을 썼고, 매 턴
저자는 실행 세부를 썼고 사용자는 그게 아니라고 답했다. §10 이 그 기록이다.

### 1.3 두 산출물

`interview-seed` 만이 아니다. 질문이 한꺼번에 쏟아질 때 **사용자가 자기 입력이 얼마나
빈약했는지 체감하는 것** 자체가 산출물이다 — 그것이 다음번 첫 턴을 좋게 만든다.

---

## 2. 어떻게 도는가 — 확산 후 압축

### 2.1 전체 그림

```
        <---------- 확 산 ---------->  |  <------ 압 축 ------>
                                        |
 덤핑 -> 질문 쏟아내기 -> 답 -> 새 질문 -> | 깎기 -> 비평 -> 냉독 -> 확정
  원문      상한 없음    부분답  상한 없음 | 불변량만 몰래  사용자가  사용자
  그대로                 "알아서"         |  남긴다 들어온것  판정     서명
   |                        |             |    |      |       |        |
   +------------------------+-------------+----+------+-------+        |
                      audit <-- 전량 보존 --                            |
                                                              payload <-+
                                                                   |
                                                          새 세션 첫 턴
```

### 2.2 확산

1. **원문 보존** — 첫 질문보다 **먼저** audit 을 만들고 원문 절에 그대로 넣는다. 판단·요약
   전이다. append-only. 회의록·대화 로그를 받았으면 그대로 붙여 넣는다.
2. **레포 읽기** — `CLAUDE.md`·`AGENTS.md` 를 읽는다. 채우려고가 아니라 **seed 에 쓰면 안 될
   것을 알기 위해서**다. **웹은 보지 않는다** — 바깥에서 찾는 것은 interview 의 R&R 이고,
   framing 의 공백은 사용자에게 물어서 메운다(§3).
3. **질문을 한꺼번에 쏟아낸다** — 하나씩 묻지 않는다. 한꺼번에 보여야 사용자가 자기 입력의
   빈약함을 본다. 최소 커버는 C20 의 아홉(목표 · 대상 사용자와 소비자 · 입력 자료 · 실행 환경 ·
   권한과 승인 경계 · 제약 · non-goal · 성공 증거 · 중지와 handoff 조건)이되, 아홉을 채우는
   것이 목적이 아니라 **넷을 끌어내는** 것이 목적이다.
4. **부분 답을 받는다** — 사용자는 답하고 싶은 것만 답하고 나머지는 위임한다. 전부 위임하면
   이 단계가 의미를 잃으므로, 그때는 그 사실을 말한다.
5. **답이 새 질문을 열면 또 쏟아낸다** — 라운드 수에 상한이 없다.

매 라운드 출력은 네 블록이다.

- **지금 이해한 작업** — 한두 문장
- **원문과 다른 점** — 내 이해가 사용자 말에서 벗어난 지점. 억제 리뷰를 끝이 아니라 **상시**로
  노출하는 자리다
- **아직 안 잡힌 것** — 넷 중 무엇이 아직 전달되지 않았나
- **질문** — 이번에 쏟아내는 것

### 2.3 압축

긴 초안을 **먼저** 쓰고 **그 다음** 깎는다. 처음부터 짧게 쓰지 않는다 — 크게 그린 다음
깎아낸 것이 처음부터 짧게 쓴 것보다 더 많은 것을 고려한다.

긴 초안은 세션 state 에만 산다. `docs/` 에 나가는 것은 깎은 것뿐이다.

깎기의 잣대는 §4 의 규약이다.

### 2.4 검증과 확정

1. **억제 리뷰** — `seed-critic`(`tools: []`) 에 초안 + 원문 + 레포 `CLAUDE.md` 를 전문 inline
   으로 준다. 네 축만 본다: 근거 없이 추가된 제약 / 예시를 필수로 오인 / 선택지를 조기에 닫는
   표현 / 사용자 결정처럼 표현된 에이전트 추론. **뺄셈 검사**이고 "좋은 프롬프트냐" 는 묻지
   않는다 — 그건 취향이고 비평자에게는 사용자의 도메인 지식이 없다.
2. **냉독** — `seed-readback`(`tools: []`) 에 **seed 만** 준다. 원문도 대화도 주지 않는다.
   "내가 이해한 것은 이것이다" 를 산문으로 말하게 하고, **싱크됐는지는 사용자가 읽고
   판정한다.** 에이전트가 통과·미달을 내면 어긋남의 감각이 사용자에게 오지 않는다.
3. **사용자 편집** — 사용자가 본문을 직접 고친다. 자기 도메인 지식으로 바꿔야 할 곳이
   반드시 있다.
4. **확정** — `references/proceed-gate.md` 의 4옵션 게이트. 게이트 질문 텍스트에 degrade 를
   하나도 빠뜨리지 않고 싣는다. **승인 이후에만** seed 파일이 `docs/` 에 쓰인다.

### 2.5 상한을 두지 않는다

질문에도 라운드에도 분량에도 상한이 없다. `probe_budget.py` 를 삭제하고 `conducting-interview`
의 base cap 12 도 함께 없앤다.

금지 패턴 *Unbounded autonomy* 와 충돌하지 않는다 — **단 그 방어는 사용자-응답 루프에만
적용된다.** 질문 루프는 매 반복마다 사용자가 답해야 돌고 사용자가 그 루프의 시계다. 자율이
없으므로 묶을 자율도 없다.

#### agent-only 루프는 그 방어 밖이고, 바운드를 유지한다

`conducting-interview` 의 coverage-mapper 재dispatch 가 그것이다 — 사용자 답 없이 도는데 지금
바운드가 하필 `probe_count` 단위(`probe_count - coverage_mapper_last_probe >= 3`)로 쓰여 있어
카운터를 지우면 함께 사라진다.

**단위를 이식하되 상태는 디스크에 남긴다.** 원래 바운드는 *두 디스크 값의 비교*라 어느 턴에서든
무상태로 재계산됐다. 그 성질을 잃으면 판정이 모델의 턴-간 기억에 의존하고, 같은 SKILL 이 백스톱에
대해 금지한 *프로즈 self-tracking* 이 된다.

**저장하는 것은 streak 값이 아니라 정체 에피소드의 정체성이다.** 값을 저장하면 fail-open 이
된다 — streak 3 에서 dispatch(저장 3) → streak 4 → `3 != 4` → 재dispatch → streak 5 → 재dispatch
… 로, 현행 바운드가 명시적으로 막는 *레벨-트리거 무한 재dispatch* 가 그대로 살아난다. 따라서
`orchestration` 에 필드 **둘**을 둔다:

```yaml
orchestration:
  stall_episode: 0                       # streak 이 0 으로 reset 될 때마다 +1. 정체 구간의 id
  coverage_mapper_dispatched_episode: null   # 마지막 dispatch 가 일어난 에피소드 id
```

재dispatch 조건은 `no_progress_streak >= 3 AND coverage_mapper_dispatched_episode != stall_episode`
다. 판정은 여전히 **디스크 두 값의 비교**이고, 한 정체 구간당 정확히 1회다.

**"새 카운터 0" 은 목표가 아니라 제약이었고, 그 제약이 바운드를 무상태 검증 불가로 만들면
제약이 틀린 것이다.** 상한(cap)을 없애는 것과 바운드를 없애는 것은 다르다 — 없애는 것은
사용자 질문의 상한이지 agent-only 루프의 바운드가 아니다.

**dispatch 조건 2 도 함께 다룬다.** 현행 coverage-mapper 는 두 조건으로 발동한다 — (1) 연속
무진전, (2) floor 차원의 첫 `open→in-progress` 전이. 위 필드는 (1)만 덮는다. (2)가 유한한 것은
"전이당 1회" 여서가 아니라 **대상이 floor 다섯 차원으로 고정**이기 때문이다(derived 차원은 그
조건의 대상이 아니다) — 상한이 5 이므로 추가 바운드가 필요 없다. 그 근거를 SKILL 에 한 줄로
명시한다. 지금은 어디에도 없어 "바운드 밖" 인지 "바운드 불필요" 인지 구별되지 않는다.

**(1)의 총량은 여전히 위로 안 묶여 있다.** cap 을 지우면 정체 구간 수의 상한이 사라지고,
coverage-mapper 가 제안한 derived 차원이 원장에 admit 되면 새 focused 대상이 생겨 새 정체
구간을 낳는 되먹임도 있다. 이전에는 `probe_count <= effective_cap` 이 바깥 시계였고 cap 상향이
사용자 승인을 요구했다. **구간당 1회는 밀도 바운드이지 총량 바운드가 아니며, 총량을 묶는 것도
사용자에게 노출하는 것도 이 설계에 없다** — 검토한 대안(에피소드 총 dispatch 상한 · 사용자
게이트 재노출)과 함께 §11 에 미해결로 남긴다.

`blind-spot-prober` 는 이미 인터뷰당 1회라 영향이 없다.

#### 나가는 문이 floor 뒤에 있는 문제

`probe_budget.py` 가 밝힌 원래 실패 모드는 *"floor 가 미충족이면 종료가 막히므로 probe 가
무한히 돈다"* 이고, proceed-gate 4옵션은 floor 5 가 닫힌 **뒤에만** 도달한다. 상한을 지우면서
그 escalation 의 탈출구까지 지우면 안 된다. 카운터는 없애되 탈출구는 남긴다: **사용자는 언제든
종료를 요청할 수 있고, 그때 미충족 floor 는 사용자-승인 박제(evidence 에 그 사실을 적고
payload 의 미해결 항목으로 이월)로 닫힌다.** 발동 조건이 카운터가 아니라 사용자 발화라는 점만
다르다.

#### 삭제 스윕은 도출이다

완결성 oracle:

```bash
grep -rlE 'probe_budget|probe_count|probe_cap|effective_cap|raise-cap|PROBE_CAP|coverage_mapper_last_probe' \
  plugins/spec-distill
```

2026-08-23 실행 결과 비-픽스처 **10건** + 픽스처 **61건**. 비-픽스처: `scripts/probe_budget.py` ·
`tests/test_probe_budget.sh` · `skills/conducting-interview/SKILL.md` ·
`tests/test_conducting_interview_stage.sh` · `templates/interview-audit-template.md` ·
`scripts/brief_review_state.py` · `tests/test_brief_review_state.py` ·
`tests/test_readme_sync.sh` · `README.md` · `CHANGELOG.md`.

**스윕 후 oracle 이 0 이 되지 않는다 — 그 잔존을 락으로 못 박는다.** audit `## 2. Budget` 절을
삭제하지 않으므로 픽스처 안의 문자열이 남는다. 그러면 완료 판정이 *"의도적 잔존"* 과 *"잔존 +
놓친 1"* 을 구별하지 못한다. 완료 조건을 **"oracle 출력에 `tests/fixtures/` 와 `CHANGELOG.md` 밖 경로가 0건"** 이라는
**단측 단언**으로 두고 `test_probe_sweep_residue.sh` 가 그것을 잰다.

**두 제외에는 각각 이유가 있고, 락 본문에 그 이유를 함께 적는다** — 이유 없는 면제 목록은 그
질문을 영구히 닫는다. 픽스처는 `## 2. Budget` 절을 남기기로 한 비용 판단의 결과이고,
`CHANGELOG.md` 는 **지울 수 없는 과거 릴리스 이력**이다. 후자를 빼지 않으면 이 락은 원리적으로
green 이 될 수 없다 — 그리고 **PR1 자신의 `Removed: probe_budget.py` 엔트리가 락을 RED 로
만든다.** 락을 만족시키는 커밋이 락을 깨뜨리는 형태다.

집합 일치가 아니라 단측인 이유: 픽스처 61건 중 `state-probe-at-cap.md` 와 `state-probe-within.md`
둘은 audit 픽스처가 아니라 **삭제 대상 `test_probe_budget.sh` 전용 state 픽스처**라 함께
지워지는 것이 옳다(잔존이 59 가 된다). 집합 일치로 잠그면 그 올바른 정리에 거짓 RED 가 난다.
단측 단언은 판별력이 같고 그 부작용이 없다.

**`## 2. Budget` 절을 남기는 것은 도출이 아니라 비용 판단이다.** 헤더 유지가 본문 유지를
함의하지 않는다 — 헤더만 남기고 본문을 바꿔도 `AUDIT_SECTIONS` 는 만족된다. 픽스처 59건을
현재 문면 그대로 동결하는 쪽을 고른 것은 그 편이 싸기 때문이고, 대가는 **삭제된 개념을 계속
인용하는 픽스처가 락으로 굳는 것**이다. 절 본문의 새 내용은 §7.2 가 정한다.

**이 oracle 이 못 보는 것(알려진 채로 남긴다)** — grep 은 산문 언급을 찾지 구조화된 상수를 못
본다. `check_brief.py` 의 `AUDIT_SECTIONS` 는 절 제목을 튜플 원소로 들고 있어 `## 2. Budget`
패턴에 걸리지 않는다. 위의 "절을 삭제하지 않는다" 결정이 이 사각지대를 무해하게 만든다.

---

## 3. 두 단계의 R&R

> **request-framing 은 사용자가 이미 아는 것을 꺼낸다. conducting-interview 는 사용자도
> 모르는 것을 찾는다.**

답의 소재지가 다르다. framing 의 질문은 답이 사용자 머릿속에만 있고, interview 의 질문은
답이 사용자 밖에 있다.

| | request-framing | conducting-interview |
|---|---|---|
| 책임 | 사용자의 의도를 정확히 옮긴다. 안 말한 것을 꺼낸다. 모델 추론이 사용자 결정으로 위장하지 않게 한다 | 문제 공간을 탐색한다. 선행 사례를 찾는다. 약한 방향을 깬다. 숨은 가정을 드러낸다 |
| 책임 아닌 것 | 문제가 진짜 문제인지 판정 · 대안 조사 · 방향 의심 | 해법 선택 · **사용자 의도를 새로 정의하는 것** |
| 조사 대상 | 사용자의 머릿속 | 문제 공간 |
| 적대성 | 없음 — 받아적고 되묻는다 | 있음 — steelman 과 premortem |
| 바깥 | 레포는 읽되 **웹은 보지 않는다** | landscape 가 통과 의례(R2) |
| 핵심 질문 | 다음 에이전트에게 무엇을 맡기는가 | 진짜 문제와 방향이 무엇인가 |
| 산출물 | `interview-seed` | `interview-brief` |

framing 에 없는 넷(landscape · steelman · blind-spot premortem · coverage-mapper)이 전부
"바깥에서 찾는" 장치다. 두 단계가 같은 형태(확산 후 압축)를 쓰면서 겹치지 않는 이유는 **확산의
방향이 반대**이기 때문이다.

**질문 라우팅** — 답을 사용자만 알 수 있으면 framing, 사용자 밖에서 찾아야 하면 interview.
같은 주제도 이 기준으로 갈린다.

**R1 재정의** — 기존 R1 `Reframe (메타 프롬프트)` 의 "받은 요청을 재구성" 은 이제 framing 이
한다. interview 의 R1 은 `Problem Reframe` 으로, **seed 가 가리키는 작업 뒤의 진짜 문제**를
재구성한다. 명칭 변경이 아니라 R&R 이동이다.

**아직 안 정한 것의 처리** — 기계 라벨은 쓰지 않지만 "이건 아직 안 정했다" 는 말로 쓴다.
그것 자체가 확정된 사실이고, 그 문장이 interview 의 첫 과제가 된다.

### 3.1 검토한 대안 — 새 단계 대신 기존 단계 확장

이 비교는 interview 의 R3 steelman 게이트에서 이미 수행됐고(ST1), 결론은 사용자 판정이다(S6).
설계 문서만 읽는 사람에게는 그 비교가 보이지 않으므로 여기 옮긴다.

| | **A. 새 단계 신설**(채택) | **B. `conducting-interview` 앞부분 확장** |
|---|---|---|
| 새 표면 | command 1 · skill 1 · agent 2 · script 1 · template 2 | 0 |
| 확산 방향 | 사용자 안쪽 전용 — landscape·steelman·premortem 없음 | 한 skill 안에 안쪽·바깥쪽 확산이 공존 |
| 새 세션 핸드오프 | 가능 | **가능**(양쪽 다 가능하다 — 이것은 A 의 근거가 아니다) |
| 위험 | 경계·핸드오프 신설이 멀티에이전트 실패의 지배적 원인이라는 지적(MAST) | R&R 이 한 skill 안에서 섞여 "어느 질문이 어느 단계의 것인가" 가 판정 불가 |

**B 를 버린 이유는 표면 수가 아니라 R&R 이다.** §3 이 보인 대로 두 단계는 확산의 *방향*이
반대이고, 한 skill 안에 두면 그 경계가 프롬프트 서술로만 존재해 검증할 수 없다. 반면 A 는
`framing-requests` 에 웹 도구를 주지 않는 것으로 경계를 **도구 표면**에 새긴다.

**steelman 이 든 핵심 사실 주장 하나는 검증에서 반증됐다** — *"요청 원형 보존이 이미 기계로
강제된다"* 는 거짓이었고(게이트 15항 어디에도 없다), 그것이 B 의 근거 중 하나였다. MAST 의
지적은 반박하지 않고 설계 제약으로 흡수했다(§3 의 R&R 분리와 §8.2 의 채택자 락이 그것이다).

---

## 4. 압축 규약

`plugins/spec-distill/references/compression.md` 에 둔다. `proceed-gate.md` 와 같은 자리,
같은 패턴이다 — 채택자를 **열거하지 않고 정본을 가리키는 포인터에서 도출**한다.

**이번 채택자는 `framing-requests` 하나다.** 채택 = *자기 표면에 `references/compression.md`
포인터를 두는 것* 이고, `conducting-interview` 는 **그 포인터를 두지 않는다.** 두면 도출로
채택자가 되어 앵커를 강제받는데, brief 는 아직 이 계약을 집행할 수 없으므로 그것은 형제 락이
자기 주석에서 이름 붙인 *"채택하지도 않은 계약의 앵커를 요구받는 거짓 RED"* 다.

brief 가 이 계약을 "원칙으로 상속" 한다는 말은 **`compression.md` 자신이 적는 문장**이지
`conducting-interview` 쪽 포인터가 아니다: *"오늘 이 계약을 게이트로 집행하는 것은 seed 뿐이고,
brief 는 재구조화(별도 설계) 이후에 채택한다."* 채택 여부와 상속 서술을 이렇게 갈라 두면
채택자 집합이 정확히 하나로 유지된다.

계약:

> **payload 는 압축의 결과이고, 압축에서 떨어진 모든 것은 audit 에 남는다.**
>
> **불변량** — 의도 · steering · 방향 · goal, 그리고 그 넷을 지탱하는 사실 중 **에이전트가 알
> 수 없는 것**. 넷을 지탱해도 에이전트가 이미 아는 사실이면 깎인다.
>
> **깎이는 것** — 자명한 것 · 하류 단계가 정할 수 있는 것 · 읽으면 아는 것 · 과정과 절차 ·
> 상시 규칙(`CLAUDE.md`·`AGENTS.md` 에 이미 있는 것) · **출처 링크**.
>
> **링크와 사실의 구분(사용자 결정).** 사용자가 준 자료는 에이전트가 알 수 없는 사실이므로
> 불변량이다 — 그러나 **URL 로 나르지 않고 말로 옮겨 적는다.** payload 에 URL 이 0개인 것은
> 사실을 버리라는 뜻이 아니라 **링크를 근거로 세우지 말라**는 뜻이다. 링크가 권위로 읽혀
> 하류를 끌고 가는 것이 이 조항의 이유다.
>
> **상한을 두지 않는다** — 확산에도 분량에도. 짧음은 상한이 아니라 뺄셈의 결과다.
>
> **메시지형 payload 에는 존재 검사를 두지 않는다.** 존재 검사가 payload 를 양식으로 만든다.
> 문서형 payload 는 절 존재 검사를 가질 수 있되 **확산물의 *원문·근거·전량*을 payload 에
> 요구해서는 안 된다.** 확산에서 나온 것의 **압축된 판정 한 줄**은 payload 의 것이다.
>
> **이 규약은 앞 단계의 결정을 봉인하지 않는다**(P23).

문장 하나에 적용하는 세 물음:

1. 이게 의도·steering·방향·goal 인가, 아니면 실행 세부인가. 세부면 뺀다.
2. 이 문장을 빼면 에이전트가 **틀리거나 빠뜨릴** 수 있는가. 어차피 맞게 할 거면 뺀다.
   대체로 하지만 가끔 빠뜨리는 것은 한 줄 값어치가 있다.
3. 레포 `CLAUDE.md`·`AGENTS.md` 에 이미 있는가. 있으면 뺀다.

---

## 5. 산출물

### 5.1 interview-seed

**메시지다.** 절도 라벨도 태그도 URL 도 없다. frontmatter 세 줄은 하니스용이고, **첫 턴에
붙여넣는 것은 본문**이다.

```markdown
---
type: interview-seed
next_phase: spec-distill:interview
audit_file: <basename>.audit.md
---

로그인이 가끔 실패한다. 사용자가 신고한 게 아니라 영업팀이 먼저 발견했고,
실패해도 에러가 안 뜨고 그냥 로그인 화면으로 되돌아간다.

한 번 토큰 만료를 의심해서 TTL 을 늘려봤는데 안 고쳐졌다. 그때 서버 로그에는
아무 기록도 없었다. 그래서 나는 클라이언트 쪽 경합을 의심하는데 확신은 없다.

`src/auth/` 안에서만 본다. 세션 스토어를 바꾸는 개편은 이번에 하지 않는다 —
다음 분기에 따로 할 예정이라 지금 손대면 두 번 일이 된다.

이 버그는 재현이 어렵다. 재현을 못 하겠으면 못 했다고 말하고 멈춰라.
추측으로 고쳐놓고 고쳤다고 하지 마라.

어떻게 고칠지는 네가 정해라. 다른 방향이 낫다고 판단되면 손대기 전에 말해라.
```

| 문장 | 불변량 | 에이전트가 알 수 있나 |
|---|---|---|
| 영업팀이 먼저 발견 · 에러 없이 되돌아감 | 의도의 근거 | 아니오 |
| TTL 늘려봤는데 안 됨 · 서버 로그 없음 | 방향의 근거 | 아니오 — 안 쓰면 똑같이 반복한다 |
| 클라이언트 경합 의심, 확신 없음 | 방향 | 아니오 |
| 세션 스토어 개편은 다음 분기 | 방향(가지 않을 곳) | 아니오 |
| 재현 못 하면 멈춰라 · 추측하지 마라 | steering | 아니오 — 기본값은 계속 가는 쪽 |
| 네가 정해라, 다른 방향이면 말해라 | steering + goal 경계 | 아니오 |

`npm test 통과` · `커밋까지` · `src/auth/ 를 본다` 같은 문장이 **없다** — 자명하거나
`CLAUDE.md` 에 있거나 에이전트가 찾는다.

audit 이 나르는 것: 원문(append-only) · **쏟아낸 질문 전체와 답한 것·안 한 것** · 긴 초안 ·
비평과 냉독 · degrade 원장.

### 5.2 brief 는 이번에 바꾸지 않는다

현재 brief 는 payload 27,458자 / audit 8,850자로 **payload 가 audit 의 3배**다. 확산의 산물이
압축물보다 커야 하는데 반대이고, 원인은 규약 부재가 아니라 **게이트 배치**다 — 15검사와
bijection 3종과 `check_verbatim_coverage.py` 가 전부 payload 를 대상으로 삼으니 검증하고 싶은
것이 전부 payload 로 끌려왔다. **검증 대상과 인계 대상이 같은 파일이면 검증이 인계물을
부풀린다.**

**그 재구조화는 이 설계에 담지 않는다.** 리뷰 두 라운드가 낸 22건 중 핵심 설계 지적은 0건이고
재구조화 쪽이 절반이었으며, 그중 하나는 전제 실패였다:

> **하류가 payload 경로 하나만 받는다.** 핸드오프는 `Skill superpowers:brainstorming
> <brief-path>` 이고 audit 경로를 넘기지 않는다. payload 의 68% 를 audit 으로 옮기면 그 정보가
> brainstorming 에서 **소실**된다. 그리고 `superpowers` 는 이 리포 밖 플러그인이라 핸드오프
> 계약을 우리가 바꿀 수 없다.

수리 경로는 있다(§4 계약이 이미 *"압축된 판정은 payload 의 것"* 이라 말하므로, 판정을 남기고
원문·근거만 옮기면 소실이 줄어든다). 그래도 남는 것이 **파서 형식 전환**(`user_sourced_items`
가 frontmatter YAML 에서 본문 절로), **bijection A 의 payload 축 소실**(§5 verdict 항목),
**bijection B 의 대상 절 소실**(새 절 구성에 "제약" 절이 없다), **append-only 가드의 관할
이동**, **픽스처 120건**이다. 이것은 request-framing 본체보다 큰 작업이고 자기 인터뷰·설계
사이클을 받아야 한다.

**그때까지 brief 는 압축 규약을 원칙으로만 따른다** — 계약을 가리키되 게이트로 강제받지
않는다. brief payload 의 URL 제거(B1·B2·B3)도 같은 이유로 그 설계로 넘어간다: 그 변경은
`landscape_uncited()` 뒤집기를 요구하는데, 뒤집으면 순수 부재 검사가 되어 양성 짝이 필요하고,
기존 `landscape_present()` 의 sentinel 이 그 짝을 새게 하며, `_web_disabled()` 가드가 "요구
완화" 에서 "금지 해제" 로 의미가 뒤집힌다. 셋이 얽혀 있어 재구조화와 분리해 넣을 수 없다.

**지금 브랜치의 brief 에 남은 `[미평가]` 라벨은 순수 4건**(§4 의 272–275행)**과 합성 1건**
(271행 `[중립·미평가]`)**이다.** 템플릿은 `[취함|피함|중립]` 셋만 규정하므로 이탈이지만,
`check_brief.py` 에 라벨 검사가 없어 **게이트 위반은 아니다** — 첫 판본이 "위반 6건" 이라 적은
것은 산문 언급까지 센 문자열 수였고 과대였다. 재구조화와 무관한 독립 수정이므로 PR1 에서
라벨만 판정으로 바꾼다.

---

## 6. P23 — Decisions Stay Refutable

### 6.1 원칙

devbrew 전체에 적용되는 신규 원칙이다. `docs/philosophy/devbrew-harness-philosophy.md` 에
넣는다.

> **정정 (P23 자신의 첫 적용, 구현 중 실측)** — 아래 인용의 **본문은 정본**이지만 **감싼 서식은
> 틀렸다.** 이 설계는 그 파일의 항목 서식을 재보지 않고 단정했고, 실제 관례는 다르다. 넣을 때
> 서식은 이웃 항목에서 **읽어서** 맞춰라 — 아래 블록을 서식까지 복사하지 말 것.
> 계획서(`docs/superpowers/plans/2026-08-27-request-framing-phase0.md` Task 1)에 실측한
> 서식이 있다. 근거: 형식 단정은 산문이라 틀려도 소리가 나지 않는다.

> **P23 — Decisions Stay Refutable**
> **Law 1 × P17 집행.** 확정된 결정은 재논의 대상이 아니지만 **반증 대상이다.** 앞 단계가 못
> 박은 것이 뒤 단계에서 틀린 것으로 드러나면, 그 단계는 근거를 제시하고 사용자 동의를 받아
> 피벗할 수 있어야 한다 — 임의 변경은 금지, 보고 후 재결정은 허용. Load-bearing: **오류를 가장
> 잘 볼 수 있는 자리는 그 오류를 만든 자리가 아니라 하류다** — 확정을 영구 봉인하면 볼 수 있는
> 자리와 고칠 수 있는 자리가 분리되고, 이른 단계의 오차가 하류 전 구간에 증폭된 채 아무도
> 말할 길이 없어진다. 재발견 금지는 반증 금지가 아니다.

번호가 P23 인 이유: 현재 최대가 P22 이고, 빈 번호(P1·P6·P7·P9·P15·P16·P19·P20)는 슬리밍 때
흡수·삭제된 것이라 재사용하면 거짓 인용이 생긴다.

기존 원칙에 흡수되지 않는 이유: 확정을 **만드는** 원칙은 넷(Law 1 · P12 · P17 · P18)이 있는데
확정을 **되돌리는** 원칙이 없다. 축이 다르다 — 결정의 **수명**이다. P18(Stagnation)이 "정체 시
다른 접근을 invoke 하라" 고 하지만, 그 다른 접근이 앞 단계의 확정을 건드려야 할 때 길이 없다.
보완이지 중복이 아니다.

anti-corollary 가 그대로 금지 패턴이 된다: **앞 단계의 확정이 하류에서 반증돼도 피벗 경로가
없는 것.** CLAUDE.md Forbidden Patterns 에 한 줄로 올린다.

**이 설계 자신이 P23 의 첫 사례다.** brief 재구조화를 이 문서에 담기로 한 결정이 설계 리뷰에서
반증됐고(하류 소실), 근거를 대고 사용자 동의로 §5.2 처럼 재결정했다. P23 이 없었으면 그
반증을 말할 자리가 없어 12건을 갈아 넣는 것 말고 길이 없었다.

### 6.2 집행 위치

지금 이 규약은 `finishing.md` B-3 의 **proceed 게이트 옵션 ①·② 안에서만** 산다 — ① 은
`/compact` 명령문에, ② 는 `brainstorming` 호출 프롬프트에 같은 문장을 싣는다(`finishing.md`
가 *"①과 ② 양쪽 모두 같은 문장을 싣습니다"* 라 적고 `test_conducting_interview_stage.sh` 가
양쪽을 잠근다).

**문제는 그 둘 밖이다.** 옵션 ③(수정)·④(종료)와 게이트를 지나지 않는 예외 경로(경로 부재 ·
kill switch)에는 이 규약이 없다. 그리고 `reviewing-spec` 의 Phase 5 에는 어느 옵션에도 없다.
즉 규약이 *핸드오프하는 두 경로에만* 있고 계약으로는 없다. 계약의 절로 승격하면 채택자
전체가 상속한다.

| 어디 | 무엇 |
|---|---|
| `docs/philosophy/devbrew-harness-philosophy.md` | P23 신설 |
| `CLAUDE.md` Forbidden Patterns | anti-corollary 한 줄 |
| `plugins/spec-distill/references/proceed-gate.md` | 재결정 규약을 **계약의 절로 승격** |
| `plugins/spec-distill/references/compression.md` | P23 상속 명시 |

---

## 7. 컴포넌트

### 7.1 새로 만드는 것

| 파일 | 무엇 |
|---|---|
| `references/compression.md` | 압축 규약(shared). 채택자는 포인터에서 도출. 오늘 집행 대상은 seed 뿐임을 자기 안에 적는다 |
| `references/trivia-escape.md` | 5패턴 정의를 빼내 두 command 가 포인터로 가리킨다 |
| `commands/request-framing.md` | kill switch + trivia escape 포인터 + skill 호출. `interview.md`(56줄)와 같은 크기 |
| `skills/framing-requests/SKILL.md` | 확산 후 압축 절차. `proceed-gate.md`·`compression.md` 채택. **채택하는 순간 기존 락이 요구하는 앵커 넷을 자기 표면에 가져야 한다** — 정지 어휘(`턴 종료`/`다음 턴`) · `polite stop` 금지 · **degrade 채널**(`framing_degradations`) 이름 · **P23 재결정 규약**. 넷은 `test_proceed_gate_adopters.sh` 가 채택자마다 강제하는 것이고, 이 skill 은 셋째 채택자로 **자동 도출**된다 |
| `agents/seed-critic.md` | `tools: []`. 초안 + 원문 + 레포 `CLAUDE.md` 전문 inline |
| `agents/seed-readback.md` | `tools: []`. seed 만. 판정은 사용자 |
| `templates/interview-seed-template.md` | **예시와 쓰지 말 것.** 양식이 아니다 |
| `templates/interview-seed-audit-template.md` | 원문 · 질문 전체 · 긴 초안 · 비평과 냉독 · degrade |
| `scripts/check_seed.py` | 검사 넷(§8.1) — **seed 본문에 대해서는 전부 부재 검사**이고, 원문 보존 하나만 audit 쪽 존재 검사다 |
| `scripts/build_seed_inline_blob.py` | critic 입력 조립. `build_brief_inline_blob.py` 와 같은 위생 규약(식별자 redact) |
| `scripts/run_seed_codex_reviewer.sh` | seed 억제 축 codex 러너. `run_brief_codex_reviewer.sh` 의 골격을 따르되 **brief 러너를 건드리지 않는다**(아래) |
| `scripts/build_seed_codex_prompt.py` | seed payload 형상의 프롬프트 빌더 |
| `scripts/seed-codex-suppression-checklist.md` | 억제 축 체크리스트 — C25 의 네 축 |
| `tests/*` | §8.2 |

`seed-critic` 과 `seed-readback` 을 나눈 것은 도구가 아니라 **입력** 때문이다. critic 은 원문과
`CLAUDE.md` 에 대조해야 해서 셋을 다 받고, readback 은 아무것도 모른 채 seed 만 받아야 측정이
성립한다. 합치면 readback 이 원문을 알게 되어 "seed 만 읽고 알 수 있나" 를 더 이상 재지 못한다.

### 7.2 고치는 것

brief 재구조화를 뺐으므로 편집면이 작다. 완결성 oracle 은 §2.5 의 스윕 grep 하나뿐이고, 그것이
덮는 것은 probe 별칭뿐이다 — 아래는 **완결성 주장이 아니라 목록**이다(첫 판본이 "각 항목이 한
파일의 한 지점" 이라고 주장했다가 `reviewing-spec` 누락으로 반증됐다).

| 파일 | 무엇 |
|---|---|
| `skills/conducting-interview/SKILL.md` | R1 을 `Problem Reframe` 으로 · 탐색 경계 · seed 입력 처리 · **probe cap 제거**(§2.5) · coverage-mapper 바운드를 에피소드 필드 둘로 이식 + 조건 2 유한성 근거 한 줄 |
| `skills/conducting-interview/references/finishing.md` | 최초 요청 원문을 §6 에 보존하도록 지시 · floor 사용자-승인 박제 경로 |
| **`skills/reviewing-spec/SKILL.md`** | **P23 재결정 규약 어휘**(오늘 0건 — 이것 없이는 PR0 의 새 앵커가 착지 즉시 RED 다) |
| `commands/interview.md` | trivia escape 를 `references/trivia-escape.md` 포인터로 · seed 아닌 입력에 조언 한 줄(차단 아님) |
| `scripts/probe_budget.py` · `tests/test_probe_budget.sh` | **삭제** |
| `tests/fixtures/state-probe-at-cap.md` · `state-probe-within.md` | **삭제**(위 테스트 전용) |
| `tests/test_conducting_interview_stage.sh` | probe 단언 제거(정지 어휘 앵커는 유지) + **floor 탈출구 단언 교체** — 아래 |
| `templates/interview-audit-template.md` | `## 2. Budget` **본문 교체** — 아래 |
| `scripts/run_spec_codex_reviewer.sh` | 맨 `${CLAUDE_PLUGIN_ROOT}` 를 형제 파일과 같은 `:-` 유도로 |
| `scripts/brief_review_state.py` | **degrade 원장 writer 를 framing 이 재사용한다.** `--ledger-key` 인자(기본값 `brief_review_degradations` 유지)로 framing 이 `framing_degradations` 에 쓰고, `AXES`(= 원장의 `affected_axis` 닫힌 열거)에 `suppression` 을 더한다. 이 파일 하나만 고친다 |
| `tests/test_proceed_gate_adopters.sh` | **P23 앵커만** 추가. 멤버십 단언 없음(§8.2) |
| `README.md` · `CHANGELOG.md` · `plugin.json` | flow · bump |

**`## 2. Budget` 의 새 본문** — 현재 내용은 `- probe_count: <n> / cap <n>` 한 줄뿐이고 cap 이
사라지면 빈 의례가 남는다. 대체 내용은 **이 인터뷰가 실제로 태운 것**이다:
`- 질문 라운드: <n> · agent dispatch: <n> · codex 실호출: <n> (성공 <n>)`. 상한이 아니라
**지출 기록**이며, 상한을 두지 않는다는 결정과 충돌하지 않는다.

**floor 탈출구의 대체 락** — `test_conducting_interview_stage.sh` 의 probe 백스톱 블록에
floor escalation 3옵션(계속 / 박제 / abort)을 잠그는 **유일한 기계 단언**이 있고, probe 단언을
지우면 함께 쓸려 나간다. 새 탈출구(사용자 발화 → 박제)는 발동 조건만 다르고 존재해야 하는 것은
같으므로, 같은 파일에 **박제 경로 단언을 새로 둔다** — SKILL 표면에 "사용자가 종료를 요청하면
미충족 floor 를 사용자-승인 박제로 닫는다" 가 실재하는가. 없으면 RED.

**억제 축은 brief 파이프라인에 얹지 않고 seed 쪽에 따로 세운다.** 첫 판본은 `suppression` 을
brief 러너에 배선하려 했는데, 그러면 세 지점의 축 하드코딩(`build_brief_codex_prompt.py` 의
`AXES` · `run_brief_codex_reviewer.sh` 의 `case … exit 2` · `brief_review_state.py` 의 `AXES`)을
전부 건드려야 하고, 그중 두 어휘는 **의미가 다르다** — 앞 둘은 *codex 프롬프트 축*(축마다
체크리스트 파일이 실재해야 한다)이고 셋째는 *degrade 원장의 `affected_axis`*(체크리스트가
있을 이유가 없다). 게다가 brief 프롬프트 빌더는 **brief payload 형상**을 만드는데 입력은
seed 다.

그래서 §7.1 이 **seed 전용 러너·빌더·체크리스트 셋**을 새로 만든다. brief 러너·brief 프롬프트
빌더·`merge_brief_review.py`·`finishing.md` 의 핸드오프 인자는 **하나도 건드리지 않는다.**

**억제 축은 판정에 합류하지 않는다.** seed 비평자의 codex 업그레이드로만 쓰이고, 그 findings 는
어떤 병합기도 거치지 않고 §2.4 의 억제 리뷰 출력으로 **사용자에게 직접** 간다. codex 가 죽으면
degrade record 하나가 `framing_degradations` 에 남고 §2.4 의 격리 critic 이 단독으로 돈다.

**최초 요청 원문 보존** — 지금 `finishing.md` 는 §6 를 `user_statements` 에서만 채우고
`$ARGUMENTS`(최초 요청)는 거기 들어가지 않는다. 게이트 15항 어디에도 원문 보존 요구가 없고,
지금까지 보존된 것은 관례였다. 재구조화 없이 **현재 위치(payload §6)** 에 요구로 넣는다.

**러너 결함은 `run_spec_codex_reviewer.sh` 에 있다**(2026-08-23 실측 — 이 설계의 첫 판본은
형제 파일 `run_brief_codex_reviewer.sh` 를 잘못 지목했다). 그 파일은 `set -euo pipefail` 아래
`:137`·`:186` 에서 맨 `${CLAUDE_PLUGIN_ROOT}` 를 참조해, 변수가 없는 환경(스킬 수동 호출)에서
codex 에 닿기 전에 죽고 사유가 `aborted_before_completion` 하나로 뭉개진다.

형제 파일이 이미 답을 갖고 있다 — `run_brief_codex_reviewer.sh:27` 이
`PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"` 로
해소했고, `:17-18` 이 그것을 *"fallback 없이 참조하면 훅이 env 를 주지 않는 컨텍스트에서
즉사한다"* 는 **반복 금지 규칙**으로 적어 뒀다. 같은 형태를 spec 러너에 이식한다.
`${CLAUDE_PLUGIN_ROOT:?}` 는 그 규칙이 금지한 즉사를 되살리므로 쓰지 않는다.

### 7.3 만들지 않는 것

**이 목록은 `request-framing`/seed 쪽에 *새로 만들지 않는 것*이다** — brief 가 이미 가진 것을
없앤다는 뜻이 아니다.

profile 표 · adapter · target 별 delta · seed 스키마 · 슬롯 존재 검사 · seed 용 bijection ·
커버리지 원장 파일 · 분량 상한 · 질문 상한 · open·추론·외부 태그 · seed 안의 URL.

---

## 8. 검증

### 8.1 게이트

seed 에만 걸린다. brief 게이트는 이번에 건드리지 않는다(§5.2).

| | seed |
|---|---|
| 존재 검사 | **없음**(본문이 비어 있지 않음만) |
| 부재 검사 | 답-슬롯 헤딩 · 태그 · URL |

`check_seed.py` 가 재는 넷:

1. **원문 보존** — audit 원문 절이 존재하고 비어 있지 않다.
2. **답-슬롯 헤딩 부재** — 미해결 질문 목록 · 대안 목록 · 인수 조건 초안 · 기각 목록에 해당하는
   `##` 헤딩이 없다.
3. **태그 0개** — `[open:` · `[추론:` · `[외부:` 가 본문에 없다.
4. **URL 0개** — `https?://` 가 본문에 없다. web kill switch 와 **무관**하다(웹이 꺼져 있어도
   금지는 유지된다 — 완화할 대상이 애초에 없다).

**금지 조항** — `check_seed.py` 에 seed 본문의 **존재 검사를 추가하지 않는다.** 그것이 이
게이트가 양식으로 변질되는 유일한 경로이고, §8.2 의 `test_seed_one_sentence.sh` 가 그 금지를
산문이 아니라 동작으로 잡는다.

### 8.2 락과 mutation

이 설계가 소유하는 것은 **무엇이 단언되어야 하는가** 다. *어느 테스트가 어느 PR 에서 green
이어야 하는가* 는 아래 「락 × PR 은 계획이 도출한다」로 넘긴다.

| 락 (신규) | mutation (이 편집이 RED 를 내야 한다) |
|---|---|
| `test_check_seed.sh` | 검사 함수 하나를 `check_seed.py` 에서 삭제 → 해당 RED 픽스처가 GREEN 이 되면 락 실패 |
| `test_seed_one_sentence.sh` | **한 문장뿐인 seed 픽스처(헤딩 0·필드 0)가 통과해야 한다.** `check_seed.py` 에 본문 존재 검사를 **추가**하면 RED |
| `test_request_framing_command.sh` | trivia escape 포인터 · kill switch · skill dispatch 각각 삭제 |
| `test_seed_agents.sh` | `tools: []` → `tools: Read` |
| `test_compression_adopters.sh` | ① 채택자 표면에서 압축 어휘 삭제 ② 정본을 presence 코퍼스에 넣기(자기 만족) ③ 유일 채택자가 포인터 상실(하한 1) — 셋 다 RED |
| **coverage-mapper 바운드 단언(교체)** | `test_conducting_interview_stage.sh` 의 기존 단언이 `probe_count` 단위를 잠근다. PR1 이 그것을 지우므로 **두-필드 바운드에 대한 대체 단언**을 같은 파일에 둔다 — 없으면 그 바운드가 locked 에서 unlocked 로 후퇴한다 |
| **floor 박제 경로 단언(교체)** | 같은 파일의 probe 백스톱 블록에 있던 3옵션 단언이 함께 지워진다. 대체 단언은 **그 파일 자신의 규칙대로 awk 윈도우로 스코프**해야 한다 — 박제 어휘가 블록 밖에도 선재해서 전-파일 grep 은 teeth 가 0 이다 |

`test_proceed_gate_adopters.sh` 는 **기존 락**이다. P23 앵커 하나만 더하고, `framing-requests`
가 셋째 채택자로 자동 도출되어 앵커 넷을 요구받는다(§7.1).

#### 락 × PR 은 계획이 도출한다 — 이 문서가 열거하지 않는다

**네 라운드 동안 이 행렬을 손으로 적어 네 번 틀렸다.** 매번 대상만 옮겨 갔다(PR0 → PR1 → PR2 →
PR3). 열거가 원인이므로 열거를 그만둔다. 이 문서는 **규칙**을 주고, `writing-plans` 가 레포에
대고 도출한다.

> **각 PR 은 자기가 건드리는 파일 집합 F 를 갖는다. 계획은 `tests/` 를 전수해 F 의 원소를
> 코퍼스로 삼는 테스트를 도출하고, 그 전부에 대해 그 PR 이 green 인지 확인한다.** 목록을
> 손으로 적지 않는다 — 손으로 적은 목록이 틀렸다는 것이 네 번 관측됐다.

도출할 때 밟은 함정 둘을 이름으로 남긴다. 계획이 같은 자리를 다시 밟지 않게 한다.

| 함정 | 실측된 형태 |
|---|---|
| **완료 oracle 이 자기 자신을 잡는다** | probe 별칭 스윕의 완료 조건을 "`tests/fixtures/` 밖 0건" 으로 두면 `CHANGELOG.md` 의 과거 릴리스 이력에 걸려 **원리적으로 green 이 될 수 없고**, PR1 자신의 `Removed: probe_budget.py` 엔트리가 락을 RED 로 만든다. 이력 파일을 스캔에서 빼되 **왜 뺐는지를 락 본문에 함께 적어라** — 이유 없는 면제 목록은 그 질문을 영구히 닫는다 |
| **같은 이름의 두 열거가 다른 것을 뜻한다** | `AXES` 가 세 곳에 있는데 `build_brief_codex_prompt.py` 는 *codex 프롬프트 축*(축마다 체크리스트 파일 실재), `run_brief_codex_reviewer.sh` 는 `case … exit 2` 의 *실제 fail-point*, `brief_review_state.py` 는 *degrade 원장의 `affected_axis`* 다. parity 락을 세우기 전에 **두 열거가 같은 것을 뜻하는지 먼저 확인하라** — 아니면 술어 자체가 거짓이다 |

#### 채택자 멤버십 락은 만들지 않는다 — OQ3 은 열린 채로 남긴다

현재 `test_proceed_gate_adopters.sh` 는 정본을 가리키는 skill 집합 **A** 를 구해 `|A| >= 2` 와
각 원소의 앵커를 본다. 셋째 채택자가 생기는 순간, 진짜 채택자가 포인터를 잃고 새 채택자가 대신
등록되는 치환이 `|A|` 를 유지하며 통과한다. 이것이 인터뷰가 **OQ3 으로 열어 둔** 질문이다.

**이 설계는 그것을 닫지 않는다.** 세 판본을 시도했고 세 번 다 구멍이 났다.

| 시도 | 왜 실패했나 |
|---|---|
| 정지 어휘 집합 **B** 와 `A == B` | 대칭 관계라 포인터와 어휘를 **한 편집으로 함께** 잃으면 등식이 유지되고 채택자별 앵커 단언 대상에서도 빠진다 |
| `Skill <plugin>:<stage>` 리터럴로 **H** 도출 후 `H ⊆ A` | `framing-requests` 가 H 에서 빠진다 — seed 핸드오프는 사람의 붙여넣기라 표면에 호출 리터럴이 없다. **하한을 vacuous 하게 만드는 셋째 채택자 자신이 무방비** |
| `next_phase` ∪ 리터럴 합집합으로 H 도출 | "자기 표면" 의 기계적 정의가 없고, `next_phase` 정본이 **템플릿**(skill 표면 밖)에 산다. 리터럴을 템플릿으로 옮기거나 키를 rename 하면 산출물은 그대로인데 H 가 줄어 GREEN 이다. 게다가 같은 단언을 compression 에 두면 `reviewing-spec`(압축 payload 를 만들지 않는다)까지 채택을 강제받아 **채택하지도 않은 계약의 앵커를 요구받는 거짓 RED** 가 난다 |

세 번째 시도가 특히 시사적이다 — 락의 앵커를 **피검자가 쥐고 있다.** 도출 대상이 skill 표면인데
정본은 템플릿에 있으므로, 표면의 문구 한 줄을 옮기는 것만으로 측정에서 빠져나갈 수 있다.

**그래서 이 설계는 락을 더하지 않고, 기존 락을 그대로 둔다.** `|A| >= 2` 와 채택자별 앵커 3종
(정지 어휘 · polite stop 금지 · degrade 채널)은 유지되고, 여기에 **P23 앵커 하나만** 더한다.

**대신 이 설계가 그 구멍을 넓힌다는 사실을 명시한다.** `framing-requests` 가 셋째 채택자가
되면 오늘 치환 변이가 RED 인 이유(대체 후보가 정지 어휘를 0줄 가진 우연)가 소멸한다. 그것을
§11 에 이월 항목으로 이름을 붙여 남긴다 — 우연히 성립하던 것이 이 설계로 성립하지 않게 되는
것은 이 설계가 만든 변화이므로, 닫지 못하더라도 기록되어야 한다.

**네 번째 앵커** — 각 채택자가 자기 표면에 **재결정 규약**(P23)을 갖는가. 코퍼스 규칙(정본은
스캔 대상 아님)이 그대로 적용된다. 오늘 `skills/reviewing-spec/SKILL.md` 에는 그 어휘가 0건
이므로 **PR0 이 그 파일도 편집한다**(§7.2) — 자기 락을 green 으로 만들지 않는 PR 은 단독
green 이 아니다.

`test_compression_adopters.sh` 는 멤버십을 재지 않는다. 채택자별 압축 어휘 존재와 코퍼스
자기만족 방지를 본다.

**단 개수 하한 1 은 둔다.** 두지 않으면 유일한 채택자가 포인터를 잃는 순간 도출 집합이
공집합이 되고, 채택자별 루프가 0회 돌아 **vacuous GREEN** 이 난다 — 형제 락이 자기 주석에서
정확히 그 모양을 막으려고 하한을 둔다고 적어 뒀다. 하한 1 은 열거가 아니므로 둘째 채택자가
생겨도 그대로 작동한다(brief 가 재구조화 이후 채택하면 자동으로 같은 요구를 받는다).

### 8.3 회귀

측정된 값이다. `probe` 별칭 스윕이 비-픽스처 **10건** + 픽스처 **61건**에 걸린다(§2.5).
brief 재구조화를 뺐으므로 §4 URL 픽스처 59건은 **이번 범위 밖**이다.

워크트리 baseline 은 **61 pass · 1 fail** 이고 그 1건(`test_hook_output_schema` cross-resolver)은
선재 실패다. 착수 전 다시 캡처하고, 그 1건은 건드리지 않는다.

---

## 9. PR 분해

**각 PR 은 단독으로 green 이어야 한다.** 이것이 아래 분해를 정한 유일한 제약이다.

| | 내용 | 이 PR 이 새로 넣는 단언 | 버전 |
|---|---|---|---|
| **PR0** | P23 신설 — philosophy · CLAUDE.md · `proceed-gate.md` 재결정 규약 승격 · **`reviewing-spec/SKILL.md` 에 그 어휘 추가**(오늘 0건, 없으면 아래 앵커가 착지 즉시 RED) | 채택자 P23 앵커 | `0.34.0` |
| **PR1** | **상한 삭제 + 원문 보존** — `probe_budget.py`·전용 픽스처 제거 · coverage-mapper 바운드를 에피소드 필드 둘로 이식 · 조건 2 유한성 근거 · floor 탈출구 · Budget 본문 교체 · `finishing.md` 원문 보존 · brief `[미평가]` 라벨 판정 | coverage-mapper 바운드 단언(교체) · floor 박제 경로 단언(교체, awk 스코프) · probe 잔존 단측 단언 | `0.35.0` |
| **PR2** | **러너 위생** — `run_spec_codex_reviewer.sh` 의 맨 참조를 형제 파일과 같은 `:-` 유도로 · `brief_review_state.py` 에 `--ledger-key` + `AXES` 에 `suppression` | 러너가 env 없이도 codex 에 닿는가(사유가 `aborted_before_completion` 으로 뭉개지지 않는가) | `0.36.0` |
| **PR3** | **request-framing 본체** — `compression.md` · `trivia-escape.md` · command · skill(앵커 넷 포함) · agent 2 · template 2 · `check_seed.py` · blob 빌더 · **seed codex 러너·빌더·체크리스트** | §8.2 의 seed 락 5종 + `test_compression_adopters.sh` | `0.37.0` |
| **PR4** | 연결 — R1 재정의 · 탐색 경계 · seed 입력 규약 · `/interview` 조언 · README flow | 없음(기존 락 갱신만) | `0.38.0` |

**"각 PR 단독 green" 은 위 열이 아니라 §8.2 의 도출 규칙이 보장한다.** 새 단언을 적어 두는 것은
*무엇을 새로 잠그는가* 를 보이기 위해서이고, *그 PR 이 깨뜨릴 수 있는 기존 락*은 열거하지
않는다 — 계획이 `F → 그 파일을 코퍼스로 삼는 테스트` 로 도출한다. 첫 판본들이 그 목록을 손으로
적어 네 번 틀렸고, 매번 대상만 옮겨 갔다.

**억제 축이 PR2 에서 PR3 으로 옮겨 간 이유**: seed 전용 러너·빌더·체크리스트로 재설계했으므로
seed 가 없는 시점에 단독으로 설 수 없다. PR2 에는 brief 러너와 무관하게 옳은 두 가지(러너
fallback 정정 · 원장 writer 의 재사용 준비)만 남는다.

PR0 이 맨 앞인 이유는 뒤 PR 들이 확정을 재결정하기 때문이다 — 규약이 먼저 서 있어야 그
재결정들이 규약을 따르는 것이 된다.

**PR2 를 따로 뗀 이유**: codex 억제 축은 `AXES` 하드코딩 · 체크리스트 신설 · 러너 배선 · 러너의
`set -u` 결함까지 네 지점이 얽혀 있고, request-framing 본체 없이도 단독으로 옳다. PR3 에 섞으면
"각 PR 단독 green" 을 검증할 때 무엇이 깨뜨렸는지 가려지지 않는다.

**`compression.md` 를 PR3 에 둔 이유**: 계약은 그 계약을 참으로 만드는 첫 산출물과 같은 PR 에
들어가야 한다. 아직 압축을 집행하는 산출물이 없는 상태에서 "payload 는 압축물" 을 선언하면 그
선언이 첫날부터 무집행이다.

`main` 에서 분기, merge commit, 각 PR 같은 커밋에서 bump.

---

## 10. 재결정 기록

P23 에 따라, 이 설계가 뒤집은 확정을 근거와 함께 남긴다. 조용히 덮어쓰지 않는다.

| 항목 | 원래 | 재결정 | 근거 |
|---|---|---|---|
| C3 | codex 가 단독 비평자 | 역할 슬롯 — 격리 agent 가 기본, codex 는 업그레이드 | codex 미가동 실측 |
| C24 | 실행 대상 감지 + profile adapter | 폐기. 대상은 하나 | 대상이 하나면 추상화가 값을 하지 않는다 |
| C1 | 소비자 중립 **스키마** + 확장점 | 스키마를 두지 않음 | 산문이 가장 중립적이다 |
| C14 | confirmed·inferred·open 구분을 seed 에 명시 | 범주가 ship 시점에 비어 무의미 | 전문을 사용자가 확정하므로 전부 사용자 결정 |
| C29 | Phase 0 외부탐색이 컨텍스트 공백 담당 | 경계는 유지하되 framing 몫이 0 | 공백은 사용자에게 물어 메운다 |
| C2 | 미확정을 `open` **라벨**로 표시 | 라벨 없이 말로 쓴다 | 태그 전면 삭제 |
| **brief 재구조화 동시 진행** | 이 설계에 포함 | **별도 설계로 분리**(§5.2) | 하류가 payload 경로만 받아 68% 가 소실된다는 전제 실패 + 파급이 본체보다 크다 |
| **brief payload URL 제거(B1–B3)** | 이 설계에 포함 | 재구조화 설계로 이월 | `landscape_uncited` 뒤집기·양성 짝·`_web_disabled` 의미 반전이 셋이 얽혀 분리 불가 |

C9(원문의 "`/interview` 를 좁혀라" 기각)이 만든 선례를 따른다 — 원문 지시가 조용히
증발하지 않게 기각을 명시한다.

---

## 11. 남은 것

정직하게 적는다.

| | |
|---|---|
| **brief 재구조화 — 이월 항목 다섯** | ① `user_sourced_items` 의 **파서 형식 전환**(frontmatter YAML → 본문 절) ② **bijection A 의 payload 축**(§5 `verdict:` 항목)이 이관되면 `refs` 가 공집합이 되고 `sec5_absent` 가드도 무력화된다 ③ **bijection B 의 대상 절**(payload §2 "제약")이 새 절 구성에 없다 ④ **§6 append-only laundering 가드의 관할 이동**(payload 편집 권한 표의 행이라 audit 을 관할하지 않는다) ⑤ **픽스처 120건**(§4 URL 59 + probe 61). 이름으로 적어 두는 이유는 §11 만 읽는 세션이 이 다섯을 복원할 수 있어야 하기 때문이다 |
| **brief payload URL 제거(B1–B3)** | 이월. `landscape_uncited()` 뒤집기 · 양성 짝이 `landscape_present()` 의 sentinel 로 새는 것 · `_web_disabled()` 가드가 "요구 완화" 에서 "금지 해제" 로 의미가 뒤집히는 것 — 셋이 얽혀 재구조화와 분리 불가 |
| **하류 핸드오프 계약** | `superpowers` 는 이 리포 밖이라 `<brief-path>` 하나만 넘기는 계약을 우리가 못 바꾼다. 재구조화 설계의 **선결 문제**다 |
| **OQ3 — 채택자 치환 구멍이 이 설계로 넓어진다** | `test_proceed_gate_adopters.sh` 의 하한은 개수이지 구성원이 아니다. 오늘 치환 변이가 RED 인 것은 유일한 대체 후보가 정지 어휘를 0줄 가진 **우연**인데, `framing-requests` 가 셋째 채택자가 되면 그 우연이 소멸한다. 세 판본을 시도해 세 번 구멍이 났고(§8.2) 닫지 못한 채 남긴다 — **이 설계가 만든 변화이므로 기록한다** |
| **agent-only 루프의 총량 바운드** | 에피소드 필드 둘은 **밀도**(구간당 1회)를 묶지 **총량**을 묶지 않는다. cap 제거로 정체 구간 수의 상한이 사라졌고 derived 차원 admit 되먹임도 있다. 검토한 대안: 에피소드 총 dispatch 상한 · 사용자 게이트 재노출. 어느 것도 채택하지 않았다 |
| **seed 에서 interview 로의 인계 규약** | 태그 없는 seed 가 도착했을 때 `user_sourced_items` 를 어떻게 채우나. 기존 게이트의 동작 변경이다. PR4 에서 정의 |
| **"수정" 의 정의** | 게이트 3번 선택지가 재취조 · 재깎기 · 직접편집 중 무엇인가. 실무에서 가장 자주 밟히는 경로인데 미정의다. PR3 에서 정의 |
| **seed 와 인터뷰 중 새 발화의 우선순위** | 확정된 seed 를 인터뷰 중 사용자가 뒤집으면 어느 쪽이 이기나. P23 이 방향은 주지만 규칙은 없다 |
| **깎기의 기준선** | "누구에게 자명한가" 는 모델 릴리스마다 움직인다. 규칙이 없고, 이것이 seed 길이를 정하는 유일한 레버다 |
| **효과 측정** | C12 로 측정하지 않는다. 이 단계를 제거하게 만들 관측은 정해지지 않았다 |
| **codex 축** | 이 계정에서 한도가 소진돼 실행 검증이 불가능하다. 이 설계의 리뷰도 Claude 단독으로 받았다 — 모델 다양성 없이 확정됐다 |
| **`shared/codex` 의 오분류** | `codex_findings_to_yaml.py` 가 quota 를 인증 오류로 분류한다. 범위 밖이므로 별도 이슈로 남긴다 |
| **정체 감지의 과소계수** | `issue_history` 의 id 가 메시지 해시라, 같은 결함이 다른 문면으로 재제기되면 새 id 가 되어 `raised_count` 가 오르지 않는다(2026-08-23 실측 — 원장은 7건 resolved 라 했으나 리뷰어는 3건만 닫혔다고 했다). 범위 밖이므로 별도 이슈 |
| **세 단계 질문 중복** | 라우팅 규칙은 기계적이지만 경계 판단은 모델이 한다. 줄이지 제거하지 못한다 |

---

## Handoff Context

PR0 에서 PR4 까지가 여러 세션에 걸친다. `/compact` 를 지나면 대화가 사라지므로, **다음 세션이
이 문서만 읽고 이어갈 수 있어야 하는 것**을 여기 남긴다.

### TL;DR

파이프라인 맨 앞에 `request-framing` 회의를 세운다. 산출물 `interview-seed` 는 **새 세션의 첫
턴에 그대로 붙여넣는 산문 메시지**이고, 절·라벨·태그·URL 이 없다. 만드는 방식은 **확산 후
압축**이며, 압축의 불변량은 **의도 · steering · 방향 · goal + 에이전트가 알 수 없는 사실**이다.
압축 규약은 공유 계약으로 두되 **이번에는 seed 에만 집행**한다. 그리고 앞 단계의 확정이 하류를
봉인하지 않게 하는 **P23** 을 devbrew 전체에 신설한다.

### 이 문서 밖에 있으면 안 되는 암묵 컨텍스트

- **왜 매번 예시가 틀렸는가.** 초안들이 반복해서 *실행 세부*(어느 파일·어느 명령·권한)를 썼다.
  seed 에 남을 것은 세부가 아니라 **하류가 정할 수 없는 것**이다. §5.1 표가 그 판정을 문장별로
  보이는 유일한 자리다.
- **왜 게이트를 부재 검사로만 두는가.** 존재 검사가 payload 를 양식으로 만들고, 양식이 내용을
  미리 판 구멍 모양으로 강제한다 — 그것이 이 단계가 막으라고 만들어진 실패다.
  `test_seed_one_sentence.sh` 가 이 금지를 동작으로 잡는 유일한 락이다.
- **왜 brief 를 안 건드리는가.** 하류 `superpowers:brainstorming` 이 payload 경로 하나만 받아
  확산물 이관이 곧 정보 소실이 된다. 이 사실이 재구조화 설계의 출발점이어야 한다.
- **왜 `## 2. Budget` 절을 남기는가.** 상한을 지우면서 절까지 지우면 `AUDIT_SECTIONS` 와 픽스처
  61건이 스윕 대상이 된다. 절은 유지하고 내용만 바꾼다(§2.5).
- **왜 채택자 멤버십 락을 안 만들었는가.** 세 판본을 시도해 세 번 구멍이 났다(§8.2 표). 마지막
  판본이 특히 시사적이다 — 도출 대상이 skill 표면인데 `next_phase` 정본은 템플릿에 살아서,
  표면의 문구 한 줄을 옮기는 것만으로 측정에서 빠져나갈 수 있다. **락의 앵커를 피검자가
  쥐고 있는 형태**다. OQ3 은 인터뷰가 열어 둔 질문이지 요구가 아니므로 닫지 못한 채 §11 에
  기록했다 — 다만 이 설계가 그 구멍을 **넓힌다**는 사실까지 함께 적었다.
- **codex 축은 이 계정에서 돌지 않는다.** 감지기는 `available: true` 를 내지만 실호출이 exit 1
  이다. 이 설계의 리뷰도 Claude 단독으로 받았다.

### 계획으로 미루는 것 (writing-plans 소관)

- **락 × PR 행렬** — §8.2 의 도출 규칙대로 `F → 그 파일을 코퍼스로 삼는 테스트` 전수. **이것이
  계획의 첫 작업이다.** 설계가 네 번 손으로 적어 네 번 틀린 자리이므로, 열거하지 말고 도출하라.
- 각 PR 안의 커밋 분할과 순서.
- probe 별칭 스윕의 실제 수행 방법(비-픽스처 10건) — 일괄인지 수동인지.
- `seed-codex-suppression-checklist.md` 의 실제 체크리스트 문면.
- floor 박제 단언·coverage-mapper 바운드 단언의 awk 윈도우 경계.
- §11 의 미해결들의 착지점.
