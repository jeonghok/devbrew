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
# ── 이 락이 재지 **않는** 것: 건너뛴 버전 ────────────────────────────────
# 위 결함을 실제로 잡는 유일한 불변식은 "한 CHANGELOG 안에 건너뛴 버전이
# 없다"이다. 다른 후보들은 전부 그날 통과했다 〔실측〕:
#   · 맨 위 헤딩 == plugin.json         → 4.1.2 == 4.1.2 로 통과
#   · 헤딩이 단조 감소                   → 4.1.3 > 4.1.2 > 4.1.0 으로 통과
#   · 헤딩 형식 적합                     → 전부 적합해서 통과
#
# **그런데 이 리포는 그 불변식을 지키지 않는다** 〔2026-08-21 전수 측정〕.
# 4.1.1 복구 후에도 건너뛴 버전이 둘 남는다 — 그리고 둘 다 정당하다.
# 둘 다 **실제로 배포된 버전인데 릴리스 노트를 안 쓴** 경우다:
#
#   · plugins/project-init/CHANGELOG.md — 1.7.2 ↔ 1.7.0 (1.7.1 없음)
#     `883cc0d` 가 plugin.json 을 1.7.1 로 올렸다(description 압축, doc-only).
#     `[1.7.2]` 본문에 그 사실이 명시돼 있다 — 의도적으로 접어 넣은 것.
#   · plugins/spec-distill/CHANGELOG.md — 0.11.2 ↔ 0.11.0 (0.11.1 없음)
#     `cd02494` 가 plugin.json 을 0.11.1 로 올렸다(description 영어 번역,
#     cache key 무효화). 이쪽은 아무 주석도 없다.
#
# 그래서 건너뛴-버전 검사를 **일부러 넣지 않았다.** 넣으려면 예외 목록이
# 필요한데, 바로 세 커밋 전 `f68d253` 이 같은 태스크에서 정확히 그 이유로
# `KNOWN_ORPHANS_PENDING_RULING` 예외 메커니즘을 지웠다 — *"빈 예외 목록도
# 위험하긴 마찬가지다 — 다음 [결함]이 생겼을 때 이 목록에 한 줄 추가하는 것이
# 이 락이 막으려는 바로 그 결정이기 때문이다."* 코퍼스를 락에 맞춰 고치는 것
# (두 항목을 소급 backfill 하거나 주석을 다는 것) 역시 불변식을 **만들어내는**
# 것이지 측정하는 것이 아니다.
#
# **따라서 아래 검사들은 오늘의 결함을 잡지 못한다.** 이것은 결함이 아니라
# 정직한 공백이다 — 거짓 불변식을 박아 넣은 락보다 낫다. 미래 세션이 "건너뛴
# 버전 검사를 넣자"고 생각한다면, 먼저 위 두 갭을 어떻게 할지 정해야 한다.
# 이 문단이 그 결정을 재발견 없이 하도록 남긴 기록이다(Law 3).
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

changelog_n=0     # 실제로 연 CHANGELOG 수
heading_total=0   # 전 코퍼스 헤딩 수

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

finish
