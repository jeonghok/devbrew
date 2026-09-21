#!/usr/bin/env bash
# test_topic_boundary.sh — scripts/resolve-topic.sh (설계 §6.2, AC3·AC4·AC5·AC15·AC16).
#
# 각 케이스는 mktemp 아래 **일회용 git 리포**를 세운다 — 실제 리포에서 fixture git 실행 금지.
# 합성 토픽 픽스처 F1–F8 + Task 6 의 양성 대조가 이 락의 이빨이다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RT="$PLUGIN_ROOT/scripts/resolve-topic.sh"
CT="$PLUGIN_ROOT/scripts/combine-tips.sh"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

KEY='docs/x-design.md#pr1'
REPO=""
cleanup() { cd / && rm -rf "$REPO"; }

new_repo() {   # 빈 리포 + main 두 커밋(둘째가 $KEY 의 선언 대상 경로). CWD = 리포
  # AC16 은 선언이 가리키는 경로가 실재해야 "ok" 로 간다 — $KEY 의 경로
  # (docs/x-design.md) 를 여기서 만들어 두지 않으면 F1·F2·F3 의 "status: ok"
  # 기대치가 원리적으로 도달 불가능해진다(모든 브랜치가 이 커밋의 후손이라
  # working tree 에 상속된다).
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q .
  git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo r0 > f.txt; git add f.txt; git commit -qm r0
  mkdir -p docs; echo '# design' > docs/x-design.md
  git add docs/x-design.md; git commit -qm "add design doc"
}

decl_commit() {   # <파일> <내용> <메시지> — 토픽 선언 트레일러를 단 커밋
  echo "$2" > "$1"; git add "$1"
  git commit -qm "$3

Spec: $KEY"
}

# ── F1: 형제 브랜치 둘이 같은 토픽을 선언 → 한 집합 (AC3) ──────────────────
case_f1_two_siblings() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  git checkout -q topicA
  git checkout -q -b noise "$R"; echo n > n.txt; git add n.txt; git commit -qm "noise (선언 없음)"
  git checkout -q topicA
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "ok" "F1 status: ok"
  assert_eq "$(field declared "$out")" "2" "F1 선언 커밋 2"
  assert_grep "$(field branches "$out")" 'topicA' "F1 branches 에 topicA"
  assert_grep "$(field branches "$out")" 'topicB' "F1 branches 에 topicB"
  cleanup
}

# ── F2: 구성원 하나가 머지됨 + ref 살아 있음 → 여전히 포함 (AC4) ────────────
#    라운드 2 재비판이 잡은 회귀의 회귀 락이다: 1단계는 tip 이 base 의 조상이라
#    떨어뜨리고, 2단계 발동 조건이 「살아 있는 ref 에 안 걸리면」이면 여기서
#    발동하지 않아 고아로 떨어진다. 조건은 「1단계가 낸 B_t 에 안 들어가면」이다.
case_f2_merged_ref_alive() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q main
  git merge -q --no-ff -m "merge topicA" topicA     # ref 는 그대로 둔다
  # topicB 는 R(머지 전)에서 분기한다 — HEAD(머지 후 main)에서 분기하면 topicB 가
  # a1 을 조상으로 자연 상속해 2단계(머지된 구성원 탐지)가 아예 발동하지 않는다.
  # 그러면 이 케이스가 잠그려는 회귀(주석 참고)를 스테이지-1 만으로 우연히 통과시켜
  # 락의 이빨이 없어진다.
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "ok" "F2 status: ok"
  assert_eq "$(field declared "$out")" "2" "F2 선언 커밋 2"
  assert_grep "$(field branches "$out")" 'merged:|topicA' "F2 머지된 구성원이 branches 에 있다"
  cleanup
}

# ── F3: 구성원 하나가 머지되고 ref 도 삭제됨 → 2단계가 받는다 (AC4) ─────────
case_f3_merged_ref_deleted() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q main
  git merge -q --no-ff -m "merge topicA" topicA
  git branch -q -D topicA
  # topicB 는 R(머지 전)에서 분기한다 — F2 와 같은 이유(위 주석).
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "ok" "F3 status: ok"
  assert_grep "$(field branches "$out")" 'merged:' "F3 ref 삭제된 구성원을 merged: 로 받는다"
  cleanup
}

