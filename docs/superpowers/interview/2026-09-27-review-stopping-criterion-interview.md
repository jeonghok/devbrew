---
name: review-stopping-criterion
type: interview-brief
created_at: 2026-09-27
session_id: 57c2d43f-5809-446c-869d-2e53f7862599
source: spec-distill conducting-interview v4.4.0
next_phase: superpowers:brainstorming
contract: v2
audit_file: 2026-09-27-review-stopping-criterion-interview.audit.md
user_sourced_items:
  - id: C1
    source: verbatim
    status: confirmed
    statement: "brief 리뷰 파이프라인이 과한 듯하다 — 그 파이프라인에서 조금 조정·덜어냄이 필요하다"
    evidence: S1
  - id: D2
    source: chosen
    status: confirmed
    statement: "과함의 층은 사용자 개입·비수렴이고, 리뷰와 관련된 다른 자리에서도 유사하게 발생한다"
    evidence: S2
  - id: D3
    source: chosen
    status: confirmed
    statement: "비수렴의 뿌리는 멈춤 기준 부재다 — 리뷰가 「충분한가」가 아니라 「더 찾을 게 있나」를 묻는다"
    evidence: S3
  - id: C4
    source: verbatim
    status: provisional
    statement: "(질문 선택지) 1·2 의 경우는 writing plan 에서 한 번 더 본다"
    evidence: S4
  - id: D5
    source: chosen
    status: provisional
    statement: "라운드 1 은 전체 리뷰, 라운드 2 이상은 직전 수정분만, 승인 기준은 반드시 잡을 범주 0건이며 나머지는 advisory 다"
    evidence: S5
  - id: C6
    source: verbatim
    status: confirmed
    statement: "좁혀서 보되 거기에 매몰되어 다른 곳에 미치는 영향을 간과해서는 안 된다"
    evidence: S6
  - id: D7
    source: chosen
    status: provisional
    statement: "라운드 2 이상도 전문을 읽고 finding 자격만 diff 가 도입한 것과 이음매로 좁힌다 — must-catch 는 층 2 충실도 전체(프로필 필드), 방향은 advisory 와 §3 이월, 재제기 금지는 전 축"
    evidence: S7
  - id: D8
    source: chosen
    status: confirmed
    statement: "advisory finding 은 게이트 질문이 아니라 Step B 에 한 목록(축·한 줄 요지)으로 1회 보이고, brief §3/§5 에 박제된다"
    evidence: S8
  - id: D9
    source: chosen
    status: confirmed
    statement: "묶음 advisory 목록이 한 화면(~10줄)을 넘으면 다시 과하다 — 상한 장치는 설계가 정한다"
    evidence: S9
  - id: D10
    source: chosen
    status: confirmed
    statement: "적용 범위는 spec-distill 세 자리(brief·design doc·seed) — 엔진 장치 + 세 프로필 값, quality-gates 는 필드 없이 현행 유지하되 회귀 확인, 레포 확인 사실 RC1~RC37 을 근거로 수용"
    evidence: S10
  - id: D11
    source: chosen
    status: confirmed
    statement: "must-catch 는 층 번호가 아니라 프로필이 지목한 축 집합이다 — brief 는 층 2 여섯 축, seed 는 층 1 충실도 네 축, design doc 은 설계가 정한다"
    evidence: S12
  - id: D12
    source: chosen
    status: confirmed
    statement: "diff 자격 좁히기는 advisory 축(방향·overdesign)에만 걸고, must-catch 축은 매 라운드 전문 대조 자격을 유지한다"
    evidence: S13
---

# 리뷰 멈춤 기준 — Interview Brief

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming 해답공간으로
> 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다. 텔레메트리는 `audit_file`에 있다.

## 0. 한눈에

