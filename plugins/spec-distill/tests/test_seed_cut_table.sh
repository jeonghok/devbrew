#!/usr/bin/env bash
# R2 Task 1 — seed audit 의 덜어 낸 것 표(check_seed check 5) · 풀이 줄의 «사용자가 적은 말» 칸 ·
# 확인 표시가 «다시 검증할 것 —» 문단에서도 따라감(classify) · 번들이 새 절을 싣는다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
S="$ROOT/plugins/spec-distill/scripts"
TMP="$(mktemp -d -t sd-cut-XXXXXX)" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
trap 'rm -rf "$TMP"' EXIT

seed() { cat > "$TMP/s.md" <<'EOF'
---
type: interview-seed
next_phase: spec-distill:pm-interview
audit_file: a.audit.md
---

로그인이 가끔 실패한다. 세션 스토어 개편은 이번에 하지 않는다. (사용자 확인)

다시 검증할 것 — 서버 로그는 다시 봐야 한다. 경합이 원인이다. (사용자 확인)
EOF
}
# 주의: «다시 검증할 것 —» 문단의 첫 문장은 그 접두를 글자로 품는다(`segments` 가 문단을 문장으로 쪼갤 뿐
# 접두를 떼지 않는다). 그래서 확인 문장은 둘째 문장에 두고, 첫 문장의 키는 접두를 포함한 전문이다.
# audit — $1 = 덜어 낸 것 절 본문(없으면 절째 뺀다: 값 "__NONE__")
audit() {
  {
    printf -- '---\ntype: interview-seed-audit\n---\n\n## 1. 원문\n\n로그인이 가끔 실패한다.\n\n## 2. 질문 전체\n\n### 라운드 1\n\n'
    printf -- '- 물은 것: 무엇을 하지 않나요\n  - 선택지: 자유 입력\n  - 당신이 답한 것: 세션 스토어는 다음 분기\n'
    printf -- '- 확인 질문: 라운드 1\n'
    printf -- '  - 내가 읽은 것: 「세션 스토어 개편은 이번에 하지 않는다.」 — 고름\n'
    printf -- '  - 내가 읽은 것: 「경합이 원인이다.」 — 고름 — 사용자가 적은 말: 「경합 같다, 확실하진 않다」\n'
    printf -- '  - 내가 읽은 것: 「서버가 원인이다.」 — 고르지 않음 — 사용자가 적은 말: 「「서버」 — 고름 은 아니다」\n\n'
    printf -- '## 3. 긴 초안\n\n긴 초안 본문.\n\n'
    if [ "$1" != "__NONE__" ]; then printf -- '## seed 에서 덜어 낸 것\n\n%s\n\n' "$1"; fi
    printf -- '## 4. 비평과 냉독\n\n## 5. degrade\n\n## 6. 리뷰 결정\n'
  } > "$TMP/a.audit.md"
}
gate() { python3 "$S/check_seed.py" gate "$TMP/s.md" "$TMP/a.audit.md" 2>"$TMP/err"; }

ROWS='| 항목 | 기준 | 원문 위치 | 되살림 |
|---|---|---|---|
| 재현 절차 재기술 | 자명 | ## 3 둘째 문단 | — |'

seed
# ── check 5: 표 · 없음 · 부재 · 머리 행만
audit "$ROWS";      gate; assert_eq "$?" "0" "cut_rows: 데이터 행이 있는 표는 통과한다"
audit "없음";        gate; assert_eq "$?" "0" "cut_none: 「없음」 한 줄은 통과한다 (덜어 낸 것 0)"
audit "__NONE__";   gate; rc=$?
{ [ "$rc" -ne 0 ] && grep -qF 'seed 에서 덜어 낸 것' "$TMP/err"; } \
  && ok "cut_absent: 절이 없으면 막고 절 이름을 댄다" || no "cut_absent: 절이 없어도 통과했다 (rc=$rc)"
audit '| 항목 | 기준 | 원문 위치 | 되살림 |
|---|---|---|---|';    gate; rc=$?
{ [ "$rc" -ne 0 ] && grep -qF '표 행도' "$TMP/err"; } \
  && ok "cut_header_only: 머리 행뿐이면 막는다 (적지 않음 ≠ 0개)" || no "cut_header_only: 머리 행뿐인데 통과했다 (rc=$rc)"
