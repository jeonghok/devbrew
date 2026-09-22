#!/usr/bin/env bash
# test_topic_boundary.sh — scripts/resolve-topic.sh (설계 §6.2, AC3·AC4·AC5·AC15·AC16).
#
# 각 케이스는 mktemp 아래 **일회용 git 리포**를 세운다 — 실제 리포에서 fixture git 실행 금지.
# 합성 토픽 픽스처 F1–F8(F5b 포함 9개) + 양성 대조 + 조립·nkeys 정합 케이스가 이 락의 이빨이다.
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
  assert_eq "$(field branches "$out" | tr ',' '\n' | grep -c .)" "2" "F1 branches 가 정확히 2개다"
  assert_not_grep "$(field branches "$out")" 'noise' "F1 선언 없는 noise 브랜치는 branches 에 없다"
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

# ── F5b: 조각 하나가 다른 조각의 리터럴 접두일 때도 구분돼야 한다 ───────────
#    #pr1 과 #pr2 는 끝 글자부터 다르므로 접두 관계가 아니다 — 끝 앵커를 빼도
#    이 둘로는 충돌을 못 만든다(F5 는 이 축을 재지 못한다). #pr1 은 #pr10 의
#    리터럴 접두다 — 끝 앵커가 실제로 막아야 하는 충돌은 이 모양이다.
case_f5b_prefix_fragment_collision() {
  new_repo
  git checkout -q -b topicA
  echo a1 > a.txt; git add a.txt
  git commit -qm "a1

Spec: docs/x-design.md#pr1"
  echo b1 > b.txt; git add b.txt
  git commit -qm "b1

Spec: docs/x-design.md#pr10"
  local out; out=$(bash "$RT" resolve 'docs/x-design.md#pr1')
  assert_eq "$(field declared "$out")" "1" "F5b #pr1 질의가 #pr10 을 매치하지 않는다"
  local out2; out2=$(bash "$RT" resolve 'docs/x-design.md#pr10')
  assert_eq "$(field declared "$out2")" "1" "F5b #pr10 질의는 자기 자신만 매치한다"
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

# ── nkeys 추출 정합 1/2: 진짜 트레일러의 다른 키는 여전히 잡는다 (약화 아님) ──
#    F7 과 같은 모양(빈 줄 + `Spec: <다른 키>`)이지만, 이 케이스는 명시적으로
#    「--grep 계열로 갈아도 진짜 트레일러 다른-키 검출력이 그대로다」를 잠근다 —
#    F2 가 nkeys 추출기를 트레일러 atom 에서 원시-메시지 매치로 바꾼 회귀 락이다.
case_nkeys_grep_family_catches_genuine_trailer() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  echo b1 > b.txt; git add b.txt
  git commit -qm "b1

Spec: docs/x-design.md#pr2"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "declaration-invalid" "nkeys: 진짜 트레일러의 다른 키는 여전히 declaration-invalid"
  cleanup
}

# ── nkeys 추출 정합 2/2: 소문자 spec: 트레일러는 거짓 declaration-invalid 를 안 낸다 ──
#    트레일러 atom(`%(trailers:key=Spec,valueonly)`)은 키를 대소문자 무시로 매치하므로
#    이 케이스에서 nkeys=2 로 부풀려 거짓 declaration-invalid 를 낸다. --grep 계열
#    (대소문자 구분)은 안 낸다. 구 구현(atom) 대비 RED 로 이빨을 증명한다.
case_nkeys_lowercase_trailer_no_false_positive() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  echo b1 > b.txt; git add b.txt
  git commit -qm "b1

