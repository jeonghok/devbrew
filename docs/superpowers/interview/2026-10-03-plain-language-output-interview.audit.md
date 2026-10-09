---
type: interview-audit
payload: 2026-10-03-plain-language-output-interview.md
created_at: 2026-10-03
session_id: cca5d8c5-e0c9-4962-9d60-335d15c66846
source: spec-distill conducting-interview v0.57.0
---

# 쉬운 말 출력 — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — S4 — 진짜 문제는 seed 그대로: devbrew 가 내놓는 글을 처음 보는 사람이 한 번에 이해하지 못하고 꼭 알 필요 없는 글까지 읽어야 한다. 층 구조·장치 과잉 진단은 문제 정의에서 빼고 제약으로만 다룬다(S3 이 재구성 초안을 seed 이탈로 기각) (@S4)
- floor:landscape — closed — S2 — 바깥 사례 넷(전·후 예시 · 쉬운 말은 화면/번호는 기록 · 간결 규칙은 사람 글에만 · 터미널은 중요한 것을 끝에)을 전부 취함 (@S2)
- floor:skepticism — closed — S7 — ST1 보완(refined): 판정·개수·공시 줄은 스크립트가 쉬운 첫 줄을 직접 내고, 리뷰 지적은 리뷰어가 처음부터 쉽게 쓰며, 모델은 미리 풀 수 없는 글에만 설명을 붙이되 통과·실패를 말하지 않는다 (@S7)
- floor:blind_spot — closed — S8 — 넘길 요구사항: 규칙 핵심은 SKILL.md 맨 앞(압축 뒤 앞 5,000토큰만 재부착) · 메모리 색인은 200줄/25KB 한도 안에서(현재 29,046바이트) · 「이상 없음」은 확인 0건일 때만, 확인 못 함·빠진 검사는 따로 한 줄. 「처음 보는 독자로 시험」은 고르지 않음 → 위험으로만 기록 (@S8)
- floor:open_questions — closed — S13 — 열린 질문 OQ10~OQ17 여덟 가지를 그대로 설계 단계로 넘기는 것을 확인 (@S13)
- derived:internal_research — closed — coverage-mapper 첫 dispatch 가 repo_claims 를 처음 산출(C43 admit); S6 — 레포 주장 RC1·RC3~RC5(설치본 경계·reference 읽기 권한·훅 분포)를 근거로 배달 범위를 고름. 22건 V1 전부 확인 (@S6)
- derived:delivery_path — closed — 규칙의 배달 경로 — CLAUDE.md 는 설치본 밖(RC1), reference 경로 Read 는 설치본에서 거부·질문(RC3·RC4), SessionStart 훅은 qg 만(RC5); S6 — 규칙은 플러그인 안에 두어 다른 레포 사용자에게도 닿게 한다; 방식(SKILL.md 본문·shared 링크·훅)은 설계 단계 (@S6)
- derived:producer_kinds — closed — 글을 만드는 쪽 — 모델 자유 글 / 스크립트 고정 문구(RC16·RC22) / subagent 출력(RC12) / 외부 스킬; S13 — 쪽별 고칠 목록(OQ11)을 열린 질문으로 설계에 넘김 (@S13)
- derived:machine_read_boundary — closed — 사람에게 보이면서 기계가 글자로 읽는 문구 — verdict 줄(RC18), 처분 라벨(RC17), 커밋 type(RC19), 소개 문구 일치(RC15); S13 — 기계가 읽는 문구의 경계(OQ12)를 열린 질문으로 설계에 넘김. 소개 문구는 S12 로 정함 (@S13)
- derived:disclosure_contract — closed — '이상 없음' 한 줄 vs 공시 규칙(RC6~RC8), 분량 상한 금지(RC9); S8 — 「이상 없음」은 확인 0건일 때만, 확인 못 함·빠진 검사는 따로 한 줄. 저자 편집 공시의 분량 상한 금지(RC9)는 사용자가 판단하는 자리라 S1 「원문 병기는 사용자가 판단해야 하는 자리에만」과 일치 → 유지 (@S8)
- derived:gloss_ownership — closed — 원문 앞 쉬운 설명을 누가 책임지나 — 판정 결정론(RC11), steelman verbatim(RC12); S7 — ST1 보완 (@S7)
- derived:scope_pr_versioning — closed — PR 나누기·버전·CHANGELOG(RC14), 문구 검사 규모(RC20); S11 — 한 브랜치에서 단계별 머지: ① 규칙·공통 → ② 플러그인별, PR 을 겹쳐 쌓지 않고 앞 PR 머지 뒤 다음 PR. 철학 문서는 충돌 조항만(S5) (@S11)
- derived:style_contagion — closed — 프롬프트 문체가 응답 문체를 끈다(E4), 금지 목록보다 예시(E5), 규칙 파일의 self-narrating 금지(RC21); S10 — 모델이 읽고 따라 하는 글(SKILL.md 본문·agent 프롬프트·메모리·CLAUDE.md)은 성능 기준: 정확한 압축 문장 유지, 출력에 옮는 습관(지어낸 말·내부 번호를 사용자 글에 쓰는 것)만 걷어냄. 쉬운 말 재작성은 사람이 읽는 글에만(S9 성능 우선) (@S10)

## 2. Budget

- 질문 라운드: 11 · agent dispatch: 3 · coverage-mapper 1 · codex 실호출: 0 (성공 0)

## 3. Steelman 원문

