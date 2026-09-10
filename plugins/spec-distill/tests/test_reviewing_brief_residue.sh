#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/spec-distill/scripts/detect_codex.sh plugins/spec-distill/scripts/codex-killswitch.conf shared/docreview/scripts/docreview_state.py plugins/spec-distill/scripts/build_brief_bundle.py
#
# `reviewing-brief` 의 codex 게이트 fence · `## 입력` · `## 번들` 블록을 **잘라내 차가운 셸
# (`env -i`)에서 실행**해 디스크 사후상태를 잰다. 읽어서 판정하지 않는다 — 읽으면 옳아 보이는
# fence 가 미할당 변수로 죽는 결함은 실행으로만 드러난다.
#
# 축은 `test_reviewing_spec_residue.sh` 와 같다:
#   A  skip 경로마다 직전 라운드 codex 산출물이 중화되는가(부재 또는 0바이트 — 둘 다 하류 fail-closed)
#   A+ 이번 실행이 쓴 산출물은 살아남는가(부재 단언의 양의 짝 — 「언제나 지운다」 판본을 잡는다)
#   A! 중화가 불가능하면 조용히 넘어가지 않고 residue_unclearable 로 codex 축을 끄는가
#   D  하류(`prepare-recritic`)가 실제로 무엇을 섭취하는가 — 대조군과 같은가
#   A2 지우지 못하면 절단하는가 · A3 둘 다 못 하는 조합에서 하류의 시점 판별이 막는가(그 전제 포함)
#   E  앞 블록의 `set -euo pipefail` 을 물려받아도 같은 사후상태·같은 공시인가
#   P  문서별 자리가 실행으로 갈리는가 · S sweep 이 codex 산출물만 지우는가 · S! sweep 의 중화 불가 공시
# 이 자리에만 있는 것:
#   · 게이트 입력이 하나 더 있다(번들) — 번들 부재도 codex 를 건너뛰는 skip 경로다(A·E 번들 부재).
#   · R 러너 인자 넷의 실측 — 넷 다 비지 않고, 둘째가 payload 가 아니라 번들인가.
#   · P×자리 — 같은 세션에서 design doc 자리(`reviewing-spec`)와 brief 자리가 다른 자리를 받는가.
#   · S×자리 — brief 쪽 sweep 이 design doc 자리의 codex 산출물까지 중화하되 번들·원장은 남기는가.
#   · B 번들 조립이 실패한 라운드가 직전 번들을 남기지 않는가, 그 뒤 fence 가 codex 를 건너뛰는가.
#   · H 따로 도는 블록(Bash 호출마다 새 셸) — `## 입력` 만 돌아도 payload 가 절대경로가 되는가(I1),
#     `## 번들` 이 머리 없이 들어온 상대경로로도 조립되는가, 진입 게이트 실패가 직전 번들을 세 층으로
#     치우는가(M2), 상태 디렉토리 부재의 사유를 가르는가, 따로 돈 degrade-append 의 record 가 원장 또는
#     두 번째 채널에 닿는가(M3).
# 감지기와 kill switch 설정은 리포 정본을 복사해 쓰고 러너만 스텁이다. PATH 는 진짜 `$PATH` 를
# 이어붙이지 않는다 — 실제 codex 로 새는 경로를 막는다. 리포의 배포 지점은 건드리지 않는다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$ROOT/plugins/spec-distill/skills/reviewing-brief/SKILL.md"
SPEC_SKILL="$ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/skills/reviewing-brief/SKILL.md"
  echo "plugins/spec-distill/skills/reviewing-spec/SKILL.md"
  echo "plugins/spec-distill/scripts/detect_codex.sh"
  echo "plugins/spec-distill/scripts/codex-killswitch.conf"
  echo "shared/docreview/scripts/docreview_state.py"
  echo "plugins/spec-distill/scripts/build_brief_bundle.py"
  exit 0
fi

. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

SCRATCH="$(mktemp -d -t sd-rb-residue-XXXXXX)" || { echo "scratch 생성 실패" >&2; exit 1; }
cleanup() { chmod -R u+w "$SCRATCH" 2>/dev/null; rm -rf "$SCRATCH"; }
trap cleanup EXIT

OLD='STALE_BRIEF_ROUND1_k3'
NEW='THIS_BRIEF_ROUND_w8'

# ── 블록 추출 ────────────────────────────────────────────────────────────────
cut_fence() {   # cut_fence <SKILL> → codex-gate 마커 사이의 bash 블록
  awk '/codex-gate:begin[[:space:]]+runner=run_docreview_codex_reviewer\.sh/ {g=1; next}
       /codex-gate:end/ {g=0}
       g && /^```bash$/ {b=1; next}
       g && b && /^```$/ {b=0; next}
       g && b' "$1"
}
cut_block() {   # cut_block <SKILL> <절 헤딩 정규식> → 그 절의 첫 bash 블록
  H="$2" awk '$0 ~ ENVIRON["H"] {s=1; next}
       s && /^## / {exit}
       s && !done && /^```bash$/ {b=1; next}
       s && b && /^```$/ {b=0; done=1; next}
       s && b' "$1"
}
FENCE="$SCRATCH/fence.sh";  cut_fence "$SKILL" > "$FENCE"
INPUT="$SCRATCH/input.sh";  cut_block "$SKILL" '^## 입력$' > "$INPUT"
BUNDLE_BLK="$SCRATCH/bundle.sh"; cut_block "$SKILL" '^## 번들' > "$BUNDLE_BLK"
S_INPUT="$SCRATCH/spec-input.sh"; cut_block "$SPEC_SKILL" '^## 입력$' > "$S_INPUT"
S_FENCE="$SCRATCH/spec-fence.sh"; cut_fence "$SPEC_SKILL" > "$S_FENCE"
n_fence="$(grep -c . "$FENCE" || true)"
if [ "${n_fence:-0}" -lt 10 ]; then
  no "추출: brief codex-gate fence 가 ${n_fence:-0}줄이다 — 마커가 사라졌거나 추출이 깨졌다. 아래 판정은 전부 무의미하다"
  finish; exit
fi
for pair in 'fence:'"$FENCE"':run_docreview_codex_reviewer\.sh" "\$PROFILE" "\$BUNDLE"' \
            "입력:$INPUT:^STATE_DIR=" "입력:$INPUT:^BUNDLE=" \
            "번들:$BUNDLE_BLK:build_brief_bundle.py" \
            "reviewing-spec 입력:$S_INPUT:^STATE_DIR=" "reviewing-spec fence:$S_FENCE:run_docreview_codex_reviewer.sh"; do
  label="${pair%%:*}"; rest="${pair#*:}"; f="${rest%%:*}"; pat="${rest#*:}"
  if grep -qE -- "$pat" "$f" 2>/dev/null && bash -n "$f" 2>/dev/null; then
    ok "추출: $label 블록이 '$pat' 을 담고 bash -n 을 통과한다"
  else
    no "추출: $label 블록이 비었거나 '$pat' 이 없거나 문법이 깨졌다 — 그 블록을 쓰는 판정은 무의미하다"
  fi
done
FENCE_E="$SCRATCH/fence-errexit.sh"; { echo 'set -euo pipefail'; cat "$FENCE"; } > "$FENCE_E"

# ── 가짜 플러그인 루트 + 문서 ────────────────────────────────────────────────
PR="$SCRATCH/plugin"; mkdir -p "$PR/scripts"
for f in state_path.py detect_codex.sh codex-killswitch.conf docreview_state.py; do
  cp "$ROOT/plugins/spec-distill/scripts/$f" "$PR/scripts/"
done
ln -s "$ROOT/plugins/spec-distill/scripts/build_brief_bundle.py" "$PR/scripts/build_brief_bundle.py"
ln -s "$ROOT/plugins/spec-distill/references" "$PR/references"
DETECTOR="$PR/scripts/detect_codex.sh"
cat > "$PR/scripts/run_docreview_codex_reviewer.sh" <<'STUB'
#!/usr/bin/env bash
# 스텁 러너 — 실물의 계약(인자 넷 · 산출물 기록 · rc)만 흉내낸다.
[ -n "${STUB_ARGV_OUT:-}" ] && printf '%s\n' "$1" "$2" "$3" "$4" > "$STUB_ARGV_OUT"
case "${STUB_WRITE:-none}" in
  ok)     printf 'findings:\n  - agent: codex-reviewer\n    ref: t1\n    layer: 2\n    category: distortion\n    anchor: "#2-제약"\n    disposition: fix\n    summary: "THIS_BRIEF_ROUND_w8"\n    evidence: null\nmeta:\n  codex_failed: false\n  exit_code: 0\n' > "$4" ;;
  honest) printf 'findings: []\nmeta:\n  codex_failed: true\n  reason: aborted_before_completion\n  exit_code: 0\n' > "$4" ;;
  husk)   : > "$4" ;;
  none)   : ;;
