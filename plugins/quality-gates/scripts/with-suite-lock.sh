#!/bin/bash
# with-suite-lock.sh — 차등 테스트의 테스트 명령 하나를 공유 스위트 잠금 아래 돌린다.
#
#   with-suite-lock.sh <세션 폴더> -- <명령> [인자…]
#
# 잠금 자리 파일(<세션 폴더>/suite-lock-path.txt — setup-qg.sh 가 --suite-lock 으로 쓴다)이 없으면 명령만 돌린다.
# 있으면 suite_lock.py run 으로 기다리지 않고(--wait 0) 잡아 본다:
#   - 잡으면 명령이 도는 동안 쥐고 끝나면 푼다(주인 quality-gates).
#   - 잡혀 있으면(75) 겹침 기록(<세션 폴더>/suite-overlap.txt)에 `busy\t<주인>\t<잡은 시각>`,
#     그 밖(쓸 수 없음 3 등)이면 `unusable\t-\t-` 를 덧붙이고 명령을 잠금 없이 돌린다.
#     겹침 기록이 비어 있었으면 겹침 줄을 표준 오류에 한 번 낸다.
# 종료 코드는 언제나 명령의 것이다 — 명령이 잠금 아래 돌았는지는 종료 코드가 아니라 --child 가 남긴 파일로 가린다.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "${1:-}" = "--child" ]; then   # 잠금 아래에서 suite_lock.py 가 부르는 갈래 — 명령을 돌리고 종료 코드를 남긴다
  RCF="${2:-}"; shift 2 2>/dev/null || exit 2
  [ "${1:-}" = "--" ] && shift
  "$@"; rc=$?
  printf '%s\n' "$rc" > "$RCF"
  exit "$rc"
fi

if [ $# -lt 3 ] || [ "$2" != "--" ]; then
  echo "with-suite-lock: 쓰는 법 — with-suite-lock.sh <세션 폴더> -- <명령> [인자…]" >&2
  exit 2
fi
RD="$1"; shift 2
LP="$RD/suite-lock-path.txt"
[ -e "$LP" ] || exec "$@"

overlap() {   # overlap <busy|unusable> <주인> <잡은 시각> — 기록에 덧붙이고, 이 실행의 첫 겹침이면 화면 줄을 낸다
  local ov="$RD/suite-overlap.txt" first=0 inner wrote=1
  [ -s "$ov" ] || first=1
  { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$ov"; } 2>/dev/null || wrote=0
  if [ "$first" = 1 ]; then
    if [ "$1" = busy ]; then inner="잠금 주인: ${2} · ${3}"; else inner="잠금을 쓸 수 없었다"; fi
    printf '> [quality-gates] 차등 테스트가 다른 전체 테스트와 겹쳐 돈다 — 결과가 경합일 수 있다(%s).\n' "$inner" >&2
  fi
  # 결과 파일의 겹침 줄은 이 기록에서 나온다 — 쓰지 못했으면 그 줄이 빠진다는 것을 알린다(판정은 그대로).
  [ "$wrote" = 1 ] || printf '%s\n' '> [quality-gates] 겹침 기록을 쓰지 못했다 — 결과 파일의 「## 차등 테스트」 에 겹침 줄이 빠진다.' >&2
}

L="$(head -n 1 "$LP" 2>/dev/null)"
WD=""
[ -n "$L" ] && WD="$(mktemp -d "${TMPDIR:-/tmp}/qg-suite-lock.XXXXXX" 2>/dev/null)"
if [ -z "$L" ] || [ -z "$WD" ] || [ ! -d "$WD" ]; then
  overlap unusable - -
  exec "$@"
fi
RCF="$WD/rc"; LOG="$WD/log"
python3 "$HERE/suite_lock.py" run --lock "$L" --owner quality-gates --wait 0 \
  -- bash "$HERE/with-suite-lock.sh" --child "$RCF" -- "$@" > "$LOG"
lrc=$?

emit_command_output() {   # 잠금 줄(잡기 전 줄들 · 잡았다 · 마지막 풀었다)을 빼고 명령의 표준 출력만 낸다
  LC_ALL=C awk '
    !started { if (index($0, "[suite-lock] ") == 1) { if (index($0, "[suite-lock] 잡았다 — ") == 1) started = 1; next } started = 1 }
    { buf[n++] = $0 }
    END {
      if (n > 0) { l = buf[n - 1]; i = index(l, "[suite-lock] 풀었다 — ")
        if (i > 0) { l = substr(l, 1, i - 1); if (l == "") n--; else buf[n - 1] = l } }
      for (k = 0; k < n; k++) print buf[k]
    }' "$LOG"
}

if [ -f "$RCF" ]; then   # 잠금 아래 돌았다
  emit_command_output
  rc="$(cat "$RCF")"; rm -rf -- "$WD"
  case "$rc" in ''|*[!0-9]*) exit "$lrc" ;; esac
  exit "$rc"
fi
if grep -q '^\[suite-lock\] 잡았다 — ' "$LOG"; then   # 잠금 아래 명령이 시작됐지만 끊겨 종료 코드를 남기지 못했다 — 다시 돌리지 않는다
  emit_command_output; rm -rf -- "$WD"
  exit "$lrc"
fi

# 잠금을 잡지 못했다 — 잠금 없이 돌린다
line="$(grep -m 1 '^\[suite-lock\] 잠금을 잡지 못했다 — ' "$LOG")"
rm -rf -- "$WD"
who=""; at=""
if [ "$lrc" = 75 ]; then
  who="$(printf '%s\n' "$line" | LC_ALL=C sed -n 's/.* — 주인 \(.*\) · 잡은 시각 .*$/\1/p')"
  at="$(printf '%s\n' "$line" | LC_ALL=C sed -n 's/.* · 잡은 시각 \(.*\)$/\1/p')"
fi
if [ -n "$who" ] && [ -n "$at" ]; then overlap busy "$who" "$at"; else overlap unusable - -; fi
exec "$@"
