#!/usr/bin/env bash
# team_status.py — 브랜치 끝 읽기(read_tip). 뒤 과제가 단계 표 · 알림 · 과제 읽기 묶음을 이 파일에 더한다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_team_status.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
. "$ROOT/plugins/spec-distill/tests/fixtures/team_repo.sh"
team_repo && ok "팀 레포를 세웠다(${TM})" || { no "팀 레포를 세우지 못했다 — $(cat "$T/out.txt")"; finish; }

tipof() {  # tipof <브랜치> — read_tip 의 세 값을 <커밋 8자 또는 None>|<알림 yes/no>|<갈라짐 yes/no> 로 낸다
  python3 - "$S" "$W" "$1" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import roadmap_status, team_status
commit, note, split = team_status.read_tip(roadmap_status.Git(sys.argv[2]), sys.argv[3])
print("%s|%s|%s" % (commit[:8] if commit else "None", "yes" if note else "no", "yes" if split else "no"))
PY
}
tipnote() {  # tipnote <브랜치> — read_tip 의 둘째 값(알림 줄, 없으면 빈 줄)
  python3 - "$S" "$W" "$1" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import roadmap_status, team_status
print(team_status.read_tip(roadmap_status.Git(sys.argv[2]), sys.argv[3])[1] or "")
PY
}
short() { g rev-parse --short=8 "$1"; }
U="$T/other"
git clone -q "$T/origin.git" "$U"
other() { git -C "$U" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"; }

g checkout -q -b t/same main && put t-same.txt a && g commit -qm same && g push -q origin t/same
assert_eq "$(tipof t/same)" "$(short t/same)|no|no" "끝: 같음 — 그 커밋 · 알림 없음"
put t-same.txt b && g commit -qm ahead
assert_eq "$(tipof t/same)" "$(short t/same)|yes|no" "끝: 로컬이 앞섬 — 로컬 · 「아직 안 올라옴」"
assert_contains "$(tipnote t/same)" "아직 안 올라옴 — t/same 의 로컬 끝" "끝: 알림 글"
g checkout -q -b t/behind main && put t-behind.txt a && g commit -qm one && g push -q origin t/behind
other fetch -q origin && other checkout -q -b t/behind origin/t/behind
printf 'x\n' > "$U/t-behind-2.txt" && other add -- t-behind-2.txt && other commit -qm two && other push -q origin t/behind
g fetch -q origin
assert_eq "$(tipof t/behind)" "$(short origin/t/behind)|no|no" "끝: origin 이 앞섬 — origin · 알림 없음"
put t-behind.txt c && g commit -qm fork
assert_eq "$(tipof t/behind)" "None|no|yes" "끝: 갈라짐 — 읽지 않는다"
g checkout -q -b t/local main && put t-local.txt a && g commit -qm local
assert_eq "$(tipof t/local)" "$(short t/local)|yes|no" "끝: 로컬에만 있는 브랜치 — 「아직 안 올라옴」(Q3)"
g checkout -q main && g branch -q -D t/same && g fetch -q origin
assert_eq "$(tipof t/same)" "$(short origin/t/same)|no|no" "끝: origin 에만 있는 브랜치 — origin · 알림 없음"
assert_eq "$(tipof t/none)" "None|no|no" "끝: 둘 다 없다"

# AC30 — 둘째 구현이 없다: read_tip 의 몸이 branch_tip.tip( 을 부르고 조상 판정 글자가 없다
src="$(python3 -c 'import sys, inspect; sys.path.insert(0, sys.argv[1]); import team_status; print(inspect.getsource(team_status.read_tip))' "$S")"
assert_contains "$src" "branch_tip.tip(" "끝: read_tip 의 몸이 branch_tip.tip( 을 부른다(AC30)"
assert_not_contains "$src" "is_ancestor" "끝: read_tip 의 몸에 is_ancestor 가 없다(AC30)"
assert_not_contains "$src" "merge-base" "끝: read_tip 의 몸에 merge-base 가 없다(AC30)"
# 양성 대조 — branch_tip.tip 을 가짜로 끼우면 첫 값이 그 값이다
fake="$(python3 - "$S" "$W" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import branch_tip, roadmap_status, team_status
branch_tip.tip = lambda root, branch: ("f" * 40, None)
print(team_status.read_tip(roadmap_status.Git(sys.argv[2]), "t/none")[0])
PY
)"
assert_eq "$fake" "ffffffffffffffffffffffffffffffffffffffff" "끝: 양성 대조 — branch_tip.tip 을 바꿔 끼우면 read_tip 의 첫 값이 따라 바뀐다"
finish
