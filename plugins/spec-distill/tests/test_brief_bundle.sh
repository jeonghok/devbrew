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

# T10/T11: 라벨은 헤딩이 아니다 — **모양**을 검사한다. -F 부분문자열 검사는
# `## <<<PAYLOAD>>>`처럼 헤딩으로 승격돼도 토큰만 있으면 통과해버린다(review round 1
# 이 실제로 이 mutation 으로 T2/T3를 속였다). 라인 전체를 정확히 매치(`grep -qx`)해
# `#`이 앞에 붙으면 실패하게 한다 — 토큰이 아니라 그 토큰이 사는 라인의 모양을 본다.
printf '%s' "$out" | grep -qx '<<<PAYLOAD>>>' \
  && ok "T10: PAYLOAD 라벨 라인이 헤딩이 아니다 (라인 전체 일치)" \
  || no "T10: PAYLOAD 라벨이 헤딩으로 승격됐거나 라인이 다르다"
printf '%s' "$out" | grep -qx '<<<AUDIT-VERBATIM>>>' \
  && ok "T11: AUDIT-VERBATIM 라벨 라인이 헤딩이 아니다 (라인 전체 일치)" \
  || no "T11: AUDIT-VERBATIM 라벨이 헤딩으로 승격됐거나 라인이 다르다"

# T12: 세 redact 키 전부가 실제로 치환됐는지 검사한다. `audit_file`은 우연히 그 값이
# `.audit.md` 꼴이라 위생 스캔(T8/T9)이 곁다리로 잡아주지만 `name`·`created_at`은
# 아무 것도 안 본다 — REDACT_KEYS에서 하나만 지워도(review round 1 mutation) 스위트가
# 그대로 GREEN이었다. 키 목록은 스크립트에서 **동적으로** 가져온다 — 여기 이름을
# 다시 나열하면 나중에 네 번째 키가 추가돼도 이 테스트가 그 키를 못 보고 계속
# 통과한다(닫으려는 gap과 같은 모양).
redact_pairs="$(python3 - "$B" "$FX/interview-brief-valid.md" <<'PY'
import importlib.util, re, sys
script, payload_path = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("brief_bundle_mod", script)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
text = open(payload_path, encoding="utf-8").read()
for k in mod.REDACT_KEYS:
    m = re.search(rf"(?m)^{re.escape(k)}\s*:\s*(\S.*)$", text)
    if m:
        print(f"{k}\t{m.group(1).strip()}")
PY
)"
[[ -n "$redact_pairs" ]] || no "T12: REDACT_KEYS 원본값을 fixture에서 못 찾았다 (테스트 자체가 무력화)"
while IFS=$'\t' read -r key val; do
  [[ -z "$key" ]] && continue
  printf '%s' "$out" | grep -qF -- "$val" \
    && no "T12: ${key} 원본값('${val}')이 번들에 남아 있다 (redact 안 됨)" \
    || ok "T12: ${key} 원본값이 번들에서 사라졌다"
  printf '%s' "$out" | grep -qE "^${key}:[[:space:]]*<redacted>\$" \
    && ok "T12: ${key}: <redacted> 형태로 치환됐다" \
    || no "T12: ${key} 가 <redacted> 형태로 치환되지 않았다"
done <<< "$redact_pairs"

exit $fail
