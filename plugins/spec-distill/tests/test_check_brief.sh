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
  # 통째로 지워도 landscape_unkeyed/skepticism_malformed 등 다른 §5 소비자가 여전히
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

# PN4: containment 검사가 형식 미달을 지목한다. v0.44.0 N1a에서 URL 요구를
# 지웠으므로(payload 외부 URL은 이제 N1a가 전면 금지한다) 이 fixture(`verdict:` 뒤
# 유효 단어 없음)의 결손은 더 이상 no-url이 아니라 no-verdict다.
python3 "$SCRIPT" skepticism "$FX/interview-brief-unchallenged.md" 2>/dev/null | grep -q 'no-verdict' \
  && ok "PN4: skepticism containment가 형식 미달(no-verdict)을 플래그" \
  || no "PN4: skepticism containment가 형식 미달을 못 잡음"

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

# F8: web 켜짐 → 무키 §4 항목은 여전히 red. #13(landscape_unkeyed, ∀)은 web 상태와
# 무관하므로 `interview-brief-web-disabled.md`(§4 항목에 URL도 «키»도 없음)를 여기서
# **고치면 안 된다** — 고치면(«키»를 붙이면) #13이 web 무관하게 항상 통과하게 되고,
# 그때 skepticism도 이미 URL 요구가 없으므로(v0.44.0 N1a) 이 fixture는 web 상태와
# 무관하게 **항상 green**이 돼 이 F8 자체가 거짓이 된다(반증: 로컬에서 «키» 삽입 실험
# → F8/AC8 동시 만족 불가능해짐을 확인했다). 그래서 이 fixture는 그대로 둔다.
python3 "$SCRIPT" gate "$FX/interview-brief-web-disabled.md" >/dev/null 2>&1 \
  && no "F8: web 켜짐 상태에서 무키 §4 항목이 통과됨" \
  || ok "F8: web 켜짐 상태에서 무키 §4 항목이 차단됨 (#13, web 무관 불변)"

# AC8: v0.44.0 이후 유일한 완화 대상은 #12(landscape_present)의 sentinel 경로뿐이다 —
# §4 인용/URL 요구도, §5 verdict URL 요구도 더는 존재하지 않아 완화할 게 없다. 그래서
# AC8은 web-disabled.md가 아니라 그 실제 완화 경로를 시험하는 sentinel-only.md로 확인한다
# (U3-T8 블록과 같은 사실을 다른 이름 아래 한 번 더 고정 — AC8은 역사적 라벨로 남긴다).
DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 python3 "$SCRIPT" gate "$FX/interview-brief-sentinel-only.md" >/dev/null 2>&1 \
  && ok "AC8: web 비활성 시 §4 sentinel 경로가 완화된다 (#12, 유일한 완화)" \
  || no "AC8: web 비활성 시 sentinel 경로가 완화돼야 한다"

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

# F13: 불릿 문자 비대칭으로 #13(§4 «출처키» 필수, ∀)을 우회할 수 없다.
# `_entry_lines`가 `- `만 받고 `BODY_ITEM_RE`는 `[-*]`를 받던 시절, §4에 키 있는 `-` 항목 하나와
# 키 없는 `*` 항목 하나를 두면 landscape_present는 만족되고 landscape_unkeyed는 `*`를 못 봐서
# 게이트가 green이었다. v0.44.0의 개명(`landscape_uncited`→`landscape_unkeyed`)으로 이 락의
# 실패 문구가 바뀌었다 — 옛 문구 'uncited landscape'를 그대로 두면 문구가 조용히 GREEN이 되고
# (더 이상 안 나오는 문자열을 찾으니), 대신 URL만 지워 옛 술어로 되돌리면 검사 대상이 아닌
# 것을 재검사하게 된다. fixture의 `-` 항목에 «키»를 붙이고 audit §7에 그 키를 선언해
# «키»만 있으면 통과함을 먼저 확정한 뒤, `*` 항목만 무키로 남겨 red 이유를 하나로 고정한다.
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-star-bullet-uncited.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'unkeyed landscape'; } \
  && ok "F13: '*' 불릿 unkeyed 항목도 #13에 걸린다" \
  || no "F13: '*' 불릿으로 «출처키» 요구가 우회됐다"

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
# v0.44.0: 문면이 바뀌어 'web 비활성' 리터럴이 더는 안 나온다(Step 5) — 새 문면에
# 안정적으로 남는 표현('완화된 것은')으로 앵커를 옮긴다.
out_off="$(DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 python3 "$SCRIPT" gate "$FX/interview-brief-no-landscape.md" 2>/dev/null)"
out_on="$(python3 "$SCRIPT" gate "$FX/interview-brief-valid.md" 2>/dev/null)"
{ printf '%s' "$out_off" | grep -q '완화된 것은' \
    && ! printf '%s' "$out_on" | grep -q '완화된 것은'; } \
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

# R12: v0.44.0 N1a 이후 `skepticism`도 §5 URL 요구를 잃어(이 커밋) kill switch로
# 완화되는 **단독 서브커맨드가 이제 하나도 없다** — `landscape-keys`는 앞선 #13
# 개명에서, `skepticism`은 이 커밋에서 빠졌다(main()의 서브커맨드별 advisory 분기를
# 통째로 지웠다). 유일한 완화 지점은 `gate()` 내부 `landscape_present`(#12)뿐이고
# 그건 이미 R10이 확인한다. 여기서는 skepticism 단독 호출이 이제 **kill switch와
# 무관**함을 확인한다 — 두 실행의 출력이 같고, 어느 쪽도 advisory를 내지 않는다.
out_off="$(DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 python3 "$SCRIPT" skepticism "$FX/interview-brief-no-landscape.md" 2>&1)"
out_on="$(python3 "$SCRIPT" skepticism "$FX/interview-brief-no-landscape.md" 2>&1)"
{ [[ "$out_off" == "$out_on" ]] && ! printf '%s' "$out_off" | grep -q '완화된 것은'; } \
  && ok "R12: skepticism 단독 호출은 더 이상 kill switch에 좌우되지 않는다 (URL 요구 삭제)" \
  || no "R12: skepticism이 여전히 kill switch로 완화되거나 침묵 완화가 남아 있다"

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

# T12 (v0.54.0 — C26): steelman 0건은 `검토 —` 기록 항목이 있어야 green. 기록이 없으면 red.
python3 "$SCRIPT" gate "$FX/interview-brief-steelman-empty.md" >/dev/null 2>&1 \
  && ok "T12: steelman 0건 + 검토 항목 1 → green" \
  || no "T12: 검토 항목이 있는 0건 payload 가 막힌다"
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-steelman-empty-norecord.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'skepticism 기록 0건'; } \
  && ok "T12(음성): verdict 0 + 검토 0 → red 「skepticism 기록 0건」 (AC9)" \
  || no "T12(음성): 기록 없는 0건이 통과했다 — 폐쇄 요구가 없다"
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-review-record-malformed.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'malformed §5 검토 entries'; } \
  && ok "T12(형식): 검토 항목에 기각 이유 없음 → red (AC11)" \
  || no "T12(형식): 네 토큰 미달 검토 항목이 통과했다"
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-review-only-no-reject.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q '§5 기각 항목 0건'; } \
  && ok "T12(R4): 검토 1 + 기각 0 → red 「§5 기각 항목 0건」 — 검토는 기각을 대신 못 한다 (AC12)" \
  || no "T12(R4): 검토 항목이 R4 기각으로 세어졌다"

