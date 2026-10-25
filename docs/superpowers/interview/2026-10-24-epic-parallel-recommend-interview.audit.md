---
type: interview-audit
payload: 2026-10-24-epic-parallel-recommend-interview.md
created_at: 2026-10-25
session_id: 2c4cd0b0-bc55-4ac6-9130-0e998a7b92e7
source: spec-distill pm-interview
---

# 에픽 병렬 권장 — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — 사용자 원문 @S1 · @S5 · @S10
- floor:landscape — closed — 외부 근거 셋 처분 @S5 — 받아들임 + 의도 갈라짐도 봐야 함
- floor:skepticism — closed — steelman ST1 판정 @S13 — refined
- floor:blind_spot — closed — 숨은 가정 · 실패 양식 처분 @S11
- floor:open_questions — closed — OQ 목록 확인 @S15
- derived:추천 신호가 고르는 자리에 닿는 길 — closed — 걸음 3 이 부르는 show --tasks 에 동시 가능 목록이 없다(RC1 · RC2); @S8
- derived:한 번에 한 에픽씩 묻는 규칙과 병렬 권장의 경계 — closed — 사람 질문 단계는 규칙상 직렬(RC5); @S3 · @S13
- derived:겹침 판정의 정의 — closed — 경로 예약 기준 · 공유 파일 제외(RC3 · RC4); @S9 · @S12
- derived:병렬 뒤 회귀와 통합 안전망 — closed — 있는 안전망을 줄이지 않음을 보증(RC7); @S7 · @S11
- derived:조사를 어디에 둘지와 범위 나누기 — closed — 계획 첫 과제 조사 vs spec 단계 조사(RC8 · RC9); @S6
- derived:권장을 보이는 모양과 고를 기회 — closed — 공시 한 줄 vs 질문 · 지휘자가 만든 질문 표시; @S2 · @S13
- derived:검증 방법 — closed — 권장 줄이 실제로 나오는지 무엇으로 증명하나; @S14
- derived:internal_research — closed — 레포 주장 첫 산출(조사 1); 레포 주장 처분 @S13(ST1 리포 주장 11 중 확인 10) · @S11

## 2. Budget

- 질문 라운드: 10 · agent dispatch: 7 · coverage-mapper 1 · codex 실호출: 0 (성공 0)
- 조사 호출 5/60 (장치별: 커버리지 1 · 맹점 1 · 반론 1 · 레포 조사 2 · 만든 조사 0 · 본체 직접 1)
- 포화 판정 1: 아직 — 빈 곳 6개
- 포화 판정 2: 아직 — 빈 곳 5개
- 사용자 종료(@S17) — 마지막 판정 아직

(agent dispatch 7 = 조사 장치 5(coverage-mapper 1 · blind-spot-prober 1 · steelman-builder 1 · repo-researcher 2) + 포화 판정자 2. 본체 직접은 state research_log 의 orchestrator 묶음 수(조사 4)다 — 라운드마다 적은 「본체 직접」 은 레포 주장 확인 행위라 따로 센다.)

## 3. Steelman 원문

#### ST1 — 여덟 변경을 한 에픽에

**dispatch 입력** — goal: S1 · S5 · 전제: P1 권장이 오지 않은 원인은 고르는 자리에 병렬 신호가 없는 것(S1 · RC1 · RC2) · P2 사람 질문 단계는 한 번에 한 에픽씩이고 계획 · 구현만 겹친다(S3) · P3 회귀 · 통합은 기계 검사 밖 의도 갈라짐까지 잡는다(S5 · S7) · P4 이 레포만이 아니라 보편(S10) · 제약: S1–S12 원문 전량 · trigger: 범위 의심 — 여덟 변경(① 병렬 질문 · ② 작업 목록 신호 · ③ 공유 파일 설정 · ④ 조사 기본 · ⑤ 이음매 일곱째 · ⑥ 이웃 결정 노출 · ⑦ 병렬 PR 머지 · ⑧ 조사가 범위를 넓힐 때 재판단)을 한 에픽에 묶음 ✎(state 에 dispatch 입력 원문이 없어 builder 출력의 P · ① ~ ⑧ 참조에서 되짚었다)

