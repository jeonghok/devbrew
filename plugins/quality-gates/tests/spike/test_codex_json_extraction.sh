#!/usr/bin/env bash
# Spike: verify codex emits fenced JSON >=2/3 times.
#
# 결과는 **세 값**이다 — PASS / FAIL / SKIPPED.
#
#   PASS     3회 중 2회 이상이 fenced JSON 을 냈다. fixture 를 굽고 exit 0.
#   FAIL     3회가 **전부 실제로 돌았는데** 임계에 못 미쳤다. exit 1.
#            이것만이 "codex 의 출력 형태가 계약을 안 지킨다"는 진짜 판정이다.
#   SKIPPED  codex 를 태울 수 없어 **판정하지 않았다**. exit 0.
#
# 왜 SKIPPED 를 1급 결과로 두는가: 이 spike 는 실제 codex 호출이 필요하고, 그 호출은
# 계정 상태(로그인·모델 설정·사용 한도)에 달렸다. 그 부재를 FAIL 로 렌더하면 회귀
# 스위트에 영구 RED 가 하나 생기고, 영구 RED 는 "선재 RED, 고치지 마라"로 분류되어
# 아무도 읽지 않게 된다 — 이 파일이 실제로 겪은 일이다. 반대로 exit 0 만 내고 조용히
# 넘어가면 *"판정하지 않았다"* 가 *"통과했다"* 로 읽힌다. 그래서 exit 0 이되 출력에
# 크게 남긴다 (CLAUDE.md "Loud logging을 동반한 graceful degradation").
#
# ★ 가용성 판정은 **두 층**이다. 하나로는 부족하다:
#   ① `detect_codex.sh` — 설치·인증·버전·kill switch. 이 리포의 정본 감지기이며
#      여기서 새로 만들지 않는다.
#   ② **실행 결과** — ①은 모델 설정이나 사용 한도를 보지 않으므로 한도가 소진된
#      계정에서도 `codex_available: true` 를 낸다(2026-08-22 실측: 감지는 true,
#      실제 호출은 `usage limit` / `model is not supported ... ChatGPT account` 로
#      400). 그러니 "감지가 참이면 돈다"고 가정하지 않고, 실행이 답변을 하나도
#      못 낸 경우를 **결함이 아니라 부재**로 분류한다.
#
# 한 run 이 "판정 가능"하려면 **assistant 턴(agent_message)이 하나라도 나와야** 한다.
# agent_message 가 없으면 fence 를 판정할 대상 자체가 없는 것이지, "fence 를 안 냈다"가
# 아니다. 이 구분이 이 파일의 핵심이다.

set -u
# Intentionally NOT `set -e` / `set -o pipefail`: the loop must continue through
# all 3 runs even if one codex invocation errors out. Failed runs are observed
# via exit-code logging + "no fenced JSON" outcome, not via shell aborting.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel)"
PROMPT_FILE="$SCRIPT_DIR/spike_prompt.md"
OUT_DIR="$(mktemp -d -t qg-codex-spike-XXXXXX)"
trap 'rm -rf "$OUT_DIR"' EXIT

[[ -f "$PROMPT_FILE" ]] || { echo "Missing $PROMPT_FILE" >&2; exit 1; }

TIMEOUT_CMD="$(command -v gtimeout || command -v timeout)"
[[ -n "$TIMEOUT_CMD" ]] || { echo "Need gtimeout or timeout" >&2; exit 1; }
command -v python3 >/dev/null || { echo "Need python3 for JSONL parsing" >&2; exit 1; }

# `SCRIPT_DIR` 로 잡지 않는다 — 관측 하니스(`tests/lib/codex_observation.sh`)가 이
# 파일을 scratch 로 복사해 실행하므로 그 자리에는 감지기가 없다. 저장소 루트에서
# 잡으면 리포 안 실행과 scratch 사본 실행 양쪽에서 같은 정본을 가리킨다.
DETECTOR="$REPO_ROOT/plugins/quality-gates/scripts/detect_codex.sh"

skipped() {   # $1 = 사람이 읽을 사유
  echo ""
  echo "SKIPPED: 이 spike 는 판정하지 않았다 — $1"
  echo "SKIPPED: 통과가 아니다. codex 를 태울 수 있게 된 뒤 다시 돌릴 것."
  exit 0
}

# ── 층 ①: 정본 감지기 ────────────────────────────────────────────────────────
if [[ ! -x "$DETECTOR" && ! -f "$DETECTOR" ]]; then
  skipped "감지기를 찾을 수 없다 ($DETECTOR) — detector_not_runnable"
fi
detect_out="$(bash "$DETECTOR" 2>/dev/null)"; detect_rc=$?
if [[ $detect_rc -ne 0 ]] || ! printf '%s\n' "$detect_out" | grep -q '^codex_available:'; then
  # 감지기가 안 돈 것은 "codex 가 없다"와 **다른 사실**이다 (SKILL.md 의
  # `detector_not_runnable` 과 같은 구분). 배포 지점이 상대 심볼릭 링크라 끊길 수 있다.
  skipped "감지기 자체가 실행되지 않았다 (detector_not_runnable, exit=$detect_rc)"
fi
if printf '%s\n' "$detect_out" | grep -q '^codex_available: false'; then
  reason="$(printf '%s\n' "$detect_out" | sed -n 's/^skip_reason: //p' | head -1)"
  skipped "codex 사용 불가 (skip_reason: ${reason:-unknown})"
