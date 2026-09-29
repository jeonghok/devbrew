---
type: interview-audit
payload: 2026-09-28-audit-folder-removal-interview.md
created_at: 2026-09-28
session_id: f278073e-5f32-44d1-b2ae-7280d1420a25
source: spec-distill conducting-interview v0.57.0
---

# 감사 폴더 제거 — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — 재구성 동의(끈 끊기 + 터진 결함만), 실패 조건은 R2 되묻기로 확인 (@S2)
- floor:landscape — closed — 외부 근거 처분: dvt 부재 음성 테스트 취함 · 태그 기점 release 취함 · 잠재/활성 결함 중립 (@S4)
- floor:skepticism — closed — ST1 유지(kept), P4 서술 교정 (@S7)
- floor:blind_spot — closed — premortem 제약 수용 + memory 포인터 갱신 (@S8)
- floor:open_questions — closed — OQ8~OQ11 과 범위 밖 3건 확인 (@S9)
- derived:internal_research — closed — 내부(레포) 조사 축; coverage-mapper·prober·steelman 의 repo_claims 42건 V1 처분 (@S8)
- derived:hole_classification — closed — 열린 항목의 발동 실측 분류; 대상 실재 기준 (@S3)
- derived:reference_sweep — closed — 경로 리터럴 밖 개념 인용 10곳; 괄호만 제거 (@S7)
- derived:audit_output_lifecycle — closed — plugin-audit 산출의 수명·위치; 산출물로 규정 (@S5)
- derived:lock_net_accounting — closed — 존재 단언 제거와 락 순감; 부재 락으로 뒤집기 (@S4)
- derived:verification_baseline — closed — 깨지는 테스트 0 의 기준선; 착수 전 기준선 대비 (@S6)

## 2. Budget

- 질문 라운드: 8 · agent dispatch: 3 · coverage-mapper 1 · codex 실호출: 0 (성공 0)

## 3. Steelman 원문

#### ST1 — 지식 무이관(git 이력만) + 개념 인용 괄호 제거 방향

**dispatch 입력** — goal: S2 · 전제: P1 두 폴더는 더 이상 읽히지 않는 저장소다(S1 · S2) · P2 감사 문서의 재사용 지식과 버리는 열린 항목은 다른 곳으로 옮기지 않고 git 이력만으로 보존이 충분하다(S1) · P3 활성 참조(경로·개념 인용)는 고쳐 써서 끊을 수 있고, 끊어도 그 자리의 뜻이 유지된다(S2 · orchestrator 도출) · P4 삭제로 잃는 것은 잠재 항목과 역사 기록뿐이다(S3 · orchestrator 도출) · 제약: S1(사용자 확인 문장) · S2–S5 원문 전량 · trigger: 활성 파일 10자리가 감사 문서 절을 근거로 인용 — 「읽히지 않는 저장소」 전제와 충돌

(builder 출력의 repo_claims id RC1~RC11 은 임시값이다 — 전역 RC32~RC42 로 다시 붙였다. 순서 그대로 대응한다.)