esac
exit "${STUB_RC:-0}"
STUB
chmod +x "$PR/scripts/run_docreview_codex_reviewer.sh"
BIN_OK="$SCRATCH/bin-ok"; BIN_NONE="$SCRATCH/bin-none"; mkdir -p "$BIN_OK" "$BIN_NONE"
printf '#!/usr/bin/env bash\n[ "${1:-}" = "--version" ] && { echo "codex-cli 0.145.0"; exit 0; }\nexit 0\n' > "$BIN_OK/codex"
chmod +x "$BIN_OK/codex"
cp "$ROOT/plugins/quality-gates/tests/mocks/bin-stubs/"* "$BIN_OK/"   2>/dev/null || true
cp "$ROOT/plugins/quality-gates/tests/mocks/bin-stubs/"* "$BIN_NONE/" 2>/dev/null || true
BASE="/usr/bin:/bin"

FX="$ROOT/shared/tests/fixtures/docreview"
DOCS="$SCRATCH/docs"; mkdir -p "$DOCS"
cp "$FX/brief-sample.md" "$DOCS/brief-sample.md"
printf -- '---\nx: 1\n---\n\n## 6. 사용자 원문\n\n- id: S2\n  source: verbatim\n  round: 1\n  text: "둘째 발화"\n\n## 7. 확산 원자료\n\n없음\n' > "$DOCS/brief-sample.audit.md"
DOC_B="$DOCS/brief-sample.md"; AUD_B="$DOCS/brief-sample.audit.md"
DOC_D="$FX/design-sample.md"
PROF_B="$ROOT/plugins/spec-distill/references/docreview-profiles/brief.md"
SDS="$ROOT/plugins/spec-distill/scripts"

