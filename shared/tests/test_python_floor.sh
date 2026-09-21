#!/usr/bin/env bash
# guards: shared/python/**
#
# 출하 Python 바닥의 «집행» 이 살아 있는가. 선언은 여기서 재지 않는다 — 선언만 한 바닥은
# 훅이 읽지 않는다는 것이 이 설계의 출발점이다(설계 Context/Why 3).
#
# 축 A 해석기 행동 · B 배포(물리 사본) · C 배선(hooks.json) · D 두 바닥 · E 훅 자식 ·
# F 도출 규칙의 산출물 기록 · G prerequisite · H uv.lock 핀.
#
# **이 락이 스스로 못 지키는 것** — fixture 로 쓰는 가짜 인터프리터가 「바닥을 만족한다」고
# 거짓말하는 것 자체는 못 잰다. 그것이 이 락의 «측정 수단»이기 때문이다. 대신 축 A 는 같은
# fixture 로 양성(3.99 를 고른다)과 음성(3.9 를 건너뛴다)을 **둘 다** 요구한다 — 한쪽만
# 통과시키는 고장은 없다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1

RESOLVER="shared/python/devbrew-python.sh"

# `--emit-scanned` — 이 락이 **실제로 읽는** 경로. assert.sh 를 source 하기 **전에** 답한다 —
# 헬퍼가 깨져도 커버리지 대조는 답을 받아야 한다.
#
# **여기에 «앞으로 읽을» 경로를 미리 적지 않는다.** 소비자
# (`plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh`)는 글롭을 이 목록과
# 대조하므로, 목록에 소망을 적으면 그 글롭들이 **아무것도 안 재면서 GREEN** 이 된다 — 그 락의
# 머리말이 「선언 ⊃ 실제 → 선택은 되는데 아무것도 안 본다」로 이름 붙인 바로 그 실패다.
# 축을 더하는 Task 가 자기 줄을 **그때** 더한다(위 `# guards:` 글롭도 함께).
SCANNED="shared/python/devbrew-python.sh"
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' "$SCANNED"
  exit 0
fi

. "$ROOT/shared/tests/assert.sh"

# 출하 바닥은 **해석기에서 도출한다** — 숫자를 이 락에 리터럴로 핀하면 바닥이 움직이는 날
# stale-red 가 된다(리포에 전례가 있다). 도출이 비면 아래 대조가 전부 헛돌므로 **증인을
# 먼저 세운다** — 재도출 락은 보간 실패를 스스로 못 잡는다.
FLOOR_MAJOR_VAL="$(sed -n 's/^FLOOR_MAJOR=\([0-9][0-9]*\)$/\1/p' "$RESOLVER" 2>/dev/null | head -1)"
FLOOR_MINOR_VAL="$(sed -n 's/^FLOOR_MINOR=\([0-9][0-9]*\)$/\1/p' "$RESOLVER" 2>/dev/null | head -1)"
case "${FLOOR_MAJOR_VAL:-x}.${FLOOR_MINOR_VAL:-x}" in
  *[!0-9.]*|.*|*.) no "증인: 해석기에서 FLOOR_MAJOR/FLOOR_MINOR 를 못 읽었다 — 축 C2·D·F·G 의 대조는 무의미하다" ;;
  *) ok "증인: 출하 바닥 ${FLOOR_MAJOR_VAL}.${FLOOR_MINOR_VAL} 를 해석기에서 도출했다" ;;
esac

# ── fixture: 가짜 인터프리터 ────────────────────────────────────────────────
# 셸을 **복사하지 않는다** — /bin/sh 사본은 macOS 코드서명 위반으로 SIGKILL(rc 137) 된다
# 〔실측〕. 좁힌 PATH 에는 실제 `/bin` 을 둔다(이 머신엔 /usr/bin/sh 가 없다 — D19).
TMP="$(mktemp -d)"
[ -n "$TMP" ] && [ -d "$TMP" ] || { echo "mktemp -d 실패 — 아무것도 재지 않았다"; exit 1; }
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/floor" "$TMP/sub" "$TMP/plain"

