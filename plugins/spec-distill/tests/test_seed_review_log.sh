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

# ── AUDIT_HEADINGS — 여섯 제목이 템플릿의 '## N.' 줄에서 도출된다, 순서까지(fix round 1) ──
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
# 되돌리는 길 — 문구 없이 눌린 drop 은 엔진에서 다시 drop 할 수 없다. 사용자에게 다시 물어 받은 문구를
# `거부` 줄로 적으면 통과한다(설계 D18 의 「항목 / 거부 / 사용자 문구」 기록).
cp "$AUD" "$TMP/fix.audit.md"
python3 "$L" log "$TMP/fix.audit.md" --kind 거부 --round 2 --target "cccc0001#r1.1" --quote "QUOTE_REFUSE 그 지적은 반영하지 않는다" --note "다시 물어 받은 문구" >/dev/null
assert_eq "$(chk '{"dropped": ["cccc0001#r1.1"]}' "$TMP/fix.audit.md")" "0" "check-drops: 문구가 빈 drop 도 사용자 문구로 쓴 거부 줄이 있으면 통과한다"

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
