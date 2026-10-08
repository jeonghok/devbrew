---
name: skill-only-surface
type: interview-brief
created_at: 2026-10-08
session_id: 66d456cd-0cd7-4277-8466-2811dc3a60f9
source: spec-distill conducting-interview v0.23.0
next_phase: superpowers:brainstorming
contract: v2
audit_file: 2026-10-08-skill-only-surface-interview.audit.md
user_sourced_items:
# confirmed 0건 — 사용자가 전부 잠정으로 판단
  - id: C1
    source: verbatim
    status: provisional
    statement: "점검 대상은 slash 명령, slash 로 부를 수 있는 skill, kill switch 환경변수, 명령 인자로 넘기는 핸드오프 문구(skill 이 다음 단계로 안내하는 명령 문구 포함) 넷 전부다"
    evidence: S1
  - id: C2
    source: verbatim
    status: provisional
    statement: "이번 사이클은 점검·결정에서 멈추지 않고 구현까지 이 브랜치 하나로 간다"
    evidence: S1
  - id: C3
    source: verbatim
    status: provisional
    statement: "quality-gates 파일은 이 작업에서 고치지 않고 점검 보고에만 올린다; qg v10 은 자기 설계대로 가고 어긋나는 qg 부분은 후속 과제로 남긴다"
    evidence: S1
  - id: C4
    source: verbatim
    status: provisional
    statement: "이 작업이 명령 체계 규칙을 정하고 qg v10 재건과 쉬운 말 출력 작업은 그 규칙을 따른다"
    evidence: S1
  - id: C5
    source: verbatim
    status: provisional
    statement: "사용자는 플러그인 접두 없는 짧은 이름으로 명령을 치고, skill 을 slash 로 직접 부르는 경로를 일부러 쓴다"
    evidence: S1
  - id: C6
    source: verbatim
    status: provisional
    statement: "skill 을 직접 부르는 이유는 넷 — 대응 명령이 없고, 명령보다 확실히 돌고, 명령의 사전 단계를 피하고, 이름이 더 정확하다"
    evidence: S1
  - id: C7
    source: verbatim
    status: provisional
    statement: "불편은 넷 — 명령 오류, 무엇을 칠지 헷갈림, 문서와 실제의 불일치, 쓸모없는 명령"
    evidence: S1
  - id: C8
    source: verbatim
    status: provisional
    statement: "/interview 오류는 @ 경로를 읽다 실패해 ‘읽지 못했다’ 메시지를 내고 멈춘 것이고 그 원인은 하류가 재현으로 가른다"
    evidence: S1
  - id: C9
    source: verbatim
    status: provisional
    statement: "이름을 바꾸거나 없애는 명령은 alias 없이 바로 제거하고 major bump 한다"
    evidence: S1
  - id: C10
    source: verbatim
    status: provisional
    statement: "CLAUDE.md 의 one-minor deprecation window 규칙을 즉시 제거를 허용하도록 바꾼다"
    evidence: S1
  - id: C11
    source: verbatim
    status: provisional
    statement: "통일한 명령 규칙은 테스트(락)로 집행한다"
    evidence: S1
  - id: D1
    source: chosen
    status: provisional
    statement: "진짜 문제는 부르는 모양마다 도는 것이 달라 예측할 수 없다는 것이다"
    evidence: S2
  - id: D2
    source: chosen
    status: provisional
    statement: "기능마다 사용자가 부르는 skill 하나로 수렴하고 사전 단계는 그 skill 안에 둔다 — 명령 파일은 없앤다"
    evidence: S4
  - id: D3
    source: chosen
    status: provisional
    statement: "명령·skill 이름은 alias 없이 즉시 제거하고 major bump 하되 이번 범위는 qg 밖 명령 4개이고 kill switch 이름은 바꾸지 않으며 CLAUDE.md 개정문은 제3자 설치 확인 전까지·호출 이름에 한함·스위치 은퇴는 공시 필수라는 조건을 단다"
    evidence: S5
  - id: D4
    source: chosen
    status: provisional
    statement: "진입의 확실성 · 짧은 이름 충돌 · @ 대화형 재현 · 전환 잔재와 qg 면제 넷은 설계가 반드시 다룬다"
    evidence: S6
  - id: D5
    source: chosen
    status: provisional
    statement: "사용자가 치는 이름은 짧게 하되 일반어 단독은 금지하고, 기계가 내는 핸드오프 안내는 /plugin:name 완전명으로 쓴다"
    evidence: S7
  - id: D6
    source: chosen
    status: provisional
    statement: "통일 규칙 락은 표면 정합을 잰다 — 안내 문구가 실재 user-invocable skill 을 가리키는가 · 인식되는 frontmatter 키만 쓰는가 · 이름이 규칙을 따르는가"
    evidence: S8
---

# Skill-Only Command Surface — Interview Brief

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming 해답공간으로
> 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다. 텔레메트리는 `audit_file`에 있다.

## 0. 한눈에

**무엇.** devbrew 의 사용자 호출 표면(slash 명령 · slash skill · kill switch · 핸드오프 문구)을 한 체계로
통일하고 이 브랜치에서 구현까지 한다. 방향은 **기능당 사용자 진입 skill 하나**다. 명령 파일 층을 없애고
사전 단계(kill switch · trivia escape · `@경로` 풀기 · setup)를 그 skill 안에 둔다.

