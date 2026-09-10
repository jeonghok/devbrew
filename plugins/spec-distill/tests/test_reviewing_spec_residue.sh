#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/spec-distill/scripts/detect_codex.sh plugins/spec-distill/scripts/codex-killswitch.conf
#
# `reviewing-spec` 의 codex 게이트를 **잘라내 실행**해, 직전 라운드의 산출물이 이번 라운드
# 판정으로 새지 않는지 잰다.
#
# ── 왜 이 파일이 생겼는가 ────────────────────────────────────────────────────
# 이 성질은 산문으로 네 번 주장됐고 **한 번도 집행되지 않았다.** 실측(재리뷰 2): 진입
# 중화를 가용성 분기 «안»으로 되돌리는 변이를 넣으면 보안 결함이 완전히 되살아나는데
# (skip 경로마다 직전 라운드 finding 2건 섭취) 리포의 셸 락 전수가 GREEN 그대로였다.
# 형제 `framing-requests` 는 바로 이 락을 갖고 있다(`test_seed_gate_wiring.sh` 의
# `residue_case` 행렬) — 모양은 복사됐는데 그 모양을 지키는 락은 복사되지 않았다.
#
# ── 형제와 무엇이 다른가 (관측 대상이 다르다) ────────────────────────────────
# 형제의 펜스는 `$CODEX_YAML` 을 **자기 안에서 읽고** 판정 줄을 stdout 으로 낸다. 그래서
# 형제 락은 stdout 을 판정한다. 이 펜스는 그 파일을 **읽지 않는다** — 소비자는 절차서
# 5단계의 `docreview_route.py prepare-recritic` 이고 그것은 다른 Bash 호출이다.
# 그러므로 여기서 재는 것은 두 가지다:
#   · **A) 디스크의 사후상태** — 펜스가 돌고 난 뒤 그 경로가 중화됐는가(부재 또는 0바이트).
#     둘 다 하류에서 fail-closed 다(0바이트는 실측으로 `codex_absent: true`).
#   · **D) 하류가 실제로 무엇을 보는가** — 한 셀을 end-to-end 로 돌려 「섭취되지 않는다」를
#     기계 채널(`prepare-recritic`)에서 직접 확인한다. A 가 부류를, D 가 그 부류가 왜
#     보안 문제인지를 잰다.
#
# ── 양성 짝이 둘인 이유 ──────────────────────────────────────────────────────
# A 는 전부 **부재** 단언이라 「언제나 지운다」는 구현이 전부 만족시킨다. 그 구현은 이번
# 라운드가 실제로 얻은 codex 결과를 파괴하므로 더 나쁘다. 그래서 살아남아야 하는 두 경우를
# 함께 잰다:
#   · `keep-rc0`  — 러너가 이번 라운드 산출물을 쓰고 정상 종료. 그 산출물은 **살아야** 한다.
#   · `keep-trap` — 러너가 정직한 degrade 기록을 남기고 **non-zero** 로 죽는다(EXIT 트랩은
#     자기 rc 를 갖지 않고 원래 실패의 rc 를 그대로 둔다 — 실측 `rc 143` +
#     `aborted_before_completion`). 이 기록도 **살아야** 한다. `rc != 0` 으로 지우는 판본이
#     여기서 RED 다.
#
# ── 판정 방식 ────────────────────────────────────────────────────────────────
# 리터럴 존재가 아니라 **관측된 사후상태**로 판정한다. 주석·산문·죽은 분기는 스텁에
# 도달하지 못하므로 애초에 이 판정을 만족시킬 수 없다. 감지기와 kill switch 설정은 리포
# 정본을 **복사**해 쓴다(스위치 의미가 스텁의 것이 아니라 정본의 것이어야 한다). 러너만
# 스텁이다. PATH 는 진짜 `$PATH` 를 이어붙이지 않고 명시적으로만 구성한다 — 실제 codex 로
# 새는 경로를 그렇게 막는다. 리포의 배포 지점은 건드리지 않는다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/skills/reviewing-spec/SKILL.md"
  echo "plugins/spec-distill/scripts/detect_codex.sh"
  echo "plugins/spec-distill/scripts/codex-killswitch.conf"
  exit 0
fi

. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

