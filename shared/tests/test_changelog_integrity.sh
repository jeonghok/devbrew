#!/usr/bin/env bash
# guards: plugins/*/CHANGELOG.md plugins/*/.claude-plugin/plugin.json
#
# 플러그인 CHANGELOG 와 `plugin.json` 사이의 **구조적 정합**을 잰다.
#
# 왜 필요한가 (Task 31 fix round 4): `f68d253`(라운드 2)가 CHANGELOG 맨 위
# `## [4.1.1] — 2026-08-21` 헤딩을 **새 섹션을 위에 끼우는 대신 제자리에서
# `[4.1.2]` 로 덮어썼다.** 그래서 라운드 1 의 본문 전체(F1/F4/F2/F3 + F6)가
# `[4.1.2]` 섹션 **안으로** 흡수됐고, 4.1.1 은 존재한 적 없는 버전이 됐다.
# 한 릴리스 노트 안에서 `KNOWN_ORPHANS_PENDING_RULING` 이 "제거됐다"(라운드 2)와
# "그것으로 면제해뒀다"(라운드 1)로 동시에 서술되는 자기모순까지 남았다.
# 그 3일 동안 리포의 어떤 테스트도 RED 가 되지 않았다.
#
# ── C5 가 재는 것: 건너뛴 버전(gap) — 래칫 ──────────────────────────────
# 위 결함을 실제로 잡는 유일한 불변식은 "한 CHANGELOG 안에 건너뛴 버전이
# 없다"이다. 다른 후보들은 전부 그날 통과했다 〔실측〕:
#   · 맨 위 헤딩 == plugin.json         → 4.1.2 == 4.1.2 로 통과
#   · 헤딩이 단조 감소                   → 4.1.3 > 4.1.2 > 4.1.0 으로 통과
#   · 헤딩 형식 적합                     → 전부 적합해서 통과
#
# 검토했다가 **측정으로 죽인** 대안: "건너뛴 버전이 파일 어딘가에 언급돼
# 있어야 한다". 이 규칙은 **버전마다 결과가 다르다** 〔2026-08-22 실측,
# plugins/quality-gates/CHANGELOG.md〕: `4.1.1` 은 헤딩 줄을 지워도 본문에
# 열 회 이상 남아(다른 노트들이 그것을 인용한다) 규칙이 만족돼 통과하고,
# `4.1.5` 는 자기 헤딩 말고는 언급이 없어 걸린다. 즉 **가장 많이 인용되는
# 버전 — 곧 가장 중요한 릴리스 — 을 골라서 놓치는** 탐지기다. 잡히는지가
# 인용 횟수에 달렸으면 탐지기가 아니다.
#
# **그런데 이 리포의 역사에는 건너뛴 버전이 둘 있다** 〔전수 측정〕. 둘 다
# **실제로 배포된 버전인데 릴리스 노트를 안 쓴** 경우다:
#
#   · plugins/project-init/CHANGELOG.md — 1.7.2 ↔ 1.7.0 (1.7.1 헤딩 없음)
#     `883cc0d` 가 plugin.json 을 1.7.1 로 올렸다(description 압축, doc-only).
#     `[1.7.2]` 본문에 그 사실이 명시돼 있다 — 의도적으로 접어 넣은 것.
#   · plugins/spec-distill/CHANGELOG.md — 0.11.2 ↔ 0.11.0 (0.11.1 헤딩 없음)
#     `cd02494` 가 plugin.json 을 0.11.1 로 올렸다(description 영어 번역,
#     cache key 무효화). 이쪽은 아무 주석도 없다.
#
# 이 둘을 **소급 backfill 하지 않는다** — 존재한 적 없는 릴리스 노트를
# 써넣는 것은 CHANGELOG 에 허구를 적는 것이고, 코퍼스를 락에 맞춰 고치는
# 것은 불변식을 *만들어내는* 것이지 재는 것이 아니다. 대신 **래칫**으로
# 간다: 플러그인마다 floor 를 두고 **floor 이상에서만** gap-freedom 을
# 요구한다. 과거는 그대로 두되 앞으로는 못 늘어난다.
#
# floor 는 **동등 핀이 아니라 하한**이다. 리포에 테스트가 버전을 리터럴로
# 동등-핀해서 doc-only bump 마다 stale-red 가 난 전례가 있다 — floor 는
# 역사적 저수위라 bump 가 지나가도 값이 변하지 않는다.
#
# 그리고 floor 는 **선언이 아니라 검증된다**(C5b). 예외 목록의 위험은 다음
# 결함이 났을 때 목록에 한 줄 더 붙이는 것인데, 여기서는 그게 안 된다:
# floor 는 **바로 아래에 실재하는 gap 이 있을 때만** 유효하다. floor 를
# 올려 새 gap 을 피하려 하면 (floor, 바로 아래 헤딩) 쌍이 gap 이 아니게 되어
# C5b 가 RED 를 낸다. 내리면 C5a 가 그 gap 에서 RED 를 낸다. 즉 floor 의
# 값은 코퍼스의 구조가 정한다 — 목록은 그것을 적어둘 뿐이다.
#
# 표에 없는 플러그인은 floor = **가장 오래된 헤딩**, 즉 파일 전체가 검사
# 대상이다(fail-closed). 새 플러그인은 표를 건드리지 않아도 자동으로 가장
# 엄격한 쪽에 놓인다.
#
# ── 실제로 재는 것 (전부 2026-08-21 코퍼스에서 참으로 실측) ──────────────
#  C1 v>=1.0.0 이면 CHANGELOG 필수, v<1.0.0 이면 없어도 된다 (CLAUDE.md).
#  C2 맨 위 헤딩 버전 == plugin.json 버전.
#  C3 헤딩 버전이 위에서 아래로 **순감소**.
#  C4 헤딩 형식: `## [x.y.z] — <비어있지 않은 꼬리>` + 꼬리가 숫자로 시작하면
#     그것은 유효한 `YYYY-MM-DD` 여야 한다(월 01-12, 일 01-31).
#     꼬리를 날짜로 강제하지 **않는** 이유는 코퍼스가 그렇지 않기 때문이다:
#     `## [1.4.0] — 이전` · `## [1.3.0] — 이전` 두 개가 1.5 이전 꼬리에 있다
#     (초기 히스토리 비정형). 이 둘을 예외 목록으로 빼는 대신 술어를
#     코퍼스에서 도출했다 — "날짜가 있다면 올바른 날짜여야 한다".
#  C5a floor 이상 구간에서 인접한 두 헤딩 사이에 **건너뛴 버전이 없다**.
#     인접의 정의: 같은 major.minor 면 patch 가 정확히 1 감소 / 한 칸 위
#     minor 로 넘어가면 위쪽 patch 가 0 / 한 칸 위 major 로 넘어가면 위쪽이
#     `x.0.0`. 그 밖은 전부 gap 이다.
#  C5b floor 가 **tight** 하다 — floor 가 가장 오래된 헤딩이 아니라면 floor
#     바로 아래에 실재하는 gap 이 있어야 한다. floor 를 올려 새 결함을
#     면제하는 길을 막는다.
#
# 대상은 열거가 아니라 **도출**한다 — `git ls-files 'plugins/*'` 의 두 번째
# 경로 성분이 플러그인 집합이다. 새 플러그인이 생기면 자동으로 대상이 된다.
# 앵커를 피검자가 쥐지 않게 하려면 목록이 아니라 구조에서 나와야 한다.
#
# `0 checked / 0 problems` 는 "문제 없음"이 아니라 "아무것도 안 봤다"다 —
# 플러그인이 있는데 CHANGELOG 를 0개 열거하거나, CHANGELOG 를 열었는데 헤딩을
# 0개 뽑으면 큰 소리로 FAIL 한다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