> OQ5 권고는 **kept** 입니다. 인용 10곳을 전부 원문으로 읽었고, 인용 괄호를 지워도 10곳 모두 뜻이 유지됩니다. 대안이 옮기자는 조각(§3·§4·§5·§8)은 이미 인용하는 파일들 본문에 들어가 있습니다. 전제 반증은 한 건(P4)이지만 OQ5 방향은 바꾸지 않습니다. 사용자가 S1 에서 이미 받아들인 손실을 P4 가 과소서술하고 있다는 뜻입니다.
>
> ## 인용 10곳 자기완결성 판정
>
> | 자리 | 인용 | 판정 | 근거 (같은 파일 안) |
> |---|---|---|---|
> | `plugins/spec-distill/references/proceed-gate.md:147` | 감사문서 §3 | 자기완결 | 147-149 가 처방("코퍼스를 넓혀 도출로")과 그것이 부재 검사용이라는 점, presence 에 적용하면 GREEN 이 난다는 결과를 직접 적음 |
> | 같은 파일 :150 | 「거울 클래스」·「공유 참조 파일」 절 | 자기완결 | 128-144 에 코퍼스 경계 규칙, 구조적 가드, 넓히는 방향이 검사 종류마다 반대라는 점이 있음 |
> | `shared/tests/presence_corpus.sh:18` | 「공유 참조 파일」 절 | 자기완결 | 10-18 이 메커니즘 전체를 다시 서술 |
> | 같은 파일 :28 | 「계측기」 절 | 자기완결이며 원래 오조준 | 규칙은 26-28 에 서 있음. 인용 대상 §5 에는 "통과 시 침묵" 사례가 없음(감사문서에서 「침묵」 grep 0건). 가장 가까운 내용은 §8 「부수 확인」 |
> | `plugins/spec-distill/tests/test_proceed_gate_adopters.sh:35` | §3 | 자기완결 | 29-33 |
> | 같은 파일 :36 | §8 | 자기완결 | 같은 문장이 "존재 검사라 이빨이 0" 을 적음 |
> | 같은 파일 :187 | 「이월된 미해결 항목」 degrade 채널 항목 | 자기완결 (잠재 항목) | 발동 조건("세 번째 채택자")이 187 에 이미 있음. 대상 §7-5 는 오히려 낡음 |
> | `plugins/spec-distill/tests/test_brief_review_entry.sh:127` | 감사문서 · 정본 병기 | 자기완결 | 같은 괄호에 플러그인 안 정본 「앵커는 각 skill 에」가 같이 인용돼 있어 감사문서 쪽만 지우면 됨 |
> | `plugins/spec-distill/tests/test_conducting_interview_stage.sh:53` | 위와 같은 병기 | 자기완결 | 위와 같음 |
> | 같은 파일 :835 | 실측 메모(감사문서 `§8`) | 자기완결 | 규칙("공유 계약에서는 절을 제목으로 인용")이 836 에 있음. 사례 문구만 일반화하면 됨 |
>
> - **:187 의 낡음:** 주석은 채널을 엔진 `fin.json` 의 `advisory[]`·`blocks` 로 적고, 감사문서 §7-5(341) 는 `merge_review 플래그 + advisory:` 로 적습니다. 활성 주석이 원본보다 최신이라, 그 인용은 오히려 틀린 쪽을 가리킵니다.
> - **다시 쓸 때 주의:** 없앨 것은 인용 괄호뿐이고 둘레의 근거 문장은 남겨야 합니다. 또 proceed-gate.md 를 고칠 때 `§8`·`§9` 를 새로 들이면 안 됩니다. `test_conducting_interview_stage.sh:837` 의 스캔이 `CI_ALL` 에서 이것을 거짓 RED 로 잡습니다.
>
> ```yaml
> case_for_alternative:
>   statement: "활성 인용 10곳이 가리키는 지식 조각(docs/audits/2026-08-21-skill-split-lock-corpus-shrink.md 의 §3·§4·§5·§7-5·§8)을 그 인용을 하는 파일 곁(주석·reference)으로 최소 흡수한 뒤 두 폴더를 삭제한다."
>   strongest: "goal 은 끈을 끊고 폴더를 지우는 것이지 지식을 버리는 것이 아니다. 인용 10곳은 과거 작성자들이 '이 근거가 없으면 누군가 이 가드를 되돌린다'고 판단해 남긴 표지다. §8 은 '주석만으로는 부족하다 — 이 편집을 하는 사람은 §3 을 근거로 삼고 있다'는 실측(가드 없이 옵션 ① 정지 어휘를 통째로 지워도 두 락 GREEN)을 담고 있다. 그 실측을 곁에 두면 다음 편집자가 git log 를 뒤지지 않고도 가드를 지키는 이유를 본다. Nygard 의 말대로 결정의 동기는 가장 잃기 쉬운 정보이고, 잃으면 후임은 무작정 따르거나 무작정 바꾼다. 흡수 비용은 몇 줄뿐이다."
> case_for_current:
>   strongest: "같은 goal 기준에서 원안이 이긴다. 대안이 옮기자는 조각은 이미 옮겨져 있다. 10곳을 전부 읽으면 각 인용은 둘레 문장이 메커니즘을 다 말한 뒤 붙은 출처 괄호일 뿐이다. §8 의 처방 셋(배열 분리, 구조적 가드, 경계 근거)과 부수 확인(assert.sh 뒤에 source)은 proceed-gate.md 128-150 과 presence_corpus.sh 2-3·10-18·41-50 에 살아 있고, §3 의 vacuity 원칙은 presence_corpus.sh 41-46 이 실행 코드로 집행한다. 그러니 흡수는 중복을 새로 만든다. 게다가 인용들은 지금 이미 해롭다. 배포되는 proceed-gate.md 의 경로 없는 '감사문서'는 설치본에서 따라갈 수 없고, 모델이 읽는 산출물에 출처를 적는 것은 AP18 Self-narrating artifact 다. presence_corpus.sh:28 은 그 사례가 없는 절을 가리키고, test_proceed_gate_adopters.sh:187 이 가리키는 §7-5 는 활성 주석보다 낡았다. 그래서 괄호만 지우는 것이 뜻을 보존하면서 문면 오류까지 고치는 최소 편집이다. 비용은 몇 줄의 삭제뿐이고, 흡수가 만드는 새 중복은 스스로 드리프트할 사본이다."
> premise_refutation:
>   hits: [P4]
>   why: "P4 '삭제로 잃는 것은 잠재 항목과 역사 기록뿐이다' ← docs/audits/2026-08-21-skill-split-lock-corpus-shrink.md 머리(8-12행, '이 문서는 … 도출 방법을 물려주려는 것이다. 다음 분할에서 이 문서만 읽고 바로 착수할 수 있어야 한다')와 §2 「독자 열거 방법」(55-94행: 도달 경로 여섯 가지, .py 축, 플러그인 경계 축, 역방향 probe 명령). 이것은 잠재 항목도 역사 기록도 아닌 재사용 절차이고, 리포 어디에도 사본이 없다('역방향 probe|도달 경로는 여섯|옮긴 파일에만 있는' grep 결과가 이 파일 하나뿐). 따라서 P4 문장은 거짓이다. 다만 이 손실은 S1('감사 문서의 재사용 지식과 … git 이력을 유일한 보존처로 둔다')이 이름까지 대며 이미 수용했고, §2 는 활성 인용 10곳 어느 것도 가리키지 않는다. 그래서 이 hit 은 OQ5 방향이 아니라 P4 의 서술을 바로잡을 사유다."
> premise_list_challenge: "(1) P4 는 사용자 문장 S1 과도 어긋난다. S1 은 '재사용 지식'을 잃는 것으로 명시했는데, P4 는 잃는 것을 '잠재 항목과 역사 기록'으로 줄였다. 'git 이력으로만 남는 것: 잠재 항목, 역사 기록, 재사용 절차(예: 분할 시 락 독자 열거법)'로 고치는 것이 맞다. (2) P1 은 목표 상태를 현재 사실처럼 적었다. 오늘은 plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh:48-50 이 폴더 속 파일의 존재를 실제로 읽고, 실패 문구에 '지우는 것은 그것을 읽는 코드이지 기록이 아니다'라는 앞 사이클의 결정을 담고 있다. 그 결정을 뒤집는 동의는 S1·S4 가 이미 줬으므로 방향 문제는 아니다. 다만 P1 은 '끈을 끊은 뒤 부하를 받는 독자가 0이 된다'로 적어야 참이다. 활성 개념 인용 10곳은 부하를 받지 않는 명목상의 독자여서 P1 과 실질적으로 충돌하지 않는다. (3) 빠진 전제가 하나 있다. 'proceed-gate.md 는 배포되는, 모델이 읽는 산출물이고 그 안의 경로 없는 감사문서 인용은 설치본에서 이미 따라갈 수 없다(AP18)'. 이 사실은 인용 제거를 손실이 아니라 S2 범위의 배포 문면 교정으로 만든다. 흡수를 그 파일로 하면 반대로 AP18 을 키운다."
> recommendation: kept
> evidence:
>   - url: "https://google.github.io/eng-practices/review/reviewer/looking-for.html"
>     supports: current
>     claim: "주석은 '왜'와 결정의 이유처럼 코드가 담을 수 없는 정보를 담는다. 코드를 지우거나 폐기하는 변경이면 관련 문서도 지울지 검토한다. 활성 주석이 이미 이유를 담고 있으면 외부 문서 포인터는 필수가 아니다."
>     touches: [P3]
>     decides: [OQ5]
>   - url: "https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions"
>     supports: alternative
>     claim: "결정의 동기는 프로젝트 수명 동안 가장 추적하기 어려운 정보이고, ADR 은 리포 안에 두며 뒤집힌 결정도 superseded 로 표시해 남긴다. 동기가 사라지면 후임은 무작정 따르거나 무작정 바꾼다."
>     touches: [P2, P4]
>     decides: [OQ5]
>   - url: "https://endjin.com/blog/architecture-decision-records"
>     supports: alternative
>     claim: "결정 기록은 대상 코드와 같은 Git 리포에 두어야 기여자가 쉽게 찾고 커밋·PR 에서 참조할 수 있다."
>     touches: [P2]
>     decides: [OQ5]
>   - url: "https://cbea.ms/git-commit/"
>     supports: current
>     claim: "커밋 메시지 본문이 '왜'를 담고 잘 관리된 log 는 유지보수자의 가장 강력한 도구다. 역사적 맥락은 git 이력이 보존처가 될 수 있다."
>     touches: [P2]
>     decides: [OQ5]
>   - url: "https://dev.to/claudiocaporro/outdated-docs-are-worse-than-no-docs-79l"
>     supports: current
>     claim: "낡은 문서는 읽는 사람이 진실의 원천으로 가정하므로 없는 것보다 해롭게 오도한다. 활성 주석보다 낡은 감사문서 §7-5 를 가리키는 인용은 그 형태다."
>     touches: [P3]
>     decides: [OQ5]
> repo_claims:
>   - id: RC1
>     path: "plugins/spec-distill/references/proceed-gate.md"
>     anchor: "경고 — 여기에 부재 락의 처방을 그대로 적용하지 말 것."
>     line: 146
>     claim: "147·150 의 인용 괄호를 지워도 뜻이 유지된다. 처방의 내용, 그것이 부재 검사용이라는 점, presence 에 적용했을 때의 결과(자기 문구를 잃어도 GREEN), 막는 장치(구조적 가드)가 146-150 에 전부 있고, 코퍼스 경계 규칙과 넓히는 방향·좁히는 방향이 검사 종류마다 반대라는 점은 128-144 에 있다."
>     touches: [P3]
>     decides: [OQ5]
>   - id: RC2
>     path: "shared/tests/presence_corpus.sh"
>     anchor: "그 편집은 그럴듯하다 — 부재(absence) 락의 처방(\"코퍼스를 넓혀 도출로\")이 바로 그것이기"
>     line: 16
>     claim: ":18 인용은 자기완결적이다. 10-18 이 공유 계약 파일이 presence 코퍼스에 들어올 때의 위험과 '부재 전용 배열 쪽으로 넓혀야 한다'는 처방을 직접 적는다."
>     touches: [P3]
>     decides: [OQ5]
>   - id: RC3
>     path: "shared/tests/presence_corpus.sh"
>     anchor: "실패 분기에서만 말하는 가드는 깨져도 단언 수·출력이 그대로라"
>     line: 27
>     claim: ":28 의 규칙은 26-28 에서 자기완결적이다. 인용 대상인 감사문서 §5 「차분 실증의 계측기 위생」은 /tmp 실행과 주입 토큰 오염 두 방식만 다루고 '통과 시 침묵' 사례는 담지 않는다(감사문서에서 「침묵」 grep 0건). 원래부터 오조준된 포인터라 끊어도 잃는 것이 없다."
>     touches: [P3]
>     decides: [OQ5]
>   - id: RC4
>     path: "plugins/spec-distill/tests/test_proceed_gate_adopters.sh"
>     anchor: "정본 `plugins/spec-distill/references/proceed-gate.md` 를 코퍼스에 넣지 말 것."
>     line: 29
>     claim: ":35-36 의 §3·§8 인용은 자기완결적이다. 29-33 이 정본을 코퍼스에서 빼는 이유(앵커 리터럴을 담아 채택 skill 이 문구를 잃어도 GREEN)를 적고, 35-37 이 처방의 적용 범위와 가드를 적는다."
>     touches: [P3]
>     decides: [OQ5]
>   - id: RC5
>     path: "plugins/spec-distill/tests/test_proceed_gate_adopters.sh"
>     anchor: "(`brief_review_degradations` 원장 vs 엔진 `fin.json` 의 `advisory[]`·`blocks`)"
>     line: 186
>     claim: ":187 인용이 가리키는 감사문서 §7-5(341행)는 채널을 'merge_review 플래그 + advisory:' 로 적어, 활성 주석보다 낡았다. 발동 조건('세 번째 채택자가 나와야 형태가 생긴다')은 주석 자체에 있으므로 괄호만 지우면 된다. §7-5 는 발동 조건이 성립하지 않은 잠재 항목이라 S1 에 따라 버리는 대상이다."
>     touches: [P3]
>     decides: [OQ5]
>   - id: RC6
>     path: "plugins/spec-distill/tests/test_brief_review_entry.sh"
>     anchor: "(감사문서 「공유 참조 파일」 절 · 정본 「앵커는 각 skill 에」 절)"
>     line: 127
>     claim: "같은 괄호가 플러그인 안 정본 절(proceed-gate.md 「앵커는 각 skill 에」)을 같이 인용한다. 감사문서 쪽만 지우면 근거가 배포 단위 안의 정본으로 남는다. test_conducting_interview_stage.sh:53 도 문구가 같고 판정도 같다."
>     touches: [P3]
>     decides: [OQ5]
>   - id: RC7
>     path: "plugins/spec-distill/tests/test_conducting_interview_stage.sh"
>     anchor: "공유 계약에서는 절을 번호가 아니라 **제목**으로 인용하는 것이 회피책이다."
>     line: 836
>     claim: ":835 의 실측 메모는 사례이고 규칙은 836 에 자기완결적으로 있다. 837 의 `§[89]` 스캔이 CI_ALL(proceed-gate.md 포함)을 보므로, proceed-gate.md 를 다시 쓸 때 §8·§9 번호를 들이면 거짓 RED 가 난다. 인용을 지우는 원안은 이 위험을 줄이고, §8 을 proceed-gate.md 로 흡수하는 대안은 이 위험을 키운다."
>     touches: [P3]
>     decides: [OQ5]
>   - id: RC8
>     path: "docs/audits/2026-08-21-skill-split-lock-corpus-shrink.md"
>     anchor: "## §2 독자 열거 방법"
>     line: 55
>     claim: "머리(8-12행)가 이 문서를 '다음 분할에서 이 문서만 읽고 바로 착수'하는 절차서라고 적고, §2 는 도달 경로 여섯 가지·.py 축·플러그인 경계 축·역방향 probe 명령을 담는다. 이 절차는 리포 다른 곳에 사본이 없다. 삭제로 잃는 것에는 잠재 항목과 역사 기록 외에 재사용 절차가 있다. 활성 인용 10곳은 §2 를 가리키지 않는다."
>     touches: [P4]
>     decides: []
>   - id: RC9
>     path: "docs/audits/2026-08-21-skill-split-lock-corpus-shrink.md"
>     anchor: "## §8 공유 참조 파일 — 처방을 거꾸로 적용하지 않기"
>     line: 597
>     claim: "§8 의 처방 셋(1 배열 분리 CI_FILES/CI_ALL, 2 구조적 가드, 3 '근거는 자제가 아니라 코퍼스 경계')과 부수 확인(가드를 assert.sh source 뒤에)은 각각 proceed-gate.md 140-144 · presence_corpus.sh 31-53 · proceed-gate.md 128-133 · presence_corpus.sh 2-3 에 이미 흡수돼 있다. 대안이 옮기자는 조각의 실질은 곁에 이미 있다."
>     touches: [P2, P3]
>     decides: [OQ5]
>   - id: RC10
>     path: "plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh"
>     anchor: "감사 문서를 지웠다 — 지우는 것은 그것을 읽는 코드이지 기록이 아니다"
>     line: 50
>     claim: "오늘 이 테스트는 docs/audits/ 속 파일의 존재를 실제로 읽고(48행 test -f), 실패 문구에 '기록은 지우지 않는다'는 앞 사이클의 결정을 담는다. P1 을 현재 사실로 읽으면 틀린 문장이다. 이 결정의 반전은 S1·S4 의 동의 범위 안이다."
>     touches: [P1]
>     decides: []
>   - id: RC11
>     path: "docs/philosophy/devbrew-harness-philosophy.md"
>     anchor: "### AP18 → CLAUDE.md Forbidden Patterns"
>     line: 105
>     claim: "모델이 읽는 산출물에 출처·배경을 담는 것은 금지 패턴(Self-narrating artifact)이다. 배포되는 proceed-gate.md 의 감사문서 인용은 이 형태이고, 설치본에는 docs/audits/ 가 없어 따라갈 수도 없다. 그러니 인용 제거는 교정이고, §8 을 그 파일로 흡수하는 대안은 이 패턴을 키운다."
>     touches: []
>     decides: [OQ5]
> ```

