#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/conducting-interview/references/seed-input.md plugins/spec-distill/skills/conducting-interview/SKILL.md plugins/spec-distill/commands/interview.md plugins/spec-distill/scripts/seed_provenance.py plugins/spec-distill/scripts/seed_review_log.py
#
# Phase 1 의 seed 출처 규약 — 출처와 확인을 두 축으로 가르고(설계 2026-09-16-framing-intent-drift
# §5.6 · AC7), 그 가름을 audit 원문 대조로 한다. audit 경로는 seed frontmatter 의 포인터(파일
# 이름뿐)를 따라가지 않고 `/interview` 가 seed 의 경로에서 도출해 넘긴다. `S1` 은 바뀌지 않는다.
# 끝에 규약이 가리키는 분류기를 픽스처로 돌려 두 경우(사용자 원문 · 저자 문장)를 실제로 가르는지 본다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SI="$ROOT/plugins/spec-distill/skills/conducting-interview/references/seed-input.md"
CI="$ROOT/plugins/spec-distill/skills/conducting-interview/SKILL.md"
IV="$ROOT/plugins/spec-distill/commands/interview.md"
P="$ROOT/plugins/spec-distill/scripts/seed_provenance.py"
if [ "${1:-}" = "--emit-scanned" ]; then
  for f in plugins/spec-distill/skills/conducting-interview/references/seed-input.md plugins/spec-distill/skills/conducting-interview/SKILL.md \
           plugins/spec-distill/commands/interview.md plugins/spec-distill/scripts/seed_provenance.py plugins/spec-distill/scripts/seed_review_log.py; do
    echo "$f"
  done
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
bash_lines() { printf '%s\n' "$1" | awk '/^```bash[[:space:]]*$/ {b=1; next} b && /^```/ {b=0; next} b && !/^[[:space:]]*#/ {print}'; }

SIB="$(awk '/^## seed 를 입력으로 받았을 때/{f=1; next} /^## /{f=0} f' "$SI")"
[ -n "$SIB" ] && ok "절 추출: seed 입력 규약 (vacuous 아님)" || no "절 추출: seed 입력 규약이 비었다 — 아래 판정은 무의미하다"
assert_contains "$SIB" "| 사용자 발화를 그대로 옮긴 것 | 사용자 | 표시가 있으면 확인, 없으면 미확인 |" "AC7: 사용자 원문은 확인 표시 없이도 사용자 출처"
assert_contains "$SIB" "| 저자가 풀어 쓴 것에 «(사용자 확인)» 이 붙은 것 | 사용자(확인으로 획득) | 확인 |" "AC7: 확인된 풀이는 사용자 출처 · 확인"
assert_contains "$SIB" "| 그 밖의 저자 문장(«다시 검증할 것 —» 문단 포함) | Phase 0 저자 | 미확인 |" "AC7: 저자 문장은 저자 출처"
assert_not_contains "$SIB" "전부 사용자" "옛 규약(seed 전문이 전부 사용자 출처)이 없다"
assert_contains "$SIB" '§6 `S1` 은 `$ARGUMENTS` 원문 그대로다' "S1 규약은 그대로다(AC7)"
assert_contains "$(bash_lines "$SIB")" 'seed_provenance.py" classify' "가름은 기계가 한다(실행 줄)"
assert_contains "$SIB" '`audit_file:` 은 따라가지 않는다' "seed frontmatter 포인터를 따라가지 않는다"
assert_contains "$SIB" "audit: unavailable" "audit 이 없으면 보수적으로 떨어지고 그 사실을 밝힌다"
assert_contains "$SIB" '`--audit` 을 넘겼어도' "T11-a: --audit 을 넘겼어도 unavailable 이면 전부 저자 · 미확인"
IVT="$(cat "$IV")"
assert_contains "$IVT" "[spec-distill] seed 원문 대조: seed=" "/interview 가 seed · audit 경로를 한 줄로 낸다"
assert_contains "$IVT" '`.audit.md`' "audit 경로는 seed 경로에서 도출한다"
assert_contains "$IVT" "「풀린 입력」에 넣지 않는다" "그 줄은 풀린 입력 밖 — S1 이 바뀌지 않는다"
assert_contains "$(cat "$CI")" 'Read ${CLAUDE_PLUGIN_ROOT}/skills/conducting-interview/references/seed-input.md' "seed-input 을 여는 줄이 절대 형태다(펜스가 루트를 쓰므로)"

# ── 실행 — 규약이 가리키는 분류기가 두 경우를 가른다 ─────────────────────────
T="$(mktemp -d -t sd-seed-input-XXXXXX)" || exit 1
trap 'rm -rf "$T"' EXIT
printf -- '---\ntype: interview-seed-audit\n---\n\n## 1. 원문\n\n나는 경합을 의심하는데 확신은 없다.\n\n## 2. 질문 전체\n\n없음\n' > "$T/s.audit.md"
printf -- '---\ntype: interview-seed\n---\n\n나는 경합을 의심하는데 확신은 없다. 로그인 화면으로 되돌아간다.\n' > "$T/s.md"
python3 "$P" classify "$T/s.md" --audit "$T/s.audit.md" > "$T/c.json"
pv() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); print([(s["provenance"], s["confirmed"]) for s in d["sentences"] if s["text"].startswith(sys.argv[2])][0])' "$T/c.json" "$1"; }
assert_eq "$(pv '나는 경합')" "('user', False)" "§10-4: 확인 표시 없는 사용자 원문 → 사용자 출처(들어가야 통과)"
assert_eq "$(pv '로그인 화면')" "('author', False)" "§10-4: 확인 표시 없는 저자 문장 → 저자 출처(들어가면 실패)"
python3 "$P" classify "$T/s.md" > "$T/c2.json"
assert_contains "$(cat "$T/c2.json")" '"audit": "unavailable' "§10-4: audit 을 못 받으면 그 사실을 낸다"
finish
