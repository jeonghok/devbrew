#!/usr/bin/env bash
# AC10 · AC15 — 사본 갈라짐 **행동** 락.
#
# 왜 파일 diff가 아닌가: 두 사본은 의도된 차이(kill switch 변수명)를 갖는다. diff로
# 재면 그 차이 때문에 항상 RED거나, 그것을 예외로 빼는 순간 다른 모든 차이도 함께
# 빠진다. 여기서 재는 것은 **같은 입력에 같은 답을 내는가**이다.
#
# 봉쇄하는 실패: qg 사본의 마지막 변경은 2026-05-14, sd 사본은 2026-07-29까지 받았다.
# 그 사이 qg는 `{"findings": {}}`에 `codex_failed: false`를 내고 있었다 — 실행되지
# 못한 검사가 통과한 검사로 기록된다. 두 사본의 동기 여부를 재는 테스트는 없었다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
QG="$ROOT/plugins/quality-gates"
SD="$ROOT/plugins/spec-distill"
PA="$ROOT/plugins/plugin-audit"
pass=0; fail=0
ok() { pass=$((pass+1)); echo "  ✓ $1"; }
no() { fail=$((fail+1)); echo "  ✗ $1"; }

TMP="$(mktemp -d -t qg-copies-XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT

# ── 층④: codex_findings_to_yaml.py 두 사본 ──────────────────────────────────
# 표본은 판정을 실제로 가르는 것들이다. 정상·빈 스트림·펜스 없는 raw JSON·
# 컨테이너 위반·원소 위반·override 유무.
mk() { printf '%s\n' "{\"type\":\"item.completed\",\"item\":{\"type\":\"agent_message\",\"text\":$1}}"; }
samples_dir="$TMP/samples"; mkdir -p "$samples_dir"
mk '"```json\n{\"findings\": []}\n```"'              > "$samples_dir/01-clean.jsonl"
mk '"```json\n{\"findings\": {}}\n```"'              > "$samples_dir/02-container-violation.jsonl"
mk '"```json\n{\"findings\": [1, 2]}\n```"'          > "$samples_dir/03-element-violation.jsonl"
mk '"{\"findings\": []}"'                            > "$samples_dir/04-raw-no-fence.jsonl"
mk '"no fence at all"'                               > "$samples_dir/05-no-json.jsonl"
: > "$samples_dir/06-empty.jsonl"
printf 'not json\n'                                  > "$samples_dir/07-garbage.jsonl"

# 판정 필드만 뽑는다. sd 사본은 emit keyset에 category/target_section을 더하는데
# 그것은 **의도된 차이**이므로 findings 본문이 아니라 meta의 판정만 대조한다.
verdict() { grep -E '^  (codex_failed|reason|raw_findings_type|bad_element_types):' || true; }