**왜.** 사용자는 명령을 쳤는데 모델이 skill 로 넘어가지 않거나 멈추는 일을 겪었다. 진짜 문제는
«부르는 모양마다 도는 것이 다르다»는 데 있다. 사용자가 확인한 불편은 넷이다 — 명령 오류, 무엇을 칠지 헷갈림, 문서와 실제의 불일치, 쓸모없는 명령(C7). 플랫폼도 같은
방향으로 가고 있다(commands = older format, skills supersede).

**확정 후보.** 이름은 짧게 하되 일반어 단독은 금지한다. 안내 문구는 완전명으로 쓴다. 제거는
alias 없이 즉시 하고 major bump 한다. CLAUDE.md 개정문은 제3자 설치 확인 전까지·호출 이름에 한함·스위치 은퇴는 공시 필수라는 조건을 단다. 이번 범위는 qg 밖 명령 4개이고 kill switch 이름은 그대로 둔다.
락은 표면 정합을 잰다. quality-gates 는 보고만 한다.

**열림.** `@` 오류 원인, 사전 단계를 결정론으로 만들 수단, 내부 skill 처분, 개별 이름 매핑, trivia 의
거처, CLAUDE.md 문안, 스위프 범위, README 편집 순서, qg 후속 목록 — §3.

**다음.** superpowers:brainstorming → 설계문서 → spec-distill:reviewing-spec → writing-plans.

**결정 목록**

- OQ1 [해결 ⟨S2⟩] — 이 작업 뒤의 진짜 문제를 무엇으로 재구성하나
- OQ2 [해결 ⟨S3⟩] — «명령보다 skill 이 확실히 돈다»의 실제 사례(재구성의 실패 조건 확인)
- OQ3 [해결 ⟨S4⟩] — 공식 문서의 방향(commands → skills 수렴)을 진입 구조로 취하나
- OQ4 [해결 ⟨S5⟩] — alias 없는 즉시 제거 + major bump 를 skill 단일화 개편에도 그대로 적용하나
- OQ5 [해결 ⟨S6⟩] — premortem 위험 중 설계 필수로 올릴 것
- OQ6 [해결 ⟨S7⟩] — 사용자가 치는 skill 이름 규칙
- OQ7 [해결 ⟨S8⟩] — 통일 규칙 락이 무엇을 재나
- OQ8 [해결 ⟨S9⟩] — Open Questions 목록 확인
- OQ9 [열림] — `@` 읽기 실패의 원인을 대화형 실측으로 가른다 → 근거 RC11 · RC26
- OQ10 [열림] — 사전 단계를 결정론으로 만들 수단과 disable-model-invocation 축 → 근거 RC1 · RC19 · RC22 · RC23
- OQ11 [열림] — 모델 전용 내부 skill 의 처분 → 근거 RC3 · RC22 · RC23
- OQ12 [열림] — qg 밖 명령 4개의 수렴 매핑과 개별 이름 → 근거 RC7 · RC12
- OQ13 [열림] — trivia escape 를 skill 안 어디에 둘지 → 근거 RC2 · RC27
- OQ14 [열림] — CLAUDE.md 개정 문안 → 근거 RC14 · RC15 · RC16 · RC17 · RC20
- OQ15 [열림] — 옛 이름 스위프 범위와 qg 면제 만료의 구현 → 근거 RC10 · RC13 · RC18 · RC25
- OQ16 [열림] — 쉬운 말 출력 작업과의 README 편집 순서 → 근거 RC8
- OQ17 [열림] — qg 후속 과제 보고 목록 → 근거 RC4 · RC5 · RC6
- OQ18 [열림] — [참고 · direction] qg 면제의 만료를 「v10 머지」에 걸면 v10 이 `commands/qg.md` 진입과 맨 `/qg` 를 유지하므로 머지 순간 표면 정합 락이 RED 가 된다 — 만료를 qg 가 실제로 규칙에 수렴한 시점에 걸지 정한다
- OQ19 [열림] — [참고 · direction] qg v10 ① 컷오버가 CLAUDE.md 메타데이터 절에 무조건 제거 문안을 넣고 kill switch 하나를 개명한다 — D3 의 조건부 문안과 같은 조항의 소유자가 둘이다. C4(이 작업이 규칙을 정함)와 C3(v10 은 자기 설계대로) 중 무엇이 우선인지 정한다
- OQ20 [열림] — [참고 · direction] qg v10 ① 은 `commands/qg.md` 를 `!` 펜스 진입으로 새로 쓴다 — D2(명령 파일 제거)·C4 와 충돌. v10 이 진입을 skill 로 맞출지, 규칙에 결정론적 `!` 선행 명령 예외를 둘지 정한다
- OQ21 [열림] — [참고 · overdesign] shrink: OQ17 의 qg 후속 목록 대부분은 v10 ①·③ 이 지우는 표면이다 — v10 이후에도 남는 어긋남만 남기고 나머지는 「v10 에서 삭제」 한 줄로 묶을지 정한다
- OQ22 [열림] — [참고 · direction] plugin-audit 은 0.10.0 이다 — 이름 제거에 일괄 major bump 를 적용해 1.0.0 으로 올릴지(안정 API 선언·CHANGELOG·창 규칙 구속이 따라옴), 0.x 는 minor 로 하는 예외(0.6.0 선례)를 D3 에 적을지 정한다
- OQ23 [열림] — [참고 · direction] `!` 블록 사전 치환이 실패하면 모델 턴 0회 · rc=0 으로 조용히 끝난 리포 실측이 있다 — OQ10 의 수단 결정이 이 실패를 소리 나게 드러내는 요건까지 포함할지 정한다
- OQ24 [열림] — [참고 · direction] Goal 의 「그 모양으로 부르면 늘 같은 것이 돈다」는 bare 이름에는 보장되지 않는다(`--plugin-dir` 에서는 등록조차 안 됨) — 보장을 완전명에만 걸지, 설치본에서 bare 해석 실측을 설계 필수에 더할지 정한다