SCRATCH="$(mktemp -d -t sd-rs-residue-XXXXXX)" || { echo "scratch 생성 실패" >&2; exit 1; }
cleanup() { chmod -R u+w "$SCRATCH" 2>/dev/null; rm -rf "$SCRATCH"; }
trap cleanup EXIT

STALE_MARK='STALE_ROUND1_zz9'
THIS_MARK='THIS_ROUND_q7'

# ── 펜스 추출 ────────────────────────────────────────────────────────────────
FENCE="$SCRATCH/fence.sh"
awk '
  /codex-gate:begin[[:space:]]+runner=run_docreview_codex_reviewer\.sh/ {ing=1; next}
  /codex-gate:end/ {ing=0}
  ing && /^```bash$/ {inb=1; next}
  ing && inb && /^```$/ {inb=0; next}
  ing && inb {print}
' "$SKILL" > "$FENCE"
fence_lines="$(grep -c . "$FENCE" || true)"
if [ "${fence_lines:-0}" -lt 10 ]; then
  no "추출: codex-gate 펜스가 ${fence_lines:-0}줄이다 — 마커가 사라졌거나 추출이 깨졌다. 아래 판정은 전부 무의미하다"
  finish
  exit
fi
ok "추출: codex-gate 펜스 ${fence_lines}줄"
if bash -n "$FENCE" 2>/dev/null; then
  ok "추출: 펜스가 문법적으로 실행 가능하다 (bash -n)"
else
  no "추출: 펜스가 bash -n 을 통과하지 못한다 — 읽기로는 옳아 보여도 돌지 않는다"
fi
# 펜스의 계약은 「앞에 이어 붙여라」라서 앞 블록의 셸 옵션을 물려받을 수 있다. 가장 엄한
# 조합을 앞에 붙인 사본 — 아래 E 셀이 같은 경로를 그 아래서 다시 돌린다.
FENCE_E="$SCRATCH/fence-errexit.sh"
{ echo 'set -euo pipefail'; cat "$FENCE"; } > "$FENCE_E"
post_state() {   # post_state <path> → absent | 0byte | <N>B
  if [ ! -e "$1" ]; then echo absent
  elif [ ! -s "$1" ]; then echo 0byte
  else echo "$(wc -c < "$1" | tr -d ' ')B"; fi
}
yml_of() { printf '%s' "$SCRATCH/$1/.claude/spec-distill/$1/docreview-codex.yaml"; }

# ── 가짜 플러그인 루트 ───────────────────────────────────────────────────────
PR="$SCRATCH/plugin"
mkdir -p "$PR/scripts"
cp "$ROOT/plugins/spec-distill/scripts/state_path.py"        "$PR/scripts/"
cp "$ROOT/plugins/spec-distill/scripts/detect_codex.sh"      "$PR/scripts/"
cp "$ROOT/plugins/spec-distill/scripts/codex-killswitch.conf" "$PR/scripts/"
ln -s "$ROOT/plugins/spec-distill/references" "$PR/references"
DETECTOR="$PR/scripts/detect_codex.sh"

cat > "$PR/scripts/run_docreview_codex_reviewer.sh" <<'STUB'
#!/usr/bin/env bash
# 스텁 러너 — 실물의 계약(인자 넷 · 산출물 기록 · rc)만 흉내낸다.
[ -n "${STUB_ARGV_OUT:-}" ] && printf '%s\n' "$4" > "$STUB_ARGV_OUT"
case "${STUB_WRITE:-none}" in
  ok)     printf 'findings:\n  - agent: codex-reviewer\n    ref: t1\n    layer: 2\n    category: placeholder\n    anchor: "#12-files-to-modify"\n    disposition: decide\n    summary: "THIS_ROUND_q7"\n    evidence: null\nmeta:\n  codex_failed: false\n  exit_code: 0\n' > "$4" ;;
  honest) printf 'findings: []\nmeta:\n  codex_failed: true\n  reason: aborted_before_completion\n  exit_code: 0\n' > "$4" ;;
  husk)   : > "$4" ;;
  none)   : ;;
esac
exit "${STUB_RC:-0}"
STUB
chmod +x "$PR/scripts/run_docreview_codex_reviewer.sh"

