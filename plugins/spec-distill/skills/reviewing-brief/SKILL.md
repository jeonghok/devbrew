---
name: reviewing-brief
description: >
  Use this skill to review an interview brief produced by conducting-interview with the shared
  document-review engine. It runs the brief's entry gates (check_brief.py gate ·
  check_verbatim_coverage.py), assembles the payload+audit bundle, runs engine rounds with the
  brief profile (snapshot → kill switch → detection → codex → anonymize → re-critique →
  freeze-check and routing → gate) inside a single turn, then a cold readback, and returns the
  gate result to the interview's Step B proceed gate.
cost_class: medium
user-invocable: false
---

# reviewing-brief — 문서 리뷰 엔진의 brief 자리

이 skill 은 진입 껍데기다. 한 라운드의 절차는 공유 엔진이 갖고 있고, 여기 남는 것은 이 자리의
것 — 호출자 계약 · 진입 게이트 · 번들 · 프로필 · dispatch 둘 · 게이트 · 냉독 · degrade 채널 — 뿐이다.

## 입력

호출자 `conducting-interview` 종료 Step A.5 가 두 값을 인자로 넘긴다. 훅은 이 자리에 없으므로 이
둘이 계약의 전부다.

- `$PAYLOAD` — 구조 게이트를 막 통과한 payload. 엔진의 `--doc`(init · snapshot · 얼림 검사 ·
  finalize)이 이것이다 — 저자가 고치는 파일이고 프로필의 앵커가 이 파일의 절을 가리킨다.
- `$AUDIT` — 그 payload 의 audit sidecar(`<payload>.audit.md`). §6 원문 `S2` 이상이 여기 산다.

인자 없이 들어왔으면(직접 호출) loud advisory 를 내고 두 경로를 사용자에게 확인한다. 상대경로는
`$(pwd)` 를 붙여 절대로 만든다 — 엔진은 상대 `--doc` 을 `doc_not_absolute` 로 거부한다.

```bash
PR="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}"
case "${PAYLOAD:-}" in ""|/*) ;; *) PAYLOAD="$(pwd)/$PAYLOAD" ;; esac
case "${AUDIT:-}" in ""|/*) ;; *) AUDIT="$(pwd)/$AUDIT" ;; esac
harness_sid="$(python3 "$PR/scripts/state_path.py" session-id || true)"
ROOT="$(python3 "$PR/scripts/state_path.py" state-root || true)"
STATE="${harness_sid:+$ROOT/$harness_sid/state.local.md}"   # degrade 원장 — 세션의 한 파일
STATE_DIR="$(python3 "$PR/scripts/docreview_state.py" state-dir-for --root "$ROOT" --session "$harness_sid" --doc "${PAYLOAD:-}" || true)"   # 엔진 상태 — 이 payload 만의 디렉토리
BUNDLE="${STATE_DIR:+$STATE_DIR/brief-bundle.md}"
```

엔진 상태(`$STATE_DIR`, 원장은 그 안의 `docreview-state.md`)는 **문서별**이다 — 세션과 payload 경로의
순수 함수라 같은 payload 는 다시 불려도 같은 자리로 돌아와 라운드·재리뷰 상한이 이어지고, 같은
세션의 다른 문서(design doc 자리의 것 포함)는 다른 자리로 간다. 세션 id 를 못 풀었거나 `$PAYLOAD` 가
비면 `$STATE_DIR` 이 비고 선결 `init` 이 `state_dir_missing` 으로 멈춘다. **선결의 `init` 이 rc 0 이
아니면 값과 무관하게 이 라운드를 진행하지 않는다** — `begin-round` 는 문서를 보지 않으므로,
`state_doc_mismatch` 같은 거부를 넘어 진행하면 다른 문서의 원장 위에서 라운드가 돈다. degrade 원장
`$STATE` 는 엔진 원장과 다른 파일이다. 진입 게이트보다 먼저 연다(`init` 은 부재 키만 추가한다):

