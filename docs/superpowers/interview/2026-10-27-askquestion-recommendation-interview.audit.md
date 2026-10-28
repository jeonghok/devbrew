---
type: interview-audit
payload: 2026-10-27-askquestion-recommendation-interview.md
created_at: 2026-10-28
session_id: 19459a6e
source: spec-distill pm-interview
---

# AskUserQuestion 추천 표시 — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — 원칙은 있는데 안 지켜진다(S2) · 사례: 분해 판단 질문에서 권고는 터미널 글에만 있고 선택지에 표시가 없어 반대를 골랐다(S3) (@S1 · @S2 · @S3)
- floor:landscape — closed — 외부 근거 처분: Microsoft 라벨 지침 · 도구 관례를 라벨 표시 근거로 취함, 기본값 · 과의존 연구는 위험으로 (@S10)
- floor:skepticism — closed — ST1 판정 보완(refined), 출처 꼬리는 steelman 질문에만 남김 (@S14 · @S22) (재개방 1회 — S18 출처 꼬리 표시가 필요한지 되물음)
- floor:blind_spot — closed — 숨은 가정 · 실패 양식 처분: 넷을 제약으로 받음(도구 안에만 · 자기 처분은 추천 없음 · 지휘자 규칙 함께 · (Recommended) 인정), 나머지는 §5 위험 (@S9)
- floor:open_questions — closed — 열린 질문 확인(OQ11–OQ14), 마무리 때 OQ19 를 더해 넘김 (@S15 · @S24)
- derived:scope — closed — 어떤 질문이 «모든 askquestion» 에 드는가; devbrew 가 띄우는 질문 전부, 외부 skill 질문은 그 skill 몫 (@S11 · @S12)
- derived:intentional_exceptions — closed — 일부러 추천을 비우는 자리와 «모든» 의 충돌; 모델 제안 승인 질문에도 추천을 단다, 자기 산출물 리뷰 지적 처분만 추천 없음 (@S9 · @S19) (재개방 1회 — 조사 7 의 모델 제안 승인 질문 7곳)
- derived:clarity_standard — closed — «명확하게» 의 기준; 첫 자리 + 라벨 (권장) · 여럿이면 여럿 · (Recommended) 인정 · 추천 없으면 화면 표시 없음, 이유는 skill 문서에만 · 과한 강제 장치 금지 (@S4 · @S6 · @S21 · @S23) (재개방 2회 — 조사 12 추천 없는 질문의 첫 자리가 위치로 추천처럼 읽힘)
- derived:enforcement_layer — closed — 집행 층위; 정본 규칙 + 질문 자리 전수 검사, 리뷰어 검사 · 훅 없음 (@S20) (재개방 1회 — S16 리뷰어 검사가 필요한지 되물음)
- derived:downstream_impact — closed — 표기 변경 시 락 · relay 대조 · 버전; 지휘자 규칙 · relay-checker · 문구 락을 같은 변경에서 함께 고친다 (@S4 · @S9)
- derived:internal_research — closed — 내부(레포) 조사 축; 레포 주장 RC1–RC181 처분 — 규칙은 있는데 안 지켜진다(S2), 레포 사실에서 나온 제약 넷을 받음(S9) (@S2 · @S9)

## 2. Budget

- 질문 라운드: 15 · agent dispatch: 14 · coverage-mapper 1 · codex 실호출: 0 (성공 0)
- 조사 호출 12/60 (장치별: 커버리지 1 · 맹점 3 · 반론 1 · 레포 조사 6 · 만든 조사 1 · 본체 직접 1)
- 포화 판정 1: 아직 — 빈 곳 5개
- 포화 판정 2: 아직 — 빈 곳 4개
- 사용자 종료(@S24) — 마지막 판정 아직

(agent dispatch 14 = 조사 장치 12(coverage-mapper 1 · blind-spot-prober 3 · steelman-builder 1 · repo-researcher 6 · open-researcher 1) + 포화 판정자 2. 본체 직접은 state research_log 의 orchestrator 묶음 수(조사 13)다.)

## 3. Steelman 원문

#### ST1 — 라벨 (권장) 의무화 대 출처 꼬리 · 맞서는 지역 규칙

**dispatch 입력** — goal: S1 · 전제: P1 추천이 선택지 밖에만 있으면 고를 때 놓친다(S3 · S8) · P2 추천은 라벨에 표시해야 명확하다(S4) · P3 추천이 없으면 「추천 없음 — 이유」를 밝혀야 빠뜨림과 구별된다(S5 · S7) · P4 여럿이면 여럿 모두(S6) · P5 규칙 문장은 이미 있고 문제는 안 지켜지는 것이다(S2) · P6 자기 산출물 처분 질문은 추천 없음(S9) · 제약: S1–S9 원문 전량 · trigger: landscape 모순 — 기본값 · 과의존 연구 대 라벨 의무, 레포의 기존 기준점 방지 장치