**게이트-전 확인** — repo_claims: RC32~RC42 11건 전부 확인(§5 확인 줄) · 부착 주장: google-eng-practices → P3 확인 · nygard-adr → P2·P4 확인 · endjin-adr → P2 확인 · cbea-commit → P2 확인 · outdated-docs → P3 확인 · 재검토 자격: 열림 1건(P4 충돌 — RC39 확인)

**사용자 선택** — 유지 (S7)

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-09-28) — web: enabled
- check_verbatim_coverage.py — exit 0 (2026-09-28)

## 5. 프로세스 로그

- round 1: path d — 진짜 문제 재구성(끈 끊기 + 터진 결함만) → S2
- round 2: path b — 되묻기(실패 조건): 「검사가 비어 있음」의 발동 경계 → S3
- round 3: path b — 외부 근거 처분 + 존재 단언 락 회계 → S4
- round 4: path b — plugin-audit 리포트 수명 → S5
- round 5: path b — 검증 기준선 → S6
- round 6: steelman ST1 게이트 → S7
- round 7: path b — blind-spot premortem 처분 → S8
- round 8: path b — Open Questions 확인 → S9
- 고른 선택지의 설명 원문(사용자에게 보인 그대로 — S14 「선택지 설명까지 선택」에 따라 ☑ 항목의 근거 범위다):
  - S2: 「폴더에 매달린 활성 의존(경로·존재 단언·개념 인용 10곳·plugin-audit 산출 경로)을 끊어 두 폴더를 지운다. 그 길에 지금 터져 있는 것(배포 문면 오류·RED)만 고친다. 범위가 선명하고, «검사는 비었지만 위반 0» 부류는 다음 질문에서 따로 정한다.」
  - S3: 「검사가 못 보는 대상이 지금 리포에 실재하면 발동으로 친다. §7-4(스캔 밖 파일 2개) 는 고친다. RC10(채택자 3개) 은 채택자별 자기 락이 실제로 있는지 확인해, 없으면 고친다. Law 2 락 갭(그렇게 쓴 agent 0)은 버린다.」
  - S4: 「E1 을 취한다. (5) 를 «활성 표면(plugins/·shared/·CLAUDE.md·docs/philosophy)이 docs/audits·docs/archive/audits 를 참조하지 않는다»는 부재 락으로 바꾼다. 스캐너가 살아 있음을 보이는 양성 짝(CHANGELOG 에 경로가 남아 있음)도 붙인다. 락 순감 0 이고, 폴더가 다시 생기거나 참조가 되살아나면 RED 가 된다.」
  - S5: 「리포트·data.json·journal 은 state 가 아니라 사람이 읽는 산출물이라 자동 삭제 대상이 아니라고 README 에 한 줄로 적는다. 끝나면 경로를 사용자에게 보고한다. GC 코드를 새로 만들지 않는다. clean-tree 선결조건은 근거가 사라지므로 함께 걷는다.」
  - S6: 「착수 전에 전체 스위트(harness 포함)를 돌려 파일별 rc 와 실패 줄 수를 기록한다. 끝낼 때 새 실패가 0 이고, 이번에 고친 RED(실행비트 사슬·Bash matcher)는 GREEN 이어야 한다. harness FAIL 2 는 범위 밖 선재 RED 로 이유와 함께 기록만 한다.」
  - S7: 「원안대로 간다. 인용 괄호만 지우고 둘레의 근거 문장은 남긴다. 번호 인용(§8·§9)은 새로 들이지 않는다. P4 는 «재사용 절차(§2 독자 열거법)도 git 이력으로만 남는다»로 고쳐 기록한다.」
  - S8: 「2~5 를 설계 제약으로 받는다. 부재 락은 rc 를 구분하고 코퍼스 하한을 두며 두 패턴을 따로 건다. 폴더 존재도 잰다. 공허해지는 락은 새 경로로 다시 앵커하고, P21 스캔은 유지한다. 그리고 이 작업의 마무리에서 auto-memory 의 docs/audits 포인터 22건을 지우거나 고친다(리포 밖이라 커밋은 없다).」
  - S9: 「OQ8~11 을 brief §3 Open Questions 로 박제하고, 범위 밖 3건은 이유와 함께 기록한다. 이어서 종료 절차(brief 작성 → 구조 게이트 → 리뷰 → proceed 게이트)로 간다.」
