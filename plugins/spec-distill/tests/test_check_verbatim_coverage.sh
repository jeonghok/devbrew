#!/usr/bin/env bash
# Spec B T1·T2·T3·T4·T19·T20·T31(행위) — check_verbatim_coverage.py.
# AC10(L1) · AC11(L2 + P21 강등 + N1–N5 순서 + NFC) · AC12(exit 1/3/4 분리 + 예외 계약) · AC14(부분)
# Run: bash plugins/spec-distill/tests/test_check_verbatim_coverage.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/check_verbatim_coverage.py"
FX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }
rc_of() { python3 "$SCRIPT" "$1" "$2" >/dev/null 2>&1; echo $?; }
json_of() { python3 "$SCRIPT" "$1" "$2" 2>/dev/null; }

test -f "$SCRIPT" || { note FAIL "스크립트 부재: $SCRIPT"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }

# --- 정상 경로 -------------------------------------------------------------
[[ "$(rc_of "$FX/brief-verbatim-ok.md" "$FX/state-verbatim-ok.md")" == "0" ]] \
  && note PASS "정상 fixture → exit 0" || note FAIL "정상 fixture가 exit 0이 아님"

# --- T1 / AC10 : L1 ---------------------------------------------------------
rc="$(rc_of "$FX/brief-verbatim-missing-anchor.md" "$FX/state-verbatim-ok.md")"
[[ "$rc" == "1" ]] && note PASS "T1: S<N> 앵커 누락 → exit 1" || note FAIL "T1: 앵커 누락이 exit 1이 아님 (rc=$rc)"
# json_of의 스크립트는 위반 시 exit 1을 낸다; `set -o pipefail` 하에서 `cmd | grep` 형태로
# 바로 연결하면 파이프 전체 상태가 grep(성공)이 아니라 cmd(1)로 오염돼 항상 FAIL로 오분류된다.
# 변수 캡처 후 grep해 파이프를 피한다.
out="$(json_of "$FX/brief-verbatim-missing-anchor.md" "$FX/state-verbatim-ok.md")"
grep -q '"missing_ids": \["S2"\]' <<<"$out" \
  && note PASS "T1: missing_ids에 S2" || note FAIL "T1: missing_ids가 S2를 담지 않음"

# --- T2 / AC11·AC14 : L2 ----------------------------------------------------
rc="$(rc_of "$FX/brief-verbatim-summarized.md" "$FX/state-verbatim-ok.md")"
[[ "$rc" == "1" ]] && note PASS "T2: 요약 치환 → exit 1" || note FAIL "T2: 요약 치환이 exit 1이 아님 (rc=$rc)"
# (동일 pipefail 회피 — 위 T1 주석 참조)
out="$(json_of "$FX/brief-verbatim-summarized.md" "$FX/state-verbatim-ok.md")"
grep -q '"not_contained": \["S2"\]' <<<"$out" \
  && note PASS "T2: not_contained에 S2" || note FAIL "T2: not_contained가 S2를 담지 않음"

# --- T2 mutation: 맨앞·중간·맨끝 3곳 절단이 모두 red ------------------------
for cut in head mid tail; do
  tmpb="$(mktemp)" || exit 1
  python3 - "$FX/brief-verbatim-ok.md" "$tmpb" "$cut" <<'PY'
import sys
src, dst, where = sys.argv[1], sys.argv[2], sys.argv[3]
t = open(src, encoding="utf-8").read()
old = '"3 에이전트 + codex, 계약별 분리"'
new = {"head": '"에이전트 + codex, 계약별 분리"',
       "mid":  '"3 에이전트 + 계약별 분리"',
       "tail": '"3 에이전트 + codex, 계약별"'}[where]
assert old in t, "fixture drift: 대상 문장을 찾지 못함"
open(dst, "w", encoding="utf-8").write(t.replace(old, new))
PY
  rc="$(rc_of "$tmpb" "$FX/state-verbatim-ok.md")"
  [[ "$rc" == "1" ]] && note PASS "T2 mutation($cut): 부분 절단 → exit 1" \
                     || note FAIL "T2 mutation($cut): 절단이 통과했다 (rc=$rc)"
  rm -f "$tmpb"
done

