---
type: roadmap
source_brief: docs/superpowers/interview/2026-11-14-qg-epic-roadmap-intent-review-brief-interview.md
---

# qg 에픽 · 로드맵 리뷰와 쓴소리 리뷰어 — 로드맵

승인된 분해안의 에픽 지도다. 에픽마다 원본 brief · 이 로드맵 · 에픽 묶음을 넘긴다. 상태 칸은 없다 — 단계는 spec-distill 의 `scripts/roadmap_status.py` 가 git 에서 계산한다. 단위는 로드맵 > 에픽(spec 하나) > plan(PR 하나) > task 다.

## 에픽

### R1 — intent-critic 리뷰어 본체
- 의도: qg 안에 사용자가 고른 것 자체를 의심하는 읽기 전용 리뷰어를 PR 범위부터 세운다
- 범위:
  - 한다: 리뷰어 agent · 입력 칸(직접 쓴 말과 고른 라벨을 갈라 보인 원문 · 묶음 · 인터뷰가 남긴 의심) · 근거 있을 때만 · 상한 · 판정 밖 질문 · 리뷰 끝에 한 번에 · 답마다 파일과 근거 키
  - 안 한다: 넓게 보기 · 지휘자 입구 · 이름 풀이
- 의존: 없음
- 브랜치: feature/qg-intent-critic
- 묶음: R1.md
- 경로 예약: plugins/quality-gates/agents/, plugins/quality-gates/skills/quality-pipeline/

### R2 — 넓게 보는 조언자
- 의도: 에픽 · 로드맵 리뷰와 설계 단계에서 intent-critic 이 만들어진 것과 다른 팀의 계획을 읽어 사용자가 놓치거나 잘못 고른 것 · 팀 사이의 갈라짐 · 조율 안 된 중복을 짚는다
- 범위:
  - 한다: 에픽 · 로드맵 리뷰와 의도 문서가 바뀐 변경에서 조언자 부르기 · 읽은 인용을 근거로 받고 스크립트가 확인 · 다른 팀 읽기(팀 지도 · 진행 중인 의도 문서 · 파일 겹침) · 근거의 종류 보이기
  - 안 한다: 걷기 · 실행 · 새 입구 · 팀 사이 조율 자체
- 의존: R1
- 브랜치: feature/qg-wide-walk
- 묶음: R2.md
- 경로 예약: plugins/quality-gates/scripts/, plugins/quality-gates/agents/intent-critic.md, plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md

### R3 — 지휘자 경유 입구
- 의도: 에픽 · 로드맵 이름 호출을 지휘자 경유로 모으고 이름 풀이 · 자동 호출 · 질문 옮기기 · 「잘못 골랐다」의 행선(피벗 경로 · 새 일의 씨앗)을 잇는다
- 범위:
  - 한다: 지휘자의 에픽 · 로드맵 이름 풀이(roadmap_status --json) · spec 승인 앞과 에픽 머지 뒤와 로드맵 끝 자동 호출 · 게이트 사이 질문 옮기기 · 새 일의 씨앗 · 범위로 부른 리뷰가 바뀐 의도 문서를 따라가게 qg 한 곳 고치기 · 머지된 PR 의 범위 확인 · 로드맵 없는 PR 의 qg 직접 호출은 그대로 둔다
  - 안 한다: 걷기 · 실행(두 박자의 걷기 전제는 뺐다) · qg 가 돌려주는 꼴 자체(R5) · 머지된 에픽 다시 열기 · 옆 세션의 팀 구조 자체
- 의존: R1, R2, R5
- 브랜치: feature/conductor-qg-entry
- 묶음: R3.md
- 경로 예약: plugins/spec-distill/references/conducting.md, plugins/spec-distill/skills/epic-conductor/, plugins/quality-gates/scripts/setup-qg.sh, plugins/quality-gates/scripts/intent_origin.py, plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md

### R4 — qg 리뷰 전념 — 고치기 반복을 지휘 흐름으로
- 의도: qg 는 리뷰만 하고 스스로 고치는 반복을 걷어내 고칠 일을 지휘 흐름(구현 담당자 · 재분해)과 qg 를 부른 세션으로 넘기되 옆 세션의 지휘자 설계에 녹인다
- 범위:
  - 한다: qg 고치기 반복 걷어내기 · 고칠 지적을 부른 쪽에 돌려주는 꼴 · 지휘 흐름의 이미 있는 구현 길로 잇기 · 옆 세션 설계에 맞추기
  - 안 한다: 쓴소리 리뷰어 본체 · 옆 세션의 팀 구조 자체
