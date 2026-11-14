#!/usr/bin/env bash
# team_status.py — 브랜치 끝 읽기(read_tip) · 단계 표와 받음(Reader.progress). 뒤 과제가 알림 · 과제 읽기 묶음을 이 파일에 더한다.
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
# ── 단계 · 받음 — 단계 표(설계 §10)를 걸음마다 근거 하나만 바꿔 잰다 ─────────────
JRC="$S/job_results.py"
LAST_RC=""
blk() { js "$T/s.json" "[b for b in r['blocks'] if b['id']=='$1'][0].get('$2', '칸 없음')"; }   # blk <번호> <칸>
st() { blk "$1" stage; }
why() { blk "$1" reason; }
prog() { blk "$1" progress; }
notes() { js "$T/s.json" "' | '.join([b for b in r['blocks'] if b['id']=='$1'][0]['notes'])"; }
jobf() { js "$T/s.json" "[b for b in r['blocks'] if b['id']=='$1'][0]['job']['$2']"; }   # jobf <번호> <job 칸>
rc() { echo "$LAST_RC"; }
step() { g add -A && g commit -qm "$1" && g push -q origin HEAD && LAST_RC="$(status "$T/s.json")"; }
back() { g reset -q --hard "$1" && g push -q -f origin HEAD; }   # back <커밋> — 지금 브랜치를 그 커밋으로 되돌려 올린다(임시 레포)
sub() {  # sub <레포 상대 경로> <옛 글> <새 글> — 한 번 나오는 글을 바꾼다(없거나 둘이면 실패)
  python3 - "$W/$1" "$2" "$3" <<'PY'
import sys
path, old, new = sys.argv[1:4]
text = open(path, encoding="utf-8", newline="").read()
if text.count(old) != 1:
    sys.exit("바꿀 글이 한 번 나오지 않는다: %r" % old)
open(path, "w", encoding="utf-8", newline="").write(text.replace(old, new))
PY
}
drop() { grep -v -F -- "$2" "$W/$1" > "$T/drop.tmp"; mv "$T/drop.tmp" "$W/$1"; }   # drop <레포 상대 경로> <글 조각> — 그 조각이 든 줄을 지운다
J1="$TM/jobs/E1"
R1="$J1/results/implement-plan-1-1.md"
BLK="$J1/results/BLOCKED.md"
DESIGN="$(printf -- '---\ntype: design\njob: E1\n---\n\n# 첫 읽기 — 단계 표 픽스처 설계\n\n### §1 읽는 자리\n\n과제 폴더를 읽는다.\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| C1 · S1 | 반영 | §1 |\n\n## Acceptance Criteria\n\n- AC1: 단계를 과제 폴더의 파일로 센다\n- AC2: 진행 숫자를 결과 파일에서 읽는다\n- AC3: 받은 뒤의 변경을 알린다\n\n## 미룸\n\n| 항목 | 이유 | 받는 곳 |\n|---|---|---|')"
PLAN1="$(printf '# 첫 읽기 — 단계 표 픽스처 계획 1\n\n## 차례\n\n### Task 1: 폴더 읽기\n\nAC1 · AC2 를 만든다.\n\n### Task 2: 숫자 읽기\n\n진행 줄을 센다.\n\n### Task 3: 알림 잇기\n\n알림을 단다.')"
# 구현 원장 — 세 단계 가운데 둘이 끝났다(test_team_sync.sh 의 원장과 글이 다르다)
printf '# 단계 표 원장\n\n- Task 1: complete (commits 1a2b3c4..5d6e7f8 — 폴더 읽기)\n- Task 2: complete (커밋 없음 — 숫자만 셌다)\n' > "$T/ledger.md"
# create 가 로드맵 폴더 바로 아래에 깐 공통 문서(역할 문서 · HANDBOOK)는 픽스처가 올리지 않았다 — 기본 브랜치에 올려
# 아래 step 의 add -A 가 그것들을 과제 브랜치의 변경으로 싣지 않게 한다
g add -A -- "$RD" && g commit -qm "공통 문서" && g push -q origin main