#### ST1 — 그대로 보여야 하는 글 앞의 쉬운 설명을 모델이 쓰는가

**dispatch 입력** — goal: S1(S4 가 「문제는 seed 그대로」로 재확인) · 전제: P1 원문은 지우지 않고 뒤에(S1) · P2 쉬운 설명은 앞에, 병기는 판단 자리에만(S1) · P3 그 설명은 모델이 쓴다(orchestrator 도출) · P4 판정은 스크립트가 정하고 오케스트레이터는 못 고친다(orchestrator 도출, 레포 규칙) · P5 검사 장치 없이 규칙으로(S1) · P6 간결 규칙은 사람 글에만(S2) · P7 진짜 문제는 seed 그대로, 장치는 제약(S4) · 제약: S1–S6 원문 전량 · trigger: 기존 레포 제약과의 충돌(qg 재서술 금지 · steelman verbatim 계약) + 알려진 anti-pattern(전달자가 판정을 누그러뜨림)

> ```yaml
> case_for_alternative:
>   statement: "판정·리뷰 결과·오류 앞에 붙는 쉬운 설명은 판정을 낸 스크립트(리뷰 결과의 자유 서술 부분은 그 글을 쓴 리뷰어)가 직접 쓰고, 모델(오케스트레이터)은 판정을 전달하는 자리에서 판정 내용을 다시 풀어 쓰지 않는다. 모델이 자유롭게 쓰는 보고 글·질문·안내는 그대로 모델이 쓴다."
>   strongest: "목표는 처음 보는 사람도 읽을 수 있을 만큼 쉬워야 한다는 것인데, 사람은 맨 앞 몇 줄만 읽고 나머지는 건너뛴다. 그래서 판정 자리에서는 앞에 오는 쉬운 설명이 사실상 판정 그 자체가 된다. AI 요약을 앞에 보여 주면 사람들이 원문을 덜 확인하고(원문 링크 클릭률 15%에서 8%로), 그럴듯한 설명은 맞든 틀리든 받아들여지는 비율을 높인다. 더구나 리뷰받는 코드를 쓴 쪽도 이 모델이라, 자기 코드에 대한 지적을 자기 말로 풀어 주는 셈이 된다. 반대로 스크립트가 한 번 써 둔 문장은 매번 똑같고 판정과 어긋나지 않는다. 레포는 이미 이 방식을 쓰고 있다(사람말을 앞에 두고 원래 낱말은 괄호에 남기는 CATEGORY_GLOSS·_CHOICE_LABEL). 연구에서도 전문가가 미리 써 둔 설명이 GPT-4가 그때그때 만든 설명보다 초보자에게 더 도움이 됐다."
> case_for_current:
>   strongest: "목표에는 «어느 자리든»이 붙어 있다. 그런데 정말 어려운 글은 스크립트가 미리 풀어 둘 수 없는 글이다. 리뷰어가 자유롭게 쓴 지적, 예상하지 못한 오류 메시지, 이번 변경에서 이 지적이 무엇을 뜻하는지 같은 것들이다. 고정된 풀이 문구는 지금도 「얼림 검사가 잡은 변경」처럼 또 하나의 전문용어가 되기 쉽다. 그 맥락을 알고 문장을 만들 수 있는 것은 모델뿐이다. 판정을 정하는 것은 여전히 스크립트이고 원문도 바로 뒤에 그대로 남으므로, 사용자는 언제든 대조할 수 있다. 판정 자리마다 스크립트를 고치는 것은 네 플러그인의 렌더 코드와 그 문구를 고정한 테스트를 전부 손대는 일이다. 사용자가 고른 「검사 장치 없이 규칙으로 지킨다」와 레포의 «모델을 믿고 하니스는 가볍게» 원칙에도 원안이 더 맞는다."
> premise_refutation:
>   hits: [P3]
>   why: "P3 (「그 쉬운 설명은 모델(오케스트레이터)이 쓴다」, seed 가 아니라 orchestrator 가 이끌어 낸 전제): (1) RC1·RC2 와 정면으로 부딪힌다. 품질 검사 스킬(quality-pipeline SKILL.md 593~595행)은 「do NOT reformat or re-summarize it yourself (Law 1 determinism — the script, not the orchestrator, owns the rendering)」로 판정 출력을 그리는 주체를 스크립트로 정해 두었다. 601행은 stdout 을 「그대로 … (요약 · 재서술 금지)」 보여 주라고 하고, 앞에 붙일 수 있는 것을 고정된 한 줄 `## qg iter N — <verdict>` 로 제한한다. 모델이 쓴 설명을 판정 앞에 두는 것은 바로 그 자리에 다시 풀어 쓴 글을 넣는 일이다. (2) RC9(철학 문서 AP3 「같은 context의 reviewer는 자신이 방금 쓴 코드를 *defend*하는 default」)에 따르면, 리뷰 대상 코드를 쓴 오케스트레이터가 그 리뷰 결과를 풀어 쓰는 구조는 P3 가 전제한 「전달하는 쪽은 중립」과 맞지 않는다. (3) https://arxiv.org/abs/2409.18661 에서는 GPT-4가 그때그때 쓴 오류 설명이 6개 과제 중 1개에서만 원래 컴파일러 메시지보다 나았고, 전문가가 미리 쓴 설명이 객관 지표와 만족도 양쪽에서 더 나았다. 이는 「모델이 써야 가장 쉽다」는 P3 의 암묵적 근거와 부딪힌다. 단, 레포 규칙은 고칠 수 있다(S2). 이 충돌이 보여 주는 것은 P3 가 아직 정해진 사실이 아니라 열린 결정(OQ5)이라는 점이지, P3 가 불가능하다는 것은 아니다."
> premise_list_challenge: "결함은 세 가지다. ① P3 는 seed 가 말하지 않은 것을 orchestrator 가 채운 것인데 전제 목록에 들어가 있다. 지금 열린 결정 OQ5(누가 쓰는가)와 같은 질문이라, P3 를 전제로 두면 OQ5 의 답이 미리 정해져 버린다. P3 는 전제에서 빼고 OQ5 로만 두는 것이 맞다. ② P3 와 P4 가 부딪히는데 목록이 그 관계를 말하지 않는다. P4 는 오케스트레이터가 판정을 고르거나 고치지 못한다고 하는데, 판정을 말로 다시 풀어 쓰면 단어 하나 차이로 판정을 고치는 것이 된다. 레포 스스로 그 위험을 기록해 두었다: 고정 라벨을 사람말로 바꾸기만 해도 «동작을 반대로 설명»할 수 있어 라벨을 상태에서 계산하게 했다(RC4). 빠진 전제는 「쉬운 설명과 원문이 어긋나면 원문이 이긴다」이고, 이것은 사용자에게 한 번 보여 주어야 할 문장이다. ③ 「그대로 보여야 하는 글」 안에 성격이 다른 두 가지가 섞여 있다. 하나는 스크립트가 만든 판정·개수·degrade 줄로, 스크립트가 미리 쉬운 문장을 붙일 수 있다. 다른 하나는 리뷰어의 자유 서술과 예상 못 한 오류로, 스크립트가 미리 풀어 둘 수 없다. 둘은 OQ5 의 답이 다를 수 있으니 따로 다루어야 한다. 참고로, 대안 후보 중 「판정 자리는 원문만, 설명 없음」은 S1(쉬운 설명을 앞에 쓴다)이 이미 닫은 길이라 대안으로 내지 않았다."
> recommendation: refined
> refined_takes: "쉬운 설명을 앞에, 원문은 지우지 않고 뒤에 둔다(P1·P2). 문제가 없으면 「이상 없음」 한 줄로 끝낸다. 모델이 자유롭게 쓰는 보고 글·질문·선택지 안내·다음 단계 설명은 모델이 쓰고, 검사 장치 없이 글쓰기 규칙으로 지킨다(P5). 스크립트가 미리 풀 수 없는 글(예상 못 한 오류, 리뷰어의 자유 서술)에도 모델이 쉬운 설명을 붙일 수 있다. 다만 그 설명은 통과·실패·clean 여부를 스스로 말하지 않고, 그 상태는 스크립트 줄이 말하게 둔다."
> refined_drops: "스크립트가 판정을 정하는 자리(qg 판정 줄·개수 줄·degrade 공시·버려진 항목 줄, docreview 선택지·분류처럼 판정이나 회계에 묶인 줄)에서 모델이 쓴 설명을 원문 앞에 두는 것은 버린다. 대신 세 가지로 바꾼다. 첫째, 그 스크립트가 쉬운 첫 줄을 직접 낸다(이미 있는 CATEGORY_GLOSS·_CHOICE_LABEL 방식을 넓힌다: 사람말을 앞에, 원래 낱말은 괄호에). 둘째, 스크립트가 내는 원래 문구(예: 영어 「No high-confidence findings …」) 자체를 쉬운 한국어로 바꾼다. 문구를 고정한 테스트는 같이 고치되 테스트가 지키는 뜻은 그대로 둔다(S1). 셋째, 리뷰 지적의 자유 서술은 전달하는 모델이 아니라 그 글을 쓴 리뷰어가 처음부터 쉽게 쓰게 한다. 이때 P6 이 리뷰어 출력에서 뺀 것은 «간결» 규칙뿐이고 «쉬운 말» 규칙은 아니라는 점을 사용자에게 확인받아야 한다. 이 변경은 검사 장치가 아니라 글을 그리는 코드를 바꾸는 것이라 S1 의 「검사 장치 없이」와 부딪히지 않는다."
> evidence:
>   - url: "https://www.pewresearch.org/short-reads/2025/07/22/google-users-are-less-likely-to-click-on-links-when-an-ai-summary-appears-in-the-results/"
>     supports: alternative
>     claim: "AI 요약이 맨 앞에 나오면 사람들이 원문 링크를 덜 누른다(15% → 8%, 요약 안의 출처 링크는 1%). 검색을 그대로 끝내는 비율도 16%에서 26%로 오른다. 앞에 놓인 요약이 사실상 원문을 대신한다는 뜻이다."
>     touches: [P2]
>     decides: [OQ5]
>   - url: "https://dl.acm.org/doi/fullHtml/10.1145/3411764.3445717"
>     supports: alternative
>     claim: "AI 가 붙인 설명은 그 추천이 맞든 틀리든 사람이 받아들이는 비율을 높였고, 틀린 경우에도 의존을 늘렸다(CHI 2021). 그럴듯한 설명을 판정 앞에 두면 그 설명이 판정보다 더 큰 힘을 갖는다."
>     touches: [P3]
>     decides: [OQ5]
>   - url: "https://arxiv.org/abs/2409.18661"
>     supports: alternative
>     claim: "초보 프로그래머 106명 실험에서 GPT-4가 그때그때 만든 오류 설명은 6개 과제 중 1개에서만 원래 컴파일러 메시지보다 빨리 고치게 했다. 전문가가 미리 써 둔 설명은 고친 시간과 만족도 양쪽에서 더 나았다."
>     touches: [P3]
>     decides: [OQ5]
>   - url: "https://dl.acm.org/doi/pdf/10.1145/3545945.3569770"
>     supports: current
>     claim: "LLM(Codex)이 초보자가 읽기 어려운 파이썬 오류 메시지를 풀어 쓴 설명은 대부분 이해할 만하다고 평가됐다(SIGCSE 2023). 미리 풀어 둘 수 없는 오류에는 모델이 쉬운 설명을 쓸 수 있다는 근거다."
>     touches: [P3]
>     decides: [OQ5]
>   - url: "https://www.nature.com/articles/s41746-025-01670-7"
>     supports: both
>     claim: "의료 기록 요약에서 LLM 의 사실 오류율은 1.47%, 누락률은 3.45%였다. 대부분은 충실하지만 0은 아니다. 검사 장치가 없는 판정 자리에서는 이 작은 비율이 그대로 사용자에게 간다."
>     touches: [P3, P5]
>     decides: [OQ5]
>   - url: "https://digital.gov/guides/plain-language/principles/organize"
>     supports: both
>     claim: "쉬운 글 지침은 가장 중요한 내용을 맨 앞에 쓰고 배경은 뒤에 두라고 한다. 쉬운 설명을 앞에 두는 순서(P2)는 어느 쪽이든 맞다. 이 지침은 누가 쓰는지는 정하지 않는다."
>     touches: [P2]
>     decides: []
>   - url: "https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content/"
>     supports: both
>     claim: "화면에서 사람은 글을 읽기보다 훑어보고, 첫 줄과 각 줄 앞부분에 시선이 가장 많이 간다. 맨 앞에 무엇을 두느냐가 사실상 독자가 읽는 전부를 정한다."
>     touches: [P2]
>     decides: [OQ5]
>   - url: "https://news.ycombinator.com/item?id=9805978"
>     supports: alternative
>     claim: "Elm 의 「Compiler Errors for Humans」는 오류를 받아 그때그때 해석해 주는 쪽이 아니라 오류를 내는 컴파일러 자체의 문구를 사람이 읽기 쉽게 다시 쓴 사례이고, Rust 오류 메시지가 이를 따랐다. 쉬운 말을 출처에서 만드는 방식의 선례다."
>     touches: []
>     decides: [OQ5]
> repo_claims:
>   - id: RC1
>     path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
>     anchor: "do NOT reformat or re-summarize it yourself (Law 1 determinism — the script, not the orchestrator, owns the rendering)"
>     line: 593
>     claim: "qg 판정 출력을 그리는 것은 스크립트이고, 오케스트레이터가 다시 정리하거나 요약하는 것은 금지다."
>     touches: [P3, P4]
>     decides: [OQ5]
>   - id: RC2
>     path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
>     anchor: "stdout 을 **그대로** 사용자에게 보인다(요약 · 재서술 금지). 앞에 한 줄:"
>     line: 601
>     claim: "판정 앞에 붙일 수 있는 것은 정해진 형식의 한 줄(`## qg iter N — <verdict>`)뿐이다. 모델이 쓴 설명을 앞에 두려면 이 규칙을 고쳐야 한다."
>     touches: [P2, P3]
>     decides: [OQ5]
>   - id: RC3
>     path: "shared/docreview/scripts/docreview_state.py"
>     anchor: "낱말을 바꾸는 것이 아니라 사람말을 앞에 두는 것이다"
>     line: 1239
>     claim: "레포에는 이미 «사람말을 앞에, 원래 낱말은 괄호에»를 스크립트가 만드는 선례가 있다(_CHOICE_LABEL 「고친다(채택)」 등). 대안은 새 장치를 만드는 것이 아니라 이 방식을 넓히는 것이다."
>     touches: [P2, P3]
>     decides: [OQ5]
>   - id: RC4
>     path: "shared/docreview/scripts/docreview_state.py"
>     anchor: "고정 라벨을 사람말로 바꾸면 그 자리에서 «동작을 반대로 설명»하게 된다"
>     line: 1237
>     claim: "결정 자리에서는 미리 정해 둔 사람말 한 개도 실제 동작과 반대로 설명할 위험이 있어서, 레포는 라벨을 상태에서 계산하게 바꿨다. 모델이 매번 새로 풀어 쓰면 이 위험이 매번 생긴다."
>     touches: [P3, P4]
>     decides: [OQ5]
>   - id: RC5
>     path: "shared/docreview/scripts/docreview_state.py"
>     anchor: "\"frozen_change\": \"얼림 검사가 잡은 변경\""
>     line: 1225
>     claim: "스크립트가 정해 둔 풀이 문구도 처음 보는 사람에게는 여전히 어려울 수 있다(「얼림 검사」). 스크립트가 쓴다고 저절로 쉬워지지는 않는다는 점에서 원안 쪽 근거다."
>     touches: []
>     decides: [OQ5]
>   - id: RC6
>     path: "plugins/quality-gates/scripts/synthesize_findings.py"
>     anchor: "f\"No high-confidence findings. {suppressed_count} low-confidence \""
>     line: 631
>     claim: "어려운 글의 상당수는 판정 스크립트(render 함수) 안에서 영어 고정 문구로 처음 만들어진다. 이 문구를 출처에서 쉬운 한국어로 바꾸면 모델이 덧붙일 필요가 줄어든다."
>     touches: []
>     decides: [OQ5]
>   - id: RC7
>     path: "plugins/spec-distill/skills/conducting-interview/references/steelman.md"
>     anchor: "conducting-interview 는 builder 출력을 **약화·편집하지 않는다** — verbatim 계약이다."
>     line: 93
>     claim: "반대 논거를 전달하는 쪽이 그 논거를 누그러뜨리지 못하게 막는 규칙이 이미 있다. 모델이 쓴 설명을 앞에 두면, 사람이 먼저 읽는 자리에서 이 규칙이 막으려던 길이 다시 열린다."
>     touches: [P3]
>     decides: [OQ5]
>   - id: RC8
>     path: "docs/philosophy/devbrew-harness-philosophy.md"
>     anchor: "qg v2.6.0의 self-honest verdict floor는 \"검토 안 한 scope를 clean이라 부르지 않기\"라는 정확성 보장 한 점에만 결정론을 걸고"
>     line: 84
>     claim: "철학 문서 P8 은 스크립트가 정하는 방식(결정론)을 판정 정확성 자리에만 쓰고 그 밖은 모델을 믿으라고 하며, 그 예로 qg 판정을 든다. 판정 자리는 스크립트, 나머지는 모델이라는 refined 경계와 같다."
>     touches: [P3, P5]
>     decides: [OQ5]
>   - id: RC9
>     path: "docs/philosophy/devbrew-harness-philosophy.md"
>     anchor: "같은 context의 reviewer는 자신이 방금 쓴 코드를 *defend*하는 default로 들어가므로"
>     line: 71
>     claim: "qg 에서는 리뷰 대상 코드를 쓴 오케스트레이터가 그 리뷰 결과도 전달한다. 그 오케스트레이터가 판정을 쉬운 말로 풀어 쓰면, AP3 가 말하는 «자기 코드를 변호하는» 기본 성향이 사람이 먼저 읽는 설명에 섞인다."
>     touches: [P3]
>     decides: [OQ5]
> ```
>
> 내가 확인한 파일(전부 읽기 전용):
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice/plugins/quality-gates/skills/quality-pipeline/SKILL.md (586~629행)
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice/plugins/spec-distill/skills/conducting-interview/references/steelman.md (75~110행)
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice/shared/docreview/scripts/docreview_state.py (1195~1262행)
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice/plugins/quality-gates/scripts/synthesize_findings.py (render 함수, 592~712행)
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice/docs/philosophy/devbrew-harness-philosophy.md (AP3 · P8)
>
> orchestrator 에게 알릴 점:
> - trigger 의 「CATEGORY_GLOSS·_CHOICE_LABEL 은 리뷰 엔진에 있다」는 맞다. 다만 실제 위치는 shared/docreview/scripts/docreview_state.py 이고, plugins 쪽은 심볼릭 링크라 Grep 으로는 찾을 수 없다.
> - 「판정 자리는 원문만, 설명 없음」은 S1 이 이미 닫은 길이라 대안으로 내지 않았다.

**게이트-전 확인** — repo_claims(builder 임시 id RC1~RC9 → 인터뷰 순번 RC23~RC31): RC23 확인 · RC24 확인 · RC25 확인 · RC26 확인 · RC27 확인 · RC28 확인 · RC29 확인 · RC30 확인 · RC31 확인 · 부착 주장: #1 pew → P2 확인(WebFetch 수치 대조) · #2 CHI2021 → P3 확인 · #3 arxiv 2409.18661 → P3 확인(WebFetch 원문 대조) · #4 SIGCSE2023 → P3 확인 · #5 nature → P3·P5 확인 · #6 digital.gov → P2 확인 · #7 nngroup → P2 확인 · #8 HN Elm 비부착 · 재검토 자격: 열림 1건(P3)

**사용자 선택** — 보완 (S7)

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-10-03) — web: enabled
- check_verbatim_coverage.py — exit 0 (2026-10-03)

## 5. 프로세스 로그

- 진입: seed 원문 대조 seed_provenance classify — audit ok · user_confirmed 21 · user_unconfirmed 0 · author 22
- dispatch: coverage-mapper 1회(R1 전) — derived 7 제안, 전부 admit(+ internal_research)
- round 1: path (b) — 바깥 사례 처분 → S2 (landscape 닫음)
- round 2: path (d) — 진짜 문제 재구성 초안 제시 → S3(seed 에서 어긋남)
- round 3: path (d) — 되묻기 1회 → S4(seed 그대로, root_problem 닫음)
- round 4: path (b) — 철학 문서 범위 → S5
- round 5: path (b) — 규칙 배달 범위 → S6
- dispatch: steelman-builder ST1 · blind-spot-prober 1회(병렬)
- round 6: steelman 게이트 → S7(보완, skepticism 닫음)
- round 7: path (b) — 숨은 위험 처분 → S8(blind_spot 닫음)
- round 8: 사용자 중간 메시지 S9(성능 우선) → 성능 우선 적용 범위 → S10
- round 9: path (b) — PR 나누기 → S11
- round 10: path (b) — 소개 문구 언어 → S12
- round 11: path (b) — 열린 질문 목록 확인 → S13(open_questions 닫음)
- D6 검증 의무 — seed «다시 검증할 것» 문단의 레포 확인 가능 항목(CLAUDE.md 도달 범위 · 공시 규칙과 '이상 없음' · 재서술 금지 · gloss 조항 · 소개 문구 · 버전 bump)을 RC1~RC15 로 산출해 V1 통과
- prober 사실 확인: MEMORY.md 154줄 29,046바이트 · 공식 문서 "first 200 lines or 25KB" · 스킬 압축 후 "first 5,000 tokens of each" WebFetch 대조 · SKILL.md 줄 수 1087/955/583 확인 · AskUserQuestion 칸 한도는 미확인
- RC34 는 RC9 와 같은 자리라 payload 에 싣지 않음
- 확인 RC1 — 확인 — shared/README.md#설치본에 들어가지 않는다 — 주장과 일치
- 확인 RC2 — 확인 — shared/README.md#상대 심볼릭 링크 — 주장과 일치(plugins/spec-distill/references/reviewing-document.md 가 mode 120000)
- 확인 RC3 — 확인 — plugins/spec-distill/tests/test_research_claims_contract.sh#subagent 의 Read 가 권한 거부 — 주장과 일치
- 확인 RC4 — 확인 — docs/superpowers/specs/2026-09-14-plugin-root-cwd-fallback-design.md#선재 문제, 따로 다룬다 — 주장과 일치
- 확인 RC5 — 확인 — plugins/quality-gates/hooks/hooks.json#"SessionStart" — 주장과 일치(나머지 둘은 PostToolUse·SessionEnd 만)
- 확인 RC6 — 확인 — plugins/spec-distill/references/proceed-gate.md#한 줄로 명시한다 — 주장과 일치
- 확인 RC7 — 확인 — plugins/spec-distill/skills/conducting-interview/references/finishing.md#그 채널들을 실제로 읽었다는 주장 — 주장과 일치
- 확인 RC8 — 확인 — CLAUDE.md#셀 수 없으면 「셀 수 없음」을 낸다 — 주장과 일치
- 확인 RC9 — 확인 — plugins/spec-distill/skills/framing-requests/SKILL.md#분량 상한을 두지 않는다 — 주장과 일치
- 확인 RC10 — 확인 — plugins/spec-distill/tests/test_framing_review_contract.sh#저자 편집 없음 — 주장과 일치
- 확인 RC11 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#re-summarize it yourself (Law 1 determinism — 주장과 일치(앵커가 593·594행에 걸쳐 줄바꿈)
- 확인 RC12 — 확인 — plugins/spec-distill/skills/conducting-interview/references/steelman.md#약화·편집하지 않는다 — 주장과 일치
- 확인 RC13 — 확인 — CLAUDE.md#어느 방향으로도 gloss 추가 안 함 — 주장과 일치
- 확인 RC14 — 확인 — CLAUDE.md#모든 PR마다 SemVer bump — 주장과 일치(네 플러그인 모두 이미 CHANGELOG.md 보유)
- 확인 RC15 — 확인 — plugins/plugin-audit/scripts/check-staleness.py#def scan_description_drift — 주장과 일치(strip 후 문자열 비교, auditing-plugins SKILL 201행 verdict 반영)
- 확인 RC16 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#scope check degraded — 주장과 일치
- 확인 RC17 — 확인 — plugins/spec-distill/skills/framing-requests/SKILL.md#「번호:처분」 — 주장과 일치(749·750행 bash case 가 한국어 라벨을 글자로 대조)
- 확인 RC18 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#줄이 정확히 한 번 — 주장과 일치
- 확인 RC19 — 확인 — plugins/project-init/hooks/post-tool-use.py#CONVENTIONAL_COMMIT_PATTERN — 주장과 일치
- 확인 RC20 — 확인 — plugins/spec-distill/tests/test_framing_review_contract.sh#assert_contains — 규모 주장 일치(실측 69개 파일 695개, 이 파일 102개)
- 확인 RC21 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#Self-narrating artifact — 주장과 일치
- 확인 RC22 — 확인 — plugins/spec-distill/skills/framing-requests/SKILL.md#기준 사본이 없다 — 주장과 일치
- 확인 RC23 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#re-summarize it yourself (Law 1 determinism — 주장과 일치(593·594행 줄바꿈, RC11 과 같은 자리)
- 확인 RC24 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#stdout 을 **그대로** 사용자에게 보인다(요약 · 재서술 금지). 앞에 한 줄: — 주장과 일치
- 확인 RC25 — 확인 — shared/docreview/scripts/docreview_state.py#사람말을 앞에 두는 것이다 — 주장과 일치(_CHOICE_LABEL)
- 확인 RC26 — 확인 — shared/docreview/scripts/docreview_state.py#동작을 반대로 설명 — 주장과 일치
- 확인 RC27 — 확인 — shared/docreview/scripts/docreview_state.py#"frozen_change": "얼림 검사가 잡은 변경" — 주장과 일치
- 확인 RC28 — 확인 — plugins/quality-gates/scripts/synthesize_findings.py#No high-confidence findings. {suppressed_count} low-confidence — 주장과 일치
- 확인 RC29 — 확인 — plugins/spec-distill/skills/conducting-interview/references/steelman.md#약화·편집하지 않는다 — 주장과 일치
- 확인 RC30 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#self-honest verdict floor — 주장과 일치
- 확인 RC31 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#defend*하는 default — 주장과 일치(quality-pipeline SKILL 61행: 오케스트레이터가 writer 이고 fix 를 소유)
- 확인 RC32 — 확인 — plugins/spec-distill/tests/test_check_brief.sh#과잉결정이 아니라 부피였고 — 주장과 일치(앵커가 687·688행 줄바꿈, test_brief_no_length_cap.sh 실재)
- 확인 RC33 — 확인 — plugins/spec-distill/tests/test_framing_review_contract.sh#T10-d — 주장과 일치
- 확인 RC34 — 확인 — plugins/spec-distill/skills/framing-requests/SKILL.md#분량 상한을 두지 않는다(줄이면 공시가 아니다) — 주장과 일치
- 확인 RC35 — 확인 — CLAUDE.md#모델 다양성 손실은 공시하고 막지 않는다 — 주장과 일치

### brief 리뷰 (reviewing-brief — 문서 리뷰 엔진)

- 라운드: 3 · 재리뷰 카운트 2 · 추가 라운드 0 — 승인 게이트 도달 사유: 상한 · 리뷰 완료: 예(라운드 3 round_reviewed 참)
- 결정: `## 8. 리뷰 결정` 기록 — 채택 2건(D1.1 §1 둘째 Goal → 제약 · D2.2 용어집을 순서로 읽음) · 열린 채 남은 항목 0건 · 저자 fix 적용 10건(라운드 3 의 2건은 추가 라운드 없이 적용 — 리뷰 재확인 없음) · 재비판 기각 1건(abf668a4#r3.1)
- codex: 있음(라운드 1·2 각 1건, 라운드 3 0건) · 웹: Claude doc-critic-web · codex 켜짐
- 냉독: gap 3건 (G3 — C2 기준 독자 범위 · C8 문구 테스트 뜻 유지 · C9 외부 스킬 번호 풀어 쓰기가 요약에 없음)
- degrade: pipeline:fidelity 라운드 1 재비판 문서 축약 · pipeline:fidelity 라운드 2·3 재비판 프로필 축약 · pipeline:all 라운드 2 finalize 이중 실행 후 복구 · pipeline:fidelity 상한 뒤 fix 2건 미재확인 · readback:readback 냉독 입력 축약 · (두 번째 채널) 라운드 1 기록 시도 실패 줄 1 · 원장 기록 1건이 오케스트레이터 state 재작성으로 사라져 다시 적음

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S2** 🗣 발화 (round 1):
  > 전·후 예시로 규칙 쓰기 (권장), "쉬운 말은 화면, 번호는 기록", 간결 규칙은 사람 글에만, 터미널은 중요한 것을 끝에, 기존 philosopy에 충돌되는거 있으면 개정하고 philosopy의 경우도 많이 낡은게 많아 그동안 모델도 클로드 코드도 많이 발전했다보니 그것도 수정이 필요하겠네 
