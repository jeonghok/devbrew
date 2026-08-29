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

1. **원문 보존** — 사용자가 준 원문(요청·생각·대화 로그·자료)을 **`$AUDIT` 파일의
   `## 1. 원문` 절**에 그대로 옮겨 적습니다(append-only — 이후 라운드의 원문도 요약하지
   않고 계속 덧붙입니다). `$AUDIT` 경로와 이 skill 이 **무엇을 만들고 무엇을 만들지
   않는지**는 `## 상태` 한 곳에 있습니다 — 여기서 다시 세지 않습니다. 지금 요약하지 않습니다 —
   압축은 나중 단계이고, 지금 요약하면 압축이 무엇을 떨어뜨렸는지 audit 이 못 남깁니다.
   `## 1. 원문` 이라는 헤딩은 장식이 아닙니다: `build_seed_inline_blob.py` 가 그 절을
   정규식으로 잘라 억제 리뷰 번들에 싣습니다.
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

**이 skill 이 만드는 것의 전부입니다** — 다른 절은 이 목록을 다시 세지 않습니다.

| 만드는 것 | 어디에 | 언제 |
|---|---|---|
| audit (`$AUDIT`) | `docs/superpowers/interview/` | `## 확산` 1번부터 — append-only |
| interview-seed (`$SEED`) | 〃 | 압축 직후 — **게이트 직전 구조 검사보다 먼저** |
| 억제 축 작업 파일 둘 (`$PAYLOAD` · `$CODEX_YAML`) | 아래 `$SEED_DIR` | 검증 라운드마다 |
| 두 문서의 이름을 붙드는 `interview-basename` | 〃 | 아래 블록에서 `TOPIC` 자리표가 실값으로 치환된 실행 — 자리표가 그대로면 만들지 않는다 |
| 세션 디렉토리 `$SEED_DIR` 자체 | `.claude/spec-distill/<session-id>/` | 〃 |

**audit 과 seed 는 시점이 다르지만, 둘 다 승인 «전»에 디스크에 있어야 합니다.** audit 은
확산 첫 항목부터, seed 는 압축 직후입니다 — 게이트 직전의 `check_seed.py` 가 둘 다
디스크에서 읽고, proceed 게이트 공통 계약의 Step A 도 대상 문서가 working-tree 에 없으면
게이트를 **띄우지 않습니다**. 승인 이후에 일어나는 것은 파일 쓰기가 아니라 **handoff**
입니다 — seed 본문을 다음 세션 첫 턴에 붙여넣는 것.

**만들지 않는 것: `state.local.md`.** degrade 원장은 그 **기존** 파일 안에 살고, 없으면
없는 채로 갑니다(§`degrade 채널` 의 `no-state-in-phase-0`).

