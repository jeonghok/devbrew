#!/usr/bin/env bash
# test_discover_spec_keys.sh — ⑤ 뒤 discover-spec.sh 의 출력 키는 intent 셋뿐이다(K-5 ⑤ 줄 · AC27).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DS="$(cd -- "$SCRIPT_DIR/.." && pwd)/scripts/discover-spec.sh"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

R=$(mktemp -d) && [ -d "$R" ] || { echo "mktemp 실패" >&2; exit 1; }
trap 'cd / && rm -rf "$R"' EXIT
git init -q -b main "$R/repo" && git -C "$R/repo" config user.email t@t && git -C "$R/repo" config user.name t
mkdir -p "$R/repo/docs/superpowers/specs" "$R/bin"
# 트레일러 커밋은 기준선(main) 위 브랜치에 있어야 base..HEAD 범위에 든다.
( cd "$R/repo" && echo base > README && git add README && git -c commit.gpgsign=false commit -qm base \
    && git checkout -q -b feature ) || exit 1
printf '# s\n\n## Acceptance Criteria\n- AC1 x\n' > "$R/repo/docs/superpowers/specs/2026-01-01-x-design.md"
( cd "$R/repo" && git add -A && git -c commit.gpgsign=false commit -qm "feat: x" \
    -m "Spec: docs/superpowers/specs/2026-01-01-x-design.md" ) || exit 1
# gh 는 읽기 전용으로만 불린다 — 네트워크 없이 「gh 오류」 경로로 보낸다.
printf '#!/bin/sh\nexit 1\n' > "$R/bin/gh"; chmod +x "$R/bin/gh"

out=$(cd "$R/repo" && PATH="$R/bin:$PATH" bash "$DS" --intent-out "$R/intent.md" 2>/dev/null); rc=$?
assert_eq "$rc" "0" "discover-spec.sh exit 0"
keys=$(printf '%s' "$out" | python3 -c 'import json,sys; print(" ".join(sorted(json.loads(sys.stdin.read()))))' 2>/dev/null)
assert_eq "$keys" "intent_file intent_note intent_source" "K-5 ⑤: 키는 intent_source · intent_note · intent_file 셋"
assert_not_contains "$out" '"spec_path"' "K-5 ⑤: spec_path 키가 없다"
src=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["intent_source"])' 2>/dev/null)
assert_eq "$src" "spec-trailer" "양성 짝: Spec: 트레일러는 여전히 첫 의도 출처다"
finish