# T20 (v0.54.0 — C10/C15): 새 어휘. refined green · 옛 defended red · 보류 deferred 는 R4 로 안 센다.
python3 "$SCRIPT" gate "$FX/interview-brief-verdict-refined.md" >/dev/null 2>&1 \
  && ok "T20: verdict: refined → green (AC13)" || no "T20: refined 가 막힌다"
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-verdict-defended.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'malformed §5 verdict entries'; } \
  && ok "T20: 옛 토큰 defended → red no-verdict (AC13, 별칭 없음)" \
  || no "T20: defended 가 여전히 유효 토큰이다 — 별칭이 살아 있다"
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-verdict-deferred-hold.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q '§5 기각 항목 0건' \
    && ! printf '%s' "$out" | grep -q 'malformed §5 verdict\|bijection A'; } \
  && ok "T20: 보류 — deferred 1 + 기각 0 → red 는 R4 만 (verdict 항목·bijection A 는 정상) (AC19)" \
  || no "T20: 보류 항목이 R4 기각으로 세어졌거나 verdict 항목으로 안 읽힌다"

# T11: verdict 항목 결손 → red ×3 (no-token/short/no-st — 이 셋은 URL과 무관한 결손이다)
for v in no-token short no-st; do
  python3 "$SCRIPT" gate "$FX/interview-brief-verdict-$v.md" >/dev/null 2>&1 \
    && no "T11/$v: 결손 verdict 항목이 통과됨" || ok "T11/$v: 결손 verdict 항목 → red"
done

# T11/no-url: v0.44.0 N1a 이후 §5 verdict 항목에서 URL 제거는 GREEN이어야 한다(§4·§5
# URL 요구를 지웠다 — payload 외부 URL은 N1a가 §6 예외 하나만 두고 전면 금지하고, 그건
# 여기서 무관하다). **양성 대조 없는 GREEN-기대 assertion은 죽은 락과 구분이 안 되므로**
# (설계 §7.1), 같은 줄에서 `verdict:` 절까지 지우면 여전히 red임을 함께 확인한다 — 이번엔
# skepticism_malformed가 아니라 bijection A가 잡는다: 그 줄이 더 이상 verdict 항목으로
# 안 보이므로 audit §3의 ST1이 orphan(판정 없는 steelman)이 된다.
python3 "$SCRIPT" gate "$FX/interview-brief-verdict-no-url.md" >/dev/null 2>&1 \
  && ok "T11/no-url(양성): §5 verdict 항목에서 URL만 제거 → green (URL 요구 삭제)" \
  || no "T11/no-url(양성): URL 없는 verdict 항목이 여전히 막힌다 — URL 요구가 안 지워짐"
cp "$FX/interview-brief-verdict-no-url.md" "$TMPD/vnu.md"
cp "$FX/interview-brief-verdict-no-url.audit.md" "$TMPD/vnu.audit.md"
sed -i.bak 's|^audit_file:.*|audit_file: vnu.audit.md|' "$TMPD/vnu.md"
sed -i.bak 's| → verdict: kept — ST1| → ST1|' "$TMPD/vnu.md"
rm -f "$TMPD/vnu.md.bak"
out="$(python3 "$SCRIPT" gate "$TMPD/vnu.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q '판정 없는 steelman'; } \
  && ok "T11/no-url(음성): 같은 줄에서 verdict: 절까지 지우면 여전히 red (bijection A)" \
  || no "T11/no-url(음성): verdict: 제거가 조용히 통과했다 — 양성만으론 죽은 락과 구분 안 됨"

# FIX4 (리뷰 라운드): URL 경로 조각에 우연히 낀 word-bounded ST<N>(예: `/ST9/`)는
# 실제 참조로 치지 않는다 — has_st/refs 모두 URL을 먼저 벗겨낸 뒤 계산해야 한다.
# exit code만으론 부족(bijection A가 phantom ref를 orphan으로 잡아 우연히 red가 될 수
# 있음) — skepticism 서브커맨드 출력에서 no-ST-ref 태그를 직접 확인한다(message teeth).
# **N1a round 1 수정**: 이 픽스처는 payload §4·§5 URL 일괄 변환에서 §5 URL이 함께
# 지워지는 바람에 phantom ST9 자체가 사라져 잠시 무이빨이 됐었다(리뷰가 실행으로
# 적발) — URL을 복원해 되살렸다. 그 결과 §5에 URL이 남아 N1a(payload_url_free)도
# **함께** 발화한다(의도된 결과, url-in-sec4/url-in-s1과 같은 예외 취급) — 그래서
# gate 단언은 이제 malformed §5 verdict entries뿐 아니라 payload 외부 URL 사유로도
# red이고, 두 사유는 서로 독립적이다(하나를 mutation으로 꺼도 다른 하나가 여전히
# red를 낸다 — U3-T8 이미 N1a 단독을 확인했으므로 여기서는 skepticism 반쪽만 잰다).
skep="$(python3 "$SCRIPT" skepticism "$FX/interview-brief-verdict-st-in-url.md" 2>/dev/null)"
printf '%s' "$skep" | grep -q 'no-ST-ref' \
  && ok "FIX4: URL 안 phantom ST9는 ST 요구를 충족시키지 못함 (no-ST-ref)" \
  || no "FIX4: URL 안 ST 토큰이 ST 요구를 잘못 충족시킴"
python3 "$SCRIPT" gate "$FX/interview-brief-verdict-st-in-url.md" >/dev/null 2>&1 \
  && no "FIX4: URL 안 phantom ST9 픽스처가 게이트를 통과함" \
  || ok "FIX4: URL 안 phantom ST9 픽스처 → red"

# FIX4-bis (sweep 발견): bijection_a_errors(check_brief.py:688)도 ST<N>을 찾기 전에
# URL을 벗겨낸다 — skepticism_malformed와 같은 방어를 다른 소비자에서 반복한 것이다.
# 위 FIX4의 gate 단언은 exit code만 보므로 이 defense를 안 껐어도 다른 사유(malformed
# §5 verdict entries)로 이미 red라 이 결함을 못 잡는다(sweep 실행 실증: 688을
# 무력화해도 123/123 그대로 GREEN). message teeth로 직접 잡는다 — phantom ST9가
# "판정 없는 steelman"으로 오탐되면 안 된다.
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-verdict-st-in-url.md" 2>/dev/null)"
printf '%s' "$out" | grep -q 'ST9: payload §5가 참조하지만' \
  && no "FIX4-bis: bijection A가 URL 안 phantom ST9를 판정 없는 steelman으로 오탐" \
  || ok "FIX4-bis: bijection A도 URL 안 phantom ST9를 참조로 안 본다"

# T17: web kill switch 는 ST 참조 요구를 완화하지 않는다 (web과 무관한 파일-축 drift-guard).
# 이 자리에 있던 앞 절반(「web 비활성 시 §4·§5 URL 없는 verdict 항목 → green」)은
# v0.44.0 이 그 URL 요구를 지운 뒤로 **아무것도 재지 않았다** — web ON 에서도 같은
# 픽스처가 green 이라 kill switch 와 무관했고, 「완화가 산다」는 거짓 인용만 남겼다.
# 지운 이유를 여기 적어 둔다(다시 넣으면 그때는 실재하는 요구를 짚어야 한다).
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

# --- U2-T3: N1b 등식 + bijection C 합집합 -----------------------------------
# N1b 위쪽: payload §6 에 S2 가 있으면 red
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-payload-s2.md" 2>&1)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'payload §6'; } \
  && ok "U2-T3: payload §6 에 S2 → red (N1b 위쪽)" \
  || no "U2-T3: payload §6 의 S2 가 안 잡힌다"

# N1b 아래쪽: payload §6 을 비우면 red — 등식 술어는 스스로 양성이다
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-payload-empty-sec6.md" 2>&1)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'payload §6'; } \
  && ok "U2-T3: payload §6 을 비우면 red (N1b 아래쪽)" \
  || no "U2-T3: 빈 payload §6 이 통과한다 — ⊆ 로 썼는가"

