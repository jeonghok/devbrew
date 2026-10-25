#!/usr/bin/env bash
# repo_defaults.py 의 git 몫 — 레포 설정 파일을 기본 브랜치 판에서 읽고 get · check-path 를 낸다(R8 AC1 · AC3 · AC4).
# 픽스처는 임시 레포다: 기본 브랜치 trunk · 원격은 로컬 bare · origin/HEAD 는 `remote set-head --auto`.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_repo_defaults_git.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
RD="$ROOT/plugins/spec-distill/scripts/repo_defaults.py"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
T="$(cd "$T" && pwd -P)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
DEF_IV="docs/superpowers/interview/"
NO_REF_LABEL="기본값(기본 브랜치 없음 — 설정 파일 못 읽음)"

g() {  # g <레포> <git 인자…>
  local r="$1"; shift
  git -C "$r" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"
}
mkrepo() {  # mkrepo <이름> — $T/<이름>/work (trunk) + $T/<이름>/remote.git, origin/HEAD 있음
  local d="$T/$1"
  mkdir -p "$d" && git init -q --bare -b trunk "$d/remote.git" && git init -q -b trunk "$d/work" || return 1
  g "$d/work" commit -q --allow-empty -m init && g "$d/work" remote add origin "$d/remote.git" \
    && g "$d/work" push -q origin trunk && g "$d/work" remote set-head origin --auto >/dev/null
}
on_trunk() {  # on_trunk <레포 work> <경로> <내용> — trunk 에 커밋하고 push
  mkdir -p "$(dirname "$1/$2")" && printf '%s' "$3" > "$1/$2" && g "$1" add -- "$2" && g "$1" commit -qm "add $2" \
    && g "$1" push -q origin trunk
}
run() {  # run <cwd> <인자…> → OUT · ERR · RC
  local c="$1"; shift
  OUT="$(cd "$c" && python3 "$RD" "$@" 2>"$T/err")"; RC=$?
  ERR="$(cat "$T/err")"
}

# ── test_default_ref_file_wins_over_worktree ─────────────────────────────────
mkrepo a || { no "픽스처 a"; finish; exit 1; }
A="$T/a/work"
on_trunk "$A" .devbrew.md $'---\ninterview_dir: notes/iv/\n---\n'
SHA8="$(g "$A" rev-parse --short=8 trunk)"
g "$A" checkout -q -b work
printf -- '---\ninterview_dir: other/\n---\n' > "$A/.devbrew.md"
run "$A" get interview_dir
assert_eq "$RC:$OUT" "0:notes/iv/" "기본 브랜치의 설정 파일이 작업 트리를 이긴다"
assert_contains "$ERR" "레포 설정@$SHA8" "출처가 레포 설정@<커밋 8자> 다"
mkdir -p "$A/sub/dir"
run "$A/sub/dir" get interview_dir
assert_eq "$RC:$OUT" "0:notes/iv/" "하위 폴더에서 불러도 같은 값이다"

# ── 양성 대조 · test_root_flag_reads_other_repo ──────────────────────────────
mkrepo b || { no "픽스처 b"; finish; exit 1; }
B="$T/b/work"
on_trunk "$B" .devbrew.md $'---\ninterview_dir: plan/iv/\n---\n'
run "$B" get interview_dir
assert_eq "$RC:$OUT" "0:plan/iv/" "양성 대조: 설정이 다른 레포 b 의 값"
[ "$OUT" != "notes/iv/" ] && ok "양성 대조: 두 레포의 결과가 다르다" || no "양성 대조: 두 레포의 결과가 같다"
run "$A" get interview_dir --root "$B"
assert_eq "$RC:$OUT" "0:plan/iv/" "--root 는 cwd 가 아니라 그 레포의 값을 읽는다"

# ── test_worktree_only_file_notice ───────────────────────────────────────────
mkrepo c || { no "픽스처 c"; finish; exit 1; }
C="$T/c/work"
run "$C" get interview_dir
assert_eq "$RC:$OUT" "0:$DEF_IV" "설정 파일이 없으면 기본값"
assert_not_contains "$ERR" "아직 기본 브랜치에 없다" "설정 파일이 어디에도 없으면 알림이 없다"
printf -- '---\ninterview_dir: wt/\n---\n' > "$C/.devbrew.md"
run "$C" get interview_dir
assert_eq "$RC:$OUT" "0:$DEF_IV" "작업 트리에만 있는 설정 파일은 쓰지 않는다"
assert_contains "$ERR" "아직 기본 브랜치에 없다" "작업 트리에만 있으면 알린다"

