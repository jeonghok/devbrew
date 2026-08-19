#!/usr/bin/env bash
# run_codex_reviewer.sh — independent codex review subprocess (T3-3 refactor).
# Replaces agent dispatch (agents/codex-reviewer.md) with a script invocation.
# Layer 1 isolation (was: frontmatter disallowedTools) is now provided by
# SKILL.md narrow Bash allowlist (this script path only).
# Layer 2 (narrow Bash allowlist on script-internal commands) and Layer 3
# (codex exec -s read-only OS-level sandbox) are preserved.
#
# Usage:
#   run_codex_reviewer.sh <diff_path> <project_dir> <output_yaml_path>
#
# Optional env:
#   SPEC_AC_FILE — explicit path to a file containing the spec's Acceptance
#                  Criteria section (escape hatch; normally unset). When unset,
#                  the spec is resolved script-internally via discover-spec.sh
#                  and its AC section is extracted. When no spec exists, the
#                  <spec_context> slot is left empty (v2.0.0 behavior).
#   DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1 — force the no-spec path even when a
#                  spec exists (empty <spec_context>; loud log emitted).
#
# Emits: YAML to <output_yaml_path>. Schema (최상위 `agent:` 키는 **없다** — 산출자
# codex_findings_to_yaml.py 의 yaml_emit 은 `agent:` 를 finding 마다 달 뿐 최상위에는
# 내지 않는다. 예전 이 주석과 degrade 경로 둘만 최상위 키를 주장했다, 설계 §6.2):
#   findings: [...]        # 각 항목이 `agent: codex-reviewer` 를 갖는다
#   meta:
#     codex_failed: bool
#     exit_code: int
#     reason: str
#
# Contract (리뷰 라운드 2, A1): exit 0 on both success and failure, always
# writing YAML to <output_yaml_path> — with ONE exception. If that path itself
# cannot be written (missing directory, permissions, RO mount), no YAML is
# possible at all; the script prints a loud stderr diagnostic and exits **3**
# instead. On rc == 3 the CALLER MUST delete <output_yaml_path> before reading
# it — a prior round's stale YAML (which may carry a false-positive
# `codex_failed: false`) would otherwise sit untouched and be read as this
# round's codex verdict. Same contract as `run_brief_codex_reviewer.sh`, whose
# caller (spec-distill's reviewing-brief SKILL) already implements the
# rc==3 → rm -f pattern; quality-pipeline/SKILL.md now documents the same for
# this runner.
#
# Sandbox guarantees: codex exec -s read-only (Layer 3) — codex subprocess
# cannot write to the working tree even though the script invokes it.

set -euo pipefail

DIFF_PATH="${1:-}"
PROJECT_DIR="${2:-}"
OUTPUT_PATH="${3:-}"

if [[ -z "$OUTPUT_PATH" ]]; then
  echo "[quality-gates] usage: run_codex_reviewer.sh <diff> <project_dir> <output>" >&2
  exit 2
fi

