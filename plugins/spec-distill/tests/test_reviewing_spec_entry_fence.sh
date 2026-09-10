#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/spec-distill/scripts/review_entry.py plugins/spec-distill/scripts/kill_switch_active.py
#
# AC6 · AC9 · AC16 — `reviewing-spec` 의 두 리터럴 펜스를 **잘라내 실행**한다.
#
#   · 진입 펜스(`review-entry:begin` ~ `:end`) — `review_entry.py` 의 출력을 스키마로 검사해
#     마지막 줄에 판결(`review-entry: PROCEED` | `review-entry: DISABLED:<사유>`)을 낸다.
#     모듈 부재 · rc≠0 · 비-JSON · 스키마 위반이면 전부 DISABLED(fail-closed)이고, PROCEED 가
#     아닌 판결 앞에는 복귀 지시가 나와야 한다(AC16).
#   · 미커밋 펜스(`uncommitted-check:begin` ~ `:end`) — 깨끗함 · 미커밋 · untracked · 작업 트리
#     밖 · 상대 경로를 가른다. 출력이 비었다는 이유로 깨끗함으로 읽지 않는다(AC9).
#
# 판정은 리터럴의 존재가 아니라 **실행한 펜스의 출력**이다 — 산문·주석은 이 판정을 만족시킬
# 수 없다. 재지 못하는 것: 모델이 판결 줄대로 분기하는가(산문 지시 — AC14 수동 e2e 몫).
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md"
SD_SCRIPTS="$ROOT/plugins/spec-distill/scripts"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/skills/reviewing-spec/SKILL.md"
  echo "plugins/spec-distill/scripts/review_entry.py"
  echo "plugins/spec-distill/scripts/kill_switch_active.py"
  exit 0
fi

. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

SCRATCH="$(mktemp -d -t sd-entry-fence-XXXXXX)" || { echo "scratch 생성 실패" >&2; exit 1; }
trap 'rm -rf "$SCRATCH"' EXIT

RETURN_MSG='[spec-distill] 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트).'
PY_DIR="$(dirname "$(command -v python3)")"

extract() {   # extract <begin-marker> <end-marker> <out>
  awk -v b="$1" -v e="$2" '
    index($0, b) {ing=1; next}
    index($0, e) {ing=0}
    ing && /^```bash$/ {inb=1; next}
    ing && inb && /^```$/ {inb=0; next}
    ing && inb {print}
  ' "$SKILL" > "$3"
}
check_fence() {   # check_fence <라벨> <파일> <최소 줄 수> — 계측기 바닥
  local n; n="$(grep -c . "$2" || true)"
  if [ "${n:-0}" -lt "$3" ]; then
    no "추출($1): ${n:-0}줄 — 마커가 사라졌거나 추출이 깨졌다. 아래 판정은 무의미하다"
    return 1
  fi
  ok "추출($1): ${n}줄"
  if bash -n "$2" 2>/dev/null; then ok "추출($1): bash -n 통과"; else no "추출($1): bash -n 실패"; fi
}

ENTRY_FENCE="$SCRATCH/entry.sh"
extract '<!-- review-entry:begin -->' '<!-- review-entry:end -->' "$ENTRY_FENCE"
check_fence "진입" "$ENTRY_FENCE" 15 || { finish; exit; }

