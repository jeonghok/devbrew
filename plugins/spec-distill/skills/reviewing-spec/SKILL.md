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
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라 — 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트)." >&2; exit 1; }
ENTRY="$SD/scripts/review_entry.py"
RETURN_MSG="[spec-distill] 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트)."
if [ ! -f "$ENTRY" ]; then
  block="$(printf '%s\n' "[spec-distill] 진입 검사 실패(끔으로 친다) — 모듈 부재: $ENTRY" "review-entry: DISABLED:entry_check_failed")"
else
  entry_err="$(mktemp 2>/dev/null || printf '/dev/null')"
  entry_out="$(python3 "$ENTRY" 2>"$entry_err")"; entry_rc=$?
  entry_err_last="$(tail -n 1 "$entry_err" 2>/dev/null)"
  [ "$entry_err" != /dev/null ] && rm -f "$entry_err"
  if [ "$entry_rc" -ne 0 ]; then
    block="$(printf '%s\n' "[spec-distill] 진입 검사 실패(끔으로 친다) — $ENTRY rc=$entry_rc: $entry_err_last" "review-entry: DISABLED:entry_check_failed")"
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
git -C "$top" -c core.quotePath=false log -n 50 --diff-filter=A --name-only --pretty=format: -- 'docs/superpowers/specs/*-design.md' | awk 'BEGIN{FS="\037"} NF && !seen[$NF]++' | while IFS= read -r p; do [ -e "$top/$p" ] && printf '%s/%s\n' "$top" "$p"; done | head -n 5
git -C "$top" -c core.quotePath=false ls-files --others --exclude-standard -- 'docs/superpowers/specs/*-design.md' | while IFS= read -r p; do [ -e "$top/$p" ] && printf '%s/%s\n' "$top" "$p"; done
```
<!-- review-candidates:end -->

후보가 없거나 사용자가 고르지 않으면 아래 「대상 부재」로 끝낸다.

상태 디렉토리는 `state_path.py` 리졸버(세션)와 엔진의 `state-dir-for`(문서)로 연다 — 이 문서의 엔진 상태
(`docreview-state.md`)와 codex 산출물이 여기 산다:

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라 — 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트)." >&2; exit 1; }
harness_sid="$(python3 "$SD/scripts/state_path.py" session-id)"
ROOT="$(python3 "$SD/scripts/state_path.py" state-root)"
STATE_DIR="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$ROOT" --session "$harness_sid" --doc "${spec_path:-}" || true)"   # 엔진 상태 — 이 문서만의 디렉토리
if [ ! -f "$SD/scripts/state_path.py" ]; then
  STATE_DIR=""
  echo "[spec-distill] 상태 리졸버 부재: $SD/scripts/state_path.py (플러그인 루트 미해석) — 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트)."
elif [ -z "$harness_sid" ] || [ -z "$ROOT" ]; then
  STATE_DIR=""
  echo "[spec-distill] 세션 상태 디렉토리를 특정할 수 없다(session id 또는 state root 미해석) — 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트)."
fi
```

두 `[spec-distill]` 줄(상태 리졸버 부재 · 세션 상태 디렉토리 미특정) 중 하나가 나오면 게이트 없이 끝낸다 —
아래 `### 대상 부재` 의 하위 경우다.

엔진 상태(`$STATE_DIR`)는 **문서별**이다 — 세션과 문서 경로의 순수 함수
(`<state-root>/<sid>/docreview/<stem>-<해시>`)라서 같은 문서는 dispatch 를 넘어 같은 디렉토리로
돌아와 라운드와 재리뷰 상한이 이어지고, 다른 문서는 다른 디렉토리로 간다. 세션 디렉토리 하나를
여러 문서가 쓰면 둘째 문서가 첫 문서의 라운드·상한·finding 위에서 시작한다(`init` 은 그런 원장을
`state_doc_mismatch` 로 거부한다). 그러므로 `$spec_path` 를 이 블록보다 **먼저** 대입한다. 세션 id
를 못 풀었거나 `$spec_path` 가 비면 도출이 사유를 stderr 로 내고 `$STATE_DIR` 은 빈 값이다 — 선결의
`init` 이 `state_dir_missing` 으로 멈춘다. **선결의 `init` 이 rc 0 이 아니면 값과 무관하게 이 라운드를
진행하지 않는다** — `begin-round` 는 문서를 보지 않으므로, `state_doc_mismatch` 같은 거부를 넘어
진행하면 다른 문서의 원장 위에서 라운드가 돈다.

