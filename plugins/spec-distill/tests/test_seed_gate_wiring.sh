#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/framing-requests/SKILL.md plugins/spec-distill/scripts/detect_codex.sh plugins/spec-distill/scripts/codex-killswitch.conf
#
# framing-requests 의 codex 게이트를 **잘라내 실행**해, 그 블록이 러너와 맺는 관계를
# 잰다. 형제 `plugins/quality-gates/tests/test_codex_gate_observation.sh` 는 같은 블록을
# 다섯 시나리오로 돌려 **codex 호출 수**를 세는데, 호출 수 축은 아래 셋을 구별하지 못한다:
#
#   · 러너가 exit 3 으로 죽었을 때 호출자가 직전 라운드 산출물을 지우는가.
#     러너는 산출물을 못 쓰면 exit 3 으로 죽고, 그때 디스크에 남은 직전 YAML 은
#     양성 마커(`codex_failed: false`)를 달고 있을 수 있어 「이번 라운드 codex 가
#     정상이었다」로 읽힌다. 호출 수 축에서는 지우든 안 지우든 값이 1 로 같다.
#   · 러너에게 넘어간 **인자들**이 실제로 무엇인가 — 축 리터럴 · payload · project_dir ·
#     산출물 경로. 어느 값을 넣어도 호출 수는 1 이다.
#   · `rm -f` 가 지우는 파일이 **러너가 쓰라고 받은 그 파일인가.** 「러너 호출이 있다」와
#     「rm -f 가 있다」를 따로 grep 하면 서로 다른 두 경로를 써 놓아도 둘 다 만족된다.
#
# 그래서 판정은 리터럴 존재가 아니라 **관측된 사후상태**로 한다. 잘라낸 블록을 stub
# 러너 위에서 돌리고, stub 이 받은 argv 와 산출물 파일의 생사를 본다 — 주석·산문·죽은
# 분기는 stub 에 도달하지 않으므로 애초에 이 판정을 만족시킬 수 없다.
#
# **양성 짝이 있다.** 「exit 3 이면 지운다」만 재면 무조건 `rm -f` 하는 판본이 통과한다
# (그 판본은 정상 라운드의 산출물까지 지워 codex 판정을 통째로 잃는다). 그래서 rc=0
# 시나리오에서 같은 파일이 **살아 있는지**를 함께 잰다 — 두 단언은 반대 방향이라
# 한쪽으로 치우친 구현이 둘 다 통과할 수 없다.
#
# 이 파일은 codex 를 부르지 않는다. 러너가 stub 이고, `codex` 는 감지기의 `--version`
# probe 에만 응답하는 자리표다. PATH 는 진짜 $PATH 를 이어붙이지 않고 명시적으로만
# 구성한다 — 형제 하니스가 실제 codex 로 새는 경로를 그렇게 막았다.
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
# 감지기는 **진짜**를 쓴다(kill switch 의미가 stub 의 것이 아니라 정본의 것이어야
# 한다). 러너만 stub 으로 바꾼다 — 이 파일이 재는 것은 호출자의 행동이지 러너가 아니다.
PROOT="$SCRATCH/proot"
mkdir -p "$PROOT/scripts"
cp "$DETECTOR" "$PROOT/scripts/detect_codex.sh" || { no "감지기 사본 생성 실패"; finish; exit $?; }
cp "$KSCONF"   "$PROOT/scripts/codex-killswitch.conf" || { no "kill switch conf 사본 생성 실패"; finish; exit $?; }

cat > "$PROOT/scripts/run_seed_codex_reviewer.sh" <<'STUBEOF'
#!/usr/bin/env bash
set -u
: > "$SEED_STUB_SENTINEL"
for a in "$@"; do printf '%s\n' "$a"; done > "$SEED_STUB_ARGV"
if [ "${SEED_STUB_WRITE:-0}" = "1" ]; then
  printf 'findings: []\nmeta:\n  codex_failed: false\n  reason: stub_fresh\n' > "$4"
fi
exit "${SEED_STUB_RC:-0}"
STUBEOF
chmod +x "$PROOT/scripts/run_seed_codex_reviewer.sh"

BIN="$SCRATCH/bin"
mkdir -p "$BIN"
cat > "$BIN/codex" <<'CODEXEOF'
#!/usr/bin/env bash
# 감지기의 --version probe 에만 응답한다. 그 밖의 호출은 «있어서는 안 되는 것»이라
# 흔적을 남기고 죽는다 — 게이트가 codex 를 직접 부르면 그 사실이 파일로 드러난다.
if [ "${1:-}" = "--version" ]; then echo "codex-cli 0.145.0"; exit 0; fi
: > "${SEED_STUB_CODEX_DIRECT:-/dev/null}"
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
run_case() {   # $1=라벨 $2=stub rc $3=stub 이 산출물을 쓰는가 $4..=추가 env
  CASE_LABEL="$1"; local rc="$2" write="$3"; shift 3
  CASE_DIR="$SCRATCH/case-$CASE_LABEL"
  rm -rf "$CASE_DIR"; mkdir -p "$CASE_DIR/home"
  CASE_PAYLOAD="$CASE_DIR/blob.md"
  CASE_YAML="$CASE_DIR/codex.yaml"
  CASE_SENTINEL="$CASE_DIR/runner.invoked"
  CASE_ARGV="$CASE_DIR/argv.txt"
  CASE_DIRECT="$CASE_DIR/codex.direct"
  CASE_STDERR="$CASE_DIR/stderr.txt"
  printf '## 초안\n\n조립된 번들.\n' > "$CASE_PAYLOAD"
  # 직전 라운드 잔존물 — **양성 마커를 달고 있다.** 지워지지 않으면 이번 라운드가
  # 「codex 정상」으로 읽힌다.
  printf '%s' "$STALE" > "$CASE_YAML"
  ( cd "$ROOT" && env "$@" \
      PATH="$GATE_PATH" CLAUDE_PLUGIN_ROOT="$PROOT" \
      PAYLOAD="$CASE_PAYLOAD" CODEX_YAML="$CASE_YAML" \
      SEED_STUB_RC="$rc" SEED_STUB_WRITE="$write" \
      SEED_STUB_SENTINEL="$CASE_SENTINEL" SEED_STUB_ARGV="$CASE_ARGV" \
      SEED_STUB_CODEX_DIRECT="$CASE_DIRECT" \
      HOME="$CASE_DIR/home" CODEX_API_KEY=t \
      bash "$GATE" ) >/dev/null 2>"$CASE_STDERR"
}
argv_line() { sed -n "${1}p" "$CASE_ARGV" 2>/dev/null; }