cat > "$TMP/floor/python3.99" <<'FAKE'
#!/bin/sh
# 바닥을 만족한다고 «답하고», 그 밖에는 **건네받은 스크립트를 실제로 실행한다** — 진짜
# 인터프리터가 하는 일이 그것이다. 자기 마커만 찍고 끝내면 argv 전달도 stdin 전달도 재지
# 못하고, A9 의 「사유가 자식 환경으로 간다」는 원리적으로 관측 불가가 된다.
[ "$1" = "-c" ] && { echo "3 99"; exit 0; }
exec "$@"
FAKE
cat > "$TMP/sub/python3.9" <<'FAKE'
#!/bin/sh
[ "$1" = "-c" ] && { echo "3 9"; exit 0; }
echo "EXECED-SUBFLOOR"
exit 0
FAKE
cat > "$TMP/plain/python3" <<'FAKE'
#!/bin/sh
[ "$1" = "-c" ] && { echo "3 9"; exit 0; }
echo "EXECED-PLAIN-PYTHON3"
exit 0
FAKE
chmod +x "$TMP/floor/python3.99" "$TMP/sub/python3.9" "$TMP/plain/python3"
# `python3.12-config` 류가 후보로 새지 않는지 — 실행 가능하고 이름이 맞아도 제외돼야 한다.
# **이 fixture 는 진짜 인터프리터처럼 답해야 한다.** 자기 마커만 찍으면 `probe` 의 `$( )` 가
# 그 출력을 삼켜 shape 검사에서 떨어뜨리므로, 배제 줄을 지워도 마커가 해석기 stdout 에 도달할
# 수 없다 — 단언이 **원리적으로 실패할 수 없는** vacuous 락이 된다〔실측: 배제 줄 제거 전후
# 출력 바이트 동일〕. `-c` 에 만족 버전을 답하게 하면 배제가 없을 때 글롭 순서상 이것이 먼저
# 뽑혀(`python3.12-config` < `python3.99`) 마커가 실제로 나온다.
cat > "$TMP/floor/python3.12-config" <<'FAKE'
#!/bin/sh
[ "$1" = "-c" ] && { echo "3 99"; exit 0; }
echo "CONFIG-SHOULD-NOT-RUN"
exec "$@"
FAKE
chmod +x "$TMP/floor/python3.12-config"

# 바닥과 **정확히** 같은 버전. 리터럴 12 를 쓰지 않고 해석기에서 도출한 값으로 만든다 —
# 이 자리가 없으면 `-ge` → `-gt` 변이가 27/27 GREEN 을 유지하면서 **출하 바닥 자신을**
# 거부한다〔실측〕. 리포에서 가장 중요한 숫자의 등호 경계다.
mkdir -p "$TMP/atfloor"
cat > "$TMP/atfloor/python3.$FLOOR_MINOR_VAL" <<FAKE
#!/bin/sh
[ "\$1" = "-c" ] && { echo "$FLOOR_MAJOR_VAL $FLOOR_MINOR_VAL"; exit 0; }
echo "EXECED-ATFLOOR"
exec "\$@"
FAKE
chmod +x "$TMP/atfloor/python3.$FLOOR_MINOR_VAL"

TARGET="$TMP/target.sh"      # 훅 대역 — exec 됐는지와 stdin 이 온전한지를 함께 증명한다
cat > "$TARGET" <<'T'
#!/bin/sh
# **내장 명령만 쓴다** — A4b 는 coreutils 가 하나도 없는 PATH 로 돈다(`cat` 이 없다).
# `|| [ -n "$_line" ]` 는 장식이 아니다: payload 는 `printf '%s'` 로 와서 **끝에 개행이
# 없고**, 그 가드가 없으면 마지막(=유일한) 줄이 통째로 버려져 A10 이 조용히 RED 다
# 〔/bin/sh · dash · ksh 셋 다 실측〕. 리포의 같은 관용구:
# plugins/spec-distill/tests/test_seed_agents.sh:173
echo "TARGET-RAN"
while IFS= read -r _line || [ -n "$_line" ]; do printf '%s\n' "$_line"; done
T
chmod +x "$TARGET"