### 대상 부재 — 게이트 없이 끝나는 경로 (정본 Step A)

`$spec_path` 가 working-tree 에 없거나(삭제된 워크트리 경로 등) 인자 없이 불려 후보를 고르지
않았으면 게이트를 띄우지 않고 이 문면 그대로 끝낸다. 승인 게이트 직전에도 같은 확인을 한 번 더
한다.

> `[spec-distill] current_spec '<path>' 부재 (working-tree 에 없거나 후보를 고르지 않았다) — handoff 진행 안 함. 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트).`

## 프로필

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라 — 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트)." >&2; exit 1; }
PROFILE="${CLAUDE_PLUGIN_ROOT}/references/docreview-profiles/design-doc.md"
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
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라 — 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트)." >&2; exit 1; }
# `## 프로필` 과 **같은 두 줄**(`SD=` · `PROFILE=`)이다. Bash 도구는 호출마다 새 셸이라 앞 펜스의
# 대입이 여기로 오지 않는다 — `SD=` 를 펜스마다 다시 세우는 것과 같은 이유다.
PROFILE="${CLAUDE_PLUGIN_ROOT}/references/docreview-profiles/design-doc.md"
# 러너의 네 인자는 전부 이 호출 안에서 서야 한다. 같은 이유(새 셸)로 여기서 함께 세운다 —
# `$CODEX_YAML` 은 `## 입력` 의 `$STATE_DIR`(세션과 문서의 **순수 함수**) 안의 한 파일이라
# 어느 셸에서 다시 도출해도 같은 파일을 가리킨다. 도출은 `## 입력` 과 같은 `state-dir-for`
# 한 줄이다. `mktemp` 은 `$$` 와 같은 결함이다 — 다음 호출이 그 파일을 재발견하지 못한다.
# 이미 값이 있으면 그것을 쓴다: `## 입력` 을 이 펜스 앞에 이어 붙여 한 호출로 도는 것이
# 정상 경로이고, 그때 두 번 도출하지 않는다.
if [ -z "${CODEX_YAML:-}" ]; then
  harness_sid="${harness_sid:-$(python3 "$SD/scripts/state_path.py" session-id || true)}"
  ROOT="${ROOT:-$(python3 "$SD/scripts/state_path.py" state-root || true)}"
  STATE_DIR="${STATE_DIR:-$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$ROOT" --session "$harness_sid" --doc "${spec_path:-}" || true)}"
  if [ -n "$STATE_DIR" ] && mkdir -p "$STATE_DIR" 2>/dev/null; then
    CODEX_YAML="$STATE_DIR/docreview-codex.yaml"
  fi
