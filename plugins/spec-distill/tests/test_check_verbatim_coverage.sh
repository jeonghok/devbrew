#!/usr/bin/env bash
# Spec B T1·T2·T3·T4·T19·T20·T31(행위) — check_verbatim_coverage.py.
# AC10(L1) · AC11(L2 + P21 강등 + N1–N5 순서 + NFC) · AC12(exit 1/3/4 분리 + 예외 계약) · AC14(부분)
# Run: bash plugins/spec-distill/tests/test_check_verbatim_coverage.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/check_verbatim_coverage.py"
FX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
rc_of() { python3 "$SCRIPT" "$1" "$2" >/dev/null 2>&1; echo $?; }
json_of() { python3 "$SCRIPT" "$1" "$2" 2>/dev/null; }

test -f "$SCRIPT" || { no "스크립트 부재: $SCRIPT"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }

# --- 정상 경로 -------------------------------------------------------------
[[ "$(rc_of "$FX/brief-verbatim-ok.md" "$FX/state-verbatim-ok.md")" == "0" ]] \
  && ok "정상 fixture → exit 0" || no "정상 fixture가 exit 0이 아님"

# --- T1 / AC10 : L1 ---------------------------------------------------------
rc="$(rc_of "$FX/brief-verbatim-missing-anchor.md" "$FX/state-verbatim-ok.md")"
[[ "$rc" == "1" ]] && ok "T1: S<N> 앵커 누락 → exit 1" || no "T1: 앵커 누락이 exit 1이 아님 (rc=$rc)"
# json_of의 스크립트는 위반 시 exit 1을 낸다; `set -o pipefail` 하에서 `cmd | grep` 형태로
# 바로 연결하면 파이프 전체 상태가 grep(성공)이 아니라 cmd(1)로 오염돼 항상 FAIL로 오분류된다.
# 변수 캡처 후 grep해 파이프를 피한다.
out="$(json_of "$FX/brief-verbatim-missing-anchor.md" "$FX/state-verbatim-ok.md")"
grep -q '"missing_ids": \["S2"\]' <<<"$out" \
  && ok "T1: missing_ids에 S2" || no "T1: missing_ids가 S2를 담지 않음"

# --- T2 / AC11·AC14 : L2 ----------------------------------------------------
rc="$(rc_of "$FX/brief-verbatim-summarized.md" "$FX/state-verbatim-ok.md")"
[[ "$rc" == "1" ]] && ok "T2: 요약 치환 → exit 1" || no "T2: 요약 치환이 exit 1이 아님 (rc=$rc)"
# (동일 pipefail 회피 — 위 T1 주석 참조)
out="$(json_of "$FX/brief-verbatim-summarized.md" "$FX/state-verbatim-ok.md")"
grep -q '"not_contained": \["S2"\]' <<<"$out" \
  && ok "T2: not_contained에 S2" || no "T2: not_contained가 S2를 담지 않음"

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
  [[ "$rc" == "1" ]] && ok "T2 mutation($cut): 부분 절단 → exit 1" \
                     || no "T2 mutation($cut): 절단이 통과했다 (rc=$rc)"
  rm -f "$tmpb"
done

# --- T31(행위) N1↔N3 순서: 멀티라인 인용이 통과해야 한다 --------------------
rc="$(rc_of "$FX/brief-verbatim-multiline.md" "$FX/state-verbatim-multiline.md")"
[[ "$rc" == "0" ]] && ok "T31: 멀티라인 인용 → exit 0 (N1이 N3보다 먼저)" \
                   || no "T31: 멀티라인 인용이 red — N3가 N1보다 먼저 적용된 징후 (rc=$rc)"

# --- T31(행위) NFC: 전각/기호는 접히지 않는다 (NFKC면 잘못 통과) ------------
rc="$(rc_of "$FX/brief-verbatim-nfkc.md" "$FX/state-verbatim-nfkc.md")"
[[ "$rc" == "1" ]] && ok "T31: ①↔1 불일치 → exit 1 (NFC 유지)" \
                   || no "T31: ①↔1이 통과했다 — NFKC 징후 (rc=$rc)"

