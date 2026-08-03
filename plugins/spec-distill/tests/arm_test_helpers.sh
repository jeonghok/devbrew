#!/usr/bin/env bash
# arm-once 테스트 공유 하니스 (v0.25.0).
# test_arm_once.sh(T1–T3·T13–T19)와 test_arm_ledger_timing.sh(T6–T12)가 source한다.
# **source 전용** — 이 파일 자체는 테스트가 아니다(이름에 test_ 접두어가 없는 이유).
#
# 계약: source하는 쪽이 `set -u -o pipefail`을 먼저 켜고, arm_work_init로 작업 리포를
# 만들고, 마지막에 arm_summary로 집계·종료 코드를 받는다.
#
# 모든 다중-dispatch 헬퍼는 DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=0을 건다(lock —
# 계획 재량 아님). review-dispatch.py의 30초 redispatch TTL 가드가 원장 게이트 없이도
# 두 번째 emit을 막아버리면 "원장 게이트 제거 → RED"라는 mutation 주장이 성립하지 않고
# 락이 이빨을 잃는다.
#
# 위치가 tests/lib/이 아닌 이유: 리포 루트 .gitignore의 `lib/` 규칙이 tests/lib/ 하위를
# 조용히 untracked로 만든다(quality-gates만 negation으로 구제됨).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
VALIDATOR="$SD/hooks/spec-write-validator.py"
DISPATCH="$SD/hooks/review-dispatch.py"
REMINDER="$SD/hooks/pending-review-reminder.py"
LEDGER="$SD/scripts/arm_ledger.py"
MERGE="$SD/scripts/merge_review.py"
SKILL="$SD/skills/reviewing-spec/SKILL.md"
FIX="$SD/tests/fixtures"

pass=0; fail=0
note() {
  if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"
  else fail=$((fail+1)); echo "  ✗ $2"; fi
}

arm_work_init() {  # $1 = mktemp prefix
  # 두 대입 모두 || exit 1 — 빈 WORK가 trap rm -rf로 흘러들어가는 laundering을 막는다.
  # (macOS bash의 `cd ""`는 exit 0 + cwd 불변이라 빈 값이 조용히 통과한다.)
  WORK=$(mktemp -d -t "$1-XXXXXX") || exit 1
  WORK=$(cd "$WORK" && pwd -P) || exit 1   # /var → /private/var symlink 해소
  trap 'rm -rf "$WORK"' EXIT
  ( cd "$WORK" && git init -q && git config user.email t@t.t && git config user.name t \
    && git commit -q --allow-empty -m seed ) || exit 1
}

new_doc() {  # $1 = WORK 기준 상대 경로
  mkdir -p "$WORK/$(dirname "$1")"
  cp "$FIX/2026-05-17-test-design.md" "$WORK/$1"
}
edit_doc() { printf '\n<!-- edit %s -->\n' "$2" >> "$WORK/$1"; }

# stdout만 (advisory JSON 검사용)
run_validator() {  # $1=rel $2=sid [$3=extra env — 단일 KEY=VALUE 토큰]
  local payload; payload=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$WORK/$1")
  # $3 를 배열로 감싼다 — unquoted ${3:-} 는 값 안에 공백이 있으면(예: PATH 항목에
  # 공백 섞인 시스템 경로) word-split 되어 env 가 KEY=VALUE 하나가 아니라 여러
  # 인자로 오인한다. 빈 배열은 "${extra[@]}" 확장 시 자취 없이 사라져 인자 없이
  # 호출한 것과 동일하다(set -u 안전 — ${3:-} 기본값이 항상 정의됨).
  local extra=(); [[ -n "${3:-}" ]] && extra=("$3")
  # bash 3.2(macOS 기본)에서 `set -u` + 빈 배열 `"${extra[@]}"` 는 unbound-variable
  # 로 죽는다 — `${extra[@]+"${extra[@]}"}` 로 우회(배열이 비어 있으면 통째로 사라짐).
  ( cd "$WORK" && env DEVBREW_SPEC_DISTILL_SESSION_ID="$2" ${extra[@]+"${extra[@]}"} \
      bash -c "echo '$payload' | python3 '$VALIDATOR'" 2>/dev/null )
}
# stdout+stderr 합본 (loud degradation 검사용)
run_validator_all() {  # $1=rel $2=sid [$3=extra env — 단일 KEY=VALUE 토큰]
  local payload; payload=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$WORK/$1")
  local extra=(); [[ -n "${3:-}" ]] && extra=("$3")
  ( cd "$WORK" && env DEVBREW_SPEC_DISTILL_SESSION_ID="$2" ${extra[@]+"${extra[@]}"} \
      bash -c "echo '$payload' | python3 '$VALIDATOR'" 2>&1 )
}
run_stop() {  # $1=sid
  ( cd "$WORK" && env DEVBREW_SPEC_DISTILL_SESSION_ID="$1" \
      DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=0 \
      bash -c "echo '{}' | python3 '$DISPATCH'" 2>/dev/null )
}
# stdout+stderr 합본 — "emit 없음" assert 의 **생존 제어**용. stdout 만 재면 훅이
# 크래시해도 빈 문자열이라 통과한다(무이빨 no-emit assert). advisory 를 함께 재면
# 훅이 살아서 그 분기를 탔음이 증명된다.
run_stop_all() {  # $1=sid
  ( cd "$WORK" && env DEVBREW_SPEC_DISTILL_SESSION_ID="$1" \
      DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=0 \
      bash -c "echo '{}' | python3 '$DISPATCH'" 2>&1 )
}
run_reminder() {  # $1=sid — stdout만
  ( cd "$WORK" && env DEVBREW_SPEC_DISTILL_SESSION_ID="$1" \
      DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=0 \
      bash -c "echo '{}' | python3 '$REMINDER'" 2>/dev/null )
}
run_reminder_all() {  # $1=sid — stdout+stderr 합본
  ( cd "$WORK" && env DEVBREW_SPEC_DISTILL_SESSION_ID="$1" \
      DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=0 \
      bash -c "echo '{}' | python3 '$REMINDER'" 2>&1 )
}
run_ledger() {  # arm_ledger CLI — cwd가 WORK여야 state_root·git이 이 리포를 본다
  ( cd "$WORK" && python3 "$LEDGER" "$@" )
}
run_ledger_rc() {  # rc를 살려서 부르는 변형(T11). stdout+stderr 합본.
  ( cd "$WORK" && python3 "$LEDGER" "$@" ) 2>&1
}
state_of() { echo "$WORK/.claude/spec-distill/$1/state.local.md"; }

arm_summary() {
  echo
  echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
  [[ $fail -eq 0 ]]
}
