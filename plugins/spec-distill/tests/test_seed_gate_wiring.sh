#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/framing-requests/SKILL.md plugins/spec-distill/scripts/detect_codex.sh plugins/spec-distill/scripts/codex-killswitch.conf plugins/spec-distill/scripts/build_seed_inline_blob.py plugins/spec-distill/scripts/seed_review_log.py shared/docreview/scripts/docreview_state.py
#
# framing-requests 의 `## 상태` 블록 · `### 번들` 펜스 · codex 게이트 펜스를 잘라내 **차가운 셸
# (`env -i`)에서 실행**해 디스크 사후상태를 잰다. 읽어서 판정하지 않는다 — 옳아 보이는 펜스가
# 미할당 변수로 죽는 결함은 실행으로만 드러난다.
#
# 형제 `plugins/quality-gates/tests/test_codex_gate_observation.sh` 가 같은 codex 펜스를 가용 · kill
# switch · 미설치 · 감지기 부재로 돌려 codex 호출 수를 센다. 여기는 호출 수가 가리지 못하는 것만 잰다:
#   P  `## 상태` 가 같은 seed 에는 같은 엔진 자리를, 다른 seed 에는 다른 자리를 낸다
#   B  `### 번들` 이 번들 둘을 쓰고 재비판 번들에는 판정 이력이 없다 · 조립 실패면 둘 다 치운다 ·
#      직전 라운드의 리뷰어 산출물을 치운다
#   R  러너 인자 넷 — 첫째 seed 프로필 · 둘째 탐지 번들(seed 도 재비판 번들도 아니다) · 넷째 산출물
#   A  codex 를 건너뛴 라운드(kill switch · 번들 부재)가 직전 라운드 산출물을 남기지 않는다
#   A+ 이번 실행이 쓴 산출물은 살아남는다(「언제나 지운다」 판본을 잡는 양의 짝)
#   X  러너 rc 3 이면 산출물을 치운다
#   E  앞 블록의 `set -euo pipefail` 을 물려받아도 같은 사후상태
# 감지기 · kill switch 설정은 리포 정본을 복사해 쓰고 러너만 스텁이다. PATH 는 명시적으로만 구성해
# 실제 codex 로 새지 않는다. 리포의 배포 지점은 건드리지 않는다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SK="$ROOT/plugins/spec-distill/skills/framing-requests/SKILL.md"
if [ "${1:-}" = "--emit-scanned" ]; then
  for f in plugins/spec-distill/skills/framing-requests/SKILL.md plugins/spec-distill/scripts/detect_codex.sh \
           plugins/spec-distill/scripts/codex-killswitch.conf plugins/spec-distill/scripts/build_seed_inline_blob.py \
           plugins/spec-distill/scripts/seed_review_log.py shared/docreview/scripts/docreview_state.py; do
    echo "$f"
  done
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
W="$(mktemp -d -t sd-framing-gate-XXXXXX)" || exit 1
trap 'chmod -R u+w "$W" 2>/dev/null; rm -rf "$W"' EXIT

# ── 블록 셋을 잘라낸다 ────────────────────────────────────────────────────────
first_bash_in() {   # first_bash_in <시작 헤딩 정규식> <끝 헤딩 정규식> → 그 구간의 첫 bash 펜스
  H="$1" E="$2" awk '
    !s && $0 ~ ENVIRON["H"] { s = 1; next }
    s && !b && $0 ~ ENVIRON["E"] { exit }
    s && !done && /^```bash$/ { b = 1; next }
    s && b && /^```$/ { b = 0; done = 1; next }
    s && b { print }' "$SK"
}
first_bash_in '^## 상태$' '^## ' | sed 's/^TOPIC="<kebab-topic>"$/TOPIC="probe-topic"/' > "$W/state.sh"
first_bash_in '^### 번들' '^##+ ' > "$W/bundle.sh"
awk '/codex-gate:begin[[:space:]]+runner=run_docreview_codex_reviewer\.sh/ {g=1; next}
     /codex-gate:end/ {g=0}
     g && /^```bash$/ {b=1; next}
     g && b && /^```$/ {b=0; next}
     g && b' "$SK" > "$W/gate.sh"