# --- T3 / AC11 : P21 관여 시 판정 포기 (구 계약 'exit 0 강등'은 iter-2에서 폐기) ---
# 세 fixture(양쪽·state만·payload만)의 계약은 이제 C1 블록이 단독으로 집행한다.
# 여기서는 advisory 문구가 **어느 쪽 때문인지**를 말하는지만 본다(사용자가 Step B에서
# 원인을 구분할 수 있어야 한다).
for pair in placeholder placeholder-payload-only placeholder-state-only; do
  out="$(json_of "$FX/brief-verbatim-$pair.md" "$FX/state-verbatim-$pair.md")"
  grep -qE 'P21 placeholder 관여\((양쪽|state|payload)\)' <<<"$out" \
    && ok "T3($pair): advisory가 관여 측(양쪽/state/payload)을 지목" \
    || no "T3($pair): advisory가 어느 쪽 때문인지 말하지 않는다"
done

# --- T3 mutation: 양쪽 모두에서 placeholder 토큰 제거 → red 승격 ------------
# (state만 벗기면 payload의 bare <REDACTED>가 독자적으로 매치해 OR가 절대 red로
# 못 넘어간다 — 양쪽을 다 벗겨야 "제거하면 실제로 escalate한다"는 이빨이 성립한다.)
tmps="$(mktemp)" || exit 1
tmpb="$(mktemp)" || exit 1
sed 's/<REDACTED:api-key>/plainsecret/' "$FX/state-verbatim-placeholder.md" > "$tmps"
sed 's/<REDACTED>/unknown-value/' "$FX/brief-verbatim-placeholder.md" > "$tmpb"
rc="$(rc_of "$tmpb" "$tmps")"
[[ "$rc" == "1" ]] && ok "T3 mutation: 양쪽 토큰 제거 → advisory가 red로 승격" \
                   || no "T3 mutation: 양쪽에서 토큰을 제거해도 통과했다 (rc=$rc)"
rm -f "$tmps" "$tmpb"

# --- C2 : producer와 checker의 P21 토큰 집합이 실제로 같다 ------------------
# conducting-interview SKILL.md(producer)가 문서로 약속한 토큰 **전부**를
# check_verbatim_coverage.py(checker)의 정규식에 그대로 먹여본다. 문서에서 토큰을
# 긁어오므로 어느 쪽을 바꿔도 이 락이 발화한다(한쪽만 고치는 drift 방지). 리터럴을
# 테스트에 박아두면 producer가 바뀌어도 조용히 통과한다.
CI_SKILL="$REPO_ROOT/plugins/spec-distill/skills/conducting-interview/SKILL.md"
P21_LINES="$(grep -n 'REDACTED' "$CI_SKILL" | head -1 | cut -d: -f1)"
if [[ -n "$P21_LINES" ]]; then
  # P21 문단(해당 줄부터 4줄)에서 `<TOKEN>` / `<TOKEN:라벨>` 모양을 전부 뽑는다.
  TOKENS="$(sed -n "${P21_LINES},$((P21_LINES+3))p" "$CI_SKILL" \
            | grep -oE '<(REDACTED|SECRET|TOKEN|KEY|CREDENTIAL|PLACEHOLDER)(:[^ `>]*)?>' | sort -u)"
  n_tok="$(grep -c . <<<"$TOKENS" || true)"
  [[ "$n_tok" -ge 2 ]] \
    && ok "C2: producer 문서에서 P21 예시 토큰 ${n_tok}종을 추출" \
    || no "C2: producer 문서에서 토큰을 못 뽑았다 (${n_tok}종) — 이 락이 vacuous하다"
  unmatched=""
  while IFS= read -r tok; do
    [[ -z "$tok" ]] && continue
    TOK="$tok" python3 - "$SCRIPT" <<'PY' || unmatched="${unmatched} ${tok}"
import os, re, runpy, sys
mod = runpy.run_path(sys.argv[1])
sys.exit(0 if mod["P21_PLACEHOLDER_RE"].search(os.environ["TOK"]) else 1)
PY
  done <<<"$TOKENS"
  [[ -z "$unmatched" ]] \
    && ok "C2: producer가 약속한 토큰을 checker가 전부 인식 (한국어 라벨 포함)" \
    || no "C2: checker가 인식 못 하는 producer 토큰:${unmatched} — 정당한 치환이 red로 잡힌다"
else
  no "C2: conducting-interview SKILL.md에서 P21 줄을 찾지 못했다"
