#!/usr/bin/env bash
# guards: plugins/** shared/**
#
# 통합한 것의 **재분열**을 막는다. 배포 지점이 정본을 가리키는 방법은 둘이다:
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

# ── 축 0: README 의 계약 수 서술이 이 락의 실제 계약 축 수와 맞는가 ─────────
# 〔2026-08-18 Ruling 45〕 축 1c 가 들어오기 전 shared/README.md 는 이 락을 "두 계약"
# 으로 서술했고, 축이 셋이 된 뒤에도 그 문장이 그대로 남았다. **존재 검사로는 못 잡는다**
# — README 에 특정 문구가 살아 있는지만 보는 grep 은 서술이 낡아도 똑같이 1 을 낸다.
# 양성 존재 단언은 정확성을 재지 않는다. 그래서 여기서는 **수를 센다**, 그것도 손으로
# 적지 않고 이 파일 자신의 두 자리(머리말 (a)(b)(c) 목록 · 축 헤더)에서 도출해 셋이
# 서로를 덮는지 본다 — 한 자리만 재면 그 자리를 고치는 편집이 나머지를 조용히 낡게 둔다.
#
# **못 보는 것**: 도출은 축 헤더의 번호 관례에 기댄다. 다음 저자가 네 번째 계약을
# `축 4` 로 붙이면 이 도출은 그것을 안 센다 — 계약 축은 1 번대 문자 접미로 붙인다.
SELF="shared/tests/$(basename -- "$0")"
if [ ! -f "$SELF" ] || [ ! -f "shared/README.md" ]; then
  no "README: 대조 대상이 없다 (self='$SELF') — 아래 계약 수 대조는 무의미하다"
else
  n_head="$(grep -cE '^#   \([a-z]\) ' "$SELF" || true)"
  n_axis="$(grep -cE '^# ── 축 1[a-z]: ' "$SELF" || true)"
  assert_eq "$n_head" "$n_axis" "README: 머리말 계약 목록(${n_head}건)과 축 헤더(${n_axis}건)가 같은 수를 낸다"
  case "$n_axis" in
    1) want='한' ;; 2) want='두' ;; 3) want='세' ;; 4) want='네' ;; 5) want='다섯' ;; *) want='' ;;
  esac
  if [ -z "$want" ]; then
    no "README: 축 수 '${n_axis}' 에 대응하는 수사를 모른다 — 도출이 깨졌거나 대응표 밖의 값이다"
  else
    ok "README: 계약 축 ${n_axis}건을 이 파일에서 도출 (열거 없음)"
    said="$(sed -nE 's/^`shared\/tests\/test_copy_of_contract\.sh` — ([^ ]+) 계약을 검사한다.*/\1/p' shared/README.md | head -1)"
    assert_eq "${said:-없음}" "$want" "README: shared/README.md 의 계약 수 서술이 실제 축 수(${n_axis}건)와 일치한다"
  fi
fi

# ── 축 1a: 심볼릭 링크 무결성 — 도미넌스(∀) 체크 (기본 방식, 설계 §16.1) ────
# 정본 목록은 이 사이클에 심볼릭 링크로 전환된 것 둘로 고정한다(설계 §16.1) —
# 이 목록이 배포 지점 목록과 다른 이유는 이 태스크 본문에 적었다.
SYMLINK_CANONICALS="shared/codex/detect_codex.sh
shared/codex/codex_findings_to_yaml.py"

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
  refs="$(grep -rlE "scripts/${esc_base}" \
            plugins/*/skills plugins/*/scripts plugins/*/hooks plugins/*/agents plugins/*/commands \
            2>/dev/null | grep -vE "^plugins/[^/]+/scripts/${esc_base}\$")"
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
done <<CANON
$SYMLINK_CANONICALS
CANON

# 전체 합 — 위 정본별 검사의 백스톱. 목록 자체가 비면 정본별 루프가 아예 안 돈다.
if [ "$n_expected" -ge 1 ]; then
  ok "symlink-∀: 파생된 배포 지점 총 ${n_expected}건 검사 (vacuous 아님)"
else
  no "symlink-∀: 파생된 배포 지점이 0건 — 참조 도출이 깨졌거나 SYMLINK_CANONICALS 가 비었다"
fi

