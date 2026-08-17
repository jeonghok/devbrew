---
name: comprehension-debt-plugin
type: interview-brief
created_at: 2026-08-02
session_id: a1797a3f-270e-402b-a47f-1eaaacf55d38
source: spec-distill conducting-interview v0.24.4
next_phase: superpowers:brainstorming
audit_file: 2026-08-02-comprehension-debt-plugin-interview.audit.md
user_sourced_items:
  - id: C1
    source: chosen
    status: provisional
    statement: "설명은 대화창에 실시간으로 나가되 대화창은 표시 계층이고 내용의 정본은 파일에 남는다"
    evidence: S26
  - id: C2
    source: verbatim
    status: provisional
    statement: "설명 지점은 명령 이름이 아니라 작업 흐름상 의미가 바뀌는 순간이다"
    evidence: S2
  - id: C3
    source: verbatim
    status: confirmed
    statement: "사용자에게 결정을 요청하기 직전 설명은 반드시 필요하다"
    evidence: S2
  - id: C4
    source: chosen
    status: provisional
    statement: "필수 순간: 판정 직후 · 다른 에이전트 결과 도착 · 도구 부재로 능력 저하 · 긴 작업 착수 직전 · 작업 종료"
    evidence: S23
  - id: C5
    source: verbatim
    status: provisional
    statement: "분류는 devbrew 내부 구조 관점이 아니라 사용자 UX 관점으로 도출한다"
    evidence: S3
  - id: C6
    source: verbatim
    status: provisional
    statement: "프로젝트 내 원장을 compound와 llm wiki로 관리하되 stale되지 않게 계속되어야 부채가 안 쌓인다"
    evidence: S4
  - id: C7
    source: verbatim
    status: provisional
    statement: "직전 발화 S4 전체(원장·compound·llm wiki 구상 포함)는 이번 작업의 주 컨텍스트가 아니다"
    evidence: S5
  - id: C8
    source: verbatim
    status: provisional
    statement: "S6에서 기각한 부분을 철회한다"
    evidence: S26
  - id: C9
    source: verbatim
    status: confirmed
    statement: "문제는 전문용어를 몰라서가 아니라 프로젝트가 만들어낸 용어다"
    evidence: S6
  - id: C10
    source: chosen
    status: provisional
    statement: "이해부채는 4겹 복합: 미공유 작업 · 기각 과정 비가시 · 누적 · 설명이 사용자 언어가 아닌 내 언어로 나감"
    evidence: S24
  - id: C11
    source: verbatim
    status: confirmed
    statement: "내가 생각하는 건 '인지부채'보다 '이해부채'에 가깝다"
    evidence: S12
  - id: C12
    source: verbatim
    status: confirmed
    statement: "결핍의 정체는 속도 불일치 — 이해 속도 < 진행 속도, 그리고 subagent 간 대화가 표면에 안 나옴"
    evidence: S13
  - id: C13
    source: verbatim
    status: confirmed
    statement: "빠르게 현황을 이해하는 것이 필요하다"
    evidence: S13
  - id: C14
    source: verbatim
    status: provisional
    statement: "오히려 초반에 잡았던 방향에 가깝다고 보인다"
    evidence: S14
  - id: C15
    source: verbatim
    status: confirmed
    statement: "성공 기준을 바꾸는 것은 잘못된 방향이다"
    evidence: S16
  - id: C16
    source: chosen
    status: confirmed
    statement: "적용 범위는 모든 작업 — 플러그인 밖까지 포함한다"
    evidence: S25
  - id: C17
    source: chosen
    status: confirmed
    statement: "목표는 기존 플러그인 내장이 아니라 이해부채를 관리하는 플러그인을 만드는 것이다"
    evidence: S18
  - id: C18
    source: verbatim
    status: confirmed
    statement: "그 플러그인은 project-init의 확장이 된다"
    evidence: S19
  - id: C19
    source: verbatim
    status: confirmed
    statement: "스코프는 큰 범위로 잡되 대상은 devbrew로 한다"
    evidence: S20
  - id: C20
    source: verbatim
    status: confirmed
    statement: "억제가 되면 안 된다"
    evidence: S20
  - id: C21
    source: verbatim
    status: confirmed
    statement: "토큰 비용이 설계 제약이다"
    evidence: S20
  - id: C22
    source: chosen
    status: provisional
    statement: "빠짐없음에 확신 못 하는 지점·리뷰어 간 불일치·근거가 약한 곳을 1급 항목으로 포함한다"
    evidence: S26
  - id: C23
    source: chosen
    status: provisional
    statement: "다음 단계에서 output style·statusline·subagentStatusLine·검사 없는 훅을 비교하고 내장 Explanatory를 무료 baseline으로 잰다"
    evidence: S26
  - id: C24
    source: verbatim
    status: confirmed
    statement: "원장에 대한 것에 집착하지 말 것"
    evidence: S10
  - id: C25
    source: chosen
    status: provisional
    statement: "원장은 각 작업 단위에서 설명이 실제로 나갔는가만 추적하는 얇은 장치다"
    evidence: S22
  - id: C26
    source: verbatim
    status: confirmed
    statement: "초반의 방향이 정답은 아니다"
    evidence: S15
  - id: C27
    source: verbatim
    status: confirmed
    statement: "읽기 편하고 구조적인 포맷을 만들어서 설명해야 하며 설명은 반드시 해야 한다"
    evidence: S27
  - id: C28
    source: verbatim
    status: confirmed
    statement: "표준 용어를 쓰고 프로젝트만의 용어를 지양하며 처음 보는 사람도 이해할 수 있고 이상한 비유를 금지한다"
    evidence: S27
  - id: C29
    source: verbatim
    status: confirmed
    statement: "모든 작업 단위를 파악해 어디에 설명해야 하는지 표로 보고한다"
    evidence: S27
  - id: C30
    source: verbatim
    status: confirmed
    statement: "설명 시점은 수행 전 · 수행 뒤 · 혹은 중간이다"
    evidence: S27
