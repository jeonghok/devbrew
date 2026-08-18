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
#
# **역할 분담 — 층① (detect_codex.sh) 에 한정한 갱신** (2026-08 무게 감축,
# 2026-08-17 실측 이후 심볼릭 링크로). 세 배포 지점은 이제
# shared/codex/detect_codex.sh 를 가리키는 상대 심볼릭 링크다(설계 §16.1) —
# **바이트 동일성**은 더 이상 "측정할" 대상이 아니라 파일이 하나뿐이라는 구조로
# 보장된다. 링크가 여전히 링크인지 · 존재하는 정본을 가리키는지는
# `shared/tests/test_copy_of_contract.sh` 가 **잴 것이다 — 그 파일은 Task 16이
# 만든다. 이 커밋 시점에는 아직 없다.** 위 문단이 기각한 전제("두 사본은 의도된
# 차이를 갖는다")는 그 차이를 형제 설정 파일 `codex-killswitch.conf` 로 빼내면서
# 사라졌다.
#
# **이 문단이 말하지 않는 것**: 층①의 kill switch 축은 그대로 유효하다 — 세 링크가
# **서로 다른 conf 세 개**를 읽으므로 conf 드리프트·교차배선에 여전히 이빨이 있다
# (2026-08-17 mutation 으로 확인: 교차배선 60/62 · conf 무시 58/62 · 스위치 영구정지
# 59/62, 전부 RED). 그리고 이 파일의 나머지 축들은 detect_codex 와 **무관하다** —
# 층④는 codex_findings_to_yaml.py 를 비교한다. **2026-08-17 실측 이후** 배포 지점도
# shared/codex/codex_findings_to_yaml.py 를 가리키는 상대 심볼릭 링크가 됐다(층①과
# 같은 이유) — 그 결과 층④ 안에서 **판정 등가**와 **값 고정**은 서로 다른 운명을
# 갖는다(다른 하위 체크들 — anti-vacuous 계측기 확인·표본 수 바닥 — 은 이 갈림과
# 무관하게 그대로 유효하다).
#
# **판정 등가는 다시 실질 판정이다** 〔2026-08-17 fix round 2, R2-7 — 이 문단의
# 앞 판본을 정정한다〕. 앞 판본은 *"파일이 하나뿐이라는 구조로 이미 보장되어 더
# 이상 실질 판정이 아니다(vacuous-but-harmless)"* 라고 적었는데, **그 문장을 쓴
# 커밋 자신이 그 전제를 깼다.** fix round 1(CRIT-1)이 배포 지점마다 형제
# `codex_jsonl.py` 사본을 두고 정본의 import 경로를 역참조하지 않는 `.parent` 로
# 바꿨다 — 그래서 `python3 $QG/scripts/...` 는 **qg 옆 사본**을, `$SD/scripts/...`
# 는 **sd 옆 사본**을 읽는다. 두 호출이 태우는 코드는 더 이상 전부 같은 파일이
# 아니고, 그 사본들이 갈라지면 아래 판정 등가가 실제로 갈라진다(2026-08-17
# mutation 으로 확인 — 아래 층⑤ 주석 참조). 스스로를 vacuous 라 부르는 서술은
# 그 축을 지워도 안전하다는 신호를 남기므로 거짓 그 자체보다 위험하다.
#
# **값 고정**(알려진-상이 표본에 대해 `codex_failed: false`/`true`가 실제로
# 나오는가)은 파일 수와 무관하게 그대로 이빨이 있다 — 사본이 하나가 돼도
# verdict()가 상수 추출기로 퇴화하면 여전히 잡힌다. 이 둘을 뭉뚱그려 "층④가
# 통째로 공허해졌다"고 적으면 Task 15가 고친 I1(판정 등가가 공허해진다는 관찰을
# 파일 전체에 대해 말한 오류)을 방향만 바꿔 재현한다. 별도로 mock 자산 교집합
# 락이 있다. 이 통합은 그 축들을 건드리지 않았다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
QG="$ROOT/plugins/quality-gates"
SD="$ROOT/plugins/spec-distill"
PA="$ROOT/plugins/plugin-audit"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

TMP="$(mktemp -d -t qg-copies-XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT

# ── 층④: codex_findings_to_yaml.py — quality-gates·spec-distill 호출 경로가
# 정본(shared/codex/codex_findings_to_yaml.py)을 가리키는 심볼릭 링크를 거쳐
# 같은 판정을 내는가 ──────────────────────────────────────────────────────
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