```yaml
case_for_alternative:
  statement: "모든 AskUserQuestion 이 추천 여부를 라벨에서 밝히는 것은 같다. 다만 표지로 「(권장)」/「(Recommended)」 꼬리만 받지 않고, 누가 추천했는지 붙인 꼬리(「(builder 추천)」 · 「(지휘자 추천)」 처럼 「(<누가> 추천)」 꼴)도 정식 표지로 받는다. 추천하는 쪽이 둘 이상이고 서로 다른 선택지를 밀 때는 「(권장)」 하나로 합치지 않는다. 선택지 순서는 추천과 상관없이 정해진 대로 둔다. steelman 질문의 지금 꼴을 예외가 아니라 정식 형태로 삼는 셈이다."
  strongest: "goal 은 '추천이 뭐인지 명확하게' 다. devbrew 질문에는 추천하는 쪽이 여럿 있다. skill 작성자가 템플릿에 박아 둔 고정 (권장)(예: 「그만둠 (권장)」), 모델이 그때그때 하는 판단, builder 와 orchestrator, 지휘자다. 꼬리가 「(권장)」 하나면 '무엇을' 권하는지는 보여도 '누가 · 어떤 근거로' 권하는지는 지워진다. 기본값은 '선택을 설계한 쪽이 이걸 권한다'는 보증 신호를 통해 가장 세게 작동하고(Jachimowicz 2019, d=0.68), '이것은 기본값이다'라고 알려도 그 힘이 줄지 않는다(Bruns 2018 · Loewenstein 2015). 그래서 라벨 표지를 의무로 만들고 나면, 사용자가 그 추천을 따져 볼 지렛대로 남는 것은 출처뿐이다. 이유 한 줄을 붙여도 과의존은 줄지 않는다는 결과도 같은 쪽을 가리킨다(Buçinca 2021). 더 직접적인 문제도 있다. 추천하는 쪽들이 서로 다를 때(builder ≠ orchestrator, skill 원문의 권장 ≠ 지휘자 의견) 두 선택지에 모두 「(권장)」 을 달면 P4 의 '둘 다 좋다'와 '두 쪽이 의견이 갈린다'가 같은 글자가 된다. 그러면 오히려 덜 명확해진다. 지휘자가 옮기는 질문에서도 skill 의 (권장) 과 지휘자의 (권장) 이 같은 글자가 되어, relay-checker 가 그대로 옮겼는지 대조할 수 없게 된다."
case_for_current:
  strongest: "실제로 일어난 실패는 출처를 몰라서 생긴 것이 아니다. 라벨에 표시가 없어서 위에 쓴 권고와 선택지를 잇지 못한 것이다(S3 · S8: 터미널 글은 '로드맵' 을 권했는데 '스펙' 을 골랐다). 「(권장)」/「(Recommended)」 는 사용자가 이미 읽는 단 하나의 표지이고, Claude Code 도구에 이미 있는 관례다. Microsoft 지침도 '(recommended) 를 보충 설명이 아니라 라벨에 붙이라'고 정확히 같은 처방을 낸다. 표지가 한 글자로 정해져 있어야 S5 의 '표시가 있는가' 하나로 기계가 잴 수 있다. 출처 꼬리를 정식 표지로 열면 표지 문법이 늘어나고, 그만큼 검사가 놓치는 꼴이 생긴다. 사용자를 대신 판단하게 될 위험은 이미 P3 · S7(근거 부족이면 추천 없음)과 P6(자기 산출물 처분이면 추천 없음)이 막는다. 표시를 공개해도 기본값 효과가 줄지 않는다는 연구는, 숨긴 nudge 보다 드러낸 nudge 가 낫다는 근거로 읽힌다. 그러니 같은 기준(명확성)에서는 단일 표지가 이긴다."
premise_refutation:
  hits: [P5]
  why: "P5 는 '규칙 문장은 이미 있고(plain-language.md:6) 문제는 안 지켜지는 것이다' 라고 말한다. 그런데 레포를 보면, S3 이 지목한 바로 그 질문은 규칙을 어긴 것이 아니라 지역 규칙대로 돌았다. (1) plugins/spec-distill/skills/pm-interview/references/finishing.md 의 '### 분해 판단 — Step A 직전' 은 일부러 이렇게 설계됐다. 권고는 선택지 밖 「이어서 권고 한 줄 — 「하나로 충분해 보인다 — <이유>」 또는 「나누는 게 좋아 보인다 — <이유>」」 로 내고, 선택지 라벨은 「spec 하나로」 · 「나눈다 — 분해안 보기」 로 (권장) 없이 두며, 「판정은 사용자가 한다」 고 적혀 있다. 즉 S3 의 '추천은 로드맵이라 나왔는데 스펙을 골랐다' 는 이 설계가 낳은 결과다. (2) shared/style/plain-language.md:3 「아래 절차가 출력 형식·원문 보존·분량을 따로 정한 자리에서는 그 절차를 따른다」 · 「부른 skill 이 메시지 모양을 정한 대화(예: brainstorming)에서는 그 skill 을 따르고, 이 블록은 낱말에만 적용한다」 는 line 6 의 규칙을 지역 절차 아래에 둔다. (3) 정반대로 정한 지역 규칙이 셋 있다. steelman.md:92 「`(Recommended)`·`(권장)` 접미사는 붙이지 않는다」, conducting.md:102 「지휘 세션의 의견은 선택지 밖 「지휘자 의견:」 한 줄로만」, relay-checker.md:32 「문장 권장이 라벨 꼬리로 옮겨짐」(어긋남) · :35. 그러니 원인의 상당 부분은 '안 지킴' 이 아니라 '서로 맞서는 지역 규칙이 이긴 것' 이다. P5 의 진단대로 지키는지 재는 장치만 더하면, 그 장치는 일부러 그렇게 만든 자리를 위반으로 잡거나 면제 목록으로 눈을 감는다."
premise_list_challenge: "빠진 전제가 넷 있다. ① 서로 맞서는 지역 규칙을 고쳐 쓰는 일. plain-language.md:3 의 '지역 절차가 이긴다' 는 조항이 이 규칙에도 적용되는지, finishing.md 분해 판단, steelman.md:92, conducting.md:102, relay-checker.md:32·35, 그리고 그 규칙을 잠근 테스트 test_epic_conductor_skill.sh:73-75. 이것들을 먼저 뒤집지 않으면 S2 의 '재는 장치' 는 의미가 없다. S4 가 지휘자 규칙만 이름으로 집었고 나머지는 전제 목록에 없다. ② P4 의 '여럿이면 여럿 모두' 는 '여러 선택지가 다 좋다' 와 '추천하는 쪽들이 서로 다른 것을 민다' 를 구별하지 못한다. steelman 질문은 두 번째 경우라서 출처를 붙인 표지를 쓴다. 이 질문에 단일 「(권장)」 을 의무로 지우면 오히려 덜 명확해진다. 지휘자가 옮기는 질문도 skill 의 (권장) 과 지휘자의 (권장) 을 가를 표지가 있어야 relay-checker 대조가 산다. ③ 라벨은 '돌려줄 값' 이다(conducting.md:102 「라벨(돌려줄 값)」, SDK answers 는 라벨 문자열을 키로 쓴다). 꼬리를 붙이거나 떼면 그 라벨을 글자 그대로 비교하는 소비자와 잠금 테스트(test_end_gates.sh · test_critiquing_artifacts_skill.sh 등)가 함께 움직여야 한다. ④ 모델이 실행 중에 지어내는 라벨이 있다(quality-pipeline 낮춘 지적 게이트의 「<파일 이름>:<줄> (L<k>)」, finishing.md 의 「<모델의 제안>」). 이런 라벨은 정적 문서 검사로 볼 수 없고 실행 중 검사만 본다. OQ4 가 이 차이를 전제로 갖고 있어야 한다. 같은 입력을 다시 받았다는 신호는 없다."
recommendation: refined
refined_takes: "라벨 의무 표시(S4 · S8), 정식 표지 「(권장)」 · 「(Recommended)」(S9), 추천이 없으면 질문 본문에 「추천 없음 — <이유>」(S5 · S7), 권장이 여럿이면 여럿 모두(S6), 자기 산출물을 처분하는 질문은 추천 없음(P6 · Law 2), 지휘자 규칙과 relay-checker 기준을 함께 바꾸는 것(S4)."
refined_drops: "P5 의 '안 지켜지는 것' 이라는 진단과, 그 진단에서 나온 '재는 장치를 먼저 더한다' 는 순서를 버린다. 맞서는 지역 규칙(finishing.md 분해 판단의 문장 권고 · plain-language.md:3 의 지역 우선 조항을 이 규칙에 적용하는 것 · relay-checker.md:32 의 '문장 권장 → 라벨 꼬리 = 어긋남' · 그 잠금 테스트)을 먼저 고친다. 또 '표지는 「(권장)」 문자열뿐' 이라는 한정을 버린다. 추천하는 쪽이 둘 이상인 질문(steelman 의 builder/orchestrator, 지휘자가 옮기는 질문의 skill 대 지휘자)은 「(<누가> 추천)」 꼬리를 추천 표지로 인정하고, 검사도 이것을 '표시 있음' 으로 센다. steelman 의 고정 순서는 그대로 둔다."
evidence:
  - {url: "https://learn.microsoft.com/en-us/windows/win32/uxguide/ctrl-command-links", supports: current, claim: "Labels 절: 'If a response is strongly recommended, add \"(recommended)\" to the label. Be sure to add to the label, not the supplemental explanation.' ... Windows 7 시절 지침", touches: [P1, P2], decides: [], certainty: high}
  - {url: "https://ideas.repec.org/a/cup/bpubpo/v3y2019i02p159-186_00.html", supports: alternative, claim: "기본값 메타분석 d=0.68(95% CI 0.53–0.83). 보증(endorsement)으로 읽힐 때 더 세다. 라벨의 (권장) 은 이 보증 신호.", touches: [], decides: [], certainty: medium}
  - {url: "https://ideas.repec.org/a/eee/joepsy/v65y2018icp41-59.html", supports: both, claim: "기본값의 영향 · 목적을 공개해도 효과가 유의하게 약해지지 않았다(Bruns 외 2018).", touches: [], decides: [], certainty: medium}
  - {url: "https://www.cmu.edu/dietrich/sds/docs/loewenstein/WarningAboutNudged.pdf", supports: both, claim: "기본값을 미리/나중에 알려도 영향이 남았다(Loewenstein 외 2015).", touches: [], decides: [], certainty: medium}
  - {url: "https://www.eecs.harvard.edu/~kgajos/papers/2021/bucinca2021trust.shtml", supports: alternative, claim: "AI 추천에 설명을 붙여도 과의존이 줄지 않았다. 인지 강제 장치가 줄였다. '라벨 (권장) + 이유 한 줄' 만으로는 앵커링을 상쇄하지 못한다.", touches: [], decides: [], certainty: high}
  - {url: "https://code.claude.com/docs/en/agent-sdk/user-input", supports: both, claim: "options[] 는 label · description 만. 추천은 라벨이나 본문 글자로만. 'For logic that must apply to every tool call, use a PreToolUse hook...' 훅은 어느 skill 이 띄웠는지 구별 못 함.", touches: [], decides: [OQ4, OQ5], certainty: high}
  - {url: "https://juejin.cn/post/7667440437863874560", supports: current, claim: "도구 설명은 추천을 맨 앞 + '(Recommended)'. 제3자 재구성.", touches: [P2], decides: [], certainty: low}
repo_claims:
  - {id: RC1 (RC57), path: "shared/style/plain-language.md", anchor: "추천은 「(권장)」으로 표시한다.", line: 6, claim: "추천 없음을 밝히라는 요구는 없다. line 3 이 이 규칙을 지역 절차와 외부 skill 아래에 둔다.", touches: [P3, P5], decides: [OQ5]}
  - {id: RC2 (RC58), path: "plugins/spec-distill/skills/pm-interview/references/finishing.md", anchor: "### 분해 판단 — Step A 직전", line: 33, claim: "권고는 선택지 밖 문장으로만, 라벨엔 (권장) 없음. 「판정은 사용자가 한다」 는 설계 의도가 문서에 적혀 있다. 규칙 위반이 아니라 지역 설계다.", touches: [P1, P5], decides: []}
  - {id: RC3 (RC59), path: "plugins/spec-distill/skills/pm-interview/references/steelman.md", anchor: "도구·라운드 규약의 `(Recommended)`·`(권장)` 접미사는 붙이지 않는다.", line: 92, claim: "(권장) 금지 · 고정 순서 · 출처 라벨. 단일 (권장) 의무와 충돌, 추천하는 쪽이 갈리는 경우를 P4 로 표현 못 함.", touches: [P2, P4, P5], decides: []}
  - {id: RC4 (RC60), path: "plugins/spec-distill/references/conducting.md", anchor: "지휘 세션의 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓰고", line: 102, claim: "지휘자의 추천은 선택지 밖에만. 라벨은 「돌려줄 값」. 지휘자 권장을 라벨로 옮기면 skill 의 권장과 구별할 표지가 필요.", touches: [P1, P5], decides: []}
  - {id: RC5 (RC61), path: "plugins/spec-distill/agents/relay-checker.md", anchor: "「문장 권장이 라벨 꼬리로 옮겨짐」", line: 32, claim: "원안과 반대 방향으로 이빨이 박혀 있다. 리뷰어 층은 이미 있고 뒤집기만 하면 된다.", touches: [P5], decides: [OQ4]}
  - {id: RC6 (RC62), path: "plugins/spec-distill/tests/test_epic_conductor_skill.sh", anchor: "AC9: 지휘자가 만든 질문의 라벨 (권장) 은 어긋남", line: 73, claim: "정적 잠금이 지휘자 질문의 라벨 (권장) 금지를 고정. 같은 PR 에서 뒤집어야 한다.", touches: [P5], decides: [OQ4]}
  - {id: RC7 (RC63), path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md", anchor: "낮춘 지적 게이트 (표면화 뒤 · 라우팅 앞)", line: 714, claim: "라벨을 실행 중에 만든다. 추천도 추천 없음도 없다. 정적 잠금은 실제 라벨을 못 본다.", touches: [P5], decides: [OQ4]}
  - {id: RC8 (RC64), path: "plugins/*/hooks/", anchor: "Grep 'AskUserQuestion' — 0건", claim: "어떤 훅도 AskUserQuestion 을 보지 않는다. 실행 중 검사 층은 새 표면이고 P8 · kill switch · README 정당화 의무를 진다.", touches: [], decides: [OQ4, OQ5]}
```

