#!/usr/bin/env bash
# guards: plugins/** shared/**
#
# 통합한 것의 **재분열**을 막는다. 배포 지점이 정본을 가리키는 방법은 셋이다:
# (이 수사는 축 0 이 아래 목록·축 헤더와 대조한다 — 손으로 어긋나게 둘 수 없다.)
#
#   (a) 심볼릭 링크 — 구조에서 도출된 모든 배포 지점이 링크여야 하고, 존재하는
#       대상을 가리켜야 하고, 그 대상이 기대한 정본과 정확히 일치해야 한다.
#       이것이 2026-08-17 실측(설계 §16.1) 이후의 기본 방식이다.
#   (b) copy-of 물리 사본(잔여, 링크를 못 쓰는 경우) — copy-of 줄이 있는 파일은,
#       그 줄이 가리키는 파일과 그 줄만 제외하고 바이트가 같아야 한다.
#   (c) import 형제 사본(축 1c) — import 로만 소비되는 정본은 소비자를 가진 모든
#       배포 디렉토리에 형제 사본을 가져야 한다(∀). (b)는 있는 사본이 같은지만
#       보므로 **빠진 자리**를 못 잡는다. 자세한 이유는 축 1c 주석.
#
# **(a)는 도미넌스(∀) 체크다 — "링크인 것들만" 훑지 않는다.** 첫 판본은
# git ls-files 로 나온 파일 중 [ -L "$f" ] 인 것만 봤다: 링크가 깨져 일반
# 파일이 되면 그 경로가 반복 대상에서 그냥 빠졌다(∃-체크). 2026-08-17 라운드 1
# 코드 리뷰가 실제 심볼릭 링크로 재현해 이 구멍을 실측으로 잡았다 — 자세한
# 기록은 이 태스크 본문에 있다. 지금은 "링크여야 하는 자리"를 참조원에서
# **먼저 도출**하고, 그 집합 전부를 검사한다.
#
# 여기에 형제 설정(codex-killswitch.conf)의 세 사실을 **같은 파일에** 둔다 —
# 배포 지점이 정본을 가리킨다 / 설정이 배포에 실린다 / 설정 부재가 fail-closed 다.
# 셋이 함께 깨질 때 함께 RED 가 되어야 한다(설계 §6.1①). 설정이 실리는지만 보고
# 부재 시 동작을 아무도 안 보면, fail-open 으로 퇴화해도 모든 검사가 GREEN 이다.
#
# 실행 지점은 `/qg` Runtime gate 하나다. 상시 자동 실행이 아니다 —
# C16 이 실행 지점 신설을 금했으므로 이 제약 아래의 최선이다.
#
# **이 락이 스스로 지키지 못하는 것**은 이 파일 자신을 고치는 편집인데, 그 모양이 정확히
# 하나다 — **마지막 `axis_audit` 호출과 EXIT 트랩 등록을 함께 지우는 것.** 그러면 락은
# `rc=0` 으로, `Total:` 줄 없이, 실패 `✗` 를 찍은 채로 끝난다(2026-08-19 실측). 둘 중
# 하나만 지우는 것은 잡히거나(호출) 아무 효과가 없다(트랩). 각 축이 넘기는 기대 최소치도
# 상수로 바꿔치기할 수 있지만 **그 축이 코퍼스-무관 단언을 남긴 채 축소될 때에 한한다.**
# 실측 근거는 아래 축-실행 계측기 주석에 있다. 이 면은 사람이 읽는 diff 리뷰와
# plan Task 16 Step 1 의 verbatim 임베드 대조가 맡는다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

MARKER_RE='^[[:space:]]*(#|//|<!--)[[:space:]]*copy-of:[[:space:]]*([^[:space:]]+)'
HEAD_WINDOW=20   # 마커는 파일 머리 20줄 안에 있어야 한다

# `--emit-scanned` — Task 6 의 양방향 커버리지 검사가 읽는다. 이 락이 **실제로 읽은**
# 경로를 낸다. 선언에서 목록을 도출하면 선언의 자기 반복이라 커버리지 증거가 안 된다.
CORPUS="$(git ls-files -- 'plugins/*' 'shared/*' | grep -vE '/(fixtures|mocks|harness)/')"
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' "$CORPUS"
  exit 0
fi

# ── 축-실행 계측과 감사 (F1) ─────────────────────────────────────────────────
# 〔2026-08-18 fix round 1, F1〕 축 0 은 **주석 텍스트**만 센다. 그래서 어떤 축의
# 구현 본문을 통째로 지우고 헤더 주석만 남기면 세 카운터가 전부 그대로라 GREEN 이
# 된다(실측). 주석 개수는 "그 축이 있다고 **적혀 있다**"만 말할 뿐 "그 축이 **돌았다**"
# 는 말하지 않는다. 그래서 각 축이 **실제로 실행한 단언 수**를 여기서 기록하고,
# 마지막에 헤더 집합과 대조한다. 호출은 **각 축 본문의 맨 끝**에 둔다.
#
# 〔2026-08-19 fix round 2b, H1·H2·H3〕 첫 판본의 계측기는 **통째-본문 삭제** — 그것을
# 쓴 저자가 흔든 유일한 모양 — 하나에만 저항했다. 실측으로 뚫린 네 모양과 그것을 닫은
# 구조는 이렇다. 어느 것도 계측기 위에 계측기를 얹지 않는다.
#  · H3 — `axis_tally 1c` 처럼 **라벨을 인자로** 받으면 그 호출을 축 2 본문으로 옮겨도
#    기록은 `1c` 로 남았다(실측: GREEN + *"축 1c 가 단언 3건을 실제로 실행했다"* 라는
#    거짓 문장이 pass 로 출력). 이제 id 를 인자로 받지 않고 **호출 줄 번호에서 가장
#    가까운 앞 축 헤더**로 도출한다 — 라벨과 호출 자리가 같은 것이 되어, 옮기면 옮겨
#    간 축의 이름이 나온다. 이름을 대는 자가 자기 위치를 고를 수 없다.
#  · H1(a) — `_AXIS_SEEN=$now` **한 줄**을 지우면 모든 축의 기록이 누계가 되어 전부
#    `≥1` 을 만족했다(실측 GREEN). 이제 워터마크를 두지 않고 **절대 카운터를 그대로**
#    적는다. 축별 수는 감사가 이웃한 두 절대값의 차로 낸다 — 지울 리셋 줄이 없다.
#    차 계산 자체를 망가뜨리는 편집(누계로 되돌리기)은 감사의 **합 불변식**이 잡는다:
#    축별 수의 합은 감사 직전까지 실행된 단언 총수와 정확히 같아야 한다.
#  · H1(b) — 감사 블록 자체는 축이 아니라(헤더에 콜론이 없어 `AXIS_IDS` 밖이다) 통째로
#    지워도 아무도 몰랐다(실측 GREEN). 이제 감사가 `finish` 를 품고, 감사가 돌지 않으면
#    **EXIT 트랩이 rc=1 로 죽인다.** `finish` 없이는 실패 개수가 종료 코드로 바뀌지
#    않으므로 — 삭제가 조용해지는 바로 그 이유로 — 트랩이 그 자리를 맡는다.
#  · H2 — `≥1` 은 코퍼스를 안 건드리는 가드 하나로도 충족됐다(축 1c 를 F3 가드만 남기고
#    줄여도 GREEN 이었다). 이제 각 축이 **자기 본문에서 도출한 기대 최소치**를
#    `axis_tally` 에 넘긴다: 코퍼스 축은 자기가 실제로 훑은 항목 수를, 축 0 은 자기 헤더가
#    열거한 도출 자리 수를 낸다. 본문을 가드만 남기고 줄이면 그 수가 0 으로 떨어지거나
#    실행 수가 그 밑으로 내려가 RED 다.
#
# **여기까지도 남는 것(주장 축소).** 2026-08-19 에 실측한 것만 적는다 — 앞 판본의 이 문단은
# 양쪽으로 다 틀렸다(트랩 한 줄을 과소평가하고, 상수 바꿔치기를 과대평가했다).
#  · **한 줄씩 지우는 것은 잡히거나 무해하다.** 마지막 `axis_audit` 호출만 지우면 트랩이
#    `rc=1` 로 죽인다(`Total:` 줄 없이 `✗` 한 줄). 반대로 **트랩 등록 줄만** 지우면 감사가
#    그대로 돌고 `finish` 가 종료 코드를 내므로 **아무 효과가 없다** — 무변이와 똑같은
#    `62 / 62 / 0` 이다. 그 한 줄은 감사가 돌 때는 죽은 코드다.
#  · **둘을 함께 지우면 약해지는 것이 아니라 판정이 사라진다.** 감사 호출과 트랩 등록이
#    같이 없어지면 `rc=0` 이고 `Total:` 줄이 아예 안 나온다. 더 나쁜 실측: **진짜 결함이
#    있어도**(인덱스에 없는 배포 지점 하나를 얹은 상태) `✗` 두 줄을 찍은 채 `rc=0` 으로
#    끝났다. 종료 코드로 판정하는 러너에게 그것은 GREEN 이다 — 침묵하는 성공 보고다.
#    이 **쌍**이 이 락의 유일한 조용한 실패 모양이고, 그래서 여기 이름을 적어 둔다.
#  · **기대 최소치를 상수로 바꾸는 것만으로는 안 된다.** 축 1c 본문을 (F3 분류기 가드와
#    M6 사본 앵커까지) 통째로 지우면 실행 수가 0 이라 어떤 양수 상수도 미달이고, `0` 을
#    선언하는 것 자체가 이름 붙은 실패다(둘 다 실측 RED). 상수가 먹히는 것은 **축소가
#    살아남은 단언을 남길 때뿐**이다 — 축 1c 의 ∀ 프로브 루프만 지우고 위 두 가드를 남기면
#    그것들이 계속 3건을 실행해 `axis_tally 1` 이 통과한다(실측 GREEN). 즉 잔여는
#    "상수로 바꾸면 뚫린다" 가 아니라 **"살아남은 코퍼스-무관 단언 수 이하의 상수"** 하나로
#    좁혀진다. H2 가 겨냥한 바로 그 모양이고, 여기서 완전히 닫히지는 않았다.
# 계측기를 계측하는 계측기를 무한히 쌓지 않기로 했으므로 이 셋은 **여기서 그렇게 말하는
# 것**으로 둔다(머리말의 같은 문장 참조).
_AXIS_TALLY=""
_AXIS_AUDIT_DONE=0
_LOCK_TMP=""
_LOCK_RC=0

