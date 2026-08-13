#!/usr/bin/env bash
# run_spec_codex_reviewer.sh — independent codex review of a DESIGN DOC.
# spec-distill design §6 #3. Unlike qg's run_codex_reviewer.sh, this NEVER
# performs script-internal spec/AC auto-discovery (C3: the reviewed doc lives
# under docs/superpowers/specs/, so AC auto-injection would feed the doc its
# own content — a circular footgun). Grep-checked absence: this file must never
# reference the qg spec-lookup helper by name.
#
# Usage:  run_spec_codex_reviewer.sh <doc_path> <project_dir> <output_yaml_path>
#
# Emits YAML (codex_findings_to_yaml.py schema) to <output_yaml_path> on
# success and on every failure above — with ONE exception (리뷰 라운드 2, A3):
# if <output_yaml_path> itself cannot be written (missing directory,
# permissions, RO mount), no YAML is possible; the script prints a loud
# stderr diagnostic and exits **3** instead. On rc == 3 the CALLER MUST
# delete <output_yaml_path> before reading it — a prior round's stale YAML
# would otherwise sit untouched and be read as this round's codex verdict.
# Same contract as `run_brief_codex_reviewer.sh`; reviewing-spec/SKILL.md now
# documents the caller-side rc==3 → rm -f obligation for this runner.
# Sandbox: codex exec -s read-only (Layer 3) — codex cannot write the tree.

set -euo pipefail

DOC_PATH="${1:-}"
PROJECT_DIR="${2:-}"
OUTPUT_PATH="${3:-}"

if [[ -z "$OUTPUT_PATH" ]]; then
  echo "usage: run_spec_codex_reviewer.sh <doc_path> <project_dir> <output_yaml_path>" >&2
  exit 2
fi