**게이트-전 확인** — repo_claims: shared/style/plain-language.md#3·6행 확인 · finishing.md#분해 판단 반증(«무권장이 설계 의도» 부분 — 28행은 숫자 컷오프 이야기) · steelman.md#92 확인 · conducting.md#102 확인 · relay-checker.md#32 확인 · test_epic_conductor_skill.sh#AC9 확인 · quality-pipeline/SKILL.md#낮춘 지적 확인 · plugins/*/hooks 확인 · 부착 주장: Microsoft command-links → P1 · P2 확인 · juejin → P2 확인(2차) · 재검토 자격: 열림 1건(P5 충돌 — 맞서는 지역 규칙 확인)

**사용자 선택** — 보완 (S14)

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-10-28) — web: enabled

## 5. 프로세스 로그

- round 1: path (a)(d) — 레포 전수 조사 · 차원 지도 뒤 핵심 문제를 물음 → 안 지켜진다
- round 2: path (b) — 되묻기(사례) → 품질 검사 · 인터뷰 · 분해 판단 사고
- round 3: path (b) — 선택지 밖 추천 · 추천 없을 때 → 라벨 의무 · 「추천 없음」 명시 + 끼어든 발화(여럿이면 여럿)
- round 4: path (b) — 되묻기(실패 조건) → 근거 부족도 허용
- round 5: path (b) — 사례 원인 · 위험 처분 → 보였는데 놓침 · 넷 다 받음
- round 6: path (b) — 바깥 근거 · 범위 → 라벨 근거로 취함 · devbrew 질문 전부
- round 7: path (b) — 되묻기(범위 밖) → 외부 skill 은 괜찮다
- round 8: path (b) — 집행 층 → 정본 + 전수 검사 + 리뷰어
- round 9: steelman ST1 → 보완
- round 10: path (b) — 열린 질문 확인 → 넷으로
- round 11: 포화 판정 1 아직 → 빈 곳 다섯 조사(묶음 4)
- round 12: path (b) — 리뷰어 · 근거 부족 · 출처 꼬리 · 모델 제안 승인 → 되물음 셋 · 추천을 단다
- round 13: path (b) — 되물음에 본체 판단을 붙여 다시 → 리뷰어 빼기 · 이유는 문서에만 · steelman 만
- round 14: 포화 판정 2 아직 → 빈 곳 넷(조사 둘 + 본체 대조 둘) · 추천 위치 · 마무리 → 첫 자리 + 꼬리, 강제 장치 금지 · 마무리
- round 15: 분해 판단 → spec 하나로

