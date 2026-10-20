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
mk() {   # mk <이름> → origin 을 가진 클론, 기능 브랜치, docs 에 세 파일(brief 는 §7 없이)
  local o="$T/$1-origin.git" c="$T/$1"
  git init -q --bare -b main "$o"; git clone -q "$o" "$c" 2>/dev/null
  git -C "$c" config user.email t@t.t; git -C "$c" config user.name t
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
roadmap() {   # roadmap <클론> → 생성기가 만든 꼴의 로드맵 폴더
  mkdir -p "$1/$RREL"; printf '# 로드맵\n' > "$1/$RREL/roadmap.md"; printf '# R1\n' > "$1/$RREL/R1.md"
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

# 5. 거부 — 커밋 · stage 0, 사유 한 줄에 경로들
refused() {   # refused <클론> <출력> <라벨> <사유 조각>
  assert_eq "$(nhead "$1")" "1" "$3: 커밋하지 않는다"
  assert_eq "$(git -C "$1" diff --cached --name-only)" "" "$3: 아무것도 stage 하지 않는다"
  case "$2" in *"커밋하지 않았다"*"$4"*"$STEM.state.md"*) ok "$3: 사유와 경로를 보인다" ;; *) nob "$3: 사유 · 경로가 없다" "$2" ;; esac
}
# 5a. 부모가 docs 다(너무 넓은 폴더)
c="$(mk wide)"; mkdir -p "$c/docs/x"; printf 'r\n' > "$c/docs/x/roadmap.md"; printf 'u\n' > "$c/docs/stray.md"
brief7 "$c" "분해됨 — docs/x/roadmap.md"
o="$(runc "$c")"; refused "$c" "$o" "부모가 docs" "docs/superpowers/roadmaps 바로 아래가 아니다"
# 5b. roadmaps 자체(roadmaps/roadmap.md)
c="$(mk wide2)"; roadmap "$c"; brief7 "$c" "분해됨 — docs/superpowers/roadmaps/roadmap.md"
o="$(runc "$c")"; refused "$c" "$o" "roadmaps 폴더 자체" "docs/superpowers/roadmaps 바로 아래가 아니다"
# 5c. 이름이 . 인 폴더(= roadmaps 전체)
c="$(mk dot)"; roadmap "$c"; brief7 "$c" "분해됨 — docs/superpowers/roadmaps/./roadmap.md"
o="$(runc "$c")"; refused "$c" "$o" "폴더 이름 ." "이 . 이나 .. 다"
# 5d. §7 경로가 roadmap.md 로 끝나지 않는다
c="$(mk notrm)"; roadmap "$c"; brief7 "$c" "분해됨 — $RREL/R1.md"
o="$(runc "$c")"; refused "$c" "$o" "roadmap.md 아님" "roadmap.md 로 끝나지 않는다"
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

finish