## 1. Goal · Non-goal

- Goal: 사용자가 devbrew 기능을 부르는 모양이 하나이고 그 모양으로 부르면 늘 같은 것이 돈다 — 기능당 사용자 진입 skill 하나, 사전 단계는 그 안, 짧은 이름, 기계가 내는 안내는 완전명, 그리고 그 정합을 지키는 락.
- Goal: 이번 브랜치에서 qg 밖 명령 4개(interview · request-framing · plugin-audit · project-init)를 그 체계로 옮기고 CLAUDE.md 규칙을 개정한다.
- Non-goal: quality-gates 파일 수정 — 규칙과 어긋나는 qg 표면은 점검 보고의 후속 과제로만 남긴다.
- Non-goal: kill switch 이름 변경 · deprecation alias 나 fallback 명령 · qg v10 설계 대체 · 쉬운 말 출력 문구 작업.

## 2. 제약

- 🗣 provisional **C1** — 점검 대상은 slash 명령, slash 로 부를 수 있는 skill, kill switch 환경변수, 명령 인자로 넘기는 핸드오프 문구(skill 이 다음 단계로 안내하는 명령 문구 포함) 넷 전부다 ⟨S1⟩
- 🗣 provisional **C2** — 이번 사이클은 점검·결정에서 멈추지 않고 구현까지 이 브랜치 하나로 간다 ⟨S1⟩
- 🗣 provisional **C3** — quality-gates 파일은 이 작업에서 고치지 않고 점검 보고에만 올린다; qg v10 은 자기 설계대로 가고 어긋나는 qg 부분은 후속 과제로 남긴다 ⟨S1⟩
- 🗣 provisional **C4** — 이 작업이 명령 체계 규칙을 정하고 qg v10 재건과 쉬운 말 출력 작업은 그 규칙을 따른다 ⟨S1⟩
- 🗣 provisional **C5** — 사용자는 플러그인 접두 없는 짧은 이름으로 명령을 치고, skill 을 slash 로 직접 부르는 경로를 일부러 쓴다 ⟨S1⟩
- 🗣 provisional **C6** — skill 을 직접 부르는 이유는 넷 — 대응 명령이 없고, 명령보다 확실히 돌고, 명령의 사전 단계를 피하고, 이름이 더 정확하다 ⟨S1⟩
- 🗣 provisional **C7** — 불편은 넷 — 명령 오류, 무엇을 칠지 헷갈림, 문서와 실제의 불일치, 쓸모없는 명령 ⟨S1⟩
- 🗣 provisional **C8** — /interview 오류는 @ 경로를 읽다 실패해 ‘읽지 못했다’ 메시지를 내고 멈춘 것이고 그 원인은 하류가 재현으로 가른다 ⟨S1⟩
- 🗣 provisional **C9** — 이름을 바꾸거나 없애는 명령은 alias 없이 바로 제거하고 major bump 한다 ⟨S1⟩
- 🗣 provisional **C10** — CLAUDE.md 의 one-minor deprecation window 규칙을 즉시 제거를 허용하도록 바꾼다 ⟨S1⟩
- 🗣 provisional **C11** — 통일한 명령 규칙은 테스트(락)로 집행한다 ⟨S1⟩
- ☑ provisional **D1** — 진짜 문제는 부르는 모양마다 도는 것이 달라 예측할 수 없다는 것이다 ⟨S2⟩
- ☑ provisional **D2** — 기능마다 사용자가 부르는 skill 하나로 수렴하고 사전 단계는 그 skill 안에 둔다 — 명령 파일은 없앤다 ⟨S4⟩
- ☑ provisional **D3** — 명령·skill 이름은 alias 없이 즉시 제거하고 major bump 하되 이번 범위는 qg 밖 명령 4개이고 kill switch 이름은 바꾸지 않으며 CLAUDE.md 개정문은 제3자 설치 확인 전까지·호출 이름에 한함·스위치 은퇴는 공시 필수라는 조건을 단다 ⟨S5⟩
- ☑ provisional **D4** — 진입의 확실성 · 짧은 이름 충돌 · @ 대화형 재현 · 전환 잔재와 qg 면제 넷은 설계가 반드시 다룬다 ⟨S6⟩
- ☑ provisional **D5** — 사용자가 치는 이름은 짧게 하되 일반어 단독은 금지하고, 기계가 내는 핸드오프 안내는 /plugin:name 완전명으로 쓴다 ⟨S7⟩
- ☑ provisional **D6** — 통일 규칙 락은 표면 정합을 잰다 — 안내 문구가 실재 user-invocable skill 을 가리키는가 · 인식되는 frontmatter 키만 쓰는가 · 이름이 규칙을 따르는가 ⟨S8⟩

✎ D2 와 C5 가 만나는 자리: S4 이후로는 사용자가 치는 이름이 곧 skill 이름이다(모델 추론 — C5 는 «명령을» 짧은 이름으로 친다고 했고, skill 직접 호출은 지금 완전명이다). 그래서 CLAUDE.md 의 «Skill 이름은 동명사, Command 이름은 짧은 명령형» 규칙은 사용자 진입 skill 에 대해 다시 써야 한다. 사용자 진입이 아닌 skill 의 명명은 열려 있다(OQ11).