# ── 로드맵 층(기계 상태는 설정 층이 아니다) ──────────────────────────────────
on_trunk "$C" docs/superpowers/roadmaps/r/roadmap.md $'---\ntype: roadmap\ntest_command: make t\n---\n# r\n'
run "$C" get test_command --roadmap docs/superpowers/roadmaps/r/roadmap.md
assert_eq "$RC:$OUT" "0:make t" "--roadmap 은 기본 브랜치의 로드맵 머리말을 읽는다"
assert_contains "$ERR" "출처: 로드맵" "로드맵 값의 출처"
assert_not_contains "$ERR" "기계 상태" "해결자는 기계 상태 층을 갖지 않는다 — 알림에도 그 층이 없다"
run "$C" get test_command
assert_eq "$RC:$OUT" "1:" "로드맵을 안 주면 로드맵 값이 없다"
assert_not_contains "$ERR" "기계 상태" "로드맵이 없어도 기계 상태 층 알림이 없다"
run "$C" get test_command --roadmap docs/superpowers/roadmaps/none/roadmap.md
assert_eq "$RC:$OUT" "3:" "기본 브랜치에 없는 로드맵은 rc 3"
on_trunk "$C" docs/superpowers/roadmaps/r2/roadmap.md $'---\ntype: roadmap\nroadmaps_dir: x/\n---\n# r2\n'
run "$C" get test_command --roadmap docs/superpowers/roadmaps/r2/roadmap.md
assert_eq "$RC:$OUT" "3:" "로드맵 층이 받지 않는 키는 rc 3 · stdout 빔"
assert_contains "$ERR" "로드맵(docs/superpowers/roadmaps/r2/roadmap.md)" "로드맵 층 오류는 그 로드맵을 짚는다"
assert_not_contains "$ERR" "레포 설정 파일(.devbrew.md, 기본 브랜치 판)" "로드맵 층 오류를 레포 설정 파일 탓으로 적지 않는다"
assert_not_contains "$ERR" "레포 설정 로드맵" "로드맵 층 오류 앞에 「레포 설정」 접두가 붙지 않는다"
assert_not_grep "$ERR" ' roadmap |roadmap:' "사유에 층 내부 이름(roadmap)이 보이지 않는다"

# ── test_get_no_value_rc1 ────────────────────────────────────────────────────
run "$A" get test_command
assert_eq "$RC" "1" "값 없는 키는 rc 1"
assert_eq "$OUT" "" "값 없는 키는 stdout 이 비었다"
run "$A" get no_such_key
assert_eq "$RC:$OUT" "2:" "모르는 키를 물으면 rc 2(사용법)"

# ── test_no_default_ref_uses_constants_with_source ───────────────────────────
mkrepo d || { no "픽스처 d"; finish; exit 1; }
D="$T/d/work"
g "$D" remote set-head origin -d
run "$D" get interview_dir
assert_eq "$RC:$OUT" "0:$DEF_IV" "기본 브랜치가 없어도 멈추지 않고 기본값"
assert_contains "$ERR" "$NO_REF_LABEL" "출처가 기본값(기본 브랜치 없음 — 설정 파일 못 읽음)"
assert_not_contains "$ERR" "[주의]" "작업 트리에 설정 파일이 없으면 크게 알리지 않는다"
printf -- '---\ninterview_dir: wt/\n---\n' > "$D/.devbrew.md"
run "$D" get interview_dir
assert_eq "$RC:$OUT" "0:$DEF_IV" "기본 브랜치가 없으면 작업 트리 설정도 쓰지 않는다"
assert_contains "$ERR" "[주의]" "작업 트리에 설정 파일이 있으면 크게 알린다"
N="$T/n/work"
mkdir -p "$N" && git init -q -b trunk "$N" && g "$N" commit -q --allow-empty -m init || no "픽스처 n(원격 없음)"
run "$N" get interview_dir
assert_eq "$RC:$OUT" "0:$DEF_IV" "원격 origin 이 아예 없어도 get 은 기본값(rc 0)"
assert_contains "$ERR" "$NO_REF_LABEL" "원격이 없을 때도 출처가 기본 브랜치 없음 기본값"