# 항목 0건: #5 가 공허한 유일한 상태. N1b 만이 막는다.
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-zero-items.md" 2>&1)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'payload §6'; } \
  && ok "U2-T3: 항목 0건 + 빈 §6 → red (N1b)" \
  || no "U2-T3: 항목 0건에서 빈 §6 이 통과한다"

# 합집합: audit §6 의 S5 를 지우면 그 id 를 쓰는 항목이 dangling
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-audit-drop-s5.md" 2>&1)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'bijection C'; } \
  && ok "U2-T3: audit §6 에서 앵커 삭제 → red (#5 합집합)" \
  || no "U2-T3: bijection C 가 audit 쪽을 안 본다"

# --- U3-T7: «출처키» ∀ + audit §7 키 집합 포함 ------------------------------
# #13: landscape_uncited → landscape_unkeyed 술어 교체. URL 요구는 audit으로 갔지만
# ∀(§4 항목마다 무언가 필수)는 payload에 남는다 — 이번엔 URL이 아니라 «출처키».
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-unkeyed-entry.md" 2>&1)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'unkeyed landscape'; } \
  && ok "U3-T7: §4 항목 하나에 «키» 없음 → red (#13, ∀ 보존)" \
  || no "U3-T7: ∀ 가 payload 에 안 남았다"

# N2: payload §4 의 «키» 집합이 audit §7 이 선언한 집합에 포함되지 않으면 red.
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-key-undeclared.md" 2>&1)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'landscape keys'; } \
  && ok "U3-T7: audit §7 에 없는 키 → red (N2)" \
  || no "U3-T7: N2 가 키 집합 포함을 안 본다"

# 집합이라 중복이 접힌다 — 두 §4 항목이 같은 키, audit §7 에 1건.
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-dup-key.md" 2>/dev/null)"; rc=$?
[[ $rc -eq 0 ]] && ok "U3-T7: 같은 키를 쓰는 두 항목 → GREEN (개수가 아니라 집합)" \
  || { printf '%s\n' "$out"; no "U3-T7: 중복 키가 red — 개수 결속으로 구현했는가"; }

# web-off 실제 형상(리포 픽스처 interview-brief-no-landscape.md — §4 항목 1건에 URL도
# «키»도 없음): N2(landscape_keys_declared) 가 kill switch 코드 없이도 공집합 ⊆ 무엇이든으로
# 자체 통과하는지를 **N2 하나만** 물어야 한다. 이 픽스처를 `gate`로 물으면 #13
# (landscape_unkeyed, ∀, web 무관 — 방금 위 블록이 그 요구를 확인했다)이 **같은 무키
# 항목**에서 독립적으로 발화한다 — 그리고 그 발화는 옳다: 이 fixture는 위쪽 "무인용
# landscape가 종료를 차단 (R2/AC4)" 락이 web ON에서 지금도 지키는 바로 그 red다. `gate`로
# 물으면 두 검사가 뒤섞여 N2 하나만의 속성을 잴 수 없고, 게다가 어떤 env 값을 넣어도
# #13이 항상 발화하므로 이 조합의 `gate`는 **어떤 env에서도 GREEN이 될 수 없다** — 그래서
# N2 함수를 직접 호출해 격리한다(양성 대조는 위 "key-undeclared" 블록 — N2가 실제로
# non-empty를 낼 수 있음을 이미 보였다).
n2_out="$(PYTHONPATH="$REPO_ROOT/plugins/spec-distill/scripts" python3 -c '
import sys, check_brief as cb
payload = open(sys.argv[1], encoding="utf-8").read()
audit = open(sys.argv[2], encoding="utf-8").read()
print(cb.landscape_keys_declared(payload, audit))
' "$FX/interview-brief-no-landscape.md" "$FX/interview-brief-no-landscape.audit.md" 2>&1)"
[[ "$n2_out" == "[]" ]] \
  && ok "U3-T7: web-off 실제 형상 → N2 는 공집합 ⊆ 무엇이든으로 자체 통과 (kill switch 코드 불필요)" \
  || no "U3-T7: web-off 가 red — N2 가 구조적 면제를 못 한다 ($n2_out)"

# --- U3-T8: N1a 부재 축 + §6 예외 ------------------------------------------
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-url-in-sec4.md" 2>&1)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q '외부 URL'; } \
  && ok "U3-T8: payload §4 에 URL → red (N1a)" || no "U3-T8: 부재 축이 안 문다"

# §6 S1 안의 URL 은 예외다 — 사용자가 자기 요청에 쓴 것이다
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-url-in-s1.md" 2>&1)"; rc=$?
[[ $rc -eq 0 ]] && ok "U3-T8: §6 S1 안의 URL → GREEN (§2.3 축 2 예외)" \
  || { printf '%s\n' "$out"; no "U3-T8: §6 예외가 없다 — L2 와 동시 만족 불가능해진다"; }

# 같은 픽스처가 verbatim 검사와도 동시 만족돼야 한다 (이 예외의 존재 이유)
python3 "$REPO_ROOT/plugins/spec-distill/scripts/check_verbatim_coverage.py" "$FX/interview-brief-url-in-s1.md" \
  "$FX/state-url-in-s1.md" "$FX/interview-brief-url-in-s1.audit.md" >/dev/null 2>&1
[[ $? -eq 0 ]] && ok "U3-T8: 같은 픽스처가 verbatim exit 0 (N1a 예외 ↔ L2 동시 만족)" \
  || no "U3-T8: N1a 예외와 L2 가 동시 만족되지 않는다 — 예외의 존재 이유가 무너졌다"

# 삭제 우회로 셋 (N1a 의 이빨은 N1a 안에 없다)
for fx in no-sec4 sec4-header-only sec5-no-entries; do
  python3 "$SCRIPT" gate "$FX/interview-brief-$fx.md" >/dev/null 2>&1
  [[ $? -ne 0 ]] && ok "U3-T8: 우회 $fx → red" || no "U3-T8: 우회 $fx 가 통과 — N1a 가 공허해진다"
done

# --- U3-T8c: N1a 의 코퍼스는 payload **전문** − §6 다 (최종 리뷰 I1) -----------
# 설계 §2.3 이 못 박은 코퍼스는 「payload 에서 §6 을 뺀 나머지」인데, 구현이
# `_body()` 위에 얹혀 있어 실제로는 **frontmatter 와 펜스까지 뺀 것**이었다.
# 벗겨진 바이트는 하류 문서에 그대로 실려 나가므로 그 벗김은 두 개의 문이었다
# (실측: 펜스 안 URL 2건 → `{"pass": true}` rc 0 / frontmatter 인라인 주석의 URL →
# 같은 방식으로 통과). §3.2 의 탈출로 표는 **삭제** 3종만 열거했고 이 둘은 없었다.
#
# 픽스처는 리포에 새로 두지 않고 `interview-brief-valid.md` 를 TMPD 에서 변형한다 —
# 변형 지점이 단언 바로 옆에 보이고, 기존 픽스처가 무엇에 기대는지 건드리지 않는다.
n1a_case() {  # $1 = TMPD 안 stem
  cp "$FX/interview-brief-valid.md" "$TMPD/$1.md"
  cp "$FX/interview-brief-valid.audit.md" "$TMPD/$1.audit.md"
  sed -i.bak "s|^audit_file:.*|audit_file: $1.audit.md|" "$TMPD/$1.md"; rm -f "$TMPD/$1.md.bak"
}

n1a_case urlfence
python3 - "$TMPD/urlfence.md" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
m = re.search(r"(?m)^##\s+4\.\s+External Landscape[^\n]*\n", t)
assert m, "§4 헤딩 부재 — 픽스처가 바뀌었다"
p.write_text(t[:m.end()] + "\n```text\nhttps://fence.example.com/a\n```\n" + t[m.end():],
             encoding="utf-8")
PY
out="$(python3 "$SCRIPT" gate "$TMPD/urlfence.md" 2>&1)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q '외부 URL'; } \
  && ok "U3-T8c: 펜스 안 URL → red (코퍼스가 펜스를 벗기지 않는다)" \
  || no "U3-T8c: 펜스 안 URL 이 통과 — N1a 가 _body() 의 펜스 스트립을 물려받았다"

n1a_case urlfm
python3 - "$TMPD/urlfm.md" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
t2, n = re.subn(r'(?m)^(\s*statement:\s*"[^"]*")\s*$', r"\1   # https://fm.example.com/x",
                t, count=1)
assert n == 1, "frontmatter statement 줄 부재 — 픽스처가 바뀌었다"
p.write_text(t2, encoding="utf-8")
PY
out="$(python3 "$SCRIPT" gate "$TMPD/urlfm.md" 2>&1)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q '외부 URL'; } \
  && ok "U3-T8c: frontmatter 주석의 URL → red (코퍼스가 frontmatter 를 벗기지 않는다)" \
  || no "U3-T8c: frontmatter URL 이 통과 — N1a 가 _body() 의 frontmatter 스트립을 물려받았다"

# §6 경계를 **펜스 밖 헤딩**으로만 찾는가. 안 그러면 위 둘을 닫으면서 같은 모양의
# 새 문을 연다 — 펜스 안에 가짜 `## 6.` 을 적으면 거기부터 다음 `## N.` 까지가
# 코퍼스에서 잘려 나간다.
n1a_case urlfakes6
python3 - "$TMPD/urlfakes6.md" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
m = re.search(r"(?m)^##\s+4\.\s+External Landscape[^\n]*\n", t)
assert m, "§4 헤딩 부재 — 픽스처가 바뀌었다"
inj = "\n```text\n## 6. 사용자 원문\n```\n\n위장 경계 뒤: https://fake.example.com/x\n"
p.write_text(t[:m.end()] + inj + t[m.end():], encoding="utf-8")
PY
out="$(python3 "$SCRIPT" gate "$TMPD/urlfakes6.md" 2>&1)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q '외부 URL'; } \
  && ok "U3-T8c: 펜스 안 가짜 §6 헤딩은 경계가 아니다 → red" \
  || no "U3-T8c: 펜스 안 가짜 §6 이 코퍼스를 잘라냈다 — 새 탈출로"

# 양성 대조 — 「URL 을 못 찾았다」와 「아무것도 안 읽었다」를 가른다.
# 부재 술어의 초록은 그 자체로는 증거가 아니다: 코퍼스가 빈 문자열이어도 위 세
# 단언은 전부 초록이 된다(그리고 실제 brief 는 전부 통과한다). 그래서 코퍼스의
# **구성**을 직접 단언한다 — 무엇이 들어 있고 무엇이 빠졌는지. 이름(§6 헤딩·
# frontmatter 키·펜스 토큰)은 여기 계약으로 고정하고, §6 본문 첫 줄만 픽스처에서
# 값으로 읽는다. 행 수는 리터럴 5 로 못 박는다 — 추출기가 죽으면 리포트가 비고
# while 루프가 아예 안 돌아 단언이 조용히 사라진다(F3 에서 실측된 실패형).
N1A_ERR="$(mktemp -t sdN1aerr)"
corpus_report="$(python3 - "$SCRIPT" "$TMPD/urlfence.md" 2>"$N1A_ERR" <<'PY'
import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location("cb_n1a", sys.argv[1])
cb = importlib.util.module_from_spec(spec); spec.loader.exec_module(cb)
raw = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8")
corpus = cb._payload_excluding_section6(raw)
S6 = "## 6. 사용자 원문"
tail = [ln for ln in raw.split(S6, 1)[-1].splitlines() if ln.strip()] if S6 in raw else []
s6_first = tail[0] if tail else ""


def row(cond, name):
    print(("YES\t" if cond else "NO\t") + name)


row(S6 in raw, "원본에 §6 헤딩이 있다 (제외가 공허하지 않다)")
row(S6 not in corpus, "코퍼스에서 §6 헤딩이 빠졌다")
row(bool(s6_first) and s6_first not in corpus, "코퍼스에서 §6 본문 첫 줄이 빠졌다")
row("user_sourced_items" in corpus, "코퍼스가 frontmatter 를 담는다")
row(chr(96) * 3 + "text" in corpus, "코퍼스가 펜스 블록을 담는다")
PY
)"
corpus_rc=$?
[[ "$corpus_rc" -eq 0 ]] \
  && ok "U3-T8c(양성): 코퍼스 추출기가 정상 종료했다 (rc=0)" \
  || no "U3-T8c(양성): 코퍼스 추출기가 rc=$corpus_rc 로 죽었다 — 아래 단언은 무의미하다: $(tr '\n' ' ' < "$N1A_ERR" | tail -c 200)"
n1a_rows="$(grep -cE '^(YES|NO)'$'\t' <<<"$corpus_report" || true)"
[[ "$n1a_rows" -eq 5 ]] \
  && ok "U3-T8c(양성): 구성 단언이 정확히 5행이다" \
  || no "U3-T8c(양성): 구성 단언이 5행이 아니라 $n1a_rows — 리포트가 비었거나 잘렸다(단언 소실)"
rm -f "$N1A_ERR"
while IFS=$'\t' read -r tag name; do
  case "$tag" in
    YES) ok "U3-T8c(양성): $name" ;;
    NO)  no "U3-T8c(양성): $name — 코퍼스가 설계 §2.3 과 다르다" ;;
  esac
