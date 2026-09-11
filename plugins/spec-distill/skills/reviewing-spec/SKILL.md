---
name: reviewing-spec
description: >
  Use right after superpowers:brainstorming writes and commits a design doc
  (docs/superpowers/specs/...-design.md), before superpowers:writing-plans — this review replaces
  brainstorming's user-review gate. Pass the design doc path as the argument. Runs the shared
  document-review engine with the design-doc profile (snapshot → detection → codex → anonymize →
  re-critique → freeze-check and routing → gate) inside a single turn and closes with the shared
  proceed gate. Design-mode only — the interview brief has its own reviewers (reviewing-brief).
cost_class: medium
---

# reviewing-spec — 문서 리뷰 엔진의 design doc 자리

이 skill 은 진입 껍데기다. 한 라운드의 절차는 공유 엔진이 갖고 있고, 여기 남는 것은 이 자리의
것 — 진입 검사 · 입력 · 프로필 · dispatch 둘 · 게이트 · degrade 채널 — 뿐이다.

## 진입 검사

이 skill 에서 **맨 먼저** 한 번 돈다 — 인자 해석·후보 제시보다, 엔진 라운드보다 앞이다. 끄기 판정은
이 펜스가 하고, 산문은 펜스 출력의 **마지막 줄**(판결)만
읽는다 — 조건을 산문으로 적지 않는다. 산문 조건은 집행되지 않고, kill switch 는 P21 보안 컨트롤이라
그 공백은 "껐다고 믿게만" 만든다.

<!-- review-entry:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}"; [ -n "$SD" ] || SD="./plugins/spec-distill"
ENTRY="$SD/scripts/review_entry.py"
RETURN_MSG="[spec-distill] 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트)."
if [ ! -f "$ENTRY" ]; then
  block="$(printf '%s\n' "[spec-distill] 진입 검사 실패(끔으로 친다) — 모듈 부재: $ENTRY" "review-entry: DISABLED:entry_check_failed")"
else
  entry_err="$(mktemp 2>/dev/null || printf '/dev/null')"
  entry_out="$(python3 "$ENTRY" 2>"$entry_err")"; entry_rc=$?
  entry_err_1="$(tail -n 1 "$entry_err" 2>/dev/null)"
  [ "$entry_err" != /dev/null ] && rm -f "$entry_err"
  if [ "$entry_rc" -ne 0 ]; then
    block="$(printf '%s\n' "[spec-distill] 진입 검사 실패(끔으로 친다) — $ENTRY rc=$entry_rc: $entry_err_1" "review-entry: DISABLED:entry_check_failed")"
  else
    block="$(printf '%s' "$entry_out" | python3 -c '
import json, sys
sys.stdout.reconfigure(encoding="utf-8")
raw = sys.stdin.buffer.read().decode("utf-8", "replace")
try:
    d = json.loads(raw)
except ValueError:
    d = None
ok = (isinstance(d, dict)
      and isinstance(d.get("disabled"), bool)
      and "reason" in d
      and (d["reason"] is None or isinstance(d["reason"], str))
      and not (isinstance(d["reason"], str) and ("\n" in d["reason"] or "\r" in d["reason"]))
      and isinstance(d.get("advisories"), list)
      and all(isinstance(a, str) and "\n" not in a and "\r" not in a for a in d["advisories"]))
if not ok:
    print("[spec-distill] 진입 검사 실패(끔으로 친다) — 출력이 계약(JSON 객체 · disabled boolean · reason 문자열|null · advisories 문자열 배열 · 개행 없음)을 어긴다: " + raw[:120].replace("\n", " "))
    print("review-entry: DISABLED:entry_check_failed")
    sys.exit(0)
for a in d["advisories"]:
    print(a)
if d["disabled"]:
    print("[spec-distill] 설계문서 리뷰가 꺼져 있다 — " + (d["reason"] or "disabled"))
    print("review-entry: DISABLED:" + (d["reason"] or "disabled"))
else:
    print("review-entry: PROCEED")
')" || block="$(printf '%s\n' "[spec-distill] 진입 검사 실패(끔으로 친다) — 출력 계약 검사기 자체가 실패했다" "review-entry: DISABLED:entry_check_failed")"
  fi
