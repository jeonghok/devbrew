#!/usr/bin/env bash
# AC7 (revised) — structural verification that codex-disabled paths
# behave identically to pre-feature state.
#
# Three checks:
#   1. Probe with kill switch returns false (uses AC1 test's logic)
#   2. SKILL.md documents codex as a Tier B availability-floor (dispatched on
#      every non-trivia iteration when detected, regardless of scope/depth) with
#      an unavailable-degrade path (v2.13.0 contract; supersedes the pre-v2.11.0
#      standard/deep-only gate + v1.10.x byte-equivalent fallback).
#   3. All existing qg test files (those not touching codex) pass —
#      no regressions in unrelated tests after the feature lands.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass=0; fail=0

# Check 1: kill switch produces skip
out="$(DEVBREW_DISABLE_QG_CODEX=1 bash "$PLUGIN_ROOT/scripts/detect_codex.sh")"
if echo "$out" | grep -q 'skip_reason: kill_switch'; then
  echo "  PASS: kill switch -> codex_available: false"
  pass=$((pass + 1))
else
  echo "  FAIL: kill switch did not produce skip"
  echo "$out" | sed 's/^/    /'
  fail=$((fail + 1))
fi

# Check 2 (v2.13.0 availability-floor contract): SKILL.md documents codex as a
# Tier B availability-floor — dispatched every non-trivia iteration when
# detect_codex is true, regardless of scope/depth, with an unavailable-degrade
# path. (Supersedes the pre-v2.11.0 standard/deep-only gate + v1.10.x
# byte-equivalent fallback, which no longer exist in the SKILL.)
# Three sub-checks; all must pass. Anchors are body-unique (mutation-tested).
SKILL_MD="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
c2_fail=0

# 2a: SKILL.md documents codex as a Tier B availability-floor
if grep -qE 'Tier B — codex \(availability-floor' "$SKILL_MD"; then
  : # sub-check pass
else
  echo "  FAIL: SKILL.md does not document codex as a Tier B availability-floor"
  c2_fail=$((c2_fail + 1))
fi

# 2b: the availability-floor is unconditional regardless of scope/depth (NOT
#     depth-gated — the semantics that superseded the old standard/deep-only gate)
if grep -qE '있으면 무조건, 스코프 무관' "$SKILL_MD"; then
  : # sub-check pass
else
  echo "  FAIL: SKILL.md does not state codex dispatches unconditionally, scope/depth-independent"
  c2_fail=$((c2_fail + 1))
fi

# 2c: codex-unavailable path degrades gracefully (continue without codex)
if grep -qE 'If codex is unavailable, continue without it' "$SKILL_MD"; then
  : # sub-check pass
else
  echo "  FAIL: SKILL.md does not document the codex-unavailable degrade path"
  c2_fail=$((c2_fail + 1))
fi

if [[ $c2_fail -eq 0 ]]; then
  echo "  PASS: SKILL.md documents codex as Tier B availability-floor (all non-trivia depths) with unavailable-degrade"
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# Check 3: codex를 건드리지 않는 기존 qg 테스트가 전부 통과한다 + "검토를
# 마친" red를 fingerprint 원장으로 별도 층에서 다룬다 (AC23).
#
# ★ 편차 기록 (2026-08-09, 태스크 20 컨트롤러 판정 R7 — 제목은 "열거를 도출로"
#   지만 이 블록은 도출로 바꾸지 않는다):
#   태스크 브리프의 Step 2는 아래 이름 열거를 `grep -qil 'codex' "$1"` 콘텐츠
#   도출로 바꾸라고 했다. 실측해보니 그 도출은 7개가 아니라 **36개**를 제외해
#   이 메타 테스트가 98개에서 69개로 줄어든다. 새로 제외되는 29개 중에는 Law 2
#   보안 락(test_agent_tools_lock_differential.sh · test_agent_tools_lock_mutation.sh
#   · test_law2_prose.sh)이 포함되는데, 이들은 "codex"를 실행 대상 코드가 아니라
#   **주석**(예: "codex model-diversity 가 단독 적발" 같은 서술)에서만 언급한다 —
#   그 우연한 단어 매치 때문에, 강화하려던 바로 그 검사에 30%짜리 구멍이 뚫린다.
#   "열거는 시간에 fail-open"이라는 도출의 근거도 반증됐다: 새 codex 테스트를
#   이 목록에 추가하는 것을 잊으면 이 메타 테스트는 그 테스트를 **그냥 실행**
#   한다 — 통과하면 비용이 없고, 실패하면 시끄럽게 unexpected로 잡힌다. 열거를
#   잊는 것은 fail-closed다. 진짜 결함은 열거 자체가 아니라 **같은 목록의
#   사본이 이 파일 안에 두 곳(예전 :81, :100) 있었다**는 것뿐이다. 그래서 이
#   태스크는 열거를 도출로 바꾸지 않고 사본만 하나로 합친다(아래
#   CODEX_TOUCHING_TESTS 가 유일한 원본). 도출이 옳은 자리는 따로 있다 —
#   형제 파일 test_codex_runner_degrade_contract.sh의 러너 목록은 도출로
#   바꿨다(그 파일 상단 주석 참고).
#
# 자기 제외는 이 열거와 **무관하게** 먼저 확인한다(재귀 방지) — "codex" 언급
# 이라는 우연에 기대면 파일명이 바뀌거나 codex 언급이 사라질 때 198초 × 무한
# 재귀가 부활한다. is_excluded의 SELF 검사가 반드시 첫 줄이어야 하는 이유.
CODEX_TOUCHING_TESTS="test_detect_codex.sh test_findings_parser.sh test_sandbox_enforced.sh test_failure_injection.sh test_scout_codex_integration.sh test_cost_consent.sh"

