---
name: brief-restructure
type: interview-brief
created_at: 2026-08-30
session_id: c4c0ff2f-6024-4d33-a35b-840ac08c72b7
source: spec-distill conducting-interview v0.41.0
next_phase: superpowers:brainstorming
audit_file: 2026-08-30-brief-restructure-interview.audit.md
user_sourced_items:
  - id: C1
    source: verbatim
    status: confirmed
    statement: "하류에 audit 으로 넘기는 내용들이 넘어가기 때문에 컨텍스트를 흔든다고 생각했다"
    evidence: S2
  - id: C2
    source: verbatim
    status: confirmed
    statement: "brief 로 완결되어야 한다"
    evidence: S3
  - id: C3
    source: verbatim
    status: confirmed
    statement: "외부 URL 은 잘못 찾아온 자료로 문제 방향을 이상하게 잡게 만든 적이 많다"
    evidence: S4
  - id: C4
    source: chosen
    status: confirmed
    statement: "payload 에는 압축 항목만 남기고 §6 사용자 원문은 전량 audit 으로 옮긴다. frontmatter YAML 형태는 유지해 파서를 재작성하지 않는다"
    evidence: S5
  - id: C5
    source: chosen
    status: confirmed
    statement: "payload 항목은 id·statement·status·⟨S<N>⟩ 를 유지하고, audit 으로는 SUPERSEDED 이력과 원문 대조만 보낸다"
    evidence: S15
  - id: C6
    source: verbatim
    status: confirmed
    statement: "1차 출처도 너무 specific 한 논문 자료가 오는 경우가 많고, URL 을 읽을 때 그 내용만 넘어오지 않아 방향과 맥락이 완전히 달라진다 — 근본 해결이 어렵다"
    evidence: S7
  - id: C7
    source: verbatim
    status: confirmed
    statement: "audit 에 두는 것이지, 필요한 경우에만 보면 된다"
    evidence: S8
  - id: C8
    source: chosen
    status: confirmed
    statement: "출처 «키» + 직접인용은 payload, URL 은 audit 에만 둔다"
    evidence: S17
  - id: C12
    source: chosen
    status: confirmed
    statement: "범위를 넓힌다 — §4·§5 도 audit 으로 옮겨 게이트 코퍼스를 실제로 이동시킨다"
    evidence: S16
  - id: C13
    source: chosen
    status: confirmed
    statement: "원자료는 audit·압축된 판정은 payload 로 가르고, 게이트는 그 둘을 잇는 payload↔audit 교차 검사가 된다"
    evidence: S19
  - id: C14
    source: chosen
    status: confirmed
    statement: "S1(seed 전문)은 payload 잔류 예외로 둔다"
    evidence: S18
  - id: C15
    source: chosen
    status: confirmed
    statement: "blob 빌더를 «번들 빌더»로 승격한다"
    evidence: S18
  - id: C9
    source: verbatim
    status: confirmed
    statement: "OQ1 에 «URL 없애면 안 되는지»를 추가한다"
    evidence: S10
  - id: C10
    source: chosen
    status: confirmed
    statement: "설계 §11 이월 목록 중 더 끌어당길 것은 없다 — 셋으로 충분"
    evidence: S13
  - id: C16
    source: verbatim
    status: confirmed
    statement: "OQ만 해소하려는 거로 하류가 오염되는 경우가 있었다 — 원 brainstorming 과정을 우리가 다른 것으로 강제하는 게 없는지 본다"
    evidence: S13
  - id: C17
    source: verbatim
    status: confirmed
    statement: "그 진행에서 우리가 나눠서 이번 세션에 진행하기로 한 몫이다"
    evidence: S12
  - id: C18
    source: verbatim
    status: confirmed
    statement: "원문의 append-only 가드가 payload 편집 권한 표의 행이라, 원문이 audit 으로 가면 그 관할이 없어진다"
    evidence: S1
  - id: C19
    source: verbatim
    status: confirmed
    statement: "이전 phase0 스펙 브리프를 봤을 때 진행 안 된 것을 확인한다"
    evidence: S11
  - id: C20
    source: verbatim
    status: open
    statement: "하류가 payload 경로 하나만 받고 superpowers 계약을 바꿀 수 없어 payload 에서 뺀 것이 소실된다 — 그걸 어떻게 할지가 먼저 정해져야 한다"
    evidence: S1
  - id: C21
    source: verbatim
    status: open
    statement: "URL 제거는 landscape_uncited 뒤집기·양성 짝·_web_disabled 가드의 의미 반전이 얽혀 있어 따로 뗄 수 없다"
    evidence: S1
  - id: C22
    source: verbatim
    status: confirmed
    statement: "bijection A 의 payload 축(§5 verdict 항목)과 bijection B 의 대상 절(「제약」)이 새 절 구성에서 사라진다"
    evidence: S1
  - id: C23
    source: chosen
    status: confirmed
    statement: "충실도 축은 1번 — blob 에 audit §6 도 함께 인라인해 격리 critic 이 대조 대상을 잃지 않게 한다"
    evidence: S8
  - id: C11
    source: chosen
    status: confirmed
    statement: "§7 Next Action 을 개정한다 (분류 선점 문구 제거 · 사람용 안내로 명시) + §5 기각에 «다시 제안해도 된다» 명시"
    evidence: S14
