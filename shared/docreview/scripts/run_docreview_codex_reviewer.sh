#!/usr/bin/env bash
# run_docreview_codex_reviewer.sh — 문서 리뷰 엔진(shared/docreview)의 codex co-reviewer. 정본.
#
# **처분** — consumer=orchestrator · fail-open · disclosure=advisory
#
# 실제 소비자는 같은 엔진의 docreview_route.py(§6.3 라우팅의 codex 입력)다. 이 파일은
# spec-distill·quality-gates 두 플러그인에 같은 파일 단위 심볼릭 링크로 배포되므로(설계
# §12 「신규(호스트)」) consumer= 경로가 어느 한 플러그인과도 같을 수 없다(처분 락 축 A⑤
# — 이 파일 자체가 애초에 어느 플러그인 서브트리에도 없다). 그래서 orchestrator 로 적고
# 실제 소비자는 이 주석이 밝힌다. fail-open 인 이유는 형제 run_spec_codex_reviewer.sh 와
# 같다 — codex 는 모델 다양성 보조지 주 판정자가 아니다(설계 §9 「codex 부재·실패」행:
# 공시하되 막지 않는다).
#
# Usage: run_docreview_codex_reviewer.sh <profile.md> <doc-or-bundle> <project_dir> <out_yaml>
# 성공·실패 모두 <out_yaml> 에 codex_findings_to_yaml.py --emit-keys docreview 스키마의
# 중첩 YAML 을 쓴다. <out_yaml> 자체를 못 쓰면(디렉토리 부재·권한·RO 마운트) YAML 이
# 애초에 불가능하므로 rc 3 으로 죽는다 — 호출자는 rc==3 을 보면 <out_yaml> 을 지워야
# 한다(형제 run_spec_codex_reviewer.sh·run_brief_codex_reviewer.sh 와 같은 계약. 이 fail-
# closed 가 핵심이다 — 조용히 죽으면 직전 라운드의 stale YAML 이 이번 라운드 판정으로
# 읽힌다).
#
# 프롬프트 빌더는 자리별 파일(build_*_codex_prompt.py)로 안 뽑는다 — 문서 리뷰 엔진은
# 프로필 넷을 전부 이 러너 하나로 흡수하므로(설계 §5.2), 빌더는 아래 인라인 python 함수
# 하나다.
set -euo pipefail

PROFILE="${1:-}"
DOC="${2:-}"
PROJECT_DIR="${3:-}"
OUTPUT_PATH="${4:-}"

# CLAUDE_PLUGIN_ROOT는 훅 실행에만 주입된다 — 스킬의 bash 블록에는 오지 않는다.
# fallback 없이 참조하면 `set -u` 아래서 codex에 도달하기 전에 즉사한다. 형제
# 러너들과 같은 철자를 쓴다(세 번째 철자를 발명하지 않는다).
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

if [[ -z "$OUTPUT_PATH" ]]; then
  echo "usage: run_docreview_codex_reviewer.sh <profile> <doc-or-bundle> <project_dir> <out_yaml>" >&2
  exit 2
fi

