#!/usr/bin/env bash
# gh_repo.py 의 gh 몫 — 모든 gh 호출이 origin 에서 도출한 -R <host>/<owner>/<repo> 를 쓰고,
# gh 없음 · 인증 · 비 GitHub · origin 없음에서 멈춘다(R8 AC16 · AC20 · AC23a · AC29 fork).
# 픽스처는 임시 레포 + PATH 앞의 가짜 gh(받은 인자를 파일에 적는다). 실제 gh 로 나가지 않는다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_gh_repo.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
SCRIPTS="$ROOT/plugins/spec-distill/scripts"
GR="$SCRIPTS/gh_repo.py"
PY="$(python3 -I -c 'import sys; print(sys.executable)')" || exit 1
[ -n "$PY" ] && [ -x "$PY" ] || exit 1
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
T="$(cd "$T" && pwd -P)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset GH_REPO GH_HOST

mkdir -p "$T/bin" "$T/nogh" || exit 1
mkdir -p "$T/badbin" || exit 1
printf '#!/nonexistent-devbrew-interp/sh\n' > "$T/badbin/gh" || exit 1
chmod +x "$T/badbin/gh" || exit 1
cat > "$T/bin/gh" <<'FAKE'
#!/bin/sh
: > "$FAKE_GH_ARGS"
for a in "$@"; do printf '%s\n' "$a" >> "$FAKE_GH_ARGS"; done
printf 'env:%s:%s:%s\n' "${GH_PROMPT_DISABLED:-}" "${NO_COLOR:-}" "${GH_NO_UPDATE_NOTIFIER:-}" >> "$FAKE_GH_ARGS"
case "${FAKE_GH_MODE:-ok}" in
  ok) printf '[]\n' ;;
  auth) printf 'To get started with GitHub CLI, please run:  gh auth login\n' >&2; exit 4 ;;
  unresolved) printf "GraphQL: Could not resolve to a Repository with the name 'o/r'. (repository)\n" >&2; exit 1 ;;
  gitlab) printf "GraphQL: No such type PullRequest, so it can't be a fragment condition (fragment pr), PullRequestState isn't a defined input type (on \$state) (query PullRequestList)\n" >&2; exit 1 ;;
  ghe_unknown) printf 'error connecting to ghe.example.com\ncheck your internet connection or https://githubstatus.com\n' >&2; exit 1 ;;
  api404) printf '{"message":"Not Found","status":"404"}'; printf 'gh: Not Found (HTTP 404)\n' >&2; exit 1 ;;
  sleep) exec sleep 5 ;;
  prs) printf '[{"number":7,"state":"MERGED","headRefName":"b","headRefOid":"abc","isCrossRepository":false,"baseRefName":"main","mergeCommit":{"oid":"def"}},{"number":8,"state":"OPEN","headRefName":"b","headRefOid":"abd","isCrossRepository":false,"baseRefName":"main","mergeCommit":null}]\n' ;;
  badshape) printf '{"number":7}\n' ;;
  missingkey) printf '[{"number":7,"state":"OPEN"}]\n' ;;
  notjson) printf 'hello\n' ;;
  open) printf '[{"url":"https://github.com/fork/r/pull/3","isCrossRepository":true},{"url":"https://github.com/me/r/pull/5","isCrossRepository":false}]\n' ;;
  crossonly) printf '[{"url":"https://github.com/fork/r/pull/3","isCrossRepository":true}]\n' ;;
  created) printf 'Creating pull request for feature/x into main in me/r\n' >&2; printf 'https://github.com/me/r/pull/9\n' ;;
  nourl) printf 'done\n' ;;
  view) printf '{"number":7,"state":"OPEN","headRefName":"feature/x","headRefOid":"abc","isCrossRepository":false,"baseRefName":"main","mergeCommit":null}\n' ;;
  viewcross) printf '{"number":7,"state":"MERGED","headRefName":"feature/x","headRefOid":"abc","isCrossRepository":true,"baseRefName":"main","mergeCommit":{"oid":"def"}}\n' ;;
  ways) printf '{"mergeCommitAllowed":false,"squashMergeAllowed":true,"rebaseMergeAllowed":true}\n' ;;
  pending) printf 'build\tpending\t0\thttps://ci.example/1\n'; printf 'still running\n' >&2; exit 8 ;;