fi
# 경계는 넓히지 않았다 — 공백이 든 라벨(산문 위장)은 여전히 토큰이 아니다.
TOK='<REDACTED:이건 라벨이 아니라 문장이다>' python3 - "$SCRIPT" <<'PY' \
  && no "C2: 공백 포함 라벨이 토큰으로 인식됐다 — 산문으로 L2를 통째로 강등시킬 수 있다" \
  || ok "C2: 공백 포함 라벨은 토큰이 아니다 (경계 유지)"
import os, re, runpy, sys
mod = runpy.run_path(sys.argv[1])
sys.exit(0 if mod["P21_PLACEHOLDER_RE"].search(os.environ["TOK"]) else 1)
PY

# --- T4 · T19 / AC12 : exit 1 ≠ exit 3 -------------------------------------
rc3="$(rc_of "$FX/brief-verbatim-ok.md" "$FX/nonexistent-state-file.md")"
[[ "$rc3" == "3" ]] && ok "T4: state 부재 → exit 3" || no "T4: state 부재가 exit 3이 아님 (rc=$rc3)"
rc1="$(rc_of "$FX/brief-verbatim-summarized.md" "$FX/state-verbatim-ok.md")"
[[ "$rc1" != "$rc3" ]] && ok "T19: 위반($rc1) ≠ 검사불가($rc3)" \
                       || no "T19: 두 실패가 같은 코드다 — 호출자가 차단과 degrade를 구분 못 함"
[[ "$rc1" != "0" && "$rc3" != "0" ]] && ok "T19: 둘 다 non-zero" || no "T19: 실패가 0을 낸다"
# (동일 pipefail 회피 — 위 T1 주석 참조: 이 호출은 exit 3을 낸다)
out="$(python3 "$SCRIPT" "$FX/brief-verbatim-ok.md" "$FX/nonexistent-state-file.md" 2>/dev/null)"
grep -q '"advisories"' <<<"$out" \
  && ok "T4: 검사불가에도 JSON + advisory (조용한 통과 없음)" || no "T4: 검사불가에 advisory 없음"

# --- 빈 state 파일도 검사불가(3)로 --------------------------------------
tmpe="$(mktemp)" || exit 1; : > "$tmpe"
rc="$(rc_of "$FX/brief-verbatim-ok.md" "$tmpe")"
[[ "$rc" == "3" ]] && ok "T4: 빈 state → exit 3" || no "T4: 빈 state가 exit 3이 아님 (rc=$rc)"
rm -f "$tmpe"

# --- A2 : malformed state가 exit 0으로 새지 않는다 (indeterminate ≠ clean) ---
# 이 셋은 fix 전에 **전부 exit 0**이었다 — 그 statement가 payload §6과 한 번도 대조되지
# 않았는데 호출자는 0을 "위반 없음"으로 매핑했다. 각 케이스는 payload 쪽에 실제 왜곡
# (S1 본문이 state의 text와 완전히 다름)을 함께 심어, 검사가 *돌기만 했다면* exit 1이
# 났어야 하는 입력이다 — 그래야 "0이 아니다"가 아니라 "검사가 눈감았다"를 잡는다.
mal_payload="$(mktemp)" || exit 1
cat > "$mal_payload" <<'MALP'
---
type: interview-brief
---
## 6. 사용자 원문

- **S1** (출처: turn 1)
  > 원문과 완전히 다른 문장
MALP
# 세 케이스는 **서로 다른 단독 가드**가 책임진다(가드가 겹치면 어느 쪽을 지워도 green이라
# mutation으로 이빨을 증명할 수 없다 — 실측으로 확인하고 구조를 갈랐다):
#   no-id        → parse_user_statements의 `- id:` 아닌 리스트 항목 raise
#   missing-text → parse_user_statements의 text 키 부재 raise
#   empty-text / normalized-empty → run()의 `not want` indeterminate 분기
for case in missing-text no-id empty-text normalized-empty; do
  tmpm="$(mktemp)" || exit 1
  case "$case" in
    missing-text)     printf -- '---\nuser_statements:\n  - id: S1\n---\n' > "$tmpm" ;;
    no-id)            printf -- '---\nuser_statements:\n  - text: "대조되지 못한 발화"\n---\n' > "$tmpm" ;;
    empty-text)       printf -- '---\nuser_statements:\n  - id: S1\n    text: ""\n---\n' > "$tmpm" ;;
    normalized-empty) printf -- '---\nuser_statements:\n  - id: S1\n    text: "**"\n---\n' > "$tmpm" ;;
  esac
  rc="$(rc_of "$mal_payload" "$tmpm")"
  [[ "$rc" == "3" ]] && ok "A2($case): 판독 불가 원장 → exit 3 (검사불가)" \
                     || no "A2($case): exit 3이 아님 (rc=$rc) — 대조되지 않은 statement가 clean으로 집계된다"
  rm -f "$tmpm"
