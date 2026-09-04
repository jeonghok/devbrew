#!/usr/bin/env bash
# guards: plugins/spec-distill/hooks/review-dispatch.py tools/adjudication/check_wiring.py shared/tests/fixtures/adjudication/run_block_disposition_count.py
#
# 훅의 차단 결정 두 자리가 자기 처분을 원장 어휘로 밝히는지 검사한다.
#
# 채널은 `reason` 이다. `systemMessage` 는 모델 컨텍스트에 도달하지 않는다
# (카나리 14개 중 0개). `reason` 은 차단 결정에 딸릴 때 7/7 도달한다.
#
# Task 11 수정 라운드 2 — `reasons()` 직접 호출 대신 공유 렌더러
# `disposition_lines()` 를 쓴다. 원인: L2 소비 락(test_adjudication_consumed.sh)
# 이 `reasons()` 는 held·unknown·sources_failed·coerced(gate=True) 넷만
# 내고 accepted/rejected/absorbed/suppressed 는 침묵한다는 것을 잡았다 —
# 오늘 이 훅이 hold() 만 불러 우연히 안 드러났을 뿐, 이 훅에 reject() 하나만
# 늘어도 조용히 새는 구조였다.
#
# 이 라운드에서 소스 텍스트 검사(`reasons\(\)` grep)의 한계도 드러났다:
# 구현이 바뀐 뒤에도 «이 파일 자신의 설명 주석»이 우연히 그 문자열을 담고
# 있어 단언이 계속 GREEN 이었다(호출이 아니라 이름의 존재만 잰 값싼 검사의
# 정체). 그래서 구조 검사에 더해 훅을 **실제로 실행**해 JSON 출력을 보는
# 절을 둔다 — 이것만이 "정말 disposition_lines() 가 불려 reason 에 실렸다"
# 를 증명한다.
#
# Task 15 수정 라운드 1 (F1·F2) — 위 "구조 검사"·"실행 절" 둘 다 결손이
# 실측됐다(변이 μ11):
#  F1) 정적 카운트가 `grep -c '\.(hold|reject|...)\('` 였다 — review-dispatch.py:222
#      의 설명 주석 안 `` `L.reject(...)` `` 텍스트가 정규식을 그대로 만족시켜,
#      진짜 호출(:804 `L.hold(...)`) 하나가 지워져도 카운트가 안 줄었다(2→2).
#      `shared/tests/fixtures/adjudication/run_block_disposition_count.py` 로
#      옮겨 ast 로 센다 — 주석·문자열 리터럴은 원리적으로 안 잡힌다.
#  F2) 실행 절이 `**처분:**` 라벨의 «존재»만 grep 했다. `disposition_lines()`
#      는 원장이 비어도 라벨을 무조건 찍으므로, 위 :804 호출을 지워도
#      "미판정 0" 인 채로 라벨은 그대로 나와 통과했다. 아래에 「미판정 1」
#      값 자체를 재는 절을 추가한다(T5-1 이 이미 하던 배관 손실 값 검사와
#      같은 방식).
#
# Task 15 수정 라운드 2 (I1·I2):
#  I1) F6 은 `check_wiring.py`(F1 의 카운터가 import 하는 대상) 만 코퍼스에
#      넣고, «부르는» `run_block_disposition_count.py` 자신은 무방비로
#      남겼다 — F4 의 실제 결함(러너의 print 루프)과 같은 자리를 이 라운드가
#      새로 하나 더 열었다는 뜻이다. 그 러너를 이 락(유일한 소비자)에 편입.
#  I2) F2 의 「미판정 1」 값 검사가 후보 문서를 «하나만» 놓아 「1 vs N」을
#      못 갈랐다(:148-150 의 형제 절이 경고하는 바로 그 off-by-one 함정을
#      T5-2 는 피하지 못했다). 후보를 둘 이상 두고 그래도 미판정이 정확히
#      1(dispatch 는 여전히 하나만 고른다)임을 잰다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../../shared/tests/assert.sh"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/review-dispatch.py"
COUNTER="$REPO_ROOT/shared/tests/fixtures/adjudication/run_block_disposition_count.py"

# `--emit-scanned` — test_guards_coverage_bidirectional.sh 가 읽는다. 코퍼스는
# 상수다: 훅 자신 + F1 이 새로 도입한 ast 카운터가 실제로 import 하는
# `tools/adjudication/check_wiring.py`(처분 메서드 어휘 `DISPOSITION` 의 정본).
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' "${HOOK#"$REPO_ROOT"/}"
  PYTHONDONTWRITEBYTECODE=1 python3 "$COUNTER" "$REPO_ROOT" --emit-scanned
  printf '%s\n' "shared/tests/fixtures/adjudication/run_block_disposition_count.py"
  exit 0
fi

BODY="$(cat "$HOOK")"

assert_grep "$BODY" 'from adjudication import Ledger' \
  "훅이 원장을 import 한다 (㉮ 에 들어온다 — L1 의 대상이 된다)"
assert_grep "$BODY" 'from render_disposition import disposition_lines' \
  "훅이 공유 렌더러를 import 한다 (키 이름을 손으로 다시 적지 않는다)"

