#!/usr/bin/env bash
# state_path.py state-root-for — 문서가 속한 레포의 상태 루트 (R13 §5 · AC9).
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HELPER="$REPO_ROOT/plugins/spec-distill/scripts/state_path.py"
. "$REPO_ROOT/shared/tests/assert.sh"

T=$(mktemp -d -t specdistill-ledgerroot-XXXXXX) || exit 1
T=$(cd "$T" && pwd -P) || exit 1
trap 'rm -rf "$T"' EXIT
export PYTHONDONTWRITEBYTECODE=1

mkrepo() {
  git init -q "$1" && git -C "$1" config user.email t@t.t && git -C "$1" config user.name t
  mkdir -p "$1/docs" && echo x > "$1/docs/x.md" && git -C "$1" add docs/x.md && git -C "$1" commit -qm init
}
A="$T/A"; B="$T/B"
mkrepo "$A"; mkrepo "$B"
git -C "$A" worktree add -q "$T/A-wt" 2>/dev/null || git -C "$A" worktree add -q "$T/A-wt" HEAD
mkdir -p "$T/nogit"; echo x > "$T/nogit/x.md"
NOTICE_PREFIX="[spec-distill] 문서가 git 작업 트리 밖이다 — 지금 작업 폴더의 레포 원장을 쓴다: "

run() {  # run <cwd> <args...> → SRF_OUT SRF_ERR SRF_RC
  local d="$1"; shift
  SRF_OUT=$(cd "$d" && python3 "$HELPER" "$@" 2>"$T/err"); SRF_RC=$?
  SRF_ERR=$(cat "$T/err")
}

note "== srf_inside_other_repo"
run "$B" state-root-for "$A/docs/x.md"
assert_eq "$SRF_OUT" "$A/.claude/spec-distill" "다른 레포 안 문서 → 그 레포의 상태 루트"
assert_eq "$SRF_ERR|$SRF_RC" "|0" "다른 레포 안: stderr 비움 · rc 0"

note "== srf_linked_worktree"
run "$B" state-root-for "$T/A-wt/docs/x.md"
assert_eq "$SRF_OUT" "$A/.claude/spec-distill" "연결된 worktree 안 문서 → 본 레포 상태 루트"

note "== srf_outside_git"
run "$B" state-root-for "$T/nogit/x.md"
assert_eq "$SRF_OUT" "$B/.claude/spec-distill" "git 밖 문서 → 지금 cwd 레포의 상태 루트"
assert_eq "$SRF_ERR" "${NOTICE_PREFIX}$T/nogit/x.md" "git 밖: stderr 가 정확히 한 줄 공시"
assert_eq "$SRF_RC" "0" "git 밖: rc 0"

note "== srf_empty_is_state_root"
run "$B" state-root
want="$SRF_OUT"
run "$B" state-root-for ""
assert_eq "$SRF_OUT" "$want" "빈 인자 → state-root 와 같다"
assert_eq "$SRF_ERR|$SRF_RC" "|0" "빈 인자: 공시 없음 · rc 0"

note "== srf_relative"
run "$A" state-root-for docs/x.md
assert_eq "$SRF_OUT" "$A/.claude/spec-distill" "상대 경로 → 문서가 속한 레포의 상태 루트"
assert_eq "$SRF_ERR" "" "상대 경로: stderr 비움"

note "== srf_missing_folder"
run "$A" payload-root "$A/nodir/x.md"; pr_out="$SRF_OUT"; pr_err="$SRF_ERR"; pr_rc="$SRF_RC"
run "$B" state-root-for "$A/nodir/x.md"
assert_eq "$SRF_RC|$SRF_OUT|$SRF_ERR" "$pr_rc|$pr_out|$pr_err" "없는 폴더 → payload-root 와 같은 rc · 출력 · 사유"

note "== srf_link_folder_refused"
mkdir -p "$T/outside"; ln -s "$T/outside" "$A/linkdir"
run "$A" payload-root "$A/linkdir/x.md"; pr_err="$SRF_ERR"; pr_rc="$SRF_RC"
run "$B" state-root-for "$A/linkdir/x.md"
assert_eq "$SRF_RC|$SRF_OUT" "2|" "링크 폴더 → rc 2 · stdout 비움"
assert_eq "$SRF_ERR" "$pr_err" "링크 폴더: payload-root 와 같은 사유 줄"
assert_eq "$pr_rc" "2" "양성 대조: payload-root 도 rc 2"