# ── F5: 조각은 서로 다른 토픽이다 (D1.4) ────────────────────────────────────
case_f5_fragment_discriminates() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  echo b1 > b.txt; git add b.txt
  git commit -qm "b1

Spec: docs/x-design.md#pr2"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field declared "$out")" "1" "F5 #pr1 질의가 #pr2 를 매치하지 않는다"
  local out2; out2=$(bash "$RT" resolve 'docs/x-design.md')
  assert_eq "$(field status "$out2")" "no-declaration" "F5 맨 경로 질의는 조각을 매치하지 않는다"
  cleanup
}

# ── F6: 트레일러는 있는데 가리키는 경로가 실재하지 않음 (AC16) ──────────────
case_f6_path_absent() {
  new_repo
  git checkout -q -b topicA
  echo a1 > a.txt; git add a.txt
  git commit -qm "a1

Spec: docs/nonexistent-design.md#pr1"
  local out; out=$(bash "$RT" resolve 'docs/nonexistent-design.md#pr1')
  assert_eq "$(field status "$out")" "declaration-invalid" "F6 경로 부재 → declaration-invalid"
  assert_grep "$(field reason "$out")" '.' "F6 사유가 비어 있지 않다"
  cleanup
}

# ── path 체크는 repo-root-relative 다 (컨트롤러 Ruling 2 회귀 락) ──────────
#    브리프 원안의 cwd-relative 검사(`[ -e "$path" ]`)는 하위 디렉터리에서 부르면
#    거짓 declaration-invalid 를 낸다. 다른 모든 케이스는 cwd == repo root 라서
#    이 차이를 구분 못 한다 — 이 케이스만 cwd != repo root 를 만들어 구분한다.
case_path_check_is_repo_root_relative() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  mkdir -p sub/dir; cd sub/dir
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "ok" "하위 디렉터리에서 호출해도 declared path 는 repo-root 기준으로 resolve 된다"
  cleanup
}

# ── F1 의 경계 (AC5) — 형제 둘의 fork 가 같으므로 경계 = 분기점 ─────────────
case_f1_boundary() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  git checkout -q topicA
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field boundary "$out")" "$R" "F1 경계 = 두 fork 의 merge-base = 분기점"
  assert_eq "$(field commits "$out")" "2" "F1 |T| = 2"
  cleanup
}

# ── F2 의 경계 (AC4+AC5) — 머지된 구성원이 경계 뒤로 숨으면 안 된다 ──────────
#    구성원이 «하나»뿐이고 그것이 이미 머지된 지형이어야 두 규칙이 갈린다.
#    다른 구성원이 그 머지의 후손이면 1단계가 선언 커밋을 흡수해 2단계가
#    발화하지 않고, 형제 구성원이 있으면 merge-base 가 같은 답으로 되돌아간다.
case_f2_boundary_merged_not_hidden() {
  new_repo
  echo r1 >> f.txt; git commit -qam r1
  local FORKPT; FORKPT=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  local TIPA; TIPA=$(git rev-parse HEAD)
  git checkout -q main
  echo r2 >> f.txt; git commit -qam r2          # main 이 토픽과 무관하게 앞으로 나간다
  git merge -q --no-ff -m "merge topicA" topicA
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_grep "$(field branches "$out")" 'merged:' "F2 경계: 2단계가 발화했다(전제 확인)"
  assert_eq "$(field boundary "$out")" "$FORKPT" "F2 경계 = 머지된 구성원의 진짜 분기점"
  assert_not_contains "$(field boundary "$out")" "$TIPA" "F2 경계가 머지된 tip 이 아니다"
  cleanup
}

# ── F4: 선언 없는 조상 커밋도 브랜치 소속으로 들어온다 (§6.2.2) ─────────────
#    R→A→B 에서 B 에만 트레일러를 붙여도 A 가 T 에 들어야 한다. 안 그러면
#    A 의 회귀가 선재 결함으로 숨는다.
case_f4_undeclared_ancestor_included() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA
  echo a1 > a.txt; git add a.txt; git commit -qm "a1 (선언 없음)"
  decl_commit b.txt b1 "b1"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field boundary "$out")" "$R" "F4 경계 = 브랜치 분기점(선언 커밋이 아니다)"
  assert_eq "$(field commits "$out")" "2" "F4 선언 없는 조상 a1 도 T 에 든다"
  local cs; cs=$(bash "$RT" commits "$KEY")
  assert_eq "$(printf '%s\n' "$cs" | grep -c .)" "2" "F4 commits 서브커맨드도 2줄"
  cleanup
}

