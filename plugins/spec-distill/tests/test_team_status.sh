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
assert_eq "$(tipof origin/t/same)" "$(short origin/t/same)|no|no" "끝: origin/<브랜치> 로 주면 그 원격 끝 · 로컬 끝이 아니니 알림 없음"
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
# 걸음이 실패하면 보고를 지운다 — 앞 걸음의 낡은 보고가 「같은 단계 그대로」 단언을 채우지 못하게(그 단언들은 빨개진다)
fail_step() { rm -f "$T/s.json"; LAST_RC="걸음 실패"; no "걸음 실패: $1"; }
restat() { rm -f "$T/s.json"; LAST_RC="$(status "$T/s.json")"; }
step() { g add -A && g commit -qm "$1" && g push -q origin HEAD && restat || fail_step "$1"; }
back() { g reset -q --hard "$1" && g push -q -f origin HEAD || fail_step "되돌리기 $1"; }   # back <커밋> — 지금 브랜치를 그 커밋으로 되돌려 올린다(임시 레포)
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

g checkout -q -b feature/tm-e1 main && put src/e1/a.txt a && step "코드 하나" || fail_step "코드 하나"
assert_eq "$(st E1) · $(why E1)" "설계 중 · 브랜치 있음 · design.md 없음" "단계: 브랜치만 — 설계 중"
put "$J1/design.md" "$DESIGN" && step "설계문서" || fail_step "설계문서"
assert_eq "$(st E1) · $(why E1)" "설계 중 · design.md 있음 · spec 승인 줄 없음" "단계: 설계문서가 있어도 승인 줄이 없으면 설계 중"
assert_eq "$(blk E1 specs)" "['$J1/design.md']" "단계: 설계 흐름의 설계문서는 과제 폴더의 design.md"
claim || no "지휘 표지를 쥐지 못했다 — $(cat "$T/led.txt")"
decide E1 "spec 승인 · 2026-11-20 · 「이대로 승인 (권장)」" && step "손으로 적은 승인 줄" || fail_step "손으로 적은 승인 줄"
assert_eq "$(st E1)" "설계 중" "AC8: 손으로 적은 승인 줄로는 계획이 되지 않는다"
assert_contains "$(why E1)" "design.md 있음 · spec 승인 줄이 지나지 못했다 — 근거 없음" "AC8: 사유에 판정"
drop "$TM/jobs/E1/INTENT.md" "spec 승인 · 2026-11-20"
[ "$(human "spec 승인" E1 - - 2026-11-20)" = "0" ] && step "승인" || fail_step "승인"
assert_eq "$(st E1) · $(why E1)" "계획 · spec 승인됨(2026-11-20) · plan-1.md 없음 · implement 결과 파일 없음" "단계: 승인 줄 — 계획"
mv "$CLAUDE_CONFIG_DIR" "$T/claude.away" && restat
assert_eq "$(st E1)" "계획" "AC8: 단계 계산은 세션 기록을 읽지 않는다"
mv "$T/claude.away" "$CLAUDE_CONFIG_DIR"
assert_eq "$(rc)" "0" "단계: 계획 — 경고 · 검사 불가가 없다(뒤의 rc 3 단언의 바탕)"
put "$J1/plan-1.md" "$PLAN1" && step "계획 파일" || fail_step "계획 파일"
assert_eq "$(st E1)" "계획" "AC9: 계획 파일만 바꾼 커밋으로는 구현 중이 아니다"
assert_contains "$(why E1)" "plan-1.md 있음 · implement 결과 파일 없음" "단계: 계획 파일이 있으면 「있음」"
decide E1 "계획 검토 · 2026-11-21 · 설계에 없던 결정 없음" && step "결정 기록 한 줄" || fail_step "결정 기록 한 줄"
assert_eq "$(st E1)" "계획" "AC9: 결정 기록만 바꾼 커밋으로는 구현 중이 아니다"
sync E1 implement-plan-1-1.md --role worker --bundle-at "$(g rev-parse origin/main)" --job-at "$(g rev-parse HEAD)" >/dev/null && step "결과 파일 시작" || fail_step "결과 파일 시작"
assert_eq "$(st E1) · $(why E1)" "구현 중 · implement 결과 파일 있음: implement-plan-1-1.md" "단계: implement 결과 파일 — 구현 중"
assert_eq "$(prog E1)" "{'done': None, 'total': None, 'why': '진행 줄 없음'}" "AC27: Task 줄이 없으면 숫자 없이 「진행 줄 없음」"
assert_contains "$(notes E1)" "결과 있음 · 받음 없음: implement-plan-1-1.md(도는 중 — 끝 줄 없음)" "AC10: 결과 있음 · 받음 없음(도는 중)"
assert_eq "$(jobf E1 intent) · $(jobf E1 plan) · $(jobf E1 result)" "$J1/INTENT.md · 1 · implement-plan-1-1.md" "Q14: job 칸 — INTENT.md · 계획 번호 · 가장 새 결과 파일"
sync E1 implement-plan-1-1.md --ledger "$T/ledger.md" --plan-file "$W/$J1/plan-1.md" >/dev/null && step "Task 둘" || fail_step "Task 둘"
assert_eq "$(st E1) · $(prog E1)" "구현 중 · {'done': 2, 'total': 3}" "AC27: 단계 글자는 그대로이고 진행은 따로 된 칸"
printf 'Task 9/3: 끝 — x\n' >> "$W/$R1" && step "깨진 진행 줄" || fail_step "깨진 진행 줄"
assert_eq "$(st E1) · $(prog E1)" "구현 중 · {'done': None, 'total': None, 'why': '진행 줄 깨짐 — Task 9/3: 끝 — x'}" "AC27: 깨진 숫자는 숫자 없이 사유로"
assert_contains "$(notes E1)" "진행 줄을 믿지 않았다: implement-plan-1-1.md — Task 9/3: 끝 — x" "AC27: 깨진 진행 줄을 알린다"
drop "$R1" "Task 9/3" && step "깨진 진행 줄 지움" || fail_step "깨진 진행 줄 지움"
assert_eq "$(prog E1)" "{'done': 2, 'total': 3}" "AC27: 그 줄을 지우면 숫자가 돌아온다"
assert_not_contains "$(notes E1)" "진행 줄을 믿지 않았다" "AC27: 줄을 지우면 알림도 없다"
# 다 읽지 못한 결과 파일 — 기계 줄을 빠뜨렸으면 진행 숫자를 내지 않고 사유와 알림으로 낸다(AC27)
PROG_AT="$(g rev-parse HEAD)"
pdone() { js "$T/s.json" "[b for b in r['blocks'] if b['id']=='E1'][0]['progress']['done']"; }
pwhy() { js "$T/s.json" "[b for b in r['blocks'] if b['id']=='E1'][0]['progress'].get('why')"; }
printf 'Task 03/3: 끝 — z\n' >> "$W/$R1" && step "앞이 0 인 진행 줄" || fail_step "앞이 0 인 진행 줄"
assert_eq "$(st E1) · $(pdone)" "구현 중 · None" "단계: 다 읽지 못한 결과 파일 — 앞이 0 인 Task 줄이 있으면 숫자를 내지 않는다(2/3 이 아니다)"
assert_contains "$(pwhy)" "결과 파일을 다 읽지 못했다 — Task 줄 꼴이 아니다" "단계: 다 읽지 못한 결과 파일 — 진행 칸의 사유(앞이 0)"
assert_contains "$(notes E1)" "결과 파일을 다 읽지 못했다: implement-plan-1-1.md — Task 줄 꼴이 아니다(Task <n>/<전체>: 끝|막힘 — <커밋>): Task 03/3: 끝 — z" \
  "단계: 다 읽지 못한 결과 파일 — 첫 사유를 알린다(앞이 0)"
back "$PROG_AT"
OPEN_FENCE=$'```text\nTask 2/3:'
sub "$R1" "Task 2/3:" "$OPEN_FENCE" && step "닫히지 않은 펜스" || fail_step "닫히지 않은 펜스"
assert_eq "$(st E1) · $(pdone)" "구현 중 · None" "단계: 다 읽지 못한 결과 파일 — 닫히지 않은 펜스면 숫자를 내지 않는다(1/3 이 아니다)"
assert_contains "$(notes E1)" "결과 파일을 다 읽지 못했다: implement-plan-1-1.md — 본문의 코드 펜스가 닫히지 않았다" "단계: 다 읽지 못한 결과 파일 — 첫 사유를 알린다(펜스)"
back "$PROG_AT"
put "$BLK" "$(printf -- '---\ntype: job-blocked\nstage: implement\nplan: 1\nattempt: 1\nhead: %s\n---\n\n## 무엇에 막혔나\n\n단계 표 픽스처가 막혔다.\n\n## 풀려면 무엇이 필요한가\n\n리더의 답 하나.' "$(g rev-parse HEAD)")" && step "막힘 파일" || fail_step "막힘 파일"
assert_eq "$(st E1)" "구현 중" "AC29: 막힘 파일이 있어도 단계는 그대로"
assert_contains "$(notes E1)" "막힘: implement plan 1 시도 1 — $BLK" "AC29: 막힘 알림 — 단계 · 계획 · 시도 · 경로"
assert_eq "$(jobf E1 result)" "implement-plan-1-1.md" "AC29: 막힘 파일은 결과 파일로 세지 않는다"
drop "$BLK" "## 풀려면" && step "막힘 파일 깨짐" || fail_step "막힘 파일 깨짐"
assert_contains "$(notes E1)" "막힘 파일을 읽지 못했다: $BLK — " "AC29: 깨진 막힘 파일은 읽지 못했다고 알린다"
g rm -q -- "$BLK" && step "막힘 파일 지움" || fail_step "막힘 파일 지움"
assert_not_contains "$(notes E1)" "막힘" "AC29: 막힘 파일을 지우면 막힘 알림이 사라진다"
put src/e1/a.txt "첫 읽기의 끝난 코드" && g commit -qm "E1 코드" && CODE="$(g rev-parse HEAD)"
printf 'AC1: 구현됨 — src/e1/a.txt\nAC2: 구현됨 — src/e1/a.txt\n' >> "$W/$R1"
sync E1 implement-plan-1-1.md --end "$CODE" >/dev/null && step "결과 끝" || fail_step "결과 끝"
assert_contains "$(notes E1)" "결과 있음 · 받음 없음: implement-plan-1-1.md(대조를 기다린다)" "AC10: 끝 줄이 있으면 「대조를 기다린다」(Q11)"
assert_eq "$(st E1)" "구현 중" "단계: 끝 줄만으로는 구현 끝이 아니다"
END_AT="$(g rev-parse HEAD)"
python3 -c 'import sys; p = sys.argv[1]; t = open(p, encoding="utf-8", newline="").read(); open(p, "w", encoding="utf-8", newline="").write("﻿" + t)' "$W/$R1" \
  && step "BOM 붙은 결과 파일" || fail_step "BOM 붙은 결과 파일"
