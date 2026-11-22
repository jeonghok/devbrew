#!/usr/bin/env bash
# 분해된 인터뷰 끝맺음의 PR 펜스(interview-pr) · 머지 펜스(interview-merge) · 다시 확인 펜스(interview-merge-recheck)
# — roadmap-draft SKILL.md(끝내기 커밋 펜스만 finishing.md)에서 뽑아 그대로 돌린다. 「값의 출처」 줄의 짝으로 끝내기 커밋 펜스(interview-commit)도 뽑아 돌린다.
# 펜스는 Bash 도구의 셸에서 돌므로 bash 와 zsh 둘 다에서 잰다(zsh 가 없으면 그 사실을 알리고 bash 만).
# 픽스처: 임시 레포(origin 은 git@github.com:<owner>/r.git — 가짜 ssh 가 로컬 bare 레포로 잇는다) + PATH 앞의
# 가짜 gh · 가짜 sleep. 실제 gh · 네트워크로 나가지 않는다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_finish_pr_merge.sh
set -u
ROOT_REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT_REPO/plugins/spec-distill"
. "$ROOT_REPO/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
unset DEVBREW_SPEC_DISTILL_DISABLE DEVBREW_SKIP_HOOKS GH_REPO GH_HOST
T="$(mktemp -d)"; [ -n "$T" ] && [ -d "$T" ] || { echo "mktemp 실패"; exit 1; }
T="$(cd "$T" && pwd -P)"; trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

fence() {   # fence <파일> <마커 이름> → 그 마커 사이 첫 bash 펜스 본문
  awk -v b="<!-- $2:begin -->" -v e="<!-- $2:end -->" '
    index($0,b){f=1;next} index($0,e){f=0} f&&/^```bash$/{c=1;next} f&&c&&/^```$/{c=0;next} f&&c' "$1"
}
nob() { no "$1"; printf '      출력: %s\n' "$2"; }
last() { printf '%s\n' "$1" | tail -n 1; }
FIN="$SD/skills/context-build/references/finishing.md"
PR="$SD/skills/roadmap-draft/SKILL.md"   # PR 과 머지 글이 사는 곳(로드맵 잡기)
PH='<Step A.5 의 PAYLOAD 절대경로>'
UPH='<interview-pr 이 낸 PR 주소>'
HPH='<interview-pr 이 낸 끝 커밋>'
pf="$(fence "$PR" interview-pr)"
mf="$(fence "$PR" interview-merge)"
rf="$(fence "$PR" interview-merge-recheck)"
cf="$(fence "$FIN" interview-commit)"
case "$pf" in *"BRIEF=\"$PH\""*'gh_repo.py" pr-open '*'gh_repo.py" pr-create '*) ok "전제: PR 펜스에 BRIEF 자리표와 gh_repo.py 호출 둘" ;; *) no "전제: PR 펜스를 못 뽑았다 — 아래 칸이 공허하다" ;; esac
# 권장 꼬리의 조건은 본문이 정한다 — ONLY 일 때만 달고 MIXED · UNKNOWN 이면 뗀다
ASK="$(grep -F '2. **머지 묻기.**' "$PR")"
assert_contains "$ASK" '「(권장)」 꼬리는 1 의 펜스가 `interview-pr-files: ONLY` 를 냈을 때만 단다' "본문: 권장 꼬리는 ONLY 일 때만"
assert_contains "$ASK" '`MIXED` 나 `UNKNOWN` 이면 꼬리를 떼어 「머지」 로 내고' "본문: MIXED · UNKNOWN 이면 꼬리를 뗀다"
case "$mf" in *"URL=\"$UPH\""*"HEAD_SHA=\"$HPH\""*'gh_repo.py" pr-number '*'gh_repo.py" pr-merge '*) ok "전제: 머지 펜스에 URL · 끝 커밋 자리표와 gh_repo.py 호출" ;; *) no "전제: 머지 펜스를 못 뽑았다 — 아래 칸이 공허하다" ;; esac
case "$rf" in *"BRIEF=\"$PH\""*"URL=\"$UPH\""*'gh_repo.py" pr-number '*'gh_repo.py" pr-identity '*) ok "전제: 다시 확인 펜스에 BRIEF · URL 자리표와 gh_repo.py 호출" ;; *) no "전제: 다시 확인 펜스를 못 뽑았다 — 아래 칸이 공허하다" ;; esac
case "$rf" in *"$HPH"*|*'gh_repo.py" pr-merge '*|*'gh_repo.py" pr-checks '*|*'gh_repo.py" pr-create '*|*" push "*) no "다시 확인 펜스는 읽기만 한다 — 끝 커밋 자리표 · 머지 · 검사 · 만들기 · push 가운데 하나가 있다" ;; *) ok "다시 확인 펜스는 읽기만 한다(머지 · 검사 · 만들기 · push 를 부르지 않는다)" ;; esac
case "$cf" in *"BRIEF=\"$PH\""*'repo_defaults.py" check-path interview_dir '*'repo_defaults.py" check-path roadmaps_dir '*) ok "전제: 커밋 펜스에 BRIEF 자리표와 check-path 둘" ;; *) no "전제: 커밋 펜스를 못 뽑았다 — 「값의 출처」 짝이 공허하다" ;; esac
# 플러그인 루트 가드 줄은 네 펜스가 글자 그대로 같다
g1="$(printf '%s\n' "$pf" | head -n 1)"
case "$g1" in 'SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || {'*'exit 1; }') ok "전제: PR 펜스 첫 줄이 플러그인 루트 가드다" ;; *) no "전제: PR 펜스 첫 줄이 가드가 아니다" ;; esac
for g in "$mf" "$rf" "$cf"; do
  assert_eq "$(printf '%s\n' "$g" | head -n 1)" "$g1" "펜스 첫 줄의 플러그인 루트 가드가 PR 펜스와 글자 그대로 같다"
done
# 판결 줄 없는 출력을 읽는 법은 본문이 정한다 — 표시 줄이 있으면 다시 확인, 없으면 NONE
HEADP="$(grep -F '**PR 과 머지.**' "$PR")"
assert_contains "$HEADP" '판결 줄 없이 끝나면(시간 초과 · 끊김 포함) `NONE` 으로 읽는다 — 하나만 다르다: 머지 펜스의 출력에 판결 줄이 없고 `interview-merge-requested:` 표시 줄이 있으면 `NONE` 으로 읽지 않고 3 의 다시 확인 펜스를 돌려 그 판결대로 잇는다.' "본문(절 머리): 표시 줄이 있으면 NONE 으로 읽지 않고 다시 확인"
assert_not_contains "$HEADP" '판결 줄 없이 끝나면(시간 초과 · 끊김 포함) `NONE` 으로 읽는다. ' "본문(절 머리): 옛 문장(예외 없는 NONE)이 남지 않았다"
assert_contains "$HEADP" '이 절의 펜스는 gh 를 직접 찾거나 부르지 않고' "본문(절 머리): 펜스가 셋이라 「이 절의 펜스는 gh 를 …」 이다"
assert_not_contains "$HEADP" '두 펜스는 gh 를' "본문(절 머리): 옛 「두 펜스는 gh 를 …」 가 남지 않았다"
STEP3="$(grep -F '3. **머지.**' "$PR")"
assert_contains "$STEP3" '판결 줄이 없고 `interview-merge-requested:` 표시 줄이 있으면 머지 요청이 이미 나갔을 수 있다 — `NONE` 으로 읽지 않고 머지 펜스 아래의 다시 확인 펜스를 돌려 그 판결대로 잇는다. 표시 줄도 없으면 `interview-merge: NONE` 으로 읽어 잇는다.' "본문(3 걸음): 그만둔 출력에 표시 줄이 있으면 다시 확인, 없으면 NONE"
assert_not_contains "$STEP3" '판결 줄이 이미 있으면 그 판결대로, 없으면 `interview-merge: NONE` 으로 읽어 잇는다' "본문(3 걸음): 옛 문장(표시 줄을 보지 않는 NONE)이 남지 않았다"
RECP="$(grep -F '**다시 확인 — ' "$PR")"
assert_contains "$RECP" '**다시 확인 — 판결 줄 없이 끝난 머지 펜스의 출력에 `interview-merge-requested:` 표시 줄이 있을 때만.**' "본문(다시 확인): 도는 조건"
assert_contains "$RECP" '(5초 간격 네 번까지)' "본문(다시 확인): 읽는 간격 · 횟수"

# AC10 — PR 을 묻는 조건은 로드맵을 커밋했는가 하나, 머지가 확인되면 언제나 지휘자 줄을 보이고 턴을 끝낸다
has() { assert_file_grep "$PR" "$1" "AC10: $1"; }
lacks() { assert_file_absent "$PR" "$1" "AC10(부재): $1"; }
has 'PR 을 열지 묻는 조건은 이 단계가 로드맵을 커밋했는가 하나다'
lacks '분해된 일 ①/② 만'                    # 앞 단계의 끝 질문 답을 읽지 않는다
lacks '여기서 계속'                          # 같은 턴에 지휘자를 부르는 갈래가 없다
has '머지가 확인되면 언제나 지휘자를 부르는 명령 줄을 보이고 턴을 끝낸다'
has '/spec-distill:epic-conductor <roadmap-path>'
# AC16 — PR 본문 펜스는 seed 경로를 상태 파일의 seed 값에서 읽고, framing 기록 경로에서 거꾸로 짓지 않는다.
# (기록은 seed 이름에서 도출되므로 동작 픽스처로는 두 값을 가를 수 없다 — 펜스 글로 문다.)
case "$pf" in *'RAW_A%.audit.md'*) no "AC16(부재): PR 펜스가 seed 경로를 기록 경로에서 짓는다" ;; *) ok "AC16(부재): PR 펜스가 seed 경로를 기록 경로에서 짓지 않는다" ;; esac
case "$pf" in *'/^seed:/'*'.state.md'*) ok "AC16: PR 펜스가 상태 파일의 seed 값을 읽는다" ;; *) no "AC16: PR 펜스가 상태 파일의 seed 값을 읽지 않는다" ;; esac