# --- T31(행위) N1↔N3 순서: 멀티라인 인용이 통과해야 한다 --------------------
rc="$(rc_of "$FX/brief-verbatim-multiline.md" "$FX/state-verbatim-multiline.md")"
[[ "$rc" == "0" ]] && note PASS "T31: 멀티라인 인용 → exit 0 (N1이 N3보다 먼저)" \
                   || note FAIL "T31: 멀티라인 인용이 red — N3가 N1보다 먼저 적용된 징후 (rc=$rc)"

# --- T31(행위) NFC: 전각/기호는 접히지 않는다 (NFKC면 잘못 통과) ------------
rc="$(rc_of "$FX/brief-verbatim-nfkc.md" "$FX/state-verbatim-nfkc.md")"
[[ "$rc" == "1" ]] && note PASS "T31: ①↔1 불일치 → exit 1 (NFC 유지)" \
                   || note FAIL "T31: ①↔1이 통과했다 — NFKC 징후 (rc=$rc)"

# --- T3 / AC11 : P21 placeholder 강등 (양쪽 모두 관여 — 서로 다른 구체 토큰) ---
rc="$(rc_of "$FX/brief-verbatim-placeholder.md" "$FX/state-verbatim-placeholder.md")"
[[ "$rc" == "0" ]] && note PASS "T3: placeholder 관여(양쪽) → advisory 강등 (exit 0)" \
                   || note FAIL "T3: placeholder 강등이 없다 (rc=$rc)"
json_of "$FX/brief-verbatim-placeholder.md" "$FX/state-verbatim-placeholder.md" | grep -q 'P21 placeholder' \
  && note PASS "T3: advisories에 P21 문구" || note FAIL "T3: advisories가 P21을 언급하지 않음"

# --- T3 / AC11 : P21 placeholder — state 쪽만 관여 --------------------------
rc="$(rc_of "$FX/brief-verbatim-placeholder-state-only.md" "$FX/state-verbatim-placeholder-state-only.md")"
[[ "$rc" == "0" ]] && note PASS "T3: placeholder 관여(state만) → advisory 강등 (exit 0)" \
                   || note FAIL "T3: state쪽 단독 placeholder가 강등되지 않는다 (rc=$rc)"

# --- T3 / AC11 : P21 placeholder — payload 쪽만 관여 (spec §5.5의 설계된 예외:
# payload가 P21 secret placeholder로 치환하는 것은 §6 append-only의 유일한 예외이며,
# state(ground truth, git-ignored)가 리터럴을 들고 있어도 payload가 그것을 redact해
# 보여주는 것은 정상 경로다 — 이 케이스가 비어 있으면 회귀가 락에 보이지 않는다) -----
rc="$(rc_of "$FX/brief-verbatim-placeholder-payload-only.md" "$FX/state-verbatim-placeholder-payload-only.md")"
[[ "$rc" == "0" ]] && note PASS "T3: placeholder 관여(payload만, §5.5 예외) → advisory 강등 (exit 0)" \
                   || note FAIL "T3: payload쪽 단독 placeholder(§5.5 예외)가 강등되지 않는다 — state의 리터럴이 정상적으로 차단된다 (rc=$rc)"
out="$(json_of "$FX/brief-verbatim-placeholder-payload-only.md" "$FX/state-verbatim-placeholder-payload-only.md")"
grep -q 'P21 placeholder' <<<"$out" \
  && note PASS "T3: payload쪽만 관여해도 advisories에 P21 문구" || note FAIL "T3: payload쪽만 관여 시 advisories가 P21을 언급하지 않음"

# --- T3 mutation: 양쪽 모두에서 placeholder 토큰 제거 → red 승격 ------------
# (state만 벗기면 payload의 bare <REDACTED>가 독자적으로 매치해 OR가 절대 red로
# 못 넘어간다 — 양쪽을 다 벗겨야 "제거하면 실제로 escalate한다"는 이빨이 성립한다.)
tmps="$(mktemp)" || exit 1
tmpb="$(mktemp)" || exit 1
sed 's/<REDACTED:api-key>/plainsecret/' "$FX/state-verbatim-placeholder.md" > "$tmps"
sed 's/<REDACTED>/unknown-value/' "$FX/brief-verbatim-placeholder.md" > "$tmpb"
rc="$(rc_of "$tmpb" "$tmps")"
[[ "$rc" == "1" ]] && note PASS "T3 mutation: 양쪽 토큰 제거 → advisory가 red로 승격" \
                   || note FAIL "T3 mutation: 양쪽에서 토큰을 제거해도 통과했다 (rc=$rc)"
