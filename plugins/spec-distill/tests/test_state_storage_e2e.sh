#!/usr/bin/env bash
# R7 끝에서 끝 — seed 진입 · 상태 파일 · 이어 감 · 끝내기 커밋 · 두 세션 리뷰(표지 넘겨받기) · 원장 정리 · 링크 축.
# 실제 CLI 와 실제 SKILL 펜스를 한 흐름으로 돈다.
set -u
ROOT_REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT_REPO/plugins/spec-distill"
. "$ROOT_REPO/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
unset DEVBREW_SPEC_DISTILL_DISABLE DEVBREW_SKIP_HOOKS DEVBREW_SPEC_DISTILL_TTL_HOURS DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW
T="$(mktemp -d)"; [ -n "$T" ] && [ -d "$T" ] || { echo "mktemp 실패"; exit 1; }
T="$(cd "$T" && pwd -P)"; trap 'rm -rf "$T"' EXIT

fence() {   # fence <파일> <마커 이름> → 그 마커 사이 첫 bash 펜스 본문
  awk -v b="<!-- $2:begin -->" -v e="<!-- $2:end -->" '
    index($0,b){f=1;next} index($0,e){f=0} f&&/^```bash$/{c=1;next} f&&c&&/^```$/{c=0;next} f&&c' "$1"
}
bash_with() {   # bash_with <파일> <고정 문자열> → 그 문자열을 담은 첫 bash 펜스
  awk -v pat="$2" '/^```bash$/ {b=1; buf=""; next} b && /^```$/ {b=0; if (!done && index(buf, pat)) {printf "%s", buf; done=1}; next} b {buf = buf $0 "\n"}' "$1"
}
SK="$SD/skills/spec-interview/SKILL.md"; FIN="$SD/skills/spec-interview/references/finishing.md"
RB="$SD/skills/reviewing-brief/SKILL.md"
PH='<Step A.5 의 PAYLOAD 절대경로>'

ENTRY="$(fence "$SK" interview-state-entry)"; COMMIT="$(fence "$FIN" interview-commit)"; BA="$(fence "$FIN" advice-ba)"
RB_OPEN="$(fence "$RB" ledger-open)"; RB_TAKE="$(fence "$RB" ledger-takeover)"; RB_GUARD="$(fence "$RB" ledger-guard)"
RB_HEAD="$(bash_with "$RB" 'init_rc=0; python3 "$PR/scripts/brief_review_state.py" init "$STATE"')"
RB_PROF="$(awk '/^## 프로필/{f=1} f&&/^```bash$/{c=1;next} c&&/^```$/{exit} c' "$RB")"
for v in ENTRY COMMIT BA RB_OPEN RB_TAKE RB_GUARD RB_HEAD RB_PROF; do
  eval "x=\"\$$v\""; [ -n "$x" ] && ok "전제: 펜스 $v 를 뽑았다" || no "전제: 펜스 $v 가 비었다 — 아래 칸이 공허하다"
done
case "$COMMIT$BA" in *"$PH"*) ok "전제: 커밋 · B-A 펜스에 PAYLOAD 자리표가 있다" ;; *) no "전제: PAYLOAD 자리표가 없다 — 자리표 치환이 공허하다" ;; esac

A=sess-e2eaaaa1; B=sess-e2ebbbb2
in_sess() {   # in_sess <저장소> <sid> <스크립트> → 그 세션으로 저장소에서 돈 출력(rc 는 호출의 rc)
  ( cd "$1" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID="$2" DEVBREW_SPEC_DISTILL_SESSION_ID="$2" bash -c "$3" 2>&1 )
}
mk() {   # mk <이름> → origin(bare) 을 가진 클론, 기능 브랜치 feature/e2e, origin/HEAD=main, seed · seed audit 커밋
  local o="$T/$1-origin.git" c="$T/$1"
  git init -q --bare -b main "$o"; git clone -q "$o" "$c" 2>/dev/null
  git -C "$c" config user.email t@t.t; git -C "$c" config user.name t
  git -C "$c" commit -q --allow-empty -m init; git -C "$c" push -q origin main 2>/dev/null
  git -C "$c" remote set-head origin main >/dev/null 2>&1
  git -C "$c" switch -q -c feature/e2e
  mkdir -p "$c/docs/superpowers/interview"
  printf -- '---\ntype: interview-seed\n---\n\n## 요청\n\n상태 저장을 끝에서 끝으로 잰다.\n' > "$c/docs/superpowers/interview/2026-10-15-e2e-interview.md"
  printf -- '---\ntype: interview-seed-audit\nsession_id: sess-e2eseed0\n---\n\n## 1. 원문\n\n원문.\n' > "$c/docs/superpowers/interview/2026-10-15-e2e-interview.audit.md"
  git -C "$c" add -- docs/superpowers/interview
  git -C "$c" commit -q -m "docs(interview): seed"
  printf '%s' "$c"
}

