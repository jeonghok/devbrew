---
name: qg-impact-driven-qa-runtime
type: interview-brief
created_at: 2026-07-26
session_id: 03f911a1-c81b-46e3-9741-4f1e8c38b2a4
source: spec-distill conducting-interview v0.22.0
next_phase: superpowers:brainstorming
locked_directions:
  - id: LD6
    statement: "문제=Runtime 게이트가 '무엇을 어떻게 돌릴지'를 정적 manifest+고정 격리 레시피로 굳혀 상황을 못 읽음. goal=임의 레포에서 변경을 읽고 계획→쉬운 설명→합의→실행하는 QA 동반자."
    source_path: d
    steelman: n/a
  - id: LD1
    statement: "container-runtime 기각 사유 = (2)범용성 상실 + (3)사용자 통제 상실. 'impact 개념 부재가 유일한 뿌리'는 사용자가 명시 기각."
    source_path: d
    steelman: n/a
  - id: LD3
    statement: "floor = 레포에 이미 있는 테스트 중 영향분을 골라 실제 실행하는 것까지가 무조건. 그 위에 상황별로 부팅/탐색적 검증 추가."
    source_path: b
    steelman: n/a
  - id: LD4
    statement: "계획과 결과를 사용자에게 '쉽게' 설명해야 한다 — 전문용어 나열이 아니라 이해 가능한 언어로."
    source_path: b
    steelman: n/a
  - id: LD5
    statement: "영향판정은 모델이 하고 결정론 신호는 보조 입력. 결정론은 '결과가 조용히 비었나'를 검사하는 반박불가 백스톱으로만. 배관은 기존 고정 계약이 기본값, 이탈은 이유와 함께 제안만."
    source_path: b
    steelman: switched-to-this
  - id: LD7
    statement: "루브릭은 질문형 floor + 의무 derived. 점수·테스트종류 메뉴 금지. spec-distill 커버리지 원장과 동형."
    source_path: b
    steelman: n/a
---

# qg Impact-Driven QA Runtime — Interview Brief (meta-prompt for brainstorming)

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §9대로 brainstorming
> 해답공간으로 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다.

## 1. Reframed Problem

*(도출: (d) ontological — ESSENCE + ROOT_CAUSE)*

**문제:** devbrew `quality-gates`의 Runtime 게이트는 *무엇을 어떻게 돌릴지*를 정적 manifest(`detect-runtime.sh`)와 고정 격리 레시피(disposable git-worktree → 컨테이너)로 **미리 굳혀놨다**. 계약에 리터럴로 박혀 있다 — `SKILL.md:667`: *"Runtime runs the whole app regardless of Review scope."* 그래서 레포·변경 상황에 맞는 테스트 전략이 나올 여지가 없고, 사용자가 그 전략을 보고 개입할 지점도 없다. **무엇을 돌릴지 못 정하니 남는 답이 "전부 안전하게 돌리기"뿐이었고, 그래서 노력이 격리 강화(worktree→컨테이너, ~10k줄)로 흘렀다.**

**진짜 goal:** 임의의 레포에 놓아도 — *이번 변경이 무엇을 건드렸는지* 읽고 → 그 상황에 맞는 테스트 계획을 세워 → **사람이 이해할 언어로** 알리고 → 합의된 대로 실제로 돌려 결과를 남기는 **QA 동반자**.

**설계 표어:** 격리는 목적이 아니라 부수 조건이다. 산출물은 인프라가 아니라 **"이 변경으로 무엇이 달라지고, 그중 무엇을 실제로 확인했는가"** 다.

## 2. Locked Directions

재논쟁 금지. brainstorming의 기정사실.

- **LD6 (문제정의)** — §1 그대로. 문제는 "impact 개념 부재"가 아니라 **"게이트가 상황을 못 읽음"**.
- **LD1 (기각 사유)** — container-runtime이 틀린 이유는 ①범용성 상실(컨테이너 레시피는 특정 스택 가정) + ②사용자 통제 상실(계획 합의 없이 전체 실행). *"impact 부재가 유일한 뿌리"라는 진단은 사용자가 명시적으로 기각했다* — 이걸 다시 뿌리로 세우지 말 것.
- **LD3 (floor)** — "실제로 돌려본다"의 최소 보장은 **레포에 이미 있는 테스트 중 영향분을 골라 실행**하는 것까지. 그 위(부팅/플로우/탐색적 검증)는 상황별 재량. *"증거만 남으면 방법은 자유"는 기각됨.*
- **LD4 (설명 의무)** — 계획과 결과를 **쉽게** 설명해야 한다. 전문용어 나열은 산출물 실패로 친다.
- **LD5 (하이브리드 — 역할 반전)** — 영향판정은 **모델**이 한다(import/의존 그래프·러너 관례·git diff는 *보조 입력*). 결정론은 권위가 아니라 **"결과가 조용히 비었나 / 변경이 있는데 안 돌렸나"를 검사하는 반박불가 백스톱**으로만 쓴다. 누락 방향 실패 금지(불확실하면 과선택)는 유지. **배관**(격리 방식·실행 환경)은 기존 고정 계약이 기본값이고, 모델은 *이유와 함께 이탈을 제안*만 할 수 있다.
- **LD7 (루브릭 모양)** — 질문형 floor + **의무** derived. floor 예: *무엇이 바뀌었나 / 그게 어떤 행동에 닿나 / 어떻게 확인하나 / 못 확인하는 건 뭔가*. 점수형·테스트종류 메뉴 금지(천장이 됨). `spec-distill` 커버리지 원장(floor 5 + derived)과 동형 — 이미 이 레포에서 검증된 모양.

