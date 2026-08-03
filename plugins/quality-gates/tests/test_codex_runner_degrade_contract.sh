#!/usr/bin/env bash
# codex 러너의 degrade 계약: 추출이 실패해도 **소비 가능한 산출물**을 남긴다.
#
# 왜 행동 테스트인가: grep으로 "가드 문자열이 있다"를 재면, 가드를 남겨둔 채
# 무력화하는 변형(조건 반전, 리다이렉트 순서 변경)에 GREEN이 난다. 여기서 재는
# 것은 문자열이 아니라 **파일이 0바이트가 아니고 실패가 표시돼 있는가**이다.
#
# 봉쇄하는 실패: `> "$OUTPUT_PATH"`는 python3가 crash하기 *전에* 이미 파일을 비운다.
# 가드가 없으면 0바이트 산출물이 남고, 소비자에게 그것은 "codex 성공, 발견 없음"
# 으로 읽힌다 — 리뷰어 하나가 조용히 사라진다(2026-08-04 /qg 라운드 1 적발).
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
QG="$ROOT/plugins/quality-gates"
pass=0; fail=0
ok() { pass=$((pass+1)); echo "  ✓ $1"; }
no() { fail=$((fail+1)); echo "  ✗ $1"; }

tmp="$(mktemp -d -t qg-degrade-XXXXXX)" || exit 1
trap 'rc=$?; rm -rf "$tmp"; exit $rc' EXIT
mkdir -p "$tmp/root/scripts" "$tmp/bin"

# 실제 러너가 필요로 하는 형제들은 진짜를 쓰고, 추출기만 실패하는 스텁으로 바꾼다.
for f in build_codex_prompt.py discover-spec.sh; do
  [ -f "$QG/scripts/$f" ] && cp "$QG/scripts/$f" "$tmp/root/scripts/"
done
printf '#!/usr/bin/env python3\nimport sys\nsys.exit(1)\n' > "$tmp/root/scripts/codex_findings_to_yaml.py"
chmod +x "$tmp/root/scripts/codex_findings_to_yaml.py"
# codex 자체는 스텁 — 이 테스트는 네트워크·모델을 쓰지 않는다.
printf '#!/bin/sh\nprintf "%%s\\n" "{\\"type\\":\\"agent_message\\",\\"text\\":\\"none\\"}"\nexit 0\n' > "$tmp/bin/codex"
chmod +x "$tmp/bin/codex"
printf 'diff --git a/x b/x\n' > "$tmp/tiny.diff"

out="$tmp/out.yaml"
PATH="$tmp/bin:$PATH" CLAUDE_PLUGIN_ROOT="$tmp/root" \
  bash "$QG/scripts/run_codex_reviewer.sh" "$tmp/tiny.diff" "$ROOT" "$out" >/dev/null 2>"$tmp/err.txt"

if [ -s "$out" ]; then
  ok "1 — 추출 실패 시 산출물이 0바이트가 아니다"
else
  no "1 — 추출 실패 시 산출물이 0바이트가 아니다 (size=$(wc -c < "$out" 2>/dev/null || echo MISSING))"
fi
if grep -q 'codex_failed: *true' "$out" 2>/dev/null; then
  ok "2 — 실패가 codex_failed로 표시된다 (성공+발견0으로 읽히지 않는다)"
else
  no "2 — 실패가 codex_failed로 표시된다"; sed 's/^/      /' "$out" 2>/dev/null
fi
if [ -s "$tmp/err.txt" ]; then
  ok "3 — degrade가 stderr에 loud하게 남는다"
else
  no "3 — degrade가 stderr에 loud하게 남는다"
fi

echo ""
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[ "$fail" -eq 0 ]
