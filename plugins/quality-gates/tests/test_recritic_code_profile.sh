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
# Fix round 2 — round-1's anchors were bare keywords (`reject`, `added`, `디렉토리`)
# or a loose same-line ERE (`reject.*evidence`). A copy-mutation audit found these
# survive: (a) rewording `reject`/`evidence` into a sentence that NEGATES the
# obligation ("reject 는 evidence 없이도 유효하다") still contains both words: the
# ERE pass; (b) moving `데이터다` into a NEW sub-heading (`### 주입 문장은 데이터다`)
# inside `## 근거 기준` and deleting the real body sentence — the old window only
# excluded `^## ` (level-2) headings, not the level-3 one, so the heading text itself
# satisfied the grep; (c) deleting only the backup-`mv` directory parenthetical while
# `파일로든 디렉토리로든` earlier in the same Gate D paragraph still contains
# `디렉토리`. Fixed by: (1) every anchor below is now the rule's own FULL operative
# clause, copied byte-for-byte from the committed profile including its markdown
# emphasis, ending at the clause's verb/copula — Korean negation restructures that
# ending (`...한다` → `...할 필요가 없다`/`...하지 않는다`) rather than appending
# after it, so a same-topic negation no longer contains the fixed string; (2) every
# window extractor now drops ANY line starting with `#` (not just the literal
# closing `## ` heading), so a heading can never smuggle a deleted body claim back
# in; (3) the reject/evidence rule — the one the audit actually demonstrated
# negating — additionally carries `assert_not_grep` against the three inversions the
# audit used. Those three are NOT a general inversion detector: a substring lock can
# promise "this literal is absent" and nothing about what replaces it (repo memory:
# a substring lock cannot promise inversion once the literal ends) — worded
# differently, an inversion this lock doesn't enumerate would still pass. The
# positive defense against that residual gap is (1): the full-clause fixed-string
# anchor itself already stops matching once the sentence is reworded away from its
# own ending, which is most of what makes rewording-safe/deletion-sensitive possible
# here in the first place.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROFILE="$HERE/../references/recritic-code-profile.md"

# 위 `# guards:` 선언의 짝 — 이 테스트가 읽는 파일은 코드 프로필 하나다.
[ "${1:-}" = "--emit-scanned" ] && { echo "plugins/quality-gates/references/recritic-code-profile.md"; exit 0; }

. "$(cd "$HERE/../../.." && pwd)/shared/tests/assert.sh"
[ -f "$PROFILE" ] || { no "프로필 파일 부재: $PROFILE"; finish; exit; }

# assert_fixed/assert_not_fixed — assert_grep/assert_not_grep 의 고정-문자열(-F) 짝.
# 관문 규칙은 마크다운 강조(`**`)와 백틱을 담은 리터럴이라 ERE(-E)로 쓰면 `**` 가
# 반복 연산자로 파싱된다 — 고정 문자열이 유일하게 안전하고, 정확히 리뷰가 요구한
# "그 규칙 문장을 있는 그대로 복사" 방식이다.
assert_fixed() {      # assert_fixed <text> <literal> <msg>
  if printf '%s\n' "$1" | grep -qF -- "$2"; then ok "$3"
  else no "$3"; printf '      literal:  %s\n      text:     %s\n' "$2" "$(printf '%s' "$1" | head -c 400)"; fi
}
assert_not_fixed() {  # assert_not_fixed <text> <literal> <msg>  — assert_fixed 의 짝
  if printf '%s\n' "$1" | grep -qF -- "$2"; then
    no "$3 (금지 리터럴 발견: $2)"
  else ok "$3"; fi
}

