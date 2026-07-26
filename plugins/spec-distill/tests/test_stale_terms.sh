#!/usr/bin/env bash
# V7 — stale-term 회귀 락. rename 완결을 **production artifacts**에서 확인한다.
# (a) breadth-keeper → coverage-mapper 재명명이 production에 완결(잔존 0).
# (b) interview_round는 활성 코드서 제거, SKILL은 migration 섹션에만.
# (c) v0.23.0 권위 문법 6개 리터럴이 production에서 제거됐다(AC13). README.md도 스코프 안 —
#     제외했던 근거("Principles Instantiated가 무엇이 왜 사라졌는지 설명하려면 옛 용어를
#     인용해야 한다")는 검증 가능한 예측이었고 실패했다: v0.23.0 README는 이 6개 리터럴을
#     grep -cF로 **0건** 인용한다. CHANGELOG.md는 실제로 4건 인용하므로(released 기록) 그
#     제외만 유효하다.
# 스코프: $SD 아래 전체 production 파일 — 확장자 whitelist 없이 sweep(SKILL.md/README.md/agents/
#         templates/scripts/plugin.json 뿐 아니라 scripts/ambiguity-blacklist.txt 같은 .txt/.yaml/
#         확장자없는 production 파일도 포함). 확장자 whitelist는 header 주장(scripts/ 커버)보다
#         좁아지는 grep-lock header-satisfiable 함정이라 폐기했다.
#         리포 루트의 docs/는 $SD 밖이라 자동으로 스코프 밖 — 중복 필터를 두지 않는다.
# 제외: (1) CHANGELOG.md(released 기록 + 이 rename을 서술하는 [0.22.0] 엔트리 — Keep-a-Changelog 불변),
#       (2) tests/(락·stage test가 토큰을 *집행/assert*하는 층 — stale ref면 그 테스트가 자체 fail),
#       (3) .pytest_cache/·__pycache__/·.git/(캐시·바이너리, production 아님),
#       (4) .claude/ — 플러그인 디렉토리 아래 .claude/는 **툴링이 쓰는 세션 상태**이지 플러그인이
#           출하하는 artifact가 아니다(quality-gates 세션 파일 등, git-untracked). 아무도 작성하지
#           않은 일시 파일이 락을 빨갛게 만들 수 있으면 사람들이 락을 무시하도록 훈련된다.
#           .claude-plugin/은 production이라 제외되지 않는다 — 패턴이 '*/.claude/*'라 안 걸린다.
#       테스트의 토큰 참조는 제거를 강제하는 enforcement 층이지 stale 참조가 아니다.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
SKILL="$SD/skills/conducting-interview/SKILL.md"
pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# grep은 세 결과를 구분한다: 0=매치(금지어 발견), 1=매치 없음(정상), >=2=grep 자체 실패
# (읽을 수 없는 파일·잘못된 인자 등). `|| true`로 상태를 삼키면 >=2가 1과 뭉뚱그려져
# **검사가 실행되지 않았는데 PASS**가 된다 — fail-closed가 존재 이유인 락에서 최악의 fail-open.
# 그래서 상태를 명시 포착하고(이 스크립트는 set -e를 쓰지 않으므로 안전) 호출자가 3-way로 분기한다.
# stderr를 2>/dev/null로 버리지 않고 캡처하는 이유: >=2일 때 원인 메시지가 유일한 단서다.
SCAN_OUT=""; SCAN_RC=0
scan() { SCAN_OUT="$(grep "$@" 2>&1)"; SCAN_RC=$?; }

