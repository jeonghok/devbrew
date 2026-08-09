#!/usr/bin/env bash
# AC12 — 게이트 연결을 **실행 관측**으로 판정한다.
#
# 실행 관측(test_codex_invocation_contract.sh)은 러너 안의 argv·stdin만 본다.
# 호출자 책임인 detect·kill switch가 러너 **앞에** 실제로 연결됐는지는 말해주지
# 않는다 — kill switch는 P21 보안 컨트롤이라 그 공백을 남기면 "껐다고 믿게만" 만든다.
#
# 여기서는 SKILL의 마킹된 게이트 블록을 잘라내 4개 시나리오로 **실행하고**,
# codex mock이 실제로 몇 번 불렸는지 센다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OBS_REPO="$ROOT"
. "$ROOT/plugins/quality-gates/tests/lib/codex_observation.sh"

pass=0; fail=0
ok() { pass=$((pass+1)); echo "  ✓ $1"; }
no() { fail=$((fail+1)); echo "  ✗ $1"; }

SCRATCH="$(mktemp -d -t qg-gate-XXXXXX)" || exit 1
trap 'rm -rf "$SCRATCH"' EXIT
obs_setup "$SCRATCH"

# ── 양방향 ratchet: 게이트가 **없는** 러너의 원장 ────────────────────────────
# 이것은 carve-out이 아니라 ratchet이다. 새 러너가 게이트 없이 들어오면 RED이고
# (미등재), 등재된 항목에 게이트가 생기면 stale로 RED다 — 목록은 줄어들기만 한다.
# 설계 §10 미해결 1·2가 여기 그대로 서 있고, 테스트 출력에 매번 보인다.
UNGATED_run_codex_reviewer_sh='quality-pipeline/SKILL.md 이 산문 게이트 — 이 사이클 범위 밖 (설계 §10 미해결 1)'
UNGATED_run_artifact_codex_reviewer_sh='critiquing-artifacts/SKILL.md 이 산문 게이트 — 이 사이클 범위 밖 (설계 §10 미해결 1)'
UNGATED_test_codex_json_extraction_sh='수동 spike — 어떤 SKILL도 부르지 않는다'
ungated_key() { printf 'UNGATED_%s' "$(printf '%s' "$1" | tr '.-' '__')"; }

# ── 마킹된 게이트 블록 수집 ──────────────────────────────────────────────────
# 마커는 저자 통제 문자열이지만, 지우면 그 러너가 "게이트 없음"이 되어 위 ratchet에
# 걸린다 — 자기제외가 불가능하다.
declare -a GATED_RUNNER=() GATED_SKILL=()
while IFS= read -r sk; do
  [ -f "$sk" ] || continue
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    GATED_RUNNER+=("$r"); GATED_SKILL+=("$sk")
  done < <(grep -oE '<!--[[:space:]]*codex-gate:begin[[:space:]]+runner=[A-Za-z0-9_.-]+' "$sk" \
           | sed -E 's/.*runner=//')