esac
FAKE
chmod +x "$T/bin/gh" || exit 1
export FAKE_GH_ARGS="$T/args"
FAKEPATH="$T/bin:$PATH"

mkrepo() {  # mkrepo <이름> <origin URL|-> [<upstream URL>]
  local d="$T/$1"
  git init -q "$d" || return 1
  [ "$2" = "-" ] || git -C "$d" remote add origin "$2" || return 1
  [ -z "${3:-}" ] || git -C "$d" remote add upstream "$3" || return 1
}
call() {  # call <cwd> <PATH> — gh_json(cwd, ["pr","list"]) → OUT · ERR · RC · ARGS
  : > "$FAKE_GH_ARGS"
  OUT="$(PATH="$2" "$PY" -I -c '
import sys
sys.path.insert(0, sys.argv[1])
import gh_repo
for n in gh_repo.env_notices():
    print("NOTICE:" + n, file=sys.stderr)
try:
    print(gh_repo.gh_json(sys.argv[2], ["pr", "list"], float(sys.argv[3])))
except gh_repo.GhStop as exc:
    print("STOP:" + str(exc), file=sys.stderr)
    sys.exit(5)
' "$SCRIPTS" "$1" "${CALL_TIMEOUT:-15}" 2>"$T/err")"; RC=$?
  ERR="$(cat "$T/err")"
  ARGS="$(tr '\n' ' ' < "$FAKE_GH_ARGS")"
}
call_prs() {  # call_prs <cwd> <limit> — pr_list(cwd, "b", limit) → OUT(개수:한도) · ERR · RC · ARGS
  : > "$FAKE_GH_ARGS"
  OUT="$(PATH="$FAKEPATH" "$PY" -I -c '
import sys
sys.path.insert(0, sys.argv[1])
import gh_repo
try:
    items, hit = gh_repo.pr_list(sys.argv[2], "b", int(sys.argv[3]))
    print("%d:%s" % (len(items), hit))
except gh_repo.GhStop as exc:
    print("STOP:" + str(exc), file=sys.stderr)
    sys.exit(5)
' "$SCRIPTS" "$1" "$2" 2>"$T/err")"; RC=$?
  ERR="$(cat "$T/err")"
  ARGS="$(tr '\n' ' ' < "$FAKE_GH_ARGS")"
}

# ── fork_with_upstream ───────────────────────────────────────────────────────
mkrepo fork https://github.com/me/r https://github.com/up/r || { no "픽스처 fork"; finish; exit 1; }
call "$T/fork" "$FAKEPATH"
assert_eq "$RC:$OUT" "0:[]" "fork: gh_json 이 가짜 gh 의 JSON 을 돌려준다"
assert_contains "$ARGS" "pr list -R github.com/me/r " "fork: upstream 이 있어도 -R 이 origin(github.com/me/r)이다"
assert_not_contains "$ARGS" "up/r" "fork: upstream 레포를 넘기지 않는다"
assert_contains "$ARGS" "env:1:1:1" "gh 를 프롬프트 · 색 · 업데이트 알림 없이 부른다"
assert_not_contains "$ERR" "NOTICE:" "GH_REPO · GH_HOST 가 없으면 알림이 없다"

# ── ghe_host ─────────────────────────────────────────────────────────────────
mkrepo ghe git@ghe.example.com:o/r.git || { no "픽스처 ghe"; finish; exit 1; }
call "$T/ghe" "$FAKEPATH"
assert_eq "$RC" "0" "ghe: 성공"
assert_contains "$ARGS" "-R ghe.example.com/o/r " "ghe: -R 이 호스트를 보존한다"