done <<< "$corpus_report"

# sentinel 조임: web ON 에서 「생략」 한 단어만은 안 된다
python3 "$SCRIPT" gate "$FX/interview-brief-sentinel-only.md" >/dev/null 2>&1
[[ $? -ne 0 ]] && ok "U3-T8: web ON + sentinel only → red (#12 조임)" \
  || no "U3-T8: sentinel 구멍이 열려 있다 — N1a 의 공허 우회로"
DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 python3 "$SCRIPT" gate "$FX/interview-brief-sentinel-only.md" >/dev/null 2>&1
[[ $? -eq 0 ]] && ok "U3-T8: web OFF + sentinel only → GREEN (정당한 degrade 를 막지 않는다)" \
  || no "U3-T8: 조임이 정당한 degrade 까지 막는다"

# U3-T8(양성/음성): _web_disabled() 를 실제로 부르는 함수가 landscape_present 하나뿐인가.
# 개수(grep -c)는 advisory 배출까지 세어 공시와 완화를 혼동하므로, 함수 본문만 도려내
# 지점을 대조한다 (양성 + 음성 짝 — 그래야 "아무것도 안 걸림"으로 통과하는 죽은 락이 아니다).
body_of() { awk -v f="$1" '$0 ~ "^def "f"\\(" {p=1;next} p && /^def |^[A-Z_]+ = / {exit} p' \
  "$REPO_ROOT/plugins/spec-distill/scripts/check_brief.py"; }
printf '%s' "$(body_of landscape_present)" | grep -q '_web_disabled()' \
  && ok "U3-T8(양성): landscape_present 가 _web_disabled() 를 부른다 — 완화되는 그 하나" \
  || no "U3-T8(양성): 조임이 사라졌다 — sentinel 구멍이 무조건 열려 있다"
for fn in landscape_unkeyed skepticism_malformed payload_url_free; do
  printf '%s' "$(body_of $fn)" | grep -q '_web_disabled()' \
    && no "U3-T8(음성): $fn 이 여전히 _web_disabled() 로 완화된다 — 공시가 「하나」라고 말하는데 거짓" \
    || ok "U3-T8(음성): $fn 은 완화되지 않는다"
done