# ── 내부 오류는 rc 3(값 없음 rc 1 로 읽히지 않는다) ───────────────────────────
mkdir "$T/gone-root" && rmdir "$T/gone-root"
run "$A" get interview_dir --root "$T/gone-root"
assert_eq "$RC:$OUT" "3:" "지워진 --root 는 rc 3 · stdout 빔"
mkdir "$T/gone-cwd"
OUT="$(cd "$T/gone-cwd" && rmdir "$T/gone-cwd" && python3 "$RD" get interview_dir 2>"$T/err")"; RC=$?
ERR="$(cat "$T/err")"
assert_eq "$RC:$OUT" "3:" "지워진 cwd 에서 부르면 rc 3 · stdout 빔"
assert_contains "$ERR" "내부 오류" "지워진 cwd 는 내부 오류로 알린다"
assert_not_contains "$ERR" "Traceback" "내부 오류가 Traceback 으로 새지 않는다"

# ── test_symlink_and_lfs_refused ─────────────────────────────────────────────
mkrepo e || { no "픽스처 e"; finish; exit 1; }
E="$T/e/work"
printf -- '---\ninterview_dir: x/\n---\n' > "$E/real.md"
ln -s real.md "$E/.devbrew.md"
g "$E" add -- real.md .devbrew.md && g "$E" commit -qm link && g "$E" push -q origin trunk
assert_eq "$(g "$E" ls-tree trunk -- .devbrew.md | cut -c1-6)" "120000" "픽스처: 기본 브랜치의 설정 파일이 링크다"
run "$E" get interview_dir
assert_eq "$RC:$OUT" "3:" "링크 설정 파일은 rc 3 · stdout 빔"
assert_contains "$ERR" "일반 파일이 아니다" "링크 설정 파일의 사유"
mkrepo f || { no "픽스처 f"; finish; exit 1; }
F="$T/f/work"
on_trunk "$F" .devbrew.md $'version https://git-lfs.github.com/spec/v1\noid sha256:0000000000000000000000000000000000000000000000000000000000000000\nsize 40\n'
run "$F" get interview_dir
assert_eq "$RC:$OUT" "3:" "LFS 포인터 설정 파일은 rc 3 · stdout 빔"
assert_contains "$ERR" "LFS" "LFS 포인터의 사유"

# ── test_get_broken_rc3 ──────────────────────────────────────────────────────
broken() {  # broken <이름> <내용> → BRC · BERR. 픽스처가 실패하면 크게 실패하고 앞 사례의 값을 남기지 않는다
  BRC="픽스처 실패"; BERR="픽스처 실패"
  mkrepo "$1" && on_trunk "$T/$1/work" .devbrew.md "$2" || { no "픽스처 $1 를 만들지 못했다"; return 1; }
  run "$T/$1/work" get interview_dir
  BRC="$RC:$OUT"; BERR="$ERR"
}
broken dup $'---\ninterview_dir: a/\ninterview_dir: b/\n---\n'; dup_rc="$BRC"; dup_err="$BERR"
broken bom $'\xef\xbb\xbf---\ninterview_dir: a/\n---\n'; bom_rc="$BRC"; bom_err="$BERR"
broken typo $'---\ninterveiw_dir: a/\n---\n'; typo_rc="$BRC"; typo_err="$BERR"
assert_eq "$dup_rc" "3:" "같은 키 둘은 rc 3 · stdout 빔"
assert_eq "$bom_rc" "3:" "BOM 은 rc 3 · stdout 빔"
assert_eq "$typo_rc" "3:" "오타 키는 rc 3 · stdout 빔"
assert_contains "$dup_err" "같은 키가 둘" "같은 키 둘의 사유"
assert_contains "$bom_err" "BOM" "BOM 의 사유"
assert_contains "$typo_err" "interveiw_dir" "오타 키의 사유가 그 키를 짚는다"
[ "$dup_err" != "$bom_err" ] && [ "$bom_err" != "$typo_err" ] && [ "$dup_err" != "$typo_err" ] \
  && ok "세 사유가 서로 다르다" || no "세 사유가 서로 다르다"
