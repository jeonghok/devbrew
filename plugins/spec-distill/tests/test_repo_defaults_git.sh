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

# ── 로드맵 층 · 기계 상태 층 건너뜀 ─────────────────────────────────────────
on_trunk "$C" docs/superpowers/roadmaps/r/roadmap.md $'---\ntype: roadmap\ntest_command: make t\n---\n# r\n'
run "$C" get test_command --roadmap docs/superpowers/roadmaps/r/roadmap.md
assert_eq "$RC:$OUT" "0:make t" "--roadmap 은 기본 브랜치의 로드맵 머리말을 읽는다"
assert_contains "$ERR" "출처: 로드맵" "로드맵 값의 출처"
assert_contains "$ERR" "기계 상태 층 건너뜀 — 읽는 함수 없음" "읽는 함수가 없으면 기계 상태 층을 건너뛴다고 알린다"
run "$C" get test_command
assert_eq "$RC:$OUT" "1:" "로드맵을 안 주면 로드맵 값이 없다"
assert_contains "$ERR" "로드맵 없음 — 기계 상태 층 건너뜀" "로드맵이 없으면 기계 상태 층을 건너뛴다고 알린다"
run "$C" get test_command --roadmap docs/superpowers/roadmaps/none/roadmap.md
assert_eq "$RC:$OUT" "3:" "기본 브랜치에 없는 로드맵은 rc 3"

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
broken() {  # broken <이름> <내용> → BRC · BERR
  mkrepo "$1" || return 1
  on_trunk "$T/$1/work" .devbrew.md "$2"
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

finish
