#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/seed_review_log.py plugins/spec-distill/templates/interview-seed-audit-template.md plugins/spec-distill/references/docreview-profiles/seed.md shared/docreview/scripts/docreview_state.py shared/docreview/scripts/docreview_route.py shared/docreview/scripts/docreview_anchor.py
#
# seed_review_log.py 를 실행으로 잰다 — 문구 추출 · 문구 없는 drop 검사(AC12 — 양성 대조 포함) ·
# 기록 쓰기 · verbatim 옮기기. 끝에 **엔진 왕복**: 실제 엔진이 audit 에 쓴 줄을 이 파서가 읽는가.
# 이 모듈은 엔진의 결정 기록 줄 모양에 결합돼 있다 — 그 결합이 깨질 때 소리를 내는 곳이 여기다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/scripts/seed_review_log.py"
  echo "plugins/spec-distill/templates/interview-seed-audit-template.md"
  echo "plugins/spec-distill/references/docreview-profiles/seed.md"
  echo "shared/docreview/scripts/docreview_state.py"
  echo "shared/docreview/scripts/docreview_route.py"
  echo "shared/docreview/scripts/docreview_anchor.py"
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
S="$ROOT/plugins/spec-distill/scripts"
L="$S/seed_review_log.py"
TPL="$ROOT/plugins/spec-distill/templates/interview-seed-audit-template.md"
PROF="$ROOT/plugins/spec-distill/references/docreview-profiles/seed.md"
TMP="$(mktemp -d -t sd-seed-log-XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT
test -f "$L" || { no "부재: $L"; finish; exit; }

# ── AUDIT_HEADINGS — 여섯 제목이 템플릿의 '## N.' 줄에서 도출된다, 순서까지 ──
tpl_headings="$(grep '^## ' "$TPL")"
py_headings="$(PYTHONPATH="$S" python3 -c '
import seed_review_log as m
for h in m.AUDIT_HEADINGS:
    print(h)
')"
assert_eq "$py_headings" "$tpl_headings" "AUDIT_HEADINGS: seed_review_log 의 여섯 제목이 템플릿의 '## N.' 줄과 순서까지 같다"

# ── ## 2 스캐폴드 — 템플릿이 실제로 '### 라운드 <n>' 줄을 쓰는가. build_seed_inline_blob.py 의
# ROUND_SCAFFOLD_RE 예외(heading-모양 경고에서 이 줄만 뺀다)가 근거로 삼는 사실이다 — 템플릿이
# 이 줄을 바꾸면 예외의 근거가 조용히 사라지지 않게 여기서 묶는다.
grep -qxF '### 라운드 <n>' "$TPL" \
  && ok "템플릿 ## 2 안에 '### 라운드 <n>' 스캐폴드 줄이 있다(heading-모양 경고 예외의 근거)" \
  || no "템플릿에 '### 라운드 <n>' 줄이 없다 — ROUND_SCAFFOLD_RE 예외의 근거가 사라졌다"

AUD="$TMP/a.audit.md"
cat > "$AUD" <<'EOF'
---
type: interview-seed-audit
---

# T

## 4. 비평과 냉독

(설명)

## 5. degrade

없음

## 6. 리뷰 결정

- D1.1 · r1 · adopt · aaaa0001#r1.1 · "채택 (권장) [게이트 선택지 라벨]" — SUMMARY_A 요약
- D1.2 · r1 · drop · bbbb0001#r1.1 · "QUOTE_DROP 적용하지 않음" — SUMMARY_B 요약
- D1.3 · r1 · drop · cccc0001#r1.1 · "" — SUMMARY_C 요약
- D2.4 · r2 · reject · aaaa0001#r2.1 · "QUOTE_REJECT" · supersedes D1.1 — SUMMARY_D 요약
- 편집 · r2 · 덩어리 1 · 그대로 둔다 · "QUOTE_EDIT" — 3–4행
- 답 · r2 · dddd0001#r2.1 · "QUOTE_ANSWER" — SUMMARY_E 요약
EOF

# ── user-quotes — 문구만, 판정 이력 없이 ──────────────────────────────────────
q="$(python3 "$L" user-quotes "$AUD")"; rc=$?
assert_eq "$rc" "0" "user-quotes rc 0"
for w in QUOTE_DROP QUOTE_REJECT QUOTE_EDIT QUOTE_ANSWER '채택 (권장)'; do
  assert_contains "$q" "$w" "user-quotes: 사용자 문구 '$w' 를 싣는다"
