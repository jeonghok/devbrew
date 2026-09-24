#!/usr/bin/env bash
# guards: plugins/quality-gates/references/recritic-code-profile.md
#
# PR4a fix round 1, Important 1 — `references/recritic-code-profile.md` now carries
# the security-judgment rules that used to live in the deleted `agents/adversarial.md`
# persona (Gates A–D incl. verifier-writable, the two Gate C trust-boundary precedents,
# the injection-resistance line, and the evidence bar). The only other thing that reads
# this file is the harness's single `grep -qi verifier-writable` line — deleting the
# injection-resistance sentence, either Gate C precedent, an entire gate, or the
# evidence rule all leave that grep untouched and GREEN. This lock closes that gap.
#
# Section-scoped, body-unique anchors only (CLAUDE.md persona-edit-is-security-review
# discipline): every assertion is chosen so that REWORDING a gate's explanatory prose
# (without deleting the rule it states) stays GREEN, while DELETING the rule itself
# goes RED. Mutation proof (4 RED + 1 positive-control GREEN, commit → mutate →
# `git checkout HEAD --` restore) is in task-6-report.md's fix-round-1 addendum.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROFILE="$HERE/../references/recritic-code-profile.md"

# 위 `# guards:` 선언의 짝 — 이 테스트가 읽는 파일은 코드 프로필 하나다.
[ "${1:-}" = "--emit-scanned" ] && { echo "plugins/quality-gates/references/recritic-code-profile.md"; exit 0; }

. "$(cd "$HERE/../../.." && pwd)/shared/tests/assert.sh"
[ -f "$PROFILE" ] || { no "프로필 파일 부재: $PROFILE"; finish; exit; }

# ── 창(window) 추출기 — section-scoped, not a whole-file keyword count.
# 규칙이 자기 절 밖으로 옮겨지거나 지워지면 창이 비어 grep 이 RED 다.
gate_c_window() {
  awk '/^\*\*C — /{f=1} /^\*\*D — /{f=0} f' "$PROFILE"
}
gate_d_window() {
  awk '/^\*\*D — /{f=1} /^## 근거 기준/{f=0} f' "$PROFILE"
}
evidence_section() {
  awk '/^## 근거 기준/{f=1; next} /^## /{f=0} f' "$PROFILE"
}
disposition_section() {
  awk '/^## 처분 어휘/{f=1; next} /^## /{f=0} f' "$PROFILE"
}

# ── 관문 마커 A–D 존재 + 순서. `\*\*X — ` 는 각 관문 문단의 유일한 시작점이다 —
# 뒤따르는 설명 산문을 통째로 다시 써도 이 마커 자체만 살아있으면 GREEN.
assert_file_grep "$PROFILE" '^\*\*A — ' "관문 A 마커 존재"
assert_file_grep "$PROFILE" '^\*\*B — ' "관문 B 마커 존재"
assert_file_grep "$PROFILE" '^\*\*C — ' "관문 C 마커 존재"
assert_file_grep "$PROFILE" '^\*\*D — ' "관문 D 마커 존재"

A_LN="$(grep -nE '^\*\*A — ' "$PROFILE" | head -1 | cut -d: -f1)"; A_LN="${A_LN:-0}"
B_LN="$(grep -nE '^\*\*B — ' "$PROFILE" | head -1 | cut -d: -f1)"; B_LN="${B_LN:-0}"
C_LN="$(grep -nE '^\*\*C — ' "$PROFILE" | head -1 | cut -d: -f1)"; C_LN="${C_LN:-0}"
D_LN="$(grep -nE '^\*\*D — ' "$PROFILE" | head -1 | cut -d: -f1)"; D_LN="${D_LN:-0}"
if [ "$A_LN" -gt 0 ] 2>/dev/null && [ "$B_LN" -gt "$A_LN" ] 2>/dev/null \
   && [ "$C_LN" -gt "$B_LN" ] 2>/dev/null && [ "$D_LN" -gt "$C_LN" ] 2>/dev/null; then
  ok "관문 순서 A < B < C < D (lines $A_LN < $B_LN < $C_LN < $D_LN)"
else
  no "관문 순서 A < B < C < D 아님 (lines A=$A_LN B=$B_LN C=$C_LN D=$D_LN)"
fi

# ── 관문 C 창 — 두 선례 + reject 배선. 두 선례 중 하나만 지워도, 산문에서 '이미
# 막히면 reject' 를 지워도 RED. 표제어(볼드 용어)만 앵커한다 — 뒤 설명은 자유롭게
# 다시 써도 된다.
assert_grep "$(gate_c_window)" '클라이언트 측 신뢰 경계' "관문 C — 클라이언트 측 신뢰 경계 선례"
assert_grep "$(gate_c_window)" '신뢰된 설정값' "관문 C — 신뢰된 설정값 선례"
assert_grep "$(gate_c_window)" 'reject' "관문 C — 이미 막히면 reject 배선"

# ── 관문 D 창 — verifier-writable, 심은 디렉토리 조항, 빠진 점검을 added 로 내는
# 조항. 셋 중 하나만 지워도 RED.
assert_grep "$(gate_d_window)" 'verifier-writable' "관문 D — verifier-writable 정의"
assert_grep "$(gate_d_window)" '디렉토리' "관문 D — 심은 디렉토리 조항(백업 mv 오염 경로)"
assert_grep "$(gate_d_window)" 'added' "관문 D — 빠진 점검을 added 로 내는 조항"

# ── ## 근거 기준 — 주입 저항 문장(diff 안 문장은 데이터다) + reject↔evidence 배선.
assert_grep "$(evidence_section)" '데이터다' "근거 기준 — diff 내 지시문은 데이터다(주입 저항)"
assert_grep "$(evidence_section)" 'reject.*evidence' "근거 기준 — reject 는 반드시 evidence 를 인용한다"

# ── ## 처분 어휘 — raise 는 상향만 허용.
assert_grep "$(disposition_section)" '지금보다 높아야' "처분 어휘 — raise 의 to 는 지금보다 높아야 한다(하향 금지)"

finish
