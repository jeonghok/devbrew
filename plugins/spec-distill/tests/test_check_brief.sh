#!/usr/bin/env bash
# check_brief.py gate (v0.23.0 2파일 계약) — payload 8섹션 + audit 5섹션.
# T1/T2  — 각 섹션 제거 시 red (payload 8 / audit 5), 런타임 생성 픽스처.
# T7     — audit_file 부재 / traversal / 파일 부재 → red ×3 (fail-closed, AC9).
# T13    — Coverage Ledger가 audit에 없으면 red (AC10).
# T15    — 정상 쌍은 green (happy-path 스모크 — 이후 모든 태스크에서 green 유지).
# F3/F4/F5/F8/F9 — 기존 실패 클래스를 새 좌표로 이관.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/check_brief.py"
FX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# 런타임 섹션-제거 픽스처용 임시 디렉토리.
# macOS bash 3.2: mktemp 대입 실패 시 빈 문자열이 `rm -rf`에 흘러가면 repo가 지워진다 → || exit 1 필수.
TMPD="$(mktemp -d)" || exit 1
[[ -n "$TMPD" && -d "$TMPD" ]] || exit 1
# TMPD2는 T7/traversal(parent-dir) 전용 — 통제된 우리 소유 디렉토리라야 그 부모에 decoy를
# 놓고 rm -rf해도 안전하다(mktemp의 실제 시스템 부모 디렉토리를 절대 rm -rf하지 않는다).
# set -u 하에서 미생성 시점에도 trap이 죽지 않도록 빈 문자열로 선언 + ${TMPD2:-} 폴백.
TMPD2=""
trap 'rm -rf "$TMPD" "${TMPD2:-}"' EXIT

# T15: 정상 payload + audit 쌍 → green
python3 "$SCRIPT" gate "$FX/interview-brief-valid.md" >/dev/null 2>&1 \
  && note PASS "T15: 정상 payload+audit 쌍이 게이트를 통과" \
  || note FAIL "T15: 정상 쌍은 통과해야 한다"

# T1: payload 8섹션을 각각 제거 → red ×8
for hdr in "0. 한눈에" "1. Goal · Non-goal" "2. 제약" "3. Open Questions" \
           "4. External Landscape" "5. 기각 · Blind Spots" "6. 사용자 원문" "7. Next Action"; do
  cp "$FX/interview-brief-valid.md" "$TMPD/p.md"
  cp "$FX/interview-brief-valid.audit.md" "$TMPD/interview-brief-valid.audit.md"
  # 헤더 줄만 지운다 — 섹션 본문은 남겨 "헤더 존재 검사"가 실제로 이빨을 갖는지 본다.
  python3 - "$TMPD/p.md" "$hdr" <<'PY'
import sys, pathlib
p, hdr = pathlib.Path(sys.argv[1]), sys.argv[2]
lines = p.read_text(encoding="utf-8").splitlines(True)
p.write_text("".join(l for l in lines if l.strip() != f"## {hdr}"), encoding="utf-8")
PY
  python3 "$SCRIPT" gate "$TMPD/p.md" >/dev/null 2>&1 \
    && note FAIL "T1: payload §$hdr 제거가 통과됨" \
    || note PASS "T1: payload §$hdr 제거 → red"
done

# T2: audit 5섹션을 각각 제거 → red ×5
for hdr in "1. Coverage Ledger" "2. Budget" "3. Steelman 원문" "4. 게이트 실행 기록" "5. 프로세스 로그"; do
  cp "$FX/interview-brief-valid.md" "$TMPD/p.md"
  cp "$FX/interview-brief-valid.audit.md" "$TMPD/interview-brief-valid.audit.md"
  python3 - "$TMPD/interview-brief-valid.audit.md" "$hdr" <<'PY'
import sys, pathlib
p, hdr = pathlib.Path(sys.argv[1]), sys.argv[2]
lines = p.read_text(encoding="utf-8").splitlines(True)
p.write_text("".join(l for l in lines if l.strip() != f"## {hdr}"), encoding="utf-8")
PY
  python3 "$SCRIPT" gate "$TMPD/p.md" >/dev/null 2>&1 \
    && note FAIL "T2: audit §$hdr 제거가 통과됨" \
    || note PASS "T2: audit §$hdr 제거 → red"
done

