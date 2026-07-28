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

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ "$fail" -eq 0 ]]
