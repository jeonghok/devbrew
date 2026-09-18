#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/seed_provenance.py plugins/spec-distill/scripts/seed_review_log.py
#
# seed_provenance.py 를 실행으로 잰다.
#   marks    — 압축이 손댄 문장에서 «(사용자 확인)» 이 떨어지고, 글자 그대로 남은 문장에서는 유지된다(AC13).
#              비교 단위: 공백 정규화 후 문장 단위로 정확히 같아야(부분 문자열이 아니다) · 마크업 포함.
#              audit 을 못 읽거나 못 믿으면(중복 제목 · 절 누락) 판단을 거부한다(rc 2, 위반이 아니다).
#   classify — 사용자 원문 그대로의 문장은 확인 표시 없이도 사용자 출처(미확인), 저자 문장은 저자 출처,
#              audit 을 못 읽으면 전부 저자 · 미확인으로 떨어지고 그 사실을 밝힌다(설계 §10-4).
#
# fix round 1: Important #1(부분 문자열이 아니라 문장 단위 일치) · #2(audit 중복 제목 · 절 누락은
# «읽었다»가 아니다) · 폴드된 사소한 것 셋(비ok audit 에서 --fix 거부 · UnicodeError 도 입력
# 오류 · --fix 결과 바이트 단위 대조).
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

# --fix 결과를 바이트 단위로 대조한다 — 원본에서 무효한 표시(뒤 셋)만 정확히 지운 파일과 같아야 한다.
python3 - "$TMP/s.orig.md" "$TMP/expected_fixed.md" <<'PY'
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
pat = re.compile(re.escape(" (사용자 확인)"))
seen = []
def repl(m):
    seen.append(1)
    return m.group(0) if len(seen) == 1 else ""
open(sys.argv[2], "w", encoding="utf-8").write(pat.sub(repl, t))
PY
assert_eq "$(cmp -s "$TMP/s.md" "$TMP/expected_fixed.md" && echo same)" "same" "marks --fix: 결과가 «첫 표시만 남기고 나머지 지운» 기대 파일과 바이트 단위로 같다"

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

# ── marks — audit 을 못 읽으면 판단을 거부한다(못 읽음 ≠ 위반) ───────────────
cp "$TMP/s.orig.md" "$TMP/s2.md"
python3 "$P" marks "$TMP/s2.md" "$TMP/none.md" > "$TMP/m3.json" 2> "$TMP/m3.err"; rc=$?
assert_eq "$rc" "2" "marks(audit 부재, --fix 없음): 판단할 수 없다 → rc 2(위반이 아니다)"
assert_eq "$(cat "$TMP/m3.json")" "" "marks(audit 못 믿음): stdout 은 비어 있다"
assert_contains "$(cat "$TMP/m3.err")" "[spec-distill]" "marks(audit 못 믿음): stderr 에 표준 접두사"
assert_eq "$(cmp -s "$TMP/s2.md" "$TMP/s.orig.md" && echo same)" "same" "marks(audit 부재, --fix 없음)는 seed 를 바꾸지 않는다"

# ── marks --fix — audit 이 not ok 면 --fix 도 거부한다(쓰지 않는다) ─────────
cp "$TMP/s.orig.md" "$TMP/s5.md"
python3 "$P" marks "$TMP/s5.md" "$TMP/none.md" --fix > "$TMP/m5.json" 2> "$TMP/m5.err"; rc=$?
assert_eq "$rc" "2" "marks --fix(audit 못 믿음): rc 2"
assert_eq "$(cmp -s "$TMP/s5.md" "$TMP/s.orig.md" && echo same)" "same" "marks --fix(audit 못 믿음): seed 를 건드리지 않는다"
assert_contains "$(cat "$TMP/m5.err")" "[spec-distill]" "marks --fix(audit 못 믿음): stderr 에 표준 접두사"

# ── 문장 단위 일치 — 부분 문자열이 아니다(fix round 1 Important #1) ─────────
cat > "$TMP/b.audit.md" <<'EOF'
---
type: interview-seed-audit
---

## 1. 원문

관리자 계정에서만 2FA 를 끈다.

로그인이 가끔 실패한다
세션 문제는 나중에

## 2. 질문 전체

### 라운드 1

- 확인 질문: 라운드 1
  - 내가 읽은 것: 「관리자 계정에서만 2FA 를 끈다.」 — 고름
  - 내가 읽은 것: 「A 를 한다. B 는 하지 않는다.」 — 고름
EOF
cat > "$TMP/b1.md" <<'EOF'
---
type: interview-seed
next_phase: spec-distill:interview
audit_file: b.audit.md
---

2FA 를 끈다. (사용자 확인)

