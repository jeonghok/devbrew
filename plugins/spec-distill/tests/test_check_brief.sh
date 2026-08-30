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

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

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
  && ok "T15: 정상 payload+audit 쌍이 게이트를 통과" \
  || no "T15: 정상 쌍은 통과해야 한다"

# T1: payload 8섹션을 각각 제거 → red ×8
for hdr in "0. 한눈에" "1. Goal · Non-goal" "2. 제약" "3. Open Questions" \
           "4. External Landscape" "5. 기각 · Blind Spots" "6. 사용자 원문" "7. Next Action"; do
  cp "$FX/interview-brief-valid.md" "$TMPD/p.md"
  cp "$FX/interview-brief-valid.audit.md" "$TMPD/p.audit.md"
  sed -i.bak 's|^audit_file:.*|audit_file: p.audit.md|' "$TMPD/p.md"; rm -f "$TMPD/p.md.bak"
  # 헤더 줄만 지운다 — 섹션 본문은 남겨 "헤더 존재 검사"가 실제로 이빨을 갖는지 본다.
  python3 - "$TMPD/p.md" "$hdr" <<'PY'
import sys, pathlib
p, hdr = pathlib.Path(sys.argv[1]), sys.argv[2]
lines = p.read_text(encoding="utf-8").splitlines(True)
p.write_text("".join(l for l in lines if l.strip() != f"## {hdr}"), encoding="utf-8")
PY
  # exit code만 보면 13개 섹션-헤더 규칙 전부가 잠금 없이 산다: SECTIONS에서 항목을
  # 통째로 지워도 landscape_uncited/skepticism_malformed 등 다른 §5 소비자가 여전히
  # red를 내 exit code가 안 흔들린다(리뷰 발견). 메시지가 그 헤더 문자열을 실제로
  # 담고 있는지까지 확인해야 "이 규칙이 이 헤더를 잡는다"는 주장에 이빨이 생긴다.
  out="$(python3 "$SCRIPT" gate "$TMPD/p.md" 2>/dev/null)"; rc=$?
  { [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'missing payload sections' \
      && printf '%s' "$out" | grep -qF "$hdr"; } \
    && ok "T1: payload §$hdr 제거 → red, missing payload sections에 헤더 명시 (message teeth)" \
    || no "T1: payload §$hdr 제거가 통과됐거나 메시지에 해당 헤더가 없음"
  if [[ "$hdr" == "5. 기각 · Blind Spots" ]]; then
    # FIX1 lock (negative assertion): §5가 없으면 section5_entries가 공집합을 반환해
    # bijection A의 refs가 항상 비므로, audit(여기선 canonical valid.audit.md)이 ST1을
    # 선언 중이면 declared-refs가 발화해 "판정 없는 steelman"이 진짜 원인(missing
    # payload sections) 옆에 phantom으로 낀다(Important, 리뷰 발견) — sec5_absent 가드가
    # 이걸 막는다. 이 실패 모드는 red/green을 안 바꾸는 **추가 노이즈**라 exit code나
    # "메시지가 있다" 류 assertion으론 절대 못 잡는다 — "없다"를 직접 확인해야 한다.
    ! printf '%s' "$out" | grep -q 'bijection A' \
      && ok "FIX1: §5 부재 + audit ST1 선언 상태에서도 bijection A는 조용함 (negative lock)" \
      || no "FIX1: §5가 없는데 bijection A가 여전히 발화함 (phantom steelman-orphan 회귀)"
  fi
done

# T2: audit 5섹션을 각각 제거 → red ×5
for hdr in "1. Coverage Ledger" "2. Budget" "3. Steelman 원문" "4. 게이트 실행 기록" "5. 프로세스 로그"; do
  cp "$FX/interview-brief-valid.md" "$TMPD/p.md"
  cp "$FX/interview-brief-valid.audit.md" "$TMPD/p.audit.md"
  sed -i.bak 's|^audit_file:.*|audit_file: p.audit.md|' "$TMPD/p.md"; rm -f "$TMPD/p.md.bak"
  python3 - "$TMPD/p.audit.md" "$hdr" <<'PY'
import sys, pathlib
p, hdr = pathlib.Path(sys.argv[1]), sys.argv[2]
lines = p.read_text(encoding="utf-8").splitlines(True)
p.write_text("".join(l for l in lines if l.strip() != f"## {hdr}"), encoding="utf-8")
PY
  out="$(python3 "$SCRIPT" gate "$TMPD/p.md" 2>/dev/null)"; rc=$?
  { [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'missing audit sections' \
      && printf '%s' "$out" | grep -qF "$hdr"; } \
    && ok "T2: audit §$hdr 제거 → red, missing audit sections에 헤더 명시 (message teeth)" \
    || no "T2: audit §$hdr 제거가 통과됐거나 메시지에 해당 헤더가 없음"
done

# T7: audit_file 부재 / 파일 부재 → red ×2 (AC9 fail-closed)
for variant in absent missing; do
  cp "$FX/interview-brief-valid.md" "$TMPD/p.md"
  rm -f "$TMPD/p.audit.md"
  case "$variant" in
    absent)  sed -i.bak '/^audit_file:/d' "$TMPD/p.md" ;;
    # 유도 이름 그대로지만 파일이 없다 — not-found 분기를 계속 시험한다.
    missing) sed -i.bak 's|^audit_file:.*|audit_file: p.audit.md|' "$TMPD/p.md" ;;
  esac
  rm -f "$TMPD/p.md.bak"
  python3 "$SCRIPT" gate "$TMPD/p.md" >/dev/null 2>&1 \
    && no "T7/$variant: audit_file 결함이 통과됨 (fail-open)" \
    || ok "T7/$variant: audit_file 결함 → red"
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
  && ok "T7/traversal(parent-dir): decoy 존재해도 basename 가드가 발화 (teeth 증명)" \
  || no "T7/traversal(parent-dir): basename 가드 메시지를 못 찾음"

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
    && ok "T7/traversal($variant2): basename 가드가 발화" \
    || no "T7/traversal($variant2): basename 가드 메시지를 못 찾음"
done