# ── gh_repo_env ──────────────────────────────────────────────────────────────
GH_REPO=up/r call "$T/fork" "$FAKEPATH"
assert_contains "$ERR" "NOTICE:GH_REPO 이 설정돼 있다(up/r) — devbrew 는 -R 로 origin 을 명시해 쓴다" \
  "GH_REPO 가 설정돼 있으면 알린다"
assert_contains "$ARGS" "-R github.com/me/r " "GH_REPO 가 있어도 -R 은 origin 이다"

# ── no_gh ────────────────────────────────────────────────────────────────────
call "$T/fork" "$T/nogh"
assert_eq "$RC" "5" "gh 가 없으면 멈춘다"
assert_contains "$ERR" "STOP:gh 가 없다 — devbrew 는 gh 를 필수로 쓴다. https://cli.github.com 에서 설치한다" \
  "gh 없음 문장에 설치 주소(cli.github.com)"
mkrepo bare - || { no "픽스처 bare"; finish; exit 1; }
call "$T/bare" "$T/nogh"
assert_contains "$ERR" "STOP:gh 가 없다" "gh 가 없으면 origin 이 없어도 「gh 가 없다」를 먼저 낸다"

# ── auth_fail ────────────────────────────────────────────────────────────────
FAKE_GH_MODE=auth call "$T/fork" "$FAKEPATH"
assert_eq "$RC" "5" "인증 실패에서 멈춘다"
assert_contains "$ERR" "STOP:gh 인증이 안 됐다 — gh auth login --hostname github.com 를 돈다" \
  "인증 실패 문장에 gh auth login --hostname github.com"

# ── non_github · 레포를 못 찾음(실측 stderr) ─────────────────────────────────
# 실측(gh 2.88.1): github.com 에 없는 레포 → "Could not resolve to a Repository" ·
# gitlab.com → "No such type PullRequest"(GitHub 인 레포만) · 모르는 호스트 → "error connecting to" · gh api 404 → "Not Found (HTTP 404)".
mkrepo lab https://gitlab.com/o/r || { no "픽스처 lab"; finish; exit 1; }
FAKE_GH_MODE=unresolved call "$T/fork" "$FAKEPATH"
assert_eq "$RC" "5" "레포를 못 찾으면 멈춘다"
assert_contains "$ERR" "STOP:gh 가 origin(github.com/me/r)을 다루지 못한다 — devbrew 는 origin 이 GitHub 인 레포만 지원한다(비공개 레포면 접근 권한도 확인한다)" \
  "레포를 못 찾음: 「GitHub 인 레포만」 · 비공개면 접근 권한"
FAKE_GH_MODE=gitlab call "$T/lab" "$FAKEPATH"
assert_eq "$RC" "5" "비 GitHub(gitlab.com) 에서 멈춘다"
assert_contains "$ARGS" "-R gitlab.com/o/r " "비 GitHub: -R 은 origin 그대로"
assert_contains "$ERR" "STOP:gh 가 origin(gitlab.com/o/r)을 다루지 못한다 — devbrew 는 origin 이 GitHub 인 레포만 지원한다" \
  "비 GitHub(gitlab.com 실측): 「GitHub 인 레포만」"
FAKE_GH_MODE=ghe_unknown call "$T/ghe" "$FAKEPATH"
assert_eq "$RC" "5" "모르는 호스트에서 멈춘다"
assert_contains "$ERR" "STOP:gh 실패(rc 1): error connecting to ghe.example.com" \
  "모르는 호스트(실측): rc 와 stderr 첫 줄로 멈춘다"
FAKE_GH_MODE=api404 call "$T/fork" "$FAKEPATH"
assert_contains "$ERR" "STOP:gh 실패(rc 1): gh: Not Found (HTTP 404)" "gh api 404 는 「GitHub 인 레포만」으로 가르지 않는다"
assert_not_contains "$ERR" "GitHub 인 레포만" "gh api 404 에 「GitHub 인 레포만」이 없다"