PAY='{"event":"probe","canary":"PAYLOAD-INTACT"}'
# 인자는 `env` 에 **그대로** 넘긴다. 환경 할당을 한 문자열로 모아 unquoted 확장하면
# 값에 공백이 있는 순간(예: `DEVBREW_SKIP_HOOKS= a , b`) 쪼개져서 env 가 둘째 조각을
# 명령으로 읽는다 — 그 케이스가 바로 아래 A3 이다.
run_resolver() {   # run_resolver <PATH> [VAR=val …] /bin/sh <해석기> <인자…>
  _p="$1"; shift
  printf '%s' "$PAY" | env PATH="$_p" "$@" 2>/dev/null
}

PATH_FLOOR="$TMP/floor:$TMP/plain:/bin"     # 바닥 만족 후보가 있다
PATH_SUB="$TMP/sub:$TMP/plain:/bin"         # 바닥 미만만 있다
PATH_BARE="$TMP/floor"                      # coreutils 가 **하나도 없다** (A4 용)
PATH_ATFLOOR="$TMP/atfloor:$TMP/plain:/bin" # 바닥과 «정확히» 같은 것만 있다 (A12 용)
R="$ROOT/$RESOLVER"

note "── 축 A: 해석기 행동 ───────────────────────────────────────────────"

# A1 (AC5a) 전역 스위치가 해석보다 먼저다 — 바닥 만족 인터프리터가 있어도 아무것도 안 한다
out="$(run_resolver "$PATH_FLOOR" DEVBREW_QUALITY_GATES_DISABLE=1 /bin/sh "$R" \
        --event SessionStart --plugin quality-gates --hook session-start-advisor "$TARGET")"
assert_eq "$out" "" "A1/AC5a: DEVBREW_QUALITY_GATES_DISABLE=1 이면 stdout 이 비고 훅이 안 돈다"

# A2 (AC5b) 전체 토큰 — 부분 일치는 끄지 않는다
out="$(run_resolver "$PATH_FLOOR" DEVBREW_SKIP_HOOKS=quality-gates:session-start /bin/sh "$R" \
        --event SessionStart --plugin quality-gates --hook session-start-advisor "$TARGET")"
assert_contains "$out" "TARGET-RAN" "A2/AC5b: 부분 일치 'quality-gates:session-start' 는 끄지 않는다"
out="$(run_resolver "$PATH_FLOOR" DEVBREW_SKIP_HOOKS=quality-gates:session-start-advisor /bin/sh "$R" \
        --event SessionStart --plugin quality-gates --hook session-start-advisor "$TARGET")"
assert_eq "$out" "" "A2/AC5b: 전체 토큰 훅명은 끈다"

# A3 (AC5c) 이벤트 별칭 + 공백 제거 + 쉼표 목록
out="$(run_resolver "$PATH_FLOOR" "DEVBREW_SKIP_HOOKS= quality-gates:SessionStart ,other:x" /bin/sh "$R" \
        --event SessionStart --plugin quality-gates --hook session-start-advisor "$TARGET")"
assert_eq "$out" "" "A3/AC5c: 이벤트 별칭 + 앞뒤 공백 + 쉼표 목록이 정본과 같게 판정된다"
# 하위 기능 토큰은 훅 전체를 끄지 않는다 — 정본의 의미를 «넓히지도» 않는다
out="$(run_resolver "$PATH_FLOOR" DEVBREW_SKIP_HOOKS=quality-gates:session-start-advisor:frontmatter-scan /bin/sh "$R" \
        --event SessionStart --plugin quality-gates --hook session-start-advisor "$TARGET")"
assert_contains "$out" "TARGET-RAN" "A3/AC5c: 하위 기능 토큰은 훅 전체를 끄지 않는다(정본과 동치)"

# A4 (AC5 순서 + PATH 불신) — 해석기가 외부 명령에 기대지 않는다는 것을 **행동으로** 잰다.
#    〔실측〕 kill switch 의 변수명 도출을 `tr` 로 쓰면 PATH 에 /usr/bin 이 없을 때
#    `tr: command not found` 로 판정이 **조용히 fail-open** 하고, PATH 분리를 `tr` 로 쓰면
#    글롭 스캔이 통째로 죽는다. 둘 다 텍스트 grep 이 아니라 실행으로 잡는다 — 해석기 본문이
#    그 명령 «이름» 을 주석에서 언급하므로 텍스트 락은 자기 주석에 걸린다.
out="$(printf '%s' "$PAY" | env -i PATH= DEVBREW_SKIP_HOOKS=quality-gates:SessionStart \
        /bin/sh "$R" --event SessionStart --plugin quality-gates \
        --hook session-start-advisor "$TARGET" 2>/dev/null)"
