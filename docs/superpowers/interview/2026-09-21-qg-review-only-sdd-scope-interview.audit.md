---
type: interview-seed-audit
payload: 2026-09-21-qg-review-only-sdd-scope-interview.md
created_at: 2026-09-21
session_id: 9895ffee-0163-4e99-a7f1-10810a8c9b77
source: spec-distill framing-requests
---

# qg review-only + SDD 기준 스코프 — Interview Seed Audit

> 순수 텔레메트리 — 다음 세션의 첫 턴 `/interview @<seed 경로>` 가 가리키는 것은 payload(seed)
> 파일이고, 여기에는 확산·압축이 어떻게 진행됐는지의 과정 기록만 남는다. payload 의 `audit_file`
> 이 이 파일을 가리킨다.

## 1. 원문

### `/spec-distill:framing-requests` 인자 (2026-09-21, 최초 요청)

```
qg 리뷰만으로 바꾸고(테스트는 반드시해야지sdd처럼), 반드시 필요한
  관점(서브에이전트)를 디스패치, 그리고 qg진행할 스콥을 기본으로 sdd기준으로
```

### 라운드 1 자유 입력 (SDD 스코프 질문에 대한 답, 선택지 밖)

```
브랜치 단위가 맞는데 요즘 보니 sdd로 큰 작업을 하면 여러 브랜치를 만들면서 진행하더라고 그래서 그거 브랜치 다를 보고 싶다는 의도였어 
```

### 라운드 2 자유 입력 (테스트 강제도 질문에 딸려 온 요청)

```
1, 차등테스트가 뭐야 그리고 이거 더 개선도 가능한 부분 있을지도 봐줘, 아니면 더 좋은 방향이나 
```

### 라운드 3 자유 입력 (확인 질문에 딸려 온 관찰)

```
adversarial 은 review shared 모듈 입장에서 옛날게 아닌가 싶기도 해 
```

## 2. 질문 전체

### 라운드 0 — 워크트리

- 물은 것: `feature/<kebab-topic>` 워크트리를 만들고 거기서 시작할까요? 이 브랜치 하나에서 인터뷰·설계·계획·구현까지 갑니다. (origin/main 에 없는 커밋 0개) 거절하면 현재 디렉토리에서 진행합니다.
  - 선택지: 만들고 시작 (권장) « / » 현재 디렉토리에서
  - 당신이 답한 것: 만들고 시작 (권장)

### 라운드 1

- 물은 것: 「qg 리뷰만으로」 — Runtime 게이트는 분리 가능한 두 기계입니다. ① 차등 테스트 실행(R4/R5b/R6 — merge_base 트리 vs HEAD 트리를 짝지어 돌려 fail 귀속을 가린다) ② 샌드박스 runtime-verifier(R5a — 앱 부팅 + 브라우저로 spec AC 검증). 무엇을 없앰나요?
  - 선택지: ②만 제거 « / » ①② 둘 다 제거 « / » 제거 없이 기본값만
  - 당신이 답한 것: ②만 제거
- 물은 것: 「테스트는 반드시 해야지 sdd처럼」 — SDD 는 implementer 가 돌리고 그 보고서가 공식 증거입니다(「Reviewers will not re-run tests for you」). qg 는 반대로 self-report 를 안 믿고 오케스트레이터가 직접 두 번 돌립니다. 어느 모델을 따르나요?
  - 선택지: qg 가 직접 돌린다 (현행 유지) « / » 증거를 읽고 막는다 « / » 둘 다 — 증거 우선, 없으면 실행
  - 당신이 답한 것: qg 가 직접 돌린다 (현행 유지)
- 물은 것: 「반드시 필요한 관점(서브에이전트)를 디스패치」 — 지금은 Tier A 바닥 2명(security-reviewer·adversarial) 항상 + Tier B codex + Tier C 최대 6명을 모델이 고릅니다. 어느 방향으로 바꾸나요?
  - 선택지: 줄인다 — 필요한 것만 « / » 빠뜨리지 않는다 — 커버리지 « / » 둘 다 — 도출된 집합
  - 당신이 답한 것: 둘 다 — 도출된 집합
- 물은 것: 「qg진행할 스코프를 기본으로 sdd기준으로」 — 오늘 qg 기본은 git 파생 `session`(커밋분 ∪ dirty ∪ untracked)이고 SDD 결합은 0 입니다. SDD 는 `.superpowers/sdd/<plan>/` 에 per-task BASE·리뷰 패키지·원장을 둡니다. 「sdd기준」은 무엇을 읽는 것인가요?
  - 선택지: per-task BASE..HEAD « / » 리뷰 패키지 파일 « / » whole-branch 기본 « / » 있으면 SDD, 없으면 git
  - 당신이 답한 것: (기타 — 자유 입력) 브랜치 단위가 맞는데 요즘 보니 sdd로 큰 작업을 하면 여러 브랜치를 만들면서 진행하더라고 그래서 그거 브랜치 다를 보고 싶다는 의도였어

### 라운드 2

- 물은 것: 「한 작업의 브랜치들」을 무엇이 식별하나요? SDD 원장은 브랜치를 하나만 적어서 거기서는 못 나옵니다.
  - 선택지: spec/design 문서 « / » PR 스택 « / » 사용자가 명시 « / » origin/main 밖 전부
  - 당신이 답한 것: spec/design 문서
- 물은 것: 「도출된 집합」이 Tier A 바닥까지 삼키나요? 오늘 security-reviewer·adversarial 은 스코프 무관 항상이고, 모델이 못 뺍니다(사용자 kill switch 로만 꺼짐).
  - 선택지: 바닥은 그대로 « / » 전부 도출 — 바닥 없음 « / » adversarial 만 바닥
  - 당신이 답한 것: 전부 도출 — 바닥 없음
- 물은 것: 차등 테스트 실행이 이제 어느 정도로 「반드시」인가요? 오늘은 선택적인 Runtime 게이트 안에 있어 Decision 1 에서 통째로 생략됩니다.
  - 선택지: 항상 — 생략 불가 « / » 영향 있을 때 항상 « / » 기본 on, 인자로 off
  - 당신이 답한 것: 1, 차등테스트가 뭐야 그리고 이거 더 개선도 가능한 부분 있을지도 봐줘, 아니면 더 좋은 방향이나