# T7: audit_file 부재 / 파일 부재 → red ×2 (AC9 fail-closed)
cp "$FX/interview-brief-valid.audit.md" "$TMPD/interview-brief-valid.audit.md"
for variant in absent missing; do
  cp "$FX/interview-brief-valid.md" "$TMPD/p.md"
  case "$variant" in
    absent)  sed -i.bak '/^audit_file:/d' "$TMPD/p.md" ;;
    missing) sed -i.bak 's|^audit_file:.*|audit_file: __no_such_audit__.md|' "$TMPD/p.md" ;;
  esac
  rm -f "$TMPD/p.md.bak"
  python3 "$SCRIPT" gate "$TMPD/p.md" >/dev/null 2>&1 \
    && note FAIL "T7/$variant: audit_file 결함이 통과됨 (fail-open)" \
    || note PASS "T7/$variant: audit_file 결함 → red"
done

# T7/traversal(parent-dir): basename 가드가 exit code가 아니라 실제 메시지로 발화하는지 확인.
# decoy를 진짜로 traversal target(TMPD2/interview-brief-valid.audit.md)에 놓는다 — 가드가
# 없으면 "file not found"로 위장되지 않고 코드 그대로 그 decoy를 읽어 {"pass": true}로
# 뚫린다(리뷰가 mutation으로 실증). TMPD2는 우리가 mktemp -d로 만든 전용 디렉토리이므로
# 그 부모(TMPD2 자체)에 decoy를 두고 통째로 rm -rf해도 안전 — 시스템 공유 tmp 부모를
# 건드리지 않는다.
TMPD2="$(mktemp -d)" || exit 1
[[ -n "$TMPD2" && -d "$TMPD2" ]] || exit 1
mkdir -p "$TMPD2/inner"
cp "$FX/interview-brief-valid.audit.md" "$TMPD2/interview-brief-valid.audit.md"
cp "$FX/interview-brief-valid.md" "$TMPD2/inner/p.md"
sed -i.bak 's|^audit_file:.*|audit_file: ../interview-brief-valid.audit.md|' "$TMPD2/inner/p.md"
rm -f "$TMPD2/inner/p.md.bak"
out="$(python3 "$SCRIPT" gate "$TMPD2/inner/p.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'not a basename'; } \
  && note PASS "T7/traversal(parent-dir): decoy 존재해도 basename 가드가 발화 (teeth 증명)" \
  || note FAIL "T7/traversal(parent-dir): basename 가드 메시지를 못 찾음"

