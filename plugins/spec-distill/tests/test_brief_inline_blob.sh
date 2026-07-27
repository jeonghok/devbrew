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

# 파일 부재는 usage 오류
python3 "$SCRIPT" "$FX/nonexistent.md" >/dev/null 2>&1 \
  && note FAIL "부재 파일이 exit 0" || note PASS "부재 파일 거부"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ "$fail" -eq 0 ]]