```bash
SD="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}"
sid="$(python3 "$SD/scripts/state_path.py" session-id)" || sid=""
ROOT="$(python3 "$SD/scripts/state_path.py" state-root)"
STATE="$ROOT/$sid/state.local.md"
# 억제 축의 두 작업 파일. 경로는 **세션의 순수 함수**여야 한다 — 어느 블록이 언제
# 재도출해도 같은 파일을 가리켜야 하기 때문이다. `mktemp` 은 `$$`(PID) 와 **같은 결함**
# 이다: Bash 도구는 호출마다 새 셸이라 그 값이 소멸하고 **재발견이 불가능**하다.
# 세션 «디렉토리»는 만들어도 된다 — state.local.md 를 만드는 것과 다른 일이다.
SEED_DIR="$ROOT/${sid:-nosid}"
mkdir -p "$SEED_DIR" 2>/dev/null || SEED_DIR="${TMPDIR:-/tmp}/spec-distill-${sid:-nosid}"
mkdir -p "$SEED_DIR" 2>/dev/null
PAYLOAD="$SEED_DIR/seed-suppression-bundle.md"
CODEX_YAML="$SEED_DIR/seed-suppression-codex.yaml"
# 두 산출 문서. 이름은 **첫 라운드에 한 번** 정하고 이후 라운드는 되찾는다 — 그래서
# 이 블록을 다시 돌리면 같은 두 경로가 나온다. 이름을 기억에서 다시 대는 판본은
# `mktemp` 과 같은 결함이다: 다음 셸이 같은 값을 다시 만들 수 있어야 한다.
# `TOPIC` 을 요청의 주제(kebab-case)로 바꿔 쓴다. **바꾸기 전에는 이름을 고정하지
# 않는다** — 고정해 버리면 자리표가 파일명에 박히고, 그 뒤로는 「이 블록을 다시
# 돌려라」가 바로 그 박제를 되풀이하는 행동이 된다.
TOPIC="<kebab-topic>"
NAME_FILE="$SEED_DIR/interview-basename"
case "$TOPIC" in
  ""|*"<"*|*">"*|*/*) : ;;
  *) [ -s "$NAME_FILE" ] || printf '%s-%s-interview\n' "$(date +%F)" "$TOPIC" > "$NAME_FILE" ;;
esac
# 이름이 성하지 않으면 두 경로를 **만들지 않는다.** 반쯤 만들어진 경로
# (`docs/superpowers/interview/.audit.md`)는 아래 가드들의 `-z` 검사를 통과해 조용히
# 틀린 파일을 가리킨다 — 시끄럽게 틀리는 것보다 그쪽이 나쁘다. 비워 두면 가드가
# 이름을 대고 멈춘다.
AUDIT=""
SEED=""
IV_NAME="$(head -n 1 "$NAME_FILE" 2>/dev/null)"
case "$IV_NAME" in
  ""|*/*|*"<"*|*">"*)
    echo "[spec-distill] 인터뷰 문서 이름을 못 구했다 (IV_NAME='$IV_NAME'). 이 블록의 TOPIC 을 요청 주제(kebab-case)로 바꿔 다시 돌려라. 자리표가 이미 이름에 박혔으면 rm -f '$NAME_FILE' 로 지운 뒤 다시 돌려라 — 그 파일이 이름의 유일한 출처이므로 지우면 되돌아간다." >&2 ;;
  *)
    AUDIT="docs/superpowers/interview/$IV_NAME.audit.md"
    SEED="docs/superpowers/interview/$IV_NAME.md" ;;
esac
if [ -n "$sid" ] && [ -f "$STATE" ]; then
  python3 "$SD/scripts/brief_review_state.py" init "$STATE" --ledger-key framing_degradations; ledger_rc=$?
else
  ledger_rc=1
fi
```

**이 블록이 경로의 유일한 도출 지점입니다.** `$SD`·`$sid`·`$ROOT`·`$STATE`·`$SEED_DIR`·
`$PAYLOAD`·`$CODEX_YAML`·`$AUDIT`·`$SEED` 은 전부 환경과 `$SEED_DIR` 의 순수 함수이므로,
셸이 바뀌었으면 **이 블록을 다시 돌려** 같은 값을 얻습니다. 아래 어느 블록도 이 값들을
새로 만들지 않습니다 —
`mktemp` 으로 만들면 다음 `Bash` 호출이 그 파일을 다시 찾지 못하고, `$CODEX_YAML` 을
읽어야 하는 하류 단계가 통째로 수행 불가능해집니다.

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

경로는 `## 상태` 에서 이미 도출했습니다. 여기서 새로 만들지 않습니다.

```bash
# 게이트 쪽과 같은 가드다. 이 펜스가 `## 상태` 없이 새 셸에서 돌면 네 변수가 다 비는데,
# 가드가 없으면 `: No such file or directory` 로 죽어 **어느 변수가 비었는지도, 어느
# 블록을 다시 돌려야 하는지도** 말하지 않는다. 관측값을 실어 이름을 댄다.
if [[ -z "${SD:-}" || -z "${SEED:-}" || -z "${AUDIT:-}" || -z "${PAYLOAD:-}" ]]; then
  echo "[spec-distill] 재료 조립 입력 부재 — SD='${SD:-}' SEED='${SEED:-}' AUDIT='${AUDIT:-}' PAYLOAD='${PAYLOAD:-}'. 「## 상태」 블록을 먼저 돌려라. 번들이 없으면 두 담당 모두 돌리지 않는다." >&2
  blob_rc=2
else
  python3 "$SD/scripts/build_seed_inline_blob.py" "$SEED" "$AUDIT" CLAUDE.md > "$PAYLOAD"; blob_rc=$?
  [ "$blob_rc" -eq 0 ] && cat "$PAYLOAD"
