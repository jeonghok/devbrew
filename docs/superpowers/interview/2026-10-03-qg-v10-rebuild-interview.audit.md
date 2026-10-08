---
type: interview-audit
payload: 2026-10-03-qg-v10-rebuild-interview.md
created_at: 2026-10-03
session_id: c39a2e50-b7ba-4999-ac48-2101dd3242f1
source: spec-distill conducting-interview v0.57.0
---

# qg v10 재건 — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — 재구성 동의(네 면 + 뿌리 둘: 옛 모델·Claude Code 가정과 장치를 덧붙여 온 공정; goal: 얇은 v10 구성요소별 컷오버) (@S14) (재개방 1회 — S11·S12 qg 전체 재건으로 S3 문제정의가 「qg 가 지금 모델·Claude Code 에 맞지 않음」을 담지 못함)
- floor:landscape — closed — 외부 근거 W1~W7 처분대로(W2·W3·W5·W7 취함, W6·W1 중립, W4 피함) (@S4)
- floor:skepticism — closed — steelman ST3 판정 보완; 앞선 ST1·ST2 도 보완(@S5 · @S6) (@S13) (재개방 1회 — 새 의심 방향 qg 전체 재건, big-bang rewrite anti-pattern · S1 테스트 불변 확정과 충돌)
- floor:blind_spot — closed — premortem 처분: ①게시 payload·소음 ②e2e 감독·증거 신뢰는 결정으로, ③④는 위험 기록 (@S10)
- floor:open_questions — closed — 미해결 목록 OQ19~OQ25 확인 (@S24)
- derived:internal_research — closed — 내부(레포) 조사 축; RC1~RC84 전부 V1 확인, premortem·ST3 게이트에서 처분 (@S10 · @S13)
- derived:e2e_verdict_vocabulary — closed — 판정 어휘 3값·사유 닫힌 열거; fail=defect, 안 함·없음=공시 (@S20)
- derived:e2e_pipeline_placement — closed — 루프 끝 1회 + 실패 시 Fix-loop 재진입 (@S16)
- derived:e2e_actor_tool_surface — closed — 오케스트레이터가 걷고 판정, reviewer 는 감독하는 사람; S15 를 S17·S18 이 뒤집음; 1st-party /verify 위임 경계 흡수 (@S19)
- derived:unattended_publish_exposure — closed — secret-scan·kill switch 만 남기고 중단 실행 미게시, 코멘트 qg 결과는 판정 한 줄 (@S6 · @S21)
- derived:publish_apparatus_inventory — closed — 게시는 이전 장치를 걷는 대신 바닥부터 새로 (@S11)
- derived:review_diet_layer_and_intent_anchor — closed — 처방+적용 양쪽, 의도는 선언 우선 사슬, SUGGESTION 비차단 (@S7 · @S8 · @S9)
- derived:era_fit_census — closed — 구성요소별 한 줄 표(가정·1st-party 대체·교훈·처분)로 판별 (@S13)
- derived:invariant_carryover — closed — 옛 교훈은 새 설계 요구 목록으로 먼저 이관 (@S13)
- derived:consumer_migration_and_deprecation — closed — 즉시 제거 (@S23)
- derived:rebuild_scope_boundary — closed — critique·공유 docreview 엔진은 밖, 토픽 스코프·codex 는 안에서 처분 (@S22)
- derived:rebuild_unit_and_release — closed — v10 을 옆에 세워 구성요소별 독립 PR·릴리스 (@S13)

## 2. Budget

- 질문 라운드: 21 · agent dispatch: 6 · coverage-mapper 2 · codex 실호출: 0 (성공 0)

## 3. Steelman 원문

#### ST1 — e2e 에서 에이전트가 걷고 판정하고 사람이 감독한다

**dispatch 입력** — goal: S3(선택지 원문) + S1 확정 문장 · 전제: P1 e2e 는 에이전트가 걸어 판정(S1) · P2 사람 감독(틀리면 뒤집기)이 오류를 잡기에 충분(S1, 「충분」은 orchestrator 도출) · P3 기계 장치보다 에이전트 직접 걷기+사람 감독(S1) · P4 e2e 실패면 clean 불가(S1) · P5 경로는 qg 제안·사용자 선택(S1) · P6 에이전트 pass 는 clean 근거로 신뢰 가능(orchestrator 도출) · 제약: S1–S4 원문 전량 · trigger: landscape 모순 — WebTestBench default-correctness bias, 9.0.0 런타임 주장 회수·9.3.0 Law 2 예외 삭제

> builder 출력 verbatim:

```yaml
case_for_alternative:
  statement: "e2e 의 pass 는 고른 경로의 기대 상태마다 관측 증거(접근성 스냅숏 발췌 또는 browser_verify_* 도구 결과)가 판정 보고에 인용될 때만 성립한다. 증거가 빠진 기대 상태가 하나라도 있으면 그 e2e 는 「미확인」이 되어 not-certified(닫힌 사유 열거에 하나 추가)로 떨어진다. 판정 주체는 그대로 에이전트이고 사람은 감독하다 뒤집는다. 같은 판정 어휘 안에서 「걸을 것 없음(대상에 앱이 없음)」은 공시만 하고, 「걸었는데 증거가 없음」은 clean 을 막는다."
  strongest: "goal 은 /qg 결과가 「사람이 믿고 판단할 검증 보고」가 되는 것이다. 무증거 pass 는 그 보고를 가장 빠르게 거짓으로 만드는 경로다. WebTestBench 에서 에이전트는 실패 증거를 못 보면 pass 를 내고(recall 대부분 25% 이하) 사람 감독은 바로 그 누락형(omission) 오류에 약하다. 그래서 「에이전트 pass + 사람이 안 뒤집음」이 확인을 거치지 않은 채 승인이 된다. 기대 상태마다 증거를 요구하면 같은 에이전트 판정이 사람과 85.7% 일치하는 형태(WebJudge: 핵심 지점 + 핵심 스크린샷)가 되고, 감독자는 다시 걷지 않고 증거만 읽으면 된다(Claude Code best practices). 이것은 qg 가 이미 지키는 규칙(「관측 없음은 음성 결과가 아니다」, 「검증 못 하는 것을 검증했다고 말하지 않음」)을 e2e 에도 그대로 적용하는 것이라 새 장치가 아니다. 더하는 것은 verdict.py 의 닫힌 열거에 사유 하나뿐이다."
case_for_current:
  strongest: "사용자는 Phase 0 에서 「에이전트가 걷고 사람이 확정」을 명시적으로 버리고 「에이전트 판정·사람 감독」을 골랐다. goal 의 넷째 면(과잉 처방·무거운 장치)과 「기계장치보다 직접 걷기」 기준에서는 증거 형식 계약과 결정론적 계수가 덧붙일수록 goal 을 거스른다. WebTestBench 가 잰 것은 숨은 결함을 찾아내는 열린 탐색(앱 전체, 수십 턴, 체크리스트 커버리지 70% 미만)이다. 원안은 qg 가 경로를 제안하고 사용자가 고르거나 고친(P5) 좁은 확인 과제라 그 수치는 위험을 과대평가한다. 대화형 세션에서 감독자는 걷는 과정을 실시간으로 보므로 증거는 이미 화면에 있다. Anthropic 의 번들 /verify 와 best practices 도 에이전트가 실행 중인 앱을 직접 구동해 확인하는 모양을 기본으로 둔다. 또한 fail → clean 불가(P4)가 이미 강한 쪽의 비대칭을 걸어 둔다."
premise_refutation:
  hits: [P2, P6]
  why: "P2 — https://arxiv.org/abs/2109.05067 (Green) 은 사람 감독 정책에 대해 「people are unable to perform the desired oversight functions」라 하고, 그런 정책이 결함 있는 알고리즘을 정당화만 한다고 결론낸다. https://thedecisionlab.com/biases/automation-bias (Mosier & Skitka) 에서 자동화 보조를 받은 집단은 시스템이 경고하지 않은 것을 놓쳐(omission error) 정확도가 59%였고, 보조 없는 집단은 97%였다. 이것이 P2 의 「사람의 감독(틀리면 뒤집기)이 에이전트 판정의 오류를 잡는 데 충분하다」와 정면으로 충돌한다. 에이전트의 지배적 오류가 누락형(무증거 pass, 아래 WebTestBench)이고, 「틀리면 뒤집기」는 감독자가 «없는 것»을 알아채야만 작동하는데 그것이 바로 자동화 편향의 누락 오류 영역이다. / P6 — https://arxiv.org/html/2603.25226v1 (WebTestBench) 는 「models default to a pass judgment when no explicit evidence is observed」라 하고 F1 은 전 모델 30% 미만, recall 은 대부분 25% 이하다. 이것이 P6 의 「에이전트의 pass 판정은 clean 의 근거로 쓸 만큼 신뢰할 수 있다」와 충돌한다. 리포 안에서도 충돌한다. plugins/quality-gates/CHANGELOG.md [9.0.0] Changed 「이상 관측 없음은 음성 결과가 아니다」와 docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md §6.5.3 「신뢰도 하한은 「검증 못 하는 것을 검증했다고 말하지 않음」으로 지켜진다」에 따라, 증거 없는 pass 를 clean 의 근거로 쓰면 qg 가 스스로 세운 하한을 깬다. 다만 반증되는 것은 P6 의 무조건형이다. 증거에 묶인 pass 는 https://arxiv.org/pdf/2504.01382 (WebJudge 85.7% 일치) 가 지지한다."
premise_list_challenge: "결함이 넷 있다. ① P6 은 orchestrator 가 도출한 전제인데 「증거 있는 pass」와 「증거 없는 pass」를 한 문장에 접는다. 그래서 목록에는 pass 가 무엇으로 성립하는가(증거 하한)에 대한 전제가 빠져 있다. 반증은 이 빠진 자리를 겨냥한다. ② P2 의 「충분하다」는 사용자 원문(「사람 감독하면 괜찮겠지」, 「감독하다 틀리면 뒤집는다」)을 넘어선 도출이다. 사용자가 고른 것은 감독의 «형태»이지 그 형태가 충분하다는 주장이 아니다. 「사람은 에이전트가 내놓은 증거를 보고 뒤집을 수 있다」로 고쳐 쓰면 사용자 선택과 반증 근거가 함께 선다. ③ 판정하는 «에이전트»가 누구인지에 대한 전제가 없다. qg 오케스트레이터는 Retry 에서 직접 Edit 하는 writer 다(plugins/quality-gates/skills/quality-pipeline/SKILL.md, Fix-loop decision 「I will Edit the files in this turn」). 그 오케스트레이터가 수정 뒤 e2e 를 걷고 pass 를 내면 CLAUDE.md Law 2 「코드를 쓴 턴은 그 코드를 승인할 수 없음」에 닿는다. 첫 iteration(아직 쓰기 전)과 Retry 뒤 iteration 이 다른 사실이라 OQ3·OQ4 가 함께 정해야 한다. ④ 앱을 부팅하는 일은 리뷰 대상 저장소의 코드를 호스트 권한으로 돌리는 일이다. 차등 테스트는 이를 보안 컨트롤 kill switch 로 다루는데(SKILL.md Kill switch 절), e2e 에 대한 같은 전제가 목록에 없다. 참고로 대안 (b)(pass/fail 을 사람이 확정)는 Phase 0 원문 「e2e 판정자: 에이전트 판정·사람 감독」이 닫았으므로 대안으로 내지 않는다. 대안 (c)(pass 는 clean 근거가 아니고 fail 만 막는 비대칭)는 goal 의 「런타임을 걸어보지 않고」 면을 고치지 못한다. 무증거 pass 가 PR 코멘트에 「e2e pass」로 게시되면 사람은 그것을 검증으로 읽기 때문이다. 그래서 (a)를 대안으로 세웠다."
recommendation: refined
refined_takes: "에이전트가 qg 가 제안하고 사용자가 고르거나 고친 경로를 직접 걷고 판정한다(P1·P3·P5). 사람은 감독하다 뒤집는다(Phase 0 선택 그대로). e2e fail → clean 불가(P4). 도구는 W2·W3(Playwright MCP 또는 Claude in Chrome, 접근성 스냅숏)를 쓴다. 판정 우선순위는 verdict.py 의 defect > not-certified > clean 을 그대로 쓴다."
refined_drops: "무증거 pass 가 clean 으로 가는 길을 여는 것(P6 의 무조건형)을 버린다. pass 는 기대 상태마다 관측 증거 인용이 있을 때만 성립하고, 하나라도 빠지면 「미확인」 → not-certified(닫힌 사유 하나 추가)다. 「사람 감독이 오류를 잡기에 충분하다」를 backstop 으로 삼는 것(P2)도 버린다. backstop 은 증거 하한이고, 감독은 그 증거를 읽고 뒤집는 자리로 남는다. 「걸을 것 없음(앱 없는 대상)」과 「걸었는데 증거 없음」을 한 값으로 접는 것도 버린다. 앞의 것은 공시, 뒤의 것은 clean 차단이다. 사용자가 e2e 를 「안 한다」고 고른 경우의 값은 OQ2 몫이다(kill-switch → not-certified 선례가 있다)."
evidence:
  - url: "https://arxiv.org/html/2603.25226v1"
    supports: alternative
    claim: "컴퓨터 사용 에이전트는 명시적 실패 증거를 관측하지 못하면 pass 로 판정한다(default-correctness bias). 전 모델 F1 30% 미만, 대부분 recall 25% 이하, 테스트 커버리지 70% 미만이다. 반대 방향으로 비동기 렌더 지연을 결함으로 오판하는 경우도 있다."
    touches: [P6]
    decides: [OQ2]
  - url: "https://arxiv.org/abs/2109.05067"
    supports: alternative
    claim: "사람 감독 정책에 대해 사람은 기대된 감독 기능을 수행하지 못하며, 그 정책이 결함 있는 알고리즘 사용을 정당화한다."
    touches: [P2]
    decides: []
  - url: "https://thedecisionlab.com/biases/automation-bias"
    supports: alternative
    claim: "Mosier & Skitka 비행 시뮬레이션에서 자동화 보조 집단의 정확도는 59%, 비보조 집단은 97%였다. 시스템이 경고하지 않은 것을 놓치는 누락 오류(omission)와 틀린 권고를 따르는 실행 오류(commission)가 함께 났다."
    touches: [P2]
    decides: []
  - url: "https://arxiv.org/pdf/2504.01382"
    supports: alternative
    claim: "WebJudge 는 과제의 핵심 지점을 먼저 식별하고 궤적에서 핵심 스크린샷을 골라 그 위에서 판정하며, 사람 판정과 85.7% 일치한다. 에이전트 판정은 증거에 묶일 때 신뢰도가 오른다."
    touches: [P1, P6]
    decides: [OQ2]
  - url: "https://code.claude.com/docs/en/best-practices"
    supports: both
    claim: "에이전트가 브라우저 스크린샷 등으로 직접 검증하게 하라는 권고(원안 지지)와 함께, 「Have Claude show evidence rather than asserting success … Reviewing evidence is faster than re-running the verification yourself, and it works for sessions you weren't watching」(대안 지지)를 담는다. 또 검증 subagent 로 「the agent doing the work isn't the one grading it」을 권한다."
    touches: [P3, P6]
    decides: [OQ2, OQ4]
  - url: "https://code.claude.com/docs/en/skills"
    supports: current
    claim: "번들 /verify 스킬은 테스트·타입체크로 물러나지 않고 앱을 빌드·구동해 변경이 의도대로 동작하는지 실행 중인 앱에서 확인한다. 실행 레시피는 .claude/skills/verify/SKILL.md 에 기록한다. 에이전트가 직접 걷는 방식의 1st-party prior-art 이자 새 전용 장치를 만들지 않을 수 있는 재사용 후보다."
    touches: [P1, P3]
    decides: [OQ4]
  - url: "https://github.com/microsoft/playwright-mcp"
    supports: both
    claim: "접근성 트리 스냅숏으로 비전 모델 없이 결정론적으로 조작한다. --caps=testing 으로 browser_verify_element_visible · browser_verify_text_visible · browser_verify_value · browser_verify_list_visible 단언 도구를 연다. 기대 상태마다 증거를 도구 결과로 남기는 가벼운 수단이다."
    touches: [P3]
    decides: [OQ4]
repo_claims:
  - id: RC1
    path: "plugins/quality-gates/CHANGELOG.md"
    anchor: "## [9.0.0] — 2026-09-26 / ### Removed — 「`runtime-verifier` agent — 부팅되는 앱의 런타임 행위 검증을 **대체하지 않고 주장을 거둔다**」"
    line: 137
    claim: "qg 는 9.0.0 에서 브라우저 플로우 · spec AC 런타임 검증 · mutation guard 를 대체 없이 거뒀다. 이번 e2e 는 그 주장을 다시 들이는 일이라, 거둘 때의 하한을 다시 충족해야 한다."
    touches: []
    decides: [OQ4]
  - id: RC2
    path: "docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md"
    anchor: "#### 6.5.3 공개 계약과 헌장 (C15) — 「신뢰도 하한은 「검증 못 하는 것을 검증했다고 말하지 않음」으로 지켜진다 — C11 의 goal 그 자체다」"
    line: 654
    claim: "런타임 주장을 거둔 근거가 「검증 못 하는 것을 검증했다고 말하지 않음」이다. 증거 없는 e2e pass 를 clean 근거로 쓰면 이 하한과 충돌한다."
    touches: [P6]
    decides: [OQ2]
  - id: RC3
    path: "plugins/quality-gates/CHANGELOG.md"
    anchor: "## [9.0.0] ### Changed — 「② 가 상시 도는 이상 관측 없음은 음성 결과가 아니다(§6.4.3 P23 재결정, 2026-09-26)」"
    line: 160
    claim: "qg 는 이미 「관측 없음 ≠ 통과」를 판정 규칙으로 갖고 있다(차등 테스트 unit 0개 → not-certified(scope-empty), docs-only 포함). 무증거 e2e pass 를 허용하면 같은 파이프라인 안에서 이 규칙과 반대가 된다."
    touches: [P6]
    decides: [OQ2]
  - id: RC4
    path: "plugins/quality-gates/scripts/verdict.py"
    anchor: "REASONS = ( … ) 닫힌 열거 · def decide(…) — `defect` > `not-certified` > `clean`"
    line: 23
    claim: "판정 어휘는 한 파일의 닫힌 열거이고 우선순위가 정해져 있다. e2e 「미확인」은 사유 하나를 추가하는 것으로 흡수되고, e2e fail 은 defect 플래그로 흡수된다. 새 판정 장치는 필요하지 않다."
    touches: [P4]
    decides: [OQ2]
  - id: RC5
    path: "docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md"
    anchor: "「실패도 아니므로 kill switch 가 「무조건 실패 버튼」이 되지 않는다」"
    line: 559
    claim: "qg 는 «안 돈 것»을 실패가 아니라 not-certified 로, 다른 전제 각도의 부재는 공시만으로 다루는 선례를 갖는다. 「걸을 것 없음」과 「안 한다」의 값을 정할 때 이 선례가 기준이 된다."
    touches: []
    decides: [OQ2]
  - id: RC6
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "## Fix-loop decision — 「Retry … Apply the suggested fixes (I will Edit the files in this turn), then re-run the pipeline for the next iteration」"
    line: 711
    claim: "qg 오케스트레이터는 Retry 에서 작업 트리를 직접 Edit 하는 writer 다. 그 오케스트레이터가 Retry 뒤 e2e 를 걷고 pass 를 판정하면 writer 가 자기 수정을 승인하는 자리가 된다."
    touches: [P1]
    decides: [OQ3, OQ4]
  - id: RC7
    path: "CLAUDE.md"
    anchor: "**Law 2 — Writer and Reviewer Must Never Share a Pass.** 「코드를 쓴 턴은 그 코드를 승인할 수 없음」"
    claim: "9.3.0 에서 scoped exception 이 지워져 Law 2 는 예외 없는 원칙이다. e2e 판정 주체가 writer 와 같은 턴이면 그대로 위반이다."
    touches: [P1]
    decides: [OQ4]
  - id: RC8
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "**Kill switch — `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1`.** 「차등 테스트는 리뷰 대상 저장소의 코드를 호스트 권한으로 돌린다 — 이 스위치는 그것을 끄는 보안 컨트롤이다」"
    line: 302
    claim: "저장소 코드를 호스트 권한으로 돌리는 축에 qg 는 kill switch 를 보안 컨트롤로 둔다. e2e 의 앱 부팅도 같은 성질이라 같은 통제가 필요한지가 열린다."
    touches: []
    decides: [OQ4]
```

**게이트-전 확인** — repo_claims(임시 RC1~RC8 → 인터뷰 순번 RC26~RC33): RC26 9.0.0 Removed 확인 · RC27 설계 §6.5.3 :654 확인 · RC28 9.0.0 Changed :160 확인 · RC29 verdict.py REASONS 확인 · RC30 설계 :559-560 확인 · RC31 SKILL Fix-loop :711 확인 · RC32 CLAUDE.md Law 2 확인 · RC33 SKILL kill switch :299-302 확인 · 부착 주장: WebTestBench → P6 확인(default-correctness bias, F1<30%) · Green → P2 확인(초록 원문) · automation-bias → P2 확인(59% vs 97%) · WebJudge → P1·P6 확인(초록에서 약 85% 일치만 확인, 핵심지점·스크린샷 메커니즘은 초록 밖) · best-practices → P3·P6 확인(「show evidence rather than asserting success」 원문) · skills /verify → P1·P3 확인 · playwright-mcp → P3 확인(--caps=testing, browser_verify_*) · 재검토 자격: 열림 5건(P2: Green·automation-bias / P6: WebTestBench·RC27·RC28)

**사용자 선택** — 보완 (S5)

#### ST2 — 실행마다 무동의 새 코멘트와 게시 장치 걷기

**dispatch 입력** — goal: S3(선택지 원문) + S1 확정 문장 · 전제: P1 매 실행 새 코멘트(S1) · P2 동의 묻지 않음(S1) · P3 이해글+qg 결과(S1) · P4 장치 최대한 걷기(S1) · P5 PR 없으면 skip, push/PR 생성 없음(S1) · P6 preview·동의 없이도 유출 위험 수용 가능(orchestrator 도출) · P7 매 실행 알림 비용 수용 가능(orchestrator 도출) · 제약: S1–S4 원문 전량 · trigger: Codecov 새 코멘트=매번 이메일 + 게시 SKILL 의 「사람 preview 가 최종 backstop」·매 실행 동의 불변식과 충돌

> builder 출력 verbatim:

```yaml
case_for_alternative:
  statement: "매 실행 새 코멘트·무동의·PR 없으면 skip 은 그대로 두고 preview·consent·upsert(마커·identity·REFUSE)·pr-create·--history 스캔은 걷되, 게시 직전 결정론 secret-scan 한 번(payload=이해글+qg 결과 전체, fail-closed, `scan_ok: yes` 줄 판정)과 publish kill switch 는 남긴다. 걸리면 묻지 않고 게시를 건너뛰고 한 줄로 알린다. 중단(Stop·cancel) 실행은 게시하지 않는다."
  strongest: "goal 은 /qg 한 번의 결과가 「사람이 믿고 판단할 검증 보고」로 PR 에 남는 것이다. 비밀이 섞인 코멘트는 그 보고를 믿을 수 없게 만든다. 게다가 게시 즉시 구독자 전원에게 이메일로 퍼져 삭제로도 되돌릴 수 없다. 리포는 스스로 preview 를 「최종 backstop」이라 적어 두었다(RC1). Invariant Labs 는 바로 이 흐름이 Claude Opus 위에서 실제로 일어남을 보였다: 주입 → 범위 밖 읽기 → GitHub 쓰기 → 유출. GitHub 의 코멘트 스캔은 사후 경보일 뿐이고 공개 리포에만 적용된다. 여기에 P3 이 리뷰어 산출(Read/Grep/Glob 전권, redaction 규칙 없음 — RC5)을 새 payload 로 더한다. 남기는 비용은 사람 상호작용이 없는 결정론 스크립트 호출 한 번뿐이다. goal 이 「무겁다」고 지목한 무게는 동의·preview·upsert·identity·create 쪽에 있고(RC4·RC12), 이 대안은 그것을 전부 걷는다. 중단 실행은 「검증 보고」가 아니다. 그런 실행을 매번 이메일로 알리면 PR 독자가 믿고 판단할 신호가 흐려진다."
case_for_current:
  strongest: "사용자는 W1 비용(매 실행 이메일)을 고지받은 뒤 갱신·매번 묻기·처음만 묻기를 모두 기각하고 「새 코멘트·묻지 않음」을 골랐다. goal 은 「과하게 보안을 무서워해 장치가 덕지덕지 붙는 것」을 판정을 왜곡하는 동등한 원인으로 명시한다. 새 코멘트 방식은 게시 장치 중 가장 무거운 덩어리를 통째로 없애고 `gh pr comment --body-file` 한 줄로 대체한다. 그 덩어리는 comment-upsert.py 의 identity 스코프·페이지네이션·마커 정규식·REFUSE 분기와 gh-identity.sh 다(RC4). 매 실행 코멘트는 그 시점에 무엇을 검증했는지를 변하지 않는 스냅샷으로 남긴다. 이메일은 「새 검증 보고가 나왔다」는 의도된 신호다. Codecov 의 `new`, sticky-comment action 의 `recreate` 처럼 이미 확립된 모드이기도 하다. 대상은 사용자 자신의 로컬 브랜치다. diff 는 이미 GitHub 에 push 돼 있고 빌더는 read-nothing 이다. 그러니 남은 유출 경로는 좁다. 리포에는 사용자가 매번 묻는 게이트를 상시 허용으로 바꾼 전례가 있어서(RC9) P2 는 P17 의 사용자 주권과 양립한다."
premise_refutation:
  hits: [P6]
  why: "P6 「사람 preview 와 동의 없이도 게시 내용의 유출 위험이 수용 가능하다」는 다음 세 근거와 부딪힌다. (1) RC1(plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md `## Generate`)은 빌더의 코퍼스 밖 읽기 잔여 위험이 「완화되나 제거되지는 않는다 — 사람 preview 가 최종 backstop」이라고 적는다. preview·동의를 걷으면 남는 층은 corpus-기반 secret-scan 하나뿐이다. P4 의 「최대한」이 그것까지 걷으면 결정론 차단은 0이 된다. 그러면 리포 자신이 「최종」이라 부른 층을 대체 없이 없애는 셈이다. (2) https://invariantlabs.ai/blog/mcp-github-vulnerability 은 이 잔여가 가설이 아님을 보인다. 코드 버그 없이 간접 주입만으로 Claude 4 Opus 에이전트가 범위 밖 데이터를 읽어 GitHub 쓰기로 게시했다. (3) https://docs.github.com/en/code-security/reference/secret-security/secret-scanning-detection-scope 는 PR 코멘트 스캔이 공개 리포·public monitoring 한정의 사후 경보라고 적는다. 따라서 무인 게시 뒤 플랫폼이 막아 준다는 가정은 성립하지 않는다. P6 이 「수용 가능」하려면 결정론 차단 한 층이 남는다는 조건이 붙어야 한다. 조건 없는 P6 문장은 이 근거들과 충돌한다. 다만 동의·preview 를 되살릴 근거는 아니다. 충돌은 secret-scan 한 층을 남기는 것으로 해소된다."
premise_list_challenge: "다섯 가지 결함이 있다. (1) P6 은 P2·P4 에서 도출되면서 「preview·동의 없이」와 「어떤 차단도 없이」를 한 문장에 섞었다. P6a(사람 게이트 없음 — 사용자 결정)와 P6b(결정론 fail-closed secret-scan 은 남는다 — 빠진 전제)로 나눠야 한다. 사용자 메모리 「결정론은 보안·정확성 게이트만」도 같은 선을 긋는다. (2) P4 「최대한」의 경계가 빠졌다. kill switch 는 CLAUDE.md 가 보안 컨트롤로 못 박은 것이고, 무인 게시에서는 사용자가 쓸 수 있는 유일한 override 다(Unbounded autonomy 금지 패턴). 그래서 걷을 수 있는 범위 밖이다. 지금 집행은 두 sink(comment-upsert.py · pr-create.sh) 안에 있다(RC10). 두 파일을 지우면 집행이 조용히 사라지므로 새 sink 로 옮긴다는 전제가 필요하다. (3) P2 는 P17 문면(「위험한·되돌리기 어려운·공유 state 액션은 항상 confirmation 게이트」 — RC8)과 정면으로 엇갈린다. Agent 상시 허용 전례(RC9)처럼 사용자의 상시 동의로 CLAUDE.md 나 스킬에 기록한다는 전제가 없다. 기록이 없으면 다음 리뷰가 P17 위반으로 다시 지적하고, 이 결정은 근거 없이 흔들린다. (4) P3 의 「qg 결과」가 무엇을 담는지 정해져 있지 않다. 현재 Final Summary 는 verdict·횟수·scope·angles·History 개수 줄뿐이라 코드 인용이 없다(RC6). finding 본문까지 싣는다면 security-reviewer 처럼 전권 읽기를 하는 리뷰어 텍스트가 빌더 코퍼스 밖 payload 가 된다(RC5). 유출 면도 이메일 소음도 이 선택이 정한다. (5) 닫힌 경로 「하나를 갱신」이 최선이라고 판단하지 않는다. 그 경로의 이점은 2회차부터 이메일이 안 간다는 것뿐이다. 유출은 줄지 않는다. 편집 이력이 읽기 권한자 전원에게 보이기 때문이다(GitHub edit-history 문서). 게다가 가장 무거운 장치(RC4)를 되살려야 해서 P4 와 충돌한다. P7 은 고지된 비용이므로 반증 대상이 아니다."
recommendation: refined
refined_takes: "P1(매 실행 새 코멘트, `gh pr comment <n> --body-file` 한 번, opaque-bytes 불변식 유지) · P2(동의 없음 — 상시 동의로 CLAUDE.md/스킬에 기록) · P3 · P5(PR 없으면 한 줄 고지 후 skip, push·create 없음). 이에 따라 걷는 것: 터미널 preview(render-terminal table·diagram), 게시 AskUserQuestion, comment-upsert.py(identity 스코프·마커 매칭·REFUSE), gh-identity.sh, pr-create.sh 와 그 `--history` 스캔 경로, 마커 첫 줄의 매칭 역할. accuracy-warnings 는 차단이 아니므로 터미널 대신 코멘트 안 notes 한 줄로 옮기거나 버린다. 둘 중 무엇이든 무방하다."
refined_drops: "P4 「최대한」을 secret-scan 과 kill switch 에까지 적용하는 것은 버린다. secret-scan.py 는 게시 직전 한 번 돈다. payload 는 이해글+qg 결과 전체, corpus 는 build-pr-context blob 이다. 걸리면 묻지 않고 게시를 skip 하고 한 줄로 알린다. kill switch DEVBREW_QUALITY_GATES_DISABLE_PUBLISH 는 새 게시 sink 로 옮겨 집행한다. 「실행마다」를 중단(Stop·/cancel-qg·aborted) 실행에까지 적용하는 것도 버린다. 중단 실행은 게시하지 않고 그 사실을 한 줄로 알린다. 이 부분은 OQ5 에 대한 추천일 뿐이고 결정은 사용자에게 남는다."
evidence:
  - url: "https://docs.codecov.com/docs/pull-request-comments"
    supports: both
    claim: "코멘트 동작은 default(갱신)·once·new(옛것 삭제 후 새로 게시)다. 이메일은 새 코멘트 게시 때만 가고 편집은 이메일을 보내지 않는다. 즉 매 실행 새 코멘트는 확립된 모드이면서 매 실행 알림이라는 비용을 확정한다."
    touches: [P1, P7]
    decides: []
  - url: "https://invariantlabs.ai/blog/mcp-github-vulnerability"
    supports: alternative
    claim: "코드 버그 없이 간접 프롬프트 주입만으로 Claude 4 Opus 에이전트가 범위 밖 private 데이터를 읽어 GitHub 쓰기(PR 생성)로 게시했다(toxic agent flow). 사람 게이트 없는 읽기→게시 흐름의 유출이 실증된 사례다."
    touches: [P6]
    decides: [OQ5]
  - url: "https://docs.github.com/en/code-security/reference/secret-security/secret-scanning-detection-scope"
    supports: alternative
    claim: "GitHub 의 PR 코멘트 secret 스캔은 공개 리포에서 enterprise public monitoring 을 켠 경우에만 돌고, 차단이 아니라 사후 경보다. 플랫폼이 게시 전 차단을 대신해 주지 않는다."
    touches: [P6]
    decides: [OQ5, OQ6]
  - url: "https://docs.github.com/en/communities/moderating-comments-and-conversations/tracking-changes-in-a-comment"
    supports: both
    claim: "코멘트 편집 이력은 읽기 권한자 누구나 볼 수 있다. 작성자가 revision 을 지울 수 있지만 편집자·시각은 남는다. 갱신 방식도 유출을 지우지 못한다. 갱신 방식의 이점은 이메일 억제뿐이다."
    touches: [P1, P6]
    decides: [OQ5]
  - url: "https://github.com/anthropics/claude-code-action/discussions/720"
    supports: both
    claim: "claude-code-action 사용자가 실행마다 새 코멘트가 쌓여 「old ones are just completely useless」라고 호소했고, 해법으로 sticky(갱신)가 제시됐다. P7 비용이 실재함을 보이는 사용자 보고다."
    touches: [P1, P7]
    decides: []
  - url: "https://github.com/marocchino/sticky-pull-request-comment/blob/main/action.yml"
    supports: current
    claim: "널리 쓰이는 PR 코멘트 action 이 `recreate`(옛것 삭제 후 새로 게시)와 `hide_and_recreate`(옛것을 OUTDATED 로 숨기고 새로 게시)를 정식 옵션으로 둔다. 매 실행 새 코멘트는 확립된 모드다."
    touches: [P1]
    decides: [OQ6]
