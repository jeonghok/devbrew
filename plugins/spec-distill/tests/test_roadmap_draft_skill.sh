#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/* plugins/spec-distill/references/*
# roadmap-draft skill 글 · 커밋 펜스 락(AC6 · AC7 · AC8 · AC9 · AC11 · AC12 · AC13 · AC14).
# 정적 락이다 — 모델이 이 글을 실제로 따르는지는 재지 못한다. 커밋 펜스(roadmap-commit)만 뽑아 임시 저장소에서 돌린다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_roadmap_draft_skill.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT/plugins/spec-distill"
if [ "${1:-}" = "--emit-scanned" ]; then   # 읽는 파일: roadmap-draft 글 + 부재 단언의 코퍼스(skill 글 · reference)
  git -C "$ROOT" ls-files -- plugins/spec-distill/skills plugins/spec-distill/references
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
unset DEVBREW_SPEC_DISTILL_DISABLE DEVBREW_SKIP_HOOKS
SK="$SD/skills/roadmap-draft/SKILL.md"
T="$(mktemp -d)"; [ -n "$T" ] && [ -d "$T" ] || { echo "mktemp 실패"; exit 1; }
T="$(cd "$T" && pwd -P)"; trap 'rm -rf "$T"' EXIT

has() {    # has <파일> <리터럴>
  if grep -qF -- "$2" "$1" 2>/dev/null; then ok "${1#"$ROOT"/}: 「$2」"; else no "${1#"$ROOT"/}: 「$2」 가 없다"; fi
}
lacks() {  # lacks <파일> <리터럴> — 파일이 없으면 실패(공허한 통과를 막는다)
  if [ ! -f "$1" ]; then no "${1#"$ROOT"/}: 파일이 없다 — 부재 단언이 공허하다"; return; fi
  if grep -qF -- "$2" "$1"; then no "${1#"$ROOT"/}: 「$2」 가 있다"; else ok "${1#"$ROOT"/}: 「$2」 가 없다"; fi
}
lacks_all() {  # lacks_all <리터럴> — spec-distill 의 skill 글 · reference 전부(추적된 파일)
  local files hit
  files="$(git -C "$ROOT" ls-files -- plugins/spec-distill/skills plugins/spec-distill/references)"
  case "$files" in *"plugins/spec-distill/skills/roadmap-draft/SKILL.md"*) ok "코퍼스(양성 짝): skill 글 · reference $(printf '%s\n' "$files" | grep -c .)개에 roadmap-draft 가 든다" ;;
    *) no "코퍼스(양성 짝): roadmap-draft 가 코퍼스에 없다 — 부재 단언이 공허하다" ;; esac
  hit="$(git -C "$ROOT" grep -lF -- "$1" -- plugins/spec-distill/skills plugins/spec-distill/references)"
  assert_eq "$hit" "" "skill 글 · reference 어디에도 「$1」 가 없다"
}
fence() {  # fence <파일> <마커 이름> → 그 마커 사이 첫 bash 펜스 본문
  awk -v b="<!-- $2:begin -->" -v e="<!-- $2:end -->" '
    index($0,b){f=1;next} index($0,e){f=0} f&&/^```bash$/{c=1;next} f&&c&&/^```$/{c=0;next} f&&c' "$1"
}
nob() { no "$1"; printf '      출력: %s\n' "$2"; }

[ -f "$SK" ] && ok "roadmap-draft SKILL.md 가 있다" || no "roadmap-draft SKILL.md 가 없다"