chk_blk() {   # chk_blk <라벨> <파일> <고정 문자열>
  if [ -s "$2" ] && grep -qF -- "$3" "$2" && bash -n "$2" 2>/dev/null; then
    ok "추출: $1 블록이 핵심 줄을 담고 bash -n 을 통과한다"
  else
    no "추출: $1 블록이 비었거나 핵심 줄('$3')이 없거나 문법이 깨졌다 — 그 블록을 쓰는 판정은 무의미하다"
  fi
}
chk_blk 상태 "$W/state.sh" 'state-dir-for'
chk_blk 번들 "$W/bundle.sh" 'build_seed_inline_blob.py'
chk_blk "codex 게이트" "$W/gate.sh" 'run_docreview_codex_reviewer.sh" "$PROFILE" "$BUNDLE"'
grep -q '^TOPIC="probe-topic"$' "$W/state.sh" && ok "추출: 자리표를 픽스처 주제로 바꿨다" \
  || no "추출: TOPIC 줄 모양이 바뀌어 자리표를 못 바꿨다 — 이름 파일 없이 도는 경로만 잰다"

# ── 가짜 플러그인 루트 ────────────────────────────────────────────────────────
PR="$W/plugin"; mkdir -p "$PR/scripts"
for f in state_path.py detect_codex.sh codex-killswitch.conf docreview_state.py; do
  cp "$ROOT/plugins/spec-distill/scripts/$f" "$PR/scripts/"
done
for f in build_seed_inline_blob.py seed_review_log.py; do ln -s "$ROOT/plugins/spec-distill/scripts/$f" "$PR/scripts/$f"; done
ln -s "$ROOT/plugins/spec-distill/references" "$PR/references"
cat > "$PR/scripts/run_docreview_codex_reviewer.sh" <<'STUB'
#!/usr/bin/env bash
# 스텁 — 실물의 인자 넷 · 산출물 · rc 계약만 흉내낸다.
[ -z "${ARGV_LOG:-}" ] || printf '%s\n' "$@" > "$ARGV_LOG"
case "${WRITE:-none}" in
  fresh) printf 'findings: []\nmeta:\n  codex_failed: false\n  note: FRESH_SEED_RUN\n' > "$4" ;;
  husk)  : > "$4" ;;
  none)  : ;;
esac
exit "${RC:-0}"
STUB
chmod +x "$PR/scripts/run_docreview_codex_reviewer.sh"
BIN_OK="$W/bin-ok"; mkdir -p "$BIN_OK"
printf '#!/usr/bin/env bash\n[ "${1:-}" = "--version" ] && { echo "codex-cli 0.145.0"; exit 0; }\nexit 0\n' > "$BIN_OK/codex"
chmod +x "$BIN_OK/codex"
cp "$ROOT/plugins/quality-gates/tests/mocks/bin-stubs/"* "$BIN_OK/" 2>/dev/null || true
BASE="/usr/bin:/bin"

cat > "$W/audit.fixture.md" <<'EOF'
---
type: interview-seed-audit
---

# probe

## 1. 원문

RAW_PROBE 사용자가 한 말.

## 2. 질문 전체

### 라운드 1

- 물은 것: 무엇을 맡기나요
  - 선택지: 자유 입력
  - 당신이 답한 것: 로그인 버그

## 6. 리뷰 결정

- D1.1 · r1 · adopt · abcd1234#r1.1 · "HIST_QUOTE_MARKER" — HIST_SUMMARY_MARKER 요약
EOF

