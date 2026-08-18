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

# ── 축-실행 계측 (F1 의 절반) ────────────────────────────────────────────────
# 〔2026-08-18 fix round 1, F1〕 축 0 은 **주석 텍스트**만 센다. 그래서 어떤 축의
# 구현 본문을 통째로 지우고 헤더 주석만 남기면 세 카운터가 전부 그대로라 GREEN 이
# 된다(실측). 주석 개수는 "그 축이 있다고 **적혀 있다**"만 말할 뿐 "그 축이 **돌았다**"
# 는 말하지 않는다. 그래서 각 축이 **실제로 실행한 단언 수**를 여기서 기록하고,
# 파일 끝에서 헤더 집합과 대조한다.
# 호출은 **각 축 본문의 맨 끝**에 둔다 — 본문이 지워지면 이 호출도 함께 사라져
# 기록 집합이 헤더 집합보다 작아지고, 본문만 죽으면 기록된 수가 0 이 된다.
# 어느 쪽도 헤더 주석만으로는 만족시킬 수 없다.
_AXIS_TALLY=""
_AXIS_SEEN=0
axis_tally() {   # axis_tally <축 id>
  local now=$((_ASSERT_PASS+_ASSERT_FAIL))
  _AXIS_TALLY="${_AXIS_TALLY}$1 $((now-_AXIS_SEEN))
"
  _AXIS_SEEN=$now
}

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
axis_tally 0

# ── 축 1a: 심볼릭 링크 무결성 — 도미넌스(∀) 체크 (기본 방식, 설계 §16.1) ────
# 정본 목록은 이 사이클에 심볼릭 링크로 전환된 것 둘로 고정한다(설계 §16.1) —
# 이 목록이 배포 지점 목록과 다른 이유는 이 태스크 본문에 적었다.
SYMLINK_CANONICALS="shared/codex/detect_codex.sh
shared/codex/codex_findings_to_yaml.py"

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
  DEP_COUNTS="${DEP_COUNTS}${base} ${n_this}
"
done <<CANON
$SYMLINK_CANONICALS
CANON

# 전체 합 — 위 정본별 검사의 백스톱. 목록 자체가 비면 정본별 루프가 아예 안 돈다.
if [ "$n_expected" -ge 1 ]; then
  ok "symlink-∀: 파생된 배포 지점 총 ${n_expected}건 검사 (vacuous 아님)"
else
  no "symlink-∀: 파생된 배포 지점이 0건 — 참조 도출이 깨졌거나 SYMLINK_CANONICALS 가 비었다"
fi
axis_tally 1a

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
if printf '# copy-of: shared/x\n' | grep -qE "$MARKER_RE"; then
  ok "copy-of: MARKER_RE 카나리아 매치 (정규식 자체는 살아있다)"
else
  no "copy-of: MARKER_RE 카나리아가 매치하지 않는다 — 정규식이 깨졌다. 아래 물리 사본 스캔 결과는 무의미하다"
fi

n_copies=0
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
#  · `*.md` — 문서는 배포 코드가 아니다.
#  · 빈 파일(`.gitkeep` 등) — 마커를 실을 수 없고 갈라질 내용도 없다.
# 이 세 제외는 **좁히는 방향**이라 빠뜨리면 거짓 RED 로 시끄럽게 드러난다(넓히는
# 방향의 열거와 달리 조용히 fail-open 하지 않는다).
SHARED_BASENAMES="$(git ls-files -- 'shared/*' \
  | grep -vE '^shared/tests/' | grep -vE '\.md$' \
  | while IFS= read -r p; do [ -s "$p" ] && basename -- "$p"; done | sort -u)"
n_sb="$(printf '%s\n' "$SHARED_BASENAMES" | grep -c . || true)"
if [ "$n_sb" -ge 1 ]; then
  ok "copy-of: 배포 대상 정본 basename ${n_sb}건 도출 (후보 판별의 근거가 살아 있다)"
else
  no "copy-of: 배포 대상 정본이 0건 도출됐다 — 아래 사본 후보 판별이 통째로 vacuous 하다"
fi