# ── A) 가용 + 러너 정상(rc=0, 새 산출물) ────────────────────────────────────
run_case avail 0 1
if [ -f "$CASE_SENTINEL" ]; then
  ok "A: 가용 → 러너가 실제로 실행됐다"
  assert_eq "$(argv_line 1)" "suppression" "A: 1번 인자가 축 리터럴 'suppression'"
  assert_eq "$(argv_line 2)" "$CASE_PAYLOAD" "A: 2번 인자가 조립된 번들(\$PAYLOAD)"
  assert_eq "$(argv_line 3)" "$ROOT" "A: 3번 인자가 호출 시점의 project_dir"
  assert_eq "$(argv_line 4)" "$CASE_YAML" "A: 4번 인자가 산출물 경로(\$CODEX_YAML)"
else
  no "A: 가용인데 러너가 실행되지 않았다 — 게이트가 정상 경로를 막는다"
  no "A: 인자 판정 4건을 잴 수 없다(러너 미실행)"
fi
# 양성 짝 — 정상 라운드의 산출물은 **살아 있어야** 한다. 이 단언이 없으면 무조건
# `rm -f` 하는 판본이 아래 B 를 통과하면서 codex 판정을 통째로 잃는다.
if [ -f "$CASE_YAML" ] && grep -q 'reason: stub_fresh' "$CASE_YAML"; then
  ok "A: 러너가 쓴 산출물이 살아남았다 (rm 이 무조건이 아니다)"
else
  no "A: 러너가 쓴 산출물이 사라졌거나 갱신되지 않았다 — 정상 라운드의 codex 판정이 버려진다"
fi
if [ -f "$CASE_DIRECT" ]; then
  no "A: 게이트가 codex 를 직접 불렀다 — 호출은 러너를 통해서만 나가야 한다"
else
  ok "A: 게이트가 codex 를 직접 부르지 않았다"
fi

# ── B) 가용 + 러너가 산출물을 못 써서 exit 3 ────────────────────────────────
run_case rc3 3 0
if [ -f "$CASE_SENTINEL" ]; then
  ok "B: 가용 → 러너 실행 (rc=3 경로 진입)"
else
  no "B: 러너가 실행되지 않았다 — rc=3 경로를 잴 수 없다"
fi
if [ -e "$CASE_YAML" ]; then
  no "B: 러너가 exit 3 인데 직전 라운드 산출물이 그대로 남았다 — 그 양성 마커가 이번 라운드 판정으로 읽힌다"
else
  ok "B: 러너 exit 3 → 러너가 받은 바로 그 산출물 경로가 제거됐다"
fi

# ── C) kill switch ──────────────────────────────────────────────────────────
# 「스위치를 켰는데 호출이 나갔다」를 직접 잰다. 감지기가 정본이므로 스위치 의미도 정본이다.
run_case kill 0 1 DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1
if [ -f "$CASE_SENTINEL" ]; then
  no "C: kill switch 가 켜졌는데 러너가 실행됐다 — 호출이 분기 밖에 있다(P21 보안 컨트롤 우회)"
else
  ok "C: kill switch → 러너 미실행 (호출이 분기 안에 있다)"
fi
if grep -q 'kill_switch' "$CASE_STDERR"; then
  ok "C: skip 사유(kill_switch)가 stderr 로 나온다"
else
  no "C: skip 사유가 stderr 에 없다 — 사용자는 이유 없는 SKIPPED 만 본다"
fi

# ── D) 감지기 자체가 안 도는 상태 ───────────────────────────────────────────
# 사본을 옮긴다(리포의 배포 지점은 건드리지 않는다). 「codex 가 없다」와 「감지기를
# 못 돌렸다」가 같은 값으로 뭉개지지 않는지 본다.
mv "$PROOT/scripts/detect_codex.sh" "$PROOT/scripts/detect_codex.sh.bak"
run_case nodetect 0 1
mv "$PROOT/scripts/detect_codex.sh.bak" "$PROOT/scripts/detect_codex.sh"
if [ -f "$CASE_SENTINEL" ]; then
  no "D: 감지기가 없는데 러너가 실행됐다 — 판정 없이 codex 가 나간다"
else
  ok "D: 감지기 부재 → 러너 미실행"
fi
if grep -q 'detector_not_runnable' "$CASE_STDERR"; then
  ok "D: 감지기 부재가 'detector_not_runnable' 로 구별돼 나온다"
else
  no "D: 감지기 부재가 다른 skip 사유와 뭉개졌다 — 부재와 판독 실패는 다른 사실이다"
fi

finish
