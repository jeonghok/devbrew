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
claim || { no "지휘 표지를 쥐지 못했다 — $(cat "$T/led.txt")"; finish; }   # 결과 대조가 사람 줄(흐름 승인)을 본다(과제 11)

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
assert_eq "$(jget fix-typo fix/typo tip)" "$(g rev-parse fix/typo)" "Q2: 사본이 생긴 뒤에도 과제의 끝은 머리 branch(fix/typo)의 끝이다 — 사본의 끝이 아니다"

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
# 막힘 파일(Q7 — 「막힘」 은 막힘 파일 하나로만 알린다) — 단계는 그대로이고 그 과제의 notes 에 막힘 한 줄
SOLO_BLK="$TM/jobs/solo/results/BLOCKED.md"
put "$SOLO_BLK" "$(printf -- '---\ntype: job-blocked\nstage: implement\nattempt: 1\nhead: %s\n---\n\n## 무엇에 막혔나\n\n로드맵 밖 일의 답을 기다린다.\n\n## 풀려면 무엇이 필요한가\n\n리더가 범위를 정해 준다.' "$(g rev-parse HEAD)")" \
  && g commit -qm "막힌 과제" && again || failed "solo 막힘"
assert_eq "$(jget solo fix/solo stage) · $(jget solo fix/solo task_status)" "진행 중 · in_progress" "Q7: 막힘 파일이 있어도 과제의 단계는 그대로 진행 중"
assert_contains "$(jget solo fix/solo notes)" "막힘: implement 시도 1 — $SOLO_BLK" "Q7: 과제의 notes 에 막힘 한 줄(블록과 같은 함수)"
assert_eq "$(js "$T/s.json" "r['exit']")" "0" "Q7: 막힘은 과제의 사정이라 종료 코드를 바꾸지 않는다"
# 결과 파일이 있는데 결정 기록 칸을 못 찾는 과제 — 단계는 Reader.progress 그대로(진행 중 · 그 사유)이고 「결과 받음인지 셀 수 없다」 한 줄을 job_notes 에
# (결과 파일이 없으면 받음 줄을 볼 일이 없어 단계가 진행 중으로 확실하다 — 결과 파일을 먼저 연다)
newjob norec fix/norec && [ "$(sync norec implement-1.md --role worker --bundle-at "$(g rev-parse origin/main)" --job-at "$(g rev-parse HEAD)")" = 0 ] \
  && python3 - "$W/$TM/jobs/norec/INTENT.md" <<'PY' && g add -A -- "$TM" && g commit -qm "결정 기록 칸 깨짐" && g push -q origin fix/norec && again || failed "fix/norec"
import sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
if t.count("\n## 결정 기록") != 1:
    sys.exit("결정 기록 제목이 한 번 나오지 않는다")
open(p, "w", encoding="utf-8").write(t.replace("\n## 결정 기록", "\n## 결정 기록이 아닌 칸"))
PY
assert_eq "$(jget norec fix/norec stage) · $(jget norec fix/norec task_status)" "진행 중 · in_progress" "과제: 결정 기록을 못 읽은 과제의 단계는 블록과 같다(진행 중 — 작업 상태는 진행 중이든 결과 받음이든 in_progress)"
assert_contains "$(jget norec fix/norec reason)" "결정 기록 읽기 불가 — " "과제: 그 근거는 결정 기록 읽기 불가"
assert_contains "$(jnotes)" "로드맵 밖 과제 norec: $TM/jobs/norec/INTENT.md 의 결정 기록을 읽지 못해 결과 받음인지 셀 수 없다 — " \
  "과제: 결정 기록을 못 읽으면 결과 받음인지 셀 수 없다고 알린다(자신 있는 진행 중으로만 내지 않는다)"
assert_not_contains "$(jnotes)" "로드맵 밖 과제 solo:" "과제: 결정 기록을 읽은 과제에는 그 알림이 없다(양의 짝)"
# 머리에 branch 키가 없는 과제 — 세지 않고 그 사실을 알린다
newjob nobr fix/nobr && grep -v '^branch: ' "$W/$TM/jobs/nobr/INTENT.md" > "$T/nobr.md" && mv "$T/nobr.md" "$W/$TM/jobs/nobr/INTENT.md" \
  && g add -A -- "$TM" && g commit -qm "머리 branch 없음" && g push -q origin fix/nobr && again || failed "fix/nobr"
assert_not_contains "$(jobs)" "nobr" "과제: 머리에 branch 가 없는 과제는 세지 않는다"
assert_contains "$(jnotes)" "로드맵 밖 과제 nobr 을 세지 않았다 — 머리에 branch 가 없다" "과제: 머리에 branch 가 없다고 알린다"
# 머리가 가리키는 브랜치에 폴더는 있는데 그 INTENT.md 머리가 깨졌다 — 「폴더가 없다」 가 아니라 진짜 사유를 한 번
newjob hb fix/hb-a fix/hb-b && g push -q origin fix/hb-a && g checkout -q -b fix/hb-b fix/hb-a \
  && printf -- '---\ntype: job\nkind: task\nbranch: fix/hb-b\n' > "$W/$TM/jobs/hb/INTENT.md" && g add -A -- "$TM" && g commit -qm "머리 깨짐" \
  && g push -q origin fix/hb-b && again || failed "fix/hb-b"
assert_not_contains "$(jnotes)" "로드맵 밖 과제 hb 을 세지 않았다" "과제: 머리가 가리키는 끝에 폴더가 있으면 「이 과제 폴더가 없다」 고 하지 않는다"
assert_eq "$(js "$T/s.json" "[n for n in r['job_notes'] if n.startswith('로드맵 밖 과제 hb ')]")" "['로드맵 밖 과제 hb 을 세지 못했다 — $TM/jobs/hb/INTENT.md 머리를 읽지 못했다 — INTENT 머리말이 닫히지 않았다']" \
  "과제: 그 끝의 INTENT.md 를 읽지 못한 진짜 사유를 한 번 낸다"
