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

# 1 — 트레일러: 범위 안 Spec: 트레일러가 가리키는 설계문서 전부가 의도다
out="$(run "$B:$PATH")"; rc=$?
assert_eq "$rc" "0" "트레일러 — exit 0"
assert_eq "$(printf '%s' "$out" | key intent_source)" "spec-trailer" "의도 출처는 spec-trailer"
assert_file_grep "$T/intent.md" '^- new$' "의도 본문에 최신 커밋의 트레일러가 가리키는 spec 이 있다"
# 「앞 커밋의 spec 은 의도가 아니다」 부재 단언은 지웠다 — AC22 가 뒤집는다(범위 안 설계문서를 전부 싣는다).
assert_eq "$(printf '%s' "$out" | key intent_file)" "$T/intent.md" "intent_file 은 --intent-out 경로"

spec_list() { python3 -I -c 'import json,sys; print(" ".join(json.loads(sys.stdin.read())["specs"]))'; }
# AC22 — 트레일러 둘은 둘 다, 커밋 순서(오래된 것 먼저)
out="$(run "$B:$PATH")"
assert_eq "$(printf '%s' "$out" | spec_list)" "docs/superpowers/specs/old-design.md docs/superpowers/specs/new-design.md" "specs: 두 설계문서를 커밋 순서로"
assert_file_grep "$T/intent.md" '^- old$' "의도에 앞 커밋의 설계문서도 실린다"
assert_file_grep "$T/intent.md" '^<!-- qg-spec 1/2: docs/superpowers/specs/old-design.md -->$' "둘 이상이면 문서마다 구분 줄 — 1/2 가 먼저"
assert_file_grep "$T/intent.md" '^<!-- qg-spec 2/2: docs/superpowers/specs/new-design.md -->$' "둘 이상이면 문서마다 구분 줄"
assert_eq "$(grep -E '^<!-- qg-spec|^- (old|new)$' "$T/intent.md" | tr '\n' '|')" \
  "<!-- qg-spec 1/2: docs/superpowers/specs/old-design.md -->|- old|<!-- qg-spec 2/2: docs/superpowers/specs/new-design.md -->|- new|" \
  "구분 줄 뒤에 그 문서의 내용이 온다(old → new)"

gc() { r="$1"; shift; git -C "$r" -c user.email=t@t -c user.name=t commit -q "$@"; }
newrepo() {  # newrepo <dir> — trunk 위 빈 base 커밋 하나
  mkdir -p "$1/docs/superpowers/specs"; git -C "$1" init -q -b trunk; gc "$1" --allow-empty -m base
}
SP=docs/superpowers/specs

# AC22 — 트레일러 하나면 지금과 같다(바이트 동일)
case_single_trailer_identical() {
  first="$(git -C "$R" rev-parse HEAD~1)"
  out="$( cd "$R" && PATH="$NOGH" bash "$D" --intent-out "$T/intent.md" --base "$first" )"
  assert_eq "$(printf '%s' "$out" | spec_list)" "$SP/new-design.md" "트레일러 하나 — specs 하나"
  if cmp -s "$T/intent.md" <(git -C "$R" show "HEAD:$SP/new-design.md"); then
    ok "트레일러 하나 — 의도 파일은 설계문서와 바이트가 같다"
  else no "트레일러 하나 — 의도 파일은 설계문서와 바이트가 같다"; fi
  assert_file_absent "$T/intent.md" 'qg-spec' "트레일러 하나 — 구분 줄이 없다"
}
case_single_trailer_identical

# 같은 경로를 가리키는 커밋 둘 → 한 번만
case_duplicate_trailer_once() {
  local X="$T/dup"; newrepo "$X"
  printf '# A\n- a\n' > "$X/$SP/a-design.md"; git -C "$X" add -A
  gc "$X" -m "feat: a1" -m "Spec: $SP/a-design.md"
  gc "$X" --allow-empty -m "feat: a2" -m "Spec: $SP/a-design.md#k"
  out="$( cd "$X" && PATH="$NOGH" bash "$D" --intent-out "$T/intent.md" --base "$(git -C "$X" rev-parse HEAD~2)" )"
  assert_eq "$(printf '%s' "$out" | spec_list)" "$SP/a-design.md" "같은 설계문서는 한 번만 싣는다"
  assert_file_absent "$T/intent.md" 'qg-spec' "같은 설계문서 둘 — 하나로 세어 구분 줄이 없다"
}
case_duplicate_trailer_once

