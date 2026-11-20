---
type: interview-audit
payload: 2026-11-20-test-method-rework-brief-interview.md
created_at: 2026-11-20
session_id: 9c43b762-d178-4764-a01a-f4ae19b15dfb
source: spec-distill pm-interview
---

# 테스트 방식 재정비 — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — S1(원자료 — 처음 요청과 framing 의 답) + S2 「skill 본문 전체」 · S3 「스위트 시간」 · S7 「옮겨 적고 고쳐 적는다」 (@S2)
- floor:landscape — closed — S10 — 바깥 근거(프롬프트 서식 민감도 · 평가 먼저 · 고른 테스트만 돌리기)를 보이고 받은 처분, S5 — 대신 지킬 후보 (@S10)
- floor:skepticism — closed — S6 — ST1 판정 「보완」: 기울기는 두고 본체가 도출한 전제 둘을 버린다 (@S6)
- floor:blind_spot — closed — S8 · S9 — 맹점 조사(조사 7)의 숨은 가정과 실패 양식에 대한 처분: 보안 갈래 예외 · 지운 것 기록 (@S8)
- floor:open_questions — closed — S19 「이대로 넘긴다」 — 열린 채 설계로 넘길 목록 확인 (@S19)
- derived:internal_research — closed — 내부(레포) 조사 축; S6 · S11 — 레포 주장(RC2 · RC17 · RC20 과 스위트 관찰)을 보이고 받은 처분 (@S11)
- derived:suite_time — closed — 시간이 어디서 드는지는 테스트 수 줄이기와 다른 축이다; S3 · S11 (@S11)
- derived:deletion_criteria — closed — 무엇을 지키는지 대는 근거와 테스트 사이의 의존 — 지우는 기준과 순서; S6 · S8 · S9 · S12 · S15 · S16 (@S15)
- derived:standing_rules — closed — 상시 규칙 셋과의 결합; S13 (@S13)
- derived:test_inflow — closed — 새 테스트가 생기는 길 — 계획 틀은 레포 밖 skill 이 정한다; S4 · S7 (@S4)
- derived:roadmap_collision — closed — 진행 중 에픽이 이 일이 고칠 파일을 쥐고 있다 — 시점과 순서; S21 · S22 · S23 (@S21) (재개방 1회 — 「시간 쪽은 진행 중 에픽과 덜 겹친다」는 바탕이 바뀌었다(조사 11))
- derived:prose_interface — closed — 모델이 읽는 글의 공개 인터페이스 — 글자 단언을 대신할 확인; S5 · S10 (@S10)

## 2. Budget

- 질문 라운드: 13 · agent dispatch: 24 · coverage-mapper 1 · codex 실호출: 4 (성공 0)
- 조사 호출 11/60 (장치별: 커버리지 1 · 맹점 1 · 반론 1 · 레포 조사 6 · 만든 조사 2 · 본체 직접 5)
- 포화 판정 1: 아직 — 빈 곳 6개
- 포화 판정 2: 아직 — 빈 곳 7개
- 포화 판정 2: 사용자 판단 포화(@S24) — 반복 빈 곳

## 3. Steelman 원문

#### ST1 — 「애매하면 지운다 — 대지 못하는 테스트는 지우고 재발을 받아들인다」 방향

**dispatch 입력** — goal: S1(framing 라운드 2 의 답 「스위트가 짧게 돈다, 글자만 바꾸면 안 깨진다, 테스트가 크게 준다, 쓰는 절차가 가볍다」) · 전제: P1 지금 테스트 방식은 너무 길다(S1) · P2 문제 넷이 모두 이 레포의 문제다(S1) · P3 있는 테스트도 정리한다(S1) · P4 통째로 없애는 갈래는 없다(S1) · P5 애매하면 지운다(S1) · P6 대지 못하는 테스트가 막던 실수는 다시 나와도 받아들일 만하다(S1) · P7 테스트를 지우고 줄이면 스위트가 크게 짧게 돈다(orchestrator 도출) · P8 테스트가 무엇을 지키는지는 그 테스트를 보고 댈 수 있다(orchestrator 도출) · 제약: S1 원문 전량 · trigger: 기존 사용자 제약과의 충돌 — 상시 규칙 셋이 반대쪽을 향한다