# ── PATH: 감지기의 `--version` probe 에만 답하는 자리표 ──────────────────────
BIN_OK="$SCRATCH/bin-ok"; BIN_NONE="$SCRATCH/bin-none"
mkdir -p "$BIN_OK" "$BIN_NONE"
printf '#!/usr/bin/env bash\n[ "${1:-}" = "--version" ] && { echo "codex-cli 0.145.0"; exit 0; }\nexit 0\n' > "$BIN_OK/codex"
chmod +x "$BIN_OK/codex"
cp "$ROOT/plugins/quality-gates/tests/mocks/bin-stubs/"* "$BIN_OK/"   2>/dev/null || true
cp "$ROOT/plugins/quality-gates/tests/mocks/bin-stubs/"* "$BIN_NONE/" 2>/dev/null || true
BASE="/usr/bin:/bin"

# ── 하니스 전제 — sid 가 «도출»을 통과하는가 (이 락 자신의 vacuity 바닥) ─────
# `state_path.py` 의 세션 이름 검사는 **8자 이상**을 요구한다. 짧은 sid 를 쓰면 도출이
# 조용히 실패해 `$CODEX_YAML` 이 비고, 그러면 진입 중화는 **설계상 no-op** 이 된다 —
# 아래 케이스는 「중화가 안 됐다」가 아니라 「아무것도 재지 않았다」가 되는데 둘의 겉모습이
# 같다. 이 락을 처음 돌렸을 때 실제로 셀 하나가 그렇게 무의미했다(7자 sid). 쓰는 이름을
# 전부 미리 통과시켜, 계측기가 죽은 채로 판정이 나오는 것을 막는다.
SIDS="rs01kill rs02noin rs03noip rs05rc3x rs04nodt rs06keep rs07trap rs08lock rs09down rs10ctlx
      rs11trnc rs12pred rs21kill rs22noin rs23noip rs24nodt rs25rc3x rs26lock"
bad_sid=""
for s in $SIDS; do
  DEVBREW_SPEC_DISTILL_SESSION_ID="$s" python3 "$PR/scripts/state_path.py" session-id >/dev/null 2>&1 \
    || bad_sid="$bad_sid $s"
done
if [ -z "$bad_sid" ]; then
  ok "전제: 이 락이 쓰는 sid 전부가 state_path.py 의 세션 이름 검사를 통과한다 (도출이 조용히 죽지 않는다)"
else
  no "전제: sid 도출 실패 —$bad_sid. 그 케이스들은 \$CODEX_YAML 이 비어 아무것도 재지 못한다(계측기 붕괴)"
fi

plant_stale() {   # plant_stale <path>
  printf 'findings:\n  - agent: codex-reviewer\n    ref: s1\n    layer: 2\n    category: placeholder\n    anchor: "#12-files-to-modify"\n    disposition: decide\n    summary: "%s"\n    evidence: null\nmeta:\n  codex_failed: false\n  exit_code: 0\n' "$STALE_MARK" > "$1"
}

# `run_fence <sid> <bin> <plant?> <stub_write> <stub_rc> [env…]` → 산출물 경로를 stdout 으로.
CASE_ERR=""
run_fence() {
  local sid="$1" bin="$2" plant="$3" sw="$4" rc="$5"; shift 5
  local home="$SCRATCH/$sid"; mkdir -p "$home/.claude/spec-distill/$sid"
  local yml="$home/.claude/spec-distill/$sid/docreview-codex.yaml"
  [ "$plant" = "plant" ] && plant_stale "$yml"
  CASE_ERR="$SCRATCH/$sid.err"
  # cwd 를 스크래치로 둔다 — `state_path.py` 가 git 밖에서 cwd fallback 을 쓰므로
  # 상태 루트가 리포의 `.claude/` 가 아니라 이 임시 트리 안에 생긴다.
  ( cd "$home" && env -i PATH="$bin:$BASE" HOME="$home" CODEX_API_KEY=t \
      PYTHONDONTWRITEBYTECODE=1 CLAUDE_PLUGIN_ROOT="$PR" \
      DEVBREW_SPEC_DISTILL_SESSION_ID="$sid" \
      STUB_WRITE="$sw" STUB_RC="$rc" STUB_ARGV_OUT="$SCRATCH/$sid.argv" \
      "$@" bash "${RUN_FENCE:-$FENCE}" ) >/dev/null 2>"$CASE_ERR"
  printf '%s' "$yml"
}

neutralised() { [ ! -s "$1" ]; }   # 부재 또는 0바이트 — 둘 다 하류 fail-closed