repo_claims:
  - id: RC1
    path: "plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md"
    anchor: "## Generate — 「완화되나 제거되지는 않는다 — 사람 preview 가 최종 backstop이다」"
    line: 122
    claim: "리포는 빌더의 코퍼스 밖 읽기 잔여 위험을 corpus-기반 secret-scan + 사람 preview + P17 consent 로 완화한다. 그중 preview 를 최종 backstop 으로 명시한다."
    touches: [P6]
    decides: [OQ5]
  - id: RC2
    path: "plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md"
    anchor: "## Consent — 「`AskUserQuestion`을 매 실행 발동한다」"
    line: 183
    claim: "현행은 게시마다 동의를 묻는 것이 불변식이다. P2 는 이것을 뒤집는다."
    touches: [P2]
    decides: [OQ5, OQ6]
  - id: RC3
    path: "plugins/quality-gates/scripts/secret-scan.py"
    anchor: "KNOWN_PATTERNS · def scan"
    line: 20
    claim: "vendor 패턴 9종(AWS·GitHub·Slack·Stripe·PEM·JWT·credential-URL 등)은 corpus 와 무관하게 payload 만 보고 잡는다. 고엔트로피·quoted-value 탐지만 corpus 안의 값에 한정된다. 그래서 SKILL 의 「코퍼스 밖 비밀은 못 잡는다」는 과장이다. 코퍼스 밖이라도 vendor 형태의 비밀은 잡힌다. 사람 상호작용 없는 약 150줄짜리 결정론 스크립트이고 fail-closed 다."
    touches: [P4, P6]
    decides: [OQ5, OQ6]
  - id: RC4
    path: "plugins/quality-gates/scripts/comment-upsert.py"
    anchor: "def _matches · 「0 matches → POST / 1 match → PATCH / ≥2 matches → REFUSE」"
    line: 55
    claim: "upsert 는 인증 사용자 numeric id 스코프, 전 코멘트 페이지네이션, tier 허용 마커 정규식, REFUSE 분기를 갖는다. 전부 갱신 의미론 때문에만 존재한다. 새 코멘트 POST 하나로 가면 이 파일과 gh-identity.sh 가 할 일이 없어진다."
    touches: [P1, P4]
    decides: [OQ6]
  - id: RC5
    path: "plugins/quality-gates/agents/security-reviewer.md"
    anchor: "tools: Read, Grep, Glob · 「Secrets in code or logs — hardcoded credentials, API keys, tokens, or passwords」"
    line: 49
    claim: "항상 도는 보안 리뷰어는 리포 전체 읽기 권한을 갖고 하드코딩된 자격증명을 찾는 것이 임무다. 그런데 값을 가리라는 redaction 규칙이 persona 에 없다. qg 결과에 finding 본문을 실으면 빌더 blob 코퍼스 밖의 payload 원천이 생긴다."
    touches: [P3, P6]
    decides: [OQ5]
  - id: RC6
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "## Final Summary · 「qg iter N: <c> CRITICAL / <i> IMPORTANT / <s> SUGGESTION → user chose <choice>」"
    line: 899
    claim: "현행 Final Summary 는 Verdict·Iterations·Outcome 표와 synthesizer 의 scope·angles 블록, 개수만 담은 History 줄로 이뤄져 코드 인용이 없다. qg 결과의 유출 면은 이 형태를 finding 본문까지 넓히느냐에 달려 있다."
    touches: [P3]
    decides: [OQ5]
  - id: RC7
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "「**Stop** → emit final summary marked aborted at this iteration.」"
    line: 740
    claim: "사용자가 Stop 한 실행도 aborted 로 표시된 Final Summary 를 낸다. 「실행 끝에서 게시」를 문면 그대로 적용하면 중단 실행도 게시된다."
    touches: [P1]
    decides: [OQ5]
  - id: RC8
    path: "docs/philosophy/devbrew-harness-philosophy.md"
    anchor: "### P17 — User Sovereignty — 「위험한·되돌리기 어려운·공유 state에 영향을 주는 액션은 항상 confirmation 게이트를 거친다」"
    line: 51
    claim: "PR 코멘트 게시는 공유 state 이고 이메일 때문에 되돌릴 수 없다. P2 는 P17 문면과 엇갈린다."
    touches: [P2]
    decides: [OQ5]
  - id: RC9
    path: "CLAUDE.md"
    anchor: "Subagent spray — 「Agent(subagent) 호출 자체는 이 리포에서 상시 허용 — 매번 승인을 묻지 않는다 (… 사용자가 상시 요청으로 해제, 2026-08-22)」"
    claim: "사용자가 매번 묻는 기본 게이트를 상시 허용으로 해제하고 그것을 CLAUDE.md 에 규칙으로 기록한 전례가 있다. P2 를 P17 과 양립시키는 방법이 이것이다."
    touches: [P2]
    decides: [OQ5]
  - id: RC10
    path: "plugins/quality-gates/CHANGELOG.md"
    anchor: "## [6.0.0] — 「진짜 집행은 최내부 네트워크 sink 둘(`scripts/comment-upsert.py:77` · `scripts/pr-create.sh:17`)이고」"
    line: 1264
    claim: "publish kill switch 의 실제 집행 지점은 걷을 후보인 두 스크립트 안에 있다. 둘을 지우면서 새 sink 로 옮기지 않으면 kill switch 가 조용히 무력화된다."
    touches: [P4]
    decides: [OQ6]
  - id: RC11
    path: "plugins/quality-gates/CHANGELOG.md"
    anchor: "## [6.0.0] — 「deprecation window 없이 제거한다.」"
    line: 1241
    claim: "6.0.0 은 대체 경로 /qg-publish 가 이미 출하돼 있었다는 이유로 one-minor 창 없이 offer 를 지웠다. /qg-publish 를 없앨 때 같은 근거가 서는지는 따로 따져야 한다. /qg 없이 이해글만 게시하는 용도는 /qg 자동 게시가 대체하지 못한다. CLAUDE.md 의 「제거 전 one-minor deprecation window」가 기본값이다."
    touches: []
    decides: [OQ6]
  - id: RC12
    path: "plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md"
    anchor: "## Scan — 「PR-create 경로(`has_pr: no`) — corpus를 `build-pr-context.sh --history`로 만든다」"
    line: 149
    claim: "히스토리 스캔과 pr-create.sh 는 push 경로에만 필요하다. P5(push·create 없음)를 따르면 이 층은 통째로 걷을 수 있다."
    touches: [P4, P5]
    decides: [OQ6]
```

**게이트-전 확인** — repo_claims(임시 RC1~RC12 → 인터뷰 순번 RC34~RC45): RC34 Generate backstop 확인 · RC35 Consent :183 확인 · RC36 secret-scan KNOWN_PATTERNS 9종 확인(`_known(line)` 이 scan 첫 분기 — SKILL 의 「코퍼스 밖은 못 잡는다」는 과장이 맞다) · RC37 upsert 분기 확인 · RC38 security-reviewer secrets 임무·redaction 규칙 부재 확인 · RC39 Final Summary 확인 · RC40 Stop → aborted 확인 · RC41 P17 :51 확인 · RC42 CLAUDE.md Agent 상시 허용 확인 · RC43 6.0.0 sink 둘 확인 · RC44 6.0.0 창 없이 제거 확인 · RC45 Scan --history 확인 · 부착 주장: Codecov → P1·P7 확인 · Invariant → P6 확인(Claude 4 Opus, 간접 주입, PR 생성으로 유출) · GitHub secret scope → P6 확인(public monitoring 한정·사후) · edit-history → P1·P6 확인 · claude-code-action #720 → P1·P7 확인(「old ones are just completely useless」 원문 문구는 미확인, 쌓임 불만과 sticky 해법은 확인) · sticky-comment → P1 확인 · 재검토 자격: 열림 3건(P6: RC34·Invariant·GitHub scope)

**사용자 선택** — 보완 (S6)

#### ST3 — qg 전체를 백지에서 재건

**dispatch 입력** — goal: S11(원문) + S3(선택지 원문) · 전제: P1 qg 전체 재건(S12) · P2 qg 는 오래돼 지금 모델·Claude Code 에 안 맞는 것이 많다(S11) · P3 기존 장치는 과했다(S10) · P4 e2e 는 과거 구현 실패가 많았다(S11) · P5 새로 지으면 과함·시대 부적합이 해소된다(orchestrator 도출) · P6 교훈을 잃는 비용은 수용 가능(orchestrator 도출) · P7 한 작업·plan 병렬로 가능(S1·S2, 확장은 orchestrator 도출) · 제약: S1–S12 원문 전량 · trigger: big-bang rewrite·second-system anti-pattern + S1 「테스트 불변」 확정과 충돌 + 메모리 「바닥부터 전에 성숙한 레퍼런스」

> builder 출력 verbatim:

```yaml
case_for_alternative:
  statement: "qg v10 을 옛 것 옆에 세우고 구성요소 단위로 갈아끼운다(strangler-fig). 먼저 구성요소마다 표 한 장을 만든다 — 이 부품이 모델·Claude Code 에 대해 깔고 있는 가정, 그 가정을 대신하는 1st-party 기본기(/code-review --comment, /security-review, ReportFindings), 이 부품이 실어 나르는 옛 교훈(CHANGELOG 의 Security/Fixed 항목과 그 교훈을 지키는 락). 그 표로 처분을 정한다: 1st-party 가 대신하면 삭제, 시대에 안 맞으면 새로 짓기, 맞으면 남기기. 구성요소마다 독립 PR·릴리스로 컷오버한다."
  strongest: "goal 은 /qg 한 번의 결과를 사람이 믿고 판단할 수 있는 검증 보고로 만드는 것이다. 그 신뢰를 지금 실제로 받치는 것은 거짓 clean 을 막아 온 누적 수정들이다. 9.3.1 confidence 누락이 0 으로 채워지던 문제, v2.7.0 파이프가 exit code 를 삼키던 문제, 2.12.0 브라우저 agent 의 도구 표면 유출이 그 예다. 게다가 사용자 제약이 남기기로 한 기능(S6 secret-scan, S5 증거 기반 pass, e2e 브라우저 agent)이 바로 이 교훈들을 품고 있다. Anthropic 의 하니스 단순화 실험도 같은 결과를 보였다. 한꺼번에 잘라낸 1차 시도는 원래 성능을 재현하지 못했고, 부품을 하나씩 빼며 영향을 본 방식이 통했다. second-system effect 대로라면 백지 재건은 「과함」을 해소하기보다 다시 키운다. 반증도 있다. 파이프라인 ①–⑤ 와 판정 어휘는 1주 전(9.0.0, 2026-09-26)에 현 Claude Code 기준으로 이미 재설계됐는데도 SKILL 이 ~950줄로 무겁다. 무게의 원인은 코드의 나이보다 공정에 있다는 뜻이다. 이 리포는 1주 전에 바로 이 방법을 실제로 성공시켰다. 기계는 호출자 0으로 먼저 들이고, 판정 산출은 기본 off 로 두었다가, 9.0.0 에서 컷오버했다."
case_for_current:
  strongest: "S3 는 원인 넷이 동등하다고 본다. 그리고 과한 시스템을 조금씩 고치는 방식은 하나 고칠 때마다 락과 규칙을 덧붙여 왔다. 9.0.0 재설계 뒤 이틀 사이에 패치가 6번 나왔다. 그래서 새 최소 요구 목록에서 다시 시작하는 것만이 이 누적에서 빠져나오는 길일 수 있다. 실제로 갈아끼울 옛 것이 없는 부분도 많다. e2e 는 9.0.0 에서 runtime-verifier 를 지운 뒤 비어 있어서 처음부터 짓는 수밖에 없다. 게시는 S6 이 preview·consent·upsert·identity·pr-create 를 걷어내 대부분 삭제다. 리뷰 다이어트는 프롬프트를 고치는 일이다. 플랫폼도 바뀌었다. Claude Code 가 이제 /code-review(검증 단계로 오탐을 거르고, --comment 로 PR 에 게시하고, nit 상한과 재리뷰 수렴 규칙을 둔다)와 /security-review 를 1st-party 로 낸다. qg 고유 장치의 상당 부분이 플랫폼과 겹친다. 하니스의 부품마다 모델 능력에 대한 가정이 박혀 있고 그 가정은 모델이 나아지면 낡는다(Anthropic). qg 의 사용자는 한 명이라 하위호환 비용이 없다. 9.3.6 은 v10 이 설 때까지 설치된 채 남는다. 마지막으로, 사용자가 「바닥부터 지금에 맞게」라고 명시적으로 정했다(P17)."
premise_refutation:
  hits: [P2, P5, P6]
  why: "P2(qg 는 오래돼 지금 모델·Claude Code 에 맞지 않는 것이 많다): RC1·RC2 와 충돌한다. plugins/quality-gates/CHANGELOG.md 의 「## [9.0.0] — 2026-09-26」 「두 게이트가 한 파이프라인이 된다」와 「## [8.3.0] — 2026-09-22」 verdict.py 도입을 보면, P1 이 재건 대상으로 꼽은 파이프라인 ①–⑤ 와 판정 어휘(verdict.py)는 1~2주 전에 현 Claude Code 기준으로 새로 설계됐다. 오래된 부품이라는 전제는 이 부품들에 서지 않는다. P2 가 성립하는 범위는 v2 시대의 게시 장치(SKILL ## Consent·## Preview)와 1st-party 가 대신하는 부분(E4)으로 좁혀진다. 이 전제는 사용자의 추정(「많을거야」)이고 실측된 적이 없다. P5(새로 지으면 과한 장치·시대 부적합 문제가 해소된다): E1(anthropic.com/engineering/harness-design-long-running-apps 의 「I cut the harness back radically … I wasn't able to replicate the performance of the original」)과 E8(second-system effect)과 충돌한다. 리포 안의 반례도 있다. RC9 를 보면 1주 전 재설계(9.0.0)의 결과물이 여전히 SKILL ~950줄에 differential-test.md ~835줄이고, 이틀 사이 패치가 6번 나왔다. 새로 짓는 것이 가벼움을 보장하지 않는다. P6(누적 교훈을 잃는 비용은 수용 가능하다): RC5·RC6·RC7 과 충돌한다. 잃게 될 교훈은 S5·S6 과 열린 결정 OQ4 가 남기기로 한 바로 그 기능에 묶여 있다. 9.3.1 의 거짓 clean 수정은 판정 경로에, publishing SKILL 의 「exit code에 의존하지 말 것 — 파이프가 code를 삼킨다(v2.7.0 fail-open 교훈)」는 S6 이 남기는 secret-scan 에, 2.12.0 의 chrome-devtools 도구 표면 교훈은 새 e2e agent 에 해당한다. 남기는 기능의 교훈을 버리면 알려진 fail-open 이 다시 들어온다. 이는 「수용 가능」하다는 판단과 직접 충돌한다. 또 RC3(설계 문서 §3)은 차등 테스트 기계를 바꾸는 일을 두고 「여러 라운드의 하드닝을 거쳤고, 교체는 신뢰도 하한을 올리지 않으면서 단순함을 크게 깎는다」고 실측 판단을 남겨 두었다."
