#!/usr/bin/env bash
# R4 × R7 이음매 — 분해된 일의 끝내기 커밋(interview-commit 펜스)과 재분해 표의 자리.
# 로드맵 폴더는 펜스가 brief §7 의 첫 `분해됨 — <로드맵 경로>` 줄에서 도출한다.
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
FIN="$SD/skills/pm-interview/references/finishing.md"
RED="$SD/references/redecompose.md"
PH='<Step A.5 의 PAYLOAD 절대경로>'
cf="$(fence "$FIN" interview-commit)"
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
FIVE="${THREE}$RREL/R1.md $RREL/roadmap.md "
DEC="분해됨 — $RREL/roadmap.md"

# 1. 분해된 일 — 세 파일 + 로드맵 폴더가 한 커밋
c="$(mk dec)"; roadmap "$c"; brief7 "$c" "$DEC"
printf 'y\n' > "$c/other.txt"; git -C "$c" add other.txt
o="$(runc "$c")"
assert_eq "$(nhead "$c")" "2" "분해: 커밋이 하나 생겼다"
assert_eq "$(files_of_head "$c")" "$FIVE" "분해: 세 파일과 로드맵 폴더가 한 커밋에"
assert_contains "$o" "brief · audit · 상태 파일 · 로드맵 폴더를 커밋했다" "분해: 로드맵 폴더까지 커밋한 사실을 보인다"
git -C "$c" diff --cached --name-only | grep -qx other.txt && ok "분해: 이미 stage 된 다른 파일은 stage 된 채로" || nob "분해: stage 된 다른 파일이 사라졌다" "$o"
# §7 경로가 절대경로여도 · 목록 · 코드 꼴이어도 같다
c="$(mk dec-abs)"; roadmap "$c"; brief7 "$c" "분해됨 — $c/$RREL/roadmap.md"
o="$(runc "$c")"
assert_eq "$(files_of_head "$c")" "$FIVE" "분해(§7 절대경로): 세 파일과 로드맵 폴더가 한 커밋에"
c="$(mk dec-code)"; roadmap "$c"; brief7 "$c" "- \`$DEC\`"
o="$(runc "$c")"
assert_eq "$(files_of_head "$c")" "$FIVE" "분해(§7 목록 · 코드 꼴): 세 파일과 로드맵 폴더가 한 커밋에"