where() {   # where <sid> <doc> → 그 세션·문서의 엔진 상태 디렉토리 (fence 와 같은 엔진 도출)
  python3 "$PR/scripts/docreview_state.py" state-dir-for \
      --root "$SCRATCH/$1/.claude/spec-distill" --session "$1" --doc "$2" 2>/dev/null
}
real() { python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"; }
state_of() {   # state_of <path> → absent | 0byte | <N>B
  if [ ! -e "$1" ]; then echo absent
  elif [ ! -s "$1" ]; then echo 0byte
  else printf '%sB\n' "$(wc -c < "$1" | tr -d ' ')"; fi
}
cleared() { [ ! -s "$1" ]; }
stale_into() {   # stale_into <path> — 직전 라운드가 정상으로 끝낸 codex 산출물
  printf 'findings:\n  - agent: codex-reviewer\n    ref: s1\n    layer: 2\n    category: distortion\n    anchor: "#2-제약"\n    disposition: fix\n    summary: "%s"\n    evidence: null\nmeta:\n  codex_failed: false\n  exit_code: 0\n' "$OLD" > "$1"
}

# ── 계측기 전제 — 쓰는 sid 전부가 세션 이름 검사와 문서별 도출을 통과하는가 ────
SIDS="rb01kill rb02noin rb03nopl rb04nobd rb05rc3x rb06nodt rb07keep rb08trap rb09lock
      rb10down rb11ctlx rb12trnc rb13pred rb21kill rb22noin rb23nopl rb24nobd rb25rc3x
      rb26nodt rb27lock rb30plce rb31swep rb32swpe rb33swlk rb34swle rb40bndl rb41bndf rb42bnde rb43bndk
      rb50relx rb51relb rb52gtrm rb53gttr rb54gtst rb55gtre rb56bdst rb57nopl rb58apnd"
bad=""
for s in $SIDS; do
  DEVBREW_SPEC_DISTILL_SESSION_ID="$s" python3 "$PR/scripts/state_path.py" session-id >/dev/null 2>&1 || bad="$bad $s"
  [ -n "$(where "$s" "$DOC_B")" ] || bad="$bad $s(state-dir-for)"
done
[ -z "$bad" ] \
  && ok "전제: 이 락의 sid 전부가 state_path.py 세션 검사와 state-dir-for 를 통과한다 (도출이 조용히 죽지 않는다)" \
  || no "전제: sid 도출 실패 —$bad. 그 셀들은 \$CODEX_YAML 이 비어 아무것도 재지 못한다"

# `fire <sid> <bin> <plant|-> <stub_write> <stub_rc> [env…]` → 산출물 경로를 stdout 으로.
# 자리는 `${AT_DOC:-$DOC_B}` 의 것이고, `NO_BUNDLE` 이 비어 있으면 그 자리에 이번 라운드 번들을 둔다
# (번들이 없으면 모든 경로가 gate_inputs_missing 으로 합쳐져 skip 사유를 가를 수 없다).
fire() {
  local sid="$1" bin="$2" plant="$3" sw="$4" rc="$5"; shift 5
  local home="$SCRATCH/$sid" at yml
  at="$(where "$sid" "${AT_DOC:-$DOC_B}")"; [ -n "$at" ] || at="$home/.noplace"
  mkdir -p "$at"; yml="$at/docreview-codex.yaml"
  [ "$plant" = "plant" ] && stale_into "$yml"
  [ -n "${NO_BUNDLE:-}" ] || printf 'bundle %s\n' "$sid" > "$at/brief-bundle.md"
  ( cd "$home" && env -i PATH="$bin:$BASE" HOME="$home" CODEX_API_KEY=t PYTHONDONTWRITEBYTECODE=1 \
      CLAUDE_PLUGIN_ROOT="$PR" DEVBREW_SPEC_DISTILL_SESSION_ID="$sid" \
      STUB_WRITE="$sw" STUB_RC="$rc" STUB_ARGV_OUT="$SCRATCH/$sid.argv" \
      "$@" bash "${WITH_FENCE:-$FENCE}" ) >/dev/null 2>"$SCRATCH/$sid.err"
  printf '%s' "$yml"
}

# ── A) skip 경로 다섯 + 러너 rc 3 ─────────────────────────────────────────────
a_case() {   # a_case <라벨> <sid> <bin> <stub_write> <stub_rc> [env…]
  local label="$1" sid="$2" bin="$3" sw="$4" rc="$5"; shift 5
  local yml; yml="$(fire "$sid" "$bin" plant "$sw" "$rc" "$@")"
  cleared "$yml" \
    && ok "A($label): 직전 라운드 codex 산출물이 중화됐다 ($(state_of "$yml"))" \
    || no "A($label): 직전 라운드 산출물이 $(state_of "$yml") 로 남았다 — 5단계가 그것을 이번 라운드 codex 판정으로 읽는다"
}
a_case "kill switch"              rb01kill "$BIN_OK"   none 0 PAYLOAD="$DOC_B" DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1
a_case "codex 미설치"              rb02noin "$BIN_NONE" none 0 PAYLOAD="$DOC_B"
a_case "게이트 입력 부재 — payload" rb03nopl "$BIN_OK"   none 0
NO_BUNDLE=1 a_case "게이트 입력 부재 — 번들" rb04nobd "$BIN_OK" none 0 PAYLOAD="$DOC_B"
a_case "러너 rc=3 (껍데기)"        rb05rc3x "$BIN_OK"   husk 3 PAYLOAD="$DOC_B"
mv "$DETECTOR" "$SCRATCH/detector.bak"
a_case "감지기 부재"               rb06nodt "$BIN_OK"   none 0 PAYLOAD="$DOC_B"
mv "$SCRATCH/detector.bak" "$DETECTOR"
# 번들 부재는 codex 를 «가용» 상태에서 건너뛴 경로다 — 중화만 보면 러너를 없는 번들로 불러도
# 통과한다. 러너가 불리지 않았고 그 사유가 공시됐는지를 함께 본다.
if [ ! -e "$SCRATCH/rb04nobd.argv" ] && grep -q 'codex co-review SKIPPED (reason: gate_inputs_missing)' "$SCRATCH/rb04nobd.err"; then
  ok "A(번들 부재): 러너를 부르지 않고 gate_inputs_missing 으로 공시한다 (없는 번들로 codex 를 태우지 않는다)"
else
  no "A(번들 부재): 번들이 없는데 러너가 불렸거나($(state_of "$SCRATCH/rb04nobd.argv") argv) SKIPPED 공시가 없다"
fi

# ── A+) 살아야 하는 것 ────────────────────────────────────────────────────────
keep() {   # keep <라벨> <sid> <stub_write> <stub_rc> <기대 마커|-> <사유>
  local yml; yml="$(fire "$2" "$BIN_OK" plant "$3" "$4" PAYLOAD="$DOC_B")"
  if [ ! -s "$yml" ]; then no "A+($1): 이번 실행이 쓴 산출물이 사라졌다 — $6"
  elif grep -q "$OLD" "$yml"; then no "A+($1): 남은 것이 직전 라운드 것이다 — 러너의 기록이 아니라 잔존물이 살아남았다"
  elif [ "$5" = "-" ] || grep -q "$5" "$yml"; then ok "A+($1): 이번 실행이 쓴 산출물이 살아남았다 — $6"
  else no "A+($1): 파일은 남았으나 기대 마커($5)가 없다"; fi
}
keep "keep-rc0"  rb07keep ok     0   "$NEW" "무조건 지우는 판본이면 이번 라운드 codex 판정이 통째로 버려진다"
keep "keep-trap" rb08trap honest 143 "-"    "EXIT 트랩은 원래 실패의 rc 를 단 채 기록을 남긴다 — rc != 0 으로 지우면 이번 라운드의 정직한 사유가 사라진다"
grep -q 'aborted_before_completion' "$(where rb08trap "$DOC_B")/docreview-codex.yaml" 2>/dev/null \
  && ok "A+(keep-trap): 그 기록의 사유(aborted_before_completion)가 보존된다" \
  || no "A+(keep-trap): 정직한 기록의 사유가 남아 있지 않다"

# ── R) 러너 인자 넷 — 비지 않고, 둘째가 번들이다 ───────────────────────────────
argv="$SCRATCH/rb07keep.argv"
if [ "$(grep -c . "$argv" 2>/dev/null || echo 0)" = "4" ]; then
  ok "R: 러너가 인자 넷을 전부 비지 않은 채 받았다"
else
  no "R: 러너 인자가 넷이 아니거나 빈 것이 있다 ($(tr '\n' '|' < "$argv" 2>/dev/null))"
fi
a1="$(sed -n 1p "$argv" 2>/dev/null)"; a2="$(sed -n 2p "$argv" 2>/dev/null)"; a4="$(sed -n 4p "$argv" 2>/dev/null)"
at7="$(where rb07keep "$DOC_B")"
[ -n "$a1" ] && [ "$(real "$a1")" = "$(real "$PROF_B")" ] \
  && ok "R: 첫 인자가 brief 프로필이다" || no "R: 첫 인자($a1)가 brief 프로필이 아니다"
[ -n "$a2" ] && [ "$(real "$a2")" = "$(real "$at7/brief-bundle.md")" ] && [ "$(real "$a2")" != "$(real "$DOC_B")" ] \
  && ok "R: 둘째 인자가 payload 가 아니라 이 문서 자리의 번들이다 (충실도의 정답인 audit 원문이 codex 에 간다)" \
  || no "R: 둘째 인자($a2)가 이 자리의 번들이 아니다 — payload 만 받은 codex 는 audit 원문 없이 왜곡을 판정한다"
[ -n "$a4" ] && [ "$(real "$a4")" = "$(real "$at7/docreview-codex.yaml")" ] \
  && ok "R: 넷째 인자가 문서별 상태 디렉토리의 codex 산출물이다" || no "R: 넷째 인자($a4)가 도출된 산출물 경로가 아니다"

# ── A!) 중화 불가 — 사유로 codex 축을 끈다 ──────────────────────────────────────
at="$(where rb09lock "$DOC_B")"; mkdir -p "$at"; yml="$at/docreview-codex.yaml"; printf 'b\n' > "$at/brief-bundle.md"
stale_into "$yml"; chmod 444 "$yml"; chmod 555 "$at"
( cd "$SCRATCH/rb09lock" && env -i PATH="$BIN_OK:$BASE" HOME="$SCRATCH/rb09lock" CODEX_API_KEY=t PYTHONDONTWRITEBYTECODE=1 \
    CLAUDE_PLUGIN_ROOT="$PR" DEVBREW_SPEC_DISTILL_SESSION_ID=rb09lock PAYLOAD="$DOC_B" DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1 \
    bash "$FENCE" ) >/dev/null 2>"$SCRATCH/rb09lock.err"
lock_left="$(state_of "$yml")"; chmod 755 "$at"; chmod 644 "$yml"
if [ "$lock_left" = "absent" ] || [ "$lock_left" = "0byte" ]; then
  no "A! 전제 붕괴: 잠금이 중화를 막지 못했다 ($lock_left)"
elif grep -q 'codex co-review SKIPPED (reason: residue_unclearable)' "$SCRATCH/rb09lock.err"; then
  ok "A!(중화 불가): 지우지도 절단하지도 못하면 residue_unclearable 로 codex 축을 끈다 ($lock_left 잔존)"
else
  no "A!(중화 불가): 잔존물을 못 치웠는데 그 사유가 공시되지 않는다"
fi

# ── D) 하류가 실제로 무엇을 섭취하는가 (brief 프로필로 end-to-end) ───────────────
open_round() {   # open_round <dir> — brief payload 의 엔진 원장 + 라운드 1 시작
  python3 "$SDS/docreview_state.py" init --state-dir "$1" --doc "$DOC_B" --profile "$PROF_B" >/dev/null
  python3 "$SDS/docreview_anchor.py" snapshot "$DOC_B" > "$1/s1.json"
  python3 "$SDS/docreview_state.py" begin-round --state-dir "$1" --snapshot "$1/s1.json" >/dev/null
}
ingest() {   # ingest <dir> <codex 경로> → "codex_absent|items|직전 마커 수|codex_reason"
  # prep.json 은 상태 디렉토리 «옆»에 쓴다 — A3 은 그 디렉토리를 쓰기 불가로 잠근 채 하류를 부른다.
  python3 "$SDS/docreview_route.py" prepare-recritic --state-dir "$1" --critic "$FX/critic-r1.txt" \
      --codex "$2" > "$1.prep.json" 2>/dev/null
  python3 -c 'import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8")); g = d.get("degrade", {}); it = d.get("items") or []
print("%s|%d|%d|%s" % (g.get("codex_absent"), len(it), json.dumps(it, ensure_ascii=False).count(sys.argv[2]), g.get("codex_reason")))' \
      "$1.prep.json" "$OLD" 2>/dev/null || echo "unreadable"
}
at="$(where rb10down "$DOC_B")"; mkdir -p "$at"; open_round "$at"
yml="$(fire rb10down "$BIN_OK" plant none 0 PAYLOAD="$DOC_B" DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1)"
got="$(ingest "$at" "$yml")"
ct="$(where rb11ctlx "$DOC_B")"; mkdir -p "$ct"; open_round "$ct"
ctl="$(ingest "$ct" "$ct/never-written.yaml")"
case "$got" in
  True\|*\|0\|*) ok "D: kill switch 라운드에서 하류가 codex 부재로 읽고 직전 마커를 섭취하지 않는다 ($got)" ;;
  *) no "D: kill switch 라운드에서 하류가 codex 를 정상으로 읽는다 ($got) — 사용자가 끈 축이 켜진 것으로 보고된다" ;;
esac
[ "${got%|*}" = "${ctl%|*}" ] \
  && ok "D 대조군: 잔존물이 있던 라운드의 하류 판정이 파일이 애초에 없던 라운드와 같다 (${ctl%|*})" \
  || no "D 대조군: 잔존물 라운드($got)와 파일 없는 라운드($ctl)의 하류 판정이 다르다"

