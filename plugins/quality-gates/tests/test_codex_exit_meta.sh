#!/usr/bin/env bash
# guards: plugins/quality-gates/scripts/codex_findings_to_yaml.py shared/codex/codex_findings_to_yaml.py plugins/quality-gates/scripts/extract_codex_artifact_yaml.py plugins/quality-gates/scripts/run_codex_reviewer.sh plugins/quality-gates/scripts/run_artifact_codex_reviewer.sh shared/docreview/scripts/run_docreview_codex_reviewer.sh
# codex 가 0 아닌 종료로 끝나면 산출물 meta 에 codex 의 종료 코드(`exit_code`)와 알려진 사유 분류(`stderr_kind`)가
# 남는다 — `reason: exit_nonzero` 만으로는 왜 죽었는지 알 수 없다. stderr 원문은 기록에 싣지 않는다(비밀이 섞일 수
# 있다). 원문 첫 줄은 실행 중 화면(추출기 stderr)에만 보이고, 그때도 비밀처럼 생긴 것을 가린다.
# 중첩 YAML 러너 둘(run_codex_reviewer.sh · run_docreview_codex_reviewer.sh)은 공유 추출기
# codex_findings_to_yaml.py 가, 평면 YAML 러너(run_artifact_codex_reviewer.sh)는 extract_codex_artifact_yaml.py 가 쓴다.
# codex 는 PATH 앞의 스텁이다(과금 · 네트워크 없음).
# Run (리포 루트에서): bash plugins/quality-gates/tests/test_codex_exit_meta.sh
set -u
[ "${1:-}" = "--emit-scanned" ] && { printf '%s\n' \
  plugins/quality-gates/scripts/codex_findings_to_yaml.py \
  shared/codex/codex_findings_to_yaml.py \
  plugins/quality-gates/scripts/extract_codex_artifact_yaml.py \
  plugins/quality-gates/scripts/run_codex_reviewer.sh \
  plugins/quality-gates/scripts/run_artifact_codex_reviewer.sh \
  shared/docreview/scripts/run_docreview_codex_reviewer.sh; exit 0; }
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
QG="$ROOT/plugins/quality-gates"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT

# 둘째 줄 표지는 가림 규칙(20자 이상 연속 · 자격 증명 낱말)에 걸리지 않는 꼴이다 — 걸리면 부재 단언이 공허하다.
SECOND='second line here'
printf '\n  ERROR: model overloaded (retry later)\n%s\n' "$SECOND" > "$T/err.txt"
printf '%s\n' '{"type":"item.completed","item":{"type":"agent_message","text":"```json\n{\"findings\": []}\n```"}}' > "$T/ok.jsonl"
: > "$T/empty.jsonl"
# codex --json 의 실제 실패 꼴(사용 한도) — 사유는 stdout 의 error · turn.failed 이벤트에 있고 stderr 는 빈다.
cat > "$T/limit.jsonl" <<'JSONL'
{"type":"thread.started","thread_id":"01a1801a-f63d-7873-b04e-a8bee9838965"}
{"type":"turn.started"}
{"type":"error","message":"You’ve hit your usage limit. Upgrade to Pro (https://chatgpt.com/explore/pro), visit https://chatgpt.com/codex/settings/usage to purchase more credits or try again at Nov 2nd, 2026 3:13 PM."}
{"type":"turn.failed","error":{"message":"You’ve hit your usage limit. Upgrade to Pro (https://chatgpt.com/explore/pro), visit https://chatgpt.com/codex/settings/usage to purchase more credits or try again at Nov 2nd, 2026 3:13 PM."}}
JSONL
: > "$T/err-empty.txt"
# 재시도로 성공한 실행 — error 이벤트가 있어도 0 으로 끝났으면 분류하지 않는다.
{ printf '%s\n' '{"type":"error","message":"stream disconnected, retrying"}'; cat "$T/ok.jsonl"; } > "$T/retried.jsonl"
# findings JSON 이 아닌 agent 메시지 — 인증 실패 둘째 갈래(메시지는 있으나 findings 가 없다)를 밟는다.
printf '%s\n' '{"type":"item.completed","item":{"type":"agent_message","text":"not json"}}' > "$T/notjson.jsonl"
meta_val() {  # meta_val <파일> <키> — meta 블록의 그 키 값(따옴표 그대로)
  sed -n "s/^  $2: //p" "$1" | head -n 1
}
# 비밀 꼴 넷 — 길고 / 가 든 키 · 자격 증명 낱말 뒤의 짧은 값 · 따옴표 든 키 · 띄어 쓴 값
cat > "$T/err-secret.txt" <<'ERR'
ERROR: 401 Authorization: Bearer sk-ant-api03-SECRETTOKENVALUE0123456789 aws wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY {"password":"hunter2"} password="correct horse battery staple" api key abc123 rejected
ERR
no_secret() {  # no_secret <파일> <이름>
  local s
  for s in SECRETTOKENVALUE bPxRfiCYEXAMPLEKEY hunter2 'horse battery' abc123; do
    assert_file_absent "$1" "${s}" "${2}: 비밀 「${s}」 이 없다"
  done
}

