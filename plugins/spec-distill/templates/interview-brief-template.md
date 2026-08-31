---
name: <kebab-topic>
type: interview-brief
created_at: YYYY-MM-DD
session_id: <uuid>
source: spec-distill conducting-interview v0.23.0
next_phase: superpowers:brainstorming
audit_file: <YYYY-MM-DD>-<kebab-topic>-interview.audit.md   # basename만 (같은 디렉토리)
# user_sourced_items — **사용자 출처 항목만**. `source: inferred`는 여기 들어갈 수 없다(게이트 fail).
# 모델 추론은 본문 프로즈에 ✎ 표기로만 산다.
# status는 인터뷰 종료 직전 사용자 일괄 확인으로만 confirmed가 된다 — 라운드 중에는 전부 provisional.
# 그래서 brief를 처음 쓰는 시점(Step A)에는 confirmed가 0건이고, 아래 블록 첫 줄의 sentinel이
# 반드시 있어야 게이트를 통과한다. 확정 반영(proceed 게이트 ①/②) 시 그 줄을 같은 write에서 지운다.
# 각 항목의 값 뒤 `# ...`는 YAML 인라인 주석이며 게이트가 값에서 떼어낸다(값의 일부가 아니다).
user_sourced_items:
# confirmed 0건 — 사용자가 전부 잠정으로 판단
  - id: C1
    source: verbatim          # verbatim(발화 그대로) | chosen(선택지 선택)
    status: provisional       # confirmed | provisional | open
    statement: "<C1 제약 한 줄>"   # 모델이 쓴 요약. P21 secret placeholder 치환
    evidence: S1              # 원문 §6(payload 또는 audit)의 어느 발화에서 나왔는가 — 필수
  - id: D2
    source: chosen
    status: provisional
    statement: "<D2 제약 한 줄>"
    evidence: S1              # payload §6엔 S1만 산다 — S2 이상 원문의 evidence는 audit §6 이관
---

# <Topic> — Interview Brief

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming 해답공간으로
> 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다. 텔레메트리는 `audit_file`에 있다.

## 0. 한눈에

(무엇 / 왜 / 무엇이 확정 / 무엇이 열려 있음 / 다음 stage. **이 절은 요약이다** — 본문을 여기
 옮겨 적는 자리가 아니라, 다음 세션이 여기만 읽고도 방향을 잡을 수 있어야 하는 자리다.)

## 1. Goal · Non-goal

- Goal: ...
- Non-goal: ...

## 2. 제약

(이 절의 진술은 모델이 쓴 요약이다. 원문은 payload §6(S1)과 audit §6(S2 이상)에 나뉘어
 있고, `⟨S<N>⟩`가 그중 하나를 가리킨다.
 한 줄이 frontmatter 한 항목의 렌더다 — id·기호↔`source`·`status`·`⟨S<N>⟩`·statement 문구가
 **전부** 일치해야 한다(bijection B). 한쪽만 고치면 게이트가 red를 낸다.)

- 🗣 provisional **C1** — <C1 제약 한 줄> ⟨S1⟩
- ☑ provisional **D2** — <D2 제약 한 줄> ⟨S1⟩

✎ (모델 추론은 이 프로즈 형식으로만. frontmatter 계약 밖이라 게이트 대상이 아니다.)

## 3. Open Questions

(미해결 명시 — "유추 금지". 탐색 대상이므로 앞쪽에 온다.)

- OQ1: ...

## 4. External Landscape

(1항목 = 1줄, **«출처키» 필수** + [취함|피함|중립] + 이유. 그 키가 가리키는 원자료
 URL은 audit `## 7. 확산 원자료`에 선언한다 — payload에는 키만 남는다.)

- ... «example» — [취함] — 이유

## 5. 기각 · Blind Spots

(`기각` 항목이 0건이면 `- 기각 — N/A — 전부 first-time defend+lock` 한 줄 명시(빈 섹션 금지).
 `verdict:`를 가진 항목은 audit §3의 `ST<N>` 참조가 필수다.)

- 기각 — <시도한 방향> → <버린 이유>
- 기각 — <시도한 방향> → <버린 이유> — verdict: defended — ST1
- 위험 — <숨은 가정 | 실패 양식>: <내용> — <근거>

## 6. 사용자 원문

(**`S1` 최초 요청 원문 하나만** 여기 남는다 — 나머지 발화 전량은 audit `## 6. 사용자 원문`에
 append-only로 보존한다. 허용 변환은 P21 placeholder 치환·앞뒤 공백 정리·인용 블록 래핑뿐이며
 요약·재서술·발췌는 금지.)

- **S1** 🗣 최초 요청:
  > "..."

## 7. Next Action

(superpowers 있으면: 이 brief를 context로 `superpowers:brainstorming` 호출 → `-design.md`
 → reviewer 검증 → writing-plans. 없으면: 이 brief가 완결 산출물 — 직접 사용.)