# ── A2) 디렉토리 쓰기 불가 · 파일 쓰기 가능 → 절단 ───────────────────────────────
at="$(where rb12trnc "$DOC_B")"; mkdir -p "$at"; open_round "$at"; printf 'b\n' > "$at/brief-bundle.md"
yml="$at/docreview-codex.yaml"; stale_into "$yml"; chmod 555 "$at"
( cd "$SCRATCH/rb12trnc" && env -i PATH="$BIN_OK:$BASE" HOME="$SCRATCH/rb12trnc" CODEX_API_KEY=t PYTHONDONTWRITEBYTECODE=1 \
    CLAUDE_PLUGIN_ROOT="$PR" DEVBREW_SPEC_DISTILL_SESSION_ID=rb12trnc PAYLOAD="$DOC_B" DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1 \
    bash "$FENCE" ) >/dev/null 2>"$SCRATCH/rb12trnc.err"
chmod 755 "$at"
[ "$(state_of "$yml")" = "0byte" ] \
  && ok "A2(절단): 지우지 못한 잔존물이 0바이트로 절단됐다" \
  || no "A2(절단): 사후상태 $(state_of "$yml") — 지우지 못한 잔존물이 절단되지 않았다"
case "$(ingest "$at" "$yml")" in
  True\|*\|0\|*) ok "A2(절단): 하류가 절단된 파일을 codex 부재로 읽는다" ;;
  *) no "A2(절단): 하류가 절단된 파일을 codex 판정으로 읽는다" ;;
esac

# ── A3) 둘 다 쓰기 불가 · 상태 파일은 쓰기 가능 — 집행은 하류의 시점 판별이다 ─────
# 전제부터 잰다: 이 조합에서 1단계는 통과하고(rc 0, 라운드 2) 잔존물은 두 라운드 시작 사이에
# 쓰였으며 fence 는 그것을 치우지 못한다. 전제가 무너지면 이 셀은 시점 판별을 재지 않는다.
at="$(where rb13pred "$DOC_B")"; mkdir -p "$at"; open_round "$at"; printf 'b\n' > "$at/brief-bundle.md"
yml="$at/docreview-codex.yaml"; stale_into "$yml"
cat > "$SCRATCH/rewind.py" <<'PY'
import os, sys
sys.path.insert(0, sys.argv[1])
import docreview_state as ds
st = ds.load_state(sys.argv[2])
r1 = st["rounds"]["1"]
r1["started_mtime_ns"] = int(r1["started_mtime_ns"]) - 120 * 10**9
ds.save_state(sys.argv[2], st)
t = r1["started_mtime_ns"] + 60 * 10**9
os.utime(sys.argv[3], ns=(t, t))
PY
cat > "$SCRATCH/between.py" <<'PY'
import os, sys
import yaml
text = open(sys.argv[1], encoding="utf-8").read()
rounds = yaml.safe_load(text[4:text.find("\n---\n", 4)])["docreview"]["rounds"]
m = os.stat(sys.argv[2]).st_mtime_ns
a = (rounds.get("1") or {}).get("started_mtime_ns"); b = (rounds.get("2") or {}).get("started_mtime_ns")
print(a is not None and b is not None and int(a) < m < int(b))
PY
python3 "$SCRATCH/rewind.py" "$SDS" "$at" "$yml"
chmod 444 "$yml"; chmod 555 "$at"
python3 "$SDS/docreview_anchor.py" snapshot "$DOC_B" > "$SCRATCH/rb13pred.s2.json"
brc=0; python3 "$SDS/docreview_state.py" begin-round --state-dir "$at" --snapshot "$SCRATCH/rb13pred.s2.json" >/dev/null 2>&1 || brc=$?
rnd="$(python3 "$FX/st_get.py" "$at/docreview-state.md" 'st["round"]' 2>/dev/null)"
win="$(python3 "$SCRATCH/between.py" "$at/docreview-state.md" "$yml" 2>/dev/null)"
( cd "$SCRATCH/rb13pred" && env -i PATH="$BIN_OK:$BASE" HOME="$SCRATCH/rb13pred" CODEX_API_KEY=t PYTHONDONTWRITEBYTECODE=1 \
    CLAUDE_PLUGIN_ROOT="$PR" DEVBREW_SPEC_DISTILL_SESSION_ID=rb13pred PAYLOAD="$DOC_B" DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1 \
    bash "$FENCE" ) >/dev/null 2>"$SCRATCH/rb13pred.err"
left="$(state_of "$yml")"
pred="$(ingest "$at" "$yml")"
chmod 755 "$at"; chmod 644 "$yml"
if [ "$brc" = "0" ] && [ "$rnd" = "2" ] && [ "$win" = "True" ] && [ "$left" != "absent" ] && [ "$left" != "0byte" ]; then
  ok "A3 전제: 1단계는 통과하고(rc 0 · 라운드 2) 잔존물은 두 라운드 시작 사이에 있으며 fence 는 그것을 치우지 못한다 ($left)"
else
  no "A3 전제 붕괴: begin-round rc=$brc 라운드=$rnd 두 시작 사이=$win 잔존=$left — 이 셀은 시점 판별을 재지 않는다"
fi
p_abs="$(printf '%s' "$pred" | cut -d'|' -f1)"; p_old="$(printf '%s' "$pred" | cut -d'|' -f3)"; p_why="$(printf '%s' "$pred" | cut -d'|' -f4)"
{ [ "$p_abs" = "True" ] && [ "$p_old" = "0" ] && [ "$p_why" = "codex_predates_round" ]; } \
  && ok "A3(시점): 치우지 못한 직전 라운드 산출물을 하류가 codex_predates_round 로 부재 처리한다 ($pred)" \
  || no "A3(시점): 하류가 직전 라운드 산출물을 이번 라운드 판정으로 읽는다 ($pred)"

# ── E) `set -euo pipefail` 을 물려받아도 같은 사후상태·같은 공시인가 ─────────────
e_case() {   # e_case <라벨> <sid> <쌍둥이 sid> <bin> <stub_write> <stub_rc> <기대 사유|-> [env…]
  local label="$1" sid="$2" twin="$3" bin="$4" sw="$5" rc="$6" why="$7"; shift 7
  local yml got want
  yml="$(WITH_FENCE="$FENCE_E" fire "$sid" "$bin" plant "$sw" "$rc" "$@")"
  got="$(state_of "$yml")"; want="$(state_of "$(where "$twin" "$DOC_B")/docreview-codex.yaml")"
  { [ "$got" = "$want" ] && cleared "$yml"; } \
    && ok "E($label): errexit 아래서도 사후상태가 평상시와 같다 ($got)" \
    || no "E($label): errexit 아래 사후상태 $got ≠ 평상시 $want — fence 가 중간에 죽었다"
  [ "$why" = "-" ] && return 0
  grep -q "codex co-review SKIPPED (reason: $why)" "$SCRATCH/$sid.err" \
    && ok "E($label): errexit 아래서도 SKIPPED 공시가 난다 (reason: $why)" \
    || no "E($label): errexit 아래서 SKIPPED (reason: $why) 공시가 없다 — fence 가 조용히 죽었다"
}
e_case "kill switch"              rb21kill rb01kill "$BIN_OK"   none 0 kill_switch           PAYLOAD="$DOC_B" DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1
e_case "codex 미설치"              rb22noin rb02noin "$BIN_NONE" none 0 not_installed         PAYLOAD="$DOC_B"
e_case "게이트 입력 부재 — payload" rb23nopl rb03nopl "$BIN_OK"   none 0 gate_inputs_missing
NO_BUNDLE=1 e_case "게이트 입력 부재 — 번들" rb24nobd rb04nobd "$BIN_OK" none 0 gate_inputs_missing PAYLOAD="$DOC_B"
e_case "러너 rc=3 (껍데기)"        rb25rc3x rb05rc3x "$BIN_OK"   husk 3 -                     PAYLOAD="$DOC_B"
mv "$DETECTOR" "$SCRATCH/detector.bak"
e_case "감지기 부재"               rb26nodt rb06nodt "$BIN_OK"   none 0 detector_not_runnable PAYLOAD="$DOC_B"
mv "$SCRATCH/detector.bak" "$DETECTOR"
at="$(where rb27lock "$DOC_B")"; mkdir -p "$at"; yml="$at/docreview-codex.yaml"; printf 'b\n' > "$at/brief-bundle.md"
stale_into "$yml"; chmod 444 "$yml"; chmod 555 "$at"
( cd "$SCRATCH/rb27lock" && env -i PATH="$BIN_OK:$BASE" HOME="$SCRATCH/rb27lock" CODEX_API_KEY=t PYTHONDONTWRITEBYTECODE=1 \
    CLAUDE_PLUGIN_ROOT="$PR" DEVBREW_SPEC_DISTILL_SESSION_ID=rb27lock PAYLOAD="$DOC_B" DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1 \
    bash "$FENCE_E" ) >/dev/null 2>"$SCRATCH/rb27lock.err"