lock_tmp_add() {   # 정리 대상 등록. 축마다 trap 을 걸면 나중 것이 앞의 것을 조용히 덮는다.
  _LOCK_TMP="${_LOCK_TMP}$1
"
}

axis_tally() {   # axis_tally <이 축이 자기 본문에서 도출한 기대 최소 단언 수>
  # 축 id 는 **인자가 아니라 호출 자리**에서 온다 〔H3〕. 도출 규칙은 `AXIS_IDS` 와 같다.
  local ln="${BASH_LINENO[0]}" aid=""
  [ -f "${SELF:-}" ] && aid="$(sed -n "1,$((ln-1))p" "$SELF" \
      | sed -nE 's/^# ── 축 ([0-9][a-z]?):.*/\1/p' | tail -1)"
  _AXIS_TALLY="${_AXIS_TALLY}${aid:-?} $((_ASSERT_PASS+_ASSERT_FAIL)) ${1:-0}
"
}

# 감사 — 헤더가 선언한 축 집합과 **실제로 단언을 남긴** 축 집합을 대조하고, 축별 수가
# 그 축이 스스로 도출한 기대 최소치 이상인지 본다. 두 방향 다 본다(선언했는데 안 돌았다 /
# 돌았는데 선언이 없다). 어느 쪽도 주석만 고쳐서는 맞출 수 없다.
# 이 함수가 `finish` 를 품는다 — 이 락의 마지막 실행 줄은 `axis_audit` 다.
axis_audit() {
  local total prev=0 sum=0 line aid abs amin d tallied_ids n_axis_ids
  total=$((_ASSERT_PASS+_ASSERT_FAIL))
  tallied_ids="$(printf '%s' "$_AXIS_TALLY" | awk '{print $1}' | sort -u)"
  assert_eq "$tallied_ids" "$AXIS_IDS" "축-실행: 헤더가 선언한 축 집합과 실제로 단언을 실행한 축 집합이 같다"
  n_axis_ids="$(printf '%s\n' "$AXIS_IDS" | grep -c . || true)"
  if [ "$n_axis_ids" -ge 1 ]; then
    ok "축-실행: 축 헤더에서 ${n_axis_ids}건의 축 id 를 도출 (대조 근거가 살아 있다)"
  else
    no "축-실행: 축 id 가 0건 도출됐다 — 헤더 도출이 깨졌다. 위 집합 대조는 무의미하다"
  fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    set -- $line
    aid="$1"; abs="$2"; amin="$3"
    d=$((abs-prev)); prev="$abs"; sum=$((sum+d))
    if [ "$amin" -lt 1 ] 2>/dev/null; then
      no "축-실행: 축 $aid 가 기대 최소치를 ${amin} 로 냈다 — 이 축은 자기 코퍼스를 한 번도 훑지 못했다(본문이 죽었거나 도출이 깨졌다)"
    elif [ "$d" -ge "$amin" ] 2>/dev/null; then
      ok "축-실행: 축 $aid 가 단언 ${d}건을 실행했다 (자기 본문이 도출한 기대 최소 ${amin}건 이상)"
    else
      no "축-실행: 축 $aid 가 단언 ${d}건만 실행했다 — 자기 본문이 도출한 기대 최소는 ${amin}건이다 (본문이 줄었거나 코퍼스 항목이 조용히 건너뛰어졌다)"
    fi
  done <<TALLY
$_AXIS_TALLY
TALLY
  assert_eq "$sum" "$total" "축-실행: 축별 단언 수의 합이 감사 직전까지 실행된 단언 총수(${total})와 같다 (축 밖 실행도, 누계로 되돌아간 델타도 없다)"
  _AXIS_AUDIT_DONE=1
  finish
}

# 감사가 안 돌면 실패 개수가 종료 코드가 되지 않는다 — 그 자리를 트랩이 맡는다 〔H1(b)〕.
_lock_exit() {
  _LOCK_RC=$?
  local p
  while IFS= read -r p; do
    case "$p" in /*) rm -rf "$p" ;; esac
  done <<TMPS
$_LOCK_TMP
TMPS
  if [ "$_AXIS_AUDIT_DONE" != "1" ]; then
    printf '\n  ✗ 축-실행: 감사(axis_audit)가 실행되지 않은 채 락이 끝났다 — 감사가 지워졌거나 그 앞에서 죽었다\n'
    exit 1
  fi
  exit "$_LOCK_RC"
}
trap _lock_exit EXIT

# ── 축 0: 계약 수 서술이 이 락의 실제 계약 축 수와 맞는가 ─────────────────────
# 〔2026-08-18 Ruling 45〕 축 1c 가 들어오기 전 shared/README.md 는 이 락의 계약 수를
# 실제보다 하나 적게 서술했고, 축이 늘어난 뒤에도 그 문장이 그대로 남았다.
# **존재 검사로는 못 잡는다** — README 에 특정 문구가 살아 있는지만 보는 grep 은
# 서술이 낡아도 똑같이 1 을 낸다. 양성 존재 단언은 정확성을 재지 않는다. 그래서
# 여기서는 **수를 센다**, 그것도 손으로 적지 않고 **세 자리**에서 도출해 서로를 덮는지
# 본다 — 한 자리만 재면 그 자리를 고치는 편집이 나머지를 조용히 낡게 둔다.
#   ① 이 파일 머리말의 개수 문장  ② 머리말 (a)(b)(c) 목록  ③ 축 헤더
#   그리고 ④ shared/README.md 의 서술이 ①②③ 이 합의한 수와 맞는가.
#
# 〔2026-08-18 fix round 1, I1〕 ①이 이번에 들어왔다. 그전까지 머리말의 개수 문장은
# 축 수보다 하나 적은 수를 말한 채 바로 아래에 실제 개수만큼을 나열했고, 축 0 은
# **그 줄을 안 읽었다** — 이 파일이 더한 기계 검사가 못 보는 유일한 개수 리터럴이
# 그 파일 자신의 첫 문장이었다. F1 과 맞물리면 최악이다: 그 문장을 믿고 마지막 계약
# 축의 헤더를 지워 수를 "맞추면" README 까지 함께 "정정"돼, CRIT-1 을 닫은 축이
# 사라진 채 전부 GREEN 이 된다.
#
# **못 보는 것**: 도출은 축 헤더의 번호 관례에 기댄다. 다음 저자가 네 번째 계약을
# `축 4` 로 붙이면 이 도출은 그것을 **계약 축으로는** 안 센다 — 계약 축은 1 번대 문자
# 접미로 붙인다(축 2·3 은 계약이 아니라 형제 설정 축이다).
SELF="shared/tests/$(basename -- "$0")"
AXIS_IDS=""

# 〔2026-08-19 fix round 2b, H2〕 이 축의 기대 최소 단언 수 — **①②③④ 각 도출 자리가
# 실제로 존재하는가**를 코퍼스에서 세어 낸다. 축 0 은 훑는 목록이 아니라 *자리*를 갖는
# 축이라 항목 수가 없다. 첫 시도는 이 수를 축 0 **헤더 주석의 원문자 열거**에서 냈는데,
# 자기 mutation 이 그것을 뚫었다(실측 A4: 본문을 개수 assert 하나로 줄이면서 그 주석의
# 원문자를 함께 지우면 기대치가 1 로 떨어져 GREEN). 산문은 그 산문을 고치는 편집과 함께
# 줄어든다 — 그래서 산문이 아니라 **자리 자체**를 센다. 각 자리는 이 파일과
# `shared/README.md` 의 실제 줄이고, ②③ 이 없어지면 아래 개수 대조가 먼저 RED 다.
# 계산은 `if` **밖**에 둔다: 본문을 줄이는 축소가 이 도출까지 함께 지우면 안 된다.
n_src0=0
[ "$(grep -cE '^# .*방법은 [^ ]+이다:' "$SELF" 2>/dev/null || true)" -ge 1 ] 2>/dev/null \
  && n_src0=$((n_src0+1))                                          # ① 머리말 개수 문장
[ "$(grep -cE '^#   \([a-z]\) ' "$SELF" 2>/dev/null || true)" -ge 1 ] 2>/dev/null \
  && n_src0=$((n_src0+1))                                          # ② 머리말 (a)(b)(c) 목록
[ "$(grep -cE '^# ── 축 [0-9][a-z]?:' "$SELF" 2>/dev/null || true)" -ge 1 ] 2>/dev/null \
  && n_src0=$((n_src0+1))                                          # ③ 축 헤더
[ "$(grep -cE '계약을 검사한다' shared/README.md 2>/dev/null || true)" -ge 1 ] 2>/dev/null \
  && n_src0=$((n_src0+1))                                          # ④ shared/README.md 서술
if [ ! -f "$SELF" ] || [ ! -f "shared/README.md" ]; then
  no "README: 대조 대상이 없다 (self='$SELF') — 아래 계약 수 대조는 무의미하다"
else
  # 축 id 전부(계약 축 1x + 형제 설정 축 2·3 + 이 축 0). 파일 끝의 축-실행 대조가
  # 같은 집합을 쓴다 — 이름을 열거하지 않고 헤더에서 도출한다.
  AXIS_IDS="$(sed -nE 's/^# ── 축 ([0-9][a-z]?):.*/\1/p' "$SELF" | sort -u)"
  n_head="$(grep -cE '^#   \([a-z]\) ' "$SELF" || true)"
  n_axis="$(printf '%s\n' "$AXIS_IDS" | grep -cE '^1[a-z]$' || true)"
  assert_eq "$n_head" "$n_axis" "README: 머리말 계약 목록(${n_head}건)과 축 헤더(${n_axis}건)가 같은 수를 낸다"
  case "$n_axis" in
    1) want='한';    want_intro='하나' ;;
    2) want='두';    want_intro='둘' ;;
    3) want='세';    want_intro='셋' ;;
    4) want='네';    want_intro='넷' ;;
    5) want='다섯';  want_intro='다섯' ;;
    *) want='';      want_intro='' ;;
  esac
  if [ -z "$want" ]; then
    no "README: 축 수 '${n_axis}' 에 대응하는 수사를 모른다 — 도출이 깨졌거나 대응표 밖의 값이다"
  else
    ok "README: 계약 축 ${n_axis}건을 이 파일에서 도출 (열거 없음)"
    # ① 이 파일 머리말의 개수 문장 — **정확히 1건**이어야 한다. 0 건이면 문장이
    #    사라진 것이고(대조가 조용히 vacuous 해진다), 2 건이면 낡은 문장이 남아 있다.
    intro_all="$(sed -nE 's/^# .*방법은 ([^ ]+)이다:.*/\1/p' "$SELF")"
    n_intro="$(printf '%s\n' "$intro_all" | grep -c . || true)"
    assert_eq "$n_intro" "1" "README: 머리말 개수 문장이 정확히 1건 (소실·누적 없음)"
    intro="$(printf '%s\n' "$intro_all" | head -1)"
    assert_eq "${intro:-없음}" "$want_intro" "README: 머리말 개수 문장의 수사가 실제 축 수(${n_axis}건)와 일치한다"
    # ④ shared/README.md — **모든** 매치를 본다. 〔2026-08-18 fix round 1, F7〕
    #    `head -1` 만 보면 낡은 문장이 **뒤에** 덧붙는 누적을 못 본다(실측 E1: 앞에
    #    놓으면 RED, 뒤에 놓으면 GREEN 이었다). Ruling 45 의 전제 자체가 "낡은 산문이
    #    살아남는다" 이므로 편집뿐 아니라 **누적**에도 걸어야 한다.
    said_all="$(sed -nE 's/^`shared\/tests\/test_copy_of_contract\.sh` — ([^ ]+) 계약을 검사한다.*/\1/p' shared/README.md)"
    n_said="$(printf '%s\n' "$said_all" | grep -c . || true)"
    assert_eq "$n_said" "1" "README: shared/README.md 의 계약 수 서술이 정확히 1건 (낡은 문장 누적 없음)"
    said="$(printf '%s\n' "$said_all" | head -1)"
    assert_eq "${said:-없음}" "$want" "README: shared/README.md 의 계약 수 서술이 실제 축 수(${n_axis}건)와 일치한다"
  fi