spec: docs/other.md#zz"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "ok" "nkeys: 소문자 spec: 트레일러는 declaration-invalid 를 유발하지 않는다"
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
  # 봉인 커밋을 손으로 만든다 — 이 케이스는 resolve-topic.sh 만 잰다(seal-worktree.sh 에
  # 기대지 않는다).
  local SEAL; SEAL=$(git commit-tree "$TIPA^{tree}" -p "$TIPA" -m seal)

  local out0; out0=$(bash "$RT" resolve "$KEY")
  assert_not_contains "$(field tips "$out0")" "$TIPA" "F8 --seal 없으면 tip(A) 는 극대원소가 아니라 빠진다"
  assert_contains "$(field tips "$out0")" "$TIPB" "F8 tip(B) 는 끝점이다"

  local out1; out1=$(bash "$RT" resolve "$KEY" --seal "$SEAL")
  assert_contains "$(field tips "$out1")" "$SEAL" "F8 봉인을 먼저 넣으면 끝점에 든다"
  assert_not_contains "$(field tips "$out1")" "$TIPA" "F8 tip(A) 는 여전히 빠진다(조상이므로)"

  # ── F1(리뷰): 합성 봉인 커밋은 tips 의 끝점이지만 commits 의 원소가 아니다 ──
  #    ref 없는 합성 커밋이 「토픽 커밋」으로 세이면 GC 뒤 사라질 SHA 가 clean 튜플에
  #    낀다. tips 는 그대로 봉인을 담아야 한다(§6.2.4) — commits 만 뺀다.
  local cout1; cout1=$(bash "$RT" commits "$KEY" --seal "$SEAL")
  assert_not_contains "$cout1" "$SEAL" "F8 commits 는 봉인 SHA 를 포함하지 않는다(합성 커밋 제외)"
  assert_contains "$cout1" "$TIPB" "F8 commits 는 여전히 실제 토픽 커밋(tip B)을 포함한다"
  cleanup
}

# ── 봉인의 부모가 토픽 안 — seal_on_topic: yes (D1 disclosure) ──────────────
case_seal_on_topic_yes() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA "$R"; decl_commit a.txt a1 "a1"
  local TIPA; TIPA=$(git rev-parse HEAD)
  local SEAL; SEAL=$(git commit-tree "$TIPA^{tree}" -p "$TIPA" -m seal)
  local out; out=$(bash "$RT" resolve "$KEY" --seal "$SEAL")
  assert_eq "$(field status "$out")" "ok" "봉인-토픽안: status: ok"
  assert_eq "$(field seal_on_topic "$out")" "yes" "봉인-토픽안: seal_on_topic: yes(봉인의 부모가 B_t 구성원)"
  assert_contains "$(field tips "$out")" "$SEAL" "봉인-토픽안: tips 에 봉인 SHA 가 있다"
  cleanup
}

# ── 봉인의 부모가 토픽 밖 — seal_on_topic: no · status: ok · 오염 없음 ──────
#    A1/A2 회귀 락: 옛 구현은 `$MAXIMAL`(끝점 = tips ∪ 봉인)에서 T·nkeys 를 뽑아
#    봉인을 사후에 `grep -v -x -F` 로만 걷어냈다 — 봉인의 부모(outside 브랜치)가
#    끌고 온 조상 커밋은 그 후처리로 못 잡는다. `$BR_TIPS`(브랜치 집합 자체) 에서
#    뽑으면 outside 브랜치가 애초에 B_t 밖이라 안 들어온다.
case_seal_off_topic_excludes_commits() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA "$R"; decl_commit a.txt a1 "a1"
  local TIPA; TIPA=$(git rev-parse HEAD)
  git checkout -q -b outside "$R"
  echo o1 > o.txt; git add o.txt; git commit -qm "o1 (선언 없음, 토픽 밖)"
  local OUTSIDE_TIP; OUTSIDE_TIP=$(git rev-parse HEAD)
  git checkout -q topicA
  local SEAL; SEAL=$(git commit-tree "$OUTSIDE_TIP^{tree}" -p "$OUTSIDE_TIP" -m seal)

  local out; out=$(bash "$RT" resolve "$KEY" --seal "$SEAL")
  assert_eq "$(field status "$out")" "ok" "봉인-토픽밖: status: ok(진행하되 공시일 뿐 막지 않는다)"
  assert_eq "$(field seal_on_topic "$out")" "no" "봉인-토픽밖: seal_on_topic: no"
  assert_contains "$(field tips "$out")" "$SEAL" "봉인-토픽밖: tips 는 여전히 봉인 SHA 를 담는다(끝점 자격은 유지)"

  local cs; cs=$(bash "$RT" commits "$KEY" --seal "$SEAL")
  assert_eq "$(printf '%s\n' "$cs" | grep -c .)" "1" "봉인-토픽밖: commits 는 정확히 1개 — 토픽 자신의 커밋만"
  assert_contains "$cs" "$TIPA" "봉인-토픽밖: commits 에 topicA 자신의 커밋(TIPA)이 있다"
  assert_not_contains "$cs" "$OUTSIDE_TIP" "봉인-토픽밖: commits 에 outside 브랜치의 커밋이 없다(오염 없음)"
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