# 헤딩 한 줄의 형식. `— ` 는 em dash(U+2014) + 공백이고, 뒤에 최소 한 글자가 온다.
HEAD_RE='^## \[[0-9]+\.[0-9]+\.[0-9]+\] — .'
# 꼬리가 날짜를 시도하고 있을 때(숫자로 시작) 요구하는 형식.
DATE_RE='^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])( .*)?$'

PLUGINS="$(git ls-files -- 'plugins/*' | cut -d/ -f2 | sort -u)"

# `--emit-scanned` — test_guards_coverage_bidirectional.sh 가 읽는다.
# 선언에서 도출하면 선언의 자기 반복이라 커버리지 증거가 안 된다. 이 락이
# **실제로 여는** 파일만 낸다: 모든 plugin.json + 존재하는 CHANGELOG.md.
if [ "${1:-}" = "--emit-scanned" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ -f "plugins/$p/.claude-plugin/plugin.json" ] && printf '%s\n' "plugins/$p/.claude-plugin/plugin.json"
    [ -f "plugins/$p/CHANGELOG.md" ] && printf '%s\n' "plugins/$p/CHANGELOG.md"
  done < <(printf '%s\n' "$PLUGINS")
  exit 0
fi

# ── vacuity 게이트 1: 플러그인 집합 ────────────────────────────────────────
plugin_n=0
while IFS= read -r p; do
  [ -n "$p" ] && plugin_n=$((plugin_n + 1))