- 의존: R1, R3
- 브랜치: feature/qg-review-only
- 묶음: R4.md
- 경로 예약: plugins/quality-gates/skills/quality-pipeline/SKILL.md, plugins/quality-gates/README.md

### R5 — intent-critic 돌려주는 꼴 계약 · qg 안쪽 뒤처리
- 의도: 부르는 쪽(지휘자 · 사람이 보는 세션)이 intent-critic 의 질문을 받아 옮길 수 있게 qg 가 돌려주는 꼴을 계약으로 굳히고 R1 · R2 가 미룬 qg 안쪽 가장자리를 닫는다
- 범위:
  - 한다: 돌려주는 꼴에 질문 글 · 관찰 · 상태 넷(답 기록 실패 · 답하지 않음 · 묻지 않음 가르기) 싣기 · 묻지 않은 질문과 다른 팀 기록 파일의 자리와 수명 정하기 · 하위 명령을 직접 부를 때 전역 스위치 읽기 · 답 입력 읽기 · 다른 팀 읽기 · 리뷰어 입력 묶음과 공시 · 문서 머리 읽기의 남은 가장자리 · 테스트 틈
  - 안 한다: 지휘 절차 파일 · 지휘자의 자동 호출과 질문 옮기기(R3) · qg 본문 흐름 고치기와 README 다듬기(R4) · 걷기 · 실행
- 의존: R1, R2
- 브랜치: feature/qg-return-contract
- 묶음: R5.md
- 경로 예약: plugins/quality-gates/scripts/intent_critic.py, plugins/quality-gates/scripts/intent_answers.py, plugins/quality-gates/scripts/intent_origin.py, plugins/quality-gates/scripts/other_teams.py, plugins/quality-gates/agents/intent-critic.md, plugins/quality-gates/skills/quality-pipeline/references/

## 지휘 절차

이 로드맵은 지휘자가 이끈다 — `/spec-distill:epic-conductor docs/superpowers/roadmaps/2026-11-14-qg-epic-roadmap-intent-review-brief/roadmap.md`. 다시 불러도 git 과 기계 상태에서 상태를 다시 계산해 같은 자리에서 잇는다. `DEVBREW_SPEC_DISTILL_DISABLE=1` 로 꺼 두면 spec-distill 전체(리뷰 · 상태 계산 포함)가 꺼진다 — 지휘자 없이 진행하려면 끄지 말고 지휘자를 부르지 않은 채 spec-distill 의 `references/conducting.md` 끝 절 「손으로 따르는 절차」 를 따른다.

- 사람 몫(brainstorming · spec 승인 · 계획의 설계에 없던 결정)은 지휘 세션이 한 번에 한 에픽씩 배경과 함께 묻는다.
- 실행 방식은 writing-plans 가 권하는 방식이고, 계획 검토는 계획에 설계에 없던 결정이 있을 때만 기다린다.
- 머지는 사용자가 한다.

## 결정 기록

줄 형식은 `- <블록> · <결정|머지> · <YYYY-MM-DD> · 「원문」` 이다. 인터뷰 뒤의 사용자 말은 새 S 번호 없이 원문 그대로 인용한다. 「머지」 줄은 PR 없이 로컬에서 머지한 에픽에만 적는다 — PR 로 머지한 에픽은 지휘자가 채운 PR 상태로 머지됨이 된다(squash · rebase 포함).

## 재분해 이력

### 2026-11-14 · 처음 로드맵
- 원문:
  - 「승인 (권장)」

### 2026-11-14 · qg 는 리뷰만 — 고치기 반복을 걷어내 지휘 흐름으로 넘기는 새 에픽 R4
- 바뀜: 새 에픽 R4 「아니 qg의 리뷰이후 액션인 고치는게 지휘와 갈라지다보니 qg자체 개발을 하지 말라는 의미였어」 · 「qg는 리뷰에만 집중해」 · 「1, 어떻게 네이티브하게 녹여낼지 특히 다른 세션에서 만들고 있는 설계를 두고 거기에 녹이면 좋겠네」 · 「이대로 다시 나눈다 (권장)」
- 원문:
  - 「아니 qg의 리뷰이후 액션인 고치는게 지휘와 갈라지다보니 qg자체 개발을 하지 말라는 의미였어」
  - 「qg는 리뷰에만 집중해」
  - 「1, 어떻게 네이티브하게 녹여낼지 특히 다른 세션에서 만들고 있는 설계를 두고 거기에 녹이면 좋겠네」
  - 「이대로 다시 나눈다 (권장)」