fi
axis_tally "$n_src0"   # 기대 최소치 도출은 이 축 머리(if 밖)에 있다

# ── 축 1a: 심볼릭 링크 무결성 — 도미넌스(∀) 체크 (기본 방식, 설계 §16.1) ────
# 〔2026-08-19 Ruling 51〕 정본 목록은 **도출한다** — 이름을 적어 두지 않는다. 앞 판본은
# 둘을 손으로 열거했고, 그래서 새 정본이 들어오면 그 배포 지점은 이 축이 **한 번도 안 보는**
# 상태로 착지했다(실측: Task 18 이 `prompt-preamble.md` 링크 3개를 더했을 때 열거는 그대로
# 둘이었고 이 축은 GREEN 이었다). 열거는 공간뿐 아니라 **시간에도** fail-open 이다 — 내일
# 추가될 정본을 오늘 적을 수 없고, 뒤이은 태스크마다 잊을 기회가 하나씩 늘어난다.
#
# 도출 규칙: **`plugins/**` 의 추적된 심볼릭 링크가 실제로 가리키는 `shared/**` 파일 전부.**
# 양쪽 다 git 인덱스(`git ls-files -s` 의 모드 `120000`)에서 온다 — 워킹트리만 보면 인덱스에서
# 사라진 링크를 놓치고, 인덱스만 보면 링크가 깨져도 못 본다. 그래서 인덱스로 **후보를 고르고**
# 워킹트리에서 **해석**한다. 해석 실패는 여기서 조용히 버리지 않는다 — 그 경로는 아래 ∀
# 루프가 `dangling`/`regular-file` 로 잡는다(정본이 도출되기만 하면).
#
# 이 도출이 자기 자신에 대해 fail-open 하지 않게, 도출 결과가 0건이면 아래에서 RED 다.
SYMLINK_CANONICALS="$(git ls-files -s -- 'plugins/*' \
  | awk '$1=="120000" { sub(/^[^\t]*\t/, ""); print }' \
  | while IFS= read -r _link; do
      [ -L "$_link" ] || continue
      _tgt="$(readlink -- "$_link")"
      _abs="$(cd "$(dirname -- "$_link")" 2>/dev/null \
              && cd "$(dirname -- "$_tgt")" 2>/dev/null \
              && printf '%s/%s\n' "$(pwd)" "$(basename -- "$_tgt")")"
      [ -n "$_abs" ] || continue
      _rel="${_abs#"$ROOT"/}"
      # `case ... in shared/*)` 를 쓰지 않는다 — 명령 치환 `$( )` 안에서 bash 3.2 가
      # 패턴의 `)` 를 치환의 끝으로 읽어 이 줄을 통째로 망가뜨린다(실측: 도출이 쓰레기
      # 문자열 둘을 뱉고 "정본 자체가 없다" 로 RED). 접두 제거 비교는 그 함정이 없다.
      [ "$_rel" != "${_rel#shared/}" ] && printf '%s\n' "$_rel"
    done | sort -u)"
n_canon="$(printf '%s\n' "$SYMLINK_CANONICALS" | grep -c . || true)"
if [ "$n_canon" -ge 1 ]; then
  ok "symlink-∀: 정본 ${n_canon}건을 배포 지점의 링크 대상에서 도출 (열거 없음)"
else
  no "symlink-∀: 정본이 0건 도출됐다 — 배포 지점 심볼릭 링크가 인덱스에서 사라졌거나 도출이 깨졌다. 아래 ∀ 루프는 한 번도 돌지 않는다"
fi

# 정본 basename → 참조원에서 도출된 배포 지점 수. 축 2·3 이 자기 코퍼스가 비었는지
# 판정할 때 이 값을 **독립 앵커**로 쓴다 〔2026-08-18 fix round 1, F5〕.
DEP_COUNTS=""
n_ref_detect=""   # 축 2 가 채운다. 여기서 미리 정의해 두는 이유: 축 2 의 본문이 사라져도
                  # 축 3 이 `set -u` 로 죽는 대신 자기 판정을 내고 RED 를 남긴다.
dep_count() {   # dep_count <basename> → 도출 수(있으면), 없으면 rc≠0
  printf '%s' "$DEP_COUNTS" | awk -v b="$1" '$1==b {print $2; f=1} END{ exit !f }'
}

n_expected=0
while IFS= read -r canonical; do
  [ -n "$canonical" ] || continue
  if [ ! -f "$canonical" ]; then
    no "symlink-∀: 정본 $canonical 자체가 없다"
    continue
  fi
  base="$(basename -- "$canonical")"
  esc_base="$(printf '%s' "$base" | sed 's/\./\\./g')"
  # 참조원 도출 — 실제 호출 패턴(scripts/<basename>)을 참조하는 파일. 배포
  # 지점 자기 자신(plugins/*/scripts/<basename>)은 도출 대상에서 제외한다 —
  # 그러지 않으면 배포 지점 자신이 스스로를 참조원으로 세어 도출이 순환한다.
  #
  # 〔2026-08-18 fix round 1, F8〕 코퍼스는 **git 이 추적하는 `plugins/` 전부**다.
  # 앞 판본은 `skills`·`scripts`·`hooks`·`agents`·`commands` 다섯 디렉토리를 손으로
  # 열거했다 — *"열거하지 않는다"* 를 원칙으로 내건 이 파일 안에서 공간(빠뜨린
  # 디렉토리)·시간(내일 생길 디렉토리) 양쪽으로 fail-open 이었다. 오늘 그 다섯 밖에서
  # `scripts/<basename>` 를 참조하는 파일이 8개 있고(`plugins/*/tests/` · `README.md` ·
  # `CHANGELOG.md`), 넓혀도 **도출된 플러그인 집합은 다섯 열거와 같다**(2026-08-18 실측)
  # — 값이 안 변한다는 것을 먼저 재고 넓혔다. 소비자가 테스트뿐인 플러그인은 앞 판본에서
  # ∀ 집합에 조용히 빠졌고, 정본별 가드도 다른 정본이 정상 도출되면 안 터졌다.
  # fixtures/mocks/harness 는 CORPUS 와 같은 이유로 뺀다 — 픽스처가 기대를 만들면 안 된다.
  # `/dev/null` 을 목록 끝에 붙이는 이유: 목록이 비면 `xargs` 가 인자 없는 `grep` 을
  # 실행해 **stdin 을 기다리며 멈춘다**. 절대 매치하지 않는 파일 하나가 그것을 막는다.
  refs="$( { git ls-files -- 'plugins/*' | grep -vE '/(fixtures|mocks|harness)/'; echo /dev/null; } \
            | tr '\n' '\0' \
            | xargs -0 grep -lE "scripts/${esc_base}" 2>/dev/null \
            | grep -vE "^plugins/[^/]+/scripts/${esc_base}\$" || true)"
  expected_plugins="$(printf '%s\n' "$refs" | sed -nE 's#^plugins/([^/]+)/.*#\1#p' | sort -u)"

  # 순환 금지: 정본 자신이 심볼릭 링크이거나 copy-of 마커를 갖지 않는다
  if [ -L "$canonical" ]; then
    no "symlink-∀: 정본 $canonical 자신이 심볼릭 링크다 (순환 위험)"
  elif head -"$HEAD_WINDOW" -- "$canonical" | grep -qE "$MARKER_RE"; then
    no "symlink-∀: 정본 $canonical 자신이 copy-of 마커를 갖는다 (순환)"
  fi

  n_this=0
  while IFS= read -r plugin; do
    [ -n "$plugin" ] || continue
    dep="plugins/$plugin/scripts/$base"
    n_expected=$((n_expected+1))
    n_this=$((n_this+1))
    if [ ! -e "$dep" ] && [ ! -L "$dep" ]; then
      no "symlink-∀: $dep 가 없다 (missing) — $canonical 을 참조하는 $plugin 에 배포 지점이 없다"
      continue
    fi
    if [ ! -L "$dep" ]; then
      no "symlink-∀: $dep 가 심볼릭 링크가 아니라 일반 파일이다 (regular-file — 재분열)"
      continue
    fi
    raw_target="$(readlink -- "$dep")"
    resolved="$(cd "$(dirname -- "$dep")" 2>/dev/null && cd "$(dirname -- "$raw_target")" 2>/dev/null && printf '%s/%s\n' "$(pwd)" "$(basename -- "$raw_target")")"
    if [ -z "$resolved" ] || [ ! -e "$resolved" ]; then
      no "symlink-∀: $dep → '$raw_target' 대상이 존재하지 않는다 (wrong-target: dangling)"
      continue
    fi
    rel="${resolved#"$ROOT"/}"
    if [ "$rel" != "$canonical" ]; then
      no "symlink-∀: $dep → $rel 인데 기대 정본은 $canonical 다 (wrong-target: mismatch)"
      continue
    fi
    ok "symlink-∀: $dep → $rel (링크·대상 존재·정본 일치)"
  done <<PLUGINS