# ── 가짜 플러그인 루트 — scripts/review_entry.py 를 케이스마다 갈아 끼운다 ────────
PR="$SCRATCH/plugin"
mkdir -p "$PR/scripts"
stub() {   # stub <stdout 문자열> <rc>
  python3 -c '
import sys
path, out, rc = sys.argv[1], sys.argv[2], int(sys.argv[3])
with open(path, "w", encoding="utf-8") as f:
    f.write("import sys\nsys.stdout.write(%r)\nsys.exit(%d)\n" % (out, rc))
' "$PR/scripts/review_entry.py" "$1" "$2"
}
run_entry_fence() {   # run_entry_fence [VAR=값 …] → 펜스 stdout
  ( cd "$SCRATCH" && env -i PATH="/usr/bin:/bin:$PY_DIR" HOME="$SCRATCH" \
      PYTHONDONTWRITEBYTECODE=1 CLAUDE_PLUGIN_ROOT="$PR" "$@" bash "$ENTRY_FENCE" ) 2>/dev/null
}
expect_verdict() {   # expect_verdict <라벨> <기대 판결> <펜스 출력>
  local label="$1" want="$2" out="$3" got n
  got="$(printf '%s\n' "$out" | grep -E '^review-entry: ' || true)"
  n="$(printf '%s' "$got" | grep -c . || true)"
  if [ "$n" != "1" ]; then
    no "$label: 판결 줄이 정확히 하나가 아니다 (${n}줄) — 출력: $(printf '%s' "$out" | head -c 300)"
    return
  fi
  if [ "$(printf '%s\n' "$out" | tail -n 1)" != "$got" ]; then
    no "$label: 판결 줄이 마지막 줄이 아니다"
    return
  fi
  assert_eq "$got" "$want" "$label: 판결"
  if [ "$want" = "review-entry: PROCEED" ]; then
    assert_not_contains "$out" "$RETURN_MSG" "$label: PROCEED 에는 복귀 지시가 없다"
  else
    assert_contains "$out" "$RETURN_MSG" "$label: 게이트 없이 끝나는 판결 앞에 복귀 지시 (AC16)"
  fi
}

# ── AC6: 모듈 부재 ────────────────────────────────────────────────────────────
rm -f "$PR/scripts/review_entry.py"
out="$(run_entry_fence)"
expect_verdict "모듈 부재" "review-entry: DISABLED:entry_check_failed" "$out"
assert_contains "$out" "모듈 부재" "모듈 부재: 실패 사유를 advisory 로 댄다"

# ── AC6: 스텁 행렬 — 계약을 어기는 출력은 전부 끔 ──────────────────────────────
F='review-entry: DISABLED:entry_check_failed'
case_stub() {   # case_stub <라벨> <stdout> <rc> <기대 판결>
  stub "$2" "$3"
  expect_verdict "$1" "$4" "$(run_entry_fence)"
}
case_stub "rc≠0 (유효 JSON 이어도)" '{"disabled": false, "reason": null, "advisories": []}' 3 "$F"
case_stub "비-JSON"                'hello' 0 "$F"
case_stub "빈 출력"                '' 0 "$F"
case_stub "JSON 두 줄"             $'{"disabled": false, "reason": null, "advisories": []}\n{"disabled": false, "reason": null, "advisories": []}' 0 "$F"
case_stub "{}"                      '{}' 0 "$F"
case_stub "disabled 문자열"         '{"disabled": "false", "reason": null, "advisories": []}' 0 "$F"
case_stub "disabled 정수"           '{"disabled": 0, "reason": null, "advisories": []}' 0 "$F"
case_stub "reason 키 없음"          '{"disabled": false, "advisories": []}' 0 "$F"
case_stub "reason 정수"             '{"disabled": true, "reason": 3, "advisories": []}' 0 "$F"
case_stub "advisories 문자열"       '{"disabled": false, "reason": null, "advisories": "x"}' 0 "$F"
case_stub "advisories 비문자열 원소" '{"disabled": false, "reason": null, "advisories": [1]}' 0 "$F"
case_stub "최상위 null"             'null' 0 "$F"
case_stub "최상위 배열"             '[]' 0 "$F"
# 양성 대조 — 계약을 지키는 출력은 통과한다(「언제나 끔」 구현이 여기서 RED).
case_stub "정상 false"              '{"disabled": false, "reason": null, "advisories": []}' 0 'review-entry: PROCEED'
case_stub "정상 true"               '{"disabled": true, "reason": "X_SWITCH=1", "advisories": []}' 0 'review-entry: DISABLED:X_SWITCH=1'
stub '{"disabled": false, "reason": null, "advisories": ["[spec-distill] ADV_MARK_q1"]}' 0
out="$(run_entry_fence)"
expect_verdict "정상 false + advisory" 'review-entry: PROCEED' "$out"
assert_contains "$out" "ADV_MARK_q1" "정상 false + advisory: advisory 를 그대로 보인다"

