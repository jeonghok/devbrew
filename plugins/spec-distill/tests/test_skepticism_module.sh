#!/usr/bin/env bash
# plugins/spec-distill/tests/test_skepticism_module.sh
# scripts/skepticism.py — §5 skepticism 검사 모듈의 함수 단위 락 (설계 §6.3 · L6).
# check_brief.py 를 import 하지 않는 방향(check_brief → skepticism 하나)을 AC21 로 잠근다.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill/scripts"
. "$REPO_ROOT/shared/tests/assert.sh"

# 파일 부재는 fail-closed 로 **여기서 끝난다** — 아래 grep 단언들은 대상 파일이 없으면
# 비-0 으로 떨어져 `ok` 가지로 흘러 조용히 통과한다(shared/tests/assert.sh 의 파일 변형이
# 못 박은 그 결함). 그래서 리포 관례대로 `finish; exit $?` 로 즉시 종료한다.
test -f "$SD/skepticism.py" && ok "skepticism.py 실재" || { no "skepticism.py 부재"; finish; exit $?; }

# AC21 — 의존 방향
grep -qE '^(import|from) check_brief' "$SD/skepticism.py" \
  && no "AC21: skepticism.py 가 check_brief 를 import 한다 (순환)" \
  || ok "AC21: skepticism.py 는 check_brief 를 import 하지 않는다"
grep -qE '^from skepticism import' "$SD/check_brief.py" \
  && ok "AC21: check_brief.py 가 skepticism 을 들여온다" \
  || no "AC21: check_brief.py 에 from skepticism import 부재"
grep -qE '^VALID_VERDICTS' "$SD/check_brief.py" \
  && no "AC8: VALID_VERDICTS 정의가 check_brief.py 에 남아 있다" \
  || ok "AC8: VALID_VERDICTS 정의는 skepticism.py 에만"

# 함수 단위 — 파이썬으로 판정을 내고 한 줄씩 받는다
report="$(PYTHONDONTWRITEBYTECODE=1 python3 - "$SD" <<'PY'
import sys; sys.path.insert(0, sys.argv[1])
import skepticism as S
def line(name, cond): print(("OK\t" if cond else "NO\t") + name)
line("AC8: VALID_VERDICTS == kept/refined/switched/deferred",
     S.VALID_VERDICTS == ("kept", "refined", "switched", "deferred"))
V = ["- 기각 — islands architecture 우선 도입 — verdict: kept — ST1",
     "- 위험 — 숨은 가정 | x: y — z"]
R = ["- 검토 — steelman 0건: 검토한 방향 2개 · 전제 P1 · trigger 후보 islands 벤치마크 → 기각 이유 전제 충돌 없음"]
RB = ["- 검토 — steelman 0건: 검토한 방향 2개 · 전제 P1 · trigger 후보 islands 벤치마크"]  # 기각 이유 없음
D = ["- 보류 — islands architecture 우선 도입 → §3 OQ1 — verdict: deferred — ST1 — 부착 0/1"]
OLD = ["- 기각 — islands architecture 우선 도입 — verdict: defended — ST1"]
line("verdict_entries 가 verdict: 줄만 고른다", S.verdict_entries(V) == [V[0]])
line("review_record_entries 가 검토 접두만 고른다", S.review_record_entries(R + V) == R)
line("review_record_entries 는 '검토함' 같은 변형을 안 고른다",
     S.review_record_entries(["- 검토함 — steelman 0건: 검토한 방향 1개 · 전제 P1 · trigger 후보 a → 기각 이유 b"]) == [])
line("skepticism_malformed: kept 는 정상", S.skepticism_malformed(V) == [])
line("skepticism_malformed: refined 는 정상",
     S.skepticism_malformed(["- 기각 — 버린 절반 → 이유 — verdict: refined — ST1 — 부착 1/2"]) == [])
line("skepticism_malformed: deferred(보류 접두)는 정상", S.skepticism_malformed(D) == [])
line("skepticism_malformed: 옛 토큰 defended 는 no-verdict",
     any("no-verdict" in m for m in S.skepticism_malformed(OLD)))
line("skepticism_malformed: ST 참조 없으면 no-ST-ref",
     any("no-ST-ref" in m for m in S.skepticism_malformed(["- 기각 — islands architecture 우선 도입 — verdict: kept"])))
line("review_record_malformed: 네 토큰 다 있으면 통과", S.review_record_malformed(R) == [])
line("review_record_malformed: 기각 이유 없으면 지목", len(S.review_record_malformed(RB)) == 1 and "기각 이유" in S.review_record_malformed(RB)[0])
line("closure: verdict 1 → ok", S.skepticism_closure_ok(V))
line("closure: 검토 1(정상) → ok", S.skepticism_closure_ok(R))
line("closure: 검토 1(형식 미달) → not ok", not S.skepticism_closure_ok(RB))
line("closure: 둘 다 0 → not ok", not S.skepticism_closure_ok(["- 기각 — a → b", "- 위험 — c"]))
line("closure: 빈 §5 → not ok", not S.skepticism_closure_ok([]))
aud = "#### ST1 — 요지\n\n> verbatim\n"
line("bijection A: 일치", S.bijection_a_errors(V, aud) == [])
line("bijection A: payload 만 ST9", any(m.startswith("ST9") and "audit §3에 없음" in m
     for m in S.bijection_a_errors(["- 기각 — x y z w q — verdict: kept — ST9"], aud)))
line("bijection A: audit 만 ST1", any("판정 없는 steelman" in m for m in S.bijection_a_errors([], aud)))
line("bijection A: URL 안 /ST9/ 는 참조가 아니다",
     S.bijection_a_errors(["- 기각 — https://x.test/ST9/ 인용 문장 — verdict: kept — ST1"], aud) == [])
line("bijection A: 보류 항목도 ST 를 참조한다", S.bijection_a_errors(D, aud) == [])
line("strip_bullet 은 - 와 * 를 뗀다", S.strip_bullet("* 기각 — a") == "기각 — a" and S.strip_bullet("- 기각 — a") == "기각 — a")
PY
)"
while IFS="$(printf '\t')" read -r st msg; do
  [[ -n "${st:-}" ]] || continue
  [[ "$st" == OK ]] && ok "$msg" || no "$msg"
done <<< "$report"
[[ "$(printf '%s\n' "$report" | grep -c .)" -ge 20 ]] \
  && ok "함수 단위 판정 ≥20 줄 (vacuous 아님)" || no "함수 단위 판정이 20 줄 미만 — 파이썬 블록이 죽었다"
finish