```bash
DEGRADE_FALLBACK_FILE="${harness_sid:+$ROOT/$harness_sid/brief-degrade-fallback.txt}"
touch "${DEGRADE_FALLBACK_FILE:-/nonexistent/brief-degrade}" 2>/dev/null \
  || DEGRADE_FALLBACK_FILE="${TMPDIR:-/tmp}/brief-degrade-fallback.${harness_sid:-nosid}.txt"
init_rc=0; python3 "$PR/scripts/brief_review_state.py" init "$STATE" || init_rc=$?
```

`init_rc != 0` 이면 그 자리에서 loud advisory(`[spec-distill] brief 리뷰 degrade 원장 기록 불가
(<reason>) — 이 세션의 record 는 두 번째 채널로만 Step B 에 간다`)를 내고 계속한다 — 기록이 없는 것과
degrade 가 없는 것은 다른 사실이다.

## kill switch

전부 dispatch 직전에 확인하고 캐시하지 않는다. 발화한 스위치는 `## degrade 채널` 로 공시한다.

- `DEVBREW_SPEC_DISTILL_DISABLE=1` → 진입하지 않는다(상태 보존).
- `DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW=1` → 리뷰 전체 skip. record(`pipeline` / `all` /
  `skipped`)를 남기고 loud advisory 후 Step B 로 돌아간다 — 조용히 건너뛰지 않는다:

  > `[spec-distill] brief 리뷰 SKIPPED (DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW=1) — 엔진 라운드·냉독 전부 미검증. Step B 게이트에서 확인하세요.`

- `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1` → codex 만 끈다(아래 codex 게이트가 집행한다). 탐지·재비판은 그대로.
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` → 이 자리에서 끄는 것은 codex 의 웹 검색이다(`## 절차` 의 「웹」).
- `DEVBREW_SPEC_DISTILL_DISABLE_RECRITIC=1` → 재비판만 끈다.

record 의 필드는 `component` · `affected_axis` · `verification_status` · `reason` 넷이고(이 문서의
`a` / `b` / `c` 표기가 앞의 셋이다), 종료 코드를 그 자리에서 잡아 실패하면 두 번째 채널 — Bash 도구는
호출마다 새 셸이라 누산기는 파일이어야 Step B 까지 산다 — 에 이어 붙인다:

```bash
python3 "$PR/scripts/brief_review_state.py" degrade-append "$STATE" --component <a> --axis <b> --status <c> --reason "<r>" \
  || echo "- (state 기록 실패) component=<a> axis=<b> status=<c> reason=<r>" >> "$DEGRADE_FALLBACK_FILE"
```

## 진입 게이트 — 매 라운드, 번들보다 먼저

엔진은 게이트를 통과한 문서만 받는다. 저자 수정이 게이트를 깨뜨릴 수 있으므로 **라운드마다** 1단계
앞에서 돈다(첫 라운드 포함 — 이 skill 은 호출자를 거치지 않고도 들어올 수 있다). 파이프를 걸지
않는다 — `$?` 가 파이프 마지막 명령의 코드가 된다.

```bash
gate_rc=0; python3 "$PR/scripts/check_brief.py" gate "$PAYLOAD" || gate_rc=$?
if [ "$gate_rc" -ne 0 ]; then
  echo "[spec-distill] 구조 게이트 미통과 — 이 라운드를 시작하지 않는다 (Law 1). failures 를 고치고 이 절부터 다시 탄다." >&2
  exit 1
fi
vc_rc=0; python3 "$PR/scripts/check_verbatim_coverage.py" "$PAYLOAD" "$STATE" "$AUDIT" || vc_rc=$?
if [ "$vc_rc" -eq 1 ]; then
  echo "[spec-distill] §6 원문 완전성 위반 — 이 라운드를 시작하지 않는다. 아래 표대로 고치고 이 절부터 다시 탄다." >&2
  exit 1
fi
```