e_left="$(state_of "$yml")"; chmod 755 "$at"; chmod 644 "$yml"
[ "$e_left" = "$lock_left" ] \
  && ok "E(중화 불가): errexit 아래서도 사후상태가 평상시와 같다 ($e_left)" \
  || no "E(중화 불가): errexit 아래 사후상태 $e_left ≠ 평상시 $lock_left"
grep -q 'codex co-review SKIPPED (reason: residue_unclearable)' "$SCRATCH/rb27lock.err" \
  && ok "E(중화 불가): 지우기·절단의 실패가 fence 를 죽이지 않고 residue_unclearable 로 공시된다" \
  || no "E(중화 불가): errexit 아래서 residue_unclearable 공시가 없다"
mkdir -p "$SCRATCH/nosid-e"
( cd "$SCRATCH/nosid-e" && env -i PATH="$BIN_OK:$BASE" HOME="$SCRATCH/nosid-e" CODEX_API_KEY=t PYTHONDONTWRITEBYTECODE=1 \
    CLAUDE_PLUGIN_ROOT="$PR" PAYLOAD="$DOC_B" bash "$FENCE_E" ) >/dev/null 2>"$SCRATCH/nosid-e.err"
grep -q 'codex co-review SKIPPED (reason: gate_inputs_missing)' "$SCRATCH/nosid-e.err" \
  && ok "E(sid 미해석): 세션 id 도출 실패가 fence 를 죽이지 않고 gate_inputs_missing 으로 공시된다" \
  || no "E(sid 미해석): errexit 아래서 gate_inputs_missing 공시가 없다 — 도출 실패가 fence 를 죽였다"

# ── P) 문서별 자리 — `## 입력` + fence 를 차가운 셸에서 실행해 경로를 관측한다 ─────
SEEN='printf "STATE=%s\nSTATE_DIR=%s\nCODEX_YAML=%s\nBUNDLE=%s\n" "${STATE:-}" "${STATE_DIR:-}" "${CODEX_YAML:-}" "${BUNDLE:-}" > "$OBS"'
{ cat "$INPUT"; cat "$FENCE"; printf '%s\n' "$SEEN"; } > "$SCRATCH/b-input-fence.sh"
{ cat "$FENCE"; printf '%s\n' "$SEEN"; } > "$SCRATCH/b-fence-only.sh"
{ cat "$S_INPUT"; cat "$S_FENCE"; printf '%s\n' "$SEEN"; } > "$SCRATCH/s-input-fence.sh"
place() {   # place <sid> <script> <관측 파일> [env…] — codex 는 kill switch 로 끈다(러너 무관)
  local sid="$1" script="$2" obs="$3"; shift 3
  mkdir -p "$SCRATCH/$sid"
  ( cd "$SCRATCH/$sid" && env -i PATH="$BIN_OK:$BASE" HOME="$SCRATCH/$sid" PYTHONDONTWRITEBYTECODE=1 \
      CLAUDE_PLUGIN_ROOT="$PR" DEVBREW_SPEC_DISTILL_SESSION_ID="$sid" DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1 \
      OBS="$obs" "$@" bash "$script" ) >/dev/null 2>"$obs.err"
}
seen() { sed -n "s/^$2=//p" "$1" 2>/dev/null; }
mkdir -p "$SCRATCH/rb30plce/docs"; cp "$DOC_B" "$SCRATCH/rb30plce/docs/rel-brief.md"
place rb30plce "$SCRATCH/b-input-fence.sh" "$SCRATCH/p-b1.obs" PAYLOAD="$DOC_B"
place rb30plce "$SCRATCH/b-input-fence.sh" "$SCRATCH/p-b2.obs" PAYLOAD="$DOC_B"
place rb30plce "$SCRATCH/b-fence-only.sh"  "$SCRATCH/p-b3.obs" PAYLOAD="$DOC_B"
place rb30plce "$SCRATCH/s-input-fence.sh" "$SCRATCH/p-s1.obs" spec_path="$DOC_D"
place rb30plce "$SCRATCH/b-input-fence.sh" "$SCRATCH/p-r1.obs" PAYLOAD="docs/rel-brief.md"
place rb30plce "$SCRATCH/b-input-fence.sh" "$SCRATCH/p-r2.obs" PAYLOAD="$SCRATCH/rb30plce/docs/rel-brief.md"
b_dir="$(seen "$SCRATCH/p-b1.obs" STATE_DIR)"; b_yml="$(seen "$SCRATCH/p-b1.obs" CODEX_YAML)"; b_bnd="$(seen "$SCRATCH/p-b1.obs" BUNDLE)"
b2_dir="$(seen "$SCRATCH/p-b2.obs" STATE_DIR)"; b3_yml="$(seen "$SCRATCH/p-b3.obs" CODEX_YAML)"; b3_bnd="$(seen "$SCRATCH/p-b3.obs" BUNDLE)"
s_dir="$(seen "$SCRATCH/p-s1.obs" STATE_DIR)"; s_yml="$(seen "$SCRATCH/p-s1.obs" CODEX_YAML)"
r1_dir="$(seen "$SCRATCH/p-r1.obs" STATE_DIR)"; r2_dir="$(seen "$SCRATCH/p-r2.obs" STATE_DIR)"
b_state="$(seen "$SCRATCH/p-b1.obs" STATE)"
if [ -n "$b_dir" ] && [ -n "$b_yml" ] && [ -n "$b_bnd" ] && [ -n "$s_dir" ] && [ -n "$s_yml" ] && [ -n "$r1_dir" ]; then
  ok "P 전제: brief·design doc 두 자리와 상대경로 호출 모두 STATE_DIR·CODEX_YAML(·BUNDLE) 을 도출한다 (빈 값끼리의 비교가 아니다)"
else
  no "P 전제 붕괴: brief='$b_dir'/'$b_yml'/'$b_bnd' design='$s_dir'/'$s_yml' 상대='$r1_dir' — 아래 비교는 공허하다 ($(head -c 300 "$SCRATCH/p-b1.obs.err" 2>/dev/null))"
fi
[ "$b_dir" != "$s_dir" ] && [ "$b_yml" != "$s_yml" ] \
  && ok "P×자리: 같은 세션에서 design doc 자리와 brief 자리가 다른 STATE_DIR · 다른 codex 산출물을 받는다" \
  || no "P×자리: 두 자리가 같은 자리를 나눠 쓴다 ($b_dir = $s_dir) — 둘째 자리가 첫 자리의 라운드·상한·finding 을 물려받는다"
[ -n "$b_dir" ] && [ "$b2_dir" = "$b_dir" ] \
  && ok "P2: 같은 payload 를 새 셸에서 다시 도출하면 같은 자리다 (라운드 연속성)" \
  || no "P2: 같은 payload 의 재도출이 다른 자리를 낸다 ($b_dir → $b2_dir)"
[ -n "$b_yml" ] && [ "$b3_yml" = "$b_yml" ] && [ "$b3_bnd" = "$b_bnd" ] \
  && ok "P3: \`## 입력\` 없이 fence 만 돌아도 같은 codex 산출물 · 같은 번들을 도출한다" \
  || no "P3: fence 단독 도출($b3_yml · $b3_bnd)이 \`## 입력\` 경유($b_yml · $b_bnd)와 다르다"
[ -n "$b_dir" ] && [ "$b_yml" = "$b_dir/docreview-codex.yaml" ] && [ "$b_bnd" = "$b_dir/brief-bundle.md" ] \
  && ok "P4: codex 산출물과 번들이 그 payload 의 상태 디렉토리 안에 있다" \
  || no "P4: codex 산출물($b_yml) 또는 번들($b_bnd)이 상태 디렉토리($b_dir) 밖이다"