home() {   # home <sid> [이름] → 차가운 셸의 cwd 를 만든다(이름 파일 · seed · audit · CLAUDE.md)
  local sid="$1" name="${2:-probe-$1-interview}" h="$W/$1"
  mkdir -p "$h/docs/superpowers/interview" "$h/.claude/spec-distill/$sid"
  printf '%s\n' "$name" > "$h/.claude/spec-distill/$sid/interview-basename"
  printf -- '---\ntype: interview-seed\n---\n\nSEED_%s 로그인이 가끔 실패한다.\n' "$sid" > "$h/docs/superpowers/interview/$name.md"
  cp "$W/audit.fixture.md" "$h/docs/superpowers/interview/$name.audit.md"
  printf '# CLAUDE.md\n규칙.\n' > "$h/CLAUDE.md"
}
run_in() {   # run_in <sid> <스크립트> [env…]
  local sid="$1" script="$2"; shift 2
  ( cd "$W/$sid" && env -i PATH="$BIN_OK:$BASE" HOME="$W/$sid" CODEX_API_KEY=t PYTHONDONTWRITEBYTECODE=1 \
      CLAUDE_PLUGIN_ROOT="$PR" DEVBREW_SPEC_DISTILL_SESSION_ID="$sid" "$@" bash "$script" ) >"$W/$sid.out" 2>"$W/$sid.err"
}
place() {   # place <sid> [이름] → 그 seed 의 엔진 자리(엔진 state-dir-for 가 낸 것)
  local sid="$1" name="${2:-probe-$1-interview}"
  python3 "$PR/scripts/docreview_state.py" state-dir-for --root "$W/$sid/.claude/spec-distill" --session "$sid" \
      --doc "$W/$sid/docs/superpowers/interview/$name.md" 2>/dev/null
}
real() { python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"; }

# ── P — 엔진 자리 ─────────────────────────────────────────────────────────────
# `set -u` 로 돌린다 — 그래야 아래 「미할당 변수로 죽지 않는다」가 실패할 수 있다. 세 실행의 stderr 를 모아 잰다.
{ echo 'set -u'; cat "$W/state.sh"; echo 'printf "STATE_DIR=%s\n" "$STATE_DIR"'; } > "$W/state-print.sh"
: > "$W/p-all.err"
home fg01same; run_in fg01same "$W/state-print.sh"; cat "$W/fg01same.err" >> "$W/p-all.err"; s1="$(sed -n 's/^STATE_DIR=//p' "$W/fg01same.out")"
run_in fg01same "$W/state-print.sh"; cat "$W/fg01same.err" >> "$W/p-all.err"; s1b="$(sed -n 's/^STATE_DIR=//p' "$W/fg01same.out")"
[ -n "$s1" ] && [ "$s1" = "$s1b" ] && ok "P: 같은 seed 는 셸이 바뀌어도 같은 엔진 자리" || no "P: 같은 seed 의 자리가 비었거나 갈렸다 ('$s1' · '$s1b')"
[ -n "$s1" ] && [ "$(real "$s1")" = "$(real "$(place fg01same)")" ] && ok "P: 그 자리는 엔진 state-dir-for 가 낸 것과 같다" \
  || no "P: 블록이 엔진과 다른 자리를 냈다"
home fg01same probe-other-interview; run_in fg01same "$W/state-print.sh"; cat "$W/fg01same.err" >> "$W/p-all.err"; s2="$(sed -n 's/^STATE_DIR=//p' "$W/fg01same.out")"
[ -n "$s2" ] && [ "$s2" != "$s1" ] && ok "P: 같은 세션의 다른 seed 는 다른 자리" || no "P: 다른 seed 가 같은 자리를 받았다 — 원장이 섞인다"
grep -q 'unbound variable' "$W/p-all.err" && no "P: 상태 블록이 set -u 에서 미할당 변수로 죽었다" || ok "P: 상태 블록이 차가운 셸 · set -u 에서 죽지 않는다"

# ── B — 번들 ─────────────────────────────────────────────────────────────────
{ cat "$W/state.sh"; cat "$W/bundle.sh"; echo 'echo "bundle_rc=$bundle_rc"'; } > "$W/bundle-run.sh"
home fg10bndl; pl="$(place fg10bndl)"; mkdir -p "$pl"
printf 'OLD_CRITIC\n' > "$pl/critic.txt"; printf 'OLD_RECRITIC\n' > "$pl/recritic.txt"
run_in fg10bndl "$W/bundle-run.sh"
grep -q '^bundle_rc=0$' "$W/fg10bndl.out" && ok "B: 조립 rc 0" || no "B: 조립 실패 — $(tail -1 "$W/fg10bndl.err")"
[ -s "$pl/seed-bundle.md" ] && [ -s "$pl/seed-bundle-recritic.md" ] && ok "B: 번들 둘이 엔진 자리에 있다" || no "B: 번들 둘 중 하나가 없다"
grep -qF 'HIST_SUMMARY_MARKER' "$pl/seed-bundle.md" && ok "B: 탐지 번들에는 판정 이력이 있다" || no "B: 탐지 번들에 audit ## 6 이 없다"
if grep -qF 'HIST_SUMMARY_MARKER' "$pl/seed-bundle-recritic.md"; then no "B: 재비판 번들에 판정 이력이 샜다(AC11)"
else ok "B: 재비판 번들에는 판정 이력이 없다(AC11)"; fi
grep -qF 'HIST_QUOTE_MARKER' "$pl/seed-bundle-recritic.md" && ok "B: 재비판 번들에 사용자 문구는 남는다" || no "B: 재비판 번들에서 사용자 문구까지 빠졌다"
[ ! -e "$pl/critic.txt" ] && [ ! -e "$pl/recritic.txt" ] && ok "B: 직전 라운드의 리뷰어 산출물을 치웠다" \
  || no "B: 직전 라운드 critic/recritic 이 남았다 — audit ## 4 에 이번 라운드 것으로 옮겨진다"
rm -f "$W/fg10bndl/docs/superpowers/interview/probe-fg10bndl-interview.audit.md"
run_in fg10bndl "$W/bundle-run.sh"
grep -q '^bundle_rc=1$' "$W/fg10bndl.out" && ok "B: audit 이 없으면 조립 실패(rc 1)" || no "B: audit 없이도 조립 성공으로 보고했다"
[ ! -s "$pl/seed-bundle.md" ] && [ ! -s "$pl/seed-bundle-recritic.md" ] && ok "B: 실패한 라운드는 직전 번들을 남기지 않는다" \
  || no "B: 실패한 라운드에 직전 번들이 남았다 — codex 게이트가 그것을 이번 번들로 넘긴다"

# ── codex — A · A+ · R · X · E ───────────────────────────────────────────────
{ cat "$W/state.sh"; cat "$W/bundle.sh"; cat "$W/gate.sh"; } > "$W/full.sh"
{ echo 'set -euo pipefail'; cat "$W/full.sh"; } > "$W/full-e.sh"
{ cat "$W/state.sh"; cat "$W/gate.sh"; } > "$W/nobundle.sh"
stale() { printf 'findings: []\nmeta:\n  codex_failed: false\n  note: STALE_PREV_ROUND\n' > "$1"; }
state_of() { if [ ! -e "$1" ]; then echo absent; elif [ ! -s "$1" ]; then echo 0byte; else echo present; fi; }
fire() {   # fire <sid> <스크립트> [env…] → 그 seed 의 codex 산출물 경로
  local sid="$1" script="$2"; shift 2
  home "$sid"; local pl; pl="$(place "$sid")"; mkdir -p "$pl"; stale "$pl/docreview-codex.yaml"
  run_in "$sid" "$script" ARGV_LOG="$W/$sid.argv" "$@"
  printf '%s' "$pl/docreview-codex.yaml"
}
y="$(fire fg20kill "$W/full.sh" DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1)"
case "$(state_of "$y")" in absent|0byte) ok "A(kill switch): 직전 라운드 산출물이 중화됐다" ;; *) no "A(kill switch): 직전 라운드 산출물이 남았다" ;; esac
[ ! -e "$W/fg20kill.argv" ] && ok "A(kill switch): 러너를 부르지 않았다" || no "A(kill switch): 끈 codex 러너가 불렸다"
grep -q 'SKIPPED (reason: kill_switch)' "$W/fg20kill.err" && ok "A(kill switch): 사유를 공시한다" || no "A(kill switch): SKIPPED 공시가 없다"
y="$(fire fg21nobd "$W/nobundle.sh" WRITE=fresh)"
case "$(state_of "$y")" in absent|0byte) ok "A(번들 부재): 직전 라운드 산출물이 중화됐다" ;; *) no "A(번들 부재): 직전 라운드 산출물이 남았다" ;; esac
[ ! -e "$W/fg21nobd.argv" ] && grep -q 'SKIPPED (reason: gate_inputs_missing)' "$W/fg21nobd.err" \
  && ok "A(번들 부재): 러너를 부르지 않고 gate_inputs_missing 으로 공시한다" || no "A(번들 부재): 번들 없이 러너가 불렸거나 공시가 없다"
