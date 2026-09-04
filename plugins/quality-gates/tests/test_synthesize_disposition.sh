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
# 코퍼스는 상수다(도출이 아니다). `# guards:` 는 `plugins/*/scripts/…` 글롭으로
# spec-distill 쪽 심볼릭 링크 사본까지 덮는다 — 그러나 "선언 ⊇ 실제는 무해"가
# 이 리포의 무조건 규약은 «아니다»(R5, adjudication-topology Task 15c 정정):
# `test_guards_coverage_bidirectional.sh` 의 방향 B 는 스캔 결과를 하나도 안
# 덮는 글롭을 명시적으로 FAIL 시킨다. 이 글롭이 지금 무해한 것은 quality-gates
# 쪽 사본(스캔 목록 안)에도 걸려 최소 1건을 맞기 때문이지, 초과분 자체가
# 면제돼서가 아니다 — 스캔 목록 밖만 가리키는 글롭을 추가하면 방향 B 가 FAIL
# 한다. `--emit-scanned` 는 그와 별개다 — 그 값은 "선언 ⊇ 실제"의 **실제**
# 쪽이라 넓히면 안 된다(수정 라운드 2, m1). `SCRIPT` 는 오직
# `plugins/quality-gates/scripts/synthesize_findings.py` 하나이고, 파이썬이
# import 로 실제로 여는 sibling 은 **그 디렉터리 안**의 심볼릭 링크뿐이다
# (`sys.path[0]` 는 스크립트 자신의 디렉터리) — `plugins/spec-distill/scripts/`
# 쪽 두 사본은 이 락이 실행하는 그 어떤 python3 호출도 열지 않는다. 다섯만 낸다.
if [ "${1:-}" = "--emit-scanned" ]; then
  cat <<'SCANNED'
plugins/quality-gates/scripts/synthesize_findings.py
shared/adjudication/adjudication.py
shared/adjudication/render_disposition.py
plugins/quality-gates/scripts/adjudication.py
plugins/quality-gates/scripts/render_disposition.py
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

# ── clean(kept=0) 렌더 분기 — 수정 라운드 2 (C1) ──────────────────────────
# `render()` 는 disposition_lines() 를 «두» 자리에서 부른다: :482(findings 가
# 비었을 때 — "No high-confidence findings" clean 분기)와 :532(kept>0). 도출
# 확인: 파일 전체에 disposition_lines( 호출이 정확히 이 둘뿐이다(제3의 자리
# 없음, main() 은 render() 를 한 번만 부른다). 위 여섯 assert_grep 은 전부
# `$OUT` 하나에 걸려 있고, 그 findings.yaml 은 CRITICAL 등 실채택 항목을
# 남겨 :532 분기만 태운다 — :482 분기는 이 락이 한 번도 실행한 적이 없었다
# (코디네이터 재현: :482 에서 plumb_line 을 지워도 이 파일을 코퍼스로 갖는
# 락 8개 전부 GREEN, 같은 제거를 :532 에서 하면 이 파일이 5/6 RED 로 잡음 —
# 두 분기 중 하나만 잠겨 있었다는 뜻). 배관 손실이 「clean」위에서 사라지는
# 것이 가장 위험하다 — 입력 실패·항목 파손이 몇 건이든 화면에서 통째로
# 증발하는데 게이트는 clean 을 찍는다.
cat > "$TMPD/clean_findings.yaml" <<'YAML'
findings:
  - "CRITICAL: bare string finding — 매핑이 아니다"
  - {agent: sec, file: low.py, line: 9, severity: SUGGESTION, summary: low-conf, confidence: 2}
  - {agent: sec, file: rej.py, line: 3, severity: IMPORTANT, summary: rejected-one, confidence: 8}
YAML
cat > "$TMPD/clean_adversarial.yaml" <<'YAML'
verdicts:
  - {finding_id: "sec-rej.py-3", verdict: reject}
YAML
OUT_CLEAN="$(PYTHONDONTWRITEBYTECODE=1 python3 "$SCRIPT" \
        --findings "$TMPD/clean_findings.yaml" \
        --adversarial "$TMPD/clean_adversarial.yaml" 2>"$TMPD/err_clean.txt")"
note "$OUT_CLEAN"

assert_grep "$OUT_CLEAN" 'No high-confidence findings' \
  "clean(kept=0) 렌더 분기를 실제로 태운다 (판정 대상 확인 — 안 태우면 아래는 공허)"
assert_grep "$OUT_CLEAN" '기각 [1-9]'   "clean 분기에서도 기각이 값으로 실린다"
assert_grep "$OUT_CLEAN" '억제 [1-9]'   "clean 분기에서도 억제가 값으로 실린다"
assert_grep "$OUT_CLEAN" '미판정 [1-9]' "clean 분기에서도 판정자 부재가 값으로 실린다"
assert_grep "$OUT_CLEAN" '\*\*배관 손실:\*\* [1-9]' \
  "clean 분기에서도 배관 손실이 값으로 실린다 (가장 위험한 자리 — 여기가 비면 사용자는 clean 으로 읽는다)"

finish
