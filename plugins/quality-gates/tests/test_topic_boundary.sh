#!/usr/bin/env bash
# test_topic_boundary.sh — scripts/resolve-topic.sh (설계 §6.2, AC3·AC4·AC5·AC15·AC16).
#
# 각 케이스는 mktemp 아래 **일회용 git 리포**를 세운다 — 실제 리포에서 fixture git 실행 금지.
# 합성 토픽 픽스처 F1–F8 + Task 6 의 양성 대조가 이 락의 이빨이다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RT="$PLUGIN_ROOT/scripts/resolve-topic.sh"
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

# (F4 · F7 · F8 은 Task 3 이 더한다 — 셋 다 경계 또는 T 가 있어야 잴 수 있다.)

# ── 선언이 아예 없는 리포 ───────────────────────────────────────────────────
case_no_declaration() {
  new_repo
  git checkout -q -b topicA
  echo a1 > a.txt; git add a.txt; git commit -qm "a1 (선언 없음)"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "no-declaration" "선언 0 → no-declaration"
  assert_eq "$(field declared "$out")" "0" "declared: 0"
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

for c in case_f1_two_siblings case_f2_merged_ref_alive case_f3_merged_ref_deleted \
         case_f5_fragment_discriminates case_f6_path_absent \
         case_path_check_is_repo_root_relative \
         case_no_declaration case_nine_keys_always; do
  echo "== $c"; $c
done
finish