# ── N1c — §6 경계 유일성 (v0.46.0) ──────────────────────────────────────────
# N1a 의 코퍼스(「payload 에서 §6 을 뺀 나머지」)와 N1b 의 코퍼스(「payload §6」)는 서로의
# 여집합이다. 그래서 둘 다 **§6 이 어디부터 어디까지인지가 유일할 때만** 정의된다. 헤딩이
# 둘이면 두 검사는 「첫 번째」를 골라야 하고, 그 선택은 곧 저자가 옮길 수 있는 경계가 된다.
#
# 축은 「두 번째 §6 헤딩이 **어디에** 놓이는가」다. 값 하나만 케이스로 잡으면 락이 그 자리에만
# 이빨을 갖는다 — v0.44.0 이 «펜스 안» 가짜 헤딩만 닫고 «펜스 밖»을 열어 둔 것이 정확히 그
# 실패였다(실측: §4 꼬리 rc 0). 그래서 축의 값들을 데이터로 돌린다:
#   frontmatter · §4 꼬리(펜스 밖) · 펜스 안 · audit 파일
# **그리고 축은 하나가 아니라 둘이다.** §6 은 (시작, 종결) 두 좌표를 갖고, v0.46.0 은 시작만
# 못 박아 종결 좌표로 같은 공격이 그대로 들어왔다 — audit §6 안에 **펜스로 감싼** `## 7.` 을
# 두면 게이트는 rc 0 인데 번들의 `<<<AUDIT-VERBATIM>>>` 이 비거나 위조본으로 바뀐다.
# 그래서 종결 좌표의 값들도 같은 표에서 돈다.
# 각 값마다 **양성 짝**을 함께 돌린다 — 주입한 줄에서 `##` 만 무력화한 판본이 green 이어야
# 그 red 의 원인이 그 헤딩임이 증명된다(주입 자체가 다른 검사를 깨서 나는 red 와 구분).
N1C_ERR="$(mktemp -t sdN1cerr)"
N1C_MANIFEST="$(python3 - "$FX" "$TMPD" 2>"$N1C_ERR" <<'PY'
import pathlib, re, sys

fx, tmpd = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
BASE_P = (fx / "interview-brief-valid.md").read_text(encoding="utf-8")
BASE_A = (fx / "interview-brief-valid.audit.md").read_text(encoding="utf-8")
HEAD = "## 6. 사용자 원문"
# 중화판: `##` 를 지워 헤딩이 아니게 만든다. 나머지 바이트는 armed 판과 같다.
DEAD = "neutralized 6. 사용자 원문"


def at_frontmatter(text, line):
    m = re.search(r"(?m)^source:[^\n]*\n", text)
    assert m, "frontmatter source 줄 부재 — 픽스처가 바뀌었다"
    return text[:m.end()] + line + "\n" + text[m.end():]


def at_section4_tail(text, line):
    m = re.search(r"(?m)^- Next\.js app-router SSR[^\n]*\n", text)
    assert m, "§4 항목 줄 부재 — 픽스처가 바뀌었다"
    return text[:m.end()] + "\n" + line + "\n" + text[m.end():]


def in_fence(text, line):
    m = re.search(r"(?m)^##\s+4\.\s+External Landscape[^\n]*\n", text)
    assert m, "§4 헤딩 부재 — 픽스처가 바뀌었다"
    return text[:m.end()] + "\n```text\n" + line + "\n```\n" + text[m.end():]


def audit_in_fence(text, line):
    i = text.index(HEAD)
    return text[:i] + "```text\n" + line + "\n```\n\n" + text[i:]


def payload_sec6_fenced_end(text, line):
    m = re.search(r"(?m)^##\s+6\.\s+사용자 원문[^\n]*\n", text)
    assert m, "payload §6 헤딩 부재 — 픽스처가 바뀌었다"
    return text[:m.end()] + "```text\n" + line + "\n```\n" + text[m.end():]


def audit_sec6_fenced_end(text, line):
    m = re.search(r"(?m)^##\s+6\.\s+사용자 원문[^\n]*\n", text)
    assert m, "audit §6 헤딩 부재 — 픽스처가 바뀌었다"
    return text[:m.end()] + "```text\n" + line + "\n```\n" + text[m.end():]


END = "## 7. 위장 종결"          # 종결 후보로 읽히는 줄
END_DEAD = "위장 아님 7. 종결"    # 같은 자리, 헤딩이 아닌 줄

# (stem, label, payload 주입기, audit 주입기, armed 줄, 중화 줄)
CASES = [
    ("n1c-fm", "시작: payload frontmatter 안", at_frontmatter, None, HEAD, DEAD),
    ("n1c-s4", "시작: payload §4 꼬리 (펜스 밖)", at_section4_tail, None, HEAD, DEAD),
    ("n1c-fence", "시작: payload §4 의 펜스 안", in_fence, None, HEAD, DEAD),
    ("n1c-audit", "시작: audit 의 펜스 안", None, audit_in_fence, HEAD, DEAD),
    ("n1c-pend", "종결: payload §6 안의 펜스 `## 7.`", payload_sec6_fenced_end, None, END, END_DEAD),
    ("n1c-aend", "종결: audit §6 안의 펜스 `## 7.`", None, audit_sec6_fenced_end, END, END_DEAD),
]
rows = []
for stem, label, pay_fn, aud_fn, armed_line, dead_line in CASES:
    for state, line in (("ARMED", armed_line), ("NEUTRAL", dead_line)):
        s = stem + "-" + state.lower()
        pay = BASE_P.replace("audit_file: interview-brief-valid.audit.md",
                             "audit_file: " + s + ".audit.md")
        aud = BASE_A.replace("interview-brief-valid.md", s + ".md")
        if pay_fn is not None:
            pay = pay_fn(pay, line)
        if aud_fn is not None:
            aud = aud_fn(aud, line)
        (tmpd / (s + ".md")).write_text(pay, encoding="utf-8")
        (tmpd / (s + ".audit.md")).write_text(aud, encoding="utf-8")
        rows.append("\t".join((s, state, label)))
print("\n".join(rows))
PY
)"
n1c_rc=$?
[[ "$n1c_rc" -eq 0 ]] \
  && ok "N1c(양성): 케이스 생성기가 정상 종료했다 (rc=0)" \
  || no "N1c(양성): 케이스 생성기가 rc=$n1c_rc 로 죽었다 — 아래 N1c 단언은 무의미하다: $(tr '\n' ' ' < "$N1C_ERR" | tail -c 200)"
rm -f "$N1C_ERR"
# 행 수는 **리터럴 8** 이다 (축 4값 × {armed, 중화}). 생성기에서 유도하면 CASES 가 빈
# 목록이 되는 변형에서 `0 == 0` 으로 다시 공허해진다 — 피검자에서 기대값을 끌어오는 실패형.
n1c_rows="$(grep -cE '^n1c-' <<<"$N1C_MANIFEST" || true)"
[[ "$n1c_rows" -eq 12 ]] \
  && ok "N1c(양성): 케이스가 정확히 12건이다 (시작 4값 + 종결 2값, 각 × 2)" \
  || no "N1c(양성): 케이스가 12건이 아니라 $n1c_rows — 리포트가 비었거나 잘렸다(N1c 단언 소실)"
while IFS=$'\t' read -r stem state label; do
  [[ -n "${stem:-}" ]] || continue
  out="$(python3 "$SCRIPT" gate "$TMPD/$stem.md" 2>&1)"; rc=$?
  case "$state" in
    ARMED)
      { [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q '§6 경계가 유일하게 해석되지 않는다'; } \
        && ok "N1c: $label → red" \
        || no "N1c: $label 인데 그 원인으로 red 가 안 난다 — 경계를 저자가 옮길 수 있다: $out" ;;
    NEUTRAL)
      [[ $rc -eq 0 ]] \
        && ok "N1c(양성짝): $label 에서 헤딩만 무력화하면 green — red 의 원인이 그 헤딩이다" \
        || no "N1c(양성짝): $label 의 중화판이 red — 이 케이스의 red 는 §6 중복이 원인이 아니다: $out" ;;
  esac