assert_eq "$out" "" "A4a: PATH 가 비어도 kill switch 가 발동한다"
out="$(printf '%s' "$PAY" | env -i PATH="$PATH_BARE" \
        /bin/sh "$R" --event SessionEnd --plugin qg --hook h "$TARGET" 2>/dev/null)"
assert_contains "$out" "TARGET-RAN" "A4b: coreutils 가 하나도 없는 PATH 에서도 글롭 스캔이 python3.99 를 찾는다"

# A5 (AC2 양성 대조) 바닥을 만족하는 python3.99 를 고른다 — 리터럴 열거였다면 «오늘 쓴
#    어떤 목록에도 3.99 가 없으므로» 못 고른다. 이것이 AC2 의 변이(글롭→열거)와 같은 자리다.
out="$(run_resolver "$PATH_FLOOR" /bin/sh "$R" --event SessionStart --plugin qg --hook h "$TARGET")"
assert_contains "$out" "TARGET-RAN" "A5/AC2: PATH 글롭이 python3.99 를 찾아 exec 한다 (양성 대조)"
assert_not_contains "$out" "CONFIG-SHOULD-NOT-RUN" "A5/AC2: python3.12-config 류는 후보가 아니다"

# A12 (바닥의 등호) 바닥과 «정확히» 같은 버전은 만족이다. 이 단언이 없으면 `-ge` → `-gt`
#     변이가 27/27 GREEN 을 유지하면서 출하 바닥 자신을 거부한다〔실측〕.
out="$(run_resolver "$PATH_ATFLOOR" /bin/sh "$R" --event SessionEnd --plugin qg --hook h "$TARGET")"
assert_contains "$out" "TARGET-RAN" \
  "A12: 바닥과 정확히 같은 Python ${FLOOR_MAJOR_VAL}.${FLOOR_MINOR_VAL} 를 만족으로 친다 (등호 경계)"

# A13 (AC5·C2) 판정이 cwd 내용에 좌우되지 않는다. 정본은 순수 문자열 비교다
#     (`kill_switch_active.py` 의 `skip.split(",")`). unquoted 확장은 IFS 분리 **뒤에**
#     pathname expansion 을 타서, cwd 에 우연히 맞는 파일이 있으면 조용히 끈다〔실측〕.
: > "$TMP/qg:h"
out="$(cd "$TMP" && printf '%s' "$PAY" | env PATH="$PATH_FLOOR" DEVBREW_SKIP_HOOKS='qg:*' \
        /bin/sh "$R" --event SessionEnd --plugin qg --hook h "$TARGET" 2>/dev/null)"
assert_contains "$out" "TARGET-RAN" "A13/C2: cwd 에 'qg:h' 가 있어도 'qg:*' 는 끄지 못한다 (글롭 아님)"

# A16 (:73 의 [ -n "$3" ] 가드 — 빈 이벤트는 별칭을 만들지 않는다) --event 없이 부르면
#     EVENT 가 비고, DEVBREW_SKIP_HOOKS 의 `<plugin>:` 꼴 접두어와 매치되면 안 된다. 이
#     규칙을 재는 단언이 지금까지 없었다. (번호는 A15 를 Task 5 가 이미 예약해 A16 으로 띄운다.)
out="$(run_resolver "$PATH_FLOOR" DEVBREW_SKIP_HOOKS=qg: /bin/sh "$R" \
        --plugin qg --hook h "$TARGET")"
assert_contains "$out" "TARGET-RAN" "A16: --event 없이 불러도(빈 이벤트) DEVBREW_SKIP_HOOKS=qg: 가 훅을 끄지 않는다"

