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
#   3. 원장(codex-blessed-red.txt)에 등재된 red 만 다시 돌려 지문을 대조한다 —
#      등재되지 않은 실패는 전체 러너가 그 테스트를 직접 돌려 자기 `FAILED` 줄로 낸다.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass=0; fail=0

# Check 1: kill switch produces skip
out="$(DEVBREW_QUALITY_GATES_DISABLE_CODEX=1 bash "$PLUGIN_ROOT/scripts/detect_codex.sh")"
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

# 2a: SKILL.md documents codex as the 다른 전제 각도 (different-premise angle)
if grep -qE '다른 전제 각도 — codex \(사용 가능하면 부른다' "$SKILL_MD"; then
  : # sub-check pass
else
  echo "  FAIL: SKILL.md does not document codex as the 다른 전제 각도"
  c2_fail=$((c2_fail + 1))
fi

# 2b: the availability-floor is unconditional regardless of scope/depth (NOT
#     depth-gated — the semantics that superseded the old standard/deep-only gate)
if grep -qE 'regardless of scope' "$SKILL_MD"; then
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
  echo "  PASS: SKILL.md documents codex as the 다른 전제 각도 (all non-trivia depths) with unavailable-degrade"
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# Check 3: 원장(codex-blessed-red.txt)에 등재된 red 만 다시 돌려 지문을 대조한다 —
# 등재되지 않은 실패는 전체 러너가 그 테스트를 직접 돌려 자기 `FAILED` 줄로 낸다.
#
# 정규화(실패 줄만 + <REPO>/<TMP> 치환 + 숫자 → N)의 이유(설계 §10 미해결 3):
# 등재 대상 하나(test_security_reviewer_kill_switch.sh)의 출력이 이 사이클이
# 편집하는 quality-pipeline/SKILL.md의 grep 카운트를 담아, 그 파일을 고칠
# 때마다 원시 해시가 stale이 된다. 어떤 assert가 실패하는지(문구)는 남으므로
# 같은 파일이 **다른 이유로** 실패하기 시작하면 해시가 바뀐다.
# L3 (라운드 1 리뷰): 빈 문자열의 sha256 — grep이 FAIL/✗ 줄을 하나도 못 찾으면
# 지문이 여기로 무너진다. 이 값과 일치하는 지문은 절대 유효한 원장 값으로
# 받아들이지 않는다(아래) — 서로 다른 실패 이유가 전부 이 값 하나로 뭉개지면
# 위 정규화 문단의 계약("실패하기 시작하면 해시가 바뀐다")은 이 absorbing
# state 안에서는 거짓이 되기 때문이다.
EMPTY_DIGEST_SHA256='e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
LEDGER="$SCRIPT_DIR/codex-blessed-red.txt"
SELF="$(basename "${BASH_SOURCE[0]}")"
fingerprint() {   # $1 = 테스트 경로 → 정규화된 실패 지문
  # L3: 확장자로 python3/bash를 가른다 — .py 테스트를 bash로 실행하면 대개
  # FAIL/✗ 패턴을 하나도 못 내 빈 입력이 EMPTY_DIGEST_SHA256로 뭉개진다.
  local runner
  case "$1" in
    *.py) runner="python3" ;;
    *)    runner="bash" ;;
  esac
  { "$runner" "$1" 2>&1 </dev/null || true; } \
    | grep -E 'FAIL|✗' \
    | sed -e "s|$PLUGIN_ROOT|<REPO>|g" \
          -e 's|/[Vv]ar/folders/[^ ]*|<TMP>|g' \
          -e 's|/tmp/[^ ]*|<TMP>|g' \
          -e 's/[0-9][0-9]*/N/g' \
    | shasum -a 256 | cut -d' ' -f1
}

# 원장의 등재 줄(주석 · 빈 줄이 아닌 줄)을 `<파일 이름> <지문>` 으로 읽는다.
# 등재된 테스트: 등재된 테스트가 다른 이유로 실패하면(해시 불일치) RED, 등재됐는데
# GREEN 이면 RED. 목록은 줄어들기만 한다 — 새 red를 등재하는 것은 검토를 마쳤다는 선언이다.
echo "Checking blessed-red ledger..."
c3_fail=""   # 사유마다 한 줄(개행으로 잇는다)
listed_count=0
c3_add() { c3_fail="${c3_fail}$1"$'\n'; }
if [[ ! -f "$LEDGER" ]]; then
  c3_add "원장 없음:$LEDGER"
else
  # 원장은 별도 fd(3)로 읽는다 — 다시 돌리는 테스트가 표준 입력을 읽어도 남은 등재 줄을 먹지 못하게.
  while read -r b listed _rest <&3 || [[ -n "$b" ]]; do
    case "$b" in ''|'#'*) continue ;; esac
    listed_count=$((listed_count + 1))
    t="$PLUGIN_ROOT/tests/$b"
    if [[ "$b" = "$SELF" ]]; then
      c3_add "$b(자기 등재)"   # 자기를 다시 돌리면 재귀한다
      continue
    fi
    if [[ ! -f "$t" ]]; then
      c3_add "$b(등재된 파일 없음)"
      continue
    fi
    case "$t" in
      *.py) rc=0; python3 "$t" > /dev/null 2>&1 </dev/null || rc=1 ;;
      *)    rc=0; bash "$t" > /dev/null 2>&1 </dev/null || rc=1 ;;
    esac
    if [[ "$rc" -eq 0 ]]; then
      # 등재됐는데 GREEN → stale 등재. 지워야 한다.
      c3_add "$b(stale 등재)"
    else
      actual="$(fingerprint "$t")"
      # 빈 지문은 유효한 원장 값으로 받아들이지 않는다 — 우연히 listed와 같아도 매치가 아니다.
      if [[ "$actual" == "$EMPTY_DIGEST_SHA256" ]]; then
        c3_add "$b(빈지문:FAIL/✗ 줄을 하나도 못 찾음 — fingerprint dispatch 확인)"
      elif [[ "$actual" != "$listed" ]]; then
        c3_add "$b(해시불일치:$actual)"
      fi
    fi
  done 3< "$LEDGER"
fi

if [[ -z "$c3_fail" ]]; then
  if [[ "$listed_count" -eq 0 ]]; then
    echo "  PASS: 등재 0건 — 다시 돌린 테스트 0개"
  else
    echo "  PASS: 등재 ${listed_count}건 — 지문 일치 · stale 등재 0"
  fi
  pass=$((pass + 1))
else
  while IFS= read -r line; do
    [[ -n "$line" ]] && echo "  FAIL: $line"
  done <<< "$c3_fail"
  fail=$((fail + 1))
fi

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[[ $fail -eq 0 ]] || exit 1
