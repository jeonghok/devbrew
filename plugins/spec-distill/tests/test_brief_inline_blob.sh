#!/usr/bin/env bash
# Spec B T24 — inline blob redaction (AC2 · AC3).
# critic·readback 프롬프트에 실리는 blob에서 audit_file·name·created_at 값이 redact되고
# `.audit.md` 문자열이 사라진다. 격리는 도구 표면으로 성립하고 이것은 **위생 조치**다.
# Run: bash plugins/spec-distill/tests/test_brief_inline_blob.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/build_brief_inline_blob.py"
FX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"
PAYLOAD="$FX/brief-verbatim-ok.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

test -f "$SCRIPT" || { note FAIL "스크립트 부재: $SCRIPT"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }

BLOB="$(python3 "$SCRIPT" "$PAYLOAD")"; rc=$?
[[ "$rc" == "0" ]] && note PASS "정상 payload → exit 0" || note FAIL "정상 payload가 exit $rc"

grep -qF '.audit.md' <<<"$BLOB" \
  && note FAIL "T24: blob에 '.audit.md' 잔존 (격리 위생 실패)" || note PASS "T24: blob에 '.audit.md' 부재"
grep -qE '^audit_file: <redacted>$' <<<"$BLOB" \
  && note PASS "T24: audit_file: <redacted>" || note FAIL "T24: audit_file redact 형태가 아님"
grep -qE '^name: <redacted>$' <<<"$BLOB" \
  && note PASS "T24: name: <redacted>" || note FAIL "T24: name redact 안 됨 (재구성 경로)"
grep -qE '^created_at: <redacted>$' <<<"$BLOB" \
  && note PASS "T24: created_at: <redacted>" || note FAIL "T24: created_at redact 안 됨"

# 본문은 온전해야 한다 — redaction이 §6 원문을 건드리면 충실도 판정 자체가 무의미해진다
grep -qF "브리프에 리뷰를 붙이고 싶다" <<<"$BLOB" \
  && note PASS "T24: §6 원문 보존" || note FAIL "T24: §6 원문이 손상됐다"
grep -qF "## 6. 사용자 원문" <<<"$BLOB" \
  && note PASS "T24: §6 헤딩 보존" || note FAIL "T24: §6 헤딩 손실"
grep -qF "Verbatim OK — Interview Brief" <<<"$BLOB" \
  && note PASS "T24: H1 제목 보존 (주제는 남는다 — readback 냉독 지장 없음)" || note FAIL "T24: H1 손실"

# session_id는 redact 대상이 아니다 (세 값만 — 과잉 redaction도 결함)
grep -qE '^session_id: 11111111' <<<"$BLOB" \
  && note PASS "T24: session_id는 그대로 (redact 대상 3값만)" || note FAIL "T24: 과잉 redaction"

# 본문이 audit 파일명을 언급하는 경우: 원문 보존이 이기고 exit 3으로 알린다
tmp="$(mktemp)" || exit 1
python3 - "$PAYLOAD" "$tmp" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
t = open(src, encoding="utf-8").read()
t = t.replace('  > "브리프에 리뷰를 붙이고 싶다"',
              '  > "브리프에 리뷰를 붙이고 싶다 (2026-07-27-x-interview.audit.md 참고)"')
open(dst, "w", encoding="utf-8").write(t)
PY
BLOB2="$(python3 "$SCRIPT" "$tmp")"; rc2=$?
[[ "$rc2" == "3" ]] && note PASS "T24: 본문 잔존 시 exit 3 (호출자가 degrade 기록)" \
                    || note FAIL "T24: 본문 잔존이 exit $rc2 — 조용히 통과했다"
grep -qF "2026-07-27-x-interview.audit.md" <<<"$BLOB2" \
  && note PASS "T24: 본문 원문은 보존된다 (§6 verbatim > 위생)" || note FAIL "T24: 본문 원문을 지웠다"
rm -f "$tmp"