**무엇** — spec-distill 의 공유 문서 리뷰 엔진(brief · design doc · seed 리뷰가 함께 씀)에 「충분하다」는
정지 기준을 넣는다. **왜** — 리뷰가 라운드마다 「더 찾을 게 있나」를 새로 묻고, 같은 입력에서도 새
finding 을 샘플링해, 멈추는 시점을 문서 상태가 아니라 상한·사용자 피로가 정한다(brief 리뷰 최근 4회 전부
상한 또는 수동 종료, 회당 결정 14~19건). **확정 후보** — 라운드 2 이상도 전문은 읽되, advisory 축(방향·overdesign)의 finding 「자격」만
「diff 가 도입한 것 + 이음매」로 좁힌다(diff 기준점은 ✎ 추론 — §2). must-catch 축은 매 라운드 전문 대조한다.
승인 기준은 must-catch(프로필이 지목한 축 집합 — brief 는 층 2 충실도 여섯 축) 0건. 방향·overdesign 은 advisory 로 Step B 에 한 목록으로 보이고 §3 로 이월한다.
적용은 spec-distill 세 자리. **열림** — design doc 프로필의 must-catch 값, advisory 목록 상한, 탐지 단계의 diff 여부, must-catch 축의 멈춤 보장 등
아홉(§3). **다음** — brainstorming 해답공간.

**결정 목록**

- OQ1 [해결 ⟨S2⟩] — 「과함」이 어느 층인가 → 근거 RC12
- OQ2 [해결 ⟨S3⟩] — 비수렴의 뿌리 → 근거 RC24 · RC28
- OQ3 [해결 ⟨S4⟩] — 멈춤 기준 뒤에도 반드시 잡을 finding
- OQ4 [해결 ⟨S7⟩] — must-catch 범위(방향+왜곡 vs 충실도 전체) → 근거 RC25 · RC29 · RC18 · RC36 · RC23 · RC31
- OQ5 [해결 ⟨S5⟩] — 외부 선례 중 멈춤 기준의 방향
- OQ6 [해결 ⟨S8⟩] — advisory 표시 방식
- OQ7 [해결 ⟨S9⟩] — 묶음 목록의 과함 기준
- OQ8 [해결 ⟨S10⟩] — 적용 범위 → 근거 RC37
- OQ9 [열림] — design doc 프로필의 must-catch 값(seed 는 층 1 충실도 네 축 — ⟨S12⟩)
- OQ10 [열림] — advisory 묶음 목록 상한 장치
- OQ11 [열림] — 재제기 금지 규약을 전 축으로 넓히는 형태 → 근거 RC33
- OQ12 [열림] — 탐지 단계에도 diff 를 줄 것인가 → 근거 RC26
- OQ13 [열림] — must-catch 0건의 단일 판정자 잔여 위험
- OQ14 [열림] — bundle/inline-blob rc 3 degrade 의 실제 원인 → 근거 RC13
- OQ15 [열림] — 공유 스크립트 변경의 quality-gates 회귀 확인 방법 → 근거 RC37 · RC11
- OQ16 [열림] — design doc · seed 자리의 advisory 박제처
- OQ17 [열림] — must-catch 축이 라운드마다 선재 본문에서 새 finding 을 내면 무엇이 멈춤을 보장하는가 → 근거 RC31

## 1. Goal · Non-goal

- Goal: 공유 리뷰 엔진이 상한·사용자 피로가 아니라 **문서 상태(must-catch 0건)** 로 멈추게 해서, 사용자 개입을
  load-bearing 판정(원문 충실도)으로 줄인다 — 좁힌 리뷰가 다른 절·다른 자리에 미치는 영향을 놓치지 않으면서.
- Non-goal: Law 2 분리 리뷰(쓰기 권한 없는 리뷰어) · kill switch · 재리뷰 상한 2 의 제거.
- Non-goal: 방향·overdesign **탐지** 자체의 제거 — 게이트에서 내릴 뿐 계속 찾고 보인다.
- Non-goal: quality-gates 쪽 리뷰 동작 변경(필드 없는 프로필은 현행 유지).
- Non-goal: reviewing-brief SKILL.md 의 유지보수 표면(펜스 머리 반복 등) 정리 — 이번 과함의 층이 아니다.

## 2. 제약