# ── A) 잔존물 — skip 네 경로 + 러너 실패 ─────────────────────────────────────
# skip 분기는 codex 호출 0회라 「게이트가 정확히 동작했다」와 구별되지 않는다. 호출 수를
# 세는 형제 하니스(qg `test_codex_gate_observation.sh`)가 이 자리를 못 보는 이유다.
residue_case() {   # residue_case <라벨> <sid> <bin> <stub_write> <stub_rc> [env…]
  local label="$1" sid="$2" bin="$3" sw="$4" rc="$5"; shift 5
  local yml; yml="$(run_fence "$sid" "$bin" plant "$sw" "$rc" "$@")"
  if neutralised "$yml"; then
    ok "A($label): 직전 라운드 산출물이 중화됐다 (부재 또는 0바이트)"
  else
    no "A($label): 직전 라운드 산출물이 그대로 남았다 ($(wc -c < "$yml" | tr -d ' ')바이트) — 5단계가 그것을 이번 라운드 codex 판정으로 읽는다"
  fi
}
residue_case "kill switch"          rs01kill  "$BIN_OK"   none 0 DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1
residue_case "codex 미설치"          rs02noin  "$BIN_NONE" none 0 spec_path="$SKILL"
residue_case "게이트 입력 부재"       rs03noip  "$BIN_OK"   none 0
residue_case "러너 rc=3 (껍데기)"     rs05rc3x  "$BIN_OK"   husk 3 spec_path="$SKILL"

# 감지기 부재 — 배포 지점이 사라진 상태. 리포를 건드리지 않고 «가짜 루트»에서만 지운다.
mv "$DETECTOR" "$SCRATCH/detector.bak"
residue_case "감지기 부재"           rs04nodt  "$BIN_OK"   none 0 spec_path="$SKILL"
mv "$SCRATCH/detector.bak" "$DETECTOR"

# ── A 의 양성 짝 — 살아야 하는 것은 살아남는가 ───────────────────────────────
keep_case() {   # keep_case <라벨> <sid> <stub_write> <stub_rc> <기대 마커|-> <사유>
  local label="$1" sid="$2" sw="$3" rc="$4" mark="$5" why="$6"
  local yml; yml="$(run_fence "$sid" "$BIN_OK" plant "$sw" "$rc" spec_path="$SKILL")"
  if [ ! -s "$yml" ]; then
    no "A+($label): 이번 실행이 쓴 산출물이 사라졌다 — $why"
  elif grep -q "$STALE_MARK" "$yml"; then
    no "A+($label): 파일은 남았는데 내용이 직전 라운드 것이다 — 러너의 기록이 아니라 잔존물이 살아남았다"
  elif [ "$mark" = "-" ] || grep -q "$mark" "$yml"; then
    ok "A+($label): 이번 실행이 쓴 산출물이 살아남았다 — $why"
  else
    no "A+($label): 파일은 남았으나 기대한 마커($mark)가 없다"
  fi
}
keep_case "keep-rc0"  rs06keep ok     0   "$THIS_MARK" "무조건 지우는 판본이면 이번 라운드 codex 판정이 통째로 버려진다"
keep_case "keep-trap" rs07trap honest 143 "-"          "EXIT 트랩은 원래 실패의 rc 를 그대로 두고 기록을 남긴다(실측 rc 143) — rc != 0 으로 지우면 이번 라운드의 정직한 사유가 사라진다"
if grep -q 'aborted_before_completion' "$SCRATCH/rs07trap/.claude/spec-distill/rs07trap/docreview-codex.yaml" 2>/dev/null; then
  ok "A+(keep-trap): 그 기록의 사유(aborted_before_completion)가 보존된다 — 하류가 뭉갠 사유 대신 실제 사유를 받는다"
else
  no "A+(keep-trap): 정직한 기록의 사유가 남아 있지 않다"
fi

