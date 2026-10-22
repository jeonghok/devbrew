#!/usr/bin/env bash
# publish-comment.sh — qg 게시의 유일한 sink. gh 쓰기는 이 파일에만 있다(AC15).
#
# 순서(spec §5): kill switch → gh 존재 · origin(gh-repo.sh) → 인증 → 열린 PR → corpus + secret-scan → 이미지·HTML 태그
# → 길이 → 코멘트. gh 호출은 전부 `-R <origin>` 을 밝힌다.
# 마지막 stdout 줄은 `posted: <url>` · `skipped: <사유>` · `failed: <사유>` 리터럴 하나다(P6). 진단은 전부 stderr.
# 사유 리터럴: no-pr · pr-closed · pr-mismatch · kill-switch · scan-failed · gh-unavailable · too-long.
# pr-mismatch — 브랜치 이름으로 찾은 PR 이 fork PR 이거나 그 head 가 지금 HEAD 가 아니다.
# `failed:` 는 둘이다 — gh 가 없다(`failed: gh-unavailable`) · origin 이 없거나 URL 을 못 읽거나 gh 가 그 레포를
# 다루지 못한다(`failed: no-origin`).
# 사유는 stderr 에 있다(gh-repo.sh 가 낸 설치 · 확인 안내).
# exit: posted·skipped 는 0, failed 는 1, 잘못된 호출은 2.
#
# Usage: publish-comment.sh --body-file <file> [--base <merge-base sha>]
set -uo pipefail

MAX_CHARS=65536
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

body=""; base=""
while [ $# -gt 0 ]; do
  case "$1" in
    --body-file) [ $# -ge 2 ] || { echo "publish-comment: --body-file 에 값이 없다" >&2; exit 2; }; body="$2"; shift 2 ;;
    --base) [ $# -ge 2 ] || { echo "publish-comment: --base 에 값이 없다" >&2; exit 2; }; base="$2"; shift 2 ;;
    *) echo "publish-comment: 알 수 없는 인자: $1" >&2; exit 2 ;;
  esac
done
[ -n "$body" ] || { echo "publish-comment: --body-file 이 필요하다" >&2; exit 2; }

skip() { echo "skipped: $1"; exit 0; }
fail() { echo "failed: $1"; exit 1; }

# 1. kill switch — 어떤 gh 호출보다 먼저(P3 · AC14). 전체 토큰 일치(E5).
if [ "${DEVBREW_QUALITY_GATES_DISABLE_PUBLISH:-}" = "1" ] || [ "${DEVBREW_QUALITY_GATES_DISABLE:-}" = "1" ]; then
  skip kill-switch
fi

if [ ! -f "$body" ] || [ ! -r "$body" ] || [ ! -s "$body" ]; then
  echo "publish-comment: 본문 파일을 읽을 수 없거나 비었다: $body" >&2
  exit 2
fi