# R2/AC4: 무인용 landscape → red
python3 "$SCRIPT" gate "$FX/interview-brief-no-landscape.md" >/dev/null 2>&1 \
  && no "무인용 landscape가 통과됨 (R2/AC4)" \
  || ok "무인용 landscape가 종료를 차단 (R2/AC4)"

# F3: §4 헤더만 있고 항목 없음 → red
python3 "$SCRIPT" gate "$FX/interview-brief-empty-landscape.md" >/dev/null 2>&1 \
  && no "F3: 빈 External Landscape가 통과됨" \
  || ok "F3: 빈 External Landscape가 종료를 차단"

# R3/AC5: §5 verdict 항목 형식 미달 → red
python3 "$SCRIPT" gate "$FX/interview-brief-unchallenged.md" >/dev/null 2>&1 \
  && no "형식 미달 verdict 항목이 통과됨 (R3/AC5)" \
  || ok "형식 미달 verdict 항목이 종료를 차단 (R3/AC5)"

# PN4: containment 검사가 누락 URL을 지목
python3 "$SCRIPT" skepticism "$FX/interview-brief-unchallenged.md" 2>/dev/null | grep -q 'no-url' \
  && ok "PN4: skepticism containment가 누락 URL을 플래그" \
  || no "PN4: skepticism containment가 누락 URL을 못 잡음"

# AC2: 섹션 부재 → red
python3 "$SCRIPT" gate "$FX/interview-brief-missing-section.md" >/dev/null 2>&1 \
  && no "섹션 부재가 통과됨 (AC2)" || ok "섹션 부재가 종료를 차단 (AC2)"
python3 "$SCRIPT" gate "$FX/interview-brief-missing-blind-spot.md" >/dev/null 2>&1 \
  && no "§5 부재가 통과됨" || ok "§5 부재가 종료를 차단"

# T19 / R4: §5 기각 0건 → red, N/A sentinel → green
python3 "$SCRIPT" gate "$FX/interview-brief-empty-tried.md" >/dev/null 2>&1 \
  && no "T19: 기각 0건 + sentinel 없음이 통과됨 (R4 증발)" \
  || ok "T19: 기각 0건 + sentinel 없음 → red (R4 이관 확인)"
python3 "$SCRIPT" gate "$FX/interview-brief-na-tried.md" >/dev/null 2>&1 \
  && ok "T19: 기각 N/A sentinel → green (R4 edge)" \
  || no "T19: N/A sentinel은 통과해야 한다"

# F4: 펜스 안 헤더는 게이트를 만족시키지 못한다
python3 "$SCRIPT" gate "$FX/interview-brief-fenced-sections.md" >/dev/null 2>&1 \
  && no "F4: 펜스 안 섹션 헤더가 통과됨" || ok "F4: 펜스 안 헤더는 불충분"

# F5: 읽을 수 없는 brief → 구조화 JSON + exit 1, traceback 금지
out="$(python3 "$SCRIPT" gate "$FX/__no_such_brief__.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q '"pass": false'; } \
  && ok "F5: 읽기 실패 → 구조화 JSON + exit 1" \
  || no "F5: 읽기 실패는 구조화 JSON이어야 한다"
printf '%s' "$out" | grep -qi 'Traceback' \
  && no "F5: traceback이 stdout으로 샜다" || ok "F5: traceback 누출 없음"

# F9-A: frontmatter 검증 실패 클래스
python3 "$SCRIPT" gate "$FX/interview-brief-bad-frontmatter.md" >/dev/null 2>&1 \
  && no "F9-A: 잘못된 frontmatter가 통과됨 (AC1)" \
  || ok "F9-A: 잘못된 frontmatter가 종료를 차단 (AC1)"

# F8/AC8: web 켜짐 → URL 없는 §4/§5는 red / kill switch → 완화
python3 "$SCRIPT" gate "$FX/interview-brief-web-disabled.md" >/dev/null 2>&1 \
  && no "F8: web 켜짐 상태에서 URL 없는 항목이 통과됨" \
  || ok "F8: web 켜짐 상태에서 URL 없는 항목이 차단됨"
DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 python3 "$SCRIPT" gate "$FX/interview-brief-web-disabled.md" >/dev/null 2>&1 \
  && ok "AC8: web 비활성 시 URL 요구 완화" \
  || no "AC8: web 비활성 시 URL 요구가 완화돼야 한다"

# AC10 / C9: Coverage Ledger는 audit에서 검증된다
python3 "$SCRIPT" gate "$FX/interview-brief-floor-open.md" >/dev/null 2>&1 \
  && no "AC10: floor open이 통과됨" || ok "AC10: floor open이 차단됨"
python3 "$SCRIPT" gate "$FX/interview-brief-floor-evidence-empty.md" >/dev/null 2>&1 \
  && no "AC10: floor evidence 공백이 통과됨" || ok "AC10: floor evidence 공백이 차단됨"
python3 "$SCRIPT" gate "$FX/interview-brief-missing-derived-row.md" >/dev/null 2>&1 \
  && no "C9: derived 행·sentinel 부재가 통과됨" || ok "C9: derived 부재가 차단됨"
python3 "$SCRIPT" gate "$FX/interview-brief-derived-sentinel.md" >/dev/null 2>&1 \
  && ok "C9: derived N/A sentinel → green" || no "C9: derived sentinel은 통과해야 한다"

# T13: audit §1 Coverage Ledger가 비어 있음 → red
python3 "$SCRIPT" gate "$FX/interview-brief-audit-no-coverage.md" >/dev/null 2>&1 \
  && no "T13: 빈 audit Coverage Ledger가 통과됨" \
  || ok "T13: 빈 audit Coverage Ledger → red (AC10)"

# coverage 서브커맨드가 audit을 스스로 해석
python3 "$SCRIPT" coverage "$FX/interview-brief-floor-open.md" 2>/dev/null | grep -q 'floor:landscape' \
  && ok "coverage 서브커맨드가 audit을 해석해 열린 floor를 플래그" \
  || no "coverage 서브커맨드가 열린 floor를 플래그해야 한다"

