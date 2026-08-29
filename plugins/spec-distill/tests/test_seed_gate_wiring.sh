#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/framing-requests/SKILL.md plugins/spec-distill/scripts/detect_codex.sh plugins/spec-distill/scripts/codex-killswitch.conf
#
# framing-requests 의 codex 게이트를 **잘라내 실행**해, 그 블록이 러너와 맺는 관계를 잰다.
#
# ── 이 파일의 경계: 형제가 이미 잡는 것은 여기서 재지 않는다 ──────────────────
# 형제 `plugins/quality-gates/tests/test_codex_gate_observation.sh` 는 **같은 블록을
# 실제로 실행한다**(`run_gate`). 다섯 시나리오(가용·kill switch·미설치·버전 바닥·감지기
# 부재)에서 codex 호출 수를 세므로, 「스위치를 켰는데 호출이 나갔다」류는 그쪽이 이미
# 잡는다. 그것을 여기서 다시 재면 값이 아니라 비용이다.
#
# 그래서 여기 남은 단언은 **형제의 호출-수 축이 원리적으로 구별하지 못하는 것**뿐이다.
# 각 단언은 형제를 GREEN 으로 두면서 계약만 깨뜨리는 변이로 확인했다:
#
#   · rc=3 일 때 직전 라운드 산출물이 제거되는가 — 지우든 말든 호출 수는 1 로 같다.
#   · rc=0 일 때 그 산출물이 **살아남는가** — 위의 양성 짝. 무조건 `rm -f` 하는 판본은
#     rc=3 축만 보면 통과하면서 정상 라운드의 codex 판정을 통째로 버린다.
#   · `rm -f` 대상이 **러너가 받은 그 파일인가** — 두 리터럴을 따로 grep 하면 서로 다른
#     경로를 써 놓아도 둘 다 만족된다.
#   · 러너에게 간 인자가 무엇인가 — 형제 하니스는 `PAYLOAD`·`AXIS_FILE`·`CODEX_JSON` 을
#     전부 실재 파일로 공급하므로, 인자를 그중 다른 이름으로 바꿔도 codex 는 1회 불린다.
#   · kill switch 경로의 **stderr** — 형제는 감지기-부재 시나리오에서만 stderr 를 본다.
#   · 게이트 입력(`$PAYLOAD`·`$CODEX_YAML`)이 비었을 때 시끄러운가 — 형제는 그 둘을 항상
#     공급하므로 이 상태를 만들지조차 않는다.
#
# 축 리터럴(`suppression`)만 예외적으로 남겼다. 오늘은 형제도 잡지만 그것은 **러너의
# `case` 가 다른 축을 exit 2 로 거절하기 때문**이지(실측 rc=2) 게이트 계약 때문이 아니다.
# 러너 헤더가 축이 늘어날 것을 명시하고 있고, 그 순간 형제 쪽 커버리지는 조용히 사라진다.
#
# ── 판정 방식 ────────────────────────────────────────────────────────────────
# 리터럴 존재가 아니라 **관측된 사후상태**로 판정한다. 잘라낸 블록을 stub 러너 위에서
# 돌리고, stub 이 받은 argv 와 산출물 파일의 생사를 본다 — 주석·산문·죽은 분기는 stub 에
# 도달하지 않으므로 애초에 이 판정을 만족시킬 수 없다.
#
# 감지기는 **정본을 복사해** 쓴다(kill switch 의미가 stub 의 것이 아니라 정본의 것이어야
# 한다). 러너만 stub 이다. `codex` 는 감지기의 `--version` probe 에만 응답하는 자리표이고,
# PATH 는 진짜 $PATH 를 이어붙이지 않고 명시적으로만 구성한다 — 형제 하니스가 실제 codex
# 로 새는 경로를 그렇게 막았다. 리포의 배포 지점은 건드리지 않는다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$ROOT/plugins/spec-distill/skills/framing-requests/SKILL.md"
DETECTOR="$ROOT/plugins/spec-distill/scripts/detect_codex.sh"
KSCONF="$ROOT/plugins/spec-distill/scripts/codex-killswitch.conf"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/skills/framing-requests/SKILL.md"
  echo "plugins/spec-distill/scripts/detect_codex.sh"
  echo "plugins/spec-distill/scripts/codex-killswitch.conf"
  exit 0
