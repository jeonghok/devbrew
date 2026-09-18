#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/seed_provenance.py plugins/spec-distill/scripts/seed_review_log.py
#
# seed_provenance.py 를 실행으로 잰다.
#   marks    — 압축이 손댄 문장에서 «(사용자 확인)» 이 떨어지고, 글자 그대로 남은 문장에서는 유지된다(AC13).
#              비교 단위: 공백 정규화 후 글자 그대로 · 마크업 포함(설계 Deferred §5.2 → 계획).
#   classify — 사용자 원문 그대로의 문장은 확인 표시 없이도 사용자 출처(미확인), 저자 문장은 저자 출처,
#              audit 을 못 읽으면 전부 저자 · 미확인으로 떨어지고 그 사실을 밝힌다(설계 §10-4).
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/scripts/seed_provenance.py"
  echo "plugins/spec-distill/scripts/seed_review_log.py"
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
P="$ROOT/plugins/spec-distill/scripts/seed_provenance.py"
TMP="$(mktemp -d -t sd-seed-prov-XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT
test -f "$P" || { no "부재: $P"; finish; exit; }
j() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); print(eval(sys.argv[2]))' "$1" "$2"; }

cat > "$TMP/a.audit.md" <<'EOF'
---
type: interview-seed-audit
---

## 1. 원문

나는 클라이언트 쪽 경합을 의심하는데 확신은 없다.

## 2. 질문 전체

### 라운드 1

- 물은 것: 무엇을 하지 않나요
  - 선택지: 자유 입력
  - 당신이 답한 것: 세션 스토어는 다음 분기
- 확인 질문: 라운드 1
  - 내가 읽은 것: 「세션 스토어 개편은 이번에 하지 않는다 — 다음 분기에 따로 한다.」 — 고름
  - 내가 읽은 것: 「경합이 원인이다.」 — 고르지 않음
  - 내가 읽은 것: 「`src/auth/` 안에서만 본다.」 — 고름
EOF
cat > "$TMP/s.md" <<'EOF'
---
type: interview-seed
next_phase: spec-distill:interview
audit_file: s.audit.md
---

로그인이 가끔 실패한다. 세션 스토어 개편은 이번에 하지 않는다 —
다음 분기에 따로 한다. (사용자 확인)

세션 스토어는 이번에 바꾸지 않는다. (사용자 확인)

경합이 원인이다. (사용자 확인)

src/auth/ 안에서만 본다. (사용자 확인)

나는 클라이언트 쪽 경합을 의심하는데 확신은 없다.

다시 검증할 것 — 경합은 의심이다.
EOF
cp "$TMP/s.md" "$TMP/s.orig.md"

# ── marks — 검사만 ───────────────────────────────────────────────────────────
python3 "$P" marks "$TMP/s.md" "$TMP/a.audit.md" > "$TMP/m1.json"; rc=$?
assert_eq "$rc" "1" "marks: 근거 없는 표시가 있으면 rc 1"
assert_eq "$(j "$TMP/m1.json" 'd["marked"], len(d["invalid"])')" "(4, 3)" "marks: 표시 넷 중 셋이 근거 없음"
assert_contains "$(j "$TMP/m1.json" 'd["invalid"]')" "세션 스토어는 이번에 바꾸지 않는다." "압축이 고친 문장 — 확인이 따라가지 않는다(AC13)"
assert_contains "$(j "$TMP/m1.json" 'd["invalid"]')" "경합이 원인이다." "고르지 않은 풀이 — 확인이 아니다(양의 선택)"
assert_contains "$(j "$TMP/m1.json" 'd["invalid"]')" "src/auth/ 안에서만 본다." "마크업을 벗긴 문장 — 글자 그대로가 아니다(비교 단위: 마크업 포함)"
assert_eq "$(cmp -s "$TMP/s.md" "$TMP/s.orig.md" && echo same)" "same" "marks(검사만)는 seed 를 바꾸지 않는다"