✎ 이름 혼재·문서 불일치가 D1 의 증상이라는 것은 모델 추론이다 — C7 은 넷을 독립된 불편으로 확인했다.

✎ S1 은 대화형 터미널에서 bare 이름이 어디로 풀리는지도 재라고 했다(헤드리스 실측에서는 Unknown command) — OQ9 의 대화형 실측에 함께 넣는다.

✎ C9·C10 은 S1 의 원안이고 D3 는 그것을 ST1 판정(S5 보완)으로 다듬은 형태다 — 범위(qg 밖 명령 4개)·kill switch 불변·CLAUDE.md 조건이 S5 에서 더해졌다.

✎ C6 의 「명령의 사전 단계를 피하고」는 D2(사전 단계를 skill 안에 둔다)와 긴장한다 — 어느 사전 단계를 늘 돌리고 어느 것을 건너뛸 수 있게 할지는 OQ10 · OQ13 에서 정한다.

✎ qg 면제의 만료 조건은 사용자가 정하지 않았다 — 인터뷰 질문 문구가 「v10 머지 시 만료」를 전제로 깔았을 뿐 S8 의 선택 라벨에는 없다. OQ15 에서 정한다.

✎ S3 이 진짜 문제의 근거다. 명령은 «이제 skill X 를 부르라»고 모델에게 맡기는 한 단계를 끼우는데, 그 단계가 끊긴 것이다. 다만 premortem 에 따르면 skill 본문의 사전 단계도 산문이면 같은 실패가 재발할 수 있다(§5 위험). 그래서 D2 하나만으로는 «확실히 돈다»가 보장되지 않는다 — OQ10.

## 3. Open Questions