- 실측(경로 a): `bash` 로 test_cancel_all_fence.sh 7/7 PASS · test_no_write_matcher_hooks_repo.sh rc=1(Bash matcher 1개) · test_codex_backward_compat.sh rc=1(유일 실패 = test_runner_adapters.sh 미등재) · test_runner_adapters.sh rc=1(case_qg_test_scripts_are_executable) · harness 테스트는 세션 격리 가드가 실행 거부
- 확인 RC1 — 확인 — plugins/quality-gates/tests/test_no_secret_prompts.py#_REFERENCE_DOCS — glob 이 skills/*/references 만 봄; 플러그인 레벨 references/ 2파일 스캔 밖; 같은 LEAK_PATTERN 직접 실행 hits=0
- 확인 RC2 — 확인 — plugins/project-init/commands/project-init.md#S4 (AGENTS exists, CLAUDE divergent or absent) — 164행 (i) 문구 그대로, 166행 보존 불변식과 모순
- 확인 RC3 — 확인 — plugins/project-init/templates/trunk-based/branch-strategy.md#Pattern B — checkout main → checkout -b release/v1.x
- 확인 RC4 — 확인 — plugins/quality-gates/tests/test_runner_adapters.sh#case_qg_test_scripts_are_executable — 인덱스 모드 100644 확인, 이 한 건으로 rc=1
- 확인 RC5 — 확인 — plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh#N_BASH -ge 2 — 실행 RED; 락(08-27)이 qg 훅 제거(09-04)보다 먼저
- 확인 RC6 — 확인 — plugins/quality-gates/tests/test_codex_backward_compat.sh#미등재 — 유일 실패가 test_runner_adapters.sh 전파
- 확인 RC7 — 미확인 — plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh — CHANGELOG 가 선재 FAIL 2 를 기록한 것은 확인, 현재 상태는 세션 격리 가드가 실행을 거부해 미측정
- 확인 RC8 — 확인 — plugins/quality-gates/tests/test_agent_frontmatter_keys.sh#L2 case — null·~·{ 부재, 트림 sed 에 LC_ALL 없음; 해당 철자 agent 0
- 확인 RC9 — 확인 — plugins/plugin-audit/scripts/run_audit_codex_reviewer.sh#web_search="live" — 주석이 의도와 kill switch 를 밝힘
- 확인 RC10 — 반증 — plugins/spec-distill/tests/test_proceed_gate_adopters.sh#degrade 채널 — 그 자리의 주석은 「세 번째 채택자가 나와야 형태가 생긴다」이고 실행 결과 채택자 3개; 주장은 「넷째 채택자 때 열리는 잠재」였다
- 확인 RC11 — 확인 — plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh#(5) 근거 기록 자체는 지우지 않는다 — 존재 단언 1개, spec-distill CHANGELOG 1319 결정
- 확인 RC12 — 확인 — plugins/plugin-audit/README.md#Law 3 (Every Cycle Leaves the System Smarter) — README 71 · SKILL 33·166·168·189 · render --readme required · validate 143-148
- 확인 RC13 — 확인 — plugins/quality-gates/scripts/qg-gc.py#ROOT — GC 는 네임스페이스별, plugin-audit 에는 GC·hooks 없음
- 확인 RC14 — 확인 — plugins/spec-distill/references/proceed-gate.md#감사문서 §3 — 147·150 + presence_corpus.sh 18·28 + test_proceed_gate_adopters.sh 35·36·187 + test_brief_review_entry.sh 127 + test_conducting_interview_stage.sh 53·835
- 확인 RC15 — 확인 — CLAUDE.md#Audits — 상시 문서의 두 폴더 경로 참조는 CLAUDE.md:99 한 곳
- 확인 RC16 — 확인 — docs/audits/2026-08-27-adjudication-topology-handoff.md#현재 사망 — 근거 스크립트 merge_review.py 가 plugins/*/scripts 에 없음
- 확인 RC17 — 확인 — plugins/plugin-audit/scripts/assemble-audit-data.py#write_text — mkdir 없음
- 확인 RC18 — 확인 — plugins/plugin-audit/tests/test_ac6_regression.py#BASELINE — 7행 + fixtures/ac6_build.py:16, 사용자 경로 24건
- 확인 RC19 — 확인 — plugins/spec-distill/tests/test_framing_review_contract.sh — framing-requests degrade 채널을 이름으로 재는 락 없음(reviewing-spec · reviewing-brief 는 있음)
- 확인 RC20 — 확인 — plugins/spec-distill/skills/reviewing-spec/SKILL.md#codex-gate:begin — 마커 4개 전부 SKILL.md
- 확인 RC21 — 확인 — plugins/spec-distill/README.md#AP2 (Polite stop) — 요약 4옵션이 정본과 현재 정합, 정합 검사는 부재
- 확인 RC22 — 확인 — plugins/plugin-audit/tests/test_skill_orchestration.py#_BUGGY_ARTIFACTS_DIR_FORM — 옛 경로 리터럴 고정
- 확인 RC23 — 확인 — plugins/plugin-audit/scripts/validate-audit-data.py#validate_artifacts — 조립형 경로
- 확인 RC24 — 확인 — plugins/plugin-audit/scripts/render-audit-report.py#--readme — required=True
- 확인 RC25 — 확인 — plugins/plugin-audit/skills/auditing-plugins/SKILL.md#run-own-tests.sh plugins/<target> <sid> — 출처 미규정, run-own-tests.sh:15 필수
- 확인 RC26 — 확인 — plugins/plugin-audit/skills/auditing-plugins/SKILL.md#committed dir — P21 스캔 근거가 커밋
- 확인 RC27 — 확인 — plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh#(4) 부재 — `grep -qF … && no || ok` 모양
- 확인 RC28 — 확인 — plugins/spec-distill/tests/test_review_hook_removed.py#HISTORY — 날짜 붙은 docs/audits 파일 면제
- 확인 RC29 — 확인 — plugins/spec-distill/tests/test_conducting_interview_stage.sh#retired_secs — §[89] 스캔이 CI_ALL 을 봄
- 확인 RC30 — 확인 — plugins/quality-gates/tests/test_runner_adapters.sh#case_qg_test_scripts_are_executable — 인덱스 모드 락은 qg 만; spec-distill 9 · shared 8 개 tests/*.sh 가 100644
- 확인 RC31 — 확인 — .gitignore#/.claude/* — devbrew 한정 규칙
- 확인 RC32 — 확인 — plugins/spec-distill/references/proceed-gate.md#경고 — 146-150 자기완결, 128-144 경계 규칙
- 확인 RC33 — 확인 — shared/tests/presence_corpus.sh#부재 락의 처방 — 10-18 자기완결
- 확인 RC34 — 확인 — shared/tests/presence_corpus.sh#통과 시에도 반드시 한 줄을 낸다 — 26-28 자기완결, 감사문서 「침묵」 0건
- 확인 RC35 — 확인 — plugins/spec-distill/tests/test_proceed_gate_adopters.sh#정본을 코퍼스에 넣지 말 것 — 29-37 자기완결
- 확인 RC36 — 확인 — plugins/spec-distill/tests/test_proceed_gate_adopters.sh#fin.json — 감사문서 §7-5 는 merge_review 로 적어 낡음
- 확인 RC37 — 확인 — plugins/spec-distill/tests/test_brief_review_entry.sh#정본 「앵커는 각 skill 에」 절 — 병기
- 확인 RC38 — 확인 — plugins/spec-distill/tests/test_conducting_interview_stage.sh#제목으로 인용 — 836 규칙 자기완결
- 확인 RC39 — 확인 — docs/audits/2026-08-21-skill-split-lock-corpus-shrink.md#§2 독자 열거 방법 — 고유 문구가 리포에서 이 파일 하나
- 확인 RC40 — 확인 — docs/audits/2026-08-21-skill-split-lock-corpus-shrink.md#§8 공유 참조 파일 — 처방 셋이 proceed-gate.md·presence_corpus.sh 에 흡수됨
- 확인 RC41 — 확인 — plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh#감사 문서를 지웠다 — RC11 과 같은 자리
- 확인 RC42 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#AP18 → CLAUDE.md Forbidden Patterns — 105행 헤딩 실재
- 리포 밖 확인: auto-memory 13파일 22건 · 추적되는 심볼릭 링크 21개 중 감사 폴더 대상 0 · 다른 워크트리 qg-angle-floor-pr3 에 폴더 잔존(그 브랜치는 main 에 머지됨)