- **S3** 🗣 발화 (round 2):
  > 내가 seed에 적은거에서 어긋난데 이건 
- **S4** ☑ 선택 (round 3):
  > 문제는 seed 그대로다 (추측) — 진짜 문제는 「글이 처음 보는 사람에게 어렵고 양이 많다」. 층이나 장치 이야기는 문제 정의에서 빼고 고칠 때 부딪히는 제약으로만 다룬다
- **S5** ☑ 선택 (round 4):
  > 충돌만 이번, 전반은 따로 (권장) — 이번 브랜치는 새 글쓰기 규칙과 부딪히는 철학 조항만 고치고, 낡은 부분 전반은 다음 작업으로 남긴다
- **S6** ☑ 선택 (round 5):
  > 닿아야 한다, 방식은 다음에 (권장) — 규칙은 플러그인 안에 두어 다른 레포에서 devbrew 를 쓰는 사람에게도 닿게 한다. SKILL.md 본문·공통 정본 링크·훅 중 어떤 방식인지는 다음 단계(설계)가 제약을 보고 정한다
- **S7** ☑ 선택 (round 6):
  > 보완 (builder·orchestrator 추천) — 판정·개수·공시 줄은 스크립트가 쉬운 첫 줄을 직접 낸다. 리뷰 지적은 리뷰어가 처음부터 쉽게 쓴다. 모델은 미리 풀 수 없는 글에만 설명을 붙이되 통과·실패는 말하지 않는다
