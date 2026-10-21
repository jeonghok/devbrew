#!/usr/bin/env bash
# R5 AC30 · AC17 — devbrew 밖 버릴 레포(기본 브랜치 trunk · 접두 work/ · 폴더는 frontmatter)에서 지휘 순환의 기계 부분:
# 상태 → 표지 · 시작 승인 → 에픽 worktree → 설계문서 · 승인 줄 → 계획 → 구현 → 판정 · 구현 대조 절 → 스위트 대조 →
# 머지 → 정리 → 기계 상태를 지워도 같은 상태. 조사 에픽은 산출물로 단계가 매겨진다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_conductor_e2e.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
S="$ROOT/plugins/spec-distill/scripts"
FX="$ROOT/plugins/spec-distill/tests/fixtures/conductor-e2e"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 PYTHONDONTWRITEBYTECODE=1
python3 -m pytest --version >/dev/null 2>&1 || { no "pytest 가 없어 끝에서 끝을 걷지 못했다 — 이 기계에 pytest 를 깔고 다시 돈다"; finish; exit $?; }
W="$T/w"; RM="plan/rm/roadmap.md"; SID="session-e2e00001"
g() { git -C "$1" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "${@:2}"; }
L() { (cd "$W" && python3 "$S/conductor_ledger.py" "$@"); }
status_json() { (cd "$W" && python3 "$S/roadmap_status.py" --json "$RM"); }
field_of() {  # field_of <필드> <블록 id>
  status_json | python3 -I -c 'import json,sys; r=json.load(sys.stdin); print(next(b[sys.argv[1]] for b in r["blocks"] if b["id"]==sys.argv[2]))' "$1" "$2"
}
stage_of() { field_of stage "$1"; }
reason_of() { field_of reason "$1"; }
tasks_of() { (cd "$W" && python3 "$S/control_plane.py" show --tasks "$RM"); }

git init -q --bare -b trunk "$T/o.git"
git clone -q "$T/o.git" "$W" 2>/dev/null; g "$W" checkout -q -B trunk
mkdir -p "$W/plan/rm" "$W/plan/br" "$W/src" "$W/tests"
cp "$FX/roadmap.md" "$FX/E1.md" "$FX/E2.md" "$W/plan/rm/"; cp "$FX/b.md" "$FX/b.audit.md" "$W/plan/br/"
printf '[pytest]\n' > "$W/pytest.ini"
printf 'def core():\n    return 1\n' > "$W/src/core.py"
printf 'import sys, os\nsys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))\nimport core\n\ndef test_core():\n    assert core.core() == 1\n' > "$W/tests/test_core.py"
g "$W" add -A; g "$W" commit -qm base; g "$W" push -q origin trunk; g "$W" remote set-head origin --auto >/dev/null

# 1 — 상태 · 작업 목록(기본 브랜치 trunk)
tasks="$(tasks_of)"; rc=$?
assert_eq "$rc" "0" "작업 목록 rc 0(기본 브랜치 trunk)"
assert_contains "$tasks" "E1" "작업 목록에 E1"
assert_eq "$(stage_of E1)" "준비" "E1 준비"

# 2 — 표지 · 시작 승인(같은 규모면 공시만)
L claim --roadmap "$RM" --session "$SID" >/dev/null
SCALE="남은 에픽 2(E1 · E2) · agent 약 6 · 순서 E1 → E2"
L approval --roadmap "$RM" --session "$SID" --scale "$SCALE" >/dev/null; assert_eq "$?" "1" "처음엔 승인 필요"
L approve --roadmap "$RM" --session "$SID" --scale "$SCALE" >/dev/null
assert_contains "$(L approval --roadmap "$RM" --session "$SID" --scale "$SCALE")" "공시만" "같은 세션 · 같은 규모면 공시만"