> ```yaml
> case_for_alternative:
>   statement: "여덟 가지를 둘로 나눈다. 에픽 A(권장 신호: ①②③)를 먼저 내고, 에픽 B(통합 안전: ④⑤)를 뒤에 낸다. ⑥⑦⑧은 새로 만들지 않는다. 레포에 이미 있는 장치(이웃 에픽 결정 · 머지 뒤 재대조 · 재분해 신호)가 맡는다."
>   strongest: "S1의 불만(「왜 병렬진행 추천이 안온걸까」)은 ①② 둘로 바로 풀린다. 여덟을 한 에픽에 넣으면 conducting.md · control_plane.py · roadmap_status.py · repo_defaults · spec_review_bundle.py · conductor_ledger.py · integration-reviewer.md · redecompose.md를 한 번에 고친다. Google 소형 CL 지침의 「one self-contained change」를 넘는 크기이고, 리뷰가 흐려지며 되돌리기도 어려워진다. 여덟 중 셋은 레포에 이미 있다. ⑥은 spec_review_bundle.neighbors()가 겹치는 이웃 에픽의 결정을 그 브랜치 끝에서 읽는다. ⑦은 conducting.md 걸음 6 · 손 절차 8이 머지 뒤 재대조와 「기본 브랜치가 움직이면 다시 돈다」를 이미 정해 둔다. ⑧은 redecompose.md §1이 열린 신호 목록에 예약 파일 겹침을 이미 둔다. 이 셋을 새 규칙으로 다시 적으면 YAGNI가 말하는 carry 비용이 생기고, 같은 규칙을 두 군데 적어 둔 사본이 시간이 지나며 서로 어긋난다. ① 질문은 문제가 더 크다. 앞 에픽 계획을 보낸 뒤 다음 에픽 설계로 넘어가는 것이 이미 기본 동작이다. 고를 때마다 「차례로」를 다시 물으면 NN/g가 말하는 cry-wolf 확인창이 된다. 이것이 premortem이 지목한 질문 의식이다."
> case_for_current:
>   strongest: "사용자 goal은 「병렬 권장」과 「회귀 · 통합은 여전히 잘해야해」를 한 문장에 묶었다. A만 먼저 나가면 병렬은 권하는데 의도 이음매(⑤)는 아직 없는 기간이 생긴다. 지금 기계 검사는 스위트 대조와 문구 · 순서 이음매(seam 2)뿐이다. 생성 테스트로 semantic conflict를 잡은 연구의 최선 설정도 28건 중 9건만 잡았다(SAM). P3에 따라 ⑤가 이 결정의 무게를 진다. 둘로 나눠도 병렬 이득은 없다. A와 B가 모두 conducting.md와 control_plane.py를 예약하므로 레포 자신의 규칙상 겹침이다. 결국 차례로 갈 수밖에 없고, 남는 것은 리뷰 두 번과 브랜치 두 개의 비용이다. ③은 과설계가 아니다. 지금 SHARED_BASENAMES(plugin.json · CHANGELOG.md · README.md)는 devbrew 플러그인 레포 전용 이름이다. package.json이나 pyproject.toml을 쓰는 레포에서는 P4(S10)와 CLAUDE.md 「레포 전용 값 금지」를 어긴다. 사용자는 S11에서 다섯 모두 작게 반영하라고 이미 골랐다. 한 설계 리뷰가 여덟 사이의 이음매(②의 출력 계약과 ①의 판단, ⑧과 ②의 재계산)를 한꺼번에 본다."
> premise_refutation:
>   hits: []
> premise_list_challenge: "반증은 아니지만 결함과 빠진 전제가 넷 있다. (1) 「이미 있는 것」 전제가 없다. 여덟 중 ⑥(RC5) · ⑦(RC8) · ⑧(RC9 · RC10)은 레포에 상당 부분 있다. 전제 목록이 이를 적지 않아서 에픽이 있는 장치를 다시 만들 위험이 있다(CLAUDE.md 「있는 것 먼저」). 전제로 더해야 한다: 「⑥⑦⑧은 기존 장치를 넓히거나 가리키는 것으로 족하다」. (2) P1은 범위를 좁혀야 한다. 동시 가능 신호는 에픽 보기(`show <로드맵> <에픽>`)의 「동시에 갈 수 있는 에픽」 줄에 이미 있다(RC2). 원인은 「신호가 없다」가 아니라 「고르는 자리가 읽는 --tasks 출력과 걸음 3 공시 규칙에 없다」이다. 또 기존 parallel_with()는 「준비」만 고르지 않고 끝나지 않은 모든 에픽을 낸다. ②는 「준비」만 걸러야 한다. (3) ②가 기대는 출력 계약 전제가 빠졌다. --tasks는 줄마다 `<제목><탭><작업 상태>`이고 에픽 하나에 작업 하나라는 소비 계약이 있다(RC3). 새 줄이 이 꼴이면 지휘자가 그 줄을 작업으로 만든다. S8(작업 목록 출력에 싣는다)은 닫힌 결정이므로 꼴만 바꾼다. 탭 없는 줄로 내고 소비 규칙에 「탭 없는 줄은 작업이 아니다」를 적는 식이다. (4) 질문 빈도 전제가 빠졌다. P2와 RC4를 보면, 앞 에픽 계획을 보낸 뒤 다음 설계로 가는 것이 이미 기본이다. 그래서 ①의 「차례로」는 기본에서 빠지는 선택이다. 언제 다시 묻는지(같은 세션에서 준비 집합이 바뀔 때만인지)가 정해지지 않으면 질문 의식이 된다. 선례: CLAUDE.md의 epic-conductor 같은 세션 승인 재사용(RC11). 같은 입력으로 다시 불린 것은 아니다(첫 호출)."
> recommendation: refined
> refined_takes: "한 에픽을 유지한다(나누면 같은 파일 예약으로 어차피 차례로 가고, 권장과 안전 사이에 틈이 생긴다). ①은 S2 그대로 권하며 묻는다. 다만 같은 세션에서 준비 에픽 집합이 바뀔 때만 다시 묻는다. ②는 기존 parallel_with() 계산을 「준비」로 걸러 --tasks에 싣는다. 탭 없는 한 줄로 내서 작업 줄 계약을 지킨다. ③은 기존 해결자(repo_defaults의 parallel_default와 같은 길)에 키 하나를 더하고, 기본값은 지금 세 이름이다. ④는 conducting.md 걸음 3에 기본값 문장 하나로 넣는다. ⑤는 integration-reviewer.md에 이음매 7을 넣고 review-pack에 같은 파일을 고친 앞 에픽의 설계문서 의도 절을 싣는다. 실제 빈자리이고 P3의 중심이다."
> refined_drops: "⑥의 새 장치: spec_review_bundle.neighbors()의 near 집합에 진행 중인 병렬 에픽을 더하는 확장으로 낮춘다. ⑦의 새 규칙: 걸음 5 · 6과 손 절차 8에 이미 있으므로 새 절을 만들지 않고, 필요하면 병렬 PR에 적용된다는 한 줄 상호 참조만 둔다. ⑧의 새 메커니즘: 동시 가능 목록은 agent를 보내고 거둘 때마다 로드맵 예약에서 다시 계산된다. 그래서 「조사가 예약 밖 경로를 찾으면 재분해 절차로 예약을 고친다」 한 줄(④ 문장 또는 redecompose.md §1 신호 목록)로 족하다. 고를 때마다 반복하는 ① 질문도 버린다."
> evidence:
>   - {url: "https://google.github.io/eng-practices/review/developer/small-cls.html", supports: alternative, claim: "변경의 적정 크기는 「one self-contained change」이다. 큰 CL은 리뷰에서 중요한 지적이 빠지고 되돌리기가 어렵다. 리팩터링은 기능 변경과 나누는 것이 보통 낫다.", touches: [], decides: [OQ9]}
>   - {url: "https://arxiv.org/abs/2310.02395v1", supports: current, claim: "merge 도구는 semantic 수준 충돌을 놓친다. 생성 단위 테스트로 잡는 최선 설정도 9/28이다. 기계 검사만으로는 의도 충돌을 다 잡지 못한다.", touches: [P3], decides: [OQ9]}
>   - {url: "https://arxiv.org/abs/2507.06762v1", supports: current, claim: "단위 테스트 기반 semantic conflict 탐지기(SMAT)는 false negative 비율이 높다(검색 요약 기준, certainty: uncertain).", touches: [P3], decides: [OQ9]}
>   - {url: "https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue", supports: both, claim: "merge queue는 각 PR을 최신 대상 브랜치와 앞에 줄 선 PR을 합친 상태에서 검사한 뒤 머지한다. 업계는 ⑦의 원리(하나씩 머지하고 합친 뒤 재대조)를 쓴다. devbrew는 이를 걸음 5 · 6에 이미 손 절차로 갖고 있다(RC8).", touches: [], decides: [OQ9]}
>   - {url: "https://docs.aviator.co/mergequeue", supports: current, claim: "서로 기대는 코드를 고친 두 PR은 각자 검사를 통과해도 합친 뒤 빌드가 깨질 수 있다. 같은 파일 겹침이 없어도 통합 위험은 남는다(검색 요약 기준, certainty: uncertain).", touches: [P3], decides: [OQ9]}
>   - {url: "https://www.nngroup.com/articles/confirmation-dialog/", supports: alternative, claim: "일상 동작에 확인을 자주 물으면 사용자는 읽지 않고 누른다(「cry wolf」). 확인은 심각하고 드문 동작에만 쓴다. ①이 고를 때마다 뜨면 질문 의식이 된다.", touches: [], decides: [OQ9]}
>   - {url: "https://martinfowler.com/bliki/Yagni.html", supports: both, claim: "앞당겨 만든 기능은 만드는 비용 · 늦어지는 비용 · 안고 가는(carry) 비용을 치른다. 이미 있는 장치를 다시 적는 ⑥⑦⑧이 여기에 걸린다. 다만 고치기 쉽게 만드는 노력은 YAGNI 대상이 아니다. 실제 다른 레포의 필요(P4)에 답하는 ③ 설정화는 이쪽에 가깝다.", touches: [P4], decides: [OQ9]}
> repo_claims:
>   - {id: RC1, path: "plugins/spec-distill/scripts/roadmap_status.py", anchor: "SHARED_BASENAMES = (\"plugin.json\", \"CHANGELOG.md\", \"README.md\")", line: 60, claim: "겹침에서 빼는 공유 파일이 devbrew 플러그인 레포 이름으로 코드에 박혀 있다. 다른 레포(package.json · pyproject.toml 등)에서는 맞지 않아, ③이 P4에 답하는 실제 빈자리다.", touches: [P4], decides: [OQ9]}
>   - {id: RC2, path: "plugins/spec-distill/scripts/control_plane.py", anchor: "row(\"동시에 갈 수 있는 에픽\"", line: 1222, claim: "동시 가능 신호는 에픽 보기(`show <로드맵> <에픽>`)에 이미 있다. 고르는 자리가 읽는 --tasks(tasks_output)에는 없다. parallel_with()는 준비 단계만이 아니라 끝나지 않은 에픽 전부를 낸다(roadmap_status.py `def parallel_with`).", touches: [P1], decides: [OQ9]}
>   - {id: RC3, path: "plugins/spec-distill/scripts/control_plane.py", anchor: "def tasks_output", line: 383, claim: "--tasks 출력은 줄마다 `<제목>\\t<상태>`이다. conducting.md 손 절차 1의 「줄마다 `<제목><탭><작업 상태>` 이고 에픽 하나에 작업 하나다」가 그 소비 계약이다. ②의 새 줄이 이 꼴이면 지휘자가 그 줄을 작업으로 만든다.", touches: [], decides: [OQ9]}
>   - {id: RC4, path: "plugins/spec-distill/references/conducting.md", anchor: "spec 이 승인되면 지휘 세션은 계획 · 구현으로 들어가지 않고 그 에픽 브랜치의 백그라운드 agent 에 계획을 보낸 뒤 다음 에픽의 설계로 간다", line: 97, claim: "앞 에픽 계획 · 구현이 도는 동안 다음 에픽 설계로 가는 파이프라인 병렬은 이미 기본이다(걸음 3 보내기에도 「같은 턴에 다음 에픽의 설계로 간다」). ①의 「차례로」는 이 기본에서 빠지는 선택이다. 빠진 것은 고른 판단을 공시하는 규칙이다.", touches: [P1, P2], decides: [OQ9]}
>   - {id: RC5, path: "plugins/spec-distill/scripts/spec_review_bundle.py", anchor: "def neighbors / near = set(deps) | set(dependents) | overlap", line: 114, claim: "spec 리뷰 묶음은 의존 · 피의존 · 경로 겹침 이웃 에픽의 `## 결정 기록`을 이미 보인다. 머지 전 에픽은 그 브랜치 끝(tip)에서 읽는다. ⑥의 빈자리는 공유 파일만 겹치거나 겹침이 없는 병렬 에픽이 near에서 빠진다는 것뿐이다. near 집합을 넓히는 확장으로 족하다.", touches: [], decides: [OQ9]}
>   - {id: RC6, path: "plugins/spec-distill/scripts/conductor_ledger.py", anchor: "readme = [\"이 폴더는 통합 리뷰 묶음이다", line: 1279, claim: "통합 리뷰 묶음(review-pack)은 pr.diff · open-*.diff · conflicts.txt · handoffs.md만 싣는다. 같은 파일을 고친 앞 에픽의 설계 의도는 없다. ⑤는 실제 빈자리다.", touches: [P3], decides: [OQ9]}
>   - {id: RC7, path: "plugins/spec-distill/agents/integration-reviewer.md", anchor: "## 볼 이음매", line: 41, claim: "이음매 1~6은 이름 · 문구 순서 · 규약 · 합계 · 되살아난 옛 문구 · 인계 확인이다. 앞 에픽 설계 의도와 대조하는 이음매는 없다. ⑤의 일곱째는 새 축이다.", touches: [P3], decides: [OQ9]}
>   - {id: RC8, path: "plugins/spec-distill/references/conducting.md", anchor: "### 6. 머지 뒤 — 열린 에픽 브랜치마다 기본 브랜치를 merge 하고 스위트 대조를 다시 돈다", line: 67, claim: "⑦(하나씩 머지하고 합친 뒤 재대조)은 이미 있다. 걸음 6이 머지 뒤 재merge · 재대조를, 손 절차 8이 「기본 브랜치가 움직이면 다시 돈다」를, 손 절차 6이 「머지는 사용자가 한다」를 정하고, 통합 리뷰어는 「epics merge one PR at a time」을 전제한다.", touches: [P3], decides: [OQ9]}
>   - {id: RC9, path: "plugins/spec-distill/references/redecompose.md", anchor: "## 1. 신호 — 목록은 닫혀 있지 않다", line: 11, claim: "재분해 신호 목록은 열려 있고, 이미 「다른 에픽이 예약한 파일을 고쳐야만 AC 를 채운다」를 담는다. ⑧(조사가 범위를 넓힘)의 길은 예약을 고치는 이 절차로 이미 있다.", touches: [], decides: [OQ9]}
>   - {id: RC10, path: "plugins/spec-distill/references/conducting.md", anchor: "agent 를 보내거나 거둘 때마다 상태 계산의 동시 가능 목록과 승인된 설계의 남은 계획을 훑어", line: 14, claim: "동시 가능 목록은 보내고 거둘 때마다 로드맵 예약에서 다시 계산된다. 예약을 고치면 병렬 재판단은 저절로 따라온다. ⑧에 새 재판단 메커니즘은 필요 없다.", touches: [], decides: [OQ9]}
>   - {id: RC11, path: "CLAUDE.md", anchor: "`epic-conductor` 를 같은 세션에서 같은 규모로 다시 부르면 이미 받은 승인을 다시 쓰고 공시만 한다", claim: "같은 세션 안에서는 받은 답을 다시 쓰고 공시만 하는 선례가 레포에 있다. ①을 고를 때마다 묻지 않고 준비 집합이 바뀔 때만 다시 묻는 refined 경계의 근거다.", touches: [], decides: [OQ9]}
> ```

**게이트-전 확인** — repo_claims 11건: 10 확인(builder RC1~RC10 = RC19~RC28) · 1 반증(builder RC11 = RC29 — CLAUDE.md 의 같은 세션 승인 재사용 문장은 R9(#256)가 지워 지금 없다) · 부착 주장 4/7: 증거 #2 «arxiv-2310.02395» → P3 · #3 «arxiv-2507.06762» → P3 · #5 «aviator-mergequeue» → P3 · #7 «fowler-yagni» → P4 (모두 지지 쪽, 반증 0) · 재검토 자격: 사유 없음 — 확인된 전제 충돌 0건(premise_refutation.hits 비어 있음)

**사용자 선택** — 보완 (S13)

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-10-25) — web: enabled
- check_verbatim_coverage.py — exit 3 (2026-10-25) — 검사 불가: state 의 user_statements 가 한 줄 흐름 꼴(`- {id: S2, …}`)이라 파서가 `- id:` 로 시작하지 않는 항목으로 거부했다. 같은 발화 17개를 블록 꼴로만 옮긴 임시 사본(state 파일은 고치지 않음)으로 돌리면 exit 0 — 누락 0 · 불일치 0 · 모르는 번호 0 · 선택 아님 0
- check_verbatim_coverage.py — exit 0 (2026-10-25) — 오케스트레이터가 state 의 user_statements 17개를 글자 변경 없이 블록 꼴로 옮긴 뒤 다시 돌림 — 누락 0 · 불일치 0 · 모르는 번호 0 · 선택 아님 0

## 5. 프로세스 로그

- round 1: (b) — OQ1 병렬 권장 모양 → S2. 조사 1(coverage-mapper) — 파생 차원 일곱, 레포 주장 RC1~RC9
- round 2: (b) — OQ2 · OQ3 · 외부 근거 처분 묶음 → S3 · S4(되물음) · S5(외부 근거 받아들임 + 의도 갈라짐 요구, OQ4 열림)
- round 3: (b) 되묻기 — OQ3 을 풀어 다시 물음 → S6
- round 4: (b) — OQ4 → S7. 조사 2(blind-spot-prober) 보냄, 본체 직접 확인 RC10
- round 5: (b) — OQ5 · OQ6 → S8 · S9
- round 6: (b) — OQ7 숨은 가정 처분 → S11. 사용자 발화 S10(보편성)으로 OQ8 열림 → S12. 조사 3(steelman-builder) 보냄
- round 7: (b) steelman 의심 게이트 ST1 — OQ9 → S13
- round 8: (b) — OQ10 · 열린 질문 확인 → S14 · S15. 포화 판정 1: 아직(빈 곳 6)
- round 9: (b) — 빈 곳 조사(조사 4 본체 · 조사 5 · 6 repo-researcher)가 결정 넷을 흔들고 OQ11~OQ14 를 엶 → S16 「진행」 으로 넷 모두 추천안
- round 10: 포화 판정 2: 아직(빈 곳 다섯 OQ15~OQ19) → S17 설계로 넘기고 마침 · 분해 판단 → S18 spec 하나로

- 확인 RC1 — 확인 — plugins/spec-distill/scripts/control_plane.py#def tasks_output — 주장과 일치
- 확인 RC2 — 확인 — plugins/spec-distill/scripts/control_plane.py#def epic_view — row("동시에 갈 수 있는 에픽", ...) — 주장과 일치(:1220-1222)
- 확인 RC3 — 확인 — plugins/spec-distill/scripts/roadmap_status.py#def parallel_with — 주장과 일치
- 확인 RC4 — 확인 — plugins/spec-distill/scripts/roadmap_status.py#SHARED_BASENAMES — 주장과 일치(:60)
- 확인 RC5 — 확인 — plugins/spec-distill/references/conducting.md#### 3. 다음 일 고르기와 보내기 — 주장과 일치(:34 · :40)
- 확인 RC6 — 확인 — plugins/spec-distill/references/conducting.md#병렬 권장 수 — 주장과 일치(:19)
- 확인 RC7 — 확인 — plugins/spec-distill/references/conducting.md#### 5. 머지 전 확인 — 주장과 일치
- 확인 RC8 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#2. **흐름.** — 주장과 일치(:8)
- 확인 RC9 — 확인 — plugins/spec-distill/references/epic-handoff.md#있는 것 검토 — 주장과 일치(:7)
- 확인 RC10 — 확인 — plugins/spec-distill/agents/integration-reviewer.md#볼 이음매 — 1~6 이 이름 · 문구 순서 · 경로 규약 · 합계 · 되살아난 문구 · 인계뿐이고 앞 에픽 설계 의도 대조는 없다
- 확인 RC11 — 확인 — plugins/spec-distill/scripts/spec_review_bundle.py#near = set(deps) | set(dependents) | overlap — 주장과 일치(:114)
- 확인 RC12 — 확인 — plugins/spec-distill/scripts/conductor_ledger.py#c_review_pack is-ancestor — 주장과 일치(:1234)
- 확인 RC13 — 확인 — plugins/spec-distill/agents/integration-reviewer.md#볼 이음매 — 주장과 일치(RC10 과 같은 자리)
- 확인 RC14 — 확인 — plugins/spec-distill/scripts/roadmap_status.py#def overlaps — 주장과 일치(:1001)
- 확인 RC15 — 확인 — plugins/spec-distill/references/conducting.md#보내기 — 주장과 일치(:40)
- 확인 RC16 — 확인 — plugins/spec-distill/references/conducting.md#머지 명령 줄만 준비 — 주장과 일치(:61 · :67)
- 확인 RC17 — 확인 — plugins/spec-distill/references/conducting.md#### 4. 돌아오기 — 주장과 일치
- 확인 RC18 — 확인 — shared/tests/test_no_new_duplication.sh#20줄 이상 완전히 같은 블록 — 주장과 일치(:6)
- 확인 RC19 — 확인 — plugins/spec-distill/scripts/roadmap_status.py#SHARED_BASENAMES — 주장과 일치
- 확인 RC20 — 확인 — plugins/spec-distill/scripts/control_plane.py#row("동시에 갈 수 있는 에픽" — 주장과 일치
- 확인 RC21 — 확인 — plugins/spec-distill/scripts/control_plane.py#def tasks_output — 주장과 일치(소비 계약 conducting.md:95 「에픽 하나에 작업 하나」)
- 확인 RC22 — 확인 — plugins/spec-distill/references/conducting.md#다음 에픽의 설계로 간다 — 주장과 일치(:40 · :97)
- 확인 RC23 — 확인 — plugins/spec-distill/scripts/spec_review_bundle.py#near = set(deps) | set(dependents) | overlap — 주장과 일치
- 확인 RC24 — 확인 — plugins/spec-distill/scripts/conductor_ledger.py#이 폴더는 통합 리뷰 묶음이다 — 주장과 일치(:1279)
- 확인 RC25 — 확인 — plugins/spec-distill/agents/integration-reviewer.md#볼 이음매 — 주장과 일치
- 확인 RC26 — 확인 — plugins/spec-distill/references/conducting.md#### 6. 머지 뒤 — 주장과 일치(:67)
- 확인 RC27 — 확인 — plugins/spec-distill/references/redecompose.md#1. 신호 — 주장과 일치(:16 예 「다른 에픽이 예약한 파일을 고쳐야만 AC 를 채운다」)
- 확인 RC28 — 확인 — plugins/spec-distill/references/conducting.md#보내거나 거둘 때마다 — 주장과 일치
- 확인 RC29 — 반증 — CLAUDE.md#`epic-conductor` 를 같은 세션에서 같은 규모로 다시 부르면 — 그 자리는 R9(#256)가 지운 뒤라 지금 CLAUDE.md 에 없고 주장은 그 문장이 있다고 했다
- 확인 RC30 — 확인 — plugins/spec-distill/references/conducting.md#판정 보관본(`## 판정` 아래 `### <계획>`) — 구현 중 판정 목록은 설계문서 `## 판정` 절에 보관된다(:51) — 의도 대조가 설계문서를 읽으면 판정도 함께 본다
- 확인 RC31 — 확인 — plugins/spec-distill/references/conducting.md#### 5. 머지 전 확인 — 병렬 PR 머지 순서 규칙 없음(:61)
- 확인 RC45 — 확인 — plugins/spec-distill/scripts/spec_review_bundle.py#DECISION_LINE_RE — `- B\d+ · 결정 · ` 만(:32) · R14 설계 B 0 · D 19
- 확인 RC46 — 확인 — plugins/spec-distill/scripts/control_plane.py#def tasks_output — 호출자 하나(:1320)
- 확인 RC47 — 확인 — plugins/spec-distill/scripts/repo_defaults.py#KEYS — 닫힌 집합(:36) · COUNT_KEYS(:30)