done
for w in SUMMARY_ 'D1.1' 'aaaa0001#r1.1' ' adopt ' 'supersedes'; do
  assert_not_contains "$q" "$w" "user-quotes: 판정 이력 '$w' 를 싣지 않는다"
done
assert_eq "$(printf '%s\n' "$q" | grep -c .)" "5" "user-quotes: 빈 문구는 싣지 않는다(다섯 줄)"

# ── check-drops — 양성 대조와 두 위반 ─────────────────────────────────────────
chk() { printf '%s' "$1" > "$TMP/g.json"; python3 "$L" check-drops "$2" "$TMP/g.json" > "$TMP/cd.out" 2>&1; echo $?; }
assert_eq "$(chk '{"dropped": ["bbbb0001#r1.1"]}' "$AUD")" "0" "check-drops 양성 대조: 문구 있는 drop 은 통과한다"
assert_eq "$(chk '{"dropped": ["cccc0001#r1.1"]}' "$AUD")" "1" "check-drops: 문구가 빈 drop 은 막는다"
assert_contains "$(cat "$TMP/cd.out")" "empty_quote" "check-drops: 사유 empty_quote"
assert_eq "$(chk '{"dropped": ["eeee0001#r1.1"]}' "$AUD")" "1" "check-drops: 기록 줄이 없는 drop 은 막는다"
assert_contains "$(cat "$TMP/cd.out")" "no_log_line" "check-drops: 사유 no_log_line"
assert_eq "$(chk '{"dropped": []}' "$AUD")" "0" "check-drops: drop 이 없으면 통과"
assert_eq "$(chk '{not json' "$AUD")" "2" "check-drops: 요약을 못 읽으면 rc 2(통과가 아니다)"
printf -- '---\nx: 1\n---\n\n## 5. degrade\n\n없음\n' > "$TMP/no6.md"
assert_eq "$(chk '{"dropped": ["bbbb0001#r1.1"]}' "$TMP/no6.md")" "1" "check-drops: ## 6 절이 없으면 drop 은 전부 no_log_line"
# 되돌리는 길 — 사용자에게 다시 물어 받은 문구를 `거부` 줄로 적으면 통과한다(설계 D18 의
# 「항목 / 거부 / 사용자 문구」 기록).
cp "$AUD" "$TMP/fix.audit.md"
python3 "$L" log "$TMP/fix.audit.md" --kind 거부 --round 2 --target "cccc0001#r1.1" --quote "QUOTE_REFUSE 그 지적은 반영하지 않는다" --note "다시 물어 받은 문구" >/dev/null
assert_eq "$(chk '{"dropped": ["cccc0001#r1.1"]}' "$TMP/fix.audit.md")" "0" "check-drops: 문구가 빈 drop 도 사용자 문구로 쓴 거부 줄이 있으면 통과한다"
# UTF-8 이 아닌 audit — 못 읽는 것은 위반(rc 1)이 아니라 입력 오류(rc 2)다.
printf '## 6. 리뷰 결정\n\n- \377\376 깨진 줄\n' > "$TMP/bad.audit.md"
assert_eq "$(chk '{"dropped": []}' "$TMP/bad.audit.md")" "2" "check-drops: UTF-8 이 아닌 audit 은 rc 2(위반 rc 1 이 아니다)"
assert_not_contains "$(cat "$TMP/cd.out")" "Traceback" "check-drops: UTF-8 이 아닌 audit 에 트레이스백을 내지 않는다"
assert_contains "$(cat "$TMP/cd.out")" "[spec-distill]" "check-drops: 입력 오류를 표준 접두사로 알린다"
# 엔진 요약에 dropped 목록이 없다 — 엔진이 키를 바꾸거나 빼면 «drop 0건» 으로 통과하지 않는다(AC12).
for g in '{}' '{"dropped": null}' '[]' '{"dropped": "x"}'; do
  assert_eq "$(chk "$g" "$AUD")" "2" "check-drops: 요약 $g 에 dropped 목록이 없으면 rc 2(통과가 아니다)"
  assert_contains "$(cat "$TMP/cd.out")" "gate_has_no_dropped_list" "check-drops: 요약 $g — 사유 gate_has_no_dropped_list"
