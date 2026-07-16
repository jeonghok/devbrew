#!/usr/bin/env bash
# T1/AC15/AC22 — E1 code/non-code/ambiguous classifier. 3분기 계약 + 정규화 + fail-safe.
set -u
SCRIPT="plugins/quality-gates/scripts/classify_artifact_target.py"
PASS=0; FAIL=0
check() { # <label> <path> <expected-classification>
  local label="$1" path="$2" want="$3"
  local got; got="$(python3 "$SCRIPT" "$path" | sed -n 's/^classification: //p')"
  if [ "$got" = "$want" ]; then PASS=$((PASS+1)); echo "  PASS: $label ($path -> $got)"
  else FAIL=$((FAIL+1)); echo "  ✗ FAIL: $label ($path -> got '$got', want '$want')"; fi
}
# 코드 확장자 -> code (종료)
check "py is code" "src/app.py" code
check "ts is code" "a/b/main.ts" code
check "sh is code" "scripts/run.sh" code
# 비-코드 고정 목록 -> non_code (진행)
check "md is non_code" "docs/design.md" non_code
check "rst is non_code" "README.rst" non_code
check "txt is non_code" "notes.txt" non_code
# 정규화: 대소문자 무시
check "MD case-insensitive" "DOCS/DESIGN.MD" non_code
# 복합 확장자: 마지막 세그먼트 기준 (.tar.gz -> gz -> 목록에 없음 -> ambiguous)
check "compound tar.gz ambiguous" "dist/bundle.tar.gz" ambiguous
# 확장자 없음 -> ambiguous
check "no extension ambiguous" "LICENSE" ambiguous
# fail-safe: 두 목록 어디에도 없는 확장자 -> ambiguous (config 등)
check "yaml unlisted -> ambiguous" "config.yaml" ambiguous
check "json unlisted -> ambiguous" "package.json" ambiguous
# 디렉터리 -> ambiguous (실제 디렉터리 fixture)
tmp="$(mktemp -d)"; check "directory ambiguous" "$tmp" ambiguous; rmdir "$tmp"
echo ""; echo "Total: $((PASS+FAIL)), PASS=$PASS, FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