### 2026-11-14 · 걷기와 실행을 로드맵에서 빼고 R2 를 넓게 보는 조언자로 — R3 는 R2 뒤로, 리뷰어 이름은 intent-critic
- 바뀜: 바뀐 에픽 R1 · R2 · R3 「같이 보는건 안돼? 두번 돌리는건 토큰 낭비 같은데, 그리고 넓은 탐색은 걷기보다는 내가 잘못된 방향으로 가는게 아닌지 보는게 더 중요해」 · 「이름도 쓴소리 리뷰어보다 다른게 좋겠어」 · 「intent-critic 좋은거 같아」 · 「의도 자체를 점검하는거라는거 잘 명시하고」 · 「내가 놓치거나 잘못 선택한걸 잡아주는 조언자 역할인거지」 · 「선택해야할게 너무 많자나 그리고 여러 팀이 돌게 되면 갈라지기도 할거고」 · 「중복이 조율 안되기도 할거고」 · 「걷기와 실행쪽을 보고싶은게 아니야」 · 「이대로 다시 나눈다 (권장)」
- 원문:
  - 「같이 보는건 안돼? 두번 돌리는건 토큰 낭비 같은데, 그리고 넓은 탐색은 걷기보다는 내가 잘못된 방향으로 가는게 아닌지 보는게 더 중요해」
  - 「이름도 쓴소리 리뷰어보다 다른게 좋겠어」
  - 「intent-critic 좋은거 같아」
  - 「의도 자체를 점검하는거라는거 잘 명시하고」
  - 「내가 놓치거나 잘못 선택한걸 잡아주는 조언자 역할인거지」
  - 「선택해야할게 너무 많자나 그리고 여러 팀이 돌게 되면 갈라지기도 할거고」
  - 「중복이 조율 안되기도 할거고」
  - 「걷기와 실행쪽을 보고싶은게 아니야」
  - 「이대로 다시 나눈다 (권장)」

### 2026-11-15 · R3 를 둘로 — qg 가 돌려주는 꼴 계약과 qg 안쪽 뒤처리는 새 에픽 R5 로 지금, 지휘자 경유 입구(R3)는 옆 로드맵의 지휘 절차 개편 설계 뒤로. 두 박자의 걷기 전제를 뺀다
- 바뀜: 바뀐 에픽 R3 · 새 에픽 R5 「그래」 · 「이대로 다시 나눈다 (권장)」
- 원문:
  - 「그래」
  - 「이대로 다시 나눈다 (권장)」

### 2026-11-20 · R3 의 경로 예약과 범위를 넓힌다 — R3 설계가 qg 의 한 곳(범위로 부른 리뷰가 바뀐 의도 문서를 따라가게)을 고치고 머지된 PR 의 범위를 확인하기로 했다
- 바뀜: 바뀐 에픽 R3 「이대로 다시 나눈다 (권장)」 · 「qg 를 작게 고친다 (권장)」 · 「고친다 — 머지 방식별로 범위 확인 (권장)」
- 원문:
  - 「이대로 다시 나눈다 (권장)」
  - 「qg 를 작게 고친다 (권장)」
  - 「고친다 — 머지 방식별로 범위 확인 (권장)」

## 위험 번호표

번호는 brief §5 위험 줄마다 박힌 번호(`- 위험 K<n> — …`)다. 박은 번호는 그 위험의 정체다 — 지운 위험의 번호는 다시 쓰지 않는다. 번호가 박히지 않은 옛 brief 만 숨은 가정 · 실패 양식 · 리뷰 참고 순으로 줄 순서대로 번호를 달고, 그렇게 매겼다고 알린다. 오른쪽은 brief 원문 그대로다.

