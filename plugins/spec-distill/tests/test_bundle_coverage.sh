#!/usr/bin/env bash
# check_bundle_coverage.py — 에픽 묶음 ids 와 에픽 spec 의 `## 번호 대조` 표를 맞추는 검사(R0 AC6).
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
type: epic-bundle
epic: R9
roadmap: docs/x/roadmap.md
source_brief: docs/x/brief.md
ids: [C1, D2, OQ3, RC4, K5, ST1, S7, «web-key»]
---

# R9 — 묶음
MD

table_spec() {  # table_spec <첫 칸들...> — 각 인자가 한 행의 첫 칸
  printf -- '---\nsource_interview: docs/x/R9.md\n---\n\n# 설계\n\n### §1 설계\n\n- 하나\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n'
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
cp "$S/section6.py" "$S/roadmap_model.py" "$T/" 2>/dev/null
python3 "$T/mut.py" "$T/bundle.md" "$T/miss.md" >/dev/null; rc=$?
assert_eq "$rc" "0" "변이: status 를 0 으로 고정하면 빠진 번호가 rc 0 — 2번 단언에 이빨이 있다"
# 10. 공유 모듈(R3 §2-5) — 두 스크립트가 같은 함수를 쓰고 순환 import 가 없다
out="$(cd "$S" && python3 -c '
import roadmap_model as m, check_bundle_coverage as c, roadmap_status as r
print(c.section_body is m.section_body, c.frontmatter is m.frontmatter,
      r.parse_roadmap is m.parse_roadmap, r.brief_universe is m.brief_universe)' 2>&1)"
assert_eq "$out" "True True True True" "공유 모듈: 두 스크립트가 roadmap_model 의 같은 함수를 쓴다"
assert_file_absent "$C" '^(import|from) roadmap_status' "check_bundle_coverage 는 roadmap_status 를 import 하지 않는다"
assert_file_absent "$S/roadmap_model.py" '^(import|from) (check_bundle_coverage|roadmap_status)' "roadmap_model 은 두 스크립트 어느 쪽도 import 하지 않는다(순환 없음)"
# ── 11~16: R3 §2 — 자리 · 기각 에픽 · 받듦 · 셀 수 없음 · brief 입력 · 출력 ─────────
R="$T/repo"; mkdir -p "$R/docs/x" "$R/docs/superpowers/specs"
cat > "$R/docs/x/roadmap.md" <<'MD'
---
type: roadmap
source_brief: docs/x/brief.md
---

# 대조 로드맵

## 에픽

### R9 — 이 에픽
- 의도: 아홉
- 범위: 아홉
- 의존: 없음
- 브랜치: feature/r9
- 묶음: R9.md
- 경로 예약: 없음

### R8 — 이웃 에픽
- 의도: 여덟
- 범위: 여덟
- 의존: 없음
- 브랜치: feature/r8
- 묶음: R8.md
- 경로 예약: 없음

### P1 — 묶음 없는 블록
- 의도: 하나
- 범위: 하나
- 의존: 없음
- 브랜치: feature/p1
- 묶음: 없음
- 경로 예약: 없음
- spec: docs/superpowers/specs/p1-design.md
- 발화: S5
- 항목: C5
MD
mkbundle() {  # mkbundle <에픽> <ids>
  printf -- '---\ntype: epic-bundle\nepic: %s\nroadmap: docs/x/roadmap.md\nsource_brief: docs/x/brief.md\nids: [%s]\n---\n\n# %s 묶음\n' "$1" "$2" "$1" > "$R/docs/x/$1.md"
}
mkbundle R9 "C1, D2, S7, S8, S9"
mkbundle R8 "S8, S9"
# R8 의 설계문서는 S9 를 기각한다 — 배정만으로는 받듦이 아니다(N17)
printf -- '---\nsource_interview: docs/x/R8.md\n---\n\n# R8 설계\n\n## Goals\n\n- 이웃\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| S8 | 반영 | Goals |\n| S9 | 기각 | 범위 밖 |\n' > "$R/docs/superpowers/specs/r8-design.md"
r9_design() {  # r9_design <표 행들 — printf %b 로 푼다> — R9 설계문서를 낸다
  printf -- '---\nsource_interview: docs/x/R9.md\n---\n\n# R9 설계\n\n## Goals\n\n- 목표\n\n## 설계\n\n### §1 첫 절\n\n1. 하나\n2. 둘\n\n```\n### §2 펜스 안 제목\n```\n\n## Acceptance Criteria\n\n- **AC10** 열째\n- AC2. 둘째\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n'
  printf '%b' "$1"
  printf '\n## Metadata\n\n- 끝\n'
}
jget() {  # jget <json 문자열> <파이썬 식 — r 이 결과>. 식은 이 테스트가 쓴 고정 문자열뿐이다.
  J="$1" python3 -I -c 'import json, os, sys; r = json.loads(os.environ["J"]); print(eval(sys.argv[1]))' "$2"
}

# 11. 자리 확인(AC3) — §n-m · ACn(낱말 경계) · 펜스 안 제목 · 제목 낱말
r9_design '| C1 | 반영 | §1-2 — 둘째 항목 |\n| D2 | 반영 | §1-7 — 없는 항목 |\n| S7 | 반영 | AC1 — AC10 과 헷갈리면 안 된다 |\n| S8 | 반영 | AC10 · Goals |\n| S9 | 반영 | §2 — 펜스 안에만 있다 |\n' > "$R/loc.md"
out="$(python3 "$C" --json "$R/docs/x/R9.md" "$R/loc.md")"; rc=$?
assert_eq "$rc" "0" "AC7: 얕은 답만 있으면 rc 0 (리뷰 전에 막을 것 없음)"
assert_eq "$(jget "$out" "sorted(s['id'] for s in r['shallow'])")" "['D2', 'S7', 'S9']" "AC3: 없는 §1-7 · AC1(AC10 만 있다) · 펜스 안 §2 를 얕음으로 센다"
assert_eq "$(jget "$out" "[s['reason'] for s in r['shallow'] if s['id']=='D2']")" "['가리킨 자리가 설계문서에 없다: §1-7']" "AC3: 얕음 사유가 가리킨 자리를 말한다"
r9_design '| C1 | 반영 | 그냥 설명만 있다 |\n| D2 | 반영 | §1 |\n| S7 | 반영 | AC2 |\n| S8 | 반영 | Goals — 목표 |\n| S9 | 반영 | 설계 — §1-1 |\n' > "$R/loc2.md"
out="$(python3 "$C" --json "$R/docs/x/R9.md" "$R/loc2.md")"
assert_eq "$(jget "$out" "[(s['id'], s['reason']) for s in r['shallow']]")" "[('C1', '가리킨 자리가 없다')]" "AC3: 자리 표기가 하나도 없으면 얕음, 있으면(§1 · AC2 · 제목 낱말 · §1-1) 세지 않는다(양성 짝)"
txt="$(python3 "$C" "$R/docs/x/R9.md" "$R/loc2.md")"
assert_contains "$txt" "얕은 답 — C1: 가리킨 자리가 없다" "번호별 줄"
# 변이(AC15) — 「자리 표기 없음」 판정을 끄면 위 단언이 무너진다
M2="$T/mut2"; mkdir -p "$M2"; cp "$S/section6.py" "$S/roadmap_model.py" "$M2/"
sed 's/^    if not found:$/    if False:/' "$C" > "$M2/check_bundle_coverage.py"
cmp -s "$C" "$M2/check_bundle_coverage.py" && no "변이 적용 안 됨(자리 표기 없음)" || ok "변이 적용됨(자리 표기 없음)"
out="$(python3 "$M2/check_bundle_coverage.py" --json "$R/docs/x/R9.md" "$R/loc2.md")"
assert_eq "$(jget "$out" "len(r['shallow'])")" "0" "변이: 「자리 표기 없음」을 끄면 C1 이 얕음에서 빠진다 — AC3 단언에 이빨이 있다"

# 12. 기각 행(AC4 · AC5) — 로드맵에 없는 에픽 · 받드는 에픽 없음 · 배정됐지만 그 설계문서가 기각(N17)
r9_design '| C1 | 반영 | §1 |\n| D2 | 기각 | R99 로 넘긴다 |\n| S7 | 기각 | 범위 밖 |\n| S8 | 기각 | R8 이 받는다 |\n| S9 | 기각 | R8 이 받는다 |\n' > "$R/rej.md"
out="$(python3 "$C" --json "$R/docs/x/R9.md" "$R/rej.md")"; rc=$?
assert_eq "$rc" "0" "AC7: 얕음 · 받드는 에픽 없는 발화만 있으면 rc 0"
assert_eq "$(jget "$out" "[(s['id'], s['reason']) for s in r['shallow']]")" "[('D2', '넘긴 에픽이 로드맵에 없다: R99')]" "AC4: 기각 칸의 에픽이 로드맵에 없으면 얕음"
assert_eq "$(jget "$out" "r['unserved']")" "['S7', 'S9']" "AC5: 받드는 블록 없는 S7 과, 배정된 R8 의 설계문서가 기각한 S9(N17)가 받드는 에픽 없는 발화다 — R8 이 받드는 S8 은 아니다"
assert_eq "$(jget "$out" "r['unknown']")" "[]" "로드맵을 읽었으면 셀 수 없음 0"
cp -R "$R" "$T/repo2"
sed 's/^| S9 | 기각 | 범위 밖 |$/| S9 | 반영 | Goals |/' "$R/docs/superpowers/specs/r8-design.md" > "$T/repo2/docs/superpowers/specs/r8-design.md"
out="$(python3 "$C" --json "$T/repo2/docs/x/R9.md" "$R/rej.md")"
assert_eq "$(jget "$out" "r['unserved']")" "['S7']" "N17 양성 짝: R8 설계문서가 S9 를 반영하면 S9 는 받든 것이다"

# 13. 로드맵을 못 찾음(AC5 · AC7) — 그 항목만 셀 수 없음, rc 0, 첫 줄이 개수를 말한다
mkdir -p "$T/lone"; cp "$R/docs/x/R9.md" "$T/lone/R9.md"
txt="$(python3 "$C" "$T/lone/R9.md" "$R/rej.md")"; rc=$?
assert_eq "$rc" "0" "AC7: 셀 수 없음만 있으면 rc 0"
assert_eq "$(printf '%s\n' "$txt" | head -n 1)" "번호 대조: 빠진 번호 0개 · 얕은 답 0개 · 받드는 에픽 없는 발화 0개 · 셀 수 없음 4개" "AC7: 첫 줄이 셀 수 없음 개수를 말한다(조용한 0 이 아니다)"
assert_contains "$txt" "셀 수 없음 — S7 — 로드맵을 찾지 못했다: docs/x/roadmap.md" "셀 수 없음 사유 줄"

# 14. 출력 · 종료 코드(AC7) — 빠진 번호가 하나면 rc 1(양성 짝), JSON 키
r9_design '| C1 | 반영 | §1 |\n| D2 | 반영 | §1 |\n| S7 | 반영 | §1 |\n| S8 | 반영 | §1 |\n' > "$R/miss1.md"
txt="$(python3 "$C" "$R/docs/x/R9.md" "$R/miss1.md")"; rc=$?
assert_eq "$rc" "1" "AC7 양성 짝: 빠진 번호 하나 → rc 1"
assert_eq "$(printf '%s\n' "$txt" | head -n 1)" "번호 대조: 빠진 번호 1개 · 얕은 답 0개 · 받드는 에픽 없는 발화 0개" "AC7: 첫 줄 형식"
out="$(python3 "$C" --json "$R/docs/x/R9.md" "$R/miss1.md")"
assert_eq "$(jget "$out" "sorted(k for k in r if k in ('missing','shallow','unserved','unknown','extra','status'))")" "['extra', 'missing', 'shallow', 'status', 'unknown', 'unserved']" "AC7: --json 키"
r9_design '| C1 · D2 · S7 · S8 · S9 | 반영 | §1-1 |\n' > "$R/ok9.md"
txt="$(python3 "$C" "$R/docs/x/R9.md" "$R/ok9.md")"; rc=$?
assert_eq "$rc" "0" "전부 정상 → rc 0"
assert_eq "$txt" "번호 대조: 빠진 번호 없음 (묶음 번호 5개 · 표 번호 5개)" "전부 0 이면 지금의 「빠진 번호 없음」 한 줄"

# 15. brief 입력(AC6) — brief 의 전체 번호로 대조하고 roadmap_status 와 같은 집합이다
B="$T/brief"; mkdir -p "$B"
cat > "$B/b.md" <<'MD'
---
type: interview-brief
user_sourced_items:
  - id: C3
    statement: "셋째 확정"
---

# 대조용 brief

## 0. 한눈에

- OQ2 [열림] — 둘째 물음

## 4. External Landscape

- 대조 사례 «cov» — [취함]

## 5. 기각 · Blind Spots

- 기각 — 다른 길 — verdict: kept — ST2 — 부착 1/1
- 위험 — 실패 양식: 대조가 빠진다 — 근거 없음 [RC3]

## 6. 사용자 원문

- **S3** 🗣 요청:
  > 번호를 다 대조해 줘

## 7. Next Action

다음.
MD
printf '# audit\n\n## 6. 사용자 원문\n\n- **S4** 🗣 발화:\n  > 넷째 말\n\n## 7. 확산 원자료\n\n- 없음\n' > "$B/b.audit.md"
bdesign() { printf -- '---\nsource_interview: x\n---\n\n# 설계\n\n### §1 절\n\n1. 하나\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| %s | 반영 | §1 |\n' "$1"; }
bdesign "C3 · OQ2 · «cov» · RC3 · ST2 · K1 · S3 · S4" > "$B/d-all.md"
txt="$(python3 "$C" "$B/b.md" "$B/d-all.md")"; rc=$?
assert_eq "$rc" "0" "AC6: brief 입력 — 전체 번호가 표에 있으면 rc 0"
assert_eq "$txt" "번호 대조: 빠진 번호 없음 (brief 번호 8개 · 표 번호 8개)" "AC6: brief 번호 8개(§2 · §0 OQ · §4 key · §5 RC · ST · K · §6 S)를 센다"
bdesign "C3 · OQ2 · «cov» · RC3 · ST2 · K1 · S3" > "$B/d-miss.md"
txt="$(python3 "$C" "$B/b.md" "$B/d-miss.md")"; rc=$?
assert_eq "$rc" "1" "AC6: audit §6 의 S4 가 빠지면 rc 1"
assert_contains "$txt" "빠진 번호 1개 — S4" "AC6: 빠진 번호 S4"
out="$(cd "$S" && python3 -c '
import sys, check_bundle_coverage as c, roadmap_model as m
b = open(sys.argv[1], encoding="utf-8").read(); a = open(sys.argv[2], encoding="utf-8").read()
non_s, s_ids, _k = m.brief_universe(b, a)
r = c.coverage(sys.argv[1], sys.argv[3])
print(r["bundle_count"] == len(non_s | s_ids) and r["mode"] == "brief")' "$B/b.md" "$B/b.audit.md" "$B/d-all.md")"
assert_eq "$out" "True" "AC6: brief 모드의 번호 집합이 roadmap_status 의 brief_universe 와 같다"
mkdir -p "$T/noaudit"; cp "$B/b.md" "$T/noaudit/b.md"
txt="$(python3 "$C" "$T/noaudit/b.md" "$B/d-all.md")"; rc=$?
assert_eq "$rc" "3" "AC6: brief 옆 audit 을 못 읽으면 rc 3"
assert_contains "$txt" "brief 또는 audit 을 못 읽었다" "rc 3 사유"

# 16. 함수 경로의 경고 수(spec-review 가 쓴다)
out="$(cd "$S" && python3 -c '
import sys, check_bundle_coverage as c
print(c.warning_count(c.coverage(sys.argv[1], sys.argv[2])), c.warning_count({"status": 3}))' "$R/docs/x/R9.md" "$R/rej.md")"
assert_eq "$out" "3 1" "warning_count: 얕음 1 + 받드는 에픽 없음 2 = 3, 검사 불가는 1"

# 17. --plan(AC8) — 계획 Task 절에 없는 AC, 낱말 경계, 펜스 안 토큰, AC 절 없음
P="$T/plan"; mkdir -p "$P"
printf -- '# 설계\n\n## Acceptance Criteria\n\n- AC1 하나\n- **AC2** 둘\n- AC10. 열\n  - 하위 항목 AC77 은 AC 가 아니다\n\n## Files to Modify\n\n- x\n' > "$P/d.md"
printf -- '# 계획\n\n## Global\n\nAC2 는 여기에만 있다.\n\n### Task 1: 하나\n\n- AC10 을 만든다\n\n```bash\n# AC1 도 펜스 안에서 센다\n```\n\n### Task 2: 둘\n\n- 끝\n' > "$P/p-miss.md"
txt="$(python3 "$C" --plan "$P/d.md" "$P/p-miss.md")"; rc=$?
assert_eq "$rc" "1" "AC8: 계획에 없는 AC 가 있으면 rc 1"
assert_eq "$txt" "계획 대조: 계획에 없는 AC 1개 — AC2" "AC8: Task 절 밖의 AC2 는 계획에 없는 것이다(펜스 안 AC1 · AC10 은 있다)"
printf -- '# 계획\n\n### Task 1: 하나\n\n- AC10 만 있다\n' > "$P/p-ten.md"
txt="$(python3 "$C" --plan "$P/d.md" "$P/p-ten.md")"
assert_eq "$txt" "계획 대조: 계획에 없는 AC 2개 — AC1 · AC2" "AC8: AC10 이 AC1 을 덮지 않는다(낱말 경계)"
printf -- '# 계획\n\n### Task 1: 전부\n\n- AC1 · AC2 · AC10\n' > "$P/p-ok.md"
txt="$(python3 "$C" --plan "$P/d.md" "$P/p-ok.md")"; rc=$?
assert_eq "$rc" "0" "AC8 양성 짝: 다 있으면 rc 0"
assert_eq "$txt" "계획 대조: 계획에 없는 AC 없음 (AC 3개)" "AC8: 하위 항목의 AC77 은 AC 로 세지 않는다"
printf -- '# 설계\n\n## Goals\n\n- x\n' > "$P/d-noac.md"
txt="$(python3 "$C" --plan "$P/d-noac.md" "$P/p-ok.md")"; rc=$?
assert_eq "$rc" "3" "AC8: AC 절이 없으면 rc 3"
assert_contains "$txt" "계획 대조 검사 불가 — 설계문서에 \`## Acceptance Criteria\` 절이 없다" "rc 3 사유"
out="$(python3 "$C" --plan --json "$P/d.md" "$P/p-miss.md")"
assert_eq "$(jget "$out" "r['missing']")" "['AC2']" "--plan --json missing"

# 18. --impl(AC10) — 보고의 미룸 · 빠짐과 ## 미룸 표
printf -- '# 설계\n\n## Acceptance Criteria\n\n- AC1 하나\n- AC2 둘\n- AC3 셋\n- AC10 열\n\n## 미룸\n\n| 항목 | 이유 | 받는 곳 |\n|---|---|---|\n| AC2 | 다음 에픽에서 | 없음 |\n| r1.2 | 리뷰 후속 | `#12` |\n' > "$P/di.md"
printf 'AC1: 구현됨 — 됐다\n- AC2: 미룸 — 다음에\nAC3: 빠짐 — 못 했다\nAC10: 구현됨 — 됐다\nAC99: 구현됨 — 설계문서에 없는 AC\n' > "$P/rep.md"
txt="$(python3 "$C" --impl "$P/di.md" "$P/rep.md")"; rc=$?
assert_eq "$rc" "1" "AC10: 경고가 있으면 rc 1"
assert_eq "$(printf '%s\n' "$txt" | head -n 1)" "구현 대조: 경고 3개 — 보고에 없는 AC 0개 · 미룸 표에 없는 미룸/빠짐 1개 · 받는 곳 없는 미룸 1개 · 빠짐 1개" "AC10: 첫 줄"
assert_contains "$txt" "미룸 표에 없는 미룸/빠짐 — AC3(빠짐)" "AC10: 빠짐인데 ## 미룸 에 없는 AC"
assert_contains "$txt" "받는 곳 없는 미룸 — AC2" "AC10: 받는 곳이 없음인 행"
assert_contains "$txt" "정보: 설계문서에 없는 AC 가 보고에 있다 — AC99" "설계문서에 없는 AC 는 정보"
printf 'AC1: 구현됨 — a\nAC2: 구현됨 — b\nAC3: 구현됨 — c\n' > "$P/rep-short.md"
txt="$(python3 "$C" --impl "$P/di.md" "$P/rep-short.md")"
assert_contains "$txt" "보고에 없는 AC — AC10" "AC10: 보고에 없는 AC 를 경고한다"
printf -- '# 설계\n\n## Acceptance Criteria\n\n- AC1 하나\n\n## 미룸\n\n없음\n' > "$P/di-none.md"
printf 'AC1: 구현됨 — 됐다\n' > "$P/rep-one.md"
txt="$(python3 "$C" --impl "$P/di-none.md" "$P/rep-one.md")"; rc=$?
assert_eq "$rc" "0" "AC10 양성 짝: 전부 구현됨 · ## 미룸 「없음」 → rc 0"
assert_eq "$txt" "구현 대조: 경고 없음 (AC 1개 · 구현됨 1개 · 미룸 0개)" "경고 없음 줄"
printf 'AC1: 됐음 — 형식 밖\n' > "$P/rep-bad.md"
python3 "$C" --impl "$P/di-none.md" "$P/rep-bad.md" >/dev/null; rc=$?
assert_eq "$rc" "3" "보고 줄이 형식 밖이면 rc 3"
printf 'AC1: 구현됨 — a\nAC1: 빠짐 — b\n' > "$P/rep-dup.md"
python3 "$C" --impl "$P/di-none.md" "$P/rep-dup.md" >/dev/null; rc=$?
assert_eq "$rc" "3" "같은 AC 가 두 번이면 rc 3"
printf -- '# 설계\n\n## Acceptance Criteria\n\n- AC1 하나\n\n## 미룸\n\n| 항목 | 받는 곳 |\n|---|---|\n| AC1 | 없음 |\n' > "$P/di-broken.md"
txt="$(python3 "$C" --impl "$P/di-broken.md" "$P/rep-one.md")"; rc=$?
assert_eq "$rc" "3" "## 미룸 표가 깨지면 rc 3"
assert_contains "$txt" "구현 대조 검사 불가 — " "rc 3 첫 줄"
python3 "$C" --impl "$P/di.md" "$P/없음.md" >/dev/null; rc=$?
assert_eq "$rc" "3" "보고 파일이 없으면 rc 3"
python3 "$C" --plan --impl "$P/di.md" "$P/rep.md" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "--plan 과 --impl 은 함께 쓸 수 없다(rc 2)"
lc="$(LC_ALL=C LANG=C PYTHONIOENCODING= python3 "$C" --impl "$P/di.md" "$P/rep.md" 2>&1)"
assert_contains "$lc" "구현 대조: 경고 3개" "비UTF-8 로캘에서도 한국어 출력이 깨지지 않는다"

# 19. deferred_rows · receiver_ok(Task 4 가 쓴다)
out="$(cd "$S" && python3 -c '
import sys, check_bundle_coverage as c
rows = c.deferred_rows(open(sys.argv[1], encoding="utf-8").read())
print(rows)
print([c.receiver_ok(r, {"R5"}) for r in ("없음", "#12", "R5", "R99", "다음에")])' "$P/di.md")"
assert_contains "$out" "[('AC2', '다음 에픽에서', '없음'), ('r1.2', '리뷰 후속', '#12')]" "deferred_rows: 받는 곳의 백틱을 벗긴다"
assert_contains "$out" "[False, True, True, False, False]" "receiver_ok: 없음 · 로드맵에 없는 에픽 · 그 밖 글은 받는 곳이 아니다"

finish
