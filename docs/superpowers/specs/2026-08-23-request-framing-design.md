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
압축해 넘긴다. 압축 규약은 `interview-brief` 와 공유하고, 앞 단계의 확정이 뒤 단계를 영구히
닫지 않게 하는 원칙(P23)을 devbrew 전체에 신설한다.

## 목차

- [1. 무엇을 만드는가](#1-무엇을-만드는가) — [1.1 정체](#11-정체) · [1.2 왜](#12-왜) · [1.3 두 산출물](#13-두-산출물)
- [2. 어떻게 도는가 — 확산 후 압축](#2-어떻게-도는가--확산-후-압축) — [2.1 전체 그림](#21-전체-그림) · [2.2 확산](#22-확산) · [2.3 압축](#23-압축) · [2.4 검증과 확정](#24-검증과-확정) · [2.5 상한을 두지 않는다](#25-상한을-두지-않는다)
- [3. 두 단계의 R&R](#3-두-단계의-rr)
- [4. 압축 규약](#4-압축-규약)
- [5. 산출물](#5-산출물) — [5.1 interview-seed](#51-interview-seed) · [5.2 interview-brief 재구조화](#52-interview-brief-재구조화)
- [6. P23 — Decisions Stay Refutable](#6-p23--decisions-stay-refutable)
- [7. 컴포넌트](#7-컴포넌트)
- [8. 검증](#8-검증)
- [9. PR 분해](#9-pr-분해)
- [10. 재결정 기록](#10-재결정-기록)
- [11. 남은 것](#11-남은-것)

---

## 1. 무엇을 만드는가

### 1.1 정체

파이프라인 맨 앞의 **회의**다. 사용자와 에이전트가 **의도 · steering · 방향 · goal** 을 싱크한
뒤, 그것을 새 세션의 첫 턴 메시지 하나로 **압축**한다.

사용자-facing 단계명은 `request-framing`, 산출물명은 `interview-seed`. `meta-prompting` 은
내부 메커니즘 명칭으로만 쓴다.

### 1.2 왜

**첫 턴이 그 세션 전체를 결정한다.** 에이전트는 첫 턴에서 가정을 세우고 거기 매인다 — Laban
et al. 의 다중턴 실측이 잰 것이 그것이다(정보를 여러 턴에 나눠 주면 평균 39% 저하, 원인은
능력 손실이 아니라 이른 턴의 가정에 매여 회복하지 못하는 것). devbrew 파이프라인은
interview → brainstorming → writing-plans → 구현으로 며칠이 가고, 넷이 어긋나면 각 단계가
그 어긋남을 **증폭**시킨다.

새 세션은 목적이 아니라 그 첫 턴이 **진짜 첫 턴이 되게 하는 수단**이다 — 컨텍스트가 비어
있어야 그 메시지가 세션의 전부가 된다.

이 증폭은 이 설계를 만드는 대화에서 실제로 관측됐다. 넷이 안 맞은 채 열 몇 턴을 썼고,
매 턴 저자는 실행 세부를 썼고 사용자는 그게 아니라고 답했다. §10 이 그 기록이다.

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

금지 패턴 *Unbounded autonomy* 와 충돌하지 않는다. 그 조항이 겨냥하는 것은 **사용자 없이 도는
루프**다. 질문 루프는 매 반복마다 사용자가 답해야 돌고, 사용자가 그 루프의 시계다. 자율이
없으므로 묶을 자율도 없고, 나가는 문은 게이트 4옵션이다.

삭제는 식별자가 아니라 개념 별칭 전체로 훑는다: `probe_budget` · `probe_count` ·
`probe_cap_override` · `effective_cap` · `raise-cap` · C1 escalation 3옵션 ·
`DEVBREW_SPEC_DISTILL_PROBE_CAP` · `test_probe_budget.sh` · state 스키마 필드 · 마이그레이션
승격 규칙.

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

---

## 4. 압축 규약

`plugins/spec-distill/references/compression.md` 에 둔다. `proceed-gate.md` 와 같은 자리,
같은 패턴이다 — 채택자를 **열거하지 않고 정본을 가리키는 포인터에서 도출**한다. 채택자는
`framing-requests`(seed)와 `conducting-interview`(brief)이고, 셋째가 생기면 같은 요구를
자동으로 받는다.

계약:

> **payload 는 압축의 결과이고, 압축에서 떨어진 모든 것은 audit 에 남는다.**
>
> **불변량** — 의도 · steering · 방향 · goal, 그리고 그 넷을 지탱하는 사실 중 **에이전트가 알
> 수 없는 것**. 넷을 지탱해도 에이전트가 이미 아는 사실이면 깎인다.
>
> **깎이는 것** — 자명한 것 · 하류 단계가 정할 수 있는 것 · 읽으면 아는 것 · 출처(URL) ·
> 과정과 절차 · 상시 규칙(`CLAUDE.md`·`AGENTS.md` 에 이미 있는 것).
>
> **상한을 두지 않는다** — 확산에도 분량에도. 짧음은 상한이 아니라 뺄셈의 결과다.
>
> **메시지형 payload 에는 존재 검사를 두지 않는다.** 존재 검사가 payload 를 양식으로 만든다.
> 문서형 payload 는 절 존재 검사를 가질 수 있되 **확산물 절을 요구해서는 안 된다** — 그것이
> 확산물을 payload 로 끌어들이는 경로다. 어느 쪽이든 압축 불변량은 부재 검사로 지킨다.
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

### 5.2 interview-brief 재구조화

현재 payload 27,458자, audit 8,850자로 **payload 가 audit 의 3배**다. 확산의 산물이
압축물보다 커야 하는데 반대다. 원인은 규약 부재가 아니라 **게이트 배치**다 — 15검사와
bijection 3종과 `check_verbatim_coverage.py` 가 전부 payload 를 대상으로 삼으니 검증하고
싶은 것이 전부 payload 로 끌려왔다. **검증 대상과 인계 대상이 같은 파일이면 검증이 인계물을
부풀린다.**

payload 절이 불변량에서 도출된다. 8절에서 5절로 줄인다.

| 새 payload | 담는 것 |
|---|---|
| §0 한눈에 | 압축의 정점 |
| §1 의도 · goal | 왜 하는가 · 무엇이 참이면 끝인가 · non-goal |
| §2 방향 · steering | 어디로 가고 어디로 안 가는가 · 갈림길에서 어느 쪽 · 버린 방향과 이유 한 줄 |
| §3 아직 안 정해진 것 | Open Questions |
| §4 다음 단계 | |

audit 으로 이관되는 확산물(현 payload 의 68%):

| 옮기는 것 | 현재 크기 |
|---|---|
| §6 사용자 원문 — 확산의 원재료 그 자체 | 5,291 |
| §5 steelman 원문 · blind spot 24건 | 4,584 |
| §4 External Landscape 21건 + URL | 3,753 |
| frontmatter `user_sourced_items` 30건 원장 | 5,047 |

압축 후 payload 는 4천에서 6천 자, audit 은 2만 7천 자가 된다.

**최초 요청 원문 보존** — 지금 `finishing.md` 는 §6 를 `user_statements` 에서만 채우고
`$ARGUMENTS`(최초 요청)는 거기 들어가지 않는다. 게이트 15항 어디에도 원문 보존 요구가 없고,
지금까지 보존된 것은 관례였다. 이 재구조화에서 **audit 원문 절에** 보존을 요구로 넣는다.

---

## 6. P23 — Decisions Stay Refutable

### 6.1 원칙

devbrew 전체에 적용되는 신규 원칙이다. `docs/philosophy/devbrew-harness-philosophy.md` 에
다음 형식으로 넣는다.

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

### 6.2 집행 위치

지금 이 규약은 `finishing.md` B-3 의 **`/compact` 명령문 안 문장**으로만 산다. 즉 사용자가
`/compact` 를 실제로 실행해야만 다음 세션에 전달되고, 게이트를 지나지 않는 경로에서는
사라진다.

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
| `references/compression.md` | 압축 규약(shared). 채택자는 포인터에서 도출 |
| `commands/request-framing.md` | kill switch + trivia escape + skill 호출. `interview.md` 와 같은 크기 |
| `skills/framing-requests/SKILL.md` | 확산 후 압축 절차. `proceed-gate.md`·`compression.md` 채택 |
| `agents/seed-critic.md` | `tools: []`. 초안 + 원문 + 레포 `CLAUDE.md` 전문 inline |
| `agents/seed-readback.md` | `tools: []`. seed 만. 판정은 사용자 |
| `templates/interview-seed-template.md` | **예시와 쓰지 말 것.** 양식이 아니다 |
| `templates/interview-seed-audit-template.md` | 원문 · 질문 전체 · 긴 초안 · 비평과 냉독 · degrade |
| `scripts/check_seed.py` | 부재 검사 넷 |
| `references/trivia-escape.md` | 5패턴 정의를 빼내 두 command 가 포인터로 가리킨다 |
| `tests/*` | §8 |

`seed-critic` 과 `seed-readback` 을 나눈 것은 도구가 아니라 **입력** 때문이다. critic 은 원문과
`CLAUDE.md` 에 대조해야 해서 셋을 다 받고, readback 은 아무것도 모른 채 seed 만 받아야 측정이
성립한다. 합치면 readback 이 원문을 알게 되어 "seed 만 읽고 알 수 있나" 를 더 이상 재지 못한다.

### 7.2 고치는 것

| 파일 | 무엇 |
|---|---|
| `templates/interview-brief-template.md` | 8절에서 5절로 |
| `templates/interview-audit-template.md` | 확산물 전량 수용 + 출처 절 신설 |
| `scripts/check_brief.py` | 절 목록 변경 · §4·§5·§6 검사를 audit 대상으로 · **URL 금지(뒤집기)** · §4 라벨 검사 · §3 URL 금지 · §5 verdict URL 요구 제거 |
| `scripts/check_verbatim_coverage.py` | 대상을 payload §6 에서 audit 원문 절로 |
| `agents/brief-critic.md` | ground truth 가 audit 으로 옮겨가므로 **audit 원문도 inline** 으로 받는다 |
| `agents/steelman-builder.md` · `blind-spot-prober.md` · `brief-direction-reviewer.md` | `evidence[].url` 을 audit 행으로. 외부 근거는 결정을 만들지 않는다는 한 줄 추가 |
| `scripts/brief-codex-direction-checklist.md` | URL 인용을 audit 대상으로 |
| `skills/conducting-interview/SKILL.md` | R1 을 `Problem Reframe` 으로 · 탐색 경계 · seed 입력 처리 · 압축 규약 채택 · **probe cap 제거** |
| `skills/conducting-interview/references/finishing.md` | 절 구성 · 원문 보존 · 압축 단계 |
| `commands/interview.md` | seed 아닌 입력에 조언 한 줄. 차단 아님 |
| `scripts/probe_budget.py` | **삭제**(별칭 스윕) |
| `scripts/brief_review_state.py` | `--ledger-key` 인자(기본값 유지) |
| `scripts/run_brief_codex_reviewer.sh` | `suppression` 축 추가 — 업그레이드 전용 |
| `tests/test_proceed_gate_adopters.sh` | 역방향 도출 추가 |
| `README.md` · `CHANGELOG.md` · `plugin.json` | flow · bump |

agent 3종과 persona 파일 편집은 CLAUDE.md 기준 **보안-민감 변경**으로 다룬다.

### 7.3 만들지 않는 것

profile 표 · adapter · target 별 delta · seed 스키마 · 슬롯 존재 검사 · bijection · 커버리지
원장 파일 · 분량 상한 · 질문 상한 · open·추론·외부 태그 · seed 안의 URL.

---

## 8. 검증

### 8.1 게이트

| | seed | brief |
|---|---|---|
| 존재 검사 | **없음**(본문이 비어 있지 않음만) | §0 에서 §4 까지 절 존재. 문서형이라 허용 |
| 부재 검사 | 답-슬롯 헤딩 · 태그 · URL | payload URL · 확산물 잔존 |

`check_seed.py` 가 재는 넷: 원문이 audit 에 보존됐고 비어 있지 않다 / 답-슬롯 헤딩(미해결 질문
목록 · 대안 목록 · 인수 조건 초안 · 기각 목록)이 없다 / 태그가 0개다 / URL 이 0개다.

**금지 조항** — `check_seed.py` 에 seed 본문의 **존재 검사를 추가하지 않는다.** 그것이 이
게이트가 양식으로 변질되는 유일한 경로다.

`landscape_uncited()` 를 "URL 없으면 red" 에서 "URL 있으면 red" 로 뒤집으면 순수 부재 검사가
되어 §4 를 통째로 비워도 통과한다. **양성 짝 둘**을 함께 둔다: §4 에 항목 1건 이상 + 각 항목에
`[취함|피함|중립]` 라벨 / audit 에 대응 출처 절 존재. 라벨 목록은 코드에 박지 않고 템플릿에서
읽어 두 곳 drift 를 막는다.

### 8.2 락과 mutation

| 락 | mutation |
|---|---|
| `test_check_seed.sh` | 검사 하나를 코드에서 지우면 해당 RED 가 GREEN |
| `test_request_framing_command.sh` | trivia escape · kill switch · dispatch 각각 삭제 시 RED |
| `test_seed_agents.sh` | `tools: []` 를 `tools: Read` 로 바꾸면 RED |
| `test_no_url_in_payload.sh` | URL 검사 삭제 · §4 비움 · audit 출처 절 삭제 — **셋 다 RED** |
| `test_compression_adopters.sh` | 규약 채택자 도출 + 각자 표면의 압축 어휘 |
| `test_proceed_gate_adopters.sh` 강화 | 아래 |

**OQ3 해소** — 현재 이 테스트는 정본을 가리키는 skill 집합 **A** 를 구해 `|A| >= 2` 와 각
원소의 앵커를 본다. `framing-requests` 가 셋째 채택자가 되는 순간, 진짜 채택자가 포인터를
잃고 새 채택자가 대신 등록되는 치환이 `|A| = 2` 를 유지하며 통과한다(오늘 그것이 RED 인 것은
대체 후보가 정지 어휘를 0줄 가진 우연이다).

**추가 단언**: 정지 어휘(`턴 종료` · `다음 턴`)를 가진 skill 집합 **B** 를 구해 **A 와 B 가
같은 집합**임을 단언한다. 포인터만 잃으면 B 에는 있고 A 에는 없어 RED 가 된다. 존재 검사를
지배관계로 바꾸는 것이고, 열거하지 않으므로 넷째 채택자도 자동으로 삼킨다.

**네 번째 앵커** — 각 채택자가 자기 표면에 **재결정 규약**(P23)을 갖는가. 코퍼스 규칙(정본은
스캔 대상 아님)이 그대로 적용된다.

### 8.3 회귀

측정된 값이다. 테스트 픽스처 154개 중 62개가 §4 를 갖고 그중 **59개**가 §4 안에 URL 을 갖는다.
`docs/` 의 기존 brief 4건도 같다. URL 요구는 코드와 문서 **11곳**에 박혀 있고 그중 둘이 게이트
코드다.

워크트리 baseline 은 **61 pass · 1 fail** 이고 그 1건(`test_hook_output_schema` cross-resolver)은
선재 실패다. 착수 전 다시 캡처하고, 그 1건은 건드리지 않는다.

---

## 9. PR 분해

| | 내용 | 버전 |
|---|---|---|
| **PR0** | P23 신설 — philosophy · CLAUDE.md · `proceed-gate.md` 재결정 규약 승격 · 채택자 앵커 | `0.34.0` |
| **PR1** | `compression.md` 신설 · payload URL 제거 · 상한 전면 삭제 | `0.35.0` |
| **PR2** | brief 재구조화 8절에서 5절로 · 확산물 audit 이관 · 원문 보존 · 게이트 재조준 · `brief-critic` 입력 확대 · 픽스처 마이그레이션 | `0.36.0` |
| **PR3** | request-framing 본체 | `0.37.0` |
| **PR4** | 연결 — R1 재정의 · 탐색 경계 · seed 입력 규약 · `/interview` 조언 · OQ3 락 · README | `0.38.0` |

PR0 이 맨 앞인 이유는 뒤 PR 들이 전부 확정을 재결정하기 때문이다 — 규약이 먼저 서 있어야 그
재결정들이 규약을 따르는 것이 된다. `main` 에서 분기, merge commit, 각 PR 같은 커밋에서 bump.

---

## 10. 재결정 기록

P23 에 따라, 이 설계가 뒤집은 brief 확정 항목을 근거와 함께 남긴다. 조용히 덮어쓰지 않는다.

| 항목 | 원래 | 재결정 | 근거 |
|---|---|---|---|
| C3 | codex 가 단독 비평자 | 역할 슬롯 — 격리 agent 가 기본, codex 는 업그레이드 | codex 미가동 실측 |
| C24 | 실행 대상 감지 + profile adapter | 폐기. 대상은 하나 | 대상이 하나면 추상화가 값을 하지 않는다 |
| C1 | 소비자 중립 **스키마** + 확장점 | 스키마를 두지 않음 | 산문이 가장 중립적이다 |
| C14 | confirmed·inferred·open 구분을 seed 에 명시 | 범주가 ship 시점에 비어 무의미 | 전문을 사용자가 확정하므로 전부 사용자 결정 |
| C29 | Phase 0 외부탐색이 컨텍스트 공백 담당 | 경계는 유지하되 framing 몫이 0 | 공백은 사용자에게 물어 메운다 |
| C2 | 미확정을 `open` **라벨**로 표시 | 라벨 없이 말로 쓴다 | 태그 전면 삭제 |

C9(원문의 "`/interview` 를 좁혀라" 기각)이 만든 선례를 따른다 — 원문 지시가 조용히
증발하지 않게 기각을 명시한다.

---

## 11. 남은 것

정직하게 적는다.

| | |
|---|---|
| **seed 에서 interview 로의 인계 규약** | 태그 없는 seed 가 도착했을 때 `user_sourced_items` 를 어떻게 채우나. 기존 게이트의 동작 변경이다. PR4 에서 정의 |
| **"수정" 의 정의** | 게이트 3번 선택지가 재취조 · 재깎기 · 직접편집 중 무엇인가. 실무에서 가장 자주 밟히는 경로인데 미정의다. PR3 에서 정의 |
| **seed 와 인터뷰 중 새 발화의 우선순위** | 확정된 seed 를 인터뷰 중 사용자가 뒤집으면 어느 쪽이 이기나. P23 이 방향은 주지만 규칙은 없다 |
| **깎기의 기준선** | "누구에게 자명한가" 는 모델 릴리스마다 움직인다. 규칙이 없고, 이것이 seed 길이를 정하는 유일한 레버다 |
| **효과 측정** | C12 로 측정하지 않는다. 이 단계를 제거하게 만들 관측은 정해지지 않았다 |
| **codex 축** | 이 계정에서 한도가 소진돼 실행 검증이 불가능하다. 코드는 들어가되 돌려본 적 없는 상태로 ship 된다 — C10 대로 그것이 미루는 이유는 되지 않는다 |
| **`shared/codex` 의 오분류** | `codex_findings_to_yaml.py` 가 quota 를 인증 오류로 분류한다. 이 설계의 범위 밖이므로 별도 이슈로 남긴다 |
| **세 단계 질문 중복** | 라우팅 규칙은 기계적이지만 경계 판단은 모델이 한다. 줄이지 제거하지 못한다 |