premise_list_challenge: "(1) 빠진 전제가 있다. 「무엇이 시대에 안 맞는가」를 잰 목록이 없다. 그래서 P2 는 추정이고, P1 의 범위가 P2 에서 도출되지 않는다. 재건 전에 목록은 필요하다고 판정한다. 다만 가벼워야 한다. 구성요소(skill·agent·reference·스크립트 묶음)마다 한 줄씩 「깔고 있는 가정 / 대신하는 1st-party / 실어 나르는 교훈 / 처분(삭제·새로·유지)」을 적는다. 새 P#·새 락·새 원장은 만들지 않는다. 이는 Anthropic 이 권한 「가정을 stress test 하라」를 그대로 옮긴 것이다. (2) 빠진 전제가 있다. 과함의 원인이 나이인지 공정인지를 따지지 않았다. RC9 를 보면 1주 된 재설계도 무겁다. 리뷰 라운드마다 finding 하나에 락 하나를 덧붙이는 공정을 그대로 두고 재건하면 무게는 다시 자란다. P5 가 서려면 이 공정을 바꾼다는 전제가 따로 있어야 한다. 예를 들면 멈춤 기준이나, 교훈을 락이 아니라 요구 목록으로 옮기는 방식이다. (3) 빠진 전제가 있다. e2e 의 대상 모집단이다. RC8(설계 문서 l.976)이 적었듯 devbrew 에는 부팅되는 앱이 없다. 9.0.0 이 runtime-verifier 를 지운 것은 구현 실패 때문만이 아니라 대상이 맞지 않아서였다(설계 l.49 「가장 비싼 게이트가 아무것도 검증하지 못하고」). 그리고 E5 에 따르면 /verify 는 v2.1.215 부터 모델이 스스로 부를 수 없다. 그러니 qg 가 e2e 를 1st-party 에 맡길 수 없고 직접 가져야 한다. P4 는 사실일 수 있지만 원인이 다르게 적혀 있다. (4) P7 의 실행 가능성이 의심스럽다. 이 리포가 1주 전에 그보다 작은 부분집합(파이프라인+판정)을 재설계하는 데 순차 PR 5개(8.1.0→9.0.0, 09-22~09-26)와 후속 패치 6번이 들었다(RC4). 그보다 큰 전체 재건을 한 spec 과 병렬 plan 으로 하면 이음매가 곱절로 늘어난다. 병렬화(S2)는 구성요소별 순차 컷오버 안에서만 안전하다. (5) 규칙 9 에 따른 공시: S12 가 S1 의 「테스트 불변」을 닫았다. 그러나 RC3 의 실측 판단은 차등 테스트 기계를 남기는 쪽이 최선이라고 말한다. 그 이유는 기계가 하드닝을 거쳤고, 교체는 신뢰도 하한을 올리지 않으며, 리뷰 다이어트·게시·e2e 라는 goal 의 네 면 어디에도 차등 기계가 원인으로 지목되지 않았다는 것이다. 이 경로를 대안으로 내지는 않는다. 다만 위 목록이 이 기계를 「유지」로 판정할 공산이 크다는 점은 사용자가 알아야 한다. (6) P6 은 전제가 아니다. 재야 할 비용이다. 교훈 목록을 만들기 전에는 「수용 가능」이라고 판정할 수 없다."
recommendation: refined
refined_takes: "「가능하면 새로 짓는다」를 구성요소별 기본 처분으로 받는다. 지금 확인된 부분은 다음과 같다. e2e 는 처음부터 새로 짓는다. 게시는 사실상 삭제해 코멘트 하나로 다시 짓는다. 리뷰 다이어트는 프롬프트를 고친다. v2 시대 장치(preview·consent·identity·upsert·pr-create)는 걷어낸다. 1st-party 가 대신하는 부분은 qg 에서 지우고 얇은 오케스트레이션으로 남긴다(E4). 현 모델·Claude Code 에 맞춰 가정을 다시 검토하는 일과 사용자의 「과했다」·「모델을 믿어라」 방향도 취한다."
refined_drops: "한 spec 으로 전체를 한꺼번에 재건하는 것을 버린다. 그 대신 v10 을 옆에 세우고 구성요소마다 독립 PR·릴리스로 컷오버한다. 이 리포가 8.1.0→9.0.0 에서 쓴 바로 그 방식이다. 측정 없이 「전체」를 재건 대상으로 잡는 것도 버린다. 1주 전에 재설계된 파이프라인 골격, verdict.py, 차등 테스트 기계는 위 목록이 「새로」로 판정할 때만 짓는다. S9(SUGGESTION 비차단)처럼 규칙 한 줄을 바꾸는 것으로 충분한 곳은 재건하지 않는다(RC11). 교훈을 버리는 것도 버린다. 옛 부품을 지우기 전에 그 부품이 실어 나르던 교훈(CHANGELOG Security/Fixed, 락이 지키던 불변식)을 새 설계의 요구 목록으로 먼저 옮긴다."
evidence:
  - url: "https://www.anthropic.com/engineering/harness-design-long-running-apps"
    supports: alternative
    claim: "하니스를 단순화할 때 한꺼번에 잘라낸 1차 시도는 원래 성능을 재현하지 못했다(「I cut the harness back radically … I wasn't able to replicate the performance of the original」). 이후 부품을 하나씩 빼며 영향을 본 방식(「removing one component at a time and reviewing what impact it had」)으로 옮겨 갔다."
    touches: [P5, P1]
    decides: [OQ15]
  - url: "https://www.anthropic.com/engineering/harness-design-long-running-apps"
    supports: current
    claim: "「Every component in a harness encodes an assumption about what the model can't do on its own … they can quickly go stale as models improve」. 하니스 부품의 가정은 모델이 나아지면 낡는다. 시대 부적합이라는 문제 제기 자체는 정당하다."
    touches: [P2]
    decides: [OQ15, OQ14]
  - url: "https://www.anthropic.com/engineering/harness-design-long-running-apps"
    supports: both
    claim: "evaluator 가 Playwright MCP 로 실행 중인 앱을 사용자처럼 클릭해 검증했다. 그 비용은 「the task sits beyond what the current model does reliably solo」일 때만 값한다. 작업자와 판정자를 분리하는 것이 자기평가 문제의 강한 지렛대다."
    touches: [P4]
    decides: [OQ4]
  - url: "https://code.claude.com/docs/en/code-review"
    supports: current
    claim: "1st-party /code-review 가 이미 여러 agent 로 탐지하고, 검증 단계로 오탐을 거른다. --comment 로 PR 에 게시하고, --max-findings 로 결과 수를 제한한다. REVIEW.md 로 nit 상한, 재리뷰 수렴(「suppress new nits」), 검증 기준을 둘 수 있다. 판정은 차단하지 않는다(neutral). qg 의 리뷰·게시 장치 상당 부분이 플랫폼과 겹친다."
    touches: [P2, P3]
    decides: [OQ15]
  - url: "https://code.claude.com/docs/en/commands"
    supports: both
    claim: "/verify 는 테스트 대신 앱을 빌드·실행·관찰해 변경을 확인하는 bundled skill 이다. 다만 「/verify runs only when you invoke it. Before v2.1.215, Claude could also run /verify on its own」. qg 가 모델 호출로 e2e 를 /verify 에 맡길 수 없으므로 e2e 를 걷는 주체는 qg 쪽에 있어야 한다."
    touches: [P2]
    decides: [OQ4]
  - url: "https://www.anthropic.com/engineering/building-effective-agents"
    supports: both
    claim: "LLM 앱은 가능한 가장 단순한 해법에서 시작하고 복잡도는 필요할 때만 올린다. 「과했다」·「모델을 믿어라」 방향을 뒷받침한다. 다만 그 단순화의 수단이 재건이냐 삭제냐는 정하지 않는다."
    touches: [P3]
    decides: [OQ15]
  - url: "https://en.wikipedia.org/wiki/Rewrite_(programming)"
    supports: alternative
    claim: "Spolsky 「Things You Should Never Do」가 가장 흔히 인용되는 재작성 반대 논거다. 옛 코드의 추한 부분은 대개 누적된 버그 수정이고, 재작성자는 경계 사례 요구를 다 알지 못한다. Netscape 4→6 이 그 예다."
    touches: [P5, P6]
    decides: [OQ15]
  - url: "https://bssw.io/items/things-you-should-never-do-part-i"
    supports: alternative
    claim: "같은 글의 요약이다. 작동하는 코드베이스를 버리고 새로 시작하는 것이 가장 나쁜 전략적 실수이고, 재작성은 축적된 지식을 버린다."
    touches: [P6]
    decides: [OQ15]
  - url: "https://en.wikipedia.org/wiki/Second-system_effect"
    supports: alternative
    claim: "설계자의 두 번째 시스템은 첫 시스템에서 못 넣은 추가물을 다 넣는 경향이 있어 가장 위험하다. 과설계에 빠지기 쉽다. 「새로 지으면 과함이 해소된다」와 반대 방향의 예측이다."
    touches: [P5]
    decides: [OQ15]
  - url: "https://en.wikipedia.org/wiki/Strangler_fig_pattern"
    supports: alternative
    claim: "기능을 점진적으로 새 시스템으로 옮기고, 다 옮긴 뒤에만 옛 시스템을 내리는 방식이다. big-bang 대비 위험을 줄인다."
    touches: [P7, P1]
    decides: [OQ15]
  - url: "https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/strangler-fig.html"
    supports: alternative
    claim: "strangler fig 는 단계적 이전으로 전환 위험과 중단을 줄이는 현대화 패턴이다."
    touches: [P7]
    decides: [OQ15]
  - url: "https://simonwillison.net/2019/Feb/19/lessons-6-software-rewrite-stories/"
    supports: current
    claim: "Herb Caudill 의 재작성 사례 6건(Basecamp, VS Code, FogBugz/Trello 등)을 소개한다. 재작성이 「최악의 실수」라는 통념에 반례가 있다. 원래 기술 선택이 필요한 개선을 막을 때는 재작성이 타당할 수 있다."
    touches: [P2, P1]
    decides: [OQ15]
