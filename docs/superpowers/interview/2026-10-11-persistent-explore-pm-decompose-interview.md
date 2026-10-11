---
name: persistent-explore-pm-decompose
type: interview-brief
created_at: 2026-10-11
session_id: 6e137b56-45f4-43d3-88d2-7fff3ba03a0a
source: spec-distill spec-interview 5.1.1
next_phase: superpowers:brainstorming
contract: v2
audit_file: 2026-10-11-persistent-explore-pm-decompose-interview.audit.md
user_sourced_items:
  - id: C1
    source: verbatim
    status: confirmed
    statement: "품질 저하는 brief 가 얇은 것, spec 하나에 일이 우겨 넣어지는 것, 무엇이 빠졌는지 경고 없이 생략되는 것 세 곳에서 가장 크게 나타난다"
    evidence: S1
  - id: C2
    source: verbatim
    status: confirmed
    statement: "의도 어긋남은 주로 brief 가 brainstorming 으로 넘어가는 이음매에서 생기고, 거기서 brief 의 조사·열린 질문·위험이 spec 에서 사라지며, spec 하나에 맞추느라 범위가 줄거나 바뀐다"
    evidence: S1
  - id: C3
    source: verbatim
    status: confirmed
    statement: "풀 제약은 조사 장치의 호출 예산과 자격, 사용자 질문 리듬 강제, 조사에 서브에이전트를 정해진 몇 자리에서만 제한적으로 쓰는 것이다"
    evidence: S1
  - id: C4
    source: verbatim
    status: confirmed
    statement: "끈질긴 조사는 한 번 더 조사해도 결정에 닿는 새 사실이 없을 때 멈추고, 횟수 상한은 안전장치로만 둔다"
    evidence: S1
  - id: C5
    source: verbatim
    status: confirmed
    statement: "비용을 이유로 품질을 제약하는 장치는 제거하고, 크게 쓰기 전에는 규모만 알린다"
    evidence: S1
  - id: C6
    source: verbatim
    status: confirmed
    statement: "나누기는 인터뷰가 조각·순서·병렬 여부를 제안하고 사용자가 고치거나 승인한 뒤에만 일어난다"
    evidence: S1
  - id: C7
    source: verbatim
    status: confirmed
    statement: "조각들은 한 세션이 지휘해 끝까지 끌고 가되, PM 인 사용자의 결정권과 내용 검토가 유지돼야 하며 그 통제가 무너지면 실패다"
    evidence: S1
  - id: C8
    source: verbatim
    status: confirmed
    statement: "통제가 살아 있다는 것은 전체 조각과 순서·의존, 각 조각이 어느 단계에 있는지를 한 곳에서 볼 수 있다는 것이다"
    evidence: S1
  - id: C9
    source: verbatim
    status: confirmed
    statement: "이번 seed 는 세 갈래를 한 번에 넘기고, 인터뷰가 PM 처럼 순서를 정해 나눈다"
    evidence: S1
  - id: C48
    source: verbatim
    status: confirmed
    statement: "사용자 확인은 조각마다 spec 승인에서 받는다(S1 같은 문장의 뒤 절 「plan·구현은 멈추지 않고 쭉」은 S36 이 외부가 묻는 자리에 한해 바꿨다)"
    evidence: S1
  - id: C10
    source: verbatim
    status: confirmed
    statement: "조사 장치(coverage-mapper)가 범위를 줄이지 않는다"
    evidence: S2
  - id: C11
    source: verbatim
    status: confirmed
    statement: "사용자 의도를 왜곡하는 장치를 다 제거한다"
    evidence: S3
  - id: C12
    source: verbatim
    status: confirmed
    statement: "제거가 아니면 수정한다"
    evidence: S4
  - id: C13
    source: verbatim
    status: confirmed
    statement: "의도 왜곡 장치를 제거·수정하는 것도 이번에 진행할 작업 항목이다"
    evidence: S5
  - id: C14
    source: verbatim
    status: confirmed
    statement: "문제정의는 재구성하지 않고 사용자 말 전부를 그대로 쓰며, 문제 재구성 단계 자체를 제거한다"
    evidence: S6
  - id: D15
    source: chosen
    status: confirmed
    statement: "찾은 의도 왜곡 장치 목록 전부를 제거·수정 대상으로 받고, 새 장치가 안 나올 때까지 조사를 계속한다(다른 플러그인·훅까지)"
    evidence: S7
  - id: D16
    source: chosen
    status: confirmed
    statement: "바깥 사례 8건을 모두 설계 참고 재료로 쓴다 — 1~6 은 취하고, 7·8 은 피할 반대 사례로"
    evidence: S8
  - id: C17
    source: verbatim
    status: confirmed
    statement: "선택지 1 을 골랐고 「구조적으로 정리가 필요할거 같음」이라고 덧붙였다"
    evidence: S9
  - id: D18
    source: chosen
    status: confirmed
    statement: "장치는 전부 대상이고 모두 제거 또는 수정한다 — 비용·절감·압축으로만 작동하거나 사용자 결정을 덮는 것은 제거, 상한·압축은 공시하고 사용자가 여는 형태로 수정"
    evidence: S10
  - id: C19
    source: verbatim
    status: confirmed
    statement: "선택지 2 를 골랐고, 모르는 사이에 드리프트되는 것은 피하고 싶으며 자신은 파일로 소비하지 않고 컨트롤 플레인으로 소비한다고 덧붙였다"
    evidence: S11
  - id: D20
    source: chosen
    status: confirmed
    statement: "인터뷰가 나누고 조각 지도를 내며, 하류의 재분해·축소 신호는 같은 지도로 돌아와 사용자 승인 뒤에만 다시 나누고, 남은 조각은 추적해 이어받는다"
    evidence: S12
  - id: D21
    source: chosen
    status: confirmed
    statement: "숨은 가정 7개와 실패 양식 7개를 모두 위험으로 받고, 조각마다 설계가 그 위험에 답해야 한다"
    evidence: S13
  - id: D22
    source: chosen
    status: confirmed
    statement: "컨트롤 플레인(조각 지도·단계·빠진 것·드리프트 알림)은 Claude Code 안(상태줄·패널)에 두고, 파일은 뒤의 저장소일 뿐이다"
    evidence: S14
  - id: D23
    source: chosen
    status: confirmed
    statement: "포화는 「조사를 더 해도 열린 결정을 바꾸거나 새 결정을 여는 사실이 없음」을 기준으로, 쓰기 권한 없는 독립 판정자가 확인해야 멈추고, 판정 결과는 컨트롤 플레인에 보인다"
    evidence: S15
  - id: D24
    source: chosen
    status: confirmed
    statement: "brief 의 모든 항목을 번호 단위로 넘기고, spec 은 번호마다 반영 또는 기각+이유를 적으며, spec 리뷰가 빠진 번호를 잡아 컨트롤 플레인의 생략 경고로 올린다"
    evidence: S16
  - id: C25
    source: verbatim
    status: confirmed
    statement: "외부 플러그인은 건드리지 않는다"
    evidence: S17
  - id: D26
    source: chosen
    status: confirmed
    statement: "superpowers 의 파일·동작은 그대로 두고 devbrew 쪽(넘길 때 보내는 글·돌아온 결과 검사)만 바꾼다"
    evidence: S18
  - id: C27
    source: verbatim
    status: confirmed
    statement: "실행 판정은 보이기로 한다 — 그 대상이 실행 중 혼자 내린 판정(Ruling)이고 바꾼 것이 「구현 중 멈춤」이라는 것은 S23·S24 가 확인했다"
    evidence: S22
  - id: D28
    source: chosen
    status: confirmed
    statement: "로드맵(고정 번호·한 줄 의도·범위 경계·의존·상태)을 조각 지도로 쓰고, 가능하면 조각 0 은 걷는 뼈대, 조각 사이 인터페이스를 먼저 정하며, 조각이 끝날 때마다 남은 조각을 재평가해 바뀔 때만 승인받는다"
    evidence: S25
  - id: D29
    source: chosen
    status: provisional
    statement: "로드맵은 레포 안 git 추적 파일로 두어 세션·압축·기기가 바뀌어도 살아남게 하고, 덮어써지면 git 이력으로 되살린다"
    evidence: S26
  - id: C30
    source: verbatim
    status: confirmed
    statement: "선택지 1 을 골랐고, devbrew 만 생각하지 말라(여기서만 쓰는 게 아니다), 머지는 기계적 충돌만이 아니라 서로 의도 회귀 같은 문제가 없어야 하고 그럴 수 있게 오케스트레이터가 잘 해야 한다고 덧붙였다"
    evidence: S27
  - id: C31
    source: verbatim
    status: confirmed
    statement: "선택지 1 을 골랐고, superpowers 에도 이런 것이 있으니 SDD 중에 잘 연결될지 생각해 보고, 병렬 머지 원칙은 더 조사하라고 덧붙였다"
    evidence: S28
  - id: C32
    source: verbatim
    status: confirmed
    statement: "원래 있는 것을 다시 만들지 않는다"
    evidence: S30
  - id: D33
    source: chosen
    status: confirmed
    statement: "SDD 연결·병렬 머지 원칙·Claude Code 기본 기능·의도 회귀 감지 조사를 모두 재료로 쓰고, 있는 것을 먼저 쓰며(기반은 작업 목록·worktree 격리·SDD·qg), agent teams 같은 실험 기능은 기반으로 쓰지 않는다"
    evidence: S31
  - id: D34
    source: chosen
    status: confirmed
    statement: "개선 여부는 따로 재지 않고 사용자가 쓰면서 판단한다"
    evidence: S32
  - id: C35
    source: verbatim
    status: confirmed
    statement: "잘 만들어진 외부 플러그인을 어그러뜨리지 않는다"
    evidence: S34
  - id: C36
    source: verbatim
    status: confirmed
    statement: "여기서 큰 작업도 잘 해낼 수 있을지 확인해 볼 수 있겠고 교훈도 있겠다고 말했다"
    evidence: S35
  - id: D37
    source: chosen
    status: confirmed
    statement: "superpowers 가 조각마다 사람에게 묻는 자리(plan 검토·실행 방식 선택·머지 메뉴)는 설계된 대로 사용자에게 묻게 둔다"
    evidence: S36
  - id: D38
    source: chosen
    status: confirmed
    statement: "진행 중인 「다음 세션 @ 명령」 브랜치를 먼저 구현·머지하고, 지휘 세션은 /new 뒤 @로드맵 으로 연다"
    evidence: S37
  - id: D39
    source: chosen
    status: confirmed
    statement: "원본 brief 하나를 정본으로 두고, 로드맵이 조각을 잇고, 조각마다 사용자 원문 전부·공통 목표·인터페이스·그 조각 번호 항목만 담은 묶음을 만들어 원본·로드맵을 거꾸로 가리키게 한다"
    evidence: S39
  - id: D40
    source: chosen
    status: confirmed
    statement: "조각 묶음에 spec 이 답해야 할 결정·질문·위험을 번호로 적고, spec 리뷰가 번호마다 답이 구체적인지 확인해 얕으면 컨트롤 플레인에 경고한다"
    evidence: S40
  - id: D41
    source: chosen
    status: confirmed
    statement: "조각 spec 은 받드는 사용자 발화 번호를 밝히고, spec 승인 때 로드맵 전체 속 위치와 이웃 조각의 결정을 함께 보이며, 어느 조각도 받들지 않는 발화는 경고한다"
    evidence: S41
  - id: D42
    source: chosen
    status: confirmed
    statement: "외부가 받아 주는 입력만 쓰고(조각 묶음으로 목적·제약을 미리 주고, 승인된 로드맵의 한 조각임을 밝힘) 「~보다 우선한다」 같은 덮어쓰기 문장은 빼며, 돌아온 spec 을 번호로 대조해 빠짐·축소·재분해를 경고하고 지도로 되돌린다"
    evidence: S42
  - id: D43
    source: chosen
    status: confirmed
    statement: "조사 안전장치 상한은 인터뷰 하나에서 조사 장치 호출 20회이고, 닿으면 컨트롤 플레인에 알리며 환경 변수로 바꾸고 사용자가 연장할 수 있다"
    evidence: S43
  - id: C44
    source: verbatim
    status: confirmed
    statement: "교훈은 따로 다루지 않는다"
    evidence: S44
  - id: D45
    source: chosen
    status: confirmed
    statement: "spec 리뷰를 부를 때 그 조각 묶음과 로드맵 경로를 직접 넘기고, spec 리뷰는 묶음(번호 항목·그 조각의 몫·사용자 원문)을 정답 출처로 쓰며, 외부 플러그인은 손대지 않는다"
    evidence: S45
  - id: D46
    source: chosen
    status: confirmed
    statement: "미구현 「spec-distill 상태 저장 재설계」 결정 D1~D4 를 이번 로드맵에 흡수한다 — 인터뷰 상태는 docs, 임시 폴더는 리뷰 상태만, 이어 하기는 로드맵 기반, 긴·병렬 실행 중 리뷰 원장 소실 방지"
    evidence: S46
  - id: D47
    source: chosen
    status: confirmed
    statement: "고친 분해안(선행 3 + R0~R9)을 승인한다"
    evidence: S47