# ── 공유 추출기(중첩 YAML 러너 둘) ─────────────────────────────────────────────
X="$QG/scripts/codex_findings_to_yaml.py"
XA_EARLY="$QG/scripts/extract_codex_artifact_yaml.py"
python3 "$X" --stderr-file "$T/err.txt" --meta-override-exit-code 7 --meta-override-reason exit_nonzero < "$T/ok.jsonl" > "$T/a.yaml" 2> "$T/a.err"
assert_eq "$(meta_val "$T/a.yaml" exit_code)" "7" "공유 추출기: 0 아닌 종료면 meta 에 codex 종료 코드"
assert_eq "$(meta_val "$T/a.yaml" stderr_kind)" "overloaded" "공유 추출기: meta 에 stderr 사유 분류"
assert_file_absent "$T/a.yaml" 'model overloaded' "공유 추출기: meta 에 stderr 원문을 싣지 않는다"
assert_contains "$(cat "$T/a.err")" 'stderr 첫 줄(기록하지 않음): ERROR: model overloaded (retry later)' "공유 추출기: 원문 첫 줄은 화면에 보인다(양성 짝)"
assert_file_absent "$T/a.err" "$SECOND" "공유 추출기: 화면에도 둘째 줄은 보이지 않는다"
printf '%s\n' "$SECOND" > "$T/err-first.txt"
python3 "$X" --stderr-file "$T/err-first.txt" --meta-override-exit-code 7 < "$T/ok.jsonl" > /dev/null 2> "$T/a1.err"
assert_contains "$(cat "$T/a1.err")" "$SECOND" "공유 추출기: 둘째 줄 표지는 첫 줄이면 화면에 보인다(가림에 걸리지 않는 표지 — 양성 짝)"
python3 "$X" --stderr-file "$T/err-secret.txt" --meta-override-exit-code 7 --meta-override-reason exit_nonzero < "$T/ok.jsonl" > "$T/s.yaml" 2> "$T/s.err"
assert_eq "$(meta_val "$T/s.yaml" stderr_kind)" "auth" "공유 추출기: 401 은 auth 로 분류"
no_secret "$T/s.yaml" "공유 추출기 meta"
no_secret "$T/s.err" "공유 추출기 화면"
assert_contains "$(cat "$T/s.err")" 'Authorization: Bearer <가림>' "공유 추출기: 화면의 가린 줄에 나머지 글은 남는다(양성 짝)"
# 인증 실패 갈래(빈 stdout + stderr 의 인증 오류)도 원문 미리보기 대신 분류만 싣는다.
python3 "$X" --stderr-file "$T/err-secret.txt" < "$T/empty.jsonl" > "$T/s2.yaml" 2>/dev/null
assert_eq "$(meta_val "$T/s2.yaml" reason)" "auth_error_in_stderr" "공유 추출기: 인증 실패 갈래를 밟았다(양성 짝)"
assert_eq "$(meta_val "$T/s2.yaml" stderr_kind)" "auth" "공유 추출기: 인증 실패 갈래도 분류를 싣는다"
assert_file_absent "$T/s2.yaml" 'stderr_preview' "공유 추출기: 인증 실패 갈래에 stderr 원문 미리보기가 없다"
no_secret "$T/s2.yaml" "공유 추출기 인증 실패 갈래"
python3 "$X" --stderr-file "$T/err-secret.txt" < "$T/notjson.jsonl" > "$T/s3.yaml" 2>/dev/null
assert_eq "$(meta_val "$T/s3.yaml" reason)" "auth_error_in_stderr" "공유 추출기: 인증 실패 둘째 갈래(findings 아닌 메시지)를 밟았다(양성 짝)"
assert_eq "$(meta_val "$T/s3.yaml" stderr_kind)" "auth" "공유 추출기: 인증 실패 둘째 갈래도 분류를 싣는다"
assert_file_absent "$T/s3.yaml" 'stderr_preview' "공유 추출기: 인증 실패 둘째 갈래에 stderr 원문 미리보기가 없다"
no_secret "$T/s3.yaml" "공유 추출기 인증 실패 둘째 갈래"
# 실제 실패 꼴: 사유가 stdout 의 실패 이벤트에만 있다 — 그 이벤트로 분류하고, 원문은 화면에만.
python3 "$X" --stderr-file "$T/err-empty.txt" --meta-override-exit-code 1 --meta-override-reason exit_nonzero < "$T/limit.jsonl" > "$T/l.yaml" 2> "$T/l.err"
assert_eq "$(meta_val "$T/l.yaml" stderr_kind)" "quota" "공유 추출기: stderr 가 비어도 실패 이벤트(사용 한도)로 분류한다"
assert_file_absent "$T/l.yaml" 'usage limit' "공유 추출기: 실패 이벤트 원문은 meta 에 싣지 않는다"
assert_contains "$(cat "$T/l.err")" '실패 이벤트(기록하지 않음): You’ve hit your usage limit' "공유 추출기: 실패 이벤트 첫 줄은 화면에 보인다"
# 앞의 error 이벤트(재시도 알림)와 끝의 turn.failed 가 다르면 마지막 실패 — turn.failed — 로 분류한다.
printf '%s\n' '{"type":"error","message":"stream disconnected, retrying"}' '{"type":"turn.failed","error":{"message":"429 Too Many Requests"}}' > "$T/tf.jsonl"
python3 "$X" --stderr-file "$T/err-empty.txt" --meta-override-exit-code 1 < "$T/tf.jsonl" > "$T/tf.yaml" 2>/dev/null
assert_eq "$(meta_val "$T/tf.yaml" stderr_kind)" "rate-limited" "공유 추출기: 마지막 실패 이벤트(turn.failed)로 분류한다"
# turn.failed 가 뒤의 error 이벤트보다 먼저다 — error 는 재시도 알림일 수 있다.
printf '%s\n' '{"type":"turn.failed","error":{"message":"429 Too Many Requests"}}' '{"type":"error","message":"stream disconnected, retrying"}' > "$T/tf2.jsonl"
python3 "$X" --stderr-file "$T/err-empty.txt" --meta-override-exit-code 1 < "$T/tf2.jsonl" > "$T/tf2.yaml" 2>/dev/null
assert_eq "$(meta_val "$T/tf2.yaml" stderr_kind)" "rate-limited" "공유 추출기: turn.failed 가 뒤의 error 이벤트보다 먼저다"
# turn.failed 없이 재시도 알림만 남기고 죽었으면 — 진짜 원인(stderr 첫 줄)도 화면에 보인다.
printf '%s\n' '{"type":"error","message":"stream error: connection reset; retrying 1/5"}' > "$T/retry-only.jsonl"
printf 'thread main panicked at src/x.rs: index out of bounds\n' > "$T/err-panic.txt"
python3 "$X" --stderr-file "$T/err-panic.txt" --meta-override-exit-code 101 < "$T/retry-only.jsonl" > "$T/p.yaml" 2> "$T/p.err"
assert_contains "$(cat "$T/p.err")" 'stderr 첫 줄(기록하지 않음): thread main panicked at src/x.rs: index out of bounds' "공유 추출기: 실패 이벤트가 있어도 stderr 첫 줄을 화면에 보인다"
assert_contains "$(cat "$T/p.err")" '실패 이벤트(기록하지 않음): stream error: connection reset' "공유 추출기: 그 실패 이벤트도 화면에 보인다(양성 짝)"
python3 "$XA_EARLY" --stderr-file "$T/err-panic.txt" --meta-override-exit-code 101 < "$T/retry-only.jsonl" > /dev/null 2> "$T/pa.err"
assert_eq "$(cat "$T/pa.err")" "$(cat "$T/p.err")" "두 추출기의 화면 줄(이벤트 + stderr)이 같다"
python3 "$X" --stderr-file "$T/err.txt" --meta-override-exit-code 1 < "$T/limit.jsonl" > "$T/l2.yaml" 2>/dev/null
assert_eq "$(meta_val "$T/l2.yaml" stderr_kind)" "quota" "공유 추출기: 실패 이벤트가 stderr 보다 먼저다"
python3 "$X" --stderr-file "$T/err.txt" --meta-override-exit-code 0 --meta-override-reason "" < "$T/retried.jsonl" > "$T/l3.yaml" 2> "$T/l3.err"
assert_file_absent "$T/l3.yaml" 'stderr_kind' "공유 추출기: 재시도로 0 종료면 error 이벤트가 있어도 분류하지 않는다"
assert_eq "$(cat "$T/l3.err")" "" "공유 추출기: 재시도로 0 종료면 화면도 조용하다"
# stderr 를 읽지 못하면 「비었다(none)」 가 아니라 「읽지 못함(unreadable)」.
python3 "$X" --stderr-file "$T/nope/missing.txt" --meta-override-exit-code 7 < "$T/ok.jsonl" > "$T/u.yaml" 2>/dev/null
assert_eq "$(meta_val "$T/u.yaml" stderr_kind)" "unreadable" "공유 추출기: stderr 를 읽지 못하면 unreadable"
assert_file_grep "$T/u.yaml" '^  stderr_read_error: ' "공유 추출기: 읽기 오류도 남긴다"
python3 "$X" --stderr-file "$T/err.txt" < "$T/ok.jsonl" > "$T/c.yaml" 2> "$T/c.err"
assert_file_absent "$T/c.yaml" 'stderr_kind' "공유 추출기: codex 가 0 으로 끝나면 분류를 싣지 않는다"
assert_eq "$(cat "$T/c.err")" "" "공유 추출기: 0 종료면 화면에도 stderr 를 보이지 않는다"
assert_file_grep "$T/c.yaml" '^  codex_failed: false$' "공유 추출기: 0 종료는 성공 표식(양성 짝)"
KINDS="$(cd "$QG/scripts" && python3 -c 'from codex_findings_to_yaml import stderr_kind as k
for t in ("429 Too Many Requests", "request timed out", "could not resolve host x", "quota exceeded", "weird", ""):
    print(k(t))')"