B 는 하지 않는다. (사용자 확인)
EOF
python3 "$P" marks "$TMP/b1.md" "$TMP/b.audit.md" > "$TMP/b1.json"; rc=$?
assert_eq "$rc" "1" "문장 단위: 풀이 앞부분이 잘려 나간 표시는 무효(부분 문자열이던 시절의 버그)"
assert_eq "$(j "$TMP/b1.json" 'd["invalid"]')" "['2FA 를 끈다.']" "문장 단위: 「관리자 계정에서만 2FA 를 끈다.」 의 뒷부분만 남은 문장은 무효 — 전체와 같지 않다"
assert_not_contains "$(j "$TMP/b1.json" 'd["invalid"]')" "B 는 하지 않는다." "문장 단위: 두 문장짜리 풀이의 둘째 문장이 통째로 남으면 유효(경계를 문장으로 잰다)"

cat > "$TMP/b2.md" <<'EOF'
---
type: interview-seed
next_phase: spec-distill:interview
audit_file: b.audit.md
---

2FA 를 끈다.

로그인이 가끔 실패한다
EOF
python3 "$P" classify "$TMP/b2.md" --audit "$TMP/b.audit.md" > "$TMP/b2.json"; rc=$?
assert_eq "$rc" "0" "classify(문장 단위) rc 0"
cls2() { j "$TMP/b2.json" "[(s['provenance'], s['basis']) for s in d['sentences'] if s['text'] == '$1'][0]"; }
assert_eq "$(cls2 '2FA 를 끈다.')" "('author', 'none')" "classify: ## 1 문장의 일부만 같은 문장은 저자 출처(부분 문자열이던 시절엔 사용자로 잘못 판정)"
assert_eq "$(cls2 '로그인이 가끔 실패한다')" "('user', 'verbatim')" "classify: 종결부호 없는 ## 1 줄도 그 줄 하나가 seed 문장과 같으면 사용자 원문"

# Task 11 이 의존하는 정확한 경계 — 문단 안에서 두 문장으로 갈린다.
cat > "$TMP/e.audit.md" <<'EOF'
---
type: interview-seed-audit
---

## 1. 원문

나는 경합을 의심하는데 확신은 없다.

## 2. 질문 전체

### 라운드 1

- 확인 질문: 라운드 1
  - 내가 읽은 것: 「자리표시자」 — 고르지 않음
EOF
cat > "$TMP/e.md" <<'EOF'
---
type: interview-seed
next_phase: spec-distill:interview
audit_file: e.audit.md
---

나는 경합을 의심하는데 확신은 없다. 로그인 화면으로 되돌아간다.
EOF
python3 "$P" classify "$TMP/e.md" --audit "$TMP/e.audit.md" > "$TMP/e.json"
cls3() { j "$TMP/e.json" "[(s['provenance'], s['confirmed']) for s in d['sentences'] if s['text'].startswith('$1')][0]"; }
assert_eq "$(cls3 '나는 경합을')" "('user', False)" "Task 11 경계: ## 1 과 같은 첫 문장은 사용자 출처"
assert_eq "$(cls3 '로그인 화면으로')" "('author', False)" "Task 11 경계: 이어 붙인 둘째 문장은 저자 출처 — 문장 경계가 갈랐다"

# ── audit 이 «읽혔다» 가 «믿을 수 있다» 는 아니다(fix round 1 Important #2) ──
cat > "$TMP/f.audit.md" <<'EOF'
---
type: interview-seed-audit
---

## 1. 원문

사용자가 이렇게 말했다:
## 2. 질문 전체
을 확인해 달라고 했다.

## 2. 질문 전체

### 라운드 1

- 확인 질문: 라운드 1
  - 내가 읽은 것: 「무엇이든」 — 고름
EOF
cat > "$TMP/f.md" <<'EOF'
---
type: interview-seed
next_phase: spec-distill:interview
audit_file: f.audit.md
---

문장 하나. (사용자 확인)
EOF
cp "$TMP/f.md" "$TMP/f.orig.md"
python3 "$P" classify "$TMP/f.md" --audit "$TMP/f.audit.md" > "$TMP/f1.json"
assert_contains "$(j "$TMP/f1.json" 'd["audit"]')" "duplicate_heading" "심겨진 «## 2» 줄로 제목이 중복되면 unavailable — ok 가 아니다(침묵한 오판 금지)"
python3 "$P" marks "$TMP/f.md" "$TMP/f.audit.md" > /dev/null 2> "$TMP/f2.err"; rc=$?
assert_eq "$rc" "2" "중복 제목 audit: marks 는 판단을 거부한다"
python3 "$P" marks "$TMP/f.md" "$TMP/f.audit.md" --fix > /dev/null 2> "$TMP/f3.err"; rc=$?
assert_eq "$rc" "2" "중복 제목 audit: --fix 도 거부한다"
assert_eq "$(cmp -s "$TMP/f.md" "$TMP/f.orig.md" && echo same)" "same" "중복 제목 audit: --fix 가 거부됐으니 seed 는 그대로다"

cat > "$TMP/g.audit.md" <<'EOF'
---
type: interview-seed-audit
---

## 1. 원문

아무 문장.
EOF
python3 "$P" classify "$TMP/f.md" --audit "$TMP/g.audit.md" > "$TMP/g1.json"
assert_contains "$(j "$TMP/g1.json" 'd["audit"]')" "section_missing" "## 2 절이 없는 audit 은 unavailable — 전부 못 읽은 것과 같다"

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
