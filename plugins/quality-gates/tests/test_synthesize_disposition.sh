#!/usr/bin/env bash
# guards: plugins/quality-gates/scripts/synthesize_findings.py
#
# 처분 여섯 종류가 각각 최소 1건씩 세어지는지 결정론 fixture 로 검사한다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../../shared/tests/assert.sh"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/quality-gates/scripts/synthesize_findings.py"

# `--emit-scanned` — test_guards_coverage_bidirectional.sh 가 읽는다. 이 락의
# 코퍼스는 처음부터 파일 «하나»다(위 SCRIPT) — 도출이 아니라 상수이므로 다시
# 계산할 것이 없다. 같은 변수를 그대로 낸다.
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' "${SCRIPT#"$REPO_ROOT"/}"
  exit 0
fi

TMPD="$(mktemp -d -t qgdisp-XXXXXX)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

cat > "$TMPD/findings.yaml" <<'YAML'
findings:
  - {agent: sec, file: a.py, line: 1, severity: CRITICAL, summary: kept, confidence: 9}
  - {agent: sec, file: b.py, line: 2, severity: IMPORTANT, summary: rejected, confidence: 8}
  - {agent: sec, file: c.py, line: 3, severity: SUGGESTION, summary: low, confidence: 2}
  - {agent: rev, file: a.py, line: 1, severity: CRITICAL, summary: dup, confidence: 7}
  - "형태 불량 — 매핑이 아니다"
  - {agent: sec, file: d.py, line: 4, severity: IMPORTANT, summary: 판정없음, confidence: 8}
YAML

cat > "$TMPD/adversarial.yaml" <<'YAML'
verdicts:
  - {finding_id: "sec-a.py-1", verdict: confirm}
  - {finding_id: "sec-b.py-2", verdict: reject}
  - {finding_id: "sec-c.py-3", verdict: confirm}
  - {finding_id: "rev-a.py-1", verdict: confirm}
new_findings: "리스트가 아니다 — 컨테이너 소실"
YAML

OUT="$(PYTHONDONTWRITEBYTECODE=1 python3 "$SCRIPT" \
        --findings "$TMPD/findings.yaml" \
        --adversarial "$TMPD/adversarial.yaml" 2>"$TMPD/err.txt")"
note "$OUT"

assert_grep "$OUT" '수용 [1-9]'      "수용이 세어진다 (accept — T1 표에 없던 행)"
assert_grep "$OUT" '기각 [1-9]'      "기각이 세어진다 (reject)"
assert_grep "$OUT" '억제 [1-9]'      "억제가 세어진다 (suppressed — D4)"
assert_grep "$OUT" '흡수 [1-9]'      "흡수가 세어진다 (absorbed — dedup)"
assert_grep "$OUT" '미판정 [1-9]'    "판정자 부재가 세어진다 (hold)"
assert_grep "$OUT" '\*\*배관 손실:\*\* [1-9]' "항목 파손 + 입력 실패가 배관 칸으로 간다"

finish