## 3. External Landscape

- **Meta predictive test selection** — ML로 변경 특성 기반 테스트 선택. 프로덕션 계약이 *'판단'이 아니라 **보장된 recall***(개별 실패 95%+, 결함 변경 99.9%+ 유지, 인프라 비용 절반) — https://arxiv.org/abs/1810.05286 — **[중립]** — 우리는 ML 학습 자산이 없어 그대로 못 씀. 단 *"선택기의 산출물은 판단이 아니라 보장이어야 한다"*는 요구 수준은 가져온다.
- **Meta 엔지니어링 블로그(동 주제)** — "20%만 실행해도 실패의 ~90% 포착" — https://engineering.fb.com/2018/11/21/developer-tools/predictive-test-selection/ — **[중립]** — 영향 선택의 경제성이 실재함을 보여주는 존재 증명.
- **Nx `affected`** — git diff + project graph 순수 결정론. 알려진 실패(lockfile 변경 시 전 프로젝트 과잉선택)는 **안전한 방향으로만** 편향 — 누락 방향으로 실패 불가능한 구조 — https://nx.dev/docs/features/ci-features/affected , https://github.com/nrwl/nx/issues/30271 — **[피함(권위로서)]/[취함(설계 교훈으로서)]** — Nx workspace 전제라 범용 플러그인엔 부적합. 그러나 **"틀리더라도 과선택 방향으로만 틀려라"** 는 LD5에 그대로 흡수.
- **pytest-testmon** — coverage.py로 테스트↔실행코드 의존성 수집, 변경과 대조해 선택. VCS 독립 — https://github.com/tarpas/pytest-testmon/ — **[중립]** — coverage 계측 전제. 있는 레포에선 최상급 *보조 입력*.
- **정적 RTS의 unsafe 문제** — reflection/동적 디스패치/동적 로딩이 있으면 static RTS는 영향받는데 미선택(unsafe) — https://lingming.cs.illinois.edu/publications/oopsla2019.pdf , https://dl.acm.org/doi/10.1145/3360613 — **[취함]** — LD5의 "결정론은 권위 아님" 근거.
- **LLM 코드분석 hallucination** — 존재하지 않는 API/의존성 생성에 취약; LLM 자기재확인은 *"비결정적 도박"*. 결정론적 AST 정적분석은 200 샘플 100% precision / 87.6% recall — https://arxiv.org/abs/2601.19106 — **[취함]** — 모델 판정에 백스톱이 필요한 근거(LD5의 나머지 절반).
- **RTS의 비용 비대칭** — false negative는 결함을 조용히 production으로, false positive는 비용만 증가 — https://arxiv.org/pdf/2604.26689 — **[취함]** — "불확실하면 과선택" 규칙의 근거.
- **PR risk scoring (churn / hot spot / ownership / 유사 편집의 과거 실패)** — https://allyticstechperspectives.com/how-ai-driven-qa-testing-predicts-risk-before-deployment/ — **[피함]** — LD7이 점수형 루브릭을 금지. 단 *신호* 로는 읽을 수 있음.
- **QA 관점의 핵심 문장** — *"PR은 코드가 뭐가 바뀌었는지는 말하지만 행동이 어떻게 달라지는지는 말하지 않는다 — QA는 후자를 원한다"* — https://shiftsync.tricentis.com/software-testing-blogs-69/3-ways-i-use-ai-for-predictive-qa-2614 — **[취함]** — §1 goal의 압축 표현.
- **Approval fatigue / Explainability Paradox** — 반복 승인은 rubber-stamp로 수렴하고, 설명이 명확할수록 재검토를 덜 한다 — https://getmrmr.com/blog/approval-fatigue , https://tianpan.co/blog/2026-04-15-human-in-the-loop-rubber-stamp , https://molten.bot/blog/agent-approval-fatigue/ — **[취함(경고로서)]** — LD4의 역효과 경로. OQ2 참조.