g checkout -q main && g branch -q -D fix/norec fix/nobr fix/hb-a fix/hb-b && g push -q origin --delete fix/norec fix/nobr fix/hb-a fix/hb-b || failed "fix-round 브랜치 지움"

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
approved "흐름 승인" fix-typo - - 2026-11-26 && g push -q origin fix/typo && again || failed "fix-typo 흐름 승인"
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

# ── 단순 작업의 예약 밖 변경 · 경로 예약 위반(AC11 · 설계 §10) — 블록과 같은 판정 · 종료 코드 그대로 ──
# 고칠 자리는 머리 paths(docs/reach-only.md). 자기 paths · 자기 과제 폴더 · 공유 파일만 바꾸면 알림이 없다
newjob reach fix/reach && put docs/reach-only.md "자기 고칠 자리" && put "$TM/jobs/reach/memo.md" "자기 과제 폴더의 메모" \
  && put docs/README.md "공유 파일" && put src/e1/README.md "다른 에픽의 예약 안에 있는 공유 파일" && g commit -qm "자기 자리만" && g push -q origin fix/reach && again || failed "fix/reach"
REACH_RC="$RC"
assert_eq "$(jget reach fix/reach stage) · $(jget reach fix/reach notes)" "진행 중 · []" \
  "AC11: 단순 작업이 자기 paths · 자기 과제 폴더 · 공유 파일만 바꾸면 예약 알림이 없다(아래 단언들의 양의 짝)"
bump docs/free.md "아무도 예약하지 않은 파일" "예약 밖 파일" && bump "$TM/RULES.md" "# 팀 규칙에 손댐" "팀 폴더의 다른 파일" \
  && bump src/e1/steal.txt "E1 이 예약한 자리" "다른 에픽의 자리" || failed "fix/reach 예약 밖"
assert_eq "$(js "$T/s.json" "[n for n in [j for j in r['jobs'] if j['id']=='reach'][0]['notes'] if '예약' in n]")" \
  "['경로 예약 위반: src/e1/steal.txt 은 E1 만 예약했다', '예약 밖 변경: docs/free.md · $TM/RULES.md']" \
  "AC11: 단순 작업이 다른 에픽의 예약을 바꾸면 경로 예약 위반 · 예약 밖 파일과 팀 폴더의 다른 파일은 예약 밖 변경(블록과 같은 글)"
assert_eq "$RC" "$REACH_RC" "AC11: 단순 작업의 예약 알림은 종료 코드를 바꾸지 않는다"
assert_not_contains "$(jnotes)" "예약" "AC11: 예약 알림은 그 과제의 notes 에 있다 — 세지 못한 사정(job_notes)이 아니다"
assert_not_contains "$(js "$T/s.json" "[n for b in r['blocks'] for n in b['notes']]")" "steal.txt" "AC11: 과제의 변경을 블록의 알림으로 내지 않는다"
(cd "$W" && python3 "$S/control_plane.py" show "$RM") > "$T/reach-show.txt" 2>&1
assert_contains "$(sed -n '/^로드맵 밖 과제:$/,$p' "$T/reach-show.txt")" "        정보: 예약 밖 변경: docs/free.md · $TM/RULES.md" \
  "AC11: 현황의 로드맵 밖 과제 절에 그 과제 아래 「정보:」 줄로 보인다"
g checkout -q main && g branch -q -D fix/reach && g push -q origin --delete fix/reach && again || failed "fix/reach 지움"
# 머리 paths 가 다른 에픽의 예약과 겹치면 그 자리는 자기 고칠 자리다 — 블록끼리의 겹침처럼 위반으로 내지 않는다
g checkout -q -b fix/overlap main && printf '에픽 자리 하나를 같이 고친다\n' > "$T/said.txt" \
  && (cd "$W" && python3 "$RW" job new --roadmap "$RM" --name overlap --branch fix/overlap --paths src/e3/own.txt --goal "겹친 자리" < "$T/said.txt") > "$T/out.txt" 2>&1 \
  && g add -- "$TM/jobs/overlap" && g commit -qm "과제 폴더 overlap" && bump src/e3/own.txt "E3 도 예약한 자리" "겹친 자리 고침" || failed "fix/overlap — $(cat "$T/out.txt")"
assert_eq "$(jget overlap fix/overlap notes)" "[]" "AC11: 머리 paths 가 다른 에픽의 예약과 겹친 자리를 바꾸면 경로 예약 위반이 아니다(자기 고칠 자리)"
g checkout -q main && g branch -q -D fix/overlap && g push -q origin --delete fix/overlap && again || failed "fix/overlap 지움"
# 예약 밖 변경 줄임(R3 Q2) — 단순 작업도 블록과 같은 글: 다섯이면 다섯 그대로, 넘으면 이름 순 앞 다섯과 「외 n개」
newjob wide fix/wide && put docs/w-a.md a && put docs/w-b.md b && put docs/w-c.md c && put docs/w-d.md d && put docs/w-e.md e \
  && g commit -qm "예약 밖 다섯" && g push -q origin fix/wide && again || failed "fix/wide 다섯"
assert_eq "$(jget wide fix/wide notes)" "['예약 밖 변경: docs/w-a.md · docs/w-b.md · docs/w-c.md · docs/w-d.md · docs/w-e.md']" "Q2: 단순 작업의 예약 밖 파일이 다섯이면 다섯 그대로"
put docs/w-0.md 0 && bump docs/w-z.md z "예약 밖 일곱" || failed "fix/wide 일곱"
assert_eq "$(jget wide fix/wide notes)" "['예약 밖 변경: docs/w-0.md · docs/w-a.md · docs/w-b.md · docs/w-c.md · docs/w-d.md 외 2개']" \
  "Q2: 단순 작업의 예약 밖 파일이 일곱이면 이름 순 앞 다섯과 「외 2개」"