---

# 이해부채 관리 플러그인 — Interview Brief

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming 해답공간으로
> 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다. 텔레메트리는 `audit_file`에 있다.

## 목차

- [0. 한눈에](#0-한눈에)
- [1. Goal · Non-goal](#1-goal--non-goal)
- [2. 제약](#2-제약)
- [3. Open Questions](#3-open-questions)
- [4. External Landscape](#4-external-landscape)
- [5. 기각 · Blind Spots](#5-기각--blind-spots)
- [6. 사용자 원문](#6-사용자-원문)
- [7. Next Action](#7-next-action)

## 0. 한눈에

**무엇** — 이해부채(comprehension debt)를 관리하는 플러그인을 만든다. `project-init`의 확장 형태이며,
적용 폭은 넓게 잡되 **대상은 devbrew**다(C19).

**왜** — 사용자가 이해하는 속도보다 작업이 진행되는 속도가 빠르고, subagent 간 대화가 대화창에
드러나지 않는다. 그래서 판단을 요구받는 시점에 판단할 재료가 없고, 방향을 잘못 고르게 된다.

**사용자가 답한 것 (전부 잠정 — 확정은 사용자 최종 확인으로만)** — 대화창은 표시 계층이고 내용의
정본은 파일(C1) · 지점은 명령이 아니라 의미 순간(C2) · 결정 요청 직전은 필수(C3) · 성공 기준을 바꾸는
것은 잘못된 방향(C15)이며 "빠짐없음"에 불확실·불일치·약한 근거를 포함(C22) · S6의 grep 검사 기각은
철회되어 집행 후보가 다시 열림(C8) · 억제 금지(C20) · 토큰 비용이 제약(C21) · 용어는 이해부채에 가까움(C11).

**열려 있는 것** — 집행 수준(OQ1) · subagent 표면화 범위와 플랫폼 기능과의 차집합(OQ2) · 정본 파일의
형태(OQ3) · 조어 처리 지침(OQ4) · 순간별 템플릿(OQ5) · 배치(OQ6) · 재귀 경계(OQ7) · 유출 경계(OQ8) ·
진행 중·방향 전환 검출(OQ9) · **원장의 스코프(OQ10)**.

**다음** — brainstorming 해답공간. 첫 과제는 **C23의 수단 비교**(output style · statusline ·
subagentStatusLine · 검사 없는 트리거 훅)이며, OQ1의 집행 수준은 그 비교 결과에 종속된다.

## 1. Goal · Non-goal

- **Goal** — 사용자가 **짧은 시간에 현황을 파악**할 수 있게 만드는 플러그인. 7개 의미 순간에서
  빠짐없는 설명이 나가되, 형식(표·고정 위치·계층)으로 읽는 시간을 줄인다.
- **Goal** — subagent가 무엇을 했고 무엇을 근거로 말했는지가 대화창 표면에 나오게 한다.
- **Non-goal** — 설명의 **총량**을 늘리는 것. 성공은 길이가 아니라 빠짐없음 + 형식으로 달성한다.
- **Goal** — 집행 장치의 후보를 닫지 않는다. C8 철회로 결정론적 검사·검사 없는 트리거 훅·테스트타임
  회귀 락이 **전부 OQ1 후보**다. 억제 금지(C20)는 여전히 상한으로 남는다.
- **Non-goal** — 성공 기준을 속도로 교체하는 것. 생략을 정당화하므로 금지(C15).
- **Non-goal** — 기존 플러그인에 규칙을 **내장**하는 것. 목표는 이해부채를 관리하는 플러그인을 새로
  만드는 것이다(C17). 이는 **산출물 형태**에 대한 것이며 적용 범위와 무관하다 — 적용 범위는 모든
  작업이고(C16), 그 메커니즘 후보는 S25가 말한 전역 규칙이다.
- **Non-goal** — 하니스를 무겁게 만들어 모델 능력을 억제하는 것(C20).
- **제약** — 설명 자체가 출력 토큰을 쓴다. 토큰 비용이 설계 제약이며(C21), 이는 "빠짐없음"을
  포기하라는 뜻이 아니라 **압축된 구조**로 달성하라는 뜻이다.

## 2. 제약

- ☑ provisional **C1** — 설명은 대화창에 실시간으로 나가되 대화창은 표시 계층이고 내용의 정본은 파일에 남는다 ⟨S26⟩
- 🗣 provisional **C2** — 설명 지점은 명령 이름이 아니라 작업 흐름상 의미가 바뀌는 순간이다 ⟨S2⟩
- 🗣 confirmed **C3** — 사용자에게 결정을 요청하기 직전 설명은 반드시 필요하다 ⟨S2⟩
- ☑ provisional **C4** — 필수 순간: 판정 직후 · 다른 에이전트 결과 도착 · 도구 부재로 능력 저하 · 긴 작업 착수 직전 · 작업 종료 ⟨S23⟩
- 🗣 provisional **C5** — 분류는 devbrew 내부 구조 관점이 아니라 사용자 UX 관점으로 도출한다 ⟨S3⟩
- 🗣 provisional **C6** — 프로젝트 내 원장을 compound와 llm wiki로 관리하되 stale되지 않게 계속되어야 부채가 안 쌓인다 ⟨S4⟩
- 🗣 provisional **C7** — 직전 발화 S4 전체(원장·compound·llm wiki 구상 포함)는 이번 작업의 주 컨텍스트가 아니다 ⟨S5⟩
- 🗣 provisional **C8** — S6에서 기각한 부분을 철회한다 ⟨S26⟩
- 🗣 confirmed **C9** — 문제는 전문용어를 몰라서가 아니라 프로젝트가 만들어낸 용어다 ⟨S6⟩
- ☑ provisional **C10** — 이해부채는 4겹 복합: 미공유 작업 · 기각 과정 비가시 · 누적 · 설명이 사용자 언어가 아닌 내 언어로 나감 ⟨S24⟩
- 🗣 confirmed **C11** — 내가 생각하는 건 '인지부채'보다 '이해부채'에 가깝다 ⟨S12⟩
- 🗣 confirmed **C12** — 결핍의 정체는 속도 불일치 — 이해 속도 < 진행 속도, 그리고 subagent 간 대화가 표면에 안 나옴 ⟨S13⟩
- 🗣 confirmed **C13** — 빠르게 현황을 이해하는 것이 필요하다 ⟨S13⟩
- 🗣 provisional **C14** — 오히려 초반에 잡았던 방향에 가깝다고 보인다 ⟨S14⟩
- 🗣 confirmed **C15** — 성공 기준을 바꾸는 것은 잘못된 방향이다 ⟨S16⟩
- ☑ confirmed **C16** — 적용 범위는 모든 작업 — 플러그인 밖까지 포함한다 ⟨S25⟩
- ☑ confirmed **C17** — 목표는 기존 플러그인 내장이 아니라 이해부채를 관리하는 플러그인을 만드는 것이다 ⟨S18⟩
- 🗣 confirmed **C18** — 그 플러그인은 project-init의 확장이 된다 ⟨S19⟩
- 🗣 confirmed **C19** — 스코프는 큰 범위로 잡되 대상은 devbrew로 한다 ⟨S20⟩
- 🗣 confirmed **C20** — 억제가 되면 안 된다 ⟨S20⟩
- 🗣 confirmed **C21** — 토큰 비용이 설계 제약이다 ⟨S20⟩
- ☑ provisional **C22** — 빠짐없음에 확신 못 하는 지점·리뷰어 간 불일치·근거가 약한 곳을 1급 항목으로 포함한다 ⟨S26⟩
- ☑ provisional **C23** — 다음 단계에서 output style·statusline·subagentStatusLine·검사 없는 훅을 비교하고 내장 Explanatory를 무료 baseline으로 잰다 ⟨S26⟩
- 🗣 confirmed **C24** — 원장에 대한 것에 집착하지 말 것 ⟨S10⟩
- ☑ provisional **C25** — 원장은 각 작업 단위에서 설명이 실제로 나갔는가만 추적하는 얇은 장치다 ⟨S22⟩
- 🗣 confirmed **C26** — 초반의 방향이 정답은 아니다 ⟨S15⟩
- 🗣 confirmed **C27** — 읽기 편하고 구조적인 포맷을 만들어서 설명해야 하며 설명은 반드시 해야 한다 ⟨S27⟩
- 🗣 confirmed **C28** — 표준 용어를 쓰고 프로젝트만의 용어를 지양하며 처음 보는 사람도 이해할 수 있고 이상한 비유를 금지한다 ⟨S27⟩
- 🗣 confirmed **C29** — 모든 작업 단위를 파악해 어디에 설명해야 하는지 표로 보고한다 ⟨S27⟩
- 🗣 confirmed **C30** — 설명 시점은 수행 전 · 수행 뒤 · 혹은 중간이다 ⟨S27⟩

✎ 모델 추론(사용자 발화 아님): C21(토큰 비용)과 §5의 첫 번째 위험(설명 과다 시 역효과)은 같은
방향을 가리킨다 — 둘 다 "빠짐없되 압축된 구조"를 요구한다. C15(기준은 빠짐없음)와 충돌하지
않는다: 요구되는 것은 생략이 아니라 압축이다.

✎ 모델 추론(사용자 발화 아님) — **의미 순간 표 7행.** 이 표는 모델이 조립한 것이며 제약이 아니다.
사용자는 이 표에 "ok"라고만 응답했고(S17), "빠진 순간이 없다"는 판정은 모델이 그 응답에 붙인
해석이다. C4가 담은 것은 이 중 **5행**(사용자가 S23에서 고른 A·B·C)이고, 1행은 C3(결정 요청 직전,
S2에서 별도 확정), 나머지 1행(진행 중)은 사용자가 고르지 않았고 검출 방법을 되물었다(OQ9).

| 순간 | 반드시 들어갈 것 (빠짐없음) | 형식 (빨리 읽히게) | 출처 |
|---|---|---|---|
| 결정 요청 직전 | 지금 묻는 것 / 왜 이 선택지들인지 / 버린 것과 그 이유 | 고정 3줄 | C3 ⟨S2⟩ |
| 판정 직후 | 판정 / 근거 / 본 범위 / 못 본 범위 | 표 1행 | C4 ⟨S23⟩ |
| 다른 에이전트 결과 도착 | 누가 / 무엇을 찾았나 / 근거 위치 / 내 판단에 미치는 영향 | 표 | C4 ⟨S23⟩ |
| 긴 작업 도는 중 | 지금 몇 번째 / 무엇 하는 중 | 1줄 | **미선택 — OQ9** |
| 도구 부재로 능력 저하 | 무엇이 빠졌나 / 결과에 미치는 영향 | 1줄 | C4 ⟨S23⟩ |
| 긴 작업 착수 직전 | 할 일 목록 / 단계 수 | 목록 | C4 ⟨S23⟩ |
| 작업 종료 | 바뀐 것 / 남은 것 / 다음 | 3줄 | C4 ⟨S23⟩ |

✎ 모델 추론: 구조화가 "빠짐없음"과 "빠른 파악"의 트레이드오프를 없앤다 — 산문은 다 넣으면
느려지지만 표·고정 위치·계층은 다 넣어도 빠르다. 원 요청 S27의 "읽기 편하고 구조적인 포맷"이 이 해법이라는 것은 모델의 해석이다.

✎ 모델 추론(C6의 지위): C6는 S4에서 왔는데 S5가 그 발화 전체를 "주 컨텍스트가 아니다"로 유보했다
(C7). 따라서 C6는 다른 제약과 같은 무게가 아니며, 확정 판단은 사용자에게 달려 있다.

✎ 모델 추론(C8의 귀결): S26의 [C] "S6에서 기각한 부분 철회"가 실제로 무엇을 다시 여는지는 §6에
없다. 모델은 이를 "결정론적 검사가 OQ1 후보로 복권된다"로 해석했고, 그 해석은 OQ1에 적혀 있다.

✎ 모델 추론(C15의 지시 대상): S16이 기각한 "성공 기준을 바꾸는 것"의 구체 내용은 §6에 없다 —
그 직전 모델이 프로즈로 제안한 표("좋은 설명이란: 빠짐없이 충실한 것 → 빨리 파악되는 것")를
가리키며, 그 표는 사용자 발화가 아니라 모델 출력이므로 §6에 없다. 따라서 성공 기준의 본문
"빠짐없이 설명"은 **모델이 정식화한 것**이고 사용자는 그 교체를 거부했을 뿐이다.

✎ 모델 추론(C14의 지시 대상): S14의 "초반에 잡았던 방향"이 구체적으로 무엇인지는 §6에 없다.
모델은 이를 "의미 순간별 설명 + 작업 단위 표"(라운드 1~3에서 조립한 것)로 해석했으나, 이
해석은 사용자 발화가 아니다.

✎ 모델 추론(C10 ④의 '내'): S24 ④의 원문 "설명이 사용자 언어가 아닌 내 언어로 나감"에서 '내'는
그 옵션 문구를 쓴 모델 자신을 가리킨다 — 사용자가 자기 언어를 말한 것이 아니다.

## 3. Open Questions

- **OQ1** — 집행 수준. C8 철회(S21)로 후보가 다시 열렸다: ① 결정론적 검사 ② 검사 없이 자리만 주입하는
  훅(`additionalContext`) ③ 테스트타임 회귀 락 ④ 지침만. 상한은 C20(억제 금지). devbrew 전례:
  `plugins/spec-distill/tests/test_web_sweep_bound.sh`는 ④로 시작했다가 fail-open이 적발돼 ③이 됐다.
  **어느 수준인지 미정 — 유추 금지.**
- **OQ2** — subagent 표면화 범위. **먼저 차집합을 재야 한다** — Claude Code가 이미 subagent 패널 ·
  `/tasks` · per-subagent transcript 파일 · `subagentStatusLine`으로 보여주는 것을 실측하고, 거기서
  안 보이는 것만 스코프로 잡는다. 요약을 누가·언제·어떤 형식으로 만들지도 미정.
- **OQ3** — 정본 파일의 형태. S21 [A]로 "없음" 후보는 제거됐다(파일 정본 확정). 남은 후보:
  ADR형 결정 기록 / 문서 대장 / 이벤트 로그. C6("stale되지 않게 관리")과 정합해야 한다.
- **OQ4** — 프로젝트 조어 처리 지침의 **구체 내용**. C28(표준 용어 사용·프로젝트 조어 지양)이 방향을
  주고 C9가 문제를 규정했으나, 실행 형태가 미정이다: 사용 금지인가, 쓰되 그 자리에서 설명인가,
  표준어 대체 목록을 유지할 것인가. in-repo 선례로 project-init의 용어집 생성기가 있다.
- **OQ5** — 7개 순간별 실제 템플릿. "고정 3줄", "표 1행"의 구체 서식 미확정.
- **OQ6** — 배치. 사용자가 직접 낸 안은 두 가지다: S3의 *"project-init의 이름을 project-manage 나
  이러한 이름으로 변경해서 위치시킬까해"*, 그리고 S4의 선택 근거 *"처음 원장을 만드는 작업부터
  시작하니 이걸 바꾸는게 맞음"*. C18이 그 귀결이다. 다만 두 리뷰어가 순서 역전을 지적했다(메커니즘
  미정 상태의 배치 확정). 독립 플러그인 + project-init 선택적 의존이 대안. 실측: `project-init`
  문자열 1,055회 / 40+ 파일.
- **OQ7** — 재귀 경계. C16의 "모든 작업"이 main agent 워크플로 전체(parent-only)인가, 각 subagent 내부
  순간까지인가. 후자면 발화·분류 비용이 배수로 증폭된다(C21과 충돌).
- **OQ8** — 유출 경계. subagent 근거를 표면화할 때 비밀·도구 입력·내부 출력의 redaction 정책이 없다.
  metadata-only 기본값 + 명시적 reveal이 후보.
- **OQ9** — **"긴 작업 도는 중"과 "방향 전환"의 검출.** 사용자가 S3에서 *"M4는 어떻게 잡을거야"*라고
  직접 물었고(그 라벨은 이후 기각된 모델 조어이므로 여기서는 쓰지 않는다) 그 항목을 고르지도 않았다.
  모델 답: 이름 붙은 분기점(quality-gates의 iter boundary·NEEDS_RESOLUTION·blocked-path routing,
  spec-distill의 steelman switched·verdict 라우팅)은 잡히나, 이름 없는 조용한 전환은 결정론적으로
  못 잡는다 — 절반만 집행 가능. 이 답을 사용자가 수용했는지는 미확인.
- **OQ10** — **원장의 스코프.** C6(원장을 compound·llm wiki로 상시 관리) · C7(그 발화 전체가 주
  컨텍스트 아님) · C24(원장에 집착하지 말 것) · C25(원장은 얇은 추적 장치) · OQ3(정본 파일은 C6과
  정합해야 함)이 서로 당긴다. 냉독 에이전트가 이 지점에서 "원장이 스코프 안인지 밖인지 정리가 안
  됐다"고 보고했다. **원장이 이번 범위에 들어오는지, 들어온다면 얼마나 얇은지가 미정이다.**

## 4. External Landscape

- Comprehension debt — 존재하는 것과 사람이 이해하는 것 사이의 격차, 보이지 않게 누적 — https://addyosmani.com/blog/comprehension-debt/ — [취함] — 사용자가 이 용어를 자기 문제로 확정(C11)
- Comprehension debt (O'Reilly Radar) — 생성 속도와 이해 속도의 불일치가 원인 — https://www.oreilly.com/radar/comprehension-debt-the-hidden-cost-of-ai-generated-code/ — [취함] — C12의 속도 진단과 일치
- Cognitive debt — AI 도구가 개발자 이해 능력을 잠식 — https://virtuslab.com/blog/ai/cognitive-debt-the-code-nobody-understands — [피함] — skill erosion 프레이밍이라 사용자 문제와 다름
- Subagent 불투명성 — 위임된 에이전트가 도는 동안 사용자는 아무것도 못 봄 — https://www.infoworld.com/article/4197328/codex-multi-agent-v2-update-raises-developer-concerns-over-agent-transparency.html — [취함] — C12의 후반부가 업계 공통 이슈임을 확증
- Copilot Mission Control — 끝난 뒤가 아니라 도는 동안 steer — https://github.blog/changelog/2026-03-19-more-visibility-into-copilot-coding-agent-sessions/ — [취함] — 진행 중 개입 선례
- Narrated AI actions / comprehension checkpoint / ADR at decision time — https://stepto.net/blog/comprehension-debt-ai-code-understanding-2026 — [취함] — 기성 처방 3종, OQ3의 후보 근거
- Intent Preview · Plan Summary 패턴 — 행동 전 계획을 먼저 보여주는 대화적 일시정지 — https://www.smashingmagazine.com/2026/02/designing-agentic-ai-practical-ux-patterns/ — [취함] — C3의 표준 패턴명
- Progressive disclosure / alert fatigue — 설명 과다 시 읽지 않고 dismiss — https://dl.acm.org/doi/fullHtml/10.1145/3374218 — [중립] — 경고로 유지하되 기준 교체 근거로는 쓰지 않음(C15)
- Transparency paradox / autonomy depletion — 설명이 임계치 넘으면 성능·통제감 저하 — https://www.aimodels.fyi/papers/arxiv/transparency-paradox-explainable-ai-theory-autonomy-depletion — [중립] — §5 위험으로 박제
- Common ground / Hidden Profile — 한쪽만 가진 정보가 공유되지 않아 잘못된 결정 — https://www.tandfonline.com/doi/full/10.1080/1463922X.2022.2061080 — [취함] — C10의 첫 번째 겹에 표준 이름 제공
- ADR이 대부분 팀에서 포기된 이유는 강제 메커니즘 부재 — https://www.javacodegeeks.com/2026/05/the-reason-most-architecture-decision-records-get-written-and-never-read-is-architectural-not-cultural.html — [취함] — OQ1 위험의 직접 근거
- Grounding Gaps in Language Model Generations — 새 정보가 상대 인지 확인 없이 assert되는 지점 — https://arxiv.org/pdf/2311.09144 — [중립] — steelman 근거, 처방은 기각됐으나 진단은 유효
- plainlanguage.gov — 필요한 전문용어는 최초 사용 시 정의 — https://digital.gov/guides/plain-language/principles/avoid-jargon — [피함] — 이 규칙으로 좁힌 것이 문제 오독이었음(C9)
- **Claude Code output styles** — 매 턴 역할·형식을 바꾸는 1급 surface, 플러그인이 `output-styles/`로 배포·`force-for-plugin` 자동적용, 내장 Explanatory가 무료 baseline, 단 subagent에는 미적용 — https://code.claude.com/docs/en/output-styles — [취함] — C23 비교 대상. devbrew 등장 0회
- **Claude Code statusline / subagentStatusLine** — 다행 고정 렌더 + subagent 행 렌더, 플러그인 settings.json으로 배포, **출력 토큰 0** — https://code.claude.com/docs/en/statusline — [취함] — C21과 직결. devbrew 등장 0회
- **Stop·SubagentStop `additionalContext`** — 검사·차단 없이 자리만 주입하는 훅. 내용은 전적으로 모델이 씀 — https://code.claude.com/docs/en/hooks — [취함] — OQ1 후보 ②의 실재 근거
- **subagent 패널 · `/tasks` · per-subagent transcript 파일** — 플랫폼이 이미 상당 부분 shipping. 외부에 subagent-viewer 등 성숙 도구 — https://code.claude.com/docs/en/sub-agents — [취함] — OQ2의 차집합 기준선
- **CHI 2021 Bansal et al.** — 설명은 추천이 틀렸을 때 성능을 떨어뜨렸고, 단순 confidence 표시 대비 이득이 없었다 — https://arxiv.org/pdf/2006.14779 — [취함] — C22의 직접 근거
- **in-repo 선례 (미사용 자산)** — 용어집 생성기 `plugins/project-init/templates/project/glossary.md` + 코드 안 읽는 독자용 설명을 강제하는 persona `plugins/quality-gates/agents/pr-understanding-builder.md` — https://github.com/jeonghok/devbrew/blob/main/plugins/quality-gates/agents/pr-understanding-builder.md — [취함] — C9의 baseline. devbrew는 용어집 생성기를 배포하면서 자기 용어집이 없다(`docs/project/**` 0건)

## 5. 기각 · Blind Spots

- 기각 — 설명을 **파일에만** 두는 안(대화창 없이) → 사용자가 대화창 실시간 발화를 선택(S1). 단 S21 [A]로 파일 자체는 정본으로 복권됨 — 기각된 것은 "파일만"이지 "파일"이 아니다
- 기각 — 설명 지점을 명령 단위(`/qg`, `/cancel-review` 등)로 잡는 안 → 의미 순간이 아니라서(C2)
- 기각 — "전문용어를 최초 사용 시 정의한다" 규칙 → 문제를 어휘 난이도로 오독한 것(C9)
- ✎ 모델 판단(사용자 기각 아님) — "프로젝트 조어를 표준 용어로 대체하면 문제가 풀린다"는 모델의 2차 오독이었다. 조어는 원인이 아니라 미공유 맥락의 표지이기 때문이다. **다만 "표준 용어를 쓰고 프로젝트만의 용어를 지양한다"는 지시 자체는 사용자 원 요청 S27에 있고 C28로 살아 있다 — 기각된 것은 그 지시가 아니라 "그것만으로 충분하다"는 모델의 가정이다.**
- 기각 — 성공 기준을 "빠짐없이"에서 "빠른 파악"으로 교체 → 생략을 정당화해 원래 병을 처방으로 바꿈(C15)
- 기각 — 모델이 만든 라벨 체계(`L1~L4`, `M1~M8`, `U1~U6`) → 그 자체가 프로젝트 조어를 재생산
- 기각 — C1 원안(대화창에만 두고 파일에 남기지 않음) → compaction 후 사망하여 C6·C10과 동시 성립 불가. 철학 P14 + 이 인터뷰에서 상태 파일이 실제로 조용히 소실된 실증 (S21 [A])
- 기각 — S6의 "grep 검사 금지" 기각 그 자체 → 사용자가 철회 (S21 [C]). 훅 범주 전체를 닫은 것은 사용자 발화가 아니라 저자가 §1에 "훅 grep 등"으로 적은 서술 오류였음
- 기각 — steelman 대안: 원장 폐기 + "첫 등장 시 1줄 정의+출처" **단일 위치 규칙으로 축소** → 사용자가 초반 방향(의미 순간별 설명)이 더 가깝다고 판정(C14). 단 같은 steelman의 **grep 구조검사** 부분은 S6에서 기각됐다가 **S21 [C]로 철회되어 OQ1 후보로 복권**됐다 — https://arxiv.org/pdf/2311.09144 — verdict: defended — ST1
- 위험 — 숨은 가정: "설명을 더 하면 더 이해한다"는 인과가 문헌상 논박됨. 설명이 작업기억 임계치를 넘으면 정확도·신뢰와 무관하게 성능·통제감이 저하되며, 역효과 조건이 이 설계가 가장 돕고 싶어하는 시나리오(긴 세션)에서 가장 크다 — https://www.aimodels.fyi/papers/arxiv/transparency-paradox-explainable-ai-theory-autonomy-depletion
- 위험 — 실패 양식: 결정론적 백스톱 없는 지침은 조용히 drift한다. 새 skill/agent가 추가될 때마다 의무를 놓치는 것이 표준 경로가 되고, 6개월 뒤 "설명이 나오는 지점"과 "조용히 빠진 지점"이 뒤섞여 예측 불가능해진다 — https://www.javacodegeeks.com/2026/05/the-reason-most-architecture-decision-records-get-written-and-never-read-is-architectural-not-cultural.html + devbrew 자체 전례(`plugins/spec-distill/tests/test_web_sweep_bound.sh`)
- 위험 — 실패 양식: rubber-stamp. 설명이 개입 능력과 연결되지 않으면 사용자는 안 읽고 습관적으로 승인만 누르게 되고, 이해부채가 사라진 게 아니라 "읽었다고 표시된 미이해 부채"로 형태만 바뀌어 가짜 감독을 만든다 — https://arxiv.org/html/2601.13973
- 위험 — 실패 양식: 해결책이 문제를 재생산한다. "사용자 언어로 표준화된 설명"을 만들려는 구현이 다시 프로젝트 고유의 템플릿·카테고리 이름을 낳고 그것이 설명 없는 내부 규범이 된다 — 이 인터뷰에서 모델이 `M1~M8`·`U1~U6`로 실증함(codebase 근거)
- 위험 — 숨은 가정: 모델이 "지금이 7개 필수 순간 중 하나인가"를 스스로 정확히 인지할 수 있다는 self-recognition 가정. devbrew 이력상 same-family 모델의 self-review는 자신의 narrate-only 종료를 스스로 잡지 못했고 별-모델 독립 리뷰만 적발했다(codebase 근거, MEMORY.md 이력)
- 위험 — 실패 양식: 설명이 **틀린** 방향의 수용률을 올린다. CHI 2021 실측에서 설명은 추천이 맞을 때 성능을 약간 올렸으나 틀렸을 때는 떨어뜨렸고, 단순 confidence 표시 대비 이득이 없었다. §5 첫 위험(alert fatigue)과 **다른 메커니즘(설득력)**이라 압축으로 해소되지 않으며 매끄러운 설명일수록 강하게 작동한다 — https://arxiv.org/pdf/2006.14779
- 위험 — 저자 편향: 이 brief의 §4 초판은 13건 전부가 개념·논문이었고 shipped surface와 in-repo 선례가 **각각 0건**이었다. 방향성 리뷰 양쪽이 공통으로 지적했으며, 방향이 틀렸다면 원인이 이 조사 편향일 가능성이 크다(위 §4에 6건 보강했으나 편향 자체는 재발 가능)

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S27** 🗣 최초 요청 (`/interview`에 넘긴 원문 — 인터뷰의 출발점):
  > "인지부채 해소를 원장으로 모든곳에 추가, 모든 곳에서 수행을 진행하기 전 그리고 수행을 진행한 뒤, 혹은 중간에(모든 작업 단위를 파악하고 표로 어디에 설명 해야한다고 명시할건지 표로 나에게 보고해) 유저 입장에서 쉽게 이해할 수 있도록(표준 용어를 사용해서, 프로젝트만의 용어 지양, 처음보는 사람도 이해할 수 있도록, 이상한 비유 금지 등 어떻게 인지 부채을 해결할 수 있을지 고민 깊게 하고 지침 세워) 쉬운 형태로 그리고 읽기 편하고 구조적인 포맷을 만들어서 설명해야함. 설명은 반드시 하도록 해"

- **S1** ☑ 선택 (설명이 실제로 사는 곳 = medium):
  > "대화창 발화 중심 (권장) — 작업 전/중/후에 터미널 대화로 사용자에게 직접 설명. 원장은 '각 작업 단위에서 설명이 실제로 나갔는가'만 추적하는 얇은 장치."
- **S2** 🗣 발화 (설명 밀도 질문에 대한 재구성 요구):
  > "훅발화가 언제를 말하는건지 말해줘, 그리고 스펙리뷰 끝나는 경우 설명이 들어가야 겠는데 cancel review가 아니라, 명령단위로 보는거 보다는 더 시멘틱한 거로 봐줘, 그리고 작업 흐름의 관점에서, 일단 ask user question 전에 설명을 잘 해줘야 하는건 확실해 지금과 같이 설명을 잘 못하고 물어보면 인지 부채가 생긴 상황에서 방향을 잘못가니까(에이전트간 대화하거나 맥락으로 숨어있던내용과 단어를(대화창에 안나온 내용) 나에게 갑자기 이야기하는경우 많음)"
- **S3** 🗣 발화 (필수 순간 묶음 선택 + 추가 요구):
  > "A. 판정이 나온 직후 (M2) — 권장, B. 숨은 맥락이 드러날 때 (M3·M8) — 권장, C. 흐름의 시작과 끝 (M6·M7), M4는 어떻게 잡을거야, 그리고 devbrew의 관점이 아니라 사용자 UX관점으로 한번더 보도록 해, 그리고 이 플러그인 위치의 경우 project-init의 이름을 project-manage 나 이러한 이름으로 변경해서 위치시킬까해"
- **S4** 🗣 발화 (플러그인 전환 구상):
  > "해당 플러그인의 전환에 대한 러프한 생각은 아래야 / compound와 llm wiki를 통해 프로젝트내 원장을 관리하는 역할 관리는 stale되지 않게 계속되어야 부채가 쌓이지 않고, 인지부채 해결도 예가 할 수 있게 도움주는 툴 필요(처음 원장을 만드는 작업부터 시작하니 이걸 바꾸는게 맞음)"
- **S5** 🗣 발화 (범위 제한):
  > "일단 이거는 이번 작업의 주 컨텍스트는 아니긴 하니 여기에 끌려다니지는 말고"
- **S6** 🗣 발화 (steelman 판정 + 문제 재정의):
  > "내가 이야기한건 전문용어를 몰라서 설명해달라는게 아니라 프로젝트에서 만들어낸 용어같은걸 말한거야, 이거를 grep으로 검사하고 이렇게 하지는 마 이건 너무 강한 억제 하네스"
- **S7** 🗣 발화 (모델의 2차 재정의도 기각):
  > "아니 문제의 정체도 잘못 이해하고 있어"
- **S8** 🗣 발화:
  > "다시 이해해봐"
- **S9** 🗣 발화 (문제 정체 4겹 전부 선택 + 외부 조사 지시):
  > "보이지 않는 곳의 작업이 공유 안 됨, 판단 근거와 기각 과정이 안 보임, 못 따라간 것이 누적됨 (부채·원장의 본뜻), 설명이 사용자 언어가 아닌 내 언어로 나감, 외부에서 검색해서 좀더 이해를 해보자 인지부채 용어가 아닐수도 있어 요즘 에이전틱 코딩 하는 사람들 사이에 이슈되는 문제야"
- **S10** 🗣 발화:
  > "원장에 대한거에 집착하지 마"
- **S11** 🗣 발화:
  > "뭐를 한다는거에서 집착하는거야?"
- **S12** 🗣 발화 (용어 확정):
  > "내가 생각하는건 이해부채에 가깝네"
- **S13** 🗣 발화 (결핍의 정체):
  > "이러한 상황이 많은데 내가 진행상황과 ask나오는 상황 등에 이해하는 속도보다 진행 속도나 서브에이전트간 대화가 표면에 나오지 않는 등의 문제가 존재 빠르게 현황에 대한 상황을 이해하는게 필요함"
- **S14** 🗣 발화 (방향 복귀):
  > "오히려 초반에 잡았던 방향에 가깝다고 보임"
- **S15** 🗣 발화:
  > "초반의 방향이 정답은 아니지만"
- **S16** 🗣 발화 (기준 교체 기각):
  > "성공 기준을 바꾸는거는 잘못된 방향이야"
- **S17** 🗣 발화 (정정된 표 수용):
  > "ok"
- **S18** ☑ 선택 (적용 범위 + 산출물 형태):
  > "2번, devbrew플러그인에 내장하는게 목표가 아니라 이해 부채룰 관리하는 플러그인을 만드는게 목표"
- **S19** 🗣 발화 (배치):
  > "그게 project-init의 확장이 될거고"
- **S20** 🗣 발화 (스코프 정련 + 새 제약 2건 + 설명 요청):
  > "이어서 진행, 일단은 큰 범위와 devbrew대상으로 스콥을 잡을거야 억제가되면 안되고 토큰 비용도 문제니, 어떻게 작성했는지 이해시켜줘"
- **S21** ☑🗣 방향성 리뷰 C4 재결정 4건 (A·B·D는 선택, C는 발화):
  > "[A] 대화창=표시, 파일=정본 (권장) / [B] 기준 유지 + '빠짐없음'의 정의 확장 (권장) / [C] S6에서 기각한 부분 철회 / [D] 다음 단계에서 반드시 비교 (권장)"

- **S22** ☑ 선택지 전문 — S1이 고른 항목 (질문: "'인지부채 해소 설명'이 실제로 사는 곳(medium)은 어디입니까? 이 답이 '원장'의 정체와 '모든 곳'의 범위를 함께 결정합니다."):
  > 라벨: "대화창 발화 중심 (권장)" / 설명문: "작업 전/중/후에 터미널 대화로 사용자에게 직접 설명. 원장은 '각 작업 단위에서 설명이 실제로 나갔는가'만 추적하는 얇은 장치. 사용자가 읽는 그 순간에 도달하지만, 대화가 끝나면 사라짐."
- **S23** ☑ 선택지 전문 — S3이 고른 A·B·C (질문: "M2~M8 중 설명이 반드시(필수) 나가야 하는 묶음을 골라주세요. 고르지 않은 묶음은 '한 줄 요약만'으로 내려갑니다(생략 아님). M1(결정 요청 직전)은 이미 확정이라 제외했습니다."):
  > A 라벨: "판정이 나온 직후 (M2) — 권장" / 설명문: "스펙 리뷰 종료, 게이트 통과/실패, 감사 결론이 나왔을 때. 직접 언급하신 지점('스펙리뷰 끝나는 경우'). 결론만 통보받고 근거를 모르는 상태를 막음."
  > B 라벨: "숨은 맥락이 드러날 때 (M3·M8) — 권장" / 설명문: "다른 에이전트 결과가 돌아왔을 때 + 도구 부재로 능력이 떨어졌을 때. Hidden Profile이 실제로 발생하는 진원지 — 대화창에 없던 내용·단어가 들어오는 유일한 통로."
  > C 라벨: "흐름의 시작과 끝 (M6·M7)" / 설명문: "긴 작업 착수 직전 '무엇을 할 것인가' + 종료 시 '무엇이 바뀌었고 다음은 무엇인가'. 사용자가 화면에서 어느 정도 볼 수 있어 중복 위험이 있음."
- **S24** ☑ 선택지 전문 — S9가 고른 4개 전부 (질문: "'인지부채'의 정체로 맞는 것을 모두 골라주세요."):
  > ① "보이지 않는 곳의 작업이 공유 안 됨" / "다른 에이전트가 무엇을 찾았는지, 내가 어떤 파일에서 무엇을 알게 됐는지가 대화창에 안 나온 채로 그 결과만 사용자에게 닿는다."
  > ② "판단 근거와 기각 과정이 안 보임" / "결론과 선택지는 주는데, 왜 그 결론인지·무엇을 검토하고 버렸는지·왜 하필 이 몇 개로 좁혔는지가 안 보임. 그래서 선택지 밖을 상상할 수 없음."
  > ③ "못 따라간 것이 누적됨 (부채·원장의 본뜻)" / "한 번씩은 넘어가지만 세션이 길어지면 못 따라간 게 쌓여 나중엔 전체가 불투명해짐. 이 독법이라면 원장은 '설명함'이 아니라 '아직 설명 안 한 것'을 쌓는 미상환 장부."
  > ④ "설명이 사용자 언어가 아닌 내 언어로 나감" / "설명을 하긴 하는데 내가 일하는 방식·내 구조 기준으로 써서, 사용자가 자기 일로 번역해야 함. 설명의 부재가 아니라 시점의 어긋남." (여기서 '내'는 모델 자신 — 옵션 문구를 모델이 썼다)
- **S25** ☑ 선택지 전문 — S18이 고른 2번 (질문: "이 지침이 적용되는 범위는 어디까지입니까? ('모든 곳'의 경계)"):
  > 라벨: "모든 작업 (플러그인 밖 포함)" / 설명문: "CLAUDE.md 전역 규칙으로 두어, 플러그인과 무관하게 이 리포에서 하는 모든 작업에 적용. 커버리지 최대지만, 사소한 작업에도 7개 순간 규칙이 도는 과잉 위험(trivia ceremony)."
- **S26** ☑ 선택지 전문 — S21이 고른 [A]·[B]·[D] ([C]는 자유 입력이라 S21이 원문):
  > [A] 라벨: "대화창=표시, 파일=정본 (권장)" / 설명문: "설명은 여전히 대화창에 실시간으로 나가되, 내용은 파일에도 남아 compaction 후에도 살아남는다. C1을 '파일 금지'가 아니라 '파일만 있는 건 안 된다'로 재해석."
  > [B] 라벨: "기준 유지 + '빠짐없음'의 정의 확장 (권장)" / 설명문: "C15 그대로. 단 '빠짐없음'에 내가 확신 못 하는 지점 · 리뷰어 간 불일치 · 근거가 약한 곳을 1급 항목으로 못박는다. 기준 교체가 아니라 내용 규정."
  > [C] 질문 원문: "S6에서 기각하신 것은 'grep으로 검사하지 마'였는데, 제가 §1에 '훅 grep 등'으로 적어 훅 전체를 닫았습니다. 기각 범위를 어디까지로 볼까요?" — 제시된 선택지는 (검사·차단하는 훅만 기각 / 테스트타임 회귀 락 허용 / 측정만 먼저 / 훅 전체 기각 유지)였고, 사용자는 자유 입력 "S6에서 기각한 부분 철회"로 답했다.
  > [D] 라벨: "다음 단계에서 반드시 비교 (권장)" / 설명문: "output style · statusline · subagentStatusLine · 검사없는 훅을 설계 단계의 후보로 명시하고, 내장 Explanatory 스타일을 무료 baseline으로 잰다. 방향 변경 아니고 후보 추가."

## 7. Next Action

superpowers가 설치돼 있으므로 이 brief를 context로 `superpowers:brainstorming`을 호출해
해답공간 설계로 넘어간다. 순서는 다음과 같다.

1. **C23의 수단 비교** — output style · statusline · subagentStatusLine · 검사 없는 트리거 훅.
   출력 토큰과 도달 범위(subagent 포함 여부)가 비교축이며, 내장 Explanatory가 무료 baseline이다.
2. **OQ2의 차집합 실측** — 플랫폼이 이미 보여주는 것을 재고 나서 남는 것만 스코프로 잡는다.
   이 둘을 먼저 하지 않으면 기성 기능을 재구현하게 된다(방향성 리뷰 공통 지적).
3. **OQ1 집행 수준** — 1의 결과에 종속된다. 후보 4개(결정론 검사 / 검사 없는 훅 / 테스트타임 락 /
   지침만) 중 선택하되 상한은 C20(억제 금지). 여기가 풀리지 않으면 나머지가 조용히 무너진다는 것이
   premortem의 결론이다.
4. 이후 OQ5(템플릿) → OQ3(정본 파일 형태) → OQ7·OQ8(경계) → OQ6(배치) 순. OQ6는 마지막이다 —
   메커니즘보다 배치를 먼저 확정한 것이 이번 리뷰의 지적 중 하나였다.