- OQ9: `@` 읽기 실패의 원인 — 선행 슬래시(`@/docs/…`)가 루트 기준 절대경로로 풀림 · `/new` 뒤 세션 cwd · 대화형 자동완성의 경로 재작성 중 무엇인가. 헤드리스가 아니라 대화형 실측으로 가른다 → 근거 RC11 · RC26
- OQ10: 사전 단계를 결정론으로 만들 수단(`` !`cmd` `` 사전 치환 · 산문 · hook)을 정하고, 정책으로 shell 실행이 꺼졌을 때 fail-closed 로 막는 방법과 disable-model-invocation 축(부작용 있는 skill 의 자동 발동 vs Skill 도구 연결 끊김)을 정한다 → 근거 RC1 · RC19 · RC22 · RC23
- OQ11: `conducting-interview` 처럼 모델만 부를 수 있는 내부 skill 의 처분 — 진입 층 둘이 «사용자/모델» 축으로 옮겨 가 사전 단계가 우회되지 않게 한다 → 근거 RC3 · RC22 · RC23
- OQ12: qg 밖 명령 4개(interview↔conducting-interview, request-framing↔framing-requests, plugin-audit↔auditing-plugins, project-init 은 새 skill)의 수렴 매핑과 S7 규칙에 맞는 개별 이름 → 근거 RC7 · RC12
- OQ13: Law 1 trivia escape 를 skill 안 어디에 둘지 — 지금 framing-requests 직접 호출은 trivia 를 건너뛰고 끝에서 커밋까지 한다 → 근거 RC2 · RC27
- OQ14: CLAUDE.md 개정 문안 — 조건부 즉시 제거(S5), 사용자 진입 skill 명명(S7), 표면 정합 락(S8)을 문장으로 확정한다 → 근거 RC14 · RC15 · RC16 · RC17 · RC20
- OQ15: 옛 이름 스위프 범위(archive · CHANGELOG · 메모리 · 이미 만든 seed)와 qg 면제의 만료 조건을 구현하는 방법 → 근거 RC10 · RC13 · RC18 · RC25
- OQ16: 쉬운 말 출력 작업(브랜치 `feature/plain-language-voice`)과 README 사용법 절을 편집하는 순서 → 근거 RC8
- OQ17: qg 후속 과제 보고 목록 — 명령 3개 수렴, `--reset`↔`/cancel-qg` 의미 차, stale 버전 표기, 무시되는 frontmatter 키, README 의 `/qg-publish` 누락, 훅·스크립트 안내 → 근거 RC4 · RC5 · RC6
- OQ18: [참고 · direction] qg 면제의 만료를 「v10 머지」에 걸면 v10 이 `commands/qg.md` 진입과 맨 `/qg` 를 유지하므로 머지 순간 표면 정합 락이 RED 가 된다 — 만료를 qg 가 실제로 규칙에 수렴한 시점에 걸지 정한다 (리뷰 abf668a4#r1.1)
- OQ19: [참고 · direction] qg v10 ① 컷오버가 CLAUDE.md 메타데이터 절에 무조건 제거 문안을 넣고 kill switch 하나를 개명한다 — D3 의 조건부 문안과 같은 조항의 소유자가 둘이다. C4(이 작업이 규칙을 정함)와 C3(v10 은 자기 설계대로) 중 무엇이 우선인지 정한다 (리뷰 abf668a4 계보 r1·r3)
- OQ20: [참고 · direction] qg v10 ① 은 `commands/qg.md` 를 `!` 펜스 진입으로 새로 쓴다 — D2(명령 파일 제거)·C4 와 충돌. v10 이 진입을 skill 로 맞출지, 규칙에 결정론적 `!` 선행 명령 예외를 둘지 정한다 (리뷰 abf668a4 계보 r3)
- OQ21: [참고 · overdesign] shrink: OQ17 의 qg 후속 목록 대부분은 v10 ①·③ 이 지우는 표면이다 — v10 이후에도 남는 어긋남만 남기고 나머지는 「v10 에서 삭제」 한 줄로 묶을지 정한다 (리뷰 d5f7195e#r1.1)
- OQ22: [참고 · direction] plugin-audit 은 0.10.0 이다 — 이름 제거에 일괄 major bump 를 적용해 1.0.0 으로 올릴지(안정 API 선언·CHANGELOG·창 규칙 구속이 따라옴), 0.x 는 minor 로 하는 예외(0.6.0 선례)를 D3 에 적을지 정한다 (리뷰 abf668a4 계보 r2)
- OQ23: [참고 · direction] `!` 블록 사전 치환이 실패하면 모델 턴 0회 · rc=0 으로 조용히 끝난 리포 실측이 있다 — OQ10 의 수단 결정이 이 실패를 소리 나게 드러내는 요건까지 포함할지 정한다 (리뷰 abf668a4 계보 r2)
- OQ24: [참고 · direction] Goal 의 「그 모양으로 부르면 늘 같은 것이 돈다」는 bare 이름에는 보장되지 않는다(`--plugin-dir` 에서는 등록조차 안 됨) — 보장을 완전명에만 걸지, 설치본에서 bare 해석 실측을 설계 필수에 더할지 정한다 (리뷰 abf668a4 계보 r2)

## 4. External Landscape

- 플러그인 skill 은 `/plugin:name` 이고 bare `/name` 은 「다른 명령이 그 이름을 쓰지 않는 한」에서만 돈다; `$ARGUMENTS` 는 친 그대로 들어간다; skill 도 argument-hint 를 갖는다 «cc-skills» — [취함] — 짧은 이름이 조건부 표면이라는 사실과 `@` 를 명령이 직접 풀어야 한다는 근거 [→ OQ9]
- commands 는 older format 이고 skills 가 대체한다; 같은 이름이면 skill 이 이긴다 «cc-components» — [취함] — 진입 구조를 skill 하나로 모으는 방향의 근거 [→ OQ3]
- 실행 중 세션은 로드한 버전을 유지하고 `/reload-plugins` 전까지 갱신이 닿지 않는다; 제3자 마켓 auto-update 는 기본 off «cc-loading» — [중립] — 즉시 제거가 사용자 쪽에서 비동기로 닿는다는 위험 [→ OQ15]
- `claude plugin validate --strict` 를 manifest 의 권위 있는 검사로 둔다 «cc-plugins-ref» — [취함] — 락의 manifest 몫을 공식 검사기에 맡기는 근거 [→ OQ7]
- non-additive 변경 전에 경고하고 alias 는 안정적이어야 한다 «clig» — [피함] — 즉시 제거와 긴장하지만 S5 가 조건부로 수용 [→ OQ4]
- 완전 제거하는 major 앞에 deprecation minor 를 하나 둔다 «semver-faq» — [피함] — 같은 이유로 창은 두지 않는다 [→ OQ4]
- Claude Code 도 `/vim` 을 alias 없이 제거했고 남은 피해는 stale 문서였다 «vim-removal» — [취함] — stale 안내를 락으로 잡는 근거 [→ OQ4]
- 없는 slash 명령은 Unknown slash command 로 loud 하게 실패한다 «unknown-slash» — [중립] — 제거된 이름은 조용히 오작동하지 않는다 [→ OQ4]
- 플러그인 skill 이 내장 명령을 가렸고 'not planned' 로 닫혔다 «collision-builtin» — [취함] — 일반어 단독 금지의 근거 [→ OQ12]
- 두 플러그인이 같은 skill 이름을 쓰면 완전명마저 다른 플러그인으로 풀렸다 «collision-cross-plugin» — [취함] — 고유한 이름이 필요하다는 근거 [→ OQ12]
- disable-model-invocation 을 단 skill 을 사용자가 `/name` 으로 쳐도 모델이 실행을 거부하고 본문을 흉내 낸 보고 «dmi-refusal» — [중립] — 플래그 축이 진입 확실성을 흔들 수 있다 [→ OQ10]
- slash 로 부른 skill 내용이 로드되지 않은 회귀(이후 closed) «slash-skill-regression» — [중립] — skill 경로도 버전에 따라 깨진다 [→ OQ10]
- slash 인자 안의 `@` 지원(v1.0.70)과 절대경로 자동완성 수정(v2.1.119)이 changelog 로만 바뀌어 왔다 «at-in-args» — [취함] — `@` 원인 재현을 대화형으로 해야 하는 근거 [→ OQ9]
- slash 명령 안에서 `@` 를 치면 파일을 끌어오지 않고 실행됐다는 보고 «at-not-pulled» — [중립] — 세 번째 원인 후보 [→ OQ9]
- 리포는 public 이고 star·fork·watcher 0 «github-devbrew» — [중립] — 제3자 사용 신호는 없지만 부재 증명은 아니다 [→ OQ14]

## 5. 기각 · Blind Spots

- 기각 — 즉시 제거를 표면 전체(qg 명령 3개 포함)에 한 번에 적용하고 kill switch 까지 같은 규칙에 묶으며 CLAUDE.md 를 무조건 허용으로 바꾸는 원안 → qg 편집 금지 제약과 양립하지 않고, kill switch 는 이름이 바뀌면 조용히 다시 켜지는 위험 등급이 다르며, 무조건 문안은 선례의 «제3자 설치 확인 전까지» 조건을 지운다 — verdict: refined — ST1 — 부착 6/6
- 기각 — 짧은 이름의 명령을 진입점으로 남기고 사전 단계만 skill 로 옮기는 절충, 또는 명령을 유일한 진입점으로 두고 skill 을 숨기는 안 → 명령→skill 넘겨주기가 남아 S3 의 실패 지점이 그대로이거나, 사용자가 일부러 쓰는 skill 직접 호출을 막는다 (S4)
- 기각 — 짧은 일반어 그대로 · 고유 접두 강제 · 동명사 유지 세 이름 규칙 → 각각 조용한 가림 위험, 짧은 이름 장점 상실, «짧은 이름으로 친다»와의 충돌 (S7)
- 위험 — 숨은 가정: skill 로 옮기면 사전 단계가 확실히 돈다 — skill 본문도 모델이 따르는 산문이라 S3 가 재발할 수 있고, 압축 뒤엔 앞 5,000 토큰만 다시 붙는다; `` !`cmd` `` 는 정책으로 꺼지면 placeholder 로 바뀐다 — «cc-skills» (사용자 처분 S6: 설계 필수)
- 위험 — 숨은 가정: bare 짧은 이름은 언제나 devbrew 로 간다 — 충돌은 사용자 설치 환경에서 일어나 레포 락으로 원리적으로 잴 수 없고 오류 없이 다른 구현으로 간다 — «collision-builtin» (사용자 처분 S6: 설계 필수)
- 위험 — 실패 양식: `@` 원인 재현을 헤드리스로만 하면 대화형 자동완성의 경로 재작성이라는 원인이 가려진다 — «at-in-args» (사용자 처분 S6: 설계 필수)
- 위험 — 실패 양식: 이름 제거 뒤 이미 디스크에 있는 seed·메모리의 옛 호출 문구가 실패하고, 레포 전체 락은 qg 면제를 품어 «풍경이 된 RED»로 굳는다 — «cc-loading» (사용자 처분 S6: 설계 필수)
- 위험 — 숨은 가정 | skill 직접 호출은 사전 단계를 건너뛴다는 seed 후보는 qg 에선 거짓이다 — quality-pipeline 이 kill switch·setup·trivia 를 스스로 돈다 — RC1 (plugins/quality-gates/skills/quality-pipeline/SKILL.md#Step P2 — Setup state.) [RC1 → OQ10]
- 위험 — 실패 양식 | framing-requests 는 trivia 검사를 명령에 맡기고 숨겨지지 않아 직접 호출 시 Law 1 trivia escape 를 건너뛴다 — RC2 (plugins/spec-distill/skills/framing-requests/SKILL.md#진입 선결조건) [RC2 → OQ13]
- 위험 — 숨은 가정 | conducting-interview 는 user-invocable: false 로 사용자 직접 호출만 막은 선례다 — RC3 (plugins/spec-distill/skills/conducting-interview/SKILL.md#user-invocable: false) [RC3 → OQ11]
- 위험 — 실패 양식 | `/qg --reset` 은 SID 를 비어 있지 않은지만 보고 패턴 가드·worktree 정리·KEEP_WORKTREE 를 거치지 않는다 — RC4 (plugins/quality-gates/commands/qg.md#Special argument: `--reset`) [RC4 → OQ17]
- 위험 — 실패 양식 | `/cancel-qg` 설명의 v1.32.0 과 quality-pipeline 제목의 v9.3.5 가 plugin.json 9.3.6 과 어긋난다 — RC5 (plugins/quality-gates/commands/cancel-qg.md#description) [RC5 → OQ17]
- 위험 — 실패 양식 | `hide-from-slash-command-tool` 은 인식되지 않는 키라 오류 없이 무시된다 — RC6 (plugins/quality-gates/commands/cancel-qg.md#hide-from-slash-command-tool) [RC6 → OQ17]
- 위험 — 실패 양식 | `/project-init` 은 argument-hint 가 없고 230줄 본문이 명령에 있으며 대응 skill 이 없다 — RC7 (plugins/project-init/commands/project-init.md#description) [RC7 → OQ12]
- 위험 — 실패 양식 | README 사용법 절의 이름·위치가 플러그인마다 다르고 qg README 사용 블록에 `/qg-publish` 가 없다 — RC8 (plugins/quality-gates/README.md#사용) [RC8 → OQ16]
- 검토 — kill switch 이름 혼재는 이력 잔상이다 — 살아 있는 이름은 `DEVBREW_<PLUGIN>_…` 하나이고 옛 어순은 CHANGELOG·rename 표에만 있다 — RC9 (plugins/plugin-audit/README.md#옛 이름은 fallback 없이 즉시 제거) [RC9 → 없음]
- 위험 — 실패 양식 | 명령 이름을 안내하는 곳에 hook 과 스크립트도 있다(SessionStart advisor · setup-qg.sh) — RC10 (plugins/quality-gates/hooks/session-start-advisor.py#/cancel-qg guidance) [RC10 → OQ15]
- 위험 — 숨은 가정 | `/new` 뒤 cwd 가 seed 를 만든 워크트리로 남는지 아무도 재지 않았다 — RC11 (plugins/spec-distill/skills/framing-requests/SKILL.md#그 디렉토리에서 열어야) [RC11 → OQ9]
- 위험 — 실패 양식 | 같은 플러그인 안에서 reviewing-spec 은 완전명 skill 호출을, 나머지는 bare 명령을 안내한다 — RC12 (plugins/spec-distill/skills/reviewing-spec/SKILL.md#/spec-distill:reviewing-spec <경로>) [RC12 → OQ12]
- 위험 — 실패 양식 | 현재 명령 이름과 핸드오프 모양이 tests 25파일 107곳에 핀돼 있다 — RC13 (plugins/spec-distill/tests/test_seed_at_path_handoff.sh#seed @경로 핸드오프) [RC13 → OQ15]
- 위험 — 숨은 가정 | 창 규칙은 v1.0.0 이상 CHANGELOG 항목 안에 있고 spec-distill·project-init 이 구속된다 — RC14 (CLAUDE.md#제거 전 one-minor deprecation window.) [RC14 → OQ14]
- 위험 — 숨은 가정 | plugin-audit 의 즉시 제거 선례는 «제3자 설치가 생기면 fallback 창» 조건을 달았다 — RC15 (plugins/plugin-audit/README.md#옛 이름은 fallback 없이 즉시 제거) [RC15 → OQ14]
- 위험 — 숨은 가정 | 리포 스스로 «이것은 설치가 없다는 증명이 아니다»라고 적었다 — RC16 (plugins/spec-distill/CHANGELOG.md#이것은 설치가 없다는 증명이 아니다) [RC16 → OQ14]
- 검토 — 은퇴한 스위치를 alias 없이 loud 하게 공시하는 선례가 있다 — RC17 (plugins/spec-distill/scripts/review_entry.py#def retired_advisories) [RC17 → OQ14]
- 위험 — 실패 양식 | 고칠 수 없는 qg SessionStart 훅이 `/cancel-qg` 를 이름으로 안내한다 — RC18 (plugins/quality-gates/hooks/session-start-advisor.py#Run `/cancel-qg` to clear before invoking) [RC18 → OQ15]
- 검토 — spec-distill kill switch 검사는 이미 skill 안에도 있어 명령 파일을 지워도 꺼지지 않는다 — RC19 (plugins/spec-distill/commands/interview.md#DEVBREW_SPEC_DISTILL_DISABLE=1) [RC19 → OQ10]
- 검토 — 리포 선례는 deprecation 릴리스 없이 major 로 제거하되 제거된 인자에 한 줄 공시를 남긴다 — RC20 (docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#6.5.2 deprecation — 친절한 오류로 바로 major) [RC20 → OQ14]
- 위험 — 숨은 가정 | plugins 전체에 disable-model-invocation 이 한 건도 없어 모델이 description 매칭으로 내부 skill 을 바로 부를 수 있다 — RC22 (plugins/spec-distill/skills/conducting-interview/SKILL.md#user-invocable: false) [RC22 → OQ10 · OQ11]
- 위험 — 실패 양식 | 파이프라인은 모델이 Skill 도구로 다음 skill 을 잇는 방식에 의존한다 — 플래그를 일괄로 걸면 연결이 끊긴다 — RC23 (plugins/spec-distill/skills/conducting-interview/references/finishing.md#Skill spec-distill:reviewing-brief $PAYLOAD $AUDIT) [RC23 → OQ10 · OQ11]
- 위험 — 실패 양식 | 핸드오프 정본이 상대경로 `/interview @docs/…` 를 노출하고 `/interview`·`/request-framing` 이 plugins 아래 40파일 358회 나온다 — RC25 (plugins/spec-distill/skills/framing-requests/SKILL.md#호출 모양 — 이 파이프라인에서 여기가 정본이다) [RC25 → OQ15]
- 위험 — 실패 양식 | `/interview` Step 1.5 는 세션 cwd 기준으로 풀어 `@/docs/…` 는 루트 기준 절대경로가 되고, 이 절차도 모델이 Read 를 부르는 산문이다 — RC26 (plugins/spec-distill/commands/interview.md#Step 1.5: `@경로` 인자 풀기) [RC26 → OQ9]
- 위험 — 실패 양식 | framing-requests 는 handoff 직전 git commit 까지 하므로 trivia 우회 직접 호출의 결과가 커밋으로 남는다 — RC27 (plugins/spec-distill/skills/framing-requests/SKILL.md#검사는 command 가 합니다) [RC27 → OQ13]

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > ---
  > type: interview-seed
  > date: 2026-10-08
  > audit_file: 2026-10-08-unify-command-surface-interview.audit.md
  > ---
  >
  > devbrew 가 사용자에게 내놓는 호출 표면 전체를 전수 점검해 한 체계로 통일하는 일을 맡기고 싶다. 명칭,
  > namespace, 등록·노출 방식, 호출 방식, 옵션·인자, alias, 도움말과 문서가 서로 맞는지 보고, 중복·충돌·stale
  > 참조를 정리하며, 어떤 명령을 새로 만들고 어떤 명령을 없앨지 결정까지 내려야 한다.
  > 점검 대상은 slash 명령, slash 로 부를 수 있는 skill, kill switch 환경변수, 명령 인자로 넘기는 핸드오프 문구(skill 이 다음 단계로 안내하는 명령 문구 포함) 넷 전부다. (사용자 확인)
  > 이번 사이클은 점검·결정에서 멈추지 않고 구현까지 이 브랜치 하나로 간다. (사용자 확인)
  >
  > 왜 하는가. 불편은 넷 다다 — 명령 오류, 무엇을 칠지 헷갈림, 문서와 실제의 불일치, 쓸모없는 명령. (사용자 확인)
  > 대표 사례가 `/interview @…` 다.
  > /interview 오류는 @ 경로를 읽다 실패해 ‘읽지 못했다’ 메시지를 내고 멈춘 것이다. (사용자 확인)
  > @ 읽기 실패의 원인은 사용자가 모르므로 하류가 재현으로 가른다. (사용자 확인)
  >
  > 사용자의 호출 습관은 통일 기준을 정할 때의 입력 중 하나다. 무엇을 기준으로 통일할지는 열려 있다.
  > 사용자는 플러그인 접두 없는 짧은 이름으로 명령을 친다. (사용자 확인)
  > 사용자는 명령을 거치지 않고 skill 을 slash 로 직접 부르는 경로를 일부러 쓴다. (사용자 확인)
  > skill 을 직접 부르는 이유는 넷 다다 — 대응 명령이 없고, 명령보다 확실히 돌고, 명령의 사전 단계를 피하고, 이름이 더 정확하다. (사용자 확인)
  > 이 회의 자체도 `/request-framing` 이 아니라 `/spec-distill:framing-requests` 로 들어왔다.
  >
  > 경계와 이웃 작업. 진행 중인 작업 둘이 같은 표면을 건드린다 — qg v10 재건과 쉬운 말 출력 작업(README·출력 문구)이다.
  > 이 작업이 명령 체계 규칙을 정하고, qg v10 재건과 쉬운 말 출력 작업은 그 규칙을 따른다. (사용자 확인)
  > quality-gates 파일은 이 작업에서 고치지 않고 점검 보고에만 올린다. (사용자 확인)
  > qg v10 은 자기 설계대로 진행하고, 이 작업의 규칙과 어긋나는 qg 부분은 이 작업의 점검 보고에 후속 과제로 남긴다. (사용자 확인)
  >
  > 깨짐과 집행.
  > 이름을 바꾸거나 없애는 명령은 alias 없이 바로 제거하고 major bump 한다. (사용자 확인)
  > CLAUDE.md 의 one-minor deprecation window 규칙을 즉시 제거를 허용하도록 바꾼다. (사용자 확인)
  > 통일한 명령 규칙은 테스트(락)로 집행한다. (사용자 확인)
  >
  > 다시 검증할 것 — 첫째, 아래 후보들은 Phase 0 이 파일만 읽고 본 것이다. 하나도 실행해 확인하지 않았다.
  > 명령과 user-invocable skill 이 한 기능에 진입점 둘을 만들고, skill 직접 호출은 명령이 하는 일(trivia 검사 ·
  > `@경로` 풀기 · `setup-qg.sh` · 인자 파싱)을 건너뛴다. `qg-publish` 와 `cancel-qg` 의 접두·접미 혼재,
  > `request-framing` 과 `framing-requests` 의 어순 뒤집기, 하위 명령(`/qg critique`)과 독립 명령의 혼재가 있다.
  > `/qg --reset` 과 `/cancel-qg` 는 같은 세션 폴더를 지우는데 SID 가드는 한쪽에만 있다. `/cancel-qg` 설명에는
  > 낡은 버전 표기가 남아 있다. `/project-init` 은 argument-hint 가 없고, 대응 skill 없이 230줄 본문을 명령에 둔다.
  > README 의 사용법 절은 플러그인마다 이름과 위치가 다르다. kill switch 는 `DEVBREW_<PLUGIN>_DISABLE` 과
  > `DEVBREW_DISABLE_<PLUGIN>`, `DEVBREW_QG_*` 와 `DEVBREW_QUALITY_GATES_*` 가 함께 보인다. 어느 쪽이 살아 있고
  > 어느 쪽이 테스트 속 부정 단언인지는 모른다. 둘째, `@경로` 가 어떻게 동작하는지 실측한 것은 헤드리스 하나뿐이다
  > (2026-09-10). 거기서는 `$ARGUMENTS` 에 글자 그대로 들어갔고, 접두 없는 bare 이름은 `Unknown command` 였다.
  > 사용자가 실제로 쓰는 대화형 터미널에서 bare 이름 · `@` 자동완성 · 선행 슬래시가 어떻게 동작하는지는 재야 한다.
  > 셋째, «짧은 이름으로 친다»와 «skill 을 직접 부른다(지금은 접두 붙은 긴 이름)»가 한 체계 안에서 어떻게 함께 서는지
  > 열려 있다. 명령 층의 사전 단계가 사라지면 Law 1 의 trivia escape 를 어디가 맡을지도 열려 있다. 넷째, qg v10 은
  > 이미 설계문서를 커밋했다(브랜치 `feature/qg-review-e2e-publish`, 2026-10-08). 그 설계에는 `/cancel-qg` ·
  > `/qg-publish` · `publishing-pr-understanding` skill 을 지우고, `/qg critique` 를 v10 범위 밖에 둔다고 적혀 있다.
  > 이것은 v10 설계에 적힌 외부 사실이고 이번 작업의 확정 결정이 아니다. 이 작업의 규칙이 그 결정과 어디서 어긋나는지는
  > 점검이 실제로 대조해 보기 전에는 모른다. 다섯째,
  > 사용자는 테스트(락)로 집행을 골랐다. 결정론을 보안·정확성 게이트에만 두려는 기존 선호(이 회의 밖 출처)와 부딪칠
  > 수 있다. 락이 무엇을 잴지는 사용자에게 다시 묻는다.

## 7. Next Action

이 brief 를 context 로 `superpowers:brainstorming` 호출 → `-design.md` 작성·커밋 → 그 설계문서 경로로
`spec-distill:reviewing-spec`(brainstorming 의 사용자 리뷰 게이트 대신) → 승인 게이트에서 진행을 고른 뒤
`superpowers:writing-plans`. superpowers 가 없으면 이 brief 가 완결 산출물 — 직접 사용.
