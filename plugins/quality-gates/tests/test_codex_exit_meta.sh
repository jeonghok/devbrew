#!/usr/bin/env bash
# codex 가 0 아닌 종료로 끝나면 산출물 meta 에 codex 의 종료 코드(`exit_code`)와 stderr 첫 줄(`stderr_head`,
# 200자에서 자름)이 남는다 — `reason: exit_nonzero` 만으로는 왜 죽었는지 알 수 없다.
# 중첩 YAML 러너 둘(run_codex_reviewer.sh · run_docreview_codex_reviewer.sh)은 공유 추출기
# codex_findings_to_yaml.py 가, 평면 YAML 러너(run_artifact_codex_reviewer.sh)는 extract_codex_artifact_yaml.py 가 쓴다.
# codex 는 PATH 앞의 스텁이다(과금 · 네트워크 없음).
# Run (리포 루트에서): bash plugins/quality-gates/tests/test_codex_exit_meta.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
QG="$ROOT/plugins/quality-gates"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT

LONG="$(printf 'word %.0s' $(seq 1 100))"
printf '\n  ERROR: model overloaded (retry later)\nSECOND_LINE_MUST_NOT_APPEAR\n' > "$T/err.txt"
printf '%s\nSECOND_LINE_MUST_NOT_APPEAR\n' "$LONG" > "$T/err-long.txt"
printf '%s\n' '{"type":"item.completed","item":{"type":"agent_message","text":"```json\n{\"findings\": []}\n```"}}' > "$T/ok.jsonl"
meta_val() {  # meta_val <파일> <키> — meta 블록의 그 키 값(따옴표 그대로)
  sed -n "s/^  $2: //p" "$1" | head -n 1
}

# ── 공유 추출기(중첩 YAML 러너 둘) ─────────────────────────────────────────────
X="$QG/scripts/codex_findings_to_yaml.py"
python3 "$X" --stderr-file "$T/err.txt" --meta-override-exit-code 7 --meta-override-reason exit_nonzero < "$T/ok.jsonl" > "$T/a.yaml"
assert_eq "$(meta_val "$T/a.yaml" exit_code)" "7" "공유 추출기: 0 아닌 종료면 meta 에 codex 종료 코드"
assert_contains "$(meta_val "$T/a.yaml" stderr_head)" "ERROR: model overloaded (retry later)" "공유 추출기: meta 에 stderr 의 첫 비어 있지 않은 줄"
assert_file_absent "$T/a.yaml" 'SECOND_LINE_MUST_NOT_APPEAR' "공유 추출기: stderr 둘째 줄은 싣지 않는다"
python3 "$X" --stderr-file "$T/err-long.txt" --meta-override-exit-code 7 --meta-override-reason exit_nonzero < "$T/ok.jsonl" > "$T/b.yaml"
v="$(meta_val "$T/b.yaml" stderr_head)"
assert_contains "$v" "word word word" "공유 추출기: 긴 첫 줄도 싣는다(양성 짝)"
[ "$(printf '%s' "$v" | tr -d '"'"'" | wc -c | tr -d ' ')" -le 200 ] \
  && ok "공유 추출기: stderr 첫 줄은 200자에서 자른다" || no "공유 추출기: stderr 첫 줄이 200자를 넘는다(${#v})"
# 비밀처럼 생긴 긴 낱말(20자 이상의 영숫자 · _-+=. 연속)은 가린다 — 이 meta 는 리뷰 기록 문서로 옮겨져 커밋될 수 있다.
printf 'ERROR: 401 Authorization: Bearer sk-ant-api03-SECRETTOKENVALUE0123456789 rejected\n' > "$T/err-secret.txt"
python3 "$X" --stderr-file "$T/err-secret.txt" --meta-override-exit-code 7 --meta-override-reason exit_nonzero < "$T/ok.jsonl" > "$T/s.yaml"
assert_file_absent "$T/s.yaml" 'SECRETTOKENVALUE' "공유 추출기: stderr 첫 줄의 비밀처럼 생긴 긴 낱말을 가린다"
assert_contains "$(meta_val "$T/s.yaml" stderr_head)" "Authorization: Bearer" "공유 추출기: 가린 뒤에도 나머지 글은 남는다(양성 짝)"
python3 "$X" --stderr-file "$T/err.txt" < "$T/ok.jsonl" > "$T/c.yaml"
assert_file_absent "$T/c.yaml" 'stderr_head' "공유 추출기: codex 가 0 으로 끝나면 stderr 를 싣지 않는다"
assert_file_grep "$T/c.yaml" '^  codex_failed: false$' "공유 추출기: 0 종료는 성공 표식(양성 짝)"

