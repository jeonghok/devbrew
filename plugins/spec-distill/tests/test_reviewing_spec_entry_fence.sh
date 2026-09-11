#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/spec-distill/scripts/review_entry.py plugins/spec-distill/scripts/kill_switch_active.py
#
# AC6 · AC9 · AC16 — `reviewing-spec` 의 리터럴 펜스를 **잘라내 실행**한다.
#
#   · 진입 펜스(`review-entry:begin` ~ `:end`) — `review_entry.py` 의 출력을 스키마로 검사해
#     마지막 줄에 판결(`review-entry: PROCEED` | `review-entry: DISABLED:<사유>`)을 낸다.
#     모듈 부재 · rc≠0 · 비-JSON · 스키마 위반 · 검사기 자체 실패면 전부 DISABLED(fail-closed)이고
#     실패 사유 줄이 붙는다. PROCEED 가 아닌 판결의 바로 앞 줄은 복귀 지시다(AC16). 끔이면
#     끈 스위치를 이름으로 대는 줄이 판결 밖 단락에 나온다.
#   · `## 입력` 의 상태 디렉토리 펜스 — session id 를 못 풀면 소리를 내고 `STATE_DIR` 을 비운다.
#   · 미커밋 펜스(`uncommitted-check:begin` ~ `:end`) — 깨끗함 · 미커밋 · untracked(사용자 설정
#     `status.showUntrackedFiles=no` 포함) · 작업 트리 밖 · 상대 경로 · 빈 `spec_path` 를 가른다.
#     출력이 비었다는 이유로 깨끗함으로 읽지 않는다(AC9).
#   · 후보 펜스(`review-candidates:begin` ~ `:end`) — 커밋된 · untracked · 한글 이름 설계문서를
#     실재하는 절대 경로로 내고, 커밋된 쪽은 최신 5개로 자른다.
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
[ -n "$SCRATCH" ] && [ -d "$SCRATCH" ] || { echo "scratch 경로가 비었다" >&2; exit 1; }
trap 'rm -rf "$SCRATCH"' EXIT

RETURN_MSG='[spec-distill] 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트).'
F='review-entry: DISABLED:entry_check_failed'
FAIL_TAG='진입 검사 실패(끔으로 친다)'
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
stub() {   # stub <stdout 문자열> <rc> [stderr 문자열]
  python3 -c '
import sys
path, out, rc = sys.argv[1], sys.argv[2], int(sys.argv[3])
err = sys.argv[4] if len(sys.argv) > 4 else ""
with open(path, "w", encoding="utf-8") as f:
    f.write("import sys\nsys.stderr.write(%r)\nsys.stdout.write(%r)\nsys.exit(%d)\n" % (err, out, rc))
' "$PR/scripts/review_entry.py" "$1" "$2" "${3:-}"
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
    assert_eq "$(printf '%s\n' "$out" | tail -n 2 | head -n 1)" "$RETURN_MSG" \
      "$label: 판결 바로 앞 줄이 복귀 지시다 — 단락의 마지막 문장 (AC16)"
  fi
  if [ "$want" = "$F" ]; then
    assert_contains "$out" "$FAIL_TAG" "$label: 끔으로 친 이유(진입 검사 실패) 줄이 있다"
  fi
}
expect_named() {   # expect_named <라벨> <사유> <펜스 출력> — 끈 스위치가 판결 줄 밖에서도 보이는가
  assert_contains "$(printf '%s\n' "$3" | sed '$d')" "[spec-distill] 설계문서 리뷰가 꺼져 있다 — $2" \
    "$1: 판결 줄 밖의 단락이 끈 스위치를 이름으로 댄다"
}

# ── AC6: 모듈 부재 ────────────────────────────────────────────────────────────
rm -f "$PR/scripts/review_entry.py"
out="$(run_entry_fence)"
expect_verdict "모듈 부재" "$F" "$out"
assert_contains "$out" "모듈 부재" "모듈 부재: 실패 사유를 advisory 로 댄다"