g checkout -q main && g branch -q -D fix/wide && g push -q origin --delete fix/wide && again || failed "fix/wide 지움"

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
assert_eq "$(js "$T/old.json" "[(b['id'], b.get('job_folder', '칸 없음')) for b in r['blocks']]")" "[('E1', '칸 없음')]" "AC20: 옛 형식 보고의 블록에는 job_folder 칸이 없다(블록 하나를 본다)"
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

# ── git 이 실패한 자리 — 가짜 Git 으로 과제 폴더 이름 목록 · 브랜치 끝 목록을 막는다: 읽지 못함은 검사 불가(3)와 사유 ──
# (리더 결정 — 과제의 사정은 알림 · 읽지 못함은 검사 불가)
python3 - "$S" "$W" "$RD" "$RM" > "$T/shut.txt" 2>&1 <<'PY'
import argparse, sys
sys.path.insert(0, sys.argv[1])
import roadmap_status, team_layout
root, rd, rm = sys.argv[2:5]
jobs_dir = team_layout.team_from_roadmap(rd, rm).jobs
main = roadmap_status.Git(root).commit("refs/remotes/origin/HEAD")


class Shut(roadmap_status.Git):
    """where — main: 기본 브랜치의 과제 폴더 이름 목록 · tip: 브랜치 끝의 과제 폴더 이름 목록 · list: 브랜치 끝 목록을
    읽지 못한다(진짜 Git 처럼 failures 에 남긴다). none: 막지 않는다(양성 대조)."""
    def __init__(self, cwd, where):
        super().__init__(cwd)
        self.where = where

    def names(self, rev, folder):
        if folder == jobs_dir and ((self.where == "main" and rev == main) or (self.where == "tip" and rev != main)):
            self.fail("ls-tree", 128, "fatal: 이름 목록 막힘")
            return None
        return super().names(rev, folder)

    def unmerged_tips(self, base):
        if self.where == "list":
            self.fail("log", 128, "fatal: 끝 목록 막힘")
            return []
        return super().unmerged_tips(base)


for where in ("none", "main", "tip", "list"):
    report = roadmap_status.build(Shut(root, where), argparse.Namespace(roadmap=rm, roadmap_file=None, json=True))
    print("%s | rc %d | %s | %s | %s" % (where, roadmap_status.exit_code(report), " / ".join(report["unknown_reasons"]),
                                        [(j["id"], j["stage"]) for j in report["jobs"]], " / ".join(report["job_notes"])))
PY
assert_grep "$(cat "$T/shut.txt")" "^none \| rc 0 \|  \| " "git 실패: 양성 대조 — 막지 않으면 종료 코드 0 · 검사 불가 사유 없음"
assert_contains "$(cat "$T/shut.txt")" "main | rc 3 | git 읽기 실패 — git ls-tree 실패(rc 128): fatal: 이름 목록 막힘 | [] | 로드맵 밖 과제를 세지 못했다 — 기본 브랜치의 $TM/jobs 를 읽지 못했다" \
  "git 실패: 기본 브랜치의 과제 폴더 이름을 못 읽으면 검사 불가(3) · 사유 한 줄 · jobs 는 비고 job_notes 에 무엇을 못 셌는지"
assert_grep "$(cat "$T/shut.txt")" "^tip \| rc 3 \| git 읽기 실패 — git ls-tree 실패\(rc 128\): fatal: 이름 목록 막힘 \| \[\('fix-typo', '머지됨'\)\] \| .*로드맵 밖 과제를 다 세지 못했다 — 브랜치 끝 [0-9a-f]{8} 의 $TM/jobs 를 읽지 못했다" \
  "git 실패: 브랜치 끝의 이름 목록을 못 읽으면 검사 불가(3) · 같은 실패는 사유 한 줄 · 기본 브랜치의 과제는 그대로 싣는다"
assert_grep "$(cat "$T/shut.txt")" "^list \| rc 3 \| git 읽기 실패 — git log 실패\(rc 128\): fatal: 끝 목록 막힘 \| \[\('fix-typo', '머지됨'\)\] \| .*로드맵 밖 과제를 다 세지 못했다 — 기본 브랜치에 들어가지 않은 브랜치 끝을 읽지 못했다" \
  "git 실패: 브랜치 끝 목록을 못 읽으면 검사 불가(3)와 사유"
assert_not_contains "$(cat "$T/shut.txt")" "Traceback" "git 실패: 죽지 않는다"
# 과제의 예약 알림을 잴 diff 를 git 이 읽지 못하면 — 알림이 아니라 검사 불가(3). 이 픽스처에는 브랜치가 있는 블록이 없어
# diff 를 부르는 것은 과제 훑기뿐이다(위 none 줄이 rc 0 인 같은 레포)
python3 - "$S" "$W" "$RM" > "$T/nodiff.txt" 2>&1 <<'PY'
import argparse, sys
sys.path.insert(0, sys.argv[1])
import roadmap_status
root, rm = sys.argv[2:4]


class NoDiff(roadmap_status.Git):
    def changed(self, base, tip, pathspec=None):
        self.fail("diff", 128, "fatal: diff 막힘")
        return []


report = roadmap_status.build(NoDiff(root), argparse.Namespace(roadmap=rm, roadmap_file=None, json=True))
print("rc %d | %s | %s" % (roadmap_status.exit_code(report), " / ".join(report["unknown_reasons"]),
                           sorted(set(j["stage"] for j in report["jobs"] if j["tip"]))))