fi
```

**마지막 `cat` 이 `${BLOB}` 의 출처입니다.** 이 블록의 출력에 번들 전문이 그대로 나오고,
아래 critic dispatch 는 그 출력을 인라인합니다. 경로를 넘기는 선택지는 없습니다 —
`seed-critic` 은 `tools: []` 이라 파일을 읽을 도구가 물리적으로 없습니다. codex 는 같은
파일을 `$PAYLOAD` 인자로 받습니다: **한 파일, 두 전달 방식.** `cat` 이 없으면 두 담당이
같은 번들을 본다는 이 절의 주장에 수행 경로가 없어집니다(조립기 stdout 은 파일로
리다이렉트되므로 그것만으로는 아무 데도 안 보입니다).

`blob_rc` 가 0 이 아니면 번들이 없는 것이므로 **두 담당 모두** 돌리지 않고, 그 사실을
`component: pipeline` · `affected_axis: suppression` · `verification_status: unavailable`
로 남깁니다.

### 억제 리뷰 — 격리 critic

```javascript
Agent({ description: "Seed suppression critique", subagent_type: "spec-distill:seed-critic",
        prompt: `초안 · 원문 · 레포 CLAUDE.md 를 전문 inline 으로 받는다. 네 축만 본다.
<draft>${BLOB}</draft>` })
// **처분** — consumer=human · fail-open · disclosure=framing_degradations
```

`${BLOB}` 은 위 조립 블록이 `cat` 으로 낸 출력 그대로입니다 — 요약하거나 다시 조립하지
않습니다. 그것이 codex 가 `$PAYLOAD` 로 받는 파일과 같은 내용이라는 것이 「두 담당이 같은
재료를 본다」의 전부입니다.

**뺄셈 검사입니다.** 「좋은 프롬프트냐」는 묻지 않습니다 — 그건 취향이고 비평자에게는
사용자의 도메인 지식이 없습니다.

### 억제 리뷰 — codex

억제 축의 **세 번째 담당**입니다. 러너는 `DEVBREW_SPEC_DISTILL_DISABLE_CODEX` 를 스스로
보지 않습니다 — 게이트는 **호출자 책임**이고 그 호출자가 여기입니다.

조건을 **산문으로 적지 않습니다.** 문장으로 「가용할 때만」이라 적고 bash 펜스는 무조건
실행되게 둔 판본이 형제 skill 에 실제로 있었고, 그 파일에는 `codex_avail` 을 검사하는
`if` 가 아예 없었습니다. kill switch 는 P21 보안 컨트롤이라 그 상태는 「껐다고 믿게만」
만듭니다.

**이 축의 전부가 한 실행입니다** — 감지 · 게이트 · 호출 · 판정 · 노출이 한 블록에
있습니다. 쪼개면 안 됩니다. 판정과 노출이 다른 `Bash` 호출로 가면 그 호출은
`$CODEX_YAML` 을 **다시 도출해서** 읽는데, 그 자리에 있는 파일이 이번 라운드 것이라는
근거가 그 호출에는 없습니다 — 지난 라운드 파일도 `codex_failed: false` 를 달고 있으므로
낡은 성공과 신선한 성공이 같은 모양입니다.

**한 블록 안에서는 그 상태가 만들어질 수 없고, 그것이 규율이 아니라 형태에서 도출됩니다.**
블록의 **첫 줄**이 그 경로를 지우고 **마지막 줄**이 같은 실행의 같은 바인딩으로 읽습니다.
그 둘 사이에 무엇을 새로 넣든 — 오늘 없는 분기를 포함해 — 그 사이에서 그 파일을 만들 수
있는 것은 이 실행뿐입니다. 클리어가 첫 줄이므로 그 **앞**에도 자리가 없습니다. 경로가
비어 있으면 클리어도 읽기도 **같은 빈 값**에 대한 no-op 이라 `degraded` 로 떨어집니다:
한쪽만 건너뛰는 상태가 없습니다.

**그러므로 `$CODEX_YAML` 을 읽는 곳은 이 블록 하나뿐입니다.** 다른 절에 그 파일을 읽는
펜스를 추가하지 마십시오. 그리고 **이 블록을 두 펜스로 쪼개지 마십시오** — 마커 사이가
한 펜스일 때만 하니스의 이어붙임 모델이 `Bash` 도구의 실행 모델(펜스마다 새 셸)과
일치합니다. 쪼개고 판정·노출을 뒤 펜스로 옮기면 하니스에는 아무 변화가 없는데 실제로는
지난 라운드 산출물이 다시 새어 나옵니다.

`tests/test_seed_gate_wiring.sh` 가 **동작으로 잡는 것은 둘**입니다 — 마커 사이의 bash
펜스가 하나가 아닌 것, 그리고 게이트 블록 밖 bash 펜스에 `$CODEX_YAML` 을 그 이름 그대로
읽는 줄이 있는 것. **잡지 못하는 것**도 적어 둡니다(전부 실측): 경로를 조각으로 재조립해
읽기 · 글롭으로 읽기 · ` ```sh ` 처럼 다른 언어표기를 단 펜스 · 들여쓴 펜스 · bash 가
아니라 산문으로 「그 파일을 읽어라」라고 시키기. 어휘로 닫히는 것들이 아니므로 이 다섯은
**락이 아니라 규율로** 지킵니다.