# ── B1: 원격-전용 미머지 구성원도 1단계가 받는다 (D2 재결정, §8) ────────────
#    선언 발견(C)은 `--all` 로 원격-추적 ref 까지 보는데 1단계가 `refs/heads` 만 보면
#    비대칭이 생겨 이 구성원이 고아(declaration-invalid)로 떨어진다. `git clone` 은
#    로컬에 main 만 만들므로 이것이 신선한 clone·CI 체크아웃의 기본 상태다.
case_remote_only_unmerged_member() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA "$R"; decl_commit a.txt a1 "a1"
  local TIPA; TIPA=$(git rev-parse HEAD)
  git update-ref refs/remotes/origin/topicA "$TIPA"
  git checkout -q main
  git branch -q -D topicA
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "ok" "원격-전용 미머지 구성원: status: ok(orphan 이 아니다)"
  assert_grep "$(field branches "$out")" 'origin/topicA' "원격-전용 미머지 구성원: branches 에 원격-추적 이름이 있다"
  cleanup
}

# ── B1: 로컬 브랜치와 그 원격-추적 대응이 같은 커밋 → 구성원 한 번만 ────────
case_local_and_remote_same_commit_dedup() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA "$R"; decl_commit a.txt a1 "a1"
  local TIPA; TIPA=$(git rev-parse HEAD)
  git update-ref refs/remotes/origin/topicA "$TIPA"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "ok" "로컬+원격 같은 커밋: status: ok"
  assert_eq "$(field branches "$out" | tr ',' '\n' | grep -c .)" "1" "로컬+원격 같은 커밋: branches 에 구성원이 한 번만"
  assert_eq "$(field branches "$out")" "topicA" "로컬+원격 같은 커밋: 로컬 이름이 이긴다(사전순으로 먼저 스캔됨)"
  cleanup
}

# ── 출력 계약: 10키가 «항상» 나온다 (seal_on_topic 이 열 번째 키) ───────────
case_ten_keys_always() {
  new_repo
  local out; out=$(bash "$RT" resolve "$KEY")
  local n; n=$(printf '%s\n' "$out" | grep -cE '^[a-z_]+:')
  assert_eq "$n" "10" "선언 0 인 리포에서도 10키 전부 emit"
  assert_eq "$(field seal_on_topic "$out")" "-" "--seal 없으면 seal_on_topic: -"
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

# ── PR4 조립: resolve 의 tips(콤마) 를 combine 이 실제로 받는다(공백) ────────
#    변환은 계획 문서에만 있고 두 스크립트 헤더·테스트 어디에도 없었다 — 두 스크립트가
#    실제로 물리는지는 이 케이스가 처음 잰다(cross-task seam).
case_resolve_tips_feed_combine() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA "$R"; decl_commit a.txt a1 "a1"
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  git checkout -q -b topicC "$R"; decl_commit c.txt c1 "c1"
  git checkout -q topicA
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "ok" "조립: resolve 가 status ok 를 낸다(전제 확인)"
  local cout; cout=$(bash "$CT" $(field tips "$out" | tr ',' ' '))
  assert_eq "$(field status "$cout")" "ok" "조립: resolve 의 tips(콤마) 를 combine(공백 인자) 이 받는다"
  local names; names=$(git ls-tree -r --name-only "$(field tree "$cout")")
  assert_grep "$names" '^a\.txt$' "조립: 합친 트리에 a.txt(구성원 A)"
  assert_grep "$names" '^b\.txt$' "조립: 합친 트리에 b.txt(구성원 B)"
  assert_grep "$names" '^c\.txt$' "조립: 합친 트리에 c.txt(구성원 C)"
  cleanup
}

for c in case_f1_two_siblings case_f1_boundary case_f2_merged_ref_alive \
         case_f2_boundary_merged_not_hidden case_f3_merged_ref_deleted \
         case_f4_undeclared_ancestor_included case_f5_fragment_discriminates \
         case_f5b_prefix_fragment_collision \
         case_f6_path_absent case_f7_mixed_keys_in_T \
         case_nkeys_grep_family_catches_genuine_trailer \
         case_nkeys_lowercase_trailer_no_false_positive \
         case_f8_seal_first_then_maximal \
         case_seal_on_topic_yes case_seal_off_topic_excludes_commits \
         case_tips_order_deterministic case_path_check_is_repo_root_relative \
         case_no_declaration \
         case_remote_only_unmerged_member case_local_and_remote_same_commit_dedup \
         case_ten_keys_always \
         case_combine_clean case_combine_conflict case_combine_edges \
         case_combine_three_clean case_combine_three_conflict_attribution \
         case_resolve_tips_feed_combine; do
  echo "== $c"; $c
done
finish
