#!/usr/bin/env bash
# V4/AC6 — steelman-builder is read-only (Law 2 frontmatter scoping) + web-capable.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/steelman-builder.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

test -f "$AGENT" && note PASS "agent file exists" || { note FAIL "agent file missing"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }

# Frontmatter 창 = 첫 두 '---' 사이. (구버전 awk 'c==1' 은 '---' 줄 자체를 포함했다.)
fm="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$AGENT")"

# 모델 티어 양방향 락 — 하니스가 세션 모델을 덮어쓰지 않는다(리터럴 핀 = 조용한 하향).
grep -qE '^model: inherit$' <<<"$fm" \
  && note PASS "model: inherit (세션 티어 상속)" || note FAIL "model이 inherit이 아님"
grep -qE '^model: (opus|sonnet|haiku)$' <<<"$fm" \
  && note FAIL "고정 티어 핀 잔존" || note PASS "고정 티어 핀 없음"

# v0.21.0: allowedTools(죽은 필드) + disallowedTools → tools: allowlist.
# census 가 가설을 확증했다: 업무에 WebSearch×2 · WebFetch×2 실사용.
grep -qE '^tools: Read, Grep, Glob, WebSearch, WebFetch$' <<<"$fm" \
  && note PASS "tools: 가 census 도출 목록과 일치" \
  || note FAIL "tools: 가 census 도출 목록과 다름"

grep -qE '^(allowedTools|disallowedTools):' <<<"$fm" \
  && note FAIL "죽은 allowedTools / denylist 잔존" \
  || note PASS "allowedTools · disallowedTools 없음"

# AC6(구): 쓰기 도구가 물리적으로 부재 — 이제 denylist 열거가 아니라 allowlist 부재로.
for tool in Write Edit MultiEdit NotebookEdit Bash Agent Monitor; do
  grep -qE "^tools:.*(^|,)[[:space:]]*${tool}[[:space:]]*(,|$)" <<<"$fm" \
    && note FAIL "AC6: tools: 에 $tool 이 있다" \
    || note PASS "AC6: tools: 에 $tool 없음"
done

# web 연구 표면은 census 근거로 유지 — 조용한 열화 방지.
for tool in WebSearch WebFetch; do
  grep -qE "^tools:.*${tool}" <<<"$fm" \
    && note PASS "tools: 에 $tool 유지" \
    || note FAIL "tools: 에서 $tool 이 사라졌다 — steelman 근거 수집 불가"
done

# name + verbatim-output contract present
grep -q '^name: steelman-builder$' <<<"$fm" \
  && note PASS "name: steelman-builder" || note FAIL "name field broken"
grep -qiE 'verbatim|약화.*금지|편집.*금지' "$AGENT" \
  && note PASS "AC5: verbatim/no-weakening output contract present" \
  || note FAIL "AC5: verbatim output contract missing"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