- 확인 질문: 라운드 1 의 풀이
  - 내가 읽은 것: 「샌드박스 runtime-verifier 와 그에 딸린 것(샌드박스 생성·폐기 · mutation guard · 브라우저 플로우 · spec AC 런타임 검증)만 제거하고, 차등 테스트 실행은 리뷰 파이프라인 안에 남긴다」 — 고름
  - 내가 읽은 것: 「「sdd처럼」은 실행 주체가 아니라 「빠질 수 없다」는 강제성을 가리킨다 — 테스트는 여전히 오케스트레이터가 기준선·HEAD 양쪽에서 직접 돌려 귀속을 가린다」 — 고름
  - 내가 읽은 것: 「리뷰어 집합은 고정 명단이 아니라 스코프에서 도출한다 — 스코프가 요구하는데 없으면 추가하고, 스코프와 무관하면 따로 부르지 않는다」 — 고름
  - 내가 읽은 것: 「스코프 단위는 브랜치가 맞고, 다만 한 작업이 여러 브랜치에 걸쳐 있을 때 그 브랜치들 전부가 한 번의 리뷰 대상이 되어야 한다」 — 고름

### 라운드 3

- 물은 것: 「바닥 없음」에 반대 근거가 있어 한 번만 다시 묻습니다. qg SKILL 자신이 「floor 구성원이 빠지면 그 iteration 의 clean 이 뜻하는 바 자체가 달라진다」고 적고 있고, CLAUDE.md 는 reviewer persona 약화를 보안 리뷰 대상으로 봅니다. 그래도 바닥을 없앱니까?
  - 선택지: 그래도 바닥 없음 « / » 바닥 유지로 되돌린다 « / » 바닥 없애되 공시 의무 « / » 인터뷰에서 다시
  - 당신이 답한 것: 그래도 바닥 없음
- 물은 것: 차등 테스트의 「file 입도 안의 새 실패가 안 보인다」 결함을 이번 범위에 넣나요? 이 리포 자신의 스위트가 전부 file 입도라 직격합니다.
  - 선택지: 넣는다 — 실패 수까지 기록 « / » 넣는다 — 케이스 입도 « / » 범위 밖 « / » 인터뷰에서 판단
  - 당신이 답한 것: 넣는다 — 실패 수까지 기록
- 물은 것: 스코프가 여러 브랜치가 되면 차등의 기준선을 무엇으로 잡나요? 공통 조상이 뒤로 밀릴수록 기준선 트리가 낡아 BASELINE_UNRUNNABLE 이 상시화될 수 있습니다.
  - 선택지: 대상 브랜치들의 공통 조상 « / » origin/main 고정 « / » 브랜치마다 따로 차등 « / » 인터뷰에서 판단
  - 당신이 답한 것: 대상 브랜치들의 공통 조상
- 확인 질문: 라운드 2 의 풀이
  - 내가 읽은 것: 「한 작업의 경계는 spec/design 문서가 정하며, 그 spec 을 인용하는 plan 들의 브랜치 전부가 한 번의 qg 리뷰 대상이 된다」 — 고름
  - 내가 읽은 것: 「Tier A 의 항상-디스패치 바닥을 없앤다 — security-reviewer 도 adversarial 도 스코프에서 도출되며, 스코프가 요구하지 않으면 부르지 않는다」 — 고름
  - 내가 읽은 것: 「차등 테스트 실행은 항상 돌며, trivia escape 와 kill switch 말고는 빠질 길이 없고 테스트 없는 clean 판정은 나오지 않는다」 — 고름

### 라운드 4

- 물은 것: 「adversarial 이 옛날 것 아닌가」 — 맞습니다. 공유 엔진이 이미 링크로 와 있고 CHANGELOG 가 「호출자 0」을 네 번 적고 있습니다. 이번 범위에 넣나요?
  - 선택지: 넣는다 — 프레이밍 맹목으로 « / » 진단만 넣는다 « / » 범위 밖 « / » 인터뷰에서 판단
  - 당신이 답한 것: 넣는다 — 프레이밍 맹목으로
- 물은 것: 마지막 — 이 변경으로 무엇이 달라지면 성공인가요? 다음 세션이 설계를 저울질할 때 무엇을 축으로 삼을지를 정합니다.
  - 선택지: 비용·시간 « / » 신뢰도 « / » 단순함 « / » SDD 와의 맞물림
  - 당신이 답한 것: 비용·시간, 신뢰도, 단순함, SDD 와의 맞물림
- 확인 질문: 라운드 3 의 풀이
  - 내가 읽은 것: 「반대 근거를 본 뒤에도 Tier A 항상-디스패치 바닥을 없애는 것이 확정이다 — security-reviewer 도 adversarial 도 스코프에서 도출되며 스코프가 요구하지 않으면 부르지 않는다」 — 고름
  - 내가 읽은 것: 「unit 축을 pass/fail 단일 값이 아니라 상태와 실패 개수를 함께 실어, 양쪽이 모두 빨간 unit 에서도 수가 늘었으면 회귀로 잡는다」 — 고름
  - 내가 읽은 것: 「차등의 기준선은 리뷰 대상으로 묶인 브랜치 전부의 공통 조상이며, 그 작업 전체를 한 덩어리로 본다」 — 고름

### 라운드 5 — 압축 전 잔여 확인

- 확인 질문: 라운드 4 의 풀이
  - 내가 읽은 것: 「코드 경로의 adversarial 자리를 공유 문서-리뷰 엔진의 출처-제거 재비판으로 바꾸는 것을 이번 범위에 넣고, 리뷰어 도출 재설계와 같은 사이클에서 다룬다」 — 고름
  - 내가 읽은 것: 「성공의 척도는 넷 전부이며 어느 하나가 다른 것을 대체하지 않는다 — 비용·시간, 신뢰도, 단순함, SDD 와의 맞물림」 — 고름