fi
verdict="$(printf '%s\n' "$block" | tail -n 1)"
case "$verdict" in
  "review-entry: PROCEED"|"review-entry: DISABLED:"?*) ;;
  *) verdict="review-entry: DISABLED:entry_check_failed" ;;
esac
printf '%s\n' "$block" | sed '$d'
[ "$verdict" = "review-entry: PROCEED" ] || printf '%s\n' "$RETURN_MSG"
printf '%s\n' "$verdict"
```
<!-- review-entry:end -->

마지막 줄이 정확히 `review-entry: PROCEED` 일 때만 `## 입력` 을 거쳐 `## 절차` 로 간다.
그 밖이면 — `review-entry: DISABLED:<사유>` — 펜스가 낸 `[spec-distill]` 줄(끈 스위치 또는 실패 사유 ·
advisory · 복귀 지시)을 **그대로** 한 단락으로 보이고 게이트 없이 끝난다(그 단락의 마지막 문장이 복귀
지시다). 정본 `proceed-gate.md` 의 kill switch 예외 경로다. `PROCEED` 여도 `[spec-distill]` 줄(은퇴
스위치 공시)이 있으면 그대로 보인다.

끄는 스위치는 셋이고 셋 다 이 skill 을 직접 불러도 끈다: `DEVBREW_SKIP_HOOKS=spec-distill:review-entry`
· `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` · 플러그인 전체 `DEVBREW_SPEC_DISTILL_DISABLE=1`. 진입
검사 자신이 실패하면(모듈 부재 · rc≠0 · 출력 계약 위반 · 검사기 자체 실패) 끔으로 친다.

## 입력

`$spec_path` 는 **호출 인자**다 — `Skill spec-distill:reviewing-spec <설계문서 경로>` 또는
`/spec-distill:reviewing-spec <경로>`. 상대 경로면 리포 루트 기준 절대 경로로 바꿔 쓴다.

인자가 없으면 후보를 뽑아 `AskUserQuestion` 으로 고르게 한다 — 설계문서(`-design.md`)를 추가한 최근
커밋 50개에서 나온 것 중 최신 5개와 untracked 전부:

<!-- review-candidates:begin -->
```bash
top="$(git rev-parse --show-toplevel)"
git -C "$top" -c core.quotePath=false log -n 50 --diff-filter=A --name-only --pretty=format: -- 'docs/superpowers/specs/*-design.md' | awk 'NF && !seen[$0]++' | head -n 5 | sed "s|^|$top/|"
git -C "$top" -c core.quotePath=false ls-files --others --exclude-standard -- 'docs/superpowers/specs/*-design.md' | sed "s|^|$top/|"
```
<!-- review-candidates:end -->

후보가 없거나 사용자가 고르지 않으면 아래 「대상 부재」로 끝낸다.

세션 상태 디렉토리는 `state_path.py` 리졸버로 연다 — 엔진 상태(`docreview-state.md`)와 codex
산출물이 여기 산다:

```bash
harness_sid="$(python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/state_path.py" session-id)"
ROOT="$(python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/state_path.py" state-root)"
STATE_DIR="$ROOT/$harness_sid"
if [ -z "$harness_sid" ] || [ -z "$ROOT" ]; then
  STATE_DIR=""
  echo "[spec-distill] 세션 상태 디렉토리를 특정할 수 없다(session id 또는 state root 미해석) — 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트)."
fi
```

그 줄이 나오면 게이트 없이 끝낸다 — 아래 `### 대상 부재` 와 같은 출구다.

### 대상 부재 — 게이트 없이 끝나는 경로 (정본 Step A)

`$spec_path` 가 working-tree 에 없거나(삭제된 워크트리 경로 등) 인자 없이 불려 후보를 고르지
않았으면 게이트를 띄우지 않고 이 문면 그대로 끝낸다. 승인 게이트 직전에도 같은 확인을 한 번 더
한다.

> `[spec-distill] current_spec '<path>' 부재 (working-tree 에 없거나 후보를 고르지 않았다) — handoff 진행 안 함. 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트).`

## 프로필

```bash
PROFILE="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/references/docreview-profiles/design-doc.md"
```

프로필은 `design-doc.md` 로 **고정**이다 — 이 skill 은 design 자리 전용이고 다른 프로필을 고르지 않는다.

## 절차

```
Read ${CLAUDE_PLUGIN_ROOT}/references/reviewing-document.md
```