# AC9: audit_file 값 뒤 YAML 인라인 주석(템플릿의 실제 라인 모양)이 파싱을 깨서는 안 된다.
python3 "$SCRIPT" gate "$FX/interview-brief-audit-file-comment.md" >/dev/null 2>&1 \
  && ok "audit_file 인라인 주석이 있어도 게이트 통과 (템플릿 라인 형태)" \
  || no "audit_file 인라인 주석이 파싱을 깨서는 안 된다"

# F5 대칭: coverage 서브커맨드도 audit을 못 읽으면(디렉토리 등) traceback 없이 구조화 JSON + exit 1.
# payload를 not-a-file.md로 두어야 유도 이름이 not-a-file.audit.md가 되고, 그 자리에 놓인
# **디렉토리**가 unreadable 분기를 시험한다 — 다른 이름이면 유도 검사에서 먼저 걸려
# 정작 시험하려는 분기에 도달하지 못한다.
cp "$FX/interview-brief-valid.md" "$TMPD/not-a-file.md"
mkdir -p "$TMPD/not-a-file.audit.md"
sed -i.bak 's|^audit_file:.*|audit_file: not-a-file.audit.md|' "$TMPD/not-a-file.md"
rm -f "$TMPD/not-a-file.md.bak"
out="$(python3 "$SCRIPT" coverage "$TMPD/not-a-file.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q '"failures"'; } \
  && ok "coverage: 읽을 수 없는 audit(디렉토리) → 구조화 JSON + exit 1" \
  || no "coverage: 읽을 수 없는 audit도 구조화 JSON이어야 한다"
printf '%s' "$out" | grep -qi 'Traceback' \
  && no "coverage: traceback이 stdout으로 샜다" || ok "coverage: traceback 누출 없음"

# F8: gate도 audit을 못 읽으면 fail-closed여야 한다 — 2파일 seal의 **나머지 절반**.
# coverage만 잠그면 gate 쪽 `audit unreadable` append는 지워도 스위트가 green이다(측정된 blast
# radius 0): audit_text가 ""로 남아 audit 섹션 검사·pairing·bijection A·coverage ledger가 통째로
# skip되고 {"pass": true}가 찍힌다 — check_brief.py 헤더가 "조용히 payload-only 검사로 degrade하지
# 않는다"고 주장하는 바로 그 fail-open이다. exit code만 보는 assertion으로는 못 잡으므로
# (a) 메시지가 'audit unreadable'을 담을 것 + (b) 하류 검사가 실제로 skip됐다는 negative를 함께 건다.
out="$(python3 "$SCRIPT" gate "$TMPD/not-a-file.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'audit unreadable' \
    && ! printf '%s' "$out" | grep -q 'coverage ledger'; } \
  && ok "F8: gate도 읽을 수 없는 audit에 fail-closed ('audit unreadable' + 하류 skip)" \
  || no "F8: gate가 읽을 수 없는 audit에 fail-closed여야 한다"
rmdir "$TMPD/not-a-file.audit.md" 2>/dev/null || true

# F13: 불릿 문자 비대칭으로 R2(출처 URL 필수)를 우회할 수 없다.
# `_entry_lines`가 `- `만 받고 `BODY_ITEM_RE`는 `[-*]`를 받던 시절, §4에 인용된 `-` 항목 하나와
# 인용 없는 `*` 항목 하나를 두면 landscape_present는 만족되고 landscape_uncited는 `*`를 못 봐서
# 게이트가 green이었다. fixture는 valid와 **한 줄만** 다르므로 red 이유가 하나로 고정된다.
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-star-bullet-uncited.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'uncited landscape'; } \
  && ok "F13: '*' 불릿 uncited 항목도 R2에 걸린다" \
  || no "F13: '*' 불릿으로 출처 URL 요구가 우회됐다"

# F1: payload는 **다른 인터뷰의 audit**을 채택할 수 없다 (Coverage Ledger 차용 봉쇄).
# fixture는 valid와 session_id 한 줄만 다르고 가리키는 audit은 완전히 유효하다 — 그래서 red 이유가
# pairing 하나로 고정된다. 메시지까지 확인하는 이유: exit code만 보면 무관한 실패로도 만족된다.
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-foreign-audit.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'audit pairing' \
    && printf '%s' "$out" | grep -q 'session_id'; } \
  && ok "F1: 다른 인터뷰의 audit 채택 → red (session_id 바인딩)" \
  || no "F1: 남의 audit을 채택해 Coverage Ledger를 상속했다"

# R1: 항목을 **받아들이는** 규칙(_entry_lines, `[-*]`)과 불릿을 **떼는** 규칙(_strip_bullet)이
# 일치한다. 소비자가 `lstrip("- ")`(문자 집합 strip)를 쓰면 `*`가 안 벗겨져, 받아들여진 줄을
# 소비자가 못 알아본다 — `* 기각 …`이 R4에 안 세어져 이 fixture가 red가 된다. green이 정답인
# assertion이라 이빨은 mutation으로 증명한다(strip을 되돌리면 이 케이스만 red).
python3 "$SCRIPT" gate "$FX/interview-brief-star-bullet-rejection.md" >/dev/null 2>&1 \
  && ok "R1: '*' 불릿 기각 항목도 R4에 세어진다 (수용≡해석 관례 일치)" \
  || no "R1: '*' 불릿 기각 항목을 소비자가 못 알아본다 (lstrip 문자집합 회귀)"

# R2: pairing 키가 **중복**이면 값을 고르지 말고 거부한다. 첫 매치만 쓰면 남의 audit 맨 앞에
# 맞는 session_id 한 줄만 얹어 바인딩을 우회할 수 있다 — 모호한 입력에 값을 하나 골라주는 것이
# 이 검사가 막으려는 fail-open 그 자체다. 메시지까지 확인해 무관한 실패로 만족되지 않게 한다.
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-dup-session.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'audit pairing' \
    && printf '%s' "$out" | grep -q '중복'; } \
  && ok "R2: session_id 중복 키 → red (첫 매치 채택 금지)" \
  || no "R2: 중복 session_id의 첫 매치로 바인딩이 우회됐다"