# ── F7: 토픽 커밋 집합이 서로 다른 토픽 키를 함께 담음 (AC16) ───────────────
case_f7_mixed_keys_in_T() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  echo b1 > b.txt; git add b.txt
  git commit -qm "b1

Spec: docs/x-design.md#pr2"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "declaration-invalid" "F7 한 집합에 두 토픽 키 → declaration-invalid"
  local cout crc
  cout=$(bash "$RT" commits "$KEY" 2>/dev/null); crc=$?
  assert_eq "$crc" "3" "F7 status != ok 이면 commits 는 exit 3 (fail-closed)"
  assert_eq "$cout" "" "F7 commits 가 stdout 에 아무것도 내지 않는다"
  cleanup
}

# ── F8: 끝점 = 봉인을 «먼저 넣고» 극대원소 (AC6) ────────────────────────────
#    스택 A→B 에서 현재 체크아웃이 A 면 tip(A) 는 tip(B) 의 조상이라 극대원소가
#    아니다 — 「끝점 중 현재 브랜치 것을 치환」할 자리가 없다. 봉인을 먼저 넣으면
#    그 자신이 극대원소로 선다.
case_f8_seal_first_then_maximal() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  local TIPA; TIPA=$(git rev-parse HEAD)
  git checkout -q -b topicB; decl_commit b.txt b1 "b1"
  local TIPB; TIPB=$(git rev-parse HEAD)
  git checkout -q topicA
  # 봉인 커밋을 손으로 만든다 — seal-worktree.sh 는 Task 4 다(이 Task 는 그것에 기대지 않는다).
  local SEAL; SEAL=$(git commit-tree "$TIPA^{tree}" -p "$TIPA" -m seal)

  local out0; out0=$(bash "$RT" resolve "$KEY")
  assert_not_contains "$(field tips "$out0")" "$TIPA" "F8 --seal 없으면 tip(A) 는 극대원소가 아니라 빠진다"
  assert_contains "$(field tips "$out0")" "$TIPB" "F8 tip(B) 는 끝점이다"

  local out1; out1=$(bash "$RT" resolve "$KEY" --seal "$SEAL")
  assert_contains "$(field tips "$out1")" "$SEAL" "F8 봉인을 먼저 넣으면 끝점에 든다"
  assert_not_contains "$(field tips "$out1")" "$TIPA" "F8 tip(A) 는 여전히 빠진다(조상이므로)"
  cleanup
}

# ── 끝점 순서 결정론: «발견 순서» 와 무관해야 한다 ──────────────────────────
#    같은 스크립트를 두 번 부르는 것으로는 못 잰다 — 리포가 안 바뀌면 정규화가
#    없어도 같은 답이 나온다. 브랜치를 개명하면 SHA 는 그대로인 채
#    `git for-each-ref` 열거 순서가 바뀌므로, 그때도 같은 순서여야 한다.
case_tips_order_deterministic() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b zzz "$R"; decl_commit z.txt z "z"
  git checkout -q -b aaa "$R"; decl_commit a.txt a "a"
  git checkout -q -b mmm "$R"; decl_commit m.txt m "m"
  git checkout -q main
  local o1; o1=$(field tips "$(bash "$RT" resolve "$KEY")")
  git branch -m zzz b_zzz; git branch -m aaa y_aaa; git branch -m mmm a_mmm
  local o2; o2=$(field tips "$(bash "$RT" resolve "$KEY")")
  assert_eq "$o2" "$o1" "브랜치 개명으로 발견 순서가 바뀌어도 tips 순서가 같다"
  assert_eq "$(printf '%s' "$o1" | tr ',' '\n' | grep -c .)" "3" "끝점 3개"
  cleanup
}