| `vc_rc` | 뜻 | 동작 |
|---|---|---|
| `0` | 위반 없음 | 번들로. **단 `advisories` 가 비어 있지 않으면** 그 줄들을 record(`verbatim_coverage` / `completeness` / `degraded`)로 남긴다 — 「이 발화는 대조하지 못했다」가 사람에게 닿지 않으면 강등이 통과로 보인다 |
| `1` | 위반(`missing_ids`/`not_contained`) | **차단.** audit §6 에 **추가만** 해서 보완하고 이 절을 다시 탄다 |
| `1` + `not_contained: ["§6"]` | 구조 위반(§6 `S<N>` 앵커 중복) | **차단.** append 로는 못 고친다 — 잘못 추가된 중복 항목을 **제거**한다 |
| `3` | 검사 불가(파일 부재·파싱 실패) | record(`verbatim_coverage` / `completeness` / `skipped`) 후 계속 |
| `4` | 내부 오류 | `3` 과 같다 + 오류 전문을 `--reason` 에 |
| 그 외 non-zero | 예측 못 한 실패 | `3` 과 같다 — indeterminate ≠ clean |

## 프로필

```bash
PROFILE="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/references/docreview-profiles/brief.md"
```

호출자가 모드를 싣지 않으므로 이 자리의 프로필은 이것 하나다.

## 번들 — 라운드마다 한 번

충실도의 정답은 payload §6(`S1`)과 audit §6(`S2` 이상) 둘이라, 탐지·재비판의 `<document>` 와 codex
러너의 `<doc>` 에는 payload 가 아니라 **번들**(`build_brief_bundle.py` 가 payload + audit 원문을 조립한
한 문서)을 넘긴다. 진입 게이트 뒤에서 라운드마다 한 번 조립해 `$BUNDLE` 파일로 둔다 — 한 라운드의
소비자 셋이 같은 바이트를 보고, 저자 수정 뒤 다음 라운드는 새 번들을 본다.

```bash
if [ -z "${STATE_DIR:-}" ] || ! mkdir -p "$STATE_DIR" 2>/dev/null; then
  echo "[spec-distill] 엔진 상태 디렉토리를 만들 수 없다('${STATE_DIR:-}') — 이 라운드를 시작하지 않는다. 해소: DEVBREW_SPEC_DISTILL_SESSION_ID 로 sid 를 명시하라." >&2
  exit 1
fi
blob_rc=0; python3 "$PR/scripts/build_brief_bundle.py" "$PAYLOAD" "$AUDIT" > "$BUNDLE" || blob_rc=$?
if [ "$blob_rc" -ne 0 ] && [ "$blob_rc" -ne 3 ]; then
  rm -f "$BUNDLE" 2>/dev/null || : > "$BUNDLE" 2>/dev/null || true
  echo "[spec-distill] 번들 조립 실패(rc $blob_rc) — 이 라운드를 시작하지 않는다." >&2
  exit 1
fi
```

`blob_rc == 2`(payload·audit 부재 · 읽기 실패 · audit 에 `## 6. 사용자 원문` 없음)와 표에 없는 코드는
같은 처리다: 번들을 지워(못 지우면 비워) 다음 셸이 직전 라운드 번들을 이번 것으로 집지 못하게 하고,
record(`pipeline` / `all` / `unavailable`) 후 Step B 로 돌아간다 — 원문 없이 충실도를 물으면 「왜곡
없음」이 공허하게 나온다. `blob_rc == 3` 은 번들의 payload 부분에 audit 파일명이 남았다는 뜻이다 —
원문 보존이 우선이라 지우지 않고 record(`critic` / `fidelity` / `degraded`) 후 계속한다.

## 절차

```
Read ${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/references/reviewing-document.md
```

그 파일의 여덟 단계를 **한 턴 안에서** 돈다. 절차를 여기 복사하지 않는다. 이 자리의 슬롯:

- `--state-dir` = `$STATE_DIR` · `--profile` = `$PROFILE` · `--doc` = `$PAYLOAD`
- 탐지·재비판의 `<document>` = `$BUNDLE` 의 내용 · codex 러너의 `<doc>` = `$BUNDLE`
- 결정 기록의 `--log-file` = `$AUDIT` — 프로필 `decision_log` 이 audit 의 `## 8. 리뷰 결정` 을 가리킨다

상한은 그 문서가 정하는 **재리뷰 상한 2** 다. 이 자리의 지출 통제가 그것이다 — 라운드 4 이상은
사용자가 승인 게이트에서 자기 문구로 열어야만 돈다.

4단계 codex 는 이 자리의 리터럴 게이트다. 조건을 산문으로 적지 않는다 — 산문 조건은 집행되지 않고,
kill switch 는 P21 보안 컨트롤이라 그 공백은 "껐다고 믿게만" 만든다.