# T7/traversal(절대경로·서브디렉토리): 스펙이 명시한 3개 거부 케이스를 모두 메시지로 확인.
for variant2 in abs subdir; do
  cp "$FX/interview-brief-valid.md" "$TMPD/p.md"
  case "$variant2" in
    abs)    sed -i.bak 's|^audit_file:.*|audit_file: /etc/__no_such_audit__.md|' "$TMPD/p.md" ;;
    subdir) sed -i.bak 's|^audit_file:.*|audit_file: a/__no_such_audit__.md|' "$TMPD/p.md" ;;
  esac
  rm -f "$TMPD/p.md.bak"
  out="$(python3 "$SCRIPT" gate "$TMPD/p.md" 2>/dev/null)"; rc=$?
  { [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'not a basename'; } \
    && note PASS "T7/traversal($variant2): basename 가드가 발화" \
    || note FAIL "T7/traversal($variant2): basename 가드 메시지를 못 찾음"
done

# R2/AC4: 무인용 landscape → red
python3 "$SCRIPT" gate "$FX/interview-brief-no-landscape.md" >/dev/null 2>&1 \
  && note FAIL "무인용 landscape가 통과됨 (R2/AC4)" \
  || note PASS "무인용 landscape가 종료를 차단 (R2/AC4)"

# F3: §4 헤더만 있고 항목 없음 → red
python3 "$SCRIPT" gate "$FX/interview-brief-empty-landscape.md" >/dev/null 2>&1 \
  && note FAIL "F3: 빈 External Landscape가 통과됨" \
  || note PASS "F3: 빈 External Landscape가 종료를 차단"

# R3/AC5: §5 verdict 항목 형식 미달 → red
python3 "$SCRIPT" gate "$FX/interview-brief-unchallenged.md" >/dev/null 2>&1 \
  && note FAIL "형식 미달 verdict 항목이 통과됨 (R3/AC5)" \
  || note PASS "형식 미달 verdict 항목이 종료를 차단 (R3/AC5)"

# PN4: containment 검사가 누락 URL을 지목
python3 "$SCRIPT" skepticism "$FX/interview-brief-unchallenged.md" 2>/dev/null | grep -q 'no-url' \
  && note PASS "PN4: skepticism containment가 누락 URL을 플래그" \
  || note FAIL "PN4: skepticism containment가 누락 URL을 못 잡음"

# AC2: 섹션 부재 → red
python3 "$SCRIPT" gate "$FX/interview-brief-missing-section.md" >/dev/null 2>&1 \
  && note FAIL "섹션 부재가 통과됨 (AC2)" || note PASS "섹션 부재가 종료를 차단 (AC2)"
python3 "$SCRIPT" gate "$FX/interview-brief-missing-blind-spot.md" >/dev/null 2>&1 \
  && note FAIL "§5 부재가 통과됨" || note PASS "§5 부재가 종료를 차단"

# T19 / R4: §5 기각 0건 → red, N/A sentinel → green
python3 "$SCRIPT" gate "$FX/interview-brief-empty-tried.md" >/dev/null 2>&1 \
  && note FAIL "T19: 기각 0건 + sentinel 없음이 통과됨 (R4 증발)" \
  || note PASS "T19: 기각 0건 + sentinel 없음 → red (R4 이관 확인)"
python3 "$SCRIPT" gate "$FX/interview-brief-na-tried.md" >/dev/null 2>&1 \
  && note PASS "T19: 기각 N/A sentinel → green (R4 edge)" \
  || note FAIL "T19: N/A sentinel은 통과해야 한다"

# F4: 펜스 안 헤더는 게이트를 만족시키지 못한다
python3 "$SCRIPT" gate "$FX/interview-brief-fenced-sections.md" >/dev/null 2>&1 \
  && note FAIL "F4: 펜스 안 섹션 헤더가 통과됨" || note PASS "F4: 펜스 안 헤더는 불충분"

# F5: 읽을 수 없는 brief → 구조화 JSON + exit 1, traceback 금지
out="$(python3 "$SCRIPT" gate "$FX/__no_such_brief__.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q '"pass": false'; } \
  && note PASS "F5: 읽기 실패 → 구조화 JSON + exit 1" \
  || note FAIL "F5: 읽기 실패는 구조화 JSON이어야 한다"
printf '%s' "$out" | grep -qi 'Traceback' \
  && note FAIL "F5: traceback이 stdout으로 샜다" || note PASS "F5: traceback 누출 없음"

# F9-A: frontmatter 검증 실패 클래스
python3 "$SCRIPT" gate "$FX/interview-brief-bad-frontmatter.md" >/dev/null 2>&1 \
  && note FAIL "F9-A: 잘못된 frontmatter가 통과됨 (AC1)" \
  || note PASS "F9-A: 잘못된 frontmatter가 종료를 차단 (AC1)"

# F8/AC8: web 켜짐 → URL 없는 §4/§5는 red / kill switch → 완화
python3 "$SCRIPT" gate "$FX/interview-brief-web-disabled.md" >/dev/null 2>&1 \
  && note FAIL "F8: web 켜짐 상태에서 URL 없는 항목이 통과됨" \
  || note PASS "F8: web 켜짐 상태에서 URL 없는 항목이 차단됨"
DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 python3 "$SCRIPT" gate "$FX/interview-brief-web-disabled.md" >/dev/null 2>&1 \
  && note PASS "AC8: web 비활성 시 URL 요구 완화" \
  || note FAIL "AC8: web 비활성 시 URL 요구가 완화돼야 한다"

# AC10 / C9: Coverage Ledger는 audit에서 검증된다
python3 "$SCRIPT" gate "$FX/interview-brief-floor-open.md" >/dev/null 2>&1 \
  && note FAIL "AC10: floor open이 통과됨" || note PASS "AC10: floor open이 차단됨"
python3 "$SCRIPT" gate "$FX/interview-brief-floor-evidence-empty.md" >/dev/null 2>&1 \
  && note FAIL "AC10: floor evidence 공백이 통과됨" || note PASS "AC10: floor evidence 공백이 차단됨"
python3 "$SCRIPT" gate "$FX/interview-brief-missing-derived-row.md" >/dev/null 2>&1 \
  && note FAIL "C9: derived 행·sentinel 부재가 통과됨" || note PASS "C9: derived 부재가 차단됨"