[ -n "$r1_dir" ] && [ "$r1_dir" = "$r2_dir" ] \
  && ok "P5: 상대경로 payload 가 절대경로와 같은 자리를 받는다 (엔진은 상대 --doc 을 거부한다 — 자리가 cwd 의 함수가 되지 않는다)" \
  || no "P5: 상대경로 payload 의 자리($r1_dir)가 절대경로의 자리($r2_dir)와 다르다"
sess="${b_state%/state.local.md}"
[ -n "$b_state" ] && [ "$sess" != "$b_state" ] && [ "${b_dir%/*}" = "$sess/docreview" ] && [ "${s_dir%/*}" = "$sess/docreview" ] \
  && ok "P6: degrade 원장(\$STATE)은 세션의 한 파일이고 두 자리의 문서별 디렉토리는 같은 세션 아래 docreview/ 에 앉는다" \
  || no "P6: degrade 원장 또는 문서별 디렉토리의 자리가 어긋났다 (STATE $b_state · $b_dir · $s_dir)"

# ── S) 문서 미상 sweep — 범위·자리 교차 ────────────────────────────────────────
# brief 쪽 fence 가 `$PAYLOAD` 없이 돌면 세션의 문서별 codex 산출물 전부를 훑는다. 같은 세션에
# 살아야 할 것 — degrade 원장 · 다른 이름의 파일 · brief 엔진 원장 · critic 원문 · **번들** ·
# design doc 자리의 엔진 원장 — 을 심고 바이트 동일을 잰다. 두 자리의 codex 산출물이 모두
# 중화되는 것은 「문서를 모르면 전부가 후보」의 양의 쪽이다.
sweep_case() {   # sweep_case <라벨> <sid> <fence>
  local label="$1" sid="$2" fence="$3" home S AB AD g i f lost=""
  home="$SCRATCH/$sid"; S="$home/.claude/spec-distill/$sid"
  AB="$(where "$sid" "$DOC_B")"; AD="$(where "$sid" "$DOC_D")"; mkdir -p "$AB" "$AD"
  printf 'brief_review_degradations: []\n' > "$S/state.local.md"
  printf 'unrelated\n' > "$S/notes-unrelated.txt"
  open_round "$AB"
  printf 'critic verbatim\n' > "$AB/critic.txt"
  printf 'bundle bytes\n<<<AUDIT-VERBATIM>>>\n' > "$AB/brief-bundle.md"
  printf -- '---\ndocreview: {doc: design}\n---\n' > "$AD/docreview-state.md"
  stale_into "$AB/docreview-codex.yaml"; stale_into "$AD/docreview-codex.yaml"
  g="$SCRATCH/$sid.golden"; mkdir -p "$g"; i=0
  for f in "$S/state.local.md" "$S/notes-unrelated.txt" "$AB/docreview-state.md" "$AB/critic.txt" "$AB/brief-bundle.md" "$AD/docreview-state.md"; do
    i=$((i+1)); cp "$f" "$g/$i"
  done
  ( cd "$home" && env -i PATH="$BIN_OK:$BASE" HOME="$home" CODEX_API_KEY=t PYTHONDONTWRITEBYTECODE=1 \
      CLAUDE_PLUGIN_ROOT="$PR" DEVBREW_SPEC_DISTILL_SESSION_ID="$sid" bash "$fence" ) >/dev/null 2>"$SCRATCH/$sid.err"
  { [ "$AB" != "$AD" ] && grep -q 'codex co-review SKIPPED (reason: gate_inputs_missing)' "$SCRATCH/$sid.err"; } \
    && ok "S($label) 전제: 두 자리가 다르고 fence 가 문서 미상 경로(gate_inputs_missing)로 돌았다" \
    || no "S($label) 전제 붕괴: 두 자리가 같거나 fence 가 sweep 경로로 돌지 않았다"
  i=0
  for f in "$S/state.local.md" "$S/notes-unrelated.txt" "$AB/docreview-state.md" "$AB/critic.txt" "$AB/brief-bundle.md" "$AD/docreview-state.md"; do
    i=$((i+1)); cmp -s "$g/$i" "$f" 2>/dev/null || lost="$lost ${f#"$S"/}"
  done
  [ -z "$lost" ] \
    && ok "S($label): degrade 원장 · 다른 이름의 파일 · 두 자리의 엔진 원장 · critic 원문 · 번들이 바이트 동일로 남는다" \
    || no "S($label): sweep 이 살아야 할 파일을 지우거나 바꿨다:$lost"
  { cleared "$AB/docreview-codex.yaml" && cleared "$AD/docreview-codex.yaml"; } \
    && ok "S($label): brief 자리와 design doc 자리의 codex 산출물이 모두 중화된다 (자리 교차 — 양의 쪽)" \
    || no "S($label): 중화되지 않은 자리가 있다 (brief $(state_of "$AB/docreview-codex.yaml") · design $(state_of "$AD/docreview-codex.yaml"))"
}
sweep_case "평상시" rb31swep "$FENCE"
sweep_case "errexit" rb32swpe "$FENCE_E"
sweep_lock() {   # sweep_lock <라벨> <sid> <fence>
  local label="$1" sid="$2" fence="$3" at yml left tail
  at="$(where "$sid" "$DOC_B")"; mkdir -p "$at"; yml="$at/docreview-codex.yaml"
  stale_into "$yml"; chmod 444 "$yml"; chmod 555 "$at"
  ( cd "$SCRATCH/$sid" && env -i PATH="$BIN_OK:$BASE" HOME="$SCRATCH/$sid" CODEX_API_KEY=t PYTHONDONTWRITEBYTECODE=1 \
      CLAUDE_PLUGIN_ROOT="$PR" DEVBREW_SPEC_DISTILL_SESSION_ID="$sid" bash "$fence" ) >/dev/null 2>"$SCRATCH/$sid.err"
  left="$(state_of "$yml")"; chmod 755 "$at"; chmod 644 "$yml"
  tail="${yml#"$SCRATCH"/}"   # fence 는 cwd 의 물리 경로로 적는다 — 스크래치 뒤 꼬리로 대조한다
  if [ "$left" = "absent" ] || [ "$left" = "0byte" ]; then
    no "S!($label) 전제 붕괴: 잠금이 중화를 막지 못했다 ($left)"
  elif grep -q 'codex co-review SKIPPED (reason: residue_unclearable)' "$SCRATCH/$sid.err" && grep -qF "$tail" "$SCRATCH/$sid.err"; then
    ok "S!($label): 문서 미상 라운드에서 치우지 못한 산출물이 residue_unclearable 와 그 경로로 공시된다 ($left 잔존)"
  else
    no "S!($label): 문서 미상 라운드의 중화 불가가 공시되지 않는다 — residue_unclearable 또는 경로($tail)가 stderr 에 없다"
  fi
}
sweep_lock "평상시" rb33swlk "$FENCE"
sweep_lock "errexit" rb34swle "$FENCE_E"

# ── B) 번들 — 조립 성공은 파일을 남기고, 실패는 직전 번들을 남기지 않는다 ─────────
{ cat "$INPUT"; cat "$BUNDLE_BLK"; } > "$SCRATCH/b-bundle.sh"
{ echo 'set -euo pipefail'; cat "$INPUT"; cat "$BUNDLE_BLK"; } > "$SCRATCH/b-bundle-e.sh"
run_bundle() {   # run_bundle <sid> <script> <audit> → rc
  mkdir -p "$SCRATCH/$1"
  ( cd "$SCRATCH/$1" && env -i PATH="$BASE" HOME="$SCRATCH/$1" PYTHONDONTWRITEBYTECODE=1 \
      CLAUDE_PLUGIN_ROOT="$PR" DEVBREW_SPEC_DISTILL_SESSION_ID="$1" PAYLOAD="$DOC_B" AUDIT="$3" \
      bash "$2" ) >/dev/null 2>"$SCRATCH/$1.err"
}
bnd="$(where rb40bndl "$DOC_B")/brief-bundle.md"
rc=0; run_bundle rb40bndl "$SCRATCH/b-bundle.sh" "$AUD_B" || rc=$?
{ [ "$rc" = "0" ] && [ -s "$bnd" ] && grep -qF '<<<AUDIT-VERBATIM>>>' "$bnd" && grep -qF '둘째 발화' "$bnd"; } \
  && ok "B+: 유효한 payload·audit 에서 번들이 그 자리에 조립되고 audit 원문(S2)을 담는다 (양의 짝)" \
  || no "B+: 번들 조립 성공 경로가 무너졌다 (rc=$rc · $(state_of "$bnd"))"
