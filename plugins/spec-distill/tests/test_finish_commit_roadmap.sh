#!/usr/bin/env bash
# 끝내기 커밋(context-commit 펜스)의 범위와 재분해 표의 자리.
# AC5 — 나눈 일이어도 끝내기 커밋은 결과물 · audit · 상태 파일만 넣는다. 로드맵 폴더는 로드맵 잡기의 커밋 펜스(roadmap-commit)가
# 넣고, 그 판정(도출 · roadmaps_dir · roadmap-check · 폴더 · 링크)은 test_roadmap_draft_skill.sh 가 잰다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_finish_commit_roadmap.sh
set -u
ROOT_REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT_REPO/plugins/spec-distill"
. "$ROOT_REPO/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
unset DEVBREW_SPEC_DISTILL_DISABLE DEVBREW_SKIP_HOOKS
T="$(mktemp -d)"; [ -n "$T" ] && [ -d "$T" ] || { echo "mktemp 실패"; exit 1; }
T="$(cd "$T" && pwd -P)"; trap 'rm -rf "$T"' EXIT

fence() {   # fence <파일> <마커 이름> → 그 마커 사이 첫 bash 펜스 본문
  awk -v b="<!-- $2:begin -->" -v e="<!-- $2:end -->" '
    index($0,b){f=1;next} index($0,e){f=0} f&&/^```bash$/{c=1;next} f&&c&&/^```$/{c=0;next} f&&c' "$1"
}
nob() { no "$1"; printf '      출력: %s\n' "$2"; }
FIN="$SD/skills/context-build/references/finishing.md"
RED="$SD/references/redecompose.md"
PH='<Step A.5 의 PAYLOAD 절대경로>'
cf="$(fence "$FIN" context-commit)"
case "$cf" in *"BRIEF=\"$PH\""*) ok "전제: 커밋 펜스에 BRIEF 자리표" ;; *) no "전제: BRIEF 자리표가 없다 — 아래 칸이 공허하다" ;; esac

STEM=docs/superpowers/interview/2026-10-15-t-interview
RREL=docs/superpowers/roadmaps/2026-10-15-t
mk() {   # mk <이름> [레포 설정 머리말 줄] → origin 을 가진 클론, 기능 브랜치, docs 에 세 파일(brief 는 §7 없이)
  local o="$T/$1-origin.git" c="$T/$1"
  git init -q --bare -b main "$o"; git clone -q "$o" "$c" 2>/dev/null
  git -C "$c" config user.email t@t.t; git -C "$c" config user.name t
  if [ -n "${2:-}" ]; then printf -- '---\n%s\n---\n' "$2" > "$c/.devbrew.md"; git -C "$c" add -- .devbrew.md; fi
  git -C "$c" commit -q --allow-empty -m init; git -C "$c" push -q origin main 2>/dev/null
  git -C "$c" remote set-head origin main >/dev/null 2>&1
  git -C "$c" switch -q -c feature/x
  mkdir -p "$c/docs/superpowers/interview"
  for s in .md .audit.md .state.md; do printf 'x\n' > "$c/$STEM$s"; done
  printf '%s' "$c"
}
brief7() {   # brief7 <클론> <§7 첫 줄> → §7 에 그 줄을 둔 brief(템플릿의 괄호 안내 줄도 둔다)
  printf -- '---\ntype: interview-brief\n---\n## 2. 제약\n\n- C1 x\n\n## 7. Next Action\n\n%s\n\n(분해된 일이면 첫 줄은 `분해됨 — <로드맵 경로>` 이다.)\n' "$2" > "$1/$STEM.md"
}
roadmap() {   # roadmap <클론> [로드맵 폴더(레포 상대)] → 생성기가 만든 꼴의 로드맵 폴더(머리말 type: roadmap)
  local d="${2:-$RREL}"
  mkdir -p "$1/$d"; printf -- '---\ntype: roadmap\n---\n# 로드맵\n' > "$1/$d/roadmap.md"; printf '# R1\n' > "$1/$d/R1.md"
}
runc() {   # runc <클론> → BRIEF 자리표를 그 클론의 brief 절대경로로 바꿔 돈 출력
  ( cd "$1" && CLAUDE_PLUGIN_ROOT="$SD" bash -c "${cf//"$PH"/$1/$STEM.md}" 2>&1 )
}
files_of_head() { git -C "$1" show --name-only --pretty=format: HEAD | sed '/^$/d' | sort | tr '\n' ' '; }
nhead() { git -C "$1" rev-list --count HEAD; }
THREE="$STEM.audit.md $STEM.md $STEM.state.md "
DEC="분해됨 — $RREL/roadmap.md"
only_three() {   # only_three <클론> <출력> <라벨> — 세 파일만 한 커밋에, 성공 줄 하나, 로드맵 폴더는 커밋 밖
  assert_eq "$(nhead "$1")" "2" "$3: 커밋이 하나 생겼다"
  assert_eq "$(files_of_head "$1")" "$THREE" "$3: 결과물 · audit · 상태 파일만 커밋된다"
  assert_contains "$2" "[spec-distill] brief · audit · 상태 파일을 커밋했다 — " "$3: 성공 줄은 「brief · audit · 상태 파일을 커밋했다」"
  assert_not_contains "$2" "로드맵 폴더" "$3: 로드맵 폴더를 말하지 않는다(커밋하지도 빼지도 않는다)"
}

# 0. 펜스 글 — 로드맵 폴더 갈래가 없다(AC5)
for tok in 'roadmap-check' 'roadmaps_dir' '로드맵 폴더를 커밋했다' 'RDIR' 'r7='; do
  assert_not_contains "$cf" "$tok" "펜스 글(AC5): 「${tok}」 가 없다"
done
assert_eq "$(printf '%s\n' "$cf" | grep -c '을 커밋했다 — ')" "1" "펜스 글(AC5): 성공 줄은 하나뿐이다"

