#!/usr/bin/env bash
# discover_common.sh — discover-plan.sh 과 discover-spec.sh 이 공유하는 탐색 조각.
#
# **사본이 아니다.** 같은 플러그인 안의 중복이라 파일 하나를 source 하면 중복 자체가
# 소멸한다 (설계 §6.1③) — `copy-of` 마커도, 사본 동일성 검사도 필요 없다. 배포는
# 형제 스크립트와 같은 `${CLAUDE_PLUGIN_ROOT}/scripts/` 라 별도 배선이 없다.
#
# 실행 지점(`main`·인자 파싱)이 없다 — source 전용이다. 두 스크립트의 실제 차이는
# **적격성 술어** 하나뿐이고(plan = 체크박스 유무, spec = Acceptance Criteria 헤더),
# 그 차이는 pick_newest 의 인자로 표현된다. emit_json 은 여기 두지 않는다: 키 이름이
# 서로 다르고(`plan_path` ↔ `spec_path`), 다르다는 사실이 각 스크립트의 계약이다.

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
