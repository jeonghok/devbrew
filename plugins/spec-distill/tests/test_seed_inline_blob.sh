#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/build_seed_inline_blob.py plugins/spec-distill/scripts/seed_review_log.py
#
# build_seed_inline_blob.py 를 실행으로 잰다. 이 조립기가 seed 리뷰 번들의 유일한 산출자다 —
# 소비자는 framing-requests/SKILL.md 의 「### 번들」 블록이고, 그 블록이 만든 두 번들을 탐지
# 리뷰어 · codex 러너(detect)와 재비판자(recritic)가 나눠 읽는다.
#
# 재는 것: 재료 다섯의 실림과 순서 · seed frontmatter 제거 · 재료별 부재 exit 2 · 절 부재의
# 소리 · **재비판 번들에 `## 6` 의 판정 이력 줄이 0건**(AC11) · 두 변이(갈래를 지우면 AC11 이 RED,
# frontmatter 제거를 지우면 누출 단언이 RED) · 비신뢰 `## 1` 안의 임의 `## ` 줄이
# 절을 자르지 않는가(truncation) · 같은 audit 제목이 두 번 나오면 조립을 거절하는가(hijacking,
# exit 2 · stdout 없음) · heading-모양 줄 경고가 뜨면서도 진짜 문구는 여전히 실리는가(forging) ·
# 정상 fixture 는 경고가 0건인가(음성 짝, `### 라운드 <n>` 스캐폴드 예외) · 번들의
# `(audit \`…\`)` 참조가 UNTRUSTED_VERBATIM_SECTIONS 와 순서까지 같은가.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$ROOT/plugins/spec-distill/scripts/build_seed_inline_blob.py"
. "$ROOT/shared/tests/assert.sh"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/scripts/build_seed_inline_blob.py"
  echo "plugins/spec-distill/scripts/seed_review_log.py"
  exit 0
fi
test -f "$SCRIPT" || { no "부재: $SCRIPT"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }
export PYTHONDONTWRITEBYTECODE=1
TMP="$(mktemp -d -t sd-seed-blob-XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT

printf -- '---\ntype: interview-seed\nnext_phase: spec-distill:interview\naudit_file: seed.audit.md\n---\n\nSEED_BODY_MARKER 로그인이 가끔 실패한다.\n' > "$TMP/seed.md"
cat > "$TMP/seed.audit.md" <<'EOF'
---
type: interview-seed-audit
payload: seed.md
---

# Topic — Interview Seed Audit

## 1. 원문

RAW_TEXT_MARKER 사용자가 실제로 한 말.

## 2. 질문 전체

### 라운드 1

- 물은 것: QUESTION_MARKER 무엇을 맡기려 하나요
  - 선택지: 자유 입력
  - 당신이 답한 것: ANSWER_MARKER 로그인 버그

## 3. 긴 초안

DRAFT_MARKER 긴 초안.

## 6. 리뷰 결정

- D1.1 · r1 · adopt · abcd1234#r1.1 · "USER_QUOTE_MARKER 채택" — HISTORY_SUMMARY_MARKER 요약
EOF
printf '# CLAUDE.md\nCLAUDE_MD_MARKER 테스트용 규칙.\n' > "$TMP/CLAUDE.md"

run() { python3 "$SCRIPT" "$TMP/seed.md" "$TMP/seed.audit.md" "$TMP/CLAUDE.md" "$@" 2>"$TMP/err.txt"; }

# ── detect — 다섯 재료, 순서대로 ─────────────────────────────────────────────
out="$(run)"; rc=$?
assert_eq "$rc" "0" "detect: exit 0"
prev=0; order_ok=1
for m in SEED_BODY_MARKER RAW_TEXT_MARKER QUESTION_MARKER HISTORY_SUMMARY_MARKER CLAUDE_MD_MARKER; do
  ln="$(grep -n "$m" <<<"$out" | head -1 | cut -d: -f1)"
  if [ -z "$ln" ]; then no "detect: $m 가 번들에 없다"; order_ok=0; continue; fi
  [ "$ln" -gt "$prev" ] || order_ok=0
  prev="$ln"