rm -f "$tmps" "$tmpb"

# --- T4 · T19 / AC12 : exit 1 ≠ exit 3 -------------------------------------
rc3="$(rc_of "$FX/brief-verbatim-ok.md" "$FX/nonexistent-state-file.md")"
[[ "$rc3" == "3" ]] && note PASS "T4: state 부재 → exit 3" || note FAIL "T4: state 부재가 exit 3이 아님 (rc=$rc3)"
rc1="$(rc_of "$FX/brief-verbatim-summarized.md" "$FX/state-verbatim-ok.md")"
[[ "$rc1" != "$rc3" ]] && note PASS "T19: 위반($rc1) ≠ 검사불가($rc3)" \
                       || note FAIL "T19: 두 실패가 같은 코드다 — 호출자가 차단과 degrade를 구분 못 함"
[[ "$rc1" != "0" && "$rc3" != "0" ]] && note PASS "T19: 둘 다 non-zero" || note FAIL "T19: 실패가 0을 낸다"
# (동일 pipefail 회피 — 위 T1 주석 참조: 이 호출은 exit 3을 낸다)
out="$(python3 "$SCRIPT" "$FX/brief-verbatim-ok.md" "$FX/nonexistent-state-file.md" 2>/dev/null)"
grep -q '"advisories"' <<<"$out" \
  && note PASS "T4: 검사불가에도 JSON + advisory (조용한 통과 없음)" || note FAIL "T4: 검사불가에 advisory 없음"

# --- 빈 state 파일도 검사불가(3)로 --------------------------------------
tmpe="$(mktemp)" || exit 1; : > "$tmpe"
rc="$(rc_of "$FX/brief-verbatim-ok.md" "$tmpe")"
[[ "$rc" == "3" ]] && note PASS "T4: 빈 state → exit 3" || note FAIL "T4: 빈 state가 exit 3이 아님 (rc=$rc)"
rm -f "$tmpe"

# --- §6 섹션 부재 → 검사불가(3). 구조는 check_brief.py 소관 --------------
tmpn="$(mktemp)" || exit 1
awk '!/^## 6\./{print} /^## 6\./{skip=1} skip&&/^## 7\./{skip=0;print}' "$FX/brief-verbatim-ok.md" > "$tmpn"
rc="$(rc_of "$tmpn" "$FX/state-verbatim-ok.md")"
[[ "$rc" == "3" ]] && note PASS "§6 부재 → exit 3 (위반 아님)" || note FAIL "§6 부재가 exit 3이 아님 (rc=$rc)"
rm -f "$tmpn"

# --- T20 / AC12 : 예외 계약 — 미처리 예외는 4, 절대 1이 아니다 -------------
grep -q "except Exception" "$SCRIPT" \
  && note PASS "T20: main()에 top-level except Exception" || note FAIL "T20: top-level 예외 핸들러 부재"
tmpd="$(mktemp -d)" || exit 1
cat > "$tmpd/inject.py" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("cvc", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
def boom(*a, **k):
    raise RuntimeError("injected")
mod.run = boom
sys.exit(mod.main(["cvc", sys.argv[2], sys.argv[3]]))
PY
python3 "$tmpd/inject.py" "$SCRIPT" "$FX/brief-verbatim-ok.md" "$FX/state-verbatim-ok.md" >/dev/null 2>&1
rc=$?
[[ "$rc" == "4" ]] && note PASS "T20: 주입된 예외 → exit 4 (1이 아님)" \
                   || note FAIL "T20: 주입된 예외가 exit $rc — 예외가 '위반 발견'으로 오분류된다"
rm -rf "$tmpd"

# --- usage -----------------------------------------------------------------
python3 "$SCRIPT" >/dev/null 2>&1; rc=$?
[[ "$rc" != "0" && "$rc" != "1" ]] && note PASS "인자 부족 → non-zero이며 1이 아님 (rc=$rc)" \
                                   || note FAIL "usage 오류가 0 또는 1을 낸다 (rc=$rc)"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ "$fail" -eq 0 ]]