# 1. 나눈 일 — §7 에 분해됨 줄과 로드맵 폴더가 있어도 세 파일만 커밋한다. 로드맵 폴더는 커밋되지 않은 채 남는다.
c="$(mk dec)"; roadmap "$c"; brief7 "$c" "$DEC"
printf 'y\n' > "$c/other.txt"; git -C "$c" add other.txt
o="$(runc "$c")"
only_three "$c" "$o" "나눈 일"
assert_eq "$(git -C "$c" status --porcelain -- "$RREL" | sed '/^$/d' | wc -l | tr -d ' ')" "1" "나눈 일: 로드맵 폴더는 커밋 밖에 남는다"
git -C "$c" diff --cached --name-only | grep -qx other.txt && ok "나눈 일: 이미 stage 된 다른 파일은 stage 된 채로" || nob "나눈 일: stage 된 다른 파일이 사라졌다" "$o"
# §7 경로가 절대경로여도 · 목록 · 코드 꼴이어도 같다
c="$(mk dec-abs)"; roadmap "$c"; brief7 "$c" "분해됨 — $c/$RREL/roadmap.md"
o="$(runc "$c")"; only_three "$c" "$o" "나눈 일(§7 절대경로)"
c="$(mk dec-code)"; roadmap "$c"; brief7 "$c" "- \`$DEC\`"
o="$(runc "$c")"; only_three "$c" "$o" "나눈 일(§7 목록 · 코드 꼴)"

# 1b. cwd 가 다른 레포(다른 interview_dir · 기본 브랜치 모름)여도 brief 레포에 세 파일을 커밋하고 cwd 레포에는 커밋하지 않는다
c="$(mk elsewhere)"; roadmap "$c"; brief7 "$c" "$DEC"
x="$(mk cwdrepo 'interview_dir: notes/')"; git -C "$x" remote set-head origin -d >/dev/null 2>&1   # cwd 레포는 기본 브랜치도 모른다
o="$( cd "$x" && CLAUDE_PLUGIN_ROOT="$SD" bash -c "${cf//"$PH"/$c/$STEM.md}" 2>&1 )"
only_three "$c" "$o" "다른 레포에서 돌림"
assert_eq "$(nhead "$x")" "1" "다른 레포에서 돌림: cwd 레포에는 커밋하지 않는다"
# 2. 나누지 않은 일 — 세 파일만
c="$(mk nodec)"; roadmap "$c"; brief7 "$c" "superpowers:brainstorming 으로 간다."
o="$(runc "$c")"; only_three "$c" "$o" "나누지 않음"
assert_eq "$(git -C "$c" status --porcelain -- "$RREL" | sed '/^$/d' | wc -l | tr -d ' ')" "1" "나누지 않음: 로드맵 폴더는 커밋되지 않고 남는다"

# 3. 로드맵 폴더가 없거나 · 비었거나 · 로드맵 꼴이 아니거나 · 정해진 폴더 밖이거나 · 폴더가 아니어도 끝내기 커밋은 판정하지 않고 세 파일을 커밋한다
c="$(mk gone)"; brief7 "$c" "$DEC"
o="$(runc "$c")"; only_three "$c" "$o" "로드맵 폴더 없음"
c="$(mk empty)"; mkdir -p "$c/$RREL"; brief7 "$c" "$DEC"
o="$(runc "$c")"; only_three "$c" "$o" "빈 로드맵 폴더"
c="$(mk notrm)"; roadmap "$c"; brief7 "$c" "분해됨 — $RREL/R1.md"
o="$(runc "$c")"; only_three "$c" "$o" "§7 의 파일이 로드맵 꼴이 아님"
c="$(mk wide)"; mkdir -p "$c/docs/x"; printf 'r\n' > "$c/docs/x/roadmap.md"; brief7 "$c" "분해됨 — docs/x/roadmap.md"
o="$(runc "$c")"; only_three "$c" "$o" "§7 의 폴더가 정해진 로드맵 폴더 밖"
c="$(mk notdir)"; mkdir -p "$c/docs/superpowers/roadmaps"; printf 'f\n' > "$c/$RREL"; brief7 "$c" "$DEC"
o="$(runc "$c")"; only_three "$c" "$o" "로드맵 폴더 자리가 파일"
# 보안 — 로드맵 폴더가 밖의 폴더로 가는 링크여도 링크 너머는 건드리지 않는다(커밋에도 없다)
c="$(mk link)"; mkdir -p "$T/outside-rm" "$c/docs/superpowers/roadmaps"; printf '밖\n' > "$T/outside-rm/roadmap.md"
ln -s "$T/outside-rm" "$c/$RREL"; brief7 "$c" "$DEC"
o="$(runc "$c")"; only_three "$c" "$o" "보안: 로드맵 폴더가 링크"
assert_eq "$(cat "$T/outside-rm/roadmap.md")" "밖" "보안: 링크 너머 파일은 그대로"

# 4. 거부 — 커밋 · stage 0, 사유 한 줄에 경로들
refused() {   # refused <클론> <출력> <라벨> <사유 조각>
  assert_eq "$(nhead "$1")" "1" "$3: 커밋하지 않는다"
  assert_eq "$(git -C "$1" diff --cached --name-only)" "" "$3: 아무것도 stage 하지 않는다"
  case "$2" in *"커밋하지 않았다"*"$4"*"$STEM.state.md"*) ok "$3: 사유와 경로를 보인다" ;; *) nob "$3: 사유 · 경로가 없다" "$2" ;; esac
}
# 4a. 레포 설정 intent_dir(옛 키만 있는 레포도) — brief 가 그 폴더 바로 아래가 아니면 멈춘다
c="$(mk cfg-iv 'interview_dir: notes/')"; brief7 "$c" "superpowers:brainstorming 으로 간다."
o="$(runc "$c")"; refused "$c" "$o" "설정 옛 키 interview_dir · 다른 자리" "정해진 의도 폴더(옛 꼴 파일은 옛 의도 폴더) 바로 아래가 아니다"
# 설정에 새 키만 있으면 옛 의도 폴더는 옛 기본 폴더다 — 그 폴더의 옛 꼴 결과물(이어 온 일)은 받는다
c="$(mk cfg-in 'intent_dir: notes/')"; brief7 "$c" "superpowers:brainstorming 으로 간다."
o="$(runc "$c")"; only_three "$c" "$o" "설정 intent_dir 만 · 옛 기본 폴더의 옛 꼴 결과물"