# ── 시간 초과 · 실행 실패 ────────────────────────────────────────────────────
FAKE_GH_MODE=sleep CALL_TIMEOUT=0.5 call "$T/fork" "$FAKEPATH"
assert_eq "$RC" "5" "gh 가 시간 안에 끝나지 않으면 멈춘다"
assert_contains "$ERR" "STOP:gh 가 0.5초 안에 끝나지 않았다(github.com/me/r)" "시간 초과 문장"
call "$T/fork" "$T/badbin:$PATH"
assert_eq "$RC" "5" "gh 를 실행하지 못하면 멈춘다"
assert_contains "$ERR" "STOP:gh 를 실행하지 못했다(" "실행 실패 문장"

# ── insteadOf ────────────────────────────────────────────────────────────────
mkrepo alias gh:me/r || { no "픽스처 alias"; finish; exit 1; }
git -C "$T/alias" config url.git@github.com:.insteadOf gh: || { no "픽스처 alias insteadOf"; finish; exit 1; }
OUT="$(cd "$T/alias" && "$PY" "$GR" slug 2>"$T/err")"; RC=$?
assert_eq "$RC:$OUT" "0:github.com/me/r" "insteadOf 로 바뀐 origin URL(git remote get-url origin)을 읽는다"

# ── pr_list ──────────────────────────────────────────────────────────────────
FAKE_GH_MODE=prs call_prs "$T/fork" 100
assert_eq "$RC:$OUT" "0:2:False" "pr_list: 목록 둘 · 한도에 닿지 않음"
assert_contains "$ARGS" "pr list --state all --head b --json number,state,headRefName,headRefOid,isCrossRepository,baseRefName,mergeCommit --limit 100 -R github.com/me/r " \
  "pr_list: 상태 전부 · head 브랜치 · 일곱 칸 · 한도 · -R origin"
FAKE_GH_MODE=prs call_prs "$T/fork" 2
assert_eq "$RC:$OUT" "0:2:True" "pr_list: 한도만큼 오면 한도에 닿았다"
for m in badshape missingkey notjson; do
  FAKE_GH_MODE=$m call_prs "$T/fork" 100
  assert_eq "$RC" "5" "pr_list: 모양이 다르면 멈춘다(${m})"
done

# ── no_origin · slug CLI ─────────────────────────────────────────────────────
OUT="$(cd "$T/bare" && "$PY" "$GR" slug 2>"$T/err")"; RC=$?; ERR="$(cat "$T/err")"
assert_eq "$RC:$OUT" "3:" "origin 이 없으면 slug 가 rc 3 · stdout 비움"
assert_contains "$ERR" "origin URL 에서 호스트 · owner · repo 를 뽑지 못했다" "slug rc 3 의 사유"
call "$T/bare" "$FAKEPATH"
assert_eq "$RC" "5" "origin 이 없으면 gh_json 도 멈춘다"
assert_eq "$ARGS" "" "origin 이 없으면 gh 를 부르지 않는다"
OUT="$(cd "$T/fork" && "$PY" "$GR" slug 2>"$T/err")"; RC=$?
assert_eq "$RC:$OUT" "0:github.com/me/r" "양성 대조: fork 에서 slug 는 origin 이다"
OUT="$(cd "$T/ghe" && GH_HOST=other.example "$PY" "$GR" slug 2>"$T/err")"; RC=$?; ERR="$(cat "$T/err")"
assert_eq "$RC:$OUT" "0:ghe.example.com/o/r" "양성 대조: ghe 에서 slug 는 호스트를 보존한다"
assert_contains "$ERR" "GH_HOST 이 설정돼 있다(other.example)" "slug 도 GH_HOST 를 알린다"

# ── CLI 하위 명령 — 인터뷰 끝맺음의 PR · 머지 펜스가 gh 를 부르는 유일한 길 ──────
cli() {  # cli <레포> <PATH> <인자…> — 다른 폴더에서 --root <레포> 로 부른다 → OUT · ERR · RC · ARGS
  local root="$1" path="$2"; shift 2
  : > "$FAKE_GH_ARGS"
  OUT="$(cd "$T" && PATH="$path" "$PY" "$GR" "$@" --root "$root" 2>"$T/err")"; RC=$?
  ERR="$(cat "$T/err")"
  ARGS="$(tr '\n' ' ' < "$FAKE_GH_ARGS")"
}
cli "$T/fork" "$FAKEPATH" slug
assert_eq "$RC:$OUT" "0:github.com/me/r" "slug --root: 지금 폴더가 아니라 --root 의 origin 을 읽는다"