---

# brief 재구조화 — Interview Brief

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming 해답공간으로
> 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다. 텔레메트리는 `audit_file`에 있다.

## 0. 한눈에

**무엇** — spec-distill 이 만드는 interview-brief 를 재구조화한다. payload(하류가 받는 문서)는 압축된 판정만 담고, 확산 원자료는 sidecar audit 으로 옮긴다.

**왜** — 오늘 payload 는 27,590자, audit 은 8,438자로 확산물이 압축물보다 작다. 원인은 규약 부재가 아니라 **게이트 배치**다: `check_brief.py` 의 15검사와 bijection 3종과 `check_verbatim_coverage.py` 가 전부 payload 를 코퍼스로 삼아, 검증하고 싶은 것이 전부 payload 로 끌려왔다. **검증 대상과 인계 대상이 같은 파일이면 검증이 인계물을 부풀린다.** 그렇게 부푼 payload 가 하류 `superpowers:brainstorming` 에서 컨텍스트를 흔든다 — **이 인과는 사용자의 관측 가설이고 측정되지 않았다**(C1·OQ3).

**진짜 goal** — 검증 대상(audit)과 인계 대상(payload)을 갈라, payload 가 자립 완결이면서 작아지게 한다. 분량 감축은 결과이지 목표가 아니다.

**무엇이 지금까지 정해졌나** (21건이 proceed 게이트에서 `confirmed` 가 됐고 C20·C21 은 `open` 이다 — **확정은 봉인이 아니다**: 근거가 있으면 하류가 보고 후 재결정할 수 있고, 임의 변경만 금지다) — **원자료는 audit, 압축된 판정은 payload** 로 가르고, 게이트는 그 둘을 잇는 payload↔audit **교차 검사**가 된다(C13). 사용자 원문은 audit 으로 가되 S1(seed 전문 또는 최초 요청)만 payload 잔류 예외(C4·C14). payload 항목은 `id·statement·status·⟨S<N>⟩` 를 유지하고 SUPERSEDED 이력만 audit 으로(C5). §4·§5 의 원자료도 audit 으로 옮겨 게이트 코퍼스를 실제로 이동시킨다(C12). **URL 은 payload 를 떠나고** 출처 «키» + 직접인용 1문장 + 판정만 남는다(C8). audit 은 반드시 읽어야 하는 것이 아니라 필요할 때 여는 것이다(C7·§7 과 같은 문면). 파서 형식은 재작성하지 않는다(C4).

**무엇이 열려 있음** — URL 이 payload 를 떠나도 audit 을 연 소비자에게는 같은 재조회 문제가 남는다(OQ1). audit 으로 옮기는 것이 물리적 배제가 아니라는 것(OQ2), 원인이 부피인지 상충인지 측정되지 않은 것(OQ3), 정본에서 payload 를 생성하는 projection 안을 평가하지 않은 것(OQ7)도 열려 있다.

**다음 stage** — §7.

## 1. Goal · Non-goal

- **Goal** — 검증 대상과 인계 대상의 분리. `check_brief.py` 의 검사들이 **payload↔audit 교차 검사**가 되도록 재배치한다 — payload 는 압축된 판정을 담고 audit 은 그 판정이 접지되는 원자료를 담아, 모든 축이 bijection A 와 같은 모양(판정 ↔ 원문)이 된다.
- **Goal** — 그 재배치가 §6(사용자 원문)에 그치지 않고 §4(landscape)·§5(steelman·blind-spot)까지 미치게 한다. 두 절만 옮기면 15검사 중 코퍼스가 바뀌는 것이 2개뿐이라 진단과 처방이 어긋난다.
- **Goal** — payload 가 하류의 컨텍스트를 오염(잘못된 자료)·산만(과잉 분량)·강제(과정 지시)하지 않게 한다. 셋은 별개 축이고 처방이 다르다.
- **Goal** — payload 의 자립 완결 유지. audit 을 읽어야만 성립하는 payload 는 실패다.
- **Non-goal** — `user_sourced_items` 의 파서 형식 전환(frontmatter YAML → 본문 절). C4 로 범위 밖.
- **Non-goal** — 출처 표기 자체를 없애는 것. URL 은 audit 으로 가되 payload 는 출처 «키» + 직접인용을 유지한다 — 검증 핸들을 없애는 것이 아니라 재조회 핸들만 옮긴다.
- **Non-goal** — 설계 §11 의 나머지 이월 항목(채택자 치환 구멍 · agent 루프 총량 바운드 · 깎기 기준선 · 효과 측정 · codex 축 · 세 단계 질문 중복). C10.
- **Non-goal** — 분량에 수치 상한을 두는 것. v0.33.0 이 이미 한 번 걷어냈고, 짧음은 상한이 아니라 뺄셈의 결과다.

