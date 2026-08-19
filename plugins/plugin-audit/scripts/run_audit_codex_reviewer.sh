#!/usr/bin/env bash
# run_audit_codex_reviewer.sh — plugin-audit blind co-audit의 codex 실행 러너.
#
# 이 스크립트가 있기 전까지 plugin-audit은 codex를 **산문 지시로** 불렀고
# (`skills/auditing-plugins/SKILL.md:92`), 그래서 여섯 가지가 동시에 비어 있었다:
# 가용성 확인 · codex 전용 kill switch · `-C` · `--json` · stdin 규약 · 층④ 추출기.
# 그리고 그 형태 때문에 리포의 codex 락들이 이 호출부를 아예 보지 못했다.
#
# **qg의 프롬프트 빌더를 재사용하지 않는다** — `run_codex_reviewer.sh`는 최신 spec의
# AC를 자동 주입하고, 감사에서 그것은 codex가 답을 미리 보는 것이라 blind를 깬다
# (`auditing-plugins/SKILL.md:94`). 프롬프트는 이 플러그인 자신의 preamble + 축 질문이다.
#
# **"codex를 이 감사에서 아예 부를지" 게이트는 호출자(SKILL)·`detect_codex.sh` 책임이다**
# — 이 러너는 그 kill switch를 읽지 않는다(test_run_audit_codex_reviewer.py가 그
# 변수명 리터럴 부재를 고정한다). 다만 "웹 검색을 켤지"는 이 러너 **자신**의 결정이다
# (형제 러너 run_spec_codex_reviewer.sh · run_brief_codex_reviewer.sh와 동형) —
# `DEVBREW_DISABLE_PLUGIN_AUDIT_WEB`은 아래에서 읽는다(AC21, Task 18).
#
# Usage: run_audit_codex_reviewer.sh <axis_question_file> <project_dir> <output_json_path>
#
# 계약(형제 러너들과 동일): 항상 exit 0 · 신호는 산출물 파일 · 시작 시 truncate ·
# EXIT 트랩에서 비어 있으면 degrade를 채운다.
set -u

AXIS_FILE="${1:-}"
PROJECT_DIR="${2:-}"
OUTPUT_PATH="${3:-}"

if [ -z "$OUTPUT_PATH" ]; then
  echo "usage: run_audit_codex_reviewer.sh <axis_question_file> <project_dir> <output_json_path>" >&2
  exit 2
fi