# ── A 의 셋째 층 — 중화가 «불가능» 할 때 조용히 넘어가지 않는가 ──────────────
# unlink 는 디렉토리 권한을, 절단은 파일 권한을 요구한다. 둘 다 막으면 중화가 불가능하고,
# 그때 펜스는 codex 축을 끄고 사유를 대야 한다 — 그러지 않으면 사람이 읽는 채널은
# 「degraded」라 하고 기계가 읽는 채널은 「codex 정상」이라 하는 모순 상태가 된다.
sid=rs08lock; home="$SCRATCH/$sid"; mkdir -p "$home/.claude/spec-distill/$sid"
yml="$home/.claude/spec-distill/$sid/docreview-codex.yaml"
plant_stale "$yml"; chmod 444 "$yml"; chmod 555 "$home/.claude/spec-distill/$sid"
( cd "$home" && env -i PATH="$BIN_OK:$BASE" HOME="$home" CODEX_API_KEY=t \
    PYTHONDONTWRITEBYTECODE=1 CLAUDE_PLUGIN_ROOT="$PR" DEVBREW_SPEC_DISTILL_SESSION_ID="$sid" \
    STUB_WRITE=none STUB_RC=0 spec_path="$SKILL" DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1 \
    bash "$FENCE" ) >/dev/null 2>"$SCRATCH/$sid.err"
chmod 755 "$home/.claude/spec-distill/$sid"; chmod 644 "$yml"
if grep -q 'residue_unclearable' "$SCRATCH/$sid.err"; then
  ok "A!(중화 불가): 지우지도 절단하지도 못하면 그 사유로 codex 축을 끈다 (조용한 통과 없음)"
else
  no "A!(중화 불가): 잔존물을 못 치웠는데 그 사실이 사유로 나오지 않는다 — stderr 는 degraded 라 하고 기계 채널은 codex 정상이라 한다"
fi

# ── D) 하류가 실제로 무엇을 보는가 (end-to-end 한 셀 + 대조군) ───────────────
# A 는 디스크를 본다. 보안 결과는 **소비자가 무엇을 섭취하는가**이므로 그 채널을 직접 잰다.
SD_SCRIPTS="$ROOT/plugins/spec-distill/scripts"
FXD="$ROOT/shared/tests/fixtures/docreview"
PROFILE_D="$ROOT/plugins/spec-distill/references/docreview-profiles/design-doc.md"
downstream() {   # downstream <상태dir> <codex 경로> → "absent|items|marks"
  python3 "$SD_SCRIPTS/docreview_route.py" prepare-recritic --state-dir "$1" \
      --critic "$FXD/critic-r1.txt" --codex "$2" > "$1/prep.json" 2>/dev/null
  python3 - "$1/prep.json" "$STALE_MARK" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
g = d.get("degrade", {})
items = d.get("items") or []
print("%s|%d|%d" % (g.get("codex_absent"), len(items),
                    json.dumps(items, ensure_ascii=False).count(sys.argv[2])))
PY
}
mk_state() {   # mk_state <dir>
  python3 "$SD_SCRIPTS/docreview_state.py" init --state-dir "$1" --doc "$FXD/design-sample.md" --profile "$PROFILE_D" >/dev/null
  python3 "$SD_SCRIPTS/docreview_anchor.py" snapshot "$FXD/design-sample.md" > "$1/s1.json"
  python3 "$SD_SCRIPTS/docreview_state.py" begin-round --state-dir "$1" --snapshot "$1/s1.json" >/dev/null
}
sid=rs09down; home="$SCRATCH/$sid"; D="$home/.claude/spec-distill/$sid"; mkdir -p "$D"
mk_state "$D"
yml="$(run_fence "$sid" "$BIN_OK" plant none 0 spec_path="$SKILL" DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1)"
got="$(downstream "$D" "$yml")"
sid=rs10ctlx; home2="$SCRATCH/$sid"; D2="$home2/.claude/spec-distill/$sid"; mkdir -p "$D2"
mk_state "$D2"
ctl="$(downstream "$D2" "$D2/never-written.yaml")"
if [ "${got%%|*}" != "True" ] || [ "${got##*|}" != "0" ]; then
  no "D: kill switch 라운드에서 하류가 codex 를 정상으로 읽는다 (absent|items|직전마커 = $got) — 사용자가 끈 축이 켜진 것으로 보고된다"
else
  ok "D: kill switch 라운드에서 하류가 codex 부재로 읽고 직전 라운드 마커를 하나도 섭취하지 않는다 ($got)"
fi
if [ "$got" = "$ctl" ]; then
  ok "D 대조군: 잔존물이 있던 라운드의 하류 판정이 «애초에 파일이 없던» 라운드와 완전히 같다 ($ctl)"