fi
# ── 잔존물 제거는 **여기**다 — 가용성 판정보다 «앞». ─────────────────────────
# 이 경로는 세션과 문서의 순수 함수라 같은 문서의 라운드마다 같은 파일이다. 직전 라운드가
# 성공했으면 그 YAML 은 `codex_failed: false` 를 달고 있어 내용만으로는 이번 라운드의 판정과 구별되지
# 않는다 — 남은 파일이 5단계에서 이번 라운드의 codex 판정으로 읽히면 직전 라운드의
# finding 이 이번 것으로 삼켜지고 `codex_absent: false`, degrade 없음으로 보고된다.
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
# 그대로 전한다. 이 줄을 아래 분기 안으로 옮기면 그 보장이 깨진다. 5단계 `prepare-recritic`
# 도 같은 판별자로 라운드 시작보다 먼저 쓰인 파일을 부재로 읽지만, 그 판별은 1단계가 이번
# 라운드 시작을 기록했다는 전제 위에 있다 — 이 지움은 그 전제에 기대지 않는다.
# **그리고 지움은 «시도» 가 아니라 «보장» 이어야 한다.** unlink 는 **디렉토리** 권한을,
# 절단은 **파일** 권한을 요구한다 — 지우지 못하면 0바이트로 절단한다(0바이트는 하류에서
# fail-closed 다: `codex_absent: true`). 둘 다 막힌 조합(디렉토리·파일 모두 쓰기 불가)에서도
# 상태 파일이 쓰기 가능하면 1단계 `begin-round` 는 통과한다(상태 파일은 제자리 덮어쓰기다) —
# 그 조합의 집행은 여기가 아니라 5단계의 시점 판별이다(`codex_predates_round`). 여기서는
# 조용히 넘어가지 않고 아래에서 codex 축을 **끈다**.
# 앞 블록을 이어 붙이면 그 셸 옵션(`set -e`)도 따라온다 — 실패할 수 있는 명령은 rc 를
# 삼키거나 잡는다. 여기서 펜스가 죽으면 잔존물이 살고 SKIPPED 공시도 나지 않는다.
# **문서를 모르면**(`$spec_path` 가 비어 경로를 도출하지 못했다) 이 세션의 문서별 산출물
# 전부가 후보다 — 어느 것이 이번 라운드의 경로인지 가를 수 없으므로 전부 같은 규칙으로
# 중화한다. codex 산출물은 한 라운드의 4단계가 쓰고 5단계가 읽고 끝나는 파일이라 지워서
# 잃는 것이 없다. 게이트 입력 부재도 codex 를 건너뛴 라운드다 — 그 라운드만 잔존물을 남기면
# 위의 결함이 그 경로로 그대로 돌아온다.
# **전제: 한 세션은 리뷰 라운드를 동시에 둘 돌리지 않는다.** sweep 은 다른 문서의 codex
# 산출물까지 중화한다 — 동시에 도는 라운드가 있으면 그 라운드가 방금 쓴 판정을 지운다.
# 「잃는 것이 없다」와 이 sweep 의 fail-closed 는 이 전제 아래에서만 참이다. 지우는 것은 문서별
# 디렉토리의 `docreview-codex.yaml` 뿐이고 원장(`docreview-state.md`)·세션 원장(`state.local.md`)·
# 그 밖의 파일은 건드리지 않는다.
residue_unclear=0; residue_left=""
neutralise() {   # `$NEUTRALISE_TARGET` 을 지운다 — 못 지우면 0바이트로 절단한다. 둘 다 못 하면 rc 1
  rm -f "$NEUTRALISE_TARGET" 2>/dev/null || true
  if [ -e "$NEUTRALISE_TARGET" ]; then
    : > "$NEUTRALISE_TARGET" 2>/dev/null || true
    if [ -s "$NEUTRALISE_TARGET" ]; then return 1; fi
  fi
  return 0
}
if [ -n "${CODEX_YAML:-}" ]; then
  NEUTRALISE_TARGET="$CODEX_YAML"; neutralise || { residue_unclear=1; residue_left="$CODEX_YAML"; }