# ── 제외 목록 크기 핀 (라운드 1 리뷰 L2, L1과 공유) ──────────────────────────
# 아래 커버리지 래칫은 "entry가 몰래 늘어나거나 정당성을 잃어도"라고 주장했지만,
# `grep -qil 'codex'`는 어디든(주석 포함) "codex"를 언급하기만 하면 통과하므로
# 실제로는 후자(정당성 상실)만 잡았다 — 이 열거와 무관한 Law 2 보안 락에
# "codex model-diversity가 단독 적발" 같은 서술 한 줄만 있어도 조용히 들어온다
# (컨트롤러 재현: test_agent_tools_lock.sh를 이 목록에 추가 → 메타 테스트
# rc 1→0. R7이 닫은 36-vs-7 구멍이 entry 하나씩 다시 열릴 수 있다는 뜻이다).
# 이유는 "무엇이 여전히 정당한가"만 재고 "집합이 몰래 자랐는가"는 아무도 안
# 쟀기 때문 — **크기**를 리터럴로 핀해서 막는다.
#
# 이 핀은 existing_run 바닥(L1, 아래)도 공유한다: existing_run의 기대값은
# "전체 후보 수 − 이 핀"으로 도출되므로, 제외 목록이 몰래 자라거나 줄면(핀은
# 그대로 두고) 두 검사 모두 같이 RED가 된다 — 완전히 독립은 아니다: 목록을
# 정말로 늘리면서 이 핀도 같은 커밋에서 의식적으로 고치면 둘 다 조용히
# 통과한다. 그 "의식적 갱신 강제"가 정확히 래칫이 원하는 동작이다.
EXCLUDED_TESTS_PIN=7   # CODEX_TOUCHING_TESTS 6개 + self(이 파일) 1개 — 2026-08-10 확정치

SELF="$(basename "${BASH_SOURCE[0]}")"
is_excluded() {   # $1 = 테스트 파일 경로
  local b; b="$(basename "$1")"
  [ "$b" = "$SELF" ] && return 0   # 자기 제외 — 반드시 첫 줄 (재귀 방지)
  case " $CODEX_TOUCHING_TESTS " in
    *" $b "*) return 0 ;;
  esac
  return 1
}

# ── 커버리지 래칫 (컨트롤러 R7 두 번째 축) ────────────────────────────────────
# CODEX_TOUCHING_TESTS는 정적 열거이지 도출이 아니다(위 편차 기록 참고) — 그래서
# "목록은 줄어들기만 한다"는 doctrine을 강제할 별도 장치가 필요하다. 여기서는
# 열거의 **각 항목**이 여전히 정당한지(실제로 codex를 언급하는지)만 사후 검증한다.
# ★ 방향이 반대다: Step 2가 반증한 content-grep 도출은 "무엇을 제외할지"를 넓게
#   **만들었지만**(7개 → 36개), 여기서는 이미 정적으로 열거된 항목을 **좁히는**
#   쪽으로만 쓴다 — 더 이상 codex를 언급하지 않는 항목이 남으면 RED로 만들어
#   목록에서 지우도록 강제한다(entry가 몰래 늘어나거나 정당성을 잃어도 조용히
#   넘어가지 않는다). 새 항목을 이 grep으로 **추가**하는 데는 절대 쓰지 않는다.
unjustified=""
for b in $CODEX_TOUCHING_TESTS; do
  f="$PLUGIN_ROOT/tests/$b"
  [ -f "$f" ] || continue
  grep -qil 'codex' "$f" || unjustified="$unjustified $b"
