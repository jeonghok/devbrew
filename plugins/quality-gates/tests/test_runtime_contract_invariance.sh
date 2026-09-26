#!/usr/bin/env bash
# test_runtime_contract_invariance.sh — create-baseline + 기존 계약 바이트 무변경.
# AC7 AC21 AC22 AC24 AC25 AC26 · T5 T16 T17 T18
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
WT="$PLUGIN_ROOT/scripts/qg-worktree.sh"
SKILL_REAL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# Task 31 fix round 1 (F1); Task 7 이 기대값을 뒤집었다: case_no_new_surfaces() 의
# verdict 토큰 7종 부재(PASS/FAIL/SKIP_WITH_EVIDENCE/NEEDS_RESOLUTION/PARTIAL/
# INCONCLUSIVE/DEGRADED_VERDICT — 전부 SKILL.md 밖) 는 판정이 실제로 만들어지는
# 차등 테스트 절차를 잰다 — 그 절차가 references/differential-test.md 로 옮겨진
# 뒤에도 동일 계약이므로, 분할 전과 동일한 논리적 문서로 재구성해 그 위에서 돈다.
# 재구성 실패는 조용히 원본으로 폴백하지 않고 FAIL 한다.
. "$SCRIPT_DIR/lib/reconstruct-skill.sh"
if ! SKILL="$(reconstruct_skill_md "$SKILL_REAL")"; then
  echo "FAIL: SKILL.md ↔ references/differential-test.md 재구성 실패 ($SKILL_REAL)"
  exit 1