> ```yaml
> case_for_alternative:
>   statement: "지우기보다 바꾸기를 먼저 하고, 지울지는 교차 참조까지 보고 가른다 — 글자에 묶인 테스트는 구조·동작 확인으로 바꾼다. 지울지 판정할 때는 테스트 본문만이 아니라 `# guards:` 선언, 다른 락 머리말이 맡긴 일(위임), 헌장 인용, AC 번호를 함께 본다. 시간 줄이기는 삭제와 따로 잡는다."
>   strongest: "goal 넷 가운데 「글자만 바꾸면 안 깨진다」는 지우지 않고 바꿔도 이룬다. 맷 포콕 tdd skill 은 구현에 묶인 테스트를 문제로 짚지만 지우라는 말은 없다. 「스위트가 짧게 돈다」는 지운 개수와 잘 이어지지 않는다. 지켜본 구간에서 시간의 절반은 30초 넘는 다섯 파일이 썼고, 2초 이하 28개는 합쳐 6%였다. 머지 전 대조는 스위트를 두 번 돌고, qg 테스트 하나는 스위트 안에서 qg 테스트를 또 돈다. 그래서 애매한 작은 락을 많이 지워도 시간은 거의 줄지 않고, 막던 실수만 다시 열린다. 이 레포에는 다른 락이 이빨을 맡긴 락(test_copy_of_contract.sh)과 헌장이 이름으로 부르는 테스트가 있다. 테스트 하나만 읽고 「지키는 것이 없다」고 보고 지우면 다른 락이 조용히 공허해진다(SWE at Google 12장이 말하는 「눈에 잘 안 띄는 구멍」)."
> case_for_current:
>   strongest: "「테스트가 크게 준다」를 404 파일 · 약 11만 7천 줄 규모에서 이루는 수단은 삭제와 통합뿐이다. 파일마다 구조 확인으로 바꾸는 일은 그 자체가 무거운 절차라 「쓰는 절차가 가볍다」와 부딪친다. 애매함을 판정 절차로 줄이자는 안도 404개를 하나씩 심리하는 비용을 다시 부른다. SWE at Google 12장은 원인을 알 수 없는 테스트가 「존재한 내내 가치가 0이었을 수 있다」고 쓴다. Google 연속 테스트 연구는 「테스트 대부분은 한 번도 실패하지 않는다」고 보고한다. Arko 는 변경에 대한 확신을 깎는 테스트(한 줄 변경에 150개 수정)는 지우라고 한다. 축소가 결함 검출을 얼마나 잃는지는 연구마다 갈린다(Rothermel 대 Wong). 그러니 「다시 나와도 받아들인다」(P6)는 근거 없는 도박이 아니라 비용을 알고 고른 거래다. 「애매하면 남긴다」는 지금의 117k 줄을 낳은 기본값이고, 사용자는 라운드 4 에서 그 길을 닫았다."
> premise_refutation:
>   hits: [P7, P8]
>   why: "P7 「테스트를 지우고 줄이면 스위트가 크게 짧게 돈다」: RC1(merge_check.py compare_command 는 base 와 merged 에서 test_command 를 한 번씩, 모두 두 번 돈다)과 RC2(test_codex_backward_compat.sh 206행 `for t in \"$PLUGIN_ROOT\"/tests/test_*.sh ...` 는 스위트 안에서 qg 테스트를 다시 돈다)가 있다. 인터뷰가 지켜본 구간에서는 30초 넘는 다섯 개가 시간의 절반, 2초 이하 28개가 6%였다(전체 측정은 아니다). 그래서 시간은 테스트 개수가 아니라 느린 몇 개와 반복 실행 구조에 있다. 지우는 대상이 그 느린 몇 개가 아니면 「크게 준다」가 「크게 짧아진다」로 이어지지 않는다. Google 연구(research.google … taming-google-scale-continuous-testing)도 테스트 부담을 고른 테스트만 돌려 줄이는 문제로 다룬다. P8 「테스트가 무엇을 지키는지는 그 테스트를 보고 댈 수 있다 — 대지 못하면 지킬 것이 없는 것이다」: RC3 이 걸린다. shared/tests/test_no_new_duplication.sh 머리말 21–23행 「실제 동일성은 test_copy_of_contract.sh 의 GREEN 에 기댄다 — 즉 이 락의 이빨은 그 락이 살아 있을 때만 유효하다」. test_copy_of_contract.sh 가 맡은 일의 일부는 그 파일이 아니라 다른 파일에 적혀 있으니 「그 테스트를 보고 댄다」가 성립하지 않는다. SWE at Google 12장(abseil.io … ch12.html)도 원인이 분명하지 않은 테스트를 지우면 「눈에 잘 안 띄는 구멍」이 생길 수 있다고 쓴다. 대지 못하는 것과 지키는 것이 없는 것은 같은 사실이 아니다."
> premise_list_challenge: "빠진 전제가 넷이다. (1) 애매함을 누가, 무엇을 입력으로 판정하는지(OQ10) — 판정자가 테스트 파일 하나만 읽으면 P8 의 오류 때문에 애매한 몫이 부풀고, 「애매하면 지운다」가 실제보다 넓게 걸린다. (2) 보안 장치 확인 갈래(P4 가 남긴다고 한 것)에도 이 기준이 그대로 걸리는지 — CLAUDE.md 는 kill switch · persona · Law 2 `tools:` 락을 약하게 하는 변경을 보안 리뷰 대상으로 둔다. 그 갈래의 애매한 락을 지우는 것은 보안 컨트롤을 약하게 하는 일이다. 사용자는 라운드 4 에서 예외 없이 「애매하면 지운다」를 골랐으므로 이 갈래에도 같은지 따로 확인이 필요하다. (3) 지우는 단위가 파일 하나가 아니다 — 위임 락(RC3)과 헌장 인용 락(RC4) 때문에 하나를 지우면 다른 락이 공허해지거나 RED 가 된다(OQ12). (4) P2 의 넷 가운데 「한꺼번에 먼저 쓰기」와 「기대값을 같은 식으로」는 새로 쓰는 규칙의 문제다(OQ6). 있는 테스트를 지운다고 고쳐지지 않는다. P1 의 「쓰고 지키는 절차」도 같다. 「애매하면 남긴다」는 라운드 4 에서 닫혔으므로 대안으로 내지 않았다. 위 대안도 기울기 방향은 그대로 두고, 애매함을 판정하는 입력만 바꾼다."
> recommendation: refined
> refined_takes: "있는 테스트를 지우고 합치는 데까지 간다. 지울지 남길지 애매하면 지운다(라운드 4 의 기울기 유지). 무엇을 지키는지 대지 못한 테스트를 지운 뒤 그 실수가 다시 나오는 것을 받아들인다(P6). 글자에 묶인 테스트를 줄이는 방향도 그대로다."
> refined_drops: "P8 의 「그 테스트를 보고 댄다 — 못 대면 지킬 것이 없다」를 버리고, 판정 입력에 교차 참조(`# guards:` 선언 · 다른 락 머리말의 위임 · 헌장 인용 · AC 번호)를 넣는다. 그것까지 본 뒤에도 대지 못하면 지운다. 지우는 단위는 위임과 인용으로 묶인 묶음이다. P7 의 인과도 버린다. 「짧게 돈다」는 삭제 개수로 재지 않고, 느린 소수 · 머지 전 이중 실행 · 중첩 재실행을 대상으로 따로 잡는다(OQ5 에서 정함)."
> evidence:
>   - url: "https://abseil.io/resources/swe-book/html/ch12.html"
>     supports: both
>     claim: "원인이 분명하지 않은 테스트는 고칠 방법을 몰라 결국 지워지고, 지우면 커버리지에 「눈에 잘 안 띄는 구멍」이 생길 수 있다(원안 반대). 같은 절은 그런 테스트가 「존재한 내내 가치가 0이었을 수 있다」고 쓰고, 깨지기 쉬운 테스트의 유지 비용이 팀 시간을 점점 더 먹는다고 쓴다(원안 지지). 이 책은 깨지기 쉬운 테스트를 지우라고 하지 않고 고치라고 한다."
>     touches: [P6, P8]
>     decides: [OQ10]
>   - url: "https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/tdd/SKILL.md"
>     supports: both
>     claim: "맷 포콕 tdd skill 은 구현에 묶인 테스트(동작은 그대로인데 리팩터에 깨진다), 같은 식으로 만든 기대값, 한꺼번에 먼저 쓰기를 문제로 이름 붙인다. 기대값은 독립된 출처에서 와야 한다고 쓴다. 테스트를 지우는 것이나 테스트 개수에 대한 말은 없다 — 고치는 방향을 말할 뿐 지우기와 바꾸기 중 어느 쪽인지는 정하지 않는다."
>     touches: [P2]
>     decides: [OQ3, OQ6]
>   - url: "https://research.google/pubs/taming-google-scale-continuous-testing/"
>     supports: both
>     claim: "Google 연속 테스트에서 실패하는 테스트는 매우 적고, 실패하는 것은 대상 코드에 「더 가까운」 테스트다. 목표를 「품질을 해치지 않고 테스트 부담을 다스리는 것」으로 둔다 — 대부분 실패하지 않는다는 사실(원안 지지)과, 시간을 지워서가 아니라 고른 테스트만 돌려 줄인다는 방향(P7 반대)을 함께 준다."
>     touches: [P7]
>     decides: [OQ5]
>   - url: "https://bibtex.github.io/ICSM-1998-RothermelHOH.html"
>     supports: alternative
>     claim: "Rothermel · Harrold · Ostrin · Hong(ICSM 1998)은 테스트 스위트를 최소화하면 결함 검출 능력이 크게 떨어질 수 있다고 보고했다. Wong 등은 크게 떨어지지 않는다고 보고해 연구가 갈린다. 이 페이지는 서지만 확인해 준다. 결과 요지는 뒤 연구의 인용으로 본 2차 확인이다(source_kind: secondary, certainty: uncertain, checked_at: 2026-11-20). 「다시 나와도 받아들인다」(P6)는 사용자의 가치 판단이라 이 근거로 반증되지 않는다. 다만 잃는 크기가 작다고 미리 말할 수는 없다."
>     touches: [P6]
>     decides: [OQ10]
>   - url: "https://andre.arko.net/2025/06/30/you-should-delete-tests/"
>     supports: current
>     claim: "테스트는 변경에 대한 확신을 높이려고 있다. 확신을 깎는 테스트(한 줄 변경에 150개 수정, flaky, 거짓 green)는 지운다. 같은 글은 「커밋에는 빠른 테스트, 머지에는 긴 테스트」라는 층을 권한다 — 시간은 층을 나눠 잡는다."
>     touches: [P5]
>     decides: [OQ3, OQ5]
> repo_claims:
>   - id: RC1
>     path: "plugins/spec-distill/scripts/merge_check.py"
>     anchor: "def compare_command(cmd: str, pattern, base: Path, merged: Path, work: Path, sources=None) -> dict:"
>     line: 206
>     claim: "머지 전 대조는 같은 test_command 를 base 사본(212행)과 merged 사본(213행)에서 한 번씩 돌린다 — 전체 스위트가 두 번 돈다. 시간 비용의 한 축이 테스트 개수가 아니라 실행 구조에 있다."
>     touches: [P7]
>     decides: [OQ5]
>   - id: RC2
>     path: "plugins/quality-gates/tests/test_codex_backward_compat.sh"
>     anchor: "for t in \"$PLUGIN_ROOT\"/tests/test_*.sh \"$PLUGIN_ROOT\"/tests/test_*.py; do"
>     line: 206
>     claim: "스위트 안의 테스트 하나가 quality-gates 테스트 전체(제외 목록 6개 빼고)를 다시 돌린다 — 중첩 재실행이다. 이 파일 하나를 바꾸면 테스트 개수와 상관없이 시간이 준다."
>     touches: [P7]
>     decides: [OQ5, OQ12]
>   - id: RC3
>     path: "shared/tests/test_no_new_duplication.sh"
>     anchor: "실제 동일성은 test_copy_of_contract.sh 의 GREEN 에 기댄다 — 즉 이 락의 이빨은 그 락이 살아 있을 때만 유효하다."
>     line: 21
>     claim: "test_copy_of_contract.sh 가 지키는 것의 일부(중복 유입 락의 이빨)는 그 파일이 아니라 다른 락의 머리말에 적혀 있다. 그 파일만 보고 판정하면 지키는 것을 덜 대게 되고, 지우면 test_no_new_duplication.sh 가 RED 없이 공허해진다."
>     touches: [P8]
>     decides: [OQ10, OQ12]
>   - id: RC4
>     path: "shared/tests/test_charter_citations.sh"
>     anchor: "헌장(CLAUDE.md + docs/philosophy/*.md)이 이름으로 박는 것은 실재해야 한다."
>     line: 5
>     claim: "헌장이 이름으로 부르는 테스트(보기: 철학 문서의 `shared/tests/test_cost_disclosure.sh`)를 지우면 이 락이 RED 가 된다. 그 테스트를 지우려면 헌장 문장도 같이 고쳐야 하니, 지우는 단위가 파일 하나가 아니다."
>     touches: []
>     decides: [OQ12]
>   - id: RC5
>     path: "CLAUDE.md"
>     anchor: "test-suite 편집과 같은 신중함으로 persona 편집을 treat."
>     claim: "레포 헌장은 테스트 편집을 persona 편집(보안 리뷰 대상)과 같은 신중함의 기준으로 둔다. 철학 문서 59행도 「persona 파일을 약화 … 하는 PR은 test-suite 편집과 같은 scrutiny의 보안-민감 변경이다」라고 쓴다. 「애매하면 지운다」와 바로 부딪치는 상시 규칙이고, 고치려면 헌장 편집이 따라야 한다."
>     touches: []
>     decides: [OQ6]
>   - id: RC6
>     path: "docs/plugin-authoring.md"
>     anchor: "락을 쓰거나 고치면 변이(삭제 · 추가 · 반전 · 형태 바꾸기)로 RED 를 보이고, 양성 대조로 계측기가 살아 있음을 확인한다. 부재 락에는 양성 짝을 둔다."
>     line: 56
>     claim: "락을 쓰거나 고칠 때마다 변이 네 축과 양성 대조를 요구한다 — 「쓰는 절차가 가볍다」와 부딪치는 상시 규칙이다. 지우기만 해서는 이 절차가 가벼워지지 않는다."
>     touches: []
>     decides: [OQ6]
> ```
>
> 정리하면, 고친 안(refined)을 추천합니다. 지우기 쪽으로 기우는 방향 자체는 그대로 둡니다. 다만 근거가 두 전제에 걸립니다. P7: 시간은 테스트 개수가 아니라 느린 몇 개와 두 번 · 겹쳐 도는 실행 구조에 있습니다. P8: 어떤 테스트가 맡은 일이 다른 락의 머리말에 적혀 있는 경우가 있습니다. 「애매하면 남긴다」는 라운드 4 에서 닫혀서 대안으로 내지 않았습니다. 사용자에게 따로 확인할 것이 하나 있습니다. 보안 장치 확인 갈래에도 「애매하면 지운다」를 그대로 쓸지입니다.
>
> 못 한 것과 확실도:
> - Rothermel 쪽 결과 요지는 2차 확인입니다. 원 논문 본문과 Shi 등 · MSR25 PDF 는 읽어 내지 못했습니다.
> - 맷 포콕 skill 은 GitHub raw 본문을 직접 읽었습니다.
> - 시간 분포(다섯 개가 절반)는 인터뷰가 10분 구간만 본 값입니다. 다시 재지 않았습니다.
>
> Sources:
> - [Software Engineering at Google 12장](https://abseil.io/resources/swe-book/html/ch12.html)
> - [mattpocock/skills tdd SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/tdd/SKILL.md)
> - [skills.sh mirror](https://www.skills.sh/mattpocock/skills/tdd)
> - [Taming Google-Scale Continuous Testing](https://research.google/pubs/taming-google-scale-continuous-testing/)
> - [Rothermel et al. ICSM 1998 서지](https://bibtex.github.io/ICSM-1998-RothermelHOH.html)
> - [Arko, You should delete tests](https://andre.arko.net/2025/06/30/you-should-delete-tests/)
>
> 읽은 레포 파일(모두 절대경로):
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/test-method-rework/plugins/spec-distill/scripts/merge_check.py
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/test-method-rework/plugins/quality-gates/tests/test_codex_backward_compat.sh
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/test-method-rework/shared/tests/test_no_new_duplication.sh
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/test-method-rework/shared/tests/test_charter_citations.sh
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/test-method-rework/docs/plugin-authoring.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/test-method-rework/docs/philosophy/devbrew-harness-philosophy.md

**게이트-전 확인** — repo_claims: plugins/spec-distill/scripts/merge_check.py#compare_command 확인(RC2) · plugins/quality-gates/tests/test_codex_backward_compat.sh#Running existing qg test suite 확인(RC17) · shared/tests/test_no_new_duplication.sh#실제 동일성은 확인(RC20) · shared/tests/test_charter_citations.sh#이름으로 박는 것 확인(RC22) · CLAUDE.md#test-suite 편집과 같은 신중함 확인(RC12) · docs/plugin-authoring.md#락을 쓰거나 고치면 변이 확인(RC10) · 부착 주장: evidence 1(SWE at Google 12장) → P6 · P8 확인 · evidence 2(포콕 tdd skill) → P2 확인 · evidence 3(Taming Google-Scale Continuous Testing) → P7 확인 · evidence 4(Rothermel 외 1998) → P6 출처 확인 못 함(M 에 세지 않음) · evidence 5(Arko) → P5 확인 · 재검토 자격: 열림 2건(P7 · P8)

**사용자 선택** — 보완 (S6)

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-11-20) — web: enabled

## 5. 프로세스 로그

- round 1: (a · b) — 조사 다섯과 스위트 관찰을 보이고 기준 범위 · 먼저 풀 것 · 계획 방식 · 대신 지킬 후보를 물음
- round 2: (b) — steelman ST1 게이트: 「애매하면 지운다」 방향 판정
- round 3: (b) — 기준 범위 답의 되묻기: 이 레포에 안 맞는 항목의 처리
- round 4: (a · b) — 스위트 한 바퀴 관찰 · 맹점 조사 · 바깥 근거의 처분: 보안 갈래 · 지운 것의 흔적 · 글자 확인의 뜻 · 시간 줄이기
- round 5: (b) — 글자 확인 기준의 되묻기: 실제 테스트 넷으로 경계 확인
- round 6: (b) — 상시 규칙 · 진행 중 에픽과의 순서 · 승인 단위 · 이력 주석
- round 7: (b) — 숫자 목표 · 네 갈래 밖 테스트 · 설계로 넘길 목록 확인
- round 8: (a · b) — 포화 판정 1 의 빈 곳 조사 뒤 정정 둘: 후보 목록 · 느린 테스트 시점 · 두 바퀴 구조 · 기준 알리기
- round 9: (b) — 포화 판정 2 의 반복 빈 곳: 조사를 닫음
- round 10: (b) — 분해 판단과 분해안 승인(에픽 넷)
- 절차 편차: 포화 판정자에게 조사 원문을 프롬프트에 싣지 않고 원문만 뽑은 사본 파일의 경로로 넘겼다(10만 자를 넘는다 — 사용자에게 그 자리에서 알림)
- round 11: (b) — 정리 문서 리뷰 1라운드의 결정 다섯(목표 · 하지 않을 것 · 두 바퀴와 범위 · 규칙 문서 겹침 · 셋의 내용)
- 절차 편차: 리뷰 1라운드의 마무리를 한 번 다시 했다 — 저자의 추출 스크립트가 재비판 판정 대신 agent 정의의 예시 블록을 엔진에 넘겨 집계가 틀렸고, 사용자가 「같은 원문으로 다시」를 골라 엔진 기록을 비우고 같은 탐지 원문과 실제 재비판 판정으로 다시 마무리했다. codex 는 두 번 시도해 두 번 다 사용 한도에 걸렸다
- round 12: (b) — 정리 문서 리뷰 2라운드의 결정 하나(규칙 문서 에픽의 순서를 로드맵에 싣기)와 고친 분해안 승인(확인 블록 E0 를 더해 블록 다섯)
- 절차 편차: 상태 파일의 조사 14 원문 끝에 닫는 코드 펜스 한 줄을 더했다 — 원문이 연 펜스를 닫지 않아 로드맵 생성기가 상태 파일의 생성 기록 절을 읽지 못했다(다시 생성이 「만들지 않은 파일」로 거부됨). 원문의 다른 글자는 그대로다
- round 13: (b) — 정리 문서 리뷰 3라운드의 결정 하나(규칙 문서를 예약한 일 넷 가운데 진행 중인 둘만 기다린다)와 추가 라운드를 열지 않는다는 선택
- 추천을 그대로 받은 답이 이어졌다 — 되묻기는 기준 범위(R3)와 글자 확인 기준(R5) 둘에만 했고 나머지는 답 그대로 기록했다(R5 · R7 의 «지금 이해»에 밝힘)
- 확인 RC1 — 확인 — tools/suite/run-all.sh#`while IFS= read -r f; do` — 파일을 하나씩 차례로 돌리고 고르는 인자가 없다
- 확인 RC2 — 확인 — plugins/spec-distill/scripts/merge_check.py#compare_command — 212–213행에서 기준 사본과 합친 사본에 각각 한 번씩 돌린다
- 확인 RC3 — 확인 — .devbrew.md#test_command — `bash tools/suite/run-all.sh` 이고 로드맵 둘의 머리에도 같은 줄이 있다
- 확인 RC4 — 확인 — plugins/spec-distill/scripts/suite_lock.py#LOCK_NAME — 잠금은 폴더 하나이고 못 잡으면 rc 75 다(머리 주석 · 상수)
- 확인 RC5 — 확인 — shared/test-selection/compute-test-scope-candidates.sh#`# guards:` — 선언을 읽는 것은 이 스크립트이고 run-all.sh · compare_command 는 읽지 않는다. 선언이 있는 테스트 파일은 115개다(본체가 머리 30줄로 셈)
- 확인 RC6 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「전체 스위트 한 번이 75분쯤 걸리고 잠금 하나로 한 번에 하나만 돈다」 — 948–950행에 그대로 있다
- 확인 RC7 — 확인 — docs/superpowers/plans/2026-11-14-r1-plan2-team-file-read.md#「전체 스위트는 과제 구현자가 돌리지 않는다」 — 30행에 「한 번에 35–75분」 과 함께 있다
- 확인 RC8 — 확인 — docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/measurements.md#「한 번에 약 19분씩 넷」 — M10 에 있다. 손 헬퍼와 run-all 을 섞은 넷이라 지금과 같은 잣대인지는 모른다
- 확인 RC9 — 확인 — docs/git-workflow/pr-process.md#「quality-gates (설치 시)」 — 차등 테스트는 사용자가 직접 돌릴 때만 돌고 레포에 .github 폴더가 없다
- 확인 RC10 — 확인 — docs/plugin-authoring.md#「락을 쓰거나 고치면 변이(삭제 · 추가 · 반전 · 형태 바꾸기)로 RED 를 보이고」 — 56행. 같은 목록 57 · 58행에 guards 찾기 · 실행 비트가 있다
- 확인 RC11 — 확인 — CLAUDE.md#「락을 고쳐 남긴다」 — 28행 Law 3 과 97행 「락 · 스크립트 · skill 이면 그것을 고치고」
- 확인 RC12 — 확인 — CLAUDE.md#「test-suite 편집과 같은 신중함으로 persona 편집을 treat」 — 78행
- 확인 RC13 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#「단계를 빼거나 다시 쓰지 말고 끝까지 돈다」 — 59행. 61행은 계획 검토 질문을 사람에게 돌려보내게 한다
- 확인 RC14 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#「계획이 쓴 테스트 코드도 묻게 한다」 — 74행. 73행은 과제 경계마다 바꾼 파일을 읽는 락까지 돌리게 한다
- 확인 RC15 — 확인 — docs/superpowers/plans/2026-11-19-conductor-walk-gates-plan1.md#「Step 1: 실패하는 테스트를 쓴다」 — Task 2 의 453–615행이 테스트 코드이고 620행의 구현은 한 줄이다. 계획 전체에 `def test_` 59개 · 2,027줄
- 확인 RC16 — 확인 — docs/superpowers/plans/2026-11-18-official-switches-state-plan1.md#「Step 5: 변이」 — 과제마다 변이 걸음이 따로 있고(269 · 320 · 424 · 551 · 593 · 633행) 11-19 계획은 Global Constraints 한 줄(50행)로만 둔다 — 계획마다 꼴이 다르다
- 확인 RC17 — 확인 — plugins/quality-gates/tests/test_codex_backward_compat.sh#「Running existing qg test suite...」 — 201–214행이 그 플러그인의 test_*.sh · test_*.py 를 제외 목록 밖 전부 다시 돌린다
- 확인 RC18 — 확인 — plugins/quality-gates/tests/test_review_diff.sh#git init — git 저장소를 만드는 테스트 파일은 정규식에 따라 71–86개다(본체 셈 86)
- 확인 RC19 — 확인 — docs/superpowers/plans/2026-10-08-qg-v10-c1-cleanup.md#「시간에 기대는 테스트는 부하에서 흔들린다」 — 2859행에 두 테스트의 이름과 함께 있다
- 확인 RC20 — 확인 — shared/tests/test_no_new_duplication.sh#「실제 동일성은 test_copy_of_contract.sh 의 GREEN 에 기댄다」 — 21–22행
- 확인 RC21 — 확인 — plugins/quality-gates/tests/test_agent_tools_lock_mutation.sh#「이빨 증명」 — 2행. 같은 꼴의 파일이 이름으로 여덟(mutation · behavior)
- 확인 RC22 — 확인 — shared/tests/test_charter_citations.sh#「이름으로 박는 것은 실재해야 한다」 — 5행. CLAUDE.md 65 · 77행, 철학 문서 64행, 작성 안내 27 · 28 · 41행이 테스트 파일을 이름으로 부른다
- 확인 RC23 — 확인 — plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh#「protocol-shape test for SKILL.md」 — 머리 주석과 agent_stub.py 의 실재까지 봤고 본문은 읽지 않았다
- 확인 RC24 — 확인 — plugins/spec-distill/tests/test_conducting_reference.sh#「정적 락이다 — 지휘 세션이 이 절차를 실제로 따르는지는 재지 못한다」 — 3행
- 확인 RC25 — 확인 — plugins/spec-distill/tests/test_end_gates.sh#「확정하고 /compact 후 지휘자로 (권장)」 — 표 한 줄을 글자 그대로 단언한다
- 확인 RC26 — 확인 — plugins/project-init/tests/test_command_contract.py#「a test cannot exercise its behaviour」 — 머리 docstring 이 문구 락의 한계와 사고를 적는다
- 확인 RC27 — 확인 — plugins/plugin-audit/tests/test_preamble_schema_parity.py#test_preamble_example_satisfies_extractor — 문서의 예시를 추출기의 FENCE_RE 로 뽑아 추출기에 먹인다
- 확인 RC28 — 확인 — plugins/spec-distill/tests/test_ledger_wiring.sh#run_open — SKILL 의 마커 사이 bash 펜스를 뽑아 `bash -c` 로 실제로 돌린다
- 확인 RC29 — 확인 — shared/tests/test_invocation_surface.sh#「합성 리포」 — 머리 주석이 검사기에 변이를 먹이는 구조를 적는다(본문은 읽지 않았다)
- 확인 RC30 — 확인 — plugins/plugin-audit/tests/test_untrusted_data_clause.py#BLANKET_RULE — 한 문장 리터럴과 그 사고 주석이 있다
- 확인 RC31 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#「### R2 — 지휘 걸음과 관문」 — 46행 경로 예약에 CLAUDE.md · 철학 문서 · roadmaps/leader/ · roadmaps/worker/ 가 있다
- 확인 RC32 — 확인 — docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/roadmap.md#「### F5 — 앞단 다시 짜기」 — 82행 경로 예약에 test_invocation_surface.sh · docs/plugin-authoring.md · 철학 문서가 있고 범위가 앞단 skill 글 줄이기다. 168 · 171행에 위험 K16 · K19
- 확인 RC33 — 확인 — plugins/spec-distill/scripts/roadmap_status.py#main — 본체가 로드맵 넷에 돌렸다: 10월 로드맵은 전부 머지 · 지휘 로드맵 R2 구현 중 · R3 구현 끝 · E1–E3 · R4 · R5 대기 · 앞단 로드맵 F5 설계 중 · F7 일부 머지 · 코드 리뷰 로드맵 R3 설계 중 · R4 대기. 스위트 시간을 맡은 에픽은 없다
- 확인 RC34 — 반증 — docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md#R9 — 규칙 · 문서 정리 — 조사 4 가 「락 · 규칙에 닿는 진행 후보」로 든 10월 로드맵 에픽들은 전부 머지됐다(RC33) — 진행 중이 아니다
- 확인 RC35 — 확인 — plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh#「대상은 열거가 아니라 **도출**한다」 — 30행. 셸 테스트의 비어 있지 않은 줄 77,732 가운데 주석 14,713(약 19% — 본체 셈)
- 확인 RC36 — 확인 — plugins/quality-gates/tests/test_security_reviewer_persona.sh#assert_line — 37–38행 「부분 문자열 락은 리터럴 뒤에 한정어를 덧붙이거나 가운데에 끼워도 GREEN 이다(최종 리뷰 M7) — 줄 전체는 그것도 잡는다」
- 확인 RC37 — 확인 — plugins/quality-gates/tests/test_agent_tools_lock_mutation.sh#「두 실제 우회를 **45/45 GREEN 인 채로** 통과시켰다(S-3)」 — 8–9행. 13행이 대상 락의 경로를 박아 둔다
- 확인 RC38 — 확인 — tools/suite/run-all.sh#「실패마다 `FAILED <파일>: <이름>` 한 줄」 — 돌린 테스트 수를 세거나 내지 않는다
- 확인 RC39 — 확인 — plugins/spec-distill/scripts/merge_check.py#`res["fixed"] = sorted(b_names - m_names)` — 223행. 기준 쪽에서 실패하던 이름이 합친 쪽에 없으면 「고쳐짐」이다. 통과하던 테스트를 지우면 어느 칸에도 나오지 않는다
- 확인 RC40 — 확인 — plugins/spec-distill/tests/test_conductor_dispatch_reference.sh#「단일 세션과 똑같이, 단계를 빼거나 다시 쓰지 말고 끝까지」 — 18행이 그 문구를 글자 그대로 단언한다
- 확인 RC41 — 확인 — plugins/quality-gates/tests/test_codex_backward_compat.sh#LEDGER — 176행 원장 파일과 217행 「등재됐는데 GREEN → stale 등재」
- 확인 RC42 — 확인 — plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh#「선언 ⊃ 실제  → 선택은 되는데 아무것도 안 본다」 — 8행
- 확인 RC43 — 미확인 — plugins/project-init/tests/test_plain_init_text.py#`assertEqual(self.block[0]` — 리터럴 하나의 실재만 확인했고 끝 문단이 약 600자라는 것은 조사 2 의 말이다
- 확인 RC44 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#경로 예약 — 일곱 블록의 예약 줄에 스위트 · 대조 · 테스트 파일 이름이 0건이고, R2 는 team_status.py · start_bundle.py · conductor_ledger.py · walk_table.py 를 예약했다
- 확인 RC45 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#「### E2 — 리더 덜기와 다시 띄우기」 — 66행 범위에 「머지 전 확인(스위트 대조 · 통합 리뷰 · PR 본문)을 담당 세션으로」, 의존 R2 · E1
- 확인 RC46 — 확인 — docs/superpowers/specs/2026-11-18-conductor-walk-gates-design.md#「판 번호만 맞춘 합치기 뒤의 스위트 재대조」 — 445 · 455행이 E2 로 미루고 318행은 스위트 잠금을 그대로 둔다
- 확인 RC47 — 확인 — docs/superpowers/plans/2026-11-20-conductor-walk-gates-plan2.md#test_team_status.sh — 이 브랜치에는 없고 worktree conductor-walk-table 의 파일을 읽었다: test_team_status.sh 11회 · test_human_gate.sh 6회 · test_roadmap_status.sh 3회 · test_human_gate_e2e.sh 2회 · merge_check.py 0회
- 확인 RC48 — 확인 — docs/superpowers/specs/2026-11-20-front-stage-restructure-design.md#「이름과 단계를 바꾸는 커밋에서 함께 고친다」 — 이 브랜치에는 없고 worktree front-stage-restructure 의 파일을 읽었다: 252행 · 517행 「순서는 동작 → 이름 → 글 → 수리」
- 확인 RC49 — 확인 — plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh#first_line — 머리 주석 「protocol-shape test」, first_line · assert_order · assert_proximity 가 23곳. 본문 전체는 조사 12 가 읽었고 본체는 머리와 수만 봤다
- 확인 RC50 — 확인 — plugins/quality-gates/tests/harness/agent_stub.py#run_agent_stub — 「returning frozen_output verbatim」
- 확인 RC51 — 확인 — plugins/quality-gates/tests/harness/run_consent_gate.sh#「Real AskUserQuestion not invoked in harness」 — 24행. plugins · shared · tools 의 코드에 `plugin eval` · `claude -p` 가 0건이고 evals 폴더가 없다
- 확인 RC52 — 확인 — plugins/quality-gates/tests/codex-blessed-red.txt#「검토를 마친 red」 — 한 줄에 파일 이름과 해시, 지금 등재 0건
- 확인 RC53 — 확인 — plugins/spec-distill/references/existing-first.NOTICE.txt#출처 — 저장소 · 파일 · 커밋 · 원문 SHA-256 · 확인한 날 · 뺀 절
- 확인 RC54 — 확인 — plugins/quality-gates/CHANGELOG.md#「`tests/test_review_floor_lock.sh`」 — 778행이 지운 테스트 · 대신 맡는 테스트 · 이유를 한 줄에 적는다
- 확인 RC55 — 확인 — shared/tests/test_charter_citations.sh#UNTRACKED_CITED — 101행이 건너뛴 수를 세고 106행의 이름 목록과 건너뛴 집합이 같아야 한다
- 확인 RC56 — 확인 — LICENSE#「Apache License」 — 레포 루트에 하나, NOTICE 파일과 플러그인별 LICENSE 는 없다
- 대체됨: seed 의 「이 일이 닿는 상시 규칙이 둘」 → 셋이다 — CLAUDE.md 78행 「test-suite 편집과 같은 신중함으로 persona 편집을 treat」 가 더 있다 (조사 1)
- 대체됨: 조사 1 의 「넘겨받은 경로에 맷 포콕 설치본이 없다」 → 그 자리에 1.3.2 가 있고 claude-plugins-official 아래 1.3.1 도 있다(둘 다 실재 — 본체가 1.3.2 의 tdd/SKILL.md 를 읽음) (조사 1)
- 대체됨: R1 의 「30초 넘는 다섯 개가 본 시간의 절반」(10분 구간) → 한 바퀴 전체로는 30초 넘는 20–21개가 68% 이고 가장 긴 것은 스위트 안에서 스위트를 다시 도는 테스트다 (조사 10)
- 대체됨: R1 의 「가짜 응답으로 돌려 보기 — 레포에 선례가 하나 있다」 → 그 하니스는 SKILL 문구의 줄 순서와 거리만 재는 정적 확인이고 아무것도 돌리지 않으며, 가짜 응답은 고정된 글을 그대로 돌려줄 뿐이다. 문구에 가장 강하게 묶인 꼴이다. 레포의 실제 선례는 「문서 안의 코드 조각을 표지로 뽑아 실제로 돌리는 테스트」(RC28)와 「문서의 예시를 그것을 읽는 코드에 먹이는 테스트」(RC27)다 (조사 12)
- 대체됨: R6 의 「시간 쪽부터 가면 규칙 문서를 쥔 에픽과 덜 겹친다」 → 규칙 문서와는 안 겹치지만, 가장 느린 열둘 가운데 넷(test_human_gate.sh · test_human_gate_e2e.sh · test_team_status.sh · test_roadmap_status.sh — 합쳐 약 458초)을 구현 중인 지휘 에픽의 둘째 계획이 고치고 있고, 머지 전 대조의 구조 변경은 대기 중인 E2 몫으로 미뤄져 있다. 나머지 여덟(합쳐 약 1,176초 — 본 시간의 39%)은 어느 에픽도 쥐고 있지 않다 (조사 11)