# 5. 기본 브랜치 — 나눈 일이어도 「커밋하지 않았다」 줄의 손 목록은 세 파일이다(로드맵 폴더는 로드맵 잡기가 커밋한다)
c="$(mk onmain)"; git -C "$c" switch -q main; roadmap "$c"; brief7 "$c" "$DEC"
o="$(runc "$c")"
assert_eq "$(nhead "$c")" "1" "기본 브랜치: 커밋하지 않는다"
case "$o" in *"커밋하지 않았다 — 지금 기본 브랜치(main)에 있다. 브랜치에서 커밋하라: $c/$STEM.md · $c/$STEM.audit.md · $c/$STEM.state.md"*) ok "기본 브랜치: 미커밋 줄의 손 목록은 세 파일" ;; *) nob "기본 브랜치: 미커밋 줄의 손 목록이 세 파일이 아니다" "$o" ;; esac
assert_not_contains "$o" "$c/$RREL" "기본 브랜치: 미커밋 줄에 로드맵 폴더가 없다(양성 짝: 위 단언)"
# 5b. AC11 — 로컬 브랜치 origin/main 이 있어도 기본 브랜치 검사가 켜져 있다
c="$(mk shadow)"; git -C "$c" branch origin/main main; git -C "$c" switch -q main; brief7 "$c" "superpowers:brainstorming 으로 간다."
o="$(runc "$c")"
assert_eq "$(nhead "$c")" "1" "로컬 브랜치 origin/main: 기본 브랜치 위 커밋을 거부한다"
assert_contains "$o" "지금 기본 브랜치(main)에 있다" "로컬 브랜치 origin/main: 기본 브랜치 이름을 보인다"
# 5c. AC10 — 원격의 기본 브랜치가 바뀌었는데 로컬 origin/HEAD 가 옛 이름이면 멈춘다
c="$(mk renamed)"; git -C "$T/renamed-origin.git" branch trunk main; git -C "$T/renamed-origin.git" symbolic-ref HEAD refs/heads/trunk
brief7 "$c" "superpowers:brainstorming 으로 간다."
o="$(runc "$c")"
assert_eq "$(nhead "$c")" "1" "기본 브랜치 개명: 커밋하지 않는다"
assert_eq "$(git -C "$c" diff --cached --name-only)" "" "기본 브랜치 개명: 아무것도 stage 하지 않는다"
assert_contains "$o" "원격 기본 브랜치(trunk)가 로컬 기본 브랜치(main)와 다르다" "기본 브랜치 개명: 해결자의 사유를 그대로 보인다"
assert_contains "$o" "기본 브랜치를 판정하지 못했다" "기본 브랜치 개명: 미커밋 줄"
# 5d. AC9 — origin/HEAD 가 없으면 멈추고 고치는 법을 보인다(main/master 대체 없음)
c="$(mk nohead)"; git -C "$c" remote set-head origin -d >/dev/null 2>&1; brief7 "$c" "superpowers:brainstorming 으로 간다."
o="$(runc "$c")"
assert_eq "$(nhead "$c")" "1" "origin/HEAD 없음: 커밋하지 않는다"
assert_contains "$o" "git remote set-head origin --auto" "origin/HEAD 없음: 고치는 법을 보인다"
# 5e. 원격과 대조하지 못하면(오프라인) 알리고 커밋한다
c="$(mk offline)"; git -C "$c" remote set-url origin "$T/no-such-origin.git"; brief7 "$c" "superpowers:brainstorming 으로 간다."
o="$(runc "$c")"
assert_eq "$(files_of_head "$c")" "$THREE" "오프라인: 세 파일을 커밋한다"
assert_contains "$o" "원격과 대조하지 못했다" "오프라인: 대조하지 못했다는 알림을 보인다"