repo_claims:
  - id: RC1
    path: "plugins/quality-gates/CHANGELOG.md"
    anchor: "## [9.0.0] — 2026-09-26 / 「두 게이트가 한 파이프라인이 된다. 판정은 `clean` · `defect` · `not-certified (<사유>)` 셋이다.」"
    line: 131
    claim: "P1 이 재건 대상으로 꼽은 파이프라인 ①–⑤ 와 판정 어휘는 오늘(2026-10-03) 기준 1주 전에 현 Claude Code 를 대상으로 재설계됐다. 「오래돼 시대에 안 맞는다」는 이 부품들에 바로 적용되지 않는다."
    touches: [P2, P1]
    decides: [OQ15, OQ14]
  - id: RC2
    path: "plugins/quality-gates/CHANGELOG.md"
    anchor: "## [8.3.0] — 2026-09-22 / 「`scripts/verdict.py` 가 `clean` · `defect` · `not-certified` 와 11값 사유 열거 …」"
    line: 274
    claim: "verdict.py 는 11일 전에 생겼다."
    touches: [P2]
    decides: [OQ15, OQ2]
  - id: RC3
    path: "docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md"
    anchor: "「차등 테스트 기계 자체를 다른 것으로 바꾸는 것(brief OQ5). 지금 기계는 여러 라운드의 하드닝을 거쳤고, 교체는 신뢰도 하한을 올리지 않으면서 단순함을 크게 깎는다」"
    line: 71
    claim: "직전 재설계가 차등 테스트 기계 교체를 근거와 함께 범위 밖으로 판정했다. S1 의 「테스트 불변」을 받치던 근거다."
    touches: [P6, P1]
    decides: [OQ15]
  - id: RC4
    path: "plugins/quality-gates/CHANGELOG.md"
    anchor: "## [8.1.0] 「호출자는 아직 0 이다. 이 릴리스는 기계만 들여놓고 `/qg` 의 동작은 바꾸지 않는다 — 배선은 뒤 릴리스다.」 + ## [8.3.0] 「합성기의 판정 산출은 `--emit-verdict` 뒤에 있고 기본 off」"
    line: 354
    claim: "이 리포는 1주 전 strangler 방식을 실제로 돌렸다. 기계를 호출자 0으로 들이고, 기본 off 로 두었다가, 9.0.0 에서 컷오버했다. 부분집합 재설계에 순차 릴리스 5개가 들었다(8.1.0~9.0.0, 09-22~09-26)."
    touches: [P7, P1]
    decides: [OQ15]
  - id: RC5
    path: "plugins/quality-gates/CHANGELOG.md"
    anchor: "## [9.3.1] 「합성기가 `confidence` 가 빠진 발견을 0 으로 채워 억제 바닥(≤4) 아래로 떨구던 것을 고친다. … 거짓 `clean` 이 날 수 있었다.」"
    line: 64
    claim: "e2e 실행에서 드러난 거짓 clean 을 막는 경계 사례 지식이 판정 경로에 박혀 있다. 판정을 재건하면 다시 지켜야 하는 교훈이다."
    touches: [P6]
    decides: [OQ15]
  - id: RC6
    path: "plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md"
    anchor: "「게이트는 스크립트 stdout의 리터럴 `scan_ok: yes` 줄로만 판정한다. exit code에 의존하지 말 것 — 파이프가 code를 삼킨다(v2.7.0 fail-open 교훈)」"
    line: 160
    claim: "S6 이 남기기로 한 게시 직전 secret-scan 에 실제로 일어났던 fail-open 교훈이 붙어 있다. 게시를 재건하면 그대로 옮겨야 한다."
    touches: [P6]
    decides: []
  - id: RC7
    path: "plugins/quality-gates/CHANGELOG.md"
    anchor: "## [2.12.0] — 2026-07-19 「`pr-understanding-builder` MCP 유출 경로 봉쇄 … denylist 에 `mcp__*` 가 없어 tavily 웹검색·chrome-devtools 브라우저 제어를 보유」 / 「chrome-devtools 는 per-tool 그대로(서버 단위 grant 는 표면을 넓혀 `upload_file` 유출 벡터를 준다) … `get_network_request`(auth 헤더·토큰 노출)는 least-privilege 로 제외」"
    line: 4067
    claim: "옛 브라우저 구동 agent 가 남긴 도구 표면 교훈이다. 브라우저 MCP 는 도구 단위로 허용하고, upload_file 유출과 auth 헤더 노출을 막는다. 새 e2e agent 를 설계할 때 그대로 요구 목록이 된다."
    touches: [P6, P4]
    decides: [OQ4]
  - id: RC8
    path: "docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md"
    anchor: "「가장 비싼 게이트가 아무것도 검증하지 못하고」(§1) / 「증거가 N=1 이다 … 그 리포는 부팅되는 앱이 없다는 점에서 모집단 중 가장 비전형적이다」"
    line: 976
    claim: "runtime-verifier(옛 e2e)를 지운 주된 이유는 대상이 맞지 않아서였다. devbrew 에는 부팅되는 앱이 없다. e2e 에는 갈아끼울 옛 것이 없으므로 새로 짓기가 맞는 자리다. 다만 devbrew 자신에게 무엇을 「걸을지」는 따로 정해야 한다."
    touches: [P4]
    decides: [OQ4, OQ14]
  - id: RC9
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "## Pipeline 「한 파이프라인, 한 판정(설계 §6.1)」"
    line: 158
    claim: "1주 전 재설계를 거친 SKILL 이 여전히 ~950줄(비어 있지 않은 줄 784)이다. 짝 reference differential-test.md 도 비어 있지 않은 줄 835 이다. 9.0.0→9.3.6 사이 이틀 동안 패치가 6번 나왔다. 무게는 진짜다(P3 지지). 동시에 새로 설계해도 가벼워지지 않았다(P5 반례)."
    touches: [P3, P5]
    decides: [OQ15, OQ14]
  - id: RC10
    path: "plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md"
    anchor: "## Consent 「`AskUserQuestion`을 매 실행 발동한다」 / 「no-PR 경로는 단일 informed consent로 push N commits + … `gh pr create`」"
    line: 181
    claim: "게시 장치의 무게는 v2 시대의 동의·preview·identity·PR 생성에서 나온다. S6 이 이것들을 걷어낸다. 따라서 게시를 「새로 짓는」 일은 대부분 삭제다."
    touches: [P3]
    decides: []
  - id: RC11
    path: "plugins/quality-gates/CHANGELOG.md"
    anchor: "## [9.0.0] 「kept > 0 인 finding 하나(SUGGESTION 포함)만으로도 판정은 `defect` 다 — severity 를 묻지 않는다(계획 R-B)」"
    line: 159
    claim: "S3 의 「과잉 처방이 판정을 쥔다」를 이루는 한 축은 판정 규칙 한 줄이다. S9 가 이를 국소 변경으로 뒤집는다. 판정 어휘 전체를 재건하지 않아도 이 원인은 닫힌다."
    touches: [P5]
    decides: [OQ2]