done
# L2: 개별 정당성(위)만으로는 목록이 "몰래 늘어나는" 것을 못 잡는다 — 크기를
# 위에서 핀한 EXCLUDED_TESTS_PIN과 비교한다(단어 수 + self 1).
excluded_word_count=$(wc -w <<< "$CODEX_TOUCHING_TESTS")
excluded_actual_count=$((excluded_word_count + 1))
if [[ -z "${unjustified// /}" && "$excluded_actual_count" -eq "$EXCLUDED_TESTS_PIN" ]]; then
  echo "  PASS: 제외 목록 항목이 전부 여전히 codex를 언급한다 + 크기(${excluded_actual_count})가 핀과 일치한다 (커버리지 래칫)"
  pass=$((pass + 1))
else
  [[ -n "${unjustified// /}" ]] && echo "  FAIL: 더 이상 제외될 이유가 없는 항목 →$unjustified (목록에서 제거할 것)"
  [[ "$excluded_actual_count" -ne "$EXCLUDED_TESTS_PIN" ]] && \
    echo "  FAIL: 제외 목록 크기가 ${excluded_actual_count}개 — 핀(${EXCLUDED_TESTS_PIN})과 어긋난다. CODEX_TOUCHING_TESTS를 의식적으로 바꿨다면 이 커밋에서 EXCLUDED_TESTS_PIN도 같이 갱신할 것 (L2)"
  fail=$((fail + 1))
fi

# ── 층 2: fingerprint 원장 — "검토를 마친" red만 등재한다 ─────────────────────
# 양방향이다: 미등재·해시 불일치 실패는 RED, 등재됐는데 GREEN이 된 항목도 RED.
# 목록은 줄어들기만 한다 — 새 red를 등재하는 것은 검토를 마쳤다는 선언이다.
#
# 정규화(실패 줄만 + <REPO>/<TMP> 치환 + 숫자 → N)의 이유(설계 §10 미해결 3):
# 등재 대상 하나(test_security_reviewer_kill_switch.sh)의 출력이 이 사이클이
# 편집하는 quality-pipeline/SKILL.md의 grep 카운트를 담아, 그 파일을 고칠
# 때마다 원시 해시가 stale이 된다. 어떤 assert가 실패하는지(문구)는 남으므로
# 같은 파일이 **다른 이유로** 실패하기 시작하면 해시가 바뀐다.
# L3 (라운드 1 리뷰): 빈 문자열의 sha256 — grep이 FAIL/✗ 줄을 하나도 못 찾으면
# 지문이 여기로 무너진다. 이 값과 일치하는 지문은 절대 유효한 원장 값으로
# 받아들이지 않는다(아래) — 서로 다른 실패 이유가 전부 이 값 하나로 뭉개지면
# ":138-139"의 계약("같은 파일이 다른 이유로 실패하면 해시가 바뀐다")이 이
# absorbing state 안에서는 거짓이 되기 때문이다.
EMPTY_DIGEST_SHA256='e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
LEDGER="$SCRIPT_DIR/codex-blessed-red.txt"
fingerprint() {   # $1 = 테스트 경로 → 정규화된 실패 지문
  # L3: 아래 실행 루프(:166-167 부근)는 확장자로 python3/bash를 가르는데 이
  # 함수는 늘 bash로 돌렸다 — .py 테스트를 bash로 실행하면 대개 FAIL/✗ 패턴을
  # 하나도 못 내(python 문법 에러는 다른 형태로 stderr에 남는다) 빈 입력이
  # EMPTY_DIGEST_SHA256로 뭉개진다(실측: test_qg_gc.py). 이 디렉터리의 105개
  # 중 17개가 .py다. 루프와 같은 디스패치로 맞춘다.
  local runner
  case "$1" in
    *.py) runner="python3" ;;
    *)    runner="bash" ;;
  esac
  { "$runner" "$1" 2>&1 || true; } \
    | grep -E 'FAIL|✗' \
    | sed -e "s|$PLUGIN_ROOT|<REPO>|g" \
          -e 's|/[Vv]ar/folders/[^ ]*|<TMP>|g' \
          -e 's|/tmp/[^ ]*|<TMP>|g' \
          -e 's/[0-9][0-9]*/N/g' \
    | shasum -a 256 | cut -d' ' -f1
}
ledger_hash() {   # $1 = basename → 등재된 해시 (없으면 빈 문자열)
  [ -f "$LEDGER" ] || return 0
  awk -v n="$1" '$1 == n {print $2}' "$LEDGER" | head -1
}