**용어** (이 brief 안에서만 쓰는 이름 — `check_brief.py` 의 검사들이다):
- **bijection A** — payload §5 의 `verdict:` 항목 ↔ audit §3 의 `ST<N>` 헤딩. 판정과 그 판정의 원문이 서로를 가리키는지.
- **bijection B** — payload 본문 §2 의 각 줄 ↔ frontmatter `user_sourced_items` 의 같은 id. **오늘 유일하게 한 파일 안에서 도는 검사**다.
- **bijection C** — 각 항목의 `evidence: S<N>` ↔ §6 사용자 원문의 `S<N>` 앵커. 요약이 가리키는 원문이 실재하는지.

**이번 세션이 넘겨받은 몫** (C17·C19 가 가리키는 것) — phase0 는 PR0~PR4 로 전량 ship 됐고(0.34.0~0.38.0, 현재 0.41.0), 남은 것은 설계 §11 이 명시 이월한 목록뿐이다. 그중 이번 몫은 **셋**: ① brief 재구조화(이월 5개 항목) ② brief payload 의 URL 처분(B1–B3) ③ 하류 핸드오프 계약. 나머지 이월(채택자 치환 구멍 · agent 루프 총량 바운드 · 깎기 기준선 · 효과 측정 · codex 축 · 세 단계 질문 중복)은 C10 으로 범위 밖.

**결과물의 모양** (이동 방향이 아니라 도착점):

| payload — 하류가 받는 것 | audit — 검증 층이 필요할 때 여는 것 |
|---|---|
| frontmatter `user_sourced_items` (id·source·status·statement·evidence) | §1 Coverage Ledger |
| §0 한눈에 | §2 Budget |
| §1 Goal · Non-goal | §3 Steelman **원문** |
| §2 제약 | §4 게이트 실행 기록 |
| §3 Open Questions | §5 프로세스 로그 |
| §4 External Landscape — 출처 «키» + 직접인용 + 판정 (**URL 없음**) | **§6 사용자 원문** (신설 — S1 제외 전량) |
| §5 기각 — 판정 한 줄 (**URL·긴 서사 없음**) | **§7 확정 원장** (신설 — SUPERSEDED 이력) |
| §6 사용자 원문 — **S1 하나만** | **§8 확산 원자료** (신설 — landscape URL·sweep 전문·blind-spot premortem 전문) |
| §7 Next Action | |

**이월 5개의 현재 상태**: ① 파서 전환 = 안 함(C4) · ② bijection A payload 축 = 발화 안 함(verdict 잔류) · ③ bijection B 대상 절 = 「소멸」이 아니라 **형태 유지**(C5 재결정) · ④ append-only 관할 이동 = 실재(C18) · ⑤ 픽스처 = **134건**(121 아님).

## 2. 제약

(이 절의 진술은 모델이 쓴 요약이다. 원문은 audit 이 나른다 — `⟨S<N>⟩` 가 그것을 가리킨다.)