<!-- codex-gate:begin runner=run_docreview_codex_reviewer.sh -->
```bash
SD="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}"
# `## 프로필` 과 같은 한 줄 — Bash 도구는 호출마다 새 셸이라 앞 펜스의 대입이 여기로 오지 않는다.
PROFILE="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/references/docreview-profiles/brief.md"
# 러너 인자 넷(프로필 · 번들 · 프로젝트 · 산출물)이 이 호출 안에서 선다. `$CODEX_YAML`·`$BUNDLE` 은
# `$STATE_DIR`(세션과 payload 의 순수 함수) 안의 파일이라 `## 입력` 과 같은 도출로 어느 셸에서나
# 같은 파일이다. `## 입력` 을 앞에 이어 붙여 한 호출로 도는 것이 정상 경로다.
case "${PAYLOAD:-}" in ""|/*) ;; *) PAYLOAD="$(pwd)/$PAYLOAD" ;; esac
if [ -z "${CODEX_YAML:-}" ]; then
  harness_sid="${harness_sid:-$(python3 "$SD/scripts/state_path.py" session-id || true)}"
  ROOT="${ROOT:-$(python3 "$SD/scripts/state_path.py" state-root || true)}"
  STATE_DIR="${STATE_DIR:-$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$ROOT" --session "$harness_sid" --doc "${PAYLOAD:-}" || true)}"
  if [ -n "$STATE_DIR" ] && mkdir -p "$STATE_DIR" 2>/dev/null; then
    CODEX_YAML="$STATE_DIR/docreview-codex.yaml"
  fi
fi
BUNDLE="${BUNDLE:-${STATE_DIR:+$STATE_DIR/brief-bundle.md}}"
# ── 잔존물 중화는 가용성 판정보다 «앞» 이다. 근거는 절차서 4단계의 불릿 넷 — 판별자는 내용이 아니라
# 시점이고, 중화는 시도가 아니라 보장이며(못 지우면 절단, 둘 다 못 하면 codex 축을 끈다), 러너 뒤에는
# rc 3 만 치운다. 이 줄들을 아래 `if` 의 참 분기 안으로 옮기면 codex 를 건너뛴 라운드(kill switch ·
# 미설치 · 감지기 부재 · 게이트 입력 부재)가 직전 라운드의 판정을 이번 것으로 남긴다. 앞 블록의
# `set -e` 가 따라와도 죽지 않도록 실패할 수 있는 명령은 rc 를 삼키거나 잡는다.
residue_unclear=0; residue_left=""
neutralise() {   # 지운다 — 못 지우면 0바이트로 절단한다. 둘 다 못 하면 rc 1
  rm -f "$1" 2>/dev/null || true
  if [ -e "$1" ]; then
    : > "$1" 2>/dev/null || true
    if [ -s "$1" ]; then return 1; fi
  fi
  return 0
}
if [ -n "${CODEX_YAML:-}" ]; then
  neutralise "$CODEX_YAML" || { residue_unclear=1; residue_left="$CODEX_YAML"; }
elif [ -n "${harness_sid:-}" ] && [ -n "${ROOT:-}" ]; then
  # 문서를 모르면 이 세션의 문서별 codex 산출물 전부가 후보다 — design doc 자리의 것도 같은
  # `docreview/` 아래라 함께 중화되고, 그 자리의 같은 분기도 이 자리의 것을 중화한다. **전제: 한
  # 세션은 리뷰 라운드를 동시에 둘 돌리지 않는다** — 동시에 도는 라운드가 방금 쓴 판정을 지우기
  # 때문이다. 지우는 것은 `docreview-codex.yaml` 뿐이고 엔진 원장·번들·degrade 원장은 건드리지 않는다.
  for y in "$ROOT/$harness_sid"/docreview/*/docreview-codex.yaml; do
    [ -e "$y" ] || continue
    neutralise "$y" || { residue_unclear=1; residue_left="${residue_left:+$residue_left }$y"; }
  done