### brief 리뷰 (reviewing-brief — 문서 리뷰 엔진)

- 라운드: 3 · 재리뷰 카운트 2 · 추가 라운드 0 — 승인 게이트 도달 사유: 상한 · 리뷰 완료: 예
- 결정: `## 8. 리뷰 결정` 7건 · 열린 채 남은 항목 0건() — 엔진 기록에 남은 것 2건: 고치기로 했고 반영 확인을 기다리는 결정 1(abf668a4#r3.1) · 아직 안 고친 곳으로 세인 수정 1(eb353eb4#r3.1). 둘 다 문서에는 반영했고, 사용자가 추가 라운드를 열지 않아(「열지 않음 (권장)」) 엔진이 반영을 확인하지 못했다
- codex: 없음 — exit_nonzero(사용 한도, 네 번 시도) · 웹: Claude doc-critic-web · codex 켜짐
- 냉독: gap 4건 (G3 — 요약에 없는 제약 C5 · C15 · C18 · C21) — 지정 agent 대신 일반 agent(sonnet)가 읽었다
- degrade: pipeline:1라운드 마무리를 한 번 다시 했다 · readback:지정 agent 에 파일 도구가 없어 일반 agent 로 대체 · (기록 못 한 경고 1 — 1라운드 다시 마무리의 첫 기록 시도, 같은 사실)

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S2** ☑ 선택 (R1):
  > skill 본문 전체 (권장) — 「맷폭콕이 이야기한거」가 가리키는 기준의 범위
- **S3** ☑ 선택 (R1):
  > 스위트 시간 — 셋 가운데 가장 먼저 · 무겁게 풀 것
- **S4** ☑ 선택 (R1):
  > 레포 문서로 닿는 데까지만 — 「한꺼번에 먼저 쓰기」를 푸는 범위
- **S5** ☑ 선택 (R1):
  > 구조 확인으로 바꾸기, 가짜 응답으로 돌려 보기, 리뷰에 맡기기, 실제 모델로 평가 — 문구 확인을 지운 자리를 지킬 후보로 설계가 따질 것
- **S6** ☑ 선택 (R2):
  > 보완 (builder·orchestrator 추천) — 「애매하면 지운다」 방향의 판정(ST1)
- **S7** ☑ 선택 (R3):
  > 옮겨 적고 고쳐 적는다 (권장) — 그 skill 본문 가운데 이 레포에 그대로 안 맞는 항목의 처리
- **S8** ☑ 선택 (R4):
  > 보안 갈래는 예외 (권장) — 보안 장치를 지키는 글자 확인에는 「글자만 바꾸면 안 깨진다」 · 「애매하면 지운다」를 쓰지 않는다
- **S9** ☑ 선택 (R4):
  > 지운 것을 기록으로 남긴다 (권장) — 지운 테스트가 스위트와 대조에 보이지 않는 것에 대해
- **S10** ☑ 선택 (R4):
  > 행동을 정하는 문장만 지킨다 (권장) — 「글자에 묶인 테스트」 가운데 무엇을 문제로 볼지
- **S11** ☑ 선택 (R4):
  > 느린 테스트 소수 손보기 (권장), 두 번 도는 구조 고치기 (권장) — 스위트 시간을 줄일 때 손댈 것
- **S12** ☑ 선택 (R5):
  > 금지 문장 하나 (권장), 절차의 걸음 문장 (권장) — 사례 넷 가운데 글자 확인을 남길 것(질문 표의 한 줄 전체 · 보고 글의 첫 줄과 끝 문단은 고르지 않음)
- **S13** ☑ 선택 (R6):
  > 망가뜨려 보기를 가볍게 (권장) — 상시 규칙 셋 가운데 이 일이 고칠 것(교훈을 테스트로 남기는 길 · 신중함 규칙 · 규칙은 두고 테스트만은 고르지 않음)
- **S14** ☑ 선택 (R6):
  > 시간 쪽부터 따로 간다 (권장) — 진행 중인 에픽들과의 순서
- **S15** ☑ 선택 (R6):
  > 묶음 단위로 승인 (권장) — 지울 테스트를 누가 가르고 어느 단위로 승인하는지
- **S16** ☑ 선택 (R6):
  > 판정이 끝난 뒤 덜어 낸다 (권장) — 테스트 안의 이력 주석
- **S17** ☑ 선택 (R7):
  > 시간만 숫자로 (권장) — 숫자 목표
- **S18** ☑ 선택 (R7):
  > 같은 기준으로 가른다 (권장) — 네 갈래에 들지 않는 테스트(테스트를 시험하는 테스트 · 규칙 문서가 이름으로 부르는 테스트)
- **S19** ☑ 선택 (R7):
  > 이대로 넘긴다 — 열린 채 설계로 넘길 여덟의 목록
- **S20** ☑ 선택 (R8):
  > 코드 조각 실행을 더한다 (권장) — 문구 확인을 걷은 자리를 지킬 후보 목록의 정정(후보는 다섯이 된다)
- **S21** ☑ 선택 (R8):
  > 안 겹치는 여덟부터 지금 (권장) — 느린 테스트 손보기의 시작 시점
- **S22** ☑ 선택 (R8):
  > 이 일이 고치고 알린다 (권장) — 머지 전 대조가 스위트를 두 번 도는 구조를 누가 고치는지
- **S23** ☑ 선택 (R8):
  > 알린다 (권장) — 글자 확인 기준을 앞단 글을 줄이는 에픽에 알릴지
- **S24** ☑ 선택 (R9):
  > 포화로 보고 종료 (권장) — 포화 판정 2 의 반복 빈 곳에 대해
- **S25** ☑ 선택 (R10):
  > 나눈다 — 분해안 보기 (권장) — 이 일을 spec 하나로 할지 나눌지

- **S26** ☑ 선택 (R11):
  > 고친다 — 가벼워진다를 목표로 (권장) — 정리 문서 리뷰: 다섯째 목표를 「쓰고 지키는 절차가 가벼워진다 — 자리를 먼저 정해 하나씩, 레포 문서로 닿는 데까지」로 고친다
- **S27** ☑ 선택 (R11):
  > 고친다 — 다시 잰 뒤 정한다로 (권장) — 정리 문서 리뷰: 함께 돌리기 · 닿는 테스트만 돌리기를 「이번에 먼저 하지 않는다 — 다시 잰 뒤 목표에 못 미치면 다시 정한다」로 고친다
- **S28** ☑ 선택 (R11):
  > 고친다 — 예외로 적는다 (권장) — 정리 문서 리뷰: 머지 전 대조의 두 바퀴 구조 고치기를 「이 레포만」 범위의 예외로 적는다(플러그인 스크립트를 고치고 판을 올리며 새 실패와 원래 실패를 가르는 결과는 지킨다)
- **S29** ☑ 선택 (R11):
  > 고친다 — 두 에픽 뒤에 연다 — 정리 문서 리뷰: 규칙 문서를 고치는 에픽은 그 문서를 쥔 진행 중 에픽 둘이 해당 문서를 머지한 뒤에 연다
- **S30** ☑ 선택 (R11):
  > 고친다 — 두 셋을 다 밝힌다 (권장) — 정리 문서 리뷰: 「셋 가운데 스위트 시간 먼저」의 셋이 이 인터뷰가 보인 셋임과 앞 회의에서 답한 셋을 함께 적는다

- **S31** ☑ 선택 (R12):
  > 고친다 — 로드맵 E2 에 적는다 (권장) — 정리 문서 리뷰: 규칙 문서를 고치는 에픽을 두 에픽 뒤에 여는 순서를 로드맵에도 싣는다
- **S32** ☑ 선택 (R12):
  > 승인 — 확인 블록 E0 를 더한다 (권장) — 분해안 고침: 규칙 문서를 쥔 두 에픽의 머지를 확인하는 결정 블록 E0 를 더하고 E2 가 E0 에 의존한다(E1 의 범위 문구 둘과 새 번호 배정도 함께 바뀐다)

- **S33** ☑ 선택 (R13):
  > 고친다 — 앞의 둘만 기다린다 (권장) — 정리 문서 리뷰: 규칙 문서를 예약한 일 넷을 이름으로 적고, 진행 중인 둘만 기다리며 뒤의 둘에는 알리기만 한다(확인 블록이 열릴 때 다시 센다)

## 7. 확산 원자료

- «pocock-tdd» — https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/tdd/SKILL.md — tdd skill 본문(설치본 1.3.2 를 직접 읽음, 최신도 1.3.2)
- «anthropic-skill-best-practices» — https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices — 「Build evaluations first」 · 평가를 돌리는 내장 방법이 없다는 문장 · 글자 대조 언급 없음
- «cc-plugin-evals» — https://code.claude.com/docs/en/plugin-evals — `claude plugin eval` 의 요구 판 · 채점기 여섯 · 실행마다 실제 모델 호출 · 비용 상한
- «sclar-prompt-format» — https://arxiv.org/abs/2310.11324 — 초록의 「performance differences of up to 76 accuracy points」
- «swe-google-ch12» — https://abseil.io/resources/swe-book/html/ch12.html — 「the ideal test is unchanging」 · 모호한 테스트 삭제와 구멍 · 가치 0 문장
- «google-taming-ci» — https://research.google/pubs/taming-google-scale-continuous-testing/ — 초록의 「very few of our tests ever fail」 · 「controlling test workload without compromising quality」
- «arko-delete-tests» — https://andre.arko.net/2025/06/30/you-should-delete-tests/ — 「any time they decrease confidence in a change」 · 한 줄 변경에 150개 수정의 예
- «practical-mutation» — https://arxiv.org/abs/2102.11378 — 초록의 「mutating only changed code during code review」 · 줄당 · 리뷰당 수 제한
- «pitest-faq» — https://pitest.org/faq/ — 「limit analysis to the code that you are changing」 · 계산이 비싸다는 문장
- «stryker-incremental» — https://stryker-mutator.io/blog/announcing-incremental-mode/ — 「ideal for Continuous Integration」 · 「full mutation testing run now and then」
- «ms-stryker-net» — https://learn.microsoft.com/en-us/dotnet/core/testing/mutation-testing — 「Don't chase a 100% mutation score」

## 8. 리뷰 결정

- D1.1 · r1 · adopt · 6705a285#r1.1 · "고친다 — 가벼워진다를 목표로 (권장)" — 다섯째 목표가 사용자가 고른 답 둘을 싣지 않는다 — 해소의 모습으로 고른 것은 「쓰는 절차가 가볍다」 였고 범위는 「레포 문서로 닿는 데까지만」 으로 좁혔는데, 목표는 「어디를 테스트할지 먼저 정해 하나씩 쓴다」 로만 적혀 있고 붙은 근거도 그 내용을 말하지 않는다.
- D1.2 · r1 · adopt · a6484ced#r1.1 · "고친다 — 다시 잰 뒤 정한다로 (권장)" — 함께 돌리기와 닿는 테스트만 돌리기를 Non-goal 로 닫았는데, 그 판단의 전제(시간이 느린 소수와 두 바퀴 구조에서 든다)는 스위트의 일부만 겹쳐 돌 때 잰 값이고, 사용자의 답은 권한 둘을 고른 것이지 나머지를 배제한 것이 아니다.
- D1.3 · r1 · adopt · abf668a4#r1.1 · "고친다 — 예외로 적는다 (권장)" — 머지 전 대조가 스위트를 두 번 도는 구조를 이 일이 고친다는 확정은, 대상을 이 레포의 테스트로 한정하고 플러그인이 다른 레포에 시키는 방식은 고치지 않는다는 확정과 부딪친다 — 그 구조는 다른 레포에도 실리는 플러그인 스크립트 안에 있다 (C17 대 C19 · 첫 Non-goal).
- D1.4 · r1 · adopt · abf668a4#r1.2 · "고친다 — 두 에픽 뒤에 연다" — 진행 중인 에픽과는 시간 쪽부터 따로 간다고 정했는데, 규칙 문서를 고치는 에픽도 의존 없이 같은 때에 열리고 그 문서들은 진행 중인 두 에픽이 이미 쥐고 있다 — 이 겹침에 대한 결정도 대응도 없다.
- D1.5 · r1 · adopt · eb353eb4#r1.1 · "고친다 — 두 셋을 다 밝힌다 (권장)" — 「셋 가운데 스위트 시간을 먼저」 의 셋이 사용자가 답한 셋과 다르게 풀려 있다 — 사용자의 셋은 도는 시간 · 테스트 코드의 양 · 쓰고 지키는 절차인데 제약은 가운데 것을 「글자에 묶인 테스트」 로 바꿔 적었다 (C2, §0 둘째 문단도 같다).
- D2.6 · r2 · adopt · 7e0e7d70#r2.1 · "고친다 — 로드맵 E2 에 적는다 (권장)" · supersedes D1.4 — 규칙 문서를 고치는 에픽을 진행 중 에픽 둘 뒤에 연다고 정했지만, 지휘자가 읽는 로드맵 파일에는 그 에픽의 의존이 「없음」 으로 남아 있고 로드맵의 의존 칸은 같은 로드맵 안의 에픽만 가리켜, 이 순서를 지키는 자리가 정리 문서의 글뿐이다 — 순서를 로드맵 어디에 실을지 정해야 한다.
- D3.7 · r3 · adopt · abf668a4#r3.1 · "고친다 — 앞의 둘만 기다린다 (권장)" — 규칙 문서를 고치는 에픽을 「그 문서를 쥔 진행 중 에픽 둘」 뒤에 연다고 적었는데, 같은 문서를 예약한 채 끝나지 않은 일이 둘 더 있고 그 둘은 앞의 두 에픽이 머지되는 바로 그때 시작한다 — 둘만 기다릴지, 예약한 것 전부를 기다릴지 정해야 한다 (C24, 같은 말이 §0 · OQ8 · K12 · §7 에도 있다).
- docreview 계수 — spec-distill-59ec298a/2026-11-20-test-method-rework-brief-inte-d77a0fd0eb777f03 r1: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — spec-distill-59ec298a/2026-11-20-test-method-rework-brief-inte-d77a0fd0eb777f03 r2: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — spec-distill-59ec298a/2026-11-20-test-method-rework-brief-inte-d77a0fd0eb777f03 r3: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0