# ── R1 (Task 20b 리뷰 라운드 1): 절대화는 cd 전에 ────────────────────────────
# 상대 경로를 호출 cwd 기준으로 절대화한다 — 아래 `cd "$PROJECT_DIR"` 이후에는
# project_dir 기준으로 조용히 재해석된다. 이 줄이 없으면 truncate가 cd *이전*
# cwd로 OUTPUT_PATH를 열고, cd *이후*에 발동하는 EXIT 트랩의 `-s` 검사는 같은
# 상대경로를 cd *이후* cwd로 다시 해석해 **서로 다른 파일**을 본다 — 가드가
# 호출자가 읽는 파일이 아닌 엉뚱한 곳을 지켜 사실상 아무것도 지키지 못한다
# (형제 `run_artifact_codex_reviewer.sh`에서 리뷰 R1으로 적발된 것과 같은 결함이
# 여기도 있었다 — sweep). 형제 러너 3곳(run_brief_/run_spec_/run_audit_codex_reviewer.sh)
# 전부 cd 전에 이 절대화를 한다.
[[ "$OUTPUT_PATH" = /* ]] || OUTPUT_PATH="$PWD/$OUTPUT_PATH"
[[ "$DIFF_PATH" = /* ]] || DIFF_PATH="$PWD/$DIFF_PATH"

# ── stale 재사용 봉쇄 + 완료 전 중단 표시 (리뷰 R2로 강화) ───────────────────
# 쌍둥이 `run_spec_codex_reviewer.sh`(spec-distill 0.24.14)가 받은 봉쇄를 여기에도
# 넣는다. 백포트가 빠져 있던 동안 이 러너는 SIGTERM/`set -u` abort/OOM/Bash-tool
# timeout 어느 경로로 죽어도 **이전 iteration의 YAML을 그대로 남겼고**, 오케스트레이터는
# 그것을 이번 라운드의 codex 판정으로 읽었다 (2026-08-05 재현, exit 143). stale이
# clean이었으면 진짜 결함이 clean 인증을 받고, 발견을 담고 있었으면 사용자가 이미
# 고친 결함을 다시 쫓는다. 둘 다 조용하다.
#
# **종료 코드로 재지 않는다**: 이 스크립트의 계약은 (헤더의 exit 3 예외를 뺀 나머지
# 모든 경로에서) "항상 exit 0 + 항상 YAML"이고, 게다가 bash 3.2.57은 `set -u` abort
# 시 EXIT 트랩에 `$?`를 0으로 넘긴다. 신호는 산출물뿐이다. 그래서 시작 시 truncate하고,
# 비어 있으면 degrade로 채운다.
#
# **R2 (리뷰 라운드 1)**: truncate 자체가 실패할 수 있다(산출물 경로가 읽기전용
# 등). 이전 코드(`: > "$OUTPUT_PATH"`, 가드 없음)는 이 실패를 확인하지 않았다 —
# 이 스크립트는 `set -euo pipefail`이라 truncate 실패가 트랩 무장 *전에* 스크립트를
# 즉사시켰고(컨트롤러 재현: 읽기전용 기존 산출물 → 트랩 설치 전 rc=1로 사망), 트랩이
# 아예 못 뜨니 이전 라운드의 stale YAML이 그대로 남는다 — 형제 `run_artifact_codex_reviewer.sh`
# 에서 리뷰 R2로 적발된 것과 동일한 결함이 여기도 있었다(controller ask: "run_codex_reviewer.sh
# needs the same treatment"). 형제 `run_audit_codex_reviewer.sh`의 형태를 쓴다: truncate조차
# 못 하면 degrade도 쓸 수 없다는 뜻이므로 loud stderr + exit 3으로 죽는다.
: > "$OUTPUT_PATH" 2>/dev/null || {
  echo "[quality-gates] 산출물 경로에 쓸 수 없다: $OUTPUT_PATH" >&2
  exit 3
}
# `_degrade_if_empty` 는 형제 러너와 공유하는 정본이다(설계 §6.2 스키마 통일 + `-n` 가드).
#
# **source 를 가드한다.** 위 truncate 가 이미 OUTPUT_PATH 를 0바이트로 만들어 놨고 트랩은
# 아직 안 떴다. `set -e` 아래에서 source 가 실패하면(사본 미배포·문법 오류) 스크립트는
# 여기서 즉사하고 **0바이트 산출물**이 남는다 — 소비자에게 그것은 "codex 성공, 발견 0건"
# 이다. 추출을 하며 새로 생긴 실패 경로이므로 여기서 닫는다. 산출물을 쓸 수 있으면
# 계약대로 degrade + exit 0, 그것마저 실패하면 exit 3(호출자가 stale 을 지운다).
# shellcheck source=/dev/null
_RUNNER_COMMON="$(dirname -- "${BASH_SOURCE[0]}")/runner_common.sh"
# `[ -r ]` + `bash -n` 을 **source 앞에** 둔다. `.` 는 POSIX special builtin 이라
# 파일이 없으면 bash 3.2.57 이 `if !` 안에서도 셸을 **즉시 종료**시키고(실측),
# 문법이 깨진 파일은 source 하는 순간 rc=2 로 죽는다 — 둘 다 이 if 로는 못 잡는다.
# 그래서 "읽을 수 있는가"와 "파싱되는가"를 먼저 묻고 그 다음에만 실제로 싣는다.
if [ -r "$_RUNNER_COMMON" ] && bash -n "$_RUNNER_COMMON" 2>/dev/null \
   && . "$_RUNNER_COMMON"; then
  :
else
  printf 'findings: []\nmeta:\n  codex_failed: true\n  reason: runner_common_unloadable\n  exit_code: 0\n' \
    > "$OUTPUT_PATH" 2>/dev/null || {
      echo "[quality-gates] runner_common.sh 로드 실패 + 산출물 기록 실패 — 호출자는 stale 을 지워야 한다" >&2
      exit 3
    }
  echo "[quality-gates] runner_common.sh 를 로드할 수 없다 — degrade 기록 후 종료(공유 정본 미배포)" >&2
  exit 0
fi
# 인자를 넘긴다 — 정본은 호출자의 전역 `$OUTPUT_PATH` 를 읽지 않는다. 인자 없이 부르면
# 정본의 `-n` 가드가 rc=3 을 내고 **아무것도 쓰지 않는다**(degrade 소실).
trap '_degrade_if_empty "$OUTPUT_PATH" aborted_before_completion' EXIT

if [[ -z "$PROJECT_DIR" ]]; then
  echo '{"codex_failed": true, "reason": "missing_project_dir"}' > "$OUTPUT_PATH"
  exit 0
fi
cd "$PROJECT_DIR" || {
  echo '{"codex_failed": true, "reason": "project_dir_unreachable"}' > "$OUTPUT_PATH"
  exit 0
}

SCRATCH="$(mktemp -d -t qg-codex-rev-XXXXXX)" || {
  echo '{"codex_failed": true, "reason": "scratch_dir_uncreatable"}' > "$OUTPUT_PATH"
  exit 0
}
PROMPT_FILE="$SCRATCH/prompt.md"
STDOUT_FILE="$SCRATCH/codex.jsonl"
STDERR_FILE="$SCRATCH/codex.stderr"

# --- Spec AC resolution (v2.1.0: codex review is spec-aware) ----------------
# The spec is the AC truth. Inject only the spec's Acceptance Criteria SECTION
# (not the whole spec — prompt-bloat mitigation, spec R3) into <spec_context>.
# Resolution is script-internal: invocation parity with discover-plan.sh means
# the SKILL allowed-tools list is NOT touched. Graceful + LOUD on every branch.
SPEC_AC="/dev/null"
if [[ "${DEVBREW_QG_DISABLE_SPEC_CONFORMANCE:-}" == "1" ]]; then
  echo "[quality-gates] codex spec context: DISABLED via DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1 — empty <spec_context>." >&2
elif [[ -n "${SPEC_AC_FILE:-}" && -f "${SPEC_AC_FILE}" ]]; then
  SPEC_AC="$SPEC_AC_FILE"
  echo "[quality-gates] codex spec context: using explicit SPEC_AC_FILE=$SPEC_AC_FILE" >&2
else
  SPEC_JSON="$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/discover-spec.sh" 2>/dev/null || true)"
  if [[ -z "$SPEC_JSON" ]]; then
    echo "[quality-gates] codex spec context: discover-spec.sh produced no output (script missing or crashed? check CLAUDE_PLUGIN_ROOT) — empty <spec_context>." >&2
  else
    SPEC_PATH="$(printf '%s' "$SPEC_JSON" | sed -n 's/.*"spec_path":"\([^"]*\)".*/\1/p')"
    if [[ -n "$SPEC_PATH" && -f "$SPEC_PATH" ]]; then
      # Extract only the spec's Acceptance Criteria SECTION: start at the AC
      # header (ANY depth — matches discover-spec.sh's ^#+ eligibility), record
      # its depth, and stop at the next header of the SAME-OR-SHALLOWER depth.
      # Deeper subsections (e.g. #### under a ### AC) stay in; sibling/parent
      # sections do not bleed in. A real '# '-style header is required, so a
      # prose line merely containing the phrase does not start extraction.
      awk '/^#+ /{h=$0;sub(/[^#].*/,"",h);d=length(h);if(!inac&&$0~/[Aa]cceptance [Cc]riteria/){inac=1;acd=d;print;next}if(inac&&d<=acd)exit} inac' "$SPEC_PATH" > "$SCRATCH/spec_ac.md"
      if [[ -s "$SCRATCH/spec_ac.md" ]]; then
        SPEC_AC="$SCRATCH/spec_ac.md"
        echo "[quality-gates] codex spec context: injected Acceptance Criteria from $SPEC_PATH" >&2
      else
        echo "[quality-gates] codex spec context: AC section empty after extraction from $SPEC_PATH — empty <spec_context>." >&2
      fi
    else
      echo "[quality-gates] codex spec context: no project spec found (searched docs/superpowers/specs/) — empty <spec_context>, v2.0.0 behavior." >&2
    fi
  fi
fi

# Build prompt (spec AC from resolution above, or empty when /dev/null).
if ! python3 "${CLAUDE_PLUGIN_ROOT}/scripts/build_codex_prompt.py" \
       "$DIFF_PATH" "$SPEC_AC" > "$PROMPT_FILE"; then
  echo '{"codex_failed": true, "reason": "prompt_build_failed"}' > "$OUTPUT_PATH"
  exit 0
fi

# Canonical codex invocation (spec §4.3 — load-bearing flags preserved):
#   -s read-only     : Layer 3 sandbox (file-system writes blocked)
#   -C "$PROJECT_DIR": working directory pin (single pipeline coordinate)
#   --json           : JSONL stream output
#   -                : 프롬프트를 stdin으로 받는다 (argv 경유는 ARG_MAX 절벽)
#   < "$PROMPT_FILE" : 그 stdin. `< /dev/null`을 남기면 교착이 아니라
#                      "No prompt provided via stdin." + exit 1이 된다.
#
# 추론 강도(`model_reasoning_effort`)는 핀하지 않는다 — 사용자 codex 설정이 지배한다.
# 하니스가 "medium"을 박으면 high/xhigh로 설정한 사용자가 조용히 하향되고, 그 하향은
# 이 co-reviewer의 유일한 존재 이유(별-모델 적발력)를 정확히 깎는다. 바닥값이
# 필요하다는 판단이 서면 그때 명시적으로 문서화해서 넣는다.
# (`run_brief_codex_reviewer.sh`가 이미 쓰던 계약을 전파한 것이다.)
#
# Direct codex invocation — no per-call timeout (hang risk accepted; backstops:
# Bash tool timeout, DEVBREW_DISABLE_QG_CODEX=1, /cancel-qg). Layer 3 sandbox
# (-s read-only) preserved. `|| EXIT_CODE=$?` keeps capture safe under set -e.
#
# 웹 posture를 **명시한다.** 미지정은 codex 기본값(`web_search = "cached"`)에 맡기는
# 것이라 "이 호출부는 웹을 쓰지 않는다"가 어디에도 적혀 있지 않게 된다. 코드 diff
# 리뷰는 외부 근거가 필요 없고, 외부 조회가 결과를 비결정적으로 만든다. kill switch가
# 없는 이유: 이미 OFF라 끌 것이 없다(죽은 스위치를 만들지 않는다, AC21).
EXIT_CODE=0
codex exec - \
    -C "$PROJECT_DIR" \
    -s read-only \
    -c 'tools.web_search=false' \
    -c 'web_search="disabled"' \
    --json \
    < "$PROMPT_FILE" \
    > "$STDOUT_FILE" \
    2>"$STDERR_FILE" || EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
  OVERRIDE_REASON=exit_nonzero
else
  OVERRIDE_REASON=""
fi

# 종단 추출은 이 스크립트에서 유일하게 가드 없던 단계였다. codex_findings_to_yaml.py는
# 정상적으로는 findings 또는 codex_failed를 담아 exit 0 하지만, 처리되지 않은 crash
# (python3 부재, plugin-root 문제)는 `> "$OUTPUT_PATH"` 리다이렉트가 이미 파일을
# 비운 뒤에 일어난다 → 0바이트 산출물. 소비자에게 그것은 "codex가 성공했고 발견이
# 없다"로 읽힌다 — 리뷰어 하나가 조용히 사라지는 것이다. 형제 두 러너
# (run_artifact_codex_reviewer.sh, run_spec_codex_reviewer.sh)는 이 가드를 이미
# 갖고 있었고 주석으로 같은 실패를 지목하고 있었다; 여기에만 백포트되지 않았다.
# `-s` 검사가 별도로 필요한 이유: exit 0 + 빈 출력이 가능하다(파이프 실패, 부분 쓰기).
if ! python3 "${CLAUDE_PLUGIN_ROOT}/scripts/codex_findings_to_yaml.py" \
    --stderr-file "$STDERR_FILE" \
    --meta-override-exit-code "$EXIT_CODE" \
    --meta-override-reason "$OVERRIDE_REASON" \
    < "$STDOUT_FILE" > "$OUTPUT_PATH" || [[ ! -s "$OUTPUT_PATH" ]]; then
  echo "[quality-gates] codex 추출 실패 — 빈 산출물 대신 codex_failed를 기록한다 (리뷰어 1명 손실, degrade)" >&2
  # 최상위 `agent:` 를 내지 않는다 — 성공 경로(codex_findings_to_yaml.py 의 yaml_emit)가
  # `agent:` 를 finding 마다 달 뿐 최상위에는 내지 않으므로, 이 키는 degrade 경로에만
  # 있던 스키마 drift 였다(설계 §6.2 "`agent:` 포함 중첩 → 없는 중첩"). 읽는 소비자도 없다.
  printf 'findings: []\nmeta:\n  codex_failed: true\n  exit_code: %s\n  reason: extract_failed\n' \
    "$EXIT_CODE" > "$OUTPUT_PATH"
fi