fi
DETECT_OUT="$(bash "$SD/scripts/detect_codex.sh")" || true
codex_avail="$(printf '%s\n' "$DETECT_OUT" | sed -n 's/^codex_available: //p')"
skip_reason="$(printf '%s\n' "$DETECT_OUT" | sed -n 's/^skip_reason: //p')"
# 감지기가 안 돈 것과 codex 가 없는 것을 가른다 — 정상 실행된 감지기는 늘 codex_available: 줄을 낸다.
if [[ -z "$codex_avail" ]]; then skip_reason="detector_not_runnable"; fi
# `$PAYLOAD` 는 호출자 인자라 디스크에서 도출되지 않고, 번들은 진입 게이트를 통과한 라운드에만 있다 —
# 셋 중 하나라도 없으면 소리를 내고 codex 없이 간다(빈 채로 러너에 넘기면 사유가 남지 않는다).
if [[ -z "${PAYLOAD:-}" || -z "${CODEX_YAML:-}" || ! -s "${BUNDLE:-}" ]]; then
  echo "[spec-distill] codex 게이트 입력 부재 — PAYLOAD='${PAYLOAD:-}' CODEX_YAML='${CODEX_YAML:-}' BUNDLE='${BUNDLE:-}'. 「## 입력」 블록을 이 펜스 앞에 이어 붙여 같은 Bash 호출 안에서 돌리고, 「## 번들」 이 이번 라운드 번들을 조립했는지 확인하라. 이 라운드의 codex 축은 없이 간다." >&2
  codex_avail=""; skip_reason="gate_inputs_missing"
fi
# 진입 중화가 실패했으면 그 사실이 다른 어떤 사유보다 앞선다.
if [[ "$residue_unclear" == "1" ]]; then
  echo "[spec-distill] codex 산출물 경로를 비우지 못했다 — 지우지도 절단하지도 못했다: ${residue_left}. 이 라운드의 codex 축은 없이 간다. 5단계의 --codex 에 이 경로를 넘기지 마라 — 이번 라운드의 1단계 begin-round 가 rc 0 으로 끝났다면 prepare-recritic 이 이 파일을 부재(codex_predates_round)로 읽지만, 그 전제가 없으면 직전 라운드의 codex finding 이 이번 라운드 판정으로 섭취된다. 해소: 그 파일을 직접 지우거나 상태 디렉토리의 쓰기 권한을 복구하라." >&2
  codex_avail=""; skip_reason="residue_unclearable"; CODEX_YAML=""
fi
if [[ "$codex_avail" == "true" ]]; then
  runner_rc=0
  bash "$SD/scripts/run_docreview_codex_reviewer.sh" "$PROFILE" "$BUNDLE" "$(pwd)" "$CODEX_YAML" || runner_rc=$?
  # rc 3 은 러너가 산출물을 못 쓰고 죽어 호출 전 것이 남은 자리다. `-ne 0` 으로 넓히면 EXIT 트랩이
  # 원래 실패의 rc 를 단 채 남긴 이번 라운드의 정직한 기록을 지운다.
  if [[ "$runner_rc" -eq 3 ]]; then rm -f "$CODEX_YAML" || true; fi
else
  echo "[spec-distill] codex co-review SKIPPED (reason: ${skip_reason:-unknown}) — Claude-only, 이 리뷰에는 모델 다양성도 외부 웹 근거도 없었다 (degraded)." >&2
fi
```
<!-- codex-gate:end -->

**웹 — Claude 쪽 근거가 없다.** 탐지·재비판 agent 둘은 `tools: Read, Grep, Glob` 뿐이다. 프로필의
`web: true` 를 소비하는 것은 codex 러너 하나다 — 러너가 프로필 frontmatter 의 `web:` 을 읽어 codex 웹
검색을 켜고, `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 이면 끈다. 그래서 이 스위치가 이 자리의 리뷰에서 끄는
것은 codex 의 웹 검색 하나이고(진입 게이트의 `check_brief.py` 도 같은 스위치로 §4 sentinel 하나를
완화하며 자기 advisory 로 공시한다), codex 가 없는 라운드에는 외부 근거가 0 이다. 그 사실은
`## degrade 채널` 의 웹 줄로 매번 공시한다.

## dispatch 블록 둘