# 사유 코드는 일반 SKIPPED 줄도 내므로, 전용 메시지(관측한 두 입력값 · 「앞에 이어 붙여라」)는 따로 잰다.
grep -qF "CODEX_YAML='" "$W/fg21nobd.err" && grep -qF "BUNDLE='" "$W/fg21nobd.err" \
  && ok "A(번들 부재): 입력 부재 전용 메시지가 관측한 CODEX_YAML · BUNDLE 값을 댄다" \
  || no "A(번들 부재): 입력 부재 전용 메시지가 없다 — 사유 코드만으로는 무엇이 비었는지 모른다"
y="$(fire fg22keep "$W/full.sh" WRITE=fresh RC=0)"
grep -q 'FRESH_SEED_RUN' "$y" 2>/dev/null && ! grep -q 'STALE_PREV_ROUND' "$y" \
  && ok "A+: 이번 실행이 쓴 산출물이 살아남는다" || no "A+: 이번 산출물이 사라졌거나 직전 것이 남았다($(state_of "$y"))"
if grep -qF "CODEX_YAML='" "$W/fg22keep.err" || grep -qF "BUNDLE='" "$W/fg22keep.err"; then
  no "A+: 입력이 있는데 입력 부재 메시지가 나왔다"
else
  ok "A+: 입력이 있으면 입력 부재 메시지가 없다(위 전용 메시지 단언의 음의 짝)"