- 🗣 confirmed **C1** — 하류에 audit 으로 넘기는 내용들이 넘어가기 때문에 컨텍스트를 흔든다고 생각했다 ⟨S2⟩
- 🗣 confirmed **C2** — brief 로 완결되어야 한다 ⟨S3⟩
- 🗣 confirmed **C3** — 외부 URL 은 잘못 찾아온 자료로 문제 방향을 이상하게 잡게 만든 적이 많다 ⟨S4⟩
- ☑ confirmed **C4** — payload 에는 압축 항목만 남기고 §6 사용자 원문은 전량 audit 으로 옮긴다. frontmatter YAML 형태는 유지해 파서를 재작성하지 않는다 ⟨S5⟩
- ☑ confirmed **C5** — payload 항목은 id·statement·status·⟨S<N>⟩ 를 유지하고, audit 으로는 SUPERSEDED 이력과 원문 대조만 보낸다 ⟨S15⟩
- 🗣 confirmed **C6** — 1차 출처도 너무 specific 한 논문 자료가 오는 경우가 많고, URL 을 읽을 때 그 내용만 넘어오지 않아 방향과 맥락이 완전히 달라진다 — 근본 해결이 어렵다 ⟨S7⟩
- 🗣 confirmed **C7** — audit 에 두는 것이지, 필요한 경우에만 보면 된다 ⟨S8⟩
- ☑ confirmed **C8** — 출처 «키» + 직접인용은 payload, URL 은 audit 에만 둔다 ⟨S17⟩
- ☑ confirmed **C12** — 범위를 넓힌다 — §4·§5 도 audit 으로 옮겨 게이트 코퍼스를 실제로 이동시킨다 ⟨S16⟩
- ☑ confirmed **C13** — 원자료는 audit·압축된 판정은 payload 로 가르고, 게이트는 그 둘을 잇는 payload↔audit 교차 검사가 된다 ⟨S19⟩
- ☑ confirmed **C14** — S1(seed 전문)은 payload 잔류 예외로 둔다 ⟨S18⟩
- ☑ confirmed **C15** — blob 빌더를 «번들 빌더»로 승격한다 ⟨S18⟩
- 🗣 confirmed **C9** — OQ1 에 «URL 없애면 안 되는지»를 추가한다 ⟨S10⟩
- ☑ confirmed **C10** — 설계 §11 이월 목록 중 더 끌어당길 것은 없다 — 셋으로 충분 ⟨S13⟩
- 🗣 confirmed **C16** — OQ만 해소하려는 거로 하류가 오염되는 경우가 있었다 — 원 brainstorming 과정을 우리가 다른 것으로 강제하는 게 없는지 본다 ⟨S13⟩
- 🗣 confirmed **C17** — 그 진행에서 우리가 나눠서 이번 세션에 진행하기로 한 몫이다 ⟨S12⟩
- 🗣 confirmed **C18** — 원문의 append-only 가드가 payload 편집 권한 표의 행이라, 원문이 audit 으로 가면 그 관할이 없어진다 ⟨S1⟩
- 🗣 confirmed **C19** — 이전 phase0 스펙 브리프를 봤을 때 진행 안 된 것을 확인한다 ⟨S11⟩
- 🗣 open **C20** — 하류가 payload 경로 하나만 받고 superpowers 계약을 바꿀 수 없어 payload 에서 뺀 것이 소실된다 — 그걸 어떻게 할지가 먼저 정해져야 한다 ⟨S1⟩
- 🗣 open **C21** — URL 제거는 landscape_uncited 뒤집기·양성 짝·_web_disabled 가드의 의미 반전이 얽혀 있어 따로 뗄 수 없다 ⟨S1⟩
- 🗣 confirmed **C22** — bijection A 의 payload 축(§5 verdict 항목)과 bijection B 의 대상 절(「제약」)이 새 절 구성에서 사라진다 ⟨S1⟩
- ☑ confirmed **C23** — 충실도 축은 1번 — blob 에 audit §6 도 함께 인라인해 격리 critic 이 대조 대상을 잃지 않게 한다 ⟨S8⟩
- ☑ confirmed **C11** — §7 Next Action 을 개정한다 (분류 선점 문구 제거 · 사람용 안내로 명시) + §5 기각에 «다시 제안해도 된다» 명시 ⟨S14⟩

## 3. Open Questions