# ── 펜스 — RB · SR · finishing.md 의 상태 루트 호출은 모두 문서 변수를 넘기는 state-root-for (AC9) ──
SD="$REPO_ROOT/plugins/spec-distill"
SR="$SD/skills/spec-review/SKILL.md"; RB="$SD/skills/reviewing-brief/SKILL.md"
FIN="$SD/skills/pm-interview/references/finishing.md"; RF="$SD/skills/request-framing/SKILL.md"

note "== root_lock"
# root_lock <RB> <SR> <FIN> <RF> → stdout 위반 줄(없으면 빈 값)
root_lock() {
  python3 -I - "$@" <<'PY'
import re, sys
BARE = re.compile(r"""state_path\.py["']?\s+state-root\b(?!-for)""")
FOR = re.compile(r"""state_path\.py["']?\s+state-root-for(?:[ \t]+("[^"\n]*"))?""")
ALLOWED = {
    "RB": {'"$PAYLOAD"', '"${PAYLOAD:-}"'},
    "SR": {'"${spec_path:-}"', '"$spec_path"'},
    "FIN": {'"$PAYLOAD"', '"${PAYLOAD:-}"'},
}
bad = []
for name, path in zip(("RB", "SR", "FIN"), sys.argv[1:4]):
    text = open(path, encoding="utf-8").read()
    for n, line in enumerate(text.splitlines(), 1):
        if BARE.search(line):
            bad.append("%s:%d: 맨 state-root 호출: %s" % (name, n, line.strip()))
        for m in FOR.finditer(line):
            if m.group(1) not in ALLOWED[name]:
                bad.append("%s:%d: state-root-for 첫 인자가 문서 변수가 아니다(%s)" % (name, n, m.group(1)))
    if not FOR.search(text):
        bad.append("%s: state-root-for 호출이 없다" % name)
# RF 예외: seed 경로를 cwd 에서 만든다(`$(pwd)/$SEED`) — 원장 뿌리도 cwd 레포의 것이라 맨 state-root 하나가 맞다.
rf = open(sys.argv[4], encoding="utf-8").read().splitlines()
section, hits = None, []
for n, line in enumerate(rf, 1):
    if line.startswith("## "):
        section = line
    if BARE.search(line):
        hits.append((n, section))
if len(hits) != 1:
    bad.append("RF: 맨 state-root 호출이 정확히 하나가 아니다(%d)" % len(hits))
for n, section in hits:
    if section != "## 상태":
        bad.append("RF:%d: 맨 state-root 호출이 「## 상태」 밖이다(%s)" % (n, section))
print("\n".join(bad))
PY
}
rl="$(root_lock "$RB" "$SR" "$FIN" "$RF")"
assert_eq "$rl" "" "root_lock: RB · SR · finishing.md 는 문서 변수를 넘기는 state-root-for 만, RF 는 「## 상태」 의 맨 호출 하나만(RF 는 seed 경로를 cwd 에서 만들어(\$(pwd)/\$SEED) 원장 뿌리도 cwd 레포의 것이다)"
for f in "$RB" "$SR" "$FIN"; do
  n="$(grep -c 'state_path.py" state-root-for' "$f" || true)"
  [ "${n:-0}" -ge 1 ] && ok "root_lock(양의 짝): ${f##*/plugins/spec-distill/} 에 state-root-for 가 ${n}번" \
    || no "root_lock(양의 짝): ${f##*/plugins/spec-distill/} 에 state-root-for 가 없다"
done
n="$(grep -c 'state_path.py" state-root)' "$RF" || true)"
assert_eq "$n" "1" "root_lock(양의 짝): RF 에 맨 state-root 호출이 하나 있다"