PY
assert_eq "$(cat "$T/nodiff.txt")" "rc 3 | git 읽기 실패 — git diff 실패(rc 128): fatal: diff 막힘 | ['진행 중']" \
  "AC11: 과제의 바꾼 파일을 git 이 읽지 못하면 검사 불가(3) · 같은 실패는 사유 한 줄 · 과제는 그대로 싣는다"

# ── 얕은 클론 — 브랜치의 과제는 단계를 셀 이력이 없다: 「알 수 없음」 · 머지된 과제는 머지됨 ──
# 얕은 클론 묶음 전용 과제 shal — 기본 브랜치 위 커밋 둘(과제 폴더 · 예약 밖 파일). 깊이 1 은 merge base 가 잘리고 깊이 3 은 닿는다.
# 얕지 않은 레포에서는 예약 알림을 내는 과제다(아래 얕은 사본들의 양의 짝)
# 기본 브랜치에는 깨진 과제 폴더가 있어 job new 의 나무 검사가 거절한다 — 깨끗한 사본에서 과제 폴더를 만들어 가져온다
SHAL_GEN="$T/shalgen"
git clone -q --no-local "$W" "$SHAL_GEN" && git -C "$SHAL_GEN" checkout -q "$(g rev-parse fix/broken~1)" && printf '얕은 클론 묶음의 과제\n' > "$T/said.txt" \
  && (cd "$SHAL_GEN" && python3 "$RW" job new --roadmap "$RM" --name shal --branch fix/shal --paths docs/shal-only.md --goal "얕은 클론 묶음의 과제" < "$T/said.txt") > "$T/out.txt" 2>&1 \
  && g checkout -q -b fix/shal main && mkdir -p "$W/$TM/jobs" && cp -R "$SHAL_GEN/$TM/jobs/shal" "$W/$TM/jobs/shal" \
  && g add -- "$TM/jobs/shal" && g commit -qm "과제 폴더 shal" || failed "fix/shal 과제 폴더 — $(cat "$T/out.txt")"
put docs/shal-extra.md "예약 밖 파일" && g commit -qm "shal 예약 밖 파일" && g push -q origin fix/shal && again || failed "fix/shal"
g checkout -q main
assert_eq "$(jget shal fix/shal stage) · $(js "$T/s.json" "[n for n in [j for j in r['jobs'] if j['id']=='shal'][0]['notes'] if '예약' in n]")" \
  "진행 중 · ['예약 밖 변경: docs/shal-extra.md']" "얕은 클론: 얕지 않은 레포에서 shal 은 예약 알림을 낸다(양의 짝 — 알림이 처음부터 없던 과제가 아니다)"
# 가드: 얕은지 묻는 호출만 실패하는 얕지 않은 레포 — 예약 알림은 떨어지지 않고 검사 불가(3)다
FG="$T/fakegit"; mkdir -p "$FG"; REAL_GIT="$(command -v git)"
cat > "$FG/git" <<SH
#!/bin/sh
case " \$* " in *" --is-shallow-repository "*) echo "fatal: simulated shallow probe" >&2; exit 128;; esac
exec "$REAL_GIT" "\$@"
SH
chmod +x "$FG/git"
G_RC=0; (cd "$W" && PATH="$FG:$PATH" python3 "$RS" "$RM" --json) > "$T/guard.json" 2>/dev/null || G_RC=$?
assert_eq "$G_RC" "3" "가드: 얕은지 읽지 못하면 검사 불가(3)다"
assert_contains "$(js "$T/guard.json" "r['unknown_reasons']")" "git 읽기 실패 — git rev-parse 실패(rc 128): fatal: simulated shallow probe" "가드: 사유에 그 호출이 있다"
assert_contains "$(js "$T/guard.json" "[n for j in r['jobs'] if j['id']=='shal' for n in j['notes']]")" "예약 밖 변경: docs/shal-extra.md" "가드: 얕지 않은 레포의 예약 알림은 떨어지지 않는다"
assert_eq "$(js "$T/guard.json" "[j['reason'] for j in r['jobs'] if j['id']=='shal'][0].endswith('예약도 재지 않았다')")" "False" "가드: 구절은 진짜 얕은 클론에만 붙는다"
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
# 깊이마다 — 단계 「알 수 없음」 인 과제에는 예약을 재지 않는다: 종료 코드 0 · 예약 알림 없음 · git 읽기 실패 없음 · 근거 끝에 구절
SH_REASON="$(PYTHONDONTWRITEBYTECODE=1 python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import team_status as T; print(T.SHALLOW + " · " + T.RESERVE_UNSCANNED)' "$S")"
shallow_depth() {  # shallow_depth <사본 폴더> <깊이> <merge base 종료 코드> <이름표> — 사본의 보고를 $T/shallow-<이름표>.json 에 쓰고 단언한다
  local dir="$1" label="$4" mb=0 rc=0 json="$T/shallow-$4.json"
  assert_eq "$(git -C "$dir" rev-parse --is-shallow-repository)" "true" "얕은 클론 ${label}: 픽스처가 정말 얕은 클론이다"
  git -C "$dir" merge-base origin/main origin/fix/shal > /dev/null 2>&1 || mb=$?
  assert_eq "$mb" "$3" "얕은 클론 ${label}: 기본 브랜치와 shal 끝의 merge base 종료 코드(깊이 ${2} — 이 깊이가 그 갈래다)"
  (cd "$dir" && python3 "$RS" "$RM" --json) > "$json" 2> /dev/null || rc=$?
  assert_eq "$rc" "0" "얕은 클론 ${label}: 과제의 사정은 알림만이라 종료 코드를 바꾸지 않는다"
  assert_eq "$(js "$json" "[(j['stage'], j['task_status']) for j in r['jobs'] if j['id'] == 'shal']")" "[('알 수 없음', None)]" \
    "얕은 클론 ${label}: shal 은 단계 「알 수 없음」"
  assert_eq "$(js "$json" "[n for j in r['jobs'] if j['id'] == 'shal' for n in j['notes'] if '예약' in n]")" "[]" \
    "얕은 클론 ${label}: 알 수 없는 과제에는 예약 알림(예약 밖 변경 · 경로 예약 위반)을 내지 않는다"
  assert_eq "$(js "$json" "[u for u in r['unknown_reasons'] if 'git 읽기 실패' in u]")" "[]" \
    "얕은 클론 ${label}: 예약 diff 를 읽지 못한 일이 검사 불가 사유에 들지 않는다"
  assert_eq "$(js "$json" "[j['reason'] for j in r['jobs'] if j['id'] == 'shal']")" "['$SH_REASON']" \
    "얕은 클론 ${label}: 근거는 얕은 클론 글로 시작해 예약을 재지 않았다는 구절로 끝난다"
}
assert_eq "$SH_RC" "0" "얕은 클론 깊이 1: 과제를 훑어도 종료 코드는 0 이다(과제의 사정은 알림)"
shallow_depth "$SH" 1 1 d1
SH3="$T/shallow3"
git clone -q --no-local --depth 3 --no-single-branch "file://$T/origin.git" "$SH3" && git -C "$SH3" remote set-head origin main \
  || no "깊이 3 얕은 클론을 만들지 못했다"