assert_eq "$(st E1) · $(pdone)" "구현 중 · None" "단계: 다 읽지 못한 결과 파일 — BOM 이 붙으면 숫자를 내지 않는다"
assert_contains "$(notes E1)" 'implement-plan-1-1.md — 머리(첫 줄 `---`)가 없다' "단계: 다 읽지 못한 결과 파일 — 첫 사유를 알린다(BOM)"
assert_contains "$(pwhy)" '머리(첫 줄 `---`)가 없다' "단계: 다 읽지 못한 결과 파일 — 진행 칸의 사유(BOM)"
assert_contains "$(notes E1)" "결과 있음 · 받음 없음: implement-plan-1-1.md(읽지 못함 — 끝 줄이 있는지 모른다)" "단계: 다 읽지 못한 결과 파일 — 받음 없음 알림이 「읽지 못함」"
assert_not_contains "$(notes E1)" "도는 중 — 끝 줄 없음" "단계: 다 읽지 못한 결과 파일 — 끝 줄이 있는 파일을 「도는 중」 이라 하지 않는다"
back "$END_AT"
approved "계획 검토" E1 1 - 2026-11-21 && g push -q origin HEAD && restat || fail_step "질문 창으로 받은 계획 검토 줄"
LINE="$(cd "$W" && python3 "$JRC" check --roadmap "$RM" --job E1 --result implement-plan-1-1.md --date 2026-11-22 | grep '^- 결과 받음 · ')"
assert_contains "$LINE" "- 결과 받음 · 2026-11-22 · 「implement-plan-1-1.md · $CODE · 결과 대조: 통과 — " "받음: 대조가 받음 줄을 낸다"
decide E1 "$LINE" && step "받음 줄" || fail_step "받음 줄"
assert_eq "$(st E1) · $(why E1) · $(prog E1)" "구현 끝 · 결과 받음 줄 있음: implement-plan-1-1.md · None" "단계: 대조를 통과한 받음 줄 — 구현 끝"
assert_not_contains "$(notes E1)" "받음 없음" "받음: 받은 뒤에는 받음 없음 알림이 없다"
RECEIVED_AT="$(g rev-parse HEAD)"

# 받음 — 갈래마다 feature/tm-e1 에 커밋을 하나 더해 단언한 뒤 RECEIVED_AT 으로 되돌린다
put src/e1/b.txt b && step "받은 뒤 고칠 자리" || fail_step "받은 뒤 고칠 자리"
assert_eq "$(st E1)" "구현 중" "받음: 받은 뒤 고칠 자리가 바뀌면 구현 중"
assert_contains "$(notes E1)" "받은 뒤 바뀜: implement-plan-1-1.md — src/e1/b.txt" "받음: 받은 뒤 바뀜 — 고칠 자리"
assert_not_contains "$(notes E1)" "받음 없음" "받음: 낡은 받음 줄은 받음 없음이 아니다"
LIT_RC="$(GIT_LITERAL_PATHSPECS=1 status "$T/s.json")"
assert_eq "$(st E1) · ${LIT_RC}" "구현 중 · 0" "받음: 환경에 GIT_LITERAL_PATHSPECS=1 이 있어도 받은 뒤 고칠 자리가 바뀌면 구현 중"
assert_contains "$(notes E1)" "받은 뒤 바뀜: implement-plan-1-1.md — src/e1/b.txt" "받음: 환경에 GIT_LITERAL_PATHSPECS=1 이 있어도 받은 뒤 바뀜 — 고칠 자리"
back "$RECEIVED_AT"
sub "$J1/design.md" "| 항목 | 이유 | 받는 곳 |
|---|---|---|" "| 항목 | 이유 | 받는 곳 |
|---|---|---|
| 알림 글 | 나중에 정한다 | plan-1.md |" && step "받은 뒤 설계문서" || fail_step "받은 뒤 설계문서"
assert_eq "$(st E1)" "구현 끝" "받음: 받은 뒤 design.md 의 미룸 절만 바뀌면 구현 끝 그대로(K13 — 본문으로 견준다)"
assert_not_contains "$(notes E1)" "받은 뒤 바뀜" "받음: 미룸 절만 바뀐 design.md 는 받은 뒤 바뀜이 아니다(본문 견줌 — 아래 r2 와 같은 규칙)"
back "$RECEIVED_AT"
sub "$J1/design.md" "과제 폴더를 읽는다." "과제 폴더를 다시 읽는다." && step "받은 뒤 설계문서 본문" || fail_step "받은 뒤 설계문서 본문"
assert_eq "$(st E1)" "설계 중" "AC8: 받은 뒤 design.md 본문을 고치면 승인이 낡아 구현 단계에서도 설계 중"
assert_contains "$(why E1)" "낡음" "AC8: 받은 뒤 본문을 고친 사유에 낡음"
back "$RECEIVED_AT"
sub "$J1/plan-1.md" "알림을 단다." "알림을 다시 단다." && step "받은 뒤 계획 파일" || fail_step "받은 뒤 계획 파일"
assert_eq "$(st E1)" "구현 중" "받음: 받은 뒤 계획 파일이 바뀌면 구현 중"
assert_contains "$(notes E1)" "받은 뒤 바뀜: implement-plan-1-1.md — $J1/plan-1.md" "받음: 받은 뒤 바뀜 — 계획 파일"
back "$RECEIVED_AT"
decide E1 "결정 · 2026-11-23 · 받은 뒤 적은 결정" && step "받은 뒤 결정 줄" || fail_step "받은 뒤 결정 줄"
assert_eq "$(st E1)" "구현 끝" "받음: INTENT.md 에 결정 줄만 더하면 구현 끝 그대로"
back "$RECEIVED_AT"
put "$J1/results/review-1.md" "검토 메모" && step "받은 뒤 검토 결과" || fail_step "받은 뒤 검토 결과"
assert_eq "$(st E1)" "구현 끝" "받음: 결과 폴더에 review-1.md 만 더하면 구현 끝 그대로"
assert_not_contains "$(notes E1)" "받음 없음" "받음: implement 가 아닌 결과 파일에는 받음 없음 알림이 없다"
back "$RECEIVED_AT"
MAIN0="$(g rev-parse origin/main)"
g checkout -q main && put src/e1/z.txt z && g commit -qm "기본 브랜치의 다른 변경" && g push -q origin main
g checkout -q feature/tm-e1 && g merge -q --no-edit main && g push -q origin HEAD && restat || fail_step "기본 브랜치 merge"
assert_eq "$(st E1)" "구현 끝" "받음: 기본 브랜치를 merge 한 커밋만 있으면 구현 끝 그대로(Review Focus 4)"
assert_not_contains "$(notes E1)" "받은 뒤 바뀜" "받음: 합쳐 들어온 고칠 자리 변경(src/e1/z.txt)은 세지 않는다"
back "$RECEIVED_AT"
g checkout -q main && back "$MAIN0" && g checkout -q feature/tm-e1
sync E1 implement-plan-1-2.md --role worker --bundle-at "$MAIN0" --job-at "$RECEIVED_AT" >/dev/null && step "받은 뒤 새 시도" || fail_step "받은 뒤 새 시도"
assert_eq "$(st E1) · $(jobf E1 result)" "구현 중 · implement-plan-1-2.md" "받음: 더 새 시도가 있으면 구현 중 · job.result 는 새 시도"
assert_contains "$(notes E1)" "받은 뒤 바뀜: implement-plan-1-1.md — 더 새 시도 implement-plan-1-2.md 가 있다" "받음: 받은 뒤 바뀜 — 더 새 시도"
back "$RECEIVED_AT"
sub "$J1/INTENT.md" " · $CODE · " " · $MAIN0 · " && step "받음 줄의 커밋이 다르다" || fail_step "받음 줄의 커밋이 다르다"
assert_eq "$(st E1)" "구현 중" "받음: 받음 줄의 커밋이 head 가 아니면 구현 중"
assert_contains "$(notes E1)" "받음 줄을 세지 않았다: implement-plan-1-1.md — 받음 줄의 커밋" "받음: 받음 커밋 ≠ head 를 알린다"
back "$RECEIVED_AT"
sub "$J1/INTENT.md" "$LINE" "- 결과 받음 · 2026-11-22 · 받았다" && step "꼴이 깨진 받음 줄" || fail_step "꼴이 깨진 받음 줄"
assert_eq "$(st E1)" "구현 중" "받음: 꼴이 깨진 받음 줄만 있으면 구현 중"
assert_contains "$(notes E1)" "받음 줄을 세지 않았다: 꼴이 깨졌다 — - 결과 받음 · 2026-11-22 · 받았다" "받음: 꼴이 깨졌다"
assert_contains "$(notes E1)" "결과 있음 · 받음 없음: implement-plan-1-1.md(대조를 기다린다)" "받음: 깨진 줄은 받음이 아니다 — 받음 없음"
back "$RECEIVED_AT"
drop "$R1" "AC2:" && step "받은 뒤 결과 파일이 대조를 못 넘는다" || fail_step "받은 뒤 결과 파일이 대조를 못 넘는다"
assert_eq "$(st E1)" "구현 중" "받음: 받음 줄이 가리키는 결과 파일이 대조를 못 넘으면 구현 중"
assert_contains "$(notes E1)" "받음 줄을 세지 않았다: implement-plan-1-1.md — 보고에 없는 AC — AC2" "받음: 대조 불통을 알린다"
back "$RECEIVED_AT"

# 못 읽는 것 — INTENT.md 가 없는 끝 · 결정 기록의 승인 줄 꼴이 깨진 끝
g rm -q -- "$J1/INTENT.md" && step "INTENT.md 지움" || fail_step "INTENT.md 지움"
assert_eq "$(st E1) · $(why E1) · $(rc)" "알 수 없음 · $J1/INTENT.md 를 읽지 못했다 · 3" "단계: INTENT.md 를 그 끝에서 읽지 못하면 알 수 없음(3)"
assert_eq "$(js "$T/s.json" "(r['unknown_reasons'], r['format_errors'])")" "([], [])" "단계: INTENT.md 못 읽음의 3 은 그 블록 하나에서 온다(보고의 검사 불가 사유 없음)"
back "$RECEIVED_AT"
g rm -q -- "$J1/INTENT.md" && put "$BLK" "$(printf -- '---\ntype: job-blocked\nstage: implement\nplan: 1\nattempt: 2\nhead: %s\n---\n\n## 무엇에 막혔나\n\n의도 파일이 없다.\n\n## 풀려면 무엇이 필요한가\n\n의도 파일을 되살린다.' "$RECEIVED_AT")" \
  && step "INTENT.md 지움 · 막힘" || fail_step "INTENT.md 지움 · 막힘"