```

**게이트-전 확인** — repo_claims(임시 RC1~RC11 → 인터뷰 순번 RC74~RC84): RC74 9.0.0 :131 확인 · RC75 8.3.0 :274 확인 · RC76 설계 :70-72 확인 · RC77 8.1.0 :354 · 8.3.0 :279 확인 · RC78 9.3.1 :64 확인 · RC79 publish SKILL :160 확인 · RC80 2.12.0 :4067 확인 · RC81 설계 :976 확인 · RC82 SKILL 955줄 · differential-test 1013줄 · 9.1.0~9.3.6 이 09-27~09-28 확인 · RC83 Consent :181 확인 · RC84 9.0.0 :159 확인 · 부착 주장: harness-design → P5·P1 확인(「cut the harness back radically」·「wasn't able to replicate」·「removing one component at a time」) · harness-design → P2 확인(「Every component in a harness encodes an assumption」) · harness-design → P4 확인(Playwright evaluator, 「beyond what the current model does reliably solo」) · code-review → P2·P3 확인(검증 단계·--comment·neutral·REVIEW.md nit 상한) · commands → P2 확인(「/verify runs only when you invoke it. Before v2.1.215 …」) · building-agents → P3 확인 · Rewrite(Wikipedia) → P5·P6 확인(Netscape 실패 재작성 인용) · BSSw → P6 확인(「Thermonuclear Mistake」, 점진 교체 권고) · second-system → P5 확인 · strangler(Wikipedia) → P7·P1 확인(Fowler) · AWS strangler → P7 확인(작은 앱이면 전체 재작성이 더 효율적일 수 있다는 단서도 함께) · Willison → P2·P1 확인 · 재검토 자격: 열림 12건(P2: RC74·RC75·harness-design / P5: harness-design·second-system·RC82 / P6: RC76·RC78·RC79·RC80·Rewrite·BSSw)

**사용자 선택** — 보완 (S13)

## 4. 게이트 실행 기록

- check_brief.py gate — fail (2026-10-03) — web: enabled — 역참조 ∀ 불일치 3건(OQ15·OQ18·OQ19 의 §0 줄) → §4·§5 연결에서 §0·§3 역참조를 기계적으로 재생성
- check_brief.py gate — pass (2026-10-03) — web: enabled
- check_verbatim_coverage.py — exit 0 (2026-10-03) — state 는 job tmp 경로를 인자로 넘김

## 5. 프로세스 로그

- 진입: `/interview @docs/superpowers/interview/2026-10-03-qg-review-e2e-publish-interview.md` — seed 원문 대조 줄 출력, seed_provenance classify rc 0 (user_confirmed 13 · user_unconfirmed 0 · author 15, audit ok)
- state 위치 degrade: 격리 워크트리 세션이라 메인 체크아웃 `.claude/spec-distill/<sid>/` 쓰기가 막혀 state 를 job tmp(`$CLAUDE_JOB_DIR/tmp/spec-distill/<sid>/state.local.md`)에 두었다. 세션 정리 뒤엔 남지 않는다.
- brief 파일명: seed 와 seed-audit 를 덮어쓰지 않으려고, 그리고 주제가 qg 전체 재건으로 넓어져서 `qg-v10-rebuild` 로 새 이름을 썼다. seed 파일 둘은 그대로 남는다.
- coverage-mapper #1 (R1 전 필수): derived 6 제안 전부 admit + internal_research admit. D6 의무 — seed «다시 검증할 것» 의 레포 확인 가능 항목에 repo_claims 산출(RC1~RC25)
- round 1: path d — 진짜 문제 질문 → S2(중심 선택 거부, 넷 다 중심)
- round 2: path d — 문제정의 모양 → S3 · root_problem closed
- round 3: path a(웹) — landscape W1~W7 처분 → S4 · landscape closed
- steelman ST1·ST2 병렬 dispatch
- round 4: steelman ST1 → S5(보완)
- round 5: steelman ST2 → S6(보완) · skepticism closed
- blind-spot-prober #1 dispatch (blind_spot 첫 전이)
- round 6: path a — 다이어트 층위 + W8(best practices 「Chasing every finding leads to over-engineering」, orchestrator 직접 확인) → S7
- round 7: path a — 의도 출처 → S8
- round 8: path a — 계획 R-B(docs/superpowers/plans/2026-09-22-qg-verdict-vocabulary-pr2.md:71, 「사용자가 뒤집을 수 있는 자리」) → S9
- round 9: path a(웹) — premortem 네 묶음 처분 → S10 · blind_spot closed
- round 10: path b — 게시 바닥부터 범위 → S11
- round 11: path d — 재건 범위 → S12 · root_problem 재개방(conflicts_with S3) · skepticism 재개방 · S1 테스트 불변 확정 뒤집음(P23)
- steelman ST3 + coverage-mapper #2(재개방 예산) 병렬 dispatch — derived 5 admit, first_party_delegation_boundary 는 e2e_actor_tool_surface 로 흡수, neglect_flag true
- round 12: steelman ST3 → S13(보완) · skepticism closed
- round 13: path d — 문제정의 재구성 → S14 · root_problem closed
- round 14: path a — e2e 주체 (#34592 직접 확인) → S15
- round 15: path a — e2e 자리 → S16 · mid-turn 사용자 발화 S17 「오케스트레이터만 다 걷고 판정하자」(S15 를 뒤집음)
- round 16: path b — Law 2 정합 되묻기 · mid-turn S18 → S19
- round 17: path a — e2e 판정값 → S20
- round 18: path a — 코멘트 payload → S21
- round 19: path a — 재건 경계 → S22
- round 20: path a — 이관 → S23
- round 21: path b — 미해결 목록 확인 → S24 · open_questions closed
- 확인 RC1 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#Pipeline — 다섯 단계 × 최대 5회, e2e 단계 없음
- 확인 RC2 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#Step 4.5 라우팅 — clean 이면 즉시 Final Summary
- 확인 RC3 — 확인 — plugins/quality-gates/scripts/verdict.py#REASONS — 3값·사유 11개 닫힌 열거
- 확인 RC4 — 확인 — plugins/quality-gates/CHANGELOG.md#9.0.0 Removed — runtime-verifier 회수, 브라우저 플로우·AC 런타임·mutation guard 상실
- 확인 RC5 — 확인 — plugins/quality-gates/CHANGELOG.md#9.3.0 Changed — CLAUDE.md Law 2 scoped exception 삭제
- 확인 RC6 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#Law 2 (Writer ≠ Reviewer) — qg 자체 agent 쓰기 0, 오케스트레이터가 테스트 실행
- 확인 RC7 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#Kill switch DISABLE_DIFFERENTIAL_TEST — 호스트 권한 실행 보안 컨트롤
- 확인 RC8 — 확인 — plugins/quality-gates/skills/quality-pipeline/references/differential-test.md#Step R3 — 생략 없으면 질문 없이 zero-click
- 확인 RC9 — 확인 — plugins/quality-gates/scripts/synthesize_findings.py#decide(defect=bool(kept)) — severity 무관 defect
- 확인 RC10 — 확인 — plugins/quality-gates/references/recritic-code-profile.md#판정 관문 — 처방 규모 관문 없음, D 는 빠진 점검을 added 로
- 확인 RC11 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#rubric — 기본·추가 리뷰어 전부 외부 플러그인
- 확인 RC12 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#Fix-loop decision Retry — suggested patches 를 의도 대조 없이 Edit
- 확인 RC13 — 확인 — plugins/quality-gates/scripts/discover-spec.sh#most-recent mtime wins — resolve-topic.sh 는 Spec: 트레일러
- 확인 RC14 — 확인 — plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md#Consent — 매 실행 AskUserQuestion
- 확인 RC15 — 확인 — plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md#Generate — 사람 preview 가 최종 backstop
- 확인 RC16 — 확인 — plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md#Publish — 0→POST/1→PATCH/≥2→REFUSE, PR 부재 시 pr-create.sh
- 확인 RC17 — 확인 — plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md#Scan — --history 는 PR-create 경로 전용
- 확인 RC18 — 확인 — plugins/quality-gates/tests/test_qg_publish_handoff.sh#(6) — publish-active.md 는 v7.0.0 에서 제거, 생산자 부재 락 (seed 저자 문장을 반증)
- 확인 RC19 — 확인 — plugins/quality-gates/CHANGELOG.md#6.0.0 Removed — 자동 발행 offer 제거, deprecation 창 없음
- 확인 RC20 — 확인 — plugins/quality-gates/scripts/comment-upsert.py#DISABLE_PUBLISH — 최내부 sink 에서 집행
- 확인 RC21 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#Stop — aborted Final Summary
- 확인 RC22 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#R5 — 단일 턴
- 확인 RC23 — 확인 — plugins/quality-gates/README.md#재계산 max fan-out — Phase 1 ≤ 8, 총 ≤ 10
- 확인 RC24 — 확인 — plugins/quality-gates/agents/security-reviewer.md#Forced findings — 추측성 덧대기 금지
- 확인 RC25 — 확인 — plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md#Build — 명시 실행이 곧 수용, tier 3 1회 비용 고지
- 확인 RC26 — 확인 — plugins/quality-gates/CHANGELOG.md#9.0.0 Removed — runtime-verifier 대체 없이 회수
- 확인 RC27 — 확인 — docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#6.5.3 — 「검증 못 하는 것을 검증했다고 말하지 않음」
- 확인 RC28 — 확인 — plugins/quality-gates/CHANGELOG.md#9.0.0 Changed — 이상 관측 없음은 음성 결과가 아니다
- 확인 RC29 — 확인 — plugins/quality-gates/scripts/verdict.py#REASONS · decide — 닫힌 열거·우선순위
- 확인 RC30 — 확인 — docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#무조건 실패 버튼 — 안 돈 것은 not-certified
- 확인 RC31 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#Fix-loop decision — Retry 에서 오케스트레이터가 Edit
- 확인 RC32 — 확인 — CLAUDE.md#Law 2 — 코드를 쓴 턴은 그 코드를 승인할 수 없음
- 확인 RC33 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#Kill switch — 차등 테스트 호스트 실행 보안 컨트롤
- 확인 RC34 — 확인 — plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md#Generate — preview 가 최종 backstop
- 확인 RC35 — 확인 — plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md#Consent — 매 실행 동의 불변식
- 확인 RC36 — 확인 — plugins/quality-gates/scripts/secret-scan.py#KNOWN_PATTERNS — vendor 9종은 corpus 무관(`_known` 이 scan 첫 분기)
- 확인 RC37 — 확인 — plugins/quality-gates/scripts/comment-upsert.py#_matches — 갱신 의미론 전용 분기
- 확인 RC38 — 확인 — plugins/quality-gates/agents/security-reviewer.md#Secrets in code or logs — redaction 규칙 부재(grep 0건)
- 확인 RC39 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#Final Summary — 코드 인용 없음
- 확인 RC40 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#Stop — 중단 실행도 Final Summary
- 확인 RC41 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#P17 — 되돌리기 어려운·공유 state 액션은 confirmation 게이트
- 확인 RC42 — 확인 — CLAUDE.md#Subagent spray — Agent 상시 허용 전례
- 확인 RC43 — 확인 — plugins/quality-gates/CHANGELOG.md#6.0.0 — kill switch 집행이 comment-upsert.py · pr-create.sh 두 sink
- 확인 RC44 — 확인 — plugins/quality-gates/CHANGELOG.md#6.0.0 — deprecation window 없이 제거
- 확인 RC45 — 확인 — plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md#Scan — --history 는 push 경로 전용
- 확인 RC46 — 확인 — plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md#Generate — preview 최종 backstop(RC34 와 같은 자리)
- 확인 RC47 — 확인 — plugins/quality-gates/scripts/secret-scan.py#_high_entropy_in_corpus — `tok in corpus` 일 때만
- 확인 RC48 — 확인 — plugins/quality-gates/scripts/synthesize_findings.py#decide — defect=bool(kept)
- 확인 RC49 — 확인 — plugins/quality-gates/scripts/synthesize_findings.py#suppress — non-CRITICAL confidence ≤4 억제(실제 줄 514, 주장의 210 과 다름 · 내용 일치)
- 확인 RC50 — 확인 — plugins/quality-gates/references/recritic-code-profile.md#D — 빠진 점검은 added 로
- 확인 RC51 — 확인 — CLAUDE.md#Persona 파일은 보안-민감 코드 — persona 약화 PR 은 보안 리뷰 대상
- 확인 RC52 — 확인 — docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#증거가 N=1 이다 — 부팅되는 앱이 없는 리포
- 확인 RC53 — 확인 — plugins/quality-gates/CHANGELOG.md#9.0.0 — runtime-verifier · mutation guard 회수
- 확인 RC54 — 확인 — plugins/quality-gates/CHANGELOG.md#3.0.0 — verifier self-report 는 raw 가 아니라 요약
- 확인 RC55 — 확인 — plugins/quality-gates/README.md#총/iteration ≤ 10 — 선언 fan-out 소진
- 확인 RC56 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#R5 — 같은 iteration 재디스패치 금지
- 확인 RC57 — 확인 — docs/git-workflow/pr-process.md#quality-gates — 자동 트리거 서술, hooks/ 에는 session-start·session-end 뿐
- 확인 RC58 — 확인 — plugins/quality-gates/scripts/diagram-facts.sh#extract_import — JS/TS·Python import 만
- 확인 RC59 — 확인 — plugins/quality-gates/scripts/verdict.py#REASONS — 튜플 순서 = 우선순위
- 확인 RC60 — 확인 — docs/superpowers/specs/2026-08-02-harness-capability-suppression-sweep-design.md#이 줄을 지우면 — 판별식 원문
- 확인 RC61 — 확인 — plugins/quality-gates/scripts/scout.py#Depth decision (v1.x scout.md L42-44) — v1 결정론 표
- 확인 RC62 — 확인 — plugins/quality-gates/scripts/synthesize_findings.py#suppress non-CRITICAL confidence<=4 — 모듈 머리 주석
- 확인 RC63 — 확인 — plugins/quality-gates/scripts/check-allowed-tools-order.sh — v1.32.3 순서 linter
- 확인 RC64 — 확인 — plugins/quality-gates/README.md#Depth — 「기존 default-Opus 베이스라인 대비 비용」
- 확인 RC65 — 확인 — plugins/quality-gates/scripts/verdict.py#REASONS — 보존할 닫힌 열거
- 확인 RC66 — 확인 — plugins/quality-gates/README.md#LD5 — 호출 주체 분리(Law 2)
- 확인 RC67 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#처분 — consumer=synthesize_findings.py
- 확인 RC68 — 확인 — shared/tests/test_charter_citations.sh — qg plugin.json 을 이름으로 지목
- 확인 RC69 — 확인 — plugins/plugin-audit/README.md#quality-gates ≥ 2.12.0 — qg-worktree.sh 의존
- 확인 RC70 — 확인 — plugins/project-init/README.md#quality-gates — 「리뷰·런타임 파이프라인」 서술
- 확인 RC71 — 확인 — plugins/quality-gates/CHANGELOG.md#9.0.0 — 제거 인자 「한 줄 공지 후 진행」
- 확인 RC72 — 확인 — plugins/quality-gates/CHANGELOG.md#9.0.0 — SUGGESTION 하나도 defect, Accept 해도 clean 아님
- 확인 RC73 — 확인 — plugins/quality-gates/README.md#/qg-publish — 파이프라인 밖 분리 불변식
- 확인 RC74 — 확인 — plugins/quality-gates/CHANGELOG.md#9.0.0 — 2026-09-26 한 파이프라인 재설계
- 확인 RC75 — 확인 — plugins/quality-gates/CHANGELOG.md#8.3.0 — verdict.py 도입
- 확인 RC76 — 확인 — docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#차등 테스트 기계 자체를 다른 것으로 바꾸는 것 — 범위 밖 판정
- 확인 RC77 — 확인 — plugins/quality-gates/CHANGELOG.md#8.1.0 — 호출자 0 → 기본 off → 컷오버
- 확인 RC78 — 확인 — plugins/quality-gates/CHANGELOG.md#9.3.1 — confidence 누락 0 채움 거짓 clean 수정
- 확인 RC79 — 확인 — plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md#Scan — `scan_ok: yes` 줄 판정(v2.7.0 교훈)
- 확인 RC80 — 확인 — plugins/quality-gates/CHANGELOG.md#2.12.0 — 브라우저 MCP 도구 표면 교훈
- 확인 RC81 — 확인 — docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#증거가 N=1 이다 — 부팅되는 앱 없음
- 확인 RC82 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#Pipeline — 955줄, differential-test.md 1013줄, 9.1.0~9.3.6 이 09-27~09-28
- 확인 RC83 — 확인 — plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md#Consent — v2 시대 동의·preview·identity·PR 생성
- 확인 RC84 — 확인 — plugins/quality-gates/CHANGELOG.md#9.0.0 — R-B 한 줄

### brief 리뷰 (reviewing-brief — 문서 리뷰 엔진)

- 라운드: 3 · 재리뷰 카운트 2 · 추가 라운드 0 — 승인 게이트 도달 사유: 상한 · 리뷰 완료: 예
- 결정: `## 8. 리뷰 결정` 6건(D1.1·D1.2·D1.3·D2.4·D3.5·D3.6 전부 채택) · 열린 채 남은 항목 0건 · 질문 1건 답함(5d052b11#r2.1 → 「spec 은 하나다(S3)」) · 미적용 fix 2건(0138b17b#r3.1 · f0f95e2d#r3.1 — 저자가 적용했으나 추가 라운드를 열지 않아 엔진 관측 없음)
- codex: 있음(라운드 1~3 실호출 3회 성공) · 웹: Claude doc-critic-web · codex 켜짐
- 냉독: gap 0건 (G1~G6 없음) — 단 인라인 본문 §2·§4·§5·§6 축약(degrade), 정의 없는 용어(이해글 · upsert · identity · --history · LD5 · 관문 D)와 audit 에만 있는 근거(RC·ST·S2+) 지적
- degrade: critic:fidelity:degraded(번들 내용 대신 경로 전달) · readback:readback:degraded(인라인 본문 축약)

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S2** 🗣 발화 (진짜 문제 질문에 대한 자유 응답):
  > 다 중심이야 진행하는데 소홀히 하지 마 예산이 문제면 서브에이전트 쓰고 plan병렬로 여러개 만들어
- **S3** ☑ 선택 (문제정의의 모양):
  > 한 goal 의 네 면 — 「/qg 한 번의 결과가 사람이 믿고 판단할 검증 보고가 되지 못한다. 런타임을 걸어보지 않고, PR 에 남지 않고, 게시 장치가 무겁고, 과잉 처방이 판정을 쥐어 수정이 의도에서 벗어난다 — 넷은 동등한 원인이다.」 spec 하나에 이음매 AC(e2e→판정→코멘트), plan 은 네 갈래 + 이음매로 병렬화
- **S4** ☑ 선택 (외부 근거 처분):
  > 처분대로 — W2·W3·W5·W7 취함, W6 중립(선례), W1 중립(비용 공시), W4 피함(무증거 pass); W1·W4 는 steelman 으로
- **S5** ☑ 선택 (steelman ST1):
  > ST1 보완 (builder·orchestrator 추천) — 에이전트 판정·사람 감독 유지, pass 는 기대 상태마다 관측 증거 인용 시에만 성립, 빠지면 「미확인」 → not-certified; 걸을 것 없음=공시, 걸었는데 증거 없음=clean 차단
- **S6** ☑ 선택 (steelman ST2):
  > ST2 보완 (builder·orchestrator 추천) — 새 코멘트·무동의·PR 없으면 skip 유지; preview·동의·upsert·identity·pr-create·--history 걷음; 게시 직전 결정론 secret-scan 1회(걸리면 묻지 않고 skip+한 줄) + publish kill switch 남김(새 sink 로 이전); 중단 실행 미게시; 무동의는 상시 동의로 규칙에 기록
- **S7** ☑ 선택 (리뷰 다이어트 층위):
  > 처방+적용 양쪽 — 리뷰어 dispatch 프롬프트에 W8 기준(정확성·명시 요구에 닿는 gap 만, 나머지 optional) + 재비판 프로필에 처방-의도 초과 관문; Retry 직전 의도 대조로 벗어나는 패치 제외·공시. 새 락·원장 없음