그 파일의 여덟 단계를 **한 턴 안에서** 돈다. 절차를 여기 복사하지 않는다 — 네 자리가 같은 절차를
쓰기 때문에 공유 정본에 두는 것이다. `--state-dir` 는 위 `$STATE_DIR` 이고, 상한은 그 문서가 정하는
**재리뷰 상한 2** 다(라운드 4 이상은 사용자가 승인 게이트에서 열어야만 돈다).

4단계 codex 는 이 자리의 리터럴 게이트다. 조건을 산문으로 적지 않는다 — 산문 조건은 집행되지 않고,
kill switch 는 P21 보안 컨트롤이라 그 공백은 "껐다고 믿게만" 만든다.

<!-- codex-gate:begin runner=run_docreview_codex_reviewer.sh -->
```bash
SD="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}"
# `## 프로필` 과 **같은 한 줄**이다. Bash 도구는 호출마다 새 셸이라 앞 펜스의 대입이 여기로
# 오지 않는다 — `SD=` 를 펜스마다 다시 세우는 것과 같은 이유다.
PROFILE="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/references/docreview-profiles/design-doc.md"
# 러너의 네 인자 중 둘은 이 펜스가 대입하지 않았었다. 같은 이유(새 셸)로 여기서 함께
# 세운다 — `$CODEX_YAML` 은 세션의 **순수 함수**라 어느 셸에서 다시 도출해도 같은 파일을
# 가리킨다(`## 입력` 의 `$STATE_DIR` 과 같은 자리다. `mktemp` 은 `$$` 와 같은 결함이다 —
# 다음 호출이 그 파일을 재발견하지 못한다). 이미 값이 있으면 그것을 쓴다: `## 입력` 을
# 이 펜스 앞에 이어 붙여 한 호출로 도는 것이 정상 경로이고, 그때 두 번 도출하지 않는다.
if [ -z "${CODEX_YAML:-}" ]; then
  harness_sid="${harness_sid:-$(python3 "$SD/scripts/state_path.py" session-id)}"
  ROOT="${ROOT:-$(python3 "$SD/scripts/state_path.py" state-root)}"
  if [ -n "$harness_sid" ] && mkdir -p "$ROOT/$harness_sid" 2>/dev/null; then
    CODEX_YAML="$ROOT/$harness_sid/docreview-codex.yaml"
  fi
fi
# ── 잔존물 제거는 **여기**다 — 가용성 판정보다 «앞». ─────────────────────────
# 이 경로는 세션의 순수 함수라 라운드마다 같은 파일이다. 직전 라운드가 성공했으면 그
# YAML 은 `codex_failed: false` 를 달고 있고, 5단계 `prepare-recritic` 은 그 마커 하나로
# 이 파일을 **이번 라운드의 판정**으로 읽는다 — 직전 라운드의 finding 을 이번 것으로
# 삼키고 `codex_absent: false`, degrade 없음으로 보고한다.
# 위험한 자리는 **codex 를 건너뛴 라운드**다: kill switch·미설치·감지기 부재·게이트 입력
# 부재 — 넷 다 아래 `if` 의 참 분기에 들어가지 않으므로, 그 안에만 제거가 있으면 넷 다
# 잔존물을 그대로 남긴다. 그 결과가 「사용자가 codex 를 껐는데 모델 다양성 정상으로
# 보고되는 라운드」다. 끈 것이 꺼진 것으로 보이지 않는 switch 는 없는 것보다 나쁘다(P21 —
# kill switch 는 보안 컨트롤이다).
# **판별자는 파일의 내용이 아니라 시점이다.** 직전 라운드의 산출물과 이번 라운드의 정직한
# 실패 기록은 스키마도 마커도 같아서 내용으로는 못 가른다(둘 다 이 러너가 쓴 같은 형식이고,
# 어느 필드도 라운드를 담지 않는다). 진입에서 지우면 그 뒤 그 자리에 있는 것은 **이 실행이
# 쓴 것**뿐이다 — 러너가 `trap … EXIT`·`emit_fallback` 으로 남기는 이번 라운드의 degrade
# 기록(`codex_failed: true` + 실제 사유)은 이 지움 **뒤에** 쓰이므로 살아남아 하류에 사유를
# 그대로 전한다. 이 줄을 아래 분기 안으로 옮기면 그 보장이 깨진다.
# **그리고 지움은 «시도» 가 아니라 «보장» 이어야 한다.** rc 를 보지 않으면 이 블록은
# 무조건형으로 적어 놓고 조건부로 동작한다 — 실측: 상태 디렉토리가 쓰기 불가면 `rm` 은
# rc 1 로 실패하고 파일이 살아남아, kill switch 를 켠 라운드가 직전 라운드 finding 을
# 그대로 삼킨다(수정 전 결함의 완전 재현). unlink 는 **디렉토리** 권한을, 절단은 **파일**
# 권한을 요구하므로 둘은 함께 실패하지 않는다 — 그래서 지우지 못하면 0바이트로 절단한다.
# 0바이트는 하류에서 이미 fail-closed 다(실측: `codex_absent: true`). 둘 다 실패하면
# 조용히 넘어가지 않고 아래에서 codex 축을 **끈다**.
residue_unclear=0
if [ -n "${CODEX_YAML:-}" ]; then
  rm -f "$CODEX_YAML" 2>/dev/null
  if [ -e "$CODEX_YAML" ]; then
    : > "$CODEX_YAML" 2>/dev/null
    [ -s "$CODEX_YAML" ] && residue_unclear=1
  fi