- **OQ1 — 재조회 문제는 URL 을 옮겨도 audit 소비자에게 남는다.** 3안(출처 키 + 직접인용은 payload, URL 은 audit) 채택으로 **하류는** 재조회 핸들을 잃지만, audit 을 여는 소비자(검증 층·사람)는 여전히 URL 을 열 수 있고 그때 문서 전체가 들어온다. 사용자 판단: "근본적으로 해결이 어려움". 전면 제거(URL 을 어디에도 두지 않음)는 여전히 닫히지 않은 선택지다(C9) — 반대 근거는 audit §3 ST1 의 9건.
- **OQ2 — audit 으로 「옮기는 것」은 물리적 제거가 아니다.** `audit_file` 은 게이트가 강제하는 필수 키이고 `resolve_audit()` 이 audit 이름을 payload stem 에서 유도하므로, 하류는 포인터가 없어도 sidecar 를 재구성할 수 있다. `/compact` 지시문은 한술 더 떠 audit 경로 보존을 명령한다. C1 은 규범으로 성립하고 물리적으로는 미보장이다.
- **OQ3 — 원인이 분량인가 상충인가. 측정하지 않기로 했다.** payload 는 대략 20,000~35,000 토큰으로 추정되나(한글 35%, 정밀 측정 아님) 실측하지 않았다. 방향성 리뷰가 「착수 전 실측」을 선택지로 올렸으나 채택되지 않았다. Chroma 의 context-rot 연구 기준 열화 예측자는 raw 토큰 수가 아니라 **distractor 와 질문-유사도**인데, 그 기준으로 보면 §6(질문-유사도 최상단)보다 §4·§5(distractor 형상)가 먼저 나가야 한다 — C12·C13 이 결과적으로 그 방향과 일치하지만 **측정으로 뒷받침된 것은 아니다.** #127 이 같은 오측정을 이미 한 번 겪었다.
- **OQ4 — `STATEMENT_MAX = 160` 이 단독 전달물이 될 때의 손실.** 오늘은 같은 파일에 원문이 있어 파일 수준에서 무손실이었다. 원문이 audit 으로 가면 같은 상한이 핸드오프 수준의 손실이 되고, 하드캡은 구조적으로 예외·범위·수량부터 깎는다. 하류가 제약을 넓게 해석하면 과잉 구현, 좁게 해석하면 누락인데 payload 안에 판별 근거가 없다.
- **OQ5 — 게이트가 강제하는 sentinel 문장의 귀속 오류.** `# confirmed 0건 — 사용자가 전부 잠정으로 판단` 은 규칙의 산물(확정은 proceed 게이트에서만)을 사용자 판단으로 귀속한다. 사용자는 그렇게 판단한 적이 없고, 저자는 문구를 바꿀 권한이 없다(지우면 red). 이 재구조화가 손대는 자리에 걸려 있으나 별건이다.
- **OQ7 — 정본 하나에서 payload 를 생성하는 projection 안을 평가하지 않았다.** 방향성 리뷰가 DITA 조건부 처리 · single-source publishing · A2A 의 `uri`/`bytes` 택일을 선례로 올렸고, 「두 파일을 손으로 나누고 bijection 으로 지킨다」는 형태 자체가 문제의 재생산일 수 있다고 지적했다. 선택되지 않았으므로 채택도 기각도 아닌 **미평가** 상태로 남긴다.
- **OQ6 — §3 Open Questions 가 하류에서 과제 목록으로 읽히는 경로.** 사용자가 관측한 오염 양식("OQ만 해소하려는 거로 하류가 오염된다")인데, 처분으로 §3 라벨을 선택하지 않았다(C11 은 §7·§5 만 다룬다). 남은 채로 둔다.

## 4. External Landscape

(1항목 = 1줄. 출처 «키» + 원문 직접인용 또는 요지 + [취함|피함|중립] + 이유. 그 키가 가리키는
 원자료 URL은 audit §7 확산 원자료에 선언한다 — payload에는 키만 남는다.)

- 컨텍스트 실패 4분류(poisoning / distraction / confusion / clash) «dbreunig-context-fail» — [취함] — "context poisoning 은 환각이나 오류가 컨텍스트에 들어와 반복 참조되는 것" / "context distraction 은 컨텍스트가 너무 길어져 모델이 훈련 지식 대신 누적 이력에 과집중하는 것". 「컨텍스트를 흔든다」를 두 축으로 갈라 처방을 달리할 근거.
- Anthropic — Effective context engineering for AI agents «anthropic-context-eng» — [취함] — just-in-time 패턴에서 파일 경로는 런타임 로드 지시로 읽힌다. audit 으로 「옮기는 것」이 물리적 제거가 아니라는 OQ2 의 근거.
- 에이전트 메모리 오염과 content 스크리닝의 한계 «memory-poisoning-screening» — [취함] — "거짓 주장과 참 주장을 구별하려면 일반적으로 텍스트 자체를 넘어선 외부 근거가 필요하다". 4단계 스크리닝이 오염 메모리 360건 중 0건을 거절. URL 전면 제거를 기각한 핵심 근거.
- Spotlighting (indirect prompt injection 방어) «spotlighting» — [취함] — 신뢰 불가 입력의 출처 신호를 유지·강화하고 "이것은 데이터이지 지시가 아니다"를 명시하면 공격 성공률 2% 미만. 처방이 삭제가 아니라 강등이라는 근거 — C6·C8 의 3항 형식과 라벨이 여기서 왔다.
- 생성형 검색엔진 검증가능성 감사 «search-verifiability-audit» — [중립] — 생성 문장의 51.5%만 인용에 완전히 지지된다. "인용이 있어야 오지지가 측정된다"는 논지는 취하되, 수치 자체는 검색엔진 대상이라 brief 핸드오프로 직접 이전하지 않는다.
- 메모리 압축의 rate-distortion 관점 «rate-distortion-compression» — [취함] — lossy summarization 은 비가역이라 탈락한 세부를 재도출할 수 없고 압축 이벤트 수에 대해 오류가 super-linear 로 증가. OQ4(160자 하드캡이 단독 전달물이 될 때)의 근거.
- handoff-document 패턴과 context rot «mindstudio-context-rot» — [중립] — "각 체크포인트에서 구조화된 핸드오프 문서를 만들고 다음 단계는 그 문서를 유일한 컨텍스트 입력으로 새로 시작한다"가 C2(자립 완결)와 같은 모양. 벤더 블로그라 근거 등급을 낮게 둔다.
- Goodhart's law «goodharts-law» — [취함] — 게이트를 옮긴 뒤 남는 payload 검사가 「자기 자신과의 일치」만 재게 되는 붕괴 양식의 이름. §5 위험 항목이 이 이름을 쓴다.