- K1 — 위험 — 숨은 가정: 모델이 대신 써 보면 사용자가 직접 써 보고 알아챈 순간을 재현할 수 있다 — 사람 손 확인으로 남겨 온 전례 — RC16 (docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md#손 확인) [RC16 → OQ4]
- K2 — 위험 — 숨은 가정: 늘 쓴소리하는 역할이 진짜 반대만큼 가치 있다 — 재비판자는 하지 않은 일 요구를 낮춘다 — RC17 (plugins/quality-gates/agents/code-recritic.md#과잉 처방) [RC17 → OQ8]
- K3 — 위험 — 숨은 가정: 판정 밖 질문 채널도 읽히고 답이 달린다 — 레포는 채널이 읽히는지 재지 못한다 — RC29 (CLAUDE.md#축 C) [RC29 → OQ8]
- K4 — 위험 — 숨은 가정: 사용자 원문이 사용자의 선택 그 자체다 — 이 인터뷰 답 34 중 31 이 모델이 쓴 라벨(S2–S35, 직접 쓴 말은 S3 · S19 · S23) — RC80 (docs/superpowers/interview/2026-11-14-qg-epic-roadmap-intent-review-brief-interview.state.md#user_statements) [RC80 → OQ21]
- K5 — 위험 — 숨은 가정: 인터뷰가 남긴 의심을 입력으로 주면 진짜 발견에 다가간다 — 구현 전 의심 장치가 이미 있고 의심 목록이 닻이 된다 — RC25 (plugins/spec-distill/agents/steelman-builder.md#strongest case) [RC25 → OQ14]
- K6 — 위험 — 숨은 가정: 진행 중인 다른 세션 · 에픽 작업을 git 으로 볼 수 있다 — 진행 기록은 커밋 전 untracked — RC30 (CLAUDE.md#런타임 state) [RC30 → OQ10]
- K7 — 위험 — 숨은 가정: 리뷰 시점에 사용자 원문이 qg 의도 사슬 안에 있다 — 범위 모드는 Spec 트레일러 설계문서만 읽는다 — RC28 (plugins/quality-gates/skills/quality-pipeline/SKILL.md#PR 본문은 읽지 않는다) [RC28 → OQ12]
- K8 — 위험 — 숨은 가정: 원문은 부르는 쪽이 넘기면 된다 — 단일 PR 호출엔 넘길 원문이 없고 source_interview 링크는 쓰이지 않는다 — RC81 (plugins/spec-distill/skills/spec-review/SKILL.md#source_interview) [RC81 → OQ14]
- K9 — 위험 — 숨은 가정: 헤드리스 옛 실측이 지금 판에도 맞다 — 맨 이름 호출 실측이 지금 문서와 어긋난다 — RC35 (docs/superpowers/plans/2026-08-17-devbrew-weight-reduction.md#헤드리스 호출 규격) [RC35 → OQ17]
- K10 — 위험 — 실패 양식: 질문 범람 → 사용자가 「맞다」로 일괄 통과 → 채널이 죽는다 — 모든 범위에서 상한 없이 돌 때
- K11 — 위험 — 실패 양식: 아첨 접힘과 반복 재질문 — 「의도다」 답에 근거와 무관하게 물러서거나 답이 남지 않아 같은 질문을 다시 낸다
- K12 — 위험 — 실패 양식: 근거가 서사에 포획된다 — 리뷰어가 오케스트레이터의 요약을 읽고 「의도대로다」로 판정 — RC2 (plugins/quality-gates/skills/quality-pipeline/SKILL.md#differential test yourself) [RC2 → OQ3]
- K13 — 위험 — 실패 양식: 모델이 고른 실행이 리뷰 대상 텍스트에 조종된다 — 사람 승인 명령 경계를 우회할 때 — RC31 (plugins/quality-gates/skills/quality-pipeline/SKILL.md#human-approved e2e walk) [RC31 → OQ9]
- K14 — 위험 — 실패 양식: 피벗 막다른 길 — 재분해는 머지된 에픽을 거부하고 qg 세션엔 spec-distill 루트가 없다 — RC77 (plugins/spec-distill/references/redecompose.md#머지되거나 끝난 에픽) [RC77 → OQ20]
- K15 — 위험 — 실패 양식: 답 원장이 병렬 브랜치에서 충돌하거나 main 에 직접 못 써 사라진다 — RC84 (CLAUDE.md#GitHub Flow) [RC84 → OQ15]
- K16 — 위험 — 실패 양식: 「맞다」 억제가 썩는다 — 레포는 버킷 동일 자동 억제를 기각하고 재상승으로 공시한다 — RC89 (docs/superpowers/specs/2026-09-27-review-stopping-criterion-design.md#재제기 금지) [RC89 → OQ15]
- K17 — 위험 — 실패 양식: 원문 확증 루프 — e2e 기대 상태가 압축본에서 나와 원문 대조가 순환한다 — RC82 (plugins/quality-gates/references/e2e.md#기대 상태) [RC82 → OQ14]
- K18 — 위험 — 실패 양식: 범위 끝 커밋과 체크아웃이 달라 걷기가 꺼진다 — 범위 모드가 걷기를 끈 이유는 그 한 문장뿐 — RC72 (plugins/quality-gates/skills/quality-pipeline/SKILL.md#범위 모드는 고치고 다시 돌지 않고) [RC72 → OQ16]
- K19 — 위험 — 숨은 가정: 리뷰어는 읽기 전용이고 실행은 오케스트레이터가 한다(모델 추론 — 사용자가 열어 두었고 설계가 다시 본다, S29) — RC1 (plugins/quality-gates/agents/code-recritic.md#tools) [RC1 → OQ3]