done
# 템플릿 제목이 중복된 audit — 어느 ## 6 이 진짜인지 모르므로 판단하지 않는다.
printf '## 1. 원문\n\n## 6. 리뷰 결정\n\n## 6. 리뷰 결정\n\n- D1.2 · r1 · drop · bbbb0001#r1.1 · "q" — s\n' > "$TMP/dup.audit.md"
assert_eq "$(chk '{"dropped": ["bbbb0001#r1.1"]}' "$TMP/dup.audit.md")" "2" "check-drops: 템플릿 제목이 중복된 audit 은 rc 2(판단 불가)"
assert_contains "$(cat "$TMP/cd.out")" "duplicate_heading" "check-drops: 사유 duplicate_heading"

# ── log — finding 없는 처분 한 줄 ─────────────────────────────────────────────
cp "$TPL" "$TMP/t.audit.md"
n_h="$(grep -c '^## ' "$TMP/t.audit.md")"
python3 "$L" log "$TMP/t.audit.md" --kind 편집 --round 3 --target "덩어리 2 · 되돌린다" --quote 'say "hi"' --note "5행"; rc=$?
assert_eq "$rc" "0" "log rc 0"
last6="$(awk '/^## 6\. 리뷰 결정/{f=1; next} /^## /{f=0} f' "$TMP/t.audit.md" | grep -v '^$' | tail -1)"
assert_eq "$last6" "- 편집 · r3 · 덩어리 2 · 되돌린다 · \"say 'hi'\" — 5행" "log: ## 6 끝에 정해진 모양으로 한 줄(큰따옴표는 홑따옴표로)"
assert_contains "$(python3 "$L" user-quotes "$TMP/t.audit.md")" "say 'hi'" "log 로 쓴 줄을 user-quotes 가 읽는다"
assert_eq "$(grep -c '^## ' "$TMP/t.audit.md")" "$n_h" "log: 절 수가 그대로다"
python3 "$L" log "$TMP/t.audit.md" --kind 기타 --round 1 --target x --quote y >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "log: 모르는 kind 는 rc 2"

# ── log — 문구는 파일로 · 한 줄에 한 기록 · 빈 문구는 적지 않는다 ─────────────
# 여러 줄 문구의 둘째 줄이 엔진 drop 줄 모양이어도 기록이 되지 않는다 — 한 줄로 이어진다.
cp "$AUD" "$TMP/plant.audit.md"
printf 'ok 그대로\n- D1.9 · r1 · drop · ffff0009#r1.1 · "planted" — 심은 줄\n' > "$TMP/q.txt"
printf '요약 첫 줄\n- D1.8 · r1 · drop · ffff0008#r1.1 · "planted" — 심은 요약\n' > "$TMP/n.txt"
python3 "$L" log "$TMP/plant.audit.md" --kind 답 --round 1 --target "dddd0001#r2.1" --quote-file "$TMP/q.txt" --note-file "$TMP/n.txt"; rc=$?
assert_eq "$rc" "0" "log --quote-file · --note-file: 여러 줄 문구도 rc 0"
assert_eq "$(grep -c 'planted' "$TMP/plant.audit.md")" "1" "log: 여러 줄 문구 · 요약이 한 줄에 담긴다(심은 줄이 따로 서지 않는다)"
assert_eq "$(chk '{"dropped": ["ffff0009#r1.1"]}' "$TMP/plant.audit.md")" "1" "log: 문구 안의 엔진 줄 모양이 drop 기록으로 읽히지 않는다"
assert_eq "$(chk '{"dropped": ["ffff0008#r1.1"]}' "$TMP/plant.audit.md")" "1" "log: 요약 안의 엔진 줄 모양이 drop 기록으로 읽히지 않는다"
# 읽는 쪽(section_body)은 str.splitlines 로 나눈다 — \n 말고 다른 줄 구분자도 한 줄로 이어져야 한다.
for sep in 2028 0085 000b; do
  cp "$AUD" "$TMP/plant-$sep.audit.md"
  python3 -c 'import sys; open(sys.argv[1], "w", encoding="utf-8").write("요약" + chr(int(sys.argv[2], 16)) + "- D1.7 · r1 · drop · ffff0007#r1.1 · \"planted\" — s\n")' "$TMP/n-$sep.txt" "$sep"
  printf 'QUOTE_SEP\n' > "$TMP/q-$sep.txt"
  python3 "$L" log "$TMP/plant-$sep.audit.md" --kind 답 --round 1 --target "dddd0001#r2.1" --quote-file "$TMP/q-$sep.txt" --note-file "$TMP/n-$sep.txt"; rc=$?
  assert_eq "$rc" "0" "log: U+$sep 가 든 요약도 한 줄로 기록한다(rc 0)"
  assert_eq "$(chk '{"dropped": ["ffff0007#r1.1"]}' "$TMP/plant-$sep.audit.md")" "1" "log: U+$sep 뒤에 심은 엔진 줄이 drop 기록으로 읽히지 않는다"
