#!/usr/bin/env bash
# baseline-cache.sh — 기준선 테스트 결과의 내용주소 캐시 (design 2026-08-01 §5.4).
#
# 키 = (merge_base sha, runner, unit). 전부 결정론적·내용주소이므로:
#   · 무효화 로직이 필요 없다 — merge_base가 바뀌면 키 자체가 바뀐다.
#   · 락이 필요 없다 — 동시 실행이 쓰는 내용이 동일하므로 rename의
#     last-write-wins가 안전하다.
#
#   get <cache-root> <merge_base> <runner> <unit>...
#     stdout: 적중분만 `<unit>\t<status>\t<exit-code>` (미적중은 무출력)
#     exit:   0 정상(0건 적중 포함) · 4 손상(전량 미적중, stdout 비움)
#   put <cache-root> <merge_base> <runner> < results.tsv
#     exit:   0 기록 완료 · 4 기록 실패(advisory — 게이트를 막지 않는다)
#
# 파일: <cache-root>/<merge_base 앞 12자>.md
#   <!-- qg-baseline-cache:v1 -->
#   merge_base: <full sha>
#   ---
#   <runner>\t<unit>\t<status>\t<exit-code>
set -u

MARKER='<!-- qg-baseline-cache:v1 -->'
die() { echo "baseline-cache: $*" >&2; exit 2; }

cache_file() { printf '%s/%s.md\n' "$1" "${2:0:12}"; }

# 파일이 이 merge_base의 유효한 캐시인지. 유효하면 본문 행을 stdout으로 흘린다.
# 헤더·본문 어느 한 줄이라도 어긋나면 **전량** 미적중이다 — 반쯤 신뢰한 캐시가
# 조용히 틀린 귀속을 만든다.
read_valid_body() {   # read_valid_body <file> <merge_base> → 0=유효(본문 emit) 1=무효
  local f=$1 mb=$2 line1 line2 line3
  [[ -f "$f" ]] || return 1
  IFS= read -r line1 < "$f" || return 1
  [[ "$line1" == "$MARKER" ]] || return 1
  line2=$(sed -n '2p' "$f"); line3=$(sed -n '3p' "$f")
  [[ "$line2" == "merge_base: $mb" ]] || return 1
  [[ "$line3" == "---" ]] || return 1
  # 본문 전량 검증 후에야 emit한다 (마지막 줄이 깨져 있으면 앞 줄도 안 쓴다).
  local body; body=$(sed -n '4,$p' "$f")
  if [[ -n "$body" ]]; then
    printf '%s\n' "$body" | awk -F'\t' '
      NF != 4 { exit 1 }
      $3 !~ /^(pass|fail|error|unrun|absent)$/ { exit 1 }
      { print }
    ' || return 1
  fi
  return 0
}

case "${1:-}" in
  get)
    [[ $# -ge 4 ]] || die "usage: get <cache-root> <merge_base> <runner> <unit>..."
    root=$2; mb=$3; runner=$4; shift 4
    f=$(cache_file "$root" "$mb")
    body=$(read_valid_body "$f" "$mb") || {
      # 파일 부재는 조용한 0건 적중, 손상은 loud exit 4. 둘 다 stdout은 비운다.
      if [[ -f "$f" ]]; then
        echo "baseline-cache: 캐시 손상 — 전량 미적중으로 재계산: $f" >&2
        exit 4
      fi
      exit 0
    }
    for u in "$@"; do
      printf '%s\n' "$body" | awk -F'\t' -v r="$runner" -v u="$u" \
        '$1 == r && $2 == u { printf "%s\t%s\t%s\n", $2, $3, $4; exit }'
    done
    exit 0
    ;;
  put)
    [[ $# -eq 4 ]] || die "usage: put <cache-root> <merge_base> <runner> < results.tsv"
    root=$2; mb=$3; runner=$4
    mkdir -p "$root" 2>/dev/null || { echo "baseline-cache: mkdir 실패: $root" >&2; exit 4; }
    f=$(cache_file "$root" "$mb")

    # 기존 유효 본문에서 **이 runner의 행만** 제거하고 나머지는 보존한다.
    kept=""
    if old=$(read_valid_body "$f" "$mb"); then
      kept=$(printf '%s\n' "$old" | awk -F'\t' -v r="$runner" '$1 != r')
    elif [[ -f "$f" ]]; then
      echo "baseline-cache: 기존 캐시 손상 — 새로 씀: $f" >&2
    fi

    # stdin 정규화. `unrun`은 환경 상태에 달렸고 merge_base의 함수가 아니므로
    # 캐시하지 않는다 — 캐시하면 복구 가능한 실패가 영구화된다.
    fresh=$(awk -F'\t' -v r="$runner" '
      NF != 3 { next }
      $2 == "unrun" { next }
      $2 !~ /^(pass|fail|error|absent)$/ { next }
      { printf "%s\t%s\t%s\t%s\n", r, $1, $2, $3 }
    ')

    # file-granularity 러너에 BULK 키가 섞이면 캐시 오염 신호다 (AC42). 저장은 하되
    # 조용히 넘기지 않는다 — 호출자가 bulk-green을 unit별로 분해하지 않은 것이다.
    if printf '%s\n' "$fresh" | awk -F'\t' '$2 == "BULK"' | grep -q . \
       && printf '%s\n' "$fresh" | awk -F'\t' '$2 != "BULK"' | grep -q .; then
      echo "baseline-cache: 경고 — runner=$runner 에 BULK 키와 unit 키가 공존 (분해 누락?)" >&2
    fi

    tmp="$f.tmp.$$"
    {
      printf '%s\n' "$MARKER"
      printf 'merge_base: %s\n' "$mb"
      printf -- '---\n'
      [[ -n "$kept"  ]] && printf '%s\n' "$kept"
      [[ -n "$fresh" ]] && printf '%s\n' "$fresh"
    } > "$tmp" 2>/dev/null || { rm -f "$tmp"; echo "baseline-cache: 임시 파일 쓰기 실패" >&2; exit 4; }
    mv "$tmp" "$f" 2>/dev/null || { rm -f "$tmp"; echo "baseline-cache: rename 실패: $f" >&2; exit 4; }
    exit 0
    ;;
  *)
    die "unknown subcommand: ${1:-} (expected get|put)"
    ;;
esac