# production artifact 파일 집합 — tests/·CHANGELOG.md·.claude/·cache/binary 제외,
# **확장자 whitelist 없이 전체**.
# (whitelist는 scripts/ambiguity-blacklist.txt 같은 .txt production 파일을 놓쳐 lock이 자기 헤더 주장보다
#  좁아진다 — grep-lock header-satisfiable 함정. grep -I로 binary는 스킵.)
# .claude/ 제외는 V7a·V7b·V8이 **함께** 쓰는 이 find 한 곳에 둔다 — 한 검사에만 걸면
# 검사별 스코프가 갈려 헤더 주장이 다시 거짓이 된다.
prod_files=()
while IFS= read -r f; do prod_files+=("$f"); done < <(
  find "$SD" -type f \
    -not -path '*/tests/*' -not -name 'CHANGELOG.md' \
    -not -path '*/.claude/*' \
    -not -path '*/.pytest_cache/*' -not -path '*/__pycache__/*' -not -path '*/.git/*'
)
# macOS bash 3.2: 빈 배열에 "${arr[@]}" 확장은 set -u 하에서 crash — 명시 guard(빈 집합=find 깨짐=FAIL).
if [[ ${#prod_files[@]} -eq 0 ]]; then
  note FAIL "V7: no production files found — find filter broken"
  echo; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1
fi

# V7a: breadth-keeper production 잔존 0
scan -InE 'breadth-keeper|breadth_keeper|Breadth-Keeper' "${prod_files[@]}"
if [[ $SCAN_RC -ge 2 ]]; then
  note FAIL "V7a: grep 자체 실패(exit=$SCAN_RC) — 검사가 실행되지 않았다:"; printf '%s\n' "$SCAN_OUT"
elif [[ $SCAN_RC -eq 0 ]]; then
  note FAIL "V7a: stale breadth-keeper in production:"; printf '%s\n' "$SCAN_OUT"
else
  note PASS "V7a: no breadth-keeper in production artifacts"
fi

# V7b-1: SKILL.md interview_round는 migration 섹션에만
mig="$(awk '/^## In-flight state migration/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
all_ir=$(grep -c interview_round "$SKILL" 2>/dev/null || true)
mig_ir=$(printf '%s\n' "$mig" | grep -c interview_round 2>/dev/null || true)
{ [[ "$all_ir" -ge 1 ]] && [[ "$all_ir" -eq "$mig_ir" ]]; } \
  && note PASS "V7b: interview_round in SKILL confined to migration ($all_ir)" \
  || note FAIL "V7b: interview_round leaks outside SKILL migration (total=$all_ir mig=$mig_ir)"

# V7b-2: interview_round production(SKILL 제외) 잔존 0
# 파일별 루프라 grep 실패도 파일별로 모은다 — 한 파일이 안 읽히면 그 파일은 검사되지 않은 것이므로
# "매치 없음"으로 넘기지 않고 err 버킷에 쌓아 FAIL로 만든다.
ir=""; ir_err=""
for f in "${prod_files[@]}"; do
  [[ "$f" == "$SKILL" ]] && continue
  scan -InH interview_round "$f"
  if [[ $SCAN_RC -ge 2 ]]; then ir_err+="$SCAN_OUT"$'\n'
  elif [[ $SCAN_RC -eq 0 ]]; then ir+="$SCAN_OUT"$'\n'
  fi
done
if [[ -n "$ir_err" ]]; then
  note FAIL "V7b: grep 자체 실패 — 아래 파일은 검사되지 않았다:"; printf '%s\n' "$ir_err"
elif [[ -z "$ir" ]]; then
  note PASS "V7b: no interview_round in production outside SKILL migration"
else
  note FAIL "V7b: interview_round in unexpected production files:"; printf '%s\n' "$ir"
fi

# --- V8 (AC13): v0.23.0 권위 문법 6개 리터럴 회귀 락 ---
# 스코프 = prod_files 그대로(README.md 포함) — AC13이 production 전체를 요구한다.
# prod_files는 위에서 이미 비어있지 않음이 확인됐으므로 별도 empty-guard는 불필요하다.
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
  scan -InIF -- "$term" "${prod_files[@]}"
  if [[ $SCAN_RC -ge 2 ]]; then
    note FAIL "V8/AC13: '$term' 검사가 실행되지 않았다 — grep 자체 실패(exit=$SCAN_RC):"
    printf '%s\n' "$SCAN_OUT"
  elif [[ $SCAN_RC -eq 0 ]]; then
    note FAIL "V8/AC13: '$term' 가 production에 잔존:"; printf '%s\n' "$SCAN_OUT"
  else
    note PASS "V8/AC13: '$term' 잔존 0건 (production)"
  fi
done

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