<!-- codex-gate:begin runner=run_seed_codex_reviewer.sh -->
```bash
# ── 진입 클리어 — 블록의 «첫 줄» ────────────────────────────────────────────
# 첫 줄인 것이 요점이다: 이 앞에는 어떤 분기도 들어갈 자리가 없다. 경로가 세션의 순수
# 함수라 라운드마다 같은 파일이고, 지우지 않으면 직전 라운드 YAML 이 그대로 남는다 —
# 그 파일은 양성 마커를 달고 있을 수 있어 skip 분기(kill switch 포함)와 3 이 아닌 실패
# rc 에서 「이번 라운드 codex 가 정상이었다」로 읽힌다. 이 줄과 블록 «끝»의 읽기가 한
# 쌍이고, 그 사이에 무엇을 몇 개 넣든 읽기가 보는 파일은 이 실행이 만든 것이다.
# 한쪽을 옮기면 그 쌍이 깨진다.
[[ -n "${CODEX_YAML:-}" ]] && rm -f "$CODEX_YAML"
SD="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}"
DETECT_OUT="$(bash "$SD/scripts/detect_codex.sh")"
codex_avail="$(printf '%s\n' "$DETECT_OUT" | sed -n 's/^codex_available: //p')"
skip_reason="$(printf '%s\n' "$DETECT_OUT" | sed -n 's/^skip_reason: //p')"
# 정상 실행된 감지기는 false 일 때도 `codex_available:` 줄을 내고 exit 0 한다. 그 줄이
# 없으면 감지기 자체가 안 돈 것이다(끊긴 심볼릭 링크·빈 stdout) — 「codex 가 없다」와
# 구별해서 적는다. 뭉개면 사용자가 이유 없는 SKIPPED 만 본다.
if [[ -z "$codex_avail" ]]; then skip_reason="detector_not_runnable"; fi
# 두 경로는 `## 상태` 가 도출한다. 이 블록이 그 도출 없이 새 셸에서 돌면 값이 비고,
# 그대로 두면 러너가 빈 경로를 받아 payload_missing 으로 **조용히** degrade 한다 —
# 침묵이 결함이다. 여기서 잡아 소리를 내고 가용 판정을 덮어쓴다.
if [[ -z "${PAYLOAD:-}" || -z "${CODEX_YAML:-}" ]]; then
  echo "[spec-distill] codex 억제 게이트 입력 부재 — PAYLOAD='${PAYLOAD:-}' CODEX_YAML='${CODEX_YAML:-}'. 「## 상태」 블록을 먼저 돌려 두 경로를 도출해라. 이 라운드의 억제 축은 codex 없이 간다." >&2
  codex_avail=""; skip_reason="gate_inputs_missing"