assert_eq "$KINDS" "$(printf '%s\n' rate-limited timeout network quota other none)" "분류: 한도 · 시간 초과 · 네트워크 · 할당량 · 그 밖 · 없음"

# ── 평면 YAML 추출기(artifact 러너) ───────────────────────────────────────────
XA="$QG/scripts/extract_codex_artifact_yaml.py"
python3 "$XA" --stderr-file "$T/err.txt" --meta-override-exit-code 7 --meta-override-reason exit_nonzero < "$T/ok.jsonl" > "$T/d.yaml" 2> "$T/d.err"
assert_file_grep "$T/d.yaml" '^codex_failed: true$' "artifact 추출기: 0 아닌 종료는 실패 표식"
assert_eq "$(sed -n 's/^exit_code: //p' "$T/d.yaml")" "7" "artifact 추출기: codex 종료 코드를 남긴다"
assert_eq "$(sed -n 's/^stderr_kind: //p' "$T/d.yaml")" "overloaded" "artifact 추출기: 사유 분류를 남긴다"
assert_file_absent "$T/d.yaml" 'model overloaded' "artifact 추출기: 산출물에 stderr 원문을 싣지 않는다"
assert_contains "$(cat "$T/d.err")" 'stderr 첫 줄(기록하지 않음): ERROR: model overloaded (retry later)' "artifact 추출기: 원문 첫 줄은 화면에 보인다(양성 짝)"
assert_file_absent "$T/d.err" "$SECOND" "artifact 추출기: 화면에도 둘째 줄은 보이지 않는다"
python3 "$XA" --stderr-file "$T/err-empty.txt" --meta-override-exit-code 1 --meta-override-reason exit_nonzero < "$T/limit.jsonl" > "$T/la.yaml" 2> "$T/la.err"
assert_eq "$(sed -n 's/^stderr_kind: //p' "$T/la.yaml")" "quota" "artifact 추출기: stderr 가 비어도 실패 이벤트(사용 한도)로 분류한다"
assert_file_absent "$T/la.yaml" 'usage limit' "artifact 추출기: 실패 이벤트 원문은 산출물에 싣지 않는다"
assert_eq "$(cat "$T/la.err")" "$(cat "$T/l.err")" "두 추출기의 실패 이벤트 화면 줄이 같다"
python3 "$XA" --stderr-file "$T/err-secret.txt" --meta-override-exit-code 7 --meta-override-reason exit_nonzero < "$T/ok.jsonl" > "$T/f.yaml" 2> "$T/f.err"
no_secret "$T/f.yaml" "artifact 추출기 산출물"
no_secret "$T/f.err" "artifact 추출기 화면"
assert_eq "$(cat "$T/f.err")" "$(cat "$T/s.err")" "두 추출기의 화면 줄이 같다(규칙 한 곳)"
python3 "$XA" --stderr-file "$T/nope/missing.txt" --meta-override-exit-code 7 --meta-override-reason exit_nonzero < "$T/ok.jsonl" > "$T/g.yaml" 2>/dev/null
assert_file_grep "$T/g.yaml" '^stderr_read_error: [0-9A-Za-z]' "artifact 추출기: stderr 를 읽지 못하면 그 사실을 남긴다(공유 추출기와 같은 꼴 — 따옴표 없음)"
assert_eq "$(sed -n 's/^stderr_kind: //p' "$T/g.yaml")" "unreadable" "artifact 추출기: stderr 를 읽지 못하면 unreadable"

