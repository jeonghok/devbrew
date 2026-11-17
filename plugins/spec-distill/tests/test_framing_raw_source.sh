#!/usr/bin/env bash
# guards: plugins/spec-distill/templates/interview-seed-audit-template.md plugins/spec-distill/templates/interview-seed-template.md plugins/spec-distill/skills/pm-interview/references/seed-input.md plugins/spec-distill/references/docreview-profiles/seed.md plugins/spec-distill/scripts/build_seed_inline_blob.py
#
# 원문이 받은 글자 그대로 남는 규약(raw-source canon)의 문면 락 — 기록 파일(audit) 템플릿의 `## 1` ·
# `## 2` 설명, seed 템플릿 · seed 입력 규약의 «seed 는 모델이 줄인 글» 문장, seed 리뷰 프로필의 읽는 법.
# `framing_fails` 는 실패한 항목 이름을 한 줄씩 낸다(빈 출력 = 통과). 항목마다 한 검사다 — 뒤 Task 가
# 같은 함수에 항목을 더한다. 변이 검사는 임시 사본을 같은 함수에 먹여 그 이름으로 실패하는지 본다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SK="$ROOT/plugins/spec-distill/skills/request-framing/SKILL.md"
AT="$ROOT/plugins/spec-distill/templates/interview-seed-audit-template.md"
ST="$ROOT/plugins/spec-distill/templates/interview-seed-template.md"
SI="$ROOT/plugins/spec-distill/skills/pm-interview/references/seed-input.md"
PR="$ROOT/plugins/spec-distill/references/docreview-profiles/seed.md"
SCRIPTS="$ROOT/plugins/spec-distill/scripts"
if [ "${1:-}" = "--emit-scanned" ]; then
  for f in plugins/spec-distill/templates/interview-seed-audit-template.md plugins/spec-distill/templates/interview-seed-template.md \
           plugins/spec-distill/skills/pm-interview/references/seed-input.md plugins/spec-distill/references/docreview-profiles/seed.md \
           plugins/spec-distill/scripts/build_seed_inline_blob.py; do
    echo "$f"
  done
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

# 절 추출 — 시작 제목 줄부터 다음 `## ` 제목 앞까지.
sec() { awk -v h="$2" 'index($0,h)==1{f=1; next} /^## /{f=0} f' "$1"; }
has() { printf '%s\n' "$1" | grep -qF -- "$2"; }

# framing_fails <SKILL> <감사 템플릿> <seed 템플릿> <seed-input> <seed 프로필> — 실패한 항목 이름을 한 줄씩.
framing_fails() {
  local skill="$1" at="$2" st="$3" si="$4" pr="$5" s1 s2 body
  s1="$(sec "$at" '## 1. 원문')"; s2="$(sec "$at" '## 2. 질문 전체')"
  has "$s1" 'token · key · credential 로 보이는 값은 쓰기 전에 가림 표시' || echo tpl_redaction
  {
    has "$s1" '`### 받은 글 — <갈래> · <준 이> · <날짜>[ · 라운드 <n> 의 답]`' &&
    has "$s1" '설명 문장을 따로 두지 않는다' &&
    has "$s1" '그 밖의 줄은 전부 받은 글자 그대로다' &&
    has "$s1" '`### ` 로 시작하는 줄은 저자가 쓴 구분 줄이라 읽되 사용자의 말이 아니다'
  } || echo tpl_separator
  # 템플릿의 구분 줄 머리(`### 받은 글 — ` 까지)가 호스트가 아는 패턴에 맞는가 — 패턴은 모듈에서 가져온다.
  local head
  head="$(printf '%s\n' "$s1" | grep -F '`### 받은 글 — <갈래>' | head -1 | sed 's/.*`\(### 받은 글 — \)<갈래>.*/\1/')"
  PYTHONDONTWRITEBYTECODE=1 python3 -I -c '
import sys
sys.path.insert(0, sys.argv[1])
import build_seed_inline_blob as m
sys.exit(0 if m.RECEIVED_SEPARATOR_RE.match(sys.argv[2] + "직접 친 글") else 1)
' "$SCRIPTS" "$head" 2>/dev/null || echo tpl_separator_regex
  {
    has "$s2" '  - 당신이 답한 것 (<라벨 | 적음 | 라벨 · 적음>): <고른 라벨 또는 적은 말 — one-line 을 거친 그대로, 답이 없으면 표시 없이 «(답 없음)»>' &&
    has "$s2" '`(라벨)`' && has "$s2" '`(적음)`' && has "$s2" '`(라벨 · 적음)`' &&
    has "$s2" '  - 내가 읽은 것: 「<풀이 문장>」 — <고름 | 고르지 않음>'
  } || echo tpl_answer_mark
  {
    has "$(cat "$st")" 'seed 는 다음 세션의 첫 턴에 넘기는, 모델이 줄인 글이다. 사용자의 말은 기록 파일(audit)의 원자료다.' &&
    has "$(cat "$si")" '다음 세션의 첫 턴에 넘기는, 모델이 줄인 글**이다. 사용자의 말은 seed 옆 기록 파일(audit)의 원자료다.' &&
    ! has "$(tr -d '\n' < "$si" | tr -s ' ')" '사용자가 확정한 메시지' &&
    ! has "$(tr -d '\n' < "$si" | tr -s ' ')" '그것이 이 세션의 최초 사용자 발화다'
  } || echo seed_role
  body="$(cat "$pr")"
  has "$body" '`### ` 로 시작하는 줄은 저자가 쓴 구분 줄이라 읽되 사용자의 말이 아니다.' || echo profile_sep
  has "$body" '고른 사실과 그 뜻은 정답이지만, 라벨의 낱말 하나하나는 사용자가 쓴 글이 아니다.' || echo profile_label
  has "$body" '「라벨 · 적음」 이 붙은 답에서는 고른 라벨이 모델 문장이고 그 뒤의 적은 말은 사용자의 글이다' || echo profile_mixed
}