# ── 선언이 아예 없는 리포 ───────────────────────────────────────────────────
case_no_declaration() {
  new_repo
  git checkout -q -b topicA
  echo a1 > a.txt; git add a.txt; git commit -qm "a1 (선언 없음)"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "no-declaration" "선언 0 → no-declaration"
  assert_eq "$(field declared "$out")" "0" "declared: 0"
  local cout crc
  cout=$(bash "$RT" commits "$KEY" 2>/dev/null); crc=$?
  assert_eq "$crc" "3" "no-declaration 이면 commits 는 exit 3 (fail-closed)"
  assert_eq "$cout" "" "no-declaration 이면 commits 가 stdout 에 아무것도 내지 않는다"
  cleanup
}

# ── 출력 계약: 9키가 «항상» 나온다 ──────────────────────────────────────────
case_nine_keys_always() {
  new_repo
  local out; out=$(bash "$RT" resolve "$KEY")
  local n; n=$(printf '%s\n' "$out" | grep -cE '^[a-z_]+:')
  assert_eq "$n" "9" "선언 0 인 리포에서도 9키 전부 emit"
  local rc; bash "$RT" resolve "$KEY" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "0" "정상 경로 exit 0"
  cleanup
}

# ── 합치기 정상: 겹치지 않는 두 끝점 → 트리 하나 (AC6) ─────────────────────
case_combine_clean() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"; local TA; TA=$(git rev-parse HEAD)
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"; local TB; TB=$(git rev-parse HEAD)
  local out; out=$(bash "$CT" "$TA" "$TB")
  assert_eq "$(field status "$out")" "ok" "합치기 정상 → status: ok"
  assert_eq "$(field steps "$out")" "1" "끝점 둘 → merge-tree 1회"
  assert_grep "$(field tree "$out")" '^[0-9a-f]{40}$' "트리 OID 한 개"
  # 합친 트리가 양쪽 파일을 다 갖는다
  local names; names=$(git ls-tree -r --name-only "$(field tree "$out")")
  assert_grep "$names" '^a\.txt$' "합친 트리에 a.txt"
  assert_grep "$names" '^b\.txt$' "합친 트리에 b.txt"
  assert_grep "$(field intermediates "$out")" '^[0-9a-f]{40}$' "중간 커밋 SHA 가 나온다"
  cleanup
}

# ── 합치기 충돌: status · 충돌 파일 · 귀속 (AC7) ────────────────────────────
case_combine_conflict() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit f.txt AAA "a"; local TA; TA=$(git rev-parse HEAD)
  git checkout -q -b topicB "$R"; decl_commit f.txt BBB "b"; local TB; TB=$(git rev-parse HEAD)
  local out; out=$(bash "$CT" "$TA" "$TB")
  assert_eq "$(field status "$out")" "merge-conflict" "충돌 → status: merge-conflict"
  assert_eq "$(field tree "$out")" "-" "충돌이면 트리를 내지 않는다"
  assert_eq "$(field conflicts "$out")" "f.txt" "충돌 파일 목록"
  assert_eq "$(field failed_at "$out")" "$TB" "충돌을 일으킨 구성원이 귀속된다(순차의 이득)"
  cleanup
}

# ── 끝점 하나 · 나쁜 입력 ───────────────────────────────────────────────────
case_combine_edges() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"; local TA; TA=$(git rev-parse HEAD)
  local out; out=$(bash "$CT" "$TA")
  assert_eq "$(field status "$out")" "ok" "끝점 하나도 정상"
  assert_eq "$(field steps "$out")" "0" "끝점 하나 → merge-tree 0회"
  assert_eq "$(field tree "$out")" "$(git rev-parse "$TA^{tree}")" "끝점 하나면 그 트리 그대로"
  assert_eq "$(field intermediates "$out")" "-" "중간 커밋 없음"

  local out2; out2=$(bash "$CT" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef")
  assert_eq "$(field status "$out2")" "bad-input" "없는 커밋 → bad-input"
  local out3; out3=$(bash "$CT")
  assert_eq "$(field status "$out3")" "bad-input" "인자 0 → bad-input"

  local n; n=$(printf '%s\n' "$out3" | grep -cE '^[a-z_]+:')
  assert_eq "$n" "6" "bad-input 에서도 6키 전부 emit"
  cleanup
}

