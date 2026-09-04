#!/usr/bin/env bash
# guards: plugins/quality-gates/scripts/synthesize_findings.py shared/adjudication/adjudication.py shared/adjudication/render_disposition.py plugins/*/scripts/adjudication.py plugins/*/scripts/render_disposition.py
#
# 처분 여섯 종류가 각각 최소 1건씩 세어지는지 결정론 fixture 로 검사한다.
#
# 수정 라운드 1 (F3) — 원래 선언은 SCRIPT 하나뿐이었다. 이 스크립트가
# `from adjudication import Ledger` · `from render_disposition import
# disposition_lines` 로 실제 렌더·회계를 수행하므로(§ 아래 여섯 assert_grep
# 이 그 렌더의 «값»을 직접 검사한다), 그 두 모듈이 이 락이 실제로 지키는
# 것이다. `shared/adjudication/*.py` 를 고친 diff 는 거기서 나타나고(git
# blob 이 그 경로에 산다), `plugins/*/scripts/{adjudication,render_disposition}.py`
# 는 그 두 파일의 배포 심볼릭 링크 사본이다(`git ls-files -s` mode 120000,
# quality-gates·spec-distill 둘 다) — 사본 자체가 재구성되는 드문 경우까지
# 같은 코퍼스로 선언한다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../../shared/tests/assert.sh"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/quality-gates/scripts/synthesize_findings.py"

# `--emit-scanned` — test_guards_coverage_bidirectional.sh 가 읽는다. 이 락의
# 코퍼스는 상수다(도출이 아니다) — 위 `# guards:` 와 같은 일곱 경로를 그대로
# 낸다. 실행 시 파이썬이 실제로 여는 파일은 심볼릭 링크 쪽(SCRIPT 와 같은
# 디렉터리의 sibling import) 이지만, 내용이 갈리는 원본은 `shared/adjudication/`
# 쪽이라 둘 다 낸다 — 어느 쪽이 바뀌어도 이 락의 여섯 assert_grep 값이
# 달라질 수 있다는 것이 이 락이 실제로 의존하는 사실이다.
if [ "${1:-}" = "--emit-scanned" ]; then
  cat <<'SCANNED'
plugins/quality-gates/scripts/synthesize_findings.py
shared/adjudication/adjudication.py
shared/adjudication/render_disposition.py
plugins/quality-gates/scripts/adjudication.py
plugins/spec-distill/scripts/adjudication.py
plugins/quality-gates/scripts/render_disposition.py
plugins/spec-distill/scripts/render_disposition.py
SCANNED
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
