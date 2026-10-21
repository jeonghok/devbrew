#!/usr/bin/env bash
# state_path.py 상태 루트 보장 — 자기 무시 · 추적 파일이면 멈춤 · bare 레포 · 환경 변수 공시 (R8 AC24 · §6).
set -u
unset GIT_DIR GIT_WORK_TREE
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
HELPER="$SD/scripts/state_path.py"
. "$REPO_ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

T="$(mktemp -d -t sd-stateroot-XXXXXX)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
T="$(cd "$T" && pwd -P)" || exit 1
trap 'rm -rf "$T"' EXIT

g() { git -c user.email=t@t.t -c user.name=t -c commit.gpgsign=false "$@"; }
mkrepo() {   # mkrepo <폴더> — 커밋 하나, .gitignore 없음
  g init -q "$1" && mkdir -p "$1/docs" && echo x > "$1/docs/x.md" && g -C "$1" add docs/x.md && g -C "$1" commit -qm init
}
mktracked() {   # mktracked <레포> — 상태 루트 아래 파일 하나를 git add -f 로 추적시킨다
  mkdir -p "$1/.claude/spec-distill" && echo t > "$1/.claude/spec-distill/kept.md" && g -C "$1" add -f .claude/spec-distill/kept.md
}
run() {   # run <cwd> <args...> → OUT ERR RC
  local d="$1"; shift
  OUT="$(cd "$d" && python3 "$HELPER" "$@" 2>"$T/err")"; RC=$?
  ERR="$(cat "$T/err")"
}
TRACKED() { printf '[spec-distill] 상태 폴더 아래 파일이 이미 추적된다 — git rm --cached -r %s 로 추적을 푼 뒤 다시 돈다' "$1/.claude/spec-distill"; }

note "== ensure_self_ignore"
A="$T/A"; mkrepo "$A"
run "$A" state-root --ensure
assert_eq "$RC|$OUT" "0|$A/.claude/spec-distill" "ensure_self_ignore: rc 0 · stdout 은 상태 루트"
assert_eq "$(cat "$A/.claude/spec-distill/.gitignore" 2>/dev/null)" "*" "ensure_self_ignore: 상태 루트의 .gitignore 는 * 한 줄"
assert_eq "$(git -C "$A" status --porcelain)" "" "ensure_self_ignore: .claude/ 를 무시하지 않는 레포에서 ensure 뒤 git status 가 비었다"
P="$T/P"; mkrepo "$P"; mkdir -p "$P/.claude/spec-distill"; echo x > "$P/.claude/spec-distill/f"
[ -n "$(git -C "$P" status --porcelain)" ] && ok "ensure_self_ignore(양성 대조): .gitignore 없는 같은 꼴 폴더는 git status 에 보인다" \
  || no "ensure_self_ignore(양성 대조): .gitignore 없이도 git status 가 비었다 — 위 칸이 공허하다"
run "$A" state-root --ensure
assert_eq "$RC|$OUT|$(cat "$A/.claude/spec-distill/.gitignore")" "0|$A/.claude/spec-distill|*" "ensure_self_ignore: 두 번째 ensure 도 rc 0 · .gitignore 그대로"

note "== ensure_flag_is_not_cwd"
B="$T/B"; mkrepo "$B"
run "$B" state-root --ensure
assert_eq "$OUT" "$B/.claude/spec-distill" "ensure_flag_is_not_cwd: --ensure 를 cwd 로 읽지 않는다"
assert_not_contains "$ERR" "fallback" "ensure_flag_is_not_cwd: cwd 대체 공시가 없다"
C0="$T/C0"; mkrepo "$C0"
run "$C0" state-root "$B" --ensure
assert_eq "$RC|$OUT" "0|$B/.claude/spec-distill" "ensure_flag_is_not_cwd: state-root <cwd> --ensure → 그 cwd 레포"
run "$C0" state-root --ensure "$B"
assert_eq "$RC|$OUT" "0|$B/.claude/spec-distill" "ensure_flag_is_not_cwd: 순서가 바뀌어도 같다"
[ ! -e "$C0/.claude" ] && ok "ensure_flag_is_not_cwd: 지금 cwd 레포에 상태 폴더가 생기지 않는다" || no "ensure_flag_is_not_cwd: 지금 cwd 레포에 상태 폴더가 생겼다"

