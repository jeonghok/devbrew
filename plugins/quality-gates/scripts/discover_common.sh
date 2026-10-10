#!/usr/bin/env bash
# discover_common.sh — discover-plan.sh 이 source 하는 탐색 조각(get_mtime · pick_newest).
#
# 실행 지점(`main`·인자 파싱)이 없다 — source 전용이다. 적격성 술어(plan = 체크박스 유무)는
# pick_newest 의 인자로 넘긴다. discover-spec.sh 는 이 파일을 쓰지 않는다 — 의도 출처는
# mtime 이 아니라 `Spec:` 트레일러 → 커밋 메시지 + PR 본문 사슬이다.

# Portable mtime (BSD stat on macOS, GNU stat on Linux)
get_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

# pick_newest <dir> <predicate>
#   <dir> 바로 아래(-maxdepth 1)의 *.md 중 <predicate> 가 0 을 내는 파일에서 mtime 이
#   가장 큰 것을 stdout 으로 출력하고 0 을 반환한다. 적격 파일이 하나도 없으면 1.
#   <predicate> 는 파일 경로 하나를 받는 셸 함수 이름 — 호출자가 정의한다.
#   디렉토리 자체가 없으면 1 (탐색 실패이지 오류가 아니다 — 호출자가 다음 source 로).
pick_newest() {
  local dir="$1" pred="$2"
  [[ -d "$dir" ]] || return 1

  local best="" best_mtime=0
  local f m

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    "$pred" "$f" || continue
    m=$(get_mtime "$f")
    if [[ "$m" -gt "$best_mtime" ]]; then
      best="$f"
      best_mtime="$m"
    fi
  done < <(find "$dir" -maxdepth 1 -type f -name '*.md' 2>/dev/null)

  [[ -n "$best" ]] || return 1
  printf '%s\n' "$best"
}