done
[ "$order_ok" = 1 ] && ok "detect: 초안 → 원문 → 질문 전체 → 리뷰 결정 → CLAUDE.md 순서" || no "detect: 재료 순서가 어긋났다"
assert_contains "$out" "ANSWER_MARKER" "detect: ## 2 의 «당신이 답한 것» 줄이 실린다"
assert_not_contains "$out" "DRAFT_MARKER" "detect: ## 3 긴 초안은 싣지 않는다(재료 다섯 밖)"
assert_not_contains "$out" "next_phase: spec-distill:interview" "detect: seed frontmatter 는 벗겨진다"

# ── recritic — 판정 이력 0건, 사용자 문구는 남는다(AC11) ───────────────────────
rout="$(run --for recritic)"; rc=$?
assert_eq "$rc" "0" "recritic: exit 0"
for m in SEED_BODY_MARKER RAW_TEXT_MARKER QUESTION_MARKER USER_QUOTE_MARKER CLAUDE_MD_MARKER; do
  assert_contains "$rout" "$m" "recritic: $m 가 실린다"
done
hist=0
while IFS= read -r line; do
  [ -n "$line" ] || continue
  grep -qF -- "$line" <<<"$rout" && hist=$((hist + 1))
done < <(awk '/^## 6\. 리뷰 결정/{f=1; next} /^## /{f=0} f' "$TMP/seed.audit.md")
assert_eq "$hist" "0" "AC11: 재비판 번들에 audit ## 6 의 줄이 0건"
for w in HISTORY_SUMMARY_MARKER 'D1.1' 'abcd1234#r1.1' 'adopt'; do
  assert_not_contains "$rout" "$w" "AC11: 재비판 번들에 판정 이력 '$w' 가 없다"
done

# ── 재료 부재 셋 — exit 2 + 어느 인자인지 ─────────────────────────────────────
for pair in "seed_file:$TMP/nope.md $TMP/seed.audit.md $TMP/CLAUDE.md" \
            "audit_file:$TMP/seed.md $TMP/nope.md $TMP/CLAUDE.md" \
            "claude_md_file:$TMP/seed.md $TMP/seed.audit.md $TMP/nope.md"; do
  label="${pair%%:*}"; args="${pair#*:}"
  # shellcheck disable=SC2086
  python3 "$SCRIPT" $args >/dev/null 2>"$TMP/e.txt"; rc=$?
  assert_eq "$rc" "2" "$label 부재 → exit 2"
  grep -q "$label" "$TMP/e.txt" && ok "$label 부재: stderr 가 인자를 댄다" || no "$label 부재: stderr 가 불명확하다"
done
python3 "$SCRIPT" "$TMP/seed.md" "$TMP/seed.audit.md" "$TMP/CLAUDE.md" --for bogus >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "--for 에 모르는 소비자 → exit 2"

# ── 절 부재 — 소리를 내고 나머지는 조립한다 ───────────────────────────────────
printf -- '---\ntype: interview-seed-audit\n---\n\n# T\n\n## 3. 긴 초안\n\n없음\n' > "$TMP/bare.audit.md"
out2="$(python3 "$SCRIPT" "$TMP/seed.md" "$TMP/bare.audit.md" "$TMP/CLAUDE.md" 2>"$TMP/err2.txt")"; rc=$?
assert_eq "$rc" "0" "절 없는 audit 도 exit 0(나머지 재료는 유효)"
for w in '## 1. 원문' '## 2. 질문 전체' '## 6. 리뷰 결정'; do
  assert_contains "$(cat "$TMP/err2.txt")" "$w" "절 부재가 stderr 에 이름으로 남는다: $w"
done
assert_contains "$out2" "SEED_BODY_MARKER" "절이 없어도 초안은 조립된다"