fi

. "$ROOT/shared/tests/assert.sh"

SCRATCH="$(mktemp -d -t sd-seed-gate-XXXXXX)" || { no "scratch 생성 실패"; finish; exit $?; }
trap 'rm -rf "$SCRATCH"' EXIT

# ── 1) 마킹된 게이트 블록을 잘라낸다 ─────────────────────────────────────────
# 형제 하니스와 같은 절단 규약(마커 사이의 bash 펜스 하나). 스코프를 이 블록으로
# 좁히는 것이 요점이다 — 파일 전체 grep 은 다른 절의 어휘로 만족된다.
GATE="$SCRATCH/gate.sh"
awk '
  /codex-gate:begin[[:space:]]+runner=run_seed_codex_reviewer\.sh/ {ing=1; next}
  /codex-gate:end/ {ing=0}
  ing && /^```bash$/ {inb=1; next}
  ing && inb && /^```$/ {inb=0; next}
  ing && inb {print}
' "$SKILL" > "$GATE"
if [ ! -s "$GATE" ]; then
  no "게이트 블록을 잘라내지 못했다 — 마커가 없거나 bash 펜스가 비었다. 아래 판정은 전부 무의미하다"
  finish; exit $?
fi
ok "게이트 블록 절단 $(grep -c . "$GATE")줄 (vacuous 아님)"

# ── 2) 격리된 플러그인 루트 ──────────────────────────────────────────────────
PROOT="$SCRATCH/proot"
mkdir -p "$PROOT/scripts"
cp "$DETECTOR" "$PROOT/scripts/detect_codex.sh" || { no "감지기 사본 생성 실패"; finish; exit $?; }
cp "$KSCONF"   "$PROOT/scripts/codex-killswitch.conf" || { no "kill switch conf 사본 생성 실패"; finish; exit $?; }

cat > "$PROOT/scripts/run_seed_codex_reviewer.sh" <<'STUBEOF'
#!/usr/bin/env bash
set -u
: > "$SEED_STUB_SENTINEL"
for a in "$@"; do printf '%s\n' "$a"; done > "$SEED_STUB_ARGV"
if [ "${SEED_STUB_WRITE:-0}" = "1" ] && [ -n "${4:-}" ]; then
  printf 'findings: []\nmeta:\n  codex_failed: false\n  reason: stub_fresh\n' > "$4"
fi
exit "${SEED_STUB_RC:-0}"
STUBEOF
chmod +x "$PROOT/scripts/run_seed_codex_reviewer.sh"

BIN="$SCRATCH/bin"
mkdir -p "$BIN"
cat > "$BIN/codex" <<'CODEXEOF'
#!/usr/bin/env bash
# 감지기의 --version probe 에만 응답하는 자리표. 그 밖의 호출은 이 락의 관심 밖이라
# 판정하지 않고 죽는다 — 게이트가 codex 를 직접 부르는 경우는 형제 하니스의 호출-수
# 축(「가용 → codex 2회」)이 잡는다.
if [ "${1:-}" = "--version" ]; then echo "codex-cli 0.145.0"; exit 0; fi
exit 90
CODEXEOF
cat > "$BIN/timeout" <<'TOEOF'
#!/usr/bin/env bash
shift
exec "$@"
TOEOF
cp "$BIN/timeout" "$BIN/gtimeout"
chmod +x "$BIN/codex" "$BIN/timeout" "$BIN/gtimeout"
GATE_PATH="$BIN:/usr/bin:/bin"