3단계 탐지 — `${DOCUMENT}` 에는 이번 라운드 `$BUNDLE` 의 **내용**을 싣는다(경로가 아니다 — 정답이
원문이라 외부 정보가 오염원이다). 한 번 dispatch 하고 출력을 요약·전사 없이 verbatim 파일
(`critic.txt`)로 저장한다. 파싱은 `docreview_route.py` 가 그 파일에서 한다.

```
Agent({
  description: "Document review detection (layer 1 then layer 2)",
  subagent_type: "spec-distill:doc-critic",
  // **처분** — consumer=plugins/spec-distill/scripts/docreview_route.py · fail-closed
  prompt: "<document>${DOCUMENT}</document>
    <profile>${PROFILE}</profile>
    <prior_finding_ids>${PRIOR_FINDING_IDS}</prior_finding_ids>"
})
```

6단계 재비판 — 입력 슬롯은 **정확히 셋**이다: 같은 번들 내용 · `prep.json` 의 `items`(출처 라벨 없음)
· 프로필. dispatch 사유도, 이전 대화도, 어느 리뷰어가 냈는지도 넣지 않는다 — 알면 판단이 그
프레이밍을 흡수한다. 출력은 verbatim 파일(`recritic.txt`)로.

```
Agent({
  description: "Framing-blind re-critique of the finding list",
  subagent_type: "spec-distill:doc-recritic",
  // **처분** — consumer=plugins/spec-distill/scripts/docreview_route.py · fail-open
  prompt: "<document>${DOCUMENT}</document>
    <findings>${FINDINGS}</findings>
    <profile>${PROFILE}</profile>"
})
```

## 수정 권한

프로필이 엔진에 싣는 것(`fix_anchors` §0·§2 · `protected_headings` §1 · `immutable` §6)에 더해 저자 규칙 셋:

| 자리 | 규칙 |
|---|---|
| payload §2 제약 | frontmatter `user_sourced_items` 와 **같은 write** 에서 고친다 — 게이트의 bijection 이 statement 까지 대조해 한쪽만 고치면 다음 라운드 진입 게이트가 red 다 |
| payload §6 (`S1`) | **불변** — 어떤 처분도 닿지 못한다 |
| audit §6 (`S2` 이상) | **append-only** — `S<N>` 추가만. 기존 본문을 고칠 수 있으면 「지적에 맞게 원문을 고쳐 통과」 라는 laundering 이 열린다 |

채택된 `decide` 가 사용자의 확정 방향을 뒤집으면(층 1) 적용은 절차서 `## 배달` 의 permit 계약대로
하고, 그 결정 발화를 audit §6 에 새 `S<N>` 으로 **추가**한다(state `user_statements` 에도) — 다음
라운드의 완전성 검사가 그것을 대조한다. 재결정은 근거와 사용자의 게이트 선택으로만 일어난다 — 반증은
보고의 근거이지 임의 변경의 근거가 아니다. 저자는 어느 finding 도 임의로 기각하지 못한다 —
`drop`·재비판 `reject` 는 엔진 회계에 남아 개수가 공시되고, 미반영 findings 는 이유와 함께 Step B 로 넘긴다.

## 게이트

엔진 8단계의 `docreview_state.py gate --state-dir "$STATE_DIR" --render` 가 어느 게이트인지 정한다.
`round_gate_needed` 면 라운드 게이트(결정 묶음 + 차단 `ask`, 렌더 순서)를 **`AskUserQuestion` 최대 4개씩
연속 호출**로 나눠 띄운다 — 도구가 호출당 질문을 4개로 제한하고, 한 결정을 다른 결정의
질문에 묶으면 그 결정의 선택지가 사라지기 때문이다. 매 호출 첫 질문의 첫 줄은 렌더 첫 줄(degrade
공시)과 같다. 응답을 `decide`·`fix`·`ask` 서브커맨드로 반영한다. `approval_gate_open` 이면 승인
게이트다. 열린 것이 남아 있으면 두 단계다(**1단계는 라운드 게이트와 같은 형태라 같은 분할이
적용된다**). **상한 도달이면 열린 것이 0 이어도 항상 두 단계다** — 그때 1단계는 열린 것의 유무로
갈린다: **열린 것이 0 이면 1단계 선택지는 「추가 라운드 1회 열기」와 「진행 옵션으로」 둘뿐인
질문 하나다.** **열린 것이 있으면 그 열린 항목들과 함께 「추가 라운드 1회 열기」가 별개 항목으로
렌더 순서 맨 끝에 서고, 같은 4개씩 분할에 함께 세어지며, 선택지 「열기 / 열지 않음」 둘뿐인 그
자신의 질문이다**(열린 항목을 마저 처리하는 것과는 독립적으로 고른다 — 다른 항목의 질문에
얹지 않는다). 「추가 라운드 1회 열기」를 고르면 다음 라운드가 진입 게이트부터 다시 돌고, 그 1단계가
`begin-round --extra-approval "<사용자 자신의 문구>"` 로 돈다.