# pr-number — PR 주소의 레포가 origin 일 때만 번호. gh 를 부르지 않는다
cli "$T/fork" "$FAKEPATH" pr-number https://github.com/me/r/pull/12
assert_eq "$RC:$OUT" "0:12" "pr-number: origin 의 PR 주소면 번호"
assert_eq "$ARGS" "" "pr-number: gh 를 부르지 않는다"
cli "$T/fork" "$FAKEPATH" pr-number https://GitHub.com/ME/R/pull/12/
assert_eq "$RC:$OUT" "0:12" "pr-number: 호스트 · owner · repo 의 대소문자와 끝 빗금은 가리지 않는다"
cli "$T/fork" "$FAKEPATH" pr-number https://github.com/up/r/pull/12
assert_eq "$RC:$OUT" "3:" "pr-number: 다른 owner 의 주소(upstream 포함)는 멈춘다"
assert_contains "$ERR" "[spec-distill] PR 주소의 레포(github.com/up/r)가 origin(github.com/me/r)이 아니다" "pr-number: 두 레포를 보인다"
for u in https://ghe.example.com/me/r/pull/12 https://github.com/me/other/pull/12; do
  cli "$T/fork" "$FAKEPATH" pr-number "$u"
  assert_eq "$RC:$OUT" "3:" "pr-number: 다른 호스트 · 다른 repo 는 멈춘다(${u})"
done
for u in 12 '#12' https://github.com/me/r/pull/12/files https://github.com/me/r/issues/12 ''; do
  cli "$T/fork" "$FAKEPATH" pr-number "$u"
  assert_eq "$RC:$OUT" "3:" "pr-number: PR 주소 꼴이 아니면 멈춘다(${u:-빈 값})"
  assert_contains "$ERR" "PR 주소를 읽지 못했다" "pr-number: 주소 꼴 사유(${u:-빈 값})"
done
cli "$T/bare" "$FAKEPATH" pr-number https://github.com/me/r/pull/12
assert_eq "$RC:$OUT" "3:" "pr-number: origin 이 없으면 멈춘다"

# pr-open — 이 레포 안 브랜치의 열린 PR 주소
FAKE_GH_MODE=open cli "$T/fork" "$FAKEPATH" pr-open --head feature/x --base main
assert_eq "$RC:$OUT" "0:https://github.com/me/r/pull/5" "pr-open: 다른 레포의 브랜치에서 온 PR 을 건너뛰고 이 레포 것을 낸다"
assert_contains "$ARGS" "pr list --state open --head feature/x --base main --json url,isCrossRepository --limit 20 -R github.com/me/r " "pr-open: 열린 것 · head · base · -R origin"
FAKE_GH_MODE=crossonly cli "$T/fork" "$FAKEPATH" pr-open --head feature/x --base main
assert_eq "$RC:$OUT" "0:" "pr-open: 다른 레포의 브랜치에서 온 PR 뿐이면 빈 줄"
cli "$T/fork" "$FAKEPATH" pr-open --head feature/x --base main
assert_eq "$RC:$OUT" "0:" "pr-open: 열린 PR 이 없으면 빈 줄"
for m in badshape prs notjson; do
  FAKE_GH_MODE=$m cli "$T/fork" "$FAKEPATH" pr-open --head feature/x --base main
  assert_eq "$RC:$OUT" "3:" "pr-open: 모양이 다르면 멈춘다(${m})"