# ── 진입 · 다시 불렀을 때(AC6) ─────────────────────────────────────────────────
has "$SK" 'python3 "$SD/scripts/roadmap_draft_entry.py" --brief'
has "$SK" '「그 표에서 이어 간다」 · 「표를 버리고 처음부터」'
# ── 읽기(AC7 · AC12) ───────────────────────────────────────────────────────────
has "$SK" '결과물 전문 · audit · 상태 파일과, 찾았으면 원자료를 읽은 뒤에 표를 제안한다'
has "$SK" '같은 세션에서 이어 왔어도 대화가 아니라 이 읽기부터 한다'
# ── 나누기 전 확인(AC13) ───────────────────────────────────────────────────────
has "$SK" '에픽마다 고칠 자리를 코드에서 열어 확인하고, 경로 예약에 그 근거를 함께 적는다'
has "$SK" '표의 경로 예약 칸에는 경로만 쓴다 — 스크립트가 그 칸을 경로 목록으로 읽는다'   # 근거를 칸에 넣으면 겹침 · 예약 밖 판정이 깨진다
has "$SK" '근거는 표 아래에 에픽마다 한 줄로'
has "$SK" '`<file>` 자리에는 `<결과물 절대경로>` 의 마지막 경로 성분(결과물 파일 이름)만 넣는다'
has "$SK" '다른 로드맵의 경로 예약과 겹치는지 본다 — 겹침은 막지 않고 표 아래에 보인다'
# ── 분해안 표 · 고치기(AC8) ────────────────────────────────────────────────────
has "$SK" 'python3 "$SD/scripts/roadmap_write.py" check --brief'
has "$SK" '고친 횟수: '
lacks_all 'decompose_edits'
# ── 생성(AC14 · AC9) ───────────────────────────────────────────────────────────
has "$SK" 'roadmap_write.py" create --brief'
lacks "$SK" '--layout'
RD_FILES="$(git -C "$ROOT" ls-files 'plugins/spec-distill/skills/roadmap-draft/*')"
[ -n "$RD_FILES" ] && ok "roadmap-draft 추적 파일 $(printf '%s\n' "$RD_FILES" | grep -c .)개(양성 짝)" || no "roadmap-draft 추적 파일이 없다 — 아래 부재 단언이 공허하다"
for f in $RD_FILES; do lacks "$ROOT/$f" '다시 생성'; done
has "$SK" '실패해 표를 고친 뒤 다시 도는 것과 끊긴 뒤 이어 가며 도는 것은 같은 생성 기록 위에서 그 기록의 파일만 덮어쓴다'
# ── 커밋(AC10 의 커밋 몫) ─────────────────────────────────────────────────────
has "$SK" '<!-- roadmap-commit:begin -->'
has "$SK" 'docs(roadmap): '
# ── 되돌아가는 길(AC11) ────────────────────────────────────────────────────────
has "$SK" '§7 의 `분해됨` 줄을 지우는 것 하나뿐이다'
has "$SK" '생성 기록의 파일 지우기 · 상태 파일의 두 절 비우기 · `분해됨` 줄 지우기를 한 커밋에 넣는다'
has "$SK" '「spec 하나로」 · 그 결과물을 입력으로 새 `/spec-distill:context-build`'