done < <(printf '%s\n' "$PLUGINS")
if [ "$plugin_n" -lt 1 ]; then
  no "changelog: git ls-files 가 plugins/ 하위 플러그인을 0개 도출했다 — 이 검사 자체가 vacuous 하다"
  finish
  exit $?
fi
ok "changelog: 플러그인 ${plugin_n}개 도출 (vacuous 아님)"

# ver_gt A B → A > B 이면 0. 성분별 10진 비교(선행 0 안전).
ver_gt() {
  local a1 a2 a3 b1 b2 b3
  IFS=. read -r a1 a2 a3 <<< "$1"
  IFS=. read -r b1 b2 b3 <<< "$2"
  [ "$((10#$a1))" -gt "$((10#$b1))" ] && return 0
  [ "$((10#$a1))" -lt "$((10#$b1))" ] && return 1
  [ "$((10#$a2))" -gt "$((10#$b2))" ] && return 0
  [ "$((10#$a2))" -lt "$((10#$b2))" ] && return 1
  [ "$((10#$a3))" -gt "$((10#$b3))" ] && return 0
  return 1
}

# ── C5 래칫: 플러그인별 gap-freedom floor ─────────────────────────────────
# 형식: `<플러그인> <floor 버전>` 한 줄에 하나. 표에 없는 플러그인은 floor 가
# **가장 오래된 헤딩**이 되어 파일 전체가 검사된다(fail-closed).
#
# 각 값이 **왜 그 값인지** — 그 바로 아래에 실재하지 않는 버전의 gap 이 있다:
#   · project-init 1.7.2 — 아래가 1.7.0 이고 1.7.1 릴리스 노트가 없다.
#     `883cc0d` 가 plugin.json 만 1.7.1 로 올렸고(doc-only) 노트를 `[1.7.2]`
#     본문에 접어 넣었다. backfill 하면 없던 릴리스를 지어내는 것이 된다.
#   · spec-distill 0.11.2 — 아래가 0.11.0 이고 0.11.1 릴리스 노트가 없다.
#     `cd02494` 가 plugin.json 만 0.11.1 로 올렸다(description 번역).
#
# 이 값들은 C5b 가 검증한다 — 숫자만 보고 옮기면 RED 가 난다.
GAP_FLOORS='project-init 1.7.2
spec-distill 0.11.2'

