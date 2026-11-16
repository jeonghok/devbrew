---
type: interview-audit
payload: 2026-11-15-existing-framework-first-brief-interview.md
created_at: 2026-11-15
session_id: 35da5fc5-5b17-4b82-9b35-92c29a78d217
source: spec-distill pm-interview
---

# Existing Framework First — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — S1(첫 요청 원문과 Phase 0 확인 문장) + S2 원인 넷의 선택 — 검토가 형식에 그친 원인: 만드는 쪽이 쉬운 길 · 결론을 읽는 눈이 없음 · 바깥을 안 찾음 · 레포 규칙에 막힘
- floor:landscape — closed — S4 「보여 주는 정보로 (권장)」 · S5 「보이고 고른다 (권장)」 · S6 반론 검토 「보완」 — 외부 근거의 처분: 문턱 없는 평가 지침 취함, 문턱형 · 일괄 금지형 피함, 한쪽 승인 선례는 재료로
- floor:skepticism — closed — S6 ST1 판정 「보완」 — 원안 뼈대는 두고 탐색 증거 · 의존 쪽 이유 인정 · 읽는 눈이 있는 자리를 붙임
- floor:blind_spot — closed — S8 숨은 가정 · 실패 양식의 처분 — 승인이 도장이 됨 · 틀린 후보 · 구현에서 다시 만듦을 설계 필수로, 과하게 들임 · 고장 전가는 고르지 않음
- floor:open_questions — closed — S14 「넷 다 설계로 (권장)」 + S15 「포화로 보고 종료 (권장)」 — 열린 질문 다섯(OQ7 · OQ8 · OQ10 · OQ13 · OQ14)을 설계로 넘김 (재개방 1회 — 조사 10 이 Phase 0 선택지의 설명이 audit 에 없음을 보였고 본체가 이 세션 전사에서 그 설명을 되찾아 OQ9 가 이미 답이 걸린 결정임을 확인했다. 포화 판정이 OQ11 을 새로 열었다. 닫은 뒤 brief 리뷰 1라운드에서 OQ12 를 다시 열고 OQ15 를 새로 열어 3라운드에서 OQ16 을 새로 열어 지금 열린 질문은 여덟이다 — 모두 설계로 넘긴다)
- derived:internal_research — closed — 내부(레포) 조사 축 — 조사 1~5 가 레포 주장을 처음 산출; S2 레포 주장의 처분(조사가 레포에서 찾은 원인 넷을 받음)
- derived:rule_carrier — closed — 규칙의 운반 자리 — 다른 레포 도달 · 외부 소유 단계 · 인터뷰를 거치지 않는 일; S3 「단계 안에서만 (권장)」
- derived:conclusion_judge — closed — 결론을 판정하는 쪽과 효과 관측; S2 「결론을 읽는 눈이 없음」 + S6 보완(읽는 눈이 있는 자리) + S13 「넣는다 (권장)」(마지막 리뷰에서 고른 것을 썼는가)
- derived:fit_judgment — closed — 「맞는」 판정과 부분 적합, 범주마다 다른 검증 기준의 뜻; S4 기준은 보여 주는 정보 + S6 보완(후보마다 맞음 판정을 적는다) + S7 안정 단계 한 칸
- derived:adoption_cost_asymmetry — closed — 채택 비용의 비대칭; S2 「만드는 쪽이 쉬운 길」 + S6 보완(의존 쪽 비용을 이유로 인정) + S12 「묶어서 한 번 (권장)」
- derived:touch_trigger — closed — 「고칠 때 함께 본다」의 발동 지점과 크기 하한; S9 「설계를 거치는 고침만 (권장)」

## 2. Budget

- 질문 라운드: 6 · agent dispatch: 14 · coverage-mapper 1 · codex 실호출: 0 (성공 0)
- 조사 호출 12/60 (장치별: 커버리지 1 · 맹점 1 · 반론 1 · 레포 조사 4 · 만든 조사 5 · 본체 직접 17)
- 포화 판정 1: 아직 — 빈 곳 5개
- 포화 판정 2: 아직 — 빈 곳 6개
- 포화 판정 2: 사용자 판단 포화(@S15) — 반복 빈 곳

## 3. Steelman 원문

#### ST1 — 「쓰는 것이 기본, 직접 만들려면 이유와 승인」 방향의 반론 검토

**dispatch 입력** — goal: S1 · 전제: P1 직접 만든 스크립트와 테스트는 유지 부담을 낳고 직접 만든 장치에서 버그가 되풀이되며 새 장치를 만드는 데 시간이 든다 — 있는 프레임워크 위에서 만들면 이 셋이 줄어든다(S1 · 줄어든다는 부분은 orchestrator 도출) · P2 검증된 프레임워크(공식 제공 · 널리 쓰임 · 유지 중)는 직접 만든 것보다 믿을 수 있다(S1 · orchestrator 도출) · P3 맞는 프레임워크가 실제로 있는 경우가 있었는데도 검토했다고 적기만 하고 결론은 늘 직접 만들기였다(S1) · P4 기본값을 「쓰는 것」으로 두고 직접 만들 때 이유와 사용자 승인을 요구하면 결론이 실제로 달라진다(S1 · 달라진다는 부분은 orchestrator 도출) · P5 외부 것의 사용자 승인을 그대로 두어도 「쓰는 것이 기본」과 함께 설 수 있다(S1) · P6 이 방식은 devbrew 전용 값이나 특정 프레임워크 이름에 묶이지 않고 어느 레포에서든 통한다(S1) · 제약: S1 원문 전량(dispatch 시점의 발화 전부 — S2~S5 는 dispatch 뒤에 왔다) · trigger: 기존 사용자 제약과의 충돌(2026-11-13 확정 「특정 외부 도구에 하드코딩되거나 의존이 생기는 것은 피한다」 · 2026-10-17 외부 파서를 테스트에서만 쓰기로 한 결정) + landscape 모순(들이는 쪽에 부담을 두는 선례 · 공급망 위험 · 에이전트 프레임워크 벤더 글)