# ── 끝에서 끝 — 원장 열기 · 결정 줄 펜스 (AC10) ──
fence() {   # fence <파일> <마커 이름> → 그 마커 사이 첫 bash 펜스 본문
  awk -v b="<!-- $2:begin -->" -v e="<!-- $2:end -->" '
    index($0,b){f=1;next} index($0,e){f=0} f&&/^```bash$/{c=1;next} f&&c&&/^```$/{c=0;next} f&&c' "$1"
}
dl_fill() {   # dl_fill <줄> <사용자 말> → 결정 줄 펜스 본문(두 heredoc 자리를 채운다)
  fence "$SR" decision-line | python3 -I -c 'import sys
t = sys.stdin.read()
t = t.replace("\n<결정 줄>\n", "\n" + sys.argv[1] + "\n").replace("\n<사용자가 적은 글 그대로>\n", "\n" + sys.argv[2] + "\n")
sys.stdout.write(t)' "$1" "$2"
}
run_fence() {   # run_fence <cwd> <sid> <앞 대입 줄> <펜스 본문> → E_OUT E_RC
  E_OUT="$(cd "$1" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID="$2" DEVBREW_SPEC_DISTILL_SESSION_ID="$2" \
    /bin/bash -c "$3
$4" 2>&1)"; E_RC=$?
}
sdir_for() { python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$1/.claude/spec-distill" --doc "$2"; }
open_round() {   # open_round <state dir> <문서> — 엔진 원장을 만들고 라운드를 연다
  python3 "$SD/scripts/docreview_state.py" init --state-dir "$1" --doc "$2" --profile "$SD/references/docreview-profiles/design-doc.md" >/dev/null
  python3 "$SD/scripts/docreview_anchor.py" snapshot "$2" > "$T/snap.json"
  python3 "$SD/scripts/docreview_state.py" begin-round --state-dir "$1" --snapshot "$T/snap.json" >/dev/null
}
count_line() { printf '%s\n' "$1" | grep -cxF -- "$2" || true; }
mkdoc() { printf '# D\n\n## 결정 기록\n\n- B1 · 결정 · 2026-10-21 · 처음 — 「네」\n' > "$1"; }
LO_NOTICE() { printf '[spec-distill] 리뷰 원장은 문서가 사는 레포(%s)의 것을 쓴다 — 지금 작업 폴더의 레포(%s)와 다르다.' "$1" "$2"; }

note "== e2e_other_repo"
DDOC="$A/docs/d-design.md"; mkdoc "$DDOC"
run_fence "$B" sess-root0001 "spec_path='$DDOC'" "$(fence "$SR" ledger-open)"
assert_eq "$(printf '%s\n' "$E_OUT" | tail -n 1)" "ledger-open: HELD" "e2e_other_repo: cwd=B · 문서 A — 원장 열기가 표지를 잡는다"
SA="$(sdir_for "$A" "$DDOC")"
assert_eq "$(cat "$SA/reviewing-by" 2>/dev/null)" "sess-root0001" "e2e_other_repo: 표지가 A 의 상태 루트 아래 원장 자리에 선다"
assert_eq "$(count_line "$E_OUT" "$(LO_NOTICE "$A" "$B")")" "1" "e2e_other_repo: 원장 열기가 두 레포를 대는 공시 한 줄을 정확히 한 번 낸다"
open_round "$SA" "$DDOC"
DL1='B2 · 결정 · 2026-10-21 · 다른 레포에서 씀'
run_fence "$B" sess-root0001 "spec_path='$DDOC'" "$(dl_fill "$DL1" '네')"
assert_eq "$E_RC $(grep -cxF -- "- $DL1 — 「네」" "$DDOC")" "0 1" "e2e_other_repo: 결정 줄 펜스가 같은 원장으로 결정 줄 한 줄을 쓴다(rc 3 아님)"
assert_contains "$E_OUT" "[spec-distill] 결정 줄은 문서가 사는 레포(${A})의 원장으로 쓴다 — 지금 작업 폴더의 레포(${B})와 다르다." "e2e_other_repo: 결정 줄 펜스의 레포 다름 줄은 그대로다"
[ ! -e "$B/.claude" ] && ok "e2e_other_repo: B 에 상태 폴더가 생기지 않는다" || no "e2e_other_repo: B 에 상태 폴더가 생겼다"

note "== e2e_same_repo_no_notice"
SDOC="$A/docs/s-design.md"; mkdoc "$SDOC"
run_fence "$A" sess-root0002 "spec_path='$SDOC'" "$(fence "$SR" ledger-open)"
assert_eq "$(printf '%s\n' "$E_OUT" | tail -n 1)" "ledger-open: HELD" "e2e_same_repo_no_notice: 전제 — 원장 열기가 돌았다"
assert_not_contains "$E_OUT" "지금 작업 폴더의 레포(" "e2e_same_repo_no_notice: 같은 레포 — 원장 열기가 레포 다름을 알리지 않는다"
open_round "$(sdir_for "$A" "$SDOC")" "$SDOC"
run_fence "$A" sess-root0002 "spec_path='$SDOC'" "$(dl_fill 'B2 · 결정 · 2026-10-21 · 같은 레포' '네')"
assert_eq "$E_RC" "0" "e2e_same_repo_no_notice: 전제 — 결정 줄 펜스가 썼다"
assert_not_contains "$E_OUT" "지금 작업 폴더의 레포(" "e2e_same_repo_no_notice: 같은 레포 — 결정 줄 펜스가 레포 다름을 알리지 않는다"

note "== e2e_linked_worktree_no_notice"
[ -f "$T/A-wt/.git" ] && ok "전제: A 의 연결된 worktree 가 있다" || no "전제: A 의 연결된 worktree 가 없다 — 아래 칸이 공허하다"
WDOC="$T/A-wt/docs/w-design.md"; mkdoc "$WDOC"
run_fence "$A" sess-root0005 "spec_path='$WDOC'" "$(fence "$SR" ledger-open)"
assert_eq "$(printf '%s\n' "$E_OUT" | tail -n 1)" "ledger-open: HELD" "e2e_linked_worktree_no_notice: 전제 — 원장 열기가 돌았다"
assert_not_contains "$E_OUT" "지금 작업 폴더의 레포(" "e2e_linked_worktree_no_notice: cwd=A · 문서는 A 의 연결된 worktree — 공용 git 폴더가 같아 레포 다름을 알리지 않는다"
assert_eq "$(cat "$(sdir_for "$A" "$WDOC")/reviewing-by" 2>/dev/null)" "sess-root0005" "e2e_linked_worktree_no_notice: 원장이 A 의 상태 루트 아래다"
[ ! -e "$T/A-wt/.claude" ] && ok "e2e_linked_worktree_no_notice: worktree 쪽에 상태 폴더가 생기지 않는다" || no "e2e_linked_worktree_no_notice: worktree 쪽에 상태 폴더가 생겼다"

note "== e2e_rb_ledger_open"
BDOC="$A/docs/b-brief.md"; printf '# brief\n' > "$BDOC"
run_fence "$B" sess-root0003 "PAYLOAD='$BDOC'" "$(fence "$RB" ledger-open)"
assert_eq "$(printf '%s\n' "$E_OUT" | tail -n 1)" "ledger-open: HELD" "e2e_rb_ledger_open: cwd=B · payload A — 원장 열기가 표지를 잡는다"
assert_eq "$(cat "$(sdir_for "$A" "$BDOC")/reviewing-by" 2>/dev/null)" "sess-root0003" "e2e_rb_ledger_open: 표지가 A 의 원장 자리에 선다"
assert_eq "$(count_line "$E_OUT" "$(LO_NOTICE "$A" "$B")")" "1" "e2e_rb_ledger_open: 공시 한 줄을 정확히 한 번 낸다"
[ ! -e "$B/.claude" ] && ok "e2e_rb_ledger_open: B 에 상태 폴더가 생기지 않는다" || no "e2e_rb_ledger_open: B 에 상태 폴더가 생겼다"

note "== e2e_outside_git"
NDOC="$T/nogit/d-design.md"; mkdoc "$NDOC"
git -C "$T/nogit" rev-parse --show-toplevel >/dev/null 2>&1 && no "전제: $T/nogit 이 git 작업 트리 안이다" || ok "전제: $T/nogit 은 git 작업 트리 밖이다"
run_fence "$B" sess-root0004 "spec_path='$NDOC'" "$(fence "$SR" ledger-open)"
assert_eq "$(printf '%s\n' "$E_OUT" | tail -n 1)" "ledger-open: HELD" "e2e_outside_git: 원장 열기가 표지를 잡는다"
SN="$(sdir_for "$B" "$NDOC")"
assert_eq "$(cat "$SN/reviewing-by" 2>/dev/null)" "sess-root0004" "e2e_outside_git: 원장 자리가 B(cwd) 상태 루트 아래다"
assert_eq "$(count_line "$E_OUT" "${NOTICE_PREFIX}${NDOC}")" "1" "e2e_outside_git: 원장 열기가 git 밖 줄을 정확히 한 번 낸다"
assert_not_contains "$E_OUT" "지금 작업 폴더의 레포(" "e2e_outside_git: 원장 열기가 레포 다름 줄을 내지 않는다"
open_round "$SN" "$NDOC"
DL2='B2 · 결정 · 2026-10-21 · git 밖에서 씀'
run_fence "$B" sess-root0004 "spec_path='$NDOC'" "$(dl_fill "$DL2" '네')"
assert_eq "$E_RC $(grep -cxF -- "- $DL2 — 「네」" "$NDOC")" "0 1" "e2e_outside_git: 결정 줄 펜스가 거절하지 않고 같은 원장으로 한 줄을 쓴다"
assert_not_contains "$E_OUT" "git 작업 트리 밖이다(" "e2e_outside_git: 옛 거절 문장이 없다"
assert_eq "$(count_line "$E_OUT" "${NOTICE_PREFIX}${NDOC}")" "1" "e2e_outside_git: 결정 줄 펜스가 git 밖 줄을 낸다"

note "== prose_limits"
pl="$(python3 -I - "$SR" <<'PY'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
i = t.find("**결정 줄 펜스.**"); j = t.find("<!-- decision-line:begin -->", i)
para = t[i:j] if 0 <= i < j else ""
rc1 = [l for l in para.splitlines() if l.startswith("- rc 1 · rc 3 —")]
print("rc1=%d" % len(rc1))
print("neg=%s" % ("있음" if any("문서가 git 작업 트리 밖이다" in l for l in rc1) else "없음"))
print("pos=%s" % ("있음" if "git 작업 트리 밖이면 지금 작업 폴더 레포의 원장에 쓴다" in para else "없음"))
PY
)"
assert_contains "$pl" "rc1=1" "prose_limits: 전제 — 결정 줄 산문의 rc 1 사유 목록을 찾았다"
assert_contains "$pl" "neg=없음" "prose_limits: rc 1 사유 목록에 「문서가 git 작업 트리 밖이다」 가 없다"
assert_contains "$pl" "pos=있음" "prose_limits(양의 짝): 그 문단에 git 밖이면 지금 작업 폴더 레포의 원장에 쓴다는 줄이 있다"

