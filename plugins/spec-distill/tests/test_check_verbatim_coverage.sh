#!/usr/bin/env bash
# Spec B T1·T2·T3·T4·T19·T20·T31(행위) — check_verbatim_coverage.py.
# AC10(L1) · AC11(L2 + P21 강등 + N1–N5 순서 + NFC) · AC12(exit 1/3/4 분리 + 예외 계약) · AC14(부분)
# R2 — payload §6 이 S1~Sn 원문 전량이고 audit §6 은 S2 이상의 같은 글자 사본이다. 스크립트는
# 3인자(payload state audit)를 받는다 — L1 은 payload 앵커를, 같은 앵커의 글자 대조는 합집합을
# 본다. rc_of/json_of도 3인자다.
# Run: bash plugins/spec-distill/tests/test_check_verbatim_coverage.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/check_verbatim_coverage.py"
FX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
rc_of() { python3 "$SCRIPT" "$1" "$2" "$3" >/dev/null 2>&1; echo $?; }
json_of() { python3 "$SCRIPT" "$1" "$2" "$3" 2>/dev/null; }

test -f "$SCRIPT" || { no "스크립트 부재: $SCRIPT"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }

# --- 정상 경로 -------------------------------------------------------------
[[ "$(rc_of "$FX/brief-verbatim-ok.md" "$FX/state-verbatim-ok.md" "$FX/brief-verbatim-ok.audit.md")" == "0" ]] \
  && ok "정상 fixture → exit 0" || no "정상 fixture가 exit 0이 아님"

# --- T1 / AC10 : L1 ---------------------------------------------------------
rc="$(rc_of "$FX/brief-verbatim-missing-anchor.md" "$FX/state-verbatim-ok.md" "$FX/brief-verbatim-missing-anchor.audit.md")"
[[ "$rc" == "1" ]] && ok "T1: S<N> 앵커 누락 → exit 1" || no "T1: 앵커 누락이 exit 1이 아님 (rc=$rc)"
# json_of의 스크립트는 위반 시 exit 1을 낸다; `set -o pipefail` 하에서 `cmd | grep` 형태로
# 바로 연결하면 파이프 전체 상태가 grep(성공)이 아니라 cmd(1)로 오염돼 항상 FAIL로 오분류된다.
# 변수 캡처 후 grep해 파이프를 피한다.
out="$(json_of "$FX/brief-verbatim-missing-anchor.md" "$FX/state-verbatim-ok.md" "$FX/brief-verbatim-missing-anchor.audit.md")"
grep -q '"missing_ids": \["S2"\]' <<<"$out" \
  && ok "T1: missing_ids에 S2" || no "T1: missing_ids가 S2를 담지 않음"

# --- T2 / AC11·AC14 : L2 ----------------------------------------------------
rc="$(rc_of "$FX/brief-verbatim-summarized.md" "$FX/state-verbatim-ok.md" "$FX/brief-verbatim-summarized.audit.md")"
[[ "$rc" == "1" ]] && ok "T2: 요약 치환 → exit 1" || no "T2: 요약 치환이 exit 1이 아님 (rc=$rc)"
# (동일 pipefail 회피 — 위 T1 주석 참조)
out="$(json_of "$FX/brief-verbatim-summarized.md" "$FX/state-verbatim-ok.md" "$FX/brief-verbatim-summarized.audit.md")"
grep -q '"not_contained": \["S2"\]' <<<"$out" \
  && ok "T2: not_contained에 S2" || no "T2: not_contained가 S2를 담지 않음"

# --- T2 mutation: 맨앞·중간·맨끝 3곳 절단이 모두 red (L2) ----------------------
# S2 본문은 payload §6 과 audit §6 에 같은 글자로 있다(R2). 한쪽만 자르면 「같은 앵커 · 다른 글자」
# 구조 위반으로 red 가 나 L2 가 재지지 않는다 — 그래서 **양쪽 사본을 같이** 자르고, 원인이
# L2(not_contained S2)인지까지 본다.
for cut in head mid tail; do
  tmpd_cut="$(mktemp -d)" || exit 1
  python3 -I -X utf8 - "$FX/brief-verbatim-ok.md" "$FX/brief-verbatim-ok.audit.md" "$tmpd_cut" "$cut" <<'PY'
import sys, pathlib
pay, aud, dst, where = sys.argv[1], sys.argv[2], pathlib.Path(sys.argv[3]), sys.argv[4]
old = '"3 에이전트 + codex, 계약별 분리"'
new = {"head": '"에이전트 + codex, 계약별 분리"',
       "mid":  '"3 에이전트 + 계약별 분리"',
       "tail": '"3 에이전트 + codex, 계약별"'}[where]
for src, name in ((pay, "p.md"), (aud, "p.audit.md")):
    t = open(src, encoding="utf-8").read()
    assert old in t, "fixture drift: 대상 문장을 찾지 못함 — " + src
    (dst / name).write_text(t.replace(old, new), encoding="utf-8")
PY
  rc="$(rc_of "$tmpd_cut/p.md" "$FX/state-verbatim-ok.md" "$tmpd_cut/p.audit.md")"
  out="$(json_of "$tmpd_cut/p.md" "$FX/state-verbatim-ok.md" "$tmpd_cut/p.audit.md")"
  { [[ "$rc" == "1" ]] && grep -q '"not_contained": \["S2"\]' <<<"$out"; } \
    && ok "T2 mutation($cut): 부분 절단(양쪽 사본의 S2) → exit 1 · not_contained S2" \
    || no "T2 mutation($cut): 절단이 L2 로 잡히지 않았다 (rc=$rc $out)"
  rm -rf "$tmpd_cut"
done

# --- T31(행위) N1↔N3 순서: 멀티라인 인용이 통과해야 한다 --------------------
rc="$(rc_of "$FX/brief-verbatim-multiline.md" "$FX/state-verbatim-multiline.md" "$FX/brief-verbatim-multiline.audit.md")"
[[ "$rc" == "0" ]] && ok "T31: 멀티라인 인용 → exit 0 (N1이 N3보다 먼저)" \
                   || no "T31: 멀티라인 인용이 red — N3가 N1보다 먼저 적용된 징후 (rc=$rc)"

# --- T31(행위) NFC: 전각/기호는 접히지 않는다 (NFKC면 잘못 통과) ------------
rc="$(rc_of "$FX/brief-verbatim-nfkc.md" "$FX/state-verbatim-nfkc.md" "$FX/brief-verbatim-nfkc.audit.md")"
[[ "$rc" == "1" ]] && ok "T31: ①↔1 불일치 → exit 1 (NFC 유지)" \
                   || no "T31: ①↔1이 통과했다 — NFKC 징후 (rc=$rc)"

# --- T3 / AC11 : P21 관여 시 판정 포기 (구 계약 'exit 0 강등'은 iter-2에서 폐기) ---
# 세 fixture(양쪽·state만·payload만)의 계약은 이제 C1 블록이 단독으로 집행한다.
# 여기서는 advisory 문구가 **어느 쪽 때문인지**를 말하는지만 본다(사용자가 Step B에서
# 원인을 구분할 수 있어야 한다).
for pair in placeholder placeholder-payload-only placeholder-state-only; do
  out="$(json_of "$FX/brief-verbatim-$pair.md" "$FX/state-verbatim-$pair.md" "$FX/brief-verbatim-$pair.audit.md")"
  grep -qE 'P21 placeholder 관여\((양쪽|state|payload)\)' <<<"$out" \
    && ok "T3($pair): advisory가 관여 측(양쪽/state/payload)을 지목" \
    || no "T3($pair): advisory가 어느 쪽 때문인지 말하지 않는다"
done

# --- T3 mutation: 양쪽 모두에서 placeholder 토큰 제거 → red 승격 ------------
# (state만 벗기면 payload의 bare <REDACTED>가 독자적으로 매치해 OR가 절대 red로
# 못 넘어간다 — 양쪽을 다 벗겨야 "제거하면 실제로 escalate한다"는 이빨이 성립한다.)
# S1은 payload에 그대로 있으므로(v0.43.0에도 옮겨가지 않음) payload 쪽 mutation은 그대로다.
tmps="$(mktemp)" || exit 1
tmpb="$(mktemp)" || exit 1
sed 's/<REDACTED:api-key>/plainsecret/' "$FX/state-verbatim-placeholder.md" > "$tmps"
sed 's/<REDACTED>/unknown-value/' "$FX/brief-verbatim-placeholder.md" > "$tmpb"
rc="$(rc_of "$tmpb" "$tmps" "$FX/brief-verbatim-placeholder.audit.md")"
[[ "$rc" == "1" ]] && ok "T3 mutation: 양쪽 토큰 제거 → advisory가 red로 승격" \
                   || no "T3 mutation: 양쪽에서 토큰을 제거해도 통과했다 (rc=$rc)"