**사내 prior-art (재발명 금지).** 이 세 건은 *외부* landscape가 아니라 이 레포가 이미 지불한 학습비다 — URL이 아니라 file:line이 출처다.

| 위치 | 무엇 | 이 설계에 대한 함의 |
|---|---|---|
| `plugins/quality-gates/scripts/check-review-scope.sh:2-8` | v2.6.0→v2.7.0에서 스크립트 책임을 *"스코프가 비었나"* → *"변경이 존재하나"* 로 좁히고 주석에 **"Scope resolution (WHAT to review) is the MODEL's responsibility now"** | **LD5가 이식하려는 바로 그 모양이 Review 게이트에 이미 착지해 있다.** 결정론=백스톱, 판정=모델. |
| `plugins/quality-gates/scripts/check-review-scope.sh:43-79` | merge-base / shallow clone / detached HEAD / remote-only default branch를 다루는 baseline 계산. 3라운드 하드닝의 산물 | Runtime이 독자 구현하면 같은 버그 클래스를 처음부터 다시 겪는다 (OQ5). |
| `plugins/quality-gates/agents/adversarial.md:45,134` | Review 게이트의 *"pre-existing → downgrade"* 개념 | 실행 결과 판정용 대응물은 **없음** — OQ1이 채워야 할 빈칸. |

**로컬 하니스 선례 (`~/Downloads/reference/`, 인터뷰 종료 후 스캔).** 논문·도구가 아니라 **실제로 돌아가는 에이전트 하니스**다. 셋 다 우리가 만들려는 것과 같은 층위이며, 스캔은 얕았다 — §9의 재탐색 대상.