# R3: **빈 값**은 부재로 읽혀야 한다. 키-값 구분자가 `\s*`면 `\s`가 개행을 포함하므로 값이 빈 키가
# 다음 줄 토큰을 값으로 포획한다 — payload와 audit이 둘 다 session_id를 비우면 양쪽이 똑같이
# 바로 아래 `source:`로 해석돼 페어링이 **상수로 붕괴하고 통과**했다(실행 실증: exit 0).
# 두 메시지를 모두 확인한다: 한쪽만 보면 반대쪽 키가 여전히 다음 줄을 삼켜도 통과한다.
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-empty-session.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'payload frontmatter에 session_id 없음' \
    && printf '%s' "$out" | grep -q 'audit frontmatter에 session_id 없음'; } \
  && ok "R3: 빈 session_id는 양쪽 다 부재로 읽힌다 (다음 줄 포획 금지)" \
  || no "R3: 빈 session_id가 다음 줄 키를 값으로 삼켰다"

# R4: 같은 규칙이 audit_file에도 적용된다 — 하나만 고치면 나머지가 남는다(같은 모양 3개 전수 교정).
# negative는 이 fixture의 **실제 인접 줄**을 짚어야 한다: `audit_file:` 다음 줄은 `user_sourced_items:`다.
# 처음엔 `created_at`을 썼는데 그 키는 세 줄 *위*라 어떤 경우에도 출력에 나올 수 없었다 — 즉 그
# conjunct는 항상 참인 죽은 절이었다(리뷰 적발). 주장하는 이빨과 실제 이빨이 다르면 락이 아니다.
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-empty-auditfile.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'audit_file key absent' \
    && ! printf '%s' "$out" | grep -q 'user_sourced_items'; } \
  && ok "R4: 빈 audit_file은 부재로 읽힌다 (다음 줄 포획 금지)" \
  || no "R4: 빈 audit_file이 다음 줄 키를 파일명으로 삼켰다"

# R5: 세 번째 키(type)도 같은 규칙. R3/R4를 고쳤을 때 이 케이스만 blast radius가 0이었다 —
# 세 regex를 함께 고쳤는데 검증은 둘만 덮은 상태였다는 뜻이라, 셋째도 명시적으로 잠근다.
# 빈 `type:`은 다음 줄 `payload:`를 값으로 삼켜도 값 불일치로 red가 되므로 exit code로는 구분이
# 안 된다 — **부재 메시지**를 요구하고 삼킨 값이 등장하지 않음을 함께 확인해야 이빨이 생긴다.
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-empty-audittype.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'audit frontmatter에 type 없음' \
    && ! printf '%s' "$out" | grep -q "type 'payload:'"; } \
  && ok "R5: 빈 audit type은 부재로 읽힌다 (다음 줄 포획 금지)" \
  || no "R5: 빈 audit type이 다음 줄 키를 값으로 삼켰다"

# R6: 중복 키의 **첫 항목이 비어 있어도** 중복으로 세어야 한다. 개수를 값 추출 패턴으로 세면
# 값이 빈 키는 hit이 안 잡혀 개수가 1이 되고 중복 거부가 통째로 우회된다 — R3(빈 값을 부재로
# 읽기)이 R2(중복 거부)를 되열어놓은 자리다. 그래서 개수는 값이 아니라 **키 라인**으로 센다.
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-dup-empty-session.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'session_id 중복'; } \
  && ok "R6: 첫 항목이 빈 중복 session_id도 중복으로 거부된다" \
  || no "R6: 빈 첫 항목이 중복 카운트에서 빠져 바인딩이 우회됐다"

# R7: 값을 첫 공백에서 끊으면 `shared payload`와 `shared audit`이 둘 다 `shared`로 읽혀 서로
# 다른 인터뷰가 동일 비교로 통과한다. 값은 라인 끝까지 읽고 주석만 뗀 뒤, 공백이 남으면 거부한다.
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-spaced-session.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q '단일 토큰'; } \
  && ok "R7: 공백 포함 session_id는 부분 비교되지 않고 거부된다" \
  || no "R7: session_id가 첫 토큰만으로 비교됐다"

# R8: `audit_file`도 나머지 frontmatter 키와 **같은** 규칙(중복 거부·빈 값·개행 포획 금지)을 쓴다.
# session_id/type만 하드닝하고 audit_file을 남겼을 때, 그 키가 자기 docstring이 금지한 두 패턴
# (first-match search + 첫 공백 컷)을 그대로 쓰고 있었다. audit_file은 **다른 모든 audit-측 검사가
# 무엇을 읽을지 고르는** 키라 규칙에서 빠질 이유가 가장 없다. 중복이 '부재'로 뭉개지지 않는지도 본다.
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-dup-auditfile.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'audit_file 중복' \
    && ! printf '%s' "$out" | grep -q 'audit_file key absent'; } \
  && ok "R8: audit_file 중복 → 중복으로 거부(부재로 오보고 안 함)" \
  || no "R8: audit_file 중복이 거부되지 않거나 부재로 오보고됐다"

# R9: audit 이름은 payload 파일명에서 **유도**된다 — payload가 자기 audit을 고를 수 없다.
# session_id 동등성만으로는 부족했다: SKILL이 세션 id 재사용을 규정해 한 세션의 두 인터뷰가
# 같은 id를 가지므로, 동일-세션 차용은 그대로 통과했다(실측: floor가 열린 payload의 audit_file
# 한 줄을 완료된 audit으로 바꾸면 exit 0). fixture는 valid와 **한 줄만** 다르고 가리키는 audit은
# 실재·유효·같은 세션이라, 유도 규칙 말고는 red가 될 이유가 없다.
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-borrowed-audit.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q "is not this payload's sidecar"; } \
  && ok "R9: 남의 audit 채택 → red (이름 유도, 같은 세션이어도)" \
  || no "R9: 같은 세션의 남의 audit을 채택해 Coverage Ledger를 상속했다"