rm -f "$tmps" "$tmpb"

# --- C2 : producer와 checker의 P21 토큰 집합이 실제로 같다 ------------------
# pm-interview SKILL.md(producer)가 문서로 약속한 토큰 **전부**를
# check_verbatim_coverage.py(checker)의 정규식에 그대로 먹여본다. 문서에서 토큰을
# 긁어오므로 어느 쪽을 바꿔도 이 락이 발화한다(한쪽만 고치는 drift 방지). 리터럴을
# 테스트에 박아두면 producer가 바뀌어도 조용히 통과한다.
CI_SKILL="$REPO_ROOT/plugins/spec-distill/skills/pm-interview/SKILL.md"
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
  no "C2: pm-interview SKILL.md에서 P21 줄을 찾지 못했다"
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
rc3="$(rc_of "$FX/brief-verbatim-ok.md" "$FX/nonexistent-state-file.md" "$FX/brief-verbatim-ok.audit.md")"
[[ "$rc3" == "3" ]] && ok "T4: state 부재 → exit 3" || no "T4: state 부재가 exit 3이 아님 (rc=$rc3)"
rc1="$(rc_of "$FX/brief-verbatim-summarized.md" "$FX/state-verbatim-ok.md" "$FX/brief-verbatim-summarized.audit.md")"
[[ "$rc1" != "$rc3" ]] && ok "T19: 위반($rc1) ≠ 검사불가($rc3)" \
                       || no "T19: 두 실패가 같은 코드다 — 호출자가 차단과 degrade를 구분 못 함"
[[ "$rc1" != "0" && "$rc3" != "0" ]] && ok "T19: 둘 다 non-zero" || no "T19: 실패가 0을 낸다"
# (동일 pipefail 회피 — 위 T1 주석 참조: 이 호출은 exit 3을 낸다)
out="$(python3 "$SCRIPT" "$FX/brief-verbatim-ok.md" "$FX/nonexistent-state-file.md" "$FX/brief-verbatim-ok.audit.md" 2>/dev/null)"
grep -q '"advisories"' <<<"$out" \
  && ok "T4: 검사불가에도 JSON + advisory (조용한 통과 없음)" || no "T4: 검사불가에 advisory 없음"

# --- 빈 state 파일도 검사불가(3)로 --------------------------------------
tmpe="$(mktemp)" || exit 1; : > "$tmpe"
rc="$(rc_of "$FX/brief-verbatim-ok.md" "$tmpe" "$FX/brief-verbatim-ok.audit.md")"
[[ "$rc" == "3" ]] && ok "T4: 빈 state → exit 3" || no "T4: 빈 state가 exit 3이 아님 (rc=$rc)"
rm -f "$tmpe"

# --- A2 : malformed state가 exit 0으로 새지 않는다 (indeterminate ≠ clean) ---
# 이 셋은 fix 전에 **전부 exit 0**이었다 — 그 statement가 payload §6과 한 번도 대조되지
# 않았는데 호출자는 0을 "위반 없음"으로 매핑했다. 각 케이스는 payload 쪽에 실제 왜곡
# (S1 본문이 state의 text와 완전히 다름)을 함께 심어, 검사가 *돌기만 했다면* exit 1이
# 났어야 하는 입력이다 — 그래야 "0이 아니다"가 아니라 "검사가 눈감았다"를 잡는다.
# audit 인자는 §6 항목이 없는 placeholder.audit.md(`(없음)`)로 채운다 — R2 부터 audit 에만 있는
# 앵커는 payload 쪽 누락(missing_ids)이라, S2 를 가진 audit 을 물리면 그 위반이 이 케이스들의 exit 3 을 가린다.
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
  rc="$(rc_of "$mal_payload" "$tmpm" "$FX/brief-verbatim-placeholder.audit.md")"
  [[ "$rc" == "3" ]] && ok "A2($case): 판독 불가 원장 → exit 3 (검사불가)" \
                     || no "A2($case): exit 3이 아님 (rc=$rc) — 대조되지 않은 statement가 clean으로 집계된다"
  rm -f "$tmpm"
done
# 대칭 통제: 같은 payload에 **정상** 원장을 물리면 exit 1(진짜 위반)이 나야 한다.
# 이게 없으면 위 셋은 "무엇을 넣어도 3"이라는 이빨 없는 assert와 구별되지 않는다.
tmpok="$(mktemp)" || exit 1
printf -- '---\nuser_statements:\n  - id: S1\n    text: "원문 그대로의 문장"\n---\n' > "$tmpok"
rc="$(rc_of "$mal_payload" "$tmpok" "$FX/brief-verbatim-placeholder.audit.md")"
[[ "$rc" == "1" ]] && ok "A2(통제): 정상 원장 + 같은 왜곡 payload → exit 1 (위반)" \
                   || no "A2(통제): 정상 원장이 exit 1을 내지 않는다 (rc=$rc) — 위 exit 3들이 무조건 3인 것과 구별 불가"
rm -f "$tmpok" "$mal_payload"

# --- §6 섹션 부재 → 검사불가(3). 구조는 check_brief.py 소관 --------------
tmpn="$(mktemp)" || exit 1
awk '!/^## 6\./{print} /^## 6\./{skip=1} skip&&/^## 7\./{skip=0;print}' "$FX/brief-verbatim-ok.md" > "$tmpn"
rc="$(rc_of "$tmpn" "$FX/state-verbatim-ok.md" "$FX/brief-verbatim-ok.audit.md")"
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
sys.exit(mod.main(["cvc", sys.argv[2], sys.argv[3], sys.argv[4]]))
PY
python3 "$tmpd/inject.py" "$SCRIPT" "$FX/brief-verbatim-ok.md" "$FX/state-verbatim-ok.md" "$FX/brief-verbatim-ok.audit.md" >/dev/null 2>&1
rc=$?
[[ "$rc" == "4" ]] && ok "T20: 주입된 예외 → exit 4 (1이 아님)" \
                   || no "T20: 주입된 예외가 exit $rc — 예외가 '위반 발견'으로 오분류된다"
rm -rf "$tmpd"

# === qg 회귀 락 (C1·C2·C3) ==================================================
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
  rc="$(rc_of "$FX/brief-verbatim-$pair.md" "$FX/state-verbatim-$pair.md" "$FX/brief-verbatim-$pair.audit.md")"
  [[ "$rc" == "3" ]] \
    && ok "C1($pair): P21 관여 → exit 3 (검사 불가, record 의무)" \
    || no "C1($pair): exit $rc — 0이면 조용한 통과, 1이면 정당한 redaction 오차단"
  out="$(json_of "$FX/brief-verbatim-$pair.md" "$FX/state-verbatim-$pair.md" "$FX/brief-verbatim-$pair.audit.md")"
  grep -q 'P21' <<<"$out" \
    && ok "C1($pair): advisory가 P21 관여를 명시" \
    || no "C1($pair): 어느 쪽 때문에 검사 불가인지 advisory에 없다"
done

# 세탁 시도(의미 반전 + 토큰) — 통과(0)해서는 안 된다.
rc="$(rc_of "$FX/brief-verbatim-p21-laundering.md" "$FX/state-verbatim-ok.md" "$FX/brief-verbatim-p21-laundering.audit.md")"
[[ "$rc" != "0" ]] \
  && ok "C1 세탁(변조): exit $rc — clean이 아니다" \
  || no "C1 세탁(변조): exit 0 — 토큰 하나로 §6을 다시 써도 통과한다"

# **누락** 세탁 — iter-2가 적발한 경로. 한 단어만 남기고 나머지를 토큰으로 덮는다.
# S1은 payload에 그대로 있으므로 대상 문장은 여전히 payload 안에서 찾는다.
tmpo="$(mktemp)" || exit 1
sed 's|> "브리프에 리뷰를 붙이고 싶다"|> "브리프에 <REDACTED:rest>"|' \
    "$FX/brief-verbatim-ok.md" > "$tmpo"