for e in "$dup_err" "$bom_err" "$typo_err"; do
  assert_not_grep "$e" ' repo |repo:' "사유에 층 내부 이름(repo)이 보이지 않는다"
  assert_contains "$e" "레포 설정 파일(.devbrew.md, 기본 브랜치 판)" "사유가 자리를 쉬운 이름으로 짚는다"
done
broken badval $'---\ninterview_dir: ../up/\n---\n'
assert_eq "$BRC" "3:" "잘못된 폴더 값(층 합치기의 오류)은 rc 3 · stdout 빔"

# ── test_check_path ──────────────────────────────────────────────────────────
mkrepo h || { no "픽스처 h"; finish; exit 1; }
H="$T/h/work"
run "$H" check-path roadmaps_dir docs/superpowers/roadmaps/x
assert_eq "$RC" "0" "check-path: roadmaps_dir 바로 아래 경로는 통과"
run "$H" check-path roadmaps_dir docs/superpowers/Roadmaps/x
assert_eq "$RC" "3" "check-path: 대소문자만 다른 부모는 rc 3"
assert_contains "$ERR" "대소문자만 다른 경로" "check-path: 대소문자 사유"
run "$H" check-path roadmaps_dir docs/x
assert_eq "$RC" "3" "check-path: 다른 부모는 rc 3"
assert_contains "$ERR" "부모 폴더가 다르다" "check-path: 다른 부모 사유"
run "$H" check-path roadmaps_dir docs/superpowers/roadmaps/x/y
assert_eq "$RC" "3" "check-path: 두 단계 아래는 rc 3"
run "$H" check-path roadmaps_dir "$H/docs/superpowers/roadmaps/x"
assert_eq "$RC" "0" "check-path: 레포 안 절대 경로는 상대 경로로 바꿔 판정"
run "$H" check-path roadmaps_dir "$H/docs/x"
assert_eq "$RC" "3" "check-path: 레포 안 절대 경로도 부모가 다르면 rc 3"
run "$H" check-path roadmaps_dir "$T/elsewhere/docs/superpowers/roadmaps/x"
assert_eq "$RC" "3" "check-path: 레포 밖 절대 경로는 rc 3"
assert_contains "$ERR" "레포 밖 경로" "check-path: 레포 밖 사유"
run "$T" check-path roadmaps_dir docs/superpowers/roadmaps/x --root "$H"
assert_eq "$RC" "0" "check-path: --root 기준 상대 경로"
L="$T/h-link"
ln -s "$H" "$L" || no "픽스처: 레포를 가리키는 링크를 만들지 못했다"
run "$T" check-path interview_dir "$L/${DEF_IV}x.md" --root "$L"
assert_eq "$RC" "0" "check-path: 절대 경로가 --root 의 글자 그대로(링크)로 시작하면 그 접두를 실제 경로로 바꿔 판정"
run "$T" check-path interview_dir "$L/${DEF_IV}x.md" --root "$H"
assert_eq "$RC" "3" "check-path(대조): --root 가 실제 경로면 링크로 시작하는 같은 경로는 레포 밖(rc 3)"
assert_contains "$ERR" "레포 밖 경로" "check-path(대조): 레포 밖 사유"
run "$H" check-path interview_dir docs/superpowers/interview/x-interview.md
assert_eq "$RC" "0" "check-path: interview_dir 도 같은 명령"
run "$H" check-path test_command x
assert_eq "$RC" "2" "check-path: 폴더 키가 아니면 rc 2(사용법)"
mkdir -p "$H/docs/superpowers/Roadmaps"
touch "$T/CaseProbe"
if [ -e "$T/caseprobe" ]; then
  run "$H" check-path roadmaps_dir docs/superpowers/roadmaps/x
  assert_eq "$RC" "3" "check-path: 디스크의 실제 폴더가 Roadmaps 면 roadmaps 인자는 rc 3"
  assert_contains "$ERR" "대소문자만 다른 경로" "check-path: 디스크 대소문자 사유"
else
  note "  - 건너뜀: 대소문자를 가리는 파일시스템이라 디스크 대소문자 사례를 돌지 않는다"
fi