done
# 대칭 통제: 같은 payload에 **정상** 원장을 물리면 exit 1(진짜 위반)이 나야 한다.
# 이게 없으면 위 셋은 "무엇을 넣어도 3"이라는 이빨 없는 assert와 구별되지 않는다.
tmpok="$(mktemp)" || exit 1
printf -- '---\nuser_statements:\n  - id: S1\n    text: "원문 그대로의 문장"\n---\n' > "$tmpok"
rc="$(rc_of "$mal_payload" "$tmpok")"
[[ "$rc" == "1" ]] && ok "A2(통제): 정상 원장 + 같은 왜곡 payload → exit 1 (위반)" \
                   || no "A2(통제): 정상 원장이 exit 1을 내지 않는다 (rc=$rc) — 위 exit 3들이 무조건 3인 것과 구별 불가"
rm -f "$tmpok" "$mal_payload"

# --- §6 섹션 부재 → 검사불가(3). 구조는 check_brief.py 소관 --------------
tmpn="$(mktemp)" || exit 1
awk '!/^## 6\./{print} /^## 6\./{skip=1} skip&&/^## 7\./{skip=0;print}' "$FX/brief-verbatim-ok.md" > "$tmpn"
rc="$(rc_of "$tmpn" "$FX/state-verbatim-ok.md")"
[[ "$rc" == "3" ]] && ok "§6 부재 → exit 3 (위반 아님)" || no "§6 부재가 exit 3이 아님 (rc=$rc)"
rm -f "$tmpn"

# --- T20 / AC12 : 예외 계약 — 미처리 예외는 4, 절대 1이 아니다 -------------
grep -q "except Exception" "$SCRIPT" \
  && ok "T20: main()에 top-level except Exception" || no "T20: top-level 예외 핸들러 부재"
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
[[ "$rc" == "4" ]] && ok "T20: 주입된 예외 → exit 4 (1이 아님)" \
                   || no "T20: 주입된 예외가 exit $rc — 예외가 '위반 발견'으로 오분류된다"
rm -rf "$tmpd"

# === /qg 회귀 락 (C1·C2·C3) ==================================================
# C1은 iter-2 리뷰(리뷰어 4/4 CRITICAL) 후 **계약 자체를 바꿨다**. redaction 뒤에 무엇이
# 있었는지는 원리적으로 알 수 없으므로, 부분 매칭으로 통과/차단을 가르려는 시도는 어느
# 앵커를 걸어도 한쪽에서 샌다(누락 세탁 통과) 또는 다른 쪽을 잘못 막는다(정당한 superset
# payload 차단). 그래서 판정은 하나다:
#
#     **P21 placeholder가 어느 쪽에든 관여하면 검사 결과는 절대 rc 0이 아니다.**
#
# rc 3(검사 불가)은 SKILL rc 표에서 degradation record가 **의무**인 행이라 Step B 사용자에게
# 반드시 도달한다. 원래 CRITICAL의 본질은 "통과했다"가 아니라 "강등이 조용했다"였다.

# --- C1 : P21 관여 → 절대 clean이 아니다 ------------------------------------
for pair in placeholder placeholder-payload-only placeholder-state-only; do
  rc="$(rc_of "$FX/brief-verbatim-$pair.md" "$FX/state-verbatim-$pair.md")"
  [[ "$rc" == "3" ]] \
    && ok "C1($pair): P21 관여 → exit 3 (검사 불가, record 의무)" \
    || no "C1($pair): exit $rc — 0이면 조용한 통과, 1이면 정당한 redaction 오차단"
  out="$(json_of "$FX/brief-verbatim-$pair.md" "$FX/state-verbatim-$pair.md")"
  grep -q 'P21' <<<"$out" \
    && ok "C1($pair): advisory가 P21 관여를 명시" \
    || no "C1($pair): 어느 쪽 때문에 검사 불가인지 advisory에 없다"