fi
if [[ "$codex_avail" == "true" ]]; then
  bash "$SD/scripts/run_seed_codex_reviewer.sh" suppression "$PAYLOAD" "$(pwd)" "$CODEX_YAML"; runner_rc=$?
  # exit 3 은 「산출물 자체를 못 썼다」이다. 이 경로는 세션의 순수 함수라 **라운드마다
  # 같은 파일**이므로, 그때 직전 라운드 YAML 이 디스크에 그대로 남아 이번 라운드 판정으로
  # 읽힌다 — 그 파일은 양성 마커(codex_failed: false)를 달고 있을 수 있어 「이번에 codex 가
  # 정상이었다」로 읽힌다. 지운다.
  if [[ "$runner_rc" -eq 3 ]]; then rm -f "$CODEX_YAML"; fi
else
  echo "[spec-distill] codex 억제 co-review SKIPPED (reason: ${skip_reason:-unknown}) — 격리 critic 단독, 이 축에 모델 다양성이 없었다 (degraded)." >&2
fi
# ── 판정과 노출 — 진입 클리어의 짝. 같은 실행, 같은 바인딩 ──────────────────
# 러너는 파일에만 쓴다. 그 파일을 여기서 읽어야 degrade 판정과 findings 노출이 일어난다.
# **성공 마커 양성 요구**로 읽는다 — 파일 부재·0바이트·잘림·`codex_failed: true` 가 전부
# 같은 degraded 로 떨어진다. 경로가 비면 `[ -s "" ]` 도 `cat ""` 도 실패하므로 위 클리어와
# 같은 no-op 이 되고, 어느 경우에도 판정 한 줄은 나온다.
if [ -s "${CODEX_YAML:-}" ] && grep -q 'codex_failed: false' "${CODEX_YAML:-}"; then
  codex_status=ok
else
  codex_status=degraded
fi
echo "codex_status: $codex_status"
cat "${CODEX_YAML:-}" 2>/dev/null || echo "(codex 산출물 없음)"
```
<!-- codex-gate:end -->

**축은 죽지 않습니다** — 격리 critic 이 남습니다. 위 stderr advisory 는 사용자에게 그대로
노출하고, 원장이 살아 있으면(`ledger_rc == 0`) 같은 사실을 `framing_degradations` 에도
남깁니다. 원장이 없으면 그 사실은 proceed 게이트 질문 텍스트로만 갑니다(§`degrade 채널`).

블록의 stdout 이 사용자가 보는 전부입니다. `codex_status` 가 degrade 표 셋째 행의
입력이고, `cat` 출력의 `findings:` 항목이 codex 의 raw findings 이며 격리 critic 의 것과
**나란히** 갑니다 — 병합기가 없고 판정도 없습니다(§`degrade 채널`).

### 냉독

```javascript
Agent({ description: "Seed cold readback", subagent_type: "spec-distill:seed-readback",
        prompt: `아래 seed 만 읽고 «내가 이해한 것은 이것이다» 를 산문으로 말하라.
<seed>${SEED}</seed>` })
// **처분** — consumer=human · fail-open · disclosure=framing_degradations
```

**싱크됐는지는 사용자가 읽고 판정합니다.** 에이전트가 통과·미달을 내면 어긋남의 감각이
사용자에게 오지 않습니다. 세 리뷰(격리 critic · codex · 냉독)의 raw 출력은 **사용자에게
직접** 갑니다 — orchestrator 는 판정하지도 병합하지도 않습니다. degrade 가 있으면 그것은
`## degrade 채널` 의 채널 둘로 나갑니다(원장은 있을 때만, 게이트 텍스트는 항상).

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

**딸린 상호작용 하나** — `## 상태` 가 `$SEED_DIR` 을 만들므로, 원래 세션 디렉토리가 없었을
세션에도 디렉토리와 파일 둘이 생깁니다. 그 둘은 `gc_common.py` 의 TTL-GC 관할에 들어갑니다:
폴더 나이가 **직속 파일들의 최신 mtime** 으로 계산되므로 이 두 파일이 그 나이를 정하고,
TTL(기본 24시간, env override) 을 넘기면 폴더가 통째로 걷힙니다. 결함으로 실증된 것은
아니지만 배선 이전에는 없던 상호작용이라 여기 적어 둡니다.

codex 가 죽으면 record 하나가 남고 격리 critic 이 단독으로 돕니다. **억제 축은 판정에
합류하지 않습니다** — findings 는 어떤 병합기도 거치지 않고 사용자에게 직접 갑니다.