# 전제: 이 PATH 에서 codex 가 **우리 자리표**로 해석되는가. 진짜 codex 로 새면
# 아래 판정이 무엇을 잰 것인지 알 수 없다(형제 하니스의 PREMISE 검사와 같은 이유).
resolved="$(PATH="$GATE_PATH" command -v codex 2>/dev/null || true)"
case "$resolved" in
  "$BIN"/*) ok "전제: codex 가 scratch 자리표로 해석된다 ($resolved)" ;;
  *) no "전제 실패: codex 가 '$resolved' 로 해석된다 — 아래 판정을 신뢰할 수 없다"; finish; exit $? ;;
esac

# ── 3) 시나리오 러너 ─────────────────────────────────────────────────────────
STALE='findings: []
meta:
  codex_failed: false
  reason: previous_round
'
# $1=라벨 $2=stub rc $3=stub 이 산출물을 쓰는가 $4=PAYLOAD 덮어쓰기 $5=CODEX_YAML 덮어쓰기
# $6..=추가 env.  $4·$5 의 `@` 는 「기본값(케이스 파일 경로)」이고, 그 밖의 값은 빈 문자열
# 포함 그대로 넘어간다 — 게이트 입력 부재를 만들기 위한 것이다.
run_case() {
  CASE_LABEL="$1"; local rc="$2" write="$3" pay_ov="$4" yml_ov="$5"; shift 5
  CASE_DIR="$SCRATCH/case-$CASE_LABEL"
  rm -rf "$CASE_DIR"; mkdir -p "$CASE_DIR/home"
  CASE_PAYLOAD="$CASE_DIR/blob.md"
  CASE_YAML="$CASE_DIR/codex.yaml"
  CASE_SENTINEL="$CASE_DIR/runner.invoked"
  CASE_ARGV="$CASE_DIR/argv.txt"
  CASE_STDERR="$CASE_DIR/stderr.txt"
  printf '## 초안\n\n조립된 번들.\n' > "$CASE_PAYLOAD"
  # 직전 라운드 잔존물 — **양성 마커를 달고 있다.** 지워지지 않으면 이번 라운드가
  # 「codex 정상」으로 읽힌다.
  printf '%s' "$STALE" > "$CASE_YAML"
  local pay="$CASE_PAYLOAD" yml="$CASE_YAML"
  [ "$pay_ov" = "@" ] || pay="$pay_ov"
  [ "$yml_ov" = "@" ] || yml="$yml_ov"
  ( cd "$ROOT" && env "$@" \
      PATH="$GATE_PATH" CLAUDE_PLUGIN_ROOT="$PROOT" \
      PAYLOAD="$pay" CODEX_YAML="$yml" \
      SEED_STUB_RC="$rc" SEED_STUB_WRITE="$write" \
      SEED_STUB_SENTINEL="$CASE_SENTINEL" SEED_STUB_ARGV="$CASE_ARGV" \
      HOME="$CASE_DIR/home" CODEX_API_KEY=t \
      bash "$GATE" ) >/dev/null 2>"$CASE_STDERR"
}
argv_line() { sed -n "${1}p" "$CASE_ARGV" 2>/dev/null; }

# 입력-부재 advisory 가 **그 자리에서** 나왔는지. 사유 코드(`gate_inputs_missing`)로
# 앵커하면 안 된다 — 게이트의 일반 `else` 문구가 `SKIPPED (reason: <사유>)` 로 그 토큰을
# 그대로 실어 내므로, 전용 advisory 를 통째로 지워도 grep 이 만족된다(실측: 그 변이가
# 두 락 모두 GREEN 이었다). 전용 줄만이 갖는 것은 **관측한 두 값을 실어 보여준다**는
# 것이고, 그것이 「어느 쪽이 비었나」를 구별 가능하게 만드는 유일한 정보다.
stderr_shows_observed_inputs() {
  grep -q "PAYLOAD='" "$CASE_STDERR" 2>/dev/null \
    && grep -q "CODEX_YAML='" "$CASE_STDERR" 2>/dev/null
}

# ── A) 가용 + 러너 정상(rc=0, 새 산출물) — 인자와 산출물 생존 ────────────────
run_case avail 0 1 @ @
if [ -f "$CASE_SENTINEL" ]; then
  note "  · A 선결: 러너가 실행됐다 (아래 인자 판정의 전제)"
  assert_eq "$(argv_line 1)" "suppression" "A: 1번 인자가 축 리터럴 'suppression'"
  assert_eq "$(argv_line 2)" "$CASE_PAYLOAD" "A: 2번 인자가 조립된 번들(\$PAYLOAD)"
  assert_eq "$(argv_line 3)" "$ROOT" "A: 3번 인자가 호출 시점의 project_dir"
  assert_eq "$(argv_line 4)" "$CASE_YAML" "A: 4번 인자가 산출물 경로(\$CODEX_YAML)"
else
  no "A: 가용인데 러너가 실행되지 않았다 — 인자 판정 4건을 잴 수 없다"
fi
# 양성 짝 — 정상 라운드의 산출물은 **살아 있어야** 한다. 이 단언이 없으면 무조건
# `rm -f` 하는 판본이 아래 B 를 통과하면서 codex 판정을 통째로 잃는다.
if [ -f "$CASE_YAML" ] && grep -q 'reason: stub_fresh' "$CASE_YAML"; then
  ok "A: 러너가 쓴 산출물이 살아남았다 (rm 이 무조건이 아니다)"
else
  no "A: 러너가 쓴 산출물이 사라졌거나 갱신되지 않았다 — 정상 라운드의 codex 판정이 버려진다"
fi
# 입력이 멀쩡한 라운드에서 입력-부재 advisory 가 나오면 그 가드는 항상 발화하는 것이고,
# 아래 E 판정은 아무것도 재지 않는다(계측기 양성 대조).
if stderr_shows_observed_inputs; then
  no "A: 입력이 멀쩡한데 게이트 입력-부재 advisory 가 나왔다 — 가드가 항상 발화한다"
else
  ok "A: 정상 입력에서는 입력-부재 advisory 가 없다 (가드가 조건부)"
fi

# ── B) 가용 + 러너가 산출물을 못 써서 exit 3 ────────────────────────────────
run_case rc3 3 0 @ @
[ -f "$CASE_SENTINEL" ] || no "B: 러너가 실행되지 않았다 — rc=3 경로를 잴 수 없다"
if [ -e "$CASE_YAML" ]; then
  no "B: 러너가 exit 3 인데 직전 라운드 산출물이 그대로 남았다 — 그 양성 마커가 이번 라운드 판정으로 읽힌다"
else
  ok "B: 러너 exit 3 → 러너가 받은 바로 그 산출물 경로가 제거됐다"
fi

# ── C) kill switch 의 stderr ────────────────────────────────────────────────
# 「호출이 나갔는가」는 형제가 잰다. 여기서 재는 것은 **사유가 사용자에게 닿는가** 다 —
# 형제는 감지기-부재 시나리오에서만 stderr 를 보므로 이 경로는 그쪽 사각지대다.
run_case kill 0 1 @ @ DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1
if grep -q 'kill_switch' "$CASE_STDERR"; then
  ok "C: kill switch skip 사유가 stderr 로 나온다"
else
  no "C: kill switch 인데 사유가 stderr 에 없다 — 사용자는 이유 없는 SKIPPED 만 본다"
fi

# ── E) 게이트 입력 부재 — 조용히 degrade 하지 않는다 ────────────────────────
# 「재료 조립」과 게이트가 다른 Bash 호출로 갈라지면 두 변수가 소멸한다. 그대로 러너에
# 넘기면 payload_missing 으로 **조용히** degrade 한다. 두 변수를 따로 재는 이유는 `||`
# 한쪽만 검사하는 판본을 가르기 위해서다.
for slot in PAYLOAD CODEX_YAML; do
  if [ "$slot" = PAYLOAD ]; then run_case "empty-payload" 0 1 "" @
  else run_case "empty-yaml" 0 1 @ ""; fi
  if [ -f "$CASE_SENTINEL" ]; then
    no "E($slot): 게이트 입력이 비었는데 러너를 불렀다 — 러너가 빈 경로를 받고 조용히 degrade 한다"
  else
    ok "E($slot): 게이트 입력이 비면 러너를 부르지 않는다"
  fi
  if stderr_shows_observed_inputs; then
    ok "E($slot): 입력 부재 advisory 가 관측한 두 값을 그대로 보여준다"
  else
    no "E($slot): 입력 부재를 알리는 줄이 관측값을 안 싣는다 — 일반 SKIPPED 문구는 사유 코드만 주고 «어느 입력이 비었는지»도 «무엇을 고쳐야 하는지»도 말하지 않는다"
  fi
done

finish
