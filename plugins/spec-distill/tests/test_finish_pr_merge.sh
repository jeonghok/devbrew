#!/usr/bin/env bash
# 분해된 인터뷰 끝맺음의 PR 펜스(interview-pr) · 머지 펜스(interview-merge) — finishing.md 에서 뽑아 그대로 돌린다.
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
FIN="$SD/skills/pm-interview/references/finishing.md"
PH='<Step A.5 의 PAYLOAD 절대경로>'
UPH='<interview-pr 이 낸 PR 주소>'
HPH='<interview-pr 이 낸 끝 커밋>'
pf="$(fence "$FIN" interview-pr)"
mf="$(fence "$FIN" interview-merge)"
case "$pf" in *"BRIEF=\"$PH\""*'gh_repo.py" pr-open '*'gh_repo.py" pr-create '*) ok "전제: PR 펜스에 BRIEF 자리표와 gh_repo.py 호출 둘" ;; *) no "전제: PR 펜스를 못 뽑았다 — 아래 칸이 공허하다" ;; esac
# 권장 꼬리의 조건은 본문이 정한다 — ONLY 일 때만 달고 MIXED · UNKNOWN 이면 뗀다
ASK="$(grep -F '2. **머지 묻기.**' "$FIN")"
assert_contains "$ASK" '「(권장)」 꼬리는 1 의 펜스가 `interview-pr-files: ONLY` 를 냈을 때만 단다' "본문: 권장 꼬리는 ONLY 일 때만"
assert_contains "$ASK" '`MIXED` 나 `UNKNOWN` 이면 꼬리를 떼어 「머지」 로 내고' "본문: MIXED · UNKNOWN 이면 꼬리를 뗀다"
case "$mf" in *"URL=\"$UPH\""*"HEAD_SHA=\"$HPH\""*'gh_repo.py" pr-number '*'gh_repo.py" pr-merge '*) ok "전제: 머지 펜스에 URL · 끝 커밋 자리표와 gh_repo.py 호출" ;; *) no "전제: 머지 펜스를 못 뽑았다 — 아래 칸이 공허하다" ;; esac

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
    [ "${FAKE_CREATE:-ok}" = ok ] || { echo 'pull request create failed: GraphQL: boom (createPullRequest)' >&2; exit 1; }
    echo "Creating pull request for feature/x into main in $FAKE_OWNER/r" >&2
    echo "https://github.com/$FAKE_OWNER/r/pull/7" ;;
  "pr view")
    printf '{"number":%s,"state":"%s","headRefName":"%s","headRefOid":"%s","isCrossRepository":false,"baseRefName":"main","mergeCommit":null}\n' \
      "$3" "$(cat "$st")" "${FAKE_HEAD:-feature/x}" "$(git --git-dir="$FAKE_REMOTE" rev-parse refs/heads/feature/x)" ;;
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
    printf 'MERGED\n' > "$st" ;;
esac
FAKE
cat > "$T/bin/sleep" <<'FAKE'
#!/bin/sh
exec /bin/sleep "${FAKE_SLEEP:-0.05}"
FAKE
cat > "$T/bin/fakessh" <<'FAKE'
#!/bin/sh
[ -z "${FAKE_SSH_FAIL:-}" ] || { echo 'ssh: connect to host github.com port 22: Operation timed out' >&2; exit 255; }
c=""
for a in "$@"; do c="$a"; done
cd "$FAKE_REMOTES" && eval "exec git ${c#git-}"
FAKE
chmod +x "$T/bin/gh" "$T/bin/sleep" "$T/bin/fakessh" || exit 1
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
  : > "$T/gh-$1/log"
  ( cd "$c" && CLAUDE_PLUGIN_ROOT="$SD" PATH="$T/bin:$PATH" FAKE_GH_LOG="$T/gh-$1/log" FAKE_GH_DIR="$T/gh-$1" \
      FAKE_OWNER="$1" FAKE_REMOTE="$T/remotes/$1/r.git" "${SHELL_ARGV[@]}" "$body" 2>&1 )
}
ghlog() { cat "$T/gh-$1/log"; }
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
  # 3c. brief 가 정해진 인터뷰 폴더 바로 아래가 아니면 그 폴더도 빼지 않는다
  n="${P}stray"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  mkdir -p "$c/notes"; cp "$c/$STEM.md" "$c/notes/b.md"; git -C "$c" add -- notes; git -C "$c" commit -q -m "docs: stray brief"
  o="$(BRIEF_REL=notes/b.md run "$n" "$pf")"
  assert_contains "$o" "interview-pr-files: MIXED" "인터뷰 폴더 밖의 brief: MIXED"
  assert_contains "$o" "  - notes/b.md" "인터뷰 폴더 밖의 brief: 그 폴더의 파일을 목록에 보인다"
  assert_contains "$o" "brief 가 정해진 인터뷰 폴더 바로 아래가 아니다(위 사유)" "인터뷰 폴더 밖의 brief: 빼지 않은 사실을 보인다"
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
  o="$(FAKE_CHECKS=hang FAKE_SLEEP=0.01 run "$n" "$mf" "$URL" "$H")"
  assert_contains "$o" "CI 검사를 30분 기다려도 끝나지 않았다" "검사가 끝나지 않음: 기다림 상한에서 멈춘다"
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
done
finish