python3 "$SCRIPT" gate "$FX/interview-brief-derived-sentinel.md" >/dev/null 2>&1 \
  && note PASS "C9: derived N/A sentinel → green" || note FAIL "C9: derived sentinel은 통과해야 한다"

# T13: audit §1 Coverage Ledger가 비어 있음 → red
python3 "$SCRIPT" gate "$FX/interview-brief-audit-no-coverage.md" >/dev/null 2>&1 \
  && note FAIL "T13: 빈 audit Coverage Ledger가 통과됨" \
  || note PASS "T13: 빈 audit Coverage Ledger → red (AC10)"

# coverage 서브커맨드가 audit을 스스로 해석
python3 "$SCRIPT" coverage "$FX/interview-brief-floor-open.md" 2>/dev/null | grep -q 'floor:landscape' \
  && note PASS "coverage 서브커맨드가 audit을 해석해 열린 floor를 플래그" \
  || note FAIL "coverage 서브커맨드가 열린 floor를 플래그해야 한다"

# AC9: audit_file 값 뒤 YAML 인라인 주석(템플릿의 실제 라인 모양)이 파싱을 깨서는 안 된다.
python3 "$SCRIPT" gate "$FX/interview-brief-audit-file-comment.md" >/dev/null 2>&1 \
  && note PASS "audit_file 인라인 주석이 있어도 게이트 통과 (템플릿 라인 형태)" \
  || note FAIL "audit_file 인라인 주석이 파싱을 깨서는 안 된다"

# F5 대칭: coverage 서브커맨드도 audit을 못 읽으면(디렉토리 등) traceback 없이 구조화 JSON + exit 1.
cp "$FX/interview-brief-valid.md" "$TMPD/p.md"
mkdir -p "$TMPD/not-a-file.audit.md"
sed -i.bak 's|^audit_file:.*|audit_file: not-a-file.audit.md|' "$TMPD/p.md"
rm -f "$TMPD/p.md.bak"
out="$(python3 "$SCRIPT" coverage "$TMPD/p.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q '"failures"'; } \
  && note PASS "coverage: 읽을 수 없는 audit(디렉토리) → 구조화 JSON + exit 1" \
  || note FAIL "coverage: 읽을 수 없는 audit도 구조화 JSON이어야 한다"
printf '%s' "$out" | grep -qi 'Traceback' \
  && note FAIL "coverage: traceback이 stdout으로 샜다" || note PASS "coverage: traceback 누출 없음"
rmdir "$TMPD/not-a-file.audit.md" 2>/dev/null || true

# --- Task 2: user_sourced_items 스키마 + bijection C + confirmed sentinel ---

# T3: user_sourced_items 부재 → red
python3 "$SCRIPT" gate "$FX/interview-brief-no-items.md" >/dev/null 2>&1 \
  && note FAIL "T3: user_sourced_items 부재가 통과됨" || note PASS "T3: user_sourced_items 부재 → red"

# T4: evidence 없음 → red
python3 "$SCRIPT" gate "$FX/interview-brief-item-no-evidence.md" >/dev/null 2>&1 \
  && note FAIL "T4: evidence 없는 항목이 통과됨" || note PASS "T4: evidence 없는 항목 → red"

# T5: source: inferred가 리스트에 있음 → red
python3 "$SCRIPT" gate "$FX/interview-brief-item-inferred.md" >/dev/null 2>&1 \
  && note FAIL "T5: source: inferred가 통과됨 (리스트 이름과 내용 불일치)" \
  || note PASS "T5: source: inferred → red"

# T6: 잘못된 status / source → red ×2
python3 "$SCRIPT" gate "$FX/interview-brief-item-bad-status.md" >/dev/null 2>&1 \
  && note FAIL "T6: 잘못된 status가 통과됨" || note PASS "T6: 잘못된 status → red"
python3 "$SCRIPT" gate "$FX/interview-brief-item-bad-source.md" >/dev/null 2>&1 \
  && note FAIL "T6: 잘못된 source가 통과됨" || note PASS "T6: 잘못된 source → red"

# T22: bijection C — evidence: S9인데 §6에 S9 없음 → red
python3 "$SCRIPT" gate "$FX/interview-brief-evidence-dangling.md" >/dev/null 2>&1 \
  && note FAIL "T22: dangling evidence가 통과됨 (bijection C 미집행)" \
  || note PASS "T22: dangling evidence → red (bijection C)"

