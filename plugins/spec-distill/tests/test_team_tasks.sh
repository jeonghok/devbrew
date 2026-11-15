#!/usr/bin/env bash
# team_status.task_jobs — 로드맵 밖 과제(kind: task)를 기본 브랜치와 브랜치 끝에서 찾아 보고의 jobs · job_notes 에 따로 싣는다(AC14 · Q2 · Q10 · Q12 · Q14).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_team_tasks.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
. "$ROOT/plugins/spec-distill/tests/fixtures/team_repo.sh"
team_repo && ok "과제 찾기 픽스처 레포를 세웠다(${TM})" || { no "과제 찾기 픽스처 레포를 못 세웠다 — $(cat "$T/out.txt")"; finish; }
JRC="$S/job_results.py"
# create 가 roadmaps_dir 바로 아래에 깐 역할 문서 · HANDBOOK 은 픽스처가 올리지 않았다 — 기본 브랜치에 먼저 올린다
g add -A -- "$RD" && g commit -qm "역할 문서를 올린다" && g push -q origin main

jobs() { js "$T/s.json" "[(j['id'], j['stage'], j['branch']) for j in r['jobs']]"; }
jnotes() { js "$T/s.json" "' | '.join(r['job_notes'])"; }
jget() { js "$T/s.json" "[j for j in r['jobs'] if (j['id'], j['branch']) == ('$1', '$2')][0]['$3']"; }   # jget <과제> <브랜치> <칸>
RC=""
# 걸음이 실패하면 보고를 지운다 — 앞 걸음의 낡은 보고가 뒤 단언을 채우지 못하게
again() { rm -f "$T/s.json"; RC="$(status "$T/s.json")"; }
failed() { rm -f "$T/s.json"; RC="걸음 실패"; no "걸음 실패: $1"; }
newjob() {  # newjob <이름> <브랜치> [<머리에 적을 branch>] — main 에서 그 브랜치를 갈라 job new 를 돌리고 커밋한다
  local goal="$1 을 맡아 끝낸다" paths="docs/$1-only.md"
  if [ "$1" = fix-typo ]; then goal="오타 고치기"; paths="docs/a.md"; fi
  g checkout -q -b "$2" main || return 1
  printf '로드맵에 없는 일 하나 — %s\n' "$1" > "$T/said.txt"
  (cd "$W" && python3 "$RW" job new --roadmap "$RM" --name "$1" --branch "${3:-$2}" --paths "$paths" --goal "$goal" < "$T/said.txt") \
    > "$T/out.txt" 2>&1 || { cat "$T/out.txt"; return 1; }
  g add -- "$TM/jobs/$1" && g commit -qm "과제 폴더 $1"
}
bump() {  # bump <레포 상대 경로> <글> <커밋 메시지> — 지금 브랜치에 그 파일을 써서 커밋하고 올린 뒤 다시 계산한다
  put "$1" "$2" && g commit -qm "$3" && g push -q origin HEAD && again
}

# ── 처음에는 없다 ──────────────────────────────────────────────────────────
again
assert_eq "$(js "$T/s.json" "(r['jobs'], r['job_notes'])")" "([], [])" "과제: 처음에는 없다"
assert_eq "$RC" "0" "과제: 처음 상태의 종료 코드 0(아래 「종료 코드 그대로」 단언의 바탕)"
n_blocks="$(js "$T/s.json" "len(r['blocks'])")"