done <<< "$N1C_MANIFEST"

# N1a 의 fail-closed 폴백 — 경계가 비유일하면 코퍼스에서 **한 글자도 빼지 않는다**.
# N1c 를 지워도 C 통로가 다시 열리지 않게 하는 두 번째 방벽이다. 부재 술어라 양성 짝을
# 함께 단언한다(중화판에서는 §6 이 실제로 빠져야 한다 — 안 빠지면 이 단언은 「아무것도
# 안 읽었다」와 구별되지 않는다).
N1CF_ERR="$(mktemp -t sdN1cferr)"
n1c_fallback="$(python3 - "$SCRIPT" "$TMPD/n1c-s4-armed.md" "$TMPD/n1c-s4-neutral.md" 2>"$N1CF_ERR" <<'PY'
import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location("cb_n1c", sys.argv[1])
cb = importlib.util.module_from_spec(spec); spec.loader.exec_module(cb)
armed = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8")
neutral = pathlib.Path(sys.argv[3]).read_text(encoding="utf-8")
print(("YES\t" if cb._payload_excluding_section6(armed) == armed else "NO\t")
      + "경계 비유일이면 N1a 코퍼스가 payload 전문 그대로다 (fail-closed)")
print(("YES\t" if len(cb._payload_excluding_section6(neutral)) < len(neutral) else "NO\t")
      + "경계 유일이면 N1a 코퍼스에서 §6 이 실제로 빠진다 (양성 짝)")
PY
)"
n1cf_rc=$?
[[ "$n1cf_rc" -eq 0 ]] \
  && ok "N1c(폴백/양성): 코퍼스 추출기가 정상 종료했다 (rc=0)" \
  || no "N1c(폴백/양성): 코퍼스 추출기가 rc=$n1cf_rc 로 죽었다: $(tr '\n' ' ' < "$N1CF_ERR" | tail -c 200)"
rm -f "$N1CF_ERR"
n1cf_rows="$(grep -cE '^(YES|NO)'$'\t' <<<"$n1c_fallback" || true)"
[[ "$n1cf_rows" -eq 2 ]] \
  && ok "N1c(폴백/양성): 단언이 정확히 2행이다" \
  || no "N1c(폴백/양성): 단언이 2행이 아니라 $n1cf_rows — 리포트가 비었거나 잘렸다"
while IFS=$'\t' read -r tag name; do
  case "$tag" in
    YES) ok "N1c(폴백): $name" ;;
    NO)  no "N1c(폴백): $name — 폴백이 사라졌다" ;;
  esac
done <<< "$n1c_fallback"

# ── N1b 의 코퍼스는 **출하되는 바이트**다 (v0.46.0) ─────────────────────────
# 결함: N1b 가 `_body()` 를 경유해 §6 을 찾았다. `_body()` 는 펜스를 벗기므로 payload §6
# **안**의 펜스에 `- **S5**` 를 적으면 앵커 집합이 `{S1}` 으로 계산돼 등식이 만족되는데,
# 그 줄은 payload 에 그대로 남아 번들에 실려 충실도 리뷰어에게 원문으로 나갔다(실측 rc 0).
# 축은 「앵커가 어떤 표기 안에 있는가」다 — 펜스 안 / 펜스 밖 둘 다 같은 판정이어야 한다.
for variant in fenced plain; do
  cp "$FX/interview-brief-valid.md" "$TMPD/n1b-$variant.md"
  cp "$FX/interview-brief-valid.audit.md" "$TMPD/n1b-$variant.audit.md"
  python3 - "$TMPD/n1b-$variant.md" "$variant" <<'PY'
import pathlib, sys
p, variant = pathlib.Path(sys.argv[1]), sys.argv[2]
t = p.read_text(encoding="utf-8")
t = t.replace("audit_file: interview-brief-valid.audit.md",
              "audit_file: " + p.stem + ".audit.md")
i = t.index("## 7. Next Action")
body = "- **S5** 🗣 몰래 실린 원문:\n  > \"게이트엔 안 보이고 하류엔 보인다\"\n"
blk = ("```\n" + body + "```\n") if variant == "fenced" else body
p.write_text(t[:i] + blk + t[i:], encoding="utf-8")
PY
  sed -i.bak "s|^payload:.*|payload: n1b-$variant.md|" "$TMPD/n1b-$variant.audit.md"
  rm -f "$TMPD/n1b-$variant.audit.md.bak"
  out="$(python3 "$SCRIPT" gate "$TMPD/n1b-$variant.md" 2>&1)"; rc=$?
  { [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q "'S5'"; } \
    && ok "N1b: payload §6 의 $variant 앵커 S5 → red (코퍼스가 출하 바이트다)" \
    || no "N1b: payload §6 의 $variant 앵커 S5 가 안 잡힌다 — 코퍼스가 하류보다 적게 본다: $out"
done
# 양성 짝 — 같은 펜스에서 **앵커 줄만** 빼면 green. red 의 원인이 「펜스가 있다」가 아니라
# 「§6 이 S1 아닌 앵커를 준다」임을 가른다.
cp "$FX/interview-brief-valid.md" "$TMPD/n1b-noanchor.md"
cp "$FX/interview-brief-valid.audit.md" "$TMPD/n1b-noanchor.audit.md"
python3 - "$TMPD/n1b-noanchor.md" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
t = t.replace("audit_file: interview-brief-valid.audit.md",
              "audit_file: n1b-noanchor.audit.md")
i = t.index("## 7. Next Action")
p.write_text(t[:i] + "```\n앵커가 아닌 예시 줄\n```\n" + t[i:], encoding="utf-8")
PY
sed -i.bak "s|^payload:.*|payload: n1b-noanchor.md|" "$TMPD/n1b-noanchor.audit.md"
rm -f "$TMPD/n1b-noanchor.audit.md.bak"
python3 "$SCRIPT" gate "$TMPD/n1b-noanchor.md" >/dev/null 2>&1 \
  && ok "N1b(양성짝): §6 안 펜스에 앵커가 없으면 green — 펜스 자체가 red 의 원인이 아니다" \
  || no "N1b(양성짝): 앵커 없는 펜스가 red — 위 두 red 는 S5 가 원인이 아니다"

# ── 코퍼스 분리의 기계 집행 (v0.46.0, `_body()` docstring 의 참) ─────────────
# `_body()` docstring 은 「payload §6 을 경계로 쓰는 검사(N1a·N1b)는 이 코퍼스를 쓰지
# 않는다」고 **사실을 서술한다**. 산문은 틀려도 소리를 안 내므로 호출 그래프로 집행한다.
# 셸 본문 추출기는 조용히 깨지므로 `ast` 로 판다.
#
# **양성 대조가 핵심이다**: 같은 분석기가 `_body()` 를 실제로 쓰는 함수(#13
# `landscape_unkeyed`)에서는 HIT 을 내야 한다. 안 그러면 「금지 호출을 못 찾았다」와
# 「분석기가 아무것도 안 봤다」가 구별되지 않는다.
AST_ERR="$(mktemp -t sdASTerr)"
ast_report="$(python3 - "$SCRIPT" 2>"$AST_ERR" <<'PY'
import ast, sys

tree = ast.parse(open(sys.argv[1], encoding="utf-8").read())
funcs = {n.name: n for n in ast.walk(tree)
         if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))}


def direct(name):
    node = funcs.get(name)
    if node is None:
        return None
    return {c.func.id for c in ast.walk(node)
            if isinstance(c, ast.Call) and isinstance(c.func, ast.Name)}