### brief 리뷰 (reviewing-brief — 문서 리뷰 엔진)

- 라운드: 3(재리뷰 2/2 — 상한 2 · 기본) · 탐지 리뷰어 1명(doc-critic-web · 프로필) · codex 3회(라운드마다 1) · 재비판 라운드마다 1
- 승인 게이트 도달 사유: 상한 · 리뷰 완료(round_reviewed 참) · 「미검증」 아님
- 마지막 렌더 첫 줄: 리뷰 3라운드를 마쳤다 — 열린 지적 2개 — 미뤄 둔 결정 1개 · 아직 안 고친 곳 1개가 남았다. 경고 3개: 판정하지 못하고 보류한 지적이 있다 (x1 — 항목 파손: anchor/summary 부재) · 판정하지 못하고 보류한 지적이 있다 (x2 — 항목 파손: anchor/summary 부재) · 판정하지 못하고 보류한 지적이 있다 (x3 — 항목 파손: anchor/summary 부재)
- 1단계 사용자 선택: 얼림 검사 자동 결정(4039a5a0#r3.1) 「그대로 둔다 (권장)」 · 추가 라운드 「열지 않음 (권장)」
- 열린 채 남은 것: 미뤄 둔 결정 30e53be6#r1.1(§1 「같은 세션」 — 사용자가 설계로 미룸) · 아직 안 고친 곳 f0f95e2d#r3.1 — 라운드 3 뒤에 §3 OQ20 과 §2 출처 메모로 고쳤으나 상한이라 관측 라운드가 없어 엔진에는 미적용으로 남는다
- codex 판정 못 함 3건(항목 파손 — anchor 칸이 앵커 꼴이 아니다): x1 S24 「2번」 해석 확인 → §2 출처 메모에 선택지 설명을 적어 답함 · x2 C13 출처 표기 → 라운드 1 결정(40f9462c#r1.1 「맞다 — 그대로 둔다」)과 같은 지적 · x3 D19 조건이 원문에 없음 → §2 출처 메모(S26 선택지 설명)와 참고 OQ21 로 답함
- 참고: 1건(41df26ba#r3.1 overdesign) → brief §3 OQ21 로 박제
- 냉독: 첫 dispatch 는 경로만 넘겨 읽지 못했다(readback agent 에 읽기 도구 없음 — 미수행) · 둘째 dispatch 에 payload 를 인라인으로 실어 돌았다 · gap G1~G5 0건 · G6 1건 · G7 4건(Step B 게이트 앞 글에 세 조각으로)

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S2** ☑ 선택 (round 1 — 병렬 권장 모양):
  > 병렬을 권하며 묻는다 (권장) — 「병렬 (권장)」 · 「차례로」 질문 하나를 띄우고 사용자가 고른다
- **S3** ☑ 선택 (round 2 — 병렬의 범위):
  > 설계는 차례로 — 설계 대화는 한 에픽씩 하고, 계획 · 구현만 겹친다
- **S4** 🗣 발화 (round 2):
  > 뭐를 말하는거지?
- **S5** 🗣 발화 (round 2):
  > 1, 서로의 의도가 갈라지거나 망가지게 되는거도 파악할필요 있을거 같아 다른거 머지로 이전게 망가지면 안되니 기계적인거 보는거도 좋지만
- **S6** ☑ 선택 (round 3 — 조사 자리):
  > 기본으로 적는다 (권장) — 에픽마다 설계 전 꼼꼼한 조사, 계획 첫 단계는 가벼운 다시 확인
- **S7** ☑ 선택 (round 4 — 의도 갈라짐을 잡는 자리):
  > 통합 리뷰어에 더한다 (권장) — 같은 파일을 고친 앞 에픽의 설계 의도도 읽고 대조
- **S8** ☑ 선택 (round 5 — 병렬 판단 신호):
  > 작업 목록 출력에 싣는다 (권장) — 지휘자가 고를 때 보는 출력에 「동시에 갈 수 있는 준비 에픽」 한 줄
- **S9** ☑ 선택 (round 5 — 공유 파일만 겹칠 때):
  > 권한다 (권장) — 같은 플러그인의 공유 파일만 겹쳐도 병렬을 권하고 머지 때 판 번호를 차례로 올려 푼다
- **S10** 🗣 발화 (round 6):
  > 근데 이거도 이 레포만 고려하는게 아니라 보편적 고려해야하는거야
- **S11** ☑ 선택 (round 6 — 숨은 가정 처분):
  > 다섯 모두 작게 반영 (권장)
- **S12** ☑ 선택 (round 6 — 공유 파일 목록):
  > 레포가 정한다 (권장) — 공유 파일 목록은 기본값 셋, 레포가 설정으로 바꾼다
- **S13** ☑ 선택 (round 7 — steelman ST1):
  > 보완 (builder·orchestrator 추천) — 한 에픽 유지, ⑥⑦⑧은 있는 장치를 넓히거나 가리키는 한 줄, 질문은 준비 에픽 집합이 바뀔 때만 다시
- **S14** ☑ 선택 (round 8 — 검증 방법):
  > 출력 테스트 + 변이 (권장)
- **S15** ☑ 선택 (round 8 — 열린 질문 확인):
  > 닫는다 (권장) — 검증 방법 말고 열린 질문 없음
- **S16** 🗣 발화 (round 9):
  > 진행
- **S17** ☑ 선택 (round 10 — 포화 판정 2 뒤 종료):
  > 설계로 넘기고 마친다 (권장) — 남은 세부 다섯을 brief 열린 질문으로 설계에 넘긴다
- **S18** ☑ 선택 (round 10 — 분해 판단):
  > spec 하나로
- **S19** 🗣 발화 (brief 리뷰 1라운드 — 병렬 질문의 뜻, 기타 칸):
  > 앞 에픽이 스펙리뷰로 넘기면 그때부터 병렬가능 스펙 설계를 한다고 보면 돼
- **S20** ☑ 선택 (brief 리뷰 1라운드 — 의도 대조 범위):
  > 고친다 — 함께 진행된 에픽 전부 (권장)
- **S21** ☑ 선택 (brief 리뷰 1라운드 — 머지 큐):
  > 고친다 — 있으면 그것에 맡김 (권장)
- **S22** ☑ 선택 (brief 리뷰 1라운드 — 「진행」의 뜻):
  > 맞다 — 그대로 둔다 (권장)
- **S23** ☑ 선택 (brief 리뷰 1라운드 — 다시 묻는 조건):
  > 설계에서 고친다 (권장)
- **S24** 🗣 발화 (brief 리뷰 2라운드 — 「병렬」 의 뜻, 기타 칸):
  > 그냥 2번으로 하자, 병렬 차례로를 판단하는 대상은 구현을 이야기하는거야
- **S25** 🗣 발화 (brief 리뷰 2라운드 — 「차례로」 의 뜻, 기타 칸):
  > 1, 차례로 에서 구현은 병렬로 못해도 설계는 되는건 1번으로 가면 되겠지
- **S26** ☑ 선택 (brief 리뷰 2라운드 — 머지 큐에 맡기는 범위):
  > 순서만 맡기고 테스트는 확인 (권장)

## 7. 확산 원자료

- «morphllm-worktrees» — https://www.morphllm.com/claude-code-worktrees — worktree 격리와 머지 때 충돌(조사 1, 2차)
- «verdent-parallel» — https://www.verdent.ai/guides/how-to-run-parallel-claude-code-agents — 병렬 agent 영역 나누기 · 차례로 머지(조사 1, 2차)
- «devto-worktrees» — https://dev.to/jcamarate/claude-code-worktrees-parallel-agents-without-the-conflicts-3fnl — 세션마다 맥락이 따로(조사 1, 2차 블로그)
- «fowler-semantic-conflict» — https://martinfowler.com/bliki/SemanticConflict.html — 의미 충돌 정의와 반대쪽 말(조사 2)
- «brun-tse2013» — https://homes.cs.washington.edu/~mernst/pubs/vc-conflicts-tse2013-abstract.html — 충돌이 빌드 · 테스트 실패로도 나타남(조사 2, 1차)
- «git-maintainer-semantic» — https://lore.kernel.ime.usp.br/git/xmqqzfuznn7g.fsf@gitster.g/T/ — git 은 의미 충돌을 돕지 못함(조사 2, 1차)
- «cognition-multi-agents» — https://cognition.com/blog/dont-build-multi-agents — 맥락을 나누지 않은 병렬 agent 의 암묵 결정 충돌(조사 2, 2차)
- «mast» — https://arxiv.org/html/2503.13657v2 — 다중 agent 실패 분류(조사 2, 1차)
- «github-merge-queue» — https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue — 머지 큐(조사 2 · 조사 3, 1차)
- «chalmers-sam» — https://research.chalmers.se/publication/541567 — 단위 테스트 생성으로 의미 충돌 9/29(조사 2, 1차, 확실성 낮음)
- «google-small-cls» — https://google.github.io/eng-practices/review/developer/small-cls.html — 소형 변경(조사 3)
- «arxiv-2310.02395» — https://arxiv.org/abs/2310.02395v1 — 의미 충돌 탐지 9/28(조사 3)
- «arxiv-2507.06762» — https://arxiv.org/abs/2507.06762v1 — SMAT 거짓 음성(조사 3, 검색 요약)
- «aviator-mergequeue» — https://docs.aviator.co/mergequeue — 서로 기대는 PR 의 통합 위험(조사 3, 검색 요약)
- «nngroup-confirmation» — https://www.nngroup.com/articles/confirmation-dialog/ — 확인창 남용(조사 3)
- «fowler-yagni» — https://martinfowler.com/bliki/Yagni.html — YAGNI 비용(조사 3)

## 8. 리뷰 결정

- D1.1 · r1 · hold · 30e53be6#r1.1 · "설계에서 고친다 (권장)" — 질문을 다시 묻는 조건에 원문에 없는 “같은 세션” 제한을 붙여, 세션이 바뀌면 같은 에픽 집합에도 다시 물을 수 있는 해석을 추가했습니다.
- D1.2 · r1 · reject · 40f9462c#r1.1 · "맞다 — 그대로 둔다 (권장)" — “진행”을 네 가지 추천안의 채택으로 해석한 내용을 사용자 발화로 표시했지만, 대화를 계속하라는 뜻과 추천안을 채택한다는 뜻이 구분되지 않습니다.
- D1.3 · r1 · adopt · abf668a4#r1.1 · "고친다 — 함께 진행된 에픽 전부 (권장)" — 앞 에픽의 의도를 대조하는 통합 리뷰 단계(일곱째 이음매)는 같은 파일을 고친 앞 에픽만 본다. 그런데 브리프가 근거로 든 대표 실패는 서로 다른 파일 사이의 의미 충돌이라, 그 쌍은 병렬로 권해지고 머지 때도 아무도 보지 않는다. 대조 범위를 함께 진행된 앞 에픽 전부로 넓히거나, 파일이 다른 경우는 설계 단계의 이웃 결정 노출에만 맡긴다고 밝혀야 한다.
- D1.4 · r1 · adopt · abf668a4#r1.2 · "앞 에픽이 스펙리뷰로 넘기면 그때부터 병렬가능 스펙 설계를 한다고 보면 돼" — 설계를 차례로 하고 계획 · 구현만 겹치기로 정하면서, 「병렬 (권장)」을 고르는 것은 지휘자가 이미 기본으로 하는 일과 같아졌다. 질문이 실제로 무언가를 바꾸는 경우는 「차례로」를 골랐을 때뿐인데, 그때 무엇이 달라지는지가 어디에도 정해져 있지 않다. 지금 상태는 둘 중 하나다 — 질문을 공시 한 줄로 바꾸거나, 질문을 남기고 「차례로」의 동작을 정한다.
- D1.5 · r1 · adopt · abf668a4#r1.3 · "고친다 — 있으면 그것에 맡김 (권장)" — 머지를 한 번에 하나씩 하고, 머지 뒤 다시 대조하는 일을 지휘자의 손 절차로만 정했다. 그런데 아무 레포에서나 맞게 하려면, 레포에 이미 머지 큐나 「최신 기본 브랜치 반영 필수」 보호 규칙이 있는 경우를 다뤄야 한다. 그 경우 기계 검사 몫을 그쪽에 맡길지, 손 절차를 언제나 돌릴지 정해야 한다.
- D2.6 · r2 · reject · 30e53be6#r2.1 · "그냥 2번으로 하자, 병렬 차례로를 판단하는 대상은 구현을 이야기하는거야" — 설계 병렬화를 제외한 문장이 후속 사용자 발화와 충돌하므로, 보호된 목표 절을 스펙 리뷰 시작부터 다음 설계를 허용하는 내용으로 맞출지 결정해야 합니다.
- D2.7 · r2 · adopt · abf668a4#r2.1 · "1, 차례로 에서 구현은 병렬로 못해도 설계는 되는건 1번으로 가면 되겠지" — 「병렬 (권장)」 · 「차례로」 질문에서 「차례로」를 고르면 지휘자가 무엇을 다르게 하는지가 아직 어디에도 없다. 정해진 것은 「병렬」의 뜻뿐이다
- D2.8 · r2 · adopt · abf668a4#r2.2 · "순서만 맡기고 테스트는 확인 (권장)" — 머지 큐나 「최신 기본 브랜치 반영 필수」 규칙이 있으면 기계 재검사를 거기에 맡기기로 했다. 그런데 그 장치가 보장하는 것은 레포가 필수로 걸어 둔 검사뿐이다. 그래서 필수 검사가 테스트 스위트를 돌리지 않는 레포에서는 스위트 대조가 조용히 빠진다 (D16)
- D3.9 · r3 · adopt · 4039a5a0#r3.1 · "그대로 둔다 (권장)" — finding 없이 바뀜: 3. Open Questions (modified)
- docreview 계수 — spec-distill-59ec298a/2026-10-24-epic-parallel-recommend-inter-432de74b2832a8b4 r1: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — spec-distill-59ec298a/2026-10-24-epic-parallel-recommend-inter-432de74b2832a8b4 r2: advice_new=0 · advice_repeat=0 · mc_preexisting_new=3
- docreview 계수 — spec-distill-59ec298a/2026-10-24-epic-parallel-recommend-inter-432de74b2832a8b4 r3: advice_new=1 · advice_repeat=0 · mc_preexisting_new=0