# 3 — 에픽 worktree(하니스 폴더 · 접두 work/) · 자원 기록
WT="$(L worktree-path --name e1)"
g "$W" worktree add -q "$WT" -b work/e1 origin/HEAD
L add --roadmap "$RM" --session "$SID" --section 자원 --cells "worktree · $WT · E1 · 설계 · t" >/dev/null
mkdir -p "$WT/plan/specs"
printf -- '---\nsource_interview: plan/rm/E1.md\nroadmap: plan/rm/roadmap.md\n---\n\n# E1 설계\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| C1 | 반영 | AC1 |\n| S1 | 반영 | AC1 |\n| OQ1 | 반영 | AC1 |\n\n## Acceptance Criteria\n\n- AC1 core 가 1 을 낸다\n' > "$WT/plan/specs/e1-design.md"
g "$WT" add -A; g "$WT" commit -qm spec
assert_eq "$(stage_of E1)" "설계 중" "설계문서 → 설계 중"
assert_eq "$(reason_of E1)" "spec 있음" "승인 전 근거"

# 4 — 승인 줄 → 근거가 승인됨
L record --spec "$WT/plan/specs/e1-design.md" --approval --date 2026-10-18 --choice "승인 — 계획 담당자에게" >/dev/null
g "$WT" add -A; g "$WT" commit -qm approval
assert_eq "$(reason_of E1)" "spec 승인됨(2026-10-18) · 계획 없음" "승인 줄 → 근거가 승인됨"

# 5 — 계획 → 구현(Spec 트레일러) → 판정 · 구현 대조 절 → 구현 끝
mkdir -p "$WT/plan/plans"; printf '# 계획\n\n**Spec:** plan/specs/e1-design.md\n' > "$WT/plan/plans/e1.md"
g "$WT" add -A; g "$WT" commit -qm plan
assert_eq "$(stage_of E1)" "계획" "계획 → 계획"
printf 'def core():\n    return 1  # e1\n' > "$WT/src/core.py"; g "$WT" add -A
g "$WT" commit -qm "feat: e1" -m "Spec: plan/specs/e1-design.md"
assert_eq "$(stage_of E1)" "구현 중" "Spec 트레일러 커밋 → 구현 중"
printf 'Rulings I made:\n- Ruling: 작은 판정 — 이유 — 비용\nAC1: 구현됨 — core\n' > "$T/report.md"
L rulings --report "$T/report.md" --out "$T/rulings.md" >/dev/null; assert_eq "$?" "0" "판정 거두기"
L write-sections --spec "$WT/plan/specs/e1-design.md" --plan plan/plans/e1.md --rulings "$T/rulings.md" \
  --impl-line "경고 없음 (AC 1개)" --counts "AC 1개 중 구현됨 1 · 미룸 0 · 빠짐 0" >/dev/null
assert_eq "$?" "0" "판정 · 구현 대조 절 쓰기(거둔 판정 파일에는 판정 줄만 있다)"
g "$WT" add -A; g "$WT" commit -qm records
assert_eq "$(stage_of E1)" "구현 끝" "구현 대조 절 → 구현 끝"

# 6 — 스위트 대조(pytest · 새 실패 없음)
out="$(cd "$W" && python3 "$S/merge_check.py" run --roadmap "$RM" --branch work/e1 --no-fetch)"; rc=$?
assert_eq "$rc" "0" "스위트 대조 rc 0: $out"
assert_contains "$out" "pytest" "스위트 대조가 탐지한 러너는 pytest"

# 7 — 조사 에픽: 산출물이 브랜치에 생기면 설계 중
WT2="$(L worktree-path --name e2)"
g "$W" worktree add -q "$WT2" -b work/e2 origin/HEAD
assert_eq "$(reason_of E2)" "브랜치 있음 · spec 없음" "조사 에픽: 브랜치만으로는 산출물이 없다"
mkdir -p "$WT2/plan/research"
printf '# E2 조사\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| «e2e-k» | 반영 | 조사 결과 |\n| K1 | 반영 | 조사 결과 |\n' > "$WT2/plan/research/e2.md"
g "$WT2" add -A; g "$WT2" commit -qm research
assert_eq "$(stage_of E2)" "설계 중" "조사 에픽: 산출물 → 설계 중"
assert_eq "$(reason_of E2)" "spec 있음" "조사 에픽: 산출물이 spec 으로 읽힌다"

