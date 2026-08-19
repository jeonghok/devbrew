#!/usr/bin/env bash
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