$expected_plugins
PLUGINS

  # 양성(vacuous 아님) — **정본마다** 판정한다. 합산만 하면 한 정본의 도출이 0건이어도
  # 다른 정본의 건강한 수에 가려 이 정본의 배포 지점이 **하나도 검사되지 않은 채**
  # "vacuous 아님"과 GREEN 이 찍힌다(2026-08-17 재검토가 실측으로 확인한 구멍).
  # 이 목록은 자라도록 설계돼 있으므로(위 SYMLINK_CANONICALS 주석), 다음 저자가
  # `scripts/<basename>` 로 **exec 되지 않고 import 되는** 정본을 더하면 정확히
  # 그 상태가 된다 — 참조 도출은 exec 관례 문자열을 찾기 때문이다.
  if [ "$n_this" -ge 1 ]; then
    ok "symlink-∀: $canonical — 배포 지점 ${n_this}건 도출·검사"
  else
    no "symlink-∀: $canonical 의 배포 지점이 **0건 도출**됐다 — 이 정본은 아무것도 검사되지 않았다. 참조 도출(scripts/${base})이 이 정본에 안 맞거나(예: import 로만 소비되는 모듈) 참조원이 사라졌다"
  fi
  # 〔2026-08-19 fix round 2b, M4〕 **반대 방향 도미넌스** — 실재하는 배포 지점이 전부
  # 도출됐는가. 위 ∀ 는 "도출된 자리에 링크가 있는가"만 본다. 도출은 참조원 **파일 수**에
  # 기대므로, 어떤 플러그인의 유일한 참조가 산문 한 줄이면 그 줄을 고쳐 쓰는 편집만으로
  # 그 플러그인이 기대 집합에서 **조용히** 빠진다 — 실측: plugin-audit 은
  # `skills/auditing-plugins/SKILL.md` 한 줄만 기여하고, 그 줄을 바꾸면 심볼릭 링크 ∀ ·
  # conf 축 · fail-closed(보안) 축에서 함께 이탈한다. 그래서 인덱스(git)와 워킹트리
  # **양쪽**에 실재하는 `plugins/*/scripts/<basename>` 를 모아 도출이 그것을 덮는지 묻는다.
  # untrack 은 인덱스에서만 지우므로 워킹트리 쪽이 남아 두 수가 갈라진다.
  actual_plugins="$( { git ls-files -- "plugins/*/scripts/$base";
      for p in plugins/*/scripts/"$base"; do
        { [ -e "$p" ] || [ -L "$p" ]; } && printf '%s\n' "$p"
      done; } 2>/dev/null | sed -nE 's#^plugins/([^/]+)/.*#\1#p' | sort -u)"
  n_actual="$(printf '%s\n' "$actual_plugins" | grep -c . || true)"
  if [ "$n_actual" = "$n_this" ]; then
    ok "symlink-∀: $canonical — 실재하는 배포 지점 ${n_actual}건이 참조원 도출 ${n_this}건과 같다 (도출이 실재를 덮는다)"
  else
    no "symlink-∀: $canonical — 실재하는 배포 지점 ${n_actual}건과 참조원 도출 ${n_this}건이 다르다 — 도출 앵커가 낡았거나(참조 산문이 바뀌었다) 배포 지점이 인덱스에서만 사라졌다"
    printf '      도출: %s\n      실재: %s\n' "$(printf '%s' "$expected_plugins" | tr '\n' ' ')" "$(printf '%s' "$actual_plugins" | tr '\n' ' ')"
  fi

  DEP_COUNTS="${DEP_COUNTS}${base} ${n_this}
"
done <<CANON
$SYMLINK_CANONICALS
CANON

# 전체 합 — 위 정본별 검사의 백스톱. 목록 자체가 비면 정본별 루프가 아예 안 돈다.
if [ "$n_expected" -ge 1 ]; then
  ok "symlink-∀: 파생된 배포 지점 총 ${n_expected}건 검사 (vacuous 아님)"
else
  no "symlink-∀: 파생된 배포 지점이 0건 — 참조 도출이 깨졌거나 정본 도출이 비었다"
fi
axis_tally "$n_expected"

# ── 축 1b: copy-of 물리 사본이 정본과 바이트 동일 (잔여 — 링크를 못 쓰는 경우) ──
# 카나리아(vacuous 방지, 축 1a에 기대지 않는다) — 코퍼스와 무관한 합성 문자열로
# MARKER_RE 자체를 매 실행마다 검사한다. 코퍼스 스캔 결과만으로는 "0건 발견"과
# "정규식이 깨졌다"를 구별할 수 없고, 축 1a의 결과를 빌려 오면 두 독립 코드 경로
# (심볼릭 링크 판정 vs 마커 정규식)를 하나가 맞으면 나머지도 맞다고 가정하는
# 것이라 MARKER_RE 가 리팩터로 조용히 깨져도 아무도 못 잡는다(2026-08-17
# 라운드 1 코드 리뷰 지적). 그래서 축 1b는 **자기 것으로** vacuous 방지를 한다.
# 〔2026-08-18 fix round 1, I2 — 앞 판본은 여기에 *"이 시점엔 물리 copy-of 파일이
# 0건이다"* 라고 적었다. 브리프가 **두 번 철회한** 서술이고(첫 실사용은 Task 17
# Step 4b 이며 그것이 이 태스크보다 앞선다), 실측은 3건이다. 아래 `물리 사본 0건`
# 가지가 **0건은 정상이 아니다** 라고 말하는데 바로 위 주석이 정상이라고 말하면,
# 실행자가 진짜 알람을 보고 위로 스크롤해 기각한다. 그 문장은 삭제했다.〕
# 〔2026-08-19 fix round 2b, H2〕 이 축이 실제로 훑은 코퍼스 항목 수 — 물리 사본 + 구조에서
# 도출한 사본 후보. 축 끝의 `axis_tally` 가 이것을 기대 최소치로 넘긴다. **초기화를 축
# 헤더 직후에 둔다**: 아래 두 루프를 통째로 지우고 카나리아만 남기는 축소(실측 Q4)에서
# 두 값이 0 으로 남아 감사가 "코퍼스를 한 번도 안 훑었다"를 RED 로 내게 하려면, 초기화가
# 지워지는 범위 **밖**에 있어야 한다.
n_copies=0
n_cand=0

if printf '# copy-of: shared/x\n' | grep -qE "$MARKER_RE"; then
  ok "copy-of: MARKER_RE 카나리아 매치 (정규식 자체는 살아있다)"
else
  no "copy-of: MARKER_RE 카나리아가 매치하지 않는다 — 정규식이 깨졌다. 아래 물리 사본 스캔 결과는 무의미하다"
fi