else
  no "D 대조군: 잔존물 라운드($got)와 파일 없는 라운드($ctl)의 하류 판정이 다르다 — 잔존물이 어떤 형태로든 판정에 남아 있다"
fi

# ── A2) 지우지 못하면 절단한다 — 디렉토리 쓰기 불가 · 파일 쓰기 가능 ───────────
# unlink 는 디렉토리 권한을, 절단은 파일 권한을 요구한다 — 이 조합에서 중화의 수단은 절단
# 하나다. 잔존물은 라운드 시작 «뒤» 에 심는다: 하류의 시점 판별이 아니라 절단만으로
# 중화되는지를 재기 위해서다.
sid=rs11trnc; home="$SCRATCH/$sid"; D="$home/.claude/spec-distill/$sid"; mkdir -p "$D"
mk_state "$D"
yml="$D/docreview-codex.yaml"; plant_stale "$yml"; chmod 555 "$D"
( cd "$home" && env -i PATH="$BIN_OK:$BASE" HOME="$home" CODEX_API_KEY=t \
    PYTHONDONTWRITEBYTECODE=1 CLAUDE_PLUGIN_ROOT="$PR" DEVBREW_SPEC_DISTILL_SESSION_ID="$sid" \
    STUB_WRITE=none STUB_RC=0 spec_path="$SKILL" DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1 \
    bash "$FENCE" ) >/dev/null 2>"$SCRATCH/$sid.err"
chmod 755 "$D"
got="$(post_state "$yml")"
if [ "$got" = "0byte" ]; then
  ok "A2(절단): 지우지 못한 잔존물이 0바이트로 절단됐다"
else
  no "A2(절단): 사후상태 $got — 지우지 못한 잔존물이 절단되지 않았다"
fi
got="$(downstream "$D" "$yml")"
if [ "${got%%|*}" = "True" ] && [ "${got##*|}" = "0" ]; then
  ok "A2(절단): 하류가 절단된 파일을 codex 부재로 읽고 직전 라운드 마커를 섭취하지 않는다 ($got)"
else
  no "A2(절단): 하류가 그 파일을 codex 판정으로 읽는다 (absent|items|직전마커 = $got)"
fi

# ── A3) 중화가 불가능한 조합 — 집행은 하류의 시점 판별이다 ──────────────────
# 디렉토리·파일 둘 다 쓰기 불가여도 상태 파일이 쓰기 가능하면 1단계 `begin-round` 는
# 통과한다(상태 파일은 제자리 덮어쓰기다). 그 라운드에 펜스는 잔존물을 치우지 못하고, 5단계는
# 새 셸에서 같은 경로를 다시 도출해 넘긴다 — 판정을 지키는 것은 `prepare-recritic` 이
# 라운드 시작보다 먼저 쓰인 파일을 부재로 읽는 것 하나다.
prep_view() {   # prep_view <prep.json> → "absent|reason|직전마커"
  python3 - "$1" "$STALE_MARK" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
g = d.get("degrade", {})
print("%s|%s|%d" % (g.get("codex_absent"), g.get("codex_reason"),
                    json.dumps(d.get("items") or [], ensure_ascii=False).count(sys.argv[2])))
PY
}
sid=rs12pred; home="$SCRATCH/$sid"; D="$home/.claude/spec-distill/$sid"; mkdir -p "$D"
mk_state "$D"                                    # 라운드 1
yml="$D/docreview-codex.yaml"; plant_stale "$yml"  # 라운드 1 의 codex 산출물
# 직전 라운드의 산출물은 라운드 1 시작 «뒤» · 라운드 2 시작 «앞» 에 쓰인다. 라운드 1 시작을 120초
# 되돌리고 파일을 그 +60초(ns 명시)에 둔다 — 어떤 타임스탬프 해상도에서도 두 시작 사이다.
python3 -c 'import os, sys
sys.path.insert(0, sys.argv[1]); import docreview_state as s
st = s.load_state(sys.argv[2]); r = st["rounds"]["1"]
r["started_mtime_ns"] = int(r["started_mtime_ns"]) - 120 * 10**9; s.save_state(sys.argv[2], st)
t = r["started_mtime_ns"] + 60 * 10**9; os.utime(sys.argv[3], ns=(t, t))' "$SD_SCRIPTS" "$D" "$yml"
chmod 444 "$yml"; chmod 555 "$D"
python3 "$SD_SCRIPTS/docreview_anchor.py" snapshot "$FXD/design-sample.md" > "$SCRATCH/$sid.s2.json"
python3 "$SD_SCRIPTS/docreview_state.py" begin-round --state-dir "$D" --snapshot "$SCRATCH/$sid.s2.json" >/dev/null 2>&1; brc=$?
rnd="$(python3 "$FXD/st_get.py" "$D/docreview-state.md" 'st["round"]' 2>/dev/null)"
win="$(python3 -c 'import os, sys, yaml; t = open(sys.argv[1], encoding="utf-8").read(); r = yaml.safe_load(t[4:t.find("\n---\n", 4)])["docreview"]["rounds"]; m = os.stat(sys.argv[2]).st_mtime_ns; a = (r.get("1") or {}).get("started_mtime_ns"); b = (r.get("2") or {}).get("started_mtime_ns"); print(a is not None and b is not None and int(a) < m < int(b))' "$D/docreview-state.md" "$yml" 2>/dev/null)"
( cd "$home" && env -i PATH="$BIN_OK:$BASE" HOME="$home" CODEX_API_KEY=t \
    PYTHONDONTWRITEBYTECODE=1 CLAUDE_PLUGIN_ROOT="$PR" DEVBREW_SPEC_DISTILL_SESSION_ID="$sid" \
    STUB_WRITE=none STUB_RC=0 spec_path="$SKILL" DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1 \
    bash "$FENCE" ) >/dev/null 2>"$SCRATCH/$sid.err"