fi

pass=0
usable=0
total=3
first_pass_run=""  # track first passing run so we freeze the correct fixture
first_error=""     # 첫 실행 실패의 원문 — SKIPPED 를 진단 가능하게 만든다
for i in 1 2 3; do
  echo "--- Run $i/$total ---"
  STDOUT_FILE="$OUT_DIR/run-$i.jsonl"
  STDERR_FILE="$OUT_DIR/run-$i.stderr"

  # 추론 강도는 핀하지 않는다 — 사용자 codex 설정이 지배한다(S1). 재현성 근거로
  # 핀을 유지할 수 없다: 이 spike가 굽는 fixture는 이미 thread_id·토큰 수가 매번
  # 다르므로 강도를 고정해도 재현되지 않는다. 보안 플래그는 그대로 둔다.
  #
  # 웹 posture: 명시적으로 OFF. 이 spike는 JSONL shape을 재는 것이 목적이라 외부
  # 검색이 결과를 비결정적으로 만든다 — kill switch 없음(수동 spike, AC21).
  "$TIMEOUT_CMD" 600 codex exec - \
    -C "$REPO_ROOT" \
    -s read-only \
    -c 'tools.web_search=false' \
    -c 'web_search="disabled"' \
    --json \
    < "$PROMPT_FILE" > "$STDOUT_FILE" 2>"$STDERR_FILE"
  run_rc=$?

  echo "  exit: $run_rc"
  echo "  stdout lines: $(wc -l < "$STDOUT_FILE")"
  echo "  stderr preview: $(head -1 "$STDERR_FILE")"

  # Codex 0.130.0 wraps agent_message inside item.completed events:
  #   {"type":"item.completed","item":{"type":"agent_message","text":"..."}}
  # Older shape (kept as fallback): {"type":"agent_message","text":"..."} or {"message":"..."}.
  last_msg="$(grep '"type":"agent_message"' "$STDOUT_FILE" | tail -1 \
              | python3 -c '
import sys, json
try:
    d = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
item = d.get("item") if isinstance(d.get("item"), dict) else d
print(item.get("text", item.get("message", "")))
' 2>/dev/null || echo "")"

  # ── 층 ②: 이 run 이 **판정 가능**한가 ──────────────────────────────────────
  # assistant 턴이 없으면 fence 를 잴 대상이 없다. 그것은 "fence 를 안 냈다"가
  # 아니라 "답이 없었다"이며, 임계 계산의 분모에서 빠져야 한다.
  if ! grep -q '"type":"agent_message"' "$STDOUT_FILE"; then
    # 실패 원문을 남긴다 — `turn.failed` 의 message, 없으면 최상위 `error` 이벤트.
    err="$(python3 - "$STDOUT_FILE" <<'PY' 2>/dev/null || true
import json, sys
msg = ""
try:
    fh = open(sys.argv[1], encoding="utf-8")
except OSError:
    sys.exit(0)
with fh:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except Exception:
            continue
        if not isinstance(d, dict):
            continue
        if d.get("type") == "turn.failed":
            e = d.get("error")
            if isinstance(e, dict) and e.get("message"):
                msg = str(e["message"]); break
        if d.get("type") == "error" and d.get("message") and not msg:
            msg = str(d["message"])
print(msg[:300])
PY
)"
    [[ -z "$err" ]] && err="$(head -1 "$STDERR_FILE")"
    [[ -z "$err" ]] && err="assistant 턴 없음 (exit $run_rc)"
    [[ -z "$first_error" ]] && first_error="$err"
    echo "  판정 불가 — assistant 턴이 없다: $err"
    continue
  fi

  usable=$((usable + 1))

  # Use POSIX bracket class instead of \s — defensive against non-GNU grep.
  if echo "$last_msg" | grep -q '```json' && echo "$last_msg" | grep -qE '```[[:space:]]*$'; then
    echo "  fenced JSON detected"
    pass=$((pass + 1))
    [[ -z "$first_pass_run" ]] && first_pass_run="$i"
  else
    echo "  no fenced JSON"
    echo "  preview: $(echo "$last_msg" | head -c 200)"
  fi
done

echo ""
echo "Spike result: $pass/$total passed (판정 가능했던 run: $usable/$total)"

if [[ $pass -ge 2 ]]; then
  mkdir -p "$SCRIPT_DIR/fixtures"
  # Freeze the FIRST passing run (not blindly run-1), so a partial-pass scenario
  # (e.g., run-1 fails, runs 2-3 pass) still produces a valid ground-truth fixture.
  cp "$OUT_DIR/run-$first_pass_run.jsonl" "$SCRIPT_DIR/fixtures/codex_jsonl_sample.json"
  echo "Frozen run-$first_pass_run sample to $SCRIPT_DIR/fixtures/codex_jsonl_sample.json"
  exit 0
fi

if [[ $usable -lt $total ]]; then
  # 3회가 다 돌지 않았다 — 2/3 임계를 아직 못 채웠을 뿐이지 "못 채웠다"고 판정할
  # 근거가 없다(못 돈 run 은 실패가 아니다). 분모가 달라졌으므로 판정을 보류한다.
  skipped "codex 를 실제로 태우지 못했다 (판정 가능 $usable/$total, fence $pass) — 첫 실패: ${first_error:-알 수 없음}"
fi

echo "FAIL: spike threshold not met. Halt before Task 4." >&2
exit 1