bundle_fail() {   # bundle_fail <라벨> <sid> <script>
  local at b rc=0
  at="$(where "$2" "$DOC_B")"; mkdir -p "$at"; b="$at/brief-bundle.md"
  printf 'bundle from the previous round — %s\n' "$OLD" > "$b"
  run_bundle "$2" "$3" "$DOCS/missing.audit.md" || rc=$?
  if [ "$rc" != "0" ] && ! grep -q "$OLD" "$b" 2>/dev/null && grep -q '번들 조립 실패' "$SCRATCH/$2.err"; then
    ok "B($1): 조립이 실패한 라운드는 멈추고(rc $rc) 직전 번들을 남기지 않으며 그 사실을 공시한다 ($(state_of "$b"))"
  else
    no "B($1): 조립 실패 라운드가 rc=$rc 로 끝났거나 직전 번들이 남았다($(state_of "$b")) — 다음 셸이 그것을 이번 번들로 codex 에 넘긴다"
  fi
}
bundle_fail "평상시" rb41bndf "$SCRATCH/b-bundle.sh"
bundle_fail "errexit" rb42bnde "$SCRATCH/b-bundle-e.sh"
# 잠긴 번들 — 직전 번들 파일이 쓰기 불가면 `> "$BUNDLE"` 리다이렉트 자체가 실패해(rc 1) 절단도
# 일어나지 않는다. 이때 직전 번들을 치우는 것은 실패 분기의 명시적 정리 하나뿐이다(디렉토리 권한으로 지운다).
at="$(where rb43bndk "$DOC_B")"; mkdir -p "$at"; b="$at/brief-bundle.md"
printf 'bundle from the previous round — %s\n' "$OLD" > "$b"; chmod 444 "$b"
rc=0; run_bundle rb43bndk "$SCRATCH/b-bundle.sh" "$AUD_B" || rc=$?
[ -e "$b" ] && chmod 644 "$b"
if [ "$rc" != "0" ] && ! grep -q "$OLD" "$b" 2>/dev/null; then
  ok "B(잠긴 번들): 리다이렉트가 실패한 라운드도 멈추고(rc $rc) 직전 번들을 치운다 ($(state_of "$b"))"
else
  no "B(잠긴 번들): rc=$rc 로 끝났거나 직전 번들이 남았다($(state_of "$b")) — 다음 셸의 fence 가 그것을 이번 번들로 codex 에 넘긴다"
fi
# 그 뒤 같은 자리에서 fence 가 돈다면 codex 를 건너뛰어야 한다 — 없는 번들로 러너를 부르지 않는다.
fire_at="$(where rb41bndf "$DOC_B")"
( cd "$SCRATCH/rb41bndf" && env -i PATH="$BIN_OK:$BASE" HOME="$SCRATCH/rb41bndf" CODEX_API_KEY=t PYTHONDONTWRITEBYTECODE=1 \
    CLAUDE_PLUGIN_ROOT="$PR" DEVBREW_SPEC_DISTILL_SESSION_ID=rb41bndf PAYLOAD="$DOC_B" STUB_ARGV_OUT="$SCRATCH/rb41bndf.argv" \
    bash "$FENCE" ) >/dev/null 2>"$SCRATCH/rb41bndf.fence.err"
{ [ ! -e "$SCRATCH/rb41bndf.argv" ] && grep -q 'reason: gate_inputs_missing' "$SCRATCH/rb41bndf.fence.err"; } \
  && ok "B→fence: 번들 실패 라운드 뒤의 fence 는 러너를 부르지 않고 gate_inputs_missing 으로 공시한다" \
  || no "B→fence: 번들 실패 라운드 뒤에 러너가 불렸거나 공시가 없다 ($(state_of "$fire_at/brief-bundle.md") 번들)"

# ── H) 따로 도는 블록 — Bash 도구는 호출마다 새 셸이다 ─────────────────────────────
# 진입 게이트·degrade 원장은 check_brief.py · brief_review_state.py 의 형제 모듈이 필요해 리포의 배포
# 루트를 쓴다(상태 루트는 cwd 가 git 밖인 스크래치라 그 안에 생긴다). 러너가 없는 블록이라 스텁이 필요 없다.
RPR="$ROOT/plugins/spec-distill"
APPEND_BLK="$SCRATCH/append.sh"; cut_block "$SKILL" '^## kill switch' > "$APPEND_BLK"
GATE_BLK="$SCRATCH/gate.sh";     cut_block "$SKILL" '^## 진입 게이트' > "$GATE_BLK"
GATE_BLK_E="$SCRATCH/gate-e.sh"; { echo 'set -euo pipefail'; cat "$GATE_BLK"; } > "$GATE_BLK_E"
{ grep -q 'degrade-append' "$APPEND_BLK" && grep -q 'check_brief.py" gate' "$GATE_BLK" && bash -n "$GATE_BLK" 2>/dev/null; } \
  && ok "H 추출: degrade-append 블록과 진입 게이트 블록을 잘랐다 (bash -n 통과)" \
  || no "H 추출: degrade-append 또는 진입 게이트 블록이 비었거나 문법이 깨졌다 — 아래 H 셀은 무의미하다"
alone() {   # alone <sid> <script> <플러그인 루트> [env…] — 앞 블록 없이 새 셸에서 그 블록 하나만
  local sid="$1" script="$2" pr="$3"; shift 3
  mkdir -p "$SCRATCH/$sid"
  ( cd "$SCRATCH/$sid" && env -i PATH="$BASE" HOME="$SCRATCH/$sid" PYTHONDONTWRITEBYTECODE=1 \
      CLAUDE_PLUGIN_ROOT="$pr" DEVBREW_SPEC_DISTILL_SESSION_ID="$sid" "$@" bash "$script" ) >/dev/null 2>"$SCRATCH/$sid.alone.err"
}

# I1 — `## 입력` 하나만 돌아도 payload·audit 가 절대경로가 된다. 엔진의 --doc 슬롯이 그 값을 받는다.
home="$SCRATCH/rb50relx"; mkdir -p "$home/docs"; cp "$DOC_B" "$AUD_B" "$home/docs/"
{ cat "$INPUT"; printf '%s\n' 'printf "PAYLOAD=%s\nAUDIT=%s\n" "$PAYLOAD" "$AUDIT" > "$OBS"'; } > "$SCRATCH/i1-input.sh"
alone rb50relx "$SCRATCH/i1-input.sh" "$PR" PAYLOAD="docs/brief-sample.md" AUDIT="docs/brief-sample.audit.md" OBS="$SCRATCH/i1.obs"
ip="$(seen "$SCRATCH/i1.obs" PAYLOAD)"; ia="$(seen "$SCRATCH/i1.obs" AUDIT)"
if [ "${ip#/}" != "$ip" ] && [ "${ia#/}" != "$ia" ] && [ "$(real "$ip")" = "$(real "$home/docs/brief-sample.md")" ] \
   && [ "$(real "$ia")" = "$(real "$home/docs/brief-sample.audit.md")" ]; then
  ok "I1: \`## 입력\` 만 돌아도 상대 payload·audit 가 같은 파일의 절대경로가 된다"
else
  no "I1: \`## 입력\` 뒤 PAYLOAD='$ip' AUDIT='$ia' — 상대경로가 남으면 엔진은 --doc 을 doc_not_absolute 로 거부한다"
