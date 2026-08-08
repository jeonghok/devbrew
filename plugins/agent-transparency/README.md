# agent-transparency

> **이해부채를 줄인다.** 위임한 에이전트가 무엇을 했고 판단이 무엇에 근거하는지를,
> 결정·판정 시점에 먼저 드러낸다.

## ⚠️ 설치 전에 알아야 할 것 셋

1. **이 플러그인의 output style 을 끄려면 플러그인 전체를 비활성화해야 한다.**
   `force-for-plugin: true` 라서 설치하면 자동 적용되고 사용자의 `outputStyle`
   설정을 덮어쓴다. 플러그인을 끄면 훅과 `/standup` 도 함께 꺼진다. devbrew 의
   kill switch 규약은 훅에만 걸 수 있다 — 플랫폼이 플러그인 디렉토리에서 직접
   읽어가므로 환경변수가 개입할 지점이 없다.
2. **설치 이전 작업에는 이 플러그인이 만든 설명이 없다.** `/standup` 이 읽는
   주재료는 훅과 output style 이 쌓은 설명 블록인데, 설치 전 구간에는 그것이
   없다. 그리고 **답변은 그 사실을 알 수 없다** — 인벤토리의 `blocks` 는 모든
   어시스턴트 텍스트 블록이지 *이 플러그인이 유발한 설명* 이 아니다(OQ-T).
3. **이 플러그인이 대화창에 내는 설명에는 어떤 비밀 필터도 없다.** 훅 · output
   style · `/standup` 세 경로 모두 그렇다. 모델 출력에 필터를 거는 지점이
   플랫폼에 없고, 프롬프트로 막으면 능력 억제가 된다. **수용된 잔여 위험**이며
   그 계산은 설계 문서 §3 에 있다(OQ-J).

## 무엇을 하나

| 부품 | 하는 일 |
|---|---|
| `output-styles/agent-transparency.md` | 일곱 순간에 무엇을 담아야 하는지 규정 + 내장 `Explanatory` 흡수 |
| `hooks/subagent-explain.py` | 에이전트가 끝난 직후 설명 자리를 만든다 (검사·차단 없음) |
| `/standup` | 쌓인 설명 + git 으로 *"지금 어떤 상태인가"* 에 답한다 |

**상태 파일을 만들지 않는다.** 훅은 상수를 출력하고 준비 스크립트는 읽기만 한다.

## 사용법

```
/standup                      # 이 브랜치의 지금 상태
/standup main 브랜치도 같이    # 범위 조정은 자연어로 — 스크립트 플래그가 아니다
/standup 최근 3일만
```

`/standup` 의 응답은 전용 agent(`agent-transparency:transcript-reader`)의 fork 가
만든다. 이 agent 는 `tools: Read, Glob, Grep` fail-closed allowlist 를 선언한다 —
파일을 쓰거나 명령을 실행하거나 네트워크에 닿을 수 없다.

## Hooks Installed

| 훅 | 왜 skill 이 아닌가 |
|---|---|
| `SubagentStop` → `hooks/subagent-explain.py` | 에이전트 종료는 **모델이 알아서 반응할 수 없는 순간**이다. 이 이벤트만이 그 시점에 컨텍스트를 주입할 수 있고(다른 후보 이벤트는 전부 주입 불가), skill 은 모델이 부를 때만 돈다 |

kill switch: `DEVBREW_DISABLE_AGENT_TRANSPARENCY=1` ·
`DEVBREW_SKIP_HOOKS=agent-transparency:subagent-explain` — **훅에만 적용된다.**

## Principles Instantiated

- **Law 1 (Clarity Before Code)** — 일곱 순간의 필수 항목이 표로 열거돼 있고,
  `tests/test_output_style.py` 가 그 표를 mutation 과 함께 잠근다.
- **Law 2 (Writer ≠ Reviewer)** — `/standup` 의 전용 agent 가 fail-closed
  `tools: Read, Glob, Grep` allowlist 를 선언한다. 쓰기·실행·네트워크 도구가
  **없다** — `disallowedTools` 단독은 시간축으로 fail-open 이라 쓰지 않는다.
- **Law 3 (Every Cycle Leaves the System Smarter)** — 이 플러그인이 하는 일
  자체가 compounding 이다. 설명이 트랜스크립트에 쌓이고 `/standup` 이 그것을
  다음 세션에 되돌려 준다.
- **P13 (state 배치)** — state 파일을 만들지 않는다. 트랜스크립트가 이미 그
  역할을 한다.
- **`cost_class` 선언** — `skills/briefing-current-state/SKILL.md` 가
  `cost_class: variable` 을 선언한다. `low` 였다면 「읽는 양에 상한을 걸지
  않는다」와 모순됐을 것이다 — 상한 없는 탐색은 정의상 `variable` 이다.
- **억제 금지** — 읽는 양·설명 길이·용어 사용에 상한을 걸지 않는다. 용어 규칙은
  금지가 아니라 **상환 의무**다.

## 알려진 한계

`REFERENCE.md` 의 「미해결(OQ) 식별자 목록」이 전부다. 특히 OQ-J(비밀 필터 없음) ·
OQ-T(설치 이전 구간) · OQ-AB(읽은 수를 기계가 검증 못 함) · OQ-AD(나열 상한 밖
파일은 후보 검증을 안 거친다)를 먼저 읽을 것.

## 머지 후 수동 확인

**설치 후 bare 호출 경로는 A/B 측정에 포함되지 않는다**(OQ-R) — 러너는
`--plugin-dir`(미설치)로 돌고 그 환경에서는 명령이 네임스페이스 형태로만 잡힌다.
머지 직후 **PR 작성자**가 한 번 확인한다:

- [ ] 플러그인을 설치한 뒤 `/standup` 을 **bare 이름으로** 불러 응답이 오는가
- [ ] 그 응답 첫 줄에 `blocks: N 중 M 개를 읽었다` 형태의 수가 나오는가
- [ ] `SubagentStop` 훅이 `/standup` 의 fork 에 대해 설명 자리를 **안 만드는가**
      (만들면 `agent_type` 이 드리프트한 것 — `tests/probe/agent_type.txt` 재측정)