## 3. 긴 초안

압축 전 초안 — 크게 그린 다음 깎아낸 원본. seed 로는 나가지 않는다.

### 무엇을 맡기는가

devbrew 의 `quality-gates` 플러그인을 「리뷰 중심 단일 게이트」로 재편한다. 네 갈래다 —
(1) 게이트 구조 축소, (2) 리뷰어 디스패치를 열거에서 도출로, (3) 리뷰 스코프를 「한 작업」
단위로, (4) 차등 테스트의 정밀도 보강. 넷은 서로 물려 있고 특히 (3)과 (4)는 직접 충돌한다.

### 확정된 것 — 사용자가 고른 풀이 열둘

1. 샌드박스 runtime-verifier 와 그에 딸린 것만 제거. 차등 테스트 실행은 남긴다.
2. 「sdd처럼」은 실행 주체가 아니라 강제성. 오케스트레이터가 계속 직접 돌린다.
3. 리뷰어 집합은 스코프에서 도출한다.
4. 스코프 단위는 브랜치. 한 작업이 여러 브랜치면 전부가 한 번의 대상.
5. 한 작업의 경계는 spec/design 문서가 정한다.
6·8. Tier A 항상-디스패치 바닥을 없앤다 (반대 근거 제시 후 재확인).
7. 차등 테스트는 항상 돈다. trivia escape · kill switch 만 예외.
9. unit 축에 실패 개수를 함께 싣는다.
10. 차등 기준선은 대상 브랜치 전부의 공통 조상.
11. 코드 경로 adversarial 을 공유 엔진의 출처-제거 재비판으로 바꾼다.
12. 성공의 축은 넷 전부 — 비용·시간, 신뢰도, 단순함, SDD 와의 맞물림.

### 레포에서 실측한 것 — 다음 세션이 다시 캐면 비싼 것들

**Runtime 게이트는 두 기계다.** R4/R5b/R6 은 오케스트레이터 소유 차등 테스트 실행이고,
R5a 는 샌드박스 runtime-verifier 다. `references/runtime-gate.md` 의 「호출 주체 불변식」이
둘을 합치는 것을 금지한다 — verifier 가 자기 턴에서 테스트를 돌려 self-report 하는 경로는
금지이고 오케스트레이터 호출 결과가 authoritative 다.

**차등의 판정 표는 16칸 총 함수다** (`diff-test-results.py`). 축 사상은
pass→P · fail→F · error→F · absent→A · unrun→U. (P,F)=NEW_REGRESSION, (A,F)=NEW_TEST_RED
둘만 `DEFECTS` 이고 FAIL 을 만든다. (F,F)=PRE_EXISTING 은 일부러 FAIL 이 아니다 — 코드
주석이 그 이유를 적는다: devbrew 자신의 stale red 가 첫 실행부터 게이트를 막으면 이 설계는
쓸 수 없다. 기준선 축 U 는 BASELINE_UNRUNNABLE → degraded → PASS 불가로 fail-closed.

**unit 입도 표** (`run-test-selection.sh` 의 `granularity_of`): pytest·unittest·shell·jest·
vitest → file · go → package · cargo·make·npm-script → bulk. 이 리포 자신의 스위트는 전부
file 이다. 축 값이 그 파일 실행의 rc 하나라, 이미 RED 인 파일에 새 실패를 더하면
(F,F)=PRE_EXISTING 으로 접혀 원리적으로 안 보인다. bulk 는 한 rc 가 전 unit 에 도말되며
R6 가 그 조합을 degraded 로 내린다.

**기준선 해소에 부모 브랜치 후보가 없다** (`resolve-baseline.sh`): origin/HEAD →
origin/main → origin/master → local main → local master 순뿐이다. 그래서 스택 위에서
앞 브랜치가 이미 머지됐거나 형제 브랜치면 그 변경은 `merge_base..HEAD` 에서 안 보인다.
`same_as_head` · `ahead` 두 키로 부분 변조를 공시만 하고 판정하지 않는다.

**SDD 원장은 브랜치를 하나만 적는다.** 이 리포의 세 워크스페이스
(`.superpowers/sdd/<plan>/progress.md`) 전부 `Branch: <하나>` 줄을 갖는다. SDD SKILL 도
plan 하나당 워크스페이스 하나 · 마지막 단계가 whole-branch 리뷰다. 즉 여러 브랜치가
생기는 층은 SDD 가 아니라 그 위층 — spec/design 하나에서 plan 여럿, PR 여럿. 실제 사례:
`docs/superpowers/specs/2026-09-06-document-review-redesign-design.md` 하나에서 PR #154·
#155·#156·#157 이 각기 다른 브랜치로 나왔다.

**SDD 의 테스트 분업은 qg 와 정반대다.** `implementer-prompt.md` 가 「Reviewers will not
re-run tests for you — your report is the test evidence」라고 적는다. qg 는 self-report 를
안 믿는 쪽을 골랐다. 사용자는 실행 주체는 qg 쪽을 유지하고 강제성만 SDD 쪽을 취한다.

**공유 문서-리뷰 엔진이 qg 에 링크로 와 있으나 호출자가 0 이다.**
`plugins/quality-gates/scripts/` 의 `docreview_state.py` · `docreview_route.py` ·
`docreview_anchor.py` · `run_docreview_codex_reviewer.sh` 는 `shared/docreview/` 를 가리키는
심볼릭 링크이고, qg CHANGELOG 가 네 군데에서 「호출자는 여전히 0 — `/qg critique` 전환은
후속 major PR 그대로다」를 반복한다. 반면 회계 층은 이미 공유다 —
`synthesize_findings.py` 가 `adjudication.Ledger` 와 `render_disposition.disposition_lines`
를 import 한다(둘 다 `shared/adjudication/` 링크).