## 5. 기각 · Blind Spots

(`기각` 항목은 닫힌 문이 아니다 — **근거가 있으면 하류가 다시 제안해도 된다.** 임의 변경만 금지다(C11·P23).
 `verdict:` 를 가진 항목은 audit §3 의 `ST<N>` 을 참조한다.)

- 기각 — payload 에서 URL 을 전면 제거하고 조사 결과를 말로만 옮겨 적는 안(B1–B3 원안) → 제거되는 것은 URL 이지 그 URL 이 실어 온 주장이 아니다. 오염된 주장은 남고 반증 수단만 사라진다 — verdict: switched — ST1
- 기각 — **재결정**: 원안 S6(「payload 는 id + statement 만, status·SUPERSEDED·evidence 앵커는 전부 audit」) → 방향성 리뷰 D3 이 게이트 3곳 파손을 코드로 보였다. `BODY_ITEM_RE` 가 status·⟨S<N>⟩ 을 문법에 요구하고, `confirmed_zero_unsentineled()` 가 status 를 읽어 sentinel 이 영구 필수가 되며, `bijection_c_errors` 의 `if ev and` 가 공전해 공허 GREEN 이 된다. **재결정 = status·앵커는 payload 잔류, 이력만 audit**(S15).
- 기각 — **재결정**: 원안 S9/C8(「§4 는 payload 에 URL 포함 3항 형식으로 잔류」) → D5 가 3안(출처 키 + 직접인용은 payload, URL 은 audit)을 올렸고, 그것이 S7 이 지목한 재조회 메커니즘을 실제로 막으면서 `landscape_uncited` 를 양성 대조로 바꾼다. **재결정 = URL 은 audit 으로**(S17).
- 기각 — **재결정**: 원안의 범위(「§6 이관 + 원장 분리」) → D1 이 그 범위로는 15검사 중 코퍼스가 2개만 바뀐다는 것을 보였다. **재결정 = §4·§5 원자료까지 이관해 범위를 넓힘**(S16·S19).
- 기각 — **재결정**: C20 이 옮긴 원 전제(「하류가 경로 하나만 받으므로 payload 에서 뺀 것은 소실된다」) → 실측이 절반을 반증했다. `superpowers/6.3.0/skills/brainstorming/SKILL.md` 에 `$ARGUMENTS` 계약이 0건이고, `Skill superpowers:brainstorming <brief-path>` 는 **devbrew 자신의** `finishing.md:207,233,236,242` 문장이며, `resolve_audit()` 이 audit 이름을 payload stem 에서 유도한다. **바꿀 수 없는 것은 superpowers 의 SKILL 문면뿐이고 인계 모양은 우리 것이다.** 남은 참인 부분: 무엇을 하류가 실제로 읽는지 우리가 강제하지 못한다(OQ2).
- 기각 — C21 의 「따로 뗄 수 없다」 중 `_web_disabled()` 가드 부분 → 3안(S17) 채택으로 **의미 반전이 아니라 이동**이 된다. URL 요구가 audit 쪽으로 가면 완화도 거기서 하면 되고, payload 쪽에는 「출처 키가 audit 에서 해석되는가」라는 양성 대조만 남는다. 얽힘 셋 중 이 하나는 해소됐다.
- 기각 — 착수 전 토큰 실측(D6) → 선택되지 않음. 원인 진단이 측정 없이 확정된 채 남는다(OQ3).
- 기각 — 정본에서 payload 를 생성하는 projection 안(D7) → 선택되지 않음. 기각이 아니라 미평가로 OQ7 에 남긴다.
- 기각 — 핸드오프 프롬프트에 audit 경로와 "필요하면 읽어라" 한 줄을 넣어 소실을 줄이는 안 → C2(자립 완결)와 정면 충돌한다. 포인터가 하류를 원자료로 다시 끌어들인다.
- 기각 — 핸드오프 시점에 payload 와 audit 의 합본을 세 번째 파일로 굽는 안 → 새 산출물이 새 게이트 대상을 낳아, 이 작업의 동기(게이트가 인계물을 부풀린다)를 그대로 재생산한다.
- 기각 — 분할 기준을 「확산/압축」이 아니라 「하류가 쓰는가」로 잡는 안 → 소실은 구성상 0이 되지만 payload 가 다시 커져 분량 문제를 해결하지 못하고, 압축 규약의 불변량 정의와 어긋난다.
- 기각 — 출처 티어링(1차 출처만 payload, 블로그·요약 사이트는 audit) → 사용자 실측 기각. 1차 출처인 논문도 너무 specific 한 자료가 오는 경우가 많아, 실패가 출처 품질 축이 아니다.
- 기각 — `user_sourced_items` 를 frontmatter YAML 에서 본문 절로 옮기는 파서 전환 → 이 결정과 분리 가능한 별건인데 묶으면 픽스처 파급이 이 결정의 인질이 된다.
- 기각 — §6 이관을 되돌려 충실도 축을 지키는 안 → 리뷰어 격리를 *도구 표면*이 아니라 *파일 경계*로 착각하는 것이다. Law 2 가 명시적으로 거부한 형태이며, blob 빌더가 무엇을 담을지는 오케스트레이터의 권한이다.
- 위험 — 숨은 가정: 「audit 으로 옮기면 하류가 보지 않는다」. 이동은 제거가 아니라 주소화다 — `audit_file` 은 게이트 필수 키이고 `resolve_audit()` 이 이름을 payload stem 에서 유도하며 `/compact` 지시문은 audit 경로 보존을 명령한다 — `plugins/spec-distill/scripts/check_brief.py`
- 위험 — 실패 양식: 옮길 수 없는 게이트가 있다. `brief-critic`·`brief-readback` 은 `tools: []` 로 payload 를 inline 으로만 받고 SKILL 이 "critic 은 §6 를 ground truth 로 쓴다"고 적는다. §6 이관은 충실도 축의 대조 대상을 없애고, 남는 리뷰어는 한도 소진된 codex 뿐이다 — `plugins/spec-distill/agents/brief-critic.md:13`
- 위험 — 실패 양식: 기각 재제안 루프. §5 기각이 payload 를 떠나면 하류는 무엇이 이미 배제됐는지 모른 채 해답공간을 연다. C11 이 부분 대응이나 완전하지 않다
- 위험 — 실패 양식: 상호정합 GREEN. 체커와 픽스처를 같은 패스가 다시 쓰면 서로의 전제를 공유한 초록이 난다. 「payload 에 없어야 한다」류 부재 락만 추가하면 payload 를 빈 파일로 만들어도 통과한다 — 양성 짝 + mutation 양성 대조가 없으면 이관 성공을 주장할 수 없다
- 위험 — 실패 양식: 자립 완결이 「쌍의 co-location 불변식」으로 바뀐다. `resolve_audit()` 이 basename 일치를 강제하므로 payload 를 PR 에 붙이거나 다른 디렉토리로 옮기면 게이트가 red 가 되고 규약상 고칠 방법이 없다 — `plugins/spec-distill/scripts/check_brief.py`
- 위험 — 실패 양식: 원문 완전성이 git-ignored 파일에만 매달린다. `check_verbatim_coverage.py` 의 코퍼스가 state↔audit 이 되면 state 는 SessionEnd hook 이 지우므로 사후 재검증이 불가능해진다 — `plugins/spec-distill/scripts/check_verbatim_coverage.py`
- 위험 — 숨은 가정: seed 가 이미 하는 것을 brief 에 그대로 확장하면 된다. 두 payload 는 소비자 모델이 다르다 — seed 는 사람이 붙여넣는 메시지, brief 는 하류가 Read 하는 파일이고, audit 해석 규약도 정반대다(seed 는 자동 유추 금지, brief 는 stem 유도) — `plugins/spec-distill/references/compression.md`
- 위험 — 실패 양식: payload 가 하류의 과정을 강제한다. §7 이 `-design.md → writing-plans` 를 못 박아 brainstorming 의 첫 단계(분류를 소리 내어 말하고 사용자가 override)를 선점하고, §1·§2·§5 가 각각 scope 평가·질문·접근법 제안을 억제한다. C11 이 §7·§5 만 대응한다 — `plugins/spec-distill/templates/interview-brief-template.md`
- 위험 — 실패 양식(**방향성 리뷰 D2**): C1 이 오늘 구조에서 규범으로만 성립하는 정도가 OQ2 가 인정한 것보다 강하다. `/compact` 리터럴(옵션 ①)이 §6 을 **이름으로 보존 명령**하고, 옵션 ②는 같은 세션이라 인터뷰 원문이 이미 컨텍스트에 있다. 두 핸드오프 경로가 각각 명시·암묵으로 §6 을 되돌린다 — `plugins/spec-distill/skills/conducting-interview/references/finishing.md:233,207`
- 위험 — 실패 양식(**방향성 리뷰 D4**): codex 충실도 리뷰어는 blob 이 아니라 payload **경로**를 읽으므로(`build_brief_codex_prompt.py:95` `payload_path.read_text()`), C7 만으로는 두 충실도 리뷰어가 서로 다른 재료를 보게 되고 「fail-closed 합집합」의 보장이 사라진다. C15(번들 빌더 승격)가 대응 — `plugins/spec-distill/scripts/build_brief_codex_prompt.py`
- 위험 — 계수 정정(**방향성 리뷰 D8**): 픽스처 영향은 121건이 아니라 **134건**이다. `## 6. 사용자 원문` 을 가진 픽스처 74건이 계수에서 빠져 있었다(URL 62 + probe 59 + §6 74 = union 134). 설계문서의 두 축을 물려받고 이 설계가 만드는 §6 축을 세지 않은 결과다. 추가로 `test_conducting_interview_stage.sh:498,698` 의 green-expected 락 2건이 §6 이관과 함께 RED 가 된다 — `plugins/spec-distill/tests/`
- 위험 — 정정(**방향성 리뷰 D8**): 설계 §11 이월 ③(bijection B 대상 절)은 「소멸」이 아니라 **형태 변경**이다. 절(§2 제약)은 남지만 `BODY_ITEM_RE` 가 요구하는 status·⟨S<N>⟩ 의 거처가 바뀔 뻔했다. C5 재결정으로 지금은 형태도 유지되나, 이월 원장의 「소멸」 표기는 틀렸다
- 위험 — 숨은 가정: 27,590자가 하류를 흔든 원인이 「분량」이다. 토큰 실측이 없고 추정 범위(20,000~35,000)가 문헌의 열화 구간에 걸쳐 있어 판별되지 않는다 — OQ3