def reach(root):
    seen, stack = set(), [root]
    while stack:
        cur = stack.pop()
        for c in (direct(cur) or set()):
            if c not in seen:
                seen.add(c)
                stack.append(c)
    return seen


FORBIDDEN = ("_body", "_section_text")
for root in ("payload_url_free", "payload_verbatim_is_s1_only"):
    if root not in funcs:
        print("MISSING\t" + root)
        continue
    r = reach(root)
    hits = [f for f in FORBIDDEN if f in r]
    print("FORBID\t" + root + "\t" + (",".join(hits) if hits else "CLEAN"))
    print("REACH\t" + root + "\t"
          + ("YES" if "payload_section6_span" in r else "NO"))
ctrl = reach("landscape_unkeyed")
print("CTRL\t" + ("YES" if any(f in ctrl for f in FORBIDDEN) else "NO"))
PY
)"
ast_rc=$?
[[ "$ast_rc" -eq 0 ]] \
  && ok "코퍼스분리(양성): 호출그래프 분석기가 정상 종료했다 (rc=0)" \
  || no "코퍼스분리(양성): 분석기가 rc=$ast_rc 로 죽었다 — 아래 단언은 무의미하다: $(tr '\n' ' ' < "$AST_ERR" | tail -c 200)"
rm -f "$AST_ERR"
ast_rows="$(grep -cE '^(FORBID|REACH|CTRL|MISSING)'$'\t' <<<"$ast_report" || true)"
[[ "$ast_rows" -eq 5 ]] \
  && ok "코퍼스분리(양성): 리포트가 정확히 5행이다 (2 루트 × 2 + 대조 1)" \
  || no "코퍼스분리(양성): 리포트가 5행이 아니라 $ast_rows — 비었거나 잘렸다(단언 소실)"
while IFS=$'\t' read -r tag a b; do
  case "$tag" in
    MISSING) no "코퍼스분리: 함수 $a 가 없다 — 락의 대상이 사라졌다" ;;
    FORBID)  [[ "$b" == "CLEAN" ]] \
               && ok "코퍼스분리: $a 는 _body()/_section_text() 에 도달하지 않는다" \
               || no "코퍼스분리: $a 가 $b 에 도달한다 — 벗겨진 바이트를 못 보면서 하류엔 실린다 (_body docstring 이 거짓)" ;;
    REACH)   [[ "$b" == "YES" ]] \
               && ok "코퍼스분리(양성): $a 가 payload_section6_span 을 실제로 경유한다" \
               || no "코퍼스분리(양성): $a 가 공유 §6 경계를 안 쓴다 — 위 CLEAN 은 「아무것도 안 봤다」일 수 있다" ;;
    CTRL)    [[ "$a" == "YES" ]] \
               && ok "코퍼스분리(대조): 같은 분석기가 landscape_unkeyed 의 _body() 사용은 잡는다" \
               || no "코퍼스분리(대조): 분석기가 알려진 _body() 사용조차 못 잡는다 — 계측기가 고장났다" ;;
  esac
done <<< "$ast_report"

# ── §6 경계는 한 곳에서만 계산된다 (v0.47.0) ────────────────────────────────
# v0.46.0 은 §6 의 **시작** 좌표를 못 박았는데, 세 소비자가 각자 **종결** 규칙을 갖고 있었고
# 셋이 서로 달랐다 — 게이트는 펜스 밖 `^##\s+\d+\.`, 번들은 원문 `^##\s+\d+\.`, 완전성
# 검사는 원문 `^##\s`. audit §6 안에 펜스로 감싼 `## 7.` 하나면 게이트가 조용한 채 번들이
# 거기서 잘렸다(실측 rc 0 — 원문 전량 소실 / 위조본 탑재 두 형태).
#
# 「종결도 못 박는다」로 고치면 세 번째 좌표에서 같은 일이 또 난다. 그래서 술어를 올렸다 —
# **§6 은 모든 소비자에게 같은 영역으로 해석돼야 한다.** 구현은 계산기를 하나로 줄이는
# 것이고, 이 락은 그 「하나」가 실제로 하나인지를 **소비자 목록을 손으로 적지 않고** 판다.
#
# ① 파생 — `scripts/*.py` 의 `re.compile` 문자열 리터럴을 `ast` 로 전수 수집해 「`##` 헤딩
#    마커를 실제로 소비하는」 것(프로브 매치가 end>=3)을 고른다. 주석 패턴(`^\s*#`, end==1)은
#    그 기준으로 걸러진다. 그런 패턴이 `section6.py` **밖**에 있으면 red.
# ② 계측기 대조 — 같은 탐지기를 stray 를 심은 **합성 소스**에 돌려 실제로 잡는지 본다.
#    없으면 「밖에 없다」와 「탐지기가 아무것도 안 봤다」가 구별되지 않는다.
S6_ERR="$(mktemp -t sdS6err)"
s6_report="$(python3 - "$REPO_ROOT/plugins/spec-distill/scripts" 2>"$S6_ERR" <<'PY'
import ast, pathlib, re, sys

PROBE = "## 6. 사용자 원문"


def heading_patterns(source: str, label: str):
    """`##` 헤딩 마커를 실제로 소비하는 `re.compile` 리터럴들."""
    out = []
    for node in ast.walk(ast.parse(source)):
        if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                and node.func.attr == "compile" and node.args
                and isinstance(node.args[0], ast.Constant)
                and isinstance(node.args[0].value, str)):
            continue
        pat = node.args[0].value
        try:
            rx = re.compile(pat, re.MULTILINE)
        except re.error:
            continue
        m = rx.match(PROBE)
        if m and m.end() >= 3:
            out.append((label, pat))
    return out


CONTROL_SRC = (
    "import re\n"
    "STRAY = re.compile(r'(?m)^##[ ]+6[.]')\n"
    "COMMENT = re.compile(r'^[ ]*#')\n"
)
ctrl = heading_patterns(CONTROL_SRC, "control")
print("CTRL\t" + ("YES" if len(ctrl) == 1 else "NO(%d)" % len(ctrl)))

scripts = pathlib.Path(sys.argv[1])
hits = []
for f in sorted(scripts.glob("*.py")):
    if f.is_symlink():
        continue
    try:
        hits += heading_patterns(f.read_text(encoding="utf-8"), f.name)
    except SyntaxError as exc:
        print("PARSEFAIL\t%s\t%s" % (f.name, exc))
print("HITS\t%d" % len(hits))
for label, pat in hits:
    print(("OWNED\t" if label == "section6.py" else "STRAY\t") + label + "\t" + pat)
PY
)"
s6_rc=$?
[[ "$s6_rc" -eq 0 ]] \
  && ok "§6단일화(양성): 파생 탐지기가 정상 종료했다 (rc=0)" \
  || no "§6단일화(양성): 탐지기가 rc=$s6_rc 로 죽었다 — 아래 단언은 무의미하다: $(tr '\n' ' ' < "$S6_ERR" | tail -c 200)"
rm -f "$S6_ERR"
grep -q "^CTRL$(printf '\t')YES" <<<"$s6_report" \
  && ok "§6단일화(대조): 탐지기가 합성 stray 를 잡고 주석 패턴은 안 잡는다" \
  || no "§6단일화(대조): 탐지기가 계측을 못 한다 — 「밖에 없다」가 「안 봤다」와 구별되지 않는다"
s6_hits="$(grep '^HITS' <<<"$s6_report" | cut -f2)"
[[ "${s6_hits:-0}" -ge 3 ]] \
  && ok "§6단일화(양성): 헤딩 소비 패턴을 $s6_hits 개 찾았다 (탐지기가 실제로 읽었다)" \
  || no "§6단일화(양성): 헤딩 소비 패턴이 ${s6_hits:-0} 개 — 코퍼스를 못 읽었다(공허 통과)"