# ── 브랜치 끝에만 있는 과제 폴더 ───────────────────────────────────────────
newjob fix-typo fix/typo && g push -q origin fix/typo && again || failed "fix/typo"
assert_eq "$(jobs)" "[('fix-typo', '진행 중', 'fix/typo')]" "AC14: 브랜치 끝에만 있는 과제 폴더를 찾는다"
assert_eq "$(js "$T/s.json" "[(j['kind'], j['task_status'], j['intent'], j['title']) for j in r['jobs']]")" "[('task', 'in_progress', '$TM/jobs/fix-typo/INTENT.md', '오타 고치기')]" "AC14: 과제의 칸"
assert_eq "$(jget fix-typo fix/typo reason) · $(jget fix-typo fix/typo tip) · $(jget fix-typo fix/typo notes) · $(jget fix-typo fix/typo progress)" \
  "브랜치 있음 · $(g rev-parse fix/typo) · [] · None" "AC14: 진행 중의 근거 · 읽은 끝 · 알림 없음 · 진행 칸(설계 없는 흐름은 비어 있다)"
assert_eq "$(js "$T/s.json" "len(r['blocks'])")" "$n_blocks" "AC14: 에픽 목록과 따로다 — 블록 수는 그대로"
assert_not_contains "$(js "$T/s.json" "[b['id'] for b in r['blocks']]")" "fix-typo" "AC14: 블록 목록에 과제가 섞이지 않는다"

# ── 머리 branch 가 다른 브랜치를 가리키는 사본은 조용히 건너뛴다 ────────────
g checkout -q -b fix/typo-copy fix/typo && put note.txt n && g commit -qm copy && g push -q origin fix/typo-copy && again || failed "fix/typo-copy"
assert_eq "$(jobs) · $(jnotes)" "[('fix-typo', '진행 중', 'fix/typo')] · " "과제: 다른 브랜치의 사본은 조용히 건너뛴다(한 번만 센다)"

# ── 머리 branch 와 이름이 맞는 브랜치에 그 과제 폴더가 없다 — 세 갈래 ─────────
newjob wrong fix/wrong-name fix/absent && g push -q origin fix/wrong-name && again || failed "fix/wrong-name"
assert_not_contains "$(jobs)" "wrong" "AC14: 머리의 branch 가 그 브랜치와 다르면 세지 않는다"
assert_contains "$(jnotes)" "로드맵 밖 과제 wrong 을 세지 않았다 — 머리의 branch(fix/absent)" "AC14: 세지 않은 것을 알린다"
assert_eq "$(js "$T/s.json" "r['exit']")" "0" "과제: 알림은 종료 코드를 바꾸지 않는다"
newjob stray fix/stray fix/typo && g push -q origin fix/stray && again || failed "fix/stray"
assert_contains "$(jnotes)" "로드맵 밖 과제 stray 을 세지 않았다 — 머리의 branch(fix/typo) 와 이름이 맞는 브랜치에 이 과제 폴더가 없다" \
  "과제: 머리가 가리키는 브랜치는 있는데 그 끝에 이 과제 폴더가 없으면 세지 않고 알린다"
assert_eq "$(jobs)" "[('fix-typo', '진행 중', 'fix/typo')]" "과제: 그 브랜치의 과제 폴더(stray)는 세지 않는다"
newjob moved fix/moved-a fix/moved-b && g push -q origin fix/moved-a || failed "fix/moved-a"
g checkout -q -b fix/moved-b fix/moved-a && python3 - "$W/$TM/jobs/moved/INTENT.md" <<'PY' && g add -A -- "$TM" && g commit -qm "머리를 또 옮김" && g push -q origin fix/moved-b && again || failed "fix/moved-b"
import sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
if t.count("branch: fix/moved-b\n") != 1:
    sys.exit("머리 branch 줄이 한 번 나오지 않는다")