n_cand=0
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
axis_tally 1b

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
# **도출 규칙**: `plugins/*/scripts/` · `plugins/*/hooks/` 안에서 `from <mod> import`
# 하는 소비자가 있는 **디렉토리** 전부. 이름을 열거하지 않는다(열거는 공간·시간
# 양쪽으로 fail-open). `grep` 이 심볼릭 링크를 따라가므로 qg·sd 의
# `codex_findings_to_yaml.py` 링크가 정본 본문을 통해 소비자로 걸린다.
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
# 소비 표기를 무는 정규식 — 고정 문자열 `from <mod> import` 하나로는 부족하다
# 〔2026-08-18 fix round 1, F6〕. 실측(A2)으로 `import X` · `import X as Y` ·
# `from  X  import`(이중 공백) · `from .X import`(상대) 가 **전부 미탐지**였다.
# 놓친 소비자는 기대 집합에서도 설치 프로브에서도 빠져 형제 단언과 설치 검증을 **양쪽 다**
# 건너뛴다 — 표기 하나 바꾸는 편집으로 CRIT-1 이 그대로 되돌아온다.
# 모듈명은 파이썬 식별자라 정규식 메타문자가 없다(이스케이프 불필요).
import_re() {   # import_re <모듈명> → ERE
  printf '%s' "^[[:space:]]*(from[[:space:]]+\.*$1[[:space:]]+import[[:space:]]|import[[:space:]]+$1([[:space:],]|\$))"
}

# 분류기 **앞**의 집합 — `shared/*.py` 중 리포 어딘가가 import 로 소비하는 것 전부.
CONSUMED_PY="$(git ls-files -- 'shared/*.py' \
  | while IFS= read -r cf; do
      cm="$(basename "$cf" .py)"
      git grep -lE "$(import_re "$cm")" 2>/dev/null \
        | grep -v "/${cm}\.py\$" | grep -q . && printf '%s\n' "$cf"
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

# 〔2026-08-18 fix round 1, F2〕 **형제 기대 위치를 소비자가 사는 곳이 아니라
# 소비자가 `sys.path` 에 얹는 곳에서 도출한다.** 앞 판본은 소비자 자신의 디렉토리를
# 요구했고 근거를 *"scripts/ 에만 있으면 설치본에서 ImportError 다"* 로 적었는데,
# 그 전제는 `sys.path.insert` 로 형제 디렉토리를 얹는 소비자에게 **거짓**이다 —
# 이 리포는 이미 그 패턴을 양방향으로 배포 중이고(예: `scripts/` 의 소비자가 `hooks/` 를
# 얹는다), 후속 태스크는 그 반대 방향(사본은 `scripts/`, 소비자는 `hooks/`)을 열두 곳에
# 만든다. 그대로 두면 **정상 배포에 열세 건의 거짓 RED** 가 나고, 그 압력이 축을
# 약화시킨다 — 가장 싼 약화가 코퍼스를 되돌리는 것이고 그게 CRIT-1 그 자체다.
# 얹는 구문이 없으면 소비자 자신의 디렉토리로 떨어진다(그때는 앞 판본과 같다).
#
# **표기를 정적으로 해석하지 않는다.** 얹는 자리는 `Path(__file__).resolve().parents[1]
# / "scripts"` · `os.path.dirname(os.path.abspath(__file__))` · 미리 만든 변수 등 형태가
# 제각각이라, 파서를 쓰면 모르는 형태마다 조용히 fail-open 한다. 대신 소비자를 **실제로
# 실행해** `sys.path` 델타를 잰다 — 아래 설치본 대역 프로브가 이미 같은 파일을 실행하므로
# 실행 위험은 새로 늘지 않는다.
SIMPROBE="$(mktemp -t copyof-probe-XXXXXX)" || exit 1
cat > "$SIMPROBE" <<'PYEOF'
# argv: <mode> <소비자 파일>
#   import — 링크 없는 일반 파일 트리에서 소비자를 실제로 실행한다(설치본 대역)
#   paths  — 소비자가 sys.path 에 **실제로 얹는** 디렉토리를 잰다
import importlib.util, os, sys
mode, target = sys.argv[1], sys.argv[2]
before = set(sys.path)

def run():
    spec = importlib.util.spec_from_file_location("dep_probe", target)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)      # 여기서 `from <mod> import ...` 가 실제로 돈다

if mode == "import":
    run()                            # 실패하면 traceback 이 그대로 stderr 로 나간다
    print("IMPORT_OK")
