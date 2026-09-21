#!/bin/sh
# devbrew 훅의 Python 인터프리터 해석기. 훅 `command` 가
# `sh <이 파일> --event E --plugin P --hook H <훅.py>` 로 부르고,
# 바닥을 만족하는 인터프리터를 찾아 exec 한다.
#
# 출하 바닥 도출 규칙 — 「2026-10 이후에도 패치를 받는 버전 중 최빈」.
#   2026-09 시점의 그 값이 3.12 다. 다음 재검토 시점은 3.12 EOL(2028-10).
#   숫자를 손으로 올리지 않는다 — 이 규칙을 다시 적용한다.
FLOOR_MAJOR=3
FLOOR_MINOR=12

# 이 스크립트는 **외부 명령을 하나도 부르지 않는다**(자기가 판정하는 파이썬 제외).
# `tr`·`sed` 를 쓰면 PATH 에 /usr/bin 이 없을 때 `command not found` 로 아래 kill switch
# 판정이 조용히 fail-open 한다 — 실측했다. PATH 를 불신하는 것이 이 파일의 일이다.

EVENT=""; PLUGIN=""; HOOK=""
while [ $# -gt 0 ]; do
  case "$1" in
    --event)  [ $# -ge 2 ] || exit 0; EVENT="$2";  shift 2 ;;
    --plugin) [ $# -ge 2 ] || exit 0; PLUGIN="$2"; shift 2 ;;
    --hook)   [ $# -ge 2 ] || exit 0; HOOK="$2";   shift 2 ;;
    --)       shift; break ;;
    *)        break ;;
  esac
done
[ $# -ge 1 ] || exit 0

# ── kill switch (C2) — 어떤 일보다 앞. 의미는 정본과 같다:
#    shared/killswitch/kill_switch_active.py
#      DEVBREW_<플러그인>_DISABLE=1  — 이름을 플러그인명에서 **도출한다**(`-`→`_`, 대문자).
#                                     예: spec-distill -> DEVBREW_SPEC_DISTILL_DISABLE=1
#      DEVBREW_SKIP_HOOKS=<plugin>:<hook>  또는  <plugin>:<event>  (쉼표 목록, 전체 토큰)
#    위 「예:」 줄은 장식이 아니다 — plugin-audit 의 `_KILLSWITCH_RE`
#    (`DEVBREW_[A-Z0-9_]*_DISABLE`)가 도출형 이름을 못 읽어서, 이 줄이 없으면 세 플러그인
#    모두에 거짓 「kill switch 부재」 gap 이 난다. shared/tests/test_python_floor.sh 축 B 가 잰다.
_ks_trim() {   # 앞뒤 공백 제거 — 정본의 `.strip()` 자리
  _s="$1"
  _s="${_s#"${_s%%[![:space:]]*}"}"
  _s="${_s%"${_s##*[![:space:]]}"}"
  printf '%s' "$_s"
}

_ks_skip_has() {   # DEVBREW_SKIP_HOOKS 에 «전체 토큰» $1 이 있는가 (부분 일치 금지)
  [ -n "${DEVBREW_SKIP_HOOKS-}" ] || return 1
  _ifs_save="$IFS"; IFS=","
  for _tok in ${DEVBREW_SKIP_HOOKS}; do
    IFS="$_ifs_save"
    [ "$(_ks_trim "$_tok")" = "$1" ] && return 0
    IFS=","
  done
  IFS="$_ifs_save"
  return 1
}

kill_switch_active() {   # $1 plugin, $2 hook, $3 event(빈 값 가능)
  _up=""; _rest="$1"
  while [ -n "$_rest" ]; do
    _ch="${_rest%"${_rest#?}"}"; _rest="${_rest#?}"
    case "$_ch" in
      a) _ch=A;; b) _ch=B;; c) _ch=C;; d) _ch=D;; e) _ch=E;; f) _ch=F;; g) _ch=G;;
      h) _ch=H;; i) _ch=I;; j) _ch=J;; k) _ch=K;; l) _ch=L;; m) _ch=M;; n) _ch=N;;
      o) _ch=O;; p) _ch=P;; q) _ch=Q;; r) _ch=R;; s) _ch=S;; t) _ch=T;; u) _ch=U;;
      v) _ch=V;; w) _ch=W;; x) _ch=X;; y) _ch=Y;; z) _ch=Z;; -) _ch=_;;
      [A-Z0-9_]) ;;
      *) _ch="" ;;   # eval 에 들어갈 «이름» 이므로 그 밖의 글자는 버린다
    esac
    _up="$_up$_ch"
  done
  eval "_dis=\${DEVBREW_${_up}_DISABLE-}"
  [ "$_dis" = "1" ] && return 0
  # 별칭 둘: 훅명 **또는** 이벤트명. 빈 이벤트는 별칭을 만들지 않는다(정본과 같다 —
  # `<plugin>:` 꼴의 문서화되지 않은 와일드카드가 생기지 않게).
  _ks_skip_has "$1:$2" && return 0
  [ -n "$3" ] && _ks_skip_has "$1:$3" && return 0
  return 1
}

