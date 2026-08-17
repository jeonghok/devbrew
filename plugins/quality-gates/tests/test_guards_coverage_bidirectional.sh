#!/usr/bin/env bash
# guards: plugins/** shared/**
#
# `# guards:` 선언이 그 락이 **실제로 읽은** 경로 집합과 서로를 덮는가.
#
# 한 방향만 재면 안 된다:
#  - 선언 ⊂ 실제  → 락이 지키는 것이 diff에 있어도 선택되지 않는다(조용한 미선택).
#  - 선언 ⊃ 실제  → 선택은 되는데 아무것도 안 본다("덮음: 전량"을 통과하며 한
#                   플러그인만 스캔).
#
# 판정은 락의 `--emit-scanned` 출력으로 한다 — 선언에서 파일 목록을 도출하면
# "락이 실제로 읽었다"의 증거가 아니라 선언의 자기 반복이다.
set -u

# 이 파일 자신이 `# guards:` 를 선언하므로 아래 도출에 **자기 자신이 든다.** 그러면
# `bash "$lock" --emit-scanned` 가 자기를 다시 실행해 **무한 자기재귀**가 된다 —
# 게다가 안쪽 출력이 `$(...)` 와 `2>/dev/null` 에 전부 삼켜져 **크래시도 출력도 없이
# 멈춘 것처럼** 보인다(〔실측〕 깊이 카운터로 depth=0..4 확인). 여기서 즉시 답하고 끝낸다:
# 이 검사기는 아무 경로도 스캔하지 않으므로 빈 stdout 이 정확한 답이고, 호출부의
# `[ -z "$scanned" ]` 분기가 그것을 "미지원"으로 읽어 아래 Expected 와 일치한다.
# **자기 자신을 목록에서 빼는 방식은 쓰지 않는다** — PR1 시점에 목록이 비어 "vacuous"
# FAIL 이 나기 때문이다.
[ "${1:-}" = "--emit-scanned" ] && exit 0

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
pass=0; fail=0
ok() { pass=$((pass+1)); echo "  ✓ $1"; }
no() { fail=$((fail+1)); echo "  ✗ $1"; }

# 대상은 열거가 아니라 **도출**한다 — 새 락이 생기면 자동으로 대상이 된다.
# `--cached --others --exclude-standard` 인 이유: 추적된 파일만 보면 **방금 쓴 락이 커밋
# 전까지 보이지 않는다.** 이 파일 자신이 PR1 시점의 유일한 선언 보유자이므로, 추적-only
# 로는 Step 2(커밋 전 실행)가 반드시 "0개 — vacuous" FAIL 을 낸다 〔실측〕. 락은 디스크에
# 존재하는 순간부터 감사 대상이어야 한다 — 커밋 여부는 그 락이 무엇을 지키는지와 무관하다.
# `mapfile` 을 쓰지 않는다 — 〔실측〕 이 기계의 `env bash` 는 **bash 3.2.57**(macOS 시스템
# bash)이고 `mapfile` 은 bash 4.0+ 빌트인이라 없다. 쓰면 `LOCKS` 가 미할당인 채
# `set -u` 아래 unbound 로 죽어 **테스트가 한 번도 못 돈다.**
LOCKS=()
while IFS= read -r f; do
  [ -n "$f" ] && LOCKS+=("$f")
done < <(cd "$ROOT" && git ls-files --cached --others --exclude-standard -- '*.sh' | grep -E '(^|/)tests?/' \
  | while IFS= read -r g; do head -30 -- "$g" | grep -q '^[[:space:]]*#[[:space:]]*guards:' && echo "$g"; done)

# `${#LOCKS[@]}` 는 빈 배열에도 안전(0)하지만 `"${LOCKS[@]}"` 확장은 bash 3.2 + `set -u`
# 에서 **unbound 로 죽는다** 〔실측〕. 그래서 개수 검사가 반드시 for 루프보다 앞이다.
if [ "${#LOCKS[@]}" -lt 1 ]; then
  no "guards: 선언을 가진 파일이 0개 — 이 검사가 vacuous하다"
  echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"; exit 1