# ── 축 1b: copy-of 물리 사본이 정본과 바이트 동일 (잔여 — 링크를 못 쓰는 경우) ──
# 카나리아(vacuous 방지, 축 1a에 기대지 않는다) — 코퍼스와 무관한 합성 문자열로
# MARKER_RE 자체를 매 실행마다 검사한다. 이 사이클 이 시점엔 물리 copy-of
# 파일이 0건이라(Task 19 이전) "0건 발견"과 "정규식이 깨졌다"를 코퍼스
# 스캔만으로는 구별할 수 없다 — 축 1a의 결과를 빌려 오면 두 독립 코드 경로
# (심볼릭 링크 판정 vs 마커 정규식)를 하나가 맞으면 나머지도 맞다고 가정하는
# 것이라 MARKER_RE 가 리팩터로 조용히 깨져도 아무도 못 잡는다(2026-08-17
# 라운드 1 코드 리뷰 지적). 그래서 축 1b는 **자기 것으로** vacuous 방지를 한다.
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
IMPORT_ONLY_CANONICALS="$(git ls-files -- 'shared/*.py' \
  | while IFS= read -r cf; do
      grep -qE '^if __name__ == "__main__"' -- "$cf" && continue
      cm="$(basename "$cf" .py)"
      git grep -lE "from ${cm} import" 2>/dev/null \
        | grep -v "/${cm}\.py\$" | grep -q . && printf '%s\n' "$cf"
    done)"
n_canon="$(printf '%s\n' "$IMPORT_ONLY_CANONICALS" | grep -c . || true)"
if [ "$n_canon" -ge 1 ]; then
  ok "형제-∀ 도출: import-only 정본 ${n_canon}건 (이름 열거 없음)"
else
  no "형제-∀ 도출: import-only 정본이 0건 — 도출 규칙이 깨졌다. 아래 ∀ 는 한 번도 안 돈다"
fi

SIMPROBE="$(mktemp -t copyof-probe-XXXXXX)" || exit 1
cat > "$SIMPROBE" <<'PYEOF'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("dep_probe", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)      # 여기서 `from <mod> import ...` 가 실제로 돈다
print("IMPORT_OK")
PYEOF
for canon in $IMPORT_ONLY_CANONICALS; do
  mod="$(basename "$canon" .py)"
  if [ ! -f "$canon" ]; then no "형제-∀: 정본 $canon 이 없다"; continue; fi

  consumers="$(git ls-files -- 'plugins/*/scripts/*' 'plugins/*/hooks/*' | grep -v "/${mod}\.py\$" \
    | while IFS= read -r f; do
        grep -q "from ${mod} import" -- "$f" 2>/dev/null && printf '%s\n' "$f"
      done)"
  expected="$(printf '%s\n' "$consumers" | grep . | sed -E 's#/[^/]+$##' | sort -u || true)"
  n_exp="$(printf '%s\n' "$expected" | grep -c . || true)"

  # positive(도출이 살아 있는가): 0건이면 아래 ∀ 가 통째로 vacuous 다.
  if [ "$n_exp" -ge 1 ]; then
    ok "형제-∀: ${mod} 소비자를 가진 배포 디렉토리 ${n_exp}건 도출 (vacuous 아님)"
  else
    no "형제-∀: ${mod} 소비자가 0건 도출됐다 — 도출 규칙이 깨졌다. 아래 ∀ 는 무의미하다"
  fi

  while IFS= read -r cdir; do
    [ -n "$cdir" ] || continue
    sib="$cdir/${mod}.py"
    if [ -f "$sib" ]; then ok "형제-∀: $cdir 에 ${mod}.py 형제 사본이 있다"
    else no "형제-∀: $cdir 에 ${mod}.py 형제 사본이 없다 — 설치본에서 ImportError (CRIT-1 결함 모양)"; fi
  done <<EOF
$expected
EOF

  SIM="$(mktemp -d -t copyof-install-XXXXXX)" || exit 1
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    cdir="$(printf '%s' "$c" | sed -E 's#/[^/]+$##')"
    d="$SIM/$cdir"
    [ -d "$d" ] || { mkdir -p "$d"; cp -RL "$cdir/." "$d/" 2>/dev/null; }
    res="$(PYTHONDONTWRITEBYTECODE=1 python3 "$SIMPROBE" "$d/$(basename "$c")" 2>&1)"
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

# ── 축 2: 형제 설정이 배포에 실린다 ───────────────────────────────────────
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

# ── 축 3: 설정 부재 시 fail-closed ────────────────────────────────────────
# kill switch 는 보안 컨트롤이다(CLAUDE.md:48). 설정을 못 읽었을 때 변수명이 빈 값으로
# 해석돼 스위치가 조용히 무반응이 되면, 사용자는 껐다고 **믿게만** 된다.
TMPC="$(mktemp -d -t copyof-failclosed-XXXXXX)" || exit 1
trap 'rm -rf "$TMPC"' EXIT
while IFS= read -r d; do
  [ -n "$d" ] || continue
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

finish