# AC3 — URL 금지는 그대로
audit "없음"; printf '\n자료는 https://example.com 에 있다.\n' >> "$TMP/s.md"; gate; rc=$?
[ "$rc" -ne 0 ] && ok "AC3: URL 금지는 그대로다" || no "AC3: seed 의 URL 이 통과했다"
seed

# ── 절 경계: ## 3 본문이 새 절을 삼키지 않는다
audit "$ROWS"
body3="$(python3 -I -X utf8 -c 'import sys; sys.path.insert(0, sys.argv[1]); from seed_review_log import section_body; print(section_body(open(sys.argv[2], encoding="utf-8").read(), "## 3. 긴 초안"))' "$S" "$TMP/a.audit.md")"
assert_not_contains "$body3" "재현 절차 재기술" "boundary: ## 3. 긴 초안 의 본문에 덜어 낸 것 표가 섞이지 않는다"
assert_contains "$body3" "긴 초안 본문." "boundary(양성 짝): ## 3 본문은 읽힌다"

# ── marks: «사용자가 적은 말» 꼬리가 있어도 모양이 맞고(rc 2 아님), 고름 풀이는 확인 근거다
python3 "$S/seed_provenance.py" marks "$TMP/s.md" "$TMP/a.audit.md" > "$TMP/marks.json" 2>"$TMP/err"; rc=$?
assert_eq "$rc" "0" "said_suffix: 꼬리 달린 풀이 줄이 모양 어긋남으로 막히지 않고 두 표시가 다 근거를 얻는다"
assert_not_contains "$(cat "$TMP/err")" "malformed" "said_brackets: 「」 와 ` — 고름` 이 든 적은 말도 모양 어긋남이 아니다"

# ── classify: 표시가 문단보다 먼저 (N20)
python3 "$S/seed_provenance.py" classify "$TMP/s.md" --audit "$TMP/a.audit.md" > "$TMP/c.json"
row() { python3 -I -X utf8 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); r=[x for x in d["sentences"] if x["text"]==sys.argv[2]]; print("%s %s %s" % (r[0]["provenance"], r[0]["confirmed"], r[0]["basis"]) if r else "ABSENT")' "$TMP/c.json" "$1"; }
assert_eq "$(row '경합이 원인이다.')" "user True confirmed_reading" "N20: 확인 표시가 붙은 문장은 «다시 검증할 것 —» 문단 안에서도 사용자 확인이다"
assert_eq "$(row '다시 검증할 것 — 서버 로그는 다시 봐야 한다.')" "author False reverify_paragraph" "N20(양성 짝): 같은 문단의 표시 없는 문장은 저자 · 미확인이다"
assert_eq "$(row '세션 스토어 개편은 이번에 하지 않는다.')" "user True confirmed_reading" "N20(대조): 문단 밖 확인 문장은 그대로 확인이다"

# ── 고르지 않은 풀이에 표시를 붙이면 문단 안에서도 확인이 아니다
cat > "$TMP/s2.md" <<'EOF'
---
type: interview-seed
---

다시 검증할 것 — 로그를 본다. 서버가 원인이다. (사용자 확인)
EOF
python3 "$S/seed_provenance.py" classify "$TMP/s2.md" --audit "$TMP/a.audit.md" > "$TMP/c.json"
assert_eq "$(row '서버가 원인이다.')" "author False reverify_paragraph" "N20(경계): 고르지 않은 풀이에 붙은 표시는 문단 안에서 확인이 되지 않는다"

# ── 번들이 덜어 낸 것 표를 싣는다 (두 소비자)
printf '# repo\n' > "$TMP/CLAUDE.md"
for who in detect recritic; do
  out="$(python3 "$S/build_seed_inline_blob.py" "$TMP/s.md" "$TMP/a.audit.md" "$TMP/CLAUDE.md" --for "$who" 2>/dev/null)"
  assert_contains "$out" "## seed 에서 덜어 낸 것" "blob($who): 번들에 덜어 낸 것 절이 있다"
  assert_contains "$out" "재현 절차 재기술" "blob($who): 표의 행이 실린다"
done

finish