done < <(find "$ROOT"/plugins/*/skills -name SKILL.md 2>/dev/null | sort)

if [ "${#GATED_RUNNER[@]}" -ge 3 ]; then
  ok "마킹된 게이트 ${#GATED_RUNNER[@]}곳 수집 (vacuous 아님)"
else
  no "마킹된 게이트가 ${#GATED_RUNNER[@]}곳뿐 — 계측기 붕괴, 아래 판정 무의미"
fi

# ── 후보 러너마다: 게이트가 있거나, 원장에 있거나 ────────────────────────────
while IFS= read -r cand; do
  [ -n "$cand" ] || continue
  base="$(basename "$cand")"
  gated=""
  for i in "${!GATED_RUNNER[@]}"; do
    [ "${GATED_RUNNER[$i]}" = "$base" ] && gated="${GATED_SKILL[$i]}"
  done
  key="$(ungated_key "$base")"
  listed="$(eval "printf '%s' \"\${$key:-}\"")"

  if [ -n "$gated" ] && [ -n "$listed" ]; then
    no "$base: 게이트가 생겼는데 UNGATED 원장에 아직 등재돼 있다 (stale — 원장에서 지울 것)"
  elif [ -z "$gated" ] && [ -z "$listed" ]; then
    no "$base: 게이트도 없고 UNGATED 원장에도 없다 — 새 러너는 게이트를 갖거나 사유와 함께 등재돼야 한다"
  elif [ -z "$gated" ]; then
    ok "$base: 게이트 없음 — 원장 등재됨 ($listed)"
  else
    ok "$base: 마킹된 게이트 보유 (${gated#"$ROOT/"})"
  fi
done < <(codex_candidates)

# ── 마킹된 게이트를 4개 시나리오로 실행한다 ──────────────────────────────────
# 블록이 요구하는 변수는 하니스가 전부 공급한다 — 어느 이름을 쓰는지는 블록 자유다.
run_gate() {   # $1=SKILL, $2=runner basename, $3=시나리오, $4=capture, $5..=env KEY=VAL
  local sk="$1" runner="$2" scen="$3" cap="$4"; shift 4
  local plugin_root; plugin_root="$(cd "$(dirname "$sk")/../.." && pwd)"
  local w; w="$(mktemp -d "$SCRATCH/gate-XXXXXX")"
  # 마커 사이의 bash fence 하나를 잘라낸다.
  awk -v r="$runner" '
    $0 ~ ("codex-gate:begin[[:space:]]+runner=" r) {ing=1; next}
    /codex-gate:end/ {ing=0}
    ing && /^```bash$/ {inb=1; next}
    ing && inb && /^```$/ {inb=0; next}
    ing && inb {print}
  ' "$sk" > "$w/gate.sh"
  [ -s "$w/gate.sh" ] || { echo "0"; return; }
  printf '%s\n%s\n' "$OBS_SENTINEL" "관측 입력" > "$w/input.md"
  mkdir -p "$cap"
  ( cd "$ROOT"
    env "$@" PATH="$OBS_MOCKBIN:$PATH" CODEX_CAPTURE_DIR="$cap" \
        CLAUDE_PLUGIN_ROOT="$plugin_root" PR="$plugin_root" PA="$plugin_root" SD="$plugin_root" \
        AXIS_FILE="$w/input.md" PAYLOAD="$w/input.md" spec_path="$w/input.md" \
        CODEX_JSON="$w/out.json" CODEX_YAML="$w/out.yaml" CODEX_DIR_YAML="$w/out.yaml" \
        HOME="$SCRATCH/home" CODEX_API_KEY=t \
        bash "$w/gate.sh" ) >/dev/null 2>&1 || true
  obs_call_count "$cap"
}
mkdir -p "$SCRATCH/home"

for i in "${!GATED_RUNNER[@]}"; do
  r="${GATED_RUNNER[$i]}"; sk="${GATED_SKILL[$i]}"
  label="$(basename "$(dirname "$sk")")"
  plugin="$(basename "$(cd "$(dirname "$sk")/../.." && pwd)")"
  case "$plugin" in
    quality-gates) sw=DEVBREW_DISABLE_QG_CODEX ;;
    spec-distill)  sw=DEVBREW_DISABLE_SPEC_DISTILL_CODEX ;;
    plugin-audit)  sw=DEVBREW_DISABLE_PLUGIN_AUDIT_CODEX ;;
    *) no "$label: 알 수 없는 플러그인 $plugin — kill switch 변수를 특정할 수 없다"; continue ;;
  esac

  n="$(run_gate "$sk" "$r" available "$SCRATCH/g-$label-avail" "IGNORE=1")"
  [ "$n" = "1" ] && ok "$label: 가용 → codex 1회" || no "$label: 가용 → codex ${n}회 (기대 1)"

  n="$(run_gate "$sk" "$r" killswitch "$SCRATCH/g-$label-kill" "$sw=1")"
  [ "$n" = "0" ] && ok "$label: kill switch → codex 0회 (P21 집행 확인)" \
                 || no "$label: kill switch → codex ${n}회 — 스위치가 우회된다"

  # 미설치: mock을 PATH에서 뺀다. OBS_MOCKBIN을 비워 detect가 not_installed를 내게 한다.
  saved="$OBS_MOCKBIN"; OBS_MOCKBIN="$SCRATCH/empty-bin"; mkdir -p "$OBS_MOCKBIN"
  cp "$ROOT/plugins/quality-gates/tests/mocks/bin-stubs/"* "$OBS_MOCKBIN/" 2>/dev/null || true
  n="$(run_gate "$sk" "$r" notinstalled "$SCRATCH/g-$label-noinst" "IGNORE=1")"
  OBS_MOCKBIN="$saved"
  [ "$n" = "0" ] && ok "$label: 미설치 → codex 0회" || no "$label: 미설치 → codex ${n}회"

  # 버전 바닥 미달
  saved="$OBS_MOCKBIN"; OBS_MOCKBIN="$SCRATCH/floor-bin"; mkdir -p "$OBS_MOCKBIN"
  cp "$ROOT/plugins/quality-gates/tests/mocks/below-floor/codex" "$OBS_MOCKBIN/codex"
  cp "$ROOT/plugins/quality-gates/tests/mocks/bin-stubs/"* "$OBS_MOCKBIN/" 2>/dev/null || true
  chmod +x "$OBS_MOCKBIN/codex"
  n="$(run_gate "$sk" "$r" belowfloor "$SCRATCH/g-$label-floor" "IGNORE=1")"
  OBS_MOCKBIN="$saved"
  [ "$n" = "0" ] && ok "$label: 버전 바닥 미달 → codex 0회" || no "$label: 바닥 미달 → codex ${n}회"
done

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[ "$fail" -eq 0 ]