| 출처 | 무엇 | [판정] 이 설계에 대한 함의 |
|---|---|---|
| `gstack/qa/SKILL.md:1155-1199` — **diff-aware mode** | Diff-aware를 *primary mode*로 두고 Full/Quick/Regression과 함께 4개 **명명 모드**로 운영. `git diff main...HEAD` + `git log main..HEAD` | **[취함]** 가장 가까운 선례. 모드에 이름을 붙이면 LD5의 모델 재량이 LD4의 "쉬운 설명"과 양립한다 — 사용자는 *어느 모드로 갔는지*만 들으면 된다. |
| `gstack/qa/SKILL.md:1173` — **빈 스코프 fail-safe** | *"If no obvious pages/routes are identified from the diff: **Do not skip** browser testing… Backend, config, and infrastructure changes affect app behavior — always verify the app still works."* | **[취함]** FM4/false-clean을 **스크립트가 아니라 프로즈로** 막는다. LD5의 백스톱을 결정론 코드 없이 표현한 형태 — 우리 설계가 그대로 쓸 수 있다. |
| `gstack/qa/SKILL.md:1190` — **의도 대조** | commit message + PR description으로 *무엇을 해야 하는지*를 읽고 "실제로 그걸 하는지" 검증 | **[취함]** §1 goal의 *"행동이 어떻게 달라지나"* 를 실행 단계에 앉히는 구체적 지점. |
| `gstack/qa/SKILL.md:1136-1147` — **신호 우선순위 사슬** | *"Before falling back to git diff heuristics, check for richer test plan sources"* → 명시적 test plan > 대화 컨텍스트 > git diff 휴리스틱 | **[취함]** LD5의 "결정론 신호는 보조 입력"을 등급으로 구체화. diff는 최상위 신호가 아니라 **fallback**이다. |
| `gstack/qa/SKILL.md:936-1096` — **test bootstrap** | runtime 감지 → 프레임워크 있으면 기존 테스트 2–3개 읽어 컨벤션 학습 / 없으면 `AskUserQuestion`(H안 = "이 프로젝트는 테스트 불필요" → `.gstack/no-test-bootstrap` opt-out marker) | **[취함]** **LD3 floor가 테스트 0개 레포에서 무엇을 하는가**의 기성 답. opt-out marker로 매번 되묻지 않는 것까지 포함. |
| `gstack/qa/SKILL.md:1128-1134` — **가시적 compounding** | *"Prior learning applied: [key] (confidence N/10, from [date])"* 를 사용자에게 출력 | **[취함]** devbrew Law 3의 거의 문자적 instantiation — 축적을 *보이게* 만든다. |
| `compound-engineering-plugin/skills/ce-test-browser/SKILL.md:51` — **매핑 판단 위임** | 파일→라우트 매핑 표 + *"a starting point of common patterns, **not an exhaustive rule set — apply judgment** for the project's actual layout"* | **[취함]** LD5를 이미 한 문장으로 못박아 놓은 선례. 표는 입력이지 규칙이 아니다. |
| `.../ce-test-browser/SKILL.md:143,169` — **manual vs pipeline mode** | pipeline 모드에선 *묻지 않고* Skip을 이유와 함께 로그. manual 모드에서만 사용자에게 질문 | **[취함]** **OQ2(승인 피로)의 구조적 답 후보** — 볼 사람이 없을 때 묻지 않으면 rubber-stamp가 생길 자리가 없다. |
| `.../ce-test-browser/SKILL.md:145-151` — **자동화 불가 경계** | OAuth / Email / Payments / SMS / External API를 표로 명시하고 사람에게 넘김. 결과는 PASS/FAIL/**PARTIAL** 3값 | **[취함]** LD7 floor 질문 *"못 확인하는 건 뭔가"* 의 구체형. PARTIAL이 정직함을 담는 그릇. |
| `.../ce-test-browser/SKILL.md:70` — **신호 신뢰도 등급** | *"prose mentions (docs, examples, troubleshooting) are unreliable and false-positive-prone — config files and `.env` are the trustworthy sources"* | **[취함]** 같은 정보라도 **어디서 왔느냐로 신뢰도를 나눈다** — LD5 보조 입력 등급화의 실례. |
| `oh-my-codex/skills/ultraqa/SKILL.md:36-51` — **scenario matrix** | id / intent / user-attacker model / setup / command·harness / expected signal / actual result / fixes / evidence / **cleanup status** | **[취함]** *"계획을 세워 사용자에게 알린다"* 의 산출물 형태 그 자체. LD3 floor **위**에 얹는 탐색적 층. |
| `.../ultraqa/SKILL.md:49-50` — **적대 클래스 2종** | *flaky tests*("avoiding false green from a single lucky pass") + *misleading success output*("success phrases with non-zero exits, hidden failures, skipped tests") | **[취함]** devbrew가 반복해 맞은 결함과 같은 클래스. OQ1에 **인접**하나 해결책은 아님(아래 참조). |
| `.../ultraqa/SKILL.md:59,68,121-125` — **격리 없는 안전 규율** | *"Do not delete, rewrite, or mask unrelated user work. Capture dirty-worktree evidence before and after"* + cleanup/rollback 단계 + 하니스 setup 실패를 **harness debris로 별도 분류**(제품 결함 선언 금지) | **[취함]** **샌드박스를 버린 자리를 메우는 조각.** 컨테이너가 구조로 주던 보호를 규율로 대체하는 유일한 선례 — LD1이 격리를 뺐으므로 이게 필수다. |
| `.../ultraqa/SKILL.md:72,145-148` — **bounded 루프** | max 5 cycles + same-failure-3x early exit + Safety Bounds 목록(무한 대기·파괴적 명령·secret 유출 금지) | **[취함]** devbrew Forbidden *"Unbounded autonomy"* 를 이미 만족하는 형태. |
| `ECC/.agents/skills/verification-loop/SKILL.md` | npm/tsc/ruff를 6 phase로 하드코딩 + coverage 80% 고정 임계 + `git diff HEAD~1` | **[피함 — 반례]** LD7이 금지한 **천장형 체크리스트**의 교과서적 예. UltraQA가 자기 "Bad" 예시로 정확히 이걸 지목한다: *"runs only npm test/build/lint/typecheck, sees green output, and declares complete without adversarial e2e coverage."* 두 레퍼런스가 서로에 대해 판정을 내려놨다. |
| `ouroboros/skills/qa/SKILL.md:29-35` | 0.0–1.0 점수 + 0.80 PASS 임계 + 5개 차원 스코어링 | **[피함 — 구조]** LD7이 기각한 점수형. |
| `ouroboros/skills/qa/SKILL.md:74-90` | *"Acting verification — reproduce and OBSERVE before judging… A text judge can be fooled by a hopeful log line."* | **[취함 — 문장만]** LD3 floor가 *실제 실행*이어야 하는 이유의 가장 압축된 표현. |

## 4. Skepticism Log

- **대안 (steelman-builder verbatim):** *"PR 영향 범위 판정('무엇이 깨질 수 있는가')과 실행 배관('무엇을, 어떤 격리로 돌릴 것인가')은 결정론적 메커니즘 — 의존성/프로젝트 그래프(Nx affected, Bazel), coverage 기반 매핑(pytest-testmon), 또는 사전 학습되었지만 recall이 보장·검증된 선택기(Meta predictive test selection) — 가 전담해야 한다. LLM은 그 결정론적 산출물을 해석·요약·우선순위화하고 사용자에게 설명하는 역할만 맡아야 하며, '무엇을 어떻게 돌릴지'를 매 실행마다 상황 판단으로 재발명해서는 안 된다."* — 근거 https://arxiv.org/abs/1810.05286 , https://arxiv.org/abs/2601.19106 , https://nx.dev/docs/features/ci-features/affected , https://arxiv.org/pdf/2604.26689 — **verdict: switched**

  builder가 제기한 원안의 약점: (1) 같은 PR에 실행마다 다른 selection → **재현성 없음**, QA 게이트(반복가능 pass/fail)와 정면충돌 (2) devbrew 자신의 Forbidden Pattern *"Unbounded autonomy"* 해당 위험 (3) 이미 있는 `detect-runtime.sh` 결정론 manifest를 무효화하는 **후퇴**.

  builder가 인정한 원안 생존 조건: 결정론 그래프가 애초에 없는 레포(polyglot/스크립트 모음)에선 여지 있음. 단 원안 그대로는 방어 불가, **하이브리드로 축소될 때만 생존**.

  전환 경위: 사용자가 부분 전환(하이브리드)을 선택해 LD5가 성립했고, 이후 round 6에서 premortem 근거로 **한 번 더 개정**되어 결정론의 역할이 *권위*에서 *백스톱*으로 반전됨. 배관 절반은 builder 주장대로 기존 고정 계약을 기본값으로 수용.

## 5. Blind Spots & Premortem

blind-spot-prober 1회 dispatch (C8). 인용 2건은 orchestrator가 직접 검증했다.

**숨은 가정**
- 숨은 가정: LD5의 "결정론 신호가 있으면 신뢰할 만하다" — 왜 위험: static RTS는 reflection/동적 디스패치/동적 로딩에서 *"있는데 틀리는"* unsafe 실패를 낸다. 신호가 **존재하므로** 과선택 백스톱이 발동하지 않고 초록불이 뜬다. devbrew 대상 레포 다수(Python/JS/bash)가 이 부류 — https://lingming.cs.illinois.edu/publications/oopsla2019.pdf — **[round 6에서 LD5 개정으로 닫힘]**
- 숨은 가정: "결정론 신호가 권위"가 새 원칙이다 — 왜 위험: 이 레포는 **이미 반대 방향으로 진화**했다. `check-review-scope.sh:2-8`이 스코프 판정을 모델로 이관했고(반복된 false-clean 때문), 결정론은 백스톱으로만 남겼다. 폐기된 아키텍처를 다른 이름으로 재도입할 뻔했다 — codebase: `plugins/quality-gates/scripts/check-review-scope.sh:2-8` [orchestrator 직접 검증 CONFIRMED] — **[round 6에서 닫힘]**
- 숨은 가정: baseline(merge-base) 계산은 자명하다 — 왜 위험: 동일 계산이 Review 게이트에서 3라운드 하드닝(v2.6.0 scope-capture → v2.7.0 detector-simplification → empty-scope-guard)을 거쳤고 매번 self-dogfood가 새 fail-open을 적발했다. Runtime이 독자 구현하면 그 버그 클래스를 처음부터 다시 겪는다 — codebase: `check-review-scope.sh:43-79` — **[OQ5로 이월 — 사용자 미확인]**
- 숨은 가정: LD4(쉬운 설명) + 합의 게이트가 사용자 개입 지점을 만든다 — 왜 위험: 문헌은 반대를 보고한다. 설명이 명확할수록 재검토의 한계효용을 낮게 느껴 더 의존(Explainability Paradox)하고, 반복 승인은 볼륨이 쌓이면 습관적 approve로 수렴한다 — https://getmrmr.com/blog/approval-fatigue , https://tianpan.co/blog/2026-04-15-human-in-the-loop-rubber-stamp — **[OQ2 미해결]**
- 숨은 가정: floor 실행의 fail은 "PR이 깼다"로 해석 가능하다 — 왜 위험: pre-existing red / flaky / 신규 회귀를 구분하는 메커니즘이 **실행 결과 판정 문맥에 존재하지 않는다**(Review용 `adversarial.md:45` "pre-existing → downgrade"는 있으나 실행 결과용 대응물 없음). devbrew 자신이 stale red 다수 보유 — codebase 부재 + `project_qg_pre_existing_test_reds` — **[OQ1 미해결]**

**실패 양식**
- 실패 양식: 정적 신호가 조용히 틀려 영향 테스트가 스킵되고 게이트가 초록불 — trigger: reflection/monkey-patch/동적 import/플러그인 레지스트리 패턴이 있는 동적 언어 레포 — https://lingming.cs.illinois.edu/publications/oopsla2019.pdf — **[LD5 개정으로 닫힘]**
- 실패 양식: 쉬운 설명이 실제 실행 범위보다 넓게 들려(overclaiming) 커버리지 과신 + 반복 승인 습관화로 게이트 형해화 — trigger: 동일 세션/PR 내 반복되는 계획→승인→실행 사이클 — https://molten.bot/blog/agent-approval-fatigue/ — **[OQ2]**
- 실패 양식: "불확실하면 보수적 과선택"이 실전에서 거의 매번 **전체 실행**으로 수렴해 LD1이 기각한 container-runtime의 경제성 문제가 뒷문으로 재발 — trigger: 대부분의 실전 레포가 위 트리거에 해당해 신호가 자주 '불확실' 판정 — *프로버 자인: 추론적 확장, 직접 실증 아님* — **[OQ3]**
- 실패 양식: Runtime의 자체 스코프 계산이 Review가 이미 고친 baseline 버그 클래스(merge-base 오판 → 빈 스코프 → false-clean)를 재발 — trigger: 독자 구현하거나 브랜치 히스토리 없는 로컬 커밋前 세션에서 호출 — codebase: `check-review-scope.sh` — **[OQ5]**
- 실패 양식: pre-existing red를 "내 PR이 깼다"로 오귀속, 또는 진짜 회귀를 pre-existing으로 오분류해 숨김 — trigger: 테스트 스위트가 100% green이 아닌 레포 — memory `project_qg_pre_existing_test_reds` — **[OQ1]**
- 실패 양식: Runtime 판정 스코프가 레포 CI의 test-selection과 달라 로컬 qg 초록/CI 빨강이라는 두 '진실'이 생김 — trigger: 대상 레포가 이미 자체 test-selection을 CI에 보유 — *프로버 자인: 근거 URL 없음, 아키텍처 추론* — **[OQ4]**

## 6. Coverage Ledger

- floor:root_problem — closed — R1 A안 locked(LD6): 게이트가 무엇을/어떻게 돌릴지를 정적 manifest+고정 격리로 굳혀 상황을 못 읽음. goal=임의 레포에서 변경을 읽고 계획→쉬운 설명→합의→실행하는 QA 동반자. (d) ESSENCE+ROOT_CAUSE로 도출, round 1·4.
- floor:landscape — closed — sweep1 3콜(TIA/predictive-test-selection/nx affected/pytest-testmon/PR risk scoring) + steelman sweep2 4 URL + 사내 prior-art 3건. 전부 인용과 함께 §3에 [취함|피함|중립]+이유로 기록.
- floor:skepticism — closed — steelman-builder 1회 dispatch(결정론 전담 대안, 근거 4 URL) → 사용자 부분전환(하이브리드, LD5) → premortem 근거로 round 6 재개정(권위→백스톱). verdict=switched, §4 기록.
- floor:blind_spot — closed — blind-spot-prober 1회 dispatch(C8): hidden assumption 5 + failure mode 6, 근거 URL/file:line 첨부. 인용 2건(check-review-scope.sh:2-8, pre-existing grep) orchestrator 직접 검증 — 1건은 프로버 주장 과장을 교정. 전부 §5 기록 후 사용자에게 표면화(round 7).
- floor:open_questions — closed — round 7에서 4항목을 권장 해법과 함께 제시했으나 **사용자 미응답 → 보류로 처리**(재질문 금지, P17). OQ1–OQ4로 박제. 추가로 orchestrator가 질문 없이 채택하려던 baseline 재사용 제약도 침묵≠동의 원칙에 따라 OQ5로 강등. 유추 금지.
- derived: N/A — floor 5차원이 전 probe를 소진했고, coverage-mapper dispatch 조건(연속 3 probe 무진전)이 한 번도 발화하지 않음(매 probe마다 status 전이 또는 evidence append 발생).

## 7. Tried & Discarded

- **컨테이너/워크트리 격리 강화 (qg v2.14.0 시도, 64커밋 / 약 +10000줄 — `qg-container.sh` 2451줄, `parse-spec-runtime.py` 343줄, credential delivery)** → 버린 이유: 목적이 아니라 부수 조건인 격리에 노력이 전부 갔고, *"이 PR로 무엇이 깨지나"* 에 대한 답은 한 줄도 늘지 않았다. 범용성 상실(스택 가정) + 사용자 통제 상실(계획 합의 없이 전체 실행). **폐기 완료 — 코드는 남아 있지 않다. 이 항목은 재탐색 차단용 기록이다.**
- **"impact 개념 부재가 유일한 뿌리"라는 진단** → 사용자가 명시 기각. 뿌리는 범용성+통제이지 impact 하나가 아니다. 이 진단으로 되돌아가면 또 하나의 단일축 최적화가 된다.
- **floor를 "증거만 남으면 방법은 자유"로 잡는 안** → 기각. 실행 없는 증거는 QA가 아니다. floor는 LD3(기존 테스트 영향분 실제 실행).
- **LD2 원형 — "인프라·배관 레벨까지 매 실행마다 모델이 상황 판단"** → steelman이 이 절반을 가장 세게 쳤고(재현성 부재, 기존 고정 계약과 직접 충돌), 부분 전환으로 축소. 배관은 고정 계약이 기본값, 모델은 이유와 함께 이탈 제안만.
- **LD5 원형 — "결정론 신호가 있으면 그것이 권위"** → premortem이 문헌(static RTS unsafe)과 자기 코드(`check-review-scope.sh:2-8`이 이미 반대 방향으로 진화) 두 근거로 반박. 역할 반전(백스톱)으로 개정. **이 레포가 이미 폐기한 아키텍처였다.**
- **점수형·체크리스트형 루브릭** → 기각(LD7). 답을 열거하는 루브릭은 천장이 되어 모델이 목록까지만 하고 멈춘다(satisficing). 질문을 열거해야 바닥이 오른다.

## 8. Open Questions

미해결. **유추 금지** — 해답공간에서 결정할 것. OQ1–OQ4는 round 7에서 권장 해법과 함께 제시됐으나 사용자가 응답하지 않아 보류 처리됐다(권장 해법은 *제안*일 뿐 합의 아님).

- **OQ1 — pre-existing red / flaky / 신규 회귀를 어떻게 구분하는가?** LD3의 floor는 "영향분 테스트 실행"인데, 그 fail을 *내 변경 탓*으로 귀속할 근거가 현재 설계에 없다. devbrew 자신이 stale red를 다수 보유해 첫 실행부터 문제가 된다. *제안(미합의): 기준선에서 먼저 돌려 green/red를 찍고 변경 적용 후와 차등 비교. 차등 실행이 불가능하면 "pre-existing 의심"으로 표기하되 침묵 금지.*
  **§3 레퍼런스 스캔 결과: 어느 하니스도 이걸 풀지 않았다.** gstack regression 모드는 *이전 실행의* `baseline.json`과 비교(변경 *전 코드 상태*가 아님), UltraQA의 flaky는 재실행·클러스터링 *규율*이지 메커니즘이 아니며, harness-debris 분류는 하니스 자신이 대상이다. **위 제안이 레퍼런스보다 앞서 있으므로 설계에서 새로 만들어야 한다** — 이 brief에서 가장 mature-reference가 없는 지점.
- **OQ2 — LD4(쉬운 설명)와 합의 게이트가 rubber-stamp로 수렴하는 걸 어떻게 막는가?** 문헌상 설명 품질이 높을수록 검토는 얕아지고, 반복 승인은 습관화된다. *제안(미합의): 설명에 "돌린 것 / 안 돌린 것"을 항상 나란히 제시하고, 승인 게이트는 매 실행이 아니라 계획이 직전과 실질적으로 달라졌을 때만 발화.*
  **§3 답 후보 있음(미합의):** CE `ce-test-browser`의 **manual / pipeline 이원화** — pipeline에선 아예 묻지 않고 Skip을 이유와 함께 로그한다. 볼 사람이 없을 때 묻지 않으면 rubber-stamp가 생길 자리가 없다. 재탐색 시 `references/pipeline-orchestration.md` 통독 필요.
- **OQ3 — "불확실하면 과선택"이 실전에서 전체 실행으로 수렴하면?** 그러면 LD1이 기각한 container-runtime의 경제성 문제가 뒷문으로 재발한다. *제안(미합의): 계획 제시 시 범위와 예상 비용을 먼저 알려 사용자가 줄일 수 있게. floor는 유지.* (프로버 자인: 이 실패 양식은 추론적 확장이며 직접 실증은 없음)
  **§3 부분 답:** gstack의 **명명 모드**(Quick 30초 / Diff-aware / Full 5–15분)가 비용 등급을 이름으로 노출한다 — 사용자가 "전체 실행"을 *선택*하는 것과 게이트가 거기로 *수렴*하는 것은 다르다.
- **OQ4 — 레포 CI가 이미 test-selection을 하고 있으면 '두 진실'을 어떻게 다루는가?** *제안(미합의): CI 설정을 신호로 읽고 차이를 설명하되 대체하지 않음.* (프로버 자인: 근거 URL 없음, 아키텍처 추론 — 4항목 중 유일하게 근거 미확보)
  **§3 스캔 결과: 어느 레퍼런스도 다루지 않았다.** gstack은 CI 파이프라인을 *생성*하지만(`:1036` B5.5) 기존 CI의 test-selection과 조율하지는 않는다.
- **OQ5 — Runtime의 baseline 계산은 Review 게이트 로직을 재사용해야 하는가?** orchestrator가 "질문 없이 채택할 제약"으로 제시했으나 사용자 응답이 없었다. 침묵은 동의가 아니므로 미확정. *제안(미합의): `check-review-scope.sh`의 merge-base/shallow/detached/remote-only 처리를 재사용하고 Runtime 전용 신규 구현 금지 — 3라운드에 걸쳐 지불한 학습비를 다시 내지 않기 위해.*
- **OQ6 — 산출물의 단위는 무엇인가?** 이 재설계가 (a) 기존 `quality-gates` Runtime 게이트의 개정인지, (b) 별도 게이트/플러그인 신설인지 인터뷰에서 다루지 않았다. LD5가 기존 `qg-worktree.sh`/`detect-runtime.sh` 계약을 기본값으로 재사용한다고 못 박았으므로 (a) 쪽으로 기울지만, 명시적으로 확인된 바 없다.
  **§3 스캔 결과:** gstack·CE·oh-my-codex 셋 다 **command + skill 한 쌍**으로 구현했고 별도 플러그인이 아니다 — (a)를 지지하는 수렴 증거.

**갱신 이력.** §3의 "로컬 하니스 선례" 표와 위 §3 교차참조는 **인터뷰 종료 후** `~/Downloads/reference/` 스캔으로 추가됐다. 인터뷰 자체가 도달한 결론(§1·§2·§4·§5·§7)은 그 스캔 이전의 것이며 수정되지 않았다 — 즉 LD5(결정론=백스톱)는 레퍼런스를 보고 정한 게 아니라 steelman·premortem으로 독립 도달한 뒤 레퍼런스에서 같은 모양을 *확인*한 것이다.

## 9. Concrete Next Action

이 brief를 context로 `superpowers:brainstorming` 호출 → `docs/superpowers/specs/<date>-<topic>-design.md` → `spec-distill:spec-reviewer` 검증 → `superpowers:writing-plans`.

### 선행 필수 — 로컬 하니스 재탐색 (얕은 스캔을 깊은 독해로)

§3의 "로컬 하니스 선례" 표는 **grep + 부분 읽기로 만든 얕은 결과**다. 설계 착수 전에 아래 셋을 **전문 통독**할 것 — 바닥부터 만들기 금지([[feedback_prefer_mature_references_over_scratch]])이며, 이 셋은 우리가 만들려는 것과 *같은 층위에서 이미 돌아가는* 하니스다.

| 재탐색 대상 | 왜 다시 읽어야 하나 |
|---|---|
| `~/Downloads/reference/gstack/qa/SKILL.md` (1684줄) | 앞 ~640줄은 gstack 공통 preamble이라 **건너뛰었고**, 실제 QA 워크플로우(Phase 1–8, `:1212` 이후)는 헤딩만 봤다. 특히 Phase 8e/Step 7(테스트 작성), `:1330` baseline 저장 포맷, `:1341-1345` regression diff 로직, `:1447` 산출물 트리는 **미독**. 4개 모드의 실제 전환 조건도 미확인. |
| `~/Downloads/reference/compound-engineering-plugin/skills/ce-test-browser/` (SKILL.md 241줄 + `references/pipeline-orchestration.md` 2.8KB + `references/agent-browser-driver.md` 1.7KB) | `references/` 두 파일을 **안 열었다**(실재 확인만 함). manual/pipeline 이원화가 OQ2의 답 후보인데 그 절반이 미독. CE의 다른 34개 스킬(`ce-code-review`·`ce-debug`·`ce-babysit-pr`·`ce-proof`)에도 impact/영향 개념이 grep에 걸렸으나 미확인. |
| `~/Downloads/reference/oh-my-codex/skills/ultraqa/SKILL.md` (263줄) | 통독은 했으나 **자매 구현 2개 미대조**: `oh-my-claudecode/skills/ultraqa/SKILL.md`(152줄, 더 짧음 — 무엇을 덜어냈는지가 정보) 및 `oh-my-codex/plugins/oh-my-codex/skills/ultraqa/`. 참조하는 `/prompts:architect`·`/prompts:executor`·`/prompts:qa-tester` 정의도 미확인. |

미탐색이 확인된 것 — `ECC/agents/e2e-runner.md`(frontmatter만 봄), `ECC/.agents/skills/e2e-testing/`, `ECC/commands/test-coverage.md`, `gbrain/skills/testing/`, `gbrain/skills/smoke-test/`, `Understand-Anything`(영향 그래프 관점에서 미검토).

### brainstorming 진입 시 우선 다룰 것

1. §1 goal의 4단계(읽기 → 계획 → 쉬운 설명 → 합의 후 실행)를 어떤 컴포넌트 경계로 나눌지 — gstack의 **명명 모드**(Diff-aware/Full/Quick/Regression)가 유력 후보. 모드에 이름이 있으면 LD5 모델 재량과 LD4 쉬운 설명이 양립한다.
2. LD7 질문형 루브릭의 floor 질문 집합 확정(4개가 맞는지, derived 의무를 어떻게 강제할지).
3. OQ1(pre-existing red)과 OQ6(산출물 단위) — 이 둘이 설계 형태를 가장 크게 가른다. **OQ6는 레퍼런스 3개 모두 "command + skill 한 쌍"으로 수렴** — 별도 플러그인이 아니다.