# 1b. 해결자는 cwd 가 아니라 brief 가 사는 레포를 기준으로 돈다 — 다른 설정을 가진 레포 안에서 돌려도 같다
c="$(mk elsewhere)"; roadmap "$c"; brief7 "$c" "$DEC"
x="$(mk cwdrepo 'interview_dir: notes/')"
o="$( cd "$x" && CLAUDE_PLUGIN_ROOT="$SD" bash -c "${cf//"$PH"/$c/$STEM.md}" 2>&1 )"
assert_eq "$(files_of_head "$c")" "$FIVE" "다른 레포에서 돌림: brief 레포의 설정으로 세 파일과 로드맵 폴더가 한 커밋에"
assert_eq "$(nhead "$x")" "1" "다른 레포에서 돌림: cwd 레포에는 커밋하지 않는다"
# 2. 나누지 않은 일 — §7 에 분해됨 줄이 없으면 로드맵 폴더가 있어도 세 파일만
c="$(mk nodec)"; roadmap "$c"; brief7 "$c" "superpowers:brainstorming 으로 간다."
o="$(runc "$c")"
assert_eq "$(files_of_head "$c")" "$THREE" "나누지 않음: 세 파일만 커밋"
assert_contains "$o" "brief · audit · 상태 파일을 커밋했다" "나누지 않음: 세 파일 커밋 줄"
assert_eq "$(git -C "$c" status --porcelain -- "$RREL" | sed '/^$/d' | wc -l | tr -d ' ')" "1" "나누지 않음: 로드맵 폴더는 커밋되지 않고 남는다"
# §7 밖의 분해됨 줄은 세지 않는다
c="$(mk outside7)"; roadmap "$c"
printf -- '---\ntype: interview-brief\n---\n## 2. 제약\n\n%s\n\n## 7. Next Action\n\nbrainstorming.\n' "$DEC" > "$c/$STEM.md"
o="$(runc "$c")"
assert_eq "$(files_of_head "$c")" "$THREE" "§7 밖의 분해됨 줄은 분해 신호가 아니다"

# 3. 분해됐지만 로드맵 폴더가 없다 — 알리고 세 파일은 커밋한다
c="$(mk gone)"; brief7 "$c" "$DEC"
o="$(runc "$c")"
assert_eq "$(files_of_head "$c")" "$THREE" "폴더 없음: 세 파일은 커밋된다"
assert_contains "$o" "로드맵 폴더가 없어 빼고 진행한다: $c/$RREL" "폴더 없음: 뺀 사실과 폴더를 보인다"

# 4. 빈 로드맵 폴더 — add 는 받아도 commit 경로 지정이 실패하므로 뺀다
c="$(mk empty)"; mkdir -p "$c/$RREL"; brief7 "$c" "$DEC"
o="$(runc "$c")"
assert_eq "$(files_of_head "$c")" "$THREE" "빈 폴더: 세 파일은 커밋된다"
assert_contains "$o" "로드맵 폴더에 커밋할 파일이 없어 빼고 진행한다" "빈 폴더: 뺀 사실을 보인다"
# 4b. 작업 트리에는 파일이 있어도 git 이 무시하는 파일뿐이면 커밋할 파일이 없다(.DS_Store 꼴)
c="$(mk ignored)"; mkdir -p "$c/$RREL"; printf 'junk\n' > "$c/$RREL/.DS_Store"; printf '.DS_Store\n' >> "$c/.git/info/exclude"; brief7 "$c" "$DEC"
o="$(runc "$c")"
assert_eq "$(files_of_head "$c")" "$THREE" "무시 파일뿐인 폴더: 세 파일은 커밋된다"
assert_contains "$o" "로드맵 폴더에 커밋할 파일이 없어 빼고 진행한다" "무시 파일뿐인 폴더: 뺀 사실을 보인다"

# 5. 거부 — 커밋 · stage 0, 사유 한 줄에 경로들
refused() {   # refused <클론> <출력> <라벨> <사유 조각>
  assert_eq "$(nhead "$1")" "1" "$3: 커밋하지 않는다"
  assert_eq "$(git -C "$1" diff --cached --name-only)" "" "$3: 아무것도 stage 하지 않는다"
  case "$2" in *"커밋하지 않았다"*"$4"*"$STEM.state.md"*) ok "$3: 사유와 경로를 보인다" ;; *) nob "$3: 사유 · 경로가 없다" "$2" ;; esac
}
# 5a. 부모가 docs 다(너무 넓은 폴더)
c="$(mk wide)"; mkdir -p "$c/docs/x"; printf 'r\n' > "$c/docs/x/roadmap.md"; printf 'u\n' > "$c/docs/stray.md"
brief7 "$c" "분해됨 — docs/x/roadmap.md"
o="$(runc "$c")"; refused "$c" "$o" "부모가 docs" "정해진 로드맵 폴더 바로 아래가 아니다"
assert_contains "$o" "부모 폴더가 다르다" "부모가 docs: 해결자의 사유를 그대로 보인다"
# 5b. roadmaps 자체(roadmaps/roadmap.md)
c="$(mk wide2)"; roadmap "$c"; brief7 "$c" "분해됨 — docs/superpowers/roadmaps/roadmap.md"
o="$(runc "$c")"; refused "$c" "$o" "roadmaps 폴더 자체" "정해진 로드맵 폴더 바로 아래가 아니다"
# 5c. 이름이 . 인 폴더(= roadmaps 전체)
c="$(mk dot)"; roadmap "$c"; brief7 "$c" "분해됨 — docs/superpowers/roadmaps/./roadmap.md"
o="$(runc "$c")"; refused "$c" "$o" "폴더 이름 ." "정해진 로드맵 폴더 바로 아래가 아니다"
# 5d. §7 경로의 파일이 로드맵이 아니다(머리말 type: roadmap 없음) — roadmap-check 가 거부한다
c="$(mk notrm)"; roadmap "$c"; brief7 "$c" "분해됨 — $RREL/R1.md"
o="$(runc "$c")"; refused "$c" "$o" "로드맵 아님" "로드맵 꼴이 아니다"
assert_contains "$o" "로드맵이 아니다" "로드맵 아님: 해결자의 사유를 그대로 보인다"
# 양의 짝 — 이름이 roadmap.md 가 아니어도 머리말 type: roadmap 이면 로드맵이다
c="$(mk othername)"; roadmap "$c"; mv -- "$c/$RREL/roadmap.md" "$c/$RREL/plan.md"
brief7 "$c" "분해됨 — $RREL/plan.md"
o="$(runc "$c")"
assert_eq "$(files_of_head "$c")" "${THREE}$RREL/R1.md $RREL/plan.md " "다른 이름의 로드맵: 세 파일과 로드맵 폴더가 한 커밋에"
# 5g. 대소문자만 다른 경로 — 부모 · 폴더 어느 쪽이든 멈춘다
c="$(mk case1)"; roadmap "$c"; brief7 "$c" "분해됨 — docs/superpowers/Roadmaps/2026-10-15-t/roadmap.md"
o="$(runc "$c")"; refused "$c" "$o" "대소문자(부모)" "정해진 로드맵 폴더 바로 아래가 아니다"
assert_contains "$o" "대소문자만 다른 경로" "대소문자(부모): 해결자의 사유를 보인다"
c="$(mk case2)"; roadmap "$c"; brief7 "$c" "분해됨 — docs/superpowers/roadmaps/2026-10-15-T/roadmap.md"
o="$(runc "$c")"; refused "$c" "$o" "대소문자(폴더)" "정해진 로드맵 폴더 바로 아래가 아니다"
assert_contains "$o" "대소문자만 다른 경로" "대소문자(폴더): 해결자의 사유를 보인다"
# 5h. 레포 설정 roadmaps_dir — 설정의 폴더가 기준이다
c="$(mk cfg-ok 'roadmaps_dir: plan/roadmaps/')"; roadmap "$c" plan/roadmaps/x; brief7 "$c" "분해됨 — plan/roadmaps/x/roadmap.md"
o="$(runc "$c")"
assert_eq "$(files_of_head "$c")" "${THREE}plan/roadmaps/x/R1.md plan/roadmaps/x/roadmap.md " "설정 roadmaps_dir: 설정 폴더 아래 로드맵 폴더가 한 커밋에"
c="$(mk cfg-def 'roadmaps_dir: plan/roadmaps/')"; roadmap "$c" docs/superpowers/roadmaps/x; brief7 "$c" "분해됨 — docs/superpowers/roadmaps/x/roadmap.md"
o="$(runc "$c")"; refused "$c" "$o" "설정 roadmaps_dir · 기본 자리" "정해진 로드맵 폴더 바로 아래가 아니다"
# 5i. 레포 설정 interview_dir — brief 가 그 폴더 바로 아래가 아니면 멈춘다
c="$(mk cfg-iv 'interview_dir: notes/')"; brief7 "$c" "superpowers:brainstorming 으로 간다."
o="$(runc "$c")"; refused "$c" "$o" "설정 interview_dir · 다른 자리" "정해진 인터뷰 폴더 바로 아래가 아니다"
# 5e. 폴더 자리가 파일이다
c="$(mk notdir)"; mkdir -p "$c/docs/superpowers/roadmaps"; printf 'f\n' > "$c/$RREL"; brief7 "$c" "$DEC"
o="$(runc "$c")"; refused "$c" "$o" "폴더 아님" "폴더가 아니다"
# 5f. 보안 — 로드맵 폴더가 밖의 폴더로 가는 링크 · 끊긴 링크
c="$(mk link)"; mkdir -p "$T/outside-rm" "$c/docs/superpowers/roadmaps"; printf '밖\n' > "$T/outside-rm/roadmap.md"
ln -s "$T/outside-rm" "$c/$RREL"; brief7 "$c" "$DEC"
o="$(runc "$c")"; refused "$c" "$o" "보안: 링크" "링크"
assert_eq "$(cat "$T/outside-rm/roadmap.md")" "밖" "보안: 링크 너머 파일은 그대로"
c="$(mk dangling)"; mkdir -p "$c/docs/superpowers/roadmaps"; ln -s "$T/no-such-dir" "$c/$RREL"; brief7 "$c" "$DEC"
o="$(runc "$c")"; refused "$c" "$o" "보안: 끊긴 링크" "$RREL"