- 확인 RC1 — 확인 — shared/style/plain-language.md#추천은 「(권장)」으로 표시한다 — 주장과 일치
- 확인 RC2 — 확인 — shared/tests/test_plain_language_block.sh#블록 동일성 — 주장과 일치(복제만 잰다)
- 확인 RC3 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#고치고 다시 돌기 — 주장과 일치(다섯 자리 모두 (권장) 없음)
- 확인 RC4 — 확인 — plugins/spec-distill/skills/pm-interview/references/saturation.md#중 하나를 받는다 — 주장과 일치
- 확인 RC5 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#첫 선택지가 추천 — 주장과 일치
- 확인 RC6 — 확인 — plugins/spec-distill/skills/pm-interview/references/steelman.md#추천 표시는 출처 라벨뿐 — 주장과 일치
- 확인 RC7 — 확인 — plugins/spec-distill/agents/relay-checker.md#지휘자가 만든 질문의 라벨에 (권장) — 주장과 일치
- 확인 RC8 — 확인 — plugins/spec-distill/skills/spec-review/SKILL.md#설명에 이유 한 줄 — 주장과 일치
- 확인 RC9 — 확인 — plugins/quality-gates/skills/artifact-critique/SKILL.md#산출물로 비평할까요 — 주장과 일치
- 확인 RC10 — 확인 — plugins/spec-distill/tests/test_conductor_dispatch_reference.sh#의견 줄에만 쓴다 — 주장과 일치
- 확인 RC11 — 확인 — shared/style/plain-language.md#6행 — RC1 과 같은 자리
- 확인 RC12 — 미확인 — CLAUDE.md#Law 1 — 부재 주장(grep 0건)은 하한, 따로 재지 않음
- 확인 RC13 — 미확인 — plugins/spec-distill/references/proceed-gate.md#Step B — 이번 라운드 표본 밖
- 확인 RC14 — 확인 — pm-interview/SKILL.md#202 — RC5 와 같은 자리
- 확인 RC15 — 확인 — steelman.md#92 — RC6 과 같은 자리
- 확인 RC16 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#지휘자 자신의 권장은 — 주장과 일치
- 확인 RC17 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#권장 표시를 달지 않는다 — 주장과 일치
- 확인 RC18 — 확인 — spec-review/SKILL.md#702 — RC8 과 같은 자리
- 확인 RC19 — 미확인 — spec-review/SKILL.md#692 — 766행만 확인(일치), 나머지 자리는 표본 밖
- 확인 RC20 — 미확인 — request-framing/SKILL.md#만들고 시작 (권장) — 표본 밖
- 확인 RC21 — 확인 — pm-interview/references/finishing.md#확정하고 /compact 후 brainstorming (권장) — 주장과 일치
- 확인 RC22 — 확인 — pm-interview/references/state-file.md#이어 감 (권장) — 주장과 일치
- 확인 RC23 — 확인 — reviewing-brief/SKILL.md#멈춘다 (권장) — 주장과 일치
- 확인 RC24 — 확인 — epic-conductor/SKILL.md#읽기만 (권장) — 주장과 일치
- 확인 RC25 — 확인 — references/conducting.md#병렬 (권장) — 주장과 일치
- 확인 RC26 — 확인 — project-init/SKILL.md#교체 (권장) — 주장과 일치(128 · 141행 다른 꼴도 확인)
- 확인 RC27 — 확인 — plugin-audit/SKILL.md#여섯 축 전부 (권장) — 주장과 일치
- 확인 RC28 — 확인 — artifact-critique/SKILL.md#1명 (권장) — 주장과 일치
- 확인 RC29 — 확인 — saturation.md#첫 선택지가 추천 — 주장과 일치
- 확인 RC30 — 확인 — proceed-gate.md#60 · spec-review/SKILL.md#766 — 주장과 일치(정본 없음 · 사본 (권장) — 충돌 실재)
- 확인 RC31 — 확인 — conductor-dispatch.md#32 · conducting.md#40 — 주장과 일치(충돌 가능성 실재)
- 확인 RC32 — 확인 — finishing.md#권고 한 줄 · #컷오프는 두지 않는다 — 주장과 일치
- 확인 RC33 — 미확인 — trivia-escape.md#13 — 문장은 실재(이 인터뷰 진입 때 읽음), «유일한 근거» 여부는 해석
- 확인 RC34 — 확인 — redecompose.md#이대로 다시 나눈다 — 주장과 일치
- 확인 RC35 — 미확인 — spec-review/SKILL.md#574 — 표본 밖
- 확인 RC36 — 미확인 — request-framing/SKILL.md#풀이 1 — 표본 밖
- 확인 RC37 — 확인 — quality-pipeline/SKILL.md#Fix-loop decision — RC3 과 같은 사실
- 확인 RC38 — 확인 — quality-gates/references/e2e.md#걸을 것 없음 — 주장과 일치
- 확인 RC39 — 확인 — shared/tests/plain_language_block.py — RC2 와 같은 사실
- 확인 RC40 — 확인 — test_conducting_interview_stage.sh#808 — 주장과 일치
- 확인 RC41 — 미확인 — test_seed_at_path_handoff.sh#100 — 표본 밖
- 확인 RC42 — 확인 — test_conductor_dispatch_reference.sh#30 — RC10 과 같은 자리
- 확인 RC43 — 확인 — relay-checker.md#32 — 주장과 일치
- 확인 RC44 — 미확인 — test_framing_review_contract.sh#141 — 표본 밖
- 확인 RC45 — 미확인 — project-init/tests/test_command_contract.py#253 — 표본 밖
- 확인 RC46 — 미확인 — spec-distill/CHANGELOG.md#1131 — 표본 밖
- 확인 RC47 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#신호 셋과 권고를 위에 적었다 — 선택지에 (권장) 없음 · 권고는 33행 문장
- 확인 RC48 — 확인 — shared/style/plain-language.md#3·6행 — RC1 과 같은 자리, 3행 외부 skill 예외 확인
- 확인 RC49 — 반증 — plugins/spec-distill/skills/pm-interview/references/finishing.md#28행 — 그 자리는 «숫자 신호에 컷오프를 두지 않는다»이고 33행은 오히려 권고 한 줄을 내게 한다. 주장은 «28행이 무권장을 의도로 적었다»였다(38행 · 선택지 무권장 부분은 확인)
- 확인 RC50 — 확인 — plugins/spec-distill/agents/relay-checker.md#문장 권장이 라벨 꼬리로 옮겨짐 — 주장과 일치
- 확인 RC51 — 확인 — steelman.md#92 — 주장과 일치
- 확인 RC52 — 확인 — request-framing/SKILL.md#928 — 주장과 일치
- 확인 RC53 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#낮춘 지적 — 동적 라벨 · multiSelect 확인. «writer 의 처분 권고» 는 해석
- 확인 RC54 — 확인 — plugins/spec-distill/dependencies.md#claude-code | 2.1.303 — 주장과 일치
- 확인 RC55 — 확인 — plugins/spec-distill/references/proceed-gate.md#56 — 주장과 일치. 더해 «제안 이유는 게이트 앞 글에 쓰고» — 추천 이유가 질문 위 글에 있는 꼴 하나 더
- 확인 RC56 — 확인 — plugins/project-init/hooks/hooks.json#matcher — git ls-files 로 hooks.json 셋(나머지 둘은 shared/tests/fixtures) — 주장과 일치
- 확인 RC57 — 확인 — shared/style/plain-language.md#3·6행 — 주장과 일치(3행이 지역 절차 우선)
- 확인 RC58 — 반증 — plugins/spec-distill/skills/pm-interview/references/finishing.md#분해 판단 — 그 자리의 「판정은 사용자가 한다」(28행)는 숫자 신호에 컷오프를 두지 않는다는 뜻이고, 라벨에 추천을 일부러 빼는 의도 문장은 없다. 주장은 «무권장이 설계 의도로 적혀 있다»였다(선택지 밖 문장 권고 · 라벨 무권장이라는 사실은 일치)
- 확인 RC59 — 확인 — steelman.md#92 — 주장과 일치
- 확인 RC60 — 확인 — plugins/spec-distill/references/conducting.md#102 — 라벨(돌려줄 값) · skill 자신의 「(권장)」 글자 그대로 — 주장과 일치
- 확인 RC61 — 확인 — relay-checker.md#32 — 주장과 일치
- 확인 RC62 — 확인 — plugins/spec-distill/tests/test_epic_conductor_skill.sh#AC9 — 73-76행 잠금 — 주장과 일치
- 확인 RC63 — 확인 — quality-pipeline/SKILL.md#낮춘 지적 — 주장과 일치
- 확인 RC64 — 확인 — plugins/*/hooks — hooks.json 은 project-init 하나, AskUserQuestion 매처 없음 — 주장과 일치
- 확인 RC65–RC83 — 표본 확인: RC66 quality-pipeline/SKILL.md#시작 구성 표(382 표 머리) · RC67 review-criteria.md#리뷰 기준(1행) · RC79 audit-workflow.js#UX·디테일(424) · RC83 CLAUDE.md#버그가 리뷰를 탈출하면 — 주장과 일치. 나머지는 미확인(표본 밖)
- 확인 RC84–RC99 — 표본 확인: RC84 steelman.md#92 · RC86 conductor-dispatch.md#32 · RC89 proceed-gate.md#56 · RC93 conducting.md#40 — 앞 라운드에서 확인한 자리와 일치. 나머지 미확인
- 확인 RC100 — 확인 — pm-interview/SKILL.md#220 — 고른 라벨만 기록, 주장과 일치
- 확인 RC101 — 확인 — 2026-10-24-epic-parallel-recommend-interview.state.md#R10 — 그 라운드에 «지금 이해»와 «답» 뿐, 질문 절 없음 — 주장과 일치
- 확인 RC103 — 확인 — test_decompose_surface.sh#27 — 분해 판단 라벨 리터럴 잠금 — 주장과 일치
- 확인 RC102 · RC104–RC107 — 미확인(표본 밖)
- 확인 RC108 — 확인 — docreview_state.py#_CHOICE_LABEL(2135) — 주장과 일치
- 확인 RC109–RC125 — 미확인(표본 밖, 같은 조사의 RC108 확인)
- 확인 RC158 — 확인 — 2026-10-24-…-interview.audit.md#143 — 실행 중 「(권장)」을 모델이 붙인 기록 — 주장과 일치
- 확인 RC159 — 확인 — test_plain_qg_templates.sh#165 — 주장과 일치
- 확인 RC126–RC157 — 미확인(표본 밖. 앞 라운드에서 같은 자리 다수 확인)
- 확인 RC110 — 확인 — plugins/spec-distill/agents/relay-checker.md#4. 「(권장)」 — 4번 · 35행이 「(권장)」 리터럴로 지휘자 권장을 금지 — 주장과 일치. 결정 대조: S4 · S9(지휘자 규칙 함께 고침 — 지휘자 권장도 라벨 (권장)) · S22(출처 꼬리는 steelman 에만)로 지휘자 쪽 출처 꼬리 자체가 생기지 않는다 → 꼬리 틈은 사라지고, relay-checker 4번 · 35행은 «skill 원문 (권장) 은 그대로 · 지휘자 추천도 (권장) 허용»으로 다시 쓴다(설계 몫) [RC110 → 없음]
- 확인 RC93 — 확인 — plugins/spec-distill/references/conducting.md#병렬 (권장) — 지휘자 질문의 라벨 (권장). 새 규칙(S4 · S9)에서는 충돌이 아니라 준수가 된다 [RC93 → 없음]
- 확인 RC95–RC97 — 확인 — multiSelect 세 자리 무표시 — S6 «권장이 여럿이면 여럿 모두»가 덮는다(정본 문장에 multiSelect 를 명시하는 것은 설계 몫) [RC95 → 없음]
- 확인 RC89 — 확인 — plugins/spec-distill/references/proceed-gate.md#둘째 질문 — 모델 제안에 꼬리 없음. S4(추천하면 라벨 (권장)) · S6(여럿 허용) · S22(출처 꼬리 없음)로 «모델이 권하면 그 제안에도 (권장)»이 된다 · 제안 이유를 «게이트 앞 글»에 두는 문장은 S9(도구 안에만)와 맞서 고칠 자리 [RC89 → 없음]
- 확인 RC160 — 확인 — pm-interview/SKILL.md#202 — 위치 규칙 실재
- 확인 RC163 — 미확인 — conductor_ledger.py#approval_line — «승인 줄 7건 모두 (권장)» 계수는 다시 세지 않음
- 확인 RC169 — 확인 — test_plain_qg_templates.sh#165 — 앞 라운드 확인과 같음
- 확인 RC161 · RC162 · RC164–RC168 · RC170–RC181 — 미확인(표본 밖, 다수는 앞 라운드에서 같은 자리 확인)
- 확인 RC67 — 확인 — plugins/quality-gates/references/review-criteria.md#리뷰 기준 — 1행 머리, 주장과 일치
- 확인 RC124 — 확인 — shared/tests/test_plain_language_block.sh#plain_language_block.py — 49행 호출, plain_language_block.py 51–52행 «블록 바이트가 정본과 다르다» — 주장과 일치
- 확인 RC126 — 확인 — shared/style/plain-language.md#추천은 「(권장)」으로 표시한다. — 주장과 일치
- 확인 RC146 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#낮춘 지적 — 711–716행 질문에 추천 표시 없음, 이 세션이 쓴 코드의 지적을 처분 — 주장과 일치
- 확인 RC161 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#되묻기 — 206행 «이유 없는 추천 수락» — 주장과 일치
- 확인 RC162 — 확인 — plugins/spec-distill/agents/relay-checker.md#4. 「(권장)」 — 32행 충실도만 대조 — 주장과 일치
- 확인 RC174 — 확인 — plugins/spec-distill/references/conducting.md#「차례로」 확인 — 41행 «「차례로」 면» 글자 조건 — 주장과 일치
- 확인 RC178 — 확인 — plugins/spec-distill/tests/test_conducting_interview_stage.sh#r3_minus_ban — 825행 부재 락 — 주장과 일치
- 확인 RC179 — 확인 — plugins/spec-distill/tests/test_ledger_wiring.sh#「그만둠 (권장)」 — 39행 닫는 꺾쇠까지 잡음 — 주장과 일치

### brief 리뷰 (reviewing-brief — 문서 리뷰 엔진)

- 라운드: 3 · 재리뷰 카운트 2 · 추가 라운드 0 — 승인 게이트 도달 사유: 상한 · 리뷰 완료: 예
- 결정: `## 8. 리뷰 결정` 13건(채택 7 · 기각 3 · 버림 3) · 열린 채 남은 항목 4건(고칠 곳 1677e331#r3.1 · 40f9462c#r3.1 · eb353eb4#r3.1 — 상한 뒤 저자가 문서에 반영했으나 다시 리뷰받지 않음 · 보류 3건 x1 · x3 · x5 는 edit_scope_multi_anchor)
- codex: 있음 · 웹: Claude doc-critic-web · codex 켜짐
- 냉독: gap 1건 (G7 — OQ14 가 목록이 모였는데도 왜 열림인지 본문만으로 불분명). 냉독 입력에서 frontmatter · §6 원문을 뺐다(본문 §0–§5 · §7 만 실음)
- degrade: 없음(brief_review_degradations 비어 있음) · 리뷰어 입력을 내용 대신 파일 경로로 넘겼다(탐지 · 재비판 · 포화 판정) · check-intent 를 짧은 범위 문자열로 잘못 불러 1라운드 fix 3건이 상향됨(2라운드에 처분)

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S2** ☑ 선택 (round 1):
  > 안 지켜진다 (권장) — 추천 없는 질문을 실제로 받아 고르기 힘들었다. → 질문 자리들을 고치고, 지키는지 재는 장치를 더하는 일이 된다.
- **S3** 🗣 발화 (round 2):
  > 품질 검사 질문 (권장), 인터뷰·리뷰 질문, 로드맵으로 갈지 스펙 하나로 갈지에서 추천이 뭐인지 안나오는데 위에 터미널 글은 추천은 로드맵이라 나왔음 근데 나는 스펙을 골라버림
- **S4** ☑ 선택 (round 3):
  > 라벨에도 의무 (권장) — 추천이 있으면 그 선택지 라벨에 반드시 「(권장)」을 단다. 문장 권고는 이유 설명으로만 남는다. 지휘자 의견 줄 규칙과 relay-checker 대조 기준도 함께 바뀐다.
- **S5** ☑ 선택 (round 3):
  > 「추천 없음」 명시 (권장) — 질문 본문에 「추천 없음 — <이유>」를 쓴다. 일부러 없는 것과 빠뜨린 것이 구별되고, 검사도 «표시가 있는가» 하나로 잴 수 있다.
- **S6** 🗣 발화 (round 3):
  > 그리고 꼭 한개만 권장이 아니라 클로드 코드가 이미 잘하지만 권장이 여러개인 경우 여러개 권장 표시해
- **S7** ☑ 선택 (round 4):
  > 모델이 판단 못 할 때도 — 근거가 모자라 모델이 자신 없을 때도 「추천 없음 — 근거 부족」을 허용한다. 정직하지만 남발될 수 있다.
- **S8** ☑ 선택 (round 5):
  > 보였는데 놓침 — 고를 때 보였지만 선택지에 표시가 없어 연결을 못 했다. → 라벨 표시의 강도가 핵심이 된다.
- **S9** ☑ 선택 (round 5):
  > 추천은 도구 안에만 (권장), 자기 처분은 추천 없음 (권장), 지휘자 규칙 함께 (권장), (Recommended) 도 인정 (권장)
- **S10** ☑ 선택 (round 6):
  > 라벨 근거로 취함 (권장) — Microsoft · 도구 관례를 라벨 표시의 근거로 쓴다. 과의존 연구는 brief 에 위험으로 남기고, 이미 받은 «자기 처분은 추천 없음»이 그 대비가 된다.
- **S11** ☑ 선택 (round 6):
  > devbrew 가 띄우는 것 (권장) — devbrew skill 의 질문 · 문장으로 지시한 질문 · 지휘자가 만든 질문 · 모델이 그 자리에서 만든 질문까지 다 든다. 고칠 자리가 레포 안에서 닫힌다.
- **S12** ☑ 선택 (round 7):
  > 괜찮다 (권장) — 외부 skill 질문은 그 skill 의 몫이다. 지키게 하는 장치는 레포 안(규칙 문장 · 검사 · 리뷰어)으로 충분하다.
- **S13** ☑ 선택 (round 8):
  > 리뷰어 수정 (권장), 정본 + 전수 검사 (권장)
- **S14** ☑ 선택 (round 9):
  > 보완 (builder·orchestrator 추천) — 맞서는 지역 규칙(문체 규칙 3행의 우선 조항 · 분해 판단 · relay-checker · 잠금 테스트)을 먼저 고친다. 추천하는 쪽이 둘 이상인 질문은 「(<누가> 추천)」도 표지로 센다.
- **S15** ☑ 선택 (round 10):
  > 이 넷으로 (권장) — OQ11–OQ14 를 brief 의 열린 질문으로 넘기고 설계 단계가 정한다.
- **S16** 🗣 발화 (round 12):
  > 필요한가?
- **S17** 🗣 발화 (round 12):
  > 추천이 없다면 추천 없음 - 근거 부족 이말이 나오는게 이상하니까 그냥 억지로 적지를 마 없애 
- **S18** 🗣 발화 (round 12):
  > 누가 추천 이표시가 필요 할까?
- **S19** ☑ 선택 (round 12):
  > 추천을 단다 (권장) — 모델이 추천하는 쪽에 「(권장)」을 단다. 분해 판단 같은 사고가 막힌다.
- **S20** ☑ 선택 (round 13):
  > 빼기 (권장) — 정본 규칙 + 전수 검사만 둔다. 리뷰어 검사는 넣지 않고, 왜 검사인지 이유를 적는다.
- **S21** ☑ 선택 (round 13):
  > 문서에만 이유 (권장) — 사용자 화면에는 아무 표시도 없다. 일부러 비운 이유는 skill 문서의 그 질문 옆에만 적어, 검사가 빠뜨린 것과 구별한다.
- **S22** ☑ 선택 (round 13):
  > 점검 질문만 그대로 (권장) — 추천이 둘로 갈리는 점검(steelman) 질문만 지금 표시를 둔다. 나머지는 모두 「(권장)」 하나로 통일한다.
- **S23** 🗣 발화 (round 14):
  > 1, 너무 강제하게 만드는 장치만들거나 하진마
- **S24** ☑ 선택 (round 14):
  > 여기서 마무리 (권장) — 인터뷰를 끝내고 brief 를 쓴다. 판정자의 «포화» 판정 없이 끝낸 것으로 기록된다.
- **S25** ☑ 선택 (round 15):
  > spec 하나로 (권장) — brief 하나를 brainstorming 하나로 넘긴다. 로드맵을 만들지 않는다.
- **S26** ☑ 선택 (round 16):
  > 고친다(채택) — 근거 S6·S20 추가 (권장)
- **S27** ☑ 선택 (round 16):
  > 고친다(채택) — 지휘자 질문은 범위 안 (권장)
- **S28** ☑ 선택 (round 16):
  > 고친다(채택) — 추천 지시 문장 검사 (권장)
- **S29** ☑ 선택 (round 16):
  > 고친다(채택) — 이유는 질문 위 글 (권장)
- **S30** ☑ 선택 (round 17):
  > 고친다(채택) — 지휘자 예외 붙임 (권장)
- **S31** ☑ 선택 (round 17):
  > 고친다(채택) — 리뷰 결정은 추천 단다 (권장)
- **S32** ☑ 선택 (round 17):
  > 그대로 둔다(기각) — 이미 고침 (권장)
- **S33** ☑ 선택 (round 17):
  > 그대로 둔다(기각) — 이미 고침 (권장)
- **S34** ☑ 선택 (round 17):
  > 그대로 둔다(기각) — §3 고침에 함께 (권장)
- **S35** ☑ 선택 (round 18):
  > 고친다(채택) — 옮긴 질문은 순서 유지 (권장)
- **S36** ☑ 선택 (round 18):
  > 열지 않음 (권장)

## 7. 확산 원자료

- «ms-radio» — https://learn.microsoft.com/en-us/windows/win32/uxguide/ctrl-radio-buttons — 「(recommended)」를 라벨에, 보충 설명이 아니라 · 기본값을 두지 말 때
- «ms-cmdlinks» — https://learn.microsoft.com/en-us/windows/win32/uxguide/ctrl-command-links — 같은 라벨 처방
- «cc-tool-desc» — https://raw.githubusercontent.com/Piebald-AI/claude-code-system-prompts/main/system-prompts/tool-description-askuserquestion-without-plan-mode-note.md — 도구 설명문 추출본: 첫 자리 + (Recommended)
- «cc-sdk-approvals» — https://code.claude.com/docs/en/agent-sdk/approvals — 공식 질문 스키마(label · description 뿐)
- «cc-hooks» — https://code.claude.com/docs/en/hooks — PreToolUse 와 질문 도구
- «gh-askuserquestion-hides-text» — https://github.com/anthropics/claude-code/issues/67475 · https://github.com/anthropics/claude-code/issues/75182 — 질문 창이 앞 글을 가림 · 안 그림(gh issue view 로 제목 · 상태 확인)
- «default-effects» — https://ideas.repec.org/a/cup/bpubpo/v3y2019i02p159-186_00.html · https://ideas.repec.org/a/eee/joepsy/v65y2018icp41-59.html — 기본값 효과 메타분석 · 알려도 효과 유지
- «ai-overreliance» — https://www.eecs.harvard.edu/~kgajos/papers/2021/bucinca2021trust.shtml — AI 추천 과의존과 인지 강제
- «apple-hig-alerts» — https://developer.apple.com/design/human-interface-guidelines/alerts — 기본 버튼을 두지 않는 경우
- «cc-cleanup» — https://code.claude.com/docs/en/claude-directory — 세션 파일 30일 정리

## 8. 리뷰 결정

- D1.1 · r1 · adopt · 0fbd6ae3#r1.1 · "고친다(채택) — 근거 S6·S20 추가 (권장)" — Goal · Non-goal 몇 줄이 근거 원문으로 S23 을 달고 있지만 S23 은 그 내용을 말하지 않는다. 「여럿이면 여럿 모두」는 S6 의 말이고, 「리뷰어 검사」 제외는 S20 의 선택이다. Goal 은 보호된 절이라 인용 정정에도 사용자 확인이 필요하다.
- D1.2 · r1 · adopt · abf668a4#r1.1 · "고친다(채택) — 지휘자 질문은 범위 안 (권장)" — 지휘자가 옮겨 띄우는 외부 skill 질문(writing-plans 끝 질문 등)이 고칠 범위 안인지가 두 확정 사이에서 갈린다. 지휘자 규칙을 함께 고친다는 항목은 범위 안으로, 외부 skill 질문은 그 skill 몫이라는 항목은 범위 밖으로 읽힌다.
- D1.3 · r1 · adopt · abf668a4#r1.2 · "고친다(채택) — 추천 지시 문장 검사 (권장)" — 집행 수단(질문 자리 정적 전수 검사와 skill 문서 옆에 적는 이유)이 이 일의 동기 사례와 즉석 질문에 닿지 않는다. 분해 판단처럼 실행 중에 권고가 정해지는 질문은 템플릿에 고정 꼬리를 둘 수 없고, 모델이 그 자리에서 만든 질문에는 이유를 적을 「질문 옆」 자리가 없다.
- D1.4 · r1 · adopt · f0f95e2d#r1.1 · "고친다(채택) — 이유는 질문 위 글 (권장)" — 원문이 두 가지로 읽히는데 brief 가 그 갈림을 적지 않았다. 사용자가 고른 「문장 권고는 이유 설명으로만 남는다」는 질문 밖에 이유 글을 남기는 쪽으로 읽힌다. 뒤에 고른 「추천은 도구 안에만」은 이유도 도구 안으로 옮기는 쪽으로도 읽힌다. 확정 항목에서는 앞 문장이 빠졌다.
- D2.5 · r2 · adopt · 30e53be6#r2.1 · "고친다(채택) — 지휘자 예외 붙임 (권장)" — 범위 밖 항목이 writing-plans 의 질문까지 예외 없이 범위 밖으로 둔다. 그래서 지휘자가 그 질문을 옮겨 띄우면 범위 안이라는 채택 결정과 맞지 않는다.
- D2.6 · r2 · adopt · abf668a4#r2.1 · "고친다(채택) — 리뷰 결정은 추천 단다 (권장)" — 모델이 쓴 문서의 리뷰 지적을 사용자가 처분하는 질문(설계 · brief 리뷰의 결정 질문)이 「자기 처분이라 추천 없음」 쪽인지 「모델 판정 승인이라 추천을 단다」 쪽인지 정해지지 않았다. 그런데 바로 이 인터뷰의 리뷰 결정 질문 넷은 모두 「고친다(채택)」에 (권장)을 달았다.
- D2.7 · r2 · reject · 40f9462c#r2.1 · "그대로 둔다(기각) — 이미 고침 (권장)" — check-intent 거부 후 상향: 「추천은 첫 자리 + 꼬리로 둔다」는 사용자의 말로 표시돼 있지만, 사용자가 실제로 한 말은 「1,」뿐이다. 이 내용은 사용자가 고른 1번 선택지를 모델이 풀어 쓴 것이고, 그 선택지 글은 brief 어디에도 없다. 그래서 근거를 대조할 수 없다.
- D2.8 · r2 · reject · e99bfa50#r2.1 · "그대로 둔다(기각) — 이미 고침 (권장)" — check-intent 거부 후 상향: 범위 항목의 앞부분(「devbrew 가 띄우는 질문 전부」)은 S11 의 선택인데 근거가 S12 하나만 달려 있다. S12 가 뒷받침하는 것은 「외부 skill 질문은 그 skill 몫」이라는 뒷부분뿐이다.
- D2.9 · r2 · reject · ae71e8f6#r2.1 · "그대로 둔다(기각) — §3 고침에 함께 (권장)" — check-intent 거부 후 상향: 「추천 없음」을 허용하는 경우 셋 가운데 「사용자만 아는 것(취향 · 사용자가 가르는 게 목적)」은 어느 원문에도 없다. 그런데 열린 질문 해결에서는 S7 로 해결된 것처럼 적혀 있다. S7 이 뒷받침하는 것은 「근거 부족」 하나다.
- D2.10 · r2 · drop · 40f9462c#r1.1 · "check-intent 를 짧은 범위 문자열로 잘못 불러 상향된 fix — 상향된 결정에서 사용자가 처분함(2라운드)" — 「추천은 첫 자리 + 꼬리로 둔다」는 사용자의 말로 표시돼 있지만, 사용자가 실제로 한 말은 「1,」뿐이다. 이 내용은 사용자가 고른 1번 선택지를 모델이 풀어 쓴 것이고, 그 선택지 글은 brief 어디에도 없다. 그래서 근거를 대조할 수 없다.
- D2.11 · r2 · drop · ae71e8f6#r1.1 · "check-intent 를 짧은 범위 문자열로 잘못 불러 상향된 fix — 상향된 결정에서 사용자가 처분함(2라운드)" — 「추천 없음」을 허용하는 경우 셋 가운데 「사용자만 아는 것(취향 · 사용자가 가르는 게 목적)」은 어느 원문에도 없다. 그런데 열린 질문 해결에서는 S7 로 해결된 것처럼 적혀 있다. S7 이 뒷받침하는 것은 「근거 부족」 하나다.
- D2.12 · r2 · drop · e99bfa50#r1.1 · "check-intent 를 짧은 범위 문자열로 잘못 불러 상향된 fix — 상향된 결정에서 사용자가 처분함(2라운드)" — 범위 항목의 앞부분(「devbrew 가 띄우는 질문 전부」)은 S11 의 선택인데 근거가 S12 하나만 달려 있다. S12 가 뒷받침하는 것은 「외부 skill 질문은 그 skill 몫」이라는 뒷부분뿐이다.
- D3.13 · r3 · adopt · abf668a4#r3.1 · "고친다(채택) — 옮긴 질문은 순서 유지 (권장)" — 추천 선택지를 첫 자리로 옮기라는 결정과, 지휘자가 다른 skill 의 질문을 옮겨 띄울 때 선택지 순서를 글자 그대로 지키라는 지금 규칙이 부딪친다. 지휘자가 옮긴 질문에서 추천을 첫 자리로 옮길지, 원래 순서를 지키고 꼬리만 달지 둘 중 하나로 정해야 한다.
- docreview 계수 — spec-distill-59ec298a/2026-10-27-askquestion-recommendation-in-a0f1820691e6a327 r1: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — spec-distill-59ec298a/2026-10-27-askquestion-recommendation-in-a0f1820691e6a327 r2: advice_new=0 · advice_repeat=0 · mc_preexisting_new=3
- docreview 계수 — spec-distill-59ec298a/2026-10-27-askquestion-recommendation-in-a0f1820691e6a327 r3: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0