done

# 세탁 시도(의미 반전 + 토큰) — 통과(0)해서는 안 된다.
rc="$(rc_of "$FX/brief-verbatim-p21-laundering.md" "$FX/state-verbatim-ok.md")"
[[ "$rc" != "0" ]] \
  && ok "C1 세탁(변조): exit $rc — clean이 아니다" \
  || no "C1 세탁(변조): exit 0 — 토큰 하나로 §6을 다시 써도 통과한다"

# **누락** 세탁 — iter-2가 적발한 경로. 한 단어만 남기고 나머지를 토큰으로 덮는다.
tmpo="$(mktemp)" || exit 1
sed 's|> "브리프에 리뷰를 붙이고 싶다"|> "브리프에 <REDACTED:rest>"|' \
    "$FX/brief-verbatim-ok.md" > "$tmpo"
rc="$(rc_of "$tmpo" "$FX/state-verbatim-ok.md")"
[[ "$rc" != "0" ]] \
  && ok "C1 세탁(누락): exit $rc — 원문 대부분을 토큰으로 지워도 clean이 아니다" \
  || no "C1 세탁(누락): exit 0 — 완전성 검사가 완전성을 검사하지 않는다"
rm -f "$tmpo"

# 본문이 통째로 placeholder — 대조할 리터럴이 0인데 clean이면 총체적 소거가 통과한다.
tmpw="$(mktemp)" || exit 1
sed 's|> "브리프에 리뷰를 붙이고 싶다"|> "<REDACTED:whole>"|' "$FX/brief-verbatim-ok.md" > "$tmpw"
rc="$(rc_of "$tmpw" "$FX/state-verbatim-ok.md")"
[[ "$rc" != "0" ]] \
  && ok "C1 총체 소거: exit $rc — 본문이 토큰뿐이어도 clean이 아니다" \
  || no "C1 총체 소거: exit 0 — 문장 전체를 지우고 통과한다"
rm -f "$tmpw"

# 정당한 superset payload(원문 + 맥락 주석) + 토큰 — **오차단하면 안 된다**(1이 아님).
tmps="$(mktemp)" || exit 1
sed 's|> "브리프에 리뷰를 붙이고 싶다"|> "브리프에 <REDACTED:x> 붙이고 싶다" (맥락: 1라운드)|' \
    "$FX/brief-verbatim-ok.md" > "$tmps"
rc="$(rc_of "$tmps" "$FX/state-verbatim-ok.md")"
[[ "$rc" != "1" ]] \
  && ok "C1 오차단 방지: 맥락이 덧붙은 payload가 위반으로 잡히지 않음 (exit $rc)" \
  || no "C1 오차단 방지: 정당한 superset payload를 위반으로 차단했다"
rm -f "$tmps"

# C1 mutation: P21 분기의 강등 플래그만 제거한다. (def rename은 NameError→exit 4를 내는데
# 그건 "세탁이 통과했다"가 아니라 "스크립트가 죽었다"이고, `!= 1` 같은 단방향 assert는 그것을
# 통과로 오독한다 — iter-2가 이 위양성을 적발했다. mutation은 **정확한 기대값**을 요구한다.)
tmpm="$(mktemp)" || exit 1
MUT_PY="$(mktemp)" || exit 1
cat > "$MUT_PY" <<'MUTEOF'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
t = open(src, encoding="utf-8").read()
i = t.find("P21 placeholder 관여({side})")
if i < 0:
    print("UNCHANGED"); sys.exit(0)
j = t.find("saw_indeterminate = True", i)
if j < 0:
    print("UNCHANGED"); sys.exit(0)
