---
type: interview-audit
payload: 2026-11-15-present-tradeoffs-brief-interview.md
created_at: 2026-11-15
session_id: 34dcab50-d8b4-4d46-a347-1199115da8bb
source: spec-distill pm-interview
---

# 추천의 대가와 리뷰 뒤 질문 — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — S1 — 「전반적으로 트레이드 오프를 같이 제시해줘야함」 · 「리뷰어가 리뷰한뒤에 나한테 ask question하는데 설명이 비어있음 그리고 위를 보라는데 위에 아무것도 없음 설명도 부족」 / S8 — 「글자는 있었지만 내용이 없었다」 (@S1 · @S8)
- floor:landscape — closed — S16 — 바깥 선례의 처분(취함 셋 · 피함 하나를 이대로 받아들인다) (@S16)
- floor:skepticism — closed — S10 — ST1 의 방향 판정(보완) (@S10)
- floor:blind_spot — closed — S14 — 숨은 가정 · 실패 양식 일곱을 전부 위험으로 넘긴다 (@S14)
- floor:open_questions — closed — S18 — 설계에 넘길 열린 질문 여섯을 이대로 넘긴다 (@S18)
- derived:internal_research — closed — 레포 주장(RC1–RC61)이 처음 산출됐다 — 지금 증상을 처방하는 기존 규칙 · 그 문면을 잠근 테스트 · 이미 대가를 내는 자리(엔진 렌더 · 인터뷰 규약 · 지휘자 규칙)를 함께 다룬다; S17 · S24 — 레포에 이미 있는 것을 옮겨 쓰되 리뷰어 글은 모델이 줄인 요약으로 싣고 전문은 앞 글에 남긴다 (@S17 · @S24) (재개방 1회 — 리뷰어 글을 그대로 싣는다는 처분이 요약으로 바뀌었다)
- derived:screen_channel — closed — 「위에 아무것도 없음」의 원인이 셋으로 갈리고 고칠 자리가 다르다 — 모델이 안 썼다 / 질문 창이 가렸다 / 화면과 기록에서 사라졌다(#75182); S2 · S7 · S10 · S19 · S20 · S25 — 화면 확인 · 이유와 대가를 질문 안으로 · 질문 창이 정본 통로 · 화면 시험 · 경고는 요약 한 줄로 (@S2 · @S7 · @S10 · @S19 · @S20 · @S25) (재개방 1회 — 경고를 셋까지 한 줄씩 싣는다는 답이 요약 한 줄로 바뀌었다)
- derived:prior_decisions — closed — 2026-10-27 인터뷰의 확정(D16 이유는 질문 위 글에 · D13 외부 skill 질문은 그 skill 몫 · C17 강제 장치 금지)이 이 일의 선택지를 막거나 뒤집힌다 — 사용자 동의로 재결정할 항목; S7 · S5 · S10 — D16 재결정 · D13 유지 · 실행 중 검사 장치 없음(C17 유지) (@S7 · @S5 · @S10)
- derived:ownership_boundary — closed — 범위의 예 셋 중 설계 · 계획은 외부 skill 이 메시지 모양을 정한다 — devbrew 가 글을 쓰는 표면이 어디까지인가; S5 — 설계 · 계획 대화는 그 skill 에 맡긴다 (@S5)
- derived:minimum_content — closed — 리뷰 뒤 질문에는 추천을 다는 자리와 일부러 비우는 자리가 섞여 있다 — 추천 없는 질문에서 화면에 실어야 하는 최소가 무엇인가; S9 · S10 — 리뷰 결정 질문 안의 셋 · 추천 없는 질문에는 얻음 · 내줌을 억지로 채우지 않는다 (@S9 · @S10)
- derived:prose_recommendation_sites — closed — 확정 범위에 「모델이 한쪽을 권하는 글」이 들었는데 그런 문장 권고 자리의 목록이 레포에 없다; S12 — 문장 권고 자리 셋에 대가 한 구절 (@S12)
- derived:verification_method — closed — 기준 측정(세션 기록의 글자 수 · 낱말 맞추기)은 화면에 무엇이 보였는지를 담지 않는다 — 고쳐졌는지를 무엇으로 확인하나; S13 — 기록 재측정과 화면 확인 둘 다 (@S13)

## 2. Budget

- 질문 라운드: 13 · agent dispatch: 11 · coverage-mapper 1 · codex 실호출: 0 (성공 0)
- 조사 호출 7/60 (장치별: 커버리지 1 · 맹점 1 · 반론 1 · 레포 조사 3 · 만든 조사 1 · 본체 직접 12)
- 포화 판정 1: 아직 — 빈 곳 4개
- 포화 판정 2: 아직 — 빈 곳 5개
- 포화 판정 3: 아직 — 빈 곳 3개
- 포화 판정 4: 아직 — 빈 곳 5개
- 포화 판정 4: 사용자 판단 포화(@S35) — 반복 빈 곳

## 3. Steelman 원문

#### ST1 — 이유 · 대가 · 지적 내용을 질문 창 안에 싣고 앞 글 방식을 버린다

**dispatch 입력** — goal: S1 의 goal 문장(「이 일의 목표는 … 알 수 있게 하는 것이다. (사용자 확인)」) · 전제: P1 화면에 보이는 글만으로 무엇을 고르는지와 그 대가를 알 수 있어야 한다(S1) · P2 추천에는 내주는 것을 함께 적는다(S1) · P3 얻음 · 내줌은 한 줄 정도의 짧은 형식(S1) · P4 질문 위 글은 사라지는 날이 있어 기대면 안 된다(S7 · orchestrator 도출 포함) · P5 설명 칸에 글자가 있어도 라벨을 되풀이하거나 너무 짧으면 빈 것과 같다(S8) · P6 리뷰 결정 질문은 창 안에 무엇이 문제인지 · 그대로 두면 · 고치면이 있어야 한다(S9) · P7 범위는 devbrew 가 글을 쓰는 방향 자리와 리뷰 뒤 결정 질문이고 설계 · 계획 대화는 외부 skill 몫(S1 · S4 · S5 · S6) · 제약: S1–S9 원문 전량과 지난 인터뷰의 D13 · D16 · C17 · trigger: 기존 사용자 제약과의 충돌(D16 · C17 · 지난 설계의 Anti-goals) · landscape 모순(대화상자는 짧게 · 설명을 붙여도 과신은 줄지 않는다) · 앞 글 소실은 고쳐질 수 있는 버그

> 전제 반증은 없고 추천은 `refined` 입니다. 계약(`<claims_contract>`)을 받아 그 형식대로 냈고, `RC<n>` 은 임시 번호입니다. 레포 경로는 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/` 기준 상대경로입니다. `supports` 의 `current` 는 의심 방향(질문 창 안으로 옮김), `alternative` 는 아래 대안(이중 통로)입니다.
>
> ```yaml
> case_for_alternative:
>   statement: "질문 창 안에는 고르는 데 필요한 한 줄들만 요약으로 싣고, 질문 앞 글은 버리지 않고 전문(추천 이유의 풀이 · 리뷰 지적의 원문 · 경고 목록)을 싣는 둘째 통로로 의무로 남긴다 — 옮기지 않고 겹쳐 쓴다."
>   strongest: >-
>     질문 창도 사라지거나 잘리는 통로다. 선택지는 보이는데 질문 문장만 안 보이는 버그가 열려 있고(#77242),
>     긴 선택지 설명이 문장 중간에서 잘린다는 보고는 바로 「trade-off 설명이 붙은 기술 선택지」에서 나왔으며(#29125),
>     긴 질문 · 설명이 창 가장자리에서 잘려 「나머지는 사라진다」는 보고는 고친 판 표기 없이 완료 처리됐다(#67113).
>     한 통로로 옮기면 실패 지점이 하나가 되고, 겹쳐 쓰면 둘 중 하나만 살아도 사용자가 읽는다 — 앞 글은 기본 Opus 에서
>     정상으로 그려졌고(메인테이너 재현) 이 인터뷰의 화면 확인(S2)에서도 보였다.
>     바깥 지침의 상한(설명은 세 줄 이내 · 선택에 영향 없는 세부는 뺀다 · 「over-communicate 하지 마라」)은 창 안에 실을 수 있는
>     양을 묶는다. 리뷰 엔진의 「그대로 두면 · 고치면」 줄에는 길이 상한이 없어(RC4) 창에는 줄인 글만 들어가고,
>     줄이지 않은 원문과 경고 목록이 설 자리는 앞 글뿐이다.
>     인터뷰의 «추천 · 트레이드오프» 줄은 화면 출력이 곧 상태 기록 형식이라(RC10) 앞 글에서 뺄 수 없다 — 이미 이중 통로다.
> case_for_current:
>   strongest: >-
>     앞 글은 devbrew 가 통제하지 못하는 통로이고, 그 실패 꼴이 devbrew 게이트의 꼴과 같다. 도구 호출 → 글 → 질문 순서에서
>     글이 화면과 세션 기록 양쪽에서 빠진다(#75182 — 메인테이너가 2.1.233 에서 재현, 사용자 측정으로 세 모델에서 3번 중 0번만 글이 남았고
>     앞에 도구 호출이 없으면 12번 중 12번 남았다). 리뷰 게이트는 언제나 엔진 렌더(Bash 호출) 뒤에 온다.
>     보고는 2.1.325(2026-11-14)까지 이어지고, changelog 맨 위 다섯 판에 고친 줄이 없으며, 고칠 자리가 모델 쪽인지 클라이언트 쪽인지도 정해지지 않았다.
>     같은 이슈에서 「글과 질문을 한 턴에 쓰지 말라」는 지시는 「do not hold reliably」였다.
>     버그가 고쳐져도 앞 글은 진다. 레포 측정에서 「위」를 가리킨 질문 107개 중 65개가 앞 글 0자였고(RC12),
>     지난 인터뷰의 사용자 확정 진단은 「보였는데 놓침」이었다(RC13) — 보일 때도 읽히지 않았다.
>     반면 question · description 은 도구 호출의 칸이라 세션 기록에 그대로 남아, 고쳐졌는지를 기록으로 잴 수 있다.
>     리뷰 결정 질문에는 가리킬 «위»가 애초에 없다. 절차서는 렌더 첫 줄만 앞 글에 쓰라고 하고 지적별 「그대로 두면 · 고치면」은
>     Bash 출력에만 있다(RC6). 리뷰어는 그 셋(무엇이 문제인지 한 문장 · 그대로 두면 · 고치면)을 이미 «게이트에 그대로 실릴» 글로 쓴다(RC5) —
>     본문과 두 선택지 설명에 그대로 꽂으면 엔진 코드도, 「설명에는 고르면 무엇이 달라지는지만」 규칙도 바꾸지 않는다(RC1 · RC4).
>     바깥 지침은 «짧게»를 말할 뿐 «창 밖에»를 말하지 않는다. Microsoft 는 추천 표시는 라벨에, 「왜 고를 만한지 · 고르면 어떻게 되는지」는
>     선택지 바로 아래 설명에(세 줄 이내) 두고, 맥락 없이 뜨는 창은 창 안에서 왜 떴는지 설명하라고 한다. W3C 는 선택지마다
>     이득 · 위험 · 결과를 선택지 옆에, MCP 는 요청 화면 자체가 무엇을 왜 묻는지 밝히라고 한다. 길이 상한은 전제 P3 이 이미 갖고 있다.
>     겹쳐 쓰면 화면이 길어지고(P3) 두 글이 어긋날 수 있으며, 앞 글을 의무로 남기는 한 「위에 적었다」로 되돌아갈 길이 열려 있다.
> premise_refutation:
>   hits: []
> premise_list_challenge: >-
>   반증은 없지만 목록에 결함이 다섯 있다.
>   (1) 빠진 전제 — 경고(degrade) 줄. 버리려는 문면 「경고 N개 — 위에 적었다」가 실제로 가리키는 것은 추천 이유도 리뷰 지적 셋도 아니고
>   경고 목록인데(RC7), 방향 문장과 P6 은 경고를 어디에 실을지 말하지 않는다. 사용자가 직접 연 사례가 바로 이 줄이었다(RC12).
>   P1 · P4 를 그대로 적용하면 경고도 창 안에 한 줄씩 있어야 하고, 지금 규칙과 락은 그것을 명시로 금한다(RC8 · RC9).
>   (2) 빠진 전제 — 「질문 창 안의 글은 다 보인다」. 방향은 이것을 말없이 가정한다. 창의 실패 보고(#77242 · #29125 · #67113 · #45384)는
>   긴 글 · preview 칸 · 테마에 몰려 있다 — 그래서 P3(짧게)은 취향이 아니라 «보이기 위한 조건»이고, preview 칸은 쓰지 않아야 한다.
>   (3) P5 는 둘을 묶었다. 「라벨을 되풀이」는 바깥 지침도 금하지만(Microsoft 「wordy restatement」), 「너무 짧으면」은 P3 과 부딪히고
>   그 지침은 라벨이 자명하면 설명을 안 붙여도 된다고 한다. 재는 기준은 길이가 아니라 «고르면 달라지는 것(얻음 · 내줌)을 말하는가»여야 한다 —
>   글자 수로 재는 검사는 거짓 대리 지표가 된다(OQ3 · OQ11).
>   (4) P3 과 P6 사이 긴장. 지적 하나에 셋을 싣되 한 줄이어야 하는데, 엔진 줄에는 길이 상한이 없다(RC4). 누가 줄이는지(리뷰어가 처음부터 짧게 쓰는지,
>   질문을 짜는 저자 모델이 줄이는지)가 전제에 없다. 정본 블록 9행 「스크립트·subagent 가 낸 원문은 고치지 않는다」와, 저자가 리뷰어의 지적을
>   자기 말로 줄이는 것(Law 2 쪽 위험)이 걸린다.
>   (5) P4 의 근거가 이슈 하나로만 적혀 있다. 실제 근거는 셋이다 — 하니스가 지운다(#75182) · 모델이 안 쓴다(지시가 지켜지지 않는다) ·
>   보여도 놓친다(RC13). 버그가 고쳐져도 뒤의 둘은 남으므로 trigger (3)은 P4 를 무너뜨리지 못한다. 셋을 전제에 적어 두어야 한다.
>   덧붙임 — 메인테이너 우회책(턴을 글로 끝내고 질문 도구 없이 묻기)은 닫힌 경로가 아니지만 대안으로 세우지 않았다. 게이트들이 고른 라벨 글자를
>   읽어 분기하고(「라벨 끝의 꼬리를 뗀 이름으로 읽는다」), S9 가 질문 창을 전제로 답해졌으며, 그 지시가 지켜지지 않았다는 보고가 같은 이슈에 있다.
> recommendation: refined
> refined_takes: >-
>   질문 창이 정본 통로다. 어느 질문도 앞 글이 보여야만 고를 수 있게 짜지 않는다.
>   (a) 추천이 있는 질문은 선택지 설명마다 「얻음 · 내줌」 한 줄 — 추천 선택지의 얻음이 곧 추천 이유이고, 모든 선택지에 같은 꼴로 써서 추천 쪽에만 설득 문장이 붙지 않게 한다.
>   (b) 리뷰 뒤 결정 질문은 본문에 무엇이 문제인지 한 줄, 「고친다」 설명에 「고치면」, 「그대로 둔다」 설명에 「그대로 두면」 — 리뷰어가 쓴 글을 그대로 쓴다.
>   (c) 내용을 「위에 적었다」만으로 가리키는 문면을 없앤다. 경고도 같은 원칙으로 창 안에 한 줄씩 싣는 쪽을 사용자에게 묻는다(위 결함 1).
>   (d) 지키게 하는 장치는 규칙 문장과 레포 테스트까지다(C17 · 지난 설계의 Anti-goals).
> refined_drops: >-
>   (a) 「앞 글 방식을 버린다」의 넓은 읽기 — 앞 글 자체를 없애는 것. 앞 글은 덤으로 남긴다: 인터뷰 «다음 결정» 줄(상태 기록과 같은 형식이라 뺄 수 없다) ·
>   엔진 렌더 첫 줄 · 근거 · 자리 · 줄이지 않은 원문. 정본 블록은 문장을 늘리지 않고 「이유는 질문 위 글에」 구절만 바꾼다.
>   (b) 길이 무제한 — 설명은 한 줄(넘어도 세 줄), 본문은 결정과 문제 한 줄. 근거 · 자리 · 선택에 영향 없는 세부와 preview 칸은 창에 싣지 않는다.
>   (c) 추천이 없는 질문과 이름만으로 뜻이 서는 선택지(멈춤 등)에 얻음 · 내줌을 억지로 채우는 것 — 되풀이 설명을 새로 만든다.
>   (d) 실행 중 훅 · mod 로 질문 칸을 검사하거나 고치는 것, 리뷰 엔진의 라벨 코드를 바꾸는 것.
> evidence:
>   - url: "https://github.com/anthropics/claude-code/issues/75182"
>     supports: current
>     claim: >-
>       2026-07-07 개설, 2026-11-15 현재 열림 · 담당자 없음 · 고친 판 언급 없음. 메인테이너(bcherny, 2026-08-16)가 2.1.233 macOS 터미널에서 재현:
>       기본 Opus 는 글이 질문 위에 그려졌고 Fable 5 는 답하기 전에도 뒤에도 안 보였으며 저장된 세션 기록에도 없었다 —
>       「the model's user-facing text is arriving in a form the CLI treats as hidden reasoning」, 고칠 자리는 「still being worked out」.
>       우회책은 턴을 평문으로 끝내거나 Fable 이 아닌 모델을 쓰는 것. 사용자 보고(메인테이너 미확인): 2.1.302 에서 opus-5-5 · sonnet-5-5 · fable-5-1 은
>       3번 중 0번, haiku-5-5 만 3번 중 3번 글 블록이 남았고, 실패한 기록의 꼴은 tool_use > thinking > thinking > tool_use,
>       앞에 도구 호출이 없으면 12번 중 12번 남았다. 2.1.317 Windows · 2.1.325 Linux(Opus 5.5, 2026-11-14)에서도 보고.
>       「글과 질문을 한 턴에 쓰지 말라」는 CLAUDE.md · 메모리 지시는 「do not hold reliably」. 질문 앞 글을 훅으로 세는 우회는 한 사람은 된다고,
>       다른 사람은 2.1.325 에서 「Neither PreToolUse nor PostToolUse on AskUserQuestion sees the running turn's assistant entry」라고 보고했다.
>     touches: [P4]
>     decides: [OQ3, OQ4, OQ11]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md"
>     supports: current
>     claim: >-
>       맨 위 판은 2.1.325. 읽은 범위(2.1.325 · 2.1.323 · 2.1.322 · 2.1.321 · 2.1.319)에 「같은 턴의 질문 앞 글이 안 그려짐」을 고쳤다는 줄이 없다.
>       그 아래 판은 이번에 읽지 못했다(파일이 길어 앞 10만 자만 읽음).
>     touches: [P4]
>     decides: []
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: uncertain
>   - url: "https://code.claude.com/docs/en/agent-sdk/user-input"
>     supports: current
>     claim: >-
>       공식 형식: 호출당 질문 1–4개, 질문당 선택지 2–4개, header 「max 12 characters」, 선택지는 「each with `label` and `description`」.
>       `preview` 는 SDK 에서 `previewFormat` 을 켰을 때만 생긴다(「Without this setting, Claude does not generate previews」).
>       question · label · description 의 글자 수 상한은 이 문서에 없다. 실을 칸은 질문 문장 · 라벨 · 설명 셋뿐이고,
>       셋 다 도구 입력이라 호출 기록에 그대로 남는다.
>     touches: []
>     decides: [OQ4, OQ11]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://learn.microsoft.com/en-us/windows/win32/uxguide/ctrl-command-links"
>     supports: both
>     claim: >-
>       Windows UX 지침(Windows 7 때 문서 · 「Much of the guidance still applies in principle」). 원안 쪽: 「If a response is strongly recommended, add
>       "(recommended)" to the label」, 「Supplemental explanations describe why users might want to choose a response or what happens if a response is chosen」 —
>       이유와 결과의 자리는 선택지 바로 아래다. 대안 쪽(양의 상한): 「Use parallel phrasing and at most three lines of text. Long supplemental
>       explanations discourage reading」, 「Omit details that don't affect the choice」, 「Don't use command links to over-communicate」.
>       P5 관련: 「Don't use a supplemental explanation that is wordy restatement of the command link. Use a supplemental explanation only when you can't
>       make a command link self-explanatory. Providing a supplemental explanation for one command link doesn't mean that you have to provide them for all」 —
>       되풀이는 금하되 짧음 · 없음 자체는 결함으로 보지 않는다.
>     touches: [P2, P3, P5]
>     decides: [OQ4, OQ3]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://learn.microsoft.com/en-us/windows/win32/uxguide/win-dialog-box"
>     supports: current
>     claim: >-
>       같은 지침의 dialog 절: 주 지시문은 「Be concise use only a single, complete sentence … If you must explain anything more, use supplemental
>       instruction」, 「If the appearance of the dialog box is program or system initiated (and therefore out of context), use the supplemental instruction to
>       explain why the dialog has appeared. For such dialogs, the context is usually not obvious」, 「Don't repeat the main instruction with slightly different
>       wording」. 맥락은 창 밖이 아니라 창 안의 보조 지시문에 싣는다 — 질문 본문 = 결정 한 문장 + 문제 한 줄의 선례다.
>     touches: [P1, P6]
>     decides: [OQ4]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://www.w3.org/WAI/WCAG2/supplemental/patterns/o7p03-supported-choice"
>     supports: current
>     claim: >-
>       W3C 인지 접근성 패턴 「Clearly State the Results and Disadvantages of Actions, Options, and Selections」: 「When presenting users with actions and
>       selections, clearly explain the benefits, risks and consequences of each option」. 예시는 선택지 옆에 무엇이 포함되는지를 두라는 것이고,
>       고른 뒤에야 나오는 세부를 피하라고 한다. 짧게 쓰는 법은 다루지 않는다.
>     touches: [P1, P2]
>     decides: [OQ4]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://modelcontextprotocol.io/specification/2025-06-18/client/elicitation"
>     supports: current
>     claim: >-
>       MCP elicitation 규격: 「Clients SHOULD present elicitation requests in a way that makes it clear what information is being requested and why」.
>       에이전트가 사람에게 입력을 구할 때 무엇을 왜 묻는지는 요청 화면 자체가 밝혀야 한다는 표준 문장이다.
>     touches: [P1]
>     decides: [OQ4]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://raw.githubusercontent.com/garrytan/gstack/main/scripts/resolvers/preamble/generate-ask-user-format.ts"
>     supports: current
>     claim: >-
>       다른 하니스(gstack)의 선례: 질문 글 «안»에 근거 한 문장 · 쉬운 설명 2–4문장 · 「Stakes if we pick wrong」 한 문장 ·
>       「Recommendation: <choice> because <one-line reason>」을 넣고, 선택지마다 장점 둘 이상 · 단점 하나 이상(각 40자 이상)과 「Net」 한 줄을 요구한다.
>       추천과 이유 · 대가를 질문 안에 싣는 방식의 실례다. 다만 분량은 이 일의 사용자가 길다고 한 「문장으로 풀어 쓴 형식」 쪽이다 — 자리는 취하고 길이는 취하지 않는다.
>     touches: [P2]
>     decides: [OQ4]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://github.com/anthropics/claude-code/issues/77242"
>     supports: alternative
>     claim: >-
>       열림(2026-07-13 개설, 마지막 댓글 2026-10-07). 질문 창에서 header 와 선택지(라벨 · 설명)는 보이고 question 글만 안 보인다(2.1.201 · 2.1.207 · 2.1.234, macOS).
>       메인테이너(bcherny, 2026-08-17)는 Linux tmux 에서 재현하지 못했다. 보고자 진단(메인테이너 미확인): 질문 글이 dark 테마의 흰색으로 칠해져
>       밝은 배경 터미널에서 대비 약 1.04:1 이고 `/theme` 을 Auto 나 Light 로 바꾸면 보인다. 질문 본문에만 실은 내용은 이 환경에서 안 보인다 —
>       질문 창도 완전한 통로가 아니다.
>     touches: [P1]
>     decides: [OQ4, OQ11]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: uncertain
>   - url: "https://github.com/anthropics/claude-code/issues/29125"
>     supports: alternative
>     claim: >-
>       2.1.59 · 80x24 터미널에서 긴 선택지 설명이 문장 중간에서 잘린다는 보고 — 「fixed rendering area doesn't accommodate longer descriptions, which are
>       common when Claude presents technical options with trade-off explanations」. 봇이 #28991 의 중복으로 닫았고 메인테이너 댓글 · 고친 판은 없다.
>       대가 설명을 길게 실은 선택지가 잘리는 실제 보고다. 지금 판에서도 그런지는 확인하지 못했다.
>     touches: [P3]
>     decides: [OQ4]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: uncertain
>   - url: "https://github.com/anthropics/claude-code/issues/67113"
>     supports: alternative
>     claim: >-
>       긴 질문 글 · 긴 선택지 설명 · preview 가 줄바꿈 없이 창 가장자리에서 잘린다는 보고(2026-06-10, Fable 5, macOS CLI) —
>       「lines are cut at the dialog edge and the remainder is gone」. 2026-06-16 에 완료로 닫혔으나 메인테이너 댓글 · 연결된 PR · 고친 판이 페이지에 없다.
>       창 안에 긴 글을 실을 때의 한계는 실제 화면에서 재야 한다.
>     touches: [P3]
>     decides: [OQ4, OQ11]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: uncertain
>   - url: "https://github.com/anthropics/claude-code/issues/45384"
>     supports: both
>     claim: >-
>       선택지에 `preview` 가 있으면 `description` 이 그려지지 않는다는 보고(2026-04-08, macOS CLI, 판 미기재) — 「Only `label` and `preview` are
>       rendered. `description` is silently dropped」. 메인테이너 댓글 없이 봇이 비활성으로 닫았다. 설명 칸에 대가를 싣는다면 preview 칸을 함께 쓰지 않아야 한다.
>     touches: []
>     decides: [OQ4]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: uncertain
>   - url: "https://arxiv.org/abs/2006.14779"
>     supports: both
>     claim: >-
>       Bansal 외(CHI 2021): 설명은 사람이 AI 추천을 받아들일 가능성을 그 추천이 옳든 그르든 높였고, 팀 정확도는 확신도만 보인 경우보다 높아지지 않았다.
>       trigger (2)의 「설명을 붙여도 과신은 줄지 않는다」의 출처 계열이다. 이 일의 goal 은 과신을 줄이는 것이 아니라 고르는 것과 대가를 알 수 있게 하는 것이라
>       어느 전제와도 충돌하지 않는다. 닿는 것은 P2 다 — 추천 «이유»만 붙이면 수락만 늘 수 있으므로 내주는 것을 같은 줄에 적는 것이 그 반대 무게다.
>       초록을 검색 요약으로 읽었다.
>     touches: [P2]
>     decides: [OQ4]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: uncertain
>   - url: "https://arxiv.org/abs/2212.06823"
>     supports: current
>     claim: >-
>       Vasconcelos 외(CSCW 2023, 다섯 연구 N=731): 사람은 설명을 읽을지를 비용 대 이득으로 고르며, 설명이 AI 를 확인하는 비용을 충분히 낮출 때는
>       과신이 줄었다 — 앞선 무효 결과는 설명이 확인 비용을 충분히 낮추지 못해서일 수 있다고 본다. 고르는 자리 바로 옆의 한 줄 「얻음 · 내줌」은
>       다른 곳의 긴 글을 찾아 읽는 것보다 확인 비용이 낮다. 초록을 검색 요약으로 읽었다.
>     touches: [P3]
>     decides: [OQ4]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: uncertain
>   - url: "https://www.eecs.harvard.edu/~kgajos/papers/2021/bucinca2021trust.shtml"
>     supports: both
>     claim: >-
>       Buçinca · Malaya · Gajos(CSCW 2021, N=199): 설명을 붙이는 것만으로는 과신이 줄지 않는 것으로 보이고, 생각을 강제하는 장치는 과신을 줄였으나
>       사용자는 그런 설계를 덜 좋아했다. 설명 칸에 대가를 적는다고 반드시 읽힌다는 근거는 아니다. 다만 비교 대상(앞 글)도 같은 한계를 지므로
>       자리 선택을 가르지 못한다. 초록을 검색 요약으로 읽었다.
>     touches: []
>     decides: []
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: uncertain
>   - url: "https://www.anthropic.com/engineering/claude-code-auto-mode"
>     supports: both
>     claim: >-
>       「in practice users accept 93% of them anyway」 · 「approval fatigue, where people stop paying close attention to what they're approving」 —
>       이 수치는 명령 실행 · 파일 수정 앞의 «권한 승인 질문»에 관한 것이고 선택지 질문에 관한 것이 아니다. trigger (2)의 「승인 질문이 잦으면 덜 읽는다」는
>       질문의 빈도에 관한 주장인데 이 방향은 질문 수를 바꾸지 않는다 — 전제에 닿지 않는다.
>     touches: []
>     decides: []
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: confirmed
>   - url: "https://doi.org/10.3389/feduc.2019.00086"
>     supports: current
>     claim: >-
>       공간 근접(spatial contiguity) 연구: 관련된 글을 가리키는 대상 가까이에 둘 때 이해가 낫다 — Beege 외(2019)는 과제가 복잡할 때 통합 배치의 효과가 크고
>       (d = 0.78) 단순할 때는 작다고(d = 0.28, 유의하지 않음) 보고했고, 선행 메타분석(Schroeder & Cenkci 2018, 58개 비교)은 g = 0.63 을 보고했다.
>       「위에 적었다」로 떨어진 글을 가리키는 꼴은 이 연구들이 말하는 주의 분할 배치다. 학습 과제 연구라 질문 창에 그대로 옮기는 것은 유추이고,
>       검색 요약으로만 읽었다.
>     touches: [P1]
>     decides: [OQ4]
>     source_kind: primary
>     checked_at: "2026-11-15"
>     certainty: uncertain
> repo_claims:
>   - id: RC1
>     path: "shared/style/plain-language.md"
>     anchor: "설명에는 고르면 무엇이 달라지는지만 쓴다"
>     line: 6
>     claim: >-
>       정본 블록 6행이 설명 칸을 「고르면 무엇이 달라지는지만」으로, 추천 이유의 자리를 「이유는 질문 위 글에」로 정한다. 이 방향이 뒤집는 것은 뒤 구절 하나다.
>       「얻음 · 내줌」과 리뷰의 「그대로 두면 · 고치면」은 «고르면 달라지는 것»이라 앞 문장을 고치지 않고 설명 칸에 들어간다.
>       같은 블록 9행 「스크립트·subagent 가 낸 원문은 고치지 않는다」는 리뷰어 글을 창에 맞춰 줄이는 일과 걸린다.
>     touches: [P2, P6]
>     decides: [OQ4, OQ3]
>   - id: RC2
>     path: "shared/tests/test_plain_language_block.sh"
>     anchor: "REC='추천이 있으면 그 선택지를 첫 자리에 두고 라벨 끝에 「(권장)」을 단다 — 여럿이면 모두, 이유는 질문 위 글에."
>     line: 30
>     claim: >-
>       그 문장은 글자째 잠겨 있고(정본에 정확히 한 번), 블록은 `plugins/*/skills/*/SKILL.md` 전부에 같은 바이트로 복제돼 판정 모듈이 동일성을 잰다.
>       「이유는 질문 위 글에」를 바꾸면 이 락과 모든 사본이 한 커밋에서 함께 바뀐다 — 규칙 문장만 두는 길에도 이 비용은 든다.
>     touches: []
>     decides: [OQ3]
>   - id: RC3
>     path: "docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md"
>     anchor: "## Anti-goals"
>     line: 47
>     claim: >-
>       지난 설계의 Anti-goals 는 넷이다 — 실행 중 질문 도구 호출에 끼어드는 훅 · 래퍼, 복제 블록을 눈에 띄게 늘리는 것, 화면의 「추천 없음」 문구,
>       리뷰 엔진의 라벨 코드 · 정답 파일을 바꾸는 것. 30행이 C17 의 뜻을 「순정 Claude Code 의 동작에 잘못 끼어들어 성능을 해치지 말라」로 풀고,
>       68행은 정본을 「새 줄을 더하지 않고 있는 문장을 바꾼다」로 고쳤으며, 178행 AC3 은 블록 변경으로 새로 밀려난 `## ` 절이 없는지를
>       `token_boundary.py` 로 잰다. 이 방향은 구절 치환(블록을 늘리지 않음) · 엔진 코드 무변경(RC4) · 훅 없음으로 넷 모두 안에서 할 수 있다 —
>       trigger (1)의 충돌은 D16 하나로 좁혀지고, 그것은 S7 로 재결정됐다.
>     touches: []
>     decides: [OQ3, OQ4]
>   - id: RC4
>     path: "shared/docreview/scripts/docreview_state.py"
>     anchor: "def _rg_decide(st, g, fid)"
>     line: 2295
>     claim: >-
>       엔진 렌더는 결정 항목마다 요약 한 줄과 「그대로 두면: <if_unfixed>」 · 「고치면: <replacement>」 · 「근거」 · 「자리」 · 「대안」 줄을 이미 만든다(2310–2315행).
>       나가는 곳은 `gate --render` 의 표준 출력이다. 이 줄들을 질문 본문 · 설명으로 옮기는 것은 절차서 문장의 일이라 엔진 코드를 바꾸지 않는다.
>       같은 파일 `_one`(2223행)은 공백만 접어 한 줄로 만들 뿐 길이를 자르지 않는다 — 설명 칸에 그대로 실으면 길이는 리뷰어가 쓴 만큼이다.
>     touches: [P6, P3]
>     decides: [OQ4]
>   - id: RC5
>     path: "plugins/spec-distill/agents/doc-critic.md"
>     anchor: "`summary`·`if_unfixed`·`replacement` 는 게이트에 그대로 실려 처음 보는 사람이 읽는다"
>     line: 68
>     claim: >-
>       P6 의 셋은 리뷰어가 이미 따로 쓰는 칸이다 — `summary`(한 문장 · 내부 기호 없이 무엇이 문제인지), `if_unfixed`(「문제의 재진술이 아니라 결과」),
>       `replacement`(「고치면 무엇이 되는가」, decide 에는 필수). 셋 다 쉬운 말로, 게이트에 그대로 실릴 글로 쓰라고 돼 있다. 저자 모델이 새로 요약할 필요 없이
>       본문 = summary · 「그대로 둔다」 설명 = if_unfixed · 「고친다」 설명 = replacement 로 꽂을 수 있다. `summary` 만 한 문장 제한이 있고 나머지 둘은 길이 제한이 없다.
>     touches: [P6]
>     decides: [OQ4]
>   - id: RC6
>     path: "shared/docreview/references/reviewing-document.md"
>     anchor: "렌더 첫 줄(상태와 경고)은 첫 호출 **앞 글**에 한 번 쓴다"
>     line: 30
>     claim: >-
>       절차서 8단계가 앞 글에 쓰라고 하는 것은 렌더 «첫 줄»뿐이고, 질문 본문은 「결정 하나와 … 「경고 N개 — 위에 적었다」 한 줄만」이다.
>       42행은 「렌더의 「고치면」 줄이 전문을 이미 내므로 라벨은 그 줄을 가리키는 손잡이다」라고 하지만, 지적별 줄을 사용자에게 보이는 글이나 설명 칸으로
>       옮기라는 문장은 이 파일에도, 같은 문장을 가진 spec-review(554행) · request-framing(783행) · reviewing-brief(603행)에도 없다
>       (세 SKILL 과 references 를 「그대로 두면」 · 「렌더 … 쓴다/싣는다」로 훑어 확인 — 다른 표현의 규칙이 있을 가능성은 남는다).
>       리뷰 결정 질문에서 지적 내용이 사는 곳은 Bash 도구 출력이다 — 버그가 없어도 가리킬 앞 글이 규칙에 없다.
>     touches: [P6, P4]
>     decides: [OQ4]
>   - id: RC7
>     path: "plugins/spec-distill/references/proceed-gate.md"
>     anchor: "질문 본문에는 결정 하나와 「경고 N개 — 위에 적었다」"
>     line: 44
>     claim: >-
>       게이트 정본은 판정 결과와 degrade 를 「하나도 빠뜨리지 않고 게이트 앞 글에」 쓰고(39–40행) 질문에는 개수 줄만 두라고 한다.
>       「위에 적었다」가 가리키는 것은 경고 목록이다. 같은 파일 56행은 둘째 질문의 「제안 이유는 게이트 앞 글에」 쓰라고 한다 — 질문 밖 「권하는 글」 자리의 하나이고,
>       「이유는 … 앞 글에 / 위 글에」 글자 계열로 찾을 수 있는 자리다(정본 블록 6행 · finishing.md 536행이 같은 꼴).
>     touches: [P1, P4]
>     decides: [OQ4, OQ10]
>   - id: RC8
>     path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
>     anchor: "옵션 description 에 싣지 않습니다"
>     line: 497
>     claim: >-
>       인터뷰 끝 게이트는 「모든 degrade record 는 게이트 앞 글에 한 줄씩 씁니다 — 옵션 description 에 싣지 않습니다. 사용자가 옵션을 고르기 전에 읽도록
>       질문 바로 앞에 둡니다」라고 정한다. 이 규칙의 근거(«고르기 전에 읽도록 앞에»)가 P4 와 정면으로 부딪힌다 — 앞 글이 안 보이면 경고는 고르기 전에 읽히지 않는다.
>       513행 질문 리터럴에도 「경고 <N>개 — 위에 적었다」가 박혀 있다. 536행은 둘째 질문의 제안 이유를 「게이트 앞 글(위 목록 끝)에 한 줄로」 쓰라고 한다.
>     touches: [P1, P4]
>     decides: [OQ4, OQ10]
>   - id: RC9
>     path: "plugins/spec-distill/tests/test_plain_gate_templates.sh"
>     anchor: "# ⑬ 질문 본문에는 결정과 상태 한 줄만"
>     line: 133
>     claim: >-
>       「질문 본문에는 결정 하나와 … 「위에 적었다」 … 한 줄만」 문장이 여섯 자리에서 글자째 정확히 한 번으로 잠겨 있고(134–142행),
>       143–147행은 여섯 파일 어디에도 「경고를 질문에 한 줄씩 싣는 문장이 없다」는 음의 락이며, 150행은 finishing 의 「옵션 description 에 싣지 않습니다」를 잠근다.
>       「위에 적었다」 방식을 버리거나 경고를 창 안에 싣기로 하면 이 양 · 음의 락을 함께 뒤집어야 한다 — 지금 락은 새 방향의 반대쪽을 지킨다.
>     touches: []
>     decides: [OQ3, OQ4]
>   - id: RC10
>     path: "plugins/spec-distill/skills/pm-interview/SKILL.md"
>     anchor: "사용자에게 보이는 출력과 state 본문 기록이 같은 형식이다"
>     line: 180
>     claim: >-
>       인터뷰 라운드 규약은 질문 앞 글 `### 다음 결정` 에 「OQ<n>: … · 추천: … · 트레이드오프: <선택지별 한 줄>」(190행)을 내고 그 형식이 상태 기록과 같다.
>       인터뷰에서는 추천과 선택지별 대가가 이미 앞 글에 한 줄로 나가고, 이 줄은 상태 기록이라 앞 글에서 통째로 뺄 수 없다.
>       204–205행은 「각 선택지의 `description` 은 «고르면 무엇이 달라지는가»를 담는다. 기계 검사는 없다」다 — 창 안의 자리는 이미 정해져 있고 집행만 없다.
>     touches: [P2, P3]
>     decides: [OQ4, OQ10, OQ3]
>   - id: RC11
>     path: "plugins/spec-distill/references/conductor-dispatch.md"
>     anchor: "지휘자는 배경을 먼저 쉬운 말로 쓰고 질문만 봐도 결정할 수 있게 묻는다"
>     line: 32
>     claim: >-
>       레포 안의 선례. 지휘자 규칙은 이미 「질문만 봐도 결정할 수 있게」와 「각 선택지 설명에 원문의 「고르면 무엇이 달라지나」 를 빠뜨리지 않는다」를 요구하고,
>       하위가 돌려보내는 요약 꼴도 「무엇을 정하나 · 고르면 무엇이 달라지나(그대로 두면 · 고치면) · 배경」(29행)이다. 같은 문장이
>       「지휘자 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓴다」고도 정한다 — 추천 이유를 일부러 선택지 밖에 두는 자리이고(옮긴 원문을 글자 그대로 지키려는 것),
>       P7 의 범위 목록에 지휘자는 없다. 이유를 창 안으로 옮기는 규칙이 정본 블록으로 들어가면 이 자리와 부딪히는지 정해야 한다.
>     touches: [P1, P7]
>     decides: [OQ4, OQ10]
>   - id: RC12
>     path: "docs/superpowers/interview/2026-11-15-present-tradeoffs-brief-interview.state.md"
>     anchor: "앞 글 0자인 질문 앞에는 전부 생각 블록이 있었다"
>     line: 238
>     claim: >-
>       본체 재측정: 「위」를 가리킨 질문 107개 중 앞 글 0자가 65개(236행), opus 계열 60개 중 42개 · fable 계열 47개 중 23개(237행),
>       그 65개 앞에는 전부 생각 블록이 있었다(238행). 이 꼴은 #75182 의 사용자 보고(실패한 기록 = tool_use > thinking > tool_use)와 같아
>       기록으로는 「안 썼다」와 「사라졌다」를 가를 수 없다. seed 29행의 손으로 연 사례는 질문 넷이 모두 「경고 4개 — 위에 적었다」였다.
>       261행은 이번 화면 확인에서 앞 글이 글 블록으로 남고 화면에도 보였다고 적는다 — 늘 나는 버그가 아니다. 앞 글을 기록으로 재는 방법은 믿을 수 없고,
>       질문 칸은 도구 입력이라 기록에 남는다.
>     touches: [P4]
>     decides: [OQ11]
>   - id: RC13
>     path: "docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.md"
>     anchor: "해결: 보였는데 놓침 — 라벨 표시의 강도가 핵심"
>     line: 195
>     claim: >-
>       지난 인터뷰의 원인 판정(OQ7, 사용자 발화 S8)은 「권고가 질문 창에 가려졌나, 보였는데 놓쳤나 — 보였는데 놓침」이었다. 앞 글이 보일 때도 그 안의 권고는
>       읽히지 않았다는 사용자 확정이다. D16(175행)은 그 위에서 표시만 라벨로 옮기고 이유를 위에 남겼고, 181행은 설명 칸 규칙을 그대로 둔 것이
>       「사용자가 따로 정한 것은 아니다」라고 적는다. 앞 글을 둘째 통로로 남겨도 읽히리라는 기대는 이 판정과 맞지 않는다.
>     touches: [P4, P1]
>     decides: [OQ4]
>   - id: RC14
>     path: "shared/tests/ask_recommendation.py"
>     anchor: "def required(kind, body)"
>     line: 109
>     claim: >-
>       지금 있는 질문 자리 검사는 종류별 리터럴(라벨 꼬리 · 지시 문장 · 「추천을 달지 않는다 —」 · 출처 꼬리 · 뗌 문장)이 문서의 그 범위에 있는지만 본다(109–127행).
>       질문 본문 · 설명 칸의 내용은 재지 않는다. 이 장치를 넓혀 잴 수 있는 것은 「그 자리에 새 지시 문장이나 설명 리터럴이 있다」까지이고,
>       실행 중 실제로 뜬 질문의 내용은 이 검사의 도달 밖이다 — 고쳐졌는지는 세션 기록의 질문 입력(question · description)을 재는 다른 방법이 필요하다.
>     touches: []
>     decides: [OQ3, OQ11]
>   - id: RC15
>     path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
>     anchor: "재비판이 심각도를 낮춘 지적이 <n>개 있다(위 「낮춘 지적」 절)"
>     line: 713
>     claim: >-
>       코드 리뷰의 낮춘 지적 게이트는 질문 본문이 「위 「낮춘 지적」 절」로 질문 밖 글을 가리키고(708–709행 「위 원문 표면화로 이미 보였다」),
>       설명 칸에는 이미 지적별 「낮춘 이유를 쉬운 말 한 줄로」를 싣는다(715행). 추천은 일부러 비운다(720행). 코드 리뷰 쪽은 설명 칸에 항목별 한 줄을 싣는 꼴이
>       이미 있고, 고칠 것은 「위」를 가리키는 본문이다 — 지적이 4개 이상이면 선택지가 「전부 되올린다 / 그대로 둔다」 둘로 접혀(716행) 항목별 내용이 창에 설 자리가 없다.
>     touches: [P7, P4, P6]
>     decides: [OQ4]
> ```
>
> ## 확인하지 못한 것
>
> - **Apple HIG Alerts** — 페이지 본문이 열리지 않아 싣지 않았습니다. 조사 3 의 인용은 여전히 본체 미확인입니다.
> - **changelog** — 맨 위 다섯 판만 읽었습니다. 2.1.318 아래에 고친 줄이 있는지는 보지 못했습니다.
> - **연구 넷** (Bansal · Vasconcelos · Buçinca · 공간 근접) — 초록을 검색 요약으로만 읽어 `uncertain` 으로 두었습니다.
> - **지금 판의 질문 창 길이 한계** — 어느 표면에서도 화면으로 재지 않았습니다. #29125 · #67113 이 2.1.303 이후에도 나는지 모릅니다.
> - **읽지 않은 레포 자리** — spec-review 702행(③ 후속 갈래의 「이유는 질문 위 글에」) · artifact-critique · e2e.md 는 조사 2 의 주장을 그대로 믿지 않고 `repo_claims` 에서 뺐습니다.
>
> ## 읽은 파일
>
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/docs/superpowers/interview/2026-11-15-present-tradeoffs-interview.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/docs/superpowers/interview/2026-11-15-present-tradeoffs-brief-interview.state.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.md (166–201행)
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md (30–99행 · AC3 줄)
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/style/plain-language.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/docreview/references/reviewing-document.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/docreview/scripts/docreview_state.py (`_one` · `_rg_decide`)
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/tests/test_plain_language_block.sh
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/tests/ask_recommendation.py (100–131행)
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/references/proceed-gate.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/references/conductor-dispatch.md (24–37행)
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/skills/pm-interview/SKILL.md (174–209행)
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/skills/pm-interview/references/finishing.md (466–541행)
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/skills/spec-review/SKILL.md (543–578행)
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/agents/doc-critic.md (54–73행)
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/tests/test_plain_gate_templates.sh (120–156행)
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/quality-gates/skills/quality-pipeline/SKILL.md (705–722행)
>
> Sources:
> - [anthropics/claude-code #75182](https://github.com/anthropics/claude-code/issues/75182)
> - [anthropics/claude-code #77242](https://github.com/anthropics/claude-code/issues/77242)
> - [anthropics/claude-code #29125](https://github.com/anthropics/claude-code/issues/29125)
> - [anthropics/claude-code #67113](https://github.com/anthropics/claude-code/issues/67113)
> - [anthropics/claude-code #45384](https://github.com/anthropics/claude-code/issues/45384)
> - [Claude Code CHANGELOG.md](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
> - [Handle approvals and user input (Agent SDK)](https://code.claude.com/docs/en/agent-sdk/user-input)
> - [Microsoft — Command Links](https://learn.microsoft.com/en-us/windows/win32/uxguide/ctrl-command-links)
> - [Microsoft — Dialog Boxes](https://learn.microsoft.com/en-us/windows/win32/uxguide/win-dialog-box)
> - [W3C — Clearly State the Results and Disadvantages of Actions, Options, and Selections](https://www.w3.org/WAI/WCAG2/supplemental/patterns/o7p03-supported-choice)
> - [MCP spec — Elicitation](https://modelcontextprotocol.io/specification/2025-06-18/client/elicitation)
> - [gstack — generate-ask-user-format.ts](https://raw.githubusercontent.com/garrytan/gstack/main/scripts/resolvers/preamble/generate-ask-user-format.ts)
> - [Bansal et al. 2021 — Does the Whole Exceed its Parts?](https://arxiv.org/abs/2006.14779)
> - [Vasconcelos et al. 2023 — Explanations Can Reduce Overreliance](https://arxiv.org/abs/2212.06823)
> - [Buçinca et al. 2021 — To Trust or to Think](https://www.eecs.harvard.edu/~kgajos/papers/2021/bucinca2021trust.shtml)
> - [Anthropic — Claude Code auto mode](https://www.anthropic.com/engineering/claude-code-auto-mode)
> - [Beege et al. 2019 — spatial contiguity](https://doi.org/10.3389/feduc.2019.00086)

**게이트-전 확인** — repo_claims: 15 중 확인 15(RC74–RC88 — 아래 §5 의 확인 줄) · 부착 주장: 13건 확인(#75182→P4 · changelog→P4 · Microsoft command link→P2 · P3 · P5 · Microsoft dialog→P1 · P6 · W3C→P1 · P2 · MCP→P1 · gstack→P2 · #77242→P1 · #29125→P3 · #67113→P3 · Bansal→P2 · Vasconcelos→P3 · 공간 근접→P1 — 대조는 「그 주장이 그 전제에 닿는가」이고 출처를 본체가 다시 읽은 것은 #75182 하나다) · 재검토 자격: 사유 없음 — 확인된 전제 충돌 0건 · 근거 17 중 부착 13

**사용자 선택** — 보완 (S10)

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-11-15) — web: enabled

## 5. 프로세스 로그

- round 1: (경로 a — 레포 · 웹에서 확인) 사용자가 본 리뷰 뒤 질문의 모양은 규칙을 어긴 것이 아니라 규칙대로 나온 것이다 — 문서 리뷰 셋(설계문서 · brief · seed)이 함께 쓰는 엔진 절차서가 「질문 본문에는 결정 하나와 『경고 N개 — 위에 적었다』 한 줄만
- round 2: (경로 a) S2 뒤에 이 세션 기록을 열어 보니 확인용 문장이 든 글이 글 블록(1,370자 · 모델 claude-fable-5-2)으로 남아 있었다 — 이번 한 번은 썼고, 기록에 남았고, 화면에도 보였다. 버그(#75182)는 늘 나는 것이 아니고, 지난 측정의 
- round 3: S6 이 S3 의 범위를 넓혔다(새 발화가 이긴다) — 리뷰 뒤 결정 질문은 문서 리뷰 셋과 코드 리뷰(quality-gates)까지다. S7 로 지난 확정 D16(추천의 이유는 질문 위 글에)을 사용자 동의로 다시 정했다 — 추천의 이유와 대가는 질문 안에 둔다. S
- round 4: S10 으로 방향이 정해졌다(ST1 보완) — 질문 창이 정본 통로다(어느 질문도 앞 글이 보여야만 고를 수 있게 짜지 않는다) · 설명은 한 줄(길어도 세 줄) · 앞 글은 덤으로 남긴다 · 추천이 없는 질문과 이름만으로 뜻이 서는 선택지에는 얻음 · 내줌을 억지로 
- round 5: S11–S14 로 넷이 정해졌다 — 경고 목록은 첫 질문 본문에 한 줄씩 싣는다 · 질문 밖 「권하는 글」 자리 셋(분해 권고 · 다음 단계 제안 이유 · 지휘자 의견)에 대가 한 구절을 붙인다 · 고쳐졌는지는 세션 기록 재측정과 실제 화면 확인 둘 다로 본다 · 실패
- round 6: [spec-distill] 포화 판정 1/5: 아직 — 빈 곳 4개, 다음: 경고 목록을 질문 밖으로 뺀 지난 변경(5.1.0)의 이유를 git 기록에서 찾기 · 조사 호출 5/60
- round 7: 화면 시험(S19 · S20): 깔린 판 2.1.325 에서 한 호출에 질문 둘 · 선택지 넷 · 설명마다 약 180자(세 줄쯤) · 본문에 경고 세 줄을 실은 꼴이 끝까지 다 보였다 — 설명 끝말 넷과 「◆본문 끝」 표시 모두. 한 번의 측정이고, 더 긴 글(「고치면
- round 8: [spec-distill] 포화 판정 2/5: 아직 — 빈 곳 5개, 다음: 화면 시험에서 재지 않은 것(300자 이상 설명 · 좁은 창 · 기타 칸)을 같은 시험 질문으로 재기 · 조사 호출 5/60
- round 9: S26 으로 빈 곳 다섯을 조사한다. 레포 조사 둘(조사 11 · 12 — 요약이 뜻을 바꾸지 않게 하는 장치 · 접힘 규칙과 문면 락)을 한 묶음으로 띄웠고 결과를 기다린다. 서로 기대지 않아 함께 보냈다.
- round 10: 레포 조사 둘(조사 11 · 12)이 도착해 본체가 원문과 대조했다(RC92–RC135 — 확인 43 · 미확인 1).
- round 11: [spec-distill] 포화 판정 3/5: 아직 — 빈 곳 3개, 다음: 추천 선택지 설명을 자리 종류별로 갈라 다시 보기 · 조사 호출 7/60
- round 12: [spec-distill] 포화 판정 4/5: 아직 — 빈 곳 5개, 다음: 공통 규칙의 새 문면 후보를 실제로 적어 길이 여유를 다시 재기 · 조사 호출 7/60
- round 13: S35 로 조사를 닫았다(포화 판정 4: 사용자 판단 포화 — 반복 빈 곳). 분해 판단의 신호 셋: 따로 승인할 수 있는 덩어리 5(공통 규칙 한 줄과 사본 ← S7 · OQ18 / 문서 리뷰 뒤 질문 규칙 ← S9 · S24 · S25 · OQ19 / 코드 리뷰 질

- 대체됨: 인터뷰 규약의 «추천 · 트레이드오프» 줄은 상태 파일에만 적는 줄이다 → 화면 출력에도 같은 형식으로 나가는 줄이다(pm-interview/SKILL.md 180행 「사용자에게 보이는 출력과 state 본문 기록이 같은 형식이다」) (조사 1)
- 대체됨: 질문 창이 앞 글을 가릴 수 있다는 근거는 질문 도구 설명서의 말뿐이다 → 1차 출처의 버그 보고가 있고(#75182 · #67475) 레포의 지난 인터뷰(2026-10-27)도 이미 확인해 적어 두었다 (조사 1 · 조사 4)
- 대체됨: 코드 리뷰에는 질문 밖 글을 가리키는 질문이 없다 → 낱말이 달라 측정에 안 걸렸을 뿐이고 「위 「낮춘 지적」 절」 · 「분류표의 「적용」 항목」으로 질문 밖 글을 가리킨다 (조사 1 · 조사 2)

- 확인 RC1 — 확인 — shared/style/plain-language.md#질문 하나에 결정 하나. 선택지 이름은 짧은 쉬운 말로 — 주장과 일치(6행 전문 대조 · 「대가」 · 「트레이드오프」 낱말 없음)
- 확인 RC2 — 확인 — shared/style/plain-language.md#아래 절차가 출력 형식·원문 보존·분량을 따로 정한 자리에서는 그 절차를 따른다 — 주장과 일치(3행)
- 확인 RC3 — 확인 — shared/tests/plain_language_block.py#def check(root, rel, canon) — check() 는 주장대로 넷만 잰다. 짝 .sh 의 문장 실재 검사는 읽지 않았다
- 확인 RC4 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#· 트레이드오프: <선택지별 한 줄> — 주장과 일치(180 · 190 · 204–205행 · 「트레이드오프」 낱말은 skills · references · shared 에서 이 줄과 리뷰 프로필 정규식 한 줄뿐)
- 확인 RC5 — 확인 — shared/docreview/references/reviewing-document.md#8. **게이트** — 주장과 일치(27–40행 · 이 파일에 description 낱말 0개)
- 확인 RC6 — 확인 — shared/docreview/references/reviewing-document.md#**`AskUserQuestion` 라벨의 항목별 내용** — 주장과 일치(42행 · 86행)
- 확인 RC7 — 확인 — shared/docreview/scripts/docreview_state.py#def _rg_decide(st, g, fid) — 주장과 일치(2310–2315행의 다섯 줄 · _CHOICE_LABEL 2137행 · 추천 줄 없음)
- 확인 RC8 — 확인 — plugins/spec-distill/skills/spec-review/SKILL.md#승인 게이트 질문에는 「경고 N개 — 위에 적었다」 — 555 · 661 · 827–828행 일치. 2단계 옵션 표(688–695행)는 읽지 않았다
- 확인 RC9 — 확인 — plugins/spec-distill/skills/spec-review/SKILL.md#**③ 의 갈래와 로드맵 에픽.** — 702행 「이유는 질문 위 글에 한 줄로 쓴다」 일치. 그 밖 라벨 줄(301 · 635 · 766행)은 읽지 않았다
- 확인 RC10 — 확인 — plugins/spec-distill/skills/reviewing-brief/SKILL.md### 게이트 — 604 · 739–740행 일치
- 확인 RC11 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#B-2 — 497–499 · 513–519 · 536행 일치
- 확인 RC12 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#신호 셋과 권고를 위에 적었다 — 33 · 38행 일치. (b)(c)(d) 의 줄(64 · 266 · 298 · 329 · 402행)은 읽지 않았다
- 확인 RC13 — 확인 — plugins/spec-distill/references/proceed-gate.md### Step B — 단일 `AskUserQuestion` — 주장과 일치(28–60행)
- 확인 RC14 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#### 게이트 — 처분은 사용자가, 편집은 처분 뒤에 — 784 · 934–935 · 1094행 일치. 800 · 1127–1134행은 읽지 않았다
- 확인 RC15 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#### 확인 질문 — 라운드마다 하나 — 246행 일치 · 워크트리 질문 펜스 일치
- 확인 RC16 — 확인 — plugins/spec-distill/references/redecompose.md#다시 나눌 표와 영향을 위에 적었다. 어떻게 할까? — 주장과 일치(57–62행)
- 확인 RC17 — 확인 — plugins/spec-distill/references/conducting.md#### 2. 사람 몫 모으기 — 27 · 40행 일치. 29 · 102–114행은 읽지 않았다
- 확인 RC18 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#지휘자는 배경을 먼저 쉬운 말로 쓰고 질문만 봐도 결정할 수 있게 묻는다 — 32행 · relay-checker.md 34행 일치
- 확인 RC19 — 확인 — shared/tests/ask_recommendation.py#def required(kind, body) — 주장과 일치(109–127행 — 종류별 글자 실재만 본다 · 본문 · 설명 내용은 재지 않는다)
- 확인 RC20 — 확인 — shared/tests/test_ask_recommendation.sh## 한계 둘: — 일치. 목록 줄 수는 wc 로 168
- 확인 RC21 — 확인 — shared/tests/test_docreview_round_gate_split.sh#**이 축의 한계** — 31–34행 일치
- 확인 RC22 — 확인 — plugins/spec-distill/tests/test_plain_gate_templates.sh## ⑬ 질문 본문에는 결정과 상태 한 줄만 — 133 · 150행 일치. test_brief_review_entry.sh 는 읽지 않았다
- 확인 RC23 — 확인 — plugins/spec-distill/tests/test_conducting_interview_stage.sh#고르면 무엇이 달라지는가 — 487 · 498행 일치
- 확인 RC24 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#남은 지적이 있다(<summary>). 어떻게 할까? — 851 · 854 · 861 · 873행 일치
- 확인 RC25 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#**낮춘 지적 게이트 (표면화 뒤 · 라우팅 앞).** — 713–720행 일치. 범위 모드 · 수정 실패 질문은 읽지 않았다
- 확인 RC26 — 미확인 — plugins/quality-gates/references/e2e.md#증거표와 판정안을 보인 뒤 — 102행만 확인했고 §2 시나리오 질문의 설명 규칙(41–57행)은 읽지 않았다
- 확인 RC27 — 미확인 — plugins/quality-gates/skills/artifact-critique/SKILL.md#### E3 — 범위 고르기 · 규모 공시 — 189행(비평자 수 질문의 대가 문장)만 확인했다
- 확인 RC28 — 확인 — plugins/quality-gates/tests/test_plain_qg_templates.sh#grep -c .)" "6" — 51 · 64 · 66 · 167행 일치
- 확인 RC29 — 미확인 — shared/tests/fixtures/ask-sites.tsv## 게이트 · 리뷰 결정 질문 (Task 4) — 여러 자리를 모은 집계 주장이라 자리마다 대조하지 않았다
- 확인 RC30 — 확인 — shared/style/plain-language.md#이유는 질문 위 글에 — 6행 · proceed-gate.md 44행 일치(두 규칙이 같은 통로에 기댄다는 데까지)
- 확인 RC31 — 확인 — docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.state.md#75182 — 429 · 478 · 485행 · brief 216행 일치
- 확인 RC32 — 확인 — plugins/spec-distill/dependencies.md#| claude-code | 2.1.303 | 2026-10-22 | 기록 | — 19행 일치
- 확인 RC33 — 확인 — plugins/spec-distill/references/proceed-gate.md#질문 본문에는 결정 하나와 「경고 N개 — 위에 적었다」 — 44행과 일곱 자리 일치
- 확인 RC34 — 확인 — shared/docreview/references/reviewing-document.md#렌더 첫 줄(상태와 경고)은 첫 호출 **앞 글**에 한 번 쓴다 — 30 · 42행 일치 · description 낱말 0개
- 확인 RC35 — 확인 — shared/docreview/scripts/docreview_state.py#_rg_decide — 2311–2315행 일치
- 확인 RC36 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#옵션 description 에 싣지 않습니다 — 497 · 38행 일치
- 확인 RC37 — 확인 — shared/tests/test_ask_recommendation.sh#모델이 즉석에서 만드는 질문은 정본 규칙만이 집행한다 — 9행 · ask_recommendation.py required() 일치
- 확인 RC38 — 확인 — plugins/spec-distill/tests/test_plain_gate_templates.sh#질문 본문 — 133행 일치 · 쉬운 말 블록 사본 10개 확인. test_plain_language_block.sh 28–32행은 읽지 않았다
- 확인 RC39 — 확인 — docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.md#**D16** — 175 · 181 · 195행 일치
- 확인 RC40 — 확인 — docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md### Anti-goals — 47–54 · 59행 · brief 176행(C17) 일치
- 확인 RC41 — 확인 — docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md#«gh-askuserquestion-hides-text» — 289행 일치
- 확인 RC42 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#OQ<n>: <무엇을 정하는지 한 줄> · 추천: — 180 · 190 · 204–205행 일치
- 확인 RC43 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#지휘자는 배경을 먼저 쉬운 말로 쓰고 질문만 봐도 결정할 수 있게 묻는다 — 32행 일치. 29행은 읽지 않았다
- 확인 RC44 — 확인 — shared/style/plain-language.md#부른 skill 이 메시지 모양을 정한 대화(예: brainstorming)에서는 그 skill 을 따르고 — 3행 일치
- 확인 RC45 — 확인 — docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.md#**D13** — 172 · 173행 일치
- 확인 RC46 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#**다음 세션 줄 — ①/② 공통** — 551 · 553행 일치
- 확인 RC47 — 확인 — plugins/spec-distill/references/conducting.md#brief · 설계 · 계획처럼 방향을 정하는 단계면 특히 그렇다 — 28행 일치(plugins 에서 「방향을 정하는 단계」 1곳 · 「방향을 정하는 자리」 0곳)
- 확인 RC48 — 확인 — shared/tests/fixtures/ask-sites.tsv## 게이트 · 리뷰 결정 질문 (Task 4) — 비움 행 87 · 88 · 91 · 120 · 124행과 request-framing 934 · 939행 · quality-pipeline 720 · 873행 일치
- 확인 RC49 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#이어서 권고 한 줄 — 33 · 536행 · proceed-gate.md 56행 일치. 문장 권고 자리를 모은 목록이 없다는 것은 찾지 못한 것이다
- 확인 RC50 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#재비판이 심각도를 낮춘 지적이 <n>개 있다(위 「낮춘 지적」 절) — 713 · 851 · 861행 일치 · 측정 낱말에 걸리지 않음을 측정 스크립트로 확인
- 확인 RC51 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#### 게이트 — 처분은 사용자가, 편집은 처분 뒤에 — 784 · 1094행 · reviewing-brief 11행 일치. 「리뷰 · 확정 게이트에서 왔을 공산」은 추정 그대로다
- 확인 RC52 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#{label: "만들고 시작 (권장)", description: — plugins 의 .md 에서 preview 를 질문 칸으로 쓰라는 지시를 찾지 못했다 · 세션 기록의 질문 855개 중 preview 칸이 있는 것은 1개
- 확인 RC53 — 확인 — plugins/spec-distill/dependencies.md#| claude-code | 2.1.303 | 2026-10-22 | 기록 | — 네 플러그인의 dependencies.md 모두 2.1.303 · superpowers 7.0.0(17행) 일치
- 확인 RC54 — 확인 — shared/style/plain-language.md#질문 하나에 결정 하나. 선택지 이름은 짧은 쉬운 말로 — 6행 일치(RC1 과 같은 자리)
- 확인 RC55 — 확인 — shared/style/plain-language.md#부른 skill 이 메시지 모양을 정한 대화(예: brainstorming)에서는 — 3행 일치(RC2 와 같은 자리)
- 확인 RC56 — 확인 — plugins/spec-distill/references/proceed-gate.md### Step B — 단일 `AskUserQuestion` — 39–45행 일치
- 확인 RC57 — 확인 — shared/docreview/references/reviewing-document.md#「경고 N개 — 위에 적었다」 한 줄만 둔다. — 열 자리와 CHANGELOG 699행 일치
- 확인 RC58 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#신호 셋과 권고를 위에 적었다 — 38행 · redecompose.md 57행 일치
- 확인 RC59 — 확인 — shared/tests/test_ask_recommendation.sh## 한계 둘: — 8–10행 · required() 일치
- 확인 RC60 — 확인 — plugins/project-init/hooks/hooks.json#"PostToolUse": [ — plugins/*/hooks 에서 AskUserQuestion · PreToolUse 0건 · 이벤트 키는 project-init 의 PostToolUse 하나
- 확인 RC61 — 확인 — plugins/spec-distill/agents/integration-reviewer.md#with a conflict preview, and earlier — plugins 의 .md 에서 preview 낱말은 이 한 줄
- 확인 RC62 — 확인 — shared/docreview/references/reviewing-document.md#렌더의 「고치면」 줄이 전문을 이미 내므로 라벨은 그 줄을 가리키는 손잡이다 — 27–42행 일치(지적별 줄을 사용자 글로 옮기라는 문장 없음)
- 확인 RC63 — 확인 — shared/docreview/scripts/docreview_state.py#def _one — 2223–2225행은 공백만 접고 길이를 자르지 않는다 · 2311–2312행 자리표 일치
- 확인 RC64 — 확인 — shared/style/plain-language.md#스크립트·subagent 가 낸 원문은 고치지 않는다 — 블록 9행 · 6행 · 3행 일치
- 확인 RC65 — 확인 — plugins/spec-distill/tests/test_plain_gate_templates.sh#⑬ 질문 본문에는 결정과 상태 한 줄만 — 100–113행 인접 순서 락 · 133–142행 양의 락 · 143–147행 부재 락 일치
- 확인 RC66 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#옵션 description 에 싣지 않습니다 — 497행 · 테스트 150–151행 일치
- 확인 RC67 — 확인 — plugins/spec-distill/agents/relay-checker.md#지휘자 의견이 선택지 설명 안으로 들어갔으면 어긋남이다 — 34 · 37행 일치
- 확인 RC68 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#덩어리 본문(`render`)은 질문 텍스트에 줄임 없이 싣는다 — 934 · 935 · 939행 일치
- 확인 RC69 — 확인 — shared/tests/plain_language_block.py#블록 바이트가 정본(%s)과 다르다 — 52행 일치 · 사본 10개(quality-gates 둘 · plugin-audit · project-init 하나씩 · spec-distill 여섯)
- 확인 RC70 — 확인 — docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md### Anti-goals — 28 · 51–54 · 178행 일치
- 확인 RC71 — 확인 — shared/tests/test_ask_recommendation.sh#한계 둘 — 8–10 · 37행 일치
- 확인 RC72 — 확인 — plugins/spec-distill/references/proceed-gate.md### Step B — 단일 `AskUserQuestion` — 39–50 · 58행 일치
- 확인 RC73 — 확인 — plugins/spec-distill/CHANGELOG.md### [5.1.0] — 2026-10-09 — 696 · 699행 일치. 왜 질문 안에서 뺐는지의 이유는 그 항목에 없다
- 확인 RC74 — 확인 — shared/style/plain-language.md#설명에는 고르면 무엇이 달라지는지만 쓴다 — 6 · 9행 일치
- 확인 RC75 — 확인 — shared/tests/test_plain_language_block.sh#REC='추천이 있으면 그 선택지를 첫 자리에 두고 — 30 · 32행 일치
- 확인 RC76 — 확인 — docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md### Anti-goals — 30 · 47–54 · 68 · 178행 일치
- 확인 RC77 — 확인 — shared/docreview/scripts/docreview_state.py#def _rg_decide(st, g, fid) — 2310–2315 · 2223–2225행 일치
- 확인 RC78 — 확인 — plugins/spec-distill/agents/doc-critic.md#`summary`·`if_unfixed`·`replacement` 는 게이트에 그대로 실려 처음 보는 사람이 읽는다 — 60 · 68행 일치
- 확인 RC79 — 확인 — shared/docreview/references/reviewing-document.md#렌더 첫 줄(상태와 경고)은 첫 호출 **앞 글**에 한 번 쓴다 — 30 · 42행 일치. 지적별 줄을 옮기라는 문장이 없다는 것은 찾지 못한 것이다
- 확인 RC80 — 확인 — plugins/spec-distill/references/proceed-gate.md#질문 본문에는 결정 하나와 「경고 N개 — 위에 적었다」 — 39–45 · 56행 일치
- 확인 RC81 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#옵션 description 에 싣지 않습니다 — 497 · 513 · 536행 일치
- 확인 RC82 — 확인 — plugins/spec-distill/tests/test_plain_gate_templates.sh## ⑬ 질문 본문에는 결정과 상태 한 줄만 — 134–147 · 150행 일치
- 확인 RC83 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#사용자에게 보이는 출력과 state 본문 기록이 같은 형식이다 — 180 · 190 · 204–205행 일치
- 확인 RC84 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#지휘자는 배경을 먼저 쉬운 말로 쓰고 질문만 봐도 결정할 수 있게 묻는다 — 32행 일치. 29행은 읽지 않았다
- 확인 RC85 — 확인 — docs/superpowers/interview/2026-11-15-present-tradeoffs-brief-interview.state.md#앞 글 0자인 질문 앞에는 전부 생각 블록이 있었다 — 236–238행(이 인터뷰의 재측정 줄) 일치
- 확인 RC86 — 확인 — docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.md#해결: 보였는데 놓침 — 라벨 표시의 강도가 핵심 — 175 · 181 · 195행 일치
- 확인 RC87 — 확인 — shared/tests/ask_recommendation.py#def required(kind, body) — 109–127행 일치
- 확인 RC88 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#재비판이 심각도를 낮춘 지적이 <n>개 있다(위 「낮춘 지적」 절) — 707–720행 일치
- 확인 RC89 — 확인 — docs/superpowers/specs/2026-10-08-plain-language-output-design.md#3. 스킬이 시키는 질문·보고 틀: 질문 하나에 결정 하나만 담고, 경고 목록은 질문 앞으로 옮긴다. — 19 · 90–91 · 255–257행(목표 4 와 게이트 규칙) · 그 변경이 들어온 커밋은 2026-10-09 의 79d010ab · de05ce3a · dc4510d0 · 6b74f39b(커밋 본문에 이유 없음)
- 확인 RC90 — 확인 — plugins/spec-distill/agents/doc-critic.md#`summary`(한 문장) — 길이를 묶은 칸은 summary 뿐이다. if_unfixed · replacement 를 정하는 파일은 doc-critic · doc-critic-web · doc-recritic(spec-distill 과 shared/docreview 의 사본) · 프로필 둘 · codex 변환기이고 어디에도 그 두 칸의 길이 규칙이 없다
- 확인 RC91 — 확인 — tools/plain-language/token_boundary.py#압축 뒤 다시 붙는 skill 앞 5,000토큰의 경계가 규칙 블록 때문에 어디로 옮겼는지 잰다(근사) — 새 문면을 넣은 뒤에야 잴 수 있는 측정 도구다(근사식 · 실제 tokenizer 로 보정하지 않음). 부르는 테스트는 plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh 하나
- 확인 RC92 — 확인 — plugins/spec-distill/agents/relay-checker.md#볼 것 — 29–37행 일치 — 대조 항목은 다섯이고 요약의 뜻 · 설명의 내용을 대조하는 항목은 없다
- 확인 RC93 — 확인 — plugins/spec-distill/skills/epic-conductor/SKILL.md#7. 옮김 대조 — 190–192행 일치 — 에픽이 끝난 뒤의 사후 대조다
- 확인 RC94 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#사람 자리 — 32행 일치(문장 수를 지킨다 · 원문은 늘 붙인다 · 지휘자 의견은 선택지 밖)
- 확인 RC95 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#쓰기 권한 없는 agent 가 둘의 선택지 수 · 라벨 · 순서를 대조한다 — 32행 일치
- 확인 RC96 — 확인 — plugins/spec-distill/tests/test_conductor_dispatch_reference.sh#once — 12–26행 일치. test_epic_conductor_skill.sh · test_conducting_reference.sh 는 해당 줄만 확인했다
- 확인 RC97 — 확인 — plugins/spec-distill/agents/doc-critic.md#출력 형식 — 60 · 68행 일치
- 확인 RC98 — 확인 — plugins/spec-distill/references/docreview-profiles/brief.md#사용자가 결정할 질문 하나 — 21행 일치. 45행 · design-doc.md 61행은 앞서 확인했고 112행은 읽지 않았다
- 확인 RC99 — 확인 — plugins/spec-distill/agents/doc-recritic.md#같은 칸을 싣는다 — 58행 일치
- 확인 RC100 — 확인 — shared/codex/codex_findings_to_yaml.py#DOCREVIEW_KEYS — 73–75행 일치. codex 지시문과 그 테스트는 읽지 않았다
- 확인 RC101 — 확인 — shared/tests/test_docreview_agent_fields.sh#부분 문자열 — 11행 일치 · 테스트 폴더에 summary 한 문장 · 재진술 문구의 핀 0건
- 확인 RC102 — 미확인 — plugins/spec-distill/tests/test_overdesign_rubric.sh#field_mapping_line_of — 읽지 않았다
- 확인 RC103 — 확인 — shared/docreview/scripts/docreview_state.py#_rg_decide — 2295–2322 · 2223–2225행 일치. 결정이 아닌 행의 함수들은 읽지 않았다
- 확인 RC104 — 확인 — shared/docreview/scripts/docreview_route.py#부재를 summary 로 메우지 않는다 — 511–516행 일치. normalize · _classify_items 와 cases.sh 는 읽지 않았다
- 확인 RC105 — 확인 — shared/docreview/scripts/docreview_advice.py#def clip — 166–168행 · docreview_config.py 13행(summary_width 60) 일치
- 확인 RC106 — 확인 — shared/docreview/references/reviewing-document.md#`AskUserQuestion` 라벨의 항목별 내용 — 42행 일치
- 확인 RC107 — 확인 — shared/docreview/references/reviewing-document.md#8. **게이트** — 27–40 · 86행 · spec-review SKILL.md 509행 일치
- 확인 RC108 — 확인 — shared/style/plain-language.md#스크립트·subagent 가 낸 원문은 고치지 않는다 — 블록 9 · 3행 일치
- 확인 RC109 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#덩어리 본문(`render`)은 질문 텍스트에 줄임 없이 싣는다 — 935행 · steelman.md 94행 · quality-pipeline SKILL.md 560행 일치
- 확인 RC110 — 확인 — CLAUDE.md#Law 2 — Writer and Reviewer Must Never Share a Pass. — 일치
- 확인 RC111 — 확인 — CLAUDE.md#Persona 파일은 보안-민감 코드. — 78행 일치
- 확인 RC112 — 확인 — shared/tests/test_copy_of_contract.sh#copy-of 물리 사본 — 10–11행 · docreview_state.py 1110행(PUBLIC_FIELDS) 일치. 나머지 자리는 읽지 않았다
- 확인 RC113 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#낮춘 지적 게이트 (표면화 뒤 · 라우팅 앞). — 707–720행 일치
- 확인 RC114 — 확인 — docs/superpowers/plans/2026-10-19-r2a-plan3-qg-devices-range-persona.md#n ≥ 4: {label: "전부 되올린다" — 767–769행 일치. 상위 설계의 줄은 읽지 않았다
- 확인 RC115 — 확인 — docs/superpowers/specs/2026-10-25-qg-range-repairs-design.md#고를 지적이 넷 이상인 낮춘 지적 게이트 — 95행 · quality-gates CHANGELOG 28행 일치
- 확인 RC116 — 확인 — plugins/quality-gates/CHANGELOG.md#「낮춘 지적」 — 재비판이 낮춘 지적을 합성기가 — 146행 일치 · 「넷 이상」은 28행 한 곳
- 확인 RC117 — 확인 — plugins/quality-gates/scripts/synthesize_findings.py#_lowered_lines — 711–719행 일치
- 확인 RC118 — 확인 — plugins/quality-gates/tests/test_plain_qg_templates.sh#AC26: 낮춘 지적 게이트 질문이 한국어다 — 50–51행 일치
- 확인 RC119 — 확인 — plugins/quality-gates/tests/test_lowered_gate_wiring.sh#case_step45_gate — 49–61행 일치
- 확인 RC120 — 확인 — shared/tests/ask_recommendation.py#EMPTY =  — 26행 · required() 일치
- 확인 RC121 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#덩어리마다 질문 하나 — 933–935행 일치. 테스트 줄은 읽지 않았다
- 확인 RC122 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#기준 사본이 없으면 — 937–939행 일치
- 확인 RC123 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#덜어 낸 것이 1개 이상이면 — 1175–1176행 일치
- 확인 RC124 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#추천을 달지 않는다 — 낮춘 지적을 되올릴지는 — 720행 일치
- 확인 RC125 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#분류표의 적용/제외를 바꿀까요 — 861 · 873행 일치. 선택지 줄은 읽지 않았다
- 확인 RC126 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#지휘자 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓴다. — 32행 일치
- 확인 RC127 — 확인 — plugins/spec-distill/references/conducting.md#지휘 세션의 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓰고 — 102행 일치
- 확인 RC128 — 확인 — plugins/spec-distill/agents/relay-checker.md#지휘자 의견이 선택지 설명 안으로 들어갔으면 어긋남이다 — 34 · 37행 일치
- 확인 RC129 — 확인 — plugins/spec-distill/tests/test_conductor_dispatch_reference.sh#once '## 사람 자리' — 26행 · test_conducting_reference.sh 117–119행 · test_epic_conductor_skill.sh 81행 일치
- 확인 RC130 — 확인 — docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md#「지휘자 의견:」 줄에 어느 꼬리가 지휘자의 것인지와 이유를 쓴다(필수 — 115행 일치. 122행은 읽지 않았다
- 확인 RC131 — 확인 — shared/tests/test_plain_language_block.sh#REC='추천이 있으면 그 선택지를 첫 자리에 두고 — 30 · 32행 일치
- 확인 RC132 — 확인 — shared/tests/plain_language_block.py#if region != canon: — 51–52행 · 사본 10개 일치
- 확인 RC133 — 확인 — plugins/spec-distill/tests/test_review_handoff_order.sh#라벨에 「(권장)」을 달고 이유는 질문 위 글에 한 줄로 쓴다 — 191행 · saturation.md 35행 일치
- 확인 RC134 — 확인 — tools/plain-language/token_boundary.py#def main(argv=None): — 47–69행 일치(--base 필수 · 측정만 낸다)
- 확인 RC135 — 확인 — plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh#import token_boundary as tb — 202–210행 일치

### brief 리뷰 (reviewing-brief — 문서 리뷰 엔진)

- 라운드: 3 · 재리뷰 카운트 2 · 추가 라운드 0 — 승인 게이트 도달 사유: 상한 · 리뷰 완료: 예
- 결정: `## 8. 리뷰 결정` 13건(채택 9 · 기각 2 · 버림 2) · 열린 채 남은 항목 0건(ask · decide). 엔진 기록에는 3라운드에 채택한 결정 둘(abf668a4#r3.1 · abf668a4#r3.2)과 허가받은 수정 둘(997c959a#r3.1 · 9b7056b0#r3.1)이 「반영 확인 대기」로 남는다 — 문서에는 반영했고, 다음 라운드를 열지 않아 엔진이 관측하지 못했다. 1단계 선택: 추가 라운드 열지 않음(S48)
- codex: 1라운드 있음 · 2라운드 없음 — exit_nonzero(사용 한도) · 3라운드 있음(지적 하나는 형식 문제로 보류 — x1) · 웹: Claude doc-critic-web · codex 켜짐
- 냉독: gap 7건 (G3 3 — C5 · D10 · D19 가 요약에 없음 · G6 1 — 「전부 잠정」 표기와 「해결」 · 「확정 후보」 서술의 무게를 가르지 못함 · G7 3 — 「부착 13/17」 · RC 번호 · 범위 밖 skill 넷이 범위에 드는지를 읽지 못함). 입력은 frontmatter 항목 목록과 §6 을 뺀 본문
- degrade: critic:리뷰어 입력을 프롬프트에 싣지 못하고 워크트리 사본 경로로 넘김(세 라운드) · codex:2라운드 사용 한도로 실패 · codex:보류 x1(1라운드 edit_scope_multi_anchor · 3라운드 anchor/summary 부재) · readback:첫 번째는 경로로 넘겨 읽지 못함, 두 번째는 본문을 줄여 실음 · saturation:판정자에게 조사 원문을 파일 경로로 넘김

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S2** ☑ 선택 (round 1):
  > 보인다 — 질문 창 위에 확인용 문장이 든 글이 지금 보인다(화면 확인 질문)
- **S3** ☑ 선택 (round 1):
  > 문서 리뷰 셋 (권장) — 리뷰 뒤 결정 질문은 설계문서 · brief · seed 리뷰 셋을 고친다
- **S4** ☑ 선택 (round 1):
  > 넣는다 (권장) — 요청을 정리하는 단계(request-framing)의 질문에도 추천의 대가를 적는다
- **S5** ☑ 선택 (round 1):
  > 그 skill 에 맡긴다 (권장) — 설계 · 계획 대화(외부 skill)는 그 skill 에 맡긴다
- **S6** ☑ 선택 (round 2):
  > 이번에 넣는다 — 코드 리뷰(quality-gates)의 질문도 이번 범위에 넣는다(S3 의 범위를 넓힌다)
- **S7** ☑ 선택 (round 2):
  > 이유와 대가를 질문 안으로 (권장) — 지난 확정 「추천의 이유는 질문 위 글에」를 다시 정해, 추천의 이유와 대가를 질문 안으로 옮긴다
- **S8** ☑ 선택 (round 2):
  > 글자는 있었지만 내용이 없었다 — 설명 칸에 글은 있었는데 라벨을 되풀이하거나 너무 짧아서 없는 것과 같았다
- **S9** ☑ 선택 (round 2):
  > 무엇이 문제인지 (권장), 그대로 두면 어떻게 되는지 (권장), 고치면 무엇이 바뀌는지 (권장) — 문서 리뷰 뒤 결정 질문의 질문 창 안에 있어야 하는 것(리뷰어의 근거는 고르지 않음)
- **S10** ☑ 선택 (round 3):
  > 보완 (builder·orchestrator 추천) — 질문 창만 보고 고를 수 있게 하되 설명은 한 줄(길어도 세 줄)로 묶고 앞 글은 덤으로 남긴다. 추천 없는 질문에는 얻음 · 내줌을 억지로 채우지 않고 실행 중 검사 장치는 두지 않는다(ST1 방향 판정)
- **S11** ☑ 선택 (round 4):
  > 첫 질문 본문에 한 줄씩 (권장) — 경고 목록을 질문 앞 글에만 두지 않고 첫 질문 본문에 한 줄씩 싣는다
- **S12** ☑ 선택 (round 4):
  > 셋 모두에 대가 한 구절 (권장) — 질문 밖 「권하는 글」 자리 셋(분해 권고 한 줄 · 다음 단계 제안 이유 한 줄 · 지휘자 의견 한 줄)에 대가 한 구절을 붙인다
- **S13** ☑ 선택 (round 4):
  > 기록 재측정과 화면 확인 둘 다 (권장) — 고쳐졌는지는 세션 기록 재측정과 실제 화면 확인 둘 다로 확인한다
- **S14** ☑ 선택 (round 4):
  > 전부 위험으로 넘긴다 (권장) — 조사가 낸 실패 양식 일곱을 전부 설계가 다룰 위험으로 넘긴다
- **S15** ☑ 선택 (round 5):
  > 셋까지 싣고 나머지는 개수 (권장) — 경고가 많으면 첫 질문 본문에 셋까지 싣고 나머지는 개수로 알린다
- **S16** ☑ 선택 (round 5):
  > 이대로 받아들인다 (권장) — 바깥 선례의 취함 셋(추천 표시는 라벨에 · 이유와 결과는 선택지 아래 설명에 세 줄 이내 · 선택지마다 결과와 불이익을 그 옆에 · 모든 선택지를 같은 꼴로)과 피함 하나(질문 안에 근거와 풀이를 길게 싣는 형식)
- **S17** ☑ 선택 (round 5):
  > 있는 것을 옮겨 쓴다 (권장) — 리뷰어가 이미 쓰는 세 칸 · 인터뷰의 추천 · 트레이드오프 한 줄 형식 · 지휘자 규칙의 「질문만 봐도 결정할 수 있게」 문장을 옮겨 쓰고, 기존 규칙 셋을 함께 고친다
- **S18** ☑ 선택 (round 5):
  > 이대로 넘긴다 (권장) — 설계에 넘길 열린 질문 여섯을 이대로 넘긴다
- **S19** ☑ 선택 (round 6):
  > 첫째 선택지, 둘째 선택지, 셋째 선택지, 넷째 선택지 — 화면 시험에서 설명의 끝말까지 보인 선택지(넷 모두)
- **S20** ☑ 선택 (round 6):
  > 모두 보였다 — 화면 시험의 첫 질문 본문에서 경고 세 줄과 본문 끝 표시까지 모두 보였다
- **S21** 🗣 발화 (round 7):
  > 너무 긴게 좋은건 아니야
- **S22** 🗣 발화 (round 7):
  > 요즘 클로드는 서머리도 되는듯한데
- **S23** 🗣 발화 (round 7):
  > 본문에 서머리
- **S24** ☑ 선택 (round 7):
  > 맞다 — 전문은 앞 글에 (권장) — 리뷰 뒤 질문에는 리뷰어의 긴 글 대신 모델이 줄인 요약을 질문 본문에 싣고, 전문은 앞 글에 남긴다(「본문에 서머리」의 읽기 확인)
- **S25** ☑ 선택 (round 7):
  > 요약 한 줄로 (권장) — 경고도 질문에 요약 한 줄로 싣는다(S11 · S15 의 「셋까지 한 줄씩」을 바꾼다)
- **S26** ☑ 선택 (round 8):
  > 더 조사한다 — 포화 판정이 두 번 아직으로 나온 뒤 남은 빈 곳 다섯을 설계에 넘기지 않고 더 조사한다
- **S27** ☑ 선택 (round 9):
  > 첫째 (300자), 둘째 (300자), 셋째 (480자), 넷째 (480자) — 긴 글 화면 시험에서 설명의 끝말까지 보인 선택지(넷 모두)
- **S28** 🗣 발화 (round 9):
  > 1
- **S29** ☑ 선택 (round 10):
  > 남아 있었다 — 기타 칸에 답한 뒤에도 그 질문과 선택지 설명이 화면에 남아 있었다
- **S30** ☑ 선택 (round 10):
  > 설계에 넘긴다 (권장) — 레포 조사가 찾은 것 넷(대조 장치는 요약의 뜻을 보지 않는다 · 줄이기 규칙이 자리마다 다르다 · 접힘의 이유 기록 없음 · 문면을 잠근 테스트 목록)을 설계에 넘긴다
- **S31** ☑ 선택 (round 11):
  > 다 보인다 — 넷 묶음 화면 시험의 첫 질문에서 본문 끝 표시와 설명 셋의 끝말이 다 보였다
- **S32** ☑ 선택 (round 11):
  > 다 보인다 — 넷 묶음 화면 시험의 둘째 질문에서 본문 끝 표시와 설명 셋의 끝말이 다 보였다
- **S33** ☑ 선택 (round 11):
  > 다 보인다 — 넷 묶음 화면 시험의 셋째 질문(본문에 경고 한 줄)에서 본문 끝 표시와 설명 셋의 끝말이 다 보였다
- **S34** ☑ 선택 (round 11):
  > 줄였다 — 창을 가로 80 · 세로 24 쯤으로 줄인 채 답했다
- **S35** ☑ 선택 (round 12):
  > 포화로 보고 종료 (권장) — 네 번째 판정도 아직이고 같은 빈 곳이 되풀이된 뒤, 조사를 여기서 닫고 brief 로 간다. 빈 곳 다섯은 설계가 먼저 볼 것으로 넘긴다
- **S36** ☑ 선택 (round 13):
  > spec 하나로 (권장) — 이 일을 나누지 않고 설계문서 하나로 한다. 로드맵을 만들지 않는다
- **S37** ☑ 선택 (round 14):
  > 고친다 — 추천 있으면 전부 적는다 (권장) — 추천이 있는 질문에서는 모든 선택지에 얻음 · 내줌을 같은 꼴로 적고, 채우지 않아도 되는 것은 추천이 없는 질문뿐으로 한다(brief 리뷰 1라운드 결정)
- **S38** ☑ 선택 (round 14):
  > 고친다 — 열 곳 모두 적용으로 적는다 (권장) — 공통 규칙의 변경이 추천이 있는 질문에 한해 skill 열 곳 모두에 적용된다는 것을 범위 결정으로 brief 에 적는다(brief 리뷰 1라운드 결정)
- **S39** ☑ 선택 (round 14):
  > 고친다 — 모델 요약 유지, 위험을 적는다 (권장) — 리뷰어 글을 질문을 짜는 모델이 줄이는 방식은 두고, 원문은 고치지 않는다 규칙의 예외라는 것과 글을 쓴 쪽이 자기 글에 대한 지적을 줄인다는 위험을 brief 에 적는다(brief 리뷰 1라운드 결정)
- **S40** ☑ 선택 (round 14):
  > 고친다 — 문서 리뷰로 좁힌다 (권장) — 질문 창 안의 셋(문제 · 그대로 두면 · 고치면)은 문서 리뷰 뒤 질문의 것으로 적고, 코드 리뷰 질문에 무엇을 실을지는 열린 질문으로 둔다(brief 리뷰 1라운드 결정)
- **S41** ☑ 선택 (round 15):
  > 고친다 — 스크립트 줄 그대로 (권장) — 질문의 경고 줄은 스크립트 · 엔진이 낸 경고 줄을 그대로 쓰고, 스크립트가 낸 줄이 없는 자리만 모델이 쓴다(brief 리뷰 2라운드 결정)
- **S42** ☑ 선택 (round 15):
  > 고친다 — 지휘자 의견 줄만 (권장) — 분해 권고 · 다음 단계 제안 이유 두 자리는 그 질문 안의 얻음 · 내줌으로 갈음하고, 대가 구절을 따로 붙이는 자리는 지휘자 의견 줄 하나로 한다(brief 리뷰 2라운드 결정)
- **S43** ☑ 선택 (round 15):
  > 고친다 — 사라지지 않는 자리 (권장) — 리뷰어 글의 전문은 앞 글이 안 보여도 찾아갈 수 있는 자리에 남기고, 어디인지는 설계가 정한다(brief 리뷰 2라운드 결정)
- **S44** ☑ 선택 (round 15):
  > 닫는다 — 이미 들어가 있음 (권장) — 고르지 않은 넓힘을 기각 목록에 적으라는 지적은 그 줄이 이미 들어가 있어 닫는다(brief 리뷰 2라운드 결정)
- **S45** ☑ 선택 (round 15):
  > 닫고 표기를 바로잡는다 (권장) — 기각 목록의 「리뷰어 글을 그대로 싣는다」 줄을 다시 쓸 때 사용자가 따로 고른 것이 아니라고 표기를 바로잡는다(brief 리뷰 2라운드 결정)
- **S46** ☑ 선택 (round 16):
  > 고친다 — 규칙 한 문장으로 (권장) — 공통 규칙에 질문 없이 한쪽을 권하는 글에는 대가 한 구절을 붙인다는 문장을 넣어 자리 목록 없이 닿게 한다(brief 리뷰 3라운드 결정)
- **S47** ☑ 선택 (round 16):
  > 고친다 — 스크립트가 짧은 줄을 냄 (권장) — 스크립트가 질문용 짧은 경고 줄(개수와 종류 이름)을 따로 내게 하는 것을 범위에 넣고 질문은 그 줄을 그대로 싣는다. 경고 전체 목록은 리뷰어 글 전문과 같은 자리에 둔다(brief 리뷰 3라운드 결정)
- **S48** ☑ 선택 (round 16):
  > 열지 않음 (권장) — 재리뷰 상한에서 추가 라운드를 열지 않고 리뷰를 닫는다(brief 리뷰 3라운드 결정)
- **S49** ☑ 선택 (round 17):
  > 확정하고 /compact 후 brainstorming (권장) — 확정 후보 27개를 확정으로 바꿔 저장하고 다음 단계(설계)로 넘긴다

## 7. 확산 원자료

- «cc-issue-75182» — https://github.com/anthropics/claude-code/issues/75182 — 질문 앞 글이 화면과 기록에서 사라지는 버그 보고 — 본체가 2026-11-15 에 읽음
- «ms-command-links» — https://learn.microsoft.com/en-us/windows/win32/uxguide/ctrl-command-links — 선택 대화상자의 라벨 · 보조 설명 지침 — 본체가 2026-11-15 에 읽음
- «w3c-supported-choice» — https://www.w3.org/WAI/WCAG2/supplemental/patterns/o7p03-supported-choice — 선택지마다 결과와 불이익을 밝히라는 패턴 — 조사 보고
- «bansal-2021» — https://arxiv.org/abs/2006.14779 — 설명이 AI 추천의 수용을 옳고 그름과 무관하게 늘렸다는 연구 — 조사 보고
- «gstack-ask-format» — https://raw.githubusercontent.com/garrytan/gstack/main/scripts/resolvers/preamble/generate-ask-user-format.ts — 질문 안에 근거 · 장단점을 싣는 형식 — 조사 보고
- «cc-issue-45384» — https://github.com/anthropics/claude-code/issues/45384 — preview 칸이 있으면 설명이 안 그려진다는 보고 — 본체가 2026-11-15 에 읽음
- «cc-issue-29125» — https://github.com/anthropics/claude-code/issues/29125 — 긴 선택지 설명이 잘린다는 보고 — 조사 보고
- «superpowers-brainstorming» — https://raw.githubusercontent.com/obra/superpowers/main/skills/brainstorming/SKILL.md — 접근안마다 대가와 추천을 요구하는 문면 — 깔린 판 7.0.2 사본으로 본체 확인

## 8. 리뷰 결정

- D1.1 · r1 · adopt · a6484ced#r1.1 · "고친다 — 추천 있으면 전부 적는다 (권장)" — 「모든 선택지를 같은 꼴로 쓴다」와 「이름만으로 뜻이 서는 선택지에는 얻음 · 내줌을 채우지 않는다」가 함께 적혀 있어, 추천이 있는 질문에서 설명 없는 선택지를 허용하는지가 갈린다 — 어느 쪽이 앞서는지 정해야 한다 (D18 · Non-goal).
- D1.2 · r1 · adopt · abf668a4#r1.1 · "고친다 — 열 곳 모두 적용으로 적는다 (권장)" — 추천의 이유와 대가를 질문 안에 두도록 고치려는 공통 규칙은 skill 열 곳에 같은 글자로 복제돼 있어, 이번 범위에 넣지 않은 skill 의 추천 질문까지 함께 바뀐다 — 사용자가 고르지 않은 「질문 전부」 쪽으로 넓어지는 것을 받아들일지 정해야 한다 (D9 · K4).
- D1.3 · r1 · adopt · abf668a4#r1.2 · "고친다 — 모델 요약 유지, 위험을 적는다 (권장)" — 리뷰어가 쓴 지적과 경고를 질문을 짜는 모델이 줄여서 싣기로 했는데, 그 모델은 리뷰받는 글을 쓴 쪽이고 레포의 공통 규칙은 리뷰어 · 스크립트가 낸 글을 고쳐 쓰지 말라고 정해 두었다 — 줄이는 일을 질문을 짜는 모델에게 둘지, 리뷰어와 스크립트가 처음부터 짧게 쓰게 할지 정해야 한다 (D13 · D14 · OQ14).
- D1.4 · r1 · adopt · eb353eb4#r1.1 · "고친다 — 문서 리뷰로 좁힌다 (권장)" — 질문 창 안에 문제 · 그대로 두면 · 고치면 셋이 있어야 한다는 답은 문서 리뷰 뒤 질문을 두고 받은 것인데, 확정 줄과 목표가 코드 리뷰 질문까지 넓혀 적었다 — 코드 리뷰 질문에도 같은 셋을 요구할지 정해야 한다 (D11 · 셋째 Goal).
- D2.5 · r2 · adopt · abf668a4#r2.1 · "고친다 — 스크립트 줄 그대로 (권장)" — 경고를 질문에 요약 한 줄로 싣기로 했는데 그 한 줄을 누가 쓰는지가 없다 — 모델이 줄이면 「공시 줄은 스크립트가 낸 줄을 그대로 쓴다」는 공통 규칙의 예외가 하나 더 생기는데 brief 는 리뷰어 글의 예외만 적었다. 스크립트가 낸 줄을 그대로 실을지 모델이 줄일지 정해야 한다 (D14 · D23).
- D2.6 · r2 · adopt · abf668a4#r2.2 · "고친다 — 지휘자 의견 줄만 (권장)" — 질문 밖에서 권하는 글이라고 꼽은 자리 셋 가운데 둘(분해 권고 한 줄 · 다음 단계 제안 이유 한 줄)은 실제로는 추천이 붙는 질문의 바로 앞 글이다 — 추천의 이유와 대가는 질문 안으로 옮기기로 했으므로, 이 두 줄에 대가 구절을 따로 붙일지 그 질문의 얻음 · 내줌으로 갈음할지 정해야 한다 (D15 · D9 · D21).
- D2.7 · r2 · adopt · abf668a4#r2.3 · "고친다 — 사라지지 않는 자리 (권장)" — 리뷰어 글의 전문을 질문 앞 글에 남기기로 했는데, 리뷰 뒤 질문은 언제나 엔진 실행(도구 호출) 바로 뒤에 오고 버그 보고에서 앞 글이 사라진 것이 바로 그 순서다 — 줄이기 전 지적을 볼 자리를 앞 글로 둘지, 앞 글이 안 보여도 닿는 자리로 정할지 정해야 한다 (D13 · D23).
- D2.8 · r2 · reject · 218e3644#r2.1 · "닫는다 — 이미 들어가 있음 (권장)" — check-intent 거부 후 상향: 사용자가 고르지 않은 넓힘(devbrew 가 띄우는 질문 전부 · 모델이 권하는 글 전부)이 기각 목록에도 하지 않을 일 목록에도 없어, 범위의 바깥 경계가 brief 에 남지 않았다.
- D2.9 · r2 · reject · fc628aaf#r2.1 · "닫고 표기를 바로잡는다 (권장)" — check-intent 거부 후 상향: 기존 세 칸을 재사용한다는 선택을 리뷰어 글을 그대로 싣기로 했던 결정으로 바꾸어 기록했다.
- D2.10 · r2 · drop · 218e3644#r1.1 · "사용자가 2라운드 게이트에서 닫음(D2.8) — 그 줄은 1라운드 결정 D1.2 를 반영하며 기각 목록에 이미 들어갔다" — 사용자가 고르지 않은 넓힘(devbrew 가 띄우는 질문 전부 · 모델이 권하는 글 전부)이 기각 목록에도 하지 않을 일 목록에도 없어, 범위의 바깥 경계가 brief 에 남지 않았다.
- D2.11 · r2 · drop · fc628aaf#r1.1 · "사용자가 2라운드 게이트에서 닫음(D2.9) — 표기는 D2.7 때문에 그 줄을 다시 쓰면서 바로잡았다" — 기존 세 칸을 재사용한다는 선택을 리뷰어 글을 그대로 싣기로 했던 결정으로 바꾸어 기록했다.
- D3.12 · r3 · adopt · abf668a4#r3.1 · "고친다 — 규칙 한 문장으로 (권장)" — 목표는 질문 밖에서 한쪽을 권하는 글에도 대가를 적는 것인데, 확정된 것을 모으면 실제로 바뀌는 자리는 질문에 딸린 지휘자 의견 줄 하나뿐이고 질문이 따라오지 않는 권고 글에 닿는 규칙은 하나도 없다 — 그런 글을 규칙 한 문장으로 다룰지 이번 일에서 뺄지 정해야 한다 (둘째 Goal · C3 · D15).
- D3.13 · r3 · adopt · abf668a4#r3.2 · "고친다 — 스크립트가 짧은 줄을 냄 (권장)" — 경고를 질문에 「요약 한 줄」로 싣기로 한 것과 그 줄을 「스크립트가 낸 줄 그대로」 쓰기로 한 것이 경고가 여럿일 때 함께 서지 않는다 — 지금 엔진이 내는 경고 줄은 경고를 전부 이어 붙인 길이 제한 없는 줄이고 경고 통로도 하나가 아니다. 경고가 여럿일 때 질문에 무엇을 실을지 정해야 한다 (D14 · D25).
- docreview 계수 — spec-distill-59ec298a/2026-11-15-present-tradeoffs-brief-inter-e4d7aa71f12cc8cf r1: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — spec-distill-59ec298a/2026-11-15-present-tradeoffs-brief-inter-e4d7aa71f12cc8cf r2: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — spec-distill-59ec298a/2026-11-15-present-tradeoffs-brief-inter-e4d7aa71f12cc8cf r3: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0