# 한 커밋 메시지에 Spec: 줄 둘 → 둘 다(줄 순서)
case_multiple_spec_lines_one_commit() {
  local X="$T/multi"; newrepo "$X"
  printf '# A\n- a\n' > "$X/$SP/a-design.md"; printf '# B\n- b\n' > "$X/$SP/b-design.md"; git -C "$X" add -A
  gc "$X" -m "feat: two" -m "Spec: $SP/a-design.md
Spec: $SP/b-design.md"
  out="$( cd "$X" && PATH="$NOGH" bash "$D" --intent-out "$T/intent.md" --base "$(git -C "$X" rev-parse HEAD~1)" )"
  assert_eq "$(printf '%s' "$out" | spec_list)" "$SP/a-design.md $SP/b-design.md" "한 커밋의 Spec: 줄 둘을 다 받는다"
  assert_file_grep "$T/intent.md" '^- b$' "둘째 Spec: 줄의 설계문서도 의도에 있다"
}
case_multiple_spec_lines_one_commit

# 거부 하나 + 정상 하나 → 정상은 싣고 거부를 센다(첫 거부에서 멈추지 않는다)
case_one_rejected_among_valid() {
  local X="$T/rej"; newrepo "$X"
  printf '# A\n- a\n' > "$X/$SP/a-design.md"; git -C "$X" add -A
  gc "$X" -m "feat: mixed" -m "Spec: ../x.md
Spec: $SP/a-design.md"
  out="$( cd "$X" && PATH="$NOGH" bash "$D" --intent-out "$T/intent.md" --base "$(git -C "$X" rev-parse HEAD~1)" )"
  assert_eq "$(printf '%s' "$out" | spec_list)" "$SP/a-design.md" "거부 뒤의 정상 트레일러를 싣는다"
  assert_eq "$(printf '%s' "$out" | key intent_source)" "spec-trailer" "거부가 섞여도 spec-trailer"
  assert_eq "$(printf '%s' "$out" | key intent_note)" "spec 경로 거부 1개" "거부 수를 공시한다"
}
case_one_rejected_among_valid

# 범위 모드 — 설계문서는 끝 커밋의 트리에서 읽는다(작업 트리에 없어도)
case_range_reads_spec_from_end_tree() {
  local X="$T/rng"; newrepo "$X"
  local S; S="$(git -C "$X" rev-parse HEAD)"
  printf '# R\n- r-end\n' > "$X/$SP/r-design.md"; git -C "$X" add -A
  gc "$X" -m "feat: r" -m "Spec: $SP/r-design.md"
  local E; E="$(git -C "$X" rev-parse HEAD)"
  git -C "$X" checkout -q "$S"
  [ ! -e "$X/$SP/r-design.md" ] && ok "전제: 작업 트리(시작 커밋)에 설계문서가 없다" || no "전제: 작업 트리(시작 커밋)에 설계문서가 없다"
  out="$( cd "$X" && PATH="$NOGH" bash "$D" --intent-out "$T/intent.md" --range "$S" "$E" )"; rc=$?
  assert_eq "$rc" "0" "범위 모드 — exit 0"
  assert_eq "$(printf '%s' "$out" | spec_list)" "$SP/r-design.md" "범위 모드 — specs 하나"
  assert_eq "$(printf '%s' "$out" | key intent_source)" "spec-trailer" "범위 모드 — spec-trailer"
  if cmp -s "$T/intent.md" <(git -C "$X" show "$E:$SP/r-design.md"); then
    ok "범위 모드 — 의도는 끝 커밋의 설계문서다"
  else no "범위 모드 — 의도는 끝 커밋의 설계문서다"; fi
}
case_range_reads_spec_from_end_tree

