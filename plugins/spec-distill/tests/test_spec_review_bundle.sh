#!/usr/bin/env bash
# R3 AC11 · AC12 · AC14 — spec-review 의 --bundle 확인 · 진입 번호 대조 · 승인 때 로드맵 위치와 이웃 결정.
# 스크립트(spec_review_bundle.py)를 픽스처 git 저장소에서 돌린다. SKILL 펜스 배선은 아래 절이 잰다(Task 7).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_spec_review_bundle.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
S="$ROOT/plugins/spec-distill/scripts"
SRB="$S/spec_review_bundle.py"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
W="$T/work"
g() { git -C "$W" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false \
        -c init.defaultBranch=main "$@"; }
put() { mkdir -p "$(dirname "$W/$1")" && printf '%b' "$2" > "$W/$1"; }   # put <경로> <내용(%b)>

git init -q --bare -b main "$T/origin.git"
git clone -q "$T/origin.git" "$W" 2>/dev/null
put docs/nb/brief.md '---\ntype: interview-brief\nuser_sourced_items:\n  - id: C1\n    statement: "이웃 확정"\n---\n\n# 이웃 brief\n\n## 0. 한눈에\n\n- OQ1 [열림] — 이웃 물음\n\n## 4. External Landscape\n\n- 이웃 사례 «nb» — 참고\n\n## 5. 기각 · Blind Spots\n\n- 위험 — 숨은 가정: 이웃이 안 보인다 — 없음 [RC1]\n\n## 6. 사용자 원문\n\n- **S1** 🗣 요청:\n  > 이웃 결정을 보여 줘\n\n## 7. Next Action\n\n없음.\n'
put docs/nb/brief.audit.md '# audit\n\n## 6. 사용자 원문\n\n- **S2** 🗣 발화:\n  > 둘째 요청\n\n## 7. 확산 원자료\n\n- 없음\n'
nb_bundle() {  # nb_bundle <에픽> <ids>
  put "docs/rm/$1.md" "---\ntype: epic-bundle\nepic: $1\nroadmap: docs/rm/roadmap.md\nsource_brief: docs/nb/brief.md\nids: [$2]\n---\n\n# $1 이웃 묶음\n"
}
nb_bundle R1 "C1, OQ1"; nb_bundle R3 "C1, S1"; nb_bundle R4 "RC1"; nb_bundle R5 "«nb», K1"; nb_bundle R6 "S2"
nb_block() {  # nb_block <id> <의존> <경로 예약>
  printf '### %s — 이웃 %s\n- 의도: %s\n- 범위: %s\n- 의존: %s\n- 브랜치: feature/%s\n- 묶음: %s.md\n- 경로 예약: %s\n\n' "$1" "$1" "$1" "$1" "$2" "$(printf '%s' "$1" | tr 'A-Z' 'a-z')" "$1" "$3"
}
{ printf -- '---\ntype: roadmap\nsource_brief: docs/nb/brief.md\n---\n\n# 이웃 로드맵\n\n## 에픽\n\n'
  nb_block R1 없음 없음; nb_block R3 R1 "src/shared.txt"; nb_block R4 없음 "src/shared.txt"
  nb_block R5 R3 없음; nb_block R6 없음 없음
  printf '## 결정 기록\n\n## 위험 번호표\n\n- K1 — 위험 — 숨은 가정: 이웃이 안 보인다 — 없음 [RC1]\n'
} > "$W/docs/rm/roadmap.md"
g add -- docs && g commit -qm "이웃 로드맵" && g push -q origin main
g remote set-head origin main
spec_with() {  # spec_with <경로> <source_interview> <결정 기록 본문(%b)>
  put "$1" "---\nsource_interview: $2\n---\n\n# 설계\n\n### §1 절\n\n1. 하나\n\n## 결정 기록\n\n$3\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| C1 | 반영 | §1 |\n| S1 | 반영 | 없는 자리만 말한다 |\n"
}
g checkout -q -b feature/r1 main
spec_with docs/superpowers/specs/r1-design.md docs/rm/R1.md '- B1 · 결정 · 2026-10-15 · 첫 결정 — 「그대로 (권장)」\n- 판정 · 2026-10-15 · 보이지 않는 줄'
g add -- docs && g commit -qm "r1 spec"; g checkout -q main
g merge -q --no-ff feature/r1 -m "Merge pull request #1 from o/feature/r1"; g push -q origin main
g checkout -q -b feature/r4 main
spec_with docs/superpowers/specs/r4-design.md docs/rm/R4.md '- 없음'
g add -- docs && g commit -qm "r4 spec"; g checkout -q main
g checkout -q -b feature/r6 main
spec_with docs/superpowers/specs/r6-design.md docs/rm/R6.md '- B9 · 결정 · 2026-10-15 · 무관한 이웃 — 「보이면 안 된다」'
g add -- docs && g commit -qm "r6 spec"; g checkout -q main
g checkout -q -b feature/r3 main
spec_with docs/superpowers/specs/r3-design.md docs/rm/R3.md '- 없음'
spec_with docs/superpowers/specs/q-design.md '"docs/rm/R3.md"' '- 없음'
spec_with docs/superpowers/specs/b-design.md docs/nb/brief.md '- 없음'
put docs/superpowers/specs/none-design.md '---\nname: x\n---\n\n# 출처 없음\n'
g add -- docs && g commit -qm "r3 spec"
g fetch -q origin
SPEC="$W/docs/superpowers/specs/r3-design.md"
entry() { (cd "$T" && python3 "$SRB" entry --spec "$1" ${2+--bundle "$2"} --root "$W"); }
last() { printf '%s\n' "$1" | tail -n 1; }