# 차단 결정 자리마다 처분 호출이 있는지 — ast 기반(F1). 자리 «수»에서
# 출발한다 — 하나를 배선하고 다른 하나를 잊는 것이 이 검사가 막는 것이다.
COUNT_OUT="$(PYTHONDONTWRITEBYTECODE=1 python3 "$COUNTER" "$REPO_ROOT" "$HOOK")"
note "$COUNT_OUT"

note "── 판정기 자체 (fixture) — decoy 주석에 안 속는지 먼저 확인한다"
assert_contains "$COUNT_OUT" "fx_good_ndisp=1" \
  "같은 파일의 진짜 호출 하나는 정상적으로 센다"
assert_contains "$COUNT_OUT" "fx_decoy_ndisp=0" \
  "설명 주석 속 문자열(review-dispatch.py:222 실측 패턴)은 호출로 안 센다"

nblock="$(printf '%s\n' "$COUNT_OUT" | sed -n 's/^target_nblock=//p')"
ndisp="$(printf '%s\n' "$COUNT_OUT" | sed -n 's/^target_ndisp=//p')"
note "차단 결정 $nblock 자리 · 처분 호출 $ndisp 건 (ast 기반)"
if [ "${nblock:-0}" -gt 0 ] 2>/dev/null; then
  ok "차단 결정 $nblock 자리 (0 이 아니다)"
else
  no "차단 결정이 0 이다 — ast 파싱이 깨졌거나 분기가 사라졌다. 이 검사가 공허하다"
fi
if [ "${ndisp:-0}" -ge "${nblock:-0}" ] 2>/dev/null; then
  ok "처분 호출 $ndisp >= 차단 자리 $nblock"
else
  no "차단 자리 $nblock 중 $((nblock - ndisp)) 곳이 처분을 안 부른다"
fi

# 렌더러가 실제로 «호출» 형태로 나타나는지 (이름만 있는 주석과 구별하려는
# 최소 방어 — 진짜 증거는 아래 실행 절).
assert_grep "$BODY" 'disposition_lines\(' \
  "훅이 disposition_lines() 를 호출 형태로 쓴다"

# ── 실행 절 — 진짜 decision:"block" 을 발생시켜 JSON 출력을 확인한다 ──────
# T5-2(dispatch 강제) 경로: 후보 문서를 «둘» 놓는다(수정 라운드 2, I2).
# 하나만 놓으면 「dispatch 가 후보마다 hold() 를 부른다」류 회귀에서도 값이
# 우연히 1 이라 이 절이 못 가른다 — :148-150 의 형제 절이 이미 경고하는
# 그 off-by-one 함정(T5-1 은 그래서 실패 문서를 둘 쓴다)을 T5-2 는 피하지
# 못하고 있었다. dispatch 는 여전히 한 턴에 하나만 고르므로(A11) 후보가
# 둘이어도 기대값은 1 그대로다 — 「후보 수와 무관하게 정확히 1」을 잰다.
WORK=$(mktemp -d -t revdispdisp-XXXXXX) || exit 1
WORK=$(cd "$WORK" && pwd -P) || exit 1
trap 'rm -rf "$WORK"' EXIT
( cd "$WORK" && git init -q && git config user.email t@t.t && git config user.name t \
  && git commit -q --allow-empty -m seed ) >/dev/null
REL="docs/superpowers/specs/2026-05-17-disp-design.md"
REL2="docs/superpowers/specs/2026-05-17-disp-design-b.md"
mkdir -p "$WORK/$(dirname "$REL")"
cp "$REPO_ROOT/plugins/spec-distill/tests/fixtures/2026-05-17-test-design.md" "$WORK/$REL"
cp "$REPO_ROOT/plugins/spec-distill/tests/fixtures/2026-05-17-test-design.md" "$WORK/$REL2"
mkdir -p "$WORK/.claude/spec-distill/disp-probe-sid"
cat > "$WORK/.claude/spec-distill/disp-probe-sid/state.local.md" <<'EOF'
---
session_id: disp-probe-sid
---
EOF
OUT="$(cd "$WORK" && DEVBREW_SPEC_DISTILL_SESSION_ID=disp-probe-sid \
  python3 "$HOOK" </dev/null 2>/dev/null)"

REASON="$(printf '%s' "$OUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("reason",""))' 2>/dev/null)"
SYSMSG="$(printf '%s' "$OUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("systemMessage",""))' 2>/dev/null)"

assert_grep "$REASON" 'MANDATORY' \
  "실제 block 의 reason 이 지시문을 담는다"
assert_grep "$REASON" '\*\*처분:\*\*' \
  "실제 block 의 reason 에 처분 줄이 실제로 실린다"
assert_grep "$REASON" '\*\*배관 손실:\*\*' \
  "실제 block 의 reason 에 배관 손실 줄이 실제로 실린다"
assert_not_grep "$SYSMSG" '\*\*처분:\*\*' \
  "systemMessage 에는 처분 줄이 안 실린다 (사람 채널·모델 채널을 계속 분리한다)"

