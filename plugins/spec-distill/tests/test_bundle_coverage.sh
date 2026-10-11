#!/usr/bin/env bash
# check_bundle_coverage.py — 조각 묶음 ids 와 조각 spec 의 `## 번호 대조` 표를 맞추는 검사(R0 AC6).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_bundle_coverage.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
S="$ROOT/plugins/spec-distill/scripts"
C="$S/check_bundle_coverage.py"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT

cat > "$T/bundle.md" <<'MD'
---
type: slice-bundle
slice: R9
roadmap: docs/x/roadmap.md
source_brief: docs/x/brief.md
ids: [C1, D2, OQ3, RC4, K5, ST1, S7, «web-key»]
---

# R9 — 묶음
MD

table_spec() {  # table_spec <첫 칸들...> — 각 인자가 한 행의 첫 칸
  printf -- '---\nsource_interview: docs/x/R9.md\n---\n\n# 설계\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n'
  for cell in "$@"; do printf '| %s | 반영 | §1 |\n' "$cell"; done
  printf '\n## Metadata\n\n- 끝\n'
}

# 1. 이상 없음 — 한 칸에 번호 여럿(쉼표와 ` · ` 둘 다), «key» 포함
table_spec "C1 · D2" "OQ3, RC4" "K5" "ST1 · S7" "«web-key»" > "$T/ok.md"
out="$(python3 "$C" "$T/bundle.md" "$T/ok.md")"; rc=$?
assert_eq "$rc" "0" "빠진 번호 없음 → rc 0"
assert_contains "$out" "빠진 번호 없음 (묶음 번호 8개 · 표 번호 8개)" "이상 없음 줄이 두 수를 센다"

# 2. 빠진 번호 — 나열하고 rc 1
table_spec "C1 · D2" "OQ3" "K5" "S7" > "$T/miss.md"
out="$(python3 "$C" "$T/bundle.md" "$T/miss.md")"; rc=$?
assert_eq "$rc" "1" "빠진 번호 → rc 1"
assert_contains "$out" "빠진 번호 3개 — RC4 · ST1 · «web-key»" "빠진 번호를 묶음 순서대로 나열한다"

# 3. 묶음에 없는 번호가 표에 있으면 정보 줄(종료 코드는 바꾸지 않는다)
table_spec "C1 · D2" "OQ3, RC4" "K5" "ST1 · S7" "«web-key»" "C99" > "$T/extra.md"
out="$(python3 "$C" "$T/bundle.md" "$T/extra.md")"; rc=$?
assert_eq "$rc" "0" "표에만 있는 번호는 rc 를 바꾸지 않는다"
assert_contains "$out" "정보: 묶음에 없는 번호 1개가 표에 있다 — C99" "정보 줄"

# 4. 검사 불가(rc 3) — ids 없음 · 표 깨짐 · 절 없음 · 범위 표기 · 셋째 칸 빔 · 파일 없음
sed '/^ids:/d' "$T/bundle.md" > "$T/noids.md"
out="$(python3 "$C" "$T/noids.md" "$T/ok.md")"; rc=$?
assert_eq "$rc" "3" "ids 없음 → rc 3"
assert_contains "$out" "번호 대조 검사 불가 — 묶음 frontmatter 에 ids 가 없다" "ids 없음 사유"
sed 's/^## 번호 대조$/## 다른 절/' "$T/ok.md" > "$T/nosec.md"
grep -q '^## 번호 대조' "$T/nosec.md" && no "양성 대조: 절 제거가 안 됐다" || ok "양성 대조: 픽스처에서 번호 대조 절이 사라졌다"
python3 "$C" "$T/bundle.md" "$T/nosec.md" >/dev/null; rc=$?
assert_eq "$rc" "3" "\`## 번호 대조\` 절 없음 → rc 3 (표 깨짐과 같은 검사 불가)"
table_spec "K1~K7" > "$T/range.md"
python3 "$C" "$T/bundle.md" "$T/range.md" >/dev/null; rc=$?
assert_eq "$rc" "3" "범위 표기 K1~K7 → rc 3 (토큰 문법 밖)"
printf -- '---\n---\n## 번호 대조\n\n| 번호 | 처리 | 자리 |\n|---|---|---|\n| C1 | 반영 | |\n' > "$T/empty3.md"
python3 "$C" "$T/bundle.md" "$T/empty3.md" >/dev/null; rc=$?
assert_eq "$rc" "3" "셋째 칸이 비면 rc 3"
printf -- '---\n---\n## 번호 대조\n\n| 번호 | 처리 | 자리 |\n|---|---|---|\n| C1 | 했음 | §1 |\n' > "$T/badverb.md"
python3 "$C" "$T/bundle.md" "$T/badverb.md" >/dev/null; rc=$?
assert_eq "$rc" "3" "둘째 칸이 반영/기각이 아니면 rc 3"
python3 "$C" "$T/bundle.md" "$T/없는파일.md" >/dev/null; rc=$?
assert_eq "$rc" "3" "spec 파일 없음 → rc 3"
python3 "$C" "$T/bundle.md" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "인자 부족 → rc 2"