mkdir -p "$T/bin" "$T/remotes" || exit 1
cat > "$T/bin/gh" <<'FAKE'
#!/bin/sh
printf '%s\n' "$*" >> "$FAKE_GH_LOG"
st="$FAKE_GH_DIR/state"
[ -f "$st" ] || printf 'OPEN\n' > "$st"
case "$1 $2" in
  "pr list")
    [ -z "${FAKE_AUTH:-}" ] || { echo 'To get started with GitHub CLI, please run:  gh auth login' >&2; exit 4; }
    printf '%s\n' "$FAKE_PR_LIST" ;;
  "pr create")
    p=""; for a in "$@"; do [ "$p" != --body-file ] || cp "$a" "$FAKE_GH_DIR/body"; p="$a"; done
    [ "${FAKE_CREATE:-ok}" = ok ] || { echo 'pull request create failed: GraphQL: boom (createPullRequest)' >&2; exit 1; }
    echo "Creating pull request for feature/x into main in $FAKE_OWNER/r" >&2
    echo "https://github.com/$FAKE_OWNER/r/pull/7" ;;
  "pr view")
    [ -z "${FAKE_VIEW_AUTH:-}" ] || { echo 'To get started with GitHub CLI, please run:  gh auth login' >&2; exit 4; }   # PR 읽기의 인증 실패
    s="$(cat "$st")"; h="${FAKE_HEAD:-feature/x}"
    v=$(( $(cat "$FAKE_GH_DIR/views" 2>/dev/null || echo 0) + 1 )); echo "$v" > "$FAKE_GH_DIR/views"   # 이 실행의 몇 번째 읽기인가
    [ -z "${FAKE_VIEW_MERGED_AT:-}" ] || [ "$v" -lt "$FAKE_VIEW_MERGED_AT" ] || s=MERGED   # n 번째 읽기부터 MERGED(요청 직후의 늦은 반영)
    [ -z "${FAKE_HEAD_FROM2:-}" ] || [ "$v" -lt 2 ] || h="$FAKE_HEAD_FROM2"                # 둘째 읽기부터 다른 브랜치
    printf '{"number":%s,"state":"%s","headRefName":"%s","headRefOid":"%s","isCrossRepository":%s,"baseRefName":"%s","mergeCommit":null}\n' \
      "$3" "$s" "$h" "$(git --git-dir="$FAKE_REMOTE" rev-parse refs/heads/feature/x)" "${FAKE_CROSS:-false}" "${FAKE_BASE:-main}" ;;
  "pr checks")
    case "${FAKE_CHECKS:-none}" in
      none) echo "no checks reported on the 'feature/x' branch" >&2; exit 1 ;;
      pass) case "${FAKE_MOVE:-}: $* " in 1:*" --watch "*)   # 검사를 기다리는 사이 PR 에 다른 커밋이 올라온다
              new="$(GIT_AUTHOR_NAME=o GIT_AUTHOR_EMAIL=o@o.o GIT_COMMITTER_NAME=o GIT_COMMITTER_EMAIL=o@o.o \
                git --git-dir="$FAKE_REMOTE" commit-tree -p refs/heads/feature/x -m moved 'refs/heads/feature/x^{tree}')" || exit 1
              git --git-dir="$FAKE_REMOTE" update-ref refs/heads/feature/x "$new" || exit 1 ;;
            esac
            printf 'build\tpass\t1s\thttps://ci.example/1\n' ;;
      fail) printf 'build\tfail\t1s\thttps://ci.example/1\n'; exit 1 ;;
      hang) case " $* " in *" --watch "*) echo $$ > "$FAKE_GH_DIR/watch.pid"; exec /bin/sleep 30 ;; esac
            printf 'build\tpending\t0\thttps://ci.example/1\n'; exit 8 ;;
    esac ;;
  "repo view") printf '%s\n' "$FAKE_WAYS" ;;
  "pr merge")
    case "${FAKE_MERGE:-ok}:$4" in
      queue:*) echo '! Pull request will be added to the merge queue for main when ready' >&2; exit 0 ;;
      reject:*|second:--merge) echo 'GraphQL: Merge commits are not allowed on this repository. (mergePullRequest)' >&2; exit 1 ;;
    esac
    [ "$5" = "--match-head-commit" ] && [ "$6" = "$(git --git-dir="$FAKE_REMOTE" rev-parse refs/heads/feature/x)" ] \
      || { echo 'GraphQL: Head branch was modified. Review and try the merge again. (mergePullRequest)' >&2; exit 1; }
    git --git-dir="$FAKE_REMOTE" update-ref refs/heads/main refs/heads/feature/x || exit 1
    printf 'MERGED\n' > "$st"
    case "${FAKE_MERGE:-ok}" in
      failmerged) echo 'failed to run git: fatal: unable to access the remote' >&2; exit 1 ;;   # 머지는 됐는데 gh 는 실패로 끝난다
      cut) kill "$(cat "$FAKE_GH_DIR/fence.pid")"; exec /bin/sleep 0.3 ;;                       # 머지는 됐는데 펜스가 판결 전에 끊긴다
    esac ;;
esac
FAKE
cat > "$T/bin/sleep" <<'FAKE'
#!/bin/sh
[ -z "${FAKE_SLEEP_LOG:-}" ] || printf '%s\n' "$*" >> "$FAKE_SLEEP_LOG"
exec /bin/sleep "${FAKE_SLEEP:-0.05}"
FAKE
cat > "$T/bin/fakessh" <<'FAKE'
#!/bin/sh
[ -z "${FAKE_SSH_FAIL:-}" ] || { echo 'ssh: connect to host github.com port 22: Operation timed out' >&2; exit 255; }
c=""
for a in "$@"; do c="$a"; done
cd "$FAKE_REMOTES" && eval "exec git ${c#git-}"
FAKE
REAL_MKTEMP="$(command -v mktemp)" || { echo "mktemp 없음"; exit 1; }
# 가짜 mktemp — 실패 모드와, 만든 경로의 기록(펜스가 임시 파일을 지웠는지 본다. macOS 의 인자 없는 mktemp 는 TMPDIR 을 따르지 않는다)
printf '%s\n' '#!/bin/sh' '[ -z "${FAKE_MKTEMP_FAIL:-}" ] || { echo "mktemp: mkstemp failed: No space left on device" >&2; exit 1; }' \
  "f=\"\$(\"$REAL_MKTEMP\" \"\$@\")\" || exit 1" '[ -z "${FAKE_GH_DIR:-}" ] || printf "%s\n" "$f" >> "$FAKE_GH_DIR/mktemps"' 'printf "%s\n" "$f"' > "$T/bin/mktemp"
chmod +x "$T/bin/gh" "$T/bin/sleep" "$T/bin/fakessh" "$T/bin/mktemp" || exit 1
export GIT_SSH_COMMAND="$T/bin/fakessh" GIT_SSH_VARIANT=simple FAKE_REMOTES="$T/remotes"
export FAKE_PR_LIST='[]'
export FAKE_WAYS='{"mergeCommitAllowed":true,"squashMergeAllowed":true,"rebaseMergeAllowed":true}'