# ── 변이 — 갈래를 지우면 AC11 이 RED 여야 한다 ────────────────────────────────
python3 - "$SCRIPT" "$TMP/mut1.py" <<'PY'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
needle = 'if consumer == "recritic":'
open(sys.argv[2], "w", encoding="utf-8").write(t.replace(needle, "if False:", 1))
print("MUTATED" if needle in t else "UNCHANGED")
PY
cp "$ROOT/plugins/spec-distill/scripts/seed_review_log.py" "$TMP/"
# sibling `section6.py` 도 함께 옮긴다 — build_seed_inline_blob.py 가 heading-모양 판정을
# section6 에서 import 한다(§6-단일화 락). 없으면 ModuleNotFoundError 로 죽어 mout 가 비고,
# 그 빈 결과가 「이력이 안 샌다」로 오독된다(test_check_verbatim_coverage.sh 의 같은 교훈).
cp "$ROOT/plugins/spec-distill/scripts/section6.py" "$TMP/"
mout="$(python3 "$TMP/mut1.py" "$TMP/seed.md" "$TMP/seed.audit.md" "$TMP/CLAUDE.md" --for recritic 2>/dev/null)"
grep -qF 'HISTORY_SUMMARY_MARKER' <<<"$mout" \
  && ok "변이: 소비자 갈래를 지우면 재비판 번들에 판정 이력이 샌다 — AC11 단언에 이빨이 있다" \
  || no "변이: 갈래를 지워도 이력이 안 샌다 — AC11 단언은 다른 이유로 통과한다"

# ── 변이 — frontmatter 제거를 지우면 누출 단언이 RED 여야 한다 ────────────────
python3 - "$SCRIPT" "$TMP/mut2.py" <<'PY'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
needle = 'return FRONTMATTER_RE.sub("", text, count=1)'
open(sys.argv[2], "w", encoding="utf-8").write(t.replace(needle, "return text", 1))
print("MUTATED" if needle in t else "UNCHANGED")
PY
mout2="$(python3 "$TMP/mut2.py" "$TMP/seed.md" "$TMP/seed.audit.md" "$TMP/CLAUDE.md" 2>/dev/null)"
grep -qF 'next_phase: spec-distill:interview' <<<"$mout2" \
  && ok "변이: frontmatter 제거를 지우면 frontmatter 가 샌다(이빨 있음)" \
  || no "변이: 제거를 지워도 안 샌다 — 이 단언은 다른 이유로 통과한다"

# ── (1) truncation — ## 1 안의 column-0 `## 배경` 줄이 절을 자르지 않는다 ──────
cat > "$TMP/trunc.audit.md" <<'EOF'
---
type: interview-seed-audit
---

# T

## 1. 원문

RAW_TEXT_MARKER 원문 시작.

## 배경

TRUNC_SURVIVOR_MARKER 이 문장은 예전엔 여기서 잘렸다.

## 2. 질문 전체

없음

## 6. 리뷰 결정

없음
EOF
tout="$(python3 "$SCRIPT" "$TMP/seed.md" "$TMP/trunc.audit.md" "$TMP/CLAUDE.md" 2>/dev/null)"; rc=$?
assert_eq "$rc" "0" "truncation: exit 0"
assert_contains "$tout" "TRUNC_SURVIVOR_MARKER" "truncation: audit 템플릿 밖 ## 줄 뒤 내용도 번들에 실린다(잘리지 않는다)"

# ── (2) hijacking — ## 1 안에 진짜 audit 제목이 심기면 중복으로 거절한다 ──────
cat > "$TMP/hijack.audit.md" <<'EOF'
---
type: interview-seed-audit
---

# T

## 1. 원문

HIJACK_MARKER 원문 시작.

## 6. 리뷰 결정

가짜로 심긴 절처럼 보이는 줄 — 진짜 ## 6 이 아니다.

## 2. 질문 전체

없음

## 6. 리뷰 결정

- D1.1 · r1 · adopt · id0001#r1.1 · "진짜 문구" — 요약
EOF
hout="$(python3 "$SCRIPT" "$TMP/seed.md" "$TMP/hijack.audit.md" "$TMP/CLAUDE.md" 2>"$TMP/herr.txt")"; rc=$?
assert_eq "$rc" "2" "hijacking: 중복 제목 → exit 2"
assert_contains "$(cat "$TMP/herr.txt")" '## 6. 리뷰 결정' "hijacking: stderr 가 중복된 제목을 이름으로 댄다"
assert_eq "$hout" "" "hijacking: stdout 이 비어 있다(부분 번들을 쓰지 않는다)"