while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$f" ] || continue
  line="$(head -"$HEAD_WINDOW" -- "$f" 2>/dev/null | grep -nE "$MARKER_RE" | head -1)" || true
  [ -n "$line" ] || continue
  n_copies=$((n_copies+1))
  lineno="${line%%:*}"
  # 추출에 `$MARKER_RE` 를 재사용하지 **않는다.** 그 정규식 안의 `|`(주석 문법 세 가지의
  # 교대)가 `s|…|…|` 의 구분자와 충돌해 `RE error: parentheses not balanced` 로 죽는다
  # — 그러면 target 이 빈 문자열이 되고, 아래 `[ ! -f "$target" ]` 가 항상 참이 되어
  # **모든 사본이 "정본이 존재하지 않는다"로 RED** 가 된다. (plan 작성 중 실측으로 잡음.)
  # 매칭은 위 grep 이 이미 했으므로, 여기서는 그룹 없이 접두를 지우고 후행을 자른다.
  # 후행 절단 하나가 `.md` 의 ` -->` 까지 함께 처리한다.
  target="$(printf '%s' "${line#*:}" | sed -E 's/.*copy-of:[[:space:]]*//; s/[[:space:]].*//')"

  # 부수 조건 ①: 가리키는 경로가 존재한다
  if [ ! -f "$target" ]; then
    no "copy-of: $f → '$target' 가 존재하지 않는다"
    continue
  fi
  # 부수 조건 ②: 정본은 shared/ 아래다
  case "$target" in
    shared/*) ok "copy-of: $f → 정본이 shared/ 아래" ;;
    *) no "copy-of: $f → 정본 '$target' 가 shared/ 밖이다 (소유 관계 왜곡)" ;;
  esac
  # 부수 조건 ③: 정본은 copy-of 줄을 갖지 않는다 (순환 금지)
  if head -"$HEAD_WINDOW" -- "$target" | grep -qE "$MARKER_RE"; then
    no "copy-of: 정본 '$target' 자신이 copy-of 를 갖는다 (순환)"
  else
    ok "copy-of: 정본 '$target' 는 copy-of 없음"
  fi
  # 본체: 마커 줄 **하나만** 빼고 바이트 동일. 줄 번호로 지운다.
  # `sed 'Nd' "$f"` — `--` 종결자를 붙이지 않는다: macOS/BSD sed 는 `--`를
  # "파일명 -- 를 열어라"로 해석해 `sed: --: No such file or directory`를
  # stderr 로 낸다(GNU sed 의 옵션-종료 관례와 다르다). 실제 삭제·비교는
  # `--` 유무와 무관하게 맞지만(2026-08-17 실측 — diff 결과 자체는 옳았다),
  # 락 출력에 매 실행 스캔 파일 수만큼 가짜 에러가 섞여 이빨 증명 로그를
  # 오염시킨다. `$f`·`$target` 는 git ls-files 산출물이라 `-`로 시작하지
  # 않으므로 `--` 없이도 안전하다.
  if sed "${lineno}d" "$f" | diff -q - "$target" >/dev/null 2>&1; then
    ok "copy-of: $f ≡ $target (마커 줄 제외 바이트 동일)"
  else
    no "copy-of: $f 가 $target 와 갈라졌다"
    sed "${lineno}d" "$f" | diff - "$target" | head -10
  fi
done <<EOF
$CORPUS
EOF

if [ "$n_copies" -ge 1 ]; then
  ok "copy-of: 물리 사본 ${n_copies}건 스캔"
else
  # B.4 5b 아래(15 → 17 → 16)에서는 Task 17 Step 4b 가 이미 배포 지점마다 사본을 만들었으므로
  # **0건은 정상이 아니다** — Step 4b 미실행 신호다. 이 가지는 그 사실을 알린다.
  no "copy-of: 물리 사본 0건 — B.4 5b 순서라면 Task 17 Step 4b 의 codex_jsonl.py 사본이 있어야 한다"
fi

# 〔2026-08-18 fix round 1, F4〕 위 스캔 코퍼스는 **마커 자신**으로 게이트된다 —
# 마커가 사라지는 방향은 코퍼스 축소로만 보이고, 존재형 가드(`n_copies -ge 1`)는
# 3 → 2 를 그대로 통과한다(실측 D2: 사본 머리에 20줄을 덧붙여 마커를 `HEAD_WINDOW`
# 밖으로 밀면 매치 1 → 0, 코퍼스 3 → 2, GREEN). 그래서 사본 후보를 **마커가 아니라
# 구조에서** 따로 도출해 그 각각이 마커를 갖는지 ∀ 로 묻는다 — 마커를 지우는 편집이
# 스스로 검사 대상에서 빠져나가지 못하게.
#
# 후보 = 배포 트리 안의 **심볼릭 링크가 아닌** 추적 파일 중 basename 이 `shared/` 의
# 배포 대상 정본과 같은 것. `shared/` 쪽에서 빼는 것 셋, 전부 이유가 있다:
#  · `shared/tests/` — 판정 헬퍼·락은 리포에서만 돌고 사본이 없다는 것이
#    `shared/tests/assert.sh` 머리말의 명시 계약이다.
#  · `shared/` **최상위**의 `*.md` — 이 디렉토리 자체를 설명하는 문서다(오늘은
#    `shared/README.md` 하나). 배포되는 payload 는 `shared/<하위>/` 에 산다.
#    〔2026-08-19 fix round 2b, L2〕 앞 판본은 `*.md` 를 **전부** 뺐다. 그러면 사본으로
#    배포되는 마크다운 정본에 후보 규칙이 아예 없어, F4 가 닫으려던 결함(마커가
#    `HEAD_WINDOW` 밖으로 밀려 파일이 스캔에서 조용히 이탈)이 `.md` 에 대해 열린 채 남는다.
#    좁힐 당시엔 잠재 결함이었다 — 그때는 `shared/` 아래에 마크다운 정본이 없었고, 좁힘이
#    `n_sb`·`n_cand` 를 바꾸지 않는 것을 먼저 재고 좁혔다.
#    **지금은 실효 중이다** 〔2026-08-19 Task 18〕: `shared/codex/prompt-preamble.md` 가
#    `shared/` 아래 첫 마크다운 정본으로 들어왔고, 최상위가 아니므로 이 규칙 안으로 들어온다
#    (그 basename 이 `SHARED_BASENAMES` 에 실린다). 사본으로 배포되는 마크다운은 아직 없다 —
#    그 정본은 심볼릭 링크로 배포되고 링크는 아래 후보 루프가 건너뛴다. 이빨은 실측했다:
#    마커 없는 마크다운 사본을 배포 지점에 놓으면 RED, 마커를 붙이면 바이트 비교까지 돌고,
#    본문을 흔들면 다시 RED 다 — 앞 판본의 `*.md` 전량 제외였다면 셋 다 조용히 통과한다.
#    남는 위험은 basename 우연 충돌(`README.md` 류)인데, 그것은 **좁히는 방향**의
#    실패라 거짓 RED 로 시끄럽다.
#  · 빈 파일(`.gitkeep` 등) — 마커를 실을 수 없고 갈라질 내용도 없다.
# 이 세 제외는 **좁히는 방향**이라 빠뜨리면 거짓 RED 로 시끄럽게 드러난다(넓히는
# 방향의 열거와 달리 조용히 fail-open 하지 않는다).
SHARED_BASENAMES="$(git ls-files -- 'shared/*' \
  | grep -vE '^shared/tests/' | grep -vE '^shared/[^/]+\.md$' \
  | while IFS= read -r p; do [ -s "$p" ] && basename -- "$p"; done | sort -u)"
n_sb="$(printf '%s\n' "$SHARED_BASENAMES" | grep -c . || true)"
if [ "$n_sb" -ge 1 ]; then
  ok "copy-of: 배포 대상 정본 basename ${n_sb}건 도출 (후보 판별의 근거가 살아 있다)"
else
  no "copy-of: 배포 대상 정본이 0건 도출됐다 — 아래 사본 후보 판별이 통째로 vacuous 하다"
fi

while IFS= read -r cand; do
  [ -n "$cand" ] || continue
  case "$cand" in plugins/*) ;; *) continue ;; esac
  [ -L "$cand" ] && continue
  [ -f "$cand" ] || continue
  cb="$(basename -- "$cand")"
  printf '%s\n' "$SHARED_BASENAMES" | grep -qxF -- "$cb" || continue
  n_cand=$((n_cand+1))
  if head -"$HEAD_WINDOW" -- "$cand" 2>/dev/null | grep -qE "$MARKER_RE"; then
    ok "copy-of: 후보 $cand 가 머리 ${HEAD_WINDOW}줄 안에 마커를 갖는다 (스캔 대상에 남아 있다)"
  else
    no "copy-of: $cand 는 shared/ 정본과 같은 이름의 일반 파일인데 머리 ${HEAD_WINDOW}줄 안에 copy-of 마커가 없다 — 위 바이트 비교에서 조용히 빠진다"
  fi
done <<EOF
$CORPUS
EOF
if [ "$n_cand" -ge 1 ]; then
  ok "copy-of: 구조에서 도출된 사본 후보 ${n_cand}건 (마커와 무관하게 셌다)"
else
  no "copy-of: 사본 후보가 0건 도출됐다 — 후보 도출이 깨졌다. 위 ∀ 는 한 번도 안 돌았다"
fi
axis_tally "$((n_copies+n_cand))"

# ── 축 1c: import 형제 사본의 ∀ 도미넌스 (설치본 조건) ────────────────────────
# 〔2026-08-17 fix round 2, R2-2 — 축 1a·1b 어느 쪽도 닫지 못하는 결함 클래스〕
#
# **왜 필요한가.** 축 1b 는 **존재하는** 사본이 정본과 같은지만 본다 — ∃ 다
# (`n_copies -ge 1`). 배포 지점 하나에서 사본을 **지우면** 스캔 대상에서 빠질 뿐
# 아무것도 RED 가 되지 않는다(Task 19~21 이후 11사본이므로 둘을 지워도 아홉이
# 남아 GREEN). 축 1a 도 못 잡는다 — 심볼릭 링크 축의 배포 지점 도출은
# `codex_jsonl` 에 대해 **0건**을 낸다(`from codex_jsonl import` 로만 불려
# `scripts/<basename>` 형태의 참조 문자열이 리포에 없다. Task 17 Step 4b 주석 참조).
# 그런데 지워진 그 한 곳이 정확히 CRIT-1 의 결함 모양이다: 설치본에서 sibling
# import 가 풀리지 않아 **그 플러그인의 codex 리뷰어가 100% 죽고 리포 스위트는
# 초록으로 남는다.** 그래서 여기서는 배포 지점 집합을 **도출하고 그 각각에**
# 형제 사본이 있음을 단언한다 — ∃ 가 아니라 ∀ 다.
#
# **도출 규칙**: git 이 추적하는 `plugins/` **전부** 안에서 그 모듈을 import 하는 `.py`
# 소비자가 있는 **디렉토리** 전부. 이름을 열거하지 않는다(열거는 공간·시간 양쪽으로
# fail-open). 파일을 `open()` 으로 읽으므로 심볼릭 링크를 따라가고, qg·sd 의
# `codex_findings_to_yaml.py` 링크가 정본 본문을 통해 소비자로 걸린다.
# 〔2026-08-19 fix round 2b, M7〕 앞 판본은 `plugins/*/scripts/*` · `plugins/*/hooks/*`
# **두 이름의 손열거**였다 — 바로 위 *"이름을 열거하지 않는다"* 20줄 아래에서. 라운드 1 은
# 같은 결함(F8)을 축 1a 에서만 고치고 여기는 그대로 뒀다. 넓혀도 **오늘 도출되는 소비자
# 집합은 그대로 3건**이다(2026-08-19 실측) — 값이 안 변한다는 것을 먼저 재고 넓혔다.
# fixtures/mocks/harness 는 `CORPUS` 와 같은 이유로 뺀다(픽스처가 기대를 만들면 안 된다).
#
# **왜 플러그인 단위가 아니라 디렉토리 단위인가** 〔2026-08-17 fix round 3, R3-3〕:
# 형제 import 는 `sys.path[0]`(= 실행되는 스크립트 자신의 디렉토리)에서 풀린다.
# 소비자가 `plugins/<p>/hooks/` 에 살면 형제 사본도 **거기** 있어야 하고 `scripts/` 에만
# 있으면 설치본에서 ImportError 다. Task 19(`kill_switch_active.py`)의 소비자가 정확히
# `plugins/*/hooks/` 이므로(plan Task 19), 코퍼스를 `scripts/` 로만 두면 그 정본은 이 축이
# **한 번도 안 보는** 상태로 착지한다 — 축 1b 는 ∃ 라 GREEN, 축 1a 는 import-only 모듈에
# 대해 배포 지점 0건, 축 1c 는 애초에 안 봄. CRIT-1 이 다른 모듈에서 그대로 재현된다.
#
# 규칙에 붙는 조건 둘 — 둘 다 실측으로 강제된 것이다:
#  ① **모듈 자신을 코퍼스에서 뺀다.** 사본은 자기 코드 때문에 자기 자신의
#     "소비자" 로 잡힌다. 어떤 플러그인이 사본만 받고 독립 소비자가 없으면,
#     사본을 지웠을 때 그 플러그인이 기대 집합에서 **함께** 사라져 GREEN 이 된다
#     (fail-open). 오늘 세 배포 지점은 전부 독립 소비자를 갖고 있어 이 필터가
#     없어도 결과가 같지만(2026-08-17 실측), 독립 소비자 없이 사본만 받는 배포
#     지점이 하나라도 생기면 그 우연이 깨진다.
#  ② **제외는 셸 필터(`grep -v`)로 한다 — `:(exclude)` pathspec 매직을 쓰지 않는다.**
#     와일드카드가 섞인 exclude pathspec 이 의도보다 훨씬 넓게 걸러냈다
#     (실측, git 2.50.1: `plugins/<p>/scripts/` 20개 중 11개가 사라졌다).
#
# **설치본 대역이 왜 별도인가.** 형제 부재를 **리포 경로에서만** 재면 부족하다 —
# 리포에는 심볼릭 링크가 실재해서 형제를 치워도 정본 옆 사본으로 풀려 PASS 한다
# (codex 교차 계열 리뷰가 실제로 재현: 정본을 일반 파일로 바꾸고 형제를 치운
# 조건에서만 `rc=1` + `ImportError`). 그래서 배포 지점을 `cp -RL` 로 **링크 없는
# 일반 파일 트리**에 펼치고(설치본과 같은 모양, `shared/` 는 그 트리에 없다)
# 거기서 소비자를 실제로 import 해 본다.
# **정본 집합도 도출한다 — 열거하지 않는다** 〔2026-08-17 fix round 3, R3-3〕. 앞 판본은
# 배포 지점은 도출하면서 정본만 `IMPORT_ONLY_CANONICALS="shared/codex/codex_jsonl.py"` 로
# 박아 뒀다 — 바로 위 "이름을 열거하지 않는다(열거는 공간·시간 양쪽으로 fail-open)"
# 주석 30줄 아래에서. 같은 plan 의 후속 태스크가 같은 모양을 두 번 더 만든다(Task 19
# `shared/killswitch/kill_switch_active.py` ×3 · Task 21 `shared/gc/gc_common.py` ×2 —
# 둘 다 이 태스크 **뒤**에 온다). 목록을 안 늘려도 RED 가 안 나므로, 늘리라는 지시가
# 없는 한 그 정본들은 이 축 밖에 남는다.
#
# 규칙: `shared/` 아래 `.py` 중 ① 실행 지점이 없고(import-only) ② 리포 어딘가가
# `from <basename> import` 로 소비하는 것.
#  · `^` 앵커가 **필수**다. `codex_jsonl.py` 는 자기 docstring 안에서 `if __name__ ==
#    "__main__"` 을 **인용**한다("… 없음, 실행 지점 아님"). 앵커 없이 재면 정본이 스스로
#    실행 지점으로 오인돼 집합에서 빠지고, 빈 집합은 아래 `for` 를 통째로 건너뛰어
#    **0 단언 GREEN** 이 된다 — 축이 조용히 사라진다. 그래서 도출 직후 개수를 못박는다.
#  · 소비 여부 grep 에서 **모듈 자신과 그 사본을 뺀다.** 안 빼면 docstring 자기인용만으로
#    자격을 얻는다(위 조건 ①과 같은 함정의 다른 자리).
# 소비 표기를 무는 것은 정규식이 아니라 **파이썬 파서**다 〔2026-08-19 fix round 2a, M5〕.
# 앞 판본은 표기를 여덟 개까지 늘린 ERE 였는데 그래도 여섯을 놓쳤다. 결정적인 것은
# `import json, <mod>`(콤마 목록에서 첫째가 아님 — **이 리포의 자체 스타일**이고 바로
# 아래 프로브 heredoc 도 그렇게 쓴다)와 `from . import <mod>`(표준 상대 형식)이다.
# 목록을 아홉으로 늘리는 것은 같은 결함의 다음 판본일 뿐이라, 표기를 세는 대신 **문법을
# 읽는다**: `ast` 로 파싱해 `Import`/`ImportFrom` 노드가 묶는 최상위 이름을 본다.
# 표기 목록이 사라지므로 새 표기가 조용히 새지 않는다.
#  · **`.py` 만 읽는다** 〔L1〕. 파서에 문법이 하나뿐이고, 아래 설치 프로브도 `.py` 만
#    실행할 수 있다(`spec_from_file_location` 은 비-`.py` 에 `None` 을 돌려준다).
#  · 파일은 `open()` 으로 읽으므로 **심볼릭 링크를 따라간다**(git grep 과 다르다) —
#    링크로 배포된 소비자도 정본 본문을 통해 걸린다.
#  · 파싱이 안 되는 `.py` 는 "소비하지 않는다" 로 떨어진다. 이 프로브가 도는 인터프리터가
#    읽지 못하는 파일은 같은 인터프리터에서 아무것도 import 하지 못한다. 더 새 문법으로
#    쓰인 소비자는 이 축의 사각지대이고, 그것은 여기서 판정하지 않는다.
IMPSCAN="$(mktemp -t copyof-impscan-XXXXXX)" || exit 1
lock_tmp_add "$IMPSCAN"
cat > "$IMPSCAN" <<'IMPEOF'
# argv: <모듈명>. stdin 으로 후보 `.py` 경로(줄 단위), stdout 으로 그 모듈을 import 하는 것.
import ast, sys
mod = sys.argv[1]

def imports(path):
    try:
        with open(path, "rb") as fh:
            tree = ast.parse(fh.read(), filename=path)
    except (OSError, SyntaxError, ValueError):
        return False
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            # `import a.b` 는 최상위 이름 `a` 를 묶는다 — 형제 사본의 이름은 첫 성분이다.
            if any(a.name.split(".")[0] == mod for a in node.names):
                return True
        elif isinstance(node, ast.ImportFrom):
            # `from <mod> import x` · `from .<mod> import x` · `from <mod>.sub import x`
            if node.module is not None and node.module.split(".")[0] == mod:
                return True
            # `from . import <mod>` — 모듈명이 names 쪽에 온다
            if node.level and node.module is None and any(a.name == mod for a in node.names):
                return True
    return False

for line in sys.stdin.read().splitlines():
    if line and imports(line):
        sys.stdout.write(line + "\n")
IMPEOF
impscan() {   # impscan <모듈명> — stdin: 후보 `.py` 경로 / stdout: 그 모듈을 import 하는 것
  python3 "$IMPSCAN" "$1"
}

# 분류기 **앞**의 집합 — `shared/*.py` 중 리포의 추적되는 `.py` 어딘가가 import 로
# 소비하는 것 전부.
CONSUMED_PY="$(git ls-files -- 'shared/*.py' \
  | while IFS= read -r cf; do
      cm="$(basename "$cf" .py)"
      git ls-files -- '*.py' | grep -v "/${cm}\.py\$" \
        | impscan "$cm" | grep -q . && printf '%s\n' "$cf"
    done)"