# 범위 모드 — 끝 트리에서 심볼릭 링크(120000) · 없는 경로는 거부
case_range_symlink_spec_rejected() {
  local X="$T/rlink"; newrepo "$X"
  local S; S="$(git -C "$X" rev-parse HEAD)"
  printf 'LINK-TARGET-XYZ\n' > "$X/target.md"
  ln -s ../../../target.md "$X/$SP/link-design.md"
  printf '# OK\n- ok\n' > "$X/$SP/ok-design.md"
  git -C "$X" add -A
  gc "$X" -m "feat: link" -m "Spec: $SP/link-design.md"
  gc "$X" --allow-empty -m "feat: gone" -m "Spec: $SP/missing-design.md"
  gc "$X" --allow-empty -m "feat: ok" -m "Spec: $SP/ok-design.md"
  local E; E="$(git -C "$X" rev-parse HEAD)"
  assert_eq "$(git -C "$X" ls-tree "$E" -- "$SP/link-design.md" | cut -c1-6)" "120000" "전제: 끝 트리에서 링크는 120000 이다"
  out="$( cd "$X" && PATH="$NOGH" bash "$D" --intent-out "$T/intent.md" --range "$S" "$E" )"
  assert_eq "$(printf '%s' "$out" | spec_list)" "$SP/ok-design.md" "범위 모드 — 링크 · 없는 경로는 빼고 보통 파일은 싣는다"
  assert_grep "$(printf '%s' "$out" | key intent_note)" '거부' "범위 모드 — 링크 거부를 공시한다"
  assert_eq "$(printf '%s' "$out" | key intent_note)" "spec 경로 거부 2개" "범위 모드 — 링크 · 없는 경로 둘을 센다"
  assert_file_absent "$T/intent.md" 'LINK-TARGET-XYZ' "범위 모드 — 링크 대상 내용이 의도에 없다"
}
case_range_symlink_spec_rejected