# 6. AC16 — 원자료를 찾은 끝내기: 거절 갈래의 손 목록에도 framing 기록 · seed 가 있다(알 수 있을 때), seed 경로는 상태 파일의 seed: 값이다
SEEDREL=docs/superpowers/interview/2026-10-15-t-seed-interview.md
RECREL=docs/superpowers/interview/2026-10-15-t-seed-interview.audit.md
rawfx() {   # rawfx <클론> [yes 면 커밋까지] → 상태 파일의 seed: 가 가리키는 seed 와 그 옆 framing 기록(원자료가 FOUND 가 되는 꼴)
  printf -- '---\ntype: interview-seed\n---\n# seed\n' > "$1/$SEEDREL"
  printf -- '---\ntype: interview-seed-audit\n---\n## 1. 원문\n\nx\n' > "$1/$RECREL"
  printf -- '---\ntype: interview-state\nseed: %s\n---\nx\n' "$SEEDREL" > "$1/$STEM.state.md"
  if [ "${2:-}" = yes ]; then git -C "$1" add -- "$SEEDREL" "$RECREL" "$STEM.state.md"; git -C "$1" commit -q -m raw; fi
}
hand_of() {   # hand_of <출력> → 「커밋하지 않았다」 줄의 손 목록(「 · 」 로 이은 경로들)을 정렬해 한 줄씩
  printf '%s\n' "$1" | grep '커밋하지 않았다' | sed 's/.*커밋하라: //' | sed 's/ · /\
/g' | LC_ALL=C sort
}
want_of() {   # want_of <클론> <경로들…> → 정렬한 절대경로 목록
  local c="$1" r; shift; for r in "$@"; do printf '%s\n' "$c/$r"; done | LC_ALL=C sort
}
FIVE_REL="$STEM.md $STEM.audit.md $STEM.state.md $SEEDREL $RECREL"
THREE_REL="$STEM.md $STEM.audit.md $STEM.state.md"
five_hand() {   # five_hand <클론> <출력> <라벨> — 손 목록이 다섯 파일 전부이고 하나도 커밋되지 않았다
  assert_eq "$(nhead "$1")" "1" "$3: 커밋하지 않는다"
  assert_eq "$(hand_of "$2")" "$(want_of "$1" $FIVE_REL)" "$3: 손 목록은 결과물 · audit · 상태 파일 · framing 기록 · seed 다섯"
}
c="$(mk raw-main)"; git -C "$c" switch -q main; rawfx "$c"; o="$(runc "$c")"
five_hand "$c" "$o" "기본 브랜치 위(5)"
# 거절 다섯 — framing 기록을 알 수 있는 곳마다
c="$(mk raw-iv 'interview_dir: notes/')"; rawfx "$c"; o="$(runc "$c")"
five_hand "$c" "$o" "인터뷰 폴더 밖(1)"
c="$(mk raw-tree)"; rawfx "$c"; mkdir -p "$T/raw-tree-out"; printf 'x\n' > "$T/raw-tree-out/s.md"
rm -f "$c/$STEM.audit.md"; ln -s "$T/raw-tree-out/s.md" "$c/$STEM.audit.md"; o="$(runc "$c")"
five_hand "$c" "$o" "작업 트리 밖(2)"
c="$(mk raw-nohead)"; git -C "$c" remote set-head origin -d >/dev/null 2>&1; rawfx "$c"; o="$(runc "$c")"
five_hand "$c" "$o" "기본 브랜치 판정 실패(3)"
c="$(mk raw-detached)"; git -C "$c" switch -q --detach; rawfx "$c"; o="$(runc "$c")"
five_hand "$c" "$o" "detached HEAD(4)"
# 모르면 넣지 않는다 — 원자료가 없는 끝내기(상태 파일 seed: 없음) · 이미 커밋돼 변경이 없는 원자료 · 기록 파일을 잃은 원자료
c="$(mk raw-none)"; git -C "$c" switch -q main; printf -- '---\ntype: interview-state\nseed: 없음\n---\nx\n' > "$c/$STEM.state.md"; o="$(runc "$c")"
assert_eq "$(hand_of "$o")" "$(want_of "$c" $THREE_REL)" "원자료 없음: 손 목록은 세 파일"
c="$(mk raw-clean)"; rawfx "$c" yes; git -C "$c" switch -q main; o="$(runc "$c")"
assert_eq "$(hand_of "$o")" "$(want_of "$c" $THREE_REL)" "원자료가 이미 커밋됨: 손 목록은 세 파일(바뀐 것만 든다)"
c="$(mk raw-lost)"; git -C "$c" switch -q main; rawfx "$c"; rm -f "$c/$RECREL"; o="$(runc "$c")"
assert_eq "$(hand_of "$o")" "$(want_of "$c" $THREE_REL)" "기록 파일을 잃음: 찾지 못했으니 손 목록은 세 파일"
# 한 쪽만 바뀐 경우 — seed 만 커밋돼 있고 framing 기록이 바뀐 것 · 그 반대
c="$(mk raw-halfA)"; rawfx "$c"; git -C "$c" add -- "$SEEDREL"; git -C "$c" commit -q -m seedonly; git -C "$c" remote set-head origin -d >/dev/null 2>&1; o="$(runc "$c")"
assert_eq "$(hand_of "$o")" "$(want_of "$c" $THREE_REL $RECREL)" "seed 만 커밋됨: 손 목록에 framing 기록만 더한다"
c="$(mk raw-halfB)"; rawfx "$c"; git -C "$c" add -- "$RECREL"; git -C "$c" commit -q -m recordonly; git -C "$c" remote set-head origin -d >/dev/null 2>&1; o="$(runc "$c")"
assert_eq "$(hand_of "$o")" "$(want_of "$c" $THREE_REL $SEEDREL)" "framing 기록만 커밋됨: 손 목록에 seed 만 더한다"
# 성공 길(기능 브랜치) — 같은 커밋에 다섯
c="$(mk raw-ok)"; rawfx "$c"; o="$(runc "$c")"
assert_eq "$(nhead "$c")" "2" "원자료 있음 · 기능 브랜치: 커밋이 하나 생긴다"
assert_eq "$(git -C "$c" show --name-only --pretty=format: HEAD | sed '/^$/d' | LC_ALL=C sort)" "$(for r in $FIVE_REL; do printf '%s\n' "$r"; done | LC_ALL=C sort)" "원자료 있음 · 기능 브랜치: 다섯 파일이 한 커밋에 든다"
# seed 경로의 출처 — 기록 경로에서 거꾸로 짓지 않고 상태 파일의 seed: 값에서 읽는다.
# raw_source.py locate 가 FOUND 를 낼 때 기록 경로는 seed 이름에서 짓기 때문에(_chain) 두 줄기가 다른 상태는 locate 를 거쳐서는 만들 수 없다 —
# 행동으로는 위 손 목록의 seed 가 상태 파일의 seed: 값(레포 상대 → git 뿌리에 붙임)과 같은 것만 잰다. 출처는 글자 락으로 문다.
case "$cf" in *'RAW_S="${RAW_A%.audit.md}.md"'*) no "AC16(부재): 커밋 펜스가 seed 경로를 기록 경로에서 짓는다" ;; *) ok "AC16(부재): 커밋 펜스가 seed 경로를 기록 경로에서 짓지 않는다" ;; esac
case "$cf" in *'/^seed:/'*'"$STATE_F"'*'RAW_S="${top}/${sv}"'*) ok "AC16(양성 짝): 커밋 펜스가 상태 파일의 seed: 값에서 seed 경로를 얻어 git 뿌리에 붙인다" ;; *) no "AC16(양성 짝): 커밋 펜스가 상태 파일의 seed: 를 읽지 않는다" ;; esac
# 순서 — 첫 거절보다 앞에서 알아 둔다
p_loc="${cf%%raw_source.py\" locate*}"; p_rej="${cf%%check-path intent_dir \"\$BRIEF\"*}"
[ "${#p_loc}" -lt "${#p_rej}" ] && ok "AC16: raw_source.py locate 가 첫 거절(brief 폴더 검사)보다 앞에 있다" || no "AC16: raw_source.py locate 가 첫 거절보다 뒤에 있다"