s6_stray="$(grep '^STRAY' <<<"$s6_report" || true)"
[[ -z "$s6_stray" ]] \
  && ok "§6단일화: §6 경계를 계산하는 정규식이 section6.py 밖에 없다" \
  || no "§6단일화: section6.py 밖에서 §6 경계를 다시 계산한다 — [$s6_stray] (소비자마다 다른 §6 을 갖는 상태의 재발)"
grep -q '^PARSEFAIL' <<<"$s6_report" \
  && no "§6단일화: 파싱 실패한 스크립트가 있다 — 그 파일은 이 락의 코퍼스 밖이다" \
  || ok "§6단일화: scripts/*.py 전부가 파싱됐다 (코퍼스 누락 없음)"

# ── 세 소비자가 같은 문서에서 같은 §6 을 본다 (행동 대조) ───────────────────
# 위 락이 「계산기가 하나」를 보장한다면, 이것은 그 하나가 **실제로 같은 답**을 주는지 잰다.
# 어느 답이 옳은지는 판정하지 않는다(피검자에서 기대값을 끌어오지 않는다) — 셋이 같은지만
# 본다. 다만 정상 문서의 공통 답이 비면 등식이 「셋 다 아무것도 못 봤다」로 공허해지므로,
# 그 경우를 따로 red 로 낸다.
TRI_ERR="$(mktemp -t sdTrierr)"
tri_report="$(python3 - "$REPO_ROOT/plugins/spec-distill/scripts" "$FX" 2>"$TRI_ERR" <<'PY'
import importlib.util, pathlib, re, sys

scripts, fx = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
sys.path.insert(0, str(scripts))


def load(name):
    spec = importlib.util.spec_from_file_location("tri_" + name, scripts / (name + ".py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


cb, bb, cvc = load("check_brief"), load("build_brief_bundle"), load("check_verbatim_coverage")
base = (fx / "interview-brief-valid.audit.md").read_text(encoding="utf-8")
head = re.search(r"(?m)^##\s+6\.\s+사용자 원문[^\n]*\n", base)
assert head, "audit §6 헤딩 부재 — 픽스처가 바뀌었다"

DOCS = [
    ("normal", base),
    ("fenced-end", base[:head.end()] + "```text\n## 7. camouflage\n```\n" + base[head.end():]),
    ("fake-start", base[:head.start()] + "## 6. camouflage\n- **S9** x\n" + base[head.start():]),
]
for label, doc in DOCS:
    a = None if cb.payload_section6_span(doc) is None else sorted(cb.payload_verbatim_anchors(doc))
    b = bb.audit_verbatim(doc)
    b = None if b is None else sorted(set(cb.S_ANCHOR_RE.findall(b)))
    try:
        c = sorted(cvc.parse_section6(doc, "x"))
    except Exception:
        c = None
    print("TRI\t%s\t%s\t%s" % (label, "SAME" if a == b == c else "SPLIT", a))
PY
)"
tri_rc=$?
[[ "$tri_rc" -eq 0 ]] \
  && ok "§6합치(양성): 3소비자 대조기가 정상 종료했다 (rc=0)" \
  || no "§6합치(양성): 대조기가 rc=$tri_rc 로 죽었다: $(tr '\n' ' ' < "$TRI_ERR" | tail -c 300)"
rm -f "$TRI_ERR"
tri_rows="$(grep -c '^TRI' <<<"$tri_report" || true)"
[[ "$tri_rows" -eq 3 ]] \
  && ok "§6합치(양성): 대조 행이 정확히 3이다" \
  || no "§6합치(양성): 대조 행이 3이 아니라 $tri_rows — 리포트가 비었거나 잘렸다(단언 소실)"
while IFS="$(printf '\t')" read -r _tag label verdict answer; do
  [[ -n "${label:-}" ]] || continue
  [[ "$verdict" == "SAME" ]] \
    && ok "§6합치: [$label] 세 소비자가 같은 §6 을 본다 ($answer)" \
    || no "§6합치: [$label] 소비자마다 다른 §6 을 본다 — 게이트가 축복한 것이 아닌 것이 하류로 나간다"
done <<< "$tri_report"
tri_normal="$(grep '^TRI' <<<"$tri_report" | grep 'normal' | cut -f4)"
[[ "$tri_normal" == \[*\'S*\]* ]] \
  && ok "§6합치(양성): 정상 문서의 공통 답이 비어 있지 않다 ($tri_normal)" \
  || no "§6합치(양성): 정상 문서의 공통 답이 [$tri_normal] — 등식이 공허하게 성립했다"

# ── 경계 매처의 관대함 ──────────────────────────────────────────────────────
# `START_RE` 에 제목을 요구하면 `## 6. 참고 자료` 같은 줄이 시작 후보에서 빠진다. 그 줄은
# 사람에게도 「6번 절」로 읽히고, 예전 `check_verbatim_coverage.SECTION6_RE` 는 실제로 그것을
# §6 시작으로 골랐다 — 좁히면 「모호(red)」가 「조용한 불일치」로 되돌아간다. v0.46.0 의
# mutation 은 펜스 축만 흔들어 이 제목 축이 열려 있었다(실측: 제목을 요구하도록 좁혀도 157/157).
# **양성(매치해야) + 음성(매치하면 안 됨) 짝**이라 넓히는 방향의 변이도 잡힌다.
SR_ERR="$(mktemp -t sdSRerr)"
sr_report="$(python3 - "$REPO_ROOT/plugins/spec-distill/scripts" 2>"$SR_ERR" <<'PY'
import importlib.util, pathlib, sys
scripts = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("sr_section6", scripts / "section6.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
MUST = ["## 6.", "##6.", "## 6. 사용자 원문", "## 6. 참고 자료", "##  6.  아무 제목"]
MUSTNOT = ["### 6.", "## 16.", "  ## 6.", "# 6.", "## 6", "##a6."]
for s in MUST:
    print("MUST\t%s\t%s" % ("HIT" if mod.START_RE.search(s) else "MISS", s))
for s in MUSTNOT:
    print("MUSTNOT\t%s\t%s" % ("HIT" if mod.START_RE.search(s) else "MISS", s))
PY
)"
sr_rc=$?
[[ "$sr_rc" -eq 0 ]] \
  && ok "경계관대함(양성): 매처 프로브가 정상 종료했다 (rc=0)" \
  || no "경계관대함(양성): 프로브가 rc=$sr_rc 로 죽었다: $(tr '\n' ' ' < "$SR_ERR" | tail -c 200)"
rm -f "$SR_ERR"
sr_rows="$(grep -cE '^(MUST|MUSTNOT)' <<<"$sr_report" || true)"
[[ "$sr_rows" -eq 11 ]] \
  && ok "경계관대함(양성): 프로브 행이 정확히 11이다 (양성 5 + 음성 6)" \
  || no "경계관대함(양성): 프로브 행이 11이 아니라 $sr_rows — 비었거나 잘렸다(단언 소실)"
while IFS="$(printf '\t')" read -r kind got form; do
  [[ -n "${kind:-}" ]] || continue
  case "$kind$got" in
    MUSTHIT)     ok "경계관대함: START_RE 가 [$form] 를 시작 후보로 본다" ;;
    MUSTMISS)    no "경계관대함: START_RE 가 [$form] 를 놓친다 — 좁히면 「모호」가 「조용한 불일치」로 되돌아간다" ;;
    MUSTNOTMISS) ok "경계관대함: START_RE 가 [$form] 를 시작 후보로 보지 않는다" ;;
    MUSTNOTHIT)  no "경계관대함: START_RE 가 [$form] 까지 잡는다 — 넓히면 정상 문서가 모호로 red" ;;
  esac
done <<< "$sr_report"

finish