rc="$(rc_of "$tmpo" "$FX/state-verbatim-ok.md" "$FX/brief-verbatim-ok.audit.md")"
[[ "$rc" != "0" ]] \
  && ok "C1 세탁(누락): exit $rc — 원문 대부분을 토큰으로 지워도 clean이 아니다" \
  || no "C1 세탁(누락): exit 0 — 완전성 검사가 완전성을 검사하지 않는다"
rm -f "$tmpo"

# 본문이 통째로 placeholder — 대조할 리터럴이 0인데 clean이면 총체적 소거가 통과한다.
tmpw="$(mktemp)" || exit 1
sed 's|> "브리프에 리뷰를 붙이고 싶다"|> "<REDACTED:whole>"|' "$FX/brief-verbatim-ok.md" > "$tmpw"
rc="$(rc_of "$tmpw" "$FX/state-verbatim-ok.md" "$FX/brief-verbatim-ok.audit.md")"
[[ "$rc" != "0" ]] \
  && ok "C1 총체 소거: exit $rc — 본문이 토큰뿐이어도 clean이 아니다" \
  || no "C1 총체 소거: exit 0 — 문장 전체를 지우고 통과한다"
rm -f "$tmpw"

# 정당한 superset payload(원문 + 맥락 주석) + 토큰 — **오차단하면 안 된다**(1이 아님).
tmps="$(mktemp)" || exit 1
sed 's|> "브리프에 리뷰를 붙이고 싶다"|> "브리프에 <REDACTED:x> 붙이고 싶다" (맥락: 1라운드)|' \
    "$FX/brief-verbatim-ok.md" > "$tmps"
rc="$(rc_of "$tmps" "$FX/state-verbatim-ok.md" "$FX/brief-verbatim-ok.audit.md")"
[[ "$rc" != "1" ]] \
  && ok "C1 오차단 방지: 맥락이 덧붙은 payload가 위반으로 잡히지 않음 (exit $rc)" \
  || no "C1 오차단 방지: 정당한 superset payload를 위반으로 차단했다"
rm -f "$tmps"

# C1 mutation: P21 분기의 강등 플래그만 제거한다. (def rename은 NameError→exit 4를 내는데
# 그건 "세탁이 통과했다"가 아니라 "스크립트가 죽었다"이고, `!= 1` 같은 단방향 assert는 그것을
# 통과로 오독한다 — iter-2가 이 위양성을 적발했다. mutation은 **정확한 기대값**을 요구한다.)
# 변이본은 **디렉토리**에 세우고 sibling(`section6.py` · `brief_body.py` · `check_brief.py` 와 그것이 쓰는 `skepticism.py`)을 함께 옮긴다. v0.47.0 부터 §6 경계는
# `scripts/section6.py` 한 곳이고, 이 스크립트는 그것을 형제 모듈로 import 한다 — 파일 하나만
# 떼어 /tmp 에 두고 돌리면 `ModuleNotFoundError` 로 죽어 rc 1 이 나고, 그 1 은 「세탁이
# 차단됐다」가 아니라 「스크립트가 죽었다」다(아래 단언이 요구하는 정확한 기대값 0 과 다르므로
# 이 위양성은 red 로 드러났다 — 단방향 assert 였다면 조용히 통과했을 자리).
MUTD="$(mktemp -d)" || exit 1
tmpm="$MUTD/check_verbatim_coverage.py"
for sib in section6 brief_body check_brief skepticism; do cp "$(dirname "$SCRIPT")/$sib.py" "$MUTD/"; done
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
                  "$FX/state-verbatim-placeholder-payload-only.md" \
                  "$FX/brief-verbatim-placeholder-payload-only.audit.md" >/dev/null 2>&1
  rcm=$?
  [[ "$rcm" == "0" ]] \
    && ok "C1 mutation: 강등 플래그 제거 → exit 0(조용한 통과) 재현, 락에 이빨 있음" \
    || no "C1 mutation: 플래그를 없애도 exit $rcm — 이 락은 다른 이유로 통과한다(4=크래시는 증명이 아니다)"
else
  no "C1 mutation: 치환 대상을 못 찾았다 ($mutres) — 락이 vacuous하다"
fi
rm -rf "$MUTD"; rm -f "$MUT_PY"

# --- C2 : §6 앵커 중복은 '검사 불가(3)'가 아니라 위반(1) --------------------
rc="$(rc_of "$FX/brief-verbatim-dup-anchor.md" "$FX/state-verbatim-ok.md" "$FX/brief-verbatim-dup-anchor.audit.md")"
[[ "$rc" == "1" ]] \
  && ok "C2: §6 앵커 중복 → exit 1 (전 statement skip 아님)" \
  || no "C2: 앵커 중복이 exit $rc — 한 줄 중복으로 완전성 게이트 전체가 꺼진다"

# C2 순서: state가 판독 불가여도 payload의 구조 위반이 선점당하면 안 된다(iter-2 적발).
tmpb="$(mktemp)" || exit 1
grep -v 'user_statements:' "$FX/state-verbatim-ok.md" | grep -v '^- id:\|^  source:\|^  round:\|^  text:' > "$tmpb"
rc="$(rc_of "$FX/brief-verbatim-dup-anchor.md" "$tmpb" "$FX/brief-verbatim-dup-anchor.audit.md")"
[[ "$rc" == "1" ]] \
  && ok "C2 순서: state 판독 실패가 구조 위반을 선점하지 않음" \
  || no "C2 순서: exit $rc — state에서 키 하나만 빼면 hard block이 soft continue로 되돌아간다"
rm -f "$tmpb"

# --- U2-T4: 코퍼스 합집합 --------------------------------------------------
# payload §6 이 원문 전량, audit §6 은 S2 이상의 같은 글자 사본(R2).
python3 "$SCRIPT" "$FX/brief-verbatim-ok.md" "$FX/state-verbatim-ok.md" \
      "$FX/brief-verbatim-ok.audit.md" >/dev/null 2>&1; rc=$?
[[ "$rc" == "0" ]] && ok "U2-T4: 합집합 정상 경로 exit 0" || no "U2-T4: 합집합 정상 경로가 exit $rc"

# audit 을 안 주면 usage — 유추하지 않는다
python3 "$SCRIPT" "$FX/brief-verbatim-ok.md" "$FX/state-verbatim-ok.md" >/dev/null 2>&1; rc=$?
[[ "$rc" == "64" ]] && ok "U2-T4: audit 인자 없으면 usage(64) — stem 유추 없음" \
  || no "U2-T4: 2인자 호출이 exit $rc — 유추로 audit 을 찾고 있는가"

# 같은 앵커 · 다른 글자 → 구조 위반 exit 1 (이미 있는 원문 글자를 한쪽에서 고친 모양)
out="$(python3 "$SCRIPT" "$FX/brief-verbatim-dup-across.md" "$FX/state-verbatim-ok.md" \
      "$FX/brief-verbatim-dup-across.audit.md" 2>&1)"; rc=$?
{ [[ "$rc" == "1" ]] && grep -q 'S5 앵커의 글자가' <<<"$out"; } \
  && ok "U2-T4: S5 가 payload·audit 에 다른 글자 → exit 1 (같은 앵커 글자 대조)" \
  || no "U2-T4: 같은 앵커 · 다른 글자가 exit $rc — 집행이 합집합 위에서 안 돈다: $out"
# 같은 앵커 · 같은 글자 → 통과 (payload §6 이 전량이고 audit 은 사본이다)
grep -q '^- \*\*S2\*\*' "$FX/brief-verbatim-ok.md" && grep -q '^- \*\*S2\*\*' "$FX/brief-verbatim-ok.audit.md" \
  && ok "U2-T4(전제): 정상 쌍의 S2 가 payload · audit 양쪽에 있다" \
  || no "U2-T4(전제): 정상 쌍의 S2 가 한쪽에만 있다 — 아래 통과 단언이 공허하다"
rc="$(rc_of "$FX/brief-verbatim-ok.md" "$FX/state-verbatim-ok.md" "$FX/brief-verbatim-ok.audit.md")"
[[ "$rc" == "0" ]] && ok "U2-T4: S2 가 payload·audit 에 같은 글자 → exit 0 (겹침 허용)" \
  || no "U2-T4: 같은 앵커 · 같은 글자가 exit $rc — 사본 겹침을 위반으로 거절한다"