- 🗣 confirmed **C1** — brief 리뷰 파이프라인이 과한 듯하다 — 그 파이프라인에서 조금 조정·덜어냄이 필요하다 ⟨S1⟩
- ☑ confirmed **D2** — 과함의 층은 사용자 개입·비수렴이고, 리뷰와 관련된 다른 자리에서도 유사하게 발생한다 ⟨S2⟩
- ☑ confirmed **D3** — 비수렴의 뿌리는 멈춤 기준 부재다 — 리뷰가 「충분한가」가 아니라 「더 찾을 게 있나」를 묻는다 ⟨S3⟩
- 🗣 provisional **C4** — (질문 선택지) 1·2 의 경우는 writing plan 에서 한 번 더 본다 ⟨S4⟩
- ☑ provisional **D5** — 라운드 1 은 전체 리뷰, 라운드 2 이상은 직전 수정분만, 승인 기준은 반드시 잡을 범주 0건이며 나머지는 advisory 다 ⟨S5⟩
- 🗣 confirmed **C6** — 좁혀서 보되 거기에 매몰되어 다른 곳에 미치는 영향을 간과해서는 안 된다 ⟨S6⟩
- ☑ provisional **D7** — 라운드 2 이상도 전문을 읽고 finding 자격만 diff 가 도입한 것과 이음매로 좁힌다 — must-catch 는 층 2 충실도 전체(프로필 필드), 방향은 advisory 와 §3 이월, 재제기 금지는 전 축 ⟨S7⟩
- ☑ confirmed **D8** — advisory finding 은 게이트 질문이 아니라 Step B 에 한 목록(축·한 줄 요지)으로 1회 보이고, brief §3/§5 에 박제된다 ⟨S8⟩
- ☑ confirmed **D9** — 묶음 advisory 목록이 한 화면(~10줄)을 넘으면 다시 과하다 — 상한 장치는 설계가 정한다 ⟨S9⟩
- ☑ confirmed **D10** — 적용 범위는 spec-distill 세 자리(brief·design doc·seed) — 엔진 장치 + 세 프로필 값, quality-gates 는 필드 없이 현행 유지하되 회귀 확인, 레포 확인 사실 RC1~RC37 을 근거로 수용 ⟨S10⟩
- ☑ confirmed **D11** — must-catch 는 층 번호가 아니라 프로필이 지목한 축 집합이다 — brief 는 층 2 여섯 축, seed 는 층 1 충실도 네 축, design doc 은 설계가 정한다 ⟨S12⟩
- ☑ confirmed **D12** — diff 자격 좁히기는 advisory 축(방향·overdesign)에만 걸고, must-catch 축은 매 라운드 전문 대조 자격을 유지한다 ⟨S13⟩

✎ C4 를 「좁은 범위만 반드시 잡아도 된다」로 읽는 것은 S4 와 그 앞 질문 문맥(선택지 1 = 방향 오류+원문 왜곡, 2 = 원문 충실도 전체)에서 나온 모델 해석이다 — 범위 선택 자체는 S5·S7 에 있다. 그 근거(「하류가 한 번 더 본다」)는 **원문 충실도에 대해서는 성립하지 않는다** — 하류 design doc 리뷰의
정답이 brief §2 라서 brief 의 왜곡은 하류에서 정답으로 집행된다(§5 ST1). C4 는 D7 에서 「충실도는 brief 에서
반드시 잡고, 방향만 하류로 넘긴다」로 좁혀져 살아남았다.

✎ D5 의 「라운드 2 이상은 직전 수정분만」은 D7 이 「읽기」 가 아니라 「finding 자격」 을 좁히는 것으로 보완했고(C6 이
허용하는 축소는 뒤쪽뿐이다), D12 가 그 자격 좁히기를 advisory 축으로 다시 한정했다(brief 리뷰 D1.2).

✎ diff 기준점을 「마지막으로 리뷰가 완료된 라운드」로 두자는 것은 모델 추론이다(§5 RC34 의 창 구멍) — S5·S7 은 기준점을 말하지 않았다. 설계가 정한다.