assert_eq "$(st E1)" "알 수 없음" "단계: INTENT.md 를 못 읽은 블록 — 알 수 없음"
assert_contains "$(notes E1)" "막힘: implement plan 1 시도 2 — $BLK" "AC29: INTENT.md 를 못 읽어도 막힘 알림은 낸다"
back "$RECEIVED_AT"
printf -- '- spec 승인 · 11/20 · 「글」\n' >> "$W/$J1/INTENT.md" && step "승인 줄 꼴 깨짐" || fail_step "승인 줄 꼴 깨짐"
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
put src/e1/b.txt b2 && g commit -qm "올리지 않은 커밋" && restat || fail_step "올리지 않은 커밋"
assert_contains "$(notes E1)" "아직 안 올라옴 — feature/tm-e1 의 로컬 끝" "끝: 올리지 않은 커밋을 알린다"
assert_eq "$(st E1)" "구현 중" "끝: 단계는 로컬 끝으로 계산한다(origin 끝이면 구현 끝)"
other fetch -q origin && other checkout -q -B feature/tm-e1 origin/feature/tm-e1
mkdir -p "$U/src/e1" && printf 'c\n' > "$U/src/e1/c.txt" && other add -- src/e1/c.txt && other commit -qm "다른 clone 의 커밋" && other push -q origin feature/tm-e1
g fetch -q origin && restat || fail_step "갈라짐 받기"
assert_eq "$(st E1) · $(rc) · $(st E2)" "알 수 없음 · 3 · 준비" "끝: 갈라지면 그 블록만 알 수 없음(3) — 다른 블록은 그대로(Q10)"
assert_eq "$(js "$T/s.json" "(r['unknown_reasons'], r['format_errors'])")" "([], [])" "끝: 갈라짐의 3 은 그 블록 하나에서 온다(보고의 검사 불가 사유 없음)"
assert_eq "$(js "$T/s.json" "[b for b in r['blocks'] if b['id']=='E1'][0]['reason'].startswith('갈라짐 — ')")" "True" "끝: 사유는 「갈라짐 — 」 으로 시작한다"
back "$RECEIVED_AT" && restat || fail_step "갈라짐 되돌리기"
assert_eq "$(st E1) · $(rc)" "구현 끝 · 0" "끝: 되돌리면 구현 끝 · 종료 코드 0"

# 조상 판정(merge-base)만 실패시키는 가짜 git — 진짜 갈라짐의 근거와 견준다(잰 대로 못 박는다)
REAL_GIT="$(command -v git)"
mkdir -p "$T/fakebin"
cat > "$T/fakebin/git" <<FAKE
#!/bin/sh
# merge-base 만 128 로 실패시키고 그 밖의 하위 명령은 진짜 git 으로 넘긴다
sub=""
skip=0
for a in "\$@"; do
  if [ "\$skip" = 1 ]; then skip=0; continue; fi
  case "\$a" in
    -c|-C) skip=1 ;;
    -*) ;;
    *) sub="\$a"; break ;;
  esac
done
if [ "\$sub" = merge-base ]; then echo "fatal: 가짜 git — 조상 판정 실패" >&2; exit 128; fi
exec "$REAL_GIT" "\$@"
FAKE
chmod +x "$T/fakebin/git"
fakestat() { (cd "$W" && PATH="$T/fakebin:$PATH" python3 "$RS" "$RM" --json) > "$T/fake.json" 2>/dev/null; echo "$?"; }
other fetch -q origin && other checkout -q -B feature/tm-e1 origin/feature/tm-e1
g checkout -q feature/tm-e1 && put src/e1/b.txt b3 && g commit -qm "갈라짐 재현(로컬)" \
  && other reset -q --hard "$RECEIVED_AT" && printf 'd\n' > "$U/src/e1/d2.txt" && other add -- src/e1/d2.txt && other commit -qm "갈라짐 재현(원격)" && other push -q -f origin HEAD:feature/tm-e1 \
  && g fetch -q origin && restat || fail_step "진짜 갈라짐 만들기"
SPLIT_REASON="$(why E1)"
FAKE_RC="$(fakestat)"
FAKE_REASON="$(js "$T/fake.json" "[b['reason'] for b in r['blocks'] if b['id']=='E1'][0]")"
assert_eq "$(st E1) · $(rc)" "알 수 없음 · 3" "끝: 진짜 갈라짐 — 알 수 없음 · 3(가짜 git 과 견줄 바탕)"
assert_eq "${FAKE_RC} · $(js "$T/fake.json" "[b['stage'] for b in r['blocks'] if b['id']=='E1'][0]")" "3 · 알 수 없음" "끝: 조상 판정만 실패해도 알 수 없음 · 3(진짜 갈라짐과 같다)"
assert_contains "$SPLIT_REASON" "갈라짐 — " "끝: 진짜 갈라짐의 근거는 「갈라짐 — 」 으로 시작한다"
assert_contains "$FAKE_REASON" "갈라짐 — " "끝: 조상 판정 실패의 근거도 「갈라짐 — 」 으로 시작한다 — 갈라짐과 가르지 않는다(지금 동작)"
assert_contains "$FAKE_REASON" "조상 관계를 잴 수 없다" "끝: 조상 판정 실패의 근거 꼬리는 「조상 관계를 잴 수 없다」 — 진짜 갈라짐의 꼬리와 다르다(지금 동작)"
assert_not_contains "$SPLIT_REASON" "조상 관계를 잴 수 없다" "끝: 진짜 갈라짐의 근거에는 「조상 관계를 잴 수 없다」 가 없다"
back "$RECEIVED_AT" && restat || fail_step "갈라짐 재현 되돌리기"

# 설계 없는 흐름(E2 — 산출물 칸): 준비 → 진행 중 → 결과 받음
g checkout -q -b feature/tm-e2 main && put src/e2/note.txt n && step "E2 시작" || fail_step "E2 시작"
assert_eq "$(st E2) · $(why E2) · $(blk E2 task_status) · $(prog E2)" "진행 중 · 브랜치 있음 · in_progress · None" "단계: 설계 없는 흐름 — 브랜치가 있으면 진행 중"
put "$TM/jobs/E2/survey.md" "$(printf '# 조사 표\n\n| 파일 | 줄 수 |\n|---|---|\n| a.txt | 1 |')" && g commit -qm "조사 표" && CODE2="$(g rev-parse HEAD)"
sync E2 implement-1.md --role worker --bundle-at "$(g rev-parse origin/main)" --job-at "$CODE2" >/dev/null
printf '산출물: %s\n' "$TM/jobs/E2/survey.md" >> "$W/$TM/jobs/E2/results/implement-1.md"
sync E2 implement-1.md --end "$CODE2" >/dev/null && step "E2 결과" || fail_step "E2 결과"
assert_eq "$(st E2) · $(jobf E2 plan) · $(jobf E2 result)" "진행 중 · None · implement-1.md" "단계: 설계 없는 흐름의 결과 파일은 계획 번호가 없다"
assert_contains "$(notes E2)" "결과 있음 · 받음 없음: implement-1.md(대조를 기다린다)" "AC10: 설계 없는 흐름에도 받음 없음 알림"
approved "흐름 승인" E2 - - 2026-11-22 && g push -q origin HEAD && restat || fail_step "E2 흐름 승인"
LINE2="$(cd "$W" && python3 "$JRC" check --roadmap "$RM" --job E2 --result implement-1.md --date 2026-11-24 | grep '^- 결과 받음 · ')"
decide E2 "$LINE2" && step "E2 받음 줄" || fail_step "E2 받음 줄"
assert_eq "$(st E2) · $(why E2) · $(blk E2 task_status)" "결과 받음 · 결과 받음 줄 있음: implement-1.md · in_progress" "단계: 설계 없는 흐름 — 받음 줄이면 결과 받음(Q12)"
E2_AT="$(g rev-parse HEAD)"
# 결과 받음인데 로드맵의 산출물 칸이 가리키는 파일이 그 끝에 없으면 — 번호 대조를 하지 않았다는 경고(머지 전에 보인다)
SKIP_WORDS="번호 대조 건너뜀(셀 수 없음) — 설계문서 없는 묶음이라 배정 번호 2개를 대조하지 않았다"
assert_eq "$(blk E2 specs) · $(js "$T/s.json" "[w for w in [b for b in r['blocks'] if b['id']=='E2'][0]['warnings'] if '설계문서 없는 묶음이라' in w]")" \
  "['$TM/jobs/E2/survey.md'] · []" "결과 받음: 산출물 칸의 파일이 그 끝에 있으면 번호 대조 건너뜀 경고가 없다(아래 단언의 양의 짝)"
MAIN_E2="$(g rev-parse origin/main)"
g checkout -q main && sub "$RM" "$TM/jobs/E2/survey.md" "$TM/jobs/E2/survey-final.md" && g add -- "$RM" \
  && g commit -qm "산출물 칸이 일꾼이 쓰지 않은 이름" && g push -q origin main && restat || fail_step "산출물 칸 바꿈"
assert_eq "$(st E2) · $(blk E2 specs) · $(rc)" "결과 받음 · [] · 1" "결과 받음: 산출물 칸의 파일이 없어도 단계는 결과 받음 · 종료 코드는 경고의 규칙(1)"
assert_contains "$(js "$T/s.json" "' | '.join([b for b in r['blocks'] if b['id']=='E2'][0]['warnings'])")" "$SKIP_WORDS" \
  "결과 받음: 산출물 칸의 파일이 그 끝에 없으면 번호 대조 건너뜀(셀 수 없음) 경고"
back "$MAIN_E2" && g checkout -q feature/tm-e2 || fail_step "산출물 칸 되돌림"
sub "$TM/jobs/E2/INTENT.md" "## 결정 기록" "## 결정 기록 아님" && step "E2 결정 기록 칸 깨짐" || fail_step "E2 결정 기록 칸 깨짐"
assert_eq "$(st E2)" "진행 중" "단계: 설계 없는 흐름 — 결정 기록을 읽지 못하면 진행 중"
assert_contains "$(why E2)" "결정 기록 읽기 불가 — " "단계: 설계 없는 흐름 — 결정 기록 읽기 불가를 근거로 낸다"
assert_eq "$(jobf E2 result)" "implement-1.md" "단계: 결정 기록 칸을 못 찾아도 job.result 는 가장 새 결과 파일"
back "$E2_AT"

# 둘째 브랜치(계획 2): feature/tm-e1 을 기본 브랜치에 merge 커밋으로 합친다
g checkout -q main
MAIN_AT="$(g rev-parse origin/main)"
g merge -q --no-ff --no-edit feature/tm-e1 && g push -q origin main && restat || fail_step "기본 브랜치에 합치기"
assert_eq "$(st E1)" "일부 머지 1/2" "단계: 브랜치 둘 가운데 하나가 머지되면 일부 머지 1/2"
g checkout -q -b feature/tm-e1b main && put src/e1/d.txt d && step "계획 2 시작" || fail_step "계획 2 시작"
assert_contains "$(why E1)" "feature/tm-e1b — 계획 · spec 승인됨(2026-11-20) · plan-2.md 없음" "단계: 둘째 브랜치는 계획 2 로 센다"
sync E1 implement-plan-2-1.md --role worker --bundle-at "$(g rev-parse origin/main)" --job-at "$(g rev-parse HEAD)" >/dev/null && step "계획 2 결과 시작" || fail_step "계획 2 결과 시작"
assert_contains "$(why E1)" "feature/tm-e1b — 구현 중" "단계: 계획 2 의 implement 결과 파일 — 구현 중"
assert_eq "$(jobf E1 plan) · $(jobf E1 result)" "2 · implement-plan-2-1.md" "Q14: job.plan == 2 · job.result 는 계획 2 의 결과 파일"
# 일부 머지가 덮는 「알 수 없음」 — git 실패 없이 지금 브랜치를 세지 못하는 갈래(INTENT.md 없음 · 얕은 클론)도 검사 불가(3)
PARTIAL_LINE="$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import roadmap_status; print(roadmap_status.PARTIAL_UNCOUNTED)' "$S")"
assert_eq "$(js "$T/s.json" "r['unknown_reasons']")" "[]" "일부 머지: 지금 브랜치를 센 블록에는 검사 불가 사유가 없다(아래 단언들의 양의 짝)"
E1B_AT="$(g rev-parse HEAD)"
g rm -q -- "$J1/INTENT.md" && step "둘째 브랜치 끝에 INTENT.md 없음" || fail_step "둘째 브랜치 끝에 INTENT.md 없음"
assert_eq "$(st E1) · $(why E1) · $(rc)" "일부 머지 1/2 · feature/tm-e1b — 알 수 없음 · $J1/INTENT.md 를 읽지 못했다 · 3" \
  "일부 머지: 둘째 브랜치 끝에 INTENT.md 가 없으면 단계 글자는 일부 머지 그대로 · 종료 코드 3"