# A6 (AC3) 후보도 같은 판정을 받는다 — 바닥 미만 python3.9 는 건너뛴다
out="$(run_resolver "$PATH_SUB" /bin/sh "$R" --event SessionEnd --plugin qg --hook h "$TARGET")"
assert_not_contains "$out" "EXECED-SUBFLOOR" "A6/AC3: 바닥 미만 python3.9 후보를 exec 하지 않는다"
assert_eq "$out" "" "A6/AC3: 건너뛴 뒤 SessionEnd 는 아무것도 찍지 않는다"

# A7 (AC4) python3 로 fallback 하지 않는다
assert_not_contains "$out" "EXECED-PLAIN-PYTHON3" "A7/AC4: 바닥 미만 python3 로 내려가지 않는다"

# A8 (AC7) 안내는 SessionStart 에서만. 문서 «하나» 에 두 키.
out="$(run_resolver "$PATH_SUB" /bin/sh "$R" --event SessionStart --plugin qg --hook h "$TARGET")"
# 바닥 문자열은 하드코딩하지 않는다 — 해석기에서 이미 도출한 FLOOR_MAJOR_VAL/MINOR_VAL 을
# 환경으로 python3 에 건네 그것과 대조한다. "3.12" 를 여기 리터럴로 심으면 바닥이 움직이는
# 날 이 단언만 stale-red 가 된다 — 헤더의 증인 절이 막으려는 것과 같은 실패.
guide_report="$(printf '%s' "$out" | FLOOR_STR="${FLOOR_MAJOR_VAL}.${FLOOR_MINOR_VAL}" python3 -c '
import json, os, sys
raw = sys.stdin.read()
try:
    d = json.loads(raw)          # 문서가 둘이면 여기서 깨진다 (C7)
except ValueError as e:
    print("parse_error: %s" % e); raise SystemExit(0)
ctx = d.get("hookSpecificOutput", {}).get("additionalContext", "")
floor_str = os.environ.get("FLOOR_STR", "")
print("one_doc: yes")
print("has_system_message: %s" % ("yes" if d.get("systemMessage") else "no"))
print("has_additional_context: %s" % ("yes" if ctx else "no"))
print("event_name: %s" % d.get("hookSpecificOutput", {}).get("hookEventName", ""))
print("mentions_found: %s" % ("yes" if "3.9" in ctx else "no"))
print("mentions_floor: %s" % ("yes" if floor_str and floor_str in ctx else "no"))
print("mentions_fix: %s" % ("yes" if "DEVBREW_PYTHON" in ctx or "install" in ctx else "no"))
')"
assert_eq "$(field one_doc "$guide_report")" "yes" "A8/AC7: SessionStart stdout 이 JSON 문서 «하나» 다"
assert_eq "$(field has_system_message "$guide_report")" "yes" "A8/AC7: systemMessage 가 있다 (사람)"
assert_eq "$(field has_additional_context "$guide_report")" "yes" "A8/AC7: additionalContext 가 있다 (모델)"
assert_eq "$(field event_name "$guide_report")" "SessionStart" "A8/AC7: hookEventName 이 SessionStart 다"
assert_eq "$(field mentions_found "$guide_report")" "yes" "A8/AC7: (a) 발견된 최고 버전을 싣는다"
assert_eq "$(field mentions_floor "$guide_report")" "yes" "A8/AC7: (b) 요구 바닥을 싣는다"
assert_eq "$(field mentions_fix "$guide_report")" "yes" "A8/AC7: (c) 고치는 법을 싣는다"
for ev in SessionEnd PostToolUse; do
  out="$(run_resolver "$PATH_SUB" /bin/sh "$R" --event "$ev" --plugin qg --hook h "$TARGET")"
  assert_eq "$out" "" "A8/AC7: $ev 는 해석에 실패해도 stdout 이 비어 있다 (중복 주입 방지)"
done

# A9 (AC8) $DEVBREW_PYTHON — 만족하면 이기고, 불만족이면 stdout 무기록 + 환경으로 사유
out="$(run_resolver "$PATH_SUB" "DEVBREW_PYTHON=$TMP/floor/python3.99" /bin/sh "$R" \
        --event SessionEnd --plugin qg --hook h "$TARGET")"
