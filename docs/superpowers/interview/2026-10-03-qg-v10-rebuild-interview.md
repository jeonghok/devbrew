---
name: qg-v10-rebuild
type: interview-brief
created_at: 2026-10-03
session_id: c39a2e50-b7ba-4999-ac48-2101dd3242f1
source: spec-distill conducting-interview v0.23.0
next_phase: superpowers:brainstorming
contract: v2
audit_file: 2026-10-03-qg-v10-rebuild-interview.audit.md
user_sourced_items:
  - id: C1
    source: verbatim
    status: confirmed
    statement: "/qg 한 번이 리뷰 → 테스트 → e2e 질문 → 결과 게시까지 이어서 간다."
    evidence: S1
  - id: C2
    source: verbatim
    status: confirmed
    statement: "e2e 는 qg 가 이 변경에 맞는 걸을 경로를 제안하고 사용자가 고르거나 고친 뒤, 에이전트가 걸어 판정을 내고 사람은 감독하다 틀리면 뒤집는다."
    evidence: S1
  - id: C3
    source: verbatim
    status: confirmed
    statement: "e2e 를 돌렸는데 실패하면 qg 판정이 clean 이 될 수 없다."
    evidence: S1
  - id: C4
    source: verbatim
    status: confirmed
    statement: "게시는 /qg 실행마다 새 코멘트로, 동의를 묻지 않고 올린다."
    evidence: S1
  - id: C5
    source: verbatim
    status: confirmed
    statement: "매 코멘트는 그 시점의 이해글과 그 실행의 qg 결과를 함께 담는다."
    evidence: S1
  - id: C6
    source: verbatim
    status: confirmed
    statement: "PR 이 없으면 게시를 건너뛰고 그 사실을 한 줄로 알리며, qg 는 push 나 PR 생성을 하지 않는다."
    evidence: S1
  - id: C7
    source: verbatim
    status: confirmed
    statement: "qg 리뷰는 한 번의 리뷰로 장치를 덧붙이거나 보안을 과하게 경계하거나 선제적 오버 엔지니어링을 처방하지 않아야 한다."
    evidence: S1
  - id: C8
    source: verbatim
    status: confirmed
    statement: "리뷰를 반영한 수정이 원래 의도에서 드리프트하는 것을 특히 피해야 한다."
    evidence: S1
  - id: C9
    source: verbatim
    status: confirmed
    statement: "네 갈래 모두 중심이고 소홀히 하지 않으며, 예산이 문제면 subagent 와 병렬 plan 여럿을 쓴다."
    evidence: S2
  - id: D10
    source: chosen
    status: confirmed
    statement: "e2e pass 는 기대 상태마다 관측 증거가 인용될 때만 성립하고, 빠지면 「미확인」으로 not-certified 다."
    evidence: S5
  - id: D11
    source: chosen
    status: confirmed
    statement: "게시에서 preview·동의·upsert·identity·pr-create·--history 는 걷고, 게시 직전 결정론 secret-scan 한 번과 publish kill switch 는 남기며, 중단된 실행은 게시하지 않는다 — secret-scan 에 걸리면 묻지 않고 게시를 건너뛰고 한 줄로 알리며, kill switch 는 새 게시 sink 로 옮겨 집행하고, 무동의 게시는 사용자의 상시 동의로 규칙에 기록한다."
    evidence: S6
  - id: D12
    source: chosen
    status: confirmed
    statement: "리뷰 다이어트는 처방 단계(리뷰어 dispatch 프롬프트의 correctness·명시 요구 기준 + 재비판의 처방-의도 초과 관문)와 적용 단계(Retry 직전 의도 대조) 양쪽에 두고 새 락·원장은 두지 않는다 — correctness·명시 요구 밖의 지적은 optional 이고, 의도에서 벗어나는 패치는 적용에서 제외하고 그 사실을 공시한다."
    evidence: S7
  - id: D13
    source: chosen
    status: confirmed
    statement: "원래 의도는 커밋 Spec: 트레일러의 spec → 없으면 브랜치 커밋 메시지와 PR 본문 순으로 읽고, mtime 최신 spec 은 쓰지 않는다 — 쓴 출처를 한 줄로 공시하고, 출처를 정하려고 추가 질문을 하지 않는다."
    evidence: S8
  - id: D14
    source: chosen
    status: confirmed
    statement: "SUGGESTION 은 판정을 막지 않는다 — 살아남은 CRITICAL·IMPORTANT 가 있을 때만 defect 이고, SUGGESTION 은 Retry 적용 대상에서 기본 제외한다."
    evidence: S9
  - id: C15
    source: verbatim
    status: confirmed
    statement: "게시는 이전 장치가 과했으므로 바닥부터 지금에 맞게 새로 짓는다."
    evidence: S10
  - id: C16
    source: verbatim
    status: confirmed
    statement: "e2e 는 구현 중 실패가 많았으므로 새로 짓고, 기존에 있던 것은 가능하면 새로 짓는다 — qg 는 오래된 플러그인이라 지금 모델과 Claude Code 에 맞지 않는 것이 많을 것이다(사용자 추정)."
    evidence: S11
  - id: D17
    source: chosen
    status: confirmed
    statement: "재건 범위는 qg 전체(파이프라인·차등 테스트·판정 어휘·스크립트)다."
    evidence: S12
  - id: D18
    source: chosen
    status: confirmed
    statement: "재건은 구성요소마다 한 줄 표(가정·1st-party 대체·교훈·처분)로 삭제/새로/유지를 정하고, v10 을 옆에 세워 구성요소별 독립 PR·릴리스로 갈아끼우며, 옛 교훈은 새 설계의 요구 목록으로 먼저 옮긴다 — 기본 처분은 「가능하면 새로」이고, e2e·게시는 새로 짓고 1st-party 가 대신하는 부분은 삭제하며, 표와 재건에 새 락·원장은 두지 않는다."
    evidence: S13
  - id: D19
    source: chosen
    status: confirmed
    statement: "e2e 질문은 리뷰·테스트 루프가 끝난 뒤 판정 직전에 한 번 오고, 실패하면 Fix-loop 결정을 다시 띄우며, Retry 를 고르면 남은 iteration 안에서 리뷰·테스트·e2e 를 다시 돈다."
    evidence: S16
  - id: C20
    source: verbatim
    status: confirmed
    statement: "오케스트레이터가 e2e 를 다 걷고 판정한다."
    evidence: S17
  - id: C21
    source: verbatim
    status: confirmed
    statement: "Law 2 를 지키려고 과한 장치를 만들지 않는다."
    evidence: S18
  - id: D22
    source: chosen
    status: confirmed
    statement: "오케스트레이터의 e2e 판정은 판정안이고, 승인·뒤집기를 하는 reviewer 는 감독하는 사람이다 — 장치는 두지 않고, 이 해석을 spec·헌장에 한 줄로 기록한다."
    evidence: S19
  - id: D23
    source: chosen
    status: confirmed
    statement: "e2e fail 은 defect 이고, 「안 한다」와 걸을 표면 없음은 판정을 바꾸지 않고 코멘트에 공시하며, 「걸을 것 없음」은 e2e 질문에서 사용자에게 보여 뒤집을 수 있게 한다."
    evidence: S20
  - id: D24
    source: chosen
    status: confirmed
    statement: "코멘트의 qg 결과는 판정 한 줄(판정·사유·개수)이고 나머지는 로컬에 둔다 — S21 이 S9 의 「코멘트에 선택 사항으로」를 대체하므로 SUGGESTION 은 로컬 결과에만 둔다."
    evidence: S21
  - id: D25
    source: chosen
    status: confirmed
    statement: "/qg critique 와 spec-distill 공동 소유 docreview 엔진은 재건에서 빠져 별 사이클로 다루고, 토픽 스코프와 codex 각도는 재건 안에서 한 줄 표로 처분한다."
    evidence: S22
  - id: D26
    source: chosen
    status: confirmed
    statement: "재건으로 사라지는 공개 표면과 소비자 의존은 deprecation 창·공지 없이 즉시 제거한다."
    evidence: S23
  - id: C27
    source: verbatim
    status: confirmed
    statement: "e2e 는 대상의 실제 앱·플로우를 구동하는 것이되, 기계 장치보다 에이전트가 직접 걸어보는 방식에 사람이 감독한다."
    evidence: S1
  - id: D28
    source: chosen
    status: confirmed
    statement: "spec 은 하나이고 이음매(e2e → 판정 → 코멘트)를 AC 로 가지며, plan 은 네 갈래와 이음매로 나눠 병렬화한다."
    evidence: S3