assert_eq "$(js "$T/s.json" "r['unknown_reasons']")" "['E1 ${PARTIAL_LINE} — feature/tm-e1b — 알 수 없음 · $J1/INTENT.md 를 읽지 못했다']" \
  "일부 머지: 세지 못한 지금 브랜치의 사유가 보고의 검사 불가 사유에 실린다"
back "$E1B_AT"
SH3="$T/shallow3"
git clone -q --no-local --depth 3 --no-single-branch "file://$T/origin.git" "$SH3" && git -C "$SH3" remote set-head origin main \
  || no "깊이 3 얕은 클론을 만들지 못했다"
assert_eq "$(git -C "$SH3" rev-parse --is-shallow-repository)" "true" "일부 머지: 깊이 3 픽스처가 정말 얕은 클론이다"
SH3_RC=0; (cd "$SH3" && python3 "$RS" "$RM" --json) > "$T/shallow3.json" 2>/dev/null || SH3_RC=$?
assert_eq "${SH3_RC} · $(js "$T/shallow3.json" "[b['stage'] for b in r['blocks'] if b['id']=='E1'][0]")" "3 · 일부 머지 1/2" \
  "일부 머지: 깊이 3 얕은 클론 — 첫 브랜치는 머지됨으로 보이고 종료 코드 3"
assert_contains "$(js "$T/shallow3.json" "r['unknown_reasons']")" "E1 ${PARTIAL_LINE} — feature/tm-e1b — 알 수 없음 · 얕은 클론이라" \
  "일부 머지: 깊이 3 얕은 클론 — 세지 못한 지금 브랜치의 사유가 검사 불가 사유에 실린다"
SH3_E2="$(js "$T/shallow3.json" "[(b['stage'], b['reason'].startswith('얕은 클론이라')) for b in r['blocks'] if b['id']=='E2'][0]")"
assert_eq "$SH3_E2" "('알 수 없음', True)" "깊이 3 얕은 클론 — 일부 머지가 아닌 블록(E2)도 알 수 없음 · 근거는 「얕은 클론이라」 로 시작"
rm -rf "$SH3"

# Review Focus 5 — 기본 브랜치를 모르는 레포: 블록이 모두 알 수 없음(3)이고 죽지 않는다
g remote set-head origin -d
NO_RC=0; (cd "$W" && python3 "$RS" --roadmap-file "$RM" --json) > "$T/nohead.json" 2> "$T/nohead.err" || NO_RC=$?
assert_eq "${NO_RC} · $(js "$T/nohead.json" "sorted(set(b['stage'] for b in r['blocks']))")" "3 · ['알 수 없음']" "Review Focus 5: origin/HEAD 가 없으면 블록이 모두 알 수 없음(3)"
assert_not_contains "$(cat "$T/nohead.err")" "Traceback" "Review Focus 5: 표준 오류에 Traceback 이 없다"
assert_not_contains "$(js "$T/nohead.json" "r['unknown_reasons']")" "내부 오류" "Review Focus 5: 계산이 죽지 않았다(내부 오류 없음)"
assert_eq "$(js "$T/nohead.json" "sorted(set(b['reason'] for b in r['blocks']))")" "['기본 브랜치를 못 읽었다']" "Review Focus 5: 블록 사유는 기본 브랜치를 못 읽었다"
assert_contains "$(js "$T/nohead.json" "r['unknown_reasons']")" "기본 브랜치를 알 수 없다 — origin/HEAD 가 없다" "Review Focus 5: 보고의 검사 불가 사유는 origin/HEAD 가 없다"
g remote set-head origin main
g checkout -q main

# Review Focus 5 — 얕은 클론: 과제 브랜치의 받음 · 진행을 셀 이력이 없다 → 그 블록은 알 수 없음(3) · 죽지 않는다
SH="$T/shallow"
git clone -q --no-local --depth 1 --no-single-branch "file://$T/origin.git" "$SH" && git -C "$SH" remote set-head origin main \
  || no "얕은 클론을 만들지 못했다"
assert_eq "$(git -C "$SH" rev-parse --is-shallow-repository)" "true" "Review Focus 5: 픽스처가 정말 얕은 클론이다"
SH_RC=0; (cd "$SH" && python3 "$RS" "$RM" --json) > "$T/shallow.json" 2> "$T/shallow.err" || SH_RC=$?
assert_eq "${SH_RC} · $(js "$T/shallow.json" "[(b['id'], b['stage']) for b in r['blocks'] if b['id'] in ('E1', 'E2')]")" "3 · [('E1', '알 수 없음'), ('E2', '알 수 없음')]" \
  "Review Focus 5: 얕은 클론이면 브랜치가 있는 블록은 알 수 없음(3)"
assert_contains "$(js "$T/shallow.json" "[b['reason'] for b in r['blocks'] if b['id']=='E2'][0]")" "얕은 클론이라" "Review Focus 5: 얕은 클론의 사유"
assert_contains "$(js "$T/shallow.json" "[b['reason'] for b in r['blocks'] if b['id']=='E1'][0]")" "얕은 클론이라" "Review Focus 5: 얕은 클론의 사유 — 브랜치가 있는 다른 블록(E1)도"
assert_not_contains "$(cat "$T/shallow.err")" "Traceback" "Review Focus 5: 얕은 클론에서 죽지 않는다(Traceback 없음)"
assert_not_contains "$(js "$T/shallow.json" "r['unknown_reasons']")" "내부 오류" "Review Focus 5: 얕은 클론에서 죽지 않는다(내부 오류 없음)"

# team 의 시작 흔적(compute 의 started) — PR 캐시에 그 브랜치 줄이 있고 로컬 · origin ref 가 없을 때만 불린다(E3)
MAIN_END="$(g rev-parse HEAD)"
python3 - "$S" "$W" "$RM" "$RECEIVED_AT" "$MAIN_END" > "$T/machine-path.txt" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import conductor_state as cs
import roadmap_status
from state_path import state_root_for_common
root, rm, oid, merge = sys.argv[2:6]
path = cs.machine_path(state_root_for_common(Path(root, roadmap_status.Git(root).common_dir()).resolve()), rm)
path.parent.mkdir(parents=True, exist_ok=True)
data = cs.empty()
data["PR"].append({"브랜치": "feature/tm-e3", "번호": "#93", "상태": "머지됨", "확인한 때": "2026-11-25 09:00", "headRefOid": oid,
                   "교차 레포": "아니오", "baseRefName": "main", "mergeCommit": merge, "쓴 세션": "session-bbbb2222"})
path.write_text(cs.render_machine(rm, data), encoding="utf-8")
print(path)
PY
restat
assert_eq "$(st E3)" "대기" "단계: 시작 흔적 없는 team 에픽 — 같은 이름의 머지된 PR 을 세지 않는다"
assert_contains "$(notes E3)" "같은 이름의 옛 PR #93 은 이 에픽의 PR 로 세지 않았다" "단계: 시작 흔적 없음 — 옛 PR 을 세지 않았다고 알린다"
decide E3 "spec 승인 · 2026-11-25 · 「이대로 승인」" && g add -- "$TM/jobs/E3/INTENT.md" && g commit -qm "E3 승인(기본 브랜치)" && g push -q origin main && restat \
  || fail_step "E3 승인(기본 브랜치)"
assert_eq "$(st E3) · $(why E3)" "머지됨 · PR #93 머지됨(mergeCommit ${MAIN_END:0:8})" "단계: 기본 브랜치 INTENT.md 의 승인 줄이 시작 흔적 — 브랜치를 지운 머지를 센다"
back "$MAIN_END"
put "$TM/jobs/E3/plan-1.md" "# 이어 읽기 계획" && g commit -qm "E3 계획(기본 브랜치)" && g push -q origin main && restat || fail_step "E3 계획(기본 브랜치)"
assert_eq "$(st E3)" "머지됨" "단계: 기본 브랜치 과제 폴더의 계획 파일도 시작 흔적"
back "$MAIN_END"
rm -f "$(cat "$T/machine-path.txt")"; rm -rf "$W/.claude"
assert_eq "$(g status --porcelain --untracked-files=all)" "" "끝 상태: 작업 트리가 깨끗하다(PR 캐시를 지웠다)"
assert_eq "$(g rev-parse --abbrev-ref HEAD) · $(g rev-parse HEAD) · $(g symbolic-ref -q refs/remotes/origin/HEAD)" "main · ${MAIN_END} · refs/remotes/origin/main" \
  "끝 상태: main 을 연 채 · main 은 합친 커밋 · origin/HEAD 는 main"
assert_eq "$(g rev-parse origin/main feature/tm-e1 origin/feature/tm-e1 feature/tm-e2 origin/feature/tm-e2 | tr '\n' ' ')" "${MAIN_END} ${RECEIVED_AT} ${RECEIVED_AT} ${E2_AT} ${E2_AT} " \
  "끝 상태: origin/main 은 합친 커밋 · feature/tm-e1 · feature/tm-e2 는 되돌린 끝(로컬 · origin)"

# ── 알림 — 예약 밖 변경 · INTENT.md 어긋남 · 넘김 · 판정 · 과제 폴더 안 산출물(AC11 · AC28 · AC9) ─────────
# 시작 자리: 위 끝 상태에서 feature/tm-e1b 를 지우고 main 을 E1 을 합치기 전(MAIN_AT) · feature/tm-e1 을 RECEIVED_AT 으로 되돌린다
g branch -q -D feature/tm-e1b && g push -q origin --delete feature/tm-e1b && back "$MAIN_AT" && g checkout -q feature/tm-e1 \
  && back "$RECEIVED_AT" && restat || fail_step "알림 시작 자리"
assert_eq "$(st E1) · $(why E1) · $(g rev-parse origin/main)" "구현 끝 · 결과 받음 줄 있음: implement-plan-1-1.md · ${MAIN_AT}" \
  "알림: 시작 자리 — feature/tm-e1 이 구현 끝 · main 은 E1 을 합치기 전"
