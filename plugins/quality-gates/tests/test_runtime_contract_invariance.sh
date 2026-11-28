#!/usr/bin/env bash
# test_runtime_contract_invariance.sh — create-baseline + 기존 계약 바이트 무변경.
# AC7 AC24 AC25 AC26 · T5 T18
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
WT="$PLUGIN_ROOT/scripts/qg-worktree.sh"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

REPO=""

# T5 + AC7: create-baseline이 merge_base에 detached worktree를 만들고 경로를 emit
case_create_baseline() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo v1 > a.txt; git add a.txt; git commit -qm v1
  local base_sha; base_sha=$(git rev-parse HEAD)
  git checkout -q -b feature
  echo v2 > a.txt; git commit -qam v2

  local out rc; out=$(bash "$WT" create-baseline "$base_sha" "sess1234"); rc=$?
  if [[ $rc -ne 0 || ! -d "$out" ]]; then
    no "create-baseline (rc=$rc out='$out')"; cd / && rm -rf "$REPO"; return
  fi
  ok "create-baseline → 워크트리 경로 emit"

  # 네임스페이스: worktrees/ 아래여야 remove 가드가 적용된다
  case "$out" in
    */.claude/worktrees/qg-*) ok "worktrees/ 네임스페이스 안" ;;
    *) no "네임스페이스 밖: $out" ;;
  esac
  # 내용이 merge_base 상태인가 (HEAD의 v2가 아니라 v1)
  [[ "$(cat "$out/a.txt")" == "v1" ]] && ok "기준선 트리 내용 == merge_base" \
                                      || no "기준선 내용 오염 ($(cat "$out/a.txt"))"
  # detached HEAD인가
  ( cd "$out" && ! git symbolic-ref --quiet HEAD >/dev/null 2>&1 ) \
    && ok "기준선 워크트리는 detached" || no "detached 아님"
  # remove가 동작 (네임스페이스 가드 통과)
  bash "$WT" remove "$out" && [[ ! -d "$out" ]] && ok "remove 적용됨" || no "remove 실패"
  cd / && rm -rf "$REPO"
}

# 같은 세션으로 create-baseline 을 두 번 불러도 두 번째가 같은 자리에 트리를 다시 만드는가.
# 이것을 안 재면 게이트가 두 번째 실행부터 영구히 죽는 회귀를 못 잡는다.
case_create_baseline_is_still_idempotent() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo v1 > a.txt; printf '/target\n' > .gitignore
  git add a.txt .gitignore; git commit -qm v1
  local base_sha; base_sha=$(git rev-parse HEAD)
  git checkout -q -b feature; echo v2 > a.txt; git commit -qam v2

  local first second rc
  first=$(bash "$WT" create-baseline "$base_sha" "sess9999" 2>/dev/null)
  # 앞선 실행이 남긴 **git-ignored 빌드 산출물**이 있는 상태가 정상 경로다
  # (cargo/venv 산출물은 전부 ignored 로 떨어진다). 여기서 막히면 게이트가 두 번째
  # 실행부터 영구히 죽는다.
  mkdir -p "$first/target/debug" && : > "$first/target/debug/x.o"
  second=$(bash "$WT" create-baseline "$base_sha" "sess9999" 2>/dev/null); rc=$?
  if [[ $rc -eq 0 && "$second" == "$first" && -d "$second" ]]; then
    ok "clean 한 기준선 트리 재실행은 그대로 성공 (idempotent 보존)"
  else
    no "idempotent 회귀 (rc=$rc first='$first' second='$second')"
  fi
  cd / && rm -rf "$REPO"
}

# 네임스페이스 밖 경로는 remove가 거부한다 (기존 가드가 새 경로에도 유효한지 확인)
case_remove_namespace_guard() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  echo x > a.txt; git add a.txt; git commit -qm x
  mkdir -p "$REPO/outside"
  bash "$WT" remove "$REPO/outside" >/dev/null 2>&1 \
    && no "네임스페이스 밖 remove가 통과" \
    || ok "네임스페이스 밖 remove 거부"
  [[ -d "$REPO/outside" ]] && ok "거부된 대상이 살아있음" || no "대상이 삭제됨"
  cd / && rm -rf "$REPO"
}