else:
    status = "OK"
    try:
        run()
    except BaseException as exc:     # 얹는 구문은 import 문 **앞**에 오므로
        status = "EXC:%s" % type(exc).__name__   # 여기서 죽어도 델타는 남아 있을 수 있다
    print("STATUS:" + status)
    for p in [q for q in sys.path if q not in before]:
        print("PATH:" + os.path.abspath(p))
PYEOF

CONSUMER_DIRS=""
dirs_of() {  # dirs_of <소비자> → 그 소비자가 형제를 푸는 디렉토리들
  printf '%s' "$CONSUMER_DIRS" | awk -v c="$1" '$1==c {print $2}'
}

for canon in $IMPORT_ONLY_CANONICALS; do
  mod="$(basename "$canon" .py)"
  if [ ! -f "$canon" ]; then no "형제-∀: 정본 $canon 이 없다"; continue; fi
  ire="$(import_re "$mod")"

  # 소비자 도출 — `grep` 은 심볼릭 링크를 따라가므로(git grep 과 달리) 링크로 배포된
  # 소비자도 정본 본문을 통해 걸린다. 모듈 자신과 그 사본은 뺀다(자기 소비 방지).
  consumers="$(git ls-files -- 'plugins/*/scripts/*' 'plugins/*/hooks/*' | grep -v "/${mod}\.py\$" \
    | while IFS= read -r f; do
        grep -qE "$ire" -- "$f" 2>/dev/null && printf '%s\n' "$f"
      done)"
  n_cons="$(printf '%s\n' "$consumers" | grep -c . || true)"

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
    praw="$(PYTHONDONTWRITEBYTECODE=1 python3 "$SIMPROBE" paths "$ROOT/$c" 2>/dev/null)"
    pstatus="$(printf '%s\n' "$praw" | sed -n 's/^STATUS://p' | head -1)"
    pabs="$(printf '%s\n' "$praw" | sed -n 's|^PATH:||p')"
    n_pabs="$(printf '%s\n' "$pabs" | grep -c . || true)"
    cdirs="$(printf '%s\n' "$pabs" | sed "s|^${ROOT}/||" | grep -E '^plugins/[^/]+/' | sort -u)"
    n_cdirs="$(printf '%s\n' "$cdirs" | grep -c . || true)"
    if [ -z "$pstatus" ]; then
      no "형제-∀: $c 의 sys.path 도출 프로브가 아무 것도 내지 않았다 — 기대 위치를 알 수 없다 (python3 부재/프로브 파손)"
      continue
    elif [ "$n_cdirs" -ge 1 ]; then
      :   # 얹는 자리가 있다 — 그것이 기대 위치다
    elif [ "$n_pabs" -ge 1 ]; then
      no "형제-∀: $c 가 sys.path 에 얹는 자리가 플러그인 트리 밖이다 ($(printf '%s' "$pabs" | tr '\n' ' ')) — 설치본에는 그 경로가 없다"
      continue
    elif [ "$pstatus" = "OK" ]; then
      cdirs="$own"   # 아무것도 얹지 않는다 → 소비자 자신의 디렉토리
    else
      no "형제-∀: $c 가 sys.path 도출 중 예외로 죽었고($pstatus) 얹은 자리도 없다 — '얹지 않는다' 와 '얹기 전에 죽었다' 를 구별할 수 없다"
      continue
    fi

    hit=""
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      CONSUMER_DIRS="${CONSUMER_DIRS}${c} ${d}
"
      [ -n "$hit" ] && continue
      [ -f "$d/${mod}.py" ] && hit="$d"
    done <<DIRS
$cdirs
DIRS
    if [ -z "$hit" ]; then
      no "형제-∀: $c 가 ${mod} 를 푸는 자리($(printf '%s' "$cdirs" | tr '\n' ' '))에 ${mod}.py 형제 사본이 없다 — 설치본에서 ImportError (CRIT-1 결함 모양)"
    elif git ls-files --error-unmatch -- "$hit/${mod}.py" >/dev/null 2>&1; then
      ok "형제-∀: $c → $hit/${mod}.py (sys.path 도출 위치에 형제 사본이 있고 git 에 실려 있다)"
    else
      # 〔F4/H1〕 사본을 untrack 하면 디스크엔 남아 존재 검사를 통과하지만 **설치본에는
      # 안 실린다** — 스캔 코퍼스(git ls-files)에서만 조용히 사라진다. 존재와 배포는 다르다.
      no "형제-∀: $hit/${mod}.py 가 git 에 추적되지 않는다 — 디스크엔 있어도 설치본에 안 실린다"
    fi
  done <<EOF