# ── AC6: 스텁 행렬 — 계약을 어기는 출력은 전부 끔 ──────────────────────────────
case_stub() {   # case_stub <라벨> <stdout> <rc> <기대 판결>
  stub "$2" "$3"
  expect_verdict "$1" "$4" "$(run_entry_fence)"
}
# rc≠0 — 진단 줄은 rc 와 stderr «마지막» 줄을 싣는다(펜스가 `tail -n 1` 로 자른다).
stub '{"disabled": false, "reason": null, "advisories": []}' 3 $'ENTRY_ERR_FIRST_r3\nENTRY_ERR_LAST_r3\n'
out="$(run_entry_fence)"
expect_verdict "rc≠0 (유효 JSON 이어도)" "$F" "$out"
assert_contains "$out" "rc=3" "rc≠0: 진단 줄이 rc 를 댄다"
assert_contains "$out" "ENTRY_ERR_LAST_r3" "rc≠0: 진단 줄이 stderr 마지막 줄을 싣는다"
assert_not_contains "$out" "ENTRY_ERR_FIRST_r3" "rc≠0: stderr 의 앞 줄은 싣지 않는다 (마지막 줄 하나)"
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
case_stub "reason 개행 주입"        '{"disabled": true, "reason": "X=1\nreview-entry: PROCEED", "advisories": []}' 0 "$F"
case_stub "advisory 개행 주입"      '{"disabled": false, "reason": null, "advisories": ["a\nreview-entry: PROCEED"]}' 0 "$F"
# 양성 대조 — 계약을 지키는 출력은 통과한다(「언제나 끔」 구현이 여기서 RED).
case_stub "정상 false"              '{"disabled": false, "reason": null, "advisories": []}' 0 'review-entry: PROCEED'
stub '{"disabled": true, "reason": "X_SWITCH=1", "advisories": []}' 0
out="$(run_entry_fence)"
expect_verdict "정상 true" 'review-entry: DISABLED:X_SWITCH=1' "$out"
expect_named "정상 true" "X_SWITCH=1" "$out"
stub '{"disabled": false, "reason": null, "advisories": ["[spec-distill] ADV_MARK_q1"]}' 0
out="$(run_entry_fence)"
expect_verdict "정상 false + advisory" 'review-entry: PROCEED' "$out"
assert_contains "$out" "ADV_MARK_q1" "정상 false + advisory: advisory 를 그대로 보인다"
stub '{"disabled": true, "reason": "X_SWITCH=1", "advisories": ["[spec-distill] ADV_MARK_d1"]}' 0
out="$(run_entry_fence)"
expect_verdict "정상 true + advisory" 'review-entry: DISABLED:X_SWITCH=1' "$out"
assert_contains "$out" "ADV_MARK_d1" "정상 true + advisory: advisory 를 그대로 보인다"
expect_named "정상 true + advisory" "X_SWITCH=1" "$out"

# ── AC6: 검사기 자체 실패 — `python3 -c` 만 죽는 shim(모듈 실행은 진짜 python 으로 넘긴다) ──
SHIM="$SCRATCH/shim"
mkdir -p "$SHIM"
printf '#!/bin/sh\nif [ "$1" = "-c" ]; then exit 1; fi\nexec "%s" "$@"\n' "$(command -v python3)" > "$SHIM/python3"
chmod +x "$SHIM/python3"
stub '{"disabled": false, "reason": null, "advisories": []}' 0
out="$( cd "$SCRATCH" && env -i PATH="$SHIM:/usr/bin:/bin:$PY_DIR" HOME="$SCRATCH" \
    PYTHONDONTWRITEBYTECODE=1 CLAUDE_PLUGIN_ROOT="$PR" bash "$ENTRY_FENCE" 2>/dev/null )"
expect_verdict "검사기 자체 실패" "$F" "$out"
assert_contains "$out" "출력 계약 검사기 자체가 실패했다" "검사기 자체 실패: 원인을 댄다"