# ── 1. 픽스처 ─────────────────────────────────────────────────────────────────
R="$(mk repo)"; D="$R/docs/superpowers/interview"; SEED="$D/2026-10-15-e2e-interview.md"
assert_eq "$(git -C "$R" branch --show-current) $(git -C "$R" symbolic-ref --short refs/remotes/origin/HEAD)" "feature/e2e origin/main" "1: 픽스처 — 기능 브랜치 위 · origin/HEAD 가 main"

# ── 2. 세션 A — seed 로 진입해 상태 파일을 만든다 ────────────────────────────
o="$(in_sess "$R" "$A" "ARG_PATH='$SEED'
$ENTRY")"
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "interview-state: NEW-SEED e2e-brief seed=docs/superpowers/interview/2026-10-15-e2e-interview.md" "2: 세션 A — seed 진입은 NEW-SEED <주제>-brief"
SP="$(cd "$R" && python3 "$SD/scripts/state_path.py" interview-state --topic e2e-brief --date 2026-10-15)"; rc=$?
assert_eq "$rc:$SP" "0:$D/2026-10-15-e2e-brief-interview.state.md" "2: 상태 파일 경로는 스크립트가 낸다(seed 와 겹치지 않는 줄기)"
printf -- '---\ntype: interview-state\nseed: docs/superpowers/interview/2026-10-15-e2e-interview.md\n---\n## 풀린 입력\n\n~~~~\n## 요청\n\n상태 저장을 끝에서 끝으로 잰다.\n~~~~\n\n## R1\n\n- 첫 라운드 기록.\n' > "$SP"
assert_eq "$(sed -n '2,3p' "$SP" | tr '\n' '|')" "type: interview-state|seed: docs/superpowers/interview/2026-10-15-e2e-interview.md|" "2: 상태 파일 첫 두 키"

# ── 3. 세션 B — 같은 seed 로 진입하면 묻고, 고른 후보로 다시 돌면 이어 간다 ─────────
o="$(in_sess "$R" "$B" "ARG_PATH='$SEED'
$ENTRY")"
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "interview-state: ASK" "3: 세션 B — 같은 seed 의 끝나지 않은 상태 파일이 있으면 ASK"
cand="$(printf '%s\n' "$o" | sed -n 's/^candidate: //p')"
assert_eq "$cand" "$SP" "3: ASK 의 후보는 세션 A 의 상태 파일 하나"
o="$(in_sess "$R" "$B" "ARG_PATH='$cand'
$ENTRY")"
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "interview-state: RESUME $SP" "3: 고른 후보로 진입 펜스를 다시 돌면 RESUME <절대경로>"