---

# 집요한 탐색 · 인터뷰의 PM 분해 · 조각별 지휘 · 의도 왜곡 장치 제거 — Interview Brief

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다. 텔레메트리는 `audit_file`에 있다.

## 0. 한눈에

- 무엇: 사용자가 말한 것 전부(seed S1 과 인터뷰 중 발화 S2~S51). 문제를 다시 짜지 않는다 — 사용자가 재구성 단계 자체를 거부했다(S6). 네 갈래: ① 인터뷰가 한 번에 닫지 않고 집요하게 탐색 ② 인터뷰가 PM 으로 일을 나눠 하류로 ③ 나뉜 조각을 한 세션이 지휘해 각각 brainstorming → spec → plan → 구현 ④ 사용자 의도를 왜곡하는 장치를 제거하거나 수정(S3·S4·S5).
- 왜: spec-distill 로 맡기면 품질이 조용히 크게 떨어지고 의도와 어긋난다 — 얇은 brief · spec 하나에 우겨 넣기 · 경고 없는 생략, 그리고 brief → brainstorming 이음매에서 조사·열린 질문·위험이 사라지고 범위가 줄거나 바뀐다(S1).
- 확정 후보: §2 의 48개(전부 잠정). 핵심 — 장치는 전부 제거 또는 수정(S10) · 포화는 독립 판정자가 확인(S15) · 번호 단위 인계·대조(S16) · 로드맵 + 걷는 뼈대(S25) · 컨트롤 플레인은 Claude Code 안(S14) · 외부(superpowers)는 건드리지도 어그러뜨리지도 않음(S17·S34) · 있는 것을 다시 만들지 않음(S30).
- 분해(사용자 승인 S47): 「다음 세션 @ 명령」 브랜치 머지 → R0 실측·공통 형식 다섯·걷는 뼈대 → R1 인터뷰 탐색 개편 ‖ R2 spec-distill 압축·리뷰 장치 ‖ R7 상태 저장 재설계 흡수 ‖ R3 번호 인계·대조·깊이 ‖ R4 PM 분해·로드맵·조각 묶음 ‖ R6 컨트롤 플레인 → R2a 공유 리뷰 엔진(qg 파급·persona 보안 리뷰) · R5 지휘자 — 이 둘은 qg ⑤·쉬운 말 PR 3 머지와 qg 진입 이름 결정 뒤(qg 쪽 선행은 qg 조각 앞만 — S51) → R8 의존 선언·범용성 → R9 규칙·문서 정리. 옛 훅 브랜치 고아 확인은 착수 전에. 상세는 §7. ✎ 조각별 내용은 인터뷰어가 제시한 분해안 문구다 — 승인 원문(S47)에는 조각 번호와 순서만 있다.
- 열림: §3 의 9개.
- 다음: §7.

**결정 목록**

- OQ1 [해결 ⟨S6⟩] — 문제의 뿌리를 무엇으로 볼 것인가(재구성 동의) → 근거 RC48
- OQ2 [해결 ⟨S7⟩] — 찾은 의도 왜곡 장치 목록을 전부 제거·수정 대상으로 받고 조사를 계속할 것인가
- OQ3 [해결 ⟨S8⟩] — 바깥 사례(8건)를 설계 재료로 어떻게 처분할 것인가
- OQ4 [해결 ⟨S9⟩] — 「경고 없는 생략」을 통제 표면(조각 지도)에 넣는가
- OQ5 [해결 ⟨S13⟩] — 숨은 가정 7 · 실패 양식 7 을 위험으로 어떻게 처분하는가
- OQ6 [해결 ⟨S14⟩] — 컨트롤 플레인(조각 지도·상태·생략·드리프트)을 어디에 두는가
- OQ7 [해결 ⟨S15⟩] — 포화를 무엇으로·누가 판정하는가
- OQ8 [해결 ⟨S16⟩] — brief 의 조사·열린 질문·위험이 spec 까지 가게 하는 방법 → 근거 RC9 · RC27
- OQ9 [해결 ⟨S18⟩] — 외부 superpowers 의 왜곡 장치에 어떻게 개입하는가
- OQ10 [해결 ⟨S22⟩] — 실행 중 혼자 내린 판정(Ruling)이 의도를 바꿀 때 어떻게 다루는가 → 근거 RC47
- OQ11 [해결 ⟨S25⟩] — 분해 방식(로드맵 + 걷는 뼈대) — 「spec 하나로 되는가」의 판단 기준 자체는 OQ36 으로 남음 → 근거 RC11
- OQ12 [해결 ⟨S26⟩] — 조각 지도(로드맵)의 저장 위치와 수명
- OQ13 [해결 ⟨S27⟩] — 병렬 조각의 격리·병합 — 선택지 1(조각마다 worktree · 버전은 머지 직전 · 의존 순 머지)과 의도 회귀는 오케스트레이터 책임(S27 의 덧붙인 말) → 근거 RC38
- OQ14 [해결 ⟨S28⟩] — 실패·중단 처리 — 선택지 1(부분 계속 + 로드맵 재개), SDD 연결과 머지 원칙은 S28 이 더 조사하라고 해서 S31 로 처분
- OQ15 [해결 ⟨S31⟩] — 병렬 머지 원칙·SDD 연결 조사 결과를 설계 재료로 어떻게 처분하는가
- OQ16 [해결 ⟨S32⟩] — 바뀐 파이프라인의 품질이 실제로 나아졌는지 무엇으로 확인하는가
- OQ17 [해결 ⟨S47⟩] — 이번 일의 조각·순서·병렬 분해안 승인 → 근거 RC20 · RC61 · RC70 · RC79
- OQ18 [해결 ⟨S36⟩] — 조각마다 외부가 사람을 멈춰 세우는 자리(plan 리뷰 등)를 어떻게 다루는가
- OQ19 [해결 ⟨S37⟩] — 진행 중인 「다음 세션 @ 명령」 브랜치와 이번 일의 선후 → 근거 RC17 · RC71
- OQ20 [해결 ⟨S46⟩] — 미구현 「spec-distill 상태 저장 재설계」 결정 D1~D4 를 이번 일에 흡수하는가 → 근거 RC15 · RC37 · RC60
- OQ21 [해결 ⟨S39⟩] — 조각을 하류로 넘기는 모양(brief 여러 개 링크 vs 다른 방법) — seed 가 열어 둔 것 → 근거 RC68
- OQ22 [해결 ⟨S40⟩] — 「자세한 spec · 태스크마다 충분한 설계」를 무엇이 보장하는가
- OQ23 [해결 ⟨S41⟩] — 조각 사이 큰 그림·의도를 어떻게 지키는가(조각마다 재해석 방지)
- OQ24 [해결 ⟨S42⟩] — 외부 왜곡 장치(YAGNI·혼자 고르기·첫 조각만·작은 일이면 spec 생략)를 외부를 건드리지 않고 어떻게 막는가 → 근거 RC10 · RC40 · RC41 · RC42 · RC43 · RC44 · RC45 · RC46
- OQ25 [해결 ⟨S43⟩] — 조사 안전장치 상한의 값 → 근거 RC14 · RC34
- OQ26 [해결 ⟨S44⟩] — 이 일에서 나오는 교훈을 어떻게 남기는가(S35)
- OQ27 [해결 ⟨S45⟩] — spec 리뷰의 끊긴 정답 출처(범위 바뀜 감지)를 어떻게 잇는가 → 근거 RC8 · RC69 · RC74 · RC75
- OQ28 [열림] — 보완안 ST2 의 예외 멈춤(승인 spec 반증·막힘 시 묻기)이 S22(구현 중 멈추지 않음)로 함께 사라지는가 → 근거 RC63
- OQ29 [열림] — 의도 왜곡 장치 각각의 제거/수정 판정 — 기준 S10 고정, 장치 전수는 포화 전이라 설계 조각이 계속 찾음 → 근거 RC1 · RC2 · RC3 · RC4 · RC5 · RC6 · RC7 · RC16 · RC19 · RC21 · RC23 · RC24 · RC25 · RC28 · RC29 · RC30 · RC31 · RC32 · RC33 · RC39 · RC49 · RC50 · RC51 · RC52 · RC53 · RC54 · RC55 · RC56 · RC57 · RC58 · RC59 · RC65 · RC66 · RC67
- OQ30 [열림] — R0 실측(한 세션 skill 이어 부르기·작업 목록 표시·외부 정지 지점)이 R5 지휘자 모양을 바꾸는가
- OQ31 [열림] — qg 진입 이름 결정·qg ⑤ 이후 의도 출처 형식에 지휘자의 qg 연결(커밋 Spec: 표시 포함)을 맞추는 법 → 근거 RC72 · RC73 · RC76 · RC77 · RC85
- OQ32 [열림] — 독립 포화 판정자를 새로 둘지 기존 재비판 장치를 재사용할지 — 새 dispatch 자리의 처분 줄·회계 → 근거 RC18
- OQ33 [열림] — 조각 묶음·로드맵 파일의 위치·이름 규약과 brief 게이트 타입을 devbrew 밖 레포에서도 통하게 → 근거 RC78 · RC82 · RC83
- OQ34 [열림] — Claude Code 작업 목록·패널로 실제 보일 수 있는 범위(기존 훅 배달지 실측에서 출발) → 근거 RC80
- OQ35 [열림] — devbrew 지출 승인 조항(cost_class high)·P22 개정 문안 — 레포 규칙 변경이라 사용자 승인 필요 → 근거 RC12 · RC13 · RC62 · RC64 · RC84
- OQ36 [열림] — 「이 일이 구현 spec 하나로 되는가」의 판단 기준 — S25 는 분해 방식을 정했고 기준 자체는 정하지 않음(brief 리뷰 r1 지적)
- OQ37 [열림] — [참고 · direction] 조각별 상태까지 담은 로드맵을 git 추적 파일 하나로 두는 결정(D28·D29)은 병렬 worktree 와 부딪힌다 — 정의(번호·의도·범위·의존)는 추적 파일에, 살아 있는 단계 상태는 지휘자만 쓰는 한 곳(또는 브랜치·PR 상태에서 도출)에 둘지
- OQ38 [열림] — [참고 · direction] §7 은 모든 조각에 조각 묶음·로드맵·컨트롤 플레인을 쓰라는데 그 장치는 R0·R3·R4·R6 에서야 생긴다 — ① 이번 일의 로드맵·묶음을 지금 손으로 만들어 걷는 뼈대로 쓸지, ② 앞쪽 조각은 지금의 brief 넘김으로 가고 새 장치는 R3·R4·R6 머지 뒤 조각부터 쓸지