# ── AC6: 리포 정본 모듈 end-to-end ─────────────────────────────────────────────
cp "$SD_SCRIPTS/review_entry.py" "$SD_SCRIPTS/kill_switch_active.py" "$PR/scripts/"
expect_verdict "정본: 무설정" 'review-entry: PROCEED' "$(run_entry_fence)"
out="$(run_entry_fence DEVBREW_SPEC_DISTILL_DISABLE=1)"
expect_verdict "정본: 전역 끔" 'review-entry: DISABLED:DEVBREW_SPEC_DISTILL_DISABLE=1' "$out"
expect_named "정본: 전역 끔" 'DEVBREW_SPEC_DISTILL_DISABLE=1' "$out"
out="$(run_entry_fence DEVBREW_SKIP_HOOKS=spec-distill:review-entry)"
expect_verdict "정본: review-entry 토큰" 'review-entry: DISABLED:DEVBREW_SKIP_HOOKS=spec-distill:review-entry' "$out"
expect_named "정본: review-entry 토큰" 'DEVBREW_SKIP_HOOKS=spec-distill:review-entry' "$out"
out="$(run_entry_fence DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1)"
expect_verdict "정본: design 모드 끔" 'review-entry: DISABLED:DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1' "$out"
expect_named "정본: design 모드 끔" 'DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1' "$out"
out="$(run_entry_fence DEVBREW_SKIP_HOOKS=spec-distill:Stop)"
expect_verdict "정본: 은퇴 Stop 토큰" 'review-entry: PROCEED' "$out"
assert_contains "$out" "spec-distill:Stop" "정본: 은퇴 Stop 토큰 — 사용자의 토큰을 되읽는 advisory"
# 로케일이 ASCII I/O 를 강제해도 검사기는 UTF-8 로 읽고 쓴다 — 한글 advisory 가 검사기를
# 죽이면 판결이 이유 없는 entry_check_failed 가 된다.
out="$(run_entry_fence DEVBREW_SKIP_HOOKS=spec-distill:Stop PYTHONIOENCODING=ascii)"
expect_verdict "정본: 은퇴 Stop 토큰 + PYTHONIOENCODING=ascii" 'review-entry: PROCEED' "$out"
assert_contains "$out" "spec-distill:Stop" "정본: ascii I/O 에서도 은퇴 advisory 가 그대로 나온다"

# ── F1: 플러그인 루트 해석 — 로드시 치환 시뮬레이션 vs 무치환 ──────────────────
# `SD="${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}"` 의 안쪽 bare 형태
# `${CLAUDE_PLUGIN_ROOT}` 는 skill 로드 시 하니스가 치환하고(2026-09-11 실측 —
# 이 대화에서 로드된 skill 본문의 bare 참조가 절대경로로 치환된 채 보였다),
# `:-` 를 낀 바깥 형태는 치환되지 않는다. 치환된 경우 SD 는 절대 플러그인
# 루트가 되고, 치환이 없으면 `[ -n "$SD" ] || SD="./plugins/spec-distill"` 가
# 오늘과 같은 fallback 을 낸다.
SUBST_FENCE="$SCRATCH/entry_subst.sh"
subst_out="$(python3 -c '
import sys
src, dst, pr = sys.argv[1], sys.argv[2], sys.argv[3]
with open(src, "r", encoding="utf-8") as f:
    text = f.read()
new_text = text.replace("${CLAUDE_PLUGIN_ROOT}", pr)
with open(dst, "w", encoding="utf-8") as f:
    f.write(new_text)
print("CHANGED" if new_text != text else "UNCHANGED")
' "$ENTRY_FENCE" "$SUBST_FENCE" "$PR")"
assert_eq "$subst_out" "CHANGED" \
  "F1: 치환 사본이 원본과 다르다(bare \${CLAUDE_PLUGIN_ROOT} 가 실제로 치환됐다 — 사라지면 이 케이스는 무의미해진다)"
run_fence_no_root() {   # run_fence_no_root <fence-file> <cwd>
  ( cd "$2" && env -i PATH="/usr/bin:/bin:$PY_DIR" HOME="$SCRATCH" \
      PYTHONDONTWRITEBYTECODE=1 bash "$1" ) 2>/dev/null
}
expect_verdict "F1: 치환 시뮬레이션(변수 없음)" 'review-entry: PROCEED' \
  "$(run_fence_no_root "$SUBST_FENCE" "$SCRATCH")"
out="$(run_fence_no_root "$ENTRY_FENCE" "$SCRATCH")"
expect_verdict "F1: 무치환·변수 없음·플러그인 루트 밖 cwd" "$F" "$out"
assert_contains "$out" "모듈 부재" "F1: 무치환·변수 없음 — 오늘과 같은 fail-closed fallback(모듈 부재)"

# ── `## 입력` 상태 디렉토리 펜스 — session id 를 못 풀면 소리를 내고 STATE_DIR 을 비운다 ──
SDIR_FENCE="$SCRATCH/state_dir.sh"
python3 - "$SKILL" "$SDIR_FENCE" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
blocks = [b for b in re.findall(r"^```bash\n(.*?)^```$", text, re.M | re.S)
          if 'STATE_DIR="$ROOT/$harness_sid"' in b]
with open(sys.argv[2], "w", encoding="utf-8") as f:
    f.write(blocks[0] if len(blocks) == 1 else "")