✎ must-catch 판정은 모델의 자유 라벨이 아니라 프로필 `layer_rubric` 의 **축 소속**으로 기계적으로 가르고, 축이
없거나 모호하면 must-catch 로 친다(fail-closed) — builder 의 전제 목록 반박에서 온 추론이다.

## 3. Open Questions

- OQ9: design doc 프로필의 must-catch 값 — brief 는 층 2 여섯 축, seed 는 층 1 충실도 네 축으로 정해졌다(S12). design doc 에서 무엇이 「하류가 다시 못 보는 것」인가.
- OQ10: advisory 묶음 목록의 상한 장치 — 한 화면(~10줄) 기준, 넘치면 무엇을 어떻게 접고 접은 개수를 어떻게 공시하나.
- OQ11: 재제기 금지 규약(「새 근거 없이 재논쟁하지 않는다」)을 overdesign 축에서 전 축으로 넓히는 형태 → 근거 RC33
- OQ12: 탐지 단계에도 diff 를 줄 것인가 — 재비판만 자격을 거르면 탐지 비용·finding 수는 그대로다 → 근거 RC26
- OQ13: must-catch 0건이 판정자 하나(`detectors: 1`)의 판단일 때의 잔여 위험 — 재비판자의 추가 finding · codex 교차가 충분한가.
- OQ14: bundle/inline-blob rc 3 degrade 의 실제 원인 — 최근 6회 중 3회 발화, 빌더는 `audit_file` 키를 가린다 → 근거 RC13
- OQ15: 공유 스크립트(`shared/docreview/scripts/`) 변경이 quality-gates 에 회귀를 만들지 않는지 확인하는 방법 → 근거 RC37 · RC11
- OQ16: design doc · seed 자리의 advisory 박제처 — D8 의 brief §3/§5 에 대응하는 자리는 어디인가.
- OQ17: must-catch 축이 라운드마다 선재 본문에서 새 finding 을 내면 무엇이 멈춤을 보장하는가 — 자격 좁히기는 advisory 축에만 걸린다(D12) → 근거 RC31

## 4. External Landscape

- 반복 개선의 이득은 1~2 라운드에 몰리고 이후 체감, 정지 규칙은 잔여 편집량·수렴 «self-refine» — [취함] — 상한이 아니라 수렴으로 멈춘다 [→ OQ5]
- 근사 수렴은 일찍 오고 불필요한 반복은 중복 변경·회귀를 낳는다 «recursive-refine» — [취함] — 라운드를 더 도는 것이 품질을 보장하지 않는다 [→ OQ5]
- 잡음은 리뷰어를 재훈련해 진짜 발견까지 무시하게 만든다 «alert-fatigue» — [취함] — hard gate 대상을 좁히는 근거 [→ OQ6]
- 매 푸시마다 전체 재리뷰하지 말고 직전 리뷰 이후 변경분만 «incremental-review» — [취함] — 단 「읽기」 가 아니라 「자격」 으로 적용(ST1) [→ OQ5]
- 게시 전 2차 패스로 「시니어가 신경 쓸까」를 거른다 «nitpick-filter» — [중립] — 재비판자가 이미 그 자리다 [→ 없음]
- 완벽이 아니라 「확실히 개선되면 승인」, 사소한 것은 Nit «google-standard» — [취함] — 차단/비차단 범주를 가르는 멈춤 기준 [→ OQ5]
- diff 만 준 리뷰는 사람이 짚은 이슈의 15–31% 만 잡고, 구조화된 diff+요약은 전체 맥락보다 낫다 «swe-prbench» — [취함] — 전문 읽기 유지 + diff 로 자격 판정 [→ OQ12]
- 변경이 말이 되는지 보려면 파일 전체를 봐야 할 때가 있다 «google-context» — [취함] — C6 의 외부 근거 [→ 없음]
- 두 라운드가 달성 가능한 이득의 76–95% «iter-repair» — [취함] — 재리뷰 상한 2 유지 근거 [→ 없음]
- 수리가 새 결함을 끼워 넣는 비율 평균 약 7% «bad-fix» — [중립] — 수정이 결함을 만들지만 「다수」 는 아니다 [→ 없음]
- 같은 리뷰 입력을 반복하면 출력이 달라진다 «llm-determinism» — [취함] — 비수렴의 기제는 재샘플링 [→ 없음]
- 반복 수정에서 정답은 흡수 상태가 아니다 «non-absorbing» — [취함] — 수정분 밖 기존 내용과의 대조가 필요 [→ OQ12]
- 리뷰 agent 가 출처가 아니라 산문을 검사하면 상류 오류가 그대로 배포된다 «multiagent-failure» — [취함] — 충실도는 brief 에서 잡아야 한다 [→ OQ4]
- 앞 단계 오류가 이후 궤적으로 전파된다 «error-propagation» — [취함] — 상류 충실도 결함이 가장 비싸다 [→ OQ4]
- unsafe 회귀 선택은 영향받는 곳을 빠뜨려 검출 손실 «rts-review» — [취함] — 이음매를 자격 안에 둔다 [→ OQ4]
- 사용자는 「보고 싶지 않았던 모든 보고」를 false positive 로 여긴다 «google-static» — [취함] — advisory 라벨만으로 소음 비용이 사라지지 않는다 [→ OQ6]
- 잔존 결함 추정에는 복수 독립 inspector 가 필요하다 «capture-recapture» — [취함] — 단일 판정자 0건은 결함 0 이 아니다 [→ OQ13]