done
assert_contains "$(grep '^- 답 · r1 · dddd0001#r2.1' "$TMP/plant.audit.md")" "ok 그대로 - D1.9" "log: 줄바꿈은 한 칸으로 이어진다"
: > "$TMP/empty.txt"
python3 "$L" log "$TMP/plant.audit.md" --kind 거부 --round 1 --target TARGET_X --quote-file "$TMP/empty.txt" >/dev/null 2>"$TMP/e.err"; rc=$?
assert_eq "$rc" "2" "log: 빈 문구 파일은 rc 2 — 문구 없는 거부 줄을 적지 않는다"
assert_contains "$(cat "$TMP/e.err")" "[spec-distill]" "log: 빈 문구를 표준 접두사로 알린다"
assert_contains "$(cat "$TMP/e.err")" "TARGET_X" "log: 빈 문구 메시지가 어느 대상인지 댄다"
assert_contains "$(cat "$TMP/e.err")" "empty.txt" "log: 빈 문구 메시지가 어느 파일인지 댄다"
# `답` · `거부` 는 대상이 finding id 라 줄이 처분을 유일하게 가리킨다 — 같은 줄은 다시 적지 않는다.
cp "$TPL" "$TMP/idem.audit.md"
printf 'QUOTE_IDEM\n' > "$TMP/idem.txt"
python3 "$L" log "$TMP/idem.audit.md" --kind 답 --round 1 --target "aaaa0001#r1.1" --quote-file "$TMP/idem.txt"; rc1=$?
python3 "$L" log "$TMP/idem.audit.md" --kind 답 --round 1 --target "aaaa0001#r1.1" --quote-file "$TMP/idem.txt" 2>"$TMP/idem.err"; rc2=$?
assert_eq "$rc1 $rc2" "0 0" "log: 같은 기록을 두 번 불러도 rc 0"
assert_eq "$(grep -c 'QUOTE_IDEM' "$TMP/idem.audit.md")" "1" "log: 답 의 같은 기록 줄은 한 번만 적힌다"
assert_contains "$(cat "$TMP/idem.err")" "이미 있다" "log: 다시 적지 않았다고 알린다"
python3 "$L" log "$TMP/idem.audit.md" --kind 거부 --round 1 --target "aaaa0001#r1.1" --quote-file "$TMP/idem.txt"
python3 "$L" log "$TMP/idem.audit.md" --kind 거부 --round 1 --target "aaaa0001#r1.1" --quote-file "$TMP/idem.txt"
assert_eq "$(grep -c 'QUOTE_IDEM' "$TMP/idem.audit.md")" "2" "log: 거부 도 같은 줄은 한 번만 적힌다(종류가 다르면 다른 줄이다)"
python3 "$L" log "$TMP/idem.audit.md" --kind 답 --round 2 --target "aaaa0001#r1.1" --quote-file "$TMP/idem.txt"
assert_eq "$(grep -c 'QUOTE_IDEM' "$TMP/idem.audit.md")" "3" "log 양의 짝: 라운드가 다르면 다른 기록이다"
# `편집` 은 다르다 — 덩어리 번호가 공시마다 1 부터 다시 시작하고 문구는 고른 라벨이라, 다른 공시의 다른
# 처분이 글자까지 같은 줄이 된다. 건너뛰면 그 처분 기록이 사라지므로 언제나 덧붙인다.
cp "$TPL" "$TMP/edit2.audit.md"
printf 'QUOTE_EDIT2\n' > "$TMP/edit2.txt"
python3 "$L" log "$TMP/edit2.audit.md" --kind 편집 --round 1 --target "덩어리 1 · 그대로 둔다" --quote-file "$TMP/edit2.txt"; rc1=$?
python3 "$L" log "$TMP/edit2.audit.md" --kind 편집 --round 1 --target "덩어리 1 · 그대로 둔다" --quote-file "$TMP/edit2.txt" 2>"$TMP/edit2.err"; rc2=$?
assert_eq "$rc1 $rc2" "0 0" "log: 편집 을 두 번 불러도 rc 0"
assert_eq "$(grep -c '^- 편집 · r1 · 덩어리 1 · 그대로 둔다 · "QUOTE_EDIT2" —$' "$TMP/edit2.audit.md")" "2" "log: 같은 라운드 두 공시의 편집 처분은 글자가 같아도 두 줄이다"
assert_not_contains "$(cat "$TMP/edit2.err")" "이미 있다" "log: 편집 에서는 같은 줄 건너뛰기를 알리지 않는다(건너뛰지 않으므로)"
# 같은 줄 판정의 코퍼스는 `## 6` 절이다 — 파일 전체면 사용자가 `## 1` 에 붙여 넣은 기록 모양 줄이
# 진짜 처분을 삼킨다(비신뢰 본문이 rc 0 과 함께 기록을 지우는 경로). 심는 줄은 손으로 적지 않고
# log 가 실제로 쓴 줄에서 도출한다 — 글자가 어긋나면 이 락은 아무것도 재지 않는다.
cp "$TPL" "$TMP/scope-src.audit.md"
printf 'QUOTE_SCOPE\n' > "$TMP/scope.txt"
python3 "$L" log "$TMP/scope-src.audit.md" --kind 답 --round 1 --target "bbbb0002#r1.1" --quote-file "$TMP/scope.txt"
host_line="$(grep -F 'QUOTE_SCOPE' "$TMP/scope-src.audit.md")"
assert_contains "$host_line" "bbbb0002#r1.1" "절 범위 전제: 심을 줄을 log 가 쓴 줄에서 도출했다"
HOST_LINE="$host_line" python3 - "$TPL" "$TMP/scope.audit.md" <<'PYS'
import os, pathlib, sys
lines = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
out = []
for line in lines:
    out.append(line)
    if line.strip() == "## 1. 원문":
        out += ["", os.environ["HOST_LINE"]]