open(p, "w", encoding="utf-8").write(t.replace("branch: fix/moved-b\n", "branch: fix/moved-c\n"))
PY
assert_contains "$(jnotes)" "로드맵 밖 과제 moved 을 세지 않았다 — 머리의 branch(fix/moved-b) 와" "과제: 머리가 가리키는 브랜치의 끝에서 머리가 또 다른 브랜치를 가리키면 세지 않는다"
assert_contains "$(jnotes)" "로드맵 밖 과제 moved 을 세지 않았다 — 머리의 branch(fix/moved-c) 와" "과제: 그 다른 브랜치가 없으면 그것도 알린다"
assert_not_contains "$(jobs)" "moved" "과제: 머리가 어긋난 과제는 jobs 에 없다"
assert_eq "$(js "$T/s.json" "r['exit']")" "0" "과제: 세지 않은 알림 셋이 있어도 종료 코드 그대로"
g checkout -q main && g branch -q -D fix/wrong-name fix/stray fix/moved-a fix/moved-b \
  && g push -q origin --delete fix/wrong-name fix/stray fix/moved-a fix/moved-b && again || failed "알림 브랜치 지움"
assert_eq "$(jobs) · $(jnotes)" "[('fix-typo', '진행 중', 'fix/typo')] · " "과제: 그 브랜치들을 지우면 알림도 사라진다(위 알림 단언들의 양의 짝)"

# ── 로컬에만 있는 브랜치 — 싣고 「아직 안 올라옴」 ─────────────────────────
newjob solo fix/solo && again || failed "fix/solo"
assert_contains "$(jobs)" "('solo', '진행 중', 'fix/solo')" "과제: 한 번도 올리지 않은 로컬 브랜치의 과제도 싣는다"
assert_contains "$(jget solo fix/solo notes)" "아직 안 올라옴 — fix/solo 의 로컬 끝" "과제: 로컬에만 있으면 그 과제의 notes 에 「아직 안 올라옴」"

# ── 갈라진 브랜치 — 싣지 않고 알림 한 줄(Q10) ──────────────────────────────
newjob split fix/split && g push -q origin fix/split || failed "fix/split"
g checkout -q -b t/split-remote fix/split && put docs/split-remote.md r && g commit -qm "origin 쪽 커밋" \
  && g push -q origin t/split-remote:fix/split && g checkout -q fix/split && g branch -q -D t/split-remote \
  && put docs/split-local.md l && g commit -qm "로컬 쪽 커밋" && again || failed "갈라짐"
assert_not_contains "$(jobs)" "split" "Q10: 갈라진 브랜치의 과제는 jobs 에 없다"
assert_contains "$(jnotes)" "로드맵 밖 과제 split: 갈라짐 — " "Q10: 「갈라짐」 알림 한 줄"
assert_eq "$(js "$T/s.json" "sum(1 for n in r['job_notes'] if n.startswith('로드맵 밖 과제 split'))")" "1" "Q10: 로컬 · origin 두 끝이 같은 과제를 가리켜도 알림은 한 번"
assert_eq "$(js "$T/s.json" "r['exit']")" "0" "Q10: 갈라짐 알림은 종료 코드를 바꾸지 않는다"