note "== existing_unchanged"
OLD="$T/old"; mkdir -p "$OLD"
git -C "$REPO_ROOT" show d433cd3b:plugins/spec-distill/scripts/state_path.py > "$OLD/state_path.py"
cmp_old() {  # cmp_old <cwd> <args...>
  local d="$1"; shift
  local o n
  o=$(cd "$d" && python3 "$OLD/state_path.py" "$@" 2>&1; echo "rc=$?")
  n=$(cd "$d" && python3 "$HELPER" "$@" 2>&1; echo "rc=$?")
  assert_eq "$n" "$o" "고치기 전과 같다: ${d##*/} $*"
}
cmp_old "$A" state-root
cmp_old "$T/A-wt" state-root
cmp_old "$T/nogit" state-root
cmp_old "$B" state-root "$A"
cmp_old "$B" state-root "$T/nogit"
cmp_old "$B" payload-root "$A/docs/x.md"
cmp_old "$B" payload-root "$T/nogit/x.md"
cmp_old "$B" payload-root "$A/nodir/x.md"
cmp_old "$B" payload-root "$A/linkdir/x.md"
cmp_old "$B" payload-root ""
cmp_old "$B" payload-root

# README 한계 문장 — 다른 레포의 문서를 리뷰하는 동안 cwd 레포 원장은 정리되지 않는다
assert_contains "$(cat "$REPO_ROOT/plugins/spec-distill/README.md")" '다른 레포의 문서를 리뷰하는 동안에는 지금 작업 폴더 레포의 원장이 그때 정리되지 않는다' "README: §5 한계 문장"

finish
