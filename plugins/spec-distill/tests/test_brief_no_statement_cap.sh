#!/usr/bin/env bash
# statement 분량 상한(STATEMENT_MAX=160) 제거의 회귀 락.
#
# 무엇이 사라졌는가: check_brief.py 의 STATEMENT_MAX 상수와 user_sourced_errors() 의
# 길이 검사, 그리고 finishing.md 의 상한 지시 문구.
#
# 왜: 상한이 잰 것은 과잉결정이 아니라 부피였다. 과잉결정은 brief-readback 이 직접 잰다.
#
# 이 락의 구조 — 세 층. 부재 검사만으로 된 락은 대상 파일을 통째로 지워도 통과하므로,
# 층 1(양성 대조)이 "이 락이 실제로 그 코퍼스를 읽었다"를 먼저 증명한다.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
SCRIPT="$SD/scripts/check_brief.py"
FIN="$SD/skills/conducting-interview/references/finishing.md"
fail=0
ok()  { printf '  ok  %s\n' "$1"; }
no()  { printf '  NO  %s\n' "$1"; fail=1; }

# --- 층 1 : 양성 대조 — 이 락이 실제 파일을 읽었다 -------------------------
grep -q 'def user_sourced_errors' "$SCRIPT" \
  && ok "L1: check_brief.py 를 실제로 읽었다 (user_sourced_errors 실재)" \
  || no "L1: 코퍼스를 못 읽었다 — 아래 부재 검사는 전부 공허하다"
grep -qF 'user_statements' "$FIN" \
  && ok "L1: finishing.md 를 실제로 읽었다" \
  || no "L1: finishing.md 코퍼스를 못 읽었다"

# --- 층 2 : 부재 — 상한의 모든 표현이 사라졌다 -----------------------------
grep -q 'STATEMENT_MAX' "$SCRIPT" \
  && no "L2: STATEMENT_MAX 잔존" || ok "L2: STATEMENT_MAX 제거됨"
grep -qE '160자|hard cap' "$SCRIPT" \
  && no "L2: 상한 메시지 잔존" || ok "L2: 상한 메시지 제거됨"
grep -qE '160자|≤ *160|160 ?자 이내' "$FIN" \
  && no "L2: finishing.md 에 상한 지시 잔존" || ok "L2: finishing.md 상한 지시 제거됨"

# --- 층 3 : 행동 — 긴 statement 가 실제로 통과한다 ------------------------
# rc(종료 코드)로 판정한다, 메시지 리터럴이 아니라. 'hard cap' grep 만으로는 이 층이
# 사실상 L2의 중복이라 — 이름을 바꿔 재도입된 상한(예: "too long")은 게이트를 실제로
# 계속 거부시키면서도 grep을 피해간다(mutation 실증, CHANGELOG 참고). rc==0 요구는
# "어떤 이름으로도 재도입되지 않았다"를 잡는다 — 진짜 행동 검사.
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
LONG="$(python3 -c "print('가' * 200)")"
python3 - "$SD" "$TMP" "$LONG" <<'PY'
import pathlib, re, sys
sd, tmp, long_stmt = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
src = sd / "tests/fixtures/interview-brief-valid.md"
src_audit = sd / "tests/fixtures/interview-brief-valid.audit.md"
dst = tmp / "interview-brief-long.md"
dst_audit = tmp / "interview-brief-long.audit.md"

text = src.read_text(encoding="utf-8")
# frontmatter 의 첫 statement(C1)와 §2 본문의 같은 항목(C1)을 함께 늘린다 (bijection B).
# 한쪽만 늘리면 bijection_b_errors 가 "body statement != frontmatter statement"로
# red를 내고, 그 red는 상한(STATEMENT_MAX)과 무관하므로 이 층이 엉뚱한 이유로
# 통과/실패한다 — 반드시 두 곳을 함께 늘린다.
text = re.sub(
    r'(?m)^(\s*statement:\s*)".*?"$',
    lambda m: m.group(1) + '"' + long_stmt + '"',
    text, count=1,
)
text = re.sub(
    r'(?m)^(- 🗣 confirmed \*\*C1\*\* — ).*?( ⟨S1⟩)$',
    lambda m: m.group(1) + long_stmt + m.group(2),
    text, count=1,
)
# audit_file 은 payload stem 에서 유도된다 (resolve_audit: <stem>.audit.md) — 새 파일명
# (interview-brief-long.md)에 맞춰 이 필드도 같이 갱신하지 않으면 이 파생 fixture는
# "audit_file is not this payload's sidecar" 로 상한과 무관한 이유로 항상 red가 나서
# rc==0 단언이 무의미해진다.
text = re.sub(
    r'(?m)^(audit_file:\s*).*$',
    lambda m: m.group(1) + dst_audit.name,
    text, count=1,
)
dst.write_text(text, encoding="utf-8")

# audit 쪽 sidecar도 함께 파생한다 — audit_pairing_errors가 audit frontmatter의 `payload:`
# 역참조를 payload_name과 대조하므로, 원본 audit을 그대로 복사만 하면 "audit payload
# 'interview-brief-valid.md' != 'interview-brief-long.md'"로 역시 상한과 무관한 red가 난다.
audit_text = src_audit.read_text(encoding="utf-8")
audit_text = re.sub(
    r'(?m)^(payload:\s*).*$',
    lambda m: m.group(1) + dst.name,
    audit_text, count=1,
)
dst_audit.write_text(audit_text, encoding="utf-8")
PY
# 이 층은 fixture 형태에 의존하므로, 파일이 안 만들어졌으면 침묵하지 않는다.
if [[ -f "$TMP/interview-brief-long.md" && -f "$TMP/interview-brief-long.audit.md" ]]; then
  out="$(python3 "$SCRIPT" gate "$TMP/interview-brief-long.md" 2>&1)"; rc=$?
  if [[ $rc -eq 0 ]]; then
    ok "L3: 200자 statement 가 상한에 안 걸린다 (rc=0)"
  else
    no "L3: 200자 statement 가 여전히 상한에 걸린다 (rc=$rc): $out"
  fi
  # 메시지 단언도 보조로 남긴다 — rc가 진단이 필요할 때 원인을 즉시 보여준다.
  printf '%s' "$out" | grep -q 'hard cap' \
    && no "L3/message: 'hard cap' 리터럴이 여전히 나온다" \
    || ok "L3/message: 'hard cap' 리터럴 없음"
else
  no "L3: 테스트 픽스처 생성 실패 — 이 층은 아무것도 재지 않았다"
fi

exit $fail