# 범위 모드 — 트리 경로 · glob · pathspec 마법은 거부, `./` 는 떼고 같은 설계문서로 한 번만.
# 범위 값은 한 번 풀어 얼린다 — 줄인 커밋 id · 브랜치 이름도 받는다.
case_range_tree_glob_dotslash() {
  local X="$T/rtree"; newrepo "$X"
  local S; S="$(git -C "$X" rev-parse HEAD)"
  printf '# A\n- a\n' > "$X/$SP/a-design.md"; git -C "$X" add -A
  gc "$X" -m "feat: a" -m "Spec: $SP
Spec: $SP/*.md
Spec: :(top)$SP/a-design.md
Spec: ./$SP/a-design.md
Spec: $SP/a-design.md"
  git -C "$X" checkout -q -b topic
  out="$( cd "$X" && PATH="$NOGH" bash "$D" --intent-out "$T/intent.md" --range "$(git -C "$X" rev-parse --short "$S")" topic )"; rc=$?
  assert_eq "$rc" "0" "범위 모드 — 줄인 id · 브랜치 이름도 범위로 받는다"
  assert_eq "$(printf '%s' "$out" | spec_list)" "$SP/a-design.md" "범위 모드 — ./ 를 떼면 같은 설계문서라 한 번만 싣는다"
  assert_eq "$(printf '%s' "$out" | key intent_note)" "spec 경로 거부 3개" "범위 모드 — 트리 경로 · glob · pathspec 마법 셋을 거부로 센다"
  assert_file_absent "$T/intent.md" 'qg-spec' "범위 모드 — 하나로 세어 구분 줄이 없다"
}
case_range_tree_glob_dotslash

# 범위 모드 아님 — 보통 파일이 아닌 트레일러(디렉토리 · glob · pathspec 마법 · 없는 파일)도 거부로 센다
case_nonrange_nonfile_rejected() {
  local X="$T/nfile"; newrepo "$X"
  printf '# A\n- a\n' > "$X/$SP/a-design.md"; git -C "$X" add -A
  gc "$X" -m "feat: a" -m "Spec: $SP
Spec: $SP/*.md
Spec: :(top)$SP/a-design.md
Spec: $SP/missing-design.md
Spec: $SP/a-design.md"
  out="$( cd "$X" && PATH="$NOGH" bash "$D" --intent-out "$T/intent.md" --base "$(git -C "$X" rev-parse HEAD~1)" )"
  assert_eq "$(printf '%s' "$out" | spec_list)" "$SP/a-design.md" "보통 파일이 아닌 트레일러는 빼고 정상은 싣는다"
  assert_eq "$(printf '%s' "$out" | key intent_note)" "spec 경로 거부 4개" "디렉토리 · glob · pathspec 마법 · 없는 파일을 거부로 센다"
}
case_nonrange_nonfile_rejected

# 범위 모드 — 트레일러 없는 범위는 커밋 메시지만, gh 는 부르지 않는다
case_range_no_gh_call() {
  local X="$T/rnogh"; newrepo "$X"
  local S; S="$(git -C "$X" rev-parse HEAD)"
  gc "$X" --allow-empty -m "feat: in-range-commit"
  local E; E="$(git -C "$X" rev-parse HEAD)"
  local L="$T/gh-range.log"; : > "$L"
  out="$( cd "$X" && GH_LOG="$L" GH_PR_BODY="PR-BODY-XYZ" PATH="$B:$PATH" bash "$D" --intent-out "$T/intent.md" --range "$S" "$E" )"
  [ ! -s "$L" ] && ok "범위 모드 — gh 를 부르지 않는다" || no "범위 모드 — gh 를 부르지 않는다 ($(cat "$L"))"
  assert_eq "$(printf '%s' "$out" | key intent_source)" "commits" "범위 모드 — 트레일러가 없으면 commits"
  assert_eq "$(printf '%s' "$out" | key intent_note)" "범위 모드 — PR 본문 안 읽음" "범위 모드 — PR 본문을 안 읽은 사실을 싣는다"
  assert_file_grep "$T/intent.md" 'in-range-commit' "범위 모드 — 의도에 범위 안 커밋 메시지가 있다"
  assert_file_absent "$T/intent.md" 'PR-BODY-XYZ' "범위 모드 — PR 본문이 의도에 없다"
}
case_range_no_gh_call

# --base 와 --range 는 함께 못 쓴다 · --range 는 커밋 둘
case_base_and_range_exclusive() {
  local h; h="$(git -C "$R" rev-parse HEAD)"
  ( cd "$R" && bash "$D" --intent-out "$T/intent.md" --base "$h" --range "$h" "$h" >/dev/null 2>&1 ); assert_eq "$?" "2" "--base 와 --range 를 함께 주면 exit 2"
  ( cd "$R" && bash "$D" --intent-out "$T/intent.md" --range "$h" >/dev/null 2>&1 ); assert_eq "$?" "2" "--range 에 커밋 하나면 exit 2"
  ( cd "$R" && bash "$D" --intent-out "$T/intent.md" --range --all "$h" >/dev/null 2>&1 ); assert_eq "$?" "2" "--range 의 시작이 - 로 시작하면 exit 2"
  ( cd "$R" && bash "$D" --intent-out "$T/intent.md" --range "$h" nosuchref >/dev/null 2>&1 ); assert_eq "$?" "2" "--range 의 끝이 커밋이 아니면 exit 2"
}
case_base_and_range_exclusive

# review-criteria.md — 설계문서가 여럿일 때 막는 지적의 근거 표기
assert_file_grep "$SCRIPT_DIR/../references/review-criteria.md" '^의도 출처에 설계문서가 여럿이면' \
  "기준 블록에 「설계문서가 여럿이면」 줄이 있다"
# 근거 표기는 의도 출처의 요구를 어긴 막는 지적에만 — 막는 지적 전부로 넓어지지 않는다.
assert_file_grep "$SCRIPT_DIR/../references/review-criteria.md" '^의도 출처에 설계문서가 여럿이면\(구분 줄 `<!-- qg-spec k/N: 경로 -->`\), 의도 출처의 요구를 어긴 막는 지적마다 summary 끝 괄호에 근거 문서의 경로와 AC 번호를 단다\(예: `\(docs/a-design\.md AC3\)`\)\.$' \
  "근거 표기 줄은 의도 출처의 요구를 어긴 막는 지적으로 좁혀져 있다"

# 2 — 트레일러 없음 · gh 없음 → 커밋 메시지만, 그 사실을 공시
git -C "$R" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "fix: third (no trailer)"
BASE2="$(git -C "$R" rev-parse HEAD~1)"
run2() { ( cd "$R" && PATH="$1" bash "$D" --intent-out "$T/intent.md" --base "$BASE2" ); }
out="$(run2 "$NOGH")"
assert_eq "$(printf '%s' "$out" | key intent_source)" "commits" "트레일러가 없으면 커밋 메시지"
assert_eq "$(printf '%s' "$out" | key intent_note)" "gh 없음" "gh 가 없으면 그 사실을 싣는다"
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
assert_file_absent "$T/intent.md" '^- new$' "가리킨 파일이 없으면 다른 spec 을 mtime 으로 고르지 않는다"
assert_eq "$(printf '%s' "$out" | key intent_source)" "commits" "커밋 메시지로 내려간다"
assert_eq "$(printf '%s' "$out" | key intent_note)" "spec 경로 거부 1개" "가리킨 파일이 없으면 거부로 공시한다(조용히 버리지 않는다)"
assert_not_grep "$(grep -v '^[[:space:]]*#' "$D")" 'mtime|stat -|-nt |getmtime|st_mtime|pick_newest' "스크립트 코드가 mtime 을 읽지 않는다"
assert_grep "$(grep -v '^[[:space:]]*#' "$D")" 'Spec: ' "양의 짝 — 코드 코퍼스가 비지 않았다(트레일러 추출이 보인다)"

# 7b — C-2: 이 리포의 실제 트레일러는 `Spec: <path>#<key>` 꼴이다. 조각을 떼고 파일을 푼다
git -C "$R" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "feat: keyed" -m "Spec: docs/superpowers/specs/new-design.md#pr1"
out="$( cd "$R" && PATH="$NOGH" bash "$D" --intent-out "$T/intent.md" --base "$BASE2" )"
assert_eq "$(printf '%s' "$out" | key intent_source)" "spec-trailer" "#key 트레일러 — 조각을 떼면 spec-trailer"
assert_file_grep "$T/intent.md" '^- new$' "#key 트레일러 — 의도 본문은 조각 없는 실제 파일이다"

# 7c — P7: 트레일러는 비신뢰 입력이다. 절대 경로 · `..` · 리포 밖으로 풀리는 심볼릭 링크는 읽지 않는다
printf 'OUTSIDE-SECRET-XYZ\n' > "$T/outside.txt"
ln -s "$T/outside.txt" "$R/docs/superpowers/specs/escape.md"
ln -s new-design.md "$R/docs/superpowers/specs/inrepo-link.md"
# 범위는 방금 만든 커밋 하나다 — 범위 안 트레일러를 전부 읽으므로(AC22) 앞 케이스의 트레일러가 섞이지 않게 한다.
trailer_case() {  # trailer_case <Spec: 값> → out
  git -C "$R" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "feat: case" -m "Spec: $1"
  out="$( cd "$R" && PATH="$NOGH" bash "$D" --intent-out "$T/intent.md" --base "$(git -C "$R" rev-parse HEAD~1)" )"
}
refused() {  # refused <Spec: 값> <라벨>
  for suffix in "" "#k"; do
    trailer_case "$1$suffix"
    assert_eq "$(printf '%s' "$out" | key intent_note)" "spec 경로 거부 1개" "$2$suffix — 거부를 공시한다"
    assert_file_absent "$T/intent.md" 'OUTSIDE-SECRET-XYZ|root:|hunter2' "$2$suffix — 밖의 파일 내용이 의도 파일에 없다"
  done
}
refused "$T/outside.txt" "절대 경로"
refused "/etc/passwd" "절대 경로(/etc/passwd)"
refused "../outside.txt" ".. 경로"
refused "docs/../../outside.txt" "중간 .. 경로"
refused "docs/superpowers/../superpowers/specs/new-design.md" "리포 안으로 되돌아오는 .. 경로"
refused "docs/superpowers/specs/escape.md" "리포 밖으로 나가는 심볼릭 링크"
# 7d — 추적되지 않은 파일은 리포 안이어도 읽지 않는다(git-ignored · 미추적 · .git/)
printf '.env\n' > "$R/.gitignore"; git -C "$R" add .gitignore
git -C "$R" -c user.email=t@t -c user.name=t commit -q -m "chore: ignore"
printf 'SECRET=hunter2\n' > "$R/.env"
printf 'SECRET=hunter2-untracked\n' > "$R/untracked-notes.md"
printf 'SECRET=hunter2-link\n' > "$R/untracked-target.md"
ln -s ../../../untracked-target.md "$R/docs/superpowers/specs/link-to-untracked.md"
git -C "$R" config remote.origin.url "https://user:hunter2-token@example.com/x.git"
refused ".env" "git-ignored .env"
refused "untracked-notes.md" "미추적 파일"
refused ".git/config" ".git/config"
refused "docs/superpowers/specs/link-to-untracked.md" "미추적 대상을 가리키는 리포 안 링크"
for f in intent.md; do
  assert_file_absent "$T/$f" 'hunter2' "비밀 문자열이 의도 파일에 없다"
done
trailer_case "docs/superpowers/specs/new-design.md"
assert_eq "$(printf '%s' "$out" | key intent_source)" "spec-trailer" "추적된 spec 은 받아들인다(양의 짝)"

for suffix in "" "#k"; do
  trailer_case "docs/superpowers/specs/inrepo-link.md$suffix"
  assert_eq "$(printf '%s' "$out" | key intent_source)" "spec-trailer" "리포 안 심볼릭 링크$suffix — 받아들인다(양의 짝)"
  assert_file_grep "$T/intent.md" '^- new$' "리포 안 심볼릭 링크$suffix — 대상 본문을 읽는다"
done

# 9 — --base 없이 기본 브랜치를 못 찾으면 고치는 법을 자기 이름으로 stderr 에 낸다(R 에는 origin/HEAD 가 없다).
NODEF="discover-spec.sh: 기본 브랜치를 찾지 못했다 — origin/HEAD 가 없거나 가리키는 브랜치가 없다. git remote set-head origin --auto 로 고친다"
err="$( cd "$R" && PATH="$B:$PATH" GH_LOG="$T/gh.log" bash "$D" --intent-out "$T/intent.md" 2>&1 >/dev/null )"
assert_contains "$err" "$NODEF" "origin/HEAD 없음 → stderr 에 set-head 안내"
err="$( cd "$R" && PATH="$B:$PATH" GH_LOG="$T/gh.log" bash "$D" --intent-out "$T/intent.md" --base "$BASE" 2>&1 >/dev/null )"
assert_not_contains "$err" "set-head" "--base 를 주면 기준선을 풀지 않아 안내가 없다(양의 짝)"
git -C "$R" update-ref refs/remotes/origin/main "$BASE"
git -C "$R" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
err="$( cd "$R" && PATH="$B:$PATH" GH_LOG="$T/gh.log" bash "$D" --intent-out "$T/intent.md" 2>&1 >/dev/null )"
assert_not_contains "$err" "set-head" "--base 없이도 origin/HEAD 가 있으면 안내가 없다(부재 짝)"
git -C "$R" symbolic-ref --delete refs/remotes/origin/HEAD; git -C "$R" update-ref -d refs/remotes/origin/main

# 8 — 잘못된 호출
( cd "$R" && bash "$D" >/dev/null 2>&1 ); assert_eq "$?" "2" "--intent-out 없으면 exit 2"
( cd "$R" && bash "$D" --intent-out "$T/없는/디렉토리/x.md" >/dev/null 2>&1 ); assert_eq "$?" "3" "의도 파일에 쓸 수 없으면 exit 3"

finish