# ── 평면 YAML 추출기(artifact 러너) ───────────────────────────────────────────
XA="$QG/scripts/extract_codex_artifact_yaml.py"
python3 "$XA" --stderr-file "$T/err.txt" --meta-override-exit-code 7 --meta-override-reason exit_nonzero < "$T/ok.jsonl" > "$T/d.yaml"
assert_file_grep "$T/d.yaml" '^codex_failed: true$' "artifact 추출기: 0 아닌 종료는 실패 표식"
assert_eq "$(sed -n 's/^exit_code: //p' "$T/d.yaml")" "7" "artifact 추출기: codex 종료 코드를 남긴다"
assert_contains "$(sed -n 's/^stderr_head: //p' "$T/d.yaml")" "ERROR: model overloaded (retry later)" "artifact 추출기: stderr 첫 줄을 남긴다"
assert_file_absent "$T/d.yaml" 'SECOND_LINE_MUST_NOT_APPEAR' "artifact 추출기: stderr 둘째 줄은 싣지 않는다"
python3 "$XA" --stderr-file "$T/err-long.txt" --meta-override-exit-code 7 --meta-override-reason exit_nonzero < "$T/ok.jsonl" > "$T/e.yaml"
v="$(sed -n 's/^stderr_head: //p' "$T/e.yaml")"
[ -n "$v" ] && [ "$(printf '%s' "$v" | tr -d '"'"'" | wc -c | tr -d ' ')" -le 200 ] \
  && ok "artifact 추출기: stderr 첫 줄은 200자에서 자른다" || no "artifact 추출기: 200자 자르기 실패(${#v})"
python3 "$XA" --stderr-file "$T/err-secret.txt" --meta-override-exit-code 7 --meta-override-reason exit_nonzero < "$T/ok.jsonl" > "$T/f.yaml"
assert_file_absent "$T/f.yaml" 'SECRETTOKENVALUE' "artifact 추출기: 비밀처럼 생긴 긴 낱말을 가린다"
assert_contains "$(sed -n 's/^stderr_head: //p' "$T/f.yaml")" "Authorization: Bearer" "artifact 추출기: 가린 뒤에도 나머지 글은 남는다(양성 짝)"

# ── 러너 끝에서 끝: codex 스텁이 stderr 를 쓰고 7 로 끝난다 ─────────────────────
mkdir -p "$T/bin" "$T/proot"
printf '#!/bin/sh\ncat >/dev/null\necho "  ERROR: model overloaded (retry later)" >&2\necho SECOND_LINE_MUST_NOT_APPEAR >&2\nexit 7\n' > "$T/bin/codex"
chmod +x "$T/bin/codex"
# discover-spec.sh 는 gh 로 PR 을 찾을 수 있다 — 아무것도 하지 않는 스텁으로 바꾼 플러그인 사본에서 돈다.
cp -RL "$QG/scripts" "$T/proot/" || exit 1
cp -RL "$QG/references" "$T/proot/" || exit 1
printf '#!/usr/bin/env bash\nexit 0\n' > "$T/proot/scripts/discover-spec.sh"
printf 'diff --git a/x b/x\n' > "$T/tiny.diff"
PATH="$T/bin:$PATH" CLAUDE_PLUGIN_ROOT="$T/proot" \
  bash "$T/proot/scripts/run_codex_reviewer.sh" "$T/tiny.diff" "$ROOT" "$T/r1.yaml" >/dev/null 2>"$T/r1.err"
assert_eq "$(meta_val "$T/r1.yaml" reason)" "exit_nonzero" "run_codex_reviewer.sh: reason exit_nonzero(양성 짝 — codex 까지 닿았다)"
assert_eq "$(meta_val "$T/r1.yaml" exit_code)" "7" "run_codex_reviewer.sh: meta 에 codex 종료 코드"
assert_contains "$(meta_val "$T/r1.yaml" stderr_head)" "ERROR: model overloaded" "run_codex_reviewer.sh: meta 에 codex stderr 첫 줄"
printf '아티팩트 fixture\n' > "$T/artifact.md"
PATH="$T/bin:$PATH" CLAUDE_PLUGIN_ROOT="$T/proot" \
  bash "$T/proot/scripts/run_artifact_codex_reviewer.sh" "$T/artifact.md" "$ROOT" "$T/r2.yaml" >/dev/null 2>"$T/r2.err"
assert_eq "$(sed -n 's/^reason: //p' "$T/r2.yaml")" "exit_nonzero" "run_artifact_codex_reviewer.sh: reason exit_nonzero(양성 짝)"
assert_eq "$(sed -n 's/^exit_code: //p' "$T/r2.yaml")" "7" "run_artifact_codex_reviewer.sh: 산출물에 codex 종료 코드"
assert_contains "$(sed -n 's/^stderr_head: //p' "$T/r2.yaml")" "ERROR: model overloaded" "run_artifact_codex_reviewer.sh: 산출물에 codex stderr 첫 줄"
# docreview 러너는 공유 추출기에 --stderr-file 과 종료 코드를 넘긴다 — 위 공유 추출기 단언이 그 meta 를 잰다.
DR="$ROOT/shared/docreview/scripts/run_docreview_codex_reviewer.sh"
assert_file_grep "$DR" '^ +--stderr-file "\$STDERR_FILE" \\$' "run_docreview_codex_reviewer.sh: 공유 추출기에 codex stderr 를 넘긴다"
assert_file_grep "$DR" '^ +--meta-override-exit-code "\$EXIT_CODE" \\$' "run_docreview_codex_reviewer.sh: 공유 추출기에 codex 종료 코드를 넘긴다"

finish