shallow_depth "$SH3" 3 0 d3
g push -q origin --delete fix/shal && g branch -q -D fix/shal && again || failed "fix/shal 지움"

# ── 기본 브랜치를 모르는 레포 — 과제를 세지 못했다고 한 줄 ─────────────────
g remote set-head origin -d
NO_RC=0; (cd "$W" && python3 "$RS" --roadmap-file "$RM" --json) > "$T/s.json" 2>/dev/null || NO_RC=$?
assert_eq "${NO_RC} · $(js "$T/s.json" "(r['jobs'], r['job_notes'])")" "3 · ([], ['로드맵 밖 과제를 세지 못했다 — 기본 브랜치를 모른다'])" \
  "기본 브랜치 모름: jobs 는 비고 세지 못했다는 알림 한 줄(없음이라 하지 않는다) · 종료 코드는 블록 규칙대로 3"
g remote set-head origin main

# ── 끝에서 끝 — create --layout team(team_repo) → job new → job sync → 결과 파일 커밋 → job_results.py check 의 실제 출력 →
#    conductor_ledger.py record 의 받음 줄 → 단계가 넘어간다. 걸음마다 앞 걸음의 종료 코드와 글을 다음 걸음이 받는다 ──
CL="$S/conductor_ledger.py"; CP="$S/control_plane.py"
E2E="$TM/jobs/e2e-job"
e2e_check() {  # e2e_check <브랜치> — 결과 대조를 돌려 출력은 $T/check.txt, rc 를 echo 한다
  local rc=0
  (cd "$W" && python3 "$JRC" check --roadmap "$RM" --job e2e-job --result implement-1.md --branch "$1" --date 2026-11-28) > "$T/check.txt" 2>&1 || rc=$?
  echo "$rc"
}
snap() {  # 작업 나무(.git 밖)의 파일 바이트 · git 이 보는 상태(무시된 파일 포함) · ref 들
  (cd "$W" && find . -path ./.git -prune -o -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum)
  g status --porcelain --untracked-files=all --ignored
  g for-each-ref
}
# 위 묶음들이 기본 브랜치에 깨진 과제 폴더(broken · dirint · loose)를 들였다 — job new 의 나무 검사가 거절하지 않는, 그 전 커밋에서 가른다
E2E_BASE="$(g rev-parse fix/broken~1)"
g checkout -q -b fix/e2e "$E2E_BASE" || failed "fix/e2e"
printf '끝에서 끝으로 문서 하나를 고친다\n' > "$T/said.txt"
E2E_RC=0; (cd "$W" && python3 "$RW" job new --roadmap "$RM" --name e2e-job --branch fix/e2e --paths docs/e2e.md --goal "끝에서 끝 문서 하나" < "$T/said.txt") \
  > "$T/out.txt" 2>&1 || E2E_RC=$?
assert_eq "${E2E_RC} · $(head -1 "$T/out.txt")" "0 · [spec-distill] 과제 폴더를 만들었다: $E2E (kind: task · 브랜치 fix/e2e) — 브랜치를 만들거나 커밋하지 않았다" \
  "끝에서 끝: job new 가 과제 폴더를 만든다"
g add -- "$E2E" && g commit -qm "과제 폴더 e2e-job" && put docs/e2e.md "끝에서 끝으로 고친 문서" && g commit -qm "e2e 문서" \
  && CODE="$(g rev-parse HEAD)" || failed "e2e 커밋"
assert_eq "$(sync e2e-job implement-1.md --role worker --bundle-at "$(g rev-parse origin/main)" --job-at "$CODE") · $(cat "$T/out.txt")" \
  "0 · [spec-distill] 결과 파일을 맞췄다: $E2E/results/implement-1.md — 머리 만듦" "끝에서 끝: job sync 가 결과 파일의 머리를 만든다"