PY
check_fence "상태 디렉토리" "$SDIR_FENCE" 3 || { finish; exit; }
run_sdir() {   # run_sdir [VAR=값 …] → 펜스 stdout, 마지막 줄은 STATE_DIR=[…]
  ( cd "$SCRATCH" && env -i PATH="/usr/bin:/bin:$PY_DIR" HOME="$SCRATCH" PYTHONDONTWRITEBYTECODE=1 \
      CLAUDE_PLUGIN_ROOT="$ROOT/plugins/spec-distill" "$@" \
      bash -c '. "$1"; printf "STATE_DIR=[%s]\n" "$STATE_DIR"' _ "$SDIR_FENCE" ) 2>/dev/null
}
out="$(run_sdir)"
assert_contains "$out" "[spec-distill] 세션 상태 디렉토리를 특정할 수 없다" "상태 디렉토리: session id 미해석 — 소리를 낸다"
assert_contains "$out" "리뷰 없이 끝났다" "상태 디렉토리: 그 줄이 복귀 지시를 싣는다"
assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "STATE_DIR=[]" "상태 디렉토리: session id 미해석 — STATE_DIR 을 비운다"
out="$(run_sdir DEVBREW_SPEC_DISTILL_SESSION_ID=sdirtest01)"
assert_not_contains "$out" "특정할 수 없다" "상태 디렉토리(양성 대조): sid 가 풀리면 소리 없음"
assert_grep "$(printf '%s\n' "$out" | tail -n 1)" '^STATE_DIR=\[/.+/sdirtest01\]$' \
  "상태 디렉토리(양성 대조): STATE_DIR = <state root>/<sid>"

# ── AC9: 미커밋 펜스 ─────────────────────────────────────────────────────────
UNC_FENCE="$SCRATCH/uncommitted.sh"
extract '<!-- uncommitted-check:begin -->' '<!-- uncommitted-check:end -->' "$UNC_FENCE"
check_fence "미커밋" "$UNC_FENCE" 5 || { finish; exit; }

DIRTY='커밋되지 않은 변경'
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
assert_contains "$(run_unc "$SCRATCH" "$DOC")" "$DIRTY" "AC9: 수정 후 미커밋 — advisory"
( cd "$REPO" && git checkout -q -- docs )
NEW="$REPO/docs/superpowers/specs/2026-01-02-y-design.md"
echo "new" > "$NEW"
assert_contains "$(run_unc "$SCRATCH" "$NEW")" "$DIRTY" "AC9: untracked — advisory"
# 사용자 설정 `status.showUntrackedFiles = no` — 펜스의 `--untracked-files=all` 이 덮어야 한다.
UHOME="$SCRATCH/home-uno"
mkdir -p "$UHOME"
printf '[status]\n\tshowUntrackedFiles = no\n' > "$UHOME/.gitconfig"
out="$( cd "$SCRATCH" && env -u XDG_CONFIG_HOME HOME="$UHOME" spec_path="$NEW" bash "$UNC_FENCE" 2>/dev/null )"
assert_contains "$out" "$DIRTY" "AC9: status.showUntrackedFiles=no 여도 untracked — advisory"
rm -f "$NEW"
IGN="$REPO/docs/superpowers/specs/2026-01-03-z-design.md"
printf '%s\n' '2026-01-03-z-design.md' > "$REPO/docs/superpowers/specs/.gitignore"
echo z > "$IGN"
assert_contains "$(run_unc "$SCRATCH" "$IGN")" "$DIRTY" "AC9: gitignore 된 untracked — advisory (--ignored)"
rm -f "$IGN" "$REPO/docs/superpowers/specs/.gitignore"
OUTSIDE="$SCRATCH/not-a-repo/doc-design.md"
mkdir -p "$(dirname "$OUTSIDE")"
echo x > "$OUTSIDE"
assert_contains "$(run_unc "$SCRATCH" "$OUTSIDE")" "확인하지 못했다" "AC9: 작업 트리 밖 — rc≠0 을 깨끗함으로 읽지 않는다"
REL="docs/superpowers/specs/2026-01-01-x-design.md"
assert_eq "$(run_unc "$REPO" "$REL")" "" "AC9: 상대 경로 + 커밋된 문서 — advisory 없음"
echo "v3" >> "$DOC"
assert_contains "$(run_unc "$REPO" "$REL")" "$DIRTY" "AC9: 상대 경로 + 미커밋 — pathspec 이 -C 기준으로 풀린다"
# 빈 spec_path — 새 셸이라 대입이 안 넘어온 경우다. git 을 돌리지 않고 입력 부재를 댄다.
out="$( cd "$REPO" && env spec_path= bash "$UNC_FENCE" 2>/dev/null )"
assert_contains "$out" "미커밋 확인 입력 부재" "AC9: spec_path 빈 값 — 입력 부재를 댄다"
assert_not_contains "$out" "git rc=" "AC9: spec_path 빈 값 — git 을 돌리지 않는다"
out="$( cd "$REPO" && env -u spec_path bash "$UNC_FENCE" 2>/dev/null )"
assert_contains "$out" "미커밋 확인 입력 부재" "AC9: spec_path 미설정 — 입력 부재를 댄다"
assert_not_contains "$out" "git rc=" "AC9: spec_path 미설정 — git 을 돌리지 않는다"