# 펜스 밖 안내 — README 의 「세 경로를 보입니다」 와 roadmap-draft 의 손 목록 줄이 원자료가 있을 때 framing 기록 · seed 를 댄다
README="$SD/README.md"; RDS="$SD/skills/roadmap-draft/SKILL.md"
assert_contains "$(cat "$README")" "세 경로를 보입니다 — 원자료를 찾았으면 커밋되지 않은 framing 기록 · seed 도 함께 보입니다" "펜스 밖(AC16): README 가 framing 기록 · seed 를 댄다"
assert_contains "$(cat "$RDS")" "아직 커밋되지 않은 framing 기록 · seed 도 그 목록에 댄다" "펜스 밖(AC16): roadmap-draft 의 손 목록 줄이 framing 기록 · seed 를 댄다"
assert_contains "$(cat "$SD/skills/context-build/references/state-file.md")" "원자료를 찾은 컨텍스트 쌓기면 framing 기록 · seed 도 커밋되지 않은 변경이 있을 때 같은 커밋에 든다" "펜스 밖(AC16): 상태 파일 reference 의 끝낼 때가 framing 기록 · seed 를 댄다"

# 6b. 새 글자와 옛 폴더의 일(AC20 · AC25) — 기본 설정이라 새 의도 폴더(intent/)와 옛 의도 폴더(interview/)가 다르다
NEWD=docs/superpowers/intent
OLDD=docs/superpowers/interview
mkb() {   # mkb <이름> → origin 을 가진 클론 · 기능 브랜치 · 두 폴더(파일 없음)
  local o="$T/$1-origin.git" c="$T/$1"
  git init -q --bare -b main "$o"; git clone -q "$o" "$c" 2>/dev/null
  git -C "$c" config user.email t@t.t; git -C "$c" config user.name t
  git -C "$c" commit -q --allow-empty -m init; git -C "$c" push -q origin main 2>/dev/null
  git -C "$c" remote set-head origin main >/dev/null 2>&1
  git -C "$c" switch -q -c feature/x
  mkdir -p "$c/$NEWD" "$c/$OLDD"
  printf '%s' "$c"
}
put3() {   # put3 <클론> <줄기(레포 상대)> [seed 값] → 새로 쓰는 종류 글자의 결과물 · audit · 상태 파일
  printf -- '---\ntype: context-brief\n---\n## 7. Next Action\n\nx\n' > "$1/$2.md"
  printf -- '---\ntype: context-audit\n---\nx\n' > "$1/$2.audit.md"
  printf -- '---\ntype: context-state\nseed: %s\n---\nx\n' "${3:-없음}" > "$1/$2.state.md"
}
runb() { ( cd "$1" && CLAUDE_PLUGIN_ROOT="$SD" bash -c "${cf//"$PH"/$2}" 2>&1 ); }   # runb <클론> <결과물 절대경로>
heads() { git -C "$1" show --name-only --pretty=format: HEAD | sed '/^$/d' | LC_ALL=C sort | tr '\n' ' '; }
sorted() { local r; for r in "$@"; do printf '%s\n' "$r"; done | LC_ALL=C sort | tr '\n' ' '; }
# new_interview_commit — 새 폴더의 새 꼴 세 파일
c="$(mkb new-iv)"; S="$NEWD/2026-11-24-x-context"; put3 "$c" "$S"
o="$(runb "$c" "$c/$S.md")"
assert_eq "$(nhead "$c")" "2" "new_interview_commit: 커밋이 하나 생겼다"
assert_eq "$(heads "$c")" "$(sorted "$S.md" "$S.audit.md" "$S.state.md")" "new_interview_commit: 새 폴더의 새 꼴 세 파일을 한 커밋에"
assert_contains "$o" "[spec-distill] brief · audit · 상태 파일을 커밋했다 — " "new_interview_commit: 성공 줄"
# old_stem_payload_and_commit — 옛 폴더의 옛 꼴 상태 파일로 이어 온 일: 리뷰 넘김 펜스가 그 줄기로 payload 를 짓고, 커밋 펜스가 받는다
A5="$(awk '/^### Step A\.5/{f=1;next} f&&/^### /{exit} f&&/^```bash$/{c=1;b="";next}
  f&&c&&/^```$/{c=0; if (index(b, "STATE_F=\"<상태 파일 절대경로>\"")) {printf "%s", b; exit}; next} f&&c{b=b $0 "\n"}' "$FIN")"
case "$A5" in *'PAYLOAD="${STATE_F%.state.md}.md"'*) ok "전제: 리뷰 넘김 펜스(Step A.5)를 뽑았다" ;; *) no "전제: 리뷰 넘김 펜스를 못 뽑았다 — 아래 칸이 공허하다" ;; esac
c="$(mkb old-stem)"; S="$OLDD/2026-10-01-x-interview"; put3 "$c" "$S"
got="$( cd "$c" && CLAUDE_PLUGIN_ROOT="$SD" bash -c "${A5//<상태 파일 절대경로>/$c/$S.state.md}
printf '%s\n' \"\$PAYLOAD\" \"\$AUDIT\"" 2>&1 )"
assert_eq "$got" "$(printf '%s\n%s' "$c/$S.md" "$c/$S.audit.md")" "old_stem_payload_and_commit: 넘김 펜스의 PAYLOAD · AUDIT 가 옛 폴더 · 옛 줄기다"
o="$(runb "$c" "$(printf '%s\n' "$got" | head -n 1)")"
assert_eq "$(heads "$c")" "$(sorted "$S.md" "$S.audit.md" "$S.state.md")" "old_stem_payload_and_commit: 커밋 펜스가 옛 폴더의 그 세 파일을 받는다"
assert_eq "$(git -C "$c" show "HEAD:$S.md" | sed -n 2p)" "type: context-brief" "old_stem_payload_and_commit: 결과물의 종류 글자는 새 글자다"
got="$( cd "$c" && CLAUDE_PLUGIN_ROOT="$SD" bash -c "${A5//<상태 파일 절대경로>/}" 2>&1 )" && rc=0 || rc=$?
assert_eq "$rc" "1" "넘김 펜스: 상태 파일 자리표가 비면 멈춘다"
# old_seed_new_interview_commit — 옛 폴더의 옛 seed 로 새로 시작한 일: 새 폴더의 새 꼴 결과물 묶음과 옛 폴더의 seed · framing 기록이 한 커밋에(B9)
c="$(mkb old-seed)"; SEED="$OLDD/2026-10-01-s-interview.md"; REC="$OLDD/2026-10-01-s-interview.audit.md"
printf -- '---\ntype: interview-seed\n---\n# seed\n' > "$c/$SEED"
printf -- '---\ntype: interview-seed-audit\n---\n## 1. 원문\n\nx\n' > "$c/$REC"
S="$NEWD/2026-11-24-s-context"; put3 "$c" "$S" "$SEED"
o="$(runb "$c" "$c/$S.md")"
assert_eq "$(nhead "$c")" "2" "old_seed_new_interview_commit: 커밋이 하나 생겼다"
assert_eq "$(heads "$c")" "$(sorted "$S.md" "$S.audit.md" "$S.state.md" "$SEED" "$REC")" "old_seed_new_interview_commit: 다섯 파일이 한 커밋에 든다"
[ "$(nhead "$c")" = 2 ] || printf '      출력: %s\n' "$o"
# old_folder_new_form_rejected — 두 폴더가 다를 때 옛 폴더의 새 꼴 이름은 받지 않는다
c="$(mkb old-newform)"; S="$OLDD/2026-11-24-x-context"; put3 "$c" "$S"
o="$(runb "$c" "$c/$S.md")"
assert_eq "$(nhead "$c")" "1" "old_folder_new_form_rejected: 커밋하지 않는다"
assert_contains "$o" "커밋하지 않았다 — brief 가 정해진 의도 폴더(옛 꼴 파일은 옛 의도 폴더) 바로 아래가 아니다" "old_folder_new_form_rejected: 펜스의 거절 줄"
assert_contains "$o" "옛 의도 폴더(docs/superpowers/interview/)는 옛 꼴 이름" "old_folder_new_form_rejected: 사유가 옛 의도 폴더 규칙을 댄다"
# 글자 — 펜스는 새 키로 판정하고, 결과물 경로를 의도 폴더 + 파일 이름으로 짓지 않는다
assert_file_grep "$FIN" 'PAYLOAD="\$\{STATE_F%\.state\.md\}\.md"' "글자: 리뷰 넘김 펜스가 상태 파일 줄기에서 payload 를 짓는다"
assert_file_absent "$FIN" '\$\{IDIR\}<file>' "글자: 의도 폴더 + 파일 이름으로 payload 를 짓지 않는다"
SKF="$(git -C "$ROOT_REPO" ls-files 'plugins/spec-distill/skills/*')"
[ "$(printf '%s\n' "$SKF" | grep -c .)" -ge 10 ] && ok "글자(양성 짝): skill 파일 $(printf '%s\n' "$SKF" | grep -c .)개" || no "글자: skill 파일 목록이 비었다 — 아래 부재 단언이 공허하다"
hit="$(cd "$ROOT_REPO" && printf '%s\n' "$SKF" | while IFS= read -r f; do grep -lE -- 'check-path interview_dir|get interview_dir' "$f"; done)"
assert_eq "$hit" "" "글자: skill 파일 어디에도 옛 키로 부르는 해결자(check-path · get interview_dir)가 없다"
assert_file_grep "$SD/skills/intent-sync/SKILL.md" '-\$\{TOPIC_ARG\}-intent"' "글자: intent-sync 가 seed 이름을 새 꼴(-intent)로 짓는다"

# 7. 재분해 표 — 세션 상태 폴더가 아니라 펜스의 임시 파일에 쓰이고, 생성기 rc 를 넘기며, 끝나면 지워진다
rf="$(awk '/^## 5\. 적용/{f=1} f&&/^```bash$/{c=1;next} c&&/^```$/{exit} c' "$RED")"
[ -n "$rf" ] && ok "재분해: 적용 펜스를 뽑았다" || no "재분해: 적용 펜스가 비었다 — 아래 칸이 공허하다"
STUB="$T/stub"; mkdir -p "$STUB/scripts"
cat > "$STUB/scripts/roadmap_write.py" <<'PY'
import os, sys
a = sys.argv[1:]
p = a[a.index("--plan-table") + 1]
out = os.environ["STUB_OUT"]
with open(out, "w", encoding="utf-8") as f:
    f.write(p + "\n")
    with open(p, encoding="utf-8") as t:
        f.write(t.read())
sys.exit(int(os.environ.get("STUB_RC", "3")))
PY
TBL='## 분해안

| 번호 | 이름 |'
s="${rf//'<승인된 새 표 — `## 분해안` 머리와 열한 칸 표>'/$TBL}"
mkdir -p "$T/rtmp"
rc=0; o="$(cd "$T" && TMPDIR="$T/rtmp" STUB_OUT="$T/stub.out" CLAUDE_PLUGIN_ROOT="$STUB" bash -c "$s" 2>&1)" || rc=$?
assert_eq "$rc" "3" "재분해: 생성기의 rc 를 그대로 넘긴다"
got_path="$(head -n 1 "$T/stub.out" 2>/dev/null)"
case "$got_path" in "$T/rtmp/redecompose-table."*) ok "재분해: 표는 TMPDIR 의 임시 파일" ;; *) nob "재분해: 표 경로가 임시 파일이 아니다" "$got_path" ;; esac
assert_eq "$(tail -n +2 "$T/stub.out" 2>/dev/null)" "$TBL" "재분해: 승인된 표가 그 파일에 그대로 들어간다"
assert_eq "$(ls -A "$T/rtmp")" "" "재분해: 펜스가 끝나면 임시 파일이 없다"
rc=0; (cd "$T" && TMPDIR="$T/rtmp" STUB_OUT="$T/stub.out" STUB_RC=0 CLAUDE_PLUGIN_ROOT="$STUB" bash -c "$s" >/dev/null 2>&1) || rc=$?
assert_eq "$rc $(ls -A "$T/rtmp")" "0 " "재분해: 성공(rc 0)에서도 임시 파일이 없다"

