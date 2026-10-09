#!/usr/bin/env bash
# test_discover_spec.sh — AC9 · AC15 · K-5: 의도 출처는 D13 사슬로 정한다.
#
#   1. HEAD 쪽 커밋의 `Spec:` 트레일러가 가리키는 spec
#   2. 없으면 브랜치 커밋 메시지 + 열린 PR 본문(읽기 전용 `gh pr view`)
#
# 파일 mtime 은 읽지 않는다(옛 「최신 mtime spec」 규칙이 무관한 spec 을 의도로 골랐다).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
D="$SCRIPT_DIR/../scripts/discover-spec.sh"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
key() { python3 -c 'import json,sys; print(json.loads(sys.stdin.read())[sys.argv[1]])' "$1"; }

# 픽스처 리포 — base 커밋 하나, 그 위 브랜치 커밋 둘
R="$T/repo"; mkdir -p "$R/docs/superpowers/specs"
git -C "$R" init -q -b main
git -C "$R" -c user.email=t@t -c user.name=t commit -q --allow-empty -m base
BASE="$(git -C "$R" rev-parse HEAD)"
printf '# Old spec\n## Acceptance Criteria\n- old\n' > "$R/docs/superpowers/specs/old-design.md"
printf '# New spec\n## Acceptance Criteria\n- new\n' > "$R/docs/superpowers/specs/new-design.md"
git -C "$R" add -A
git -C "$R" -c user.email=t@t -c user.name=t commit -q -m "feat: first" -m "Spec: docs/superpowers/specs/old-design.md"
git -C "$R" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "feat: second" -m "Spec: docs/superpowers/specs/new-design.md"

# gh 스텁 — 환경 변수로 응답을 고른다
B="$T/bin"; mkdir -p "$B"
cat > "$B/gh" <<'SH'
#!/bin/sh
echo "$*" >> "$GH_LOG"
case "$1 $2" in
  "pr view")
    case "$*" in
      *"--json state"*) [ -n "${GH_PR_ERR:-}" ] && { echo "$GH_PR_ERR" >&2; exit 1; }; echo "${GH_PR_STATE:-OPEN}" ;;
      *"--json body"*) echo "${GH_PR_BODY:-}" ;;
    esac ;;
esac
SH
chmod +x "$B/gh"
NOGH="$T/nogh"; mkdir -p "$NOGH"
for c in git python3 sed grep cat mktemp rm dirname bash tail; do ln -s "$(command -v "$c")" "$NOGH/$c"; done
export GH_LOG="$T/gh.log"; : > "$GH_LOG"

run() { ( cd "$R" && PATH="$1" bash "$D" --intent-out "$T/intent.md" --base "$BASE" ); }

# 1 — 트레일러: HEAD 쪽(최신) 커밋의 Spec: 이 이긴다
out="$(run "$B:$PATH")"; rc=$?
assert_eq "$rc" "0" "트레일러 — exit 0"
assert_eq "$(printf '%s' "$out" | key intent_source)" "spec-trailer" "의도 출처는 spec-trailer"
assert_eq "$(printf '%s' "$out" | key spec_path)" "$(cd "$R" && pwd -P)/docs/superpowers/specs/new-design.md" \
  "spec_path 는 최신 커밋의 트레일러가 가리키는 파일"
assert_file_grep "$T/intent.md" '^- new$' "의도 본문은 그 spec 이다"
assert_eq "$(printf '%s' "$out" | key intent_file)" "$T/intent.md" "intent_file 은 --intent-out 경로"

# 2 — 트레일러 없음 · gh 없음 → 커밋 메시지만, 그 사실을 공시
git -C "$R" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "fix: third (no trailer)"
BASE2="$(git -C "$R" rev-parse HEAD~1)"
run2() { ( cd "$R" && PATH="$1" bash "$D" --intent-out "$T/intent.md" --base "$BASE2" ); }
out="$(run2 "$NOGH")"
assert_eq "$(printf '%s' "$out" | key intent_source)" "commits" "트레일러가 없으면 커밋 메시지"
assert_eq "$(printf '%s' "$out" | key intent_note)" "gh 없음" "gh 가 없으면 그 사실을 싣는다"
assert_eq "$(printf '%s' "$out" | key spec_path)" "" "트레일러가 없으면 spec_path 는 비어 있다"
assert_file_grep "$T/intent.md" 'fix: third' "의도 본문에 커밋 메시지가 있다"