IDIR=docs/superpowers/interview
STEM="$IDIR/2026-10-15-t-interview"
RREL=docs/superpowers/roadmaps/2026-10-15-t
mk() {   # mk <owner> → 클론 경로. origin 은 git@github.com:<owner>/r.git, 기능 브랜치에 seed 커밋 + 인터뷰 커밋(세 파일 · 로드맵 폴더)
  local o="$T/remotes/$1/r.git" c="$T/$1"
  mkdir -p "$T/remotes/$1" "$T/gh-$1" && git init -q --bare -b main "$o" || return 1
  git clone -q "git@github.com:$1/r.git" "$c" 2>/dev/null || return 1
  git -C "$c" config user.email t@t.t; git -C "$c" config user.name t
  git -C "$c" symbolic-ref HEAD refs/heads/main   # 빈 레포의 클론은 첫 브랜치 이름을 원격에서 받지 못한다
  git -C "$c" commit -q --allow-empty -m init; git -C "$c" push -q origin main 2>/dev/null || return 1
  git -C "$c" remote set-head origin main >/dev/null 2>&1
  git -C "$c" switch -q -c feature/x
  mkdir -p "$c/$IDIR" "$c/$RREL"
  printf 'seed\n' > "$c/$IDIR/2026-10-15-t-interview-seed.md"
  git -C "$c" add -- "$IDIR"; git -C "$c" commit -q -m "docs(interview): seed"
  for s in .audit.md .state.md; do printf 'x\n' > "$c/$STEM$s"; done
  printf -- '---\ntype: interview-brief\n---\n## 7. Next Action\n\n분해됨 — %s/roadmap.md\n' "$RREL" > "$c/$STEM.md"
  printf -- '---\ntype: roadmap\n---\n# 로드맵\n' > "$c/$RREL/roadmap.md"; printf '# R1\n' > "$c/$RREL/R1.md"
  git -C "$c" add -- "$IDIR" "$RREL"; git -C "$c" commit -q -m "docs(interview): 2026-10-15-t-interview brief · audit · 상태 기록"
  printf '%s' "$c"
}
SHELL_ARGV=()
run() {   # run <owner> <펜스 본문> [<PR 주소> [<끝 커밋>]] → 자리표를 바꿔 지금 셸(SHELL_ARGV)로 돈 출력. gh 호출은 $T/gh-<owner>/log 에 쌓인다
  # BRIEF_REL 을 주면 brief 자리를 그 레포 상대 경로로 바꾼다.
  local c="$T/$1" body="${2//"$PH"/$T/$1/${BRIEF_REL:-$STEM.md}}"
  body="${body//"$UPH"/${3:-$UPH}}"
  body="${body//"$HPH"/${4:-$HPH}}"
  : > "$T/gh-$1/log"; : > "$T/gh-$1/sleeps"; : > "$T/gh-$1/mktemps"; rm -f "$T/gh-$1/views"
  ( cd "$c" && CLAUDE_PLUGIN_ROOT="$SD" PATH="$T/bin:$PATH" FAKE_GH_LOG="$T/gh-$1/log" FAKE_GH_DIR="$T/gh-$1" \
      FAKE_SLEEP_LOG="$T/gh-$1/sleeps" FAKE_OWNER="$1" FAKE_REMOTE="$T/remotes/$1/r.git" "${SHELL_ARGV[@]}" "$body" 2>&1 )
}
ghlog() { cat "$T/gh-$1/log"; }
sleeps() { tr '\n' ' ' < "$T/gh-$1/sleeps"; }   # 그 실행이 부른 sleep 의 인자들(간격)
remote_merge() {   # remote_merge <owner> [nostate] → 원격의 main 을 feature/x 로(머지됨). nostate 가 아니면 가짜 gh 의 상태도 MERGED 로
  git --git-dir="$T/remotes/$1/r.git" update-ref refs/heads/main refs/heads/feature/x || return 1
  [ "${2:-}" = nostate ] || printf 'MERGED\n' > "$T/gh-$1/state"
}
omain() { git -C "$T/$1" rev-parse refs/remotes/origin/main; }   # 로컬이 아는 origin 기본 브랜치
MARK='interview-merge-requested: 7'
SRC='값의 출처'
CUT='echo $$ > "$FAKE_GH_DIR/fence.pid"'   # 테스트만의 한 줄 — 가짜 gh 가 이 pid 를 죽여 「요청 뒤 끊김」을 만든다
ERRF='exec 2> "$FAKE_GH_DIR/stderr"'       # 테스트만의 한 줄 — 펜스의 stderr 를 파일로 갈라 받는다(run 의 출력에는 stdout 만 남는다)
head_of() { printf '%s\n' "$1" | sed -n 's/^interview-pr-head: //p'; }   # PR 펜스 출력에서 끝 커밋
remote_ref() { git --git-dir="$T/remotes/$1/r.git" rev-parse -q --verify "refs/heads/$2" 2>/dev/null || true; }