# 5. 펜스 안의 `## ` 줄은 절 경계가 아니다
{ printf -- '---\n---\n## 번호 대조\n\n```\n## 예시 제목\n```\n\n| 번호 | 처리 | 자리 |\n|---|---|---|\n'
  printf '| C1 · D2 · OQ3 · RC4 · K5 · ST1 · S7 · «web-key» | 반영 | §1 |\n'; } > "$T/fence.md"
python3 "$C" "$T/bundle.md" "$T/fence.md" >/dev/null; rc=$?
assert_eq "$rc" "0" "펜스 안 \`## \` 줄을 절 끝으로 읽지 않는다"

# 6. JSON 출력과 함수 경로(roadmap_status 가 쓰는 문자열 입력)
out="$(python3 "$C" --json "$T/bundle.md" "$T/miss.md")"
assert_contains "$out" '"missing": ["RC4", "ST1", "«web-key»"]' "JSON missing 필드"
out="$(cd "$S" && python3 -c '
import check_bundle_coverage as c, sys
b = open(sys.argv[1], encoding="utf-8").read(); s = open(sys.argv[2], encoding="utf-8").read()
print(c.check(b, s)["status"])' "$T/bundle.md" "$T/miss.md")"
assert_eq "$out" "1" "check(문자열, 문자열) 이 파일 없이 같은 판정을 낸다"

# 7. §6 은 section_body 로 읽지 않는다(section6.body 한 곳)
out="$(cd "$S" && python3 -c '
import check_bundle_coverage as c
try:
    c.section_body("## 6. 사용자 원문\n- x\n", "## 6.")
    print("READ")
except ValueError:
    print("REFUSED")')"
assert_eq "$out" "REFUSED" "section_body 가 §6 읽기를 거부한다"

# 8. 실데이터 양성 대조 — R0 설계문서의 번호 대조 표가 파싱된다(손으로 쓴 실제 표)
R0_SPEC="$ROOT/docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md"
out="$(cd "$S" && python3 -c '
import check_bundle_coverage as c, sys
ids = c.table_ids(open(sys.argv[1], encoding="utf-8").read())
print(len(ids), "C25" in ids, "D26" in ids, "S51" in ids)' "$R0_SPEC" 2>&1)"
assert_grep "$out" "^[0-9]+ True True True$" "R0 설계문서 표가 한 칸 여러 번호까지 파싱된다: $out"

# 9. 변이 — 빠진 번호 판정을 지우면 2번 단언이 무너지는지(통과가 정답인 1번의 짝)
sed 's/return {"status": 1 if missing else 0,/return {"status": 0,/' "$C" > "$T/mut.py"
cmp -s "$C" "$T/mut.py" && no "변이가 적용되지 않았다" || ok "변이 적용됨"
cp "$S/section6.py" "$T/" 2>/dev/null
python3 "$T/mut.py" "$T/bundle.md" "$T/miss.md" >/dev/null; rc=$?
assert_eq "$rc" "0" "변이: status 를 0 으로 고정하면 빠진 번호가 rc 0 — 2번 단언에 이빨이 있다"
finish