# ── AC6: 리포 정본 모듈 end-to-end ─────────────────────────────────────────────
cp "$SD_SCRIPTS/review_entry.py" "$SD_SCRIPTS/kill_switch_active.py" "$PR/scripts/"
expect_verdict "정본: 무설정" 'review-entry: PROCEED' "$(run_entry_fence)"
expect_verdict "정본: 전역 끔" 'review-entry: DISABLED:DEVBREW_SPEC_DISTILL_DISABLE=1' \
  "$(run_entry_fence DEVBREW_SPEC_DISTILL_DISABLE=1)"
expect_verdict "정본: review-entry 토큰" 'review-entry: DISABLED:DEVBREW_SKIP_HOOKS=spec-distill:review-entry' \
  "$(run_entry_fence DEVBREW_SKIP_HOOKS=spec-distill:review-entry)"
expect_verdict "정본: design 모드 끔" 'review-entry: DISABLED:DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1' \
  "$(run_entry_fence DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1)"
out="$(run_entry_fence DEVBREW_SKIP_HOOKS=spec-distill:Stop)"
expect_verdict "정본: 은퇴 Stop 토큰" 'review-entry: PROCEED' "$out"
assert_contains "$out" "spec-distill:Stop" "정본: 은퇴 Stop 토큰 — 사용자의 토큰을 되읽는 advisory"

# ── AC9: 미커밋 펜스 ─────────────────────────────────────────────────────────
UNC_FENCE="$SCRATCH/uncommitted.sh"
extract '<!-- uncommitted-check:begin -->' '<!-- uncommitted-check:end -->' "$UNC_FENCE"
check_fence "미커밋" "$UNC_FENCE" 5 || { finish; exit; }

REPO="$SCRATCH/repo"
mkdir -p "$REPO/docs/superpowers/specs"
( cd "$REPO" && git init -q && git config user.email t@t && git config user.name t )
DOC="$REPO/docs/superpowers/specs/2026-01-01-x-design.md"
echo "v1" > "$DOC"
( cd "$REPO" && git add -A && git commit -qm init )
run_unc() {   # run_unc <cwd> <spec_path>
  ( cd "$1" && env spec_path="$2" bash "$UNC_FENCE" ) 2>/dev/null
}
assert_eq "$(run_unc "$SCRATCH" "$DOC")" "" "AC9: 커밋된 깨끗한 문서 — advisory 없음 (양성 대조)"
echo "v2" >> "$DOC"
assert_contains "$(run_unc "$SCRATCH" "$DOC")" "커밋되지 않았다" "AC9: 수정 후 미커밋 — advisory"
( cd "$REPO" && git checkout -q -- docs )
NEW="$REPO/docs/superpowers/specs/2026-01-02-y-design.md"
echo "new" > "$NEW"
assert_contains "$(run_unc "$SCRATCH" "$NEW")" "커밋되지 않았다" "AC9: untracked — advisory"
rm -f "$NEW"
OUTSIDE="$SCRATCH/not-a-repo/doc-design.md"
mkdir -p "$(dirname "$OUTSIDE")"
echo x > "$OUTSIDE"
assert_contains "$(run_unc "$SCRATCH" "$OUTSIDE")" "확인하지 못했다" "AC9: 작업 트리 밖 — rc≠0 을 깨끗함으로 읽지 않는다"
REL="docs/superpowers/specs/2026-01-01-x-design.md"
assert_eq "$(run_unc "$REPO" "$REL")" "" "AC9: 상대 경로 + 커밋된 문서 — advisory 없음"
echo "v3" >> "$DOC"
assert_contains "$(run_unc "$REPO" "$REL")" "커밋되지 않았다" "AC9: 상대 경로 + 미커밋 — pathspec 이 -C 기준으로 풀린다"
finish
