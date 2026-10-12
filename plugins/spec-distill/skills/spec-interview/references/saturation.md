## 조사 호출 상한 · 포화 판정

이 파일은 두 때에 읽는다: 조사 호출 합이 `research_limit` 에 닿을 때, 그리고 floor 다섯이 사용자 답으로 모두
`closed` 가 될 때. 줄 형식은 끝의 `## audit §2 줄` 이 정본이고 `check_brief.py gate` 가 그 글자를 읽는다.

### 상한 값

`research_limit` 의 시작값은 `DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT` 다 — 양의 정수가 아니면 20 으로 두고 그 사실을
한 줄로 알린다. `saturation_limit` 의 시작값은 `DEVBREW_SPEC_DISTILL_SATURATION_LIMIT` 다 — 양의 정수가 아니면 5 로 두고
그 사실을 한 줄로 알린다. 둘 다 state 에 적고 연장마다 시작값만큼 더한다.

```bash
lim="${DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT:-20}"
case "$lim" in ''|*[!0-9]*|0) echo "[spec-distill] DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT='${DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT:-}' 가 양의 정수가 아니다 — 20 으로 둔다." >&2; lim=20 ;; esac
sat="${DEVBREW_SPEC_DISTILL_SATURATION_LIMIT:-5}"
case "$sat" in ''|*[!0-9]*|0) echo "[spec-distill] DEVBREW_SPEC_DISTILL_SATURATION_LIMIT='${DEVBREW_SPEC_DISTILL_SATURATION_LIMIT:-}' 가 양의 정수가 아니다 — 5 로 둔다." >&2; sat=5 ;; esac
echo "research_limit=$lim saturation_limit=$sat"
```

### 상한 도달

`research_dispatches` 합이 `research_limit` 에 닿으면 다음 조사 dispatch **전에** 멈춘다. 하한 자리도 상한 앞에서 멈춘다 —
coverage-mapper · blind-spot-prober 의 첫 호출도 예외가 아니다. 그 순간 한 줄을 그대로 낸다:

> `[spec-distill] 조사 호출 상한 도달 — <n>/<limit>. 연장 · 판정 · 종료 중 고르세요.`

그리고 `AskUserQuestion` 1회로 셋 중 하나를 받는다(첫 선택지가 추천):

- 「같은 크기만큼 연장」 — `research_limit` 에 시작값을 더하고 멈췄던 dispatch 를 한다.
- 「지금 포화 판정으로」 — floor 가 다 닫혔으면 아래 `### 포화 판정` 으로 간다. 아직 열린 floor 는 사용자 질문으로 닫는다
  — blind_spot 첫 호출이 남았으면 web 비활성 때와 같은 inline premortem 강등으로 닫는다.
- 「인터뷰 종료」 — SKILL 의 「나가는 문」(사용자-승인 박제)으로 간다.

답은 사용자 발화 `S<m>` 으로 기록하고 audit §2 에 `- 상한 도달 <n>/<limit> — 사용자 선택 S<m>: …` 을 남긴다.

### 포화 판정

floor 다섯이 사용자 답으로 모두 `closed` 가 되면 brief 작성(`finishing.md`)으로 가기 **전에** 판정자를 부른다.
판정자 호출 수가 `saturation_limit` 에 닿았으면 부르기 전에 `### 판정 상한` 으로 간다.

입력을 만든다:

- `${DECISIONS}` — `open_decisions[]` 전량, 한 줄에 하나 `OQ<n>: <한 줄> [열림|해결]`.
- `${RESEARCH_OUTPUTS}` — state 본문의 `### 조사 <n> — <장치> · R<round>` 블록을 번호 순으로 그대로 이어 붙인다.
  `research_log` 의 `changed` · `opened` · `summary` 는 싣지 않는다. 블록이 하나라도 빠졌으면(이월한 세션 · 원문을
  남기지 않은 조사) 요약으로 대신하지 않는다 — `### 판정 불가` 로 간다(사유 `조사 원문 블록 누락: <n…>`).
- `${LEDGER_STATE}` — floor + derived 원장 행 그대로.

```
Agent({ description: "Judge research saturation", subagent_type: "spec-distill:saturation-judge",
        prompt: "열린 결정과 해결된 결정 전량: <decisions>${DECISIONS}</decisions>. 조사 산출 원문(시간 순 번호 · verbatim): <research_outputs>${RESEARCH_OUTPUTS}</research_outputs>. 원장 상태(floor + derived 행 그대로): <ledger_state>${LEDGER_STATE}</ledger_state>. 판정 기준대로 verdict · novelty · basis · gaps 를." })
// **처분** — consumer=orchestrator · fail-closed · disclosure=포화 판정 불가 공시 + 사용자 선택
```

판정자는 최근 조사 두 번이 모두 결정을 바꾸지도 열지도 않았을 때만 「포화」를 낸다 — 「충분해 보인다」는 근거가 아니다.
판정자 호출은 조사 호출 상한에 세지 않는다. 판정마다 `saturation_log` 에 `{k, round, verdict, gaps, user_choice: null}` 을 더한다.

- `saturated` — audit §2 에 `- 포화 판정 <k>: 포화 — <basis 요지>` 를 남기고 `finishing.md` 로 간다.
- `not_saturated` — audit §2 에 `- 포화 판정 <k>: 아직 — 빈 곳 <g>개` 를 남긴다. `### 반복 감지` 를 먼저 보고,
  반복이 아니면 빈 곳을 조사한다(같은 질문을 되풀이하지 않고 다른 접근 먼저). 조사가 결정을 바꾸거나 열면 라운드가
  사용자에게 돌아가고 floor 가 재개방될 수 있다. floor 가 다시 모두 닫히면 판정자를 다시 부른다.

