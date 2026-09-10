---
type: interview-audit
payload: <YYYY-MM-DD>-<kebab-topic>-interview.md
created_at: YYYY-MM-DD
session_id: <uuid>
source: spec-distill conducting-interview v0.57.0
---

# <Topic> — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

(커버리지 원장 직렬화 — floor 5행(전부 closed + evidence) + derived(≥1행 OR N/A sentinel).
 orchestrator가 state.local.md에서 직렬화한다. evidence는 실재 `S<N>` 앵커를 인용해야 한다(AC3).
 아래의 `S1`은 **예시**이며, 실제로는 그 차원의 닫힘을 근거한 실제 `S<N>`으로 — 행마다
 서로 다른 발화로 — 바뀐다.)

- floor:root_problem — closed — <evidence> (@S1)
- floor:landscape — closed — <evidence> (@S1)
- floor:skepticism — closed — <evidence> (@S1)
- floor:blind_spot — closed — <evidence> (@S1)
- floor:open_questions — closed — <evidence> (@S1)
- derived:<name> — closed — <rationale>; <evidence> (@S1)

(재개방된 차원은 행 끝에 «(재개방 <n>회 — <사유>)», 박제는 «사용자-승인 박제(@S<N>) —
 §Open Questions 참조». 모든 closed 행의 evidence 는 실재 S<N> 을 인용한다.)

## 2. Budget

(한 줄. 이 줄의 두 계수는 **다른 것을 센다**: `agent dispatch: <n>` 은 이 인터뷰의 subagent
 dispatch **총계**이고, `coverage-mapper <k>` 는 그중 coverage-mapper **하나만**의 횟수라
 언제나 `<k> ≤ <n>` 이다. 게이트가 보는 것은 후자뿐이며 k≥1이면 통과한다 — dispatch 를 못
 했으면 `coverage-mapper 0 (unavailable: <사유>)`처럼 사유를 붙인다(advisory). 사유 없는 0은
 게이트 red(AC4). 게이트가 읽는 것은 아래 **불릿 줄**뿐이고 이 설명 산문은 판정에 참여하지
 않는다. `<k>` 는 **반드시 실제 횟수로 치환한다** — 템플릿이 통과값을 미리 채워 두면
 dispatch 를 한 번도 안 한 턴이 그대로 옮겨 적어 게이트가 조용히 통과한다. 채우지 않은
 `<k>` 는 게이트 red 다(«coverage-mapper <k> line missing»): 침묵보다 red 가 낫다.)

- 질문 라운드: <n> · agent dispatch: <n> · coverage-mapper <k> · codex 실호출: <n> (성공 <n>)

## 3. Steelman 원문

(steelman-builder 출력 verbatim. payload §5의 `verdict:` 항목이 여기의 `ST<N>`을 참조한다 —
 양방향 일치가 게이트 대상이다. steelman 0건이면 이 절은 비어 있어도 되고 sentinel도 필요 없다 —
 그때 skepticism 폐쇄 기록은 payload §5 의 `검토 —` 항목이다.)

#### ST1 — <한 줄 요지>

**dispatch 입력** — goal: S<N> · 전제: P1 <…>(S<N>) · P2 <…> · 제약: S1–S<N> 원문 전량 · trigger: <…>

> <builder 출력 verbatim — 다단락 가능>

**게이트-전 확인** — repo_claims: <path+anchor> 확인|반증|미확인 … · 부착 주장: <evidence #> → P<n> 확인|반증 … · 재검토 자격: 열림 <k>건 | 사유 없음

**사용자 선택** — <유지|보완|전환|보류> (S<N>) <— 사용자 override(전제 충돌 0), 해당 시>

#### ST2 — <한 줄 요지>

**dispatch 입력** — goal: S<N> · 전제: P1 <…>(S<N>) · P2 <…> · 제약: S1–S<N> 원문 전량 · trigger: <…>

> <builder 출력 verbatim — 다단락 가능>

**게이트-전 확인** — repo_claims: <path+anchor> 확인|반증|미확인 … · 부착 주장: <evidence #> → P<n> 확인|반증 … · 재검토 자격: 열림 <k>건 | 사유 없음

**사용자 선택** — <유지|보완|전환|보류> (S<N>) <— 사용자 override(전제 충돌 0), 해당 시>

## 4. 게이트 실행 기록

- check_brief.py gate — <pass|fail> (<YYYY-MM-DD>) — web: <enabled|disabled>
- check_verbatim_coverage.py — <exit 0|1|3|4> (<YYYY-MM-DD>)

## 5. 프로세스 로그

- round <n>: <path (a|b|d)> — <한 줄 요약>

### brief 리뷰 라운드 (reviewing-brief, v0.24.0)

(순수 텔레메트리 — **기록이며 게이트 통과 조건이 아니다.** 검사 대상이 통과 조건을 직접 쓰는
검사는 이빨이 없으므로, 리뷰 생략 방지는 Step B 게이트의 degrade 전파가 담당한다.)

- 방향성: Claude <n>건 / codex <n>건 — 사용자 재결정 <n>건
- 충실도 기록(게이트 아님, 마지막 관측 verdict만 기재): <approved|needs_revise|advisory> — critic <n>건 / codex <n>건 — 재라운드 <n>/2
- 냉독: gap <n>건 (<G1..G6 중 어느 클래스>)
- degrade: <component:reason 한 줄씩 | 없음>

## 6. 사용자 원문

(`S1`을 제외한 발화 전량. **append-only** — `S<N>` 항목 추가만 허용하고 기존 항목 본문은
 바꾸지 않는다(P21 placeholder 치환만 예외). 요약·재서술·발췌 금지.
 `check_verbatim_coverage.py`가 state 원장과 대조하는 대상이 이 절이다.)

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S\<N\>** ☑ 선택 (\<무엇에 대한 선택\>):
  > "..."

## 7. 확산 원자료

(payload §4가 쓴 «출처키» 마다 원자료 URL을 여기 선언한다. 집합 포함 검사(N2)이므로
 개수·순서는 무관 — payload가 쓴 키가 이 목록에 있기만 하면 된다. 두 payload 항목이
 같은 키를 써도 여기는 한 번만 선언하면 된다.)

- «example» — https://example.com — 무엇을 확인했나