# 분류기 **뒤**의 집합 — 위에서 실행 지점(`^if __name__`)이 있는 것을 뺀다.
IMPORT_ONLY_CANONICALS="$(printf '%s\n' "$CONSUMED_PY" \
  | while IFS= read -r cf; do
      [ -n "$cf" ] || continue
      grep -qE '^if __name__ == "__main__"' -- "$cf" && continue
      printf '%s\n' "$cf"
    done)"

# 〔2026-08-18 fix round 1, F3〕 정본 집합 가드가 **합계 전용**(`n_canon -ge 1`)이면,
# 정본이 여럿일 때 하나가 분류기에 떨어져 나가도 남은 수에 가려 GREEN 이다 — 그 정본의
# ∀ 계약이 조용히 소멸한다(오늘 안전한 이유는 n_canon 이 우연히 1 이라서일 뿐이고,
# 후속 태스크가 이 수를 셋으로 만든다). 축 1a 는 같은 모양에 **정본별** 가드를 갖는데
# 축 1c 는 그것도 구조 가드도 없었다. 그래서 형제 락 `test_codex_copies_agree.sh` 의
# `listed == burned` 와 같은 모양으로 **분류기 앞뒤 두 집합을 대조**한다. 떨어진 것이
# 있으면 이름을 찍고 RED 다 — 배포 소비자가 import 하는 모듈은 실행 지점이 있든 없든
# 설치본에 형제가 필요하다(보안 모듈이 컬럼 0 에 스모크 테스트를 얻는 것은 흔하다).
while IFS= read -r cf; do
  [ -n "$cf" ] || continue
  printf '%s\n' "$IMPORT_ONLY_CANONICALS" | grep -qxF -- "$cf" && continue
  no "형제-∀ 도출: $cf 는 import 로 소비되는데 실행 지점(^if __name__)이 있다는 이유로 축 1c 밖으로 떨어졌다 — 이 정본의 형제 ∀ 계약이 조용히 소멸한다"
done <<EOF
$CONSUMED_PY
EOF
n_consumed="$(printf '%s\n' "$CONSUMED_PY" | grep -c . || true)"
n_canon="$(printf '%s\n' "$IMPORT_ONLY_CANONICALS" | grep -c . || true)"
assert_eq "$n_canon" "$n_consumed" "형제-∀ 도출: import 로 소비되는 shared 모듈 ${n_consumed}건이 전부 축 1c 집합에 남았다 (분류기가 아무것도 떨어뜨리지 않았다)"
if [ "$n_canon" -ge 1 ]; then
  ok "형제-∀ 도출: import-only 정본 ${n_canon}건 (이름 열거 없음)"
else
  no "형제-∀ 도출: import-only 정본이 0건 — 도출 규칙이 깨졌다. 아래 ∀ 는 한 번도 안 돈다"
fi

# 〔2026-08-19 fix round 2b, M6〕 위 `listed == burned` 는 **함께 줄어드는 두 집합**을
# 비교한다: `IMPORT_ONLY_CANONICALS` 가 `CONSUMED_PY` **로부터** 도출되므로, 어떤 정본이
# 탐지 가능한 소비자를 전부 잃으면 양쪽에서 함께 빠지고 등식은 그대로 성립한다. F3 는
# "분류기가 떨어뜨린다"만 닫았고 "1단계가 애초에 안 만든다"는 안 닫았다 — 오늘은
# `n_canon=1` 이라 `≥1` 가드가 가리지만, 이 파일이 예고한 Task 19·21 이후의 `n_canon=3`
# 에서 하나를 잃으면 조용하다. 그래서 소비자 스캔과 **무관한 자리**에 세 번째 앵커를 둔다:
# **배포 트리에 형제 사본이 실재하는** 정본. 사본이 있다는 것은 누군가 이 모듈을 형제로
# 배포했다는 뜻이고, 그렇다면 그 정본은 이 축의 ∀ 대상이어야 한다. 사본은 소비자 목록이
# 비어도 사라지지 않는다. 심볼릭 링크로 배포되는 정본은 형제 **사본**이 아니라서 여기
# 걸리지 않는다 — 그쪽 계약은 축 1a 가 진다.
PLUGIN_PY="$(git ls-files -- 'plugins/*' | grep -E '\.py$' || true)"
while IFS= read -r sp; do
  [ -n "$sp" ] || continue
  sb="$(basename -- "$sp")"
  n_sib=0
  while IFS= read -r pp; do
    [ -n "$pp" ] || continue
    [ "$(basename -- "$pp")" = "$sb" ] || continue
    [ -L "$pp" ] && continue
    [ -f "$pp" ] || continue
    n_sib=$((n_sib+1))
  done <<PLGPY
$PLUGIN_PY
PLGPY
  [ "$n_sib" -ge 1 ] || continue
  if printf '%s\n' "$IMPORT_ONLY_CANONICALS" | grep -qxF -- "$sp"; then
    ok "형제-∀ 도출: $sp 는 배포 트리에 형제 사본 ${n_sib}건이 실재하고 축 1c 집합에 남아 있다"
  else
    no "형제-∀ 도출: $sp 는 배포 트리에 형제 사본 ${n_sib}건이 실재하는데 축 1c 집합에 없다 — 소비자 탐지가 이 정본을 통째로 잃었다(두 집합이 함께 줄어 위 등식은 성립한다)"
  fi