left="$(post_state "$yml")"
python3 "$SD_SCRIPTS/docreview_route.py" prepare-recritic --state-dir "$D" --critic "$FXD/critic-r1.txt" \
    --codex "$yml" > "$SCRATCH/$sid.prep.json" 2>/dev/null
chmod 755 "$D"; chmod 644 "$yml"
if [ "$brc" = "0" ] && [ "$rnd" = "2" ] && [ "$win" = "True" ] && [ "$left" != "absent" ] && [ "$left" != "0byte" ]; then
  ok "A3 전제: 이 조합에서 1단계는 통과하고(rc 0, 라운드 2) 잔존물은 두 라운드 시작 사이에 있으며 펜스는 그것을 치우지 못한다 ($left)"
else
  no "A3 전제 붕괴: begin-round rc=$brc 라운드=$rnd 두 시작 사이=$win 잔존=$left — 이 셀은 하류 판별을 재지 못한다"
fi
got="$(prep_view "$SCRATCH/$sid.prep.json")"
if [ "$got" = "True|codex_predates_round|0" ]; then
  ok "A3(시점): 치우지 못한 직전 라운드 산출물을 하류가 부재로 읽는다 — 섭취 0 ($got)"
else
  no "A3(시점): 하류가 직전 라운드 산출물을 이번 라운드 판정으로 읽는다 (absent|reason|직전마커 = $got)"
fi

