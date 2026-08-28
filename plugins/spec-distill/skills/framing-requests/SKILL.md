---
name: framing-requests
description: >
  Phase 0 회의 skill. `/request-framing` 이 trivia escape 를 통과시킨 요청을 받아
  확산(원문 보존 → 레포 읽기 → 질문 라운드) 후 압축해, 새 세션 첫 턴에 붙여넣는
  `interview-seed` 메시지를 만든다. 산출물은 문서가 아니라 다음 세션의 첫 턴이다.
cost_class: medium
---

# Framing Requests — Phase 0

당신은 파이프라인 맨 앞의 **회의**를 진행 중입니다. 산출물은 문서가 아니라 **새 세션의 첫
턴에 그대로 붙여넣는 메시지**입니다.

**진입 선결조건** — `/request-framing` command 가 trivia escape 를 통과시킨 요청만 이
skill 에 옵니다. 5패턴 정의는 `${CLAUDE_PLUGIN_ROOT}/references/trivia-escape.md`.
**검사는 command 가 합니다** — 이 skill 은 그 정의를 인용할 뿐 다시 검사하지 않습니다.

## 무엇을 남기고 무엇을 깎는가

압축 규약 정본은 `${CLAUDE_PLUGIN_ROOT}/references/compression.md` 입니다.

**불변량은 넷** — **의도 · steering · 방향 · goal**, 그리고 그 넷을 지탱하는 사실 중
에이전트가 알 수 없는 것.

**방식은 확산 후 압축** — 긴 초안을 먼저 쓰고 **그 다음 깎습니다.** 처음부터 짧게 쓰지
않습니다. 크게 그린 다음 깎아낸 것이 처음부터 짧게 쓴 것보다 더 많은 것을 고려합니다.
긴 초안은 세션 state 에만 살고, `docs/` 에 나가는 것은 깎은 것뿐입니다.

## 확산

1. **원문 보존** — 사용자가 준 원문(요청·생각·대화 로그·자료)을 세션 state 에 그대로
   옮겨 적습니다. 지금 요약하지 않습니다 — 압축은 나중 단계이고, 지금 요약하면 압축이
   무엇을 떨어뜨렸는지 audit 이 못 남깁니다.
2. **레포 읽기** — 관련 코드 · `CLAUDE.md` · `AGENTS.md` · 기존 설계 문서를 읽습니다.
   다음 세션이 이미 아는 것(상시 규칙)은 압축 단계에서 깎일 대상이므로 지금 확인해 둡니다.
3. **질문을 한꺼번에** — 라운드마다 질문 하나씩 흩뿌리지 않고, 그 라운드에 필요한
   질문을 모아서 한 번에 묻습니다.
4. **부분 답 → 새 질문** — 사용자가 부분적으로만 답하면 남은 공백을 다음 라운드 질문으로
   좁혀 다시 묻습니다.

매 라운드는 **네 블록**으로 사용자에게 보고합니다 — 지금 이해한 작업 / 원문과 다른 점 /
아직 안 잡힌 것 / 질문.

**질문에도 라운드에도 분량에도 상한이 없습니다.** 질문 루프는 매 반복마다 사용자가
답해야 돌고 사용자가 그 루프의 시계입니다 — 자율이 없으므로 묶을 자율도 없습니다.

## 검증

### 억제 리뷰

```javascript
Agent({ description: "Seed suppression critique", subagent_type: "spec-distill:seed-critic",
        prompt: `초안 · 원문 · 레포 CLAUDE.md 를 전문 inline 으로 받는다. 네 축만 본다.
<draft>${BLOB}</draft>` })
// **처분** — consumer=orchestrator · fail-open · disclosure=framing_degradations
```

**뺄셈 검사입니다.** 「좋은 프롬프트냐」는 묻지 않습니다 — 그건 취향이고 비평자에게는
사용자의 도메인 지식이 없습니다.

### 냉독