# Absolutize relative DOC_PATH/OUTPUT_PATH against the invocation cwd BEFORE
# any `cd "$PROJECT_DIR"` below — otherwise a relative path silently resolves
# against project_dir instead (wrong-location write / spurious prompt_build_failed).
[[ "$OUTPUT_PATH" = /* ]] || OUTPUT_PATH="$PWD/$OUTPUT_PATH"
[[ "$DOC_PATH" = /* ]] || DOC_PATH="$PWD/$DOC_PATH"

# ── B3 (/qg 2026-08-13 whole-branch 리뷰): seed 를 절대화 **직후**로 끌어올린다 ──
# 아래 세 분기(missing_project_dir · project_dir_unreachable · scratch_dir_uncreatable)
# 는 예전에 guarded truncate 보다 **앞**에서 `>` 로 직접 썼다. `set -euo pipefail`
# 아래에서 OUTPUT_PATH 가 쓰기 불가면 그 리다이렉트가 실패하며 스크립트는 **exit 1**
# 로 죽고(EXIT 트랩도 아직 미무장), 계약과 호출자는 rc==3 에서만 stale 을 지운다.
# 결과: 이전 라운드의 YAML 이 양성 `codex_failed: false` 를 단 채 이번 라운드의
# 판정으로 읽힌다 — indeterminate ≠ clean 위반.
#
# 교훈은 위치다. 가드는 "내가 문제를 떠올린 지점"이 아니라 **자원을 처음 만지는
# 지점**에 있어야 한다. 형제 `run_brief_codex_reviewer.sh:39-63` 의 seed 형태를
# 그대로 쓴다(세 번째 철자를 발명하지 않는다).
: > "$OUTPUT_PATH" 2>/dev/null || {
  echo "[spec-distill] 산출물 경로에 쓸 수 없다: $OUTPUT_PATH" >&2
  exit 3
}

write_failclosed() {                   # $1 = reason — 리다이렉트 실패를 삼키지 않는다
  { echo 'findings: []'
    echo 'meta:'
    echo '  codex_failed: true'
    echo "  reason: $1"; } > "$OUTPUT_PATH" || {
    echo "[spec-distill] fail-closed YAML 기록 실패: $OUTPUT_PATH ($1)" >&2
    return 1
  }
}
emit_fallback() { write_failclosed "$1" || exit 3; exit 0; }

if [[ -z "$PROJECT_DIR" ]]; then
  emit_fallback missing_project_dir
fi
cd "$PROJECT_DIR" || emit_fallback project_dir_unreachable

# C7: guard scratch-dir assignment BEFORE any trap arms (cd "" repo-delete footgun).
SCRATCH="$(mktemp -d -t sd-codex-rev-XXXXXX)" || emit_fallback scratch_dir_uncreatable
# 치명적 abort(예: `set -u` 위반)가 EXIT trap을 지나면서 조용해지는 문제.
#
# 이 스크립트의 계약은 (헤더의 exit 3 예외를 뺀 나머지 모든 경로에서) **항상
# exit 0 + 항상 YAML 기록**이므로, 강제로 비-0을 내보내는 것은 고치는 게 아니라
# 계약을 깨는 것이다. 그리고 종료 코드로 판정할
# 수도 없다: bash 3.2.57은 `set -u` abort 시 트랩 핸들러에 **`$?`를 0으로** 넘긴다
# (2026-08-04 최소 재현 확인) — `rc=$?`를 보존해도 abort와 정상 종료가 구별되지
# 않는다. 종료 코드가 아니라 **산출물**로 판정한다.
#
# 실제 피해는 두 가지이고 둘 다 여기서 막는다:
#   (1) YAML 부재 — 호출자가 읽을 것이 없다.
#   (2) 이전 run이 남긴 stale 파일을 이번 결과로 재사용 — 더 나쁘다. 조용히
#       틀린 리뷰 결과를 이번 라운드의 판정으로 쓰게 된다.
# 그래서 시작 시 truncate하고(=stale 제거), 트랩에서 비어 있으면 degrade를 채운다.
# 비어 있지 않으면 손대지 않는다 — 위쪽 정상 degrade 경로들의 YAML을 덮지 않기 위함.
#
# **A3 (리뷰 라운드 2)**: truncate 자체가 실패할 수 있다(산출물 경로가 읽기전용
# 등) — 이전 코드(`[[ -n "$OUTPUT_PATH" ]] && : > "$OUTPUT_PATH"`)는 이 실패를
# 확인하지 않았다. 이 스크립트는 `set -euo pipefail`이라 truncate 실패가 (아래
# `trap ... EXIT` 무장) *전에* 스크립트를 즉사시켰다(컨트롤러 재현: 읽기전용 기존
# 산출물 → rc=1, tagged stderr 없이 bash의 raw "Permission denied"만, stale
# 불변 — 형제 두 곳(run_codex_reviewer.sh·run_artifact_codex_reviewer.sh)에서
# 리뷰 라운드 1로 적발된 것과 동일한 결함이 여기도 있었고, tagged stderr조차
# 없었던 만큼 형태는 더 나빴다). 형제 `run_audit_codex_reviewer.sh`의 형태를
# 그대로 쓴다: truncate조차 못 하면 degrade도 쓸 수 없다는 뜻이므로 loud
# stderr + exit 3으로 죽는다. 호출자는 rc==3을 보면 OUTPUT_PATH를 지워야
# 한다(위 계약 문단과 동형; reviewing-spec SKILL이 이 의무를 구현한다).
# (seed 는 위 B3 블록으로 올라갔다 — 여기서 다시 truncate 하지 않는다. 이 지점에
# 도달했다는 것은 seed 가 이미 성공했다는 뜻이고, 재truncate 는 그 사이 분기가 쓴
# 진짜 reason 을 지울 위험만 만든다.)
_degrade_if_empty() {
  [[ -n "$OUTPUT_PATH" && ! -s "$OUTPUT_PATH" ]] || return 0
  { echo 'findings: []'
    echo 'meta:'
    echo '  codex_failed: true'
    echo '  reason: aborted_before_completion'; } > "$OUTPUT_PATH" 2>/dev/null || true
  echo "[spec-distill] codex 리뷰가 완료 전에 중단됨 — degrade YAML 기록(stale 재사용 방지)" >&2
}
# trap은 한 줄로 유지한다: C7 순서 락(test_run_spec_codex_reviewer.sh AC6)이
# `trap.*rm -rf.*SCRATCH.*EXIT`를 한 줄 정규식으로 앵커한다. 여러 줄로 펼치면
# 그 락이 trap을 **못 보고** guard 순서 검사가 통째로 무력화된다 — 락을 약화시키지
# 않으려면 로직을 함수로 빼고 arm 줄은 그대로 둔다.
trap 'rm -rf "$SCRATCH"; _degrade_if_empty' EXIT
PROMPT_FILE="$SCRATCH/prompt.md"
STDOUT_FILE="$SCRATCH/codex.jsonl"
STDERR_FILE="$SCRATCH/codex.stderr"

# Build the design-doc prompt (path-only input — no spec/AC auto-discovery, C3).
if ! python3 "${CLAUDE_PLUGIN_ROOT}/scripts/build_spec_codex_prompt.py" \
       "$DOC_PATH" > "$PROMPT_FILE"; then
  echo 'findings: []' > "$OUTPUT_PATH"
  echo 'meta:' >> "$OUTPUT_PATH"; echo '  codex_failed: true' >> "$OUTPUT_PATH"
  echo '  reason: prompt_build_failed' >> "$OUTPUT_PATH"
  exit 0
fi

# Canonical codex invocation (load-bearing flags preserved):
#   -s read-only  : Layer 3 sandbox (writes blocked)   | --json : JSONL stream
#   -C            : working-dir pin | - + < "$PROMPT_FILE" : 프롬프트를 stdin으로
# 추론 강도는 핀하지 않는다 — 사용자 codex 설정이 지배한다. 하니스가 medium을 박으면
# high/xhigh 사용자가 조용히 하향되고, 그 하향이 이 co-reviewer의 존재 이유(별-모델
# 적발력)를 정확히 깎는다.
#
# 웹 검색: 사용자 kill switch(DEVBREW_SPEC_DISTILL_DISABLE_WEB=1)만 끈다. 그 밖에는
# 명시적으로 켠다 — design doc 리뷰는 외부 prior-art 대조가 판정의 일부다.
# `web_search="live"`: `tools.web_search=true` 단독은 codex 기본 모드(`cached`) —
# 최대 12일 지연된 인덱스를 되돌려주면서도 검색에 성공한 것처럼 보인다(V1 probe
# 실측, 2026-08-09). `live`로 승격해야 실제 현재 웹에 닿는다.
# `allowed_domains`로 좁히지 않는다: 어느 도메인이 중요할지 미리 알 수 없고, 좁히면
# 조사 능력을 깎는다(하니스는 능력을 억제하지 않는다).
# 검색 *횟수* 상한은 두지 않는다 — 단일 exec은 이미 턴으로 경계가 있다.
WEB_ARGS=(-c 'tools.web_search=true' -c 'web_search="live"')
if [[ "${DEVBREW_SPEC_DISTILL_DISABLE_WEB:-0}" == "1" ]]; then
  WEB_ARGS=(-c 'tools.web_search=false' -c 'web_search="disabled"')
  echo "[spec-distill] web 비활성 — codex co-reviewer가 리포 근거만 사용 (외부 사실 확인 없음)" >&2
fi

EXIT_CODE=0
codex exec - \
    -C "$PROJECT_DIR" \
    -s read-only \
    "${WEB_ARGS[@]}" \
    --json \
    < "$PROMPT_FILE" \
    > "$STDOUT_FILE" \
    2>"$STDERR_FILE" || EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
  OVERRIDE_REASON=exit_nonzero
else
  OVERRIDE_REASON=""
fi

# Guarded like the build_spec_codex_prompt.py call above: under `set -e` this
# final pipeline is otherwise unguarded — a python3/write failure here would
# abort the script non-zero with NO fallback YAML, breaking the
# always-exit-0/always-writes-YAML contract.
if ! python3 "${CLAUDE_PLUGIN_ROOT}/scripts/codex_findings_to_yaml.py" \
       --stderr-file "$STDERR_FILE" \
       --meta-override-exit-code "$EXIT_CODE" \
       --meta-override-reason "$OVERRIDE_REASON" \
       < "$STDOUT_FILE" > "$OUTPUT_PATH"; then
  echo 'findings: []' > "$OUTPUT_PATH"
  echo 'meta:' >> "$OUTPUT_PATH"; echo '  codex_failed: true' >> "$OUTPUT_PATH"
  echo '  reason: yaml_conversion_failed' >> "$OUTPUT_PATH"
  exit 0
fi