fi
DETECT_OUT="$(bash "$SD/scripts/detect_codex.sh")"
codex_avail="$(printf '%s\n' "$DETECT_OUT" | sed -n 's/^codex_available: //p')"
skip_reason="$(printf '%s\n' "$DETECT_OUT" | sed -n 's/^skip_reason: //p')"
# "감지기를 못 돌렸다"와 "codex가 없다"를 구별한다: 정상 실행된 감지기는 항상 exit 0 이고
# codex_available: 줄을 낸다(false 여도). 그 줄이 없으면 감지기 자체가 안 돈 것이다 —
# skip_reason: unknown 으로 뭉개지 않는다.
if [[ -z "$codex_avail" ]]; then skip_reason="detector_not_runnable"; fi
# `$spec_path` 는 호출 인자(`## 입력`)라 디스크에서 도출되지 않는다 — 값이 없으면 소리를
# 내고 이 라운드의 codex 축을 건너뛴다(러너에 빈 인자를 넘기면 usage rc 2 로 죽는다). 잔존물은
# 위 진입 중화가 이미 지웠다.
if [[ -z "${spec_path:-}" || -z "${CODEX_YAML:-}" ]]; then
  echo "[spec-distill] codex 게이트 입력 부재 — spec_path='${spec_path:-}' CODEX_YAML='${CODEX_YAML:-}'. 「## 입력」 블록을 이 펜스 앞에 이어 붙여 같은 Bash 호출 안에서 함께 돌리고, spec_path 에는 이 skill 의 호출 인자(설계문서 경로)를 대입해라. 이 라운드의 codex 축은 없이 간다." >&2
  codex_avail=""; skip_reason="gate_inputs_missing"
fi
# 진입 중화가 실패했으면 그 사실이 다른 어떤 사유보다 앞선다 — 이 라운드는 codex 를
# 돌리지 않을 뿐 아니라, 하류가 그 자리의 파일을 이번 라운드 판정으로 읽으면 안 된다.
if [[ "$residue_unclear" == "1" ]]; then
  echo "[spec-distill] codex 산출물 경로를 비우지 못했다 — 지우지도 절단하지도 못했다: ${CODEX_YAML}. 그 자리의 내용이 직전 라운드 것인지 이번 실행 것인지 구별할 수 없다(판별자는 시점인데 그 보장이 사라졌다). 5단계의 --codex 에 이 경로를 넘기지 마라 — 넘기면 직전 라운드의 codex finding 이 이번 라운드 판정으로 섭취된다. 해소: 그 파일을 직접 지우거나 상태 디렉토리의 쓰기 권한을 복구하라." >&2
  codex_avail=""; skip_reason="residue_unclearable"; CODEX_YAML=""
