#!/usr/bin/env bash
# run_artifact_codex_reviewer.sh — independent codex artifact-review subprocess.
# Mirrors run_codex_reviewer.sh: build prompt (file-path only) -> codex exec -
# -s read-only --json < "$PROMPT" (stdin) -> extract fenced findings YAML. Any failure
# writes a `codex_failed: true` degrade meta to OUT (graceful, C7). No writes to
# the working tree (Layer-3 read-only sandbox).
#
# Contract (리뷰 라운드 2, A1): exit 0 on success and on every failure above —
# with ONE exception. If OUT itself cannot be written (missing directory,
# permissions, RO mount), no degrade meta is possible either; the script prints
# a loud stderr diagnostic and exits **3** instead. On rc == 3 the CALLER MUST
# delete OUT before reading it — a prior round's stale YAML (possibly carrying
# a false-positive `codex_failed: false`) would otherwise sit untouched and be
# read as this round's codex verdict. Same contract as
# `run_brief_codex_reviewer.sh`; critiquing-artifacts/SKILL.md now documents
# the caller-side rc==3 → rm -f obligation for this runner.
#
# Usage: run_artifact_codex_reviewer.sh <artifact_path> <project_dir> <output_yaml_path>
set -u

ARTIFACT="${1:-}"
PROJECT_DIR="${2:-}"
OUT="${3:-}"

emit_fail() { # <reason>
  { printf 'codex_failed: true\n'; printf 'reason: %s\n' "$1"; } > "${OUT:-/dev/stdout}"
}

if [ -z "$PROJECT_DIR" ] || [ -z "$OUT" ]; then
  emit_fail "missing_args"
  exit 0
fi