# payload 쪽 누락 — audit · state 에 있는 앵커가 payload §6 에 없으면 위반
out="$(json_of "$FX/brief-verbatim-missing-anchor.md" "$FX/state-verbatim-ok.md" "$FX/brief-verbatim-ok.audit.md")"
grep -q '"missing_ids": \["S2"\]' <<<"$out" \
  && ok "U2-T4: audit §6 에 있는 S2 가 payload §6 에 없으면 missing_ids S2 (payload 쪽 누락)" \
  || no "U2-T4: payload 쪽 누락이 안 잡힌다: $out"
# audit 에만 있고 state 는 모르는 앵커도 payload 쪽 누락이다
tmpst="$(mktemp)" || exit 1
printf -- '---\nuser_statements:\n- id: S1\n  text: "브리프에 리뷰를 붙이고 싶다"\n---\n' > "$tmpst"
out="$(json_of "$FX/brief-verbatim-missing-anchor.md" "$tmpst" "$FX/brief-verbatim-ok.audit.md")"
grep -q '"missing_ids": \["S2"\]' <<<"$out" \
  && ok "U2-T4: state 가 모르는 audit-only S2 도 missing_ids (L1 의 audit 쪽)" \
  || no "U2-T4: audit 에만 있는 앵커가 안 잡힌다: $out"
rm -f "$tmpst"

# 한쪽 절 부재는 조용한 코퍼스 축소가 아니다
python3 "$SCRIPT" "$FX/brief-verbatim-ok.md" "$FX/state-verbatim-ok.md" \
      "$FX/brief-verbatim-audit-no-sec6.audit.md" >/dev/null 2>&1; rc=$?
[[ "$rc" == "3" ]] && ok "U2-T4: audit §6 부재 → exit 3 (검사 불가, 조용한 통과 아님)" \
  || no "U2-T4: audit §6 이 없는데 exit $rc — 축소된 코퍼스로 '완전성 통과'를 냈는가"

# --- C3 : 확정 위반이 뒤 항목의 불확정에 밀려 강등되지 않는다 ---------------
rc="$(rc_of "$FX/brief-verbatim-mixed.md" "$FX/state-verbatim-mixed.md" "$FX/brief-verbatim-mixed.audit.md")"
[[ "$rc" == "1" ]] \
  && ok "C3: 위반(S1) + 불확정(S2) 혼합 → exit 1 (위반이 불확정보다 우선)" \
  || no "C3: 혼합 케이스가 exit $rc — 확정 위반이 강등돼 차단되지 않는다"
out="$(json_of "$FX/brief-verbatim-mixed.md" "$FX/state-verbatim-mixed.md" "$FX/brief-verbatim-mixed.audit.md")"
grep -q '"not_contained": \["S1"\]' <<<"$out" \
  && ok "C3: 강등 대신 S1 위반이 보존됨" || no "C3: S1 위반이 결과에서 사라졌다"
rc="$(rc_of "$FX/brief-verbatim-ok.md" "$FX/state-verbatim-mixed.md" "$FX/brief-verbatim-ok.audit.md")"
[[ "$rc" == "3" ]] \
  && ok "C3 대칭: 불확정만 → 여전히 exit 3 (위반으로 과승격하지 않음)" \
  || no "C3 대칭: 불확정 단독이 exit $rc — 과승격은 정상 brief를 차단한다"

# --- C4(iter-2) : 빈 원장은 '전건 검증 완료'가 아니다 -----------------------
tmpe="$(mktemp)" || exit 1
printf -- '---\nsession_id: 11111111-1111-1111-1111-111111111111\nphase: 1\nuser_statements: []\n---\n\nbody\n' > "$tmpe"
rc="$(rc_of "$FX/brief-verbatim-ok.md" "$tmpe" "$FX/brief-verbatim-ok.audit.md")"
[[ "$rc" == "3" ]] \
  && ok "C4: user_statements 0건 → exit 3 (빈 전칭명제는 clean이 아니다)" \
  || no "C4: 빈 원장이 exit $rc — 원장을 비우는 것만으로 L1·L2가 조용히 우회된다"
rm -f "$tmpe"

# --- C5(Task 7 fix round 2) : 최초 요청 원문(S1) 예약 — 원문 있는 정상 케이스가
# end-to-end로 clean임을 실제 스크립트로 고정한다. finishing.md는 원문을 §6 앞에 S1로
# 예약하고 SKILL.md `사용자 발화 기록`의 id 공식은 그 예약을 반영해 오프셋 +1을 적용한다
# (원문 있으면 user_statements가 S2부터 시작). payload에는 원문(S1)이 있지만 state의
# `user_statements`에는 없다(원문은 매 round 사용자 발화가 아니므로 append 대상이 아니다)
# — 그래서 이 스크립트는 원문 자체를 판정하지 않고, state가 실제로 아는 S2·S3만 대조한다.
# R2: S1~S3 전부 payload §6 에 있고, audit §6 은 S2·S3 를 같은 글자로 겹쳐 가진다.
rc="$(rc_of "$FX/brief-verbatim-original-request.md" "$FX/state-verbatim-original-request.md" "$FX/brief-verbatim-original-request.audit.md")"
[[ "$rc" == "0" ]] \
  && ok "C5: 원문 있음 + 오프셋 적용(S2부터) → exit 0 (S1 예약과 정합)" \
  || no "C5: 원문 있는 정상 케이스가 exit $rc — 오프셋 없이는 이 케이스가 clean이 아니다"

# C5 회귀: 오프셋을 적용하지 않은(고치기 전) state — 첫 실제 답변이 S1을 자칭하면
# payload의 S1(원문)과 대조돼 not_contained, 그 뒤로 밀린 S2도 함께 어긋난다. 이 fixture는
# Task 7 fix round 1에서 스크래치로 1회 실행하고 지운 시나리오 B를 영구 회귀로 고정한다.
rc="$(rc_of "$FX/brief-verbatim-original-request.md" "$FX/state-verbatim-original-request-old-formula.md" "$FX/brief-verbatim-original-request.audit.md")"
[[ "$rc" == "1" ]] \
  && ok "C5 회귀: 오프셋 없는 옛 공식(첫 답변=S1) → exit 1 (S1은 원문 텍스트라 불일치)" \
  || no "C5 회귀: 오프셋 없는 옛 공식이 exit $rc — 번호 드리프트가 조용히 통과한다"

# --- AC18 : 문법 밖 §6 앵커 줄은 게이트(check_brief)와 같은 판독으로 막는다 -------------------------
VB="$(mktemp -d)" || exit 1
[[ -n "$VB" && -d "$VB" ]] || exit 1
trap 'rm -rf "$VB"' EXIT
for spec in 'v_nbsp|anchor_unicode_space|\n- **S2**|\n\u00a0- **S2**' \
            'v_ideo|anchor_unicode_space|\n- **S2**|\n\u3000- **S2**' \
            'v_star|anchor_star_bullet|\n- **S2**|\n* **S2**' \
            'v_indent|anchor_indented|\n- **S2**|\n  - **S2**' \
            'v_sep2028|anchor_line_separator|\n- **S2**|\u2028- **S2**' \
            'v_sepvt|anchor_line_separator|\n- **S2**|\u000b- **S2**' \
            'v_fullS|anchor_confusable|\n- **S2**|\n- **\uff332**' \
            'v_inbody|anchor_in_body|\n- **S2**|\n  > 인용 가운데 **\u04053** 를 심었다\n- **S2**' \
            'v_cyr|anchor_confusable|\n- **S2**|\n- **\u04052**' \
            'v_di|anchor_confusable|\n- **S2**|\n- **S\u31642**' \
            'v_ze|anchor_confusable|\n- **S2**|\n- **S\u0417** 「심은 줄」\n- **S2**'; do
  IFS='|' read -r stem why from to <<<"$spec"
  cp "$FX/brief-verbatim-ok.md" "$VB/$stem.md"
  python3 -I - "$VB/$stem.md" "$from" "$to" <<'PY'
import json, sys
p = sys.argv[1]
old, rep = (json.loads('"' + a + '"') for a in sys.argv[2:4])
t = open(p, encoding="utf-8").read()
new = t.replace(old, rep)
if new == t:
    sys.exit("변형이 적용되지 않았다")