status "$T/s.json" >/dev/null
assert_eq "$(js "$T/s.json" "[(b['id'], b['stage']) for b in r['blocks']]")" "[('P1', '준비'), ('E1', '준비'), ('E2', '준비'), ('E3', '대기')]" "단계: create --layout team 이 만든 로드맵 — 대기 · 준비"
assert_eq "$(js "$T/s.json" "(r['exit'], r['layout'], r['unknown_reasons'], r['format_errors'])")" "(0, 'team', [], [])" "AC9: 종료 코드 0 · 검사 불가 없음"
assert_eq "$(blk E3 job) · $(blk E3 progress) · $(blk P1 job)" "{'intent': '$TM/jobs/E3/INTENT.md', 'plan': None, 'result': None} · None · 칸 없음" \
  "Q14: 브랜치 없는 블록의 job · progress — 결정 블록에는 job 칸이 없다"
# 커밋 전의 새 팀도 읽힌다 — create --layout team 으로 tm2 를 만들고 커밋하지 않은 채 --roadmap-file 로
TM2="${RD}tm2"
(cd "$W" && python3 "$RW" original --brief docs/tv/brief.md --out "$TM2" \
  && python3 "$RW" create --layout team --brief docs/tv/brief.md --audit docs/tv/brief.audit.md --plan-table "$T/tm-table.md" \
       --out "$TM2" --title "커밋 전 팀" --date 2026-11-15 --approval "이대로 승인") > "$T/out.txt" 2>&1 || no "tm2 를 만들지 못했다 — $(cat "$T/out.txt")"
NEW_RC=0; (cd "$W" && python3 "$RS" --roadmap-file "$TM2/roadmap.md" --json) > "$T/tm2.json" 2>/dev/null || NEW_RC=$?
assert_eq "${NEW_RC} · $(js "$T/tm2.json" "[b['stage'] for b in r['blocks']]")" "0 · ['준비', '준비', '준비', '대기']" "AC9: 커밋 전의 새 팀도 읽힌다(--roadmap-file · rc 0)"
# 팀 자리(<roadmaps_dir><팀>/roadmap.md)가 아닌 곳의 team 로드맵은 형식 깨짐이다 — 한 층 더 깊은 사본
mkdir -p "$W/${RD}deep" && cp -R "$W/$TM2" "$W/${RD}deep/"
BAD_RC=0; (cd "$W" && python3 "$RS" --roadmap-file "${RD}deep/tm2/roadmap.md" --json) > "$T/bad.json" 2>/dev/null || BAD_RC=$?
assert_eq "${BAD_RC} · $(js "$T/bad.json" "r['format_errors']")" "3 · ['team 로드맵의 자리가 아니다 — <팀>/roadmap.md 꼴이 아니다: ${RD}deep/tm2/roadmap.md']" \
  "단계: 팀 자리가 아닌 team 로드맵은 형식 깨짐(3)"
rm -rf "$W/$TM2" "$W/${RD}deep"

