#!/usr/bin/env bash
# V7 — stale-term 회귀 락. rename 완결을 **production artifacts**에서 확인한다.
# (a) breadth-keeper → coverage-mapper 재명명이 production에 완결(잔존 0).
# (b) interview_round는 활성 코드서 제거, SKILL은 migration 섹션에만.
# (c) v0.23.0 권위 문법 6개 리터럴이 production에서 제거됐다(AC13).
#     이 검사만 README.md를 **추가로 제외**한다 — README의 "Principles Instantiated"는
#     무엇이 왜 사라졌는지 설명하려면 옛 용어를 인용해야 하고(CHANGELOG를 뺀 것과 같은 이유),
#     우회해야 하는 락은 그 자체로 설계 결함이다. 그 대가로 README는 기계 커버리지가 0이며
#     V10 수동 검토가 그 갭을 맡는다 — 숨기지 않는다.
# 스코프: $SD 아래 전체 production 파일 — 확장자 whitelist 없이 sweep(SKILL.md/README.md/agents/
#         templates/scripts/plugin.json 뿐 아니라 scripts/ambiguity-blacklist.txt 같은 .txt/.yaml/
#         확장자없는 production 파일도 포함). 확장자 whitelist는 header 주장(scripts/ 커버)보다
#         좁아지는 grep-lock header-satisfiable 함정이라 폐기했다.
#         리포 루트의 docs/는 $SD 밖이라 자동으로 스코프 밖 — 중복 필터를 두지 않는다.
# 제외: (1) CHANGELOG.md(released 기록 + 이 rename을 서술하는 [0.22.0] 엔트리 — Keep-a-Changelog 불변),
#       (2) tests/(락·stage test가 토큰을 *집행/assert*하는 층 — stale ref면 그 테스트가 자체 fail),
#       (3) .pytest_cache/·__pycache__/·.git/(캐시·바이너리, production 아님),
#       (4) README.md — **(c)만** 추가 제외. (a)/(b)는 여전히 README를 검사한다(헤더 주장 = 본문 검사).
#       테스트의 토큰 참조는 제거를 강제하는 enforcement 층이지 stale 참조가 아니다.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
SKILL="$SD/skills/conducting-interview/SKILL.md"
pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# production artifact 파일 집합 — tests/·CHANGELOG.md·cache/binary 제외, **확장자 whitelist 없이 전체**.
# (whitelist는 scripts/ambiguity-blacklist.txt 같은 .txt production 파일을 놓쳐 lock이 자기 헤더 주장보다
#  좁아진다 — grep-lock header-satisfiable 함정. grep -I로 binary는 스킵.)
prod_files=()
while IFS= read -r f; do prod_files+=("$f"); done < <(
  find "$SD" -type f \
    -not -path '*/tests/*' -not -name 'CHANGELOG.md' \
    -not -path '*/.pytest_cache/*' -not -path '*/__pycache__/*' -not -path '*/.git/*'
)
# macOS bash 3.2: 빈 배열에 "${arr[@]}" 확장은 set -u 하에서 crash — 명시 guard(빈 집합=find 깨짐=FAIL).
if [[ ${#prod_files[@]} -eq 0 ]]; then
  note FAIL "V7: no production files found — find filter broken"
  echo; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1
fi

# V7a: breadth-keeper production 잔존 0
bk="$(grep -InE 'breadth-keeper|breadth_keeper|Breadth-Keeper' "${prod_files[@]}" 2>/dev/null || true)"
[[ -z "$bk" ]] && note PASS "V7a: no breadth-keeper in production artifacts" \
  || { note FAIL "V7a: stale breadth-keeper in production:"; printf '%s\n' "$bk"; }

# V7b-1: SKILL.md interview_round는 migration 섹션에만
mig="$(awk '/^## In-flight state migration/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
all_ir=$(grep -c interview_round "$SKILL" 2>/dev/null || true)
mig_ir=$(printf '%s\n' "$mig" | grep -c interview_round 2>/dev/null || true)
{ [[ "$all_ir" -ge 1 ]] && [[ "$all_ir" -eq "$mig_ir" ]]; } \
  && note PASS "V7b: interview_round in SKILL confined to migration ($all_ir)" \
  || note FAIL "V7b: interview_round leaks outside SKILL migration (total=$all_ir mig=$mig_ir)"

# V7b-2: interview_round production(SKILL 제외) 잔존 0
ir=""
for f in "${prod_files[@]}"; do
  [[ "$f" == "$SKILL" ]] && continue
  m="$(grep -InH interview_round "$f" 2>/dev/null || true)"
  [[ -n "$m" ]] && ir+="$m"$'\n'
done
[[ -z "$ir" ]] && note PASS "V7b: no interview_round in production outside SKILL migration" \
  || { note FAIL "V7b: interview_round in unexpected production files:"; printf '%s\n' "$ir"; }

# --- V8 (AC13): v0.23.0 권위 문법 6개 리터럴 회귀 락 ---
# 스코프 = prod_files − README.md. prod_files를 그대로 재사용하면 AC13의 명시 예외와
# 모순되므로 별도 배열을 만든다.
lock_files=()
for f in "${prod_files[@]}"; do
  [[ "$(basename "$f")" == "README.md" ]] && continue
  lock_files+=("$f")
done
if [[ ${#lock_files[@]} -eq 0 ]]; then
  note FAIL "V8: lock scope empty — filter broken"
else
  # 배열 리터럴 + "${arr[@]}" 확장으로만 다룬다 — 6개 중 3개가 공백을 품은 구(句)라
  # 단일 문자열 word-split은 그것들을 조용히 쪼갠다. 각 원소는 quote된 채 grep에 그대로 간다.
  # 매칭은 반드시 -F(고정 문자열): 한국어 조사·markdown 백틱이 regex 경계를 소리 없이
  # 깨뜨린 전례가 있다(Task 7). '·'는 metachar가 아니지만 -F면 그 판단 자체가 불필요해진다.
  authority_terms=(
    'locked_directions'
    'pending_locked_decisions'
    '재논쟁 금지'
    'Locked Directions'
    '다시 묻지 않는다'
    '확정·재논쟁'
  )
  for term in "${authority_terms[@]}"; do
    hit="$(grep -InIF -- "$term" "${lock_files[@]}" 2>/dev/null || true)"
    [[ -z "$hit" ]] \
      && note PASS "V8/AC13: '$term' 잔존 0건 (production, README 제외)" \
      || { note FAIL "V8/AC13: '$term' 가 production에 잔존:"; printf '%s\n' "$hit"; }
  done
fi

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