open(p, "w", encoding="utf-8").write(new)
PY
  out="$(json_of "$VB/$stem.md" "$FX/state-verbatim-ok.md" "$FX/brief-verbatim-ok.audit.md")"
  rc="$(rc_of "$VB/$stem.md" "$FX/state-verbatim-ok.md" "$FX/brief-verbatim-ok.audit.md")"
  { [[ "$rc" == "1" ]] && grep -qF "$why" <<<"$out"; } \
    && ok "AC18: 문법 밖 §6 앵커(${stem}) → exit 1 «${why}»" \
    || no "AC18: 문법 밖 §6 앵커(${stem})가 exit 1 + ${why} 가 아니다 (rc=$rc)"
done

# 같은 문법 밖 줄을 audit §6 에 두어도 막는다(payload 만 보던 틈).
for spec in 'a_sep2028|anchor_line_separator|\n- **S2**|\u2028- **S2**' \
            'a_fullS|anchor_confusable|\n- **S2**|\n- **\uff332**' \
            'a_nbsp|anchor_unicode_space|\n- **S2**|\n\u00a0- **S2**' \
            'a_inbody|anchor_in_body|\n- **S2**|\n  > - S9 「심은 줄」\n- **S2**'; do
  IFS='|' read -r stem why from to <<<"$spec"
  cp "$FX/brief-verbatim-ok.audit.md" "$VB/$stem.audit.md"
  python3 -I - "$VB/$stem.audit.md" "$from" "$to" <<'PY'
import json, sys
p = sys.argv[1]
old, rep = (json.loads('"' + a + '"') for a in sys.argv[2:4])
t = open(p, encoding="utf-8").read()
new = t.replace(old, rep)
if new == t:
    sys.exit("변형이 적용되지 않았다")
open(p, "w", encoding="utf-8").write(new)
PY
  out="$(json_of "$FX/brief-verbatim-ok.md" "$FX/state-verbatim-ok.md" "$VB/$stem.audit.md")"
  rc="$(rc_of "$FX/brief-verbatim-ok.md" "$FX/state-verbatim-ok.md" "$VB/$stem.audit.md")"
  { [[ "$rc" == "1" ]] && grep -qF "$why" <<<"$out"; } \
    && ok "AC18: audit §6 의 문법 밖 앵커(${stem}) → exit 1 «${why}»" \
    || no "AC18: audit §6 의 문법 밖 앵커(${stem})가 exit 1 + ${why} 가 아니다 (rc=$rc)"
done

# --- 닫은 답의 출처 — 인터뷰를 닫은 답이 state 에 고른 선택지(`source: chosen`)로 있는가 ----------
# 대상 S: brief §4 의 「외부 선례 무관(@S…)」 줄 전부 + audit §2 «마지막» 포화 판정 줄이 「사용자 판단 포화(@S…)」 일 때 그 S.
# 쌍은 fixtures/brief-closing-{irrelevant,saturation}.{md,audit.md,state.md} — 둘 다 게이트 · 대조를 통과하는 양성 대조다.
CL="$(mktemp -d)" || exit 1
[[ -n "$CL" && -d "$CL" ]] || exit 1
trap 'rm -rf "$VB" "$CL"' EXIT
SD_DIR="$REPO_ROOT/plugins/spec-distill"
GATE_PY="$SD_DIR/scripts/check_brief.py"
cat > "$CL/tool.py" <<'PY'
import json, re, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import check_brief as CB
import check_verbatim_coverage as CVC
cmd, args = sys.argv[2], sys.argv[3:]
def rd(p): return Path(p).read_text(encoding="utf-8")
def wr(p, t): Path(p).write_text(t, encoding="utf-8")
if cmd == "sub":      # sub <file> <old> <new> — 한 번 바꾼다(없으면 실패)
    t = rd(args[0])
    if args[1] not in t: sys.exit("sub: 찾지 못했다 — " + args[1])
    wr(args[0], t.replace(args[1], args[2], 1))
elif cmd == "src":    # src <state> <op>... — S3=verbatim · S3=- (키 삭제) · S3= (빈 값) · S3=@drop · +S9=chosen=<text>
    t = rd(args[0])
    for op in args[1:]:
        if op.startswith("+"):
            sid, src, text = op[1:].split("=", 2)
            rec = f'- id: {sid}\n  source: {src}\n  round: 9\n  text: "{text}"\n'
            i = t.index("\n---\n", 4)
            t = t[:i + 1] + rec + t[i + 1:]
            continue
        sid, val = op.split("=", 1)
        m = re.search(rf"(?m)^- id: {sid}\n(?:  .*\n)*", t)
        if not m: sys.exit("src: 레코드가 없다 — " + sid)
        rec = m.group(0)
        if val != "@drop" and not re.search(r"(?m)^  source:", rec): sys.exit("src: source 줄이 없다 — " + sid)
        if val == "@drop": new = ""
        elif val == "-": new = re.sub(r"(?m)^  source:.*\n", "", rec)
        elif val == "": new = re.sub(r"(?m)^  source:.*$", '  source: ""', rec)
        else: new = re.sub(r"(?m)^  source:.*$", f"  source: {val}", rec)
        t = t[:m.start()] + new + t[m.end():]
    wr(args[0], t)
elif cmd == "empty":  # empty <state> — user_statements: []
    t = rd(args[0])
    t = re.sub(r"(?ms)^user_statements:\n.*?(?=^---$)", "user_statements: []\n", t, count=1)
    wr(args[0], t)
elif cmd == "block":  # block <state> <line> — 대기 줄 블록 끝에 한 줄
    t = rd(args[0]).rstrip("\n") + "\n" + args[1] + "\n"
    wr(args[0], t)
elif cmd == "anchors":  # anchors <payload> <audit> — closing_answer_anchors 를 JSON 으로
    print(json.dumps(CB.closing_answer_anchors(rd(args[0]), rd(args[1])), ensure_ascii=False))
elif cmd == "field":  # field <key> < json
    print(json.dumps(json.load(sys.stdin).get(args[0]), ensure_ascii=False))
elif cmd == "sat_last":  # sat_last <audit> — audit §2 마지막 포화 판정 줄
    sec = CB._section_text(rd(args[0]), "2", "Budget")
    hits = [b for b in (CB._strip_bullet(ln).strip() for ln in CB._entry_lines(sec)) if CB.SAT_LINE_RE.match(b)]
    print(hits[-1] if hits else "")
elif cmd == "rebuild":  # rebuild_step_a <payload> <audit> <state> — Step A 의 state 로부터 다시 짓는 걸음을 흉내 낸다
    pp, ap, sp = args
    state = rd(sp)
    stmts = CVC.parse_user_statements(CVC._frontmatter(state))
    m = re.search(r"(?ms)^## audit §2 대기 줄[ \t]*\n(.*?)(?=^## |\Z)", state)
    block = [ln for ln in m.group(1).splitlines() if ln.strip()]
    def is_event(ln):
        b = CB._strip_bullet(ln.strip()).strip()
        return bool(CB.SAT_LINE_RE.match(b)) or b.startswith(("상한 도달 ", "판정 상한 도달 "))
    a = rd(ap)
    m2 = re.search(r"(?ms)^## 2\. Budget\n(.*?)(?=^## )", a)
    keep = [ln for ln in m2.group(1).splitlines() if ln.strip() and not is_event(ln)]
    a = a[:m2.start(1)] + "\n" + "\n".join(keep + block) + "\n\n" + a[m2.end(1):]
    p = rd(pp)
    pay_ids, aud_ids = set(CVC.parse_section6(p, "payload")), set(CVC.parse_section6(a, "audit"))
    for st in sorted(stmts, key=lambda s: int(s["id"][1:])):
        mark = "☑ 선택" if st.get("source") == "chosen" else "🗣 답"
        item = f'- **{st["id"]}** {mark}:\n  > "{st["text"]}"\n'
        if st["id"] not in pay_ids:
            p = p.replace("## 7. Next Action", item + "## 7. Next Action", 1)
        if st["id"] not in aud_ids and st["id"] != "S1":
            a = a.replace("\n## 7. 확산 원자료", item + "\n## 7. 확산 원자료", 1)
    wr(pp, p); wr(ap, a)
else:
    sys.exit("tool: 모르는 명령 " + cmd)