g checkout -q -b feature/tm-e1 main && put src/e1/a.txt a && step "코드 하나"
assert_eq "$(st E1) · $(why E1)" "설계 중 · 브랜치 있음 · design.md 없음" "단계: 브랜치만 — 설계 중"
put "$J1/design.md" "$DESIGN" && step "설계문서"
assert_eq "$(st E1) · $(why E1)" "설계 중 · design.md 있음 · spec 승인 줄 없음" "단계: 설계문서가 있어도 승인 줄이 없으면 설계 중"
assert_eq "$(blk E1 specs)" "['$J1/design.md']" "단계: 설계 흐름의 설계문서는 과제 폴더의 design.md"
decide E1 "spec 승인 · 2026-11-20 · 「이대로 승인 (권장)」" && step "승인"
assert_eq "$(st E1) · $(why E1)" "계획 · spec 승인됨(2026-11-20) · plan-1.md 없음 · implement 결과 파일 없음" "단계: 승인 줄 — 계획"
assert_eq "$(rc)" "0" "단계: 계획 — 경고 · 검사 불가가 없다(뒤의 rc 3 단언의 바탕)"
put "$J1/plan-1.md" "$PLAN1" && step "계획 파일"
assert_eq "$(st E1)" "계획" "AC9: 계획 파일만 바꾼 커밋으로는 구현 중이 아니다"
assert_contains "$(why E1)" "plan-1.md 있음 · implement 결과 파일 없음" "단계: 계획 파일이 있으면 「있음」"
decide E1 "계획 검토 · 2026-11-21 · 설계에 없던 결정 없음" && step "결정 기록 한 줄"
assert_eq "$(st E1)" "계획" "AC9: 결정 기록만 바꾼 커밋으로는 구현 중이 아니다"
sync E1 implement-plan-1-1.md --role worker --bundle-at "$(g rev-parse origin/main)" --job-at "$(g rev-parse HEAD)" >/dev/null && step "결과 파일 시작"
assert_eq "$(st E1) · $(why E1)" "구현 중 · implement 결과 파일 있음: implement-plan-1-1.md" "단계: implement 결과 파일 — 구현 중"
assert_eq "$(prog E1)" "{'done': None, 'total': None, 'why': '진행 줄 없음'}" "AC27: Task 줄이 없으면 숫자 없이 「진행 줄 없음」"
assert_contains "$(notes E1)" "결과 있음 · 받음 없음: implement-plan-1-1.md(도는 중 — 끝 줄 없음)" "AC10: 결과 있음 · 받음 없음(도는 중)"
assert_eq "$(jobf E1 intent) · $(jobf E1 plan) · $(jobf E1 result)" "$J1/INTENT.md · 1 · implement-plan-1-1.md" "Q14: job 칸 — INTENT.md · 계획 번호 · 가장 새 결과 파일"
sync E1 implement-plan-1-1.md --ledger "$T/ledger.md" --plan-file "$W/$J1/plan-1.md" >/dev/null && step "Task 둘"
assert_eq "$(st E1) · $(prog E1)" "구현 중 · {'done': 2, 'total': 3}" "AC27: 단계 글자는 그대로이고 진행은 따로 된 칸"
printf 'Task 9/3: 끝 — x\n' >> "$W/$R1" && step "깨진 진행 줄"
assert_eq "$(st E1) · $(prog E1)" "구현 중 · {'done': None, 'total': None, 'why': '진행 줄 깨짐 — Task 9/3: 끝 — x'}" "AC27: 깨진 숫자는 숫자 없이 사유로"
assert_contains "$(notes E1)" "진행 줄을 믿지 않았다: implement-plan-1-1.md — Task 9/3: 끝 — x" "AC27: 깨진 진행 줄을 알린다"
drop "$R1" "Task 9/3" && step "깨진 진행 줄 지움"
assert_eq "$(prog E1)" "{'done': 2, 'total': 3}" "AC27: 그 줄을 지우면 숫자가 돌아온다"
assert_not_contains "$(notes E1)" "진행 줄을 믿지 않았다" "AC27: 줄을 지우면 알림도 없다"
put "$BLK" "$(printf -- '---\ntype: job-blocked\nstage: implement\nplan: 1\nattempt: 1\nhead: %s\n---\n\n## 무엇에 막혔나\n\n단계 표 픽스처가 막혔다.\n\n## 풀려면 무엇이 필요한가\n\n리더의 답 하나.' "$(g rev-parse HEAD)")" && step "막힘 파일"
assert_eq "$(st E1)" "구현 중" "AC29: 막힘 파일이 있어도 단계는 그대로"
assert_contains "$(notes E1)" "막힘: implement plan 1 시도 1 — $BLK" "AC29: 막힘 알림 — 단계 · 계획 · 시도 · 경로"
assert_eq "$(jobf E1 result)" "implement-plan-1-1.md" "AC29: 막힘 파일은 결과 파일로 세지 않는다"
drop "$BLK" "## 풀려면" && step "막힘 파일 깨짐"
assert_contains "$(notes E1)" "막힘 파일을 읽지 못했다: $BLK — " "AC29: 깨진 막힘 파일은 읽지 못했다고 알린다"
g rm -q -- "$BLK" && step "막힘 파일 지움"
assert_not_contains "$(notes E1)" "막힘" "AC29: 막힘 파일을 지우면 막힘 알림이 사라진다"
put src/e1/a.txt "첫 읽기의 끝난 코드" && g commit -qm "E1 코드" && CODE="$(g rev-parse HEAD)"
printf 'AC1: 구현됨 — src/e1/a.txt\nAC2: 구현됨 — src/e1/a.txt\n' >> "$W/$R1"
sync E1 implement-plan-1-1.md --end "$CODE" >/dev/null && step "결과 끝"
assert_contains "$(notes E1)" "결과 있음 · 받음 없음: implement-plan-1-1.md(대조를 기다린다)" "AC10: 끝 줄이 있으면 「대조를 기다린다」(Q11)"
assert_eq "$(st E1)" "구현 중" "단계: 끝 줄만으로는 구현 끝이 아니다"
LINE="$(cd "$W" && python3 "$JRC" check --roadmap "$RM" --job E1 --result implement-plan-1-1.md --date 2026-11-22 | grep '^- 결과 받음 · ')"
assert_contains "$LINE" "- 결과 받음 · 2026-11-22 · 「implement-plan-1-1.md · $CODE · 결과 대조: 통과 — " "받음: 대조가 받음 줄을 낸다"
decide E1 "$LINE" && step "받음 줄"
assert_eq "$(st E1) · $(why E1) · $(prog E1)" "구현 끝 · 결과 받음 줄 있음: implement-plan-1-1.md · None" "단계: 대조를 통과한 받음 줄 — 구현 끝"
assert_not_contains "$(notes E1)" "받음 없음" "받음: 받은 뒤에는 받음 없음 알림이 없다"
RECEIVED_AT="$(g rev-parse HEAD)"