# ── 합치기 정상: 끝점 셋 → 누적기가 진짜 자란다 (AC6, 순차 2+ 스텝) ─────────
#    Fix round 1 — 두-끝점 케이스만으로는 sequential accumulation 자체(스텝이
#    누적되는지, N-1 회 도는지)가 안 잠긴다. 형제 셋을 겹치지 않게 붙여
#    steps: N-1 과 intermediates 개수·트리에 세 파일 전부를 확인한다.
case_combine_three_clean() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA "$R"; decl_commit a.txt a1 "a1"; local TA; TA=$(git rev-parse HEAD)
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"; local TB; TB=$(git rev-parse HEAD)
  git checkout -q -b topicC "$R"; decl_commit c.txt c1 "c1"; local TC; TC=$(git rev-parse HEAD)
  local out; out=$(bash "$CT" "$TA" "$TB" "$TC")
  assert_eq "$(field status "$out")" "ok" "끝점 셋 합치기 → status: ok"
  assert_eq "$(field steps "$out")" "2" "끝점 셋 → merge-tree 2회(N-1) — 누적이 실제로 돈다"
  local inter; inter=$(field intermediates "$out")
  assert_eq "$(printf '%s' "$inter" | tr ',' '\n' | grep -c .)" "2" "중간 커밋 2개(스텝마다 하나)"
  assert_grep "$inter" '^[0-9a-f]{40},[0-9a-f]{40}$' "중간 커밋 둘 다 40-hex SHA"
  local names; names=$(git ls-tree -r --name-only "$(field tree "$out")")
  assert_grep "$names" '^a\.txt$' "합친 트리에 a.txt(1차 누적)"
  assert_grep "$names" '^b\.txt$' "합친 트리에 b.txt(1차 누적)"
  assert_grep "$names" '^c\.txt$' "합친 트리에 c.txt(2차 누적 — 누적기가 앞 결과를 버리지 않는다)"
  cleanup
}

# ── 합치기 충돌 — 셋 중 «둘째»에서 충돌 (귀속이 "마지막 인자" 함정을 피함) ──
#    Fix round 1 — 끝점 둘짜리 충돌 케이스는 failed_at 이 유일하게 tip2 (=
#    마지막 인자) 값 하나만 취할 수 있어, 「진짜 실패한 스텝의 tip」과
#    「그냥 마지막 인자」를 구분 못 한다. 셋째 끝점(TC, 무관)을 더해
#    첫 스텝(acc=TA, tip=TB)에서 충돌시키면 failed_at 이 TB(끝에서 둘째)여야
#    하고 TC(마지막 인자)여서는 안 된다 — 이 비대칭이 귀속을 정말 잠근다.
case_combine_three_conflict_attribution() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA "$R"; decl_commit f.txt AAA "a"; local TA; TA=$(git rev-parse HEAD)
  git checkout -q -b topicB "$R"; decl_commit f.txt BBB "b"; local TB; TB=$(git rev-parse HEAD)
  git checkout -q -b topicC "$R"; decl_commit c.txt c1 "c1"; local TC; TC=$(git rev-parse HEAD)
  local out; out=$(bash "$CT" "$TA" "$TB" "$TC")
  assert_eq "$(field status "$out")" "merge-conflict" "셋 중 첫 스텝(TA·TB)이 충돌 → status: merge-conflict"
  assert_eq "$(field steps "$out")" "1" "충돌은 첫 merge-tree 호출(acc=TA, tip=TB)에서 남 — steps: 1"
  assert_eq "$(field failed_at "$out")" "$TB" "귀속은 실제로 충돌시킨 tip(TB) — 「마지막 인자」가 아니다"
  assert_not_contains "$(field failed_at "$out")" "$TC" "failed_at 이 마지막 인자(TC)가 아님을 명시적으로 못박는다"
  cleanup
}

for c in case_f1_two_siblings case_f1_boundary case_f2_merged_ref_alive \
         case_f2_boundary_merged_not_hidden case_f3_merged_ref_deleted \
         case_f4_undeclared_ancestor_included case_f5_fragment_discriminates \
         case_f6_path_absent case_f7_mixed_keys_in_T case_f8_seal_first_then_maximal \
         case_tips_order_deterministic case_path_check_is_repo_root_relative \
         case_no_declaration case_nine_keys_always \
         case_combine_clean case_combine_conflict case_combine_edges \
         case_combine_three_clean case_combine_three_conflict_attribution; do
  echo "== $c"; $c
done
finish