PY
tool() { python3 -I "$CL/tool.py" "$SD_DIR/scripts" "$@" || { no "tool $1 이 실패했다: $*"; return 1; }; }
pair() {  # pair <case> <irrelevant|saturation> → $CL/<case>/ 에 세 파일(이름 그대로 — audit_file 이 basename 을 가리킨다)
  mkdir -p "$CL/$1"
  cp "$FX/brief-closing-$2.md" "$FX/brief-closing-$2.audit.md" "$FX/brief-closing-$2.state.md" "$CL/$1/"
  P="$CL/$1/brief-closing-$2.md"; A="$CL/$1/brief-closing-$2.audit.md"; S="$CL/$1/brief-closing-$2.state.md"
}
vc() { python3 "$SCRIPT" "$P" "$S" "$A" 2>/dev/null; }
nc_of() { tool field not_chosen <<<"$1"; }
WHY_CL='이 레포 안의 정리 일이라 바깥 선례가 결정을 바꾸지 않는다'

# 양성 대조 — 두 쌍은 그대로 대조 rc 0 · 게이트 rc 0 이다(아래 red 가 다른 이유로 나지 않는다).
for k in irrelevant saturation; do
  pair "ctl_$k" "$k"
  out="$(vc)"; rc=$?
  { [[ $rc -eq 0 ]] && [[ "$(nc_of "$out")" == "[]" ]]; } \
    && ok "닫은 답(양성 대조 ${k}): 대상 S 가 chosen → rc 0 · not_chosen 빔" || no "닫은 답(양성 대조 ${k}): rc=$rc $out"
  python3 "$GATE_PY" gate "$P" >/dev/null 2>&1 && ok "닫은 답(양성 대조 ${k}): check_brief gate rc 0" || no "닫은 답(양성 대조 ${k}): 게이트가 red"
done

# vc_irrelevant_verbatim_rc1 — 「외부 선례 무관(@S2)」 · S2 verbatim → rc 1 · ["S2"] · 마무리 단계 문장
pair irr_verb irrelevant; tool src "$S" S2=verbatim
out="$(vc)"; rc=$?
{ [[ $rc -eq 1 ]] && [[ "$(nc_of "$out")" == '["S2"]' ]]; } \
  && ok "vc_irrelevant_verbatim_rc1: S2 verbatim → rc 1 · not_chosen [S2]" || no "vc_irrelevant_verbatim_rc1: rc=$rc $out"
adv="$(tool field advisories <<<"$out")"
adv_ok=1
for ph in 'S2(외부 선례 무관)' '고른 선택지로 기록되지 않았다' '마무리 단계' '그 질문을 선택지로 다시 묻는다' '다른 세션' '이어 갈 수 없다'; do
  grep -qF -- "$ph" <<<"$adv" || { adv_ok=0; no "vc_irrelevant_verbatim_rc1: advisory 에 「${ph}」 가 없다: $adv"; }
done
[[ $adv_ok -eq 1 ]] && ok "vc_irrelevant_verbatim_rc1: advisory 가 S2 · 종류 · 고른 선택지 아님 · 마무리 단계가 다시 묻는다 · 다른 세션이면 이어 갈 수 없다를 말한다"
assert_eq "$(tool field missing_ids <<<"$out")|$(tool field not_contained <<<"$out")|$(tool field unknown_ids <<<"$out")" "[]|[]|[]" \
  "vc_irrelevant_verbatim_rc1: rc 1 의 이유가 원문 완전성 키가 아니다"

# vc_saturation_last_line — 마지막 줄만 본다
pair sat_verb saturation; tool src "$S" S3=verbatim
out="$(vc)"; rc=$?
{ [[ $rc -eq 1 ]] && [[ "$(nc_of "$out")" == '["S3"]' ]]; } \
  && ok "vc_saturation_last_line: 마지막 줄 사용자 판단 포화(@S3) · S3 verbatim → rc 1 · [S3]" || no "vc_saturation_last_line: rc=$rc $out"
pair sat_prev saturation; tool src "$S" S3=verbatim
tool sub "$A" "- 포화 판정 2: 사용자 판단 포화(@S3) — 조사 불필요" "- 포화 판정 2: 사용자 판단 포화(@S3) — 조사 불필요
- 포화 판정 3: 포화 — 최근 두 조사 모두 결정을 바꾸지도 열지도 않았다"
out="$(vc)"; rc=$?
{ [[ $rc -eq 0 ]] && [[ "$(nc_of "$out")" == "[]" ]]; } \
  && ok "vc_saturation_last_line: 앞 줄 사용자 판단 포화 · 마지막 줄 판정자 포화 → 대조 안 함(rc 0)" || no "vc_saturation_last_line(앞 줄): rc=$rc $out"
pair sat_stop saturation; tool src "$S" S3=verbatim
tool sub "$A" "- 포화 판정 2: 사용자 판단 포화(@S3) — 조사 불필요" "- 사용자 종료(@S3) — 포화 판정 전"
out="$(vc)"; rc=$?
{ [[ $rc -eq 0 ]] && [[ "$(nc_of "$out")" == "[]" ]]; } \
  && ok "vc_saturation_last_line: 마지막 줄 사용자 종료(@S3) · S3 verbatim → rc 0 (대상 아님)" || no "vc_saturation_last_line(사용자 종료): rc=$rc $out"

# vc_record_missing_rc1 — 대상 S 가 state 에 없다(payload 에도 없어 원문 완전성 키는 비어 있다)
pair rec_missing irrelevant
tool sub "$P" "외부 선례 무관(@S2) — " "외부 선례 무관(@S9) — "
out="$(vc)"; rc=$?
{ [[ $rc -eq 1 ]] && [[ "$(nc_of "$out")" == '["S9"]' ]]; } \
  && ok "vc_record_missing_rc1: state 에 없는 S9 → rc 1 · [S9]" || no "vc_record_missing_rc1: rc=$rc $out"
assert_eq "$(tool field missing_ids <<<"$out")|$(tool field unknown_ids <<<"$out")" "[]|[]" \
  "vc_record_missing_rc1: rc 1 의 이유가 원문 완전성 키가 아니다"

# vc_source_absent_rc3 — 키 없음 · 빈 값 → rc 3 · 검사 불가 · not_chosen 빔
for v in - ''; do
  pair "src_absent_${v:-empty}" saturation; tool src "$S" "S3=${v}"
  out="$(vc)"; rc=$?
  { [[ $rc -eq 3 ]] && [[ "$(nc_of "$out")" == "[]" ]] && grep -qF '검사 불가' <<<"$(tool field advisories <<<"$out")"; } \
    && ok "vc_source_absent_rc3(${v:-empty}): source 없음 → rc 3 · 「검사 불가」 · not_chosen 빔" || no "vc_source_absent_rc3(${v:-empty}): rc=$rc $out"
done

# vc_source_unknown_value_rc1 — chosen 이 아닌 값은 글자 하나 달라도 위반
for v in selected Chosen; do
  pair "src_$v" saturation; tool src "$S" "S3=$v"
  out="$(vc)"; rc=$?
  { [[ $rc -eq 1 ]] && [[ "$(nc_of "$out")" == '["S3"]' ]]; } \
    && ok "vc_source_unknown_value_rc1: source: $v → rc 1 · [S3]" || no "vc_source_unknown_value_rc1($v): rc=$rc $out"
done

# vc_s1_chosen_passes — 최초 요청이 없는 인터뷰(S1 이 첫 답 · chosen)는 통과, 최초 요청 S1(state 에 없음)은 위반
pair s1_chosen irrelevant
tool sub "$P" "외부 선례 무관(@S2) — " "외부 선례 무관(@S1) — "
tool src "$S" "+S1=chosen=대시보드가 너무 느려요."
out="$(vc)"; rc=$?
{ [[ $rc -eq 0 ]] && [[ "$(nc_of "$out")" == "[]" ]]; } \
  && ok "vc_s1_chosen_passes: S1 이 chosen 인 첫 답 → rc 0" || no "vc_s1_chosen_passes: rc=$rc $out"
pair s1_request irrelevant
tool sub "$P" "외부 선례 무관(@S2) — " "외부 선례 무관(@S1) — "
out="$(vc)"; rc=$?
{ [[ $rc -eq 1 ]] && [[ "$(nc_of "$out")" == '["S1"]' ]]; } \
  && ok "vc_s1_chosen_passes: 최초 요청 S1(state 에 없음)을 가리킴 → rc 1 · [S1]" || no "vc_s1_chosen_passes(최초 요청): rc=$rc $out"