g add -- "$E2E" && g commit -qm "결과 파일 열기" && g push -q origin fix/e2e && again || failed "결과 파일 열기"
assert_contains "$(jget e2e-job fix/e2e notes)" "결과 있음 · 받음 없음: implement-1.md(도는 중 — 끝 줄 없음)" "끝에서 끝: 끝 줄 전에는 「도는 중」 받음 없음 알림"
approved "흐름 승인" e2e-job - - 2026-11-27 && g push -q origin fix/e2e || failed "e2e 흐름 승인"
rm -rf "$W/.claude"   # 위 claim 이 이 테스트의 준비로 남긴 지휘 표지 자리 — 아래 「git 이 모르는 파일이 없다」 단언은 상태 계산이 남긴 파일만 잰다
# 끝 줄 전의 대조 — 1(거절): 받음 줄을 내지 않으므로 리더가 record 에 넘길 줄이 없다
assert_eq "$(e2e_check fix/e2e)" "1" "끝에서 끝: 끝 줄 전의 대조는 거절(1)"
assert_eq "$(head -1 "$T/check.txt")" "결과 대조: 거절 2건 — implement-1.md" "끝에서 끝: 거절의 첫 줄(사유 둘)"
assert_eq "$(grep '^거절 사유: ' "$T/check.txt")" "$(printf '거절 사유: 끝 줄이 없다 — 아직 도는 중이다\n거절 사유: 산출물 줄이 없다 — 설계문서가 없는 과제는 `산출물: <경로>` 를 하나 이상 적는다')" \
  "끝에서 끝: 거절 사유 — 끝 줄 없음 · 산출물 줄 없음(설계문서가 없는 과제)"
assert_not_contains "$(cat "$T/check.txt")" "- 결과 받음 · " "끝에서 끝: 거절(1)이면 받음 줄을 내지 않는다"
# 브랜치를 읽지 못한 대조 — 3(검사 불가): 받음 줄을 내지 않는다
assert_eq "$(e2e_check fix/e2e-nowhere) · $(head -1 "$T/check.txt")" "3 · 결과 대조: 검사 불가 — 브랜치 fix/e2e-nowhere 가 로컬에도 origin 에도 없다" \
  "끝에서 끝: 없는 브랜치의 대조는 검사 불가(3)와 그 사유"
assert_not_contains "$(cat "$T/check.txt")" "- 결과 받음 · " "끝에서 끝: 검사 불가(3)면 받음 줄을 내지 않는다"
printf '산출물: docs/e2e.md\n' >> "$W/$E2E/results/implement-1.md"
assert_eq "$(sync e2e-job implement-1.md --end "$CODE") · $(cat "$T/out.txt")" "0 · [spec-distill] 결과 파일을 맞췄다: $E2E/results/implement-1.md — 끝 줄" \
  "끝에서 끝: job sync --end 가 끝 줄을 단다"
# 끝난 결과 파일을 다시 맞추려 하면 1(쓰지 않음) — 파일은 바이트 그대로다
cp "$W/$E2E/results/implement-1.md" "$T/ended.md"
assert_eq "$(sync e2e-job implement-1.md --end "$(g rev-parse origin/main)")" "1" "끝에서 끝: 끝난 결과 파일의 job sync 는 쓰지 않음(1)"
assert_contains "$(cat "$T/out.txt")" "끝난 결과 파일은 고치지 않는다 — 다시 하는 일은 새 시도 번호다" "끝에서 끝: 그 사유"
cmp -s "$T/ended.md" "$W/$E2E/results/implement-1.md" && ok "끝에서 끝: 쓰지 않음(1) 뒤 결과 파일은 바이트 그대로" \
  || no "끝에서 끝: 쓰지 않음(1) 뒤 결과 파일이 바뀌었다"
g add -- "$E2E" && g commit -qm "결과 파일 끝" && g push -q origin fix/e2e || failed "결과 파일 끝"
# 통과(0) — 실제 출력에서 받음 줄을 떼어 record 에 넘긴다
assert_eq "$(e2e_check fix/e2e)" "0" "끝에서 끝: 끝 줄 뒤의 대조는 통과(0)"
FIRST="$(head -1 "$T/check.txt")"
assert_eq "$FIRST" "결과 대조: 통과 — implement-1.md · head ${CODE:0:8} · 산출물 1개" "끝에서 끝: 통과의 첫 줄(가운뎃점 구분이 든다)"
LINE="$(grep '^- 결과 받음 · ' "$T/check.txt")"
assert_eq "$LINE" "- 결과 받음 · 2026-11-28 · 「implement-1.md · ${CODE} · ${FIRST}」" "끝에서 끝: 받음 줄은 「결과 파일 · head 전체 · 첫 줄 그대로」"
assert_eq "$(grep -c '^- 결과 받음 · ' "$T/check.txt") · $(grep -cx '리더가 과제의 결정 기록에 적을 받음 줄:' "$T/check.txt")" "1 · 1" \
  "끝에서 끝: 받음 줄은 한 줄이고 그 앞에 안내 줄이 있다"
REC_RC=0; (cd "$W" && python3 "$CL" --root "$W" record --spec "$W/$E2E/results/implement-1.md" --line "$LINE") > "$T/rec.txt" 2>&1 || REC_RC=$?
assert_eq "${REC_RC} · $(cat "$T/rec.txt")" "0 · 적었다(커밋은 리더가) — $W/$E2E/INTENT.md 의 결정 기록: $LINE" \
  "끝에서 끝: record 가 과제 폴더의 파일을 받아 그 INTENT.md 결정 기록에 받음 줄을 쓴다"
REC_RC=0; (cd "$W" && python3 "$CL" --root "$W" record --spec "$W/$E2E/INTENT.md" --line "$LINE") > "$T/rec.txt" 2>&1 || REC_RC=$?
assert_eq "${REC_RC} · $(grep -cxF -- "$LINE" "$W/$E2E/INTENT.md")" "0 · 1" "끝에서 끝: 같은 받음 줄을 다시 record 해도 줄은 한 번"
g add -- "$E2E" && g commit -qm "받음 줄" && g push -q origin fix/e2e || failed "받음 줄"
BEFORE="$(snap)"
again
assert_eq "$(js "$T/s.json" "[j['stage'] for j in r['jobs'] if j['id']=='e2e-job']")" "['결과 받음']" "끝에서 끝: 대조 → record 의 받음 줄 → 단계가 넘어간다"
assert_eq "$(jget e2e-job fix/e2e reason) · $RC" "결과 받음 줄 있음: implement-1.md · 0" "끝에서 끝: 그 근거 · 종료 코드 0"
[ "$(snap)" = "$BEFORE" ] && ok "끝에서 끝: 상태 계산은 team 로드맵을 읽기만 한다(작업 나무 · git 상태 · ref 가 그대로)" \
  || no "끝에서 끝: 상태 계산 전후로 작업 나무가 달라졌다"