before_rc="$(status "$T/n0.json")"
assert_not_contains "$(notes E1)" "예약 밖 변경" "알림: 고칠 자리와 과제 폴더만 바꾼 브랜치에는 예약 밖 변경이 없다"
assert_not_contains "$(notes E1)" "INTENT.md 가 로드맵 블록과 다르다" "알림: 고치지 않은 INTENT.md 에는 어긋남 알림이 없다(아래 단언들의 양의 짝)"
assert_not_contains "$(notes P1)" "INTENT.md" "알림: 결정 블록은 INTENT.md 를 견주지 않는다"
put docs/free.md x && put README.md y && put src/e3/steal.txt z && put "$TM/RULES.md" "# RULES 알림 픽스처" && step "예약 밖 파일들" || fail_step "예약 밖 파일들"
OUTLINE="$(js "$T/s.json" "[n for b in r['blocks'] if b['id']=='E1' for n in b['notes'] if n.startswith('예약 밖 변경: ')][0]")"
assert_contains "$OUTLINE" "docs/free.md" "AC11: 아무도 예약하지 않은 파일이 이름과 함께 나온다"
assert_contains "$OUTLINE" "$TM/RULES.md" "AC11: 팀 폴더의 다른 파일도 예약 밖 변경이다(Q13)"
assert_not_contains "$OUTLINE" "README.md" "AC11: 공유 파일은 뺀다"
assert_not_contains "$OUTLINE" "src/e3/steal.txt" "AC11: 다른 과제가 예약한 파일은 예약 밖 변경이 아니다"
assert_not_contains "$OUTLINE" "src/e1/" "AC11: 자기 고칠 자리는 예약 밖 변경이 아니다"
assert_not_contains "$OUTLINE" "$TM/jobs/E1/" "AC11: 자기 과제 폴더는 예약 밖 변경이 아니다"
assert_eq "$OUTLINE" "예약 밖 변경: docs/free.md · $TM/RULES.md" "AC11: 예약 밖 변경은 한 줄 · 이름 순"
assert_contains "$(notes E1)" "경로 예약 위반: src/e3/steal.txt 은 E3 만 예약했다" "AC11: 경로 예약 위반 알림은 그대로다"
assert_eq "$(rc) · $(st E1)" "${before_rc} · 구현 끝" "AC11: 종료 코드와 단계는 그대로다"
decide E1 "예약 밖 변경 · 2026-11-26 · 「docs/free.md 를 함께 고쳤다」" && step "예약 밖 변경 결정 줄" || fail_step "예약 밖 변경 결정 줄"
assert_contains "$(notes E1)" "예약 밖 변경: docs/free.md · $TM/RULES.md" "Q13: 결정 기록의 예약 밖 변경 줄은 알림을 끄지 않는다"
back "$RECEIVED_AT"
# 어긋남(AC28) — 작업 폴더의 INTENT.md 칸 하나씩
sub "$J1/INTENT.md" "첫 읽기를 만든다" "첫 읽기를 만든다." && step "목표 칸 고침" || fail_step "목표 칸 고침"
assert_contains "$(notes E1)" "INTENT.md 가 로드맵 블록과 다르다: E1 — 목표 칸이 로드맵의 의도 · 범위와 다르다" "AC28: 목표 칸이 로드맵 블록과 다르면 알린다"
assert_not_contains "$(notes E1)" "하지 않을 것 칸이" "AC28: 고치지 않은 칸은 알리지 않는다"
assert_eq "$(rc)" "$before_rc" "AC28: 어긋남 알림은 종료 코드를 바꾸지 않는다"
back "$RECEIVED_AT"
sub "$J1/INTENT.md" "- 쓰기" "- 쓰기와 지우기" && step "하지 않을 것 칸 고침" || fail_step "하지 않을 것 칸 고침"
assert_contains "$(notes E1)" "INTENT.md 가 로드맵 블록과 다르다: E1 — 하지 않을 것 칸이 로드맵의 범위(안 한다 쪽)와 다르다" "AC28: 하지 않을 것 칸이 다르면 알린다"
assert_not_contains "$(notes E1)" "목표 칸이" "AC28: 목표 칸은 그대로라 알리지 않는다"
back "$RECEIVED_AT"
sub "$J1/INTENT.md" "## 목표" "## 목표 아님" && step "목표 칸 제목 깨짐" || fail_step "목표 칸 제목 깨짐"
assert_contains "$(notes E1)" "INTENT.md 를 로드맵 블록과 견주지 못했다: E1 — 칸이 없다: ## 목표" "AC28: 칸을 찾지 못하면 견주지 못했다고 알린다"
assert_contains "$(js "$T/s.json" "r['unknown_reasons']")" "E1 INTENT.md 의 결정 기록 읽기 불가 — 칸이 없다: ## 목표" "넘김: 단계를 센 블록의 결정 기록을 못 읽으면 검사 불가 사유"
assert_eq "$(rc)" "3" "넘김: 결정 기록 읽기 불가는 검사 불가(3)"
back "$RECEIVED_AT"
g rm -q -- "$J1/INTENT.md" && step "INTENT.md 지움(알림)" || fail_step "INTENT.md 지움(알림)"
assert_contains "$(notes E1)" "$J1/INTENT.md 를 읽지 못했다" "AC28: INTENT.md 를 읽지 못하면 그 한 줄"
assert_eq "$(js "$T/s.json" "(r['unknown_reasons'], [b['warnings'] for b in r['blocks'] if b['id']=='E1'][0])")" "([], [])" \
  "넘김: 브랜치 끝에 INTENT.md 가 없으면 결정 기록은 빈 글 — 경고 · 검사 불가 사유가 없다"
# 위 블록은 단계가 알 수 없음이라 보고가 결정 기록 읽기의 결과를 가린다 — 그 끝에서 record_text 를 직접 부른다
rectext() {  # rectext — feature/tm-e1 끝에서 E1 의 Reader.record_text(빈 글이면 '', 읽지 못하면 FormatError 와 사유)
  python3 - "$S" "$W" "$RD" "$RM" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import roadmap_status, team_layout, team_status
from roadmap_model import FormatError, parse_roadmap
root, rd, rm = sys.argv[2:5]
git = roadmap_status.Git(root)
main = git.commit("refs/remotes/origin/HEAD")
e1 = [b for b in parse_roadmap(git.blob(main, rm))[1] if b["id"] == "E1"][0]
reader = team_status.Reader(git, main, team_layout.team_from_roadmap(rd, rm), lambda p: git.blob(main, p), lambda p: git.absent(main, p))
try:
    print(repr(reader.record_text(git.commit("refs/heads/feature/tm-e1"), e1)))
except FormatError as exc:
    print("FormatError: %s" % exc)
PY
}
assert_eq "$(rectext)" "''" "넘김: 브랜치 끝에서 INTENT.md 가 확인된 없음이면 record_text 는 빈 글을 낸다(FormatError 가 아니다)"
back "$RECEIVED_AT"
g rm -q -- "$J1/INTENT.md" && put "$J1/INTENT.md/x.txt" "폴더인 INTENT" && step "INTENT.md 가 폴더(브랜치 끝)" || fail_step "INTENT.md 가 폴더(브랜치 끝)"
assert_eq "$(st E1) · $(rc)" "알 수 없음 · 3" "알림: 브랜치 끝의 INTENT.md 를 읽지 못하면 알 수 없음(3)"
assert_eq "$(js "$T/s.json" "(r['unknown_reasons'], [b['warnings'] for b in r['blocks'] if b['id']=='E1'][0])")" "([], [])" \
  "알림: 알 수 없음 블록의 결정 기록 · 판정 읽기 불가를 경고 · 검사 불가 사유로 겹쳐 내지 않는다"
assert_eq "$(rectext)" "FormatError: $J1/INTENT.md 를 읽지 못했다" "넘김: 브랜치 끝의 INTENT.md 가 있는데 못 읽으면 record_text 는 FormatError(위 단언의 양의 짝)"
back "$RECEIVED_AT"
g checkout -q main && sub "$TM/jobs/E3/INTENT.md" "첫 읽기 위에 얹는다" "첫 읽기 위에 얹었다" && step "E3 목표 칸 고침(기본 브랜치)" || fail_step "E3 목표 칸 고침(기본 브랜치)"
assert_contains "$(notes E3)" "INTENT.md 가 로드맵 블록과 다르다: E3 — 목표 칸이 로드맵의 의도 · 범위와 다르다" "AC28: 브랜치가 없는 과제는 기본 브랜치의 INTENT.md 를 견준다"
assert_not_contains "$(notes E2)" "INTENT.md 가 로드맵 블록과 다르다" "AC28: 고치지 않은 E2 에는 어긋남 알림이 없다(양의 짝)"
assert_eq "$(rc)" "$before_rc" "AC28: 기본 브랜치의 어긋남도 종료 코드를 바꾸지 않는다"
back "$MAIN_AT"
# 기본 브랜치의 E3 INTENT.md 가 없음 · 있는데 못 읽음 — 없음은 빈 결정 기록(옛 형식의 설계문서 없는 블록과 같다), 못 읽음은 검사 불가
g rm -q -- "$TM/jobs/E3/INTENT.md" && step "E3 INTENT.md 지움(기본 브랜치)" || fail_step "E3 INTENT.md 지움(기본 브랜치)"
assert_contains "$(notes E3)" "$TM/jobs/E3/INTENT.md 를 읽지 못했다" "AC28: 없는 INTENT.md 는 견주지 못했다는 한 줄"
assert_eq "$(rc) · $(blk E3 warnings)" "${before_rc} · []" "넘김: 없는 INTENT.md 는 빈 결정 기록 — 경고 · 종료 코드 그대로"
back "$MAIN_AT"
g rm -q -- "$TM/jobs/E3/INTENT.md" && put "$TM/jobs/E3/INTENT.md/x.txt" "폴더인 INTENT" && step "E3 INTENT.md 가 폴더(기본 브랜치)" || fail_step "E3 INTENT.md 가 폴더(기본 브랜치)"
assert_contains "$(blk E3 warnings)" "INTENT.md 의 결정 기록 읽기 불가($TM/jobs/E3/INTENT.md 를 읽지 못했다)" "넘김: 있는데 읽지 못한 INTENT.md 는 경고"
assert_eq "$(rc)" "3" "넘김: 있는데 읽지 못한 INTENT.md 는 검사 불가(3)"
back "$MAIN_AT"
# git 이 기본 브랜치의 E3 INTENT.md 를 읽지 못한다(없음이 아닌 실패) — 없음으로 세지 않는다: 경고 · git 읽기 실패 · 검사 불가
mkdir -p "$T/gitfail"
printf '#!/bin/bash\nfor a in "$@"; do case "$a" in *:%s) echo "fatal: 객체를 읽지 못했다(흉내)" >&2; exit 128 ;; esac; done\nexec %s "$@"\n' \
  "$TM/jobs/E3/INTENT.md" "$(command -v git)" > "$T/gitfail/git" && chmod +x "$T/gitfail/git"
GF_RC=0; (cd "$W" && PATH="$T/gitfail:$PATH" python3 "$RS" "$RM" --json) > "$T/gitfail.json" 2>/dev/null || GF_RC=$?
assert_eq "${GF_RC} · $(js "$T/gitfail.json" "[b['stage'] for b in r['blocks'] if b['id']=='E3'][0]")" "3 · 대기" "넘김: git 이 INTENT.md 를 읽지 못하면 검사 불가(3)"
assert_contains "$(js "$T/gitfail.json" "[b['warnings'] for b in r['blocks'] if b['id']=='E3'][0]")" "INTENT.md 의 결정 기록 읽기 불가($TM/jobs/E3/INTENT.md 를 읽지 못했다)" \
  "넘김: git 실패를 INTENT.md 없음으로 세지 않는다(경고)"
