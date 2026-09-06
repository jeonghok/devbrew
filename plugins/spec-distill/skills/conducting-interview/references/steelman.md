### R3 — Steelman 의심 게이트 (P17)

의심된 방향에 대해 steelman-builder 가 **원안과 대안 양쪽**의 최강 케이스를 사용자 goal 기준으로 쓰고,
근거가 핵심 전제에 닿는지 판정한 뒤 추천을 낸다. 재검토를 여는 열쇠는 하나 — 새 근거가 핵심 전제와
직접 충돌할 때. 그 외의 근거는 원안을 강화하거나 경계를 다듬는 데 쓴다. 판정은 유지 / 보완 / 전환 /
보류 넷이고 선택은 사용자가 한다.

**trigger** = landscape 모순 / 알려진 anti-pattern / 기존 사용자 제약과의 충돌. 커버리지 공백은 R3
대상이 아니다 — probe 질문으로 간다(coverage-mapper 블록).

#### Step 1 — dispatch 재료 도출 (orchestrator)

- **핵심 전제 P1..Pn** — R1 문제정의·goal 과 그때까지의 `user_statements` 에서 도출한다. 각 전제 뒤에
  근거 S<N> 을 적고, 적을 수 없으면 「orchestrator 도출」로 표기한다. 개수 상한은 없다.
- **goal** — goal 내용을 담은 사용자 발화 중 **가장 최근 것**의 원문(S<N> 인용). seed S1 의 goal 문장은
  후보 중 하나이고 더 늦은 발화가 goal 을 고쳤으면 그쪽이 이긴다. 후보가 없거나(확인 발화가 「맞아」류
  동의문뿐) 후보 둘이 충돌하면 dispatch **전에** 한 probe 로 goal 한 문장을 사용자에게 받아 그 답 원문을
  쓴다. orchestrator 가 쓴 재구성 문장은 어떤 경우에도 goal 에 넣지 않는다.
- **constraints** — state `user_statements` 전량 원문.
- 어느 S<N> 을 goal 로 골랐는지, 전제 목록, 제약 S-id 범위를 audit §3 `#### ST<N>` 블록의 「dispatch 입력」
  소절에 적는다.

Web kill switch 는 dispatch 직전에 확인한다:

```bash
if [[ "${DEVBREW_SPEC_DISTILL_DISABLE_WEB:-0}" == "1" ]]; then
  echo "[spec-distill] web 비활성 — steelman 자동 생략, 사용자에게 의심 방향 수동 확인 요청" >&2
fi
```

```
Agent({ description: "Steelman both cases", subagent_type: "spec-distill:steelman-builder",
        prompt: "의심 방향: <direction>${SUSPECT_DIRECTION}</direction>. trigger: <trigger>${TRIGGER}</trigger>. 사용자 goal(원문): <goal>${GOAL}</goal>. 핵심 전제: <premises>${PREMISES}</premises>. 사용자가 지금까지 말한 제약(원문 전량): <constraints>${CONSTRAINTS}</constraints>. 양쪽 최강 케이스를 같은 기준으로, 전제 반증 판정과 추천을." })
// **처분** — consumer=orchestrator · fail-open · disclosure=loud advisory
```

한 방향당 steelman 1회 — 새 근거 없으면 재steelman 금지(AP16).

#### Step 2 — 게이트-전 확인 (orchestrator, Read/Grep)

- `repo_claims` 전 항목: 경로 실재 → 앵커 실재 → 주장이 그 자리와 맞는가. 결과 ∈ {확인, 반증, 미확인}.
- **양성 부착 주장 전부**(C4): `evidence[]`·`repo_claims[]` 중 `touches` 가 비어 있지 않은 항목마다 `claim` 을
  지목된 전제 문장과 대조한다(repo_claims 는 경로·앵커 확인을 먼저 통과한 것만). 결과 ∈ {확인, 반증}.
  `premise_refutation.hits` 는 그 부분집합(부착 중 「충돌」을 주장하는 것)이라 같은 대조 안에서 「충돌인가」까지
  본다. 음성(`touches` 빈 배열)은 확인하지 않는다.
- 「근거 N 중 부착 M」의 M 은 **확인을 통과한 부착**만 센다. 반증된 부착은 `[부착 주장 반증]` 라벨로 노출되고
  M 에 들지 않는다(N 에는 든다). 리포 주장은 「리포 주장 K 중 확인 J」로 따로 센다.
- 결과는 audit §3 `#### ST<N>` 블록의 「게이트-전 확인」 소절에 주장별 한 줄로 남는다.
- 반증된 항목은 4-block 에서 빼지 않고 「반증됨」 라벨을 단다. orchestrator 는 verdict 를 대신 내지 않는다.

#### Step 2.5 — 재검토 자격 판정

확인을 통과한 `hits`(전제 충돌) 개수로 둘 중 하나를 4-block 「막힌 결정」 첫 줄에 적는다:

- 충돌 ≥1 → `재검토 열림 — 전제 P<n> 충돌 확인 <k>건`. 4-block 은 Step 3 그대로.
- 충돌 0(hits 가 비었거나 전부 반증) → `재검토 사유 없음 — 확인된 전제 충돌 0건`. 게이트는 그대로 띄운다 —
  선택은 언제나 사용자다. 단 「추천 답안」의 orchestrator 줄은 유지 또는 보완 중 하나이고, builder 추천이
  switched 면 그 옆에 `[전제 충돌 없음]` 라벨을 붙인다. 이 상태에서 사용자가 전환을 고르면 그것은 근거-발동
  재검토가 아니라 **사용자 override** 다 — §5 항목 끝에 `— 사용자 override(전제 충돌 0)` 를 붙이고 audit §3 에도
  같은 문구를 남긴다. 봉쇄는 추천·라벨 층에 있고 선택지를 제한하지 않는다.