note "== ensure_for_other_repo"
D="$T/D"; mkrepo "$D"
run "$C0" state-root-for "$D/docs/x.md"
[ ! -e "$D/.claude" ] && ok "ensure_for_other_repo: --ensure 없는 state-root-for 는 폴더를 만들지 않는다(읽기 길)" || no "ensure_for_other_repo: --ensure 없이 폴더가 생겼다"
run "$C0" state-root-for "$D/docs/x.md" --ensure
assert_eq "$RC|$OUT" "0|$D/.claude/spec-distill" "ensure_for_other_repo: cwd=C0 · 문서 D → D 의 상태 루트"
assert_eq "$(cat "$D/.claude/spec-distill/.gitignore" 2>/dev/null)" "*" "ensure_for_other_repo: D 의 상태 루트에 .gitignore 가 생긴다"
[ ! -e "$C0/.claude" ] && ok "ensure_for_other_repo: cwd 레포에는 생기지 않는다" || no "ensure_for_other_repo: cwd 레포에 상태 폴더가 생겼다"
mkdir -p "$T/nogit"; echo x > "$T/nogit/x.md"
run "$C0" state-root-for "$T/nogit/x.md" --ensure
assert_eq "$RC|$OUT" "0|$C0/.claude/spec-distill" "ensure_for_other_repo: git 밖 문서 → cwd 레포의 상태 루트를 보장한다"
assert_eq "$(cat "$C0/.claude/spec-distill/.gitignore" 2>/dev/null)" "*" "ensure_for_other_repo: git 밖 문서면 cwd 레포에 .gitignore"
run "$C0" state-root-for "" --ensure
assert_eq "$RC|$OUT" "0|$C0/.claude/spec-distill" "ensure_for_other_repo: 빈 문서 → state-root 와 같다"

note "== args_refused"
R2="$T/R2"; mkrepo "$R2"
refused() { run "$R2" "$@"; assert_eq "$RC|$OUT" "2|" "args_refused: $* → rc 2 · stdout 비움"; }
refused state-root-for "$R2/docs/x.md" --bogus
refused state-root-for "$R2/docs/x.md" x
refused state-root-for "$R2/docs/x.md" --ensure --ensure
refused state-root --ensure x y
refused state-root "$R2" x
refused state-root --bogus
[ ! -e "$R2/.claude" ] && ok "args_refused: 거부한 호출은 폴더를 만들지 않는다" || no "args_refused: 거부한 호출이 폴더를 만들었다"

note "== tracked_stops"
E="$T/E"; mkrepo "$E"; mktracked "$E"
run "$E" state-root --ensure
assert_eq "$RC|$OUT" "3|" "tracked_stops: 상태 루트 아래 추적 파일 → rc 3 · stdout 비움"
assert_contains "$ERR" "$(TRACKED "$E")" "tracked_stops: 고치는 법을 담은 안내 문장"
run "$C0" state-root-for "$E/docs/x.md" --ensure
assert_eq "$RC|$OUT" "3|" "tracked_stops: state-root-for <문서> --ensure 도 rc 3"
run "$E" state-root
assert_eq "$RC|$OUT" "0|$E/.claude/spec-distill" "tracked_stops: --ensure 없는 읽기 길은 막지 않는다"
g -C "$E" rm -q --cached -r .claude/spec-distill
run "$E" state-root --ensure
assert_eq "$RC|$OUT" "0|$E/.claude/spec-distill" "tracked_stops(양의 짝): 추적을 풀면 rc 0"

note "== bare_split"
S="$T/seed"; mkrepo "$S"; mkdir -p "$T/bares"
g clone -q --bare "$S" "$T/bares/a.git"; g clone -q --bare "$S" "$T/bares/b.git"
g -C "$T/bares/a.git" worktree add -q --detach "$T/wa" HEAD
g -C "$T/bares/b.git" worktree add -q --detach "$T/wb" HEAD
run "$T/wa" state-root; ra="$OUT"
run "$T/wb" state-root; rb="$OUT"
assert_eq "$ra" "$T/bares/a.git/.claude/spec-distill" "bare_split: a.git 의 worktree → a.git 안"
assert_eq "$rb" "$T/bares/b.git/.claude/spec-distill" "bare_split: b.git 의 worktree → b.git 안"
[ -n "$ra" ] && [ "$ra" != "$rb" ] && ok "bare_split: 같은 부모 폴더의 bare 둘이 서로 다른 상태 루트를 쓴다" || no "bare_split: 두 bare 가 같은 상태 루트를 쓴다($ra)"
run "$T/bares/a.git" state-root
assert_eq "$OUT" "$ra" "bare_split: bare 폴더 자신에서도 같은 자리"

note "== bare_ensure"
run "$T/wa" state-root --ensure
assert_eq "$RC|$OUT" "0|$T/bares/a.git/.claude/spec-distill" "bare_ensure: bare 의 worktree 에서 --ensure → rc 0"
assert_eq "$(cat "$T/bares/a.git/.claude/spec-distill/.gitignore" 2>/dev/null)" "*" "bare_ensure: 추적 검사를 건너뛰고 .gitignore 는 쓴다"
[ ! -e "$T/bares/.claude" ] && ok "bare_ensure: 부모 폴더에 상태 폴더가 생기지 않는다" || no "bare_ensure: 부모 폴더에 상태 폴더가 생겼다"