# ── 결과 받음 — 대조를 통과한 받음 줄이면 「결과 받음」, 받은 뒤 바뀌면 「진행 중」(Q6 · Q12) ──
g checkout -q fix/typo && put docs/a.md "오타를 고친 문서" && g commit -qm "오타 고침" && CODE="$(g rev-parse HEAD)" || failed "오타 고침"
assert_eq "$(sync fix-typo implement-1.md --role worker --bundle-at "$(g rev-parse origin/main)" --job-at "$CODE")" "0" "결과: job sync 로 결과 파일을 연다"
printf '산출물: docs/a.md\n' >> "$W/$TM/jobs/fix-typo/results/implement-1.md"
assert_eq "$(sync fix-typo implement-1.md --end "$CODE")" "0" "결과: job sync --end 로 끝 줄을 단다"
g add -- "$TM/jobs/fix-typo" && g commit -qm "결과 파일" && g push -q origin fix/typo && again || failed "결과 파일"
assert_eq "$(jget fix-typo fix/typo stage)" "진행 중" "결과: 받음 줄 전에는 진행 중"
assert_contains "$(jget fix-typo fix/typo notes)" "결과 있음 · 받음 없음: implement-1.md(대조를 기다린다)" "결과: 과제에도 받음 없음 알림(블록과 같은 함수)"
LINE="$(cd "$W" && python3 "$JRC" check --roadmap "$RM" --job fix-typo --result implement-1.md --branch fix/typo --date 2026-11-27 | grep '^- 결과 받음 · ')"
assert_contains "$LINE" "- 결과 받음 · 2026-11-27 · 「implement-1.md · $CODE · 결과 대조: 통과 — " "결과: 대조가 과제의 받음 줄을 낸다"
decide fix-typo "$LINE" && g add -- "$TM/jobs/fix-typo" && g commit -qm "받음 줄" && g push -q origin fix/typo && again || failed "받음 줄"
assert_eq "$(jobs)" "[('fix-typo', '결과 받음', 'fix/typo'), ('solo', '진행 중', 'fix/solo')]" "Q12: 받음 줄이 대조를 통과하면 결과 받음"
assert_eq "$(jget fix-typo fix/typo reason) · $(jget fix-typo fix/typo task_status)" "결과 받음 줄 있음: implement-1.md · in_progress" "Q12: 결과 받음의 근거 · 작업 상태는 진행 중"
assert_not_contains "$(jget fix-typo fix/typo notes)" "받음 없음" "결과: 받은 뒤에는 받음 없음 알림이 없다"
bump docs/a.md "오타를 또 고친 문서" "받은 뒤 또 고침" || failed "받은 뒤 또 고침"
assert_eq "$(jget fix-typo fix/typo stage)" "진행 중" "Q6: 설계 없는 과제도 받은 뒤 고칠 자리가 바뀌면 진행 중"
assert_contains "$(jget fix-typo fix/typo notes)" "받은 뒤 바뀜: implement-1.md — docs/a.md" "Q6: 받은 뒤 바뀜 알림"

# ── 머지됨 — 과제 폴더가 기본 브랜치에 있다 ────────────────────────────────
g checkout -q main && g merge -q --no-ff --no-edit fix/typo && g push -q origin main && again || failed "fix/typo 합치기"
assert_contains "$(jobs)" "('fix-typo', '머지됨', 'fix/typo')" "Q12: 과제 폴더가 기본 브랜치에 있으면 머지됨"
assert_eq "$(jget fix-typo fix/typo reason) · $(jget fix-typo fix/typo task_status) · $(jget fix-typo fix/typo tip) · $(jget fix-typo fix/typo title)" \
  "기본 브랜치에 있음 · completed · None · 오타 고치기" "Q12: 머지됨의 근거 · 작업 상태 · 끝 없음 · 제목은 기본 브랜치의 목표 칸"
assert_eq "$(js "$T/s.json" "sum(1 for j in r['jobs'] if j['id'] == 'fix-typo')")" "1" "Q2: 머지된 과제는 남은 사본 브랜치(fix/typo-copy)에서 또 세지 않는다"

# ── 같은 과제 이름 두 브랜치 — 둘 다 싣고 알린다 ───────────────────────────
newjob dup fix/dup-a && g push -q origin fix/dup-a && newjob dup fix/dup-b && g push -q origin fix/dup-b && again || failed "dup 둘"
assert_contains "$(jobs)" "('dup', '진행 중', 'fix/dup-a'), ('dup', '진행 중', 'fix/dup-b')" "과제: 같은 이름이 두 브랜치에서 실리면 둘 다 싣는다"
assert_contains "$(jnotes)" "로드맵 밖 과제 이름이 겹친다: dup — fix/dup-a · fix/dup-b" "과제: 이름 겹침을 알린다"
assert_not_contains "$(jnotes)" "이름이 겹친다: fix-typo" "과제: 한 브랜치에서만 실린 과제는 겹친다고 알리지 않는다(양의 짝)"