# T23: statement 161자 → red / 160자 → green (hard cap)
python3 "$SCRIPT" gate "$FX/interview-brief-statement-161.md" >/dev/null 2>&1 \
  && note FAIL "T23: 161자 statement가 통과됨 (cap이 hard가 아님)" \
  || note PASS "T23: 161자 statement → red"
python3 "$SCRIPT" gate "$FX/interview-brief-statement-160.md" >/dev/null 2>&1 \
  && note PASS "T23: 160자 statement → green (경계 포함)" \
  || note FAIL "T23: 160자는 통과해야 한다 (off-by-one)"

# T14: confirmed 0건 + sentinel 없음 → red / 있음 → green
python3 "$SCRIPT" gate "$FX/interview-brief-confirmed-zero.md" >/dev/null 2>&1 \
  && note FAIL "T14: confirmed 0건 + sentinel 없음이 통과됨 (확인 게이트 우회)" \
  || note PASS "T14: confirmed 0건 + sentinel 없음 → red"
python3 "$SCRIPT" gate "$FX/interview-brief-confirmed-zero-sentinel.md" >/dev/null 2>&1 \
  && note PASS "T14: confirmed 0건 + sentinel → green" \
  || note FAIL "T14: sentinel이 있으면 통과해야 한다"

# --- Task 3: bijection B (body §2 ↔ frontmatter) ---

# T8: 한쪽에만 있는 id → red ×2 (양방향)
python3 "$SCRIPT" gate "$FX/interview-brief-body-only-id.md" >/dev/null 2>&1 \
  && note FAIL "T8: body §2에만 있는 id가 통과됨" || note PASS "T8: body-only id → red"
python3 "$SCRIPT" gate "$FX/interview-brief-fm-only-id.md" >/dev/null 2>&1 \
  && note FAIL "T8: frontmatter에만 있는 id가 통과됨" || note PASS "T8: frontmatter-only id → red"

# T9: 기호↔source / status 불일치 → red ×2
python3 "$SCRIPT" gate "$FX/interview-brief-marker-mismatch.md" >/dev/null 2>&1 \
  && note FAIL "T9: 기호↔source 불일치가 통과됨 (☑ laundering)" || note PASS "T9: 기호↔source 불일치 → red"
python3 "$SCRIPT" gate "$FX/interview-brief-status-mismatch.md" >/dev/null 2>&1 \
  && note FAIL "T9: status 불일치가 통과됨" || note PASS "T9: status 불일치 → red"

# T21: statement 내용 drift → red / 공백·강조기호만 다름 → green
python3 "$SCRIPT" gate "$FX/interview-brief-statement-drift.md" >/dev/null 2>&1 \
  && note FAIL "T21: statement 내용 drift가 통과됨 (같은 라벨, 다른 제약)" \
  || note PASS "T21: statement 내용 drift → red"
python3 "$SCRIPT" gate "$FX/interview-brief-statement-whitespace.md" >/dev/null 2>&1 \
  && note PASS "T21: 공백·강조기호 차이는 정규화로 흡수 → green" \
  || note FAIL "T21: 정규화가 공백·강조 차이를 흡수해야 한다"

# T24: ⟨S<N>⟩ 불일치 / 접미 부재 → red ×2
python3 "$SCRIPT" gate "$FX/interview-brief-anchor-mismatch.md" >/dev/null 2>&1 \
  && note FAIL "T24: ⟨S<N>⟩ 불일치가 통과됨" || note PASS "T24: ⟨S<N>⟩ 불일치 → red"
python3 "$SCRIPT" gate "$FX/interview-brief-anchor-absent.md" >/dev/null 2>&1 \
  && note FAIL "T24: ⟨S<N>⟩ 접미 부재가 통과됨 (요약 신호 소실)" || note PASS "T24: ⟨S<N>⟩ 부재 → red"

# 형식 미달 §2 항목은 조용히 사라지지 않고 loud하게 red가 된다
python3 "$SCRIPT" gate "$FX/interview-brief-body-malformed.md" >/dev/null 2>&1 \
  && note FAIL "형식 미달 §2 항목이 통과됨 (silent drop)" || note PASS "형식 미달 §2 항목 → red (loud)"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
