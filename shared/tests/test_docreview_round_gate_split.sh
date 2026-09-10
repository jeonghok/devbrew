#!/usr/bin/env bash
# guards: shared/docreview/references/reviewing-document.md plugins/spec-distill/skills/reviewing-spec/SKILL.md
#
# 라운드 게이트 항목(`decide` 묶음 + 차단 `ask`)이 한 `AskUserQuestion` 호출에 다 안
# 들어가면 질문 최대 4개씩 연속 호출로 나눈다는 규칙(Task 2d · Park P4 · 사용자 결정)이
# 절차서(`shared/docreview/references/reviewing-document.md`)와 그 첫 사이트
# (`plugins/spec-distill/skills/reviewing-spec/SKILL.md` 의 `## 게이트`)에 실제로 적혀
# 있는지 잰다. 엔진 코드는 이 태스크에서 바뀌지 않는다 — 이 락은 산문만 지킨다.
#
# ── 두 축 ────────────────────────────────────────────────────────────────
# 1. 존재 — 분할 규칙 문구가 **본문**(헤더 제외)에 있는지 본다.
#    `test_docreview_procedure_paths.sh` 와 같은 이유로 헤더 줄('#' 시작)을 코퍼스에서
#    뺀다 — 헤더나 목차가 문구를 만족시키면 본문을 지워도 GREEN 이 되는 함정이 있다
#    (리포에 기록된 실패 유형: feedback_grep_lock_header_satisfiable).
# 2. 부재 + 양의 짝 — 옛 「`AskUserQuestion` 하나로」 문면이 두 파일 모두에서 사라졌는지
#    본다. 부재 단언 단독으로는 파일이나 게이트 절 자체가 통째로 지워져도 GREEN 이므로
#    (리포에 기록된 실패 유형: feedback_negative_locks_need_positive_pair), 같은 자리에
#    게이트 절 마커(절차서는 「8. **게이트**」, SKILL 은 「## 게이트」)가 실재하는지를
#    함께 잰다.
set -u -o pipefail
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/references/reviewing-document.md"
  echo "plugins/spec-distill/skills/reviewing-spec/SKILL.md"
  exit 0
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$REPO_ROOT/shared/tests/assert.sh"

REF="$REPO_ROOT/shared/docreview/references/reviewing-document.md"
SKILL="$REPO_ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md"

for f in "$REF" "$SKILL"; do
  if [ ! -r "$f" ]; then
    echo "✗ FATAL: $f 를 읽을 수 없다"
    exit 1
  fi
done

REF_FULL="$(cat "$REF")"
SKILL_FULL="$(cat "$SKILL")"
# 헤더(줄이 '#' 로 시작)를 빼고 본문만 남긴다 — body-unique 를 구조적으로 강제한다.
REF_BODY="$(grep -vE '^#' "$REF")"
SKILL_BODY="$(grep -vE '^#' "$SKILL")"

# ── 1. 존재 — 분할 규칙 문구 (body-unique) ─────────────────────────────────
assert_contains "$REF_BODY" '최대 4개씩' \
  "절차서 본문이 라운드 게이트를 AskUserQuestion 최대 4개씩 연속 호출로 나눈다고 적는다 (body-unique)"
assert_contains "$SKILL_BODY" '최대 4개씩' \
  "reviewing-spec ## 게이트 본문이 같은 4개씩 분할 규칙을 적는다 (body-unique)"

# ── 2. 부재 + 양의 짝 ────────────────────────────────────────────────────
assert_not_contains "$REF_FULL" '`AskUserQuestion` 하나로' \
  "절차서에 옛 「AskUserQuestion 하나로」 문면이 없다"
assert_not_contains "$SKILL_FULL" '`AskUserQuestion` **하나**로' \
  "reviewing-spec 에 옛 「AskUserQuestion 하나로」 문면이 없다"

assert_grep "$REF_FULL" '^8\. \*\*게이트\*\*' \
  "양의 짝 — 절차서에 8단계 게이트 절이 실재한다 (부재 단언이 통째 삭제로 헛통과하지 않는다)"
assert_grep "$SKILL_FULL" '^## 게이트$' \
  "양의 짝 — reviewing-spec 에 ## 게이트 절이 실재한다"

finish