# 6. 기본 브랜치 — 분해된 일이면 「커밋하지 않았다」 줄에 로드맵 폴더도 적는다
c="$(mk onmain)"; git -C "$c" switch -q main; roadmap "$c"; brief7 "$c" "$DEC"
o="$(runc "$c")"
assert_eq "$(nhead "$c")" "1" "기본 브랜치: 커밋하지 않는다"
case "$o" in *"커밋하지 않았다"*"$c/$RREL"*) ok "기본 브랜치: 미커밋 줄에 로드맵 폴더" ;; *) nob "기본 브랜치: 미커밋 줄에 로드맵 폴더가 없다" "$o" ;; esac
# 6b. AC11 — 로컬 브랜치 origin/main 이 있어도 기본 브랜치 검사가 켜져 있다
c="$(mk shadow)"; git -C "$c" branch origin/main main; git -C "$c" switch -q main; brief7 "$c" "superpowers:brainstorming 으로 간다."
o="$(runc "$c")"
assert_eq "$(nhead "$c")" "1" "로컬 브랜치 origin/main: 기본 브랜치 위 커밋을 거부한다"
assert_contains "$o" "지금 기본 브랜치(main)에 있다" "로컬 브랜치 origin/main: 기본 브랜치 이름을 보인다"
# 6c. AC10 — 원격의 기본 브랜치가 바뀌었는데 로컬 origin/HEAD 가 옛 이름이면 멈춘다
c="$(mk renamed)"; git -C "$T/renamed-origin.git" branch trunk main; git -C "$T/renamed-origin.git" symbolic-ref HEAD refs/heads/trunk
brief7 "$c" "superpowers:brainstorming 으로 간다."
o="$(runc "$c")"
assert_eq "$(nhead "$c")" "1" "기본 브랜치 개명: 커밋하지 않는다"
assert_eq "$(git -C "$c" diff --cached --name-only)" "" "기본 브랜치 개명: 아무것도 stage 하지 않는다"
assert_contains "$o" "원격 기본 브랜치(trunk)가 로컬 기본 브랜치(main)와 다르다" "기본 브랜치 개명: 해결자의 사유를 그대로 보인다"
assert_contains "$o" "기본 브랜치를 판정하지 못했다" "기본 브랜치 개명: 미커밋 줄"
# 6d. AC9 — origin/HEAD 가 없으면 멈추고 고치는 법을 보인다(main/master 대체 없음)
c="$(mk nohead)"; git -C "$c" remote set-head origin -d >/dev/null 2>&1; brief7 "$c" "superpowers:brainstorming 으로 간다."
o="$(runc "$c")"
assert_eq "$(nhead "$c")" "1" "origin/HEAD 없음: 커밋하지 않는다"
assert_contains "$o" "git remote set-head origin --auto" "origin/HEAD 없음: 고치는 법을 보인다"
# 6e. 원격과 대조하지 못하면(오프라인) 알리고 커밋한다
c="$(mk offline)"; git -C "$c" remote set-url origin "$T/no-such-origin.git"; brief7 "$c" "superpowers:brainstorming 으로 간다."
o="$(runc "$c")"
assert_eq "$(files_of_head "$c")" "$THREE" "오프라인: 세 파일을 커밋한다"
assert_contains "$o" "원격과 대조하지 못했다" "오프라인: 대조하지 못했다는 알림을 보인다"

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
