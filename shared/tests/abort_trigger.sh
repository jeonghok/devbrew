#!/usr/bin/env bash
# abort_trigger.sh — codex 러너를 **완료 전에 실제로 중단**시키는 트리거.
#
# 러너들의 계약 하나는 "어느 경로로 죽어도 산출물을 남긴다"이고, 그 집행 지점은
# `trap '_degrade_if_empty ... aborted_before_completion' EXIT` 이다. 그 트랩을
# 재려면 **진짜 중단**이 필요하다.
#
# 예전 트리거는 플러그인 루트 환경변수를 지워 `set -u` 를 위반시키는 것이었다.
# 러너들이 fallback 을 갖게 되면서 그 트리거는 더 이상 중단을 일으키지 않는다 —
# 그대로 두면 assertion 이 통과는 하되(다른 degrade 경로로) abort 를 한 번도 밟지
# 않는다. 그래서 신호로 바꾼다.
#
# SIGTERM 을 쓰는 근거: bash 3.2.57 에서 SIGTERM 은 EXIT 트랩을 실행한다(실측).
# codex 스텁이 잠든 사이에 신호가 도착하므로 러너는 산출물 truncate **이후**,
# 완료 **이전**에 죽는다 — SIGTERM · OOM · Bash 도구 timeout 과 같은 계열이다.
#
# 소비자는 `reason: aborted_before_completion` 을 단언해야 한다. `codex_failed:
# true` 만 보면 다른 실패 경로(missing_result · no_agent_message)로도 통과해
# abort 를 안 재고도 GREEN 이 된다 — 이 모듈이 존재하는 이유가 그 구별이다.

# abort_trigger_bin — timeout 바이너리 경로를 stdout 에. 없으면 비-zero.
abort_trigger_bin() {
  command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null
}

# abort_trigger_sleeping_codex <bindir> — <bindir>/codex 에 잠자는 스텁을 만든다.
# 러너가 codex 안에서 대기하는 동안 SIGTERM 이 도착하도록 만드는 장치다.
abort_trigger_sleeping_codex() {
  mkdir -p "$1" || return 1
  printf '#!/bin/sh\nsleep 30\n' > "$1/codex" || return 1
  chmod +x "$1/codex"
}

# run_until_aborted <bindir> <runner.sh> <args...>
#   <bindir> 을 PATH 앞에 두고 러너를 돌리다 SIGTERM 으로 중단시킨다.
#   timeout 바이너리가 없으면 비-zero 를 돌려준다 — 호출자는 그때 **loud skip**
#   해야 한다. 조용히 통과시키면 없는 검증이 있는 것으로 읽힌다.
run_until_aborted() {
  local bindir="$1"; shift
  local to
  to="$(abort_trigger_bin)" || return 127
  PATH="$bindir:$PATH" "$to" -s TERM 2 bash "$@" >/dev/null 2>&1
  return 0
}
