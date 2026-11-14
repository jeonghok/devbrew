---
type: interview-audit
payload: 2026-11-14-qg-epic-roadmap-intent-review-brief-interview.md
created_at: 2026-11-14
session_id: 2e569030-b34b-44df-b3cf-e6e82c81557f
source: spec-distill pm-interview
---

# qg 에픽 · 로드맵 리뷰와 쓴소리 리뷰어 — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다.

## 1. Coverage Ledger

- floor:root_problem — closed — S1 원문(「이게 진짜 의도가 맞는지 나에게 질문을 하는 … 리뷰어」) · S2(뿌리 = 고른 것을 의심할 자리 없음) · S3(알아챈 때: 구현 뒤 써 보고 · 로드맵을 다 끝내고 — 한참 뒤는 잘 모름) (@S1) (@S2) (@S3)
- floor:landscape — closed — S4 — 외부 근거(조사 4) 처분: 의도 자체 이의 리뷰어 선례 없음, 실행은 /run · /verify 를 취함 (@S4)
- floor:skepticism — closed — S8 — ST1 steelman 판정 보완(refined) (@S8)
- floor:blind_spot — closed — S15 · S16 — 2차 premortem(조사 7) 처분: 머지 뒤 잘못 골랐다는 새 일의 씨앗으로, 원문은 직접 쓴 말과 고른 라벨을 갈라 라벨도 의심 (@S15) (@S16) (재개방 1회 — 조사 7 — 머지 뒤 · 로드맵 끝엔 피벗 경로가 닫혀 있음(RC77 · RC78 · RC79), 원문 대부분이 모델 라벨(RC80))
- floor:open_questions — closed — S21 — 열린 질문 일곱 목록 확인(재개방 뒤 새 S) (@S21) (재개방 1회 — S14 뒤 열린 질문 목록이 바뀜 — OQ15 · OQ19 해결, OQ23 추가, OQ12 는 S17 · S19 로 지휘자가 푸는 쪽)
- derived:internal_research — closed — R1 coverage-mapper 가 repo_claims 첫 산출 — 조사 행위가 함의; S8 — 레포 주장(RC1–44) 처분: ST1 보완이 레포 사실(원문 0건 · 24시간 GC · 피벗 경로)을 받아들임 (@S8)
- derived:돌려 보기의 주체와 방법 — closed — qg 리뷰 agent 넷은 읽기 전용(RC1), 실행은 오케스트레이터(RC2) · e2e 는 승인한 명령만(RC4) · 표면은 웹 UI · API · CLI 셋(RC3) — devbrew skill 은 대화 세션 안에서만 써 볼 수 있고 질문하는 skill 은 헤드리스로 끝까지 못 감(RC14 · RC16 · 웹 E2); S4 · S5 · S7 · S9 (@S4) (@S5) (@S7) (@S9)
- derived:에픽 · 로드맵 이름을 리뷰 대상으로 푸는 길 — closed — range 는 두 커밋 사이 하나(RC5), 로드맵 끝 호출은 남의 커밋까지 섞임(RC7), 머지 뒤 호출 없음(RC8), 이름 풀이 데이터는 spec-distill(RC9)인데 qg 는 그 스크립트를 못 부름(RC10); S8 — 원문 · 묶음 · 에픽 블록은 부르는 쪽이 넘긴다(이름 풀이 주체는 OQ12 로 이월) (@S8)
- derived:의도 출처 확장과 판정 축 · 질문 축의 경계 — closed — 의도는 지적을 올릴 수만 있는 정답(RC11), 재비판자는 하지 않은 일 요구를 낮춤(RC17) — 쓴소리는 판정 밖이어야 충돌을 비켜 감; S8 — 질문은 판정 밖, 원문은 부르는 쪽이 넘김 (@S8)
- derived:질문의 길과 답의 하류 — closed — 백그라운드엔 질문 도구 없음(RC18) · relay 파일 + 게이트 사이 별도 메시지(RC19 · RC20) · qg 결과는 24시간 뒤 지워짐(RC12) · 「내가 잘못 골랐다」 답의 피벗 경로(RC21) · 「맞다」 답의 재질문 방지; S8 · S12 — 질문 · 답은 docs 추적 파일, 잘못 골랐다는 spec-distill 피벗 경로, 리뷰 끝에 한 번에 / 지휘자는 게이트 사이 (@S8) (@S12)
- derived:기존 비판 자리와의 겹침 — closed — 통합 리뷰어는 의도를 정답으로 놓고 로드맵 안 에픽만 봄(RC24) · 인터뷰의 steelman · premortem 은 구현 전(RC25) — 새 리뷰어 고유 몫을 가르기; S8 — 인터뷰의 steelman · premortem 의심을 입력으로 받아 구현 뒤 근거로 다시 묻는다 (@S8)
- derived:동시 작업을 아는 원천 — closed — 로드맵 밖 · 세션 밖 동시 작업을 아는 장치가 없음(RC24) · 옆 세션은 기계를 넘는 지휘자 소통을 만들려 함(RC22); S11 (@S11)
- derived:옆 세션과의 순서 · 경계 — closed — 옆 seed 의 「지휘자 없이 도는 흐름 없음」(RC22) · INTENT.md · 관문 다섯 칸을 qg 에, 검수 두 번을 SDD 리뷰 + 머지 전 확인에 대응(RC23); S20 — 본체 먼저, 입구는 옆 세션 설계에 맞춰(재개방 뒤 새 S) (@S20) (재개방 1회 — S19 — qg 호출 전부가 지휘자 경유면 입구가 옆 세션의 지휘자 개편에 기댄다)
- derived:비용 · 맥락 상한 — closed — qg 는 한 턴 · cost_class variable(RC26) — 에픽 · 로드맵 규모 탐색의 상한 · 멈출 조건; S6 · S13 — 근거 있을 때만 · 상한, 넓은 탐색은 규모 공시 + 승인이 상한 (@S6) (@S13)

## 2. Budget

- 질문 라운드: 10 · agent dispatch: 13 · coverage-mapper 1 · codex 실호출: 0 (성공 0)
- 조사 호출 8/60 (장치별: 커버리지 1 · 맹점 2 · 반론 1 · 레포 조사 2 · 만든 조사 2 · 본체 직접 3)
- 포화 판정 1: 아직 — 빈 곳 7개
- 포화 판정 2: 아직 — 빈 곳 7개
- 포화 판정 2: 사용자 판단 포화(@S22) — 반복 빈 곳

## 3. Steelman 원문

#### ST1 — 쓴소리 자리를 qg 안 새 리뷰어로 둘지