fi
if [[ "$codex_avail" == "true" ]]; then
  bash "$SD/scripts/run_docreview_codex_reviewer.sh" "$PROFILE" "$spec_path" "$(pwd)" "$CODEX_YAML"; runner_rc=$?
  # 껍데기 정리 — 형제 `framing-requests` 와 같은 `-eq 3` 이다.
  # **앞선 판본의 `-ne 0` 은 거짓 전제 위에 있었다**: 「기록을 남기는 러너 종료는 전부
  # exit 0」이라고 적었는데 그렇지 않다. EXIT 트랩은 «자기 rc 를 갖는 종료 지점»이 아니라
  # 모든 종료에 얹히므로 **원래 실패의 rc 를 그대로 두고** 기록을 남긴다 — 실측: 트랩
  # 무장 뒤 SIGTERM 이면 `rc 143` + `reason: aborted_before_completion` 인 정직한 이번
  # 라운드 기록이 함께 나온다. `-ne 0` 은 바로 그 기록을 지운다.
  # 그리고 `-ne 0` 이 대신 막아 주는 것은 없다: 껍데기가 생기는 유일한 자리는 러너의
  # `runner_common` 미로드 + 기록 실패이고 그것은 **rc 3** 이며(rc 2 는 절단 이전이라
  # 파일 자체가 없다), 0바이트는 하류에서 이미 fail-closed 다(실측: `codex_absent: true`).
  # 넓은 술어가 사는 것은 없고 잃는 것은 정직한 사유다 — `-eq 3` 이 지배한다.
  if [[ "$runner_rc" -eq 3 ]]; then rm -f "$CODEX_YAML"; fi
else
  echo "[spec-distill] codex co-review SKIPPED (reason: ${skip_reason:-unknown}) — Claude-only, 이 리뷰에는 모델 다양성이 없었다 (degraded)." >&2
fi
```
<!-- codex-gate:end -->

`DEVBREW_SPEC_DISTILL_DISABLE=1` 은 `## 진입 검사` 펜스가 엔진 라운드 전에 걸러낸다(엔진 2단계도 한 번
더 본다). `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1` 은 codex 만 끄고 탐지 리뷰는 그대로 돈다.
`DEVBREW_SPEC_DISTILL_DISABLE_RECRITIC=1` 은 재비판만 끈다. 뒤의 둘은 dispatch 직전에 확인하고
캐시하지 않으며, 발화한 스위치는 아래 degrade 채널로 공시한다.

## dispatch 블록 둘

3단계 탐지 — 한 번 dispatch 하고 출력을 요약·전사 없이 verbatim 파일(`critic.txt`)로 저장한다.
파싱은 `docreview_route.py` 가 그 파일에서 한다.

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

6단계 재비판 — 입력 슬롯은 **정확히 셋**이다: 문서 · `prep.json` 의 `items`(출처 라벨 없음) ·
프로필. dispatch 사유도, 이전 대화도, 어느 리뷰어가 냈는지도 넣지 않는다 — 그것을 알면 판단이 그
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

## 게이트

골격 · 두 가드 · 예외 경로의 정본은 아래 파일이다. 게이트 진입 시 읽고 따른다.

```
Read ${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md
```

엔진 8단계의 `docreview_state.py gate --state-dir "$STATE_DIR" --render` 가 어느 게이트인지 정한다.
`round_gate_needed` 면 라운드 게이트(결정 묶음 + 차단 `ask`)를 `AskUserQuestion` **하나**로 띄우고
응답을 `decide`·`fix`·`ask` 서브커맨드로 반영한다. `approval_gate_open` 이면 승인 게이트이고, 열린
것이 남아 있으면 두 단계다.

승인 게이트를 띄우기 직전에 `$spec_path` 가 working-tree 에 있는지 다시 본다 — 없으면
`### 대상 부재` 문면으로 끝낸다(게이트 없음).

승인 게이트의 옵션 넷 — 정본 Step B 표를 이 skill 어휘로 채운 것이다:

| # | 이 skill 에서 |
|---|---|
| ① | 미커밋 확인 → `/compact` 후 `superpowers:writing-plans` (권장) — verbatim `/compact` 명령을 노출하고 **턴 종료** |
| ② | 미커밋 확인 → 바로 `Skill superpowers:writing-plans <path>` |
| ③ | 수정 필요 — 후속 질문으로 revise per findings / `conducting-interview` 재진입 / 사용자 직접 편집 분기 |
| ④ | 멈춤 — 상태 보존하고 종료 |