if kill_switch_active "$PLUGIN" "$HOOK" "$EVENT"; then
  exit 0
fi

# ── 버전 판정 — 이름이나 실행 권한이 아니라 «물어본 답» 이 근거다 ──────────────
PROBE_MAJOR=0; PROBE_MINOR=0
probe() {   # $1 = 인터프리터. rc 0 이면 PROBE_MAJOR/PROBE_MINOR 가 채워진다
  _out="$("$1" -c 'import sys;print("%d %d"%(sys.version_info[0],sys.version_info[1]))' 2>/dev/null)" || return 1
  case "$_out" in
    [0-9]*' '[0-9]*) ;;
    *) return 1 ;;
  esac
  PROBE_MAJOR="${_out%% *}"; PROBE_MINOR="${_out##* }"
  return 0
}

BEST_MAJOR=0; BEST_MINOR=-1     # 안내에 실을 「발견된 최고 버전」
note_best() {
  if [ "$PROBE_MAJOR" -gt "$BEST_MAJOR" ] ||
     { [ "$PROBE_MAJOR" -eq "$BEST_MAJOR" ] && [ "$PROBE_MINOR" -gt "$BEST_MINOR" ]; }; then
    BEST_MAJOR="$PROBE_MAJOR"; BEST_MINOR="$PROBE_MINOR"
  fi
}

satisfies() {
  [ "$PROBE_MAJOR" -gt "$FLOOR_MAJOR" ] && return 0
  [ "$PROBE_MAJOR" -eq "$FLOOR_MAJOR" ] && [ "$PROBE_MINOR" -ge "$FLOOR_MINOR" ] && return 0
  return 1
}

# ── 1. $DEVBREW_PYTHON (탈출구) ─────────────────────────────────────────────
IGNORED=""
if [ -n "${DEVBREW_PYTHON-}" ]; then
  if probe "$DEVBREW_PYTHON"; then
    note_best
    if satisfies; then exec "$DEVBREW_PYTHON" "$@"; fi
    IGNORED="$DEVBREW_PYTHON (Python ${PROBE_MAJOR}.${PROBE_MINOR} < ${FLOOR_MAJOR}.${FLOOR_MINOR})"
  else
    IGNORED="$DEVBREW_PYTHON (실행할 수 없거나 버전을 물을 수 없다)"
  fi
  # stdout 에 쓰지 않는다 (C7) — 이 사실은 환경으로 넘기고 SessionStart 안내가 싣는다.
  DEVBREW_PYTHON_IGNORED="$IGNORED"; export DEVBREW_PYTHON_IGNORED
fi

# ── 2. python3 — 흔한 경우, spawn 1회로 끝난다 ──────────────────────────────
if probe python3; then
  note_best
  if satisfies; then exec python3 "$@"; fi
fi

# ── 3. PATH 글롭 — 마이너 버전을 열거하지 않는다 (C4) ───────────────────────
FOUND=""
scan_path() {   # 함수 안이라 `set --` 가 **이 함수의** 위치인자만 건드린다 — 훅의 argv 는 그대로다
  _ifs_save="$IFS"
  IFS=":"; set -f
  set -- ${PATH-}
  set +f; IFS="$_ifs_save"
  for _dir in "$@"; do
    [ -n "$_dir" ] || _dir="."
    for _cand in "$_dir"/python3.*; do
      [ -f "$_cand" ] || continue
      [ -x "$_cand" ] || continue
      case "$_cand" in *-config) continue ;; esac
      probe "$_cand" || continue
      note_best
      if satisfies; then FOUND="$_cand"; return 0; fi
    done
  done
  return 1
}
scan_path

if [ -n "$FOUND" ]; then
  exec "$FOUND" "$@"
fi

# ── 4. 아무것도 없다 — fail-open (C3). 안내는 SessionStart 에서만 (D26) ─────
# 여기서만 stdout 에 쓴다. exec 하는 경로(1·2·3)의 stdout 은 비어 있다.
# 메시지에 `"` 와 `\` 를 넣지 않는다 — 아래 printf 가 JSON 을 손으로 조립한다.
if [ "$EVENT" = "SessionStart" ]; then
  if [ "$BEST_MINOR" -ge 0 ]; then
    _seen="발견된 최고 버전 Python ${BEST_MAJOR}.${BEST_MINOR}"
  else
    _seen="PATH 에서 Python 을 찾지 못했다"
  fi
  _extra=""
  [ -n "$IGNORED" ] && _extra=" \$DEVBREW_PYTHON 은 무시했다: ${IGNORED}."
  _msg="[devbrew] 이 세션에서 devbrew 훅이 비활성이다 — ${_seen}, 요구 바닥은 Python ${FLOOR_MAJOR}.${FLOOR_MINOR}+ 다.${_extra} 고치는 법: Python ${FLOOR_MAJOR}.${FLOOR_MINOR} 이상을 설치해 PATH 에 두거나(uv python install ${FLOOR_MAJOR}.${FLOOR_MINOR}), 이미 있다면 \$DEVBREW_PYTHON 에 그 경로를 지정하라."
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' \
    "$_msg" "$_msg"
fi
exit 0