# 3 — 미인증은 gh 오류로 접는다(실측 gh 2.88.1: 미인증 `gh pr view` 는 「gh auth login」 안내를 내고 rc 4)
out="$(GH_PR_ERR="To get started with GitHub CLI, please run:  gh auth login" run2 "$B:$PATH")"
assert_eq "$(printf '%s' "$out" | key intent_note)" "gh 오류" "미인증은 gh 오류다 — 따로 가르지 않는다"

# 4 — 열린 PR 본문
out="$(GH_PR_BODY="PR 본문의 요구" run2 "$B:$PATH")"
assert_eq "$(printf '%s' "$out" | key intent_source)" "commits+pr" "열린 PR 이 있으면 commits+pr"
assert_file_grep "$T/intent.md" 'PR 본문의 요구' "의도 본문에 PR 본문이 있다"

# 5 — PR 없음 · 닫힌 PR
out="$(GH_PR_ERR="no pull requests found for branch" run2 "$B:$PATH")"
assert_eq "$(printf '%s' "$out" | key intent_note)" "열린 PR 없음" "PR 이 없으면 열린 PR 없음"
out="$(GH_PR_STATE=MERGED run2 "$B:$PATH")"
assert_eq "$(printf '%s' "$out" | key intent_note)" "열린 PR 없음" "머지된 PR 은 열린 PR 이 아니다"
out="$(GH_PR_ERR="HTTP 502" run2 "$B:$PATH")"
assert_eq "$(printf '%s' "$out" | key intent_note)" "gh 오류" "그 밖의 gh 실패는 gh 오류"

# 6 — AC15: gh 는 읽기만 한다
assert_eq "$(grep -cv '^pr view ' "$GH_LOG")" "0" "gh 호출은 pr view 뿐이다 (AC15 · K-5 — auth status 도 부르지 않는다)"
assert_grep "$(cat "$GH_LOG")" '^pr view' "양의 짝 — pr view 는 실제로 불렸다"

# 7 — AC9: mtime 을 읽지 않는다. 트레일러가 가리키는 파일이 없으면 더 새 spec 이 있어도 고르지 않는다
git -C "$R" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "feat: gone" -m "Spec: docs/superpowers/specs/missing-design.md"
touch "$R/docs/superpowers/specs/new-design.md"
out="$( cd "$R" && PATH="$NOGH" bash "$D" --intent-out "$T/intent.md" --base "$BASE2" )"
assert_eq "$(printf '%s' "$out" | key spec_path)" "" "가리킨 파일이 없으면 다른 spec 을 mtime 으로 고르지 않는다"
assert_eq "$(printf '%s' "$out" | key intent_source)" "commits" "커밋 메시지로 내려간다"
assert_not_grep "$(grep -v '^[[:space:]]*#' "$D")" 'mtime|stat -|-nt |getmtime|st_mtime|pick_newest' "스크립트 코드가 mtime 을 읽지 않는다"
assert_grep "$(grep -v '^[[:space:]]*#' "$D")" 'Spec: ' "양의 짝 — 코드 코퍼스가 비지 않았다(트레일러 추출이 보인다)"

# 7b — C-2: 이 리포의 실제 트레일러는 `Spec: <path>#<key>` 꼴이다. 조각을 떼고 파일을 푼다
git -C "$R" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "feat: keyed" -m "Spec: docs/superpowers/specs/new-design.md#pr1"
out="$( cd "$R" && PATH="$NOGH" bash "$D" --intent-out "$T/intent.md" --base "$BASE2" )"
assert_eq "$(printf '%s' "$out" | key intent_source)" "spec-trailer" "#key 트레일러 — 조각을 떼면 spec-trailer"
assert_eq "$(printf '%s' "$out" | key spec_path)" "$(cd "$R" && pwd -P)/docs/superpowers/specs/new-design.md" "#key 트레일러 — spec_path 는 조각 없는 실제 파일"

# 8 — 잘못된 호출
( cd "$R" && bash "$D" >/dev/null 2>&1 ); assert_eq "$?" "2" "--intent-out 없으면 exit 2"
( cd "$R" && bash "$D" --intent-out "$T/없는/디렉토리/x.md" >/dev/null 2>&1 ); assert_eq "$?" "3" "의도 파일에 쓸 수 없으면 exit 3"

finish