# R10: web 킬 스위치가 verdict를 뒤집으면 **말해야** 한다 (CLAUDE.md loud-degradation).
# 같은 brief가 web ON에서 red, OFF에서 green이 되는데 stdout·stderr 어디에도 흔적이 없었다 —
# 이전 세션의 export가 셸에 남아 있으면 이후 모든 brief가 이유 없이 통과한다. 두 방향을 다
# 확인해야 이빨이 있다: 켜져 있을 때 나오고, **꺼져 있을 때는 안 나온다**(negative half —
# 없으면 advisory를 무조건 붙이는 구현도 통과한다).
out_off="$(DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 python3 "$SCRIPT" gate "$FX/interview-brief-no-landscape.md" 2>/dev/null)"
out_on="$(python3 "$SCRIPT" gate "$FX/interview-brief-valid.md" 2>/dev/null)"
{ printf '%s' "$out_off" | grep -q 'web 비활성' \
    && ! printf '%s' "$out_on" | grep -q 'web 비활성'; } \
  && ok "R10: web 킬 스위치가 verdict를 완화하면 advisory로 알린다 (양방향)" \
  || no "R10: web 킬 스위치 완화가 조용하거나, 꺼져 있을 때도 advisory가 나온다"

# R11: 유도된 이름 자리에 **남의 audit 내용**이 놓인 경우. 이름 유도는 "어느 파일을 읽을지"만
# 고정하므로 이 케이스는 통과했다(실측: floor-open의 sidecar 자리에 완료된 audit을 복사 → exit 0).
# audit이 스스로 선언하는 `payload:` 역참조만이 이걸 잡는다 — 두 템플릿과 모든 fixture가 이미
# 담고 있으면서 아무도 읽지 않던 필드다. fixture는 파일명·session_id·type이 전부 정상이라
# 역참조 말고는 red가 될 이유가 없다.
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-copied-audit.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'audit payload'; } \
  && ok "R11: 유도 경로에 복사된 남의 audit 내용 → red (payload 역참조)" \
  || no "R11: 남의 audit 내용을 sidecar 자리에 복사해 통과했다"

# R12: `gate` 말고 `_web_disabled()`가 결과를 바꾸는 다른 서브커맨드도 완화를 알려야 한다.
# stdout은 JSON 계약이므로 advisory는 **stderr**로 간다 — 여기 섞이면 소비자 파싱이 깨진다.
# 양방향: 꺼져 있을 때 나오고, 켜져 있을 때는 안 나온다.
err_off="$(DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 python3 "$SCRIPT" landscape-citations "$FX/interview-brief-no-landscape.md" 2>&1 1>/dev/null)"
err_on="$(python3 "$SCRIPT" landscape-citations "$FX/interview-brief-no-landscape.md" 2>&1 1>/dev/null)"
out_off="$(DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 python3 "$SCRIPT" landscape-citations "$FX/interview-brief-no-landscape.md" 2>/dev/null)"
{ printf '%s' "$err_off" | grep -q 'web 비활성' \
    && ! printf '%s' "$err_on" | grep -q 'web 비활성' \
    && printf '%s' "$out_off" | grep -q '^{'; } \
  && ok "R12: 단독 서브커맨드도 web 완화를 stderr로 알린다 (stdout JSON 무오염)" \
  || no "R12: 단독 서브커맨드가 조용히 완화되거나 advisory가 stdout을 오염시켰다"

# R13: 같은 쌍에 대해 `gate`와 `coverage`가 같은 답을 내야 한다. `coverage`는 페어링을 건너뛰어
# gate가 거부하는 쌍을 {"failures": []}로 답했다 — 두 진입점이 같은 질문에 다른 답을 내면 느슨한
# 쪽이 거짓이다. 원장 자체가 유효한 사본이라 exit code만으로는 원인이 안 보이므로 메시지까지 본다.
out="$(python3 "$SCRIPT" coverage "$FX/interview-brief-copied-audit.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'audit pairing'; } \
  && ok "R13: coverage도 mispaired audit을 거부 (gate와 동일 판정)" \
  || no "R13: coverage가 gate와 다른 답을 냈다 (mispaired audit을 clean으로 보고)"

# --- Task 2: user_sourced_items 스키마 + bijection C + confirmed sentinel ---

# T3: user_sourced_items 부재 → red
python3 "$SCRIPT" gate "$FX/interview-brief-no-items.md" >/dev/null 2>&1 \
  && no "T3: user_sourced_items 부재가 통과됨" || ok "T3: user_sourced_items 부재 → red"

# T4: evidence 없음 → red
python3 "$SCRIPT" gate "$FX/interview-brief-item-no-evidence.md" >/dev/null 2>&1 \
  && no "T4: evidence 없는 항목이 통과됨" || ok "T4: evidence 없는 항목 → red"
# T4 message teeth: 이 fixture는 bijection B(§2 body ⟨S1⟩ 부재)도 같이 red를 내므로
# exit code만 보면 evidence-required 규칙 자체를 지워도 assertion이 안 걸린다(가짜 teeth,
# bijection B 도입 리뷰 발견). items의 errors 키 안에서 그 규칙 고유 메시지를 직접 찾는다.
errs="$(python3 "$SCRIPT" items "$FX/interview-brief-item-no-evidence.md" 2>/dev/null \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["errors"])')"
printf '%s' "$errs" | grep -q 'evidence missing' \
  && ok "T4: user_sourced_errors가 evidence missing을 flag (message teeth)" \
  || no "T4: evidence missing 메시지를 items.errors에서 못 찾음"

# T5: source: inferred가 리스트에 있음 → red
python3 "$SCRIPT" gate "$FX/interview-brief-item-inferred.md" >/dev/null 2>&1 \
  && no "T5: source: inferred가 통과됨 (리스트 이름과 내용 불일치)" \
  || ok "T5: source: inferred → red"
# T5 message teeth: MARKER_SOURCE는 verbatim/chosen만 반환하므로 source 값이 무엇이든
# 유효하지 않으면 bijection B도 구조적으로 같이 red를 낸다 — exit code만으론 이 규칙의
# 삭제를 못 잡는다(가짜 teeth). items.errors에서 규칙 고유 메시지를 직접 확인.
errs="$(python3 "$SCRIPT" items "$FX/interview-brief-item-inferred.md" 2>/dev/null \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["errors"])')"
printf '%s' "$errs" | grep -q "source 'inferred' not in" \
  && ok "T5: user_sourced_errors가 source 'inferred'를 flag (message teeth)" \
  || no "T5: source 'inferred' 메시지를 items.errors에서 못 찾음"