# vc_not_chosen_dedup_sorted — 같은 S 를 두 줄 · 두 닫힘이 가리켜도 한 번, 번호 순
pair dedup irrelevant; tool src "$S" S2=verbatim S4=verbatim
tool sub "$P" "외부 선례 무관(@S2) — ${WHY_CL}" "외부 선례 무관(@S4) — ${WHY_CL}
외부 선례 무관(@S4) — 같은 답을 두 번 적었다
외부 선례 무관(@S2) — ${WHY_CL}"
tool block "$S" "- 포화 판정 2: 사용자 판단 포화(@S4) — 조사 불필요"
tool sub "$A" "- 포화 판정 1: 포화 — 최근 두 조사 모두 결정을 바꾸지도 열지도 않았다" "- 포화 판정 1: 포화 — 최근 두 조사 모두 결정을 바꾸지도 열지도 않았다
- 포화 판정 2: 사용자 판단 포화(@S4) — 조사 불필요"
out="$(vc)"; rc=$?
{ [[ $rc -eq 1 ]] && [[ "$(nc_of "$out")" == '["S2", "S4"]' ]]; } \
  && ok "vc_not_chosen_dedup_sorted: S4 두 줄 + S2 + 마지막 포화 S4 → [S2, S4]" || no "vc_not_chosen_dedup_sorted: rc=$rc $out"
assert_eq "$(tool anchors "$P" "$A")" '[["S4", "irrelevant"], ["S2", "irrelevant"], ["S4", "saturation"]]' \
  "vc_not_chosen_dedup_sorted: closing_answer_anchors 는 외부 선례 무관 S 를 한 번씩 · 마지막 포화를 따로 낸다"

# vc_violation_beats_indeterminate — 다른 S 의 P21 자리표(검사 불가)가 섞여도 · 원장이 0건이어도 rc 1
pair beats irrelevant; tool src "$S" S2=verbatim
tool sub "$S" 'text: "첫 화면만 빠르면 된다"' 'text: "첫 화면만 <REDACTED:x> 된다"'
out="$(vc)"; rc=$?
{ [[ $rc -eq 1 ]] && [[ "$(nc_of "$out")" == '["S2"]' ]] && grep -qF 'P21' <<<"$out"; } \
  && ok "vc_violation_beats_indeterminate: P21 검사 불가(S5) + not_chosen(S2) → rc 1" || no "vc_violation_beats_indeterminate: rc=$rc $out"
pair beats_empty irrelevant; tool empty "$S"
out="$(vc)"; rc=$?
{ [[ $rc -eq 1 ]] && [[ "$(nc_of "$out")" == '["S2"]' ]]; } \
  && ok "vc_violation_beats_indeterminate: user_statements 0건 + 대상 S2 → rc 1 (검사 불가 3 이 아니다)" || no "vc_violation_beats_indeterminate(0건): rc=$rc $out"
pair beats_empty_ctl saturation; tool empty "$S"
tool sub "$A" "- 포화 판정 2: 사용자 판단 포화(@S3) — 조사 불필요" "- 포화 판정 3: 포화 — 최근 두 조사 모두 결정을 바꾸지도 열지도 않았다"
out="$(vc)"; rc=$?
[[ $rc -eq 3 ]] && ok "vc_violation_beats_indeterminate(대칭): 0건 원장 · 대상 없음 → 여전히 rc 3" || no "vc_violation_beats_indeterminate(대칭): rc=$rc $out"