done <<SHPY
$(git ls-files -- 'shared/*.py')
SHPY

# 〔2026-08-18 fix round 1, F2〕 **형제 기대 위치를 소비자가 사는 곳이 아니라
# 그 모듈이 실제로 풀리는 곳에서 도출한다.** 앞 판본은 소비자 자신의 디렉토리를
# 요구했고 근거를 *"scripts/ 에만 있으면 설치본에서 ImportError 다"* 로 적었는데,
# 그 전제는 `sys.path.insert` 로 형제 디렉토리를 얹는 소비자에게 **거짓**이다 —
# 이 리포는 이미 그 패턴을 양방향으로 배포 중이고(예: `scripts/` 의 소비자가 `hooks/` 를
# 얹는다), 후속 태스크는 그 반대 방향(사본은 `scripts/`, 소비자는 `hooks/`)을 열두 곳에
# 만든다. 그대로 두면 **정상 배포에 열세 건의 거짓 RED** 가 나고, 그 압력이 축을
# 약화시킨다 — 가장 싼 약화가 코퍼스를 되돌리는 것이고 그게 CRIT-1 그 자체다.
#
# **표기를 정적으로 해석하지 않는다.** 얹는 자리는 `Path(__file__).resolve().parents[1]
# / "scripts"` · `os.path.dirname(os.path.abspath(__file__))` · 미리 만든 변수 등 형태가
# 제각각이라, 파서를 쓰면 모르는 형태마다 조용히 fail-open 한다. 대신 소비자를 **실제로
# 실행**한다 — 아래 설치본 대역 프로브가 이미 같은 파일을 실행하므로 실행 위험은 새로
# 늘지 않는다.
#
# 〔2026-08-19 fix round 2a, M3〕 실행해서 **무엇을 재는가**가 바뀌었다. 앞 판본은
# `sys.path` **델타**를 쟀다 — 델타는 "어딘가에 얹혔다"는 **흔적**이라 얹은 쪽이 치우면
# 지워진다. 평범한 네 모양이 전부 빈 델타를 낸다: `insert` 후 `finally: pop` ·
# contextmanager · `if p not in sys.path` · `PYTHONPATH` 선존재. 그러면 판정이 조용히
# "아무것도 안 얹는다" 로 떨어져 소비자 자신의 디렉토리를 요구하고, 형제를 다른 디렉토리에
# 두는 **정상 배포에 거짓 RED** 가 난다(실측: 표준 위생 관용구 하나로 2건 — F2 가 고쳤다는
# 결함이 그대로 돌아왔다). 그래서 흔적이 아니라 **결과**를 읽는다: import 가 끝난 뒤
# `sys.modules[<mod>].__file__` 은 그 모듈이 **실제로 어디서 풀렸는지**를 말한다.
# pop·재삽입·표기·`PYTHONPATH` 어느 것에도 지워지지 않고, 형제 사본이 있어야 할 디렉토리는
# 그 파일의 디렉토리 그 자체다. 끝까지 안 풀리면(지연 import 등) 소비자 자신의 디렉토리로
# 떨어진다 — 지연 import 도 호출 시점의 `sys.path[0]` 에서 풀리기 때문이다.
#  · `python3 <소비자>` 로 직접 실행할 때와 같은 `sys.path[0]`(= 소비자 자신의 디렉토리)를
#    준다. 앞 판본은 프로브 자신의 임시 디렉토리를 `sys.path[0]` 에 남겨 뒀는데, 그것은
#    설치본에서 일어나는 일이 아니다.
#  · `PYTHONPATH` 를 비우고 실행한다 — 판정이 실행자의 환경에 의존하면 안 된다.
#  · 〔M1/M2〕 판정은 stdout 이 아니라 **결과 파일**로만 나간다. 앞 판본은 소비자 출력과
#    프로브 출력을 합류시킨 스트림의 **부분문자열**로 판정했다: 소비자가 스스로 `STATUS:`
#    / `PATH:` 를 찍으면 락의 기대 위치에 **주입**됐고(실측), 성공 토큰을 담은 traceback
#    한 줄이 설치본 `ImportError` 를 ✓ 로 만들었다(실측). 소비자는 결과 파일 경로를
#    모르고, 설치본 대역의 성공은 **종료 코드**와 그 파일 둘 다로만 신호한다.
SIMPROBE="$(mktemp -t copyof-probe-XXXXXX)" || exit 1
PROBEOUT="$(mktemp -t copyof-probeout-XXXXXX)" || exit 1
PROBEERR="$(mktemp -t copyof-probeerr-XXXXXX)" || exit 1
lock_tmp_add "$SIMPROBE"; lock_tmp_add "$PROBEOUT"; lock_tmp_add "$PROBEERR"
cat > "$SIMPROBE" <<'PYEOF'
# argv: <mode> <소비자 파일> <모듈명> <결과 파일> <트리 루트>
#   import  — 링크 없는 일반 파일 트리에서 소비자를 실제로 실행한다(설치본 대역).
#             실패는 traceback + rc≠0 으로 나간다.
#   resolve — 소비자를 실행하고, 예외로 죽어도 계속 간다.
# 두 모드 모두 **그 모듈이 실제로 풀린 파일**을 결과 파일에 한 줄로 적는다:
#   MODFILE:<트리 루트 기준 상대경로> · OUTSIDE:<절대경로> · NOMOD:<상태>
import importlib.util, os, sys
mode, target, mod, out, root = sys.argv[1:6]
# `python3 <소비자>` 와 같은 sys.path[0]. 프로브 자신의 디렉토리는 경로에서 뺀다.
sys.path[0:1] = [os.path.dirname(os.path.abspath(target))]

def run():
    spec = importlib.util.spec_from_file_location("dep_probe", target)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)      # 여기서 `from <mod> import ...` 가 실제로 돈다

def rel_to(root, path):
    # 풀린 경로 자체는 realpath 하지 않는다 — 링크로 배포된 형제 사본은 **링크 쪽**
    # 경로가 배포 자리다. 루트만 양쪽(abspath·realpath)으로 재서 /var → /private/var
    # 같은 마운트 표기 차이를 흡수한다.
    path = os.path.abspath(path)
    for r in (os.path.abspath(root), os.path.realpath(root)):
        if path.startswith(r + os.sep):
            return path[len(r) + 1:]
    return None

status = "OK"
if mode == "import":
    run()                            # 실패하면 traceback 이 stderr 로 나가고 rc≠0 이다
else:
    try:
        run()
    except BaseException as exc:     # import 뒤에 죽어도 sys.modules 에는 남는다
        status = "EXC:%s" % type(exc).__name__

m = sys.modules.get(mod)
where = getattr(m, "__file__", None) if m is not None else None
if where is None:
    line = "NOMOD:" + status
else:
    rel = rel_to(root, where)
    line = ("MODFILE:" + rel) if rel is not None else ("OUTSIDE:" + os.path.abspath(where))
with open(out, "w", encoding="utf-8") as fh:   # 소비자가 경로를 모르는 채널
    fh.write(line + "\n")
PYEOF

CONSUMER_DIRS=""
dirs_of() {  # dirs_of <소비자> → 그 소비자가 형제를 푸는 디렉토리들
  printf '%s' "$CONSUMER_DIRS" | awk -v c="$1" '$1==c {print $2}'
}