# 1. AC11 — 같은 파일은 표기가 달라도 통과(양성 짝)
for v in docs/rm/R3.md @docs/rm/R3.md ./docs/rm/../rm/R3.md "$W/docs/rm/R3.md"; do
  out="$(entry "$SPEC" "$v")"
  assert_eq "$(last "$out")" "bundle-entry: PROCEED $(cd "$W" && pwd -P)/docs/rm/R3.md" "AC11: --bundle '$v' 은 source_interview 와 같은 파일이라 통과한다"
done
out="$(entry "$W/docs/superpowers/specs/q-design.md" docs/rm/R3.md)"
assert_contains "$(last "$out")" "bundle-entry: PROCEED " "AC11: 따옴표 친 source_interview 도 같은 파일로 읽는다"
# 2. AC11 — 거부 넷
out="$(entry "$SPEC" docs/rm/없음.md)"
assert_eq "$(last "$out")" "bundle-entry: REFUSE" "AC11: 없는 파일 → 거부"
assert_contains "$out" "[spec-distill] --bundle 'docs/rm/없음.md' 을 정답 출처로 쓸 수 없다 — 파일이 없다." "AC11: 거부 사유 문면"
out="$(entry "$SPEC" docs/rm/roadmap.md)"
assert_contains "$out" "frontmatter type 이 epic-bundle · interview-brief 가 아니다(roadmap)" "AC11: 틀린 type → 거부"
assert_eq "$(last "$out")" "bundle-entry: REFUSE" "AC11: 틀린 type → 거부 종료 줄"
out="$(entry "$SPEC" docs/rm/R4.md)"
assert_contains "$out" "설계문서 source_interview(docs/rm/R3.md) 와 다른 파일이다" "AC11: 다른 묶음 → 거부"
assert_eq "$(last "$out")" "bundle-entry: REFUSE" "AC11: 다른 묶음 → 거부 종료 줄"
out="$(entry "$W/docs/superpowers/specs/none-design.md" docs/rm/R3.md)"
assert_contains "$out" "설계문서 frontmatter 에 source_interview 가 없다" "AC11: source_interview 없는 설계문서 → 거부"
assert_eq "$(last "$out")" "bundle-entry: REFUSE" "AC11: source_interview 없음 → 거부 종료 줄"
# 3. AC11 — --bundle 없는 호출은 검사를 건너뛴다
out="$(entry "$SPEC")"
assert_eq "$(last "$out")" "bundle-entry: PROCEED -" "AC11: --bundle 없으면 건너뛴다"
assert_contains "$out" "번호 대조 건너뜀" "건너뜀을 말한다"
# 4. AC12 — 진입 대조 출력과 경고 수(얕은 행 하나)
out="$(entry "$SPEC" docs/rm/R3.md)"
assert_contains "$out" "번호 대조: 빠진 번호 0개 · 얕은 답 1개 · 받드는 에픽 없는 발화 0개" "AC12: §2 출력 첫 줄을 그대로 보인다"
assert_eq "$(printf '%s\n' "$out" | tail -n 2 | head -n 1)" "번호 대조 경고 1개" "AC12: PROCEED 앞 줄이 경고 수"
out="$(entry "$W/docs/superpowers/specs/b-design.md" docs/nb/brief.md)"
assert_contains "$out" "번호 대조: 빠진 번호 " "AC12: brief 로 불려도 대조한다(brief 모드)"
assert_contains "$(last "$out")" "bundle-entry: PROCEED " "brief --bundle 은 통과"
lc="$(cd "$T" && LC_ALL=C LANG=C PYTHONIOENCODING= python3 "$SRB" entry --spec "$SPEC" --bundle docs/rm/R3.md --root "$W" 2>&1)"
assert_contains "$lc" "번호 대조 경고 1개" "비UTF-8 로캘에서도 한국어 출력이 깨지지 않는다"