# 8. 재분해 사용자 말 · 사유 · 경로(AC14) — 따옴표 · 명령 치환 · 역따옴표 · 「-」 머리가 든 글도 셸로 새지 않고 글자 그대로 생성기로 간다
STUB2="$T/stub2"; mkdir -p "$STUB2/scripts"
cat > "$STUB2/scripts/roadmap_write.py" <<'PY'
import argparse, json, os, sys
p = argparse.ArgumentParser()
sub = p.add_subparsers(dest="cmd")
u = sub.add_parser("update")
for k in ("--roadmap", "--brief", "--audit", "--plan-table", "--date", "--change"):
    u.add_argument(k, required=True)
u.add_argument("--approval", action="append", required=True)
a = p.parse_args()
with open(os.environ["STUB_OUT"], "w", encoding="utf-8") as f:
    json.dump({"roadmap": a.roadmap, "brief": a.brief, "audit": a.audit, "change": a.change, "approval": a.approval}, f, ensure_ascii=False)
sys.exit(0)
PY
red_fill() {   # red_fill <사용자 말> <사유> <경로 머리> → 표 · 사용자 말 · 사유 · 세 경로 자리를 채운 적용 펜스
  printf '%s' "$rf" | python3 -I -c 'import sys
t = sys.stdin.read()
for k, v in (("<승인된 새 표 — `## 분해안` 머리와 열한 칸 표>", sys.argv[1]), ("<사용자 말 그대로>", sys.argv[2]), ("<사유 한 줄>", sys.argv[3]),
             ("<로드맵 경로>", sys.argv[4] + "/roadmap.md"), ("<원본 brief>", sys.argv[4] + "/b.md"), ("<원본 audit>", sys.argv[4] + "/b.audit.md")):
    if k not in t:
        sys.exit("자리표 없음: " + k)
    t = t.replace(k, v)
sys.stdout.write(t)' "$TBL" "$1" "$2" "$3"
}
HP="$T/r'oad\"map \$(touch $T/pwned-p) \`touch $T/pwned-q\`"
n8=0
for W in "말 \"따옴표\" it's \$(touch $T/pwned-a) \`touch $T/pwned-b\` \$HOME" '-좋아'; do
  n8=$((n8 + 1))
  if [ "$n8" = 1 ]; then C="\`R3\` 을 \"둘로\" 나눔 it's \$(touch $T/pwned-c) \`touch $T/pwned-d\`"; P="$HP"; else C='-순서만'; P='-rel/docs'; fi
  rm -f "$T/stub2.out"
  rc=0; o="$(cd "$T" && TMPDIR="$T/rtmp" STUB_OUT="$T/stub2.out" CLAUDE_PLUGIN_ROOT="$STUB2" bash -c "$(red_fill "$W" "$C" "$P")" 2>&1)" || rc=$?
  got="$(python3 -I -c 'import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