# ── 커밋 펜스 동작 — 펜스를 뽑아 임시 저장소에서 돌린다 ───────────────────────
PH='<결과물 절대경로>'
cf="$(fence "$SK" roadmap-commit)"
case "$cf" in *"BRIEF=\"$PH\""*) ok "전제: 커밋 펜스에 BRIEF 자리표" ;; *) no "전제: 커밋 펜스를 못 뽑았거나 BRIEF 자리표가 없다 — 아래 칸이 공허하다" ;; esac
STEM=docs/superpowers/interview/2026-10-15-t-interview
RREL=docs/superpowers/roadmaps/2026-10-15-t
mk() {   # mk <이름> <§7 첫 줄> [레포 설정 머리말 줄] → origin 을 가진 클론 · 기능 브랜치 · 커밋된 결과물 · audit · 상태 파일
  local o="$T/$1-origin.git" c="$T/$1"
  git init -q --bare -b main "$o"; git clone -q "$o" "$c" 2>/dev/null
  git -C "$c" config user.email t@t.t; git -C "$c" config user.name t; git -C "$c" config commit.gpgsign false
  if [ -n "${3:-}" ]; then printf -- '---\n%s\n---\n' "$3" > "$c/.devbrew.md"; git -C "$c" add -- .devbrew.md; fi
  git -C "$c" commit -q --allow-empty -m init; git -C "$c" push -q origin main 2>/dev/null
  git -C "$c" remote set-head origin main >/dev/null 2>&1
  git -C "$c" switch -q -c feature/x
  mkdir -p "$c/docs/superpowers/interview"
  printf -- '---\ntype: interview-brief\n---\n## 7. Next Action\n\n%s\n' "$2" > "$c/$STEM.md"
  printf '# audit\n' > "$c/$STEM.audit.md"
  printf '# state\n\n## 풀린 입력\n\nx\n' > "$c/$STEM.state.md"
  git -C "$c" add -- docs; git -C "$c" commit -q -m "docs(context): 결과물"
  printf '%s' "$c"
}
generated() {   # generated <클론> → 생성 뒤 꼴: 로드맵 폴더 · 상태 파일의 두 절, 결과물 · audit 은 커밋하지 않은 변경
  local c="$1"
  mkdir -p "$c/$RREL"; printf -- '---\ntype: roadmap\n---\n# 로드맵\n' > "$c/$RREL/roadmap.md"; printf '# R1\n' > "$c/$RREL/R1.md"
  printf '\n## 분해안\n\n| 번호 |\n\n고친 횟수: 0\n승인: 「승인」\n\n## 생성 기록\n\n- %s/roadmap.md\n' "$RREL" >> "$c/$STEM.state.md"
  printf 'dirty\n' >> "$c/$STEM.md"; printf 'dirty\n' >> "$c/$STEM.audit.md"
}
runc() { ( cd "$1" && CLAUDE_PLUGIN_ROOT="$SD" bash -c "${cf//"$PH"/$1/$STEM.md}" 2>&1 ); }
files_of_head() { git -C "$1" show --name-only --pretty=format: HEAD | sed '/^$/d' | LC_ALL=C sort | tr '\n' ' '; }
nhead() { git -C "$1" rev-list --count HEAD; }
DEC="분해됨 — $RREL/roadmap.md"