for sh_name in bash zsh; do
  sh_bin="$(command -v "$sh_name" 2>/dev/null)" || sh_bin=""
  if [ -z "$sh_bin" ]; then note "=== ${sh_name}: 이 머신에 없어 건너뛴다 ==="; continue; fi
  if [ "$sh_name" = zsh ]; then SHELL_ARGV=("$sh_bin" -f -c); else SHELL_ARGV=("$sh_bin" -c); fi
  P="${sh_name}-"
  note "=== ${sh_name}: PR 펜스 ==="

  # 1. 새 PR — 열린 PR 찾기 → push → 만들기. 인터뷰 폴더(seed 포함) · 로드맵 폴더의 파일뿐이면 ONLY
  n="${P}new"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(run "$n" "$pf")"
  assert_eq "$(last "$o")" "interview-pr: OPEN https://github.com/$n/r/pull/7" "새 PR: 마지막 줄이 판결(OPEN 과 주소)"
  assert_contains "$o" "[spec-distill] PR 을 열었다 — https://github.com/$n/r/pull/7" "새 PR: 연 사실을 보인다"
  assert_eq "$(remote_ref "$n" feature/x)" "$(git -C "$c" rev-parse HEAD)" "새 PR: 브랜치를 push 했다"
  assert_contains "$(ghlog "$n")" "pr list --state open --head feature/x --base main --json url,isCrossRepository --limit 20 -R github.com/$n/r" "새 PR: 열린 PR 찾기가 -R origin 으로 간다"
  assert_grep "$(ghlog "$n")" "^pr create --base main --head feature/x --title docs\(interview\): .* --body-file [^ ]+ -R github\.com/$n/r\$" "새 PR: 만들기가 -R origin 으로 간다"
  assert_contains "$o" "interview-pr-files: ONLY" "새 PR: seed · 세 파일 · 로드맵 폴더뿐이면 ONLY"
  assert_contains "$o" "이 PR 은 인터뷰 폴더와 로드맵 폴더의 파일만 담는다." "새 PR: ONLY 의 사람 줄"
  assert_eq "$(printf '%s\n' "$o" | tail -n 2 | head -n 1)" "interview-pr-head: $(git -C "$c" rev-parse HEAD)" "새 PR: 판결 바로 앞 줄이 push 한 끝 커밋"
  # 14a. 「값의 출처」 — 끝내기 커밋 펜스가 보인 키의 줄을 PR 펜스는 다시 보이지 않는다
  assert_not_contains "$o" "$SRC" "값의 출처: PR 펜스 출력에 없다"
  for kp in "interview_dir $c/$STEM.md" "roadmaps_dir $c/$RREL"; do   # 짝 1 — 걸러서 없는 것이지 원래 없는 것이 아니다
    d="$(python3 "$SD/scripts/repo_defaults.py" check-path "${kp%% *}" "${kp#* }" --root "$c" 2>&1)" && d_rc=0 || d_rc=$?
    assert_eq "$d_rc" "0" "값의 출처(짝 1): 같은 픽스처에서 check-path ${kp%% *} 를 직접 부르면 통과한다"
    assert_grep "$d" "^\[spec-distill\] ${SRC}: .+\(${kp%% *}\)\$" "값의 출처(짝 1): 그때 그 줄이 나온다 — 펜스가 걸러서 없는 것이다"
  done

  # 1b. AC16 — PR 본문이 올리는 파일 목록: 결과물 · audit · 상태 파일 · 로드맵 폴더, 알 때는 framing 기록 · seed 도(seed 경로는 상태 파일의 seed 값에서 온다 — 기록 경로에서 짓지 않는다)
  n="${P}body"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  SEEDREL="$IDIR/2026-10-15-t-framing-seed.md"
  printf 'seed\n' > "$c/$SEEDREL"
  printf -- '---\ntype: interview-seed-audit\n---\n' > "$c/$IDIR/2026-10-15-t-framing-seed.audit.md"
  printf -- '---\ntype: interview-state\nseed: %s\n---\n' "$SEEDREL" > "$c/$STEM.state.md"
  git -C "$c" add -- "$IDIR"; git -C "$c" commit -q -m "docs: framing"
  rm -f "$T/gh-$n/body"; o="$(run "$n" "$pf")"
  assert_eq "$(last "$o")" "interview-pr: OPEN https://github.com/$n/r/pull/7" "PR 본문(원자료 있음): 판결 OPEN"
  B="$(cat "$T/gh-$n/body" 2>/dev/null)"
  assert_contains "$B" "$STEM.md" "PR 본문(원자료 있음): 결과물을 댄다"
  assert_contains "$B" "로드맵 폴더" "PR 본문(원자료 있음): 로드맵 폴더를 댄다"
  assert_contains "$B" "$IDIR/2026-10-15-t-framing-seed.audit.md" "PR 본문(원자료 있음): framing 기록을 댄다"
  assert_contains "$B" "$SEEDREL" "PR 본문(원자료 있음): seed 를 댄다"
  # 원자료를 모르면(상태 파일에 seed 가 없다) 두 줄을 대지 않는다 — 기록 경로에서 seed 를 지어내지도 않는다
  n="${P}nobody"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  rm -f "$T/gh-$n/body"; o="$(run "$n" "$pf")"
  B="$(cat "$T/gh-$n/body" 2>/dev/null)"
  assert_contains "$B" "$STEM.md" "PR 본문(원자료 모름): 결과물은 댄다"
  assert_not_contains "$B" "framing 기록" "PR 본문(원자료 모름): framing 기록을 대지 않는다"
  assert_not_contains "$B" "seed" "PR 본문(원자료 모름): seed 를 대지 않는다"

  # 2. 이 레포 안 브랜치의 열린 PR 이 있으면 그것을 쓴다 — 다른 레포의 브랜치에서 온 PR 은 세지 않는다
  n="${P}reuse"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(FAKE_PR_LIST='[{"url":"https://github.com/fork/r/pull/3","isCrossRepository":true},{"url":"https://github.com/'"$n"'/r/pull/5","isCrossRepository":false}]' run "$n" "$pf")"
  assert_eq "$(last "$o")" "interview-pr: OPEN https://github.com/$n/r/pull/5" "열린 PR: 이 레포 안 브랜치의 PR 을 쓴다"
  assert_contains "$o" "이 브랜치의 열린 PR 을 쓴다 — https://github.com/$n/r/pull/5" "열린 PR: 쓴 사실을 보인다"
  assert_not_contains "$(ghlog "$n")" "pr create" "열린 PR: 새로 만들지 않는다"
  assert_eq "$(remote_ref "$n" feature/x)" "$(git -C "$c" rev-parse HEAD)" "열린 PR: 그래도 브랜치는 push 한다"
  o="$(FAKE_PR_LIST='[{"url":"https://github.com/fork/r/pull/3","isCrossRepository":true}]' run "$n" "$pf")"
  assert_contains "$(ghlog "$n")" "pr create" "다른 레포의 브랜치에서 온 PR 뿐이면 새로 만든다"

  # 3. 인터뷰 폴더 · 로드맵 폴더 밖의 파일이 있으면 MIXED — 목록을 보이고 판결은 그대로 OPEN
  n="${P}mixed"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  mkdir -p "$c/src" "$c/$IDIR/sub"; printf 'x\n' > "$c/src/app.py"; printf 'x\n' > "$c/$IDIR/sub/deep.md"; printf 'x\n' > "$c/src/한글 이름.py"
  git -C "$c" add -- src "$IDIR/sub"; git -C "$c" commit -q -m "feat: code"
  o="$(run "$n" "$pf")"
  assert_eq "$(last "$o")" "interview-pr: OPEN https://github.com/$n/r/pull/7" "섞인 PR: 판결은 그대로 OPEN"
  assert_contains "$o" "interview-pr-files: MIXED" "섞인 PR: MIXED"
  assert_contains "$o" "밖의 파일 3개도 담는다" "섞인 PR: 개수를 보인다"
  assert_contains "$o" "  - src/한글 이름.py" "섞인 PR: 한글 경로를 글자 그대로 보인다(8진 이스케이프가 아니다)"
  assert_contains "$o" "  - src/app.py" "섞인 PR: 코드 파일을 목록에 보인다"
  assert_contains "$o" "  - $IDIR/sub/deep.md" "섞인 PR: 인터뷰 폴더의 하위 폴더는 「바로 아래」 가 아니다"
  assert_not_contains "$o" "  - $STEM.md" "섞인 PR: brief 는 목록에 없다"
  assert_not_contains "$o" "  - $RREL/" "섞인 PR: 로드맵 폴더의 파일은 목록에 없다"
  assert_not_contains "$o" "interview-pr-files: ONLY" "섞인 PR: ONLY 를 내지 않는다"

  # 3b. brief §7 이 넓은 폴더를 가리키면 그 폴더를 통째로 빼지 않는다 — 커밋 펜스와 같은 판정(check-path)을 통과한 폴더만 뺀다
  n="${P}wide"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  mkdir -p "$c/src"; printf 'x\n' > "$c/src/app.py"; printf -- '---\ntype: roadmap\n---\n# 로드맵\n' > "$c/src/roadmap.md"
  printf -- '---\ntype: interview-brief\n---\n## 7. Next Action\n\n분해됨 — src/roadmap.md\n' > "$c/$STEM.md"
  git -C "$c" add -- src "$STEM.md"; git -C "$c" commit -q -m "feat: code beside a roadmap"
  o="$(run "$n" "$pf")"
  assert_contains "$o" "interview-pr-files: MIXED" "넓은 §7: 그 폴더 아래 코드가 있으면 MIXED"
  assert_contains "$o" "  - src/app.py" "넓은 §7: 그 폴더의 코드를 목록에 보인다"
  assert_contains "$o" "brief §7 의 로드맵 폴더가 정해진 로드맵 폴더 바로 아래가 아니다(위 사유) — 그 폴더의 파일도 밖의 파일로 센다: $c/src" "넓은 §7: 빼지 않은 사실과 폴더를 보인다"
  assert_not_contains "$o" "interview-pr-files: ONLY" "넓은 §7: ONLY 를 내지 않는다"
  assert_contains "$o" "[spec-distill] 부모 폴더가 다르다: src 의 부모는 / 인데 정해진 폴더는 docs/superpowers/roadmaps/ 다(roadmaps_dir) — 그 폴더 바로 아래 경로를 준다" "값의 출처(짝 2): 넓은 §7 — 해결자의 사유 줄은 그대로 보인다"
  assert_not_contains "$o" "$SRC" "값의 출처: 넓은 §7 — 판정이 거부돼도 그 줄은 없다"
  # 3c. brief 가 정해진 인터뷰 폴더 바로 아래가 아니면 그 폴더도 빼지 않는다
  n="${P}stray"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  mkdir -p "$c/notes"; cp "$c/$STEM.md" "$c/notes/b.md"; git -C "$c" add -- notes; git -C "$c" commit -q -m "docs: stray brief"
  o="$(BRIEF_REL=notes/b.md run "$n" "$pf")"
  assert_contains "$o" "interview-pr-files: MIXED" "인터뷰 폴더 밖의 brief: MIXED"
  assert_contains "$o" "  - notes/b.md" "인터뷰 폴더 밖의 brief: 그 폴더의 파일을 목록에 보인다"
  assert_contains "$o" "brief 가 정해진 인터뷰 폴더 바로 아래가 아니다(위 사유)" "인터뷰 폴더 밖의 brief: 빼지 않은 사실을 보인다"
  assert_contains "$o" "[spec-distill] 부모 폴더가 다르다: notes/b.md 의 부모는 notes/ 인데 정해진 폴더는 docs/superpowers/interview/ 다(interview_dir) — 그 폴더 바로 아래 경로를 준다" "값의 출처(짝 2): 인터뷰 폴더 밖의 brief — 해결자의 사유 줄은 그대로 보인다"
  assert_not_contains "$o" "$SRC" "값의 출처: 인터뷰 폴더 밖의 brief — 판정이 거부돼도 그 줄은 없다"
  # 걸러 낸 뒤에도 해결자의 줄은 stderr 로, 펜스의 줄은 stdout 으로 간다
  o="$(BRIEF_REL=notes/b.md run "$n" "$ERRF
$pf")"; e="$(cat "$T/gh-$n/stderr")"
  assert_contains "$e" "[spec-distill] 부모 폴더가 다르다: notes/b.md 의 부모는 notes/ 인데" "값의 출처(짝 2): 해결자의 사유 줄은 stderr 로 다시 나온다"
  assert_not_contains "$o" "부모 폴더가 다르다" "값의 출처(짝 2): 해결자의 사유 줄이 stdout 으로 옮겨 가지 않았다"
  assert_contains "$o" "brief 가 정해진 인터뷰 폴더 바로 아래가 아니다(위 사유)" "값의 출처(짝 2): 펜스의 줄은 stdout 그대로다"
  assert_not_contains "$e$o" "$SRC" "값의 출처: stdout · stderr 어디에도 그 줄은 없다"
  # 임시 파일을 못 만들면 거르지 않고 그대로 돈다 — 판정의 종료 코드(거부)와 사유 줄은 그대로이고, 그때는 「값의 출처」 줄도 보인다
  o="$(FAKE_MKTEMP_FAIL=1 FAKE_PR_LIST='[{"url":"https://github.com/'"$n"'/r/pull/5","isCrossRepository":false}]' BRIEF_REL=notes/b.md run "$n" "$pf")"
  assert_eq "$(last "$o")" "interview-pr: OPEN https://github.com/$n/r/pull/5" "임시 파일 실패(거부되는 판정): 판결은 그대로 OPEN"
  assert_contains "$o" "mktemp: mkstemp failed" "임시 파일 실패(거부되는 판정): 전제 — mktemp 가 실패했다"
  assert_contains "$o" "interview-pr-files: MIXED" "임시 파일 실패(거부되는 판정): MIXED"
  assert_contains "$o" "  - notes/b.md" "임시 파일 실패(거부되는 판정): 판정의 거부가 그대로 읽힌다 — 그 폴더의 파일을 목록에 보인다"
  assert_contains "$o" "brief 가 정해진 인터뷰 폴더 바로 아래가 아니다(위 사유)" "임시 파일 실패(거부되는 판정): 판정의 거부가 그대로 읽힌다 — 빼지 않은 사실을 보인다"
  assert_contains "$o" "[spec-distill] 부모 폴더가 다르다: notes/b.md 의 부모는 notes/ 인데" "임시 파일 실패(거부되는 판정): 사유 줄이 보인다"
  assert_eq "$(printf '%s\n' "$o" | grep -c "^\[spec-distill\] ${SRC}: ")" "2" "임시 파일 실패(거부되는 판정): 거르지 않아 「값의 출처」 줄이 판정마다 보인다"
  # 3d. 파일을 세지 못하면 UNKNOWN — ONLY 를 내지 않아 권장 꼬리가 붙지 않는 쪽으로 간다
  n="${P}unknown"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  git -C "$c" checkout -q --orphan feature/y; git -C "$c" commit -q -m "기본 브랜치와 조상이 없는 브랜치"
  o="$(run "$n" "$pf")"
  assert_eq "$(last "$o")" "interview-pr: OPEN https://github.com/$n/r/pull/7" "세지 못함: 판결은 그대로 OPEN"
  assert_eq "$(printf '%s\n' "$o" | grep '^interview-pr-files: ')" "interview-pr-files: UNKNOWN" "세지 못함: 파일 줄은 UNKNOWN 하나뿐이다"
  assert_contains "$o" "이 PR 에 담긴 파일을 세지 못했다(위 사유) — 머지하기 전에 PR 에서 직접 확인한다." "세지 못함: 사람 줄"
  assert_contains "$o" "no merge base" "세지 못함: git 의 사유가 위에 보인다"

  # 4. gh 실패(인증) — push 하기 전에 멈춘다
  n="${P}auth"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(FAKE_AUTH=1 run "$n" "$pf")"
  assert_eq "$(last "$o")" "interview-pr: NONE" "gh 실패: 판결 NONE"
  assert_contains "$o" "gh 인증이 안 됐다 — gh auth login --hostname github.com 를 돈다" "gh 실패: gh_repo.py 의 사유를 보인다"
  assert_contains "$o" "PR 을 열지 않았다 — 열린 PR 을 찾지 못했다(위 사유)" "gh 실패: 사람 줄"
  assert_eq "$(remote_ref "$n" feature/x)" "" "gh 실패: push 하지 않았다"
  # 4b. PR 만들기 실패 · 자리표 그대로
  o="$(FAKE_CREATE=fail run "$n" "$pf")"
  assert_eq "$(last "$o")" "interview-pr: NONE" "만들기 실패: 판결 NONE"
  assert_contains "$o" "PR 을 만들지 못했다(위 사유)" "만들기 실패: 사람 줄"
  o="$( cd "$c" && CLAUDE_PLUGIN_ROOT="$SD" PATH="$T/bin:$PATH" FAKE_GH_LOG="$T/gh-$n/log" "${SHELL_ARGV[@]}" "$pf" 2>&1 )"
  assert_eq "$(last "$o")" "interview-pr: NONE" "자리표 그대로: 판결 NONE"

  note "=== ${sh_name}: 머지 펜스 ==="
  # 5. 머지 — 검사 없음을 다시 본 뒤 머지, 상태 확인, origin 받기
  n="${P}merge"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"; H="$(head_of "$o")"
  before="$(git -C "$c" rev-parse refs/remotes/origin/main)"
  o="$(run "$n" "$mf" "$URL" "$H")"
  assert_eq "$(last "$o")" "interview-merge: MERGED" "머지: 마지막 줄이 판결(MERGED)"
  assert_contains "$o" "[spec-distill] PR 을 머지했다(merge) — $URL" "머지: 방식과 주소를 보인다"
  assert_eq "$(printf '%s\n' "$o" | grep -e "^interview-merge-requested: " -e 'PR 을 머지했다' | tr '\n' '|')" "${MARK}|[spec-distill] PR 을 머지했다(merge) — ${URL}|" "머지: 요청 표시 줄(PR 번호) 하나가 머지한 줄보다 먼저 나온다"
  L="$(ghlog "$n")"
  assert_eq "$(printf '%s\n' "$L" | grep -c "^pr checks 7 -R github.com/$n/r\$")" "6" "머지: 「검사 없음」을 여섯 번 본다"
  assert_not_contains "$L" "--watch" "머지: 검사가 없으면 기다리지 않는다"
  assert_contains "$L" "repo view --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed github.com/$n/r" "머지: 허용 방식을 origin 레포에 묻는다"
  assert_contains "$L" "pr merge 7 --merge --match-head-commit $H -R github.com/$n/r" "머지: 번호 · 물을 때의 끝 커밋 · -R origin 으로 머지한다"
  assert_eq "$H" "$(git -C "$c" rev-parse HEAD)" "머지: 그 끝 커밋은 PR 펜스가 push 한 커밋이다"
  assert_eq "$(printf '%s\n' "$L" | grep -c "^pr view 7 ")" "2" "머지: 신원 확인 한 번 · 머지 뒤 상태 확인 한 번"
  assert_not_contains "$L" "$URL" "머지: gh 에 주소를 넘기지 않는다(번호와 -R 만)"
  after="$(git -C "$c" rev-parse refs/remotes/origin/main)"
  [ "$before" != "$after" ] && [ "$after" = "$(git -C "$c" rev-parse HEAD)" ] && ok "머지: 로컬의 origin 기본 브랜치 ref 가 머지된 끝으로 왔다(fetch)" || nob "머지: origin 을 받지 않았다" "$before → $after"

  # 6. 다른 레포의 PR 주소 — gh 를 부르기 전에 거절
  n="${P}other"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(run "$n" "$pf")"; H="$(head_of "$o")"
  o="$(run "$n" "$mf" "https://github.com/someone-else/r/pull/7" "$H")"
  assert_eq "$(last "$o")" "interview-merge: NONE" "다른 레포 주소: 판결 NONE"
  assert_contains "$o" "PR 주소의 레포(github.com/someone-else/r)가 origin(github.com/$n/r)이 아니다" "다른 레포 주소: gh_repo.py 의 사유"
  assert_contains "$o" "머지하지 않았다 — PR 주소가 이 레포(origin)의 PR 이 아니다(위 사유)" "다른 레포 주소: 사람 줄"
  assert_eq "$(ghlog "$n")" "" "다른 레포 주소: gh 를 한 번도 부르지 않는다"
  o="$(run "$n" "$mf" "https://GitHub.com/${n}/R/pull/7" "$H")"
  assert_not_contains "$o" "이 레포(origin)의 PR 이 아니다" "양성 짝: 대소문자만 다른 같은 레포 주소는 거절하지 않는다"
  assert_contains "$(ghlog "$n")" "pr view 7 " "양성 짝: 같은 레포 주소면 PR 을 읽는다"
  assert_eq "$(last "$o")" "interview-merge: MERGED" "양성 짝: 같은 레포 주소면 머지까지 간다"

  # 7. 머지 대기열 — gh 는 rc 0 인데 PR 은 OPEN 그대로
  n="${P}queue"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"; H="$(head_of "$o")"
  before="$(git -C "$c" rev-parse refs/remotes/origin/main)"
  o="$(FAKE_MERGE=queue run "$n" "$mf" "$URL" "$H")"
  assert_eq "$(last "$o")" "interview-merge: NONE" "대기열: gh 가 rc 0 이어도 MERGED 가 아니면 NONE"
  assert_contains "$o" "PR 이 아직 머지되지 않았다(읽은 상태: OPEN)" "대기열: 읽은 상태를 보인다"
  assert_not_contains "$o" "PR 을 머지했다" "대기열: 머지했다고 말하지 않는다"
  assert_eq "$(ghlog "$n" | grep -c "^pr merge ")" "1" "대기열: 다음 머지 방식을 시도하지 않는다"
  assert_eq "$(ghlog "$n" | grep -c "^pr view 7 ")" "5" "대기열: 상태를 네 번까지 다시 읽는다(신원 확인 한 번 더)"
  Q_SLEEPS="$(sleeps "$n" | sed 's/^\(10 \)*//')"   # 앞의 10초들은 「검사 없음」 다시 보기다 — 그 뒤가 머지 뒤 상태 읽기의 간격
  assert_eq "$Q_SLEEPS" "5 5 5 " "대기열: 머지 뒤 상태 읽기 사이를 5초씩 세 번 쉰다"
  assert_eq "$(printf '%s\n' "$o" | grep -c "^${MARK}\$")" "1" "대기열: 요청 표시 줄은 하나다"
  assert_eq "$(git -C "$c" rev-parse refs/remotes/origin/main)" "$before" "대기열: 머지 전이라 origin 을 받지 않는다"

  # 8. 머지 뒤 origin 을 받지 못함 — 알리고 판결은 MERGED
  n="${P}nofetch"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"; H="$(head_of "$o")"
  o="$(FAKE_SSH_FAIL=1 run "$n" "$mf" "$URL" "$H")"
  assert_eq "$(last "$o")" "interview-merge: MERGED" "fetch 실패: 판결은 MERGED 그대로"
  assert_contains "$o" "머지 뒤 origin 을 받지 못했다(위 사유) — 지휘자를 부르기 전에 git fetch origin 을 돌린다." "fetch 실패: 알린다"
  assert_contains "$o" "PR 을 머지했다(merge)" "fetch 실패: 머지한 사실은 보인다"

  # 9. 신원 불일치 · 검사 실패 · 검사 통과 · 방식 거절
  n="${P}misc"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"; H="$(head_of "$o")"
  o="$(FAKE_HEAD=other-branch run "$n" "$mf" "$URL" "$H")"
  assert_contains "$o" "이 PR 은 열린, 이 레포의 feature/x → main PR 이 아니거나 끝 커밋이 물을 때(${H})와 다르다(읽은 것: OPEN main other-branch false ${H})" "신원 불일치: 읽은 것을 보이고 멈춘다"
  assert_not_contains "$(ghlog "$n")" "pr merge" "신원 불일치: 머지하지 않는다"
  o="$(FAKE_CHECKS=fail run "$n" "$mf" "$URL" "$H")"
  assert_eq "$(last "$o")" "interview-merge: NONE" "검사 실패: 판결 NONE"
  assert_contains "$o" "CI 검사가 통과하지 않았다(rc 1, 위 목록)" "검사 실패: 사유"
  assert_not_contains "$(ghlog "$n")" "pr merge" "검사 실패: 머지하지 않는다"
  assert_not_contains "$o" "interview-merge-requested" "검사 실패: 요청을 보내지 않았으니 표시 줄도 없다"
  o="$(FAKE_CHECKS=hang FAKE_SLEEP=0.01 run "$n" "$mf" "$URL" "$H")"
  assert_contains "$o" "CI 검사를 30분 기다려도 끝나지 않았다" "검사가 끝나지 않음: 기다림 상한에서 멈춘다"
  assert_not_contains "$o" "interview-merge-requested" "검사가 끝나지 않음: 기다리는 동안에는 표시 줄이 없다"
  wp="$(cat "$T/gh-$n/watch.pid" 2>/dev/null)" || wp=""
  [ -n "$wp" ] && ! kill -0 "$wp" 2>/dev/null && ok "검사가 끝나지 않음: 기다리던 gh 를 끝냈다" || nob "검사가 끝나지 않음: 기다리던 gh 가 남았다" "pid ${wp:-없음}"
  o="$(FAKE_WAYS='{"mergeCommitAllowed":false,"squashMergeAllowed":true,"rebaseMergeAllowed":true}' FAKE_CHECKS=pass run "$n" "$mf" "$URL" "$H")"
  L="$(ghlog "$n")"
  assert_contains "$L" "pr checks 7 --watch --interval 15 -R github.com/$n/r" "검사 통과: 끝나길 기다린다(-R origin)"
  assert_not_contains "$L" "pr merge 7 --merge" "허용 방식: 허용하지 않는 방식은 시도하지 않는다"
  assert_contains "$o" "PR 을 머지했다(squash)" "허용 방식: 허용된 첫 방식으로 머지한다"
  assert_eq "$(last "$o")" "interview-merge: MERGED" "검사 통과: 판결 MERGED"
  n="${P}second"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"; H="$(head_of "$o")"
  o="$(FAKE_MERGE=second run "$n" "$mf" "$URL" "$H")"
  assert_contains "$o" "merge 머지가 거절됐다(위 사유) — 다음 방식을 시도한다." "방식 거절: 알리고 다음 방식으로"
  assert_contains "$o" "PR 을 머지했다(squash)" "방식 거절: 다음 방식으로 머지한다"
  assert_eq "$(printf '%s\n' "$o" | grep -e "^interview-merge-requested: " -e '머지가 거절됐다' -e 'PR 을 머지했다' | sed 's/^\[spec-distill\] //;s/ — .*//;s/(위 사유)//' | tr '\n' '|')" "${MARK}|merge 머지가 거절됐다|${MARK}|PR 을 머지했다(squash)|" "방식 거절: 요청 표시 줄은 방식마다 요청 바로 앞에 낸다"
  o="$(run "$n" "$mf")"
  assert_contains "$o" "머지하지 않았다 — PR 주소가 비었거나 자리표 그대로다" "자리표 그대로: 머지하지 않는다"
  for bad in "" "${H}Z" "not-a-commit"; do
    o="$(run "$n" "$mf" "$URL" "$bad")"
    assert_contains "$o" "머지하지 않았다 — 끝 커밋이 비었거나 자리표 그대로다" "끝 커밋 자리표: 16진이 아니면 머지하지 않는다(${bad:-자리표 그대로})"
    assert_eq "$(ghlog "$n")" "" "끝 커밋 자리표: gh 를 부르지 않는다(${bad:-자리표 그대로})"
  done

  # 10. 묻고 난 뒤 PR 의 끝 커밋이 바뀌면 머지하지 않는다
  # 10a. 머지 펜스가 돌기 전에 바뀜 — 신원 확인에서 멈춘다
  n="${P}moved"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"; H="$(head_of "$o")"
  git -C "$c" commit -q --allow-empty -m "뒤에 올라온 커밋"; git -C "$c" push -q origin feature/x 2>/dev/null
  mainref="$(remote_ref "$n" main)"
  o="$(run "$n" "$mf" "$URL" "$H")"
  assert_eq "$(last "$o")" "interview-merge: NONE" "끝 커밋이 바뀜(머지 전): 판결 NONE"
  assert_contains "$o" "끝 커밋이 물을 때(${H})와 다르다(읽은 것: OPEN main feature/x false $(remote_ref "$n" feature/x))" "끝 커밋이 바뀜(머지 전): 두 커밋을 보인다"
  assert_not_contains "$(ghlog "$n")" "pr merge" "끝 커밋이 바뀜(머지 전): 머지를 요청하지 않는다"
  assert_eq "$(remote_ref "$n" main)" "$mainref" "끝 커밋이 바뀜(머지 전): 기본 브랜치는 그대로다"
  # 10b. CI 를 기다리는 사이 바뀜 — 머지 요청이 물을 때의 커밋에 묶여 있어 거절되고, 다른 방식으로 다시 시도하지 않는다
  n="${P}moved2"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"; H="$(head_of "$o")"
  mainref="$(remote_ref "$n" main)"
  o="$(FAKE_CHECKS=pass FAKE_MOVE=1 run "$n" "$mf" "$URL" "$H")"
  [ "$(remote_ref "$n" feature/x)" != "$H" ] && ok "전제: 검사를 기다리는 사이 PR 의 끝 커밋이 바뀌었다" || no "전제: 끝 커밋이 그대로다 — 아래 칸이 공허하다"
  assert_eq "$(last "$o")" "interview-merge: NONE" "끝 커밋이 바뀜(기다리는 사이): 판결 NONE"
  assert_contains "$(ghlog "$n")" "pr merge 7 --merge --match-head-commit $H -R github.com/$n/r" "끝 커밋이 바뀜(기다리는 사이): 머지 요청은 물을 때의 커밋에 묶여 있다"
  assert_eq "$(ghlog "$n" | grep -c "^pr merge ")" "1" "끝 커밋이 바뀜(기다리는 사이): 다른 방식으로 다시 시도하지 않는다"
  assert_contains "$o" "머지가 거절됐고(위 사유) PR 이 물을 때와 달라졌다" "끝 커밋이 바뀜(기다리는 사이): 사유를 보인다"
  assert_contains "$o" "물을 때의 끝 커밋: ${H}" "끝 커밋이 바뀜(기다리는 사이): 물을 때의 커밋을 보인다"
  assert_not_contains "$o" "PR 을 머지했다" "끝 커밋이 바뀜(기다리는 사이): 머지했다고 말하지 않는다"
  assert_eq "$(remote_ref "$n" main)" "$mainref" "끝 커밋이 바뀜(기다리는 사이): 기본 브랜치는 그대로다"

  note "=== ${sh_name}: 이미 머지됨 · 실패 뒤 머지됨 ==="
  # 11. 물을 때 이미 머지됨 — 「머지하지 않았다」 가 아니라 머지됨으로 읽고 origin 을 받는다. 검사를 기다리지도 머지를 요청하지도 않는다
  n="${P}already"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"; H="$(head_of "$o")"
  before="$(omain "$n")"; remote_merge "$n"
  for kv in "FAKE_HEAD=other-branch" "FAKE_BASE=develop" "FAKE_CROSS=true"; do   # 양의 대조 — 같은 머지 상태인데 브랜치 · 바탕 · 레포가 다르면 머지됨으로 읽지 않는다
    o="$(export "$kv"; run "$n" "$mf" "$URL" "$H")"
    assert_eq "$(last "$o")" "interview-merge: NONE" "이미 머지됨(대조 ${kv}): 판결 NONE"
    assert_contains "$o" "머지하지 않았다 — 이 PR 은 열린, 이 레포의 feature/x → main PR 이 아니거나" "이미 머지됨(대조 ${kv}): 신원 불일치로 멈춘다"
    assert_contains "$o" "(읽은 것: MERGED " "이미 머지됨(대조 ${kv}): 읽은 상태는 머지됨이다(대조가 같은 상태에서 갈린다)"
    assert_not_contains "$o" "이미 머지돼 있다" "이미 머지됨(대조 ${kv}): 머지돼 있다고 말하지 않는다"
    assert_eq "$(omain "$n")" "$before" "이미 머지됨(대조 ${kv}): origin 을 받지 않는다"
  done
  o="$(run "$n" "$mf" "$URL" "$H")"
  assert_eq "$(last "$o")" "interview-merge: MERGED" "이미 머지됨: 마지막 줄이 판결(MERGED)"
  assert_contains "$o" "[spec-distill] PR 이 이미 머지돼 있다 — $URL" "이미 머지됨: 그 사실과 주소를 보인다"
  assert_not_contains "$o" "머지하지 않았다" "이미 머지됨: 「머지하지 않았다」 고 말하지 않는다"
  assert_not_contains "$o" "PR 을 머지했다" "이미 머지됨: 이 펜스가 머지했다고 말하지 않는다"
  assert_not_contains "$o" "interview-merge-requested" "이미 머지됨: 요청을 보내지 않았으니 표시 줄도 없다"
  L="$(ghlog "$n")"
  assert_not_contains "$L" "pr merge" "이미 머지됨: 머지를 요청하지 않는다"
  assert_not_contains "$L" "pr checks" "이미 머지됨: CI 검사를 기다리지 않는다"
  assert_eq "$(printf '%s\n' "$L" | grep -c "^pr view 7 ")" "1" "이미 머지됨: PR 을 한 번 읽는다"
  assert_eq "$(sleeps "$n")" "" "이미 머지됨: 기다리지 않는다(sleep 없음)"
  after="$(omain "$n")"
  [ "$before" != "$after" ] && [ "$after" = "$H" ] && ok "이미 머지됨: 로컬의 origin 기본 브랜치 ref 가 머지된 끝으로 왔다(fetch)" || nob "이미 머지됨: origin 을 받지 않았다" "$before → $after"
  # 11b. 끝 커밋은 대조하지 않는다 — 물은 뒤 커밋이 더 올라온 채 머지됐어도 머지됨이다
  o="$(run "$n" "$mf" "$URL" "0000000000000000000000000000000000000000")"
  assert_eq "$(last "$o")" "interview-merge: MERGED" "이미 머지됨(끝 커밋이 물을 때와 다름): 그래도 MERGED"
  # 11c. 이미 머지됐는데 origin 을 받지 못함 — 알리고 판결은 MERGED
  o="$(FAKE_SSH_FAIL=1 run "$n" "$mf" "$URL" "$H")"
  assert_eq "$(last "$o")" "interview-merge: MERGED" "이미 머지됨(fetch 실패): 판결은 MERGED 그대로"
  assert_contains "$o" "머지 뒤 origin 을 받지 못했다(위 사유) — 지휘자를 부르기 전에 git fetch origin 을 돌린다." "이미 머지됨(fetch 실패): 알린다"

  # 12. gh 의 머지 명령이 실패로 끝났는데 다시 읽으니 머지됨 — 머지됨으로 읽고 다음 방식을 시도하지 않는다
  n="${P}failmerged"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"; H="$(head_of "$o")"
  before="$(omain "$n")"
  o="$(FAKE_MERGE=failmerged run "$n" "$mf" "$URL" "$H")"
  assert_eq "$(last "$o")" "interview-merge: MERGED" "실패 뒤 머지됨: 마지막 줄이 판결(MERGED)"
  assert_contains "$o" "[spec-distill] gh 의 머지 명령은 실패로 끝났지만(위 사유) PR 은 머지돼 있다 — $URL" "실패 뒤 머지됨: 그 사실과 주소를 보인다"
  assert_contains "$o" "failed to run git: fatal: unable to access the remote" "실패 뒤 머지됨: gh 의 사유가 위에 보인다"
  assert_not_contains "$o" "머지하지 않았다" "실패 뒤 머지됨: 「머지하지 않았다」 고 말하지 않는다"
  assert_not_contains "$o" "다음 방식을 시도한다" "실패 뒤 머지됨: 다음 방식으로 간다고 말하지 않는다"
  assert_not_contains "$o" "PR 을 머지했다(" "실패 뒤 머지됨: 정상 경로의 머지한 줄은 내지 않는다"
  assert_eq "$(ghlog "$n" | grep -c "^pr merge ")" "1" "실패 뒤 머지됨: 머지 요청은 한 번이다(다음 방식을 시도하지 않는다)"
  assert_eq "$(ghlog "$n" | grep -c "^pr view 7 ")" "2" "실패 뒤 머지됨: 신원 확인 한 번 · 실패 뒤 다시 읽기 한 번"
  after="$(omain "$n")"
  [ "$before" != "$after" ] && [ "$after" = "$H" ] && ok "실패 뒤 머지됨: 로컬의 origin 기본 브랜치 ref 가 머지된 끝으로 왔다(fetch)" || nob "실패 뒤 머지됨: origin 을 받지 않았다" "$before → $after"
  # 12b. 양의 대조 — 실패 뒤 다시 읽은 것이 머지됨이어도 브랜치가 다르면 머지됨으로 읽지 않는다(둘째 읽기부터 다른 브랜치)
  n="${P}failother"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"; H="$(head_of "$o")"
  before="$(omain "$n")"
  o="$(FAKE_MERGE=failmerged FAKE_HEAD_FROM2=other-branch run "$n" "$mf" "$URL" "$H")"
  assert_eq "$(last "$o")" "interview-merge: NONE" "실패 뒤 머지됨(대조 — 다른 브랜치): 판결 NONE"
  assert_contains "$o" "머지가 거절됐고(위 사유) PR 이 물을 때와 달라졌다 — 끝 커밋이 바뀌었거나 닫혔다(읽은 것: MERGED main other-branch false ${H}" "실패 뒤 머지됨(대조 — 다른 브랜치): 읽은 것을 보이고 멈춘다"
  assert_eq "$(ghlog "$n" | grep -c "^pr merge ")" "1" "실패 뒤 머지됨(대조 — 다른 브랜치): 다음 방식을 시도하지 않는다"
  assert_eq "$(omain "$n")" "$before" "실패 뒤 머지됨(대조 — 다른 브랜치): origin 을 받지 않는다"

  note "=== ${sh_name}: 다시 확인 펜스 ==="
  # 13. 요청 표시 뒤 끊김 — 머지 펜스는 판결 줄 없이 끝나고, 다시 확인 펜스가 머지됨으로 읽는다
  n="${P}cut"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"; H="$(head_of "$o")"
  before="$(omain "$n")"
  o="$(FAKE_MERGE=cut run "$n" "$CUT
$mf" "$URL" "$H" 2>/dev/null)"
  assert_eq "$(printf '%s\n' "$o" | grep -c "^${MARK}\$")" "1" "끊김: 출력에 요청 표시 줄이 있다"
  assert_not_grep "$o" "^interview-merge: " "끊김: 판결 줄이 없다"
  assert_eq "$(last "$o")" "$MARK" "끊김: 마지막 줄이 표시 줄이다(요청 바로 앞에 낸다)"
  assert_eq "$(ghlog "$n" | grep -c "^pr merge ")" "1" "끊김: 머지 요청은 나갔다"
  assert_eq "$(remote_ref "$n" main)" "$H" "끊김: 원격은 머지됐다"
  assert_eq "$(omain "$n")" "$before" "끊김: 머지 펜스는 origin 을 받지 못하고 끝났다"
  o="$(run "$n" "$rf" "$URL")"
  assert_eq "$(last "$o")" "interview-merge: MERGED" "다시 확인(머지됨): 마지막 줄이 판결(MERGED)"
  assert_contains "$o" "[spec-distill] 다시 확인하니 PR 이 머지돼 있다 — $URL" "다시 확인(머지됨): 그 사실과 주소를 보인다"
  assert_not_contains "$o" "머지 요청은 나갔지만" "다시 확인(머지됨): 머지되지 않았다고 말하지 않는다"
  L="$(ghlog "$n")"
  assert_not_contains "$L" "pr merge" "다시 확인(머지됨): 머지를 요청하지 않는다"
  assert_not_contains "$L" "pr checks" "다시 확인(머지됨): 검사를 부르지 않는다"
  assert_eq "$L" "pr view 7 --json number,state,headRefName,headRefOid,isCrossRepository,baseRefName,mergeCommit -R github.com/$n/r" "다시 확인(머지됨): gh 호출은 PR 읽기 한 번뿐이다(-R origin)"
  assert_eq "$(sleeps "$n")" "" "다시 확인(머지됨): 첫 읽기에 머지됨이면 기다리지 않는다"
  after="$(omain "$n")"
  [ "$before" != "$after" ] && [ "$after" = "$H" ] && ok "다시 확인(머지됨): 로컬의 origin 기본 브랜치 ref 가 머지된 끝으로 왔다(fetch)" || nob "다시 확인(머지됨): origin 을 받지 않았다" "$before → $after"
  o="$(FAKE_SSH_FAIL=1 run "$n" "$rf" "$URL")"
  assert_eq "$(last "$o")" "interview-merge: MERGED" "다시 확인(fetch 실패): 판결은 MERGED 그대로"
  assert_contains "$o" "머지 뒤 origin 을 받지 못했다(위 사유) — 지휘자를 부르기 전에 git fetch origin 을 돌린다." "다시 확인(fetch 실패): 알린다"

  # 13b. 요청 직후에는 아직 열림 → 뒤 읽기에서 머지됨. 한 번 읽고 끝내지 않는다
  n="${P}late"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"; H="$(head_of "$o")"
  before="$(omain "$n")"; remote_merge "$n" nostate
  for at in 2 4; do
    git -C "$c" update-ref refs/remotes/origin/main "$before"
    o="$(FAKE_VIEW_MERGED_AT=$at run "$n" "$rf" "$URL")"
    assert_eq "$(last "$o")" "interview-merge: MERGED" "다시 확인(${at}번째 읽기에 머지됨): 판결 MERGED"
    assert_eq "$(ghlog "$n" | grep -c "^pr view 7 ")" "$at" "다시 확인(${at}번째 읽기에 머지됨): PR 을 ${at}번 읽는다"
    assert_eq "$(omain "$n")" "$H" "다시 확인(${at}번째 읽기에 머지됨): origin 을 받았다"
  done
  assert_eq "$(sleeps "$n")" "5 5 5 " "다시 확인(4번째 읽기에 머지됨): 읽기 사이를 5초씩 세 번 쉰다"
  # 양의 대조 — 다섯째 읽기에야 머지됨이면 네 번에서 멈춰 NONE 이다(정해진 횟수만 읽는다)
  git -C "$c" update-ref refs/remotes/origin/main "$before"
  o="$(FAKE_VIEW_MERGED_AT=5 run "$n" "$rf" "$URL")"
  assert_eq "$(last "$o")" "interview-merge: NONE" "다시 확인(다섯째 읽기에야 머지됨): 네 번에서 멈춰 NONE"
  assert_eq "$(ghlog "$n" | grep -c "^pr view 7 ")" "4" "다시 확인(다섯째 읽기에야 머지됨): PR 을 네 번 읽는다"
  assert_eq "$(omain "$n")" "$before" "다시 확인(다섯째 읽기에야 머지됨): origin 을 받지 않는다"

  # 13c. 끝까지 열림 — NONE. 요청이 나갔다는 사실과 PR 주소를 함께 알린다
  n="${P}stillopen"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"; H="$(head_of "$o")"
  before="$(omain "$n")"
  o="$(run "$n" "$rf" "$URL")"
  assert_eq "$(last "$o")" "interview-merge: NONE" "다시 확인(끝까지 열림): 마지막 줄이 판결(NONE)"
  assert_contains "$o" "[spec-distill] 머지 요청은 나갔지만 PR 이 아직 머지되지 않았다(읽은 상태: OPEN) — 머지 대기열이나 자동 머지를 쓰는 레포면 조건이 채워진 뒤 머지된다. 머지된 것을 확인한 뒤 지휘자를 부른다: $URL" "다시 확인(끝까지 열림): 요청이 나간 사실 · 읽은 상태 · PR 주소가 한 줄에"
  assert_not_contains "$o" "머지돼 있다" "다시 확인(끝까지 열림): 머지돼 있다고 말하지 않는다"
  L="$(ghlog "$n")"
  assert_eq "$(printf '%s\n' "$L" | grep -c "^pr view 7 ")" "4" "다시 확인(끝까지 열림): PR 을 네 번 읽는다"
  assert_eq "$(printf '%s\n' "$L" | grep -vc "^pr view 7 ")" "0" "다시 확인(끝까지 열림): PR 읽기 말고는 gh 를 부르지 않는다"
  assert_eq "$(sleeps "$n")" "$Q_SLEEPS" "다시 확인(끝까지 열림): 머지 펜스의 머지 뒤 상태 읽기와 같은 간격 · 횟수로 쉰다(${Q_SLEEPS})"
  assert_eq "$(omain "$n")" "$before" "다시 확인(끝까지 열림): origin 을 받지 않는다"
  # 13d. 자리표 그대로 · 다른 레포 주소 — gh 를 부르지 않고 NONE
  o="$(run "$n" "$rf")"
  assert_eq "$(last "$o")" "interview-merge: NONE" "다시 확인(주소 자리표 그대로): 판결 NONE"
  assert_contains "$o" "머지됐는지 다시 확인하지 못했다 — PR 주소가 비었거나 자리표 그대로다. 머지 요청은 나갔을 수 있다" "다시 확인(주소 자리표 그대로): 사람 줄"
  assert_eq "$(ghlog "$n")" "" "다시 확인(주소 자리표 그대로): gh 를 부르지 않는다"
  : > "$T/gh-$n/log"
  o="$( cd "$c" && CLAUDE_PLUGIN_ROOT="$SD" PATH="$T/bin:$PATH" FAKE_GH_LOG="$T/gh-$n/log" "${SHELL_ARGV[@]}" "$rf" 2>&1 )"
  assert_eq "$(last "$o")" "interview-merge: NONE" "다시 확인(BRIEF 자리표 그대로): 판결 NONE"
  assert_contains "$o" "머지됐는지 다시 확인하지 못했다 — BRIEF 가 비었거나 자리표 그대로다" "다시 확인(BRIEF 자리표 그대로): 사람 줄"
  assert_eq "$(ghlog "$n")" "" "다시 확인(BRIEF 자리표 그대로): gh 를 부르지 않는다"
  o="$(run "$n" "$rf" "https://github.com/someone-else/r/pull/7")"
  assert_eq "$(last "$o")" "interview-merge: NONE" "다시 확인(다른 레포 주소): 판결 NONE"
  assert_contains "$o" "PR 주소의 레포(github.com/someone-else/r)가 origin(github.com/$n/r)이 아니다" "다시 확인(다른 레포 주소): gh_repo.py 의 사유"
  assert_contains "$o" "머지됐는지 다시 확인하지 못했다 — PR 주소가 이 레포(origin)의 PR 이 아니다(위 사유). 머지 요청은 나갔을 수 있다 — PR 에서 머지된 것을 확인한 뒤 지휘자를 부른다: https://github.com/someone-else/r/pull/7" "다시 확인(다른 레포 주소): 사람 줄에 그 주소"
  assert_eq "$(ghlog "$n")" "" "다시 확인(다른 레포 주소): gh 를 한 번도 부르지 않는다"
  # 13e. PR 을 읽지 못함(gh 인증 실패) — 원격이 머지돼 있어도 머지됨으로 읽지 않는다. 「끝까지 열림」 과 다른 줄로 알린다
  remote_merge "$n"
  o="$(FAKE_VIEW_AUTH=1 run "$n" "$rf" "$URL")"
  assert_eq "$(last "$o")" "interview-merge: NONE" "다시 확인(읽지 못함): 마지막 줄이 판결(NONE)"
  assert_contains "$o" "[spec-distill] 머지 요청은 나갔지만 PR 상태를 읽지 못했다(위 사유) — 머지됐는지 확인한 뒤 지휘자를 부른다: $URL" "다시 확인(읽지 못함): 요청이 나간 사실 · 읽지 못한 사실 · PR 주소가 한 줄에"
  assert_contains "$o" "gh 인증이 안 됐다 — gh auth login --hostname github.com 를 돈다" "다시 확인(읽지 못함): gh_repo.py 의 사유가 위에 보인다"
  assert_not_contains "$o" "아직 머지되지 않았다" "다시 확인(읽지 못함): 「끝까지 열림」 의 줄을 내지 않는다(열림으로 읽은 것이 아니다)"
  assert_not_contains "$o" "머지돼 있다" "다시 확인(읽지 못함): 머지돼 있다고 말하지 않는다"
  L="$(ghlog "$n")"
  assert_eq "$(printf '%s\n' "$L" | grep -c "^pr view 7 ")" "4" "다시 확인(읽지 못함): 정해진 횟수(네 번)만큼 읽는다"
  assert_not_contains "$L" "pr merge" "다시 확인(읽지 못함): 머지를 요청하지 않는다"
  assert_eq "$(omain "$n")" "$before" "다시 확인(읽지 못함): origin 을 받지 않는다"
  o="$(run "$n" "$rf" "$URL")"   # 양의 짝 — 같은 픽스처에서 읽을 수 있으면 MERGED 다(위의 NONE 은 읽지 못해서다)
  assert_eq "$(last "$o")" "interview-merge: MERGED" "다시 확인(읽지 못함의 짝): 읽을 수 있으면 MERGED"
  git -C "$c" update-ref refs/remotes/origin/main "$before"
  # 13f. 머지됨인데 브랜치 · 바탕 · 레포가 다르면 머지됨으로 읽지 않는다
  for kv in "FAKE_HEAD=other-branch" "FAKE_BASE=develop" "FAKE_CROSS=true"; do
    o="$(export "$kv"; run "$n" "$rf" "$URL")"
    assert_eq "$(last "$o")" "interview-merge: NONE" "다시 확인(대조 ${kv}): 판결 NONE"
    assert_contains "$o" "[spec-distill] 머지 요청은 나갔지만 읽은 PR 이 이 레포의 feature/x → main PR 이 아니다(읽은 것: MERGED " "다시 확인(대조 ${kv}): 읽은 것을 보인다"
    assert_contains "$o" "PR 에서 직접 확인한 뒤 지휘자를 부른다: $URL" "다시 확인(대조 ${kv}): PR 주소를 싣는다"
    assert_eq "$(omain "$n")" "$before" "다시 확인(대조 ${kv}): origin 을 받지 않는다"
  done
  o="$(run "$n" "$rf" "$URL")"
  assert_eq "$(last "$o")" "interview-merge: MERGED" "다시 확인(대조의 짝): 같은 픽스처에서 브랜치 · 바탕 · 레포가 같으면 MERGED"

  note "=== ${sh_name}: 「값의 출처」 줄 ==="
  # 14b. 끝내기 커밋 펜스는 두 키의 「값의 출처」 줄을 보이고, 이어 도는 PR 펜스는 그 줄을 다시 보이지 않는다
  n="${P}src"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  printf 'y\n' >> "$c/$STEM.state.md"
  o="$(run "$n" "$cf")"
  assert_contains "$o" "brief · audit · 상태 파일 · 로드맵 폴더를 커밋했다" "값의 출처: 끝내기 커밋 펜스가 커밋했다(PR 단계가 도는 조건)"
  assert_eq "$(printf '%s\n' "$o" | grep -c "^\[spec-distill\] ${SRC}: .*(interview_dir)\$")" "1" "값의 출처: 끝내기 커밋 펜스는 interview_dir 의 줄을 보인다"
  assert_eq "$(printf '%s\n' "$o" | grep -c "^\[spec-distill\] ${SRC}: .*(roadmaps_dir)\$")" "1" "값의 출처: 끝내기 커밋 펜스는 roadmaps_dir 의 줄을 보인다"
  o="$(run "$n" "$pf")"
  made=0; left=""
  while IFS= read -r f; do made=$((made + 1)); [ ! -e "$f" ] || left="${left} ${f}"; done < "$T/gh-$n/mktemps"
  assert_eq "$made" "3" "값의 출처(전제): PR 펜스가 임시 파일을 셋 만들었다(PR 본문 · 판정 둘)"
  assert_eq "$left" "" "값의 출처: PR 펜스가 임시 파일을 남기지 않는다"
  assert_eq "$(last "$o")" "interview-pr: OPEN https://github.com/$n/r/pull/7" "값의 출처: 이어 돈 PR 펜스의 판결은 OPEN"
  assert_contains "$o" "interview-pr-files: ONLY" "값의 출처: 걸러도 두 판정은 통과로 읽힌다(ONLY)"
  assert_not_contains "$o" "$SRC" "값의 출처: 이어 돈 PR 펜스 출력에는 그 줄이 없다"
  # 14c. 알림 줄은 남는다 — 작업 트리에만 있는 레포 설정 파일의 알림(판정마다 한 번, 두 번)
  printf -- '---\n---\n' > "$c/.devbrew.md"
  o="$(run "$n" "$pf")"
  assert_eq "$(printf '%s\n' "$o" | grep -c "^\[spec-distill\] 레포 설정 파일(.devbrew.md)이 아직 기본 브랜치에 없다 — 기본값을 쓴다\$")" "2" "값의 출처: 해결자의 알림 줄은 그대로 보인다(판정 둘)"
  assert_not_contains "$o" "$SRC" "값의 출처: 알림이 있어도 그 줄은 없다"
  assert_contains "$o" "interview-pr-files: ONLY" "값의 출처: 알림이 있어도 판정은 통과로 읽힌다"
  rm -f "$c/.devbrew.md"
  # 임시 파일을 못 만들면 거르지 않고 그대로 돈다 — 통과하는 판정은 통과로 읽힌다
  o="$(FAKE_MKTEMP_FAIL=1 FAKE_PR_LIST='[{"url":"https://github.com/'"$n"'/r/pull/5","isCrossRepository":false}]' run "$n" "$pf")"
  assert_contains "$o" "mktemp: mkstemp failed" "임시 파일 실패(통과하는 판정): 전제 — mktemp 가 실패했다"
  assert_contains "$o" "interview-pr-files: ONLY" "임시 파일 실패(통과하는 판정): 판정의 통과가 그대로 읽힌다(ONLY)"
  assert_eq "$(printf '%s\n' "$o" | grep -c "^\[spec-distill\] ${SRC}: ")" "2" "임시 파일 실패(통과하는 판정): 거르지 않아 「값의 출처」 줄이 판정마다 보인다"
  # 14d. 경고 줄은 남는다 — 기본 브랜치의 레포 설정이 깨진 값을 가질 때
  n="${P}srcwarn"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  git -C "$c" switch -q main; printf -- '---\nparallel_default: x\n---\n' > "$c/.devbrew.md"
  git -C "$c" add -- .devbrew.md; git -C "$c" commit -q -m "chore: settings"; git -C "$c" push -q origin main 2>/dev/null; git -C "$c" switch -q feature/x
  o="$(run "$n" "$pf")"
  assert_eq "$(printf '%s\n' "$o" | grep -c "동시 작업 권장 수는 1 이상의 정수다(parallel_default: 'x')")" "2" "값의 출처: 해결자의 경고 줄은 그대로 보인다(판정 둘)"
  assert_not_contains "$o" "$SRC" "값의 출처: 경고가 있어도 그 줄은 없다"
  assert_contains "$o" "interview-pr-files: ONLY" "값의 출처: 경고가 있어도 판정은 통과로 읽힌다"
done
finish