$consumers
EOF

  SIM="$(mktemp -d -t copyof-install-XXXXXX)" || exit 1
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
    res="$(PYTHONDONTWRITEBYTECODE=1 python3 "$SIMPROBE" import "$SIM/$c" 2>&1)"
    case "$res" in
      *IMPORT_OK*) ok "형제-∀(설치본 대역): $c 가 링크 없는 일반 파일 트리에서 ${mod} 를 import 한다" ;;
      *) no "형제-∀(설치본 대역): $c 가 ${mod} 를 import 못 한다 — $(printf '%s' "$res" | tail -1)" ;;
    esac
  done <<EOF
$consumers
EOF
  rm -rf "$SIM"
done
rm -f "$SIMPROBE"
axis_tally 1c

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
axis_tally 2

# ── 축 3: 설정 부재 시 fail-closed ────────────────────────────────────────
# kill switch 는 보안 컨트롤이다(CLAUDE.md:48). 설정을 못 읽었을 때 변수명이 빈 값으로
# 해석돼 스위치가 조용히 무반응이 되면, 사용자는 껐다고 **믿게만** 된다.
# 〔F5〕 이 루프는 카운터조차 없었다 — 코퍼스가 비면 **단언 0개로 통과**했다(실측 N7:
# `Total: 1 | Pass: 1 | Fail: 0`). 보안 컨트롤 축이 조용히 사라지는 모양이다.
# 그래서 실제로 태운 횟수를 세고 축 1a 의 도출과 대조한다.
TMPC="$(mktemp -d -t copyof-failclosed-XXXXXX)" || exit 1
trap 'rm -rf "$TMPC"' EXIT
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
axis_tally 3

# ── 축 0 후반부 — 주석 개수와 **실행된 단언 수**를 함께 묶는다 〔F1〕 ────────
# 앞의 축 0 은 주석 텍스트만 셌다. 그래서 어떤 축의 구현 본문을 통째로 지우고 헤더
# 주석만 남기면 세 카운터가 전부 그대로였고, 락에 단언 **개수**를 재는 것이 하나도
# 없었다(실측: 축 1c 본문 삭제 → `n_head=3 n_axis=3` 불변 → GREEN, 단언 자리 4개 소멸).
# 여기서 헤더가 선언한 축 집합과 **실제로 단언을 남긴** 축 집합을 대조한다 —
# 두 방향 다 본다(선언했는데 안 돌았다 / 돌았는데 선언이 없다). 어느 쪽도 주석만
# 고쳐서는 맞출 수 없다.
tallied_ids="$(printf '%s' "$_AXIS_TALLY" | awk '{print $1}' | sort -u)"
assert_eq "$tallied_ids" "$AXIS_IDS" "축-실행: 헤더가 선언한 축 집합과 실제로 단언을 실행한 축 집합이 같다"
n_axis_ids="$(printf '%s\n' "$AXIS_IDS" | grep -c . || true)"
if [ "$n_axis_ids" -ge 1 ]; then
  ok "축-실행: 축 헤더에서 ${n_axis_ids}건의 축 id 를 도출 (대조 근거가 살아 있다)"
else
  no "축-실행: 축 id 가 0건 도출됐다 — 헤더 도출이 깨졌다. 위 집합 대조는 무의미하다"
fi
while IFS= read -r aid; do
  [ -n "$aid" ] || continue
  n_run="$(printf '%s' "$_AXIS_TALLY" | awk -v a="$aid" '$1==a {s+=$2} END{print s+0}')"
  if [ "$n_run" -ge 1 ]; then
    ok "축-실행: 축 $aid 가 단언 ${n_run}건을 실제로 실행했다"
  else
    no "축-실행: 축 $aid 가 단언을 0건 실행했다 — 헤더 주석은 있는데 본문이 죽었다(또는 통째로 지워졌다)"
  fi
done <<EOF
$AXIS_IDS
EOF

finish