# 실제 파일 — 빈 출력이면 통과.
FF="$(framing_fails "$SK" "$AT" "$ST" "$SI" "$PR")"
[ -z "$FF" ] && ok "framing_fails: 실제 파일 전 항목 통과" || no "framing_fails 실패 항목: $(printf '%s' "$FF" | tr '\n' ' ')"

# 변이 — 임시 사본에서 첫 출현만 바꿔 그 이름으로 실패하는지 본다(통과가 정답인 락의 이빨).
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mutate() { # <원본> <사본> <옛> <새> — 첫 출현만(새가 비면 삭제). 안 바뀌면 rc 1.
  python3 -I - "$1" "$2" "$3" "$4" <<'PY'
import sys
src, dst, old, new = sys.argv[1:5]
t = open(src, encoding="utf-8").read()
if old not in t:
    sys.exit(1)
open(dst, "w", encoding="utf-8").write(t.replace(old, new, 1))
PY
}
expect_fail() { # <항목> <at> <st> <si> <pr>
  local want="$1" out; shift
  out="$(framing_fails "$SK" "$1" "$2" "$3" "$4")"
  if printf '%s\n' "$out" | grep -qxF "$want"; then ok "변이 → $want 로 실패"; else no "변이가 $want 로 실패하지 않았다(출력: $(printf '%s' "$out" | tr '\n' ' '))"; fi
}
mutate "$AT" "$T/at1.md" '쓰기 전에 가림 표시' '쓴 뒤 가림 표시' && expect_fail tpl_redaction "$T/at1.md" "$ST" "$SI" "$PR" || no "변이 준비 실패: tpl_redaction"
mutate "$AT" "$T/at2.md" '### 받은 글 — ' '### 받은글 — ' && expect_fail tpl_separator "$T/at2.md" "$ST" "$SI" "$PR" || no "변이 준비 실패: tpl_separator"
mutate "$AT" "$T/at3.md" '`(라벨 · 적음)`' '' && expect_fail tpl_answer_mark "$T/at3.md" "$ST" "$SI" "$PR" || no "변이 준비 실패: tpl_answer_mark"
mutate "$SI" "$T/si1.md" '다음 세션의 첫 턴에 넘기는, 모델이 줄인 글' '**Phase 0 에서 사용자가 확정한 메시지' && expect_fail seed_role "$AT" "$ST" "$T/si1.md" "$PR" || no "변이 준비 실패: seed_role"
mutate "$PR" "$T/pr1.md" '라벨의 낱말 하나하나는 사용자가 쓴 글이 아니다.' '' && expect_fail profile_label "$AT" "$ST" "$SI" "$T/pr1.md" || no "변이 준비 실패: profile_label"

finish