# ── 옛 형식 로드맵의 보고에는 jobs · job_notes 가 없다(Q14 · AC13) — 과제 브랜치가 여럿 있는 지금 잰다 ──
OLD="${RD}old-shape"
mkdir -p "$W/$OLD"
printf -- '---\ntype: roadmap\nsource_brief: docs/tv/brief.md\n---\n\n# 옛 꼴 대조\n\n## 에픽\n\n### E1 — 옛 꼴 하나\n- 의도: 옛 형식 보고를 본다\n- 범위:\n  - 한다: 보기\n  - 안 한다: 바꾸기\n- 의존: 없음\n- 브랜치: feature/old-e1\n- 묶음: E1.md\n- 경로 예약: 없음\n\n## 결정 기록\n\n## 재분해 이력\n\n### 2026-11-03 · 옛 꼴로 씀\n- 원문:\n  - 「옛 꼴을 손으로 쓴다」\n' \
  > "$W/$OLD/roadmap.md"
printf -- '---\ntype: epic-bundle\nepic: E1\nroadmap: %s\nsource_brief: docs/tv/brief.md\nids: [C1, D2, C3, OQ1, S1, S2, S3, S4]\n---\n\n# E1\n' "$OLD/roadmap.md" > "$W/$OLD/E1.md"
OLD_RC=0; (cd "$W" && python3 "$RS" --roadmap-file "$OLD/roadmap.md" --json) > "$T/old.json" 2>/dev/null || OLD_RC=$?
assert_eq "${OLD_RC} · $(js "$T/old.json" "(r['format_errors'], r['unknown_reasons'], [b['stage'] for b in r['blocks']])")" "0 · ([], [], ['준비'])" \
  "Q14: 옛 형식 로드맵을 끝까지 계산했다(아래 단언의 바탕)"
assert_eq "$(js "$T/old.json" "('jobs' in r, 'job_notes' in r, 'layout' in r)")" "(False, False, False)" "Q14: 옛 형식의 보고에는 jobs · job_notes 칸이 없다"
rm -rf "$W/$OLD"

# ── 블록 없는 에픽 폴더(kind: epic) — 브랜치에서도 기본 브랜치에서도 과제가 아니다 ──
EPIC="$(printf -- '---\ntype: job\njob: E9\nkind: epic\nroadmap: %s\nbranch: fix/epic-x\npaths: [src/e9/]\n---\n\n## 목표\n\n블록이 없는 에픽 폴더' "$RM")"
g checkout -q -b fix/epic-x main && bump "$TM/jobs/E9/INTENT.md" "$EPIC" "블록 없는 에픽 폴더" || failed "fix/epic-x"
assert_not_contains "$(jobs)" "E9" "과제: 브랜치에만 있는 kind: epic 폴더는 jobs 에 없다"
assert_not_contains "$(jnotes)" "E9" "과제: kind: epic 폴더는 알림도 없다(나무 검사의 몫)"
g checkout -q main && g merge -q --no-ff --no-edit fix/epic-x && g push -q origin main && again || failed "fix/epic-x 합치기"
assert_not_contains "$(jobs) $(jnotes)" "E9" "과제: 기본 브랜치의 kind: epic 폴더도 과제가 아니다"
assert_contains "$(jobs)" "('fix-typo', '머지됨', 'fix/typo')" "과제: 같은 기본 브랜치의 kind: task 폴더는 머지됨(위 단언의 양의 짝)"

# ── INTENT.md 가 없는 폴더 · 머리가 깨진 INTENT.md · 읽지 못하는 INTENT.md ──
g checkout -q -b fix/broken main && put "$TM/jobs/loose/memo.txt" "INTENT 없는 폴더" \
  && bump "$TM/jobs/broken/INTENT.md" "$(printf -- '---\ntype: job\nkind: task\nbranch: fix/broken')" "머리가 닫히지 않은 과제" || failed "fix/broken"