# T18 + AC24/AC25/AC26: 훅 항목 수 · 에이전트 파일 수 불변
#
# 이 락은 몰래 늘거나 주는 쪽 둘 다 잡는 알람이지, "늘기만 막는" 래칫이 아니다 —
# 의도적 변경이면 이 숫자를 같은 커밋에서 의식적으로 고치는 게 정확히 이 락이
# 원하는 동작이다. 현재 값(hooks 0 · agents 5)의 근거는 CHANGELOG 참고.
case_no_new_surfaces() {
  local agents
  agents=$(ls "$PLUGIN_ROOT/agents" | wc -l | tr -d ' ')
  # hooks/ 자체가 없다(훅 0개). 생기면 새 표면이다.
  [[ ! -e "$PLUGIN_ROOT/hooks" ]] && ok "hooks/ 없음 (v10 — 훅 0개)" || no "hooks/ 가 다시 생겼다"
  [[ -d "$PLUGIN_ROOT/agents" ]] && ok "agents/ 는 있다 (위 부재가 경로 오타로 공허하지 않다)" \
    || no "agents/ 도 없다 — PLUGIN_ROOT 가 틀렸다"
  [[ "$agents" == "5" ]] && ok "agents/ 파일 5개 불변"    || no "agents 파일 수 $agents (기대 5)"
}

# T88 + §11 ⑬ / §6.7 S4: HEAD 축 트리는 기준선 트리와 **동시에 공존하는** 별개 트리다.
#
# 이 케이스가 잠그는 세 축과 **각 축을 실제로 잡는 assert** (mutation 으로 실측 —
# 주장이 아니라 측정이다):
#
#  1) 경로 구별 — 두 축이 같은 경로 prefix 를 쓰면 한 실행 안에서 두 축이 하나로
#     붕괴하는데, 각 호출은 **여전히 정상 경로를 emit 하고 rc 0 을 낸다.** detached
#     인가 · 네임스페이스 안인가 같은 호출 단위 검사는 전부 통과한다. 잡는 것은
#     "두 축이 서로 다른 경로" assert.
#  2) 생성이 형제를 파괴하지 않음 — prefix 가 달라도 네임스페이스를 통째로 정리하고
#     시작하면 두 번째 생성이 첫 번째 트리를 지운다. 경로는 여전히 구별되므로 (1) 은
#     통과한다. 잡는 것은 공존 assert.
#  3) 각 트리가 자기 커밋 — 공존하고 경로가 달라도 둘 다 같은 커밋을 가리키면 차등이
#     0 이다. 잡는 것은 두 내용 assert.
case_head_and_baseline_coexist() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo v1 > a.txt; git add a.txt; git commit -qm v1
  local base_sha; base_sha=$(git rev-parse HEAD)
  git checkout -q -b feature
  echo v2 > a.txt; git commit -qam v2
  local head_sha; head_sha=$(git rev-parse HEAD)

  # HEAD 축은 지금 봉인한 커밋에만 붙는다(create-head 가 봉인을 다시 떠 대조한다).
  local b h
  if ! head_sha=$(bash "$PLUGIN_ROOT/scripts/seal-worktree.sh" seal "sess1234"); then
    no "봉인 실패"; cd / && rm -rf "$REPO"; return
  fi
  if ! b=$(bash "$WT" create-baseline "$base_sha" "sess1234"); then
    no "create-baseline 실패"; cd / && rm -rf "$REPO"; return
  fi
  if ! h=$(bash "$WT" create-head "$head_sha" "sess1234"); then
    no "create-head 실패"; cd / && rm -rf "$REPO"; return
  fi

  [[ "$b" != "$h" ]] && ok "두 축이 서로 다른 경로" || no "두 축이 같은 경로: $b"
  case "$h" in
    */.claude/worktrees/qg-*) ok "HEAD 축도 worktrees/ 네임스페이스 안" ;;
    *) no "네임스페이스 밖: $h" ;;
  esac

  local b_here=no h_here=no
  [[ -d "$b" ]] && b_here=yes
  [[ -d "$h" ]] && h_here=yes
  [[ "$b_here" == yes && "$h_here" == yes ]] \
    && ok "기준선·HEAD 두 트리가 동시에 존재 (한쪽이 다른 쪽을 갈아엎지 않음)" \
    || no "공존 실패 (기준선=$b_here HEAD=$h_here) — 두 축이 한 트리로 붕괴"

  # 내용 축 — 공존해도 같은 커밋이면 차등이 0 이다.
  [[ -f "$b/a.txt" && "$(cat "$b/a.txt")" == "v1" ]] \
    && ok "기준선 트리 내용 == merge_base" || no "기준선 내용 오염"
  [[ -f "$h/a.txt" && "$(cat "$h/a.txt")" == "v2" ]] \
    && ok "HEAD 축 트리 내용 == 봉인 커밋 B" || no "HEAD 축 내용 오염"

  ( cd "$h" && ! git symbolic-ref --quiet HEAD >/dev/null 2>&1 ) \
    && ok "HEAD 축 워크트리는 detached" || no "HEAD 축 detached 아님"

  # remove 네임스페이스 가드가 HEAD 축에도 적용된다 (일회용이므로 지워질 수 있어야 함)
  bash "$WT" remove "$h" >/dev/null 2>&1
  [[ ! -d "$h" ]] && ok "HEAD 축 트리 remove 적용됨" || no "HEAD 축 remove 실패"
  bash "$WT" remove "$b" >/dev/null 2>&1
  cd / && rm -rf "$REPO"
}