elif [ -n "${harness_sid:-}" ] && [ -n "${ROOT:-}" ]; then
  for y in "$ROOT/$harness_sid"/docreview/*/docreview-codex.yaml; do
    [ -e "$y" ] || continue
    NEUTRALISE_TARGET="$y"; neutralise || { residue_unclear=1; residue_left="${residue_left:+$residue_left }$y"; }
  done
fi
DETECT_OUT="$(bash "$SD/scripts/detect_codex.sh")" || true
codex_avail="$(printf '%s\n' "$DETECT_OUT" | sed -n 's/^codex_available: //p')"
skip_reason="$(printf '%s\n' "$DETECT_OUT" | sed -n 's/^skip_reason: //p')"
# "감지기를 못 돌렸다"와 "codex가 없다"를 구별한다: 정상 실행된 감지기는 항상 exit 0 이고
# codex_available: 줄을 낸다(false 여도). 그 줄이 없으면 감지기 자체가 안 돈 것이다 —
# skip_reason: unknown 으로 뭉개지 않는다.
if [[ -z "$codex_avail" ]]; then skip_reason="detector_not_runnable"; fi
# `$spec_path` 는 호출 인자(`## 입력`)라 디스크에서 도출되지 않는다 — 값이 없으면 소리를
# 내고 이 라운드의 codex 축을 건너뛴다(러너에 빈 인자를 넘기면 usage rc 2 로 죽는다). 잔존물은
# 위 진입 중화가 이미 지웠다. 처방은 「앞에 이어 붙여라」다 — 별개 호출로 다시 돌려도 같은
# 빈 상태가 재생산된다.
if [[ -z "${spec_path:-}" || -z "${CODEX_YAML:-}" ]]; then
  echo "[spec-distill] codex 게이트 입력 부재 — spec_path='${spec_path:-}' CODEX_YAML='${CODEX_YAML:-}'. 「## 입력」 블록을 이 펜스 앞에 이어 붙여 같은 Bash 호출 안에서 함께 돌리고, spec_path 에는 이 skill 의 호출 인자(설계문서 경로)를 대입해라. 이 라운드의 codex 축은 없이 간다." >&2
  codex_avail=""; skip_reason="gate_inputs_missing"
fi
# 진입 중화가 실패했으면 그 사실이 다른 어떤 사유보다 앞선다 — 이 라운드는 codex 를
# 돌리지 않을 뿐 아니라, 하류가 그 자리의 파일을 이번 라운드 판정으로 읽으면 안 된다.
if [[ "$residue_unclear" == "1" ]]; then
  echo "[spec-distill] codex 산출물 경로를 비우지 못했다 — 지우지도 절단하지도 못했다: ${residue_left}. 이 라운드의 codex 축은 없이 간다. 5단계의 --codex 에 이 경로를 넘기지 마라 — 이번 라운드의 1단계 begin-round 가 rc 0 으로 끝났다면 prepare-recritic 이 이 파일을 부재(codex_predates_round)로 읽지만, 그 전제가 없으면 직전 라운드의 codex finding 이 이번 라운드 판정으로 섭취된다. 해소: 그 파일을 직접 지우거나 상태 디렉토리의 쓰기 권한을 복구하라." >&2
  codex_avail=""; skip_reason="residue_unclearable"; CODEX_YAML=""
fi
if [[ "$codex_avail" == "true" ]]; then
  runner_rc=0
  bash "$SD/scripts/run_docreview_codex_reviewer.sh" "$PROFILE" "$spec_path" "$(pwd)" "$CODEX_YAML" || runner_rc=$?
  # 껍데기 정리 — 형제 `framing-requests` 와 같은 `-eq 3` 이다. `-ne 0` 은 틀리다: EXIT 트랩은
  # «자기 rc 를 갖는 종료 지점»이 아니라 모든 종료에 얹혀 **원래 실패의 rc 를 그대로 두고**
  # 이번 라운드의 정직한 기록을 남긴다 — 실측: 트랩 무장 뒤 SIGTERM 이면 `rc 143` +
  # `reason: aborted_before_completion` 인 기록이 함께 나온다. `-ne 0` 은 바로 그 기록을 지운다.
  # 그리고 `-ne 0` 이 대신 막아 주는 것은 없다: 0바이트 껍데기는 러너가 출력 경로를 절단한 뒤
  # EXIT 트랩이 기록을 끝내기 전에 죽으면 생기고, 그 죽음은 rc 하나로 좁혀지지 않는다(실측:
  # 트랩 자체가 못 뜨는 신호 종료 SIGKILL·SIGXFSZ 가 같은 껍데기를 남겼다) — 빈 파일은 하류가
  # 이미 fail-closed 로 읽는다(`codex_absent: true`). `rc 3` 이 디스크에 남기는 것은 새 껍데기가
  # 아니라 호출 전에 그 자리에 있던 것 그대로이고, 아래 `rm` 이 그것을 치운다. 넓은 술어가
  # 사는 것은 없고 잃는 것은 정직한 사유다 — `-eq 3` 이 지배한다.
  if [[ "$runner_rc" -eq 3 ]]; then rm -f "$CODEX_YAML" || true; fi
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

`${PROFILE}` 에는 경로가 아니라 **프로필 파일의 내용**을 싣는다 — 플러그인 캐시는 사용자 프로젝트 밖이라 리뷰어의
Read 가 거부된다. 탐지 dispatch 직전에(재dispatch 포함) 아래 펜스를 돌려 그 stdout 전문을 탐지와 재비판의
`<profile>` 슬롯에 싣는다. 펜스의 rc 가 0 이 아니면 dispatch 하지 않는다 — 펜스가 critic 출력 파일
(`$STATE_DIR/critic.txt`)을 비우고(`$STATE_DIR` 이 비면 건너뛴다) 5단계가 그것을 critic 사망(rc 4)으로 읽어
재dispatch 1회(이 펜스부터 다시), 또 실패면 「미검증」이다. 엔진도 라운드 시작보다 오래된 critic 파일을 부재로
읽는다(`critic_predates_round`). `$spec_path` 는 이 펜스와 **같은 Bash 호출**에서 대입한다(codex 게이트 펜스와
같다) — 새 셸에는 앞 호출의 대입이 남지 않아 `$STATE_DIR` 이 비고, 그러면 펜스는 비움을 건너뛰고 그 사실을 알린다.

<!-- profile-content:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라 — 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트)." >&2; exit 1; }
harness_sid="$(python3 "$SD/scripts/state_path.py" session-id)"
ROOT="$(python3 "$SD/scripts/state_path.py" state-root)"
STATE_DIR="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$ROOT" --session "$harness_sid" --doc "${spec_path:-}" || true)"   # 엔진 상태 — 이 문서만의 디렉토리
PROFILE="${CLAUDE_PLUGIN_ROOT}/references/docreview-profiles/design-doc.md"
prof_rc=0; PROFILE_TEXT="$(cat "$PROFILE")" || prof_rc=$?
if [ "$prof_rc" -ne 0 ] || [ -z "$PROFILE_TEXT" ]; then
  echo "[spec-distill] 프로필 내용을 읽지 못했다(cat rc $prof_rc): $PROFILE — 탐지 · 재비판을 dispatch 하지 않는다. 5단계가 critic 사망으로 읽는다(재dispatch 1회 → 「미검증」)." >&2
  if [ -n "${STATE_DIR:-}" ] && [ -d "$STATE_DIR" ]; then
    if { : > "$STATE_DIR/critic.txt"; } 2>/dev/null; then
      echo "[spec-distill] critic 출력 파일($STATE_DIR/critic.txt)을 비웠다." >&2
    else
      echo "[spec-distill] critic 출력 파일($STATE_DIR/critic.txt)을 비우지 못했다 — 5단계가 라운드 시작보다 오래된 그 파일을 부재로 읽는다(critic_predates_round)." >&2
    fi
  else
    echo "[spec-distill] critic 출력 파일을 비우지 않았다 — STATE_DIR 도출 실패(spec_path='${spec_path:-}' · harness_sid='${harness_sid:-}' · STATE_DIR='${STATE_DIR:-}'). spec_path 는 이 펜스와 같은 Bash 호출에서 대입한다. 5단계는 라운드 시작보다 오래된 critic 파일을 부재로 읽는다(critic_predates_round)." >&2
  fi
  exit 1
fi
printf '%s\n' "$PROFILE_TEXT"
```
<!-- profile-content:end -->

3단계 탐지 — 한 번 dispatch 하고 출력을 요약·전사 없이 verbatim 파일(`$STATE_DIR/critic.txt`)로 저장한다.
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
얹지 않는다). 「추가 라운드 1회 열기」를 고르면
다음 라운드 1단계가 `begin-round --extra-approval "<사용자 자신의 문구>"` 로 돈다.

**`AskUserQuestion` 라벨의 항목별 내용** — 각 선택지 `label` 은 **상태별 라벨 + `— <replacement 를 1–5 낱말로 압축>`** 이다. 상태별 라벨만 담으면 같은 라운드의 여러 항목이 전부 같은 글자가 되어 「라벨만 읽고 고른다」가 원리적으로 안 닫힌다. 같은 라운드의 두 항목이 **같은 라벨을 갖지 않는다.** 단 `replacement` 가 둘 다 부재면 그 부재 표기(`(대체안 미작성)`)가 같을 수 있고, 그때는 이 규약이 공허해지지 않도록 **부재 건수를 함께 공시한다**(「대체안 미작성 N건」). `label` 예산은 1–5 낱말이므로 압축은 필수다 — 렌더의 「고치면」 줄이 전문을 이미 내므로 라벨은 그 줄을 가리키는 손잡이다.

**「미검증」 라운드** — 라벨의 정본은 엔진 출력이다. 요약(`gate --state-dir "$STATE_DIR"`, `--render` 없이)의
`approval_label` 이 「미검증」이면 승인 게이트를 그 라벨로 연다(엔진이 `approval_gate_open` 을 참으로 내고, 사유는
`unverified` 가 말하며, 렌더 첫 줄이 그 공시를 맨 앞에 싣는다). **`finalize` 의 rc 가 0 이 아니면 값과 무관하게 이 라운드를 정상 게이트로 넘기지 않는다** —
그 라운드의 `fin.json` 은 비었거나 직전 라운드 것이라 판정에 쓰지 않고, 엔진이 「미검증」(`unverified: finalize_incomplete`)으로
낸 게이트를 띄운다. 어느 쪽이든 요약의 `round_reviewed` 가 거짓이다 — 그 라운드는 리뷰 완료가 아니다.
「미검증」이 아니어도 `round_reviewed` 가 거짓이면(`unreviewed_reason: unrouted` — 이번 라운드의 finalize 보고서가 없다)
라벨은 붙지 않지만 렌더 첫 줄이 그 사실을 공시하고 「다음:」 줄에 리뷰 완료가 아니라는 꼬리가 붙는다.

승인 게이트를 띄우기 직전에 `$spec_path` 가 working-tree 에 있는지 다시 본다 — 없으면
`### 대상 부재` 문면으로 끝낸다(게이트 없음).

승인 게이트 **2단계**의 옵션 넷 — 정본 Step B 표를 이 skill 어휘로 채운 것이다:

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
  거치지 않는 예외 경로(`### 대상 부재` — `## 입력` 의 상태 리졸버·session id 출구는 그 하위 경우다 ·
  `## 진입 검사` 의 끔)면 명시적 advisory 단락을 동반한다 —
  게이트-less silent 종료는 금지다.
- **재결정 규약 (P23)** — `decide` 처분이 인터뷰가 이미 확정한 항목을 겨냥하면 조용히 덮어쓰지
  않는다. design.md 의 재결정 기록에 *원래 / 재결정 후보 / 근거* 를 적어 다음 라운드로 들고 가고,
  확정이 실제로 뒤집히는 자리는 이 승인 게이트 하나다 — 사용자가 판정한다. 하류의 반증은 보고의
  근거이지 임의 변경의 근거가 아니다. 정본은 `proceed-gate.md` 의 「재결정 규약」 절.

### 미커밋 확인 — ①/② 직전

사용자가 진행을 고르면 다음 단계로 가기 전에 이 펜스를 돌리고, 나온 `[spec-distill]` 줄을 그대로
보인다. 진행은 막지 않는다. 펜스 앞에 `spec_path='<「## 입력」에서 절대 경로로 바꾼 설계문서 경로>'` 한 줄을 붙여
같은 Bash 호출로 돌린다 — 호출마다 새 셸이라 앞 대입이 오지 않는다.

<!-- uncommitted-check:begin -->
```bash
if [ -z "${spec_path:-}" ]; then
  echo "[spec-distill] 미커밋 확인 입력 부재 — spec_path 가 비었다(Bash 호출마다 새 셸이다 — 호출 인자를 이 펜스 안에서 다시 대입하라)."
elif [ ! -e "$spec_path" ]; then
  echo "[spec-distill] 미커밋 확인 대상 부재 — '$spec_path' 가 없다(cwd=$(pwd)). 커밋 여부를 확인하지 못했다."
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
- `fin.json` 의 `blocks` — 막는지를 참/거짓 하나로 말한다. critic 사망(주 판정자) · 항목 소실 · 셀 수 없음일
  때만 참이고, 무엇이 막는지는 위 `advisory[]` 에 함께 실린다.
- `docreview_state.py gate --render` 의 **첫 줄** — 그 라운드의 degrade 한 줄이다. codex 가 없었으면
  그 사실과 사유가, 아니면 `advisory[]` 요약이, 둘 다 비면 `degrade 없음` 이 온다. 이번 라운드가 「미검증」이면
  (요약의 `unverified` — critic 사망 · `finalize` 실패, `fin.json` 이 없는 라운드 포함) 그 공시가, 「미검증」은 아니지만
  리뷰 완료가 아닌 라운드(요약의 `round_reviewed` 거짓 · `unreviewed_reason: unrouted`)면 라우팅 보고서 부재 공시가 맨 앞에 오고
  `degrade 없음` 은 나올 수 없다. 라운드 번호와
  재리뷰 카운트는 **둘째 줄**이다(상한 도달·stagnation 도 그 줄에 붙는다).

게이트를 띄우기 **직전에** 이 셋을 읽어 하나도 빠뜨리지 않고 프로즈로 내고, 승인 게이트 질문
텍스트의 `degrade:` 슬롯에도 싣는다. 셋 다 비었을 때만 `degrade 없음` 이다 — 그 문구는 **채널을
실제로 읽었다는 주장**이므로, 읽지 않은 채 쓰지 않는다.