fi
# I1 — `## 번들` 이 앞 블록 없이 상대 payload·audit 로 들어와도 제 머리로 절대화해 그 문서 자리에 조립한다.
home="$SCRATCH/rb51relb"; mkdir -p "$home/docs"; cp "$DOC_B" "$AUD_B" "$home/docs/"
rc=0; alone rb51relb "$BUNDLE_BLK" "$PR" PAYLOAD="docs/brief-sample.md" AUDIT="docs/brief-sample.audit.md" || rc=$?
bnd="$(where rb51relb "$home/docs/brief-sample.md")/brief-bundle.md"
{ [ "$rc" = "0" ] && grep -qF '<<<AUDIT-VERBATIM>>>' "$bnd" 2>/dev/null; } \
  && ok "I1: \`## 번들\` 이 따로 상대경로로 돌아도 그 문서의 자리에 번들을 조립한다" \
  || no "I1: \`## 번들\` 을 따로 상대경로로 돌리면 rc=$rc · 번들 $(state_of "$bnd") — $(head -c 200 "$SCRATCH/rb51relb.alone.err" 2>/dev/null)"

# M2 — 진입 게이트가 막히면 직전 라운드 번들을 세 층으로 치운다(지움 → 절단 → 공시).
gate_case() {   # gate_case <라벨> <sid> <디렉토리 권한> <파일 권한> <기대: absent|0byte|stuck> <블록>
  local label="$1" sid="$2" dm="$3" fm="$4" want="$5" script="$6" at b rc=0 got tail
  at="$(where "$sid" "$DOC_B")"; mkdir -p "$at"; b="$at/brief-bundle.md"
  printf 'bundle from the previous round — %s\n' "$OLD" > "$b"; chmod "$fm" "$b"; chmod "$dm" "$at"
  alone "$sid" "$script" "$RPR" PAYLOAD="$DOC_B" AUDIT="$AUD_B" || rc=$?
  got="$(state_of "$b")"; chmod 755 "$at"; [ -e "$b" ] && chmod 644 "$b"
  tail="${b#"$SCRATCH"/}"
  if ! grep -q '구조 게이트 미통과' "$SCRATCH/$sid.alone.err"; then
    no "M2($label) 전제 붕괴: 진입 게이트가 실패 경로로 돌지 않았다 (rc=$rc) — 이 셀은 정리를 재지 않는다"; return
  fi
  if [ "$want" = "stuck" ]; then
    { [ "$rc" != "0" ] && [ "$got" != "absent" ] && [ "$got" != "0byte" ] \
      && grep -q '지우지도 비우지도 못했다' "$SCRATCH/$sid.alone.err" && grep -qF "$tail" "$SCRATCH/$sid.alone.err"; } \
      && ok "M2($label): 치울 수 없는 직전 번들은 그 경로와 함께 공시되고 라운드가 멈춘다 (rc $rc · $got 잔존)" \
      || no "M2($label): 치우지 못한 직전 번들이 공시되지 않았다 (rc=$rc · $got)"
  else
    { [ "$rc" != "0" ] && [ "$got" = "$want" ]; } \
      && ok "M2($label): 진입 게이트 실패가 직전 번들을 치운다 ($got)" \
      || no "M2($label): 진입 게이트가 막혔는데 직전 번들이 $got 로 남았다 (기대 $want) — codex 게이트의 -s 검사가 그것을 넘긴다"
  fi
}
gate_case "지움"          rb52gtrm 755 644 absent "$GATE_BLK"
gate_case "절단"          rb53gttr 555 644 0byte  "$GATE_BLK"
gate_case "중화 불가"     rb54gtst 555 444 stuck  "$GATE_BLK"
gate_case "지움 · errexit" rb55gtre 755 644 absent "$GATE_BLK_E"
# 번들 조립 쪽의 셋째 층 — 리다이렉트도 지움도 절단도 막히면 공시하고 멈춘다.
at="$(where rb56bdst "$DOC_B")"; mkdir -p "$at"; b="$at/brief-bundle.md"
printf 'bundle from the previous round — %s\n' "$OLD" > "$b"; chmod 444 "$b"; chmod 555 "$at"
rc=0; alone rb56bdst "$BUNDLE_BLK" "$PR" PAYLOAD="$DOC_B" AUDIT="$AUD_B" || rc=$?
got="$(state_of "$b")"; chmod 755 "$at"; chmod 644 "$b"
{ [ "$rc" != "0" ] && [ "$got" != "absent" ] && [ "$got" != "0byte" ] \
  && grep -q '지우지도 비우지도 못했다' "$SCRATCH/rb56bdst.alone.err" && grep -q '번들 조립 실패' "$SCRATCH/rb56bdst.alone.err"; } \
  && ok "M2(번들 · 중화 불가): 조립·지움·절단이 다 막히면 직전 번들을 공시하고 멈춘다 (rc $rc · $got 잔존)" \
  || no "M2(번들 · 중화 불가): 치우지 못한 직전 번들이 공시되지 않았다 (rc=$rc · $got)"

# M5 — 상태 디렉토리가 없는 사유를 가른다: 빈 payload 에 세션 id 처방을 내지 않는다.
rc=0; alone rb57nopl "$BUNDLE_BLK" "$PR" AUDIT="$AUD_B" || rc=$?
{ [ "$rc" != "0" ] && grep -q 'PAYLOAD 가 비었다' "$SCRATCH/rb57nopl.alone.err" && ! grep -q '세션 id 미해석' "$SCRATCH/rb57nopl.alone.err"; } \
  && ok "M5: 빈 payload 로 들어온 번들 블록이 그 사유(Skill 인자 1)를 대고 멈춘다" \
  || no "M5: 빈 payload 의 공시가 사유를 잘못 대거나 멈추지 않는다 (rc=$rc · $(head -c 200 "$SCRATCH/rb57nopl.alone.err" 2>/dev/null))"

# M3 — 따로 돈 degrade-append 블록의 record 가 닿는다. 원장이 쓰기 불가면 두 번째 채널 파일에 닿는다.
# 슬롯(<a>·<b>·<c>·<r>)은 모델이 채우는 자리라 여기서도 채워 돌린다.
home="$SCRATCH/rb58apnd"; S="$home/.claude/spec-distill/rb58apnd"; mkdir -p "$S"
printf -- '---\nsession_id: rb58apnd\n---\n\nbody\n' > "$S/state.local.md"
alone rb58apnd "$INPUT" "$RPR" PAYLOAD="$DOC_B" AUDIT="$AUD_B"
fill() { sed -e 's/<a>/pipeline/g' -e 's/<b>/all/g' -e 's/<c>/skipped/g' -e "s/<r>/$1/g" "$APPEND_BLK" > "$2"; }
fill probe-land-q1 "$SCRATCH/append-1.sh"; fill probe-fallback-q2 "$SCRATCH/append-2.sh"
if grep -q '^brief_review_degradations:' "$S/state.local.md"; then
  ok "M3 전제: \`## 입력\` 머리의 init 이 degrade 원장 키를 심었다"
else
  no "M3 전제 붕괴: degrade 원장 키가 없다 — 아래 셀은 append 를 재지 않는다 ($(head -c 200 "$SCRATCH/rb58apnd.alone.err" 2>/dev/null))"
fi
alone rb58apnd "$SCRATCH/append-1.sh" "$RPR" PAYLOAD="$DOC_B" AUDIT="$AUD_B"
grep -q 'probe-land-q1' "$S/state.local.md" \
  && ok "M3: 앞 블록 없이 따로 돈 degrade-append 의 record 가 원장에 닿는다" \
  || no "M3: 따로 돈 degrade-append 의 record 가 원장에 없다 — 그 record 는 「degrade 없음」으로 사라진다 ($(head -c 200 "$SCRATCH/rb58apnd.alone.err" 2>/dev/null))"
chmod 444 "$S/state.local.md"
alone rb58apnd "$SCRATCH/append-2.sh" "$RPR" PAYLOAD="$DOC_B" AUDIT="$AUD_B"
chmod 644 "$S/state.local.md"
{ grep -q 'probe-fallback-q2' "$S/brief-degrade-fallback.txt" 2>/dev/null && ! grep -q 'probe-fallback-q2' "$S/state.local.md"; } \
  && ok "M3: 원장이 쓰기 불가면 따로 돈 블록의 record 가 머리가 다시 도출한 두 번째 채널 파일에 닿는다" \
  || no "M3: 원장 쓰기 실패의 record 가 두 번째 채널 파일($S/brief-degrade-fallback.txt)에 없다 — \`>> \"\"\` 로 사라졌다"
finish