echo "Running existing qg test suite..."
existing_run=0
unexpected=""
stale_ledger=""
seen_in_ledger=""
for t in "$PLUGIN_ROOT"/tests/test_*.sh "$PLUGIN_ROOT"/tests/test_*.py; do
  [[ -f "$t" ]] || continue
  is_excluded "$t" && continue
  existing_run=$((existing_run + 1))
  b="$(basename "$t")"
  case "$t" in
    *.py) rc=0; python3 "$t" > /dev/null 2>&1 || rc=1 ;;
    *.sh) rc=0; bash "$t" > /dev/null 2>&1 || rc=1 ;;
  esac
  listed="$(ledger_hash "$b")"
  if [[ "$rc" -eq 0 ]]; then
    # 등재됐는데 GREEN → stale 등재. 지워야 한다.
    [[ -n "$listed" ]] && stale_ledger="$stale_ledger $b"
  else
    if [[ -z "$listed" ]]; then
      unexpected="$unexpected $b(미등재)"
    else
      actual="$(fingerprint "$t")"
      seen_in_ledger="$seen_in_ledger $b"
      # L3: 빈-지문은 유효한 원장 값으로 절대 받아들이지 않는다 — actual이
      # EMPTY_DIGEST_SHA256이면 listed와 우연히 같더라도(오늘은 아니다) 매치로
      # 치지 않는다. dispatch가 다시 고장 나 모든 .py가 이 값으로 뭉개져도
      # "일치"라고 조용히 통과하는 사고를 막는다.
      if [[ "$actual" == "$EMPTY_DIGEST_SHA256" ]]; then
        unexpected="$unexpected $b(빈지문:FAIL/✗ 줄을 하나도 못 찾음 — fingerprint dispatch 확인)"
      elif [[ "$actual" != "$listed" ]]; then
        unexpected="$unexpected $b(해시불일치:$actual)"
      fi
    fi
  fi
done

# L1 (라운드 1 리뷰): existing_run은 지금까지 초기화·증가·출력만 됐지 assert된
# 적이 없었다 — PLUGIN_ROOT 도출이 깨지거나 glob이 변형돼 이 루프가 0개를 돌아도
# unexpected/stale_ledger가 둘 다 빈 문자열이라 곧장 PASS("0개 중 예상 밖 실패
# 0")가 나가고 exit 0이었다. 이 파일의 헤드라인 산출물(98개, 회귀 0)이 나쁜
# 날엔 텅 빈 채로 통과했다는 뜻이다.
#
# 매직넘버 대신, 위 for 루프가 쓴 것과 **다른 방식**(find)으로 후보 총수를 독립
# 재도출해 기대값을 derive한다 — 같은 glob 문자열을 복붙하면 그 glob 자체가
# 변형될 때("the glob shifts") 두 값이 같이 변해 드리프트를 못 잡는다. 제외
# 개수는 위에서 핀한 EXCLUDED_TESTS_PIN을 그대로 쓴다(L2와 공유 — 제외 목록이
# 몰래 자라거나 줄면 여기도 같이 반응한다).
total_candidates="$(find "$PLUGIN_ROOT/tests" -maxdepth 1 \( -name 'test_*.sh' -o -name 'test_*.py' \) | wc -l | tr -d ' ')"
expected_existing_run=$((total_candidates - EXCLUDED_TESTS_PIN))
run_floor_ok=1
[[ "$existing_run" -eq "$expected_existing_run" && "$existing_run" -gt 0 ]] || run_floor_ok=0

if [[ -z "${unexpected// /}" && -z "${stale_ledger// /}" && "$run_floor_ok" -eq 1 ]]; then
  echo "  PASS: ${existing_run}개 중 예상 밖 실패 0 · stale 등재 0 (등재된 red:${seen_in_ledger:- 없음})"
  pass=$((pass + 1))
else
  [[ -n "${unexpected// /}" ]] && echo "  FAIL: 예상 밖 실패 →$unexpected"
  [[ -n "${stale_ledger// /}" ]] && echo "  FAIL: stale 등재 (GREEN인데 원장에 있다) →$stale_ledger"
  [[ "$run_floor_ok" -eq 0 ]] && \
    echo "  FAIL: existing_run=${existing_run}, 기대값=${expected_existing_run}(find 도출 후보 ${total_candidates} − 핀 ${EXCLUDED_TESTS_PIN}) — PLUGIN_ROOT 도출이 깨졌거나 glob이 변형됐다 (L1)"
  fail=$((fail + 1))
fi

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[[ $fail -eq 0 ]] || exit 1