**승인 게이트 2단계(진행 옵션 넷)는 이 skill 이 띄우지 않는다.** 진행 결정은 호출자
`conducting-interview` 종료 Step B 의 몫이다 — 같은 공통 계약(`proceed-gate.md`)을 쓰는 그 게이트가
확정 후보와 함께 한 번에 묻는다. 1단계가 닫히면(두 단계가 아니면 승인 게이트에 도달한 그 시점에)
`## 냉독` 을 돌리고 `## Step B 로 돌아간다` — 1단계의 「진행 옵션으로」가 그 전환이다.

- **finding 은 hard gate 다**(충실도·방향성 둘 다) — 미적용·상향된 `fix` 나 열린·채택만 된 `decide` 가 하나라도
  남으면 승인 게이트가 열리지 않는다(상한·stagnation 전 — 엔진의 `approval_ready`). 상한에 닿으면 열린 채로
  1단계에 서고 사용자가 판정한다 — 조용히 통과로 바뀌지 않는다.
- **라운드 게이트에서 턴이 끝나면**(사용자 미응답) 엔진 원장이 라운드마다 저장돼 있어 재진입(이 skill 의
  수동 재호출)이 그 라운드부터 잇는다. 이 자리에는 arm 원장이 없어 치울 in-flight 표시가 없다.
- **critic 사망이 두 번**이면 승인 게이트를 「미검증」으로 열고 그 라벨을 그대로 Step B 로 넘긴다.
- **polite stop 금지 (AP2)** — 이 skill 을 끝내는 모든 경로는 게이트 결과를 싣고 Step B 로 돌아가거나,
  게이트를 거치지 않는 예외 경로(kill switch · 진입 게이트 차단 · 번들 실패)면 명시적 advisory 단락을
  동반한다. 조용한 종료는 금지다.

## 냉독 — 엔진 밖, advisory

`brief-readback` 은 리뷰가 아니라 가독성 **측정**이라 finding 계약 밖이다 — 출력은 라우팅되지 않고
Step B 텍스트에 advisory 로 붙는다. 문서가 더 이상 바뀌지 않는 시점, 곧 마지막 라운드의 게이트
1단계가 닫힌 뒤 한 번 돈다. 하류가 읽는 것이 payload 이므로 번들이 아니라 payload 만 싣는다.

```bash
blob_rc=0; BLOB="$(python3 "$PR/scripts/build_brief_inline_blob.py" "$PAYLOAD")" || blob_rc=$?
```

`blob_rc == 2`(payload 부재 · 읽기 실패)와 그 외 non-zero 는 `2`와 동일하게 취급 — dispatch 하지 않고
record(`readback` / `readback` / `unavailable`)를 남긴다(빈 문서의 냉독은 그럴듯한 무내용 요약을 낸다).
`blob_rc == 3` 이면 본문에 audit 파일명이 남아 있다 — dispatch 하되 gap 판정을 **신뢰도 하향**으로 읽는다.

```javascript
Agent({
  description: "Brief cold readback",
  subagent_type: "spec-distill:brief-readback",
  // **처분** — consumer=human · fail-open · disclosure=verification_status
  prompt: `Read this document cold and say back, in plain prose, what you
understood: what it is trying to do, what is settled and what is still open, and
what happens next. Nothing else.

<document>
${BLOB}
</document>`
})
```