# T6: 잘못된 status / source → red ×2
python3 "$SCRIPT" gate "$FX/interview-brief-item-bad-status.md" >/dev/null 2>&1 \
  && no "T6: 잘못된 status가 통과됨" || ok "T6: 잘못된 status → red"
python3 "$SCRIPT" gate "$FX/interview-brief-item-bad-source.md" >/dev/null 2>&1 \
  && no "T6: 잘못된 source가 통과됨" || ok "T6: 잘못된 source → red"
# T6 message teeth (source만 — status는 bijection B와 충돌하지 않아 exit code로 이미 충분):
# 위 T5와 같은 이유로 source allowlist 삭제 시 exit code가 bijection B로 계속 red를 유지한다.
errs="$(python3 "$SCRIPT" items "$FX/interview-brief-item-bad-source.md" 2>/dev/null \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["errors"])')"
printf '%s' "$errs" | grep -q "source '사용자' not in" \
  && ok "T6: user_sourced_errors가 잘못된 source를 flag (message teeth)" \
  || no "T6: source '사용자' 메시지를 items.errors에서 못 찾음"

# T22: bijection C — evidence: S9인데 §6에 S9 없음 → red
python3 "$SCRIPT" gate "$FX/interview-brief-evidence-dangling.md" >/dev/null 2>&1 \
  && no "T22: dangling evidence가 통과됨 (bijection C 미집행)" \
  || ok "T22: dangling evidence → red (bijection C)"

# T14: confirmed 0건 + sentinel 없음 → red / 있음 → green
python3 "$SCRIPT" gate "$FX/interview-brief-confirmed-zero.md" >/dev/null 2>&1 \
  && no "T14: confirmed 0건 + sentinel 없음이 통과됨 (확인 게이트 우회)" \
  || ok "T14: confirmed 0건 + sentinel 없음 → red"
python3 "$SCRIPT" gate "$FX/interview-brief-confirmed-zero-sentinel.md" >/dev/null 2>&1 \
  && ok "T14: confirmed 0건 + sentinel → green" \
  || no "T14: sentinel이 있으면 통과해야 한다"

# T14/anchoring — sentinel은 **한 줄 전체**여야 한다. substring 검사였을 때, 템플릿이
# 사용법을 설명하려고 인쇄하는 주석(`#   # confirmed 0건 — …`)이 그 검사를 만족시켜
# **템플릿대로 만든 brief가 AC12를 통째로 우회**했다(리뷰가 재현). 픽스처는 그 주석 블록을
# 축자로 담는다 — 템플릿이 나중에 그 문구를 다시 인쇄해도 이 락이 먼저 시끄러워진다.
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-template-comment-zero.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'sentinel 없음'; } \
  && ok "T14/anchoring: 템플릿 안내 주석은 sentinel을 만족시키지 못한다 → red" \
  || no "T14/anchoring: 템플릿 안내 주석이 AC12를 우회했다 (substring 회귀)"
# 같은 앵커링이 **인용값 안에 숨은** 문자열도 거절한다. 그리고 이 픽스처는 statement 값 안에
# ` #`를 담으므로 인라인-주석 제거의 **따옴표 보호**도 함께 잠근다 — 보호가 없으면 값이
# `게이트는`으로 잘려 bijection B statement drift가 *추가로* 발화한다(부정 assert가 그걸 본다).
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-sentinel-in-statement.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'sentinel 없음' \
    && ! printf '%s' "$out" | grep -q 'bijection B'; } \
  && ok "T14/anchoring: statement 값 안의 sentinel 문자열은 무효 + 인용값 `#` 보존" \
  || no "T14/anchoring: 인용값 안 sentinel이 인정됐거나 인용값 `#`가 잘렸다"
# 템플릿은 sentinel을 "이 블록 안에" 쓰라고 지시한다 — 들여쓰지 않은 주석 줄이 블록을
# 끊어 항목이 전부 증발하면 게이트가 "in body §2 but not in frontmatter"라는 원인과
# 어긋난 말을 한다. 파서가 주석 줄을 건너뛰므로 블록 안 선언이 정상 동작해야 한다.
python3 "$SCRIPT" gate "$FX/interview-brief-sentinel-in-block.md" >/dev/null 2>&1 \
  && ok "T14/anchoring: items 블록 *안*의 sentinel → green (주석 줄이 파싱을 안 끊음)" \
  || no "T14/anchoring: 블록 안 sentinel이 항목 파싱을 끊었다"

# T-TPL: shipping되는 템플릿 쌍은 자기 게이트를 통과해야 한다.
# 게이트가 첫 인터뷰마다 거짓 오류 벽을 내던 실제 결함이 여기서 났다 — `audit_file`은
# 인라인 주석을 떼는데 항목 필드는 안 떼서, 같은 frontmatter를 두 규칙이 반대로 읽었다.
# 템플릿을 픽스처로 복제하지 않고 **shipping 파일 자체**를 복사해 돌린다(복제본은 drift한다).
cp "$REPO_ROOT/plugins/spec-distill/templates/interview-brief-template.md" "$TMPD/tpl.md"
cp "$REPO_ROOT/plugins/spec-distill/templates/interview-audit-template.md" "$TMPD/tpl.audit.md"
sed -i.bak 's|^audit_file:.*|audit_file: tpl.audit.md|' "$TMPD/tpl.md"
# audit의 payload 역참조도 이 쌍의 실제 이름으로 맞춘다 — 템플릿은 placeholder를 싣고 출하되고,
# 그 placeholder는 어떤 실제 payload 이름과도 같지 않다(그게 정상이다).
sed -i.bak 's|^payload:.*|payload: tpl.md|' "$TMPD/tpl.audit.md"
rm -f "$TMPD/tpl.md.bak" "$TMPD/tpl.audit.md.bak"
out="$(python3 "$SCRIPT" gate "$TMPD/tpl.md" 2>/dev/null)"; rc=$?
[[ $rc -eq 0 ]] \
  && ok "T-TPL: shipping 템플릿 쌍(payload+audit)이 자기 게이트를 통과" \
  || { no "T-TPL: shipping 템플릿 쌍이 자기 게이트에 걸린다"; printf '    %s\n' "$out"; }