# 전후 비교는 이 한 번의 실행만 본다 — 앞선 상태 계산이 이미 남긴 파일(같은 바이트로 다시 만든 것)은 위 비교에 안 보인다
assert_eq "$(g status --porcelain --untracked-files=all --ignored)" "" "끝에서 끝: 상태 계산을 여러 번 돈 뒤에도 작업 나무에 git 이 모르는 파일이 없다"
SHOW_RC=0; (cd "$W" && python3 "$CP" show "$RM") > "$T/show.txt" 2>&1 || SHOW_RC=$?
assert_eq "$SHOW_RC" "0" "끝에서 끝: 현황 rc 0"
assert_grep "$(cat "$T/show.txt")" "^로드맵 밖 과제:$" "끝에서 끝: 현황에 「로드맵 밖 과제:」 절"
assert_contains "$(cat "$T/show.txt")" "    e2e-job 끝에서 끝 문서 하나 — 결과 받음 · 결과 받음 줄 있음: implement-1.md" "끝에서 끝: 현황에 그 과제의 줄"

# ── 과제 훑기의 진짜 git 실패 — 브랜치 끝의 과제 폴더 트리 객체를 치운다: 실제 보고가 3 과 사유를 내고 현황이 그 사유를 보인다 ──
g checkout -q -b fix/e2e-gone "$E2E_BASE" && printf '트리를 치울 과제\n' > "$T/said.txt" \
  && (cd "$W" && python3 "$RW" job new --roadmap "$RM" --name e2e-gone --branch fix/e2e-gone --paths docs/gone.md --goal "치울 트리" < "$T/said.txt") > "$T/out.txt" 2>&1 \
  && g add -- "$TM/jobs/e2e-gone" && g commit -qm "과제 폴더 e2e-gone" && g checkout -q main || failed "fix/e2e-gone"
GONE="$(g rev-parse "fix/e2e-gone:$TM/jobs")"
GONE_OBJ="$W/.git/objects/${GONE:0:2}/${GONE:2}"
if [ -f "$GONE_OBJ" ] && mv "$GONE_OBJ" "$T/gone-tree"; then
  GONE_RC=0; (cd "$W" && python3 "$RS" "$RM" --json) > "$T/gone.json" 2>/dev/null || GONE_RC=$?
  (cd "$W" && python3 "$CP" show "$RM") > "$T/gone-show.txt" 2>&1
  mv "$T/gone-tree" "$GONE_OBJ"
  assert_eq "${GONE_RC} · $(js "$T/gone.json" "[u for u in r['unknown_reasons'] if u.startswith('git 읽기 실패 — git ls-tree 실패')] != []")" "3 · True" \
    "끝에서 끝: 과제 훑기에서 git 이 읽지 못하면 실제 보고가 검사 불가(3)와 「git 읽기 실패 — …」 사유를 낸다"
  REASON="$(js "$T/gone.json" "[u for u in r['unknown_reasons'] if u.startswith('git 읽기 실패 — git ls-tree 실패')][0]")"
  assert_contains "$(cat "$T/gone-show.txt")" "검사 불가: $REASON" "끝에서 끝: 현황이 그 사유를 「검사 불가: <사유>」 로 보인다"
  assert_contains "$(js "$T/gone.json" "' | '.join(r['job_notes'])")" "로드맵 밖 과제를 다 세지 못했다 — 브랜치 끝 $(g rev-parse fix/e2e-gone | cut -c1-8) 의 $TM/jobs 를 읽지 못했다" \
    "끝에서 끝: 무엇을 못 셌는지는 알림으로"
  assert_contains "$(js "$T/gone.json" "[(j['id'], j['stage']) for j in r['jobs']]")" "('e2e-job', '결과 받음')" "끝에서 끝: 읽은 과제는 그대로 싣는다"
else
  no "끝에서 끝: 치울 트리 객체가 낱개 파일이 아니다 — $GONE_OBJ"
fi
g cat-file -e "$GONE" && ok "끝에서 끝: 치운 트리 객체를 되돌렸다" || no "끝에서 끝: 트리 객체를 되돌리지 못했다"
g branch -q -D fix/e2e-gone || failed "fix/e2e-gone 지움"

# ── pr-refresh 의 3 — 단계 계산이 세지 못한 블록(형식이 깨진 team 로드맵)은 PR 캐시를 채우지 않고 사유와 3 ──
git clone -q --bare "$T/origin.git" "$T/origin-pr.git" && git clone -q "$T/origin-pr.git" "$T/prr" && git -C "$T/prr" remote set-head origin main \
  && python3 - "$T/prr/$RM" <<'PY' && git -C "$T/prr" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false commit -qam "형식 깨짐" \
  && git -C "$T/prr" push -q origin main || no "pr-refresh 사본을 만들지 못했다"
import sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
if t.count("- 의존: 없음\n") < 1:
    sys.exit("의존 줄이 없다")