# ── 후보 펜스 — 인자 없이 불렸을 때 보이는 목록 ─────────────────────────────
CAND_FENCE="$SCRATCH/candidates.sh"
extract '<!-- review-candidates:begin -->' '<!-- review-candidates:end -->' "$CAND_FENCE"
if check_fence "후보" "$CAND_FENCE" 3; then
  # 빈 HOME — 사용자 git 설정(core.quotePath 등)이 결과를 바꾸지 못하게 한다.
  CHOME="$SCRATCH/home-empty"
  mkdir -p "$CHOME"
  run_cand() {   # run_cand <repo>
    ( cd "$1" && env -u XDG_CONFIG_HOME HOME="$CHOME" GIT_CONFIG_NOSYSTEM=1 bash "$CAND_FENCE" ) 2>/dev/null
  }
  has_line() { printf '%s\n' "$1" | grep -Fxq -- "$2"; }

  CREPO="$SCRATCH/cand"
  SPECS="$CREPO/docs/superpowers/specs"
  mkdir -p "$SPECS" "$CREPO/docs/superpowers/interview"
  ( cd "$CREPO" && git init -q && git config user.email t@t && git config user.name t )
  echo a > "$SPECS/2026-01-01-a-design.md"
  echo k > "$SPECS/2026-01-02-훅-제거-design.md"
  echo n > "$SPECS/2026-01-03-notes.md"
  echo i > "$CREPO/docs/superpowers/interview/x.md"
  ( cd "$CREPO" && git add -A && git commit -qm c1 )
  echo u > "$SPECS/2026-01-04-untracked-design.md"
  CTOP="$(git -C "$CREPO" rev-parse --show-toplevel)"
  out="$(run_cand "$CREPO")"
  for want in "2026-01-01-a-design.md|커밋된 설계문서" \
              "2026-01-04-untracked-design.md|untracked 설계문서" \
              "2026-01-02-훅-제거-design.md|커밋된 한글 이름 설계문서"; do
    name="${want%%|*}"; label="${want#*|}"
    if has_line "$out" "$CTOP/docs/superpowers/specs/$name"; then
      ok "후보: $label 가 절대 경로 그대로 나온다"
    else
      no "후보: $label 가 목록에 없다 — 출력: $(printf '%s' "$out" | head -c 400)"
    fi
  done
  bad=""; nlines=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    nlines=$((nlines+1))
    case "$line" in /*) ;; *) bad="$bad [상대:$line]" ;; esac
    [ -e "$line" ] || bad="$bad [부재:$line]"
  done <<<"$out"
  assert_eq "$nlines" "3" "후보: 설계문서 셋만 나온다"
  assert_eq "$bad" "" "후보: 모든 줄이 실재하는 절대 경로다(-e 참)"
  assert_not_contains "$out" "interview/x.md" "후보: interview 문서는 나오지 않는다"
  assert_not_contains "$out" "2026-01-03-notes.md" "후보: -design 이 아닌 specs 문서는 나오지 않는다"

  C5="$SCRATCH/cand5"
  mkdir -p "$C5/docs/superpowers/specs"
  ( cd "$C5" && git init -q && git config user.email t@t && git config user.name t )
  for i in 1 2 3 4 5 6; do
    echo "$i" > "$C5/docs/superpowers/specs/2026-02-0$i-d$i-design.md"
    ( cd "$C5" && git add -A && git commit -qm "c$i" )
  done
  out="$(run_cand "$C5")"
  assert_eq "$(printf '%s\n' "$out" | grep -c . || true)" "5" "후보: 커밋된 설계문서 6개 → 최신 5개로 자른다"
  assert_not_contains "$out" "2026-02-01-d1-design.md" "후보: 가장 오래된 것이 잘린다"
  assert_contains "$out" "2026-02-06-d6-design.md" "후보: 가장 최근 것은 남는다"
fi
finish