assert_contains "$out" "TARGET-RAN" "A9/AC8: 바닥을 만족하는 \$DEVBREW_PYTHON 이 이긴다"
REPORT_ENV="$TMP/report_env.sh"
cat > "$REPORT_ENV" <<'R'
#!/bin/sh
# stdin 을 읽지 않는다 — 여기서 재는 것은 «환경» 이고, payload 는 파이프 버퍼에 이미
# 다 쓰여 있다(수십 바이트). 읽지 않는 쪽이 움직이는 부품이 하나 적고, 위 $TARGET 의
# 가드 없는 사본이 이 파일에 남아 복사되는 일도 없다.
echo "ignored=${DEVBREW_PYTHON_IGNORED-}"
R
chmod +x "$REPORT_ENV"
out="$(run_resolver "$PATH_FLOOR" "DEVBREW_PYTHON=$TMP/sub/python3.9" /bin/sh "$R" \
        --event SessionEnd --plugin qg --hook h "$REPORT_ENV")"
assert_grep "$out" '^ignored=.+python3\.9' "A9/AC8: 불만족 \$DEVBREW_PYTHON 사유가 자식 «환경» 으로 간다"
assert_not_grep "$out" '^\{' "A9/AC8: 그 통지를 stdout JSON 으로 찍지 않는다 (문서가 둘이 되면 C7 위반)"

# A10 (AC6) stdin 불가침
out="$(run_resolver "$PATH_FLOOR" /bin/sh "$R" --event SessionEnd --plugin qg --hook h "$TARGET")"
assert_contains "$out" "PAYLOAD-INTACT" "A10/AC6: payload 가 훅에 그대로 간다 (해석기는 stdin 을 읽지 않는다)"

# A14 (AC7·AC8·C7) 안내 JSON 은 $DEVBREW_PYTHON 이 «무엇이든» 유효한 문서 하나다.
#     손으로 조립한 JSON 에 사용자 값을 escape 없이 싣던 자리다 — 경로에 따옴표 하나면
#     훅의 stdout 이 JSON 이 아니게 된다〔실측: Expecting ',' delimiter〕. 그리고 이 조합
#     (DEVBREW_PYTHON 설정 + SessionStart)은 **한 번도 파싱된 적이 없었다** — A8 은
#     DEVBREW_PYTHON 을 안 쓰고, A9 는 SessionEnd 라 안내 블록에 닿지 않는다.
BADPY="$TMP/ba\"d-py"
cp "$TMP/sub/python3.9" "$BADPY"; chmod +x "$BADPY"
out="$(run_resolver "$PATH_SUB" "DEVBREW_PYTHON=$BADPY" /bin/sh "$R" \
        --event SessionStart --plugin qg --hook h "$TARGET")"
bad_report="$(printf '%s' "$out" | python3 -c '
import json, sys
raw = sys.stdin.read()
try:
    d = json.loads(raw)
except ValueError as e:
    print("parsed: no (%s)" % e); raise SystemExit(0)
print("parsed: yes")
print("mentions_ignored: %s" % ("yes" if "DEVBREW_PYTHON" in json.dumps(d, ensure_ascii=False) else "no"))
')"
assert_eq "$(field parsed "$bad_report")" "yes" "A14/C7: 경로에 따옴표가 있어도 stdout 이 유효한 JSON 문서 하나다"
assert_eq "$(field mentions_ignored "$bad_report")" "yes" "A14/AC8: 그 안내가 \$DEVBREW_PYTHON 무시 사실을 싣는다"

# A11 (AC11 의 파일-국소 전제) plugin-audit 의 kill switch 판정기 정규식은
#     `DEVBREW_[A-Z0-9_]*_DISABLE` 이라 **도출형 이름도 꺾쇠 플레이스홀더도 못 본다**
#     〔실측〕. 그래서 머리에 구체 예시 한 줄이 필요하다. 진짜 소비자를 보는 것은 Task 2 의
#     축 B(감사기를 실제로 돌린다)이고, 이 단언은 축 B 가 붙기 전까지의 대역이자
#     「어느 파일이 원인인지」를 바로 가리키는 국소 신호다.
assert_file_grep "$ROOT/$RESOLVER" 'DEVBREW_[A-Z0-9_]+_DISABLE' \
  "A11: 해석기 본문에 plugin-audit 가 읽을 수 있는 구체 kill switch 이름이 있다"

finish