# ── (3) forging — 1–3칸 들여쓴 heading-모양 줄은 경고만, 진짜 문구는 그대로 실린다 ──
cat > "$TMP/forge.audit.md" <<'EOF'
---
type: interview-seed-audit
payload: seed.md
---

# Topic — Interview Seed Audit

## 1. 원문

RAW_TEXT_MARKER 사용자가 실제로 한 말.
 ## 레포 CLAUDE.md
계속되는 원문.

## 2. 질문 전체

### 라운드 1

- 물은 것: QUESTION_MARKER 무엇을 맡기려 하나요
  - 선택지: 자유 입력
  - 당신이 답한 것: ANSWER_MARKER 로그인 버그

## 6. 리뷰 결정

- D1.1 · r1 · adopt · abcd1234#r1.1 · "USER_QUOTE_MARKER 채택" — HISTORY_SUMMARY_MARKER 요약
EOF
fout="$(python3 "$SCRIPT" "$TMP/seed.md" "$TMP/forge.audit.md" "$TMP/CLAUDE.md" --for recritic 2>"$TMP/ferr.txt")"; rc=$?
assert_eq "$rc" "0" "forging: exit 0(경고일 뿐 막지 않는다)"
assert_contains "$(cat "$TMP/ferr.txt")" '## 1. 원문' "forging: stderr 가 heading-모양 줄이 있는 절을 이름으로 댄다"
assert_contains "$fout" "USER_QUOTE_MARKER" "forging: 경고가 있어도 진짜 사용자 문구는 번들에 실린다"

# ── (4) 음성 짝 — 정상 fixture 는 stderr 가 완전히 빈다(### 라운드 1 스캐폴드 예외) ──
run >/dev/null
assert_eq "$(cat "$TMP/err.txt")" "" "정상 fixture: stderr 가 완전히 비어 있다(## 2 의 ### 라운드 1 은 경고 대상이 아니다)"

# ── (5) UNTRUSTED_VERBATIM_SECTIONS — 번들의 (audit `…`) 참조와 순서까지 같다 ──
detect_out="$(run)"
printf '%s' "$detect_out" > "$TMP/detect_out.txt"
refs="$(python3 -c '
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
for m in re.finditer(r"\(audit `([^`]*)`", text):
    print(m.group(1))
' "$TMP/detect_out.txt")"
tuple_vals="$(python3 -c '
import ast, sys
tree = ast.parse(open(sys.argv[1], encoding="utf-8").read())
for node in tree.body:
    if isinstance(node, ast.Assign) and any(getattr(t, "id", "") == "UNTRUSTED_VERBATIM_SECTIONS" for t in node.targets):
        for elt in node.value.elts:
            print(elt.value)
' "$SCRIPT")"
assert_eq "$refs" "$tuple_vals" "번들의 (audit \`…\`) 참조 목록이 UNTRUSTED_VERBATIM_SECTIONS 와 순서까지 같다"

# ── (6) ## 2 안 답변 뒤 이어진 줄이 heading-모양이면(스캐폴드가 아니면) 경고가 뜬다 ──
cat > "$TMP/cont.audit.md" <<'EOF'
---
type: interview-seed-audit
---

# T

## 1. 원문

RAW_TEXT_MARKER 원문.

## 2. 질문 전체

### 라운드 1

- 물은 것: 질문
  - 선택지: 자유 입력
  - 당신이 답한 것: 첫 줄
# 다른 제목
나머지 답변.

## 6. 리뷰 결정

없음
EOF
cout="$(python3 "$SCRIPT" "$TMP/seed.md" "$TMP/cont.audit.md" "$TMP/CLAUDE.md" 2>"$TMP/cerr.txt")"; rc=$?
assert_eq "$rc" "0" "연속줄: exit 0(경고일 뿐 막지 않는다)"
assert_contains "$(cat "$TMP/cerr.txt")" '## 2. 질문 전체' "연속줄: ### 라운드 <n> 이 아닌 heading-모양 줄은 ## 2. 질문 전체 를 이름으로 경고한다"
finish