pathlib.Path(sys.argv[2]).write_text("\n".join(out) + "\n", encoding="utf-8")
PYS
assert_eq "$(grep -c -F 'QUOTE_SCOPE' "$TMP/scope.audit.md")" "1" "절 범위 전제: 심은 줄이 ## 1 에 하나 있다"
python3 "$L" log "$TMP/scope.audit.md" --kind 답 --round 1 --target "bbbb0002#r1.1" --quote-file "$TMP/scope.txt" 2>"$TMP/scope.err"; rc=$?
assert_eq "$rc" "0" "절 범위: ## 1 에 심긴 기록 모양 줄이 있어도 rc 0"
assert_eq "$(grep -c -F 'QUOTE_SCOPE' "$TMP/scope.audit.md")" "2" "절 범위: 같은 줄 판정은 ## 6 만 본다 — 비신뢰 원문이 진짜 기록을 삼키지 않는다"
assert_not_contains "$(cat "$TMP/scope.err")" "이미 있다" "절 범위: ## 1 의 줄을 «이미 있다» 로 읽지 않는다"
python3 "$L" log "$TMP/plant.audit.md" --kind 거부 --round 1 --target x --quote-file "$TMP/nope.txt" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "log: 문구 파일이 없으면 rc 2"
python3 "$L" log "$TMP/plant.audit.md" --kind 거부 --round 1 --target x --quote a --quote-file "$TMP/q.txt" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "log: --quote 와 --quote-file 은 함께 쓰지 않는다"