## 6. 사용자 원문

(`S1` 최초 요청 원문 하나만 여기 남는다 — 나머지 발화 전량은 audit `## 6. 사용자 원문`에
 append-only로 보존한다. 허용 변환은 P21 placeholder 치환·앞뒤 공백 정리·인용 블록 래핑뿐이며
 요약·재서술·발췌는 금지.)

- **S1** 🗣 최초 요청:
  > interview-brief 를 압축 규약대로 재구조화한다. payload 는 압축물만 담고 확산물(사용자 원문·External Landscape·steelman 원문·blind spot·확정 항목 원장)은 audit 으로 옮긴다. 배경과 이미 조사된 것은 docs/superpowers/specs/2026-08-23-request-framing-design.md 의 §5.2·§10·§11 에 있다. 그걸 먼저 읽어라.
  >
  > 선결 문제 하나가 이 설계의 출발점이다: 하류 superpowers:brainstorming 은 Skill superpowers:brainstorming 로 payload 경로 하나만 받고, superpowers 는 이 리포 밖 플러그인이라 그 계약을 우리가 바꿀 수 없다. 그래서 payload 에서 뺀 것은 하류에서 그냥 소실된다. 그걸 어떻게 할지가 먼저 정해져야 나머지가 정해진다.
  >
  > 알려진 어려움: user_sourced_items 가 frontmatter YAML 에서 본문 절로 가면 파서를 다시 써야 한다 / bijection A 의 payload 축(§5 verdict 항목)과 bijection B 의 대상 절("제약")이 새 절 구성에서 사라진다 / 원문의 append-only 가드가 payload 편집 권한 표의 행이라 audit 으로 가면 관할이 없어진다 / 픽스처 약 120건이 걸린다.
  >
  > brief payload 의 URL 제거도 이 작업에 딸려 있다 — landscape_uncited() 뒤집기와 양성 짝, _web_disabled() 가드의 의미 반전이 얽혀 있어 따로 뗄 수 없다.

## 7. Next Action

(사람용 안내다. 하류의 경로 선택을 미리 닫지 않는다 — C11.)

- superpowers 가 있으면 이 brief 를 context 로 `superpowers:brainstorming` 을 부른다. **경로 분류(spike / bounded / architectural)와 그에 따르는 산출물은 brainstorming 이 정하고 사용자가 override 한다** — 이 brief 는 그것을 미리 고르지 않는다.
- superpowers 가 없으면 이 brief 자체가 완결 산출물이다.
- 원자료(사용자 원문 전문 · steelman 원문 · blind-spot premortem 전문 · 커버리지 원장 · sweep 원문)는 `audit_file` 에 있다. **반드시 읽어야 하는 것이 아니라, 필요할 때 여는 것이다.**