# 5. AC14 — 에픽 묶음이면 로드맵 위치와 이웃 결정
nbr="$(cd "$T" && python3 "$SRB" neighbors --bundle docs/rm/R3.md --root "$W")"
assert_contains "$nbr" "로드맵 속 위치 — docs/rm/roadmap.md" "AC14: 위치 머리"
assert_grep "$nbr" '^  R3 이웃 R3 — 설계 중 · ' "AC14: 이 에픽 한 줄(roadmap_status 줄 모양)"
assert_grep "$nbr" '^  의존: R1 이웃 R1 — 머지됨 · ' "AC14: 의존 에픽 한 줄"
assert_grep "$nbr" '^  이 에픽에 의존: R5 이웃 R5 — ' "AC14: 이 에픽에 의존하는 에픽 한 줄"
assert_contains "$nbr" "    - B1 · 결정 · 2026-10-15 · 첫 결정 — 「그대로 (권장)」" "AC14: 의존 이웃의 사용자 결정 줄을 그대로"
assert_contains "$nbr" "  R4 — 결정 줄 없음 — docs/superpowers/specs/r4-design.md" "AC14: 경로 예약이 겹치는 이웃(결정 줄 없음)"
assert_not_contains "$nbr" "보이지 않는 줄" "AC14: 결정 줄(B<n> · 결정)이 아닌 줄은 내지 않는다"
assert_not_contains "$nbr" "무관한 이웃" "AC14: 의존도 겹침도 없는 R6 은 내지 않는다"
g show feature/r6:docs/superpowers/specs/r6-design.md | grep -q 'B9 · 결정' && ok "양성 대조: R6 설계문서에는 결정 줄이 있다 — 위 부재가 공허하지 않다" || no "양성 대조: R6 설계문서에 결정 줄이 없다 — 위 부재 단언이 공허하다"
nbr="$(cd "$T" && python3 "$SRB" neighbors --bundle docs/nb/brief.md --root "$W")"
assert_eq "$nbr" "" "AC14: brief 로 불리면 내지 않는다"
put docs/rm/R9.md '---\ntype: epic-bundle\nepic: R9\nroadmap: docs/rm/roadmap.md\nsource_brief: docs/nb/brief.md\nids: [C1]\n---\n'
nbr="$(cd "$T" && python3 "$SRB" neighbors --bundle docs/rm/R9.md --root "$W")"
assert_eq "$nbr" "" "AC14: 로드맵 밖 에픽이면 내지 않는다"
(cd "$T" && python3 "$SRB" >/dev/null 2>&1); rc=$?
assert_eq "$rc" "2" "하위 명령 없음 → rc 2"
# ── 6. SKILL 배선(Task 7) — 펜스를 실제로 돌린다 ───────────────────────────────
SKILL="$ROOT/plugins/spec-distill/skills/spec-review/SKILL.md"
fence() {  # fence <표지 이름> — 표지 사이 bash 펜스 본문
  awk -v b="<!-- $1:begin -->" -v e="<!-- $1:end -->" 'index($0,b){f=1;next} index($0,e){f=0} f' "$SKILL" | sed -e '/^```/d'
}
EF="$(fence bundle-entry)"; NF_="$(fence roadmap-position)"
[ -n "$EF" ] && ok "진입 펜스(bundle-entry)가 있다" || no "진입 펜스(bundle-entry)가 없다"
[ -n "$NF_" ] && ok "위치 펜스(roadmap-position)가 있다" || no "위치 펜스(roadmap-position)가 없다"
run_fence() {  # run_fence <펜스 본문> <플러그인 루트> <앞에 붙일 대입들>
  printf '%s\n%s\n' "$3" "$1" > "$T/fence.sh"
  (cd "$W" && CLAUDE_PLUGIN_ROOT="$2" bash "$T/fence.sh" 2>&1)
}
SDROOT="$ROOT/plugins/spec-distill"
out="$(run_fence "$EF" "$SDROOT" "spec_path='$SPEC' bundle_arg='docs/rm/R4.md' repo_root='$W'")"
assert_contains "$out" "bundle-entry: REFUSE" "AC11: 펜스가 다른 묶음을 거부한다"
assert_contains "$out" "[spec-distill] 리뷰 없이 끝났다 — writing-plans 로 가기 전에" "AC11: 거부에 복귀 문장이 붙는다"
out="$(run_fence "$EF" "$SDROOT" "spec_path='$SPEC' bundle_arg='docs/rm/R3.md' repo_root='$W'")"
assert_contains "$(last "$out")" "bundle-entry: PROCEED " "AC12: 펜스가 통과 줄로 끝난다"
assert_contains "$out" "번호 대조 경고 1개" "AC12: 펜스가 경고 수를 보인다"
mkdir -p "$T/emptyroot"
out="$(run_fence "$EF" "$T/emptyroot" "spec_path='$SPEC' bundle_arg='docs/rm/R3.md' repo_root='$W'")"
assert_eq "$(last "$out")" "bundle-entry: PROCEED -" "스크립트가 없으면 대조 없이 리뷰한다고 말하고 통과한다(경고 1)"
assert_contains "$out" "번호 대조 진입 검사가 실패했다" "실패를 말한다"
out="$(run_fence "$NF_" "$SDROOT" "bundle_path='$W/docs/rm/R3.md' repo_root='$W'")"
assert_contains "$out" "로드맵 속 위치 — docs/rm/roadmap.md" "AC14: 위치 펜스가 위치를 낸다"
out="$(run_fence "$NF_" "$SDROOT" "bundle_path='-' repo_root='$W'")"
assert_eq "$out" "" "위치 펜스: 경로가 - 면 아무것도 내지 않는다"
INPUT_SEC="$(awk '/^## 입력$/{f=1;next} f&&/^## /{exit} f' "$SKILL")"
assert_contains "$INPUT_SEC" "--bundle" "AC11: ## 입력 이 --bundle 을 받는다"
assert_contains "$INPUT_SEC" "source_interview" "AC11: ## 입력 이 source_interview 대조를 말한다"
GATE_SEC="$(awk '/^## 게이트$/{f=1;next} f&&/^## /{exit} f' "$SKILL")"
assert_contains "$GATE_SEC" "번호 대조 경고" "AC12: 게이트가 번호 대조 경고 수를 「경고 N개」에 더한다"
assert_file_grep "$SKILL" '^argument-hint: .*--bundle' "argument-hint 에 --bundle"
DEG_SEC="$(awk '/^## degrade 채널$/{f=1;next} f&&/^## /{exit} f' "$SKILL")"
assert_contains "$DEG_SEC" "진입 펜스의 \`번호 대조 경고 <N>개\` 의 N 을 여기에 더한다" "AC12: degrade 채널의 N 규칙이 번호 대조 경고를 더한다"
assert_contains "$DEG_SEC" "번호 대조 경고 N 이 0 이 아니면 셋이 비었어도 「이상 없음」·「경고 없음」은 쓰지 않는다" "AC12: degrade 채널의 「이상 없음」 조건이 번호 대조 경고 0 을 요구한다"
finish
