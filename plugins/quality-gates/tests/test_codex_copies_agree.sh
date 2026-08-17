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
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

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
    # positive(존재): verdict()가 이번 표본에서 실제로 뭔가를 뽑아냈는가. 앵커가
    # 깨져 아무것도 매칭하지 않으면 a·b가 둘 다 빈 문자열이 되어 위 비교가 "차이
    # 없음"으로 늘 통과한다(vacuous) — 모든 표본은 codex_failed 키를 반드시
    # 내므로 그 존재를 여기서 강제한다.
    case "$a" in
      *codex_failed:*) ok "층④ $name (override='${ov:-none}'): 계측기가 codex_failed 를 추출했다" ;;
      *) no "층④ $name (override='${ov:-none}'): 계측기가 아무것도 추출하지 못했다 — 위 비교가 vacuous하다" ;;
    esac
    # positive(값 고정): "존재"만으로는 부족하다 — verdict()가 입력과 무관하게
    # 고정 문자열(예: 항상 `codex_failed: true`)을 내도록 망가지면 위 두 체크를
    # 모두 속인다(양쪽이 같은 상수라 등가 비교 통과, 상수가 `codex_failed:`를
    # 포함하니 존재 체크도 통과). 알려진-상이(known-distinct) 두 표본의 실제
    # 판정값을 여기서 못박는다: override 없는 01-clean은 정상 라운드라
    # `codex_failed: false`, 02-container-violation은 컨테이너 위반이라
    # `codex_failed: true`다 — 상수 추출기는 둘 중 하나에서 반드시 틀린다.
    # 표본에 따라 verdict가 여러 줄일 수 있어 부분문자열 포함으로 재고, 두
    # 사본 emit keyset 차이(category/target_section)는 meta 판정 밖이라 무관하다.
    if [ -z "$ov" ]; then
      case "$name" in
        01-clean.jsonl)
          case "$a" in
            *'codex_failed: false'*) ok "층④ 값 고정 $name (qg): codex_failed: false 확인(상수 추출기 아님)" ;;
            *) no "층④ 값 고정 $name (qg): codex_failed: false 가 없다 — 상수 추출기 의심" ;;
          esac
          case "$b" in
            *'codex_failed: false'*) ok "층④ 값 고정 $name (sd): codex_failed: false 확인(상수 추출기 아님)" ;;
            *) no "층④ 값 고정 $name (sd): codex_failed: false 가 없다 — 상수 추출기 의심" ;;
          esac
          ;;
        02-container-violation.jsonl)
          case "$a" in
            *'codex_failed: true'*) ok "층④ 값 고정 $name (qg): codex_failed: true 확인(상수 추출기 아님)" ;;
            *) no "층④ 값 고정 $name (qg): codex_failed: true 가 없다 — 상수 추출기 의심" ;;
          esac
          case "$b" in
            *'codex_failed: true'*) ok "층④ 값 고정 $name (sd): codex_failed: true 확인(상수 추출기 아님)" ;;
            *) no "층④ 값 고정 $name (sd): codex_failed: true 가 없다 — 상수 추출기 의심" ;;
          esac
          ;;
      esac
    fi
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

# ── mock 자산 사본 ──────────────────────────────────────────────────────────
# 바이트 diff로 재지 않는다 — 헤더 주석 한 줄 차이에 영구 RED가 나고, 그것을
# 예외로 빼는 순간 실제 행동 차이도 함께 빠진다. **같은 인자에 같은 출력을
# 내는가**를 잰다.
#
# 대상은 **두 플러그인에 같은 이름으로 있는 것**의 교집합이다(`comm -12`) —
# 한쪽 고유 mock(qg의 capture-codex·mock-codex-hang.sh·
# mock-codex-no-agent-message.sh·mock-codex-valid-json-no-fence.sh, sd의
# mock-codex-valid-json.sh)은 이름 열거가 아니라 교집합 자체가 대상에서 뺀다 —
# 대조하지 않고, 그 결과 RED도 나지 않는다.
#
# bin-stubs는 `shift; exec "$@"` 스텁이다 — 여기서 태우는 인자는 실행마다 1개뿐이라
# shift 후 "$@"가 비고 exec는 무동작이지만(실측 확인됨), 인자 목록이 늘어나는
# 미래 편집에 대비해 PATH를 시스템 디렉토리로 좁혀 실제 codex 바이너리에 닿을
# 경로를 없앤다 — 이 테스트가 진짜 codex를 호출하는 일은 없어야 한다.
mock_groups="$(comm -12 \
  <(ls "$QG/tests/mocks" 2>/dev/null | sort) \
  <(ls "$SD/tests/mocks" 2>/dev/null | sort))"
n_groups="$(printf '%s\n' "$mock_groups" | grep -c . || true)"
# 바닥은 실측값(8)이다 — brief 초안의 `-ge 4`는 통과하되 헐거워 그룹 하나가
# 조용히 사라져도(8→7) 못 잡는다. 실측치를 바닥으로 두면 축소는 반드시 RED,
# 확장(그룹이 늘어나는 것)은 여전히 자유롭다.
if [ "$n_groups" -ge 8 ]; then
  ok "mock 교집합 ${n_groups}그룹 도출 (vacuous 아님, 실측 바닥 8 유지)"
else
  no "mock 교집합이 ${n_groups}그룹뿐 — 도출이 실측 바닥(8) 밑으로 줄었다"
fi

while IFS= read -r g; do
  [ -n "$g" ] || continue
  a="$QG/tests/mocks/$g"; b="$SD/tests/mocks/$g"
  if [ -d "$a" ] && [ -d "$b" ]; then
    # 디렉토리형 mock: 안의 실행 파일을 같은 인자로 태워 출력을 대조한다.
    for exe in "$a"/*; do
      [ -f "$exe" ] || continue
      name="$(basename "$exe")"
      [ -f "$b/$name" ] || { no "mock $g/$name: sd 쪽에 없다"; continue; }
      for arg in --version "exec"; do
        oa="$(PATH="/usr/bin:/bin" bash "$exe" "$arg" 2>&1; echo "rc=$?")"
        ob="$(PATH="/usr/bin:/bin" bash "$b/$name" "$arg" 2>&1; echo "rc=$?")"
        [ "$oa" = "$ob" ] \
          && ok "mock $g/$name ($arg): 두 사본이 같은 행동" \
          || { no "mock $g/$name ($arg): 행동이 갈라졌다"; echo "      qg: $oa"; echo "      sd: $ob"; }
      done
    done
  elif [ -f "$a" ] && [ -f "$b" ]; then
    # 파일형 mock (mock-codex-*.sh): stdin을 주고 출력을 대조한다.
    oa="$(printf 'x\n' | PATH="/usr/bin:/bin" bash "$a" 2>&1; echo "rc=$?")"
    ob="$(printf 'x\n' | PATH="/usr/bin:/bin" bash "$b" 2>&1; echo "rc=$?")"
    [ "$oa" = "$ob" ] \
      && ok "mock $g: 두 사본이 같은 행동" \
      || { no "mock $g: 행동이 갈라졌다"; echo "      qg: $oa"; echo "      sd: $ob"; }
  fi
done <<EOF
$mock_groups
EOF
finish