done
cli "$T/fork" "$T/nogh" pr-open --head feature/x --base main
assert_eq "$RC:$OUT" "3:" "pr-open: gh 가 없으면 멈춘다"
assert_contains "$ERR" "[spec-distill] gh 가 없다 — devbrew 는 gh 를 필수로 쓴다" "pr-open: gh 없음 사유"
FAKE_GH_MODE=auth cli "$T/fork" "$FAKEPATH" pr-open --head feature/x --base main
assert_eq "$RC:$OUT" "3:" "pr-open: 인증 실패에서 멈춘다"
assert_contains "$ERR" "gh auth login --hostname github.com" "pr-open: 인증 사유"

# pr-create — 새 PR 주소
FAKE_GH_MODE=created cli "$T/fork" "$FAKEPATH" pr-create --head feature/x --base main --title "docs: t" --body-file "$T/body.md"
assert_eq "$RC:$OUT" "0:https://github.com/me/r/pull/9" "pr-create: gh 가 낸 주소"
assert_contains "$ARGS" "pr create --base main --head feature/x --title docs: t --body-file $T/body.md -R github.com/me/r " "pr-create: base · head · 제목 · 본문 파일 · -R origin"
FAKE_GH_MODE=nourl cli "$T/fork" "$FAKEPATH" pr-create --head feature/x --base main --title t --body-file "$T/body.md"
assert_eq "$RC:$OUT" "3:" "pr-create: 주소가 아닌 출력이면 멈춘다"
assert_contains "$ERR" "gh pr create 가 PR 주소를 내지 않았다(github.com/me/r): done" "pr-create: 받은 줄을 보인다"

# pr-identity — 상태 · base · head · 다른 레포의 브랜치인가
FAKE_GH_MODE=view cli "$T/fork" "$FAKEPATH" pr-identity 7
assert_eq "$RC:$OUT" "0:OPEN main feature/x false abc" "pr-identity: 다섯 칸 한 줄 — 끝 칸은 PR 의 head 커밋"
assert_contains "$ARGS" "pr view 7 --json number,state,headRefName,headRefOid,isCrossRepository,baseRefName,mergeCommit -R github.com/me/r " "pr-identity: 번호와 -R origin"
FAKE_GH_MODE=viewcross cli "$T/fork" "$FAKEPATH" pr-identity 7
assert_eq "$RC:$OUT" "0:MERGED main feature/x true abc" "pr-identity: 머지된 · 다른 레포의 브랜치"
FAKE_GH_MODE=badshape cli "$T/fork" "$FAKEPATH" pr-identity 7
assert_eq "$RC:$OUT" "3:" "pr-identity: 모양이 다르면 멈춘다"
for bad in 0 abc -3 https://github.com/me/r/pull/7; do
  FAKE_GH_MODE=view cli "$T/fork" "$FAKEPATH" pr-identity "$bad"
  assert_eq "$RC:$ARGS" "2:" "pr-identity: 번호가 1 이상의 숫자가 아니면 사용법 오류이고 gh 를 부르지 않는다(${bad})"
done

# merge-ways — 레포가 허용하는 머지 방식. repo view 는 -R 을 받지 않아 같은 값을 인자로 준다
FAKE_GH_MODE=ways cli "$T/fork" "$FAKEPATH" merge-ways
assert_eq "$RC:$OUT" "0:--squash --rebase" "merge-ways: 허용된 것만, merge commit → squash → rebase 순서"
assert_contains "$ARGS" "repo view --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed github.com/me/r env:" "merge-ways: origin 레포를 인자로 준다"
assert_not_contains "$ARGS" " -R " "merge-ways: -R 을 붙이지 않는다"
FAKE_GH_MODE=badshape cli "$T/fork" "$FAKEPATH" merge-ways
assert_eq "$RC:$OUT" "3:" "merge-ways: 모양이 다르면 멈춘다"