print(d == {"roadmap": sys.argv[4] + "/roadmap.md", "brief": sys.argv[4] + "/b.md", "audit": sys.argv[4] + "/b.audit.md", "change": sys.argv[3], "approval": [sys.argv[2]]})' "$T/stub2.out" "$W" "$C" "$P" 2>&1)"
  assert_eq "$rc $got" "0 True" "재분해(AC14): 사용자 말 · 사유 · 세 경로가 글자 그대로 생성기로 간다 — 칸 $n8"
  [ "$rc" -eq 0 ] || printf '      출력: %s\n' "$o"
  assert_eq "$(ls "$T" | grep -c '^pwned-')" "0" "재분해(AC14): 말 · 사유 · 경로 안의 명령이 돌지 않았다 — 칸 $n8"
  assert_eq "$(ls -A "$T/rtmp")" "" "재분해(AC14): 펜스가 끝나면 임시 파일이 없다 — 칸 $n8"
done

# 9. 재분해 손 편집의 허가 걸음(AC13) · rc 1 가르기(AC16) · extract 펜스의 경로(따옴표 heredoc)
RT="$(cat "$RED")"
for n in '표 행을 고치기 전에' '`docreview_state.py declare-related --state-dir D --decision <D#> --anchors' '채택한 결정이 없으면' \
         '다음 게이트에 「허가 없이 바뀜」 결정으로 다시 온다' \
         '`## 미룸` 표 행도 묶는다' '`## 미룸` 절을 새로 만들면 그 자리를 `insert-after:<그 앞 절 앵커>` 로 묶는다' \
         '묶을 수 없는 것은 `## 결정 기록` 과 프로필의 미룸 자리(`### Deferred to plan`)뿐이다' \
         '`declare-related` 가 rc 0 이 아니면' \
         'brief §5 위험 줄 가운데 K 번호가 없는 줄' 'brief §5 위험 줄의 K 번호가 겹친다' '표로 돌아가지 않고 멈추고 사유를 보인다' \
         '재분해는 이력 brief 를 고치지 않는다' '`RISK_ORDER_NOTICE`' '정보 줄이라 멈추지 않는다'; do
  assert_contains "$RT" "$n" "재분해(AC13·AC16): $n"