# F2 (수정 라운드 1) — 라벨의 «존재» 가 아니라 «값» 을 잰다.
# `disposition_lines()` 는 원장이 비어도 `**처분:**` 라벨을 무조건 찍으므로,
# 위 assert_grep 셋은 :804 의 `L.hold(str(cand.path), ...)` 를 지워도 전부
# 통과했다(미판정이 0 으로 찍혀도 라벨 자체는 그대로 나오므로) — 변이 μ11 실측.
# 이 시나리오(T5-2, 후보 문서 하나)는 그 한 번의 hold() 로 미판정이 정확히
# 1 이어야 한다.
UNADJ1="$(printf '%s' "$REASON" | python3 -c '
import re, sys
m = re.search(r"미판정 (\d+)", sys.stdin.read())
print(m.group(1) if m else "-1")
')"
assert_eq "$UNADJ1" "1" \
  "T5-2 dispatch 강제 1건 → 미판정 정확히 1 (라벨이 아니라 값)"

# 배치 — 지시문이 처분 줄보다 «먼저» 나온다. 앞뒤가 바뀌면 지시가 처분
# 텍스트에 묻혀 다음 턴 강제력이 떨어진다(오케스트레이터 지적).
MANDATORY_POS="$(printf '%s' "$REASON" | grep -bo 'MANDATORY' | head -1 | cut -d: -f1)"
DISP_POS="$(printf '%s' "$REASON" | grep -bo '\*\*처분:\*\*' | head -1 | cut -d: -f1)"
if [ -n "${MANDATORY_POS:-}" ] && [ -n "${DISP_POS:-}" ] \
   && [ "$MANDATORY_POS" -lt "$DISP_POS" ] 2>/dev/null; then
  ok "배치 — MANDATORY 지시문이 처분 줄보다 앞에 온다"
else
  no "배치 위반 — MANDATORY(${MANDATORY_POS:-?}) 가 처분 줄(${DISP_POS:-?}) 보다 앞이 아니다"
fi

# ── 실행 절 2 — T5-1(구조 검증 실패) : 실패 문서 «수» == 원장이 센 항목 수 ──
# Task 11 수정 라운드 3 — 오케스트레이터가 실측 적발: 최초 판은
# `for line in lines: L.hold(line[:60], ...)` 로 «메시지 줄»(안내 헤더 +
# 실패 문서 + 상한 안내)을 돌아, 실패 문서가 N개여도 hold() 가 N+1(헤더
# 포함) 또는 N+2(헤더+상한 안내 포함)회 불렸다. 실패 문서가 하나면 이
# off-by-one 이 안 보이므로(1개 vs 2개 구별이 안 됨) 여기서는 반드시
# **둘 이상** 실패시킨다.
#
# 채널 note: 이 항목들은 hold() 사유가 "항목 파손:" 접두라
# disposition_lines() 의 **배관 손실**(line2) 칸에 실린다 — "미판정"
# (line1) 이 아니다. "미판정" 은 "판정자 부재" 접두 전용 칸이라 T5-2(위
# 실행 절 1) 에서만 움직인다. 오케스트레이터의 라운드 3 지시문은 이 칸을
# "미판정" 으로 불렀으나 실제 필드는 "배관 손실" 이다 — 보고서에 그 사실을
# 적었다(측정 대상은 동일: hold() 호출 수 == 실패 문서 수).
WORK2=$(mktemp -d -t revdispdisp2-XXXXXX) || exit 1
WORK2=$(cd "$WORK2" && pwd -P) || exit 1
trap 'rm -rf "$WORK" "$WORK2"' EXIT
( cd "$WORK2" && git init -q && git config user.email t@t.t && git config user.name t \
  && git commit -q --allow-empty -m seed ) >/dev/null
RELA2="docs/superpowers/specs/2026-05-17-disp-fail-a-spec.md"
RELB2="docs/superpowers/specs/2026-05-17-disp-fail-b-spec.md"
mkdir -p "$WORK2/$(dirname "$RELA2")"
printf '# A — frontmatter 없음\n\n본문 A.\n' > "$WORK2/$RELA2"
printf '# B — frontmatter 없음\n\n본문 B.\n' > "$WORK2/$RELB2"
mkdir -p "$WORK2/.claude/spec-distill/disp-probe-fail-sid"
cat > "$WORK2/.claude/spec-distill/disp-probe-fail-sid/state.local.md" <<'EOF'
---
session_id: disp-probe-fail-sid
---
EOF
OUT2="$(cd "$WORK2" && DEVBREW_SPEC_DISTILL_SESSION_ID=disp-probe-fail-sid \
  python3 "$HOOK" </dev/null 2>/dev/null)"
REASON2="$(printf '%s' "$OUT2" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("reason",""))' 2>/dev/null)"
PLUMBING2="$(printf '%s' "$REASON2" | python3 -c '
import re, sys
m = re.search(r"\*\*배관 손실:\*\* (\d+)", sys.stdin.read())
print(m.group(1) if m else "-1")
')"
assert_eq "$PLUMBING2" "2" \
  "실패 문서 2개 → 배관 손실 정확히 2 (안내 헤더·상한 안내를 항목으로 잘못 세지 않는다)"

finish