# pr-checks · pr-merge — gh 로 갈아탄다: 출력과 종료 코드가 gh 의 것 그대로
FAKE_GH_MODE=pending cli "$T/fork" "$FAKEPATH" pr-checks 7 --watch --interval 15
assert_eq "$RC" "8" "pr-checks: gh 의 종료 코드(8 — 검사 대기)가 그대로 나온다"
assert_contains "$OUT" "pending" "pr-checks: gh 의 stdout 이 그대로 나온다"
assert_contains "$ERR" "still running" "pr-checks: gh 의 stderr 가 그대로 나온다"
assert_contains "$ARGS" "pr checks 7 --watch --interval 15 -R github.com/me/r env:1:1:1" "pr-checks: 번호 · 기다림 · -R origin · 프롬프트 없이"
cli "$T/fork" "$FAKEPATH" pr-checks 7
assert_contains "$ARGS" "pr checks 7 -R github.com/me/r " "pr-checks: 기다림 없이도 -R origin"
cli "$T/fork" "$T/nogh" pr-checks 7
assert_eq "$RC" "3" "pr-checks: gh 가 없으면 멈춘다"
cli "$T/fork" "$T/badbin:$PATH" pr-checks 7
assert_eq "$RC" "3" "pr-checks: gh 를 실행하지 못하면 멈춘다"
assert_contains "$ERR" "gh 를 실행하지 못했다(" "pr-checks: 실행 실패 사유"
cli "$T/bare" "$FAKEPATH" pr-checks 7
assert_eq "$RC:$ARGS" "3:" "pr-checks: origin 이 없으면 gh 를 부르지 않고 멈춘다"
SHA=0123456789abcdef0123456789abcdef01234567
cli "$T/fork" "$FAKEPATH" pr-merge 7 --squash --match-head-commit "$SHA"
assert_eq "$RC" "0" "pr-merge: gh 가 성공하면 0"
assert_contains "$ARGS" "pr merge 7 --squash --match-head-commit $SHA -R github.com/me/r env:1:1:1" "pr-merge: 번호 · 방식 · head 커밋 · -R origin · 프롬프트 없이"
cli "$T/fork" "$FAKEPATH" pr-merge 7 --rebase --match-head-commit "$SHA$SHA"
assert_eq "$RC:$ARGS" "2:" "pr-merge: 80자 커밋은 사용법 오류다(양성 짝은 아래 64자)"
cli "$T/fork" "$FAKEPATH" pr-merge 7 --rebase --match-head-commit "${SHA}0123456789abcdef01234567"
assert_contains "$ARGS" "--match-head-commit ${SHA}0123456789abcdef01234567 -R " "pr-merge: 64자(sha256) 커밋도 받는다"
FAKE_GH_MODE=auth cli "$T/fork" "$FAKEPATH" pr-merge 7 --merge --match-head-commit "$SHA"
assert_eq "$RC" "4" "pr-merge: gh 의 종료 코드가 그대로 나온다"
cli "$T/fork" "$FAKEPATH" pr-merge 7 --merge
assert_eq "$RC:$ARGS" "2:" "pr-merge: head 커밋이 없으면 사용법 오류이고 gh 를 부르지 않는다 — 커밋에 묶이지 않은 머지는 없다"
NL='
'
for bad in abc1234 "${SHA%?}" "${SHA}0" "${SHA%?}G" "$(printf '%s' "$SHA" | tr 'a-f' 'A-F')" HEAD "" "$SHA$NL" " $SHA" "--admin"; do
  cli "$T/fork" "$FAKEPATH" pr-merge 7 --merge --match-head-commit "$bad"
  assert_eq "$RC:$ARGS" "2:" "pr-merge: 전체 SHA(16진 소문자 40자)가 아니면 사용법 오류이고 gh 를 부르지 않는다(${bad:-빈 값})"
done
cli "$T/fork" "$FAKEPATH" pr-merge 7 --match-head-commit "$SHA"
assert_eq "$RC:$ARGS" "2:" "pr-merge: 방식이 없으면 사용법 오류이고 gh 를 부르지 않는다"
cli "$T/fork" "$FAKEPATH" pr-merge 7 --merge --squash --match-head-commit "$SHA"
assert_eq "$RC:$ARGS" "2:" "pr-merge: 방식이 둘이면 사용법 오류이고 gh 를 부르지 않는다"

finish