# ── one-line — 엔진 --reason 처럼 인자로만 받는 자리에 넘길 한 줄 ─────────────
printf '첫 줄\n\n  둘째 줄  \n' > "$TMP/ol.txt"
assert_eq "$(python3 "$L" one-line "$TMP/ol.txt")" "첫 줄 둘째 줄" "one-line: 줄을 한 칸으로 잇고 빈 줄 · 앞뒤 공백을 걷는다"
python3 "$L" one-line "$TMP/empty.txt" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "one-line: 빈 파일은 rc 2"
printf '`touch %s/PWNED` $(touch %s/PWNED2)\n' "$TMP" "$TMP" > "$TMP/evil.txt"
( cd "$TMP" && r="$(python3 "$L" one-line "$TMP/evil.txt")" && printf '%s' "$r" > "$TMP/evil.out" )
[ ! -e "$TMP/PWNED" ] && [ ! -e "$TMP/PWNED2" ] && ok "one-line: 명령 치환의 출력 안 백틱 · \$( ) 는 다시 실행되지 않는다" \
  || no "one-line: 출력 안의 명령이 실행됐다"
assert_contains "$(cat "$TMP/evil.out")" '`touch' "one-line: 글자는 그대로 전달된다"

# ── 변이 — 한 줄 잇기를 지우면 여러 줄 문구가 기록되지 못한다(이빨) ──────────
python3 - "$L" "$TMP/mut_ol.py" <<'PY'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
needle = 'quote = one_line(quote).replace'
open(sys.argv[2], "w", encoding="utf-8").write(t.replace(needle, "quote = quote.replace", 1))
print("MUTATED" if needle in t else "UNCHANGED")
PY
cp "$AUD" "$TMP/mut.audit.md"
python3 "$TMP/mut_ol.py" log "$TMP/mut.audit.md" --kind 답 --round 1 --target t --quote-file "$TMP/q.txt" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "변이: 문구의 한 줄 잇기를 지우면 여러 줄 문구가 거부된다 — 위 rc 0 단언에 이빨이 있다"
assert_eq "$(grep -c 'planted' "$TMP/mut.audit.md")" "0" "변이: 그때도 심은 줄은 audit 에 들어가지 않는다(한 줄 검사가 두 번째 방어선)"
# 변이 — 한 줄 잇기를 \n 만으로 좁히면 U+2028 요약이 거부된다(splitlines 가 두 번째 방어선) — 잇기가 \n 밖에도 닿는다는 이빨
python3 - "$L" "$TMP/mut_sep.py" <<'PY'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
needle = 'return " ".join(part.strip() for part in s.splitlines() if part.strip())'
open(sys.argv[2], "w", encoding="utf-8").write(t.replace(needle, 'return " ".join(part.strip() for part in s.split("\\n") if part.strip())', 1))
print("MUTATED" if needle in t else "UNCHANGED")
PY
cp "$AUD" "$TMP/mut2.audit.md"
python3 "$TMP/mut_sep.py" log "$TMP/mut2.audit.md" --kind 답 --round 1 --target t --quote-file "$TMP/q-2028.txt" --note-file "$TMP/n-2028.txt" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "변이: 잇기를 \\n 으로 좁히면 U+2028 요약 기록이 거부된다 — 위 U+2028 rc 0 단언에 이빨이 있다"
# 변이 — append-verbatim 을 \n 나눔으로 되돌리면 U+2028 뒤의 템플릿 제목이 중복으로 읽힌다
python3 - "$L" "$TMP/mut_av.py" <<'PY'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
needle = 'content = _read(a.file).splitlines() or [""]'
open(sys.argv[2], "w", encoding="utf-8").write(t.replace(needle, 'content = _read(a.file).rstrip("\\n").split("\\n")', 1))
print("MUTATED" if needle in t else "UNCHANGED")
PY
cp "$TPL" "$TMP/v3.audit.md"
python3 -c 'import sys; open(sys.argv[1], "w", encoding="utf-8").write("냉독 첫 줄" + chr(0x2028) + "## 6. 리뷰 결정" + chr(0x0b) + "## 1. 원문\n")' "$TMP/sep-m.txt"
python3 "$TMP/mut_av.py" append-verbatim "$TMP/v3.audit.md" --section "## 4. 비평과 냉독" --title "냉독" "$TMP/sep-m.txt" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "변이 전제: 변이본의 append-verbatim 이 돌았다(입력 파일이 있다)"
[ "$(PYTHONPATH="$S" python3 -c 'import sys, seed_review_log as m; print(len(m.duplicate_headings(open(sys.argv[1], encoding="utf-8").read())))' "$TMP/v3.audit.md")" != "0" ] \
  && ok "변이: \\n 나눔으로 되돌리면 제목 중복이 생긴다 — 위 splitlines 단언에 이빨이 있다" \
  || no "변이: \\n 나눔으로 되돌려도 중복이 없다 — 그 단언은 다른 이유로 통과한다"