assert_contains "$(js "$T/gitfail.json" "r['unknown_reasons']")" "git 읽기 실패 — git cat-file 실패(rc 128): fatal: 객체를 읽지 못했다(흉내)" \
  "넘김: 그 git 실패가 검사 불가 사유에 남는다"
# 넘김 —과제 폴더 design.md 의 미룸 행 · 받는 과제 INTENT.md 의 넘김 확인 줄
HO="[(h['giver'], h['receiver'], h['state'], h['basis']) for h in r['handoffs'] if h['item']=='넘길 일']"
g checkout -q feature/tm-e1 && printf '| 넘길 일 | 이유 | E3 |\n' >> "$W/$J1/design.md" && step "E1 미룸 한 행" || fail_step "E1 미룸 한 행"
assert_eq "$(js "$T/s.json" "$HO")" "[('E1', 'E3', '열림', 'E3 대기')]" "넘김: 과제 폴더 design.md 의 미룸 행 — 열림"
CONFIRM="$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import conductor_state; print(conductor_state.confirm_line("E1", "넘길 일", "받았다"))' "$S")"
g checkout -q main && decide E3 "$CONFIRM" && step "E3 넘김 확인(기본 브랜치)" || fail_step "E3 넘김 확인(기본 브랜치)"
assert_eq "$(js "$T/s.json" "$HO")" "[('E1', 'E3', '확인됨', 'E3 INTENT.md 의 결정 기록')]" "넘김: 받는 과제 INTENT.md 의 넘김 확인 줄 — 확인됨"
sub "$TM/jobs/E3/INTENT.md" "## 결정 기록" "## 결정 기록 아님" && step "E3 결정 기록 칸 깨짐" || fail_step "E3 결정 기록 칸 깨짐"
assert_eq "$(js "$T/s.json" "$HO")" "[('E1', 'E3', '셀 수 없음', 'E3 INTENT.md 의 결정 기록 읽기 불가')]" "넘김: 받는 과제의 결정 기록을 못 읽으면 셀 수 없음"
back "$MAIN_AT"
# 판정 — 결과 파일의 Ruling 줄 · 결과 파일이 없는 과제 · 결정 블록 · 읽지 못한 결과 파일
g checkout -q feature/tm-e1 && back "$RECEIVED_AT" && sub "$R1" "끝 — $CODE" $'Ruling: 알림 픽스처의 판정 — 읽는 자리는 결과 파일이다\n끝 — '"$CODE" \
  && step "결과 파일의 판정 줄" || fail_step "결과 파일의 판정 줄"
assert_eq "$(blk E1 rulings_archived)" "['- Ruling: 알림 픽스처의 판정 — 읽는 자리는 결과 파일이다']" "판정: 결과 파일의 Ruling 줄에 - 를 붙여 싣는다"
assert_eq "$(st E1)" "구현 끝" "판정: 결과 파일에 판정 줄을 더해도 구현 끝 그대로"
assert_eq "$(blk E3 rulings_archived) · $(blk P1 rulings_archived)" "[] · None" "판정: 결과 파일이 없는 과제는 [] · 결정 블록은 None"
back "$RECEIVED_AT"
g checkout -q main && put "$TM/jobs/E3/results/review-1.md/x.txt" "폴더인 결과 이름" && step "E3 결과 이름의 폴더(기본 브랜치)" || fail_step "E3 결과 이름의 폴더(기본 브랜치)"
assert_contains "$(blk E3 warnings)" "판정 읽기 불가($TM/jobs/E3/results/review-1.md 를 읽지 못했다)" "판정: 읽지 못한 결과 파일은 0 이 아니라 경고"
assert_contains "$(js "$T/s.json" "r['unknown_reasons']")" "E3 판정 읽기 불가 — $TM/jobs/E3/results/review-1.md 를 읽지 못했다" "판정: 읽지 못한 결과 파일은 검사 불가 사유"
assert_eq "$(rc) · $(blk E3 rulings_archived)" "3 · None" "판정: 읽지 못하면 검사 불가(3) · 판정 칸은 None"
back "$MAIN_AT"
# 판정 줄을 다 읽지 못한 결과 파일 — 다른 단계의 파일(design-1.md)에 판정 줄 · 닫히지 않은 펜스 · 판정 줄, implement 파일은 깨끗한 판정 줄
g checkout -q feature/tm-e1 && sync E1 design-1.md --role designer --bundle-at "$MAIN_AT" --job-at "$RECEIVED_AT" >/dev/null \
  && printf 'Ruling: 앞의 판정 — 펜스 앞\n```text\nRuling: 뒤의 판정 — 펜스 안으로 사라진다\n' >> "$W/$J1/results/design-1.md" \
  && sub "$R1" "끝 — $CODE" $'Ruling: 새 시도의 판정 — 깨끗하다\n끝 — '"$CODE" && step "판정 줄을 다 읽지 못한 결과 파일" || fail_step "판정 줄을 다 읽지 못한 결과 파일"
assert_eq "$(blk E1 rulings_archived)" "['- Ruling: 앞의 판정 — 펜스 앞', '- Ruling: 새 시도의 판정 — 깨끗하다']" "판정: 다 읽지 못한 결과 파일에서도 읽힌 판정 줄은 싣는다"
assert_contains "$(notes E1)" "판정 줄을 다 읽지 못했다: design-1.md — 본문의 코드 펜스가 닫히지 않았다" "판정: 판정 줄을 다 읽지 못한 결과 파일을 알린다(0 이 아니다)"
assert_eq "$(rc) · $(st E1)" "${before_rc} · 구현 끝" "판정: 그 알림은 종료 코드 · 단계를 바꾸지 않는다"
back "$RECEIVED_AT"
OPEN_AFTER=$'```text\nTask 2/3:'
sub "$R1" "Task 2/3:" "$OPEN_AFTER" && step "받은 뒤 닫히지 않은 펜스" || fail_step "받은 뒤 닫히지 않은 펜스"
assert_contains "$(notes E1)" "받음 줄을 세지 않았다: implement-plan-1-1.md — 본문의 코드 펜스가 닫히지 않았다" "판정: 받은 뒤 닫히지 않은 펜스 — 받음 줄을 세지 않았다"
assert_eq "$(js "$T/s.json" "sum(n.count('본문의 코드 펜스가 닫히지 않았다') for b in r['blocks'] if b['id']=='E1' for n in b['notes'])")" "1" \
  "판정: 같은 결과 파일 · 같은 사유를 이미 알렸으면 판정 줄 알림을 덧내지 않는다(Q13)"
back "$RECEIVED_AT"
# 같은 사실은 한 번 — 받음 줄이 가리키는 결과 파일을 다 읽지 못하면 받음 줄의 알림 하나로 낸다
g checkout -q feature/tm-e1 && python3 -c 'import sys; p = sys.argv[1]; t = open(p, encoding="utf-8", newline="").read(); open(p, "w", encoding="utf-8", newline="").write("\ufeff" + t)' "$W/$R1" \
  && step "받은 뒤 BOM" || fail_step "받은 뒤 BOM"
assert_contains "$(notes E1)" "받음 줄을 세지 않았다: implement-plan-1-1.md — 머리(첫 줄" "알림: 받은 뒤 다 읽지 못한 결과 파일 — 받음 줄을 세지 않았다"
assert_eq "$(js "$T/s.json" "sum(n.count('머리(첫 줄') for b in r['blocks'] if b['id']=='E1' for n in b['notes'])")" "1" \
  "알림: 받음 줄의 결과 파일을 다 읽지 못한 사실은 한 번만 알린다(Q13)"
back "$RECEIVED_AT"
# 조사 흐름(AC9) — feature/tm-e2 를 다시 쓴다: 과제 폴더 안 산출물의 번호 대조 · 미룸
SURVEY="$(printf '# 조사 표\n\n| 파일 | 줄 수 |\n|---|---|\n| a.txt | 1 |\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| D2 | 반영 | 조사 표 |\n| S2 | 반영 | 조사 표의 칸 |\n\n## 미룸\n\n| 항목 | 이유 | 받는 곳 |\n|---|---|---|\n| 조사 넘김 | 표 밖의 파일 | E3 |')"
g checkout -q feature/tm-e2 && restat || fail_step "feature/tm-e2 로"
assert_eq "$(g rev-parse HEAD) · $(blk E2 specs)" "${E2_AT} · ['$TM/jobs/E2/survey.md']" "AC9: 산출물이 설계문서 자리다(feature/tm-e2 의 받은 끝)"
assert_contains "$(blk E2 warnings)" "번호 대조 건너뜀" "AC9: 번호 대조 절이 없는 산출물은 건너뛴다고 경고한다(아래 「없다」 의 양의 짝)"
put "$TM/jobs/E2/survey.md" "$SURVEY" && step "조사 표의 번호 대조 · 미룸" || fail_step "조사 표의 번호 대조 · 미룸"
assert_eq "$(blk E2 specs)" "['$TM/jobs/E2/survey.md']" "AC9: 과제 폴더 안 산출물이 E2 의 specs"
assert_not_contains "$(blk E2 warnings)" "번호 대조 건너뜀" "AC9: 산출물의 번호 대조 표를 읽는다"
assert_not_contains "$(blk E2 warnings)" "생략" "AC9: 번호를 다 받들면 생략이 없다(아래 단언의 양의 짝)"
assert_eq "$(js "$T/s.json" "[(h['giver'], h['receiver'], h['state']) for h in r['handoffs'] if h['giver']=='E2']")" "[('E2', 'E3', '열림')]" "AC9: 산출물의 미룸 표가 넘김이 된다"
assert_not_contains "$(notes E2)" "예약 밖 변경" "AC11: 자기 과제 폴더 안 산출물은 예약 밖 변경이 아니다"
drop "$TM/jobs/E2/survey.md" "| S2 |" && step "번호 대조에서 S2 를 지움" || fail_step "번호 대조에서 S2 를 지움"
assert_contains "$(blk E2 warnings)" "생략: " "AC9: 번호 대조 표에서 빠진 번호는 생략"
assert_contains "$(blk E2 warnings)" "S2" "AC9: 생략 경고가 빠진 번호를 적는다"
back "$E2_AT"
# 읽는 함수를 바로 부른다 — 결과 폴더를 못 읽는 가짜 Git · 기본 브랜치 모름 · 사본에서 없음을 물을 길 없음 · 옛 근거 글
python3 - "$S" "$W" "$RD" "$RM" "$RECEIVED_AT" > "$T/notice-reader.txt" 2>&1 <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import conductor_state, roadmap_model, roadmap_status, team_layout, team_status
from roadmap_model import FormatError, parse_roadmap
root, rd, rm, tip = sys.argv[2:6]
team = team_layout.team_from_roadmap(rd, rm)
git = roadmap_status.Git(root)
main = git.commit("refs/remotes/origin/HEAD")
block = {b["id"]: b for b in parse_roadmap(git.blob(main, rm))[1]}["E1"]


class Shut(roadmap_status.Git):
    def names(self, rev, folder):
        return None if folder == team.results("E1") else super().names(rev, folder)