# --- Task 3: bijection B (body §2 ↔ frontmatter) ---

# T8: 한쪽에만 있는 id → red ×2 (양방향)
python3 "$SCRIPT" gate "$FX/interview-brief-body-only-id.md" >/dev/null 2>&1 \
  && no "T8: body §2에만 있는 id가 통과됨" || ok "T8: body-only id → red"
python3 "$SCRIPT" gate "$FX/interview-brief-fm-only-id.md" >/dev/null 2>&1 \
  && no "T8: frontmatter에만 있는 id가 통과됨" || ok "T8: frontmatter-only id → red"

# T9: 기호↔source / status 불일치 → red ×2
python3 "$SCRIPT" gate "$FX/interview-brief-marker-mismatch.md" >/dev/null 2>&1 \
  && no "T9: 기호↔source 불일치가 통과됨 (☑ laundering)" || ok "T9: 기호↔source 불일치 → red"
python3 "$SCRIPT" gate "$FX/interview-brief-status-mismatch.md" >/dev/null 2>&1 \
  && no "T9: status 불일치가 통과됨" || ok "T9: status 불일치 → red"

# T21: statement 내용 drift → red / 공백·강조기호만 다름 → green
python3 "$SCRIPT" gate "$FX/interview-brief-statement-drift.md" >/dev/null 2>&1 \
  && no "T21: statement 내용 drift가 통과됨 (같은 라벨, 다른 제약)" \
  || ok "T21: statement 내용 drift → red"
python3 "$SCRIPT" gate "$FX/interview-brief-statement-whitespace.md" >/dev/null 2>&1 \
  && ok "T21: 공백·강조기호 차이는 정규화로 흡수 → green" \
  || no "T21: 정규화가 공백·강조 차이를 흡수해야 한다"

# T24: ⟨S<N>⟩ 불일치 / 접미 부재 → red ×2
python3 "$SCRIPT" gate "$FX/interview-brief-anchor-mismatch.md" >/dev/null 2>&1 \
  && no "T24: ⟨S<N>⟩ 불일치가 통과됨" || ok "T24: ⟨S<N>⟩ 불일치 → red"
python3 "$SCRIPT" gate "$FX/interview-brief-anchor-absent.md" >/dev/null 2>&1 \
  && no "T24: ⟨S<N>⟩ 접미 부재가 통과됨 (요약 신호 소실)" || ok "T24: ⟨S<N>⟩ 부재 → red"

# 형식 미달 §2 항목은 조용히 사라지지 않고 loud하게 red가 된다
python3 "$SCRIPT" gate "$FX/interview-brief-body-malformed.md" >/dev/null 2>&1 \
  && no "형식 미달 §2 항목이 통과됨 (silent drop)" || ok "형식 미달 §2 항목 → red (loud)"

# VS16 관용: 마커 뒤 U+FE0F(대부분의 이모지 입력 경로가 내는 변형 선택자)가 붙어도
# 정상 항목으로 파싱돼야 한다(loud로 그치지 않고 green) — 리뷰 발견, BODY_ITEM_LOOSE_RE의
# 원래 취지("기호로 시작하지만 문법에 안 맞으면 loud")가 VS16 앞에서는 과잉발화였다.
python3 "$SCRIPT" gate "$FX/interview-brief-marker-vs16.md" >/dev/null 2>&1 \
  && ok "VS16 마커(☑️/🗣️)가 정상 항목으로 파싱돼 green" \
  || no "VS16 마커가 있으면 정상 항목으로 통과해야 한다 (VS16 불관용)"

# --- Task 4: bijection A + §5 verdict 강화 + 표기 블록 ---

# T10: 한쪽에만 있는 ST<N> → red ×2 (양방향)
python3 "$SCRIPT" gate "$FX/interview-brief-st-orphan-payload.md" >/dev/null 2>&1 \
  && no "T10: payload만 참조하는 ST가 통과됨 (원문 없는 판정)" \
  || ok "T10: payload-only ST → red"
python3 "$SCRIPT" gate "$FX/interview-brief-st-orphan-audit.md" >/dev/null 2>&1 \
  && no "T10: audit에만 있는 ST가 통과됨 (판정 없는 steelman)" \
  || ok "T10: audit-only ST → red"
# T10 message teeth: exit code만으론 방향(direction)이 아니라 존재만 증명된다. 단
# "고유 문구가 있는지"만 보면 부족하다 — `refs - declared`를 `refs ^ declared`로
# 바꿔도 st-orphan-payload는 declared⊆refs라 값이 우연히 안 바뀌고, st-orphan-audit는
# 잘못된 방향 문구가 옳은 문구 **옆에 추가로** 붙을 뿐 옳은 문구를 안 지운다 — "문구가
# 있다"만 보면 두 경우 다 여전히 통과해버린다(직접 재현해 확인). 그래서 각 픽스처마다
# "제 방향 문구가 있다" + "반대 방향 문구는 없다"를 함께 확인해야 방향 자체가 잠긴다.
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-st-orphan-payload.md" 2>/dev/null)"
{ printf '%s' "$out" | grep -q '원문 없는 판정' \
    && ! printf '%s' "$out" | grep -q '판정 없는 steelman'; } \
  && ok "T10: payload-only ST → '원문 없는 판정'만 발화 (반대 방향 없음, message teeth)" \
  || no "T10: payload-only ST 메시지 방향이 틀렸거나 반대 방향이 섞여 있음"
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-st-orphan-audit.md" 2>/dev/null)"
{ printf '%s' "$out" | grep -q '판정 없는 steelman' \
    && ! printf '%s' "$out" | grep -q '원문 없는 판정'; } \
  && ok "T10: audit-only ST → '판정 없는 steelman'만 발화 (반대 방향 없음, message teeth)" \
  || no "T10: audit-only ST 메시지 방향이 틀렸거나 반대 방향이 섞여 있음"