# ── 4. 끝내기 커밋 — 같은 줄기의 brief · audit · 상태 파일 셋만 한 커밋 ──────────
STEM="${SP%.state.md}"; BRIEF="$STEM.md"; AUD="$STEM.audit.md"
printf -- '---\ntype: interview-brief\n---\n# e2e brief\n' > "$BRIEF"
printf -- '---\ntype: interview-audit\n---\n# e2e audit\n' > "$AUD"
printf 'y\n' > "$R/other.txt"   # 커밋에 끼면 안 되는 이웃 파일
before_n="$(git -C "$R" rev-list --count HEAD)"
o="$(in_sess "$R" "$B" "${COMMIT//"$PH"/$BRIEF}")"
assert_eq "$(git -C "$R" rev-list --count HEAD)" "$((before_n + 1))" "4: 끝내기 커밋이 한 번 생겼다"
assert_contains "$o" "brief · audit · 상태 파일을 커밋했다" "4: 커밋한 사실을 보인다"
assert_eq "$(git -C "$R" show --name-only --pretty=format: HEAD | sed '/^$/d' | sort | tr '\n' ' ')" \
  "docs/superpowers/interview/2026-10-15-e2e-brief-interview.audit.md docs/superpowers/interview/2026-10-15-e2e-brief-interview.md docs/superpowers/interview/2026-10-15-e2e-brief-interview.state.md " \
  "4: 그 커밋은 세 경로뿐"
assert_eq "$(git -C "$R" branch --show-current)" "feature/e2e" "4: 커밋은 기능 브랜치 위"
assert_eq "$(git -C "$R" log -1 --pretty=%s)" "docs(interview): 2026-10-15-e2e-brief-interview brief · audit · 상태 기록" "4: 끝내기 커밋 메시지 꼴(R-h)"
assert_eq "$(git -C "$R" status --porcelain -- other.txt)" "?? other.txt" "4: 이웃 파일은 커밋되지 않았다"

# ── 5. 두 세션이 같은 brief 를 리뷰 — 표지 · 넘겨받기 · 쓰기 전 확인 · 끝맺음 ────────
rb() {   # rb <sid> <머리 뒤에 이어 붙일 스크립트> → reviewing-brief 의 PAYLOAD · AUDIT 대입 + 이어 붙인 것
  in_sess "$R" "$1" "PAYLOAD='$BRIEF'; AUDIT='$AUD'
$2"
}
SDIR="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$R/.claude/spec-distill" --doc "$BRIEF")"
o="$(rb "$A" "$RB_OPEN")"
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: HELD" "5: 세션 A — reviewing-brief 원장 열기가 표지를 잡는다"
assert_eq "$(cat "$SDIR/reviewing-by" 2>/dev/null)" "$A" "5: 표지는 brief 의 원장 자리에 세션 A"
o="$(rb "$A" "$RB_HEAD
$RB_PROF
$RB_GUARD
python3 \"\$PR/scripts/docreview_state.py\" init --state-dir \"\$STATE_DIR\" --doc \"\$PAYLOAD\" --profile \"\$PROFILE\"")"; rc=$?
{ [ "$rc" -eq 0 ] && [ -f "$SDIR/docreview-state.md" ]; } && ok "5: 표지 주인 A — 확인을 지나 원장을 연다(init)" || no "5: A 의 init 이 원장을 만들지 못했다(rc $rc): $o"
o="$(rb "$B" "$RB_OPEN")"; rc=$?
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: OTHER:$A" "5: 세션 B — 남의 표지면 OTHER:<A>"
assert_eq "$rc" "3" "5: OTHER 판결은 펜스를 rc 3 으로 끝낸다"
rb "$B" "$RB_TAKE" >/dev/null
assert_eq "$(cat "$SDIR/reviewing-by" 2>/dev/null)" "$B" "5: 「이어 씀」 — B 의 넘겨받기 뒤 표지가 B"
o="$(rb "$B" "$RB_OPEN")"
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: HELD" "5: 넘겨받은 B 가 원장 열기를 다시 돌면 HELD"
snap="$T/snap.json"; python3 "$SD/scripts/docreview_anchor.py" snapshot "$BRIEF" > "$snap"
before="$(cksum < "$SDIR/docreview-state.md")"
o="$(rb "$A" "$RB_HEAD
$RB_GUARD
python3 \"\$PR/scripts/docreview_state.py\" begin-round --state-dir \"\$STATE_DIR\" --snapshot '$snap'")"; rc=$?
assert_eq "$rc" "3" "5: 넘겨준 세션 A — 쓰기 전 확인이 rc 3 으로 멈춘다"
assert_eq "$(cksum < "$SDIR/docreview-state.md")" "$before" "5: 넘겨준 세션 A — 원장 바이트가 그대로다"
assert_contains "$o" "「이어 씀」" "5: A 에게 남의 표지라는 안내(「이어 씀」)를 보인다"
o="$(rb "$B" "$RB_HEAD
$RB_GUARD
python3 \"\$PR/scripts/docreview_state.py\" begin-round --state-dir \"\$STATE_DIR\" --snapshot '$snap'")"; rc=$?
assert_eq "$rc" "0" "5: 표지 주인 B — 확인을 지나 begin-round 가 돈다"; [ "$rc" -eq 0 ] || printf '      출력: %s\n' "$o"
[ "$(cksum < "$SDIR/docreview-state.md")" != "$before" ] && ok "5 양성 대조: 같은 쓰기가 표지 주인에게서는 원장을 바꾼다(바이트 단언의 이빨)" \
  || no "5 양성 대조: B 의 begin-round 가 원장을 바꾸지 않았다 — 위 「그대로다」 단언이 공허하다"
