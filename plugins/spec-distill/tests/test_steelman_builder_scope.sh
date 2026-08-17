#!/usr/bin/env bash
# V4/AC6 — steelman-builder is read-only (Law 2 frontmatter scoping) + web-capable.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/steelman-builder.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

test -f "$AGENT" && ok "agent file exists" || { no "agent file missing"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }

# Frontmatter 창 = 첫 두 '---' 사이. (구버전 awk 'c==1' 은 '---' 줄 자체를 포함했다.)
fm="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$AGENT")"

# 모델 티어 양방향 락 — 하니스가 세션 모델을 덮어쓰지 않는다(리터럴 핀 = 조용한 하향).
grep -qE '^model: inherit$' <<<"$fm" \
  && ok "model: inherit (세션 티어 상속)" || no "model이 inherit이 아님"
grep -qE '^model: (opus|sonnet|haiku)$' <<<"$fm" \
  && no "고정 티어 핀 잔존" || ok "고정 티어 핀 없음"

# v0.21.0: allowedTools(죽은 필드) + disallowedTools → tools: allowlist.
# census 가 가설을 확증했다: 업무에 WebSearch×2 · WebFetch×2 실사용.
grep -qE '^tools: Read, Grep, Glob, WebSearch, WebFetch$' <<<"$fm" \
  && ok "tools: 가 census 도출 목록과 일치" \
  || no "tools: 가 census 도출 목록과 다름"

grep -qE '^(allowedTools|disallowedTools):' <<<"$fm" \
  && no "죽은 allowedTools / denylist 잔존" \
  || ok "allowedTools · disallowedTools 없음"

# AC6(구): 쓰기 도구가 물리적으로 부재 — 이제 denylist 열거가 아니라 allowlist 부재로.
for tool in Write Edit MultiEdit NotebookEdit Bash Agent Monitor; do
  grep -qE "^tools:.*(^|,)[[:space:]]*${tool}[[:space:]]*(,|$)" <<<"$fm" \
    && no "AC6: tools: 에 $tool 이 있다" \
    || ok "AC6: tools: 에 $tool 없음"
done

# web 연구 표면은 census 근거로 유지 — 조용한 열화 방지.
for tool in WebSearch WebFetch; do
  grep -qE "^tools:.*${tool}" <<<"$fm" \
    && ok "tools: 에 $tool 유지" \
    || no "tools: 에서 $tool 이 사라졌다 — steelman 근거 수집 불가"
done

# name + verbatim-output contract present
grep -q '^name: steelman-builder$' <<<"$fm" \
  && ok "name: steelman-builder" || no "name field broken"
grep -qiE 'verbatim|약화.*금지|편집.*금지' "$AGENT" \
  && ok "AC5: verbatim/no-weakening output contract present" \
  || no "AC5: verbatim output contract missing"

# E10 — 단일 호출 상한 표현 + 탐색 폭 좁힘 문구 부재.
# 하니스가 프롬프트로 검색 횟수를 묶으면 조사가 본질인 역할의 능력을 직접 깎는다.
# 패턴은 test_brief_agents.sh:194의 E10 락을 확장한 것이다(숫자 범위·병렬 금지 추가).
if grep -qE '최대 [0-9]+회|[0-9]+회까지|[0-9]–[0-9]회|[0-9]-[0-9]회|max_[a-z_]+ *= *[0-9]' "$AGENT"; then
  no "E10: 단일 호출 상한 표현 잔존"
else
  ok "E10: 상한 표현 없음"
fi
if grep -qE '병렬.{0,8}금지|투기적.{0,8}금지' "$AGENT"; then
  no "E10: 병렬·투기적 호출 금지 문구 잔존 (탐색 폭 좁힘)"
else
  ok "E10: 병렬 금지 문구 없음"
fi
finish