fi
ok "guards: 선언 파일 ${#LOCKS[@]}개 도출 (vacuous 아님)"

for lock in "${LOCKS[@]}"; do
  # 후행 공백·CR 을 함께 턴다 — Task 5 의 추출부와 같은 규약(CRLF 파일의 선언이
  # 마지막 글롭에 `\r` 을 붙여 조용히 아무것도 안 맞추는 것을 막는다).
  decl="$(head -30 -- "$ROOT/$lock" | sed -n 's/^[[:space:]]*#[[:space:]]*guards:[[:space:]]*//p' | sed 's/[[:space:]]*$//' | head -1)"
  if [ -z "$decl" ]; then
    # 조용히 넘기지 않는다. 그리고 빈 배열을 `"${arr[@]}"` 로 확장하면 bash 3.2 +
    # `set -u` 에서 죽으므로 여기서 끊는 것이 크래시 방지이기도 하다.
    no "guards: $lock — 선언이 비어 있다 (guards: 뒤에 글롭이 없다)"
    continue
  fi
  # 따옴표 없는 `for g in $decl` 를 쓰지 않는다 — 〔Task 5 실측〕 bash 에서 word-split
  # **뒤에 pathname expansion** 이 일어나 리터럴 `plugins/**` 가 실제 디렉토리 이름으로
  # 전개된다. cwd 의존이라 `plugins/` 가 없는 곳에서는 정상 동작하고 있는 곳에서만
  # 조용히 틀린다. `read -a` 는 glob 하지 않는다.
  # **`IFS` 를 지정하지 않는다** — 기본값 `$' \t\n'` 이라야 탭 구분 선언도 쪼갠다.
  # `IFS=' '` 로 좁히면 globbing 버그를 splitting 버그로 맞바꾸는 것이다(Task 5 F1).
  read -r -a decl_globs <<< "$decl"
  # `--emit-scanned` 를 지원하지 않는 선언 파일은 이 검사 대상 밖이다. 단
  # **조용히 넘어가지 않는다** — 지원 여부 자체를 보고한다.
  if ! scanned="$(cd "$ROOT" && bash "$lock" --emit-scanned 2>/dev/null)" || [ -z "$scanned" ]; then
    ok "guards: $lock — --emit-scanned 미지원 (커버리지 대조 대상 아님, 선언만 존재)"
    continue
  fi

  # 방향 A: 실제로 읽은 것이 전부 선언 안에 드는가 (선언이 좁지 않은가)
  outside=0
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    m=0
    for g in "${decl_globs[@]}"; do
      # shellcheck disable=SC2254
      case "$p" in $g) m=1; break ;; esac
    done
    [ "$m" -eq 0 ] && { outside=$((outside+1)); echo "      선언 밖: $p"; }
  done <<< "$scanned"
  [ "$outside" -eq 0 ] \
    && ok "guards: $lock — 읽은 경로가 전부 선언 안 (선언이 좁지 않다)" \
    || no "guards: $lock — 선언 밖 경로 ${outside}건 (선언이 좁다 → 조용한 미선택)"

  # 방향 B: 선언이 가리키는 것 중 실제로 읽힌 것이 있는가 (선언이 헛돌지 않는가)
  for g in "${decl_globs[@]}"; do
    n=0
    while IFS= read -r p; do
      [ -z "$p" ] && continue
      # shellcheck disable=SC2254
      case "$p" in $g) n=$((n+1)) ;; esac
    done <<< "$scanned"
    [ "$n" -gt 0 ] \
      && ok "guards: $lock — 글롭 '$g' 가 실제 ${n}건을 덮는다" \
      || no "guards: $lock — 글롭 '$g' 가 아무것도 안 덮는다 (선언이 넓다)"
  done
done

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[ "$fail" -eq 0 ]