t2 = t[:j] + "pass  # mutated" + t[j + len("saw_indeterminate = True"):]
open(dst, "w", encoding="utf-8").write(t2)
print("MUTATED")
MUTEOF
mutres="$(python3 "$MUT_PY" "$SCRIPT" "$tmpm")"
if [[ "$mutres" == "MUTATED" ]]; then
  python3 "$tmpm" "$FX/brief-verbatim-placeholder-payload-only.md" \
                  "$FX/state-verbatim-placeholder-payload-only.md" >/dev/null 2>&1
  rcm=$?
  [[ "$rcm" == "0" ]] \
    && ok "C1 mutation: 강등 플래그 제거 → exit 0(조용한 통과) 재현, 락에 이빨 있음" \
    || no "C1 mutation: 플래그를 없애도 exit $rcm — 이 락은 다른 이유로 통과한다(4=크래시는 증명이 아니다)"
else
  no "C1 mutation: 치환 대상을 못 찾았다 ($mutres) — 락이 vacuous하다"
fi
rm -f "$tmpm" "$MUT_PY"

# --- C2 : §6 앵커 중복은 '검사 불가(3)'가 아니라 위반(1) --------------------
rc="$(rc_of "$FX/brief-verbatim-dup-anchor.md" "$FX/state-verbatim-ok.md")"
[[ "$rc" == "1" ]] \
  && ok "C2: §6 앵커 중복 → exit 1 (전 statement skip 아님)" \
  || no "C2: 앵커 중복이 exit $rc — 한 줄 중복으로 완전성 게이트 전체가 꺼진다"

# C2 순서: state가 판독 불가여도 payload의 구조 위반이 선점당하면 안 된다(iter-2 적발).
tmpb="$(mktemp)" || exit 1
grep -v 'user_statements:' "$FX/state-verbatim-ok.md" | grep -v '^- id:\|^  source:\|^  round:\|^  text:' > "$tmpb"
rc="$(rc_of "$FX/brief-verbatim-dup-anchor.md" "$tmpb")"
[[ "$rc" == "1" ]] \
  && ok "C2 순서: state 판독 실패가 구조 위반을 선점하지 않음" \
  || no "C2 순서: exit $rc — state에서 키 하나만 빼면 hard block이 soft continue로 되돌아간다"
rm -f "$tmpb"

# --- C3 : 확정 위반이 뒤 항목의 불확정에 밀려 강등되지 않는다 ---------------
rc="$(rc_of "$FX/brief-verbatim-mixed.md" "$FX/state-verbatim-mixed.md")"
[[ "$rc" == "1" ]] \
  && ok "C3: 위반(S1) + 불확정(S2) 혼합 → exit 1 (위반이 불확정보다 우선)" \
  || no "C3: 혼합 케이스가 exit $rc — 확정 위반이 강등돼 차단되지 않는다"
out="$(json_of "$FX/brief-verbatim-mixed.md" "$FX/state-verbatim-mixed.md")"
grep -q '"not_contained": \["S1"\]' <<<"$out" \
  && ok "C3: 강등 대신 S1 위반이 보존됨" || no "C3: S1 위반이 결과에서 사라졌다"
rc="$(rc_of "$FX/brief-verbatim-ok.md" "$FX/state-verbatim-mixed.md")"
[[ "$rc" == "3" ]] \
  && ok "C3 대칭: 불확정만 → 여전히 exit 3 (위반으로 과승격하지 않음)" \
  || no "C3 대칭: 불확정 단독이 exit $rc — 과승격은 정상 brief를 차단한다"

# --- C4(iter-2) : 빈 원장은 '전건 검증 완료'가 아니다 -----------------------
tmpe="$(mktemp)" || exit 1
printf -- '---\nsession_id: 11111111-1111-1111-1111-111111111111\nphase: 1\nuser_statements: []\n---\n\nbody\n' > "$tmpe"
rc="$(rc_of "$FX/brief-verbatim-ok.md" "$tmpe")"
[[ "$rc" == "3" ]] \
  && ok "C4: user_statements 0건 → exit 3 (빈 전칭명제는 clean이 아니다)" \
  || no "C4: 빈 원장이 exit $rc — 원장을 비우는 것만으로 L1·L2가 조용히 우회된다"
rm -f "$tmpe"

# --- usage -----------------------------------------------------------------
python3 "$SCRIPT" >/dev/null 2>&1; rc=$?
[[ "$rc" != "0" && "$rc" != "1" ]] && ok "인자 부족 → non-zero이며 1이 아님 (rc=$rc)" \
                                   || no "usage 오류가 0 또는 1을 낸다 (rc=$rc)"
finish