- **S8** ☑ 선택 (원래 의도의 출처):
  > 선언 우선 사슬 — 커밋 Spec: 트레일러 spec → 없으면 브랜치 커밋 메시지 + PR 본문; mtime 최신 spec 미사용; 쓴 출처 한 줄 공시; 추가 질문 없음
- **S9** ☑ 선택 (SUGGESTION 판정 규칙):
  > 판정을 막지 않음 — 살아남은 CRITICAL·IMPORTANT 가 있을 때만 defect; SUGGESTION 은 코멘트·결과에 선택 사항으로, Retry 대상에서 기본 제외; 계획 R-B 를 P23 재결정으로 뒤집음
- **S10** 🗣 발화 (premortem 처분 — 다중 선택 + 자유 입력):
  > ① 게시 payload·소음 (권장), ② e2e 감독·증거 신뢰 (권장), "1, 이전 장치는 너무 과했고 별로로 보임 바닥부터 지금에 맞게 새로 진행하는게 좋음 "
- **S11** 🗣 발화 (게시 백지 범위 질문에 대한 자유 응답):
  > 1, e2e도 그렇게 해주고 e2e를 진행하는거의 경우 구현중 실패가 많았다보니 그럴필요가 있겠어. 그리고 기존에 있던걸 가능하면 새로 짓는게 좋겠어 qg는 오래된 플러그인이다보니 지금 모델과 클로드 코드에 맞지 않는것들이 많을거야.
- **S12** ☑ 선택 (재건 범위):
  > qg 전체 재건 — 파이프라인·차등 테스트·판정 어휘·스크립트까지 새로; S1 「테스트 리뷰와 테스트 실행은 지금 장치로 충분하고 바꾸지 않는다」를 뒤집음(P23)
- **S13** ☑ 선택 (steelman ST3):
  > ST3 보완 (builder·orchestrator 추천) — 「가능하면 새로」를 구성요소별 기본 처분으로; 구성요소마다 한 줄 표(가정·1st-party 대체·교훈·처분)로 삭제/새로/유지(새 락·원장 없음); v10 을 옆에 세워 구성요소별 독립 PR·릴리스로 컷오버; 옛 교훈은 새 설계 요구 목록으로 먼저 이관; e2e·게시는 새로, 1st-party 대체분은 삭제
- **S14** ☑ 선택 (재구성된 문제정의):
  > 동의 — 진짜 문제: qg 결과가 믿을 검증 보고가 못 됨(네 면); 뿌리: 부품마다 박힌 옛 모델·Claude Code 가정 + 리뷰마다 장치를 덧붙여 온 공정; goal: 지금 모델·Claude Code 위 얇은 qg v10 을 구성요소별로 갈아끼워 /qg 한 번이 리뷰→테스트→(선택) e2e→PR 코멘트로 믿을 보고, 옛 교훈 보존
- **S15** ☑ 선택 (e2e 주체 — 뒤에 S17 이 뒤집음):
  > 걷기·판정 분리 — 오케스트레이터가 걷고 Read-only 판정 agent 가 raw 출력으로 판정 (→ S17 이 뒤집음)
- **S16** ☑ 선택 (e2e 자리):
  > 루프 끝 1회 + 실패 시 재진입 — 리뷰·테스트 루프 뒤(판정 직전) 한 번 e2e 질문·경로 제안; 실패 시 Fix-loop 결정 재표출, Retry 면 남은 iteration 안에서 리뷰·테스트·e2e 재실행
- **S17** 🗣 발화 (턴 중간 메시지):
  > 오케스트레이터만 다 걷고 판정하자
- **S18** 🗣 발화 (턴 중간 메시지):
  > law2를 지키기 위해서 너무 과한 장치가 생기는건 또 오히려 별로야
- **S19** ☑ 선택 (Law 2 정합):
  > 사람 감독 = reviewer — 오케스트레이터가 e2e 를 걷고 판정(판정안), 승인·뒤집기는 감독하는 사람; spec·헌장 해석에 한 줄, 장치 0, S5 증거 하한 유지
- **S20** ☑ 선택 (e2e 판정값):
  > fail=defect, 안 함·없음=공시 — e2e fail 은 defect; 「안 한다」·걸을 표면 없음은 판정 불변 + 코멘트 공시; 「걸을 것 없음」은 e2e 질문에서 사용자에게 보여 뒤집을 수 있게
- **S21** ☑ 선택 (코멘트 payload):
  > 판정 한 줄만 — 코멘트의 qg 결과는 판정·사유·개수 한 줄, 나머지는 로컬
- **S22** ☑ 선택 (재건 경계):
  > critique·공유 엔진은 밖 — /qg critique·spec-distill 공동 소유 docreview 엔진은 재건 제외(별 사이클); 토픽 스코프·codex 각도는 재건 안에서 한 줄 표로 처분
- **S23** ☑ 선택 (이관 방식):
  > 즉시 제거 — 사라지는 공개 표면·소비자 의존은 deprecation 창·공지 없이 바로 제거(헌장 one-minor 창 기본값을 사용자 결정으로 쓰지 않음)
- **S24** ☑ 선택 (미해결 목록 확인):
  > 이대로 확정 — brainstorming 으로 넘길 미해결 목록 OQ19~OQ25(한 줄 표의 실제 처분 · e2e 구체 형태 · 다이어트 과소 처방 경계 · 컷오버 순서와 dogfooding · 헌장 기록 두 줄 · plugin-audit 의존 · 「공정」 바꾸기)

## 7. 확산 원자료

- «codecov» — https://docs.codecov.com/docs/pull-request-comments — 코멘트 동작 default·once·new, 이메일은 새 코멘트 때만
- «cc-best-practices» — https://code.claude.com/docs/en/best-practices — 브라우저 검증·증거를 보이라·리뷰 gap 추격이 over-engineering 을 낳는다
- «playwright-mcp» — https://github.com/microsoft/playwright-mcp — 접근성 스냅숏, --caps=testing browser_verify_*
- «webtestbench» — https://arxiv.org/html/2603.25226v1 — default-correctness bias, F1<30%
- «google-eng» — https://google.github.io/eng-practices/review/reviewer/looking-for.html — over-engineering 정의
- «coderabbit» — https://docs.coderabbit.ai/reference/configuration — reviews.profile
- «arctic» — https://arxiv.org/abs/2607.29516 — 의도 추론·역번역 드리프트 탐지
- «green-oversight» — https://arxiv.org/abs/2109.05067 — 사람 감독 정책의 결함
- «automation-bias» — https://thedecisionlab.com/biases/automation-bias — 59% vs 97%, 누락 오류
- «webjudge» — https://arxiv.org/abs/2504.01382 — LLM-as-judge 약 85% 일치
- «cc-commands» — https://code.claude.com/docs/en/commands — /verify 사용자 호출 전용(v2.1.215)
- «cc-code-review» — https://code.claude.com/docs/en/code-review — 검증 단계·--comment·neutral·REVIEW.md
- «cc-34592» — https://github.com/anthropics/claude-code/issues/34592 — subagent AskUserQuestion 부재, not planned
- «invariant-mcp» — https://invariantlabs.ai/blog/mcp-github-vulnerability — 간접 주입 → GitHub 쓰기 유출
- «gh-secret-scope» — https://docs.github.com/en/code-security/reference/secret-security/secret-scanning-detection-scope — PR 코멘트 스캔은 public monitoring·사후
- «gh-edit-history» — https://docs.github.com/en/communities/moderating-comments-and-conversations/tracking-changes-in-a-comment — 편집 이력 공개
- «sticky-comment» — https://github.com/marocchino/sticky-pull-request-comment/blob/main/action.yml — recreate · hide_and_recreate
- «cca-720» — https://github.com/anthropics/claude-code-action/discussions/720 — 실행마다 쌓이는 코멘트, use_sticky_comment
- «harness-design» — https://www.anthropic.com/engineering/harness-design-long-running-apps — 부품 가정·하나씩 빼기·Playwright evaluator
- «building-agents» — https://www.anthropic.com/engineering/building-effective-agents — 가장 단순한 해법에서 시작
- «bssw-spolsky» — https://bssw.io/items/things-you-should-never-do-part-i — 재작성은 Thermonuclear Mistake, 점진 교체
- «second-system» — https://en.wikipedia.org/wiki/Second-system_effect — 두 번째 시스템 비대
- «aws-strangler» — https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/strangler-fig.html — 점진 이전, 작은 앱은 재작성이 효율적일 수도
- «willison-rewrites» — https://simonwillison.net/2019/Feb/19/lessons-6-software-rewrite-stories/ — 재작성 사례 6건
- «kodus-recall» — https://kodus.io/en/ai-code-review-recall/ — recall↔오탐 맞바뀜 (prober 출처, 처분 S10)
- «cisco-review» — https://static1.smartbear.co/support/media/resources/cc/book/code-review-cisco-case-study.pdf — 200~400 LOC (prober 출처, 처분 S10)
- «pwn-request» — https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/ — PR head 스크립트 실행 위험 (prober 출처, 처분 S10)
- «managed-agents» — https://www.anthropic.com/engineering/managed-agents — 하니스 가정이 dead weight 가 된다 (coverage-mapper #2 출처)
- «gh-65536» — https://github.com/orgs/community/discussions/27190 — 코멘트 65,536자 한도 (prober 출처, 처분 S10)

## 8. 리뷰 결정

- D1.1 · r1 · adopt · 0fbd6ae3#r1.1 · "고친다(채택) — spec 수 열어 둠" — Non-goal 「한 spec 으로 전체를 한꺼번에 백지에서 짓는 것(S13)」은 S13 을 근거로 단다. 그러나 S13 은 spec 의 수를 말하지 않고, S3 는 「spec 하나」를 골랐다. 이 Non-goal 이 「spec 하나」를 금하는지 「한꺼번에 백지 재건」만 금하는지 정해야 한다.
- D1.2 · r1 · adopt · 30e53be6#r1.1 · "고친다(채택) — 「과한」 복원" — Non-goal 「Law 2 를 지키려고 장치를 덧붙이는 것(S18)」은 S18 의 「너무 과한」을 떨어뜨렸다. 그래서 재건 전체에서 Law 2 장치 일체를 금하는 말이 됐다. 이 Non-goal 을 「과한」 장치로 좁힐지, e2e 의 「장치 0」(S19)으로 한정할지 정해야 한다.
- D1.3 · r1 · adopt · f0f95e2d#r1.4 · "고친다(채택) — 로컬에만 둠" — S9 는 SUGGESTION 을 「코멘트·결과에 선택 사항으로」 담는다고 했다. 나중의 S21 은 코멘트의 qg 결과를 「판정·사유·개수 한 줄, 나머지는 로컬」로 정했다. 두 원문이 갈리는데 §2(D24)는 S21 만 옮기고 대체 관계를 적지 않았다. SUGGESTION 이 코멘트에 실리는지 정해야 한다.
- D2.4 · r2 · adopt · f0f95e2d#r2.2 · "고친다(채택) — spec 하나 복원" — D28은 S3의 이음매 AC와 plan 병렬화는 옮겼지만, 함께 선택한 ‘spec 하나’ 제약은 빠뜨렸다. S13의 구성요소별 독립 PR·릴리스는 spec 수를 변경한다는 선택이 아니다.
- D3.5 · r3 · adopt · 41488ee9#r3.1 · "현재 변경 유지(채택) — 네 갈래 plan" — finding 없이 바뀜: 7. Next Action (modified)
- D3.6 · r3 · adopt · 9e5ecd9f#r3.1 · "현재 변경 유지(채택) — spec 하나" — finding 없이 바뀜: 1. Goal · Non-goal (modified)
- docreview 계수 — c39a2e50-b7ba-4999-ac48-2101dd3242f1/2026-10-03-qg-v10-rebuild-interview-ad7bd06ff618f54b r1: advice_new=2 · advice_repeat=1 · mc_preexisting_new=0
- docreview 계수 — c39a2e50-b7ba-4999-ac48-2101dd3242f1/2026-10-03-qg-v10-rebuild-interview-ad7bd06ff618f54b r2: advice_new=0 · advice_repeat=3 · mc_preexisting_new=0
- docreview 계수 — c39a2e50-b7ba-4999-ac48-2101dd3242f1/2026-10-03-qg-v10-rebuild-interview-ad7bd06ff618f54b r3: advice_new=1 · advice_repeat=2 · mc_preexisting_new=1
