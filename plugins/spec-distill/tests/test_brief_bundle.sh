#!/usr/bin/env bash
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
B="$SD/scripts/build_brief_bundle.py"
FX="$SD/tests/fixtures"
fail=0; ok(){ printf '  ok  %s\n' "$1"; }; no(){ printf '  NO  %s\n' "$1"; fail=1; }

out="$(python3 "$B" "$FX/interview-brief-valid.md" "$FX/interview-brief-valid.audit.md" 2>&1)"; rc=$?
[[ $rc -eq 0 ]] && ok "T1: 정상 경로 rc 0" || no "T1: 정상 경로 rc $rc"
printf '%s' "$out" | grep -qF '<<<PAYLOAD>>>' && ok "T2: PAYLOAD 라벨" || no "T2: PAYLOAD 라벨 부재"
printf '%s' "$out" | grep -qF '<<<AUDIT-VERBATIM>>>' && ok "T3: AUDIT-VERBATIM 라벨" || no "T3: 라벨 부재"

# (ㄴ) 실린 절의 내부 헤딩은 벗긴다 — 안 벗기면 `## 6. 사용자 원문` 이 번들에 둘이 되고
# 「§6 을 보라」는 지시가 먼저 나오는 payload(S1 하나)에 걸린다. 이 절이 닫으려는 fail-open 이다.
n="$(printf '%s' "$out" | grep -cF '## 6. 사용자 원문')"
[[ "$n" -le 1 ]] && ok "T4: 번들에 §6 헤딩이 최대 1개 (동명 충돌 없음)" \
  || no "T4: §6 헤딩이 $n 개 — audit 절 헤딩을 안 벗겼다"

# audit §6 의 S2+ 가 실제로 실렸다 (양성 대조 — 라벨만 있고 내용이 비면 무의미)
printf '%s' "$out" | grep -qE '\*\*S[2-9][0-9]*\*\*' \
  && ok "T5: audit §6 항목이 번들에 실렸다" || no "T5: 라벨만 있고 원문이 없다"

# rc 2 : audit 을 안 주면
python3 "$B" "$FX/interview-brief-valid.md" >/dev/null 2>&1
[[ $? -eq 2 ]] && ok "T6: audit 인자 없음 → rc 2" || no "T6: audit 없이 조립했다 (fail-open)"
# rc 2 : audit 에 §6 이 없으면
python3 "$B" "$FX/interview-brief-valid.md" "$FX/brief-verbatim-audit-no-sec6.audit.md" >/dev/null 2>&1
[[ $? -eq 2 ]] && ok "T7: audit §6 부재 → rc 2 (무디스패치)" \
  || no "T7: 원문 없이 조립했다 — 「왜곡 없음」이 나오는 경로"
# rc 3 : 위생 스캔은 payload 부분에만
python3 "$B" "$FX/interview-brief-valid.md" "$FX/interview-brief-valid.audit.md" >/dev/null 2>&1
[[ $? -ne 3 ]] && ok "T8: 정상 동작이 exit 3 이 아니다 (위생 스캔 범위 한정)" \
  || no "T8: audit 내용까지 스캔해 매번 exit 3"

# T9: T8은 vacuous하다 — 두 fixture 어디에도 `.audit.md` 문자열이 없어서, 스캔 범위를
# 번들 전체로 넓혀도(mutation으로 확인) T8은 여전히 통과한다. 스캔 범위 요구를 실제로
# 거는 양성 대조: audit §6 원문 **안에** `.audit.md` 꼴 문자열을 심어 넣고, payload
# 쪽엔 없게 한다. payload만 스캔하면 rc 0, 번들 전체를 스캔하면 rc 3이어야 한다.
tmp_audit="$(mktemp)" || exit 1
sed 's/"인증 뷰는 일단 빼고 갑시다"/"stray-note.audit.md 참고하고 인증 뷰는 일단 빼고 갑시다"/' \
  "$FX/interview-brief-valid.audit.md" > "$tmp_audit"
grep -qF '.audit.md' "$tmp_audit" || { no "T9: 픽스처 치환이 적용되지 않았다 (vacuous 방지 실패)"; }
out9="$(python3 "$B" "$FX/interview-brief-valid.md" "$tmp_audit" 2>&1)"; rc9=$?
[[ $rc9 -eq 0 ]] && ok "T9: audit §6 원문 안의 '.audit.md'는 위생 스캔 대상이 아니다 (rc 0)" \
  || no "T9: audit 쪽 '.audit.md'가 rc $rc9 를 냈다 — 스캔이 payload 밖까지 샜다"
printf '%s' "$out9" | grep -qF 'stray-note.audit.md' \
  && ok "T9: 그 원문은 그대로 실렸다 (지우지 않았다)" || no "T9: 원문이 사라졌다"
rm -f "$tmp_audit"

exit $fail
