#!/usr/bin/env bash
# superpowers 가 없을 때 · 판이 다를 때 · quality-gates 가 없을 때의 문면과 판 확인 펜스(AC22 · AC23).
#  · 지휘자 진입(`### 1.5 의존 확인`) — superpowers 가 없으면 멈추는 문장 · 판 확인 펜스
#  · 인터뷰 끝(finishing.md B-1) — superpowers 없음 갈래(brief 까지 만들고 알린 뒤 멈춤)가 그대로 · 판 확인 펜스
#  · 손 절차 머리 — superpowers 없으면 멈춤 · 걸음 7 — quality-gates 없음 문장
#  · spec-distill plugin.json 에 `dependencies` 키가 없다(음) — 양의 짝: dependencies.md 의 superpowers 행
# 판 확인 펜스는 잘라 돌린다 — 가짜 check_deps.py 가 받은 인자를 적고 STUB_RC 로 끝난다.
# 정적 락이다 — 모델이 skill 목록으로 superpowers 를 실제로 가려내는지는 재지 못한다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_superpowers_presence.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd -P)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
SD="$ROOT/plugins/spec-distill"
EC="$SD/skills/epic-conductor/SKILL.md"
FIN="$SD/skills/pm-interview/references/finishing.md"
CD="$SD/references/conducting.md"
README="$SD/README.md"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/sppresence.XXXXXX")" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
TMP="$(cd "$TMP" && pwd -P)" || exit 1
case "$TMP" in /*/sppresence.*) ;; *) echo "임시 폴더 경로가 이상하다: $TMP" >&2; exit 1 ;; esac
trap 'rm -rf "$TMP"' EXIT

STOP='superpowers 가 필요하다 — Claude Code 의 /plugin 에서 superpowers 를 설치한 뒤 다시 부른다'
QG_ABSENT='품질 게이트 없이 간다 — quality-gates 가 설치돼 있지 않다'

# section <파일> <제목 줄 ERE> <끝 줄 ERE> — 제목 줄부터 끝 줄 앞까지(제목 포함, 끝 제외)
section() {
  awk -v s="$2" -v e="$3" 'f && $0 ~ e {exit} $0 ~ s {f=1} f' "$1"
}
# sp_fences <글 파일> — `check_deps.py" superpowers` 를 부르는 bash 펜스마다 「<여는 줄>」 한 줄
sp_fences() {
  awk '/^```bash$/ {inb=1; start=NR; hit=0; next} inb && /^```$/ {if (hit) print start; inb=0; next}
       inb && /^python3 "\$[A-Za-z_]+\/scripts\/check_deps\.py" superpowers --plugin-root "\$[A-Za-z_]+" --base "<[^>]+>"$/ {hit=1}' "$1"
}
# run_sp_fence <키> <글 파일> <여는 줄> — 펜스를 잘라 가짜 check_deps.py 로 돌린다
run_sp_fence() {
  key="$1"; src="$2"; fline="$3"
  fake="$TMP/fake-$key"; mkdir -p "$fake/scripts"
  printf 'import os, sys\nopen(os.environ["ARGS_OUT"], "w", encoding="utf-8").write(" ".join(sys.argv[1:]))\nprint("[devbrew-deps] stub")\nsys.exit(int(os.environ.get("STUB_RC", "0")))\n' > "$fake/scripts/check_deps.py"
  awk -v s="$fline" 'NR>s && /^```$/ {exit} NR>s' "$src" > "$TMP/fence-$key.sh"
  guard="$(grep -c '^\([A-Za-z_][A-Za-z_]*\)="${CLAUDE_PLUGIN_ROOT}"; \[ -n "\$\1" \] || { echo "\[spec-distill\] 플러그인 루트 미해석 — ' "$TMP/fence-$key.sh")"
  assert_eq "$guard" "1" "$key: 판 확인 펜스가 자기 루트 가드 줄을 갖는다"
  for rc in 0 5; do
    rm -f "$TMP/args"
    ( cd "$TMP" && env -i PATH=/usr/bin:/bin HOME="$TMP" CLAUDE_PLUGIN_ROOT="$fake" ARGS_OUT="$TMP/args" STUB_RC="$rc" \
        PYTHONDONTWRITEBYTECODE=1 /bin/bash "$TMP/fence-$key.sh" ) >/dev/null 2>&1; got=$?
    assert_eq "$got" "$rc" "$key: 판 확인 펜스가 check_deps 의 rc $rc 를 그대로 낸다"
    case "$(cat "$TMP/args" 2>/dev/null)" in
      "superpowers --plugin-root $fake --base <"*">") ok "$key: 펜스가 superpowers · 플러그인 루트 · 기준 폴더 자리를 넘긴다 (rc $rc)" ;;
      *) no "$key: 펜스가 넘긴 인자가 다르다 (rc $rc): $(cat "$TMP/args" 2>/dev/null)" ;;
    esac
  done
  rm -f "$TMP/args-noroot"
  ( cd "$TMP" && env -i PATH=/usr/bin:/bin HOME="$TMP" ARGS_OUT="$TMP/args-noroot" /bin/bash "$TMP/fence-$key.sh" ) >/dev/null 2>&1; got=$?
  assert_eq "$got" "1" "$key: 루트가 비면 판 확인 펜스가 rc 1 로 멈춘다"
  [ -e "$TMP/args-noroot" ] && no "$key: 루트가 빈데 판 확인을 불렀다" || ok "$key: 루트가 비면 판 확인을 부르지 않는다"
}
# after_fence <글 파일> <여는 줄> — 펜스가 닫힌 뒤부터 다음 bash 펜스 · 제목 앞까지의 글
after_fence() {
  awk -v s="$2" 'NR>s && f && (/^```bash$/ || /^#/) {exit} NR>s && /^```$/ && !f {f=1; next} f' "$1"
}

for f in "$EC" "$FIN" "$CD" "$README"; do
  [ -f "$f" ] && ok "읽는다: ${f#$ROOT/}" || no "없다: ${f#$ROOT/}"
done

# ── 1. 지휘자 진입 — superpowers 가 없으면 멈춘다 · 판 확인 펜스 ─────────────────
E15="$(section "$EC" '^### 1\.5 의존 확인$' '^##+ ')"
[ -n "$E15" ] && ok "epic-conductor: 「### 1.5 의존 확인」 절을 읽었다" || no "epic-conductor: 「### 1.5 의존 확인」 절이 없다"
stopline="$(printf '%s\n' "$E15" | grep -F -- "$STOP" | head -1)"
assert_contains "$stopline" "$STOP" "epic-conductor 1.5: superpowers 가 없으면 보일 문장"
assert_contains "$stopline" "멈춘다" "epic-conductor 1.5: 그 문장의 줄이 멈춘다고 적는다"
assert_contains "$stopline" "skill 목록" "epic-conductor 1.5: 있는지는 skill 목록으로 가린다"
okrow="$(printf '%s\n' "$E15" | grep -E '^\| rc 0 ' | head -1)"
assert_contains "$okrow" "superpowers" "epic-conductor 1.5: 의존 확인 rc 0 다음이 superpowers 확인이다(바로 2 로 가지 않는다)"
printf '%s\n' "$E15" > "$TMP/e15.md"
ef="$(sp_fences "$TMP/e15.md")"
assert_eq "$(printf '%s\n' "$ef" | grep -c .)" "1" "epic-conductor 1.5: 판 확인 펜스가 정확히 하나다"
el15="$(grep -n '^### 1\.5 의존 확인$' "$EC" | head -1 | cut -d: -f1)"
if [ -n "$ef" ] && [ -n "$el15" ]; then
  efl=$((el15 + ef - 1))
  run_sp_fence conductor "$EC" "$efl"
  after="$(after_fence "$EC" "$efl")"
  assert_contains "$after" "멈추지 않는다" "epic-conductor 1.5: 판 확인 결과로는 멈추지 않는다고 적는다"
  assert_contains "$after" "다르다" "epic-conductor 1.5: 「다르다」 줄을 어떻게 하는지 적는다"
  assert_contains "$after" "확인하지 못했다" "epic-conductor 1.5: 「확인하지 못했다」 줄을 어떻게 하는지 적는다"
fi

# ── 2. 인터뷰 끝 — superpowers 없음 갈래(B-1)는 그대로 · 넘기기 직전 판 확인 펜스 ──────
B1="$(section "$FIN" '^#### B-1 — superpowers 가용성 분기$' '^#### B-2 ')"
[ -n "$B1" ] && ok "finishing.md: B-1 절을 읽었다" || no "finishing.md: B-1 절이 없다"
absent="$(printf '%s\n' "$B1" | grep -F -- '- **superpowers 부재 시**' | head -1)"
assert_contains "$absent" "brief를 완료하고" "finishing.md B-1: superpowers 가 없으면 brief 까지 만든다"
assert_contains "$absent" "**loud advisory**" "finishing.md B-1: 크게 알린다"
assert_contains "$absent" "**정지(STOP)**" "finishing.md B-1: 그 뒤 멈춘다"
assert_contains "$B1" '`[spec-distill] interview brief 를 만들었다: <payload 경로>. superpowers 가 없어 여기서 멈춘다.' \
  "finishing.md B-1: 멈춤 안내 원문이 그대로다"
printf '%s\n' "$B1" > "$TMP/b1.md"
bf="$(sp_fences "$TMP/b1.md")"
assert_eq "$(printf '%s\n' "$bf" | grep -c .)" "1" "finishing.md B-1: 판 확인 펜스가 정확히 하나다"
lb1="$(grep -n '^#### B-1 — superpowers 가용성 분기$' "$FIN" | head -1 | cut -d: -f1)"
lavail="$(grep -n -F -- '- **superpowers 가용 시**' "$FIN" | head -1 | cut -d: -f1)"
if [ -n "$bf" ] && [ -n "$lb1" ]; then
  bfl=$((lb1 + bf - 1))
  if [ -n "$lavail" ] && [ "$lavail" -lt "$bfl" ]; then ok "finishing.md B-1: 판 확인 펜스가 「superpowers 가용 시」 갈래 안에 있다"
  else no "finishing.md B-1: 판 확인 펜스가 「superpowers 가용 시」 갈래 안에 없다 (가용=${lavail:-없음} 펜스=$bfl)"; fi
  run_sp_fence interview "$FIN" "$bfl"
  after="$(after_fence "$FIN" "$bfl")"
  assert_contains "$after" "멈추지 않는다" "finishing.md B-1: 판 확인 결과로는 멈추지 않는다고 적는다"
  assert_contains "$after" "B-2" "finishing.md B-1: 판 확인 뒤 B-2 게이트로 간다"
fi

# ── 3. 손 절차 머리 · 걸음 7 ─────────────────────────────────────────────────
MAN_HEAD="$(section "$CD" '^## 손으로 따르는 절차$' '^1\. \*\*')"
[ -n "$MAN_HEAD" ] && ok "conducting.md: 손 절차 머리를 읽었다" || no "conducting.md: 손 절차 머리가 없다"
mline="$(printf '%s\n' "$MAN_HEAD" | grep -F -- "$STOP" | head -1)"
assert_contains "$mline" "$STOP" "conducting.md 손 절차 머리: superpowers 가 없으면 보일 문장"
assert_contains "$mline" "멈춘다" "conducting.md 손 절차 머리: 그 문장의 줄이 멈춘다고 적는다"
assert_contains "$MAN_HEAD" 'scripts/check_deps.py superpowers --plugin-root' "conducting.md 손 절차 머리: superpowers 판 확인 명령"
S7="$(section "$CD" '^### 7\. 끝$' '^##+ ')"
[ -n "$S7" ] && ok "conducting.md: 걸음 7 을 읽었다" || no "conducting.md: 걸음 7 이 없다"
qline="$(printf '%s\n' "$S7" | grep -F -- "$QG_ABSENT" | head -1)"
assert_contains "$qline" "$QG_ABSENT" "conducting.md 걸음 7: quality-gates 가 없을 때 알릴 문장"
assert_contains "$qline" "진행한다" "conducting.md 걸음 7: 알리고 진행한다"
assert_not_contains "$qline" "멈춘다" "conducting.md 걸음 7: quality-gates 가 없다고 멈추지 않는다"

# ── 4. README Prerequisites ─────────────────────────────────────────────────
PRE="$(section "$README" '^## Prerequisites$' '^## ')"
spl="$(printf '%s\n' "$PRE" | grep -F -- '- **superpowers**' | head -1)"
assert_contains "$spl" "지휘자" "README Prerequisites: superpowers 줄이 지휘자 흐름을 말한다"
assert_contains "$spl" "진입에서 멈춘다" "README Prerequisites: superpowers 가 없으면 지휘자 흐름은 진입에서 멈춘다"
assert_contains "$spl" "다르면 알린다" "README Prerequisites: superpowers 판이 다르면 알린다"
qgl="$(printf '%s\n' "$PRE" | grep -F -- '- **quality-gates**' | head -1)"
assert_contains "$qgl" "$QG_ABSENT" "README Prerequisites: quality-gates 가 없을 때의 문장"

# ── 5. plugin.json 에 dependencies 키가 없다(음) · dependencies.md 에 superpowers 행(양) ──
pj="$(python3 -I -c 'import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
print(d.get("name", ""))
print("has-dependencies" if "dependencies" in d else "no-dependencies")' "$SD/.claude-plugin/plugin.json" 2>&1)"
assert_eq "$(printf '%s\n' "$pj" | sed -n 1p)" "spec-distill" "plugin.json 을 읽었다(이름 spec-distill)"
assert_eq "$(printf '%s\n' "$pj" | sed -n 2p)" "no-dependencies" "plugin.json 에 dependencies 키가 없다 — 없으면 플러그인 전체가 꺼진다"
sprow="$(python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import check_deps
for r in check_deps.read_table(sys.argv[2]):
    if r["name"] == "superpowers":
        print("%s|%s|%s" % (r["strength"], "ok" if check_deps.version_triple(r["min_version"]) else "no-version", r["when_missing"]))' \
  "$ROOT/shared/deps" "$SD/dependencies.md" 2>&1)"
assert_eq "$(printf '%s' "$sprow" | cut -d'|' -f1-2)" "알림|ok" "dependencies.md: superpowers 행이 판과 강도 알림으로 있다(양의 짝)"
assert_contains "$sprow" "진입에서 멈춘다" "dependencies.md: superpowers 행의 없을 때 칸이 지휘자 흐름의 멈춤을 말한다"

finish