# 리포 루트에서 돈다 — 하위 디렉토리에서 불려도 untracked 목록과 파일 경로가 루트 기준이다.
case "$body" in /*) ;; *) body="$PWD/$body" ;; esac
top="$(git rev-parse --show-toplevel 2>/dev/null)" && cd "$top" \
  || { echo "publish-comment: git 리포 루트를 찾지 못했다" >&2; skip scan-failed; }

# 2. gh 존재 · origin — gh-repo.sh 가 정한다. gh 가 없거나(rc 4) origin 을 못 읽으면(rc 3) 실패다.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/qg-sink.XXXXXX")" || { echo "publish-comment: 임시 디렉토리를 만들 수 없다" >&2; skip scan-failed; }
trap 'rm -rf "$WORK"' EXIT
slug_rc=0
slug="$(bash "$SCRIPT_DIR/gh-repo.sh" 2>"$WORK/gh-repo.err")" || slug_rc=$?
cat "$WORK/gh-repo.err" >&2
if [ "$slug_rc" -eq 4 ]; then
  echo "publish-comment: gh 가 없어 PR 코멘트를 달지 못했다" >&2
  fail gh-unavailable
fi
[ "$slug_rc" -eq 0 ] && [ -n "$slug" ] \
  || { echo "publish-comment: origin 의 레포를 정하지 못해 PR 코멘트를 달지 못했다(gh-repo.sh rc ${slug_rc})" >&2; fail no-origin; }
host="${slug%%/*}"
# 인증 — 부작용 전(P5). 활성 계정만 본다 — 다른 호스트·두 번째 계정이 깨졌다고 게시를 잃지 않는다.
auth_err="$(gh auth status --active 2>&1 >/dev/null)" \
  || { echo "publish-comment: gh 미인증 — gh auth login --hostname ${host} 를 돈다" >&2
       printf '%s\n' "$auth_err" | tail -n 3 >&2; skip gh-unavailable; }

# 3. 현재 브랜치의 PR — 브랜치 이름과 origin 을 밝혀 묻는다. 이름 붙은 브랜치가 없으면(detached HEAD) PR 이 없다.
branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)" \
  || { echo "publish-comment: 지금 브랜치가 없다(detached HEAD) — 그 PR 을 찾지 않는다" >&2; skip no-pr; }
pr_rc=0
gh pr view "$branch" -R "$slug" --json number,state,url,baseRefName,headRefOid,isCrossRepository \
  --jq '[.number,.state,.url,.baseRefName,.headRefOid,.isCrossRepository]|@tsv' \
  >"$WORK/pr.tsv" 2>"$WORK/pr.err" || pr_rc=$?
if [ "$pr_rc" -ne 0 ]; then
  tail -n 3 "$WORK/pr.err" >&2
  if grep -qi 'no pull requests found' "$WORK/pr.err"; then skip no-pr; fi
  if grep -qiE 'could not resolve to a repository|no such type pullrequest' "$WORK/pr.err"; then
    echo "publish-comment: gh 가 origin(${slug})을 다루지 못한다 — devbrew 는 origin 이 GitHub 인 레포만 지원한다(비공개 레포면 접근 권한도 확인한다)" >&2
    fail no-origin
  fi
  skip gh-unavailable
fi
IFS="$(printf '\t')" read -r pr_num pr_state pr_url pr_base pr_head pr_cross <"$WORK/pr.tsv" || true
# 비신뢰 값은 전체 일치로 검사한다(V11).
[[ "${pr_num:-}" =~ ^[0-9]+$ ]] || { echo "publish-comment: PR 번호를 읽지 못했다" >&2; skip gh-unavailable; }
[ "${pr_state:-}" = "OPEN" ] || { echo "publish-comment: PR #${pr_num} 상태 ${pr_state:-?}" >&2; skip pr-closed; }
# 브랜치 이름만으로 고른 PR 이 이 checkout 의 PR 인지 확인한다 — 같은 이름의 fork PR · 옛 PR 에 달지 않는다.
# origin 안의 PR 이고(isCrossRepository false) 그 head 가 지금 HEAD 와 같을 때만 단다. 아니면 달지 않는다.
[ "${pr_cross:-}" = "false" ] \
  || { echo "publish-comment: PR #${pr_num} 은 다른 레포(fork)에서 온 PR 이다(isCrossRepository ${pr_cross:-?}) — 달지 않는다" >&2; skip pr-mismatch; }
head_sha="$(git rev-parse --verify -q HEAD 2>/dev/null || true)"
if [ -z "$head_sha" ] || [ "${pr_head:-}" != "$head_sha" ]; then
  echo "publish-comment: PR #${pr_num} 의 head(${pr_head:0:12}) 가 지금 HEAD(${head_sha:0:12}) 와 다르다 — 푸시한 뒤 다시 /quality-gates:quality-pipeline" >&2
  skip pr-mismatch
fi

# 4. corpus — 이 변경 자신의 글: 커밋 메시지·패치, 작업트리 diff, 변경 파일 내용. merge-base 가 없거나 생산자
#    하나라도 실패하면 degraded 헤더 한 줄만 둔다(secret-scan 이 fail-closed) — 부분 corpus 로 통과시키지 않는다.
mb=""
if [ -n "$base" ]; then
  mb="$(git rev-parse --verify -q "${base}^{commit}" 2>/dev/null || true)"
elif [[ "${pr_base:-}" =~ ^[A-Za-z0-9._/][A-Za-z0-9._/-]*$ ]]; then
  # 전체 참조 이름만 쓴다 — 짧은 이름 origin/<base> 는 같은 이름의 태그 · 로컬 브랜치가 가로챈다.
  mb="$(git merge-base "refs/remotes/origin/${pr_base}" HEAD 2>/dev/null || git merge-base "refs/heads/${pr_base}" HEAD 2>/dev/null || true)"
fi
CORPUS="$WORK/corpus"
diff_vs_base() { git diff "$@" "$mb" --; }
# corpus 계약: mb..HEAD 의 git 기본 텍스트 뷰(`log -p --text`, 커밋 메시지 포함) + mb 대비 작업트리 diff
# + 변경된 추적 파일과 무시되지 않는 untracked 텍스트 파일의 현재 평문.
# 범위 밖(설계상): 무시된 파일 · 바이너리/NUL 바이트 파일의 현재 내용 · LFS 객체의 지난 내용 · 병합 해소에만
# 있는 줄 · 변경 밖에서 오케스트레이터가 읽은 것 · qg 세션 폴더 `.claude/quality-gates/`(게시 본문 자신이 거기 산다).
build_corpus() {
  local f gr
  echo "=== QG CORPUS (deterministic) ===" || return 1
  echo "base: $mb"
  echo "=== COMMITS ==="
  git log -p --text --no-ext-diff --no-color --format='%B' "$mb..HEAD" -- || return 1
  echo "=== WORKTREE DIFF ==="
  diff_vs_base --text --no-ext-diff --no-color || return 1
  echo "=== CHANGED FILE CONTENTS ==="
  diff_vs_base -z --name-only --diff-filter=ACMR >"$WORK/names" || return 1
  git ls-files -z --others --exclude-standard -- . ':!.claude/quality-gates' >>"$WORK/names" || return 1
  sort -z -u "$WORK/names" >"$WORK/names.sorted" || return 1
  while IFS= read -r -d '' f; do
    [ -f "$f" ] || continue
    echo "--- FILE: $f ---"
    # grep rc: 0 = 텍스트, 1 = 바이너리(건너뜀), 그 밖 = 읽기 실패(fail-closed)
    LC_ALL=C grep -Iq -e . -- "./$f"; gr=$?
    if [ "$gr" -eq 0 ]; then cat -- "./$f" || return 1
    elif [ "$gr" -ne 1 ]; then return 1; fi
    echo
  done <"$WORK/names.sorted"
  return 0
}
if [ -z "$mb" ]; then
  echo "=== QG CORPUS (degraded: no merge-base) ===" >"$CORPUS"
elif ! build_corpus >"$CORPUS" 2>"$WORK/corpus.err"; then
  tail -n 5 "$WORK/corpus.err" >&2
  echo "=== QG CORPUS (degraded: corpus build failed) ===" >"$CORPUS"
fi
python3 "$SCRIPT_DIR/secret-scan.py" --payload "$body" --corpus "$CORPUS" >"$WORK/scan.out" 2>"$WORK/scan.err" || true
# 통과는 첫 줄 리터럴 하나로만 본다 — exit code 는 보지 않는다(P1).
first="$(head -n 1 "$WORK/scan.out")"
if [ "$first" != "scan_ok: yes" ]; then
  sed -n '2,20p' "$WORK/scan.out" >&2
  skip scan-failed
fi
# 이미지 · HTML 태그 — 렌더링이 본문 속 URL 을 클릭 없이 불러 값이 밖으로 샌다. 코멘트 형식에 없으니 막는다.
img_rc=0
LC_ALL=C grep -qiE '!\[|<(img|image|picture|source|svg|video|audio)' -- "$body" || img_rc=$?
if [ "$img_rc" -eq 0 ]; then
  echo "publish-comment: 본문에 이미지·HTML 태그가 있다 — 게시하지 않는다" >&2
  skip scan-failed
elif [ "$img_rc" -ne 1 ]; then
  echo "publish-comment: 본문의 이미지·HTML 검사를 하지 못했다(grep rc ${img_rc})" >&2
  skip scan-failed
fi

# 5. 길이 — 자르지 않고 건너뛴다.
chars="$(python3 -I -X utf8 -c 'import sys; print(len(open(sys.argv[1], encoding="utf-8", errors="replace").read()))' "$body" 2>/dev/null || echo x)"
[[ "$chars" =~ ^[0-9]+$ ]] || { echo "publish-comment: 본문 길이를 재지 못했다" >&2; skip scan-failed; }
[ "$chars" -le "$MAX_CHARS" ] || { echo "publish-comment: 본문 ${chars}자 > ${MAX_CHARS}" >&2; skip too-long; }

# 6. 새 코멘트 하나. 본문은 불투명 바이트로만 넘긴다(P4).
post_rc=0
gh pr comment "$pr_num" --body-file "$body" -R "$slug" >"$WORK/post.out" 2>"$WORK/post.err" || post_rc=$?
if [ "$post_rc" -ne 0 ]; then
  tail -n 3 "$WORK/post.err" >&2
  echo "publish-comment: gh pr comment 실패(rc ${post_rc})" >&2
  skip gh-unavailable
fi
url="$(grep -E '^https://' "$WORK/post.out" | tail -n 1)"
echo "posted: ${url:-unknown}"
exit 0