o="$(in_sess "$R" "$B" "${BA//"$PH"/$BRIEF}")"
[ -e "$SDIR/reviewing-by" ] && no "5: B 의 끝맺음(B-A) 뒤에도 표지가 남았다: $o" || ok "5: B 의 끝맺음(B-A) 펜스가 표지를 푼다"
assert_eq "$(cat "$SDIR/last-session" 2>/dev/null)" "$B" "5: last-session 에 B 가 남는다"

# ── 6. 정리 — brief 를 지운 뒤 늙은 원장은 문서 없는 원장으로 걷힌다 ──────────────
git -C "$R" rm -q -- "$BRIEF"; git -C "$R" commit -q -m "docs: brief 제거"
[ -e "$BRIEF" ] && no "6: brief 가 남았다" || ok "6: brief 를 지우고 커밋했다"
o="$(cd "$R" && python3 "$SD/scripts/ledger_sweep.py" --root "$R/.claude/spec-distill" 2>&1)"
[ -d "$SDIR" ] && ok "6: TTL 안의 문서 없는 원장은 아직 걷지 않는다(늙히기가 아래 칸의 원인이다)" || no "6: 갓 쓴 원장이 TTL 전에 걷혔다: $o"
python3 -I - "$SDIR" <<'PY'
import os, sys, time
when = time.time() - 30 * 3600
for dp, dns, fns in os.walk(sys.argv[1]):
    for n in dns + fns:
        os.utime(os.path.join(dp, n), (when, when), follow_symlinks=False)
os.utime(sys.argv[1], (when, when))
PY
o="$(cd "$R" && python3 "$SD/scripts/ledger_sweep.py" --root "$R/.claude/spec-distill" 2>&1)"
assert_contains "$o" "문서 없는 원장 1개" "6: 정리가 문서 없는 원장 1개를 보고한다"
[ -e "$SDIR" ] && no "6: 원장 폴더가 남았다: $o" || ok "6: 원장 폴더가 걷혔다"

# ── 7. 링크 축 — 레포가 심을 수 있는 링크를 따라 쓰지 않는다 ─────────────────────
L="$(mk linked)"; LD="$L/docs/superpowers/interview"; LSEED="$LD/2026-10-15-e2e-interview.md"
LOUT="$T/l-outside"; LFILE="$T/l-outside.txt"; mkdir -p "$LOUT" "$L/.claude/spec-distill"
ln -s "$LOUT" "$L/.claude/spec-distill/.docreview"
printf -- '---\ntype: interview-state\nseed: docs/superpowers/interview/2026-10-15-e2e-interview.md\n---\n## R1\n' > "$LFILE"
ln -s "$LFILE" "$LD/2026-10-15-e2e-brief-interview.state.md"
LB="$LD/2026-10-15-e2e-brief-interview.md"
printf -- '---\ntype: interview-brief\n---\n# l\n' > "$LB"; printf -- '---\ntype: interview-audit\n---\n# l\n' > "${LB%.md}.audit.md"
[ -L "$L/.claude/spec-distill/.docreview" ] && [ -L "$LD/2026-10-15-e2e-brief-interview.state.md" ] \
  && ok "7 전제: .docreview 와 상태 파일이 밖을 가리키는 링크다" || no "7 전제: 링크가 아니다 — 아래 칸이 공허하다"
lsum="$(cksum < "$LFILE")"
o="$(in_sess "$L" "$A" "ARG_PATH='$LD/2026-10-15-e2e-brief-interview.state.md'
$ENTRY")"
case "$(printf '%s\n' "$o" | tail -n 1)" in "interview-state: REJECT "*) ok "7: 링크인 상태 파일로는 이어 가지 않는다(REJECT)" ;; *) no "7: 링크인 상태 파일 진입: $o" ;; esac
rm -f "$LB"   # 끝나지 않은 인터뷰로 보이게 — 링크인 후보도 ASK 에 오르지 않는다
o="$(in_sess "$L" "$A" "ARG_PATH='$LSEED'
$ENTRY")"
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "interview-state: NEW-SEED e2e-brief seed=docs/superpowers/interview/2026-10-15-e2e-interview.md" "7: 링크인 상태 파일은 이어 갈 후보가 아니다"
printf -- '---\ntype: interview-brief\n---\n# l\n' > "$LB"
ln0="$(git -C "$L" rev-list --count HEAD)"
o="$(in_sess "$L" "$A" "${COMMIT//"$PH"/$LB}")"
assert_eq "$(git -C "$L" rev-list --count HEAD)" "$ln0" "7: 상태 파일이 링크면 끝내기 커밋을 하지 않는다"
assert_eq "$(git -C "$L" diff --cached --name-only)" "" "7: 그때 아무것도 stage 하지 않는다"
assert_contains "$o" "커밋하지 않았다" "7: 커밋하지 않은 사유를 보인다"
o="$(in_sess "$L" "$A" "PAYLOAD='$LB'; AUDIT='${LB%.md}.audit.md'
$RB_OPEN
mkdir -p \"\$STATE_DIR\"; echo after-fence-ran")"; rc=$?
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: NO_DIR" "7: 링크된 .docreview — reviewing-brief 원장 열기가 NO_DIR"
assert_eq "$rc" "3" "7: NO_DIR 은 호출을 rc 3 으로 끝내 뒤 명령이 돌지 않는다"
o="$(in_sess "$L" "$B" "${BA//"$PH"/$LB}")"
assert_eq "$(ls -A "$LOUT")" "" "7: 링크 너머 폴더가 비어 있다(원장 열기 · B-A 뒤)"
assert_eq "$(cksum < "$LFILE")" "$lsum" "7: 링크 너머 상태 파일이 그대로다"

finish