codex 축의 record 는 게이트 블록이 낸 값으로 정합니다. `--component codex --axis
suppression` 은 세 경우 모두 같고 갈리는 것은 `--status` 와 `--reason` 입니다.
**위에서부터 먼저 맞는 행**을 씁니다:

| 관측 | `--status` | `--reason` |
|---|---|---|
| `skip_reason` 이 `gate_inputs_missing` | `unavailable` | 게이트 입력 부재 — 「`## 상태`」가 돌지 않아 `$PAYLOAD`·`$CODEX_YAML` 이 비었다 |
| `codex_avail` 이 `true` 가 아니다 | `skipped` | `$skip_reason` 값 그대로 |
| `codex_avail` 이 `true` 였는데 `$CODEX_YAML` 에 `codex_failed: false` 가 없다 | `degraded` | `$runner_rc` + 관측한 사실(파일 부재·0바이트·잘림·`true`) |

첫 행이 둘째 행보다 먼저인 이유: 게이트 입력 부재는 `codex_avail` 을 덮어써서 둘째 행에도
맞지만, 그것은 환경 사실이 아니라 **배선 결함**입니다. `skipped` 로 적으면 사용자가
「codex 가 없는 환경이었구나」로 읽습니다.

`$CODEX_YAML` 은 **성공 마커 양성 요구**로 읽습니다 — `codex_failed: false` 가 **있어야**
정상입니다. 「`codex_failed: true` 가 없는지」만 보면 그 술어에 fail-closed 보수가 없어
파일 부재·0바이트·잘림이 전부 「정상」으로 읽힙니다.

**직전 라운드 잔존은 이 술어가 못 가릅니다.** 지난 라운드의 파일도 `codex_failed: false`
를 달고 있을 수 있고, 그러면 양성 요구는 만족됩니다 — 신선한 성공과 낡은 성공이 이
술어에게는 같은 모양입니다. 그것을 막는 것은 술어가 아니라 **블록의 형태**입니다:
진입 클리어와 마지막 읽기가 한 실행 안에 있으므로 술어가 보는 파일은 그 실행이 만든
것뿐입니다. 두 장치가 각각 다른 것을 막습니다 — 술어는 *이 실행의 실패*를, 클리어-읽기
쌍은 *다른 실행의 성공*을. 이 축의 판정과 노출을 게이트 블록 밖으로 옮기면 그 쌍이
깨지고, 술어 혼자서는 낡은 성공을 가릴 수 없습니다.

`codex_avail` 은 pre-flight **부재**만 잡고, 표 아래 칸은 러너 자체의 **런타임 실패**라
서로 다른 사실입니다.

## 확정 — proceed 게이트

공통 계약의 정본은 `${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md` 입니다. 4옵션
게이트를 띄우고, 게이트 질문 텍스트에 degrade 를 **하나도 빠뜨리지 않고** 싣습니다.
seed 파일은 이 게이트 **이전에** 디스크에 있어야 합니다 — 아래 구조 검사도, 공통 계약의
Step A 도 그것을 읽습니다. 승인이 여는 것은 파일 쓰기가 아니라 handoff 입니다.

게이트를 띄우기 **직전에** 구조 검사를 돌립니다:

```bash
python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/check_seed.py" \
  gate "$SEED" "$AUDIT"; seed_rc=$?
if [ "$seed_rc" -ne 0 ]; then
  echo "[spec-distill] seed 게이트 위반 — 위 항목을 고치고 다시 이 블록부터 탑니다. 게이트를 띄우지 않습니다." >&2
fi
```

`check_seed.py` 가 재는 다섯 중 셋(답-슬롯 헤딩·태그·URL)은 seed 본문 **슬롯** 부재
검사입니다. 나머지 둘은 존재 검사이되 범위가 다릅니다 — 하나(check 0)는 seed 본문
**전체**가 비어 있지 않은지만 보고, 다른 하나는 audit 쪽 `## 1. 원문` 절(유일한 슬롯
존재 검사)입니다. **seed 본문에 슬롯 존재 검사를 추가하지 마십시오** — 그것이 이
payload 를 양식으로 만드는 유일한 경로이고, `tests/test_seed_one_sentence.sh` 가 그
금지를 동작으로 잡습니다.

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