# T12: 양쪽 steelman 공집합 + 기각 항목 존재 + sentinel 없음 → green
python3 "$SCRIPT" gate "$FX/interview-brief-steelman-empty.md" >/dev/null 2>&1 \
  && ok "T12: steelman 양쪽 공집합은 sentinel 없이 green (R4 sentinel과 다른 조건)" \
  || no "T12: steelman 공집합은 sentinel을 요구받지 않는다"

# T11: verdict 항목 결손 → red ×4
for v in no-url no-token short no-st; do
  python3 "$SCRIPT" gate "$FX/interview-brief-verdict-$v.md" >/dev/null 2>&1 \
    && no "T11/$v: 결손 verdict 항목이 통과됨" || ok "T11/$v: 결손 verdict 항목 → red"
done

# FIX4 (리뷰 라운드): URL 경로 조각에 우연히 낀 word-bounded ST<N>(예: `/ST9/`)는
# 실제 참조로 치지 않는다 — has_st/refs 모두 URL을 먼저 벗겨낸 뒤 계산해야 한다.
# exit code만으론 부족(bijection A가 phantom ref를 orphan으로 잡아 우연히 red가 될 수
# 있음) — skepticism 서브커맨드 출력에서 no-ST-ref 태그를 직접 확인한다(message teeth).
skep="$(python3 "$SCRIPT" skepticism "$FX/interview-brief-verdict-st-in-url.md" 2>/dev/null)"
printf '%s' "$skep" | grep -q 'no-ST-ref' \
  && ok "FIX4: URL 안 phantom ST9는 ST 요구를 충족시키지 못함 (no-ST-ref)" \
  || no "FIX4: URL 안 ST 토큰이 ST 요구를 잘못 충족시킴"
python3 "$SCRIPT" gate "$FX/interview-brief-verdict-st-in-url.md" >/dev/null 2>&1 \
  && no "FIX4: URL 안 phantom ST9 픽스처가 게이트를 통과함" \
  || ok "FIX4: URL 안 phantom ST9 픽스처 → red"

# T17: web 비활성 시 §4·§5 URL 요구 완화 (기존 graceful degradation 선례 유지)
DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 python3 "$SCRIPT" gate "$FX/interview-brief-verdict-no-url.md" >/dev/null 2>&1 \
  && ok "T17: web 비활성 시 URL 없는 verdict 항목 → green (AC8/AC11)" \
  || no "T17: web 비활성 시 URL 요구가 완화돼야 한다"
# ...단 ST 참조 요구는 완화되지 않는다 (web과 무관한 파일-축 drift-guard)
DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 python3 "$SCRIPT" gate "$FX/interview-brief-verdict-no-st.md" >/dev/null 2>&1 \
  && no "T17: web 비활성이 ST 참조 요구까지 완화시켰다 (과잉 완화)" \
  || ok "T17: web 비활성이어도 ST 참조는 계속 요구됨"

# T18: 출처 표기 블록 부재 / 세 기호 중 하나 누락 → red ×2
python3 "$SCRIPT" gate "$FX/interview-brief-no-attribution.md" >/dev/null 2>&1 \
  && no "T18: 표기 블록 부재가 통과됨" || ok "T18: 표기 블록 부재 → red"
python3 "$SCRIPT" gate "$FX/interview-brief-attribution-partial.md" >/dev/null 2>&1 \
  && no "T18: 기호 누락 표기 블록이 통과됨" || ok "T18: 기호 누락 표기 블록 → red"

# Task 5(분량 지표 / 150줄 트립와이어)는 v0.33.0에서 제거됐다. 분량 상한이 잰 것은
# 과잉결정이 아니라 부피였고, 그 대리 지표는 §3 Open Questions를 성실히 채운 brief를
# 벌하는 방향으로 틀렸다. 재삽입 방지 락은 `test_brief_no_length_cap.sh`에 산다 —
# 여기에 부정 assertion만 남기면 트립와이어가 없는 지금은 무엇을 지워도 통과하는
# 빈 락이 되기 때문에, 블록을 고치지 않고 통째로 걷어냈다.

# --- U2-T2: audit 절 확장 + attribution 이사 --------------------------------
# 이사 후: payload §6 에 블록이 없어도 통과, audit §6 에 없으면 red.
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-audit-attr-missing.md" 2>&1)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q '출처 표기 블록 부재'; } \
  && ok "U2-T2: audit §6 에 출처 표기 블록이 없으면 red" \
  || no "U2-T2: attribution 이사가 audit 을 대상으로 안 잡는다"

# **rc 로 판정한다. 문면 grep 의 부정형을 쓰지 않는다.** 이 이사는 실패 메시지를
# `audit §6 출처 표기 블록 부재` 로 바꾸는데, 그 문자열은 옛 문면을 **부분문자열로 포함**한다 —
# `grep -q '출처 표기 블록 부재'` 의 부정형으로 쓰면 audit 쪽 실패가 payload 쪽 실패로 오독되고,
# 반대로 문면을 더 고치면 조용히 GREEN 이 된다. 부정형 문면 앵커는 두 방향 모두로 거짓말한다.
python3 "$SCRIPT" gate "$FX/interview-brief-payload-attr-missing.md" >/dev/null 2>&1
[[ $? -eq 0 ]] \
  && ok "U2-T2: payload §6 에 블록이 없어도 게이트 통과 (검사 대상이 아니다)" \
  || { python3 "$SCRIPT" gate "$FX/interview-brief-payload-attr-missing.md" 2>&1 | head -2
       no "U2-T2: payload §6 이 여전히 attribution 검사 대상이다 (이사 실패)"; }

for sec in 6; do
  out="$(python3 "$SCRIPT" gate "$FX/interview-brief-audit-no-sec${sec}.md" 2>&1)"; rc=$?
  { [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'missing audit sections'; } \
    && ok "U2-T2: audit §${sec} 헤딩 제거 → red (#9)" \
    || no "U2-T2: audit §${sec} 제거가 안 잡힌다 — AUDIT_SECTIONS 확장에 이빨이 없다"
done

finish