# 절대화는 `cd "$PROJECT_DIR"` **이전**이다 — 아니면 상대 경로가 project_dir 기준으로
# 조용히 잘못 풀린다(형제 run_spec_codex_reviewer.sh B3 의 교훈과 같은 자리).
[[ "$OUTPUT_PATH" = /* ]] || OUTPUT_PATH="$PWD/$OUTPUT_PATH"
[[ "$DOC" = /* ]] || DOC="$PWD/$DOC"
[[ "$PROFILE" = /* ]] || PROFILE="$PWD/$PROFILE"

# stale 제거 + 쓰기 가능성 확인을 자원을 처음 만지는 지점에서 한다. 여기서 실패하면
# YAML 자체가 불가능하므로 rc 3 — 호출자가 <out_yaml> 을 지워야 한다는 계약의 근거다.
: > "$OUTPUT_PATH" 2>/dev/null || {
  echo "[docreview] 산출물 경로에 쓸 수 없다: $OUTPUT_PATH" >&2
  exit 3
}

# `write_failclosed` · `_degrade_if_empty` 는 shared/codex/runner_common.sh 정본을
# 그대로 쓴다(설계 §5.2 표 「reviewing-document.md」 행의 의존). source 를 가드한다 —
# 위 guarded truncate 가 이미 OUTPUT_PATH 를 0바이트로 만들어 놨고 트랩은 아직
# 안 떴다. source 실패가 `set -e` 아래서 즉사하면 0바이트 산출물이 "성공, 발견 0건"
# 으로 읽힌다.
# shellcheck source=/dev/null
_RUNNER_COMMON="$(dirname -- "${BASH_SOURCE[0]}")/runner_common.sh"
if [ -r "$_RUNNER_COMMON" ] && bash -n "$_RUNNER_COMMON" 2>/dev/null \
   && . "$_RUNNER_COMMON"; then
  :
else
  printf 'findings: []\nmeta:\n  codex_failed: true\n  reason: runner_common_unloadable\n  exit_code: 0\n' \
    > "$OUTPUT_PATH" 2>/dev/null || {
      echo "[docreview] runner_common.sh 로드 실패 + 산출물 기록 실패 — 호출자는 stale 을 지워야 한다" >&2
      exit 3
    }
  echo "[docreview] runner_common.sh 를 로드할 수 없다 — degrade 기록 후 종료(공유 정본 미배포)" >&2
  exit 0
fi
emit_fallback() { write_failclosed "$OUTPUT_PATH" "$1" || exit 3; exit 0; }

[[ -n "$PROJECT_DIR" ]] || emit_fallback missing_project_dir
[[ -f "$PROFILE" ]] || emit_fallback profile_missing
[[ -f "$DOC" ]] || emit_fallback doc_missing
cd "$PROJECT_DIR" || emit_fallback project_dir_unreachable

# 스크래치 디렉토리 대입은 트랩 무장 **이전**이다(`cd ""` repo-delete footgun 회피).
SCRATCH="$(mktemp -d -t docreview-codex-XXXXXX)" || emit_fallback scratch_dir_uncreatable
# 트랩 한 줄 — 여러 줄로 펼치면 순서 락이 이 줄을 못 보고 무력화된다(형제 러너 계약과 같다).
trap 'rm -rf "$SCRATCH"; _degrade_if_empty "$OUTPUT_PATH" aborted_before_completion' EXIT
PROMPT_FILE="$SCRATCH/prompt.md"
WEB_META_FILE="$SCRATCH/web.meta"
STDOUT_FILE="$SCRATCH/codex.jsonl"
STDERR_FILE="$SCRATCH/codex.stderr"

# 프롬프트 조립(러너 안 인라인 빌더) — 프로필의 frontmatter(`layer_rubric` ·
# `allowed_dispositions` · `web`) 와 shared/codex/prompt-preamble.md(P21) 로 프롬프트
# 하나를 낸다. `web` 판정을 **같은 호출에서** WEB_META_FILE 에 함께 써서, frontmatter
# 파싱을 두 번(프롬프트용 · 웹 스위치용) 하지 않는다 — 파싱이 한 곳이면 그 결과를 두
# 갈래로 읽는 자리가 하나이므로 웹 인자를 만드는 지점도 하나로 유지하기 쉽다(P11).
if ! python3 - "$PROFILE" "$DOC" "$PLUGIN_ROOT/scripts/prompt-preamble.md" "$WEB_META_FILE" \
       > "$PROMPT_FILE" <<'PY'
import pathlib, re, sys
import yaml

prof_path, doc_path, preamble_path, meta_path = sys.argv[1:5]

t = pathlib.Path(prof_path).read_text(encoding="utf-8")
m = re.match(r"^---\n(.*?)\n---\n", t, re.DOTALL)
fm = (yaml.safe_load(m.group(1)) if m else None) or {}
lr = fm.get("layer_rubric") or {}
ad = fm.get("allowed_dispositions") or []
web = fm.get("web") is True
pathlib.Path(meta_path).write_text("web: %s\n" % ("true" if web else "false"), encoding="utf-8")

pre = ""
pre_p = pathlib.Path(preamble_path)
if pre_p.is_file():
    # P21 preamble 은 HTML 주석 줄을 제거한 뒤 프롬프트에 넣는다 — 그 마커가 본문으로
    # 새면 모델이 그것을 지시로 읽는다(shared/codex/prompt-preamble.md 자체 주석).
    pre = "\n".join(line for line in pre_p.read_text(encoding="utf-8").splitlines()
                    if not re.match(r"^\s*<!--.*-->\s*$", line))

doc = pathlib.Path(doc_path).read_text(encoding="utf-8")

print("You are an independent document reviewer in a read-only sandbox. Do NOT modify files.")
print("\nReview the document in two layers.")
print("Layer 1 (big-picture coherence) — categories: "
      + ", ".join(str(x) for x in lr.get("layer1", [])))
l2 = lr.get("layer2") or ["(none — skip layer 2)"]
print("Layer 2 (detail completeness) — categories: " + ", ".join(str(x) for x in l2))
print("For each finding assign a disposition from: " + ", ".join(str(x) for x in ad))
print("  decide = user must decide · ask = ask the user · fix = author edits · drop = not worth raising"
      + (" · defer = hand to the implementation plan" if "defer" in ad else ""))
print("Zero findings is a valid honest answer.")
print("\n" + pre)
print('\nEmit ONE fenced JSON block. `disposition` is required unless you cannot judge it.')
print('```json\n{"findings":[{"ref":"x1","layer":1,"category":"...","anchor":"#slug",'
      '"disposition":"...","summary":"...","edit_scope":"#slug","blocks":[],"evidence":"..."}]}\n```')
print("\n<document>\n" + doc + "\n</document>")
PY
then emit_fallback prompt_build_failed; fi

# 웹 스위치 — 이 if/else 가 WEB_ARGS 를 만드는 **유일한 자리**다(P11). 기본값은 꺼짐:
# 프로필 web:false 면 두 kill switch 와 무관하게 꺼져 있고(WEB_META_FILE 이 "web: false"),
# `web: true` 여도 두 호스트 kill switch(DEVBREW_SPEC_DISTILL_DISABLE_WEB ·
# DEVBREW_QUALITY_GATES_DISABLE_WEB) 중 하나라도 켜져 있으면 끈다 — 공유 러너는 자기
# 호스트를 모르므로 과잉 적용(둘 다 검사)이 안전한 방향이다.
WEB_ARGS=(-c 'tools.web_search=false' -c 'web_search="disabled"')
WEB_META_VAL="$(cat "$WEB_META_FILE" 2>/dev/null || true)"
if [[ "$WEB_META_VAL" == "web: true" \
      && "${DEVBREW_SPEC_DISTILL_DISABLE_WEB:-0}" != "1" \
      && "${DEVBREW_QUALITY_GATES_DISABLE_WEB:-0}" != "1" ]]; then
  WEB_ARGS=(-c 'tools.web_search=true' -c 'web_search="live"')
elif [[ "$WEB_META_VAL" == "web: true" ]]; then
  echo "[docreview] web 비활성(kill switch) — codex 리포 근거만" >&2
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
[[ $EXIT_CODE -ne 0 ]] && OVERRIDE_REASON=exit_nonzero

if ! python3 "$PLUGIN_ROOT/scripts/codex_findings_to_yaml.py" \
       --stderr-file "$STDERR_FILE" \
       --meta-override-exit-code "$EXIT_CODE" \
       --meta-override-reason "$OVERRIDE_REASON" \
       --emit-keys docreview \
       < "$STDOUT_FILE" > "$OUTPUT_PATH"; then
  echo 'findings: []' > "$OUTPUT_PATH"
  echo 'meta:' >> "$OUTPUT_PATH"; echo '  codex_failed: true' >> "$OUTPUT_PATH"
  echo '  reason: yaml_conversion_failed' >> "$OUTPUT_PATH"
  exit 0
fi