# 받음 — 갈래마다 feature/tm-e1 에 커밋을 하나 더해 단언한 뒤 RECEIVED_AT 으로 되돌린다
put src/e1/b.txt b && step "받은 뒤 고칠 자리"
assert_eq "$(st E1)" "구현 중" "받음: 받은 뒤 고칠 자리가 바뀌면 구현 중"
assert_contains "$(notes E1)" "받은 뒤 바뀜: implement-plan-1-1.md — src/e1/b.txt" "받음: 받은 뒤 바뀜 — 고칠 자리"
assert_not_contains "$(notes E1)" "받음 없음" "받음: 낡은 받음 줄은 받음 없음이 아니다"
back "$RECEIVED_AT"
sub "$J1/design.md" "과제 폴더를 읽는다." "과제 폴더를 다시 읽는다." && step "받은 뒤 설계문서"
assert_eq "$(st E1)" "구현 중" "받음: 받은 뒤 design.md 가 바뀌면 구현 중"
assert_contains "$(notes E1)" "받은 뒤 바뀜: implement-plan-1-1.md — $J1/design.md" "받음: 받은 뒤 바뀜 — design.md"
back "$RECEIVED_AT"
sub "$J1/plan-1.md" "알림을 단다." "알림을 다시 단다." && step "받은 뒤 계획 파일"
assert_eq "$(st E1)" "구현 중" "받음: 받은 뒤 계획 파일이 바뀌면 구현 중"
assert_contains "$(notes E1)" "받은 뒤 바뀜: implement-plan-1-1.md — $J1/plan-1.md" "받음: 받은 뒤 바뀜 — 계획 파일"
back "$RECEIVED_AT"
decide E1 "결정 · 2026-11-23 · 받은 뒤 적은 결정" && step "받은 뒤 결정 줄"
assert_eq "$(st E1)" "구현 끝" "받음: INTENT.md 에 결정 줄만 더하면 구현 끝 그대로"
back "$RECEIVED_AT"
put "$J1/results/review-1.md" "검토 메모" && step "받은 뒤 검토 결과"
assert_eq "$(st E1)" "구현 끝" "받음: 결과 폴더에 review-1.md 만 더하면 구현 끝 그대로"
assert_not_contains "$(notes E1)" "받음 없음" "받음: implement 가 아닌 결과 파일에는 받음 없음 알림이 없다"
back "$RECEIVED_AT"
MAIN0="$(g rev-parse origin/main)"
g checkout -q main && put src/e1/z.txt z && g commit -qm "기본 브랜치의 다른 변경" && g push -q origin main
g checkout -q feature/tm-e1 && g merge -q --no-edit main && g push -q origin HEAD && LAST_RC="$(status "$T/s.json")"
assert_eq "$(st E1)" "구현 끝" "받음: 기본 브랜치를 merge 한 커밋만 있으면 구현 끝 그대로(Review Focus 4)"
assert_not_contains "$(notes E1)" "받은 뒤 바뀜" "받음: 합쳐 들어온 고칠 자리 변경(src/e1/z.txt)은 세지 않는다"
back "$RECEIVED_AT"
g checkout -q main && back "$MAIN0" && g checkout -q feature/tm-e1
sync E1 implement-plan-1-2.md --role worker --bundle-at "$MAIN0" --job-at "$RECEIVED_AT" >/dev/null && step "받은 뒤 새 시도"
assert_eq "$(st E1) · $(jobf E1 result)" "구현 중 · implement-plan-1-2.md" "받음: 더 새 시도가 있으면 구현 중 · job.result 는 새 시도"
assert_contains "$(notes E1)" "받은 뒤 바뀜: implement-plan-1-1.md — 더 새 시도 implement-plan-1-2.md 가 있다" "받음: 받은 뒤 바뀜 — 더 새 시도"
back "$RECEIVED_AT"
sub "$J1/INTENT.md" " · $CODE · " " · $MAIN0 · " && step "받음 줄의 커밋이 다르다"
assert_eq "$(st E1)" "구현 중" "받음: 받음 줄의 커밋이 head 가 아니면 구현 중"
assert_contains "$(notes E1)" "받음 줄을 세지 않았다: implement-plan-1-1.md — 받음 줄의 커밋" "받음: 받음 커밋 ≠ head 를 알린다"
back "$RECEIVED_AT"
sub "$J1/INTENT.md" "$LINE" "- 결과 받음 · 2026-11-22 · 받았다" && step "꼴이 깨진 받음 줄"
assert_eq "$(st E1)" "구현 중" "받음: 꼴이 깨진 받음 줄만 있으면 구현 중"
assert_contains "$(notes E1)" "받음 줄을 세지 않았다: 꼴이 깨졌다 — - 결과 받음 · 2026-11-22 · 받았다" "받음: 꼴이 깨졌다"
assert_contains "$(notes E1)" "결과 있음 · 받음 없음: implement-plan-1-1.md(대조를 기다린다)" "받음: 깨진 줄은 받음이 아니다 — 받음 없음"
back "$RECEIVED_AT"
drop "$R1" "AC2:" && step "받은 뒤 결과 파일이 대조를 못 넘는다"
assert_eq "$(st E1)" "구현 중" "받음: 받음 줄이 가리키는 결과 파일이 대조를 못 넘으면 구현 중"
assert_contains "$(notes E1)" "받음 줄을 세지 않았다: implement-plan-1-1.md — 보고에 없는 AC — AC2" "받음: 대조 불통을 알린다"
back "$RECEIVED_AT"