# ── test_roadmap_check (AC6) ─────────────────────────────────────────────────
mkrepo rb || { no "픽스처 rb"; finish; exit 1; }
RB="$T/rb/work"
on_trunk "$RB" .devbrew.md $'---\nroadmaps_dir: plan/roadmaps/\n---\n'
mkdir -p "$RB/plan/roadmaps/x" "$RB/docs/superpowers/roadmaps/x"
printf -- '---\ntype: roadmap\n---\n# x\n' > "$RB/plan/roadmaps/x/roadmap.md"
printf -- '---\ntype: roadmap\n---\n# x\n' > "$RB/docs/superpowers/roadmaps/x/roadmap.md"
printf -- '---\ntype: epic-bundle\n---\n' > "$RB/plan/roadmaps/x/A1.md"
printf -- '---\ntype: roadmap\n# 닫히지 않음\n' > "$RB/plan/roadmaps/x/broken.md"
RB_P="$(cd "$RB" && pwd -P)"
run "$RB" roadmap-check plan/roadmaps/x/roadmap.md
assert_eq "$RC:$OUT" "0:" "roadmap-check: 설정 폴더 바로 아래 폴더의 type: roadmap 은 rc 0 · stdout 빔"
run "$RB/plan" roadmap-check roadmaps/x/roadmap.md
assert_eq "$RC" "0" "roadmap-check: 상대 경로는 cwd 기준"
run "$T" roadmap-check "$RB_P/plan/roadmaps/x/roadmap.md" --root "$RB"
assert_eq "$RC" "0" "roadmap-check: 같은 파일의 물리 절대 경로도 rc 0"
run "$RB" roadmap-check "$T/elsewhere/plan/roadmaps/x/roadmap.md"
assert_eq "$RC" "3" "roadmap-check: 레포 밖 절대 경로는 rc 3"
assert_contains "$ERR" "레포 밖 경로" "roadmap-check: 레포 밖 사유"
run "$RB" roadmap-check docs/superpowers/roadmaps/x/roadmap.md
assert_eq "$RC" "3" "roadmap-check: 설정이 바꾼 폴더 밖(기본 폴더)은 rc 3"
assert_contains "$ERR" "로드맵 폴더 밖" "roadmap-check: 폴더 밖 사유"
run "$RB" roadmap-check plan/roadmaps/x/A1.md
assert_eq "$RC" "3" "roadmap-check: 표지가 다른 파일은 rc 3"
assert_contains "$ERR" "epic-bundle" "roadmap-check: 표지 사유가 실제 type 을 짚는다"
run "$RB" roadmap-check plan/roadmaps/x/broken.md
assert_eq "$RC" "3" "roadmap-check: 머리말을 못 읽는 파일은 rc 3"
assert_contains "$ERR" "검사 불가" "roadmap-check: 못 읽으면 검사 불가로 알린다"
run "$RB" roadmap-check plan/roadmaps/x/none.md
assert_eq "$RC" "3" "roadmap-check: 없는 파일은 rc 3"
run "$RB" roadmap-check plan/roadmaps/x/roadmap.md
assert_not_contains "$ERR" "기계 상태 층 건너뜀" "roadmap-check: 해결자 알림(로드맵 없음 — 기계 상태 층 건너뜀)을 끝내기 펜스에 내지 않는다"
mkdir -p "$RB/plan/roadmaps/ex" "$RB/plan/roadmaps/ln" "$RB/plan/roadmaps/lfs"
cp "$RB/plan/roadmaps/x/roadmap.md" "$RB/plan/roadmaps/ex/roadmap.md" && chmod +x "$RB/plan/roadmaps/ex/roadmap.md"
ln -s ../x/roadmap.md "$RB/plan/roadmaps/ln/roadmap.md"
printf 'version https://git-lfs.github.com/spec/v1\noid sha256:00\nsize 1\n' > "$RB/plan/roadmaps/lfs/roadmap.md"
run "$RB" roadmap-check plan/roadmaps/ex/roadmap.md
assert_eq "$RC" "0" "roadmap-check: 실행 비트가 있는 일반 파일도 로드맵(두 진입과 같은 읽기 규칙)"
run "$RB" roadmap-check plan/roadmaps/ln/roadmap.md
assert_eq "$RC" "3" "roadmap-check: 링크는 rc 3"
assert_contains "$ERR" "일반 파일이 아니다" "roadmap-check: 링크의 사유"
run "$RB" roadmap-check plan/roadmaps/lfs/roadmap.md
assert_eq "$RC" "3" "roadmap-check: LFS 포인터는 rc 3"
assert_contains "$ERR" "검사 불가" "roadmap-check: LFS 포인터는 조용한 로드맵 아님이 아니라 검사 불가"
assert_contains "$ERR" "LFS 포인터다" "roadmap-check: LFS 포인터의 사유"
run "$A" roadmap-check plan/roadmaps/x/roadmap.md --root "$RB"
assert_eq "$RC" "0" "roadmap-check: 레포 A 를 cwd 로 두고 --root 레포 B 의 설정 폴더로 판정한다"
mkdir -p "$A/plan/roadmaps/x" && cp "$RB/plan/roadmaps/x/roadmap.md" "$A/plan/roadmaps/x/roadmap.md"
run "$A" roadmap-check plan/roadmaps/x/roadmap.md
assert_eq "$RC" "3" "양성 대조: 같은 파일 모양도 레포 A 의 설정(기본 폴더)이면 rc 3"
on_trunk "$RB" .devbrew.md $'---\nroadmaps_dir: plan/roadmaps/\ntypo_key: x\n---\n'
run "$RB" roadmap-check docs/superpowers/roadmaps/x/roadmap.md
assert_eq "$RC" "3" "roadmap-check: 레포 설정이 깨지면 기본 폴더로 조용히 판정하지 않고 rc 3(기본 폴더의 로드맵도 통과 못 함)"
assert_contains "$ERR" "typo_key" "roadmap-check: 깨진 설정의 사유를 알린다"

