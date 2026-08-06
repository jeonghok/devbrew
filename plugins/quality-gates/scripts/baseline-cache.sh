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
    # **캐시는 결함을 숨길 수 있는 상태를 적중으로 내주지 않는다.** 서빙 집합은
    # `pass`·`absent` 뿐이다. 근거는 공격/오류 방향의 **비대칭**이다:
    #
    #   심어지거나 낡은 `fail`  → (F,F) = PRE_EXISTING → DEFECTS 밖 → **회귀가 숨는다**
    #   심어지거나 낡은 `pass`  → (P,F) = NEW_REGRESSION → 결함으로 뜬다 (fail-closed)
    #   심어지거나 낡은 `absent`→ (A,F) = NEW_TEST_RED  → 결함으로 뜬다 (fail-closed)
    #
    # 그래서 `fail` 만 재검증하면 된다 — 미적중으로 떨어뜨리면 호출자가 기준선 트리에서
    # 그 unit 을 다시 돌린다. 봉인(digest)이 아니라 이 비대칭을 쓰는 이유: 캐시는
    # **실행 사이에 살아남는 것이 존재 이유**(merge_base 당 1회 상각)라, 세션 컨텍스트에
    # 든 오케스트레이터 비밀로 봉인할 수 없다. 파일에 둔 비밀은 verifier 의 Bash 가
    # 읽는다. 비대칭은 비밀을 필요로 하지 않는다.
    #
    # 같은 변경이 flaky 기준선 red 영구 동결도 닫는다 — 한 번 빨갛게 나온 unit 이
    # 브랜치 수명 내내 PRE_EXISTING 을 찍어내던 경로가 사라진다.
    #
    # `error`·`unrun` 도 여기서 걸린다. put 이 더 이상 쓰지 않지만 이 수정 **이전**
    # 버전이 남긴 캐시가 사용자 디스크에 이미 있다. read_valid_body 는 이 토큰들을
    # 여전히 **유효**로 보므로(옛 캐시 = 손상 아님) 파일이 통째로 exit 4 로 버려지지는
    # 않는다 — 그 행만 미적중이다.
    for u in "$@"; do
      printf '%s\n' "$body" | awk -F'\t' -v r="$runner" -v u="$u" \
        '$1 == r && $2 == u && $3 ~ /^(pass|absent)$/ { printf "%s\t%s\t%s\n", $2, $3, $4; exit }'
    done
    exit 0
    ;;
  put)
    [[ $# -eq 4 ]] || die "usage: put <cache-root> <merge_base> <runner> < results.tsv"
    root=$2; mb=$3; runner=$4
    mkdir -p "$root" 2>/dev/null || { echo "baseline-cache: mkdir 실패: $root" >&2; exit 4; }
    f=$(cache_file "$root" "$mb")

    # stdin 정규화. **캐시 가능한 상태는 `pass`·`fail`·`absent` 셋뿐이다** —
    # merge_base 트리의 함수라서 안정적이다.
    #
    # `unrun`·`error` 는 둘 다 환경 상태(설치 실패·네트워크·OOM·timeout·권한)에 달렸고
    # merge_base 의 함수가 아니다. 캐시하면 **복구 가능한 실패가 영구화된다**: 키가
    # (merge_base, runner, unit) 이고 TTL 도 환경 지문도 없으므로, 한 번 나쁜 기준선
    # 실행이 그 unit 들의 이후 HEAD 회귀를 브랜치 수명 내내 `PRE_EXISTING` 으로 가린다
    # (기준선에서 이미 red 인 것은 재실행 대상이 아니다 — R5b 재시도 규칙).
    # `error` 제외는 /qg iter-1 에서 codex 와 silent-failure-hunter 가 각각 실측해
    # 올린 것이다. 원래 주석이 `unrun` 을 뺀 근거가 `error` 에 **문자 그대로** 적용된다.
    #
    # 필터를 한 줄로 합친 이유: 예전에는 `$2 == "unrun" { next }` 와 허용집합 regex 가
    # 겹쳐 unrun 을 이중으로 막았고, 그래서 앞 줄을 지우는 mutation 이 GREEN 이었다
    # (pr-test-analyzer 가 자기 계측기 고장으로 보고). 관문이 하나면 그 착시가 없다.
    fresh=$(awk -F'\t' -v r="$runner" '
      NF != 3 { next }
      $2 !~ /^(pass|fail|absent)$/ { next }
      { printf "%s\t%s\t%s\t%s\n", r, $1, $2, $3 }
    ')

    # 기존 유효 본문에서 **이번 put이 갱신하는 (runner, unit) 키만** 제거하고
    # 나머지는 보존한다. 호출자(오케스트레이터)의 실제 payload는 보통 캐시
    # 미스분(부분집합)뿐이다 — 이 runner 섹션 전체를 통째로 지우면, 이번 호출에
    # 없는 unit의 유효한 과거 결과까지 사라져 "merge_base당 1회" 상각이 무너진다.
    # 멤버십 비교는 grep -qxF(고정 문자열)로 한다 — bare `grep -qx`는 unit을
    # 정규식으로 취급해 `a.py`가 저장된 `axpy`에 매치하는 등 조용한 오판을 만든다.
    kept=""
    if old=$(read_valid_body "$f" "$mb"); then
      fresh_units=$(printf '%s\n' "$fresh" | awk -F'\t' 'NF { print $2 }')
      kept=$(printf '%s\n' "$old" | while IFS=$'\t' read -r orunner ounit ostatus oexit; do
        [[ -z "$orunner" ]] && continue
        if [[ "$orunner" != "$runner" ]]; then
          printf '%s\t%s\t%s\t%s\n' "$orunner" "$ounit" "$ostatus" "$oexit"
        elif ! printf '%s\n' "$fresh_units" | grep -qxF -- "$ounit"; then
          printf '%s\t%s\t%s\t%s\n' "$orunner" "$ounit" "$ostatus" "$oexit"
        fi
      done)
    elif [[ -f "$f" ]]; then
      echo "baseline-cache: 기존 캐시 손상 — 새로 씀: $f" >&2
    fi

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
      :   # 블록의 종료 상태는 마지막 명령의 것이다 — 위 `[[ ]] &&` 가 빈 payload 에서
          # 1 로 단락되면 쓰기가 전부 성공했는데도 거짓 실패(exit 4)가 난다. 제거 금지.
    } > "$tmp" 2>/dev/null || { rm -f "$tmp"; echo "baseline-cache: 임시 파일 쓰기 실패" >&2; exit 4; }
    mv "$tmp" "$f" 2>/dev/null || { rm -f "$tmp"; echo "baseline-cache: rename 실패: $f" >&2; exit 4; }
    exit 0
    ;;
  *)
    die "unknown subcommand: ${1:-} (expected get|put)"
    ;;
esac