# 못 읽는 것 — INTENT.md 가 없는 끝 · 결정 기록의 승인 줄 꼴이 깨진 끝
g rm -q -- "$J1/INTENT.md" && step "INTENT.md 지움"
assert_eq "$(st E1) · $(why E1) · $(rc)" "알 수 없음 · $J1/INTENT.md 를 읽지 못했다 · 3" "단계: INTENT.md 를 그 끝에서 읽지 못하면 알 수 없음(3)"
back "$RECEIVED_AT"
printf -- '- spec 승인 · 11/20 · 「글」\n' >> "$W/$J1/INTENT.md" && step "승인 줄 꼴 깨짐"
assert_eq "$(st E1)" "설계 중" "단계: 결정 기록의 승인 줄 꼴이 깨지면 설계 중"
assert_contains "$(why E1)" "결정 기록 읽기 불가 — " "단계: 결정 기록 읽기 불가를 근거로 낸다"
back "$RECEIVED_AT"
# 읽는 함수들과 git 이 실패한 자리 — 가짜 Git 으로 결과 폴더 · 결과 파일 · 막힘 파일 읽기를 막는다
python3 - "$S" "$W" "$RD" "$RM" "$RECEIVED_AT" > "$T/reader.txt" 2>&1 <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import roadmap_status, team_layout, team_status
from roadmap_model import parse_roadmap
root, rd, rm, tip = sys.argv[2:6]
team = team_layout.team_from_roadmap(rd, rm)
git0 = roadmap_status.Git(root)
main = git0.commit("refs/remotes/origin/HEAD")
blocks = {b["id"]: b for b in parse_roadmap(git0.blob(main, rm))[1]}