# 판정 필드만 뽑는다. 〔2026-08-17 fix round 1〕 이 락은 아래에서 qg·sd 호출
# **둘 다 --emit-keys 인자 없이** 부른다(정본화 이후 기본값은 DEFAULT_KEYS) —
# category/target_section이 나타나는 design 어휘는 여기서 아예 안 켜지므로
# findings 본문에 지금 갈릴 만한 차이가 없다. 그 배선(호출자가 --emit-keys design을
# 실제로 넘기는가)은 이 락이 아니라 run_spec_codex_reviewer.sh·
# run_brief_codex_reviewer.sh 쪽 락이 잰다(F1). verdict()가 findings 본문이
# 아니라 meta만 보는 것은 그와 무관하게 유지한다 — 이 락의 목적은 codex_failed·
# reason 같은 판정 필드의 동일성이지 렌더 형태 동일성이 아니다.
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
    # 표본에 따라 verdict가 여러 줄일 수 있어 부분문자열 포함으로 잰다. verdict()가
    # meta 필드만 보므로 이 비교는 emit keyset(호출자 인자, 이 락에서는 미사용 —
    # 위 verdict() 주석 참조)과 애초에 무관하다.
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

# ── 층⑤: 공백 가드(F2)를 **물리 인스턴스 전부**에 대해 잰다 ────────────────────
# 〔2026-08-17 fix round 2, R2-8〕 fix round 1 이 이 동작을 고정한 락은
# plugins/spec-distill/tests/test_codex_findings_to_yaml.py 하나였는데, 그것은
# sd 배포 지점을 태우므로 **sd 옆 사본만** 읽는다 — 정본이나 qg 옆 사본에서 가드를
# 지우면 전부 GREEN 이었다(리뷰어 실측 행렬). 층④의 표본 7종에도 이 모양이 없다
# ("진짜 메시지 뒤에 빈 메시지" 는 01~07 어디에도 없다).
#
# 대상 집합은 **이름을 열거하지 않고** git 코퍼스에서 도출한다 — 정본과 그 copy-of
# 사본 전부. 사본이 늘어나면 자동으로 함께 검사된다.
#
# 재는 것: 진짜 agent_message 뒤에 공백-only agent_message 가 흐를 때 **앞선 진짜
# 것이 살아남는가**. 가드가 없으면 빈 후보가 last_text 를 덮어써 하류에서
# codex_failed 가 뒤집힌다(fix round 1 F2 의 방향 서술 참조).
CJ_PROBE="$TMP/blank_guard_probe.py"
cat > "$CJ_PROBE" <<'PYEOF'
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("cj_probe", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
real = json.dumps({"type": "item.completed",
                   "item": {"type": "agent_message", "text": "REAL-ANSWER"}})
blank = json.dumps({"type": "item.completed",
                    "item": {"type": "agent_message", "text": "   "}})
text, parsed = mod.extract_last_agent_message(real + "\n" + blank + "\n")
# 앞선 진짜 메시지가 살아남고, JSONL 이 실제로 파싱됐어야 한다.
print("GUARD_OK" if (text == "REAL-ANSWER" and parsed) else "GUARD_BROKEN text=%r parsed=%r" % (text, parsed))
PYEOF

cj_corpus="$(git -C "$ROOT" ls-files -- 'shared/codex/codex_jsonl.py' 'plugins/*/scripts/codex_jsonl.py')"
cj_listed="$(printf '%s\n' "$cj_corpus" | grep -c . || true)"
cj_seen=0
cj_has_canonical=no
cj_has_copy=no
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  cj_seen=$((cj_seen+1))
  case "$rel" in
    shared/codex/codex_jsonl.py) cj_has_canonical=yes ;;
    plugins/*/scripts/codex_jsonl.py) cj_has_copy=yes ;;
  esac
  cj_res="$(python3 "$CJ_PROBE" "$ROOT/$rel" 2>&1)"
  case "$cj_res" in
    GUARD_OK) ok "층⑤ $rel: 뒤따르는 빈 agent_message 가 앞선 진짜 것을 덮어쓰지 못한다(F2 공백 가드)" ;;
    *) no "층⑤ $rel: 공백 가드가 없다 — $cj_res" ;;
  esac
done <<EOF
$cj_corpus
EOF

# positive(도출이 살아 있는가): 개수를 리터럴로 심지 않고 **구조**로 잰다 —
# 정본 하나와 배포 지점 사본이 적어도 하나는 코퍼스에 들어야 하고, 열거된 수와
# 실제로 태운 수가 같아야 한다. 셋 중 하나라도 어긋나면 위 ∀ 가 vacuous 다.
[ "$cj_has_canonical" = yes ] \
  && ok "층⑤ 도출: 정본 shared/codex/codex_jsonl.py 가 코퍼스에 있다" \
  || no "층⑤ 도출: 정본이 코퍼스에 없다 — 위 ∀ 가 정본을 한 번도 안 봤다"
[ "$cj_has_copy" = yes ] \
  && ok "층⑤ 도출: plugins/*/scripts/ 배포 사본이 코퍼스에 있다" \
  || no "층⑤ 도출: 배포 사본이 하나도 없다 — 위 ∀ 가 배포되는 파일을 안 봤다"
[ "$cj_seen" = "$cj_listed" ] && [ "$cj_seen" -ge 1 ] \
  && ok "층⑤ 도출: 열거 ${cj_listed}건 = 실행 ${cj_seen}건 (누락 없음)" \
  || no "층⑤ 도출: 열거 ${cj_listed}건인데 ${cj_seen}건만 태웠다 — 루프가 조용히 건너뛰었다"

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