## 1. Goal · Non-goal

- Goal: 사용자가 한 말 전부(S1~S51)를 그대로 실현한다 — 네 갈래 전부, 작업 범위를 줄이지 않는다(S6 · S3, 이 읽기는 S49 가 정했다). 조사 장치 coverage-mapper 는 범위를 줄이지 않는다(S2). 결정은 §2, 나누기는 §7 의 승인된 로드맵을 따른다.
- Non-goal: 외부 플러그인(superpowers) 파일·동작을 고치거나 어그러뜨리는 것(S17·S18·S34) · 실험 기능(agent teams)을 기반으로 쓰는 것(S31) · 이미 있는 것을 다시 만드는 것(S30) · 교훈을 따로 다루는 장치(S44) · 개선을 재는 별도 측정 장치(S32) · 문제를 다시 짜는 재구성(S6).

## 2. 제약

(모델이 쓴 요약이다. 원문은 payload §6(S1)과 audit §6(S2 이상)에 있다.)

- 🗣 confirmed **C1** — 품질 저하는 brief 가 얇은 것, spec 하나에 일이 우겨 넣어지는 것, 무엇이 빠졌는지 경고 없이 생략되는 것 세 곳에서 가장 크게 나타난다 ⟨S1⟩
- 🗣 confirmed **C2** — 의도 어긋남은 주로 brief 가 brainstorming 으로 넘어가는 이음매에서 생기고, 거기서 brief 의 조사·열린 질문·위험이 spec 에서 사라지며, spec 하나에 맞추느라 범위가 줄거나 바뀐다 ⟨S1⟩
- 🗣 confirmed **C3** — 풀 제약은 조사 장치의 호출 예산과 자격, 사용자 질문 리듬 강제, 조사에 서브에이전트를 정해진 몇 자리에서만 제한적으로 쓰는 것이다 ⟨S1⟩
- 🗣 confirmed **C4** — 끈질긴 조사는 한 번 더 조사해도 결정에 닿는 새 사실이 없을 때 멈추고, 횟수 상한은 안전장치로만 둔다 ⟨S1⟩
- 🗣 confirmed **C5** — 비용을 이유로 품질을 제약하는 장치는 제거하고, 크게 쓰기 전에는 규모만 알린다 ⟨S1⟩
- 🗣 confirmed **C6** — 나누기는 인터뷰가 조각·순서·병렬 여부를 제안하고 사용자가 고치거나 승인한 뒤에만 일어난다 ⟨S1⟩
- 🗣 confirmed **C7** — 조각들은 한 세션이 지휘해 끝까지 끌고 가되, PM 인 사용자의 결정권과 내용 검토가 유지돼야 하며 그 통제가 무너지면 실패다 ⟨S1⟩
- 🗣 confirmed **C8** — 통제가 살아 있다는 것은 전체 조각과 순서·의존, 각 조각이 어느 단계에 있는지를 한 곳에서 볼 수 있다는 것이다 ⟨S1⟩
- 🗣 confirmed **C9** — 이번 seed 는 세 갈래를 한 번에 넘기고, 인터뷰가 PM 처럼 순서를 정해 나눈다 ⟨S1⟩
- 🗣 confirmed **C48** — 사용자 확인은 조각마다 spec 승인에서 받는다(S1 같은 문장의 뒤 절 「plan·구현은 멈추지 않고 쭉」은 S36 이 외부가 묻는 자리에 한해 바꿨다) ⟨S1⟩
- 🗣 confirmed **C10** — 조사 장치(coverage-mapper)가 범위를 줄이지 않는다 ⟨S2⟩
- 🗣 confirmed **C11** — 사용자 의도를 왜곡하는 장치를 다 제거한다 ⟨S3⟩
- 🗣 confirmed **C12** — 제거가 아니면 수정한다 ⟨S4⟩
- 🗣 confirmed **C13** — 의도 왜곡 장치를 제거·수정하는 것도 이번에 진행할 작업 항목이다 ⟨S5⟩
- 🗣 confirmed **C14** — 문제정의는 재구성하지 않고 사용자 말 전부를 그대로 쓰며, 문제 재구성 단계 자체를 제거한다 ⟨S6⟩
- ☑ confirmed **D15** — 찾은 의도 왜곡 장치 목록 전부를 제거·수정 대상으로 받고, 새 장치가 안 나올 때까지 조사를 계속한다(다른 플러그인·훅까지) ⟨S7⟩
- ☑ confirmed **D16** — 바깥 사례 8건을 모두 설계 참고 재료로 쓴다 — 1~6 은 취하고, 7·8 은 피할 반대 사례로 ⟨S8⟩
- 🗣 confirmed **C17** — 선택지 1 을 골랐고 「구조적으로 정리가 필요할거 같음」이라고 덧붙였다 ⟨S9⟩
- ☑ confirmed **D18** — 장치는 전부 대상이고 모두 제거 또는 수정한다 — 비용·절감·압축으로만 작동하거나 사용자 결정을 덮는 것은 제거, 상한·압축은 공시하고 사용자가 여는 형태로 수정 ⟨S10⟩
- 🗣 confirmed **C19** — 선택지 2 를 골랐고, 모르는 사이에 드리프트되는 것은 피하고 싶으며 자신은 파일로 소비하지 않고 컨트롤 플레인으로 소비한다고 덧붙였다 ⟨S11⟩
- ☑ confirmed **D20** — 인터뷰가 나누고 조각 지도를 내며, 하류의 재분해·축소 신호는 같은 지도로 돌아와 사용자 승인 뒤에만 다시 나누고, 남은 조각은 추적해 이어받는다 ⟨S12⟩
- ☑ confirmed **D21** — 숨은 가정 7개와 실패 양식 7개를 모두 위험으로 받고, 조각마다 설계가 그 위험에 답해야 한다 ⟨S13⟩
- ☑ confirmed **D22** — 컨트롤 플레인(조각 지도·단계·빠진 것·드리프트 알림)은 Claude Code 안(상태줄·패널)에 두고, 파일은 뒤의 저장소일 뿐이다 ⟨S14⟩
- ☑ confirmed **D23** — 포화는 「조사를 더 해도 열린 결정을 바꾸거나 새 결정을 여는 사실이 없음」을 기준으로, 쓰기 권한 없는 독립 판정자가 확인해야 멈추고, 판정 결과는 컨트롤 플레인에 보인다 ⟨S15⟩
- ☑ confirmed **D24** — brief 의 모든 항목을 번호 단위로 넘기고, spec 은 번호마다 반영 또는 기각+이유를 적으며, spec 리뷰가 빠진 번호를 잡아 컨트롤 플레인의 생략 경고로 올린다 ⟨S16⟩
- 🗣 confirmed **C25** — 외부 플러그인은 건드리지 않는다 ⟨S17⟩
- ☑ confirmed **D26** — superpowers 의 파일·동작은 그대로 두고 devbrew 쪽(넘길 때 보내는 글·돌아온 결과 검사)만 바꾼다 ⟨S18⟩
- 🗣 confirmed **C27** — 실행 판정은 보이기로 한다 — 그 대상이 실행 중 혼자 내린 판정(Ruling)이고 바꾼 것이 「구현 중 멈춤」이라는 것은 S23·S24 가 확인했다 ⟨S22⟩
- ☑ confirmed **D28** — 로드맵(고정 번호·한 줄 의도·범위 경계·의존·상태)을 조각 지도로 쓰고, 가능하면 조각 0 은 걷는 뼈대, 조각 사이 인터페이스를 먼저 정하며, 조각이 끝날 때마다 남은 조각을 재평가해 바뀔 때만 승인받는다 ⟨S25⟩
- ☑ provisional **D29** — 로드맵은 레포 안 git 추적 파일로 두어 세션·압축·기기가 바뀌어도 살아남게 하고, 덮어써지면 git 이력으로 되살린다 ⟨S26⟩
- 🗣 confirmed **C30** — 선택지 1 을 골랐고, devbrew 만 생각하지 말라(여기서만 쓰는 게 아니다), 머지는 기계적 충돌만이 아니라 서로 의도 회귀 같은 문제가 없어야 하고 그럴 수 있게 오케스트레이터가 잘 해야 한다고 덧붙였다 ⟨S27⟩
- 🗣 confirmed **C31** — 선택지 1 을 골랐고, superpowers 에도 이런 것이 있으니 SDD 중에 잘 연결될지 생각해 보고, 병렬 머지 원칙은 더 조사하라고 덧붙였다 ⟨S28⟩
- 🗣 confirmed **C32** — 원래 있는 것을 다시 만들지 않는다 ⟨S30⟩
- ☑ confirmed **D33** — SDD 연결·병렬 머지 원칙·Claude Code 기본 기능·의도 회귀 감지 조사를 모두 재료로 쓰고, 있는 것을 먼저 쓰며(기반은 작업 목록·worktree 격리·SDD·qg), agent teams 같은 실험 기능은 기반으로 쓰지 않는다 ⟨S31⟩
- ☑ confirmed **D34** — 개선 여부는 따로 재지 않고 사용자가 쓰면서 판단한다 ⟨S32⟩
- 🗣 confirmed **C35** — 잘 만들어진 외부 플러그인을 어그러뜨리지 않는다 ⟨S34⟩
- 🗣 confirmed **C36** — 여기서 큰 작업도 잘 해낼 수 있을지 확인해 볼 수 있겠고 교훈도 있겠다고 말했다 ⟨S35⟩
- ☑ confirmed **D37** — superpowers 가 조각마다 사람에게 묻는 자리(plan 검토·실행 방식 선택·머지 메뉴)는 설계된 대로 사용자에게 묻게 둔다 ⟨S36⟩
- ☑ confirmed **D38** — 진행 중인 「다음 세션 @ 명령」 브랜치를 먼저 구현·머지하고, 지휘 세션은 /new 뒤 @로드맵 으로 연다 ⟨S37⟩
- ☑ confirmed **D39** — 원본 brief 하나를 정본으로 두고, 로드맵이 조각을 잇고, 조각마다 사용자 원문 전부·공통 목표·인터페이스·그 조각 번호 항목만 담은 묶음을 만들어 원본·로드맵을 거꾸로 가리키게 한다 ⟨S39⟩
- ☑ confirmed **D40** — 조각 묶음에 spec 이 답해야 할 결정·질문·위험을 번호로 적고, spec 리뷰가 번호마다 답이 구체적인지 확인해 얕으면 컨트롤 플레인에 경고한다 ⟨S40⟩
- ☑ confirmed **D41** — 조각 spec 은 받드는 사용자 발화 번호를 밝히고, spec 승인 때 로드맵 전체 속 위치와 이웃 조각의 결정을 함께 보이며, 어느 조각도 받들지 않는 발화는 경고한다 ⟨S41⟩
- ☑ confirmed **D42** — 외부가 받아 주는 입력만 쓰고(조각 묶음으로 목적·제약을 미리 주고, 승인된 로드맵의 한 조각임을 밝힘) 「~보다 우선한다」 같은 덮어쓰기 문장은 빼며, 돌아온 spec 을 번호로 대조해 빠짐·축소·재분해를 경고하고 지도로 되돌린다 ⟨S42⟩
- ☑ confirmed **D43** — 조사 안전장치 상한은 인터뷰 하나에서 조사 장치 호출 20회이고, 닿으면 컨트롤 플레인에 알리며 환경 변수로 바꾸고 사용자가 연장할 수 있다 ⟨S43⟩
- 🗣 confirmed **C44** — 교훈은 따로 다루지 않는다 ⟨S44⟩
- ☑ confirmed **D45** — spec 리뷰를 부를 때 그 조각 묶음과 로드맵 경로를 직접 넘기고, spec 리뷰는 묶음(번호 항목·그 조각의 몫·사용자 원문)을 정답 출처로 쓰며, 외부 플러그인은 손대지 않는다 ⟨S45⟩
- ☑ confirmed **D46** — 미구현 「spec-distill 상태 저장 재설계」 결정 D1~D4 를 이번 로드맵에 흡수한다 — 인터뷰 상태는 docs, 임시 폴더는 리뷰 상태만, 이어 하기는 로드맵 기반, 긴·병렬 실행 중 리뷰 원장 소실 방지 ⟨S46⟩
- ☑ confirmed **D47** — 고친 분해안(선행 3 + R0~R9)을 승인한다 ⟨S47⟩

