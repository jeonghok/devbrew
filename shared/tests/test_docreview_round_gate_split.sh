#!/usr/bin/env bash
# guards: shared/docreview/references/reviewing-document.md plugins/spec-distill/skills/reviewing-spec/SKILL.md
#
# 라운드 게이트 항목(`decide` 묶음 + 차단 `ask`)이 한 `AskUserQuestion` 호출에 다 안
# 들어가면 질문 최대 4개씩 연속 호출로 나눈다는 규칙(Task 2d · Park P4 · 사용자 결정)이
# 절차서(`shared/docreview/references/reviewing-document.md`)와 그 첫 사이트
# (`plugins/spec-distill/skills/reviewing-spec/SKILL.md` 의 `## 게이트`)에 실제로 적혀
# 있는지 잰다. 엔진 코드는 이 태스크에서 바뀌지 않는다 — 이 락은 산문만 지킨다.
#
# ── 네 축 ────────────────────────────────────────────────────────────────
# 1. 존재 — 분할 규칙 문구가 **본문**(헤더 제외)에 있는지 본다.
#    `test_docreview_procedure_paths.sh` 와 같은 이유로 헤더 줄('#' 시작)을 코퍼스에서
#    뺀다 — 헤더나 목차가 문구를 만족시키면 본문을 지워도 GREEN 이 되는 함정이 있다
#    (리포에 기록된 실패 유형: feedback_grep_lock_header_satisfiable).
# 2. 부재 + 양의 짝 — 옛 「`AskUserQuestion` 하나로」 문면이 두 파일 모두에서 사라졌는지
#    본다. 부재 단언 단독으로는 파일이나 게이트 절 자체가 통째로 지워져도 GREEN 이므로
#    (리포에 기록된 실패 유형: feedback_negative_locks_need_positive_pair), 같은 자리에
#    게이트 절 마커(절차서는 「8. **게이트**」, SKILL 은 「## 게이트」)가 실재하는지를
#    함께 잰다.
# 3. 존재 — 상한 도달 + 열린 것이 있는 경우에도 1단계가 「추가 라운드 1회 열기」를
#    선택지로 낸다는 문구(controller 추가 요청 — `render_gate` else 분기가 이미 그렇게
#    내는데 산문은 「상한 + 열린 것 0」의 1단계 선택지만 적고 있었다). body-unique.
# 4. 존재 — Task 2d fix round 1(controller ruling R23): 그 「추가 라운드 1회 열기」가
#    열린 항목들과 **별개의 항목**으로 렌더 순서 맨 끝에 서고 같은 4개씩 분할에 함께
#    세어지며, 그 자신의 질문(선택지 「열기 / 열지 않음」 둘뿐)이라는 문구 — 다른 항목의
#    질문에 얹는 것도, 분할 밖의 부가물인 것도 아니라는 결정성 명문화. body-unique.
#    (열린 finding 리뷰 발견: 이 배칭이 결정 (a)/(b) 둘 다로 읽혀 원문이 비결정적이었다.)
# 5. 존재 — Task 13(AC17″): `AskUserQuestion` 각 선택지 `label` 이 상태별 라벨만이 아니라
#    `replacement` 압축을 붙인다는 규약, 같은 라운드 두 항목이 같은 label 을 갖지 않는다는
#    규약, 그 금지가 부재-겹침 경우에 공허해지지 않도록 부재 건수를 공시한다는 규약 —
#    셋 다 body-unique. **이 축의 한계** — 이 락이 잴 수 있는 것은 이 규약이 절차서·
#    SKILL 본문에 **적혀 있는가**뿐이다. 라벨 조립은 엔진이 아니라 런타임의
#    오케스트레이터가 하므로, 오케스트레이터가 실제로 이 규약을 **지키는가**는 이 락의
#    도달 밖이다(e2e 로만 눈으로 본다).
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

# ── 3. 존재 — 상한 도달 + 열린 것 있음에서도 1단계에 추가 라운드 선택지 (body-unique) ──
assert_contains "$REF_BODY" '그 열린 항목들과 함께' \
  "절차서 본문이 상한 도달 + 열린 것 있음에서도 1단계가 추가 라운드 1회 열기를 함께 낸다고 적는다"
assert_contains "$SKILL_BODY" '그 열린 항목들과 함께' \
  "reviewing-spec ## 게이트 본문이 같은 절을 적는다"

# ── 4. 존재 — 추가 라운드 항목이 별개 항목 · 같은 분할에 세어짐 (body-unique, R23) ──
assert_contains "$REF_BODY" '같은 4개씩 분할에 함께 세어지며' \
  "절차서 본문이 추가 라운드 선택지를 별개 항목으로 같은 4개씩 분할에 세어 넣는다고 적는다 (결정성, R23)"
assert_contains "$SKILL_BODY" '같은 4개씩 분할에 함께 세어지며' \
  "reviewing-spec ## 게이트 본문이 같은 결정성 문구를 적는다 (R23)"

# ── 5. 존재 — AskUserQuestion 라벨의 항목별 내용 (AC17″, body-unique) ────────────
# 이 락이 잴 수 있는 것은 규약의 실재뿐이다 — 아래 세 단언이 통과해도 오케스트레이터가
# 런타임에 그 규약을 실제로 지킨다는 증거는 아니다(위 축 5 설명 참조).
assert_contains "$REF_BODY" 'replacement 를 1–5 낱말로 압축' \
  "절차서 본문이 라벨을 상태별 라벨 + replacement 1–5 낱말 압축으로 조립한다고 적는다"
assert_contains "$SKILL_BODY" 'replacement 를 1–5 낱말로 압축' \
  "reviewing-spec ## 게이트 본문이 같은 라벨 압축 규약을 적는다"

assert_contains "$REF_BODY" '같은 라벨을 갖지 않는다' \
  "절차서 본문이 같은 라운드의 두 항목은 같은 라벨을 갖지 않는다고 적는다"
assert_contains "$SKILL_BODY" '같은 라벨을 갖지 않는다' \
  "reviewing-spec ## 게이트 본문이 같은 라벨 중복 금지를 적는다"

assert_contains "$REF_BODY" '부재 건수를 함께 공시' \
  "절차서 본문이 replacement 양쪽 부재로 라벨이 겹치는 경우 부재 건수를 공시한다고 적는다"
assert_contains "$SKILL_BODY" '부재 건수를 함께 공시' \
  "reviewing-spec ## 게이트 본문이 같은 부재 공시 규약을 적는다"

finish