class Blind(roadmap_status.Git):
    def __init__(self, cwd, shut):
        super().__init__(cwd)
        self.shut = shut

    def names(self, rev, folder):
        return None if folder in self.shut else super().names(rev, folder)

    def blob(self, rev, path):
        return None if path in self.shut else super().blob(rev, path)

    def exists(self, rev, path):
        return True if path in self.shut else super().exists(rev, path)


def run(shut, tree=tip):
    reader = team_status.Reader(Blind(root, shut), main, team, lambda p: None)
    b = dict(blocks["E1"], notes=[])
    stage, why, _specs, _plans = reader.progress(tree, b, 1)
    return stage, why, b["progress"], b["notes"]


reader0 = team_status.Reader(git0, main, team, lambda p: "default:" + p)
print("flow", reader0.flow(blocks["E1"]), reader0.flow(blocks["E2"]))
print("approved", reader0.approved(main, blocks["E1"]), reader0.approved(tip, blocks["E1"]))
print("planned", reader0.planned(main, blocks["E1"]), reader0.planned(tip, blocks["E1"]))
print("specs", reader0.specs(main, blocks["E1"]), reader0.specs(tip, blocks["E1"]))
print("read", reader0.read(None, "x/y.md"))
print("results", run([team.results("E1")])[:2])
print("result", run([team.result("E1", team_layout.STAGES[2], 1, 1)]))
print("blocked", run([team.blocked("E1")])[3])
PY
assert_contains "$(cat "$T/reader.txt")" "flow 설계 흐름 설계 없는 흐름" "단계: 흐름 — 산출물 칸이 있으면 설계 없는 흐름(Q5)"
assert_contains "$(cat "$T/reader.txt")" "approved (None, None) ('2026-11-20', None)" "단계: approved 는 그 트리의 결정 기록에서 읽는다"
assert_contains "$(cat "$T/reader.txt")" "planned False True" "단계: planned 는 그 트리의 과제 폴더에 계획 파일이 있는가"
assert_contains "$(cat "$T/reader.txt")" "specs [] ['$J1/design.md']" "단계: specs 는 그 트리의 design.md"
assert_contains "$(cat "$T/reader.txt")" "read default:x/y.md" "단계: 트리가 None 이면 로드맵을 읽은 사본에서 읽는다"
assert_contains "$(cat "$T/reader.txt")" "results ('알 수 없음', '$J1/results 를 읽지 못했다')" "단계: 결과 폴더를 읽지 못하면 「결과 파일 없음」 이 아니라 알 수 없음"
assert_contains "$(cat "$T/reader.txt")" "result ('구현 중', 'implement 결과 파일 있음: implement-plan-1-1.md', {'done': None, 'total': None, 'why': '$R1 를 읽지 못했다'}" \
  "단계: 결과 파일 글을 읽지 못하면 진행은 숫자 없이 사유로"