done
# 엔진 울타리 = 불변 ∪ 결정 기록 ∪ 프로필 미룸 자리(`### Deferred to plan`) — `## 미룸` 표는 보통 절이라 묶인다
# (shared/tests/fixtures/docreview/cases.sh 의 case_AC13_table_rows_bound_with_declare 가 엔진에서 잰다).
assert_not_contains "$RT" '미룸 절은 엔진 울타리' "재분해(AC13): \`## 미룸\` 을 엔진 울타리라 부르지 않는다(양성 짝: 위 「묶을 수 없는 것은 …뿐이다」)"
assert_not_contains "$RT" '`## 미룸` · `## 결정 기록` 밖의 고친 절' "재분해(AC13): 묶을 절에서 \`## 미룸\` 을 빼지 않는다(양성 짝: 위 「표 행도 묶는다」)"
assert_not_contains "$RT" 'rc 1 — 사유를 그대로 보이고 3 으로 돌아간다' "재분해(AC16): 옛 단일 갈래 문장(위험 줄 사유까지 표로 돌아가게 하는 꼴)이 없다(양성 짝: 위 가름 문장)"
# RISK_ORDER_NOTICE 는 생성기가 rc 0 길에서만 낸다(roadmap_write.py) — rc 1 갈래 목록 안에 두지 않는다.
rc1_items="$(awk '/rc 1 은 사유로 가른다/{f=1;next} f&&/^  - /{print;next} f{exit}' "$RED")"
case "$rc1_items" in *'그 밖의 사유'*) ok "재분해(AC16): rc 1 갈래 목록을 뽑았다" ;; *) no "재분해(AC16): rc 1 갈래 목록이 비었다 — 아래 칸이 공허하다" ;; esac
assert_not_contains "$rc1_items" 'RISK_ORDER_NOTICE' "재분해(AC16): RISK_ORDER_NOTICE 는 rc 1 갈래가 아니다"
assert_eq "$(grep -c '^- rc 0 이면 .*`RISK_ORDER_NOTICE`' "$RED")" "1" "재분해(AC16): RISK_ORDER_NOTICE 는 rc 0 길의 항목이다"
extract_fence() {   # extract_fence <파일> → `## 2. 지금 표` 절 안에서 extract 를 부르는 bash 펜스(다음 `## ` 머리에서 멈춘다)
  awk '/^## 2\. 지금 표/{f=1;next} f&&/^## /{exit} f&&/^```bash$/{c=1;b="";next}
       c&&/^```$/{c=0; if (index(b, "roadmap_write.py\" extract")) {printf "%s", b; exit}; next} c{b=b $0 "\n"}' "$1"
}
ef="$(extract_fence "$RED")"
[ -n "$ef" ] && ok "재분해: extract 펜스를 뽑았다" || no "재분해: extract 펜스가 비었다 — 아래 칸이 공허하다"
printf '## 2. 지금 표\n\n펜스 없음.\n\n## 3. 영향 보이기\n\n```bash\necho roadmap_write.py" extract leak\n```\n' > "$T/ef-probe.md"
assert_eq "$(extract_fence "$T/ef-probe.md")" "" "재분해: extract 펜스 추출은 2 절 밖(다음 \`## \` 절)의 펜스를 집지 않는다(양성 짝: 위 실제 문서 추출)"
assert_not_contains "$ef" '"<' "재분해(AC14): extract 펜스에 따옴표로 감싼 모델 채움 자리가 없다(양성 짝: 아래 실행 칸)"
STUB3="$T/stub3"; mkdir -p "$STUB3/scripts"
cat > "$STUB3/scripts/roadmap_write.py" <<'PY'
import argparse, json, os, sys
p = argparse.ArgumentParser()
sub = p.add_subparsers(dest="cmd")
e = sub.add_parser("extract")
e.add_argument("--roadmap", required=True)
a = p.parse_args()
with open(os.environ["STUB_OUT"], "w", encoding="utf-8") as f:
    json.dump({"roadmap": a.roadmap}, f, ensure_ascii=False)
PY
for HX in "$HP/roadmap.md" '-rel/roadmap.md'; do
  s3="${ef//'<로드맵 경로>'/$HX}"
  rm -f "$T/stub3.out"
  rc=0; o="$(cd "$T" && STUB_OUT="$T/stub3.out" CLAUDE_PLUGIN_ROOT="$STUB3" bash -c "$s3" 2>&1)" || rc=$?
  got="$(python3 -I -c 'import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8")) == {"roadmap": sys.argv[2]})' "$T/stub3.out" "$HX" 2>&1)"
  assert_eq "$rc $got" "0 True" "재분해(AC14): extract 펜스가 경로를 글자 그대로 생성기로 넘긴다 — $HX"
  assert_eq "$(ls "$T" | grep -c '^pwned-')" "0" "재분해(AC14): extract 펜스의 경로 안 명령이 돌지 않았다"
done

finish