- **S8** ☑ 선택 (round 7):
  > 규칙은 SKILL.md 맨 앞에 (권장), 메모리는 한도 안에서, 「이상 없음」에 따로 출구
- **S9** 🗣 발화 (round 8):
  > 이렇게 가도 모델 성능에는 문제 없겠지? 성능에 문제가 발생할 부분이면 성능이 우선이긴해
- **S10** ☑ 선택 (round 8):
  > 모델용 글은 성능 기준 (권장) — 모델이 읽는 글(SKILL.md 본문·agent 프롬프트·메모리·CLAUDE.md)은 정확한 문장을 유지하고 출력에 옮는 말투만 걷어낸다. 쉬운 말로 다시 쓰기는 사람이 읽는 글에만 한다
- **S11** ☑ 선택 (round 9):
  > 한 브랜치, 단계별 머지 (권장) — 같은 브랜치에서 ① 규칙과 공통 부분 → ② 플러그인별 수정을 차례로 PR 로 올려 머지한다. PR 을 겹쳐 쌓지 않고 앞 PR 이 머지된 뒤 다음 PR 을 연다
- **S12** ☑ 선택 (round 10):
  > 둘 다 영어 (권장) — plugin.json 과 마켓플레이스 소개 문구를 같은 영어 문장으로 두고, 처음 보는 사람이 알아보게 쉽게 다듬으며 project-init 불일치도 맞춘다