def tried(f):
    try:
        return f()
    except FormatError as exc:
        return "FormatError: %s" % exc


print("rulings-folder", tried(lambda: team_status.Reader(Shut(root), main, team, lambda p: None).rulings(tip, block)))
print("rulings-nomain", tried(lambda: team_status.Reader(git, None, team, lambda p: None).rulings(None, block)))
print("record-no-exists", tried(lambda: team_status.Reader(git, main, team, lambda p: None).record_text(None, block)))
rows = [("E1", "d.md", [("넘길 일", "이유", "E3")])]
record = {"E3": conductor_state.confirm_line("E1", "넘길 일", "받았다")}
print("old-basis", roadmap_model.handoff_rows(rows, {"E1": "구현 끝", "E3": "대기"}, record)[0]["basis"])
PY
assert_contains "$(cat "$T/notice-reader.txt")" "rulings-folder FormatError: $J1/results 를 읽지 못했다" "판정: 결과 폴더를 읽지 못하면 [] 가 아니라 FormatError"
assert_contains "$(cat "$T/notice-reader.txt")" "rulings-nomain FormatError: 기본 브랜치를 몰라 결과 파일을 읽지 못했다" "판정: 기본 브랜치를 모르면 FormatError"
assert_contains "$(cat "$T/notice-reader.txt")" "record-no-exists FormatError: $J1/INTENT.md 를 읽지 못했다" \
  "넘김: 사본에서 없음을 확인할 길이 없으면 없음으로 치지 않는다(FormatError)"
assert_contains "$(cat "$T/notice-reader.txt")" "old-basis E3 설계문서의 지휘 기록 절" "넘김: record_label 이 없으면 옛 근거 글 그대로"
assert_not_contains "$(cat "$T/notice-reader.txt")" "Traceback" "알림: 읽는 함수들이 죽지 않는다"
g checkout -q main && restat || fail_step "알림 끝"
# 기본 브랜치를 모르면(알 수 없음 블록) 판정 · 결정 기록 읽기 불가를 블록마다 겹쳐 내지 않는다 — 그 사실은 검사 불가 사유 한 줄이 말한다
g remote set-head origin -d
NH_RC=0; (cd "$W" && python3 "$RS" --roadmap-file "$RM" --json) > "$T/nohead2.json" 2>/dev/null || NH_RC=$?
assert_eq "${NH_RC} · $(js "$T/nohead2.json" "[u for u in r['unknown_reasons'] if '읽기 불가' in u]")" "3 · []" \
  "알림: 기본 브랜치를 모르면 블록마다 판정 · 결정 기록 읽기 불가를 겹쳐 내지 않는다"
assert_contains "$(js "$T/nohead2.json" "r['unknown_reasons']")" "기본 브랜치를 알 수 없다" "알림: 그 사실은 검사 불가 사유 한 줄이 말한다(양의 짝)"
g remote set-head origin main
assert_eq "$(g status --porcelain --untracked-files=all)" "" "알림 끝 상태: 작업 트리가 깨끗하다"
assert_eq "$(g rev-parse --abbrev-ref HEAD) · $(g rev-parse HEAD) · $(g rev-parse origin/main) · $(g symbolic-ref -q refs/remotes/origin/HEAD)" \
  "main · ${MAIN_AT} · ${MAIN_AT} · refs/remotes/origin/main" "알림 끝 상태: main 을 연 채 · main 은 E1 을 합치기 전(MAIN_AT) · origin/HEAD 는 main"
assert_eq "$(g rev-parse feature/tm-e1 origin/feature/tm-e1 feature/tm-e2 origin/feature/tm-e2 | tr '\n' ' ')" "${RECEIVED_AT} ${RECEIVED_AT} ${E2_AT} ${E2_AT} " \
  "알림 끝 상태: feature/tm-e1 은 RECEIVED_AT · feature/tm-e2 는 E2_AT(로컬 · origin)"
assert_eq "$(g for-each-ref --format='%(refname)' refs/heads/feature/tm-e1b refs/heads/feature/tm-e3 refs/remotes/origin/feature/tm-e1b refs/remotes/origin/feature/tm-e3)" "" \
  "알림 끝 상태: feature/tm-e1b · feature/tm-e3 이 없다(로컬 · origin)"
assert_eq "$(st E1) · $(st E2) · $(st E3)" "구현 끝 · 결과 받음 · 대기" "알림 끝 상태: 단계 — E1 구현 끝 · E2 결과 받음 · E3 대기"
# 이름 꼴: 흐름과 다른 꼴의 implement 결과 파일은 세지 않고 알린다 — 단계 · 근거 · 종료 코드는 그대로다
g checkout -q main && restat || fail_step "이름 꼴 시작"
assert_not_contains "$(notes E1) | $(notes E2)" "세지 않은 결과 파일" "이름 꼴: 꼴이 맞는 결과 파일만 있는 블록에는 알림이 없다(음의 짝)"
SHAPE_BEFORE="$(st E1) · $(why E1) · $(rc) · $(st E2) · $(why E2)"
g checkout -q feature/tm-e1 && sync E1 implement-1.md --role worker --bundle-at "$(g rev-parse origin/main)" --job-at "$(g rev-parse HEAD)" >/dev/null \
  && step "이름 꼴: 설계 흐름에 번호 없는 이름" || fail_step "이름 꼴: 설계 흐름"
assert_eq "$(st E1) · $(why E1) · $(rc) · $(st E2) · $(why E2)" "$SHAPE_BEFORE" "이름 꼴: 설계 흐름에 번호 없는 이름 — 단계 · 근거 · 종료 코드는 그 파일을 두기 전과 같다"
assert_contains "$(notes E1)" "세지 않은 결과 파일: implement-1.md — 설계 흐름 의 implement 결과 파일은 implement-plan-1-1.md 이다" \
  "이름 꼴: 설계 흐름에 번호 없는 이름이면 맞는 이름을 알린다"
back "$RECEIVED_AT" && restat
assert_not_contains "$(notes E1)" "세지 않은 결과 파일" "이름 꼴: 그 파일을 치우면 알림도 사라진다"
g checkout -q feature/tm-e2 && sync E2 implement-plan-1-1.md --role worker --bundle-at "$(g rev-parse origin/main)" --job-at "$(g rev-parse HEAD)" >/dev/null \
  && step "이름 꼴: 설계 없는 흐름에 번호 붙은 이름" || fail_step "이름 꼴: 설계 없는 흐름"
assert_eq "$(st E1) · $(why E1) · $(rc) · $(st E2) · $(why E2)" "$SHAPE_BEFORE" "이름 꼴: 설계 없는 흐름에 번호 붙은 이름 — 단계 · 근거 · 종료 코드는 그대로다"
assert_contains "$(notes E2)" "세지 않은 결과 파일: implement-plan-1-1.md — 설계 없는 흐름 의 implement 결과 파일은 implement-1.md 이다" \
  "이름 꼴: 설계 없는 흐름에 번호 붙은 이름이면 맞는 이름을 알린다"
back "$E2_AT" && restat
g checkout -q main
# ── 사람 줄 관문 — 근거 있는 승인 줄만 단계를 넘긴다(AC8 · AC12 · AC20) ──────────────────────────────
# 새 레포(E3) — 위 레포의 상태와 겹치지 않게 임시 폴더 하나를 더 쓴다
T0="$T"; T="$T0/gate"; mkdir -p "$T"; W="$T/repo"; export CLAUDE_CONFIG_DIR="$T/claude"
team_repo && ok "관문 레포를 세웠다(${TM})" || { no "관문 레포를 세우지 못했다 — $(cat "$T/out.txt")"; finish; }
J3="$TM/jobs/E3"
g add -A -- "$RD" && g commit -qm "공통 문서" && g push -q origin main
claim || no "지휘 표지를 쥐지 못했다 — $(cat "$T/led.txt")"
g checkout -q -b feature/tm-e3 main && put "$J3/design.md" "$(printf '%s' "$DESIGN" | sed 's/^job: E1$/job: E3/')" && step "E3 설계문서" || fail_step "E3 설계문서"
approved "spec 승인" E3 - - 2026-11-25 && g push -q origin HEAD && restat || fail_step "E3 승인"
assert_eq "$(st E3) · $(why E3)" "계획 · spec 승인됨(2026-11-25) · plan-1.md 없음 · implement 결과 파일 없음" "AC8: 승인 줄이 지나면 계획(새 레포)"
G_OK="$(g rev-parse HEAD)"
# a — 기록 절 · 미룸 절만 고친다
printf '\n## 지휘 기록\n\n- 메모 하나\n' >> "$W/$J3/design.md"
sub "$J3/design.md" "| 항목 | 이유 | 받는 곳 |
|---|---|---|" "| 항목 | 이유 | 받는 곳 |
|---|---|---|
| 알림 글 | 나중에 정한다 | plan-1.md |" && step "기록 절 · 미룸 절" || fail_step "기록 절 · 미룸 절"
assert_eq "$(st E3)" "계획" "AC8: 기록 절 · 미룸 절은 승인을 낡게 하지 않는다"
# b — 본문을 고친다
sub "$J3/design.md" "과제 폴더를 읽는다." "과제 폴더를 다시 읽는다." && step "본문 고침" || fail_step "본문 고침"
assert_eq "$(st E3)" "설계 중" "AC8: 승인 뒤 본문을 고치면 설계 중"
assert_contains "$(why E3)" "낡음" "AC8: 본문을 고친 사유에 낡음"
G_STALE="$(g rev-parse HEAD)"
# c — 건너뜀 줄
approved "걸음 건너뜀" E3 - "spec 승인" 2026-11-26 && g push -q origin HEAD && restat || fail_step "E3 건너뜀"
assert_eq "$(st E3)" "계획" "AC12: 건너뜀 줄로 지나면 계획"
case "$(why E3)" in "spec 승인 건너뜀(2026-11-26)"*) ok "AC12: 근거의 앞머리가 spec 승인 건너뜀(2026-11-26)" ;; *) no "AC12: 근거의 앞머리 — $(why E3)" ;; esac
# d — 건너뜀 줄 없이 관문을 끄고 손으로 적은 줄
back "$G_STALE"
g checkout -q main && printf '%s\n' '---' 'human_gate: 끔' '---' > "$W/.devbrew.md" && g add -- .devbrew.md && g commit -qm "관문 끔" \
  && g push -q origin main && g fetch -q origin && g checkout -q feature/tm-e3 || fail_step "관문 끔"