**dispatch 입력** — goal = S2(원 요청 S1 병기) · 전제 P1–P6(P1←S3 · P2←S1 · P3←seed 확인 · P4←seed 확인 · P5←seed 확인 + S4 · P6←S5) · 제약 S1(seed 확인 여섯) ~ S7 전량 · trigger = landscape 모순(의도 자체 이의 선례 없음 · 공식 권장은 작업 전 질문 + 「늘 뭔가 찾는다」 경고 · Ask Early · devil's advocate 연구) + 알려진 anti-pattern(있는 것 먼저 — steelman · premortem 이 이미 있음)

> ```yaml
> case_for_alternative:
>   statement: "쓴소리 자리를 qg 밖 별도 skill로 둔다. 이 skill은 spec-distill 쪽에 살며, 사용자 원문 · 인터뷰 묶음 · 로드맵 · 피벗 경로를 직접 쥔다. qg와 같은 범위(단일 PR · range · 에픽 · 로드맵)를 받지만 qg 판정과는 다른 박자로 돈다 — 단일 PR은 사용자가 써 본 뒤, 에픽은 머지 뒤, 로드맵은 끝에. 인터뷰 단계의 steelman · premortem이 남긴 의심을 구현 뒤 돌려 본 근거로 다시 묻는다."
>   strongest: "의심할 대상은 «사용자가 고른 것»이다. 그런데 그것을 담은 원문(발화 S<n>) · 묶음 · 에픽 블록은 spec-distill에만 있고(roadmap_model.py FIELDS), qg의 의도 사슬은 이를 하나도 참조하지 않는다(discover-spec.sh 0건). 설치본의 qg는 spec-distill 스크립트를 부를 수도 없다. 그래서 qg 안의 리뷰어는 인터뷰어가 압축한 설계문서를 의심하게 되고, 압축에서 빠진 바로 그것(=놓친 것)을 못 본다. 「내가 잘못 골랐다」는 답이 흘러갈 피벗 경로(재분해 · 인터뷰 · Sealed decision)도 spec-distill에 있다. 반면 qg 상태는 24시간 뒤 지워진다. 박자도 S3와 맞는다. 사용자가 알아챈 때는 «써 본 뒤»와 «로드맵 끝»이지 «머지해도 되나» 판정 때가 아니었다. 업계 표준인 증분 뒤 방향 재검토(Scrum Sprint Review — 결과를 보고 다음 적응을 정하며, 백로그를 고칠 수 있는 작업 세션)는 코드 리뷰와 따로 떨어진 행사다. Claude Code 공식 문서도 /verify를 리뷰와 떼어 두고, 「A reviewer that's asked to find problems will always find something」이라고 경고한다 — 머지 게이트에 «선택이 옳았나»를 얹으면 지적 무더기 속에 질문이 묻힌다. 그리고 의심 장치(steelman-builder · blind-spot-prober)가 이미 같은 플러그인에 있다(있는 것 먼저). 구현 전에 남은 의심을 구현 뒤 근거로 닫는 고리는 별도 skill이어야 자연스럽게 생긴다."
> case_for_current:
>   strongest: "뿌리 문제는 «자리 없음»이다. 그리고 devbrew의 존재 이유는 «사용자가 의식적으로 기억하지 않아도 자동으로 지켜지게» 하는 것이다(CLAUDE.md 에피그래프). 인터뷰 단계의 steelman-builder는 이미 있지만 모델이 trigger를 볼 때만 도는 조건부 자리다(pm-interview R3). 그런데도 사용자는 잘못 고른 것을 구현 뒤 써 보고서야 알았다(S3). 기억해서 불러야 하는 자리는 자리가 없는 것과 같았다는 증거다. qg는 사용자가 매 PR에 이미 부르는 게이트이고(「is my PR ready to merge」), 지휘자가 로드맵 끝에 이미 부른다. 지휘자가 없는 단일 PR 일에는 구현 뒤 자동 자리가 qg 하나뿐이다. 돌려 본 근거도 qg에 이미 있다 — 기준선과 견주는 차등 테스트, 사람이 승인한 e2e 걷기(S7과 같은 경계), «오케스트레이터가 돌리고 리뷰어는 읽기만»이라는 Law 2 분리. 그래서 새 리뷰어가 따로 내는 비용은 작다. «구현 뒤 리뷰가 의도 자체를 묻는다»는 선례도 있다. Google 코드 리뷰 지침은 리뷰어에게 「Is what the developer intended good for the users of this code?」 · 「Is now a good time to add this functionality?」를 묻게 하고, 「코드만 읽어서는 사용자 영향을 알기 어렵다」며 직접 패치해 써 보거나 시연을 받으라고 한다. 이는 trigger (1) 「선례 없음」을 약하게 만들고 P5를 받친다. 사용자가 확인한 제약도 모두 qg를 기준으로 쓰여 있다(«qg의 모든 범위», «qg 판정을 바꾸지 않고»)."
> premise_refutation:
>   hits: []
> premise_list_challenge: "반증은 없지만 목록에 결함이 넷 있다. (1) P2는 서로 다른 두 가지를 한 문장에 묶었다. (a) 사용자 · 지휘자가 부르는 «입구»를 qg에 둔다 — S1 원문이 받친다. (b) 리뷰어의 입력 · 질문 원장 · 답의 하류를 qg 안에 둔다 — 레포 사실이 이쪽에 불리하다(qg 의도 사슬에 원문 0건 · 다른 플러그인 스크립트에 닿지 못함 · 24시간 GC · 피벗 경로는 spec-distill). 둘로 쪼개야 한다. (2) 빠진 전제가 있다: «리뷰 시점에 의심 대상(사용자 원문 · 고른 것)이 리뷰어 손에 있다». 지금 qg에서는 거짓이다. 이것 없이는 P2 · P5가 맞아도 리뷰어가 압축본을 의심한다. (3) goal 문장 「고른 것 자체를 의심할 자리가 없다」는 레포 기준으로 정확하지 않다. 구현 전 의심 자리(steelman · premortem)는 있되 조건부다. 정확한 뿌리는 «구현 뒤, 돌려 본 근거로, 기본으로 도는 의심 자리가 없다»이다. 그러면 새 자리가 구현 전 의심(audit의 steelman 판정)을 입력으로 받아야 하는지가 전제 목록에 없다. (4) P1은 S3에서 «알아챈 때»를 뽑아 «드러날 수 있는 때»로 일반화했다. S3의 3은 「잘 모르겠네」로 약한 답이다. 반대쪽 근거(premortem)는 근거 기반이 얇아 반증까지는 아니다. 덧붙여 P3(모든 범위에서 같은 강도)와 S3(써 본 뒤 · 로드맵 끝)는 강도의 무게중심이 다르다. 이 차이는 S6(근거 있을 때만 · 상한)가 다 메우지 못한다. 반복 입력은 아니다 — 이 방향으로 처음 부른 것이다."
> recommendation: refined
> refined_takes: "입구는 qg에 둔다. qg의 모든 범위(단일 PR · range · 이름으로 부른 에픽 · 로드맵, 지휘자의 에픽 머지 뒤 · 로드맵 끝 호출)에서 자동으로 돈다. Law 2 분리를 유지한다 — 오케스트레이터가 사람 승인 뒤 /run · /verify로 돌리고 리뷰어는 읽기만 한다. 질문은 판정 밖에 둔다(P4). 근거가 있을 때만 묻고 상한을 둔다(S6). 모델이 먼저 걷고, 사람이 직접 써 볼 자리를 짚는다(S5)."
> refined_drops: "«qg 리뷰어 하나를 더 두고 qg의 의도 사슬과 세션 상태를 그대로 쓴다»는 꼴을 버린다. 대신 넷을 바꾼다. ① 의심 대상인 사용자 원문 · 묶음 · 에픽 블록을 부르는 쪽이 넘긴다 — 지휘자는 인라인으로, 이름 호출은 추적 문서에서. qg 설계문서 사슬만으로 의심하지 않는다. ② 질문과 답은 qg의 24시간 상태가 아니라 docs의 추적 파일에 남긴다. 「잘못 골랐다」는 답은 spec-distill의 피벗 경로(재분해 · 인터뷰 다시 열기)로 보낸다 — 답의 하류는 qg 밖이다. ③ 범위마다 강도를 똑같이 두지 않는다. PR 범위에서는 qg가 이미 만든 실행 근거(차등 테스트 · 승인된 e2e)를 사용자 원문과 대조해 어긋날 때만 묻는다. 넓은 탐색(/run · /verify로 새로 걷기)은 에픽 머지 뒤 · 로드맵 끝 · 이름 호출에 몰아 둔다. ④ «늘 반대하는 역할»을 버린다. 인터뷰 단계의 steelman · premortem이 남긴 의심과 사용자가 「잘 모르겠다」고 한 자리를 입력으로 받아, «돌려 보니 그 의심이 맞았나»를 묻는다 — 연출된 반대와 「늘 뭔가 찾는 리뷰어」를 피하는 진짜 소수 의견에 가깝다."
> evidence:
>   - url: "https://google.github.io/eng-practices/review/reviewer/looking-for.html"
>     supports: current
>     claim: "Google 코드 리뷰 지침은 PR(CL) 리뷰어에게 「Is what the developer intended good for the users of this code?」 · 「Is now a good time to add this functionality?」를 묻게 한다. 또 「It's hard to understand how some changes will impact a user when you're just reading the code」라며 시연을 받거나 직접 패치해 써 보라고 한다 — 구현 뒤 리뷰 게이트에서 의도 자체를 묻고, 실행 근거로 보강하는 선례다."
>     touches: [P2, P5]
>     decides: []
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://scrumguides.org/scrum-guide.html"
>     supports: alternative
>     claim: "Sprint Review는 「inspect the outcome of the Sprint and determine future adaptations」이다. 이해관계자와 함께하고, 「a working session … avoid limiting it to a presentation」이며, 「The Product Backlog may also be adjusted」라고 한다 — 증분 뒤 방향 재검토를 코드 리뷰와 떨어진 정해진 박자의 행사로 둔다."
>     touches: [P1, P2]
>     decides: [OQ5]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://code.claude.com/docs/en/best-practices"
>     supports: alternative
>     claim: "공식 권장은 의도 질문을 작업 전에 둔다(「Interview me until you could write the spec, then write it to SPEC.md」). 리뷰어는 SPEC.md와 대조만 한다. 또 「A reviewer that's asked to find problems will always find something」이라고 경고한다 — 모든 범위에서 상시 도는 쓴소리는 지어낸 지적의 위험을 안는다."
>     touches: [P3]
>     decides: [OQ5]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://code.claude.com/docs/en/best-practices"
>     supports: current
>     claim: "「Once Claude says it's done, you can also run /verify … That catches the kind of problem that tests and typechecks miss」 — 구현 뒤 실제로 돌려 보면 서류 · 테스트 대조가 놓치는 문제를 잡는다."
>     touches: [P5]
>     decides: []
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://code.claude.com/docs/en/skills.md"
>     supports: current
>     claim: "/verify는 「Build and run your app to confirm a code change does what it should」이다. 기록된 방법이 없으면 잘 된 방법을 .claude/skills/verify/SKILL.md에 남겨 다음 실행과 다른 agent가 따른다. 띄우는 방법은 README · package.json · Makefile 같은 프로젝트 파일에서 추론한다 — 산출물이 대화형 skill인 대상을 어떻게 «써 보는지»는 적혀 있지 않다. 명령 실행에 사용자 승인이 필요한지도 문서에 없다."
>     touches: [P5]
>     decides: [OQ4]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://researchr.org/publication/Boehm00a/bibtex"
>     supports: current
>     claim: "Boehm(2000, IEEE Computer) 「Requirements that Handle IKIWISI, COTS, and Rapid Change」 — «보면 안다(IKIWISI)», 곧 사용자는 동작하는 것을 봐야 요구를 안다는 사실이 미리 확정하는 요구사항 방식을 흔든다. 본문은 열지 못했고 서지와 2차 요약만 봤다."
>     touches: [P1]
>     decides: []
>     source_kind: secondary
>     checked_at: "2026-11-14"
>     certainty: uncertain
>   - url: "https://corporate.jasoncollins.blog/premortem"
>     supports: both
>     claim: "premortem(구현 전 «실패했다고 치고» 원인 찾기)의 근거 기반은 얇다. Klein(2007)의 유일한 인용은 Mitchell · Russo · Pennington(1989)인데, 이 연구는 낸 이유의 «수»가 늘었다는 것만 쟀고 이유의 질은 재지 않았다 — 구현 전 의심 자리의 효과는 약하게만 뒷받침되며, P1을 반증하지 못한다."
>     touches: [P1]
>     decides: []
>     source_kind: secondary
>     checked_at: "2026-11-14"
>     certainty: uncertain
>   - url: "https://behavioralscientist.org/stop-playing-devils-advocate-and-other-advice-for-better-decision-making/"
>     supports: both
>     claim: "Nemeth 계열 연구(2차 요약): 진짜 소수 의견이 역할로 맡긴 devil's advocate보다 나았고, 역할극 반대는 처음 견해를 오히려 굳혔다 — 자리가 qg 안이든 밖이든 «늘 반대하는 역할»보다 실제 근거나 기존 의심에 기댄 질문이 낫다."
>     touches: [P3]
>     decides: [OQ5]
>     source_kind: secondary
>     certainty: uncertain
> repo_claims:
>   - id: RC37
>     path: "CLAUDE.md"
>     anchor: "devbrew의 역할은 사용자가 의식적으로 기억하지 않아도 이 세 가지가 자동으로 지켜지도록 만드는 것이다"
>     line: 7
>     claim: "레포의 존재 이유가 «기억하지 않아도 자동으로»다 — 사용자가 이미 부르는 게이트(qg)에 의심 자리를 다는 원안의 핵심 근거다."
>     touches: [P2]
>     decides: []
>   - id: RC38
>     path: "plugins/spec-distill/skills/pm-interview/SKILL.md"
>     anchor: "| R3 | **Skepticism 통과** | 의심 triggered 방향이 모두 steelman 후 *유지 / 보완 / 전환 / 보류* 중 하나로 판정."
>     line: 514
>     claim: "구현 전 의심 자리(steelman-builder)는 trigger가 있을 때만 도는 조건부 자리다(같은 파일 299행 「조건 자리(steelman-builder)」). goal 문장의 «자리 없음»은 정확히는 «구현 뒤 · 기본으로 도는 자리 없음»이다."
>     touches: [P1]
>     decides: []
>   - id: RC39
>     path: "plugins/quality-gates/scripts/discover-spec.sh"
>     anchor: "grep 'interview|brief|roadmap|로드맵' → 0건"
>     claim: "qg 의도 출처를 찾는 스크립트는 인터뷰 묶음 · brief · 로드맵을 전혀 참조하지 않는다 — qg 안의 리뷰어는 지금 그대로라면 사용자 원문이 아니라 설계문서 압축본을 의심하게 된다."
>     touches: [P2]
>     decides: []
>   - id: RC40
>     path: "plugins/spec-distill/scripts/roadmap_model.py"
>     anchor: "FIELDS = (\"의도\", \"범위\", \"의존\", \"브랜치\", \"묶음\", \"경로 예약\", \"spec\", \"발화\", \"항목\", \"완료\")"
>     line: 234
>     claim: "의심 대상(사용자 원문 번호인 발화 · 인터뷰 묶음 · 브랜치)을 에픽에 잇는 데이터는 spec-distill 쪽에 있다. 설치본 qg는 이 스크립트를 부를 수 없다(CLAUDE.md 「설치본에서 다른 플러그인의 스크립트는 도달 불가다」)."
>     touches: [P2]
>     decides: []
>   - id: RC41
>     path: "plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md"
>     anchor: "`scripts/qg-gc.py` 가 TTL(기본 24시간)이 지난 세션 폴더를 지운다"
>     line: 77
>     claim: "qg 상태는 24시간 뒤 지워진다 — 질문과 답을 «따로 오래 남기는» 자리는 qg 세션 상태 밖이어야 한다."
>     touches: [P4]
>     decides: [OQ5]
>   - id: RC42
>     path: "plugins/spec-distill/references/conducting.md"
>     anchor: "### 6. 머지 뒤 … 부를 skill: 없음. / ### 7. 끝 … 부를 skill: `/quality-gates:quality-pipeline`(범위 입력이 있을 때)."
>     line: 73
>     claim: "지휘자는 머지 뒤 자리(지금은 비어 있음)와 로드맵 끝 자리(qg range 호출, 지적은 후속 PR 하나로)를 이미 갖고 있다 — 에픽 · 로드맵 단위 질문을 낼 박자와 relay 길은 지휘자 쪽에 있다(80행)."
>     touches: [P3]
>     decides: [OQ5]
>   - id: RC43
>     path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
>     anchor: "\"is my PR ready to merge\". One pipeline, one verdict — … a differential test against the baseline (always), an optional human-approved e2e walk"
>     line: 6
>     claim: "qg는 머지해도 되는지 판정하는 게이트이고, 실행 근거(차등 테스트는 늘 · e2e 걷기는 사람 승인 뒤)를 오케스트레이터가 이미 만든다 — 새 리뷰어가 읽을 실행 근거와 승인 경계(S7)가 이미 있다. 판정 게이트라는 성격은 판정 밖 질문(P4)을 따로 남길 자리를 요구한다."
>     touches: [P4, P5]
>     decides: []
>   - id: RC44
>     path: "plugins/quality-gates/references/e2e.md"
>     anchor: "의도 출처에 없는 동작을 기대 상태로 만들지 않는다"
>     line: 21
>     claim: "qg의 지금 걷기는 기대 상태를 의도 출처에서만 뽑는다. 그래서 «써 보면 당연히 필요한데 빠진 것»을 찾는 탐색이 아니다 — PR 범위에서 이미 있는 실행 근거를 다시 쓰는 것만으로는 부족하고, 넓은 탐색은 별도 걷기가 필요하다."
>     touches: [P5]
>     decides: [OQ4]
> ```

**게이트-전 확인** — repo_claims: RC37–RC44 확인 8/8 · 부착 주장: Google eng-practices → P2 · P5 확인, Scrum Guide → P1 · P2 확인, best-practices → P3 · P5 확인, skills.md → P5 확인, Boehm · premortem · Nemeth 미확인(2차) · 재검토 자격: 사유 없음 — 확인된 전제 충돌 0건

**사용자 선택** — 보완 (S8)


## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-11-14) — web: enabled
- check_verbatim_coverage.py — exit 0 (2026-11-14)

## 5. 프로세스 로그

- round 1: d · b — 뿌리 문제(S2) · 알아챈 때(S3). coverage-mapper 첫 dispatch, RC1–RC26 V1 확인
- round 2: b — 외부 근거 처분(S4) · premortem 처분(S5 · S6 · S7). blind-spot-prober · open-researcher 묶음 3
- round 3: steelman — ST1 보완(S8)
- round 4: b — skill 써 보기(S9) · 순서(S10) · 동시 작업 원천(S11)
- round 5: b — 질문 시점(S12) · 탐색 상한(S13)
- round 6: b — 열린 질문 목록 확인(S14) → 포화 판정 1: 아직 — 빈 곳 7개 → 묶음 5 조사(조사 6–10)
- round 7: b — blind_spot 재개방(조사 7) · 새 일의 씨앗(S15) · 원문 갈라 보기(S16) · 지휘자 경유로만(S17 — seed 확인 문장을 뒤집음) · 답마다 파일(S18)
- round 8: b — S17 의 범위 되묻기 → S19(qg 호출 전부, devbrew 동작 통일) · 옆 세션과의 순서 재개방 → S20
- round 9: b — 열린 질문 목록 재확인(S21) → 포화 판정 2: 아직 — 빈 곳 7개(반복 빈 곳 하나)
- round 10: 반복 감지 질문 → 사용자 판단 포화(S22) · 분해 판단(나눈다) · 분해안 승인
- 공시: 포화 판정자 입력(조사 원문 · 결정 · 원장)을 분량 때문에 인라인 대신 작업 트리의 파일(.saturation-input-1.md · .saturation-input-2.md)로 넘겼다 — 그 파일엔 사용자 발화와 인터뷰어 요약이 없고, 판정자에게 그 밖의 인터뷰 기록을 읽지 말라고 했다. 커밋 전에 지운다
- 공시: 조사 agent 가 낸 RC 번호는 임시값이라 인터뷰 전역 번호로 다시 붙였다(조사 3 RC1–5 → RC27–31 · 조사 4 RC1–5 → RC32–36 · 조사 5 RC37–44 그대로 · 조사 9 RC1–12 → RC45–56 · 조사 8 RC1–20 → RC57–76 · 조사 7 RC45–53 → RC77–85 · 조사 10 RC1–14 → RC86–99 · 조사 11 RC100)
- 공시: 묶음 5 의 웹 근거 확인은 본체가 web-fetch 도구로 1차 문서를 읽어 했다(조사 6 — 상한에 세지 않음)
- 확인 RC1 — 확인 — plugins/quality-gates/agents/code-recritic.md#tools: Read, Grep, Glob — 주장과 일치(artifact-adversarial · artifact-critic · security-reviewer 도 6행 같은 값)
- 확인 RC2 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#You run both axes of the differential test yourself — 주장과 일치(68행)
- 확인 RC3 — 확인 — plugins/quality-gates/references/e2e.md#의도 출처에 없는 동작을 기대 상태로 만들지 않는다 — 주장과 일치(21행, 표면 12행)
- 확인 RC4 — 확인 — plugins/quality-gates/references/e2e.md#실행해도 된다는 승인이다 — 주장과 일치(54 · 57행)
- 확인 RC5 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#범위 모드는 고치고 다시 돌지 않고 — 주장과 일치(136행)
- 확인 RC6 — 확인 — plugins/quality-gates/scripts/#grep source_interview|interview|roadmap|로드맵 — 0 파일, 주장과 일치
- 확인 RC7 — 확인 — plugins/spec-distill/references/conducting.md#로드맵 시작 커밋부터 지금 기본 브랜치까지 — 주장과 일치(78 · 79행)
- 확인 RC8 — 확인 — plugins/spec-distill/references/conducting.md#### 6. 머지 뒤 · 부를 skill: 없음. — 주장과 일치(70–75행)
- 확인 RC9 — 확인 — plugins/spec-distill/scripts/roadmap_model.py#FIELDS = ( — 주장과 일치(234행)
- 확인 RC10 — 확인 — CLAUDE.md#설치본에서 다른 플러그인의 스크립트는 도달 불가다 — 주장과 일치(55행)
- 확인 RC11 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#it never lowers or skips a finding — 주장과 일치(195행, discover-spec.sh 4–7행 사슬)
- 확인 RC12 — 확인 — plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md#TTL(기본 24시간) — 주장과 일치(77행)
- 확인 RC13 — 확인 — docs/archive/specs/2026-08-01-qg-impact-driven-qa-runtime-design.md#전량 폐기 — 주장과 일치(57행, LD1 149행)
- 확인 RC14 — 확인 — docs/superpowers/specs/2026-10-09-skill-only-surface-design.md#allowedTools Skill — 주장과 일치(253 · 261행)
- 확인 RC15 — 확인 — docs/superpowers/specs/2026-09-10-spec-review-hook-removal-design.md#rc 0 으로 조용히 실패 — 주장과 일치(468행)
- 확인 RC16 — 확인 — docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md#사람 몫 — 주장과 일치(238행)
- 확인 RC17 — 확인 — plugins/quality-gates/agents/code-recritic.md#과잉 처방 — 주장과 일치(5–6행)
- 확인 RC18 — 확인 — plugins/spec-distill/references/conducting.md#백그라운드 agent 에는 질문 도구가 없다 — 주장과 일치(100행)
- 확인 RC19 — 확인 — plugins/spec-distill/references/conducting.md#--kind relay — 주장과 일치(28행)
- 확인 RC20 — 확인 — plugins/spec-distill/agents/relay-checker.md#You are NOT responsible for judging whether the user's choice — 주장과 일치(23행)
- 확인 RC21 — 확인 — CLAUDE.md#Sealed decision — 주장과 일치(95행)
- 확인 RC22 — 확인 — (옆 워크트리) docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.md#지휘자 없이 도는 흐름을 따로 두지 않는다 — 주장과 일치(13행, audit 124 · 155행 claude -p 일꾼)
- 확인 RC23 — 확인 — (옆 워크트리) docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.audit.md#QUALITY_GATES 5칸 — 주장과 일치(381 · 382행)
- 확인 RC24 — 확인 — plugins/spec-distill/agents/integration-reviewer.md#함께 진행된 에픽의 설계 의도 — 주장과 일치(54행, tools 13행 읽기 전용)
- 확인 RC25 — 확인 — plugins/spec-distill/agents/steelman-builder.md#strongest case for — 주장과 일치(31 · 45행)
- 확인 RC26 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#cost_class: variable — 주장과 일치(12 · 61행)
- 확인 RC27 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#범위 모드는 … 앱을 걷지 않고 — 주장과 일치(136행)
- 확인 RC28 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#PR 본문은 읽지 않는다 — 주장과 일치(168행, discover-spec.sh 0건)
- 확인 RC29 — 확인 — CLAUDE.md#그 채널이 실제로 읽히는지는 못 잰다 — 주장과 일치(66행)
- 확인 RC30 — 확인 — CLAUDE.md#git-ignored, plugin namespace — 주장과 일치(70행, 상태 파일 untracked)
- 확인 RC31 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#an optional human-approved e2e walk — 주장과 일치(8행)
- 확인 RC32 — 확인 — plugins/quality-gates/dependencies.md#| claude-code | 2.1.303 — 주장과 일치(17행)
- 확인 RC33 — 확인 — docs/superpowers/plans/2026-09-08-docreview-design-doc-site.md#존재하지 않는다 — 주장과 일치(1140행)
- 확인 RC34 — 확인 — docs/superpowers/specs/2026-08-05-agent-transparency-design.md#OQ-AA — 주장과 일치(1422행 「-p 에는 답변 채널이 없어」, canUseTool 0건)
- 확인 RC35 — 확인 — docs/superpowers/plans/2026-08-17-devbrew-weight-reduction.md#헤드리스 호출 규격 — 주장과 일치(66행)
- 확인 RC36 — 확인 — docs/superpowers/interview/2026-09-01-seam-and-adjudication-interview.audit.md#권한 게이트 — 주장과 일치(349행)
- 확인 RC37 — 확인 — CLAUDE.md#의식적으로 기억하지 않아도 — 주장과 일치(6행)
- 확인 RC38 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#Skepticism 통과 — 주장과 일치(514 · 299행)
- 확인 RC39 — 확인 — plugins/quality-gates/scripts/discover-spec.sh#interview|brief|roadmap 0건 — 주장과 일치
- 확인 RC40 — 확인 — plugins/spec-distill/scripts/roadmap_model.py#FIELDS = ( — 주장과 일치(234행)
- 확인 RC41 — 확인 — plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md#TTL(기본 24시간) — 주장과 일치(77행)
- 확인 RC42 — 확인 — plugins/spec-distill/references/conducting.md#부를 skill — 주장과 일치(73 · 80행)
- 확인 RC43 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#is my PR ready to merge — 주장과 일치(6행)
- 확인 RC44 — 확인 — plugins/quality-gates/references/e2e.md#의도 출처에 없는 동작 — 주장과 일치(21행)
- 확인 RC45–RC56 — 확인 — 옆 워크트리 seed 13행 · audit 107 · 276 · 368 · 382행 · state S4 · S7–S9 · S12 · S14 · OQ10 — 주장과 일치(조사 9)
- 확인 RC57–RC76 — 확인 — conductor_ledger.py 1193 · review_intents.py 174 · control_plane.py 1212 · roadmap_status.py 885 · roadmap_model.py 245 · roadmap_render.py 343 · integration-reviewer.md 16 · conducting.md 105 · setup-qg.sh 119 · discover-spec.sh 16 · qg-worktree.sh 12 · 38 · e2e.md 24 · e2e-state.sh 218 · merge_check.py 152 · quality-pipeline SKILL.md 136 · 138 — 주장과 일치(조사 8)
- 확인 RC77–RC85 — 확인 — redecompose.md 73 · 5 · spec-review SKILL.md 700 · source_interview · finishing.md path-inside · quality-pipeline SKILL.md docs/ 0건 · 274 · 이 상태 파일 user_statements — 주장과 일치(조사 7)
- 확인 RC86–RC99 — 확인 — docreview_route.py 242 · 942 · stopping-criterion-design.md 325 · synthesize_findings.py 309 · CHANGELOG 4023 · synthesize_artifact_findings.py 43 · 48 · docreview_state.py 1271 · 1555 — 주장과 일치(조사 10)
- 확인 RC100 — 확인 — git show ac2782e4 — 설계문서 넷만 바뀜(조사 11)
- 확인 RC45 — 확인 — (옆 워크트리) docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.md#지휘자 없이 도는 흐름을 따로 두지 않는다. (사용자 확인) — 주장과 일치(13행)
- 확인 RC51 — 확인 — (옆 워크트리) docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.audit.md#QUALITY_GATES 5칸 대응 표 — qg 자리는 저자 제안(사용자 미확인)에만 있다, 주장과 일치(368 · 381행)
- 확인 RC60 — 확인 — plugins/spec-distill/scripts/roadmap_status.py#branch_states — 블록마다 branches · branch_states · tip · specs · bundle · ids 를 낸다, 주장과 일치(885행)
- 확인 RC69 — 확인 — plugins/quality-gates/scripts/qg-worktree.sh#create-head … --range — 범위 끝 커밋 detached worktree, 주장과 일치(12 · 38행)
- 확인 RC72 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#범위는 이미 있는 커밋이라 지금 체크아웃과 다를 수 있다 — 주장과 일치(136행)
- 확인 RC77 — 확인 — plugins/spec-distill/references/redecompose.md#머지되거나 끝난 에픽은 건드리지 않는다 — 주장과 일치(73행)
- 확인 RC78 — 확인 — plugins/spec-distill/references/redecompose.md#spec-distill 이 로드된 적 없는 지휘 세션 — 주장과 일치(5행)
- 확인 RC80 — 확인 — docs/superpowers/interview/2026-11-14-qg-epic-roadmap-intent-review-brief-interview.state.md#user_statements — 그때 S2–S14 13개 중 verbatim 은 S3 하나, 주장과 일치
- 확인 RC81 — 확인 — plugins/spec-distill/skills/spec-review/SKILL.md#source_interview — 설계문서 → brief 링크 실재, qg discover-spec.sh 는 그 링크를 따라가지 않음(RC6 · 0건)
- 확인 RC82 — 확인 — plugins/quality-gates/references/e2e.md#기대 상태는 의도 출처가 약속한 동작에서 뽑는다 — 주장과 일치(21 · 23 · 24행)
- 확인 RC84 — 확인 — CLAUDE.md#GitHub Flow. `main`에서 분기, PR로 merge back. — 주장과 일치
- 확인 RC89 — 확인 — docs/superpowers/specs/2026-09-27-review-stopping-criterion-design.md#must-catch 축의 재제기 금지(버킷 동일 → 자동 처분) — 기각 대안 행, 주장과 일치(325행)
- 확인 RC94 — 확인 — plugins/quality-gates/scripts/synthesize_findings.py#def dedup — (file, line, severity) 그룹핑, CHANGELOG CHECKS-07 미해결, 주장과 일치(309행 · CHANGELOG 4023 · 4032행)

### brief 리뷰 (reviewing-brief — 문서 리뷰 엔진)

- 라운드: 4 · 재리뷰 카운트 2 · 추가 라운드 1 — 승인 게이트 도달 사유: 상한 · 리뷰 완료: 예(4라운드 round_reviewed 참) — 4라운드 뒤 고친 다섯 곳(결정 1 · 문구 4)은 리뷰가 확인하지 않았다(추가 라운드 열지 않음)
- 결정: `## 8. 리뷰 결정` 10건(D1.1–D1.4 · D2.5–D2.8 · D3.9 · D4.10 모두 채택) · 열린 채 남은 항목 5건(abf668a4#r4.1 반영 확인 대기 · 0138b17b#r4.1 · 997c959a#r4.1 · ae71e8f6#r4.1 · eb353eb4#r4.1 — 고쳤으나 미확인) · 판정 못 하고 보류 1건(codex x1 — 항목 파손 edit_scope_multi_anchor)
- codex: 있음(4라운드 모두 정상) · 웹: Claude doc-critic-web · codex 켜짐
- 냉독: 돌지 못함 — brief-readback 에 경로만 실어 문서를 읽지 못했다(gap 판정 없음)
- degrade: critic:all:degraded(번들 · 프로필을 경로로 실음) · readback:readback:degraded(경로로 실음) · readback:readback:unavailable(냉독 못 함)

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S2** ☑ R1 답:
  > 고른 것을 의심할 자리 없음 (권장) — 뿌리 문제는 사용자가 고른 것 자체를 의심할 자리가 없다는 것
- **S3** 🗣 R1 답:
  > 1, 2이고 3은 잘 모르겠네
- **S4** ☑ R2 답:
  > /run · /verify 를 쓴다 (권장) — 실제로 돌려 보기는 Claude Code 의 /run · /verify 에 맡기고 devbrew 는 쓴소리만
- **S5** ☑ R2 답:
  > 모델이 먼저, 사람 자리를 짚음 (권장) — 모델이 먼저 걷고 사람이 직접 써 봐야 알 자리를 질문과 함께 짚는다
- **S6** ☑ R2 답:
  > 근거 있을 때만, 상한 둠 (권장) — 돌려 본 근거가 있는 쓴소리만, 실행당 상한, 없으면 없음이라고
- **S7** ☑ R2 답:
  > 돌리기 전 사람 승인 (권장) — 모델이 고르고 사람이 승인한 뒤 돌린다
- **S8** ☑ R3 답:
  > 보완 (builder·orchestrator 추천) — ST1: 입구는 qg, 사용자 원문은 부르는 쪽이 넘기고 질문 · 답은 docs 추적 파일에, 잘못 골랐다는 spec-distill 피벗 경로로, PR 은 가볍게 · 에픽/로드맵은 넓게, 인터뷰가 남긴 의심을 입력으로
- **S9** ☑ R4 답:
  > 질문 전까지 모델, 그 뒤 사람 (권장) — skill 대상은 모델이 첫 질문까지 걷고 그다음부터는 사람이 직접 써 볼 자리로 짚는다
- **S10** ☑ R4 답:
  > 이 일 먼저, 이음매만 열어 둠 (권장) — 옆 세션의 INTENT.md · 단계표가 오면 넘길 것만 바뀌게
- **S11** ☑ R4 답:
  > 지금은 git, 채널 생기면 그것도 (권장) — 브랜치 · worktree · 열린 PR 을 읽고 못 본 것은 확인 못 함으로
- **S12** ☑ R5 답:
  > 리뷰 끝에 한 번에 (권장) — 사람이 보는 세션은 리뷰 끝에 모아 묻고, 지휘자 자동 호출은 docs 파일에 쌓아 게이트 사이에
- **S13** ☑ R5 답:
  > 규모 공시 + 승인이 상한 (권장) — 시작 전 몇 개를 걸을지 한 줄로 알리고 걷기마다 승인이 곧 상한
- **S14** ☑ R6 답:
  > 맞다 (권장) — 설계로 넘길 열린 질문 OQ12–OQ19 여덟이 맞다
- **S15** ☑ R7 답:
  > 새 일의 씨앗으로 (권장) — 에픽 머지 뒤 · 로드맵 끝의 잘못 골랐다 답은 다음 일의 출발점(seed 후보)으로 남기고 다음 세션 첫 턴을 안내
- **S16** ☑ R7 답:
  > 갈라 보이고 라벨도 의심 (권장) — 직접 쓴 말과 고른 라벨을 나눠 보이고, 고른 라벨은 모델이 제안한 것으로 의심 대상에 넣는다
- **S17** ☑ R7 답:
  > 지휘자 경유로만 — 이름으로 직접 부르기를 지휘자에게 이름을 대면 지휘자가 부른다로 바꾼다(seed 확인 문장을 뒤집음)
- **S18** ☑ R7 답:
  > 답마다 파일, 근거 바뀌면 다시 (권장) — 답 하나에 파일 하나, 대상 커밋 · 실행 결과가 바뀌면 다시 묻고 조용히 지우지 않는다
- **S19** 🗣 R8 답:
  > 2 devbrew내의 동작을 통일시켜서 갈라지지 않게 하고 싶어서야
- **S20** ☑ R8 답:
  > 본체 먼저, 입구는 옆에 맞춰 (권장) — 쓴소리 리뷰어 본체는 지금, 지휘자 경유 입구는 옆 세션 설계가 정해지면 붙인다
- **S21** ☑ R9 답:
  > 맞다 (권장) — 설계로 넘길 열린 질문 일곱(OQ12 · OQ13 · OQ14 · OQ16 · OQ17 · OQ18 · OQ23)이 맞다
- **S22** ☑ R10 답:
  > 포화로 보고 마무리 (권장) — 반복 빈 곳(헤드리스 재측정)은 설계로 넘길 열린 질문, 남은 빈 곳도 설계 단계로
- **S23** 🗣 리뷰 1라운드 답:
  > 1, 2, 3 선택한거로 하자
- **S24** ☑ 리뷰 1라운드 답:
  > 맞다 — R8 의 2 는 qg 호출 전부 경유(PR 하나를 포함해 qg 를 부르는 모든 길이 지휘자를 거친다)였다
- **S25** ☑ 리뷰 1라운드 답:
  > 고친다 — 자동 호출 두 박자 (권장) — 첫 박자에 걸을 목록과 규모를 docs 파일에 남기고 게이트에서 승인하면 둘째 박자에 돌린 뒤 쓴소리한다
- **S26** ☑ 리뷰 1라운드 답:
  > 고친다 — 커밋 키, 관찰 인용 시만 (권장) — 다시 묻는 키는 질문 정체 + 대상 커밋, 실행 결과는 근거로 붙이되 판단에 쓴 관찰이 달라졌다고 인용할 때만 다시 묻는다
- **S27** ☑ 리뷰 1라운드 답:
  > 고친다 — qg 걷기, /verify 는 사람 자리 (권장) — 모델의 걷기는 qg 의 사람 승인 e2e 걷기(재 본 뒤의 /run 포함)로, /verify 는 사람이 직접 불러 볼 자리로
- **S28** ☑ 리뷰 1라운드 답:
  > 고친다 — 이름 호출만 경유 — 통일은 지휘자가 늘 같은 qg 입구를 같은 입력으로 부르는 것, 로드맵 없는 PR 하나는 qg 를 바로 부르고 원문이 없으면 없다고 밝히며 에픽 · 로드맵 이름 호출만 지휘자를 거친다
- **S29** ☑ 리뷰 2라운드 답:
  > 고친다 — Non-goal 빼고 추론 표시 (권장) — 리뷰어에게 실행 도구를 주지 않는다는 Non-goal 을 빼고 실행은 오케스트레이터 · 리뷰어 읽기 전용은 모델 추론으로 남긴다
- **S30** ☑ 리뷰 2라운드 답:
  > 고친다 — 범위별 대상 (권장) — 다시 묻는 키의 대상은 에픽 · 로드맵은 끝 커밋, PR 하나는 리뷰한 트리의 해시로 하고 답 파일은 그 계산에서 뺀다
- **S31** ☑ 리뷰 2라운드 답:
  > 고친다 — 호출 길마다 행선 (권장) — 지휘자를 거친 호출의 잘못 골랐다는 spec-distill 피벗 경로로, 로드맵 없는 PR 하나는 qg 가 docs 파일에 남기고 다음 할 일만 안내한다
- **S32** ☑ 리뷰 2라운드 답:
  > 고친다 — 리뷰 끝난 뒤 다시 생성 (권장) — 로드맵과 에픽 묶음을 확정된 brief 로 다시 만든다
- **S33** ☑ 리뷰 3라운드 답:
  > 고친다 — 먼저 걷고 나중에 대조 (권장) — 리뷰어는 의심 목록 없이 먼저 걷고 쓴소리 후보를 낸 뒤 인터뷰가 남긴 의심을 반증할 가설로 받아 대조한다, 비용이 상한을 넘으면 처음부터 넣되 반례를 찾게 한다
- **S34** ☑ 리뷰 3라운드 답:
  > 열기 (권장) — 재리뷰 상한 뒤 추가 라운드 1회를 연다
- **S35** ☑ 리뷰 4라운드 답:
  > 고친다 — 대상은 기록만 (권장) — 다시 묻는 키에 대상을 쓰지 않고 답에 기록만 하며, 판단에 쓴 관찰이 달라졌다고 인용할 때만 다시 묻는다

## 7. 확산 원자료

- «claude-headless» — https://code.claude.com/docs/en/headless — -p 의 /skill-name 펼침 · permission_denials · dontAsk · --permission-prompts none 의 AskUserQuestion
- «sdk-user-input» — https://code.claude.com/docs/en/agent-sdk/user-input — canUseTool 의 AskUserQuestion 답 · subagent 에선 못 씀
- «claude-skills-verify» — https://code.claude.com/docs/en/skills — 번들 /run · /verify 와 기록되는 verify skill
- «claude-best-practices» — https://code.claude.com/docs/en/best-practices — 작업 전 인터뷰 → SPEC.md · 「늘 뭔가 찾는 리뷰어」 경고
- «claude-code-review» — https://code.claude.com/docs/en/code-review.md — 실행하지 않고 승인 · 차단하지 않는 관리형 리뷰
- «anthropic-harness» — https://www.anthropic.com/engineering/harness-design-long-running-apps — evaluator 가 실행 중 앱을 클릭
- «google-review» — https://google.github.io/eng-practices/review/reviewer/looking-for.html — 의도가 사용자에게 좋은가를 묻는 리뷰 지침
- «scrum-guide» — https://scrumguides.org/scrum-guide.html — Sprint Review
- «sim-users» — https://arxiv.org/html/2601.17087v2 — LLM 모의 사용자의 체계적 오차
- «devils-advocate» — https://behavioralscientist.org/stop-playing-devils-advocate-and-other-advice-for-better-decision-making/ — 역할극 반대 대 진짜 소수 의견
- «coderabbit-study» — https://www.alphaxiv.org/abs/2607.03316v1 — CodeRabbit 리뷰 31,073건 거절률과 원인
- «ask-less» — https://www.opentrain.ai/papers/ask-less-ask-better-allocating-user-attention-in-proactive-llm-agents-with-inter--arxiv-2610.24411/ — 질문 예산
- «gitinject» — https://arxiv.org/pdf/2606.09935 — PR · 이슈 본문 주입으로 CI 토큰 유출
- «ms-cicd» — https://microsoft.com/en-us/security/blog/2026/06/05/securing-ci-cd-in-agentic-world-claude-code-github-action-case — Claude Code GitHub Action 비밀 노출
- «jakesch» — https://arxiv.org/pdf/2302.00560 — 의견을 가진 모델과 함께 쓰기
- «failing-falsify» — https://arxiv.org/abs/2604.02485 — LLM 의 확증 쪽 가설 시험
- «gitlab-changelog» — https://about.gitlab.com/blog/solving-gitlabs-changelog-conflict-crisis/ — 항목마다 파일 하나
- «sonarqube-match» — https://docs.sonarsource.com/sonarqube-server/2025.4/user-guide/issues/solution-overview — 이슈 짝짓기 규칙
- «copilot-memory» — https://docs.github.com/en/copilot/concepts/agents/copilot-memory — 인용 재검증 · 만료
- «bugbot-forum» — https://forum.cursor.com/t/bugbot-should-filter-out-previously-resolved-dismissed-issues/147748 — 글 답이 억제 신호가 아님
- «plugin-evals» — https://code.claude.com/docs/en/plugin-evals.md — 격리 비대화형 세션 평가
- «claude-changelog» — https://code.claude.com/docs/en/changelog — 2.1.323 · 2.1.318 수정

## 8. 리뷰 결정

- D1.1 · r1 · adopt · abf668a4#r1.1 · "고친다 — 자동 호출 두 박자 (권장)" — 세 확정이 서로 부딪친다. 돌리기 전에 사람이 승인하고, 돌려 본 근거가 있을 때만 쓴소리를 낸다. 그런데 지휘자 자동 호출은 백그라운드라 리뷰 도중에 승인을 물을 수 없다. 자동 경로에서는 승인 없이 아무것도 못 돌리고, 근거가 없으니 쓴소리도 없다.
- D1.2 · r1 · adopt · abf668a4#r1.3 · "고친다 — 커밋 키, 관찰 인용 시만 (권장)" — 답을 다시 묻는 조건에 「실행 결과가 바뀌면」을 넣으면, 돌릴 때마다 출력이 조금씩 달라지는 실행(시각 · 순서 · 흔들리는 테스트)에서 이미 「맞다」고 답한 질문이 매번 다시 올라온다.
- D1.3 · r1 · adopt · abf668a4#r1.4 · "고친다 — qg 걷기, /verify 는 사람 자리 (권장)" — 실제로 돌려 보기를 Claude Code 의 /run · /verify 에 맡기는데, 공식 문서상 /verify 는 사용자가 부를 때만 돈다. 모델이 먼저 걷는다는 확정과 지휘자가 자동으로 부르는 길에서는 모델이 /verify 를 부를 수 없다. 게다가 /verify 가 리포 뿌리에 방법을 기록하면 그 파일이 커밋마다 돈다.
- D1.4 · r1 · adopt · abf668a4#r1.2 · "고친다 — 이름 호출만 경유" — PR 하나까지 모든 qg 호출이 지휘자를 거치게 하면 의존 방향이 뒤집힌다. 지금 지휘자는 로드맵 경로를 받아야 돌고, qg 는 spec-distill 에 기대지 않는다. 그런데 이 확정은 로드맵 없는 PR 하나를 qg 로 리뷰하는 길을 없애고, qg 를 spec-distill 의 kill switch 에 묶는다.
- D2.5 · r2 · adopt · 2c0abd98#r2.1 · "고친다 — Non-goal 빼고 추론 표시 (권장)" — 「리뷰어에게 실행 도구를 주거나 실행 격리 장치를 크게 세우는 것」이 모델 추론인데 Non-goal 로 올라가 있습니다. 사용자가 「다시 검증할 것」으로 열어 둔 문제(누가 돌리고 리뷰어가 무엇을 읽는가)를 범위 밖 선언으로 닫고 있습니다.
- D2.6 · r2 · adopt · abf668a4#r2.1 · "고친다 — 범위별 대상 (권장)" — 다시 물을지 정하는 키를 「질문 + 대상 커밋」으로 정했습니다. 그런데 qg 의 PR 리뷰는 커밋이 아니라 매 반복 새로 고친(아직 커밋하지 않은) 트리를 봅니다. 그래서 같은 커밋 안에서 코드가 바뀌어도 다시 묻지 않고, 반대로 커밋할 때마다(답 파일 커밋 포함) 답한 질문이 전부 다시 나옵니다.
- D2.7 · r2 · adopt · abf668a4#r2.2 · "고친다 — 호출 길마다 행선 (권장)" — 로드맵 없이 qg 를 바로 부른 경우에도 「잘못 골랐다」 답을 spec-distill 피벗 경로로 보내도록 정해 두었습니다. 그런데 qg 는 spec-distill 에 기대지 않는다는 리뷰 결정이 있어, 이 호출 길에서는 답이 갈 곳이 없습니다.
- D2.8 · r2 · adopt · f4aceed8#r2.1 · "고친다 — 리뷰 끝난 뒤 다시 생성 (권장)" — 다음 단계로 지정한 로드맵에 본문과 다른 실행 방식과 호출 경로가 남아 있습니다. 현재 본문에 맞춰 로드맵을 정리한 뒤 진행할까요?
- D3.9 · r3 · adopt · abf668a4#r3.1 · "고친다 — 먼저 걷고 나중에 대조 (권장)" — 확정된 항목 하나는 인터뷰가 남긴 의심을 리뷰어의 입력으로 넣는다. 그런데 이 문서가 조사한 근거로는 모델이 받은 가설을 반증하지 않고 확증하는 쪽을 고른다. 게다가 이 위험이 이어지는 열린 질문(PR 범위의 가벼운 쓴소리 기준)은 이 문제를 다루지 않는다. 지금 고를 수 있는 길은 둘이다. 의심을 처음부터 입력으로 넣거나, 리뷰어가 먼저 아무것도 모른 채 걷고 그 뒤에 의심 목록과 대조하는 것이다.
- D4.10 · r4 · adopt · abf668a4#r4.1 · "고친다 — 대상은 기록만 (권장)" — 다시 묻는 키에 대상(PR 이면 리뷰한 트리의 해시)이 들어 있어, 고칠 때마다 이미 「맞다」고 답한 질문이 전부 다시 나온다. 「판단에 쓴 관찰이 달라졌을 때만 다시 묻는다」는 결정과 부딪친다. 대상이 바뀌면 새 질문으로 볼지, 대상은 기록만 하고 다시 묻는 것은 관찰이 달라졌다고 인용할 때만으로 할지 둘 중 하나를 고른다.
- docreview 계수 — spec-distill-59ec298a/2026-11-14-qg-epic-roadmap-intent-review-b2ee3c29b88e21d1 r1: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — spec-distill-59ec298a/2026-11-14-qg-epic-roadmap-intent-review-b2ee3c29b88e21d1 r2: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — spec-distill-59ec298a/2026-11-14-qg-epic-roadmap-intent-review-b2ee3c29b88e21d1 r3: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — spec-distill-59ec298a/2026-11-14-qg-epic-roadmap-intent-review-b2ee3c29b88e21d1 r4: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0