- **S13** ☑ 선택 (round 11):
  > 이 목록 그대로 (권장) — 열린 질문 여덟 가지(배달 방식 · 쪽별 고칠 목록 · 기계가 읽는 문구 · 리뷰어 쉬운 말과 성능 · 「구조적으로」 · qg 영어 · 레포 문서 범위 · 선택지 칸 한도)를 설계 단계로 넘긴다
- **S14** ☑ 선택 (round 12 — brief 리뷰 2라운드 결정):
  > 고친다(채택) — 순서로 읽음 — 「먼저 만들 것은 devbrew 설명 정본이나 용어집이 아니라 글쓰기 규칙이다」는 순서다. 용어집을 범위 밖 목록에서 빼고, 이번에 만들지는 설계가 정한다

## 7. 확산 원자료

- «google-errors» — https://developers.google.com/tech-writing/error-messages/error-handling — "Failure is inevitable; failing to report failures is inexcusable." 숫자 코드는 지원용
- «toss-writing» — https://toss.tech/article/8-writing-principles-of-toss — 원칙 2·3·4·5 원문 대조
- «anthropic-opus5» — https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5 — coverage-mapper 인용(lead with the outcome · positive examples · 리뷰어 덜 보고)
- «anthropic-prompting» — https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices — coverage-mapper 인용(prompt formatting influences response style)
- «clig» — https://clig.dev/ — coverage-mapper 인용
- «digitalgov» — https://digital.gov/guides/plain-language/writing — coverage-mapper 인용
- «korean-gov» — https://www.korean.go.kr/front/etcData/etcDataView.do?mn_id=&etc_seq=700&pageIndex=1 — 검색 결과로만 확인
- «pew-ai-summary» — https://www.pewresearch.org/short-reads/2025/07/22/google-users-are-less-likely-to-click-on-links-when-an-ai-summary-appears-in-the-results/ — WebFetch 수치 대조
- «chi2021» — https://dl.acm.org/doi/fullHtml/10.1145/3411764.3445717 — steelman 인용
- «arxiv-errmsg» — https://arxiv.org/abs/2409.18661 — WebFetch 원문 대조
- «sigcse2023» — https://dl.acm.org/doi/pdf/10.1145/3545945.3569770 — steelman 인용
- «nature-summ» — https://www.nature.com/articles/s41746-025-01670-7 — steelman 인용
- «nngroup-f» — https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content/ — steelman 인용
- «elm-errors» — https://news.ycombinator.com/item?id=9805978 — steelman 인용
- «cc-skills-doc» — https://code.claude.com/docs/en/skills — WebFetch 원문 대조
- «cc-memory-doc» — https://code.claude.com/docs/en/memory — WebFetch 원문 대조
- «cc-issue-13919» — https://github.com/anthropics/claude-code/issues/13919 — prober 인용
- «phare» — https://www.giskard.ai/knowledge/good-answers-are-not-necessarily-factual-answers-an-analysis-of-hallucination-in-leading-llms — prober 인용
- «curse-knowledge» — https://www.aje.com/arc/how-to-overcome-the-curse-of-knowledge — prober 인용
- «nglspn-strings» — https://github.com/alexcouper/nglspn/issues/103 — prober 인용
- «bigbang» — https://scalablehuman.com/2023/10/14/why-a-big-bang-rewrite-of-a-system-is-a-bad-idea-in-software-development/ — prober 인용
- «zenn-auq» — https://zenn.dev/shintaro/articles/claude-code-askuserquestion-skills?locale=en — prober 인용, 공식 대조 안 함