- `premise_list_challenge` 가 빠진 전제나 틀린 전제를 지목하면 「막힌 결정」에 그대로 보이고, 사용자가 받아들이면
  전제 목록을 고쳐 audit §3 에 적는다. 목록 수정 자체는 재검토를 열지 않는다 — 고친 전제에 닿는 확인된 충돌이
  있어야 연다. 같은 ST 안에서 재dispatch 는 하지 않는다.

#### Step 3 — 4-block 제시

- **현재 이해**: 의심 방향 + trigger.
- **막힌 결정**: Step 2.5 의 자격 판정 한 줄 → 전제 목록 P1..Pn **그대로**(C2) → builder 의 `premise_list_challenge`
  원문.
- **추천 답안**: 두 줄 나란히 — 「builder: <recommendation>」 / 「orchestrator: <의견>」. 아래에 `case_for_alternative`
  와 `case_for_current` 를 verbatim 으로. evidence 는 항목마다 `[부착 P<n>]` 또는 `[비부착]` 라벨, 반증된 것은
  `[반증됨]` 추가. 마지막 줄 「근거 N 중 부착 M · 리포 주장 K 중 확인 J」.
- **질문**: `AskUserQuestion` 선택지 **고정 순서** 유지 / 보완 / 전환 / 보류. `(Recommended)` 라벨은 붙이지 않는다.

conducting-interview 는 builder 출력을 **약화·편집하지 않는다** — verbatim 계약이다.

#### Step 4 — 기록

payload §5 항목은 **사용자가 고른 verdict 별로** 형식이 정해지고 builder 추천과 무관하다:

- 유지(kept): `- 기각 — <대안 statement> → <이유> — verdict: kept — ST<N> — 부착 M/N`
- 전환(switched): `- 기각 — <원안> → <이유> — verdict: switched — ST<N> — 부착 M/N`
- 보완(refined): `- 기각 — <버림> → <이유> — verdict: refined — ST<N> — 부착 M/N`. 「버림」은 builder 추천이 refined
  였으면 `refined_drops` 에서 오고, 아니면(builder 는 kept/switched 를 냈는데 사용자가 보완을 고름) 게이트 **직후**
  `AskUserQuestion` 1회(자유 텍스트)로 취함/버림을 받아 그 원문을 S<N> 으로 기록하고 그 「버림」을 쓴다.
- 보류(deferred): `- 보류 — <대안 statement> → §3 OQ<k> — verdict: deferred — ST<N> — 부착 M/N`. 접두가 `보류` 인 이유:
  아무것도 버리지 않았으므로 R4 기각 계수에 들면 안 된다. `verdict:` 를 가지므로 skepticism verdict 항목으로 계수되고
  bijection A 에 든다. 같은 내용을 §3 OQ 에도 박제한다.

audit §3 `#### ST<N> — <요지>` 블록 순서: dispatch 입력(goal S-id · 전제 목록 · 제약 S-id 범위) → builder 출력 verbatim
→ 게이트-전 확인 → 사용자 선택 S<N>. payload §5 와 audit §3 은 `ST<N>` id 로 맞물린다(bijection A). frontmatter 에는
별도 필드를 두지 않는다.

#### Step 5 — steelman 0건으로 skepticism 을 닫을 때

의심 trigger 가 한 번도 발화하지 않은 인터뷰는 payload §5 에 `검토 —` 접두 항목 하나로 skepticism 을 닫는다:

`- 검토 — steelman 0건: 검토한 방향 <N>개 · 전제 <P1..Pn> · trigger 후보 <무엇을 봤는가> → 기각 이유 <왜 trigger 가 아닌가>`

접두가 `기각` 이 아닌 이유: R4 기각 계수에 섞이면 안 된다. coverage 원장 `floor:skepticism` evidence 는 이 항목을
가리킨다. `check_brief.py` 는 verdict 항목이 0건이면 이 항목을 **요구**하고, 네 토큰(검토한 방향 · 전제 · trigger 후보 ·
기각 이유)이 다 있어야 통과시킨다.

#### Web 부재 시 graceful degradation (R2 대칭)

`steelman-builder` 는 WebSearch/WebFetch 를 요구한다. kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 또는 web 도구
부재로 steelman 을 돌릴 수 없으면 — R2 landscape 와 대칭으로 — opaque 한 게이트 실패로 떨어뜨리지 말고
**loud advisory**(`[spec-distill] web 비활성 — steelman 자동 생략, 사용자에게 의심 방향 수동 확인 요청`)를 내고
**수동 의심 게이트**로 전환한다. 이 경우 §5 항목은 사용자 판단(유지/보완/전환/보류)을 근거로 기록하되 URL 부재 사유를
명시한다. 보류는 §3 OQ 에도 박제한다.

#### Law 2 경계

steelman 게이트는 Law 2 분리 메커니즘이 *아니다* — Law 2 분리 reviewer 는 오직 design doc(brainstorming `-design.md`)에만
적용된다. steelman 은 문제공간 품질을 끌어올리는 Law 1급 skepticism 의례다(verbatim pass-through 로 무력화 방지).