assert_contains "$(jnotes)" "로드맵 밖 과제 broken 을 세지 못했다 — " "과제: 브랜치 끝의 INTENT.md 머리가 깨지면 세지 못했다고 알린다"
assert_not_contains "$(jobs)" "broken" "과제: 머리가 깨진 과제는 jobs 에 없다"
assert_not_contains "$(jobs) $(jnotes)" "loose" "과제: INTENT.md 가 없는(확인된 없음) 폴더는 과제가 아니다 — 알림도 없다"
g checkout -q -b fix/broken-copy fix/broken && bump docs/broken-copy.md c "깨진 과제의 사본" || failed "fix/broken-copy"
assert_eq "$(js "$T/s.json" "sum(1 for n in r['job_notes'] if n.startswith('로드맵 밖 과제 broken 을 세지 못했다'))")" "1" \
  "과제: 같은 깨진 폴더를 가진 브랜치 끝이 둘이어도 알림은 한 번"
g checkout -q main && g branch -q -D fix/broken-copy && g push -q origin --delete fix/broken-copy || failed "fix/broken-copy 지움"
g checkout -q main && g merge -q --no-ff --no-edit fix/broken && put "$TM/jobs/dirint/INTENT.md/x.txt" "폴더인 INTENT" \
  && g commit -qm "폴더인 INTENT" && g push -q origin main && again || failed "fix/broken 합치기"
assert_contains "$(jnotes)" "로드맵 밖 과제 broken 을 세지 못했다 — $TM/jobs/broken/INTENT.md 머리를 읽지 못했다" "과제: 기본 브랜치의 깨진 머리도 알린다"
assert_contains "$(jnotes)" "로드맵 밖 과제 dirint 을 세지 못했다 — $TM/jobs/dirint/INTENT.md 를 읽지 못했다" "과제: 있는데 읽지 못하는 INTENT.md 는 세지 못했다고 알린다"
assert_not_contains "$(jobs) $(jnotes)" "loose" "과제: 기본 브랜치의 INTENT.md 없는 폴더도 조용히 건너뛴다"
assert_eq "$RC" "0" "과제: 세지 못한 알림도 종료 코드를 바꾸지 않는다"

# ── git 이 실패한 자리 — 가짜 Git 으로 이름 목록 · 브랜치 끝 목록을 막는다: 세지 못했다고 알리고 없음으로 내지 않는다 ──
python3 - "$S" "$W" "$RD" "$RM" > "$T/shut.txt" 2>&1 <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import roadmap_status, team_layout, team_status
from roadmap_model import parse_roadmap
root, rd, rm = sys.argv[2:5]
team = team_layout.team_from_roadmap(rd, rm)
real = roadmap_status.Git(root)
main = real.commit("refs/remotes/origin/HEAD")
blocks = parse_roadmap(real.blob(main, rm))[1]


class Shut(roadmap_status.Git):
    """where — main: 기본 브랜치의 이름 목록 · tip: 브랜치 끝의 이름 목록 · list: 브랜치 끝 목록을 읽지 못한다."""
    def __init__(self, cwd, where):
        super().__init__(cwd)
        self.where = where

    def names(self, rev, folder):
        if (self.where == "main" and rev == main) or (self.where == "tip" and rev != main):
            return None
        return super().names(rev, folder)

    def unmerged_tips(self, base):
        if self.where == "list":
            self.fail("log", 128, "fatal: 끝 목록 막힘")
            return []
        return super().unmerged_tips(base)


for where in ("main", "tip", "list"):
    jobs, notes = team_status.task_jobs(team_status.Reader(Shut(root, where), main, team, lambda p: None), blocks)
    print("%s | %s | %s" % (where, [(j["id"], j["stage"]) for j in jobs], " / ".join(notes)))