- **① 의 정지 요건** — verbatim `/compact` 명령을 노출한 자리에서 **턴 종료(STOP)** 한다. 같은 턴
  에서 `writing-plans` 를 호출하지 않는다(compact 전 진입은 옵션 ① 을 무력화한다). 진입은 사용자가
  `/compact` 를 실제로 실행한 **다음 턴**에 사용자 트리거로만 일어나고, 사용자가 redirect 하면
  미진입한다(P17).
- **polite stop 금지 (AP2)** — ①/② 를 골랐는데 narrate 만 하고 `### 미커밋 확인` 과 다음 단계
  진입을 skip 하면 polite stop 이다. 이 skill 을 종료하는 모든 경로는 이 게이트를 거치거나, 게이트를
  거치지 않는 예외 경로(`### 대상 부재` · `## 진입 검사` 의 끔)면 명시적 advisory 단락을 동반한다 —
  게이트-less silent 종료는 금지다.
- **재결정 규약 (P23)** — `decide` 처분이 인터뷰가 이미 확정한 항목을 겨냥하면 조용히 덮어쓰지
  않는다. design.md 의 재결정 기록에 *원래 / 재결정 후보 / 근거* 를 적어 다음 라운드로 들고 가고,
  확정이 실제로 뒤집히는 자리는 이 승인 게이트 하나다 — 사용자가 판정한다. 하류의 반증은 보고의
  근거이지 임의 변경의 근거가 아니다. 정본은 `proceed-gate.md` 의 「재결정 규약」 절.

### 미커밋 확인 — ①/② 직전

사용자가 진행을 고르면 다음 단계로 가기 전에 이 펜스를 돌리고, 나온 `[spec-distill]` 줄을 그대로
보인다. 진행은 막지 않는다. `$spec_path` 는 이 펜스 안에서 호출 인자로 다시 대입한다(새 셸).

<!-- uncommitted-check:begin -->
```bash
if [ -z "${spec_path:-}" ]; then
  echo "[spec-distill] 미커밋 확인 입력 부재 — spec_path 가 비었다(Bash 호출마다 새 셸이다 — 호출 인자를 이 펜스 안에서 다시 대입하라)."
else
  spec_dir="$(dirname -- "$spec_path")"
  spec_base="$(basename -- "$spec_path")"
  born_out="$(git -C "$spec_dir" status --porcelain --ignored --untracked-files=all -- "$spec_base" 2>/dev/null)"; born_rc=$?
  if [ "$born_rc" -ne 0 ]; then
    echo "[spec-distill] 커밋 여부를 확인하지 못했다(git rc=$born_rc) — '$spec_path' 가 git 작업 트리 밖이거나 git 이 실패했다. writing-plans 전에 문서가 커밋됐는지 직접 확인하라."
  elif [ -n "$born_out" ]; then
    echo "[spec-distill] 커밋되지 않은 변경(또는 미추적·ignore 된 문서)이 있다: $spec_path — writing-plans 전에 커밋하라."
  fi
fi
```
<!-- uncommitted-check:end -->

## degrade 채널

이 skill 의 degrade 채널은 엔진의 것이고 별도 원장을 만들지 않는다. 이름은 셋이다:

- `fin.json` 의 `advisory[]` — codex 부재 · critic 층 2 부재 · recritic 부재 · 처분 회계의 degrade
  사유가 전부 이 한 채널로 온다.
- `fin.json` 의 `blocks` — **막는 것**만 여기 온다: critic 사망(주 판정자) · 항목 소실 · 셀 수 없음.
- `docreview_state.py gate --render` 의 **첫 줄** — 그 라운드의 degrade 한 줄이다. codex 가 없었으면
  그 사실과 사유가, 아니면 `advisory[]` 요약이, 둘 다 비면 `degrade 없음` 이 온다. 라운드 번호와
  재리뷰 카운트는 **둘째 줄**이다(상한 도달·stagnation 도 그 줄에 붙는다).

게이트를 띄우기 **직전에** 이 셋을 읽어 하나도 빠뜨리지 않고 프로즈로 내고, 승인 게이트 질문
텍스트의 `degrade:` 슬롯에도 싣는다. 셋 다 비었을 때만 `degrade 없음` 이다 — 그 문구는 **채널을
실제로 읽었다는 주장**이므로, 읽지 않은 채 쓰지 않는다.