---

# qg v10 재건 — Interview Brief

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming 해답공간으로
> 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다. 텔레메트리는 `audit_file`에 있다.

## 0. 한눈에

**무엇.** quality-gates(qg)를 지금 모델·Claude Code 위의 얇은 v10 으로 다시 짓는다. 한 번의 `/qg` 가
리뷰 → 테스트 → (선택) e2e → PR 코멘트까지 가서 사람이 믿고 판단할 검증 보고를 낸다.

**왜.** 지금 qg 결과는 믿을 보고가 못 된다. 런타임을 걸어보지 않고, PR 에 남지 않으며, 게시 장치가
무겁다. 게다가 과잉 처방이 판정을 쥐어 수정이 의도에서 벗어난다. 뿌리는 둘이다. 하나는 부품마다
박힌 옛 모델·옛 Claude Code 가정이고, 다른 하나는 리뷰마다 장치를 덧붙여 온 공정이다(S14). 1주 전에
재설계한 파이프라인 SKILL 이 여전히 955줄이고, 그 뒤 이틀 사이 패치가 여섯 번 나왔다.

**확정(잠정).**
- e2e 는 오케스트레이터가 걷고 판정하고 사람이 reviewer 로 뒤집는다. pass 는 관측 증거가 있을 때만
  성립한다. 루프 끝에 한 번 오고, fail 이면 defect 다.
- 게시는 백지에서 새로 짓는다. 매 실행 새 코멘트(이해글 + 판정 한 줄)를 동의 없이 올리되, secret-scan
  과 kill switch 는 남긴다. PR 이 없거나 실행이 중단됐으면 게시를 건너뛴다.
- 리뷰 다이어트는 처방과 적용 양쪽에 두고, SUGGESTION 은 판정을 막지 않는다. 원래 의도는 선언 우선
  사슬(Spec: 트레일러 → 없으면 커밋 메시지·PR 본문)로 읽는다.
- 재건은 옛 교훈을 새 설계의 요구 목록으로 먼저 옮기고, 구성요소별 한 줄 표로 처분을 정한 뒤, v10 을
  옆에 세워 갈아끼운다. critique·공유 엔진은 범위 밖이고, 사라지는 표면은 즉시 제거한다.

**열림.** 한 줄 표의 실제 처분, e2e 의 구체 형태, 다이어트의 과소 처방 경계, 컷오버 순서와 dogfooding,
헌장 기록 두 줄, plugin-audit 의존, 공정 바꾸기, 그리고 리뷰가 남긴 참고 다섯(e2e pass 승인 자리 · 헌장 기록
범위 · /code-review 대체 · mutation guard 교훈 · Spec: 트레일러와 토픽 스코프)(§3).

**다음.** brainstorming(§7).

**결정 목록**

