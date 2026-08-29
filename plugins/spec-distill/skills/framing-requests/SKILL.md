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

## 상태

degrade 원장은 **기존** state 파일 안에 삽니다. 이 skill 은 state 파일을 만들지 않습니다.

```bash
SD="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}"
sid="$(python3 "$SD/scripts/state_path.py" session-id)" || sid=""
STATE="$(python3 "$SD/scripts/state_path.py" state-root)/$sid/state.local.md"
if [ -n "$sid" ] && [ -f "$STATE" ]; then
  python3 "$SD/scripts/brief_review_state.py" init "$STATE" --ledger-key framing_degradations; ledger_rc=$?
else
  ledger_rc=1
fi
```

`--ledger-key framing_degradations` 는 표준 3키에 **더해** 이 원장 줄을 심습니다(치환이
아닙니다 — brief 파이프라인의 원장은 그대로 남습니다). 이 호출이 없으면 뒤의
`degrade-append` 가 「라인 부재」로 죽습니다 — 닫힌 열거에 이름이 있다는 것과 그 원장에
쓸 수 있다는 것은 다른 사실입니다.

`ledger_rc` 가 0 이 아니면 원장 없이 진행합니다. 그 처리는 `## degrade 채널` 에 있습니다.

## 검증

억제 축의 담당은 **둘**입니다 — 격리 critic 과 codex. 냉독은 별개 축입니다.

### 재료 조립

번들(초안 · 사용자 원문 · 레포 `CLAUDE.md`)은 **한 번만** 조립하고 두 담당이 나눠
씁니다. 조립이 두 곳에 있으면 한쪽만 고쳐질 때 두 리뷰어가 서로 다른 재료를 보게 되고,
그 어긋남은 findings 가 갈릴 때까지 드러나지 않습니다.

```bash
SD="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}"
PAYLOAD="$(mktemp -t sd-seed-blob-XXXXXX)"
CODEX_YAML="$(mktemp -t sd-seed-codex-XXXXXX)"
python3 "$SD/scripts/build_seed_inline_blob.py" "$SEED" "$AUDIT" CLAUDE.md > "$PAYLOAD"; blob_rc=$?
```

`blob_rc` 가 0 이 아니면 번들이 없는 것이므로 **두 담당 모두** 돌리지 않고, 그 사실을
`component: pipeline` · `affected_axis: suppression` · `verification_status: unavailable`
로 남깁니다.

아래 codex 게이트 블록은 **이 블록과 같은 `Bash` 호출**에서 이어서 돌립니다 — `Bash`
도구는 호출마다 새 셸이라 `$PAYLOAD`·`$CODEX_YAML` 은 다음 호출에 남지 않습니다.

### 억제 리뷰 — 격리 critic

```javascript
Agent({ description: "Seed suppression critique", subagent_type: "spec-distill:seed-critic",
        prompt: `초안 · 원문 · 레포 CLAUDE.md 를 전문 inline 으로 받는다. 네 축만 본다.
<draft>${BLOB}</draft>` })
// **처분** — consumer=human · fail-open · disclosure=framing_degradations
```

`${BLOB}` 은 위에서 조립한 `$PAYLOAD` 의 내용입니다 — codex 가 파일로 받는 것과 같은
번들을 인라인으로 넘깁니다.

**뺄셈 검사입니다.** 「좋은 프롬프트냐」는 묻지 않습니다 — 그건 취향이고 비평자에게는
사용자의 도메인 지식이 없습니다.

### 억제 리뷰 — codex

억제 축의 **세 번째 담당**입니다. 러너는 `DEVBREW_SPEC_DISTILL_DISABLE_CODEX` 를 스스로
보지 않습니다 — 게이트는 **호출자 책임**이고 그 호출자가 여기입니다.

조건을 **산문으로 적지 않습니다.** 문장으로 「가용할 때만」이라 적고 bash 펜스는 무조건
실행되게 둔 판본이 형제 skill 에 실제로 있었고, 그 파일에는 `codex_avail` 을 검사하는
`if` 가 아예 없었습니다. kill switch 는 P21 보안 컨트롤이라 그 상태는 「껐다고 믿게만」
만듭니다.

<!-- codex-gate:begin runner=run_seed_codex_reviewer.sh -->
```bash
SD="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}"
DETECT_OUT="$(bash "$SD/scripts/detect_codex.sh")"
codex_avail="$(printf '%s\n' "$DETECT_OUT" | sed -n 's/^codex_available: //p')"
skip_reason="$(printf '%s\n' "$DETECT_OUT" | sed -n 's/^skip_reason: //p')"
# 정상 실행된 감지기는 false 일 때도 `codex_available:` 줄을 내고 exit 0 한다. 그 줄이
# 없으면 감지기 자체가 안 돈 것이다(끊긴 심볼릭 링크·빈 stdout) — 「codex 가 없다」와
# 구별해서 적는다. 뭉개면 사용자가 이유 없는 SKIPPED 만 본다.
if [[ -z "$codex_avail" ]]; then skip_reason="detector_not_runnable"; fi
# 「재료 조립」과 이 블록이 다른 Bash 호출로 갈라지면 두 변수가 소멸한다. 그대로 두면
# 러너가 빈 경로를 받아 payload_missing 으로 **조용히** degrade 한다 — 침묵이 결함이다.
# 여기서 잡아 소리를 내고 가용 판정을 덮어쓴다.
if [[ -z "${PAYLOAD:-}" || -z "${CODEX_YAML:-}" ]]; then
  echo "[spec-distill] codex 억제 게이트 입력 부재 — PAYLOAD='${PAYLOAD:-}' CODEX_YAML='${CODEX_YAML:-}'. 「재료 조립」 블록을 같은 Bash 호출에서 먼저 돌려라. 이 라운드의 억제 축은 codex 없이 간다." >&2
  codex_avail=""; skip_reason="gate_inputs_missing"
fi
if [[ "$codex_avail" == "true" ]]; then
  bash "$SD/scripts/run_seed_codex_reviewer.sh" suppression "$PAYLOAD" "$(pwd)" "$CODEX_YAML"; runner_rc=$?
  # exit 3 은 「산출물 자체를 못 썼다」이다. 그때 직전 라운드 YAML 이 디스크에 그대로
  # 남아 이번 라운드 판정으로 읽히는데, 그 파일은 양성 마커(codex_failed: false)를
  # 달고 있을 수 있어 「이번에 codex 가 정상이었다」로 읽힌다. 지운다.
  if [[ "$runner_rc" -eq 3 ]]; then rm -f "$CODEX_YAML"; fi
else
  echo "[spec-distill] codex 억제 co-review SKIPPED (reason: ${skip_reason:-unknown}) — 격리 critic 단독, 이 축에 모델 다양성이 없었다 (degraded)." >&2
fi
```
<!-- codex-gate:end -->