# C1: 값이 빈 redact 키가 **다음 줄을 삼키지 않는다**. `\s*`는 개행을 넘으므로
# `(.*)$`가 다음 줄을 이 줄의 값으로 잡아 그 줄 전체를 <redacted>로 갈아치웠다
# (실측: 빈 `audit_file:` 다음의 `created_at:` 줄이 사라졌다). `name`·`created_at`은
# check_brief.py의 frontmatter 검증 대상이 아니라 빈 값이 구조 게이트를 통과한다 —
# 도달 가능한 경로다. 인접 키가 살아남는지를 **키 이름으로** 확인한다.
tmp_empty="$(mktemp)" || exit 1
printf -- '---\ntype: interview-brief\nname:\naudit_file:\ncreated_at: 2026-07-27\nsession_id: 42\n---\n\n# H1\n' > "$tmp_empty"
BLOB3="$(python3 "$SCRIPT" "$tmp_empty" 2>/dev/null)"
for k in created_at session_id; do
  grep -qE "^${k}:" <<<"$BLOB3" \
    && note PASS "C1: 빈 redact 키 뒤의 '${k}:' 라인이 살아남는다" \
    || note FAIL "C1: '${k}:' 라인이 삭제됐다 — 빈 값 뒤 개행을 넘어 다음 줄을 먹었다"
done
# 원래 하려던 일은 그대로 해야 한다 — "아무것도 안 한다"로는 위 assert가 통과하므로
# redaction 자체가 살아 있는지 같은 입력에서 함께 확인한다.
grep -qE '^created_at: <redacted>$' <<<"$BLOB3" \
  && note PASS "C1: 값이 있는 created_at은 여전히 redact된다" \
  || note FAIL "C1: redaction이 죽었다 (no-op으로 위 assert를 만족시키는 퇴행)"
# frontmatter 키 5개(type·name·audit_file·created_at·session_id). 본문 `# H1`엔 콜론이 없다.
n_lines_in=5; n_lines_out="$(grep -c ':' <<<"$BLOB3")"
[[ "$n_lines_out" == "$n_lines_in" ]] \
  && note PASS "C1: frontmatter 키 ${n_lines_in}개가 전부 보존 (누락 0)" \
  || note FAIL "C1: frontmatter 키가 ${n_lines_in} → ${n_lines_out} 개로 줄었다"
rm -f "$tmp_empty"

# 파일 부재는 usage 오류 — exit 2를 구체적으로 요구한다(review round 1: "0이 아니면 OK"는
# 느슨해서 실수로 3이나 1을 반환해도 통과시킨다 — 실제로는 항상 2를 내므로 강화해도 무해하다)
python3 "$SCRIPT" "$FX/nonexistent.md" >/dev/null 2>&1
rc3=$?
[[ "$rc3" == "2" ]] && note PASS "부재 파일 거부 (exit 2)" || note FAIL "부재 파일이 exit $rc3 (2가 아님)"

# === /qg iter-1 CRITICAL : 읽기 실패는 문서화된 exit 2 (1이 아니다) ==========
# 결함: `path.read_text(encoding="utf-8")`가 try 밖에 있어 비-UTF-8 payload가
# uncaught UnicodeDecodeError → Python 기본 **exit 1**을 냈다. 호출 SKILL의 표는
# 0/2/3만 라우팅하므로 1은 어느 분기에도 안 걸리고, `BLOB`이 빈 문자열인 채로
# `${BLOB}`이 그대로 Agent() 프롬프트에 보간된다 → critic이 **빈 `<brief>`** 를
# 리뷰하고 "왜곡 없음"을 보고한다(SKILL이 프로즈로 금지한 바로 그 fail-open).
tmpbin="$(mktemp)" || exit 1
# `printf '---…'`는 bash가 `--`를 옵션 종결자로 파싱해 실패한다 — 포맷을 `%s`로 분리한다.
{ printf '%s\n' '---' 'name: x' '---'; printf '\xff\xfe invalid utf-8 \xff\n'; } > "$tmpbin"
out="$(python3 "$SCRIPT" "$tmpbin" 2>/dev/null)"; rc=$?
[[ "$rc" == "2" ]] \
  && note PASS "비-UTF-8 payload → exit 2 (문서화된 '디스패치 금지' 코드)" \
  || note FAIL "비-UTF-8 payload가 exit $rc — 표에 없는 코드는 빈 blob 디스패치로 샌다"