PY
assert_contains "$(cat "$T/shut.txt")" "main | [] | 로드맵 밖 과제를 세지 못했다 — 기본 브랜치의 $TM/jobs 를 읽지 못했다" "git 실패: 기본 브랜치의 과제 폴더 이름을 못 읽으면 세지 못했다고 한 줄"
assert_grep "$(cat "$T/shut.txt")" "^tip \| \[\('fix-typo', '머지됨'\)\] \| .*로드맵 밖 과제를 다 세지 못했다 — 브랜치 끝 [0-9a-f]{8} 의 $TM/jobs 를 읽지 못했다" \
  "git 실패: 브랜치 끝의 이름 목록을 못 읽으면 그 끝을 알리고 기본 브랜치의 과제는 그대로 싣는다"
assert_grep "$(cat "$T/shut.txt")" "^list \| \[\('fix-typo', '머지됨'\)\] \| .*로드맵 밖 과제를 다 세지 못했다 — 기본 브랜치에 들어가지 않은 브랜치 끝을 읽지 못했다" \
  "git 실패: 브랜치 끝 목록을 못 읽으면 다 세지 못했다고 알린다"
assert_not_contains "$(cat "$T/shut.txt")" "Traceback" "git 실패: 죽지 않는다"

# ── 얕은 클론 — 브랜치의 과제는 단계를 셀 이력이 없다: 「알 수 없음」 · 머지된 과제는 머지됨 ──
SH="$T/shallow"
git clone -q --no-local --depth 1 --no-single-branch "file://$T/origin.git" "$SH" && git -C "$SH" remote set-head origin main \
  || no "얕은 클론을 만들지 못했다"
assert_eq "$(git -C "$SH" rev-parse --is-shallow-repository)" "true" "얕은 클론: 픽스처가 정말 얕은 클론이다"
SH_RC=0; (cd "$SH" && python3 "$RS" "$RM" --json) > "$T/shallow.json" 2> "$T/shallow.err" || SH_RC=$?
assert_eq "$(js "$T/shallow.json" "sorted(set((j['stage'], j['task_status']) for j in r['jobs'] if j['id'] != 'fix-typo'))")" "[('알 수 없음', None)]" \
  "얕은 클론: 브랜치의 과제는 단계 「알 수 없음」 · 작업 상태 없음(자신 있는 단계를 내지 않는다)"
assert_contains "$(js "$T/shallow.json" "[j['reason'] for j in r['jobs'] if j['id'] == 'dup']")" "얕은 클론이라" "얕은 클론: 그 사유"
assert_contains "$(js "$T/shallow.json" "[(j['id'], j['stage'], j['branch']) for j in r['jobs']]")" "('dup', '알 수 없음', 'fix/dup-a')" "얕은 클론: 과제는 목록에 있다(없다고 하지 않는다)"
assert_contains "$(js "$T/shallow.json" "[(j['id'], j['stage']) for j in r['jobs']]")" "('fix-typo', '머지됨')" "얕은 클론: 기본 브랜치의 과제는 트리로 알 수 있어 머지됨"
assert_not_contains "$(cat "$T/shallow.err")" "Traceback" "얕은 클론: 죽지 않는다"

# ── 기본 브랜치를 모르는 레포 — 과제를 세지 못했다고 한 줄 ─────────────────
g remote set-head origin -d
NO_RC=0; (cd "$W" && python3 "$RS" --roadmap-file "$RM" --json) > "$T/s.json" 2>/dev/null || NO_RC=$?
assert_eq "${NO_RC} · $(js "$T/s.json" "(r['jobs'], r['job_notes'])")" "3 · ([], ['로드맵 밖 과제를 세지 못했다 — 기본 브랜치를 모른다'])" \
  "기본 브랜치 모름: jobs 는 비고 세지 못했다는 알림 한 줄(없음이라 하지 않는다) · 종료 코드는 블록 규칙대로 3"
g remote set-head origin main

g checkout -q main
assert_eq "$(g status --porcelain --untracked-files=all)" "" "끝 상태: 작업 트리가 깨끗하다"
assert_eq "$(g symbolic-ref -q refs/remotes/origin/HEAD)" "refs/remotes/origin/main" "끝 상태: origin/HEAD 는 main"

finish