판정자의 `novelty` 와 본체의 `research_log` 표시가 다르면 그 라운드의 «지금 이해»에 한 줄로 보인다 — 같은 `n` 에서
`changed` 집합이 다르거나, `research_log.opened` 가 `[]` 인데 판정자 `opened` 가 `없음` 이 아니거나 그 반대일 때다.
멈춤은 판정자의 것을 따른다.

### 반복 감지

반복 감지는 판정자가 아니라 본체가 한다(판정자는 앞 판정을 받지 않는다). `not_saturated` 의 빈 곳마다 `saturation_log`
의 이전 빈 곳과 비교해, `may_change` 결정 집합과 `device` 가 둘 다 같으면 같은 빈 곳이다(`look_at` 문장은 비교하지
않는다 — 판정자는 같은 빈 곳을 매번 다른 문장으로 쓸 수 있다). `may_change` 가 빈 빈 곳은 `opens` 문장의 공백 정규화
일치를 함께 본다. 같은 빈 곳이 하나라도 있으면 혼자 다시 돌리지 않고 그 빈 곳을 사용자에게 보인 뒤 `AskUserQuestion` 1회로
「한 번 더 조사」 · 「포화로 보고 종료」 · 「인터뷰 종료」 중 하나를 받는다. 같은 입력의 steelman 재호출도 하지 않는다.

- 「한 번 더 조사」 → `- 포화 판정 <k>: 아직 — 반복 빈 곳 재조사(@S<m>)`
- 「포화로 보고 종료」 → `- 포화 판정 <k>: 사용자 판단 포화(@S<m>) — 반복 빈 곳` 뒤 `finishing.md`
- 「인터뷰 종료」 → `- 사용자 종료(@S<m>) — 마지막 판정 아직` 뒤 나가는 문

### 판정 불가

Agent 도구가 없거나, dispatch 가 실패하거나, 출력이 깨졌거나(`not_saturated` 인데 `gaps` 가 빔 · 필드 누락), 조사 원문
블록이 빠졌으면 모델이 혼자 끝내지 않는다. 한 줄을 낸다:

> `[spec-distill] 포화 판정 불가 — <사유>`

그리고 `AskUserQuestion` 1회로 「포화로 보고 종료」 · 「조사 계속」 중 하나를 받는다. 공시는 포화 판정 불가 공시 + 사용자 선택 이다.

- 「포화로 보고 종료」 → `- 포화 판정 <k>: 사용자 판단 포화(@S<m>) — 판정 불가(<사유>)` 뒤 `finishing.md`
- 「조사 계속」 → `- 포화 판정 <k>: 판정 불가(<사유>) — 조사 계속(@S<m>)`. 뒤에 포화 판정이나 사용자 종료 줄이 와야
  게이트가 통과한다.

### 판정 상한

floor 다섯이 닫힌 뒤에는 「판정자 → 빈 곳 조사 → 판정자」 고리가 사용자 턴 없이 돌 수 있다. 판정자 호출 수가
`saturation_limit` 에 닿으면 다음 판정자 dispatch **전에** 멈추고 한 줄을 낸다:

> `[spec-distill] 포화 판정 상한 도달 — <k>/<limit>. 연장 · 포화로 보고 종료 · 인터뷰 종료 중 고르세요.`

`AskUserQuestion` 1회로 「같은 크기만큼 연장」 · 「포화로 보고 종료」 · 「인터뷰 종료」 중 하나를 받고 audit §2 에
`- 판정 상한 도달 <k>/<limit> — 사용자 선택 S<m>: …` 을 남긴다. 「포화로 보고 종료」는
`- 포화 판정 <k>: 사용자 판단 포화(@S<m>) — 판정 상한`, 「인터뷰 종료」는 `- 사용자 종료(@S<m>) — 마지막 판정 아직` 으로 잇는다.

### audit §2 줄

`finishing.md` Step A ④ 가 mapper 줄 아래에 시간 순으로 옮겨 쓴다. 판정 줄은 같은 차례 `<k>` 에 사용자 선택 줄이 이어진다.

- `- 조사 호출 <n>/<limit> (장치별: 커버리지 <a> · 맹점 <b> · 반론 <c> · 레포 조사 <d> · 본체 직접 <e>)` — `<e>` 는 상한 밖이고 보이기만 한다.
- `- 상한 도달 <n>/<limit> — 사용자 선택 S<m>: 연장 | 판정으로 | 인터뷰 종료`
- `- 판정 상한 도달 <k>/<limit> — 사용자 선택 S<m>: 연장 | 포화로 보고 종료 | 인터뷰 종료`
- `- 포화 판정 <k>: 포화 — <basis 요지>`
- `- 포화 판정 <k>: 아직 — 빈 곳 <g>개`
- `- 포화 판정 <k>: 사용자 판단 포화(@S<m>) — <반복 빈 곳 | 판정 불가(<사유>) | 판정 상한>`
- `- 포화 판정 <k>: 판정 불가(<사유>) — 조사 계속(@S<m>)`
- `- 포화 판정 <k>: 아직 — 반복 빈 곳 재조사(@S<m>)`
- `- 사용자 종료(@S<m>) — 포화 판정 전`
- `- 사용자 종료(@S<m>) — 마지막 판정 아직`

장치 이름(`coverage-mapper`)은 mapper 줄 밖에 쓰지 않는다 — 게이트의 하한 검사가 그 글자의 첫 매치를 읽는다.