assert_contains "$(cat "$T/reader.txt")" "blocked ['막힘 파일을 읽지 못했다: $BLK — 글을 읽지 못했다']" "AC29: 있는데 읽지 못한 막힘 파일"
assert_not_contains "$(cat "$T/reader.txt")" "Traceback" "단계: 읽는 함수들이 죽지 않는다"

# 끝 — 올리지 않은 커밋은 알리고 로컬 끝으로 계산한다 · 둘째 clone 이 다른 커밋을 올려 갈라지면 알 수 없음
put src/e1/b.txt b2 && g commit -qm "올리지 않은 커밋" && LAST_RC="$(status "$T/s.json")"
assert_contains "$(notes E1)" "아직 안 올라옴 — feature/tm-e1 의 로컬 끝" "끝: 올리지 않은 커밋을 알린다"
assert_eq "$(st E1)" "구현 중" "끝: 단계는 로컬 끝으로 계산한다(origin 끝이면 구현 끝)"
other fetch -q origin && other checkout -q -B feature/tm-e1 origin/feature/tm-e1
mkdir -p "$U/src/e1" && printf 'c\n' > "$U/src/e1/c.txt" && other add -- src/e1/c.txt && other commit -qm "다른 clone 의 커밋" && other push -q origin feature/tm-e1
g fetch -q origin && LAST_RC="$(status "$T/s.json")"
assert_eq "$(st E1) · $(rc) · $(st E2)" "알 수 없음 · 3 · 준비" "끝: 갈라지면 그 블록만 알 수 없음(3) — 다른 블록은 그대로(Q10)"
assert_eq "$(js "$T/s.json" "[b for b in r['blocks'] if b['id']=='E1'][0]['reason'].startswith('갈라짐 — ')")" "True" "끝: 사유는 「갈라짐 — 」 으로 시작한다"
back "$RECEIVED_AT" && LAST_RC="$(status "$T/s.json")"
assert_eq "$(st E1) · $(rc)" "구현 끝 · 0" "끝: 되돌리면 구현 끝 · 종료 코드 0"