✎ 재결정 셋이 있다 — S1 의 「…plan·구현은 멈추지 않고 쭉 간다」(뒤 절)는 S36 이 외부가 묻는 자리에 한해(앞 절 「조각마다 spec 승인」은 C48 로 살아 있다), S10 의 외부 장치 부분은 S17·S18 이, S19 의 「어긋나면 그 조각 멈춤」은 S22 가 뒤집었다(§5 기각에 원래/재결정/근거). 위 요약은 원문을 줄이지 않으려 했지만, 요약과 원문이 다르면 원문(payload §6 · audit §6)이 이긴다. 열린 질문 넘김(S48)은 §3 과 조각 묶음 양쪽이다 — §3 에 반영했고, 조각 묶음에는 R0·R4 가 묶음을 만들 때 그 조각에 닿는 열린 질문을 싣는다.

✎ seed 에서 확인 표시가 없는 저자 문장(사용자 처음 원문에서 옮김)과 그것을 받드는 항목 — 「spec-distill 로 일을 맡기면 결과물의 품질이 조용히 크게 떨어지고 내 의도와도 어긋난다」→ C1·C2 · 「내가 보는 원인은 둘이다 / 첫째, 인터뷰가 다섯 floor 를 한 번 채우면 닫고, 조사에 제약이 너무 많아 맥락이 매우 부족한 상태로 넘어간다」→ C3·D18·D23 · 「둘째, 큰 문제를 spec 하나로 처리하려다 보니 한 spec 에 우겨 넣거나 할 일을 미룬다」→ D20·D28 · 「여러 spec 이 나오는 것이 자연스럽고, 그래야 더 상세히 명세될 것 같다」→ D28·D40(사용자 추측, 직접 잰 근거 없음) · 「원하는 모양은 세 갈래다 / 먼저 인터뷰는 한 번에 닫지 않고 집요하게 탐색한다」→ D15·D18·D23(네 번째 갈래는 C13) · 「다음으로 인터뷰가 PM 역할을 맡는다 / 이 일이 구현 spec 하나로 되는지 판단하고, 크면 순서를 나눠 일을 하류로 나눠 넘긴다」→ D20·D28, 판단 기준 자체는 OQ36 · 「brief 를 여러 개로 만들어 서로 링크하는 것이 내 첫 생각이지만 …」→ D39 · 「마지막으로 나뉜 조각은 순차 또는 병렬로 각각 brainstorming → spec → plan → 구현을 거친다」→ C30·C48·D37 · 「목적은 태스크마다 충분한 설계를 붙여 긴 작업을 쭉, 그리고 병렬로 맡기는 것이다」→ D40·C30.

✎ 선택지 번호의 뜻(인터뷰어가 쓴 선택지 문구 — 원문에는 번호만 있다): S9 의 1 = 「빠진 것을 조각 지도와 같은 곳에」 · S11 의 2 = 「긴 실행 보완안(지휘 상태는 파일, 반증·막힘에서만 묻기, 지출 조항 공개 개정)」 · S27 의 1 = 「조각마다 worktree · 버전은 머지 직전 · 의존 순 머지」 · S28 의 1 = 「실패 조각과 그 의존 조각만 멈추고 나머지 계속, 끊기면 로드맵에서 재개」. 이 뜻은 D 항목들(D20·D22·D29 등)과 §5 기각 줄에 함께 실려 있다.

## 3. Open Questions