fi
pl="$(place fg22keep)"
if [ -f "$W/fg22keep.argv" ]; then
  a1="$(sed -n 1p "$W/fg22keep.argv")"; a2="$(sed -n 2p "$W/fg22keep.argv")"; a4="$(sed -n 4p "$W/fg22keep.argv")"
  case "$a1" in */docreview-profiles/seed.md) ok "R: 첫째 인자는 seed 프로필" ;; *) no "R: 첫째 인자가 seed 프로필이 아니다 — '$a1'" ;; esac
  [ "$(real "$a2")" = "$(real "$pl/seed-bundle.md")" ] && ok "R: 둘째 인자는 탐지 번들(seed 도 재비판 번들도 아니다)" || no "R: 둘째 인자가 탐지 번들이 아니다 — '$a2'"
  [ "$(real "$a4")" = "$(real "$pl/docreview-codex.yaml")" ] && ok "R: 넷째 인자는 엔진 자리의 산출물" || no "R: 넷째 인자가 엔진 자리 산출물이 아니다 — '$a4'"
else
  no "R: 러너가 불리지 않았다 — 가용 경로가 죽었다"
fi
y="$(fire fg23rc3x "$W/full.sh" WRITE=husk RC=3)"
[ "$(state_of "$y")" = absent ] && ok "X: 러너 rc 3 이면 산출물을 치운다(껍데기를 남기지 않는다)" || no "X: rc 3 뒤에 $(state_of "$y") 가 남았다"
y="$(fire fg24ekep "$W/full-e.sh" WRITE=fresh RC=0)"
grep -q 'FRESH_SEED_RUN' "$y" 2>/dev/null && ok "E: set -euo pipefail 을 물려받아도 이번 산출물이 산다" || no "E: 엄격 모드에서 가용 경로가 죽었다 — $(tail -1 "$W/fg24ekep.err")"
y="$(fire fg25ekil "$W/full-e.sh" DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1)"
case "$(state_of "$y")" in absent|0byte) ok "E: 엄격 모드의 kill switch 경로도 직전 산출물을 중화한다" ;; *) no "E: 엄격 모드 kill switch 경로가 잔존물을 남겼다" ;; esac
grep -q 'unbound variable' "$W"/fg2*.err && no "E: 어느 실행이 미할당 변수로 죽었다" || ok "E: 미할당 변수로 죽은 실행 없음"
finish
