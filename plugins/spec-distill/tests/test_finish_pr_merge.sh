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
pf="$(fence "$FIN" interview-pr)"
mf="$(fence "$FIN" interview-merge)"
case "$pf" in *"BRIEF=\"$PH\""*'gh_repo.py" pr-open '*'gh_repo.py" pr-create '*) ok "전제: PR 펜스에 BRIEF 자리표와 gh_repo.py 호출 둘" ;; *) no "전제: PR 펜스를 못 뽑았다 — 아래 칸이 공허하다" ;; esac
case "$mf" in *"URL=\"$UPH\""*'gh_repo.py" pr-number '*'gh_repo.py" pr-merge '*) ok "전제: 머지 펜스에 URL 자리표와 gh_repo.py 호출" ;; *) no "전제: 머지 펜스를 못 뽑았다 — 아래 칸이 공허하다" ;; esac

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
    printf '{"number":%s,"state":"%s","headRefName":"%s","headRefOid":"abc","isCrossRepository":false,"baseRefName":"main","mergeCommit":null}\n' \
      "$3" "$(cat "$st")" "${FAKE_HEAD:-feature/x}" ;;
  "pr checks")
    case "${FAKE_CHECKS:-none}" in
      none) echo "no checks reported on the 'feature/x' branch" >&2; exit 1 ;;
      pass) printf 'build\tpass\t1s\thttps://ci.example/1\n' ;;
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
run() {   # run <owner> <펜스 본문> [<PR 주소>] → 자리표를 바꿔 지금 셸(SHELL_ARGV)로 돈 출력. gh 호출은 $T/gh-<owner>/log 에 쌓인다
  local c="$T/$1" body="${2//"$PH"/$T/$1/$STEM.md}"
  body="${body//"$UPH"/${3:-$UPH}}"
  : > "$T/gh-$1/log"
  ( cd "$c" && CLAUDE_PLUGIN_ROOT="$SD" PATH="$T/bin:$PATH" FAKE_GH_LOG="$T/gh-$1/log" FAKE_GH_DIR="$T/gh-$1" \
      FAKE_OWNER="$1" FAKE_REMOTE="$T/remotes/$1/r.git" "${SHELL_ARGV[@]}" "$body" 2>&1 )
}
ghlog() { cat "$T/gh-$1/log"; }
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
  mkdir -p "$c/src" "$c/$IDIR/sub"; printf 'x\n' > "$c/src/app.py"; printf 'x\n' > "$c/$IDIR/sub/deep.md"
  git -C "$c" add -- src "$IDIR/sub"; git -C "$c" commit -q -m "feat: code"
  o="$(run "$n" "$pf")"
  assert_eq "$(last "$o")" "interview-pr: OPEN https://github.com/$n/r/pull/7" "섞인 PR: 판결은 그대로 OPEN"
  assert_contains "$o" "interview-pr-files: MIXED" "섞인 PR: MIXED"
  assert_contains "$o" "밖의 파일 2개도 담는다" "섞인 PR: 개수를 보인다"
  assert_contains "$o" "  - src/app.py" "섞인 PR: 코드 파일을 목록에 보인다"
  assert_contains "$o" "  - $IDIR/sub/deep.md" "섞인 PR: 인터뷰 폴더의 하위 폴더는 「바로 아래」 가 아니다"
  assert_not_contains "$o" "  - $STEM.md" "섞인 PR: brief 는 목록에 없다"
  assert_not_contains "$o" "  - $RREL/" "섞인 PR: 로드맵 폴더의 파일은 목록에 없다"
  assert_not_contains "$o" "interview-pr-files: ONLY" "섞인 PR: ONLY 를 내지 않는다"

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
  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"
  before="$(git -C "$c" rev-parse refs/remotes/origin/main)"
  o="$(run "$n" "$mf" "$URL")"
  assert_eq "$(last "$o")" "interview-merge: MERGED" "머지: 마지막 줄이 판결(MERGED)"
  assert_contains "$o" "[spec-distill] PR 을 머지했다(merge) — $URL" "머지: 방식과 주소를 보인다"
  L="$(ghlog "$n")"
  assert_eq "$(printf '%s\n' "$L" | grep -c "^pr checks 7 -R github.com/$n/r\$")" "6" "머지: 「검사 없음」을 여섯 번 본다"
  assert_not_contains "$L" "--watch" "머지: 검사가 없으면 기다리지 않는다"
  assert_contains "$L" "repo view --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed github.com/$n/r" "머지: 허용 방식을 origin 레포에 묻는다"
  assert_contains "$L" "pr merge 7 --merge -R github.com/$n/r" "머지: 번호와 -R origin 으로 머지한다"
  assert_eq "$(printf '%s\n' "$L" | grep -c "^pr view 7 ")" "2" "머지: 신원 확인 한 번 · 머지 뒤 상태 확인 한 번"
  assert_not_contains "$L" "$URL" "머지: gh 에 주소를 넘기지 않는다(번호와 -R 만)"
  after="$(git -C "$c" rev-parse refs/remotes/origin/main)"
  [ "$before" != "$after" ] && [ "$after" = "$(git -C "$c" rev-parse HEAD)" ] && ok "머지: 로컬의 origin 기본 브랜치 ref 가 머지된 끝으로 왔다(fetch)" || nob "머지: origin 을 받지 않았다" "$before → $after"

  # 6. 다른 레포의 PR 주소 — gh 를 부르기 전에 거절
  n="${P}other"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(run "$n" "$mf" "https://github.com/someone-else/r/pull/7")"
  assert_eq "$(last "$o")" "interview-merge: NONE" "다른 레포 주소: 판결 NONE"
  assert_contains "$o" "PR 주소의 레포(github.com/someone-else/r)가 origin(github.com/$n/r)이 아니다" "다른 레포 주소: gh_repo.py 의 사유"
  assert_contains "$o" "머지하지 않았다 — PR 주소가 이 레포(origin)의 PR 이 아니다(위 사유)" "다른 레포 주소: 사람 줄"
  assert_eq "$(ghlog "$n")" "" "다른 레포 주소: gh 를 한 번도 부르지 않는다"
  o="$(run "$n" "$mf" "https://GitHub.com/${n}/R/pull/7")"
  assert_not_contains "$o" "이 레포(origin)의 PR 이 아니다" "양성 짝: 대소문자만 다른 같은 레포 주소는 거절하지 않는다"
  assert_contains "$(ghlog "$n")" "pr view 7 " "양성 짝: 같은 레포 주소면 PR 을 읽는다"

  # 7. 머지 대기열 — gh 는 rc 0 인데 PR 은 OPEN 그대로
  n="${P}queue"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"
  before="$(git -C "$c" rev-parse refs/remotes/origin/main)"
  o="$(FAKE_MERGE=queue run "$n" "$mf" "$URL")"
  assert_eq "$(last "$o")" "interview-merge: NONE" "대기열: gh 가 rc 0 이어도 MERGED 가 아니면 NONE"
  assert_contains "$o" "PR 이 아직 머지되지 않았다(읽은 상태: OPEN)" "대기열: 읽은 상태를 보인다"
  assert_not_contains "$o" "PR 을 머지했다" "대기열: 머지했다고 말하지 않는다"
  assert_eq "$(ghlog "$n" | grep -c "^pr merge ")" "1" "대기열: 다음 머지 방식을 시도하지 않는다"
  assert_eq "$(ghlog "$n" | grep -c "^pr view 7 ")" "5" "대기열: 상태를 네 번까지 다시 읽는다(신원 확인 한 번 더)"
  assert_eq "$(git -C "$c" rev-parse refs/remotes/origin/main)" "$before" "대기열: 머지 전이라 origin 을 받지 않는다"

  # 8. 머지 뒤 origin 을 받지 못함 — 알리고 판결은 MERGED
  n="${P}nofetch"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"
  o="$(FAKE_SSH_FAIL=1 run "$n" "$mf" "$URL")"
  assert_eq "$(last "$o")" "interview-merge: MERGED" "fetch 실패: 판결은 MERGED 그대로"
  assert_contains "$o" "머지 뒤 origin 을 받지 못했다(위 사유) — 지휘자를 부르기 전에 git fetch origin 을 돌린다." "fetch 실패: 알린다"
  assert_contains "$o" "PR 을 머지했다(merge)" "fetch 실패: 머지한 사실은 보인다"

  # 9. 신원 불일치 · 검사 실패 · 검사 통과 · 방식 거절
  n="${P}misc"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"
  o="$(FAKE_HEAD=other-branch run "$n" "$mf" "$URL")"
  assert_contains "$o" "이 PR 은 열린, 이 레포의 feature/x → main PR 이 아니다(읽은 것: OPEN main other-branch false)" "신원 불일치: 읽은 것을 보이고 멈춘다"
  assert_not_contains "$(ghlog "$n")" "pr merge" "신원 불일치: 머지하지 않는다"
  o="$(FAKE_CHECKS=fail run "$n" "$mf" "$URL")"
  assert_eq "$(last "$o")" "interview-merge: NONE" "검사 실패: 판결 NONE"
  assert_contains "$o" "CI 검사가 통과하지 않았다(rc 1, 위 목록)" "검사 실패: 사유"
  assert_not_contains "$(ghlog "$n")" "pr merge" "검사 실패: 머지하지 않는다"
  o="$(FAKE_CHECKS=hang FAKE_SLEEP=0.01 run "$n" "$mf" "$URL")"
  assert_contains "$o" "CI 검사를 30분 기다려도 끝나지 않았다" "검사가 끝나지 않음: 기다림 상한에서 멈춘다"
  wp="$(cat "$T/gh-$n/watch.pid" 2>/dev/null)" || wp=""
  [ -n "$wp" ] && ! kill -0 "$wp" 2>/dev/null && ok "검사가 끝나지 않음: 기다리던 gh 를 끝냈다" || nob "검사가 끝나지 않음: 기다리던 gh 가 남았다" "pid ${wp:-없음}"
  o="$(FAKE_WAYS='{"mergeCommitAllowed":false,"squashMergeAllowed":true,"rebaseMergeAllowed":true}' FAKE_CHECKS=pass run "$n" "$mf" "$URL")"
  L="$(ghlog "$n")"
  assert_contains "$L" "pr checks 7 --watch --interval 15 -R github.com/$n/r" "검사 통과: 끝나길 기다린다(-R origin)"
  assert_not_contains "$L" "pr merge 7 --merge" "허용 방식: 허용하지 않는 방식은 시도하지 않는다"
  assert_contains "$o" "PR 을 머지했다(squash)" "허용 방식: 허용된 첫 방식으로 머지한다"
  assert_eq "$(last "$o")" "interview-merge: MERGED" "검사 통과: 판결 MERGED"
  n="${P}second"; c="$(mk "$n")" || { no "픽스처 $n"; continue; }
  o="$(run "$n" "$pf")"; URL="https://github.com/$n/r/pull/7"
  o="$(FAKE_MERGE=second run "$n" "$mf" "$URL")"
  assert_contains "$o" "merge 머지가 거절됐다(위 사유) — 다음 방식을 시도한다." "방식 거절: 알리고 다음 방식으로"
  assert_contains "$o" "PR 을 머지했다(squash)" "방식 거절: 다음 방식으로 머지한다"
  o="$(run "$n" "$mf")"
  assert_contains "$o" "머지하지 않았다 — PR 주소가 비었거나 자리표 그대로다" "자리표 그대로: 머지하지 않는다"
done
finish