**adversarial 자리가 셋이다.** `plugins/quality-gates/agents/adversarial.md`(코드 경로) ·
`plugins/quality-gates/agents/artifact-adversarial.md`(산출물) ·
`shared/docreview/agents/doc-recritic.md`(문서, 프레이밍 맹목). 결정적 차이는 입력이다 —
앞의 둘은 finding 을 **출처와 함께** 받고, `doc-recritic` 은 출처를 벗긴 목록과 문서와
프로필 셋만 받는다. qg 의 `adversarial` 은 자기 페르소나에서 「the single model-based
judgment gate」로 선언돼 있어, 사용자가 보는 모든 finding 이 그 좌석을 통과한다.

### 긴장 — 설계가 풀어야 할 것

**(3) × (4) 충돌.** 스코프를 여러 브랜치로 넓히면 공통 조상이 뒤로 밀린다. 기준선 트리가
그만큼 오래된 커밋이 되고, 오래된 트리는 빌드·의존성 설치가 깨질 확률이 높아
BASELINE_UNRUNNABLE → degraded → PASS 불가가 상시화될 수 있다. 「테스트 항상 돈다」와
「기준선은 공통 조상」이 함께 서면 이 경로가 기본 경로가 된다.

**바닥 제거의 대가.** qg SKILL 자신이 「floor 구성원이 빠지면 그 iteration 의 clean 이
뜻하는 바 자체가 달라진다」고 적고 그 근거로 security-reviewer 를 loud advisory 대상으로
둔다. CLAUDE.md 는 reviewer persona 약화를 보안 리뷰 대상으로 본다. 사용자는 반대 근거를
보고도 바닥 없음을 확정했다 — 재발견 금지이되 반증은 열려 있다.

**「도출」의 집행 지점이 비어 있다.** 오늘 Tier C 선택은 명시적으로 model-owned 이고
결정론 셀렉터가 없다(P8 경량성). 바닥까지 도출로 바뀌면 이제 **아무 리뷰어도** 결정론적
보장이 없다. 도출이 규칙인지 재량인지, 규칙이면 무엇이 그것을 집행하는지가 열려 있다.

**spec → 브랜치 매핑의 실재 배관이 없다.** spec 이 경계를 정한다는 결정은 났지만, 어떤
브랜치가 어떤 spec 에 속하는지를 기계가 읽을 자리가 지금 없다. SDD 원장의 첫 줄이 plan 을
이름 짓고 plan 이 spec 을 이름 짓지만, 그 사슬은 그 plan 의 워크트리 안에서만 보인다.

**제거의 파급.** runtime-verifier 제거는 spec AC 런타임 검증 · 브라우저 플로우 ·
mutation guard · 샌드박스 워크트리 배관 · `block_policy` · Decision 2 · NEEDS_RESOLUTION
루프를 함께 들어낸다. SemVer major 이고 `runtime-gate.md` 1206줄의 상당 부분이 사라진다.

## 4. 비평과 냉독

### 라운드 3 — 탐지 (doc-critic)