# 〔2026-08-19 fix round 2b, H2〕 이 축이 실제로 훑은 소비자 총수. 축 끝의 `axis_tally` 가
# 이것을 기대 최소치로 넘긴다. 초기화가 아래 루프 **밖**에 있어야, 루프를 통째로 지우고
# F3 가드만 남기는 축소(실측 Q3)에서 0 으로 남아 RED 가 된다.
n_cons_all=0
for canon in $IMPORT_ONLY_CANONICALS; do
  mod="$(basename "$canon" .py)"
  if [ ! -f "$canon" ]; then no "형제-∀: 정본 $canon 이 없다"; continue; fi
  # 소비자 도출 — `.py` 만 본다 〔L1〕. 읽기는 `open()` 이라 심볼릭 링크를 따라가므로
  # (git grep 과 달리) 링크로 배포된 소비자도 정본 본문을 통해 걸린다. 모듈 자신과
  # 그 사본은 뺀다(자기 소비 방지).
  consumers="$(git ls-files -- 'plugins/*' | grep -vE '/(fixtures|mocks|harness)/' \
    | grep -E '\.py$' | grep -v "/${mod}\.py\$" | impscan "$mod")"
  n_cons="$(printf '%s\n' "$consumers" | grep -c . || true)"
  n_cons_all=$((n_cons_all+n_cons))

  # positive(도출이 살아 있는가): 0건이면 아래 ∀ 가 통째로 vacuous 다.
  if [ "$n_cons" -ge 1 ]; then
    ok "형제-∀: ${mod} 를 import 하는 배포 소비자 ${n_cons}건 도출 (vacuous 아님)"
  else
    no "형제-∀: ${mod} 소비자가 0건 도출됐다 — 도출 규칙이 깨졌다. 아래 ∀ 는 무의미하다"
  fi

  CONSUMER_DIRS=""
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    own="$(printf '%s' "$c" | sed -E 's#/[^/]+$##')"
    : > "$PROBEOUT"
    env -u PYTHONPATH PYTHONDONTWRITEBYTECODE=1 python3 "$SIMPROBE" resolve "$ROOT/$c" "$mod" "$PROBEOUT" "$ROOT" >/dev/null 2>&1
    pfile="$(sed -n 's|^MODFILE:||p' "$PROBEOUT" | head -1)"
    pout="$(sed -n 's|^OUTSIDE:||p' "$PROBEOUT" | head -1)"
    pstatus="$(sed -n 's|^NOMOD:||p' "$PROBEOUT" | head -1)"
    if [ -n "$pfile" ]; then
      case "$pfile" in
        plugins/*/*)
          cdir_e="${pfile%/*}"   # 실제로 풀린 파일의 디렉토리 = 형제가 있어야 할 자리
          ;;
        *)
          no "형제-∀: $c 가 ${mod} 를 플러그인 트리 밖($pfile)에서 풀었다 — 설치본에는 그 경로가 없다"
          continue
          ;;
      esac
    elif [ -n "$pout" ]; then
      no "형제-∀: $c 가 ${mod} 를 리포 밖($pout)에서 풀었다 — 설치본에는 그 경로가 없다"
      continue
    elif [ "$pstatus" = "OK" ]; then
      cdir_e="$own"   # 실행이 끝나도록 안 풀렸다(지연 import 등) → 소비자 자신의 디렉토리
    elif [ -n "$pstatus" ]; then
      no "형제-∀: $c 가 ${mod} 를 풀지 못한 채 예외로 죽었다($pstatus) — 설치본에서 ImportError 이거나 그 앞에서 죽었다"
      continue
    else
      no "형제-∀: $c 의 해석 프로브가 결과를 내지 않았다 — 기대 위치를 알 수 없다 (python3 부재/프로브 파손)"
      continue
    fi

    CONSUMER_DIRS="${CONSUMER_DIRS}${c} ${cdir_e}
"
    if [ ! -f "$cdir_e/${mod}.py" ]; then
      no "형제-∀: $c 가 ${mod} 를 푸는 자리($cdir_e)에 ${mod}.py 형제 사본이 없다 — 설치본에서 ImportError (CRIT-1 결함 모양)"
    elif git ls-files --error-unmatch -- "$cdir_e/${mod}.py" >/dev/null 2>&1; then
      ok "형제-∀: $c → $cdir_e/${mod}.py (실제로 풀린 자리에 형제 사본이 있고 git 에 실려 있다)"
    else
      # 〔F4/H1〕 사본을 untrack 하면 디스크엔 남아 존재 검사를 통과하지만 **설치본에는
      # 안 실린다** — 스캔 코퍼스(git ls-files)에서만 조용히 사라진다. 존재와 배포는 다르다.
      no "형제-∀: $cdir_e/${mod}.py 가 git 에 추적되지 않는다 — 디스크엔 있어도 설치본에 안 실린다"
    fi
  done <<EOF
$consumers
EOF

  SIM="$(mktemp -d -t copyof-install-XXXXXX)" || exit 1
  lock_tmp_add "$SIM"
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    cdir="$(printf '%s' "$c" | sed -E 's#/[^/]+$##')"
    # 소비자 자신의 디렉토리 **와** 그 소비자가 sys.path 에 얹는 디렉토리를 함께 편다.
    # 앞 판본은 소비자 디렉토리만 폈다 — 형제 디렉토리를 얹는 소비자에게는 그 디렉토리가
    # 트리에 아예 없어 **정상 배포가 통째로 ImportError** 였다 〔F2〕.
    while IFS= read -r sd; do
      [ -n "$sd" ] || continue
      d="$SIM/$sd"
      [ -d "$d" ] || { mkdir -p "$d"; cp -RL "$sd/." "$d/" 2>/dev/null; }
    done <<TREE
$cdir
$(dirs_of "$c")
TREE
    # 〔M1〕 성공은 **종료 코드**로만 신호하고, 그 위에 "${mod} 가 이 트리 안에서 풀렸다"를
    # 결과 파일로 확인한다. 소비자 출력은 어느 쪽에도 섞이지 않는다.
    : > "$PROBEOUT"; : > "$PROBEERR"
    if env -u PYTHONPATH PYTHONDONTWRITEBYTECODE=1 python3 "$SIMPROBE" import "$SIM/$c" "$mod" "$PROBEOUT" "$SIM" >/dev/null 2>"$PROBEERR" \
       && grep -q '^MODFILE:' "$PROBEOUT"; then
      ok "형제-∀(설치본 대역): $c 가 링크 없는 일반 파일 트리에서 ${mod} 를 import 한다"
    else
      det="$(tail -1 "$PROBEERR")"
      [ -n "$det" ] || det="$(cat "$PROBEOUT")"
      no "형제-∀(설치본 대역): $c 가 ${mod} 를 import 못 한다 — ${det:-(진단 없음)}"
    fi
  done <<EOF
$consumers
EOF
  rm -rf "$SIM"
done
rm -f "$SIMPROBE" "$IMPSCAN" "$PROBEOUT" "$PROBEERR"
axis_tally "$n_cons_all"

# ── 축 2: 형제 설정이 배포에 실린다 ───────────────────────────────────────
# 〔2026-08-18 fix round 1, F5〕 이 축과 축 3 만 vacuity 가드가 없었다. 아래
# `assert_eq "$n_conf" "$n_detect"` 는 **`0 == 0` 에 통과**한다 — conf 와 detect 사본을
# 짝으로 untrack 하면(또는 두 코퍼스가 함께 비면) 한 플러그인이 fail-closed 검사에서
# 조용히 이탈하고 락은 완전 초록이다(실측 N6: `Total: 5 | Pass: 5 | Fail: 0`).
# 축 1a 는 백스톱이 되지 못한다 — 그쪽은 인덱스가 아니라 **워킹트리**에서 존재를 보므로
# untrack 된 파일도 통과한다. 그래서 **독립 앵커**를 쓴다: 축 1a 가 참조원(SKILL.md·
# 호출자·문서)에서 도출한 배포 지점 수. 참조원은 이 두 코퍼스와 다른 자리에 있어
# conf/detect 를 지우는 편집이 기대치를 함께 줄이지 못한다.
n_conf=0
while IFS= read -r c; do
  [ -n "$c" ] || continue
  n_conf=$((n_conf+1))
  assert_grep "$(cat "$c")" '^CODEX_KILL_SWITCH_VAR=DEVBREW_[A-Z_]+$' "conf: $c 가 변수명을 선언한다"
done <<EOF
$(git ls-files -- 'plugins/*/scripts/codex-killswitch.conf')
EOF
# detect_codex.sh 사본이 있는 만큼 conf 도 있어야 한다 — 개수를 열거하지 않고 **도출**한다.
n_detect="$(git ls-files -- 'plugins/*/scripts/detect_codex.sh' | grep -c . || true)"
assert_eq "$n_conf" "$n_detect" "conf: detect_codex.sh 사본 수(${n_detect})만큼 conf 가 git 에 있다"
if n_ref_detect="$(dep_count detect_codex.sh)"; then
  assert_eq "$n_detect" "$n_ref_detect" "conf: git 에 실린 detect_codex.sh 사본 수(${n_detect})가 축 1a 의 참조원 도출(${n_ref_detect}건)과 같다 (코퍼스가 조용히 줄지 않았다)"
else
  no "conf: 축 1a 가 detect_codex.sh 의 배포 지점 수를 내지 않았다 — 아래 개수 대조의 앵커가 없다"
  n_ref_detect=""
fi

# 〔2026-08-19 fix round 2b, M4〕 참조원 앵커는 **참조 파일 수**에 기대므로, 어떤
# 플러그인의 유일한 참조가 산문 한 줄이면 그 줄을 고쳐 쓰는 편집이 앵커를 함께 줄인다
# (실측: plugin-audit 은 `skills/auditing-plugins/SKILL.md` 한 줄만 기여한다). 그 상태에서
# conf·detect 를 짝으로 untrack 하면 세 수가 **함께** 줄어 위 등식이 전부 성립한다.
# 그래서 참조원과 무관한 두 번째 앵커를 둔다: **워킹트리 실재 수.** `git rm --cached` 는
# 인덱스에서만 지우고 디스크에는 남기므로 두 수가 갈라진다.
n_detect_disk=0
for p in plugins/*/scripts/detect_codex.sh; do
  { [ -e "$p" ] || [ -L "$p" ]; } && n_detect_disk=$((n_detect_disk+1))
done
assert_eq "$n_detect" "$n_detect_disk" "conf: git 에 실린 detect_codex.sh 사본 수(${n_detect})가 워킹트리 실재 수(${n_detect_disk})와 같다 (untrack 으로 인덱스에서만 조용히 빠지지 않았다)"
n_conf_disk=0
for p in plugins/*/scripts/codex-killswitch.conf; do
  { [ -e "$p" ] || [ -L "$p" ]; } && n_conf_disk=$((n_conf_disk+1))
done
assert_eq "$n_conf" "$n_conf_disk" "conf: git 에 실린 conf 수(${n_conf})가 워킹트리 실재 수(${n_conf_disk})와 같다 (untrack 으로 인덱스에서만 조용히 빠지지 않았다)"
axis_tally "$n_conf"

# ── 축 3: 설정 부재 시 fail-closed ────────────────────────────────────────
# kill switch 는 보안 컨트롤이다(CLAUDE.md:48). 설정을 못 읽었을 때 변수명이 빈 값으로
# 해석돼 스위치가 조용히 무반응이 되면, 사용자는 껐다고 **믿게만** 된다.
# 〔F5〕 이 루프는 카운터조차 없었다 — 코퍼스가 비면 **단언 0개로 통과**했다(실측 N7:
# `Total: 1 | Pass: 1 | Fail: 0`). 보안 컨트롤 축이 조용히 사라지는 모양이다.
# 그래서 실제로 태운 횟수를 세고 축 1a 의 도출과 대조한다.
TMPC="$(mktemp -d -t copyof-failclosed-XXXXXX)" || exit 1
lock_tmp_add "$TMPC"   # 축마다 `trap ... EXIT` 를 걸면 나중 것이 앞의 것을 조용히 덮는다
n_fc=0
while IFS= read -r d; do
  [ -n "$d" ] || continue
  n_fc=$((n_fc+1))
  # 원본을 건드리지 않는다 — 사본을 임시 디렉토리에 만들고 conf 없이 태운다.
  wd="$TMPC/$(printf '%s' "$d" | tr '/' '_')"; mkdir -p "$wd"
  cp "$d" "$wd/detect_codex.sh"
  out="$(env -i PATH=/usr/bin:/bin HOME="$TMPC/nohome" bash "$wd/detect_codex.sh" 2>/dev/null)"
  case "$out" in
    *'codex_available: false'*)
      assert_grep "$out" 'skip_reason: killswitch_config_' "fail-closed: $d — 설정 부재를 사유로 밝힌다" ;;
    *)
      no "fail-closed: $d — 설정 부재인데 codex_available 이 false 가 아니다 (fail-open)" ;;
  esac
done <<EOF
$(git ls-files -- 'plugins/*/scripts/detect_codex.sh')
EOF
if [ -n "$n_ref_detect" ]; then
  assert_eq "$n_fc" "$n_ref_detect" "fail-closed: 설정 부재로 태운 배포 지점 ${n_fc}건이 축 1a 의 참조원 도출(${n_ref_detect}건)과 같다 (보안 축이 vacuous 하지 않다)"
else
  no "fail-closed: 축 1a 의 도출 앵커가 없어 이 축이 vacuous 한지 판정할 수 없다"
fi
axis_tally "$n_fc"

# 축-실행 감사 — 정의는 파일 머리의 계측기 옆에 있다. 이 호출이 이 락의 마지막 실행
# 줄이고, `finish` 는 그 안에 있다. 이 줄이 사라지면 EXIT 트랩이 rc=1 로 죽인다 〔H1(b)〕.
axis_audit