[[ -z "$out" ]] \
  && note PASS "비-UTF-8 payload → stdout 비어 있음 (부분 blob 아님)" \
  || note FAIL "비-UTF-8 payload가 stdout에 무언가를 냈다 — 잘린 blob이 디스패치될 수 있다"
# `set -o pipefail` 하에서 `cmd | grep`으로 바로 연결하면 파이프 상태가 grep(성공)이 아니라
# cmd(exit 2)로 오염돼 항상 FAIL로 오분류된다 — test_check_verbatim_coverage.sh가 같은 함정을
# 이미 주석으로 남겼다. 변수에 캡처한 뒤 grep해 파이프를 피한다.
err="$(python3 "$SCRIPT" "$tmpbin" 2>&1 >/dev/null)"
grep -q 'payload' <<<"$err" \
  && note PASS "비-UTF-8 payload → stderr에 원인 명시 (조용한 실패 아님)" \
  || note FAIL "비-UTF-8 payload 실패가 stderr에 설명되지 않는다"
rm -f "$tmpbin"

# 읽기 권한 없음도 같은 계약(1로 새지 않는다).
tmpperm="$(mktemp)" || exit 1
cp "$PAYLOAD" "$tmpperm"; chmod 000 "$tmpperm"
if [[ ! -r "$tmpperm" ]]; then   # root로 돌리면 항상 읽히므로 그때는 건너뛴다
  python3 "$SCRIPT" "$tmpperm" >/dev/null 2>&1; rc=$?
  [[ "$rc" == "2" ]] \
    && note PASS "읽기 불가 payload → exit 2 (1이 아님)" \
    || note FAIL "읽기 불가 payload가 exit $rc"
else
  note PASS "읽기 불가 케이스 건너뜀 (root 실행 — 권한이 적용되지 않음)"
fi
chmod 644 "$tmpperm"; rm -f "$tmpperm"

# mutation: 읽기 가드를 제거하면 비-UTF-8이 다시 표 밖 코드로 새야 한다(락에 이빨).
# 치환이 실제로 일어났는지 먼저 확인한다 — UNCHANGED인 채로 "2가 아니다"를 통과시키면
# 이 mutation은 아무것도 증명하지 않는다(vacuous pass).
tmpmut="$(mktemp)" || exit 1
mutres="$(python3 - "$SCRIPT" "$tmpmut" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
t = open(src, encoding="utf-8").read()
GUARDED = '''    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:'''
BARE = '    text = path.read_text(encoding="utf-8")\n    if False:  # noqa\n        exc = None'
t2 = t.replace(GUARDED, BARE, 1)
open(dst, "w", encoding="utf-8").write(t2)
print("MUTATED" if t2 != t else "UNCHANGED")
PY
)"
tmpbin2="$(mktemp)" || exit 1
{ printf '%s\n' '---' 'name: x' '---'; printf '\xff\xfe bad \xff\n'; } > "$tmpbin2"
if [[ "$mutres" == "MUTATED" ]]; then
  python3 "$tmpmut" "$tmpbin2" >/dev/null 2>&1; rcm=$?
  [[ "$rcm" != "2" ]] \
    && note PASS "mutation: 읽기 가드 제거 → exit $rcm (2가 아님, 락에 이빨 있음)" \
    || note FAIL "mutation: 가드를 제거해도 exit 2 — 이 락은 다른 이유로 통과한다"
else
  note FAIL "mutation: 가드 텍스트를 못 찾아 치환이 일어나지 않았다 ($mutres) — 이 락은 vacuous하다"
fi
rm -f "$tmpmut" "$tmpbin2"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ "$fail" -eq 0 ]]