### brief 리뷰 (reviewing-brief — 문서 리뷰 엔진)

- 라운드: 3 · 재리뷰 카운트 2 · 추가 라운드 0 — 승인 게이트 도달 사유: 상한 · 리뷰 완료: 예(round_reviewed true, 라운드 3)
- 결정: `## 8. 리뷰 결정` 13건 · 열린 채 남은 항목 0건 — 단 라운드 3 의 fix 4건(0138b17b · 40f9462c · b8f9a943 · f0f95e2d)과 채택 D3.13 의 편집은 추가 라운드 없이 적용돼 엔진 관측 밖(미관측), 탐지·재비판을 다시 거치지 않았다(S25)
- codex: 있음(라운드 1·2·3 실호출 3회, 전부 성공) · 웹: Claude doc-critic-web · codex 켜짐
- 냉독: gap 1건 (G6 — 「C4 의 원문」 ✎ 가 좁혀진 C4 를 가리킴) — 리뷰 뒤 한 단어로 교정, 구조 게이트 재통과
- degrade: critic:fidelity 번들 audit 파일명 잔존 ×3(라운드 1·2·3) · critic:all 번들·프로필 경로 전달 · readback 블롭 audit 파일명 잔존 · readback 첫 dispatch 실패(경로 전달, 인라인 재dispatch) · 라운드 2 자동 결정 4건을 한 질문으로 물음(규약 위반, 라운드 3 부터 분리)

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S2** ☑ 선택 (R1 — 이 작업의 진짜 문제를 어떻게 정의할까):
  > "끈 끊기 + 터진 결함만 (권장)"