# create-head 의 sha 는 **선언된 자유 변수가 아니다** — 지금 다시 뜬 봉인의 트리와
# 대조되고 다르면 죽는다(설계 §6.4.1 — 「봉인 커밋의 트리가 기대 OID 와 일치」).
# `$merge_base` 를 넘기는 실수(형제 create-baseline 과 인자 모양이 같다)면 HEAD 축이
# 기준선의 바이트 복사본이 되어 전 unit 이 STILL_GREEN 으로 접힌다. 세 축 + 양의 짝.
case_create_head_asserts_sealed_commit() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main; echo v1 > a.txt; git add a.txt; git commit -qm v1
  local mb; mb=$(git rev-parse HEAD)
  git checkout -q -b feature; echo v2 > a.txt; git commit -qam v2
  echo v3 > a.txt                                   # 미커밋 변경 — 봉인이 담아야 한다
  local SEAL="$PLUGIN_ROOT/scripts/seal-worktree.sh"
  local sealed; sealed=$(bash "$SEAL" seal "sess7777") || { no "봉인 실패"; cd / && rm -rf "$REPO"; return; }

  # 양의 짝: 방금 뜬 봉인은 받아들인다
  local h
  if h=$(bash "$WT" create-head "$sealed" "sess7777" 2>/dev/null) && [[ "$(cat "$h/a.txt")" == "v3" ]]; then
    ok "봉인 커밋 → create-head 수락 · 트리에 미커밋 변경이 있다 (양의 짝)"
    bash "$WT" remove "$h" >/dev/null 2>&1
  else
    no "봉인 커밋인데 create-head 가 거부했거나 트리가 봉인과 다르다"
  fi

  # 음 ①: merge_base — 형제 호출과 인자 모양이 같아 가장 현실적인 오값
  if bash "$WT" create-head "$mb" "sess7777" >/dev/null 2>&1; then
    no "merge_base 가 통과함 — HEAD 축이 기준선 복사본이 된다"
  else
    ok "merge_base → create-head 거부"
  fi

  # 음 ②: 봉인 뒤 워킹트리가 바뀐 stale 봉인
  echo v4 > a.txt
  if bash "$WT" create-head "$sealed" "sess7777" >/dev/null 2>&1; then
    no "봉인 뒤 워킹트리가 바뀌었는데 옛 봉인이 통과함"
  else
    ok "stale 봉인 → create-head 거부"
  fi

  # 음 ③: 커밋이 아닌 값
  if bash "$WT" create-head "not-a-commit" "sess7777" >/dev/null 2>&1; then
    no "커밋이 아닌 값이 통과함"
  else
    ok "커밋 아닌 값 → create-head 거부"
  fi
  cd / && rm -rf "$REPO"
}

for c in case_create_baseline \
         case_create_baseline_is_still_idempotent \
         case_head_and_baseline_coexist case_create_head_asserts_sealed_commit \
         case_remove_namespace_guard \
         case_no_new_surfaces; do
  echo "== $c"; $c
done
finish