note "== linked_worktree"
F="$T/F"; mkrepo "$F"; g -C "$F" worktree add -q --detach "$T/F-wt" HEAD
run "$T/F-wt" state-root
assert_eq "$OUT" "$F/.claude/spec-distill" "linked_worktree: 평범한 레포의 연결된 worktree → 본 체크아웃의 상태 루트(그대로)"
run "$T/F-wt" state-root --ensure
assert_eq "$RC|$OUT" "0|$F/.claude/spec-distill" "linked_worktree: 연결된 worktree 를 cwd 로 --ensure → rc 0"
assert_eq "$(cat "$F/.claude/spec-distill/.gitignore" 2>/dev/null)" "*" "linked_worktree: 본 체크아웃의 상태 루트에 .gitignore"
[ ! -e "$T/F-wt/.claude" ] && ok "linked_worktree: worktree 쪽에 상태 폴더가 생기지 않는다" || no "linked_worktree: worktree 쪽에 상태 폴더가 생겼다"
mktracked "$F"
run "$T/F-wt" state-root --ensure
assert_eq "$RC|$OUT" "3|" "linked_worktree: 본 체크아웃에서 추적시키면 연결된 worktree 에서도 rc 3"
assert_contains "$ERR" "$(TRACKED "$F")" "linked_worktree: 안내가 본 체크아웃의 상태 루트를 댄다"

note "== plain_path_unchanged"
run "$A" state-root
assert_eq "$RC|$OUT|$ERR" "0|$A/.claude/spec-distill|" "plain_path_unchanged: 평범한 레포는 <레포>/.claude/spec-distill 그대로"

note "== git_dir_notice"
OUT="$(cd "$A" && GIT_DIR="$A/.git" python3 "$HELPER" state-root --ensure 2>"$T/err")"; RC=$?; ERR="$(cat "$T/err")"
assert_eq "$RC|$OUT" "0|$A/.claude/spec-distill" "git_dir_notice: GIT_DIR 설정 — rc 0 · 같은 상태 루트"
assert_contains "$ERR" "[spec-distill] 환경 변수 GIT_DIR 가 설정된 채로 돈다" "git_dir_notice: 알림 한 줄"
OUT="$(cd "$A" && GIT_DIR="$A/.git" GIT_WORK_TREE="$A" python3 "$HELPER" state-root --ensure 2>"$T/err")"; RC=$?; ERR="$(cat "$T/err")"
assert_contains "$ERR" "GIT_DIR · GIT_WORK_TREE" "git_dir_notice: 둘 다면 둘 다 댄다"
assert_eq "$(printf '%s\n' "$ERR" | grep -c '환경 변수')" "1" "git_dir_notice: 알림은 한 줄"
run "$A" state-root --ensure
assert_not_contains "$ERR" "환경 변수" "git_dir_notice(양의 짝): 변수가 없으면 알리지 않는다"

note "== link_refused"
L1="$T/L1"; mkrepo "$L1"; mkdir -p "$T/out1" "$L1/.claude"; ln -s "$T/out1" "$L1/.claude/spec-distill"
run "$L1" state-root --ensure
assert_eq "$RC|$OUT" "3|" "link_refused: 상태 루트가 링크면 rc 3 · stdout 비움"
assert_contains "$ERR" "상태 폴더 경로가 링크를 거친다" "link_refused: 사유"
assert_eq "$(ls -A "$T/out1")" "" "link_refused: 링크 너머에 .gitignore 를 쓰지 않았다"
L2="$T/L2"; mkrepo "$L2"; mkdir -p "$T/out2"; ln -s "$T/out2" "$L2/.claude"
run "$L2" state-root --ensure
assert_eq "$RC|$(ls -A "$T/out2")" "3|" "link_refused: .claude 가 링크여도 rc 3 · 너머가 비었다"
L3="$T/L3"; mkrepo "$L3"; mkdir -p "$L3/.claude/spec-distill"; echo x > "$T/out3"; ln -s "$T/out3" "$L3/.claude/spec-distill/.gitignore"
run "$L3" state-root --ensure
assert_eq "$RC|$(cat "$T/out3")" "3|x" "link_refused: .gitignore 가 링크면 rc 3 · 너머 파일 그대로"
assert_contains "$ERR" ".gitignore 가 링크다" "link_refused: .gitignore 링크 사유"