# ── 러너 끝에서 끝: codex 스텁이 stderr 를 쓰고 7 로 끝난다 ─────────────────────
mkdir -p "$T/bin" "$T/proot"
printf '#!/bin/sh\ncat >/dev/null\necho "  ERROR: model overloaded (retry later)" >&2\necho "%s" >&2\nexit 7\n' "$SECOND" > "$T/bin/codex"
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
assert_eq "$(meta_val "$T/r1.yaml" stderr_kind)" "overloaded" "run_codex_reviewer.sh: meta 에 사유 분류"
assert_file_absent "$T/r1.yaml" "$SECOND" "run_codex_reviewer.sh: meta 에 stderr 원문이 없다"
printf '아티팩트 fixture\n' > "$T/artifact.md"
PATH="$T/bin:$PATH" CLAUDE_PLUGIN_ROOT="$T/proot" \
  bash "$T/proot/scripts/run_artifact_codex_reviewer.sh" "$T/artifact.md" "$ROOT" "$T/r2.yaml" >/dev/null 2>"$T/r2.err"
assert_eq "$(sed -n 's/^reason: //p' "$T/r2.yaml")" "exit_nonzero" "run_artifact_codex_reviewer.sh: reason exit_nonzero(양성 짝)"
assert_eq "$(sed -n 's/^exit_code: //p' "$T/r2.yaml")" "7" "run_artifact_codex_reviewer.sh: 산출물에 codex 종료 코드"
assert_eq "$(sed -n 's/^stderr_kind: //p' "$T/r2.yaml")" "overloaded" "run_artifact_codex_reviewer.sh: 산출물에 사유 분류"
# docreview 러너는 공유 추출기에 --stderr-file 과 종료 코드를 넘긴다 — 위 공유 추출기 단언이 그 meta 를 잰다.
DR="$ROOT/shared/docreview/scripts/run_docreview_codex_reviewer.sh"
assert_file_grep "$DR" '^ +--stderr-file "\$STDERR_FILE" \\$' "run_docreview_codex_reviewer.sh: 공유 추출기에 codex stderr 를 넘긴다"
assert_file_grep "$DR" '^ +--meta-override-exit-code "\$EXIT_CODE" \\$' "run_docreview_codex_reviewer.sh: 공유 추출기에 codex 종료 코드를 넘긴다"

finish