seen=0
for s in "$samples_dir"/*.jsonl; do
  seen=$((seen+1))
  name="$(basename "$s")"
  for ov in "" "1"; do
    if [ -z "$ov" ]; then oargs=(); else oargs=(--meta-override-exit-code 1 --meta-override-reason exit_nonzero); fi
    a="$(python3 "$QG/scripts/codex_findings_to_yaml.py" "${oargs[@]+"${oargs[@]}"}" < "$s" | verdict)"
    b="$(python3 "$SD/scripts/codex_findings_to_yaml.py" "${oargs[@]+"${oargs[@]}"}" < "$s" | verdict)"
    if [ "$a" = "$b" ]; then
      ok "층④ $name (override='${ov:-none}'): 두 사본이 같은 판정"
    else
      no "층④ $name (override='${ov:-none}'): 판정이 갈라졌다"
      echo "      qg: $(printf '%s' "$a" | tr '\n' ' ')"
      echo "      sd: $(printf '%s' "$b" | tr '\n' ' ')"
    fi
    # positive: verdict()가 이번 표본에서 실제로 뭔가를 뽑아냈는가. 앵커가 깨져
    # 아무것도 매칭하지 않으면 a·b가 둘 다 빈 문자열이 되어 위 비교가 "차이
    # 없음"으로 늘 통과한다(vacuous) — 모든 표본은 codex_failed 키를 반드시
    # 내므로 그 존재를 여기서 강제한다.
    case "$a" in
      *codex_failed:*) ok "층④ $name (override='${ov:-none}'): 계측기가 codex_failed 를 추출했다" ;;
      *) no "층④ $name (override='${ov:-none}'): 계측기가 아무것도 추출하지 못했다 — 위 비교가 vacuous하다" ;;
    esac
  done
done
# positive: 표본을 실제로 돌렸는가. 없으면 "차이 0"과 "아무것도 안 봄"이 구별되지 않는다.
if [ "$seen" -ge 7 ]; then ok "층④ 표본 ${seen}건 실행 (vacuous 아님)"
else no "층④ 표본이 ${seen}건뿐 — 위 판정이 무의미하다"; fi

# ── 층①: detect_codex.sh 세 사본 ────────────────────────────────────────────
# kill switch 변수명은 **의도된 차이**이므로 그 축만 파라미터로 뺀다. 순진하게 걸면
# 첫 실행부터 RED다. §4.2의 버전 바닥은 **공통 축**이므로 빼지 않는다.
MOCKS="$QG/tests/mocks"
declare -a PROBES=("$QG/scripts/detect_codex.sh" "$SD/scripts/detect_codex.sh" "$PA/scripts/detect_codex.sh")
declare -a SWITCHES=(DEVBREW_DISABLE_QG_CODEX DEVBREW_DISABLE_SPEC_DISTILL_CODEX DEVBREW_DISABLE_PLUGIN_AUDIT_CODEX)

probe_out() {   # $1 = probe, $2 = mock dir 이름, $3 = 추가 env(KEY=VAL 또는 빈 문자열)
  local extra="$3"
  env -i PATH="$MOCKS/$2:$MOCKS/bin-stubs:/usr/bin:/bin" HOME="$TMP/nohome" \
      CODEX_API_KEY=t ${extra:+"$extra"} bash "$1" 2>/dev/null
}
mkdir -p "$TMP/nohome"

for scenario in safe-v1 bad-version below-floor unreadable-version; do
  outs=()
  for p in "${PROBES[@]}"; do outs+=("$(probe_out "$p" "$scenario" "")"); done
  if [ "${outs[0]}" = "${outs[1]}" ] && [ "${outs[1]}" = "${outs[2]}" ]; then
    ok "층① $scenario: 세 사본이 같은 판정 (공통 축)"
  else
    no "층① $scenario: 판정이 갈라졌다"
    for i in 0 1 2; do echo "      ${PROBES[$i]}: $(printf '%s' "${outs[$i]}" | tr '\n' ' ')"; done
  fi
done

# kill switch는 **각자의 변수에만** 반응해야 한다 (의도된 차이 — 파라미터 축).
for i in 0 1 2; do
  own="$(probe_out "${PROBES[$i]}" safe-v1 "${SWITCHES[$i]}=1")"
  printf '%s' "$own" | grep -q 'skip_reason: kill_switch' \
    && ok "층① $(basename "$(dirname "$(dirname "${PROBES[$i]}")")"): 자기 변수에 반응" \
    || no "층① $(basename "$(dirname "$(dirname "${PROBES[$i]}")")"): 자기 변수에 무반응"
  for j in 0 1 2; do
    [ "$i" = "$j" ] && continue
    other="$(probe_out "${PROBES[$i]}" safe-v1 "${SWITCHES[$j]}=1")"
    printf '%s' "$other" | grep -q 'codex_available: true' \
      && ok "층① ${SWITCHES[$j]} 가 ${PROBES[$i]##*/plugins/} 에 무효" \
      || no "층① 이웃 변수 ${SWITCHES[$j]} 가 ${PROBES[$i]##*/plugins/} 에 영향을 준다"
  done
done

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[ "$fail" -eq 0 ]