open(p, "w", encoding="utf-8").write(t.replace("- 의존: 없음\n", "- 의존: 없음\n- 의존: 없음\n", 1))
PY
PR_SID="session-e2e00016"
CLAIM_RC=0; (cd "$T/prr" && python3 "$CL" --root "$T/prr" claim --roadmap "$RM" --session "$PR_SID") > "$T/claim.txt" 2>&1 || CLAIM_RC=$?
assert_eq "$CLAIM_RC" "0" "pr-refresh: 사본에서 세션 표지를 잡는다(아래 단언의 바탕)"
PRR_RC=0; (cd "$T/prr" && python3 "$CL" --root "$T/prr" pr-refresh --roadmap "$RM" --session "$PR_SID") > "$T/prr.txt" 2>&1 || PRR_RC=$?
assert_eq "$PRR_RC" "3" "pr-refresh: 세지 못한 블록이 있으면 3"
assert_contains "$(cat "$T/prr.txt")" "[spec-distill] E1 의 단계를 세지 못해 브랜치를 읽지 못했다 — 로드맵 형식 깨짐" "pr-refresh: 그 사유(「브랜치 없음」 이 아니다)"
assert_not_contains "$(cat "$T/prr.txt")" "브랜치 없음" "pr-refresh: 세지 못한 블록을 「브랜치 없음」 으로 말하지 않는다"

g checkout -q main
assert_eq "$(g status --porcelain --untracked-files=all)" "" "끝 상태: 작업 트리가 깨끗하다"
assert_eq "$(g symbolic-ref -q refs/remotes/origin/HEAD)" "refs/remotes/origin/main" "끝 상태: origin/HEAD 는 main"

# ── 글 출력의 로드맵 밖 과제(R3 M21) · 과제 폴더 없는 작업(R3 AC18 · M22) — 과제가 하나뿐인 새 팀 레포에서 잰다 ──
T0="$T"
new_repo "$T0/fresh" && ok "새 팀 레포를 세웠다" || { no "새 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; use_repo "$T0"; finish; exit 1; }
newjob solo fix/solo && put docs/solo-extra.md "예약 밖 파일" && g commit -qm "solo 예약 밖" && g push -q origin fix/solo && g checkout -q main && again \
  || failed "fix/solo"
TXT_RC=0; (cd "$W" && python3 "$RS" "$RM") > "$T/solo.txt" 2>&1 || TXT_RC=$?
assert_eq "$(jobs) · $(js "$T/s.json" "r['job_notes']")" "[('solo', '진행 중', 'fix/solo')] · []" "M21: 로드맵 밖 과제가 하나다(아래 단언의 바탕)"
assert_eq "$TXT_RC" "$RC" "M21: 글 출력과 --json 의 종료 코드가 같다"
SOLO_LINE="    solo solo 을 맡아 끝낸다 — 진행 중 · $(jget solo fix/solo reason)"
assert_eq "$(sed -n '/^로드맵 밖 과제: /,/^경로 예약 겹침(정보): /p' "$T/solo.txt")" \
  "$(printf '로드맵 밖 과제: 1개\n%s\n        정보: 예약 밖 변경: docs/solo-extra.md\n경로 예약 겹침(정보): 0개' "$SOLO_LINE")" \
  "M21: team 로드맵의 글 출력에 「로드맵 밖 과제: 1개」 · 그 과제 줄 · 그 알림의 「정보:」 줄이 경로 예약 겹침 줄 앞에 있다"
assert_eq "$(js "$T/s.json" "[(b['id'], b.get('job_folder', '칸 없음')) for b in r['blocks']]")" "[('P1', '칸 없음'), ('E1', True), ('E2', True), ('E3', True)]" \
  "AC18: 과제 폴더가 기본 브랜치에 있는 블록은 job_folder 가 true · 결정 블록에는 칸이 없다"
# 과제 폴더를 통째로 지우면 번호 파일(sources.md)이 없어 로드맵 형식 깨짐(3)이다 — 과제 폴더가 있다는 표지 INTENT.md 만 지운다
g rm -q -- "$TM/jobs/E2/INTENT.md" && g commit -qm "E2 의 INTENT.md 를 지운다" && g push -q origin main && again || failed "E2 INTENT.md 지움"
assert_eq "$(js "$T/s.json" "[(b['id'], b.get('job_folder', '칸 없음')) for b in r['blocks']]")" "[('P1', '칸 없음'), ('E1', True), ('E2', False), ('E3', True)]" \
  "AC18: 기본 브랜치에서 과제의 INTENT.md 를 지운 블록은 job_folder 가 false"
python3 - "$S" "$W" "$RM" <<'PY' || no "기계 상태에 작업 줄을 쓰지 못했다"
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import conductor_state as cs
import roadmap_status
from state_path import state_root_for_common
root, rm = sys.argv[2:4]
path = cs.machine_path(state_root_for_common(Path(root, roadmap_status.Git(root).common_dir()).resolve()), rm)
path.parent.mkdir(parents=True, exist_ok=True)
data = cs.load(path, rm)
row = lambda kind, name, epic, stage="진행": {"종류": kind, "이름": name, "에픽": epic, "단계": stage, "담당": "없음", "근거": "-"}
data["작업"] += [row("구현", "E1 계획 1", "E1"), row("구현", "E2 계획 1", "E2"), row("구현", "E2 계획 0", "E2", stage="끝"),
                 row("수리", "solo 마무리", "로드맵 밖"), row("수리", "지휘자 수리", "로드맵 밖")]
path.write_text(cs.render_machine(rm, data), encoding="utf-8")
PY
(cd "$W" && python3 "$S/control_plane.py" show "$RM") > "$T/fresh-show.txt" 2>&1
assert_eq "$(grep -F " · 과제 폴더 없음" "$T/fresh-show.txt" | sed 's/ — .*//')" "$(printf '    구현 E2 계획 1\n    수리 지휘자 수리')" \
  "AC18: 상태 보기가 과제 폴더를 지운 블록의 작업 줄과 어디에도 과제가 없는 로드맵 밖 작업 줄만 「과제 폴더 없음」 으로 알린다"
assert_contains "$(cat "$T/fresh-show.txt")" "    구현 E1 계획 1 — E1 · 진행 · 담당 없음 · -" "AC18: 과제 폴더가 있는 블록의 작업 줄은 그대로(양의 짝 — 작업 줄이 화면에 있다)"
use_repo "$T0"

finish