fi
trap 'rm -f "$SKILL"' EXIT

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
    */.claude/quality-gates/worktrees/*) ok "worktrees/ 네임스페이스 안" ;;
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

# 최종 whole-branch 리뷰 (Task 9 이월분 승격) — create-baseline 의 idempotent 정리가
# **사용자 워크트리를 파괴**할 수 있다. `create` 는 `${sanitized}-${sid_short}`,
# create-baseline 은 `base-${sid_short}` 를 쓰므로 같은 세션의 `/qg branch base` 가
# **정확히 같은 경로**를 만들고, 무조건 `--force` 면 미커밋 작업이 되돌릴 수 없이 사라진다.
#
# 판별자로 "HEAD 가 심볼릭 ref 인가"는 쓸 수 없다 — `create` 도 `--detach` 라 둘 다
# detached 다 (위 case_create_baseline 이 기준선 트리의 detached 를 확인하는 것과 같은
# 성질이며, 실측으로 확인했다). 그래서 이 케이스는 **미커밋 파일이 살아남는가**를 직접
# 잰다. 파일 존재는 어떤 판별자 구현에도 의존하지 않는 관측이다.
case_create_baseline_refuses_colliding_user_worktree() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo v1 > a.txt; git add a.txt; git commit -qm v1
  local base_sha; base_sha=$(git rev-parse HEAD)
  git branch base
  git checkout -q -b feature; echo v2 > a.txt; git commit -qam v2

  # 사용자가 같은 세션에서 `/qg branch base` 를 돌린 상태를 만든다
  local user_wt; user_wt=$(bash "$WT" create base "sess1234" 2>/dev/null)
  if [[ -z "$user_wt" || ! -d "$user_wt" ]]; then
    no "픽스처 무효: /qg branch base 워크트리 생성 실패"; cd / && rm -rf "$REPO"; return
  fi
  # 픽스처가 실제로 충돌하는지 먼저 증명한다 (경로가 안 겹치면 이 락은 무의미하다)
  [[ "$(basename "$user_wt")" == "base-sess1234" ]] \
    && ok "픽스처: /qg branch base 와 create-baseline 이 같은 경로를 노린다" \
    || no "픽스처 무효: 경로 불일치 ($user_wt)"
  echo "uncommitted work" > "$user_wt/WIP.txt"

  local out rc; out=$(bash "$WT" create-baseline "$base_sha" "sess1234" 2>/dev/null); rc=$?
  [[ -f "$user_wt/WIP.txt" ]] \
    && ok "충돌 경로의 미커밋 작업이 살아남음" \
    || no "create-baseline 이 사용자 워크트리의 미커밋 작업을 파괴함"
  [[ $rc -ne 0 ]] \
    && ok "충돌 시 조용히 진행하지 않고 non-zero 로 죽는다" \
    || no "충돌인데 exit 0 (rc=$rc out='$out')"
  cd / && rm -rf "$REPO"
}

# 위 가드가 정상 경로(우리가 만든 clean 한 기준선 트리 재사용)를 막지 않는가.
# 가드만 넣고 이것을 안 재면 게이트가 두 번째 실행부터 영구히 죽는 회귀를 못 잡는다.
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
  # 앞선 실행이 남긴 **git-ignored 빌드 산출물**이 있는 상태가 정상 경로다 (C1 수정 이후
  # cargo/venv 산출물은 전부 ignored 로 떨어진다). 여기서 막히면 게이트가 두 번째
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

# T16 + AC21′ (대상 소멸 — Task 7): detect-runtime.sh 가 삭제됐다. 이 스텝이 잠그던
# "무단 변경 없음" 은 대상이 사라지며 함께 소멸한다 — case_detect_runtime_frozen 은
# 지운다(케이스 목록에서도 제거).

# T17 + AC22: create-sandbox / mutation-guard case 본문 바이트 무변경
# case 절 본문만 잘라 해시한다 — 파일 전체를 핀하면 create-baseline 추가로 깨진다.
extract_case() {   # extract_case <case-label> → 그 case 절 본문
  awk -v label="  $1)" '
    $0 == label { inblock = 1; next }
    inblock && /^  [a-z][a-z-]*\)$/ { exit }
    inblock { print }
  ' "$WT"
}
CREATE_SANDBOX_SHA256="7585a46b39036685d47fbd08c3f748c915c30b326a65471fb97d1e422406e49e"
MUTATION_GUARD_SHA256="000c3a26953269b237c4e272bbddfad8ea4a33b2d3f6f5787e80fecbdd1ed830"
case_sandbox_guard_frozen() {
  local a b
  a=$(extract_case create-sandbox | shasum -a 256 | awk '{print $1}')
  b=$(extract_case mutation-guard | shasum -a 256 | awk '{print $1}')
  [[ "$a" == "$CREATE_SANDBOX_SHA256" ]] && ok "create-sandbox 본문 무변경" \
    || no "create-sandbox 변경 (got $a)"
  [[ "$b" == "$MUTATION_GUARD_SHA256" ]] && ok "mutation-guard 본문 무변경" \
    || no "mutation-guard 변경 (got $b)"
}

# T18 + AC24/AC25/AC26: 훅 항목 수 · 에이전트 파일 수 · verdict 토큰 집합 불변
#
# 이 락은 몰래 늘거나 주는 쪽 둘 다 잡는 알람이지, "늘기만 막는" 래칫이 아니다 —
# 의도적 변경이면 이 숫자를 같은 커밋에서 의식적으로 고치는 게 정확히 이 락이
# 원하는 동작이다(test_codex_backward_compat.sh 헤더의 "의식적 갱신 강제"와
# 같은 패턴). 현재 값(hooks 2 · agents 6)의 근거는 CHANGELOG 참고.
case_no_new_surfaces() {
  local hooks agents
  hooks=$(python3 -c "
import json
with open('$PLUGIN_ROOT/hooks/hooks.json', encoding='utf-8') as f:
    d = json.load(f)
print(sum(len(v) for v in d.get('hooks', {}).values()))
")
  agents=$(ls "$PLUGIN_ROOT/agents" | wc -l | tr -d ' ')
  # v7.0.0: PostToolUse(pr-create 자동 트리거) 제거로 3 → 2. 늘어난 방향만이 새 표면이다.
  [[ "$hooks" == "2" ]]  && ok "hooks.json 항목 2개 불변" || no "hooks 항목 수 $hooks (기대 2)"
  [[ "$agents" == "6" ]] && ok "agents/ 파일 6개 불변"    || no "agents 파일 수 $agents (기대 6)"
  # verdict 토큰은 이제 SKILL.md 에 0종이 기대값이다 (Task 7 — invert). 판정 어휘는
  # `scripts/verdict.py` 밖에 두지 않는다(global constraints) — PASS/FAIL/
  # SKIP_WITH_EVIDENCE/NEEDS_RESOLUTION 은 옛 Runtime 게이트가 SKILL.md 에 직접
  # 내던 판정값이었고, 그 게이트 자체가 대상 소멸했다. 레거시 3종
  # (PARTIAL/INCONCLUSIVE/DEGRADED_VERDICT) 은 애초에 실재한 적이 없어 그대로 0종.
  #
  # **부재를 통과로 읽지 않는다 (/qg iter-5 C3 계승).** `$SKILL` 이 없으면 grep 은
  # **exit 2**(파일 오류)를 내고, 그것을 "매치 없음"과 같은 non-zero 로 읽으면
  # 파일을 지워도·이름을 바꿔도·경로를 오타내도 GREEN 이 된다 — 그래서 파일 실재를
  # 먼저 확인한다.
  if [[ ! -f "$SKILL" ]]; then
    no "SKILL.md 부재 ($SKILL) — verdict 토큰 락이 공허하게 통과할 뻔했다"
  else
    local present="" t
    for t in PASS FAIL SKIP_WITH_EVIDENCE NEEDS_RESOLUTION PARTIAL INCONCLUSIVE DEGRADED_VERDICT; do
      grep -qE "\\b${t}\\b" "$SKILL" && present="$present $t"
    done
    [[ -z "$present" ]] && ok "verdict 토큰 0종 (레거시 7종 전부 부재 — Task 7)" \
      || no "verdict 토큰 잔존:$present"
  fi
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

  # HEAD 축은 create-sandbox 가 봉인한 커밋 B 에만 붙는다 — 샌드박스를 먼저 만들고
  # 그 출력 2행(= B)을 쓴다. 픽스처가 이 순서를 지켜야 하는 것 자체가 계약이다.
  local sb b h
  if ! sb=$(bash "$WT" create-sandbox "sess1234"); then
    no "create-sandbox 실패"; cd / && rm -rf "$REPO"; return
  fi
  head_sha=$(printf '%s\n' "$sb" | sed -n 2p)
  if ! b=$(bash "$WT" create-baseline "$base_sha" "sess1234"); then
    no "create-baseline 실패"; cd / && rm -rf "$REPO"; return
  fi
  if ! h=$(bash "$WT" create-head "$head_sha" "sess1234"); then
    no "create-head 실패"; cd / && rm -rf "$REPO"; return
  fi

  [[ "$b" != "$h" ]] && ok "두 축이 서로 다른 경로" || no "두 축이 같은 경로: $b"
  case "$h" in
    */.claude/quality-gates/worktrees/*) ok "HEAD 축도 worktrees/ 네임스페이스 안" ;;
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

for c in case_create_baseline case_create_baseline_refuses_colliding_user_worktree \
         case_create_baseline_is_still_idempotent \
         case_head_and_baseline_coexist case_create_head_asserts_sealed_commit \
         case_remove_namespace_guard \
         case_sandbox_guard_frozen case_no_new_surfaces; do
  echo "== $c"; $c
done
finish