- **S3** ☑ 선택 (R2 — 「검사가 비어 있음」을 어디서 잘라 터진 결함으로 칠까):
  > "대상 실재 기준 (권장)"
- **S4** ☑ 선택 (R3 — 감사 문서 존재 단언 (5) 처리 · 외부 근거 처분):
  > "부재 락으로 뒤집기 (권장)"
- **S5** ☑ 선택 (R4 — plugin-audit 리포트와 자동 삭제 규약의 공존):
  > "산출물로 규정, 삭제 안 함 (권장)"
- **S6** ☑ 선택 (R5 — 깨지는 테스트 0 의 대조 기준):
  > "착수 전 기준선 대비 (권장)"
- **S7** ☑ 선택 (R6 — ST1 판정):
  > "유지 (builder·orchestrator 추천)"
- **S8** ☑ 선택 (R7 — premortem 처분):
  > "제약 수용 + memory 갱신 (권장)"
- **S9** ☑ 선택 (R8 — Open Questions 확인):
  > "이대로 넘긴다 (권장)"
- **S10** ☑ 선택 (brief 리뷰 라운드 1 게이트 — 41df26ba#r1.1 부재 락이 goal 대비 과함):
  > "채택 — 폴더 부재 한 줄로"
- **S11** ☑ 선택 (brief 리뷰 라운드 1 게이트 — abf668a4#r1.1 plugin-audit 과 Law 3):
  > "채택 — OQ8 을 Law 3 결정으로"
- **S12** ☑ 선택 (brief 리뷰 라운드 1 게이트 — abf668a4#r1.2 기준선 대조 단위):
  > "채택 — 실패 식별자로 대조"
- **S13** ☑ 선택 (brief 리뷰 라운드 1 게이트 — e99bfa50#r1.1 확정 시점):
  > "Step B 에서 확정 (권장)"
- **S14** ☑ 선택 (brief 리뷰 라운드 1 게이트 — e99bfa50#r1.2 선택의 범위):
  > "선택지 설명까지 선택 (권장)"
- **S15** ☑ 선택 (brief 리뷰 라운드 2 게이트 — 얼림 검사 자동 결정 4건 §0·§1·§3·§5, 한 질문으로 물음):
  > "채택 — 네 편집 유지"
- **S16** ☑ 선택 (brief 리뷰 라운드 2 게이트 — abf668a4#r2.1 사용자 리포의 ignore 보장):
  > "채택 — ignore 보장을 OQ 로"
- **S17** ☑ 선택 (brief 리뷰 라운드 2 게이트 — abf668a4#r2.2 산출 경로 모양):
  > "채택 — <date>-<target> 경로로"
- **S18** ☑ 선택 (brief 리뷰 라운드 2 게이트 — f4aceed8#r2.1 인벤토리 보강):
  > "채택 — 목록 보강 + grep 1회"
- **S19** ☑ 선택 (brief 리뷰 라운드 2 게이트 — c89d8197#r2.1 §7 수정 허용):
  > "고쳐도 된다 (권장)"
- **S20** ☑ 선택 (brief 리뷰 라운드 3 승인 게이트 1단계 — 4039a5a0#r3.1 §3 자동 결정):
  > "채택 — §3 편집 유지"
- **S21** ☑ 선택 (brief 리뷰 라운드 3 승인 게이트 1단계 — 41488ee9#r3.1 §7 자동 결정):
  > "채택 — §7 편집 유지"
- **S22** ☑ 선택 (brief 리뷰 라운드 3 승인 게이트 1단계 — abf668a4#r3.1 검사기 락 순감):
  > "채택(가) — 순감 수용 명시"
- **S23** ☑ 선택 (brief 리뷰 라운드 3 승인 게이트 1단계 — 194dffbb#r3.1 sentinel 근거):
  > "S13 그대로 — Step B 에서 (권장)"
- **S24** ☑ 선택 (brief 리뷰 라운드 3 승인 게이트 1단계 — 9b7056b0#r3.1 §3 OQ8 수정 허용):
  > "§3 도 고쳐도 된다 (권장)"
- **S25** ☑ 선택 (brief 리뷰 라운드 3 승인 게이트 1단계 — 추가 라운드 1회 열기):
  > "열지 않음 (권장)"

## 7. 확산 원자료

- «dvt-archive-removal» — https://github.com/dunay2/dvt/pull/3223 — archive 제거 + 은퇴 대상 부재 음성 회귀 테스트
- «tbd-branch-for-release» — https://trunkbaseddevelopment.com/branch-for-release/ — 릴리스 태그에서 사후 브랜치
- «latent-active-defects» — https://quashbugs.com/blog/latent-vs-active-defects — 잠재/활성 결함 구분
- «nygard-adr» — https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions — 결정 동기 보존
- «google-eng-practices» — https://google.github.io/eng-practices/review/reviewer/looking-for.html — 주석이 이유를 담는다
- «outdated-docs» — https://dev.to/claudiocaporro/outdated-docs-are-worse-than-no-docs-79l — 낡은 문서의 해
- «endjin-adr» — https://endjin.com/blog/architecture-decision-records — 결정 기록을 같은 리포에
- «cbea-commit» — https://cbea.ms/git-commit/ — 커밋 메시지가 이유를 담는다
- «git-grep-worktree» — https://git-scm.com/book/en/v2/Git-Tools-Searching — git grep 은 작업 트리, 삭제는 pickaxe
- «gh-code-search» — https://docs.github.com/en/search-github/github-code-search/about-github-code-search — 기본 브랜치만 색인
- «cc-plugin-cache» — https://github.com/anthropics/claude-code/issues/28492 — 플러그인 캐시 name+version 키
- «cc-clear-session-id» — https://github.com/anthropics/claude-code/issues/70606 — /clear 가 session_id 재발급
- «git-core-filemode» — https://git-scm.com/docs/git-config/2.14.6 — core.fileMode

## 8. 리뷰 결정

- D1.1 · r1 · adopt · 41df26ba#r1.1 · "채택 — 폴더 부재 한 줄로" — shrink: D9·D13 이 짓는 부재 락은 S1 goal(두 폴더 제거 · 깨지는 것 0)에 비해 과하다. 구성은 활성 표면 전수 참조 스캔, 면제 설계(CHANGELOG · 역사 정규식 · 합성 표본 · 락 자신 · AC6 fixture — OQ11), 코퍼스 하한, 두 패턴, rc 구분, 양성 짝이다. 결국 폴더 하나를 지우려고 새 락 하나를 설계하는 셈이다.
- D1.2 · r1 · adopt · abf668a4#r1.1 · "채택 — OQ8 을 Law 3 결정으로" — C3·C4 를 따르면 이후 /plugin-audit 의 갭 목록은 git-ignored `<sid>` 디렉토리에만 남는다. 이는 CLAUDE.md Law 3(다음 세션이 실제로 찾을 파일로 capture)과 충돌하는데, OQ8 은 이것을 README 한 줄을 어떻게 고칠지의 문제로만 열어 두었다. 사용자가 고를 두 상태는 (가) plugin-audit 이 산출물로는 Law 3 을 instantiate 하지 않는다고 공시하는 것, (나) 산출물이 발견 가능한 자리로 넘어가는 단계를 두는 것이다.
- D1.3 · r1 · adopt · abf668a4#r1.2 · "채택 — 실패 식별자로 대조" — D11의 파일별 rc·실패 줄 수만으로는 기존 실패 하나가 사라지고 새 실패 하나가 생긴 경우를 구별하지 못한다. 기준선 비교에 실패 항목의 식별자도 포함할 것인가?
- D2.4 · r2 · adopt · 4039a5a0#r2.1 · "채택 — 네 편집 유지" — finding 없이 바뀜: 3. Open Questions (modified)
- D2.5 · r2 · adopt · 5443440e#r2.1 · "채택 — 네 편집 유지" — finding 없이 바뀜: 0. 한눈에 (modified)
- D2.6 · r2 · adopt · 9e5ecd9f#r2.1 · "채택 — 네 편집 유지" — finding 없이 바뀜: 1. Goal · Non-goal (modified)
- D2.7 · r2 · adopt · ad526e9e#r2.1 · "채택 — 네 편집 유지" — finding 없이 바뀜: 5. 기각 · Blind Spots (modified)
- D2.8 · r2 · adopt · abf668a4#r2.1 · "채택 — ignore 보장을 OQ 로" — C4 는 산출 위치를 「git-ignored 인 .claude/plugin-audit/<session-id>/」로 확정했다. 그러나 187행 ✎ 와 §5 RC31 은 `.claude/` 가 무시되는 것이 devbrew 의 .gitignore 에서만 참이라고 스스로 적었다. 그 위험은 OQ4 로 넘겨졌는데, OQ4 는 S5(자동 삭제 여부)로 해결됐고 ignore 보장은 다루지 않았다. 남은 OQ8~OQ10 에도 이 문제가 없어서 위험이 어디서도 닫히지 않는다. 고를 두 상태가 있다. 하나는 C4 의 「git-ignored」를 devbrew 한정 전제로 두고 사용자 리포에서는 미보장이라고 공시하는 것이다. 다른 하나는 plugin-audit 이 출력 디렉토리를 만들 때 스스로 ignore 되게 하는 것이다(디렉토리 안 `.gitignore` 에 `*`).
- D2.9 · r2 · adopt · abf668a4#r2.2 · "채택 — <date>-<target> 경로로" — C4 의 `<session-id>` 경로 세그먼트는 리포 규약상 auto-delete 되는 state 자리와 같은 모양이다. 그런데 D10 은 그 산출물을 state 가 아니라고 규정했다. /clear 가 sid 를 재발급하니 리포트를 세션을 넘어 찾기도 어렵다. 두 상태가 있다: sid 세그먼트를 유지하고 OQ9 에서 출처를 정하는 것, 아니면 SKILL 이 이미 쓰는 `<date>-<target>` 키로 `.claude/plugin-audit/<date>-<target>/` 에 두는 것.
- D2.10 · r2 · adopt · f4aceed8#r2.1 · "채택 — 목록 보강 + grep 1회" — §0 은 매달린 끈을 넷으로 셌지만 활성 테스트에는 그 넷 밖의 경로 참조가 더 있다. D16 이 참조 스캔을 없앴으므로 C6 정리가 끝났는지 재는 장치도 없다. 두 상태가 있다: 인벤토리를 브리프가 정한 대로 두는 것, 아니면 설계 검증 절차에 활성 표면 git grep 을 한 번 두는 것(영구 락은 아니다).
- D3.11 · r3 · adopt · 4039a5a0#r3.1 · "채택 — §3 편집 유지" — finding 없이 바뀜: 3. Open Questions (modified)
- D3.12 · r3 · adopt · 41488ee9#r3.1 · "채택 — §7 편집 유지" — finding 없이 바뀜: 7. Next Action (modified)
- D3.13 · r3 · adopt · abf668a4#r3.1 · "채택(가) — 순감 수용 명시" — C4 는 검사기의 README 링크·CLAUDE.md 포인터 요구를 없앤다. 그러면 그 요구를 RED 로 재는 단언 3개도 함께 사라진다. 그런데 brief 는 「락 순감 금지」를 일반형으로 읽을 때의 순감 0 을 D9 에서만 주장하고, C4 가 만드는 순감은 다루지 않는다. 두 상태 중 하나를 고른다. 하나는 이 3개의 순감을 C4 의 대가로 받아들인다고 명시하는 것이다. 다른 하나는 새 산출 경로를 재는 대체 단언을 두어 순감을 0 으로 유지하는 것이다.