> ## doc-critic — seed 프로필 (층 1 억제 검사). 2건.
>
> ```docreview-layer1
> - ref: c1
>   layer: 1
>   category: premature_closure
>   anchor: "#__doc__"
>   disposition: fix
>   summary: "사용자의 「아니면 더 좋은 방향이나」를 초안이 「바깥(웹)을 보는 반쪽」으로 분류해 landscape·steelman·blind-spot 에 넘기는데, 원문에는 그 반쪽이 레포 밖이라는 근거가 없다 — 레포 «안»의 대안 방향(차등 테스트 자체를 다른 기계로 바꾸는 것 등)은 이번 단계에서도 다음 단계에서도 주인이 없어진다."
>   edit_scope: "#__doc__"
>   evidence: "원문 «이거 더 개선도 가능한 부분 있을지도 봐줘, 아니면 더 좋은 방향이나» ↔ 초안 «바깥을 보는 반쪽(「더 좋은 방향」)은 이 단계가 레포는 읽되 웹은 보지 않아 손대지 않았고, landscape·steelman·blind-spot 이 그것을 맡는다» · 초안이 레포 안쪽 반쪽을 «실패 개수 한 축»(+미결 후보 하나)으로 닫는다"
> - ref: c2
>   layer: 1
>   category: premature_closure
>   anchor: "#__doc__"
>   disposition: fix
>   summary: "「넷 전부이며 어느 하나가 다른 것을 대체하지 않는다」가 성공 척도의 충돌 순서를 «없는 질문»으로 만들지만, 같은 초안이 그 축들이 정면으로 부딪히는 긴장 둘을 적고 있다 — 충돌 시 무엇이 이기는지는 묻지도 정해지지도 않았다는 사실이 초안에 없다."
>   edit_scope: "#__doc__"
>   evidence: "당신이 답한 것 «비용·시간, 신뢰도, 단순함, SDD 와의 맞물림» ↔ 초안 «성공의 척도는 넷 전부이며 어느 하나가 다른 것을 대체하지 않는다» · 초안 «기준선 실행 불가로 인한 PASS 불가가 예외가 아니라 기본 경로가 될 수 있다»(비용·시간 ↔ SDD 맞물림) · 초안 «Tier A 바닥까지 도출로 바뀌면 그 두 자리에도 결정론적 보장이 남지 않는다»(단순함 ↔ 신뢰도)"
> ```
>
> ```docreview-layer2
> []
> ```
>
> ### 검사 기록 (findings 아닌 것 — 왜 0 이 아니라 2 인지)
>
> **(사용자 확인) 11개 전수 대조 — 전부 통과.** 초안의 «(사용자 확인)» 문장 열하나를 audit `## 2` 의 「고름」 풀이와 한 문장씩 맞췄고, 열하나 모두 대응하는 확인 질문 풀이가 «고름» 으로 존재한다(R2 풀이 4 · R3 풀이 3 · R4 풀이 3 · R5 풀이 2 중 해당분). 프로필이 정한 `inference_as_decision` 판정식으로는 0건.
>
> **«당신이 답한 것» 10줄과 초안의 서술 대조 — 모순 0.** ②만 제거 · qg 가 직접 돌린다 · 둘 다 도출된 집합 · spec/design 문서 · 전부 도출 바닥 없음 · 그래도 바닥 없음 · 넣는다(실패 수까지 기록) · 대상 브랜치들의 공통 조상 · 넣는다(프레이밍 맹목으로) · 넷 전부. 초안이 뒤집거나 강화한 자리 없음.
>
> **원문 4블록의 모든 절이 초안에 살아 있다.** 「기본으로」의 열림(세 모드 override vs 대체)은 초안이 명시적으로 «묻지도 정해지지도 않았다» 로 보존했고, Tier B codex availability-floor 도 열린 것으로 남겼다. 「여러 브랜치」 관찰은 «사용자의 자기 관찰 + 사례 하나로만 뒷받침, 일반성 미측정» 으로 caveat 되어 `example_as_requirement` 도 0건.
>
> **초안의 레포 사실 주장 9건을 파일로 실제 확인 — 전부 참.** 틀린 사실을 근거로 한 finding 을 내지 않기 위해 다음을 읽었다(전부 워크트리 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope` 기준, SDD 원장만 메인 체크아웃):
> - `plugins/quality-gates/scripts/diff-test-results.py` — `ATTR` 가 16칸 총 함수, `DEFECTS = {"NEW_REGRESSION", "NEW_TEST_RED"}` 즉 `(P,F)`·`(A,F)` 둘만 FAIL, `(F,F)`=`PRE_EXISTING` 은 주석 «devbrew 자신의 stale red가 첫 실행부터 게이트를 막으면 이 설계는 쓸 수 없다» 와 함께 의도적 제외. ✔
> - `plugins/quality-gates/scripts/resolve-baseline.sh` — base 후보는 `origin/HEAD`→`origin/main`→`origin/master`→로컬 `main`→`master` 뿐, 부모 브랜치 후보 없음. ✔
> - `plugins/quality-gates/scripts/run-test-selection.sh` `granularity_of()` — `pytest|unittest|shell|jest|vitest→file`, `go→package`, `cargo|make|npm-script→bulk`. 초안의 표와 글자 그대로 일치. ✔
> - `…/references/runtime-gate.md` — 「호출 주체 불변식 (load-bearing)」 블록 실재, verifier self-report 경로 금지. ✔
> - `plugins/quality-gates/CHANGELOG.md` — 「호출자는 여전히 0」류 문구가 [7.6.0] 안에서 정확히 네 줄(34·35·36·37). ✔
> - `shared/docreview/agents/doc-recritic.md` — «출처 라벨이 지워진 finding 목록» 을 받는다고 명시. ✔
> - `…/quality-pipeline/SKILL.md` — Tier A floor(security-reviewer+adversarial, 스코프 무관 항상) · Tier B codex availability-floor · Tier C 모델 소유(결정론 셀렉터 없음) · 「floor 구성원이 빠지면…」 문장 · security-reviewer 결손 loud advisory 전부 실재. ✔
> - `.superpowers/sdd/` 워크스페이스 셋 — 라벨 `Branch:` 둘 · `브랜치:` 하나, 셋 다 `Spec:` 줄 동반, `2026-08-27-request-framing-phase0/progress.md` 의 값이 `worktree-feature+request-framing-phase0`(실재 브랜치명 아님). ✔
> - `.superpowers/sdd/.gitignore` = `*`. ✔ (부수 관찰: 이 `*` 때문에 `Grep`/ripgrep 이 원장 트리를 통째로 건너뛴다 — 확인은 `Read` 로만 됐다. 하류가 원장을 기계로 읽으려 할 때 같은 벽을 만난다.)
>
> ### 남긴 판단 둘 (일부러 finding 으로 내지 않음)
>
> - **「넣는다 — 프레이밍 맹목으로」→「공유 문서-리뷰 엔진의 출처-제거 재비판으로 바꾼다」 번역.** 옵션 라벨의 「프레이밍 맹목」 이 초안에서 「출처-제거」 로 바뀌어 있는데, 리포 안에서 `doc-recritic` 은 «프레이밍을 못 보는» 이면서 «출처 라벨이 지워진 목록을 받는» 같은 agent 라 번역은 충실하다. 다만 «엔진을 그대로 재사용» 인지 «성질만 코드 경로에 이식» 인지는 초안도 원문도 가르지 않는다 — 문서 엔진을 코드 경로에 쓰는 문제라 설계에서 갈릴 것이다. 확인 풀이가 «고름» 이라 프로필 판정식상 finding 은 아니다.
> - **바닥 제거가 SKILL 의 별개 결정론 장치와 맞물리는 것.** `SKILL.md` Step 4.5 의 honest-verdict floor 가 `$security_review_absent`(오늘은 kill switch 로만 참)를 입력으로 쓰므로, Tier A 바닥이 사라지면 그 결정론 장치의 입력 의미가 바뀐다. 초안이 언급하지 않았지만 이 프로필의 층 1 rubric(억제 4범주)에 없는 축이라 범주를 지어내지 않고 여기 남긴다 — 설계 단계로 넘기길 권한다.
>
> ### supersedes 미기재 사유
>
> `<prior_finding_ids>` 여섯 개(7c0f5fba#r1.2·r1.3·r2.1·r2.3, 3720b2b7#r1.2·r1.3)의 «내용» 이 입력에 없어 동일 결함인지 판정할 수 없었다. 틀린 지목보다 공백이 낫다고 보고 비웠다 — c1·c2 가 그중 하나와 같은 결함이면 라우팅 쪽에서 이어 붙여 달라. 참고로 audit `## 6. 리뷰 결정` 은 r2 덩어리 1~4 가 전부 «그대로 둔다» 이므로, 이전 라운드의 편집 제안 넷은 사용자가 반려한 상태다.

### 라운드 3 — codex

> (이 라운드에 산출물 없음 — docreview-codex.yaml · 사유: kill_switch, 사용자가 라운드 3 에서 codex 축을 껐다)

### 라운드 3 — 재비판 (doc-recritic)

> ```docreview-recritic
> verdicts:
>   - f: f1
>     verdict: confirm
>   - f: f2
>     verdict: confirm
> added: []
> ```
>
> 판단 근거.
>
> **f1 — confirm (layer 1 · premature_closure · fix 적정)**
> 원문은 `이거 더 개선도 가능한 부분 있을지도 봐줘, 아니면 더 좋은 방향이나` 한 줄뿐이고, 「더 좋은 방향」이 레포 «바깥»을 뜻한다는 단서가 원문에도 질문 문구·선택지 어디에도 없다. 그런데 초안은 `바깥을 보는 반쪽(「더 좋은 방향」)은 이 단계가 레포는 읽되 웹은 보지 않아 손대지 않았고, landscape·steelman·blind-spot 이 그것을 맡는다` 로 그 반쪽을 웹을 보는 층에 귀속시킨다. 분류 자체가 근거 없는 추론이고, 결과적으로 레포 «안»의 대안 방향(차등 테스트 기계 자체의 교체 등)은 이 단계에서도(초안이 고른 것은 `실패 개수 한 축`뿐) 하류에서도 주인이 없다. 초안이 다른 열림들은 `묻지도 정해지지도 않았다` · `이번 범위인지 아닌지가 정해지지 않았다` 로 명시 보존하는 것과 대비되어, 이 자리만 분류-후-위임으로 닫혔다. 처분은 `fix` 가 맞다 — 사용자에게 물을 것이 아니라 초안이 그 반쪽의 레포-안 몫이 열려 있음을 도로 적으면 된다.
>
> **f2 — confirm (layer 1 · premature_closure · fix 적정)**
> `(사용자 확인)` 표기 자체는 유효하다 — 라운드 5 확인 질문의 「고름」 풀이에 `성공의 척도는 넷 전부이며 어느 하나가 다른 것을 대체하지 않는다` 가 그대로 있어 rubric 의 `inference_as_decision` 에는 걸리지 않는다. 결함은 다른 자리다: 「어느 하나가 다른 것을 대체하지 않는다」가 충돌 시 우선순위를 «물을 것이 없는 것»처럼 보이게 만드는데, 같은 초안이 그 축들이 정면으로 부딪히는 자리 둘을 스스로 적는다 — `기준선 실행 불가로 인한 PASS 불가가 예외가 아니라 기본 경로가 될 수 있다`(신뢰도·SDD 맞물림 ↔ 비용·시간), `Tier A 바닥까지 도출로 바뀌면 그 두 자리에도 결정론적 보장이 남지 않는다`(단순함 ↔ 신뢰도). 초안은 `오늘 qg 의 세 모드…는 묻지도 정해지지도 않았다` · `Tier B codex 의 availability-floor…는 묻지 않았고` 처럼 미질문 열림을 적는 관례를 스스로 세워 놓고, 이 축의 충돌 순서만 그 목록에서 빠져 있다. `fix` 가 맞다 — 순위를 여기서 정하라는 것이 아니라 「넷의 충돌 순서는 묻지도 정해지지도 않았다」를 초안이 적으면 되고, 그러면 인터뷰가 사용자에게 묻는다. (그래서 `decide` 로 올리지 않았다.)
>
> **added: 없음 (0건).** 초안의 `(사용자 확인)` 문장 11개를 audit `## 2. 질문 전체` 의 「고름」 풀이와 한 줄씩 대조했고 전부 대응 풀이가 있다(라운드 2·3·4·5 확인 질문). `trivia escape 와 kill switch 말고는 빠질 길이 없고` 같은 저자-도입 예외 문구도 라운드 3 확인 풀이 안에서 「고름」으로 받아졌다. 「여러 브랜치」 요구 · spec 경계 · 공통 조상 기준선은 모두 확인 풀이에 대응이 있고, 근거 약함(`그 패턴이 얼마나 일반적인지는 재지 않았다`) · 미질문(`세 모드` · Tier B availability-floor · SDD 원장 매핑 세 선택지)은 초안이 이미 열림으로 보존하고 있다. 레포 사실 서술(`diff-test-results.py` 16칸 · 러너 입도 · `resolve-baseline.sh` 부모-브랜치 후보 부재)의 진위는 층 2 영역이고 이 프로필에는 층 2 가 없어 판단하지 않았다.
>
> 처분 하향 요청 없음 · `same_as` 없음 · 층 오분류 없음(둘 다 layer 1 이 맞다).

### 냉독 (seed-readback)

> seed 만 읽고 낸 냉독입니다. 원문도 대화도 레포도 보지 않았고, 판정·점수·개선은 내지 않았습니다.
>
> ## 무엇을 맡기려는 것으로 읽었는가
>
> devbrew 의 `quality-gates` 플러그인을 「리뷰만 하는 것」으로 재편하는 일로 읽었다. 한 군데를 고치는 게 아니라 **네 축을 한 사이클에서 동시에** 바꾸는 일이다 — 게이트 구조(무엇이 남고 무엇이 빠지는가), 리뷰어 구성(누가 불려오는지를 무엇이 정하는가), 리뷰 스코프(한 번의 리뷰가 덮는 범위가 무엇인가), 차등 테스트의 정밀도(회귀를 어디까지 보는가). 그리고 이 넷이 서로 독립 과제가 아니라 같은 재편의 네 면이라는 것, 성공을 잴 때도 비용·시간 / 신뢰도 / 단순함 / SDD 맞물림 넷을 전부 봐야 하고 어느 하나가 다른 하나를 갚지 않는다는 것.
>
> 받는 쪽은 구현자가 아니라 **그다음 설계·인터뷰 단계**로 읽었다. seed 자신이 「설계가 풀어야 할 긴장 둘」과 「다시 검증할 것」을 따로 떼어 적고, landscape·steelman·blind-spot 이 더할 축을 언급하니까. 이 seed 가 맡기는 것은 결론이 아니라 «열린 자리들을 닫는 일»로 읽힌다.
>
> ## 방향이 무엇으로 읽혔는가
>
> **빼는 쪽.** 가장 무거운 기계(샌드박스 runtime-verifier 와 딸린 것 — 샌드박스 생성·폐기, mutation guard, 브라우저 플로우, spec AC 런타임 검증)를 통째로 들어내고, 고정 명단(Tier A 항상-디스패치 바닥)도 없앤다.
>
> 동시에 **남는 것의 강제성은 올린다.** 차등 테스트 실행은 리뷰 파이프라인 안에 남아 항상 돌고, trivia escape 와 kill switch 말고는 빠질 길이 없고, 테스트 없는 clean 판정은 안 나온다. 「sdd처럼」이 실행 주체가 아니라 강제성을 가리킨다는 것 — 테스트는 여전히 오케스트레이터가 기준선·HEAD 양쪽에서 직접 돌려 귀속을 가린다 — 이 대비를 명시적으로 붙잡고 있다.
>
> 또 하나는 **열거에서 도출로.** 리뷰어는 명단이 아니라 스코프에서 나오고, 스코프는 브랜치 하나가 아니라 spec/design 문서가 묶는 브랜치 집합에서 나오고, 차등의 기준선도 그 집합의 공통 조상에서 나온다. 세 자리 전부 「미리 적어 둔 값」에서 「그때 계산해 내는 값」으로 옮긴다.
>
> 그리고 **추상이 아니라 실제 작업 방식에 맞춘다.** git 의 브랜치 단위가 아니라, 사용자가 SDD 로 큰 작업을 할 때 실제로 생기는 모양(한 spec 아래 여러 브랜치)을 스코프 단위로 삼는다. seed 가 「SDD 자신의 마지막 단계도 whole-branch 리뷰라, 여러 브랜치가 생기는 층은 SDD 가 아니라 그 위층」이라고 적은 것이 이 방향의 근거로 읽혔다.
>
> 빼는 방향과 도출 방향이 서로 대가를 청구하고, seed 는 그걸 긴장 둘로 이름 붙여 놓았다 — 스코프를 넓히면 공통 조상이 뒤로 밀려 기준선 트리가 낡고, 「항상 돈다」가 「항상 못 돈다」로 뒤집혀 PASS 불가가 예외가 아니라 기본 경로가 될 수 있다는 것. 그리고 바닥을 없애면 Tier C 처럼 결정론적 셀렉터 없는 모델 재량 자리가 둘 더 늘어난다는 것.
>
> ## 보낸 사람이 무엇을 신경 쓰는 것으로 읽혔는가
>
> **무엇이 결정이고 무엇이 아닌지의 구분.** 사용자가 확인한 문장마다 「(사용자 확인)」이 붙고, 레포를 읽어 알아낸 것은 사실로, 안 물어본 것은 「묻지도 정해지지도 않았다」로 따로 적힌다. 추론이 결정으로 승격되는 걸 막으려는 것으로 읽었다.
>
> **확정의 품질.** Tier A 바닥 제거는 그냥 확정이 아니라 「반대 근거 둘을 보여준 뒤 재확인된 확정」으로 적혀 있고, 그 반대 근거 둘(qg SKILL 자신의 「floor 구성원이 빠지면 clean 의 뜻이 달라진다」 + CLAUDE.md 의 persona 약화=보안 리뷰)이 본문에 그대로 남아 있다. 없앤 것이 무엇을 보장하고 있었는지를 다음 단계가 모른 채로 진행하지 않기를 바라는 것으로 읽었다.
>
> **기존 설계의 의도를 존중.** `(fail,fail)` 이 일부러 FAIL 이 아니고 그 이유(devbrew 자신의 stale red 가 첫 실행부터 게이트를 막으면 설계가 쓸 수 없다)가 코드 주석에 있다는 것, 「호출 주체 불변식」이 verifier self-report 경로를 금지한다는 것을 굳이 적어 두었다. 이번 변경이 무엇을 override 하는지 알고 하라는 것으로 읽었다.
>
> **근거의 강도 공시.** Phase 0 이 센 제거 목록은 「파일을 읽고 센 것이지 구현 착수로 확증한 것이 아니다」, 여러 브랜치 패턴은 「한 사례로만 뒷받침했다」, 실패 개수가 어느 러너에서 실제로 얻어지는지는 「재지 않았다」. 주장마다 얼마나 믿을 수 있는지를 라벨링한다.
>
> **원문 문구가 남긴 열림.** 「기본으로」·「sdd처럼」·「더 좋은 방향」 — 사용자 원문의 단어 하나가 닫지 못한 자리를 셋 다 이름 붙여 남겼다. 특히 「더 좋은 방향」은 «반쪽이 둘이고 둘의 처분이 다르다»고 따로 쪼개 적었다.
>
> **범위의 경계.** adversarial 자리를 공유 문서-리뷰 엔진의 출처-제거 재비판으로 바꾸는 것은 이번 범위 «안», `resolve-baseline.sh` 의 부모-브랜치 후보 부재는 결정과 직결되는데도 «미정», 차등 기계 자체를 다른 것으로 바꾸는 레포 안 대안은 «아직 아무에게도 안 맡겨짐». 셋의 처분이 다르다는 걸 흐리지 않는다.
>
> ## 읽으면서 «이건 모르겠다» 싶었던 곳
>
> 아래는 판정이 아니라 내가 읽으면서 확정하지 못한 자리들이다.
>
> - **게이트가 둘에서 하나가 되는지.** Review 와 Runtime 을 순차로 돈다고 했고 R5a 만 빠지고 R4/R5b/R6 은 리뷰 파이프라인 안에 남는다고 했으니 하나로 합쳐지는 것 같은데, Runtime 이라는 게이트 이름/단계가 살아남는지 사라지는지는 못 읽었다.
> - **Tier A/B/C 가 무엇인지.** 긴장 문단에서 처음 나오고 소개가 없다. Tier A = 항상-디스패치 바닥, Tier B = codex, Tier C = 모델이 고르는 자리로 읽었는데 이건 내 추론이다.
> - **「스코프에서 도출」의 «스코프»가 무엇인지.** 변경 파일 집합인지, diff 내용인지, spec 문서의 내용인지, 셋의 조합인지. 리뷰어 도출 전체가 여기 매달려 있는데 입력의 정체를 못 읽었다.
> - **「sdd처럼」의 원문.** 강제성을 가리킨다는 gloss 는 있는데 원문 문장이 없어서 gloss 말고는 확인할 수 없다.
> - **출처를 벗기는 것이 코드 경로에서 무엇을 사는지.** 세 adversarial 자리의 결정적 차이가 입력이고 `doc-recritic` 만 출처를 벗긴 목록을 받는다는 «사실»은 적혀 있는데, 그 성질이 코드 경로에 필요하다는 것인지 아니면 이미 있는 엔진이라 쓴다는 것인지 못 갈랐다.
> - **16칸 총 함수의 네 번째 상태.** 본문에 `pass`·`fail`·`없음` 셋만 나오는데 16칸이면 축마다 넷이라 하나를 못 읽었다.
> - **실패 개수를 실은 뒤 `(fail,fail)` 이 어떻게 접히는지.** 「수가 늘었으면 회귀」는 적혀 있는데, 수가 같거나 줄었을 때, 그리고 bulk 러너라 개수 자체가 없을 때 어느 쪽으로 가는지는 seed 가 말하지 않는다(개수 부재는 「재지 않았다」로만 표시).
> - **제거가 문서까지 닿는지.** 들어내는 목록은 코드·배관 쪽인데, 그 기계를 서술하는 문서들(예: `references/runtime-gate.md` 의 「호출 주체 불변식」)이 같이 빠지는지 남는지는 못 읽었다.
> - **명시적으로 열려 있다고 적힌 것들** — 나도 여기서 닫히지 않은 걸 확인했다: 오늘의 세 모드(`paths`·`branch`·`session`)가 override 로 남는지 대체되는지 / spec↔브랜치 매핑을 무엇이 담는지(한 줄 정형화 · 별도 자리 · 새 배관 셋 다 열림, 유일한 기존 자리인 SDD 원장은 `.superpowers/sdd/.gitignore` 가 `*` 라 추적 안 되고 라벨도 불균일) / 성공 척도 넷이 부딪힐 때 무엇이 이기는지 / Tier B codex availability-floor 의 처분 / `resolve-baseline.sh` 부모-브랜치 후보가 이번 범위인지 / 「더 좋은 방향」이 레포 안인지 밖인지.
>
> 참고로 내가 본 것은 seed 본문뿐이고, seed 가 이름을 댄 파일들은 열어보지 않았다.

## 5. degrade

**원장 없음 — `no-state-in-phase-0`.** `brief_review_state.py init … --ledger-key framing_degradations`
가 rc 1 이었다. `request-framing` 은 인터뷰 이전이라 `state.local.md` 이 아예 없는 세션이 정상이고,
그 세션에서 `framing_degradations` 원장은 구조적으로 부재한다. 아래 항목들은 원장이 아니라 이 절과
proceed 게이트 질문 텍스트로만 공시된다 — **기록이 없는 것과 degrade 가 없는 것은 다른 사실이다.**

- **codex 축 부재 (라운드 3).** `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1` 로 사용자가 껐다(라운드 3
  시작 전 승인). 엔진 `fin.json` 이 `codex_absent: true` · `codex_reason: yaml_missing_or_broken` ·
  `adjudication_sources_failed: 1` · `adjudication_degraded: true` 로 기록했고 게이트 렌더 첫 줄이
  「codex 없음 — 모델 다양성 0」을 공시했다. 차단하지 않는다 — 모델 다양성 손실은 공시 대상이지
  차단 대상이 아니다(CLAUDE.md Plugin Shape). 근거: 라운드 1·2 에서 codex 가 낸 9건을 재비판이
  9/9 기각했고 그 9건이 전부 같은 논증이었다(아래 항목).
- **프로필 내부 모순 — 이 사이클 밖.** seed 프로필의 `ground_truth` 는 audit `## 2` 의 「내가 읽은
  것」 줄을 정답에서 제외한다고 선언하는데, 같은 프로필의 층 1 `inference_as_decision` 은 그 줄을
  «(사용자 확인)» 표기의 유효성 판정 기준으로 지목한다. codex 는 매 라운드 앞 문장만 적용해 같은
  부류의 finding 을 9건 냈고(R1 4 · R2 5) 재비판이 전부 기각했다. seed 결함이 아니라
  `references/docreview-profiles/seed.md` 의 결함이며 이번 범위 밖이다.
- **라운드 1·2 리뷰어 산출물이 `## 4` 에 전사되지 않았다.** 절차상 7단계 뒤·게이트 앞에 옮겼어야
  했는데 그 라운드에서는 하지 않았고, 엔진 자리의 `critic.txt`·`recritic.txt`·`docreview-codex.yaml`
  은 라운드마다 같은 경로를 덮어써서 지금은 라운드 3 것만 남아 있다. `## 4` 에 있는 것은 라운드 3
  산출물과 냉독뿐이다 — 라운드 1·2 의 원문은 복구 불가이고, 그 라운드의 **처분 결과**만 `## 6` 에
  남아 있다.
- **워크트리** — 만들었다(`feature/qg-review-only-sdd-scope`). 이 항목은 degrade 가 아니라 사실
  기록이다.

## 6. 리뷰 결정

- 편집 · r2 · 덩어리 1 · 그대로 둔다 · "그대로 둔다" —

- 편집 · r2 · 덩어리 2 · 그대로 둔다 · "그대로 둔다" —

- 편집 · r2 · 덩어리 3 · 그대로 둔다 · "그대로 둔다" —

- 편집 · r2 · 덩어리 4 · 그대로 둔다 · "그대로 둔다" —

- 편집 · r3 · 덩어리 1 · 그대로 둔다 · "그대로 둔다" —

- 편집 · r3 · 덩어리 2 · 그대로 둔다 · "그대로 둔다" —

- 편집 · r3 · 확정 직전 덩어리 1 · 그대로 둔다 · "그대로 둔다" —

- 편집 · r3 · 확정 직전 덩어리 2 · 그대로 둔다 · "그대로 둔다" —