# 8 — 머지(사용자 몫을 흉내) → 머지됨 → 정리(브랜치는 남는다) → 주인 모름은 E2 worktree
g "$W" merge -q --no-ff work/e1 -m "Merge pull request #1 from o/work/e1"; g "$W" push -q origin trunk; g "$W" fetch -q origin
assert_eq "$(stage_of E1)" "머지됨" "머지 → 머지됨"
L cleanup --roadmap "$RM" --session "$SID" --path "$WT" >/dev/null; assert_eq "$?" "0" "E1 worktree 정리"
[ -d "$WT" ] && no "정리했는데 worktree 가 남았다" || ok "E1 worktree 를 지웠다"
assert_contains "$(g "$W" branch --list work/e1)" "work/e1" "브랜치는 지우지 않는다"
assert_contains "$(L orphans --roadmap "$RM")" "work/e2" "기계 상태에 없는 E2 worktree 는 주인 모름"

# 9 — 기계 상태를 지워도 상태는 git 에서 같다(AC17): 작업 목록 출력(`show --tasks` 의 줄 전부)을 지우기 전후로 통째 비교
L add --roadmap "$RM" --session "$SID" --section 자원 --cells "worktree · $WT2 · E2 · 조사 · t" >/dev/null
assert_not_contains "$(L orphans --roadmap "$RM")" "work/e2" "자원에 적은 E2 worktree 는 주인 모름이 아니다"
before="$(tasks_of)"
SP="$(cd "$W" && python3 "$S/conductor_state.py" path --roadmap "$RM")"
[ -n "$before" ] && ok "비교할 작업 줄이 있다(빈 둘을 같다고 보지 않는다)" || no "작업 줄이 비어 있다"
[ -f "$SP" ] && ok "지우기 전에 기계 상태 파일이 있다" || no "기계 상태 파일이 없다: $SP"
rm -f -- "$SP"
after="$(tasks_of)"
assert_eq "$after" "$before" "기계 상태를 지워도 작업 목록이 같다"
assert_contains "$(L orphans --roadmap "$RM")" "work/e2" "기계 상태를 잃으면 E2 worktree 는 주인 모름으로 다시 드러난다"
L claim --roadmap "$RM" --session "$SID" >/dev/null
L approval --roadmap "$RM" --session "$SID" --scale "$SCALE" >/dev/null; assert_eq "$?" "1" "기계 상태를 잃으면 시작 승인을 다시 묻는다"

# 10 — 레포 전용 값이 박혀 있지 않다: 이 레포에는 main · feature/ · docs/superpowers 가 없다
assert_eq "$(g "$W" branch -a --list '*main*' | wc -l | tr -d ' ')" "0" "버릴 레포에 main 브랜치가 없다"
[ -d "$W/docs" ] && no "버릴 레포에 docs 폴더가 생겼다(기본 폴더를 박은 곳이 있다)" || ok "기본 폴더를 쓰지 않았다(frontmatter 폴더만)"
rs="$(status_json)"
assert_eq "$(printf '%s' "$rs" | python3 -I -c 'import json,sys; s=json.load(sys.stdin)["settings"]["sources"]; print(s["specs_dir"], s["plans_dir"])')" "로드맵 로드맵" "설계문서 · 계획 폴더는 로드맵 머리말에서 읽었다(출처 로드맵)"
assert_eq "$(printf '%s' "$rs" | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["default_branch"])')" "origin/trunk" "기본 브랜치는 origin/trunk 로 읽혔다"
finish
