#!/usr/bin/env bash
# **참조 구현이다 — 배포되지 않고, 코드 소비자가 없다.** 이것은 잊고 배선하지 않은 파일이
# 아니다: 설계 §12.2 의 요구 4(`.md` 정본을 읽는 쪽이 마커 줄을 제거한 뒤 프롬프트에 넣는다)
# 를 실행 가능한 형태로 **확정하는 것**이 이 파일의 역할이고, plan `:2946` 이 그 역할을
# 그대로 적었다 — *"Task 18의 read_preamble.sh는 §12.2 요구를 확정하지만 배포 스텝을 실제로
# 쓰지 않는다"*. 배포 스텝이 없다는 사실 자체도 plan `:4843-4846` 이 미리 기록해 뒀다.
# 아래 `grep -v` 한 줄은 유일한 셸 소비 지점인
# `plugins/plugin-audit/scripts/run_audit_codex_reviewer.sh` 의 호출 자리에 인라인돼 있다.
#
# P21 프리앰블을 읽어 **HTML 주석 줄을 제거한 뒤** stdout 에 낸다.
#
# stripping 이 필요한 이유(설계 §12.2 요구 4): 이 파일은 프롬프트로 읽힌다. 마커·메타
# 주석이 본문으로 새면 모델이 그것을 지시로 읽는다 — P21 이 막으려는 바로 그 혼동이다.
# 현재 러너가 파일을 통째로 읽으므로(`run_audit_codex_reviewer.sh:62`) 이 stripping 을
# 추가해야 한다.
set -u
src="${1:?usage: read_preamble.sh <preamble.md>}"
[ -r "$src" ] || { echo "read_preamble: '$src' 를 읽을 수 없다" >&2; exit 3; }
grep -v '^[[:space:]]*<!--.*-->[[:space:]]*$' -- "$src"