# ── R1 (Task 20b 리뷰 라운드 1): 절대화는 cd 전에 ────────────────────────────
# 상대 경로를 호출 cwd 기준으로 절대화한다 — 아래 `cd "$PROJECT_DIR"` 이후에는
# project_dir 기준으로 조용히 재해석된다. 이전 순서는 truncate가 cd *이전* cwd로
# OUT을 열고, EXIT 트랩의 `-s` 검사는 (트랩이 cd 이후에 발동하면) 같은 상대경로를
# cd *이후* cwd로 다시 해석해 **서로 다른 파일**을 본다 — 가드가 호출자가 보는
# 파일이 아닌 엉뚱한 곳을 지키는 셈이라 사실상 아무것도 지키지 못했다(리뷰 R1).
# 형제 러너 3곳(run_brief_/run_spec_/run_audit_codex_reviewer.sh) 전부 cd 전에
# 이 절대화를 한다 — 이 러너에만 없었다.
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac
case "$ARTIFACT" in /*) ;; *) ARTIFACT="$PWD/$ARTIFACT" ;; esac

# ── stale 재사용 봉쇄 (Task 20b, 리뷰 R2로 강화) ─────────────────────────────
# 형제 러너(run_codex_reviewer.sh)가 가진 계약이 이 러너에는 백포트되지 않았다.
# 아래의 명시적 emit_fail 분기들은 각자 자기 실패를 정확히 기록하지만, 그 분기
# *자체*에 도달하지 못하고 죽는 경로(예: `CLAUDE_PLUGIN_ROOT` 미설정으로 인한
# `set -u` abort)는 아무것도 잡지 못했다. 그 경로에서는 이전 라운드의 YAML이
# **양성 `codex_failed: false` 표식과 함께 그대로** 남아 이번 라운드의 clean
# 판정으로 읽혔다(indeterminate ≠ clean 위반. 부재가 아니라 stale이 이번 결과로
# 제시되는 형태). 종료 코드로 판정하지 않는다: 이 스크립트의 계약은 (헤더의
# exit 3 예외를 뺀 나머지 모든 경로에서) "항상 exit 0 + 항상 YAML"이고, bash
# 3.2.57은 `set -u` abort 시 EXIT 트랩에 `$?`를 0으로 넘긴다. 신호는 산출물뿐이다.
# 그래서 시작 시 truncate하고, 비어 있으면 degrade로 채운다.
#
# **R2 (리뷰 라운드 1)**: truncate 자체가 실패할 수 있다(산출물 경로가 읽기전용
# 등) — 이전 코드(`[ -n "$OUT" ] && : > "$OUT"`)는 그 실패를 확인하지 않았다.
# truncate가 조용히 실패하면 이후 모든 쓰기 시도(emit_fail·추출기 리다이렉트)도
# 같은 이유로 실패해, 결국 이전 라운드의 stale YAML — 양성 `codex_failed: false`
# 포함 — 이 그대로 남는다(컨트롤러 재현: 읽기전용 기존 산출물 → stderr에 Permission
# denied, 파일 불변). 형제 `run_audit_codex_reviewer.sh`의 형태를 그대로 쓴다:
# truncate조차 못 하면 degrade도 쓸 수 없다는 뜻이므로, loud stderr + exit 3으로
# 죽는다(exit 0으로 조용히 "성공"한 척하지 않는다).
: > "$OUT" 2>/dev/null || {
  echo "[quality-gates] 산출물 경로에 쓸 수 없다: $OUT" >&2
  exit 3
}
_degrade_if_empty() {
  [ -n "$OUT" ] && [ ! -s "$OUT" ] || return 0
  emit_fail "aborted_before_completion"
  echo "[quality-gates] codex 아티팩트 리뷰가 완료 전에 중단됨 — degrade 기록(stale 재사용 방지)" >&2
}
trap '_degrade_if_empty' EXIT

cd "$PROJECT_DIR" 2>/dev/null || { emit_fail "project_dir_unreachable"; exit 0; }

SCRATCH="$(mktemp -d -t qg-art-codex-XXXXXX)" || { emit_fail "scratch_uncreatable"; exit 0; }
PROMPT="$SCRATCH/prompt.md"
JSONL="$SCRATCH/codex.jsonl"
ERR="$SCRATCH/codex.stderr"

if ! python3 "${CLAUDE_PLUGIN_ROOT}/scripts/build_artifact_codex_prompt.py" "$ARTIFACT" > "$PROMPT" 2>"$ERR"; then
  emit_fail "prompt_build_failed"
  exit 0
fi

# 추론 강도는 핀하지 않는다 — 사용자 codex 설정이 지배한다. 하니스가 medium을 박으면
# high/xhigh 사용자가 조용히 하향되고, 그 하향이 별-모델 적발력을 정확히 깎는다.
# 샌드박스(-s read-only)·작업디렉토리 핀(-C)·파싱 계약(--json)은 load-bearing이라 유지.
#
# 웹 posture를 **명시한다.** 미지정은 codex 기본값(`web_search = "cached"`)에 맡기는
# 것이라 "이 호출부는 웹을 쓰지 않는다"가 어디에도 적혀 있지 않게 된다. 산출물 비평은
# 외부 근거가 필요 없고, 외부 조회가 결과를 비결정적으로 만든다. kill switch가 없는
# 이유: 이미 OFF라 끌 것이 없다(죽은 스위치를 만들지 않는다, AC21).
EXIT_CODE=0
codex exec - \
    -C "$PROJECT_DIR" \
    -s read-only \
    -c 'tools.web_search=false' \
    -c 'web_search="disabled"' \
    --json \
    < "$PROMPT" \
    > "$JSONL" \
    2>"$ERR" || EXIT_CODE=$?

REASON=""
[ "$EXIT_CODE" -ne 0 ] && REASON=exit_nonzero

if ! python3 "${CLAUDE_PLUGIN_ROOT}/scripts/extract_codex_artifact_yaml.py" \
    --meta-override-exit-code "$EXIT_CODE" \
    --meta-override-reason "$REASON" \
    < "$JSONL" > "$OUT" || [ ! -s "$OUT" ]; then
  # F-D: the terminal extract was the one step not guarded like the prompt build
  # (line 30). extract_codex_artifact_yaml.py normally exits 0 with either findings
  # or `codex_failed: true`, but an UNHANDLED crash (python3 unavailable, plugin-root
  # issue) truncates OUT to empty via `> "$OUT"`, which the SKILL would read as
  # codex-succeeded-with-no-findings -> a silently dropped reviewer (no C7 degrade,
  # no sources_failed++). Force codex_failed so the loss is loud + counted.
  emit_fail "extract_failed"
fi
exit 0