note "== rf_state_block"
rf_block() { awk '/^## 상태$/{s=1} s&&/^```bash$/{b=1;next} b&&/^```$/{exit} b' "$SD/skills/request-framing/SKILL.md"; }
rf_block > "$T/rf-state.sh"
grep -q 'state-root --ensure' "$T/rf-state.sh" && bash -n "$T/rf-state.sh" && ok "rf_state_block: 전제 — 「## 상태」 블록을 잘라 냈다" || no "rf_state_block: 블록을 잘라 내지 못했다 — 아래 칸이 공허하다"
RT="$T/RT"; mkrepo "$RT"; mktracked "$RT"
RF_OUT="$(cd "$RT" && CLAUDE_PLUGIN_ROOT="$SD" DEVBREW_SPEC_DISTILL_SESSION_ID=sess-root0007 bash "$T/rf-state.sh" 2>&1)"; RF_RC=$?
assert_eq "$RF_RC" "1" "rf_state_block: 추적 파일 레포에서 「## 상태」 블록이 멈춘다"
assert_contains "$RF_OUT" "$(TRACKED "$RT")" "rf_state_block: 고치는 법이 보인다"
assert_contains "$RF_OUT" "상태 폴더를 쓸 수 없다" "rf_state_block: 멈춘 사유 줄"
RC2="$T/RC2"; mkrepo "$RC2"
RF_OUT="$(cd "$RC2" && CLAUDE_PLUGIN_ROOT="$SD" DEVBREW_SPEC_DISTILL_SESSION_ID=sess-root0007 bash "$T/rf-state.sh" 2>&1)"; RF_RC=$?
assert_not_contains "$RF_OUT" "상태 폴더를 쓸 수 없다" "rf_state_block(양의 짝): 깨끗한 레포에서는 멈추지 않는다"
assert_eq "$(cat "$RC2/.claude/spec-distill/.gitignore" 2>/dev/null)" "*" "rf_state_block(양의 짝): 블록이 상태 루트를 보장한다"

note "== conductor_claim_stops"
run_cl() { CL_OUT="$(python3 "$SD/scripts/conductor_ledger.py" "$@" 2>&1)"; CL_RC=$?; }
H="$T/H"; mkrepo "$H"; mktracked "$H"
run_cl --root "$H" claim --roadmap docs/rm/roadmap.md --session sess-root0001
assert_eq "$CL_RC" "3" "conductor_claim_stops: 추적 파일 레포에서 표지 잡기가 rc 3"
assert_contains "$CL_OUT" "상태 폴더 아래 파일이 이미 추적된다" "conductor_claim_stops: 같은 안내"
[ ! -e "$H/.claude/spec-distill/conductor" ] && ok "conductor_claim_stops: 표지 폴더를 만들지 않았다" || no "conductor_claim_stops: 표지 폴더가 생겼다"
K="$T/K"; mkrepo "$K"
run_cl --root "$K" claim --roadmap docs/rm/roadmap.md --session sess-root0001
assert_eq "$CL_RC" "0" "conductor_claim_stops(양의 짝): 깨끗한 레포에서는 rc 0"
assert_eq "$(cat "$K/.claude/spec-distill/.gitignore" 2>/dev/null)" "*" "conductor_claim_stops(양의 짝): 표지 잡기가 .gitignore 를 둔다"
assert_eq "$(git -C "$K" status --porcelain)" "" "conductor_claim_stops(양의 짝): 표지 잡기 뒤 git status 가 비었다"

note "== git_dir_notice_on_stop"
run_cl --root "$H" claim --roadmap docs/rm/roadmap.md --session sess-root0001
assert_not_contains "$CL_OUT" "환경 변수" "git_dir_notice_on_stop(양의 짝): 변수 없이 멈추면 알림이 없다"
OUT="$(cd "$H" && GIT_DIR="$H/.git" python3 "$HELPER" state-root --ensure 2>"$T/err")"; RC=$?; ERR="$(cat "$T/err")"
assert_eq "$RC|$OUT" "3|" "git_dir_notice_on_stop: GIT_DIR 설정 · 추적 파일 → rc 3"
assert_contains "$ERR" "$(TRACKED "$H")" "git_dir_notice_on_stop: 멈춘 사유"
assert_contains "$ERR" "[spec-distill] 환경 변수 GIT_DIR 가 설정된 채로 돈다" "git_dir_notice_on_stop: 멈출 때도 환경 변수 알림이 보인다"
CL_OUT="$(GIT_DIR="$H/.git" python3 "$SD/scripts/conductor_ledger.py" --root "$H" claim --roadmap docs/rm/roadmap.md --session sess-root0001 2>&1)"; CL_RC=$?
assert_eq "$CL_RC" "3" "git_dir_notice_on_stop: 표지 잡기도 rc 3"
assert_contains "$CL_OUT" "환경 변수 GIT_DIR 가 설정된 채로 돈다" "git_dir_notice_on_stop: 표지 잡기가 멈출 때도 환경 변수 알림이 보인다"

finish