```javascript
Agent({ description: "Seed cold readback", subagent_type: "spec-distill:seed-readback",
        prompt: `아래 seed 만 읽고 «내가 이해한 것은 이것이다» 를 산문으로 말하라.
<seed>${SEED}</seed>` })
// **처분** — consumer=orchestrator · fail-open · disclosure=framing_degradations
```

**싱크됐는지는 사용자가 읽고 판정합니다.** 에이전트가 통과·미달을 내면 어긋남의 감각이
사용자에게 오지 않습니다. 두 dispatch 의 raw 출력은 orchestrator 가 읽어 아래
`framing_degradations` 원장에 옮기고, 최종적으로 그 원장을 통해 사용자에게 갑니다.

## degrade 채널

이 skill 의 **degrade 채널**은 state 의 `framing_degradations` 원장입니다. 기록은
`brief_review_state.py degrade-append … --ledger-key framing_degradations --axis suppression`
으로 하고, **원장에 못 쓰면 그 사실 자체를 게이트 질문 텍스트에 한 줄로 싣습니다** —
기록이 없는 것과 degrade 가 없는 것은 다른 사실입니다.

codex 가 죽으면 record 하나가 남고 격리 critic 이 단독으로 돕니다. **억제 축은 판정에
합류하지 않습니다** — findings 는 어떤 병합기도 거치지 않고 사용자에게 직접 갑니다.

## 확정 — proceed 게이트

공통 계약의 정본은 `${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md` 입니다. 4옵션
게이트를 띄우고, 게이트 질문 텍스트에 degrade 를 **하나도 빠뜨리지 않고** 싣습니다.
**승인 이후에만** seed 파일이 `docs/` 에 쓰입니다.

게이트를 띄우기 **직전에** 구조 검사를 돌립니다:

```bash
python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/check_seed.py" \
  gate "$SEED" "$AUDIT"; seed_rc=$?
if [ "$seed_rc" -ne 0 ]; then
  echo "[spec-distill] seed 게이트 위반 — 위 항목을 고치고 다시 이 블록부터 탑니다. 게이트를 띄우지 않습니다." >&2
fi
```

`check_seed.py` 가 재는 넷은 **전부 부재 검사**입니다(원문 보존 하나만 audit 쪽 존재
검사). **본문에 존재 검사를 추가하지 마십시오** — 그것이 이 payload 를 양식으로 만드는
유일한 경로이고, `tests/test_seed_one_sentence.sh` 가 그 금지를 동작으로 잡습니다.

### 두 가드

- **polite stop 금지 (AP2)** — 승인 옵션인데 narrate 만 하고 다음 단계로 가지 않는 것은
  polite stop 입니다. 게이트를 거치지 않는 예외 경로(kill switch · 경로 부재)면 명시적
  advisory 단락을 동반해야 합니다 — 게이트-less silent 종료 금지.
- **cross-compact 조기 진행 금지** — 옵션 ①(`/compact` 후 다음 단계)을 고르면 verbatim
  `/compact` 명령을 노출하고 **거기서 턴 종료(STOP)** 합니다. 같은 턴에서 다음 단계로
  가지 않습니다. **다음 턴** 진입은 사용자가 `/compact` 를 실제 실행한 뒤 사용자
  트리거로만 일어납니다.

### 재결정 규약 (P23)

확산에서 확정된 것은 재논의 대상이 아니지만 **반증 대상입니다.** 압축 중에 그 확정이
틀렸다는 근거가 나오면 근거를 제시하고 **사용자 동의를 받아** 피벗합니다 — 임의 변경은
금지, 보고 후 재결정은 허용. 뒤집은 항목은 audit 에 *원래 / 재결정 / 근거* 세 칸으로
남깁니다. 정본은 `${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md` 의 「재결정 규약」 절.

## kill switch

- `DEVBREW_SPEC_DISTILL_DISABLE=1` — 즉시 abort, state 보존.
- `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1` — codex 억제 축만 skip, 격리 critic 은 정상.