- OQ1 [해결 ⟨S3⟩] — 네 갈래 뒤의 진짜 문제와 goal(→ OQ14 로 재개방·재구성)
- OQ2 [해결 ⟨S20⟩] — e2e 결과별 판정값 → 근거 RC59
- OQ3 [해결 ⟨S16⟩] — e2e 의 파이프라인 자리와 실패 시 재진입 → 근거 RC56
- OQ4 [해결 ⟨S19⟩] — e2e 를 걷고 판정하는 주체(S15 를 S17·S18 이 뒤집음) → 근거 RC31 · RC32 · RC54
- OQ5 [해결 ⟨S6⟩] — 무인 게시의 노출 경계 → 근거 RC34
- OQ6 [해결 ⟨S11⟩] — 걷을 게시 장치와 /qg-publish 처리 → 근거 RC43 · RC73
- OQ7 [해결 ⟨S7⟩] — 리뷰 다이어트의 층위 → 근거 RC11 · RC12
- OQ8 [해결 ⟨S4⟩] — 외부 근거 처분
- OQ9 [해결 ⟨S9⟩] — SUGGESTION 하나도 defect(계획 R-B) 유지 여부 → 근거 RC48
- OQ10 [해결 ⟨S8⟩] — 원래 의도의 출처 → 근거 RC13
- OQ11 [해결 ⟨S10⟩] — premortem 처분
- OQ12 [해결 ⟨S11⟩] — 게시 「바닥부터 새로」의 범위 → 근거 RC83
- OQ13 [해결 ⟨S12⟩] — 「가능하면 새로」의 범위
- OQ14 [해결 ⟨S14⟩] — 재구성된 문제정의
- OQ15 [해결 ⟨S13⟩] — qg 전체 재건 방향(ST3) → 근거 RC74 · RC77
- OQ16 [해결 ⟨S21⟩] — 코멘트 payload 의 모양 → 근거 RC47
- OQ17 [해결 ⟨S22⟩] — 재건 경계
- OQ18 [해결 ⟨S23⟩] — 공개 표면·소비자 이관 방식 → 근거 RC71
- OQ19 [열림] — 구성요소별 한 줄 표의 실제 처분 → 근거 RC60 · RC61 · RC62 · RC63 · RC64 · RC65 · RC66 · RC67 · RC68 · RC76
- OQ20 [열림] — e2e 의 구체 형태 → 근거 RC33 · RC80
- OQ21 [열림] — 리뷰 다이어트의 과소 처방 경계 → 근거 RC50 · RC51
- OQ22 [열림] — 컷오버 순서와 dogfooding → 근거 RC52
- OQ23 [열림] — 헌장 기록 두 줄의 자리 → 근거 RC41
- OQ24 [열림] — plugin-audit 의 qg-worktree.sh 의존 처리 → 근거 RC69 · RC70
- OQ25 [열림] — 「공정」을 바꾸는 방법 → 근거 RC78 · RC79 · RC82
- OQ26 [열림] — [참고 · direction] e2e pass 판정안을 사람이 승인하는 자리가 걷기 뒤·게시 전에 없다 — 게시 전 승인·뒤집기 한 번을 둘지, 침묵 = 승인을 Law 2 해석으로 받아들여 코멘트에 「판정안(사람 미확인)」으로 공시할지 (리뷰 abf668a4#r1.1 · abf668a4#r2.2)
- OQ27 [열림] — [참고 · direction] 헌장 기록을 두 줄에서 넓힐지 — D26 즉시 제거와 CLAUDE.md one-minor deprecation 창의 충돌(조건 · 복귀 트리거를 붙일지), e2e 재도입과 P4 「qg 는 runtime tier 를 주장하지 않는다」의 충돌 (리뷰 402da1b4#r1.1 · abf668a4#r2.1)
- OQ28 [열림] — [참고 · direction] 1st-party /code-review 대체 판단 — 로컬 /code-review 는 REVIEW.md 를 읽지 않고 cleanup 을 내며 --comment 는 인라인 게시라, 대체하면 D12 처방 지렛대와 D24 판정 한 줄이 풀린다. 리뷰어를 대체할지 dispatch 프롬프트를 쥔 리뷰어를 새로 지을지 (리뷰 b73addba#r3.1)
- OQ29 [열림] — [참고 · direction] 쓰기 권한 오케스트레이터가 걷는 e2e 에 옛 mutation guard 교훈을 요구로 넣을지 — 「걷기 중 대상 코드가 바뀌면 그 걷기의 판정은 무효, 다시 걷는다」 한 줄 규약 (리뷰 abf668a4#r1.2)
- OQ30 [열림] — [참고 · direction] D13 의 첫 출처 Spec: 트레일러는 토픽 스코프의 선언 키인데 D25 가 토픽 스코프를 처분 대상으로 열었다 — 트레일러를 독립 의도 선언 관례로 둘지, 토픽 스코프가 지워지면 D13 사슬을 커밋 메시지·PR 본문으로 줄일지 (리뷰 abf668a4#r2.3 · abf668a4#r3.1)

## 1. Goal · Non-goal

- Goal: 구성요소마다 가정을 다시 재어, 지금 모델·Claude Code 위의 얇은 qg v10 을 구성요소별로
  갈아끼운다. 그 결과 `/qg` 한 번이 리뷰 → 테스트 → (선택) e2e → PR 코멘트로 사람이 믿고 판단할
  검증 보고를 내되, 옛 qg 가 사고를 겪으며 얻은 교훈(거짓 clean·fail-open 수정)은 잃지 않는다(S14).
- Goal: 네 면 — e2e 신설 · 게시 백지 재건 · 게시 장치 걷기 · 리뷰 다이어트 — 을 모두 중심으로 다룬다(S2).
- Non-goal: 전체를 한꺼번에 백지에서 짓고 한 번에 갈아끼우는 것(S13). spec 은 하나다(S3).
- Non-goal: /qg critique 와 spec-distill 공동 소유 docreview 엔진(S22).
- Non-goal: qg 가 push 하거나 PR 을 만드는 것(S1).
- Non-goal: Law 2 를 지키려고 과한 장치를 덧붙이는 것(S18).

## 2. 제약

- 🗣 confirmed **C1** — /qg 한 번이 리뷰 → 테스트 → e2e 질문 → 결과 게시까지 이어서 간다. ⟨S1⟩
- 🗣 confirmed **C2** — e2e 는 qg 가 이 변경에 맞는 걸을 경로를 제안하고 사용자가 고르거나 고친 뒤, 에이전트가 걸어 판정을 내고 사람은 감독하다 틀리면 뒤집는다. ⟨S1⟩
- 🗣 confirmed **C3** — e2e 를 돌렸는데 실패하면 qg 판정이 clean 이 될 수 없다. ⟨S1⟩
- 🗣 confirmed **C4** — 게시는 /qg 실행마다 새 코멘트로, 동의를 묻지 않고 올린다. ⟨S1⟩
- 🗣 confirmed **C5** — 매 코멘트는 그 시점의 이해글과 그 실행의 qg 결과를 함께 담는다. ⟨S1⟩
- 🗣 confirmed **C6** — PR 이 없으면 게시를 건너뛰고 그 사실을 한 줄로 알리며, qg 는 push 나 PR 생성을 하지 않는다. ⟨S1⟩
- 🗣 confirmed **C7** — qg 리뷰는 한 번의 리뷰로 장치를 덧붙이거나 보안을 과하게 경계하거나 선제적 오버 엔지니어링을 처방하지 않아야 한다. ⟨S1⟩
- 🗣 confirmed **C8** — 리뷰를 반영한 수정이 원래 의도에서 드리프트하는 것을 특히 피해야 한다. ⟨S1⟩
- 🗣 confirmed **C9** — 네 갈래 모두 중심이고 소홀히 하지 않으며, 예산이 문제면 subagent 와 병렬 plan 여럿을 쓴다. ⟨S2⟩
- ☑ confirmed **D10** — e2e pass 는 기대 상태마다 관측 증거가 인용될 때만 성립하고, 빠지면 「미확인」으로 not-certified 다. ⟨S5⟩
- ☑ confirmed **D11** — 게시에서 preview·동의·upsert·identity·pr-create·--history 는 걷고, 게시 직전 결정론 secret-scan 한 번과 publish kill switch 는 남기며, 중단된 실행은 게시하지 않는다 — secret-scan 에 걸리면 묻지 않고 게시를 건너뛰고 한 줄로 알리며, kill switch 는 새 게시 sink 로 옮겨 집행하고, 무동의 게시는 사용자의 상시 동의로 규칙에 기록한다. ⟨S6⟩
- ☑ confirmed **D12** — 리뷰 다이어트는 처방 단계(리뷰어 dispatch 프롬프트의 correctness·명시 요구 기준 + 재비판의 처방-의도 초과 관문)와 적용 단계(Retry 직전 의도 대조) 양쪽에 두고 새 락·원장은 두지 않는다 — correctness·명시 요구 밖의 지적은 optional 이고, 의도에서 벗어나는 패치는 적용에서 제외하고 그 사실을 공시한다. ⟨S7⟩
- ☑ confirmed **D13** — 원래 의도는 커밋 Spec: 트레일러의 spec → 없으면 브랜치 커밋 메시지와 PR 본문 순으로 읽고, mtime 최신 spec 은 쓰지 않는다 — 쓴 출처를 한 줄로 공시하고, 출처를 정하려고 추가 질문을 하지 않는다. ⟨S8⟩
- ☑ confirmed **D14** — SUGGESTION 은 판정을 막지 않는다 — 살아남은 CRITICAL·IMPORTANT 가 있을 때만 defect 이고, SUGGESTION 은 Retry 적용 대상에서 기본 제외한다. ⟨S9⟩
- 🗣 confirmed **C15** — 게시는 이전 장치가 과했으므로 바닥부터 지금에 맞게 새로 짓는다. ⟨S10⟩
- 🗣 confirmed **C16** — e2e 는 구현 중 실패가 많았으므로 새로 짓고, 기존에 있던 것은 가능하면 새로 짓는다 — qg 는 오래된 플러그인이라 지금 모델과 Claude Code 에 맞지 않는 것이 많을 것이다(사용자 추정). ⟨S11⟩
- ☑ confirmed **D17** — 재건 범위는 qg 전체(파이프라인·차등 테스트·판정 어휘·스크립트)다. ⟨S12⟩
- ☑ confirmed **D18** — 재건은 구성요소마다 한 줄 표(가정·1st-party 대체·교훈·처분)로 삭제/새로/유지를 정하고, v10 을 옆에 세워 구성요소별 독립 PR·릴리스로 갈아끼우며, 옛 교훈은 새 설계의 요구 목록으로 먼저 옮긴다 — 기본 처분은 「가능하면 새로」이고, e2e·게시는 새로 짓고 1st-party 가 대신하는 부분은 삭제하며, 표와 재건에 새 락·원장은 두지 않는다. ⟨S13⟩
- ☑ confirmed **D19** — e2e 질문은 리뷰·테스트 루프가 끝난 뒤 판정 직전에 한 번 오고, 실패하면 Fix-loop 결정을 다시 띄우며, Retry 를 고르면 남은 iteration 안에서 리뷰·테스트·e2e 를 다시 돈다. ⟨S16⟩
- 🗣 confirmed **C20** — 오케스트레이터가 e2e 를 다 걷고 판정한다. ⟨S17⟩
- 🗣 confirmed **C21** — Law 2 를 지키려고 과한 장치를 만들지 않는다. ⟨S18⟩
- ☑ confirmed **D22** — 오케스트레이터의 e2e 판정은 판정안이고, 승인·뒤집기를 하는 reviewer 는 감독하는 사람이다 — 장치는 두지 않고, 이 해석을 spec·헌장에 한 줄로 기록한다. ⟨S19⟩
- ☑ confirmed **D23** — e2e fail 은 defect 이고, 「안 한다」와 걸을 표면 없음은 판정을 바꾸지 않고 코멘트에 공시하며, 「걸을 것 없음」은 e2e 질문에서 사용자에게 보여 뒤집을 수 있게 한다. ⟨S20⟩
- ☑ confirmed **D24** — 코멘트의 qg 결과는 판정 한 줄(판정·사유·개수)이고 나머지는 로컬에 둔다 — S21 이 S9 의 「코멘트에 선택 사항으로」를 대체하므로 SUGGESTION 은 로컬 결과에만 둔다. ⟨S21⟩
- ☑ confirmed **D25** — /qg critique 와 spec-distill 공동 소유 docreview 엔진은 재건에서 빠져 별 사이클로 다루고, 토픽 스코프와 codex 각도는 재건 안에서 한 줄 표로 처분한다. ⟨S22⟩
- ☑ confirmed **D26** — 재건으로 사라지는 공개 표면과 소비자 의존은 deprecation 창·공지 없이 즉시 제거한다. ⟨S23⟩
- 🗣 confirmed **C27** — e2e 는 대상의 실제 앱·플로우를 구동하는 것이되, 기계 장치보다 에이전트가 직접 걸어보는 방식에 사람이 감독한다. ⟨S1⟩
- ☑ confirmed **D28** — spec 은 하나이고 이음매(e2e → 판정 → 코멘트)를 AC 로 가지며, plan 은 네 갈래와 이음매로 나눠 병렬화한다. ⟨S3⟩

✎ D10·D22 는 한 쌍이다. 증거는 오케스트레이터 턴에 남은 raw 도구 출력이라 요약이 끼지 않는다. 그 증거를
읽고 뒤집는 사람이 reviewer 다 — 그래서 별도 판정 agent 없이 Law 2 의 「writer 와 reviewer 분리」가 사람
쪽에서 성립한다고 본 것이 S19 다.

✎ D11 과 D24 는 서로 받친다. 코멘트 payload 가 이해글(빌더 입력 blob 이 곧 secret-scan corpus)과 qg 가
스스로 만든 판정 한 줄로 좁혀져서, corpus 밖 텍스트가 섞일 자리가 거의 없다.

✎ seed 는 사용자가 지금 게시를 「새 본문을 만드는 것」으로 기억한다고 관찰했고, 실제와 다른 쪽은 그 기억이다 —
지금은 PR 이 없을 때만 PR 본문을 만들고, PR 이 있으면 마커 코멘트 하나를 매번 동의를 받아 덮어쓴다. 이 brief 의
결정은 그 차이와 무관하게 새로 짓는다(C15).

## 3. Open Questions

- OQ19: 구성요소별 한 줄 표의 실제 처분. 표의 칸은 이 부품이 깔고 있는 가정 · 그것을 대신하는 1st-party(`/code-review` · `/security-review` · `/verify`) · 이 부품이 실어 나르는 교훈 · 삭제/새로/유지다. 특히 차등 테스트 기계는 직전 설계가 「여러 라운드 하드닝, 교체는 신뢰도 하한을 올리지 않는다」며 유지 쪽으로 판단했으니, 표가 처음 가를 자리다 → 근거 RC60 · RC61 · RC62 · RC63 · RC64 · RC65 · RC66 · RC67 · RC68 · RC76
- OQ20: e2e 의 구체 형태. 걸을 경로를 무엇으로 제안하나. 앱 부팅 레시피는 어디서 얻나(`/verify` 는 사용자 호출 전용이라 qg 가 대신 부를 수 없다). 브라우저 MCP 가 없으면 어떻게 하나. 남의 브랜치 코드를 호스트 권한으로 부팅하는 일을 무엇으로 통제하나(차등 테스트에는 보안 kill switch 선례가 있다) → 근거 RC33 · RC80
- OQ21: 리뷰 다이어트의 과소 처방 경계. 재비판 관문 D 는 「빠진 보안 점검을 added 로 내라」고 하고, 새 「처방 초과」 관문은 장치를 덧붙이지 말라고 한다. 둘이 부딪치는 자리를 어떻게 가르나. 관문을 고치면 헌장상 보안 리뷰 대상이다 → 근거 RC50 · RC51
- OQ22: 컷오버 순서와 dogfooding. devbrew 에는 부팅되는 앱이 없어 e2e 가 늘 「걸을 것 없음」이다. e2e 를 어디서 검증하나 → 근거 RC52
- OQ23: 헌장 기록 두 줄의 자리. 하나는 「매 실행 무동의 게시는 사용자의 상시 동의」(P17 과 맞추기 — Agent 상시 허용 전례처럼)이고, 다른 하나는 「e2e 판정의 reviewer 는 감독하는 사람」(Law 2 해석)이다. 둘을 어디에 적나 → 근거 RC41
- OQ24: plugin-audit 가 `qg-worktree.sh` 에 `≥2.12.0` 으로 의존하고 경로를 하드코딩했다. 즉시 제거(D26) 아래에서 같은 컷오버에 소비자도 고칠지, 그 스크립트를 유지로 처분할지 정한다 → 근거 RC69 · RC70
- OQ25: 「공정」을 바꾸는 방법. 교훈을 락이 아니라 요구 목록으로 옮기고, 리뷰 라운드에 멈춤 기준을 둔다. 재건 자체가 다시 무거워지지 않게 하는 수단을 정한다 → 근거 RC78 · RC79 · RC82
- OQ26: [참고 · direction] e2e pass 판정안을 사람이 승인하는 자리가 걷기 뒤·게시 전에 없다 — 게시 전 승인·뒤집기 한 번을 둘지, 침묵 = 승인을 Law 2 해석으로 받아들여 코멘트에 「판정안(사람 미확인)」으로 공시할지 (리뷰 abf668a4#r1.1 · abf668a4#r2.2)
- OQ27: [참고 · direction] 헌장 기록을 두 줄에서 넓힐지 — D26 즉시 제거와 CLAUDE.md one-minor deprecation 창의 충돌(조건 · 복귀 트리거를 붙일지), e2e 재도입과 P4 「qg 는 runtime tier 를 주장하지 않는다」의 충돌 (리뷰 402da1b4#r1.1 · abf668a4#r2.1)
- OQ28: [참고 · direction] 1st-party /code-review 대체 판단 — 로컬 /code-review 는 REVIEW.md 를 읽지 않고 cleanup 을 내며 --comment 는 인라인 게시라, 대체하면 D12 처방 지렛대와 D24 판정 한 줄이 풀린다. 리뷰어를 대체할지 dispatch 프롬프트를 쥔 리뷰어를 새로 지을지 (리뷰 b73addba#r3.1)
- OQ29: [참고 · direction] 쓰기 권한 오케스트레이터가 걷는 e2e 에 옛 mutation guard 교훈을 요구로 넣을지 — 「걷기 중 대상 코드가 바뀌면 그 걷기의 판정은 무효, 다시 걷는다」 한 줄 규약 (리뷰 abf668a4#r1.2)
- OQ30: [참고 · direction] D13 의 첫 출처 Spec: 트레일러는 토픽 스코프의 선언 키인데 D25 가 토픽 스코프를 처분 대상으로 열었다 — 트레일러를 독립 의도 선언 관례로 둘지, 토픽 스코프가 지워지면 D13 사슬을 커밋 메시지·PR 본문으로 줄일지 (리뷰 abf668a4#r2.3 · abf668a4#r3.1)

## 4. External Landscape

- 구독자 이메일은 새 코멘트일 때만 가고 편집은 알리지 않는다 — 매 실행 새 코멘트는 매 실행 알림이다 «codecov» — [중립] — 사용자가 알고 고른 비용(C4) [→ OQ5]
- 에이전트가 실행 중인 앱을 브라우저로 직접 열어 검증하고, 성공을 단언하지 말고 증거를 보이라 «cc-best-practices» — [취함] — e2e 걷기와 증거 하한(D10) [→ OQ4]
- 리뷰어가 찾은 gap 을 다 쫓으면 추상 층·방어 코드·불가능한 경우의 테스트가 붙는 over-engineering 이 된다 — correctness·명시 요구에 닿는 gap 만 내고 나머지는 optional 로 «cc-best-practices» — [취함] — 다이어트 처방 단계 기준(D12) [→ OQ7]
- 접근성 트리 스냅숏으로 비전 모델 없이 구동하고, `--caps=testing` 으로 verify 단언 도구를 연다 «playwright-mcp» — [취함] — 걷기 도구와 증거 형식 [→ OQ20]
- 컴퓨터 사용 에이전트는 실패 증거를 못 보면 pass 로 판정한다(default-correctness bias, 전 모델 F1 30% 미만) «webtestbench» — [피함] — 무증거 pass 를 피한다(D10) [→ OQ2]
- over-engineering 은 필요 이상 일반화이거나 지금 필요 없는 기능이다 — 추측한 미래 문제가 아니라 지금 문제를 푼다 «google-eng» — [취함] — 처방 초과 관문의 판별 기준 [→ OQ7]
- 리뷰 강도를 출력 단계 프로필로 조절한다 «coderabbit» — [중립] — 층위 선례 [→ 없음]
- 의도를 대화·메타데이터에서 얻고 diff 를 역번역해 의도와 대조해 드리프트를 잡는다 «arctic» — [취함] — Retry 직전 의도 대조의 모양 [→ OQ10]
- 사람 감독 정책은 사람이 기대된 감독을 못 해 결함 있는 알고리즘을 정당화만 한다 «green-oversight» — [중립] — D22 의 남는 위험 [→ OQ4]
- 자동화 보조 집단은 시스템이 경고하지 않은 것을 놓쳐 정확도 59%, 비보조 97% «automation-bias» — [중립] — 증거 하한이 감독을 받쳐야 하는 이유 [→ OQ4]
- 증거에 묶인 LLM 판정은 사람 판정과 약 85% 일치 «webjudge» — [취함] — pass 를 증거에 묶는다 [→ OQ2]
- `/verify` 는 v2.1.215 부터 사용자가 부를 때만 돈다 «cc-commands» — [중립] — qg 가 e2e 를 그것에 맡길 수 없다 [→ OQ20]
- 1st-party `/code-review` 는 여러 agent 탐지 + 검증 단계로 오탐을 거르고 `--comment` 로 게시하며, 판정은 차단하지 않는다(neutral). REVIEW.md 로 nit 상한·재리뷰 수렴을 둔다 «cc-code-review» — [취함] — 한 줄 표의 1st-party 대체 후보 [→ OQ19]
- subagent 에는 AskUserQuestion 이 아예 없다(not planned) «cc-34592» — [취함] — 사람이 감독하는 걷기는 오케스트레이터가 한다(C20) [→ OQ4]
- 간접 프롬프트 주입만으로 에이전트가 범위 밖 private 데이터를 읽어 GitHub 쓰기로 유출했다 «invariant-mcp» — [피함] — 무인 게시에서 차단 0 을 피한다(D11) [→ OQ5]
- GitHub 의 PR 코멘트 secret 스캔은 공개 리포 public monitoring 한정의 사후 경보다 «gh-secret-scope» — [피함] — 플랫폼이 게시 전에 막아 준다는 가정을 피한다 [→ OQ5]
- 코멘트 편집 이력은 읽기 권한자 누구나 본다 — 갱신 방식도 유출을 지우지 못한다 «gh-edit-history» — [중립] — 새 코멘트 대 갱신 비교 [→ 없음]
- PR 코멘트 action 이 `recreate` · `hide_and_recreate` 를 정식 옵션으로 둔다 «sticky-comment» — [중립] — 매 실행 새 코멘트는 확립된 모드 [→ 없음]
- 실행마다 새 코멘트가 쌓인다는 사용자 불만과 sticky 해법 «cca-720» — [중립] — 알고 고른 소음 비용 [→ 없음]
- 하니스 부품마다 「모델이 혼자 못 하는 것」의 가정이 박히고 모델이 나아지면 낡는다 — 한꺼번에 잘라낸 단순화는 성능을 재현 못 했고 부품을 하나씩 뺄 때 통했다 «harness-design» — [취함] — 구성요소별 가정 재측정과 컷오버(D18) [→ OQ19]
- 가장 단순한 해법에서 시작해 필요할 때만 복잡도를 올린다 «building-agents» — [취함] — 공정 바꾸기의 기준 [→ OQ25]
- 작동하는 코드를 버리고 처음부터 다시 쓰는 것은 누적된 버그 수정과 경계 사례 지식을 버린다 «bssw-spolsky» — [피함] — 한꺼번에 백지 재건을 피한다 [→ OQ15]
- 성공한 첫 시스템 뒤의 두 번째 시스템은 미뤄 둔 추가물이 몰려 비대해진다 «second-system» — [피함] — 새로 지으면 가벼워진다는 가정을 피한다 [→ OQ15]
- strangler fig — 기능을 점진적으로 새 시스템으로 옮기고 다 옮긴 뒤 옛 것을 내린다. 작은 애플리케이션이면 전체 재작성이 더 효율적일 수도 있다 «aws-strangler» — [취함] — 옆에 세워 갈아끼우기(D18) [→ OQ15]
- 재작성 성공 사례(Basecamp · VS Code 등)도 있다 «willison-rewrites» — [중립] — 「가능하면 새로」의 정당한 쪽 [→ OQ15]
- recall 을 53%→62% 로 올리자 오탐이 170→328 로 늘었다 — 두 축은 맞바뀐다 «kodus-recall» — [중립] — 다이어트의 과소 처방 위험 [→ OQ21]
- 리뷰 결함 검출은 한 번에 200~400 LOC 에서 가장 강하고 그 이상에서 급락한다 «cisco-review» — [중립] — 컷오버 단위 [→ OQ22]
- 신뢰 권한 문맥에서 PR head 의 빌드 스크립트를 돌리면 비밀과 쓰기 토큰이 털린다 «pwn-request» — [피함] — 남의 브랜치 앱 부팅 통제 [→ OQ20]
- 하니스는 모델이 혼자 못 하는 것의 가정을 담고 그 가정은 모델이 나아지면 dead weight 가 된다 «managed-agents» — [취함] — era-fit 판별 [→ OQ19]
- issue/PR 코멘트 본문 한도는 65,536자다 «gh-65536» — [중립] — D24 의 판정 한 줄로 위험이 작아졌다 [→ 없음]

## 5. 기각 · Blind Spots

- 기각 — 무증거 pass 가 clean 으로 가는 길을 여는 것 · 「사람 감독이 오류를 잡기에 충분하다」를 backstop 으로 삼는 것 · 「걸을 것 없음」과 「걸었는데 증거 없음」을 한 값으로 접는 것 → 에이전트는 실패 증거를 못 보면 pass 를 내고 사람 감독은 그 누락형 오류에 약하다 — verdict: refined — ST1 — 부착 7/7
- 기각 — P4 「최대한」을 secret-scan 과 kill switch 에까지 적용하는 것 · 「실행마다」를 중단 실행에까지 적용하는 것 → 리포 스스로 사람 preview 를 최종 backstop 이라 적었고 무인 게시에서 그것을 대체 없이 걷으면 결정론 차단이 0 이 된다, 중단 실행은 검증 보고가 아니다 — verdict: refined — ST2 — 부착 6/6
- 기각 — 한 spec 으로 전체를 한꺼번에 백지 재건 · 측정 없이 「전체」를 재건 대상으로 잡기 · 옛 부품의 교훈을 버리기 → 1주 전 재설계도 무겁다는 사실이 원인을 나이보다 공정에 두고, 한꺼번에 잘라낸 하니스 단순화는 성능을 재현하지 못했다 — verdict: refined — ST3 — 부착 12/12
- 기각 — 원래: 「테스트 리뷰와 테스트 실행은 지금 장치로 충분하고 바꾸지 않는다」(S1) / 재결정: qg 전체 재건, 차등 테스트도 한 줄 표의 처분 대상(S12·S13) / 근거: S11 — qg 가 오래돼 지금 모델·Claude Code 에 맞지 않는다는 사용자 판단. 직전 설계는 차등 기계 유지를 권했다 [RC76 → OQ19]
- 기각 — 원래: e2e 걷기와 판정 분리, 판정은 Read-only agent(S15) / 재결정: 오케스트레이터가 걷고 판정, reviewer 는 감독하는 사람(S17·S19) / 근거: S18 — Law 2 를 지키려고 과한 장치를 만들지 않는다 [RC31 → OQ4]
- 기각 — 원래: 「SUGGESTION 하나도 defect」(9.0.0 계획 R-B, 「사용자가 뒤집을 수 있는 자리」로 명시) / 재결정: SUGGESTION 은 판정을 막지 않는다(S9) / 근거: 그 규칙이 clean 을 Retry 하나로만 열어 처방 적용과 드리프트를 부른다 [RC48 → OQ9]
- 기각 — 원래: 헌장의 one-minor deprecation 창 기본값 / 재결정: 즉시 제거(S23) / 근거: 사용자 결정 [RC71 → OQ18]
- 기각 — 게시를 기존 publishing-pr-understanding 에서 덜어내며 고치기 → 사용자가 이전 장치가 과했다며 바닥부터 새로 짓기로 했다(C15) [RC83 → OQ12]
- 기각 — seed 가 걷을 후보로 든 `publish-active.md` → v7.0.0 에서 소비자 훅과 함께 이미 제거됐고 부재 락이 지킨다 [RC18 → 없음]
- 위험 — 숨은 가정 | 사람 preview 가 최종 backstop 이던 게시에서 preview·동의를 걷으면 남는 차단은 게시 직전 secret-scan 하나다 — RC34 (plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md#Generate) [RC34 → OQ5]
- 위험 — 숨은 가정 | secret-scan 의 고엔트로피 검출은 corpus 안 값만 잡는다 — payload 를 이해글 + 판정 한 줄로 좁혀(D24) 완화했다 — RC47 (plugins/quality-gates/scripts/secret-scan.py#_high_entropy_in_corpus) [RC47 → OQ16]
- 위험 — 실패 양식 | 다이어트가 진짜 결함까지 억누른다 — 재비판 관문 D 는 빠진 보안 점검을 added 로 내라고 한다 — RC50 (plugins/quality-gates/references/recritic-code-profile.md#D) [RC50 → OQ21]
- 위험 — 숨은 가정 | 재비판 프로필·리뷰어 persona 약화는 헌장상 보안 리뷰 대상이다 — RC51 (CLAUDE.md#Persona 파일은 보안-민감 코드) [RC51 → OQ21]
- 위험 — 실패 양식 | devbrew 에는 부팅되는 앱이 없어 dogfooding 에서 e2e 가 한 번도 실행되지 않은 채 나갈 수 있다 — RC52 (docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#증거가 N=1 이다) [RC52 → OQ22]
- 위험 — 실패 양식 | e2e 앱 부팅은 리뷰 대상 코드를 호스트 권한으로 돌린다 — 보안 kill switch 는 차등 테스트에만 있다 — RC33 (plugins/quality-gates/skills/quality-pipeline/SKILL.md#Kill switch) [RC33 → OQ20]
- 위험 — 숨은 가정 | 브라우저 MCP 도구 표면 — 2.12.0 은 upload_file 유출과 auth 헤더 노출을 도구 단위 허용으로 막았다 — RC80 (plugins/quality-gates/CHANGELOG.md#2.12.0) [RC80 → OQ20]
- 위험 — 숨은 가정 | subagent 의 self-report 는 raw 출력이 아니라 요약이다(3.0.0) — 오케스트레이터가 걷기로 해서(C20) 증거가 raw 로 남는다 — RC54 (plugins/quality-gates/CHANGELOG.md#3.0.0) [RC54 → OQ4]
- 위험 — 숨은 가정 | 판정 사유 튜플의 순서가 곧 우선순위다 — 「미확인」 사유의 자리가 판정 의미를 정한다 — RC59 (plugins/quality-gates/scripts/verdict.py#REASONS) [RC59 → OQ2]
- 위험 — 숨은 가정 | 같은 iteration 안에서 같은 리뷰어 재디스패치 금지 — e2e 실패 후 재보행은 iteration 경계에서만 — RC56 (plugins/quality-gates/skills/quality-pipeline/SKILL.md#R5) [RC56 → OQ3]
- 위험 — 실패 양식 | iteration 당 선언 fan-out 10 을 이미 다 쓴다 — 매 실행 이해글 빌더를 더하면 선언을 고쳐야 한다 — RC55 (plugins/quality-gates/README.md#총/iteration ≤ 10) [RC55 → 없음]
- 위험 — 숨은 가정 | 첫 /qg 는 대개 PR 전에 돌아 아무것도 남기지 않는다 — pr-process.md 의 「gh pr create 자동 트리거」 서술은 낡았다 — RC57 (docs/git-workflow/pr-process.md#quality-gates) [RC57 → 없음]
- 위험 — 실패 양식 | 재건 공정이 그대로면 무게가 다시 자란다 — 9.0.0 재설계 SKILL 955줄, 그 뒤 이틀 패치 여섯 번 — RC82 (plugins/quality-gates/skills/quality-pipeline/SKILL.md#Pipeline) [RC82 → OQ25]
- 위험 — 실패 양식 | 옛 교훈을 놓치면 알려진 거짓 clean 이 돌아온다 — 9.3.1 confidence 누락 0 채움 — RC78 (plugins/quality-gates/CHANGELOG.md#9.3.1) [RC78 → OQ25]
- 위험 — 실패 양식 | 옛 교훈을 놓치면 fail-open 이 돌아온다 — secret-scan 은 exit code 가 아니라 `scan_ok: yes` 줄로 판정(v2.7.0) — RC79 (plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md#Scan) [RC79 → OQ25]
- 위험 — 숨은 가정 | 차등 테스트 기계 교체는 직전 설계가 근거와 함께 범위 밖으로 두었다 — RC76 (docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#차등 테스트 기계 자체를 다른 것으로 바꾸는 것) [RC76 → OQ19]
- 위험 — 숨은 가정 | 한 줄 표의 판별식이 리포에 이미 있다 — 「이 줄을 지우면 무엇이 조용히 통과하게 되는가?」 — RC60 (docs/superpowers/specs/2026-08-02-harness-capability-suppression-sweep-design.md) [RC60 → OQ19]
- 위험 — 숨은 가정 | era-fit 후보 — v1 결정론 depth 표 — RC61 (plugins/quality-gates/scripts/scout.py#Depth decision) [RC61 → OQ19]
- 위험 — 숨은 가정 | era-fit 후보 — confidence ≤4 억제, 9.3.x 패치 셋의 원천 — RC62 (plugins/quality-gates/scripts/synthesize_findings.py#suppress) [RC62 → OQ19]
- 위험 — 숨은 가정 | era-fit 후보 — allowed-tools 순서 linter(제한이 아닌 계층을 잠금) — RC63 (plugins/quality-gates/scripts/check-allowed-tools-order.sh) [RC63 → OQ19]
- 위험 — 숨은 가정 | era-fit 후보 — 「default-Opus 베이스라인 대비」 비용표 — RC64 (plugins/quality-gates/README.md#Depth) [RC64 → OQ19]
- 위험 — 숨은 가정 | 보존할 불변식 — 판정 닫힌 열거와 「검증 못 했다」는 일급 판정값 — RC65 (plugins/quality-gates/scripts/verdict.py#REASONS) [RC65 → OQ19]
- 위험 — 숨은 가정 | 보존할 불변식 — LD5, 결정론 백스톱은 오케스트레이터가 직접 부른다 — RC66 (plugins/quality-gates/README.md#LD5) [RC66 → OQ19]
- 위험 — 숨은 가정 | dispatch 처분 앵커의 consumer 경로가 재건으로 옮겨지면 shared 락도 함께 옮겨야 한다 — RC67 (plugins/quality-gates/skills/quality-pipeline/SKILL.md#처분) [RC67 → OQ19]
- 위험 — 숨은 가정 | shared 헌장 인용 락이 qg plugin.json 과 사라진 이름을 지목한다 — RC68 (shared/tests/test_charter_citations.sh) [RC68 → OQ19]
- 위험 — 실패 양식 | 즉시 제거(D26)로 plugin-audit 의 qg-worktree 의존이 끊긴다 — RC69 (plugins/plugin-audit/README.md#quality-gates ≥ 2.12.0) [RC69 → OQ24]
- 위험 — 실패 양식 | 다른 플러그인 문서가 이미 사라진 qg 런타임 파이프라인을 서술한다 — 소비자 sweep 범위 — RC70 (plugins/project-init/README.md#quality-gates) [RC70 → OQ24]
- 위험 — 숨은 가정 | /qg-publish 가 파이프라인 밖이라는 분리 불변식과 그 락을 뒤집는다 — RC73 (plugins/quality-gates/README.md#/qg-publish) [RC73 → OQ6]
- 위험 — 숨은 가정 | 직전 재설계가 strangler 방식(호출자 0 → 기본 off → 컷오버)을 이미 성공시켰다 — RC77 (plugins/quality-gates/CHANGELOG.md#8.1.0) [RC77 → OQ15]
- 위험 — 숨은 가정 | 파이프라인과 판정 어휘는 1주 전에 현 Claude Code 기준으로 재설계됐다 — 「오래됐다」가 그 부품엔 덜 맞는다 — RC74 (plugins/quality-gates/CHANGELOG.md#9.0.0) [RC74 → OQ15]
- 위험 — 숨은 가정 | 처방이 clean 을 막는 구조 — SUGGESTION 하나도 defect — RC48 (plugins/quality-gates/scripts/synthesize_findings.py#decide) [RC48 → OQ9]
- 위험 — 숨은 가정 | Retry 는 합성기 패치를 의도 대조 없이 Edit 한다 — 드리프트의 자리 — RC12 (plugins/quality-gates/skills/quality-pipeline/SKILL.md#Fix-loop decision) [RC12 → OQ7]
- 위험 — 숨은 가정 | 기본 리뷰어와 추가 리뷰어는 외부 플러그인이라 qg 가 페르소나를 못 고친다 — 처방 단계는 dispatch 프롬프트로 — RC11 (plugins/quality-gates/skills/quality-pipeline/SKILL.md#rubric) [RC11 → OQ7]
- 위험 — 숨은 가정 | discover-spec 은 mtime 최신 spec 을 골라 변경과 무관할 수 있다 — RC13 (plugins/quality-gates/scripts/discover-spec.sh) [RC13 → OQ10]
- 위험 — 숨은 가정 | Retry 로 코드를 쓴 오케스트레이터의 판정은 Law 2 문면과 닿는다 — 사람 reviewer 로 맞춘다(D22) — RC32 (CLAUDE.md#Law 2) [RC32 → OQ4]
- 위험 — 숨은 가정 | 무동의 게시는 P17 「되돌리기 어려운·공유 state 액션은 항상 confirmation 게이트」와 엇갈린다 — Agent 상시 허용처럼 상시 동의로 기록해야 흔들리지 않는다 — RC41 (docs/philosophy/devbrew-harness-philosophy.md#P17) [RC41 → OQ23]
- 위험 — 리뷰 참고 | [direction] #2-제약 — plan 분할 축: D28·§7 의 「네 갈래 + 이음매」 plan 은 S12 로 넓어진 범위의 차등 테스트·판정 어휘·스크립트 구성요소를 담을 갈래가 없다. 사용자는 라운드 3 게이트에서 네 갈래 plan 유지를 골랐다 (리뷰 abf668a4#r3.2)
- 위험 — 숨은 가정 | 게시 kill switch 의 실제 집행이 걷을 두 sink 안에 있다 — 새 sink 로 옮기지 않으면 조용히 무력화된다 — RC43 (plugins/quality-gates/CHANGELOG.md#6.0.0) [RC43 → OQ6]

## 6. 사용자 원문

- **S1** 🗣 최초 요청(interview-seed 전문):
  > ---
  > type: interview-seed
  > next_phase: spec-distill:interview
  > audit_file: 2026-10-03-qg-review-e2e-publish-interview.audit.md
  > ---
  >
  > /qg 한 번이 리뷰 → 테스트 → e2e 질문 → 결과 게시까지 이어서 간다. (사용자 확인)
  > e2e 단계 · 게시 개편 · 게시 장치 걷기 · 리뷰 다이어트 넷 전부를 한 작업으로 한다. (사용자 확인)
  > 테스트 리뷰와 테스트 실행은 지금 장치(매번 차등 테스트, 테스트 파일이 바뀐 때만 pr-test-analyzer)로 충분하고 바꾸지 않는다. (사용자 확인)
  >
  > e2e 는 대상의 실제 앱·플로우를 구동하는 것이되, 기계 장치보다 에이전트가 직접 걸어보는 방식에 사람이 감독한다. (사용자 확인)
  > e2e 는 qg 가 이 변경에 맞는 걸을 경로를 제안하고 사용자가 고르거나 고친 뒤, 에이전트가 걸어 판정을 내고 사람은 감독하다 틀리면 뒤집는다. (사용자 확인)
  > e2e 를 돌렸는데 실패하면 qg 판정이 clean 이 될 수 없다. (사용자 확인)
  > 이것은 qg 9.0.0 이 runtime-verifier 를 지우며 거둔 런타임 검증 주장(브라우저 플로우 · AC 런타임
  > 검증)을 다시 들이는 일이다. 사용자는 「기계장치에 의존하기 보다는 직접 걷는 방식으로 사람 감독」을
  > 말했다. 지워진 runtime-verifier 의 형태(전용 agent · 브라우저 MCP 구동)를 다시 쓰는 것이 그
  > 「기계장치」에 해당하는지는 사용자가 말하지 않았고, 인터뷰에서 확인한다.
  >
  > 게시는 새 PR 본문을 만드는 것이 아니라 리뷰 결과를 코멘트로 올리는 쪽으로 바뀐다. (사용자 확인)
  > 게시는 /qg 실행마다 새 코멘트로, 동의를 묻지 않고 올린다. (사용자 확인)
  > 매 코멘트는 그 시점의 이해글과 그 실행의 qg 결과를 함께 담는다. (사용자 확인)
  > PR 이 없으면 게시를 건너뛰고 그 사실을 한 줄로 알리며, qg 는 push 나 PR 생성을 하지 않는다. (사용자 확인)
  > 지금 PR 에 올리는 문서 방식이 괜찮은지 점검하고, 걷어낼 수 있는 게시 장치는 최대한 걷어낸다. (사용자 확인)
  > 사용자는 지금 게시를 「새 본문을 만드는 것」으로 기억한다. 실제로는 PR 이 없을 때만 PR 본문을
  > 만들고, PR 이 있으면 마커 코멘트 하나를 매번 동의를 받아 덮어쓴다. 파이프라인 끝의 자동 게시
  > 제안은 6.0.0 에서 지워졌으므로, 이 요청은 그 결정과 게시 skill 의 「매 실행 동의」 불변식을 함께
  > 뒤집는다.
  >
  > qg 리뷰는 한 번의 리뷰로 장치를 덧붙이거나 보안을 과하게 경계하거나 선제적 오버 엔지니어링을 처방하지 않아야 한다. (사용자 확인)
  > 리뷰를 반영한 수정이 원래 의도에서 드리프트하는 것을 특히 피해야 한다. (사용자 확인)
  > 리뷰 다이어트의 구현 자체가 새 락·원장·게이트를 써도 되는지는 사용자가 말하지 않았다 — 원문의
  > 기준은 qg 리뷰가 처방하는 것과 게시 장치에 관한 것이다.
  >
  > 다시 검증할 것 — e2e 질문이 fix-loop 의 어느 시점에 오는지, e2e 가 실패하면 fix-loop 로
  > 돌아가는지, 사용자가 「안 한다」를 고르면 판정이 무엇이 되는지는 정하지 않았다. 걸을 앱이 없는
  > 대상(라이브러리, 이 리포 같은 문서·셸 플러그인 리포)에서 e2e 질문이 어떻게 보일지도 열려 있다.
  > 에이전트가 무엇으로 걷는지(브라우저 MCP · Bash 등)와, 걷고 판정하는 쪽이 쓰기 권한을 가진
  > 오케스트레이터인지 쓰기 없는 agent 인지(Law 2)도 열려 있다. 「실행마다 게시」가 Stop·중단으로
  > 끝난 실행에도 적용되는지는 묻지 않았다. 동의 없는 자동 게시에서 무엇을 남기고 무엇을 걷을지
  > (secret-scan, preview, 마커 upsert, `publish-active.md` 등)는 점검의 결과로 정할 일이고, Phase 0 은
  > 어느 장치도 보존·제거 대상으로 확정하지 않았다. 리뷰 다이어트가 리뷰어 페르소나 수정인지, 합성
  > 단계에서 처방을 거르는 것인지, 수정 전에 의도와 대조하는 것인지도 열려 있고, 그 구현이 새
  > 장치를 둬도 되는지는 인터뷰에서 확인한다. 페르소나 편집은 이
  > 리포에서 보안 리뷰 대상이다. 드리프트를 막으려면 원래 의도를 어디서(spec · plan · 커밋 · PR
  > 본문) 읽을지도 정해야 한다.

## 7. Next Action

superpowers 가 있으면 이 brief 를 context 로 `superpowers:brainstorming` 을 부른다. brainstorming 은
`-design.md` 를 쓰고 커밋하고, 그 설계문서 경로로 `spec-distill:reviewing-spec` 을 부른다
(brainstorming 의 사용자 리뷰 게이트 자리를 대신한다). 승인 게이트에서 진행을 고른 뒤
`superpowers:writing-plans` 로 넘어간다. 설계는 §3 의 OQ19(구성요소별 한 줄 표)에서 시작해, 그 표가
정하는 구성요소별 컷오버는 릴리스 단위가 되고, plan 은 네 갈래와 이음매로 나눠 병렬화한다(D28 · C9). superpowers 가 없으면 이 brief 가
완결 산출물이다.