# ── append-verbatim — 인용 블록으로, 그 절 끝에 ───────────────────────────────
cp "$TPL" "$TMP/v.audit.md"
printf '## 가짜 헤딩\n내용 줄\n\n끝\n' > "$TMP/content.txt"
n_h="$(grep -c '^## ' "$TMP/v.audit.md")"
python3 "$L" append-verbatim "$TMP/v.audit.md" --section "## 4. 비평과 냉독" --title "라운드 1 — 탐지 (doc-critic)" "$TMP/content.txt"; rc=$?
assert_eq "$rc" "0" "append-verbatim rc 0"
assert_eq "$(grep -c '^## ' "$TMP/v.audit.md")" "$n_h" "append-verbatim: 내용 속 ## 가 절을 만들지 않는다(인용 블록)"
t_line="$(grep -n '^### 라운드 1 — 탐지 (doc-critic)$' "$TMP/v.audit.md" | cut -d: -f1)"
q_line="$(grep -n '^> ## 가짜 헤딩$' "$TMP/v.audit.md" | cut -d: -f1)"
n5_line="$(grep -n '^## 5\. degrade$' "$TMP/v.audit.md" | cut -d: -f1)"
n4_line="$(grep -n '^## 4\. 비평과 냉독$' "$TMP/v.audit.md" | cut -d: -f1)"
if [ -n "$t_line" ] && [ -n "$q_line" ] && [ "$n4_line" -lt "$t_line" ] && [ "$t_line" -lt "$q_line" ] && [ "$q_line" -lt "$n5_line" ]; then
  ok "append-verbatim: ## 4 와 ## 5 사이에 제목 → 인용 순서로 붙었다"
else
  no "append-verbatim: 위치가 틀렸다(## 4=$n4_line 제목=${t_line:-?} 인용=${q_line:-?} ## 5=$n5_line)"
fi
grep -qxF '>' "$TMP/v.audit.md" && ok "append-verbatim: 빈 줄도 인용 블록 안에 남는다" || no "append-verbatim: 빈 줄이 인용 블록을 끊었다"
# 줄 나눔은 읽는 쪽과 같은 str.splitlines — U+2028 뒤의 템플릿 제목이 인용 표시 없는 줄로 읽히지 않는다.
cp "$TPL" "$TMP/v2.audit.md"
python3 -c 'import sys; open(sys.argv[1], "w", encoding="utf-8").write("냉독 첫 줄" + chr(0x2028) + "## 6. 리뷰 결정" + chr(0x0b) + "## 1. 원문\n")' "$TMP/sep.txt"
python3 "$L" append-verbatim "$TMP/v2.audit.md" --section "## 4. 비평과 냉독" --title "냉독 (seed-readback)" "$TMP/sep.txt"; rc=$?
assert_eq "$rc" "0" "append-verbatim(U+2028 · U+000B): rc 0"
assert_eq "$(PYTHONPATH="$S" python3 -c 'import sys, seed_review_log as m; print(m.duplicate_headings(open(sys.argv[1], encoding="utf-8").read()))' "$TMP/v2.audit.md")" "[]" "append-verbatim: 다른 줄 구분자 뒤의 템플릿 제목도 인용 블록 안에 남는다(제목 중복 0)"