# 예외 JSON 도 not_chosen 키를 갖는다 — run 에 예외를 심어 main 의 출력을 본다
cat > "$CL/inject.py" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("cvc", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
def boom(*a, **k):
    raise RuntimeError("injected")
mod.run = boom
sys.exit(mod.main(["cvc"] + sys.argv[2:5]))
PY
out="$(python3 -I "$CL/inject.py" "$SCRIPT" "$P" "$S" "$A")"; rc=$?
{ [[ $rc -eq 4 ]] && [[ "$(nc_of "$out")" == "[]" ]]; } \
  && ok "main 예외 JSON 에 not_chosen 키(빈 목록) · exit 4" || no "main 예외 JSON 에 not_chosen 키가 없다: rc=$rc $out"

# check_brief_invariant — check_brief.py 는 brief 파일만 읽는다
grep -qF '**불변식: 이 스크립트는 brief 파일만 읽는다**' "$GATE_PY" \
  && ok "check_brief_invariant: 불변식 docstring 문장이 그대로다" || no "check_brief_invariant: 불변식 문장이 바뀌었다"
for tok in 'user_statements' '.state.md' 'state_path'; do
  grep -qF -- "$tok" "$GATE_PY" && no "check_brief_invariant: check_brief.py 에 '${tok}'" || ok "check_brief_invariant: check_brief.py 에 '${tok}' 없음"
done
python3 -I - "$GATE_PY" <<'PY' && ok "check_brief_invariant: closing_answer_anchors(payload_text, audit_text) — 글만 받는다" || no "check_brief_invariant: closing_answer_anchors 의 인자가 글 둘이 아니다"
import ast, sys
t = ast.parse(open(sys.argv[1], encoding="utf-8").read())
fn = [n for n in t.body if isinstance(n, ast.FunctionDef) and n.name == "closing_answer_anchors"]
sys.exit(0 if fn and [a.arg for a in fn[0].args.args] == ["payload_text", "audit_text"] else 1)
PY

# rb_gate_skip_var_not_chosen — RB 진입 게이트 펜스를 실제 검사기로 돌린다. 건너뛰기 변수 + 오늘 날짜 rc 1 증거 줄이 있어도 멈춘다.
RB_SKILL="$SD_DIR/skills/reviewing-brief/SKILL.md"
rb_fence() {  # rb_fence <case 디렉토리 이름> → fence.sh
  { printf 'PR="%s"; PAYLOAD="%s"; STATE="%s"; AUDIT="%s"; BUNDLE=""\ndrop_bundle() { return 0; }\n' "$SD_DIR" "$P" "$S" "$A"
    awk '/^## 진입 게이트/{f=1;next} f && /^## /{exit} f' "$RB_SKILL" | awk '/^gate_rc=0;/{f=1} f && /^```/{exit} f'
    echo 'echo REACHED_ENGINE'; } > "$CL/$1/fence.sh"
}
TODAY_CL="$(date +%Y-%m-%d)"
for c in rb_skip rb_skip_ctl; do
  pair "$c" saturation
  [[ "$c" == rb_skip ]] && tool src "$S" S3=verbatim
  tool sub "$A" "- check_brief.py gate — pass (2026-09-23) — web: enabled" "- check_brief.py gate — pass (2026-09-23) — web: enabled
- check_verbatim_coverage.py — exit 1 — skipped_by_user: 검사 없이 계속 (${TODAY_CL})"
  rb_fence "$c"
done
grep -qF 'check_verbatim_coverage.py" "$PAYLOAD" "$STATE" "$AUDIT"' "$CL/rb_skip/fence.sh" \
  && ok "rb_gate_skip_var_not_chosen(전제): 꺼낸 펜스가 실제 검사기를 부른다" || no "rb_gate_skip_var_not_chosen(전제): 펜스를 꺼내지 못했다"
o="$(DEVBREW_SPEC_DISTILL_SKIP_VC_ONCE=1 bash "$CL/rb_skip/fence.sh" 2>"$CL/rb_skip/err")"; r=$?
e="$(cat "$CL/rb_skip/err")"
{ [[ $r -eq 1 ]] && [[ "$o" != *REACHED_ENGINE* ]] && [[ "$e" == *'닫은 답의 출처 위반'* ]] && [[ "$o" == *'"not_chosen": ["S3"]'* ]]; } \
  && ok "rb_gate_skip_var_not_chosen: not_chosen 쌍 + 건너뛰기 변수 + rc 1 증거 줄 → rc 1 로 멈춘다" \
  || no "rb_gate_skip_var_not_chosen: r=$r out=$o err=$e"
o="$(DEVBREW_SPEC_DISTILL_SKIP_VC_ONCE=1 bash "$CL/rb_skip_ctl/fence.sh" 2>/dev/null)"; r=$?
{ [[ $r -eq 0 ]] && [[ "$o" == *REACHED_ENGINE* ]]; } \
  && ok "rb_gate_skip_var_not_chosen(양성 대조): S3 chosen 이면 같은 펜스가 엔진까지 간다" || no "rb_gate_skip_var_not_chosen(양성 대조): r=$r $o"

# rebuild_once_and_idempotent — 되묻기 결과(S9 chosen + 대기 줄 덧붙임)를 넣고 Step A 의 다시 짓는 걸음을 돌린다
pair rebuild saturation; tool src "$S" S3=verbatim
[[ "$(nc_of "$(vc)")" == '["S3"]' ]] && ok "rebuild_once_and_idempotent(전제): 시작 쌍은 not_chosen [S3]" || no "rebuild_once_and_idempotent(전제): 시작 쌍이 not_chosen 이 아니다"
tool src "$S" "+S9=chosen=조사 불필요 — 판단만 남음"
tool block "$S" "- 포화 판정 3: 사용자 판단 포화(@S9) — 조사 불필요"
tool rebuild "$P" "$A" "$S"
n9="$(grep -cF -- '- 포화 판정 3: 사용자 판단 포화(@S9) — 조사 불필요' "$A")"
assert_eq "$n9" "1" "rebuild_once_and_idempotent: audit §2 에 @S9 줄이 정확히 한 번"
out="$(vc)"; rc=$?
{ [[ $rc -eq 0 ]] && [[ "$(nc_of "$out")" == "[]" ]]; } && ok "rebuild_once_and_idempotent: 다시 지은 뒤 대조 rc 0" || no "rebuild_once_and_idempotent: 대조 rc=$rc $out"
python3 "$GATE_PY" gate "$P" >/dev/null 2>&1 && ok "rebuild_once_and_idempotent: 다시 지은 뒤 check_brief gate rc 0" || no "rebuild_once_and_idempotent: 게이트가 red"
h1="$(cat "$P" "$A" "$S" | cksum)"
tool rebuild "$P" "$A" "$S"
h2="$(cat "$P" "$A" "$S" | cksum)"
assert_eq "$h2" "$h1" "rebuild_once_and_idempotent: 한 번 더 돌려도 세 파일의 바이트가 같다(멱등)"

# rebuild_irrelevant_keeps_last_saturation — 외부 선례 무관 되묻기는 brief §4 의 @S 만 바꾸고 포화 줄은 그대로다
pair rebuild_irr irrelevant; tool src "$S" S2=verbatim
sat_before="$(tool sat_last "$A")"
tool sub "$P" "외부 선례 무관(@S2) — " "외부 선례 무관(@S9) — "
tool src "$S" "+S9=chosen=외부 선례 무관"
tool rebuild "$P" "$A" "$S"
out="$(vc)"; rc=$?
{ [[ $rc -eq 0 ]] && [[ "$(nc_of "$out")" == "[]" ]]; } && ok "rebuild_irrelevant_keeps_last_saturation: 대조 rc 0" || no "rebuild_irrelevant_keeps_last_saturation: 대조 rc=$rc $out"
python3 "$GATE_PY" gate "$P" >/dev/null 2>&1 && ok "rebuild_irrelevant_keeps_last_saturation: 게이트 rc 0" || no "rebuild_irrelevant_keeps_last_saturation: 게이트가 red"
assert_eq "$(tool sat_last "$A")" "$sat_before" "rebuild_irrelevant_keeps_last_saturation: audit §2 마지막 포화 판정 줄이 같은 글자"

# 문장 단언 — RB rc 표 · 펜스 · finishing · README
W_GATE_CL="$(awk '/^## 진입 게이트/{f=1;next} f && /^## /{exit} f' "$RB_SKILL")"
row="$(grep -F '| `1`(`not_chosen`) |' <<<"$W_GATE_CL" || true)"
{ [[ -n "$row" ]] && [[ "$row" == *'`advisories` 의 「인터뷰를 닫은 답 …」 줄을 고쳐 쓰지 않고 그대로 사용자에게 보인다'* ]] && [[ "$row" == *'건너뛰지 않는다'* ]]; } \
  && ok "RB rc 표: \`1\`(\`not_chosen\`) 행이 advisories 의 「인터뷰를 닫은 답 …」 줄을 그대로 보이라고 한다 · 건너뛰지 않는다" || no "RB rc 표: not_chosen 행이 없거나 문면이 다르다"
# 행이 제 문장을 따로 지어 보이지 않는다(그 문장은 advisory 에 산다 — 위 advisory 단언이 「그 질문을 선택지로 다시 묻는다」 를 본다) · 계획 얘기를 싣지 않는다
[[ "$row" == *'다시 묻는다」를 보인다'* ]] && no "RB rc 표: not_chosen 행이 advisory 대신 제 문장을 보이라고 한다" || ok "RB rc 표: not_chosen 행이 제 문장을 따로 짓지 않는다"
grep -qF '계획이 실측한다' "$RB_SKILL" && no "RB SKILL: 계획 얘기(「계획이 실측한다」)가 실렸다" || ok "RB SKILL: 「계획이 실측한다」 없음"
grep -qF '원문 완전성 검사(닫은 답의 출처 대조 포함)를 건너뛰고 계속한다' <<<"$W_GATE_CL" \
  && ok "RB 펜스: 건너뛰기 알림이 닫은 답의 출처 대조도 건너뛴다고 말한다" || no "RB 펜스: 건너뛰기 알림에 닫은 답의 출처 대조가 없다"
grep -qF '이 검사만 건너뛰고 리뷰를 시작한다 — 닫은 답의 출처 대조 포함' <<<"$W_GATE_CL" \
  && ok "RB 진입 게이트: 「검사 없이 계속」 설명이 닫은 답의 출처 대조를 포함한다고 말한다" || no "RB 진입 게이트: 「검사 없이 계속」 설명에 닫은 답의 출처 대조가 없다"
grep -qF '1) echo "[spec-distill] §6 원문 완전성 위반이나 닫은 답의 출처 위반' <<<"$W_GATE_CL" \
  && ok "RB 펜스: rc 1 문장이 원문 완전성 위반과 닫은 답의 출처 위반을 함께 말한다" || no "RB 펜스: rc 1 문장에 닫은 답의 출처 위반이 없다"
FIN="$SD_DIR/skills/pm-interview/references/finishing.md"
A5="$(awk '/^### Step A\.5/{f=1;next} f && /^### /{exit} f' "$FIN")"
for ph in '닫는 선택지' '「조사 계속」' '대기 줄 블록 한 곳에만' 'brief §4 그 줄의 `@S` 만' '3 · 4 · 7 · 8 을 다시 돈 뒤 Step A.5 로' '세션을 넘겨' '마지막 포화 판정 번호 다음 수'; do
  grep -qF -- "$ph" <<<"$A5" && ok "finishing Step A.5 되묻기 갈래: 「${ph}」" || no "finishing Step A.5 되묻기 갈래에 「${ph}」 가 없다"
done
A4="$(awk '/^4\. \*\*Coverage Ledger 직렬화/{f=1} f && /^5\. \*\*/{exit} f' "$FIN")"
{ grep -qF 'Step A.5 의 되묻기 갈래로 다시 돌 때는' <<<"$A4" && grep -qF '통째로 다시 쓴다 — 덧붙이지 않는다' <<<"$A4"; } \
  && ok "finishing Step A ④: 다시 돌 때는 state 에서 통째로 다시 쓴다" || no "finishing Step A ④ 에 「다시 돌 때는 … 통째로 다시 쓴다」 가 없다"
README_SD="$SD_DIR/README.md"
grep -qF '이 대조는 brief 를 쓴 뒤 리뷰 진입(`check_verbatim_coverage.py`)에서 돈다 — 리뷰를 거치지 않는 길에서는 돌지 않는다.' "$README_SD" \
  && ok "README: 시점 한계 문장" || no "README: 시점 한계 문장이 없다"
CL_SD="$SD_DIR/CHANGELOG.md"
grep -qF '이 대조는 brief 를 쓴 뒤 리뷰 진입(`check_verbatim_coverage.py`)에서 돈다 — 리뷰를 거치지 않는 길에서는 돌지 않는다.' "$CL_SD" \
  && ok "CHANGELOG: 시점 한계 문장" || no "CHANGELOG: 시점 한계 문장이 없다"
grep -qF '사용자가 골랐는지는 증명하지 못한다' "$README_SD" \
  && ok "README: 출처 한계 「사용자가 골랐는지는 증명하지 못한다」 유지" || no "README: 출처 한계 문장이 사라졌다"

# --- usage -----------------------------------------------------------------
python3 "$SCRIPT" >/dev/null 2>&1; rc=$?
[[ "$rc" != "0" && "$rc" != "1" ]] && ok "인자 부족 → non-zero이며 1이 아님 (rc=$rc)" \
                                   || no "usage 오류가 0 또는 1을 낸다 (rc=$rc)"
finish