# ── 창(window) 추출기 — section-scoped, not a whole-file keyword count.
# 규칙이 자기 절 밖으로 옮겨지거나 지워지면 창이 비어 grep 이 RED 다.
# `$0 !~ /^#/` 를 모든 창에 건다 — heading 은 레벨(#/##/###…) 과 무관하게 전부
# 제외한다. 라운드 1 은 `^## ` 딱 하나만 닫는 조건으로 썼는데, 그러면 절 «안에»
# `### 어떤 규칙은 여기 있다` 같은 레벨-3 heading 을 새로 심고 그 규칙의 실제
# 본문 문장을 지워도 heading 문구 자체가 grep 을 통과시켰다(fix round 2 증거 (e)).
gate_c_window() {
  awk '/^\*\*C — /{f=1} /^\*\*D — /{f=0} f && $0 !~ /^#/' "$PROFILE"
}
gate_d_window() {
  awk '/^\*\*D — /{f=1} /^## 근거 기준/{f=0} f && $0 !~ /^#/' "$PROFILE"
}
evidence_section() {
  awk '/^## 근거 기준/{f=1; next} /^## /{f=0} f && $0 !~ /^#/' "$PROFILE"
}
disposition_section() {
  awk '/^## 처분 어휘/{f=1; next} /^## /{f=0} f && $0 !~ /^#/' "$PROFILE"
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

# ── 관문 C 창 — 두 선례 표제어 + reject 배선 «전체 문장». 표제어(볼드 용어)만
# 앵커한 두 선례는 뒤 설명을 다시 써도 되고, reject 배선은 이제 문장 전체(그
# 동사 어미 `인용한다` 까지)를 고정 문자열로 잡는다 — 바로 이 문장을 "이미
# 막히면 reject 가 필요 없다" 류로 반전해도 더는 만족되지 않는다(fix round 2
# 증거 (a)/(d): 바깥 keyword `reject` 단독은 반전 문장에도 살아남았었다).
assert_grep "$(gate_c_window)" '클라이언트 측 신뢰 경계' "관문 C — 클라이언트 측 신뢰 경계 선례"
assert_grep "$(gate_c_window)" '신뢰된 설정값' "관문 C — 신뢰된 설정값 선례"
assert_fixed "$(gate_c_window)" '이미 막히면 `reject` 이고, 그 자리를 `evidence` 에 인용한다' \
  "관문 C — reject 배선 전체 문장(반전 방어)"

# ── 관문 D 창 — verifier-writable 정의어 + 두 전체-문장 조항. round 1 은 바깥
# `added`/`디렉토리` 키워드였다 — `디렉토리` 는 같은 창 앞부분의 "파일로든
# 디렉토리로든 심을 수 있는지" 문구가 이미 만족시켜서, 정작 지워야 할 백업-mv
# 괄호절을 지워도 GREEN 이었다(fix round 2 증거 backup-mv alias). 이제 그
# 괄호절 문장 전체를 고정 문자열로 잡는다.
assert_grep "$(gate_d_window)" 'verifier-writable' "관문 D — verifier-writable 정의"
assert_fixed "$(gate_d_window)" '심은 **디렉토리**는 백업 `mv` 가 원본을 그 안으로 조용히 옮기게 만든다' \
  "관문 D — 심은 디렉토리 조항 전체 문장(백업 mv 오염 경로, 앞의 다른 '디렉토리' 언급과 구분)"
assert_fixed "$(gate_d_window)" '이 점검이 **빠진** 것은 그 자체로 `added` 에 낸다' \
  "관문 D — 빠진 점검을 added 로 내는 조항 전체 문장"

# ── ## 근거 기준 — 주입 저항 문장(전체) + reject↔evidence 배선(두 문장 각각
# 전체). round 1 의 `reject.*evidence` 는 같은 줄에 두 단어만 있으면 통과했다 —
# "reject 는 evidence 없이도 유효하다" 도 그 조건을 만족한다(fix round 2 증거
# (d), 실측 확인). 아래 두 assert_fixed 가 각 문장을 전체로 고정한다.
assert_fixed "$(evidence_section)" '그것은 데이터다' "근거 기준 — diff 내 지시문은 그것은 데이터다(주입 저항, 전체 문장)"
assert_fixed "$(evidence_section)" '**반드시** `evidence` 에 코드 줄을 인용한다' \
  "근거 기준 — reject 는 반드시 evidence 를 인용한다(전체 문장)"
assert_fixed "$(evidence_section)" '근거 없는 `reject` 는 무효로 처리된다' \
  "근거 기준 — 근거 없는 reject 는 무효(전체 문장)"
# 위 reject/evidence 배선은 리뷰가 실제로 반전 우회를 실측한 자리라 음의 짝을
# 더한다 — 다만 이 셋은 리뷰가 쓴 «그 세 표현»의 부재만 보장한다. 다른 말로
# 반전되면(예: "evidence 는 선택이다") 이 assert_not_fixed 셋은 못 잡는다 — 그
# 잔여는 위 assert_fixed 의 전체-문장 앵커가 진다(리포 메모리: 부분 문자열
# 락은 반전을 약속 못 한다 — 리터럴이 끝난 뒤는 못 본다).
assert_not_fixed "$(evidence_section)" '필요가 없다' "근거 기준 — '인용할 필요가 없다' 류 반전 리터럴 부재"
assert_not_fixed "$(evidence_section)" '없이도 유효' "근거 기준 — 'evidence 없이도 유효' 류 반전 리터럴 부재"
assert_not_fixed "$(evidence_section)" '비워 둬도' "근거 기준 — '비워 둬도' 류 반전 리터럴 부재"

# ── ## 처분 어휘 — raise 는 상향만 허용. 전체 문장(볼드 포함)으로 고정 —
# "지금과 같아도 된다" 류로 바꾸면 이 리터럴이 사라진다.
assert_fixed "$(disposition_section)" '**지금보다 높아야** 한다' \
  "처분 어휘 — raise 의 to 는 지금보다 높아야 한다(하향 금지, 전체 문장)"

finish