## 8. 리뷰 결정

- D1.1 · r1 · adopt · 30e53be6#r1.1 · "고친다(채택) — 제약으로 옮김" — 사용자는 장치 이야기를 문제 정의에서 빼고 제약으로만 다루라고 했다. 그런데 §1 은 「정직성 장치는 약해지지 않는다」를 두 번째 Goal 로 올렸다. 고를 두 상태: 이 줄을 Goal 로 둔다 / §2 제약으로 옮긴다.
- D2.2 · r2 · adopt · 30e53be6#r2.1 · "고친다(채택) — 순서로 읽음" — §1 Non-goal 「devbrew 설명 정본·용어집」의 원문은 「먼저 만들 것은 … 아니라」다. 우선순위로 읽으면 나중에 만들 수 있고, 범위로 읽으면 이번에 만들지 않는다. §1 은 이 중 범위 쪽 하나로 정했다.
- docreview 계수 — cca5d8c5-e0c9-4962-9d60-335d15c66846/2026-10-03-plain-language-output-intervi-e5c05d0c7c9d7da1 r1: advice_new=1 · advice_repeat=3 · mc_preexisting_new=0
- docreview 계수 — cca5d8c5-e0c9-4962-9d60-335d15c66846/2026-10-03-plain-language-output-intervi-e5c05d0c7c9d7da1 r2: advice_new=0 · advice_repeat=1 · mc_preexisting_new=0
- docreview 계수 — cca5d8c5-e0c9-4962-9d60-335d15c66846/2026-10-03-plain-language-output-intervi-e5c05d0c7c9d7da1 r3: advice_new=1 · advice_repeat=0 · mc_preexisting_new=0