# 설계 없는 흐름(E2 — 산출물 칸): 준비 → 진행 중 → 결과 받음
g checkout -q -b feature/tm-e2 main && put src/e2/note.txt n && step "E2 시작"
assert_eq "$(st E2) · $(why E2) · $(blk E2 task_status) · $(prog E2)" "진행 중 · 브랜치 있음 · in_progress · None" "단계: 설계 없는 흐름 — 브랜치가 있으면 진행 중"
put "$TM/jobs/E2/survey.md" "$(printf '# 조사 표\n\n| 파일 | 줄 수 |\n|---|---|\n| a.txt | 1 |')" && g commit -qm "조사 표" && CODE2="$(g rev-parse HEAD)"
sync E2 implement-1.md --role worker --bundle-at "$(g rev-parse origin/main)" --job-at "$CODE2" >/dev/null
printf '산출물: %s\n' "$TM/jobs/E2/survey.md" >> "$W/$TM/jobs/E2/results/implement-1.md"
sync E2 implement-1.md --end "$CODE2" >/dev/null && step "E2 결과"
assert_eq "$(st E2) · $(jobf E2 plan) · $(jobf E2 result)" "진행 중 · None · implement-1.md" "단계: 설계 없는 흐름의 결과 파일은 계획 번호가 없다"
assert_contains "$(notes E2)" "결과 있음 · 받음 없음: implement-1.md(대조를 기다린다)" "AC10: 설계 없는 흐름에도 받음 없음 알림"
LINE2="$(cd "$W" && python3 "$JRC" check --roadmap "$RM" --job E2 --result implement-1.md --date 2026-11-24 | grep '^- 결과 받음 · ')"
decide E2 "$LINE2" && step "E2 받음 줄"
assert_eq "$(st E2) · $(why E2) · $(blk E2 task_status)" "결과 받음 · 결과 받음 줄 있음: implement-1.md · in_progress" "단계: 설계 없는 흐름 — 받음 줄이면 결과 받음(Q12)"
E2_AT="$(g rev-parse HEAD)"
sub "$TM/jobs/E2/INTENT.md" "## 결정 기록" "## 결정 기록 아님" && step "E2 결정 기록 칸 깨짐"
assert_eq "$(st E2)" "진행 중" "단계: 설계 없는 흐름 — 결정 기록을 읽지 못하면 진행 중"
assert_contains "$(why E2)" "결정 기록 읽기 불가 — " "단계: 설계 없는 흐름 — 결정 기록 읽기 불가를 근거로 낸다"
back "$E2_AT"

# 둘째 브랜치(계획 2): feature/tm-e1 을 기본 브랜치에 merge 커밋으로 합친다
g checkout -q main
MAIN_AT="$(g rev-parse origin/main)"
g merge -q --no-ff --no-edit feature/tm-e1 && g push -q origin main && LAST_RC="$(status "$T/s.json")"
assert_eq "$(st E1)" "일부 머지 1/2" "단계: 브랜치 둘 가운데 하나가 머지되면 일부 머지 1/2"
g checkout -q -b feature/tm-e1b main && put src/e1/d.txt d && step "계획 2 시작"
assert_contains "$(why E1)" "feature/tm-e1b — 계획 · spec 승인됨(2026-11-20) · plan-2.md 없음" "단계: 둘째 브랜치는 계획 2 로 센다"
sync E1 implement-plan-2-1.md --role worker --bundle-at "$(g rev-parse origin/main)" --job-at "$(g rev-parse HEAD)" >/dev/null && step "계획 2 결과 시작"
assert_contains "$(why E1)" "feature/tm-e1b — 구현 중" "단계: 계획 2 의 implement 결과 파일 — 구현 중"
assert_eq "$(jobf E1 plan) · $(jobf E1 result)" "2 · implement-plan-2-1.md" "Q14: job.plan == 2 · job.result 는 계획 2 의 결과 파일"

# Review Focus 5 — 기본 브랜치를 모르는 레포: 블록이 모두 알 수 없음(3)이고 죽지 않는다
g remote set-head origin -d
NO_RC=0; (cd "$W" && python3 "$RS" --roadmap-file "$RM" --json) > "$T/nohead.json" 2> "$T/nohead.err" || NO_RC=$?
assert_eq "${NO_RC} · $(js "$T/nohead.json" "sorted(set(b['stage'] for b in r['blocks']))")" "3 · ['알 수 없음']" "Review Focus 5: origin/HEAD 가 없으면 블록이 모두 알 수 없음(3)"
assert_not_contains "$(cat "$T/nohead.err")" "Traceback" "Review Focus 5: 표준 오류에 Traceback 이 없다"
assert_not_contains "$(js "$T/nohead.json" "r['unknown_reasons']")" "내부 오류" "Review Focus 5: 계산이 죽지 않았다(내부 오류 없음)"
g remote set-head origin main
g checkout -q main
finish