# ── marks --fix — 근거 없는 표시만 뗀다 ──────────────────────────────────────
python3 "$P" marks "$TMP/s.md" "$TMP/a.audit.md" --fix > "$TMP/m2.json"; rc=$?
assert_eq "$rc" "0" "marks --fix: rc 0"
body="$(cat "$TMP/s.md")"
assert_contains "$body" "다음 분기에 따로 한다. (사용자 확인)" "AC13 양성: 줄바꿈으로 감싼 채 글자 그대로 남은 문장은 표시가 유지된다(공백 정규화)"
assert_not_contains "$body" "바꾸지 않는다. (사용자 확인)" "AC13: 압축이 고친 문장의 표시가 떨어졌다"
assert_not_contains "$body" "경합이 원인이다. (사용자 확인)" "고르지 않은 풀이의 표시가 떨어졌다"
assert_contains "$body" "세션 스토어는 이번에 바꾸지 않는다." "표시만 떼고 문장은 남는다"
assert_eq "$(head -5 "$TMP/s.md")" "$(head -5 "$TMP/s.orig.md")" "frontmatter 는 그대로다"
python3 "$P" marks "$TMP/s.md" "$TMP/a.audit.md" > /dev/null; rc=$?
assert_eq "$rc" "0" "marks: 뗀 뒤에는 통과(멱등)"

# ── classify — 출처와 확인의 두 축 ───────────────────────────────────────────
python3 "$P" classify "$TMP/s.md" --audit "$TMP/a.audit.md" > "$TMP/c1.json"; rc=$?
assert_eq "$rc" "0" "classify rc 0"
cls() { j "$TMP/c1.json" "[(s['provenance'], s['confirmed'], s['basis']) for s in d['sentences'] if s['text'].startswith('$1')][0]"; }
assert_eq "$(cls '세션 스토어 개편은')" "('user', True, 'confirmed_reading')" "확인된 풀이 → 사용자 출처 · 확인"
assert_eq "$(cls '나는 클라이언트')" "('user', False, 'verbatim')" "사용자 원문 그대로 → 사용자 출처 · 미확인(표시 없이도)"
assert_eq "$(cls '로그인이 가끔')" "('author', False, 'none')" "그 밖의 저자 문장 → 저자 출처 · 미확인"
assert_eq "$(cls '다시 검증할 것')" "('author', False, 'reverify_paragraph')" "«다시 검증할 것 —» 문단 → 저자 출처"
assert_eq "$(j "$TMP/c1.json" 'd["audit"]')" "ok" "audit 을 읽었다고 밝힌다"

# ── classify — audit 을 못 읽으면 보수적으로 ─────────────────────────────────
python3 "$P" classify "$TMP/s.md" --audit "$TMP/none.md" > "$TMP/c2.json"; rc=$?
assert_eq "$rc" "0" "classify(audit 부재) rc 0"
assert_contains "$(j "$TMP/c2.json" 'd["audit"]')" "unavailable" "audit 부재를 밝힌다(침묵하지 않는다)"
assert_eq "$(j "$TMP/c2.json" 'sorted({(s["provenance"], s["confirmed"]) for s in d["sentences"]})')" "[('author', False)]" "audit 부재 → 전부 저자 · 미확인"
python3 "$P" classify "$TMP/s.md" > "$TMP/c3.json"
assert_contains "$(j "$TMP/c3.json" 'd["audit"]')" "unavailable" "--audit 없이 불러도 같은 보수적 결과"

# ── marks — audit 을 못 읽으면 표시는 전부 근거 없음 ─────────────────────────
cp "$TMP/s.orig.md" "$TMP/s2.md"
python3 "$P" marks "$TMP/s2.md" "$TMP/none.md" > "$TMP/m3.json"; rc=$?
assert_eq "$rc" "1" "marks(audit 부재): 표시 넷 다 근거 없음 → rc 1"
assert_eq "$(j "$TMP/m3.json" 'len(d["invalid"])')" "4" "marks(audit 부재): 넷 다 무효"

# ── 변이 — 공백 정규화를 지우면 줄바꿈 문장이 떨어져야 한다 ─────────────────
python3 - "$P" "$TMP/mut.py" <<'PY'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
needle = 's = re.sub(r"\\s+", " ", s).strip()'
open(sys.argv[2], "w", encoding="utf-8").write(t.replace(needle, "s = s.strip()", 1))
print("MUTATED" if needle in t else "UNCHANGED")
PY
cp "$ROOT/plugins/spec-distill/scripts/seed_review_log.py" "$TMP/"
cp "$TMP/s.orig.md" "$TMP/s3.md"
python3 "$TMP/mut.py" marks "$TMP/s3.md" "$TMP/a.audit.md" > "$TMP/m4.json" 2>/dev/null
[ "$(j "$TMP/m4.json" 'len(d["invalid"])' 2>/dev/null)" = "4" ] \
  && ok "변이: 공백 정규화를 지우면 줄바꿈으로 감싼 확인 문장까지 떨어진다 — 비교 단위 단언에 이빨이 있다" \
  || no "변이: 정규화를 지워도 결과가 같다 — 비교 단위 단언은 다른 이유로 통과한다"
finish