프롬프트에 판정 기준·출력 형식·검사 항목을 **주지 않는다** — 형식 자체가 오염원이다. 출력이 비거나
실패하면 record(`readback` / `readback` / `unavailable`)를 남긴다 — 「gap 0」으로 읽지 않는다.

받은 산문 요약을 payload 의 §0/§1/§2/§3/§7 과 대조해 gap 을 분류한다. **닫힌 여섯 클래스**다:

| # | gap 클래스 | 판정 |
|---|---|---|
| G1 | **미결을 확정으로 읽음** — §3 OQ 항목을 결정된 것으로 요약 | 요약에 그 OQ 가 결정으로 등장 |
| G2 | **확정을 미결로 읽음** — `status: confirmed` 항목을 열린 것으로 요약 | 요약에 그 제약이 미결/후보로 등장 |
| G3 | **최상위 제약 누락** — 최상위 항목의 내용이 요약에 없음 | 해당 id 의 내용이 요약에 부재 |
| G4 | **Goal ↔ Non-goal 반전** — §1 의 Non-goal 을 goal 로(또는 역) 요약 | 방향이 뒤집힌 서술 존재 |
| G5 | **다음 행동 오독** — §7 Next Action 과 다른 다음 단계를 서술 | 요약의 next step ≠ §7 |
| G6 | **상태 표기와 본문 서술의 불일치** — 같은 항목을 frontmatter/표와 본문 산문이 다르게 말함 | 요약이 두 서술 중 한쪽만 담고, 나머지가 payload 에 그대로 있음 |

G1–G6 **전부 0건**이면 readback pass. 1건 이상이면 그 항목을 **세 조각**으로 넘긴다 — *어느 클래스 /
요약의 어느 문장 / payload 의 어느 절*. 판정은 advisory 다: 프레시 에이전트는 잘못 재구성된 payload 도
정확히 요약할 수 있어 hard verdict 로 쓰면 false block 이 난다. 일곱 번째 클래스가 관측되면 이 표에 더한다.

## Step B 로 돌아간다

`conducting-interview` 종료 Step B 의 proceed 게이트에 셋을 싣는다:

1. **엔진 게이트 결과** — 마지막 `gate --render` 전문 · 승인 게이트에 도달한 사유(열린 것 없음 · 상한 ·
   stagnation · 「미검증」) · 1단계에서의 사용자 선택 · 열린 채 남은 항목(`ask`·`decide`)과 미반영
   findings 목록(각각 이유와 함께).
2. **냉독 요약 전문 + gap 목록**(세 조각), 또는 냉독이 돌지 못한 사유.
3. **degrade** — 아래 채널 전부를 한 줄씩.

## degrade 채널

이 skill 의 degrade 채널은 이름이 다섯이다:

- 엔진의 셋 — `fin.json` 의 `advisory[]`(codex 부재 · critic 층 2 부재 · recritic 부재 · 처분 회계의
  degrade 사유) · `fin.json` 의 `blocks`(막는 것만: critic 사망 · 항목 소실 · 셀 수 없음) ·
  `docreview_state.py gate --render` 의 **첫 줄**(그 라운드의 degrade 한 줄).
- 이 자리의 둘 — `brief_review_state.py get "$STATE"` 의 `brief_review_degradations`(진입 게이트 강등 ·
  번들 위생 미달 · 냉독 실패 · BRIEF_REVIEW skip · 원장 기록 불가처럼 엔진 밖의 사건) · 그 기록이
  실패했을 때의 `$DEGRADE_FALLBACK_FILE` 줄들.

그리고 매번 싣는 한 줄 — `웹: Claude 쪽 없음 · codex <켜짐 | 꺼짐(DISABLE_WEB) | codex 부재>`.

Step B 게이트를 띄우기 **직전에** 이 채널들을 읽어 하나도 빠뜨리지 않고 게이트 `question` 텍스트에
싣는다. 전부 비었을 때만 `degrade 없음` 이다 — 그 문구는 **채널을 실제로 읽었다는 주장**이므로 읽지
않은 채 쓰지 않는다. `get` 이 실패하면(`ok: false`) 원장은 비어 있는 것이 아니라 **알 수 없는** 것이므로
`degrade 원장 판독 불가 — <get 이 낸 reason>` 을 한 줄로 쓴다.