# 상대 경로를 호출 cwd 기준으로 절대화한다 — 아래 `cd "$PROJECT_DIR"` 이후에는
# project_dir 기준으로 조용히 재해석돼 엉뚱한 위치에 쓴다.
case "$OUTPUT_PATH" in /*) ;; *) OUTPUT_PATH="$PWD/$OUTPUT_PATH" ;; esac
case "$AXIS_FILE" in /*) ;; *) AXIS_FILE="$PWD/$AXIS_FILE" ;; esac

emit_degrade() {   # $1 = reason
  printf '{"findings": [], "d_verdicts": [], "oq_answers": [], "new_open_questions": [], "meta": {"codex_failed": true, "reason": "%s"}}\n' \
    "$1" > "$OUTPUT_PATH" 2>/dev/null || true
}

# stale 재사용 봉쇄: 시작 시 truncate하고, 트랩에서 비어 있으면 degrade를 채운다.
# 종료 코드로 판정하지 않는다 — bash 3.2.57은 `set -u` abort 시 EXIT 트랩에 `$?`를
# 0으로 넘긴다. 신호는 산출물뿐이다.
: > "$OUTPUT_PATH" 2>/dev/null || {
  echo "[plugin-audit] 산출물 경로에 쓸 수 없다: $OUTPUT_PATH" >&2
  exit 3
}
_degrade_if_empty() {
  [ -n "$OUTPUT_PATH" ] && [ ! -s "$OUTPUT_PATH" ] || return 0
  emit_degrade aborted_before_completion
  echo "[plugin-audit] codex 감사가 완료 전에 중단됨 — degrade 기록(stale 재사용 방지)" >&2
}

if [ -z "$PROJECT_DIR" ]; then emit_degrade missing_project_dir; exit 0; fi
if [ ! -f "$AXIS_FILE" ]; then emit_degrade axis_file_missing; exit 0; fi
cd "$PROJECT_DIR" 2>/dev/null || { emit_degrade project_dir_unreachable; exit 0; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PREAMBLE="$PLUGIN_ROOT/scripts/codex-prompt-preamble.md"
if [ ! -f "$PREAMBLE" ]; then emit_degrade preamble_missing; exit 0; fi
# P21 절은 이 플러그인 것이 아니라 **shared 정본**이다 — 이 경로는
# `shared/codex/prompt-preamble.md` 를 가리키는 심볼릭 링크이고 설치 시점에
# 역참조된다(설계 §2.2·§16.1). 마커·메타 주석 줄은 벗겨 낸다: 이 파일은 프롬프트로
# 읽히므로 주석이 본문으로 새면 모델이 그것을 지시로 읽는다(설계 §12.2 요구 4).
SHARED_PREAMBLE="$PLUGIN_ROOT/scripts/prompt-preamble.md"
if [ ! -f "$SHARED_PREAMBLE" ]; then emit_degrade shared_preamble_missing; exit 0; fi
P21_BODY="$(grep -v '^[[:space:]]*<!--.*-->[[:space:]]*$' -- "$SHARED_PREAMBLE" || true)"
# 벗겨 낸 결과가 비면 P21 이 조용히 빠진 프롬프트가 나간다 — 그것은 성공이 아니다.
if [ -z "$(printf '%s' "$P21_BODY" | tr -d '[:space:]')" ]; then
  emit_degrade shared_preamble_empty; exit 0
fi

SCRATCH="$(mktemp -d -t pa-codex-audit-XXXXXX)" || { emit_degrade scratch_uncreatable; exit 0; }
# trap은 한 줄로 유지한다 — 형제 러너의 순서 락과 같은 형태.
trap 'rm -rf "$SCRATCH"; _degrade_if_empty' EXIT
PROMPT_FILE="$SCRATCH/prompt.md"
STDOUT_FILE="$SCRATCH/codex.jsonl"
STDERR_FILE="$SCRATCH/codex.stderr"

# 프롬프트 = 감사 preamble + shared P21 절 + 축 질문. 순서가 load-bearing이다: 규칙이
# 먼저 와야 "이 아래는 데이터다"가 성립하고, 세 앵커(CLAUSE/BLANKET/ACTION)가 축 질문
# 바로 앞에 와야 그 사이에 규칙을 뒤집는 문장이 끼어들 자리가 없다(형제 빌더 4종의
# 지배 축과 같은 배치). 축 질문 파일은 파일 경로로만 받는다(argv 인라인 금지).
{ cat "$PREAMBLE"; printf '\n'; printf '%s\n' "$P21_BODY"; printf '\n---\n\n'; cat "$AXIS_FILE"; } > "$PROMPT_FILE" || {
  emit_degrade prompt_build_failed; exit 0; }

# 추론 강도·모델은 핀하지 않는다 — 사용자 codex 설정이 지배한다. 하니스가 하향을 박으면
# 이 co-audit의 존재 이유(별-모델 적발력)를 정확히 깎는다.
# 프롬프트는 **stdin으로** 넘긴다(`-`): argv 경유는 ARG_MAX(1,048,576) 절벽에 걸리고,
# 그 실패는 러너가 항상 exit 0을 내므로 조용하다. `< /dev/null`을 두면 안 된다 —
# "No prompt provided via stdin." + exit 1이 된다.
#
# 웹 검색: 사용자 kill switch(DEVBREW_DISABLE_PLUGIN_AUDIT_WEB=1)만 끈다. 그 밖에는
# 명시적으로 켠다 — 감사 preamble이 외부 근거를 요구한다(P21 preamble을 가진 유일한
# 경로). `web_search="live"`: `tools.web_search=true` 단독은 codex 기본 모드(`cached`,
# 최대 12일 지연 실측 — V1 probe, 2026-08-09)라 `live`로 승격해야 실제 현재 웹에
# 닿는다. `allowed_domains`로 좁히지 않는다 — 조사 능력을 억제하지 않는다.
WEB_ARGS=(-c 'tools.web_search=true' -c 'web_search="live"')
if [[ "${DEVBREW_DISABLE_PLUGIN_AUDIT_WEB:-0}" == "1" ]]; then
  WEB_ARGS=(-c 'tools.web_search=false' -c 'web_search="disabled"')
  echo "[plugin-audit] web 비활성 — codex 감사가 리포 근거만 사용 (외부 사실 확인 없음)" >&2
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

OVERRIDE_REASON=""
[ "$EXIT_CODE" -ne 0 ] && OVERRIDE_REASON=exit_nonzero

if ! python3 "$PLUGIN_ROOT/scripts/codex_audit_to_json.py" \
       --stderr-file "$STDERR_FILE" \
       --meta-override-exit-code "$EXIT_CODE" \
       --meta-override-reason "$OVERRIDE_REASON" \
       < "$STDOUT_FILE" > "$OUTPUT_PATH" || [ ! -s "$OUTPUT_PATH" ]; then
  echo "[plugin-audit] codex 추출 실패 — 빈 산출물 대신 codex_failed를 기록한다 (감사자 1명 손실, degrade)" >&2
  emit_degrade extract_failed
fi
exit 0