# ── E) 셸 옵션 상속 — `set -euo pipefail` 을 앞에 붙여도 같은 사후상태인가 ──────
# 앞 블록의 errexit 는 실패한 명령 하나로 펜스를 죽인다. 중화 명령이 실패하는 권한 조합이나
# 러너의 non-zero 에서 펜스가 죽으면 잔존물이 살고 SKIPPED 공시조차 안 난다. 판정은 평상시
# 실행(A 의 쌍둥이 셀)과 **같은 디스크 사후상태** + skip 경로의 공시 줄이다.
errexit_case() {   # errexit_case <라벨> <sid> <쌍둥이 sid> <bin> <stub_write> <stub_rc> <기대 사유|-> [env…]
  local label="$1" sid="$2" twin="$3" bin="$4" sw="$5" rc="$6" why="$7"; shift 7
  local yml got want
  yml="$(RUN_FENCE="$FENCE_E" run_fence "$sid" "$bin" plant "$sw" "$rc" "$@")"
  got="$(post_state "$yml")"; want="$(post_state "$(yml_of "$twin")")"
  if [ "$got" = "$want" ] && neutralised "$yml"; then
    ok "E($label): errexit 아래서도 디스크 사후상태가 평상시와 같다 ($got)"
  else
    no "E($label): errexit 아래 사후상태 $got ≠ 평상시 $want — 펜스가 중간에 죽었다"
  fi
  [ "$why" = "-" ] && return 0
  if grep -q "codex co-review SKIPPED (reason: $why)" "$SCRATCH/$sid.err"; then
    ok "E($label): errexit 아래서도 SKIPPED 공시가 난다 (reason: $why)"
  else
    no "E($label): errexit 아래서 SKIPPED (reason: $why) 공시가 없다 — 펜스가 조용히 죽었다"
  fi
}
errexit_case "kill switch"      rs21kill rs01kill "$BIN_OK"   none 0 kill_switch         spec_path="$SKILL" DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1
errexit_case "codex 미설치"      rs22noin rs02noin "$BIN_NONE" none 0 not_installed       spec_path="$SKILL"
errexit_case "게이트 입력 부재"   rs23noip rs03noip "$BIN_OK"   none 0 gate_inputs_missing
errexit_case "러너 rc=3 (껍데기)" rs25rc3x rs05rc3x "$BIN_OK"   husk 3 -                   spec_path="$SKILL"
mv "$DETECTOR" "$SCRATCH/detector.bak"
errexit_case "감지기 부재"       rs24nodt rs04nodt "$BIN_OK"   none 0 detector_not_runnable spec_path="$SKILL"
mv "$SCRATCH/detector.bak" "$DETECTOR"
# 중화 불가 조합(A 의 셋째 층과 같은 잠금) — 지우기·절단의 실패가 errexit 로 펜스를 죽이면
# residue_unclearable 공시가 사라진다.
sid=rs26lock; home="$SCRATCH/$sid"; D="$home/.claude/spec-distill/$sid"; mkdir -p "$D"
yml="$D/docreview-codex.yaml"; plant_stale "$yml"; chmod 444 "$yml"; chmod 555 "$D"
( cd "$home" && env -i PATH="$BIN_OK:$BASE" HOME="$home" CODEX_API_KEY=t \
    PYTHONDONTWRITEBYTECODE=1 CLAUDE_PLUGIN_ROOT="$PR" DEVBREW_SPEC_DISTILL_SESSION_ID="$sid" \
    STUB_WRITE=none STUB_RC=0 spec_path="$SKILL" DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1 \
    bash "$FENCE_E" ) >/dev/null 2>"$SCRATCH/$sid.err"
chmod 755 "$D"; chmod 644 "$yml"
got="$(post_state "$yml")"; want="$(post_state "$(yml_of rs08lock)")"
if [ "$got" = "$want" ]; then
  ok "E(중화 불가): errexit 아래서도 디스크 사후상태가 평상시와 같다 ($got)"
else
  no "E(중화 불가): errexit 아래 사후상태 $got ≠ 평상시 $want"
fi
if grep -q 'codex co-review SKIPPED (reason: residue_unclearable)' "$SCRATCH/$sid.err"; then
  ok "E(중화 불가): 지우기·절단의 실패가 펜스를 죽이지 않고 residue_unclearable 로 공시된다"
else
  no "E(중화 불가): errexit 아래서 residue_unclearable 공시가 없다 — 지우기 또는 절단의 실패가 펜스를 죽였다"
fi
# sid 미해석 — 경로를 도출할 수 없는 채로 들어온 라운드. 도출 실패의 rc 가 errexit 로 펜스를
# 죽이면 gate_inputs_missing 공시가 사라진다.
home="$SCRATCH/nosid-e"; mkdir -p "$home"
( cd "$home" && env -i PATH="$BIN_OK:$BASE" HOME="$home" CODEX_API_KEY=t \
    PYTHONDONTWRITEBYTECODE=1 CLAUDE_PLUGIN_ROOT="$PR" STUB_WRITE=none STUB_RC=0 spec_path="$SKILL" \
    bash "$FENCE_E" ) >/dev/null 2>"$SCRATCH/nosid-e.err"
if grep -q 'codex co-review SKIPPED (reason: gate_inputs_missing)' "$SCRATCH/nosid-e.err"; then
  ok "E(sid 미해석): 세션 id 도출 실패가 펜스를 죽이지 않고 gate_inputs_missing 으로 공시된다"
else
  no "E(sid 미해석): errexit 아래서 gate_inputs_missing 공시가 없다 — 도출 실패가 펜스를 죽였다"
fi
finish