# ── 레포 밖 — get 은 기본 브랜치를 모를 때와 같은 기본값, 판정 명령 · --roadmap 은 rc 3 ─────────
NR="$T/norepo/sub"; mkdir -p "$NR"
[ -z "$(git -C "$NR" rev-parse --show-toplevel 2>/dev/null)" ] && ok "전제: 픽스처가 레포 밖이다" || no "전제: 픽스처가 레포 안이다 — 아래 칸이 공허하다"
run "$NR" get interview_dir
assert_eq "$RC:$OUT" "0:$DEF_IV" "레포 밖 get: 기본값 · rc 0"
assert_contains "$ERR" "값의 출처: $NO_REF_LABEL(interview_dir)" "레포 밖 get: 출처는 「기본 브랜치 없음」 표기"
assert_contains "$ERR" "git 레포 밖이라" "레포 밖 get: 레포가 아니라는 알림"
assert_eq "$(printf '%s\n' "$ERR" | grep -c .)" "2" "레포 밖 get: stderr 는 알림 한 줄 + 출처 한 줄"
run "$NR" get test_command
assert_eq "$RC:$OUT" "1:" "레포 밖 get: 기본값이 없는 키는 rc 1"
run "$NR" get test_command --roadmap x/roadmap.md
assert_eq "$RC" "3" "레포 밖 get --roadmap: 로드맵을 읽을 수 없어 rc 3"
run "$NR" check-path interview_dir "$DEF_IV"x-interview.md
assert_eq "$RC" "3" "레포 밖 check-path: rc 3"
run "$NR" roadmap-check docs/superpowers/roadmaps/x/roadmap.md
assert_eq "$RC" "3" "레포 밖 roadmap-check: rc 3"
run "$NR" default-branch
assert_eq "$RC" "3" "레포 밖 default-branch: rc 3"
# 음의 짝 — 조상에 `.git` 이 있는데 git 이 레포를 못 읽으면 레포 밖이 아니라 깨짐(rc 3)
BG="$T/brokengit"; mkdir -p "$BG/.git" "$BG/sub"
run "$BG/sub" get interview_dir
assert_eq "$RC" "3" "못 읽는 .git 아래 get: 기본값으로 조용히 넘어가지 않고 rc 3"

run "$H" check-path specs_dir docs/superpowers/specs/x
assert_eq "$RC" "2" "check-path: specs_dir 는 키가 아니다(사용법 오류 rc 2)"
run "$H" check-path interview_dir docs/superpowers/interview/x
assert_eq "$RC" "0" "check-path(양의 짝): interview_dir 는 그대로 통과"

finish