## 5. 기각 · Blind Spots

- 기각 — 라운드 2 이상은 직전 수정분만 「읽는다」 → 이음매·omission·하류 정답화에 눈이 먼다(전제 P2·P3·P4 반증) — verdict: refined — ST1 — 부착 7/7
- 기각 — 하류 설계 리뷰가 brief 가 놓친 충실도 결함을 다시 잡는다(C4) / 충실도는 brief 에서 must-catch 로 잡는다(D7) / 하류 정답이 brief §2 다 — RC25 (plugins/spec-distill/references/docreview-profiles/design-doc.md#ground_truth) [RC25 → OQ4]
- 기각 — 비수렴의 다수는 직전 수정이 만든 것이다 → brief 방향 범주에서는 라운드 1 대상 밖 항목의 재샘플링이었다 — RC28 (docs/superpowers/interview/2026-09-21-interview-research-specialization-interview.audit.md#D2.9) [RC28 → OQ2]
- 기각 — design doc 리뷰 결정 수 r1 55 · r2 69 를 「수정이 결함을 만든다」의 근거로 쓴 해석 → 집계에 얼림 자동 결정이 섞여 결함 수가 아니다 — RC30 (docs/superpowers/specs/2026-09-22-interview-research-specialization-design.md#D2.21) [RC30 → 없음]
- 위험 — 사실 | brief 리뷰 최근 4회 전부 상한 또는 사용자 수동 종료, 회당 결정 14~19건 — RC12 (docs/superpowers/interview/2026-09-21-interview-research-specialization-interview.audit.md#S12) [RC12 → OQ1]
- 위험 — 사실 | 승인 가능 여부가 범주를 보지 않는다(모든 열린 항목이 차단) — RC24 (shared/docreview/scripts/docreview_state.py#approval_ready) [RC24 → OQ2]
- 위험 — 사실 | 사용자가 비수렴 상태에서 실제로 고른 처분이 「충실도 적용 · 방향 이월」이었다 — RC29 (docs/superpowers/interview/2026-09-21-interview-research-specialization-interview.audit.md#S12) [RC29 → OQ4]
- 위험 — 실패 양식 | 수정 중 소실: omission 은 따라갈 앵커가 없어 원문 전수 대조로만 잡힌다 — 읽기를 좁히면 사라진다 — RC18 (plugins/spec-distill/references/docreview-profiles/brief.md#omission) [RC18 → OQ4]
- 위험 — 실패 양식 | 파급 누락: 수정과 안 바뀐 절 사이의 어긋남(이음매)이 실제 라운드 2 finding 으로 나왔다 — RC36 (docs/superpowers/specs/2026-09-22-interview-research-specialization-design.md#D2.23) [RC36 → OQ4]
- 위험 — 실패 양식 | 창 구멍: critic 사망으로 6~7단계를 건너뛴 라운드의 편집이 「직전 라운드 diff」 어디에도 안 든다 — diff 기준점은 마지막 `round_reviewed` 라운드여야 한다 — RC34 (plugins/spec-distill/references/reviewing-document.md#5단계) [RC34 → 없음]
- 위험 — 실패 양식 | 공유 엔진 파급: `shared/docreview/scripts/` 가 quality-gates 에도 배포돼 승인 술어 변경이 다섯 자리에 닿는다 — RC37 (plugins/quality-gates/scripts/docreview_state.py#symlink) [RC37 → OQ8 · OQ15]
- 위험 — 숨은 가정 | 재비판자의 「이 변경이 도입했는가」 축은 이미 있으나 문서 자리에서 diff 를 싣지 않아 꺼져 있다 — 켜는 것이 곧 자격 좁히기다 — RC26 (plugins/spec-distill/agents/doc-recritic.md#이 변경이 도입했는가) [RC26 → OQ12]
- 위험 — 숨은 가정 | 「새 근거 없이 재논쟁 금지」 규약이 overdesign 축에만 있어, 자격만 좁히면 수정분을 건드린 선재 항목이 다시 올라온다 — RC33 (plugins/spec-distill/references/docreview-profiles/brief.md#자르지 않는 것) [RC33 → OQ11]
- 위험 — 숨은 가정 | must-catch 0건은 판정자 하나(`detectors: 1`)의 표본이라 결함 0 을 뜻하지 않는다 — §4 «capture-recapture»
- 위험 — 숨은 가정 | advisory 로 내려도 읽을 양은 남는다 — 목록 상한이 없으면 피로가 이름만 바뀐다 — §4 «google-static»
- 위험 — 숨은 가정 | 방향 축을 advisory 로 내리면 무조건 외부 반증 지점이 약해진다 — 하류 design doc 프로필은 `web: false` 이고, 인터뷰 steelman 은 trigger 조건부다 — RC23 (plugins/spec-distill/agents/steelman-builder.md#의심 trigger 가 없는 방향) [RC23 → OQ4]
- 위험 — 사실 | 수렴한 레포 선례(seed 리뷰 6→2→0)는 전문 읽기 + 신규 자료 개별 검사 형태였다 — RC31 (docs/superpowers/interview/2026-09-21-interview-research-burden-interview.audit.md#멈출 조건에 대한 관측) [RC31 → OQ4 · OQ17]
- 위험 — 숨은 가정 | must-catch 축의 수렴은 전문 재대조에서 재샘플링이 잦아든다는 가정에 기댄다 — 근거는 RC31 한 건뿐이다(§4 «llm-determinism») [RC31 → OQ17]
- 위험 — 미확인 | bundle rc 3 degrade 가 최근 6회 중 3회 — 원인 미확정(잡음 공시의 한 원천) — RC13 (plugins/spec-distill/scripts/build_brief_bundle.py#REDACT_KEYS) [RC13 → OQ14]
- 위험 — 사실 | 이 파이프라인을 참조하는 spec-distill 테스트가 34파일 — 락 동반 변경 비용 — RC11 (plugins/spec-distill/tests/test_reviewing_brief_residue.sh#guards) [RC11 → OQ15]

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > "briefing review 파이프라인이 과한듯 하여 그 파이프라인에서 조금 조정 덜어냄이 필요"

## 7. Next Action

이 brief 를 context 로 `superpowers:brainstorming` 호출 → `-design.md` 작성·커밋 → 그 설계문서 경로로
`spec-distill:reviewing-spec`(brainstorming 의 사용자 리뷰 게이트 대신) → 승인 게이트에서 진행을 고른 뒤
`superpowers:writing-plans`.