> ```yaml
> case_for_alternative:
>   statement: "기본값을 결론 한 곳이 아니라 의존의 거리로 나눈다 — 플랫폼 기본 기능과 이미 의존으로 적힌 것 위에서 만드는 것만 「쓰는 것이 기본」으로 두고, 새 외부 의존(남의 플러그인 · skill · 패키지)은 방향 기본값 없이 쓰기와 만들기 양쪽에 같은 비용표를 요구해 사용자가 고르며, 강제는 결론이 아니라 «후보를 실제로 찾았다는 증거»에 건다(승인은 지금처럼 둔다)."
>   strongest: |
>     goal 은 「있는 프레임워크」가 아니라 「검증된 프레임워크 위에서」다. 새 외부 의존을 들이는 쪽에 증명 책임을 지우는 것이 큰 프로젝트의 표준이다 — Chromium 은 동기 · 검토한 대안 · 보안 · 유지 책임 · 무게를 적어 두 곳의 승인을 받게 하고, Kubernetes 는 「의존 없이 할 수 있는가 · 이미 비슷한 의존이 있는가」를 묻는다. 공식 · 널리 쓰임 · 유지 중 셋을 다 넘은 xz 가 공식 릴리스에 백도어를 실었고, Anthropic 공식 마켓플레이스조차 「의도대로 동작하는지 · 바뀌지 않는지 확인할 수 없다」고 적는다.
>     이 레포의 기록에서 고장 난 곳은 결론이 아니라 탐색이다. 설계 다섯이 바깥 칸을 「새 외부 패키지는 쓰지 않는다」 한 줄로 닫았고 어떤 후보를 찾았는지 적지 않았다. 후보가 비어 있으면 「맞는 프레임워크가 있으면」이라는 조건절이 거짓이 되어 결론 기본값은 발동하지 않는다 — 「쓰는 것이 기본」은 같은 저자가 「맞는 것 없음」 한 줄로 지나간다. 이유를 대게 하는 제도는 내용 기준이 없으면 상투 문구로 굳는다(comply-or-explain 실증).
>     배포 구조도 대안 편이다. 플러그인은 어느 레포에나 깔리므로 런타임 의존 하나가 모든 소비 레포의 환경에 생긴다. Claude Code 는 Python 의존을 자동으로 깔아 주지 않고, plugin.json 의존은 못 풀리면 그 플러그인이 로드되지 않으며, 판을 고정하지 않은 의존은 상류가 이름을 바꾸는 순간 모든 사용자에게서 깨진다. 같은 사용자가 C5(특정 외부 도구 의존을 피한다)와 B2(외부 패키지는 테스트에서만 — 사용자 환경에 의존이 생기므로)에서 이 비용을 이미 결정 근거로 썼다. 맞지 않는 추상에 끼워 맞춘 비용은 중복보다 크고(Metz), 작은 필요에는 복사가 의존보다 낫다(Cox). 그래서 goal 의 「직접 만드는 것 최소화」는 플랫폼 기본 기능과 이미 든 의존에서 가장 싸게 이뤄지고, 거기에만 방향 기본값을 두는 편이 유지 부담 · 되풀이 버그 · 시간이라는 계기 셋을 실제로 줄인다.
> case_for_current:
>   strongest: |
>     goal 의 낱말은 「최대한」과 「가능한 최소화」다. 방향 없는 양쪽 비교는 지금 규칙(「검토한다」) 그대로이고, 그 규칙 아래 `## 있는 것 검토` 절이 있는 설계 아홉 가운데 새 외부 것을 들인 것은 하나도 없다. 만드는 쪽에는 구조적 홈 이점이 있다 — 모델에게 새 코드를 쓰는 것은 그 순간 가장 싼 길이고, AI 보조 이후 옮겨 다시 쓴 줄(재사용의 대리 지표)이 2021년 24.8% 에서 2024년 9.5% 로 줄었다는 측정이 있다. 이 기울기를 되돌리는 것은 증명 책임의 방향뿐이고, 기본값은 58개 연구 메타분석에서 d=0.68 로 선택을 옮긴다.
>     원안은 지금 흐름의 구멍 하나를 정확히 막는다. 의존 이식성 설계는 공식 Claude Code 기능 둘(plugin.json 의존 · userConfig)을 후보로 보고도 지휘자 판단으로 기각한 뒤 같은 일을 직접 만들었고, 그 기능을 쓸지 사용자에게 물은 기록이 없다. 「직접 만들려면 이유 + 사용자 승인」은 이 조용한 기각을 사용자 앞의 결정으로 바꾼다 — 「새 외부 패키지는 쓰지 않는다」 한 줄이 더는 승인 없이 설 수 없다.
>     trigger 의 landscape 모순은 원안을 뒤집지 못한다. Chromium 문서의 첫 문장은 「제3자 코드 사용은 시간을 아끼고 우리 가치와 맞다 — 바퀴를 다시 만들 필요가 없다」이고 그 위에 승인 절차를 얹는다. 재사용이 기본 가치인 것과 들일 때 승인받는 것은 한 문서 안에서 함께 선다 — 원안의 P5 가 바로 그 구조다. 공급망 위험과 환각 패키지는 그대로 둔 외부 승인이 받는다. 체계적 재사용은 산업 연구 다섯에서 낮은 결함 밀도와, 셋에서 수정 노력 감소와 유의하게 묶였고, 오래 쓰인 기술은 고장 방식이 알려져 있으며 운영 비용이 만들 때의 불편을 압도한다. 벤더의 「API 를 직접 쓰는 데서 시작하라」는 에이전트 프레임워크 이야기이고, 사용자는 그 범주를 고르지 않았다.
> premise_refutation:
>   hits: [P2]
>   why: |
>     P2 — 「검증된 프레임워크(만든 쪽이 공식으로 내고 · 널리 쓰이고 · 지금도 유지되는 것)는 직접 만든 것보다 믿을 수 있다」는 세 기준을 넘으면 기반으로 믿을 수 있다는 문장인데, 세 기준을 넘는 것을 같은 사용자 · 같은 레포가 기반으로 믿지 않기로 한 기록과 직접 충돌한다.
>     (1) docs/superpowers/specs/2026-10-15-roadmap-control-plane-design.md 「실험 기능은 기반으로 쓰지 않는다(D33)」와 docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md 「기각 — agent 팀을 일꾼 기반으로 → 리드 고정 · 재개 불가로 지휘 세션 리프레시와 충돌하는 실험 기능(S4)」. agent 팀은 Anthropic 이 공식으로 내고 지금도 유지하는 Claude Code 기본 기능이고, 공식 문서(https://code.claude.com/docs/en/agent-teams)가 「experimental and disabled by default … known limitations around session resumption, task coordination, and shutdown behavior」라고 적는다. 세 기준에는 이것을 걸러 낼 축이 없다.
>     (2) 같은 brief 의 「기각 — 헤드리스 claude -p 를 일꾼 기본으로 → Skill 도구 거부 · 실패가 rc 0 으로 숨음(S4)」와 docs/superpowers/specs/2026-10-20-dependency-portability-design.md 「기각: Claude Code plugin.json `dependencies`(superpowers 가 없으면 spec-distill 전체가 꺼진다 — U6 과 충돌) · Claude Code `userConfig`(레포 단위로 둘 수 없고 Bash 명령 환경에 없다)」. 넷 다 공식 · 유지 중인데 기각 사유는 믿음의 문제(실패가 숨는다)이거나 맞음의 문제(레포 단위로 못 둔다)였다.
>     (3) https://research.swtch.com/xz-timeline — xz 는 세 기준을 모두 넘었고 공식 상류 릴리스 5.6.0 · 5.6.1 에 백도어가 실렸다. https://github.com/anthropics/claude-plugins-official 은 공식 마켓플레이스에 대해 「Anthropic does not control what MCP servers, files, or other software are included in plugins and cannot verify that they will work as intended or that they won't change」라고 적는다.
>     충돌의 범위는 「세 기준이면 충분하다」까지다. 재사용이 평균적으로 결함을 줄인다는 근거(Mohagheghi · Conradi)는 그대로 서므로 P2 는 버려지지 않고 기준이 다듬어진다 — 세 기준은 필요조건이고, 인터페이스 안정(실험 딱지) · 실패가 드러나는가 · 일에 맞는가가 빠져 있다.
> premise_list_challenge: |
>   결함 넷과 공시 둘이다.
>   (1) 빠진 전제 — 「프레임워크에 기대서 생기는 비용(사용자 환경에 생기는 의존 · 특정 도구 종속 · 상류 판 변동 · 없을 때의 길)이 직접 만드는 비용보다 작다」. P1 은 장부의 한쪽(직접 만든 것의 비용)만 적는다. trigger 의 C5 와 B2 는 P1~P6 어느 문장과도 직접 충돌하지 않는다 — 둘이 충돌하는 상대는 목록에 없는 이 전제다. 같은 사용자가 2026-10-17(B2) · 2026-11-14(C5)에 이 비용을 이유로 만드는 쪽을 골랐으므로, 이 전제를 세우지 않으면 새 규칙 아래서 그 두 결정이 그대로인지 뒤집히는지 판정할 수 없다.
>   (2) P4 는 지렛대 둘을 하나로 적었다 — 결론의 방향(기본값)과 후보 탐색. 레포 기록에서 형식에 그친 것은 바깥 칸의 탐색이고(다섯 설계가 후보 없이 한 줄로 닫음), 결론 기본값은 후보가 있을 때만 발동한다. 「맞는 프레임워크가 있으면」의 판정자가 만드는 쪽 저자 자신인 한 P4 의 「결론이 실제로 달라진다」는 그 조건절에서 새어 나간다. P4 는 반증되지 않았다 — 조용한 기각을 승인 대상으로 바꾸는 효과는 실재한다 — 그러나 탐색 증거 없이 이 전제 하나로는 서지 않는다.
>   (3) P3 의 「늘」은 레포 기록과 글자대로는 맞지 않는다. markdown-it-py 는 사용자 승인으로 들어왔고(테스트 한정), 설계 · 계획 단계 자체가 남이 유지하는 플러그인(superpowers) 위에 서 있다. 다만 B2 는 P3 를 약하게 하지 않는다 — 맞는 파서가 있었는데 런타임 판독기는 직접 만들었고, 그 선택지에 「(권장)」을 붙인 쪽은 모델이었다. 승인 게이트가 있어도 추천의 방향이 만드는 쪽이면 결론은 만드는 쪽으로 간다는 실례라서 P4 의 「기본값」 부분을 오히려 받친다. hit 으로 내지 않았다.
>   (4) P6 에는 「규칙이 닿는 자리를 devbrew 가 갖고 있다」는 전제가 숨어 있다. 설계와 계획 단계의 실행자는 superpowers(brainstorming · writing-plans)이고 devbrew 가 쥔 자리는 넘김 줄 · 인터뷰 문단 · 설계문서 리뷰 프로필뿐이다. CLAUDE.md 는 이 레포에만 있고, 플러그인이 실어 보낼 수 있는 컴포넌트에 규칙 파일은 없다. 그리고 설계문서를 읽는 유일한 독립 판정자의 과설계 사다리에는 「플랫폼 기본 기능 · 바깥의 유지되는 것으로 되나」 단이 없고 그 판정자는 웹 도구가 없다 — 바깥 칸을 읽어 줄 독자가 지금 없다.
>   공시 1 — 닫힌 경로: 「지금 규칙이 지켜지게」(라운드 1)와 「새로 들일 때만 승인」 · 「기준 넘으면 묻지 않음」(라운드 2)은 사용자가 고르지 않아 대안에 넣지 않았다. 대안의 단계 구분은 승인을 푸는 것이 아니라 방향 기본값이 걸리는 범위만 가른다.
>   공시 2 — 반복 감지: 이 방향으로 받은 첫 입력이다. 같은 입력의 재호출이 아니다.
> recommendation: refined
> refined_takes: |
>   원안의 뼈대 전부 — 맞는 프레임워크가 있으면 그 위에서 만드는 것이 세 범주(Claude Code 기본 기능 · 남이 유지하는 플러그인과 skill · 널리 쓰이는 패키지와 도구) 모두에서 기본이고, 직접 만들려면 이유와 사용자 승인이 필요하며, 외부 것의 승인은 그대로 두고, 규칙과 장치에 레포 전용 값 · 특정 프레임워크 이름을 박지 않고, 범위는 규칙 문장과 인터뷰 · 설계 · 계획 단계까지다.
>   대안에서 가져와 원안에 붙이는 것 넷.
>   (a) 만드는 이유의 선행 조건으로 탐색 증거 — 찾아본 후보를 이름으로 들고 후보마다 요구에 비춘 맞음 판정을 적는다. 「없음」은 어디를 찾았는지와 함께만 선다.
>   (b) 의존 쪽 장부를 이유의 종류로 인정 — 사용자 환경에 생기는 의존 · 특정 도구 종속 · 라이선스 · 없을 때의 길 없음 · 요구에 안 맞음은 정당한 이유이고, 테스트 한정 · 방식만 차용 같은 부분 채택도 「쓰는 것」의 한 형태로 센다. 그래야 C5 · B2 가 새 규칙과 어긋나지 않는다.
>   (c) 검증 기준 셋은 필요조건이고 인터페이스 안정을 더한다 — 실험 딱지 기능은 사용자가 따로 승인하지 않는 한 기반이 아니다(D33 유지).
>   (d) 규칙이 사는 자리는 독립 독자가 있는 곳 — 플러그인이 실어 보내는 인터뷰 문단 · 넘김 줄 · 설계문서 리뷰 프로필의 사다리. CLAUDE.md 문장만 고치는 것으로 끝내지 않는다.
> refined_drops: |
>   셋을 버린다.
>   (1) 「공식 · 널리 쓰임 · 유지 중이면 직접 만든 것보다 믿을 수 있다」를 충분조건으로 읽는 것(P2 의 반증된 범위).
>   (2) 결론의 기본값을 뒤집는 것만으로 결론이 달라진다는 기대 — 후보가 비면 기본값은 발동하지 않는다.
>   (3) 「결론은 늘 직접 만들기였다」를 원인 진단으로 쓰는 것 — 기록이 보이는 고장은 잘못된 결론보다 비어 있는 바깥 칸과 사용자에게 닿지 않은 기각이다.
> evidence:
>   - url: "https://chromium.googlesource.com/chromium/src/+/main/docs/adding_to_third_party.md"
>     supports: both
>     claim: "첫 문장이 「Using third party code can save time and is consistent with our values - no need to reinvent the wheel!」이고, 같은 문서가 새 제3자 프로젝트에 Technical Steering Council 과 Chrome Security 의 승인, 동기 · 검토한 대안 · 보안 · 유지 책임(「You will be responsible for owning the dependency」) · 무게 기재를 요구하며 「Third party code is a hot spot for security vulnerabilities」라고 적는다. 재사용이 기본 가치인 것과 들일 때의 승인이 한 절차 안에 함께 선다."
>     touches: [P5, P1]
>     decides: [OQ7, OQ8]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/vendor.md"
>     supports: alternative
>     claim: "새 의존 검토 목록이 「Is the dependency maintained?」 · 「Does the dependency bring value to the project? Could this be done without adding a new dependency?」 · 「Is there already a dependency in the project that does something similar?」이고 라이선스는 dep-approvers 가 본다. 유지 중인지는 여러 물음 가운데 하나이고, 이미 든 의존을 먼저 보는 단계가 따로 있다."
>     touches: [P2]
>     decides: [OQ2, OQ8, OQ9]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://www.anthropic.com/engineering/building-effective-agents"
>     supports: alternative
>     claim: "「We suggest that developers start by using LLM APIs directly」 · 프레임워크는 「extra layers of abstraction that can obscure the underlying prompts and responses」 · 「If you do use a framework, ensure you understand the underlying code」 · 「Incorrect assumptions about what's under the hood are a common source of customer error」. 범위는 에이전트 시스템을 쉽게 만들어 주는 프레임워크이고 일반 패키지 · 플랫폼 기능이 아니다."
>     touches: []
>     decides: [OQ4]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://research.swtch.com/deps"
>     supports: alternative
>     claim: "의존 관리자는 내려받고 까는 비용만 없앴고 평가 · 유지 비용은 남는다. 들이기 전에 설계 · 코드 품질 · 테스트 · 디버깅 · 유지 · 사용처 · 보안 · 라이선스 · 그 의존의 의존을 살피라 하고, 위험하고 격리할 수 없으면 「the best answer may be to avoid it entirely」, 작은 필요에는 「A little copying is better than a little dependency」. 결론은 「We do this because it's easy, because it seems to work, because everyone else is doing it too」."
>     touches: [P1, P2]
>     decides: [OQ2, OQ8]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://research.swtch.com/xz-timeline"
>     supports: alternative
>     claim: "공격자가 2년 넘게 신뢰받는 기여자가 되어 유지 권한을 얻었고, 백도어는 공식 상류 릴리스 xz 5.6.0 · 5.6.1 배포본에 실렸다. 공식 · 널리 쓰임 · 유지 중 세 기준을 모두 넘는 것이 믿을 수 없게 된 실례다."
>     touches: [P2]
>     decides: [OQ2]
>     source_kind: secondary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://code.claude.com/docs/en/agent-teams"
>     supports: alternative
>     claim: "「Agent teams are experimental and disabled by default … known limitations around session resumption, task coordination, and shutdown behavior」. 한계 목록에 in-process 팀원의 세션 재개 불가 · 작업 상태 지연 · 리드 고정이 있다. 만든 쪽이 공식으로 내고 유지하는 기본 기능이 기반으로 쓰기에는 불안정할 수 있다."
>     touches: [P2]
>     decides: [OQ3]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://github.com/anthropics/claude-plugins-official"
>     supports: alternative
>     claim: "공식 마켓플레이스의 경고 — 「Make sure you trust a plugin before installing, updating, or using it. Anthropic does not control what MCP servers, files, or other software are included in plugins and cannot verify that they will work as intended or that they won't change」. 공식 목록에 올랐다는 것이 검증을 뜻하지 않는다."
>     touches: [P2, P5]
>     decides: [OQ2]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://snyk.io/blog/toxicskills-malicious-ai-agent-skills-clawhub/"
>     supports: alternative
>     claim: "커뮤니티 skill 저장소 약 4천 개를 훑은 감사에서 3분의 1 이상에 결함이 있었고 악성 페이로드가 확인된 skill 이 나왔다. 「남이 만들어 유지하는 플러그인과 skill」 범주는 사용자 승인 없이 기본으로 들일 수 없다. 수치는 요약마다 달라(악성 76건 대 페이로드 1,467건) 원문 확인이 필요하다."
>     touches: [P2, P5]
>     decides: [OQ2]
>     source_kind: secondary
>     checked_at: "2026-11-15"
>     certainty: uncertain
>   - url: "https://labs.cloudsecurityalliance.org/research/csa-research-note-slopsquatting-ai-supply-chain-20260419/"
>     supports: alternative
>     claim: "USENIX Security 2025 연구(Spracklen 외)에서 코드 생성 표본의 19.7% 가 실재하지 않는 패키지 이름을 하나 이상 담았고, 같은 프롬프트를 열 번 돌리면 환각 이름의 43% 가 매번 되풀이됐다. 모델이 「맞는 패키지가 있다」고 내는 판정은 그 자체로 확인 대상이다. 표본 수는 출처마다 다르다."
>     touches: [P5]
>     decides: [OQ8]
>     source_kind: secondary
>     checked_at: "2026-11-15"
>     certainty: uncertain
>   - url: "https://code.claude.com/docs/en/plugin-dependencies"
>     supports: alternative
>     claim: "판을 고정하지 않은 플러그인 의존은 「If that release renames an MCP tool your plugin calls, your plugin breaks for everyone who updates」. 다른 마켓플레이스의 의존은 기본으로 깔리지 않고, plugin.json 에 선언된 의존이 못 깔리면 「the install completes without the dependency and your plugin then fails to load」. 플러그인이 남의 플러그인에 기대는 공식 길은 있지만 못 풀릴 때 기대는 쪽 전체가 꺼진다."
>     touches: [P1, P6]
>     decides: [OQ1, OQ9]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://code.claude.com/docs/en/plugins/loading.md"
>     supports: alternative
>     claim: "Claude Code 는 플러그인의 Node.js 패키지 의존만 자동으로 깐다(package.json + 지원 lockfile). Python 의존은 자동 설치가 없어 훅으로 영속 데이터 폴더에 직접 깔아야 한다(「install it from a hook into the persistent data directory. That includes … Python dependencies」). 플러그인은 캐시로 복사되고 플러그인 폴더 밖 파일은 복사되지 않는다. Python 기반 플러그인이 런타임에 일반 패키지에 기대면 그 설치가 모든 소비 레포 사용자 환경의 일이 된다."
>     touches: [P6, P1]
>     decides: [OQ1]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://www.cambridge.org/core/product/1E6135ADFCBBC9AC9170DAEB3BBDA9DA"
>     supports: current
>     claim: "기본값 효과 메타분석(Jachimowicz 외 2019, 연구 58 · 참가자 73,675) — 합친 효과 d=0.68(95% CI 0.53–0.83). 미리 골라 둔 선택지가 선택을 옮긴다. 다만 연구 사이 편차가 크고 효과가 없거나 반대인 연구도 있으며, 기본값이 «추천»으로 읽힐 때 더 잘 듣는다."
>     touches: [P4]
>     decides: [OQ7]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://assets.kpmg.com/content/dam/kpmgsites/uk/pdf/2021/03/improving-the-quality-of-comply-or-explain-reporting.pdf"
>     supports: alternative
>     claim: "영국 FRC 의 comply-or-explain 보고 품질 검토 — 「'tick-box compliance' continues to be preferred over high quality reporting」 · 「such a formulaic approach leads to boilerplate language and ineffective reporting」. 따르지 않을 때 이유를 대게 하는 제도는 이유의 내용 기준이 없으면 상투 문구로 굳는다. 본문은 읽지 못했고 문서 설명 칸에서 확인했다."
>     touches: [P4]
>     decides: [OQ6, OQ10]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: uncertain
>   - url: "https://link.springer.com/doi/10.1007/s10664-007-9040-x"
>     supports: current
>     claim: "산업 연구 검토(Mohagheghi · Conradi 2007) — 체계적 재사용이 연구 다섯에서 낮은 결함 밀도와, 셋에서 수정 노력 감소와, 셋에서 생산성 이득과 유의하게 묶였다. 합치는 방식은 표 세기이고 산업 근거는 드물다고 저자가 적는다."
>     touches: [P1]
>     decides: []
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://mcfunley.com/choose-boring-technology"
>     supports: both
>     claim: "오래 쓰인 기술은 「their failure modes are well understood」이고 「the long-term costs of keeping a system working reliably vastly exceed any inconveniences you encounter while building it」 — 검증된 것 위에서 만드는 쪽의 근거. 같은 글이 「adding tech is a decision that requires company-wide visibility」라고 적어 새로 들이는 것에는 가시적 결정을 요구한다."
>     touches: [P1, P2, P5]
>     decides: [OQ3]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction"
>     supports: alternative
>     claim: "「duplication is far cheaper than the wrong abstraction」 · 「prefer duplication over the wrong abstraction」. 이미 들인 것에는 유지하려는 압력이 생겨 맞지 않는 추상을 매개변수와 조건문으로 계속 구부린다. 「맞는가」를 재지 않고 프레임워크에 올리면 유지 부담이 줄지 않고 옮겨 간다."
>     touches: [P1]
>     decides: [OQ8]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://www.devclass.com/ai-ml/2025/02/20/ai-is-eroding-code-quality-states-new-in-depth-report/1626250"
>     supports: current
>     claim: "GitClear 2025 보고서(2020–2024 바뀐 줄 2억 1,100만) — 옮긴 줄(리팩터 · 재사용의 대리 지표)의 비중이 2021년 24.8% 에서 2024년 9.5% 로 줄고 2024년에 복사 · 붙여 넣은 줄이 옮긴 줄을 처음 넘었다. AI 보조가 새 코드 삽입을 가장 쉬운 길로 만든다는 풀이. 있는 것을 쓰지 않고 새로 쓰는 쪽으로 기우는 것이 도구 차원의 경향이라는 근거다. 보고서 원문은 접근이 막혀 2차 보도로 확인했다."
>     touches: [P3]
>     decides: [OQ6]
>     source_kind: secondary
>     checked_at: "2026-11-15"
>     certainty: uncertain
> repo_claims:
>   - id: RC1
>     path: "CLAUDE.md"
>     anchor: "**있는 것 먼저.** 만들기 전에 레포 안 · 밖의 있는 것을 검토하고 외부 것은 사용자 검토 뒤 쓴다(철학 P8)."
>     line: 34
>     claim: "지금 규칙 문장은 「검토한다」까지이고 결론의 방향도, 무엇을 찾아봤는지 남기라는 요구도 없다. 이 파일은 이 레포에만 있어 플러그인을 깐 다른 레포에는 닿지 않는다. 철학 문서 P8 재사용 조항(docs/philosophy/devbrew-harness-philosophy.md 85행)도 같은 문장이다."
>     touches: [P6]
>     decides: [OQ1, OQ6]
>   - id: RC2
>     path: "plugins/spec-distill/skills/pm-interview/SKILL.md"
>     anchor: "**있는 것 먼저.** 무엇을 만들자는 결정이 열리면"
>     line: 312
>     claim: "플러그인이 실어 보내는 인터뷰 문단이 이미 「바깥의 성숙한 것(패키지 · 프레임워크 · 도구)을 웹으로 찾는다 … 후보와 차이를 보이고 묻는다」를 요구한다. 다른 레포에 실제로 닿는 규칙 자리는 여기이고, 이 문단도 방향 기본값과 「없음」의 근거 요구가 없다."
>     touches: [P6, P4]
>     decides: [OQ1, OQ6]
>   - id: RC3
>     path: "plugins/spec-distill/references/epic-handoff.md"
>     anchor: "설계문서에 ## 있는 것 검토 절(레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)"
>     line: 7
>     claim: "설계 단계의 실행자는 superpowers:brainstorming, 계획 단계는 superpowers:writing-plans 이고 devbrew 가 설계 · 계획에 규칙을 넣는 자리는 이 넘김 줄 한 문장이다. 그 문장은 레포 안은 「먼저 찾아 쓰고」, 레포 밖은 「후보로만 적어」로 비대칭이다 — 바깥 것에는 쓰라는 방향이 아니라 붙잡아 두는 방향이 적혀 있다. 락(plugins/spec-distill/tests/test_epic_handoff.sh 64행)은 이 문구의 존재만 잰다."
>     touches: [P6, P4]
>     decides: [OQ1, OQ6]
>   - id: RC4
>     path: "plugins/spec-distill/references/docreview-profiles/design-doc.md"
>     anchor: "### 판정 절차 — 사다리"
>     line: 69
>     claim: "설계문서를 읽는 독립 판정자의 과설계 사다리는 「1. 이 구조가 있어야 하나 2. 이미 리포에 있는 원칙·메커니즘으로 되나 3. 이미 있는 하니스 표면으로 되나 4. 한 줄 규약으로 되나 5. 그제서야 새 메커니즘」이다. 플랫폼 기본 기능이나 바깥의 유지되는 것으로 되는지를 묻는 단이 없고, 층 1 · 층 2 범주 어디에도 「있는 것 검토」 절을 읽는 항목이 없다. 이 판정자는 웹 도구가 없다(plugins/spec-distill/CHANGELOG.md 「새 `doc-critic`·`doc-recritic` 은 `tools: Read, Grep, Glob` 뿐이고 `design-doc.md` 프로필은 `web: false` 를 고정한다」). 바깥 칸은 쓰는 사람만 있고 읽는 사람이 없다."
>     touches: [P4]
>     decides: [OQ1, OQ6, OQ10]
>   - id: RC5
>     path: "docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md"
>     anchor: "B2 · 결정 · 2026-10-17 · 실제 파서 — 「테스트에서만 씁니다 (권장)」"
>     line: 318
>     claim: "맞는 파서(markdown-it-py)가 있었고 사용자 승인도 거쳤지만 결론은 「런타임 판독기는 표준 라이브러리만 쓴다」(165행)였다. 기각 사유는 「markdown-it-py 를 실행 때도 — 사용자 환경에 의존이 생긴다(B2)」(311행)이고, 「(권장)」은 만드는 쪽 선택지에 붙어 있었다. 승인 게이트가 있어도 추천의 방향이 결론을 정한 실례이고, 「사용자 환경에 생기는 의존」이 사용자가 받아들인 이유의 종류라는 기록이다. 같은 절에 bashlex 를 GPLv3 라이선스로 기각한 것도 있다(216행)."
>     touches: [P3, P4, P1]
>     decides: [OQ7, OQ8]
>   - id: RC6
>     path: "docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md"
>     anchor: "기각 — herdr 같은 외부 실행기를 기본으로 → 특정 도구 의존(C5)"
>     line: 484
>     claim: "하루 전 같은 사용자의 확정 제약 C5(34행 「특정 외부 도구에 하드코딩되거나 의존이 생기는 것은 피한다」)가 외부 도구를 「특정 도구 의존」 한마디로 기각하는 근거로 쓰였다. 같은 목록이 공식 Claude Code 기능 둘도 기각한다 — 「agent 팀을 일꾼 기반으로 → … 실험 기능(S4)」(482행) · 「헤드리스 claude -p 를 일꾼 기본으로 → Skill 도구 거부 · 실패가 rc 0 으로 숨음(S4)」(483행). 반대로 superpowers SDD 는 「[취함] — 자체 검수 상한을 여기에 맡긴다」(475행)로 들였다. 새 규칙이 「의존이 생긴다」를 이유로 인정하는지 정하지 않으면 C5 와 맞부딪친다."
>     touches: [P2]
>     decides: [OQ3, OQ4, OQ8]
>   - id: RC7
>     path: "docs/superpowers/specs/2026-10-15-roadmap-control-plane-design.md"
>     anchor: "실험 기능은 기반으로 쓰지 않는다(D33) — 기반은 작업 목록 · 상태줄 설정 · 진입 skill."
>     line: 64
>     claim: "실험 딱지 기능을 기반에서 빼는 것은 확정 제약으로 이미 있다. 공식 제공 · 유지 중을 넘는 기능이라도 기반으로 믿지 않기로 한 결정이므로, 검증 기준 셋만으로는 이 결정을 다시 낼 수 없다."
>     touches: [P2]
>     decides: [OQ3, OQ2]
>   - id: RC8
>     path: "docs/superpowers/specs/2026-10-20-dependency-portability-design.md"
>     anchor: "기각: Claude Code plugin.json `dependencies`(superpowers 가 없으면 spec-distill 전체가 꺼진다 — U6 과 충돌) · Claude Code `userConfig`(레포 단위로 둘 수 없고 Bash 명령 환경에 없다"
>     line: 247
>     claim: "공식 Claude Code 기능 둘을 후보로 보고 구체적인 맞음 사유로 기각한 뒤 같은 일을 직접 만들었다. 바깥 칸은 「Renovate 의 기본 브랜치 설정 읽기(방식만 차용). 새 외부 패키지는 쓰지 않는다」(246행)다. 기각 사유는 믿음이 아니라 맞음의 문제였다 — 「맞는가」의 판정 기준이 없으면 같은 기각이 새 규칙 아래서도 저자 판단으로 되풀이된다."
>     touches: [P2, P3]
>     decides: [OQ6, OQ8]
>   - id: RC9
>     path: "docs/superpowers/specs/2026-10-23-r8-device-leftovers-design.md"
>     anchor: "레포 밖: gh `pr view <번호> --json` · `pr create` 의 URL 출력. 새 외부 패키지는 쓰지 않는다."
>     line: 339
>     claim: "바깥 칸이 찾아본 후보 없이 한 줄로 닫힌다. 같은 꼴이 docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md 238행 「새 외부 패키지는 쓰지 않는다」 · 2026-10-23-rules-docs-cleanup-design.md 394행 「레포 밖: 쓰지 않는다.」 · 2026-10-21-interview-gate-leftovers-design.md 225행 「레포 밖: 쓰지 않는다」 · 2026-10-25-epic-parallel-recommend-design.md 190행에 되풀이된다. 같은 문서들의 레포 안 칸은 스크립트 · 함수를 이름으로 열거한다(r8 328–338행). 형식에 그친 것은 검토 전체가 아니라 바깥 칸의 탐색이다."
>     touches: [P3, P4]
>     decides: [OQ6, OQ10]
>   - id: RC10
>     path: "plugins/spec-distill/dependencies.md"
>     anchor: "| superpowers | 7.0.0 | 2026-10-22 | 알림 |"
>     line: 17
>     claim: "spec-distill 은 이미 남이 유지하는 플러그인(superpowers) · 자매 플러그인(quality-gates) · python · git · gh · claude-code 를 의존 표에 적고 그 위에서 돈다. 「이미 의존으로 적힌 것」이라는 범주가 파일로 실재하고(이름 · 최소 판 · 강도 · 없을 때), 새로 들이는 것과 가를 기준선으로 쓸 수 있다. 「결론은 늘 직접 만들기」는 설계 · 계획 단계 자체에는 맞지 않는다."
>     touches: [P3]
>     decides: [OQ9]
>   - id: RC11
>     path: "CLAUDE.md"
>     anchor: "**Trivia ceremony** — 한 문장 diff에 full pipeline 실행"
>     claim: "한 문장으로 설명되는 trivia diff 는 게이트를 우회하고(Law 1 Trivia escape), trivia 에 전체 절차를 돌리는 것은 금지 패턴으로 이름 붙어 있다. 「고칠 때 크기와 상관없이 함께 본다」를 오타 수정에까지 걸면 이 조항과 부딪친다."
>     touches: []
>     decides: [OQ5]
> ```
>
> 읽은 파일(절대 경로):
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/CLAUDE.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/philosophy/devbrew-harness-philosophy.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/skills/pm-interview/SKILL.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/epic-handoff.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/docreview-profiles/design-doc.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/dependencies.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/interview/2026-11-15-existing-framework-first-interview.audit.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-15-roadmap-control-plane-design.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-20-dependency-portability-design.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-19-interview-open-research-design.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-23-r8-device-leftovers-design.md
>
> 확인 수준 공시:
> - RC9 의 되풀이 다섯 가운데 r8 · review-engine-leftovers 는 절 전체를 읽었고, rules-docs-cleanup · interview-gate-leftovers · epic-parallel-recommend 는 해당 줄만 grep 으로 확인했다.
> - RC4 의 「층 1 · 층 2 범주에 있는 것 검토를 읽는 항목이 없다」는 프로필 23–114행을 읽고 확인했다. 판정자의 도구 제한은 CHANGELOG 문장으로 확인했고 agent 파일의 frontmatter 는 직접 읽지 않았다.
> - 웹 근거 가운데 Snyk · 환각 패키지 연구 · GitClear 는 2차 요약으로만 확인했고(GitClear 원문은 403), FRC 보고서는 PDF 본문이 읽히지 않아 문서 설명 칸의 문장만 확인했다 — 넷 다 `certainty: uncertain` 으로 표시했다.
> - Kubernetes vendor.md 는 「새 의존에 별도의 이유 서식을 요구한다」고 적지 않는다 — 검토 물음 목록과 라이선스 검토자만 있다. trigger 의 「Kubernetes 는 이유와 승인을 요구한다」는 그만큼 약하게 읽어야 한다.

**게이트-전 확인** — repo_claims: 11건 모두 확인(임시 번호 → 전역 번호: RC1 → RC2 · RC2 → RC6 · RC3 → RC8 · RC4 → RC45 · RC5 → RC17 · RC6 → RC46 · RC7 → RC49 · RC8 → RC19 · RC9 → RC47 · RC10 → RC43 · RC11 → RC48) · 부착 주장: 근거 17 중 부착 16(비부착 1 — Anthropic 의 에이전트 구축 글), 부착 16 모두 지목된 전제에 닿는다 — 확인 · 재검토 자격: 열림 4건(전제 P2 충돌 — agent teams 공식 문서 · RC46 과 RC49 · RC19 · 공식 플러그인 저장소 안내문. xz 사례는 본체가 다시 읽지 않았다)

**사용자 선택** — 보완 (S6). builder 의 보완안 가운데 셋째 항목(검증 기준 셋은 필요조건 · 실험 딱지 기능은 따로 승인하지 않는 한 기반이 아니다)은 dispatch 뒤에 온 S4 · S5 와 어긋나 따로 물었고 사용자는 앞 답을 유지했다(S7).

## 4. 게이트 실행 기록

- check_brief.py gate — 통과(확정 반영 뒤) (2026-11-15) — web: enabled
- check_verbatim_coverage.py — 아직 돌리지 않음(brief 리뷰 진입 때 돈다) (2026-11-15)

## 5. 프로세스 로그

- round 1: path (a · b) — 원인 넷 · 규칙이 살 자리 · 검증 기준 · 실험 기능 — coverage-mapper 첫 dispatch, 레포 조사 둘 · 웹 조사 둘을 한 묶음으로
- round 2: path (b) — steelman ST1 게이트(보완)
- round 3: path (a · b) — 보완안 셋째 항목 · 숨은 가정과 실패 양식의 처분 · 고칠 때의 범위 · 에이전트 조율용 프레임워크
- round 4: path (b) — 열린 질문 목록 확인 → 포화 판정 1
- round 5: path (a · b) — 빈 곳 다섯 조사(묶음 3) 뒤 이미 쓰는 것의 승인 · 구현 뒤 확인 · 열린 질문 목록 → 포화 판정 2
- round 6: path (b) — 반복 빈 곳 감지 → 사용자 판단 포화, 분해 판단(설계 하나로)
- round 7: path (b) — brief 리뷰 1라운드 게이트의 결정 넷(S17~S20, 넷 다 「고친다」) — 인터뷰 질문 라운드가 아니라 리뷰 게이트의 답이다
- brief 리뷰 1라운드 반영: 「측정 장치를 만들지 않는다」를 목표 밖에서 뺐다(S17) · 정당한 이유는 후보별로 구체일 때만 서게 했다(S18 — D20 · D21) · 설계문서 리뷰 프로필을 규칙 자리에 더했다(S19 — D22, S3 의 재결정) · 같은 일을 하는 공개 skill 둘을 후보로 올렸다(S20 — D23 · OQ15). 지적 다섯은 저자가 고쳤다 — D11 · D12 를 선택 글자대로 줄이고 세부는 모델 제안으로 갈랐다, OQ12 를 다시 열었다(「해결」 표기가 선택 글자보다 넓었다), 다시 정해진 seed 문장을 셋으로 바로잡았다, D16 에 온전한 문장을 실었다, 조율용 프레임워크 기각 줄에서 조사 이유를 사용자 답과 갈랐다.
- round 8: path (b) — brief 리뷰 2라운드 게이트의 결정 둘(S21 · S22, 둘 다 「고친다」) — 리뷰 게이트의 답이다
- brief 리뷰 2라운드 반영: 후보마다 보이는 정보에 안전 칸을 더하고 인기 지표에 재는 단위를 적게 했다(S21 — D24 · D25 · K20) · 「새 장치는 만들지 않는다」를 규칙을 나를 장치로 좁혔다(S22 — D8 · D26). 지적 둘은 저자가 고쳤다 — 조사 목록 한 줄의 「승인 질문 수를 늘리지 않는다」를 고른 글자(묶음 승인)로 바꿨다, 사소한 변경으로 새는 길을 남기기로 한 사실(S9)을 위험 K18 에 적었다. 재비판이 기각한 지적 1건(「전부 잠정으로 판단」 문구 — 틀이 요구하는 고정 글자다).
- round 9: path (b) — brief 리뷰 3라운드(상한 도달) 승인 게이트 1단계의 답 둘(S23 「고친다」 · S24 「열지 않음」) — 리뷰 게이트의 답이다
- brief 리뷰 3라운드 반영: 돌고 있는 지휘자 맥락 경제 로드맵과 고칠 파일이 겹치는 것을 위험과 열린 질문으로 실었다(S23 — D27 · K21 · OQ16 · RC67). 지적 넷은 저자가 고쳤다 — 「새 장치」의 넓은 글자가 남은 조사 줄과 기각 줄을 좁힌 글자로 맞췄다, 둘째 공개 skill 줄에 안정 단계 · 보안 칸을 「보지 않았다」로 채웠다, 「레포의 의존 규칙 자체는 고치지 않고」를 「사용자가 정하지 않았다」로 바꿨다. 재비판이 기각한 지적 1건(「빈 곳 다섯」의 수 — 기록과 맞았다). 추가 라운드는 열지 않았다(S24) — 3라운드 뒤에 고친 다섯 곳은 리뷰어가 다시 보지 않았다.
- 끝 게이트: 사용자가 「확정하고 /compact 후 brainstorming」을 골랐다(S25) — §2 의 제약 27개(C1~C6 · D7~D27)를 확정으로 바꿨다. 확정으로 올리지 않은 발화 6개(S11 · S14 · S15 · S16 · S17 · S24)와 그 이유는 게이트 앞 글에 보였다. superpowers 판은 이 세션이 그 skill 을 불러오지 않아 확인하지 않았다(다음 세션에서).
- 공시: brief 리뷰 3라운드에 codex 는 사용 한도에 걸려 돌지 못했다(stderr_kind quota · 엔진 사유 exit_nonzero). 1 · 2라운드는 돌았다. codex 실호출 3회 · 성공 2회.
- 공시: brief 리뷰 2라운드의 웹 근거 둘(«snyk-toxicskills» · «arxiv-fake-stars»)은 본체가 원문 페이지를 읽어 확인했다. 가짜 별 연구는 초록만 읽었다.
- 공시: brief 리뷰 1라운드의 웹 근거 둘은 본체가 직접 확인했다 — «ecc-search-first» 는 저장소 정보와 skill 본문 앞부분을 공개 API 로 읽었고, «agent-powerups-search-before-building» 은 목록 페이지만 읽었다(원본 저장소는 읽지 않음).
- 공시: 조사 2 · 3 · 4 · 5 에는 조사 주장 계약의 전문이 아니라 형식 · 규칙만 남긴 줄인 본을 실었다(조사 1 과 6~12 는 전문).
- 공시: 포화 판정자에게 조사 원문을 글에 붙이지 않고 워크트리 안 파일(조사 원문만 이어 붙인 것) 경로로 넘겼다.
- 공시: 본체의 직접 확인은 라운드 기록의 확인 줄과 웹 항목 줄로만 남겼고 state `research_log` 에 `device: orchestrator` 항목으로 따로 넣지 않았다. §2 의 「본체 직접 17」은 라운드 기록 끝줄의 수를 더한 값이다.
- 공시: 조사가 낸 레포 주장의 임시 번호는 버리고 전역 번호로 다시 붙였다. 같은 자리를 가리키는 주장은 하나로 합쳤고, «지금 이해»에 싣지 않은 조사 주장에는 번호를 붙이지 않았다.
- D6: seed 의 «다시 검증할 것» 문단 가운데 레포로 확인 가능한 항목(예전 로드맵의 실험 기능 결정 · 이 레포의 규칙 문서만 고치면 다른 레포에 닿지 않는다)은 RC26 · RC1 · RC4 로 확인했다.
- 미확인: 조사 6 이 든 상류 설계 skill 의 문장은 처음에 찾지 못했다가 조사 12 뒤 설치본에서 확인했다(아래 대체됨 줄).
- 확인 RC1 — 확인 — .claude-plugin/marketplace.json#"source": "./plugins/spec-distill" — 주장과 일치(설치본에 실리는 것은 plugins/<이름>/ 넷뿐이다)
- 확인 RC2 — 확인 — CLAUDE.md#**있는 것 먼저.** 만들기 전에 레포 안 · 밖의 있는 것을 검토하고 — 주장과 일치(검토와 외부 것의 사용자 검토까지, 기본값 없음)
- 확인 RC3 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#(재사용) 새로 만든 것은 유지할 표면이 되므로 — 주장과 일치
- 확인 RC4 — 확인 — docs/superpowers/specs/2026-10-19-principles-docs-cleanup-design.md#**두 갈래의 「다른 레포」.** — 주장과 일치(CLAUDE.md 는 devbrew 개발 세션만 읽고, 남의 레포에서는 플러그인 동작 자리에 실려야 지켜진다)
- 확인 RC5 — 확인 — docs/superpowers/specs/2026-10-17-epic-conductor-design.md#결정 · 2026-10-17 · 이해 확인 — 주장과 일치(원칙이 들어올 때의 사용자 말은 「검토하는 성향」이었다)
- 확인 RC6 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#**있는 것 먼저.** 무엇을 만들자는 결정이 열리면 — 주장과 일치(찾기 · 싣기 · 묻기까지, 발동은 「만들자는 결정」, 「성숙한」의 기준 없음)
- 확인 RC7 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#**다음 세션 줄 — ①/② 공통** — 주장과 일치(설계 단계의 요구는 넘김 줄의 산문으로만 전달된다)
- 확인 RC8 — 확인 — plugins/spec-distill/references/epic-handoff.md#설계문서에 ## 있는 것 검토 절 — 주장과 일치(레포 안은 「찾아 쓰고」, 밖은 「후보로만 적어 사용자가 승인한 뒤에만」 — 한 절이 근거 재확인과 재사용 검토 두 일을 맡는다)
- 확인 RC9 — 확인 — plugins/spec-distill/tests/test_end_gates.sh#SHARED= — 주장과 일치(검사는 넘김 줄에 문구가 있는지만 잰다)
- 확인 RC10 — 확인 — plugins/spec-distill/references/docreview-profiles/design-doc.md#`required_sections` — 주장과 일치(필수 절 아홉에 「있는 것 검토」 없음 · web: false · 사다리는 레포 안만)
- 확인 RC11 — 확인 — plugins/spec-distill/references/docreview-profiles/brief.md#`direction` — 주장과 일치(brief 리뷰어는 「더 성숙한 외부 대안」을 웹으로 본다)
- 확인 RC12 — 확인 — plugins/spec-distill/scripts/check_bundle_coverage.py#(부재) 있는 것 검토 — 주장과 일치(plugins · shared · tools 의 .py · .js · agents · hooks · SKILL.md 에 그 글자 0건 — 하한)
- 확인 RC13 — 확인 — plugins/spec-distill/scripts/check_brief.py#External Landscape empty — 주장과 일치(brief §4 검사는 구조만 잰다)
- 확인 RC14 — 확인 — plugins/spec-distill/skills/spec-review/SKILL.md#writing-plans 를 시작하라 — 주장과 일치(계획으로 넘기는 줄과 계획 agent 틀에 「있는 것」 요구 없음)
- 확인 RC15 — 확인 — plugins/spec-distill/references/conducting.md#설계 전 조사는 꼼꼼히 — 주장과 일치(지휘자는 epic-handoff 를 가리킬 뿐 그 절을 확인하는 걸음이 없다)
- 확인 RC16 — 확인 — docs/superpowers/specs/2026-10-23-rules-docs-cleanup-design.md#- 레포 밖: 쓰지 않는다. — 주장과 일치(「있는 것 검토」 머리를 가진 설계문서 11건 — `##` 9건은 절 전문을, `### §8` 2건은 해당 줄을 읽었다. 새 외부 것을 기반으로 삼은 것 0건, 레포 밖 칸은 대부분 한 줄로 닫힌다)
- 확인 RC17 — 확인 — docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md#**레포 밖**: markdown-it-py — 주장과 일치(외부 패키지를 후보로 보이고 결정받은 기록 — 테스트에서만, 사용자 환경에 의존을 만들지 않으려고)
- 확인 RC18 — 확인 — docs/superpowers/specs/2026-10-17-epic-conductor-design.md#**레포 밖(사용자 승인됨 — 주장과 일치(Claude Code 기본 기능 · superpowers skill 을 레포 밖으로 다루고 묶음 한 번으로 승인받았다. 새 패키지 의존은 넣지 않았다)
- 확인 RC19 — 확인 — docs/superpowers/specs/2026-10-20-dependency-portability-design.md#- 기각: Claude Code plugin.json `dependencies` — 주장과 일치(공식 기능 둘을 적합 이유로 기각하고 직접 만들었다. 기각은 지휘자 판단으로 적혀 있다)
- 확인 RC20 — 확인 — docs/superpowers/specs/2026-10-12-interview-persistent-explore-design.md#**내장 Explore 로 레포 조사** — 주장과 일치(내장 agent 를 레포 자신의 규칙 때문에 기각했고 권장 선택지가 새로 만들기였다)
- 확인 RC21 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/token-baseline.md#ccusage(외부) — 주장과 일치(「외부 도구는 사용자 검토 뒤에 쓴다」가 검토를 청하는 문이 아니라 쓰지 않는 이유로 쓰였다)
- 확인 RC22 — 확인 — docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md#K2. 외부 플러그인 리뷰어(pr-review-toolkit)를 쓰는 방식은 유지한다. — 주장과 일치(사용자 선택이 결론을 외부 것 쓰기로 정한 기록)
- 확인 RC23 — 확인 — docs/archive/specs/2026-07-19-plugin-audit-plugin-design.md#**재발명하지 말고 감싸라.** — 주장과 일치
- 확인 RC24 — 확인 — docs/superpowers/specs/2026-08-05-agent-transparency-design.md#**output style**(본체 — 주장과 일치(Claude Code 기본 기능을 본체로 삼은 기록. `force-for-plugin: true` 를 썼고 그 플러그인은 뒤에 제거됐다 — 제거 이유는 읽지 않았다)
- 확인 RC25 — 확인 — CLAUDE.md#**최소 버전이 선언된 의존성.** — 주장과 일치(외부 것을 들이면 의존 표 · 없을 때 동작 · 공시가 붙고 레포 안에 만들면 붙지 않는다)
- 확인 RC26 — 확인 — docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md#☑ confirmed **D33** — 주장과 일치(「실험 기능은 기반으로 쓰지 않는다」는 한 로드맵에서 고른 선택지이고 가리킨 것은 agent teams 다. CLAUDE.md · 철학 문서에는 없다)
- 확인 RC27 — 확인 — plugins/spec-distill/references/fresh-evidence.md#최신과 안정이 갈리면(새 판 · 실험 기능 · 막 바뀐 정책) 차이를 보이고 선택지로 묻는다 — 주장과 일치
- 확인 RC28 — 확인 — docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md#agent 팀은 리드 고정 · 세션당 팀 하나 — 주장과 일치(2026-11-14 에 다시 기각했고 이유는 구체 한계다)
- 확인 RC29 — 확인 — docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md#🗣 confirmed **C5** — 주장과 일치(「특정 외부 도구에 하드코딩되거나 의존이 생기는 것은 피한다」는 사용자 확정 제약)
- 확인 RC30 — 확인 — plugins/project-init/skills/project-init/SKILL.md#**AGENTS.md를 canonical content source로** — 주장과 일치(대상 레포의 규칙 파일에 쓰는 표면은 이것 하나이고 사용자가 불러야 돈다. 템플릿에 재사용 규칙은 없다)
- 확인 RC31 — 확인 — plugins/project-init/hooks/hooks.json#"PostToolUse" — 주장과 일치(레포의 플러그인 훅은 이것 하나이고 세션 시작 훅은 없다)
- 확인 RC32 — 확인 — plugins/spec-distill/references/trivia-escape.md#한 문장으로 설명 가능한 사소한 변경이면 — 주장과 일치(사소한 변경은 진입에서 빠져 인터뷰 · 설계에 닿지 않는다)
- 확인 RC33 — 확인 — CLAUDE.md#중간 크기 일은 이유를 밝히고 가벼운 꼴 — 주장과 일치(가벼운 꼴은 CLAUDE.md 에만 있고 플러그인 .md 에는 그 낱말이 없다)
- 확인 RC34 — 확인 — plugins/spec-distill/dependencies.md#| claude-code | 2.1.303 — 주장과 일치
- 확인 RC35 — 확인 — docs/superpowers/specs/2026-09-21-designer-lens-review-design.md#### 1.3 외부 조달 결과 — 주장과 일치(외부에서 조달해 절반만 얻었고, 나머지를 레포에서 만드는 전환을 사용자 동의로 기록했다)
- 확인 RC36 — 확인 — docs/superpowers/interview/2026-10-03-plain-language-output-interview.md#위험 — 숨은 가정 | CLAUDE.md 에 규칙을 두면 devbrew 사용자 모두에게 닿는다 — 주장과 일치(앞선 brief 가 같은 물음을 「틀림」으로 닫았다)
- 확인 RC37 — 확인 — docs/superpowers/interview/2026-11-15-existing-framework-first-interview.audit.md#**「맞는 프레임워크」** 에서 맞는지를 누가 무엇으로 판단하는지 모르겠다 — 주장과 일치(냉독이 짚은 빈 곳)
- 확인 RC38 — 확인 — docs/superpowers/specs/2026-10-17-epic-conductor-design.md#- agent teams · Workflow 기반 — 주장과 일치(뒤 설계가 같은 결정을 Workflow · 병합 대기열 서비스로 넓혀 걸었다)
- 확인 RC39 — 미확인 — docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md#플러그인 monitor 의 한 줄이 알림 하나가 되고 — 그 줄은 실재하지만 monitor 가 최종 기반에 들어갔는지와 그 딱지를 사용자에게 보였는지는 확정하지 못했다
- 확인 RC40 — 미확인 — docs/superpowers/specs/2026-10-25-epic-parallel-recommend-design.md#레포 안에 있는 것을 먼저 썼다 — 절은 확인했으나 짝 brief 의 「머지 큐 [취함]」 줄은 조사가 든 줄 번호에서 찾지 못했다(brief 파일 날짜가 다르다)
- 확인 RC41 — 확인 — docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.md#특정 외부 도구에 하드코딩되거나 의존이 생기는 것은 피한다. (사용자 확인) — 주장과 일치(같은 줄에 「팀 구조는 superpowers 하나에 묶이지 않고」도 사용자 확인으로 있다) [조사 6]
- 확인 RC42 — 확인 — plugins/spec-distill/references/trivia-escape.md#**그대로** — 다음 안내를 내고 진행하지 않는다 — 주장과 일치(사소한 변경으로 판정되면 skill 이 안내만 내고 끝난다) [조사 6]
- 확인 RC43 — 확인 — plugins/spec-distill/dependencies.md#| superpowers | 7.0.0 | 2026-10-22 | 알림 | — 주장과 일치(이미 의존으로 적힌 것은 여섯. 설치 캐시에는 7.0.0 과 7.0.2 가 함께 있다 — 레포 밖 관찰) [조사 6 · 조사 7]
- 확인 RC44 — 확인 — CLAUDE.md#Workflow 와 deep-research 는 범위 밖 — 주장과 일치(Claude Code 기본 기능 가운데 조율 기능 일부를 이미 「명시 요청이 있어야 쓰는 것」으로 다룬다) [조사 6]
- 확인 RC45 — 확인 — plugins/spec-distill/references/docreview-profiles/design-doc.md#### 판정 절차 — 사다리 — 주장과 일치(다섯 단에 플랫폼 기본 기능 · 바깥의 유지되는 것으로 되는지를 묻는 단이 없고, doc-critic · doc-recritic 의 tools 는 Read, Grep, Glob 이다) [조사 7]
- 확인 RC46 — 확인 — docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md#기각 — herdr 같은 외부 실행기를 기본으로 → 특정 도구 의존(C5) — 주장과 일치(같은 목록이 agent 팀 · 헤드리스 claude -p 도 기각하고 superpowers SDD 는 취했다) [조사 7]
- 확인 RC47 — 확인 — docs/superpowers/specs/2026-10-23-r8-device-leftovers-design.md#- 레포 밖: gh `pr view <번호> --json` — 주장과 일치(바깥 칸이 찾아본 후보 없이 한 줄로 닫히고 같은 꼴이 다른 설계 넷에 있다) [조사 7]
- 확인 RC48 — 확인 — CLAUDE.md#**Trivia ceremony** — 주장과 일치(한 문장 diff 에 전체 절차를 돌리는 것은 금지 패턴이다) [조사 7]
- 확인 RC49 — 확인 — docs/superpowers/specs/2026-10-15-roadmap-control-plane-design.md#실험 기능은 기반으로 쓰지 않는다(D33) — 주장과 일치 [조사 7]
- 확인 RC50 — 확인 — plugins/spec-distill/CHANGELOG.md#**능력 축소 — design doc 리뷰의 외부 prior-art 대조가 Claude·codex 양쪽에서 동시에 0 이 됐다.** — 주장과 일치(1.0.0 에서 설계문서 리뷰의 웹 대조가 꺼졌다. 그 전에는 「외부 prior-art 대조가 판정의 일부」였다) [조사 9]
- 확인 RC51 — 확인 — docs/superpowers/specs/2026-09-06-document-review-redesign-design.md#| S1 | 방향성 리뷰어의 웹 탐색은 brief 프로필의 `web: true` 로 흡수 — 주장과 일치(끈 이유는 「근거 폭이 본질인 축은 brief 의 방향성 하나뿐」 한 줄이고 설계가 혼자 닫은 결정으로 적혀 있다. 같은 설계의 OQ-C 가 다시 열 조건을 열린 채 남겼다) [조사 9]
- 확인 RC52 — 확인 — plugins/spec-distill/skills/spec-review/SKILL.md#subagent_type: "spec-distill:doc-critic" — 주장과 일치(설계문서 리뷰 skill 에는 웹 사본을 고르는 걸음이 없고 web · 웹 글자가 0건이다. 프로필 값만 바꾸면 codex 쪽만 켜진다) [조사 9]
- 확인 RC53 — 확인 — shared/tests/test_docreview_codex.sh#러너: web:false 프로필 → 두 kill switch 무관하게 웹 켜지 않음 — 주장과 일치(설계문서 프로필의 web false 를 실질로 잠그는 락) [조사 9]
- 확인 RC54 — 확인 — docs/superpowers/specs/2026-10-17-epic-conductor-design.md#결정 · 2026-10-17 · 접근 — 「1 · 외부 후보도 씁 (권장)」 — 주장과 일치(기본 기능 · superpowers · gh 의 사용 승인이 결정 줄 하나로 묶여 있다) [조사 10]
- 확인 RC55 — 확인 — docs/superpowers/specs/2026-10-20-dependency-portability-design.md#U1 · 결정 · 2026-10-20 · 사용자 — 주장과 일치(의존 표 행의 사용자 줄은 쓸지가 아니라 강도 · 없을 때 동작 · 판 규칙을 정한다. quality-gates 행은 지휘자 판단이다) [조사 10]
- 확인 RC56 — 확인 — docs/superpowers/specs/2026-10-23-rules-docs-cleanup-design.md#qg `dependencies.md` 의 `pr-review-toolkit` 행 — 주장과 일치(표가 생긴 뒤 더해진 행은 이것 하나이고 사용자 결정 줄 없이 들어갔다) [조사 10]
- 확인 RC57 — 확인 — docs/superpowers/interview/2026-11-15-existing-framework-first-interview.audit.md#선택지: 승인 유지 / 새로 들일 때만 / 기준 넘으면 묻지 않음 — 주장과 일치(audit 에는 라벨만 있다. 본체가 이 세션의 전사에서 설명을 되찾았다 — 승인 유지 「외부 것은 지금처럼 후보와 차이를 보이고 승인받은 뒤에만 쓴다」 · 새로 들일 때만 「이미 깔려 쓰고 있는 것은 묻지 않고 쓰고, 새로 설치하거나 의존에 더해야 하는 것만 승인받는다」) [조사 10]
- 확인 RC58 — 확인 — plugins/spec-distill/CHANGELOG.md#superpowers 7.0.0 brainstorming 에 맞췄다 — 주장과 일치(넘김 글은 7.0.0 모양에 맞춰 쓰였다) [조사 12]
- 확인 RC59 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#마지막 전체 리뷰는 설계문서 ## Acceptance Criteria 가운데 — 주장과 일치(마지막 리뷰에 얹는 것은 수용 기준 대조 · 과제 사이 이음매 · 계획이 쓴 테스트 코드 셋이다) [조사 12]
- 확인 RC60 — 확인 — plugins/spec-distill/agents/integration-reviewer.md### 볼 이음매 — 주장과 일치(「고른 것을 실제로 썼는가」는 목록에 없다) [조사 11 · 조사 12]
- 확인 RC61 — 확인 — plugins/spec-distill/scripts/repo_defaults.py#def strict_frontmatter — 주장과 일치(손으로 쓴 줄 단위 파서이고 표준 라이브러리만 쓴다) [조사 8]
- 확인 RC62 — 확인 — docs/superpowers/specs/2026-10-23-r8-device-leftovers-design.md#레포 밖: gh `pr view <번호> --json` · `pr create` 의 URL 출력. 새 외부 패키지는 쓰지 않는다. — 주장과 일치(세 설계문서에 조사가 찾은 후보 이름은 없다 — 걸린 글자는 무관한 낱말과 `fetch.followRemoteHEAD` 기본값 인용뿐) [조사 8]
- 확인 RC63 — 확인 — plugins/spec-distill/scripts/check_bundle_coverage.py#def check_impl — 주장과 일치(구현 쪽 대조는 수용 기준 단위 보고 줄만 읽는다. 「고른 것을 썼는가」는 설계가 수용 기준으로 적을 때만 이 길에 실린다) [조사 11]
- 확인 RC64 — 확인 — docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.audit.md#**S32** ☑ 선택 (round 22) — 주장과 일치(「내가 쓰면서 판단 — 개선 여부는 따로 재지 않고」 — 그 로드맵 범위의 사용자 결정) [조사 11]
- 확인 RC65 — 확인 — docs/superpowers/specs/2026-09-22-interview-research-specialization-design.md#**조사를 했는지를 나중에 재는 장치** — 주장과 일치(2026-09-10 에 사용자가 사후 측정 장치를 「쓰이지 않는 무게 · 번거로움 · 방향이 틀렸다」로 걷어냈다) [조사 11]
- 확인 RC66 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/token-baseline.md#측정 도구를 제품화하지 않는다 — 주장과 일치 [조사 11]
- 대체됨: 「상류 설계 skill 의 «When there's existing work, build on what it already uses» 는 설치본에서 찾지 못했다」 → 설치된 7.0.2 본문 127~128행에 줄바꿈에 걸쳐 실재한다 (조사 12)
- 대체됨: 「조사 10 이 Phase 0 의 「새로 들일 때만」 설명을 되찾았다」 → 조사 10 은 그 설명이 audit 에 없음을 보였고 본체가 이 세션 전사에서 되찾았다 (조사 10)
- 확인 RC67 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#R2 — 지휘 절차 개편 — 주장과 일치 — 팀 파일 규약 에픽(R1)의 경로 예약에 에픽 넘김 글이 있고, 지휘 절차 개편 에픽(R2)의 경로 예약에 규칙 문서 · 철학 문서 · 구현 담당자 틀 · 설계문서 리뷰 프로필이 있으며 R2 의 의도는 절차서를 단계표와 지시서로 쪼개고 작업 방식 결합을 푸는 것이다. 재분해 이력은 R2 경로 예약에서 인터뷰 끝맺음 절차 파일을 뺐다고 적는다

### brief 리뷰 (reviewing-brief — 문서 리뷰 엔진)

- 라운드: 3 · 재리뷰 카운트 2 · 추가 라운드 0 — 승인 게이트 도달 사유: 상한 · 리뷰 완료: 예
- 결정: `## 8. 리뷰 결정` 7건(모두 채택) · 열린 채 남은 항목 0건 — 다만 엔진 집계로는 열린 지적 5개다: 3라운드의 채택 하나(abf668a4#r3.1)와 저자 수정 넷(23fe3fec#r3.1 · 5cff0112#r3.1 · 997c959a#r3.1 · d968a524#r3.1)은 문서에 반영했으나 추가 라운드를 열지 않아(S24) 리뷰어가 다시 보지 않았다
- codex: 1 · 2라운드 있음 · 3라운드 없음 — exit_nonzero(사용 한도) · 웹: Claude doc-critic-web · codex 켜짐(3라운드는 codex 부재)
- 냉독: 돌지 못함 — gap 을 재지 못했다(0건이 아니다). 냉독 agent 는 파일을 여는 도구가 없어 전문을 글에 실어야 하는데, 경로로 한 번 보냈다가 「읽지 못했다」를 받았고 61KB 전문을 다시 옮겨 싣지 않았다
- degrade: codex:exit_nonzero(3라운드 — 사용 한도, 다른 모델의 시각 없음) · readback:unavailable(위 사유) · 1라운드에 codex 지적 셋이 형식 파손으로 판정에 들지 못했다(x1 · x2 edit_scope_multi_anchor · x4 anchor/summary 부재) · 리뷰어 · 재비판자 · 포화 판정자에게 문서와 프로필을 글에 싣지 않고 워크트리 안 파일 경로로 넘겼다

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S2** ☑ 선택:
  > 만드는 쪽이 쉬운 길, 결론을 읽는 눈이 없음, 바깥을 안 찾음, 레포 규칙에 막힘 — 검토가 형식에 그친 원인 후보 넷을 모두 골랐다(외부 것을 쓰면 승인 · 의존 기록 · 공시가 붙고 직접 만들면 아무것도 안 붙었다 / 검토 절은 쓰기만 하고 결론을 따지는 리뷰 항목 · 검사가 없었다 / 레포 밖 칸이 후보 이름 없이 「쓰지 않는다」 한 줄이었다 / 쓸 만한 것이 있어도 레포 자신의 규칙 때문에 「맞지 않는다」로 끝났다)
- **S3** ☑ 선택:
  > 단계 안에서만 (권장) — devbrew 규칙 문서와 spec-distill 의 인터뷰 · 설계 · 계획 넘김 글만 고친다. 새 장치는 없고, 이 흐름을 타지 않는 일(사소한 수정 등)에는 규칙이 닿지 않는다
- **S4** ☑ 선택:
  > 보여 주는 정보로 (권장) — 검증 기준 셋을 문턱으로 쓰지 않는다. 후보마다 셋의 상태를 보이고 승인 때 판단한다
- **S5** ☑ 선택:
  > 보이고 고른다 (권장) — 실험 딱지 기능도 후보에 올리되 딱지와 알려진 한계를 함께 보이고 승인 때 고른다. 지난 로드맵의 결정은 그 로드맵에만 남는다
- **S6** ☑ 선택:
  > 보완 (builder·orchestrator 추천) — 원안의 뼈대는 그대로 두고 탐색 증거, 의존 쪽 비용을 정당한 이유로 인정하는 것, 읽는 눈이 있는 자리에 규칙을 두는 것을 붙인다. 검증 기준과 실험 기능 부분은 다음 질문에서 따로 묻는다
- **S7** ☑ 선택:
  > 방금 답대로 (권장) — 검증 기준은 문턱이 아니라 보여 주는 정보로 두고, 실험 기능은 딱지와 한계를 보이고 승인 때 고른다. 「안정 단계(실험 딱지 여부)」를 후보마다 보이는 정보에 한 칸 더한다
- **S8** ☑ 선택:
  > 승인이 도장이 됨 (권장), 틀린 후보가 올라옴 (권장), 구현에서 다시 만듦 (권장) — 설계가 반드시 다뤄야 할 실패 양식으로 셋을 골랐다(「과하게 들임 · 고장 전가」는 고르지 않았다)
- **S9** ☑ 선택:
  > 설계를 거치는 고침만 (권장) — 인터뷰 · 설계를 타는 고침에서는 크기와 상관없이 함께 본다. 오타 같은 사소한 변경은 지금처럼 그냥 고친다. 작은 고침으로 직접 만들기가 새는 길은 남는다
- **S10** ☑ 선택:
  > 따로 가르지 않는다 (권장) — 에이전트 조율용 프레임워크를 빼는 규칙도 넣는 규칙도 두지 않는다. 조율용도 다른 후보와 같은 길(후보로 보이고 승인)을 탄다
- **S11** ☑ 선택:
  > 넷 다 설계로 (권장) — 열린 결정 넷(두 승인이 있을 때 「기본」이 바꾸는 것 · 「맞는」을 누가 무엇으로 판정하는가 · Claude Code 기본 기능과 이미 적힌 의존도 쓸 때마다 승인받는가 · 형식이 아니게 됐는지를 무엇으로 아는가)을 조사 재료와 함께 brief 의 열린 질문으로 싣는다
- **S12** ☑ 선택:
  > 묶어서 한 번 (권장) — 설계마다 그 설계가 기대는 Claude Code 기본 기능과 이미 적힌 의존을 이름으로 모아 한 번에 승인받는다. 새로 들이는 것은 하나씩 승인받는다
- **S13** ☑ 선택:
  > 넣는다 (권장) — 계획 · 구현으로 넘기는 글이 마지막 리뷰에서 「설계가 고른 것을 실제로 썼는가」를 보게 하는 것까지 이번 범위에 든다. 확인한 범위를 계획 뒤로 한 걸음 넓힌다
- **S14** ☑ 선택:
  > 넷 다 설계로 (권장) — 남은 열린 결정 넷(두 승인이 있을 때 「기본」이 바꾸는 것 · 「맞는」을 누가 무엇으로 판정하는가 · 형식이 아니게 됐는지를 무엇으로 아는가 · 설계문서 리뷰에 웹 대조를 다시 여는가)을 brief 의 열린 질문으로 싣는다. 웹 대조를 다시 여는 일은 설계가 비용과 함께 정한다
- **S15** ☑ 선택:
  > 포화로 보고 종료 (권장) — 조사가 충분하다고 보고 brief 작성으로 간다. 열린 질문 다섯(새로 짚인 「기준 판」 포함)과 조사 재료가 설계로 넘어간다
- **S16** ☑ 선택:
  > spec 하나로 (권장) — 지금처럼 brief 하나를 brainstorming 하나로 넘긴다. 로드맵을 만들지 않는다
- **S17** ☑ 선택:
  > 고친다 — 목표 밖에서 뺀다 (권장) — 그 줄을 빼고, 과거에 측정 장치를 걷어낸 두 결정은 열린 질문의 재료로만 둔다. 재는 방법은 설계가 정한다(지적 2c0abd98#r1.1)
- **S18** ☑ 선택:
  > 고친다 — 후보별로 구체일 때만 (권장) — 이유는 그 후보에 대해 구체로 적을 때만 선다(누구 환경에 어떤 의존이 생기고 없을 때 무엇이 깨지는가). 상시 규칙이나 앞 인터뷰의 「의존 회피」 확정을 인용하는 것만으로는 이유가 안 된다. 어제 로드맵의 그 확정은 그 로드맵에만 남는다고 적는다(지적 abf668a4#r1.1)
- **S19** ☑ 선택:
  > 고친다 — 리뷰 프로필도 자리에 (권장) — 규칙을 두는 자리 목록에 설계문서 리뷰 프로필을 넣는다. 새 장치가 아니라 있는 리뷰 문장의 수정이고, 리뷰어 프로필 편집이라 보안 리뷰가 붙는다. 웹 대조를 다시 여는지는 설계에 남는다(지적 abf668a4#r1.2)
- **S20** ☑ 선택:
  > 고친다 — 후보로 이름을 올린다 (권장) — 조사 목록에 그 skill 을 이름으로 올리고, 그대로 쓸지 · 판정 틀만 빌릴지 · 직접 쓸지를 설계가 탐색 증거와 함께 정하게 한다. 쓰기로 하면 그때 승인을 받는다(지적 b73addba#r1.1)
- **S21** ☑ 선택:
  > 고친다 — 안전 칸을 더한다 (권장) — 후보마다 보이는 정보에 한 칸을 더한다 — 그 후보가 무엇을 실행하고 무엇에 닿는가(훅 · 스크립트 · 네트워크 · 자격증명)와 알려진 보안 문제. 인기 지표에는 재는 단위(저장소 전체인지 그 skill 하나인지)를 함께 적는다. 이 칸도 문턱이 아니라 보이는 정보다(지적 abf668a4#r2.1)
- **S22** ☑ 선택:
  > 고친다 — 규칙을 나르는 장치만 (권장) — 「규칙을 나를 새 장치(세션 시작 훅 · 대상 레포 규칙 파일 쓰기)는 만들지 않는다」로 좁혀 목표 밖 줄과 같은 글자로 맞춘다. 그 밖의 새 것(재는 수단 · 리뷰 걸음 · 공개 skill 을 들이는 것)은 설계가 이유와 함께 제안할 수 있다(지적 eb353eb4#r2.1)
- **S23** ☑ 선택:
  > 고친다 — 위험과 열린 질문으로 싣는다 (권장) — 위험 한 줄(고칠 자리가 그 로드맵의 예약 경로와 겹치고 지휘 절차 개편 에픽이 같은 문서를 쪼갠다)과 열린 질문 한 줄(두 일의 순서 — 이 일을 먼저 / 그 에픽이 끝난 뒤 / 겹치는 파일의 몫을 그 에픽으로 넘긴다)을 싣는다. 순서는 설계가 정한다(지적 abf668a4#r3.1)
- **S24** ☑ 선택:
  > 열지 않음 (권장) — 리뷰를 여기서 닫고 다음 단계 질문으로 간다. 이번에 고치는 다섯 곳은 리뷰어가 다시 보지 않는다
- **S25** ☑ 선택:
  > 확정하고 /compact 후 brainstorming (권장) — 확정 후보를 확정으로 바꿔 저장하고, 붙여 넣을 두 줄(/compact 와 다음 세션 줄)을 보여 준다. 인터뷰 기록을 요약해 둔 채 brief 를 붙여 읽고 brainstorming 을 시작한다

## 7. 확산 원자료

- «cc-plugin-manifest» — https://code.claude.com/docs/en/plugins/manifest-reference.md — 플러그인 루트 CLAUDE.md 는 실리지 않음 · 실을 수 있는 컴포넌트 · experimental 그릇
- «cc-output-styles» — https://code.claude.com/docs/en/output-styles.md — force-for-plugin · 한 번에 하나 · subagent 미적용
- «cc-hooks» — https://code.claude.com/docs/en/hooks.md — 세션 시작 훅의 컨텍스트 주입(조사 4)
- «agents-md-eval» — https://arxiv.org/abs/2602.11988 — 규칙 파일 지시의 준수와 성공률
- «whisper-money-1076» — https://github.com/whisper-money/whisper-money/pull/1076 — 승인 조항을 금지로 읽은 에이전트와 고친 규칙
- «chromium-third-party» — https://chromium.googlesource.com/chromium/src/+/main/docs/adding_to_third_party.md — 들이는 쪽의 이유 · 승인 · 주인
- «eo-14271» — https://www.govinfo.gov/content/pkg/FR-2025-04-18/html/2025-06835.htm — 상용품 기본 · 안 쓰는 쪽의 승인(조사 5)
- «anthropic-auto-mode» — https://www.anthropic.com/engineering/claude-code-auto-mode — 승인 요청 93% 수락 · 승인 피로
- «default-effects» — https://www.cambridge.org/core/journals/behavioural-public-policy/article/when-and-why-defaults-influence-decisions-a-metaanalysis-of-default-effects/67AF6972CFB52698A60B6BD94B70C2C0 — 기본값 효과 메타분석(조사 5)
- «openssf-eval-guide» — https://best.openssf.org/Concise-Guide-for-Evaluating-Open-Source-Software — 필요성 먼저 · 12개월 유지 · 문턱 없음 · 불안정 표시
- «homebrew-policy» — https://docs.brew.sh/Package-Acceptance-Policy — 축 사이 모두 · 안정판 요구(조사 5)
- «cc-agent-teams» — https://code.claude.com/docs/en/agent-teams.md — 실험 기능 · 한계 목록
- «k8s-api-stages» — https://kubernetes.io/docs/reference/using-api/ — alpha · beta · stable 의 쓸 자리(조사 5)
- «anthropic-effective-agents» — https://www.anthropic.com/engineering/building-effective-agents — 에이전트 프레임워크는 직접 쓰는 데서 시작(조사 5)
- «cc-plugin-deps» — https://code.claude.com/docs/en/plugins/dependencies.md — 판 제약 없는 의존 · 다른 마켓플레이스 의존 · 못 풀릴 때
- «cc-plugins-official» — https://github.com/anthropics/claude-plugins-official — 플러그인 내용물을 통제 · 검증하지 않는다는 안내
- «library-design-bench» — https://arxiv.org/abs/2609.36730 — 에이전트의 라이브러리 재구현과 원인
- «gh-poi» — https://github.com/seachicken/gh-poi — 머지된 브랜치를 PR 상태로 가리는 gh 확장
- «pypi-python-frontmatter» — https://pypi.org/pypi/python-frontmatter/json — 머리말 파서 패키지의 Python 요구 판
- «superpowers-brainstorming» — https://raw.githubusercontent.com/obra/superpowers/v7.0.2/skills/brainstorming/SKILL.md — 대안 · 추천 걸음과 있는 작업 위에 짓기(설치본에서 확인)
- «superpowers-reviewers» — https://github.com/obra/superpowers/blob/v7.0.2/skills/requesting-code-review/code-reviewer.md — 마지막 전체 리뷰의 점검 목록(설치본에서 확인)
- «arxiv-building-to-the-test» — https://arxiv.org/html/2606.28430 — 테스트 점수와 불리지 않는 라이브러리(조사 11)
- «frc-comply-or-explain» — https://www.frc.org.uk/docs/1892/html/ — 이탈 설명의 질(조사 11)
- «gao-aoa-practices» — https://files.gao.gov/reports/GAO-25-107092/index.html — 대안 분석 모범 관행의 채점과 한계(조사 11)
- «ecc-search-first» — https://github.com/affaan-m/everything-claude-code/blob/main/skills/search-first/SKILL.md — 만들기 전에 있는 것을 찾아 가르는 공개 skill(brief 리뷰 1라운드가 찾았고 본체가 저장소 정보와 본문을 확인)
- «agent-powerups-search-before-building» — https://www.claudepluginhub.com/skills/yeaight7-codebase-intelligence-plugins-codebase-intelligence/search-before-building — 같은 일을 하는 공개 skill 의 목록 페이지(원본 저장소 https://github.com/yeaight7/agent-powerups 는 읽지 않음)
- «snyk-toxicskills» — https://snyk.io/blog/toxicskills-malicious-ai-agent-skills-clawhub/ — 공개 skill 목록의 보안 조사(brief 리뷰 2라운드가 들었고 본체가 원문을 확인)
- «arxiv-fake-stars» — https://arxiv.org/abs/2412.13459 — GitHub 가짜 별 연구(brief 리뷰 2라운드가 들었고 본체가 초록을 확인 — 저장소 수는 초록에 없어 싣지 않았다)
- «gh-stack» — https://github.com/github/gh-stack — PR 묶음 확장(라운드 5 기록에만 쓰임)
- «arxiv-build-vs-buy-protocol» — https://arxiv.org/html/2606.03907 — build-vs-buy 사전 등록 프로토콜(라운드 5 기록에만 쓰임)

## 8. 리뷰 결정

- D1.1 · r1 · adopt · 2c0abd98#r1.1 · "고친다 — 목표 밖에서 뺀다 (권장)" — 사용자가 설계에 넘긴 질문(검토가 형식이 아니게 됐는지를 무엇으로 아는가)의 답 하나가 Non-goal 로 미리 닫혀 있다 — 「효과를 재는 측정 장치를 이번에 만들지 않는다」는 사용자가 한 말이 아니라 모델 추론이다.
- D1.2 · r1 · adopt · abf668a4#r1.1 · "고친다 — 후보별로 구체일 때만 (권장)" — 원인 넷 가운데 「레포 자신의 규칙에 막혔다」에는 고치는 결정이 없고, 그 규칙이 낳는 비용(의존이 생김 · 특정 도구 종속 · 없을 때의 길)이 오히려 직접 만들 정당한 이유로 인정됐다 — 원인으로 꼽은 것이 면제 사유가 된다 (D7 · D12).
- D1.3 · r1 · adopt · abf668a4#r1.2 · "고친다 — 리뷰 프로필도 자리에 (권장)" — 규칙을 둘 자리를 「규칙 문서와 넘김 글에만」으로 묶은 결정과 「읽는 눈이 있는 자리에 둔다」는 결정이 부딪친다 — 읽는 눈으로 꼽힌 셋 가운데 설계문서 리뷰 프로필은 넘김 글이 아니어서, 앞 결정대로면 고칠 수 없고 뒤 결정대로면 고쳐야 한다 (D8 · D13).
- D1.4 · r1 · adopt · b73addba#r1.1 · "고친다 — 후보로 이름을 올린다 (권장)" — 이 brief 가 만들려는 것 — 만들기 전에 있는 것을 찾고 채택 · 부분 채택 · 직접 만들기를 가르는 절차 — 과 같은 일을 하는 공개 skill 이 이미 있는데 조사 목록에 후보로 오르지 않았다. 이 brief 자신이 「후보를 이름으로 들지 않은 검토」가 된다 (C5 · D11).
- D2.5 · r2 · adopt · abf668a4#r2.1 · "고친다 — 안전 칸을 더한다 (권장)" — 프레임워크에 남이 만든 플러그인 · skill 이 들어 있는데, 승인 때 후보마다 보이는 정보 넷(공식 제공 · 널리 쓰임 · 유지 중 · 안정 단계)에는 그 후보가 사용자 환경에서 무엇을 실행하고 안전한지를 알리는 칸이 없다 — 한 칸을 더하거나, 설계가 반드시 다룰 실패 양식에 올리거나, 지금 넷으로 둔다 (C5 · D9 · D14).
- D2.6 · r2 · adopt · eb353eb4#r2.1 · "고친다 — 규칙을 나르는 장치만 (권장)" — 「새 장치는 만들지 않는다」가 문서 안에서 두 뜻으로 쓰인다 — 한쪽은 규칙을 나르는 장치(세션 시작 훅 · 대상 레포 규칙 파일 쓰기)만 막고, 다른 쪽은 이번 일에서 새로 만드는 것 전부를 막는다. 원문이 두 가지로 읽히므로 어느 쪽인지 정해야 한다 (D8 · OQ10 · OQ15).
- D3.7 · r3 · adopt · abf668a4#r3.1 · "고친다 — 위험과 열린 질문으로 싣는다 (권장)" — 규칙을 고쳐 넣기로 한 파일들이, 이미 승인돼 돌고 있는 다른 로드맵의 에픽이 고치려고 예약해 둔 파일과 겹치고 그 에픽은 같은 절차 문서를 쪼개 다시 짜려는데, 이 일은 로드맵 없이 설계 하나로 간다고만 정했고 두 일의 순서와 이음매가 문서 어디에도 없다 — 순서를 지금 정할지, 설계가 정할 열린 질문으로 실을지 정해야 한다 (D8 · D19 · D22 · S16).
- docreview 계수 — spec-distill-59ec298a/2026-11-15-existing-framework-first-brie-0a86caf0930909cb r1: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — spec-distill-59ec298a/2026-11-15-existing-framework-first-brie-0a86caf0930909cb r2: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — spec-distill-59ec298a/2026-11-15-existing-framework-first-brie-0a86caf0930909cb r3: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0
