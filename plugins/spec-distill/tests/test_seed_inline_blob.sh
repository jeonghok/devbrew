#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/build_seed_inline_blob.py plugins/spec-distill/scripts/seed_review_log.py
#
# build_seed_inline_blob.py 를 실행으로 잰다. 이 조립기가 seed 리뷰 번들의 유일한 산출자다 —
# 소비자는 framing-requests/SKILL.md 의 「### 번들」 블록이고, 그 블록이 만든 두 번들을 탐지
# 리뷰어 · codex 러너(detect)와 재비판자(recritic)가 나눠 읽는다.
#
# 재는 것: 재료 다섯의 실림과 순서 · seed frontmatter 제거 · 재료별 부재 exit 2 · 절 부재의
# 소리 · **재비판 번들에 `## 6` 의 판정 이력 줄이 0건**(AC11) · 두 변이(갈래를 지우면 AC11 이 RED,
# frontmatter 제거를 지우면 누출 단언이 RED).
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
finish