- OQ28: 보완안 ST2 의 예외 멈춤(승인 spec 반증·막힘 시 묻기)이 S22(구현 중 멈추지 않음)로 함께 사라지는가 → 근거 RC63
- OQ29: 의도 왜곡 장치 각각의 제거/수정 판정 — 기준 S10 고정, 장치 전수는 포화 전이라 설계 조각이 계속 찾음 → 근거 RC1 · RC2 · RC3 · RC4 · RC5 · RC6 · RC7 · RC16 · RC19 · RC21 · RC23 · RC24 · RC25 · RC28 · RC29 · RC30 · RC31 · RC32 · RC33 · RC39 · RC49 · RC50 · RC51 · RC52 · RC53 · RC54 · RC55 · RC56 · RC57 · RC58 · RC59 · RC65 · RC66 · RC67
- OQ30: R0 실측(한 세션 skill 이어 부르기·작업 목록 표시·외부 정지 지점)이 R5 지휘자 모양을 바꾸는가
- OQ31: qg 진입 이름 결정·qg ⑤ 이후 의도 출처 형식에 지휘자의 qg 연결(커밋 Spec: 표시 포함)을 맞추는 법 → 근거 RC72 · RC73 · RC76 · RC77 · RC85
- OQ32: 독립 포화 판정자를 새로 둘지 기존 재비판 장치를 재사용할지 — 새 dispatch 자리의 처분 줄·회계 → 근거 RC18
- OQ33: 조각 묶음·로드맵 파일의 위치·이름 규약과 brief 게이트 타입을 devbrew 밖 레포에서도 통하게 → 근거 RC78 · RC82 · RC83
- OQ34: Claude Code 작업 목록·패널로 실제 보일 수 있는 범위(기존 훅 배달지 실측에서 출발) → 근거 RC80
- OQ35: devbrew 지출 승인 조항(cost_class high)·P22 개정 문안 — 레포 규칙 변경이라 사용자 승인 필요 → 근거 RC12 · RC13 · RC62 · RC64 · RC84
- OQ36: 「이 일이 구현 spec 하나로 되는가」의 판단 기준 — S25 는 분해 방식을 정했고 기준 자체는 정하지 않음(brief 리뷰 r1 지적)
- OQ37: [참고 · direction] 조각별 상태까지 담은 로드맵을 git 추적 파일 하나로 두는 결정(D28·D29)은 병렬 worktree 와 부딪힌다 — 정의(번호·의도·범위·의존)는 추적 파일에, 살아 있는 단계 상태는 지휘자만 쓰는 한 곳(또는 브랜치·PR 상태에서 도출)에 둘지 (리뷰 abf668a4#r1.1)
- OQ38: [참고 · direction] §7 은 모든 조각에 조각 묶음·로드맵·컨트롤 플레인을 쓰라는데 그 장치는 R0·R3·R4·R6 에서야 생긴다 — ① 이번 일의 로드맵·묶음을 지금 손으로 만들어 걷는 뼈대로 쓸지, ② 앞쪽 조각은 지금의 brief 넘김으로 가고 새 장치는 R3·R4·R6 머지 뒤 조각부터 쓸지 (리뷰 7e0e7d70#r1.1)

## 4. External Landscape

- 조사량을 일의 복잡도에 맞춰 늘리고 산출물은 외부에 저장해 가벼운 참조만 넘김, 「충분한데 계속」은 실패, 토큰 약 15배 «anthropic-multiagent» — [취함] [→ OQ7]
- 새로움 신호가 여러 번 0일 때만 멈추고 개입을 먼저 시도하는 포화 판정 «arxiv-2608.15191» — [취함] [→ OQ7]
- 하위 질문 커버리지 체크리스트가 가장 믿을 만한 수렴 검사 «tianpan-convergence» — [취함] [→ OQ7]
- 조기 종료는 반복 실패 양식이고 처방은 사전 충분 조건 «arxiv-2604.24978» — [취함] [→ OQ7]
- 포화는 개념이 여럿이라 운용 정의 없이 쓰면 흔들림 «saunders-saturation» — [중립] [→ OQ7]
- 묶이지 않은 피드백 경로는 끝없는 루프 — 안전 상한의 근거 «infinite-agentic-loops» — [취함] [→ OQ25]
- 산문 요약은 「왜」를 잃으니 결정·근거·출처를 담은 구조체로 넘김 «contextchain» — [취함] [→ OQ8]
- 요약 단계가 특정 사실을 군더더기로 판단해 버려 하류가 오판 «lightrun» — [취함] [→ OQ8]
- 조각(story)이 원래 문서로 돌아가는 인용과 자기 맥락을 들고 감 «bmad» — [취함] [→ OQ21]
- 의존 그래프로 다음 할 일을 고름 «taskmaster» — [취함] [→ OQ11]
- 의존 순 spec 을 웨이브로 병렬, 한 조각 실패해도 나머지 계속, 체크박스로 상태 «kiro-spec-batch» — [취함] [→ OQ11]
- 발견 단계 청사진(도메인·인터페이스·계약) 뒤 재귀 분해, 크기 기준 제시 «recursive-sdd» — [취함] [→ OQ11]
- 진입점 epic triage 로 의존 인식 spec 들로 분해하고 진행 상태를 따로 추적 «ralph-specum» — [취함] [→ OQ11]
- spec 승인 뒤 수직 조각, 조각 0 걷는 뼈대, 조각마다 재평가(메인테이너 응답 없이 닫힌 제안) «superpowers-issue-1173» — [취함] [→ OQ11]
- 로드맵 한 장에 고정 번호·의도·범위 경계·의존·상태, 하위 spec 이 부모를 역참조, 독립 조각은 worktree 병렬 «spec-kit-spec-of-specs» — [취함] [→ OQ11]
- spec 이 형제의 2.5배이거나 리뷰가 하위 시스템별로 몰려 수렴하지 않으면 분할 «eugenelim-pr11» — [중립] [→ OQ11]
- 할 일은 일하면서 드러난다 — 분해를 다시 정할 수 있어야 함 «shapeup» — [중립] [→ OQ11]
- 실행이 막힐 때만 분해 — 인터뷰가 나눈다(확인 문장)와 충돌, 재평가 아이디어만 참고 «adapt» — [피함] [→ OQ11]
- 단계마다 사람 확인 «spec-kit» — [피함] [→ OQ18]
- 독립 조각을 순서대로 하나씩만 다룸 — 병렬과 충돌 «superpowers-brainstorming-main» — [피함] [→ OQ24]
- 긴 입력의 가운데 정보를 덜 씀 — 조각 묶음을 그 조각 몫으로 좁히는 근거 «lost-in-middle» — [취함] [→ OQ21]
- 진척 파일과 git 으로 세션을 이어 가고, 한 세션 몰아치기는 조기 승리 선언 «anthropic-long-running» — [취함] [→ OQ14]
- 체크포인트·막힘에서 사람 피드백, 최대 반복 수 같은 정지 조건 «anthropic-building-agents» — [중립] [→ OQ10]
- 서로 못 보는 병렬 에이전트는 상충하는 암묵 결정을 내림 «cognition-multi-agents» — [취함] [→ OQ13]
- 조기 종료·정보 은닉·과업 불복종과 반복·종료 조건 무지가 함께 실패 유형 «mast» — [취함] [→ OQ29]
- 맥락은 체감 수익이 줄어드는 유한 자원(context rot), 공격적 압축은 미묘하지만 결정적인 맥락을 잃음 «context-engineering» — [취함] [→ OQ29]
- 입력이 길수록 단순 과제도 불안정(요약으로만 확인) «chroma-context-rot» — [중립] [→ OQ29]
- 최신 모델은 지시를 정확히 따름(절감 지시가 그대로 축소로), 동시에 과설계 경향 «claude4-best-practices» — [취함] [→ OQ29]
- 울타리를 왜 세웠는지 알기 전에 치우지 말 것 — 장치마다 지키던 요구 확인 «chesterton-fence» — [취함] [→ OQ29]
- 모델은 사용자 견해에 맞추는 경향 — 「말 그대로」를 비판 없이 따를 위험 «sycophancy» — [취함] [→ OQ29]
- 승인이 늘면 사람 게이트가 도장 찍기로 쇠퇴(실무 블로그, 근거 약함) «approval-fatigue» — [중립] [→ OQ18]
- 산문 승인 지시를 장시간 에이전트가 어김(2차 보도) «replit-incident» — [중립] [→ OQ10]
- 글자 충돌 없이 병합돼도 깨지는 의미 충돌 «graphite-mergequeue» — [취함] [→ OQ13]
- 최신 main 위 재검증, 범위가 안 겹치면 병렬 레인·겹치면 직렬 «mergify-queue» — [취함] [→ OQ13]
- 직렬 머지·fail-closed, 충돌 해소를 모델에게 맡기지 않음, 경로 예약, 쌍별 사전 검사, 공유 체크리스트는 충돌 지점 «worktree-merge-conflicts» — [취함] [→ OQ13]
- worktree 는 파일만 격리, 포트·DB 는 격리 못 함 «augment-worktrees» — [취함] [→ OQ13]
- 조각 사이 인터페이스를 계약 테스트로 묶어 머지 전에 깨짐 감지 «cdc-contracts» — [취함] [→ OQ13]
- 요구→작업→파일→테스트 추적과 머지 전 검사 «spec-drift-traceability» — [취함] [→ OQ15]
- 결정론 검사는 매번, 의미 검사는 PR, 판정자 검사는 main 머지에 «coverge-regression» — [취함] [→ OQ15]
- 모델 판정 단독은 미세한 구현 드리프트에 약해 기계 검사와 짝 «arxiv-2604.03447» — [취함] [→ OQ15]
- 수용 기준 단위 DRIFT 로 머지 차단 사례(본문 PDF 미확인, 검색 요약) «arxiv-2606.26924» — [중립] [→ OQ15]
- 단독 권한 게이트엔 최적화 쪽 밖의 두 번째 관측 «arxiv-2608.13867» — [취함] [→ OQ15]
- 공유 작업 목록·의존·메시지·완료 훅이 있으나 실험 기능이고 재개 불가·계획 자동 승인 «cc-agent-teams» — [피함] [→ OQ15]
- subagent 에선 사용자 질문 불가, worktree 격리는 기본 브랜치에서 분기, 중첩 3단·동시 20 «cc-subagents» — [취함] [→ OQ18]
- 설치본 writing-plans 는 실행 방식을 미리 받아도 plan 검토를 기다리고, finishing 은 머지 메뉴에서 기다림 «superpowers-repo» — [중립] [→ OQ18]
- 계획마다 실행 기록 파일, 완료·Ruling 줄, 압축 뒤 기록과 git 으로 재개, 통과하면 폴더 삭제, 계획 안 구현은 병렬 금지 «superpowers-sdd» — [취함] [→ OQ14]
- 분해를 별도 skill 로 뺀 superpowers 포크(원문 410, 색인 요약뿐) «decomposing-requirements-fork» — [중립] [→ 없음]

## 5. 기각 · Blind Spots

- 기각 — 인터뷰 분해를 한 번에 끝나는 최종 판정으로 두는 성질 → 하류 세 분해 자리의 재분해·축소가 지도 밖에서 조용히 일어난다(S11 드리프트 금지와 충돌) — verdict: refined — ST1 — 부착 10/10
- 기각 — 지휘자의 대화 맥락을 상태 정본으로 삼기와 「멈추지 않는다 = 어떤 경우에도 묻지 않는다」 해석 → 압축이 지휘 상태를 지우고 결정권 유지·P23 과 충돌, 사용자는 파일이 아니라 컨트롤 플레인으로 소비(S11) — verdict: refined — ST2 — 부착 5/5
- 기각 — 상한·압축 계열까지 「제거」 일률 적용, 무변경 유지 분기, 모델 재량의 「안전」 판정 근거 → 사용자 원문 S1(상한은 안전장치로·규모만 공시)·S4(수정이나)와 충돌, P2 의 「두꺼운 brief → 품질」 고리가 반증됨 — verdict: refined — ST3 — 부착 6/6
- 기각 — 원래 S1(확인) 문장의 뒤 절 「plan·구현은 멈추지 않고 쭉 간다」 / 재결정 S36 「외부가 묻는 plan 검토·실행 방식·머지 메뉴는 그대로 사용자에게」(앞 절 「조각마다 spec 승인」은 C48 로 유지) / 근거 S34·S17 외부를 건드리지도 어그러뜨리지도 않음
- 기각 — 원래 S10 「외부 장치도 제거·수정」 / 재결정 S17·S18 「외부는 그대로, devbrew 쪽 넘김 글과 결과 검사만」 / 근거 사용자 발화
- 기각 — 원래 S19 「실행 판정이 spec 과 어긋나면 그 조각만 멈춤」 / 재결정 S22 「보이기만, 구현 중 멈추지 않음」 / 근거 S21·S23·S24(실행 판정 이야기임을 사용자가 확인)
- 기각 — 문제의 뿌리를 하나로 골라 재구성하기 → 사용자가 「내말 그대로 … 전부다」로 거부하고 그 단계 자체를 제거 대상으로 지목(S6)
- 기각 — 원래 seed 「바깥 사례 조사의 웹 검색 1회 이상 기준이 조사를 묶는 제약」 / 재결정 그 기준은 하한이고 묶는 것은 예산·자격·리듬 / 근거 RC22 (plugins/spec-distill/skills/spec-interview/SKILL.md) [RC22 → 없음]
- 위험 — 숨은 가정: 장치를 없애면 늘 의도를 지키는 쪽으로만 작동한다 — 멈춤 판정의 주인이 조사하는 모델 자신으로 옮겨 무한 조사·조기 「충분」 선언이 사용자 모르게 열린다 — 근거 포화 개념의 불안정·조기 종료 실패 양식·무한 루프 사례
- 위험 — 숨은 가정: plan·구현을 쭉 가는 것과 왜곡 장치 제거가 서로 맞는다 — 실행 중 혼자 판정(Ruling)은 쭉 가게 하는 장치이고 plan 검토 게이트는 PM 이 plan 을 볼 마지막 자리 — 근거 superpowers SDD·brainstorming 원문
- 위험 — 숨은 가정: 사용자 말 그대로가 하류에서도 그대로 읽힌다 — brainstorming 은 자기 이해 요약을 새 정본으로 삼아 조각 N개면 N번 재해석 — 근거 Cognition 병렬 에이전트·brainstorming 원문
- 위험 — 숨은 가정: 인터뷰 시점에 나눈 경계가 맞고 하류가 따른다 — 하류의 2차 분해와 충돌하고 승인된 분해가 봉인되기 쉽다 — 근거 ADaPT·brainstorming 분해 문구
- 위험 — 숨은 가정: 한 세션이 압축을 여러 번 겪어도 의도와 조각 지도를 잃지 않는다 — 근거 Anthropic 장시간 하니스
- 위험 — 숨은 가정: 조각이 늘어도 spec 승인이 실질 검토로 남는다 — 도장 찍기로 쇠퇴 — 근거 승인 피로(근거 약함)
- 위험 — 숨은 가정: 찾은 장치 목록이 완전하고 전부 왜곡이다 — 사용자 자신의 통제 자리가 섞여 있고 모델은 사용자 말에 맞추는 경향 — 근거 Sycophancy 연구
- 위험 — 실패 양식: 병렬 조각의 암묵 결정 충돌과 버전·CHANGELOG 같은 공유 파일 겹침 — 근거 Cognition·Anthropic 멀티에이전트
- 위험 — 실패 양식: 압축 뒤 조각 지도·결정 내력 소실 또는 덮어쓰기로 「한 곳」이 실제와 어긋남 — 근거 Anthropic 장시간 하니스
- 위험 — 실패 양식: 두꺼운 brief 의 역설 — 가운데 묻힌 조사·위험·열린 질문을 하류가 덜 씀 — 근거 Lost in the Middle
- 위험 — 실패 양식: 외부 문구가 바뀌면 devbrew 쪽 넘김 글이 조용히 무력화됨(설치본과 최신본이 이미 다름) — 근거 superpowers 원문 비교
- 위험 — 실패 양식: 무한 조사 또는 포화를 가장한 조기 종료 — 근거 무한 루프 사례·조기 종료 실패 양식
- 위험 — 실패 양식: spec 승인 하나만 남은 통제점이 도장 찍기로 무너지고 실행 판정이 보이지 않음 — 근거 승인 피로(근거 약함)
- 위험 — 실패 양식: 승인된 분해가 봉인돼 조각 사이를 되돌릴 경로가 없음 — 근거 ADaPT·재결정 규약이 확정 항목 단위뿐
- 위험 — 리뷰 참고 | [overdesign] #2-제약 — 번호로 추적하는 장치가 다섯 결정(D24·D40·D41·D42·D45)에 나뉘고 번호 체계가 셋이다(D24·D42 의 빠짐 경고는 같은 검사) — 사용자 발화 S 번호에 매단 원장 하나와 spec 리뷰 검사 하나로 합치는 쪽을 설계에서 검토한다(판정은 모두 남기고 구조만 합침) (리뷰 41df26ba#r1.1)
- 위험 — 장치 | coverage-mapper 재호출 자격(열린 결정)·예산(1+재개방 합) — RC1 (plugins/spec-distill/skills/spec-interview/SKILL.md) [RC1 → OQ29]
- 위험 — 장치 | blind-spot-prober 재호출 자격·예산(1+그 차원 재개방) — RC2 (plugins/spec-distill/skills/spec-interview/SKILL.md) [RC2 → OQ29]
- 위험 — 장치 | 답 없는 조사 3회면 사용자 질문으로 강제(면제는 아직 안 닿은 열린 결정뿐) — RC3 (plugins/spec-distill/skills/spec-interview/SKILL.md) [RC3 → OQ29]
- 위험 — 사실 | 바깥 사례 조사 통과 기준은 웹 검색 1회 이상이고 round 1–2 에 하라고 한다 — RC4 (plugins/spec-distill/skills/spec-interview/SKILL.md) [RC4 → OQ29]
- 위험 — 장치 | 반론 세우기는 한 방향당 1회 — RC5 (plugins/spec-distill/skills/spec-interview/references/steelman.md) [RC5 → OQ29]
- 위험 — 장치 | 문서 리뷰 재검토 상한 2 — RC6 (plugins/spec-distill/references/reviewing-document.md) [RC6 → OQ29]
- 위험 — 장치 | overdesign 축의 「비기면 더 자르는」 사다리와 판정자당 3건 상한 — RC7 (plugins/spec-distill/references/docreview-profiles/design-doc.md) [RC7 → OQ29]
- 위험 — 이음매 | spec 리뷰 정답이 brief §2 확정 항목뿐이라 §3·§4·§5 의 사라짐을 대조하지 않는다 — RC8 (plugins/spec-distill/references/docreview-profiles/design-doc.md) [RC8 → OQ27]
- 위험 — 이음매 | /compact 보존 목록에 §4 조사·§5 위험이 없다 — RC9 (plugins/spec-distill/skills/spec-interview/references/finishing.md) [RC9 → OQ8]
- 위험 — 장치 | 하류에 이어받으라는 지시를 걸지 않고, 옵션 ② 넘김 문장이 외부 지시를 「~보다 우선한다」로 덮어쓴다 — RC10 (plugins/spec-distill/skills/spec-interview/references/finishing.md) [RC10 → OQ24]
- 위험 — 사실 | spec 하나에 우겨 넣기를 잡는 자리는 spec 리뷰 scope_creep 하나이고 설계 뒤에만 돈다 — RC11 (plugins/spec-distill/references/docreview-profiles/design-doc.md) [RC11 → OQ11]
- 위험 — 규칙 | cost_class high 는 지출 전 승인 게이트 필수 — RC12 (CLAUDE.md) [RC12 → OQ35]
- 위험 — 규칙 | Subagent spray 는 규모가 아니라 선언 없음을 금지 — RC13 (CLAUDE.md) [RC13 → OQ35]
- 위험 — 규칙 | Unbounded autonomy — 반복 상한·반복 감지·kill switch 셋 — RC14 (CLAUDE.md) [RC14 → OQ25]
- 위험 — 규칙 | 플러그인 state 는 세션별·git 밖·성공 시 삭제 — RC15 (CLAUDE.md) [RC15 → OQ20]
- 위험 — 결정 | 자격·예산·면제는 2026-09-22 설계 §F 가 정했다 — 뒤집으면 재결정 기록 필요 — RC16 (docs/superpowers/specs/2026-09-22-interview-research-specialization-design.md) [RC16 → OQ29]
- 위험 — 장치 | 인터뷰 종료 옵션 ① 은 /compact 뒤 턴 종료, 사람이 유일한 운반자 — RC17 (plugins/spec-distill/skills/spec-interview/references/finishing.md) [RC17 → OQ19]
- 위험 — 규칙 | 모든 dispatch 자리에 처분 줄이 필요하고 테스트가 집행 — RC18 (shared/tests/test_dispatch_disposition.sh) [RC18 → OQ32]
- 위험 — 장치 | Phase 0 은 웹을 보지 않아 인터뷰 조사 상한이 사슬 전체의 바깥 조사 상한 — RC19 (plugins/spec-distill/skills/request-framing/SKILL.md) [RC19 → OQ29]
- 위험 — 사실 | spec 리뷰 게이트 ③ 에 인터뷰 재진입 경로가 있다 — RC20 (plugins/spec-distill/skills/spec-review/SKILL.md) [RC20 → OQ17]
- 위험 — 장치 | 재개방은 충돌 때만 일어나 충돌 없는 인터뷰에서 조사 장치는 사실상 1회 — RC21 (plugins/spec-distill/skills/spec-interview/SKILL.md) [RC21 → OQ29]
- 위험 — 장치 | 레포 조사는 subagent 금지, subagent 자리는 셋뿐 — RC23 (plugins/spec-distill/skills/spec-interview/SKILL.md) [RC23 → OQ29]
- 위험 — 장치 | 같은 주제 되묻기 2회 상한 — RC24 (plugins/spec-distill/skills/spec-interview/SKILL.md) [RC24 → OQ29]
- 위험 — 장치 | floor 다섯이 닫히면 종료, 포화를 보는 조건 없음 — RC25 (plugins/spec-distill/skills/spec-interview/references/finishing.md) [RC25 → OQ29]
- 위험 — 사실 | 사용자가 종료를 요청하면 덜 채운 floor 를 박제로 닫는다 — RC26 (plugins/spec-distill/skills/spec-interview/SKILL.md) [RC26 → 없음]
- 위험 — 이음매 | brainstorming 은 brief frontmatter 를 읽지 않는다 — 전달은 산문뿐 — RC27 (plugins/spec-distill/skills/spec-interview/references/finishing.md) [RC27 → OQ8]
- 위험 — 장치 | brief §2 로 올릴 제약을 모델이 고른다 — RC28 (plugins/spec-distill/skills/spec-interview/references/finishing.md) [RC28 → OQ29]
- 위험 — 장치 | 확정 목록 수정 2회 뒤 전 항목 강등·종료 — RC29 (plugins/spec-distill/skills/spec-interview/references/finishing.md) [RC29 → OQ29]
- 위험 — 장치 | 압축 규약이 「하류가 정할 수 있는 것」 등을 깎는다 — RC30 (plugins/spec-distill/references/compression.md) [RC30 → OQ29]
- 위험 — 장치 | Phase 0 은 확산 뒤 압축, seed 로 나가는 것은 깎은 것뿐 — RC31 (plugins/spec-distill/skills/request-framing/SKILL.md) [RC31 → OQ29]
- 위험 — 장치 | seed 리뷰에는 빠짐(omission) 범주가 없다 — RC32 (plugins/spec-distill/references/docreview-profiles/seed.md) [RC32 → OQ29]
- 위험 — 장치 | brief 리뷰는 빠짐을 찾아도 fix 는 §0·§2 에만 낼 수 있다 — RC33 (plugins/spec-distill/references/docreview-profiles/brief.md) [RC33 → OQ29]
- 위험 — 규칙 | 정체 시 재시도 대신 다른 접근(P18) — RC34 (docs/philosophy/devbrew-harness-philosophy.md) [RC34 → OQ25]
- 위험 — 락 | 조사 장치 예산 식이 테스트 락으로 고정 — RC35 (plugins/spec-distill/tests/test_conducting_interview_stage.sh) [RC35 → 없음]
- 위험 — 락 | 구조 게이트는 coverage-mapper 하한만 검사 — RC36 (plugins/spec-distill/scripts/check_brief.py) [RC36 → 없음]
- 위험 — 상태 | SessionEnd 정리 + 24시간 TTL-GC — RC37 (plugins/spec-distill/hooks/session-end-cleanup.py) [RC37 → OQ20]
- 위험 — 규칙 | 플러그인 PR 마다 SemVer bump — 병렬 조각이 같은 파일에서 겹침 — RC38 (CLAUDE.md) [RC38 → OQ13]
- 위험 — 장치 | brief §4 조사 항목은 한 줄 형식 — RC39 (plugins/spec-distill/templates/interview-brief-template.md) [RC39 → OQ29]
- 위험 — 외부 | brainstorming 이 큰 일을 나눈 뒤 첫 조각만 설계 — RC40 (레포 밖 superpowers 6.4.1 brainstorming) [RC40 → OQ24]
- 위험 — 외부 | brainstorming 의 YAGNI ruthlessly — RC41 (레포 밖 superpowers 6.4.1 brainstorming) [RC41 → OQ24]
- 위험 — 외부 | spec 자체 점검에서 모호하면 혼자 하나를 고른다 — RC42 (레포 밖 superpowers 6.4.1 brainstorming) [RC42 → OQ24]
- 위험 — 외부 | 작은 일(Bounded)로 분류하면 spec 파일 없음 — RC43 (레포 밖 superpowers 6.4.1 brainstorming) [RC43 → OQ24]
- 위험 — 외부 | spec 작성에 간결체 skill — RC44 (레포 밖 superpowers 6.4.1 brainstorming) [RC44 → OQ24]
- 위험 — 외부 | writing-plans 의 YAGNI·늦은 Scope Check — RC45 (레포 밖 superpowers 6.4.1 writing-plans) [RC45 → OQ24]
- 위험 — 외부 | brief 를 받아도 명확화 질문부터 다시 — RC46 (레포 밖 superpowers 6.4.1 brainstorming) [RC46 → OQ24]
- 위험 — 외부 | SDD 는 충돌·모호를 혼자 판정하고 기록 파일에만 Ruling 을 남긴다 — RC47 (레포 밖 superpowers 6.4.1 subagent-driven-development) [RC47 → OQ10]
- 위험 — 장치 | 문제 재구성 의례 「seed 의 문장을 되풀이하는 것은 통과가 아니다」 — RC48 (plugins/spec-distill/skills/spec-interview/SKILL.md) [RC48 → OQ1]
- 위험 — 장치 | brief 리뷰에도 yagni·shrink 절감 태그와 판정자당 3건 상한 — RC49 (plugins/spec-distill/references/docreview-profiles/brief.md) [RC49 → OQ29]
- 위험 — 장치 | 「지출 통제는 엔진의 재리뷰 상한이 한다」 — 비용 이유의 품질 상한 — RC50 (plugins/spec-distill/skills/spec-interview/references/finishing.md) [RC50 → OQ29]
- 위험 — 장치 | qg 리뷰어 8명·수정 루프 5회 상한 — RC51 (plugins/quality-gates/skills/quality-pipeline/SKILL.md) [RC51 → OQ29]
- 위험 — 판정 필요 | qg 재비판의 lower(이 변경이 하지 않은 일 처방 낮춤) — 의도 보호 쪽일 수 있음 — RC52 (plugins/quality-gates/agents/code-recritic.md) [RC52 → OQ29]
- 위험 — 장치 | project-init 재질문 3회 뒤 단계 강등 — RC53 (plugins/project-init/skills/project-init/SKILL.md) [RC53 → OQ29]
- 위험 — 판정 필요 | plugin-audit 가 근거 약한 gap 을 버림 — 정밀도 필터일 수 있음 — RC54 (plugins/plugin-audit/agents/plugin-auditor.md) [RC54 → OQ29]
- 위험 — 장치 | 선택지 라벨을 1–5 낱말로 압축 — RC55 (plugins/spec-distill/references/reviewing-document.md) [RC55 → OQ29]
- 위험 — 장치 | 재리뷰 상한이 코드에 박혀 있고 상한·정체면 열린 지적이 있어도 승인 게이트가 열린다 — RC56 (shared/docreview/scripts/docreview_state.py) [RC56 → OQ29]
- 위험 — 장치 | 리뷰 조언 표시 8줄 뒤 접기 — RC57 (shared/docreview/scripts/docreview_advice.py) [RC57 → OQ29]
- 위험 — 장치 | qg 산출물 비평 기본 5라운드 — RC58 (plugins/quality-gates/skills/critiquing-artifacts/SKILL.md) [RC58 → OQ29]
- 위험 — 사실 | 재개방 무상한의 근거는 「사용자가 시계다」 — RC59 (plugins/spec-distill/skills/spec-interview/SKILL.md) [RC59 → OQ29]
- 위험 — 상태 | 오래 남을 정보를 세션 state 에 두지 않은 선례(TTL-GC 24시간) — RC60 (plugins/spec-distill/skills/request-framing/SKILL.md) [RC60 → OQ20]
- 위험 — 사실 | 재결정 규약은 확정 항목 단위이고 분해·조각 사이 피벗은 다루지 않는다 — RC61 (plugins/spec-distill/references/proceed-gate.md) [RC61 → OQ17]
- 위험 — 선례 | qg PR 코멘트는 상시 동의 + kill switch — RC62 (docs/philosophy/devbrew-harness-philosophy.md) [RC62 → OQ35]
- 위험 — 규칙 | 확정된 결정도 반증 대상(P23) — RC63 (docs/philosophy/devbrew-harness-philosophy.md) [RC63 → OQ28]
- 위험 — 선례 | upfront 범위 고지 게이트를 지출 전 승인으로 침 — RC64 (plugins/quality-gates/skills/critiquing-artifacts/SKILL.md) [RC64 → OQ35]
- 위험 — 사실 | 재리뷰 상한을 넘으면 사용자가 자기 문구로 라운드를 연다 — RC65 (shared/docreview/scripts/docreview_state.py) [RC65 → OQ29]
- 위험 — 사실 | overdesign 「자르지 않는 것」에 사용자가 명시로 요청한 동작이 있다 — RC66 (plugins/spec-distill/references/docreview-profiles/design-doc.md) [RC66 → OQ29]
- 위험 — 사실 | steelman 은 새 근거가 있으면 다시 부를 수 있다 — RC67 (plugins/spec-distill/agents/steelman-builder.md) [RC67 → OQ29]
- 위험 — 이음매 | 종료 경로가 brief 하나를 brainstorming 하나로만 넘긴다 — RC68 (plugins/spec-distill/skills/spec-interview/references/finishing.md) [RC68 → OQ21]
- 위험 — 사실 | 목표·범위를 바꾸는 수정은 사용자 결정(decide)으로 간다 — RC69 (plugins/spec-distill/references/docreview-profiles/design-doc.md) [RC69 → OQ27]
- 위험 — 사실 | 인터뷰에는 분해 판단 자리가 없다(검색 기준, 하한) — RC70 (plugins/spec-distill/skills/spec-interview) [RC70 → OQ17]
- 위험 — 흐름 | 미머지 「다음 세션 @ 명령」 브랜치가 종료 ①·② 를 모두 턴 종료로 바꾸고 여러 파일 넘김을 규칙에 넣는다 — RC71 (docs/superpowers/specs/2026-10-11-next-session-at-handoff-design.md (feature/next-session-at-handoff)) [RC71 → OQ19]
- 위험 — 흐름 | qg 쉬운 말 PR 3 미머지 — RC72 (feature/plain-language-voice) [RC72 → OQ31]
- 위험 — 흐름 | qg v10 ⑤ 차등 테스트 미머지 — RC73 (feature/qg-v10-differential) [RC73 → OQ31]
- 위험 — 이음매 | spec 리뷰 정답 출처 source_interview 를 채우는 쪽이 없다 — RC74 (plugins/spec-distill/references/docreview-profiles/design-doc.md) [RC74 → OQ27]
- 위험 — 이음매 | spec 리뷰 호출에 brief 가 실리지 않는다 — RC75 (plugins/spec-distill/skills/spec-review/SKILL.md) [RC75 → OQ27]
- 위험 — 이음매 | qg 의도 앵커는 커밋 Spec: 표시 — spec-distill 은 쓰지 않는다 — RC76 (plugins/quality-gates/scripts/discover-spec.sh) [RC76 → OQ31]
- 위험 — 흐름 | qg ⑤ 가 spec_path 등을 지우고 의도 출처 필드만 남긴다 — RC77 (docs/superpowers/plans/2026-10-08-qg-v10-c5-differential.md) [RC77 → OQ31]
- 위험 — 게이트 | 구조 게이트는 interview-brief 타입 하나만 받는다 — RC78 (plugins/spec-distill/scripts/check_brief.py) [RC78 → OQ33]
- 위험 — 이음매 | spec 승인 뒤 「지휘자로 돌아가 다음 조각」 길이 없다 — RC79 (plugins/spec-distill/skills/spec-review/SKILL.md) [RC79 → OQ17]
- 위험 — 선례 | 훅 배달지 실측(TaskCreated 등)이 이미 있다 — RC80 (docs/superpowers/specs/2026-08-05-agent-transparency-design.md) [RC80 → OQ34]
- 위험 — 흐름 | 옛 훅 쓰기 경로 계획이 지금 없는 파일을 전제 — 고아 여부 확인 필요 — RC81 (docs/superpowers/plans/2026-08-23-hook-write-path-bypass.md) [RC81 → 없음]
- 위험 — 범용 | 브랜치 이름 검증이 Bash 명령에만 걸려 네이티브 worktree 브랜치는 우회 — RC82 (plugins/project-init/hooks/post-tool-use.py) [RC82 → OQ33]
- 위험 — 의존 | superpowers 의존이 최소 버전 없이 optional 로만 선언 — RC83 (plugins/spec-distill/README.md) [RC83 → OQ33]
- 위험 — 규칙 | P22 Cost Awareness — fan-out 선언·high 면 지출 전 승인 — RC84 (docs/philosophy/devbrew-harness-philosophy.md) [RC84 → OQ35]
- 위험 — 흐름 | qg 진입 이름(진입 표면)이 미결 — RC85 (docs/superpowers/specs/2026-10-09-skill-only-surface-qg-handoff.md) [RC85 → OQ31]

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > ---
  > type: interview-seed
  > next_phase: spec-distill:spec-interview
  > audit_file: 2026-10-11-interview-explore-decompose-interview.audit.md
  > ---
  >
  > spec-distill 로 일을 맡기면 결과물의 품질이 조용히 크게 떨어지고 내 의도와도 어긋난다. 품질 저하는 brief 가 얇은 것, spec 하나에 일이 우겨 넣어지는 것, 무엇이 빠졌는지 경고 없이 생략되는 것 세 곳에서 가장 크게 나타난다. (사용자 확인) 의도 어긋남은 주로 brief 가 brainstorming 으로 넘어가는 이음매에서 생긴다. (사용자 확인) brief 가 brainstorming 으로 넘어갈 때 brief 의 조사·열린 질문·위험이 spec 에서 사라지고, spec 하나에 맞추느라 범위가 줄거나 바뀐다. (사용자 확인)
  >
  > 내가 보는 원인은 둘이다. 첫째, 인터뷰가 다섯 floor 를 한 번 채우면 닫고, 조사에 제약이 너무 많아 맥락이 매우 부족한 상태로 넘어간다. 풀고 싶은 제약은 조사 장치의 호출 예산과 자격, 사용자 질문 리듬 강제, 그리고 조사에 서브에이전트를 정해진 몇 자리에서만 제한적으로 쓰는 것이다. (사용자 확인) 둘째, 큰 문제를 spec 하나로 처리하려다 보니 한 spec 에 우겨 넣거나 할 일을 미룬다. 여러 spec 이 나오는 것이 자연스럽고, 그래야 더 상세히 명세될 것 같다.
  >
  > 원하는 모양은 세 갈래다. 먼저 인터뷰는 한 번에 닫지 않고 집요하게 탐색한다. 끈질긴 조사는 한 번 더 조사해도 결정에 닿는 새 사실이 없을 때 멈추고, 횟수 상한은 안전장치로만 둔다. (사용자 확인) 비용을 이유로 품질을 제약하는 장치는 제거하고, 크게 쓰기 전에는 규모만 알린다. (사용자 확인)
  >
  > 다음으로 인터뷰가 PM 역할을 맡는다. 이 일이 구현 spec 하나로 되는지 판단하고, 크면 순서를 나눠 일을 하류로 나눠 넘긴다. 나누기는 인터뷰가 조각·순서·병렬 여부를 제안하고 사용자가 고치거나 승인한 뒤에만 일어난다. (사용자 확인) brief 를 여러 개로 만들어 서로 링크하는 것이 내 첫 생각이지만, 더 자연스러운 방법이 있을 수도 있다 — 그 모양은 열어 둔다.
  >
  > 마지막으로 나뉜 조각은 순차 또는 병렬로 각각 brainstorming → spec → plan → 구현을 거친다. 목적은 태스크마다 충분한 설계를 붙여 긴 작업을 쭉, 그리고 병렬로 맡기는 것이다. 조각들은 한 세션이 지휘해 끝까지 끌고 가되, PM 인 사용자의 결정권과 내용 검토가 유지돼야 하며 그 통제가 무너지면 실패다. (사용자 확인) 사용자 확인은 조각마다 spec 승인에서 받고, plan·구현은 멈추지 않고 쭉 간다. (사용자 확인) 통제가 살아 있다는 것은 전체 조각과 순서·의존, 각 조각이 어느 단계에 있는지를 한 곳에서 볼 수 있다는 것이다. (사용자 확인)
  >
  > 이번 seed 는 세 갈래를 한 번에 넘기고, 다음 인터뷰가 PM 처럼 순서를 정해 나눈다. (사용자 확인)
  >
  > 다시 검증할 것 — 제약의 실체는 Phase 0 이 인터뷰 skill 을 읽고 본 것뿐이다: 조사 장치 둘(coverage-mapper · blind-spot-prober)의 「1 + 재개방 수」 예산과 「열린 결정이 있어야 다시 부른다」는 자격, 사용자 답 없는 조사가 세 번 이어지면 사용자 질문으로 강제로 돌아가는 리듬 규칙, 바깥 사례 조사의 「웹 검색 1회 이상」 기준. 이것이 전부인지, brainstorming·spec 리뷰·plan 쪽에도 품질을 묶는 제약이 있는지는 보지 않았다. brief 에서 brainstorming 으로 넘어갈 때 내용이 빠지고 범위가 바뀌는 원인도 확인하지 않았다 — brainstorming 과 plan 쪽은 외부 플러그인이라 devbrew 가 손댈 수 있는 자리가 핸드오프 쪽뿐일 수 있다. 「규모만 알리고 진행」·「포화까지 조사」·「한 세션이 길게 지휘」가 레포의 기존 금지 규칙(선언 없는 대규모 fan-out, 멈출 조건 없는 자율 루프, 큰 비용 skill 의 지출 전 승인)과 어떻게 맞물리는지 — 규칙 안에서 설계할지 규칙을 고칠지 — 는 열려 있다. 「경고 없이 생략」은 품질 증상으로 골랐지만 통제 표면으로는 「조각 지도와 상태」만 골랐다; 생략 경고가 덜 중요하다는 뜻인지는 묻지 않았다. 포화를 무엇으로 판정할지, 안전장치 상한 값, spec 하나로 되는지의 판단 기준, 조각 사이에서 큰 그림과 의도를 어떻게 지킬지, 조각 지도가 어디에 사는지는 정하지 않았다.

## 7. Next Action

승인된 로드맵(S47)대로 간다. 조각마다 「원본 brief(이 문서) + 로드맵 + 조각 묶음」(S39)을 넘기고, 사용자 확인은 외부가 묻는 자리 그대로(S36), 실행 판정은 컨트롤 플레인에 보이기만 한다(S22).

1. 선행 — 「다음 세션 @ 명령」 브랜치(`feature/next-session-at-handoff`)를 먼저 구현·머지한다(S37). qg ⑤(`feature/qg-v10-differential`)·qg 쉬운 말 PR 3(`feature/plain-language-voice`) 머지와 qg 진입 이름 결정은 qg 를 건드리는 조각(R2a·R5 의 qg 연결)보다 앞선다. 옛 훅 쓰기 경로 계획이 고아인지 확인한다.
2. R0 — 실측(한 세션 skill 이어 부르기 · 작업 목록 표시 · 외부 정지 지점) + 공통 형식 다섯(① 조각 묶음·번호 ② 로드맵 ③ 컨트롤 플레인 데이터 ④ spec 리뷰에 넘길 정답 ⑤ 커밋 Spec: 표시) + 걷는 뼈대 + 락 지도·진행 중 흐름 충돌표.
3. R0 뒤 병렬(같은 파일은 경로 예약으로 직렬): R1 인터뷰 탐색 개편 · R2 spec-distill 안쪽 압축·리뷰 장치 · R7 상태 저장 재설계 흡수 · R3 번호 인계·대조·깊이(덮어쓰기 문장 제거, /compact 보존에 조사·위험, spec 리뷰 정답 연결) · R4 PM 분해·로드맵·조각 묶음·재분해 경로 · R6 컨트롤 플레인.
4. R2a 공유 리뷰 엔진(qg 파급 + persona 보안 리뷰)과 R5 지휘자(외부 정지는 사용자에게, 실행 기록 회수, 재개·부분 계속, 머지 원칙 7·qg 의도 회귀, 조각 사이 이음매·base 이동) — qg 선행 뒤.
5. R8 의존 선언·부재 시 강등·devbrew 밖 경로 → R9 규칙·문서(CLAUDE.md · 철학 P22 · README · CHANGELOG) — 조각마다 + 마지막 정리. 버전은 머지 직전에 정한다.

superpowers 가 있으면 첫 조각(선행의 @ 브랜치는 이미 설계·계획이 있으니 그 계획 실행, 이어 R0)을 `superpowers:brainstorming` 으로 시작해 설계문서 → `spec-distill:spec-review` → 승인 게이트 → `superpowers:writing-plans` 순서로 간다. 없으면 이 brief 와 로드맵이 완결 산출물이다.
