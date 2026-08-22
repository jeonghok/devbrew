#!/usr/bin/env bash
# v0.33.0 — interview brief 분량 상한 제거의 회귀 락.
#
# 무엇이 사라졌는가: 템플릿의 절별 `≤N줄` 예산 7개(합 137)와 `check_brief.py`의
# `LINE_TRIPWIRE = 150` advisory + `payload_body_lines_excl_verbatim` 지표 +
# `metrics` 서브커맨드.
#
# 왜: 그 상한의 원래 목적은 "짧게"가 아니라 *"brief가 해답을 미리 정해버리지 않게"*
# 였다(2026-07-25-spec-distill-brief-format-producer-design.md §5.3 + Implicit
# context). 줄 수는 그 목적의 **대리 지표**인데 대상을 안 잰다 — §3 Open Questions
# (과잉결정의 정반대 절)를 성실히 채운 brief가 예산을 태워 벌을 받는 방향으로 틀렸다.
# 과잉결정은 이제 대리 지표가 아니라 직접 측정기가 본다: `brief-readback`이 묻는
# 두 번째 질문이 *"무엇이 확정이고 무엇이 아직 열려 있는가"* 다(v0.24.0에 도입 —
# 137/150은 그 앞 버전 v0.23.0의 산물이라, 대리 지표가 먼저 있었고 직접 측정기가
# 나중에 왔다).
#
# ── 이 락의 구조 ─────────────────────────────────────────────────────────
# 세 층이다. **부재 검사만으로 된 락은 대상 파일을 통째로 지워도 통과하므로**,
# 층 1(양성 대조)이 "이 락이 실제로 그 코퍼스를 읽었다"를 먼저 증명한다.
#
#   층 1 양성 대조 — 템플릿 8섹션 헤더 + gate() 존재. 파일이 비거나 옮겨지면 RED.
#   층 2 보존      — 숫자와 **함께** 지워지면 안 되는 계약 3개. 섹션 윈도우 안에서
#                    본다(파일 전체 grep이면 주석·다른 절이 대신 만족시킨다).
#   층 3 부재      — 상한 재삽입 차단. 개념 별칭(`최대 N줄`·`N줄 이내`)까지 덮는다 —
#                    식별자만 잠그면 같은 것을 다른 이름으로 부른 재삽입이 살아남는다.
#   층 4 행동      — grep이 아니라 실제 호출. gate JSON에 지표 키가 없고 `metrics`
#                    서브커맨드가 거부되는지. 문서가 아니라 계약을 잰다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TPL="$REPO_ROOT/plugins/spec-distill/templates/interview-brief-template.md"
GATE="$REPO_ROOT/plugins/spec-distill/scripts/check_brief.py"
FX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"

. "$REPO_ROOT/shared/tests/assert.sh"

# section_window <file> <n> → `## n.` 헤더부터 다음 `## <숫자>.` 헤더 직전까지.
section_window() {
  awk -v n="$2" '
    $0 ~ ("^## " n "\\.") { on = 1; print; next }
    on && /^## [0-9]+\./   { on = 0 }
    on                      { print }
  ' "$1"
}

# ── 층 1: 양성 대조 ───────────────────────────────────────────────────────
for n in 0 1 2 3 4 5 6 7; do
  assert_file_grep "$TPL" "^## $n\." "양성대조: 템플릿에 §$n 헤더 존재"
done
assert_file_grep "$GATE" "^def gate\(" "양성대조: check_brief.py에 gate() 존재"

# ── 층 2: 숫자와 함께 지워지면 안 되는 계약 ────────────────────────────────
w0="$(section_window "$TPL" 0)"
assert_grep "$w0" '이 절은 요약이다' \
  "§0 보존: '이 절은 요약이다' — ≤15줄이 대리하던 계약"
assert_grep "$w0" '여기만 읽고도' \
  "§0 보존: '다음 세션이 여기만 읽고도 방향을 잡을 수 있어야'"

w2="$(section_window "$TPL" 2)"
assert_grep "$w2" '한 항목의 렌더' \
  "§2 보존: 한 줄 = frontmatter 한 항목의 렌더 (bijection B 계약)"

w4="$(section_window "$TPL" 4)"
assert_grep "$w4" '1항목 = 1줄' \
  "§4 보존: 1항목 = 1줄 (분량이 아니라 렌더 계약)"

# ── 층 3: 상한 부재 (개념 별칭 포함) ──────────────────────────────────────
# `1항목 = 1줄`은 이 패턴에 걸리지 않는다 — 첫 대안은 ≤/최대 접두를, 둘째 대안은
# 이내/이하/까지 접미를 요구한다.
CAP_RE='(≤|최대 ?)[0-9]+ *줄|[0-9]+ *줄 *(이내|이하|까지)'
assert_file_absent "$TPL" "$CAP_RE" \
  "부재: 템플릿에 절별 줄 예산 없음 (별칭 '최대 N줄'·'N줄 이내' 포함)"
assert_file_absent "$GATE" 'LINE_TRIPWIRE' \
  "부재: check_brief.py에 LINE_TRIPWIRE 상수 없음"
assert_file_absent "$GATE" 'payload_body_lines_excl_verbatim' \
  "부재: check_brief.py에 분량 지표 함수/키 없음"
assert_file_absent "$GATE" '트립와이어' \
  "부재: check_brief.py에 트립와이어 advisory 문구 없음"

# ── 층 4: 행동 ────────────────────────────────────────────────────────────
out="$(python3 "$GATE" gate "$FX/interview-brief-valid.md" 2>/dev/null)"
assert_grep "$out" '"pass"' \
  "행동/양성대조: gate가 정상 brief에 JSON을 낸다 (아래 부재 검사의 전제)"
assert_not_grep "$out" 'payload_body_lines_excl_verbatim' \
  "행동: gate JSON에 분량 지표 키가 없다"
# advisories 채널 자체는 남아야 한다 — DEVBREW_SPEC_DISTILL_DISABLE_WEB 킬 스위치가
# 같은 채널로 강등을 알린다. 분량 상한을 걷어내며 이걸 같이 끊으면 graceful
# degradation의 loud logging이 조용해진다.
assert_grep "$out" '"advisories"' \
  "행동: advisories 채널 유지 (web 킬 스위치 통보용)"

rc=0
python3 "$GATE" metrics "$FX/interview-brief-valid.md" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "64" "행동: metrics 서브커맨드가 unknown으로 거부된다 (rc 64)"

finish