**축은 죽지 않습니다** — 격리 critic 이 남습니다. 위 stderr advisory 는 사용자에게 그대로
노출하고, 같은 사실을 아래 `framing_degradations` 원장에도 남깁니다.

codex 의 raw findings 도 격리 critic 의 것과 **나란히** 사용자에게 갑니다 — 병합기가
없고 판정도 없습니다(§`degrade 채널`).

### 냉독

```javascript
Agent({ description: "Seed cold readback", subagent_type: "spec-distill:seed-readback",
        prompt: `아래 seed 만 읽고 «내가 이해한 것은 이것이다» 를 산문으로 말하라.
<seed>${SEED}</seed>` })
// **처분** — consumer=human · fail-open · disclosure=framing_degradations
```

**싱크됐는지는 사용자가 읽고 판정합니다.** 에이전트가 통과·미달을 내면 어긋남의 감각이
사용자에게 오지 않습니다. 세 리뷰(격리 critic · codex · 냉독)의 raw 출력은 **사용자에게 직접** 갑니다 —
orchestrator 는 그것을 아래 `framing_degradations` 원장에 옮겨 적을 뿐, 판정하거나
병합하지 않습니다.

## degrade 채널

degrade 는 **채널 둘**로 나갑니다. 하나는 없을 수 있고 하나는 항상 있습니다.

1. **원장** — state 의 `framing_degradations`. **`ledger_rc` 가 0 일 때만 존재합니다.**
   기록은 `brief_review_state.py degrade-append "$STATE" --ledger-key framing_degradations …`
   이고, 매 호출의 종료 코드를 그 자리에서 잡습니다.
2. **proceed 게이트 질문 텍스트** — 항상 있습니다. 원장이 없거나(`ledger_rc != 0`) 개별
   `degrade-append` 가 실패하면 **이쪽이 유일한 채널**이고, 그때는 「원장에 기록하지
   못했다」는 사실 자체를 한 줄로 함께 싣습니다.

**기록이 없는 것과 degrade 가 없는 것은 다른 사실입니다.** 게이트 텍스트에서 둘을
구별해 씁니다 — 원장이 없는 세션에 「degrade 없음」이라고 쓰지 않습니다.

**남은 갭 — `no-state-in-phase-0`.** `request-framing` 은 인터뷰 이전이라 state 파일이
아예 없는 세션이 **정상**입니다. 그 세션에서 원장은 구조적으로 부재하고 채널 2 만
남습니다. state 파일을 새로 만드는 설계(어디에 · 어떤 frontmatter 로 · 누가 지우나)는 이
skill 의 범위 밖이므로, 그 갭을 이 이름으로 부르고 게이트 텍스트가 그 사실을 말합니다.

codex 가 죽으면 record 하나가 남고 격리 critic 이 단독으로 돕니다. **억제 축은 판정에
합류하지 않습니다** — findings 는 어떤 병합기도 거치지 않고 사용자에게 직접 갑니다.

codex 축의 record 는 게이트 블록이 낸 값으로 정합니다. `--component codex --axis
suppression` 은 세 경우 모두 같고 갈리는 것은 `--status` 와 `--reason` 입니다.
**위에서부터 먼저 맞는 행**을 씁니다:

| 관측 | `--status` | `--reason` |
|---|---|---|
| `skip_reason` 이 `gate_inputs_missing` | `unavailable` | 게이트 입력 부재 — 「재료 조립」이 같은 Bash 호출에서 돌지 않았다 |
| `codex_avail` 이 `true` 가 아니다 | `skipped` | `$skip_reason` 값 그대로 |
| `codex_avail` 이 `true` 였는데 `$CODEX_YAML` 에 `codex_failed: false` 가 없다 | `degraded` | `$runner_rc` + 관측한 사실(파일 부재·0바이트·잘림·`true`) |

첫 행이 둘째 행보다 먼저인 이유: 게이트 입력 부재는 `codex_avail` 을 덮어써서 둘째 행에도
맞지만, 그것은 환경 사실이 아니라 **배선 결함**입니다. `skipped` 로 적으면 사용자가
「codex 가 없는 환경이었구나」로 읽습니다.

`$CODEX_YAML` 은 **성공 마커 양성 요구**로 읽습니다 — `codex_failed: false` 가 **있어야**
정상입니다. 「`codex_failed: true` 가 없는지」만 보면 그 술어에 fail-closed 보수가 없어
파일 부재·0바이트·직전 라운드 잔존이 전부 「정상」으로 읽힙니다. `codex_avail` 은
pre-flight **부재**만 잡고, 아래 칸은 러너 자체의 **런타임 실패**라 서로 다른 사실입니다.

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