# ── 엔진 왕복 — 엔진이 쓴 줄을 이 파서가 읽는가 ───────────────────────────────
printf -- '---\ntype: interview-seed\n---\n\n로그인이 가끔 실패한다.\n' > "$TMP/s.md"
cp "$TPL" "$TMP/rt.audit.md"
D="$TMP/rt-state"; mkdir -p "$D"
python3 "$S/docreview_state.py" init --state-dir "$D" --doc "$TMP/s.md" --profile "$PROF" >/dev/null
python3 "$S/docreview_anchor.py" snapshot "$TMP/s.md" > "$D/snap.json"
python3 "$S/docreview_state.py" begin-round --state-dir "$D" --snapshot "$D/snap.json" >/dev/null
cat > "$D/critic.txt" <<'EOF'
```docreview-layer1
- ref: c1
  category: unfounded_addition
  anchor: "#__doc__"
  disposition: fix
  summary: "RT_FIX_Q"
- ref: c2
  category: example_as_requirement
  anchor: "#__doc__"
  disposition: fix
  summary: "RT_FIX_EMPTY"
- ref: c3
  category: premature_closure
  anchor: "#__doc__"
  disposition: fix
  summary: "RT_FIX_NOLOG"
- ref: c4
  category: inference_as_decision
  anchor: "#__doc__"
  disposition: decide
  summary: "RT_DEC"
```
```docreview-layer2
[]
```
EOF
python3 "$S/docreview_route.py" prepare-recritic --state-dir "$D" --critic "$D/critic.txt" > "$D/prep.json"
python3 "$S/docreview_route.py" finalize --state-dir "$D" --recritic-skipped --doc "$TMP/s.md" > "$D/fin.json"
fid() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); print([f["id"] for f in d["findings"] if f.get("summary")==sys.argv[2]][0])' "$D/fin.json" "$1" 2>/dev/null; }
F_Q="$(fid RT_FIX_Q)"; F_E="$(fid RT_FIX_EMPTY)"; F_N="$(fid RT_FIX_NOLOG)"; F_D="$(fid RT_DEC)"
if [ -z "$F_Q" ] || [ -z "$F_E" ] || [ -z "$F_N" ] || [ -z "$F_D" ]; then
  no "왕복 전제: 라우팅이 네 finding 을 내지 않았다(Q=$F_Q E=$F_E N=$F_N D=$F_D) — 아래 판정은 무의미하다"
else
  python3 "$S/docreview_state.py" decide --state-dir "$D" --id "$F_D" --choice adopt --quote "RT_DECIDE_QUOTE" --log-file "$TMP/rt.audit.md" >/dev/null
  python3 "$S/docreview_state.py" fix --state-dir "$D" --id "$F_Q" --event drop --reason "RT_DROP_QUOTE" --log-file "$TMP/rt.audit.md" >/dev/null
  python3 "$S/docreview_state.py" gate --state-dir "$D" > "$D/g1.json"
  python3 "$L" check-drops "$TMP/rt.audit.md" "$D/g1.json" >/dev/null; rc=$?
  assert_eq "$rc" "0" "왕복 양성: 엔진이 문구와 함께 적은 drop 을 check-drops 가 읽는다"
  q="$(python3 "$L" user-quotes "$TMP/rt.audit.md")"
  assert_contains "$q" "RT_DECIDE_QUOTE" "왕복: 엔진이 적은 decide 문구를 읽는다"
  assert_contains "$q" "RT_DROP_QUOTE" "왕복: 엔진이 적은 drop 문구를 읽는다"
  python3 "$S/docreview_state.py" fix --state-dir "$D" --id "$F_E" --event drop --log-file "$TMP/rt.audit.md" >/dev/null
  python3 "$S/docreview_state.py" fix --state-dir "$D" --id "$F_N" --event drop >/dev/null
  python3 "$S/docreview_state.py" gate --state-dir "$D" > "$D/g2.json"
  out="$(python3 "$L" check-drops "$TMP/rt.audit.md" "$D/g2.json")"; rc=$?
  assert_eq "$rc" "1" "왕복: 문구 없는 drop 둘이 막힌다"
  assert_contains "$out" "\"$F_E\"" "왕복: 문구를 비운 drop 이 위반에 있다"
  assert_contains "$out" "empty_quote" "왕복: 사유 empty_quote"
  assert_contains "$out" "\"$F_N\"" "왕복: --log-file 없이 누른 drop 이 위반에 있다"
  assert_contains "$out" "no_log_line" "왕복: 사유 no_log_line"
fi

# ── 변이 — 빈 문구를 문구로 치면 위반이 사라져야 한다(이빨) ──────────────────
python3 - "$L" "$TMP/mut.py" <<'PY'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
needle = '(quoted if e["quote"].strip() else bare)'
open(sys.argv[2], "w", encoding="utf-8").write(t.replace(needle, "quoted", 1))
print("MUTATED" if needle in t else "UNCHANGED")
PY
printf '{"dropped": ["cccc0001#r1.1"]}' > "$TMP/g.json"
python3 "$TMP/mut.py" check-drops "$AUD" "$TMP/g.json" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "변이: 빈 문구 판별을 지우면 막히던 drop 이 통과한다 — 위 empty_quote 단언에 이빨이 있다"
finish