# 1. 로드맵 폴더 + 상태 파일이 한 커밋에 · 결과물 · audit 은 그 커밋에 없고 stage 도 되지 않는다 · 제목이 docs(roadmap):
c="$(mk ok "$DEC")"; generated "$c"
o="$(runc "$c")"
assert_eq "$(nhead "$c")" "3" "커밋: 커밋이 하나 생겼다"
assert_eq "$(files_of_head "$c")" "$STEM.state.md $RREL/R1.md $RREL/roadmap.md " "커밋: 로드맵 폴더와 상태 파일이 한 커밋에 든다(결과물 · audit 은 없다)"
assert_eq "$(git -C "$c" log -1 --format=%s)" "docs(roadmap): 2026-10-15-t 로드맵 · 분해안" "커밋: 제목이 docs(roadmap): <로드맵 폴더 이름> 로드맵 · 분해안"
assert_eq "$(git -C "$c" diff --cached --name-only)" "" "커밋: 결과물 · audit 을 stage 하지 않는다"
assert_eq "$(git -C "$c" status --porcelain -- "$STEM.md" "$STEM.audit.md" | sed '/^$/d' | wc -l | tr -d ' ')" "2" "커밋: 결과물 · audit 의 변경은 커밋되지 않은 채 남는다"
assert_contains "$o" "[spec-distill] 로드맵 폴더 · 상태 파일을 커밋했다 — " "커밋: 성공 줄"
# §7 줄이 목록 · 코드 꼴이어도 같은 로드맵 폴더를 도출한다
c="$(mk code "- \`$DEC\`")"; generated "$c"
o="$(runc "$c")"
assert_eq "$(files_of_head "$c")" "$STEM.state.md $RREL/R1.md $RREL/roadmap.md " "커밋(§7 목록 · 코드 꼴): 로드맵 폴더와 상태 파일이 한 커밋에 든다"

# 2. 기본 브랜치 위면 커밋하지 않고 손 목록(로드맵 폴더 · 상태 파일)을 낸다
c="$(mk onmain "$DEC")"; git -C "$c" switch -q main; git -C "$c" merge -q --ff-only feature/x; generated "$c"
o="$(runc "$c")"
assert_eq "$(nhead "$c")" "2" "기본 브랜치: 커밋하지 않는다"
assert_eq "$(git -C "$c" diff --cached --name-only)" "" "기본 브랜치: 아무것도 stage 하지 않는다"
case "$o" in *"커밋하지 않았다 — 지금 기본 브랜치(main)에 있다. 확인한 뒤 직접 커밋하라: $c/$RREL · $c/$STEM.state.md"*) ok "기본 브랜치: 사유와 손 목록(로드맵 폴더 · 상태 파일)" ;;
  *) nob "기본 브랜치: 사유 · 손 목록이 없다" "$o" ;; esac

# 3. §7 에 분해됨 줄이 없으면 커밋하지 않는다
c="$(mk nodec "다음 단계로 간다.")"; generated "$c"
o="$(runc "$c")"
assert_eq "$(nhead "$c")" "2" "분해됨 줄 없음: 커밋하지 않는다"
assert_contains "$o" "커밋하지 않았다 — 결과물 §7 에 분해됨 줄이 없다" "분해됨 줄 없음: 사유를 보인다"

# 4. §7 의 파일이 로드맵이 아니면(roadmap-check) 커밋하지 않는다
c="$(mk notrm "분해됨 — $RREL/R1.md")"; generated "$c"
o="$(runc "$c")"
assert_eq "$(nhead "$c")" "2" "로드맵 아님: 커밋하지 않는다"
assert_contains "$o" "로드맵 꼴이 아니다" "로드맵 아님: 사유를 보인다"

# 5. 로드맵 폴더가 정해진 폴더 바로 아래가 아니면 커밋하지 않는다
c="$(mk wide "분해됨 — docs/x/roadmap.md")"; generated "$c"; mkdir -p "$c/docs/x"; printf -- '---\ntype: roadmap\n---\n' > "$c/docs/x/roadmap.md"
o="$(runc "$c")"
assert_eq "$(nhead "$c")" "2" "폴더 밖: 커밋하지 않는다"
assert_contains "$o" "정해진 로드맵 폴더 바로 아래가 아니다" "폴더 밖: 사유를 보인다"

# 6. 끝내기 커밋에서 옮겨 온 로드맵 폴더 판정 — 이 판정은 이제 로드맵 잡기의 커밋 펜스에만 있다(AC5)
stated() {   # stated <클론> → 상태 파일에 두 절을 더해 커밋할 변경을 만든다(로드맵 폴더는 만들지 않는다)
  printf '\n## 분해안\n\n| 번호 |\n\n고친 횟수: 0\n' >> "$1/$STEM.state.md"
}
rmdir_at() {   # rmdir_at <클론> <레포 상대 폴더> → 그 자리에 로드맵 꼴 폴더
  mkdir -p "$1/$2"; printf -- '---\ntype: roadmap\n---\n# 로드맵\n' > "$1/$2/roadmap.md"; printf '# R1\n' > "$1/$2/R1.md"
}
refused_rd() {   # refused_rd <클론> <출력> <라벨> <사유 조각>
  assert_eq "$(nhead "$1")" "2" "$3: 커밋하지 않는다"
  assert_eq "$(git -C "$1" diff --cached --name-only)" "" "$3: 아무것도 stage 하지 않는다"
  case "$2" in *"커밋하지 않았다"*"$4"*"$STEM.state.md"*) ok "$3: 사유와 손 목록을 보인다" ;; *) nob "$3: 사유 · 손 목록이 없다" "$2" ;; esac
}
c="$(mk wide2 "분해됨 — docs/superpowers/roadmaps/roadmap.md")"; stated "$c"; rmdir_at "$c" docs/superpowers/roadmaps
o="$(runc "$c")"; refused_rd "$c" "$o" "roadmaps 폴더 자체" "정해진 로드맵 폴더 바로 아래가 아니다"
c="$(mk dot "분해됨 — docs/superpowers/roadmaps/./roadmap.md")"; stated "$c"; rmdir_at "$c" "$RREL"
o="$(runc "$c")"; refused_rd "$c" "$o" "폴더 이름 ." "정해진 로드맵 폴더 바로 아래가 아니다"
c="$(mk case1 "분해됨 — docs/superpowers/Roadmaps/2026-10-15-t/roadmap.md")"; stated "$c"; rmdir_at "$c" "$RREL"
o="$(runc "$c")"; refused_rd "$c" "$o" "대소문자(부모)" "정해진 로드맵 폴더 바로 아래가 아니다"
assert_contains "$o" "대소문자만 다른 경로" "대소문자(부모): 해결자의 사유를 보인다"
c="$(mk case2 "분해됨 — docs/superpowers/roadmaps/2026-10-15-T/roadmap.md")"; stated "$c"; rmdir_at "$c" "$RREL"
o="$(runc "$c")"; refused_rd "$c" "$o" "대소문자(폴더)" "정해진 로드맵 폴더 바로 아래가 아니다"
assert_contains "$o" "대소문자만 다른 경로" "대소문자(폴더): 해결자의 사유를 보인다"
# 레포 설정 roadmaps_dir — 설정의 폴더가 기준이다
c="$(mk cfg-ok "분해됨 — plan/roadmaps/x/roadmap.md" 'roadmaps_dir: plan/roadmaps/')"; stated "$c"; rmdir_at "$c" plan/roadmaps/x
o="$(runc "$c")"
assert_eq "$(files_of_head "$c")" "$STEM.state.md plan/roadmaps/x/R1.md plan/roadmaps/x/roadmap.md " "설정 roadmaps_dir: 설정 폴더 아래 로드맵 폴더와 상태 파일이 한 커밋에"
c="$(mk cfg-def "$DEC" 'roadmaps_dir: plan/roadmaps/')"; stated "$c"; rmdir_at "$c" "$RREL"
o="$(runc "$c")"; refused_rd "$c" "$o" "설정 roadmaps_dir · 기본 자리" "정해진 로드맵 폴더 바로 아래가 아니다"
# 폴더가 없다 · 폴더가 아니다 · 비었다 · git 이 무시하는 파일뿐이다
c="$(mk gone "$DEC")"; stated "$c"
o="$(runc "$c")"; refused_rd "$c" "$o" "폴더 없음" "로드맵 폴더가 없거나 폴더가 아니다"
c="$(mk notdir "$DEC")"; stated "$c"; mkdir -p "$c/docs/superpowers/roadmaps"; printf 'f\n' > "$c/$RREL"
o="$(runc "$c")"; refused_rd "$c" "$o" "폴더 아님" "로드맵 폴더가 없거나 폴더가 아니다"
c="$(mk empty "$DEC")"; stated "$c"; mkdir -p "$c/$RREL"
o="$(runc "$c")"; refused_rd "$c" "$o" "빈 폴더" "로드맵 폴더에 커밋할 파일이 없다"
c="$(mk ignored "$DEC")"; stated "$c"; mkdir -p "$c/$RREL"; printf 'junk\n' > "$c/$RREL/.DS_Store"; printf '.DS_Store\n' >> "$c/.git/info/exclude"
o="$(runc "$c")"; refused_rd "$c" "$o" "무시 파일뿐인 폴더" "로드맵 폴더에 커밋할 파일이 없다"
# 보안 — 로드맵 폴더가 밖의 폴더로 가는 링크 · 끊긴 링크
c="$(mk link "$DEC")"; stated "$c"; mkdir -p "$T/outside-rm" "$c/docs/superpowers/roadmaps"; printf -- '---\ntype: roadmap\n---\n밖\n' > "$T/outside-rm/roadmap.md"
ln -s "$T/outside-rm" "$c/$RREL"
o="$(runc "$c")"; refused_rd "$c" "$o" "보안: 링크" "링크"
assert_eq "$(tail -n 1 "$T/outside-rm/roadmap.md")" "밖" "보안: 링크 너머 파일은 그대로"
c="$(mk dangling "$DEC")"; stated "$c"; mkdir -p "$c/docs/superpowers/roadmaps"; ln -s "$T/no-such-dir" "$c/$RREL"
o="$(runc "$c")"; refused_rd "$c" "$o" "보안: 끊긴 링크" "$RREL"

# 끝내기 커밋에서 옮겨 온 도출 칸 — §7 절대경로 · §7 밖의 분해됨 줄 · 다른 cwd 레포 · 다른 이름의 로드맵
RD3="$STEM.state.md $RREL/R1.md $RREL/roadmap.md "
c="$(mk dec-abs "분해됨 — $T/dec-abs/$RREL/roadmap.md")"; generated "$c"
o="$(runc "$c")"
assert_eq "$(files_of_head "$c")" "$RD3" "커밋(§7 절대경로): 로드맵 폴더와 상태 파일이 한 커밋에 든다"
c="$(mk outside7 "다음 단계로 간다.")"; generated "$c"
printf -- '---\ntype: interview-brief\n---\n## 2. 제약\n\n%s\n\n## 7. Next Action\n\n다음 단계로 간다.\n' "$DEC" > "$c/$STEM.md"
o="$(runc "$c")"
assert_eq "$(nhead "$c")" "2" "§7 밖의 분해됨 줄: 분해 신호가 아니다 — 커밋하지 않는다"
assert_contains "$o" "커밋하지 않았다 — 결과물 §7 에 분해됨 줄이 없다" "§7 밖의 분해됨 줄: 사유를 보인다"
# cwd 가 다른 레포(다른 interview_dir · 기본 브랜치 모름)여도 결과물 레포에 커밋하고 cwd 레포에는 커밋하지 않는다
c="$(mk elsewhere "$DEC")"; generated "$c"
x="$(mk cwdrepo "다음 단계로 간다." 'interview_dir: notes/')"; git -C "$x" remote set-head origin -d >/dev/null 2>&1
o="$( cd "$x" && CLAUDE_PLUGIN_ROOT="$SD" bash -c "${cf//"$PH"/$c/$STEM.md}" 2>&1 )"
assert_eq "$(files_of_head "$c")" "$RD3" "다른 레포에서 돌림: 결과물 레포의 설정으로 로드맵 폴더와 상태 파일이 한 커밋에"
assert_eq "$(nhead "$x")" "2" "다른 레포에서 돌림: cwd 레포에는 커밋하지 않는다"
# 양의 짝 — 이름이 roadmap.md 가 아니어도 머리말 type: roadmap 이면 로드맵이다(끝내기 커밋에서 옮긴 칸 그대로 — roadmap-check 의 결함을 지켜본다)
c="$(mk othername "분해됨 — $RREL/plan.md")"; generated "$c"; mv -- "$c/$RREL/roadmap.md" "$c/$RREL/plan.md"
o="$(runc "$c")"
assert_eq "$(files_of_head "$c")" "$STEM.state.md $RREL/R1.md $RREL/plan.md " "다른 이름의 로드맵: 로드맵 폴더와 상태 파일이 한 커밋에"

# AC19 — 판 · 변경 기록 · README
ver=$(python3 -I -c 'import json,sys;print(json.load(open(sys.argv[1],encoding="utf-8"))["version"])' "$SD/.claude-plugin/plugin.json")
# major 만 잰다 — 호출 이름을 바꾼 판이 9 다. patch · minor 자리까지 묶으면 다음 PR 의 판 올림마다 빨개진다.
case "${ver%%.*}" in ''|*[!0-9]*) no "AC19: 판의 major 를 읽지 못했다: $ver" ;; *) if [ "${ver%%.*}" -ge 9 ]; then ok "AC19: 판의 major 가 9 이상이다"; else no "AC19: 판의 major 가 9 보다 작다: $ver"; fi ;; esac
OLD1="request-""framing"; OLD2="pm-""interview"
sec=$(awk '/^## \[9\.0\.0\]/{f=1;print;next} f&&/^## \[/{exit} f' "$SD/CHANGELOG.md")
if printf '%s' "$sec" | grep -qF "$OLD1" && printf '%s' "$sec" | grep -qF "$OLD2"; then ok "AC19: 9.0.0 절이 두 옛 이름을 싣는다"; else no "AC19: 9.0.0 절에 옛 이름이 없다"; fi
if printf '%s' "$sec" | grep -qF '옛 명령 줄'; then ok "AC19: 옛 명령 줄이 돌지 않음을 적는다"; else no "AC19: 옛 명령 줄이 돌지 않음을 적지 않았다"; fi
has "$SD/README.md" '9.0.0 에서 호출 이름이 바뀌었다'
has "$SD/README.md" 'CHANGELOG.md'
has "$SD/README.md" '/spec-distill:roadmap-draft'

finish