# gap_floor_of <플러그인> → floor 를 stdout 으로. 표에 없으면 빈 문자열.
gap_floor_of() {
  local want="$1" name fl
  while read -r name fl; do
    [ -n "$name" ] || continue
    if [ "$name" = "$want" ]; then printf '%s' "$fl"; return 0; fi
  done <<< "$GAP_FLOORS"
  printf ''
}

# ver_adjacent HI LO → HI 가 LO 바로 위 버전이면 0(gap 없음), 아니면 1.
ver_adjacent() {
  local h1 h2 h3 l1 l2 l3
  IFS=. read -r h1 h2 h3 <<< "$1"
  IFS=. read -r l1 l2 l3 <<< "$2"
  h1=$((10#$h1)); h2=$((10#$h2)); h3=$((10#$h3))
  l1=$((10#$l1)); l2=$((10#$l2)); l3=$((10#$l3))
  if [ "$h1" -eq "$l1" ]; then
    if [ "$h2" -eq "$l2" ]; then
      [ "$h3" -eq $((l3 + 1)) ] && return 0
      return 1
    fi
    if [ "$h2" -eq $((l2 + 1)) ]; then
      [ "$h3" -eq 0 ] && return 0
      return 1
    fi
    return 1
  fi
  if [ "$h1" -eq $((l1 + 1)) ]; then
    [ "$h2" -eq 0 ] && [ "$h3" -eq 0 ] && return 0
    return 1
  fi
  return 1
}

changelog_n=0     # 실제로 연 CHANGELOG 수
heading_total=0   # 전 코퍼스 헤딩 수
pair_total=0      # 전 코퍼스에서 실제로 인접성을 잰 헤딩 쌍 수

while IFS= read -r plug; do
  [ -n "$plug" ] || continue
  pj="plugins/$plug/.claude-plugin/plugin.json"
  cl="plugins/$plug/CHANGELOG.md"

  if [ ! -f "$pj" ]; then
    no "changelog: $plug — .claude-plugin/plugin.json 이 없다 (버전을 알 수 없어 나머지 검사가 vacuous)"
    continue
  fi
  ver="$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+"' "$pj" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  if [ -z "$ver" ]; then
    no "changelog: $plug — plugin.json 에서 SemVer version 을 못 뽑았다 (추출 실패를 '문제 없음'으로 읽지 않는다)"
    continue
  fi

  # ── C1: v>=1.0.0 이면 CHANGELOG 필수 ─────────────────────────────────
  major="${ver%%.*}"
  if [ "$((10#$major))" -ge 1 ]; then
    if [ -f "$cl" ]; then
      ok "C1: $plug v$ver (>=1.0.0) — CHANGELOG.md 있음"
    else
      no "C1: $plug v$ver 는 1.0.0 이상인데 CHANGELOG.md 가 없다 (CLAUDE.md 필수 조항)"
      continue
    fi
  else
    if [ -f "$cl" ]; then
      ok "C1: $plug v$ver (<1.0.0) — CHANGELOG.md 선택인데 있음 (아래 검사 적용)"
    else
      ok "C1: $plug v$ver (<1.0.0) — CHANGELOG.md 없음 (허용)"
      continue
    fi
  fi

  changelog_n=$((changelog_n + 1))

  # ── 헤딩 열거 ────────────────────────────────────────────────────────
  headings="$(grep -n '^## \[' "$cl" || true)"
  hn=0
  while IFS= read -r h; do
    [ -n "$h" ] && hn=$((hn + 1))
  done < <(printf '%s\n' "$headings")
  if [ "$hn" -lt 1 ]; then
    no "C4: $cl — '## [' 헤딩을 0개 뽑았다 (파일은 있는데 추출이 아무것도 못 봤다 = 안 본 것)"
    continue
  fi
  heading_total=$((heading_total + hn))

  # ── C4: 형식 ─────────────────────────────────────────────────────────
  bad_fmt=0
  bad_date=0
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    lno="${h%%:*}"
    line="${h#*:}"
    if printf '%s\n' "$line" | grep -qE -- "$HEAD_RE"; then :; else
      no "C4: $cl:$lno — 헤딩 형식 위반 '$line' (기대: '## [x.y.z] — <꼬리>')"
      bad_fmt=$((bad_fmt + 1))
      continue
    fi
    tail_txt="${line#*] — }"
    first_ch="$(printf '%s' "$tail_txt" | cut -c1)"
    if printf '%s' "$first_ch" | grep -qE '^[0-9]$'; then
      if printf '%s\n' "$tail_txt" | grep -qE -- "$DATE_RE"; then :; else
        no "C4: $cl:$lno — 날짜 형식 위반 '$tail_txt' (기대: YYYY-MM-DD, 월 01-12 / 일 01-31)"
        bad_date=$((bad_date + 1))
      fi
    fi
  done < <(printf '%s\n' "$headings")
  [ "$bad_fmt" -eq 0 ] && [ "$bad_date" -eq 0 ] \
    && ok "C4: $cl — 헤딩 ${hn}개 형식 적합 (형식 위반 0 / 날짜 위반 0)"

  # ── C2: 맨 위 헤딩 == plugin.json ────────────────────────────────────
  top_line="$(printf '%s\n' "$headings" | head -1)"
  top_ver="$(printf '%s\n' "${top_line#*:}" | grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  if [ -z "$top_ver" ]; then
    no "C2: $cl — 맨 위 헤딩에서 버전을 못 뽑았다 ('${top_line#*:}')"
  else
    assert_eq "$top_ver" "$ver" "C2: $plug — 맨 위 헤딩 [$top_ver] == plugin.json $ver"
  fi

  # ── C3: 순감소 ───────────────────────────────────────────────────────
  prev=""
  desc_bad=0
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    lno="${h%%:*}"
    v="$(printf '%s\n' "${h#*:}" | grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    [ -n "$v" ] || continue
    if [ -n "$prev" ]; then
      if ver_gt "$prev" "$v"; then :; else
        no "C3: $cl:$lno — 순감소 위반: [$prev] 다음에 [$v] (같거나 커졌다)"
        desc_bad=$((desc_bad + 1))
      fi
    fi
    prev="$v"
  done < <(printf '%s\n' "$headings")
  [ "$desc_bad" -eq 0 ] && ok "C3: $cl — 헤딩 ${hn}개가 위에서 아래로 순감소"

  # ── C5: gap-freedom 래칫 ─────────────────────────────────────────────
  # floor 를 정한다. 표에 없으면 가장 오래된 헤딩 = 파일 전체 검사.
  oldest_ver="$(printf '%s\n' "$headings" | grep -oE '^[0-9]+:## \[[0-9]+\.[0-9]+\.[0-9]+\]' \
                 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tail -1)"
  floor="$(gap_floor_of "$plug")"
  floor_src="표"
  if [ -z "$floor" ]; then floor="$oldest_ver"; floor_src="가장 오래된 헤딩(표에 없음)"; fi
  if [ -z "$floor" ]; then
    no "C5: $cl — floor 를 정하지 못했다 (헤딩에서 가장 오래된 버전을 못 뽑았다)"
    continue
  fi

  # floor 가 실제 헤딩으로 존재하는가. 없으면 검사 범위가 조용히 어긋난다.
  floor_seen=0
  # C5a: floor 이상 구간의 인접성 + C5b 용 (floor 바로 아래) 쌍 포착
  prev=""
  gap_bad=0
  pairs_checked=0
  below_floor_ver=""
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    lno="${h%%:*}"
    v="$(printf '%s\n' "${h#*:}" | grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    [ -n "$v" ] || continue
    [ "$v" = "$floor" ] && floor_seen=1
    if [ -n "$prev" ]; then
      # 아래쪽(v)이 floor 이상인 쌍만 잰다 — floor 아래 역사는 그대로 둔다.
      if [ "$v" = "$floor" ] || ver_gt "$v" "$floor"; then
        pairs_checked=$((pairs_checked + 1))
        if ver_adjacent "$prev" "$v"; then :; else
          no "C5a: $cl:$lno — 건너뛴 버전: [$prev] 다음이 [$v] 다 (그 사이 버전의 릴리스 노트가 없다). floor=$floor"
          gap_bad=$((gap_bad + 1))
        fi
      fi
      [ "$prev" = "$floor" ] && below_floor_ver="$v"
    fi
    prev="$v"
  done < <(printf '%s\n' "$headings")
  pair_total=$((pair_total + pairs_checked))

  if [ "$floor_seen" -ne 1 ]; then
    no "C5: $cl — floor=$floor 가 이 파일의 헤딩에 없다 ($floor_src) — 검사 범위가 코퍼스와 어긋났다"
  elif [ "$gap_bad" -eq 0 ]; then
    ok "C5a: $cl — floor=$floor 이상 인접 쌍 ${pairs_checked}개에 건너뛴 버전 0 ($floor_src)"
  fi

  # ── C5b: floor tightness ─────────────────────────────────────────────
  # floor 가 가장 오래된 헤딩이면 파일 전체가 검사됐으므로 면제가 없다.
  # 그렇지 않다면 floor 바로 아래는 **실재하는 gap** 이어야 한다 — 아니면
  # 그 floor 는 아무 gap 도 면제하지 않으면서 검사 범위만 줄이고 있는 것이다.
  if [ "$floor" = "$oldest_ver" ]; then
    ok "C5b: $cl — floor=$floor 가 가장 오래된 헤딩이다 (면제 구간 없음 = 파일 전체 검사)"
  elif [ -z "$below_floor_ver" ]; then
    no "C5b: $cl — floor=$floor 아래 헤딩을 못 찾았다 (tightness 를 잴 수 없다)"
  elif ver_adjacent "$floor" "$below_floor_ver"; then
    no "C5b: $cl — floor=$floor 이 tight 하지 않다: 바로 아래 [$below_floor_ver] 와 인접해 gap 이 없다. 이 floor 는 아무것도 면제하지 않으면서 그 아래 전부를 검사에서 뺀다 — 표에서 지워라"
  else
    ok "C5b: $cl — floor=$floor tight ([$floor] 바로 아래 [$below_floor_ver] 사이에 실재 gap)"
  fi

done < <(printf '%s\n' "$PLUGINS")

# ── vacuity 게이트 2: CHANGELOG 를 실제로 하나도 안 열었으면 FAIL ─────────
if [ "$changelog_n" -lt 1 ]; then
  no "changelog: 플러그인 ${plugin_n}개가 있는데 CHANGELOG 를 0개 열었다 — '0 checked / 0 problems' 는 '문제 없음'이 아니라 '안 봤다'"
else
  ok "changelog: CHANGELOG ${changelog_n}개 / 헤딩 합계 ${heading_total}개를 실제로 읽었다"
fi
# ── vacuity 게이트 3: 헤딩 총량 ──────────────────────────────────────────
if [ "$heading_total" -lt 1 ]; then
  no "changelog: 전 코퍼스에서 헤딩을 0개 뽑았다 — 추출이 조용히 깨졌다"
fi
# ── vacuity 게이트 4: C5 가 실제로 쌍을 하나도 안 쟀으면 FAIL ────────────
# floor 가 전부 맨 위로 올라가버리면 C5 는 "gap 0" 을 조용히 보고한다.
if [ "$pair_total" -lt 1 ]; then
  no "C5: 전 코퍼스에서 인접 쌍을 0개 쟀다 — floor 가 전부 검사 범위를 지웠거나 추출이 깨졌다"
else
  ok "C5: 전 코퍼스 인접 쌍 ${pair_total}개를 실제로 쟀다"
fi

finish