decide E3 "spec 승인 · 2026-11-27 · 「글」" && step "손으로 적은 승인 줄(관문 꺼짐)" || fail_step "손으로 적은 승인 줄(관문 꺼짐)"
assert_eq "$(st E3)" "계획" "AC20: 관문이 꺼지면 손으로 적은 줄도 지난다"
case "$(why E3)" in "spec 승인됨(2026-11-27)"*) ok "AC20: 손으로 적은 줄의 날짜가 근거다(낡은 줄 2026-11-25 가 아니다)" ;; *) no "AC20: 손으로 적은 줄의 날짜 — $(why E3)" ;; esac
assert_eq "$(js "$T/s.json" "[b for b in r['blocks'] if b['id']=='E3'][0]['notes'][0]")" "사람 줄 대조가 꺼져 있다" "AC20: 도는 과제의 첫 알림 줄"
# e — 설계 없는 흐름 · 로드맵 밖 과제
g checkout -q -b feature/tm-e2 main && put src/e2/note.txt n && step "E2 시작(관문 꺼짐)" || fail_step "E2 시작(관문 꺼짐)"
g checkout -q -b chore/tm-gate main
printf '로드맵 밖 일\n' | (cd "$W" && python3 "$RW" job new --roadmap "$RM" --name gate-task --branch chore/tm-gate --paths docs/tv/ --goal "로드맵 밖 일") > "$T/out.txt" 2>&1
g add -- "$TM/jobs/gate-task" && g commit -qm "과제 gate-task" && g push -q origin chore/tm-gate && g fetch -q origin \
  && put docs/tv/ahead.txt a && g commit -qm "올리지 않은 커밋" && restat || fail_step "로드맵 밖 과제"
assert_contains "$(js "$T/s.json" "' | '.join([j for j in r['jobs'] if j['id']=='gate-task'][0]['notes'])")" "아직 안 올라옴" "AC20 전제: 로드맵 밖 과제에 올라오지 않은 끝 알림이 있다(첫 줄 단언이 맞물린다)"
assert_eq "$(js "$T/s.json" "[b for b in r['blocks'] if b['id']=='E2'][0]['notes'][0]")" "사람 줄 대조가 꺼져 있다" "AC20: 설계 없는 흐름 블록의 첫 알림 줄"
assert_eq "$(js "$T/s.json" "[j for j in r['jobs'] if j['id']=='gate-task'][0]['notes'][0]")" "사람 줄 대조가 꺼져 있다" "AC20: 로드맵 밖 과제의 첫 알림 줄"
# f — 브랜치 없는 블록
assert_eq "$(st E1)" "준비" "AC20 전제: E1 은 브랜치가 없어 준비"
assert_not_contains "$(notes E1)" "사람 줄 대조가 꺼져 있다" "AC20: 브랜치 없는 블록(준비)에는 그 줄이 없다"
# g — 되돌린다(양성 대조)
g checkout -q main && printf '%s\n' '---' 'human_gate: 켬' '---' > "$W/.devbrew.md" && g add -- .devbrew.md && g commit -qm "관문 켬" \
  && g push -q origin main && g fetch -q origin && restat || fail_step "관문 켬"
assert_eq "$(st E3)" "설계 중" "AC20: 설정을 되돌리면 손으로 적은 줄은 다시 지나지 못한다"
assert_not_contains "$(notes E3) | $(notes E2) | $(js "$T/s.json" "' | '.join([j for j in r['jobs'] if j['id']=='gate-task'][0]['notes'])")" "사람 줄 대조가 꺼져 있다" \
  "AC20: 켜지면 어느 알림에도 그 줄이 없다(양성 대조)"
# h · i — 설정을 읽지 못하거나 오류가 있으면 켜진 것으로 본다(J19). 현황 보고는 설정 오류를 알 수 없음(3)으로 먼저 올리므로
# 이 기본값은 Reader 를 직접 불러 잰다(시작 묶음이 Reader 를 따로 만든다)
gate_of() {  # gate_of <.devbrew.md 글> — 기본 브랜치에 그 설정을 올리고 새 Reader 의 gate_on() 을 낸다
  g checkout -q main && printf '%s\n' "$1" > "$W/.devbrew.md" && g add -- .devbrew.md && g commit -qm "설정 시험" \
    && g push -q origin main && g fetch -q origin || { echo "설정 올리기 실패"; return; }
  python3 - "$S" "$W" <<'PY2'
import sys
sys.path.insert(0, sys.argv[1])
import roadmap_status, team_status
print(team_status.Reader(roadmap_status.Git(sys.argv[2]), None, None, None).gate_on())
PY2
}
assert_eq "$(gate_of "$(printf -- '---\nhuman_gate: 끔\n---')")" "False" "J19 양의 짝: 읽은 설정이 끔 이면 관문이 꺼진다"
assert_eq "$(gate_of 'frontmatter 가 없는 설정')" "True" "J19: 설정을 읽지 못하면(SettingsError) 관문은 켜진 채"
assert_eq "$(gate_of "$(printf -- '---\nhuman_gate: 끔\nno_such_key: 1\n---')")" "True" "J19: 설정에 오류가 있으면 끔 이 적혀 있어도 관문은 켜진 채"
T="$T0"

# ── 받음 줄의 낡음 — 받은 head 와 지금 끝의 글을 견준다(K13 · 새 레포) ─────────────────────────────
new_repo "$T0/rcpt" && ok "받음 낡음: 팀 레포를 세웠다(${TM})" || { no "받음 낡음: 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
J1="$TM/jobs/E1"
R1="$J1/results/implement-plan-1-1.md"
RDESIGN="$(printf -- '---\ntype: design\njob: E1\n---\n\n# 받음 낡음 픽스처 설계\n\n## Goals\n\n- 받은 뒤의 변경을 센다.\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| C1 · S1 | 반영 | §1 |\n\n## Acceptance Criteria\n\n- AC1: 받은 뒤 바뀐 글을 센다\n- AC2: 되돌린 글은 세지 않는다\n\n## 미룸\n\n| 항목 | 이유 | 받는 곳 |\n|---|---|---|')"
RPLAN="$(printf '# 받음 낡음 픽스처 계획 1\n\n### Task 1: 견주기\n\nAC1 · AC2 를 만든다.')"
g checkout -q -b feature/tm-e1 main && put src/e1/a.txt a && step "받음 낡음: 코드 하나" || fail_step "받음 낡음: 코드 하나"
put "$J1/design.md" "$RDESIGN" && step "받음 낡음: 설계문서" || fail_step "받음 낡음: 설계문서"
approved "spec 승인" E1 - - 2026-11-20 && g push -q origin HEAD || fail_step "받음 낡음: 승인"
put "$J1/plan-1.md" "$RPLAN" && step "받음 낡음: 계획 파일" || fail_step "받음 낡음: 계획 파일"
approved "계획 검토" E1 1 - 2026-11-21 && g push -q origin HEAD || fail_step "받음 낡음: 계획 검토"
sync E1 implement-plan-1-1.md --role worker --bundle-at "$(g rev-parse origin/main)" --job-at "$(g rev-parse HEAD)" >/dev/null && step "받음 낡음: 결과 시작" || fail_step "받음 낡음: 결과 시작"
put src/e1/a.txt "끝난 코드" && g commit -qm "받음 낡음: 코드" && RCODE="$(g rev-parse HEAD)"
printf 'AC1: 구현됨 — src/e1/a.txt\nAC2: 구현됨 — src/e1/a.txt\n' >> "$W/$R1"
sync E1 implement-plan-1-1.md --end "$RCODE" >/dev/null && step "받음 낡음: 결과 끝" || fail_step "받음 낡음: 결과 끝"
RLINE="$(cd "$W" && python3 "$JRC" check --roadmap "$RM" --job E1 --result implement-plan-1-1.md --date 2026-11-22 | grep '^- 결과 받음 · ')"
decide E1 "$RLINE" && step "받음 낡음: 받음 줄" || fail_step "받음 낡음: 받음 줄"
RAT="$(g rev-parse HEAD)"

assert_eq "$(st E1)" "구현 끝" "r1: 받은 뒤 고침이 없으면 구현 끝(양성 대조)"
assert_not_contains "$(notes E1)" "받은 뒤 바뀜" "r1: 받은 뒤 바뀜 알림이 없다"
sub "$J1/design.md" "| 항목 | 이유 | 받는 곳 |
|---|---|---|" "| 항목 | 이유 | 받는 곳 |
|---|---|---|
| 알림 글 | 나중에 정한다 | plan-1.md |" && step "r2 미룸 절" || fail_step "r2 미룸 절"
assert_eq "$(st E1)" "구현 끝" "r2: 설계 파일의 미룸 절에 한 줄만 더하면 구현 끝 그대로"
assert_not_contains "$(notes E1)" "받은 뒤 바뀜" "r2: 미룸 절만 고친 설계 파일은 받은 뒤 바뀜이 아니다"
back "$RAT"
put src/e1/a.txt "받은 뒤 고친 코드" && step "r3 고침" || fail_step "r3 고침"
put src/e1/a.txt "끝난 코드" && step "r3 되돌림" || fail_step "r3 되돌림"
assert_eq "$(st E1)" "구현 끝" "r3: 예약 경로 파일을 고쳤다 되돌리면 구현 끝 그대로"
assert_not_contains "$(notes E1)" "받은 뒤 바뀜" "r3: 되돌린 파일은 받은 뒤 바뀜이 아니다"
back "$RAT"
sub "$J1/design.md" "- 받은 뒤의 변경을 센다." "- 받은 뒤의 변경을 다시 센다." && step "r4 설계 본문" || fail_step "r4 설계 본문"
assert_eq "$(st E1)" "설계 중" "r4: 설계 본문을 고치면 승인이 낡아 설계 중(AC8) — 받음 줄의 낡음은 아래 알림이 잰다"
assert_contains "$(notes E1)" "받은 뒤 바뀜: implement-plan-1-1.md — $J1/design.md" "r4: 알림에 받은 뒤 바뀜과 설계 파일 경로"
back "$RAT"
put src/e1/a.txt "받은 뒤 고친 코드" && step "r5 고침" || fail_step "r5 고침"
assert_eq "$(st E1)" "구현 중" "r5: 예약 경로 파일을 고치고 되돌리지 않으면 구현 중"
assert_contains "$(notes E1)" "받은 뒤 바뀜: implement-plan-1-1.md — src/e1/a.txt" "r5: 알림에 그 경로"
back "$RAT"
printf '끝난 코드\r\n' > "$W/src/e1/a.txt" && step "r6 줄바꿈만" || fail_step "r6 줄바꿈만"
assert_eq "$(st E1)" "구현 중" "r6: 줄바꿈만 바꾼 예약 경로 파일도 받은 뒤 바뀜이다(객체 번호로 견준다)"
assert_contains "$(notes E1)" "받은 뒤 바뀜: implement-plan-1-1.md — src/e1/a.txt" "r6: 알림에 그 경로"
back "$RAT"
printf '\377\n' > "$W/src/e1/a.txt" && g add -- src/e1/a.txt && g commit -qm "r7 바이트 하나" && printf '\376\n' > "$W/src/e1/a.txt" && step "r7 다른 바이트" || fail_step "r7 다른 바이트"
assert_eq "$(st E1)" "구현 중" "r7: 읽을 수 없는 바이트로 바뀐 예약 경로 파일(디코드하면 같아 보인다)도 받은 뒤 바뀜이다"
back "$RAT"
sub "$J1/INTENT.md" "## 결정 기록" "## 결정 기록 아님" && step "r8 결정 기록 칸 깨짐" || fail_step "r8 결정 기록 칸 깨짐"
assert_eq "$(st E1)" "설계 중" "r8: 설계 흐름 — 구현 결과 파일이 있어도 결정 기록 칸을 읽지 못하면 설계 중"
assert_contains "$(why E1)" "결정 기록 읽기 불가 — " "r8: 결정 기록 읽기 불가를 근거로 낸다"
back "$RAT"
use_repo "$T0"
finish
